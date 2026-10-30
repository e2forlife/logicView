//! Encodes the control-message envelope independently of device transport and destinations.

use crate::error::ProtoError;

/// Encode the 4-byte vendor control header: destination, little-endian offset, size.
///
/// This codec describes the envelope layout only. Hardware backends select
/// destination values and are responsible for validating device behavior.
pub fn encode_envelope_header(destination: u8, offset: u16, size: u8) -> [u8; 4] {
    [destination, offset as u8, (offset >> 8) as u8, size]
}

/// Reads the destination, offset, and payload length from a control envelope.
///
/// An incomplete envelope is rejected; bytes after the header are left to the caller.
pub fn decode_envelope_header(bytes: &[u8]) -> Result<(u8, u16, u8), ProtoError> {
    if bytes.len() < 4 {
        return Err(ProtoError::Truncated);
    }
    let offset = u16::from_le_bytes([bytes[1], bytes[2]]);
    Ok((bytes[0], offset, bytes[3]))
}

#[cfg(test)]
mod tests {
    //! Checks the vendor control envelope independently of a USB device.

    use super::*;

    /// Checks the control envelope against independently written byte fixtures.
    #[test]
    fn envelope_header_layout_is_dest_offset_le_size() {
        // Hand-written: destination 0x01, offset 0x0010, size 4.
        assert_eq!(
            encode_envelope_header(0x01, 0x0010, 4),
            [0x01, 0x10, 0x00, 0x04]
        );
        assert_eq!(
            decode_envelope_header(&[0x2A, 0x34, 0x12, 60]).unwrap(),
            (0x2A, 0x1234, 60)
        );
        assert_eq!(
            decode_envelope_header(&[0x00, 0x00]).unwrap_err(),
            ProtoError::Truncated
        );
    }
}
