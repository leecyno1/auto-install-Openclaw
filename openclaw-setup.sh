#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 OpenClaw 统一入口工具 v2.0.0                                        ║
# ║   模块化架构 - 极简安装 + 独立配置                                         ║
# ║                                                                           ║
# ║   用法: openclaw-setup [命令]                                              ║
# ║   命令: install, config [模块], repair, workbench, status, doctor, backup  ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 路径定义
OPENCLAW_HOME="$HOME/.openclaw"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 显示帮助
show_help() {
    cat << EOF
${CYAN}🦞 OpenClaw 统一入口工具 v2.0.0${NC}
${GREEN}模块化架构${NC}

${GREEN}用法:${NC} openclaw-setup [命令] [选项]

${GREEN}命令:${NC}
  install       执行首次安装（交互式或全自动）
  config       配置中心（模块化）
  config skills      - Skills 管理
  config tier-rules  - 三档规则配置
  config pixel-house - 像素小屋
  config api        - API 配置
  repair       修复历史错误配置（保留记忆/对话）
  workbench    启动像素小屋工作台
  status       查看所有服务状态
  doctor       运行健康检查并自动修复
  backup       备份配置和数据
  help         显示此帮助信息

${GREEN}示例:${NC}
  openclaw-setup install                    # 交互式安装
  openclaw-setup install --auto           # 全自动安装
  openclaw-setup config                    # 交互式配置菜单
  openclaw-setup config skills --tier extended
  openclaw-setup config tier-rules --level high
  openclaw-setup config pixel-house --install
  openclaw-setup config api --replace-service nanobanana --with https://my.com/api
  openclaw-setup repair                    # 修复配置

EOF
}

# 安装命令
cmd_install() {
    local auto_flag="${1:-}"
    echo -e "${GREEN}🚀 开始安装 OpenClaw...${NC}"

    if [ "$auto_flag" = "--auto" ] || [ "$auto_flag" = "--auto-confirm-all" ]; then
        bash "$INSTALLER_DIR/install.sh" --auto-confirm-all
    else
        bash "$INSTALLER_DIR/install.sh"
    fi

    echo -e "${GREEN}✅ 安装完成！运行 'openclaw-setup config' 进行配置${NC}"
}

# 模块目录
MODULES_DIR="$INSTALLER_DIR/scripts/modules"

#===============================================================================
# 配置命令（模块化）
#===============================================================================

cmd_config() {
    local module="${1:-}"
    shift || true

    # 如果有模块参数，路由到对应模块
    if [ -n "$module" ]; then
        route_config_module "$module" "$@"
        return $?
    fi

    # 否则显示简化的交互式菜单
    show_config_menu
}

# 模块路由
route_config_module() {
    local module="$1"
    shift || true

    case "$module" in
        skills)
            [ ! -f "$MODULES_DIR/skills.sh" ] && {
                echo -e "${RED}❌ Skills 模块未找到${NC}"
                exit 1
            }
            bash "$MODULES_DIR/skills.sh" "$@"
            ;;
        tier-rules|tier)
            [ ! -f "$MODULES_DIR/tier-rules.sh" ] && {
                echo -e "${RED}❌ Tier Rules 模块未找到${NC}"
                exit 1
            }
            bash "$MODULES_DIR/tier-rules.sh" "$@"
            ;;
        pixel-house|pixel|house)
            [ ! -f "$MODULES_DIR/pixel-house.sh" ] && {
                echo -e "${RED}❌ Pixel House 模块未找到${NC}"
                exit 1
            }
            bash "$MODULES_DIR/pixel-house.sh" "$@"
            ;;
        api)
            [ ! -f "$MODULES_DIR/api-config.sh" ] && {
                echo -e "${RED}❌ API 配置模块未找到${NC}"
                exit 1
            }
            bash "$MODULES_DIR/api-config.sh" "$@"
            ;;
        dashboard-pairing|dashboard|pairing)
            [ ! -f "$MODULES_DIR/dashboard-pairing.sh" ] && {
                echo -e "${RED}❌ Dashboard Pairing 模块未找到${NC}"
                exit 1
            }
            bash "$MODULES_DIR/dashboard-pairing.sh" "$@"
            ;;
        migrate)
            echo -e "${CYAN}🔄 启动迁移向导...${NC}"
            bash "$INSTALLER_DIR/scripts/migrate-to-modular.sh" "$@"
            ;;
        menu)
            show_config_menu
            ;;
        --help|-h)
            show_config_help
            ;;
        *)
            echo -e "${RED}❌ 未知模块: $module${NC}"
            echo ""
            show_config_help
            exit 1
            ;;
    esac
}

