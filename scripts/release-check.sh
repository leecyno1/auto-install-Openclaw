#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

./scripts/preflight-check.sh >/dev/null || fail "preflight"
pass "preflight"

if rg -n 'sk-[A-Za-z0-9_-]{20,}|sk-cp-|sk-ant-' \
    README.md install.sh config-menu.sh docs scripts openclaw-setup.sh script.sh docker-entrypoint.sh \
    --glob '!tests/**' \
    --glob '!examples/**' \
    --glob '!skills/**' \
    --glob '!subprojects/**' \
    --glob '!scripts/release-check.sh' \
    --glob '!photo/**' \
    --glob '!materials/**' \
    --glob '!.git/**' \
    --glob '!**/__pycache__/**' >/tmp/openclaw-release-secrets.txt; then
    cat /tmp/openclaw-release-secrets.txt
    fail "possible secrets detected"
fi
rm -f /tmp/openclaw-release-secrets.txt 2>/dev/null || true
pass "secret scan"

echo "release check passed"
