//! I2C from NXP UM10204.
//!
//! A start is SDA falling while SCL is high. A stop is SDA rising while SCL
//! is high. Data bits are sampled on the rising edge of SCL, MSB first, eight
//! bits then an ACK (SDA low) or NACK (SDA high). The first byte after a start
//! is a 7-bit address plus the read/write bit.

use std::collections::BTreeMap;

use super::{Annotation, Decoder, DecodeError, SampleSlice};

/// Stateful I2C bus interpreter with an optional address filter.
#[derive(Clone, Debug)]
pub struct I2cDecoder {
    primed: bool,
    prev_scl: bool,
    prev_sda: bool,
    in_frame: bool,
    expect_address: bool,
    /// 7-bit address filter. `None` keeps every transaction.
    address: Option<u8>,
    shown: bool,
    acc: u8,
    bits: u8,
    byte_start: u64,
}

impl Default for I2cDecoder {
    /// Creates an idle I2C decoder that retains transactions for every address.
    fn default() -> Self {
        Self {
            primed: false,
            prev_scl: true,
            prev_sda: true,
            in_frame: false,
            expect_address: false,
            address: None,
            shown: false,
            acc: 0,
            bits: 0,
            byte_start: 0,
        }
    }
}

impl Decoder for I2cDecoder {
    /// Returns the stable identifier used to select this protocol in engine commands.
    fn id(&self) -> &'static str {
        "i2c"
    }

    /// Returns the display name for this protocol analyzer.
    fn name(&self) -> &'static str {
        "I2C"
    }

    /// Lists the signal roles the engine maps to captured channels.
    fn channels(&self) -> &'static [&'static str] {
        &["scl", "sda"]
    }

    /// Clears partial protocol state while preserving the selected decoding options.
    fn reset(&mut self) {
        let address = self.address;
        *self = Self {
            address,
            ..Self::default()
        };
    }

    /// Tracks bus starts, stops, bytes, and acknowledgments across contiguous capture slices.
    fn feed(&mut self, slice: &SampleSlice<'_>) -> Vec<Annotation> {
        let mut out = Vec::new();
        let mut index = slice.start;
        let end = slice.end();
        if !self.primed {
            if slice.len == 0 {
                return out;
            }
            self.prev_scl = slice.bit("scl", index);
            self.prev_sda = slice.bit("sda", index);
            self.primed = true;
            index += 1;
        }
        while index < end {
            let scl = slice.bit("scl", index);
            let sda = slice.bit("sda", index);
            if self.prev_scl && scl && self.prev_sda && !sda {
                self.in_frame = true;
                self.expect_address = true;
                self.acc = 0;
                self.bits = 0;
                self.byte_start = index;
                self.shown = self.address.is_none();
                if self.shown {
                    out.push(note(index, index + 1, "start", "Start", BTreeMap::new()));
                }
            } else if self.prev_scl && scl && !self.prev_sda && sda {
                if self.shown {
                    out.push(note(index, index + 1, "stop", "Stop", BTreeMap::new()));
                }
                self.in_frame = false;
                self.bits = 0;
                self.acc = 0;
                self.shown = self.address.is_none();
            } else if self.in_frame && !self.prev_scl && scl {
                if self.bits == 0 {
                    self.byte_start = index;
                }
                if self.bits < 8 {
                    self.acc = (self.acc << 1) | u8::from(sda);
                    self.bits += 1;
                } else {
                    let data = self.acc;
                    let acked = !sda;
                    if self.expect_address {
                        let read = data & 1 == 1;
                        let addr = data >> 1;
                        self.shown = self.address.is_none() || self.address == Some(addr);
                        if self.shown {
                            let mut fields = BTreeMap::new();
                            fields.insert("address".into(), format!("{addr:02X}"));
                            fields.insert("read".into(), if read { "true" } else { "false" }.into());
                            fields.insert("raw".into(), format!("{data:02X}"));
                            let text = if read {
                                format!("Read 0x{addr:02X}")
                            } else {
                                format!("Write 0x{addr:02X}")
                            };
                            out.push(note(self.byte_start, index + 1, "address", text, fields));
                        }
                        self.expect_address = false;
                    } else if self.shown {
                        let mut fields = BTreeMap::new();
                        fields.insert("data".into(), format!("{data:02X}"));
                        out.push(note(
                            self.byte_start,
                            index + 1,
                            "data",
                            format!("Data 0x{data:02X}"),
                            fields,
                        ));
                    }
                    if self.shown {
                        let mut ack_fields = BTreeMap::new();
                        ack_fields.insert("ack".into(), if acked { "true" } else { "false" }.into());
                        if acked {
                            out.push(note(index, index + 1, "ack", "ACK", ack_fields));
                        } else {
                            out.push(note(index, index + 1, "nack", "NACK", ack_fields));
                        }
                    }
                    self.bits = 0;
                    self.acc = 0;
                }
            }
            self.prev_scl = scl;
            self.prev_sda = sda;
            index += 1;
        }
        out
    }

    /// Produces no extra rows because only complete protocol events are emitted during feeding.
    fn finish(&mut self) -> Vec<Annotation> {
        Vec::new()
    }

    /// Selects a hexadecimal I2C address filter or restores decoding of all addresses.
    fn set_option(&mut self, key: &str, value: &str) -> Result<(), DecodeError> {
        if key != "address" {
            return Err(DecodeError::UnknownOption(key.into()));
        }
        let trimmed = value.trim();
        if trimmed.is_empty() || trimmed.eq_ignore_ascii_case("any") {
            self.address = None;
            return Ok(());
        }
        let hex = trimmed
            .strip_prefix("0x")
            .or_else(|| trimmed.strip_prefix("0X"))
            .unwrap_or(trimmed);
        let addr = u8::from_str_radix(hex, 16).map_err(|_| {
            DecodeError::Message("address must be a 7-bit hex value".into())
        })?;
        if addr > 0x7f {
            return Err(DecodeError::Message("address must be 7 bits".into()));
        }
        self.address = Some(addr);
        Ok(())
    }
}

