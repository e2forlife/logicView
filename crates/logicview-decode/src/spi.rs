//! SPI from the Motorola mode table.
//!
//! CPOL is the idle clock level. CPHA 0 samples on the leading edge (the edge
//! that leaves idle); CPHA 1 samples on the trailing edge. Bytes are MSB first
//! unless `order` is `lsb`. Chip select is active low unless `cs` is `high`.
//! A word is emitted when `bits` samples have been collected inside a select.

use std::collections::BTreeMap;

use super::{Annotation, Decoder, DecodeError, SampleSlice};

/// Stateful SPI interpreter that preserves partially collected words across capture slices.
#[derive(Clone, Debug)]
pub struct SpiDecoder {
    cpol: bool,
    cpha: bool,
    msb: bool,
    bits_per_word: u8,
    cs_active_low: bool,
    primed: bool,
    prev_sck: bool,
    prev_selected: bool,
    mosi_acc: u8,
    miso_acc: u8,
    got: u8,
    word_start: u64,
    select_start: u64,
    words_in_select: u32,
}

impl Default for SpiDecoder {
    /// Creates a mode-zero SPI decoder with eight-bit words and active-low selection.
    fn default() -> Self {
        Self {
            cpol: false,
            cpha: false,
            msb: true,
            bits_per_word: 8,
            cs_active_low: true,
            primed: false,
            prev_sck: false,
            prev_selected: false,
            mosi_acc: 0,
            miso_acc: 0,
            got: 0,
            word_start: 0,
            select_start: 0,
            words_in_select: 0,
        }
    }
}

impl SpiDecoder {
    /// Interprets chip-select voltage according to the configured active polarity.
    fn selected(&self, cs_high: bool) -> bool {
        if self.cs_active_low {
            !cs_high
        } else {
            cs_high
        }
    }

    /// Chooses the sampling edge from the configured SPI mode.
    fn sample_on_rising(&self) -> bool {
        self.cpol == self.cpha
    }
}

