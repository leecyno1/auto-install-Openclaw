#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME="remote-local-control"
DEFAULT_CLOUD_PORT="24022"
DEFAULT_LOCAL_SSH_PORT="22"
DEFAULT_LOCAL_USER="local-agent"
DEFAULT_GATE_PATH="/usr/local/bin/openclaw-local-command-gate"
DEFAULT_WRAPPER_PATH="/usr/local/bin/openclaw-local-run"
DEFAULT_LOG_FILE="/var/log/openclaw-local-command-gate.log"

OPENCLAW_REMOTE_LOCAL_CLOUD_PORT="${OPENCLAW_REMOTE_LOCAL_CLOUD_PORT:-$DEFAULT_CLOUD_PORT}"
OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT="${OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT:-$DEFAULT_LOCAL_SSH_PORT}"
OPENCLAW_REMOTE_LOCAL_USER="${OPENCLAW_REMOTE_LOCAL_USER:-$DEFAULT_LOCAL_USER}"
OPENCLAW_REMOTE_LOCAL_GATE_PATH="${OPENCLAW_REMOTE_LOCAL_GATE_PATH:-$DEFAULT_GATE_PATH}"
OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH="${OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH:-$DEFAULT_WRAPPER_PATH}"
OPENCLAW_REMOTE_LOCAL_LOG_FILE="${OPENCLAW_REMOTE_LOCAL_LOG_FILE:-$DEFAULT_LOG_FILE}"

usage() {
    cat <<EOF_USAGE
Cloud-to-local reverse SSH helper (optional)

Usage:
  $PROGRAM_NAME install-local --cloud-public-key <key-file> [--local-user local-agent]
  $PROGRAM_NAME install-cloud --identity <key-file> [--port 24022]
  $PROGRAM_NAME start-tunnel --cloud <user@host> [--identity <key-file>] [--port 24022]
  $PROGRAM_NAME run <action> [args...]
  $PROGRAM_NAME status
  $PROGRAM_NAME help

Purpose:
  Build an opt-in reverse SSH path so cloud OpenClaw/Hermes can run a small
  whitelist of commands on a local computer without exposing local SSH publicly.

Safe defaults:
  - reverse tunnel binds cloud side to 127.0.0.1 only
  - local authorized_keys should use forced command gate
  - no agent forwarding, X11 forwarding, or TTY
  - no full shell by default
EOF_USAGE
}

need_value() {
    local name="${1:-option}" value="${2:-}"
    if [ -z "$value" ]; then
        echo "[ERROR] Missing value for $name" >&2
        exit 2
    fi
}

write_command_gate_template() {
    cat <<'EOF_GATE'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${OPENCLAW_LOCAL_COMMAND_GATE_LOG:-/var/log/openclaw-local-command-gate.log}"
ORIGINAL="${SSH_ORIGINAL_COMMAND:-status}"
ACTION="${ORIGINAL%% *}"
ARGS=""
if [ "$ORIGINAL" != "$ACTION" ]; then
  ARGS="${ORIGINAL#"$ACTION" }"
fi

log_attempt() {
  local status="$1"
  local message="$2"
  local ts
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  printf '%s status=%s action=%s message=%s\n' "$ts" "$status" "$ACTION" "$message" >> "$LOG_FILE" 2>/dev/null || true
}

reject() {
  log_attempt "denied" "$1"
  echo "denied: $1" >&2
  exit 126
}

case "$ORIGINAL" in
  *';'*|*'&&'*|*'||'*|*'`'*|*'$('*|*'>'*|*'<'*)
    reject "shell metacharacters are not allowed"
    ;;
esac

case "$ACTION" in
  status)
    log_attempt "ok" "status"
    printf 'host=%s\n' "$(hostname 2>/dev/null || echo unknown)"
    printf 'user=%s\n' "$(whoami 2>/dev/null || echo unknown)"
    printf 'os=%s\n' "$(uname -a 2>/dev/null || echo unknown)"
    ;;
  openclaw-status)
    log_attempt "ok" "openclaw-status"
    if command -v openclaw >/dev/null 2>&1; then
      openclaw gateway status 2>&1 | head -40 || true
    else
      echo "openclaw not found"
    fi
    ;;
  tail-log)
    case "$ARGS" in
      gateway) target="/tmp/openclaw-gateway.log" ;;
      health) target="/tmp/openclaw-health.log" ;;
      quota) target="/tmp/openclaw-quota-enforcer.log" ;;
      *) reject "unknown log name" ;;
    esac
    log_attempt "ok" "tail-log $ARGS"
    tail -80 "$target" 2>/dev/null || echo "log not found: $ARGS"
    ;;
  run-maintenance)
    case "$ARGS" in
      openclaw-doctor)
        log_attempt "ok" "run-maintenance openclaw-doctor"
        command -v openclaw >/dev/null 2>&1 && openclaw doctor || echo "openclaw not found"
        ;;
      *) reject "unknown maintenance task" ;;
    esac
    ;;
  sync-inbox)
    reject "sync-inbox is disabled until explicitly implemented"
    ;;
  bash|sh|zsh|fish|python|python3|node|ruby|perl|sudo|su|cat|rm|mv|cp|scp|sftp)
    reject "interactive or unsafe command is not allowed"
    ;;
  *)
    reject "unknown action"
    ;;
