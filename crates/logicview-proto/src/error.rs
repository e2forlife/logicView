//! Reports invalid capture records and payload layouts to callers without depending on USB.

use thiserror::Error;

/// A capture record or sample payload could not be encoded or interpreted.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum ProtoError {
    #[error("truncated record")]
    Truncated,
    #[error("bad sync word")]
    BadSync,
    #[error("missing section {0}")]
    MissingSection(u8),
    #[error("bad section length for tag {0}")]
    BadSectionLength(u8),
    #[error("section is too large to encode")]
    SectionTooLarge,
    #[error("logic header check word was {0:#010x}")]
    BadCheckWord(u32),
    #[error("sample buffer length {len} is not a whole atom for {channels} channels")]
    BadAtom { len: usize, channels: usize },
    #[error("no channels")]
    NoChannels,
    #[error("channel streams differ in length")]
    UnevenChannels,
    #[error("value does not fit in the arm field")]
    FieldOverflow,
}
