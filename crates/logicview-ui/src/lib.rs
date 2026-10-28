//! Localhost Axum shell.
//!
//! The page, stylesheet, and waveform client are served by this process.
//! Sample truth stays in the engine. Tile requests return either JSON (HTTP)
//! or the `LVT1` binary frame (WebSocket). The server refuses a non-loopback
//! bind.

use std::convert::Infallible;
use std::net::SocketAddr;
use std::time::Duration;

use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::State;
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

const INDEX_HTML: &str = include_str!("../assets/index.html");
const APP_CSS: &str = include_str!("../assets/app.css");
const APP_JS: &str = include_str!("../assets/app.js");

#[derive(Clone)]
struct AppState {
    engine: Engine,
}

#[derive(Debug, Error)]
pub enum UiError {
    #[error(
        "refusing to bind {0}; LogicView listens on loopback unless a later build adds a token"
    )]
    NonLoopback(SocketAddr),
    #[error("{0}")]
    Io(#[from] std::io::Error),
}

pub fn router(engine: Engine) -> Router {
    Router::new()
        .route("/", get(index))
        .route("/assets/app.css", get(css))
        .route("/assets/app.js", get(js))
        .route("/api/health", get(health))
        .route("/api/command", post(command))
        .route("/api/events", get(events))
        .route("/api/export/lvcap", get(export_lvcap))
        .route("/api/export/dsl", get(export_dsl))
        .route("/ws", get(ws_upgrade))
        .with_state(AppState { engine })
}

pub async fn serve(engine: Engine, addr: SocketAddr) -> Result<(), UiError> {
    if !addr.ip().is_loopback() {
        return Err(UiError::NonLoopback(addr));
    }
    let listener = tokio::net::TcpListener::bind(addr).await?;
    let local = listener.local_addr()?;
    tracing::info!("LogicView demo UI at http://{local}");
    axum::serve(listener, router(engine)).await?;
    Ok(())
}

async fn index() -> impl IntoResponse {
    ([(header::CACHE_CONTROL, "no-store")], Html(INDEX_HTML))
}

async fn css() -> impl IntoResponse {
    (
        [
            (header::CONTENT_TYPE, "text/css; charset=utf-8"),
            (header::CACHE_CONTROL, "no-store"),
        ],
        APP_CSS,
    )
}

async fn js() -> impl IntoResponse {
    (
        [
            (header::CONTENT_TYPE, "text/javascript; charset=utf-8"),
            (header::CACHE_CONTROL, "no-store"),
        ],
        APP_JS,
    )
}

async fn health() -> Json<Value> {
    Json(json!({
        "ok": true,
        "service": "logicview",
        "phases": ["0", "1", "2", "3", "4"],
        "device": "demo"
    }))
}

async fn command(
    State(app): State<AppState>,
    Json(cmd): Json<Command>,
) -> Result<Json<Value>, ApiError> {
    let data = dispatch(&app.engine, cmd).await?;
    Ok(Json(json!({"ok": true, "data": data})))
}

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

fn event_name(event: &EngineEvent) -> &'static str {
    match event {
        EngineEvent::Phase { .. } => "phase",
        EngineEvent::Appended { .. } => "appended",
        EngineEvent::Stopped { .. } => "stopped",
        EngineEvent::Error { .. } => "error",
    }
}

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

async fn ws_upgrade(ws: WebSocketUpgrade, State(app): State<AppState>) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, app.engine))
}

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

async fn dispatch(engine: &Engine, cmd: Command) -> Result<Value, ApiError> {
    match cmd {
        Command::ListDevices => Ok(json!(engine.list_devices().await)),
        Command::Connect { id } => Ok(json!(engine.connect(&id).await?)),
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
        } => {
            engine
                .configure(
                    session.as_deref(),
                    SessionConfig {
                        sample_rate_hz,
                        duration_ms,
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
                            "high" => TriggerKind::High,
                            "low" => TriggerKind::Low,
                            _ => TriggerKind::Rising,
                        },
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
        } => {
            let edge = engine
                .search_edge(session.as_deref(), channel, from, rising)
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

fn check_tile(columns: usize, spp: f64) -> Result<(), ApiError> {
    if columns == 0 || columns > 8192 || !spp.is_finite() || spp <= 0.0 || spp > 1.0e12 {
        return Err(ApiError(EngineError::Capture(
            logicview_capture::CaptureError::Proto("tile request is out of range".into()),
        )));
    }
    Ok(())
}

struct TileQuery<'a> {
    session: Option<&'a str>,
    channel: usize,
    start: f64,
    columns: usize,
    spp: f64,
    kind: &'a str,
    req: u32,
}

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
/// 32..   logic: first, last, toggled, edges (u8, saturated)
///        analog: min f32, max f32 (NaN when the column is past the capture)
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
    }
    out
}

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

fn column_json(column: &Column) -> Value {
    json!({
        "first": column.first,
        "last": column.last,
        "toggled": column.toggled,
        "edges": column.edges,
    })
}

fn analog_json(column: &AnalogColumn) -> Value {
    json!({
        "min": column.min,
        "max": column.max,
        "valid": column.valid,
    })
}

fn metrics_json(metrics: PulseMetrics) -> Value {
    json!({
        "sample": metrics.sample,
        "level_high": metrics.level_high,
        "pulse_width_samples": metrics.pulse_width_samples,
        "period_samples": metrics.period_samples,
        "high_samples": metrics.high_samples,
        "width_secs": metrics.width_secs,
        "period_secs": metrics.period_secs,
        "frequency_hz": metrics.frequency_hz,
        "duty": metrics.duty,
    })
}

struct ApiError(EngineError);

impl From<EngineError> for ApiError {
    fn from(err: EngineError) -> Self {
        Self(err)
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let body = Json(json!({"ok": false, "error": self.0.to_string()}));
        (StatusCode::BAD_REQUEST, body).into_response()
    }
}

#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
enum Command {
    ListDevices,
    Connect { id: String },
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
        channel_enable: u32,
        #[serde(default)]
        trigger_channel: u8,
        #[serde(default)]
        trigger_kind: String,
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

fn default_percent() -> f64 {
    10.0
}

fn default_threshold() -> f64 {
    1.6
}

fn default_true() -> bool {
    true
}

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
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use http_body_util::BodyExt;
    use logicview_engine::Column;
    use tower::ServiceExt;

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
    }

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
        let page = app
            .oneshot(Request::builder().uri("/").body(Body::empty()).unwrap())
            .await
            .unwrap();
        let bytes = page.into_body().collect().await.unwrap().to_bytes();
        let html = String::from_utf8(bytes.to_vec()).unwrap();
        assert!(html.contains("LogicView"));
        assert!(html.contains("id=\"wave\""));
        assert!(html.contains("id=\"start\""));
    }

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
    }

    #[tokio::test]
    async fn non_loopback_bind_is_refused() {
        let addr = "0.0.0.0:9".parse().unwrap();
        let err = serve(Engine::new(), addr).await.unwrap_err();
        assert!(err.to_string().contains("loopback"));
    }

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
