//! Localhost Axum shell.
//!
//! The page, stylesheet, and waveform client are served by this process.
//! Sample truth stays in the engine. Tile requests return either JSON (HTTP)
//! or the `LVT1` binary frame (WebSocket). The server refuses a non-loopback
//! bind.
//!
//! # Client boundary
//!
//! HTTP and WebSocket commands share `dispatch`, which delegates operations to
//! `logicview-engine`. The embedded HTML, CSS, and JavaScript live in `assets`;
//! this crate handles transport and does not own capture or measurement policy.
//!
//! When changing commands, keep the serialized `Command` representation and
//! browser requests aligned. Changes to binary tile frames must also agree
//! with the JavaScript reader. Session events prompt clients to refresh their
//! view; they do not replace the samples retained by the engine.

use std::collections::BTreeMap;
use std::convert::Infallible;
use std::net::SocketAddr;
use std::time::Duration;

use axum::body::Bytes;
use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{DefaultBodyLimit, Query, State};
use axum::http::{header, StatusCode};
use axum::response::sse::{Event, KeepAlive, Sse};
use axum::response::{Html, IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use logicview_capture::{DepthMode, RunPolicy, SessionConfig, TriggerKind};
use logicview_engine::{
    AnalogColumn, Column, Engine, EngineError, EngineEvent, PulseMetrics, StartMode,
};
use serde::Deserialize;
use serde_json::{json, Value};
use thiserror::Error;
use tokio_stream::wrappers::BroadcastStream;
use tokio_stream::StreamExt;

mod mcp_server;

const INDEX_HTML: &str = include_str!("../assets/index.html");
const APP_CSS: &str = include_str!("../assets/app.css");
const APP_JS: &str = include_str!("../assets/app.js");
const APP_LOGO: &[u8] = include_bytes!("../assets/AppLogo.png");
const EXPORT_LOGO: &[u8] = include_bytes!("../assets/ExportFileLogo.png");
const PREFS_LOGO: &[u8] = include_bytes!("../assets/PrefsLogo.png");
const SETTINGS_ICON: &str = include_str!("../assets/settings.svg");
const E2_LOGO: &[u8] = include_bytes!("../assets/E2logo.png");
const CONTRIBUTORS_TOML: &str = include_str!("../../../contrib.toml");

/// Shares the same engine across all HTTP and WebSocket handlers.
#[derive(Clone)]
struct AppState {
    engine: Engine,
    mcp: mcp_server::Control,
}

/// The local UI server could not bind or continue serving.
#[derive(Debug, Error)]
pub enum UiError {
    #[error(
        "refusing to bind {0}; LogicView listens on loopback unless a later build adds a token"
    )]
    NonLoopback(SocketAddr),
    #[error("{0}")]
    Io(#[from] std::io::Error),
}

/// Builds the application routes around a shared engine, including commands, events, and capture
/// files.
pub fn router(engine: Engine) -> Router {
    router_with_control(engine, mcp_server::Control::default())
}

fn router_with_control(engine: Engine, mcp: mcp_server::Control) -> Router {
    Router::new()
        .route("/", get(index))
        .route("/assets/app.css", get(css))
        .route("/assets/app.js", get(js))
        .route("/assets/settings.svg", get(settings_icon))
        .route("/assets/AppLogo.png", get(app_logo))
        .route("/assets/ExportFileLogo.png", get(export_logo))
        .route("/assets/PrefsLogo.png", get(prefs_logo))
        .route("/assets/E2logo.png", get(e2_logo))
        .route("/api/contributors", get(contributors_json))
        .route(
            "/api/preferences",
            get(get_preferences).post(save_preferences),
        )
        .route("/api/export-dir", post(save_export_dir))
        .route(
            "/api/mcp",
            get(mcp_server::status).post(mcp_server::configure),
        )
        .route("/api/health", get(health))
        .route("/api/command", post(command))
        .route("/api/events", get(events))
        .route("/api/import-path", post(import_path))
        .route("/api/export/lvcap", get(export_lvcap))
        .route("/api/export/dsl", get(export_dsl))
        .route("/api/export/csv", get(export_csv))
        .route("/api/export/xlsx", get(export_xlsx))
        .route("/api/export-to", post(export_to))
        .route("/api/save-as", post(save_as))
        .route(
            "/api/import",
            post(import_capture).layer(DefaultBodyLimit::max(64 * 1024 * 1024)),
        )
        .route("/ws", get(ws_upgrade))
        .with_state(AppState { engine, mcp })
}

/// Binds the UI server to a local address, rejecting non-loopback listeners.
pub async fn bind(addr: SocketAddr) -> Result<tokio::net::TcpListener, UiError> {
    if !addr.ip().is_loopback() {
        return Err(UiError::NonLoopback(addr));
    }
    Ok(tokio::net::TcpListener::bind(addr).await?)
}

/// Binds and runs the local UI server until the serving future ends.
pub async fn serve(engine: Engine, addr: SocketAddr) -> Result<(), UiError> {
    let listener = bind(addr).await?;
    serve_listener(engine, listener).await
}

/// Runs the UI on an existing listener.
///
/// Callers are responsible for supplying a loopback listener, normally obtained
/// through `bind`, because this entry point does not repeat that address check.
pub async fn serve_listener(
    engine: Engine,
    listener: tokio::net::TcpListener,
) -> Result<(), UiError> {
    let local = listener.local_addr()?;
    tracing::info!(%local, "LogicView UI listening");
    let control = mcp_server::Control::default();
    if let Err(err) = control.restore(engine.clone()).await {
        tracing::warn!("MCP server: {err}");
    }
    axum::serve(listener, router_with_control(engine, control)).await?;
    Ok(())
}

async fn get_preferences() -> Json<logicview_config::Preferences> {
    let mut prefs = logicview_config::load();
    if prefs.scripts_dir.is_empty() {
        prefs.scripts_dir = logicview_config::effective_scripts_dir(&prefs);
    }
    Json(prefs)
}

async fn save_preferences(
    Json(mut prefs): Json<logicview_config::Preferences>,
) -> Result<Json<logicview_config::Preferences>, (StatusCode, String)> {
    let current = logicview_config::load();
    prefs.mcp_enabled = current.mcp_enabled;
    prefs.mcp_port = current.mcp_port;
    prefs.export_dir = current.export_dir;
    logicview_config::save(&prefs).map_err(|err| (StatusCode::BAD_REQUEST, err))?;
    Ok(Json(prefs))
}

#[derive(Deserialize)]
struct ExportDirBody {
    directory: String,
}

/// Remembers the export folder without changing the other preferences.
async fn save_export_dir(
    Json(input): Json<ExportDirBody>,
) -> Result<Json<logicview_config::Preferences>, (StatusCode, String)> {
    let mut prefs = logicview_config::load();
    prefs.export_dir = input.directory;
    logicview_config::save(&prefs).map_err(|err| (StatusCode::BAD_REQUEST, err))?;
    Ok(Json(prefs))
}

/// Serves the embedded application shell without browser caching.
async fn index() -> impl IntoResponse {
    ([(header::CACHE_CONTROL, "no-store")], Html(INDEX_HTML))
}

/// Serves the embedded splash artwork to the desktop webview.
async fn app_logo() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], APP_LOGO)
}

/// Serves the export dialog artwork.
async fn export_logo() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], EXPORT_LOGO)
}

/// Serves the Preferences dialog header artwork.
async fn prefs_logo() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], PREFS_LOGO)
}

/// Serves the locally embedded Material Symbols settings icon.
async fn settings_icon() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/svg+xml")], SETTINGS_ICON)
}

/// Serves the embedded E2 artwork for the About dialog.
async fn e2_logo() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], E2_LOGO)
}

