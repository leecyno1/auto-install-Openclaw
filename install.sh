#!/usr/bin/env bash
#===============================================================================
# OpenClaw 极简安装脚本
# 官方安装 + 基本配置
#===============================================================================
# 用法:
#   curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash
#   bash install.sh
#===============================================================================

set -e

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
SKILL_TIER="${OPENCLAW_SKILL_TIER:-basic}"

#------------------------------------------------------------------------------
# UI 组件
#------------------------------------------------------------------------------

# 打印红色边框盒子
print_box() {
    local msg="$1"
    local width=60
    echo -e "${RED}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
    echo -e "${RED}║${NC}$(printf "%-${width}s" "$msg")${RED}║${NC}"
    echo -e "${RED}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
}

# 打印 Logo
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
    echo -e "${BOLD}极简安装脚本 v1.0${NC}"
    echo ""
}

# 打印步骤
print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 打印成功
print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

# 打印警告
print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 打印错误
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印分隔线
print_divider() {
    echo -e "${RED}$(printf '─%.0s' $(seq 1 60))${NC}"
}

#------------------------------------------------------------------------------
# 工具函数
#------------------------------------------------------------------------------

# 检查命令是否存在
check_command() {
    command -v "$1" &>/dev/null
}

# 日志记录
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
    for cmd in curl bash; do
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
# 官方配置向导
#------------------------------------------------------------------------------

run_official_onboard() {
    print_step "运行官方配置向导..."
    print_divider

    # 运行官方 onboard 命令
    if check_command openclaw; then
        if openclaw onboard --install-daemon 2>&1 | tee -a "$INSTALL_LOG"; then
            print_success "官方配置完成"
        else
            print_warn "配置向导未完成，可稍后手动运行: openclaw onboard"
        fi
    else
        print_warn "openclaw 命令不可用，跳过配置向导"
    fi
}

#------------------------------------------------------------------------------
# 飞书清理补丁
#------------------------------------------------------------------------------

apply_feishu_patch() {
    print_step "应用飞书清理补丁..."
    print_divider

    local cfg="$HOME/.openclaw/openclaw.json"
    if [ ! -f "$cfg" ]; then
        print_warn "配置文件不存在，跳过飞书清理"
        return 0
    fi

    # 删除飞书 channel 配置，避免 @larksuiteoapi/node-sdk 依赖缺失
    if check_command jq; then
        local tmp
        tmp="$(mktemp)"
        if jq 'del(.channels.feishu)' "$cfg" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$cfg"
            print_success "飞书配置已清理"
        else
            rm -f "$tmp"
            print_warn "飞书清理失败（可能已清理或无权限）"
        fi
    elif check_command python3; then
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
except Exception:
    pass
PY
        print_success "飞书配置已清理"
    else
        print_warn "缺少 jq 或 python3，跳过飞书清理"
    fi
}

#------------------------------------------------------------------------------
# Skills 安装
#------------------------------------------------------------------------------

install_default_skills() {
    print_step "安装默认 Skills 预设..."
    print_divider

    if ! check_command openclaw; then
        print_warn "openclaw 命令不可用，跳过 Skills 安装"
        return 0
    fi

    # 官方 Skills 安装
    if openclaw skills sync 2>&1 | tee -a "$INSTALL_LOG"; then
        print_success "Skills 同步完成"
    else
        print_warn "Skills 同步失败，可稍后手动运行: openclaw skills sync"
    fi
}

#------------------------------------------------------------------------------
# 基础配置
#------------------------------------------------------------------------------

apply_basic_config() {
    print_step "应用基础配置..."
    print_divider

    if ! check_command openclaw; then
        return 0
    fi

    # 设置 Gateway 端口（如果未设置）
    local current_port
    current_port="$(openclaw config get gateway.port 2>/dev/null || echo "")"
    if [ -z "$current_port" ] || [ "$current_port" = "undefined" ]; then
        openclaw config set gateway.port "$GATEWAY_PORT" 2>/dev/null || true
        print_success "Gateway 端口已设置为: $GATEWAY_PORT"
    fi

    # 设置 Gateway 模式
    local current_mode
    current_mode="$(openclaw config get gateway.mode 2>/dev/null || echo "")"
    if [ -z "$current_mode" ] || [ "$current_mode" = "undefined" ]; then
        openclaw config set gateway.mode local 2>/dev/null || true
        print_success "Gateway 模式已设置为: local"
    fi

    # 设置规则档位为 MEDIUM
    openclaw config set vendor.ruleProfile medium 2>/dev/null || true
    print_success "规则档位已设置为: medium"
}

