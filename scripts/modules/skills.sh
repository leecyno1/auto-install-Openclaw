#!/usr/bin/env bash
#===============================================================================
# Skills 管理模块 - Skills Management Module
#
# 职责：
# - 标准 skills 从 boutique-openclaw-skills 同步
# - 支持 standard 与 boutique low/medium/high 三档，兼容 basic/extended/super
# - 本仓库不再内置 skills 库存或 manifest
#
# CLI 用法：
#   openclaw-setup config skills --tier standard|low|medium|high
#   openclaw-setup config skills --tier basic|extended|super  # compatibility aliases
#   openclaw-setup config skills --list
#   openclaw-setup config skills --force-local  # compatibility: use boutique cache/source only
#===============================================================================

set -euo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Skills 相关路径
OPENCLAW_SKILLS_REPO_URL="${OPENCLAW_SKILLS_REPO_URL:-https://gitee.com/leecyno1/boutique-openclaw-skills.git}"
OPENCLAW_SKILLS_REPO_GITHUB_URL="${OPENCLAW_SKILLS_REPO_GITHUB_URL:-https://github.com/leecyno1/boutique-openclaw-skills.git}"
OPENCLAW_SKILLS_REPO_MIRROR_URL="${OPENCLAW_SKILLS_REPO_MIRROR_URL:-https://mirror.ghproxy.com/https://github.com/leecyno1/boutique-openclaw-skills.git}"
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

normalize_tier() {
    case "${1:-standard}" in
        standard|default|std) echo "standard" ;;
        low|basic) echo "basic" ;;
        medium|extended) echo "extended" ;;
        high|super) echo "super" ;;
        *) echo "$1" ;;
    esac
}

boutique_tier_name() {
    case "$(normalize_tier "${1:-basic}")" in
        basic) echo "low" ;;
        extended) echo "medium" ;;
        super) echo "high" ;;
        *) echo "$1" ;;
    esac
}

get_boutique_skills_repo_urls() {
    cat <<EOF
$OPENCLAW_SKILLS_REPO_URL
$OPENCLAW_SKILLS_REPO_GITHUB_URL
$OPENCLAW_SKILLS_REPO_MIRROR_URL
EOF
}

