//! Plus-only profile numbers confirmed against the connected pod.

use crate::HalError;

pub const VENDOR_ID: u16 = 0x2A0E;
pub const PLUS_PID: u16 = 0x0020;
pub const DEVICE_ID: &str = "usb:2a0e:0020";
pub const BITSTREAM_NAME: &str = "DSLogicPlus.bin";

/// HDL version byte read from this pod after the FPGA was configured.
pub const HDL_VERSION: u8 = 0x0E;

/// 256 Mibit of sample memory.
pub const MEMORY_BITS: u64 = 256 * 1024 * 1024;

/// Hardware clock the divider divides, for every buffer mode on this profile.
pub const HW_CLOCK_HZ: u64 = 100_000_000;

pub const HALF_RATE_HZ: u64 = 200_000_000;
pub const QUARTER_RATE_HZ: u64 = 400_000_000;
pub const U3PRO32_PID: u16 = 0x002C;

/// Highest rate for a channel count. Bands are inclusive upper bounds.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RateLimit {
    pub max_channels: u32,
    pub max_hz: u64,
}

/// Plus buffer ceilings enforced by [`plan_clock`]: 4 channels to 400 MHz,
/// 8 to 200 MHz, 16 to 100 MHz.
const PLUS_BUFFER: &[RateLimit] = &[
    RateLimit {
        max_channels: 4,
        max_hz: QUARTER_RATE_HZ,
    },
    RateLimit {
        max_channels: 8,
        max_hz: HALF_RATE_HZ,
    },
    RateLimit {
        max_channels: 16,
        max_hz: HW_CLOCK_HZ,
    },
];

/// Plus stream ceilings enforced by [`plan_clock`].
const PLUS_STREAM: &[RateLimit] = &[
    RateLimit {
        max_channels: 3,
        max_hz: 100_000_000,
    },
    RateLimit {
        max_channels: 6,
        max_hz: 50_000_000,
    },
    RateLimit {
        max_channels: 12,
        max_hz: 25_000_000,
    },
    RateLimit {
        max_channels: 16,
        max_hz: 20_000_000,
    },
];

/// U3Pro32 ceilings from its datasheet. A count at or under the band uses
/// that rate: buffer 1 GHz to 8 channels, 500 MHz to 16, 250 MHz to 32.
/// Stream is 1 GHz to 3, 500 MHz to 6, 250 MHz to 12, 100 MHz to 30, 50 MHz
/// at 32.
const U3PRO32_BUFFER: &[RateLimit] = &[
    RateLimit {
        max_channels: 8,
        max_hz: 1_000_000_000,
    },
    RateLimit {
        max_channels: 16,
        max_hz: 500_000_000,
    },
    RateLimit {
        max_channels: 32,
        max_hz: 250_000_000,
    },
];

const U3PRO32_STREAM: &[RateLimit] = &[
    RateLimit {
        max_channels: 3,
        max_hz: 1_000_000_000,
    },
    RateLimit {
        max_channels: 6,
        max_hz: 500_000_000,
    },
    RateLimit {
        max_channels: 12,
        max_hz: 250_000_000,
    },
    RateLimit {
        max_channels: 30,
        max_hz: 100_000_000,
    },
    RateLimit {
        max_channels: 32,
        max_hz: 50_000_000,
    },
];

/// Plus limits for every product except the 32-channel U3Pro32.
pub fn rate_limits(product_id: u16, stream: bool) -> &'static [RateLimit] {
    if product_id == U3PRO32_PID {
        if stream {
            U3PRO32_STREAM
        } else {
            U3PRO32_BUFFER
        }
    } else if stream {
        PLUS_STREAM
    } else {
        PLUS_BUFFER
    }
}

