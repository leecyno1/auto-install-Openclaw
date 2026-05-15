#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME="remote-local-control"
DEFAULT_CLOUD_PORT="24022"
DEFAULT_LOCAL_SSH_PORT="22"
DEFAULT_LOCAL_USER="local-agent"
DEFAULT_GATE_PATH="/usr/local/bin/openclaw-local-command-gate"
DEFAULT_WRAPPER_PATH="/usr/local/bin/openclaw-local-run"
DEFAULT_LOG_FILE="/var/log/openclaw-local-command-gate.log"
DEFAULT_SERVICE_NAME="openclaw-local-tunnel"
DEFAULT_CLOUD_SSH_PORT="22"

OPENCLAW_REMOTE_LOCAL_CLOUD_PORT_INPUT="${OPENCLAW_REMOTE_LOCAL_CLOUD_PORT:-}"
OPENCLAW_REMOTE_LOCAL_CLOUD_PORT="${OPENCLAW_REMOTE_LOCAL_CLOUD_PORT:-$DEFAULT_CLOUD_PORT}"
OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT="${OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT:-$DEFAULT_LOCAL_SSH_PORT}"
OPENCLAW_REMOTE_LOCAL_USER="${OPENCLAW_REMOTE_LOCAL_USER:-$DEFAULT_LOCAL_USER}"
OPENCLAW_REMOTE_LOCAL_GATE_PATH="${OPENCLAW_REMOTE_LOCAL_GATE_PATH:-$DEFAULT_GATE_PATH}"
OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH="${OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH:-$DEFAULT_WRAPPER_PATH}"
OPENCLAW_REMOTE_LOCAL_LOG_FILE="${OPENCLAW_REMOTE_LOCAL_LOG_FILE:-$DEFAULT_LOG_FILE}"
OPENCLAW_REMOTE_LOCAL_SERVICE_NAME="${OPENCLAW_REMOTE_LOCAL_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}"
OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT_INPUT="${OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT:-}"
OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT="${OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT:-$DEFAULT_CLOUD_SSH_PORT}"
OPENCLAW_REMOTE_LOCAL_PAIRING_FILE="${OPENCLAW_REMOTE_LOCAL_PAIRING_FILE:-}"

