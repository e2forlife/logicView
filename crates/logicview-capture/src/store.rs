//! Bit-packed logic pages and a hierarchy of edge summaries.
//!
//! Windows are 64 samples, then 64², 64³, and 64⁴. Each window stores whether
//! any bit changed, plus the first and last level. Tile queries walk the
//! coarsest aligned windows and only scan the ragged edges.

use logicview_analysis::bit_at;

use crate::error::CaptureError;

const WINDOWS: [u64; 4] = [64, 4_096, 262_144, 16_777_216];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Summary {
    first: bool,
    last: bool,
    toggled: bool,
    edges: u16,
}

impl Summary {
    fn empty() -> Self {
        Self {
            first: false,
            last: false,
            toggled: false,
            edges: 0,
        }
    }
}

#[derive(Clone, Debug)]
struct ChannelBits {
    bytes: Vec<u8>,
    len: u64,
    levels: [Vec<Summary>; 4],
}

impl ChannelBits {
    fn new() -> Self {
        Self {
            bytes: Vec::new(),
            len: 0,
            levels: [Vec::new(), Vec::new(), Vec::new(), Vec::new()],
        }
    }

    fn append(&mut self, bytes: &[u8], samples: u64) -> Result<(), CaptureError> {
        if !samples.is_multiple_of(8) || bytes.len() as u64 != samples / 8 {
            return Err(CaptureError::BadLength);
        }
        self.bytes.extend_from_slice(bytes);
        self.len += samples;
        self.extend_summaries();
        Ok(())
    }

    fn rebuild(&mut self) {
        for level in &mut self.levels {
            level.clear();
        }
        self.extend_summaries();
    }

    fn extend_summaries(&mut self) {
        let complete = self.len / WINDOWS[0];
        let have = self.levels[0].len() as u64;
        for index in have..complete {
            let start = index * WINDOWS[0];
            self.levels[0].push(scan(&self.bytes, start, start + WINDOWS[0]));
        }
        for level in 1..4 {
            let child = level - 1;
            let parents = self.levels[child].len() / 64;
            let have = self.levels[level].len();
            for index in have..parents {
                let start = index * 64;
                let summary = rollup(&self.levels[child][start..start + 64]);
                self.levels[level].push(summary);
            }
        }
    }

    fn summarize_range(&self, start: u64, end: u64) -> Summary {
        let end = end.min(self.len);
        if start >= end {
            return Summary::empty();
        }
        let mut cursor = start;
        let mut acc: Option<Summary> = None;
        while cursor < end {
            let (step, part) = self.take_step(cursor, end);
            acc = Some(match acc {
                None => part,
                Some(prev) => merge(prev, part),
            });
            cursor += step;
        }
        acc.unwrap_or_else(Summary::empty)
    }

    fn take_step(&self, cursor: u64, end: u64) -> (u64, Summary) {
        let remain = end - cursor;
        for level in (0..WINDOWS.len()).rev() {
            let win = WINDOWS[level];
            if win <= remain && cursor.is_multiple_of(win) {
                let index = (cursor / win) as usize;
                if let Some(summary) = self.levels[level].get(index) {
                    return (win, *summary);
                }
            }
        }
        let n = if !cursor.is_multiple_of(64) {
            (64 - (cursor % 64)).min(remain)
        } else {
            remain.min(64)
        };
        (n, scan(&self.bytes, cursor, cursor + n))
    }
}

fn scan(bytes: &[u8], start: u64, end: u64) -> Summary {
    if start >= end {
        return Summary::empty();
    }
    let first = bit_at(bytes, start);
    let mut last = first;
    let mut prev = first;
    let mut edges: u32 = 0;
    for index in start + 1..end {
        let level = bit_at(bytes, index);
        if level != prev {
            edges += 1;
            prev = level;
        }
        last = level;
    }
    Summary {
        first,
        last,
        toggled: edges > 0,
        edges: edges.min(u16::MAX as u32) as u16,
    }
}

fn rollup(children: &[Summary]) -> Summary {
    merge_all(children)
}

