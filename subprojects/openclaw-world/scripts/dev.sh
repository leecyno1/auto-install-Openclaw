#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

cleanup() {
  jobs -pr | xargs -r kill >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

npm run dev:gateway &
GATEWAY_PID=$!

npm run dev:client &
CLIENT_PID=$!

wait "$GATEWAY_PID" "$CLIENT_PID"
