#!/usr/bin/env bash
#===============================================================================
# Skills 管理模块 - Skills Management Module
#
# 职责：
# - 基础 skills (~60) 从本地仓库快速安装
# - 扩展 skills (~80) 从官方源同步（保持更新）
# - 基于 skills/manifest.json 的三档管理（basic/extended/super）
#
# CLI 用法：
#   openclaw-setup config skills --tier basic|extended|super
#   openclaw-setup config skills --list
#   openclaw-setup config skills --force-local
#===============================================================================

set -euo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Skills 相关路径
SKILLS_LOCAL_SOURCE="$REPO_ROOT/skills/default"
SKILLS_LOCAL_MANIFEST="$REPO_ROOT/skills/manifest.json"
SKILLS_INSTALL_TARGET="$HOME/.openclaw/skills"

# 加载共享的 skills 库
if [ -f "$REPO_ROOT/scripts/lib/skills.sh" ]; then
    source "$REPO_ROOT/scripts/lib/skills.sh"
fi

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
    mkdir -p "$1"
}

count_skills() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -type d | wc -l | tr -d ' '
    else
        echo "0"
    fi
}

get_tier_skills() {
    local tier="$1"
    local skills=""

    # 使用 manifest.json 获取 skill 列表
    if [ -f "$SKILLS_LOCAL_MANIFEST" ]; then
        skills="$(openclaw_skill_manifest_list "bundles:$tier" 2>/dev/null || echo "")"
    fi

    # 如果 manifest 获取失败，使用 fallback
    if [ -z "$skills" ]; then
        case "$tier" in
            basic)
                openclaw_skill_fallback_init
                skills="$PROFILE_BASIC_SKILLS"
                ;;
            extended)
                openclaw_skill_fallback_init
                skills="$PROFILE_EXTENDED_SKILLS"
                ;;
            super)
                openclaw_skill_fallback_init
                skills="$PROFILE_SUPER_SKILLS"
                ;;
        esac
    fi

    echo "$skills"
}

#===============================================================================
# 安装基础 Skills（本地快速安装）
#===============================================================================

install_basic_skills_local() {
    log_info "Installing basic skills from local repository..."

    ensure_dir "$SKILLS_INSTALL_TARGET"

    local basic_skills
    basic_skills="$(get_tier_skills "basic")"

    local installed=0
    local skipped=0

    for skill in $basic_skills; do
        local source_dir="$SKILLS_LOCAL_SOURCE/$skill"

        if [ -d "$source_dir" ]; then
            if [ -d "$SKILLS_INSTALL_TARGET/$skill" ]; then
                # 已安装，跳过或更新
                if [ "$FORCE_UPDATE" = "true" ]; then
                    rm -rf "$SKILLS_INSTALL_TARGET/$skill"
                    cp -R "$source_dir" "$SKILLS_INSTALL_TARGET/"
                    ((installed++))
                else
                    ((skipped++))
                fi
            else
                cp -R "$source_dir" "$SKILLS_INSTALL_TARGET/"
                ((installed++))
            fi
            log_info "  Installed: $skill"
        else
            log_warn "  Missing: $skill (not found in local repository)"
        fi
    done

    log_success "Basic skills: $installed installed, $skipped skipped"
}

#===============================================================================
# 安装扩展 Skills（官方源 + 本地回退）
#===============================================================================

install_extended_skills_official() {
    log_info "Installing extended skills from official source..."

    # 尝试使用官方 CLI 同步
    if command -v openclaw &>/dev/null; then
        log_info "Using 'openclaw skills sync'..."

        if openclaw skills sync 2>&1; then
            log_success "Official skills synced successfully"
            return 0
        else
            log_warn "Official sync failed, falling back to local..."
        fi
    else
        log_warn "OpenClaw CLI not found, using local repository"
    fi

    return 1
}

install_extended_skills_local() {
    local tier="${1:-extended}"

    log_info "Installing extended skills from local repository..."

    local extended_skills
    extended_skills="$(get_tier_skills "$tier")"

    local installed=0

    for skill in $extended_skills; do
        local source_dir="$SKILLS_LOCAL_SOURCE/$skill"

        if [ -d "$source_dir" ]; then
            if [ ! -d "$SKILLS_INSTALL_TARGET/$skill" ]; then
                cp -R "$source_dir" "$SKILLS_INSTALL_TARGET/"
                ((installed++))
                log_info "  Installed: $skill"
            fi
        else
            log_warn "  Missing: $skill"
        fi
    done

    log_success "Extended skills: $installed installed"
}