fn merge(left: Summary, right: Summary) -> Summary {
    let mut edges = u32::from(left.edges) + u32::from(right.edges);
    let mut toggled = left.toggled || right.toggled;
    if left.last != right.first {
        edges += 1;
        toggled = true;
    }
    Summary {
        first: left.first,
        last: right.last,
        toggled,
        edges: edges.min(u16::MAX as u32) as u16,
    }
}

fn merge_all(parts: &[Summary]) -> Summary {
    let mut acc = parts[0];
    for part in &parts[1..] {
        acc = merge(acc, *part);
    }
    acc
}

/// One pixel column of a digital trace.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Column {
    pub first: bool,
    pub last: bool,
    pub toggled: bool,
    pub edges: u16,
    /// False when this pixel starts at or after the last stored sample.
    /// A low level with `valid == false` is empty time, not a sample.
    pub valid: bool,
}

impl Column {
    fn empty() -> Self {
        Self {
            first: false,
            last: false,
            toggled: false,
            edges: 0,
            valid: false,
        }
    }
}

/// Min and max of an analog column, in volts.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct AnalogColumn {
    pub min: f32,
    pub max: f32,
    pub valid: bool,
}

#[derive(Clone, Debug)]
pub struct LogicStore {
    channels: Vec<ChannelBits>,
}

impl LogicStore {
    pub fn new(channel_count: usize) -> Self {
        Self {
            channels: (0..channel_count).map(|_| ChannelBits::new()).collect(),
        }
    }

    pub fn channel_count(&self) -> usize {
        self.channels.len()
    }

    pub fn len(&self) -> u64 {
        self.channels.first().map(|ch| ch.len).unwrap_or(0)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn level(&self, channel: usize, sample: u64) -> Option<bool> {
        let bytes = self.channel_bytes(channel).ok()?;
        if sample >= self.len() {
            return None;
        }
        Some(logicview_analysis::bit_at(bytes, sample))
    }

    pub fn channel_bytes(&self, channel: usize) -> Result<&[u8], CaptureError> {
        self.channels
            .get(channel)
            .map(|ch| ch.bytes.as_slice())
            .ok_or(CaptureError::BadChannel(channel))
    }

    pub fn append_channel(
        &mut self,
        channel: usize,
        bytes: &[u8],
        samples: u64,
    ) -> Result<(), CaptureError> {
        let ch = self
            .channels
            .get_mut(channel)
            .ok_or(CaptureError::BadChannel(channel))?;
        ch.append(bytes, samples)
    }

    pub fn from_channels(channels: Vec<Vec<u8>>, sample_count: u64) -> Result<Self, CaptureError> {
        let expect = (sample_count / 8) as usize;
        if !sample_count.is_multiple_of(8) {
            return Err(CaptureError::BadLength);
        }
        let mut store = Self::new(channels.len());
        for (index, bytes) in channels.into_iter().enumerate() {
            if bytes.len() != expect {
                return Err(CaptureError::BadLength);
            }
            store.channels[index].bytes = bytes;
            store.channels[index].len = sample_count;
            store.channels[index].rebuild();
        }
        Ok(store)
    }

    pub fn to_channels(&self) -> Vec<Vec<u8>> {
        self.channels.iter().map(|ch| ch.bytes.clone()).collect()
    }

    /// Drop samples from the front so at most `samples` remain.
    pub fn retain_tail(&mut self, samples: u64) {
        let keep = samples & !7;
        let len = self.len();
        if keep >= len {
            return;
        }
        let drop_bytes = ((len - keep) / 8) as usize;
        for channel in &mut self.channels {
            if channel.bytes.len() >= drop_bytes {
                channel.bytes.drain(..drop_bytes);
            }
            channel.len = keep.min(channel.len);
            channel.rebuild();
        }
    }

    pub fn tile(
        &self,
        channel: usize,
        start: f64,
        columns: usize,
        spp: f64,
    ) -> Result<Vec<Column>, CaptureError> {
        let ch = self
            .channels
            .get(channel)
            .ok_or(CaptureError::BadChannel(channel))?;
        if columns == 0 || !start.is_finite() || !spp.is_finite() || spp <= 0.0 {
            return Ok(Vec::new());
        }
        let mut out = Vec::with_capacity(columns);
        for col in 0..columns {
            let s0 = start + col as f64 * spp;
            let s1 = start + (col + 1) as f64 * spp;
            if s1 <= 0.0 || s0 >= ch.len as f64 {
                out.push(Column::empty());
                continue;
            }
            let a = s0.max(0.0).floor() as u64;
            let mut b = s1.ceil().max(0.0) as u64;
            if b <= a {
                b = a + 1;
            }
            // Do not scan bytes past the stored sample count. A partial last
            // atom or a request that runs off the end would otherwise turn
            // unread zeros into a falling edge and a noise tail.
            b = b.min(ch.len);
            if a >= ch.len {
                out.push(Column::empty());
                continue;
            }
            let summary = ch.summarize_range(a, b);
            out.push(Column {
                first: summary.first,
                last: summary.last,
                toggled: summary.toggled,
                edges: summary.edges,
                valid: true,
            });
        }
        Ok(out)
    }
}

#[derive(Clone, Debug, Default)]
pub struct AnalogStore {
    samples: Vec<f32>,
    /// Min/max of each 1024-sample block, built as samples arrive.
    block_min: Vec<f32>,
    block_max: Vec<f32>,
}

impl AnalogStore {
    const BLOCK: usize = 1024;

