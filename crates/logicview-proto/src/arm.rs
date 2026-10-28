//! Arm-record codec.
//!
//! A record opens with `0xF5A5F5A5` and closes with `0xFA5AFA5A`. Between the
//! sync words are tagged sections. Each section is a 16-bit header (tag in the
//! low byte, payload length in 16-bit words in the high byte) followed by that
//! many little-endian words.
//!
//! Tag numbers are LogicView assignments of the section list in the spec.
//! They are locked by the fixture in this file. A hardware phase has to
//! confirm the on-wire image before these bytes are written to a pod.
//!
//! A second record, with the same sync words, carries mask/value/edge for
//! channels 16–31 when the caller asks for it.

use crate::error::ProtoError;
use crate::mode::ModeFlags;
use crate::{pack_capture_count, unpack_capture_count};

pub const OPEN_SYNC: u32 = 0xF5A5_F5A5;
pub const CLOSE_SYNC: u32 = 0xFA5A_FA5A;

pub const TAG_MODE: u8 = 1;
pub const TAG_DIVIDER: u8 = 2;
pub const TAG_CAPTURE_COUNT: u8 = 3;
pub const TAG_TRIGGER_POSITION: u8 = 4;
pub const TAG_GLOBAL_TRIGGER: u8 = 5;
pub const TAG_SCOPE_COUNT: u8 = 6;
pub const TAG_CHANNEL_ENABLE: u8 = 7;
pub const TAG_FINE_GAIN: u8 = 8;
pub const TAG_STAGE_MASK: u8 = 9;
pub const TAG_STAGE_VALUE: u8 = 10;
pub const TAG_STAGE_EDGE: u8 = 11;
pub const TAG_STAGE_CTRL: u8 = 12;
pub const TAG_STAGE_COUNT: u8 = 13;
pub const TAG_UPPER_MASK: u8 = 21;
pub const TAG_UPPER_VALUE: u8 = 22;
pub const TAG_UPPER_EDGE: u8 = 23;

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
    /// Post-divider stored as a 32-bit word split into two 16-bit halves.
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
    let mut out = Vec::new();
    out.extend_from_slice(&OPEN_SYNC.to_le_bytes());
    push_section(&mut out, TAG_MODE, &[config.mode.0])?;
    push_section(&mut out, TAG_DIVIDER, &u32_halves(config.divider)?)?;
    push_section(
        &mut out,
        TAG_CAPTURE_COUNT,
        &u32_halves(pack_capture_count(config.sample_count))?,
    )?;
    push_section(
        &mut out,
        TAG_TRIGGER_POSITION,
        &u32_halves(fit_u32(config.trigger_position)?)?,
    )?;
    let global = ((config.channel_count as u16) << 8) | config.stage_count as u16;
    push_section(&mut out, TAG_GLOBAL_TRIGGER, &[global])?;
    push_section(&mut out, TAG_SCOPE_COUNT, &u32_halves(config.scope_count)?)?;
    push_section(
        &mut out,
        TAG_CHANNEL_ENABLE,
        &u32_halves(config.channel_enable)?,
    )?;
    push_section(&mut out, TAG_FINE_GAIN, &[config.fine_gain])?;

    let mut mask = Vec::with_capacity(32);
    let mut value = Vec::with_capacity(32);
    let mut edge = Vec::with_capacity(32);
    let mut ctrl = Vec::with_capacity(16);
    let mut count = Vec::with_capacity(32);
    for stage in &config.stages {
        push_halves(&mut mask, stage.mask)?;
        push_halves(&mut value, stage.value)?;
        push_halves(&mut edge, stage.edge)?;
        let mut word = 0u16;
        if stage.invert {
            word |= 1;
        }
        if stage.logic_or {
            word |= 1 << 1;
        }
        ctrl.push(word);
        push_halves(&mut count, stage.count)?;
    }
    push_section(&mut out, TAG_STAGE_MASK, &mask)?;
    push_section(&mut out, TAG_STAGE_VALUE, &value)?;
    push_section(&mut out, TAG_STAGE_EDGE, &edge)?;
    push_section(&mut out, TAG_STAGE_CTRL, &ctrl)?;
    push_section(&mut out, TAG_STAGE_COUNT, &count)?;
    out.extend_from_slice(&CLOSE_SYNC.to_le_bytes());

    if let Some(upper) = &config.upper {
        out.extend_from_slice(&OPEN_SYNC.to_le_bytes());
        let mut umask = Vec::with_capacity(32);
        let mut uvalue = Vec::with_capacity(32);
        let mut uedge = Vec::with_capacity(32);
        for stage in upper {
            push_halves(&mut umask, stage.mask)?;
            push_halves(&mut uvalue, stage.value)?;
            push_halves(&mut uedge, stage.edge)?;
        }
        push_section(&mut out, TAG_UPPER_MASK, &umask)?;
        push_section(&mut out, TAG_UPPER_VALUE, &uvalue)?;
        push_section(&mut out, TAG_UPPER_EDGE, &uedge)?;
        out.extend_from_slice(&CLOSE_SYNC.to_le_bytes());
    }
    Ok(out)
}