#===============================================================================
# 验证安装
#===============================================================================

verify_installation() {
    local tier="${1:-basic}"

    log_info "Verifying skills installation..."

    local expected_skills
    expected_skills="$(get_tier_skills "$tier")"

    local installed_count
    installed_count="$(count_skills "$SKILLS_INSTALL_TARGET")"
    ((installed_count--))  # 减去 . 目录本身

    log_info "Installed: $installed_count skills"
    log_info "Target tier: $tier"

    # 检查关键 skills
    local critical_skills="shell agent subagent-driven-development"
    local missing=""

    for skill in $critical_skills; do
        if [ ! -d "$SKILLS_INSTALL_TARGET/$skill" ]; then
            missing="$missing $skill"
        fi
    done

    if [ -n "$missing" ]; then
        log_warn "Missing critical skills:$missing"
        return 1
    fi

    log_success "Verification passed"
}

#===============================================================================
# 列出已安装/可用的 Skills
#===============================================================================

list_skills() {
    echo ""
    echo "=== Skills Status ==="
    echo ""

    # 已安装的 skills
    echo "Installed skills ($(count_skills "$SKILLS_INSTALL_TARGET") skills):"
    if [ -d "$SKILLS_INSTALL_TARGET" ]; then
        find "$SKILLS_INSTALL_TARGET" -maxdepth 1 -type d -not -name ".git*" | \
            sed 's|.*/||' | sort | while read -r skill; do
            echo "  - $skill"
        done
    else
        echo "  (none installed)"
    fi

    echo ""

    # 本地可用的 skills
    echo "Available in local repository ($(count_skills "$SKILLS_LOCAL_SOURCE") skills):"
    if [ -d "$SKILLS_LOCAL_SOURCE" ]; then
        find "$SKILLS_LOCAL_SOURCE" -maxdepth 1 -type d -not -name ".git*" | \
            sed 's|.*/||' | sort | head -20 | while read -r skill; do
            local status=""
            [ -d "$SKILLS_INSTALL_TARGET/$skill" ] && status="[installed]"
            echo "  - $skill $status"
        done
        echo "  ... (showing first 20)"
    fi

    echo ""
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    local tier="basic"
    local force_local="false"
    local list_only="false"
    local force_update="false"
    export FORCE_UPDATE="false"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tier|-t)
                tier="$2"
                shift
                ;;
            --force-local|-l)
                force_local="true"
                ;;
            --list|-l)
                list_only="true"
                ;;
            --force-update|-f)
                force_update="true"
                export FORCE_UPDATE="true"
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

    # 验证 tier
    case "$tier" in
        basic|extended|super) ;;
        *)
            log_error "Invalid tier: $tier"
            echo "Valid tiers: basic, extended, super"
            exit 1
            ;;
    esac

    # 列出模式
    if [ "$list_only" = "true" ]; then
        list_skills
        exit 0
    fi

    # 安装模式
    log_info "Starting skills installation (tier: $tier)..."
    echo ""

    # 1. 基础 skills - 始终从本地快速安装
    install_basic_skills_local

    # 2. 扩展 skills - 根据策略
    if [ "$tier" != "basic" ]; then
        echo ""
        if [ "$force_local" = "true" ]; then
            install_extended_skills_local "$tier"
        else
            # 混合策略：优先官方，失败后本地
            if ! install_extended_skills_official; then
                install_extended_skills_local "$tier"
            fi
        fi
    fi

    # 3. 验证
    echo ""
    verify_installation "$tier"

    echo ""
    log_success "Skills installation complete!"
    log_info "Run 'openclaw-setup config skills --list' to see all installed skills"
}

show_help() {
    cat <<'EOF'
Skills Management Module

Usage:
  openclaw-setup config skills [options]

Options:
  --tier, -t <tier>     Installation tier: basic, extended, super (default: basic)
  --force-local, -l      Skip official sync, use local repository only
  --list, -l             List installed and available skills
  --force-update, -f     Force update already installed skills
  --help, -h             Show this help message

Tiers:
  basic      ~60 core skills (shell, agent, subagent, browser, github, etc.)
  extended   basic + extended skills (~80 total)
  super      basic + extended + curated skills (~100+ total)

Examples:
  # Install basic skills
  openclaw-setup config skills

  # Install extended skills
  openclaw-setup config skills --tier extended

  # Force local installation
  openclaw-setup config skills --force-local

  # List all skills
  openclaw-setup config skills --list

EOF
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
