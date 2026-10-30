//! Synthetic signals for the demo device.
//!
//! Channel 0 is a square clock, low for 50 samples and high for 50. The first
//! rising edge is sample 50. Channel 1 is a UART-shaped idle-high frame carrying
//! `0x55`. Channels 2 and 3 are an I2C-shaped start plus a byte on SDA/SCL.
//! The analog trace is a 1 kHz sine plus a deterministic dither.

use logicview_proto::{
    encode_logic_header, pack_logic_atoms, parse_logic_header, LogicHeader, LOGIC_CHECK_WORD,
};

use crate::error::CaptureError;
use crate::session::{active_edge_steps, SessionConfig};

pub const DEMO_CHANNELS: usize = 4;
pub const CLOCK_PERIOD: u64 = 100;
pub const CLOCK_HIGH_AT: u64 = 50;

/// Produces deterministic capture blocks for demos and tests without a physical instrument.
#[derive(Clone, Debug)]
pub struct DemoSource {
    total: u64,
    rate: u64,
    chunk: u64,
    produced: u64,
    header_sent: bool,
    finished: bool,
    trigger_enabled: bool,
    instant: bool,
    /// Rising/falling steps are found in the stored samples, so the header
    /// does not invent a position. A level trigger still reports the clock edge.
    edge_sequence: bool,
    waves: Vec<fn(u64) -> bool>,
}

impl DemoSource {
    /// Creates a repeatable synthetic source using the session settings and selected channel
    /// waveforms.
    pub fn new(
        config: &SessionConfig,
        total_samples: u64,
        instant: bool,
        waves: Vec<fn(u64) -> bool>,
    ) -> Self {
        Self {
            total: total_samples,
            rate: config.sample_rate_hz,
            chunk: crate::session::DEMO_CHUNK_SAMPLES,
            produced: 0,
            header_sent: false,
            finished: false,
            trigger_enabled: config.trigger_enabled,
            instant,
            edge_sequence: config.trigger_enabled && !active_edge_steps(config).is_empty(),
            waves,
        }
    }

    /// Produces the next header or sample block without waiting for wall-clock time.
    ///
    /// The session consumes these blocks through the same storage path as a device
    /// capture. Once exhausted, the source continues returning the end marker.
    pub fn poll(&mut self) -> Result<Feed, CaptureError> {
        if self.finished {
            return Ok(Feed::End);
        }
        if !self.header_sent {
            self.header_sent = true;
            let trigger_position = if self.trigger_enabled && !self.instant && !self.edge_sequence {
                CLOCK_HIGH_AT as u32
            } else {
                0
            };
            let header = LogicHeader {
                check_word: LOGIC_CHECK_WORD,
                trigger_position,
                ram_start: 0,
                remaining: 0,
                status: 0,
            };
            let bytes = encode_logic_header(&header);
            let parsed =
                parse_logic_header(&bytes).map_err(|err| CaptureError::Proto(err.to_string()))?;
            return Ok(Feed::Header(parsed));
        }
        if self.produced >= self.total {
            self.finished = true;
            return Ok(Feed::End);
        }
        let mut n = self.chunk.min(self.total - self.produced);
        n -= n % 64;
        if n == 0 {
            self.finished = true;
            return Ok(Feed::End);
        }
        let waves = self.waves.clone();
        let channels: Vec<Vec<u8>> = waves
            .iter()
            .map(|wave| pack_bits(self.produced, n, *wave))
            .collect();
        let atoms =
            pack_logic_atoms(&channels).map_err(|err| CaptureError::Proto(err.to_string()))?;
        let mut analog = Vec::with_capacity(n as usize);
        for offset in 0..n {
            analog.push(analog_sample(self.produced + offset, self.rate));
        }
        let first = self.produced;
        self.produced += n;
        Ok(Feed::Samples {
            atoms,
            analog,
            samples: n,
            first_sample: first,
        })
    }
}

/// One event from a capture source: metadata, a sample block, or completion.
pub enum Feed {
    Header(LogicHeader),
    Samples {
        atoms: Vec<u8>,
        analog: Vec<f32>,
        samples: u64,
        first_sample: u64,
    },
    End,
}

/// Provides the demo clock level used to exercise waveform drawing and measurements.
pub fn clock_high(sample: u64) -> bool {
    sample % CLOCK_PERIOD >= CLOCK_HIGH_AT
}

/// Provides a repeating serial frame for exercising UART decoding without hardware.
pub fn uart_high(sample: u64) -> bool {
    const BIT: u64 = 10;
    const IDLE: u64 = BIT * 2;
    let frame = BIT * 16;
    let s = sample % frame;
    if s < IDLE {
        return true;
    }
    let bit_index = (s - IDLE) / BIT;
    const BYTE: u8 = 0x55;
    match bit_index {
        0 => false,
        1..=8 => ((BYTE >> (bit_index - 1)) & 1) == 1,
        _ => true,
    }
}

