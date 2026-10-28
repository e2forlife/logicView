use std::net::SocketAddr;

use logicview_engine::Engine;
use logicview_ui::serve;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt().with_env_filter(filter).init();

    let port: u16 = std::env::var("LOGICVIEW_PORT")
        .ok()
        .and_then(|value| value.parse().ok())
        .unwrap_or(4173);
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    println!("LogicView demo UI at http://{addr}");
    if let Err(err) = serve(Engine::new(), addr).await {
        eprintln!("logicview: {err}");
        std::process::exit(1);
    }
}
