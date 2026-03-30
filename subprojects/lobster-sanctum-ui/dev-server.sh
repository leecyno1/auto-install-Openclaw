#!/usr/bin/env bash
set -euo pipefail
PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:${PATH:-}"

PORT="${CONFIG_UI_PORT:-18188}"
HOST="${CONFIG_UI_HOST:-0.0.0.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$ROOT_DIR/web"
ASSET_BUILD_SCRIPT="$ROOT_DIR/scripts/build-runtime-assets.py"
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

listen_pids() {
  lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | sort -u || true
}

is_running() {
  [[ -n "$(listen_pid)" ]]
}

listener_command() {
  local pid
  pid="$(listen_pid)"
  [[ -n "$pid" ]] || return 0
  ps -p "$pid" -o command= 2>/dev/null || true
}

listener_uses_ui_dir() {
  local cmd
  cmd="$(listener_command)"
  [[ "$cmd" == *"--directory $UI_DIR"* ]]
}

spawn_detached_http_server() {
  python3 - "$PORT" "$HOST" "$UI_DIR" "$LOG_FILE" <<'PY'
import subprocess
import sys

port, host, ui_dir, log_file = sys.argv[1:5]
cmd = ["python3", "-m", "http.server", port, "--bind", host, "--directory", ui_dir]
with open(log_file, "ab", buffering=0) as log:
    proc = subprocess.Popen(
        cmd,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True,
    )
print(proc.pid)
PY
}

verify_ui_response() {
  curl -fsS --max-time 2 "http://127.0.0.1:$PORT/index.html" 2>/dev/null | grep -q "人格圣殿"
}

force_release_port() {
  local attempt
  for attempt in {1..6}; do
    local pids
    pids="$(listen_pids)"
    if [[ -z "$pids" ]]; then
      return 0
    fi
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      kill "$pid" 2>/dev/null || true
    done <<< "$pids"
    sleep 0.4
    pids="$(listen_pids)"
    if [[ -z "$pids" ]]; then
      return 0
    fi
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      kill -9 "$pid" 2>/dev/null || true
    done <<< "$pids"
    sleep 0.4
  done

  [[ -z "$(listen_pids)" ]]
}

start_server() {
  if [[ ! -d "$UI_DIR" ]]; then
    echo "[ERROR] UI directory not found: $UI_DIR"
    exit 1
  fi
  if [[ -f "$ASSET_BUILD_SCRIPT" ]]; then
    if python3 "$ASSET_BUILD_SCRIPT" >/dev/null 2>&1; then
      echo "[INFO] Runtime asset manifests refreshed."
    else
      echo "[WARN] Runtime asset manifest refresh failed, continue with existing manifests."
    fi
  fi
  if is_running; then
    local pid
    pid="$(listen_pid)"
    if listener_uses_ui_dir && verify_ui_response; then
      [[ -n "$pid" ]] && echo "$pid" > "$PID_FILE"
      echo "[INFO] Lobster Sanctum Studio already running (PID: ${pid:-unknown}, port: $PORT)"
      exit 0
    fi
    echo "[WARN] Port $PORT is occupied by another service, replacing it for Lobster Sanctum Studio."
    if ! force_release_port; then
      echo "[ERROR] Port $PORT is still occupied after cleanup."
      exit 1
    fi
  fi

  local pid
  pid="$(spawn_detached_http_server)"
  echo "$pid" > "$PID_FILE"

  local ok=0
  for _ in {1..20}; do
    if listener_uses_ui_dir && verify_ui_response; then
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
    if listener_uses_ui_dir && verify_ui_response; then
      echo "[OK] Running: http://$HOST:$PORT (PID: $pid)"
    else
      echo "[WARN] Port $PORT is occupied, but the current listener is not the Lobster Sanctum Studio UI."
      echo "[WARN] Active command: $(listener_command)"
      return 1
    fi
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
