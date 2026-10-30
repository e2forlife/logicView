//! Facade over capture sessions.
//!
//! Commands come from the UI and from MCP. A session can stack more than one
//! demo pod into a single channel list. Events go out on a broadcast bus.
//!
//! # Finding the right layer
//!
//! [`Engine`] is the command boundary shared by the UI and MCP. Its methods
//! resolve sessions and validate requests before changing capture state.
//! `run` drives demo sources; `usb` bridges blocking device acquisition into
//! asynchronous updates. Both publish [`EngineEvent`] notifications.
//!
//! Capture lifecycle and sample storage live in `logicview-capture`; USB
//! transfers and hardware limits live in `logicview-hal`. Decoder commands
//! and annotation ordering live in `decode_cmd`. File encoding belongs to
//! `logicview-store`, while `samples_export` renders sample tables.
//!
//! A session owns its devices, samples, decoders, cursors, and measurements.
//! Commands with no session identifier use the selected session. Workers carry
//! a capture generation and check it before updating state; keep that check
//! when adding background work.

mod decode_cmd;
mod run;
mod samples_export;
mod usb;

#[cfg(test)]
mod tests;

use std::collections::{BTreeMap, HashMap};
use std::path::Path;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Duration;

use logicview_analysis::{
    cursor_span, find_edge, find_edge_before, find_pattern, measure_pulse, nearest_edge,
};
use logicview_capture::{
    demo_pod, planned_samples, AnalogStore, HostClock, LogicStore, Phase, Session,
};
use logicview_proto::DepthMode;
use logicview_store::{
    ArchiveData, ChannelManifest, Manifest, StoreError, TriggerManifest, MANIFEST_VERSION,
};
use serde::Serialize;
use thiserror::Error;
use tokio::sync::{broadcast, Mutex};

pub use logicview_analysis::{CursorSpan, PulseMetrics};
pub use logicview_capture::{
    AnalogColumn, Column, RunPolicy, SessionConfig, StartMode, TriggerKind,
};

const MAX_SESSIONS: usize = 8;

const ANALOG_NAME: &str = "SINE";

/// An engine command could not resolve, configure, capture, analyze, or persist a session.
#[derive(Debug, Error)]
pub enum EngineError {
    #[error("unknown session {0}")]
    UnknownSession(String),
    #[error("{0}")]
    UnknownDevice(String),
    #[error("{0}")]
    Decode(String),
    #[error("{0}")]
    Capture(#[from] logicview_capture::CaptureError),
    #[error("{0}")]
    Store(#[from] StoreError),
    #[error("timed out waiting for the capture")]
    Timeout,
    #[error("{0}")]
    Device(String),
    #[error("too many sessions")]
    TooManySessions,
}

/// Serializable sampling ceiling for an inclusive channel-count band.
#[derive(Clone, Debug, Serialize)]
pub struct RateBandInfo {
    pub max_channels: u32,
    pub max_hz: u64,
}

/// Client-facing hardware profile with capabilities and verification status.
#[derive(Clone, Debug, Serialize)]
pub struct ProfileInfo {
    pub id: String,
    pub product_id: u16,
    pub name: String,
    pub channels: u8,
    pub hardware_tested: bool,
    pub note: String,
    /// Inclusive channel ceilings. Enabling more channels moves to a lower band.
    pub buffer_rates: Vec<RateBandInfo>,
    pub stream_rates: Vec<RateBandInfo>,
    /// Stream ceilings when the bound U3Pro32 enumerated at SuperSpeed.
    /// High-speed links keep [`Self::stream_rates`].
    pub super_stream_rates: Vec<RateBandInfo>,
}

/// A discovered or bound device as presented to UI and automation clients.
#[derive(Clone, Debug, Serialize)]
pub struct DeviceInfo {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub connected: bool,
    /// The USB link enumerated at SuperSpeed. Demo and file devices stay false.
    pub super_speed: bool,
}

/// A sampled channel's display identity and originating device.
#[derive(Clone, Debug, Serialize)]
pub struct ChannelInfo {
    pub index: usize,
    pub name: String,
    pub color: String,
    pub device_id: String,
    pub device_name: String,
}

/// Display metadata for an analog waveform lane.
#[derive(Clone, Debug, Serialize)]
pub struct AnalogInfo {
    pub index: usize,
    pub name: String,
    pub color: String,
}

/// Consistent session snapshot shared by the UI and automation interfaces.
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
    /// Every logic probe on the connected devices. `index` is the enable bit.
    pub probes: Vec<ChannelInfo>,
    /// Zero means every probe is sampled. Otherwise each set bit is one probe.
    pub channel_enable: u32,
    pub devices: Vec<DeviceInfo>,
    pub analog: Vec<AnalogInfo>,
    pub warnings: Vec<String>,
    pub error: Option<String>,
    pub active: bool,
}

/// Compact session summary used to build the workspace session list.
#[derive(Clone, Debug, Serialize)]
pub struct SessionBrief {
    pub id: String,
    pub name: String,
    pub phase: String,
    pub sample_count: u64,
    pub active: bool,
}

/// Live notification that a session changed phase, gained samples, stopped, or failed.
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

/// Identifies a running capture generation and its cooperative stop flag.
struct RunHandle {
    pub(crate) generation: u64,
    stop: Arc<AtomicBool>,
}

/// Pulse measurement retained independently of subsequent cursor movement.
#[derive(Clone, Debug, Serialize)]
pub struct SavedMeasurement {
    pub id: u64,
    pub channel: usize,
    pub sample: u64,
    pub pulse_width_samples: u64,
    pub period_samples: Option<u64>,
    pub frequency_hz: Option<f64>,
    pub duty: Option<f64>,
}

/// Device identity and link capabilities assigned to a session.
pub(crate) struct BoundDevice {
    id: String,
    name: String,
    kind: String,
    super_speed: bool,
}

/// Maps a displayed channel back to its device when multiple demo sources are stacked.
#[derive(Clone)]
pub(crate) struct ChannelOrigin {
    device_id: String,
    device_name: String,
}

/// Configured decoder instance, including channel bindings and any lower-level dependency.
pub(crate) struct DecoderInst {
    id: String,
    protocol: String,
    channels: BTreeMap<String, usize>,
    options: BTreeMap<String, String>,
    region: Option<(u64, u64)>,
    stack_on: Option<String>,
}

/// Client-facing settings and bindings of an installed decoder.
#[derive(Clone, Debug, Serialize)]
pub struct DecoderInfo {
    pub id: String,
    pub protocol: String,
    pub channels: BTreeMap<String, usize>,
    pub options: BTreeMap<String, String>,
    pub stack_on: Option<String>,
}

/// Decoded event tagged with its analyzer instance for tables, search, and exports.
#[derive(Clone, Debug, Serialize)]
pub struct AnnotationRow {
    pub decoder: String,
    pub protocol: String,
    pub start_sample: u64,
    pub end_sample: u64,
    pub class: String,
    pub text: String,
    pub fields: BTreeMap<String, String>,
}

/// All capture, device, and analysis state belonging to one workspace session.
///
/// Catalog fields preserve every probe; sampled-channel fields follow the
/// current enable mask and therefore match the order of stored channel bytes.
struct Slot {
    pub(crate) id: String,
    name: String,
    pub(crate) channel_names: Vec<String>,
    channel_colors: Vec<String>,
    pub(crate) origins: Vec<ChannelOrigin>,
    catalog_names: Vec<String>,
    catalog_colors: Vec<String>,
    catalog_origins: Vec<ChannelOrigin>,
    pub(crate) devices: Vec<BoundDevice>,
    pub(crate) decoders: Vec<DecoderInst>,
    pub(crate) annotations: Vec<AnnotationRow>,
    next_decoder: u64,
    pub(crate) session: Session,
    cursors: [Option<u64>; 2],
    measurements: Vec<SavedMeasurement>,
    next_measure: u64,
}

/// Mutable workspace state protected by the engine's asynchronous mutex.
struct State {
    pub(crate) slots: Vec<Slot>,
    active: usize,
    pub(crate) running: HashMap<String, RunHandle>,
    next_id: u64,
    device: String,
}

/// State and event bus shared by client commands and background capture workers.
struct Shared {
    state: Mutex<State>,
    events: broadcast::Sender<EngineEvent>,
}

/// Cloneable command facade used by desktop, HTTP, and MCP clients.
///
/// Clones share one workspace. Commands serialize state access through a mutex;
/// long-running acquisition is handed to background workers identified by
/// session generation so stale workers cannot update a newer capture.
#[derive(Clone)]
pub struct Engine {
    shared: Arc<Shared>,
}

impl Engine {
    /// Creates a shared engine with one demo session ready for UI or automation commands.
    pub fn new() -> Self {
        let (events, _) = broadcast::channel(256);
        let slot = Slot::demo("ses-1", "Capture 1");
        let shared = Arc::new(Shared {
            state: Mutex::new(State {
                slots: vec![slot],
                active: 0,
                running: HashMap::new(),
                next_id: 2,
                device: "demo".into(),
            }),
            events,
        });
        Self { shared }
    }

