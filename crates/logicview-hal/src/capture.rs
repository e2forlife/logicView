//! Arm, header, and sample upload for one capture on a tested pod.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use logicview_proto::{
    actual_payload_bytes, actual_sample_count, parse_logic_header, LogicHeader, ProtoError,
    LOGIC_HEADER_LEN,
};
use nusb::transfer::{Buffer, Bulk, In};

use crate::device::Pod;
use crate::HalError;

const EP_IN: u8 = 0x86;

const PIPE_DEPTH: usize = 32;

/// Prepared arm bytes, transfer policy, and cancellation state for one physical acquisition.
pub struct CaptureJob {
    /// Prepared arm records to send before starting acquisition.
    pub image: Vec<u8>,
    /// Number of packed channel streams, used to size complete sample atoms.
    pub enabled_channels: u64,
    /// Planned per-channel record length before any device shortfall.
    pub requested_samples: u64,
    /// Optional hardware input-threshold code, already converted by the profile.
    pub threshold: Option<u8>,
    /// Stream and loop ignore the header remaining count and keep reading
    /// until the requested length, a sample limit, or stop.
    pub stream: bool,
    /// Loop keeps the pipe open past the requested length until stop.
    pub continuous: bool,
    /// Shared cooperative stop request checked by the blocking transfer loop.
    pub stop: Arc<AtomicBool>,
    /// What to do when `stop` is set before the byte budget is met.
    pub on_stop: OnStop,
    /// Cancel the sample pipe after a good header and return [`HalError::Interrupted`].
    pub abort_after_header: bool,
    /// How long to wait for the header before giving up. Buffer captures need
    /// at least the record duration, because the header arrives with the upload.
    pub header_wait: Duration,
    /// Stop after this many sample bytes and return them. `None` reads the
    /// budget the header describes.
    pub sample_limit: Option<u64>,
    /// Open this product. `None` opens the first tested pod.
    pub product_id: Option<u16>,
}

/// How an early stop treats samples still in the pod.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OnStop {
    /// Cancel the pipe and return an interrupt error.
    Cancel,
    /// Ask the pod to finish and upload, then keep the bytes that arrive.
    Upload,
    /// Ask the pod to abort. The report keeps no sample bytes.
    Discard,
}

/// Final device metadata and transfer diagnostics returned after capture cleanup.
#[derive(Debug)]
pub struct CaptureReport {
    /// Validated device metadata, when a header arrived before capture ended.
    pub header: Option<LogicHeader>,
    /// Accepted payload byte count; sample events contain only complete atoms.
    pub sample_bytes: u64,
    /// Whether the final hardware status reported sample memory overflow.
    pub overflow: bool,
    /// Raw final device status retained for diagnostics.
    pub hw_status: u8,
    /// Stop asked the pod to drop the buffer. `sample_bytes` is then zero.
    pub discarded: bool,
}

/// Metadata or complete sample atoms emitted while a physical acquisition is read.
pub enum CaptureEvent {
    Header(LogicHeader),
    Samples(Vec<u8>),
}

