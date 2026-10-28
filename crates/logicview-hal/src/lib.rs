//! USB capture for the one pod this build supports.
//!
//! High-speed DSLogic Plus, vendor `0x2A0E`, product `0x0020`. Firmware and
//! the FPGA bitstream stay on disk outside the repo. `LOGICVIEW_FIRMWARE_DIR`
//! points at the folder that contains `DSLogicPlus.bin`.

mod capture;
mod catalog;
mod device;
mod profile;

pub use capture::{run_capture, CaptureEvent, CaptureJob, CaptureReport, OnStop};
pub use device::{list_plus, Pod};
pub use catalog::{logic_profile, logic_profiles, LogicProfile};
pub use profile::{
    plan_clock, threshold_code, ClockPlan, BITSTREAM_NAME, DEVICE_ID, HALF_RATE_HZ, HDL_VERSION,
    HW_CLOCK_HZ, MEMORY_BITS, PLUS_PID, QUARTER_RATE_HZ, VENDOR_ID,
};

use thiserror::Error;

#[derive(Debug, Error)]
pub enum HalError {
    #[error("no high-speed DSLogic Plus ({DEVICE_ID}) is connected")]
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
