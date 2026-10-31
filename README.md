<p align="center">
  <img src="crates/logicview-ui/assets/icon.png" alt="LogicView icon" width="128">
</p>

# LogicView

LogicView is an open-source project for capturing and exploring signals and building an extensible platform for laboratory hardware. It aims to bring USB- and Ethernet-connected devices into a consistent workspace, from logic analyzers to rack instruments controlled using SCPI. Current hardware work focuses on DSLogic logic analyzers; broader device and instrument support is a future goal.

LogicView is an independent project and is not affiliated with DreamSourceLab.

## Project status

LogicView is in early development. The Rust workspace includes a desktop waveform interface, a capture engine, simulated devices, protocol decoders, and a Model Context Protocol (MCP) server. You can explore the interface with the demo devices without connecting hardware.

- **Hardware:** Buffer and stream captures have been checked on one DSLogic Plus (`0x2A0E:0x0020`) and one DSLogic U3Pro32 (`0x2A0E:0x002C`). A short combined buffer capture of both pods in one session was checked. Stream and a hardware trigger were not part of that combined check. Other listed DSLogic models cannot currently be opened and have not been tested.
- **Analysis:** Waveform measurements and UART, I2C, SPI, and 24xx-style EEPROM decoding are available. The interface includes a data table and an ordered edge-trigger interface; hardware trigger stages have not been verified on a pod.
- **Platforms:** Windows and Linux desktop builds are the current focus. macOS, Android, and iOS are goals for future investigation, not supported releases. Mobile support depends on platform and hardware-access constraints.
- **Scope:** SCPI instruments, Ethernet-connected devices, oscilloscopes, and data acquisition are not supported in the current build.

See [Mission and vision](MISSION.md) for the project's direction and [Contributing](CONTRIBUTING.md) for ways to help.

## Get started

