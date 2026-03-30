#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${PROJECTION_API_HOST:-127.0.0.1}"
PORT="${PROJECTION_API_PORT:-19100}"
SERVER_FILE="$ROOT_DIR/projection-api/server.py"
PID_FILE="/tmp/lobster-projection-api-${PORT}.pid"
LOG_FILE="/tmp/lobster-projection-api-${PORT}.log"

usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|status}
  PROJECTION_API_HOST=127.0.0.1 PROJECTION_API_PORT=19100 $0 start
USAGE
}

listen_pid() {
  lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

is_running() {
  [[ -n "$(listen_pid)" ]]
}

start_server() {
  if [[ ! -f "$SERVER_FILE" ]]; then
    echo "[ERROR] Server file missing: $SERVER_FILE"
    exit 1
  fi
  if is_running; then
    local pid
    pid="$(listen_pid)"
    echo "$pid" > "$PID_FILE"
    echo "[INFO] Projection API already running (PID: $pid, http://$HOST:$PORT)"
    return 0
  fi

  nohup python3 "$SERVER_FILE" --host "$HOST" --port "$PORT" >"$LOG_FILE" 2>&1 < /dev/null &
  local pid="$!"

  local ok=0
  for _ in {1..25}; do
    if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 0.2
  done

  if [[ "$ok" -eq 1 ]]; then
    local lp
    lp="$(listen_pid)"
    echo "${lp:-$pid}" > "$PID_FILE"
    echo "[OK] Projection API started: http://$HOST:$PORT (PID: ${lp:-$pid})"
  else
    echo "[ERROR] Projection API failed to start, see log: $LOG_FILE"
    rm -f "$PID_FILE"
    exit 1
  fi
}

stop_server() {
  if ! is_running; then
    echo "[INFO] Projection API not running on port $PORT"
    rm -f "$PID_FILE"
    return 0
  fi
  local pid
  pid="$(listen_pid)"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
    sleep 0.6
    if lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
  echo "[OK] Projection API stopped"
}

status_server() {
  if is_running; then
    local pid
    pid="$(listen_pid)"
    echo "[OK] Projection API running: http://$HOST:$PORT (PID: $pid)"
  else
    echo "[INFO] Projection API not running on port $PORT"
  fi
}

case "${1:-}" in
  start) start_server ;;
  stop) stop_server ;;
  restart) stop_server; start_server ;;
  status) status_server ;;
  *) usage; exit 1 ;;
esac
