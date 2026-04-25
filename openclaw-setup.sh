#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║   🦞 OpenClaw 统一入口工具 v2.0.0                                 ║
# ║   开箱即用的 AI 智能体工作台管理                                   ║
# ╚══════════════════════════════════════════════════════════════════╝
#

set -euo pipefail

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_LIB="$SCRIPT_DIR/scripts/lib/openclaw-custom.sh"
[ -f "$CUSTOM_LIB" ] && source "$CUSTOM_LIB"

CONFIG_DIR="$HOME/.openclaw"

# ================================ 帮助 ================================
show_help() {
    cat << EOF
${CYAN}🦞 OpenClaw 统一入口工具${NC}

${GREEN}用法:${NC} openclaw-setup [命令] [选项]

${GREEN}安装与配置:${NC}
  install [选项]     执行安装（交互式或全自动）
  config             打开配置中心菜单
  repair             修复历史错误配置
  doctor [选项]      运行健康检查并自动修复

${GREEN}服务管理:${NC}
  workbench [操作]   管理像素小屋工作台 (start/stop/restart/status)
  status             查看所有服务状态
  gateway [操作]     管理 Gateway (start/stop/restart/status)

${GREEN}工具:${NC}
  persona            设置/切换工作档案
  skills [档位]      同步技能包 (low/medium/high)
  backup             备份配置和数据
  help               显示此帮助

${GREEN}安装选项:${NC}
  --auto, --auto-confirm-all   全自动安装（批量部署）
  --no-custom                  仅安装官方版本，跳过自定义层
  --persona <role>             指定工作档案
  --rule-profile <level>       指定 Token 档位

${GREEN}doctor 选项:${NC}
  --fix              自动修复发现的问题
  --status           仅显示状态，不修复

${GREEN}示例:${NC}
  openclaw-setup install                    # 交互式安装
  openclaw-setup install --auto             # 全自动安装
  openclaw-setup install --no-custom        # 仅安装官方版本
  openclaw-setup install --persona warrior  # 安装 + 设置工程档案
  openclaw-setup config                     # 打开配置菜单
  openclaw-setup doctor --fix               # 自动修复
  openclaw-setup workbench start            # 启动工作台
  openclaw-setup skills medium              # 同步扩展档技能
EOF
}

# ================================ 命令实现 ================================

cmd_install() {
    local install_args=()
    for arg in "$@"; do
        case "$arg" in
            --auto|--auto-confirm-all) install_args+=(--auto-confirm-all) ;;
            --no-custom)               install_args+=(--no-custom) ;;
            --persona|--rule-profile|--version|--gateway-bind|--gateway-port)
                install_args+=("$arg" "${2:-}"); shift ;;
            *) install_args+=("$arg") ;;
        esac
    done

    echo -e "${GREEN}🚀 开始安装 OpenClaw...${NC}"
    bash "$SCRIPT_DIR/install.sh" "${install_args[@]}"
}

cmd_config() {
    if [ ! -f "$CONFIG_DIR/config-menu.sh" ]; then
        bash "$SCRIPT_DIR/config-menu.sh"
    else
        bash "$CONFIG_DIR/config-menu.sh"
    fi
}

cmd_repair() {
    echo -e "${YELLOW}🔧 开始修复配置...${NC}"
    if [ -f "$CONFIG_DIR/config-menu.sh" ]; then
        bash "$CONFIG_DIR/config-menu.sh" --repair-config
    else
        bash "$SCRIPT_DIR/config-menu.sh" --repair-config
    fi
}

cmd_doctor() {
    local fix=false status_only=false
    for arg in "$@"; do
        case "$arg" in --fix) fix=true ;; --status) status_only=true ;; esac
    done

    echo -e "${CYAN}🏥 OpenClaw 健康检查${NC}"
    echo ""

    # Node.js
    if command -v node &>/dev/null; then
        local nv; nv=$(node -v | sed 's/^v//' | cut -d'.' -f1)
        [ "$nv" -ge 22 ] 2>/dev/null && echo -e "  ${GREEN}✅${NC} Node.js: $(node -v)" \
            || echo -e "  ${RED}❌${NC} Node.js: $(node -v) (需要 22+)"
    else
        echo -e "  ${RED}❌${NC} Node.js: 未安装"
    fi

    # OpenClaw
    if command -v openclaw &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} OpenClaw: $(openclaw --version 2>/dev/null || echo 'installed')"
    else
        echo -e "  ${RED}❌${NC} OpenClaw: 未安装"
    fi

    # 端口
    for port_name in "13145:Gateway" "13146:健康检查" "19000:工作台"; do
        local port="${port_name%%:*}" name="${port_name#*:}"
        if lsof -i :"$port" &>/dev/null 2>&1; then
            echo -e "  ${GREEN}✅${NC} 端口 $port ($name): 监听中"
        else
            echo -e "  ${YELLOW}⚠️${NC} 端口 $port ($name): 未监听"
        fi
    done

    # 配置文件
    [ -f "$CONFIG_DIR/env" ] && echo -e "  ${GREEN}✅${NC} 配置文件: 存在" \
        || echo -e "  ${YELLOW}⚠️${NC} 配置文件: 不存在"

    echo ""

    if [ "$status_only" = true ]; then
        return
    fi

    if [ "$fix" = true ]; then
        echo -e "${GREEN}🔧 自动修复中...${NC}"
        if command -v openclaw &>/dev/null; then
            openclaw doctor --non-interactive 2>&1 || true
        fi
        if [ -f "$CONFIG_DIR/config-menu.sh" ]; then
            bash "$CONFIG_DIR/config-menu.sh" --repair-config 2>&1 || true
        fi
        echo -e "${GREEN}✅ 修复完成${NC}"
    fi
}

