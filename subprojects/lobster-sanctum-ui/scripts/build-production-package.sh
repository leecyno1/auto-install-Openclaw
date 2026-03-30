#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PKG_NAME="${PKG_NAME:-lobster-sanctum-runtime}"
OUT_DIR="$DIST_DIR/$PKG_NAME"
ARCHIVE_PATH="$DIST_DIR/${PKG_NAME}.tar.gz"

mkdir -p "$DIST_DIR"
rm -rf "$OUT_DIR" "$ARCHIVE_PATH"
mkdir -p "$OUT_DIR"

if ! command -v rsync >/dev/null 2>&1; then
  echo "[ERROR] rsync is required to build the production package."
  exit 1
fi

rsync -a \
  --delete \
  --exclude '.DS_Store' \
  --exclude '__pycache__/' \
  --exclude '*.pyc' \
  --exclude '*.pyo' \
  --exclude '.pytest_cache/' \
  --exclude '.mypy_cache/' \
  --exclude '.venv/' \
  --exclude 'materials/' \
  --exclude 'tmp/' \
  --exclude 'test-results/' \
  --exclude 'SESSION.md' \
  --exclude 'tmp-sync-f0.png' \
  --exclude 'vendor/star-office-ui/dist/' \
  --exclude 'vendor/star-office-ui/desktop-pet/' \
  --exclude 'vendor/star-office-ui/electron-shell/' \
  --exclude 'vendor/star-office-ui/docs/' \
  --exclude 'vendor/star-office-ui/*.md' \
  --exclude 'vendor/star-office-ui/*.sample.json' \
  --exclude 'vendor/star-office-ui/uv.lock' \
  --exclude 'scripts/test-world-console.sh' \
  "$ROOT_DIR/" "$OUT_DIR/"

cat > "$OUT_DIR/PRODUCTION_NOTES.md" <<'EOF'
# Lobster Sanctum Runtime Package

This package is intentionally trimmed for production deployment.

Excluded on purpose:
- `materials/` development art source and backup packs
- preview screenshots and temporary files
- Electron / desktop shell files
- upstream docs and release artifacts

Runtime policy:
- load only the currently selected role sprite pack
- keep new assets pixel-first and resource-bounded
- avoid adding large non-pixel illustration assets to runtime paths
EOF

tar -C "$DIST_DIR" -czf "$ARCHIVE_PATH" "$PKG_NAME"

echo "[OK] Production package created:"
echo "  directory: $OUT_DIR"
echo "  archive:   $ARCHIVE_PATH"
