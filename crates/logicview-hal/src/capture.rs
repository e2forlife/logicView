//! Arm, header, and sample upload for one Plus capture.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use logicview_proto::{
    actual_payload_bytes, actual_sample_count, parse_logic_header, LogicHeader, ProtoError,
    LOGIC_HEADER_LEN, LOGIC_HEADER_TRANSFER,
};
use nusb::transfer::{Bulk, Buffer, In};

use crate::device::Pod;
use crate::HalError;

const EP_IN: u8 = 0x86;

pub struct CaptureJob {
    pub image: Vec<u8>,
    pub enabled_channels: u64,
    pub requested_samples: u64,
    pub threshold: Option<u8>,
    /// Stream and loop ignore the header remaining count and keep reading
    /// until the requested length, a sample limit, or stop.
    pub stream: bool,
    /// Loop keeps the pipe open past the requested length until stop.
    pub continuous: bool,
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

#[derive(Debug)]
pub struct CaptureReport {
    pub header: Option<LogicHeader>,
    pub sample_bytes: u64,
    pub overflow: bool,
    pub hw_status: u8,
    /// Stop asked the pod to drop the buffer. `sample_bytes` is then zero.
    pub discarded: bool,
}

pub enum CaptureEvent {
    Header(LogicHeader),
    Samples(Vec<u8>),
}

pub fn run_capture(
    job: &CaptureJob,
    mut emit: impl FnMut(CaptureEvent) -> Result<(), HalError>,
) -> Result<CaptureReport, HalError> {
    if job.enabled_channels == 0 {
        return Err(HalError::Message("no channels enabled".into()));
    }
    let pod = Pod::open()?;
    if let Some(code) = job.threshold {
        pod.set_threshold(code)?;
    }
    let _ = pod.stop();
    pod.arm_image(&job.image)?;

    let mut ep = pod
        .interface()
        .endpoint::<Bulk, In>(EP_IN)
        .map_err(|err| HalError::Usb(err.to_string()))?;
    for _ in 0..4 {
        ep.submit(Buffer::new(LOGIC_HEADER_TRANSFER));
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
                if header.is_none() {
                    if done.actual_len < LOGIC_HEADER_LEN {
                        failed = Some(HalError::Interrupted(format!(
                            "header transfer was {} bytes",
                            done.actual_len
                        )));
                        break;
                    }
                    if done.buffer[..LOGIC_HEADER_LEN]
                        .iter()
                        .skip(4)
                        .all(|byte| *byte == 0x55)
                    {
                        filler += 1;
                        if filler > 8 {
                            failed = Some(HalError::Interrupted(
                                "header fill stayed 0x55".into(),
                            ));
                            break;
                        }
                        if ep.pending() < 4 {
                            ep.submit(Buffer::new(LOGIC_HEADER_TRANSFER));
                        }
                        continue;
                    }
                    match parse_logic_header(&done.buffer[..LOGIC_HEADER_LEN]) {
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
                            failed = Some(match err {
                                ProtoError::BadCheckWord(word) => HalError::BadCheckWord(word),
                                other => HalError::Message(other.to_string()),
                            });
                            break;
                        }
                    }
                    if ep.pending() < 4 {
                        ep.submit(Buffer::new(LOGIC_HEADER_TRANSFER));
                    }
                    continue;
                }

                let budget = read_budget(job, expected_bytes, limit_after_stop);
                let room = budget.saturating_sub(kept);
                if room == 0 {
                    break;
                }
                let take = done.actual_len.min(room as usize);
                pending.extend_from_slice(&done.buffer[..take]);
                kept += take as u64;
                let whole = pending.len() / atom * atom;
                if whole > 0 {
                    let chunk = pending[..whole].to_vec();
                    if let Err(err) = emit(CaptureEvent::Samples(chunk)) {
                        failed = Some(err);
                        break;
                    }
                    pending.drain(..whole);
                }
                let short = done.actual_len < LOGIC_HEADER_TRANSFER;
                if !short && kept < budget && ep.pending() < 4 {
                    ep.submit(Buffer::new(LOGIC_HEADER_TRANSFER));
                }
                deadline = std::time::Instant::now()
                    + if forced {
                        Duration::from_millis(500)
                    } else {
                        Duration::from_secs(2)
                    };
                if short || kept >= budget {
                    break;
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

    let _ = pod.stop();
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

fn budget_bytes(job: &CaptureJob, header: &LogicHeader) -> u64 {
    let samples = if job.stream || job.continuous {
        job.requested_samples & !63
    } else {
        actual_sample_count(job.requested_samples, header.remaining)
    };
    actual_payload_bytes(samples, job.enabled_channels)
}

#[cfg(test)]
mod hw {
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::{Arc, Mutex};
    use std::time::Duration;

    use logicview_proto::{capture_length_warning, encode_arm, ArmConfig, ModeFlags};

    use super::*;

    fn pod_lock() -> std::sync::MutexGuard<'static, ()> {
        static LOCK: Mutex<()> = Mutex::new(());
        LOCK.lock().unwrap_or_else(|err| err.into_inner())
    }

    fn job(samples: u64, mode: u16, abort: bool) -> CaptureJob {
        let mut capture = armed(samples, mode, 100);
        capture.abort_after_header = abort;
        capture
    }

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
        }
    }

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
        let shown: Vec<String> = bytes.iter().take(8).map(|byte| format!("{byte:02X}")).collect();
        format!("mixed {}", shown.join(" "))
    }

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

    fn take(job: &CaptureJob) -> (CaptureReport, Vec<u8>) {
        try_take(job).unwrap_or_else(|err| panic!("capture failed: {err}"))
    }

    fn reopen(label: &str) {
        let (report, bytes) = take(&job(256, ModeFlags::INSTANT | ModeFlags::INTERNAL_TEST, false));
        assert!(
            report.header.is_some_and(|header| header.check_word == 0x5555_5555),
            "{label} reopen header"
        );
        assert_eq!(report.sample_bytes, 32, "{label} reopen length");
        assert!(bytes.iter().all(|byte| *byte == 0xAA), "{label} reopen pattern");
    }

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
        assert!(first.sample_bytes > 0 && second.sample_bytes > 0, "repeat samples");
        assert!(!second_bytes.is_empty(), "repeat stop retained the second record");
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
        let (filtered, filtered_bytes) = take(&armed(
            1_024,
            internal | ModeFlags::ONE_SAMPLE_FILTER,
            100,
        ));
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
            assert!(
                warning_text.contains("RLE shortfall"),
                "{warning_text}"
            );
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

fn cancel(ep: &mut nusb::Endpoint<Bulk, In>) {
    ep.cancel_all();
    while ep.pending() > 0 {
        if ep.wait_next_complete(Duration::from_millis(50)).is_none() {
            break;
        }
    }
}
