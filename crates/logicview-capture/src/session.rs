use logicview_analysis::find_edge_sequence;
use logicview_proto::{
    align_trigger_position, encode_arm, unpack_logic_atoms, ArmConfig, DepthMode, LogicHeader,
    ModeFlags, Stage, UpperStage,
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

/// What happens after one arm finishes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub enum RunPolicy {
    #[default]
    Single,
    /// Arm again after `repeat_interval_ms`, keeping the latest record.
    Repeat,
    /// Arm again immediately and keep the last duration of samples.
    Loop,
}

/// Simple trigger on one channel. A non-empty [`SessionConfig::trigger_steps`]
/// list replaces this with an ordered edge sequence.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub enum TriggerKind {
    #[default]
    Rising,
    Falling,
    High,
    Low,
}

/// One edge in a sequential trigger. `rising` is false for a falling edge.
///
/// The arm record stores each step as its own stage, in order, up to 16.
/// Stages are what the pod's trigger RAM can hold. The demo source does not
/// wait on that RAM: it searches the captured samples for the same sequence.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct TriggerStep {
    pub channel: u8,
    pub rising: bool,
}

pub const MAX_TRIGGER_STEPS: usize = 16;

/// Clock the arm divider is computed from.
#[derive(Clone, Copy, Debug)]
pub struct HostClock {
    pub hw_max_hz: u64,
    pub half_rate_hz: Option<u64>,
    pub quarter_rate_hz: Option<u64>,
}

#[derive(Clone, Debug)]
pub struct SessionConfig {
    pub sample_rate_hz: u64,
    pub duration_ms: u64,
    pub realtime: bool,
    pub trigger_enabled: bool,
    pub trigger_percent: f64,
    pub depth: DepthMode,
    pub run: RunPolicy,
    pub repeat_interval_ms: u64,
    pub rle: bool,
    pub threshold_volts: f64,
    pub one_sample_filter: bool,
    pub external_clock: bool,
    pub clock_falling: bool,
    pub discard_on_stop: bool,
    /// Bit per channel. Zero means the first `channel_count` channels.
    pub channel_enable: u32,
    pub trigger_channel: u8,
    pub trigger_kind: TriggerKind,
    /// Ordered edges. Empty means the single `trigger_channel` / `trigger_kind`.
    pub trigger_steps: Vec<TriggerStep>,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            sample_rate_hz: 1_000_000,
            duration_ms: 2_000,
            realtime: false,
            trigger_enabled: false,
            trigger_percent: 10.0,
            depth: DepthMode::Buffer,
            run: RunPolicy::Single,
            repeat_interval_ms: 0,
            rle: false,
            threshold_volts: 1.6,
            one_sample_filter: false,
            external_clock: false,
            clock_falling: false,
            discard_on_stop: false,
            channel_enable: 0,
            trigger_channel: 0,
            trigger_kind: TriggerKind::Rising,
            trigger_steps: Vec::new(),
        }
    }
}

/// Edges that arm the capture, in order.
///
/// A non-empty `trigger_steps` list wins. Otherwise a rising or falling
/// `trigger_kind` is one step. High and low stay a single level stage.
pub fn active_edge_steps(config: &SessionConfig) -> Vec<TriggerStep> {
    if !config.trigger_steps.is_empty() {
        return config.trigger_steps.clone();
    }
    match config.trigger_kind {
        TriggerKind::Rising => vec![TriggerStep {
            channel: config.trigger_channel,
            rising: true,
        }],
        TriggerKind::Falling => vec![TriggerStep {
            channel: config.trigger_channel,
            rising: false,
        }],
        TriggerKind::High | TriggerKind::Low => Vec::new(),
    }
}

