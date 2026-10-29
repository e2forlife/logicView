//! MCP for an agent driving the analyzer.
//!
//! `logicview mcp` speaks newline-delimited JSON-RPC on stdio (protocol
//! 2024-11-05). If the UI already published the local attach endpoint, the
//! client attaches to that engine. Unix uses a Unix socket at the endpoint
//! path. Windows listens on TCP `127.0.0.1` and writes `host:port` into that
//! path, or binds the address directly when the path is already `host:port`.
//! A second start does not reset a capture that is still running unless the
//! caller passes `force`.
//!
//! Scope and data-acquisition tools are refused. This build does not implement
//! them.

use std::path::{Path, PathBuf};
use std::time::Duration;

use logicview_capture::{SessionConfig, StartMode};
use logicview_engine::Engine;
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt, BufReader};
use tokio::sync::Mutex;

#[cfg(unix)]
mod attach_unix;
#[cfg(unix)]
use attach_unix as transport;

#[cfg(windows)]
mod attach_windows;
#[cfg(windows)]
use attach_windows as transport;

#[cfg(not(any(unix, windows)))]
compile_error!("MCP attach is implemented for Unix sockets and Windows TCP localhost");

pub fn default_socket_path() -> PathBuf {
    if let Some(value) = std::env::var_os("LOGICVIEW_SOCKET") {
        return PathBuf::from(value);
    }
    platform_default_socket_path()
}

#[cfg(unix)]
fn platform_default_socket_path() -> PathBuf {
    PathBuf::from("/tmp/logicview.sock")
}

#[cfg(windows)]
fn platform_default_socket_path() -> PathBuf {
    std::env::temp_dir().join("logicview.sock")
}

/// Startup description of where an MCP client attaches.
pub fn attach_location() -> String {
    let path = default_socket_path();
    #[cfg(unix)]
    {
        return format!("unix socket {}", path.display());
    }
    #[cfg(windows)]
    {
        format!("TCP 127.0.0.1 via {}", path.display())
    }
}

// The Windows transport reads this. Unix unit tests cover it; the Unix library
// build has no caller, so the unused warning is limited to that build.
#[cfg_attr(not(windows), allow(dead_code))]
pub(crate) fn parse_loopback_endpoint(text: &str) -> Result<std::net::SocketAddr, String> {
    let addr: std::net::SocketAddr = text
        .trim()
        .parse()
        .map_err(|_| "attach endpoint must be a loopback host:port".to_string())?;
    if !addr.ip().is_loopback() {
        return Err(format!("refusing non-loopback attach address {addr}"));
    }
    if addr.port() == 0 {
        return Err("attach endpoint is missing a port".into());
    }
    Ok(addr)
}

pub async fn run_stdio(attach: Option<PathBuf>) -> i32 {
    let session = match open_session(attach).await {
        Ok(session) => session,
        Err(err) => {
            eprintln!("logicview mcp: {err}");
            return 1;
        }
    };
    if let Err(err) = stdio_loop(session).await {
        eprintln!("logicview mcp: {err}");
        return 1;
    }
    0
}

async fn open_session(attach: Option<PathBuf>) -> Result<McpSession, String> {
    if let Some(path) = attach {
        return McpSession::connect(&path)
            .await
            .map_err(|err| format!("attach {}: {err}", path.display()));
    }
    let path = default_socket_path();
    if let Ok(session) = McpSession::connect(&path).await {
        tracing::info!(path = %path.display(), "attached to the running LogicView engine");
        return Ok(session);
    }
    Ok(McpSession::local(Engine::new()))
}

pub async fn serve_attach(engine: Engine, path: &Path) -> std::io::Result<()> {
    let listener = transport::bind(path).await?;
    tracing::info!(endpoint = %listener.label(), "engine attach listening");
    loop {
        let stream = listener.accept().await?;
        let engine = engine.clone();
        tokio::spawn(async move {
            if let Err(err) = socket_client(engine, stream).await {
                tracing::debug!("attach client closed: {err}");
            }
        });
    }
}

async fn socket_client<S>(engine: Engine, stream: S) -> Result<(), String>
where
    S: AsyncRead + AsyncWrite + Unpin + Send,
{
    let (read, mut write) = tokio::io::split(stream);
    let mut lines = BufReader::new(read).lines();
    while let Some(line) = lines.next_line().await.map_err(|err| err.to_string())? {
        if line.trim().is_empty() {
            continue;
        }
        let request: Value = serde_json::from_str(&line).map_err(|err| err.to_string())?;
        let id = request.get("id").cloned().unwrap_or(Value::Null);
        let tool = request
            .get("tool")
            .and_then(|value| value.as_str())
            .unwrap_or("");
        let arguments = request
            .get("arguments")
            .cloned()
            .unwrap_or_else(|| json!({}));
        let response = match invoke(&engine, tool, &arguments).await {
            Ok(data) => json!({"id": id, "ok": true, "data": data}),
            Err(err) => json!({"id": id, "ok": false, "error": err}),
        };
        let mut bytes = serde_json::to_vec(&response).map_err(|err| err.to_string())?;
        bytes.push(b'\n');
        write
            .write_all(&bytes)
            .await
            .map_err(|err| err.to_string())?;
    }
    Ok(())
}