resolve_skills_source() {
    local candidate cache_root cache_repo tmp_repo url
    for candidate in \
        "${OPENCLAW_SKILLS_BUNDLE_DIR:-}" \
        "$HOME/.openclaw/.cache/boutique-openclaw-skills/skills/default" \
        "$HOME/boutique-openclaw-skills/skills/default" \
        "$REPO_ROOT/../boutique-openclaw-skills/skills/default"; do
        [ -n "$candidate" ] || continue
        if [ -d "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    command -v git >/dev/null 2>&1 || return 1
    cache_root="$HOME/.openclaw/.cache"
    cache_repo="$cache_root/boutique-openclaw-skills"
    mkdir -p "$cache_root" 2>/dev/null || true
    if [ -d "$cache_repo/skills/default" ]; then
        echo "$cache_repo/skills/default"
        return 0
    fi

    tmp_repo="$(mktemp -d "$cache_root/boutique.XXXXXX")"
    for url in $(get_boutique_skills_repo_urls); do
        rm -rf "$tmp_repo" 2>/dev/null || true
        tmp_repo="$(mktemp -d "$cache_root/boutique.XXXXXX")"
        if git clone --depth 1 "$url" "$tmp_repo" >/dev/null 2>&1 && [ -d "$tmp_repo/skills/default" ]; then
            rm -rf "$cache_repo" 2>/dev/null || true
            mv "$tmp_repo" "$cache_repo"
            echo "$cache_repo/skills/default"
            return 0
        fi
    done
    rm -rf "$tmp_repo" 2>/dev/null || true
    return 1
}

get_boutique_tier_skills() {
    local tier="$1"
    local source_dir json_path root_dir boutique_tier
    boutique_tier="$(boutique_tier_name "$tier")"
    source_dir="$(resolve_skills_source 2>/dev/null || true)"
    [ -n "$source_dir" ] || return 1
    root_dir="$(cd "$source_dir/../.." && pwd)"
    json_path="$root_dir/tiers/$boutique_tier.json"
    [ -f "$json_path" ] || return 1
    python3 - "$json_path" <<'PY'
import json, sys
payload=json.load(open(sys.argv[1], encoding='utf-8'))
print(' '.join(item['id'] for item in payload.get('skills', [])))
PY
}

get_boutique_standard_skills() {
    local source_dir json_path root_dir
    source_dir="$(resolve_skills_source 2>/dev/null || true)"
    [ -n "$source_dir" ] || return 1
    root_dir="$(cd "$source_dir/../.." && pwd)"
    json_path="$root_dir/catalog/standard-bundle.json"
    [ -f "$json_path" ] || return 1
    python3 - "$json_path" <<'PY'
import json, sys
payload=json.load(open(sys.argv[1], encoding='utf-8'))
names=[]
for item in payload.get('skills', []):
    if isinstance(item, str):
        names.append(item)
    elif isinstance(item, dict):
        name=item.get('skill') or item.get('id') or item.get('name')
        if name:
            names.append(name)
print(' '.join(names))
PY
}

get_tier_skills() {
    local tier
    local skills=""
    tier="$(normalize_tier "$1")"

    if [ "$tier" = "standard" ]; then
        skills="$(get_boutique_standard_skills 2>/dev/null || echo "")"
        [ -n "$skills" ] && { echo "$skills"; return 0; }
        echo "brainstorming find-skills multi-search-engine url-to-markdown agent-browser github task planning-with-files verification-before-completion skill-creator skill-security-auditor data-analyst minimax-docx minimax-xlsx pptx-generator nano-pdf generative-ui fullstack-dev mcp-builder media-downloader gemini-image-service news-radar finance-data content-strategy writing-skills proactive-agent model-usage weather"
        return 0
    fi

    skills="$(get_boutique_tier_skills "$tier" 2>/dev/null || echo "")"
    [ -n "$skills" ] && { echo "$skills"; return 0; }

    # 如果 boutique tier 获取失败，使用内置兼容列表兜底
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

install_skills_from_boutique() {
    local tier="${1:-standard}"

    tier="$(normalize_tier "$tier")"
    log_info "Installing $tier skills from boutique repository..."

    ensure_dir "$SKILLS_INSTALL_TARGET"

    local selected_skills
    selected_skills="$(get_tier_skills "$tier")"

    local installed=0
    local skipped=0

    for skill in $selected_skills; do
        local source_root source_dir
        source_root="$(resolve_skills_source 2>/dev/null || true)"
        if [ -z "$source_root" ]; then
            log_warn "  Cannot resolve boutique skills source"
            return 1
        fi
        source_dir="$source_root/$skill"

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
            log_warn "  Missing: $skill (not found in boutique repository/cache)"
        fi
    done

    log_success "$tier skills: $installed installed, $skipped skipped"
}

#===============================================================================
# 验证安装
#===============================================================================

verify_installation() {
    local tier="${1:-standard}"

    log_info "Verifying skills installation..."

    local expected_skills
    expected_skills="$(get_tier_skills "$tier")"

    local installed_count
    installed_count="$(count_skills "$SKILLS_INSTALL_TARGET")"
    ((installed_count--))  # 减去 . 目录本身

    log_info "Installed: $installed_count skills"
    log_info "Target tier: $tier"

    # 检查关键 skills
    local critical_skills="skill-creator verification-before-completion writing-skills"
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

    # Boutique 可用的 skills
    local available_source
    available_source="$(resolve_skills_source 2>/dev/null || true)"
    echo "Available in boutique repository/cache ($(count_skills "$available_source") skills):"
    if [ -d "$available_source" ]; then
        find "$available_source" -maxdepth 1 -type d -not -name ".git*" | \
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
    local tier="standard"
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
            --force-local)
                :
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

    tier="$(normalize_tier "$tier")"

    case "$tier" in
        standard|basic|extended|super) ;;
        *)
            log_error "Invalid tier: $tier"
            echo "Valid tiers: standard, low, medium, high, basic, extended, super"
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

    install_skills_from_boutique "$tier"

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
  --tier, -t <tier>     Installation tier: standard, low, medium, high (aliases: basic, extended, super)
  --force-local          Compatibility flag; use boutique repository/cache only
  --list, -l             List installed and available skills
  --force-update, -f     Force update already installed skills
  --help, -h             Show this help message

Tiers:
  standard         default standard bundle from boutique catalog
  low/basic        low tier skills
  medium/extended  low + production extensions
  high/super       medium + curated expert skills

Examples:
  # Install standard skills
  openclaw-setup config skills

  # Install medium skills
  openclaw-setup config skills --tier medium

  # Force boutique cache/source installation
  openclaw-setup config skills --force-local

  # List all skills
  openclaw-setup config skills --list

EOF
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
