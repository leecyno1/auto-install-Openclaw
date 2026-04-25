#!/usr/bin/env bash
#===============================================================================
# OpenClaw 极简安装脚本 v2.0
# 模块化架构 - 极简安装
#===============================================================================
# 用法:
#   curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash
#   bash install.sh
#===============================================================================

set -euo pipefail

#------------------------------------------------------------------------------
# 颜色配置
#------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

#------------------------------------------------------------------------------
# 全局变量
#------------------------------------------------------------------------------
INSTALL_LOG="/tmp/openclaw-install-$(date +%Y%m%d_%H%M%S).log"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-13145}"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#------------------------------------------------------------------------------
# UI 组件
#------------------------------------------------------------------------------

print_logo() {
    echo -e "${RED}"
    cat << 'EOF'
   ██████╗ ██████╗ ███████╗██╗██████╗ ██╗ █████╗ ███╗   ██╗
  ██╔═══██╗██╔══██╗██╔════╝██║██╔══██╗██║██╔══██╗████╗  ██║
  ██║   ██║██████╔╝███████╗██║██║  ██║██║███████║██╔██╗ ██║
  ██║   ██║██╔══██╗╚════██║██║██║  ██║██║██╔══██║██║╚██╗██║
  ╚██████╔╝██║  ██║███████║██║██████╔╝██║██║  ██║██║ ╚████║
   ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝╚═════╝ ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
EOF
    echo -e "${NC}"
    echo -e "${BOLD}极简安装脚本 v2.0 (模块化架构)${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_divider() {
    echo -e "${RED}$(printf '─%.0s' $(seq 1 60))${NC}"
}

#------------------------------------------------------------------------------
# 工具函数
#------------------------------------------------------------------------------

check_command() {
    command -v "$1" &>/dev/null
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$INSTALL_LOG"
}

#------------------------------------------------------------------------------
# 环境检测
#------------------------------------------------------------------------------

check_environment() {
    print_step "检测运行环境..."

    # 检查操作系统
    case "$(uname -s)" in
        Linux*)     OS="linux" ;;
        Darwin*)    OS="macos" ;;
        *)          print_error "不支持的操作系统: $(uname -s)"; exit 1 ;;
    esac
    print_success "操作系统: $OS"

    # 检查必要命令
    local missing_cmds=()
    for cmd in curl bash python3; do
        if ! check_command "$cmd"; then
            missing_cmds+=("$cmd")
        fi
    done

    if [ ${#missing_cmds[@]} -gt 0 ]; then
        print_error "缺少必要命令: ${missing_cmds[*]}"
        exit 1
    fi
    print_success "必要命令检查通过"

    # 检查 Node.js
    if ! check_command node; then
        print_warn "Node.js 未安装，将在官方安装时自动安装"
    else
        print_success "Node.js: $(node --version)"
    fi
}

#------------------------------------------------------------------------------
# 官方安装
#------------------------------------------------------------------------------

run_official_install() {
    print_step "运行官方 OpenClaw 安装..."
    print_divider

    # 使用官方安装脚本
    if bash -c "$(curl -fsSL https://openclaw.ai/install.sh)" 2>&1 | tee -a "$INSTALL_LOG"; then
        print_success "官方安装完成"
    else
        print_error "官方安装失败，请查看日志: $INSTALL_LOG"
        return 1
    fi
}

#------------------------------------------------------------------------------
# 飞书清理补丁
#------------------------------------------------------------------------------

apply_feishu_patch() {
    print_step "应用飞书清理补丁..."

    local cfg="$HOME/.openclaw/openclaw.json"
    if [ ! -f "$cfg" ]; then
        print_warn "配置文件不存在，跳过飞书清理"
        return 0
    fi

    # 删除飞书 channel 配置，避免 @larksuiteoapi/node-sdk 依赖缺失
    python3 - "$cfg" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    channels = data.get("channels") or {}
    if "feishu" in channels:
        del channels["feishu"]
        data["channels"] = channels
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print("feishu-cleaned")
except Exception:
    pass
PY

    if [ -f "$cfg" ]; then
        print_success "飞书配置已清理"
    fi
}

#------------------------------------------------------------------------------
# 显示后续步骤
#------------------------------------------------------------------------------

show_next_steps() {
    echo ""
    print_divider
    echo ""
    echo -e "${GREEN}🎉 安装完成！${NC}"
    echo ""
    echo -e "${BOLD}后续步骤:${NC}"
    echo ""
    echo -e "${CYAN}1. 配置 Skills（可选）:${NC}"
    echo "   openclaw-setup config skills --tier basic"
    echo "   openclaw-setup config skills --tier extended"
    echo ""
    echo -e "${CYAN}2. 配置三档规则（可选）:${NC}"
    echo "   openclaw-setup config tier-rules --level medium"
    echo ""
    echo -e "${CYAN}3. 安装像素小屋（可选）:${NC}"
    echo "   openclaw-setup config pixel-house --install"
    echo "   openclaw-setup config pixel-house --start"
    echo ""
    echo -e "${CYAN}4. 配置自定义 API（可选）:${NC}"
    echo "   openclaw-setup config api --show"
    echo "   openclaw-setup config api --replace-service nanobanana --with https://my.com/api"
    echo ""
    echo -e "${CYAN}5. 或使用交互式菜单:${NC}"
    echo "   openclaw-setup config"
    echo ""
    echo -e "${BOLD}常用命令:${NC}"
    echo "   openclaw gateway start   # 启动服务"
    echo "   openclaw gateway status  # 查看状态"
    echo "   openclaw onboard         # 重新配置"
    echo ""
    echo "安装日志: $INSTALL_LOG"
    echo ""
}

#------------------------------------------------------------------------------
# 帮助信息
#------------------------------------------------------------------------------

show_help() {
    print_logo
    cat << EOF
${CYAN}用法:${NC}
  curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash
  bash install.sh

${CYAN}选项:${NC}
  --help     显示帮助信息
  --dry-run  仅显示安装计划，不实际执行

${CYAN}环境变量:${NC}
  OPENCLAW_GATEWAY_PORT  Gateway 端口 (默认: 13145)

${CYAN}说明:${NC}
  此脚本仅执行极简安装，详细的配置（如 Skills、三档规则、
  像素小屋等）需要使用 openclaw-setup config 命令单独配置。

EOF
}

#------------------------------------------------------------------------------
# 主流程
#------------------------------------------------------------------------------

main() {
    local dry_run=false

    # 解析参数
    for arg in "$@"; do
        case $arg in
            --help)
                show_help
                exit 0
                ;;
            --dry-run)
                dry_run=true
                ;;
        esac
    done

    # 显示 Logo
    clear
    print_logo

    if [ "$dry_run" = true ]; then
        echo "安装计划:"
        echo "  1. 检测运行环境"
        echo "  2. 运行官方安装 (openclaw.ai/install.sh)"
        echo "  3. 应用飞书清理补丁"
        echo ""
        echo "使用 --dry-run 参数跳过实际执行"
        exit 0
    fi

    echo ""
    print_divider
    echo ""

    # 执行安装步骤
    check_environment
    echo ""

    run_official_install
    echo ""

    apply_feishu_patch
    echo ""

    # 显示后续步骤
    show_next_steps
}

# 运行主函数
main "$@"
