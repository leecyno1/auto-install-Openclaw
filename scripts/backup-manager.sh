#!/bin/bash
#
# OpenClaw 备份管理器
# 支持定时自动备份、备份列表、一键恢复
#

set -euo pipefail

OPENCLAW_HOME="$HOME/.openclaw"
BACKUP_BASE="$OPENCLAW_HOME/backups"
CONFIG_DIR="$OPENCLAW_HOME"
BACKUP_MANAGER_SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

compute_dir_size_bytes() {
    local target_dir="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$target_dir" <<'PY'
import os
import sys

total = 0
for root, _, files in os.walk(sys.argv[1]):
    for name in files:
        path = os.path.join(root, name)
        try:
            total += os.path.getsize(path)
        except OSError:
            pass
print(total)
PY
        return 0
    fi

    du -sk "$target_dir" 2>/dev/null | awk '{print $1 * 1024}'
}

# 创建备份
create_backup() {
    local backup_name="${1:-$(date +%Y%m%d_%H%M%S)}"
    local backup_dir="$BACKUP_BASE/$backup_name"
    local item_name item_path
    local size_bytes file_count

    mkdir -p "$backup_dir"

    echo -e "${BLUE}💾 开始备份配置...${NC}"

    # 备份核心配置
    if [ -d "$CONFIG_DIR" ]; then
        while IFS= read -r item_path; do
            item_name="$(basename "$item_path")"
            cp -R "$item_path" "$backup_dir/$item_name" 2>/dev/null || true
        done < <(
            find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 \
                ! -name "$(basename "$BACKUP_BASE")" \
                -print
        )
        echo -e "  ${GREEN}✅${NC} 已备份: $CONFIG_DIR"
    fi

    # 备份环境变量（脱敏）
    if [ -f "$CONFIG_DIR/env" ]; then
        # 创建脱敏版本，隐藏 API key
        sed 's/\(API_KEY.*\)=.*/\1=***REDACTED***/' "$CONFIG_DIR/env" > "$backup_dir/env.redacted"
        cp "$CONFIG_DIR/env" "$backup_dir/env.original"
        echo -e "  ${GREEN}✅${NC} 已备份环境变量（含原始和脱敏）"
    fi

    # 记录元数据
    cat > "$backup_dir/backup.json" << EOF
{
    "name": "$backup_name",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "openclaw_version": "$(openclaw --version 2>/dev/null || echo 'unknown')",
    "size_bytes": 0,
    "files": 0
}
EOF

    size_bytes="$(compute_dir_size_bytes "$backup_dir")"
    file_count="$(find "$backup_dir" -type f | wc -l | tr -d ' ')"

    cat > "$backup_dir/backup.json" << EOF
{
    "name": "$backup_name",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "openclaw_version": "$(openclaw --version 2>/dev/null || echo 'unknown')",
    "size_bytes": ${size_bytes:-0},
    "files": ${file_count:-0}
}
EOF

    echo -e "${GREEN}✅ 备份完成: $backup_dir${NC}"
    echo ""
    echo -e "${YELLOW}📋 备份信息:${NC}"
    cat "$backup_dir/backup.json" | python3 -m json.tool 2>/dev/null || cat "$backup_dir/backup.json"
}