    /// Subscribes to live session changes; consumers must tolerate lag on the bounded event bus.
    pub fn subscribe(&self) -> broadcast::Receiver<EngineEvent> {
        self.shared.events.subscribe()
    }

    /// Lists known model profiles and sampling limits without probing connected hardware.
    pub async fn list_profiles(&self) -> Vec<ProfileInfo> {
        logicview_hal::logic_profiles()
            .iter()
            .map(|profile| ProfileInfo {
                id: format!("usb:2a0e:{:04x}", profile.product_id),
                product_id: profile.product_id,
                name: profile.name.to_string(),
                channels: profile.channels,
                hardware_tested: profile.hardware_tested,
                note: profile.note.to_string(),
                buffer_rates: rate_bands(profile.product_id, false, false),
                stream_rates: rate_bands(profile.product_id, true, false),
                super_stream_rates: rate_bands(profile.product_id, true, true),
            })
            .collect()
    }

    /// Discovers connected USB devices and available demos, presenting physical hardware first.
    pub async fn list_devices(&self) -> Vec<DeviceInfo> {
        let mut devices: Vec<DeviceInfo> = logicview_capture::demo_pods()
            .iter()
            .map(|pod| demo_device_info(pod.id))
            .collect();
        match logicview_hal::list_pods() {
            Ok(pods) => {
                for pod in pods {
                    devices.push(DeviceInfo {
                        id: pod.id,
                        name: pod.name,
                        kind: "usb".into(),
                        connected: true,
                        super_speed: pod.super_speed,
                    });
                }
            }
            Err(err) => tracing::warn!("USB scan failed: {err}"),
        }
        hardware_before_demo(devices)
    }

    /// Selects a demo or opens a verified hardware model and installs its channels in the active
    /// session.
    pub async fn connect(&self, id: &str) -> Result<DeviceInfo, EngineError> {
        if demo_pod(id).is_some() {
            self.set_active_devices(&[id.to_string()]).await?;
            let mut state = self.shared.state.lock().await;
            state.device = id.into();
            return Ok(demo_device_info(id));
        }
        if let Some(pid) = usb_product_id(id) {
            let Some(profile) = logicview_hal::logic_profile(pid) else {
                return Err(EngineError::UnknownDevice(format!(
                    "{id} (unknown product, 0 channels) is not opened: no hardware test for this product id"
                )));
            };
            let canonical = format!("usb:{:04x}:{:04x}", logicview_hal::VENDOR_ID, pid);
            if !profile.hardware_tested || id != canonical {
                return Err(EngineError::UnknownDevice(format!(
                    "{id} ({}, {} channels) is not opened: no hardware test for this product id",
                    profile.name, profile.channels
                )));
            }
            let pod = logicview_hal::Pod::open_product(Some(pid))
                .map_err(|err| EngineError::Device(err.to_string()))?;
            let super_speed = pod.link_is_super();
            let info = DeviceInfo {
                id: id.into(),
                name: format!(
                    "{} fw {}.{} ({:04x}:{:04x})",
                    profile.name,
                    pod.firmware_major,
                    pod.firmware_minor,
                    logicview_hal::VENDOR_ID,
                    pid
                ),
                kind: "usb".into(),
                connected: true,
                super_speed,
            };
            drop(pod);
            {
                let mut state = self.shared.state.lock().await;
                state.device = id.into();
            }
            let mask = if profile.channels >= 32 {
                u32::MAX
            } else {
                (1u32 << profile.channels) - 1
            };
            self.use_pod_channels(mask, id, profile.name, super_speed)
                .await;
            return Ok(info);
        }
        Err(EngineError::UnknownDevice(format!(
            "unknown device {id}; open demo, demo:spi, or a tested pod ({}, {})",
            logicview_hal::DEVICE_ID,
            logicview_hal::U3_DEVICE_ID
        )))
    }