cmd_workbench() {
    local action="${1:-start}"
    local wb_script=""
    [ -f "$CONFIG_DIR/lobster-world.sh" ] && wb_script="$CONFIG_DIR/lobster-world.sh"
    [ -z "$wb_script" ] && [ -f "$SCRIPT_DIR/scripts/lobster-world.sh" ] && wb_script="$SCRIPT_DIR/scripts/lobster-world.sh"

    if [ -z "$wb_script" ]; then
        echo -e "${YELLOW}⚠️ 工作台未安装，正在安装...${NC}"
        if [ -f "$CONFIG_DIR/config-menu.sh" ]; then
            bash "$CONFIG_DIR/config-menu.sh" --install-pixel-house
        else
            bash "$SCRIPT_DIR/config-menu.sh" --install-pixel-house
        fi
        [ -f "$CONFIG_DIR/lobster-world.sh" ] && wb_script="$CONFIG_DIR/lobster-world.sh"
        [ -z "$wb_script" ] && [ -f "$SCRIPT_DIR/scripts/lobster-world.sh" ] && wb_script="$SCRIPT_DIR/scripts/lobster-world.sh"
    fi

    if [ -n "$wb_script" ]; then
        bash "$wb_script" "$action"
    else
        echo -e "${RED}❌ 工作台脚本未找到${NC}"
        exit 1
    fi
}

cmd_status() {
    echo -e "${CYAN}📊 OpenClaw 服务状态${NC}"
    echo ""

    # OpenClaw
    if command -v openclaw &>/dev/null; then
        openclaw gateway status 2>&1 || true
    else
        echo -e "  ${RED}❌${NC} OpenClaw: 未安装"
    fi
    echo ""

    # 端口
    for port_name in "13145:Gateway" "13146:健康检查" "19000:工作台"; do
        local port="${port_name%%:*}" name="${port_name#*:}"
        if lsof -i :"$port" &>/dev/null 2>&1; then
            echo -e "  ${GREEN}✅${NC} $name (:$port): 运行中"
        else
            echo -e "  ${RED}❌${NC} $name (:$port): 未运行"
        fi
    done
    echo ""
}

cmd_gateway() {
    local action="${1:-status}"
    command -v openclaw &>/dev/null || { echo -e "${RED}❌ OpenClaw 未安装${NC}"; exit 1; }

    case "$action" in
        start|stop|restart|status)
            openclaw gateway "$action" 2>&1 || true
            ;;
        *)
            echo -e "${RED}未知操作: $action${NC}"
            echo "用法: openclaw-setup gateway [start|stop|restart|status]"
            ;;
    esac
}

cmd_persona() {
    if [ -n "${1:-}" ]; then
        echo -e "${GREEN}设置工作档案: $1${NC}"
        export OPENCLAW_PERSONA_ROLE="$1"
    fi
    if [ -f "$CONFIG_DIR/config-menu.sh" ]; then
        bash "$CONFIG_DIR/config-menu.sh"
    else
        bash "$SCRIPT_DIR/config-menu.sh"
    fi
}

cmd_skills() {
    local level="${1:-medium}"
    echo -e "${GREEN}同步技能包 (档位: $level)${NC}"

    local skills_dir="$SCRIPT_DIR/skills/default"
    [ -d "$skills_dir" ] || { echo -e "${RED}❌ 技能包目录不存在${NC}"; exit 1; }

    mkdir -p "$CONFIG_DIR/skills"
    local skill_list
    skill_list="$(get_profile_skill_list "$level")"

    local copied=0 skipped=0
    for skill in $skill_list; do
        local src="$skills_dir/$skill" dst="$CONFIG_DIR/skills/$skill"
        [ -d "$src" ] || continue
        if [ -d "$dst" ]; then skipped=$((skipped + 1)); continue; fi
        cp -a "$src" "$dst" 2>/dev/null && copied=$((copied + 1))
    done

    log_info "技能同步完成: 新增 ${copied}, 保留 ${skipped}"
}

cmd_backup() {
    local backup_dir="$CONFIG_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}💾 备份配置到: $backup_dir${NC}"
    mkdir -p "$backup_dir"

    for item in env openclaw.json agents policy skills channels plugins; do
        [ -e "$CONFIG_DIR/$item" ] && cp -r "$CONFIG_DIR/$item" "$backup_dir/" 2>/dev/null || true
    done

    log_info "备份完成: $backup_dir"
    echo -e "${YELLOW}💡 恢复: cp -r $backup_dir/* $CONFIG_DIR/${NC}"
}

# ================================ 主入口 ================================

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        install|i)      cmd_install "$@" ;;
        config|c)       cmd_config ;;
        repair|r|fix)   cmd_repair ;;
        doctor|d)       cmd_doctor "$@" ;;
        workbench|wb|w) cmd_workbench "$@" ;;
        status|s)       cmd_status ;;
        gateway|gw|g)   cmd_gateway "$@" ;;
        persona|p)      cmd_persona "$@" ;;
        skills|sk)      cmd_skills "$@" ;;
        backup|b)       cmd_backup ;;
        help|--help|-h) show_help ;;
        *)
            echo -e "${RED}未知命令: $cmd${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
