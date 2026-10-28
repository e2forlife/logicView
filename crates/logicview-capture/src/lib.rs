//! Capture session, demo source, and the logic sample store.
//!
//! The demo source emits the same feed a device source will: a header, then
//! atom-packed logic, then analog samples, then end. Tests drive it without
//! waiting for wall-clock time. USB transfers are not implemented.

mod demo;
mod error;
mod session;
mod store;

pub use demo::{
    analog_sample, clock_high, uart_high, DemoSource, Feed, CLOCK_HIGH_AT, CLOCK_PERIOD,
    DEMO_CHANNELS,
};
pub use error::CaptureError;
pub use session::{
    planned_samples, Phase, Session, SessionConfig, StartMode, DEMO_CHUNK_SAMPLES, MAX_SAMPLES,
};
pub use store::{AnalogColumn, AnalogStore, Column, LogicStore};

pub const DEMO_HW_MAX_RATE: u64 = 100_000_000;
