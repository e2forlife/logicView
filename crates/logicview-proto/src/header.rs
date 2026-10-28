use crate::error::ProtoError;

/// First bulk-IN word of a logic capture. A mismatch means the capture is bad.
pub const LOGIC_CHECK_WORD: u32 = 0x5555_5555;

/// Packed logic header length: check, trigger position, RAM start, remaining, status.
pub const LOGIC_HEADER_LEN: usize = 20;

/// Host-side view of the logic trigger header.
///
/// Layout, little-endian:
/// - `0x00` check word (`0x55555555`)
/// - `0x04` trigger position in samples
/// - `0x08` RAM start address
/// - `0x0C` remaining sample count (`low` in bits 0..15, `high` in bits 16..31)
/// - `0x10` status word
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct LogicHeader {
    pub check_word: u32,
    pub trigger_position: u32,
    pub ram_start: u32,
    pub remaining: u32,
    pub status: u32,
}

impl LogicHeader {
    pub fn remaining_low(self) -> u16 {
        self.remaining as u16
    }

    pub fn remaining_high(self) -> u16 {
        (self.remaining >> 16) as u16
    }
}

pub fn encode_logic_header(header: &LogicHeader) -> [u8; LOGIC_HEADER_LEN] {
    let mut out = [0u8; LOGIC_HEADER_LEN];
    out[0..4].copy_from_slice(&header.check_word.to_le_bytes());
    out[4..8].copy_from_slice(&header.trigger_position.to_le_bytes());
    out[8..12].copy_from_slice(&header.ram_start.to_le_bytes());
    out[12..16].copy_from_slice(&header.remaining.to_le_bytes());
    out[16..20].copy_from_slice(&header.status.to_le_bytes());
    out
}

pub fn parse_logic_header(bytes: &[u8]) -> Result<LogicHeader, ProtoError> {
    if bytes.len() < LOGIC_HEADER_LEN {
        return Err(ProtoError::Truncated);
    }
    let header = LogicHeader {
        check_word: read_u32(bytes, 0)?,
        trigger_position: read_u32(bytes, 4)?,
        ram_start: read_u32(bytes, 8)?,
        remaining: read_u32(bytes, 12)?,
        status: read_u32(bytes, 16)?,
    };
    if header.check_word != LOGIC_CHECK_WORD {
        return Err(ProtoError::BadCheckWord(header.check_word));
    }
    Ok(header)
}

/// Samples actually stored: requested minus remaining, aligned down to 64.
pub fn actual_sample_count(requested: u64, remaining: u64) -> u64 {
    requested.saturating_sub(remaining) & !63
}

/// Byte size of an expanded logic payload: atoms × enabled channels × 8.
pub fn actual_payload_bytes(actual_samples: u64, enabled_channels: u64) -> u64 {
    let atoms = actual_samples / 64;
    atoms.saturating_mul(enabled_channels).saturating_mul(8)
}

fn read_u32(bytes: &[u8], at: usize) -> Result<u32, ProtoError> {
    let slice = bytes.get(at..at + 4).ok_or(ProtoError::Truncated)?;
    let mut buf = [0u8; 4];
    buf.copy_from_slice(slice);
    Ok(u32::from_le_bytes(buf))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn header_vector_round_trips() {
        // Hand-written little-endian image:
        // check 0x55555555, trigger 384, ram 0, remaining 64, status 1.
        let hex = "5555555580010000000000004000000001000000";
        let bytes = decode_hex(hex);
        assert_eq!(bytes.len(), LOGIC_HEADER_LEN);
        let parsed = parse_logic_header(&bytes).unwrap();
        assert_eq!(parsed.check_word, LOGIC_CHECK_WORD);
        assert_eq!(parsed.trigger_position, 384);
        assert_eq!(parsed.ram_start, 0);
        assert_eq!(parsed.remaining_low(), 64);
        assert_eq!(parsed.remaining_high(), 0);
        assert_eq!(parsed.status, 1);
        assert_eq!(encode_logic_header(&parsed).to_vec(), bytes);
    }

    #[test]
    fn bad_check_word_is_a_data_error() {
        let mut bytes = encode_logic_header(&LogicHeader {
            check_word: LOGIC_CHECK_WORD,
            trigger_position: 0,
            ram_start: 0,
            remaining: 0,
            status: 0,
        });
        bytes[0] = 0;
        assert!(matches!(
            parse_logic_header(&bytes),
            Err(ProtoError::BadCheckWord(_))
        ));
        assert_eq!(parse_logic_header(&[0, 1, 2]), Err(ProtoError::Truncated));
    }

    fn decode_hex(s: &str) -> Vec<u8> {
        (0..s.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
            .collect()
    }
}
