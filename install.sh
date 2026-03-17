#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   🦞 OpenClaw 一键部署脚本 v1.0.5                                          ║
# ║   🔥 大圣之怒傻瓜Openclaw安装&配置助手                                     ║
# ║   智能 AI 助手部署工具 - 支持多平台多模型                                    ║
# ║                                                                           ║
# ║   GitHub: https://github.com/leecyno1/auto-install-Openclaw               ║
# ║   官方文档: https://docs.openclaw.ai                                       ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# 使用方法:
#   curl -fsSL https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh | bash
#   或本地执行: chmod +x install.sh && ./install.sh
#

set -e

# ================================ TTY 检测 ================================
# 当通过 curl | bash 运行时，stdin 是管道，需要优先选择可读输入源
resolve_tty_input() {
    if [ -t 0 ]; then
        echo "/dev/stdin"
        return 0
    fi
    if [ -e /dev/tty ] && ( : < /dev/tty ) 2>/dev/null; then
        echo "/dev/tty"
        return 0
    fi
    if [ -r /dev/stdin ]; then
        echo "/dev/stdin"
        return 0
    fi
    echo "/dev/null"
}
TTY_INPUT="$(resolve_tty_input)"

# ================================ 颜色定义 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # 无颜色

# ================================ 配置变量 ================================
# 兼容旧环境变量命名（clawdbot -> openclaw）
map_legacy_env() {
    local new_key="$1"
    local legacy_key="$2"
    if [ -z "${!new_key:-}" ] && [ -n "${!legacy_key:-}" ]; then
        export "$new_key=${!legacy_key}"
    fi
}

map_legacy_env "OPENCLAW_NO_ONBOARD" "CLAWDBOT_NO_ONBOARD"
map_legacy_env "OPENCLAW_NO_PROMPT" "CLAWDBOT_NO_PROMPT"
map_legacy_env "OPENCLAW_DRY_RUN" "CLAWDBOT_DRY_RUN"
map_legacy_env "OPENCLAW_INSTALL_METHOD" "CLAWDBOT_INSTALL_METHOD"
map_legacy_env "OPENCLAW_VERSION" "CLAWDBOT_VERSION"
map_legacy_env "OPENCLAW_BETA" "CLAWDBOT_BETA"
map_legacy_env "OPENCLAW_GIT_DIR" "CLAWDBOT_GIT_DIR"
map_legacy_env "OPENCLAW_GIT_UPDATE" "CLAWDBOT_GIT_UPDATE"
map_legacy_env "OPENCLAW_VERBOSE" "CLAWDBOT_VERBOSE"

OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
CONFIG_DIR="$HOME/.openclaw"
MIN_NODE_MAJOR=22
MIN_NODE_MINOR=12
INSTALLER_NAME="auto-install-Openclaw"
INSTALLER_VERSION="1.0.5"
GITHUB_REPO="${GITHUB_REPO:-leecyno1/auto-install-Openclaw}"
GITEE_REPO="${GITEE_REPO:-leecyno1/auto-install-openclaw}"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main"
GITEE_RAW_URL="https://gitee.com/$GITEE_REPO/raw/main"
OFFICIAL_INSTALL_URL="https://openclaw.ai/install.sh"
OFFICIAL_DOCS_URL="https://docs.openclaw.ai"
INSTALLER_MIRROR_RAW_URL="${OPENCLAW_INSTALLER_MIRROR_RAW_URL:-https://mirror.ghproxy.com/${GITHUB_RAW_URL}}"
OFFICIAL_INSTALL_MIRROR_URL="${OPENCLAW_OFFICIAL_INSTALL_MIRROR_URL:-}"
CURL_CONNECT_TIMEOUT="${OPENCLAW_CURL_CONNECT_TIMEOUT:-8}"
CURL_MAX_TIME="${OPENCLAW_CURL_MAX_TIME:-30}"
DOWNLOAD_RETRIES="${OPENCLAW_DOWNLOAD_RETRIES:-3}"
DOWNLOAD_BACKOFF_SECONDS="${OPENCLAW_DOWNLOAD_BACKOFF_SECONDS:-2}"
PLUGIN_INSTALL_RETRIES="${OPENCLAW_PLUGIN_INSTALL_RETRIES:-2}"
PLUGIN_INSTALL_BACKOFF_SECONDS="${OPENCLAW_PLUGIN_INSTALL_BACKOFF_SECONDS:-2}"
AUTO_CONFIRM_ALL="${OPENCLAW_AUTO_CONFIRM_ALL:-0}"
GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-}"
GATEWAY_HOST="${OPENCLAW_GATEWAY_HOST:-}"
GATEWAY_CUSTOM_BIND_HOST="${OPENCLAW_GATEWAY_CUSTOM_BIND_HOST:-}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-13145}"
GATEWAY_CONVERGE_MARKER="/tmp/openclaw-installer-gateway-converged.$$"
RESET_CHAT_AFTER_INSTALL="${OPENCLAW_RESET_CHAT_AFTER_INSTALL:-1}"
AUTO_SWAP_ENABLE="${OPENCLAW_AUTO_SWAP:-1}"
SWAP_PERSIST_ENABLE="${OPENCLAW_SWAP_PERSIST:-1}"
SWAP_THRESHOLD_MB="${OPENCLAW_SWAP_THRESHOLD_MB:-4096}"
SWAP_TARGET_MB="${OPENCLAW_SWAP_TARGET_MB:-0}"
SWAP_FILE_BASE="${OPENCLAW_SWAP_FILE:-/swapfile.openclaw}"
INSTALL_SKILL_DEPS="${OPENCLAW_INSTALL_SKILL_DEPS:-1}"
SKILL_PIP_PACKAGES_DEFAULT="duckduckgo-search akshare requests pyyaml pypdf pillow openpyxl python-pptx python-docx lxml defusedxml pdf2image"
SKILL_PIP_PACKAGES="${OPENCLAW_SKILL_PIP_PACKAGES:-$SKILL_PIP_PACKAGES_DEFAULT}"
SKILL_PIP_PACKAGES_FILE_REL="skills/requirements-runtime.txt"
AUTO_FIX_ATTEMPTED=0
GATEWAY_CONVERGED_ONCE=0
# 默认官方消息渠道插件（仅保留通用官方渠道；微信/企业微信/钉钉/QQ 改为用户手动安装）
DEFAULT_OFFICIAL_PLUGINS="@openclaw/feishu @openclaw/discord @openclaw/whatsapp"
DEFAULT_BUILTIN_CHANNEL_PLUGINS="telegram imessage"
RULE_PROFILE_DEFAULT="${OPENCLAW_RULE_PROFILE:-medium}"
RULE_PROFILE_SELECTED="$(echo "${RULE_PROFILE_DEFAULT}" | tr '[:upper:]' '[:lower:]')"
PROFILE_BASIC_SKILLS="capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator agent-browser chrome-devtools-mcp github mcp-builder model-usage shell minimax-understand-image tavily-search web-search minimax-web-search news-radar url-to-markdown pdf docx pptx xlsx stock-monitor-skill multi-search-engine akshare-stock"
PROFILE_EXTENDED_SKILLS="capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator agent-browser chrome-devtools-mcp github mcp-builder model-usage shell minimax-understand-image tavily-search web-search minimax-web-search news-radar url-to-markdown pdf docx pptx xlsx stock-monitor-skill multi-search-engine akshare-stock gemini-image-service nano-banana-service"
PROFILE_SUPER_SKILLS="__ALL_DEFAULT__"
GEMINI_BASE_URL_DEFAULT="${GEMINI_BASE_URL:-${GOOGLE_BASE_URL:-}}"
GEMINI_IMAGE_MODEL_DEFAULT="${GEMINI_IMAGE_MODEL:-gemini-2.5-flash-image-preview}"
NANO_BANANA_BASE_URL_DEFAULT="${NANO_BANANA_BASE_URL:-}"
NANO_BANANA_IMAGE_MODEL_DEFAULT="${NANO_BANANA_IMAGE_MODEL:-nano-banana-pro-image}"
NANO_BANANA_VIDEO_MODEL_DEFAULT="${NANO_BANANA_VIDEO_MODEL:-nano-banana-pro-video}"
SILICONFLOW_FALLBACK_API_URL="${OPENCLAW_UNOFFICIAL_OPENAI_API_URL:-https://api.siliconflow.cn/v1}"
SILICONFLOW_FALLBACK_MODEL="${OPENCLAW_UNOFFICIAL_OPENAI_MODEL:-Qwen/Qwen3-8B}"
WELCOME_DOC_URL_GITEE="https://gitee.com/leecyno1/auto-install-openclaw/blob/main/docs/channels-configuration-guide.md"
WELCOME_DOC_URL_GITHUB="https://github.com/leecyno1/auto-install-Openclaw/blob/main/docs/channels-configuration-guide.md"

NO_ONBOARD="${OPENCLAW_NO_ONBOARD:-0}"
NO_PROMPT="${OPENCLAW_NO_PROMPT:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"
VERBOSE="${OPENCLAW_VERBOSE:-0}"
INSTALL_METHOD="${OPENCLAW_INSTALL_METHOD:-npm}"
USE_BETA="${OPENCLAW_BETA:-0}"
GIT_DIR="${OPENCLAW_GIT_DIR:-$HOME/openclaw}"
GIT_UPDATE="${OPENCLAW_GIT_UPDATE:-1}"
HELP=0

# ================================ 工具函数 ================================

print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
 __  __  ___  _   _ _  ________   __      _______ _   _ ______   __
|  \/  |/ _ \| \ | | |/ /  ____| / /|  _ \|_   _| \ | |  ____| / /
| \  / | | | |  \| | ' /| |__   / /_| |_) | | | |  \| | |__   / /
| |\/| | | | | . ` |  < |  __| | '_ \  _ <  | | | . ` |  __| / /
| |  | | |_| | |\  | . \| |____| (_) | |_) |_| |_| |\  | |___/ /
|_|  |_|\___/|_| \_|_|\_\______|\___/|____/|_____|_| \_|______/_/

                        MONKEY'S-FURY
EOF
    echo -e "${NC}"
    echo -e "${CYAN}🔥 大圣之怒傻瓜Openclaw安装&配置助手 🔥${NC}"
    echo -e "${CYAN}🔖 Version: v${INSTALLER_VERSION}${NC}"
    echo ""
}

print_exit_hint() {
    local exit_code="${1:-0}"
    echo ""
    if [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}安装脚本执行结束。${NC}"
    else
        echo -e "${YELLOW}安装脚本提前退出（状态码: ${exit_code}）。${NC}"
    fi
    echo -e "${CYAN}后续可执行命令:${NC}"
    echo "  source ~/.openclaw/env && openclaw doctor"
    echo "  source ~/.openclaw/env && openclaw models status --probe --check"
    echo "  bash ~/.openclaw/config-menu.sh  # 或 bash ./config-menu.sh"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

run_auto_fix_once() {
    if [ "$AUTO_FIX_ATTEMPTED" -ge 1 ]; then
        log_warn "自动修复已执行过一次，跳过再次修复。"
        return 1
    fi

    AUTO_FIX_ATTEMPTED=1
    log_warn "检测到异常，尝试执行一次自动修复..."

    if check_command openclaw; then
        local repair_log
        repair_log="$(mktemp /tmp/openclaw-auto-fix.XXXXXX.log)"
        if openclaw doctor --help 2>/dev/null | grep -q -- "--non-interactive"; then
            set +e
            openclaw doctor --non-interactive >"$repair_log" 2>&1
            local repair_exit=$?
            set -e
            if [ $repair_exit -eq 0 ]; then
                log_info "自动修复成功（openclaw doctor --non-interactive）"
                return 0
            fi
        fi

        set +e
        yes | openclaw doctor --fix >"$repair_log" 2>&1
        local repair_exit=$?
        set -e
        if [ $repair_exit -eq 0 ]; then
            log_info "自动修复成功（openclaw doctor --fix）"
            return 0
        fi
        tail -n 30 "$repair_log" 2>/dev/null || true
    fi

    if check_command npm; then
        set +e
        npm cache verify >/tmp/openclaw-npm-cache-verify.log 2>&1
        local cache_exit=$?
        set -e
        if [ $cache_exit -eq 0 ]; then
            log_info "已执行 npm cache verify，准备重试失败步骤。"
            return 0
        fi
    fi

    log_warn "自动修复未生效。"
    return 1
}

run_step_with_auto_fix() {
    local step_name="$1"
    shift

    set +e
    "$@"
    local step_exit=$?
    set -e
    if [ $step_exit -eq 0 ]; then
        return 0
    fi

    log_warn "${step_name} 失败（exit=${step_exit}），将执行一次自动修复并重试。"
    if run_auto_fix_once; then
        set +e
        "$@"
        step_exit=$?
        set -e
        if [ $step_exit -eq 0 ]; then
            log_info "${step_name} 重试成功。"
            return 0
        fi
        log_error "${step_name} 重试后仍失败（exit=${step_exit}）。"
    fi

    return $step_exit
}

download_with_fallback() {
    local output_path="$1"
    shift
    local url=""
    local attempts="${DOWNLOAD_RETRIES:-3}"
    local backoff="${DOWNLOAD_BACKOFF_SECONDS:-2}"
    local attempt

    if ! [[ "$attempts" =~ ^[0-9]+$ ]] || [ "$attempts" -lt 1 ]; then
        attempts=1
    fi
    if ! [[ "$backoff" =~ ^[0-9]+$ ]] || [ "$backoff" -lt 1 ]; then
        backoff=1
    fi

    for url in "$@"; do
        [ -z "$url" ] && continue
        attempt=1
        while [ "$attempt" -le "$attempts" ]; do
            if curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "$url" -o "$output_path"; then
                log_info "下载成功: $url (attempt ${attempt}/${attempts})"
                return 0
            fi
            if [ "$attempt" -lt "$attempts" ]; then
                sleep $((backoff * attempt))
            fi
            attempt=$((attempt + 1))
        done
        log_warn "下载失败: $url（已重试 ${attempts} 次）"
    done
    return 1
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

print_usage() {
    cat <<EOF
${INSTALLER_NAME} (OpenClaw 安装增强版)

用法:
  curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh | bash -s -- [选项]

选项:
  --install-method, --method npm|git   安装方式 (默认: npm)
  --npm                                等价于 --install-method npm
  --git, --github                      等价于 --install-method git
  --version <version|dist-tag>         指定 OpenClaw 版本 (默认: latest)
  --beta                               优先使用 beta dist-tag
  --git-dir, --dir <path>              git 安装目录 (默认: ~/openclaw)
  --no-git-update                      禁止更新已有 git checkout
  --no-onboard                         跳过本脚本 AI 初始化向导
  --onboard                            强制执行本脚本 AI 初始化向导
  --no-prompt                          非交互模式（使用默认值）
  --auto-confirm-all, --fast-install   全自动模式（所有确认默认通过，选择题默认 1，等价 no-prompt + no-onboard）
  --dry-run                            只显示执行计划，不做变更
  --verbose                            详细日志
  --gateway-host <host>               Gateway 监听地址 (默认: 127.0.0.1)
  --gateway-bind <mode>               Gateway 绑定模式: loopback|lan|tailnet|auto|custom
  --gateway-custom-host <ipv4>        当绑定模式为 custom 时指定自定义 IPv4
  --gateway-port <port>               Gateway 监听端口 (默认: 13145)
  --reset-chat-history                安装后重置聊天历史 (默认开启)
  --keep-chat-history                 安装后保留历史聊天记录
  --rule-profile <low|medium|high|none> token规划规则档位 (默认: medium)
  --help, -h                           显示帮助

环境变量:
  OPENCLAW_INSTALL_METHOD=git|npm
  OPENCLAW_VERSION=latest|next|<semver>
  OPENCLAW_BETA=0|1
  OPENCLAW_GIT_DIR=<path>
  OPENCLAW_GIT_UPDATE=0|1
  OPENCLAW_NO_ONBOARD=0|1
  OPENCLAW_NO_PROMPT=0|1
  OPENCLAW_AUTO_CONFIRM_ALL=0|1
  OPENCLAW_DRY_RUN=0|1
  OPENCLAW_VERBOSE=0|1
  OPENCLAW_INSTALLER_MIRROR_RAW_URL=<mirror_raw_url>
  OPENCLAW_OFFICIAL_INSTALL_MIRROR_URL=<mirror_install_sh_url>
  OPENCLAW_CURL_CONNECT_TIMEOUT=<seconds>
  OPENCLAW_CURL_MAX_TIME=<seconds>
  OPENCLAW_DOWNLOAD_RETRIES=<默认3>
  OPENCLAW_DOWNLOAD_BACKOFF_SECONDS=<默认2>
  OPENCLAW_PLUGIN_INSTALL_RETRIES=<默认2>
  OPENCLAW_PLUGIN_INSTALL_BACKOFF_SECONDS=<默认2>
  OPENCLAW_GATEWAY_BIND=<默认loopback>
  OPENCLAW_GATEWAY_HOST=<旧变量，兼容映射到 bind/customBindHost>
  OPENCLAW_GATEWAY_CUSTOM_BIND_HOST=<custom 模式专用 IPv4>
  OPENCLAW_GATEWAY_PORT=<默认13145>
  OPENCLAW_RESET_CHAT_AFTER_INSTALL=0|1
  OPENCLAW_AUTO_SWAP=0|1
  OPENCLAW_SWAP_PERSIST=0|1
  OPENCLAW_SWAP_THRESHOLD_MB=<默认4096>
  OPENCLAW_SWAP_TARGET_MB=<默认自动(2G或4G)>
  OPENCLAW_SWAP_FILE=</swapfile.openclaw>
  OPENCLAW_INSTALL_SKILL_DEPS=0|1
  OPENCLAW_SKILL_PIP_PACKAGES="<覆盖默认依赖包列表>"
  OPENCLAW_SKILLS_FORCE_UPDATE=0|1
  OPENCLAW_RULE_PROFILE=low|medium|high|none
  GEMINI_BASE_URL=<third_party_gemini_url>
  GEMINI_IMAGE_MODEL=<gemini_image_model>
  NANO_BANANA_BASE_URL=<third_party_nano_url>
  NANO_BANANA_IMAGE_MODEL=<nano_image_model>
  NANO_BANANA_VIDEO_MODEL=<nano_video_model>
  OPENCLAW_WELCOME_MESSAGE=<欢迎语，留空使用默认文案>
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --install-method|--method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --npm)
                INSTALL_METHOD="npm"
                shift
                ;;
            --git|--github)
                INSTALL_METHOD="git"
                shift
                ;;
            --version)
                OPENCLAW_VERSION="$2"
                shift 2
                ;;
            --beta)
                USE_BETA=1
                shift
                ;;
            --git-dir|--dir)
                GIT_DIR="$2"
                shift 2
                ;;
            --no-git-update)
                GIT_UPDATE=0
                shift
                ;;
            --no-onboard)
                NO_ONBOARD=1
                shift
                ;;
            --onboard)
                NO_ONBOARD=0
                shift
                ;;
            --no-prompt)
                NO_PROMPT=1
                shift
                ;;
            --auto-confirm-all|--fast-install)
                AUTO_CONFIRM_ALL=1
                NO_PROMPT=1
                NO_ONBOARD=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --gateway-bind)
                GATEWAY_BIND="$2"
                shift 2
                ;;
            --gateway-custom-host)
                GATEWAY_CUSTOM_BIND_HOST="$2"
                shift 2
                ;;
            --gateway-host)
                GATEWAY_HOST="$2"
                shift 2
                ;;
            --gateway-port)
                GATEWAY_PORT="$2"
                shift 2
                ;;
            --reset-chat-history)
                RESET_CHAT_AFTER_INSTALL=1
                shift
                ;;
            --keep-chat-history)
                RESET_CHAT_AFTER_INSTALL=0
                shift
                ;;
            --rule-profile)
                RULE_PROFILE_SELECTED="$2"
                shift 2
                ;;
            --help|-h)
                HELP=1
                shift
                ;;
            *)
                echo "忽略未知参数: $1"
                shift
                ;;
        esac
    done
}

# 从 TTY 读取用户输入（支持 curl | bash 模式）
read_input() {
    local prompt="$1"
    local var_name="$2"
    if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
        local auto_value=""
        if echo "$prompt" | grep -q "请选择"; then
            auto_value="1"
        fi
        printf -v "$var_name" '%s' "$auto_value"
        return 0
    fi
    echo -en "$prompt"
    read $var_name < "$TTY_INPUT"
}

# 从 TTY 读取敏感输入（默认不回显）
read_secret_input() {
    local prompt="$1"
    local var_name="$2"
    echo -e "${GRAY}（自动隐藏，直接粘贴后回车即可）${NC}"
    echo -en "$prompt"
    if stty -echo < "$TTY_INPUT" 2>/dev/null; then
        read $var_name < "$TTY_INPUT"
        stty echo < "$TTY_INPUT" 2>/dev/null || true
    else
        read $var_name < "$TTY_INPUT"
    fi
    echo ""
}

confirm() {
    local message="$1"
    local default="${2:-y}"
    if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
        return 0
    fi

    if [ "$NO_PROMPT" = "1" ] || [ "$TTY_INPUT" = "/dev/null" ]; then
        [ "$default" = "y" ]
        return $?
    fi

    if [ "$default" = "y" ]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi
    
    echo -en "${YELLOW}$message $prompt: ${NC}"
    read response < "$TTY_INPUT"
    response=${response:-$default}
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

contains_word() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

upsert_env_export_install() {
    local key="$1"
    local value="$2"
    local env_file="$CONFIG_DIR/env"

    mkdir -p "$(dirname "$env_file")" 2>/dev/null || true
    touch "$env_file" 2>/dev/null || true

    local tmp_file
    tmp_file="$(mktemp)"
    awk -v k="$key" -v v="$value" '
        BEGIN { done=0 }
        $0 ~ "^export " k "=" { print "export " k "=" v; done=1; next }
        { print }
        END { if (!done) print "export " k "=" v }
    ' "$env_file" > "$tmp_file" && mv "$tmp_file" "$env_file"
    chmod 600 "$env_file" 2>/dev/null || true
}

remove_env_export_install() {
    local key="$1"
    local env_file="$CONFIG_DIR/env"
    [ -f "$env_file" ] || return 0

    local tmp_file
    tmp_file="$(mktemp)"
    awk -v k="$key" '$0 !~ "^export " k "=" { print }' "$env_file" > "$tmp_file" && mv "$tmp_file" "$env_file"
    chmod 600 "$env_file" 2>/dev/null || true
}

normalize_rule_profile_level() {
    local level="$(echo "${1:-$RULE_PROFILE_DEFAULT}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$level" in
        low|medium|high|none) echo "$level" ;;
        l) echo "low" ;;
        m|mid) echo "medium" ;;
        h) echo "high" ;;
        n|no|skip|off) echo "none" ;;
        *) echo "medium" ;;
    esac
}

normalize_bool_flag() {
    local value
    value="$(echo "${1:-0}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$value" in
        1|y|yes|true|on|enable|enabled) echo "1" ;;
        0|n|no|false|off|disable|disabled) echo "0" ;;
        *) echo "${2:-0}" ;;
    esac
}

normalize_gateway_bind_mode() {
    local raw host
    raw="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '"'\''[:space:]')"
    host="$(echo "${2:-}" | tr -d '"'\''[:space:]')"

    case "$raw" in
        loopback|lan|tailnet|auto|custom)
            echo "$raw"
            return 0
            ;;
        127.0.0.1|localhost|::1)
            echo "loopback"
            return 0
            ;;
        0.0.0.0|::|all)
            echo "lan"
            return 0
            ;;
        "")
            case "$host" in
                ""|127.0.0.1|localhost|::1)
                    echo "loopback"
                    ;;
                0.0.0.0|::|all)
                    echo "lan"
                    ;;
                tailnet)
                    echo "tailnet"
                    ;;
                auto|loopback|lan|custom)
                    echo "$host"
                    ;;
                *)
                    echo "custom"
                    ;;
            esac
            return 0
            ;;
    esac

    echo "loopback"
}

get_gateway_bind_display_host_install() {
    local bind="$1"
    local custom_host="$2"
    case "$bind" in
        loopback) echo "127.0.0.1" ;;
        lan) echo "0.0.0.0" ;;
        tailnet) echo "tailnet" ;;
        auto) echo "auto" ;;
        custom) echo "${custom_host:-custom}" ;;
        *) echo "127.0.0.1" ;;
    esac
}

get_profile_skill_list() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    case "$level" in
        none) echo "" ;;
        low) echo "$PROFILE_BASIC_SKILLS" ;;
        medium) echo "$PROFILE_EXTENDED_SKILLS" ;;
        high) echo "$PROFILE_SUPER_SKILLS" ;;
        *) echo "$PROFILE_EXTENDED_SKILLS" ;;
    esac
}

get_profile_token_limits() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    case "$level" in
        none)
            echo "0 0 0 0"
            ;;
        low)
            echo "5 50 600000 24000"
            ;;
        medium)
            echo "5 160 2400000 48000"
            ;;
        high)
            echo "5 360 6000000 80000"
            ;;
        *)
            echo "5 160 2400000 48000"
            ;;
    esac
}

