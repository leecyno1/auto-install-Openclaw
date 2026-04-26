#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║   🐵 大圣之怒 · 配置中心 - 简洁版                                    ║
# ║   快速入口模型配置、插件管理、技能同步与服务控制                      ║
# ╚══════════════════════════════════════════════════════════════════╝
#

set -euo pipefail

# 加载共享库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_LIB="$SCRIPT_DIR/scripts/lib/openclaw-custom.sh"
[ -f "$CUSTOM_LIB" ] && source "$CUSTOM_LIB"

# 颜色变量降级（共享库加载失败时使用）
[ -z "${RED:-}" ] && RED='\033[0;31m'
[ -z "${GREEN:-}" ] && GREEN='\033[0;32m'
[ -z "${YELLOW:-}" ] && YELLOW='\033[1;33m'
[ -z "${BLUE:-}" ] && BLUE='\033[0;34m'
[ -z "${PURPLE:-}" ] && PURPLE='\033[0;35m'
[ -z "${CYAN:-}" ] && CYAN='\033[0;36m'
[ -z "${WHITE:-}" ] && WHITE='\033[1;37m'
[ -z "${GRAY:-}" ] && GRAY='\033[0;90m'
[ -z "${NC:-}" ] && NC='\033[0m'

# TTY_INPUT 降级
[ -z "${TTY_INPUT:-}" ] && TTY_INPUT="/dev/stdin"
[ -z "${AUTO_CONFIRM_ALL:-}" ] && AUTO_CONFIRM_ALL=0
[ -z "${NO_PROMPT:-}" ] && NO_PROMPT=0
[ -z "${CONFIG_DIR:-}" ] && CONFIG_DIR="$HOME/.openclaw"

# 路径
CONFIG_DIR="$HOME/.openclaw"
OPENCLAW_ENV="$CONFIG_DIR/env"
OPENCLAW_JSON="$CONFIG_DIR/openclaw.json"

# ================================ TTY 处理 ================================
resolve_tty() {
    if [ -t 0 ]; then echo "/dev/stdin"; return 0; fi
    if [ -e /dev/tty ] && ( : < /dev/tty ) 2>/dev/null; then echo "/dev/tty"; return 0; fi
    echo "/dev/null"
}
TTY_INPUT="$(resolve_tty)"

# 快捷参数
case "${1:-}" in
    --repair-config)    exec bash "$0" --action repair; ;;
    --repair-pairing)   exec bash "$0" --action repair-pairing; ;;
    --install-pixel-house) exec bash "$0" --action install-pixel-house; ;;
    --action)           ACTION="$2"; shift 2 ;;
esac

# ================================ 工具函数 ================================
print_header() {
    clear 2>/dev/null || true
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════╗"
    echo "  ║   🐵 大圣之怒 · 配置中心                     ║"
    echo "  ╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
}

press_enter() {
    echo -en "${GRAY}按 Enter 键继续...${NC}"; read < "$TTY_INPUT" 2>/dev/null || true
}

check_openclaw() {
    if ! command -v openclaw &>/dev/null; then
        echo -e "${RED}✗ OpenClaw 未安装，请先运行: openclaw-setup install${NC}"
        exit 1
    fi
}

# ================================ 功能模块 ================================

# 1. 模型配置
menu_model_config() {
    print_header
    echo -e "${WHITE}模型配置 - 使用官方向导设置 AI 模型与渠道${NC}"
    echo ""
    echo "  [1] 运行官方 onboard 向导（推荐）"
    echo "  [2] 查看当前模型状态"
    echo "  [3] 返回主菜单"
    echo ""

    read -p "请选择 [1-3]: " choice < "$TTY_INPUT"
    case "$choice" in
        1)
            echo -e "${YELLOW}启动官方配置向导...${NC}"
            openclaw onboard 2>&1 || true
            ;;
        2)
            echo ""
            echo -e "${CYAN}当前模型状态:${NC}"
            openclaw models status 2>&1 || echo "  无法获取模型状态"
            ;;
        3) return ;;
    esac
    press_enter
}

