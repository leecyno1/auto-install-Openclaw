#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║   🐵 大圣之怒 · 统一入口工具 v2.0.0                                 ║
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
${CYAN}🐵 大圣之怒 · 统一入口工具${NC}

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

${GREEN}网站集成:${NC}
  tunnel [操作]      管理 SSH 隧道 (start/stop/status)
  website            配置网站集成 (monkeykingfury.com)

${GREEN}API Server:${NC}
  api-server [操作]  配置 API Server (setup/status/test)
  hermes-api [操作]  配置 Hermes API Server (setup/status/test)

${GREEN}Hermes 代理:${NC}
  hermes [操作]      管理 Hermes 代理 (install/setup/start/stop/status/model)

${GREEN}路由与档位:${NC}
  routing [档位]     配置 Token 档位 (low/medium/high/none)
  routing status     查看当前路由状态

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
  --model <name>               指定默认模型
  --api-key <key>              设置 API 密钥
  --api-url <url>              设置 API Base URL
  --api-provider <name>        设置 API Provider

${GREEN}智能体选择:${NC}
  两者一般只装一个，按需选择：
  openclaw-setup install                    # 安装龙虾（OpenClaw）
  openclaw-setup hermes install             # 安装 Hermes

${GREEN}示例:${NC}
  openclaw-setup install --auto --model gpt-4o --api-key sk-xxx
  openclaw-setup hermes install             # 安装 Hermes
  openclaw-setup hermes setup               # 运行 Hermes 配置向导
  openclaw-setup tunnel start               # 启动 SSH 隧道
  openclaw-setup rt medium                  # 设置扩展档
EOF
}

# ================================ 命令实现 ================================

cmd_install() {
    local install_args=()
    local args=("$@")
    local i=0
    while [ $i -lt ${#args[@]} ]; do
        local arg="${args[$i]}"
        case "$arg" in
            --auto|--auto-confirm-all) install_args+=(--auto-confirm-all) ;;
            --no-custom)               install_args+=(--no-custom) ;;
            --persona|--rule-profile|--version|--gateway-bind|--gateway-port|\
            --model|--api-key|--api-url|--api-provider)
                install_args+=("$arg" "${args[$((i+1))]:-}")
                i=$((i + 1))
                ;;
            *) install_args+=("$arg") ;;
        esac
        i=$((i + 1))
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
    if command -v node &>/dev/null; then
        local nv; nv=$(node -v | sed 's/^v//' | cut -d'.' -f1)
        [ "$nv" -ge 22 ] 2>/dev/null && echo -e "  ${GREEN}✅${NC} Node.js: $(node -v)" \
            || echo -e "  ${RED}❌${NC} Node.js: $(node -v) (需要 22+)"
    else
        echo -e "  ${RED}❌${NC} Node.js: 未安装"
    fi
    if command -v openclaw &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} OpenClaw: $(openclaw --version 2>/dev/null || echo 'installed')"
    else
        echo -e "  ${RED}❌${NC} OpenClaw: 未安装"
    fi
    if command -v hermes &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} Hermes: $(hermes --version 2>&1 | head -1)"
    else
        echo -e "  ${YELLOW}⚠️${NC} Hermes: 未安装"
    fi
    for port_name in "13145:Gateway" "13146:健康检查" "19000:工作台"; do
        local port="${port_name%%:*}" name="${port_name#*:}"
        if lsof -i :"$port" &>/dev/null 2>&1; then
            echo -e "  ${GREEN}✅${NC} 端口 $port ($name): 监听中"
        else
            echo -e "  ${YELLOW}⚠️${NC} 端口 $port ($name): 未监听"
        fi
    done
    [ -f "$CONFIG_DIR/env" ] && echo -e "  ${GREEN}✅${NC} 配置文件: 存在" \
        || echo -e "  ${YELLOW}⚠️${NC} 配置文件: 不存在"
    echo ""
    if [ "$status_only" = true ]; then return; fi
    if [ "$fix" = true ]; then
        echo -e "${GREEN}🔧 自动修复中...${NC}"
        if command -v openclaw &>/dev/null; then openclaw doctor --non-interactive 2>&1 || true; fi
        if [ -f "$CONFIG_DIR/config-menu.sh" ]; then bash "$CONFIG_DIR/config-menu.sh" --repair-config 2>&1 || true; fi
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
        if [ -f "$CONFIG_DIR/config-menu.sh" ]; then bash "$CONFIG_DIR/config-menu.sh" --install-pixel-house
        else bash "$SCRIPT_DIR/config-menu.sh" --install-pixel-house; fi
        [ -f "$CONFIG_DIR/lobster-world.sh" ] && wb_script="$CONFIG_DIR/lobster-world.sh"
        [ -z "$wb_script" ] && [ -f "$SCRIPT_DIR/scripts/lobster-world.sh" ] && wb_script="$SCRIPT_DIR/scripts/lobster-world.sh"
    fi
    if [ -n "$wb_script" ]; then bash "$wb_script" "$action"
    else echo -e "${RED}❌ 工作台脚本未找到${NC}"; exit 1; fi
}

