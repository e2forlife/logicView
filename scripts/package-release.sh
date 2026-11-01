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
APPDIR="dist/LogicView.AppDir"
APPIMAGE="dist/logicview-${VERSION}-x86_64.AppImage"
TOOL_DIR="${LOGICVIEW_APPIMAGE_TOOL_DIR:-dist/.appimage-tools}"
APPIMAGETOOL="${TOOL_DIR}/appimagetool-x86_64.AppImage"
APPIMAGETOOL_URL="${LOGICVIEW_APPIMAGETOOL_URL:-https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage}"

rm -rf "${STAGE}" "${ARCHIVE}" "${APPDIR}" "${APPIMAGE}"
mkdir -p "${STAGE}/assets" "${STAGE}/examples/decoders" dist

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
  mkdir -p "${STAGE}/contrib/udev" "${STAGE}/scripts"
  cp -f contrib/udev/99-logicview.rules "${STAGE}/contrib/udev/99-logicview.rules"
  cp -f scripts/install-udev.sh "${STAGE}/scripts/install-udev.sh"
  chmod +x "${STAGE}/scripts/install-udev.sh"
fi

tar -C dist -czf "${ARCHIVE}" "logicview-${VERSION}"
echo "Release package: $(pwd)/${ARCHIVE}"

echo "Building LogicView AppImage..."
mkdir -p "${APPDIR}/usr/bin" "${TOOL_DIR}"

# Same relative layout as the tarball, beside the executable, for profile and script discovery.
cp -a "${STAGE}/." "${APPDIR}/usr/bin/"
chmod +x "${APPDIR}/usr/bin/logicview"

cat > "${APPDIR}/logicview.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=LogicView
Comment=Capture and explore logic analyzer signals
Exec=logicview
Icon=logicview
Categories=Development;Electronics;
Terminal=false
StartupNotify=true
EOF

python3 - "${APPDIR}/logicview.png" <<'PY'
from pathlib import Path
import sys
from PIL import Image

dest = Path(sys.argv[1])
src = Path("crates/logicview-ui/assets/icon.png")
image = Image.open(src).convert("RGBA")
image = image.resize((256, 256), Image.Resampling.LANCZOS)
image.save(dest)
PY

cat > "${APPDIR}/AppRun" <<'EOF'
#!/bin/sh
# Thin AppImage: runs the bundled binary against host WebKitGTK / GTK.
# Install runtime packages as documented in README.md (libwebkit2gtk-4.1-0, GTK 3).
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="${HERE}/usr/bin:${PATH}"
cd "${HERE}/usr/bin" || exit 1
exec "${HERE}/usr/bin/logicview" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

if [[ ! -f "${APPIMAGETOOL}" ]]; then
  echo "Downloading appimagetool..."
  curl -fsSL -o "${APPIMAGETOOL}" "${APPIMAGETOOL_URL}"
fi
chmod +x "${APPIMAGETOOL}"
APPIMAGETOOL="$(cd "$(dirname "${APPIMAGETOOL}")" && pwd)/$(basename "${APPIMAGETOOL}")"

# Avoid FUSE on CI and locked-down hosts.
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=x86_64
(
  cd dist
  "${APPIMAGETOOL}" "$(basename "${APPDIR}")" "$(basename "${APPIMAGE}")"
)

if [[ ! -f "${APPIMAGE}" ]]; then
  echo "Missing ${APPIMAGE}" >&2
  exit 1
fi
chmod +x "${APPIMAGE}"
echo "Release package: $(pwd)/${APPIMAGE}"
