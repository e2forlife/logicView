//! Drives synthetic captures and turns source events into shared session updates.
//!
//! Every update checks the capture generation so an older task cannot overwrite
//! a newer acquisition for the same session.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use logicview_capture::Feed;

use super::{EngineEvent, Shared};

/// Feeds a demo source into the session, publishes progress, and optionally paces live playback.
pub(crate) async fn drive(
    shared: Arc<Shared>,
    id: String,
    mut source: logicview_capture::DemoSource,
    generation: u64,
    stop: Arc<AtomicBool>,
    realtime: bool,
    rate: u64,
) {
    loop {
        if stop.load(Ordering::Relaxed) && settle(&shared, &id, generation, None).await {
            break;
        }
        let feed = match source.poll() {
            Ok(feed) => feed,
            Err(err) => {
                let _ = settle(&shared, &id, generation, Some(err.to_string())).await;
                break;
            }
        };

        let event;
        let mut chunk_samples = 0u64;
        let mut stop_after = false;
        {
            let mut state = shared.lock().await;
            let Some(index) = state.slots.iter().position(|slot| slot.id == id) else {
                break;
            };
            if state.slots[index].session.generation() != generation {
                break;
            }
            let mut failed = None;
            match feed {
                Feed::Header(header) => {
                    state.slots[index].session.on_header(header);
                }
                Feed::Samples {
                    atoms,
                    analog,
                    samples,
                    ..
                } => match state.slots[index]
                    .session
                    .on_samples(&atoms, &analog, samples)
                {
                    Ok(()) => chunk_samples = samples,
                    Err(err) => failed = Some(err.to_string()),
                },
                Feed::End => {
                    state.slots[index].session.finish();
                    super::decode_cmd::rerun(&mut state.slots[index]);
                    clear_run(&mut state, &id, generation);
                    stop_after = true;
                }
            }
            if let Some(message) = failed {
                state.slots[index].session.fail(message.clone());
                clear_run(&mut state, &id, generation);
                event = Some(EngineEvent::Error {
                    session: id.clone(),
                    message,
                });
                stop_after = true;
            } else {
                let phase = state.slots[index].session.phase.as_str().to_string();
                let sample_count = state.slots[index].session.store.len();
                event = Some(if stop_after {
                    EngineEvent::Stopped {
                        session: id.clone(),
                        phase,
                        sample_count,
                    }
                } else if chunk_samples > 0 {
                    EngineEvent::Appended {
                        session: id.clone(),
                        phase,
                        sample_count,
                    }
                } else {
                    EngineEvent::Phase {
                        session: id.clone(),
                        phase,
                        sample_count,
                    }
                });
            }
        }
        if let Some(event) = event {
            shared.emit(event);
        }
        if stop_after {
            break;
        }
        if stop.load(Ordering::Relaxed) && settle(&shared, &id, generation, None).await {
            break;
        }
        if realtime && chunk_samples > 0 {
            let secs = chunk_samples as f64 / rate.max(1) as f64;
            let delay = Duration::from_secs_f64(secs)
                .min(Duration::from_millis(40))
                .max(Duration::from_millis(8));
            tokio::time::sleep(delay).await;
        } else {
            tokio::task::yield_now().await;
        }
    }
}

/// Returns true when this task still owned the session and marked it finished.
async fn settle(shared: &Shared, id: &str, generation: u64, error: Option<String>) -> bool {
    let event = {
        let mut state = shared.lock().await;
        let Some(index) = state.slots.iter().position(|slot| slot.id == id) else {
            return false;
        };
        if state.slots[index].session.generation() != generation {
            return false;
        }
        if let Some(message) = error.clone() {
            state.slots[index].session.fail(message);
        } else {
            state.slots[index].session.finish();
            super::decode_cmd::rerun(&mut state.slots[index]);
        }
        clear_run(&mut state, id, generation);
        let phase = state.slots[index].session.phase.as_str().to_string();
        let sample_count = state.slots[index].session.store.len();
        if let Some(message) = error {
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
        }
    };
    shared.emit(event);
    true
}

/// Removes the running handle only when it still belongs to this capture generation.
fn clear_run(state: &mut super::State, id: &str, generation: u64) {
    if state
        .running
        .get(id)
        .is_some_and(|run| run.generation == generation)
    {
        state.running.remove(id);
    }
}
