//! Profile numbers confirmed against the connected pods.
//!
//! The high-speed DSLogic Plus is `0x0020`. The high-speed DSLogic U3Pro32
//! on this machine is `0x002C`. Bitstream files stay outside the repo.

use crate::HalError;

/// USB vendor identifier used to discover the current analyzer family.
pub const VENDOR_ID: u16 = 0x2A0E;
/// USB product identifier for the tested Plus backend.
pub const PLUS_PID: u16 = 0x0020;
/// Session identifier used to select the tested Plus backend.
pub const DEVICE_ID: &str = "usb:2a0e:0020";
/// External FPGA image expected by the Plus backend.
pub const BITSTREAM_NAME: &str = "DSLogicPlus.bin";

/// USB product identifier for the tested wider analyzer backend.
pub const U3PRO32_PID: u16 = 0x002C;
/// Session identifier used to select the wider analyzer backend.
pub const U3_DEVICE_ID: &str = "usb:2a0e:002c";
/// External FPGA image expected by the wider analyzer backend.
pub const U3_BITSTREAM_NAME: &str = "DSLogicU3Pro32.bin";

/// HDL version byte read from a Plus after the FPGA was configured.
pub const HDL_VERSION: u8 = 0x0E;

/// Register-window byte after the U3Pro32 bitstream loads. A capture can
/// leave this byte at 0, and open accepts either value.
pub const U3_HDL_VERSION: u8 = 0x0E;

/// Later USB 3 divider stage. The arm word keeps `(pre_divider - 1) << 8` in
/// the high half and `ceil(ceil(hw_clock / rate) / pre_divider)` in the low half.
pub const U3_PRE_DIVIDER: u64 = 5;

/// Clock the U3 divider divides, for buffer and stream. 500 MHz and 1 GHz are
/// this clock with the half and quarter mode bits set.
pub const U3_HW_CLOCK_HZ: u64 = 500_000_000;

/// Requested sampling rate that selects the wider pod's half-rate mode.
pub const U3_HALF_RATE_HZ: u64 = 500_000_000;
/// Requested sampling rate that selects the wider pod's quarter-rate mode.
pub const U3_QUARTER_RATE_HZ: u64 = 1_000_000_000;

/// Bytes of high-speed bulk data that follow the logic header before samples.
/// Super-speed sends the header in the 1024-byte packet and then the samples,
/// so that link has no extra leader.
pub const U3_HS_SAMPLE_LEADER: u64 = 512;

/// 256 Mibit of sample memory.
pub const MEMORY_BITS: u64 = 256 * 1024 * 1024;

/// Hardware clock the divider divides, for every buffer mode on this profile.
pub const HW_CLOCK_HZ: u64 = 100_000_000;

/// Requested sampling rate that selects the Plus half-rate mode.
pub const HALF_RATE_HZ: u64 = 200_000_000;
/// Requested sampling rate that selects the Plus quarter-rate mode.
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

/// U3Pro32 ceilings. Buffer matches the datasheet on both link speeds: 1 GHz
/// through 8 channels, 500 MHz through 16, and 250 MHz through 32. Stream on
/// a high-speed link is 100 MHz through 3 channels, 50 through 6, 25 through
/// 12, 20 through 16, and 10 MHz at 32. A super-speed link uses
/// [`U3PRO32_STREAM_SUPER`]. Both modes divide [`U3_HW_CLOCK_HZ`].
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

/// Super-speed U3Pro32 stream ceilings: 1 GHz through 3 channels, 500 MHz
/// through 6, 250 through 12, 100 through 30, and 50 MHz at 32.
const U3PRO32_STREAM_SUPER: &[RateLimit] = &[
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
///
/// The U3 stream table here is the high-speed link. Super-speed stream uses
/// [`link_rate_limits`].
pub fn rate_limits(product_id: u16, stream: bool) -> &'static [RateLimit] {
    link_rate_limits(product_id, stream, false)
}

