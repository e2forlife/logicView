//! Facade over the demo capture session.
//!
//! Commands come from the UI (and, later, MCP). Events go out on a broadcast
//! bus. Snapshots stay inside the session; readers copy the bytes they need
//! under a short lock. There is no USB device in this crate.

mod run;

#[cfg(test)]
mod tests;

use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Duration;

use logicview_analysis::{find_edge, measure_pulse};
use logicview_capture::{planned_samples, AnalogStore, LogicStore, Phase, Session, DEMO_CHANNELS};
use logicview_store::{
    ArchiveData, ChannelManifest, Manifest, StoreError, TriggerManifest, MANIFEST_VERSION,
};
use serde::Serialize;
use thiserror::Error;
use tokio::sync::{broadcast, Mutex};

pub use logicview_analysis::PulseMetrics;
pub use logicview_capture::{AnalogColumn, Column, SessionConfig, StartMode};

const MAX_SESSIONS: usize = 8;

const CHANNELS: [(&str, &str); DEMO_CHANNELS] = [
    ("CLK", "#e2b340"),
    ("UART", "#3dcc8e"),
    ("SDA", "#5aa2ff"),
    ("SCL", "#c58bff"),
];
const ANALOG_NAME: &str = "SINE";
const ANALOG_COLOR: &str = "#ff8a5b";

