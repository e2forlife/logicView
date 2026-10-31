//! A small 24xx-style read stacked on I2C.
//!
//! The public 24C02 random-read sequence is: write the 7-bit control byte and
//! one word address, repeated start, read one or more data bytes. A write with
//! a word address plus payload bytes is reported as a byte write. This is not
//! a memory simulator; it names the bytes already present on the bus.

use std::collections::BTreeMap;

use super::{Annotation, DecodeError, Decoder, SampleSlice};

/// Interprets the supported 24xx-style EEPROM operations from I2C annotations.
#[derive(Clone, Debug, Default)]
pub struct EepromDecoder;

impl Decoder for EepromDecoder {
    /// Returns the stable identifier used to select this protocol in engine commands.
    fn id(&self) -> &'static str {
        "eeprom24"
    }

    /// Returns the display name for this protocol analyzer.
    fn name(&self) -> &'static str {
        "EEPROM 24xx"
    }

    /// Requires no direct signal inputs because this decoder consumes I2C annotations.
    fn channels(&self) -> &'static [&'static str] {
        &[]
    }

    /// Declares I2C as the lower-level protocol required for EEPROM interpretation.
    fn stack_on(&self) -> Option<&'static str> {
        Some("i2c")
    }

    /// Leaves this stateless adapter ready for another set of I2C annotations.
    fn reset(&mut self) {}

    /// Ignores raw logic slices because EEPROM interpretation operates on decoded I2C transfers.
    fn feed(&mut self, _slice: &SampleSlice<'_>) -> Vec<Annotation> {
        Vec::new()
    }

    /// Produces no extra rows because only complete protocol events are emitted during feeding.
    fn finish(&mut self) -> Vec<Annotation> {
        Vec::new()
    }

    /// Interprets I2C transfers as EEPROM address selection, writes, and reads.
    fn feed_lower(&mut self, rows: &[Annotation]) -> Vec<Annotation> {
        decode_transfers(rows)
    }

    /// Rejects options because the current EEPROM interpreter has no configurable settings.
    fn set_option(&mut self, key: &str, _value: &str) -> Result<(), DecodeError> {
        Err(DecodeError::UnknownOption(key.into()))
    }
}

/// Collects the address, direction, and payload of one observed I2C transfer.
struct Transfer {
    start: u64,
    end: u64,
    address: u8,
    read: bool,
    data: Vec<u8>,
}