    /// Adds another demo device to a stopped session; physical multi-device capture is not yet
    /// verified.
    pub async fn attach_device(
        &self,
        id: Option<&str>,
        device_id: &str,
    ) -> Result<Status, EngineError> {
        let pod = demo_pod(device_id).ok_or_else(|| {
            if usb_product_id(device_id).is_some() {
                EngineError::UnknownDevice(format!(
                    "attach {device_id} is refused: stacking USB pods in one capture is not verified. Use demo and demo:spi."
                ))
            } else {
                EngineError::UnknownDevice(format!("unknown device {device_id}"))
            }
        })?;
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot_mut(&id)?;
        if slot.session.phase.is_active() {
            return Err(logicview_capture::CaptureError::Busy.into());
        }
        if slot.devices.iter().any(|device| device.kind != "demo") {
            return Err(EngineError::Device(
                "this session is on a USB pod; stacking a demo onto it is not supported".into(),
            ));
        }
        if slot.devices.iter().any(|device| device.id == device_id) {
            return Ok(slot.status(true));
        }
        let mut ids: Vec<String> = slot
            .devices
            .iter()
            .map(|device| device.id.clone())
            .collect();
        ids.push(pod.id.to_string());
        install_demo_ids(slot, &ids)?;
        Ok(slot.status(true))
    }

    /// Removes a device from a stopped demo session while keeping at least one source.
    pub async fn detach_device(
        &self,
        id: Option<&str>,
        device_id: &str,
    ) -> Result<Status, EngineError> {
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot_mut(&id)?;
        if slot.session.phase.is_active() {
            return Err(logicview_capture::CaptureError::Busy.into());
        }
        if slot.devices.len() <= 1 {
            return Err(EngineError::Device(
                "a session keeps at least one device".into(),
            ));
        }
        let ids: Vec<String> = slot
            .devices
            .iter()
            .filter(|device| device.id != device_id)
            .map(|device| device.id.clone())
            .collect();
        if ids.len() == slot.devices.len() {
            return Err(EngineError::UnknownDevice(format!(
                "device {device_id} is not in this session"
            )));
        }
        install_demo_ids(slot, &ids)?;
        Ok(slot.status(true))
    }

    /// Replaces the active session's demo device set when no capture is running.
    async fn set_active_devices(&self, ids: &[String]) -> Result<(), EngineError> {
        let mut state = self.shared.state.lock().await;
        let active = state.active;
        let slot = state
            .slots
            .get_mut(active)
            .ok_or_else(|| EngineError::UnknownSession("active".into()))?;
        if slot.session.phase.is_active() {
            return Err(logicview_capture::CaptureError::Busy.into());
        }
        install_demo_ids(slot, ids)?;
        Ok(())
    }

    /// Returns session summaries together with the selected session identifier.
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

    /// Creates and selects a new demo session, enforcing the workspace session limit.
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

    /// Selects the session used by commands that omit an explicit identifier.
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

    /// Validates and stores capture settings while the session is inactive.
    ///
    /// Trigger placement is bounded and rates above the selected device's ceiling
    /// are lowered to that ceiling before the capture size is checked.
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
        let id = {
            let state = self.shared.state.lock().await;
            self.resolve(&state, id)?
        };
        let mut state = self.shared.state.lock().await;
        let slot = state.slot_mut(&id)?;
        if slot.session.phase.is_active() {
            return Err(logicview_capture::CaptureError::Busy.into());
        }
        clamp_sample_rate(slot, &mut config);
        planned_samples(&config)?;
        logicview_capture::check_trigger(&config)?;
        slot.session.config = config;
        Ok(())
    }

    /// Prepares and schedules a demo or USB capture, returning the current session status.
    ///
    /// Capture work continues asynchronously. Use events or `wait_until_settled`
    /// when a caller needs the completed record rather than the initial state.
    pub async fn start(&self, id: Option<&str>, mode: StartMode) -> Result<Status, EngineError> {
        let id = {
            let state = self.shared.state.lock().await;
            self.resolve(&state, id)?
        };
        let usb = {
            let state = self.shared.state.lock().await;
            let slot = state.slot(&id)?;
            session_uses_usb(&slot.devices)?
        };
        if usb {
            return self.start_usb(Some(&id), mode).await;
        }
        let (source, realtime, rate, generation, stop) = {
            let mut state = self.shared.state.lock().await;
            let (source, generation, realtime, rate) = {
                let slot = state.slot_mut(&id)?;
                let config = slot.session.config.clone();
                let mask = config.channel_enable;
                let waves = demo_waves_masked(&slot.devices, mask)?;
                apply_sampled_channels(slot, mask)?;
                let mut packed = config;
                packed.channel_enable = 0;
                let source = slot.session.begin(packed, mode, waves)?;
                slot.session.config.channel_enable = mask;
                slot.annotations.clear();
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

    /// Requests capture termination and waits briefly for the source to settle.
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

    /// Waits for a session to become idle or stopped, reporting capture errors and timeouts.
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

    /// Returns a consistent snapshot of the requested session or the selected session.
    pub async fn status(&self, id: Option<&str>) -> Result<Status, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let active = state.slots[state.active].id.clone();
        let slot = state.slot(&id)?;
        Ok(slot.status(slot.id == active))
    }

    /// Searches original channel samples for the next or previous transition of the requested
    /// polarity.
    pub async fn search_edge(
        &self,
        id: Option<&str>,
        channel: usize,
        from: u64,
        rising: bool,
        forward: bool,
    ) -> Result<Option<u64>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let bytes = slot.session.store.channel_bytes(channel)?;
        let len = slot.session.store.len();
        Ok(if forward {
            find_edge(bytes, len, from, rising)
        } else {
            find_edge_before(bytes, len, from, rising)
        })
    }

    /// Finds the closest transition for waveform cursor snapping.
    pub async fn nearest_edge(
        &self,
        id: Option<&str>,
        channel: usize,
        sample: u64,
    ) -> Result<Option<u64>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let bytes = slot.session.store.channel_bytes(channel)?;
        let len = slot.session.store.len();
        Ok(nearest_edge(bytes, len, sample))
    }

