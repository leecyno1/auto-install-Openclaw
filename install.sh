#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════════════╗
# ║   🦞 OpenClaw 一键部署脚本 v2.0.0 (重构版)                            ║
# ║   官方优先 + 自定义可选 + 低内存优化 + 批量部署支持                      ║
# ║                                                                      ║
# ║   用法:                                                              ║
# ║     curl -fsSL <url>/install.sh | bash                               ║
# ║     curl -fsSL <url>/install.sh | bash -s -- --auto-confirm-all      ║
# ╚══════════════════════════════════════════════════════════════════════╝
#

set -e

# ================================ 加载共享库 ================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_LIB="$SCRIPT_DIR/scripts/lib/openclaw-custom.sh"
if [ -f "$CUSTOM_LIB" ]; then
    # shellcheck disable=SC1090
    source "$CUSTOM_LIB"
fi

# ================================ 内联核心函数（确保 curl|bash 模式下可用）================
# 注意：共享库在 curl|bash 模式下可能因路径问题加载失败，
# 因此必须内联所有在 install.sh 中使用的核心函数

# 颜色定义
[ -z "$RED" ] && RED='\033[0;31m'
[ -z "$GREEN" ] && GREEN='\033[0;32m'
[ -z "$YELLOW" ] && YELLOW='\033[1;33m'
[ -z "$BLUE" ] && BLUE='\033[0;34m'
[ -z "$PURPLE" ] && PURPLE='\033[0;35m'
[ -z "$CYAN" ] && CYAN='\033[0;36m'
[ -z "$WHITE" ] && WHITE='\033[1;37m'
[ -z "$GRAY" ] && GRAY='\033[0;90m'
[ -z "$NC" ] && NC='\033[0m'

# 日志函数
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }
check_command() { command -v "$1" >/dev/null 2>&1; }

# Persona 角色系统
CUSTOM_LIB_PERSONA_LOADED=0
load_persona_system() {
    [ "$CUSTOM_LIB_PERSONA_LOADED" -eq 1 ] && return 0
    CUSTOM_LIB_PERSONA_LOADED=1
    PERSONA_ROLE_ID=""
    PERSONA_ROLE_NAME=""
    PERSONA_ROLE_EMOJI=""
    PERSONA_ROLE_DESC=""
    PERSONA_ROLE_AGENCY=""
    PERSONA_ROLE_DEFAULT_GOAL=""
    PERSONA_ROLE_DEFAULT_STYLE=""
    PERSONA_ROLE_DEFAULT_WORK=""
    PERSONA_ROLE_CORE_SKILLS=""
    PERSONA_ROLE_EXTRA_SKILLS=""
}

