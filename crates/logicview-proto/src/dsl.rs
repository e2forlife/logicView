//! Writes the metadata portion of a session interchange header.
//!
//! This module does not read or write the complete capture archive.

/// One probe line in a `.dsl` header.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DslProbe {
    pub name: String,
    pub trigger: String,
}

/// Fields written into the text header of a version-3 session file.
///
/// This is only the header text. The `logicview-store` crate handles the ZIP
/// container and channel blocks. Names must not contain newlines.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DslHeader {
    pub version: u32,
    pub driver: String,
    pub mode: String,
    pub samples: u64,
    pub probes: u32,
    pub blocks: u32,
    pub sample_rate: u64,
    pub trigger_pos: u64,
    pub probe_meta: Vec<DslProbe>,
}

/// Render the header as stable INI-like text, including a trailing newline.
pub fn write_dsl_header(header: &DslHeader) -> String {
    let mut out = String::new();
    out.push_str("[header]\n");
    push_kv(&mut out, "version", &header.version.to_string());
    push_kv(&mut out, "driver", &header.driver);
    push_kv(&mut out, "mode", &header.mode);
    push_kv(&mut out, "samples", &header.samples.to_string());
    push_kv(&mut out, "probes", &header.probes.to_string());
    push_kv(&mut out, "blocks", &header.blocks.to_string());
    push_kv(&mut out, "samplerate", &header.sample_rate.to_string());
    push_kv(&mut out, "trigger_pos", &header.trigger_pos.to_string());
    push_kv(
        &mut out,
        "trigger_time",
        &format_trigger_time(header.trigger_pos, header.sample_rate),
    );
    for (index, probe) in header.probe_meta.iter().enumerate() {
        out.push('\n');
        out.push_str(&format!("[probe{index}]\n"));
        push_kv(&mut out, "name", &probe.name);
        push_kv(&mut out, "trigger", &probe.trigger);
    }
    out
}

/// Appends a metadata entry to the session header text.
fn push_kv(out: &mut String, key: &str, value: &str) {
    out.push_str(key);
    out.push('=');
    out.push_str(value);
    out.push('\n');
}

/// `trigger_pos / sample_rate`, always six digits after the decimal point.
pub fn format_trigger_time(trigger_pos: u64, sample_rate: u64) -> String {
    if sample_rate == 0 {
        return "0.000000".to_string();
    }
    let micros = trigger_pos.saturating_mul(1_000_000) / sample_rate;
    format!("{}.{:06}", micros / 1_000_000, micros % 1_000_000)
}

#[cfg(test)]
mod tests {
    //! Checks the stable session header text used for capture interchange.

    use super::*;

    /// Checks the session header against its stable interchange text fixture.
    #[test]
    fn dsl_header_matches_the_snapshot() {
        let header = DslHeader {
            version: 3,
            driver: "logicview".to_string(),
            mode: "logic".to_string(),
            samples: 4096,
            probes: 2,
            blocks: 1,
            sample_rate: 1_000_000,
            trigger_pos: 384,
            probe_meta: vec![
                DslProbe {
                    name: "CLK".to_string(),
                    trigger: "rising".to_string(),
                },
                DslProbe {
                    name: "UART".to_string(),
                    trigger: String::new(),
                },
            ],
        };
        let text = write_dsl_header(&header);
        let expected = "\
[header]
version=3
driver=logicview
mode=logic
samples=4096
probes=2
blocks=1
samplerate=1000000
trigger_pos=384
trigger_time=0.000384

[probe0]
name=CLK
trigger=rising

[probe1]
name=UART
trigger=
";
        assert_eq!(text, expected);
    }
}