    /// Measures the pulse at a capture position using original samples and the session sample rate.
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

    /// Reads a retained analog value, returning `None` outside the recorded analog data.
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

    /// Returns digital drawing summaries for a viewport expressed in capture sample coordinates.
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

    /// Returns analog drawing envelopes for a viewport expressed in capture sample coordinates.
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

    /// Validates device-specific capture limits, prepares arm bytes, and schedules the USB worker.
    async fn start_usb(&self, id: Option<&str>, mode: StartMode) -> Result<Status, EngineError> {
        let id = {
            let state = self.shared.state.lock().await;
            self.resolve(&state, id)?
        };
        let (
            generation,
            stop,
            image,
            enabled,
            samples,
            threshold,
            stream,
            run,
            interval,
            discard,
            continuous,
            header_wait,
            product_id,
        ) = {
            let mut state = self.shared.state.lock().await;
            let slot_ref = state.slot(&id)?;
            let config = slot_ref.session.config.clone();
            let device_id = slot_ref
                .devices
                .first()
                .map(|device| device.id.clone())
                .unwrap_or_else(|| logicview_hal::DEVICE_ID.to_string());
            let device_name = slot_ref
                .devices
                .first()
                .map(|device| device.name.clone())
                .unwrap_or_else(|| "DSLogic Plus".to_string());
            let pid = usb_product_id(&device_id).unwrap_or(logicview_hal::PLUS_PID);
            let profile_channels = logicview_hal::logic_profile(pid)
                .map(|profile| usize::from(profile.channels))
                .unwrap_or(16);
            let mask = if config.channel_enable == 0 {
                if profile_channels >= 32 {
                    u32::MAX
                } else {
                    (1u32 << profile_channels) - 1
                }
            } else {
                config.channel_enable
            };
            let clock = if pid == logicview_hal::U3PRO32_PID {
                let planned = logicview_hal::plan_u3_link(
                    config.sample_rate_hz,
                    mask,
                    config.depth == DepthMode::Stream,
                    bound_link_is_super(&slot_ref.devices),
                )
                .map_err(|err| {
                    EngineError::Capture(logicview_capture::CaptureError::Proto(err.to_string()))
                })?;
                HostClock {
                    hw_max_hz: planned.hw_max_hz,
                    half_rate_hz: Some(planned.half_rate_hz),
                    quarter_rate_hz: Some(planned.quarter_rate_hz),
                    pre_divider: planned.pre_divider,
                    ext_record: true,
                }
            } else {
                logicview_hal::plan_clock(
                    config.sample_rate_hz,
                    mask,
                    config.depth == DepthMode::Stream,
                )
                .map_err(|err| {
                    EngineError::Capture(logicview_capture::CaptureError::Proto(err.to_string()))
                })?;
                HostClock {
                    hw_max_hz: logicview_hal::HW_CLOCK_HZ,
                    half_rate_hz: Some(logicview_hal::HALF_RATE_HZ),
                    quarter_rate_hz: Some(logicview_hal::QUARTER_RATE_HZ),
                    pre_divider: 1,
                    ext_record: false,
                }
            };
            let slot = state.slot_mut(&id)?;
            let samples = slot
                .session
                .prepare(config.clone(), mode, profile_channels, clock)?;
            if slot.catalog_names.is_empty() {
                remember_catalog(slot);
            }
            let (names, colors) = pod_channel_style(mask);
            slot.origins = names
                .iter()
                .map(|_| ChannelOrigin {
                    device_id: device_id.clone(),
                    device_name: device_name.clone(),
                })
                .collect();
            slot.channel_names = names;
            slot.channel_colors = colors;
            slot.annotations.clear();
            let generation = slot.session.generation();
            let stop = Arc::new(AtomicBool::new(false));
            let image = slot.session.arm.clone();
            state.running.insert(
                id.clone(),
                RunHandle {
                    generation,
                    stop: Arc::clone(&stop),
                },
            );
            (
                generation,
                stop,
                image,
                u64::from(mask.count_ones()),
                samples,
                if pid == logicview_hal::U3PRO32_PID {
                    Some(logicview_hal::u3_threshold_code(config.threshold_volts))
                } else {
                    Some(logicview_hal::threshold_code(config.threshold_volts))
                },
                config.depth == DepthMode::Stream,
                config.run,
                Duration::from_millis(config.repeat_interval_ms),
                config.discard_on_stop,
                config.run == RunPolicy::Loop,
                if config.depth == DepthMode::Stream {
                    Duration::from_secs(3)
                } else {
                    let secs = samples / config.sample_rate_hz.max(1) + 3;
                    Duration::from_secs(secs.min(120))
                },
                Some(pid),
            )
        };
        let shared = Arc::clone(&self.shared);
        let task_id = id.clone();
        tokio::spawn(async move {
            usb::drive(
                shared,
                task_id,
                generation,
                stop,
                image,
                enabled,
                samples,
                threshold,
                stream,
                run,
                interval,
                discard,
                continuous,
                header_wait,
                product_id,
            )
            .await;
        });
        self.status(Some(&id)).await
    }

