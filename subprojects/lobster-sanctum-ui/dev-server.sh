#!/usr/bin/env bash
set -euo pipefail

PORT="${CONFIG_UI_PORT:-18188}"
HOST="${CONFIG_UI_HOST:-0.0.0.0}"
UI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/web" && pwd)"
PID_FILE="/tmp/lobster-sanctum-ui-${PORT}.pid"
LOG_FILE="/tmp/lobster-sanctum-ui-${PORT}.log"

usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|status}
  CONFIG_UI_HOST=0.0.0.0 CONFIG_UI_PORT=18188 $0 start
USAGE
}

listen_pid() {
  lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

is_running() {
  [[ -n "$(listen_pid)" ]]
}

start_server() {
  if [[ ! -d "$UI_DIR" ]]; then
    echo "[ERROR] UI directory not found: $UI_DIR"
    exit 1
  fi
  if is_running; then
    local pid
    pid="$(listen_pid)"
    [[ -n "$pid" ]] && echo "$pid" > "$PID_FILE"
    echo "[INFO] Lobster Sanctum Studio already running (PID: ${pid:-unknown}, port: $PORT)"
    exit 0
  fi

  nohup python3 -m http.server "$PORT" --bind "$HOST" --directory "$UI_DIR" >"$LOG_FILE" 2>&1 < /dev/null &
  local pid="$!"

  local ok=0
  for _ in {1..20}; do
    if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
      ok=1
      break
    fi
    sleep 0.2
  done

  if [[ "$ok" -eq 1 ]]; then
    local lp
    lp="$(listen_pid)"
    echo "${lp:-$pid}" > "$PID_FILE"
    echo "[OK] Lobster Sanctum Studio started: http://$HOST:$PORT (PID: ${lp:-$pid})"
  else
    rm -f "$PID_FILE"
    echo "[ERROR] Failed to start Lobster Sanctum Studio. Check log: $LOG_FILE"
    exit 1
  fi
}

stop_server() {
  if ! is_running; then
    echo "[INFO] Lobster Sanctum Studio not running on port $PORT"
    rm -f "$PID_FILE"
    return 0
  fi

  local pid_file pid_port
  pid_file="$(cat "$PID_FILE" 2>/dev/null || true)"
  pid_port="$(listen_pid)"

  [[ -n "$pid_file" ]] && kill "$pid_file" 2>/dev/null || true
  [[ -n "$pid_port" && "$pid_port" != "$pid_file" ]] && kill "$pid_port" 2>/dev/null || true
  sleep 1
  pid_port="$(listen_pid)"
  [[ -n "$pid_port" ]] && kill -9 "$pid_port" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "[OK] Lobster Sanctum Studio stopped"
}

status_server() {
  if is_running; then
    local pid
    pid="$(listen_pid)"
    echo "[OK] Running: http://$HOST:$PORT (PID: $pid)"
  else
    echo "[INFO] Not running on port $PORT"
  fi
}

case "${1:-}" in
  start) start_server ;;
  stop) stop_server ;;
  restart) stop_server || true; start_server ;;
  status) status_server ;;
  *) usage; exit 1 ;;
esac