pub fn decode_arm(bytes: &[u8]) -> Result<ArmConfig, ProtoError> {
    let (sections, used) = parse_record(bytes)?;
    let mut config = ArmConfig::default();
    let mut seen = [false; 14];
    for (tag, words) in &sections {
        match *tag {
            TAG_MODE => {
                expect_len(TAG_MODE, words, 1)?;
                config.mode = ModeFlags(words[0]);
                seen[0] = true;
            }
            TAG_DIVIDER => {
                config.divider = take_u32(TAG_DIVIDER, words)?;
                seen[1] = true;
            }
            TAG_CAPTURE_COUNT => {
                config.sample_count = unpack_capture_count(take_u32(TAG_CAPTURE_COUNT, words)?);
                seen[2] = true;
            }
            TAG_TRIGGER_POSITION => {
                config.trigger_position = take_u32(TAG_TRIGGER_POSITION, words)? as u64;
                seen[3] = true;
            }
            TAG_GLOBAL_TRIGGER => {
                expect_len(TAG_GLOBAL_TRIGGER, words, 1)?;
                config.stage_count = (words[0] & 0xff) as u8;
                config.channel_count = (words[0] >> 8) as u8;
                seen[4] = true;
            }
            TAG_SCOPE_COUNT => {
                config.scope_count = take_u32(TAG_SCOPE_COUNT, words)?;
                seen[5] = true;
            }
            TAG_CHANNEL_ENABLE => {
                config.channel_enable = take_u32(TAG_CHANNEL_ENABLE, words)?;
                seen[6] = true;
            }
            TAG_FINE_GAIN => {
                expect_len(TAG_FINE_GAIN, words, 1)?;
                config.fine_gain = words[0];
                seen[7] = true;
            }
            TAG_STAGE_MASK => {
                apply_u32_pairs(TAG_STAGE_MASK, words, |i, v| config.stages[i].mask = v)?;
                seen[8] = true;
            }
            TAG_STAGE_VALUE => {
                apply_u32_pairs(TAG_STAGE_VALUE, words, |i, v| config.stages[i].value = v)?;
                seen[9] = true;
            }
            TAG_STAGE_EDGE => {
                apply_u32_pairs(TAG_STAGE_EDGE, words, |i, v| config.stages[i].edge = v)?;
                seen[10] = true;
            }
            TAG_STAGE_CTRL => {
                expect_len(TAG_STAGE_CTRL, words, STAGE_COUNT)?;
                for (i, word) in words.iter().enumerate() {
                    config.stages[i].invert = word & 1 != 0;
                    config.stages[i].logic_or = word & (1 << 1) != 0;
                }
                seen[11] = true;
            }
            TAG_STAGE_COUNT => {
                apply_u32_pairs(TAG_STAGE_COUNT, words, |i, v| config.stages[i].count = v)?;
                seen[12] = true;
            }
            other => {
                let _ = other;
            }
        }
    }
    for (i, tag) in [
        TAG_MODE,
        TAG_DIVIDER,
        TAG_CAPTURE_COUNT,
        TAG_TRIGGER_POSITION,
        TAG_GLOBAL_TRIGGER,
        TAG_SCOPE_COUNT,
        TAG_CHANNEL_ENABLE,
        TAG_FINE_GAIN,
        TAG_STAGE_MASK,
        TAG_STAGE_VALUE,
        TAG_STAGE_EDGE,
        TAG_STAGE_CTRL,
        TAG_STAGE_COUNT,
    ]
    .into_iter()
    .enumerate()
    {
        if !seen[i] {
            return Err(ProtoError::MissingSection(tag));
        }
    }

    if used < bytes.len() {
        let (upper_sections, upper_used) = parse_record(&bytes[used..])?;
        if used + upper_used != bytes.len() {
            return Err(ProtoError::Truncated);
        }
        let mut upper = [UpperStage::default(); STAGE_COUNT];
        let mut got_mask = false;
        let mut got_value = false;
        let mut got_edge = false;
        for (tag, words) in &upper_sections {
            match *tag {
                TAG_UPPER_MASK => {
                    apply_u32_pairs(TAG_UPPER_MASK, words, |i, v| upper[i].mask = v)?;
                    got_mask = true;
                }
                TAG_UPPER_VALUE => {
                    apply_u32_pairs(TAG_UPPER_VALUE, words, |i, v| upper[i].value = v)?;
                    got_value = true;
                }
                TAG_UPPER_EDGE => {
                    apply_u32_pairs(TAG_UPPER_EDGE, words, |i, v| upper[i].edge = v)?;
                    got_edge = true;
                }
                _ => {}
            }
        }
        if !(got_mask && got_value && got_edge) {
            return Err(ProtoError::MissingSection(TAG_UPPER_MASK));
        }
        config.upper = Some(upper);
    }
    Ok(config)
}

type RecordSections = Vec<(u8, Vec<u16>)>;

