//! Measurements on packed logic samples.
//!
//! Bits are LSB-first: bit 0 of byte 0 is sample 0. Search and pulse math are
//! exact. The capture crate's mipmap is for drawing, not for these answers.
//!
//! # Measurement inputs
//!
//! Callers supply the original packed channel bytes, their valid sample count,
//! and a sample rate when time units are needed. The valid count must not exceed
//! the available packed data when using edge searches. All positions are
//! capture-relative sample indexes, so results can be used directly for cursors,
//! trigger markers, and decoder regions.

/// One pulse under the cursor, plus the rising-to-rising cycle that contains it
/// when both edges exist.
#[derive(Clone, Debug, PartialEq)]
pub struct PulseMetrics {
    /// Capture position at which the pulse was measured.
    pub sample: u64,
    /// Whether the measured run is high rather than low.
    pub level_high: bool,
    /// Inclusive start and exclusive end of the measured run.
    pub pulse_start: u64,
    pub pulse_end: u64,
    /// Rising edges bounding the cycle, when both are available.
    pub period_start: Option<u64>,
    pub period_end: Option<u64>,
    /// Length of the current high or low run, in samples.
    pub pulse_width_samples: u64,
    /// Rising-to-rising cycle length when the surrounding cycle is known.
    pub period_samples: Option<u64>,
    /// High portion of the known rising-to-rising cycle.
    pub high_samples: Option<u64>,
    /// Duration of the measured run at the capture sample rate.
    pub width_secs: f64,
    /// Cycle duration when enough edges are available.
    pub period_secs: Option<f64>,
    /// Cycle frequency when a nonzero period is available.
    pub frequency_hz: Option<f64>,
    /// High time divided by the rising-to-rising period.
    pub duty: Option<f64>,
}

/// Reads a channel level from the packed capture data; missing bytes are treated as low.
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

/// Largest sample `i < from` where the level becomes `rising` (true) or low (false).
pub fn find_edge_before(bytes: &[u8], len: u64, from: u64, rising: bool) -> Option<u64> {
    if len < 2 || from == 0 {
        return None;
    }
    let mut i = from.min(len);
    while i > 1 {
        i -= 1;
        let level = bit_at(bytes, i);
        let prev = bit_at(bytes, i - 1);
        if prev != level && level == rising {
            return Some(i);
        }
    }
    None
}

/// Edge closest to `sample`, rising or falling.
pub fn nearest_edge(bytes: &[u8], len: u64, sample: u64) -> Option<u64> {
    if len < 2 {
        return None;
    }
    let sample = sample.min(len - 1);
    let mut best: Option<u64> = None;
    let mut consider = |hit: Option<u64>| {
        if let Some(hit) = hit {
            let replace = best
                .map(|prev| hit.abs_diff(sample) < prev.abs_diff(sample))
                .unwrap_or(true);
            if replace {
                best = Some(hit);
            }
        }
    };
    let origin = sample.saturating_sub(1);
    consider(find_edge(bytes, len, origin, true));
    consider(find_edge(bytes, len, origin, false));
    let before = sample.saturating_add(1);
    consider(find_edge_before(bytes, len, before, true));
    consider(find_edge_before(bytes, len, before, false));
    best
}

/// Measures the pulse under a sample position using the original channel data.
///
/// Cycle measurements are present only when both surrounding rising edges are
/// known. Returns `None` for an invalid position, empty data, or an unknown rate.
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
        pulse_start: start,
        pulse_end: end,
        period_start: if next_rise.is_some() { rise_at } else { None },
        period_end: next_rise,
        pulse_width_samples: pulse_width,
        period_samples: period,
        high_samples,
        width_secs,
        period_secs,
        frequency_hz,
        duty,
    })
}

