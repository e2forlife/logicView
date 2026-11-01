#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building logicview release..."
cargo build --release -p logicview-app

TARGET_DIR="$(cargo metadata --format-version 1 --no-deps | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p')"
if [[ -z "${TARGET_DIR}" ]]; then
  echo "Could not resolve Cargo target directory." >&2
  exit 1
fi

BINARY="${TARGET_DIR}/release/logicview"
if [[ ! -f "${BINARY}" ]]; then
  echo "Missing ${BINARY}" >&2
  exit 1
fi

VERSION="$(cargo pkgid -p logicview-app | sed -n 's/.*#//p')"
if [[ -z "${VERSION}" ]]; then
  echo "Could not read the logicview-app version from cargo pkgid." >&2
  exit 1
fi

STAGE="dist/logicview-${VERSION}"
ARCHIVE="dist/logicview-${VERSION}-linux-x86_64.tar.gz"
rm -rf "${STAGE}" "${ARCHIVE}"
mkdir -p "${STAGE}/assets" "${STAGE}/examples/decoders"

cp -f "${BINARY}" "${STAGE}/logicview"
chmod +x "${STAGE}/logicview"
cp -f profiles.toml "${STAGE}/profiles.toml"
cp -f examples/decoders/high_pulses.lua "${STAGE}/examples/decoders/high_pulses.lua"

if [[ ! -f crates/logicview-ui/assets/index.html ]]; then
  echo "Missing UI assets in crates/logicview-ui/assets" >&2
  exit 1
fi
cp -a crates/logicview-ui/assets/. "${STAGE}/assets/"

if [[ -f contrib/udev/99-logicview.rules ]]; then
  mkdir -p "${STAGE}/contrib/udev"
  cp -f contrib/udev/99-logicview.rules "${STAGE}/contrib/udev/99-logicview.rules"
fi

mkdir -p dist
tar -C dist -czf "${ARCHIVE}" "logicview-${VERSION}"

echo "Release package: $(pwd)/${ARCHIVE}"