    /// Searches packed channel samples for a logic pattern, with unspecified levels acting as
    /// wildcards.
    pub async fn search_pattern(
        &self,
        id: Option<&str>,
        channel: usize,
        from: u64,
        pattern: &[Option<bool>],
        forward: bool,
    ) -> Result<Option<u64>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let bytes = slot.session.store.channel_bytes(channel)?;
        let len = slot.session.store.len();
        Ok(find_pattern(bytes, len, from, pattern, forward))
    }

    /// Sets or clears a waveform cursor and returns both current cursor positions.
    pub async fn set_cursor(
        &self,
        id: Option<&str>,
        which: usize,
        sample: Option<u64>,
    ) -> Result<[Option<u64>; 2], EngineError> {
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot_mut(&id)?;
        if let Some(slot_index) = [0, 1].into_iter().find(|index| *index == which) {
            slot.cursors[slot_index] = sample;
        }
        Ok(slot.cursors)
    }

    /// Measures the selected channel between the two saved cursors, requiring both positions to be
    /// set.
    pub async fn cursor_span(
        &self,
        id: Option<&str>,
        channel: usize,
    ) -> Result<CursorSpan, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let (Some(a), Some(b)) = (slot.cursors[0], slot.cursors[1]) else {
            return Err(EngineError::Capture(
                logicview_capture::CaptureError::Proto("set both cursors first".into()),
            ));
        };
        let bytes = slot.session.store.channel_bytes(channel)?;
        let len = slot.session.store.len();
        Ok(cursor_span(
            bytes,
            len,
            a,
            b,
            slot.session.config.sample_rate_hz,
        ))
    }

    /// Measures a pulse and retains a snapshot for the session's measurement drawer.
    pub async fn save_measurement(
        &self,
        id: Option<&str>,
        channel: usize,
        sample: u64,
    ) -> Result<SavedMeasurement, EngineError> {
        let mut state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot_mut(&id)?;
        let bytes = slot.session.store.channel_bytes(channel)?.to_vec();
        let len = slot.session.store.len();
        let rate = slot.session.config.sample_rate_hz;
        let metrics = measure_pulse(&bytes, len, sample, rate).ok_or_else(|| {
            EngineError::Capture(logicview_capture::CaptureError::Proto(
                "no pulse at that sample".into(),
            ))
        })?;
        let saved = SavedMeasurement {
            id: slot.next_measure,
            channel,
            sample,
            pulse_width_samples: metrics.pulse_width_samples,
            period_samples: metrics.period_samples,
            frequency_hz: metrics.frequency_hz,
            duty: metrics.duty,
        };
        slot.next_measure += 1;
        slot.measurements.push(saved.clone());
        Ok(saved)
    }

    /// Lists the measurement snapshots retained in this session.
    pub async fn measurements(
        &self,
        id: Option<&str>,
    ) -> Result<Vec<SavedMeasurement>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        Ok(state.slot(&id)?.measurements.clone())
    }

    /// Builds the supported DSL capture archive from the session's logic data and settings.
    pub async fn export_dsl(&self, id: Option<&str>) -> Result<Vec<u8>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let probes = slot
            .channel_names
            .iter()
            .enumerate()
            .map(|(index, name)| logicview_proto::DslProbe {
                name: name.clone(),
                trigger: dsl_trigger_label(&slot.session.config, index),
            })
            .collect();
        let header = logicview_proto::write_dsl_header(&logicview_proto::DslHeader {
            version: 3,
            driver: "logicview".into(),
            mode: "logic".into(),
            samples: slot.session.store.len(),
            probes: slot.channel_names.len() as u32,
            blocks: 1,
            sample_rate: slot.session.config.sample_rate_hz,
            trigger_pos: slot.session.trigger_sample.unwrap_or(0),
            probe_meta: probes,
        });
        let session_json = serde_json::json!({
            "depth": match slot.session.config.depth {
                DepthMode::Buffer => "buffer",
                DepthMode::Stream => "stream",
            },
            "run": match slot.session.config.run {
                RunPolicy::Single => "single",
                RunPolicy::Repeat => "repeat",
                RunPolicy::Loop => "loop",
            },
            "threshold_volts": slot.session.config.threshold_volts,
            "rle": slot.session.config.rle,
            "filter": slot.session.config.one_sample_filter,
            "external_clock": slot.session.config.external_clock,
            "discard_on_stop": slot.session.config.discard_on_stop,
        })
        .to_string();
        Ok(logicview_store::write_dsl_bytes(
            &logicview_store::DslParts {
                header,
                session_json,
                channels: slot.session.store.to_channels(),
            },
        )?)
    }

    /// Returns the last prepared device arm image for diagnostics or protocol inspection.
    pub async fn arm_record(&self, id: Option<&str>) -> Result<Vec<u8>, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        Ok(slot.session.arm.clone())
    }

    /// Saves the capture as a native ZIP for a `.lvcap` path or as a directory for other paths.
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

    /// Loads a native capture from disk and installs it in an inactive session.
    pub async fn load_lvcap(&self, id: Option<&str>, path: &Path) -> Result<Status, EngineError> {
        let data = logicview_store::read_any(path)?;
        self.install_archive(id, data).await
    }

    /// Serializes a native capture archive for download or transport.
    pub async fn export_zip(&self, id: Option<&str>) -> Result<Vec<u8>, EngineError> {
        let data = self.archive(id).await?;
        Ok(logicview_store::write_zip_bytes(&data)?)
    }

    /// Replace the session with a `.lvcap` or `.dsl` zip. The name picks the
    /// container when it has a known extension.
    pub async fn import_capture(
        &self,
        id: Option<&str>,
        name: &str,
        bytes: &[u8],
    ) -> Result<Status, EngineError> {
        if bytes.len() < 4 || &bytes[..2] != b"PK" {
            return Err(EngineError::Device("capture file is not a zip".into()));
        }
        let data = decode_capture_bytes(name, bytes)?;
        self.install_archive(id, data).await
    }

    /// Exports individual samples to CSV and reports whether the table row limit truncated the
    /// capture.
    pub async fn export_samples_csv(
        &self,
        id: Option<&str>,
    ) -> Result<samples_export::SampleFile, EngineError> {
        let snap = self.sample_snapshot(id).await?;
        Ok(samples_export::render_csv(&snap))
    }

    /// Exports individual samples to an Excel workbook with the shared table row limit.
    pub async fn export_samples_xlsx(
        &self,
        id: Option<&str>,
    ) -> Result<samples_export::SampleFile, EngineError> {
        let snap = self.sample_snapshot(id).await?;
        Ok(samples_export::render_xlsx(&snap)?)
    }

    /// Copies recorded samples and labels while holding the engine lock so export can render
    /// independently.
    async fn sample_snapshot(
        &self,
        id: Option<&str>,
    ) -> Result<samples_export::SampleSnapshot, EngineError> {
        let state = self.shared.state.lock().await;
        let id = self.resolve(&state, id)?;
        let slot = state.slot(&id)?;
        let len = slot.session.store.len();
        if len == 0 {
            return Err(EngineError::Device("nothing captured yet".into()));
        }
        Ok(samples_export::SampleSnapshot {
            rate: slot.session.config.sample_rate_hz.max(1),
            names: slot.channel_names.clone(),
            packed: slot.session.store.to_channels(),
            len,
            analog_name: ANALOG_NAME.into(),
            analog: slot.session.analog.samples().to_vec(),
        })
    }

    /// Copies session metadata and sample data into the native persistence representation.
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

    /// Restores a saved record into an inactive session and replaces its source with a file device.
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
        slot.session.config.channel_enable = 0;
        slot.devices = vec![BoundDevice {
            id: "file".into(),
            name: "File".into(),
            kind: "file".into(),
            super_speed: false,
        }];
        slot.origins = slot
            .channel_names
            .iter()
            .map(|_| ChannelOrigin {
                device_id: "file".into(),
                device_name: "File".into(),
            })
            .collect();
        remember_catalog(slot);
        slot.decoders.clear();
        slot.annotations.clear();
        let is_active = slot.id == active;
        Ok(slot.status(is_active))
    }

    /// Installs a physical device's channel catalog and clears data tied to the previous source.
    async fn use_pod_channels(
        &self,
        mask: u32,
        device_id: &str,
        device_name: &str,
        super_speed: bool,
    ) {
        let mut state = self.shared.state.lock().await;
        let active = state.active;
        if let Some(slot) = state.slots.get_mut(active) {
            if slot.session.phase.is_active() {
                return;
            }
            let (names, colors) = pod_channel_style(mask);
            slot.devices = vec![BoundDevice {
                id: device_id.into(),
                name: device_name.into(),
                kind: "usb".into(),
                super_speed,
            }];
            slot.origins = names
                .iter()
                .map(|_| ChannelOrigin {
                    device_id: device_id.into(),
                    device_name: device_name.into(),
                })
                .collect();
            slot.channel_names = names;
            slot.channel_colors = colors;
            remember_catalog(slot);
            slot.session.config.channel_enable = 0;
            slot.decoders.clear();
            slot.annotations.clear();
            slot.session.store = LogicStore::new(mask.count_ones() as usize);
        }
    }

    /// Resolves an optional session identifier, falling back to the selected session.
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
    /// Creates the shared engine with its initial demo session.
    fn default() -> Self {
        Self::new()
    }
}

