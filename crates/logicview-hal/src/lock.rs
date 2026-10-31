//! Cross-process lock so hardware tests do not open the pods at the same time.
//!
//! Ignored tests in this crate and in the engine share one lock file. The
//! owner writes its process id. A later test removes the file when that
//! process is gone.

use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant};

/// Held for the duration of one hardware test.
pub struct PodGuard {
    path: PathBuf,
}

/// Waits until no other hardware test owns the pods.
pub fn acquire_test_pod_lock() -> PodGuard {
    let path = std::env::temp_dir().join("logicview-pod.lock");
    let deadline = Instant::now() + Duration::from_secs(180);
    loop {
        match OpenOptions::new().write(true).create_new(true).open(&path) {
            Ok(mut file) => {
                let _ = writeln!(file, "{}", std::process::id());
                let _ = file.flush();
                return PodGuard { path };
            }
            Err(_) => {
                if !lock_is_held(&path) {
                    let _ = std::fs::remove_file(&path);
                    continue;
                }
                if Instant::now() >= deadline {
                    panic!("timed out waiting for the pod test lock");
                }
                thread::sleep(Duration::from_millis(200));
            }
        }
    }
}

/// A lock file with a live owner is held. An empty or dead owner is not.
fn lock_is_held(path: &Path) -> bool {
    let Ok(text) = std::fs::read_to_string(path) else {
        return false;
    };
    if text.trim().is_empty() {
        let recent = std::fs::metadata(path)
            .and_then(|meta| meta.modified())
            .ok()
            .and_then(|modified| modified.elapsed().ok())
            .is_some_and(|age| age < Duration::from_millis(500));
        return recent;
    }
    let Ok(pid) = text.trim().parse::<u32>() else {
        return false;
    };
    if pid == std::process::id() {
        return true;
    }
    process_alive(pid)
}

fn process_alive(pid: u32) -> bool {
    #[cfg(windows)]
    {
        let output = std::process::Command::new("tasklist")
            .args(["/FI", &format!("PID eq {pid}"), "/NH", "/FO", "CSV"])
            .output();
        match output {
            Ok(output) => {
                let text = String::from_utf8_lossy(&output.stdout);
                text.contains(&format!("\"{pid}\""))
            }
            Err(_) => true,
        }
    }
    #[cfg(not(windows))]
    {
        let output = std::process::Command::new("kill")
            .args(["-0", &pid.to_string()])
            .output();
        match output {
            Ok(output) => output.status.success(),
            Err(_) => true,
        }
    }
}

impl Drop for PodGuard {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}
