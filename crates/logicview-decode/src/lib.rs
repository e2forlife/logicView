//! Protocol decoders for logic captures.
//!
//! I2C follows the NXP UM10204 start/stop/ACK rules and 7-bit addressing.
//! SPI follows the Motorola mode table (CPOL/CPHA) with an active chip select.
//! The 24xx-style stack interprets I2C bytes the way a small EEPROM random
//! read does: a word address, then a read. UART is 8N1, idle-high, LSB first.
//! Nothing here is copied from another project's decoder scripts.

mod eeprom;
mod i2c;
mod runtime;
mod spi;
mod uart;

use std::collections::BTreeMap;
use std::ops::Range;
use std::sync::atomic::AtomicBool;

use serde::Serialize;

pub use eeprom::EepromDecoder;
pub use i2c::I2cDecoder;
pub use runtime::{export_csv, export_text, search_annotations};
pub use spi::SpiDecoder;
pub use uart::UartDecoder;

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Annotation {
    pub start_sample: u64,
    pub end_sample: u64,
    pub class: String,
    pub text: String,
    pub fields: BTreeMap<String, String>,
}

impl Annotation {
    pub fn new(
        start_sample: u64,
        end_sample: u64,
        class: impl Into<String>,
        text: impl Into<String>,
        fields: BTreeMap<String, String>,
    ) -> Self {
        Self {
            start_sample,
            end_sample,
            class: class.into(),
            text: text.into(),
            fields,
        }
    }
}

/// One slice of a capture. `start` is the absolute index of the first sample
/// the decoder should read, and `len` is how many samples this call covers.
pub struct SampleSlice<'a> {
    pub start: u64,
    pub len: u64,
    channels: &'a [(&'a str, &'a [u8])],
}

impl<'a> SampleSlice<'a> {
    pub fn new(start: u64, len: u64, channels: &'a [(&'a str, &'a [u8])]) -> Self {
        Self {
            start,
            len,
            channels,
        }
    }

    pub fn bit(&self, name: &str, index: u64) -> bool {
        let Some((_, bytes)) = self.channels.iter().find(|(n, _)| *n == name) else {
            return false;
        };
        logicview_analysis::bit_at(bytes, index)
    }

    pub fn end(&self) -> u64 {
        self.start.saturating_add(self.len)
    }
}

pub trait Decoder: Send {
    fn id(&self) -> &'static str;
    fn name(&self) -> &'static str;
    fn channels(&self) -> &'static [&'static str];
    fn stack_on(&self) -> Option<&'static str> {
        None
    }
    fn reset(&mut self);
    fn feed(&mut self, slice: &SampleSlice<'_>) -> Vec<Annotation>;
    fn finish(&mut self) -> Vec<Annotation>;
    fn feed_lower(&mut self, _rows: &[Annotation]) -> Vec<Annotation> {
        Vec::new()
    }
    fn set_option(&mut self, key: &str, value: &str) -> Result<(), DecodeError>;
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct DecoderSchema {
    pub id: &'static str,
    pub name: &'static str,
    pub channels: &'static [&'static str],
    pub optional_channels: &'static [&'static str],
    pub stack_on: Option<&'static str>,
    pub classes: &'static [&'static str],
}

pub fn catalog() -> Vec<DecoderSchema> {
    vec![
        DecoderSchema {
            id: "uart",
            name: "UART",
            channels: &["rx"],
            optional_channels: &[],
            stack_on: None,
            classes: &["data", "frame", "error"],
        },
        DecoderSchema {
            id: "i2c",
            name: "I2C",
            channels: &["scl", "sda"],
            optional_channels: &[],
            stack_on: None,
            classes: &["start", "address", "data", "ack", "nack", "stop"],
        },
        DecoderSchema {
            id: "spi",
            name: "SPI",
            channels: &["sck", "mosi", "miso", "cs"],
            optional_channels: &[],
            stack_on: None,
            classes: &["word", "select"],
        },
        DecoderSchema {
            id: "eeprom24",
            name: "EEPROM 24xx",
            channels: &[],
            optional_channels: &[],
            stack_on: Some("i2c"),
            classes: &["write", "read", "address"],
        },
    ]
}

pub fn create(protocol: &str) -> Option<Box<dyn Decoder>> {
    match protocol {
        "uart" => Some(Box::new(UartDecoder::default())),
        "i2c" => Some(Box::new(I2cDecoder::default())),
        "spi" => Some(Box::new(SpiDecoder::default())),
        "eeprom24" => Some(Box::new(EepromDecoder::default())),
        _ => None,
    }
}

#[derive(Debug, thiserror::Error)]
pub enum DecodeError {
    #[error("unknown decoder {0}")]
    UnknownProtocol(String),
    #[error("unknown option {0}")]
    UnknownOption(String),
    #[error("{0}")]
    Message(String),
}

#[derive(Clone, Debug)]
pub struct DecodeRequest<'a> {
    pub protocol: &'a str,
    pub channels: &'a [(&'a str, &'a [u8])],
    pub options: &'a [(String, String)],
    pub region: Range<u64>,
    pub sample_len: u64,
    pub lower: &'a [Annotation],
}

#[derive(Clone, Debug)]
pub struct DecodeOutput {
    pub annotations: Vec<Annotation>,
    pub cancelled: bool,
}

/// Run one decoder over `region`, checking `cancel` between slices.
pub fn run(request: &DecodeRequest<'_>, cancel: &AtomicBool) -> Result<DecodeOutput, DecodeError> {
    runtime::run(request, cancel)
}