set_persona_role() {
    load_persona_system
    local role
    role="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | xargs)"
    PERSONA_ROLE_ID="$role"

    case "$role" in
        druid)
            PERSONA_ROLE_NAME="综合助理（通用）"
            PERSONA_ROLE_EMOJI="🦞"
            PERSONA_ROLE_DESC="通用总管，覆盖日常助理、任务推进、沟通协作与结果回报。"
            PERSONA_ROLE_AGENCY="specialized/agents-orchestrator + project-management/project-manager-senior"
            PERSONA_ROLE_DEFAULT_GOAL="综合的小助理，帮我制定日程，邮件，写作，搜索，投资分析等"
            PERSONA_ROLE_DEFAULT_STYLE="严谨、适当幽默、务实"
            PERSONA_ROLE_DEFAULT_WORK="整段回复，主动汇报，积极响应并调用skills"
            PERSONA_ROLE_CORE_SKILLS="proactive-agent, openclaw-cron-setup, reflection, find-skills, shell, web-search, summarize, docx, xlsx, agentmail"
            PERSONA_ROLE_EXTRA_SKILLS="task, todo, todoist-api, ai-meeting-notes, openclaw-feeds, weather"
            ;;
        assassin)
            PERSONA_ROLE_NAME="分析研究（投资）"
            PERSONA_ROLE_EMOJI="🗡️"
            PERSONA_ROLE_DESC="券商式深挖分析，负责数据采集、价值挖掘与投资机会研究。"
            PERSONA_ROLE_AGENCY="sales/sales-pipeline-analyst + support/support-finance-tracker + product/product-trend-researcher"
            PERSONA_ROLE_DEFAULT_GOAL="帮我做投资研究、机会筛选、估值拆解和风险提示"
            PERSONA_ROLE_DEFAULT_STYLE="冷静、数据驱动、结论导向"
            PERSONA_ROLE_DEFAULT_WORK="先给结论与风险，再给证据链与可执行建议"
            PERSONA_ROLE_CORE_SKILLS="akshare-stock, stock-monitor-skill, multi-search-engine, web-search, tavily-search, news-radar, summarize, url-to-markdown, xlsx"
            PERSONA_ROLE_EXTRA_SKILLS="finance-data, data-analyst, google-trends, openclaw-feeds, reddit, requesthunt, producthunt, session-logs"
            ;;
        mage)
            PERSONA_ROLE_NAME="学术研究"
            PERSONA_ROLE_EMOJI="🧙"
            PERSONA_ROLE_DESC="学术与知识生产角色，擅长论文、科研、读书与结构化笔记。"
            PERSONA_ROLE_AGENCY="marketing/marketing-book-co-author + specialized/specialized-document-generator + testing/testing-evidence-collector"
            PERSONA_ROLE_DEFAULT_GOAL="帮我完成论文写作、科研资料整理、读书笔记与知识沉淀"
            PERSONA_ROLE_DEFAULT_STYLE="严谨、学术化、条理清晰"
            PERSONA_ROLE_DEFAULT_WORK="先给研究框架与提纲，再给逐步产出与引用建议"
            PERSONA_ROLE_CORE_SKILLS="brainstorming, summarize, web-search, tavily-search, url-to-markdown, docx, pdf, nano-pdf, pptx, xlsx"
            PERSONA_ROLE_EXTRA_SKILLS="ai-meeting-notes, paperless-docs, paperless-ngx-tools, format-pro, byterover"
            ;;
        summoner)
            PERSONA_ROLE_NAME="团队管理"
            PERSONA_ROLE_EMOJI="🪄"
            PERSONA_ROLE_DESC="企业管理角色，覆盖招聘、人力、流程、组织协同与团队激励。"
            PERSONA_ROLE_AGENCY="specialized/recruitment-specialist + project-management/project-management-studio-operations + project-management/project-manager-senior"
            PERSONA_ROLE_DEFAULT_GOAL="帮我管理团队目标、人员分工、流程制度和执行节奏"
            PERSONA_ROLE_DEFAULT_STYLE="稳健、结构化、目标导向"
            PERSONA_ROLE_DEFAULT_WORK="先给优先级和里程碑，再给分工、风险和跟进机制"
            PERSONA_ROLE_CORE_SKILLS="proactive-agent, openclaw-cron-setup, docx, xlsx, pptx, agentmail, github, reflection"
            PERSONA_ROLE_EXTRA_SKILLS="task, todo, todoist-api, ai-meeting-notes, lark-calendar, data-reconciliation-exceptions, publish-guard, session-logs"
            ;;
        warrior)
            PERSONA_ROLE_NAME="工程开发"
            PERSONA_ROLE_EMOJI="⚔️"
            PERSONA_ROLE_DESC="工程交付角色，负责编码实现、测试排障、稳定性与上线。"
            PERSONA_ROLE_AGENCY="engineering/engineering-senior-developer + engineering/engineering-code-reviewer + engineering/engineering-devops-automator + engineering/engineering-sre"
            PERSONA_ROLE_DEFAULT_GOAL="帮我做编程工程交付、代码测试、故障排查和上线保障"
            PERSONA_ROLE_DEFAULT_STYLE="直接、工程化、可验证"
            PERSONA_ROLE_DEFAULT_WORK="先给可运行结果，再给验证步骤和回滚方案"
            PERSONA_ROLE_CORE_SKILLS="shell, github, mcp-builder, chrome-devtools-mcp, agent-browser, model-usage, web-search, minimax-image-understanding, reflection"
            PERSONA_ROLE_EXTRA_SKILLS="tdd, test-driven-development, subagent-driven-development, skill-security-auditor, github-actions-generator, gitclassic, prisma-database-setup, database, preflight-checks, tmux"
            ;;
        paladin)
            PERSONA_ROLE_NAME="市场增长"
            PERSONA_ROLE_EMOJI="🛡️"
            PERSONA_ROLE_DESC="增长运营角色，覆盖SEO、广告、内容分发、客户关系与客服协同。"
            PERSONA_ROLE_AGENCY="marketing/marketing-growth-hacker + marketing/marketing-seo-specialist + marketing/marketing-social-media-strategist + marketing/marketing-content-creator"
            PERSONA_ROLE_DEFAULT_GOAL="帮我做市场运营、内容增长、渠道分发、SEO和客户关系管理"
            PERSONA_ROLE_DEFAULT_STYLE="增长导向、创意与数据并重"
            PERSONA_ROLE_DEFAULT_WORK="先给增长目标与漏斗，再给渠道方案、内容节奏和复盘指标"
            PERSONA_ROLE_CORE_SKILLS="web-search, tavily-search, news-radar, summarize, url-to-markdown, docx, xlsx, agentmail, frontend-design, web-design"
            PERSONA_ROLE_EXTRA_SKILLS="programmatic-seo, seo-geo, social-content, content-strategy, google-trends, twitter, weibo-manager, weibo-fresh-posts, xiaohongshu-ops, xiaohongshu-auto, douyin-hot-trend, douyin-upload-skill, baoyu-post-to-wechat, baoyu-post-to-x"
            ;;
        designer)
            PERSONA_ROLE_NAME="设计创作"
            PERSONA_ROLE_EMOJI="🏹"
            PERSONA_ROLE_DESC="综合设计角色，覆盖前端设计、艺术设计、UI/UX、平面/工业/建筑概念与自媒体视觉。"
            PERSONA_ROLE_AGENCY="design/design-ui-designer + design/design-ux-architect + design/design-visual-storyteller + design/design-image-prompt-engineer"
            PERSONA_ROLE_DEFAULT_GOAL="帮我做前端界面设计、视觉创作、图文内容与多场景设计方案"
            PERSONA_ROLE_DEFAULT_STYLE="审美驱动、可落地、强调风格一致性"
            PERSONA_ROLE_DEFAULT_WORK="先给风格方向与版式，再给素材清单、实现路径和交付规格"
            PERSONA_ROLE_CORE_SKILLS="frontend-design, web-design, gemini-image-service, grok-imagine-1.0-video, pptx, docx, summarize"
            PERSONA_ROLE_EXTRA_SKILLS="ai-image-generation, logo-creator, infographic-pro, baoyu-article-illustrator, baoyu-comic, baoyu-cover-image, baoyu-infographic, baoyu-slide-deck, video-frames, tailwind-design-system, web-design-guidelines"
            ;;
        *)
            PERSONA_ROLE_ID="druid"
            PERSONA_ROLE_NAME="综合助理（通用）"
            PERSONA_ROLE_EMOJI="🦞"
            PERSONA_ROLE_DESC="通用总管，覆盖日常助理、任务推进、沟通协作与结果回报。"
            PERSONA_ROLE_AGENCY="specialized/agents-orchestrator + project-management/project-manager-senior"
            PERSONA_ROLE_DEFAULT_GOAL="综合的小助理，帮我制定日程，邮件，写作，搜索，投资分析等"
            PERSONA_ROLE_DEFAULT_STYLE="严谨、适当幽默、务实"
            PERSONA_ROLE_DEFAULT_WORK="整段回复，主动汇报，积极响应并调用skills"
            PERSONA_ROLE_CORE_SKILLS="proactive-agent, openclaw-cron-setup, reflection, find-skills, shell, web-search, summarize, docx, xlsx, agentmail"
            PERSONA_ROLE_EXTRA_SKILLS="task, todo, todoist-api, ai-meeting-notes, openclaw-feeds, weather"
            ;;
    esac
}

