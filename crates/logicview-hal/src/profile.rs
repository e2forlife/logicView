//! Profile numbers confirmed against the connected pods.
//!
//! The high-speed DSLogic Plus is `0x0020`. The high-speed DSLogic U3Pro32
//! on this machine is `0x002C`. Bitstream files stay outside the repo.

use crate::HalError;

pub const VENDOR_ID: u16 = 0x2A0E;
pub const PLUS_PID: u16 = 0x0020;
pub const DEVICE_ID: &str = "usb:2a0e:0020";
pub const BITSTREAM_NAME: &str = "DSLogicPlus.bin";

pub const U3PRO32_PID: u16 = 0x002C;
pub const U3_DEVICE_ID: &str = "usb:2a0e:002c";
pub const U3_BITSTREAM_NAME: &str = "DSLogicU3Pro32.bin";

/// HDL version byte read from a Plus after the FPGA was configured.
pub const HDL_VERSION: u8 = 0x0E;

/// Register-window byte after the U3Pro32 bitstream loads. A capture can
/// leave this byte at 0, and open accepts either value.
pub const U3_HDL_VERSION: u8 = 0x0E;

/// Later USB 3 / "3DN2" divider stage. The arm record stores the post-divider.
pub const U3_PRE_DIVIDER: u64 = 5;

/// Bytes of high-speed bulk data that follow the logic header before samples.
/// Super-speed was not measured.
pub const U3_HS_SAMPLE_LEADER: u64 = 512;

/// 256 Mibit of sample memory.
pub const MEMORY_BITS: u64 = 256 * 1024 * 1024;

/// Hardware clock the divider divides, for every buffer mode on this profile.
pub const HW_CLOCK_HZ: u64 = 100_000_000;

pub const HALF_RATE_HZ: u64 = 200_000_000;
pub const QUARTER_RATE_HZ: u64 = 400_000_000;

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

/// U3Pro32 ceilings. Buffer matches the datasheet: 1 GHz through 8 channels,
/// 500 MHz through 16, and 250 MHz through 32. Stream is the high-speed link
/// measured on this pod: 100 MHz through 3 channels, 50 through 6, 25 through
/// 12, 20 through 16, and 10 MHz at 32. Datasheet super-speed stream rates
/// stay off this table; that link was not measured.
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
    RateLimit {
        max_channels: 32,
        max_hz: 10_000_000,
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
        return Err(HalError::Message(
            "sample rate must be greater than zero".into(),
        ));
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

/// Buffer clock for one channel count on the U3Pro32.
///
/// This is the buffer row of [`rate_limits`]: eight or fewer channels run to
/// 1 GHz, sixteen to 500 MHz, and thirty-two to 250 MHz. The arm divider is
/// `ceil(that max / rate)` split by [`U3_PRE_DIVIDER`].
pub fn u3_channel_max_hz(channels: u32) -> u64 {
    max_sample_hz(rate_limits(U3PRO32_PID, false), channels)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct U3Clock {
    pub hw_max_hz: u64,
    pub pre_divider: u64,
}

/// Arm clock for one U3Pro32 capture. The accepted rate is the matching row
/// of [`rate_limits`]. Super-speed stream rates were not measured on this pod.
pub fn plan_u3_clock(rate_hz: u64, enabled: u32, stream: bool) -> Result<U3Clock, HalError> {
    if rate_hz == 0 {
        return Err(HalError::Message(
            "sample rate must be greater than zero".into(),
        ));
    }
    let channels = enabled.count_ones();
    if channels == 0 || channels > 32 {
        return Err(HalError::Message(
            "this pod enables between 1 and 32 channels".into(),
        ));
    }
    let hw_max_hz = u3_channel_max_hz(channels);
    let limit = max_sample_hz(rate_limits(U3PRO32_PID, stream), channels);
    if rate_hz > limit {
        return Err(HalError::Message(if stream {
            format!("{channels} stream channels top out at {limit} Hz on this high-speed pod")
        } else {
            format!("{channels} buffer channels cannot run at {rate_hz} Hz on this pod")
        }));
    }
    Ok(U3Clock {
        hw_max_hz,
        pre_divider: U3_PRE_DIVIDER,
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
            max_sample_hz(rate_limits(U3PRO32_PID, true), 3),
            100_000_000
        );
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, true), 16),
            20_000_000
        );
        assert_eq!(
            max_sample_hz(rate_limits(U3PRO32_PID, true), 32),
            10_000_000
        );
    }

    #[test]
    fn u3_rate_bands_match_plan_u3_clock() {
        for stream in [false, true] {
            for band in rate_limits(U3PRO32_PID, stream) {
                let mask = if band.max_channels >= 32 {
                    u32::MAX
                } else {
                    (1u32 << band.max_channels) - 1
                };
                assert!(
                    plan_u3_clock(band.max_hz, mask, stream).is_ok(),
                    "{} ch at {} stream={stream}",
                    band.max_channels,
                    band.max_hz
                );
                if band.max_channels < 32 {
                    let wider = (1u32 << (band.max_channels + 1)) - 1;
                    assert!(plan_u3_clock(band.max_hz, wider, stream).is_err());
                }
            }
        }
    }

    #[test]
    fn threshold_at_one_point_six_volts() {
        assert_eq!(threshold_code(1.6), 62);
        assert_eq!(threshold_code(0.0), 0);
        assert_eq!(threshold_code(5.0), 193);
    }

    #[test]
    fn u3_one_megahertz_divider_matches_the_buffer_capture() {
        let one = plan_u3_clock(1_000_000, 0x1, false).unwrap();
        assert_eq!(one.hw_max_hz, 1_000_000_000);
        assert_eq!(one.pre_divider, 5);
        assert_eq!(
            logicview_proto::logic_divider(one.hw_max_hz, 1_000_000, one.pre_divider),
            200
        );
        let sixteen = plan_u3_clock(1_000_000, 0xFFFF, false).unwrap();
        assert_eq!(
            logicview_proto::logic_divider(sixteen.hw_max_hz, 1_000_000, 5),
            100
        );
        let wide = plan_u3_clock(1_000_000, u32::MAX, false).unwrap();
        assert_eq!(wide.hw_max_hz, 250_000_000);
        assert_eq!(
            logicview_proto::logic_divider(wide.hw_max_hz, 1_000_000, 5),
            50
        );
        assert!(plan_u3_clock(300_000_000, u32::MAX, false).is_err());
        assert!(plan_u3_clock(20_000_000, u32::MAX, true).is_err());
        assert!(plan_u3_clock(10_000_000, u32::MAX, true).is_ok());
        assert!(plan_u3_clock(100_000_000, 0x7, true).is_ok());
        assert!(plan_u3_clock(0, 1, false).is_err());
        assert!(plan_u3_clock(1_000_000, 0, false).is_err());
    }
}