impl Slot {
    /// Builds a new session slot with the default demo channels and empty analysis state.
    fn demo(id: &str, name: &str) -> Self {
        let mut slot = Self {
            id: id.to_string(),
            name: name.to_string(),
            channel_names: Vec::new(),
            channel_colors: Vec::new(),
            origins: Vec::new(),
            catalog_names: Vec::new(),
            catalog_colors: Vec::new(),
            catalog_origins: Vec::new(),
            devices: Vec::new(),
            decoders: Vec::new(),
            annotations: Vec::new(),
            next_decoder: 1,
            session: Session::new(),
            cursors: [None, None],
            measurements: Vec::new(),
            next_measure: 1,
        };
        let _ = install_demo_ids(&mut slot, &["demo".to_string()]);
        slot
    }

    /// Combines channel labels and device origins into the client-facing channel list.
    fn channel_list(
        &self,
        names: &[String],
        colors: &[String],
        origins: &[ChannelOrigin],
    ) -> Vec<ChannelInfo> {
        names
            .iter()
            .zip(colors.iter())
            .enumerate()
            .map(|(index, (name, color))| ChannelInfo {
                index,
                name: name.clone(),
                color: color.clone(),
                device_id: origins
                    .get(index)
                    .map(|origin| origin.device_id.clone())
                    .unwrap_or_else(|| "session".into()),
                device_name: origins
                    .get(index)
                    .map(|origin| origin.device_name.clone())
                    .unwrap_or_else(|| "Session".into()),
            })
            .collect()
    }

    /// Builds a client-facing session snapshot, keeping all available probes separate from sampled
    /// channels.
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
            channels: self.channel_list(&self.channel_names, &self.channel_colors, &self.origins),
            probes: self.channel_list(
                if self.catalog_names.is_empty() {
                    &self.channel_names
                } else {
                    &self.catalog_names
                },
                if self.catalog_names.is_empty() {
                    &self.channel_colors
                } else {
                    &self.catalog_colors
                },
                if self.catalog_names.is_empty() {
                    &self.origins
                } else {
                    &self.catalog_origins
                },
            ),
            channel_enable: self.session.config.channel_enable,
            devices: self
                .devices
                .iter()
                .map(|device| DeviceInfo {
                    id: device.id.clone(),
                    name: device.name.clone(),
                    kind: device.kind.clone(),
                    connected: true,
                    super_speed: device.super_speed,
                })
                .collect(),
            // A logic pod has no analog input. The demo sine is a synthetic
            // trace, not a connected probe, so it stays out of the waveform.
            analog: Vec::new(),
            warnings: self.session.warnings.clone(),
            error: self.session.error.clone(),
            active,
        }
    }
}