pub fn check_trigger(config: &SessionConfig) -> Result<(), CaptureError> {
    if config.trigger_steps.len() > MAX_TRIGGER_STEPS {
        return Err(CaptureError::BadTrigger(
            "a trigger sequence has at most 16 steps".into(),
        ));
    }
    if config.trigger_steps.iter().any(|step| step.channel > 31) {
        return Err(CaptureError::BadTrigger(
            "trigger channels are 0 through 31".into(),
        ));
    }
    Ok(())
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
    pub warnings: Vec<String>,
    pub total_samples: u64,
    /// Demo captures search stored samples for the edge sequence.
    resolve_edges: bool,
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
            warnings: Vec::new(),
            total_samples: 0,
            resolve_edges: false,
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
        waves: Vec<fn(u64) -> bool>,
    ) -> Result<DemoSource, CaptureError> {
        let mut config = config;
        config.channel_enable = 0;
        let width = waves.len();
        let total = self.prepare(
            config,
            mode,
            width,
            HostClock {
                hw_max_hz: DEMO_HW_MAX_RATE,
                half_rate_hz: None,
                quarter_rate_hz: None,
            },
        )?;
        self.resolve_edges = true;
        Ok(DemoSource::new(&self.config, total, self.instant, waves))
    }

    /// Build the arm record and an empty store. `channels` is the width used
    /// when `channel_enable` is zero.
    pub fn prepare(
        &mut self,
        config: SessionConfig,
        mode: StartMode,
        channels: usize,
        clock: HostClock,
    ) -> Result<u64, CaptureError> {
        if self.phase.is_active() {
            return Err(CaptureError::Busy);
        }
        self.generation = self.generation.wrapping_add(1);
        let total = planned_samples(&config)?;
        let instant = mode == StartMode::Instant;
        let enable = enabled_mask(config.channel_enable, channels);
        let width = enable.count_ones() as usize;
        let arm = build_arm(&config, total, instant, enable, &clock)?;
        self.config = config;
        self.store = LogicStore::new(width);
        self.analog = AnalogStore::default();
        self.arm = arm;
        self.trigger_sample = None;
        self.instant = instant;
        self.error = None;
        self.warnings.clear();
        self.total_samples = total;
        self.resolve_edges = false;
        self.phase = Phase::Arming;
        Ok(total)
    }

    /// Mark the sample where the last edge of the sequence occurs.
    ///
    /// Used by the demo source. A USB capture keeps the position from the
    /// device header instead, because this machine cannot check the pod.
    pub fn locate_edge_trigger(&mut self) {
        if !self.resolve_edges
            || self.instant
            || !self.config.trigger_enabled
            || self.trigger_sample.is_some()
        {
            return;
        }
        let steps = active_edge_steps(&self.config);
        if steps.is_empty() {
            return;
        }
        let len = self.store.len();
        if len == 0 {
            return;
        }
        if steps
            .iter()
            .any(|step| step.channel as usize >= self.store.channel_count())
        {
            return;
        }
        let pairs: Vec<(usize, bool)> = steps
            .iter()
            .map(|step| (step.channel as usize, step.rising))
            .collect();
        let found = find_edge_sequence(len, &pairs, |channel, sample| {
            self.store.level(channel, sample).unwrap_or(false)
        });
        if let Some(sample) = found {
            self.trigger_sample = Some(sample);
        }
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
        let split = unpack_logic_atoms(atoms, self.store.channel_count())
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
        self.locate_edge_trigger();
        Ok(())
    }

    pub fn request_stop(&mut self) {
        if self.phase.is_active() {
            self.phase = Phase::Stopping;
        }
    }

    pub fn finish(&mut self) {
        self.locate_edge_trigger();
        if self.resolve_edges && self.config.trigger_enabled && !self.instant {
            let steps = active_edge_steps(&self.config);
            if !steps.is_empty() && self.trigger_sample.is_none() {
                if steps
                    .iter()
                    .any(|step| step.channel as usize >= self.store.channel_count())
                {
                    self.warn("trigger sequence names a channel this capture does not have");
                } else {
                    self.warn("trigger sequence was not seen in the captured samples");
                }
            }
        }
        self.phase = Phase::Stopped;
    }

    pub fn fail(&mut self, message: impl Into<String>) {
        self.error = Some(message.into());
        self.phase = Phase::Error;
    }

    pub fn warn(&mut self, message: impl Into<String>) {
        self.warnings.push(message.into());
    }
}

impl Default for Session {
    fn default() -> Self {
        Self::new()
    }
}

/// Opposite level, then the edge. Both stages use `count` 1.
fn qualified_edge(
    step: TriggerStep,
    stages: &mut [Stage; 16],
    upper: &mut Option<[UpperStage; 16]>,
) -> u8 {
    let channel = step.channel.min(31);
    let bit = 1u32 << (channel % 16);
    let (level, edge_value) = if step.rising { (0, bit) } else { (bit, 0) };
    let on_low = channel < 16;
    stages[0] = Stage {
        mask: if on_low { bit } else { 0 },
        value: if on_low { level } else { 0 },
        edge: 0,
        invert: false,
        logic_or: false,
        count: 1,
    };
    stages[1] = Stage {
        mask: if on_low { bit } else { 0 },
        value: if on_low { edge_value } else { 0 },
        edge: if on_low { bit } else { 0 },
        invert: false,
        logic_or: false,
        count: 1,
    };
    if !on_low {
        let mut upper_stages = [UpperStage::default(); 16];
        upper_stages[0] = UpperStage {
            mask: bit,
            value: level,
            edge: 0,
        };
        upper_stages[1] = UpperStage {
            mask: bit,
            value: edge_value,
            edge: bit,
        };
        *upper = Some(upper_stages);
    }
    2
}

