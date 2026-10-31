//! Capture session, demo source, and the logic sample store.
//!
//! The demo source emits the same feed a device source will: a header, then
//! atom-packed logic, then analog samples, then end. Tests drive it without
//! waiting for wall-clock time. Hardware USB transfers live in `logicview-hal`;
//! the engine feeds their results into the session and stores defined here.
//!
//! # Data flow
//!
//! [`SessionConfig`] is validated and converted into arm bytes by [`Session`].
//! Sources supply metadata and packed sample blocks; the session updates its
//! lifecycle and stores the original values in [`LogicStore`] and [`AnalogStore`].
//! The engine owns scheduling and device selection, so this crate can be tested
//! without a window or connected instrument.
//!
//! The stores also build reduced waveform summaries for drawing. Measurements
//! and protocol decoding must use original samples rather than those summaries.

mod demo;
mod error;
mod session;
mod store;

pub use demo::{
    analog_sample, clock_high, demo_pod, demo_pods, i2c_scl_high, i2c_sda_high, spi_cs_high,
    spi_miso_high, spi_mosi_high, spi_sck_high, uart_high, DemoChannel, DemoPod, DemoSource, Feed,
    CLOCK_HIGH_AT, CLOCK_PERIOD, DEMO_CHANNELS, I2C_ADDR, I2C_DATA, I2C_OFFSET, SPI_MISO, SPI_MOSI,
};
pub use error::CaptureError;
pub use logicview_proto::DepthMode;
pub use session::{
    active_edge_steps, check_trigger, device_arm, planned_samples, HostClock, Phase, RunPolicy,
    Session, SessionConfig, StartMode, TriggerKind, TriggerStep, DEMO_CHUNK_SAMPLES,
    MAX_BUFFER_SAMPLES, MAX_SAMPLES,
    MAX_TRIGGER_STEPS,
};
pub use store::{AnalogColumn, AnalogStore, Column, LogicStore};

/// Reference clock used to build arm settings for the synthetic capture source.
pub const DEMO_HW_MAX_RATE: u64 = 100_000_000;
