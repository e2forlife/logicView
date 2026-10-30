//! Plans captures and tracks their lifecycle independently of device transport.
//!
//! The engine drives these transitions, while sources provide headers and samples.
//! Arm records translate the shared configuration into settings understood by the
//! current hardware backends.

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

/// Lifecycle state reported by the engine while a capture is prepared, run, and finalized.
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
    /// Returns the stable phase name shared by UI state and automation responses.
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

    /// Reports whether capture work is still in progress and another arm must wait.
    pub fn is_active(self) -> bool {
        matches!(
            self,
            Phase::Arming | Phase::WaitingTrigger | Phase::Running | Phase::Stopping
        )
    }
}

/// Chooses whether a capture uses its configured trigger or starts immediately.
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
    /// Probe index used by the trigger, before capture streams are packed.
    pub channel: u8,
    /// Selects a rising transition when true and a falling transition when false.
    pub rising: bool,
}

/// Maximum ordered trigger depth supported by the arm-record layout.
pub const MAX_TRIGGER_STEPS: usize = 16;

/// Clock the arm divider is computed from.
#[derive(Clone, Copy, Debug)]
pub struct HostClock {
    /// Reference clock used to derive the requested sampling rate.
    pub hw_max_hz: u64,
    /// Requested rate that selects the hardware half-rate mode, if supported.
    pub half_rate_hz: Option<u64>,
    /// Requested rate that selects the hardware quarter-rate mode, if supported.
    pub quarter_rate_hz: Option<u64>,
    /// 1 on the Plus. 5 on the U3Pro32. The high half of the divider word holds
    /// the pre-divider stage.
    pub pre_divider: u64,
    /// A 32-channel pod sends the second trigger record on every capture.
    pub ext_record: bool,
}

/// Shared capture options supplied by the UI or automation and translated into an arm record.
#[derive(Clone, Debug)]
pub struct SessionConfig {
    /// Requested samples per second, validated against the selected hardware limits.
    pub sample_rate_hz: u64,
    /// Requested record duration used to plan a bounded sample count.
    pub duration_ms: u64,
    /// Paces demo delivery for live playback instead of generating the record as fast as possible.
    pub realtime: bool,
    /// Enables trigger settings for normal capture; instant capture bypasses them.
    pub trigger_enabled: bool,
    /// Requested pre-trigger share of the record, subject to mode-specific limits.
    pub trigger_percent: f64,
    /// Selects device-buffered acquisition or streaming transfer.
    pub depth: DepthMode,
    /// Chooses completion behavior; the engine applies repeat and loop scheduling.
    pub run: RunPolicy,
    /// Pause between acquisitions when the engine uses repeat mode.
    pub repeat_interval_ms: u64,
    /// Requests the device run-length encoding mode.
    pub rle: bool,
    /// Logic input threshold requested for physical hardware.
    pub threshold_volts: f64,
    /// Requests the hardware filter for isolated sample glitches.
    pub one_sample_filter: bool,
    /// Selects external sampling clock input when supported by the hardware.
    pub external_clock: bool,
    /// Selects falling-edge sampling for the configured clock mode.
    pub clock_falling: bool,
    /// Requests dropping the device buffer when an acquisition is stopped early.
    pub discard_on_stop: bool,
    /// Bit per channel. Zero means the first `channel_count` channels.
    pub channel_enable: u32,
    /// Probe index used by the simple trigger when no ordered steps are provided.
    pub trigger_channel: u8,
    /// Edge or level condition for the simple trigger.
    pub trigger_kind: TriggerKind,
    /// Ordered edges. Empty means the single `trigger_channel` / `trigger_kind`.
    pub trigger_steps: Vec<TriggerStep>,
}

impl Default for SessionConfig {
    /// Provides a bounded demo-friendly capture configuration for a new session.
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

/// Rejects trigger sequences that exceed the arm format's stage or channel limits.
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

/// Owns the current capture state, recorded data, and diagnostics independently of its source.
pub struct Session {
    /// Current acquisition lifecycle state reported to clients.
    pub phase: Phase,
    /// Settings used to plan and interpret this capture.
    pub config: SessionConfig,
    /// Original logic samples and their drawing summaries.
    pub store: LogicStore,
    /// Original analog samples and their drawing envelopes.
    pub analog: AnalogStore,
    /// Last prepared device configuration image, retained for capture and diagnostics.
    pub arm: Vec<u8>,
    /// Observed trigger position in capture sample coordinates, if available.
    pub trigger_sample: Option<u64>,
    /// Whether this capture bypassed the configured trigger.
    pub instant: bool,
    /// Terminal failure reason when the session is in its error phase.
    pub error: Option<String>,
    /// Nonfatal observations that affect interpretation of the retained record.
    pub warnings: Vec<String>,
    /// Planned capture length, which can exceed the samples actually retained.
    pub total_samples: u64,
    /// Demo captures search stored samples for the edge sequence.
    resolve_edges: bool,
    generation: u64,
}

impl Session {
    /// Creates an idle session with empty stores and the default capture settings.
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

