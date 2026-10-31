//! Slice runner, annotation search, and export.
//!
//! Cancel is checked before every slice, so a flag that is already set returns
//! without emitting rows.

use std::sync::atomic::{AtomicBool, Ordering};

use super::{create, Annotation, DecodeError, DecodeOutput, DecodeRequest, SampleSlice};

const SLICE: u64 = 4_096;

/// Configures a decoder and runs it over bounded slices or lower-level annotations.
///
/// Cancellation returns the rows already completed without flushing unfinished
/// frames. Stacked decoders consume the supplied lower rows in one call.
pub fn run(request: &DecodeRequest<'_>, cancel: &AtomicBool) -> Result<DecodeOutput, DecodeError> {
    let Some(mut decoder) = create(request.protocol) else {
        return super::script::run_script(request, cancel);
    };
    for (key, value) in request.options {
        decoder.set_option(key, value)?;
    }
    if decoder.stack_on().is_some() {
        if cancel.load(Ordering::Relaxed) {
            return Ok(DecodeOutput::new(Vec::new(), Vec::new(), true));
        }
        let mut annotations = decoder.feed_lower(request.lower);
        annotations.extend(decoder.finish());
        return Ok(DecodeOutput::new(annotations, Vec::new(), false));
    }
    let end = request.region.end.min(request.sample_len);
    let mut cursor = request.region.start.min(end);
    let mut annotations = Vec::new();
    while cursor < end {
        if cancel.load(Ordering::Relaxed) {
            return Ok(DecodeOutput::new(annotations, Vec::new(), true));
        }
        let len = (end - cursor).min(SLICE);
        let slice = SampleSlice::new(cursor, len, request.channels);
        annotations.extend(decoder.feed(&slice));
        cursor += len;
    }
    if cancel.load(Ordering::Relaxed) {
        return Ok(DecodeOutput::new(annotations, Vec::new(), true));
    }
    annotations.extend(decoder.finish());
    let packets = if request.protocol == "spi" {
        let mut packets: Vec<_> = annotations
            .iter()
            .filter(|row| row.class == "word")
            .map(|row| {
                let byte = |name: &str| {
                    row.fields
                        .get(name)
                        .and_then(|s| u64::from_str_radix(s, 16).ok())
                };
                super::ProtocolPacket {
                    start_sample: row.start_sample,
                    end_sample: row.end_sample,
                    kind: "DATA".into(),
                    data: serde_json::json!({ "mosi": byte("mosi"), "miso": byte("miso") }),
                }
            })
            .collect();
        if let Some((_, bytes)) = request.channels.iter().find(|(name, _)| *name == "cs") {
            let start = request.region.start.min(end);
            if start < end {
                let active_high = request
                    .options
                    .iter()
                    .any(|(key, value)| key == "cs" && value == "high");
                let mut previous = logicview_analysis::bit_at(bytes, start);
                for sample in start + 1..end {
                    let current = logicview_analysis::bit_at(bytes, sample);
                    if current != previous {
                        packets.push(super::ProtocolPacket { start_sample: sample, end_sample: sample + 1,
                            kind: "CS-CHANGE".into(), data: serde_json::json!({ "old": previous, "new": current, "selected": current == active_high }) });
                        previous = current;
                    }
                }
            }
        }
        packets.sort_by_key(|packet| packet.end_sample);
        packets
    } else {
        Vec::new()
    };
    Ok(DecodeOutput::new(annotations, packets, false))
}

/// Substring match, or a dash-separated byte pattern such as `A0-10-5A`.
pub fn search_annotations(rows: &[Annotation], query: &str) -> Vec<usize> {
    let query = query.trim();
    if query.is_empty() {
        return (0..rows.len()).collect();
    }
    if let Some(pattern) = byte_pattern(query) {
        return match_bytes(rows, &pattern);
    }
    let needle = query.to_ascii_lowercase();
    rows.iter()
        .enumerate()
        .filter_map(|(index, row)| {
            let hay = format!(
                "{} {} {}",
                row.class,
                row.text,
                row.fields
                    .iter()
                    .map(|(key, value)| format!("{key}={value}"))
                    .collect::<Vec<_>>()
                    .join(" ")
            )
            .to_ascii_lowercase();
            hay.contains(&needle).then_some(index)
        })
        .collect()
}

/// Recognizes a byte-sequence search query so it can be matched against structured fields.
fn byte_pattern(query: &str) -> Option<Vec<u8>> {
    let parts: Vec<&str> = query.split('-').collect();
    if parts.len() < 2 {
        return None;
    }
    let mut out = Vec::with_capacity(parts.len());
    for part in parts {
        if part.len() != 2 {
            return None;
        }
        out.push(u8::from_str_radix(part, 16).ok()?);
    }
    Some(out)
}

