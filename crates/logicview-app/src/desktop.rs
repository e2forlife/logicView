//! Native window that hosts the Axum UI.
//!
//! The window is the application. The page it loads is the loopback server
//! started in this process; nothing asks the user to open a browser.

#[cfg(any(not(windows), debug_assertions))]
use std::io::Write;
use std::net::SocketAddr;
use std::sync::mpsc;

use tao::dpi::LogicalSize;
use tao::event::{Event, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoop};
use tao::window::{Icon, WindowBuilder};
use wry::WebViewBuilder;

pub fn open(addr: SocketAddr) -> Result<(), String> {
    let bound = start_server(addr)?;
    let origin = format!("http://{bound}");
    open_window(&format!("{origin}/"), &origin)
}

fn start_server(addr: SocketAddr) -> Result<SocketAddr, String> {
    let (tx, rx) = mpsc::channel();
    let engine = logicview_engine::Engine::new();
    std::thread::Builder::new()
        .name("logicview-ui".to_string())
        .spawn(move || {
            let started = match tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .build()
            {
                Ok(runtime) => runtime.block_on(run_server(engine, addr, tx.clone())),
                Err(err) => Err(err.to_string()),
            };
            if let Err(err) = started {
                let _ = tx.send(Err(err));
            }
        })
        .map_err(|err| format!("could not start LogicView: {err}"))?;
    rx.recv()
        .map_err(|_| "LogicView stopped before its window was ready".to_string())?
}

async fn run_server(
    engine: logicview_engine::Engine,
    addr: SocketAddr,
    tx: mpsc::Sender<Result<SocketAddr, String>>,
) -> Result<(), String> {
    let listener = logicview_ui::bind(addr)
        .await
        .map_err(|err| err.to_string())?;
    let local = listener.local_addr().map_err(|err| err.to_string())?;
    let attached = engine.clone();
    let socket = logicview_mcp::default_socket_path();
    tokio::spawn(async move {
        if let Err(err) = logicview_mcp::serve_attach(attached, &socket).await {
            tracing::warn!("attach socket: {err}");
        }
    });
    tracing::info!("{}", logicview_mcp::attach_location());
    tx.send(Ok(local))
        .map_err(|_| "LogicView closed before its window was ready".to_string())?;
    if let Err(err) = logicview_ui::serve_listener(engine, listener).await {
        tracing::error!("UI server stopped: {err}");
    }
    Ok(())
}

fn window_icon() -> Option<Icon> {
    const PX: u32 = 256;
    let rgba = include_bytes!(concat!(env!("OUT_DIR"), "/window-icon.rgba"));
    Icon::from_rgba(rgba.to_vec(), PX, PX).ok()
}

fn open_window(start_url: &str, origin: &str) -> Result<(), String> {
    let event_loop = EventLoop::new();
    let mut builder = WindowBuilder::new()
        .with_title("LogicView")
        .with_inner_size(LogicalSize::new(1440.0, 900.0))
        .with_min_inner_size(LogicalSize::new(960.0, 640.0))
        .with_theme(Some(tao::window::Theme::Dark));
    if let Some(icon) = window_icon() {
        builder = builder.with_window_icon(Some(icon));
    }
    let window = builder
        .build(&event_loop)
        .map_err(|err| format!("could not open the LogicView window: {err}"))?;

    let origin = origin.to_string();
    let builder = WebViewBuilder::new()
        .with_url(start_url)
        .with_background_color((0x0c, 0x10, 0x16, 0xff))
        .with_clipboard(true)
        .with_navigation_handler(move |url| allows_navigation(&origin, &url));

    #[cfg(not(target_os = "linux"))]
    let webview = builder
        .build(&window)
        .map_err(|err| format!("could not open the LogicView window: {err}"))?;
    #[cfg(target_os = "linux")]
    let webview = {
        use tao::platform::unix::WindowExtUnix;
        use wry::WebViewBuilderExtUnix;
        let vbox = window.default_vbox().ok_or_else(|| {
            "could not open the LogicView window: the GTK window has no container".to_string()
        })?;
        builder
            .build_gtk(vbox)
            .map_err(|err| format!("could not open the LogicView window: {err}"))?
    };

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;
        let _keep_webview = &webview;
        if let Event::WindowEvent {
            event: WindowEvent::CloseRequested,
            ..
        } = event
        {
            *control_flow = ControlFlow::Exit;
        }
    });
}

pub fn report_error(message: &str) {
    tracing::error!("{message}");
    #[cfg(windows)]
    {
        let _choice = rfd::MessageDialog::new()
            .set_title("LogicView")
            .set_level(rfd::MessageLevel::Error)
            .set_description(message)
            .set_buttons(rfd::MessageButtons::Ok)
            .show();
    }
    #[cfg(any(not(windows), debug_assertions))]
    {
        let _ = writeln!(std::io::stderr(), "logicview: {message}");
    }
}

/// The window may follow links inside the app, blank pages, and download blobs.
/// Other destinations stay out of the window.
pub(crate) fn allows_navigation(origin: &str, url: &str) -> bool {
    let url = url.trim();
    if url == "about:blank" || url.starts_with("blob:") || url.starts_with("data:") {
        return true;
    }
    let Some(rest) = url.strip_prefix(origin) else {
        return false;
    };
    rest.is_empty() || rest.starts_with(['/', '?', '#'])
}

#[cfg(test)]
mod tests {
    use super::allows_navigation;

    #[test]
    fn navigation_stays_inside_the_window() {
        let origin = "http://127.0.0.1:4173";
        assert!(allows_navigation(origin, "http://127.0.0.1:4173/"));
        assert!(allows_navigation(
            origin,
            "http://127.0.0.1:4173/assets/app.js"
        ));
        assert!(allows_navigation(
            origin,
            "http://127.0.0.1:4173/api/export/csv?x=1"
        ));
        assert!(allows_navigation(origin, "blob:http://127.0.0.1:4173/uuid"));
        assert!(allows_navigation(origin, "data:text/plain,hi"));
        assert!(allows_navigation(origin, "about:blank"));
        assert!(!allows_navigation(origin, "https://example.com/"));
        assert!(!allows_navigation(origin, "http://127.0.0.1:41730/"));
        assert!(!allows_navigation(origin, "http://127.0.0.1:4173.example/"));
    }
}