impl Decoder for SpiDecoder {
    /// Returns the stable identifier used to select this protocol in engine commands.
    fn id(&self) -> &'static str {
        "spi"
    }

    /// Returns the display name for this protocol analyzer.
    fn name(&self) -> &'static str {
        "SPI"
    }

    /// Lists the signal roles the engine maps to captured channels.
    fn channels(&self) -> &'static [&'static str] {
        &["sck", "mosi", "miso", "cs"]
    }

    /// Clears partial protocol state while preserving the selected decoding options.
    fn reset(&mut self) {
        let (cpol, cpha, msb, bits, cs_active_low) = (
            self.cpol,
            self.cpha,
            self.msb,
            self.bits_per_word,
            self.cs_active_low,
        );
        *self = Self {
            cpol,
            cpha,
            msb,
            bits_per_word: bits,
            cs_active_low,
            prev_sck: cpol,
            ..Self::default()
        };
    }

    /// Accumulates both SPI data directions on selected clock edges and emits word and select
    /// annotations.
    fn feed(&mut self, slice: &SampleSlice<'_>) -> Vec<Annotation> {
        let mut out = Vec::new();
        let mut index = slice.start;
        let end = slice.end();
        if !self.primed {
            if slice.len == 0 {
                return out;
            }
            self.prev_sck = slice.bit("sck", index);
            self.prev_selected = (!slice.has_channel("cs")) || self.selected(slice.bit("cs", index));
            self.primed = true;
            index += 1;
        }
        let width = self.bits_per_word.max(1);
        while index < end {
            let sck = slice.bit("sck", index);
            let selected = (!slice.has_channel("cs")) || self.selected(slice.bit("cs", index));
            if selected && !self.prev_selected {
                self.select_start = index;
                self.words_in_select = 0;
                self.got = 0;
                self.mosi_acc = 0;
                self.miso_acc = 0;
                self.word_start = index;
            }
            let rising = !self.prev_sck && sck;
            let falling = self.prev_sck && !sck;
            let take = selected && ((self.sample_on_rising() && rising) || (!self.sample_on_rising() && falling));
            if take {
                if self.got == 0 {
                    self.word_start = index;
                }
                let mosi = slice.bit("mosi", index);
                let miso = slice.bit("miso", index);
                if self.msb {
                    self.mosi_acc = (self.mosi_acc << 1) | u8::from(mosi);
                    self.miso_acc = (self.miso_acc << 1) | u8::from(miso);
                } else {
                    self.mosi_acc |= u8::from(mosi) << self.got;
                    self.miso_acc |= u8::from(miso) << self.got;
                }
                self.got += 1;
                if self.got == width {
                    out.push(word(self.word_start, index + 1, self.mosi_acc, self.miso_acc, slice.has_channel("mosi"), slice.has_channel("miso")));
                    self.words_in_select += 1;
                    self.got = 0;
                    self.mosi_acc = 0;
                    self.miso_acc = 0;
                }
            }
            if !selected && self.prev_selected {
                let mut fields = BTreeMap::new();
                fields.insert("words".into(), self.words_in_select.to_string());
                out.push(Annotation::new(
                    self.select_start,
                    index + 1,
                    "select",
                    format!("SPI {} word{}", self.words_in_select, if self.words_in_select == 1 { "" } else { "s" }),
                    fields,
                ));
                self.got = 0;
            }
            self.prev_sck = sck;
            self.prev_selected = selected;
            index += 1;
        }
        out
    }

    /// Produces no extra rows because only complete protocol events are emitted during feeding.
    fn finish(&mut self) -> Vec<Annotation> {
        Vec::new()
    }

    /// Configures the SPI clock mode, bit order, word width, or chip-select polarity.
    fn set_option(&mut self, key: &str, value: &str) -> Result<(), DecodeError> {
        match key {
            "cpol" => self.cpol = parse_bit(value)?,
            "cpha" => self.cpha = parse_bit(value)?,
            "order" => {
                self.msb = match value {
                    "msb" => true,
                    "lsb" => false,
                    _ => {
                        return Err(DecodeError::Message(
                            "order must be msb or lsb".into(),
                        ))
                    }
                }
            }
            "bits" => {
                let bits: u8 = value
                    .parse()
                    .map_err(|_| DecodeError::Message("bits must be 1..=8".into()))?;
                if !(1..=8).contains(&bits) {
                    return Err(DecodeError::Message("bits must be 1..=8".into()));
                }
                self.bits_per_word = bits;
            }
            "cs" => match value {
                "low" => self.cs_active_low = true,
                "high" => self.cs_active_low = false,
                _ => return Err(DecodeError::Message("cs must be low or high".into())),
            },
            _ => return Err(DecodeError::UnknownOption(key.into())),
        }
        Ok(())
    }
}

/// Accepts the supported textual forms for SPI clock settings.
fn parse_bit(value: &str) -> Result<bool, DecodeError> {
    match value {
        "0" | "false" | "low" => Ok(false),
        "1" | "true" | "high" => Ok(true),
        _ => Err(DecodeError::Message(
            "expected 0 or 1 for a clock option".into(),
        )),
    }
}

/// Creates a decoded SPI word with structured values for both transfer directions.
fn word(start: u64, end: u64, mosi: u8, miso: u8, has_mosi: bool, has_miso: bool) -> Annotation {
    let mut fields = BTreeMap::new();
    let mut labels = Vec::new();
    if has_mosi {
        fields.insert("mosi".into(), format!("{mosi:02X}"));
        fields.insert("data".into(), format!("{mosi:02X}"));
        labels.push(format!("MOSI 0x{mosi:02X}"));
    }
    if has_miso {
        fields.insert("miso".into(), format!("{miso:02X}"));
        labels.push(format!("MISO 0x{miso:02X}"));
    }
    Annotation::new(start, end, "word", labels.join(" "), fields)
}

#[cfg(test)]
mod tests {
    //! Checks SPI interpretation using independently generated signal levels.

    use std::sync::atomic::AtomicBool;

    use crate::{run, DecodeRequest};

