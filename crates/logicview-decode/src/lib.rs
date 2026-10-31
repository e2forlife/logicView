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
mod lua_helpers;
mod lua_host;
mod runtime;
mod script;
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
    /// Longer and shorter forms of `text`, longest first, when a script provides more than one.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub texts: Vec<String>,
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
            texts: Vec::new(),
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

    /// Returns whether a named input is connected.
    pub fn has_channel(&self, name: &str) -> bool {
        self.channels.iter().any(|(channel, _)| *channel == name)
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

/// A required or optional decoder input, with the label and description shown to the user.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct ChannelDesc {
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub desc: String,
}

/// One annotation class. `id` is the value stored on each annotation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct AnnotationClass {
    pub id: String,
    #[serde(default)]
    pub desc: String,
}

/// A display row that groups annotation classes by their index in `annotation_classes`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct AnnotationRowGroup {
    pub id: String,
    pub name: String,
    pub classes: Vec<u32>,
}

/// A decoded lane mapped to a data channel and its annotation classes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct DecoderLane {
    pub id: String,
    pub name: String,
    pub channel: String,
    pub channels: Vec<String>,
    pub classes: Vec<String>,
    #[serde(default)]
    pub value_field: Option<String>,
}

/// A named binary stream a script can emit with `put`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct BinaryFormat {
    pub id: String,
    #[serde(default)]
    pub desc: String,
}

/// Describes a decoder's channel roles, options, and output classes for discovery by clients.
///
/// The fields after `options` carry the registration metadata used by sigrok protocol
/// decoders. Clients that only know `channels`, `classes`, and `options` can ignore them.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct DecoderSchema {
    pub id: String,
    pub name: String,
    pub channels: Vec<String>,
    #[serde(default)]
    pub optional_channels: Vec<String>,
    #[serde(default)]
    pub stack_on: Option<String>,
    #[serde(default)]
    pub classes: Vec<String>,
    #[serde(default)]
    pub options: Vec<DecoderOption>,
    #[serde(default)]
    pub api_version: u32,
    #[serde(default)]
    pub longname: String,
    #[serde(default)]
    pub desc: String,
    #[serde(default)]
    pub license: String,
    #[serde(default)]
    pub inputs: Vec<String>,
    #[serde(default)]
    pub outputs: Vec<String>,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub channel_details: Vec<ChannelDesc>,
    #[serde(default)]
    pub optional_channel_details: Vec<ChannelDesc>,
    #[serde(default)]
    pub annotation_classes: Vec<AnnotationClass>,
    #[serde(default)]
    pub annotation_rows: Vec<AnnotationRowGroup>,
    #[serde(default)]
    pub lanes: Vec<DecoderLane>,
    #[serde(default)]
    pub binary: Vec<BinaryFormat>,
}

/// A script-configurable setting. Values are transported as strings.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, serde::Deserialize)]
pub struct DecoderOption {
    pub id: String,
    pub name: String,
    pub default: String,
    #[serde(default)]
    pub values: Vec<String>,
    /// Longer description. `name` remains the label used by the settings dialog.
    #[serde(default)]
    pub desc: String,
}