# 技能档位
CORE_SKILLS="capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator subagent-driven-development using-superpowers verification-before-completion writing-skills agent-browser chrome-devtools-mcp github mcp-builder model-usage shell minimax-image-understanding minimax-web-search minimax-pdf minimax-docx minimax-xlsx tavily-search web-search news-radar url-to-markdown pdf nano-pdf docx pptx xlsx stock-monitor-skill multi-search-engine content-strategy social-content ai-image-generation media-downloader marketingskills inference-skills agentmail agentmail-cli agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill skill-security-auditor weather data-analyst task todo"
EXTENDED_SKILLS="animation akshare-stock gemini-image-service oracle paperless-docs paperless-ngx-tools writing-plans planning-with-files finance-data"
SUPER_SKILLS="baoyu-skills baoyu-article-illustrator baoyu-comic baoyu-compress-image baoyu-cover-image baoyu-danger-gemini-web baoyu-danger-x-to-markdown baoyu-format-markdown baoyu-image-gen baoyu-infographic baoyu-markdown-to-html baoyu-post-to-wechat baoyu-post-to-weibo baoyu-post-to-x baoyu-slide-deck baoyu-translate baoyu-url-to-markdown baoyu-xhs-images baoyu-youtube-transcript"

PROFILE_BASIC_SKILLS="${CORE_SKILLS}"
PROFILE_EXTENDED_SKILLS="${CORE_SKILLS} ${EXTENDED_SKILLS}"
PROFILE_SUPER_SKILLS="${CORE_SKILLS} ${EXTENDED_SKILLS} ${SUPER_SKILLS}"

get_profile_skill_list() {
    local level
    level="$(echo "${1:-medium}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$level" in
        none) echo "" ;;
        low|l)   echo "$PROFILE_BASIC_SKILLS" ;;
        medium|m|mid) echo "$PROFILE_EXTENDED_SKILLS" ;;
        high|h)  echo "$PROFILE_SUPER_SKILLS" ;;
        *)       echo "$PROFILE_EXTENDED_SKILLS" ;;
    esac
}

# Token 档位
get_profile_token_limits() {
    local level
    level="$(echo "${1:-medium}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$level" in
        none)  echo "0 0 0 0" ;;
        low)   echo "5 100 600000 24000" ;;
        medium) echo "5 300 2400000 48000" ;;
        high)  echo "5 0 6000000 80000" ;;
        *)     echo "5 300 2400000 48000" ;;
    esac
}

get_profile_media_limits() {
    local level
    level="$(echo "${1:-medium}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$level" in
        none|low) echo "0 0" ;;
        medium)   echo "20 1" ;;
        high)     echo "50 2" ;;
        *)        echo "20 1" ;;
    esac
}

# 规范化函数
normalize_rule_profile_level() {
    local level
    level="$(echo "${1:-medium}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
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
        loopback|lan|tailnet|auto|custom) echo "$raw"; return 0 ;;
        127.0.0.1|localhost|::1) echo "loopback"; return 0 ;;
        0.0.0.0|::|all) echo "lan"; return 0 ;;
        "")
            case "$host" in
                ""|127.0.0.1|localhost|::1) echo "loopback" ;;
                0.0.0.0|::|all) echo "lan" ;;
                tailnet) echo "tailnet" ;;
                auto|loopback|lan|custom) echo "$host" ;;
                *) echo "custom" ;;
            esac
            return 0
            ;;
    esac
    echo "loopback"
}

get_gateway_bind_display_host() {
    local bind="$1" custom_host="$2"
    case "$bind" in
        loopback) echo "127.0.0.1" ;;
        lan)      echo "0.0.0.0" ;;
        tailnet)  echo "tailnet" ;;
        auto)     echo "auto" ;;
        custom)   echo "${custom_host:-custom}" ;;
        *)        echo "127.0.0.1" ;;
    esac
}

# ================================ Windows 引导 ================================
detect_and_guide_windows() {
    [[ "${OSTYPE}" == "msys" || "${OSTYPE}" == "cygwin" || "${OSTYPE}" == "win32" ]] && return 0
    grep -qi "microsoft\|wsl" /proc/version 2>/dev/null && return 0
    if [[ -n "${WINDIR:-}" || -n "${ProgramFiles:-}" ]]; then
        echo "检测到 Windows环境，请使用 WSL2 或 Git Bash 运行此脚本。"
        echo "  方案 A: wsl --install -d Ubuntu  (推荐)"
        echo "  方案 B: 安装 Git Bash"
        exit 1
    fi
}
detect_and_guide_windows

# ================================ TTY 检测 ================================
resolve_tty_input() {
    if [ -t 0 ]; then echo "/dev/stdin"; return 0; fi
    if [ -e /dev/tty ] && ( : < /dev/tty ) 2>/dev/null; then echo "/dev/tty"; return 0; fi
    if [ -r /dev/stdin ]; then echo "/dev/stdin"; return 0; fi
    echo "/dev/null"
}
TTY_INPUT="$(resolve_tty_input)"

# ================================ 配置变量 ================================
# 兼容旧环境变量
for old_new in "CLAWDBOT_NO_ONBOARD:OPENCLAW_NO_ONBOARD" "CLAWDBOT_NO_PROMPT:OPENCLAW_NO_PROMPT" \
               "CLAWDBOT_DRY_RUN:OPENCLAW_DRY_RUN" "CLAWDBOT_INSTALL_METHOD:OPENCLAW_INSTALL_METHOD" \
               "CLAWDBOT_VERSION:OPENCLAW_VERSION" "CLAWDBOT_BETA:OPENCLAW_BETA"; do
    old="${old_new%%:*}" new="${old_new##*:}"
    [ -z "${!new:-}" ] && [ -n "${!old:-}" ] && export "$new=${!old}"
done

CONFIG_DIR="$HOME/.openclaw"
MIN_NODE_MAJOR=22
MIN_NODE_MINOR=14
INSTALLER_VERSION="2.0.0"
INSTALLER_NAME="auto-install-Openclaw"

# 下载与重试配置
CURL_CONNECT_TIMEOUT="${OPENCLAW_CURL_CONNECT_TIMEOUT:-8}"
CURL_MAX_TIME="${OPENCLAW_CURL_MAX_TIME:-30}"
DOWNLOAD_RETRIES="${OPENCLAW_DOWNLOAD_RETRIES:-3}"
DOWNLOAD_BACKOFF_SECONDS="${OPENCLAW_DOWNLOAD_BACKOFF_SECONDS:-2}"

# 安装参数
OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
INSTALL_METHOD="${OPENCLAW_INSTALL_METHOD:-npm}"
USE_BETA="${OPENCLAW_BETA:-0}"
NO_ONBOARD="${OPENCLAW_NO_ONBOARD:-0}"
NO_PROMPT="${OPENCLAW_NO_PROMPT:-0}"
AUTO_CONFIRM_ALL="${OPENCLAW_AUTO_CONFIRM_ALL:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"
VERBOSE="${OPENCLAW_VERBOSE:-0}"

