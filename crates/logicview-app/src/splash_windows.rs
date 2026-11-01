//! Per-pixel-alpha Windows splash rendering without a WebView background.

use rightkit_overlay_win::{
    Align, Animation, Easing, Font, FrameInfo, OverlayConfig, OverlayWindow, PaintCtx, Rect, Rgba,
};
use tao::window::Window;

use super::splash_quote::{self, Message, QuotePlacement};

/// Show the embedded PNG in a native layered window, preserving its alpha channel.
pub(super) fn show(reference: &Window, quote: Option<Message>) -> Result<OverlayWindow, String> {
    let image = image::load_from_memory(include_bytes!("../../logicview-ui/assets/AppLogo.png"))
        .map_err(|err| format!("could not read startup logo: {err}"))?
        .to_rgba8();
    let (width, height) = image.dimensions();
    let pixels = image.into_raw();
    let placement = splash_quote::logo_anchor(&pixels, width, height)
        .map(|anchor| QuotePlacement::from_anchor(&anchor))
        .filter(|place| place.wrap_width() > 0.0);
    let splash_height = if quote.is_some() && placement.is_some() {
        splash_quote::SPLASH_HEIGHT
    } else {
        splash_quote::LOGO_HEIGHT
    };
    let position = reference
        .outer_position()
        .map_err(|err| format!("could not place startup splash: {err}"))?;
    let overlay = OverlayWindow::create(OverlayConfig::passive("LogicViewSplash"))
        .map_err(|err| format!("could not create startup splash: {err}"))?;
    let handle = overlay.handle();
    let animate = quote.is_some() && placement.is_some();
    handle.set_painter(Box::new(move |ctx: &mut PaintCtx, frame: FrameInfo| {
        ctx.blit_rgba(
            &pixels,
            width,
            height,
            Rect {
                x: 0.0,
                y: 0.0,
                width: splash_quote::LOGO_WIDTH,
                height: splash_quote::LOGO_HEIGHT,
            },
        );
        if let (Some(place), Some(message)) = (placement, quote.as_ref()) {
            paint_quote(ctx, frame, place, message);
        }
    }));
    handle.set_frame(Rect {
        x: f64::from(position.x),
        y: f64::from(position.y),
        width: splash_quote::LOGO_WIDTH,
        height: splash_height,
    });
    handle.show();
    if animate {
        handle.animate(Animation::once(
            splash_quote::FADE_IN_MS as u32,
            Easing::Linear,
        ));
    }
    Ok(overlay)
}

fn paint_quote(ctx: &mut PaintCtx, frame: FrameInfo, place: QuotePlacement, message: &Message) {
    let regular = Font::ui(splash_quote::QUOTE_FONT_PX);
    let bold = regular.with_weight(800);
    let lines = splash_quote::wrap_message(message, place.wrap_width(), |text, is_bold| {
        let font = if is_bold { bold } else { regular };
        ctx.measure_text(text, font).width
    });
    if lines.is_empty() {
        return;
    }
    let line_height = f64::from(
        ctx.measure_text("Mg", regular)
            .height
            .max(ctx.measure_text("Mg", bold).height)
            .max(splash_quote::QUOTE_FONT_PX),
    );
    let content_width = lines
        .iter()
        .map(|line| {
            line.spans
                .iter()
                .map(|span| {
                    let font = if span.bold { bold } else { regular };
                    ctx.measure_text(&span.text, font).width
                })
                .sum::<f32>()
        })
        .fold(0.0f32, f32::max);
    let content_height = lines.len() as f64 * line_height;
    ctx.fill_rounded_rect(
        Rect {
            x: place.plate_left,
            y: place.plate_top,
            width: (f64::from(content_width) + place.pad_x * 2.0).min(place.plate_width),
            height: content_height + place.pad_y * 2.0,
        },
        8.0,
        Rgba::new(0, 0, 0, 170),
    );
    let (done, alpha) = splash_quote::reveal(frame.elapsed_ms, message.char_count());
    let text_left = place.text_left();
    let text_right = text_left + f64::from(place.wrap_width());
    for (index, line) in lines.iter().enumerate() {
        let y = place.text_top() + index as f64 * line_height;
        let mut x = text_left;
        for span in &line.spans {
            let font = if span.bold { bold } else { regular };
            let len = span.text.chars().count();
            let full = done.saturating_sub(span.start).min(len);
            if full > 0 {
                let prefix: String = span.text.chars().take(full).collect();
                let advance = f64::from(ctx.measure_text(&prefix, font).width);
                ctx.text(
                    &prefix,
                    font,
                    Rgba::WHITE,
                    Rect {
                        x,
                        y,
                        width: (text_right - x).max(1.0),
                        height: line_height,
                    },
                    Align::Left,
                );
                x += advance;
            }
            if done >= span.start && done < span.start + len && alpha > 0.0 {
                let ch: String = span.text.chars().skip(done - span.start).take(1).collect();
                ctx.text(
                    &ch,
                    font,
                    Rgba::WHITE.with_alpha(alpha),
                    Rect {
                        x,
                        y,
                        width: (text_right - x).max(1.0),
                        height: line_height,
                    },
                    Align::Left,
                );
            }
        }
    }
}
