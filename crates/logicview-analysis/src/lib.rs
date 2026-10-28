//! Measurements on packed logic samples.
//!
//! Bits are LSB-first: bit 0 of byte 0 is sample 0. Search and pulse math are
//! exact. The capture crate's mipmap is for drawing, not for these answers.

/// One pulse under the cursor, plus the rising-to-rising cycle that contains it
/// when both edges exist.
#[derive(Clone, Debug, PartialEq)]
pub struct PulseMetrics {
    pub sample: u64,
    pub level_high: bool,
    /// Length of the current high or low run, in samples.
    pub pulse_width_samples: u64,
    pub period_samples: Option<u64>,
    pub high_samples: Option<u64>,
    pub width_secs: f64,
    pub period_secs: Option<f64>,
    pub frequency_hz: Option<f64>,
    /// High time divided by the rising-to-rising period.
    pub duty: Option<f64>,
}

pub fn bit_at(bytes: &[u8], index: u64) -> bool {
    let Some(byte) = bytes.get((index / 8) as usize) else {
        return false;
    };
    (byte >> (index % 8)) & 1 == 1
}

/// Smallest sample `i > from` where the level becomes `rising` (true) or low (false).
pub fn find_edge(bytes: &[u8], len: u64, from: u64, rising: bool) -> Option<u64> {
    if len == 0 || from >= len {
        return None;
    }
    let mut prev = bit_at(bytes, from);
    let mut i = from + 1;
    while i < len {
        if i.is_multiple_of(8) && i + 8 <= len {
            let byte = bytes[(i / 8) as usize];
            if (prev && byte == 0xFF) || (!prev && byte == 0x00) {
                i += 8;
                continue;
            }
        }
        let level = bit_at(bytes, i);
        if level != prev && level == rising {
            return Some(i);
        }
        prev = level;
        i += 1;
    }
    None
}

pub fn measure_pulse(bytes: &[u8], len: u64, sample: u64, rate_hz: u64) -> Option<PulseMetrics> {
    if sample >= len || rate_hz == 0 || bytes.is_empty() {
        return None;
    }
    let level = bit_at(bytes, sample);
    let mut start = sample;
    while start > 0 && bit_at(bytes, start - 1) == level {
        start -= 1;
    }
    let mut end = sample + 1;
    while end < len && bit_at(bytes, end) == level {
        end += 1;
    }
    let pulse_width = end - start;

    let mut rise_at = None;
    let mut j = sample;
    loop {
        if j > 0 && !bit_at(bytes, j - 1) && bit_at(bytes, j) {
            rise_at = Some(j);
            break;
        }
        if j == 0 {
            break;
        }
        j -= 1;
    }
    let next_rise = rise_at.and_then(|rise| find_edge(bytes, len, rise, true));
    let (period, high_samples) = if let (Some(rise), Some(next)) = (rise_at, next_rise) {
        let mut high_end = rise + 1;
        while high_end < len && bit_at(bytes, high_end) {
            high_end += 1;
        }
        (Some(next - rise), Some(high_end - rise))
    } else {
        (None, None)
    };

    let width_secs = pulse_width as f64 / rate_hz as f64;
    let period_secs = period.map(|p| p as f64 / rate_hz as f64);
    let frequency_hz = period.and_then(|p| {
        if p == 0 {
            None
        } else {
            Some(rate_hz as f64 / p as f64)
        }
    });
    let duty = match (high_samples, period) {
        (Some(high), Some(period)) if period > 0 => Some(high as f64 / period as f64),
        _ => None,
    };

    Some(PulseMetrics {
        sample,
        level_high: level,
        pulse_width_samples: pulse_width,
        period_samples: period,
        high_samples,
        width_secs,
        period_secs,
        frequency_hz,
        duty,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn clock_bytes(samples: u64) -> Vec<u8> {
        let mut out = vec![0u8; (samples / 8) as usize];
        for sample in 0..samples {
            if sample % 100 >= 50 {
                let byte = (sample / 8) as usize;
                out[byte] |= 1 << (sample % 8);
            }
        }
        out
    }

    #[test]
    fn first_rising_edge_of_the_clock_is_sample_50() {
        let bytes = clock_bytes(1000);
        assert_eq!(find_edge(&bytes, 1000, 0, true), Some(50));
        assert_eq!(find_edge(&bytes, 1000, 50, true), Some(150));
        assert_eq!(find_edge(&bytes, 1000, 49, true), Some(50));
        assert_eq!(find_edge(&bytes, 1000, 0, false), Some(100));
    }

    #[test]
    fn pulse_metrics_on_the_clock() {
        let bytes = clock_bytes(10_000);
        let high = measure_pulse(&bytes, 10_000, 75, 1_000_000).unwrap();
        assert!(high.level_high);
        assert_eq!(high.pulse_width_samples, 50);
        assert_eq!(high.period_samples, Some(100));
        assert_eq!(high.high_samples, Some(50));
        assert_eq!(high.frequency_hz, Some(10_000.0));
        assert_eq!(high.duty, Some(0.5));
        assert_eq!(high.width_secs, 50.0 / 1_000_000.0);
        assert_eq!(high.period_secs, Some(100.0 / 1_000_000.0));

        let low = measure_pulse(&bytes, 10_000, 1000, 1_000_000).unwrap();
        assert!(!low.level_high);
        assert_eq!(low.pulse_width_samples, 50);
        assert_eq!(low.period_samples, Some(100));
        assert_eq!(low.duty, Some(0.5));

        let leading = measure_pulse(&bytes, 10_000, 10, 1_000_000).unwrap();
        assert_eq!(leading.pulse_width_samples, 50);
        assert_eq!(leading.period_samples, None);
    }
}