# Gateway 配置
GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-loopback}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-13145}"

# 低内存处理（云端服务器关键功能）
AUTO_SWAP_ENABLE="${OPENCLAW_AUTO_SWAP:-1}"
SWAP_PERSIST_ENABLE="${OPENCLAW_SWAP_PERSIST:-1}"
SWAP_THRESHOLD_MB="${OPENCLAW_SWAP_THRESHOLD_MB:-4096}"
SWAP_TARGET_MB="${OPENCLAW_SWAP_TARGET_MB:-0}"
SWAP_FILE="${OPENCLAW_SWAP_FILE:-/swapfile.openclaw}"

# 自定义层开关（默认开启，可跳过）
ENABLE_CUSTOM_LAYERS="${OPENCLAW_ENABLE_CUSTOM_LAYERS:-1}"
RULE_PROFILE_SELECTED="${OPENCLAW_RULE_PROFILE:-medium}"
PERSONA_ROLE_SELECTED="${OPENCLAW_PERSONA_ROLE:-druid}"

# ================================ 工具函数 ================================

print_banner() {
    echo -e "${CYAN}"
    echo "  ___                     _      ____                   _ _   "
    echo " / _ \ _ __   ___ _ __ __| |    / ___|_ __ __ _  __ _ _(_) |_ "
    echo "| | | | '_ \ / _ \ '__/ _\` |  | |   | '__/ _\` |/ _\` | | | __|"
    echo "| |_| | |_) |  __/ | | (_| |  | |___| | | (_| | (_| | | | |_ "
    echo " \___/| .__/ \___|_|  \__,_|   \____|_|  \__,_|\__, |_|_|\__|"
    echo "      |_|                                       |___/         "
    echo -e "${NC}"
    echo -e "${WHITE}OpenClaw 一键部署 v${INSTALLER_VERSION} - 官方优先，自定义可选${NC}"
    echo -e "${GRAY}官方文档: https://docs.openclaw.ai${NC}"
    echo ""
}

print_usage() {
    cat <<EOF
用法:
  curl -fsSL <url>/install.sh | bash -s -- [选项]

核心选项:
  --auto-confirm-all, --fast    全自动模式（批量部署专用，跳过所有交互）
  --no-onboard                  跳过官方 onboarding（安装后手动配置）
  --no-prompt                   非交互模式
  --version <version>           指定 OpenClaw 版本 (默认: latest)
  --beta                        使用 beta 版本
  --dry-run                     仅打印计划，不执行

Gateway 配置:
  --gateway-bind <mode>         loopback|lan|tailnet|auto|custom (默认: loopback)
  --gateway-port <port>         Gateway 端口 (默认: 13145)

自定义层配置（官方安装后的可选增强）:
  --no-custom                   跳过所有自定义配置（仅安装官方版本）
  --rule-profile <level>        Token 档位: low|medium|high|none (默认: medium)
  --persona <role>              工作档案: druid|assassin|mage|summoner|warrior|paladin|designer
  --assistant-name <name>       机器人名称
  --user-goal <text>            用户主要目标
  --assistant-personality <text> 机器人性格

低内存优化（云端服务器）:
  --no-swap                     不自动创建 Swap 分区
  --swap-size <MB>              手动指定 Swap 大小 (默认: 自动计算)
  --swap-file <path>            Swap 文件路径 (默认: /swapfile.openclaw)

其他:
  --verbose                     详细日志输出
  --help, -h                    显示帮助

环境变量 (所有选项均可通过环境变量设置):
  OPENCLAW_AUTO_CONFIRM_ALL=1          全自动模式
  OPENCLAW_NO_ONBOARD=1                跳过 onboard
  OPENCLAW_NO_PROMPT=1                 非交互模式
  OPENCLAW_ENABLE_CUSTOM_LAYERS=0      跳过自定义层
  OPENCLAW_AUTO_SWAP=0                 不自动创建 Swap
  OPENCLAW_SWAP_THRESHOLD_MB=4096      内存低于此值时启用 Swap
  OPENCLAW_RULE_PROFILE=medium         Token 档位
  OPENCLAW_PERSONA_ROLE=druid          工作档案
  OPENCLAW_GATEWAY_BIND=loopback       Gateway 绑定模式
  OPENCLAW_GATEWAY_PORT=13145          Gateway 端口
EOF
}

confirm() {
    local message="$1" default="${2:-y}"
    if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then return 0; fi
    if [ "$NO_PROMPT" = "1" ] || [ "$TTY_INPUT" = "/dev/null" ]; then
        [ "$default" = "y" ]; return $?
    fi
    echo -en "${YELLOW}$message [$([ "$default" = "y" ] && echo "Y/n" || echo "y/N")]: ${NC}"
    local response; read response < "$TTY_INPUT"
    response=${response:-$default}
    case "$response" in [yY][eE][sS]|[yY]) return 0 ;; *) return 1 ;; esac
}

read_input() {
    local prompt="$1" var_name="$2"
    if [ "${AUTO_CONFIRM_ALL:-0}" = "1" ]; then
        printf -v "$var_name" '%s' "$(echo "$prompt" | grep -q "请选择" && echo "1" || echo "")"
        return 0
    fi
    echo -en "$prompt"; read $var_name < "$TTY_INPUT"
}

download_with_fallback() {
    local output_path="$1"; shift
    local attempts="${DOWNLOAD_RETRIES:-3}" backoff="${DOWNLOAD_BACKOFF_SECONDS:-2}"
    for url in "$@"; do
        [ -z "$url" ] && continue
        local attempt=1
        while [ "$attempt" -le "$attempts" ]; do
            if curl -fsSL --proto '=https' --tlsv1.2 --connect-timeout "$CURL_CONNECT_TIMEOUT" \
               --max-time "$CURL_MAX_TIME" "$url" -o "$output_path" 2>/dev/null; then
                log_info "下载成功: $url"
                return 0
            fi
            [ "$attempt" -lt "$attempts" ] && sleep $((backoff * attempt))
            attempt=$((attempt + 1))
        done
    done
    return 1
}