/// One person shown in the About dialog as `name -- contribution`.
#[derive(Clone, Debug, serde::Deserialize, serde::Serialize)]
struct Contributor {
    name: String,
    contribution: String,
}

#[derive(serde::Deserialize)]
struct ContributorFile {
    #[serde(default)]
    contributors: Vec<Contributor>,
}

/// Loads credits from an external file when one is present, otherwise the copy packaged with the app.
fn contributors() -> &'static [Contributor] {
    static LIST: std::sync::OnceLock<Vec<Contributor>> = std::sync::OnceLock::new();
    LIST.get_or_init(|| {
        let explicit = std::env::var_os("LOGICVIEW_CONTRIB").map(std::path::PathBuf::from);
        let candidates = explicit
            .into_iter()
            .chain([std::path::PathBuf::from("contrib.toml")])
            .chain(
                std::env::current_exe()
                    .ok()
                    .and_then(|path| path.parent().map(|dir| dir.join("contrib.toml"))),
            );
        for path in candidates {
            if let Ok(contents) = std::fs::read_to_string(&path) {
                match toml::from_str::<ContributorFile>(&contents) {
                    Ok(file) if !file.contributors.is_empty() => return file.contributors,
                    Ok(_) => eprintln!("{} contains no contributors", path.display()),
                    Err(err) => eprintln!("Invalid contributors {}: {err}", path.display()),
                }
            }
        }
        toml::from_str::<ContributorFile>(CONTRIBUTORS_TOML)
            .expect("bundled contributors are valid")
            .contributors
    })
}

/// Serves the About-dialog credits read from the packaged contributor list.
async fn contributors_json() -> impl IntoResponse {
    (
        [(header::CACHE_CONTROL, "no-store")],
        Json(contributors().to_vec()),
    )
}

/// Serves the embedded styles used by the waveform workspace.
async fn css() -> impl IntoResponse {
    (
        [
            (header::CONTENT_TYPE, "text/css; charset=utf-8"),
            (header::CACHE_CONTROL, "no-store"),
        ],
        APP_CSS,
    )
}

/// Serves the embedded browser client that renders waveforms and sends engine commands.
async fn js() -> impl IntoResponse {
    (
        [
            (header::CONTENT_TYPE, "text/javascript; charset=utf-8"),
            (header::CACHE_CONTROL, "no-store"),
        ],
        APP_JS,
    )
}

/// Reports service availability and the advertised build capabilities.
async fn health() -> Json<Value> {
    Json(json!({
        "ok": true,
        "service": "logicview",
        "phases": ["0", "1", "2", "3", "4", "5", "6"],
        "device": "demo"
    }))
}

/// Handles a JSON command through the same engine dispatch used by WebSocket clients.
async fn command(
    State(app): State<AppState>,
    Json(cmd): Json<Command>,
) -> Result<Json<Value>, ApiError> {
    let data = dispatch(&app.engine, cmd).await?;
    Ok(Json(json!({"ok": true, "data": data})))
}

/// Streams live engine notifications to HTTP clients using server-sent events.
async fn events(
    State(app): State<AppState>,
) -> Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>> {
    let rx = app.engine.subscribe();
    let stream = BroadcastStream::new(rx).filter_map(|item| match item {
        Ok(event) => serde_json::to_string(&event)
            .ok()
            .map(|data| Ok(Event::default().event(event_name(&event)).data(data))),
        Err(_) => None,
    });
    Sse::new(stream).keep_alive(KeepAlive::new().interval(Duration::from_secs(15)))
}

/// Chooses the event-stream name corresponding to a session notification.
fn event_name(event: &EngineEvent) -> &'static str {
    match event {
        EngineEvent::Phase { .. } => "phase",
        EngineEvent::Appended { .. } => "appended",
        EngineEvent::Stopped { .. } => "stopped",
        EngineEvent::Error { .. } => "error",
    }
}

/// Carries the uploaded filename used to recognize a capture container.
#[derive(Deserialize)]
struct ImportQuery {
    #[serde(default)]
    name: String,
}

#[derive(Deserialize)]
struct ImportPath {
    path: std::path::PathBuf,
}
async fn import_path(
    State(app): State<AppState>,
    Json(input): Json<ImportPath>,
) -> Result<Json<Value>, (StatusCode, String)> {
    let name = input
        .path
        .file_name()
        .and_then(|s| s.to_str())
        .ok_or((StatusCode::BAD_REQUEST, "Invalid file name".into()))?;
    if !["lvcap", "dsl"].iter().any(|ext| {
        input
            .path
            .extension()
            .is_some_and(|value| value.eq_ignore_ascii_case(ext))
    }) {
        return Err((
            StatusCode::BAD_REQUEST,
            "Expected a .lvcap or .dsl file".into(),
        ));
    }
    let metadata =
        std::fs::metadata(&input.path).map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;
    if !metadata.is_file() || metadata.len() > 64 * 1024 * 1024 {
        return Err((
            StatusCode::BAD_REQUEST,
            "Invalid or oversized capture file".into(),
        ));
    }
    let bytes = std::fs::read(&input.path).map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;
    let result = app
        .engine
        .import_capture(None, name, &bytes)
        .await
        .map_err(|e| (StatusCode::BAD_REQUEST, e.to_string()))?;
    Ok(Json(json!({"ok": true, "data": result})))
}

/// Loads an uploaded archive into the selected session, using its filename to choose the format.
async fn import_capture(
    State(app): State<AppState>,
    Query(query): Query<ImportQuery>,
    body: Bytes,
) -> Result<Json<Value>, ApiError> {
    let status = app.engine.import_capture(None, &query.name, &body).await?;
    Ok(Json(json!({"ok": true, "data": status})))
}

/// Downloads the selected session as a native capture archive, rejecting an empty record.
async fn export_lvcap(State(app): State<AppState>) -> Result<Response, ApiError> {
    let status = app.engine.status(None).await?;
    if status.sample_count == 0 {
        let body = Json(json!({"ok": false, "error": "nothing captured yet"}));
        return Ok((StatusCode::BAD_REQUEST, body).into_response());
    }
    let bytes = app.engine.export_zip(None).await?;
    Ok((
        [
            (header::CONTENT_TYPE, "application/zip"),
            (
                header::CONTENT_DISPOSITION,
                "attachment; filename=\"capture.lvcap\"",
            ),
        ],
        bytes,
    )
        .into_response())
}

/// Downloads the selected session in the supported DSL archive layout.
async fn export_dsl(State(app): State<AppState>) -> Result<Response, ApiError> {
    let bytes = app.engine.export_dsl(None).await?;
    Ok((
        [
            (header::CONTENT_TYPE, "application/zip"),
            (
                header::CONTENT_DISPOSITION,
                "attachment; filename=\"capture.dsl\"",
            ),
        ],
        bytes,
    )
        .into_response())
}

/// Downloads individual capture samples as a CSV table.
async fn export_csv(State(app): State<AppState>) -> Result<Response, ApiError> {
    let file = app.engine.export_samples_csv(None).await?;
    Ok(sample_file_response(
        file.body,
        "text/csv; charset=utf-8",
        "attachment; filename=\"capture.csv\"",
        file.rows,
        file.total,
    ))
}

/// Folder, file name, and format for a capture written by the export form.
#[derive(Deserialize)]
struct ExportTo {
    kind: String,
    directory: std::path::PathBuf,
    filename: String,
    #[serde(default)]
    query: Option<String>,
}

