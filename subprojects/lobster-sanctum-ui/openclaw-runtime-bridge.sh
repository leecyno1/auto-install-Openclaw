#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$ROOT_DIR/openclaw-runtime-bridge.sh"

OPENCLAW_STATUS_URL="${OPENCLAW_STATUS_URL:-http://127.0.0.1:13145/status}"
PROJECTION_API_HOST="${PROJECTION_API_HOST:-127.0.0.1}"
PROJECTION_API_PORT="${PROJECTION_API_PORT:-19100}"
PROJECTION_API_INGEST_URL="${PROJECTION_API_INGEST_URL:-http://${PROJECTION_API_HOST}:${PROJECTION_API_PORT}/runtime/ingest}"
BRIDGE_SOURCE="${BRIDGE_SOURCE:-openclaw-bridge}"
BRIDGE_INTERVAL_SEC="${BRIDGE_INTERVAL_SEC:-3}"
BRIDGE_CONNECT_TIMEOUT_SEC="${BRIDGE_CONNECT_TIMEOUT_SEC:-2}"
BRIDGE_MAX_TIME_SEC="${BRIDGE_MAX_TIME_SEC:-6}"
BRIDGE_VERBOSE="${BRIDGE_VERBOSE:-0}"
BRIDGE_GUARDIAN_ENABLED="${BRIDGE_GUARDIAN_ENABLED:-1}"
BRIDGE_GUARDIAN_MAX_RESTARTS="${BRIDGE_GUARDIAN_MAX_RESTARTS:-3}"
BRIDGE_GUARDIAN_COOLDOWN_SEC="${BRIDGE_GUARDIAN_COOLDOWN_SEC:-60}"
BRIDGE_GUARDIAN_STABLE_WINDOW_SEC="${BRIDGE_GUARDIAN_STABLE_WINDOW_SEC:-120}"
BRIDGE_GUARDIAN_MIN_FAIL_STREAK="${BRIDGE_GUARDIAN_MIN_FAIL_STREAK:-2}"

PID_FILE="/tmp/lobster-openclaw-bridge.pid"
LOG_FILE="/tmp/lobster-openclaw-bridge.log"
GUARDIAN_LOG_FILE="/tmp/lobster-openclaw-guardian.log"

guardian_restart_count=0
guardian_last_restart_at=0
guardian_fail_streak=0
guardian_blocked=0

usage() {
  cat <<USAGE
Usage: $0 {once|loop|start|stop|restart|status}

Env:
  OPENCLAW_STATUS_URL       OpenClaw status endpoint (default: $OPENCLAW_STATUS_URL)
  PROJECTION_API_INGEST_URL Projection ingest endpoint (default: $PROJECTION_API_INGEST_URL)
  BRIDGE_INTERVAL_SEC       Poll interval seconds (default: $BRIDGE_INTERVAL_SEC)
USAGE
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

now_epoch() {
  date +%s
}

bridge_log_info() {
  if is_truthy "$BRIDGE_VERBOSE"; then
    echo "$@"
  fi
}

guardian_log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S%z')"
  local msg="[GUARDIAN] $ts $*"
  echo "$msg" | tee -a "$GUARDIAN_LOG_FILE" >/dev/null
}

is_pid_running() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

read_pid() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  echo "$pid"
}

is_running() {
  local pid
  pid="$(read_pid || true)"
  is_pid_running "$pid"
}

post_ingest_payload() {
  local payload="$1"
  curl -fsS --connect-timeout "$BRIDGE_CONNECT_TIMEOUT_SEC" --max-time "$BRIDGE_MAX_TIME_SEC" \
    -H "Content-Type: application/json" \
    -X POST "$PROJECTION_API_INGEST_URL" \
    -d "$payload" >/dev/null
}

guardian_on_success() {
  guardian_fail_streak=0
  if ! is_truthy "$BRIDGE_GUARDIAN_ENABLED"; then
    return 0
  fi
  if (( guardian_restart_count <= 0 || guardian_last_restart_at <= 0 )); then
    return 0
  fi
  local now
  now="$(now_epoch)"
  if (( now - guardian_last_restart_at >= BRIDGE_GUARDIAN_STABLE_WINDOW_SEC )); then
    guardian_log "runtime stable for >=${BRIDGE_GUARDIAN_STABLE_WINDOW_SEC}s; reset restart counter"
    guardian_restart_count=0
    guardian_last_restart_at=0
    guardian_blocked=0
  fi
}