# ================================ 系统检测 ================================

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release; OS=$ID; OS_VERSION=$VERSION_ID
        else
            OS="linux"
        fi
        if command -v apt-get &>/dev/null; then PKG_MGR="apt"
        elif command -v dnf &>/dev/null; then PKG_MGR="dnf"
        elif command -v yum &>/dev/null; then PKG_MGR="yum"
        elif command -v pacman &>/dev/null; then PKG_MGR="pacman"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"; OS_VERSION=$(sw_vers -productVersion); PKG_MGR="brew"
    else
        log_error "不支持的操作系统: $OSTYPE"; exit 1
    fi
    log_info "检测到系统: $OS ${OS_VERSION:-} (包管理器: ${PKG_MGR:-未知})"
}

check_nodejs() {
    if command -v node &>/dev/null; then
        local node_major node_minor
        node_major=$(node -v | sed 's/^v//' | cut -d'.' -f1)
        node_minor=$(node -v | sed 's/^v//' | cut -d'.' -f2)
        if [ "$node_major" -gt "$MIN_NODE_MAJOR" ] || \
           { [ "$node_major" -eq "$MIN_NODE_MAJOR" ] && [ "$node_minor" -ge "$MIN_NODE_MINOR" ]; }; then
            log_info "Node.js 版本满足要求: $(node -v)"
            return 0
        fi
        log_warn "Node.js 版本过低: $(node -v)，需要 v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+"
        return 1
    fi
    log_warn "未检测到 Node.js"
    return 1
}

install_nodejs() {
    log_step "安装 Node.js ${MIN_NODE_MAJOR}.x ..."
    case "$OS" in
        macos)
            command -v brew &>/dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install node@22; brew link --overwrite node@22
            ;;
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;
        centos|rhel|fedora)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
            sudo yum install -y nodejs
            ;;
        *)
            log_error "无法自动安装 Node.js，请手动安装 v${MIN_NODE_MAJOR}.${MIN_NODE_MINOR}+"; exit 1
            ;;
    esac
    log_info "Node.js 安装完成: $(node -v)"
}

install_dependencies() {
    log_step "安装系统依赖..."
    case "$OS" in
        ubuntu|debian)
            sudo apt-get update -qq && sudo apt-get install -y -qq curl wget jq python3 python3-pip poppler-utils ffmpeg bc 2>/dev/null
            ;;
        centos|rhel|fedora)
            sudo yum install -y curl wget jq python3 python3-pip ffmpeg bc 2>/dev/null || true
            ;;
        macos)
            brew install curl jq python poppler ffmpeg 2>/dev/null || true
            ;;
    esac
    log_info "系统依赖安装完成"
}

# ================================ 低内存处理（云端服务器关键功能） ================================

get_total_mem_mb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo $(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1048576 ))
    else
        echo 0
    fi
}

get_total_swap_mb() {
    if [ -f /proc/meminfo ]; then
        awk '/SwapTotal/ {print int($2/1024)}' /proc/meminfo
    else
        echo 0
    fi
}

is_low_memory() {
    [[ "$OSTYPE" == "darwin"* ]] && return 1
    local mem_mb swap_mb
    mem_mb="$(get_total_mem_mb)"
    swap_mb="$(get_total_swap_mb)"
    [ "$mem_mb" -lt "$SWAP_THRESHOLD_MB" ] && [ "$swap_mb" -lt "$((mem_mb / 2))" ]
}

create_swap() {
    local target_mb="${1:-4096}"
    log_step "创建 Swap 分区 (${target_mb}MB)..."

    if [ -f "$SWAP_FILE" ]; then
        log_warn "Swap 文件已存在，正在重新配置..."
        sudo swapoff "$SWAP_FILE" 2>/dev/null || true
        sudo rm -f "$SWAP_FILE"
    fi

    if command -v fallocate &>/dev/null; then
        sudo fallocate -l "${target_mb}M" "$SWAP_FILE"
    else
        sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$target_mb" status=progress
    fi

    sudo chmod 600 "$SWAP_FILE"
    sudo mkswap "$SWAP_FILE"
    sudo swapon "$SWAP_FILE"

    # 持久化（重启后生效）
    if [ "$SWAP_PERSIST_ENABLE" = "1" ] && ! grep -q "$SWAP_FILE" /etc/fstab 2>/dev/null; then
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
        log_info "已添加到 /etc/fstab（持久化）"
    fi

    log_info "Swap 已启用: ${target_mb}MB (总内存: $(get_total_mem_mb)MB, 总Swap: $(get_total_swap_mb)MB)"
}

ensure_swap_for_install() {
    [ "$AUTO_SWAP_ENABLE" = "1" ] || return 0
    is_low_memory || return 0

    local mem_mb swap_mb target_mb
    mem_mb="$(get_total_mem_mb)"
    swap_mb="$(get_total_swap_mb)"

    if [ "$SWAP_TARGET_MB" -gt 0 ] 2>/dev/null; then
        target_mb="$SWAP_TARGET_MB"
    elif [ "$mem_mb" -lt 1024 ]; then
        target_mb=4096
    else
        target_mb=2048
    fi

    log_warn "检测到低内存环境（${mem_mb}MB, Swap ${swap_mb}MB），将创建 ${target_mb}MB Swap 以防 OOM..."
    create_swap "$target_mb"
    return 0
}

# ================================ 官方安装 ================================

install_openclaw_official() {
    log_step "安装 OpenClaw (官方方式: npm install -g openclaw@latest)..."

    # 检查是否已安装
    if command -v openclaw &>/dev/null; then
        log_info "OpenClaw 已安装: $(openclaw --version 2>/dev/null || echo 'installed')"
        if [ "$AUTO_CONFIRM_ALL" != "1" ]; then
            if ! confirm "检测到已安装，是否重新安装/更新？" "n"; then
                return 0
            fi
        fi
    fi

    # 低内存环境优先启用 Swap
    ensure_swap_for_install

    # 执行官方安装
    local node_opts=""
    if is_low_memory; then
        node_opts="--max-old-space-size=512"
        log_info "低内存模式: 启用 Node.js 内存优化"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        log_info "[dry-run] npm install -g openclaw@${OPENCLAW_VERSION}"
        return 0
    fi

    if NODE_OPTIONS="${node_opts}" npm install -g "openclaw@${OPENCLAW_VERSION}" 2>&1; then
        log_info "OpenClaw 安装成功: $(openclaw --version 2>/dev/null || echo 'installed')"
    else
        log_error "官方安装失败"
        exit 1
    fi

    # 确保 openclaw 在 PATH 中
    if ! command -v openclaw &>/dev/null; then
        local npm_bin
        npm_bin="$(npm config get prefix 2>/dev/null || true)/bin"
        if [ -d "$npm_bin" ]; then
            export PATH="$npm_bin:$PATH"
            hash -r 2>/dev/null || true
        fi
    fi

    # 创建 ~/.openclaw 目录
    mkdir -p "$CONFIG_DIR"/{agents/main,skills,plugins,channels,logs,backups,policy} 2>/dev/null || true
}