enum Backend {
    Local(Engine),
    Remote(Mutex<transport::Stream>),
}

pub struct McpSession {
    backend: Backend,
}

impl McpSession {
    pub fn local(engine: Engine) -> Self {
        Self {
            backend: Backend::Local(engine),
        }
    }

    pub async fn connect(path: &Path) -> Result<Self, String> {
        let stream = transport::connect(path).await?;
        Ok(Self {
            backend: Backend::Remote(Mutex::new(stream)),
        })
    }

    pub async fn handle(&mut self, message: Value) -> Option<Value> {
        let id = message.get("id").cloned();
        let method = message
            .get("method")
            .and_then(|value| value.as_str())
            .unwrap_or("");
        let params = message.get("params").cloned().unwrap_or_else(|| json!({}));
        if id.is_none() {
            return None;
        }
        let id = id.unwrap();
        match method {
            "initialize" => Some(rpc_ok(
                id,
                json!({
                    "protocolVersion": "2024-11-05",
                    "capabilities": {
                        "tools": {},
                        "resources": {},
                        "prompts": {}
                    },
                    "serverInfo": {"name": "logicview", "version": env!("CARGO_PKG_VERSION")}
                }),
            )),
            "ping" => Some(rpc_ok(id, json!({}))),
            "tools/list" => Some(rpc_ok(id, json!({"tools": tool_defs()}))),
            "tools/call" => {
                let name = params
                    .get("name")
                    .and_then(|value| value.as_str())
                    .unwrap_or("");
                let arguments = params
                    .get("arguments")
                    .cloned()
                    .unwrap_or_else(|| json!({}));
                Some(rpc_ok(id, self.call_tool(name, &arguments).await))
            }
            "resources/list" => Some(rpc_ok(id, json!({"resources": resource_defs()}))),
            "resources/read" => {
                let uri = params
                    .get("uri")
                    .and_then(|value| value.as_str())
                    .unwrap_or("");
                match self.read_resource(uri).await {
                    Ok(text) => Some(rpc_ok(
                        id,
                        json!({
                            "contents": [{
                                "uri": uri,
                                "mimeType": "application/json",
                                "text": text
                            }]
                        }),
                    )),
                    Err(err) => Some(rpc_err(id, err)),
                }
            }
            "prompts/list" => Some(rpc_ok(id, json!({"prompts": prompt_defs()}))),
            "prompts/get" => {
                let name = params
                    .get("name")
                    .and_then(|value| value.as_str())
                    .unwrap_or("");
                match prompt_text(name) {
                    Some(text) => Some(rpc_ok(
                        id,
                        json!({
                            "description": text.0,
                            "messages": [{
                                "role": "user",
                                "content": {"type": "text", "text": text.1}
                            }]
                        }),
                    )),
                    None => Some(rpc_err(id, format!("unknown prompt {name}"))),
                }
            }
            _ => Some(rpc_err(id, format!("unknown method {method}"))),
        }
    }

    async fn call_tool(&mut self, name: &str, arguments: &Value) -> Value {
        match self.dispatch(name, arguments).await {
            Ok(data) => tool_ok(&data),
            Err(err) => tool_err(&err),
        }
    }

    async fn dispatch(&mut self, name: &str, arguments: &Value) -> Result<Value, String> {
        match &self.backend {
            Backend::Local(engine) => invoke(engine, name, arguments).await,
            Backend::Remote(stream) => remote_call(stream, name, arguments).await,
        }
    }

    async fn read_resource(&mut self, uri: &str) -> Result<String, String> {
        let value = if uri == "logicview://devices" {
            self.dispatch("list_devices", &json!({})).await?
        } else if uri == "logicview://session" || uri == "logicview://capture/active" {
            self.dispatch("capture_status", &json!({})).await?
        } else if uri == "logicview://catalog/decoders" {
            self.dispatch("list_decoders_catalog", &json!({})).await?
        } else if uri == "logicview://catalog/profiles" {
            self.dispatch("list_profiles", &json!({})).await?
        } else if let Some(rest) = uri.strip_prefix("logicview://capture/") {
            if let Some((id, tail)) = rest.split_once('/') {
                if tail == "decoders" {
                    self.dispatch("list_decoder_instances", &json!({"session": id}))
                        .await?
                } else if let Some(decoder) = tail.strip_prefix("annotations/") {
                    self.dispatch(
                        "read_annotations",
                        &json!({"session": id, "decoder": decoder, "limit": 200}),
                    )
                    .await?
                } else {
                    return Err(format!("unknown resource {uri}"));
                }
            } else {
                self.dispatch("capture_status", &json!({"session": rest}))
                    .await?
            }
        } else if let Some(id) = uri.strip_prefix("logicview://device/") {
            let devices = self.dispatch("list_devices", &json!({})).await?;
            let found = devices
                .as_array()
                .and_then(|rows| rows.iter().find(|row| row["id"] == id))
                .cloned()
                .ok_or_else(|| format!("unknown device {id}"))?;
            found
        } else {
            return Err(format!("unknown resource {uri}"));
        };
        Ok(value.to_string())
    }
}

