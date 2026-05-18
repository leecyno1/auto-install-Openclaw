#!/usr/bin/env bash
set -euo pipefail

VERSION="${GODOT_VERSION:-4.6.2}"
TEMPLATE_VERSION_DIR="${GODOT_TEMPLATE_VERSION_DIR:-${VERSION}.stable}"
TARGET_DIR="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$TEMPLATE_VERSION_DIR}"

ARCHIVE_PATH="${1:-${GODOT_EXPORT_TEMPLATES_TPZ:-}}"

is_valid_zip() {
  python3 - "$1" <<'PY' >/dev/null 2>&1
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as zf:
    zf.infolist()
PY
}

if [[ -z "${ARCHIVE_PATH}" ]]; then
  for candidate in \
    "$PWD/Godot_v${VERSION}-stable_export_templates.tpz" \
    "/tmp/godot-templates/Godot_v${VERSION}-stable_export_templates.tpz" \
    "/tmp/godot-release-fetch/Godot_v${VERSION}-stable_export_templates.tpz" \
    "$HOME/Downloads/Godot_v${VERSION}-stable_export_templates.tpz"
  do
    if [[ -f "$candidate" ]] && is_valid_zip "$candidate"; then
      ARCHIVE_PATH="$candidate"
      break
    fi
  done
fi

if [[ -z "${ARCHIVE_PATH}" ]]; then
  if command -v gh >/dev/null 2>&1; then
    FETCH_DIR="/tmp/godot-release-fetch"
    FETCH_PATH="$FETCH_DIR/Godot_v${VERSION}-stable_export_templates.tpz"
    mkdir -p "$FETCH_DIR"
    echo "Downloading official export templates from github.com/godotengine/godot ..." >&2
    if gh release download "${VERSION}-stable" \
      --repo godotengine/godot \
      --pattern "Godot_v${VERSION}-stable_export_templates.tpz" \
      --output "$FETCH_PATH" \
      --clobber; then
      if is_valid_zip "$FETCH_PATH"; then
        ARCHIVE_PATH="$FETCH_PATH"
      else
        rm -f "$FETCH_PATH"
      fi
    fi
  fi
fi

if [[ -z "${ARCHIVE_PATH}" || ! -f "${ARCHIVE_PATH}" ]]; then
  cat >&2 <<EOF
Godot export templates archive not found.

Provide a local archive path:
  $0 /path/to/Godot_v${VERSION}-stable_export_templates.tpz

Or set:
  GODOT_EXPORT_TEMPLATES_TPZ=/path/to/Godot_v${VERSION}-stable_export_templates.tpz

The script can also auto-download from:
  https://github.com/godotengine/godot
when GitHub CLI (gh) is installed and network is available.
EOF
  exit 1
fi

if ! is_valid_zip "${ARCHIVE_PATH}"; then
  echo "Invalid or incomplete Godot export templates archive: ${ARCHIVE_PATH}" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

python3 - "$ARCHIVE_PATH" "$TARGET_DIR" <<'PY'
import sys
import zipfile
from pathlib import Path

archive = Path(sys.argv[1])
target = Path(sys.argv[2])
need = {
    "web_nothreads_debug.zip",
    "web_nothreads_release.zip",
    "web_threads_debug.zip",
    "web_threads_release.zip",
}

with zipfile.ZipFile(archive) as zf:
    matched = 0
    for member in zf.namelist():
        name = member.rsplit("/", 1)[-1]
        if name in need:
            out = target / name
            out.write_bytes(zf.read(member))
            print(f"installed {name} -> {out}")
            matched += 1

if matched < 2:
    raise SystemExit(
        f"expected at least web_nothreads_debug.zip and web_nothreads_release.zip in {archive}"
    )
PY

echo "Templates installed to: $TARGET_DIR"
