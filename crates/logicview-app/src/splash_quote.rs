//! Random startup quote: wording, letter timing, and placement under the logo.

use serde::Deserialize;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Logo art size inside the splash, in logical pixels. The quote uses the room below this.
pub(super) const LOGO_WIDTH: f64 = 780.0;
pub(super) const LOGO_HEIGHT: f64 = 260.0;
/// Splash height while a quote is showing. Tall enough for the wordmark plus two wrapped lines.
pub(super) const SPLASH_HEIGHT: f64 = 320.0;
/// How long the letters take to appear. Each character owns an equal slice of this window.
pub(super) const FADE_IN_MS: u64 = 2_000;
const HOLD_MS: u64 = 3_000;
/// Gap from the magnifier handle to the quote text, and from the text to the end of the wordmark.
const PAD_X: f64 = 8.0;
/// Gap from the bottom of the lettering to the quote text.
const PAD_Y: f64 = 6.0;
pub(super) const QUOTE_FONT_PX: f32 = 16.0;

/// Where the quote sits relative to the logo artwork, in image pixels.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) struct LogoAnchor {
    pub image_width: u32,
    pub image_height: u32,
    /// Exclusive right edge of the magnifier handle on the lowest lettering row.
    pub handle_right: u32,
    /// Inclusive row of the lowest lettering pixels.
    pub lettering_bottom: u32,
    /// Exclusive right edge of the logo artwork.
    pub wordmark_right: u32,
}

/// Anchor of the bundled logo. The Windows painter measures the PNG; the webview uses this.
#[cfg_attr(windows, allow(dead_code))]
pub(super) const APP_LOGO_ANCHOR: LogoAnchor = LogoAnchor {
    image_width: 2172,
    image_height: 724,
    handle_right: 310,
    lettering_bottom: 613,
    wordmark_right: 2144,
};

/// Plate and text column for a logo anchor, in logical pixels of the splash logo rect.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(super) struct QuotePlacement {
    pub plate_left: f64,
    pub plate_top: f64,
    pub plate_width: f64,
    pub pad_x: f64,
    pub pad_y: f64,
}

impl QuotePlacement {
    pub(super) fn from_anchor(anchor: &LogoAnchor) -> Self {
        let sx = LOGO_WIDTH / f64::from(anchor.image_width);
        let sy = LOGO_HEIGHT / f64::from(anchor.image_height);
        let plate_left = f64::from(anchor.handle_right) * sx;
        let plate_right = f64::from(anchor.wordmark_right) * sx;
        Self {
            plate_left,
            plate_top: f64::from(anchor.lettering_bottom.saturating_add(1)) * sy,
            plate_width: (plate_right - plate_left).max(0.0),
            pad_x: PAD_X,
            pad_y: PAD_Y,
        }
    }

    pub(super) fn text_left(self) -> f64 {
        self.plate_left + self.pad_x
    }

    pub(super) fn text_top(self) -> f64 {
        self.plate_top + self.pad_y
    }

    /// Width available for glyphs. Wrapped lines stop before the end of the wordmark.
    pub(super) fn wrap_width(self) -> f32 {
        (self.plate_width - self.pad_x * 2.0).max(0.0) as f32
    }
}

/// The splash stays up for the fade plus a hold long enough to read the finished line.
pub(super) fn splash_duration() -> Duration {
    Duration::from_millis(FADE_IN_MS + HOLD_MS)
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
struct Quote {
    quote: String,
    #[serde(rename = "ref")]
    reference: String,
}

#[derive(Deserialize)]
struct QuoteFile {
    quotes: Vec<Quote>,
}

/// Quote text, then ` - `, then the reference. `reference_start` is the first bold character.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Message {
    pub text: String,
    pub reference_start: usize,
}

impl Message {
    fn new(quote: &str, reference: &str) -> Self {
        let text = format!("{quote} - {reference}");
        let reference_start = quote.chars().count() + 3;
        Self {
            text,
            reference_start,
        }
    }

    pub(super) fn char_count(&self) -> usize {
        self.text.chars().count()
    }

    fn is_bold(&self, index: usize) -> bool {
        index >= self.reference_start
    }
}

fn load_quotes() -> Vec<Quote> {
    toml::from_str::<QuoteFile>(include_str!("../../../quotes.toml"))
        .map(|file| file.quotes)
        .unwrap_or_default()
}

/// Picks one embedded quote. An empty or unreadable file leaves the splash as the logo alone.
pub(super) fn pick() -> Option<Message> {
    let quotes = load_quotes();
    if quotes.is_empty() {
        return None;
    }
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.subsec_nanos() as usize)
        .unwrap_or(0);
    let chosen = &quotes[seed % quotes.len()];
    Some(Message::new(&chosen.quote, &chosen.reference))
}

/// Characters fully revealed, and the opacity (`0.0..=1.0`) of the character fading in now.
///
/// Character `i` fades during `[i / count, (i + 1) / count]` of the fade. At the end every
/// character is opaque.
pub(super) fn reveal(elapsed_ms: u64, count: usize) -> (usize, f32) {
    if count == 0 || elapsed_ms >= FADE_IN_MS {
        return (count, 1.0);
    }
    let pos = (elapsed_ms as f64 / FADE_IN_MS as f64) * count as f64;
    let done = pos.floor() as usize;
    let alpha = (pos - done as f64) as f32;
    (done.min(count), alpha.clamp(0.0, 1.0))
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct TextSpan {
    pub text: String,
    pub bold: bool,
    /// Index of this span's first character in [`Message::text`].
    pub start: usize,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub(super) struct TextLine {
    pub spans: Vec<TextSpan>,
}

struct Token {
    start: usize,
    text: String,
    bold: bool,
    /// Whitespace that precedes this word in the message. Omitted when the word starts a line.
    gap: String,
    gap_bold: bool,
}

fn tokens(message: &Message) -> Vec<Token> {
    let chars: Vec<char> = message.text.chars().collect();
    let mut tokens = Vec::new();
    let mut index = 0;
    while index < chars.len() {
        let mut gap = String::new();
        while index < chars.len() && chars[index].is_whitespace() {
            gap.push(chars[index]);
            index += 1;
        }
        if index >= chars.len() {
            break;
        }
        let start = index;
        let bold = message.is_bold(start);
        let gap_bold = !gap.is_empty() && message.is_bold(start - gap.chars().count());
        let mut text = String::new();
        while index < chars.len() && !chars[index].is_whitespace() && message.is_bold(index) == bold
        {
            text.push(chars[index]);
            index += 1;
        }
        tokens.push(Token {
            start,
            text,
            bold,
            gap,
            gap_bold,
        });
    }
    tokens
}

fn pieces(
    word: &str,
    bold: bool,
    max_width: f32,
    measure: &mut impl FnMut(&str, bool) -> f32,
) -> Vec<String> {
    if word.is_empty() {
        return Vec::new();
    }
    if measure(word, bold) <= max_width {
        return vec![word.to_string()];
    }
    let mut parts = Vec::new();
    let mut current = String::new();
    for ch in word.chars() {
        let mut trial = current.clone();
        trial.push(ch);
        if !current.is_empty() && measure(&trial, bold) > max_width {
            parts.push(std::mem::take(&mut current));
        }
        current.push(ch);
    }
    if !current.is_empty() {
        parts.push(current);
    }
    parts
}

fn append_text(line: &mut TextLine, start: usize, text: &str, bold: bool) {
    if text.is_empty() {
        return;
    }
    if let Some(span) = line.spans.last_mut() {
        if span.bold == bold && span.start + span.text.chars().count() == start {
            span.text.push_str(text);
            return;
        }
    }
    line.spans.push(TextSpan {
        text: text.to_string(),
        bold,
        start,
    });
}

fn line_width(line: &TextLine, measure: &mut impl FnMut(&str, bool) -> f32) -> f32 {
    line.spans
        .iter()
        .map(|span| measure(&span.text, span.bold))
        .sum()
}

/// Wraps the message so each line's measured width stays within `max_width`.
///
/// A single glyph wider than the column is left on its own line. Spaces that fall at a wrap are
/// not drawn; they still occupy a slice of the fade.
pub(super) fn wrap_message(
    message: &Message,
    max_width: f32,
    mut measure: impl FnMut(&str, bool) -> f32,
) -> Vec<TextLine> {
    if max_width <= 0.0 || message.text.is_empty() {
        return Vec::new();
    }
    let mut lines = Vec::new();
    let mut current = TextLine::default();
    for token in tokens(message) {
        let mut offset = 0usize;
        for (piece_index, piece) in pieces(&token.text, token.bold, max_width, &mut measure)
            .into_iter()
            .enumerate()
        {
            let piece_start = token.start + offset;
            offset += piece.chars().count();
            let piece_width = measure(&piece, token.bold);
            let continuing = !current.spans.is_empty();
            let gap_width = if continuing && piece_index == 0 {
                measure(&token.gap, token.gap_bold)
            } else {
                0.0
            };
            if continuing
                && line_width(&current, &mut measure) + gap_width + piece_width > max_width
            {
                lines.push(std::mem::take(&mut current));
            }
            if current.spans.is_empty() {
                append_text(&mut current, piece_start, &piece, token.bold);
            } else if piece_index == 0 {
                let gap_start = token.start - token.gap.chars().count();
                append_text(&mut current, gap_start, &token.gap, token.gap_bold);
                append_text(&mut current, piece_start, &piece, token.bold);
            } else {
                append_text(&mut current, piece_start, &piece, token.bold);
            }
        }
    }
    if !current.spans.is_empty() {
        lines.push(current);
    }
    lines
}

/// Locates the magnifier handle and the bottom of the wordmark in straight RGBA pixels.
pub(super) fn logo_anchor(pixels: &[u8], width: u32, height: u32) -> Option<LogoAnchor> {
    let needed = (width as usize)
        .checked_mul(height as usize)?
        .checked_mul(4)?;
    if width == 0 || height == 0 || pixels.len() < needed {
        return None;
    }
    let mut wordmark_right = 0u32;
    let mut lettering_bottom = None;
    let mut handle_below = None;
    let mut handle_right = None;
    for y in (0..height).rev() {
        let runs = opaque_runs(pixels, width, y);
        let Some(row_right) = runs.last().map(|run| run.1) else {
            continue;
        };
        wordmark_right = wordmark_right.max(row_right);
        let left_only = runs.len() == 1 && runs[0].1.saturating_mul(2) <= width;
        if lettering_bottom.is_none() {
            if left_only {
                handle_below = Some(runs[0].1);
                continue;
            }
            lettering_bottom = Some(y);
            handle_right = if runs.len() >= 2 && runs[0].1.saturating_mul(2) <= width {
                Some(runs[0].1)
            } else {
                handle_below
            };
        }
    }
    let lettering_bottom = lettering_bottom?;
    let handle_right = handle_right?;
    if wordmark_right <= handle_right {
        return None;
    }
    Some(LogoAnchor {
        image_width: width,
        image_height: height,
        handle_right,
        lettering_bottom,
        wordmark_right,
    })
}

fn opaque_runs(pixels: &[u8], width: u32, y: u32) -> Vec<(u32, u32)> {
    let mut runs = Vec::new();
    let mut start = None;
    for x in 0..width {
        let index = (y as usize * width as usize + x as usize) * 4 + 3;
        let opaque = pixels[index] > 16;
        match (opaque, start) {
            (true, None) => start = Some(x),
            (false, Some(begin)) => {
                runs.push((begin, x));
                start = None;
            }
            _ => {}
        }
    }
    if let Some(begin) = start {
        runs.push((begin, width));
    }
    runs
}

/// Splash page for platforms that show the logo in a webview.
#[cfg_attr(windows, allow(dead_code))]
pub(super) fn webview_html(origin: &str, message: Option<&Message>) -> String {
    let Some(message) = message else {
        return format!(
            r#"<!doctype html><html><head><style>
            html,body {{ margin:0; width:100%; height:100%; overflow:hidden; background:transparent; }}
            img {{ width:100%; height:100%; object-fit:contain; }}
            </style></head><body><img src="{origin}/assets/AppLogo.png" alt="LogicView"></body></html>"#
        );
    };
    let place = QuotePlacement::from_anchor(&APP_LOGO_ANCHOR);
    let count = message.char_count().max(1);
    let slot = FADE_IN_MS as f64 / count as f64;
    let mut letters = String::new();
    for (index, ch) in message.text.chars().enumerate() {
        let class = if message.is_bold(index) {
            "ch ref"
        } else {
            "ch"
        };
        let delay = index as f64 * slot;
        letters.push_str(&format!(
            r#"<span class="{class}" style="animation-delay:{delay:.2}ms">{}</span>"#,
            html_text(ch)
        ));
    }
    format!(
        r#"<!doctype html><html><head><style>
        html,body {{ margin:0; width:100%; height:100%; overflow:hidden; background:transparent; }}
        body {{ position:relative; }}
        img.logo {{ display:block; width:{logo_w}px; height:{logo_h}px; }}
        .plate {{
            position:absolute; left:{left:.1}px; top:{top:.1}px; width:fit-content; max-width:{width:.1}px;
            box-sizing:border-box; padding:{pad_y:.0}px {pad_x:.0}px;
            background:rgba(0,0,0,0.67); border-radius:8px; color:#fff;
            font:{font:.0}px/1.35 "Segoe UI",sans-serif; overflow-wrap:break-word;
        }}
        .ref {{ font-weight:700; }}
        .ch {{ opacity:0; animation:quote-in {slot:.2}ms linear forwards; }}
        @keyframes quote-in {{ from {{ opacity:0; }} to {{ opacity:1; }} }}
        </style></head><body>
        <img class="logo" src="{origin}/assets/AppLogo.png" alt="LogicView">
        <div class="plate">{letters}</div>
        </body></html>"#,
        logo_w = LOGO_WIDTH,
        logo_h = LOGO_HEIGHT,
        left = place.plate_left,
        top = place.plate_top,
        width = place.plate_width,
        pad_y = place.pad_y,
        pad_x = place.pad_x,
        font = QUOTE_FONT_PX,
    )
}

#[cfg_attr(windows, allow(dead_code))]
fn html_text(ch: char) -> String {
    match ch {
        '&' => "&amp;".to_string(),
        '<' => "&lt;".to_string(),
        '>' => "&gt;".to_string(),
        _ => ch.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quotes_file_loads_the_attribution_in_order() {
        let quotes = load_quotes();
        assert!(quotes.len() >= 5);
        assert_eq!(
            quotes[0].quote,
            "Test everything; hold fast to what is good."
        );
        assert_eq!(quotes[0].reference, "1 Thessolonians 5:21");
        let message = Message::new(&quotes[0].quote, &quotes[0].reference);
        assert_eq!(
            message.text,
            "Test everything; hold fast to what is good. - 1 Thessolonians 5:21"
        );
        assert!(message.is_bold(message.reference_start));
        assert!(!message.is_bold(message.reference_start - 1));
        assert_eq!(message.text.chars().nth(message.reference_start), Some('1'));
    }

    #[test]
    fn letters_share_the_fade_evenly() {
        let count = 10;
        let (done, alpha) = reveal(0, count);
        assert_eq!((done, alpha), (0, 0.0));
        assert_eq!(reveal(FADE_IN_MS, count).0, count);
        assert_eq!(reveal(FADE_IN_MS + 500, count).0, count);
        let slot = FADE_IN_MS as f64 / count as f64;
        for index in 0..count {
            let mid = ((index as f64 + 0.5) * slot).round() as u64;
            let (done, alpha) = reveal(mid, count);
            assert_eq!(done, index, "character {index} should be the one fading");
            assert!(
                (alpha - 0.5).abs() < 0.05,
                "character {index} alpha {alpha}"
            );
        }
    }

    #[test]
    fn wrapped_lines_stay_inside_the_column() {
        let message = Message::new(
            "An intelligent mind acquires knowledge, and the ear of the wise seeks knowledge.",
            "Proverbs 18:15",
        );
        let max = 40.0;
        let measure =
            |text: &str, bold: bool| text.chars().count() as f32 * if bold { 1.2 } else { 1.0 };
        let lines = wrap_message(&message, max, measure);
        assert!(lines.len() > 1);
        for line in &lines {
            let width: f32 = line
                .spans
                .iter()
                .map(|span| span.text.chars().count() as f32 * if span.bold { 1.2 } else { 1.0 })
                .sum();
            let chars = line
                .spans
                .iter()
                .map(|span| span.text.chars().count())
                .sum::<usize>();
            assert!(
                width <= max + 0.01 || chars == 1,
                "line is {width} wide: {line:?}"
            );
            for span in &line.spans {
                let from_message: String = message
                    .text
                    .chars()
                    .skip(span.start)
                    .take(span.text.chars().count())
                    .collect();
                assert_eq!(from_message, span.text);
                assert_eq!(span.bold, span.start >= message.reference_start);
            }
        }
        let bold: String = lines
            .iter()
            .flat_map(|line| line.spans.iter())
            .filter(|span| span.bold)
            .map(|span| span.text.as_str())
            .collect();
        assert_eq!(bold, "Proverbs 18:15");
        let shown: String = lines
            .iter()
            .flat_map(|line| line.spans.iter().map(|span| span.text.chars()))
            .flatten()
            .filter(|ch| !ch.is_whitespace())
            .collect();
        let expected: String = message
            .text
            .chars()
            .filter(|ch| !ch.is_whitespace())
            .collect();
        assert_eq!(shown, expected);
    }

    #[test]
    fn placement_starts_beside_the_handle_and_under_the_lettering() {
        let anchor = APP_LOGO_ANCHOR;
        let place = QuotePlacement::from_anchor(&anchor);
        let sx = LOGO_WIDTH / f64::from(anchor.image_width);
        let sy = LOGO_HEIGHT / f64::from(anchor.image_height);
        let handle = f64::from(anchor.handle_right) * sx;
        let wordmark = f64::from(anchor.wordmark_right) * sx;
        let lettering = f64::from(anchor.lettering_bottom + 1) * sy;
        assert!((place.plate_left - handle).abs() < 0.01);
        assert!((place.plate_top - lettering).abs() < 0.01);
        assert!(place.text_left() > handle);
        assert!(place.text_top() > lettering);
        assert!(place.text_left() + f64::from(place.wrap_width()) <= wordmark + 0.01);
        assert!(place.wrap_width() > 0.0);
    }

    #[test]
    fn logo_anchor_finds_a_handle_under_lettering() {
        let width = 30u32;
        let height = 12u32;
        let mut pixels = vec![0u8; width as usize * height as usize * 4];
        let paint = |pixels: &mut [u8], x: u32, y: u32| {
            let index = (y as usize * width as usize + x as usize) * 4;
            pixels[index + 3] = 255;
        };
        for y in 4..7 {
            for x in 12..25 {
                paint(&mut pixels, x, y);
            }
        }
        for y in 6..11 {
            for x in 4..8 {
                paint(&mut pixels, x, y);
            }
        }
        let anchor = logo_anchor(&pixels, width, height).unwrap();
        assert_eq!(anchor.lettering_bottom, 6);
        assert_eq!(anchor.handle_right, 8);
        assert_eq!(anchor.wordmark_right, 25);
    }

    #[test]
    fn webview_html_fades_the_reference_in_bold() {
        let message = Message::new("Be quick.", "Sirach 5:11");
        let html = webview_html("http://127.0.0.1:9", Some(&message));
        assert!(html.contains("font-weight:700"));
        assert!(html.contains("animation:quote-in"));
        assert!(html.contains("rgba(0,0,0,0.67)"));
        assert_eq!(html.matches("<span ").count(), message.char_count());
        let reference_chars = message.char_count() - message.reference_start;
        assert_eq!(html.matches("class=\"ch ref\"").count(), reference_chars);
        let plain = webview_html("http://127.0.0.1:9", None);
        assert!(!plain.contains("plate"));
    }

    #[cfg(windows)]
    #[test]
    fn bundled_logo_matches_the_webview_anchor() {
        let image =
            image::load_from_memory(include_bytes!("../../logicview-ui/assets/AppLogo.png"))
                .unwrap()
                .to_rgba8();
        let (width, height) = image.dimensions();
        let anchor = logo_anchor(image.as_raw(), width, height).unwrap();
        assert_eq!(anchor, APP_LOGO_ANCHOR);
    }
}