esac
EOF_GATE
}

write_cloud_wrapper_template() {
    local identity_file="$1" port="$2" local_user="$3"
    cat <<EOF_WRAPPER
#!/usr/bin/env bash
set -euo pipefail
ACTION="\${1:-status}"
shift || true
exec ssh \
  -i "$identity_file" \
  -p "$port" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 \
  -o RequestTTY=no \
  "$local_user@127.0.0.1" "\$ACTION" "\$@"
EOF_WRAPPER
}

install_local() {
    local cloud_public_key="" local_user="$OPENCLAW_REMOTE_LOCAL_USER" gate_path="$OPENCLAW_REMOTE_LOCAL_GATE_PATH"
    while [ $# -gt 0 ]; do
        case "$1" in
            --cloud-public-key) cloud_public_key="${2:-}"; need_value "$1" "$cloud_public_key"; shift 2 ;;
            --local-user) local_user="${2:-}"; need_value "$1" "$local_user"; shift 2 ;;
            --gate-path) gate_path="${2:-}"; need_value "$1" "$gate_path"; shift 2 ;;
            *) echo "[ERROR] Unknown install-local option: $1" >&2; exit 2 ;;
        esac
    done
    [ -f "$cloud_public_key" ] || { echo "[ERROR] Cloud public key not found: $cloud_public_key" >&2; exit 2; }

    echo "[INFO] This command prints safe local setup steps. Review before running as root."
    echo "sudo install -m 755 /dev/stdin '$gate_path' <<'EOF_GATE'"
    write_command_gate_template
    echo "EOF_GATE"
    echo "sudo mkdir -p /Users/$local_user/.ssh 2>/dev/null || sudo mkdir -p /home/$local_user/.ssh"
    echo "sudo sh -c 'printf %s\\n "'"'command=\"$gate_path\",no-agent-forwarding,no-X11-forwarding,no-pty $(cat "$cloud_public_key")'"'" >> ~$local_user/.ssh/authorized_keys'"
    echo "[INFO] Create or verify the '$local_user' account manually before applying these commands."
}

install_cloud() {
    local identity_file="" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_user="$OPENCLAW_REMOTE_LOCAL_USER" wrapper_path="$OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH"
    while [ $# -gt 0 ]; do
        case "$1" in
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --local-user) local_user="${2:-}"; need_value "$1" "$local_user"; shift 2 ;;
            --wrapper-path) wrapper_path="${2:-}"; need_value "$1" "$wrapper_path"; shift 2 ;;
            *) echo "[ERROR] Unknown install-cloud option: $1" >&2; exit 2 ;;
        esac
    done
    [ -n "$identity_file" ] || { echo "[ERROR] --identity is required" >&2; exit 2; }
    echo "[INFO] This command prints a cloud wrapper template. Review before installing."
    echo "sudo install -m 755 /dev/stdin '$wrapper_path' <<'EOF_WRAPPER'"
    write_cloud_wrapper_template "$identity_file" "$port" "$local_user"
    echo "EOF_WRAPPER"
}

start_tunnel() {
    local cloud="" identity_file="" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_port="$OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT"
    while [ $# -gt 0 ]; do
        case "$1" in
            --cloud) cloud="${2:-}"; need_value "$1" "$cloud"; shift 2 ;;
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --local-ssh-port) local_port="${2:-}"; need_value "$1" "$local_port"; shift 2 ;;
            *) echo "[ERROR] Unknown start-tunnel option: $1" >&2; exit 2 ;;
        esac
    done
    [ -n "$cloud" ] || { echo "[ERROR] --cloud user@host is required" >&2; exit 2; }
    local identity_args=()
    [ -n "$identity_file" ] && identity_args=(-i "$identity_file")
    exec ssh -N \
      "${identity_args[@]}" \
      -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -R 127.0.0.1:${port}:127.0.0.1:${local_port} \
      "$cloud"
}

run_remote() {
    local port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_user="$OPENCLAW_REMOTE_LOCAL_USER"
    local action="${1:-status}"
    shift || true
    exec ssh -p "$port" -o BatchMode=yes -o RequestTTY=no "$local_user@127.0.0.1" "$action" "$@"
}

status() {
    cat <<EOF_STATUS
$PROGRAM_NAME status
cloud_port=$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT
local_ssh_port=$OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT
local_user=$OPENCLAW_REMOTE_LOCAL_USER
gate_path=$OPENCLAW_REMOTE_LOCAL_GATE_PATH
wrapper_path=$OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH
EOF_STATUS
}

cmd="${1:-help}"
shift || true
case "$cmd" in
    help|-h|--help) usage ;;
    install-local) install_local "$@" ;;
    install-cloud) install_cloud "$@" ;;
    start-tunnel) start_tunnel "$@" ;;
    run) run_remote "$@" ;;
    status) status ;;
    *) echo "[ERROR] Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac
