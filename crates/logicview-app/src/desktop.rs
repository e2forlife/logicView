//! Native window that hosts the Axum UI.
//!
//! The window is the application. The page it loads is the loopback server
//! started in this process; nothing asks the user to open a browser.

#[cfg(any(not(windows), debug_assertions))]
use std::io::Write;
use std::net::SocketAddr;
use std::sync::mpsc;
use std::time::{Duration, Instant};

use tao::dpi::LogicalSize;
use tao::event::{Event, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoopBuilder};
use tao::window::{Icon, WindowBuilder};
use wry::WebViewBuilder;

/// Starts the local application services and opens the desktop window once they are ready.
pub fn open(addr: SocketAddr) -> Result<(), String> {
    let bound = start_server(addr)?;
    let origin = format!("http://{bound}");
    open_window(&format!("{origin}/"), &origin)
}

/// Starts the engine and UI on a background thread, waiting for an address or startup error.
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

/// Serves the UI and starts the local MCP attachment endpoint for the same engine.
async fn run_server(
    engine: logicview_engine::Engine,
    addr: SocketAddr,
    tx: mpsc::Sender<Result<SocketAddr, String>>,
) -> Result<(), String> {
    let listener = logicview_ui::bind(addr)
        .await
        .map_err(|err| err.to_string())?;
    let local = listener.local_addr().map_err(|err| err.to_string())?;
    tx.send(Ok(local))
        .map_err(|_| "LogicView closed before its window was ready".to_string())?;
    if let Err(err) = logicview_ui::serve_listener(engine, listener).await {
        tracing::error!("UI server stopped: {err}");
    }
    Ok(())
}

/// Loads the build-generated icon for the native application window.
fn window_icon() -> Option<Icon> {
    const PX: u32 = 256;
    let rgba = include_bytes!(concat!(env!("OUT_DIR"), "/window-icon.rgba"));
    Icon::from_rgba(rgba.to_vec(), PX, PX).ok()
}

