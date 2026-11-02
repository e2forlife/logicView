#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v mksquashfs >/dev/null 2>&1 || ! command -v unsquashfs >/dev/null 2>&1; then
  echo "squashfs-tools is required to package the AppImage icon (mksquashfs and unsquashfs)." >&2
  exit 1
fi

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

ICON_DIR="$(find "${TARGET_DIR}/release/build" -type f -name 'icon-256.png' -printf '%T@ %h\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [[ -z "${ICON_DIR}" || ! -f "${ICON_DIR}/icon-48.png" || ! -f "${ICON_DIR}/icon-64.png" || ! -f "${ICON_DIR}/icon-128.png" ]]; then
  echo "Missing Linux icon PNGs from the logicview-app build." >&2
  exit 1
fi
mkdir -p \
  "${STAGE}/share/applications" \
  "${STAGE}/share/icons/hicolor/48x48/apps" \
  "${STAGE}/share/icons/hicolor/64x64/apps" \
  "${STAGE}/share/icons/hicolor/128x128/apps" \
  "${STAGE}/share/icons/hicolor/256x256/apps" \
  "${STAGE}/scripts"
cp -f contrib/linux/logicview.desktop "${STAGE}/share/applications/logicview.desktop"
cp -f "${ICON_DIR}/icon-48.png" "${STAGE}/share/icons/hicolor/48x48/apps/logicview.png"
cp -f "${ICON_DIR}/icon-64.png" "${STAGE}/share/icons/hicolor/64x64/apps/logicview.png"
cp -f "${ICON_DIR}/icon-128.png" "${STAGE}/share/icons/hicolor/128x128/apps/logicview.png"
cp -f "${ICON_DIR}/icon-256.png" "${STAGE}/share/icons/hicolor/256x256/apps/logicview.png"
cp -f scripts/install-desktop.sh "${STAGE}/scripts/install-desktop.sh"
cp -f contrib/linux/appimage-thumbnailer "${STAGE}/scripts/appimage-thumbnailer"
chmod +x "${STAGE}/scripts/install-desktop.sh" "${STAGE}/scripts/appimage-thumbnailer"

if [[ -f contrib/udev/99-logicview.rules ]]; then
  mkdir -p "${STAGE}/contrib/udev"
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
# Desktop integration reads icons and the desktop file from /usr/share, not from beside the binary.
if [[ -d "${APPDIR}/usr/bin/share" ]]; then
  rm -rf "${APPDIR}/usr/share"
  mv "${APPDIR}/usr/bin/share" "${APPDIR}/usr/share"
fi

# The root names are what AppImage thumbnailers open. .DirIcon is a real PNG,
# not a symlink, so readers that do not follow links still find the artwork.
cp -f contrib/linux/logicview.desktop "${APPDIR}/logicview.desktop"
chmod +x "${APPDIR}/logicview.desktop"
cp -f "${ICON_DIR}/icon-256.png" "${APPDIR}/logicview.png"
cp -f "${ICON_DIR}/icon-256.png" "${APPDIR}/.DirIcon"

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
# appimagetool's bundled mksquashfs writes zstd, which many file-manager
# thumbnailers cannot open. Rebuild the payload with gzip and a regular
# .DirIcon so folder views can show the application icon.
cp -f "${ICON_DIR}/icon-256.png" "${APPDIR}/logicview.png"
cp -f "${ICON_DIR}/icon-256.png" "${APPDIR}/.DirIcon"
python3 contrib/linux/appimage-thumbnailer --recompress "${APPIMAGE}" "${APPDIR}"
chmod +x "${APPIMAGE}"

if [[ -z "${GITHUB_ACTIONS:-}" && -n "${HOME:-}" ]]; then
  python3 contrib/linux/appimage-thumbnailer --install "${ICON_DIR}/icon-256.png" || \
    echo "Could not install the AppImage thumbnailer for this user." >&2
  python3 contrib/linux/appimage-thumbnailer --seed "${APPIMAGE}" || \
    echo "Could not seed the AppImage thumbnail cache." >&2
  ICON_FILE="${HOME}/.local/share/logicview/logicview.png"
  if command -v gio >/dev/null 2>&1 && [[ -f "${ICON_FILE}" ]]; then
    gio set "${APPIMAGE}" metadata::custom-icon "file://${ICON_FILE}" || \
      echo "Could not set the AppImage file-manager icon." >&2
  fi
fi
echo "Release package: $(pwd)/${APPIMAGE}"