/// Builds the requested export and saves it under the chosen folder.
async fn export_to(
    State(app): State<AppState>,
    Json(input): Json<ExportTo>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    let meta = std::fs::metadata(&input.directory).map_err(|err| export_error(err.to_string()))?;
    if !meta.is_dir() {
        return Err(export_error("Choose an existing folder"));
    }
    let (ext, bytes, rows, total) = match input.kind.as_str() {
        "csv" => {
            let file = app
                .engine
                .export_samples_csv(None)
                .await
                .map_err(|err| export_error(err.to_string()))?;
            (".csv", file.body, Some(file.rows), Some(file.total))
        }
        "xlsx" => {
            let file = app
                .engine
                .export_samples_xlsx(None)
                .await
                .map_err(|err| export_error(err.to_string()))?;
            (".xlsx", file.body, Some(file.rows), Some(file.total))
        }
        "lvcap" => {
            let status = app
                .engine
                .status(None)
                .await
                .map_err(|err| export_error(err.to_string()))?;
            if status.sample_count == 0 {
                return Err(export_error("nothing captured yet"));
            }
            let bytes = app
                .engine
                .export_zip(None)
                .await
                .map_err(|err| export_error(err.to_string()))?;
            (".lvcap", bytes, None, None)
        }
        "dsl" => {
            let bytes = app
                .engine
                .export_dsl(None)
                .await
                .map_err(|err| export_error(err.to_string()))?;
            (".dsl", bytes, None, None)
        }
        "annotations" => {
            let text = app
                .engine
                .export_annotations(None, "csv", input.query.as_deref())
                .await
                .map_err(|err| export_error(err.to_string()))?;
            (".csv", text.into_bytes(), None, None)
        }
        _ => return Err(export_error("Unknown export type")),
    };
    let name = safe_export_name(&input.filename, ext)?;
    let path = input.directory.join(&name);
    if path.file_name().and_then(|value| value.to_str()) != Some(name.as_str()) {
        return Err(export_error("Enter a file name without a folder"));
    }
    std::fs::write(&path, bytes).map_err(|err| export_error(err.to_string()))?;
    Ok(Json(json!({
        "ok": true,
        "path": path.to_string_lossy(),
        "rows": rows,
        "total": total,
    })))
}

/// Full path chosen in the system save dialog.
#[derive(Deserialize)]
struct SaveAs {
    path: std::path::PathBuf,
}

/// Writes the current capture to the file chosen in the system save dialog.
async fn save_as(
    State(app): State<AppState>,
    Json(input): Json<SaveAs>,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    if !input.path.is_absolute() {
        return Err(export_error("Choose a file"));
    }
    let path = if input
        .path
        .extension()
        .is_some_and(|ext| ext.eq_ignore_ascii_case("lvcap"))
    {
        input.path
    } else {
        input.path.with_extension("lvcap")
    };
    let parent = path.parent().filter(|dir| dir.is_dir()).ok_or_else(|| {
        export_error("Choose a folder that exists")
    })?;
    if path.file_name().is_none() || parent.as_os_str().is_empty() {
        return Err(export_error("Choose a file"));
    }
    if path.exists() && !path.is_file() {
        return Err(export_error("Choose a file"));
    }
    let status = app
        .engine
        .status(None)
        .await
        .map_err(|err| export_error(err.to_string()))?;
    if status.sample_count == 0 {
        return Err(export_error("nothing captured yet"));
    }
    let bytes = app
        .engine
        .export_zip(None)
        .await
        .map_err(|err| export_error(err.to_string()))?;
    std::fs::write(&path, bytes).map_err(|err| export_error(err.to_string()))?;
    Ok(Json(json!({
        "ok": true,
        "path": path.to_string_lossy(),
    })))
}

/// Rejects a file name that would escape the chosen folder, and adds the format extension.
fn safe_export_name(raw: &str, ext: &str) -> Result<String, (StatusCode, Json<Value>)> {
    let trimmed = raw.trim();
    if trimmed.is_empty()
        || trimmed == "."
        || trimmed == ".."
        || trimmed.contains(['/', '\\', '\0'])
    {
        return Err(export_error("Enter a file name without a folder"));
    }
    if trimmed.to_ascii_lowercase().ends_with(ext) {
        Ok(trimmed.to_string())
    } else {
        Ok(format!("{trimmed}{ext}"))
    }
}

/// Reports an export problem as JSON the page can show in the status line.
fn export_error(message: impl Into<String>) -> (StatusCode, Json<Value>) {
    (
        StatusCode::BAD_REQUEST,
        Json(json!({"ok": false, "error": message.into()})),
    )
}

/// Downloads individual capture samples as an Excel workbook.
async fn export_xlsx(State(app): State<AppState>) -> Result<Response, ApiError> {
    let file = app.engine.export_samples_xlsx(None).await?;
    Ok(sample_file_response(
        file.body,
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "attachment; filename=\"capture.xlsx\"",
        file.rows,
        file.total,
    ))
}

/// Adds download metadata and exported row counts so the client can detect table truncation.
fn sample_file_response(
    body: Vec<u8>,
    content_type: &'static str,
    disposition: &'static str,
    rows: u64,
    total: u64,
) -> Response {
    let mut response = body.into_response();
    let headers = response.headers_mut();
    headers.insert(header::CONTENT_TYPE, content_type.parse().unwrap());
    headers.insert(header::CONTENT_DISPOSITION, disposition.parse().unwrap());
    headers.insert(
        header::HeaderName::from_static("x-logicview-rows"),
        rows.to_string().parse().unwrap(),
    );
    headers.insert(
        header::HeaderName::from_static("x-logicview-total"),
        total.to_string().parse().unwrap(),
    );
    response
}

/// Upgrades the browser connection for binary waveform tiles and live command traffic.
async fn ws_upgrade(ws: WebSocketUpgrade, State(app): State<AppState>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, app.engine))
}

/// Multiplexes browser commands and engine notifications over one WebSocket connection.
async fn handle_socket(mut socket: WebSocket, engine: Engine) {
    let mut events = engine.subscribe();
    loop {
        tokio::select! {
            incoming = socket.recv() => {
                match incoming {
                    Some(Ok(Message::Text(text))) => {
                        if let Ok(cmd) = serde_json::from_str::<Command>(&text) {
                            if let Err(err) = reply_socket(&mut socket, &engine, cmd).await {
                                tracing::debug!("websocket reply failed: {err}");
                                break;
                            }
                        }
                    }
                    Some(Ok(Message::Ping(payload))) => {
                        if socket.send(Message::Pong(payload)).await.is_err() {
                            break;
                        }
                    }
                    Some(Ok(Message::Close(_))) | None | Some(Err(_)) => break,
                    _ => {}
                }
            }
            ev = events.recv() => {
                match ev {
                    Ok(event) => {
                        let text = match serde_json::to_string(&event) {
                            Ok(text) => text,
                            Err(_) => continue,
                        };
                        if socket.send(Message::Text(text)).await.is_err() {
                            break;
                        }
                    }
                    Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => continue,
                    Err(tokio::sync::broadcast::error::RecvError::Closed) => break,
                }
            }
        }
    }
}

/// Returns binary frames for waveform tiles and JSON responses for other WebSocket commands.
async fn reply_socket(
    socket: &mut WebSocket,
    engine: &Engine,
    cmd: Command,
) -> Result<(), axum::Error> {
    if let Command::Tile {
        session,
        channel,
        start,
        columns,
        samples_per_pixel,
        kind,
        req,
    } = cmd
    {
        let frame = match tile_frame(
            engine,
            TileQuery {
                session: session.as_deref(),
                channel,
                start,
                columns,
                spp: samples_per_pixel,
                kind: &kind,
                req,
            },
        )
        .await
        {
            Ok(frame) => frame,
            Err(err) => {
                let text = serde_json::to_string(&json!({"ok": false, "error": err.0.to_string()}))
                    .unwrap_or_default();
                return socket.send(Message::Text(text)).await;
            }
        };
        socket.send(Message::Binary(frame)).await
    } else {
        let payload = match dispatch(engine, cmd).await {
            Ok(data) => json!({"ok": true, "data": data}),
            Err(err) => json!({"ok": false, "error": err.0.to_string()}),
        };
        let text = serde_json::to_string(&payload).unwrap_or_else(|_| "{\"ok\":false}".to_string());
        socket.send(Message::Text(text)).await
    }
}