# 2. 插件管理
menu_plugin_manager() {
    print_header
    echo -e "${WHITE}插件管理 - 安装/卸载消息渠道插件${NC}"
    echo ""
    echo "  [1] 安装官方插件（飞书 / Discord / WhatsApp）"
    echo "  [2] 安装社区插件（微信 / 企业微信 / 钉钉 / QQ）"
    echo "  [3] 卸载插件"
    echo "  [4] 查看已安装插件"
    echo "  [5] 返回主菜单"
    echo ""

    read -p "请选择 [1-5]: " choice < "$TTY_INPUT"
    case "$choice" in
        1)
            echo -e "${YELLOW}安装官方渠道插件...${NC}"
            openclaw plugins add @openclaw/feishu @openclaw/discord @openclaw/whatsapp 2>&1 || true
            log_info "官方插件安装完成"
            ;;
        2)
            echo ""
            echo "  选择要安装的社区插件:"
            echo "  [1] 微信 (openclaw-wechat-channel)"
            echo "  [2] 企业微信 (@wecom/wecom-openclaw-plugin)"
            echo "  [3] 钉钉 (openclaw-channel-dingtalk)"
            echo "  [4] QQ (@sliverp/qqbot)"
            echo -en "${YELLOW}请选择 [1-4]: ${NC}"
            read sub < "$TTY_INPUT"
            case "$sub" in
                1) openclaw plugins add openclaw-wechat-channel 2>&1 || true ;;
                2) openclaw plugins add @wecom/wecom-openclaw-plugin 2>&1 || true ;;
                3) openclaw plugins add openclaw-channel-dingtalk 2>&1 || true ;;
                4) openclaw plugins add @sliverp/qqbot 2>&1 || true ;;
            esac
            ;;
        3)
            echo -en "${YELLOW}输入要卸载的插件名称: ${NC}"
            read plugin < "$TTY_INPUT"
            openclaw plugins remove "$plugin" 2>&1 || true
            ;;
        4)
            echo ""
            echo -e "${CYAN}已安装插件:${NC}"
            openclaw plugins list 2>&1 || echo "  无法获取插件列表"
            ;;
        5) return ;;
    esac
    press_enter
}

# 3. 技能管理
menu_skill_manager() {
    print_header
    echo -e "${WHITE}技能管理 - 同步本地技能包到 OpenClaw${NC}"
    echo ""
    echo "  [1] 同步基础档技能包 (low)"
    echo "  [2] 同步扩展档技能包 (medium)"
    echo "  [3] 同步超级档技能包 (high)"
    echo "  [4] 重建技能缓存"
    echo "  [5] 返回主菜单"
    echo ""

    read -p "请选择 [1-5]: " choice < "$TTY_INPUT"
    case "$choice" in
        1|2|3)
            local level; case "$choice" in 1) level="low" ;; 2) level="medium" ;; 3) level="high" ;; esac
            sync_skills "$level"
            ;;
        4)
            log_step "重建技能缓存..."
            if [ -f "$SCRIPT_DIR/scripts/refresh_default_skills.py" ]; then
                python3 "$SCRIPT_DIR/scripts/refresh_default_skills.py" 2>&1 || true
            elif command -v openclaw &>/dev/null; then
                openclaw skills sync 2>&1 || true
            fi
            ;;
        5) return ;;
    esac
    press_enter
}

# 4. 工作档案
menu_persona() {
    print_header
    echo -e "${WHITE}工作档案 - 初始化 AI 助手角色${NC}"
    echo ""
    show_persona_cards

    read -p "请选择 [1-7]: " choice < "$TTY_INPUT"
    local role; case "$choice" in
        1) role="druid" ;; 2) role="assassin" ;; 3) role="mage" ;;
        4) role="summoner" ;; 5) role="warrior" ;; 6) role="paladin" ;;
        7) role="designer" ;; *) log_warn "无效选择"; press_enter; return ;;
    esac

    set_persona_role "$role"
    log_info "已选择: ${PERSONA_ROLE_EMOJI} ${PERSONA_ROLE_NAME}"

    if confirm "是否应用此工作档案？" "y"; then
        apply_persona_profile "$role"
        log_info "工作档案已应用"
    fi
    press_enter
}