/// 7-bit address used by the demo EEPROM transaction.
pub const I2C_ADDR: u8 = 0x50;
/// Word address written, then read back.
pub const I2C_OFFSET: u8 = 0x10;
/// Data byte on the demo EEPROM write and the following random read.
pub const I2C_DATA: u8 = 0x5A;
/// Mode-0 SPI word on the second demo pod. MOSI then MISO.
pub const SPI_MOSI: u8 = 0xA5;
pub const SPI_MISO: u8 = 0x3C;

/// Provides the clock line of the demo EEPROM exchange.
pub fn i2c_scl_high(sample: u64) -> bool {
    let frame = i2c_frame();
    frame[(sample as usize) % frame.len()].1
}

/// Provides the data line of the demo EEPROM exchange.
pub fn i2c_sda_high(sample: u64) -> bool {
    let frame = i2c_frame();
    frame[(sample as usize) % frame.len()].0
}

/// Provides the clock line of the demo SPI pod.
pub fn spi_sck_high(sample: u64) -> bool {
    spi_frame()[(sample as usize) % spi_frame().len()][0]
}

/// Provides the controller output line of the demo SPI pod.
pub fn spi_mosi_high(sample: u64) -> bool {
    spi_frame()[(sample as usize) % spi_frame().len()][1]
}

/// Provides the peripheral output line of the demo SPI pod.
pub fn spi_miso_high(sample: u64) -> bool {
    spi_frame()[(sample as usize) % spi_frame().len()][2]
}

/// Provides the chip-select line that bounds demo SPI transfers.
pub fn spi_cs_high(sample: u64) -> bool {
    spi_frame()[(sample as usize) % spi_frame().len()][3]
}

/// Shares one lazily generated EEPROM waveform across demo channel queries.
fn i2c_frame() -> &'static [(bool, bool)] {
    use std::sync::OnceLock;
    static FRAME: OnceLock<Vec<(bool, bool)>> = OnceLock::new();
    FRAME.get_or_init(build_i2c_frame)
}

/// Shares one lazily generated SPI waveform across demo channel queries.
fn spi_frame() -> &'static [[bool; 4]] {
    use std::sync::OnceLock;
    static FRAME: OnceLock<Vec<[bool; 4]>> = OnceLock::new();
    FRAME.get_or_init(build_spi_frame)
}

/// Byte write of [`I2C_DATA`] at [`I2C_OFFSET`], then a 24xx random read.
///
/// Each bit is eight samples of SCL low followed by eight of SCL high. Data
/// changes while SCL is low and is stable on the rising edge. A start is SDA
/// falling while SCL stays high.
fn build_i2c_frame() -> Vec<(bool, bool)> {
    /// Extends the synthetic I2C waveform with a stable bus state.
    fn push(out: &mut Vec<(bool, bool)>, n: usize, sda: bool, scl: bool) {
        for _ in 0..n {
            out.push((sda, scl));
        }
    }
    /// Appends one complete clocked bit to the synthetic bus exchange.
    fn push_bit(out: &mut Vec<(bool, bool)>, bit: bool) {
        push(out, 8, bit, false);
        push(out, 8, bit, true);
    }
    /// Appends an I2C byte and its acknowledgment to the synthetic exchange.
    fn push_byte(out: &mut Vec<(bool, bool)>, byte: u8, ack: bool) {
        for shift in (0..8).rev() {
            push_bit(out, (byte >> shift) & 1 == 1);
        }
        push_bit(out, !ack);
    }
    let mut out = Vec::new();
    push(&mut out, 16, true, true);
    push(&mut out, 16, false, true);
    push_byte(&mut out, 0xA0, true);
    push_byte(&mut out, I2C_OFFSET, true);
    push_byte(&mut out, I2C_DATA, true);
    push(&mut out, 8, false, false);
    push(&mut out, 8, false, true);
    push(&mut out, 16, true, true);
    push(&mut out, 16, false, true);
    push_byte(&mut out, 0xA0, true);
    push_byte(&mut out, I2C_OFFSET, true);
    push(&mut out, 8, false, false);
    push(&mut out, 8, true, false);
    push(&mut out, 8, true, true);
    push(&mut out, 8, false, true);
    push_byte(&mut out, 0xA1, true);
    push_byte(&mut out, I2C_DATA, false);
    push(&mut out, 8, false, false);
    push(&mut out, 8, false, true);
    push(&mut out, 16, true, true);
    out
}

/// One mode-0 word, chip select active low, MSB first.
fn build_spi_frame() -> Vec<[bool; 4]> {
    /// Appends one complete clocked bit to the synthetic bus exchange.
    fn push_bit(out: &mut Vec<[bool; 4]>, mosi: bool, miso: bool) {
        for _ in 0..4 {
            out.push([false, mosi, miso, false]);
        }
        for _ in 0..4 {
            out.push([true, mosi, miso, false]);
        }
    }
    let mut out = Vec::new();
    for _ in 0..24 {
        out.push([false, false, false, true]);
    }
    for _ in 0..4 {
        out.push([false, false, false, false]);
    }
    for shift in (0..8).rev() {
        push_bit(
            &mut out,
            (SPI_MOSI >> shift) & 1 == 1,
            (SPI_MISO >> shift) & 1 == 1,
        );
    }
    for _ in 0..8 {
        out.push([false, false, false, false]);
    }
    for _ in 0..16 {
        out.push([false, false, false, true]);
    }
    out
}

