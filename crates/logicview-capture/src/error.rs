//! Reports capture configuration, state, and sample-storage failures.

use thiserror::Error;

/// A capture could not be configured, started, or added to the session stores.
#[derive(Debug, Error)]
pub enum CaptureError {
    #[error("sample rate must be greater than zero")]
    BadRate,
    #[error("duration must be greater than zero")]
    BadDuration,
    #[error("capture of {requested} samples exceeds the ceiling of {ceiling}")]
    TooLarge { requested: u64, ceiling: u64 },
    #[error("channel {0} is out of range")]
    BadChannel(usize),
    #[error("capture is already running")]
    Busy,
    #[error("{0}")]
    BadTrigger(String),
    #[error("sample buffer does not match the manifest")]
    BadLength,
    #[error("{0}")]
    Proto(String),
}
