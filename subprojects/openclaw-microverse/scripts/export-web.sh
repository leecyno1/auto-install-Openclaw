#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/build/web}"
GODOT_BIN="${GODOT_BIN:-}"
TEMPLATE_DIR="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/4.6.2.stable}"

if [[ -z "$GODOT_BIN" ]]; then
  if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  fi
fi

if [[ -z "$GODOT_BIN" || ! -x "$GODOT_BIN" ]]; then
  echo "Godot binary not found. Set GODOT_BIN or install Godot 4." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" || ! -f "$TEMPLATE_DIR/web_nothreads_debug.zip" ]]; then
  if [[ -n "${GODOT_EXPORT_TEMPLATES_TPZ:-}" && -x "$ROOT_DIR/scripts/install-web-templates.sh" ]]; then
    "$ROOT_DIR/scripts/install-web-templates.sh" "${GODOT_EXPORT_TEMPLATES_TPZ}"
  fi
fi

if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" || ! -f "$TEMPLATE_DIR/web_nothreads_debug.zip" ]]; then
  cat >&2 <<EOF
Missing Godot Web export templates in:
  $TEMPLATE_DIR

Install them first, for example:
  cd "$ROOT_DIR"
  ./scripts/install-web-templates.sh /path/to/Godot_v4.6.2-stable_export_templates.tpz
EOF
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
"$GODOT_BIN" --headless --path "$ROOT_DIR" --export-release Web "$OUTPUT_DIR/index.html"