/// Display metadata and signal generator for one channel on a synthetic device.
#[derive(Clone, Copy)]
pub struct DemoChannel {
    pub name: &'static str,
    pub color: &'static str,
    pub level: fn(u64) -> bool,
}

/// Describes a selectable synthetic device and the channels it contributes to a session.
#[derive(Clone, Copy)]
pub struct DemoPod {
    pub id: &'static str,
    pub name: &'static str,
    pub channels: &'static [DemoChannel],
}

/// Lists the synthetic devices and their channel waveforms for the device drawer.
pub fn demo_pods() -> &'static [DemoPod] {
    const LOGIC: &[DemoChannel] = &[
        DemoChannel {
            name: "CLK",
            color: "#e2b340",
            level: clock_high,
        },
        DemoChannel {
            name: "UART",
            color: "#3dcc8e",
            level: uart_high,
        },
        DemoChannel {
            name: "SDA",
            color: "#5aa2ff",
            level: i2c_sda_high,
        },
        DemoChannel {
            name: "SCL",
            color: "#c58bff",
            level: i2c_scl_high,
        },
    ];
    const SPI: &[DemoChannel] = &[
        DemoChannel {
            name: "SCK",
            color: "#f2d38a",
            level: spi_sck_high,
        },
        DemoChannel {
            name: "MOSI",
            color: "#ff6b8a",
            level: spi_mosi_high,
        },
        DemoChannel {
            name: "MISO",
            color: "#7dcea0",
            level: spi_miso_high,
        },
        DemoChannel {
            name: "CS",
            color: "#f0c14d",
            level: spi_cs_high,
        },
    ];
    const PODS: &[DemoPod] = &[
        DemoPod {
            id: "demo",
            name: "Demo",
            channels: LOGIC,
        },
        DemoPod {
            id: "demo:spi",
            name: "Demo SPI",
            channels: SPI,
        },
    ];
    PODS
}

/// Finds a synthetic device by its stable session identifier.
pub fn demo_pod(id: &str) -> Option<&'static DemoPod> {
    demo_pods().iter().find(|pod| pod.id == id)
}

/// Provides a repeatable analog signal for exercising the analog waveform lane.
pub fn analog_sample(sample: u64, rate: u64) -> f32 {
    let rate = rate.max(1) as f32;
    let t = sample as f32 / rate;
    let sine = (2.0 * std::f32::consts::PI * 1_000.0 * t).sin();
    sine + noise(sample) * 0.05
}

/// Encodes a generated channel waveform into the packed format consumed by capture stores.
fn pack_bits(start: u64, samples: u64, f: fn(u64) -> bool) -> Vec<u8> {
    let nbytes = (samples / 8) as usize;
    let mut out = vec![0u8; nbytes];
    for (i, slot) in out.iter_mut().enumerate() {
        let mut byte = 0u8;
        let base = start + (i as u64) * 8;
        for bit in 0..8 {
            if f(base + bit) {
                byte |= 1 << bit;
            }
        }
        *slot = byte;
    }
    out
}

/// Adds deterministic dither so repeated demo captures remain reproducible.
fn noise(sample: u64) -> f32 {
    let mut x = sample.wrapping_mul(0x9E37_79B9_7F4A_7C15);
    x ^= x >> 30;
    x = x.wrapping_mul(0xBF58_476D_1CE4_E5B9);
    x ^= x >> 27;
    let unit = ((x >> 40) as u32) as f32 / 16_777_215.0;
    unit * 2.0 - 1.0
}

#[cfg(test)]
mod tests {
    //! Checks that synthetic sources produce recognizable and reproducible signals.

    use super::*;
    use logicview_proto::bit_at;

    /// Checks that the demo channels expose distinct, recognizable signals.
    #[test]
    fn clock_edges_and_the_other_patterns_are_not_copies() {
        assert!(!clock_high(49));
        assert!(clock_high(50));
        assert!(!clock_high(100));
        assert!(uart_high(0));
        assert!(!uart_high(20));
        let mut uart_differs = false;
        let mut i2c_start = false;
        for sample in 0..400 {
            if uart_high(sample) != clock_high(sample) {
                uart_differs = true;
            }
            if sample > 0
                && i2c_scl_high(sample)
                && i2c_sda_high(sample - 1)
                && !i2c_sda_high(sample)
            {
                i2c_start = true;
            }
        }
        assert!(uart_differs);
        assert!(i2c_start);
        let a0 = analog_sample(0, 1_000_000);
        let a250 = analog_sample(250, 1_000_000);
        assert!(a0.is_finite() && a250.is_finite());
        assert!((a250 - a0).abs() > 0.01);
    }

    /// Checks that the packed demo clock preserves the expected transition.
    #[test]
    fn packed_clock_bit_50_is_high() {
        let bytes = pack_bits(0, 64, clock_high);
        assert!(!bit_at(&bytes, 49));
        assert!(bit_at(&bytes, 50));
    }
}
