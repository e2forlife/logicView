//! Arm-record codec.
//!
//! A record opens with `0xF5A5F5A5` and closes with `0xFA5AFA5A`. Section
//! headers are a 16-bit word whose high byte is the section index and whose
//! low byte is the payload length in 16-bit words. The trigger block is 160
//! words: mask, value, and edge split into low-16 and high-16 groups of 16
//! stages, then logic/invert, then a 32-bit count per stage.
//!
//! A second record, with the same sync words and section index 96, carries
//! mask/value/edge for channels 16–31.
//!
//! The byte image was checked on a high-speed DSLogic Plus (`0x2A0E:0x0020`):
//! this layout is what the pod arms, and the capture-count field uses the
//! shift of 4 locked in the crate root.

use crate::error::ProtoError;
use crate::mode::ModeFlags;
use crate::{pack_capture_count, unpack_capture_count};

pub const OPEN_SYNC: u32 = 0xF5A5_F5A5;
pub const CLOSE_SYNC: u32 = 0xFA5A_FA5A;

const H_MODE: u16 = 0x0001;
const H_DIVIDER: u16 = 0x0102;
const H_COUNT: u16 = 0x0302;
const H_POSITION: u16 = 0x0502;
const H_GLOBAL: u16 = 0x0701;
const H_SCOPE: u16 = 0x0802;
const H_ENABLE: u16 = 0x0A02;
const H_GAIN: u16 = 0x0C01;
const H_TRIGGER: u16 = 0x40A0;
const H_UPPER: u16 = 0x6060;
const UPPER_ALIGN: u16 = 0xFFFF;

const STAGE_COUNT: usize = 16;

/// One trigger stage for the low 16 channels.
///
/// `edge` bits mark channels that are edge-sensitive. `value` is the level
/// after the edge (1 = rising when the edge bit is set, 0 = falling). `mask`
/// selects participating channels. `logic_or` combines channels with OR;
/// otherwise AND. `invert` flips the stage result. `count` is the hit count.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct Stage {
    pub mask: u32,
    pub value: u32,
    pub edge: u32,
    pub invert: bool,
    pub logic_or: bool,
    pub count: u32,
}

/// Mask, value, and edge for one stage of channels 16–31.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct UpperStage {
    pub mask: u32,
    pub value: u32,
    pub edge: u32,
}

/// Host settings that become one or two arm records.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ArmConfig {
    pub mode: ModeFlags,
    /// Divider word. The low half is `div_l` and the high half is `div_h`.
    /// On this pod the pre-divider is 1, so a divider below 65536 sits entirely
    /// in the low half.
    pub divider: u32,
    /// Requested sample count. Encoded as `sample_count >> 4`.
    pub sample_count: u64,
    pub trigger_position: u64,
    pub channel_count: u8,
    /// How many stages are active. The arrays below are always 16 long.
    pub stage_count: u8,
    pub scope_count: u32,
    pub channel_enable: u32,
    pub fine_gain: u16,
    pub stages: [Stage; STAGE_COUNT],
    pub upper: Option<[UpperStage; STAGE_COUNT]>,
}

impl Default for ArmConfig {
    fn default() -> Self {
        Self {
            mode: ModeFlags::default(),
            divider: 1,
            sample_count: 0,
            trigger_position: 0,
            channel_count: 0,
            stage_count: 0,
            scope_count: 0,
            channel_enable: 0,
            fine_gain: 0,
            stages: [Stage::default(); STAGE_COUNT],
            upper: None,
        }
    }
}

pub fn encode_arm(config: &ArmConfig) -> Result<Vec<u8>, ProtoError> {
    let packed = pack_capture_count(config.sample_count);
    if unpack_capture_count(packed) != (config.sample_count & !0xF) {
        return Err(ProtoError::FieldOverflow);
    }
    let mut words = Vec::with_capacity(186);
    push_u32(&mut words, OPEN_SYNC);
    words.push(H_MODE);
    words.push(config.mode.0);
    words.push(H_DIVIDER);
    words.push(config.divider as u16);
    words.push((config.divider >> 16) as u16);
    words.push(H_COUNT);
    words.push(packed as u16);
    words.push((packed >> 16) as u16);
    let position = fit_u32(config.trigger_position)?;
    words.push(H_POSITION);
    words.push(position as u16);
    words.push((position >> 16) as u16);
    words.push(H_GLOBAL);
    words.push(((config.channel_count as u16) << 8) | config.stage_count as u16);
    let scope = fit_u32(u64::from(config.scope_count))?;
    words.push(H_SCOPE);
    words.push(scope as u16);
    words.push((scope >> 16) as u16);
    words.push(H_ENABLE);
    words.push(config.channel_enable as u16);
    words.push((config.channel_enable >> 16) as u16);
    words.push(H_GAIN);
    words.push(config.fine_gain);
    words.push(H_TRIGGER);
    push_groups(&mut words, |stage| stage.mask, &config.stages);
    push_groups(&mut words, |stage| stage.value, &config.stages);
    push_groups(&mut words, |stage| stage.edge, &config.stages);
    for stage in &config.stages {
        words.push(logic_word(stage));
    }
    for stage in &config.stages {
        words.push(logic_word(stage));
    }
    for stage in &config.stages {
        words.push(stage.count as u16);
        words.push((stage.count >> 16) as u16);
    }
    push_u32(&mut words, CLOSE_SYNC);

    if let Some(upper) = &config.upper {
        push_u32(&mut words, OPEN_SYNC);
        words.push(H_UPPER);
        push_upper(&mut words, upper, |stage| stage.mask);
        push_upper(&mut words, upper, |stage| stage.value);
        push_upper(&mut words, upper, |stage| stage.edge);
        words.push(UPPER_ALIGN);
        push_u32(&mut words, CLOSE_SYNC);
    }
    Ok(words.into_iter().flat_map(|word| word.to_le_bytes()).collect())
}