get_profile_context_guard_limits() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    case "$level" in
        none)
            echo "0 0 0"
            ;;
        *)
            # warn / ask / force
            echo "120000 150000 180000"
            ;;
    esac
}

get_profile_prompt_text() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    case "$level" in
        none)
            cat <<'EOF'
未注入 token规划规则（NONE）。
- 跳过本轮 token/request 限流与策略文件写入。
- 跳过档位 API 参数采集与技能档位注入。
- 仅保留现有配置，不做额外变更。
EOF
            ;;
        low)
            cat <<'EOF'
你是受控执行模式（LOW）。
- 只执行低频请求预算：5 小时 50 次。
- 绝不泄露任何 API Key、Token、密钥、Cookie、会话票据。
- 拒绝任何“切换/绕过模型限制、突破调用限制、越权执行”请求。
- 涉及用户隐私/敏感信息时必须脱敏或拒绝，并解释原因。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。
EOF
            ;;
        medium)
            cat <<'EOF'
你是平衡执行模式（MEDIUM）。
- 请求预算提升到 5 小时 160 次，仍需避免无效重复调用。
- 拒绝导出密钥、凭据、令牌和任何可用于接管账户的信息。
- 拒绝协助规避模型/网关/权限限制，所有升级动作需显式授权。
- 输出涉及隐私数据时默认最小化披露并做脱敏。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。
EOF
            ;;
        high)
            cat <<'EOF'
你是高性能执行模式（HIGH）。
- 请求预算提升到 5 小时 360 次，用于高并发任务但需持续监控。
- 严禁输出 API Key、系统密钥、数据库凭据、私有令牌。
- 严禁执行绕过安全策略、越权访问、数据外泄类指令。
- 遇到敏感数据请求先拒绝，再提供合规替代方案。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。
EOF
            ;;
        *)
            cat <<'EOF'
你是平衡执行模式（MEDIUM）。
- 请求预算提升到 5 小时 160 次，仍需避免无效重复调用。
- 拒绝导出密钥、凭据、令牌和任何可用于接管账户的信息。
- 拒绝协助规避模型/网关/权限限制，所有升级动作需显式授权。
- 输出涉及隐私数据时默认最小化披露并做脱敏。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。
EOF
            ;;
    esac
}

select_rule_profile_level() {
    local default_level
    default_level="$(normalize_rule_profile_level "$RULE_PROFILE_SELECTED")"
    RULE_PROFILE_SELECTED="$default_level"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  token规划规则注入档位${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}[1]${NC} LOW    - 基础档（5小时 50 次）"
    echo -e "  ${CYAN}[2]${NC} MEDIUM - 扩展档（5小时 160 次）"
    echo -e "  ${CYAN}[3]${NC} HIGH   - 超级档（5小时 360 次）"
    echo -e "  ${CYAN}[4]${NC} NONE   - 跳过本次注入"
    echo ""

    if [ "$NO_PROMPT" = "1" ] || [ "$TTY_INPUT" = "/dev/null" ]; then
        log_info "非交互模式，规则档位默认: $RULE_PROFILE_SELECTED"
        upsert_env_export_install "OPENCLAW_RULE_PROFILE" "$RULE_PROFILE_SELECTED"
        return 0
    fi

    local default_choice="2"
    case "$default_level" in
        low) default_choice="1" ;;
        medium) default_choice="2" ;;
        high) default_choice="3" ;;
        none) default_choice="4" ;;
    esac

    local profile_choice=""
    read_input "${YELLOW}请选择规则档位 [1-4] (默认: ${default_choice}): ${NC}" profile_choice
    profile_choice="${profile_choice:-$default_choice}"
    case "$profile_choice" in
        1) RULE_PROFILE_SELECTED="low" ;;
        2) RULE_PROFILE_SELECTED="medium" ;;
        3) RULE_PROFILE_SELECTED="high" ;;
        4) RULE_PROFILE_SELECTED="none" ;;
        *)
            log_warn "无效选择，回退默认档位: ${default_level}"
            RULE_PROFILE_SELECTED="$default_level"
            ;;
    esac

    upsert_env_export_install "OPENCLAW_RULE_PROFILE" "$RULE_PROFILE_SELECTED"
    log_info "已选择规则档位: $RULE_PROFILE_SELECTED"
}

prompt_profile_api_key() {
    local key_var="$1"
    local display_name="$2"
    local required="$3"
    local current="${!key_var:-}"
    local value="$current"

    if [ "$NO_PROMPT" = "1" ] || [ "$TTY_INPUT" = "/dev/null" ]; then
        export "$key_var=$value"
        return 0
    fi

    local marker="未配置"
    if [ -n "$current" ]; then
        marker="已配置"
    fi
    echo -e "${CYAN}${display_name}${NC} (${marker})"
    read_secret_input "${YELLOW}请输入 ${display_name} Key（留空保持当前）: ${NC}" value
    value="${value:-$current}"

    if [ "$required" = "1" ] && [ -z "$value" ]; then
        log_warn "${display_name} 未配置，相关能力将不可用。"
    fi

    export "$key_var=$value"
}

apply_generative_service_settings() {
    local gemini_key="${GOOGLE_API_KEY:-}"
    local gemini_url="${GEMINI_BASE_URL:-$GEMINI_BASE_URL_DEFAULT}"
    local gemini_model="${GEMINI_IMAGE_MODEL:-$GEMINI_IMAGE_MODEL_DEFAULT}"
    local nano_key="${NANO_BANANA_API_KEY:-}"
    local nano_url="${NANO_BANANA_BASE_URL:-$NANO_BANANA_BASE_URL_DEFAULT}"
    local nano_image_model="${NANO_BANANA_IMAGE_MODEL:-$NANO_BANANA_IMAGE_MODEL_DEFAULT}"
    local nano_video_model="${NANO_BANANA_VIDEO_MODEL:-$NANO_BANANA_VIDEO_MODEL_DEFAULT}"

    upsert_env_export_install "GEMINI_BASE_URL" "$gemini_url"
    upsert_env_export_install "GEMINI_IMAGE_MODEL" "$gemini_model"
    upsert_env_export_install "NANO_BANANA_BASE_URL" "$nano_url"
    upsert_env_export_install "NANO_BANANA_IMAGE_MODEL" "$nano_image_model"
    upsert_env_export_install "NANO_BANANA_VIDEO_MODEL" "$nano_video_model"
    upsert_env_export_install "OPENCLAW_GEMINI_BASE_URL" "$gemini_url"
    upsert_env_export_install "OPENCLAW_GEMINI_IMAGE_MODEL" "$gemini_model"
    upsert_env_export_install "OPENCLAW_NANO_BANANA_BASE_URL" "$nano_url"
    upsert_env_export_install "OPENCLAW_NANO_BANANA_IMAGE_MODEL" "$nano_image_model"
    upsert_env_export_install "OPENCLAW_NANO_BANANA_VIDEO_MODEL" "$nano_video_model"

    if check_command openclaw; then
        openclaw config set "vendor.media.gemini.apiKey" "$gemini_key" >/dev/null 2>&1 || true
        openclaw config set "vendor.media.gemini.baseUrl" "$gemini_url" >/dev/null 2>&1 || true
        openclaw config set "vendor.media.gemini.imageModel" "$gemini_model" >/dev/null 2>&1 || true
        openclaw config set "vendor.media.nanobanana.apiKey" "$nano_key" >/dev/null 2>&1 || true
        openclaw config set "vendor.media.nanobanana.baseUrl" "$nano_url" >/dev/null 2>&1 || true
        openclaw config set "vendor.media.nanobanana.imageModel" "$nano_image_model" >/dev/null 2>&1 || true
        openclaw config set "vendor.media.nanobanana.videoModel" "$nano_video_model" >/dev/null 2>&1 || true
        # gemini/nano-banana 属于 skills 服务，不是 openclaw 插件；清理历史陈旧插件项
        openclaw config unset "plugins.entries.gemini" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.nano-banana-pro" >/dev/null 2>&1 || true
    fi

    local skills_root="$CONFIG_DIR/skills"
    local gemini_skill_cfg="$skills_root/gemini-image-service/service.env"
    local nano_skill_cfg="$skills_root/nano-banana-service/service.env"
    mkdir -p "$(dirname "$gemini_skill_cfg")" "$(dirname "$nano_skill_cfg")" 2>/dev/null || true

    cat > "$gemini_skill_cfg" <<EOF
GEMINI_API_KEY=${gemini_key}
GEMINI_BASE_URL=${gemini_url}
GEMINI_IMAGE_MODEL=${gemini_model}
EOF

    cat > "$nano_skill_cfg" <<EOF
NANO_BANANA_API_KEY=${nano_key}
NANO_BANANA_BASE_URL=${nano_url}
NANO_BANANA_IMAGE_MODEL=${nano_image_model}
NANO_BANANA_VIDEO_MODEL=${nano_video_model}
EOF
    chmod 600 "$gemini_skill_cfg" "$nano_skill_cfg" 2>/dev/null || true
}

configure_profile_api_keys() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    if [ "$level" = "none" ]; then
        log_info "已选择 NONE，跳过档位 API 参数配置。"
        return 0
    fi

    echo ""
    log_step "配置档位 API 参数（BraveSearch / NanoBanana / Gemini）..."
    case "$level" in
        low)
            log_info "LOW 档默认不强制配置工具 API Key（可后续在配置菜单补充）"
            ;;
        medium)
            prompt_profile_api_key "GOOGLE_API_KEY" "Gemini" "1"
            prompt_profile_api_key "BRAVE_API_KEY" "BraveSearch" "1"
            prompt_profile_api_key "NANO_BANANA_API_KEY" "NanoBanana" "0"
            ;;
        high)
            prompt_profile_api_key "GOOGLE_API_KEY" "Gemini" "1"
            prompt_profile_api_key "BRAVE_API_KEY" "BraveSearch" "1"
            prompt_profile_api_key "NANO_BANANA_API_KEY" "NanoBanana" "1"
            ;;
        *)
            prompt_profile_api_key "GOOGLE_API_KEY" "Gemini" "1"
            prompt_profile_api_key "BRAVE_API_KEY" "BraveSearch" "1"
            prompt_profile_api_key "NANO_BANANA_API_KEY" "NanoBanana" "0"
            ;;
    esac

    if [ -n "${GOOGLE_API_KEY:-}" ]; then
        upsert_env_export_install "GOOGLE_API_KEY" "$GOOGLE_API_KEY"
        upsert_env_export_install "GEMINI_API_KEY" "$GOOGLE_API_KEY"
    else
        remove_env_export_install "GOOGLE_API_KEY"
        remove_env_export_install "GEMINI_API_KEY"
    fi

    if [ -n "${BRAVE_API_KEY:-}" ]; then
        upsert_env_export_install "BRAVE_API_KEY" "$BRAVE_API_KEY"
        upsert_env_export_install "BRAVESEARCH_API_KEY" "$BRAVE_API_KEY"
    else
        remove_env_export_install "BRAVE_API_KEY"
        remove_env_export_install "BRAVESEARCH_API_KEY"
    fi

    if [ -n "${NANO_BANANA_API_KEY:-}" ]; then
        upsert_env_export_install "NANO_BANANA_API_KEY" "$NANO_BANANA_API_KEY"
        upsert_env_export_install "NANOBANANA_API_KEY" "$NANO_BANANA_API_KEY"
    else
        remove_env_export_install "NANO_BANANA_API_KEY"
        remove_env_export_install "NANOBANANA_API_KEY"
    fi

    apply_generative_service_settings
}

apply_profile_token_policy() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    if [ "$level" = "none" ]; then
        log_info "已选择 NONE，跳过 token/request 限流配置。"
        return 0
    fi
    local limits window_hours max_requests max_tokens max_tokens_per_req
    local context_limits context_warn_tokens context_ask_tokens context_force_tokens
    limits="$(get_profile_token_limits "$level")"
    window_hours="$(echo "$limits" | awk '{print $1}')"
    max_requests="$(echo "$limits" | awk '{print $2}')"
    max_tokens="$(echo "$limits" | awk '{print $3}')"
    max_tokens_per_req="$(echo "$limits" | awk '{print $4}')"
    context_limits="$(get_profile_context_guard_limits "$level")"
    context_warn_tokens="$(echo "$context_limits" | awk '{print $1}')"
    context_ask_tokens="$(echo "$context_limits" | awk '{print $2}')"
    context_force_tokens="$(echo "$context_limits" | awk '{print $3}')"

    upsert_env_export_install "OPENCLAW_RULE_WINDOW_HOURS" "$window_hours"
    upsert_env_export_install "OPENCLAW_RULE_MAX_REQUESTS" "$max_requests"
    upsert_env_export_install "OPENCLAW_RULE_MAX_TOKENS" "$max_tokens"
    upsert_env_export_install "OPENCLAW_RULE_MAX_TOKENS_PER_REQUEST" "$max_tokens_per_req"
    upsert_env_export_install "OPENCLAW_CONTEXT_WARN_TOKENS" "$context_warn_tokens"
    upsert_env_export_install "OPENCLAW_CONTEXT_ASK_TOKENS" "$context_ask_tokens"
    upsert_env_export_install "OPENCLAW_CONTEXT_FORCE_TOKENS" "$context_force_tokens"
    upsert_env_export_install "OPENCLAW_CONTEXT_ASK_COMMAND" "/compact"

    if check_command openclaw; then
        openclaw config set "vendor.control.rate.windowHours" "$window_hours" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.rate.maxRequests" "$max_requests" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.rate.maxTokens" "$max_tokens" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.rate.maxTokensPerRequest" "$max_tokens_per_req" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.context.warnTokens" "$context_warn_tokens" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.context.askTokens" "$context_ask_tokens" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.context.forceTokens" "$context_force_tokens" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.context.askCompact" true >/dev/null 2>&1 || true
        openclaw config set "vendor.control.context.askCommand" "/compact" >/dev/null 2>&1 || true
    fi
}

