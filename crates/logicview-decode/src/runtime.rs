//! Slice runner, annotation search, and export.
//!
//! Cancel is checked before every slice, so a flag that is already set returns
//! without emitting rows.

use std::sync::atomic::{AtomicBool, Ordering};

use super::{create, Annotation, DecodeError, DecodeOutput, DecodeRequest, SampleSlice};

const SLICE: u64 = 4_096;

pub fn run(request: &DecodeRequest<'_>, cancel: &AtomicBool) -> Result<DecodeOutput, DecodeError> {
    let Some(mut decoder) = create(request.protocol) else {
        return Err(DecodeError::UnknownProtocol(request.protocol.into()));
    };
    for (key, value) in request.options {
        decoder.set_option(key, value)?;
    }
    if decoder.stack_on().is_some() {
        if cancel.load(Ordering::Relaxed) {
            return Ok(DecodeOutput {
                annotations: Vec::new(),
                cancelled: true,
            });
        }
        let mut annotations = decoder.feed_lower(request.lower);
        annotations.extend(decoder.finish());
        return Ok(DecodeOutput {
            annotations,
            cancelled: false,
        });
    }
    let end = request.region.end.min(request.sample_len);
    let mut cursor = request.region.start.min(end);
    let mut annotations = Vec::new();
    while cursor < end {
        if cancel.load(Ordering::Relaxed) {
            return Ok(DecodeOutput {
                annotations,
                cancelled: true,
            });
        }
        let len = (end - cursor).min(SLICE);
        let slice = SampleSlice::new(cursor, len, request.channels);
        annotations.extend(decoder.feed(&slice));
        cursor += len;
    }
    if cancel.load(Ordering::Relaxed) {
        return Ok(DecodeOutput {
            annotations,
            cancelled: true,
        });
    }
    annotations.extend(decoder.finish());
    Ok(DecodeOutput {
        annotations,
        cancelled: false,
    })
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

fn csv_escape(text: &str) -> String {
    if text.contains([',', '"', '\n']) {
        format!("\"{}\"", text.replace('"', "\"\""))
    } else {
        text.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Annotation;
    use std::collections::BTreeMap;

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
                lower: &[],
            },
            &AtomicBool::new(true),
        )
        .unwrap();
        assert!(output.cancelled);
        assert!(output.annotations.is_empty());
    }

    #[test]
    fn byte_pattern_and_substring_search() {
        let rows = vec![
            ann("address", "Write 0x50", &[("raw", "A0"), ("address", "50")]),
            ann("data", "Data 0x10", &[("data", "10")]),
            ann("data", "Data 0x5A", &[("data", "5A")]),
            ann("word", "MOSI 0xA5 MISO 0x3C", &[("mosi", "A5"), ("miso", "3C")]),
        ];
        let hit = search_annotations(&rows, "A0-10-5A");
        assert_eq!(hit, vec![0, 1, 2]);
        let text = search_annotations(&rows, "0x5A");
        assert_eq!(text, vec![2]);
        let csv = export_csv("i2c", &rows[..1]);
        assert!(csv.contains("Write 0x50"));
        assert!(export_text("i2c", &rows[..1]).contains("address"));
    }

    fn ann(class: &str, text: &str, fields: &[(&str, &str)]) -> Annotation {
        let mut map = BTreeMap::new();
        for (key, value) in fields {
            map.insert((*key).to_string(), (*value).to_string());
        }
        Annotation::new(0, 1, class, text, map)
    }
}
