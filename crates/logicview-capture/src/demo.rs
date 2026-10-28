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
use crate::session::SessionConfig;

pub const DEMO_CHANNELS: usize = 4;
pub const CLOCK_PERIOD: u64 = 100;
pub const CLOCK_HIGH_AT: u64 = 50;

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
}

impl DemoSource {
    pub fn new(config: &SessionConfig, total_samples: u64, instant: bool) -> Self {
        Self {
            total: total_samples,
            rate: config.sample_rate_hz,
            chunk: crate::session::DEMO_CHUNK_SAMPLES,
            produced: 0,
            header_sent: false,
            finished: false,
            trigger_enabled: config.trigger_enabled,
            instant,
        }
    }

    pub fn poll(&mut self) -> Result<Feed, CaptureError> {
        if self.finished {
            return Ok(Feed::End);
        }
        if !self.header_sent {
            self.header_sent = true;
            let trigger_position = if self.trigger_enabled && !self.instant {
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
        let channels: Vec<Vec<u8>> = (0..DEMO_CHANNELS)
            .map(|channel| pack_bits(self.produced, n, channel_fn(channel)))
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

pub fn clock_high(sample: u64) -> bool {
    sample % CLOCK_PERIOD >= CLOCK_HIGH_AT
}

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

pub fn i2c_scl_high(sample: u64) -> bool {
    let p = sample % 400;
    if !(40..360).contains(&p) {
        return true;
    }
    let t = p - 40;
    (t % 20) < 10
}

pub fn i2c_sda_high(sample: u64) -> bool {
    let p = sample % 400;
    if p < 20 {
        return true;
    }
    if p < 40 {
        return false;
    }
    if p >= 360 {
        return true;
    }
    let clock_index = (p - 40) / 20;
    if clock_index >= 8 {
        return false;
    }
    const BYTE: u8 = 0xA5;
    ((BYTE >> clock_index) & 1) == 1
}

pub fn analog_sample(sample: u64, rate: u64) -> f32 {
    let rate = rate.max(1) as f32;
    let t = sample as f32 / rate;
    let sine = (2.0 * std::f32::consts::PI * 1_000.0 * t).sin();
    sine + noise(sample) * 0.05
}

fn channel_fn(channel: usize) -> fn(u64) -> bool {
    match channel {
        0 => clock_high,
        1 => uart_high,
        2 => i2c_sda_high,
        _ => i2c_scl_high,
    }
}

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
    use super::*;
    use logicview_proto::bit_at;

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

    #[test]
    fn packed_clock_bit_50_is_high() {
        let bytes = pack_bits(0, 64, clock_high);
        assert!(!bit_at(&bytes, 49));
        assert!(bit_at(&bytes, 50));
    }
}