cmd_status() {
    echo -e "${CYAN}📊 OpenClaw 服务状态${NC}"
    echo ""
    if command -v openclaw &>/dev/null; then openclaw gateway status 2>&1 || true
    else echo -e "  ${RED}❌${NC} OpenClaw: 未安装"; fi
    echo ""
    if command -v hermes &>/dev/null; then echo -e "  ${GREEN}✅${NC} Hermes: $(hermes --version 2>&1 | head -1)"
    else echo -e "  ${YELLOW}⚠️${NC} Hermes: 未安装"; fi
    echo ""
    for port_name in "13145:Gateway" "13146:健康检查" "19000:工作台"; do
        local port="${port_name%%:*}" name="${port_name#*:}"
        if lsof -i :"$port" &>/dev/null 2>&1; then echo -e "  ${GREEN}✅${NC} $name (:$port): 运行中"
        else echo -e "  ${RED}❌${NC} $name (:$port): 未运行"; fi
    done
    echo ""
}

cmd_gateway() {
    local action="${1:-status}"
    command -v openclaw &>/dev/null || { echo -e "${RED}❌ OpenClaw 未安装${NC}"; exit 1; }
    case "$action" in
        start|stop|restart|status) openclaw gateway "$action" 2>&1 || true ;;
        *) echo -e "${RED}未知操作: $action${NC}"; echo "用法: openclaw-setup gateway [start|stop|restart|status]" ;;
    esac
}

cmd_persona() {
    if [ -n "${1:-}" ]; then echo -e "${GREEN}设置工作档案: $1${NC}"; export OPENCLAW_PERSONA_ROLE="$1"; fi
    if [ -f "$CONFIG_DIR/config-menu.sh" ]; then bash "$CONFIG_DIR/config-menu.sh"
    else bash "$SCRIPT_DIR/config-menu.sh"; fi
}

cmd_skills() {
    local level="${1:-medium}"
    RULE_PROFILE_SELECTED="$level" sync_skills "$level"
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

cmd_tunnel() {
    local action="${1:-status}"
    local remote_port="${2:-${WEBSITE_DASHBOARD_PORT:-13145}}"
    local local_port="${3:-${WEBSITE_DASHBOARD_PORT:-13145}}"
    case "$action" in
        start)  ssh_tunnel_start "$remote_port" "$local_port" ;;
        stop)   ssh_tunnel_stop "$remote_port" ;;
        status) ssh_tunnel_status "$remote_port" ;;
        *) echo -e "${RED}未知操作: $action${NC}"; echo "用法: openclaw-setup tunnel [start|stop|status]" ;;
    esac
}

