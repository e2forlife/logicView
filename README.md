# LogicView

Clean-room Rust logic analyzer. Phases 0–4 are the capture contract, the demo
engine, the Axum waveform shell, and buffer/stream capture for one high-speed
DSLogic Plus (`0x2A0E:0x0020`). This tree adds protocol decode (UART, I2C, SPI,
and a 24xx-style EEPROM stack), the data table, and a stdio MCP server.
A session can stack the Demo and Demo SPI pods onto one waveform. Other logic
product ids are listed with their channel counts and are not opened: they have
not been tested on hardware. Oscilloscope and data acquisition are not in this
build. Firmware and the FPGA bitstream are not in this repo. Set
`LOGICVIEW_FIRMWARE_DIR` to the folder that contains `DSLogicPlus.bin` when the
Plus pod's FPGA is not already configured.

```
cargo test --workspace
cargo run -p logicview-app
cargo run -p logicview-app -- mcp
```

On Windows, from this directory:

```
scripts\package-release.cmd
scripts\run-debug.cmd
```

`package-release.cmd` runs `cargo build --release -p logicview-app` and writes
`dist\logicview-<version>-windows.zip`. The archive holds a
`logicview-<version>` folder with `logicview.exe` and the files from
`crates\logicview-ui\assets`. `run-debug.cmd` starts the same app with
`cargo run` (debug build).

The UI binds to `127.0.0.1:4173` (override with `LOGICVIEW_PORT`). `logicview mcp`
attaches to that running engine when the endpoint is up, and otherwise starts
its own demo engine. On Unix the endpoint is a socket at `/tmp/logicview.sock`.
On Windows the UI listens on TCP `127.0.0.1` (ephemeral port) and writes
`127.0.0.1:<port>` into `%TEMP%\logicview.sock`; the MCP client reads that file
and connects over TCP. `LOGICVIEW_SOCKET` overrides the socket path on Unix and
the endpoint file path on Windows. When that value is a loopback
`host:port` such as `127.0.0.1:4174`, Windows binds and connects to that
TCP address. Press Run. Stack **Demo SPI** from the
device drawer to see both pods. Hover a trace for width, period, frequency,
and duty; the measure drawer keeps those readings. Add I2C or SPI from the
analyzers drawer and read the rows in the bottom table. The trigger drawer
takes an ordered list of edges (channel 1 rising, then channel 3 rising,
fires on channel 3). Each step is one stage in the arm record. The demo
source finds that sequence in the captured samples. The same stages are
written for a pod and have not been run on hardware.

## Crates

| Crate | Phase | Role |
| --- | --- | --- |
| `logicview-proto` | 0 | Arm record, logic header, sample atoms, `.dsl` header text |
| `logicview-hal` | 3 | DSLogic Plus USB, FPGA sequencing, buffer capture |
| `logicview-analysis` | 1 | Edge search and pulse measurements |
| `logicview-decode` | 5 | UART, I2C, SPI, and a 24xx EEPROM stack |
| `logicview-capture` | 1 | Demo source, session phases, logic mipmap |
| `logicview-store` | 1 | `.lvcap` directory or zip |
| `logicview-engine` | 1 | Command facade, multi-pod channel list, live events |
| `logicview-mcp` | 6 | stdio MCP and the UI attach endpoint |
| `logicview-ui` | 2 | Axum routes, WebSocket tile frames, waveform shell |
| `logicview-app` | 2 | `logicview` binary |

See `CONTRIBUTING.md` for the clean-room rule. Decoders follow the published
I2C, SPI, UART, and 24C02 sequences, not another project's scripts. The arm
record's sample-count shift is 4, measured on the Plus pod:
packed counts `0x10`, `0x40`, and `0x80` kept 32, 128, and 256 bytes on one
channel.