usage() {
    cat <<EOF_USAGE
Cloud-to-local reverse SSH helper (optional)

Usage:
  $PROGRAM_NAME configure-local [--pairing-file pairing.json] [--gate-path path] [--connect-now] [--install-service]
  $PROGRAM_NAME bootstrap-local --cloud <user@host> --cloud-public-key <key-file> [--identity <key-file>] [--cloud-ssh-port 22] [--connect-now]
  $PROGRAM_NAME install-local --cloud-public-key <key-file> [--local-user local-agent]
  $PROGRAM_NAME install-cloud --identity <key-file> [--port 24022]
  $PROGRAM_NAME install-tunnel-service --cloud <user@host> [--identity <key-file>] [--cloud-ssh-port 22] [--port 24022]
  $PROGRAM_NAME start-tunnel --cloud <user@host> [--identity <key-file>] [--cloud-ssh-port 22] [--port 24022]
  $PROGRAM_NAME run <action> [args...]
  $PROGRAM_NAME status
  $PROGRAM_NAME help

Purpose:
  Build an opt-in reverse SSH path so cloud OpenClaw/Hermes can run a small
  whitelist of commands on a local computer without exposing local SSH publicly.

Local whitelist actions exposed to the cloud:
  status
  openclaw-status
  tail-log gateway|health|quota
  run-maintenance openclaw-doctor
  desktop-create-folder <safe-folder-name>
  desktop-write-article <safe-folder-name> <safe-file-name.md> <base64-content>

Safe defaults:
  - reverse tunnel binds cloud side to 127.0.0.1 only
  - local authorized_keys uses a forced command gate
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

read_pairing_value() {
    local file="$1" key_spec="$2"
    [ -f "$file" ] || return 1
    python3 - "$file" "$key_spec" <<'PY_READ_PAIRING' 2>/dev/null
import json, sys
path, key_spec = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8') as handle:
    data = json.load(handle)
keys = key_spec.split('|')
for key in keys:
    cur = data
    ok = True
    for part in key.split('.'):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            ok = False
            break
    if ok and cur not in (None, ''):
        print(cur)
        break
PY_READ_PAIRING
}

prompt_if_tty() {
    local prompt="$1" default_value="${2:-}" value=""
    [ -t 0 ] || return 1
    if [ -n "$default_value" ]; then
        read -r -p "$prompt [$default_value]: " value
        printf '%s\n' "${value:-$default_value}"
    else
        read -r -p "$prompt: " value
        printf '%s\n' "$value"
    fi
}

materialize_cloud_public_key() {
    local key_file="$1" key_value="$2" target_dir target_file
    if [ -n "$key_file" ]; then
        printf '%s\n' "$key_file"
        return 0
    fi
    [ -n "$key_value" ] || return 1
    target_dir="$HOME/.openclaw"
    target_file="$target_dir/remote-local-cloud.pub"
    mkdir -p "$target_dir"
    printf '%s\n' "$key_value" > "$target_file"
    chmod 600 "$target_file" 2>/dev/null || true
    printf '%s\n' "$target_file"
}

current_script_path() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    printf '%s/%s\n' "$script_dir" "${BASH_SOURCE[0]##*/}"
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

safe_leaf_name() {
  local value="${1:-}"
  [ -n "$value" ] || return 1
  case "$value" in
    .*|*/*|*'\\'*|*'..'*|*':'*|*';'*|*'&&'*|*'||'*|*'`'*|*'$('*|*'>'*|*'<'*) return 1 ;;
  esac
  case "$value" in
    *[!A-Za-z0-9._@%+=,\ -]*) return 1 ;;
  esac
  return 0
}

desktop_dir() {
  if [ -d "$HOME/Desktop" ]; then
    printf '%s\n' "$HOME/Desktop"
  else
    printf '%s\n' "$HOME/OpenClawRemoteDesktop"
  fi
}

decode_base64_to_file() {
  local payload="$1" target="$2"
  if printf '%s' "$payload" | base64 --decode > "$target" 2>/dev/null; then
    return 0
  fi
  printf '%s' "$payload" | base64 -D > "$target" 2>/dev/null
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
  desktop-create-folder)
    folder="$ARGS"
    safe_leaf_name "$folder" || reject "unsafe folder name"
    target="$(desktop_dir)/$folder"
    mkdir -p "$target"
    log_attempt "ok" "desktop-create-folder $folder"
    printf 'created=%s\n' "$target"
    ;;
  desktop-write-article)
    folder="${ARGS%% *}"
    rest="${ARGS#"$folder" }"
    file="${rest%% *}"
    payload="${rest#"$file" }"
    [ "$ARGS" != "$folder" ] && [ "$rest" != "$file" ] || reject "usage: desktop-write-article <folder> <file.md> <base64-content>"
    safe_leaf_name "$folder" || reject "unsafe folder name"
    safe_leaf_name "$file" || reject "unsafe file name"
    case "$file" in *.md|*.txt) ;; *) reject "file extension must be .md or .txt" ;; esac
    dir="$(desktop_dir)/$folder"
    mkdir -p "$dir"
    decode_base64_to_file "$payload" "$dir/$file" || reject "invalid base64 content"
    log_attempt "ok" "desktop-write-article $folder/$file"
    printf 'written=%s\n' "$dir/$file"
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
exec ssh \\
  -i "$identity_file" \\
  -p "$port" \\
  -o BatchMode=yes \\
  -o StrictHostKeyChecking=accept-new \\
  -o ConnectTimeout=10 \\
  -o RequestTTY=no \\
  "$local_user@127.0.0.1" "\$ACTION" "\$@"
EOF_WRAPPER
}

append_authorized_key() {
    local cloud_public_key="$1" local_user="$2" gate_path="$3"
    local home_dir auth_line
    # authorized_keys forced-command shape: command="$gate_path",no-agent-forwarding,no-X11-forwarding,no-pty
    home_dir="$(eval "printf '%s' ~$local_user")"
    [ -n "$home_dir" ] && [ "$home_dir" != "~$local_user" ] || { echo "[ERROR] Cannot resolve home for $local_user" >&2; exit 2; }
    auth_line="command=\"$gate_path\",no-agent-forwarding,no-X11-forwarding,no-pty $(cat "$cloud_public_key")"
    sudo mkdir -p "$home_dir/.ssh"
    if ! sudo grep -Fqx "$auth_line" "$home_dir/.ssh/authorized_keys" 2>/dev/null; then
        printf '%s\n' "$auth_line" | sudo tee -a "$home_dir/.ssh/authorized_keys" >/dev/null
    fi
    sudo chmod 700 "$home_dir/.ssh"
    sudo chmod 600 "$home_dir/.ssh/authorized_keys"
    sudo chown -R "$local_user" "$home_dir/.ssh" 2>/dev/null || true
}

install_gate() {
    local gate_path="$1" tmp_file
    tmp_file="$(mktemp)"
    write_command_gate_template > "$tmp_file"
    sudo install -m 755 "$tmp_file" "$gate_path"
    rm -f "$tmp_file"
}

install_local() {
    local cloud_public_key="" local_user="$OPENCLAW_REMOTE_LOCAL_USER" gate_path="$OPENCLAW_REMOTE_LOCAL_GATE_PATH" apply="0"
    while [ $# -gt 0 ]; do
        case "$1" in
            --cloud-public-key) cloud_public_key="${2:-}"; need_value "$1" "$cloud_public_key"; shift 2 ;;
            --local-user) local_user="${2:-}"; need_value "$1" "$local_user"; shift 2 ;;
            --gate-path) gate_path="${2:-}"; need_value "$1" "$gate_path"; shift 2 ;;
            --apply) apply="1"; shift ;;
            *) echo "[ERROR] Unknown install-local option: $1" >&2; exit 2 ;;
        esac
    done
    [ -f "$cloud_public_key" ] || { echo "[ERROR] Cloud public key not found: $cloud_public_key" >&2; exit 2; }

    if [ "$apply" = "1" ]; then
        install_gate "$gate_path"
        append_authorized_key "$cloud_public_key" "$local_user" "$gate_path"
        echo "[INFO] Local command gate installed for $local_user: $gate_path"
        return 0
    fi

    echo "[INFO] This command prints safe local setup steps. Review before running as root."
    echo "sudo install -m 755 /dev/stdin '$gate_path' <<'EOF_GATE'"
    write_command_gate_template
    echo "EOF_GATE"
    echo "sudo mkdir -p /Users/$local_user/.ssh 2>/dev/null || sudo mkdir -p /home/$local_user/.ssh"
    echo "sudo sh -c 'printf %s\\n "'"'command=\"$gate_path\",no-agent-forwarding,no-X11-forwarding,no-pty $(cat "$cloud_public_key")'"'" >> ~$local_user/.ssh/authorized_keys'"
    echo "[INFO] Create or verify the '$local_user' account manually before applying these commands."
}

install_cloud() {
    local identity_file="" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_user="$OPENCLAW_REMOTE_LOCAL_USER" wrapper_path="$OPENCLAW_REMOTE_LOCAL_WRAPPER_PATH" apply="0"
    while [ $# -gt 0 ]; do
        case "$1" in
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --local-user) local_user="${2:-}"; need_value "$1" "$local_user"; shift 2 ;;
            --wrapper-path) wrapper_path="${2:-}"; need_value "$1" "$wrapper_path"; shift 2 ;;
            --apply) apply="1"; shift ;;
            *) echo "[ERROR] Unknown install-cloud option: $1" >&2; exit 2 ;;
        esac
    done
    [ -n "$identity_file" ] || { echo "[ERROR] --identity is required" >&2; exit 2; }
    if [ "$apply" = "1" ]; then
        tmp_file="$(mktemp)"
        write_cloud_wrapper_template "$identity_file" "$port" "$local_user" > "$tmp_file"
        sudo install -m 755 "$tmp_file" "$wrapper_path"
        rm -f "$tmp_file"
        echo "[INFO] Cloud wrapper installed: $wrapper_path"
        return 0
    fi
    echo "[INFO] This command prints a cloud wrapper template. Review before installing."
    echo "sudo install -m 755 /dev/stdin '$wrapper_path' <<'EOF_WRAPPER'"
    write_cloud_wrapper_template "$identity_file" "$port" "$local_user"
    echo "EOF_WRAPPER"
}

start_tunnel() {
    local cloud="" identity_file="" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_port="$OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT" cloud_ssh_port="$OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT"
    while [ $# -gt 0 ]; do
        case "$1" in
            --cloud) cloud="${2:-}"; need_value "$1" "$cloud"; shift 2 ;;
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --cloud-ssh-port) cloud_ssh_port="${2:-}"; need_value "$1" "$cloud_ssh_port"; shift 2 ;;
            --local-ssh-port) local_port="${2:-}"; need_value "$1" "$local_port"; shift 2 ;;
            *) echo "[ERROR] Unknown start-tunnel option: $1" >&2; exit 2 ;;
        esac
    done
    [ -n "$cloud" ] || { echo "[ERROR] --cloud user@host is required" >&2; exit 2; }
    local identity_args=()
    [ -n "$identity_file" ] && identity_args=(-i "$identity_file")
    exec ssh -N \
      "${identity_args[@]}" \
      -p "$cloud_ssh_port" \
      -o ExitOnForwardFailure=yes \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -R 127.0.0.1:${port}:127.0.0.1:${local_port} \
      "$cloud"
}

bootstrap_local() {
    local cloud="" cloud_public_key="" identity_file="" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_port="$OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT" cloud_ssh_port="$OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT" local_user="$(id -un 2>/dev/null || echo "$OPENCLAW_REMOTE_LOCAL_USER")" gate_path="$OPENCLAW_REMOTE_LOCAL_GATE_PATH" connect_now="0" install_service="0"
    while [ $# -gt 0 ]; do
        case "$1" in
            --cloud) cloud="${2:-}"; need_value "$1" "$cloud"; shift 2 ;;
            --cloud-public-key) cloud_public_key="${2:-}"; need_value "$1" "$cloud_public_key"; shift 2 ;;
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --cloud-ssh-port) cloud_ssh_port="${2:-}"; need_value "$1" "$cloud_ssh_port"; shift 2 ;;
            --local-ssh-port) local_port="${2:-}"; need_value "$1" "$local_port"; shift 2 ;;
            --local-user) local_user="${2:-}"; need_value "$1" "$local_user"; shift 2 ;;
            --gate-path) gate_path="${2:-}"; need_value "$1" "$gate_path"; shift 2 ;;
            --connect-now) connect_now="1"; shift ;;
            --install-service) install_service="1"; shift ;;
            *) echo "[ERROR] Unknown bootstrap-local option: $1" >&2; exit 2 ;;
        esac
    done
    [ -n "$cloud" ] || { echo "[ERROR] --cloud user@host is required" >&2; exit 2; }
    [ -f "$cloud_public_key" ] || { echo "[ERROR] Cloud public key not found: $cloud_public_key" >&2; exit 2; }

    local identity_args=()
    [ -n "$identity_file" ] && identity_args=(--identity "$identity_file")

    install_local --cloud-public-key "$cloud_public_key" --local-user "$local_user" --gate-path "$gate_path" --apply
    if [ "$install_service" = "1" ]; then
        install_tunnel_service --cloud "$cloud" "${identity_args[@]}" --port "$port" --cloud-ssh-port "$cloud_ssh_port" --local-ssh-port "$local_port"
    fi
    if [ "$connect_now" = "1" ]; then
        start_tunnel --cloud "$cloud" "${identity_args[@]}" --port "$port" --cloud-ssh-port "$cloud_ssh_port" --local-ssh-port "$local_port"
    fi
    echo "[INFO] Local side is ready. Start tunnel with:"
    echo "  $PROGRAM_NAME start-tunnel --cloud '$cloud'${identity_file:+ --identity '$identity_file'} --cloud-ssh-port '$cloud_ssh_port' --port '$port' --local-ssh-port '$local_port'"
}

configure_local() {
    local pairing_file="$OPENCLAW_REMOTE_LOCAL_PAIRING_FILE" cloud="${OPENCLAW_REMOTE_LOCAL_CLOUD:-}" cloud_ssh_port="$OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT_INPUT" cloud_public_key="${OPENCLAW_REMOTE_LOCAL_CLOUD_PUBLIC_KEY_FILE:-}" cloud_public_key_value="${OPENCLAW_REMOTE_LOCAL_CLOUD_PUBLIC_KEY:-}" identity_file="${OPENCLAW_REMOTE_LOCAL_IDENTITY:-}" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT_INPUT" local_user="$(id -un 2>/dev/null || echo "$OPENCLAW_REMOTE_LOCAL_USER")" gate_path="$OPENCLAW_REMOTE_LOCAL_GATE_PATH" connect_now="0" install_service="0"
    while [ $# -gt 0 ]; do
        case "$1" in
            --pairing-file) pairing_file="${2:-}"; need_value "$1" "$pairing_file"; shift 2 ;;
            --cloud) cloud="${2:-}"; need_value "$1" "$cloud"; shift 2 ;;
            --cloud-ssh-port) cloud_ssh_port="${2:-}"; need_value "$1" "$cloud_ssh_port"; shift 2 ;;
            --cloud-public-key) cloud_public_key="${2:-}"; need_value "$1" "$cloud_public_key"; shift 2 ;;
            --cloud-public-key-value) cloud_public_key_value="${2:-}"; need_value "$1" "$cloud_public_key_value"; shift 2 ;;
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --local-user) local_user="${2:-}"; need_value "$1" "$local_user"; shift 2 ;;
            --gate-path) gate_path="${2:-}"; need_value "$1" "$gate_path"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --connect-now) connect_now="1"; shift ;;
            --install-service) install_service="1"; shift ;;
            *) echo "[ERROR] Unknown configure-local option: $1" >&2; exit 2 ;;
        esac
    done

    if [ -n "$pairing_file" ] && [ -f "$pairing_file" ]; then
        cloud="${cloud:-$(read_pairing_value "$pairing_file" 'cloud|cloudSshTarget|cloud_ssh_target|server.sshTarget|server.ssh_target')}"
        cloud_ssh_port="${cloud_ssh_port:-$(read_pairing_value "$pairing_file" 'cloudSshPort|cloud_ssh_port|sshPort|ssh_port|server.sshPort|server.ssh_port')}"
        port="${port:-$(read_pairing_value "$pairing_file" 'reversePort|reverse_port|cloudReversePort|cloud_reverse_port')}"
        cloud_public_key="${cloud_public_key:-$(read_pairing_value "$pairing_file" 'cloudPublicKeyFile|cloud_public_key_file')}"
        cloud_public_key_value="${cloud_public_key_value:-$(read_pairing_value "$pairing_file" 'cloudPublicKey|cloud_public_key|publicKey|public_key')}"
    fi

    cloud="${cloud:-$(prompt_if_tty '请输入云服务器 SSH 目标，例如 root@1.2.3.4' || true)}"
    cloud_ssh_port="${cloud_ssh_port:-$(prompt_if_tty '请输入云服务器 SSH 端口' '22' || true)}"
    port="${port:-$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT}"
    identity_file="${identity_file:-$(prompt_if_tty '请输入本地连接云服务器的私钥路径，留空使用默认 SSH 配置' || true)}"
    cloud_public_key="$(materialize_cloud_public_key "$cloud_public_key" "$cloud_public_key_value" || true)"

    [ -n "$cloud" ] || { echo "[ERROR] Missing cloud address. Provide --cloud, OPENCLAW_REMOTE_LOCAL_CLOUD, or --pairing-file." >&2; exit 2; }
    [ -n "$cloud_public_key" ] || { echo "[ERROR] Missing cloud public key. Provide --cloud-public-key or a pairing file with cloudPublicKey." >&2; exit 2; }

    local bootstrap_args=(--cloud "$cloud" --cloud-public-key "$cloud_public_key" --local-user "$local_user" --gate-path "$gate_path" --cloud-ssh-port "$cloud_ssh_port" --port "$port")
    [ -n "$identity_file" ] && bootstrap_args+=(--identity "$identity_file")
    [ "$connect_now" = "1" ] && bootstrap_args+=(--connect-now)
    [ "$install_service" = "1" ] && bootstrap_args+=(--install-service)
    bootstrap_local "${bootstrap_args[@]}"
}

install_tunnel_service() {
    local cloud="" identity_file="" port="$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT" local_port="$OPENCLAW_REMOTE_LOCAL_LOCAL_SSH_PORT" cloud_ssh_port="$OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT" service_name="$OPENCLAW_REMOTE_LOCAL_SERVICE_NAME" script_path
    while [ $# -gt 0 ]; do
        case "$1" in
            --cloud) cloud="${2:-}"; need_value "$1" "$cloud"; shift 2 ;;
            --identity) identity_file="${2:-}"; need_value "$1" "$identity_file"; shift 2 ;;
            --port) port="${2:-}"; need_value "$1" "$port"; shift 2 ;;
            --cloud-ssh-port) cloud_ssh_port="${2:-}"; need_value "$1" "$cloud_ssh_port"; shift 2 ;;
            --local-ssh-port) local_port="${2:-}"; need_value "$1" "$local_port"; shift 2 ;;
            --name) service_name="${2:-}"; need_value "$1" "$service_name"; shift 2 ;;
            *) echo "[ERROR] Unknown install-tunnel-service option: $1" >&2; exit 2 ;;
        esac
    done
    [ -n "$cloud" ] || { echo "[ERROR] --cloud user@host is required" >&2; exit 2; }
    script_path="$(current_script_path)"

    case "$(uname -s 2>/dev/null || echo unknown)" in
        Darwin)
            local plist_dir plist_path
            plist_dir="$HOME/Library/LaunchAgents"
            plist_path="$plist_dir/com.openclaw.${service_name}.plist"
            mkdir -p "$plist_dir"
            cat > "$plist_path" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.openclaw.${service_name}</string>
  <key>ProgramArguments</key>
  <array>
    <string>$script_path</string><string>start-tunnel</string><string>--cloud</string><string>$cloud</string>
    <string>--cloud-ssh-port</string><string>$cloud_ssh_port</string>
    <string>--port</string><string>$port</string><string>--local-ssh-port</string><string>$local_port</string>
$(if [ -n "$identity_file" ]; then printf '    <string>--identity</string><string>%s</string>\n' "$identity_file"; fi)
  </array>
  <key>KeepAlive</key><true/>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/tmp/${service_name}.out.log</string>
  <key>StandardErrorPath</key><string>/tmp/${service_name}.err.log</string>
</dict>
</plist>
EOF_PLIST
            echo "[INFO] LaunchAgent installed: $plist_path"
            echo "[INFO] Enable with: launchctl load -w '$plist_path'"
            ;;
        Linux)
            local unit_dir unit_path identity_part
            unit_dir="$HOME/.config/systemd/user"
            unit_path="$unit_dir/${service_name}.service"
            mkdir -p "$unit_dir"
            identity_part=""
            [ -n "$identity_file" ] && identity_part=" --identity '$identity_file'"
            cat > "$unit_path" <<EOF_UNIT
[Unit]
Description=OpenClaw local reverse SSH tunnel
After=network-online.target

[Service]
ExecStart=$script_path start-tunnel --cloud '$cloud'$identity_part --cloud-ssh-port '$cloud_ssh_port' --port '$port' --local-ssh-port '$local_port'
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF_UNIT
            echo "[INFO] systemd/user service installed: $unit_path"
            echo "[INFO] Enable with: systemctl --user enable --now '$service_name.service'"
            ;;
        *)
            echo "[ERROR] Unsupported OS for service install. Use start-tunnel manually." >&2
            exit 2
            ;;
    esac
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
service_name=$OPENCLAW_REMOTE_LOCAL_SERVICE_NAME
cloud_ssh_port=$OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT
pairing_file=$OPENCLAW_REMOTE_LOCAL_PAIRING_FILE
cloud_port_from_env=$OPENCLAW_REMOTE_LOCAL_CLOUD_PORT_INPUT
cloud_ssh_port_from_env=$OPENCLAW_REMOTE_LOCAL_CLOUD_SSH_PORT_INPUT
EOF_STATUS
}

cmd="${1:-help}"
shift || true
case "$cmd" in
    help|-h|--help) usage ;;
    configure-local) configure_local "$@" ;;
    install-local) install_local "$@" ;;
    install-cloud) install_cloud "$@" ;;
    install-tunnel-service) install_tunnel_service "$@" ;;
    bootstrap-local) bootstrap_local "$@" ;;
    start-tunnel) start_tunnel "$@" ;;
    run) run_remote "$@" ;;
    status) status ;;
    *) echo "[ERROR] Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac
