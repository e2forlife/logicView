//! USB capture thread. It owns the pod and posts chunks to the engine.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use logicview_capture::{Phase, RunPolicy};
use logicview_hal::{run_capture, CaptureEvent, CaptureJob, HalError, OnStop};
use logicview_proto::capture_length_warning;
use tokio::sync::mpsc;

use super::{EngineEvent, Shared};

enum Note {
    Event(CaptureEvent),
    End(Result<logicview_hal::CaptureReport, HalError>),
}

pub(crate) async fn drive(
    shared: Arc<Shared>,
    id: String,
    generation: u64,
    stop: Arc<AtomicBool>,
    image: Vec<u8>,
    enabled: u64,
    samples: u64,
    threshold: Option<u8>,
    stream: bool,
    run: RunPolicy,
    interval: Duration,
    discard: bool,
    continuous: bool,
    header_wait: Duration,
) {
    let mut pass = 0u32;
    loop {
        if stop.load(Ordering::Relaxed) {
            settle(&shared, &id, generation, None, discard && pass > 0).await;
            break;
        }
        pass += 1;
        let (tx, mut rx) = mpsc::channel(32);
        let job = CaptureJob {
            image: image.clone(),
            enabled_channels: enabled,
            requested_samples: samples,
            threshold,
            stream,
            continuous,
            stop: Arc::clone(&stop),
            on_stop: if discard { OnStop::Discard } else { OnStop::Upload },
            abort_after_header: false,
            header_wait,
            sample_limit: None,
        };
        let tx_thread = tx.clone();
        let worker = std::thread::spawn(move || {
            let result = run_capture(&job, |event| {
                tx_thread
                    .blocking_send(Note::Event(event))
                    .map_err(|_| HalError::Interrupted("the engine stopped reading".into()))
            });
            let _ = tx_thread.blocking_send(Note::End(result));
        });
        drop(tx);

        let mut failed: Option<String> = None;
        let mut saw_end = false;
        while let Some(note) = rx.recv().await {
            match note {
                Note::Event(CaptureEvent::Header(header)) => {
                    apply_header(&shared, &id, generation, header).await;
                }
                Note::Event(CaptureEvent::Samples(chunk)) => {
                    let dropping = discard && stop.load(Ordering::Relaxed);
                    if !dropping {
                        let count = (chunk.len() as u64) * 8 / enabled.max(1);
                        if let Err(err) = apply_samples(&shared, &id, generation, &chunk, count).await
                        {
                            failed = Some(err);
                            stop.store(true, Ordering::Relaxed);
                        }
                    }
                }
                Note::End(Ok(report)) => {
                    saw_end = true;
                    if report.overflow {
                        warn(&shared, &id, generation, "sample memory overflowed".into()).await;
                    }
                    if !stream && !report.discarded {
                        if let Some(header) = report.header {
                            let rle = {
                                let state = shared.lock().await;
                                state
                                    .slots
                                    .iter()
                                    .find(|slot| slot.id == id)
                                    .map(|slot| slot.session.config.rle)
                                    .unwrap_or(false)
                            };
                            if let Some(text) =
                                capture_length_warning(rle, samples, header.remaining)
                            {
                                warn(&shared, &id, generation, text).await;
                            }
                        }
                    }
                }
                Note::End(Err(err)) => {
                    saw_end = true;
                    failed = Some(err.to_string());
                }
            }
        }
        let _ = worker.join();
        if let Some(message) = failed {
            settle(&shared, &id, generation, Some(message), false).await;
            break;
        }
        if !saw_end {
            settle(
                &shared,
                &id,
                generation,
                Some("capture ended without a result".into()),
                false,
            )
            .await;
            break;
        }
        if run == RunPolicy::Loop {
            trim(&shared, &id, generation, samples).await;
        }
        if stop.load(Ordering::Relaxed) || run == RunPolicy::Single {
            settle(&shared, &id, generation, None, discard).await;
            break;
        }
        if run == RunPolicy::Repeat {
            clear_samples(&shared, &id, generation).await;
            tokio::time::sleep(interval).await;
        }
    }
}

async fn apply_header(
    shared: &Shared,
    id: &str,
    generation: u64,
    header: logicview_proto::LogicHeader,
) {
    let mut state = shared.lock().await;
    let Some(slot) = state.slots.iter_mut().find(|slot| slot.id == id) else {
        return;
    };
    if slot.session.generation() != generation {
        return;
    }
    slot.session.on_header(header);
    let phase = slot.session.phase.as_str().to_string();
    let sample_count = slot.session.store.len();
    shared.emit(EngineEvent::Phase {
        session: id.to_string(),
        phase,
        sample_count,
    });
}

async fn apply_samples(
    shared: &Shared,
    id: &str,
    generation: u64,
    chunk: &[u8],
    samples: u64,
) -> Result<(), String> {
    let mut state = shared.lock().await;
    let Some(slot) = state.slots.iter_mut().find(|slot| slot.id == id) else {
        return Ok(());
    };
    if slot.session.generation() != generation {
        return Ok(());
    }
    slot.session
        .on_samples(chunk, &[], samples)
        .map_err(|err| err.to_string())?;
    let phase = slot.session.phase.as_str().to_string();
    let sample_count = slot.session.store.len();
    shared.emit(EngineEvent::Appended {
        session: id.to_string(),
        phase,
        sample_count,
    });
    Ok(())
}

async fn warn(shared: &Shared, id: &str, generation: u64, message: String) {
    let mut state = shared.lock().await;
    let Some(slot) = state.slots.iter_mut().find(|slot| slot.id == id) else {
        return;
    };
    if slot.session.generation() == generation {
        slot.session.warn(message);
    }
}

async fn trim(shared: &Shared, id: &str, generation: u64, samples: u64) {
    let mut state = shared.lock().await;
    let Some(slot) = state.slots.iter_mut().find(|slot| slot.id == id) else {
        return;
    };
    if slot.session.generation() == generation {
        slot.session.store.retain_tail(samples);
    }
}

async fn clear_samples(shared: &Shared, id: &str, generation: u64) {
    let mut state = shared.lock().await;
    let Some(slot) = state.slots.iter_mut().find(|slot| slot.id == id) else {
        return;
    };
    if slot.session.generation() == generation {
        let width = slot.session.store.channel_count();
        slot.session.store = logicview_capture::LogicStore::new(width);
        slot.session.phase = Phase::Arming;
    }
}

async fn settle(
    shared: &Shared,
    id: &str,
    generation: u64,
    error: Option<String>,
    discard: bool,
) {
    let mut state = shared.lock().await;
    let Some(index) = state.slots.iter().position(|slot| slot.id == id) else {
        return;
    };
    if state.slots[index].session.generation() != generation {
        return;
    }
    if discard {
        let width = state.slots[index].session.store.channel_count();
        state.slots[index].session.store = logicview_capture::LogicStore::new(width);
    }
    if let Some(message) = error.clone() {
        state.slots[index].session.fail(message);
    } else if state.slots[index].session.phase != Phase::Error {
        state.slots[index].session.finish();
    }
    state.running.retain(|key, run| key != id || run.generation != generation);
    let phase = state.slots[index].session.phase.as_str().to_string();
    let sample_count = state.slots[index].session.store.len();
    let event = if let Some(message) = error {
        EngineEvent::Error {
            session: id.to_string(),
            message,
        }
    } else {
        EngineEvent::Stopped {
            session: id.to_string(),
            phase,
            sample_count,
        }
    };
    shared.emit(event);
}