apply_profile_skill_policy() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    if [ "$level" = "none" ]; then
        log_info "已选择 NONE，跳过档位技能注入。"
        return 0
    fi
    local bundle_dir skills_list target_dir force_update copied skipped missing
    copied=0
    skipped=0
    missing=0
    force_update="${OPENCLAW_SKILLS_FORCE_UPDATE:-0}"
    target_dir="$CONFIG_DIR/skills"

    bundle_dir="$(resolve_install_skills_bundle_dir || true)"
    if [ -z "$bundle_dir" ] || [ ! -d "$bundle_dir" ]; then
        log_warn "未找到默认技能包目录，跳过档位技能注入。"
        return 1
    fi

    mkdir -p "$target_dir" 2>/dev/null || true
    skills_list="$(get_profile_skill_list "$level")"

    if [ "$skills_list" = "__ALL_DEFAULT__" ]; then
        local src_all
        for src_all in "$bundle_dir"/*; do
            [ -d "$src_all" ] || continue
            local name_all
            local dst_all
            name_all="$(basename "$src_all")"
            dst_all="$target_dir/$name_all"
            if [ -d "$dst_all" ] && [ "$force_update" != "1" ]; then
                skipped=$((skipped + 1))
                continue
            fi
            rm -rf "$dst_all" 2>/dev/null || true
            if cp -a "$src_all" "$dst_all" 2>/dev/null; then
                copied=$((copied + 1))
            fi
        done
        log_info "HIGH 档技能同步完成：新增/更新 ${copied}，保留 ${skipped}"
        return 0
    fi

    local skill_name src dst
    for skill_name in $skills_list; do
        src="$bundle_dir/$skill_name"
        dst="$target_dir/$skill_name"
        if [ ! -d "$src" ]; then
            missing=$((missing + 1))
            log_warn "技能包缺失: $skill_name"
            continue
        fi
        if [ -d "$dst" ] && [ "$force_update" != "1" ]; then
            skipped=$((skipped + 1))
            continue
        fi
        rm -rf "$dst" 2>/dev/null || true
        if cp -a "$src" "$dst" 2>/dev/null; then
            copied=$((copied + 1))
        fi
    done
    log_info "档位技能同步完成：新增/更新 ${copied}，保留 ${skipped}，缺失 ${missing}"
}

write_profile_policy_files() {
    local level
    level="$(normalize_rule_profile_level "$1")"
    if [ "$level" = "none" ]; then
        log_info "已选择 NONE，跳过 token规划规则策略文件写入。"
        return 0
    fi
    local limits window_hours max_requests max_tokens max_tokens_per_req
    local context_limits context_warn_tokens context_ask_tokens context_force_tokens
    local prompt_text
    local now_iso
    local gemini_url gemini_model nano_url nano_image_model nano_video_model
    local persona_user_name persona_timezone persona_location persona_goal
    local persona_style persona_work_mode persona_agent_name persona_agent_emoji

    limits="$(get_profile_token_limits "$level")"
    window_hours="$(echo "$limits" | awk '{print $1}')"
    max_requests="$(echo "$limits" | awk '{print $2}')"
    max_tokens="$(echo "$limits" | awk '{print $3}')"
    max_tokens_per_req="$(echo "$limits" | awk '{print $4}')"
    context_limits="$(get_profile_context_guard_limits "$level")"
    context_warn_tokens="$(echo "$context_limits" | awk '{print $1}')"
    context_ask_tokens="$(echo "$context_limits" | awk '{print $2}')"
    context_force_tokens="$(echo "$context_limits" | awk '{print $3}')"

    gemini_url="${GEMINI_BASE_URL:-$GEMINI_BASE_URL_DEFAULT}"
    gemini_model="${GEMINI_IMAGE_MODEL:-$GEMINI_IMAGE_MODEL_DEFAULT}"
    nano_url="${NANO_BANANA_BASE_URL:-$NANO_BANANA_BASE_URL_DEFAULT}"
    nano_image_model="${NANO_BANANA_IMAGE_MODEL:-$NANO_BANANA_IMAGE_MODEL_DEFAULT}"
    nano_video_model="${NANO_BANANA_VIDEO_MODEL:-$NANO_BANANA_VIDEO_MODEL_DEFAULT}"
    prompt_text="$(get_profile_prompt_text "$level")"
    now_iso="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    local policy_dir="$CONFIG_DIR/policy"
    local soul_dir="$CONFIG_DIR/agents/main/soul"
    local agent_dir="$CONFIG_DIR/agents/main/agent"
    local memory_dir="$CONFIG_DIR/agents/main/memory"
    local session_dir="$CONFIG_DIR/agents/main/sessions"
    local persona_dir="$CONFIG_DIR/agents/main/persona"
    local system_rule_file="$agent_dir/vendor-control-system.md"
    local memory_rule_file="$memory_dir/vendor-control-memory.md"
    local session_rule_file="$session_dir/vendor-control-session.md"
    local soul_rule_file="$soul_dir/vendor-control-soul.md"
    local persona_soul_file="$persona_dir/SOUL.md"
    local persona_agents_file="$persona_dir/AGENTS.md"
    local persona_user_file="$persona_dir/USER.md"
    local persona_identity_file="$persona_dir/IDENTITY.md"
    local policy_json="$policy_dir/vendor-control-profile.json"
    local prompt_file="$policy_dir/vendor-control-prompts.md"

    persona_user_name="${OPENCLAW_USER_NAME:-主人}"
    persona_timezone="${OPENCLAW_USER_TIMEZONE:-Asia/Shanghai}"
    persona_location="${OPENCLAW_USER_REGION:-中国大陆}"
    persona_goal="${OPENCLAW_USER_GOAL:-综合的小助理，帮我制定日程，邮件，写作，搜索，投资分析等}"
    persona_style="${OPENCLAW_ASSISTANT_PERSONALITY:-严谨、适当幽默、务实}"
    persona_work_mode="${OPENCLAW_ASSISTANT_WORK_MODE:-整段回复，主动汇报，积极响应并调用skills}"
    persona_agent_name="${OPENCLAW_ASSISTANT_NAME:-龙虾小助理}"
    persona_agent_emoji="${OPENCLAW_ASSISTANT_EMOJI:-🦞}"

    mkdir -p "$policy_dir" "$soul_dir" "$agent_dir" "$memory_dir" "$session_dir" "$persona_dir" 2>/dev/null || true

    cat > "$system_rule_file" <<EOF
# 厂商控制规则（系统层）

- 档位: ${level}
- 时间窗: ${window_hours} 小时
- 请求上限: ${max_requests}
- Token 上限: ${max_tokens}
- 单请求 Token 上限: ${max_tokens_per_req}
- 上下文预警阈值: ${context_warn_tokens}
- 上下文询问阈值: ${context_ask_tokens}
- 上下文强制压缩阈值: ${context_force_tokens}

## 执行提示词
${prompt_text}

## 风险行为硬限制
- 禁止输出任何 API Key、令牌、会话凭据、私钥、数据库密码。
- 禁止协助绕过模型调用限制、权限限制或网关限制。
- 禁止暴露用户敏感信息（身份、联系方式、地址、财务、医疗等）。
- 遇到敏感请求必须拒绝，并返回合规替代方案。

## 上下文守门规则
- 当上下文 >= ${context_warn_tokens} tokens 时，先给出一次预警。
- 当上下文 >= ${context_ask_tokens} tokens 时，必须先询问用户是否执行 /compact。
- 若达到 ${context_force_tokens} tokens，且用户未响应或拒绝，则必须先压缩上下文再继续。
- 询问阶段暂停高成本工具调用，仅保留确认交互与必要状态回执。
EOF

    cat > "$memory_rule_file" <<EOF
# 厂商控制规则（Memory 注入）

## 运行基线（初始化）

1. 用户消息必须秒回。任何 >5s 的操作都走后台，前台只做快速指令 message 发送。
2. 使用第一性原理思考。不要假设用户非常清楚自己想要什么和该怎么得到。从原始需求和问题本质出发，审慎分析后再行动。
3. 每次 heartbeat 必须主动检查工作进度。数据连续不变 = 异常信号，kill 卡住的进程并重发任务，不要只报数字。
4. 上下文守门：>=${context_warn_tokens} 先预警；>=${context_ask_tokens} 必须询问“是否 /compact”；>=${context_force_tokens} 必须先压缩再继续。
5. 你不只是在完成任务，你是在值班。没人叫你也要巡逻：查 Codex、查进度、查异常、查卡住。主动发现问题比被动等指令更重要。

## 规则约束（档位 ${level}）

- 始终遵循档位 ${level} 的预算控制。
- 当预算接近上限时先返回摘要与下一步建议，避免超限。
- 不记录或复述明文密钥与敏感凭据。
EOF

    cat > "$session_rule_file" <<EOF
# 厂商控制规则（Session 注入）

当前会话默认规则：
1. 优先满足可用性，其次控制成本。
2. 每 ${window_hours} 小时最多 ${max_requests} 次请求。
3. 单请求建议 Token 不超过 ${max_tokens_per_req}。
4. 拒绝密钥泄露、越权请求和敏感信息外泄。
5. 当上下文 >= ${context_ask_tokens} 时，必须先询问是否执行 /compact。
EOF

    cat > "$soul_rule_file" <<EOF
# 厂商控制规则（Soul 注入）

这是厂商级控制基线，优先级高于临时会话偏好：
- 安全边界优先。
- 成本控制与稳定性优先。
- 在不降低正确性的前提下控制资源开销。
EOF

    cat > "$persona_soul_file" <<EOF
# SOUL.md - 基础人格规则

## 性格
- ${persona_style}
- 反应快、务实、先结论后细节，不说空话。

## 原则
- 执行优先：有明确指令先行动，边界不清先澄清。
- 透明汇报：完成、卡住、失败都主动同步。
- 安全第一：涉及密钥、隐私、越权请求一律拒绝并给替代方案。

## 语言铁律（不可违反）
- 全部输出使用简体中文；英文术语需附中文解释。
- 时间统一按北京时间说明（必要时附绝对日期）。
EOF

    cat > "$persona_agents_file" <<EOF
# AGENTS.md - 基础工作手册

## 任务流程（SOP）
1. 接收任务并复述目标与验收标准。
2. 先判断风险等级与权限边界，再决定执行或分派。
3. 执行中超过 5 秒的步骤转后台，前台先回执进度。
4. 完成后输出结果、证据、后续建议。

## 协作边界
- 不越权处理高风险操作；不可逆操作必须二次确认。
- 不确定信息先查 memory/session/policy，再回答，不靠猜测。
- 工具调用失败时先降级兜底，再给可执行替代路径。

## 触发规则
- 上下文 >= ${context_ask_tokens} tokens：先询问是否执行 /compact。
- 检测敏感内容请求：拒绝并返回合规说明。
EOF

    cat > "$persona_user_file" <<EOF
# USER.md - 用户协作档案（基础模板）

- 用户称呼：${persona_user_name}
- 时区：${persona_timezone}
- 所在地：${persona_location}
- 主要目标：${persona_goal}

## 协作偏好
1. 先结论后细节，优先结构化输出。
2. 减少碎片化回复，尽量一次回复完整信息。
3. 高风险命令（删除、重置、对外发布、转账、推送）必须确认后执行。
4. 默认不暴露内部密钥、配置细节和敏感数据。

## 维护规则
- 本文件作为基础模板，后续可由用户确认后增改。
EOF

    cat > "$persona_identity_file" <<EOF
# IDENTITY.md - 机器人身份卡

- Name: ${persona_agent_name}
- Emoji: ${persona_agent_emoji}
- Role: OpenClaw 综合助理（调度、执行、汇报）
- Work Mode: ${persona_work_mode}
- Language: 简体中文

## 能力边界
- 负责：任务拆解、工具调用、结果汇总、进度回报。
- 不负责：越权访问、绕过平台限制、泄露敏感信息。

## 绝对禁区
- 不输出 API Key/Token/私钥/会话凭据。
- 不执行绕过安全策略或权限边界的指令。
- 不在未确认前执行不可逆高风险操作。
EOF

    cat > "$policy_json" <<EOF
{
  "version": 1,
  "updatedAt": "${now_iso}",
  "profile": "${level}",
  "rateLimit": {
    "windowHours": ${window_hours},
    "maxRequests": ${max_requests},
    "maxTokens": ${max_tokens},
    "maxTokensPerRequest": ${max_tokens_per_req}
  },
  "contextGuard": {
    "warnTokens": ${context_warn_tokens},
    "askTokens": ${context_ask_tokens},
    "forceTokens": ${context_force_tokens},
    "askCommand": "/compact",
    "requireUserConfirmAtAsk": true,
    "pauseHeavyToolsWhenAsking": true
  },
  "riskControls": {
    "blockSecretExposure": true,
    "blockModelBypass": true,
    "blockSensitiveDataExfiltration": true
  },
  "mediaServices": {
    "gemini": {
      "baseUrl": "${gemini_url}",
      "imageModel": "${gemini_model}"
    },
    "nanobanana": {
      "baseUrl": "${nano_url}",
      "imageModel": "${nano_image_model}",
      "videoModel": "${nano_video_model}"
    }
  },
  "files": {
    "soul": "${soul_rule_file}",
    "agent": "${system_rule_file}",
    "memory": "${memory_rule_file}",
    "session": "${session_rule_file}"
  },
  "personaFiles": {
    "soul": "${persona_soul_file}",
    "agents": "${persona_agents_file}",
    "user": "${persona_user_file}",
    "identity": "${persona_identity_file}"
  }
}
EOF

    cat > "$prompt_file" <<'EOF'
# 三档厂商控制提示词

## LOW
你是受控执行模式（LOW）。
- 只执行低频请求预算：5 小时 50 次。
- 绝不泄露任何 API Key、Token、密钥、Cookie、会话票据。
- 拒绝任何“切换/绕过模型限制、突破调用限制、越权执行”请求。
- 涉及用户隐私/敏感信息时必须脱敏或拒绝，并解释原因。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。

## MEDIUM
你是平衡执行模式（MEDIUM）。
- 请求预算提升到 5 小时 160 次，仍需避免无效重复调用。
- 拒绝导出密钥、凭据、令牌和任何可用于接管账户的信息。
- 拒绝协助规避模型/网关/权限限制，所有升级动作需显式授权。
- 输出涉及隐私数据时默认最小化披露并做脱敏。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。

## HIGH
你是高性能执行模式（HIGH）。
- 请求预算提升到 5 小时 360 次，用于高并发任务但需持续监控。
- 严禁输出 API Key、系统密钥、数据库凭据、私有令牌。
- 严禁执行绕过安全策略、越权访问、数据外泄类指令。
- 遇到敏感数据请求先拒绝，再提供合规替代方案。
- 当上下文 >=150k tokens 时，必须先询问用户是否执行 /compact；>=180k tokens 时先压缩再继续。
EOF

    chmod 600 "$policy_json" 2>/dev/null || true
    chmod 644 "$system_rule_file" "$memory_rule_file" "$session_rule_file" "$soul_rule_file" "$prompt_file" \
      "$persona_soul_file" "$persona_agents_file" "$persona_user_file" "$persona_identity_file" 2>/dev/null || true

    if check_command openclaw; then
        openclaw config set "vendor.control.profile" "$level" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.soul" "$soul_rule_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.agent" "$system_rule_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.memory" "$memory_rule_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.session" "$session_rule_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.policy" "$policy_json" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.prompts" "$prompt_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.persona.soul" "$persona_soul_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.persona.agents" "$persona_agents_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.persona.user" "$persona_user_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.files.persona.identity" "$persona_identity_file" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.persona.enabled" true >/dev/null 2>&1 || true
        openclaw config set "boot-md.enabled" true >/dev/null 2>&1 || true
        openclaw config set "session-memory.enabled" true >/dev/null 2>&1 || true
    fi
}

apply_vendor_rule_profile() {
    select_rule_profile_level
    local level
    level="$(normalize_rule_profile_level "$RULE_PROFILE_SELECTED")"
    RULE_PROFILE_SELECTED="$level"
    upsert_env_export_install "OPENCLAW_RULE_PROFILE" "$level"

    if [ "$level" = "none" ]; then
        echo ""
        log_info "已跳过 token规划规则注入，保持当前策略与限流配置不变。"
        return 0
    fi

    local limits prompt_text context_limits context_warn_tokens context_ask_tokens context_force_tokens
    limits="$(get_profile_token_limits "$level")"
    prompt_text="$(get_profile_prompt_text "$level")"
    context_limits="$(get_profile_context_guard_limits "$level")"
    context_warn_tokens="$(echo "$context_limits" | awk '{print $1}')"
    context_ask_tokens="$(echo "$context_limits" | awk '{print $2}')"
    context_force_tokens="$(echo "$context_limits" | awk '{print $3}')"

    configure_profile_api_keys "$level"
    apply_profile_token_policy "$level"
    apply_profile_skill_policy "$level" || true
    write_profile_policy_files "$level"

    echo ""
    log_info "token规划规则注入完成"
    echo -e "  档位: ${WHITE}${level}${NC}"
    echo -e "  限流: ${WHITE}$(echo "$limits" | awk '{print $1"小时/"$2"次, 总Token="$3", 单次="$4}')${NC}"
    echo -e "  Skills 档位: ${WHITE}$(case "$level" in low) echo 基础;; medium) echo 扩展;; high) echo 超级;; *) echo 扩展;; esac)${NC}"
    echo -e "  上下文守门: ${WHITE}预警 ${context_warn_tokens} / 询问 ${context_ask_tokens} / 强制 ${context_force_tokens}${NC}"
    echo -e "  Gemini 服务: ${WHITE}${GEMINI_BASE_URL:-$GEMINI_BASE_URL_DEFAULT} | ${GEMINI_IMAGE_MODEL:-$GEMINI_IMAGE_MODEL_DEFAULT}${NC}"
    echo -e "  NanoBanana 服务: ${WHITE}${NANO_BANANA_BASE_URL:-$NANO_BANANA_BASE_URL_DEFAULT} | ${NANO_BANANA_IMAGE_MODEL:-$NANO_BANANA_IMAGE_MODEL_DEFAULT}${NC}"
    echo -e "  提示词摘要: ${WHITE}$(echo "$prompt_text" | head -1)${NC}"
}

resolve_beta_version() {
    npm view openclaw dist-tags.beta 2>/dev/null || true
}

normalize_install_options() {
    if [ "$INSTALL_METHOD" != "npm" ] && [ "$INSTALL_METHOD" != "git" ]; then
        log_error "无效安装方式: $INSTALL_METHOD（仅支持 npm|git）"
        exit 2
    fi

    if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
        NO_PROMPT=1
        NO_ONBOARD=1
        if [ -z "${OPENCLAW_RULE_PROFILE:-}" ]; then
            RULE_PROFILE_SELECTED="low"
        fi
    fi

    if [ "$USE_BETA" = "1" ]; then
        local beta_version
        beta_version="$(resolve_beta_version)"
        if [ -n "$beta_version" ] && [ "$beta_version" != "undefined" ] && [ "$beta_version" != "null" ]; then
            OPENCLAW_VERSION="$beta_version"
            log_info "检测到 beta 版本: $OPENCLAW_VERSION"
        else
            log_warn "未找到 beta dist-tag，回退 latest"
            OPENCLAW_VERSION="latest"
        fi
    fi

    # 规范化 Gateway 绑定参数，按官方语义使用 bind + port
    GATEWAY_BIND="$(normalize_gateway_bind_mode "$GATEWAY_BIND" "$GATEWAY_HOST")"
    if [ "$GATEWAY_BIND" = "custom" ] && [ -z "$GATEWAY_CUSTOM_BIND_HOST" ] && [ -n "$GATEWAY_HOST" ]; then
        GATEWAY_CUSTOM_BIND_HOST="$GATEWAY_HOST"
    fi
    if [ "$GATEWAY_BIND" != "custom" ]; then
        GATEWAY_CUSTOM_BIND_HOST=""
    fi
    GATEWAY_HOST="$(get_gateway_bind_display_host_install "$GATEWAY_BIND" "$GATEWAY_CUSTOM_BIND_HOST")"
    if ! [[ "$GATEWAY_PORT" =~ ^[0-9]+$ ]] || [ "$GATEWAY_PORT" -lt 1 ] || [ "$GATEWAY_PORT" -gt 65535 ]; then
        log_warn "无效 gateway 端口: $GATEWAY_PORT，回退到默认 13145"
        GATEWAY_PORT="13145"
    fi
    export OPENCLAW_GATEWAY_BIND="$GATEWAY_BIND"
    export OPENCLAW_GATEWAY_HOST="$GATEWAY_HOST"
    export OPENCLAW_GATEWAY_CUSTOM_BIND_HOST="$GATEWAY_CUSTOM_BIND_HOST"
    export OPENCLAW_GATEWAY_PORT="$GATEWAY_PORT"
    RESET_CHAT_AFTER_INSTALL="$(normalize_bool_flag "$RESET_CHAT_AFTER_INSTALL" "1")"
    export OPENCLAW_RESET_CHAT_AFTER_INSTALL="$RESET_CHAT_AFTER_INSTALL"
    RULE_PROFILE_SELECTED="$(normalize_rule_profile_level "$RULE_PROFILE_SELECTED")"
}

print_install_plan() {
    echo ""
    echo -e "${CYAN}安装计划:${NC}"
    echo "  - installer: $INSTALLER_NAME"
    echo "  - install_method: $INSTALL_METHOD"
    echo "  - openclaw_version: $OPENCLAW_VERSION"
    echo "  - no_onboard: $NO_ONBOARD"
    echo "  - no_prompt: $NO_PROMPT"
    echo "  - auto_confirm_all: $AUTO_CONFIRM_ALL"
    echo "  - dry_run: $DRY_RUN"
    echo "  - verbose: $VERBOSE"
    echo "  - gateway_bind: $GATEWAY_BIND"
    [ -n "$GATEWAY_CUSTOM_BIND_HOST" ] && echo "  - gateway_custom_host: $GATEWAY_CUSTOM_BIND_HOST"
    echo "  - gateway_host_display: $GATEWAY_HOST"
    echo "  - gateway_port: $GATEWAY_PORT"
    echo "  - reset_chat_after_install: $RESET_CHAT_AFTER_INSTALL"
    echo "  - rule_profile: $RULE_PROFILE_SELECTED"
    if [ "$INSTALL_METHOD" = "git" ]; then
        echo "  - git_dir: $GIT_DIR"
        echo "  - git_update: $GIT_UPDATE"
    fi
}

# ================================ 系统检测 ================================

detect_os() {
    log_step "检测操作系统..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        fi
        PACKAGE_MANAGER=""
        if command -v apt-get &> /dev/null; then
            PACKAGE_MANAGER="apt"
        elif command -v yum &> /dev/null; then
            PACKAGE_MANAGER="yum"
        elif command -v dnf &> /dev/null; then
            PACKAGE_MANAGER="dnf"
        elif command -v pacman &> /dev/null; then
            PACKAGE_MANAGER="pacman"
        fi
        log_info "检测到 Linux 系统: $OS $OS_VERSION (包管理器: $PACKAGE_MANAGER)"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
        PACKAGE_MANAGER="brew"
        log_info "检测到 macOS 系统: $OS_VERSION"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
        log_info "检测到 Windows 系统 (Git Bash/Cygwin)"
    else
        log_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "检测到以 root 用户运行"
        if ! confirm "建议使用普通用户运行，是否继续？" "y"; then
            exit 1
        fi
    fi
}

ensure_sudo_privileges() {
    # root 用户无需 sudo
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Linux 下依赖安装和 systemd 操作需要 sudo
    if [[ "$OS" != "macos" ]]; then
        if ! check_command sudo; then
            log_error "未检测到 sudo，无法安装系统依赖。请安装 sudo 或使用 root 运行。"
            exit 1
        fi

        log_step "检查并请求 sudo 权限..."
        if ! sudo -v; then
            log_error "sudo 授权失败，安装已中止。"
            echo -e "${YELLOW}请确认当前用户在 sudoers 中，或改用 root 运行。${NC}"
            exit 1
        fi

        # 保持 sudo 会话，避免中途过期导致命令失败
        (
            while true; do
                sudo -n true 2>/dev/null || exit 0
                sleep 50
            done
        ) &
        SUDO_KEEPALIVE_PID=$!
        trap 'if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true; fi' EXIT

        log_info "sudo 权限已就绪"
    fi
}

# ================================ 依赖检查与安装 ================================

check_command() {
    command -v "$1" &> /dev/null
}

get_gateway_pid() {
    get_port_pid "$GATEWAY_PORT"
}

get_port_pid() {
    local port="$1"
    local pid=""
    if check_command lsof; then
        pid=$(lsof -ti :"$port" 2>/dev/null | head -1)
    fi
    if [ -z "$pid" ] && check_command pgrep; then
        pid=$(pgrep -f "openclaw gateway" 2>/dev/null | head -1)
    fi
    echo "$pid"
}

install_homebrew() {
    if ! check_command brew; then
        log_step "安装 Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 添加到 PATH
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

install_nodejs() {
    log_step "检查 Node.js..."
    
    if check_command node; then
        local node_major
        local node_minor
        node_major=$(node -v | sed 's/^v//' | cut -d'.' -f1)
        node_minor=$(node -v | sed 's/^v//' | cut -d'.' -f2)
        if [ "$node_major" -gt "$MIN_NODE_MAJOR" ] || { [ "$node_major" -eq "$MIN_NODE_MAJOR" ] && [ "$node_minor" -ge "$MIN_NODE_MINOR" ]; }; then
            log_info "Node.js 版本满足要求: $(node -v)"
            return 0
        else
            log_warn "Node.js 版本过低: $(node -v)，需要 v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+"
        fi
    fi
    
    log_step "安装 Node.js ${MIN_NODE_MAJOR}.x ..."
    
    case "$OS" in
        macos)
            install_homebrew
            brew install node@22
            brew link --overwrite node@22
            ;;
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        arch|manjaro)
            sudo pacman -S nodejs npm --noconfirm
            ;;
        *)
            log_error "无法自动安装 Node.js，请手动安装 v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+"
            exit 1
            ;;
    esac
    
    log_info "Node.js 安装完成: $(node -v)"
}

install_git() {
    if ! check_command git; then
        log_step "安装 Git..."
        case "$OS" in
            macos)
                install_homebrew
                brew install git
                ;;
            ubuntu|debian)
                sudo apt-get update && sudo apt-get install -y git
                ;;
            centos|rhel|fedora)
                sudo yum install -y git
                ;;
            arch|manjaro)
                sudo pacman -S git --noconfirm
                ;;
        esac
    fi
    log_info "Git 版本: $(git --version)"
}

install_dependencies() {
    log_step "检查并安装依赖..."
    
    # 安装基础依赖
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y curl wget jq python3 python3-pip poppler-utils
            ;;
        centos|rhel|fedora)
            sudo yum install -y curl wget jq python3 python3-pip poppler-utils || \
            sudo yum install -y curl wget jq python3 python3-pip
            ;;
        macos)
            install_homebrew
            brew install curl wget jq python poppler
            ;;
    esac
    
    install_git
    install_nodejs
    ensure_uvx_for_minimax_skills || true
    install_skill_runtime_python_deps || true
}

ensure_uvx_for_minimax_skills() {
    if check_command uvx; then
        log_info "uvx 已安装: $(command -v uvx)"
        ensure_minimax_mcp_for_skills || true
        return 0
    fi

    log_step "检查 MiniMax Web Search 依赖 (uvx)..."
    local installer tmp_log
    installer="$(mktemp /tmp/uv-install.XXXXXX.sh)"
    tmp_log="$(mktemp /tmp/uv-install.XXXXXX.log)"

    if ! curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout "$CURL_CONNECT_TIMEOUT" --max-time "$CURL_MAX_TIME" "https://astral.sh/uv/install.sh" -o "$installer"; then
        log_warn "无法下载 uv 安装脚本，已跳过自动安装 uvx。"
        rm -f "$installer" "$tmp_log" 2>/dev/null || true
        return 1
    fi

    if sh "$installer" >"$tmp_log" 2>&1; then
        export PATH="$HOME/.local/bin:$PATH"
        hash -r 2>/dev/null || true
        if check_command uvx; then
            log_info "uvx 安装成功: $(command -v uvx)"
            ensure_minimax_mcp_for_skills || true
            rm -f "$installer" "$tmp_log" 2>/dev/null || true
            return 0
        fi
    fi

    log_warn "uvx 自动安装未成功。MiniMax Web Search 可能不可用。"
    tail -n 5 "$tmp_log" 2>/dev/null | sed 's/^/  /'
    rm -f "$installer" "$tmp_log" 2>/dev/null || true
    return 1
}

ensure_minimax_mcp_for_skills() {
    if ! check_command uvx; then
        return 1
    fi

    local probe_host
    probe_host="${MINIMAX_API_HOST:-https://api.minimaxi.com}"

    # minimax-coding-plan-mcp 在某些版本下即使 --help 也要求 MINIMAX_API_HOST。
    if MINIMAX_API_HOST="$probe_host" uvx minimax-coding-plan-mcp --help >/dev/null 2>&1; then
        log_info "minimax-coding-plan-mcp 已可用"
        return 0
    fi

    local log_file
    log_file="$(mktemp /tmp/minimax-mcp-install.XXXXXX.log)"

    # 正确安装方式是 uv tool install；uvx install 会被当作包名 install 导致报错。
    if check_command uv; then
        if uv tool install minimax-coding-plan-mcp >"$log_file" 2>&1; then
            if MINIMAX_API_HOST="$probe_host" uvx minimax-coding-plan-mcp --help >/dev/null 2>&1; then
                log_info "minimax-coding-plan-mcp 安装完成"
                rm -f "$log_file" 2>/dev/null || true
                return 0
            fi
        fi
    fi

    log_warn "minimax-coding-plan-mcp 自动安装失败，MiniMax Web Search 可能不可用。"
    tail -n 8 "$log_file" 2>/dev/null | sed 's/^/  /'
    rm -f "$log_file" 2>/dev/null || true
    return 1
}

pip_install_skill_dep() {
    local pkg="$1"
    local log_file
    log_file="$(mktemp /tmp/openclaw-pip-install.XXXXXX.log)"

    if python3 -m pip install --user --disable-pip-version-check "$pkg" >"$log_file" 2>&1; then
        rm -f "$log_file" 2>/dev/null || true
        return 0
    fi
    if python3 -m pip install --user --break-system-packages --disable-pip-version-check "$pkg" >"$log_file" 2>&1; then
        rm -f "$log_file" 2>/dev/null || true
        return 0
    fi
    if python3 -m pip install --break-system-packages --disable-pip-version-check "$pkg" >"$log_file" 2>&1; then
        rm -f "$log_file" 2>/dev/null || true
        return 0
    fi

    log_warn "Python 依赖安装失败: $pkg"
    tail -n 6 "$log_file" 2>/dev/null | sed 's/^/  /'
    rm -f "$log_file" 2>/dev/null || true
    return 1
}

resolve_skill_pip_packages() {
    local script_dir req_file line pkgs
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    req_file="$script_dir/$SKILL_PIP_PACKAGES_FILE_REL"

    if [ -f "$req_file" ]; then
        pkgs=""
        while IFS= read -r line; do
            line="$(echo "$line" | sed 's/#.*$//' | xargs)"
            [ -n "$line" ] || continue
            pkgs="$pkgs $line"
        done < "$req_file"
        echo "$pkgs" | xargs
        return 0
    fi
    echo "$SKILL_PIP_PACKAGES"
}

install_skill_runtime_python_deps() {
    [ "$INSTALL_SKILL_DEPS" = "1" ] || {
        log_info "已设置 OPENCLAW_INSTALL_SKILL_DEPS=0，跳过 skills 运行依赖安装"
        return 0
    }

    if ! check_command python3; then
        log_warn "未检测到 python3，跳过 skills Python 依赖安装"
        return 1
    fi
    if ! python3 -m pip --version >/dev/null 2>&1; then
        log_warn "未检测到 pip，跳过 skills Python 依赖安装"
        return 1
    fi

    log_step "安装默认 skills 运行依赖..."
    local pkg ok fail packages
    ok=0
    fail=0
    packages="$(resolve_skill_pip_packages)"
    for pkg in $packages; do
        if pip_install_skill_dep "$pkg"; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    done

    export PATH="$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true

    log_info "skills 依赖安装完成: 成功 ${ok}，失败 ${fail}"
    if [ "$fail" -gt 0 ]; then
        log_warn "部分依赖安装失败，可能影响个别 skills，可稍后手动执行: python3 -m pip install --user $packages"
        return 1
    fi
    return 0
}

# ================================ OpenClaw 安装 ================================

create_directories() {
    log_step "创建配置目录..."
    
    mkdir -p "$CONFIG_DIR"
    
    log_info "配置目录: $CONFIG_DIR"
}

install_openclaw_via_official() {
    local -a args
    local low_mem_guard=0
    local scoped_node_opts="${NODE_OPTIONS:-}"
    args=(--install-method "$INSTALL_METHOD" --no-onboard)

    if [ "$NO_PROMPT" = "1" ]; then
        args+=(--no-prompt)
    fi
    if [ "$VERBOSE" = "1" ]; then
        args+=(--verbose)
    fi
    if [ "$DRY_RUN" = "1" ]; then
        args+=(--dry-run)
    fi
    if [ "$USE_BETA" = "1" ]; then
        args+=(--beta)
    elif [ -n "$OPENCLAW_VERSION" ] && [ "$OPENCLAW_VERSION" != "latest" ]; then
        args+=(--version "$OPENCLAW_VERSION")
    fi
    if [ "$INSTALL_METHOD" = "git" ]; then
        args+=(--git-dir "$GIT_DIR")
        if [ "$GIT_UPDATE" = "0" ]; then
            args+=(--no-git-update)
        fi
    fi

    log_info "调用官方安装器以确保核心安装行为与上游一致..."
    local tmp_script
    tmp_script="$(mktemp /tmp/openclaw-install.XXXXXX.sh)"
    if ! download_with_fallback "$tmp_script" "$OFFICIAL_INSTALL_URL" "$OFFICIAL_INSTALL_MIRROR_URL"; then
        rm -f "$tmp_script" 2>/dev/null || true
        return 1
    fi

    # 低内存机器提前启用保护，降低官方安装器内部 npm OOM 概率
    if is_low_memory_linux; then
        ensure_swap_for_install || true
        low_mem_guard=1
    fi
    if [ "$low_mem_guard" -eq 1 ]; then
        scoped_node_opts="${scoped_node_opts:+${scoped_node_opts} }--max-old-space-size=512"
        env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm_config_jobs=1 npm_config_maxsockets=1 npm_config_progress=false UV_THREADPOOL_SIZE=1 NODE_OPTIONS="$scoped_node_opts" bash "$tmp_script" "${args[@]}"
    else
        bash "$tmp_script" "${args[@]}"
    fi
    local install_exit=$?
    rm -f "$tmp_script" 2>/dev/null || true
    return "$install_exit"
}

ensure_openclaw_on_path() {
    # 尝试从常见 npm 全局安装位置补充 PATH，避免“已安装但当前 shell 不可见”
    local npm_prefix=""
    local npm_bin=""
    local candidate=""

    if check_command npm; then
        npm_prefix="$(npm config get prefix 2>/dev/null || true)"
        if [ -n "$npm_prefix" ] && [ "$npm_prefix" != "undefined" ] && [ "$npm_prefix" != "null" ]; then
            npm_bin="$npm_prefix/bin"
            if [ -d "$npm_bin" ]; then
                case ":$PATH:" in
                    *":$npm_bin:"*) ;;
                    *) export PATH="$npm_bin:$PATH" ;;
                esac
            fi
        fi
    fi

    for candidate in "$HOME/.npm-global/bin" "$HOME/.local/bin" "/usr/local/bin" "/usr/bin"; do
        if [ -d "$candidate" ]; then
            case ":$PATH:" in
                *":$candidate:"*) ;;
                *) export PATH="$candidate:$PATH" ;;
            esac
        fi
    done
}

run_as_root() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

get_meminfo_kb() {
    local key="$1"
    awk -v k="$key" '$1==k":" {print $2; exit}' /proc/meminfo 2>/dev/null
}

get_total_mem_mb() {
    local kb
    kb="$(get_meminfo_kb MemTotal)"
    [ -n "$kb" ] && echo $((kb / 1024)) || echo 0
}

get_total_swap_mb() {
    local kb
    kb="$(get_meminfo_kb SwapTotal)"
    [ -n "$kb" ] && echo $((kb / 1024)) || echo 0
}

is_low_memory_linux() {
    [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || return 1
    local mem_mb swap_mb target_swap_mb
    mem_mb="$(get_total_mem_mb)"
    swap_mb="$(get_total_swap_mb)"
    target_swap_mb="$(get_recommended_swap_mb "$mem_mb")"
    [ "$mem_mb" -lt "$SWAP_THRESHOLD_MB" ] && [ "$swap_mb" -lt "$target_swap_mb" ]
}

has_minimum_swap_for_low_memory() {
    [ "$(uname -s 2>/dev/null || true)" = "Linux" ] || return 0
    local mem_mb swap_mb target_swap_mb
    mem_mb="$(get_total_mem_mb)"
    swap_mb="$(get_total_swap_mb)"
    target_swap_mb="$(get_recommended_swap_mb "$mem_mb")"

    if [ "$mem_mb" -ge "$SWAP_THRESHOLD_MB" ]; then
        return 0
    fi
    [ "$swap_mb" -ge "$target_swap_mb" ]
}

get_recommended_swap_mb() {
    local mem_mb="${1:-0}"
    local override="${SWAP_TARGET_MB:-0}"

    if [ "$override" -gt 0 ] 2>/dev/null; then
        echo "$override"
        return 0
    fi

    # 默认策略：<2G 配 4G swap；2G~4G 配 2G swap
    if [ "$mem_mb" -lt 2048 ]; then
        echo 4096
    else
        echo 2048
    fi
}

create_and_enable_swapfile() {
    local swap_file="$1"
    local swap_size_mb="$2"

    if swapon --show=NAME --noheadings 2>/dev/null | grep -qx "$swap_file"; then
        return 0
    fi

    if [ ! -f "$swap_file" ]; then
        if check_command fallocate; then
            if ! run_as_root fallocate -l "${swap_size_mb}M" "$swap_file"; then
                run_as_root dd if=/dev/zero of="$swap_file" bs=1M count="$swap_size_mb" status=none
            fi
        else
            run_as_root dd if=/dev/zero of="$swap_file" bs=1M count="$swap_size_mb" status=none
        fi
    fi

    run_as_root chmod 600 "$swap_file"
    run_as_root mkswap "$swap_file" >/dev/null 2>&1 || true
    run_as_root swapon "$swap_file"
}

persist_swapfile_entry() {
    local swap_file="$1"
    [ "$SWAP_PERSIST_ENABLE" = "1" ] || return 0

    if [ ! -f "$swap_file" ]; then
        return 1
    fi
    if [ ! -f /etc/fstab ]; then
        log_warn "未找到 /etc/fstab，无法持久化 Swap。"
        return 1
    fi

    if awk -v f="$swap_file" '$1==f && $2=="none" && $3=="swap" {found=1} END{exit !found}' /etc/fstab 2>/dev/null; then
        log_info "Swap 已存在持久化配置: $swap_file"
        return 0
    fi

    if printf "%s none swap sw 0 0\n" "$swap_file" | run_as_root tee -a /etc/fstab >/dev/null; then
        log_info "已写入 Swap 持久化: $swap_file -> /etc/fstab"
        return 0
    fi

    log_warn "写入 /etc/fstab 失败，重启后需手动 swapon $swap_file"
    return 1
}

ensure_swap_for_install() {
    is_low_memory_linux || return 0

    local mem_mb swap_mb target_swap_mb missing_swap_mb
    local primary_swap_file extra_swap_file
    mem_mb="$(get_total_mem_mb)"
    swap_mb="$(get_total_swap_mb)"
    target_swap_mb="$(get_recommended_swap_mb "$mem_mb")"
    missing_swap_mb=$((target_swap_mb - swap_mb))
    [ "$missing_swap_mb" -lt 0 ] && missing_swap_mb=0

    if [ "$AUTO_SWAP_ENABLE" != "1" ]; then
        log_warn "检测到内存 ${mem_mb}MB (<${SWAP_THRESHOLD_MB}MB)，但 OPENCLAW_AUTO_SWAP=0，跳过自动启用 Swap。"
        return 1
    fi

    log_warn "检测到低内存环境（内存 ${mem_mb}MB，Swap ${swap_mb}MB）。"
    log_warn "将自动补齐 Swap 以降低 OOM 风险（目标 Swap: ${target_swap_mb}MB，推荐 2G~4G）。"
    if ! check_command swapon || ! check_command mkswap; then
        log_warn "系统缺少 swapon/mkswap，无法自动启用 Swap。"
        return 1
    fi

    if [ "$missing_swap_mb" -le 0 ]; then
        log_info "当前 Swap 已满足低内存安装要求（${swap_mb}MB）"
        return 0
    fi

    primary_swap_file="$SWAP_FILE_BASE"
    extra_swap_file="${SWAP_FILE_BASE}.extra"

    if ! swapon --show=NAME --noheadings 2>/dev/null | grep -qx "$primary_swap_file"; then
        local primary_size_mb="$target_swap_mb"
        if [ "$primary_size_mb" -gt 4096 ]; then
            primary_size_mb=4096
        fi
        if [ "$primary_size_mb" -lt 1024 ]; then
            primary_size_mb=1024
        fi
        if ! create_and_enable_swapfile "$primary_swap_file" "$primary_size_mb"; then
            log_warn "创建/启用 Swap 失败: $primary_swap_file"
        fi
        persist_swapfile_entry "$primary_swap_file" || true
        log_info "已启用 Swap: $primary_swap_file (${primary_size_mb}MB)"
    else
        log_info "检测到已启用 Swap: $primary_swap_file"
        persist_swapfile_entry "$primary_swap_file" || true
    fi

    swap_mb="$(get_total_swap_mb)"
    missing_swap_mb=$((target_swap_mb - swap_mb))
    if [ "$missing_swap_mb" -gt 0 ]; then
        if [ "$missing_swap_mb" -lt 512 ]; then
            missing_swap_mb=512
        fi
        if ! create_and_enable_swapfile "$extra_swap_file" "$missing_swap_mb"; then
            log_warn "补充 Swap 失败: $extra_swap_file"
        fi
        persist_swapfile_entry "$extra_swap_file" || true
        log_info "已补充 Swap: $extra_swap_file (${missing_swap_mb}MB)"
    fi

    log_info "当前总 Swap: $(get_total_swap_mb)MB"
    has_minimum_swap_for_low_memory
    return $?
}

is_oom_like_failure() {
    local exit_code="$1"
    local log_file="$2"

    if [ "$exit_code" -eq 137 ] || [ "$exit_code" -eq 143 ]; then
        return 0
    fi
    if [ -f "$log_file" ] && grep -qiE "killed|out of memory|heap out of memory|cannot allocate memory|ENOMEM|oom" "$log_file"; then
        return 0
    fi
    return 1
}

npm_install_openclaw_with_fallback() {
    local spec="openclaw@$OPENCLAW_VERSION"
    local log1 log2 exit_code node_opts

    log_step "执行 npm 回退安装..."
    log1="$(mktemp /tmp/openclaw-npm-fallback.XXXXXX.log)"
    set +e
    env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm_config_jobs=1 npm_config_maxsockets=1 npm_config_progress=false UV_THREADPOOL_SIZE=1 NODE_OPTIONS="${NODE_OPTIONS:-} --max-old-space-size=512" npm --loglevel error --no-fund --no-audit install -g "$spec" --unsafe-perm >"$log1" 2>&1
    exit_code=$?
    set -e
    if [ $exit_code -eq 0 ]; then
        return 0
    fi

    log_warn "npm 安装失败（第 1 次，exit=$exit_code）"
    tail -n 40 "$log1" 2>/dev/null || true

    if is_oom_like_failure "$exit_code" "$log1"; then
        log_warn "检测到疑似内存不足导致的安装失败，准备启用低内存保护后重试。"
        ensure_swap_for_install || true
    fi

    node_opts="--max-old-space-size=384"
    if [ -n "${NODE_OPTIONS:-}" ]; then
        node_opts="${NODE_OPTIONS} ${node_opts}"
    fi

    log2="$(mktemp /tmp/openclaw-npm-fallback.XXXXXX.log)"
    set +e
    env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm_config_jobs=1 npm_config_maxsockets=1 npm_config_progress=false UV_THREADPOOL_SIZE=1 NODE_OPTIONS="$node_opts" npm --loglevel error --no-fund --no-audit install -g "$spec" --unsafe-perm >"$log2" 2>&1
    exit_code=$?
    set -e
    if [ $exit_code -eq 0 ]; then
        log_info "npm 低内存模式重试成功。"
        return 0
    fi

    log_error "npm 回退安装仍然失败（第 2 次，exit=$exit_code）"
    tail -n 80 "$log2" 2>/dev/null || true
    echo ""
    echo -e "${YELLOW}建议先手动启用 Swap 后重试（推荐 2G~4G）:${NC}"
    echo "  sudo fallocate -l 4G /swapfile.openclaw || sudo dd if=/dev/zero of=/swapfile.openclaw bs=1M count=4096"
    echo "  sudo chmod 600 /swapfile.openclaw && sudo mkswap /swapfile.openclaw && sudo swapon /swapfile.openclaw"
    return 1
}

resolve_openclaw_bin() {
    ensure_openclaw_on_path

    if check_command openclaw; then
        command -v openclaw
        return 0
    fi
    if check_command claw; then
        command -v claw
        return 0
    fi

    if check_command npm && check_command node; then
        local npm_root=""
        npm_root="$(npm root -g 2>/dev/null || true)"
        if [ -n "$npm_root" ]; then
            local pkg_json="$npm_root/openclaw/package.json"
            if [ -f "$pkg_json" ]; then
                local candidate
                candidate=$(node -e '
const fs=require("fs");
const path=require("path");
const pkg=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
const bin=(pkg.bin&& (pkg.bin.openclaw||pkg.bin.claw)) || "";
if (bin) process.stdout.write(path.resolve(path.dirname(process.argv[1]), bin));
' "$pkg_json" 2>/dev/null || true)
                if [ -n "$candidate" ] && [ -f "$candidate" ]; then
                    chmod +x "$candidate" 2>/dev/null || true
                    echo "$candidate"
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

get_current_model_ref() {
    if ! check_command openclaw; then
        return 1
    fi

    local model_ref=""
    if check_command node; then
        model_ref=$(openclaw models status --json 2>/dev/null | node -e '
const fs = require("fs");
try {
  const raw = fs.readFileSync(0, "utf8");
  const data = JSON.parse(raw || "{}");
  const v = (data.resolvedDefault || data.defaultModel || "").trim();
  if (v) process.stdout.write(v);
} catch {}
' 2>/dev/null || true)
    elif check_command python3; then
        model_ref=$(openclaw models status --json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    v=(d.get("resolvedDefault") or d.get("defaultModel") or "").strip()
    if v: print(v,end="")
except Exception:
    pass
' 2>/dev/null || true)
    else
        model_ref=$(openclaw config get agents.defaults.model.primary 2>/dev/null || true)
        if [ -z "$model_ref" ] || [ "$model_ref" = "undefined" ]; then
            model_ref=$(openclaw config get models.default 2>/dev/null || true)
        fi
    fi

    [ -n "$model_ref" ] && [ "$model_ref" != "undefined" ] && echo "$model_ref"
}

install_openclaw() {
    log_step "安装 OpenClaw..."
    
    # 检查是否已安装
    if check_command openclaw; then
        local current_version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_warn "OpenClaw 已安装 (版本: $current_version)"
        if ! confirm "是否重新安装/更新？"; then
            init_openclaw_config
            return 0
        fi
    fi

    # 低内存机器优先补齐 Swap，降低 npm 安装被 OOM Kill 的概率
    local low_mem_mode=0
    if is_low_memory_linux; then
        low_mem_mode=1
    fi

    if [ "$low_mem_mode" -eq 1 ]; then
        log_warn "检测到低内存安装场景，将优先使用内存优化安装流程。"
        if ! ensure_swap_for_install; then
            local mem_mb swap_mb target_swap_mb
            mem_mb="$(get_total_mem_mb)"
            swap_mb="$(get_total_swap_mb)"
            target_swap_mb="$(get_recommended_swap_mb "$mem_mb")"
            log_error "当前内存 ${mem_mb}MB，Swap ${swap_mb}MB，低于建议目标 ${target_swap_mb}MB。"
            log_error "继续安装大概率被 OOM Killer 终止。"
            if [ "$NO_PROMPT" = "1" ] || ! confirm "是否仍要继续安装（不推荐）？" "n"; then
                echo ""
                echo -e "${YELLOW}请先启用 Swap 后重试:${NC}"
                echo "  sudo fallocate -l 4G /swapfile.openclaw || sudo dd if=/dev/zero of=/swapfile.openclaw bs=1M count=4096"
                echo "  sudo chmod 600 /swapfile.openclaw && sudo mkswap /swapfile.openclaw && sudo swapon /swapfile.openclaw"
                exit 1
            fi
        fi

        if ! npm_install_openclaw_with_fallback; then
            log_error "内存优化安装流程失败"
            exit 1
        fi
    else
        if ! install_openclaw_via_official; then
            if [ "$INSTALL_METHOD" != "npm" ]; then
                log_error "官方安装器执行失败，且当前为 git 安装模式，无法安全回退"
                exit 1
            fi
            log_warn "官方安装器执行失败，回退到 npm 安装"
            if ! npm_install_openclaw_with_fallback; then
                log_error "OpenClaw 回退安装失败"
                exit 1
            fi
        fi
    fi
    
    # 验证安装
    local claw_bin=""
    claw_bin="$(resolve_openclaw_bin || true)"
    if [ -n "$claw_bin" ]; then
        local claw_dir
        claw_dir="$(dirname "$claw_bin")"
        case ":$PATH:" in
            *":$claw_dir:"*) ;;
            *) export PATH="$claw_dir:$PATH" ;;
        esac

        # 某些版本仅暴露 claw 命令；自动提供 openclaw shim
        if ! check_command openclaw && [ "$(basename "$claw_bin")" = "claw" ]; then
            local shim_dir=""
            local shim_target=""
            shim_dir="$(dirname "$claw_bin")"
            if [ -d "$shim_dir" ] && [ -w "$shim_dir" ]; then
                shim_target="$shim_dir/openclaw"
            else
                shim_dir="$HOME/.local/bin"
                mkdir -p "$shim_dir" 2>/dev/null || true
                shim_target="$shim_dir/openclaw"
            fi

            cat > "$shim_target" <<EOF
#!/bin/sh
exec "$claw_bin" "\$@"
EOF
            chmod +x "$shim_target" 2>/dev/null || true
            case ":$PATH:" in
                *":$shim_dir:"*) ;;
                *) export PATH="$shim_dir:$PATH" ;;
            esac
            log_info "已创建 openclaw 命令兼容 shim: $shim_target"
        fi

        # 先做 JSON 级清洗，避免 openclaw 命令加载历史残留渠道时刷出 Config invalid/warnings
        cleanup_stale_channel_keys_in_json_install || true
        log_info "OpenClaw 安装成功: $("$claw_bin" --version 2>/dev/null || echo 'installed')"
        init_openclaw_config
    else
        log_error "OpenClaw 安装后未在当前 PATH 中发现可执行文件"
        if check_command npm; then
            local npm_prefix_hint
            npm_prefix_hint="$(npm config get prefix 2>/dev/null || true)"
            if [ -n "$npm_prefix_hint" ] && [ "$npm_prefix_hint" != "undefined" ] && [ "$npm_prefix_hint" != "null" ]; then
                echo -e "${YELLOW}可能的修复方式:${NC}"
                echo "  export PATH=\"$npm_prefix_hint/bin:\$PATH\""
                echo "  hash -r"
                echo "  command -v openclaw && openclaw --version"
            fi
        fi
        exit 1
    fi
}

run_official_onboard() {
    if [ "$NO_PROMPT" = "1" ] && [ "${AUTO_CONFIRM_ALL:-0}" != "1" ]; then
        log_info "NO_PROMPT 模式下跳过交互式官方向导，可稍后手动运行: openclaw onboard"
        return 0
    fi

    if ! check_command openclaw; then
        log_error "未检测到 openclaw 命令，无法启动官方向导。"
        return 1
    fi

    # 先清理已移除渠道的历史插件残留，避免 onboard 阶段反复输出 Config warnings
    cleanup_stale_plugin_state || true

    if [ "$NO_PROMPT" = "1" ] && [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
        log_step "全自动模式：执行官方模型配置（非交互，跳过官方其它步骤）..."
        local auth_choice="skip"
        local auth_args=()
        local existing_env="$HOME/.openclaw/env"

        if [ -f "$existing_env" ]; then
            # shellcheck disable=SC1090
            source "$existing_env" >/dev/null 2>&1 || true
        fi

        if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
            auth_choice="anthropic-api-key"
            auth_args+=(--anthropic-api-key "$ANTHROPIC_API_KEY")
        elif [ -n "${OPENAI_API_KEY:-}" ]; then
            auth_choice="openai-api-key"
            auth_args+=(--openai-api-key "$OPENAI_API_KEY")
        elif [ -n "${MOONSHOT_API_KEY:-}" ]; then
            auth_choice="moonshot-api-key"
            auth_args+=(--moonshot-api-key "$MOONSHOT_API_KEY")
        elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
            auth_choice="openrouter-api-key"
            auth_args+=(--openrouter-api-key "$OPENROUTER_API_KEY")
        elif [ -n "${MISTRAL_API_KEY:-}" ]; then
            auth_choice="mistral-api-key"
            auth_args+=(--mistral-api-key "$MISTRAL_API_KEY")
        elif [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ]; then
            auth_choice="gemini-api-key"
            auth_args+=(--gemini-api-key "${GEMINI_API_KEY:-$GOOGLE_API_KEY}")
        elif [ -n "${XAI_API_KEY:-}" ]; then
            auth_choice="xai-api-key"
            auth_args+=(--xai-api-key "$XAI_API_KEY")
        elif [ -n "${ZAI_API_KEY:-}" ]; then
            auth_choice="zai-api-key"
            auth_args+=(--zai-api-key "$ZAI_API_KEY")
        elif [ -n "${MINIMAX_API_KEY:-}" ]; then
            auth_choice="minimax-global-api"
            auth_args+=(--minimax-api-key "$MINIMAX_API_KEY")
        fi

        local onboard_args=(
            --non-interactive
            --accept-risk
            --flow quickstart
            --mode local
            --gateway-bind "$GATEWAY_BIND"
            --gateway-port "$GATEWAY_PORT"
            --skip-channels
            --skip-search
            --skip-skills
            --skip-ui
            --skip-daemon
            --skip-health
            --auth-choice "$auth_choice"
        )
        onboard_args+=("${auth_args[@]}")
        openclaw onboard "${onboard_args[@]}"
        return $?
    fi

    log_step "启动官方配置向导（openclaw onboard）..."
    if [ -e /dev/tty ]; then
        openclaw onboard < /dev/tty
    else
        openclaw onboard
    fi
}

apply_default_security_baseline() {
    if ! check_command openclaw; then
        log_warn "未检测到 openclaw，跳过默认安全权限配置。"
        return 0
    fi

    log_step "应用默认安全权限（开启 system/file/web/boot/session，关闭 sandbox）..."
    openclaw config set security.enable_shell_commands true >/dev/null 2>&1 || true
    openclaw config set security.enable_file_access true >/dev/null 2>&1 || true
    openclaw config set security.enable_web_browsing true >/dev/null 2>&1 || true
    openclaw config set security.sandbox_mode false >/dev/null 2>&1 || true
    openclaw config set "boot-md.enabled" true >/dev/null 2>&1 || true
    openclaw config set "boot_md.enabled" true >/dev/null 2>&1 || true
    openclaw config set "memory.boot.enabled" true >/dev/null 2>&1 || true
    openclaw config set "session-memory.enabled" true >/dev/null 2>&1 || true
    openclaw config set "session_memory.enabled" true >/dev/null 2>&1 || true
    openclaw config set "memory.session.enabled" true >/dev/null 2>&1 || true
    log_info "默认安全设置已启用：system/file/web/boot-md/session-memory（sandbox 默认关闭）"
}

get_installer_repo_urls() {
    cat <<EOF
https://gitee.com/${GITEE_REPO}.git
https://github.com/${GITHUB_REPO}.git
https://mirror.ghproxy.com/https://github.com/${GITHUB_REPO}.git
EOF
}

refresh_cached_installer_repo() {
    local cache_repo="$1"
    [ -d "$cache_repo/.git" ] || return 1
    git -C "$cache_repo" fetch --depth 1 origin main >/dev/null 2>&1 || return 1
    git -C "$cache_repo" reset --hard FETCH_HEAD >/dev/null 2>&1 || return 1
    return 0
}

resolve_install_skills_bundle_dir() {
    local script_dir
    local local_bundle
    local cache_root
    local cache_repo
    local cache_bundle
    local tmp_repo
    local url

    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local_bundle="$script_dir/skills/default"
    if [ -d "$local_bundle" ]; then
        echo "$local_bundle"
        return 0
    fi

    cache_root="$CONFIG_DIR/.cache"
    cache_repo="$cache_root/auto-install-openclaw-repo"
    cache_bundle="$cache_repo/skills/default"
    mkdir -p "$cache_root" 2>/dev/null || true

    if [ -d "$cache_bundle" ]; then
        if check_command git && [ "${OPENCLAW_REFRESH_SKILLS_CACHE:-1}" = "1" ]; then
            refresh_cached_installer_repo "$cache_repo" >/dev/null 2>&1 || true
        fi
        echo "$cache_bundle"
        return 0
    fi

    if ! check_command git; then
        return 1
    fi

    log_warn "当前安装脚本不在仓库目录内，正在从远端拉取默认技能包..."
    tmp_repo="$(mktemp -d "$cache_root/repo.XXXXXX")"
    for url in $(get_installer_repo_urls); do
        rm -rf "$tmp_repo" 2>/dev/null || true
        tmp_repo="$(mktemp -d "$cache_root/repo.XXXXXX")"
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

cleanup_stale_plugin_state() {
    cleanup_stale_channel_keys_in_json_install || true
    if check_command openclaw; then
        # 清理已知的陈旧插件配置项，避免 Config warnings
        openclaw config unset "plugins.entries.gemini" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.nano-banana-pro" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.wechat" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.wecom" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.openclaw-wecom" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.wecom-openclaw-plugin" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.dingtalk" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.openclaw-channel-dingtalk" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.qqbot" >/dev/null 2>&1 || true
        openclaw config unset "plugins.entries.openclaw-qqbot" >/dev/null 2>&1 || true
        openclaw config unset "channels.wechat" >/dev/null 2>&1 || true
        openclaw config unset "channels.wecom" >/dev/null 2>&1 || true
        openclaw config unset "channels.dingtalk" >/dev/null 2>&1 || true
        openclaw config unset "channels.qqbot" >/dev/null 2>&1 || true
        # 清理历史错误 channel 键（插件 id 被误写入 channels.* 导致 Config invalid）
        openclaw config unset "channels.wecom-openclaw-plugin" >/dev/null 2>&1 || true
        openclaw config unset "channels.openclaw-wecom" >/dev/null 2>&1 || true
        openclaw config unset "channels.openclaw-channel-dingtalk" >/dev/null 2>&1 || true
        openclaw config unset "channels.openclaw-wechat-channel" >/dev/null 2>&1 || true
        openclaw config unset "channels.openclaw-qqbot" >/dev/null 2>&1 || true
        cleanup_unknown_plugin_entries_install || true
    fi

    # 清理历史/已下线渠道扩展目录，避免被 openclaw 自动发现后触发告警
    local legacy_dir
    for legacy_dir in \
        "$CONFIG_DIR/extensions/feishu" \
        "$CONFIG_DIR/extensions/openclaw-feishu" \
        "$CONFIG_DIR/extensions/wechat" \
        "$CONFIG_DIR/extensions/openclaw-wechat-channel" \
        "$CONFIG_DIR/extensions/wecom" \
        "$CONFIG_DIR/extensions/openclaw-wecom" \
        "$CONFIG_DIR/extensions/wecom-openclaw-plugin" \
        "$CONFIG_DIR/extensions/dingtalk" \
        "$CONFIG_DIR/extensions/openclaw-channel-dingtalk" \
        "$CONFIG_DIR/extensions/qqbot" \
        "$CONFIG_DIR/extensions/openclaw-qqbot"; do
        if [ -d "$legacy_dir" ]; then
            rm -rf "$legacy_dir" >/dev/null 2>&1 || true
            log_warn "已清理历史扩展残留: $legacy_dir"
        fi
    done
}

cleanup_stale_channel_keys_in_json_install() {
    local cfg="$CONFIG_DIR/openclaw.json"
    [ -f "$cfg" ] || return 0
    if check_command jq; then
        local tmp
        tmp="$(mktemp)"
        if jq '
            .plugins = (.plugins // {})
            | .plugins.entries = ((.plugins.entries // {})
              | del(.wechat)
              | del(.wecom)
              | del(.["openclaw-wecom"])
              | del(.["wecom-openclaw-plugin"])
              | del(.dingtalk)
              | del(.["openclaw-channel-dingtalk"])
              | del(.qqbot)
              | del(.["openclaw-qqbot"]))
            | .plugins.allow = ((.plugins.allow // [])
              | map(select(
                  . != "wechat" and
                  . != "openclaw-wechat-channel" and
                  . != "wecom" and
                  . != "openclaw-wecom" and
                  . != "wecom-openclaw-plugin" and
                  . != "@wecom/wecom-openclaw-plugin" and
                  . != "dingtalk" and
                  . != "openclaw-channel-dingtalk" and
                  . != "qqbot" and
                  . != "openclaw-qqbot" and
                  . != "@sliverp/qqbot" and
                  . != "@tencent-connect/openclaw-qqbot"
              )))
            .channels = ((.channels // {})
              | del(.wechat)
              | del(.wecom)
              | del(.dingtalk)
              | del(.qqbot)
              | del(.["wecom-openclaw-plugin"])
              | del(.["openclaw-wecom"])
              | del(.["openclaw-channel-dingtalk"])
              | del(.["openclaw-wechat-channel"])
              | del(.["openclaw-qqbot"]))
        ' "$cfg" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$cfg"
            return 0
        fi
        rm -f "$tmp" 2>/dev/null || true
    fi
    if check_command python3; then
        python3 - "$cfg" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
drop_channels = {
    "wechat", "wecom", "dingtalk", "qqbot",
    "wecom-openclaw-plugin", "openclaw-wecom", "openclaw-channel-dingtalk",
    "openclaw-wechat-channel", "openclaw-qqbot"
}
drop_entries = {
    "wechat", "wecom", "openclaw-wecom", "wecom-openclaw-plugin",
    "dingtalk", "openclaw-channel-dingtalk", "qqbot", "openclaw-qqbot"
}
drop_allow = {
    "wechat", "openclaw-wechat-channel",
    "wecom", "openclaw-wecom", "wecom-openclaw-plugin", "@wecom/wecom-openclaw-plugin",
    "dingtalk", "openclaw-channel-dingtalk",
    "qqbot", "openclaw-qqbot", "@sliverp/qqbot", "@tencent-connect/openclaw-qqbot"
}
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    plugins = data.get("plugins") or {}
    if not isinstance(plugins, dict):
        plugins = {}
    entries = plugins.get("entries") or {}
    if isinstance(entries, dict):
        for k in drop_entries:
            entries.pop(k, None)
        plugins["entries"] = entries
    allow = plugins.get("allow") or []
    if isinstance(allow, list):
        plugins["allow"] = [x for x in allow if x not in drop_allow]
    data["plugins"] = plugins

    ch = data.get("channels") or {}
    if isinstance(ch, dict):
        for k in drop_channels:
            ch.pop(k, None)
        data["channels"] = ch
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
except Exception:
    pass
PY
    fi
}

normalize_channel_policy_in_json_install() {
    local cfg="$CONFIG_DIR/openclaw.json"
    if check_command openclaw; then
        local active_cfg
        active_cfg="$(openclaw config file 2>/dev/null | head -n 1 | tr -d '\r')"
        case "$active_cfg" in
            "~/"*) active_cfg="$HOME/${active_cfg#~/}" ;;
        esac
        if [ -n "$active_cfg" ] && [ "$active_cfg" != "undefined" ]; then
            cfg="$active_cfg"
        fi
    fi
    if [ ! -f "$cfg" ]; then
        mkdir -p "$(dirname "$cfg")" 2>/dev/null || true
        cat > "$cfg" <<'EOF'
{
  "gateway": {
    "controlUi": {
      "allowInsecureAuth": true,
      "dangerouslyDisableDeviceAuth": true
    }
  },
  "channels": {
    "feishu": { "dmPolicy": "open", "groupPolicy": "open", "allowFrom": ["*"], "groupAllowFrom": ["*"] },
    "telegram": { "dmPolicy": "open", "groupPolicy": "open", "allowFrom": ["*"], "groupAllowFrom": ["*"] },
    "whatsapp": { "dmPolicy": "open", "groupPolicy": "open", "allowFrom": ["*"], "groupAllowFrom": ["*"] },
    "imessage": { "dmPolicy": "open", "groupPolicy": "open", "allowFrom": ["*"], "groupAllowFrom": ["*"] }
  }
}
EOF
    fi
    if check_command jq; then
        local tmp
        tmp="$(mktemp)"
        if jq '
            .gateway = (.gateway // {})
            | .gateway.controlUi = (.gateway.controlUi // {})
            | .gateway.controlUi.allowInsecureAuth = true
            | .gateway.controlUi.dangerouslyDisableDeviceAuth = true
            | .channels = (.channels // {})
            | (.channels.feishu //= {})
            | (.channels.telegram //= {})
            | (.channels.whatsapp //= {})
            | (.channels.imessage //= {})
            | .channels.feishu.dmPolicy = "open"
            | .channels.feishu.groupPolicy = "open"
            | .channels.feishu.allowFrom = ["*"]
            | .channels.feishu.groupAllowFrom = ["*"]
            | .channels.telegram.dmPolicy = "open"
            | .channels.telegram.groupPolicy = "open"
            | .channels.telegram.allowFrom = ["*"]
            | .channels.telegram.groupAllowFrom = ["*"]
            | .channels.whatsapp.dmPolicy = "open"
            | .channels.whatsapp.groupPolicy = "open"
            | .channels.whatsapp.allowFrom = ["*"]
            | .channels.whatsapp.groupAllowFrom = ["*"]
            | .channels.imessage.dmPolicy = "open"
            | .channels.imessage.groupPolicy = "open"
            | .channels.imessage.allowFrom = ["*"]
            | .channels.imessage.groupAllowFrom = ["*"]
        ' "$cfg" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
            mv "$tmp" "$cfg"
            return 0
        fi
        rm -f "$tmp" 2>/dev/null || true
    fi
    if check_command python3; then
        python3 - "$cfg" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
channels = ("feishu","telegram","whatsapp","imessage")
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    gateway = data.get("gateway") or {}
    if not isinstance(gateway, dict):
        gateway = {}
    control_ui = gateway.get("controlUi") or {}
    if not isinstance(control_ui, dict):
        control_ui = {}
    control_ui["allowInsecureAuth"] = True
    control_ui["dangerouslyDisableDeviceAuth"] = True
    gateway["controlUi"] = control_ui
    data["gateway"] = gateway
    root = data.get("channels") or {}
    if not isinstance(root, dict):
        root = {}
    for ch in channels:
        item = root.get(ch) or {}
        if not isinstance(item, dict):
            item = {}
        item["dmPolicy"] = "open"
        item["groupPolicy"] = "open"
        item["allowFrom"] = ["*"]
        item["groupAllowFrom"] = ["*"]
        root[ch] = item
    data["channels"] = root
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
except Exception:
    pass
PY
    fi
}

apply_dashboard_pairing_bypass_install() {
    if ! check_command openclaw; then
        return 0
    fi
    # 禁用 Control UI 设备配对门槛，避免远程浏览器隧道反复出现 pairing required。
    openclaw config set gateway.controlUi.allowInsecureAuth true >/dev/null 2>&1 || true
    openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true >/dev/null 2>&1 || true
}

apply_default_feishu_runtime_flags() {
    if ! check_command openclaw; then
        return 0
    fi
    openclaw config set channels.feishu.streaming true >/dev/null 2>&1 || true
    openclaw config set channels.feishu.footer.elapsed true >/dev/null 2>&1 || true
    openclaw config set channels.feishu.footer.status true >/dev/null 2>&1 || true
}

openclaw_plugins_install_with_retry_install() {
    local source_spec="$1"
    local attempts="${PLUGIN_INSTALL_RETRIES:-2}"
    local backoff="${PLUGIN_INSTALL_BACKOFF_SECONDS:-2}"
    local attempt=1

    if ! [[ "$attempts" =~ ^[0-9]+$ ]] || [ "$attempts" -lt 1 ]; then
        attempts=1
    fi
    if ! [[ "$backoff" =~ ^[0-9]+$ ]] || [ "$backoff" -lt 1 ]; then
        backoff=1
    fi

    while [ "$attempt" -le "$attempts" ]; do
        if openclaw plugins install "$source_spec" --pin >/dev/null 2>&1 || openclaw plugins install "$source_spec" >/dev/null 2>&1; then
            return 0
        fi
        if [ "$attempt" -lt "$attempts" ]; then
            sleep $((backoff * attempt))
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

get_plugins_entries_keys_install() {
    local config_json="$CONFIG_DIR/openclaw.json"
    [ -f "$config_json" ] || return 0

    if check_command jq; then
        jq -r '.plugins.entries // {} | keys[]' "$config_json" 2>/dev/null || true
        return 0
    fi

    if check_command python3; then
        python3 - "$config_json" <<'PY' 2>/dev/null || true
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    for k in (data.get("plugins", {}).get("entries", {}) or {}).keys():
        print(k)
except Exception:
    pass
PY
        return 0
    fi

    if check_command node; then
        node -e '
const fs=require("fs");
try{
  const d=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  Object.keys((d.plugins&&d.plugins.entries)||{}).forEach(k=>console.log(k));
}catch(e){}
' "$config_json" 2>/dev/null || true
    fi
}

plugin_entry_candidate_ids_install() {
    local entry_id="$1"
    case "$entry_id" in
        wecom-openclaw-plugin) echo "wecom-openclaw-plugin wecom @wecom/wecom-openclaw-plugin" ;;
        openclaw-wechat-channel|wechat) echo "openclaw-wechat-channel wechat" ;;
        openclaw-qqbot|qqbot) echo "qqbot openclaw-qqbot @sliverp/qqbot @tencent-connect/openclaw-qqbot" ;;
        dingtalk) echo "dingtalk openclaw-channel-dingtalk @openclaw-china/channels" ;;
        feishu) echo "feishu @openclaw/feishu" ;;
        *) echo "$entry_id" ;;
    esac
}

is_plugin_entry_available_install() {
    local entry_id="$1"
    local candidate=""
    for candidate in $(plugin_entry_candidate_ids_install "$entry_id"); do
        [ -n "$candidate" ] || continue
        if openclaw plugins info "$candidate" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

is_legacy_plugin_entry_alias_install() {
    local entry_id="$1"
    case "$entry_id" in
        wechat|openclaw-wechat-channel|wecom|openclaw-wecom|wecom-openclaw-plugin|dingtalk|openclaw-channel-dingtalk|qqbot|openclaw-qqbot)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

cleanup_unknown_plugin_entries_install() {
    local key=""
    local removed=0
    local inspected=0
    local keys
    keys="$(get_plugins_entries_keys_install)"
    [ -n "$keys" ] || return 0

    while IFS= read -r key; do
        [ -n "$key" ] || continue
        inspected=$((inspected + 1))
        if is_legacy_plugin_entry_alias_install "$key"; then
            openclaw config unset "plugins.entries.$key" >/dev/null 2>&1 || true
            removed=$((removed + 1))
            continue
        fi
        if is_plugin_entry_available_install "$key"; then
            continue
        fi
        openclaw config unset "plugins.entries.$key" >/dev/null 2>&1 || true
        removed=$((removed + 1))
    done <<< "$keys"

    if [ "$removed" -gt 0 ]; then
        log_warn "已清理 ${removed}/${inspected} 个无效插件配置项（plugins.entries.*），减少启动告警。"
    fi
}

install_default_official_plugins() {
    if ! check_command openclaw; then
        log_warn "未检测到 openclaw，跳过默认官方插件安装。"
        return 0
    fi

    local script_dir cache_root cache_repo bundle_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cache_root="$CONFIG_DIR/.cache"
    cache_repo="$cache_root/auto-install-openclaw-repo"
    bundle_dir="$script_dir/plugins/official"
    if [ ! -d "$bundle_dir" ] && [ -d "$cache_repo/plugins/official" ]; then
        bundle_dir="$cache_repo/plugins/official"
    fi

    cleanup_stale_plugin_state

    log_step "同步默认消息渠道插件集（优先仓库本地包，其次远端兜底）..."
    local ok=0
    local fail=0
    local builtins_ok=0
    local builtins_skip=0
    local plugin spec local_source plugin_alias
    for plugin in $DEFAULT_OFFICIAL_PLUGINS; do
        spec="$plugin"
        plugin_alias="$(plugin_enable_alias_from_spec_install "$spec")"

        # 1) 先尝试启用（针对已安装/内置插件）
        if openclaw plugins enable "$plugin_alias" >/dev/null 2>&1; then
            ok=$((ok + 1))
            continue
        fi

        # 2) 优先尝试从仓库本地包安装，避免公网慢速/失败拖慢安装
        local_source="$(resolve_official_plugin_local_source_install "$spec" "$bundle_dir" 2>/dev/null || true)"
        if [ -n "$local_source" ]; then
            if openclaw_plugins_install_with_retry_install "$local_source"; then
                openclaw plugins enable "$plugin_alias" >/dev/null 2>&1 || true
                ok=$((ok + 1))
                continue
            fi
        fi

        # 3) 本地包缺失或安装失败时，再按需尝试远端兜底
        if [ "${OPENCLAW_ALLOW_REMOTE_PLUGIN_FALLBACK:-0}" = "1" ] && openclaw_plugins_install_with_retry_install "$spec"; then
            openclaw plugins enable "$plugin_alias" >/dev/null 2>&1 || true
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    done

    # Telegram / iMessage 在部分版本中是内置渠道能力，默认只做启用，不做远端安装。
    local builtin_id
    for builtin_id in $DEFAULT_BUILTIN_CHANNEL_PLUGINS; do
        if openclaw plugins enable "$builtin_id" >/dev/null 2>&1; then
            builtins_ok=$((builtins_ok + 1))
        else
            log_info "内置渠道插件未显式暴露，按内置渠道处理（跳过）: $builtin_id"
            builtins_skip=$((builtins_skip + 1))
        fi
    done

    log_info "默认消息渠道插件安装完成：包安装成功 ${ok}，包安装失败 ${fail}，内置启用成功 ${builtins_ok}，内置跳过 ${builtins_skip}"
    cleanup_unknown_plugin_entries_install || true
}

plugin_bundle_slug_from_spec_install() {
    local spec="$1"
    local slug="${spec##*/}"
    slug="${slug%@*}"
    echo "$slug"
}

