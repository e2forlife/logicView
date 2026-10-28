use std::net::SocketAddr;
use std::path::PathBuf;

use logicview_engine::Engine;
use logicview_ui::serve;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt().with_env_filter(filter).init();

    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("mcp") {
        let attach = args
            .iter()
            .position(|arg| arg == "--attach")
            .and_then(|index| args.get(index + 1))
            .map(PathBuf::from);
        let code = logicview_mcp::run_stdio(attach).await;
        std::process::exit(code);
    }

    let port: u16 = std::env::var("LOGICVIEW_PORT")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(4173);
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let engine = Engine::new();
    let attached = engine.clone();
    let socket = logicview_mcp::default_socket_path();
    tokio::spawn(async move {
        if let Err(err) = logicview_mcp::serve_attach(attached, &socket).await {
            tracing::warn!("attach socket: {err}");
        }
    });
    println!("LogicView UI at http://{addr}");
    println!(
        "MCP attach {} (logicview mcp)",
        logicview_mcp::attach_location()
    );
    if let Err(err) = serve(engine, addr).await {
        eprintln!("logicview: {err}");
        std::process::exit(1);
    }
}