    /// Identifies the latest prepared capture so asynchronous workers can detect stale work.
    pub fn generation(&self) -> u64 {
        self.generation
    }

    /// Prepares a demo capture and returns the synthetic source that will feed it.
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
                pre_divider: 1,
                ext_record: false,
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

    /// Applies source metadata and establishes the initial trigger and running state.
    pub fn on_header(&mut self, header: LogicHeader) {
        if header.trigger_position > 0 && self.config.trigger_enabled && !self.instant {
            self.trigger_sample = Some(u64::from(header.trigger_position));
            self.phase = Phase::WaitingTrigger;
        } else {
            self.trigger_sample = None;
            self.phase = Phase::Running;
        }
    }

    /// Unpacks a capture block into channel stores and updates the live session state.
    ///
    /// Analog samples beyond the logic block are dropped. Demo edge-trigger
    /// positions are resolved from the accumulated original samples.
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
        // An unpacked analog tail longer than the logic sample count is not
        // part of the capture. Drawing it shows a spike after the last sample.
        let analog = if analog.len() as u64 > samples {
            &analog[..samples as usize]
        } else {
            analog
        };
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

    /// Moves an active session into stopping while its source finishes or releases hardware.
    pub fn request_stop(&mut self) {
        if self.phase.is_active() {
            self.phase = Phase::Stopping;
        }
    }

