# LogicView

Clean-room Rust logic analyzer. Phases 0–2 are the capture contract, the demo
engine, and the Axum waveform shell. Phases 3–4 add buffer and stream capture
for one high-speed DSLogic Plus (`0x2A0E:0x0020`). Firmware and the FPGA
bitstream are not in this repo. Set `LOGICVIEW_FIRMWARE_DIR` to the folder
that contains `DSLogicPlus.bin` when the pod's FPGA is not already configured.

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
| `logicview-hal` | 3 | DSLogic Plus USB, FPGA sequencing, buffer capture |
| `logicview-analysis` | 1 | Edge search and pulse measurements |
| `logicview-capture` | 1 | Demo source, session phases, logic mipmap |
| `logicview-store` | 1 | `.lvcap` directory or zip |
| `logicview-engine` | 1 | Command facade and live events |
| `logicview-ui` | 2 | Axum routes, WebSocket tile frames, waveform shell |
| `logicview-app` | 2 | `logicview` binary |

Decoders and MCP are later phases. See `CONTRIBUTING.md` for the clean-room
rule. The arm record's sample-count shift is 4, measured on the Plus pod:
packed counts `0x10`, `0x40`, and `0x80` kept 32, 128, and 256 bytes on one
channel.