Install the stable [Rust toolchain](https://www.rust-lang.org/tools/install). On Linux, the desktop build also requires WebKitGTK 4.1, GTK 3, and pkg-config development packages. On Windows, the desktop window uses WebView2.

```sh
cargo test --workspace
cargo run -p logicview-app
```

The app opens a desktop window and serves its interface on loopback port `4173`. Set `LOGICVIEW_PORT` to choose a different port. Press **Run** to use the demo source; add **Demo SPI** from the device drawer to see multiple demo pods on the waveform. The analyzers drawer adds protocol decoders, and the measurement drawer keeps waveform readings.

For supported hardware, firmware and FPGA bitstreams are not included in the repository. If the pod's FPGA is not already configured, set `LOGICVIEW_FIRMWARE_DIR` to a directory containing the appropriate user-supplied `DSLogicPlus.bin` or `DSLogicU3Pro32.bin`. See [Contributing](CONTRIBUTING.md) before working with hardware or reference materials.

## Preferences and extensions

Use the gear in the upper right to set the firmware directory, Lua decoder script directory, and light, dark, or system theme. Preferences persist across launches. A blank firmware directory uses the standard search locations; `LOGICVIEW_FIRMWARE_DIR` takes precedence. On Windows preferences are stored in `%APPDATA%\LogicView\preferences.json`; on Linux they use `XDG_CONFIG_HOME` or `~/.config/LogicView`.

Device identities, USB IDs, channel counts, bitstream filenames, and tested status are in [profiles.toml](profiles.toml). LogicView loads this file at startup from `LOGICVIEW_PROFILES`, the working directory, or beside the executable, and falls back to bundled defaults. Restart after editing it. Profiles describe hardware; the current USB capture implementation still supports only the Plus and U3Pro32 backends. Adding another ID or marking it tested does not implement its hardware protocol or make it safe to open.

### Lua decoders

Lua 5.5 scripts can be used alongside built-in Rust decoders. A blank decoder-script directory uses [examples/decoders](examples/decoders), which holds the translated DSView protocol decoders. Set another directory in Preferences to use your own scripts. Files ending in `.lua` in that directory are discovered when the application starts and when Preferences are saved. [high_pulses.lua](examples/decoders/high_pulses.lua) is a small tutorial; [session_edges.lua](examples/decoders/session_edges.lua) shows the session API.

For a step-by-step guide to writing, configuring, testing, and stacking decoders, see the [Lua decoder tutorial](docs/lua-decoders.md).

Each script returns a table with unique `id`, `name`, `channels`, `classes`, and a `decode(start_sample, end_sample, bit, options, context)` function. Sample indexes are absolute and the end is exclusive. `bit(channel_name, sample)` returns a Boolean; a disconnected channel reads low. `context.connected` identifies mapped channels, and `context.sample_rate_hz` gives the capture rate when available. A script may declare `options` as a list of tables with string `id`, `name` or `desc`, and `default`, plus an optional `values` list; the settings dialog exposes them and passes their string values to `decode`. A script may declare `stack_on` as the protocol ID of its parent; `context.lower` contains that instance's annotations and `context.packets` contains its structured protocol packets. Return an array of annotations with `start_sample`, `end_sample`, `class`, `text`, and an optional string-to-string `fields` table. Alternatively return `{ annotations = {...}, packets = {...} }`: each packet has `start_sample`, `end_sample`, `kind`, and JSON-compatible `data`. Ranges must be inside the requested capture region. The built-in SPI decoder emits `DATA` packets with numeric `mosi` and `miso` fields, and `CS-CHANGE` packets with Boolean `old`, `new`, and `selected` fields; missing SPI data lines are represented as null.

Set `api_version` to 3 to use the session host instead of that callback. It follows the [sigrok protocol decoder API](https://sigrok.org/wiki/Protocol_decoder_API): `start`, `reset`, and `metadata`, then `register`, `wait`, and `put` for annotation, Python, binary, and metadata outputs. [session_edges.lua](examples/decoders/session_edges.lua) is a complete session script. The [Lua decoder tutorial](docs/lua-decoders.md) describes both forms. The built-in decoder IDs take precedence over scripts with the same ID. Scripts run with limited standard libraries, memory, and instruction count; errors are logged and yield no annotations.

The same directory contains a Lua translation of the DSView decoder set. Stacked decoders keep their sigrok inputs, so a script that reads `spi`, `i2c`, or `uart` can stack on the translated parent (`1:spi`, `1:i2c`, or `1:uart`) as well as on the built-in decoder with that id. Shorter adaptations of the [7-segment display](examples/decoders/dsview_seven_segment.lua), [stepper motor](examples/decoders/dsview_stepper_motor.lua), [edge counter](examples/decoders/dsview_counter.lua), [PWM](examples/decoders/dsview_pwm.lua), [NES gamepad](examples/decoders/dsview_nes_gamepad.lua), [RGB LED SPI](examples/decoders/dsview_rgb_led_spi.lua), and [ADNS-5020](examples/decoders/dsview_adns5020.lua) decoders remain available under their `dsview_` ids. The NES adaptation stacks on an SPI decoder configured for eight-bit MSB-first MISO words; the RGB and ADNS adaptations use eight-bit MOSI words. The stepper position is relative to the selected region.

## Device support

The following inventory is based on the device profiles in the bundled DSView reference (`libsigrok4DSL/hardware/DSL/dsl.h`). All physical devices use USB vendor ID `2a0e`. **Tested** means buffer and stream capture were checked on one physical device; it does not mean every feature or unit has been verified. **Not implemented** means the reference supports the model, but LogicView cannot open it for capture. Merely identifying a USB device does not constitute capture support.

| Device | USB product ID | LogicView status | DSView FPGA image |
| --- | --- | --- | --- |
| DSLogic | `0001` | Not implemented | `DSLogic33.bin` / `DSLogic50.bin` |
| DSLogic Pro | `0003` | Not implemented | `DSLogicPro.bin` |
| DSLogic Plus | `0020` | Tested on hardware | `DSLogicPlus.bin` |
| DSLogic Basic | `0021` | Not implemented | `DSLogicBasic.bin` |
| DSLogic U2Basic | `0029` | Not implemented | `DSLogicU2Basic.bin` |
| DSLogic U3Pro16 | `002a` | Not implemented | `DSLogicU3Pro16.bin` |
| DSLogic U3Pro32 | `002c` | Tested on hardware | `DSLogicU3Pro32.bin` |
| DSLogic U2Pro16 | `002d` | Not implemented | `DSLogicU2Pro16.bin` |
| DSLogic Plus (Pango) | `0030` | Not implemented | `DSLogicPlus-pgl12.bin` |
| DSLogic U2Basic (Pango) | `0031` | Not implemented | `DSLogicU2Basic-pgl12.bin` |
| DSLogic Plus (Pango v2) | `0034` | Not implemented | `DSLogicPlus-pgl12-2.bin` |
| DSLogic U2Basic (Pango v2) | `0035` | Not implemented | `DSLogicU2Basic-pgl12-2.bin` |
| DSCope | `0002` | Not implemented | `DSCope.bin` |
| DSCope20 | `0004` | Not implemented | `DSCope20.bin` |
| DSCope B20 | `0022` | Not implemented | `DSCope20.bin` |
| DSCope C20 | `0023` | Not implemented | `DSCopeC20P.bin` |
| DSCope C20P | `0024` | Not implemented | `DSCopeC20P.bin` |
| DSCope C20 | `0025` | Not implemented | `DSCopeC20B.bin` |
| DSCope U2B20 | `0026` | Not implemented | `DSCopeU2B20.bin` |
| DSCope U2P20 | `0027` | Not implemented | `DSCopeU2P20.bin` |
| DSCope U2B100 | `0028` | Not implemented | `DSCopeU2B100.bin` |
| DSCope U3P100 | `002b` | Not implemented | `DSCopeU3P100.bin` |

DSView uses USB vendor control requests (`b0`, `b1`, `b2`) for device commands, bulk endpoint `02` for FPGA configuration and capture setup, and bulk endpoint `86` for capture data. It also uploads USB-controller firmware using vendor request `a0` when needed. LogicView currently expects the USB controller firmware to be running and implements the capture path only for the two tested models. Other models have different capabilities and initialization requirements; the shared transport alone does not make them supported.

Obtain FPGA images and any required USB-controller firmware from [DreamSourceLab's DSView project](https://github.com/DreamSourceLab/DSView) or its distributions. DSView profiles name both `.fw` controller firmware and `.bin` FPGA images; availability may vary by distribution. LogicView loads the two supported `.bin` files from `LOGICVIEW_FIRMWARE_DIR` (or its other documented search locations), but does not upload `.fw` files. No firmware or bitstreams are distributed with LogicView.

### Windows packaging

From the repository directory:

```bat
scripts\package-release.cmd
scripts\run-debug.cmd
```

The packaging script builds a release executable and writes `dist\logicview-<version>-windows.zip`, including the UI assets. Extract the archive and run `logicview.exe`. The debug script keeps a console open for logs.

### MCP server

```sh
cargo run -p logicview-app -- mcp
```

The robot button in the lower-right corner controls the MCP server. It is off by default; enable it to expose a loopback HTTP endpoint at `http://127.0.0.1:8765/mcp` (or the configured port). Changes to the port take effect after disabling and re-enabling the server. The enabled state and port persist between launches. The stdio MCP server attaches to the running engine when the desktop MCP server is enabled; otherwise it starts its own demo engine. On Unix the default endpoint is `/tmp/logicview.sock`. On Windows, the running UI writes its loopback TCP endpoint to `%TEMP%\logicview.sock`. `LOGICVIEW_SOCKET` overrides the Unix socket path or Windows endpoint file path; on Windows a loopback `host:port` value specifies a TCP address instead.

## Architecture

| Crate | Responsibility |
| --- | --- |
| `logicview-proto` | Hardware protocol records, sample data, and `.dsl` header text |
| `logicview-hal` | Device profiles, USB hardware access, FPGA setup, and capture |
| `logicview-capture` | Capture sessions, demo sources, and waveform data |
| `logicview-analysis` | Edge search and pulse measurements |
| `logicview-decode` | Protocol decoders |
| `logicview-store` | `.lvcap` capture storage |
| `logicview-engine` | Commands, device sessions, and live events |
| `logicview-mcp` | MCP server and engine attachment |
| `logicview-ui` | Web interface and waveform transport |
| `logicview-app` | Desktop application and executable |

## Contributing

Contributions are welcome, including device research, hardware testing, documentation, accessibility, platform support, and protocol analysis. Please read [CONTRIBUTING.md](CONTRIBUTING.md), especially its clean-room rules, before starting.

## License

Copyright (C) 2026 Chuck

LogicView is licensed under the GNU General Public License, version 3 or any later version (`GPL-3.0-or-later`). The full license text is in [LICENSE.md](LICENSE.md).