/// Groups I2C events into transfers and interprets the EEPROM address pointer and payloads.
///
/// This models the supported small-device transaction pattern rather than
/// reconstructing memory contents or every EEPROM variant.
fn decode_transfers(rows: &[Annotation]) -> Vec<Annotation> {
    let mut transfers = Vec::new();
    let mut current: Option<Transfer> = None;
    for row in rows {
        match row.class.as_str() {
            "start" => {
                if let Some(done) = current.take() {
                    transfers.push(done);
                }
                current = Some(Transfer {
                    start: row.start_sample,
                    end: row.end_sample,
                    address: 0,
                    read: false,
                    data: Vec::new(),
                });
            }
            "address" => {
                if let Some(xfer) = current.as_mut() {
                    if let Some(addr) = hex_field(row, "address") {
                        xfer.address = addr;
                        xfer.read = row.fields.get("read").map(String::as_str) == Some("true");
                        xfer.end = row.end_sample;
                    }
                }
            }
            "data" => {
                if let Some(xfer) = current.as_mut() {
                    if let Some(byte) = hex_field(row, "data") {
                        xfer.data.push(byte);
                        xfer.end = row.end_sample;
                    }
                }
            }
            "stop" => {
                if let Some(mut done) = current.take() {
                    done.end = row.end_sample;
                    transfers.push(done);
                }
            }
            _ => {}
        }
    }
    if let Some(done) = current {
        transfers.push(done);
    }

    let mut out = Vec::new();
    let mut pointer: Option<u8> = None;
    for xfer in transfers {
        if !(0x50..=0x57).contains(&xfer.address) {
            pointer = None;
            continue;
        }
        if !xfer.read {
            if xfer.data.is_empty() {
                continue;
            }
            if xfer.data.len() == 1 {
                pointer = Some(xfer.data[0]);
                out.push(eeprom_row(
                    xfer.start,
                    xfer.end,
                    "address",
                    format!("Set address 0x{:02X}", xfer.data[0]),
                    &[("address", format!("{:02X}", xfer.data[0]))],
                ));
            } else {
                let offset = xfer.data[0];
                let payload = &xfer.data[1..];
                let bytes = payload
                    .iter()
                    .map(|byte| format!("{byte:02X}"))
                    .collect::<Vec<_>>()
                    .join(" ");
                out.push(eeprom_row(
                    xfer.start,
                    xfer.end,
                    "write",
                    format!("Write 0x{offset:02X} = 0x{bytes}"),
                    &[
                        ("address", format!("{offset:02X}")),
                        (
                            "data",
                            payload
                                .iter()
                                .map(|byte| format!("{byte:02X}"))
                                .collect::<Vec<_>>()
                                .join("-"),
                        ),
                    ],
                ));
                pointer = Some(offset.wrapping_add(payload.len() as u8));
            }
        } else {
            let offset = pointer.unwrap_or(0);
            let bytes = xfer
                .data
                .iter()
                .map(|byte| format!("{byte:02X}"))
                .collect::<Vec<_>>()
                .join(" ");
            out.push(eeprom_row(
                xfer.start,
                xfer.end,
                "read",
                format!("Read 0x{offset:02X} = 0x{bytes}"),
                &[
                    ("address", format!("{offset:02X}")),
                    (
                        "data",
                        xfer.data
                            .iter()
                            .map(|byte| format!("{byte:02X}"))
                            .collect::<Vec<_>>()
                            .join("-"),
                    ),
                ],
            ));
            pointer = Some(offset.wrapping_add(xfer.data.len() as u8));
        }
    }
    out
}

/// Creates a higher-level EEPROM event for tables, search, and waveform annotations.
fn eeprom_row(
    start: u64,
    end: u64,
    class: &str,
    text: String,
    pairs: &[(&str, String)],
) -> Annotation {
    let mut fields = BTreeMap::new();
    for (key, value) in pairs {
        fields.insert((*key).to_string(), value.clone());
    }
    Annotation::new(start, end, class, text, fields)
}

/// Reads a byte from a structured field emitted by the I2C decoder.
fn hex_field(row: &Annotation, key: &str) -> Option<u8> {
    let text = row.fields.get(key)?;
    u8::from_str_radix(text, 16).ok()
}

#[cfg(test)]
mod tests {
    //! Checks higher-level EEPROM interpretation against independently generated I2C traffic.

    use std::sync::atomic::AtomicBool;

    use super::*;
    use crate::i2c::fixture_eeprom_bits;
    use crate::{run, DecodeRequest};

    /// Checks that a decoded I2C exchange becomes the expected EEPROM operations.
    #[test]
    fn stack_reports_the_write_and_the_random_read() {
        let (scl, sda, len) = fixture_eeprom_bits();
        let channels = [("scl", scl.as_slice()), ("sda", sda.as_slice())];
        let lower = run(
            &DecodeRequest {
                protocol: "i2c",
                channels: &channels,
                options: &[],
                region: 0..len,
                sample_len: len,
                sample_rate_hz: None,
                lower: &[],
                lower_packets: &[],
            },
            &AtomicBool::new(false),
        )
        .unwrap();
        let mut eeprom = EepromDecoder;
        let rows = eeprom.feed_lower(&lower.annotations);
        let text: Vec<_> = rows.iter().map(|row| row.text.as_str()).collect();
        assert!(text.iter().any(|line| *line == "Write 0x10 = 0x5A"));
        assert!(text.iter().any(|line| *line == "Set address 0x10"));
        assert!(text.iter().any(|line| *line == "Read 0x10 = 0x5A"));
    }
}