async fn remote_call(
    stream: &Mutex<transport::Stream>,
    tool: &str,
    arguments: &Value,
) -> Result<Value, String> {
    let mut guard = stream.lock().await;
    let request = json!({"id": 1, "tool": tool, "arguments": arguments});
    let mut bytes = serde_json::to_vec(&request).map_err(|err| err.to_string())?;
    bytes.push(b'\n');
    guard
        .write_all(&bytes)
        .await
        .map_err(|err| err.to_string())?;
    let mut reader = BufReader::new(&mut *guard);
    let mut line = String::new();
    let read = reader
        .read_line(&mut line)
        .await
        .map_err(|err| err.to_string())?;
    if read == 0 {
        return Err("attach connection closed".into());
    }
    let response: Value = serde_json::from_str(line.trim()).map_err(|err| err.to_string())?;
    if response.get("ok").and_then(|value| value.as_bool()) == Some(true) {
        Ok(response.get("data").cloned().unwrap_or(Value::Null))
    } else {
        Err(response
            .get("error")
            .and_then(|value| value.as_str())
            .unwrap_or("attach call failed")
            .to_string())
    }
}

async fn stdio_loop(mut session: McpSession) -> Result<(), String> {
    let stdin = tokio::io::stdin();
    let mut reader = BufReader::new(stdin);
    let mut stdout = tokio::io::stdout();
    loop {
        let Some(message) = read_message(&mut reader).await? else {
            return Ok(());
        };
        if let Some(response) = session.handle(message).await {
            let mut bytes = serde_json::to_vec(&response).map_err(|err| err.to_string())?;
            bytes.push(b'\n');
            stdout
                .write_all(&bytes)
                .await
                .map_err(|err| err.to_string())?;
            stdout.flush().await.map_err(|err| err.to_string())?;
        }
    }
}

async fn read_message<R: AsyncBufReadExt + Unpin>(reader: &mut R) -> Result<Option<Value>, String> {
    loop {
        let mut line = String::new();
        let read = reader
            .read_line(&mut line)
            .await
            .map_err(|err| err.to_string())?;
        if read == 0 {
            return Ok(None);
        }
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        if trimmed.to_ascii_lowercase().starts_with("content-length:") {
            let len: usize = trimmed
                .split(':')
                .nth(1)
                .unwrap_or("0")
                .trim()
                .parse()
                .map_err(|_| "bad Content-Length".to_string())?;
            loop {
                line.clear();
                reader
                    .read_line(&mut line)
                    .await
                    .map_err(|err| err.to_string())?;
                if line == "\n" || line == "\r\n" || line.is_empty() {
                    break;
                }
            }
            let mut body = vec![0u8; len];
            reader
                .read_exact(&mut body)
                .await
                .map_err(|err| err.to_string())?;
            return serde_json::from_slice(&body)
                .map(Some)
                .map_err(|err| err.to_string());
        }
        return serde_json::from_str(trimmed)
            .map(Some)
            .map_err(|err| err.to_string());
    }
}

