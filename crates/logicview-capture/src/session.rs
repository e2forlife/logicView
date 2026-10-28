use logicview_proto::{
    align_trigger_position, encode_arm, unpack_logic_atoms, ArmConfig, DepthMode, LogicHeader,
    ModeFlags, Stage,
};

use crate::demo::DemoSource;
use crate::error::CaptureError;
use crate::store::{AnalogStore, LogicStore};
use crate::DEMO_CHANNELS;
use crate::DEMO_HW_MAX_RATE;

/// Hard stop so a bad duration cannot allocate without bound.
pub const MAX_SAMPLES: u64 = 16_000_000;

/// Samples produced per demo poll. A multiple of the 64-sample atom.
pub const DEMO_CHUNK_SAMPLES: u64 = 65_536;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Phase {
    Idle,
    Arming,
    WaitingTrigger,
    Running,
    Stopping,
    Stopped,
    Error,
}

impl Phase {
    pub fn as_str(self) -> &'static str {
        match self {
            Phase::Idle => "idle",
            Phase::Arming => "arming",
            Phase::WaitingTrigger => "waiting_trigger",
            Phase::Running => "running",
            Phase::Stopping => "stopping",
            Phase::Stopped => "stopped",
            Phase::Error => "error",
        }
    }

    pub fn is_active(self) -> bool {
        matches!(
            self,
            Phase::Arming | Phase::WaitingTrigger | Phase::Running | Phase::Stopping
        )
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StartMode {
    Normal,
    Instant,
}

#[derive(Clone, Debug)]
pub struct SessionConfig {
    pub sample_rate_hz: u64,
    pub duration_ms: u64,
    pub realtime: bool,
    pub trigger_enabled: bool,
    pub trigger_percent: f64,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            sample_rate_hz: 1_000_000,
            duration_ms: 2_000,
            realtime: false,
            trigger_enabled: false,
            trigger_percent: 10.0,
        }
    }
}

pub struct Session {
    pub phase: Phase,
    pub config: SessionConfig,
    pub store: LogicStore,
    pub analog: AnalogStore,
    pub arm: Vec<u8>,
    pub trigger_sample: Option<u64>,
    pub instant: bool,
    pub error: Option<String>,
    pub total_samples: u64,
    generation: u64,
}

impl Session {
    pub fn new() -> Self {
        Self {
            phase: Phase::Idle,
            config: SessionConfig::default(),
            store: LogicStore::new(DEMO_CHANNELS),
            analog: AnalogStore::default(),
            arm: Vec::new(),
            trigger_sample: None,
            instant: false,
            error: None,
            total_samples: 0,
            generation: 0,
        }
    }

    pub fn generation(&self) -> u64 {
        self.generation
    }

    pub fn begin(
        &mut self,
        config: SessionConfig,
        mode: StartMode,
    ) -> Result<DemoSource, CaptureError> {
        if self.phase.is_active() {
            return Err(CaptureError::Busy);
        }
        self.generation = self.generation.wrapping_add(1);
        if config.sample_rate_hz == 0 {
            return Err(CaptureError::BadRate);
        }
        if config.duration_ms == 0 {
            return Err(CaptureError::BadDuration);
        }
        let mut total = config.sample_rate_hz.saturating_mul(config.duration_ms) / 1000;
        total -= total % 64;
        if total == 0 {
            return Err(CaptureError::BadDuration);
        }
        if total > MAX_SAMPLES {
            return Err(CaptureError::TooLarge {
                requested: total,
                ceiling: MAX_SAMPLES,
            });
        }
        let instant = mode == StartMode::Instant;
        let arm = build_arm(&config, total, instant)?;
        self.config = config;
        self.store = LogicStore::new(DEMO_CHANNELS);
        self.analog = AnalogStore::default();
        self.arm = arm;
        self.trigger_sample = None;
        self.instant = instant;
        self.error = None;
        self.total_samples = total;
        self.phase = Phase::Arming;
        Ok(DemoSource::new(&self.config, total, instant))
    }

    pub fn on_header(&mut self, header: LogicHeader) {
        if header.trigger_position > 0 && self.config.trigger_enabled && !self.instant {
            self.trigger_sample = Some(u64::from(header.trigger_position));
            self.phase = Phase::WaitingTrigger;
        } else {
            self.trigger_sample = None;
            self.phase = Phase::Running;
        }
    }

    pub fn on_samples(
        &mut self,
        atoms: &[u8],
        analog: &[f32],
        samples: u64,
    ) -> Result<(), CaptureError> {
        let split = unpack_logic_atoms(atoms, DEMO_CHANNELS)
            .map_err(|err| CaptureError::Proto(err.to_string()))?;
        for (index, bytes) in split.iter().enumerate() {
            self.store.append_channel(index, bytes, samples)?;
        }
        self.analog.append(analog)?;
        if matches!(
            self.phase,
            Phase::Arming | Phase::WaitingTrigger | Phase::Running
        ) {
            self.phase = Phase::Running;
        }
        Ok(())
    }

    pub fn request_stop(&mut self) {
        if self.phase.is_active() {
            self.phase = Phase::Stopping;
        }
    }

    pub fn finish(&mut self) {
        self.phase = Phase::Stopped;
    }

    pub fn fail(&mut self, message: impl Into<String>) {
        self.error = Some(message.into());
        self.phase = Phase::Error;
    }
}

impl Default for Session {
    fn default() -> Self {
        Self::new()
    }
}

fn build_arm(config: &SessionConfig, total: u64, instant: bool) -> Result<Vec<u8>, CaptureError> {
    let mut mode = ModeFlags::default();
    if config.trigger_enabled && !instant {
        mode.insert(ModeFlags::TRIGGER_ENABLE);
    }
    if instant {
        mode.insert(ModeFlags::INSTANT);
    }
    let divider = logicview_proto::logic_divider(DEMO_HW_MAX_RATE, config.sample_rate_hz, 1);
    let trigger_position = if config.trigger_enabled && !instant {
        align_trigger_position(total, config.trigger_percent, DepthMode::Buffer)
    } else {
        0
    };
    let mut stages = [Stage::default(); 16];
    let stage_count = if config.trigger_enabled && !instant {
        stages[0] = Stage {
            mask: 1,
            value: 1,
            edge: 1,
            invert: false,
            logic_or: false,
            count: 1,
        };
        1
    } else {
        0
    };
    let arm = ArmConfig {
        mode,
        divider,
        sample_count: total,
        trigger_position,
        channel_count: DEMO_CHANNELS as u8,
        stage_count,
        scope_count: 0,
        channel_enable: (1u32 << DEMO_CHANNELS) - 1,
        fine_gain: 0,
        stages,
        upper: None,
    };
    encode_arm(&arm).map_err(|err| CaptureError::Proto(err.to_string()))
}

/// How many samples a config will store, after atom alignment.
pub fn planned_samples(config: &SessionConfig) -> Result<u64, CaptureError> {
    if config.sample_rate_hz == 0 {
        return Err(CaptureError::BadRate);
    }
    if config.duration_ms == 0 {
        return Err(CaptureError::BadDuration);
    }
    let mut total = config.sample_rate_hz.saturating_mul(config.duration_ms) / 1000;
    total -= total % 64;
    if total == 0 {
        return Err(CaptureError::BadDuration);
    }
    if total > MAX_SAMPLES {
        return Err(CaptureError::TooLarge {
            requested: total,
            ceiling: MAX_SAMPLES,
        });
    }
    Ok(total)
}
