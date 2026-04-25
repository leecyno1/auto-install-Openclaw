#!/usr/bin/env bash
#===============================================================================
# API 配置模块 - API Configuration Module
#
# 职责：
# - 修改多层配置文件中的 API 端点和密钥
# - 替换 Skills 中硬编码的第三方服务地址
# - 支持 NanoBanana, Gemini, OpenAI, MiniMax 等服务
#
# CLI 用法：
#   openclaw-setup config api --show              # 显示当前配置
#   openclaw-setup config api --provider <name>    # 设置提供商配置
#   openclaw-setup config api --replace-service <service> --with <url>  # 替换服务地址
#   openclaw-setup config api --list-overrides    # 列出 API 覆盖配置
#   openclaw-setup config api --rollback [--name <backup>]  # 回滚修改
#===============================================================================

set -euo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# API Replacer 脚本
API_REPLACER="$SCRIPT_DIR/api_replacer.py"

# 配置文件路径
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
OPENCLAW_ENV="$HOME/.openclaw/env"
API_OVERRIDES="$HOME/.openclaw/api-overrides.json"
PIXEL_HOUSE_CONFIG="$HOME/.openclaw/pixel-house/web/configure.js"

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
    echo "[WARN] $*"
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

backup_file() {
    local file="$1"
    local backup_dir="$HOME/.openclaw/backups"
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    if [ -f "$file" ]; then
        ensure_dir "$backup_dir"
        cp "$file" "$backup_dir/$(basename "$file").$timestamp.bak"
        log_info "Backed up: $file -> $backup_dir/"
    fi
}

upsert_env() {
    local key="$1"
    local value="$2"
    local env_file="${3:-$OPENCLAW_ENV}"

    ensure_dir "$env_file"

    if grep -q "^export $key=" "$env_file" 2>/dev/null; then
        sed -i.bak "s|^export $key=.*|export $key=\"$value\"|" "$env_file"
    elif grep -q "^$key=" "$env_file" 2>/dev/null; then
        sed -i.bak "s|^$key=.*|$key=\"$value\"|" "$env_file"
    else
        echo "export $key=\"$value\"" >> "$env_file"
    fi
}

#===============================================================================
# 显示配置
#===============================================================================

show_api_config() {
    echo ""
    echo "=== API Configuration Status ==="
    echo ""

    # 显示 env 中的 API 配置
    if [ -f "$OPENCLAW_ENV" ]; then
        echo "Environment Variables:"
        grep -E "(API_KEY|API_BASE|ENDPOINT|BASE_URL)" "$OPENCLAW_ENV" 2>/dev/null || echo "  (none set)"
    fi

    # 显示 API Overrides 配置
    echo ""
    echo "Service Overrides:"
    if [ -f "$API_OVERRIDES" ]; then
        python3 - "$API_OVERRIDES" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
    for svc, cfg in data.items():
        print(f"  {svc}:")
        if "original" in cfg:
            print(f"    original: {cfg['original']}")
        print(f"    replacement: {cfg['replacement']}")
except:
    print("  (error reading file)")
PY
    else
        echo "  (no overrides configured)"
    fi

    echo ""
}

#===============================================================================
# 设置提供商配置
#===============================================================================

set_provider_config() {
    local provider="$1"
    local endpoint="${2:-}"
    local api_key="${3:-}"

    case "$provider" in
        anthropic)
            [ -n "$api_key" ] && upsert_env "ANTHROPIC_API_KEY" "$api_key"
            [ -n "$endpoint" ] && upsert_env "ANTHROPIC_API_BASE" "$endpoint"
            log_success "Anthropic API configured"
            ;;

        openai)
            [ -n "$api_key" ] && upsert_env "OPENAI_API_KEY" "$api_key"
            [ -n "$endpoint" ] && upsert_env "OPENAI_API_BASE" "$endpoint"
            log_success "OpenAI API configured"
            ;;

        gemini)
            [ -n "$api_key" ] && upsert_env "GEMINI_API_KEY" "$api_key"
            [ -n "$endpoint" ] && upsert_env "GEMINI_BASE_URL" "$endpoint"
            log_success "Gemini API configured"
            ;;

        minimax)
            [ -n "$api_key" ] && upsert_env "MINIMAX_API_KEY" "$api_key"
            [ -n "$endpoint" ] && upsert_env "MINIMAX_API_BASE" "$endpoint"
            log_success "MiniMax API configured"
            ;;

        *)
            log_error "Unknown provider: $provider"
            echo "Supported: anthropic, openai, gemini, minimax"
            return 1
            ;;
    esac

    # 如果有 Pixel House 配置，也更新它
    if [ -f "$PIXEL_HOUSE_CONFIG" ]; then
        update_pixel_house_config "$provider" "$endpoint"
    fi
}

