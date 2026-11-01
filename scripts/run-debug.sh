#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Debug build: this terminal stays open for logs, and LogicView opens its window.
exec cargo run -p logicview-app -- "$@"
