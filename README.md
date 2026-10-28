# LogicView

Clean-room Rust logic analyzer. This branch is phases 0–2: the capture
contract, a demo engine, and an Axum waveform shell. No USB, firmware, or FPGA
code is included.

```
cargo test --workspace
cargo run -p logicview-app
```

The UI binds to `127.0.0.1:4173` (override with `LOGICVIEW_PORT`). Press Start.
The demo source streams a clock, a UART-shaped line, an I2C-shaped pair, and a
noisy 1 kHz sine. Drag to pan, scroll to zoom, and hover a trace for pulse
width and period. The `+` button opens another session tab.

## Crates

| Crate | Phase | Role |
| --- | --- | --- |
| `logicview-proto` | 0 | Arm record, logic header, sample atoms, `.dsl` header text |
| `logicview-analysis` | 1 | Edge search and pulse measurements |
| `logicview-capture` | 1 | Demo source, session phases, logic mipmap |
| `logicview-store` | 1 | `.lvcap` directory or zip |
| `logicview-engine` | 1 | Command facade and live events |
| `logicview-ui` | 2 | Axum routes, WebSocket tile frames, waveform shell |
| `logicview-app` | 2 | `logicview` binary |

Device I/O, decoders, and MCP are later phases. See `CONTRIBUTING.md` for the
clean-room rule. The arm record's sample-count shift is locked at 4 until a
real pod is measured.
