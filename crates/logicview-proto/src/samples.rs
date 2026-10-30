//! Converts device logic payloads to and from the per-channel streams used for analysis.
//!
//! Capture sources use atoms for transport; stores and decoders use packed bits
//! for individual channels.

use crate::error::ProtoError;

/// Samples in one logic atom.
pub const ATOM_SAMPLES: usize = 64;

/// Packed bytes of one channel inside one atom (64 bits).
pub const BYTES_PER_CHANNEL_ATOM: usize = 8;

/// `sample count = bytes × 8 / enabled channels`.
pub fn logic_sample_count(byte_len: u64, enabled_channels: u64) -> u64 {
    if enabled_channels == 0 {
        return 0;
    }
    byte_len.saturating_mul(8) / enabled_channels
}

/// Split atom-major logic bytes into one packed stream per channel.
///
/// An atom is 64 samples. Inside the atom, channel 0's 8 bytes come first,
/// then channel 1, and so on, in channel-index order. Within a channel, bit 0
/// of byte 0 is the earliest sample.
pub fn unpack_logic_atoms(bytes: &[u8], channels: usize) -> Result<Vec<Vec<u8>>, ProtoError> {
    if channels == 0 {
        return Err(ProtoError::NoChannels);
    }
    let atom = channels * BYTES_PER_CHANNEL_ATOM;
    if !bytes.len().is_multiple_of(atom) {
        return Err(ProtoError::BadAtom {
            len: bytes.len(),
            channels,
        });
    }
    let atoms = bytes.len() / atom;
    let mut out = vec![vec![0u8; atoms * BYTES_PER_CHANNEL_ATOM]; channels];
    for atom_index in 0..atoms {
        for (channel, dest) in out.iter_mut().enumerate() {
            let src = (atom_index * channels + channel) * BYTES_PER_CHANNEL_ATOM;
            let dst = atom_index * BYTES_PER_CHANNEL_ATOM;
            dest[dst..dst + BYTES_PER_CHANNEL_ATOM]
                .copy_from_slice(&bytes[src..src + BYTES_PER_CHANNEL_ATOM]);
        }
    }
    Ok(out)
}

/// Inverse of [`unpack_logic_atoms`]. Every channel must be the same length
/// and a multiple of 8 bytes.
pub fn pack_logic_atoms(channels: &[Vec<u8>]) -> Result<Vec<u8>, ProtoError> {
    if channels.is_empty() {
        return Err(ProtoError::NoChannels);
    }
    let width = channels[0].len();
    if !width.is_multiple_of(BYTES_PER_CHANNEL_ATOM) || channels.iter().any(|c| c.len() != width) {
        return Err(ProtoError::UnevenChannels);
    }
    let atoms = width / BYTES_PER_CHANNEL_ATOM;
    let n = channels.len();
    let mut out = vec![0u8; atoms * n * BYTES_PER_CHANNEL_ATOM];
    for atom_index in 0..atoms {
        for (channel, bytes) in channels.iter().enumerate() {
            let src = atom_index * BYTES_PER_CHANNEL_ATOM;
            let dst = (atom_index * n + channel) * BYTES_PER_CHANNEL_ATOM;
            out[dst..dst + BYTES_PER_CHANNEL_ATOM]
                .copy_from_slice(&bytes[src..src + BYTES_PER_CHANNEL_ATOM]);
        }
    }
    Ok(out)
}

/// Read one LSB-first packed bit. `index` 0 is bit 0 of byte 0.
pub fn bit_at(bytes: &[u8], index: u64) -> bool {
    let byte = bytes.get((index / 8) as usize).copied().unwrap_or(0);
    (byte >> (index % 8)) & 1 == 1
}

#[cfg(test)]
mod tests {
    //! Checks conversion between transport atoms and analysis channel streams.

    use super::*;

    /// Checks that transport atoms preserve channel identity and sample order.
    #[test]
    fn unpack_vector_splits_channels_in_index_order() {
        // Two channels, one atom (16 bytes). Hand-written bits:
        // channel 0 byte 0 = 0b0001_0101 → samples 0, 2, 4 high
        // channel 1 byte 0 = 0b0000_1010 → samples 1, 3 high
        let atom = [
            0x15, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00,
        ];
        assert_eq!(logic_sample_count(atom.len() as u64, 2), 64);
        let chans = unpack_logic_atoms(&atom, 2).unwrap();
        assert!(bit_at(&chans[0], 0));
        assert!(!bit_at(&chans[0], 1));
        assert!(bit_at(&chans[0], 2));
        assert!(bit_at(&chans[0], 4));
        assert!(!bit_at(&chans[0], 3));
        assert!(bit_at(&chans[1], 1));
        assert!(bit_at(&chans[1], 3));
        assert!(!bit_at(&chans[1], 0));
        assert!(!bit_at(&chans[1], 2));
        assert_eq!(pack_logic_atoms(&chans).unwrap(), atom);
    }

    /// Checks that incomplete payloads and incompatible channel streams are rejected.
    #[test]
    fn uneven_or_short_buffers_fail() {
        assert_eq!(
            unpack_logic_atoms(&[0, 1, 2], 1),
            Err(ProtoError::BadAtom {
                len: 3,
                channels: 1
            })
        );
        assert_eq!(pack_logic_atoms(&[]), Err(ProtoError::NoChannels));
        assert_eq!(
            pack_logic_atoms(&[vec![0; 8], vec![0; 7]]),
            Err(ProtoError::UnevenChannels)
        );
    }
}