/// Lists built-in and external scripted decoders.
pub fn catalog() -> Vec<DecoderSchema> {
    let mut entries = vec![
        schema("uart", "UART", &["rx"], None, &["data", "frame", "error"]),
        schema(
            "i2c",
            "I2C",
            &["scl", "sda"],
            None,
            &["start", "address", "data", "ack", "nack", "stop"],
        ),
        schema(
            "spi",
            "SPI",
            &["sck", "mosi", "miso", "cs"],
            None,
            &["word", "select"],
        ),
        schema(
            "eeprom24",
            "EEPROM 24xx",
            &[],
            Some("i2c"),
            &["write", "read", "address"],
        ),
    ];
    entries[2].lanes = [("mosi", "MOSI"), ("miso", "MISO")]
        .into_iter()
        .map(|(id, name)| DecoderLane {
            id: id.into(),
            name: name.into(),
            channel: id.into(),
            channels: if id == "mosi" {
                vec!["mosi".into(), "sck".into(), "cs".into()]
            } else {
                vec!["sck".into(), "miso".into(), "cs".into()]
            },
            classes: vec!["word".into()],
            value_field: Some(id.into()),
        })
        .collect();
    for entry in script::catalog() {
        if !entries.iter().any(|existing| existing.id == entry.id) {
            entries.push(entry);
        }
    }
    entries
}
fn schema(
    id: &str,
    name: &str,
    channels: &[&str],
    stack: Option<&str>,
    classes: &[&str],
) -> DecoderSchema {
    let channels: Vec<String> = channels.iter().map(|v| (*v).into()).collect();
    let classes: Vec<String> = classes.iter().map(|v| (*v).into()).collect();
    let details = |ids: &[String]| {
        ids.iter()
            .map(|id| ChannelDesc {
                id: id.clone(),
                name: id.clone(),
                desc: String::new(),
            })
            .collect()
    };
    DecoderSchema {
        id: id.into(),
        name: name.into(),
        optional_channels: channels.clone(),
        channel_details: details(&channels),
        optional_channel_details: details(&channels),
        channels,
        stack_on: stack.map(str::to_string),
        inputs: vec![stack.unwrap_or("logic").into()],
        outputs: vec![id.into()],
        annotation_classes: classes
            .iter()
            .map(|id| AnnotationClass {
                id: id.clone(),
                desc: String::new(),
            })
            .collect(),
        classes,
        options: Vec::new(),
        api_version: 1,
        longname: String::new(),
        desc: String::new(),
        license: String::new(),
        tags: Vec::new(),
        annotation_rows: Vec::new(),
        lanes: Vec::new(),
        binary: Vec::new(),
    }
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
    /// Capture sample rate in hertz, or None when unavailable.
    pub sample_rate_hz: Option<u64>,
    /// Lower-level annotations supplied when decoding a protocol stack.
    pub lower: &'a [Annotation],
    /// Structured packets from the immediate parent decoder.
    pub lower_packets: &'a [ProtocolPacket],
}

/// A typed protocol event delivered to another decoder in a stack.
#[derive(Clone, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct ProtocolPacket {
    pub start_sample: u64,
    pub end_sample: u64,
    pub kind: String,
    pub data: serde_json::Value,
}

/// Bytes emitted by a script for a later save or download action.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BinaryPayload {
    pub start_sample: u64,
    pub end_sample: u64,
    pub format: String,
    pub bytes: Vec<u8>,
}

/// A named measurement or property emitted by a script.
#[derive(Clone, Debug, PartialEq)]
pub struct MetaItem {
    pub start_sample: u64,
    pub end_sample: u64,
    pub key: String,
    pub value: serde_json::Value,
}

/// Annotations completed by a decoding pass, with an indication of cancellation.
#[derive(Clone, Debug)]
pub struct DecodeOutput {
    /// Completed protocol events, including any produced before cancellation.
    pub annotations: Vec<Annotation>,
    /// Structured events consumed by a stacked decoder.
    pub packets: Vec<ProtocolPacket>,
    /// Binary streams from a session script. The application does not display these yet.
    pub binary: Vec<BinaryPayload>,
    /// Named metadata from a session script. The application does not display these yet.
    pub meta: Vec<MetaItem>,
    /// Whether processing stopped because the caller requested cancellation.
    pub cancelled: bool,
}

impl DecodeOutput {
    /// A finished pass that did not emit binary or metadata.
    pub fn new(
        annotations: Vec<Annotation>,
        packets: Vec<ProtocolPacket>,
        cancelled: bool,
    ) -> Self {
        Self {
            annotations,
            packets,
            binary: Vec::new(),
            meta: Vec::new(),
            cancelled,
        }
    }
}

/// Run one decoder over `region`, checking `cancel` between slices.
pub fn run(request: &DecodeRequest<'_>, cancel: &AtomicBool) -> Result<DecodeOutput, DecodeError> {
    runtime::run(request, cancel)
}