/// Sample where the last edge in `steps` occurs.
///
/// Each step is `(channel, rising)`. The next edge must be strictly after the
/// previous one. An empty list, or a step that never happens, returns none.
pub fn find_edge_sequence(
    len: u64,
    steps: &[(usize, bool)],
    mut level: impl FnMut(usize, u64) -> bool,
) -> Option<u64> {
    if steps.is_empty() || len == 0 {
        return None;
    }
    let mut from = 0u64;
    let mut hit = None;
    for &(channel, rising) in steps {
        let edge = next_level_edge(len, from, rising, |sample| level(channel, sample))?;
        from = edge;
        hit = Some(edge);
    }
    hit
}

/// Finds the next qualifying transition while evaluating an ordered trigger sequence.
fn next_level_edge(
    len: u64,
    from: u64,
    rising: bool,
    mut level: impl FnMut(u64) -> bool,
) -> Option<u64> {
    if from >= len {
        return None;
    }
    let mut prev = level(from);
    let mut sample = from + 1;
    while sample < len {
        let now = level(sample);
        if now != prev && now == rising {
            return Some(sample);
        }
        prev = now;
        sample += 1;
    }
    None
}

/// Next or previous place where `pattern` matches.
///
/// `None` in the pattern ignores that sample. Search starts strictly after
/// `from` when moving forward and strictly before it when moving backward.
pub fn find_pattern(
    bytes: &[u8],
    len: u64,
    from: u64,
    pattern: &[Option<bool>],
    forward: bool,
) -> Option<u64> {
    if pattern.is_empty() || len < pattern.len() as u64 {
        return None;
    }
    let last = len - pattern.len() as u64;
    if forward {
        let start = from.saturating_add(1);
        let mut i = start;
        while i <= last {
            if pattern_at(bytes, i, pattern) {
                return Some(i);
            }
            i += 1;
        }
        None
    } else {
        let mut i = from.min(last + 1);
        while i > 0 {
            i -= 1;
            if i <= last && pattern_at(bytes, i, pattern) {
                return Some(i);
            }
        }
        None
    }
}

/// Checks whether the capture matches a search pattern at one candidate position.
fn pattern_at(bytes: &[u8], at: u64, pattern: &[Option<bool>]) -> bool {
    pattern.iter().enumerate().all(|(offset, want)| match want {
        None => true,
        Some(level) => bit_at(bytes, at + offset as u64) == *level,
    })
}

/// Rising and falling edges in `[start, end)`.
pub fn count_edges(bytes: &[u8], len: u64, start: u64, end: u64) -> u64 {
    let end = end.min(len);
    if end <= start.saturating_add(1) {
        return 0;
    }
    let mut edges = 0u64;
    let mut prev = bit_at(bytes, start);
    let mut i = start + 1;
    while i < end {
        let level = bit_at(bytes, i);
        if level != prev {
            edges += 1;
        }
        prev = level;
        i += 1;
    }
    edges
}

/// Distance between two cursors.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct CursorSpan {
    /// Distance between the clipped cursor positions.
    pub samples: u64,
    /// Cursor interval at the capture sample rate.
    pub seconds: f64,
    /// Number of transitions within the measured interval.
    pub edges: u64,
}

/// Measures the interval and edge count between two waveform cursors.
///
/// Positions are clipped to the capture; an unknown sample rate gives zero seconds.
pub fn cursor_span(bytes: &[u8], len: u64, a: u64, b: u64, rate_hz: u64) -> CursorSpan {
    let start = a.min(b).min(len);
    let end = a.max(b).min(len);
    let samples = end.saturating_sub(start);
    let seconds = if rate_hz == 0 {
        0.0
    } else {
        samples as f64 / rate_hz as f64
    };
    CursorSpan {
        samples,
        seconds,
        edges: count_edges(bytes, len, start, end),
    }
}

#[cfg(test)]
mod tests {
    //! Checks measurement and search results against independently generated waveforms.

    use super::*;

    /// Builds a predictable clock signal shared by measurement and search tests.
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

