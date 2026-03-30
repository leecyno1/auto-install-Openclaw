#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/subprojects/lobster-sanctum-ui/vendor/star-office-ui/backend"
REQUIREMENTS_FILE="$BACKEND_DIR/requirements.txt"
PORT="${STAR_BACKEND_PORT:-19000}"
HOST="${STAR_BACKEND_HOST:-0.0.0.0}"
PID_FILE="/tmp/lobster-world-${PORT}.pid"
LOG_FILE="/tmp/lobster-world-${PORT}.log"
VENV_DIR="$BACKEND_DIR/.venv"
TMP_VENV="/tmp/lobster-star-office-venv"
THEME_MARKER="$HOME/.openclaw/profile/lobster-theme-initialized"

usage() {
  cat <<USAGE
Usage: $0 {start|stop|restart|status}
  STAR_BACKEND_HOST=0.0.0.0 STAR_BACKEND_PORT=19000 $0 start
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

verify_world_response() {
  curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" 2>/dev/null | grep -q '"status":"ok"'
}

apply_default_theme_once() {
  if [[ -f "$THEME_MARKER" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$THEME_MARKER")" >/dev/null 2>&1 || true
  if curl -fsS --max-time 8 -X POST "http://127.0.0.1:$PORT/openclaw/theme/red-blue-default" >/dev/null 2>&1; then
    touch "$THEME_MARKER"
    echo "[INFO] Applied default red-blue pixel house theme."
    return 0
  fi
  echo "[WARN] Unable to apply default red-blue theme now; you can retry from menu."
  return 1
}

spawn_detached_world_server() {
  local py_bin="$1"
  "$py_bin" - "$py_bin" "$PORT" "$HOST" "$BACKEND_DIR" "$LOG_FILE" <<'PY'
import os
import subprocess
import sys

py_bin, port, host, cwd, log_file = sys.argv[1:6]
cmd = [py_bin, "app.py"]
env = os.environ.copy()
env["STAR_BACKEND_PORT"] = port
env["STAR_BACKEND_HOST"] = host
with open(log_file, "ab", buffering=0) as log:
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
        close_fds=True,
    )
print(proc.pid)
PY
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
    [[ -z "$pids" ]] && return 0
    while IFS= read -r pid; do
      [[ -z "$pid" ]] && continue
      kill -9 "$pid" 2>/dev/null || true
    done <<< "$pids"
    sleep 0.4
  done

  [[ -z "$(listen_pids)" ]]
}

python_has_modules() {
  local py_bin="$1"
  "$py_bin" - <<'PY' >/dev/null 2>&1
import importlib.util
mods = ["flask", "PIL"]
raise SystemExit(0 if all(importlib.util.find_spec(m) for m in mods) else 1)
PY
}

python_has_pip() {
  local py_bin="$1"
  "$py_bin" -m pip --version >/dev/null 2>&1
}

repair_broken_venv() {
  local venv_path="$1"
  [[ -d "$venv_path" ]] || return 0
  rm -rf "$venv_path" >/dev/null 2>&1 || true
}

install_requirements_with_system_pip() {
  if ! python_has_pip python3; then
    return 1
  fi

  if python3 -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
    python3 -m pip install --user --break-system-packages -r "$REQUIREMENTS_FILE" >/dev/null
  else
    python3 -m pip install --user -r "$REQUIREMENTS_FILE" >/dev/null
  fi
}

create_local_venv() {
  repair_broken_venv "$VENV_DIR"
  echo "[INFO] Creating local venv for Lobster World..." >&2
  if ! python3 -m venv "$VENV_DIR" >/dev/null 2>&1; then
    return 1
  fi
  "$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null 2>&1 || true
  "$VENV_DIR/bin/python" -m pip install -r "$REQUIREMENTS_FILE" >/dev/null
}

ensure_python() {
  if [[ -x "$VENV_DIR/bin/python" ]] && python_has_modules "$VENV_DIR/bin/python"; then
    echo "$VENV_DIR/bin/python"
    return 0
  fi
  if [[ -d "$VENV_DIR" ]]; then
    echo "[WARN] Broken Lobster World venv detected at $VENV_DIR, recreating..." >&2
    repair_broken_venv "$VENV_DIR"
  fi

  if [[ -x "$TMP_VENV/bin/python" ]] && python_has_modules "$TMP_VENV/bin/python"; then
    echo "$TMP_VENV/bin/python"
    return 0
  fi
  if [[ -d "$TMP_VENV" && ! -x "$TMP_VENV/bin/python" ]]; then
    repair_broken_venv "$TMP_VENV"
  fi

  if python_has_modules python3; then
    echo "python3"
    return 0
  fi

  echo "[INFO] Installing Lobster World Python dependencies with system pip..." >&2
  if install_requirements_with_system_pip && python_has_modules python3; then
    echo "python3"
    return 0
  fi

  if create_local_venv && python_has_modules "$VENV_DIR/bin/python"; then
    echo "$VENV_DIR/bin/python"
    return 0
  fi

  echo "[ERROR] Lobster World Python runtime is not ready." >&2
  echo "[ERROR] Missing dependency path: python3-venv or usable python3 pip environment." >&2
  echo "[ERROR] On Debian/Ubuntu run: apt install -y python3-venv python3-pip" >&2
  return 1
}

start_server() {
  if [[ ! -f "$BACKEND_DIR/app.py" ]]; then
    echo "[ERROR] Backend entry not found: $BACKEND_DIR/app.py"
    exit 1
  fi

  local py_bin
  py_bin="$(ensure_python)"

  if is_running; then
    local pid
    pid="$(listen_pid)"
    if verify_world_response; then
      [[ -n "$pid" ]] && echo "$pid" > "$PID_FILE"
      echo "[INFO] Lobster World already running (PID: ${pid:-unknown}, port: $PORT)"
      exit 0
    fi
    echo "[WARN] Port $PORT is occupied by another service, replacing it for Lobster World."
    if ! force_release_port; then
      echo "[ERROR] Port $PORT is still occupied after cleanup."
      exit 1
    fi
  fi

  local pid
  pid="$(spawn_detached_world_server "$py_bin")"
  echo "$pid" > "$PID_FILE"

  local ok=0
  for _ in {1..30}; do
    if verify_world_response; then
      ok=1
      break
    fi
    sleep 0.3
  done

  if [[ "$ok" -eq 1 ]]; then
    local pid
    pid="$(listen_pid)"
    echo "${pid:-$(cat "$PID_FILE" 2>/dev/null || true)}" > "$PID_FILE"
    apply_default_theme_once || true
    echo "[OK] Lobster World started: http://$HOST:$PORT (PID: ${pid:-unknown})"
  else
    rm -f "$PID_FILE"
    echo "[ERROR] Failed to start Lobster World. Check log: $LOG_FILE"
    exit 1
  fi
}

stop_server() {
  if ! is_running; then
    echo "[INFO] Lobster World not running on port $PORT"
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
  echo "[OK] Lobster World stopped"
}

status_server() {
  if is_running; then
    local pid
    pid="$(listen_pid)"
    if verify_world_response; then
      echo "[OK] Running: http://$HOST:$PORT (PID: $pid)"
    else
      echo "[WARN] Port $PORT is occupied, but the current listener is not the Lobster World service."
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