/// Describes the trigger stages associated with a channel in the exported session header.
fn dsl_trigger_label(config: &SessionConfig, index: usize) -> String {
    if !config.trigger_enabled {
        return String::new();
    }
    let steps = logicview_capture::active_edge_steps(config);
    if !steps.is_empty() {
        return steps
            .iter()
            .enumerate()
            .filter(|(_, step)| step.channel as usize == index)
            .map(|(order, step)| {
                format!(
                    "{}:{}",
                    order + 1,
                    if step.rising { "rising" } else { "falling" }
                )
            })
            .collect::<Vec<_>>()
            .join(",");
    }
    if index != config.trigger_channel as usize {
        return String::new();
    }
    match config.trigger_kind {
        TriggerKind::Rising => "rising".into(),
        TriggerKind::Falling => "falling".into(),
        TriggerKind::High => "high".into(),
        TriggerKind::Low => "low".into(),
    }
}

/// Orders discovery results so connected USB instruments precede simulated sources.
fn hardware_before_demo(devices: Vec<DeviceInfo>) -> Vec<DeviceInfo> {
    let mut usb = Vec::new();
    let mut other = Vec::new();
    for device in devices {
        if device.kind == "usb" {
            usb.push(device);
        } else {
            other.push(device);
        }
    }
    usb.extend(other);
    usb
}

/// Builds the discovery record for a selectable synthetic device.
fn demo_device_info(id: &str) -> DeviceInfo {
    let pod = demo_pod(id);
    DeviceInfo {
        id: id.to_string(),
        name: pod
            .map(|item| item.name.to_string())
            .unwrap_or_else(|| id.to_string()),
        kind: "demo".into(),
        connected: true,
        super_speed: false,
    }
}

/// Converts hardware sampling limits into the serializable profile description.
fn rate_bands(product_id: u16, stream: bool, super_speed: bool) -> Vec<RateBandInfo> {
    logicview_hal::link_rate_limits(product_id, stream, super_speed)
        .iter()
        .map(|band| RateBandInfo {
            max_channels: band.max_channels,
            max_hz: band.max_hz,
        })
        .collect()
}

/// Returns the available probe count even when only a subset was captured.
fn probe_count(slot: &Slot) -> usize {
    if slot.catalog_names.is_empty() {
        slot.channel_names.len()
    } else {
        slot.catalog_names.len()
    }
}

/// Counts selected probes within the available width for sample-rate planning.
fn enabled_channel_count(mask: u32, probes: usize) -> u32 {
    let width = probes.max(1).min(32);
    let all = if width == 32 {
        u32::MAX
    } else {
        (1u32 << width) - 1
    };
    let bits = if mask == 0 { all } else { mask & all };
    bits.count_ones().max(1)
}

/// Checks whether the session's bound hardware advertises a SuperSpeed connection.
fn bound_link_is_super(devices: &[BoundDevice]) -> bool {
    devices.iter().any(|device| device.super_speed)
}

/// Selects the hardware rate profile, using the default analyzer profile for demo planning.
fn rate_product(devices: &[BoundDevice]) -> u16 {
    devices
        .iter()
        .find_map(|device| usb_product_id(&device.id))
        .unwrap_or(logicview_hal::PLUS_PID)
}

/// Keeps requested capture rates within the selected channel, mode, and link limits.
fn clamp_sample_rate(slot: &Slot, config: &mut SessionConfig) {
    if config.sample_rate_hz == 0 {
        return;
    }
    let channels = enabled_channel_count(config.channel_enable, probe_count(slot));
    let stream = config.depth == DepthMode::Stream;
    let max = logicview_hal::max_sample_hz(
        logicview_hal::link_rate_limits(
            rate_product(&slot.devices),
            stream,
            bound_link_is_super(&slot.devices),
        ),
        channels,
    );
    if config.sample_rate_hz > max {
        config.sample_rate_hz = max;
    }
}

/// Extracts a product identifier from the current analyzer family's USB session identifier.
fn usb_product_id(id: &str) -> Option<u16> {
    let rest = id.strip_prefix("usb:2a0e:")?;
    let hex = rest.split([':', '#', '/']).next().unwrap_or(rest);
    u16::from_str_radix(hex, 16).ok()
}

/// Selects the capture backend and rejects source combinations that cannot currently be armed.
fn session_uses_usb(devices: &[BoundDevice]) -> Result<bool, EngineError> {
    let usb = devices.iter().filter(|device| device.kind == "usb").count();
    let demo = devices
        .iter()
        .filter(|device| device.kind == "demo")
        .count();
    if usb == 0 && demo == devices.len() && !devices.is_empty() {
        return Ok(false);
    }
    if usb == 1 && devices.len() == 1 {
        return Ok(true);
    }
    if usb > 1 {
        return Err(EngineError::Device(
            "arming more than one USB pod in one capture is not verified on hardware".into(),
        ));
    }
    Err(EngineError::Device(
        "this session cannot be armed from its current devices".into(),
    ))
}

/// Rebuilds a session's demo device and channel catalog, clearing source-dependent data.
fn install_demo_ids(slot: &mut Slot, ids: &[String]) -> Result<(), EngineError> {
    let mut devices = Vec::new();
    let mut names = Vec::new();
    let mut colors = Vec::new();
    let mut origins = Vec::new();
    for id in ids {
        let pod = demo_pod(id)
            .ok_or_else(|| EngineError::UnknownDevice(format!("unknown demo device {id}")))?;
        devices.push(BoundDevice {
            id: pod.id.to_string(),
            name: pod.name.to_string(),
            kind: "demo".into(),
            super_speed: false,
        });
        for channel in pod.channels {
            names.push(channel.name.to_string());
            colors.push(channel.color.to_string());
            origins.push(ChannelOrigin {
                device_id: pod.id.to_string(),
                device_name: pod.name.to_string(),
            });
        }
    }
    if names.is_empty() {
        return Err(EngineError::Device(
            "a session needs at least one channel".into(),
        ));
    }
    slot.devices = devices;
    slot.channel_names = names;
    slot.channel_colors = colors;
    slot.origins = origins;
    remember_catalog(slot);
    slot.session.config.channel_enable = 0;
    slot.decoders.clear();
    slot.annotations.clear();
    slot.session.store = LogicStore::new(slot.channel_names.len());
    Ok(())
}

