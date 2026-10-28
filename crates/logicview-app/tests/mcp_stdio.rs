use std::io::{BufRead, BufReader, Write};
use std::process::{Command, Stdio};

#[test]
fn stdio_mcp_initializes_without_a_pod() {
    let socket = std::env::temp_dir().join(format!(
        "logicview-missing-{}-{}.sock",
        std::process::id(),
        "stdio"
    ));
    let _ = std::fs::remove_file(&socket);
    let mut child = Command::new(env!("CARGO_BIN_EXE_logicview"))
        .arg("mcp")
        .env("LOGICVIEW_SOCKET", &socket)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .expect("logicview mcp");
    let mut stdin = child.stdin.take().unwrap();
    let mut stdout = BufReader::new(child.stdout.take().unwrap());
    writeln!(
        stdin,
        r#"{{"jsonrpc":"2.0","id":1,"method":"initialize","params":{{"protocolVersion":"2024-11-05","capabilities":{{}},"clientInfo":{{"name":"stdio-test","version":"0"}}}}}}"#
    )
    .unwrap();
    stdin.flush().unwrap();
    let mut line = String::new();
    stdout.read_line(&mut line).unwrap();
    assert!(line.contains("\"name\":\"logicview\""), "{line}");
    drop(stdin);
    let _ = child.wait();
}