fn parse_record(bytes: &[u8]) -> Result<(RecordSections, usize), ProtoError> {
    if bytes.len() < 8 {
        return Err(ProtoError::Truncated);
    }
    let open = read_u32(bytes, 0)?;
    if open != OPEN_SYNC {
        return Err(ProtoError::BadSync);
    }
    let mut i = 4;
    let mut sections = Vec::new();
    loop {
        if i + 4 <= bytes.len() {
            let maybe = read_u32(bytes, i)?;
            let at_end = i + 4 == bytes.len();
            let next_is_open = i + 8 <= bytes.len() && read_u32(bytes, i + 4)? == OPEN_SYNC;
            if maybe == CLOSE_SYNC && (at_end || next_is_open) {
                return Ok((sections, i + 4));
            }
        }
        if i + 2 > bytes.len() {
            return Err(ProtoError::Truncated);
        }
        let header = u16::from_le_bytes([bytes[i], bytes[i + 1]]);
        let tag = (header & 0xff) as u8;
        let count = (header >> 8) as usize;
        i += 2;
        if i + count * 2 > bytes.len() {
            return Err(ProtoError::Truncated);
        }
        let mut words = Vec::with_capacity(count);
        for _ in 0..count {
            words.push(u16::from_le_bytes([bytes[i], bytes[i + 1]]));
            i += 2;
        }
        sections.push((tag, words));
    }
}

fn push_section(out: &mut Vec<u8>, tag: u8, words: &[u16]) -> Result<(), ProtoError> {
    if words.len() > 255 {
        return Err(ProtoError::SectionTooLarge);
    }
    let header = (tag as u16) | ((words.len() as u16) << 8);
    out.extend_from_slice(&header.to_le_bytes());
    for word in words {
        out.extend_from_slice(&word.to_le_bytes());
    }
    Ok(())
}

fn u32_halves(value: u32) -> Result<[u16; 2], ProtoError> {
    Ok([value as u16, (value >> 16) as u16])
}

fn push_halves(words: &mut Vec<u16>, value: u32) -> Result<(), ProtoError> {
    let halves = u32_halves(value)?;
    words.extend_from_slice(&halves);
    Ok(())
}

fn fit_u32(value: u64) -> Result<u32, ProtoError> {
    u32::try_from(value).map_err(|_| ProtoError::FieldOverflow)
}

fn read_u32(bytes: &[u8], at: usize) -> Result<u32, ProtoError> {
    let slice = bytes.get(at..at + 4).ok_or(ProtoError::Truncated)?;
    let mut buf = [0u8; 4];
    buf.copy_from_slice(slice);
    Ok(u32::from_le_bytes(buf))
}

fn expect_len(tag: u8, words: &[u16], len: usize) -> Result<(), ProtoError> {
    if words.len() != len {
        Err(ProtoError::BadSectionLength(tag))
    } else {
        Ok(())
    }
}

fn take_u32(tag: u8, words: &[u16]) -> Result<u32, ProtoError> {
    expect_len(tag, words, 2)?;
    Ok((words[0] as u32) | ((words[1] as u32) << 16))
}

fn apply_u32_pairs(
    tag: u8,
    words: &[u16],
    mut set: impl FnMut(usize, u32),
) -> Result<(), ProtoError> {
    if words.len() != STAGE_COUNT * 2 {
        return Err(ProtoError::BadSectionLength(tag));
    }
    for i in 0..STAGE_COUNT {
        let value = (words[i * 2] as u32) | ((words[i * 2 + 1] as u32) << 16);
        set(i, value);
    }
    Ok(())
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

    #[test]
    fn arm_record_matches_the_hand_written_vector() {
        // Built by hand from the layout above for `canonical()`:
        // sync, mode 0x1001, divider 10, capture count 4096>>4 = 256,
        // trigger position 384, global trigger channel=4 stage=1,
        // scope 0, enable 0xF, gain 0, stage 0 mask/value/edge/count = 1,
        // every other stage word 0, closing sync. No upper record.
        let hex = "a5f5a5f50101011002020a0000000302000100000402800100000501010406020000000007020f000000080100000920010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a20010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b20010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c1000000000000000000000000000000000000000000000000000000000000000000d20010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005afa5afa";
        let expected = decode_hex(hex);
        let encoded = encode_arm(&canonical()).unwrap();
        assert_eq!(encoded, expected);
        assert_eq!(decode_arm(&encoded).unwrap(), canonical());
        assert_eq!(encoded.len(), 348);
    }

    #[test]
    fn upper_channel_record_is_a_second_sync_pair() {
        let mut config = canonical();
        let mut upper = [UpperStage::default(); 16];
        upper[0].mask = 0x0001_0000;
        upper[3].edge = 0x00F0_0000;
        config.upper = Some(upper);
        let bytes = encode_arm(&config).unwrap();
        assert!(bytes.len() > 348);
        let decoded = decode_arm(&bytes).unwrap();
        let upper = decoded.upper.unwrap();
        assert_eq!(upper[0].mask, 0x0001_0000);
        assert_eq!(upper[3].edge, 0x00F0_0000);
        assert_eq!(upper[1].value, 0);
        // Two opening syncs: the low record and the upper record.
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

    fn decode_hex(s: &str) -> Vec<u8> {
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
            .collect()
    }
}
