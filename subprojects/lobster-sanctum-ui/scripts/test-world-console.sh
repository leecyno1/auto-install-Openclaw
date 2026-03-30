#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORLD_HTML="$ROOT/web/world-console.html"
WORLD_JS="$ROOT/web/world-console.js"
ROOT_HTML="$ROOT/vendor/star-office-ui/frontend/index.html"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

[[ -f "$WORLD_HTML" ]] || fail "missing world-console.html"
[[ -f "$WORLD_JS" ]] || fail "missing world-console.js"

grep -q '统一控制台' "$WORLD_HTML" || fail "world-console.html missing unified title"
grep -q 'data-station="role"' "$WORLD_HTML" || fail "world-console.html missing role station nav"
grep -q 'data-station="equipment"' "$WORLD_HTML" || fail "world-console.html missing equipment station nav"
grep -q 'id="worldConsoleFrame"' "$WORLD_HTML" || fail "world-console.html missing iframe shell"
grep -q 'const STATUS_ENDPOINT = "/status"' "$WORLD_JS" || fail "world-console.js missing /status runtime polling"
grep -q "configure.html?tab=role" "$ROOT_HTML" || fail "root pixel world does not route directly into configure workbench"

echo "[PASS] unified world console wiring present"