fn apply_edge_stages(
    steps: &[TriggerStep],
    stages: &mut [Stage; 16],
    upper: &mut Option<[UpperStage; 16]>,
) -> Result<u8, CaptureError> {
    if steps.len() > MAX_TRIGGER_STEPS {
        return Err(CaptureError::BadTrigger(
            "a trigger sequence has at most 16 steps".into(),
        ));
    }
    let mut upper_stages = [UpperStage::default(); 16];
    let mut needs_upper = false;
    for (index, step) in steps.iter().enumerate() {
        if step.channel > 31 {
            return Err(CaptureError::BadTrigger(
                "trigger channels are 0 through 31".into(),
            ));
        }
        let bit = 1u32 << (step.channel % 16);
        let value = if step.rising { bit } else { 0 };
        if step.channel < 16 {
            stages[index] = Stage {
                mask: bit,
                value,
                edge: bit,
                invert: false,
                logic_or: false,
                count: 1,
            };
        } else {
            needs_upper = true;
            upper_stages[index] = UpperStage {
                mask: bit,
                value,
                edge: bit,
            };
        }
    }
    if needs_upper {
        *upper = Some(upper_stages);
    }
    Ok(steps.len() as u8)
}

fn enabled_mask(mask: u32, channels: usize) -> u32 {
    if mask != 0 {
        return mask;
    }
    if channels >= 32 {
        u32::MAX
    } else {
        (1u32 << channels) - 1
    }
}

