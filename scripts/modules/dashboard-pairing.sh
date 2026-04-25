#!/usr/bin/env bash
#===============================================================================
# Dashboard 配对修复模块 - Dashboard Pairing Fix Module
#
# 职责：
# - 修复 Dashboard 配对问题（pairing required）
# - 配置 gateway.controlUi.allowedOrigins
# - 禁用设备认证以支持内嵌/代理场景
# - 自动重启 Gateway 使配置生效
#
# CLI 用法：
#   openclaw-setup config dashboard-pairing --fix
#   openclaw-setup config dashboard-pairing --show
#===============================================================================

set -euo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 配置文件
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
OPENCLAW_ENV="$HOME/.openclaw/env"
DEFAULT_GATEWAY_PORT="13145"

#===============================================================================
# 日志函数
#===============================================================================

log_info() {
    echo "[INFO] $*"
}

log_success() {
    echo "[SUCCESS] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

#===============================================================================
# 辅助函数
#===============================================================================

check_openclaw_installed() {
    if ! command -v openclaw >/dev/null 2>&1; then
        log_error "OpenClaw not installed"
        return 1
    fi
    return 0
}

get_gateway_port() {
    local port="$DEFAULT_GATEWAY_PORT"

    if [ -f "$OPENCLAW_ENV" ]; then
        port="$(grep "OPENCLAW_GATEWAY_PORT" "$OPENCLAW_ENV" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "$DEFAULT_GATEWAY_PORT")"
    fi

    echo "${port:-$DEFAULT_GATEWAY_PORT}"
}

#===============================================================================
# Dashboard 配对修复
#===============================================================================

apply_dashboard_pairing_bypass() {
    log_info "Applying dashboard pairing bypass..."

    if [ ! -f "$OPENCLAW_JSON" ]; then
        log_error "OpenClaw config not found: $OPENCLAW_JSON"
        return 1
    fi

    # 使用 Python 修改配置
    python3 - "$OPENCLAW_JSON" "$(get_gateway_port)" <<'PYEOF'
import json
import os
import secrets
import sys

cfg_path = os.path.expanduser(sys.argv[1])
gateway_port = str(sys.argv[2]).strip() or "13145"

with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

gateway = cfg.setdefault("gateway", {})
control_ui = gateway.setdefault("controlUi", {})
auth = gateway.setdefault("auth", {})

# 配置 allowedOrigins
existing = control_ui.get("allowedOrigins", [])
if not isinstance(existing, list):
    existing = []

required = [
    f"http://127.0.0.1:{gateway_port}",
    f"https://127.0.0.1:{gateway_port}",
    f"http://localhost:{gateway_port}",
    f"https://localhost:{gateway_port}",
]

# 合并并去重
merged = []
seen = set()
for item in [*existing, *required]:
    v = str(item).strip()
    if not v or v in seen:
        continue
    seen.add(v)
    merged.append(v)

control_ui["allowedOrigins"] = merged

# 配置认证模式
if str(auth.get("mode", "")).strip().lower() != "token":
    auth["mode"] = "token"

if not str(auth.get("token", "")).strip():
    auth["token"] = secrets.token_hex(24)

# 禁用配对要求（支持内嵌/代理场景）
control_ui["allowInsecureAuth"] = True
control_ui["dangerouslyDisableDeviceAuth"] = True

# 保存配置
with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)

print("Dashboard pairing bypass applied")
PYEOF

    log_success "Dashboard pairing bypass applied"
}

restart_gateway() {
    log_info "Restarting Gateway..."

    # 尝试重启 Gateway
    if command -v openclaw >/dev/null 2>&1; then
        # 先停止
        openclaw gateway stop >/dev/null 2>&1 || true
        sleep 2

        # 再启动
        openclaw gateway start >/dev/null 2>&1 || {
            log_warn "Failed to restart gateway automatically"
            log_info "Please restart manually: openclaw gateway restart"
            return 1
        }

        log_success "Gateway restarted"
    else
        log_warn "openclaw command not found, please restart manually"
    fi
}

#===============================================================================
# 修复 Dashboard 配对
#===============================================================================

fix_dashboard_pairing() {
    log_info "Fixing dashboard pairing..."
    echo ""

    if ! check_openclaw_installed; then
        return 1
    fi

    # 应用配对绕过配置
    apply_dashboard_pairing_bypass || return 1

    # 运行 doctor 修复
    log_info "Running openclaw doctor..."
    if openclaw doctor --help 2>/dev/null | grep -q -- "--non-interactive"; then
        openclaw doctor --non-interactive >/dev/null 2>&1 || true
    else
        yes | openclaw doctor --fix >/dev/null 2>&1 || true
    fi

    # 重启 Gateway
    restart_gateway || true

    echo ""
    log_success "Dashboard pairing fix completed"
    echo ""
    echo "Next steps:"
    echo "  1. Open dashboard: openclaw dashboard"
    echo "  2. Or visit: http://localhost:$(get_gateway_port)"
    echo ""
}

#===============================================================================
# 显示当前配置
#===============================================================================

show_dashboard_config() {
    echo ""
    echo "=== Dashboard Configuration ==="
    echo ""

    if [ ! -f "$OPENCLAW_JSON" ]; then
        echo "Config file not found: $OPENCLAW_JSON"
        return 1
    fi

    # 使用 Python 读取配置
    python3 - "$OPENCLAW_JSON" <<'PYEOF'
import json
import sys

cfg_path = sys.argv[1]

with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

gateway = cfg.get("gateway", {})
control_ui = gateway.get("controlUi", {})
auth = gateway.get("auth", {})

print("Gateway Port:", gateway.get("port", "13145"))
print("")
print("Control UI:")
print("  allowInsecureAuth:", control_ui.get("allowInsecureAuth", False))
print("  dangerouslyDisableDeviceAuth:", control_ui.get("dangerouslyDisableDeviceAuth", False))
print("")
print("Allowed Origins:")
for origin in control_ui.get("allowedOrigins", []):
    print(f"  - {origin}")
print("")
print("Auth Mode:", auth.get("mode", "none"))
print("Auth Token:", "configured" if auth.get("token") else "not set")
PYEOF

    echo ""
}

#===============================================================================
# 帮助信息
#===============================================================================

show_help() {
    cat <<'EOF'
Dashboard Pairing Fix Module

Usage:
  openclaw-setup config dashboard-pairing [options]

Options:
  --fix              Fix dashboard pairing issues
  --show             Show current dashboard configuration
  --restart-gateway  Restart gateway only
  --help, -h         Show this help message

Examples:
  # Fix dashboard pairing
  openclaw-setup config dashboard-pairing --fix

  # Show current config
  openclaw-setup config dashboard-pairing --show

  # Restart gateway
  openclaw-setup config dashboard-pairing --restart-gateway

EOF
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    local action=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fix)
                action="fix"
                ;;
            --show)
                action="show"
                ;;
            --restart-gateway)
                action="restart"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # 执行动作
    case "$action" in
        fix)
            fix_dashboard_pairing
            ;;
        show)
            show_dashboard_config
            ;;
        restart)
            restart_gateway
            ;;
        *)
            show_help
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
