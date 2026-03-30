#!/usr/bin/env bash
set -euo pipefail

HOST="${PROJECTION_API_HOST:-127.0.0.1}"
PORT="${PROJECTION_API_PORT:-19100}"
URL="http://$HOST:$PORT/runtime/state"

STATE="${1:-idle}"
DETAIL="${2:-projection push update}"
PROGRESS="${3:-0}"
SOURCE="${4:-projection-push}"

case "$STATE" in
  idle|writing|researching|executing|syncing|error) ;;
  *)
    echo "[ERROR] invalid state: $STATE"
    echo "allowed: idle|writing|researching|executing|syncing|error"
    exit 1
    ;;
esac

if ! [[ "$PROGRESS" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] progress must be integer 0-100"
  exit 1
fi

if (( PROGRESS < 0 )); then PROGRESS=0; fi
if (( PROGRESS > 100 )); then PROGRESS=100; fi

curl -fsS -X POST "$URL" \
  -H "Content-Type: application/json" \
  -d "{\"state\":\"$STATE\",\"detail\":\"$DETAIL\",\"progress\":$PROGRESS,\"source\":\"$SOURCE\"}" >/dev/null

echo "[OK] pushed to $URL => $STATE ($PROGRESS%)"