run_official_onboard() {
    [ "$NO_ONBOARD" = "1" ] && return 0
    command -v openclaw &>/dev/null || return 0

    log_step "运行官方配置向导 (openclaw onboard)..."

    if [ "$AUTO_CONFIRM_ALL" = "1" ] || [ "$NO_PROMPT" = "1" ]; then
        # 全自动模式：非交互快速启动
        local onboard_args=(--non-interactive --accept-risk --flow quickstart --mode local)

        # 如果环境变量中已有 API Key，自动传递
        if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
            onboard_args+=(--anthropic-api-key "$ANTHROPIC_API_KEY")
        elif [ -n "${OPENAI_API_KEY:-}" ]; then
            onboard_args+=(--openai-api-key "$OPENAI_API_KEY")
        elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
            onboard_args+=(--openrouter-api-key "$OPENROUTER_API_KEY")
        elif [ -n "${MOONSHOT_API_KEY:-}" ]; then
            onboard_args+=(--moonshot-api-key "$MOONSHOT_API_KEY")
        fi

        # Gateway 配置
        onboard_args+=(--gateway-bind "$GATEWAY_BIND" --gateway-port "$GATEWAY_PORT")

        if openclaw onboard "${onboard_args[@]}" 2>&1; then
            log_info "官方 onboard 完成"
        else
            log_warn "官方 onboard 未完全成功，可稍后手动运行: openclaw onboard"
        fi
    else
        # 交互模式：让用户通过官方向导配置
        local onboard_term
        case "${TERM:-}" in ""|dumb|unknown) onboard_term="xterm-256color" ;; *) onboard_term="$TERM" ;; esac
        env TERM="$onboard_term" COLORTERM="${COLORTERM:-truecolor}" openclaw onboard < /dev/tty 2>&1 || true
        log_info "官方 onboard 完成"
    fi
}

# ================================ 自定义增强层（可选） ================================

# 写入环境变量到 ~/.openclaw/env
upsert_env() {
    local key="$1" value="$2" env_file="$CONFIG_DIR/env"
    mkdir -p "$(dirname "$env_file")" 2>/dev/null || true
    touch "$env_file" 2>/dev/null || true
    local tmp_file; tmp_file="$(mktemp)"
    awk -v k="$key" -v v="$value" '
        BEGIN { done=0 }
        $0 ~ "^export " k "=" { print "export " k "=" v; done=1; next }
        { print }
        END { if (!done) print "export " k "=" v }
    ' "$env_file" > "$tmp_file" && mv "$tmp_file" "$env_file"
    chmod 600 "$env_file" 2>/dev/null || true
}

# 自定义层 A: 角色化档案
apply_persona_profile() {
    local role="${PERSONA_ROLE_SELECTED:-druid}"
    set_persona_role "$role"

    log_step "应用工作档案: ${PERSONA_ROLE_EMOJI} ${PERSONA_ROLE_NAME}"

    local persona_dir="$CONFIG_DIR/agents/main/persona"
    mkdir -p "$persona_dir"

    cat > "$persona_dir/SOUL.md" <<EOF
# SOUL.md - 基础人格规则

## 初始化工作档案
- ${PERSONA_ROLE_EMOJI} ${PERSONA_ROLE_NAME}
- ${PERSONA_ROLE_DESC}

## 性格
- ${PERSONA_ROLE_DEFAULT_STYLE}

## 原则
- 执行优先：有明确指令先行动，边界不清先澄清。
- 透明汇报：完成、卡住、失败都主动同步。
- 安全第一：涉及密钥、隐私、越权请求一律拒绝并给替代方案。

## 语言铁律
- 全部输出使用简体中文；英文术语需附中文解释。
- 时间统一按北京时间说明。
EOF

    cat > "$persona_dir/AGENTS.md" <<EOF
# AGENTS.md - 基础工作手册

## 工作档案
- 档案: ${PERSONA_ROLE_EMOJI} ${PERSONA_ROLE_NAME}
- 对照: ${PERSONA_ROLE_AGENCY}
- 核心技能: ${PERSONA_ROLE_CORE_SKILLS}
- 扩展技能: ${PERSONA_ROLE_EXTRA_SKILLS}

## 任务流程 (SOP)
1. 接收任务并复述目标与验收标准。
2. 先判断风险等级与权限边界，再决定执行或分派。
3. 执行中超过 5 秒的步骤转后台，前台先回执进度。
4. 完成后输出结果、证据、后续建议。
EOF

    upsert_env "OPENCLAW_PERSONA_ROLE" "$role"
    log_info "工作档案已写入: $persona_dir/"
}

