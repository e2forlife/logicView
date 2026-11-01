#!/usr/bin/env bash
# Install LogicView USB access rules so DreamSourceLab pods can be opened
# (not only listed) without root.
set -euo pipefail
cd "$(dirname "$0")/.."

RULE_SRC="contrib/udev/99-logicview.rules"
RULE_DST="/etc/udev/rules.d/99-logicview.rules"

if [[ ! -f "${RULE_SRC}" ]]; then
  echo "Missing ${RULE_SRC}" >&2
  exit 1
fi

echo "Installing ${RULE_DST} (requires sudo)..."
sudo cp "${RULE_SRC}" "${RULE_DST}"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb --action=add

echo
echo "Unplug and replug the logic analyzer, then confirm the node is writable:"
echo "  ls -l /dev/bus/usb/*/*"
echo "Expect mode 0666 (or an ACL for your user). Restart LogicView and select the pod again."
