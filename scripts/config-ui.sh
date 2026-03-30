#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORLD_SERVER="$ROOT_DIR/scripts/lobster-world.sh"

usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|status}
  STAR_BACKEND_HOST=0.0.0.0 STAR_BACKEND_PORT=19000 $0 start
USAGE
}

if [[ -x "$WORLD_SERVER" ]]; then
  exec "$WORLD_SERVER" "${1:-}"
fi
echo "[ERROR] World server script not found: $WORLD_SERVER"
exit 1