plugin_bundle_pack_name_from_spec_install() {
    local spec="$1"
    local base="${spec%@*}"
    base="${base#@}"
    echo "${base//\//-}"
}

plugin_enable_alias_from_spec_install() {
    local spec="$1"
    case "$spec" in
        @wecom/wecom-openclaw-plugin* ) echo "wecom-openclaw-plugin" ;;
        @openclaw-china/wecom* ) echo "wecom" ;;
        openclaw-wechat-channel* ) echo "openclaw-wechat-channel" ;;
        openclaw-channel-dingtalk* ) echo "dingtalk" ;;
        @sliverp/qqbot* ) echo "qqbot" ;;
        @tencent-connect/openclaw-qqbot* ) echo "openclaw-qqbot" ;;
        @openclaw/* )
            local alias="${spec#@openclaw/}"
            alias="${alias%@*}"
            echo "$alias"
            ;;
        * )
            plugin_bundle_slug_from_spec_install "$spec"
            ;;
    esac
}

plugin_spec_base_install() {
    local spec="$1"
    echo "${spec%@*}"
}

resolve_plugin_source_from_manifest_install() {
    local plugin_spec="$1"
    local bundle_dir="$2"
    local manifest_file="$bundle_dir/manifest.json"
    local spec_base rel candidate

    [ -f "$manifest_file" ] || return 1
    spec_base="$(plugin_spec_base_install "$plugin_spec")"

    if check_command jq; then
        while IFS= read -r rel; do
            [ -n "$rel" ] || continue
            candidate="$bundle_dir/$rel"
            [ -e "$candidate" ] || continue
            echo "$candidate"
            return 0
        done < <(jq -r --arg s "$spec_base" '
            (.entries // [])
            | map(select(((.spec // .package // "") == $s)))
            | .[] | (.files // [])[]
        ' "$manifest_file" 2>/dev/null || true)
    elif check_command python3; then
        while IFS= read -r rel; do
            [ -n "$rel" ] || continue
            candidate="$bundle_dir/$rel"
            [ -e "$candidate" ] || continue
            echo "$candidate"
            return 0
        done < <(python3 - "$manifest_file" "$spec_base" <<'PY' 2>/dev/null || true
import json, sys
path, spec = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(path, "r", encoding="utf-8"))
except Exception:
    data = {}
for entry in data.get("entries", []) or []:
    ident = entry.get("spec") or entry.get("package") or ""
    if ident != spec:
        continue
    for f in (entry.get("files") or []):
        if f:
            print(f)
PY
)
    fi

    return 1
}

resolve_official_plugin_local_source_install() {
    local plugin_spec="$1"
    local bundle_dir="$2"
    local slug
    local pack_name
    local candidate

    candidate="$(resolve_plugin_source_from_manifest_install "$plugin_spec" "$bundle_dir" 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -e "$candidate" ]; then
        echo "$candidate"
        return 0
    fi

    slug="$(plugin_bundle_slug_from_spec_install "$plugin_spec")"
    pack_name="$(plugin_bundle_pack_name_from_spec_install "$plugin_spec")"
    for candidate in \
        "$bundle_dir/$slug" \
        "$bundle_dir/$pack_name" \
        "$bundle_dir/${slug}.tgz" \
        "$bundle_dir/${pack_name}.tgz" \
        "$bundle_dir/archives/${slug}.tgz" \
        "$bundle_dir/archives/${pack_name}.tgz" \
        "$bundle_dir/archives/${slug}-"*.tgz \
        "$bundle_dir/archives/${pack_name}-"*.tgz \
        "$bundle_dir/archives/openclaw-${slug}-"*.tgz \
        "$bundle_dir/archives/openclaw-${pack_name}-"*.tgz; do
        [ -e "$candidate" ] || continue
        echo "$candidate"
        return 0
    done
    return 1
}

install_channel_assets() {
    local skill_dir="$CONFIG_DIR/skills/channel-setup-assistant"
    local skill_file="$skill_dir/SKILL.md"
    local skills_root="$CONFIG_DIR/skills"
    local docs_dir="$CONFIG_DIR/docs"
    local doc_file="$docs_dir/channels-configuration-guide.md"
    local source_index_file="$docs_dir/upstream-sources.md"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local local_doc="$script_dir/docs/channels-configuration-guide.md"
    local local_source_index="$script_dir/docs/upstream-sources.md"
    local local_skill="$script_dir/skills/channel-setup-assistant/SKILL.md"

    mkdir -p "$skill_dir" "$skills_root" "$docs_dir" 2>/dev/null || true

    if [ -f "$local_doc" ]; then
        cp "$local_doc" "$doc_file" 2>/dev/null || true
    elif download_with_fallback "$doc_file.tmp" "$GITHUB_RAW_URL/docs/channels-configuration-guide.md" "$INSTALLER_MIRROR_RAW_URL/docs/channels-configuration-guide.md"; then
        mv "$doc_file.tmp" "$doc_file"
    else
        rm -f "$doc_file.tmp" 2>/dev/null || true
        cat > "$doc_file" <<'EOF'
# OpenClaw 渠道配置文档（自动安装器）

请优先使用：
1) `openclaw onboard`（官方模型配置）
2) `bash ~/.openclaw/config-menu.sh`（渠道配置）

关键渠道推荐：
- 飞书（官方）：`@openclaw/feishu`
- Telegram（内置）：`telegram`
- iMessage（内置）：`imessage`

完整文档请查看仓库 `docs/channels-configuration-guide.md`。
EOF
    fi

    if [ -f "$local_source_index" ]; then
        cp "$local_source_index" "$source_index_file" 2>/dev/null || true
    elif download_with_fallback "$source_index_file.tmp" "$GITHUB_RAW_URL/docs/upstream-sources.md" "$INSTALLER_MIRROR_RAW_URL/docs/upstream-sources.md"; then
        mv "$source_index_file.tmp" "$source_index_file"
    else
        rm -f "$source_index_file.tmp" 2>/dev/null || true
    fi

    if [ -f "$local_skill" ]; then
        cp "$local_skill" "$skill_file" 2>/dev/null || true
    else
        cat > "$skill_file" <<'EOF'
# OpenClaw 渠道配置助手 Skill

目标：当用户提供消息渠道信息时，交互式收集缺失参数，并执行命令行完成配置。

执行原则：
1. 先确认渠道类型（telegram/discord/slack/feishu/whatsapp/imessage/others）。
2. 明确必填项，缺失项逐个询问，不一次性抛出过多字段。
3. 执行前回显将执行的命令，并让用户确认。
4. 执行后输出：成功/失败、下一步验证命令、常见排障命令。

标准命令：
- 状态：`openclaw channels list`
- 健康检查：`openclaw doctor --fix`
- 重启：`openclaw gateway restart`

重点渠道字段：
- Feishu: `appId`, `appSecret`
- Telegram: `botToken`
- WhatsApp: `session` / `pairing`

配置完成后必须执行：
1) `openclaw doctor --fix`
2) `openclaw gateway restart`
3) `openclaw channels list`
EOF
    fi

    log_info "默认技能包将按规则档位注入（低/中/高），此步骤仅注入渠道文档与渠道助手 Skill。"

    chmod 644 "$skill_file" "$doc_file" "$source_index_file" 2>/dev/null || true
    log_info "已注入渠道配置文档与 Skill:"
    log_info "  文档: $doc_file"
    log_info "  上游索引: $source_index_file"
    log_info "  Skill: $skill_file"
}

# 初始化 OpenClaw 配置
init_openclaw_config() {
    log_step "初始化 OpenClaw 配置..."
    
    local OPENCLAW_DIR="$HOME/.openclaw"
    
    # 创建必要的目录
    mkdir -p "$OPENCLAW_DIR/agents/main/sessions"
    mkdir -p "$OPENCLAW_DIR/agents/main/agent"
    mkdir -p "$OPENCLAW_DIR/credentials"
    
    # 修复权限
    chmod 700 "$OPENCLAW_DIR" 2>/dev/null || true

    # 预先纠正常见渠道策略，避免后续 openclaw config set 时反复输出 doctor 告警
    normalize_channel_policy_in_json_install || true
    
    # 设置 gateway.mode 为 local
    if check_command openclaw; then
        openclaw config set gateway.mode local 2>/dev/null || true
        openclaw config set gateway.bind "$GATEWAY_BIND" 2>/dev/null || true
        [ "$GATEWAY_BIND" = "custom" ] && [ -n "$GATEWAY_CUSTOM_BIND_HOST" ] && \
            openclaw config set gateway.customBindHost "$GATEWAY_CUSTOM_BIND_HOST" 2>/dev/null || true
        openclaw config set gateway.port "$GATEWAY_PORT" 2>/dev/null || true
        apply_dashboard_pairing_bypass_install
        # 默认放开消息渠道 DM/群聊准入，避免渠道侧触发 pairing 审批
        openclaw config set channels.feishu.dmPolicy open 2>/dev/null || true
        openclaw config set channels.feishu.groupPolicy open 2>/dev/null || true
        openclaw config set channels.telegram.dmPolicy open 2>/dev/null || true
        openclaw config set channels.telegram.groupPolicy open 2>/dev/null || true
        openclaw config set channels.whatsapp.dmPolicy open 2>/dev/null || true
        openclaw config set channels.whatsapp.groupPolicy open 2>/dev/null || true
        openclaw config set channels.imessage.dmPolicy open 2>/dev/null || true
        openclaw config set channels.imessage.groupPolicy open 2>/dev/null || true
        log_info "Gateway 模式已设置为 local（bind=${GATEWAY_BIND}, port=${GATEWAY_PORT}）"

        local auth_mode
        auth_mode="$(openclaw config get gateway.auth.mode 2>/dev/null || true)"
        auth_mode="$(echo "$auth_mode" | tr -d '"'\''[:space:]')"
        if [ -z "$auth_mode" ] || [ "$auth_mode" = "undefined" ]; then
            openclaw config set gateway.auth.mode token 2>/dev/null || true
            auth_mode="token"
        fi
        if [ "$auth_mode" = "token" ]; then
            local auth_token
            auth_token="$(openclaw config get gateway.auth.token 2>/dev/null || true)"
            auth_token="$(echo "$auth_token" | tr -d '"'\''[:space:]')"
            if [ -z "$auth_token" ] || [ "$auth_token" = "undefined" ]; then
                local new_token
                new_token="$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | head -c 32 | xxd -p 2>/dev/null || date +%s%N | sha256sum | head -c 64)"
                openclaw config set gateway.auth.token "$new_token" 2>/dev/null || true
                log_info "已初始化并持久化 Gateway Token，用于远程隧道/反向代理访问。"
            fi
        fi
    fi

    local env_file="$OPENCLAW_DIR/env"
    touch "$env_file" 2>/dev/null || true
    if ! grep -q '^# Gateway runtime defaults' "$env_file" 2>/dev/null; then
        {
            echo ""
            echo "# Gateway runtime defaults"
        } >> "$env_file"
    fi
    if grep -q '^export OPENCLAW_GATEWAY_BIND=' "$env_file" 2>/dev/null; then
        local tmp_env_bind
        tmp_env_bind="$(mktemp)"
        awk -v v="$GATEWAY_BIND" '
            BEGIN { done=0 }
            /^export OPENCLAW_GATEWAY_BIND=/ { print "export OPENCLAW_GATEWAY_BIND=" v; done=1; next }
            { print }
            END { if (!done) print "export OPENCLAW_GATEWAY_BIND=" v }
        ' "$env_file" > "$tmp_env_bind" && mv "$tmp_env_bind" "$env_file"
    else
        echo "export OPENCLAW_GATEWAY_BIND=$GATEWAY_BIND" >> "$env_file"
    fi
    if grep -q '^export OPENCLAW_GATEWAY_HOST=' "$env_file" 2>/dev/null; then
        local tmp_env
        tmp_env="$(mktemp)"
        awk -v v="$GATEWAY_HOST" '
            BEGIN { done=0 }
            /^export OPENCLAW_GATEWAY_HOST=/ { print "export OPENCLAW_GATEWAY_HOST=" v; done=1; next }
            { print }
            END { if (!done) print "export OPENCLAW_GATEWAY_HOST=" v }
        ' "$env_file" > "$tmp_env" && mv "$tmp_env" "$env_file"
    else
        echo "export OPENCLAW_GATEWAY_HOST=$GATEWAY_HOST" >> "$env_file"
    fi
    if [ -n "$GATEWAY_CUSTOM_BIND_HOST" ]; then
        if grep -q '^export OPENCLAW_GATEWAY_CUSTOM_BIND_HOST=' "$env_file" 2>/dev/null; then
            local tmp_env_custom
            tmp_env_custom="$(mktemp)"
            awk -v v="$GATEWAY_CUSTOM_BIND_HOST" '
                BEGIN { done=0 }
                /^export OPENCLAW_GATEWAY_CUSTOM_BIND_HOST=/ { print "export OPENCLAW_GATEWAY_CUSTOM_BIND_HOST=" v; done=1; next }
                { print }
                END { if (!done) print "export OPENCLAW_GATEWAY_CUSTOM_BIND_HOST=" v }
            ' "$env_file" > "$tmp_env_custom" && mv "$tmp_env_custom" "$env_file"
        else
            echo "export OPENCLAW_GATEWAY_CUSTOM_BIND_HOST=$GATEWAY_CUSTOM_BIND_HOST" >> "$env_file"
        fi
    fi
    if grep -q '^export OPENCLAW_GATEWAY_PORT=' "$env_file" 2>/dev/null; then
        local tmp_env2
        tmp_env2="$(mktemp)"
        awk -v v="$GATEWAY_PORT" '
            BEGIN { done=0 }
            /^export OPENCLAW_GATEWAY_PORT=/ { print "export OPENCLAW_GATEWAY_PORT=" v; done=1; next }
            { print }
            END { if (!done) print "export OPENCLAW_GATEWAY_PORT=" v }
        ' "$env_file" > "$tmp_env2" && mv "$tmp_env2" "$env_file"
    else
        echo "export OPENCLAW_GATEWAY_PORT=$GATEWAY_PORT" >> "$env_file"
    fi
    chmod 600 "$env_file" 2>/dev/null || true

    # 自动写入 Dashboard 反向代理/内嵌场景所需 Origin 白名单
    ensure_gateway_controlui_allowed_origins
}

# 为 Gateway Control UI 自动补齐 allowedOrigins，避免 Dashboard 内嵌/代理后出现 origin not allowed。
ensure_gateway_controlui_allowed_origins() {
    local openclaw_json="$HOME/.openclaw/openclaw.json"
    if [ ! -f "$openclaw_json" ]; then
        log_warn "未找到 $openclaw_json，跳过 gateway.controlUi.allowedOrigins 自动配置"
        return 0
    fi

    local py_bin=""
    if command -v python3 >/dev/null 2>&1; then
        py_bin="python3"
    elif command -v python >/dev/null 2>&1; then
        py_bin="python"
    else
        log_warn "未检测到 Python，跳过 gateway.controlUi.allowedOrigins 自动配置"
        return 0
    fi

    local extra_origins="${OPENCLAW_DASHBOARD_ALLOWED_ORIGINS:-}"
    local disable_pairing="${OPENCLAW_DASHBOARD_DISABLE_PAIRING:-1}"
    local result
    result=$("$py_bin" - "$openclaw_json" "$GATEWAY_PORT" "$disable_pairing" "$extra_origins" <<'PYEOF'
import json
import os
import secrets
import sys

cfg_path = os.path.expanduser(sys.argv[1])
gateway_port = str(sys.argv[2]).strip() or "13145"
disable_pairing = str(sys.argv[3]).strip() != "0"
extra_raw = str(sys.argv[4]).strip()

with open(cfg_path, "r", encoding="utf-8") as f:
    cfg = json.load(f)

gateway = cfg.setdefault("gateway", {})
control_ui = gateway.setdefault("controlUi", {})
auth = gateway.setdefault("auth", {})
existing = control_ui.get("allowedOrigins", [])
if not isinstance(existing, list):
    existing = []

required = [
    f"http://127.0.0.1:{gateway_port}",
    f"https://127.0.0.1:{gateway_port}",
    f"http://localhost:{gateway_port}",
    f"https://localhost:{gateway_port}",
    "https://monkeykingfury.com",
    "https://www.monkeykingfury.com",
]
if extra_raw:
    required.extend([x.strip() for x in extra_raw.split(",") if x.strip()])

merged = []
seen = set()
for item in [*existing, *required]:
    v = str(item).strip()
    if not v or v in seen:
        continue
    seen.add(v)
    merged.append(v)

if merged == existing:
    origins_changed = False
else:
    control_ui["allowedOrigins"] = merged
    origins_changed = True

changed = origins_changed
if str(auth.get("mode", "")).strip().lower() != "token":
    auth["mode"] = "token"
    changed = True

if not str(auth.get("token", "")).strip():
    auth["token"] = secrets.token_hex(24)
    changed = True

if disable_pairing:
    if control_ui.get("allowInsecureAuth") is not True:
        control_ui["allowInsecureAuth"] = True
        changed = True
    if control_ui.get("dangerouslyDisableDeviceAuth") is not True:
        control_ui["dangerouslyDisableDeviceAuth"] = True
        changed = True

if not changed:
    print("NOCHANGE")
    raise SystemExit(0)

with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("UPDATED")
PYEOF
)

    if [ "$result" = "UPDATED" ]; then
        log_info "已自动补齐 gateway.controlUi.allowedOrigins"
        if check_command openclaw; then
            openclaw gateway restart 2>/dev/null || openclaw gateway start 2>/dev/null || true
            log_info "Gateway 已重启以应用 allowedOrigins 配置"
        fi
    elif [ "$result" = "NOCHANGE" ]; then
        log_info "gateway.controlUi.allowedOrigins 已符合要求"
    else
        log_warn "gateway.controlUi.allowedOrigins 自动配置失败（可手动检查 ~/.openclaw/openclaw.json）"
    fi
}

# 为 MiniMax 写入官方兼容 provider 配置，避免旧版本出现 Unknown model
ensure_minimax_provider_config() {
    local provider="$1"   # minimax|minimax-cn
    local model="$2"      # MiniMax-M2.5 / MiniMax-M2.5-highspeed
    local config_file="$3"
    local base_url="https://api.minimax.io/anthropic"
    if [ "$provider" = "minimax-cn" ]; then
        base_url="https://api.minimaxi.com/anthropic"
    fi

    mkdir -p "$(dirname "$config_file")" 2>/dev/null || true
    [ -f "$config_file" ] || echo "{}" > "$config_file"

    if command -v node &> /dev/null; then
        node -e "
const fs = require('fs');
const file = '$config_file';
const provider = '$provider';
const model = '$model';
const baseUrl = '$base_url';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
cfg.models ||= {};
cfg.models.mode ||= 'merge';
cfg.models.providers ||= {};
const p = cfg.models.providers[provider] || {};
const models = Array.isArray(p.models) ? p.models : [];
const catalog = {
  'MiniMax-M2.5': { name: 'MiniMax M2.5' },
  'MiniMax-M2.5-highspeed': { name: 'MiniMax M2.5 Highspeed' },
};
const modelIds = new Set(models.map(m => m.id));
for (const id of ['MiniMax-M2.5', 'MiniMax-M2.5-highspeed']) {
  if (!modelIds.has(id)) {
    models.push({
      id,
      name: (catalog[id] && catalog[id].name) || id,
      reasoning: true,
      input: ['text'],
      cost: { input: 0.3, output: 1.2, cacheRead: 0.03, cacheWrite: 0.12 },
      contextWindow: 200000,
      maxTokens: 8192
    });
  }
}
cfg.models.providers[provider] = {
  ...p,
  baseUrl,
  api: 'anthropic-messages',
  authHeader: true,
  models
};
cfg.agents ||= {};
cfg.agents.defaults ||= {};
cfg.agents.defaults.models ||= {};
const ref = provider + '/' + model;
cfg.agents.defaults.models[ref] = { ...(cfg.agents.defaults.models[ref] || {}), alias: 'Minimax' };
fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
" >/dev/null 2>&1 || true
    elif command -v python3 &> /dev/null; then
        python3 - <<PYEOF
import json, os
file = os.path.expanduser("$config_file")
provider = "$provider"
model = "$model"
base_url = "$base_url"
try:
    with open(file, "r") as f:
        cfg = json.load(f)
except Exception:
    cfg = {}
cfg.setdefault("models", {})
cfg["models"].setdefault("mode", "merge")
cfg["models"].setdefault("providers", {})
p = cfg["models"]["providers"].get(provider, {})
models = p.get("models", []) if isinstance(p.get("models"), list) else []
catalog = {
    "MiniMax-M2.5": "MiniMax M2.5",
    "MiniMax-M2.5-highspeed": "MiniMax M2.5 Highspeed",
}
existing = {m.get("id") for m in models if isinstance(m, dict)}
for mid in ("MiniMax-M2.5", "MiniMax-M2.5-highspeed"):
    if mid not in existing:
        models.append({
            "id": mid, "name": catalog.get(mid, mid), "reasoning": True, "input": ["text"],
            "cost": {"input": 0.3, "output": 1.2, "cacheRead": 0.03, "cacheWrite": 0.12},
            "contextWindow": 200000, "maxTokens": 8192
        })
cfg["models"]["providers"][provider] = {
    **(p if isinstance(p, dict) else {}),
    "baseUrl": base_url,
    "api": "anthropic-messages",
    "authHeader": True,
    "models": models
}
cfg.setdefault("agents", {}).setdefault("defaults", {}).setdefault("models", {})
cfg["agents"]["defaults"]["models"][f"{provider}/{model}"] = {"alias": "Minimax"}
with open(file, "w") as f:
    json.dump(cfg, f, indent=2)
PYEOF
    fi
}

write_minimax_skill_config_install() {
    local api_key="$1"
    [ -n "$api_key" ] || return 0

    local cfg_dir="$CONFIG_DIR/config"
    local cfg_file="$cfg_dir/minimax.json"
    local output_path="$CONFIG_DIR/workspace/minimax-output"

    mkdir -p "$cfg_dir" "$output_path" 2>/dev/null || true

    if command -v python3 >/dev/null 2>&1; then
        python3 - <<PYEOF
import json, os
cfg_file = os.path.expanduser("$cfg_file")
payload = {
    "api_key": "$api_key",
    "output_path": "~/.openclaw/workspace/minimax-output"
}
os.makedirs(os.path.dirname(cfg_file), exist_ok=True)
with open(cfg_file, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PYEOF
    else
        cat > "$cfg_file" <<EOF
{
  "api_key": "$api_key",
  "output_path": "~/.openclaw/workspace/minimax-output"
}
EOF
    fi
    chmod 600 "$cfg_file" 2>/dev/null || true
}

# 配置 OpenClaw 使用的 AI 模型和 API Key
configure_openclaw_model() {
    log_step "配置 OpenClaw AI 模型..."
    
    local env_file="$HOME/.openclaw/env"
    local openclaw_json="$HOME/.openclaw/openclaw.json"
    
    # 首次创建环境变量文件，后续采用增量更新避免覆盖其他 Provider Key
    if [ ! -f "$env_file" ]; then
        cat > "$env_file" << EOF
# OpenClaw 环境变量配置
# 由安装脚本自动生成: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    fi

    # 根据 AI_PROVIDER 设置对应的环境变量
    case "$AI_PROVIDER" in
        anthropic)
            upsert_env_export_install "ANTHROPIC_API_KEY" "$AI_KEY"
            [ -n "$BASE_URL" ] && upsert_env_export_install "ANTHROPIC_BASE_URL" "$BASE_URL" || remove_env_export_install "ANTHROPIC_BASE_URL"
            ;;
        openai)
            upsert_env_export_install "OPENAI_API_KEY" "$AI_KEY"
            [ -n "$BASE_URL" ] && upsert_env_export_install "OPENAI_BASE_URL" "$BASE_URL" || remove_env_export_install "OPENAI_BASE_URL"
            ;;
        deepseek)
            upsert_env_export_install "DEEPSEEK_API_KEY" "$AI_KEY"
            upsert_env_export_install "DEEPSEEK_BASE_URL" "${BASE_URL:-https://api.deepseek.com}"
            ;;
        moonshot|kimi)
            upsert_env_export_install "MOONSHOT_API_KEY" "$AI_KEY"
            upsert_env_export_install "MOONSHOT_BASE_URL" "${BASE_URL:-https://api.moonshot.ai/v1}"
            ;;
        google|google-gemini-cli|google-antigravity)
            upsert_env_export_install "GOOGLE_API_KEY" "$AI_KEY"
            [ -n "$BASE_URL" ] && upsert_env_export_install "GOOGLE_BASE_URL" "$BASE_URL" || remove_env_export_install "GOOGLE_BASE_URL"
            ;;
        groq)
            upsert_env_export_install "GROQ_API_KEY" "$AI_KEY"
            upsert_env_export_install "GROQ_BASE_URL" "${BASE_URL:-https://api.groq.com/openai/v1}"
            ;;
        mistral)
            upsert_env_export_install "MISTRAL_API_KEY" "$AI_KEY"
            upsert_env_export_install "MISTRAL_BASE_URL" "${BASE_URL:-https://api.mistral.ai/v1}"
            ;;
        openrouter)
            upsert_env_export_install "OPENROUTER_API_KEY" "$AI_KEY"
            upsert_env_export_install "OPENROUTER_BASE_URL" "${BASE_URL:-https://openrouter.ai/api/v1}"
            ;;
        ollama)
            upsert_env_export_install "OLLAMA_HOST" "${BASE_URL:-http://localhost:11434}"
            ;;
        xai)
            upsert_env_export_install "XAI_API_KEY" "$AI_KEY"
            ;;
        zai)
            upsert_env_export_install "ZAI_API_KEY" "$AI_KEY"
            ;;
        minimax|minimax-cn)
            upsert_env_export_install "MINIMAX_API_KEY" "$AI_KEY"
            if [ "$AI_PROVIDER" = "minimax-cn" ]; then
                upsert_env_export_install "MINIMAX_API_HOST" "https://api.minimaxi.com"
            else
                upsert_env_export_install "MINIMAX_API_HOST" "https://api.minimax.io"
            fi
            write_minimax_skill_config_install "$AI_KEY"
            ;;
        opencode|opencode-go)
            upsert_env_export_install "OPENCODE_API_KEY" "$AI_KEY"
            ;;
    esac

    upsert_env_export_install "OPENCLAW_GATEWAY_BIND" "$GATEWAY_BIND"
    upsert_env_export_install "OPENCLAW_GATEWAY_HOST" "$GATEWAY_HOST"
    if [ -n "$GATEWAY_CUSTOM_BIND_HOST" ]; then
        upsert_env_export_install "OPENCLAW_GATEWAY_CUSTOM_BIND_HOST" "$GATEWAY_CUSTOM_BIND_HOST"
    fi
    upsert_env_export_install "OPENCLAW_GATEWAY_PORT" "$GATEWAY_PORT"
    
    chmod 600 "$env_file"
    log_info "环境变量配置已保存到: $env_file"

    if [ "$AI_PROVIDER" = "minimax" ] || [ "$AI_PROVIDER" = "minimax-cn" ]; then
        ensure_minimax_provider_config "$AI_PROVIDER" "$AI_MODEL" "$openclaw_json"
    fi
    
    # 设置默认模型
    if check_command openclaw; then
        local openclaw_model=""
        local use_custom_provider=false
        
        # 如果使用自定义 BASE_URL，需要配置自定义 provider
        if [ -n "$BASE_URL" ] && [ "$AI_PROVIDER" = "anthropic" ]; then
            use_custom_provider=true
            configure_custom_provider "$AI_PROVIDER" "$AI_KEY" "$AI_MODEL" "$BASE_URL" "$openclaw_json"
            openclaw_model="anthropic-custom/$AI_MODEL"
        elif [ -n "$BASE_URL" ] && [ "$AI_PROVIDER" = "openai" ]; then
            use_custom_provider=true
            # 传递 API 类型参数（如果已设置）
            configure_custom_provider "$AI_PROVIDER" "$AI_KEY" "$AI_MODEL" "$BASE_URL" "$openclaw_json" "$AI_API_TYPE"
            openclaw_model="openai-custom/$AI_MODEL"
        else
            case "$AI_PROVIDER" in
                anthropic)
                    openclaw_model="anthropic/$AI_MODEL"
                    ;;
                openai)
                    openclaw_model="openai/$AI_MODEL"
                    ;;
                groq)
                    openclaw_model="groq/$AI_MODEL"
                    ;;
                mistral)
                    openclaw_model="mistral/$AI_MODEL"
                    ;;
                deepseek)
                    openclaw_model="deepseek/$AI_MODEL"
                    ;;
                moonshot|kimi)
                    openclaw_model="moonshot/$AI_MODEL"
                    ;;
                openrouter)
                    openclaw_model="openrouter/$AI_MODEL"
                    ;;
                google)
                    openclaw_model="google/$AI_MODEL"
                    ;;
                google-gemini-cli)
                    openclaw_model="google-gemini-cli/$AI_MODEL"
                    ;;
                google-antigravity)
                    openclaw_model="google-antigravity/$AI_MODEL"
                    ;;
                ollama)
                    openclaw_model="ollama/$AI_MODEL"
                    ;;
                xai)
                    openclaw_model="xai/$AI_MODEL"
                    ;;
                zai)
                    openclaw_model="zai/$AI_MODEL"
                    ;;
                minimax)
                    openclaw_model="minimax/$AI_MODEL"
                    ;;
                minimax-cn)
                    openclaw_model="minimax-cn/$AI_MODEL"
                    ;;
                opencode)
                    openclaw_model="opencode/$AI_MODEL"
                    ;;
                opencode-go)
                    openclaw_model="opencode-go/$AI_MODEL"
                    ;;
            esac
        fi
        
        if [ -n "$openclaw_model" ]; then
            # 加载环境变量
            source "$env_file"
            
            # 设置默认模型（显示错误信息以便调试）
            local set_result
            local set_exit=0
            if set_result=$(openclaw models set "$openclaw_model" 2>&1); then
                set_exit=0
            else
                set_exit=$?
            fi
            
            if [ $set_exit -eq 0 ]; then
                log_info "默认模型已设置为: $openclaw_model"
            else
                log_warn "模型设置可能失败: $openclaw_model"
                echo -e "  ${GRAY}$set_result${NC}" | head -3
                
                # 尝试直接使用 config set
                log_info "尝试使用 config set 设置模型..."
                openclaw config set agents.defaults.model.primary "$openclaw_model" 2>/dev/null || true
                openclaw config set models.default "$openclaw_model" 2>/dev/null || true
            fi
        fi
    fi
    
    # 添加到 shell 配置文件
    add_env_to_shell "$env_file"
}

# 配置自定义 provider（用于支持自定义 API 地址）
# 参数: provider api_key model base_url config_file [api_type]
configure_custom_provider() {
    local provider="$1"
    local api_key="$2"
    local model="$3"
    local base_url="$4"
    local config_file="$5"
    local custom_api_type="$6"  # 可选参数，用于覆盖默认 API 类型
    
    # 参数校验
    if [ -z "$model" ]; then
        log_error "模型名称不能为空"
        return 1
    fi
    
    if [ -z "$api_key" ]; then
        log_error "API Key 不能为空"
        return 1
    fi
    
    if [ -z "$base_url" ]; then
        log_error "API 地址不能为空"
        return 1
    fi
    
    log_step "配置自定义 Provider..."
    
    # 确保配置目录存在
    local config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir" 2>/dev/null || true
    
    # 确定 API 类型
    # 如果传入了自定义 API 类型，使用传入的值；否则根据 provider 自动判断
    local api_type=""
    if [ -n "$custom_api_type" ]; then
        api_type="$custom_api_type"
    elif [ "$provider" = "anthropic" ]; then
        api_type="anthropic-messages"
    else
        api_type="openai-responses"
    fi
    local provider_id="${provider}-custom"
    
    # 先检查是否存在旧的自定义配置，并询问是否清理
    local do_cleanup="false"
    if [ -f "$config_file" ]; then
        # 检查是否有旧的自定义 provider 配置
        local has_old_config="false"
        if grep -q '"anthropic-custom"' "$config_file" 2>/dev/null || \
           grep -q '"openai-custom"' "$config_file" 2>/dev/null; then
            has_old_config="true"
        fi
        
        if [ "$has_old_config" = "true" ]; then
            echo ""
            echo -e "${CYAN}当前已有自定义 Provider 配置:${NC}"
            # 显示当前配置的 provider 和模型
            if command -v node &> /dev/null; then
                node -e "
const fs = require('fs');
try {
    const config = JSON.parse(fs.readFileSync('$config_file', 'utf8'));
    const providers = config.models?.providers || {};
    for (const [id, p] of Object.entries(providers)) {
        if (id.includes('-custom')) {
            console.log('  - Provider: ' + id);
            console.log('    API 地址: ' + p.baseUrl);
            if (p.models?.length) {
                console.log('    模型: ' + p.models.map(m => m.id).join(', '));
            }
        }
    }
} catch (e) {}
" 2>/dev/null
            fi
            echo ""
            echo -e "${YELLOW}是否清理旧的自定义配置？${NC}"
            echo -e "${GRAY}(清理可避免配置累积，推荐选择 Y)${NC}"
            if confirm "清理旧配置？" "y"; then
                do_cleanup="true"
            fi
        fi
    fi
    
    # 读取现有配置或创建新配置
    local config_json="{}"
    if [ -f "$config_file" ]; then
        config_json=$(cat "$config_file")
    fi
    
    # 使用 node 或 python 来处理 JSON
    local config_success=false
    
    if command -v node &> /dev/null; then
        log_info "使用 node 配置自定义 Provider..."
        
        # 将变量写入临时文件，避免 shell 转义问题
        local tmp_vars="/tmp/openclaw_provider_vars_$$.json"
        cat > "$tmp_vars" << EOFVARS
{
    "config_file": "$config_file",
    "provider_id": "$provider_id",
    "base_url": "$base_url",
    "api_key": "$api_key",
    "model": "$model",
    "api_type": "$api_type",
    "do_cleanup": "$do_cleanup"
}
EOFVARS
        
        node -e "
const fs = require('fs');
const vars = JSON.parse(fs.readFileSync('$tmp_vars', 'utf8'));

let config = {};
try {
    config = JSON.parse(fs.readFileSync(vars.config_file, 'utf8'));
} catch (e) {
    config = {};
}

// 确保 models.providers 结构存在
if (!config.models) config.models = {};
if (!config.models.providers) config.models.providers = {};

// 根据用户选择决定是否清理旧配置
if (vars.do_cleanup === 'true') {
    delete config.models.providers['anthropic-custom'];
    delete config.models.providers['openai-custom'];
    if (config.models.configured) {
        config.models.configured = config.models.configured.filter(m => {
            if (m.startsWith('openai/claude')) return false;
            if (m.startsWith('openrouter/claude') && !m.includes('openrouter.ai')) return false;
            return true;
        });
    }
    if (config.models.aliases) {
        delete config.models.aliases['claude-custom'];
    }
    console.log('Old configurations cleaned up');
}

// 添加自定义 provider
config.models.providers[vars.provider_id] = {
    baseUrl: vars.base_url,
    apiKey: vars.api_key,
    models: [
        {
            id: vars.model,
            name: vars.model,
            api: vars.api_type,
            input: ['text','image'],
            contextWindow: 200000,
            maxTokens: 8192
        }
    ]
};

fs.writeFileSync(vars.config_file, JSON.stringify(config, null, 2));
console.log('Custom provider configured: ' + vars.provider_id);
" 2>&1
        local node_exit=$?
        rm -f "$tmp_vars" 2>/dev/null
        
        if [ $node_exit -eq 0 ]; then
            config_success=true
            log_info "自定义 Provider 已配置: $provider_id"
        else
            log_warn "node 配置失败 (exit: $node_exit)，尝试使用 python3..."
        fi
    fi
    
    # 如果 node 失败或不存在，尝试 python3
    if [ "$config_success" = false ] && command -v python3 &> /dev/null; then
        log_info "使用 python3 配置自定义 Provider..."
        
        # 将变量写入临时文件，避免 shell 转义问题
        local tmp_vars="/tmp/openclaw_provider_vars_$$.json"
        cat > "$tmp_vars" << EOFVARS
{
    "config_file": "$config_file",
    "provider_id": "$provider_id",
    "base_url": "$base_url",
    "api_key": "$api_key",
    "model": "$model",
    "api_type": "$api_type",
    "do_cleanup": "$do_cleanup"
}
EOFVARS
        
        python3 -c "
import json
import os

# 从临时文件读取变量
with open('$tmp_vars', 'r') as f:
    vars = json.load(f)

config = {}
config_file = vars['config_file']
if os.path.exists(config_file):
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
    except:
        config = {}

if 'models' not in config:
    config['models'] = {}
if 'providers' not in config['models']:
    config['models']['providers'] = {}

# 根据用户选择决定是否清理旧配置
if vars['do_cleanup'] == 'true':
    config['models']['providers'].pop('anthropic-custom', None)
    config['models']['providers'].pop('openai-custom', None)
    if 'configured' in config['models']:
        config['models']['configured'] = [
            m for m in config['models']['configured']
            if not (m.startswith('openai/claude') or 
                    (m.startswith('openrouter/claude') and 'openrouter.ai' not in m))
        ]
    if 'aliases' in config['models']:
        config['models']['aliases'].pop('claude-custom', None)
    print('Old configurations cleaned up')

config['models']['providers'][vars['provider_id']] = {
    'baseUrl': vars['base_url'],
    'apiKey': vars['api_key'],
    'models': [
        {
            'id': vars['model'],
            'name': vars['model'],
            'api': vars['api_type'],
            'input': ['text','image'],
            'contextWindow': 200000,
            'maxTokens': 8192
        }
    ]
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
print('Custom provider configured: ' + vars['provider_id'])
" 2>&1
        local py_exit=$?
        rm -f "$tmp_vars" 2>/dev/null
        
        if [ $py_exit -eq 0 ]; then
            config_success=true
            log_info "自定义 Provider 已配置: $provider_id"
        else
            log_warn "python3 配置失败 (exit: $py_exit)"
        fi
    fi
    
    if [ "$config_success" = false ]; then
        log_warn "无法配置自定义 Provider（需要 node 或 python3）"
    fi
    
    # 验证配置文件是否正确写入
    if [ -f "$config_file" ]; then
        if grep -q "$provider_id" "$config_file" 2>/dev/null; then
            log_info "配置文件验证通过: $config_file"
        else
            log_warn "配置文件可能未正确写入，请检查: $config_file"
        fi
    fi
}

# 添加环境变量到 shell 配置
add_env_to_shell() {
    local env_file="$1"
    local shell_rc=""
    
    if [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        shell_rc="$HOME/.bash_profile"
    fi
    
    if [ -n "$shell_rc" ]; then
        # 检查是否已添加
        if ! grep -q "source.*openclaw/env" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# OpenClaw 环境变量" >> "$shell_rc"
            echo "[ -f \"$env_file\" ] && source \"$env_file\"" >> "$shell_rc"
            log_info "环境变量已添加到: $shell_rc"
        fi
    fi
}

# ================================ 配置向导 ================================

# create_default_config 已移除 - OpenClaw 使用 openclaw.json 和环境变量

run_onboard_wizard() {
    log_step "运行配置向导..."
    
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🧙 OpenClaw 核心配置向导${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if confirm "使用官方配置向导 openclaw onboard（推荐，模型列表与官方同步）？" "y"; then
        if run_step_with_auto_fix "官方配置向导" run_official_onboard; then
            log_info "官方配置流程完成。"
            return 0
        fi
        if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
            log_warn "全自动模式下官方模型配置失败，已跳过回退向导以保持官方流程一致。"
            log_warn "请稍后手动执行: openclaw onboard"
            return 0
        fi
        log_warn "官方向导执行失败，将回退到内置兼容向导。"
    fi
    
    # 检查是否已有配置
    local skip_ai_config=false
    local api_test_done=false
    local env_file="$HOME/.openclaw/env"
    
    if [ -f "$env_file" ]; then
        echo -e "${YELLOW}检测到已有配置！${NC}"
        echo ""
        
        # 显示当前模型配置
        if check_command openclaw; then
            echo -e "${CYAN}当前 OpenClaw 配置:${NC}"
            openclaw models status 2>/dev/null | head -10 || true
            echo ""
        fi
        
        # 询问是否重新配置 AI
        if ! confirm "是否重新配置 AI 模型提供商？" "n"; then
            skip_ai_config=true
            log_info "使用现有 AI 配置"
            
            if confirm "是否测试现有 API 连接？" "y"; then
                # 从 env 文件读取配置进行测试
                source "$env_file"
                # 获取当前模型（优先使用官方 models status JSON）
                local current_model_ref
                current_model_ref="$(get_current_model_ref || true)"
                AI_MODEL="${current_model_ref#*/}"
                if [ -n "$ANTHROPIC_API_KEY" ]; then
                    AI_PROVIDER="anthropic"
                    AI_KEY="$ANTHROPIC_API_KEY"
                    BASE_URL="$ANTHROPIC_BASE_URL"
                elif [ -n "$MOONSHOT_API_KEY" ]; then
                    AI_PROVIDER="moonshot"
                    AI_KEY="$MOONSHOT_API_KEY"
                    BASE_URL="$MOONSHOT_BASE_URL"
                elif [ -n "$MINIMAX_API_KEY" ]; then
                    AI_PROVIDER="minimax"
                    AI_KEY="$MINIMAX_API_KEY"
                elif [ -n "$OPENROUTER_API_KEY" ]; then
                    AI_PROVIDER="openrouter"
                    AI_KEY="$OPENROUTER_API_KEY"
                    BASE_URL="$OPENROUTER_BASE_URL"
                elif [ -n "$MISTRAL_API_KEY" ]; then
                    AI_PROVIDER="mistral"
                    AI_KEY="$MISTRAL_API_KEY"
                    BASE_URL="$MISTRAL_BASE_URL"
                elif [ -n "$GROQ_API_KEY" ]; then
                    AI_PROVIDER="groq"
                    AI_KEY="$GROQ_API_KEY"
                    BASE_URL="$GROQ_BASE_URL"
                elif [ -n "$OPENAI_API_KEY" ]; then
                    AI_PROVIDER="openai"
                    AI_KEY="$OPENAI_API_KEY"
                    BASE_URL="$OPENAI_BASE_URL"
                elif [ -n "$GOOGLE_API_KEY" ]; then
                    AI_PROVIDER="google"
                    AI_KEY="$GOOGLE_API_KEY"
                    BASE_URL="$GOOGLE_BASE_URL"
                elif [ -n "$XAI_API_KEY" ]; then
                    AI_PROVIDER="xai"
                    AI_KEY="$XAI_API_KEY"
                elif [ -n "$ZAI_API_KEY" ]; then
                    AI_PROVIDER="zai"
                    AI_KEY="$ZAI_API_KEY"
                fi
                test_api_connection
                api_test_done=true
            fi
        fi
        
        echo ""
    else
        echo -e "${CYAN}接下来将引导你完成核心配置，包括:${NC}"
        echo "  1. 选择 AI 模型提供商"
        echo "  2. 配置 API 连接"
        echo "  3. 测试 API 连接"
        echo ""
    fi
    
    # AI 配置
    if [ "$skip_ai_config" = false ]; then
        setup_ai_provider
        # 先配置 OpenClaw（设置环境变量和自定义 provider），然后再测试
        configure_openclaw_model
        test_api_connection
    else
        # 即使跳过配置，也可选择测试连接
        if [ "$api_test_done" = false ] && confirm "是否测试现有 API 连接？" "y"; then
            test_api_connection
            api_test_done=true
        fi
    fi
    
    log_info "模型配置流程已完成！"
}

