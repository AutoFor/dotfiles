#!/bin/bash
set -euo pipefail

TEXT="$1"

if grep -qi microsoft /proc/version 2>/dev/null; then
  printf '%s' "$TEXT" | clip.exe          # WSL2
elif command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$TEXT" | pbcopy            # macOS
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$TEXT" | xclip -selection clipboard  # Linux X11
elif command -v xsel >/dev/null 2>&1; then
  printf '%s' "$TEXT" | xsel --clipboard --input    # Linux X11
elif command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$TEXT" | wl-copy           # Wayland
else
  echo "⚠ クリップボードツールが見つかりません。手動でコピーしてください:" >&2
  echo "$TEXT" >&2
  exit 1
fi
