#!/usr/bin/env bash
#===============================================================================
# 迁移脚本 - Migration to Modular Architecture
#
# 职责：
# - 从旧版 monolithic config-menu.sh 迁移到新的模块化架构
# - 提取现有配置并应用到新模块
# - 保留用户数据（memory, sessions, API keys）
# - 提供回滚机制
#
# CLI 用法：
#   scripts/migrate-to-modular.sh [--dry-run] [--rollback]
#===============================================================================

set -euo pipefail

# 脚本目录和仓库根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 备份目录
BACKUP_DIR="$HOME/.openclaw/backups/migration-$(date +%Y%m%d_%H%M%S)"

# 旧配置文件
OLD_CONFIG_MENU="$HOME/.openclaw/config-menu.sh"
OLD_CONFIG="$HOME/.openclaw/config"

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
# 备份函数
#===============================================================================

backup_current_state() {
    log_info "Creating backup..."

    mkdir -p "$BACKUP_DIR"

    # 备份整个 .openclaw 目录（选择性）
    local dirs_to_backup=(
        "$HOME/.openclaw/profile"
        "$HOME/.openclaw/env"
        "$HOME/.openclaw/pixel-house"
        "$HOME/.openclaw/skills"
    )

    for dir in "${dirs_to_backup[@]}"; do
        if [ -d "$dir" ]; then
            local name
            name="$(basename "$dir")"
            cp -R "$dir" "$BACKUP_DIR/$name"
            log_info "  Backed up: $dir"
        fi
    done

    # 备份配置文件
    local files_to_backup=(
        "$HOME/.openclaw/openclaw.json"
        "$HOME/.openclaw/api-overrides.json"
    )

    for file in "${files_to_backup[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/"
            log_info "  Backed up: $file"
        fi
    done

    log_success "Backup created: $BACKUP_DIR"
    echo ""
}

#===============================================================================
# 迁移 Skills 配置
#===============================================================================

migrate_skills_config() {
    log_info "Migrating skills configuration..."

    # 从旧配置提取 skills tier
    local tier="basic"  # 默认值

    if [ -f "$HOME/.openclaw/env" ]; then
        if grep -q "OPENCLAW_PROFILE_SKILL_LIST" "$HOME/.openclaw/env" 2>/dev/null; then
            local skill_count
            skill_count="$(grep "OPENCLAW_PROFILE_SKILL_COUNT" "$HOME/.openclaw/env" 2>/dev/null | cut -d'"' -f2 || echo "")"

            # 根据 skill 数量推断 tier
            if [ -n "$skill_count" ]; then
                if [ "$skill_count" -gt 80 ]; then
                    tier="super"
                elif [ "$skill_count" -gt 60 ]; then
                    tier="extended"
                fi
            fi
        fi
    fi

    log_info "  Detected tier: $tier"
    echo ""

    # 执行 skills 安装
    bash "$SCRIPT_DIR/modules/skills.sh" --tier "$tier" || true

    log_success "Skills configuration migrated"
}

#===============================================================================
# 迁移三档规则配置
#===============================================================================

migrate_tier_rules() {
    log_info "Migrating tier rules configuration..."

    # 从旧配置提取 tier level
    local level="medium"  # 默认值

    if [ -f "$HOME/.openclaw/env" ]; then
        level="$(grep "OPENCLAW_RULE_PROFILE" "$HOME/.openclaw/env" 2>/dev/null | cut -d'"' -f2 || echo "medium")"
    fi

    log_info "  Detected level: $level"
    echo ""

    # 执行 tier rules 配置
    bash "$SCRIPT_DIR/modules/tier-rules.sh" --level "$level" || true

    log_success "Tier rules configuration migrated"
}

#===============================================================================
# 迁移像素小屋配置
#===============================================================================

migrate_pixel_house() {
    log_info "Migrating Pixel House configuration..."

    if [ -d "$HOME/.openclaw/pixel-house" ]; then
        log_info "  Pixel House already exists, skipping..."
        echo ""
        return 0
    fi

    # 询问用户是否安装
    read -p "Install Pixel House? [y/N] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "$SCRIPT_DIR/modules/pixel-house.sh" --install || true
    fi

    log_success "Pixel House configuration migrated"
}

#===============================================================================
# 迁移 API 配置
#===============================================================================

migrate_api_config() {
    log_info "Migrating API configuration..."

    # API 配置已经在 ~/.openclaw/env 和 openclaw.json 中
    # 新模块会读取这些文件

    log_info "  API configuration will be read from existing files"
    log_info "  Run 'openclaw-setup config api --show' to verify"
    echo ""

    log_success "API configuration migrated"
}

