# Linux troubleshooting for LogicView pods

This guide covers common problems when using LogicView on Linux with DreamSourceLab USB logic analyzers (currently the DSLogic Plus and DSLogic U3Pro32). Demo captures do not need USB permissions or firmware files.

For build and packaging basics, see the [README](../README.md). For hardware research rules, see [Contributing](../CONTRIBUTING.md).

## Quick checks

1. Confirm the pod is visible to the system:
   ```sh
   lsusb -d 2a0e:
   ```
   You should see vendor `2a0e` and a product id such as `0020` (Plus) or `002c` (U3Pro32).

2. Confirm LogicView can list it: the device drawer should show **Detected: DSLogic …**. Listing only needs sysfs; it does **not** prove the pod can be opened.

3. Confirm the USB device node is writable by your user:
   ```sh
   ls -l /dev/bus/usb/*/*
   ```
   After the udev rule is installed and the pod is replugged, expect mode `0666` or an ACL for your session.

4. If open fails, read the status line or the alert dialog. The message usually names permissions or a missing FPGA bitstream.

## Pod is detected but selection snaps back to Demo

**Symptom:** The drawer shows the analyzer, but choosing it leaves the session on Demo.

**Cause:** LogicView lists DreamSourceLab devices without opening them. Selecting a tested model opens the USB interface, checks firmware, and may load an FPGA bitstream. If that open fails, the active session stays on Demo.

### Fix USB permissions

Install the project udev rule, then unplug and replug the analyzer:

```sh
# from a source checkout or an extracted release package
scripts/install-udev.sh
```

Or manually:

```sh
sudo cp contrib/udev/99-logicview.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Then:

```sh
lsusb -d 2a0e:
# note bus and device, then:
ls -l /dev/bus/usb/BBB/DDD
```

If the node is still `root:root` with mode `0644`/`0664` and no user ACL, the rule did not apply. Replug the cable, try another port, and confirm the rule file is named exactly `99-logicview.rules` under `/etc/udev/rules.d/`.

Do not leave DSView or another LogicView instance holding the device. Quit other tools and replug if open reports the device is busy.

### Missing FPGA bitstream

**Symptom:** An alert or status text about `DSLogicPlus.bin` / `DSLogicU3Pro32.bin` not found.

LogicView does not ship firmware or bitstreams. If the pod's FPGA is not already configured, provide the matching `.bin` file:

- Set **Preferences → firmware directory**, or
- Export `LOGICVIEW_FIRMWARE_DIR` to that folder, or
- Place files under a conventional Linux path such as `~/.local/share/LogicView/firmware` or a DSView `res` directory.

`LOGICVIEW_FIRMWARE_DIR` wins over Preferences and conventional paths. Restart LogicView after changing the directory.

LogicView does **not** upload USB-controller `.fw` files. The controller firmware must already be running on the pod.

### Untested product ids

Other DreamSourceLab ids may appear as Detected. Only profiles marked tested (Plus `0x0020`, U3Pro32 `0x002C` in the bundled `profiles.toml`) can be opened. Choosing an untested id shows a warning and does not switch the session off Demo.

## Capture ends with a burst of edges (fill noise)

**Symptom:** A buffer capture looks clean, then ends in a dense alternating pattern on the enabled channels.

Full-buffer uploads can append SRAM fill (`0x55` / `0xAA`). Current LogicView builds drop that shared trailing fill when finishing a capture, including single-channel captures. If you still see the burst:

- Rebuild or reinstall a current Linux package (AppImage or tarball); older packages kept one-wire fill.
- Confirm you are not looking at a live, unfinished capture.
- A real high-rate clock on every enabled channel for the whole record is kept; only a trailing fill suffix is removed.

## App will not start (WebKit / GTK)

Desktop LogicView needs WebKitGTK 4.1 and GTK 3 at runtime. On Debian/Ubuntu:

```sh
# build
sudo apt-get install -y libwebkit2gtk-4.1-dev libgtk-3-dev pkg-config

# runtime (often already pulled in by the -dev packages)
sudo apt-get install -y libwebkit2gtk-4.1-0 libgtk-3-0
```

The thin AppImage uses **host** WebKitGTK; it is not a fully self-contained WebKit bundle. Install the runtime libraries on the machine that runs the AppImage.

## Preferences and paths on Linux

| Item | Location |
| --- | --- |
| Preferences | `$XDG_CONFIG_HOME/LogicView/preferences.json` or `~/.config/LogicView/preferences.json` |
| Optional firmware dir | Preferences, `LOGICVIEW_FIRMWARE_DIR`, or `~/.local/share/LogicView/firmware` |
| Profiles | `LOGICVIEW_PROFILES`, working directory `profiles.toml`, or beside the executable |
| UI port | `127.0.0.1:4173` (override with `LOGICVIEW_PORT`) |
| MCP HTTP (when enabled) | `http://127.0.0.1:8765/mcp` by default |

Override the preferences file with `LOGICVIEW_CONFIG_FILE` if needed.

## MCP endpoint

The robot control in the UI starts a loopback MCP HTTP server when enabled. Defaults use port `8765`.

- Enabled: `curl` or an MCP client can reach `http://127.0.0.1:8765/mcp`.
- Disabled: nothing listens on that port; connection refused is expected.
- The desktop UI can still run on port `4173` while MCP is off.

Stdio MCP (`logicview mcp`) attaches to a running desktop engine when MCP is enabled; otherwise it uses its own demo engine. On Linux the attach socket defaults to `/tmp/logicview.sock` (`LOGICVIEW_SOCKET` overrides it).

## Packaging notes

From the repository:

```sh
scripts/package-release.sh
```

Produces:

- `dist/logicview-<version>-linux-x86_64.tar.gz`
- `dist/logicview-<version>-x86_64.AppImage`

Release packages include `contrib/udev/99-logicview.rules` and `scripts/install-udev.sh`. Installing the AppImage or extracting the tarball does **not** install udev rules automatically; run the helper once per machine.

## Hardware tests (optional)

Ignored HAL tests exercise a connected pod:

```sh
cargo test -p logicview-hal -- --ignored
```

Report the OS, model, USB product id, firmware/bitstream setup, and exact errors when filing issues. A result on one unit does not establish support for every model.

## Still stuck?

Collect:

- Output of `lsusb -d 2a0e:` and `ls -l` on the matching `/dev/bus/usb/...` node
- Whether `contrib/udev/99-logicview.rules` is installed
- The exact status or alert text when selecting the pod
- Whether Preferences / `LOGICVIEW_FIRMWARE_DIR` points at the `.bin` files
- LogicView version or package type (source, tarball, AppImage)

Open an issue with that information after removing any sensitive paths or captures.