    /// Adds a complete mode-zero clocked transfer to the SPI test waveform.
    fn push_bit(rows: &mut Vec<[bool; 4]>, mosi: bool, miso: bool) {
        for _ in 0..4 {
            rows.push([false, mosi, miso, false]);
        }
        for _ in 0..4 {
            rows.push([true, mosi, miso, false]);
        }
    }

    /// Extracts one packed channel from the synthetic multi-line SPI waveform.
    fn pack(rows: &[[bool; 4]], lane: usize) -> Vec<u8> {
        let mut out = vec![0u8; rows.len().div_ceil(8)];
        for (index, row) in rows.iter().enumerate() {
            if row[lane] {
                out[index / 8] |= 1 << (index % 8);
            }
        }
        out
    }

    /// Checks a known SPI transfer and its chip-select annotation against independent expected
    /// values.
    #[test]
    fn spi_mode0_golden_word() {
        let mut rows = Vec::new();
        for _ in 0..24 {
            rows.push([false, false, false, true]);
        }
        for _ in 0..4 {
            rows.push([false, false, false, false]);
        }
        let mosi = 0xA5u8;
        let miso = 0x3Cu8;
        for shift in (0..8).rev() {
            push_bit(
                &mut rows,
                (mosi >> shift) & 1 == 1,
                (miso >> shift) & 1 == 1,
            );
        }
        for _ in 0..8 {
            rows.push([false, false, false, false]);
        }
        for _ in 0..16 {
            rows.push([false, false, false, true]);
        }
        let sck = pack(&rows, 0);
        let mosi_bits = pack(&rows, 1);
        let miso_bits = pack(&rows, 2);
        let cs = pack(&rows, 3);
        let len = rows.len() as u64;
        let channels = [
            ("sck", sck.as_slice()),
            ("mosi", mosi_bits.as_slice()),
            ("miso", miso_bits.as_slice()),
            ("cs", cs.as_slice()),
        ];
        let output = run(
            &DecodeRequest {
                protocol: "spi",
                channels: &channels,
                options: &[],
                region: 0..len,
                sample_len: len, sample_rate_hz: None,
                lower: &[], lower_packets: &[],
            },
            &AtomicBool::new(false),
        )
        .unwrap();
        let words: Vec<_> = output
            .annotations
            .iter()
            .filter(|row| row.class == "word")
            .collect();
        assert_eq!(words.len(), 1);
        assert_eq!(words[0].fields.get("mosi").map(String::as_str), Some("A5"));
        assert_eq!(words[0].fields.get("miso").map(String::as_str), Some("3C"));
        assert_eq!(words[0].text, "MOSI 0xA5 MISO 0x3C");
        assert!(output.annotations.iter().any(|row| row.class == "select"));
        let packet = output.packets.iter().find(|packet| packet.kind == "DATA").unwrap();
        assert_eq!(packet.data["mosi"], 0xa5);
        assert_eq!(packet.data["miso"], 0x3c);
        assert!(output.packets.iter().any(|packet| packet.kind == "CS-CHANGE"));
    }
    #[test]
    fn spi_decodes_one_data_line_without_chip_select() {
        let mut rows = vec![[false, false, false, false]; 4];
        for shift in (0..8).rev() {
            push_bit(&mut rows, false, (0x3Cu8 >> shift) & 1 == 1);
        }
        let sck = pack(&rows, 0);
        let miso = pack(&rows, 2);
        let channels = [("sck", sck.as_slice()), ("miso", miso.as_slice())];
        let len = rows.len() as u64;
        let result = run(&DecodeRequest { protocol: "spi", channels: &channels, options: &[], region: 0..len, sample_len: len, sample_rate_hz: None, lower: &[], lower_packets: &[] }, &AtomicBool::new(false)).unwrap();
        let word = result.annotations.iter().find(|row| row.class == "word").unwrap();
        assert_eq!(word.fields.get("miso").map(String::as_str), Some("3C"));
        assert!(!word.fields.contains_key("mosi"));
        assert_eq!(word.text, "MISO 0x3C");
        let packet = result.packets.iter().find(|packet| packet.kind == "DATA").unwrap();
        assert_eq!(packet.data["miso"], 0x3c);
        assert!(packet.data["mosi"].is_null());
    }

}
