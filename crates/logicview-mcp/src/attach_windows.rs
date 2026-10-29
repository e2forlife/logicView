//! TCP localhost attach transport.
//!
//! Tokio does not expose Unix sockets on Windows. Two endpoint forms work:
//!
//! - A filesystem path. The UI binds `127.0.0.1` on an ephemeral port and
//!   writes `host:port` into that file. The MCP client reads the file and
//!   connects with TCP.
//! - A loopback `host:port`, such as `127.0.0.1:4174`. The UI binds that
//!   address and the client connects to it. No file is written.

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::{Path, PathBuf};

use tokio::net::{TcpListener, TcpStream};

#[cfg(not(windows))]
compile_error!("Windows TCP attach is compiled only on Windows");

pub type Stream = TcpStream;

pub struct Listener {
    inner: TcpListener,
    endpoint: String,
}

pub async fn bind(path: &Path) -> std::io::Result<Listener> {
    if let Some(addr) = direct_addr(path) {
        let inner = bind_loopback(addr).await?;
        return Ok(Listener {
            inner,
            endpoint: addr.to_string(),
        });
    }
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)?;
        }
    }
    let _ = std::fs::remove_file(path);
    let inner = bind_loopback(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0)).await?;
    let bound = inner.local_addr()?;
    publish_endpoint(path, bound)?;
    Ok(Listener {
        inner,
        endpoint: path.display().to_string(),
    })
}

async fn bind_loopback(addr: SocketAddr) -> std::io::Result<TcpListener> {
    if !addr.ip().is_loopback() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AddrNotAvailable,
            "attach listener must be loopback",
        ));
    }
    let listener = TcpListener::bind(addr).await?;
    let bound = listener.local_addr()?;
    if !bound.ip().is_loopback() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AddrNotAvailable,
            "attach listener left loopback",
        ));
    }
    Ok(listener)
}

fn direct_addr(path: &Path) -> Option<SocketAddr> {
    let text = path.to_str()?;
    crate::parse_loopback_endpoint(text).ok()
}

fn publish_endpoint(path: &Path, addr: SocketAddr) -> std::io::Result<()> {
    let mut tmp_name = path.as_os_str().to_os_string();
    tmp_name.push(".tmp");
    let tmp = PathBuf::from(tmp_name);
    std::fs::write(&tmp, format!("{addr}\n"))?;
    std::fs::rename(&tmp, path)?;
    Ok(())
}

impl Listener {
    pub async fn accept(&self) -> std::io::Result<Stream> {
        loop {
            let (stream, peer) = self.inner.accept().await?;
            if peer.ip().is_loopback() {
                return Ok(stream);
            }
            drop(stream);
        }
    }

    pub fn label(&self) -> String {
        match self.inner.local_addr() {
            Ok(addr) => format!("tcp {addr} via {}", self.endpoint),
            Err(_) => format!("tcp 127.0.0.1 via {}", self.endpoint),
        }
    }
}

pub async fn connect(path: &Path) -> Result<Stream, String> {
    let addr = if let Some(addr) = direct_addr(path) {
        addr
    } else {
        let text = std::fs::read_to_string(path).map_err(|err| err.to_string())?;
        crate::parse_loopback_endpoint(&text)?
    };
    TcpStream::connect(addr)
        .await
        .map_err(|err| err.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn endpoint_file_points_at_the_loopback_listener() {
        let path = std::env::temp_dir().join(format!(
            "logicview-tcp-{}-{}.sock",
            std::process::id(),
            "win"
        ));
        let _ = std::fs::remove_file(&path);
        let listener = bind(&path).await.expect("bind");
        let text = std::fs::read_to_string(&path).expect("endpoint file");
        let addr = crate::parse_loopback_endpoint(&text).expect("loopback");
        assert_eq!(addr.ip(), IpAddr::V4(Ipv4Addr::LOCALHOST));
        assert_ne!(addr.port(), 0);
        let accept = tokio::spawn(async move {
            let stream = listener.accept().await.expect("accept");
            let _ = stream;
        });
        let stream = connect(&path).await.expect("connect");
        assert_eq!(stream.peer_addr().expect("peer").ip(), addr.ip());
        accept.await.expect("accept task");
        let _ = std::fs::remove_file(&path);
    }

    #[tokio::test]
    async fn host_port_endpoint_binds_without_a_file() {
        let (listener, port) = bind_free_explicit().await;
        let path = PathBuf::from(format!("127.0.0.1:{port}"));
        let accept = tokio::spawn(async move {
            let stream = listener.accept().await.expect("accept");
            let _ = stream;
        });
        let stream = connect(&path).await.expect("connect");
        assert_eq!(stream.peer_addr().expect("peer").port(), port);
        accept.await.expect("accept task");
    }

    async fn bind_free_explicit() -> (Listener, u16) {
        for _ in 0..20 {
            let probe = TcpListener::bind(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0))
                .await
                .expect("probe");
            let port = probe.local_addr().expect("probe addr").port();
            drop(probe);
            let path = PathBuf::from(format!("127.0.0.1:{port}"));
            match bind(&path).await {
                Ok(listener) => return (listener, port),
                Err(err) if err.kind() == std::io::ErrorKind::AddrInUse => continue,
                Err(err) => panic!("bind {path:?}: {err}"),
            }
        }
        panic!("no free loopback port");
    }
}