/// Runs one blocking device capture, delivering metadata and whole sample atoms to the caller.
///
/// The caller should run this off the asynchronous executor. The job determines
/// stop behavior and transfer limits; callback failures terminate the capture.
/// Device cleanup follows the transfer loop before a report is returned.
pub fn run_capture(
    job: &CaptureJob,
    mut emit: impl FnMut(CaptureEvent) -> Result<(), HalError>,
) -> Result<CaptureReport, HalError> {
    if job.enabled_channels == 0 {
        return Err(HalError::Message("no channels enabled".into()));
    }
    let pod = match job.product_id {
        Some(pid) => Pod::open_product(Some(pid))?,
        None => Pod::open()?,
    };
    if let Some(code) = job.threshold {
        pod.set_threshold(code)?;
    }
    let _ = pod.stop();
    pod.arm_image(&job.image)?;

    let bulk = pod.bulk_in_packet();
    let mut ep = pod
        .interface()
        .endpoint::<Bulk, In>(EP_IN)
        .map_err(|err| HalError::Usb(err.to_string()))?;
    for _ in 0..PIPE_DEPTH {
        ep.submit(Buffer::new(bulk));
    }
    pod.start()?;

    let atom = (job.enabled_channels as usize).saturating_mul(8).max(1);
    let mut header: Option<LogicHeader> = None;
    let mut expected_bytes = 0u64;
    let mut kept = 0u64;
    let mut pending = Vec::new();
    let mut failed: Option<HalError> = None;
    let mut forced = false;
    let mut discarded = false;
    let mut limit_after_stop: Option<u64> = None;
    let mut filler = 0u32;
    let mut leader = pod.sample_leader();
    let overall = std::time::Instant::now() + job.header_wait + Duration::from_secs(4);
    let mut deadline = std::time::Instant::now() + job.header_wait;

    loop {
        if std::time::Instant::now() > overall {
            failed = Some(HalError::Interrupted("capture exceeded its wait".into()));
            break;
        }
        if !forced && !discarded && job.stop.load(Ordering::Relaxed) {
            match job.on_stop {
                OnStop::Cancel => {
                    cancel(&mut ep);
                    let _ = pod.stop();
                    return Err(HalError::Interrupted("bulk IN cancelled".into()));
                }
                OnStop::Discard => {
                    if let Err(err) = pod.force_stop() {
                        cancel(&mut ep);
                        let _ = pod.stop();
                        return Err(err);
                    }
                    discarded = true;
                    kept = 0;
                    pending.clear();
                    break;
                }
                OnStop::Upload => {
                    if let Err(err) = pod.force_ready() {
                        cancel(&mut ep);
                        let _ = pod.stop();
                        return Err(err);
                    }
                    forced = true;
                    if job.continuous {
                        // A loop does not end when the requested length is met.
                        // Keep a short tail after the stop, then leave the pipe.
                        limit_after_stop = Some(kept.saturating_add(8_192));
                    }
                    deadline = std::time::Instant::now() + Duration::from_secs(3);
                }
            }
        }
        if job.abort_after_header && header.is_some() {
            cancel(&mut ep);
            let _ = pod.stop();
            return Err(HalError::Interrupted(
                "bulk IN cancelled after the header".into(),
            ));
        }

        match ep.wait_next_complete(Duration::from_millis(100)) {
            Some(done) if done.status.is_ok() && done.actual_len > 0 => {
                let received = done.actual_len;
                let data = done.buffer[..received].to_vec();
                let mut offset = 0;
                let mut stop = false;
                while offset < data.len() && failed.is_none() && !stop {
                    let end = (offset + bulk).min(data.len());
                    let packet = &data[offset..end];
                    let packet_short = packet.len() < bulk;
                    offset = end;
                    if header.is_none() {
                        if packet.len() < LOGIC_HEADER_LEN {
                            failed = Some(HalError::Interrupted(format!(
                                "header transfer was {} bytes",
                                packet.len()
                            )));
                            break;
                        }
                        if packet[..LOGIC_HEADER_LEN]
                            .iter()
                            .skip(4)
                            .all(|byte| *byte == 0x55)
                        {
                            filler += 1;
                            if filler > 8 {
                                failed =
                                    Some(HalError::Interrupted("header fill stayed 0x55".into()));
                            }
                            continue;
                        }
                        match parse_logic_header(&packet[..LOGIC_HEADER_LEN]) {
                            Ok(parsed) => {
                                expected_bytes = budget_bytes(job, &parsed);
                                header = Some(parsed);
                                if let Err(err) = emit(CaptureEvent::Header(parsed)) {
                                    failed = Some(err);
                                    break;
                                }
                                deadline = std::time::Instant::now() + Duration::from_secs(2);
                            }
                            Err(err) => {
                                let preview = packet
                                    .iter()
                                    .take(32)
                                    .map(|byte| format!("{byte:02x}"))
                                    .collect::<Vec<_>>()
                                    .join(" ");
                                failed = Some(match err {
                                    ProtoError::BadCheckWord(word) => HalError::Message(format!(
                                        "logic header check word was {word:#010x} in {preview}"
                                    )),
                                    other => HalError::Message(format!(
                                        "{other} in {preview}"
                                    )),
                                });
                                break;
                            }
                        }
                        continue;
                    }

                    let budget = read_budget(job, expected_bytes, limit_after_stop);
                    let payload = take_after_leader(&mut leader, packet);
                    if payload.is_empty() {
                        deadline = std::time::Instant::now() + Duration::from_secs(2);
                        continue;
                    }
                    let room = budget.saturating_sub(kept);
                    if room == 0 {
                        stop = true;
                        break;
                    }
                    let take_n = payload.len().min(room as usize);
                    pending.extend_from_slice(&payload[..take_n]);
                    kept += take_n as u64;
                    let whole = pending.len() / atom * atom;
                    if whole > 0 {
                        let chunk = pending[..whole].to_vec();
                        if let Err(err) = emit(CaptureEvent::Samples(chunk)) {
                            failed = Some(err);
                            break;
                        }
                        pending.drain(..whole);
                    }
                    deadline = std::time::Instant::now()
                        + if forced {
                            Duration::from_millis(500)
                        } else {
                            Duration::from_secs(2)
                        };
                    if packet_short || kept >= budget {
                        stop = true;
                    }
                }
                if failed.is_some() || stop {
                    break;
                }
                let budget = read_budget(job, expected_bytes, limit_after_stop);
                if received == bulk && kept < budget && ep.pending() < PIPE_DEPTH {
                    ep.submit(Buffer::new(bulk));
                }
            }
            Some(done) if done.status.is_ok() => {
                if header.is_some() {
                    break;
                }
                failed = Some(HalError::Interrupted("header transfer was empty".into()));
                break;
            }
            Some(done) => {
                failed = Some(HalError::Interrupted(format!(
                    "sample transfer {:?} ({} bytes)",
                    done.status, done.actual_len
                )));
                break;
            }
            None => {
                if std::time::Instant::now() > deadline {
                    if header.is_none() && !discarded {
                        failed = Some(HalError::Interrupted("header transfer timed out".into()));
                    } else if !forced && !job.continuous && job.sample_limit.is_none() {
                        failed = Some(HalError::Interrupted("sample transfer timed out".into()));
                    }
                    break;
                }
            }
        }
    }

    let _ = pod.force_ready();
    let _ = pod.stop();
    let _ = pod.clear_pipes();
    cancel(&mut ep);
    let hw_status = pod.status().unwrap_or(0);
    if let Some(err) = failed {
        return Err(err);
    }
    if discarded {
        kept = 0;
    }
    Ok(CaptureReport {
        header,
        sample_bytes: kept,
        overflow: hw_status & (1 << 4) != 0,
        hw_status,
        discarded,
    })
}

/// Combines capture mode, sample limits, and stop behavior into the remaining transfer ceiling.
fn read_budget(job: &CaptureJob, expected_bytes: u64, limit_after_stop: Option<u64>) -> u64 {
    let mut budget = if job.continuous {
        job.sample_limit.unwrap_or(u64::MAX)
    } else {
        expected_bytes.min(job.sample_limit.unwrap_or(u64::MAX))
    };
    if let Some(limit) = limit_after_stop {
        budget = budget.min(limit);
    }
    budget
}

/// Determines the payload budget from the requested length and device-reported shortfall.
fn budget_bytes(job: &CaptureJob, header: &LogicHeader) -> u64 {
    let samples = if job.stream || job.continuous {
        job.requested_samples & !63
    } else {
        actual_sample_count(job.requested_samples, header.remaining)
    };
    actual_payload_bytes(samples, job.enabled_channels)
}