/// Rate ceilings for one link. `super_speed` widens U3Pro32 stream only.
/// Buffer ceilings are the same at either speed.
pub fn link_rate_limits(product_id: u16, stream: bool, super_speed: bool) -> &'static [RateLimit] {
    if product_id == U3PRO32_PID {
        if stream && super_speed {
            U3PRO32_STREAM_SUPER
        } else if stream {
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

/// Selects the sampling ceiling for a channel count from the chosen device and link limits.
pub fn max_sample_hz(limits: &[RateLimit], channels: u32) -> u64 {
    let channels = channels.max(1);
    for band in limits {
        if channels <= band.max_channels {
            return band.max_hz;
        }
    }
    limits.last().map(|band| band.max_hz).unwrap_or(HW_CLOCK_HZ)
}

/// Validated Plus sampling divider and special rate-mode selections.
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

/// Datasheet buffer ceiling for one channel count on the U3Pro32.
///
/// Eight or fewer channels run to 1 GHz, sixteen to 500 MHz, and thirty-two
/// to 250 MHz. The arm divider divides [`U3_HW_CLOCK_HZ`] by [`U3_PRE_DIVIDER`]
/// for both buffer and stream. The half bit selects 500 MHz and the quarter
/// bit selects 1 GHz.
pub fn u3_channel_max_hz(channels: u32) -> u64 {
    max_sample_hz(rate_limits(U3PRO32_PID, false), channels)
}

/// Clock parameters needed to build an arm record for the wider analyzer.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct U3Clock {
    pub hw_max_hz: u64,
    pub pre_divider: u64,
    pub half_rate_hz: u64,
    pub quarter_rate_hz: u64,
}

/// Arm clock for one U3Pro32 capture on a high-speed link.
pub fn plan_u3_clock(rate_hz: u64, enabled: u32, stream: bool) -> Result<U3Clock, HalError> {
    plan_u3_link(rate_hz, enabled, stream, false)
}

/// Arm clock for one U3Pro32 capture. Buffer and stream both divide
/// [`U3_HW_CLOCK_HZ`]. `super_speed` selects the wider stream ceilings.
pub fn plan_u3_link(
    rate_hz: u64,
    enabled: u32,
    stream: bool,
    super_speed: bool,
) -> Result<U3Clock, HalError> {
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
    let limit = max_sample_hz(link_rate_limits(U3PRO32_PID, stream, super_speed), channels);
    if rate_hz > limit {
        return Err(HalError::Message(if stream {
            format!("{channels} stream channels top out at {limit} Hz on this pod")
        } else {
            format!("{channels} buffer channels cannot run at {rate_hz} Hz on this pod")
        }));
    }
    Ok(U3Clock {
        hw_max_hz: U3_HW_CLOCK_HZ,
        pre_divider: U3_PRE_DIVIDER,
        half_rate_hz: U3_HALF_RATE_HZ,
        quarter_rate_hz: U3_QUARTER_RATE_HZ,
    })
}

/// Threshold code for the opened DSLogic Plus (`0x0020`).
///
/// That profile has no 2.5 V threshold flag, so the code is
/// `volts / 3.3 * (1.5 / 2.5) * 255`, the same scale as the U3Pro32. 1.6 V is
/// the usual 3.3 V logic threshold.
pub fn threshold_code(volts: f64) -> u8 {
    threshold_from_ratio(volts, 1.5 / 2.5)
}

/// Threshold code for the U3Pro32. The scale is 1.5/2.5 of the 3.3 V reference.
pub fn u3_threshold_code(volts: f64) -> u8 {
    threshold_from_ratio(volts, 1.5 / 2.5)
}

/// Converts a requested input threshold into the bounded hardware code for the profile.
fn threshold_from_ratio(volts: f64, ratio: f64) -> u8 {
    if !volts.is_finite() {
        return 0;
    }
    let code = (volts / 3.3) * ratio * 255.0;
    code.round().clamp(0.0, 255.0) as u8
}

#[cfg(test)]
mod tests {
    //! Checks that sampling plans, advertised limits, and threshold conversion agree.

    use super::*;

    /// Checks supported clock plans and rejects rates that exceed the selected capture mode.
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

    /// Checks that advertised sampling limits agree with Plus capture validation.
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

    /// Checks the channel-count and link-speed tradeoffs advertised to clients.
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
        assert_eq!(
            max_sample_hz(link_rate_limits(U3PRO32_PID, true, true), 3),
            1_000_000_000
        );
        assert_eq!(
            max_sample_hz(link_rate_limits(U3PRO32_PID, true, true), 6),
            500_000_000
        );
        assert_eq!(
            max_sample_hz(link_rate_limits(U3PRO32_PID, true, true), 12),
            250_000_000
        );
        assert_eq!(
            max_sample_hz(link_rate_limits(U3PRO32_PID, true, true), 30),
            100_000_000
        );
        assert_eq!(
            max_sample_hz(link_rate_limits(U3PRO32_PID, true, true), 32),
            50_000_000
        );
        assert!(plan_u3_link(50_000_000, u32::MAX, true, true).is_ok());
        assert!(plan_u3_clock(50_000_000, u32::MAX, true).is_err());
    }

    /// Checks that advertised sampling limits agree with wider-pod capture validation.
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

    /// Preserves the expected logic-threshold calibration for the tested profiles.
    #[test]
    fn threshold_at_one_point_six_volts() {
        assert_eq!(threshold_code(1.6), 74);
        assert_eq!(threshold_code(0.0), 0);
        assert_eq!(threshold_code(5.0), 232);
        assert_eq!(u3_threshold_code(1.6), 74);
        assert_eq!(u3_threshold_code(0.0), 0);
    }

    /// Checks that buffer and stream planning use the same staged hardware clock.
    #[test]
    fn u3_buffer_and_stream_share_the_five_hundred_megahertz_clock() {
        let one = plan_u3_clock(1_000_000, 0x1, false).unwrap();
        assert_eq!(one.hw_max_hz, U3_HW_CLOCK_HZ);
        assert_eq!(one.pre_divider, U3_PRE_DIVIDER);
        assert_eq!(one.half_rate_hz, U3_HALF_RATE_HZ);
        assert_eq!(one.quarter_rate_hz, U3_QUARTER_RATE_HZ);
        let word = logicview_proto::logic_divider(one.hw_max_hz, 1_000_000, one.pre_divider);
        assert_eq!(word & 0xffff, 100);
        assert_eq!(word >> 16, 0x0400);
        let stream = plan_u3_clock(1_000_000, u32::MAX, true).unwrap();
        assert_eq!(stream, one);
        assert_eq!(
            logicview_proto::logic_divider(stream.hw_max_hz, 10_000_000, stream.pre_divider)
                & 0xffff,
            10
        );
        let half = plan_u3_clock(U3_HALF_RATE_HZ, 0xFFFF, false).unwrap();
        assert_eq!(
            logicview_proto::logic_divider(half.hw_max_hz, U3_HALF_RATE_HZ, half.pre_divider),
            1
        );
        let quarter = plan_u3_clock(U3_QUARTER_RATE_HZ, 0xFF, false).unwrap();
        assert_eq!(
            logicview_proto::logic_divider(
                quarter.hw_max_hz,
                U3_QUARTER_RATE_HZ,
                quarter.pre_divider
            ),
            1
        );
        assert!(plan_u3_clock(300_000_000, u32::MAX, false).is_err());
        assert!(plan_u3_clock(20_000_000, u32::MAX, true).is_err());
        assert!(plan_u3_clock(10_000_000, u32::MAX, true).is_ok());
        assert!(plan_u3_clock(100_000_000, 0x7, true).is_ok());
        assert!(plan_u3_clock(0, 1, false).is_err());
        assert!(plan_u3_clock(1_000_000, 0, false).is_err());
    }
}