#------------------------------------------------------------------------------
# 清理旧配置
#------------------------------------------------------------------------------

cleanup_stale_config() {
    print_step "清理旧配置..."
    print_divider

    local cfg="$HOME/.openclaw/openclaw.json"
    if [ ! -f "$cfg" ]; then
        return 0
    fi

    # 清理无效插件配置
    if check_command jq; then
        local tmp
        tmp="$(mktemp)"
        if jq 'if .plugins and .plugins.entries then
            .plugins.entries |= with_entries(
                select(.value != null and .value != "")
            )
        else . end' "$cfg" > "$tmp" 2>/dev/null; then
            mv "$tmp" "$cfg"
            print_success "无效插件配置已清理"
        else
            rm -f "$tmp"
        fi
    fi
}

#------------------------------------------------------------------------------
# 启动验证
#------------------------------------------------------------------------------

verify_installation() {
    print_step "验证安装..."
    print_divider

    if ! check_command openclaw; then
        print_warn "openclaw 命令不可用，跳过验证"
        return 0
    fi

    # 检查 Gateway 状态
    if openclaw gateway status 2>&1 | tee -a "$INSTALL_LOG"; then
        print_success "Gateway 运行正常"
    else
        print_warn "Gateway 未运行，可运行: openclaw gateway start"
    fi
}

#------------------------------------------------------------------------------
# 帮助信息
#------------------------------------------------------------------------------

show_help() {
    print_logo
    echo "用法:"
    echo "  curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash"
    echo "  bash install.sh"
    echo ""
    echo "选项:"
    echo "  --help     显示帮助信息"
    echo "  --dry-run  仅显示安装计划，不实际执行"
    echo "  --skip-onboard  跳过配置向导"
    echo ""
    echo "环境变量:"
    echo "  OPENCLAW_GATEWAY_PORT  Gateway 端口 (默认: 13145)"
    echo "  OPENCLAW_SKILL_TIER    Skills 预设: basic|extended|super (默认: basic)"
    echo ""
}

#------------------------------------------------------------------------------
# 主流程
#------------------------------------------------------------------------------

main() {
    local skip_onboard=false
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
            --skip-onboard)
                skip_onboard=true
                ;;
        esac
    done

    # 显示 Logo
    clear
    print_logo
    print_box "OpenClaw 极简安装"

    if [ "$dry_run" = true ]; then
        echo ""
        echo "安装计划:"
        echo "  1. 检测运行环境"
        echo "  2. 运行官方安装 (openclaw.ai/install.sh)"
        echo "  3. 运行官方配置向导 (openclaw onboard --install-daemon)"
        echo "  4. 应用飞书清理补丁"
        echo "  5. 安装默认 Skills"
        echo "  6. 应用基础配置"
        echo "  7. 清理旧配置"
        echo "  8. 验证安装"
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

    if [ "$skip_onboard" = false ]; then
        run_official_onboard
        echo ""
    fi

    apply_feishu_patch
    echo ""

    install_default_skills
    echo ""

    apply_basic_config
    echo ""

    cleanup_stale_config
    echo ""

    verify_installation
    echo ""

    # 完成信息
    print_divider
    echo ""
    print_box "安装完成!"
    echo ""
    echo -e "${GREEN}常用命令:${NC}"
    echo "  openclaw gateway start   # 启动服务"
    echo "  openclaw gateway status  # 查看状态"
    echo "  openclaw onboard         # 重新配置"
    echo ""
    echo -e "${CYAN}详细文档: ~/.openclaw/docs/${NC}"
    echo ""
    echo "安装日志: $INSTALL_LOG"
    echo ""
}

# 运行主函数
main "$@"
