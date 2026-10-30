# Contributing to LogicView

Thank you for helping make laboratory tools more open and accessible. Contributions can include documentation, bug reports, hardware testing, protocol research, accessibility improvements, and support for additional devices and platforms.

## Before you begin

For a substantial change or new hardware backend, open an issue first to describe the goal, proposed approach, and any hardware or platform constraints. For a bug, include steps to reproduce it, the expected and actual behavior, your operating system, and relevant logs. For hardware reports, include the device model, connection type, USB product ID or network interface details, and relevant instrument or capture settings when available; remove sensitive data from logs and captures.

## Original implementation and research

LogicView aims to implement device support and application behavior independently. Do not copy, vendor, translate, or mechanically rewrite source code, decoder scripts, user interface assets, test vectors, or other material from another published application into LogicView. This applies regardless of the other application's license. Do not commit firmware or FPGA bitstreams; the application may load user-supplied files from outside the repository.

Research is welcome. Contributors may study published specifications, device manuals, command descriptions, code examples, and application interfaces to understand device behavior, protocols, and workflows. They may also observe hardware communication and record their own captures where permitted. Follow applicable licenses, access restrictions, and other requirements when consulting materials or examining devices.

- Use what you learn to write an independent implementation; do not transplant or mechanically adapt example code or another application's implementation. Facts such as protocol commands and field meanings can be documented, with sources or measurements identified.
- Document sources, observations, assumptions, and test conditions. Mark behavior and fields that have not been confirmed on hardware as unverified.
- Write decoders and tests using published specifications and independently created fixtures or captures. Do not take another application's test vectors or scripts.
- For file formats, implement readers and writers independently using documented or observed format details rather than copying another application's implementation.
- If a source's terms or a proposed contribution raise questions, discuss them in an issue before including the material.

## Development and review

1. Fork the repository and create a branch for your change.
2. Make a focused change and update the documentation when behavior or requirements change.
3. Run `cargo test --workspace`. Add or update meaningful tests when appropriate, and describe any checks you could not run.
4. Open a pull request describing the problem, the change, how it was tested, and any remaining limitations. Link related issues and include screenshots for visible interface changes when useful.
5. Respond constructively to review and keep discussion respectful and welcoming.

The CI configuration also checks a Windows release build and rejects firmware and bitstream blobs. Linux development of the desktop app requires WebKitGTK 4.1, GTK 3, and pkg-config development packages.

## Hardware testing

The current logic analyzer hardware tests are ignored by default and require a compatible connected pod:

```sh
cargo test -p logicview-hal -- --ignored
```

The Plus USB path loads the user-supplied `DSLogicPlus.bin` from `LOGICVIEW_FIRMWARE_DIR` only if the FPGA done bit is clear. Do not commit that file. Describe the exact model, connection, test conditions, and results when reporting hardware behavior; a result from one device does not establish support for every model.

## Licensing

LogicView is licensed under the GNU General Public License, version 3 or any later version (`GPL-3.0-or-later`). Contributions are accepted under those terms. See [LICENSE.md](LICENSE.md). If your contribution includes third-party material, identify its source and license; do not assume it can be included.