    /// Finalizes the captured record, trims known fill data, and records unresolved demo triggers.
    pub fn finish(&mut self) {
        // Alternating fill on every channel is not the captured signal.
        // Drop it before the analog lane is cut to the logic length.
        self.store.drop_shared_nyquist_tail();
        self.analog.truncate(self.store.len() as usize);
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

    /// Records a terminal capture failure so clients can display the reason.
    pub fn fail(&mut self, message: impl Into<String>) {
        self.error = Some(message.into());
        self.phase = Phase::Error;
    }

    /// Adds a nonfatal capture diagnostic to the session status.
    pub fn warn(&mut self, message: impl Into<String>) {
        self.warnings.push(message.into());
    }
}

impl Default for Session {
    /// Creates the idle session used when no capture has been prepared.
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

/// Translates an ordered edge sequence into low- and extended-channel trigger records.
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

/// Resolves the selected channel mask, using the requested width when no mask is supplied.
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

/// Translates session options and device clock capabilities into capture arm records.
///
/// This is the shared policy boundary for sampling, trigger placement, and
/// mode flags; transport code sends the resulting bytes without rebuilding them.
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
    let channels = u64::from(enable.count_ones().max(1));
    let bytes_per_ms = config
        .sample_rate_hz
        .saturating_mul(channels)
        .div_ceil(8_000);
    if bytes_per_ms < 1024 {
        mode.insert(ModeFlags::SLOW_ACQUISITION);
    }
    let divider = logicview_proto::logic_divider(
        clock.hw_max_hz,
        config.sample_rate_hz,
        clock.pre_divider.max(1),
    );
    let trigger_position = if config.trigger_enabled && !instant {
        align_trigger_position(total, config.trigger_percent, config.depth)
    } else {
        0
    };
    let mut stages = [Stage::default(); 16];
    let mut upper = None;
    let stage_count = if config.trigger_enabled && !instant {
        let steps = active_edge_steps(config);
        if clock.ext_record && config.trigger_steps.is_empty() {
            // U3Pro32 uses the reference driver's simple trigger format: one
            // condition, stage index zero, and an inactive second comparator.
            let channel = config.trigger_channel.min(31);
            let bit = 1u32 << (channel % 16);
            let (value, edge) = match config.trigger_kind {
                TriggerKind::Rising => (bit, bit),
                TriggerKind::Falling => (0, bit),
                TriggerKind::High => (bit, 0),
                TriggerKind::Low => (0, 0),
            };
            stages[0].logic_or = true;
            if channel < 16 {
                stages[0].mask = bit;
                stages[0].value = value;
                stages[0].edge = edge;
            } else {
                let mut extended = [UpperStage::default(); 16];
                extended[0] = UpperStage { mask: bit, value, edge };
                upper = Some(extended);
            }
            0
        } else if steps.len() == 1 && config.trigger_steps.is_empty() {
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
            let count = apply_edge_stages(&steps, &mut stages, &mut upper)?;
            if clock.ext_record { count - 1 } else { count }
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
    if clock.ext_record && upper.is_none() {
        upper = Some([UpperStage::default(); 16]);
    }
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
    //! Checks capture planning, trigger encoding, and consistency between stored signal types.

    use super::*;
    use logicview_proto::{decode_arm, pack_logic_atoms};

    /// Guards against analog spikes caused by retaining data beyond the logic capture.
    #[test]
    fn analog_samples_past_the_logic_count_are_dropped() {
        let mut session = Session::new();
        let channels = vec![vec![0u8; 8]; 4];
        let atoms = pack_logic_atoms(&channels).unwrap();
        let mut analog = vec![0.2f32; 64];
        analog.extend([40.0, -40.0, 12.0]);
        session.on_samples(&atoms, &analog, 64).unwrap();
        assert_eq!(session.store.len(), 64);
        assert_eq!(session.analog.len(), 64);
        assert!(session
            .analog
            .samples()
            .iter()
            .all(|sample| sample.abs() < 1.0));
        session.analog.append(&[80.0, -80.0]).unwrap();
        assert_eq!(session.analog.len(), 66);
        session.finish();
        assert_eq!(session.analog.len(), 64);
        assert!(session
            .analog
            .samples()
            .iter()
            .all(|sample| sample.abs() < 1.0));
    }

    /// Checks that ordered triggers preserve stage order across channel groups.
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
                pre_divider: 1,
                ext_record: false,
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

    /// Preserves the qualified edge sequence required by the measured device behavior.
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
                pre_divider: 1,
                ext_record: false,
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

    /// Checks that staged clocks and extended trigger records are selected for the wider device.
    #[test]
    fn u3_pre_divider_stage_sits_in_the_high_half() {
        let config = SessionConfig {
            sample_rate_hz: 1_000_000,
            duration_ms: 1,
            ..SessionConfig::default()
        };
        let bytes = build_arm(
            &config,
            960,
            true,
            1,
            &HostClock {
                hw_max_hz: 500_000_000,
                half_rate_hz: Some(500_000_000),
                quarter_rate_hz: Some(1_000_000_000),
                pre_divider: 5,
                ext_record: true,
            },
        )
        .unwrap();
        let armed = decode_arm(&bytes).unwrap();
        assert_eq!(armed.divider & 0xffff, 100);
        assert_eq!(armed.divider >> 16, 0x0400);
        assert!(armed.mode.contains(ModeFlags::SLOW_ACQUISITION));
        assert!(armed.upper.is_some());
    }

    #[test]
    fn u3_simple_edge_uses_reference_trigger_record_for_both_banks() {
        let clock = HostClock { hw_max_hz: 500_000_000, half_rate_hz: None,
            quarter_rate_hz: None, pre_divider: 5, ext_record: true };
        for channel in [3, 19] {
            let config = SessionConfig { trigger_enabled: true, trigger_channel: channel,
                trigger_kind: TriggerKind::Rising, ..SessionConfig::default() };
            let bytes = build_arm(&config, 64_000, false, u32::MAX, &clock).unwrap();
            let arm = decode_arm(&bytes).unwrap();
            assert!(!arm.mode.contains(ModeFlags::SERIAL_TRIGGER));
            assert_eq!(arm.stage_count, 0);
            assert!(arm.stages[0].logic_or);
            let (low, upper) = (arm.stages[0], arm.upper.unwrap()[0]);
            assert_eq!(low.mask, if channel < 16 { 8 } else { 0 });
            assert_eq!(upper.mask, if channel >= 16 { 8 } else { 0 });
            assert_eq!(low.edge, low.mask);
            assert_eq!(upper.edge, upper.mask);
        }
    }

    /// Checks that slow-acquisition mode follows aggregate transfer volume, not sample rate alone.
    #[test]
    fn a_wide_u3_megahertz_capture_is_not_the_slow_bit() {
        let config = SessionConfig {
            sample_rate_hz: 1_000_000,
            duration_ms: 100,
            ..SessionConfig::default()
        };
        let bytes = build_arm(
            &config,
            64_000,
            false,
            u32::MAX,
            &HostClock {
                hw_max_hz: 500_000_000,
                half_rate_hz: Some(500_000_000),
                quarter_rate_hz: Some(1_000_000_000),
                pre_divider: 5,
                ext_record: true,
            },
        )
        .unwrap();
        let armed = decode_arm(&bytes).unwrap();
        assert_eq!(armed.divider, 100 | (0x0400 << 16));
        assert!(!armed.mode.contains(ModeFlags::SLOW_ACQUISITION));
        assert!(!armed.mode.contains(ModeFlags::HALF_RATE));
        assert!(armed.upper.is_some());
    }

    /// Checks that unsupported trigger depth is rejected before arming.
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