/// Creates an I2C annotation using the timing of the observed bus event.
fn note(
    start: u64,
    end: u64,
    class: &str,
    text: impl Into<String>,
    fields: BTreeMap<String, String>,
) -> Annotation {
    Annotation::new(start, end, class, text, fields)
}

/// Packed SCL/SDA for a 24xx byte write of 0x5A at 0x10, then a random read.
#[cfg(test)]
pub(crate) fn fixture_eeprom_bits() -> (Vec<u8>, Vec<u8>, u64) {
    /// Adds a stable bus interval to the independently generated I2C test fixture.
    fn push_level(scl: &mut Vec<bool>, sda: &mut Vec<bool>, n: usize, sda_level: bool, scl_level: bool) {
        for _ in 0..n {
            scl.push(scl_level);
            sda.push(sda_level);
        }
    }
    /// Adds one clocked I2C bit to the test fixture.
    fn push_bit(scl: &mut Vec<bool>, sda: &mut Vec<bool>, bit: bool) {
        push_level(scl, sda, 8, bit, false);
        push_level(scl, sda, 8, bit, true);
    }
    /// Adds a byte and acknowledgment to the test fixture.
    fn push_byte(scl: &mut Vec<bool>, sda: &mut Vec<bool>, byte: u8, ack: bool) {
        for shift in (0..8).rev() {
            push_bit(scl, sda, (byte >> shift) & 1 == 1);
        }
        push_bit(scl, sda, !ack);
    }
    /// Converts a test bus line into the packed channel format used by decoders.
    fn pack(bits: &[bool]) -> Vec<u8> {
        let mut out = vec![0u8; bits.len().div_ceil(8)];
        for (index, bit) in bits.iter().enumerate() {
            if *bit {
                out[index / 8] |= 1 << (index % 8);
            }
        }
        out
    }
    let mut scl = Vec::new();
    let mut sda = Vec::new();
    push_level(&mut scl, &mut sda, 16, true, true);
    push_level(&mut scl, &mut sda, 16, false, true);
    push_byte(&mut scl, &mut sda, 0xA0, true);
    push_byte(&mut scl, &mut sda, 0x10, true);
    push_byte(&mut scl, &mut sda, 0x5A, true);
    push_level(&mut scl, &mut sda, 8, false, false);
    push_level(&mut scl, &mut sda, 8, false, true);
    push_level(&mut scl, &mut sda, 16, true, true);
    push_level(&mut scl, &mut sda, 16, false, true);
    push_byte(&mut scl, &mut sda, 0xA0, true);
    push_byte(&mut scl, &mut sda, 0x10, true);
    // Repeated start: SDA rises while SCL is low, then falls while SCL is high.
    push_level(&mut scl, &mut sda, 8, false, false);
    push_level(&mut scl, &mut sda, 8, true, false);
    push_level(&mut scl, &mut sda, 8, true, true);
    push_level(&mut scl, &mut sda, 8, false, true);
    push_byte(&mut scl, &mut sda, 0xA1, true);
    push_byte(&mut scl, &mut sda, 0x5A, false);
    push_level(&mut scl, &mut sda, 8, false, false);
    push_level(&mut scl, &mut sda, 8, false, true);
    push_level(&mut scl, &mut sda, 16, true, true);
    let len = scl.len() as u64;
    (pack(&scl), pack(&sda), len)
}