# 5. Token 档位
menu_token_profile() {
    print_header
    echo -e "${WHITE}Token 档位 - 设置请求限与安全规则${NC}"
    echo ""
    echo "  [1] 基础档 (low)   - 5h/100次, 60万Token"
    echo "  [2] 扩展档 (medium) - 5h/300次, 240万Token"
    echo "  [3] 超级档 (high)  - 请求不限, 600万Token"
    echo "  [4] 不设置 (none)  - 保持当前配置"
    echo "  [5] 返回主菜单"
    echo ""

    read -p "请选择 [1-5]: " choice < "$TTY_INPUT"
    local level; case "$choice" in
        1) level="low" ;; 2) level="medium" ;; 3) level="high" ;;
        4) level="none" ;; 5) return ;; *) return ;;
    esac

    RULE_PROFILE_SELECTED="$level"
    apply_token_profile "$level"
    press_enter
}

# 6. 服务管理
menu_service_manager() {
    print_header
    echo -e "${WHITE}服务管理 - 启动/停止/查看 OpenClaw 服务${NC}"
    echo ""
    echo "  [1] Gateway 状态"
    echo "  [2] 启动 Gateway"
    echo "  [3] 停止 Gateway"
    echo "  [4] 重启 Gateway"
    echo "  [5] 查看所有服务状态"
    echo "  [6] 返回主菜单"
    echo ""

    read -p "请选择 [1-6]: " choice < "$TTY_INPUT"
    case "$choice" in
        1) openclaw gateway status 2>&1 || true ;;
        2) openclaw gateway start 2>&1 || true ;;
        3) openclaw gateway stop 2>&1 || true ;;
        4) openclaw gateway restart 2>&1 || true ;;
        5) show_all_services ;;
        6) return ;;
    esac
    press_enter
}

# 7. 配置修复
menu_repair_config() {
    print_header
    echo -e "${WHITE}配置修复 - 清理错误配置，保留记忆与对话${NC}"
    echo ""

    log_step "开始修复配置..."

    # 运行官方 doctor
    if command -v openclaw &>/dev/null; then
        log_info "运行 openclaw doctor..."
        openclaw doctor --non-interactive 2>&1 || true
    fi

    # 清理残留插件
    clean_stale_plugins

    # 重建缓存
    log_info "重建技能缓存..."
    if command -v openclaw &>/dev/null; then
        openclaw skills sync 2>&1 || true
    fi

    log_info "配置修复完成"
    press_enter
}

clean_stale_plugins() {
    [ -f "$OPENCLAW_JSON" ] || return 0
    if command -v jq &>/dev/null; then
        jq '
            .plugins.allow = (.plugins.allow // [] | map(select(. != "" and . != null))) |
            .plugins.entries = (.plugins.entries // {} | to_entries | map(select(.value.enabled != false)) | from_entries)
        ' "$OPENCLAW_JSON" > "$OPENCLAW_JSON.tmp" && mv "$OPENCLAW_JSON.tmp" "$OPENCLAW_JSON"
        log_info "已清理残留插件配置"
    fi
}

# 8. 像素小屋工作台
menu_pixel_house() {
    print_header
    echo -e "${WHITE}像素小屋工作台 - 可视化管理界面${NC}"
    echo ""
    echo "  [1] 安装工作台"
    echo "  [2] 启动工作台 (端口 19000)"
    echo "  [3] 停止工作台"
    echo "  [4] 查看工作台状态"
    echo "  [5] 返回主菜单"
    echo ""

    read -p "请选择 [1-5]: " choice < "$TTY_INPUT"
    case "$choice" in
        1) install_pixel_house ;;
        2) start_pixel_house ;;
        3) stop_pixel_house ;;
        4) status_pixel_house ;;
        5) return ;;
    esac
    press_enter
}

install_pixel_house() {
    local src="$SCRIPT_DIR/subprojects/lobster-sanctum-ui"
    if [ ! -d "$src" ]; then
        log_warn "工作台源码不存在，请从仓库获取"
        return 1
    fi
    log_step "安装像素小屋工作台..."
    # 安装到 ~/.openclaw
    cp -a "$src" "$CONFIG_DIR/lobster-sanctum-ui" 2>/dev/null || true
    if [ -f "$SCRIPT_DIR/scripts/lobster-world.sh" ]; then
        cp "$SCRIPT_DIR/scripts/lobster-world.sh" "$CONFIG_DIR/lobster-world.sh"
        chmod +x "$CONFIG_DIR/lobster-world.sh"
    fi
    log_info "安装完成，访问 http://127.0.0.1:19000"
}

