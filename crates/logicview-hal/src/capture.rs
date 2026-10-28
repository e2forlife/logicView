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
    pub stream: bool,
    pub stop: Arc<AtomicBool>,
    /// Cancel the sample pipe after a good header and return [`HalError::Interrupted`].
    pub abort_after_header: bool,
}

#[derive(Debug)]
pub struct CaptureReport {
    pub header: LogicHeader,
    pub sample_bytes: u64,
    pub overflow: bool,
    pub hw_status: u8,
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
    pod.arm_image(&job.image)?;

    let mut ep = pod
        .interface()
        .endpoint::<Bulk, In>(EP_IN)
        .map_err(|err| HalError::Usb(err.to_string()))?;
    for _ in 0..4 {
        ep.submit(Buffer::new(LOGIC_HEADER_TRANSFER));
    }
    pod.start()?;
    let Some(header_done) = ep.wait_next_complete(Duration::from_secs(2)) else {
        let _ = pod.stop();
        cancel(&mut ep);
        return Err(HalError::Interrupted("header transfer timed out".into()));
    };
    if header_done.status.is_err() || header_done.actual_len < LOGIC_HEADER_LEN {
        let _ = pod.stop();
        cancel(&mut ep);
        return Err(HalError::Interrupted(format!(
            "header transfer {:?} ({} bytes)",
            header_done.status, header_done.actual_len
        )));
    }
    let header = match parse_logic_header(&header_done.buffer[..LOGIC_HEADER_LEN]) {
        Ok(header) => header,
        Err(err) => {
            let _ = pod.stop();
            cancel(&mut ep);
            return Err(match err {
                ProtoError::BadCheckWord(word) => HalError::BadCheckWord(word),
                other => HalError::Message(other.to_string()),
            });
        }
    };

    emit(CaptureEvent::Header(header))?;
    if job.abort_after_header {
        cancel(&mut ep);
        let _ = pod.stop();
        return Err(HalError::Interrupted(
            "bulk IN cancelled after the header".into(),
        ));
    }

    let mut expected_samples = actual_sample_count(job.requested_samples, header.remaining);
    if job.stream && header.remaining == 0 {
        expected_samples = job.requested_samples & !63;
    }
    let expected_bytes = actual_payload_bytes(expected_samples, job.enabled_channels);
    let atom = (job.enabled_channels as usize).saturating_mul(8);
    let mut kept = 0u64;
    let mut pending = Vec::new();
    let mut failed: Option<HalError> = None;

    while kept < expected_bytes && failed.is_none() {
        if job.stop.load(Ordering::Relaxed) {
            break;
        }
        match ep.wait_next_complete(Duration::from_millis(400)) {
            Some(done) if done.status.is_ok() && done.actual_len > 0 => {
                let need = (expected_bytes - kept) as usize;
                let take = done.actual_len.min(need);
                pending.extend_from_slice(&done.buffer[..take]);
                kept += take as u64;
                let whole = pending.len() / atom * atom;
                if whole > 0 {
                    let chunk = pending[..whole].to_vec();
                    if let Err(err) = emit(CaptureEvent::Samples(chunk)) {
                        failed = Some(err);
                    }
                    pending.drain(..whole);
                }
                let short = done.actual_len < LOGIC_HEADER_TRANSFER;
                if !short && kept < expected_bytes && ep.pending() < 4 {
                    ep.submit(Buffer::new(LOGIC_HEADER_TRANSFER));
                }
                if short {
                    break;
                }
            }
            Some(done) => {
                failed = Some(HalError::Interrupted(format!(
                    "sample transfer {:?} ({} bytes)",
                    done.status, done.actual_len
                )));
            }
            None => {
                if job.stop.load(Ordering::Relaxed) {
                    break;
                }
                failed = Some(HalError::Interrupted(
                    "sample transfer timed out".into(),
                ));
            }
        }
    }

    let _ = pod.stop();
    cancel(&mut ep);
    let hw_status = pod.status().unwrap_or(0);
    if let Some(err) = failed {
        return Err(err);
    }
    Ok(CaptureReport {
        header,
        sample_bytes: kept.min(expected_bytes),
        overflow: hw_status & (1 << 4) != 0,
        hw_status,
    })
}

#[cfg(test)]
mod hw {
    use std::sync::atomic::AtomicBool;
    use std::sync::Arc;

    use logicview_proto::{encode_arm, ArmConfig, ModeFlags};

    use super::*;

    fn job(samples: u64, mode: u16, abort: bool) -> CaptureJob {
        let mut config = ArmConfig::default();
        config.mode = ModeFlags(mode);
        config.divider = 100;
        config.sample_count = samples;
        config.channel_count = 1;
        config.channel_enable = 1;
        CaptureJob {
            image: encode_arm(&config).unwrap(),
            enabled_channels: 1,
            requested_samples: samples,
            threshold: Some(crate::threshold_code(1.6)),
            stream: mode & ModeFlags::STREAM != 0,
            stop: Arc::new(AtomicBool::new(false)),
            abort_after_header: abort,
        }
    }

    #[test]
    #[ignore = "needs the plugged-in high-speed DSLogic Plus"]
    fn plus_buffer_header_count_and_interrupted_capture() {
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
        assert_eq!(report.header.check_word, 0x5555_5555);
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
        assert_eq!(longer.header.check_word, 0x5555_5555);
        assert_eq!(plain.len(), 128, "1024 samples on one channel is 128 bytes");

        let interrupted = run_capture(&job(4096, ModeFlags::INSTANT, true), |_| Ok(()));
        let message = interrupted.expect_err("cancelled capture").to_string();
        assert!(message.contains("interrupt"), "{message}");

        let again = run_capture(&job(256, ModeFlags::INSTANT, false), |_| Ok(())).expect("reopen");
        assert_eq!(again.header.check_word, 0x5555_5555);
        assert_eq!(again.sample_bytes, 32);
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