pub async fn invoke(engine: &Engine, tool: &str, args: &Value) -> Result<Value, String> {
    let session = args.get("session").and_then(|value| value.as_str());
    match tool {
        "list_devices" => Ok(json!(engine.list_devices().await)),
        "list_profiles" => Ok(json!(engine.list_profiles().await)),
        "list_decoders_catalog" => Ok(json!(engine.decoder_catalog().await)),
        "connect" => {
            let id = req_str(args, "id")?;
            Ok(json!(engine
                .connect(id)
                .await
                .map_err(|err| err.to_string())?))
        }
        "attach_device" => {
            let id = req_str(args, "id")?;
            Ok(json!(engine
                .attach_device(session, id)
                .await
                .map_err(|err| err.to_string())?))
        }
        "detach_device" => {
            let id = req_str(args, "id")?;
            Ok(json!(engine
                .detach_device(session, id)
                .await
                .map_err(|err| err.to_string())?))
        }
        "configure_logic" => {
            let mut config = SessionConfig::default();
            if let Some(rate) = args.get("sample_rate_hz").and_then(|value| value.as_u64()) {
                config.sample_rate_hz = rate;
            }
            if let Some(duration) = args.get("duration_ms").and_then(|value| value.as_u64()) {
                config.duration_ms = duration;
            }
            config.realtime = args
                .get("realtime")
                .and_then(|value| value.as_bool())
                .unwrap_or(false);
            config.trigger_enabled = args
                .get("trigger_enabled")
                .and_then(|value| value.as_bool())
                .unwrap_or(false);
            if let Some(steps) = args.get("trigger_steps").and_then(|value| value.as_array()) {
                let mut parsed = Vec::with_capacity(steps.len());
                for step in steps {
                    let channel = step
                        .get("channel")
                        .and_then(|value| value.as_u64())
                        .ok_or_else(|| "trigger step needs a channel".to_string())?;
                    if channel > 31 {
                        return Err("trigger channels are 0 through 31".into());
                    }
                    let rising = step
                        .get("rising")
                        .and_then(|value| value.as_bool())
                        .or_else(|| match step.get("edge").and_then(|value| value.as_str()) {
                            Some("falling") => Some(false),
                            Some("rising") => Some(true),
                            _ => None,
                        })
                        .unwrap_or(true);
                    parsed.push(logicview_capture::TriggerStep {
                        channel: channel as u8,
                        rising,
                    });
                }
                if !parsed.is_empty() {
                    config.trigger_enabled = true;
                    config.trigger_steps = parsed;
                }
            }
            engine
                .configure(session, config)
                .await
                .map_err(|err| err.to_string())?;
            let status = engine
                .status(session)
                .await
                .map_err(|err| err.to_string())?;
            Ok(json!(status))
        }
        "configure_scope" | "configure_daq" => {
            Err("oscilloscope and data acquisition are not in this build".into())
        }
        "start_capture" => {
            let force = args
                .get("force")
                .and_then(|value| value.as_bool())
                .unwrap_or(false);
            let instant = args
                .get("instant")
                .and_then(|value| value.as_bool())
                .unwrap_or(false)
                || args.get("mode").and_then(|value| value.as_str()) == Some("instant");
            let current = engine
                .status(session)
                .await
                .map_err(|err| err.to_string())?;
            if !force
                && matches!(
                    current.phase.as_str(),
                    "arming" | "waiting_trigger" | "running" | "stopping"
                )
            {
                return Ok(capture_payload(&current, true));
            }
            let mode = if instant {
                StartMode::Instant
            } else {
                StartMode::Normal
            };
            let status = engine
                .start(session, mode)
                .await
                .map_err(|err| err.to_string())?;
            Ok(capture_payload(&status, false))
        }
        "wait_capture" => {
            let timeout_ms = args
                .get("timeout_ms")
                .and_then(|value| value.as_u64())
                .unwrap_or(10_000);
            if !(1..=120_000).contains(&timeout_ms) {
                return Err("timeout_ms must be between 1 and 120000".into());
            }
            let id = match session {
                Some(id) => id.to_string(),
                None => engine.status(None).await.map_err(|err| err.to_string())?.id,
            };
            let status = engine
                .wait_until_settled(&id, Duration::from_millis(timeout_ms))
                .await
                .map_err(|err| err.to_string())?;
            Ok(capture_payload(&status, false))
        }
        "stop_capture" => {
            let status = engine.stop(session).await.map_err(|err| err.to_string())?;
            Ok(capture_payload(&status, false))
        }
        "capture_status" | "list_sessions" => {
            if tool == "list_sessions" {
                let (sessions, active) = engine.list_sessions().await;
                return Ok(json!({"sessions": sessions, "active": active}));
            }
            let status = engine
                .status(session)
                .await
                .map_err(|err| err.to_string())?;
            Ok(capture_payload(&status, false))
        }
        "add_decoder" => {
            let protocol = args
                .get("protocol")
                .and_then(|value| value.as_str())
                .or_else(|| args.get("id").and_then(|value| value.as_str()))
                .ok_or("protocol is required")?;
            let channels = channel_map(args.get("channels").unwrap_or(&json!({})))?;
            let options = string_map(args.get("options").unwrap_or(&json!({})))?;
            let stack_on = args.get("stack_on").and_then(|value| value.as_str());
            let region = match (
                args.get("region_start").and_then(|value| value.as_u64()),
                args.get("region_end").and_then(|value| value.as_u64()),
            ) {
                (Some(start), Some(end)) => Some((start, end)),
                _ => None,
            };
            let info = engine
                .add_decoder(session, protocol, &channels, &options, region, stack_on)
                .await
                .map_err(|err| err.to_string())?;
            Ok(json!(info))
        }
        "remove_decoder" => {
            let id = req_str(args, "id")?;
            engine
                .remove_decoder(session, id)
                .await
                .map_err(|err| err.to_string())?;
            Ok(json!({"removed": id}))
        }
        "list_decoder_instances" => Ok(json!(engine
            .list_decoders(session)
            .await
            .map_err(|err| err.to_string())?)),
        "read_annotations" | "search_annotations" => {
            let query = if tool == "search_annotations" {
                Some(req_str(args, "query")?)
            } else {
                args.get("query").and_then(|value| value.as_str())
            };
            let decoder = args.get("decoder").and_then(|value| value.as_str());
            let offset = args
                .get("offset")
                .and_then(|value| value.as_u64())
                .unwrap_or(0) as usize;
            let limit = args
                .get("limit")
                .and_then(|value| value.as_u64())
                .unwrap_or(200) as usize;
            let rows = engine
                .read_annotations(
                    session,
                    decoder,
                    query,
                    args.get("start").and_then(|value| value.as_u64()),
                    args.get("end").and_then(|value| value.as_u64()),
                    offset,
                    limit,
                )
                .await
                .map_err(|err| err.to_string())?;
            let preview: Vec<&str> = rows.iter().take(40).map(|row| row.text.as_str()).collect();
            Ok(json!({
                "rows": rows,
                "text": preview.join("\n"),
            }))
        }
        "export_annotations" => {
            let format = args
                .get("format")
                .and_then(|value| value.as_str())
                .unwrap_or("csv");
            let query = args.get("query").and_then(|value| value.as_str());
            let body = engine
                .export_annotations(session, format, query)
                .await
                .map_err(|err| err.to_string())?;
            Ok(json!({"format": format, "body": body}))
        }
        "search_edges" => {
            let channel = req_u64(args, "channel")? as usize;
            let from = args
                .get("from")
                .and_then(|value| value.as_u64())
                .unwrap_or(0);
            if let Some(pattern) = args.get("pattern").and_then(|value| value.as_str()) {
                let bits = parse_pattern(pattern);
                let forward = args
                    .get("forward")
                    .and_then(|value| value.as_bool())
                    .unwrap_or(true);
                let sample = engine
                    .search_pattern(session, channel, from, &bits, forward)
                    .await
                    .map_err(|err| err.to_string())?;
                Ok(json!({"sample": sample}))
            } else {
                let rising = args
                    .get("rising")
                    .and_then(|value| value.as_bool())
                    .unwrap_or(true);
                let forward = args
                    .get("forward")
                    .and_then(|value| value.as_bool())
                    .unwrap_or(true);
                let sample = engine
                    .search_edge(session, channel, from, rising, forward)
                    .await
                    .map_err(|err| err.to_string())?;
                Ok(json!({"sample": sample}))
            }
        }
        "measure" => {
            let channel = req_u64(args, "channel")? as usize;
            let sample = req_u64(args, "sample")?;
            let metrics = engine
                .measure(session, channel, sample)
                .await
                .map_err(|err| err.to_string())?;
            let saved = if args
                .get("persist")
                .and_then(|value| value.as_bool())
                .unwrap_or(false)
            {
                Some(
                    engine
                        .save_measurement(session, channel, sample)
                        .await
                        .map_err(|err| err.to_string())?,
                )
            } else {
                None
            };
            Ok(json!({
                "pulse_width_samples": metrics.pulse_width_samples,
                "period_samples": metrics.period_samples,
                "frequency_hz": metrics.frequency_hz,
                "duty": metrics.duty,
                "width_secs": metrics.width_secs,
                "level_high": metrics.level_high,
                "saved": saved,
            }))
        }
        "set_cursors" => {
            let channel = args
                .get("channel")
                .and_then(|value| value.as_u64())
                .unwrap_or(0) as usize;
            if let Some(sample) = args.get("a").and_then(|value| value.as_u64()) {
                engine
                    .set_cursor(session, 0, Some(sample))
                    .await
                    .map_err(|err| err.to_string())?;
            }
            if let Some(sample) = args.get("b").and_then(|value| value.as_u64()) {
                engine
                    .set_cursor(session, 1, Some(sample))
                    .await
                    .map_err(|err| err.to_string())?;
            }
            let span = engine
                .cursor_span(session, channel)
                .await
                .map_err(|err| err.to_string())?;
            Ok(json!({
                "samples": span.samples,
                "seconds": span.seconds,
                "edges": span.edges,
            }))
        }
        other => Err(format!("unknown tool {other}")),
    }
}