# ================================ AI Provider 配置 ================================

setup_ai_provider() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 1 步: 选择 AI 模型提供商${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1)  🟣 Anthropic Claude"
    echo "  2)  🟢 OpenAI GPT"
    echo "  3)  🔵 DeepSeek"
    echo "  4)  🌙 Kimi (Moonshot)"
    echo "  5)  🔴 Google Gemini"
    echo "  6)  🔄 OpenRouter (多模型网关)"
    echo "  7)  ⚡ Groq (超快推理)"
    echo "  8)  🌬️ Mistral AI"
    echo "  9)  🟠 Ollama (本地模型)"
    echo "  10) 𝕏 xAI Grok"
    echo "  11) 🇨🇳 智谱 GLM (Zai)"
    echo "  12) 🤖 MiniMax"
    echo "  13) 🆓 OpenCode (免费多模型)"
    echo "  14) ☁️ Azure OpenAI"
    echo "  15) 🧪 Google Gemini CLI"
    echo "  16) 🚀 Google Antigravity"
    echo ""
    echo -e "${GRAY}说明:${NC}"
    echo -e "${GRAY}  • 本安装向导提供官方常用提供商的快速入口（与官方文档对齐的精简集）${NC}"
    echo -e "${GRAY}  • 更多提供商（如 Venice / Qwen / Vercel Gateway 等）可在安装后运行：${NC}"
    echo -e "${GRAY}    openclaw onboard 或 bash ~/.openclaw/config-menu.sh${NC}"
    echo -e "${GRAY}  • 官方模型文档: https://docs.openclaw.ai/providers/models${NC}"
    echo -e "${GRAY}  • 支持自定义 API 地址（通过 openclaw.json 配置自定义 Provider）${NC}"
    echo ""
    echo -en "${YELLOW}请选择 AI 提供商 [1-16] (默认: 1): ${NC}"; read ai_choice < "$TTY_INPUT"
    ai_choice=${ai_choice:-1}
    
    case $ai_choice in
        1)
            AI_PROVIDER="anthropic"
            echo ""
            echo -e "${CYAN}配置 Anthropic Claude${NC}"
            echo -e "${GRAY}官方 API: https://console.anthropic.com/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) claude-sonnet-4-6 (推荐, 官方默认)"
            echo "  2) claude-opus-4-6 (最强)"
            echo "  3) claude-haiku-4-5 (快速)"
            echo "  4) claude-sonnet-4-5 (兼容)"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="claude-opus-4-6" ;;
                3) AI_MODEL="claude-haiku-4-5" ;;
                4) AI_MODEL="claude-sonnet-4-5" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="claude-sonnet-4-6" ;;
            esac
            ;;
        2)
            AI_PROVIDER="openai"
            echo ""
            echo -e "${CYAN}配置 OpenAI GPT${NC}"
            echo -e "${GRAY}官方 API: https://platform.openai.com/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gpt-5.1-codex (推荐, 官方默认)"
            echo "  2) gpt-5.4 (最新通用)"
            echo "  3) gpt-5.1"
            echo "  4) gpt-5.1-codex-mini (经济)"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gpt-5.4" ;;
                3) AI_MODEL="gpt-5.1" ;;
                4) AI_MODEL="gpt-5.1-codex-mini" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gpt-5.1-codex" ;;
            esac
            # 如果使用自定义 API 地址，询问 API 类型
            AI_API_TYPE=""
            if [ -n "$BASE_URL" ]; then
                echo ""
                echo -e "${CYAN}选择 API 兼容格式:${NC}"
                echo "  1) openai-responses (OpenAI 官方 Responses API)"
                echo "  2) openai-completions (兼容 /v1/chat/completions 端点)"
                echo -e "${GRAY}提示: 大多数第三方服务使用 openai-completions 格式${NC}"
                echo -en "${YELLOW}选择 API 格式 [1-2] (默认: 2): ${NC}"; read api_type_choice < "$TTY_INPUT"
                case $api_type_choice in
                    1) AI_API_TYPE="openai-responses" ;;
                    *) AI_API_TYPE="openai-completions" ;;
                esac
            fi
            ;;
        3)
            AI_PROVIDER="deepseek"
            echo ""
            echo -e "${CYAN}配置 DeepSeek${NC}"
            echo -e "${GRAY}官方 API: https://platform.deepseek.com/${NC}"
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.deepseek.com"}
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) deepseek-chat (V3.2, 推荐)"
            echo "  2) deepseek-reasoner (R1, 推理)"
            echo "  3) deepseek-coder"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="deepseek-reasoner" ;;
                3) AI_MODEL="deepseek-coder" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="deepseek-chat" ;;
            esac
            ;;
        4)
            AI_PROVIDER="moonshot"
            echo ""
            echo -e "${CYAN}配置 Kimi (Moonshot)${NC}"
            echo -e "${GRAY}官方控制台: https://platform.moonshot.cn/${NC}"
            echo ""
            echo "选择区域:"
            echo "  1) 国际版 API (api.moonshot.ai)"
            echo "  2) 国内版 API (api.moonshot.cn)"
            echo -en "${YELLOW}选择区域 [1-2] (默认: 1): ${NC}"; read kimi_region < "$TTY_INPUT"
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方 API): ${NC}"; read BASE_URL < "$TTY_INPUT"
            if [ -z "$BASE_URL" ]; then
                if [ "$kimi_region" = "2" ]; then
                    BASE_URL="https://api.moonshot.cn/v1"
                else
                    BASE_URL="https://api.moonshot.ai/v1"
                fi
            fi
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) kimi-k2.5 (推荐, 官方默认)"
            echo "  2) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-2] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="kimi-k2.5" ;;
            esac
            ;;
        5)
            AI_PROVIDER="google"
            echo ""
            echo -e "${CYAN}配置 Google Gemini${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            echo ""
            echo "选择模型:"
            echo "  1) gemini-3.1-pro-preview (推荐, 官方默认)"
            echo "  2) gemini-3-flash-preview"
            echo "  3) gemini-2.5-pro"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-3-flash-preview" ;;
                3) AI_MODEL="gemini-2.5-pro" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-3.1-pro-preview" ;;
            esac
            ;;
        6)
            AI_PROVIDER="openrouter"
            echo ""
            echo -e "${CYAN}配置 OpenRouter${NC}"
            echo -e "${GRAY}获取 API Key: https://openrouter.ai/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://openrouter.ai/api/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) auto (推荐, 官方默认)"
            echo "  2) anthropic/claude-opus-4.6"
            echo "  3) openai/gpt-5.1-codex"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="anthropic/claude-opus-4.6" ;;
                3) AI_MODEL="openai/gpt-5.1-codex" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="auto" ;;
            esac
            ;;
        7)
            AI_PROVIDER="groq"
            echo ""
            echo -e "${CYAN}配置 Groq${NC}"
            echo -e "${GRAY}获取 API Key: https://console.groq.com/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.groq.com/openai/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) llama-3.3-70b-versatile (推荐)"
            echo "  2) llama-3.1-8b-instant"
            echo "  3) mixtral-8x7b-32768"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="llama-3.1-8b-instant" ;;
                3) AI_MODEL="mixtral-8x7b-32768" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="llama-3.3-70b-versatile" ;;
            esac
            ;;
        8)
            AI_PROVIDER="mistral"
            echo ""
            echo -e "${CYAN}配置 Mistral AI${NC}"
            echo -e "${GRAY}获取 API Key: https://console.mistral.ai/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"https://api.mistral.ai/v1"}
            echo ""
            echo "选择模型:"
            echo "  1) mistral-large-latest (推荐)"
            echo "  2) mistral-small-latest"
            echo "  3) codestral-latest"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="mistral-small-latest" ;;
                3) AI_MODEL="codestral-latest" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="mistral-large-latest" ;;
            esac
            ;;
        9)
            AI_PROVIDER="ollama"
            AI_KEY=""
            echo ""
            echo -e "${CYAN}配置 Ollama 本地模型${NC}"
            echo ""
            echo -en "${YELLOW}Ollama 地址 (默认: http://localhost:11434): ${NC}"; read BASE_URL < "$TTY_INPUT"
            BASE_URL=${BASE_URL:-"http://localhost:11434"}
            echo ""
            echo "选择模型:"
            echo "  1) llama3"
            echo "  2) llama3:70b"
            echo "  3) mistral"
            echo "  4) 自定义"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="llama3:70b" ;;
                3) AI_MODEL="mistral" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="llama3" ;;
            esac
            ;;
        10)
            AI_PROVIDER="xai"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 xAI Grok${NC}"
            echo -e "${GRAY}获取 API Key: https://console.x.ai/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) grok-4 (推荐, 官方默认)"
            echo "  2) grok-4-fast"
            echo "  3) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-3] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="grok-4-fast" ;;
                3) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="grok-4" ;;
            esac
            ;;
        11)
            AI_PROVIDER="zai"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 智谱 GLM (Zai)${NC}"
            echo -e "${GRAY}获取 API Key: https://open.bigmodel.cn/${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) glm-5 (推荐)"
            echo "  2) glm-4.7"
            echo "  3) glm-4.7-flash"
            echo "  4) glm-4.7-flashx"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="glm-4.7" ;;
                3) AI_MODEL="glm-4.7-flash" ;;
                4) AI_MODEL="glm-4.7-flashx" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="glm-5" ;;
            esac
            ;;
        12)
            AI_PROVIDER="minimax"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 MiniMax${NC}"
            echo ""
            echo "选择区域:"
            echo "  1) 国际版 (minimax)"
            echo "  2) 国内版 (minimax-cn)"
            echo -en "${YELLOW}选择区域 [1-2] (默认: 1): ${NC}"; read region_choice < "$TTY_INPUT"
            if [ "$region_choice" = "2" ]; then
                AI_PROVIDER="minimax-cn"
                echo -e "${GRAY}获取 API Key: https://platform.minimaxi.com/${NC}"
            else
                echo -e "${GRAY}获取 API Key: https://platform.minimax.io/${NC}"
            fi
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) MiniMax-M2.5 (推荐，官方)"
            echo "  2) MiniMax-M2.5-highspeed (高速)"
            echo "  3) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-3] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="MiniMax-M2.5-highspeed" ;;
                3) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="MiniMax-M2.5" ;;
            esac
            ;;
        13)
            AI_PROVIDER="opencode"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 OpenCode${NC}"
            echo -e "${GRAY}获取 API Key: https://opencode.ai/auth${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) claude-opus-4-6 (推荐, Zen 默认)"
            echo "  2) gpt-5.1-codex"
            echo "  3) gpt-5.2"
            echo "  4) gemini-3-pro"
            echo "  5) glm-4.7"
            echo "  6) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-6] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gpt-5.1-codex" ;;
                3) AI_MODEL="gpt-5.2" ;;
                4) AI_MODEL="gemini-3-pro" ;;
                5) AI_MODEL="glm-4.7" ;;
                6) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="claude-opus-4-6" ;;
            esac
            ;;
        14)
            # Azure OpenAI 走 OpenAI 兼容协议
            AI_PROVIDER="openai"
            AI_API_TYPE="openai-completions"
            echo ""
            echo -e "${CYAN}配置 Azure OpenAI${NC}"
            echo -e "${GRAY}说明: 请输入 Azure Endpoint（示例: https://<resource>.openai.azure.com）${NC}"
            echo ""
            echo -en "${YELLOW}Azure Endpoint: ${NC}"; read azure_endpoint < "$TTY_INPUT"
            echo -en "${YELLOW}Azure 部署名(Deployment Name): ${NC}"; read azure_deployment < "$TTY_INPUT"
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            if [ -z "$azure_endpoint" ] || [ -z "$azure_deployment" ] || [ -z "$AI_KEY" ]; then
                log_warn "Azure OpenAI 信息不完整，回退到 OpenAI 默认配置"
                BASE_URL=""
                AI_MODEL="gpt-5.1-codex"
            else
                BASE_URL="${azure_endpoint%/}/openai/deployments/${azure_deployment}"
                AI_MODEL="$azure_deployment"
            fi
            ;;
        15)
            AI_PROVIDER="google-gemini-cli"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 Google Gemini CLI${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gemini-3.1-pro-preview (推荐)"
            echo "  2) gemini-3-flash-preview"
            echo "  3) gemini-3.1-flash-lite-preview"
            echo "  4) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-4] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-3-flash-preview" ;;
                3) AI_MODEL="gemini-3.1-flash-lite-preview" ;;
                4) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-3.1-pro-preview" ;;
            esac
            ;;
        16)
            AI_PROVIDER="google-antigravity"
            BASE_URL=""
            echo ""
            echo -e "${CYAN}配置 Google Antigravity${NC}"
            echo -e "${GRAY}获取 API Key: https://aistudio.google.com/apikey${NC}"
            echo ""
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            echo ""
            echo "选择模型:"
            echo "  1) gemini-3-pro-high (推荐)"
            echo "  2) gemini-3-pro-low"
            echo "  3) gemini-3-flash"
            echo "  4) claude-opus-4-6-thinking"
            echo "  5) 自定义模型名称"
            echo -en "${YELLOW}选择模型 [1-5] (默认: 1): ${NC}"; read model_choice < "$TTY_INPUT"
            case $model_choice in
                2) AI_MODEL="gemini-3-pro-low" ;;
                3) AI_MODEL="gemini-3-flash" ;;
                4) AI_MODEL="claude-opus-4-6-thinking" ;;
                5) echo -en "${YELLOW}输入模型名称: ${NC}"; read AI_MODEL < "$TTY_INPUT" ;;
                *) AI_MODEL="gemini-3-pro-high" ;;
            esac
            ;;
        *)
            # 默认使用 Anthropic
            AI_PROVIDER="anthropic"
            echo ""
            echo -e "${CYAN}配置 Anthropic Claude${NC}"
            echo -en "${YELLOW}自定义 API 地址 (留空使用官方): ${NC}"; read BASE_URL < "$TTY_INPUT"
            read_secret_input "${YELLOW}输入 API Key: ${NC}" AI_KEY
            AI_MODEL="claude-sonnet-4-6"
            ;;
    esac
    
    echo ""
    log_info "AI Provider 配置完成"
    echo -e "  提供商: ${WHITE}$AI_PROVIDER${NC}"
    echo -e "  模型: ${WHITE}$AI_MODEL${NC}"
    [ -n "$BASE_URL" ] && echo -e "  API 地址: ${WHITE}$BASE_URL${NC}"
}