/// Selects the synthetic waveforms for enabled probes in capture channel order.
fn demo_waves_masked(
    devices: &[BoundDevice],
    mask: u32,
) -> Result<Vec<fn(u64) -> bool>, EngineError> {
    let waves = demo_waves(devices)?;
    if mask == 0 {
        return Ok(waves);
    }
    let kept: Vec<_> = waves
        .into_iter()
        .enumerate()
        .filter(|(index, _)| *index < 32 && mask & (1 << *index) != 0)
        .map(|(_, wave)| wave)
        .collect();
    if kept.is_empty() {
        return Err(EngineError::Device("no channels enabled".into()));
    }
    Ok(kept)
}

/// Preserves the complete probe catalog before the sampled channel list is narrowed.
fn remember_catalog(slot: &mut Slot) {
    slot.catalog_names = slot.channel_names.clone();
    slot.catalog_colors = slot.channel_colors.clone();
    slot.catalog_origins = slot.origins.clone();
}

/// Rebuilds channel labels and origins to match the enabled capture streams.
fn apply_sampled_channels(slot: &mut Slot, mask: u32) -> Result<(), EngineError> {
    if slot.catalog_names.is_empty() {
        remember_catalog(slot);
    }
    if mask == 0 {
        slot.channel_names = slot.catalog_names.clone();
        slot.channel_colors = slot.catalog_colors.clone();
        slot.origins = slot.catalog_origins.clone();
        return Ok(());
    }
    let mut names = Vec::new();
    let mut colors = Vec::new();
    let mut origins = Vec::new();
    for (index, name) in slot.catalog_names.iter().enumerate() {
        if index < 32 && mask & (1 << index) != 0 {
            names.push(name.clone());
            colors.push(
                slot.catalog_colors
                    .get(index)
                    .cloned()
                    .unwrap_or_else(|| "#d5dce6".into()),
            );
            origins.push(
                slot.catalog_origins
                    .get(index)
                    .cloned()
                    .unwrap_or(ChannelOrigin {
                        device_id: "session".into(),
                        device_name: "Session".into(),
                    }),
            );
        }
    }
    if names.is_empty() {
        return Err(EngineError::Device("no channels enabled".into()));
    }
    slot.channel_names = names;
    slot.channel_colors = colors;
    slot.origins = origins;
    Ok(())
}

/// Collects synthetic channel generators in the order of the session's bound devices.
fn demo_waves(devices: &[BoundDevice]) -> Result<Vec<fn(u64) -> bool>, EngineError> {
    let mut waves = Vec::new();
    for device in devices {
        let pod = demo_pod(&device.id)
            .ok_or_else(|| EngineError::Device(format!("{} is not a demo source", device.id)))?;
        for channel in pod.channels {
            waves.push(channel.level);
        }
    }
    if waves.is_empty() {
        return Err(EngineError::Device("session has no demo channels".into()));
    }
    Ok(waves)
}

/// Selects the native or DSL archive reader using the filename or format probing.
fn decode_capture_bytes(name: &str, bytes: &[u8]) -> Result<ArchiveData, EngineError> {
    let lower = name.to_ascii_lowercase();
    if lower.ends_with(".dsl") {
        return Ok(logicview_store::read_dsl_bytes(bytes)?);
    }
    if lower.ends_with(".lvcap") || lower.ends_with(".zip") {
        return Ok(logicview_store::read_zip_bytes(bytes)?);
    }
    match logicview_store::read_zip_bytes(bytes) {
        Ok(data) => Ok(data),
        Err(zip_err) => match logicview_store::read_dsl_bytes(bytes) {
            Ok(data) => Ok(data),
            Err(_) => Err(zip_err.into()),
        },
    }
}

/// Creates labels and display colors for enabled physical probes in channel order.
fn pod_channel_style(mask: u32) -> (Vec<String>, Vec<String>) {
    const COLORS: [&str; 8] = [
        "#e2b340", "#3dcc8e", "#5aa2ff", "#c58bff", "#ff8a5b", "#f2f2f2", "#7dcea0", "#f1948a",
    ];
    let mut names = Vec::new();
    let mut colors = Vec::new();
    for bit in 0..32 {
        if mask & (1u32 << bit) != 0 {
            names.push(format!("D{bit}"));
            colors.push(COLORS[bit % COLORS.len()].to_string());
        }
    }
    (names, colors)
}

impl State {
    /// Borrows an existing session slot or reports an unknown session.
    fn slot(&self, id: &str) -> Result<&Slot, EngineError> {
        self.slots
            .iter()
            .find(|slot| slot.id == id)
            .ok_or_else(|| EngineError::UnknownSession(id.to_string()))
    }

    /// Borrows a session slot for modification or reports an unknown session.
    fn slot_mut(&mut self, id: &str) -> Result<&mut Slot, EngineError> {
        self.slots
            .iter_mut()
            .find(|slot| slot.id == id)
            .ok_or_else(|| EngineError::UnknownSession(id.to_string()))
    }
}

impl Shared {
    /// Locks shared engine state while a worker applies session updates.
    pub(crate) async fn lock(&self) -> tokio::sync::MutexGuard<'_, State> {
        self.state.lock().await
    }

    /// Broadcasts a session change; having no subscribers does not fail capture work.
    pub(crate) fn emit(&self, event: EngineEvent) {
        let _ = self.events.send(event);
    }
}
