#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

"${GODOT_BIN}" \
  --headless \
  --path "${PROJECT_DIR}" \
  --import

"${GODOT_BIN}" \
  --display-driver x11 \
  --rendering-driver opengl3 \
  --audio-driver Dummy \
  --path "${PROJECT_DIR}" \
  --script res://scripts/capture_play_select.gd \
  "$@"