fn capture_payload(status: &logicview_engine::Status, reused: bool) -> Value {
    json!({
        "reused": reused,
        "capture_id": status.id,
        "product_id": null,
        "firmware": null,
        "device_ids": status.devices.iter().map(|device| &device.id).collect::<Vec<_>>(),
        "phase": status.phase,
        "sample_count": status.sample_count,
        "sample_rate_hz": status.sample_rate_hz,
        "warnings": status.warnings,
        "status": status,
    })
}

fn req_str<'a>(args: &'a Value, key: &str) -> Result<&'a str, String> {
    args.get(key)
        .and_then(|value| value.as_str())
        .ok_or_else(|| format!("{key} is required"))
}

fn req_u64(args: &Value, key: &str) -> Result<u64, String> {
    args.get(key)
        .and_then(|value| value.as_u64())
        .ok_or_else(|| format!("{key} is required"))
}

fn channel_map(value: &Value) -> Result<std::collections::BTreeMap<String, String>, String> {
    stringish_map(value, "channels")
}

fn string_map(value: &Value) -> Result<std::collections::BTreeMap<String, String>, String> {
    stringish_map(value, "options")
}

fn stringish_map(
    value: &Value,
    label: &str,
) -> Result<std::collections::BTreeMap<String, String>, String> {
    let Some(object) = value.as_object() else {
        return Err(format!("{label} must be an object"));
    };
    let mut map = std::collections::BTreeMap::new();
    for (key, value) in object {
        let text = match value {
            Value::String(text) => text.clone(),
            Value::Number(number) => number.to_string(),
            Value::Bool(flag) => flag.to_string(),
            _ => return Err(format!("{label}.{key} must be a string or number")),
        };
        map.insert(key.clone(), text);
    }
    Ok(map)
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

fn rpc_ok(id: Value, result: Value) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "result": result})
}