# 自定义层 B: Token 档位策略
apply_token_profile() {
    local level
    level="$(normalize_rule_profile_level "$RULE_PROFILE_SELECTED")"
    [ "$level" = "none" ] && { log_info "已选择 NONE，跳过 Token 档位配置。"; return 0; }

    local limits media_limits
    limits="$(get_profile_token_limits "$level")"
    media_limits="$(get_profile_media_limits "$level")"

    local window_hours max_requests max_tokens max_tokens_per_req max_image max_video
    window_hours=$(echo "$limits" | awk '{print $1}')
    max_requests=$(echo "$limits" | awk '{print $2}')
    max_tokens=$(echo "$limits" | awk '{print $3}')
    max_tokens_per_req=$(echo "$limits" | awk '{print $4}')
    max_image=$(echo "$media_limits" | awk '{print $1}')
    max_video=$(echo "$media_limits" | awk '{print $2}')

    log_step "应用 Token 档位: ${level^^} (${window_hours}h / ${max_requests}req / ${max_tokens} tokens)"

    # 写入环境变量
    upsert_env "OPENCLAW_RULE_PROFILE" "$level"
    upsert_env "OPENCLAW_RULE_WINDOW_HOURS" "$window_hours"
    upsert_env "OPENCLAW_RULE_MAX_REQUESTS" "$max_requests"
    upsert_env "OPENCLAW_RULE_MAX_TOKENS" "$max_tokens"
    upsert_env "OPENCLAW_RULE_MAX_TOKENS_PER_REQUEST" "$max_tokens_per_req"
    upsert_env "OPENCLAW_RULE_MAX_IMAGE_REQUESTS" "$max_image"
    upsert_env "OPENCLAW_RULE_MAX_VIDEO_REQUESTS" "$max_video"

    # 通过官方 CLI 写入（如果可用）
    if command -v openclaw &>/dev/null; then
        openclaw config set "vendor.control.profile" "$level" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.rate.windowHours" "$window_hours" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.rate.maxRequests" "$max_requests" >/dev/null 2>&1 || true
        openclaw config set "vendor.control.rate.maxTokens" "$max_tokens" >/dev/null 2>&1 || true
    fi

    # 写入策略文件
    local policy_dir="$CONFIG_DIR/policy"
    mkdir -p "$policy_dir"
    cat > "$policy_dir/vendor-control-profile.json" <<EOF
{
  "version": 1,
  "profile": "${level}",
  "rateLimit": {
    "windowHours": ${window_hours},
    "maxRequests": ${max_requests},
    "maxTokens": ${max_tokens},
    "maxTokensPerRequest": ${max_tokens_per_req},
    "maxImageRequests": ${max_image},
    "maxVideoRequests": ${max_video}
  }
}
EOF

    log_info "Token 档位策略已写入"
}

# 自定义层 C: 技能包同步
sync_skills() {
    local level
    level="$(normalize_rule_profile_level "$RULE_PROFILE_SELECTED")"
    [ "$level" = "none" ] && return 0

    local skills_dir="$SCRIPT_DIR/skills/default"

    # 本地不存在时，从仓库 ZIP 下载并提取
    if [ ! -d "$skills_dir" ]; then
        log_step "从仓库下载技能包 (档位: ${level}) ..."

        local tmp_dir extract_dir target_dir skill_list downloaded failed
        tmp_dir="$(mktemp -d)"
        extract_dir="$tmp_dir/extract"
        target_dir="$CONFIG_DIR/skills"
        mkdir -p "$target_dir"
        downloaded=0; failed=0

        # 下载仓库 ZIP
        local zip_url="https://github.com/leecyno1/auto-install-openclaw/archive/refs/heads/main.zip"
        local zip_file="$tmp_dir/repo.zip"

        log_info "正在下载仓库..."
        if ! curl -fsSL --connect-timeout 15 --max-time 120 \
            -o "$zip_file" "$zip_url" 2>/dev/null; then
            log_warn "技能包下载失败，将跳过技能同步"
            rm -rf "$tmp_dir"
            return 0
        fi

        # 解压并提取 skills/default
        log_info "正在解压技能包..."
        if unzip -q "$zip_file" -d "$extract_dir" 2>/dev/null; then
            local src_dir="$extract_dir/auto-install-openclaw-main/skills/default"
            if [ -d "$src_dir" ]; then
                skill_list="$(get_profile_skill_list "$level")"
                for skill_name in $skill_list; do
                    if [ -d "$target_dir/$skill_name" ]; then
                        continue
                    fi
                    if [ -d "$src_dir/$skill_name" ]; then
                        cp -a "$src_dir/$skill_name" "$target_dir/" && \
                            downloaded=$((downloaded + 1)) || \
                            failed=$((failed + 1))
                    else
                        failed=$((failed + 1))
                    fi
                done
            else
                log_warn "skills/default 目录在仓库中不存在"
            fi
        else
            log_warn "ZIP 解压失败"
        fi

        rm -rf "$tmp_dir"
        log_info "技能下载完成: 成功 ${downloaded}, 失败 ${failed}"
        return 0
    fi

    # 本地存在时，直接复制
    log_step "同步技能包 (档位: ${level}) ..."

    local skill_list target_dir copied skipped missing
    skill_list="$(get_profile_skill_list "$level")"
    target_dir="$CONFIG_DIR/skills"
    mkdir -p "$target_dir"
    copied=0; skipped=0; missing=0

    for skill_name in $skill_list; do
        local src="$skills_dir/$skill_name" dst="$target_dir/$skill_name"
        if [ ! -d "$src" ]; then
            missing=$((missing + 1)); continue
        fi
        if [ -d "$dst" ]; then
            skipped=$((skipped + 1)); continue
        fi
        if cp -a "$src" "$dst" 2>/dev/null; then
            copied=$((copied + 1))
        fi
    done

    log_info "技能同步完成: 新增 ${copied}, 保留 ${skipped}, 缺失 ${missing}"
}

# 自定义层 D: 安装 Python 技能依赖
install_skill_python_deps() {
    [ "${OPENCLAW_INSTALL_SKILL_DEPS:-1}" = "1" ] || return 0
    command -v python3 &>/dev/null || return 0

    log_step "安装 Python 技能依赖..."
    local pkgs="${OPENCLAW_SKILL_PIP_PACKAGES:-duckduckgo-search akshare requests pyyaml pypdf pillow openpyxl python-pptx python-docx lxml defusedxml pdf2image}"
    for pkg in $pkgs; do
        python3 -m pip install --user --disable-pip-version-check -q "$pkg" 2>/dev/null || \
        python3 -m pip install --break-system-packages --disable-pip-version-check -q "$pkg" 2>/dev/null || true
    done
    log_info "Python 依赖安装完成"
}

# ================================ 自定义层菜单 ================================

run_custom_layers_wizard() {
    [ "$ENABLE_CUSTOM_LAYERS" != "1" ] && return 0
    [ "$AUTO_CONFIRM_ALL" = "1" ] && { run_all_custom_layers; return 0; }

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  官方安装已完成！是否安装自定义增强层？${NC}"
    echo -e "${GRAY}  以下均为可选配置，跳过不影响 OpenClaw 正常运行${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  [1] 安装全部增强（推荐）"
    echo "  [2] 选择性地安装"
    echo "  [3] 跳过，仅使用官方版本"
    echo ""

    local choice; read_input "${YELLOW}请选择 [1-3] (默认: 1): ${NC}" choice
    choice="${choice:-1}"

    case "$choice" in
        1) run_all_custom_layers ;;
        2) run_selective_custom_layers ;;
        3) log_info "已跳过自定义增强层";;
    esac
}