    pub fn len(&self) -> usize {
        self.samples.len()
    }

    pub fn is_empty(&self) -> bool {
        self.samples.is_empty()
    }

    pub fn samples(&self) -> &[f32] {
        &self.samples
    }

    /// Drop samples past `len`. A capture that appended an unpacked tail
    /// longer than the logic sample count must not keep those volts.
    pub fn truncate(&mut self, len: usize) {
        if self.samples.len() <= len {
            return;
        }
        self.samples.truncate(len);
        let blocks = len / Self::BLOCK;
        self.block_min.truncate(blocks);
        self.block_max.truncate(blocks);
    }

    pub fn append(&mut self, samples: &[f32]) -> Result<(), CaptureError> {
        self.samples.extend_from_slice(samples);
        self.rebuild_tail();
        Ok(())
    }

    pub fn from_samples(samples: Vec<f32>) -> Self {
        let mut store = Self {
            samples,
            block_min: Vec::new(),
            block_max: Vec::new(),
        };
        store.rebuild_tail();
        store
    }

    fn rebuild_tail(&mut self) {
        let full = self.samples.len() / Self::BLOCK;
        let have = self.block_min.len();
        for index in have..full {
            let start = index * Self::BLOCK;
            let window = &self.samples[start..start + Self::BLOCK];
            let mut min = window[0];
            let mut max = window[0];
            for value in window {
                min = min.min(*value);
                max = max.max(*value);
            }
            self.block_min.push(min);
            self.block_max.push(max);
        }
    }

    pub fn tile(&self, start: f64, columns: usize, spp: f64) -> Vec<AnalogColumn> {
        if columns == 0 || !start.is_finite() || !spp.is_finite() || spp <= 0.0 {
            return Vec::new();
        }
        let mut out = Vec::with_capacity(columns);
        let len = self.samples.len() as u64;
        for col in 0..columns {
            let s0 = start + col as f64 * spp;
            let s1 = start + (col + 1) as f64 * spp;
            if s1 <= 0.0 || s0 >= len as f64 || self.samples.is_empty() {
                out.push(AnalogColumn {
                    min: 0.0,
                    max: 0.0,
                    valid: false,
                });
                continue;
            }
            let a = s0.max(0.0).floor() as u64;
            let mut b = s1.ceil().max(0.0) as u64;
            if b <= a {
                b = a + 1;
            }
            b = b.min(len);
            if a >= len {
                out.push(AnalogColumn {
                    min: 0.0,
                    max: 0.0,
                    valid: false,
                });
                continue;
            }
            let (min, max) = self.range_min_max(a, b);
            out.push(AnalogColumn {
                min,
                max,
                valid: true,
            });
        }
        out
    }