fn rpc_err(id: Value, message: String) -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": {"code": -32602, "message": message}
    })
}

fn tool_ok(data: &Value) -> Value {
    let summary = summary_text(data);
    json!({
        "content": [
            {"type": "text", "text": summary},
            {"type": "text", "text": data.to_string()}
        ],
        "isError": false
    })
}

fn tool_err(message: &str) -> Value {
    json!({
        "content": [{"type": "text", "text": message}],
        "isError": true
    })
}

fn summary_text(data: &Value) -> String {
    if let Some(text) = data.get("text").and_then(|value| value.as_str()) {
        if !text.is_empty() {
            return text.to_string();
        }
    }
    if let Some(rows) = data.get("rows").and_then(|value| value.as_array()) {
        let lines: Vec<&str> = rows
            .iter()
            .filter_map(|row| row.get("text").and_then(|value| value.as_str()))
            .take(40)
            .collect();
        if !lines.is_empty() {
            return lines.join("\n");
        }
    }
    if let Some(phase) = data.get("phase").and_then(|value| value.as_str()) {
        let samples = data
            .get("sample_count")
            .and_then(|value| value.as_u64())
            .unwrap_or(0);
        let id = data
            .get("capture_id")
            .and_then(|value| value.as_str())
            .unwrap_or("");
        return format!("capture {id} {phase}, {samples} samples");
    }
    data.to_string()
}

fn tool_defs() -> Vec<Value> {
    vec![
        tool(
            "list_devices",
            "List plugged-in DreamSourceLab pods ahead of demo devices. Untested product ids are shown and are not opened.",
            json!({}),
        ),
        tool("list_profiles", "Logic pod profiles. Untested product ids are not opened.", json!({})),
        tool("connect", "Replace the session devices with one demo pod or the tested Plus.", json!({"id": {"type": "string"}})),
        tool("attach_device", "Stack another demo pod into the active session.", json!({"id": {"type": "string"}})),
        tool("detach_device", "Remove one stacked demo pod.", json!({"id": {"type": "string"}})),
        tool("configure_logic", "Set sample rate, duration, and an optional ordered edge trigger. trigger_steps is a list of {channel, rising}. The demo source finds that sequence in the captured samples. The same stages are written into the arm record and have not been run on a pod.", json!({"sample_rate_hz": {"type": "integer"}, "duration_ms": {"type": "integer"}, "trigger_enabled": {"type": "boolean"}, "trigger_steps": {"type": "array"}})),
        tool("configure_scope", "Refused: oscilloscope is not in this build.", json!({})),
        tool("configure_daq", "Refused: data acquisition is not in this build.", json!({})),
        tool("start_capture", "Arm the session. A running capture is reused unless force is true.", json!({"force": {"type": "boolean"}, "instant": {"type": "boolean"}})),
        tool("wait_capture", "Wait until the capture stops. timeout_ms is required to avoid an unbounded wait and defaults to 10000.", json!({"timeout_ms": {"type": "integer"}})),
        tool("stop_capture", "Stop and keep the samples already stored.", json!({})),
        tool("capture_status", "Phase, sample count, devices, and warnings.", json!({})),
        tool("add_decoder", "Add UART, I2C, SPI, or eeprom24. Channels accept an index or device/name.", json!({"protocol": {"type": "string"}, "channels": {"type": "object"}})),
        tool("remove_decoder", "Remove a decoder instance.", json!({"id": {"type": "string"}})),
        tool("read_annotations", "Read decoded rows. Optional query is a substring or A0-10-5A byte pattern.", json!({"query": {"type": "string"}})),
        tool("search_annotations", "Find annotation rows by text or byte pattern.", json!({"query": {"type": "string"}})),
        tool("search_edges", "Next or previous edge or 0/1/x pattern on one channel.", json!({"channel": {"type": "integer"}, "pattern": {"type": "string"}})),
        tool("measure", "Width, period, frequency, and duty at a sample. persist saves it.", json!({"channel": {"type": "integer"}, "sample": {"type": "integer"}})),
        tool("set_cursors", "Place cursors A and B and return the span.", json!({"a": {"type": "integer"}, "b": {"type": "integer"}})),
        tool("export_annotations", "Export decoded rows as csv or text.", json!({"format": {"type": "string"}})),
        tool("list_sessions", "Open session tabs.", json!({})),
    ]
}

fn tool(name: &str, description: &str, properties: Value) -> Value {
    json!({
        "name": name,
        "description": description,
        "inputSchema": {
            "type": "object",
            "properties": properties,
        }
    })
}

fn resource_defs() -> Vec<Value> {
    [
        ("logicview://devices", "Demo pods and connected tested pods"),
        ("logicview://session", "Active capture"),
        ("logicview://catalog/decoders", "Built-in decoder schemas"),
        ("logicview://catalog/profiles", "Logic pod profiles, with untested ids marked"),
    ]
    .into_iter()
    .map(|(uri, description)| json!({"uri": uri, "name": uri, "description": description, "mimeType": "application/json"}))
    .collect()
}

