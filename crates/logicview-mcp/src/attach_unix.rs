//! Unix-socket attach transport.
//!
//! The path is the socket inode. `logicview mcp` connects to it directly.

use std::path::{Path, PathBuf};

use tokio::net::{UnixListener, UnixStream};

#[cfg(not(unix))]
compile_error!("Unix socket attach is compiled only on Unix");

pub type Stream = UnixStream;

pub struct Listener {
    inner: UnixListener,
    path: PathBuf,
}

pub async fn bind(path: &Path) -> std::io::Result<Listener> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)?;
        }
    }
    let _ = std::fs::remove_file(path);
    let inner = UnixListener::bind(path)?;
    Ok(Listener {
        inner,
        path: path.to_path_buf(),
    })
}

impl Listener {
    pub async fn accept(&self) -> std::io::Result<Stream> {
        let (stream, _) = self.inner.accept().await?;
        Ok(stream)
    }

    pub fn label(&self) -> String {
        format!("unix {}", self.path.display())
    }
}

pub async fn connect(path: &Path) -> Result<Stream, String> {
    UnixStream::connect(path)
        .await
        .map_err(|err| err.to_string())
}