start_pixel_house() {
    if [ -f "$CONFIG_DIR/lobster-world.sh" ]; then
        bash "$CONFIG_DIR/lobster-world.sh" start
    elif [ -f "$SCRIPT_DIR/scripts/lobster-world.sh" ]; then
        bash "$SCRIPT_DIR/scripts/lobster-world.sh" start
    else
        log_warn "工作台未安装，请先安装"
    fi
}

stop_pixel_house() {
    if [ -f "$CONFIG_DIR/lobster-world.sh" ]; then
        bash "$CONFIG_DIR/lobster-world.sh" stop
    elif [ -f "$SCRIPT_DIR/scripts/lobster-world.sh" ]; then
        bash "$SCRIPT_DIR/scripts/lobster-world.sh" stop
    fi
}

status_pixel_house() {
    if lsof -i :19000 &>/dev/null; then
        log_info "工作台运行中 (http://127.0.0.1:19000)"
    else
        log_warn "工作台未运行"
    fi
}

# 9. 网站集成
menu_website() {
    print_header
    echo -e "${WHITE}网站集成 - SSH 隧道与远程连接${NC}"
    echo ""
    echo -e "  服务器: ${WEBSITE_SERVER_IP:-60.205.58.39}"
    echo -e "  域名:   ${WEBSITE_DOMAIN:-monkeykingfury.com}"
    echo -e "  端口:   ${WEBSITE_PORT:-8787}"
    echo -e "  Dashboard 端口: ${WEBSITE_DASHBOARD_PORT:-13145}"
    echo ""
    echo "  [1] 写入网站环境变量"
    echo "  [2] 启动 SSH 隧道"
    echo "  [3] 查看 SSH 隧道状态"
    echo "  [4] 停止 SSH 隧道"
    echo "  [5] 测试网站连接"
    echo "  [0] 返回主菜单"
    echo ""

    read -p "请选择 [0-5]: " choice < "$TTY_INPUT"
    case "$choice" in
        1) write_website_env ;;
        2) ssh_tunnel_start ;;
        3) ssh_tunnel_status ;;
        4) ssh_tunnel_stop ;;
        5)
            log_info "测试连接 ${WEBSITE_DOMAIN:-monkeykingfury.com}..."
            if curl -fsSL --connect-timeout 5 --max-time 10 "https://${WEBSITE_DOMAIN:-monkeykingfury.com}" >/dev/null 2>&1; then
                log_info "网站连接正常"
            else
                log_warn "网站连接失败"
            fi
            ;;
        0) return ;;
    esac
    press_enter
}

# A. Hermes 代理
menu_hermes() {
    print_header
    echo -e "${WHITE}Hermes 代理 - AI 智能体网关管理${NC}"
    echo ""

    if command -v hermes &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} Hermes: $(hermes --version 2>&1 | head -1)"
    else
        echo -e "  ${YELLOW}⚠️${NC} Hermes: 未安装"
    fi
    echo ""

    echo "  [1] 安装 Hermes"
    echo "  [2] 运行配置向导"
    echo "  [3] 配置模型"
    echo "  [4] 启动 Gateway"
    echo "  [5] 停止 Gateway"
    echo "  [6] 查看状态"
    echo "  [0] 返回主菜单"
    echo ""

    read -p "请选择 [0-6]: " choice < "$TTY_INPUT"
    case "$choice" in
        1) install_hermes ;;
        2)
            command -v hermes &>/dev/null || { log_warn "请先安装 Hermes"; press_enter; return; }
            hermes setup 2>&1 || true
            ;;
        3)
            command -v hermes &>/dev/null || { log_warn "请先安装 Hermes"; press_enter; return; }
            hermes model 2>&1 || true
            ;;
        4) start_hermes_gateway ;;
        5) stop_hermes_gateway ;;
        6) status_hermes ;;
        0) return ;;
    esac
    press_enter
}

