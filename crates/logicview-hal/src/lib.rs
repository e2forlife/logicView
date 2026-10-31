//! USB capture for DreamSourceLab logic pods.
//!
//! Scan lists every vendor `0x2A0E` device. This build opens the high-speed
//! DSLogic Plus (`0x0020`) and the DSLogic U3Pro32 (`0x002C`), including its
//! high-speed and SuperSpeed capture paths.
//! Firmware and FPGA bitstreams stay on disk outside the repo.
//! `LOGICVIEW_FIRMWARE_DIR`, a DSView `res` folder, or
//! `%LOCALAPPDATA%\Temp\lv-fw` can supply `DSLogicPlus.bin` or
//! `DSLogicU3Pro32.bin`.
//!
//! # Responsibilities
//!
//! Device discovery and FPGA setup live in `device`; model identities and rate
//! limits live in `catalog` and `profile`. [`run_capture`] owns blocking USB
//! acquisition and emits whole sample atoms through [`CaptureEvent`]. The
//! engine runs it on a worker thread and applies events to capture stores.
//!
//! Descriptive profiles do not imply hardware support. Preserve the tested-model
//! checks and distinguish observed behavior from assumptions when extending a
//! backend. Hardware tests are ignored by default and require a compatible pod.

mod capture;
mod catalog;
mod device;
mod lock;
mod profile;

pub use capture::{run_capture, CaptureEvent, CaptureJob, CaptureReport, OnStop};
pub use lock::{acquire_test_pod_lock, PodGuard};
pub use catalog::{logic_profile, logic_profiles, LogicProfile};
pub use device::{list_plus, list_pods, matches_plus, supported_product, Pod};
pub use profile::{
    link_rate_limits, max_sample_hz, plan_clock, plan_u3_clock, plan_u3_link, rate_limits,
    threshold_code, u3_channel_max_hz,
    u3_threshold_code, ClockPlan, RateLimit, U3Clock, BITSTREAM_NAME, DEVICE_ID, HALF_RATE_HZ,
    HDL_VERSION, HW_CLOCK_HZ, MEMORY_BITS, PLUS_PID, QUARTER_RATE_HZ, U3PRO32_PID,
    U3_BITSTREAM_NAME, U3_DEVICE_ID, U3_HALF_RATE_HZ, U3_HDL_VERSION, U3_HS_SAMPLE_LEADER,
    U3_HW_CLOCK_HZ, U3_PRE_DIVIDER, U3_QUARTER_RATE_HZ, VENDOR_ID,
};

use thiserror::Error;

/// A physical device could not be opened, configured, or read successfully.
#[derive(Debug, Error)]
pub enum HalError {
    #[error("no tested DreamSourceLab logic pod ({DEVICE_ID} or {U3_DEVICE_ID}) is connected")]
    NotFound,
    #[error("USB error: {0}")]
    Usb(String),
    #[error(
        "FPGA bitstream {file} was not found. Set LOGICVIEW_FIRMWARE_DIR to the folder that contains it. Looked in: {tried}"
    )]
    FirmwareMissing { file: String, tried: String },
    #[error("HDL version was {found:#04x}, expected {expected:#04x}")]
    HdlMismatch { found: u8, expected: u8 },
    #[error("firmware {major}.{minor} is older than 2.0")]
    FirmwareTooOld { major: u8, minor: u8 },
    #[error("logic header check word was {0:#010x}")]
    BadCheckWord(u32),
    #[error("capture interrupted: {0}")]
    Interrupted(String),
    #[error("{0}")]
    Message(String),
}
