//! Clean-room capture contract.
//!
//! Byte layouts in this crate are LogicView's reading of the instrument
//! behavior we implement against. They are locked by fixtures in the tests.
//! Fields that still need a measurement on real hardware are called out next
//! to the constant. Nothing here speaks USB.

mod arm;
mod dsl;
mod envelope;
mod error;
mod header;
mod mode;
mod samples;

pub use arm::{decode_arm, encode_arm, ArmConfig, Stage, UpperStage, CLOSE_SYNC, OPEN_SYNC};
pub use dsl::{write_dsl_header, DslHeader, DslProbe};
pub use envelope::{decode_envelope_header, encode_envelope_header};
pub use error::ProtoError;
pub use header::{
    actual_payload_bytes, actual_sample_count, encode_logic_header, parse_logic_header,
    LogicHeader, LOGIC_CHECK_WORD, LOGIC_HEADER_LEN, LOGIC_HEADER_TRANSFER,
};
pub use mode::{logic_divider, DepthMode, ModeFlags};
pub use samples::{
    bit_at, logic_sample_count, pack_logic_atoms, unpack_logic_atoms, ATOM_SAMPLES,
    BYTES_PER_CHANNEL_ATOM,
};

/// Right-shift applied when a sample count is packed into an arm record.
///
/// Measured on a high-speed DSLogic Plus, vendor `0x2A0E` product `0x0020`,
/// one channel enabled, instant captures, 2026-10-28. The pod wrote that many
/// bytes and then left the previous buffer contents in place:
///
/// | packed count | bytes kept | samples (`bytes * 8`) |
/// | --- | --- | --- |
/// | `0x10` | 32 | 256 |
/// | `0x40` | 128 | 1024 |
/// | `0x80` | 256 | 2048 |
///
/// `samples == packed << 4`, so the shift is 4. A shift of 6 would have kept
/// four times as many bytes.
pub const CAPTURE_COUNT_SHIFT: u32 = 4;

/// Trigger positions are aligned down to this many samples.
pub const TRIGGER_ALIGN_SAMPLES: u64 = 64;

/// Percent of a buffer-mode record that pre-trigger is allowed to occupy.
pub const BUFFER_TRIGGER_CAP_NUM: u64 = 9;
pub const BUFFER_TRIGGER_CAP_DEN: u64 = 10;

/// Percent of a stream-mode record that pre-trigger is allowed to occupy.
pub const STREAM_TRIGGER_CAP_NUM: u64 = 1;
pub const STREAM_TRIGGER_CAP_DEN: u64 = 10;

/// Place a trigger inside a record.
///
/// `percent` is 0–100 of `sample_count`. The result is at least 64 samples
/// when the record is that long, aligned down to 64, and capped at 90% of the
/// record in buffer mode or 10% in stream mode.
pub fn align_trigger_position(sample_count: u64, percent: f64, mode: DepthMode) -> u64 {
    if sample_count == 0 {
        return 0;
    }
    let percent = if percent.is_finite() {
        percent.clamp(0.0, 100.0)
    } else {
        0.0
    };
    let raw = (sample_count as f64 * (percent / 100.0)).floor() as u64;
    let cap = match mode {
        DepthMode::Buffer => sample_count * BUFFER_TRIGGER_CAP_NUM / BUFFER_TRIGGER_CAP_DEN,
        DepthMode::Stream => sample_count * STREAM_TRIGGER_CAP_NUM / STREAM_TRIGGER_CAP_DEN,
    };
    let mut pos = raw.min(cap).min(sample_count);
    if sample_count >= TRIGGER_ALIGN_SAMPLES {
        pos = pos.max(TRIGGER_ALIGN_SAMPLES.min(cap));
    }
    let aligned = pos & !(TRIGGER_ALIGN_SAMPLES - 1);
    if sample_count >= TRIGGER_ALIGN_SAMPLES
        && aligned < TRIGGER_ALIGN_SAMPLES
        && cap >= TRIGGER_ALIGN_SAMPLES
    {
        TRIGGER_ALIGN_SAMPLES
    } else {
        aligned
    }
}

/// Pack a sample count the way the arm record stores it (`>> CAPTURE_COUNT_SHIFT`).
pub fn pack_capture_count(samples: u64) -> u32 {
    (samples >> CAPTURE_COUNT_SHIFT) as u32
}

/// Invert [`pack_capture_count`]. Low bits below the shift are not recoverable.
pub fn unpack_capture_count(packed: u32) -> u64 {
    (packed as u64) << CAPTURE_COUNT_SHIFT
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn trigger_position_matches_hand_computed_cases() {
        assert_eq!(
            align_trigger_position(10_000, 50.0, DepthMode::Buffer),
            4992
        );
        assert_eq!(align_trigger_position(10_000, 50.0, DepthMode::Stream), 960);
        assert_eq!(align_trigger_position(10_000, 0.0, DepthMode::Buffer), 64);
        assert_eq!(
            align_trigger_position(10_000, 99.0, DepthMode::Buffer),
            8960
        );
        assert_eq!(align_trigger_position(0, 50.0, DepthMode::Buffer), 0);
    }

    #[test]
    fn capture_count_shift_matches_the_plus_capture() {
        assert_eq!(CAPTURE_COUNT_SHIFT, 4);
        assert_eq!(pack_capture_count(4096), 256);
        assert_eq!(unpack_capture_count(256), 4096);
        // The shift discards bits below the quantum. 4097 cannot round-trip.
        assert_eq!(unpack_capture_count(pack_capture_count(4097)), 4096);
        // One enabled channel: payload bytes = samples / 8.
        assert_eq!(unpack_capture_count(0x10) / 8, 32);
        assert_eq!(unpack_capture_count(0x40) / 8, 128);
        assert_eq!(unpack_capture_count(0x80) / 8, 256);
    }

    #[test]
    fn kept_samples_drop_the_remainder_and_align_to_64() {
        assert_eq!(actual_sample_count(10_000, 100), 9856);
        assert_eq!(actual_sample_count(64, 0), 64);
        assert_eq!(actual_sample_count(63, 0), 0);
        assert_eq!(actual_sample_count(100, 100), 0);
        assert_eq!(actual_payload_bytes(4096, 4), 2048);
    }
}