pub fn max_sample_hz(limits: &[RateLimit], channels: u32) -> u64 {
    let channels = channels.max(1);
    for band in limits {
        if channels <= band.max_channels {
            return band.max_hz;
        }
    }
    limits.last().map(|band| band.max_hz).unwrap_or(HW_CLOCK_HZ)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ClockPlan {
    pub divider: u32,
    pub half: bool,
    pub quarter: bool,
}

/// Divider and rate-mode bits for one Plus capture.
///
/// Buffer: 16 channels to 100 MHz, 8 to 200 MHz, 4 to 400 MHz. Stream: 16
/// channels to 20 MHz, 12 to 25, 6 to 50, 3 to 100. The divider is
/// `ceil(100 MHz / rate)` and is never below 1. The half and quarter bits are
/// set only when the requested rate is exactly 200 or 400 MHz.
pub fn plan_clock(rate_hz: u64, enabled: u32, stream: bool) -> Result<ClockPlan, HalError> {
    if rate_hz == 0 {
        return Err(HalError::Message("sample rate must be greater than zero".into()));
    }
    let channels = enabled.count_ones();
    if channels == 0 || channels > 16 {
        return Err(HalError::Message(
            "this pod enables between 1 and 16 channels".into(),
        ));
    }
    if stream {
        let limit = if channels <= 3 {
            100_000_000
        } else if channels <= 6 {
            50_000_000
        } else if channels <= 12 {
            25_000_000
        } else {
            20_000_000
        };
        if rate_hz > limit {
            return Err(HalError::Message(format!(
                "{channels} stream channels top out at {limit} Hz on this pod"
            )));
        }
    } else if rate_hz > QUARTER_RATE_HZ
        || (rate_hz > HALF_RATE_HZ && channels > 4)
        || (rate_hz > HW_CLOCK_HZ && channels > 8)
    {
        return Err(HalError::Message(format!(
            "{channels} buffer channels cannot run at {rate_hz} Hz on this pod"
        )));
    }
    let half = !stream && rate_hz == HALF_RATE_HZ;
    let quarter = !stream && rate_hz == QUARTER_RATE_HZ;
    let divider = HW_CLOCK_HZ.div_ceil(rate_hz).max(1) as u32;
    Ok(ClockPlan {
        divider,
        half,
        quarter,
    })
}

/// Threshold code for the 0–5 V range on this Xilinx-era Plus.
///
/// `volts / 3.3 * 0.5 * 255`, rounded and clamped. 1.6 V is the usual 3.3 V
/// logic threshold.
pub fn threshold_code(volts: f64) -> u8 {
    if !volts.is_finite() {
        return 0;
    }
    let code = (volts / 3.3) * 0.5 * 255.0;
    code.round().clamp(0.0, 255.0) as u8
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buffer_and_stream_dividers() {
        let one_mhz = plan_clock(1_000_000, 0xFFFF, false).unwrap();
        assert_eq!(one_mhz.divider, 100);
        assert!(!one_mhz.half && !one_mhz.quarter);

        let half = plan_clock(HALF_RATE_HZ, 0x00FF, false).unwrap();
        assert_eq!(half.divider, 1);
        assert!(half.half);

        let quarter = plan_clock(QUARTER_RATE_HZ, 0x000F, false).unwrap();
        assert!(quarter.quarter);

        assert!(plan_clock(HALF_RATE_HZ, 0xFFFF, false).is_err());
        let stream = plan_clock(20_000_000, 0xFFFF, true).unwrap();
        assert_eq!(stream.divider, 5);
        assert!(plan_clock(25_000_000, 0xFFFF, true).is_err());
    }

    #[test]
    fn plus_rate_bands_match_plan_clock() {
        for stream in [false, true] {
            for band in rate_limits(PLUS_PID, stream) {
                let mask = (1u32 << band.max_channels) - 1;
                assert!(
                    plan_clock(band.max_hz, mask, stream).is_ok(),
                    "{} ch at {} stream={stream}",
                    band.max_channels,
                    band.max_hz
                );
                if band.max_channels < 16 {
                    let wider = (1u32 << (band.max_channels + 1)) - 1;
                    assert!(plan_clock(band.max_hz, wider, stream).is_err());
                }
            }
        }
    }

    #[test]
    fn wider_pods_use_a_lower_ceiling() {
        assert_eq!(max_sample_hz(rate_limits(PLUS_PID, false), 4), 400_000_000);
        assert_eq!(max_sample_hz(rate_limits(PLUS_PID, false), 8), 200_000_000);
        assert_eq!(max_sample_hz(rate_limits(PLUS_PID, false), 16), 100_000_000);
        assert_eq!(max_sample_hz(rate_limits(PLUS_PID, true), 3), 100_000_000);
        assert_eq!(max_sample_hz(rate_limits(PLUS_PID, true), 4), 50_000_000);
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, false), 8),
            1_000_000_000
        );
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, false), 9),
            500_000_000
        );
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, false), 32),
            250_000_000
        );
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, true), 32),
            50_000_000
        );
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, true), 3),
            1_000_000_000
        );
    }

    #[test]
    fn threshold_at_one_point_six_volts() {
        assert_eq!(threshold_code(1.6), 62);
        assert_eq!(threshold_code(0.0), 0);
        assert_eq!(threshold_code(5.0), 193);
    }
}
