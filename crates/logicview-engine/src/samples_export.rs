//! CSV and Excel exports of one capture.
//!
//! Rows are one sample each: time, then each logic channel as 0 or 1, then the
//! analog lane in volts when the session stored one. Excel's worksheet stops at
//! 1,048,575 data rows; a longer capture is cut there and `rows` is less than
//! `total`.

use logicview_analysis::bit_at;
use logicview_store::write_xlsx;

/// Excel's limit on data rows, leaving room for the header.
pub const MAX_TABLE_ROWS: u64 = 1_048_575;

pub struct SampleSnapshot {
    pub rate: u64,
    pub names: Vec<String>,
    pub packed: Vec<Vec<u8>>,
    pub len: u64,
    pub analog_name: String,
    pub analog: Vec<f32>,
}

pub struct SampleFile {
    pub body: Vec<u8>,
    pub rows: u64,
    pub total: u64,
}

pub fn render_csv(snap: &SampleSnapshot) -> SampleFile {
    let rows = snap.len.min(MAX_TABLE_ROWS);
    let headers = headers(snap);
    let mut out = String::with_capacity((rows as usize + 1) * (headers.len() * 8));
    push_csv_row(&mut out, &headers);
    for sample in 0..rows {
        let mut cells = Vec::with_capacity(headers.len());
        cells.push(format_time(sample, snap.rate));
        for bytes in &snap.packed {
            cells.push(if bit_at(bytes, sample) { "1" } else { "0" }.to_string());
        }
        if !snap.analog.is_empty() {
            cells.push(analog_cell(snap, sample));
        }
        push_csv_row(&mut out, &cells);
    }
    SampleFile {
        body: out.into_bytes(),
        rows,
        total: snap.len,
    }
}

pub fn render_xlsx(snap: &SampleSnapshot) -> Result<SampleFile, logicview_store::StoreError> {
    let rows = snap.len.min(MAX_TABLE_ROWS);
    let headers = headers(snap);
    let mut xml = String::with_capacity((rows as usize + 1) * (headers.len() * 24) + 256);
    xml.push_str(
        r#"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>"#,
    );
    xml.push_str("<row r=\"1\">");
    for (index, header) in headers.iter().enumerate() {
        let cell = format!("{}1", col_letter(index));
        xml.push_str(&format!(
            "<c t=\"inlineStr\" r=\"{cell}\"><is><t>{}</t></is></c>",
            xml_escape(header)
        ));
    }
    xml.push_str("</row>");
    for sample in 0..rows {
        let excel_row = sample + 2;
        xml.push_str(&format!("<row r=\"{excel_row}\">"));
        write_number(&mut xml, 0, excel_row, &format_time(sample, snap.rate));
        for (index, bytes) in snap.packed.iter().enumerate() {
            let bit = if bit_at(bytes, sample) { "1" } else { "0" };
            write_number(&mut xml, index + 1, excel_row, bit);
        }
        if !snap.analog.is_empty() {
            write_number(
                &mut xml,
                snap.packed.len() + 1,
                excel_row,
                &analog_cell(snap, sample),
            );
        }
        xml.push_str("</row>");
    }
    xml.push_str("</sheetData></worksheet>");
    Ok(SampleFile {
        body: write_xlsx(&xml)?,
        rows,
        total: snap.len,
    })
}

fn headers(snap: &SampleSnapshot) -> Vec<String> {
    let mut headers = Vec::with_capacity(snap.names.len() + 2);
    headers.push("time_s".into());
    headers.extend(snap.names.iter().cloned());
    if !snap.analog.is_empty() {
        headers.push(format!("{} (V)", snap.analog_name));
    }
    headers
}

fn format_time(sample: u64, rate: u64) -> String {
    let seconds = sample as f64 / rate.max(1) as f64;
    format!("{seconds:.9}")
}

fn analog_cell(snap: &SampleSnapshot, sample: u64) -> String {
    match snap.analog.get(sample as usize) {
        Some(value) if value.is_finite() => format!("{value:.6}"),
        _ => String::new(),
    }
}

fn push_csv_row(out: &mut String, cells: &[String]) {
    for (index, cell) in cells.iter().enumerate() {
        if index > 0 {
            out.push(',');
        }
        if cell.contains([',', '"', '\n', '\r']) {
            out.push('"');
            out.push_str(&cell.replace('"', "\"\""));
            out.push('"');
        } else {
            out.push_str(cell);
        }
    }
    out.push('\n');
}

fn write_number(xml: &mut String, column: usize, row: u64, value: &str) {
    let cell = format!("{}{row}", col_letter(column));
    if value.is_empty() {
        xml.push_str(&format!("<c r=\"{cell}\"/>"));
        return;
    }
    xml.push_str(&format!("<c r=\"{cell}\"><v>{value}</v></c>"));
}

fn col_letter(index: usize) -> String {
    let mut n = index + 1;
    let mut bytes = Vec::new();
    while n > 0 {
        n -= 1;
        bytes.push(b'A' + (n % 26) as u8);
        n /= 26;
    }
    bytes.reverse();
    String::from_utf8(bytes).unwrap_or_else(|_| "A".into())
}

fn xml_escape(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snap() -> SampleSnapshot {
        SampleSnapshot {
            rate: 1_000_000,
            names: vec!["CLK".into()],
            packed: vec![vec![0b0000_0010]],
            len: 2,
            analog_name: "SINE".into(),
            analog: vec![0.25, -0.5],
        }
    }

    #[test]
    fn csv_lists_time_logic_and_volts() {
        let file = render_csv(&snap());
        let text = String::from_utf8(file.body).unwrap();
        assert_eq!(file.rows, 2);
        assert!(text.starts_with("time_s,CLK,SINE (V)\n"));
        assert!(text.contains("0.000000000,0,0.250000\n"));
        assert!(text.contains("0.000001000,1,-0.500000\n"));
    }
}