    /// Checks that an ordered trigger fires only after every requested transition.
    #[test]
    fn sequence_fires_on_the_later_edge() {
        let ch0 = [0xF0];
        let ch1 = [0xCC];
        let level =
            |channel: usize, sample: u64| bit_at(if channel == 0 { &ch0 } else { &ch1 }, sample);
        assert_eq!(
            find_edge_sequence(8, &[(0, true), (1, true)], level),
            Some(6)
        );
        assert_eq!(
            find_edge_sequence(8, &[(1, true), (0, true)], level),
            Some(4)
        );
        assert_eq!(find_edge_sequence(8, &[(0, true), (0, true)], level), None);
        assert_eq!(find_edge_sequence(8, &[], level), None);
    }

    /// Checks forward edge searches against known clock transitions.
    #[test]
    fn first_rising_edge_of_the_clock_is_sample_50() {
        let bytes = clock_bytes(1000);
        assert_eq!(find_edge(&bytes, 1000, 0, true), Some(50));
        assert_eq!(find_edge(&bytes, 1000, 50, true), Some(150));
        assert_eq!(find_edge(&bytes, 1000, 49, true), Some(50));
        assert_eq!(find_edge(&bytes, 1000, 0, false), Some(100));
    }

    /// Checks that cursor snapping chooses the closest available transition.
    #[test]
    fn nearest_clock_edge_snaps_to_the_closer_transition() {
        let bytes = clock_bytes(1_000);
        assert_eq!(find_edge_before(&bytes, 1_000, 150, true), Some(50));
        assert_eq!(find_edge_before(&bytes, 1_000, 100, false), None);
        assert_eq!(nearest_edge(&bytes, 1_000, 40), Some(50));
        assert_eq!(nearest_edge(&bytes, 1_000, 60), Some(50));
        assert_eq!(nearest_edge(&bytes, 1_000, 90), Some(100));
        assert_eq!(nearest_edge(&bytes, 1_000, 50), Some(50));
    }

    /// Checks pulse and cycle measurements, including an incomplete leading cycle.
    #[test]
    fn pulse_metrics_on_the_clock() {
        let bytes = clock_bytes(10_000);
        let high = measure_pulse(&bytes, 10_000, 75, 1_000_000).unwrap();
        assert!(high.level_high);
        assert_eq!((high.pulse_start, high.pulse_end), (50, 100));
        assert_eq!((high.period_start, high.period_end), (Some(50), Some(150)));
        assert_eq!(high.pulse_width_samples, 50);
        assert_eq!(high.period_samples, Some(100));
        assert_eq!(high.high_samples, Some(50));
        assert_eq!(high.frequency_hz, Some(10_000.0));
        assert_eq!(high.duty, Some(0.5));
        assert_eq!(high.width_secs, 50.0 / 1_000_000.0);
        assert_eq!(high.period_secs, Some(100.0 / 1_000_000.0));

        let low = measure_pulse(&bytes, 10_000, 1000, 1_000_000).unwrap();
        assert!(!low.level_high);
        assert_eq!((low.pulse_start, low.pulse_end), (1000, 1050));
        assert_eq!((low.period_start, low.period_end), (Some(950), Some(1050)));
        assert_eq!(low.pulse_width_samples, 50);
        assert_eq!(low.period_samples, Some(100));
        assert_eq!(low.duty, Some(0.5));

        let leading = measure_pulse(&bytes, 10_000, 10, 1_000_000).unwrap();
        assert_eq!(leading.pulse_width_samples, 50);
        assert_eq!(leading.period_samples, None);
    }

    /// Checks pattern navigation and cursor measurements against a known waveform.
    #[test]
    fn pattern_search_and_cursor_span_match_the_clock() {
        let bytes = clock_bytes(1_000);
        let high_low = [Some(true), Some(false)];
        assert_eq!(find_pattern(&bytes, 1_000, 0, &high_low, true), Some(99));
        assert_eq!(find_pattern(&bytes, 1_000, 99, &high_low, true), Some(199));
        assert_eq!(find_pattern(&bytes, 1_000, 199, &high_low, false), Some(99));
        let span = cursor_span(&bytes, 1_000, 50, 150, 1_000_000);
        assert_eq!(span.samples, 100);
        assert_eq!(span.seconds, 0.0001);
        assert_eq!(span.edges, 1);
        assert_eq!(count_edges(&bytes, 1_000, 0, 200), 3);
    }
}
