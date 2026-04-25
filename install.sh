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
    if [ ! -d "$skills_dir" ]; then
        log_warn "本地技能包目录不存在，跳过技能同步。"
        return 0
    fi

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

    # 完成
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}  OpenClaw 安装完成！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
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