guardian_maybe_restart_gateway() {
  if ! is_truthy "$BRIDGE_GUARDIAN_ENABLED"; then
    return 0
  fi
  if (( guardian_fail_streak < BRIDGE_GUARDIAN_MIN_FAIL_STREAK )); then
    return 0
  fi
  if ! command -v openclaw >/dev/null 2>&1; then
    guardian_log "skip restart: openclaw command not found"
    return 0
  fi
  if (( guardian_blocked == 1 )); then
    return 0
  fi

  local now
  now="$(now_epoch)"

  if (( guardian_restart_count >= BRIDGE_GUARDIAN_MAX_RESTARTS )); then
    guardian_blocked=1
    guardian_log "disable auto-restart: reached max attempts (${BRIDGE_GUARDIAN_MAX_RESTARTS})"
    return 0
  fi
  if (( guardian_last_restart_at > 0 && now - guardian_last_restart_at < BRIDGE_GUARDIAN_COOLDOWN_SEC )); then
    return 0
  fi

  guardian_restart_count=$((guardian_restart_count + 1))
  guardian_last_restart_at="$now"
  guardian_log "attempt ${guardian_restart_count}/${BRIDGE_GUARDIAN_MAX_RESTARTS}: restarting gateway"

  if openclaw gateway restart >/dev/null 2>&1 || openclaw gateway start >/dev/null 2>&1; then
    sleep 1
    if curl -fsS --connect-timeout "$BRIDGE_CONNECT_TIMEOUT_SEC" --max-time "$BRIDGE_MAX_TIME_SEC" "$OPENCLAW_STATUS_URL" >/dev/null 2>&1; then
      guardian_fail_streak=0
      guardian_log "gateway restart succeeded and status endpoint recovered"
    else
      guardian_log "gateway restart command ran, but status endpoint still unreachable"
    fi
  else
    guardian_log "gateway restart command failed"
  fi

  if (( guardian_restart_count >= BRIDGE_GUARDIAN_MAX_RESTARTS )); then
    guardian_blocked=1
    guardian_log "auto-restart budget exhausted; manual intervention required"
  fi
}

run_once() {
  local status_json
  if ! status_json="$(curl -fsS --connect-timeout "$BRIDGE_CONNECT_TIMEOUT_SEC" --max-time "$BRIDGE_MAX_TIME_SEC" "$OPENCLAW_STATUS_URL")"; then
    guardian_fail_streak=$((guardian_fail_streak + 1))
    guardian_maybe_restart_gateway || true
    local fail_payload
    fail_payload="{\"source\":\"$BRIDGE_SOURCE\",\"raw\":{\"state\":\"error\",\"phase\":\"error\",\"message\":\"bridge pull failed\",\"detail\":\"cannot reach $OPENCLAW_STATUS_URL\",\"error_code\":\"OPENCLAW_STATUS_UNREACHABLE\"}}"
    post_ingest_payload "$fail_payload" || true
    echo "[WARN] pull failed: $OPENCLAW_STATUS_URL"
    return 1
  fi

  local payload
  if command -v jq >/dev/null 2>&1 && printf '%s' "$status_json" | jq -e type >/dev/null 2>&1; then
    payload="$(printf '%s' "$status_json" | jq -c --arg src "$BRIDGE_SOURCE" '{source:$src,raw:.}')"
  else
    payload="$status_json"
  fi

  post_ingest_payload "$payload"
  guardian_on_success
  bridge_log_info "[OK] bridged status -> $PROJECTION_API_INGEST_URL"
}

run_loop() {
  while true; do
    run_once || true
    sleep "$BRIDGE_INTERVAL_SEC"
  done
}

start_loop() {
  if is_running; then
    local pid
    pid="$(read_pid)"
    echo "[INFO] bridge already running (PID: $pid)"
    return 0
  fi

  nohup bash "$SELF" loop >"$LOG_FILE" 2>&1 < /dev/null &
  local pid="$!"
  echo "$pid" > "$PID_FILE"
  sleep 0.4
  if is_pid_running "$pid"; then
    echo "[OK] bridge started (PID: $pid)"
    echo "[INFO] log: $LOG_FILE"
  else
    echo "[ERROR] failed to start bridge"
    rm -f "$PID_FILE"
    return 1
  fi
}

stop_loop() {
  local pid
  pid="$(read_pid || true)"
  if ! is_pid_running "$pid"; then
    rm -f "$PID_FILE"
    echo "[INFO] bridge not running"
    return 0
  fi
  kill "$pid" 2>/dev/null || true
  sleep 0.5
  if is_pid_running "$pid"; then
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
  echo "[OK] bridge stopped"
}

status_loop() {
  if is_running; then
    local pid
    pid="$(read_pid)"
    echo "[OK] bridge running (PID: $pid)"
    echo "[INFO] $OPENCLAW_STATUS_URL -> $PROJECTION_API_INGEST_URL"
  else
    echo "[INFO] bridge not running"
  fi
}

case "${1:-}" in
  once) run_once ;;
  loop) run_loop ;;
  start) start_loop ;;
  stop) stop_loop ;;
  restart) stop_loop; start_loop ;;
  status) status_loop ;;
  *) usage; exit 1 ;;
esac