#[derive(Debug, Error)]
pub enum EngineError {
    #[error("unknown session {0}")]
    UnknownSession(String),
    #[error("unknown device {0}; this build only connects to demo")]
    UnknownDevice(String),
    #[error("{0}")]
    Capture(#[from] logicview_capture::CaptureError),
    #[error("{0}")]
    Store(#[from] StoreError),
    #[error("timed out waiting for the capture")]
    Timeout,
    #[error("too many sessions")]
    TooManySessions,
}

#[derive(Clone, Debug, Serialize)]
pub struct DeviceInfo {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub connected: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct ChannelInfo {
    pub index: usize,
    pub name: String,
    pub color: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct AnalogInfo {
    pub index: usize,
    pub name: String,
    pub color: String,
}

#[derive(Clone, Debug, Serialize)]
pub struct Status {
    pub id: String,
    pub name: String,
    pub phase: String,
    pub sample_count: u64,
    pub sample_rate_hz: u64,
    pub duration_ms: u64,
    pub trigger_enabled: bool,
    pub trigger_percent: f64,
    pub trigger_sample: Option<u64>,
    pub instant: bool,
    pub realtime: bool,
    pub channels: Vec<ChannelInfo>,
    pub analog: Vec<AnalogInfo>,
    pub warnings: Vec<String>,
    pub error: Option<String>,
    pub active: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct SessionBrief {
    pub id: String,
    pub name: String,
    pub phase: String,
    pub sample_count: u64,
    pub active: bool,
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum EngineEvent {
    Phase {
        session: String,
        phase: String,
        sample_count: u64,
    },
    Appended {
        session: String,
        phase: String,
        sample_count: u64,
    },
    Stopped {
        session: String,
        phase: String,
        sample_count: u64,
    },
    Error {
        session: String,
        message: String,
    },
}

struct RunHandle {
    generation: u64,
    stop: Arc<AtomicBool>,
}

struct Slot {
    id: String,
    name: String,
    channel_names: Vec<String>,
    channel_colors: Vec<String>,
    session: Session,
}

struct State {
    slots: Vec<Slot>,
    active: usize,
    running: HashMap<String, RunHandle>,
    next_id: u64,
}

struct Shared {
    state: Mutex<State>,
    events: broadcast::Sender<EngineEvent>,
}

#[derive(Clone)]
pub struct Engine {
    shared: Arc<Shared>,
}

impl Engine {
    pub fn new() -> Self {
        let (events, _) = broadcast::channel(256);
        let slot = Slot::demo("ses-1", "Capture 1");
        let shared = Arc::new(Shared {
            state: Mutex::new(State {
                slots: vec![slot],
                active: 0,
                running: HashMap::new(),
                next_id: 2,
            }),
            events,
        });
        Self { shared }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<EngineEvent> {
        self.shared.events.subscribe()
    }

    pub async fn list_devices(&self) -> Vec<DeviceInfo> {
        vec![DeviceInfo {
            id: "demo".into(),
            name: "Demo".into(),
            kind: "demo".into(),
            connected: true,
        }]
    }

    pub async fn connect(&self, id: &str) -> Result<DeviceInfo, EngineError> {
        if id != "demo" {
            return Err(EngineError::UnknownDevice(id.to_string()));
        }
        Ok(self.list_devices().await.remove(0))
    }

    pub async fn list_sessions(&self) -> (Vec<SessionBrief>, String) {
        let state = self.shared.state.lock().await;
        let active = state.slots[state.active].id.clone();
        let sessions = state
            .slots
            .iter()
            .map(|slot| SessionBrief {
                id: slot.id.clone(),
                name: slot.name.clone(),
                phase: slot.session.phase.as_str().to_string(),
                sample_count: slot.session.store.len(),
                active: slot.id == active,
            })
            .collect();
        (sessions, active)
    }

    pub async fn create_session(&self, name: Option<String>) -> Result<SessionBrief, EngineError> {
        let mut state = self.shared.state.lock().await;
        if state.slots.len() >= MAX_SESSIONS {
            return Err(EngineError::TooManySessions);
        }
        let id_num = state.next_id;
        state.next_id += 1;
        let id = format!("ses-{id_num}");
        let label = name.unwrap_or_else(|| format!("Capture {id_num}"));
        state.slots.push(Slot::demo(&id, &label));
        state.active = state.slots.len() - 1;
        Ok(SessionBrief {
            id,
            name: label,
            phase: Phase::Idle.as_str().to_string(),
            sample_count: 0,
            active: true,
        })
    }

    pub async fn select_session(&self, id: &str) -> Result<(), EngineError> {
        let mut state = self.shared.state.lock().await;
        let index = state
            .slots
            .iter()
            .position(|slot| slot.id == id)
            .ok_or_else(|| EngineError::UnknownSession(id.to_string()))?;
        state.active = index;
        Ok(())
    }

    pub async fn configure(
        &self,
        id: Option<&str>,
        mut config: SessionConfig,
    ) -> Result<(), EngineError> {
        config.trigger_percent = if config.trigger_percent.is_finite() {
            config.trigger_percent.clamp(0.0, 100.0)
        } else {
            0.0
        };
        planned_samples(&config)?;
        let id = {
            let state = self.shared.state.lock().await;
            self.resolve(&state, id)?
        };
        let mut state = self.shared.state.lock().await;
        let slot = state.slot_mut(&id)?;
        if slot.session.phase.is_active() {
            return Err(logicview_capture::CaptureError::Busy.into());
        }
        slot.session.config = config;
        Ok(())
    }

    pub async fn start(&self, id: Option<&str>, mode: StartMode) -> Result<Status, EngineError> {
        let id = {
            let state = self.shared.state.lock().await;
            self.resolve(&state, id)?
        };
        let (source, realtime, rate, generation, stop) = {
            let mut state = self.shared.state.lock().await;
            let (source, generation, realtime, rate) = {
                let slot = state.slot_mut(&id)?;
                let config = slot.session.config.clone();
                let source = slot.session.begin(config, mode)?;
                let generation = slot.session.generation();
                let realtime = slot.session.config.realtime;
                let rate = slot.session.config.sample_rate_hz;
                (source, generation, realtime, rate)
            };
            let stop = Arc::new(AtomicBool::new(false));
            state.running.insert(
                id.clone(),
                RunHandle {
                    generation,
                    stop: Arc::clone(&stop),
                },
            );
            (source, realtime, rate, generation, stop)
        };
        tracing::info!(session = %id, realtime, rate, "demo capture started");
        let shared = Arc::clone(&self.shared);
        let task_id = id.clone();
        tokio::spawn(async move {
            run::drive(shared, task_id, source, generation, stop, realtime, rate).await;
        });
        self.status(Some(&id)).await
    }

    pub async fn stop(&self, id: Option<&str>) -> Result<Status, EngineError> {
        let id = {
            let state = self.shared.state.lock().await;
            self.resolve(&state, id)?
        };
        let flag = {
            let mut state = self.shared.state.lock().await;
            if let Ok(slot) = state.slot_mut(&id) {
                slot.session.request_stop();
            }
            state.running.get(&id).map(|run| Arc::clone(&run.stop))
        };
        if let Some(flag) = flag {
            flag.store(true, std::sync::atomic::Ordering::Relaxed);
            self.wait_until_settled(&id, Duration::from_secs(3)).await?;
        }
        self.status(Some(&id)).await
    }

    pub async fn wait_until_settled(
        &self,
        id: &str,
        timeout: Duration,
    ) -> Result<Status, EngineError> {
        let deadline = tokio::time::Instant::now() + timeout;
        loop {
            let status = self.status(Some(id)).await?;
            if matches!(status.phase.as_str(), "stopped" | "error" | "idle") {
                if status.phase == "error" {
                    return Err(EngineError::Capture(
                        logicview_capture::CaptureError::Proto(
                            status.error.unwrap_or_else(|| "capture failed".into()),
                        ),
                    ));
                }
                return Ok(status);
            }
            if tokio::time::Instant::now() >= deadline {
                return Err(EngineError::Timeout);
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
    }

    pub async fn status(&self, id: Option<&str>) -> Result<Status, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let active = state.slots[state.active].id.clone();
        let slot = state.slot(&id)?;
        Ok(slot.status(slot.id == active))
    }

    pub async fn search_edge(
        &self,
        id: Option<&str>,
        channel: usize,
        from: u64,
        rising: bool,
    ) -> Result<Option<u64>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let bytes = slot.session.store.channel_bytes(channel)?;
        let len = slot.session.store.len();
        Ok(find_edge(bytes, len, from, rising))
    }

    pub async fn measure(
        &self,
        id: Option<&str>,
        channel: usize,
        sample: u64,
    ) -> Result<PulseMetrics, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let bytes = slot.session.store.channel_bytes(channel)?;
        let len = slot.session.store.len();
        let rate = slot.session.config.sample_rate_hz;
        measure_pulse(bytes, len, sample, rate).ok_or_else(|| {
            EngineError::Capture(logicview_capture::CaptureError::Proto(
                "no pulse at that sample".into(),
            ))
        })
    }

    pub async fn analog_at(
        &self,
        id: Option<&str>,
        index: u64,
    ) -> Result<Option<f32>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        Ok(slot.session.analog.sample(index))
    }

    pub async fn tile(
        &self,
        id: Option<&str>,
        channel: usize,
        start: f64,
        columns: usize,
        spp: f64,
    ) -> Result<Vec<Column>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        Ok(slot.session.store.tile(channel, start, columns, spp)?)
    }

    pub async fn tile_analog(
        &self,
        id: Option<&str>,
        start: f64,
        columns: usize,
        spp: f64,
    ) -> Result<Vec<AnalogColumn>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        Ok(slot.session.analog.tile(start, columns, spp))
    }

    pub async fn arm_record(&self, id: Option<&str>) -> Result<Vec<u8>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        Ok(slot.session.arm.clone())
    }

    pub async fn save_lvcap(&self, id: Option<&str>, path: &Path) -> Result<(), EngineError> {
        let data = self.archive(id).await?;
        let is_file = path
            .extension()
            .and_then(|ext| ext.to_str())
            .is_some_and(|ext| ext.eq_ignore_ascii_case("lvcap"));
        if is_file {
            logicview_store::write_zip(path, &data)?;
        } else {
            logicview_store::write_directory(path, &data)?;
        }
        Ok(())
    }

    pub async fn load_lvcap(&self, id: Option<&str>, path: &Path) -> Result<Status, EngineError> {
        let data = logicview_store::read_any(path)?;
        self.install_archive(id, data).await
    }

    pub async fn export_zip(&self, id: Option<&str>) -> Result<Vec<u8>, EngineError> {
        let data = self.archive(id).await?;
        Ok(logicview_store::write_zip_bytes(&data)?)
    }

    async fn archive(&self, id: Option<&str>) -> Result<ArchiveData, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let sample_count = slot.session.store.len();
        let rate = slot.session.config.sample_rate_hz.max(1);
        let manifest = Manifest {
            version: MANIFEST_VERSION,
            software: format!("logicview {}", env!("CARGO_PKG_VERSION")),
            device: "demo".into(),
            mode: "logic".into(),
            sample_rate_hz: slot.session.config.sample_rate_hz,
            sample_count,
            duration_secs: sample_count as f64 / rate as f64,
            threshold_volts: 1.6,
            trigger: TriggerManifest {
                enabled: slot.session.config.trigger_enabled,
                position_samples: slot.session.trigger_sample,
                instant: slot.session.instant,
            },
            channels: slot
                .channel_names
                .iter()
                .zip(slot.channel_colors.iter())
                .enumerate()
                .map(|(index, (name, color))| ChannelManifest {
                    index: index as u32,
                    name: name.clone(),
                    color: color.clone(),
                })
                .collect(),
            analog_channels: if slot.session.analog.is_empty() { 0 } else { 1 },
        };
        Ok(ArchiveData {
            manifest,
            logic: slot.session.store.to_channels(),
            analog: slot.session.analog.samples().to_vec(),
        })
    }

    async fn install_archive(
        &self,
        id: Option<&str>,
        data: ArchiveData,
    ) -> Result<Status, EngineError> {
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let active = state.slots[state.active].id.clone();
        let slot = state.slot_mut(&id)?;
        if slot.session.phase.is_active() {
            return Err(logicview_capture::CaptureError::Busy.into());
        }
        let count = data.manifest.sample_count;
        slot.session.store = LogicStore::from_channels(data.logic, count)?;
        slot.session.analog = AnalogStore::from_samples(data.analog);
        slot.session.config.sample_rate_hz = data.manifest.sample_rate_hz;
        slot.session.total_samples = count;
        slot.session.config.duration_ms = (data.manifest.duration_secs * 1000.0).round() as u64;
        slot.session.config.trigger_enabled = data.manifest.trigger.enabled;
        slot.session.trigger_sample = data.manifest.trigger.position_samples;
        slot.session.instant = data.manifest.trigger.instant;
        slot.session.phase = Phase::Stopped;
        slot.session.error = None;
        slot.channel_names = data
            .manifest
            .channels
            .iter()
            .map(|channel| channel.name.clone())
            .collect();
        slot.channel_colors = data
            .manifest
            .channels
            .iter()
            .map(|channel| channel.color.clone())
            .collect();
        let is_active = slot.id == active;
        Ok(slot.status(is_active))
    }

    fn resolve(&self, state: &State, id: Option<&str>) -> Result<String, EngineError> {
        match id {
            Some(id) => {
                if state.slots.iter().any(|slot| slot.id == id) {
                    Ok(id.to_string())
                } else {
                    Err(EngineError::UnknownSession(id.to_string()))
                }
            }
            None => state
                .slots
                .get(state.active)
                .map(|slot| slot.id.clone())
                .ok_or_else(|| EngineError::UnknownSession("active".into())),
        }
    }
}

impl Default for Engine {
    fn default() -> Self {
        Self::new()
    }
}

impl Slot {
    fn demo(id: &str, name: &str) -> Self {
        Self {
            id: id.to_string(),
            name: name.to_string(),
            channel_names: CHANNELS
                .iter()
                .map(|(name, _)| (*name).to_string())
                .collect(),
            channel_colors: CHANNELS
                .iter()
                .map(|(_, color)| (*color).to_string())
                .collect(),
            session: Session::new(),
        }
    }

