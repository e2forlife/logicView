//! Optional loopback MCP HTTP endpoint and its persistent lifecycle.
use crate::AppState;
use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::post,
    Json, Router,
};
use logicview_engine::Engine;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use tokio::{net::TcpListener, sync::Mutex, task::JoinHandle};

#[derive(Clone)]
pub struct Control {
    inner: Arc<Mutex<Running>>,
    attach: bool,
}
impl Default for Control {
    fn default() -> Self {
        Self {
            inner: Arc::new(Mutex::new(Running::default())),
            attach: true,
        }
    }
}
#[derive(Default)]
struct Running {
    task: Option<JoinHandle<()>>,
    attach_task: Option<JoinHandle<()>>,
    active: Option<Arc<AtomicBool>>,
    port: Option<u16>,
}
#[derive(Serialize)]
pub struct Status {
    enabled: bool,
    port: u16,
    active_port: Option<u16>,
    address: String,
}
#[derive(Deserialize)]
pub struct Settings {
    enabled: bool,
    port: u16,
}
impl Control {
    pub async fn restore(&self, engine: Engine) -> Result<(), String> {
        let prefs = logicview_config::load();
        if prefs.mcp_enabled {
            self.set(engine, true, prefs.mcp_port, false).await?;
        }
        Ok(())
    }
    async fn set(
        &self,
        engine: Engine,
        enabled: bool,
        port: u16,
        persist: bool,
    ) -> Result<Status, String> {
        if port == 0 {
            return Err("Port must be between 1 and 65535".into());
        }
        let mut state = self.inner.lock().await;
        let running = state.task.as_ref().is_some_and(|task| !task.is_finished());
        // Bind before committing so a port conflict never leaves the switch enabled.
        let listener = if enabled && !running {
            Some(
                TcpListener::bind((std::net::Ipv4Addr::LOCALHOST, port))
                    .await
                    .map_err(|e| format!("Could not start MCP server on port {port}: {e}"))?,
            )
        } else {
            None
        };
        if persist {
            let mut prefs = logicview_config::load();
            prefs.mcp_enabled = enabled;
            prefs.mcp_port = port;
            logicview_config::save(&prefs)?;
        }
        if !enabled {
            if let Some(active) = state.active.take() {
                active.store(false, Ordering::Release);
            }
            if let Some(task) = state.task.take() {
                task.abort();
                let _ = task.await;
            }
            if let Some(task) = state.attach_task.take() {
                task.abort();
                let _ = task.await;
            }
            state.port = None;
        } else if let Some(listener) = listener {
            let active = Arc::new(AtomicBool::new(true));
            if self.attach {
                let attach_engine = engine.clone();
                let path = logicview_mcp::default_socket_path();
                state.attach_task = Some(tokio::spawn(async move {
                    if let Err(err) = logicview_mcp::serve_attach(attach_engine, &path).await {
                        tracing::warn!("MCP attachment: {err}");
                    }
                }));
            }
            let shared = HttpState {
                engine,
                active: active.clone(),
                port,
            };
            let app = Router::new().route("/mcp", post(rpc)).with_state(shared);
            state.task = Some(tokio::spawn(async move {
                if let Err(err) = axum::serve(listener, app).await {
                    tracing::warn!("MCP server stopped: {err}");
                }
            }));
            state.active = Some(active);
            state.port = Some(port);
        }
        Ok(status_value(&state, port))
    }
}
fn status_value(state: &Running, port: u16) -> Status {
    let enabled = state.task.as_ref().is_some_and(|task| !task.is_finished());
    let active_port = if enabled { state.port } else { None };
    Status {
        enabled,
        port,
        active_port,
        address: format!("http://127.0.0.1:{}/mcp", active_port.unwrap_or(port)),
    }
}
pub async fn status(State(app): State<AppState>) -> Json<Status> {
    let port = logicview_config::load().mcp_port;
    let state = app.mcp.inner.lock().await;
    Json(status_value(&state, port))
}
pub async fn configure(
    State(app): State<AppState>,
    Json(settings): Json<Settings>,
) -> Result<Json<Status>, (StatusCode, String)> {
    app.mcp
        .set(app.engine, settings.enabled, settings.port, true)
        .await
        .map(Json)
        .map_err(|e| (StatusCode::BAD_REQUEST, e))
}
#[derive(Clone)]
struct HttpState {
    engine: Engine,
    active: Arc<AtomicBool>,
    port: u16,
}
async fn rpc(
    State(state): State<HttpState>,
    headers: HeaderMap,
    Json(message): Json<Value>,
) -> Response {
    if !state.active.load(Ordering::Acquire) {
        return StatusCode::SERVICE_UNAVAILABLE.into_response();
    }
    let host = headers
        .get("host")
        .and_then(|h| h.to_str().ok())
        .unwrap_or("");
    let good_host =
        host == format!("127.0.0.1:{}", state.port) || host == format!("localhost:{}", state.port);
    let good_origin = headers.get("origin").map_or(true, |h| {
        h.to_str().ok().is_some_and(|s| {
            s == format!("http://127.0.0.1:{}", state.port)
                || s == format!("http://localhost:{}", state.port)
        })
    });
    if !good_host || !good_origin {
        return StatusCode::FORBIDDEN.into_response();
    }
    let initialize = message.get("method").and_then(Value::as_str) == Some("initialize");
    let mut session = logicview_mcp::McpSession::local(state.engine);
    match session.handle(message).await {
        Some(mut response) => {
            if initialize {
                response["result"]["protocolVersion"] = json!("2025-03-26");
            }
            Json(response).into_response()
        }
        None => StatusCode::ACCEPTED.into_response(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    #[tokio::test]
    async fn starts_responds_keeps_port_until_restart_and_stops() {
        let probe = TcpListener::bind((std::net::Ipv4Addr::LOCALHOST, 0))
            .await
            .unwrap();
        let port = probe.local_addr().unwrap().port();
        drop(probe);
        let control = Control {
            attach: false,
            ..Control::default()
        };
        let engine = Engine::new();
        let started = control
            .set(engine.clone(), true, port, false)
            .await
            .unwrap();
        assert!(started.enabled);
        let body = r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#;
        let mut client = tokio::net::TcpStream::connect((std::net::Ipv4Addr::LOCALHOST, port))
            .await
            .unwrap();
        let request = format!("POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: {}\r\n\r\n{body}", body.len());
        client.write_all(request.as_bytes()).await.unwrap();
        let mut reply = String::new();
        client.read_to_string(&mut reply).await.unwrap();
        assert!(reply.starts_with("HTTP/1.1 200"));
        assert!(reply.contains("2025-03-26"));
        let other_port = if port == 65535 { 65534 } else { port + 1 };
        let pending = control
            .set(engine.clone(), true, other_port, false)
            .await
            .unwrap();
        assert_eq!(pending.port, other_port);
        assert_eq!(pending.active_port, Some(port));
        let stopped = control.set(engine, false, other_port, false).await.unwrap();
        assert!(!stopped.enabled);
        assert!(
            tokio::net::TcpStream::connect((std::net::Ipv4Addr::LOCALHOST, port))
                .await
                .is_err()
        );
    }
    #[tokio::test]
    async fn refuses_non_local_origin() {
        let state = HttpState {
            engine: Engine::new(),
            active: Arc::new(AtomicBool::new(true)),
            port: 8765,
        };
        let mut headers = HeaderMap::new();
        headers.insert("host", "127.0.0.1:8765".parse().unwrap());
        headers.insert("origin", "https://example.com".parse().unwrap());
        let response = rpc(
            State(state),
            headers,
            Json(json!({"jsonrpc":"2.0","id":1,"method":"ping"})),
        )
        .await;
        assert_eq!(response.status(), StatusCode::FORBIDDEN);
    }
}