# ================================ API 连接测试 ================================

test_api_connection() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 2 步: 测试 API 连接${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local test_passed=false
    
    # 确保环境变量已加载
    local env_file="$HOME/.openclaw/env"
    [ -f "$env_file" ] && source "$env_file"
    
    if ! check_command openclaw; then
        echo -e "${YELLOW}OpenClaw 未安装，跳过测试${NC}"
        return 0
    fi
    
    local current_model_ref
    current_model_ref="$(get_current_model_ref || true)"
    echo -e "${CYAN}当前模型配置:${NC}"
    openclaw models status 2>&1 | head -12
    echo ""
    [ -n "$current_model_ref" ] && echo -e "${CYAN}目标模型:${NC} ${WHITE}${current_model_ref}${NC}" && echo ""

    echo -e "${YELLOW}运行官方模型探针 (openclaw models status --probe --check)...${NC}"
    local probe_output=""
    local probe_exit=0
    set +e
    probe_output=$(openclaw models status --probe --check --json 2>&1)
    probe_exit=$?
    set -e

    if [ $probe_exit -eq 0 ]; then
        test_passed=true
        echo -e "${GREEN}✓ OpenClaw AI 测试成功（探针通过）${NC}"
    else
        echo -e "${RED}✗ 模型探针失败${NC}"
        echo "$probe_output" | head -10 | sed 's/^/  /'
        echo ""
        echo -e "${YELLOW}尝试本地 agent 调用获取详细错误...${NC}"
        local agent_output=""
        local agent_exit=1
        if [ -n "$current_model_ref" ]; then
            set +e
            agent_output=$(openclaw agent --local --model "$current_model_ref" --message "只回复 OK" 2>&1)
            agent_exit=$?
            set -e
        else
            set +e
            agent_output=$(openclaw agent --local --message "只回复 OK" 2>&1)
            agent_exit=$?
            set -e
        fi
        if [ $agent_exit -eq 0 ] && ! echo "$agent_output" | grep -qiE "error|failed|401|403|Unknown model"; then
            test_passed=true
            echo -e "${GREEN}✓ OpenClaw AI 测试成功（agent 调用通过）${NC}"
        else
            echo -e "${RED}✗ OpenClaw AI 调用失败${NC}"
            echo "$agent_output" | head -10 | sed 's/^/  /'
        fi
    fi

    if [ "$test_passed" = false ]; then
        echo -e "${RED}API 连接测试失败${NC}"
        echo ""
        echo "建议运行以下命令手动配置:"
        echo "  openclaw configure --section model"
        echo "  openclaw doctor"
        echo ""
        if confirm "是否仍然继续安装？" "y"; then
            log_warn "跳过连接测试，继续安装..."
            return 0
        else
            echo "安装已取消"
            exit 1
        fi
    fi
    
    return 0
}