    fn range_min_max(&self, start: u64, end: u64) -> (f32, f32) {
        let mut cursor = start as usize;
        let end = end as usize;
        let mut min = f32::MAX;
        let mut max = f32::MIN;
        let block = Self::BLOCK;
        if !cursor.is_multiple_of(block) {
            let n = (block - (cursor % block)).min(end - cursor);
            self.scan_into(cursor, cursor + n, &mut min, &mut max);
            cursor += n;
        }
        while cursor + block <= end {
            let index = cursor / block;
            if index < self.block_min.len() {
                min = min.min(self.block_min[index]);
                max = max.max(self.block_max[index]);
                cursor += block;
            } else {
                break;
            }
        }
        if cursor < end {
            self.scan_into(cursor, end, &mut min, &mut max);
        }
        (min, max)
    }

    fn scan_into(&self, start: usize, end: usize, min: &mut f32, max: &mut f32) {
        for value in &self.samples[start..end] {
            *min = min.min(*value);
            *max = max.max(*value);
        }
    }

    pub fn sample(&self, index: u64) -> Option<f32> {
        self.samples.get(index as usize).copied()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use logicview_analysis::find_edge;

    fn push_clock(store: &mut LogicStore, samples: u64) {
        let mut bytes = vec![0u8; (samples / 8) as usize];
        for sample in 0..samples {
            if sample % 100 >= 50 {
                bytes[(sample / 8) as usize] |= 1 << (sample % 8);
            }
        }
        store.append_channel(0, &bytes, samples).unwrap();
    }

    #[test]
    fn mipmap_search_matches_the_linear_scan() {
        let mut store = LogicStore::new(1);
        push_clock(&mut store, 20_000);
        let bytes = store.channel_bytes(0).unwrap();
        let mut from = 0u64;
        for _ in 0..20 {
            let linear = find_edge(bytes, store.len(), from, true).unwrap();
            let fast = find_edge_mip(&store, 0, from, true).unwrap();
            assert_eq!(linear, fast);
            from = linear;
        }
    }

    #[test]
    fn tiles_see_the_clock_edges() {
        let mut store = LogicStore::new(1);
        push_clock(&mut store, 4_096);
        let zoomed = store.tile(0, 0.0, 64, 1.0).unwrap();
        assert!(!zoomed[49].first);
        assert!(zoomed[50].first);
        assert!(!zoomed[50].toggled);
        let wide = store.tile(0, 0.0, 10, 100.0).unwrap();
        assert!(wide.iter().all(|col| col.toggled));
        let span = store.channels[0].summarize_range(40, 60);
        assert!(!span.first);
        assert!(span.last);
        assert!(span.toggled);
    }

    #[test]
    fn columns_past_the_last_sample_are_not_edges() {
        let mut store = LogicStore::new(1);
        let samples = 80u64;
        let bytes = vec![0xFFu8; (samples / 8) as usize];
        store.append_channel(0, &bytes, samples).unwrap();
        // One column sits on the high tail and runs past the buffer. The next
        // columns are entirely past the stored samples.
        let cols = store.tile(0, 64.0, 3, 64.0).unwrap();
        assert!(cols[0].valid);
        assert!(cols[0].first && cols[0].last);
        assert!(
            !cols[0].toggled,
            "unread samples past the buffer must not become a falling edge"
        );
        assert!(!cols[1].valid && !cols[1].toggled && !cols[1].first);
        assert!(!cols[2].valid && !cols[2].toggled);
    }

    fn find_edge_mip(store: &LogicStore, channel: usize, from: u64, rising: bool) -> Option<u64> {
        let ch = &store.channels[channel];
        if ch.len == 0 || from >= ch.len {
            return None;
        }
        let mut prev = bit_at(&ch.bytes, from);
        let mut i = from + 1;
        while i < ch.len {
            if i.is_multiple_of(64) {
                let index = (i / 64) as usize;
                if let Some(summary) = ch.levels[0].get(index) {
                    if summary.first != prev {
                        if summary.first == rising {
                            return Some(i);
                        }
                    } else if !summary.toggled {
                        i += 64;
                        prev = summary.last;
                        continue;
                    }
                }
            }
            let level = bit_at(&ch.bytes, i);
            if level != prev && level == rising {
                return Some(i);
            }
            prev = level;
            i += 1;
        }
        None
    }
}