# B. 路由与档位
menu_routing() {
    print_header
    echo -e "${WHITE}路由与档位 - Token 消耗控制与安全策略${NC}"
    echo ""
    show_routing_status
    echo ""

    echo "  [1] 设置基础档 (low)    - 5h/100次, 60万Token"
    echo "  [2] 设置扩展档 (medium)  - 5h/300次, 240万Token"
    echo "  [3] 设置超级档 (high)   - 请求不限, 600万Token"
    echo "  [4] 不限 (none)         - 无限制"
    echo "  [5] 刷新状态"
    echo "  [0] 返回主菜单"
    echo ""

    read -p "请选择 [0-5]: " choice < "$TTY_INPUT"
    case "$choice" in
        1) configure_model_routing "low" ;;
        2) configure_model_routing "medium" ;;
        3) configure_model_routing "high" ;;
        4) configure_model_routing "none" ;;
        5) show_routing_status ;;
        0) return ;;
    esac
    press_enter
}

# ================================ 主菜单 ================================

show_all_services() {
    echo ""
    echo -e "${CYAN}服务状态总览:${NC}"
    echo ""

    # Gateway
    if lsof -i :13145 &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} Gateway (13145): 运行中"
    else
        echo -e "  ${RED}❌${NC} Gateway (13145): 未运行"
    fi

    # 工作台
    if lsof -i :19000 &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} 像素小屋 (19000): 运行中"
    else
        echo -e "  ${GRAY}--${NC} 像素小屋 (19000): 未运行"
    fi

    # 健康检查
    if lsof -i :13146 &>/dev/null 2>&1; then
        echo -e "  ${GREEN}✅${NC} 健康检查 (13146): 运行中"
    else
        echo -e "  ${GRAY}--${NC} 健康检查 (13146): 未运行"
    fi

    # Hermes
    if command -v hermes &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} Hermes: $(hermes --version 2>&1 | head -1)"
    else
        echo -e "  ${GRAY}--${NC} Hermes: 未安装"
    fi

    # Node.js
    if command -v node &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} Node.js: $(node -v)"
    else
        echo -e "  ${RED}❌${NC} Node.js: 未安装"
    fi

    # OpenClaw
    if command -v openclaw &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} OpenClaw: $(openclaw --version 2>/dev/null || echo 'installed')"
    else
        echo -e "  ${RED}❌${NC} OpenClaw: 未安装"
    fi

    # 配置文件
    if [ -f "$OPENCLAW_ENV" ]; then
        echo -e "  ${GREEN}✅${NC} 配置文件: $OPENCLAW_ENV"
    else
        echo -e "  ${YELLOW}⚠️${NC} 配置文件: 不存在"
    fi
    echo ""
}

main_menu() {
    # 非菜单参数直接执行
    if [ -n "${ACTION:-}" ]; then
        case "$ACTION" in
            repair)          menu_repair_config; exit 0 ;;
            repair-pairing)  clean_stale_plugins; exit 0 ;;
            install-pixel-house) install_pixel_house; exit 0 ;;
        esac
    fi

    check_openclaw

    while true; do
        print_header
        show_all_services
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  [1] 模型配置          [6] 服务管理"
        echo "  [2] 插件管理          [7] 配置修复"
        echo "  [3] 技能管理          [8] 像素小屋工作台"
        echo "  [4] 工作档案          [9] 网站集成"
        echo "  [5] Token 档位        [A] Hermes 代理"
        echo "                        [B] 路由与档位"
        echo ""
        echo "  [0] 退出"
        echo ""

        read -p "请选择 [0-9,A,B]: " choice < "$TTY_INPUT"
        case "$choice" in
            1) menu_model_config ;;
            2) menu_plugin_manager ;;
            3) menu_skill_manager ;;
            4) menu_persona ;;
            5) menu_token_profile ;;
            6) menu_service_manager ;;
            7) menu_repair_config ;;
            8) menu_pixel_house ;;
            9) menu_website ;;
            A|a) menu_hermes ;;
            B|b) menu_routing ;;
            0) echo -e "${GREEN}再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选择${NC}"; press_enter ;;
        esac
    done
}

main_menu
