//! Per-pixel-alpha Windows splash rendering without a WebView background.

use rightkit_overlay_win::{FrameInfo, OverlayConfig, OverlayWindow, PaintCtx, Rect};
use tao::window::Window;

/// Show the embedded PNG in a native layered window, preserving its alpha channel.
pub(super) fn show(reference: &Window) -> Result<OverlayWindow, String> {
    let image = image::load_from_memory(include_bytes!("../../logicview-ui/assets/AppLogo.png"))
        .map_err(|err| format!("could not read startup logo: {err}"))?
        .to_rgba8();
    let (width, height) = image.dimensions();
    let pixels = image.into_raw();
    let position = reference.outer_position()
        .map_err(|err| format!("could not place startup splash: {err}"))?;
    let overlay = OverlayWindow::create(OverlayConfig::passive("LogicViewSplash"))
        .map_err(|err| format!("could not create startup splash: {err}"))?;
    let handle = overlay.handle();
    handle.set_painter(Box::new(move |ctx: &mut PaintCtx, _: FrameInfo| {
        let size = ctx.logical_size();
        ctx.blit_rgba(&pixels, width, height, Rect {
            x: 0.0, y: 0.0, width: f64::from(size.width), height: f64::from(size.height),
        });
    }));
    handle.set_frame(Rect { x: f64::from(position.x), y: f64::from(position.y), width: 780.0, height: 260.0 });
    handle.show();
    Ok(overlay)
}