/// Translates browser commands into shared engine operations and client-facing JSON results.
async fn dispatch(engine: &Engine, cmd: Command) -> Result<Value, ApiError> {
    match cmd {
        Command::ListDevices => Ok(json!(engine.list_devices().await)),
        Command::ListProfiles => Ok(json!(engine.list_profiles().await)),
        Command::Connect { id } => Ok(json!(engine.connect(&id).await?)),
        Command::AttachDevice { session, id } => {
            Ok(json!(engine.attach_device(session.as_deref(), &id).await?))
        }
        Command::DetachDevice { session, id } => {
            Ok(json!(engine.detach_device(session.as_deref(), &id).await?))
        }
        Command::ListSessions => {
            let (sessions, active) = engine.list_sessions().await;
            Ok(json!({"sessions": sessions, "active": active}))
        }
        Command::CreateSession { name } => Ok(json!(engine.create_session(name).await?)),
        Command::SelectSession { id } => {
            engine.select_session(&id).await?;
            Ok(json!({"id": id}))
        }
        Command::Configure {
            session,
            sample_rate_hz,
            duration_ms,
            duration_ns,
            realtime,
            trigger_enabled,
            trigger_percent,
            depth,
            run,
            repeat_interval_ms,
            rle,
            threshold_volts,
            one_sample_filter,
            external_clock,
            clock_falling,
            discard_on_stop,
            channel_enable,
            trigger_channel,
            trigger_kind,
            trigger_steps,
        } => {
            engine
                .configure(
                    session.as_deref(),
                    SessionConfig {
                        sample_rate_hz,
                        duration_ms,
                        duration_ns,
                        realtime,
                        trigger_enabled,
                        trigger_percent,
                        depth: if depth == "stream" {
                            DepthMode::Stream
                        } else {
                            DepthMode::Buffer
                        },
                        run: match run.as_str() {
                            "repeat" => RunPolicy::Repeat,
                            "loop" => RunPolicy::Loop,
                            _ => RunPolicy::Single,
                        },
                        repeat_interval_ms,
                        rle,
                        threshold_volts,
                        one_sample_filter,
                        external_clock,
                        clock_falling,
                        discard_on_stop,
                        channel_enable,
                        trigger_channel,
                        trigger_kind: match trigger_kind.as_str() {
                            "falling" => TriggerKind::Falling,
                            "any" | "either" => TriggerKind::Any,
                            "high" => TriggerKind::High,
                            "low" => TriggerKind::Low,
                            _ => TriggerKind::Rising,
                        },
                        trigger_steps: trigger_steps
                            .into_iter()
                            .map(|step| logicview_capture::TriggerStep {
                                channel: step.channel,
                                rising: step.rising,
                            })
                            .collect(),
                    },
                )
                .await?;
            Ok(json!(engine.status(session.as_deref()).await?))
        }
        Command::Start { session, instant } => {
            let mode = if instant {
                StartMode::Instant
            } else {
                StartMode::Normal
            };
            Ok(json!(engine.start(session.as_deref(), mode).await?))
        }
        Command::Stop { session } => Ok(json!(engine.stop(session.as_deref()).await?)),
        Command::Status { session } => Ok(json!(engine.status(session.as_deref()).await?)),
        Command::Measure {
            session,
            channel,
            sample,
        } => {
            let metrics = engine.measure(session.as_deref(), channel, sample).await?;
            Ok(metrics_json(metrics))
        }
        Command::SearchEdge {
            session,
            channel,
            from,
            rising,
            forward,
        } => {
            let edge = engine
                .search_edge(session.as_deref(), channel, from, rising, forward)
                .await?;
            Ok(json!({"sample": edge}))
        }
        Command::NearestEdge {
            session,
            channel,
            sample,
        } => {
            let edge = engine
                .nearest_edge(session.as_deref(), channel, sample)
                .await?;
            Ok(json!({"sample": edge}))
        }
        Command::SearchPattern {
            session,
            channel,
            from,
            pattern,
            forward,
        } => {
            let bits = parse_pattern(&pattern);
            let sample = engine
                .search_pattern(session.as_deref(), channel, from, &bits, forward)
                .await?;
            Ok(json!({"sample": sample}))
        }
        Command::SetCursor {
            session,
            which,
            sample,
        } => {
            let cursors = engine.set_cursor(session.as_deref(), which, sample).await?;
            Ok(json!({"a": cursors[0], "b": cursors[1]}))
        }
        Command::CursorSpan { session, channel } => {
            let span = engine.cursor_span(session.as_deref(), channel).await?;
            Ok(json!({
                "samples": span.samples,
                "seconds": span.seconds,
                "edges": span.edges,
            }))
        }
        Command::SaveMeasurement {
            session,
            channel,
            sample,
        } => Ok(json!(
            engine
                .save_measurement(session.as_deref(), channel, sample)
                .await?
        )),
        Command::ListMeasurements { session } => {
            Ok(json!(engine.measurements(session.as_deref()).await?))
        }
        Command::DecoderCatalog => Ok(json!(engine.decoder_catalog().await)),
        Command::ListDecoders { session } => {
            Ok(json!(engine.list_decoders(session.as_deref()).await?))
        }
        Command::AddDecoder {
            session,
            protocol,
            channels,
            options,
            stack_on,
            region_start,
            region_end,
        } => {
            let region = match (region_start, region_end) {
                (Some(start), Some(end)) => Some((start, end)),
                _ => None,
            };
            Ok(json!(
                engine
                    .add_decoder(
                        session.as_deref(),
                        &protocol,
                        &channels,
                        &options,
                        region,
                        stack_on.as_deref(),
                    )
                    .await?
            ))
        }
        Command::RemoveDecoder { session, id } => {
            engine.remove_decoder(session.as_deref(), &id).await?;
            Ok(json!({"removed": id}))
        }
        Command::UpdateDecoder {
            session,
            id,
            channels,
            options,
            stack_on,
        } => Ok(json!(
            engine
                .update_decoder(
                    session.as_deref(),
                    &id,
                    &channels,
                    &options,
                    stack_on.as_deref(),
                )
                .await?
        )),
        Command::ReadAnnotations {
            session,
            decoder,
            query,
            start,
            end,
            offset,
            limit,
        } => Ok(json!(
            engine
                .read_annotations(
                    session.as_deref(),
                    decoder.as_deref(),
                    query.as_deref(),
                    start,
                    end,
                    offset.unwrap_or(0),
                    limit.unwrap_or(300),
                )
                .await?
        )),
        Command::ExportAnnotations {
            session,
            format,
            query,
        } => Ok(json!(
            engine
                .export_annotations(session.as_deref(), &format, query.as_deref())
                .await?
        )),
        Command::Tile {
            session,
            channel,
            start,
            columns,
            samples_per_pixel,
            kind,
            req,
        } => {
            check_tile(columns, samples_per_pixel)?;
            if kind == "analog" {
                let cols = engine
                    .tile_analog(session.as_deref(), start, columns, samples_per_pixel)
                    .await?;
                Ok(json!({
                    "req": req,
                    "kind": "analog",
                    "channel": channel,
                    "columns": cols.iter().map(analog_json).collect::<Vec<_>>()
                }))
            } else {
                let cols = engine
                    .tile(
                        session.as_deref(),
                        channel,
                        start,
                        columns,
                        samples_per_pixel,
                    )
                    .await?;
                Ok(json!({
                    "req": req,
                    "kind": "logic",
                    "channel": channel,
                    "columns": cols.iter().map(column_json).collect::<Vec<_>>()
                }))
            }
        }
    }
}