    fn status(&self, active: bool) -> Status {
        Status {
            id: self.id.clone(),
            name: self.name.clone(),
            phase: self.session.phase.as_str().to_string(),
            sample_count: self.session.store.len(),
            sample_rate_hz: self.session.config.sample_rate_hz,
            duration_ms: self.session.config.duration_ms,
            trigger_enabled: self.session.config.trigger_enabled,
            trigger_percent: self.session.config.trigger_percent,
            trigger_sample: self.session.trigger_sample,
            instant: self.session.instant,
            realtime: self.session.config.realtime,
            channels: self
                .channel_names
                .iter()
                .zip(self.channel_colors.iter())
                .enumerate()
                .map(|(index, (name, color))| ChannelInfo {
                    index,
                    name: name.clone(),
                    color: color.clone(),
                })
                .collect(),
            analog: vec![AnalogInfo {
                index: 0,
                name: ANALOG_NAME.into(),
                color: ANALOG_COLOR.into(),
            }],
            warnings: Vec::new(),
            error: self.session.error.clone(),
            active,
        }
    }
}

impl State {
    fn slot(&self, id: &str) -> Result<&Slot, EngineError> {
        self.slots
            .iter()
            .find(|slot| slot.id == id)
            .ok_or_else(|| EngineError::UnknownSession(id.to_string()))
    }

    fn slot_mut(&mut self, id: &str) -> Result<&mut Slot, EngineError> {
        self.slots
            .iter_mut()
            .find(|slot| slot.id == id)
            .ok_or_else(|| EngineError::UnknownSession(id.to_string()))
    }
}

impl Shared {
    pub(crate) async fn lock(&self) -> tokio::sync::MutexGuard<'_, State> {
        self.state.lock().await
    }

    pub(crate) fn emit(&self, event: EngineEvent) {
        let _ = self.events.send(event);
    }
}