fn prompt_defs() -> Vec<Value> {
    vec![
        json!({"name": "bringup_i2c", "description": "Capture the demo I2C EEPROM transaction and quote the rows."}),
        json!({"name": "bringup_spi", "description": "Capture the demo SPI word and quote MOSI and MISO."}),
        json!({"name": "bringup_uart", "description": "Capture the demo UART line and quote the decoded byte."}),
    ]
}

fn prompt_text(name: &str) -> Option<(&'static str, &'static str)> {
    match name {
        "bringup_i2c" => Some((
            "I2C bring-up on the demo pod",
            "Use the tools in this order and quote the decoded rows back, including address, data, and ACK. Do not summarize them as merely fine.\n\
             1. connect {\"id\":\"demo\"}\n\
             2. configure_logic {\"sample_rate_hz\":1000000,\"duration_ms\":10}\n\
             3. start_capture {}\n\
             4. wait_capture {\"timeout_ms\":10000}\n\
             5. add_decoder {\"protocol\":\"i2c\",\"channels\":{\"scl\":\"SCL\",\"sda\":\"SDA\"}}\n\
             6. add_decoder {\"protocol\":\"eeprom24\"}\n\
             7. read_annotations {}\n\
             The demo fixture is a 24xx-style write of 0x5A at word address 0x10 on 7-bit address 0x50, then a random read of that byte.",
        )),
        "bringup_spi" => Some((
            "SPI bring-up on the stacked demo pod",
            "Use the tools in this order and quote each SPI word (MOSI and MISO). Do not summarize them as merely fine.\n\
             1. connect {\"id\":\"demo\"}\n\
             2. attach_device {\"id\":\"demo:spi\"}\n\
             3. configure_logic {\"sample_rate_hz\":1000000,\"duration_ms\":10}\n\
             4. start_capture {}\n\
             5. wait_capture {\"timeout_ms\":10000}\n\
             6. add_decoder {\"protocol\":\"spi\",\"channels\":{\"sck\":\"demo:spi/SCK\",\"mosi\":\"demo:spi/MOSI\",\"miso\":\"demo:spi/MISO\",\"cs\":\"demo:spi/CS\"}}\n\
             7. read_annotations {\"decoder query\":\"SPI\"} via read_annotations with no filter, then keep the word rows.\n\
             The demo word is mode 0, MSB first, MOSI 0xA5, MISO 0x3C, chip select active low.",
        )),
        "bringup_uart" => Some((
            "UART bring-up on the demo pod",
            "Use the tools in this order and quote the decoded byte and any framing error.\n\
             1. connect {\"id\":\"demo\"}\n\
             2. configure_logic {\"sample_rate_hz\":1000000,\"duration_ms\":10}\n\
             3. start_capture {}\n\
             4. wait_capture {\"timeout_ms\":10000}\n\
             5. add_decoder {\"protocol\":\"uart\",\"channels\":{\"rx\":\"UART\"},\"options\":{\"bit_samples\":\"10\"}}\n\
             6. read_annotations {}\n\
             The demo line is 8N1 idle-high LSB-first at 10 samples per bit and carries 0x55.",
        )),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use logicview_capture::SessionConfig;
    use logicview_engine::{Engine, StartMode};

    async fn rpc(session: &mut McpSession, id: i64, method: &str, params: Value) -> Value {
        session
            .handle(json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params}))
            .await
            .expect("response")
    }

    fn tool_data(response: &Value) -> Value {
        let text = response["result"]["content"][1]["text"]
            .as_str()
            .expect("structured text");
        serde_json::from_str(text).expect("json payload")
    }

    #[tokio::test]
    async fn i2c_and_spi_bringup_reads_decoded_text() {
        let mut session = McpSession::local(Engine::new());
        let init = rpc(
            &mut session,
            1,
            "initialize",
            json!({"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "0"}}),
        )
        .await;
        assert_eq!(init["result"]["serverInfo"]["name"], "logicview");
        assert!(session
            .handle(json!({"jsonrpc": "2.0", "method": "notifications/initialized"}))
            .await
            .is_none());

        let prompt = rpc(
            &mut session,
            2,
            "prompts/get",
            json!({"name": "bringup_i2c"}),
        )
        .await;
        assert!(prompt["result"]["messages"][0]["content"]["text"]
            .as_str()
            .unwrap()
            .contains("0x50"));

        rpc(
            &mut session,
            3,
            "tools/call",
            json!({"name": "attach_device", "arguments": {"id": "demo:spi"}}),
        )
        .await;
        rpc(
            &mut session,
            4,
            "tools/call",
            json!({"name": "configure_logic", "arguments": {"sample_rate_hz": 1_000_000, "duration_ms": 10}}),
        )
        .await;
        let started = rpc(
            &mut session,
            5,
            "tools/call",
            json!({"name": "start_capture", "arguments": {}}),
        )
        .await;
        assert_eq!(started["result"]["isError"], false);
        rpc(
            &mut session,
            6,
            "tools/call",
            json!({"name": "wait_capture", "arguments": {"timeout_ms": 5000}}),
        )
        .await;
        rpc(
            &mut session,
            7,
            "tools/call",
            json!({"name": "add_decoder", "arguments": {"protocol": "i2c", "channels": {"scl": "SCL", "sda": "SDA"}}}),
        )
        .await;
        rpc(
            &mut session,
            8,
            "tools/call",
            json!({"name": "add_decoder", "arguments": {"protocol": "eeprom24"}}),
        )
        .await;
        rpc(
            &mut session,
            9,
            "tools/call",
            json!({"name": "add_decoder", "arguments": {"protocol": "spi", "channels": {"sck": "demo:spi/SCK", "mosi": "demo:spi/MOSI", "miso": "demo:spi/MISO", "cs": "demo:spi/CS"}}}),
        )
        .await;
        let address = rpc(
            &mut session,
            10,
            "tools/call",
            json!({"name": "search_annotations", "arguments": {"query": "Write 0x50"}}),
        )
        .await;
        assert!(address["result"]["content"][0]["text"]
            .as_str()
            .unwrap()
            .contains("Write 0x50"));
        let eeprom = rpc(
            &mut session,
            13,
            "tools/call",
            json!({"name": "search_annotations", "arguments": {"query": "Read 0x10 = 0x5A"}}),
        )
        .await;
        assert!(eeprom["result"]["content"][0]["text"]
            .as_str()
            .unwrap()
            .contains("Read 0x10 = 0x5A"));
        let spi = rpc(
            &mut session,
            14,
            "tools/call",
            json!({"name": "search_annotations", "arguments": {"query": "MOSI 0xA5"}}),
        )
        .await;
        assert!(spi["result"]["content"][0]["text"]
            .as_str()
            .unwrap()
            .contains("MOSI 0xA5 MISO 0x3C"));

        let scope = rpc(
            &mut session,
            11,
            "tools/call",
            json!({"name": "configure_scope", "arguments": {}}),
        )
        .await;
        assert_eq!(scope["result"]["isError"], true);

        let measured = rpc(
            &mut session,
            12,
            "tools/call",
            json!({"name": "measure", "arguments": {"channel": 0, "sample": 75, "persist": true}}),
        )
        .await;
        let metrics = tool_data(&measured);
        assert_eq!(metrics["pulse_width_samples"], 50);
        assert_eq!(metrics["period_samples"], 100);
        assert_eq!(metrics["frequency_hz"], 10_000.0);
        assert_eq!(metrics["duty"], 0.5);
    }

    #[tokio::test]
    async fn attached_client_does_not_reset_a_running_capture() {
        let engine = Engine::new();
        engine
            .configure(
                None,
                SessionConfig {
                    sample_rate_hz: 1_000_000,
                    duration_ms: 5_000,
                    realtime: true,
                    ..SessionConfig::default()
                },
            )
            .await
            .unwrap();
        engine.start(None, StartMode::Normal).await.unwrap();
        let mut before = 0u64;
        for _ in 0..100 {
            tokio::time::sleep(Duration::from_millis(20)).await;
            before = engine.status(None).await.unwrap().sample_count;
            if before > 0 {
                break;
            }
        }
        assert!(before > 0, "capture should be in progress");

        let path =
            std::env::temp_dir().join(format!("logicview-attach-{}.sock", std::process::id()));
        let _ = std::fs::remove_file(&path);
        let server = engine.clone();
        let listen = path.clone();
        tokio::spawn(async move {
            let _ = serve_attach(server, &listen).await;
        });
        let mut remote = None;
        for _ in 0..50 {
            tokio::time::sleep(Duration::from_millis(20)).await;
            if let Ok(session) = McpSession::connect(&path).await {
                remote = Some(session);
                break;
            }
        }
        let mut remote = remote.expect("attach socket");
        let response = rpc(
            &mut remote,
            1,
            "tools/call",
            json!({"name": "start_capture", "arguments": {}}),
        )
        .await;
        let data = tool_data(&response);
        assert_eq!(data["reused"], true);
        assert_eq!(data["capture_id"], "ses-1");
        let after = engine.status(None).await.unwrap();
        assert!(after.sample_count >= before);
        assert_ne!(after.phase, "idle");
        engine.stop(None).await.unwrap();
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn loopback_endpoint_rejects_other_hosts() {
        let addr = parse_loopback_endpoint("127.0.0.1:4174\n").unwrap();
        assert_eq!(addr.port(), 4174);
        assert!(addr.ip().is_loopback());
        assert!(parse_loopback_endpoint("[::1]:9").is_ok());
        assert!(parse_loopback_endpoint("0.0.0.0:1").is_err());
        assert!(parse_loopback_endpoint("192.168.0.2:9").is_err());
        assert!(parse_loopback_endpoint("127.0.0.1:0").is_err());
        assert!(parse_loopback_endpoint("/tmp/logicview.sock").is_err());
    }

    #[test]
    fn attach_location_matches_this_platform() {
        let text = attach_location();
        #[cfg(unix)]
        assert!(text.starts_with("unix socket "), "{text}");
        #[cfg(windows)]
        assert!(text.starts_with("TCP 127.0.0.1 via "), "{text}");
    }
}