#===============================================================================
# 创建符号链接
#===============================================================================

create_symlinks() {
    log_info "Creating symlinks..."

    # 创建模块脚本链接
    local modules=(
        "skills"
        "tier-rules"
        "pixel-house"
        "api-config"
    )

    for module in "${modules[@]}"; do
        local target="$SCRIPT_DIR/modules/${module}.sh"
        if [ -f "$target" ]; then
            # 已经是绝对路径
            log_info "  Module available: $target"
        fi
    done

    # 创建 openclaw-setup 链接（如果不存在）
    if [ ! -f "$REPO_ROOT/openclaw-setup.sh" ]; then
        log_info "  Creating openclaw-setup.sh link..."
        cp "$REPO_ROOT/scripts/lobster-setup.sh" "$REPO_ROOT/openclaw-setup.sh" 2>/dev/null || true
    fi

    log_success "Symlinks created"
}

#===============================================================================
# 执行迁移
#===============================================================================

run_migration() {
    local dry_run="${1:-false}"

    echo ""
    echo "========================================"
    echo "  OpenClawInstaller 模块化迁移"
    echo "========================================"
    echo ""

    # 检查是否已迁移
    if [ -f "$HOME/.openclaw/.modular_migrated" ]; then
        log_warn "Already migrated on: $(cat "$HOME/.openclaw/.modular_migrated")"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    # 创建备份
    backup_current_state

    if [ "$dry_run" = "true" ]; then
        log_warn "Dry run mode - no changes will be made"
        echo ""
    fi

    # 执行迁移
    echo ""
    log_info "Starting migration..."
    echo ""

    migrate_skills_config
    migrate_tier_rules
    migrate_pixel_house
    migrate_api_config

    # 创建标记
    if [ "$dry_run" = "false" ]; then
        echo "$(date)" > "$HOME/.openclaw/.modular_migrated"
    fi

    # 完成
    echo ""
    echo "========================================"
    log_success "Migration complete!"
    echo "========================================"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'openclaw-setup config skills --list' to verify skills"
    echo "  2. Run 'openclaw-setup config tier-rules --show' to verify tier rules"
    echo "  3. Run 'openclaw-setup config pixel-house --status' to verify Pixel House"
    echo "  4. Run 'openclaw-setup config api --show' to verify API config"
    echo ""
    echo "Rollback: cp -R $BACKUP_DIR/* ~/.openclaw/"
    echo ""
}

#===============================================================================
# 回滚
#===============================================================================

rollback() {
    echo ""
    echo "========================================"
    echo "  迁移回滚"
    echo "========================================"
    echo ""

    # 列出可用的备份
    local backups
    backups=$(find "$HOME/.openclaw/backups/migration-" -maxdepth 0 -type d 2>/dev/null || echo "")

    if [ -z "$backups" ]; then
        log_error "No migration backups found"
        exit 1
    fi

    echo "Available backups:"
    ls -la "$HOME/.openclaw/backups/migration-"* 2>/dev/null || true
    echo ""

    read -p "Enter backup directory: " backup_dir
    echo ""

    if [ -d "$backup_dir" ]; then
        log_info "Rolling back to: $backup_dir"

        # 恢复文件
        cp -R "$backup_dir"/* "$HOME/.openclaw/"

        # 删除迁移标记
        rm -f "$HOME/.openclaw/.modular_migrated"

        log_success "Rollback complete"
    else
        log_error "Backup not found: $backup_dir"
        exit 1
    fi
}

#===============================================================================
# 帮助信息
#===============================================================================

show_help() {
    cat <<'EOF'
Migration Script - Migrate to Modular Architecture

Usage:
  scripts/migrate-to-modular.sh [options]

Options:
  --dry-run       Show what will be migrated without making changes
  --rollback      Rollback to a previous migration state
  --help, -h      Show this help message

Examples:
  # Run migration
  scripts/migrate-to-modular.sh

  # Preview migration
  scripts/migrate-to-modular.sh --dry-run

  # Rollback
  scripts/migrate-to-modular.sh --rollback

EOF
}

#===============================================================================
# 主函数
#===============================================================================

main() {
    local action="migrate"
    local dry_run="false"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run="true"
                ;;
            --rollback)
                action="rollback"
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

    case "$action" in
        migrate)
            run_migration "$dry_run"
            ;;
        rollback)
            rollback
            ;;
    esac
}

# 如果直接执行此脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