update_pixel_house_config() {
    local provider="$1"
    local endpoint="$2"

    backup_file "$PIXEL_HOUSE_CONFIG"

    case "$provider" in
        anthropic)
            sed -i.bak "s|https://api.anthropic.com|$endpoint|g" "$PIXEL_HOUSE_CONFIG" 2>/dev/null || true
            ;;
        openai)
            sed -i.bak "s|https://api.openai.com/v1|$endpoint|g" "$PIXEL_HOUSE_CONFIG" 2>/dev/null || true
            ;;
        gemini)
            sed -i.bak "s|https://generativelanguage.googleapis.com|$endpoint|g" "$PIXEL_HOUSE_CONFIG" 2>/dev/null || true
            ;;
    esac

    log_info "Updated Pixel House config"
}

#===============================================================================
# 替换 Skills 中的服务地址
#===============================================================================

replace_service_url() {
    local service="$1"
    local new_url="$2"

    if ! command -v python3 &>/dev/null; then
        log_error "Python3 is required for this operation"
        return 1
    fi

    # 添加或更新 overrides 配置
    ensure_dir "$API_OVERRIDES"

    python3 - "$API_OVERRIDES" "$service" "$new_url" <<'PY'
import json, sys, os
path, service, url = sys.argv[1], sys.argv[2], sys.argv[3]

data = {}
if os.path.exists(path):
    data = json.load(open(path))

data[service] = {"replacement": url}

with open(path, 'w') as f:
    json.dump(data, f, indent=2)

print(f"Updated: {path}")
PY

    log_success "Added override for: $service -> $new_url"

    # 扫描并替换 skills 中的地址
    local skills_dir="$HOME/.openclaw/skills"

    if [ -d "$skills_dir" ]; then
        log_info "Scanning skills for hardcoded URLs..."

        python3 "$API_REPLACER" replace \
            --skills-dir "$skills_dir" \
            --overrides "$API_OVERRIDES"
    else
        log_warn "Skills directory not found: $skills_dir"
        log_info "Run 'openclaw-setup config skills' first to install skills"
    fi
}

#===============================================================================
# 列出当前覆盖配置
#===============================================================================

list_overrides() {
    if ! command -v python3 &>/dev/null; then
        log_error "Python3 is required for this operation"
        return 1
    fi

    python3 "$API_REPLACER" list --overrides "$API_OVERRIDES"
}

#===============================================================================
# 回滚修改
#===============================================================================

rollback_changes() {
    local backup_name="${1:-}"

    if ! command -v python3 &>/dev/null; then
        log_error "Python3 is required for this operation"
        return 1
    fi

    if [ -n "$backup_name" ]; then
        python3 "$API_REPLACER" rollback --name "$backup_name"
    else
        python3 "$API_REPLACER" rollback
    fi
}

#===============================================================================
# 帮助信息
#===============================================================================

show_help() {
    cat <<'EOF'
API Configuration Module

Usage:
  openclaw-setup config api [command] [options]

Commands:
  --show                 Show current API configuration
  --provider <name>      Configure API provider (anthropic/openai/gemini/minimax)
                         Additional options:
                           --endpoint <url>   Set API endpoint
                           --key <key>       Set API key
  --replace-service <svc> --with <url>
                         Replace hardcoded URL for a service
                         Supported services: nanobanana, gemini, openai, minimax, replicate
  --list-overrides       List current service overrides
  --rollback [--name <backup>]
                         Rollback to a previous backup
  --help                 Show this help message

Examples:
  # Configure Anthropic API
  openclaw-setup config api --provider anthropic --endpoint https://api.anthropic.com --key sk-xxx

  # Replace NanoBanana URL in skills
  openclaw-setup config api --replace-service nanobanana --with https://my-service.com/api

  # List all overrides
  openclaw-setup config api --list-overrides

  # Rollback changes
  openclaw-setup config api --rollback

EOF
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    local command=""
    local provider=""
    local endpoint=""
    local api_key=""
    local service=""
    local new_url=""
    local backup_name=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --show)
                command="show"
                ;;
            --provider)
                provider="$2"
                shift
                ;;
            --endpoint)
                endpoint="$2"
                shift
                ;;
            --key)
                api_key="$2"
                shift
                ;;
            --replace-service)
                service="$2"
                shift
                ;;
            --with)
                new_url="$2"
                shift
                ;;
            --list-overrides)
                command="list"
                ;;
            --rollback)
                command="rollback"
                ;;
            --name)
                backup_name="$2"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # 执行命令
    case "$command" in
        show)
            show_api_config
            ;;
        list)
            list_overrides
            ;;
        rollback)
            rollback_changes "$backup_name"
            ;;
        "")
            # 没有显式命令，可能是 --provider 或 --replace-service
            if [ -n "$provider" ]; then
                set_provider_config "$provider" "$endpoint" "$api_key"
            elif [ -n "$service" ] && [ -n "$new_url" ]; then
                replace_service_url "$service" "$new_url"
            else
                show_help
            fi
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
