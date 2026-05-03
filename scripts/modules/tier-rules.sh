#!/usr/bin/env bash
#===============================================================================
# 三档注入规则模块 - Tier Rules Module
#
# 职责：
# - 配置三档流量规则（low/medium/high/none）
# - 设置配额限制（请求数、图片数、视频数）
# - 写入请求次数/媒体配额规则；13147 兼容代理仅按显式命令启动
#
# CLI 用法：
#   openclaw-setup config tier-rules --level low|medium|high|none
#   openclaw-setup config tier-rules --restart-enforcer
#   openclaw-setup config tier-rules --show
#===============================================================================

# 检测 bash 版本，使用较新的 bash 如果可用
if [[ "${BASH_VERSION}" < "4.3" ]]; then
    # 尝试使用 homebrew bash (macOS)
    if [ -x "/opt/homebrew/bin/bash" ]; then
        exec /opt/homebrew/bin/bash "$0" "$@"
    elif [ -x "/usr/local/bin/bash" ]; then
        exec /usr/local/bin/bash "$0" "$@"
    fi
fi

set -uo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 相关脚本
APPLY_WEB_PROFILE="$REPO_ROOT/scripts/apply-web-profile.sh"
MEDIA_QUOTA="$REPO_ROOT/scripts/media_quota.py"
GATEWAY_ENFORCER="$REPO_ROOT/scripts/gateway-quota-enforcer.py"

# 配置文件
OPENCLAW_ENV="$HOME/.openclaw/env"
WEB_PROFILE="$HOME/.openclaw/profile/web-config-profile.json"

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

ensure_dir() {
    mkdir -p "$(dirname "$1")"
}

# 更新或插入环境变量
upsert_env() {
    local key="$1"
    local value="$2"
    local env_file="${3:-$OPENCLAW_ENV}"

    ensure_dir "$env_file"

    # 确保文件存在
    touch "$env_file"

    if grep -qE "^export $key=" "$env_file" 2>/dev/null; then
        # 使用临时文件避免 sed -i 在 macOS 上的问题
        sed -i.bak "s|^export $key=.*|export $key=\"$value\"|" "$env_file"
        rm -f "$env_file.bak"
    elif grep -qE "^$key=" "$env_file" 2>/dev/null; then
        sed -i.bak "s|^$key=.*|$key=\"$value\"|" "$env_file"
        rm -f "$env_file.bak"
    else
        echo "export $key=\"$value\"" >> "$env_file"
    fi
}

#===============================================================================
# 三档配额定义
#===============================================================================

declare -A TIER_MAX_REQUESTS=(
    ["none"]="0"
    ["low"]="100"
    ["medium"]="300"
    ["high"]="0"
)

declare -A TIER_MAX_IMAGE_REQUESTS=(
    ["none"]="0"
    ["low"]="0"
    ["medium"]="20"
    ["high"]="50"
)

declare -A TIER_MAX_VIDEO_REQUESTS=(
    ["none"]="0"
    ["low"]="0"
    ["medium"]="1"
    ["high"]="2"
)

declare -A TIER_WINDOW_HOURS=(
    ["none"]="5"
    ["low"]="5"
    ["medium"]="5"
    ["high"]="5"
)

#===============================================================================
# 获取当前配置
#===============================================================================

get_current_level() {
    local level="medium"  # 默认值

    if [ -f "$OPENCLAW_ENV" ]; then
        level="$(grep "OPENCLAW_RULE_PROFILE" "$OPENCLAW_ENV" 2>/dev/null | cut -d'"' -f2 || echo "medium")"
    fi

    echo "$level"
}

show_current_config() {
    echo ""
    echo "=== Tier Rules Configuration ==="
    echo ""

    local level
    level="$(get_current_level)"

    echo "Current Level: $level"
    echo ""

    echo "Limits for $level:"
    echo "  Max Requests:      ${TIER_MAX_REQUESTS["$level"]:-unlimited}"
    echo "  Max Image Req:    ${TIER_MAX_IMAGE_REQUESTS["$level"]:-0}"
    echo "  Max Video Req:    ${TIER_MAX_VIDEO_REQUESTS["$level"]:-0}"
    echo "  Window Hours:     ${TIER_WINDOW_HOURS["$level"]:-5}"

    echo ""

    # 检查网关执行器状态
    if [ -f "$GATEWAY_ENFORCER" ]; then
        if pgrep -f "gateway-quota-enforcer" >/dev/null 2>&1; then
            echo "Gateway Enforcer: Running"
        else
            echo "Gateway Enforcer: Stopped"
        fi
    else
        echo "Gateway Enforcer: Not available"
    fi

    echo ""
}

#===============================================================================
# 设置档位
#===============================================================================

set_tier_level() {
    local level="$1"

    # 验证档位
    case "$level" in
        none|low|medium|high) ;;
        *)
            log_error "Invalid level: $level"
            echo "Valid levels: none, low, medium, high"
            return 1
            ;;
    esac

    log_info "Setting tier level to: $level"

    # 更新环境变量
    upsert_env "OPENCLAW_RULE_PROFILE" "$level"
    upsert_env "OPENCLAW_RULE_WINDOW_HOURS" "${TIER_WINDOW_HOURS["$level"]}"
    upsert_env "OPENCLAW_RULE_MAX_REQUESTS" "${TIER_MAX_REQUESTS["$level"]}"
    upsert_env "OPENCLAW_RULE_MAX_IMAGE_REQUESTS" "${TIER_MAX_IMAGE_REQUESTS["$level"]}"
    upsert_env "OPENCLAW_RULE_MAX_VIDEO_REQUESTS" "${TIER_MAX_VIDEO_REQUESTS["$level"]}"
    upsert_env "OPENCLAW_MEDIA_QUOTA_STATE_FILE" "$HOME/.openclaw/quota/media-state.json"

    # 应用到 web profile（如果存在）
    if [ -f "$APPLY_WEB_PROFILE" ]; then
        log_info "Applying web profile..."
        bash "$APPLY_WEB_PROFILE" "$level" 2>/dev/null || true
    fi

    update_quota_config "$level"
    log_success "Tier level set to: $level"
}