#[cfg(test)]
mod tests {
    //! Checks I2C event decoding and filtering using an independently generated bus exchange.

    use std::sync::atomic::AtomicBool;

    use super::*;
    use crate::{run, DecodeRequest};

    /// Checks decoded bus events against an independently generated EEPROM exchange.
    #[test]
    fn i2c_golden_annotations_are_a_write_then_a_read() {
        let (scl, sda, len) = fixture_eeprom_bits();
        let channels = [("scl", scl.as_slice()), ("sda", sda.as_slice())];
        let output = run(
            &DecodeRequest {
                protocol: "i2c",
                channels: &channels,
                options: &[],
                region: 0..len,
                sample_len: len, sample_rate_hz: None,
                lower: &[], lower_packets: &[],
            },
            &AtomicBool::new(false),
        )
        .unwrap();
        assert!(!output.cancelled);
        let addresses: Vec<_> = output
            .annotations
            .iter()
            .filter(|row| row.class == "address")
            .map(|row| {
                (
                    row.fields.get("address").map(String::as_str),
                    row.fields.get("read").map(String::as_str),
                    row.fields.get("raw").map(String::as_str),
                )
            })
            .collect();
        assert_eq!(
            addresses,
            vec![
                (Some("50"), Some("false"), Some("A0")),
                (Some("50"), Some("false"), Some("A0")),
                (Some("50"), Some("true"), Some("A1")),
            ]
        );
        let data: Vec<_> = output
            .annotations
            .iter()
            .filter(|row| row.class == "data")
            .map(|row| row.fields.get("data").map(String::as_str))
            .collect();
        assert_eq!(data, vec![Some("10"), Some("5A"), Some("10"), Some("5A")]);
        assert!(output.annotations.iter().any(|row| row.class == "start"));
        assert!(output.annotations.iter().any(|row| row.class == "stop"));
        assert!(output.annotations.iter().any(|row| row.class == "ack"));
        assert!(output.annotations.iter().any(|row| row.class == "nack"));
    }

    /// Checks that the address filter retains matching exchanges and suppresses others.
    #[test]
    fn i2c_address_option_keeps_only_that_address() {
        let (scl, sda, len) = fixture_eeprom_bits();
        let channels = [("scl", scl.as_slice()), ("sda", sda.as_slice())];
        let kept = run(
            &DecodeRequest {
                protocol: "i2c",
                channels: &channels,
                options: &[("address".into(), "50".into())],
                region: 0..len,
                sample_len: len, sample_rate_hz: None,
                lower: &[], lower_packets: &[],
            },
            &AtomicBool::new(false),
        )
        .unwrap();
        assert!(kept.annotations.iter().any(|row| row.class == "address"));
        let dropped = run(
            &DecodeRequest {
                protocol: "i2c",
                channels: &channels,
                options: &[("address".into(), "51".into())],
                region: 0..len,
                sample_len: len, sample_rate_hz: None,
                lower: &[], lower_packets: &[],
            },
            &AtomicBool::new(false),
        )
        .unwrap();
        assert!(dropped.annotations.is_empty());
    }
}
