//! UART, 8 data bits, no parity, one stop bit, idle high, LSB first.
//!
//! `bit_samples` is how many capture samples make one bit. The demo line uses
//! 10. The start bit is sampled at its midpoint, then each following bit.

use std::collections::BTreeMap;

use super::{Annotation, Decoder, DecodeError, SampleSlice};

#[derive(Clone, Debug)]
pub struct UartDecoder {
    bit_samples: u64,
    primed: bool,
    prev: bool,
    frame: Option<Frame>,
}

#[derive(Clone, Debug)]
struct Frame {
    start: u64,
    next_sample: u64,
    bits: u8,
    acc: u8,
}

impl Default for UartDecoder {
    fn default() -> Self {
        Self {
            bit_samples: 10,
            primed: false,
            prev: true,
            frame: None,
        }
    }
}

impl Decoder for UartDecoder {
    fn id(&self) -> &'static str {
        "uart"
    }

    fn name(&self) -> &'static str {
        "UART"
    }

    fn channels(&self) -> &'static [&'static str] {
        &["rx"]
    }

    fn reset(&mut self) {
        let bit_samples = self.bit_samples;
        *self = Self {
            bit_samples,
            ..Self::default()
        };
    }

    fn feed(&mut self, slice: &SampleSlice<'_>) -> Vec<Annotation> {
        let mut out = Vec::new();
        let mut index = slice.start;
        let end = slice.end();
        if !self.primed {
            if slice.len == 0 {
                return out;
            }
            self.prev = slice.bit("rx", index);
            self.primed = true;
            index += 1;
        }
        let bit = self.bit_samples.max(1);
        while index < end {
            let level = slice.bit("rx", index);
            if self.frame.is_none() && self.prev && !level {
                self.frame = Some(Frame {
                    start: index,
                    next_sample: index + bit / 2,
                    bits: 0,
                    acc: 0,
                });
            }
            if let Some(frame) = self.frame.as_mut() {
                if index == frame.next_sample {
                    match frame.bits {
                        0 => {
                            if level {
                                out.push(Annotation::new(
                                    frame.start,
                                    index + 1,
                                    "error",
                                    "Framing error",
                                    BTreeMap::new(),
                                ));
                                self.frame = None;
                            } else {
                                frame.bits = 1;
                                frame.next_sample = frame.start + bit + bit / 2;
                            }
                        }
                        1..=8 => {
                            if level {
                                frame.acc |= 1 << (frame.bits - 1);
                            }
                            frame.bits += 1;
                            frame.next_sample += bit;
                        }
                        _ => {
                            let data = frame.acc;
                            let start = frame.start;
                            if !level {
                                out.push(Annotation::new(
                                    start,
                                    index + 1,
                                    "error",
                                    "Missing stop bit",
                                    BTreeMap::new(),
                                ));
                            } else {
                                let mut fields = BTreeMap::new();
                                fields.insert("data".into(), format!("{data:02X}"));
                                let text = if (0x20..0x7F).contains(&data) {
                                    format!("0x{data:02X} '{}'", data as char)
                                } else {
                                    format!("0x{data:02X}")
                                };
                                out.push(Annotation::new(start, index + 1, "data", text, fields));
                            }
                            self.frame = None;
                        }
                    }
                }
            }
            self.prev = level;
            index += 1;
        }
        out
    }

    fn finish(&mut self) -> Vec<Annotation> {
        Vec::new()
    }

    fn set_option(&mut self, key: &str, value: &str) -> Result<(), DecodeError> {
        if key != "bit_samples" {
            return Err(DecodeError::UnknownOption(key.into()));
        }
        let bits: u64 = value
            .parse()
            .map_err(|_| DecodeError::Message("bit_samples must be a positive integer".into()))?;
        if bits == 0 || bits > 10_000 {
            return Err(DecodeError::Message(
                "bit_samples must be between 1 and 10000".into(),
            ));
        }
        self.bit_samples = bits;
        Ok(())
    }
}