/// Selects the protocol byte represented by a row for cross-row pattern searching.
fn row_byte(row: &Annotation) -> Option<u8> {
    let key = if row.class == "address" {
        "raw"
    } else if row.class == "word" {
        "mosi"
    } else if row.fields.contains_key("data") {
        "data"
    } else {
        return None;
    };
    let text = row.fields.get(key)?;
    let text = text.split('-').next().unwrap_or(text);
    u8::from_str_radix(text, 16).ok()
}

/// Finds annotation rows participating in matching byte sequences, ignoring non-byte rows.
fn match_bytes(rows: &[Annotation], pattern: &[u8]) -> Vec<usize> {
    let indexed: Vec<(usize, u8)> = rows
        .iter()
        .enumerate()
        .filter_map(|(index, row)| row_byte(row).map(|byte| (index, byte)))
        .collect();
    let mut hits = Vec::new();
    if pattern.is_empty() || indexed.len() < pattern.len() {
        return hits;
    }
    for start in 0..=indexed.len() - pattern.len() {
        if indexed[start..start + pattern.len()]
            .iter()
            .zip(pattern)
            .all(|((_, byte), want)| byte == want)
        {
            for (index, _) in &indexed[start..start + pattern.len()] {
                if !hits.contains(index) {
                    hits.push(*index);
                }
            }
        }
    }
    hits
}

/// Serializes decoded annotations and their structured fields for spreadsheet analysis.
pub fn export_csv(decoder: &str, rows: &[Annotation]) -> String {
    let mut out = String::from("start_sample,end_sample,decoder,class,text,fields\n");
    for row in rows {
        let fields = row
            .fields
            .iter()
            .map(|(key, value)| format!("{key}={value}"))
            .collect::<Vec<_>>()
            .join(" ");
        out.push_str(&format!(
            "{},{},{},{},{},{}\n",
            row.start_sample,
            row.end_sample,
            csv_escape(decoder),
            csv_escape(&row.class),
            csv_escape(&row.text),
            csv_escape(&fields),
        ));
    }
    out
}

/// Serializes decoded annotations as a tab-separated, readable event listing.
pub fn export_text(decoder: &str, rows: &[Annotation]) -> String {
    let mut out = String::new();
    for row in rows {
        out.push_str(&format!(
            "{}\t{}\t{}\t{}\t{}\n",
            row.start_sample, row.end_sample, decoder, row.class, row.text
        ));
    }
    out
}

/// Protects annotation text containing CSV separators or quotes during export.
fn csv_escape(text: &str) -> String {
    if text.contains([',', '"', '\n']) {
        format!("\"{}\"", text.replace('"', "\"\""))
    } else {
        text.to_string()
    }
}

#[cfg(test)]
mod tests {
    //! Checks decode cancellation, annotation searches, and export behavior.

    use super::*;
    use crate::Annotation;
    use std::collections::BTreeMap;

    /// Checks that an already cancelled decode does no sample processing.
    #[test]
    fn cancel_returns_before_any_rows() {
        let scl = vec![0xFFu8; 64 * 1024];
        let sda = vec![0xFFu8; 64 * 1024];
        let len = scl.len() as u64 * 8;
        let channels = [("scl", scl.as_slice()), ("sda", sda.as_slice())];
        let output = run(
            &DecodeRequest {
                protocol: "i2c",
                channels: &channels,
                options: &[],
                region: 0..len,
                sample_len: len,
                sample_rate_hz: None,
                lower: &[],
                lower_packets: &[],
            },
            &AtomicBool::new(true),
        )
        .unwrap();
        assert!(output.cancelled);
        assert!(output.annotations.is_empty());
    }

    /// Checks structured byte searches, readable text searches, and annotation exports.
    #[test]
    fn byte_pattern_and_substring_search() {
        let rows = vec![
            ann("address", "Write 0x50", &[("raw", "A0"), ("address", "50")]),
            ann("data", "Data 0x10", &[("data", "10")]),
            ann("data", "Data 0x5A", &[("data", "5A")]),
            ann(
                "word",
                "MOSI 0xA5 MISO 0x3C",
                &[("mosi", "A5"), ("miso", "3C")],
            ),
        ];
        let hit = search_annotations(&rows, "A0-10-5A");
        assert_eq!(hit, vec![0, 1, 2]);
        let text = search_annotations(&rows, "0x5A");
        assert_eq!(text, vec![2]);
        let csv = export_csv("i2c", &rows[..1]);
        assert!(csv.contains("Write 0x50"));
        assert!(export_text("i2c", &rows[..1]).contains("address"));
    }

    /// Builds a structured annotation fixture for search and export tests.
    fn ann(class: &str, text: &str, fields: &[(&str, &str)]) -> Annotation {
        let mut map = BTreeMap::new();
        for (key, value) in fields {
            map.insert((*key).to_string(), (*value).to_string());
        }
        Annotation::new(0, 1, class, text, map)
    }
}