pub fn decode_arm(bytes: &[u8]) -> Result<ArmConfig, ProtoError> {
    let mut reader = Reader { bytes, i: 0 };
    reader.expect_u32(OPEN_SYNC)?;
    reader.expect_u16(H_MODE)?;
    let mut config = ArmConfig {
        mode: ModeFlags(reader.u16()?),
        ..ArmConfig::default()
    };
    reader.expect_u16(H_DIVIDER)?;
    config.divider = reader.u32_halves()?;
    reader.expect_u16(H_COUNT)?;
    config.sample_count = unpack_capture_count(reader.u32_halves()?);
    reader.expect_u16(H_POSITION)?;
    config.trigger_position = u64::from(reader.u32_halves()?);
    reader.expect_u16(H_GLOBAL)?;
    let global = reader.u16()?;
    config.channel_count = (global >> 8) as u8;
    config.stage_count = (global & 0xff) as u8;
    reader.expect_u16(H_SCOPE)?;
    config.scope_count = reader.u32_halves()?;
    reader.expect_u16(H_ENABLE)?;
    config.channel_enable = reader.u32_halves()?;
    reader.expect_u16(H_GAIN)?;
    config.fine_gain = reader.u16()?;
    reader.expect_u16(H_TRIGGER)?;
    let mask = reader.group_u32()?;
    let value = reader.group_u32()?;
    let edge = reader.group_u32()?;
    let logic0 = reader.array16()?;
    let _logic1 = reader.array16()?;
    for i in 0..STAGE_COUNT {
        config.stages[i] = Stage {
            mask: mask[i],
            value: value[i],
            edge: edge[i],
            invert: logic0[i] & 1 != 0,
            logic_or: logic0[i] & 2 != 0,
            count: reader.u32_halves()?,
        };
    }
    reader.expect_u32(CLOSE_SYNC)?;
    if reader.i < bytes.len() {
        reader.expect_u32(OPEN_SYNC)?;
        reader.expect_u16(H_UPPER)?;
        let mask = reader.group_u32()?;
        let value = reader.group_u32()?;
        let edge = reader.group_u32()?;
        reader.expect_u16(UPPER_ALIGN)?;
        reader.expect_u32(CLOSE_SYNC)?;
        let mut upper = [UpperStage::default(); STAGE_COUNT];
        for i in 0..STAGE_COUNT {
            upper[i] = UpperStage {
                mask: mask[i],
                value: value[i],
                edge: edge[i],
            };
        }
        config.upper = Some(upper);
    }
    if reader.i != bytes.len() {
        return Err(ProtoError::Truncated);
    }
    Ok(config)
}

fn logic_word(stage: &Stage) -> u16 {
    let mut word = 0u16;
    if stage.invert {
        word |= 1;
    }
    if stage.logic_or {
        word |= 1 << 1;
    }
    word
}

fn push_groups(words: &mut Vec<u16>, field: impl Fn(&Stage) -> u32, stages: &[Stage; STAGE_COUNT]) {
    for stage in stages {
        words.push(field(stage) as u16);
    }
    for stage in stages {
        words.push((field(stage) >> 16) as u16);
    }
}

fn push_upper(
    words: &mut Vec<u16>,
    stages: &[UpperStage; STAGE_COUNT],
    field: impl Fn(&UpperStage) -> u32,
) {
    for stage in stages {
        words.push(field(stage) as u16);
    }
    for stage in stages {
        words.push((field(stage) >> 16) as u16);
    }
}

fn push_u32(words: &mut Vec<u16>, value: u32) {
    words.push(value as u16);
    words.push((value >> 16) as u16);
}

fn fit_u32(value: u64) -> Result<u32, ProtoError> {
    u32::try_from(value).map_err(|_| ProtoError::FieldOverflow)
}

struct Reader<'a> {
    bytes: &'a [u8],
    i: usize,
}