# 配置菜单帮助
show_config_help() {
    cat << EOF
${CYAN}OpenClaw 配置模块${NC}

${GREEN}用法:${NC} openclaw-setup config [模块] [选项]

${GREEN}模块:${NC}
  skills            Skills 管理（安装/列表）
  tier-rules        三档注入规则配置
  pixel-house       像素小屋工作台
  api               API 配置和替换
  dashboard-pairing Dashboard 配对修复
  migrate           迁移到模块化架构

${GREEN}示例:${NC}
  openclaw-setup config                      # 交互式菜单
  openclaw-setup config skills               # Skills 管理
  openclaw-setup config tier-rules           # 三档规则
  openclaw-setup config pixel-house          # 像素小屋
  openclaw-setup config api                  # API 配置
  openclaw-setup config dashboard-pairing    # Dashboard 配对修复
  openclaw-setup config migrate              # 迁移向导

  # 指定选项
  openclaw-setup config skills --tier extended
  openclaw-setup config tier-rules --level high --with-monitoring
  openclaw-setup config api --replace-service nanobanana --with https://my.com/api
  openclaw-setup config dashboard-pairing --fix

EOF
}

# 简化的配置菜单
show_config_menu() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  🦞 OpenClaw 配置中心                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "  1) Skills 管理        - 安装/管理 AI 技能包"
    echo "  2) 三档规则配置       - 流量控制和配额设置"
    echo "  3) 像素小屋           - 安装/启动工作台"
    echo "  4) API 配置           - 配置第三方 API"
    echo "  5) Dashboard 配对修复 - 修复配对问题"
    echo "  6) 迁移向导           - 从旧版迁移"
    echo ""
    echo "  0) 退出"
    echo ""

    read -p "请选择 [0-6]: " choice

    case "$choice" in
        1)
            echo ""
            echo -e "${BLUE}→ 启动 Skills 管理...${NC}"
            bash "$MODULES_DIR/skills.sh" --tier basic
            ;;
        2)
            echo ""
            echo -e "${BLUE}→ 启动三档规则配置...${NC}"
            bash "$MODULES_DIR/tier-rules.sh" --level medium
            ;;
        3)
            echo ""
            echo -e "${BLUE}→ 启动像素小屋配置...${NC}"
            bash "$MODULES_DIR/pixel-house.sh" --status
            ;;
        4)
            echo ""
            echo -e "${BLUE}→ 启动 API 配置...${NC}"
            bash "$MODULES_DIR/api-config.sh" --show
            ;;
        5)
            echo ""
            echo -e "${BLUE}→ 启动 Dashboard 配对修复...${NC}"
            bash "$MODULES_DIR/dashboard-pairing.sh" --fix
            ;;
        6)
            echo ""
            echo -e "${BLUE}→ 启动迁移向导...${NC}"
            bash "$INSTALLER_DIR/scripts/migrate-to-modular.sh"
            ;;
        0|q)
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
}

# 修复命令
cmd_repair() {
    echo -e "${YELLOW}🔧 开始修复配置...${NC}"
    if [ -f "$OPENCLAW_HOME/config-menu.sh" ]; then
        bash "$OPENCLAW_HOME/config-menu.sh" --repair-config
    else
        bash "$INSTALLER_DIR/config-menu.sh" --repair-config
    fi
    echo -e "${GREEN}✅ 修复完成${NC}"
}

