//! USB capture for DreamSourceLab logic pods.
//!
//! Scan lists every vendor `0x2A0E` device. This build opens the high-speed
//! DSLogic Plus, product `0x0020`. Firmware and the FPGA bitstream stay on
//! disk outside the repo. `LOGICVIEW_FIRMWARE_DIR`, a DSView `res` folder, or
//! `%LOCALAPPDATA%\Temp\lv-fw` can supply `DSLogicPlus.bin`.

mod capture;
mod catalog;
mod device;
mod profile;

pub use capture::{run_capture, CaptureEvent, CaptureJob, CaptureReport, OnStop};
pub use catalog::{logic_profile, logic_profiles, LogicProfile};
pub use device::{list_plus, list_pods, matches_plus, Pod};
pub use profile::{
    max_sample_hz, plan_clock, rate_limits, threshold_code, ClockPlan, RateLimit, BITSTREAM_NAME,
    DEVICE_ID, HALF_RATE_HZ, HDL_VERSION, HW_CLOCK_HZ, MEMORY_BITS, PLUS_PID, QUARTER_RATE_HZ,
    U3PRO32_PID, VENDOR_ID,
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