fn build_arm(
    config: &SessionConfig,
    total: u64,
    instant: bool,
    enable: u32,
    clock: &HostClock,
) -> Result<Vec<u8>, CaptureError> {
    let mut mode = ModeFlags::default();
    if config.trigger_enabled && !instant {
        mode.insert(ModeFlags::TRIGGER_ENABLE);
    }
    if instant {
        mode.insert(ModeFlags::INSTANT);
    }
    if config.depth == DepthMode::Stream {
        mode.insert(ModeFlags::STREAM);
    }
    if config.run == RunPolicy::Loop {
        mode.insert(ModeFlags::ANALOG_OR_LOOP);
    }
    if config.rle {
        mode.insert(ModeFlags::RLE);
    }
    if config.one_sample_filter {
        mode.insert(ModeFlags::ONE_SAMPLE_FILTER);
    }
    if config.external_clock {
        mode.insert(ModeFlags::EXTERNAL_CLOCK);
    }
    if config.clock_falling {
        mode.insert(ModeFlags::CLOCK_FALLING);
    }
    if clock.half_rate_hz == Some(config.sample_rate_hz) {
        mode.insert(ModeFlags::HALF_RATE);
    }
    if clock.quarter_rate_hz == Some(config.sample_rate_hz) {
        mode.insert(ModeFlags::QUARTER_RATE);
    }
    let divider = logicview_proto::logic_divider(clock.hw_max_hz, config.sample_rate_hz, 1);
    let trigger_position = if config.trigger_enabled && !instant {
        align_trigger_position(total, config.trigger_percent, config.depth)
    } else {
        0
    };
    let mut stages = [Stage::default(); 16];
    let mut upper = None;
    let stage_count = if config.trigger_enabled && !instant {
        let steps = active_edge_steps(config);
        if steps.len() == 1 && config.trigger_steps.is_empty() {
            // A lone rising or falling stage matches the level that is already
            // there, so the pod triggers immediately and the header stays near
            // 1. On this Plus the edge is a two-stage serial sequence: the
            // opposite level, then the edge. The position field is a cap. The
            // header lands on that edge, and on the marker when the edge
            // arrives after the requested depth. Measured on channel 0.
            mode.insert(ModeFlags::SERIAL_TRIGGER);
            qualified_edge(steps[0], &mut stages, &mut upper)
        } else if !steps.is_empty() {
            // One stage per edge, in order. The record format holds 16.
            // The demo path proves the sequence by searching samples; the
            // pod image is written and has not been run on hardware.
            apply_edge_stages(&steps, &mut stages, &mut upper)?
        } else {
            let channel = config.trigger_channel.min(31);
            let bit = 1u32 << (channel % 16);
            let (value, edge) = match config.trigger_kind {
                TriggerKind::High => (bit, 0),
                TriggerKind::Low => (0, 0),
                TriggerKind::Rising => (bit, bit),
                TriggerKind::Falling => (0, bit),
            };
            if channel < 16 {
                stages[0] = Stage {
                    mask: bit,
                    value,
                    edge,
                    invert: false,
                    logic_or: false,
                    count: 1,
                };
            } else {
                let mut upper_stages = [UpperStage::default(); 16];
                upper_stages[0] = UpperStage {
                    mask: bit,
                    value,
                    edge,
                };
                upper = Some(upper_stages);
            }
            1
        }
    } else {
        0
    };
    let arm = ArmConfig {
        mode,
        divider,
        sample_count: total,
        trigger_position,
        channel_count: enable.count_ones() as u8,
        stage_count,
        scope_count: 0,
        channel_enable: enable,
        fine_gain: 0,
        stages,
        upper,
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

#[cfg(test)]
mod tests {
    use super::*;
    use logicview_proto::decode_arm;

    #[test]
    fn two_edges_occupy_two_stages_including_the_upper_record() {
        let config = SessionConfig {
            sample_rate_hz: 1_000_000,
            duration_ms: 10,
            trigger_enabled: true,
            trigger_steps: vec![
                TriggerStep {
                    channel: 1,
                    rising: true,
                },
                TriggerStep {
                    channel: 17,
                    rising: false,
                },
            ],
            ..SessionConfig::default()
        };
        let bytes = build_arm(
            &config,
            9_984,
            false,
            0xFFFF,
            &HostClock {
                hw_max_hz: 100_000_000,
                half_rate_hz: None,
                quarter_rate_hz: None,
            },
        )
        .unwrap();
        let armed = decode_arm(&bytes).unwrap();
        assert_eq!(armed.stage_count, 2);
        assert!(armed.mode.contains(ModeFlags::TRIGGER_ENABLE));
        assert!(!armed.mode.contains(ModeFlags::SERIAL_TRIGGER));
        assert_eq!(armed.stages[0].mask, 1 << 1);
        assert_eq!(armed.stages[0].value, 1 << 1);
        assert_eq!(armed.stages[0].edge, 1 << 1);
        assert_eq!(armed.stages[0].count, 1);
        assert_eq!(armed.stages[1].mask, 0);
        let upper = armed.upper.expect("channel 17 is in the second record");
        assert_eq!(upper[1].mask, 1 << 1);
        assert_eq!(upper[1].value, 0);
        assert_eq!(upper[1].edge, 1 << 1);
    }

    #[test]
    fn a_falling_edge_is_high_then_the_edge() {
        let config = SessionConfig {
            sample_rate_hz: 1_000_000,
            duration_ms: 10,
            trigger_enabled: true,
            trigger_channel: 0,
            trigger_kind: TriggerKind::Falling,
            ..SessionConfig::default()
        };
        let bytes = build_arm(
            &config,
            262_144,
            false,
            1,
            &HostClock {
                hw_max_hz: 100_000_000,
                half_rate_hz: None,
                quarter_rate_hz: None,
            },
        )
        .unwrap();
        let armed = decode_arm(&bytes).unwrap();
        assert!(armed.mode.contains(ModeFlags::SERIAL_TRIGGER));
        assert_eq!(armed.stage_count, 2);
        assert_eq!(armed.stages[0].value, 1);
        assert_eq!(armed.stages[0].edge, 0);
        assert_eq!(armed.stages[1].value, 0);
        assert_eq!(armed.stages[1].edge, 1);
        assert_eq!(armed.stages[0].count, 1);
        assert_eq!(armed.stages[1].count, 1);
    }

    #[test]
    fn a_seventeenth_step_is_refused() {
        let config = SessionConfig {
            trigger_enabled: true,
            trigger_steps: (0..17)
                .map(|channel| TriggerStep {
                    channel,
                    rising: true,
                })
                .collect(),
            ..SessionConfig::default()
        };
        let err = check_trigger(&config).unwrap_err();
        assert!(err.to_string().contains("16"));
    }
}
