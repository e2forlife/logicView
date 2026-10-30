//! Protocol decoders for logic captures.
//!
//! I2C follows the NXP UM10204 start/stop/ACK rules and 7-bit addressing.
//! SPI follows the Motorola mode table (CPOL/CPHA) with an active chip select.
//! The 24xx-style stack interprets I2C bytes the way a small EEPROM random
//! read does: a word address, then a read. UART is 8N1, idle-high, LSB first.
//! Nothing here is copied from another project's decoder scripts.
//!
//! # Adding a decoder
//!
//! Implement [`Decoder`] with state that survives contiguous [`SampleSlice`]
//! calls, then register its constructor in [`create`] and its description in
//! [`catalog`]. Emit [`Annotation`] values with absolute capture sample ranges
//! and structured fields that searches and higher protocol layers can use.
//! A stacked decoder consumes lower-level annotations through
//! [`Decoder::feed_lower`] instead of reading signal lines.
//!
//! [`run`] configures a fresh decoder, processes bounded slices, and checks
//! cancellation between slices. The engine binds protocol input names to the
//! session's channel streams and retains the resulting annotations.

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

/// A decoded event shown on the waveform and in searchable protocol tables.
///
/// Sample ranges use an exclusive end. Fields carry structured values used by
/// stacked decoders, searches, and exports.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct Annotation {
    /// First sample covered by the decoded event.
    pub start_sample: u64,
    /// Exclusive end of the event in absolute capture samples.
    pub end_sample: u64,
    /// Protocol-specific event category used for filtering and display.
    pub class: String,
    /// Readable description shown in tables and waveform overlays.
    pub text: String,
    /// Structured protocol values used by stacked decoders, searches, and exports.
    pub fields: BTreeMap<String, String>,
}

impl Annotation {
    /// Creates a decoded event with capture-relative timing and protocol-specific searchable
    /// fields.
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
    /// Absolute capture position where this decoding call begins.
    pub start: u64,
    /// Number of samples the decoder should consume in this call.
    pub len: u64,
    channels: &'a [(&'a str, &'a [u8])],
}

impl<'a> SampleSlice<'a> {
    /// Selects a decoding range while borrowing full packed channel streams.
    ///
    /// Channel buffers are indexed by absolute capture position, not relative to
    /// `start`; callers must provide buffers covering the requested range.
    pub fn new(start: u64, len: u64, channels: &'a [(&'a str, &'a [u8])]) -> Self {
        Self {
            start,
            len,
            channels,
        }
    }

    /// Reads a named decoder input at an absolute capture position; missing inputs read low.
    pub fn bit(&self, name: &str, index: u64) -> bool {
        let Some((_, bytes)) = self.channels.iter().find(|(n, _)| *n == name) else {
            return false;
        };
        logicview_analysis::bit_at(bytes, index)
    }

    /// Returns the exclusive end of this decoding slice in capture sample coordinates.
    pub fn end(&self) -> u64 {
        self.start.saturating_add(self.len)
    }
}

/// Common interface for interpreting captured logic or annotations from a lower protocol layer.
pub trait Decoder: Send {
    /// Returns the stable protocol identifier used in commands and saved decoder settings.
    fn id(&self) -> &'static str;
    /// Returns the protocol name shown in the analyzer interface.
    fn name(&self) -> &'static str;
    /// Lists the input names callers must map to captured logic channels.
    fn channels(&self) -> &'static [&'static str];
    /// Identifies the lower-level decoder whose annotations this decoder consumes, if any.
    fn stack_on(&self) -> Option<&'static str> {
        None
    }
    /// Clears interpretation state before decoding another capture while retaining configured
    /// options.
    fn reset(&mut self);
    /// Consumes the next contiguous sample slice and emits completed protocol annotations.
    ///
    /// Implementations retain partial frames between calls; slice boundaries must
    /// not be treated as protocol boundaries.
    fn feed(&mut self, slice: &SampleSlice<'_>) -> Vec<Annotation>;
    /// Emits any final annotations after the last input slice.
    fn finish(&mut self) -> Vec<Annotation>;
    /// Interprets lower-level annotations for a stacked decoder; ordinary signal decoders emit
    /// nothing here.
    fn feed_lower(&mut self, _rows: &[Annotation]) -> Vec<Annotation> {
        Vec::new()
    }
    /// Applies a protocol-specific option or reports an unknown or invalid setting.
    fn set_option(&mut self, key: &str, value: &str) -> Result<(), DecodeError>;
}

/// Describes a decoder's channel roles and output classes for discovery by clients.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct DecoderSchema {
    /// Stable identifier accepted by decoder creation and engine commands.
    pub id: &'static str,
    /// Readable analyzer name for selection menus.
    pub name: &'static str,
    /// Input signal roles declared by the decoder.
    pub channels: &'static [&'static str],
    /// Input roles that callers may omit.
    pub optional_channels: &'static [&'static str],
    /// Required lower-level protocol for stacked interpretation, if any.
    pub stack_on: Option<&'static str>,
    /// Event categories the decoder can emit.
    pub classes: &'static [&'static str],
}

/// Describes the available decoders, their inputs, and the annotation classes clients can expect.
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

/// Constructs a decoder with default options, returning `None` for unknown protocol identifiers.
pub fn create(protocol: &str) -> Option<Box<dyn Decoder>> {
    match protocol {
        "uart" => Some(Box::new(UartDecoder::default())),
        "i2c" => Some(Box::new(I2cDecoder::default())),
        "spi" => Some(Box::new(SpiDecoder::default())),
        "eeprom24" => Some(Box::new(EepromDecoder::default())),
        _ => None,
    }
}

/// A decoder or its options could not be selected or interpreted.
#[derive(Debug, thiserror::Error)]
pub enum DecodeError {
    #[error("unknown decoder {0}")]
    UnknownProtocol(String),
    #[error("unknown option {0}")]
    UnknownOption(String),
    #[error("{0}")]
    Message(String),
}

/// Borrowed inputs, settings, and region for one decoding pass.
#[derive(Clone, Debug)]
pub struct DecodeRequest<'a> {
    /// Registered decoder identifier to instantiate for this pass.
    pub protocol: &'a str,
    /// Named signal roles borrowing full packed capture streams.
    pub channels: &'a [(&'a str, &'a [u8])],
    /// Textual decoder settings applied before feeding data.
    pub options: &'a [(String, String)],
    /// Capture sample range requested for signal decoding.
    pub region: Range<u64>,
    /// Valid capture length used to bound the requested region.
    pub sample_len: u64,
    /// Lower-level annotations supplied when decoding a protocol stack.
    pub lower: &'a [Annotation],
}

/// Annotations completed by a decoding pass, with an indication of cancellation.
#[derive(Clone, Debug)]
pub struct DecodeOutput {
    /// Completed protocol events, including any produced before cancellation.
    pub annotations: Vec<Annotation>,
    /// Whether processing stopped because the caller requested cancellation.
    pub cancelled: bool,
}

/// Run one decoder over `region`, checking `cancel` between slices.
pub fn run(request: &DecodeRequest<'_>, cancel: &AtomicBool) -> Result<DecodeOutput, DecodeError> {
    runtime::run(request, cancel)
}