/// Bounds viewport requests before allocating or querying waveform columns.
fn check_tile(columns: usize, spp: f64) -> Result<(), ApiError> {
    if columns == 0 || columns > 8192 || !spp.is_finite() || spp <= 0.0 || spp > 1.0e12 {
        return Err(ApiError(EngineError::Capture(
            logicview_capture::CaptureError::Proto("tile request is out of range".into()),
        )));
    }
    Ok(())
}

/// Identifies a viewport, waveform lane, and request for binary tile rendering.
struct TileQuery<'a> {
    session: Option<&'a str>,
    channel: usize,
    start: f64,
    columns: usize,
    spp: f64,
    kind: &'a str,
    req: u32,
}

/// Queries the requested waveform lane and encodes a response tagged with the browser request
/// identifier.
async fn tile_frame(engine: &Engine, query: TileQuery<'_>) -> Result<Vec<u8>, ApiError> {
    check_tile(query.columns, query.spp)?;
    if query.kind == "analog" {
        let cols = engine
            .tile_analog(query.session, query.start, query.columns, query.spp)
            .await?;
        Ok(encode_analog_frame(
            query.req,
            query.channel as u16,
            query.start,
            query.spp,
            &cols,
        ))
    } else {
        let cols = engine
            .tile(
                query.session,
                query.channel,
                query.start,
                query.columns,
                query.spp,
            )
            .await?;
        Ok(encode_logic_frame(
            query.req,
            query.channel as u16,
            query.start,
            query.spp,
            &cols,
        ))
    }
}

/// Binary tile frame.
///
/// ```text
/// 0..4   b"LVT1"
/// 4      version = 1
/// 5      kind (1 logic, 2 analog)
/// 6..8   channel u16 le
/// 8..12  req u32 le
/// 12..16 column count u32 le
/// 16..24 start f64 le
/// 24..32 samples per pixel f64 le
/// 32..   logic: first, last, toggled, edges, valid (u8; edges saturated)
///        analog: min f32, max f32 (NaN when the column is past the capture)
///        `valid` is 0 when the column starts after the last stored sample.
/// ```
pub fn encode_logic_frame(
    req: u32,
    channel: u16,
    start: f64,
    spp: f64,
    columns: &[Column],
) -> Vec<u8> {
    let mut out = Vec::with_capacity(32 + columns.len() * 4);
    push_header(&mut out, 1, channel, req, columns.len(), start, spp);
    for column in columns {
        out.push(u8::from(column.first));
        out.push(u8::from(column.last));
        out.push(u8::from(column.toggled));
        out.push(u8::try_from(column.edges).unwrap_or(255));
        out.push(u8::from(column.valid));
    }
    out
}

/// Encodes an analog waveform tile using the shared binary frame header.
///
/// Invalid columns carry NaN bounds so the client can leave empty time blank.
pub fn encode_analog_frame(
    req: u32,
    channel: u16,
    start: f64,
    spp: f64,
    columns: &[AnalogColumn],
) -> Vec<u8> {
    let mut out = Vec::with_capacity(32 + columns.len() * 8);
    push_header(&mut out, 2, channel, req, columns.len(), start, spp);
    for column in columns {
        let (min, max) = if column.valid {
            (column.min, column.max)
        } else {
            (f32::NAN, f32::NAN)
        };
        out.extend_from_slice(&min.to_le_bytes());
        out.extend_from_slice(&max.to_le_bytes());
    }
    out
}

/// Writes the common tile metadata needed to associate a binary frame with its viewport request.
fn push_header(
    out: &mut Vec<u8>,
    kind: u8,
    channel: u16,
    req: u32,
    columns: usize,
    start: f64,
    spp: f64,
) {
    out.extend_from_slice(b"LVT1");
    out.push(1);
    out.push(kind);
    out.extend_from_slice(&channel.to_le_bytes());
    out.extend_from_slice(&req.to_le_bytes());
    out.extend_from_slice(&(columns as u32).to_le_bytes());
    out.extend_from_slice(&start.to_le_bytes());
    out.extend_from_slice(&spp.to_le_bytes());
}

/// Serializes a digital drawing column while preserving whether it contains real samples.
fn column_json(column: &Column) -> Value {
    json!({
        "first": column.first,
        "last": column.last,
        "toggled": column.toggled,
        "edges": column.edges,
        "valid": column.valid,
    })
}

/// Serializes an analog drawing envelope while preserving whether it contains real samples.
fn analog_json(column: &AnalogColumn) -> Value {
    json!({
        "min": column.min,
        "max": column.max,
        "valid": column.valid,
    })
}

/// Exposes pulse measurements and available cycle metrics to the browser.
fn metrics_json(metrics: PulseMetrics) -> Value {
    json!({
        "sample": metrics.sample,
        "level_high": metrics.level_high,
        "pulse_start": metrics.pulse_start,
        "pulse_end": metrics.pulse_end,
        "period_start": metrics.period_start,
        "period_end": metrics.period_end,
        "pulse_width_samples": metrics.pulse_width_samples,
        "period_samples": metrics.period_samples,
        "high_samples": metrics.high_samples,
        "width_secs": metrics.width_secs,
        "period_secs": metrics.period_secs,
        "frequency_hz": metrics.frequency_hz,
        "duty": metrics.duty,
    })
}

/// Wraps an engine failure for the common HTTP error response.
struct ApiError(EngineError);

impl From<EngineError> for ApiError {
    /// Adapts an engine failure to the UI error response path.
    fn from(err: EngineError) -> Self {
        Self(err)
    }
}

impl IntoResponse for ApiError {
    /// Returns an engine command failure as a JSON client error.
    fn into_response(self) -> Response {
        let body = Json(json!({"ok": false, "error": self.0.to_string()}));
        (StatusCode::BAD_REQUEST, body).into_response()
    }
}

/// Browser representation of one edge in an ordered trigger.
#[derive(Deserialize)]
struct TriggerStepCmd {
    channel: u8,
    #[serde(default = "default_true")]
    rising: bool,
}