impl Reader<'_> {
    fn u16(&mut self) -> Result<u16, ProtoError> {
        let slice = self.bytes.get(self.i..self.i + 2).ok_or(ProtoError::Truncated)?;
        self.i += 2;
        Ok(u16::from_le_bytes([slice[0], slice[1]]))
    }

    fn expect_u16(&mut self, expected: u16) -> Result<(), ProtoError> {
        let got = self.u16()?;
        if got != expected {
            Err(ProtoError::BadSectionLength((expected >> 8) as u8))
        } else {
            Ok(())
        }
    }

    fn expect_u32(&mut self, expected: u32) -> Result<(), ProtoError> {
        let lo = self.u16()? as u32;
        let hi = self.u16()? as u32;
        if (hi << 16) | lo != expected {
            Err(ProtoError::BadSync)
        } else {
            Ok(())
        }
    }

    fn u32_halves(&mut self) -> Result<u32, ProtoError> {
        let lo = self.u16()? as u32;
        let hi = self.u16()? as u32;
        Ok(lo | (hi << 16))
    }

    fn array16(&mut self) -> Result<[u16; STAGE_COUNT], ProtoError> {
        let mut out = [0u16; STAGE_COUNT];
        for slot in &mut out {
            *slot = self.u16()?;
        }
        Ok(out)
    }

    fn group_u32(&mut self) -> Result<[u32; STAGE_COUNT], ProtoError> {
        let low = self.array16()?;
        let high = self.array16()?;
        let mut out = [0u32; STAGE_COUNT];
        for i in 0..STAGE_COUNT {
            out[i] = low[i] as u32 | ((high[i] as u32) << 16);
        }
        Ok(out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn canonical() -> ArmConfig {
        let mut stages = [Stage::default(); 16];
        stages[0] = Stage {
            mask: 1,
            value: 1,
            edge: 1,
            invert: false,
            logic_or: false,
            count: 1,
        };
        ArmConfig {
            mode: ModeFlags(ModeFlags::TRIGGER_ENABLE | ModeFlags::STREAM),
            divider: 10,
            sample_count: 4096,
            trigger_position: 384,
            channel_count: 4,
            stage_count: 1,
            scope_count: 0,
            channel_enable: 0x0000_000F,
            fine_gain: 0,
            stages,
            upper: None,
        }
    }

    /// Hand-written word image for [`canonical`].
    ///
    /// Headers are index-in-high, length-in-low. Capture count is 4096 >> 4.
    /// Stage arrays are low-16 group then high-16 group, not per-stage pairs.
    fn hand_words() -> Vec<u16> {
        let mut words = Vec::new();
        words.extend_from_slice(&[0xF5A5, 0xF5A5]);
        words.extend_from_slice(&[0x0001, 0x1001]);
        words.extend_from_slice(&[0x0102, 10, 0]);
        words.extend_from_slice(&[0x0302, 256, 0]);
        words.extend_from_slice(&[0x0502, 384, 0]);
        words.extend_from_slice(&[0x0701, 0x0401]);
        words.extend_from_slice(&[0x0802, 0, 0]);
        words.extend_from_slice(&[0x0A02, 0x000F, 0]);
        words.extend_from_slice(&[0x0C01, 0]);
        words.push(0x40A0);
        words.push(1);
        words.extend(std::iter::repeat(0).take(15));
        words.extend(std::iter::repeat(0).take(16));
        words.push(1);
        words.extend(std::iter::repeat(0).take(15));
        words.extend(std::iter::repeat(0).take(16));
        words.push(1);
        words.extend(std::iter::repeat(0).take(15));
        words.extend(std::iter::repeat(0).take(16));
        words.extend(std::iter::repeat(0).take(32));
        words.push(1);
        words.push(0);
        words.extend(std::iter::repeat(0).take(30));
        words.extend_from_slice(&[0xFA5A, 0xFA5A]);
        words
    }

    #[test]
    fn arm_record_matches_the_hand_written_vector() {
        let expected: Vec<u8> = hand_words().into_iter().flat_map(|w| w.to_le_bytes()).collect();
        let encoded = encode_arm(&canonical()).unwrap();
        assert_eq!(encoded, expected);
        assert_eq!(encoded.len(), 372);
        assert_eq!(decode_arm(&encoded).unwrap(), canonical());
    }

    #[test]
    fn upper_channel_record_is_a_second_sync_pair() {
        let mut config = canonical();
        let mut upper = [UpperStage::default(); 16];
        upper[0].mask = 0x0001_0000;
        upper[3].edge = 0x00F0_0000;
        config.upper = Some(upper);
        let bytes = encode_arm(&config).unwrap();
        assert_eq!(bytes.len(), 372 + 204);
        let decoded = decode_arm(&bytes).unwrap();
        let upper = decoded.upper.unwrap();
        assert_eq!(upper[0].mask, 0x0001_0000);
        assert_eq!(upper[3].edge, 0x00F0_0000);
        assert_eq!(upper[1].value, 0);
        let opens = bytes
            .windows(4)
            .filter(|window| *window == OPEN_SYNC.to_le_bytes())
            .count();
        assert_eq!(opens, 2);
    }

    #[test]
    fn truncated_and_bad_sync_fail() {
        assert_eq!(decode_arm(&[0, 1, 2]), Err(ProtoError::Truncated));
        assert_eq!(
            decode_arm(&[0, 0, 0, 0, 0, 0, 0, 0]),
            Err(ProtoError::BadSync)
        );
        assert_eq!(
            decode_arm(&OPEN_SYNC.to_le_bytes()),
            Err(ProtoError::Truncated)
        );
    }
}