/// Drop the fixed leader in front of the sample bytes.
///
/// The length is a bulk packet, not a run of zeros. An all-low capture stays
/// aligned once that packet has been discarded.
fn take_after_leader<'a>(leader: &mut u64, packet: &'a [u8]) -> &'a [u8] {
    if *leader == 0 {
        return packet;
    }
    let drop_n = (*leader as usize).min(packet.len());
    *leader -= drop_n as u64;
    &packet[drop_n..]
}

#[cfg(test)]
mod hw {
    //! Exercises physical acquisitions on connected compatible hardware.
    //!
    //! These tests are ignored by default and serialize access to the pod.

    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Arc, Mutex};
    use std::time::Duration;

    use logicview_proto::{capture_length_warning, encode_arm, ArmConfig, ModeFlags};
    use nusb::MaybeFuture;

    use super::*;

    /// Serializes hardware tests so they do not claim or reconfigure the same pod concurrently.
    fn pod_lock() -> std::sync::MutexGuard<'static, ()> {
        static LOCK: Mutex<()> = Mutex::new(());
        LOCK.lock().unwrap_or_else(|err| err.into_inner())
    }

    /// Creates a standard hardware test job with optional cancellation after the header.
    fn job(samples: u64, mode: u16, abort: bool) -> CaptureJob {
        let mut capture = armed(samples, mode, 100);
        capture.abort_after_header = abort;
        capture
    }

    /// Builds a one-channel hardware test job using the chosen clock and mode.
    fn armed(samples: u64, mode: u16, divider: u32) -> CaptureJob {
        let mut config = ArmConfig::default();
        config.mode = ModeFlags(mode);
        config.divider = divider;
        config.sample_count = samples;
        config.channel_count = 1;
        config.channel_enable = 1;
        CaptureJob {
            image: encode_arm(&config).unwrap(),
            enabled_channels: 1,
            requested_samples: samples,
            threshold: Some(crate::threshold_code(1.6)),
            stream: mode & ModeFlags::STREAM != 0,
            continuous: mode & ModeFlags::ANALOG_OR_LOOP != 0,
            stop: Arc::new(AtomicBool::new(false)),
            on_stop: OnStop::Upload,
            abort_after_header: false,
            header_wait: Duration::from_secs(3),
            sample_limit: None,
            product_id: Some(crate::PLUS_PID),
        }
    }

    /// Summarizes received test data to help diagnose transfer alignment and internal-test
    /// failures.
    fn pattern(bytes: &[u8]) -> String {
        if bytes.is_empty() {
            return "empty".into();
        }
        if bytes.iter().all(|byte| *byte == 0xAA) {
            return "internal-test 0xAA".into();
        }
        if let Some(pos) = bytes.iter().position(|byte| *byte != 0xAA) {
            if bytes[..pos].iter().all(|byte| *byte == 0xAA) {
                return format!("0xAA then {:02X} at {pos}", bytes[pos]);
            }
        }
        if bytes.iter().all(|byte| *byte == 0xFF) {
            return "floating inputs 0xFF".into();
        }
        let shown: Vec<String> = bytes
            .iter()
            .take(8)
            .map(|byte| format!("{byte:02X}"))
            .collect();
        format!("mixed {}", shown.join(" "))
    }

    /// Runs a hardware test capture and retains a short payload preview for diagnostics.
    fn try_take(job: &CaptureJob) -> Result<(CaptureReport, Vec<u8>), String> {
        let mut bytes = Vec::new();
        match run_capture(job, |event| {
            if let CaptureEvent::Samples(chunk) = event {
                if bytes.len() < 64 {
                    let room = 64 - bytes.len();
                    bytes.extend(chunk.into_iter().take(room));
                }
            }
            Ok(())
        }) {
            Ok(report) => {
                let header = report.header;
                eprintln!(
                    "MODE samples={} discarded={} remaining={:?} status={:?} hw={:#04x} pattern={}",
                    report.sample_bytes,
                    report.discarded,
                    header.map(|item| item.remaining),
                    header.map(|item| item.status),
                    report.hw_status,
                    pattern(&bytes)
                );
                Ok((report, bytes))
            }
            Err(err) => {
                eprintln!("MODE error={err}");
                Err(err.to_string())
            }
        }
    }

    /// Runs a hardware test capture that is expected to succeed.
    fn take(job: &CaptureJob) -> (CaptureReport, Vec<u8>) {
        try_take(job).unwrap_or_else(|err| panic!("capture failed: {err}"))
    }

    /// Checks that a previous test left the instrument usable for another acquisition.
    fn reopen(label: &str) {
        let (report, bytes) = take(&job(
            256,
            ModeFlags::INSTANT | ModeFlags::INTERNAL_TEST,
            false,
        ));
        assert!(
            report
                .header
                .is_some_and(|header| header.check_word == 0x5555_5555),
            "{label} reopen header"
        );
        assert_eq!(report.sample_bytes, 32, "{label} reopen length");
        assert!(
            bytes.iter().all(|byte| *byte == 0xAA),
            "{label} reopen pattern"
        );
    }

    /// Exercises physical buffer capture, cancellation, and recovery on the tested Plus pod.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic Plus"]
    fn plus_buffer_header_count_and_interrupted_capture() {
        let _pod = pod_lock();
        let mut bytes = Vec::new();
        let report = run_capture(
            &job(256, ModeFlags::INSTANT | ModeFlags::INTERNAL_TEST, false),
            |event| {
                if let CaptureEvent::Samples(chunk) = event {
                    bytes.extend_from_slice(&chunk);
                }
                Ok(())
            },
        )
        .expect("internal-test capture");
        assert_eq!(report.header.unwrap().check_word, 0x5555_5555);
        assert_eq!(bytes.len(), 32, "256 samples on one channel is 32 bytes");
        assert!(bytes.iter().all(|byte| *byte == 0xAA), "{bytes:02x?}");

        let mut plain = Vec::new();
        let longer = run_capture(&job(1024, ModeFlags::INSTANT, false), |event| {
            if let CaptureEvent::Samples(chunk) = event {
                plain.extend_from_slice(&chunk);
            }
            Ok(())
        })
        .expect("instant capture");
        assert_eq!(longer.header.unwrap().check_word, 0x5555_5555);
        assert_eq!(plain.len(), 128, "1024 samples on one channel is 128 bytes");

        let interrupted = run_capture(&job(4096, ModeFlags::INSTANT, true), |_| Ok(()));
        let message = interrupted.expect_err("cancelled capture").to_string();
        assert!(message.contains("interrupt"), "{message}");

        let again = run_capture(&job(256, ModeFlags::INSTANT, false), |_| Ok(())).expect("reopen");
        assert_eq!(again.header.unwrap().check_word, 0x5555_5555);
        assert_eq!(again.sample_bytes, 32);
    }

    /// Prints physical USB link and endpoint information for wider-pod diagnostics.
    #[test]
    #[ignore = "needs the plugged-in DSLogic U3Pro32"]
    fn u3pro32_reports_link_speed() {
        let _pod = pod_lock();
        let info = nusb::list_devices()
            .wait()
            .expect("bus")
            .find(|dev| dev.vendor_id() == 0x2A0E && dev.product_id() == crate::U3PRO32_PID)
            .expect("u3 on the bus");
        let device = info.open().wait().expect("open descriptor");
        eprintln!(
            "bcdUSB {:04x} open speed {:?}",
            device.device_descriptor().usb_version(),
            device.speed()
        );
        if let Ok(config) = device.active_configuration() {
            for iface in config.interfaces() {
                for alt in iface.alt_settings() {
                    for endpoint in alt.endpoints() {
                        eprintln!(
                            "cfg ep {:02x} mps {}",
                            endpoint.address(),
                            endpoint.max_packet_size()
                        );
                    }
                }
            }
        }
        drop(device);
        let pod = Pod::open_product(Some(crate::U3PRO32_PID)).expect("open");
        eprintln!("open speed {:?}", pod.speed());
        for iface in pod.interface().descriptors() {
            for endpoint in iface.endpoints() {
                eprintln!(
                    "ep {:02x} type {:?} mps {} burst {}",
                    endpoint.address(),
                    endpoint.transfer_type(),
                    endpoint.max_packet_size(),
                    endpoint.packets_per_microframe()
                );
            }
        }
    }

    /// Checks sample alignment using the wider pod's internal pattern on a SuperSpeed link.
    #[test]
    #[ignore = "needs the plugged-in super-speed DSLogic U3Pro32"]
    fn u3pro32_super_internal_pattern_follows_the_header() {
        let _pod = pod_lock();
        {
            let pod = Pod::open_product(Some(crate::U3PRO32_PID)).expect("open");
            assert_eq!(pod.speed(), Some(nusb::Speed::Super), "link speed");
            assert_eq!(pod.bulk_in_packet(), 1024, "super-speed bulk packet");
            eprintln!(
                "super leader {} packet {}",
                pod.sample_leader(),
                pod.bulk_in_packet()
            );
        }

        let mut bytes = Vec::new();
        let report = run_capture(&u3_job(8192), |event| {
            if let CaptureEvent::Samples(chunk) = event {
                bytes.extend_from_slice(&chunk);
            }
            Ok(())
        })
        .expect("internal-test capture");
        eprintln!(
            "super internal {} bytes: {}",
            bytes.len(),
            pattern(&bytes)
        );
        if bytes.len() >= 16 {
            eprintln!("first {:02x?}", &bytes[..16]);
        }
        assert_eq!(report.header.unwrap().check_word, 0x5555_5555);
        assert_eq!(bytes.len(), 1024, "8192 samples on one channel is 1024 bytes");
        assert!(bytes.iter().all(|byte| *byte == 0xAA), "{bytes:02x?}");
    }

    /// Exercises FPGA reload and short buffer capture on the wider pod.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic U3Pro32"]
    fn u3pro32_short_buffer_returns_check_word_and_samples() {
        let _pod = pod_lock();
        let listed = crate::list_pods().expect("scan");
        let wide = listed
            .iter()
            .find(|pod| pod.product_id == crate::U3PRO32_PID)
            .expect("u3pro32 listed");
        assert_eq!(wide.id, crate::U3_DEVICE_ID);

        {
            let pod = Pod::open_product(Some(crate::U3PRO32_PID)).expect("open");
            assert_eq!(pod.product_id(), crate::U3PRO32_PID);
            pod.reload_fpga().expect("fpga reload");
            let status = pod.status().expect("status");
            assert!(
                status & (1 << 6) != 0,
                "DONE after reload, status {status:#04x}, speed {:?}",
                pod.speed()
            );
            assert_eq!(
                pod.sample_leader(),
                crate::U3_HS_SAMPLE_LEADER,
                "high-speed leader, speed {:?}",
                pod.speed()
            );
        }

        let mut bytes = Vec::new();
        // 4096 samples is one high-speed payload packet. A 256-sample
        // internal test on this pod ends in a few bytes of previous memory.
        let report = run_capture(&u3_job(4096), |event| {
            if let CaptureEvent::Samples(chunk) = event {
                bytes.extend_from_slice(&chunk);
            }
            Ok(())
        })
        .expect("internal-test capture");
        assert_eq!(report.header.unwrap().check_word, 0x5555_5555);
        assert_eq!(bytes.len(), 512, "4096 samples on one channel is 512 bytes");
        assert!(bytes.iter().all(|byte| *byte == 0xAA), "{bytes:02x?}");
    }

    /// Checks buffer acquisition at a representative rate on the wider pod.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic U3Pro32"]
    fn u3pro32_one_megahertz_buffer_returns_a_header() {
        let _pod = pod_lock();
        // The UI default: 1 MHz, every channel, trigger off. Divider 50
        // produced no header within 12 s. The planner's divider must return.
        let clock = crate::plan_u3_clock(1_000_000, u32::MAX, false).unwrap();
        let divider =
            logicview_proto::logic_divider(clock.hw_max_hz, 1_000_000, clock.pre_divider);
        assert_eq!(divider & 0xffff, 100, "1 MHz low half");
        assert_eq!(divider >> 16, 0x0400, "pre-divider stage");

        let mut job = armed(2_000_000, 0, divider);
        job.product_id = Some(crate::U3PRO32_PID);
        job.threshold = Some(crate::u3_threshold_code(1.6));
        job.enabled_channels = 32;
        job.header_wait = Duration::from_secs(6);
        let mut decoded = logicview_proto::decode_arm(&job.image).unwrap();
        decoded.divider = divider;
        decoded.mode = ModeFlags(0);
        decoded.channel_count = 32;
        decoded.channel_enable = u32::MAX;
        decoded.upper = Some([logicview_proto::UpperStage::default(); 16]);
        job.image = logicview_proto::encode_arm(&decoded).unwrap();

        let started = std::time::Instant::now();
        let report = run_capture(&job, |_| Ok(())).expect("32-channel 1 MHz buffer");
        let elapsed = started.elapsed();
        eprintln!("32ch 1 MHz buffer took {elapsed:?}");
        assert!(report.header.is_some(), "header arrived");
        assert!(report.sample_bytes > 0, "samples arrived in {elapsed:?}");
        assert!(
            elapsed > Duration::from_millis(1200) && elapsed < Duration::from_secs(6),
            "2e6 samples at 1 MHz took {elapsed:?}"
        );
    }

    /// Checks streaming acquisition at a representative rate on the wider pod.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic U3Pro32"]
    fn u3pro32_one_megahertz_stream_returns_a_header() {
        let _pod = pod_lock();
        let clock = crate::plan_u3_clock(1_000_000, u32::MAX, true).unwrap();
        let divider =
            logicview_proto::logic_divider(clock.hw_max_hz, 1_000_000, clock.pre_divider);
        let mut job = armed(65_536, ModeFlags::STREAM, divider);
        job.product_id = Some(crate::U3PRO32_PID);
        job.threshold = Some(crate::u3_threshold_code(1.6));
        job.enabled_channels = 32;
        job.header_wait = Duration::from_secs(3);
        let mut decoded = logicview_proto::decode_arm(&job.image).unwrap();
        decoded.divider = divider;
        decoded.mode = ModeFlags(ModeFlags::STREAM);
        decoded.channel_count = 32;
        decoded.channel_enable = u32::MAX;
        decoded.upper = Some([logicview_proto::UpperStage::default(); 16]);
        job.image = logicview_proto::encode_arm(&decoded).unwrap();

        let started = std::time::Instant::now();
        let report = run_capture(&job, |_| Ok(())).expect("32-channel 1 MHz stream");
        eprintln!("32ch 1 MHz stream took {:?}", started.elapsed());
        assert!(report.header.is_some(), "stream header arrived");
        assert!(report.sample_bytes > 0, "stream samples arrived");
    }

    /// Exercises buffer clock settings against real wider-pod captures.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic U3Pro32"]
    fn u3pro32_buffer_rates_scale_with_the_divider() {
        let _pod = pod_lock();
        // 2e6 samples at 1 MHz takes about 2.4 s. Faster rates have to finish
        // inside that window. A miss clears the bulk pipe on the next open.
        let mut failed = Vec::new();
        for (rate, channels, mode, samples) in [
            (10_000_000, 32, 0, 2_000_000),
            (100_000_000, 32, 0, 262_144),
            (250_000_000, 32, 0, 65_536),
            (250_000_000, 8, 0, 262_144),
            (500_000_000, 16, ModeFlags::HALF_RATE, 262_144),
            (1_000_000_000, 8, ModeFlags::QUARTER_RATE, 262_144),
        ] {
            match u3_buffer(rate, channels, mode, samples) {
                Ok(elapsed) => {
                    eprintln!("{channels}ch {rate} Hz {samples} samples took {elapsed:?}");
                    if rate == 10_000_000 {
                        assert!(
                            elapsed < Duration::from_millis(1500),
                            "10 MHz took {elapsed:?}"
                        );
                    }
                }
                Err((elapsed, err)) => {
                    eprintln!("{channels}ch {rate} Hz failed after {elapsed:?}: {err}");
                    failed.push(rate);
                }
            }
        }
        assert!(
            failed.is_empty(),
            "rates that did not return a header: {failed:?}"
        );
    }

    /// Exercises the supported streaming rate bands on a physical SuperSpeed connection.
    #[test]
    #[ignore = "needs the plugged-in super-speed DSLogic U3Pro32"]
    fn u3pro32_super_stream_ceilings_return_a_header() {
        let _pod = pod_lock();
        let mut failed = Vec::new();
        for (rate, channels, mode) in [
            (50_000_000, 32, ModeFlags::STREAM),
            (100_000_000, 30, ModeFlags::STREAM),
            (250_000_000, 12, ModeFlags::STREAM),
            (500_000_000, 6, ModeFlags::STREAM | ModeFlags::HALF_RATE),
            (1_000_000_000, 3, ModeFlags::STREAM | ModeFlags::QUARTER_RATE),
        ] {
            match u3_stream(rate, channels, mode, 65_536) {
                Ok(elapsed) => {
                    eprintln!("{channels}ch {rate} Hz stream took {elapsed:?}");
                }
                Err((elapsed, err)) => {
                    eprintln!("{channels}ch {rate} Hz stream failed after {elapsed:?}: {err}");
                    failed.push(rate);
                }
            }
        }
        assert!(
            failed.is_empty(),
            "super-speed stream rates that did not return a header: {failed:?}"
        );
    }

    /// Builds a wider-pod buffer test job with matching channel and clock settings.
    fn u3_buffer(
        rate_hz: u64,
        channels: u32,
        extra_mode: u16,
        samples: u64,
    ) -> Result<Duration, (Duration, String)> {
        let mask = if channels >= 32 {
            u32::MAX
        } else {
            (1u32 << channels) - 1
        };
        let clock = crate::plan_u3_clock(rate_hz, mask, false).expect("rate");
        let divider = logicview_proto::logic_divider(clock.hw_max_hz, rate_hz, clock.pre_divider);
        let mut job = armed(samples, extra_mode, divider);
        job.product_id = Some(crate::U3PRO32_PID);
        job.threshold = Some(crate::u3_threshold_code(1.6));
        job.enabled_channels = u64::from(channels);
        job.header_wait = Duration::from_secs(3);
        let mut decoded = logicview_proto::decode_arm(&job.image).unwrap();
        decoded.divider = divider;
        decoded.mode = ModeFlags(extra_mode);
        decoded.channel_count = channels as u8;
        decoded.channel_enable = mask;
        decoded.upper = Some([logicview_proto::UpperStage::default(); 16]);
        job.image = logicview_proto::encode_arm(&decoded).unwrap();
        eprintln!(
            "arm {channels}ch {rate_hz} Hz divider {:#010x}",
            divider
        );
        let started = std::time::Instant::now();
        match run_capture(&job, |_| Ok(())) {
            Ok(report) if report.header.is_some() && report.sample_bytes > 0 => Ok(started.elapsed()),
            Ok(report) => Err((
                started.elapsed(),
                format!("header {:?} bytes {}", report.header.is_some(), report.sample_bytes),
            )),
            Err(err) => Err((started.elapsed(), err.to_string())),
        }
    }

    /// Builds a wider-pod stream test job with matching channel and clock settings.
    fn u3_stream(
        rate_hz: u64,
        channels: u32,
        mode: u16,
        samples: u64,
    ) -> Result<Duration, (Duration, String)> {
        let mask = if channels >= 32 {
            u32::MAX
        } else {
            (1u32 << channels) - 1
        };
        let divider = logicview_proto::logic_divider(crate::U3_HW_CLOCK_HZ, rate_hz, crate::U3_PRE_DIVIDER);
        let mut job = armed(samples, mode, divider);
        job.product_id = Some(crate::U3PRO32_PID);
        job.threshold = Some(crate::u3_threshold_code(1.6));
        job.enabled_channels = u64::from(channels);
        job.header_wait = Duration::from_secs(3);
        let mut decoded = logicview_proto::decode_arm(&job.image).unwrap();
        decoded.divider = divider;
        decoded.mode = ModeFlags(mode);
        decoded.channel_count = channels as u8;
        decoded.channel_enable = mask;
        decoded.upper = Some([logicview_proto::UpperStage::default(); 16]);
        job.image = logicview_proto::encode_arm(&decoded).unwrap();
        eprintln!("arm {channels}ch {rate_hz} Hz stream divider {divider:#010x} mode {mode:#06x}");
        let started = std::time::Instant::now();
        match run_capture(&job, |_| Ok(())) {
            Ok(report) if report.header.is_some() && report.sample_bytes > 0 => Ok(started.elapsed()),
            Ok(report) => Err((
                started.elapsed(),
                format!("header {:?} bytes {}", report.header.is_some(), report.sample_bytes),
            )),
            Err(err) => Err((started.elapsed(), err.to_string())),
        }
    }

    /// Creates a wider-pod internal-pattern job for transfer alignment checks.
    fn u3_job(samples: u64) -> CaptureJob {
        let mut capture = armed(samples, ModeFlags::INSTANT | ModeFlags::INTERNAL_TEST, 200);
        capture.product_id = Some(crate::U3PRO32_PID);
        capture.threshold = None;
        capture
    }

    /// Exercises representative Plus capture modes and checks device responses.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic Plus"]
    fn plus_reference_modes_return_a_header() {
        let _pod = pod_lock();
        {
            let pod = Pod::open_product(Some(crate::PLUS_PID)).expect("open");
            pod.reload_fpga().expect("fpga reload");
            assert_eq!(pod.product_id(), crate::PLUS_PID);
            assert_eq!(pod.speed(), Some(nusb::Speed::High), "Plus link");
            assert_eq!(pod.bulk_in_packet(), 512, "high-speed bulk packet");
            assert_eq!(pod.sample_leader(), 0, "Plus has no sample leader");
            eprintln!(
                "plus speed {:?} packet {} leader {}",
                pod.speed(),
                pod.bulk_in_packet(),
                pod.sample_leader()
            );
        }

        let mut pattern_bytes = Vec::new();
        let pattern_report = run_capture(
            &job(4096, ModeFlags::INSTANT | ModeFlags::INTERNAL_TEST, false),
            |event| {
                if let CaptureEvent::Samples(chunk) = event {
                    pattern_bytes.extend_from_slice(&chunk);
                }
                Ok(())
            },
        )
        .expect("internal-test capture");
        assert_eq!(pattern_report.header.unwrap().check_word, 0x5555_5555);
        assert_eq!(pattern_bytes.len(), 512);
        assert!(pattern_bytes.iter().all(|byte| *byte == 0xAA));

        let mut failed = Vec::new();
        for (rate, channels, stream, samples, min_ms, max_ms) in [
            (1_000_000, 16, false, 1_000_000, 700, 4_000),
            (100_000_000, 16, false, 65_536, 0, 1_500),
            (200_000_000, 8, false, 65_536, 0, 1_500),
            (400_000_000, 4, false, 65_536, 0, 1_500),
            (20_000_000, 16, true, 65_536, 0, 1_500),
            (25_000_000, 12, true, 65_536, 0, 1_500),
            (50_000_000, 6, true, 65_536, 0, 1_500),
            (100_000_000, 3, true, 65_536, 0, 1_500),
        ] {
            let label = format!(
                "{channels}ch {rate} Hz {}",
                if stream { "stream" } else { "buffer" }
            );
            match plus_mode(rate, channels, stream, samples) {
                Ok(elapsed) => {
                    eprintln!("{label} took {elapsed:?}");
                    let ms = elapsed.as_millis();
                    if ms < min_ms || ms > max_ms {
                        eprintln!("{label} outside {min_ms}..{max_ms} ms");
                        failed.push(label);
                    }
                }
                Err((elapsed, err)) => {
                    eprintln!("{label} failed after {elapsed:?}: {err}");
                    failed.push(label);
                }
            }
        }
        assert!(failed.is_empty(), "Plus modes that missed the reference: {failed:?}");
    }

    /// Builds a Plus test job for a selected sampling rate and channel mask.
    fn plus_mode(
        rate_hz: u64,
        channels: u32,
        stream: bool,
        samples: u64,
    ) -> Result<Duration, (Duration, String)> {
        let mask = (1u32 << channels) - 1;
        let plan = crate::plan_clock(rate_hz, mask, stream).expect("rate");
        let divider = logicview_proto::logic_divider(crate::HW_CLOCK_HZ, rate_hz, 1);
        assert_eq!(plan.divider, divider, "pre-divider 1 keeps the divider in the low half");
        let mut mode = 0u16;
        if stream {
            mode |= ModeFlags::STREAM;
        }
        if plan.half {
            mode |= ModeFlags::HALF_RATE;
        }
        if plan.quarter {
            mode |= ModeFlags::QUARTER_RATE;
        }
        let bytes_per_ms = rate_hz.saturating_mul(u64::from(channels)).div_ceil(8_000);
        if bytes_per_ms < 1024 {
            mode |= ModeFlags::SLOW_ACQUISITION;
        }
        let mut job = armed(samples, mode, divider);
        job.threshold = Some(crate::threshold_code(1.6));
        job.enabled_channels = u64::from(channels);
        job.header_wait = Duration::from_secs(4);
        let mut decoded = logicview_proto::decode_arm(&job.image).unwrap();
        decoded.divider = divider;
        decoded.mode = ModeFlags(mode);
        decoded.channel_count = channels as u8;
        decoded.channel_enable = mask;
        decoded.upper = None;
        job.image = logicview_proto::encode_arm(&decoded).unwrap();
        eprintln!(
            "arm {channels}ch {rate_hz} Hz {} divider {divider:#010x} mode {mode:#06x}",
            if stream { "stream" } else { "buffer" }
        );
        let started = std::time::Instant::now();
        match run_capture(&job, |_| Ok(())) {
            Ok(report) if report.header.is_some() && report.sample_bytes > 0 => Ok(started.elapsed()),
            Ok(report) => Err((
                started.elapsed(),
                format!("header {:?} bytes {}", report.header.is_some(), report.sample_bytes),
            )),
            Err(err) => Err((started.elapsed(), err.to_string())),
        }
    }

    /// Exercises physical capture modes, input settings, early-stop policies, and subsequent
    /// recovery.
    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic Plus"]
    fn plus_stream_loop_repeat_threshold_filter_rle_and_stop() {
        let _pod = pod_lock();
        let internal = ModeFlags::INSTANT | ModeFlags::INTERNAL_TEST;

        eprintln!("-- stream to completion --");
        let mut stream = armed(65_536, internal | ModeFlags::STREAM, 100);
        let (stream_done, stream_bytes) = take(&mut stream);
        assert!(stream_done.header.is_some(), "stream started");
        assert_eq!(stream_done.sample_bytes, 8192, "stream samples arrived");
        assert!(stream_bytes.iter().all(|byte| *byte == 0xAA));
        eprintln!("-- stream stop retains data --");
        let mut stream_stop = armed(2_000_000, internal | ModeFlags::STREAM, 100);
        stream_stop.on_stop = OnStop::Upload;
        let flag = Arc::clone(&stream_stop.stop);
        let killer = std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(250));
            flag.store(true, Ordering::Relaxed);
        });
        let (stopped, stopped_bytes) = take(&stream_stop);
        let _ = killer.join();
        assert!(stopped.header.is_some(), "stopped stream started");
        assert_eq!(stopped.sample_bytes, 250_000, "stop retained the stream");
        assert!(stopped_bytes.iter().all(|byte| *byte == 0xAA));
        reopen("stream");

        eprintln!("-- loop until stop --");
        let mut looped = armed(
            65_536,
            internal | ModeFlags::STREAM | ModeFlags::ANALOG_OR_LOOP,
            100,
        );
        looped.on_stop = OnStop::Upload;
        let flag = Arc::clone(&looped.stop);
        let killer = std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(250));
            flag.store(true, Ordering::Relaxed);
        });
        let (loop_report, loop_bytes) = take(&looped);
        let _ = killer.join();
        assert!(loop_report.header.is_some(), "loop started");
        assert!(loop_report.sample_bytes > 0, "loop samples arrived");
        assert!(!loop_bytes.is_empty(), "stop retained loop samples");
        reopen("loop");

        eprintln!("-- repeat two captures --");
        let (first, first_bytes) = take(&armed(1_024, internal, 100));
        std::thread::sleep(Duration::from_millis(150));
        let (second, second_bytes) = take(&armed(1_024, internal, 100));
        assert!(
            first.sample_bytes > 0 && second.sample_bytes > 0,
            "repeat samples"
        );
        assert!(
            !second_bytes.is_empty(),
            "repeat stop retained the second record"
        );
        assert_eq!(first_bytes.len(), second_bytes.len());
        reopen("repeat");

        eprintln!("-- threshold codes --");
        {
            let pod = crate::Pod::open().expect("threshold open");
            pod.set_threshold(0).expect("threshold 0");
            let low = pod.read_register(0x78);
            pod.set_threshold(193).expect("threshold 5V code");
            let high = pod.read_register(0x78);
            eprintln!("threshold readback code0={low:?} code193={high:?}");
        }
        let mut low_job = armed(256, internal, 100);
        low_job.threshold = Some(0);
        let (low_cap, low_bytes) = take(&low_job);
        let mut high_job = armed(256, internal, 100);
        high_job.threshold = Some(193);
        let (high_cap, high_bytes) = take(&high_job);
        assert!(low_cap.sample_bytes > 0 && high_cap.sample_bytes > 0);
        eprintln!(
            "threshold patterns {} / {}",
            pattern(&low_bytes),
            pattern(&high_bytes)
        );
        reopen("threshold");

        eprintln!("-- one-sample filter --");
        let (plain, plain_bytes) = take(&armed(1_024, internal, 100));
        let (filtered, filtered_bytes) =
            take(&armed(1_024, internal | ModeFlags::ONE_SAMPLE_FILTER, 100));
        assert!(plain.sample_bytes > 0 && filtered.sample_bytes > 0);
        eprintln!(
            "filter off={} on={}",
            pattern(&plain_bytes),
            pattern(&filtered_bytes)
        );
        reopen("filter");

        eprintln!("-- RLE past one channel's share of memory --");
        // One channel can hold the whole 256 Mibit, and the packed count field
        // cannot name a longer record. Sixteen channels split that memory, so
        // 32e6 samples is past the per-channel depth while the count still fits.
        let mut rle = armed(32_000_000, internal | ModeFlags::RLE, 1);
        let mut decoded = logicview_proto::decode_arm(&rle.image).unwrap();
        decoded.channel_count = 16;
        decoded.channel_enable = 0xFFFF;
        rle.image = logicview_proto::encode_arm(&decoded).unwrap();
        rle.enabled_channels = 16;
        rle.header_wait = Duration::from_secs(15);
        rle.sample_limit = Some(4_096);
        let (rle_report, _) = take(&rle);
        let rle_header = rle_report.header.expect("rle header");
        let warning = capture_length_warning(true, rle.requested_samples, rle_header.remaining);
        eprintln!(
            "rle warning={warning:?} remaining={} status={}",
            rle_header.remaining, rle_header.status
        );
        assert!(rle_report.sample_bytes > 0, "rle upload started");
        if rle_header.remaining == 0 {
            eprintln!("rle header remaining was 0, so no shortfall warning was emitted");
        }
        let warning_text = warning.clone().unwrap_or_default();
        if rle_header.remaining > 0 {
            assert!(warning_text.contains("RLE shortfall"), "{warning_text}");
        }
        reopen("rle");

        eprintln!("-- stop and upload --");
        let mut upload = armed(8_000_000, internal, 100);
        upload.on_stop = OnStop::Upload;
        upload.header_wait = Duration::from_secs(12);
        let flag = Arc::clone(&upload.stop);
        let killer = std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(700));
            flag.store(true, Ordering::Relaxed);
        });
        let upload_result = try_take(&upload);
        let _ = killer.join();
        match upload_result {
            Ok((report, bytes)) => {
                assert!(!report.discarded, "upload stop is not a discard");
                assert!(
                    report.sample_bytes > 0 && !bytes.is_empty(),
                    "upload stop retained samples"
                );
            }
            Err(err) => {
                assert!(
                    err.contains("0x55"),
                    "buffer force-ready did not upload a capture: {err}"
                );
            }
        }
        reopen("upload");

        eprintln!("-- stop and discard --");
        let mut discard = armed(8_000_000, internal, 100);
        discard.on_stop = OnStop::Discard;
        discard.header_wait = Duration::from_secs(12);
        let flag = Arc::clone(&discard.stop);
        let killer = std::thread::spawn(move || {
            std::thread::sleep(Duration::from_millis(700));
            flag.store(true, Ordering::Relaxed);
        });
        let (discard_report, _) = take(&discard);
        let _ = killer.join();
        assert!(discard_report.discarded, "discard stop completed");
        assert_eq!(discard_report.sample_bytes, 0, "discard kept no samples");
        reopen("discard");
    }
}

/// Cancels queued input transfers and drains completions during capture cleanup.
fn cancel(ep: &mut nusb::Endpoint<Bulk, In>) {
    ep.cancel_all();
    while ep.pending() > 0 {
        if ep.wait_next_complete(Duration::from_millis(50)).is_none() {
            break;
        }
    }
}

#[cfg(test)]
mod leader {
    //! Checks that transport padding is removed without discarding real all-low samples.

    use super::take_after_leader;

    /// Guards against treating real all-low samples as transport padding.
    #[test]
    fn the_leader_is_one_packet_and_later_zeros_stay() {
        let mut leader = 512u64;
        let packet = vec![0u8; 512];
        assert!(take_after_leader(&mut leader, &packet).is_empty());
        assert_eq!(leader, 0);
        let samples = [0x00, 0xAA, 0xAA];
        assert_eq!(take_after_leader(&mut leader, &samples), &samples);

        let mut leader = 512u64;
        let low = [0x00, 0x00];
        assert_eq!(take_after_leader(&mut leader, &low), &[]);
        assert_eq!(leader, 510);
        assert_eq!(take_after_leader(&mut leader, &low), &low[..0]);
    }
}