/// Tagged browser command contract shared by the HTTP and WebSocket transports.
#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
enum Command {
    ListDevices,
    ListProfiles,
    Connect {
        id: String,
    },
    AttachDevice {
        session: Option<String>,
        id: String,
    },
    DetachDevice {
        session: Option<String>,
        id: String,
    },
    ListSessions,
    CreateSession {
        name: Option<String>,
    },
    SelectSession {
        id: String,
    },
    Configure {
        session: Option<String>,
        sample_rate_hz: u64,
        duration_ms: u64,
        #[serde(default)]
        duration_ns: u64,
        #[serde(default)]
        realtime: bool,
        #[serde(default)]
        trigger_enabled: bool,
        #[serde(default = "default_percent")]
        trigger_percent: f64,
        #[serde(default)]
        depth: String,
        #[serde(default)]
        run: String,
        #[serde(default)]
        repeat_interval_ms: u64,
        #[serde(default)]
        rle: bool,
        #[serde(default = "default_threshold")]
        threshold_volts: f64,
        #[serde(default)]
        one_sample_filter: bool,
        #[serde(default)]
        external_clock: bool,
        #[serde(default)]
        clock_falling: bool,
        #[serde(default)]
        discard_on_stop: bool,
        #[serde(default)]
        channel_enable: u64,
        #[serde(default)]
        trigger_channel: u8,
        #[serde(default)]
        trigger_kind: String,
        #[serde(default)]
        trigger_steps: Vec<TriggerStepCmd>,
    },
    SearchPattern {
        session: Option<String>,
        channel: usize,
        from: u64,
        pattern: String,
        #[serde(default = "default_true")]
        forward: bool,
    },
    SetCursor {
        session: Option<String>,
        which: usize,
        sample: Option<u64>,
    },
    CursorSpan {
        session: Option<String>,
        channel: usize,
    },
    SaveMeasurement {
        session: Option<String>,
        channel: usize,
        sample: u64,
    },
    ListMeasurements {
        session: Option<String>,
    },
    DecoderCatalog,
    ListDecoders {
        session: Option<String>,
    },
    AddDecoder {
        session: Option<String>,
        protocol: String,
        #[serde(default)]
        channels: BTreeMap<String, String>,
        #[serde(default)]
        options: BTreeMap<String, String>,
        #[serde(default)]
        stack_on: Option<String>,
        #[serde(default)]
        region_start: Option<u64>,
        #[serde(default)]
        region_end: Option<u64>,
    },
    RemoveDecoder {
        session: Option<String>,
        id: String,
    },
    UpdateDecoder {
        session: Option<String>,
        id: String,
        #[serde(default)]
        channels: BTreeMap<String, String>,
        #[serde(default)]
        options: BTreeMap<String, String>,
        #[serde(default)]
        stack_on: Option<String>,
    },
    ReadAnnotations {
        session: Option<String>,
        #[serde(default)]
        decoder: Option<String>,
        #[serde(default)]
        query: Option<String>,
        #[serde(default)]
        start: Option<u64>,
        #[serde(default)]
        end: Option<u64>,
        #[serde(default)]
        offset: Option<usize>,
        #[serde(default)]
        limit: Option<usize>,
    },
    ExportAnnotations {
        session: Option<String>,
        #[serde(default = "default_csv")]
        format: String,
        #[serde(default)]
        query: Option<String>,
    },
    Start {
        session: Option<String>,
        #[serde(default)]
        instant: bool,
    },
    Stop {
        session: Option<String>,
    },
    Status {
        session: Option<String>,
    },
    Measure {
        session: Option<String>,
        channel: usize,
        sample: u64,
    },
    SearchEdge {
        session: Option<String>,
        channel: usize,
        from: u64,
        #[serde(default = "default_true")]
        rising: bool,
        #[serde(default = "default_true")]
        forward: bool,
    },
    NearestEdge {
        session: Option<String>,
        channel: usize,
        sample: u64,
    },
    Tile {
        session: Option<String>,
        channel: usize,
        start: f64,
        columns: usize,
        samples_per_pixel: f64,
        #[serde(default)]
        kind: String,
        #[serde(default)]
        req: u32,
    },
}

/// Provides the default pre-trigger placement for omitted browser settings.
fn default_percent() -> f64 {
    10.0
}

/// Provides the default input threshold for omitted browser settings.
fn default_threshold() -> f64 {
    1.6
}

/// Supplies enabled defaults for direction and edge options in browser commands.
fn default_true() -> bool {
    true
}

/// Selects CSV when a browser annotation export does not specify a format.
fn default_csv() -> String {
    "csv".into()
}