cmd_website() {
    echo -e "${CYAN}🌐 网站集成配置${NC}"
    echo ""
    echo -e "  服务器: ${WEBSITE_SERVER_IP:-60.205.58.39}"
    echo -e "  域名:   ${WEBSITE_DOMAIN:-monkeykingfury.com}"
    echo -e "  端口:   ${WEBSITE_PORT:-8787}"
    echo -e "  Dashboard: ${WEBSITE_DASHBOARD_PORT:-13145}"
    echo ""
    echo "  [1] 写入网站环境变量"
    echo "  [2] 启动 SSH 隧道"
    echo "  [3] 查看 SSH 隧道状态"
    echo "  [4] 停止 SSH 隧道"
    echo "  [5] 测试网站连接"
    echo "  [0] 返回"
    echo ""
    read -p "请选择 [0-5]: " choice < "${TTY_INPUT:-/dev/stdin}"
    case "$choice" in
        1) write_website_env ;;
        2) ssh_tunnel_start ;;
        3) ssh_tunnel_status ;;
        4) ssh_tunnel_stop ;;
        5) log_info "测试连接 ${WEBSITE_DOMAIN:-monkeykingfury.com}..."; curl -fsSL --connect-timeout 5 --max-time 10 "https://${WEBSITE_DOMAIN:-monkeykingfury.com}" >/dev/null 2>&1 && log_info "连接正常" || log_warn "连接失败" ;;
        0) return ;;
    esac
}

cmd_api_server() {
    local action="${1:-setup}"
    case "$action" in
        setup|config)
            local bind="${2:-lan}"
            local port="${3:-13145}"
            local domains="${4:-}"
            configure_openclaw_api_server "$bind" "$port" "$domains"
            ;;
        status)
            echo -e "${CYAN}📊 OpenClaw Gateway API Server 状态${NC}"
            echo ""
            if command -v openclaw &>/dev/null; then
                local bind port token
                bind="$(openclaw config get gateway.bind 2>/dev/null || echo '未配置')"
                port="$(openclaw config get gateway.port 2>/dev/null || echo '13145')"
                token="$(openclaw config get gateway.auth.token 2>/dev/null || echo '未配置')"
                echo -e "  绑定模式: $bind"
                echo -e "  端口: $port"
                echo -e "  认证 Token: ${token:0:16}..."
                echo ""
                # 检查端口监听
                if lsof -i :"$port" &>/dev/null 2>&1; then
                    echo -e "  ${GREEN}✅${NC} Gateway: 运行中 (端口 $port)"
                else
                    echo -e "  ${YELLOW}⚠️${NC} Gateway: 未运行"
                    echo -e "  启动: openclaw gateway start"
                fi
            else
                echo -e "  ${RED}❌${NC} OpenClaw 未安装"
            fi
            ;;
        test)
            local port="${2:-13145}"
            local token
            token="$(openclaw config get gateway.auth.token 2>/dev/null || echo '')"
            if [ -z "$token" ] || [ "$token" = "null" ]; then
                echo -e "${RED}❌ 未配置认证 Token${NC}"
                return 1
            fi
            echo -e "${CYAN}测试 API Server 连接...${NC}"
            curl -fsSL --connect-timeout 5 --max-time 10 \
                "http://127.0.0.1:$port/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -d '{"model": "test", "messages": [{"role": "user", "content": "test"}]}' 2>&1 || \
                echo -e "${YELLOW}测试失败，请检查 Gateway 是否运行${NC}"
            ;;
        *) echo -e "${RED}未知操作: $action${NC}"; echo "用法: openclaw-setup api-server [setup|status|test]" ;;
    esac
}

cmd_hermes_api() {
    local action="${1:-setup}"
    case "$action" in
        setup|config)
            local host="${2:-0.0.0.0}"
            local port="${3:-8000}"
            local api_key="${4:-}"
            configure_hermes_api_server "$host" "$port" "$api_key"
            echo -e "${YELLOW}请重启 Gateway 使配置生效: hermes gateway restart${NC}"
            ;;
        status)
            echo -e "${CYAN}📊 Hermes API Server 状态${NC}"
            echo ""
            if command -v hermes &>/dev/null; then
                if [ -f "$HOME/.hermes/config.yaml" ]; then
                    python3 -c "