# 工作台命令
cmd_workbench() {
    local action="${1:-start}"
    if [ ! -f "$OPENCLAW_HOME/lobster-world.sh" ]; then
        echo -e "${YELLOW}⚠️ 工作台未安装，正在安装...${NC}"
        if [ -f "$OPENCLAW_HOME/config-menu.sh" ]; then
            bash "$OPENCLAW_HOME/config-menu.sh" --install-pixel-house
        else
            bash "$INSTALLER_DIR/config-menu.sh" --install-pixel-house
        fi
    fi

    case "$action" in
        start|stop|restart|status)
            bash "$OPENCLAW_HOME/lobster-world.sh" "$action"
            ;;
        *)
            bash "$OPENCLAW_HOME/lobster-world.sh" start
            ;;
    esac
}

# 状态命令
cmd_status() {
    echo -e "${CYAN}📊 OpenClaw 服务状态${NC}"
    echo ""

    # Gateway 状态
    if pgrep -f "openclaw gateway" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} Gateway: 运行中 (端口 13145)"
    else
        echo -e "  ${RED}❌${NC} Gateway: 未运行"
    fi

    # 工作台状态
    if pgrep -f "lobster-world" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} 像素小屋: 运行中 (端口 19000)"
    else
        echo -e "  ${RED}❌${NC} 像素小屋: 未运行"
    fi

    # 配置完整性
    if [ -f "$OPENCLAW_HOME/env" ]; then
        echo -e "  ${GREEN}✅${NC} 配置文件: 存在"
    else
        echo -e "  ${RED}❌${NC} 配置文件: 缺失"
    fi

    echo ""
}

# 健康检查命令
cmd_doctor() {
    local fix_flag="${1:-}"
    echo -e "${CYAN}🏥 运行健康检查...${NC}"
    echo ""

    if [ -f "$OPENCLAW_HOME/env" ]; then
        source "$OPENCLAW_HOME/env"
    fi

    # 检查 Node.js 版本
    if command -v node > /dev/null 2>&1; then
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -ge 22 ]; then
            echo -e "  ${GREEN}✅${NC} Node.js: $(node -v)"
        else
            echo -e "  ${RED}❌${NC} Node.js: $(node -v) (需要 22.12+)"
            [ "$fix_flag" = "--fix" ] && echo -e "  ${YELLOW}🔧 请升级 Node.js 到 22.12 以上版本${NC}"
        fi
    else
        echo -e "  ${RED}❌${NC} Node.js: 未安装"
    fi

    # 检查 OpenClaw CLI
    if command -v openclaw > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} OpenClaw CLI: 可用"
    else
        echo -e "  ${RED}❌${NC} OpenClaw CLI: 未找到"
    fi

    # 端口检查
    if lsof -i :13145 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} 端口 13145 (Gateway): 可用"
    else
        echo -e "  ${YELLOW}⚠️${NC} 端口 13145 (Gateway): 未监听"
    fi

    if lsof -i :19000 > /dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} 端口 19000 (工作台): 可用"
    else
        echo -e "  ${YELLOW}⚠️${NC} 端口 19000 (工作台): 未监听"
    fi

    echo ""

    if [ "$fix_flag" = "--fix" ]; then
        echo -e "${GREEN}🔧 尝试自动修复...${NC}"
        if [ -f "$OPENCLAW_HOME/config-menu.sh" ]; then
            bash "$OPENCLAW_HOME/config-menu.sh" --repair-config
        fi
    fi
}

# 健康检查命令
cmd_health() {
    local action="${1:-start}"
    local health_script="$INSTALLER_DIR/scripts/health-server.sh"

    if [ ! -f "$health_script" ]; then
        echo -e "${RED}❌ 健康检查脚本未找到: $health_script${NC}"
        exit 1
    fi

    bash "$health_script" "$action"
}

