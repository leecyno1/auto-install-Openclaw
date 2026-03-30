#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEED_FILE="$ROOT_DIR/web/runtime-feed.json"

STATE="${1:-idle}"
DETAIL="${2:-外部进程写入状态。}"
PROGRESS="${3:-0}"
SOURCE="${4:-manual-feed}"

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

TIMESTAMP="$(date "+%Y-%m-%dT%H:%M:%S%z")"
TIMESTAMP="${TIMESTAMP:0:22}:${TIMESTAMP:22:2}"

cat > "$FEED_FILE" <<JSON
{
  "state": "$STATE",
  "detail": "$DETAIL",
  "progress": $PROGRESS,
  "updated_at": "$TIMESTAMP",
  "source": "$SOURCE"
}
JSON

echo "[OK] runtime feed updated: $FEED_FILE"