import yaml
with open('$HOME/.hermes/config.yaml') as f:
    config = yaml.safe_load(f) or {}
api = config.get('platforms', {}).get('api_server', {})
print(f\"  启用: {api.get('enabled', False)}\")
print(f\"  地址: http://{api.get('host', '0.0.0.0')}:{api.get('port', 8000)}\")
print(f\"  API Key: {str(api.get('api_key', ''))[:16]}...\")
" 2>/dev/null || echo -e "  ${YELLOW}⚠️${NC} 无法读取配置"
                    echo ""
                    # 检查端口监听
                    local port
                    port="$(python3 -c "import yaml; c=yaml.safe_load(open('$HOME/.hermes/config.yaml')) or {}; print(c.get('platforms', {}).get('api_server', {}).get('port', 8000))" 2>/dev/null || echo '8000')"
                    if lsof -i :"$port" &>/dev/null 2>&1; then
                        echo -e "  ${GREEN}✅${NC} API Server: 运行中 (端口 $port)"
                    else
                        echo -e "  ${YELLOW}⚠️${NC} API Server: 未运行"
                        echo -e "  重启: hermes gateway restart"
                    fi
                else
                    echo -e "  ${YELLOW}⚠️${NC} Hermes 未配置"
                fi
            else
                echo -e "  ${RED}❌${NC} Hermes 未安装"
            fi
            ;;
        test)
            local port="${2:-8000}"
            echo -e "${CYAN}测试 Hermes API Server 连接...${NC}"
            curl -fsSL --connect-timeout 5 --max-time 10 "http://127.0.0.1:$port/health" 2>&1 || \
                echo -e "${YELLOW}测试失败，请检查 Gateway 是否运行${NC}"
            ;;
        *) echo -e "${RED}未知操作: $action${NC}"; echo "用法: openclaw-setup hermes-api [setup|status|test]" ;;
    esac
}

cmd_hermes() {
    local action="${1:-status}"
    case "$action" in
        install) install_hermes ;;
        setup) command -v hermes &>/dev/null || { echo -e "${RED}❌ Hermes 未安装${NC}"; return 1; }; hermes setup 2>&1 ;;
        model) command -v hermes &>/dev/null || { echo -e "${RED}❌ Hermes 未安装${NC}"; return 1; }; if [ -n "${2:-}" ]; then configure_hermes_model "$2" "${3:-}"; else hermes model 2>&1; fi ;;
        start) start_hermes_gateway ;;
        stop) stop_hermes_gateway ;;
        status) status_hermes ;;
        *) echo -e "${RED}未知操作: $action${NC}"; echo "用法: openclaw-setup hermes [install|setup|start|stop|status|model]" ;;
    esac
}

cmd_routing() {
    local action="${1:-status}"
    case "$action" in
        low|medium|high|none) configure_model_routing "$action" ;;
        status|show) show_routing_status ;;
        set) configure_model_routing "${2:-}" ;;
        *) echo -e "${RED}未知操作: $action${NC}"; echo "用法: openclaw-setup routing [low|medium|high|none|status|set]" ;;
    esac
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
        tunnel|t)       cmd_tunnel "$@" ;;
        website|web)    cmd_website ;;
        api-server|api) cmd_api_server "$@" ;;
        hermes-api|hapi) cmd_hermes_api "$@" ;;
        hermes|h)       cmd_hermes "$@" ;;
        routing|rt)     cmd_routing "$@" ;;
        help|--help|-h) show_help ;;
        *) echo -e "${RED}未知命令: $cmd${NC}"; echo ""; show_help; exit 1 ;;
    esac
}

main "$@"