/// Hosts the local UI in a native webview and keeps it alive until the window closes.
fn open_window(start_url: &str, origin: &str) -> Result<(), String> {
    enum UiEvent {
        PickDirectory(String),
        PickFile(String),
        SaveFile(String),
        Theme(String),
        Close,
        Drop(std::path::PathBuf, i32, i32),
    }
    let event_loop = EventLoopBuilder::<UiEvent>::with_user_event().build();
    let ipc_proxy = event_loop.create_proxy();
    let drop_proxy = event_loop.create_proxy();
    let mut builder = WindowBuilder::new()
        .with_title("LogicView")
        .with_visible(false)
        .with_inner_size(LogicalSize::new(1440.0, 900.0))
        .with_min_inner_size(LogicalSize::new(960.0, 640.0))
        .with_theme(preferred_window_theme(&logicview_config::load().theme));
    if let Some(icon) = window_icon() {
        builder = builder.with_window_icon(Some(icon));
    }
    let window = builder
        .build(&event_loop)
        .map_err(|err| format!("could not open the LogicView window: {err}"))?;

    let navigation_origin = origin.to_string();
    let builder = WebViewBuilder::new()
        .with_url(start_url)
        .with_background_color((0x0c, 0x10, 0x16, 0xff))
        .with_clipboard(true)
        .with_ipc_handler(move |request| {
            let body = request.body();
            if let Some(target) = body.strip_prefix("pick-directory:") {
                if matches!(
                    target,
                    "preferences-firmware"
                        | "preferences-scripts"
                        | "panel-export-dir"
                        | "dialog-export-dir"
                ) {
                    let _ = ipc_proxy.send_event(UiEvent::PickDirectory(target.to_string()));
                }
            } else if let Some(kind) = body.strip_prefix("pick-file:") {
                if matches!(kind, "load" | "import") {
                    let _ = ipc_proxy.send_event(UiEvent::PickFile(kind.to_string()));
                }
            } else if let Some(kind) = body.strip_prefix("save-file:") {
                if kind == "lvcap" {
                    let _ = ipc_proxy.send_event(UiEvent::SaveFile(kind.to_string()));
                }
            } else if let Some(theme) = body.strip_prefix("theme:") {
                if matches!(theme, "light" | "dark" | "system") {
                    let _ = ipc_proxy.send_event(UiEvent::Theme(theme.to_string()));
                }
            } else if body == "close" {
                let _ = ipc_proxy.send_event(UiEvent::Close);
            }
        })
        .with_drag_drop_handler(move |event| {
            if let wry::DragDropEvent::Drop { paths, position } = event {
                if let Some(path) = paths.into_iter().next() {
                    let _ = drop_proxy.send_event(UiEvent::Drop(path, position.0, position.1));
                }
            }
            true
        })
        .with_navigation_handler(move |url| allows_navigation(&navigation_origin, &url));

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

    let mut splash_builder = WindowBuilder::new()
        .with_title("LogicView")
        .with_inner_size(LogicalSize::new(780.0, 260.0))
        .with_decorations(false)
        .with_transparent(!cfg!(windows))
        .with_always_on_top(true)
        .with_resizable(false)
        .with_focusable(false)
        .with_visible(false);
    #[cfg(target_os = "windows")]
    {
        use tao::platform::windows::WindowBuilderExtWindows;
        splash_builder = splash_builder.with_skip_taskbar(true);
    }
    #[cfg(target_os = "linux")]
    {
        use tao::platform::unix::WindowBuilderExtUnix;
        splash_builder = splash_builder.with_skip_taskbar(true);
    }
    let splash = splash_builder
        .build(&event_loop)
        .map_err(|err| format!("could not open the startup splash: {err}"))?;
    if let Some(monitor) = splash.current_monitor() {
        let origin = monitor.position();
        let screen = monitor.size();
        let size = splash.outer_size();
        let x = origin.x + (i64::from(screen.width) - i64::from(size.width)).max(0) as i32 / 2;
        let y = origin.y + (i64::from(screen.height) - i64::from(size.height)).max(0) as i32 / 2;
        splash.set_outer_position(tao::dpi::PhysicalPosition::new(x, y));
    }
    #[cfg(not(windows))]
    let html = format!(
        r#"<!doctype html><html><head><style>
        html,body {{ margin:0; width:100%; height:100%; overflow:hidden; background:transparent; }}
        img {{ width:100%; height:100%; object-fit:contain; }}
        </style></head><body><img src="{origin}/assets/AppLogo.png" alt="LogicView"></body></html>"#
    );
    #[cfg(not(windows))]
    let splash_builder = WebViewBuilder::new()
        .with_html(html)
        .with_transparent(true)
        .with_background_color((0, 0, 0, 0));
    #[cfg(all(not(windows), not(target_os = "linux")))]
    let splash_view = splash_builder
        .build(&splash)
        .map_err(|err| format!("could not display the startup splash: {err}"))?;
    #[cfg(target_os = "linux")]
    let splash_view = {
        use tao::platform::unix::WindowExtUnix;
        use wry::WebViewBuilderExtUnix;
        let vbox = splash
            .default_vbox()
            .ok_or_else(|| "startup splash has no GTK container".to_string())?;
        splash_builder
            .build_gtk(vbox)
            .map_err(|err| format!("could not display the startup splash: {err}"))?
    };
    #[cfg(windows)]
    let splash_view = layered_splash::show(&splash)?;
    #[cfg(not(windows))]
    splash.set_visible(true);
    let deadline = Instant::now() + Duration::from_secs(5);
    let mut splash = Some((splash_view, splash));

    event_loop.run(move |event, _, control_flow| {
        *control_flow = if splash.is_some() { ControlFlow::WaitUntil(deadline) } else { ControlFlow::Wait };
        let _keep_webview = &webview;
        if splash.is_some() && Instant::now() >= deadline {
            splash.take();
            window.set_visible(true);
            window.set_focus();
            *control_flow = ControlFlow::Wait;
        }
        if let Event::UserEvent(ref request) = event {
            match request {
                UiEvent::PickDirectory(target) => {
                    if let Some(path) = rfd::FileDialog::new().set_title("Choose directory").pick_folder() {
                        let target = serde_json::to_string(target).unwrap_or_default();
                        let path = serde_json::to_string(&path.to_string_lossy()).unwrap_or_default();
                        let _ = webview.evaluate_script(&format!("window.logicviewDirectorySelected({target}, {path})"));
                    }
                }
                UiEvent::PickFile(kind) => {
                    let dialog = match kind.as_str() {
                        "load" => rfd::FileDialog::new()
                            .set_title("Load saved capture")
                            .add_filter("LogicView capture", &["lvcap"]),
                        _ => rfd::FileDialog::new()
                            .set_title("Import capture")
                            .add_filter("Capture", &["lvcap", "dsl"]),
                    };
                    let chosen = dialog.pick_file();
                    let kind_js = serde_json::to_string(kind).unwrap_or_else(|_| "\"\"".into());
                    let path_js = chosen
                        .as_ref()
                        .map(|path| {
                            serde_json::to_string(&path.to_string_lossy().to_string())
                                .unwrap_or_else(|_| "null".into())
                        })
                        .unwrap_or_else(|| "null".into());
                    let _ = webview.evaluate_script(&format!(
                        "if (window.logicviewFileSelected) window.logicviewFileSelected({kind_js}, {path_js})"
                    ));
                }
                UiEvent::SaveFile(kind) => {
                    let chosen = rfd::FileDialog::new()
                        .set_title("Save capture")
                        .set_file_name("capture.lvcap")
                        .add_filter("LogicView capture", &["lvcap"])
                        .save_file()
                        .map(|path| {
                            if path
                                .extension()
                                .is_some_and(|ext| ext.eq_ignore_ascii_case("lvcap"))
                            {
                                path
                            } else {
                                path.with_extension("lvcap")
                            }
                        });
                    let kind_js = serde_json::to_string(kind).unwrap_or_else(|_| "\"\"".into());
                    let path_js = chosen
                        .as_ref()
                        .map(|path| {
                            serde_json::to_string(&path.to_string_lossy().to_string())
                                .unwrap_or_else(|_| "null".into())
                        })
                        .unwrap_or_else(|| "null".into());
                    let _ = webview.evaluate_script(&format!(
                        "if (window.logicviewSaveSelected) window.logicviewSaveSelected({kind_js}, {path_js})"
                    ));
                }
                UiEvent::Theme(choice) => {
                    window.set_theme(preferred_window_theme(choice));
                }
                UiEvent::Close => {
                    *control_flow = ControlFlow::Exit;
                }
                UiEvent::Drop(path, x, y) => {
                    let path = serde_json::json!({"value": path.to_string_lossy(), "isDirectory": path.is_dir()});
                    let _ = webview.evaluate_script(&format!("window.logicviewNativeDrop({path}, {x}, {y})"));
                }
            }
        }
        if let Event::WindowEvent {
            window_id,
            event: WindowEvent::CloseRequested,
            ..
        } = event
        {
            if window_id == window.id() {
                *control_flow = ControlFlow::Exit;
            }
        }
    });
}

/// Displays a startup failure through logging and the platform's available user interface.
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

/// Maps a saved theme choice onto the native window caption.
///
/// `system` leaves the choice unset so the caption follows the operating system.
pub(crate) fn preferred_window_theme(choice: &str) -> Option<tao::window::Theme> {
    match choice {
        "light" => Some(tao::window::Theme::Light),
        "dark" => Some(tao::window::Theme::Dark),
        _ => None,
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
    //! Checks desktop navigation rules without starting a native window.

    use super::{allows_navigation, preferred_window_theme};

    #[test]
    fn window_caption_follows_the_saved_theme() {
        assert_eq!(preferred_window_theme("light"), Some(tao::window::Theme::Light));
        assert_eq!(preferred_window_theme("dark"), Some(tao::window::Theme::Dark));
        assert_eq!(preferred_window_theme("system"), None);
        assert_eq!(preferred_window_theme("other"), None);
    }

    /// Checks that the webview accepts application pages and downloads while rejecting external
    /// origins.
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

#[cfg(windows)]
#[path = "splash_windows.rs"]
mod layered_splash;