/// Interprets a browser search pattern as logic levels with wildcard positions.
fn parse_pattern(text: &str) -> Vec<Option<bool>> {
    text.chars()
        .filter(|ch| !ch.is_whitespace())
        .map(|ch| match ch {
            '1' | 'H' | 'h' => Some(true),
            '0' | 'L' | 'l' => Some(false),
            _ => None,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    //! Exercises the browser command contract, waveform transport, and capture downloads.

    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use http_body_util::BodyExt;
    use logicview_engine::Column;
    use tower::ServiceExt;

    /// Checks the binary waveform contract expected by the browser client.
    #[test]
    fn logic_tile_frame_matches_the_documented_layout() {
        let frame = encode_logic_frame(
            7,
            2,
            10.0,
            1.5,
            &[Column {
                first: true,
                last: false,
                toggled: true,
                edges: 300,
                valid: true,
            }],
        );
        assert_eq!(&frame[..4], b"LVT1");
        assert_eq!(frame[4], 1);
        assert_eq!(frame[5], 1);
        assert_eq!(u16::from_le_bytes([frame[6], frame[7]]), 2);
        assert_eq!(u32::from_le_bytes(frame[8..12].try_into().unwrap()), 7);
        assert_eq!(u32::from_le_bytes(frame[12..16].try_into().unwrap()), 1);
        assert_eq!(frame[32], 1);
        assert_eq!(frame[33], 0);
        assert_eq!(frame[34], 1);
        assert_eq!(frame[35], 255);
        assert_eq!(frame[36], 1);
        assert_eq!(frame.len(), 37);
    }

    /// Checks that the local application shell and service health route are available.
    #[tokio::test]
    async fn health_and_shell_are_served() {
        let app = router(Engine::new());
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/health")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(res.status().is_success());
        let logo = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/assets/AppLogo.png")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(logo.status(), StatusCode::OK);
        assert_eq!(logo.headers()[header::CONTENT_TYPE], "image/png");
        let logo_bytes = logo.into_body().collect().await.unwrap().to_bytes();
        assert!(logo_bytes.starts_with(b"\x89PNG\r\n\x1a\n"));
        let export_logo = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/assets/ExportFileLogo.png")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(export_logo.status(), StatusCode::OK);
        assert_eq!(export_logo.headers()[header::CONTENT_TYPE], "image/png");
        assert!(export_logo
            .into_body()
            .collect()
            .await
            .unwrap()
            .to_bytes()
            .starts_with(b"\x89PNG\r\n\x1a\n"));
        let prefs_logo = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/assets/PrefsLogo.png")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(prefs_logo.status(), StatusCode::OK);
        assert_eq!(prefs_logo.headers()[header::CONTENT_TYPE], "image/png");
        assert!(prefs_logo
            .into_body()
            .collect()
            .await
            .unwrap()
            .to_bytes()
            .starts_with(b"\x89PNG\r\n\x1a\n"));
        let e2_logo = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/assets/E2logo.png")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(e2_logo.status(), StatusCode::OK);
        assert_eq!(e2_logo.headers()[header::CONTENT_TYPE], "image/png");
        assert!(e2_logo
            .into_body()
            .collect()
            .await
            .unwrap()
            .to_bytes()
            .starts_with(b"\x89PNG\r\n\x1a\n"));
        let settings = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/assets/settings.svg")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(settings.status(), StatusCode::OK);
        assert_eq!(settings.headers()[header::CONTENT_TYPE], "image/svg+xml");
        let svg = settings.into_body().collect().await.unwrap().to_bytes();
        assert!(std::str::from_utf8(&svg).unwrap().contains("<svg"));
        let page = app
            .clone()
            .oneshot(Request::builder().uri("/").body(Body::empty()).unwrap())
            .await
            .unwrap();
        let bytes = page.into_body().collect().await.unwrap().to_bytes();
        let html = String::from_utf8(bytes.to_vec()).unwrap();
        assert!(html.contains("LogicView"));
        assert!(html.contains("id=\"wave\""));
        assert!(html.contains("id=\"run\""));
        assert!(html.contains("id=\"stop\""));
        assert!(html.contains("id=\"device-select\""));
        assert!(html.contains("id=\"device-name\""));
        assert!(html.contains("id=\"cursor-mode\""));
        assert!(html.contains("id=\"export-dialog\""));
        assert!(html.contains("ExportFileLogo.png"));
        assert!(html.contains("PrefsLogo.png"));
        assert!(html.contains("id=\"trig-kind\""));
        assert!(html.contains("id=\"trig-channel\""));
        assert!(html.contains("id=\"trig-pre\""));
        assert!(html.contains("class=\"tool-divider\""));
        assert!(html.contains("about-copy-app"));
        assert!(html.contains("about-copy-e2"));
        assert!(html.contains("passionate about engineering"));
        assert!(html.contains("id=\"about-contributors\""));
        let credits = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/contributors")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(credits.status(), StatusCode::OK);
        let credits_body = credits.into_body().collect().await.unwrap().to_bytes();
        let credits_json: Value = serde_json::from_slice(&credits_body).unwrap();
        assert_eq!(credits_json[0]["name"], "Chuck");
        assert!(credits_json[0]["contribution"].as_str().unwrap().len() > 0);
        assert!(!html.contains("DreamSourceLab"));
        assert!(!html.contains(">Instant<"));
        assert!(!html.contains("Use Demo"));
    }

    /// Exercises capture startup, progress, and completion through HTTP commands.
    #[tokio::test]
    async fn demo_capture_shows_samples_then_stops() {
        let app = router(Engine::new());
        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 5_000,
                "realtime": true
            }),
        )
        .await;
        post(&app, json!({"cmd": "start", "instant": false})).await;
        let mut partial = None;
        for _ in 0..80 {
            tokio::time::sleep(Duration::from_millis(40)).await;
            let status = post(&app, json!({"cmd": "status"})).await;
            let count = status["sample_count"].as_u64().unwrap();
            let phase = status["phase"].as_str().unwrap();
            if count > 0 && phase == "running" && count < 5_000_000 {
                partial = Some(count);
                break;
            }
            if phase == "stopped" {
                break;
            }
        }
        assert!(
            partial.is_some(),
            "samples should appear while the demo capture is still running"
        );
        let stopped = post(&app, json!({"cmd": "stop"})).await;
        assert_eq!(stopped["phase"], "stopped");
        let count = stopped["sample_count"].as_u64().unwrap();
        assert!(count > 0, "stop keeps the samples already captured");
        assert!(
            count < 5_000_000,
            "stop ends the demo before the full five seconds"
        );
    }

    /// Checks that session selection keeps measurements and waveform queries tied to the correct
    /// record.
    #[tokio::test]
    async fn two_sessions_measure_and_tiles() {
        let app = router(Engine::new());
        let created = post(&app, json!({"cmd": "create_session", "name": "Capture 2"})).await;
        assert_eq!(created["id"], "ses-2");
        let listed = post(&app, json!({"cmd": "list_sessions"})).await;
        assert_eq!(listed["sessions"].as_array().unwrap().len(), 2);
        assert_eq!(listed["active"], "ses-2");

        post(&app, json!({"cmd": "select_session", "id": "ses-1"})).await;
        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 16,
                "realtime": false
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut status = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            status = post(&app, json!({"cmd": "status"})).await;
            if status["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(status["phase"], "stopped");
        assert_eq!(status["sample_count"], 16_000);

        let metrics = post(
            &app,
            json!({"cmd": "measure", "channel": 0, "sample": 1000}),
        )
        .await;
        assert_eq!(metrics["level_high"], false);
        assert_eq!(metrics["pulse_start"], 1000);
        assert_eq!(metrics["pulse_end"], 1050);
        assert_eq!(metrics["period_start"], 950);
        assert_eq!(metrics["period_end"], 1050);
        assert_eq!(metrics["pulse_width_samples"], 50);
        assert_eq!(metrics["period_samples"], 100);
        assert_eq!(metrics["frequency_hz"], 10_000.0);
        assert_eq!(metrics["duty"], 0.5);

        let tile = post(
            &app,
            json!({
                "cmd": "tile",
                "channel": 0,
                "start": 0.0,
                "columns": 4,
                "samples_per_pixel": 100.0,
                "kind": "logic"
            }),
        )
        .await;
        let columns = tile["columns"].as_array().unwrap();
        assert_eq!(columns.len(), 4);
        assert!(columns.iter().all(|col| col["toggled"] == true));

        let second = post(&app, json!({"cmd": "status", "session": "ses-2"})).await;
        assert_eq!(second["sample_count"], 0);

        let export = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/export/lvcap")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(export.status().is_success());
        let bytes = export.into_body().collect().await.unwrap().to_bytes();
        assert_eq!(&bytes[..2], b"PK");

        let created = post(&app, json!({"cmd": "create_session", "name": "Opened"})).await;
        assert_eq!(created["sample_count"], 0);
        let req = Request::builder()
            .method("POST")
            .uri("/api/import?name=capture.lvcap")
            .header("content-type", "application/octet-stream")
            .body(Body::from(bytes.to_vec()))
            .unwrap();
        let imported = app.clone().oneshot(req).await.unwrap();
        assert!(imported.status().is_success());
        let imported_bytes = imported.into_body().collect().await.unwrap().to_bytes();
        let imported: Value = serde_json::from_slice(&imported_bytes).unwrap();
        assert_eq!(imported["ok"], true);
        assert_eq!(imported["data"]["sample_count"], 16_000);
        assert_eq!(imported["data"]["devices"][0]["id"], "file");
        assert_eq!(imported["data"]["channels"][0]["name"], "CLK");
    }

    /// Exercises demo stacking and protocol analysis through browser commands.
    #[tokio::test]
    async fn stacked_channels_decode_over_the_command_api() {
        let app = router(Engine::new());
        let status = post(&app, json!({"cmd": "attach_device", "id": "demo:spi"})).await;
        assert_eq!(status["channels"].as_array().unwrap().len(), 8);
        assert_eq!(status["channels"][0]["device_id"], "demo");
        assert_eq!(status["channels"][0]["name"], "CLK");
        assert_eq!(status["channels"][4]["device_id"], "demo:spi");
        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 10
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut stopped = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            stopped = post(&app, json!({"cmd": "status"})).await;
            if stopped["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(stopped["phase"], "stopped");
        post(
            &app,
            json!({
                "cmd": "add_decoder",
                "protocol": "spi",
                "channels": {
                    "sck": "demo:spi/SCK",
                    "mosi": "demo:spi/MOSI",
                    "miso": "demo:spi/MISO",
                    "cs": "demo:spi/CS"
                }
            }),
        )
        .await;
        let rows = post(
            &app,
            json!({"cmd": "read_annotations", "query": "MOSI 0xA5", "limit": 5}),
        )
        .await;
        let rows = rows.as_array().unwrap();
        assert!(!rows.is_empty());
        assert!(rows[0]["text"].as_str().unwrap().contains("MISO 0x3C"));
    }

    /// Checks that ordered trigger settings reach the engine and report the observed demo trigger
    /// position.
    #[tokio::test]
    async fn sequential_trigger_reports_sample_40() {
        let app = router(Engine::new());
        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 10,
                "trigger_enabled": true,
                "trigger_steps": [
                    {"channel": 1, "rising": true},
                    {"channel": 3, "rising": true}
                ]
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut stopped = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            stopped = post(&app, json!({"cmd": "status"})).await;
            if stopped["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(stopped["phase"], "stopped");
        assert_eq!(stopped["trigger_sample"], 40);
    }

    /// Guards the UI transport against drawing nonexistent samples after capture completion.
    #[tokio::test]
    async fn stopped_capture_does_not_paint_a_tail_past_the_last_sample() {
        let app = router(Engine::new());
        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 16,
                "realtime": false
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut status = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            status = post(&app, json!({"cmd": "status"})).await;
            if status["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(status["phase"], "stopped");
        let count = status["sample_count"].as_u64().unwrap();
        assert_eq!(count, 16_000);

        let tail = post(
            &app,
            json!({
                "cmd": "tile",
                "channel": 0,
                "start": (count - 80) as f64,
                "columns": 80,
                "samples_per_pixel": 1.0,
                "kind": "logic"
            }),
        )
        .await;
        let columns = tail["columns"].as_array().unwrap();
        assert_eq!(columns.len(), 80);
        for (offset, column) in columns.iter().enumerate() {
            let sample = count - 80 + offset as u64;
            let high = logicview_capture::clock_high(sample);
            assert_eq!(column["valid"], true, "sample {sample}");
            assert_eq!(column["toggled"], false, "sample {sample}");
            assert_eq!(column["first"], high, "sample {sample}");
            assert_eq!(column["last"], high, "sample {sample}");
        }

        let past = post(
            &app,
            json!({
                "cmd": "tile",
                "channel": 0,
                "start": count as f64,
                "columns": 6,
                "samples_per_pixel": 8.0,
                "kind": "logic"
            }),
        )
        .await;
        for column in past["columns"].as_array().unwrap() {
            assert_eq!(column["valid"], false);
            assert_eq!(column["toggled"], false);
            assert_eq!(column["first"], false);
        }

        let straddle = post(
            &app,
            json!({
                "cmd": "tile",
                "channel": 0,
                "start": (count - 20) as f64,
                "columns": 2,
                "samples_per_pixel": 40.0,
                "kind": "logic"
            }),
        )
        .await;
        let cols = straddle["columns"].as_array().unwrap();
        assert_eq!(cols[0]["valid"], true);
        assert_eq!(
            cols[0]["toggled"], false,
            "a high tail must not pick up unread samples past the count"
        );
        assert_eq!(cols[1]["valid"], false);
        assert_eq!(cols[1]["toggled"], false);

        let analog = post(
            &app,
            json!({
                "cmd": "tile",
                "channel": 0,
                "start": (count - 32) as f64,
                "columns": 8,
                "samples_per_pixel": 16.0,
                "kind": "analog"
            }),
        )
        .await;
        for column in analog["columns"].as_array().unwrap() {
            if column["valid"] == true {
                let min = column["min"].as_f64().unwrap();
                let max = column["max"].as_f64().unwrap();
                assert!(min.is_finite() && max.is_finite());
                assert!(
                    (-1.3..1.3).contains(&min) && (-1.3..1.3).contains(&max),
                    "analog tail {min}..{max}"
                );
            }
        }
    }

    /// Checks that table downloads expose usable formats and sample row metadata.
    #[tokio::test]
    async fn capture_exports_csv_and_xlsx() {
        let app = router(Engine::new());
        let empty = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/export/csv")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(empty.status(), StatusCode::BAD_REQUEST);

        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 1,
                "realtime": false
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut status = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            status = post(&app, json!({"cmd": "status"})).await;
            if status["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(status["phase"], "stopped");
        let count = status["sample_count"].as_u64().unwrap();
        assert_eq!(count, 960);

        let csv_res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/export/csv")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(csv_res.status().is_success());
        assert_eq!(
            csv_res
                .headers()
                .get("x-logicview-rows")
                .unwrap()
                .to_str()
                .unwrap(),
            count.to_string()
        );
        let csv_bytes = csv_res.into_body().collect().await.unwrap().to_bytes();
        let csv = String::from_utf8(csv_bytes.to_vec()).unwrap();
        let lines: Vec<&str> = csv.lines().collect();
        assert_eq!(lines[0], "time_s,CLK,UART,SDA,SCL,SINE (V)");
        assert_eq!(lines.len() as u64, count + 1);
        let first: Vec<&str> = lines[1].split(',').collect();
        assert_eq!(first[0], "0.000000000");
        assert_eq!(first[1], "0");
        assert!(first[5].parse::<f64>().unwrap().abs() < 1.3);
        let last_sample = count - 1;
        let last: Vec<&str> = lines.last().unwrap().split(',').collect();
        assert_eq!(
            last[1],
            if logicview_capture::clock_high(last_sample) {
                "1"
            } else {
                "0"
            }
        );

        let xlsx_res = app
            .oneshot(
                Request::builder()
                    .uri("/api/export/xlsx")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(xlsx_res.status().is_success());
        let xlsx = xlsx_res.into_body().collect().await.unwrap().to_bytes();
        assert_eq!(&xlsx[..2], b"PK");
        assert!(xlsx.windows(6).any(|window| window == b"time_s"));
        assert!(xlsx.windows(3).any(|window| window == b"CLK"));
        assert!(xlsx.windows(4).any(|window| window == b"SINE"));
    }

    /// Writes a capture into a chosen folder and rejects a path that is not a folder.
    #[tokio::test]
    async fn export_to_writes_the_chosen_folder() {
        let app = router(Engine::new());
        let missing = std::env::temp_dir().join("logicview-export-missing");
        let _ = std::fs::remove_dir_all(&missing);
        let rejected = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/export-to")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({
                            "kind": "csv",
                            "directory": missing,
                            "filename": "Capture(1)"
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(rejected.status(), StatusCode::BAD_REQUEST);

        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 16,
                "realtime": false
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut status = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            status = post(&app, json!({"cmd": "status"})).await;
            if status["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(status["phase"], "stopped");

        let dir = std::env::temp_dir().join(format!("logicview-export-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let saved = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/export-to")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({
                            "kind": "csv",
                            "directory": dir,
                            "filename": "../Capture(1)"
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(saved.status(), StatusCode::BAD_REQUEST);

        let saved = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/export-to")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({
                            "kind": "csv",
                            "directory": &dir,
                            "filename": "Capture(1)"
                        }))
                        .unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(saved.status().is_success());
        let body = saved.into_body().collect().await.unwrap().to_bytes();
        let payload: Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(payload["ok"], true);
        let written = std::fs::read(dir.join("Capture(1).csv")).unwrap();
        assert!(written.starts_with(b"time_s"));
        let _ = std::fs::remove_dir_all(&dir);
    }

    /// Writes a capture to the absolute path chosen by the system save dialog.
    #[tokio::test]
    async fn save_as_writes_the_chosen_file() {
        let app = router(Engine::new());
        let relative = app
            .clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/save-as")
                    .header("content-type", "application/json")
                    .body(Body::from(
                        serde_json::to_vec(&json!({"path": "capture.lvcap"})).unwrap(),
                    ))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(relative.status(), StatusCode::BAD_REQUEST);

        post(
            &app,
            json!({
                "cmd": "configure",
                "sample_rate_hz": 1_000_000,
                "duration_ms": 16,
                "realtime": false
            }),
        )
        .await;
        post(&app, json!({"cmd": "start"})).await;
        let mut status = json!({});
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(10)).await;
            status = post(&app, json!({"cmd": "status"})).await;
            if status["phase"] == "stopped" {
                break;
            }
        }
        assert_eq!(status["phase"], "stopped");

        let path = std::env::temp_dir().join(format!("logicview-save-as-{}.lvcap", std::process::id()));
        let _ = std::fs::remove_file(&path);
        let saved = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/save-as")
                    .header("content-type", "application/json")
                    .body(Body::from(serde_json::to_vec(&json!({"path": path})).unwrap()))
                    .unwrap(),
            )
            .await
            .unwrap();
        assert!(saved.status().is_success());
        let written = std::fs::read(&path).unwrap();
        assert!(written.starts_with(b"PK"));
        let _ = std::fs::remove_file(&path);
    }

    /// Checks that the UI listener stays on the local host.
    #[tokio::test]
    async fn non_loopback_bind_is_refused() {
        let addr = "0.0.0.0:9".parse().unwrap();
        let err = serve(Engine::new(), addr).await.unwrap_err();
        assert!(err.to_string().contains("loopback"));
    }

    /// Sends a command through the in-memory HTTP router and extracts its successful data payload.
    async fn post(app: &Router, body: Value) -> Value {
        let req = Request::builder()
            .method("POST")
            .uri("/api/command")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_vec(&body).unwrap()))
            .unwrap();
        let res = app.clone().oneshot(req).await.unwrap();
        let status = res.status();
        let bytes = res.into_body().collect().await.unwrap().to_bytes();
        let value: Value = serde_json::from_slice(&bytes).unwrap();
        assert!(status.is_success(), "{status} {value}");
        assert_eq!(value["ok"], true, "{value}");
        value["data"].clone()
    }
}