# 列出所有备份
list_backups() {
    echo -e "${BLUE}📋 可用备份列表:${NC}"
    echo ""

    if [ ! -d "$BACKUP_BASE" ]; then
        echo -e "  ${RED}❌ 暂无备份${NC}"
        return 1
    fi

    local count=0
    for backup in "$BACKUP_BASE"/*; do
        if [ -d "$backup" ]; then
            local name=$(basename "$backup")
            local size=$(du -sh "$backup" | cut -f1)
            local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup" 2>/dev/null || date -r "$backup" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
            echo -e "  ${GREEN}📁${NC} $name"
            echo -e "      大小: $size | 时间: $date"
            count=$((count + 1))
        fi
    done

    if [ $count -eq 0 ]; then
        echo -e "  ${RED}❌ 暂无备份${NC}"
    else
        echo ""
        echo -e "${GREEN}共 $count 个备份${NC}"
    fi
}

# 恢复备份
restore_backup() {
    local backup_name="$1"
    local backup_dir="$BACKUP_BASE/$backup_name"
    local item_name item_path

    if [ ! -d "$backup_dir" ]; then
        echo -e "${RED}❌ 备份不存在: $backup_name${NC}"
        list_backups
        return 1
    fi

    echo -e "${YELLOW}⚠️ 警告: 恢复将覆盖当前配置${NC}"
    read -p "确认恢复? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${RED}已取消${NC}"
        return 0
    fi

    # 备份当前配置（作为回滚点）
    local rollback_name="pre_restore_$(date +%Y%m%d_%H%M%S)"
    echo -e "${BLUE}创建回滚点: $rollback_name${NC}"
    create_backup "$rollback_name" > /dev/null 2>&1

    # 恢复配置
    echo -e "${BLUE}🔄 恢复配置...${NC}"
    while IFS= read -r item_path; do
        item_name="$(basename "$item_path")"
        if [ -d "$item_path" ]; then
            mkdir -p "$CONFIG_DIR/$item_name"
            cp -R "$item_path"/. "$CONFIG_DIR/$item_name/" 2>/dev/null || true
        else
            cp -f "$item_path" "$CONFIG_DIR/$item_name" 2>/dev/null || true
        fi
    done < <(
        find "$backup_dir" -mindepth 1 -maxdepth 1 \
            ! -name "backup.json" \
            ! -name "env.redacted" \
            ! -name "env.original" \
            -print
    )

    echo -e "${GREEN}✅ 恢复完成${NC}"
    echo -e "${YELLOW}💡 如出现问题，可使用回滚点: lobster-setup backup restore $rollback_name${NC}"
}

# 设置定时备份（cron）
setup_cron_backup() {
    local schedule="${1:-0 2 * * *}"  # 默认每天凌晨2点
    local cron_cmd="$BACKUP_MANAGER_SELF create --auto >> /tmp/openclaw-backup.log 2>&1"

    echo -e "${BLUE}⏰ 设置定时备份...${NC}"
    echo -e "  调度规则: $schedule"

    # 检查是否已存在
    if crontab -l 2>/dev/null | grep -q "backup-manager.sh"; then
        echo -e "  ${YELLOW}⚠️ 定时备份已存在，正在覆盖...${NC}"
        crontab -l 2>/dev/null | grep -v "backup-manager.sh" | crontab -
    fi

    # 添加新任务
    (crontab -l 2>/dev/null; echo "$schedule $cron_cmd") | crontab -

    echo -e "${GREEN}✅ 定时备份已设置${NC}"
    echo -e "  日志: /tmp/openclaw-backup.log"
}

# 移除定时备份
remove_cron_backup() {
    echo -e "${BLUE}🗑️ 移除定时备份...${NC}"

    if crontab -l 2>/dev/null | grep -q "backup-manager.sh"; then
        crontab -l 2>/dev/null | grep -v "backup-manager.sh" | crontab -
        echo -e "${GREEN}✅ 定时备份已移除${NC}"
    else
        echo -e "${YELLOW}⚠️ 未找到定时备份任务${NC}"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
OpenClaw 备份管理器

用法: backup-manager.sh [命令] [选项]

命令:
  create [name]           创建备份（可选指定名称）
  list                    列出所有备份
  restore <name>          恢复指定备份
  cron setup [schedule]   设置定时备份（默认: 0 2 * * *）
  cron remove             移除定时备份
  help                    显示帮助

示例:
  backup-manager.sh create                    # 创建自动命名的备份
  backup-manager.sh create pre-upgrade        # 创建名为 pre-upgrade 的备份
  backup-manager.sh list                      # 查看所有备份
  backup-manager.sh restore 20240101_120000   # 恢复指定备份
  backup-manager.sh cron setup "0 */6 * * *"  # 每6小时备份一次

EOF
}

# 主入口
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        create)
            if [ "${1:-}" = "--auto" ]; then
                create_backup ""
            else
                create_backup "${1:-}"
            fi
            ;;
        list)
            list_backups
            ;;
        restore)
            restore_backup "${1:-}"
            ;;
        cron)
            case "${1:-}" in
                setup)
                    setup_cron_backup "${2:-0 2 * * *}"
                    ;;
                remove)
                    remove_cron_backup
                    ;;
                *)
                    echo -e "${RED}未知子命令: ${1:-}${NC}"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}未知命令: $cmd${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
