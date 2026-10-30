/// Where a trigger is allowed to sit inside the record.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DepthMode {
    /// Pre-trigger may use most of the on-device record.
    Buffer,
    /// Pre-trigger is only a short prefix of the streamed record.
    Stream,
}

/// Mode bits, low to high, as described for the arm image.
///
/// The numeric values are the bit positions in that list. They are not copied
/// from another project.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct ModeFlags(pub u16);

impl ModeFlags {
    pub const TRIGGER_ENABLE: u16 = 1 << 0;
    pub const EXTERNAL_CLOCK: u16 = 1 << 1;
    pub const CLOCK_FALLING: u16 = 1 << 2;
    pub const RLE: u16 = 1 << 3;
    pub const OSCILLOSCOPE: u16 = 1 << 4;
    pub const HALF_RATE: u16 = 1 << 5;
    pub const QUARTER_RATE: u16 = 1 << 6;
    pub const ANALOG_OR_LOOP: u16 = 1 << 7;
    pub const ONE_SAMPLE_FILTER: u16 = 1 << 8;
    pub const INSTANT: u16 = 1 << 9;
    pub const SLOW_ACQUISITION: u16 = 1 << 10;
    pub const SERIAL_TRIGGER: u16 = 1 << 11;
    pub const STREAM: u16 = 1 << 12;
    pub const LOOPBACK_TEST: u16 = 1 << 13;
    pub const EXTERNAL_TEST: u16 = 1 << 14;
    pub const INTERNAL_TEST: u16 = 1 << 15;

    pub fn contains(self, bit: u16) -> bool {
        self.0 & bit == bit
    }

    pub fn insert(&mut self, bit: u16) {
        self.0 |= bit;
    }
}

/// Divider word stored in the arm record.
///
/// `total` is `ceil(hw_max_rate / requested)`. The high half is
/// `(min(total, pre_divider) - 1) << 8`, plus any bits of the post-divider
/// above 16. The low half is `ceil(total / pre_divider)`. `pre_divider` is 1
/// on the Plus modes and 5 on the later USB 3 modes. A pre-divider of 1 leaves
/// the high half at 0, so the word is the low half alone.
pub fn logic_divider(hw_max_rate: u64, requested: u64, pre_divider: u64) -> u32 {
    if requested == 0 || pre_divider == 0 || hw_max_rate == 0 {
        return 1;
    }
    let total = hw_max_rate.div_ceil(requested).max(1);
    let pre = pre_divider.max(1);
    let stage = if total >= pre { pre - 1 } else { total - 1 };
    let post = u32::try_from(total.div_ceil(pre).max(1)).unwrap_or(u32::MAX);
    let div_l = post & 0xffff;
    let div_h = (((stage as u32) << 8) + (post >> 16)) & 0xffff;
    div_l | (div_h << 16)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mode_bits_follow_the_low_to_high_list() {
        assert_eq!(ModeFlags::TRIGGER_ENABLE, 1 << 0);
        assert_eq!(ModeFlags::EXTERNAL_CLOCK, 1 << 1);
        assert_eq!(ModeFlags::CLOCK_FALLING, 1 << 2);
        assert_eq!(ModeFlags::RLE, 1 << 3);
        assert_eq!(ModeFlags::OSCILLOSCOPE, 1 << 4);
        assert_eq!(ModeFlags::HALF_RATE, 1 << 5);
        assert_eq!(ModeFlags::QUARTER_RATE, 1 << 6);
        assert_eq!(ModeFlags::ANALOG_OR_LOOP, 1 << 7);
        assert_eq!(ModeFlags::ONE_SAMPLE_FILTER, 1 << 8);
        assert_eq!(ModeFlags::INSTANT, 1 << 9);
        assert_eq!(ModeFlags::SLOW_ACQUISITION, 1 << 10);
        assert_eq!(ModeFlags::SERIAL_TRIGGER, 1 << 11);
        assert_eq!(ModeFlags::STREAM, 1 << 12);
        assert_eq!(ModeFlags::LOOPBACK_TEST, 1 << 13);
        assert_eq!(ModeFlags::EXTERNAL_TEST, 1 << 14);
        assert_eq!(ModeFlags::INTERNAL_TEST, 1 << 15);
    }

    #[test]
    fn divider_ceils_then_applies_the_pre_divider() {
        assert_eq!(logic_divider(100_000_000, 25_000_000, 1), 4);
        assert_eq!(logic_divider(100, 30, 1), 4);
        assert_eq!(logic_divider(100, 0, 1), 1);
        // 500 MHz clock, pre-divider 5, 1 MHz: low half 100, high half (5-1)<<8.
        assert_eq!(
            logic_divider(500_000_000, 1_000_000, 5),
            100 | (0x0400 << 16)
        );
        // The ratio is below the pre-divider, so the high half is (ratio-1)<<8.
        assert_eq!(
            logic_divider(400_000_000, 100_000_000, 5),
            1 | (0x0300 << 16)
        );
    }
}
