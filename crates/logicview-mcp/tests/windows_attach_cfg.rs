//! Guards the Windows build against Unix socket imports.
//!
//! `cargo test` reads the attach sources. CI also runs
//! `cargo check --target x86_64-pc-windows-msvc`, which compiles the TCP
//! module and skips the Unix module.

#[test]
fn unix_socket_types_stay_behind_cfg() {
    let lib = include_str!("../src/lib.rs");
    let unix = include_str!("../src/attach_unix.rs");
    let windows = include_str!("../src/attach_windows.rs");

    assert!(
        !lib.contains("UnixStream") && !lib.contains("UnixListener"),
        "lib.rs must not name Unix socket types; keep them in the Unix module"
    );
    assert!(
        !windows.contains("UnixStream") && !windows.contains("UnixListener"),
        "the Windows attach module must not name Unix socket types"
    );
    assert!(
        windows.contains("TcpListener"),
        "Windows attach must listen with TcpListener"
    );
    assert!(
        windows.contains("Ipv4Addr::LOCALHOST"),
        "Windows attach must bind loopback"
    );
    assert!(
        unix.contains("UnixListener") && unix.contains("compile_error!"),
        "Unix attach must keep the socket listener and refuse other targets"
    );
    assert!(
        windows.contains("compile_error!"),
        "Windows attach must refuse to compile off Windows"
    );
    assert!(
        !unix.contains("TcpListener"),
        "Unix attach keeps the socket path"
    );

    assert_cfg_gated(lib, "attach_unix", "#[cfg(unix)]");
    assert_cfg_gated(lib, "attach_windows", "#[cfg(windows)]");
}

fn assert_cfg_gated(src: &str, module: &str, cfg: &str) {
    let lines: Vec<&str> = src.lines().collect();
    let needle = format!("mod {module};");
    let mut found = 0;
    for (index, line) in lines.iter().enumerate() {
        if line.trim() == needle {
            found += 1;
            let previous = lines.get(index.wrapping_sub(1)).copied().unwrap_or("");
            assert_eq!(
                previous.trim(),
                cfg,
                "{module} must be compiled only under {cfg}"
            );
        }
    }
    assert_eq!(found, 1, "expected one `{needle}`");
}