run_all_custom_layers() {
    apply_persona_profile "$PERSONA_ROLE_SELECTED"
    apply_token_profile "$RULE_PROFILE_SELECTED"
    sync_skills "$RULE_PROFILE_SELECTED"
    install_skill_python_deps
    log_info "全部自定义增强层安装完成"
}

run_selective_custom_layers() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  选择要安装的自定义功能${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  [1] 工作档案（角色化 Persona）"
    echo "  [2] Token 档位策略（限流与安全规则）"
    echo "  [3] 技能包同步（本地 Skills 仓）"
    echo "  [4] Python 技能依赖"
    echo "  [5] 安装全部"
    echo "  [6] 跳过"
    echo ""

    local choice; read_input "${YELLOW}请选择 [1-6] (默认: 1): ${NC}" choice
    choice="${choice:-1}"

    case "$choice" in
        1) apply_persona_profile "$PERSONA_ROLE_SELECTED" ;;
        2) apply_token_profile "$RULE_PROFILE_SELECTED" ;;
        3) sync_skills "$RULE_PROFILE_SELECTED" ;;
        4) install_skill_python_deps ;;
        5) run_all_custom_layers ;;
        6) log_info "已跳过自定义增强层" ;;
    esac
}

# ================================ 主流程 ================================

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --auto-confirm-all|--fast)   AUTO_CONFIRM_ALL=1; NO_PROMPT=1; NO_ONBOARD=0; shift ;;
            --no-onboard)                NO_ONBOARD=1; shift ;;
            --no-prompt)                 NO_PROMPT=1; shift ;;
            --no-custom)                 ENABLE_CUSTOM_LAYERS=0; shift ;;
            --version)                   OPENCLAW_VERSION="$2"; shift 2 ;;
            --beta)                      USE_BETA=1; shift ;;
            --dry-run)                   DRY_RUN=1; shift ;;
            --verbose)                   VERBOSE=1; shift ;;
            --gateway-bind)              GATEWAY_BIND="$2"; shift 2 ;;
            --gateway-port)              GATEWAY_PORT="$2"; shift 2 ;;
            --no-swap)                   AUTO_SWAP_ENABLE=0; shift ;;
            --swap-size)                 SWAP_TARGET_MB="$2"; shift 2 ;;
            --swap-file)                 SWAP_FILE="$2"; shift 2 ;;
            --rule-profile)              RULE_PROFILE_SELECTED="$2"; shift 2 ;;
            --persona)                   PERSONA_ROLE_SELECTED="$(echo "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;;
            --assistant-name)            export OPENCLAW_ASSISTANT_NAME="$2"; shift 2 ;;
            --user-goal)                 export OPENCLAW_USER_GOAL="$2"; shift 2 ;;
            --assistant-personality)     export OPENCLAW_ASSISTANT_PERSONALITY="$2"; shift 2 ;;
            --help|-h)                   print_usage; exit 0 ;;
            *)                           echo "忽略未知参数: $1"; shift ;;
        esac
    done
}

main() {
    parse_args "$@"
    print_banner

    # Phase 1: 环境准备
    log_step "Phase 1: 环境准备"
    detect_os

    if ! check_nodejs; then
        if confirm "是否自动安装 Node.js ${MIN_NODE_MAJOR}.x？" "y"; then
            install_nodejs
        else
            log_error "Node.js 是必需的依赖。请手动安装后重试。"; exit 1
        fi
    fi

    install_dependencies 2>/dev/null || true

    # Phase 2: 官方安装
    log_step "Phase 2: 官方安装"
    install_openclaw_official

    if [ "$NO_ONBOARD" != "1" ]; then
        run_official_onboard
    else
        log_info "已跳过官方 onboard，可稍后运行: openclaw onboard"
    fi

    # Phase 3: 自定义增强层（可选）
    if [ "$ENABLE_CUSTOM_LAYERS" = "1" ]; then
        log_step "Phase 3: 自定义增强层"
        run_custom_layers_wizard
    else
        log_info "已跳过自定义增强层"
    fi

    # 完成 - 交互引导
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  OpenClaw 安装完成！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 非全自动模式下，提供交互引导
    if [ "$AUTO_CONFIRM_ALL" != "1" ] && [ "$NO_PROMPT" != "1" ]; then
        echo -e "${CYAN}接下来要做什么？${NC}"
        echo ""
        echo "  [1] 打开 Web Dashboard  (http://127.0.0.1:${GATEWAY_PORT})"
        echo "  [2] 运行配置菜单（模型/插件/技能/工作档案）"
        echo "  [3] 启动像素小屋工作台  (http://127.0.0.1:19000)"
        echo "  [4] 仅显示常用命令，稍后手动配置"
        echo ""

        local choice
        read_input "请选择 [1-4] (默认 1): " choice
        choice="${choice:-1}"

        case "$choice" in
            1)
                log_info "正在打开 Web Dashboard..."
                openclaw dashboard 2>/dev/null || {
                    log_warn "openclaw dashboard 命令失败，请手动访问:"
                    echo -e "  ${CYAN}http://127.0.0.1:${GATEWAY_PORT}${NC}"
                }
                ;;
            2)
                log_info "正在打开配置菜单..."
                openclaw-setup config 2>/dev/null || {
                    log_warn "openclaw-setup 未找到，请手动运行:"
                    echo -e "  ${CYAN}openclaw onboard${NC}"
                }
                ;;
            3)
                log_info "正在启动像素小屋工作台..."
                openclaw-setup workbench start 2>/dev/null || {
                    log_warn "启动失败，请检查:"
                    echo -e "  ${CYAN}openclaw-setup workbench status${NC}"
                }
                ;;
            4)
                # 跳到下面的常用命令打印
                ;;
            *)
                log_info "无效选择，显示常用命令列表"
                ;;
        esac
        echo ""
    fi

    # 显示常用命令
    echo -e "${WHITE}常用命令:${NC}"
    echo "  openclaw onboard                  配置模型与渠道"
    echo "  openclaw gateway start            启动 Gateway"
    echo "  openclaw dashboard                打开 Web 控制面板"
    echo "  openclaw-setup config             打开配置菜单"
    echo "  openclaw-setup doctor             健康检查"
    echo "  openclaw-setup workbench start    启动像素小屋工作台"
    echo ""
    echo -e "${GRAY}文档: https://docs.openclaw.ai${NC}"
}

main "$@"