update_quota_config() {
    local level="$1"

    # 设置环境变量让配额脚本使用正确的配置
    export OPENCLAW_RULE_PROFILE="$level"
    export OPENCLAW_RULE_MAX_IMAGE_REQUESTS="${TIER_MAX_IMAGE_REQUESTS["$level"]}"
    export OPENCLAW_RULE_MAX_VIDEO_REQUESTS="${TIER_MAX_VIDEO_REQUESTS["$level"]}"
    export OPENCLAW_RULE_MAX_REQUESTS="${TIER_MAX_REQUESTS["$level"]}"
    export OPENCLAW_RULE_WINDOW_HOURS="${TIER_WINDOW_HOURS["$level"]}"
    export OPENCLAW_MEDIA_QUOTA_STATE_FILE="$HOME/.openclaw/quota/media-state.json"
}

#===============================================================================
# 网关执行器管理
#===============================================================================

start_gateway_enforcer() {
    log_info "Starting gateway quota enforcer..."

    if [ ! -f "$GATEWAY_ENFORCER" ]; then
        log_error "Gateway enforcer script not found: $GATEWAY_ENFORCER"
        return 1
    fi

    # 检查是否已在运行
    if pgrep -f "gateway-quota-enforcer" >/dev/null 2>&1; then
        log_warn "Gateway enforcer is already running"
        return 0
    fi

    # 启动执行器
    python3 "$GATEWAY_ENFORCER" start 2>&1 || {
        log_error "Failed to start gateway enforcer"
        return 1
    }

    log_success "Gateway enforcer started on compatibility port 13147"
    log_info "Compatibility quota proxy: http://127.0.0.1:13147"
}

stop_gateway_enforcer() {
    log_info "Stopping gateway quota enforcer..."

    if [ -f "$GATEWAY_ENFORCER" ]; then
        python3 "$GATEWAY_ENFORCER" stop 2>&1 || true
    fi

    # 也尝试通过 pkill
    pkill -f "gateway-quota-enforcer" 2>/dev/null || true

    log_success "Gateway enforcer stopped"
}

restart_gateway_enforcer() {
    stop_gateway_enforcer
    sleep 1
    start_gateway_enforcer
}

#===============================================================================
# 状态检查
#===============================================================================

check_status() {
    echo ""
    echo "=== Tier Rules Status ==="
    echo ""

    show_current_config

    # 检查配额状态
    if [ -f "$MEDIA_QUOTA" ]; then
        echo "Quota Status:"
        python3 "$MEDIA_QUOTA" status 2>/dev/null || echo "  (unable to query)"
    fi

    echo ""
}

#===============================================================================
# 帮助信息
#===============================================================================

show_help() {
    cat <<'EOF'
Tier Rules Module

Usage:
  openclaw-setup config tier-rules [options]

Options:
  --level, -l <level>     Set tier level: none, low, medium, high
  --with-monitoring       Deprecated compatibility flag; does not auto-start services
  --start-enforcer        Start gateway enforcer only
  --stop-enforcer         Stop gateway enforcer only
  --restart-enforcer      Restart gateway enforcer
  --show, -s              Show current configuration
  --status                Show detailed status
  --help, -h              Show this help message

Levels:
  none    No limits (unrestricted)
  low     100 req/5h, 0 images, 0 videos
  medium  300 req/5h, 20 images, 1 video
  high    unlimited text req, 50 images, 2 videos

Examples:
  # Set to medium tier
  openclaw-setup config tier-rules --level medium

  # Start the legacy quota proxy explicitly when needed
  openclaw-setup config tier-rules --restart-enforcer

  # Check status
  openclaw-setup config tier-rules --status

EOF
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    local level=""
    local with_monitoring="false"
    local show_only="false"
    local status_only="false"
    local enforcer_action=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --level|-l)
                level="$2"
                shift
                ;;
            --with-monitoring)
                with_monitoring="true"
                ;;
            --start-enforcer)
                enforcer_action="start"
                ;;
            --stop-enforcer)
                enforcer_action="stop"
                ;;
            --restart-enforcer)
                enforcer_action="restart"
                ;;
            --show|-s)
                show_only="true"
                ;;
            --status)
                status_only="true"
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

    # 执行器操作
    case "$enforcer_action" in
        start)
            start_gateway_enforcer
            exit $?
            ;;
        stop)
            stop_gateway_enforcer
            exit $?
            ;;
        restart)
            restart_gateway_enforcer
            exit $?
            ;;
    esac

    # 显示模式
    if [ "$show_only" = "true" ]; then
        show_current_config
        exit 0
    fi

    # 状态模式
    if [ "$status_only" = "true" ]; then
        check_status
        exit 0
    fi

    # 设置档位
    if [ -n "$level" ]; then
        set_tier_level "$level"

        if [ "$with_monitoring" = "true" ]; then
            echo ""
            log_info "--with-monitoring 已兼容保留；如需 13147 兼容代理，请显式使用 --restart-enforcer。"
        fi
    else
        show_help
    fi
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