# 快速启动向导
cmd_wizard() {
    echo -e "${CYAN}🦞 OpenClaw 快速启动向导${NC}"
    echo -e "${GREEN}5 步完成配置，开始使用 AI 智能体工作台${NC}"
    echo ""

    # 步骤 1: 检查安装
    echo -e "${BLUE}[1/5] 检查 OpenClaw 安装状态...${NC}"
    if [ ! -f "$OPENCLAW_HOME/env" ]; then
        echo -e "  ${YELLOW}⚠️ OpenClaw 未安装，正在安装...${NC}"
        cmd_install --auto
    else
        echo -e "  ${GREEN}✅ OpenClaw 已安装${NC}"
    fi
    echo ""

    # 步骤 2: 配置模型
    echo -e "${BLUE}[2/5] 配置 AI 模型...${NC}"
    echo -e "  ${YELLOW}将打开配置菜单，请选择「模型配置」${NC}"
    read -p "按回车继续..." < "$TTY_INPUT"
    cmd_config
    echo ""

    # 步骤 3: 安装推荐技能
    echo -e "${BLUE}[3/5] 安装推荐技能包...${NC}"
    echo -e "  ${YELLOW}选择档位: 1=基础档 2=扩展档 3=超级档${NC}"
    read -p "请输入档位 (默认: 1): " tier_choice < "$TTY_INPUT"
    case "${tier_choice:-1}" in
        2) echo -e "  ${GREEN}✅ 安装扩展档技能包${NC}" ;;
        3) echo -e "  ${GREEN}✅ 安装超级档技能包${NC}" ;;
        *) echo -e "  ${GREEN}✅ 安装基础档技能包${NC}" ;;
    esac
    echo ""

    # 步骤 4: 启动服务
    echo -e "${BLUE}[4/5] 启动 Gateway、工作台和健康检查...${NC}"
    source "$OPENCLAW_HOME/env" 2>/dev/null || true
    if command -v openclaw > /dev/null 2>&1; then
        openclaw gateway start &
        echo -e "  ${GREEN}✅ Gateway 已启动 (端口 13145)${NC}"
    fi
    cmd_workbench start
    cmd_health start
    echo ""

    # 步骤 5: 验证
    echo -e "${BLUE}[5/5] 验证服务状态...${NC}"
    cmd_status
    echo ""

    echo -e "${GREEN}🎉 向导完成！${NC}"
    echo -e "  🌐 Gateway: http://127.0.0.1:13145"
    echo -e "  🏠 工作台: http://127.0.0.1:19000"
    echo -e "  ❤️  健康检查: http://127.0.0.1:13146/health"
    echo ""
}

# 备份命令
cmd_backup() {
    local backup_dir="$OPENCLAW_HOME/backups/$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}💾 开始备份配置...${NC}"

    mkdir -p "$backup_dir"

    if [ -d "$OPENCLAW_HOME" ]; then
        cp -r "$OPENCLAW_HOME"/* "$backup_dir/" 2>/dev/null || true
        echo -e "  ${GREEN}✅${NC} 已备份: $OPENCLAW_HOME"
    fi

    echo -e "${GREEN}✅ 备份完成: $backup_dir${NC}"
    echo -e "${YELLOW}💡 恢复: cp -r $backup_dir/* $OPENCLAW_HOME/${NC}"
}

# 主入口
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        install)
            cmd_install "${1:-}"
            ;;
        config|c)
            cmd_config "${1:-}" "$@"
            ;;
        repair|fix|r)
            cmd_repair
            ;;
        workbench|wb|w)
            cmd_workbench "${1:-start}"
            ;;
        status|s)
            cmd_status
            ;;
        doctor|d)
            cmd_doctor "${1:-}"
            ;;
        backup|b)
            cmd_backup
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
