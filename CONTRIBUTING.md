# Contributing to LogicView

LogicView is a clean-room Rust logic analyzer. Behavior was learned from public
documentation and from studying how DreamSourceLab instruments and Saleae Logic
are used. The implementation is original.

## Clean-room rule

Do not vendor, translate, or mechanically rewrite DreamSourceLab application
source, libsigrok-style device libraries, protocol-decoder scripts, firmware,
FPGA bitstreams, icons, or test vectors taken from those trees.

- Protocol layouts in `logicview-proto` are specified in this repository and
  locked by hand-written fixtures. Numeric fields that the hardware has not
  confirmed stay marked that way. Do not fill them in by transcribing another
  project.
- Decoders, when they are added, must be written from published bus
  specifications and from captures this project records.
- Firmware and bitstreams are never committed. A later hardware phase may load
  files the user supplies from outside the repository.
- `.dsl` support, when it grows past the header snapshot, must be a fresh
  reader and writer of the observed zip layout.

If a change needs a fact that is not already written down here, measure it or
cite a public document. Do not paste the missing piece from another codebase.

## Tests

```
cargo test --workspace
```

Phase 3 (real USB pods, firmware upload, FPGA programming) is out of scope
until a person runs that work on hardware they have.
