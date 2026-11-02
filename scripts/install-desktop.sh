#!/usr/bin/env bash
# Install the LogicView menu entry and icon for the current user, and the
# AppImage thumbnailer that shows the application icon in folder views.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESKTOP_SRC="${ROOT}/share/applications/logicview.desktop"
ICON_ROOT="${ROOT}/share/icons/hicolor"
BINARY="${ROOT}/logicview"
THUMBNAILER="${ROOT}/scripts/appimage-thumbnailer"

if [[ ! -f "${DESKTOP_SRC}" || ! -d "${ICON_ROOT}" || ! -f "${BINARY}" ]]; then
  echo "Run scripts/install-desktop.sh from an extracted LogicView release." >&2
  exit 1
fi

DEST="${HOME}/.local/share"
mkdir -p "${DEST}/applications" "${DEST}/icons/hicolor"
cp -a "${ICON_ROOT}/." "${DEST}/icons/hicolor/"

python3 - "${DESKTOP_SRC}" "${DEST}/applications/logicview.desktop" "${BINARY}" <<'PY'
import sys
from pathlib import Path

source, dest, binary = sys.argv[1:]
lines = []
for line in Path(source).read_text().splitlines():
    if line.startswith("Exec="):
        if any(char in binary for char in ' \t"\\'):
            escaped = binary.replace("\\", "\\\\").replace('"', '\\"')
            line = f'Exec="{escaped}"'
        else:
            line = f"Exec={binary}"
    lines.append(line)
Path(dest).write_text("\n".join(lines) + "\n")
PY
chmod 644 "${DEST}/applications/logicview.desktop"

if [[ -f "${THUMBNAILER}" ]]; then
  python3 "${THUMBNAILER}" --install "${ICON_ROOT}/256x256/apps/logicview.png"
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${DEST}/icons/hicolor" >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${DEST}/applications" >/dev/null 2>&1 || true
fi

echo "Installed the LogicView menu entry and icon for ${HOME}."
echo "Restart the file manager if an open folder does not show the AppImage icon yet."