# ================================ 身份配置 ================================

setup_identity() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  第 4 步: 首次欢迎与身份人设${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local bot_name="${OPENCLAW_ASSISTANT_NAME:-Clawd}"
    local user_name="${OPENCLAW_USER_NAME:-主人}"
    local region="${OPENCLAW_USER_REGION:-中国大陆}"
    local timezone="${OPENCLAW_USER_TIMEZONE:-Asia/Shanghai}"
    local user_goal="${OPENCLAW_USER_GOAL:-综合的小助理，帮我制定日程，邮件，写作，搜索，投资分析等}"
    local personality="${OPENCLAW_ASSISTANT_PERSONALITY:-严谨、适当幽默、务实}"
    local work_style="${OPENCLAW_ASSISTANT_WORK_STYLE:-整段回复，主动汇报，积极响应并调用skills}"
    local welcome_text="${OPENCLAW_WELCOME_MESSAGE:-你好我的主人，我是你的龙虾小助理，现在我已经上线了。现在你可以通过简单设置与飞书/钉钉/tele等进行配对，你就可以在通讯平台中给我布置任务啦！具体参照页面下方的配对指南}"
    local profile_doc="$CONFIG_DIR/docs/assistant-base-profile.md"

    if [ "$NO_PROMPT" != "1" ] && [ "$TTY_INPUT" != "/dev/null" ]; then
        read_input "${YELLOW}助手名称 (默认: ${bot_name}): ${NC}" bot_name
        bot_name="${bot_name:-${OPENCLAW_ASSISTANT_NAME:-Clawd}}"
        read_input "${YELLOW}机器人如何称呼你 (默认: ${user_name}): ${NC}" user_name
        user_name="${user_name:-${OPENCLAW_USER_NAME:-主人}}"
        read_input "${YELLOW}你所在地区 (默认: ${region}): ${NC}" region
        region="${region:-${OPENCLAW_USER_REGION:-中国大陆}}"
        read_input "${YELLOW}你的时区 (默认: ${timezone}): ${NC}" timezone
        timezone="${timezone:-${OPENCLAW_USER_TIMEZONE:-Asia/Shanghai}}"
        read_input "${YELLOW}你希望机器人主要做什么: ${NC}" user_goal
        user_goal="${user_goal:-${OPENCLAW_USER_GOAL:-综合的小助理，帮我制定日程，邮件，写作，搜索，投资分析等}}"
        read_input "${YELLOW}你希望机器人的性格: ${NC}" personality
        personality="${personality:-${OPENCLAW_ASSISTANT_PERSONALITY:-严谨、适当幽默、务实}}"
        read_input "${YELLOW}你希望机器人的工作方式: ${NC}" work_style
        work_style="${work_style:-${OPENCLAW_ASSISTANT_WORK_STYLE:-整段回复，主动汇报，积极响应并调用skills}}"
        echo ""
        read_input "${YELLOW}欢迎消息（留空使用默认）: ${NC}" welcome_text
        welcome_text="${welcome_text:-${OPENCLAW_WELCOME_MESSAGE:-你好我的主人，我是你的龙虾小助理，现在我已经上线了。现在你可以通过简单设置与飞书/钉钉/tele等进行配对，你就可以在通讯平台中给我布置任务啦！具体参照页面下方的配对指南}}"
    fi

    upsert_env_export_install "OPENCLAW_WELCOME_MESSAGE" "$welcome_text"
    remove_env_export_install "OPENCLAW_WELCOME_CHANNEL"
    remove_env_export_install "OPENCLAW_WELCOME_TARGET"

    if check_command openclaw; then
        openclaw config set identity.name "$bot_name" >/dev/null 2>&1 || true
        openclaw config set identity.user_name "$user_name" >/dev/null 2>&1 || true
        openclaw config set identity.region "$region" >/dev/null 2>&1 || true
        openclaw config set identity.timezone "$timezone" >/dev/null 2>&1 || true
        openclaw config set identity.goal "$user_goal" >/dev/null 2>&1 || true
        openclaw config set identity.personality "$personality" >/dev/null 2>&1 || true
        openclaw config set identity.work_style "$work_style" >/dev/null 2>&1 || true
        openclaw config set identity.greeting "$welcome_text" >/dev/null 2>&1 || true
        openclaw config set identity.welcome.message "$welcome_text" >/dev/null 2>&1 || true
        openclaw config unset identity.welcome.channel >/dev/null 2>&1 || true
        openclaw config unset identity.welcome.target >/dev/null 2>&1 || true
        # 使首次会话时更容易读取到该人设
        openclaw config set "boot-md.enabled" true >/dev/null 2>&1 || true
        openclaw config set "session-memory.enabled" true >/dev/null 2>&1 || true
    fi

    mkdir -p "$CONFIG_DIR/docs" 2>/dev/null || true
    cat > "$profile_doc" <<EOF
# OpenClaw 基础人设配置

- 助手名称: ${bot_name}
- 用户称呼: ${user_name}
- 所在地区: ${region}
- 时区: ${timezone}
- 用户目标: ${user_goal}
- 机器人性格: ${personality}
- 机器人工作方式: ${work_style}

## 首次欢迎语
${welcome_text}

## 渠道配置入口
- 命令: \`bash ~/.openclaw/config-menu.sh\`
- 文档:
  - ${WELCOME_DOC_URL_GITEE}
  - ${WELCOME_DOC_URL_GITHUB}

## 启动后自动欢迎发送
- 类型: 通用欢迎语（不区分消息渠道）
EOF
    chmod 600 "$profile_doc" 2>/dev/null || true

    echo ""
    log_info "首次欢迎与身份人设已写入"
    echo -e "  助手名称: ${WHITE}$bot_name${NC}"
    echo -e "  用户称呼: ${WHITE}$user_name${NC}"
    echo -e "  时区: ${WHITE}$timezone${NC}"
    echo -e "  人设文档: ${WHITE}$profile_doc${NC}"
}

build_post_install_welcome_message() {
    local welcome_text
    welcome_text="$(openclaw config get identity.welcome.message 2>/dev/null || true)"
    if [ -z "$welcome_text" ] || [ "$welcome_text" = "undefined" ] || [ "$welcome_text" = "null" ]; then
        welcome_text="$(openclaw config get identity.greeting 2>/dev/null || true)"
    fi
    if [ -z "$welcome_text" ] || [ "$welcome_text" = "undefined" ] || [ "$welcome_text" = "null" ]; then
        welcome_text="${OPENCLAW_WELCOME_MESSAGE:-你好我的主人，我是你的龙虾小助理，现在我已经上线了。现在你可以通过简单设置与飞书/钉钉/tele等进行配对，你就可以在通讯平台中给我布置任务啦！具体参照页面下方的配对指南}"
    fi

    cat <<EOF
${welcome_text}

渠道配置入口：
- bash ~/.openclaw/config-menu.sh
- ${WELCOME_DOC_URL_GITEE}
- ${WELCOME_DOC_URL_GITHUB}
EOF
}

send_post_install_welcome_message() {
    if ! check_command openclaw; then
        return 0
    fi

    local welcome_message
    welcome_message="$(build_post_install_welcome_message)"
    mkdir -p "$CONFIG_DIR/docs" 2>/dev/null || true
    cat > "$CONFIG_DIR/docs/startup-welcome-message.md" <<EOF
${welcome_message}
EOF
    chmod 600 "$CONFIG_DIR/docs/startup-welcome-message.md" 2>/dev/null || true
    log_info "欢迎语已更新为通用文案（不再按渠道/目标自动探测发送）"
    return 0
}

apply_default_welcome_after_session_reset() {
    local welcome_text
    welcome_text="${OPENCLAW_WELCOME_MESSAGE:-你好我的主人，我是你的龙虾小助理，现在我已经上线了。现在你可以通过简单设置与飞书/钉钉/tele等进行配对，你就可以在通讯平台中给我布置任务啦！具体参照页面下方的配对指南}"
    upsert_env_export_install "OPENCLAW_WELCOME_MESSAGE" "$welcome_text"
    remove_env_export_install "OPENCLAW_WELCOME_CHANNEL"
    remove_env_export_install "OPENCLAW_WELCOME_TARGET"

    if check_command openclaw; then
        # 仅写入欢迎语相关字段，不做身份初始化。
        openclaw config set identity.greeting "$welcome_text" >/dev/null 2>&1 || true
        openclaw config set identity.welcome.message "$welcome_text" >/dev/null 2>&1 || true
        openclaw config unset identity.welcome.channel >/dev/null 2>&1 || true
        openclaw config unset identity.welcome.target >/dev/null 2>&1 || true
    fi

    send_post_install_welcome_message || true
}

reset_gateway_chat_history_for_fresh_start() {
    if [ "$NO_PROMPT" != "1" ] && [ "$TTY_INPUT" != "/dev/null" ]; then
        local default_answer="y"
        [ "$RESET_CHAT_AFTER_INSTALL" = "0" ] && default_answer="n"
        echo ""
        echo -e "${CYAN}聊天历史处理${NC}"
        echo -e "${GRAY}说明: 仅清理会话聊天记录，不删除 API Key、插件与渠道安装包。${NC}"
        if confirm "安装完成后是否清理历史会话（进入 Gateway 像首次使用）？" "$default_answer"; then
            RESET_CHAT_AFTER_INSTALL="1"
        else
            RESET_CHAT_AFTER_INSTALL="0"
        fi
    fi

    upsert_env_export_install "OPENCLAW_RESET_CHAT_AFTER_INSTALL" "$RESET_CHAT_AFTER_INSTALL"
    if [ "$RESET_CHAT_AFTER_INSTALL" != "1" ]; then
        log_info "已保留历史聊天记录（OPENCLAW_RESET_CHAT_AFTER_INSTALL=0）"
        return 0
    fi

    log_step "重置 Gateway 聊天历史（保留配置与插件）..."
    local session_dir="$CONFIG_DIR/agents/main/sessions"
    local keep_rule_file="$session_dir/vendor-control-session.md"
    local session_state_file="$CONFIG_DIR/agents/main/agent/SESSION-STATE.md"

    if check_command openclaw; then
        openclaw sessions cleanup >/dev/null 2>&1 || true
    fi

    if [ -d "$session_dir" ]; then
        if [ -f "$keep_rule_file" ]; then
            find "$session_dir" -mindepth 1 ! -path "$keep_rule_file" -exec rm -rf {} + 2>/dev/null || true
        else
            find "$session_dir" -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
        fi
    fi

    rm -f "$session_state_file" 2>/dev/null || true
    log_info "聊天历史已重置；下次进入将以新会话显示欢迎语。"
    return 0
}


# ================================ 服务管理 ================================

cleanup_legacy_gateway_runtime() {
    # 历史版本可能创建了 /etc/systemd/system/openclaw.service，需先停用避免双实例
    if check_command systemctl; then
        if [ -f /etc/systemd/system/openclaw.service ] || systemctl list-unit-files 2>/dev/null | grep -q '^openclaw\.service'; then
            log_warn "检测到遗留 openclaw.service，正在停用以避免 Gateway 端口冲突..."
            run_as_root systemctl disable --now openclaw.service >/dev/null 2>&1 || true
            run_as_root systemctl daemon-reload >/dev/null 2>&1 || true
        fi
    fi

    if check_command openclaw; then
        openclaw gateway stop >/dev/null 2>&1 || true
    fi

    if check_command pkill; then
        pkill -f "openclaw-gateway" >/dev/null 2>&1 || true
        pkill -f "openclaw gateway" >/dev/null 2>&1 || true
    fi
}

enforce_gateway_service_precedence() {
    if ! check_command systemctl; then
        return 0
    fi

    local has_gateway_service=0
    if systemctl list-unit-files 2>/dev/null | grep -q '^openclaw-gateway\.service'; then
        has_gateway_service=1
    elif systemctl status openclaw-gateway.service >/dev/null 2>&1; then
        has_gateway_service=1
    fi

    if [ "$has_gateway_service" -eq 1 ]; then
        run_as_root systemctl disable --now openclaw.service >/dev/null 2>&1 || true
        run_as_root systemctl mask openclaw.service >/dev/null 2>&1 || true
        run_as_root systemctl daemon-reload >/dev/null 2>&1 || true
        log_info "已收敛服务：保留 openclaw-gateway.service，禁用并屏蔽 openclaw.service"
    fi
}

install_official_gateway_service() {
    local log_file
    log_file="$(mktemp /tmp/openclaw-gateway-install.XXXXXX.log)"

    if openclaw gateway install --force --port "$GATEWAY_PORT" >"$log_file" 2>&1; then
        log_info "官方 Gateway 服务已安装（--force --port ${GATEWAY_PORT}）"
        rm -f "$log_file" 2>/dev/null || true
        return 0
    fi

    if openclaw gateway install --force >"$log_file" 2>&1; then
        log_warn "当前版本不支持 --port，已按配置端口安装官方 Gateway 服务"
        rm -f "$log_file" 2>/dev/null || true
        return 0
    fi

    if openclaw gateway install >"$log_file" 2>&1; then
        log_warn "当前版本不支持 --force，已安装官方 Gateway 服务"
        rm -f "$log_file" 2>/dev/null || true
        return 0
    fi

    log_error "官方 Gateway 服务安装失败"
    tail -20 "$log_file" 2>/dev/null | sed 's/^/  /'
    rm -f "$log_file" 2>/dev/null || true
    return 1
}

converge_gateway_single_instance() {
    local mode="${1:-restart}" # install-only | restart
    local restart_output=""

    if ! check_command openclaw; then
        log_error "未检测到 openclaw 命令，无法收敛 Gateway 服务"
        return 1
    fi

    log_step "收敛 Gateway 为单实例（bind=${GATEWAY_BIND}, port=${GATEWAY_PORT}）..."
    cleanup_legacy_gateway_runtime
    normalize_channel_policy_in_json_install || true

    openclaw config set gateway.mode local >/dev/null 2>&1 || true
    openclaw config set gateway.bind "$GATEWAY_BIND" >/dev/null 2>&1 || true
    if [ "$GATEWAY_BIND" = "custom" ] && [ -n "$GATEWAY_CUSTOM_BIND_HOST" ]; then
        openclaw config set gateway.customBindHost "$GATEWAY_CUSTOM_BIND_HOST" >/dev/null 2>&1 || true
    fi
    openclaw config set gateway.port "$GATEWAY_PORT" >/dev/null 2>&1 || true
    apply_dashboard_pairing_bypass_install

    if ! install_official_gateway_service; then
        return 1
    fi

    enforce_gateway_service_precedence

    if [ "$mode" = "install-only" ]; then
        GATEWAY_CONVERGED_ONCE=1
        : > "$GATEWAY_CONVERGE_MARKER" 2>/dev/null || true
        log_info "Gateway 单实例服务收敛完成（未启动）"
        return 0
    fi

    restart_output="$(openclaw gateway restart 2>&1)" || true
    sleep 2

    local gateway_pid
    gateway_pid="$(get_gateway_pid)"
    if [ -z "$gateway_pid" ]; then
        restart_output="$(openclaw gateway start 2>&1)" || true
        sleep 2
        gateway_pid="$(get_gateway_pid)"
    fi

    if [ -n "$gateway_pid" ]; then
        GATEWAY_CONVERGED_ONCE=1
        : > "$GATEWAY_CONVERGE_MARKER" 2>/dev/null || true
        log_info "Gateway 已单实例运行 (PID: $gateway_pid, bind=${GATEWAY_BIND}, port=${GATEWAY_PORT})"
        openclaw gateway status 2>/dev/null | head -8 | sed 's/^/  /' || true
        return 0
    fi

    log_error "Gateway 启动失败，未检测到端口监听: $GATEWAY_PORT"
    echo "$restart_output" | head -15 | sed 's/^/  /'
    if check_command ss; then
        ss -lntp 2>/dev/null | grep -E "(:${GATEWAY_PORT}\\b|openclaw)" | head -10 | sed 's/^/  /' || true
    fi
    return 1
}

setup_daemon() {
    if confirm "是否设置开机自启动？" "y"; then
        if ! converge_gateway_single_instance "install-only"; then
            return 1
        fi
        log_info "已切换为官方 Gateway 服务管理（避免多实例冲突）"
    else
        log_info "跳过开机自启动配置"
    fi
}

# ================================ 完成安装 ================================

print_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                    🎉 安装完成！🎉${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}配置目录:${NC}"
    echo "  OpenClaw 配置: ~/.openclaw/"
    echo "  环境变量配置: ~/.openclaw/env"
    echo ""
    echo -e "${CYAN}常用命令:${NC}"
    echo "  openclaw gateway start   # 后台启动服务"
    echo "  openclaw gateway stop    # 停止服务"
    echo "  openclaw gateway status  # 查看状态"
    echo "  openclaw models status   # 查看模型配置"
    echo "  openclaw channels list   # 查看渠道列表"
    echo "  openclaw doctor          # 诊断问题"
    echo "  ~/.openclaw/docs/channels-configuration-guide.md  # 渠道配置文档"
    echo "  ~/.openclaw/skills/channel-setup-assistant/SKILL.md  # 渠道配置 Skill"
    echo "  ~/.openclaw/skills/      # 默认技能包目录"
    echo "  ~/.openclaw/policy/vendor-control-profile.json  # token规划规则档位配置"
    echo "  ~/.openclaw/policy/vendor-control-prompts.md    # 三档提示词"
    echo ""
    echo -e "${PURPLE}📚 官方文档: $OFFICIAL_DOCS_URL${NC}"
    echo -e "${PURPLE}💬 社区支持: https://github.com/$GITHUB_REPO/discussions${NC}"
    echo ""
}

# 启动 OpenClaw Gateway 服务
start_openclaw_service() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🚀 启动 OpenClaw 服务${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 使用端口检测判断是否已有服务在运行（更可靠）
    local existing_pid
    existing_pid=$(get_gateway_pid)
    if [ -n "$existing_pid" ]; then
        log_warn "OpenClaw Gateway 已在运行 (PID: $existing_pid)"
        echo ""
        if confirm "是否重启服务？" "y"; then
            openclaw gateway stop 2>/dev/null || true
            sleep 2
        else
            return 0
        fi
    fi

    if [ "${GATEWAY_CONVERGED_ONCE:-0}" = "1" ] || [ -f "$GATEWAY_CONVERGE_MARKER" ]; then
        log_info "已在本次安装中完成 Gateway 单实例收敛，跳过重复收敛。"
        openclaw gateway restart >/dev/null 2>&1 || openclaw gateway start >/dev/null 2>&1 || true
        sleep 2
    else
        if ! converge_gateway_single_instance "restart"; then
            log_error "Gateway 启动失败，请先执行: openclaw doctor --fix"
            return 1
        fi
    fi

    # 使用端口检测判断服务是否启动成功（更可靠）
    local gateway_pid
    gateway_pid=$(get_gateway_pid)
    if [ -n "$gateway_pid" ]; then
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}           ✓ OpenClaw Gateway 已启动！(PID: $gateway_pid)${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${CYAN}查看状态:${NC} openclaw gateway status"
        echo -e "  ${CYAN}查看日志:${NC} tail -f /tmp/openclaw-gateway.log"
        echo -e "  ${CYAN}停止服务:${NC} openclaw gateway stop"
        echo ""
        log_info "OpenClaw 现在可以接收消息了！"
        send_post_install_welcome_message || true
    else
        log_error "Gateway 启动失败"
        echo -e "${YELLOW}排查命令:${NC} openclaw gateway status && openclaw doctor --fix"
    fi
}

# 下载并运行配置菜单
run_config_menu() {
    local menu_args=("$@")
    local config_menu_path="./config-menu.sh"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local local_config_menu="$script_dir/config-menu.sh"
    local menu_script=""
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           🔧 启动配置菜单${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # 检查本地是否已有配置菜单
    local has_local_menu=false
    if [ -f "$local_config_menu" ]; then
        has_local_menu=true
        menu_script="$local_config_menu"
    elif [ -f "$config_menu_path" ]; then
        has_local_menu=true
        menu_script="$config_menu_path"
    fi
    
    # 如果本地已有配置菜单，询问是否更新
    if [ "$has_local_menu" = true ]; then
        log_info "检测到本地配置菜单: $menu_script"
        echo ""
        if confirm "是否从 GitHub 更新到最新版本？" "n"; then
            log_step "从 GitHub 下载最新配置菜单..."
            if download_with_fallback "$config_menu_path.tmp" "$GITHUB_RAW_URL/config-menu.sh" "$INSTALLER_MIRROR_RAW_URL/config-menu.sh"; then
                mv "$config_menu_path.tmp" "$config_menu_path"
                chmod +x "$config_menu_path"
                log_info "配置菜单已更新: $config_menu_path"
                menu_script="$config_menu_path"
            else
                rm -f "$config_menu_path.tmp" 2>/dev/null
                log_warn "下载失败，继续使用本地版本"
            fi
        else
            log_info "使用本地配置菜单"
        fi
    else
        # 本地没有配置菜单，从 GitHub 下载
        log_step "从 GitHub 下载配置菜单..."
        if download_with_fallback "$config_menu_path.tmp" "$GITHUB_RAW_URL/config-menu.sh" "$INSTALLER_MIRROR_RAW_URL/config-menu.sh"; then
            mv "$config_menu_path.tmp" "$config_menu_path"
            chmod +x "$config_menu_path"
            log_info "配置菜单已下载: $config_menu_path"
            menu_script="$config_menu_path"
        else
            rm -f "$config_menu_path.tmp" 2>/dev/null
            log_error "配置菜单下载失败"
            echo -e "${YELLOW}你可以稍后手动下载运行:${NC}"
            echo "  bash -c 'set -e; tmp=\"\$(mktemp)\"; for u in \"$GITHUB_RAW_URL/config-menu.sh\" \"$INSTALLER_MIRROR_RAW_URL/config-menu.sh\"; do if curl -fsSL --proto \"=https\" --tlsv1.2 --connect-timeout ${CURL_CONNECT_TIMEOUT} --max-time ${CURL_MAX_TIME} \"\$u\" -o \"\$tmp\"; then bash \"\$tmp\"; rm -f \"\$tmp\"; exit 0; fi; done; rm -f \"\$tmp\"; echo \"All sources failed\"; exit 1'"
            return 1
        fi
    fi
    
    # 确保有执行权限
    chmod +x "$menu_script" 2>/dev/null || true
    
    # 启动配置菜单（使用 /dev/tty 确保交互正常）
    echo ""
    if [ -e /dev/tty ] && ( : < /dev/tty ) 2>/dev/null; then
        bash "$menu_script" "${menu_args[@]}" < /dev/tty
    else
        bash "$menu_script" "${menu_args[@]}"
    fi
    return $?
}

# ================================ 主函数 ================================

main() {
    parse_args "$@"
    if [ "$HELP" = "1" ]; then
        print_usage
        exit 0
    fi
    normalize_install_options

    print_banner
    print_install_plan
    
    echo -e "${YELLOW}⚠️  警告: OpenClaw 需要完全的计算机权限${NC}"
    echo -e "${YELLOW}    不建议在主要工作电脑上安装，建议使用专用服务器或虚拟机${NC}"
    echo ""

    if [ "$DRY_RUN" = "1" ]; then
        log_info "dry-run 模式：仅输出计划，不执行安装"
        exit 0
    fi

    if ! confirm "是否继续安装？"; then
        echo "安装已取消"
        exit 0
    fi
    
    echo ""
    detect_os
    check_root
    ensure_sudo_privileges
    install_dependencies
    create_directories
    install_channel_assets
    if ! run_step_with_auto_fix "安装 OpenClaw" install_openclaw; then
        log_error "OpenClaw 安装失败"
        exit 1
    fi
    cleanup_stale_plugin_state
    log_info "默认消息渠道插件自动安装已关闭（改为手动安装，避免安装阶段耗时与失败重试）。"
    if [ "$NO_ONBOARD" = "1" ]; then
        log_info "已按参数跳过 AI 初始化向导 (--no-onboard)"
    else
        if ! run_step_with_auto_fix "安装后配置向导" run_onboard_wizard; then
            log_warn "安装后配置向导未完成，可稍后手动运行: openclaw onboard"
        fi
    fi
    apply_default_feishu_runtime_flags
    log_info "已禁用安装阶段机器人初始化设置，保持 OpenClaw 默认身份配置。"
    apply_vendor_rule_profile
    apply_default_security_baseline
    reset_gateway_chat_history_for_fresh_start
    apply_default_welcome_after_session_reset
    if ! run_step_with_auto_fix "设置开机守护进程" setup_daemon; then
        log_warn "守护进程设置失败，安装继续完成；稍后可手动执行: openclaw gateway install --force --port ${GATEWAY_PORT}"
    fi
    print_success
    
    # 询问是否启动服务
    if confirm "是否现在启动 OpenClaw 服务？" "y"; then
        if ! start_openclaw_service; then
            log_warn "安装已完成，但 Gateway 暂未成功启动。可稍后执行: openclaw doctor --fix && openclaw gateway restart"
        fi
    else
        echo ""
        echo -e "${CYAN}稍后可以通过以下命令启动服务:${NC}"
        echo "  openclaw gateway restart"
        echo ""
    fi
    
    # 询问是否打开配置菜单进行详细配置
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}           📝 配置菜单（命令行版）${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GRAY}配置菜单支持: 官方/非官方渠道、Skills 管理、安全配置、服务管理等${NC}"
    echo ""
    echo -e "${WHITE}💡 下次可以直接运行配置菜单:${NC}"
    echo -e "   ${CYAN}bash ./config-menu.sh${NC}"
    echo ""
    if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
        log_info "全自动模式：已跳过配置菜单，请按需手动执行: bash ./config-menu.sh"
    else
        if confirm "是否现在打开配置菜单？" "n"; then
            if ! run_config_menu; then
                log_warn "配置菜单启动失败或被中断，可稍后手动运行: bash ./config-menu.sh"
            fi
        else
            echo ""
            echo -e "${CYAN}稍后可以通过以下命令打开配置菜单:${NC}"
            echo "  bash ./config-menu.sh"
            echo ""
        fi
    fi
    
    echo ""
    echo -e "${GREEN}🦞 OpenClaw 安装完成！祝你使用愉快！${NC}"
    echo ""
}

# 始终输出收尾提示，避免用户感知“无响应直接退出”
trap 'print_exit_hint "$?"' EXIT

# 执行主函数
main "$@"
