#!/bin/bash
#
# ╔══════════════════════════════════════════════════════════════╗
# ║  OpenClaw 自定义增强 - 共享库                                  ║
# ║  供 install.sh / config-menu.sh / openclaw-setup.sh 共用     ║
# ╚══════════════════════════════════════════════════════════════╝
#

# ================================ 颜色定义 ================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ================================ 大圣之怒品牌色 ================================
# 红蓝交替主题：红=烈焰(行动), 蓝=深海(智慧)
BRAND_RED='\033[0;31m'          # 烈焰红 - 警示/行动/核心
BRAND_BRIGHT_RED='\033[1;31m'   # 亮红 - 标题/强调
BRAND_BLUE='\033[0;34m'         # 深海蓝 - 信息/智慧/冷静
BRAND_BRIGHT_BLUE='\033[1;34m'  # 亮蓝 - 次级标题/链接
BRAND_GOLD='\033[0;33m'         # 金箍 - 高亮/成功/品牌标识

# ================================ 基础工具函数 ================================

check_command() {
    command -v "$1" >/dev/null 2>&1
}

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# ================================ Persona 角色定义 ================================
# 7 种工作档案，仅定义一次，所有脚本共用

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
            PERSONA_ROLE_EMOJI="🐵"
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
            PERSONA_ROLE_EMOJI="🐵"
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

show_persona_cards() {
    echo -e "${CYAN}请选择初始化工作档案（7选1）:${NC}"
    echo "  [1] 🐵 综合助理（通用）   - 通用总管，适合绝大多数用户"
    echo "  [2] 🗡️ 分析研究（投资）   - 数据深挖、价值发现、投资机会"
    echo "  [3] 🧙 学术研究           - 学术科研、论文写作、知识沉淀"
    echo "  [4] 🪄 团队管理           - 团队管理、流程制度、组织协同"
    echo "  [5] ⚔️ 工程开发           - 编程交付、测试排障、工程上线"
    echo "  [6] 🛡️ 市场增长           - 市场增长、SEO投放、渠道运营"
    echo "  [7] 🏹 设计创作           - 前端/UI/视觉/平面/工业/建筑概念"
    echo ""
}

# ================================ 技能档位定义 ================================

# 核心技能（基础档）
CORE_SKILLS="capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator subagent-driven-development using-superpowers verification-before-completion writing-skills agent-browser chrome-devtools-mcp github mcp-builder model-usage shell minimax-image-understanding minimax-web-search minimax-pdf minimax-docx minimax-xlsx tavily-search web-search news-radar url-to-markdown pdf nano-pdf docx pptx xlsx stock-monitor-skill multi-search-engine content-strategy social-content ai-image-generation media-downloader marketingskills inference-skills agentmail agentmail-cli agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill skill-security-auditor weather data-analyst task todo"

# 扩展技能（仅扩展档/超级档）
EXTENDED_SKILLS="animation akshare-stock gemini-image-service oracle paperless-docs paperless-ngx-tools writing-plans planning-with-files finance-data"

# 超级技能（仅超级档，baoyu系列）
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

# ================================ Token 档位限额 ================================

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

# ================================ 规范化函数 ================================

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

# ================================ 交互工具函数 ================================

TTY_INPUT="${TTY_INPUT:-/dev/stdin}"
AUTO_CONFIRM_ALL="${AUTO_CONFIRM_ALL:-0}"
NO_PROMPT="${NO_PROMPT:-0}"

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

# ================================ 配置持久化 ================================

CONFIG_DIR="${CONFIG_DIR:-$HOME/.openclaw}"

upsert_env() {
    local key="$1" value="$2"
    local env_file="${CONFIG_DIR:-$HOME/.openclaw}/env"
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

# ================================ 技能同步 ================================

sync_skills() {
    local level
    level="$(normalize_rule_profile_level "${1:-${RULE_PROFILE_SELECTED:-medium}}")"
    [ "$level" = "none" ] && return 0

    local skills_dir="${OPENCLAW_SKILLS_DIR:-}"
    if [ -z "$skills_dir" ]; then
        local script_dir="${SCRIPT_DIR:-}"
        if [ -n "$script_dir" ]; then
            skills_dir="$script_dir/skills/default"
        fi
    fi

    # 本地不存在时，从仓库 ZIP 下载并提取
    if [ ! -d "$skills_dir" ]; then
        echo -e "${BLUE}[STEP]${NC} 从仓库下载技能包 (档位: ${level}) ..."

        local tmp_dir extract_dir target_dir skill_list downloaded failed
        tmp_dir="$(mktemp -d)"
        extract_dir="$tmp_dir/extract"
        target_dir="$CONFIG_DIR/skills"
        mkdir -p "$target_dir"
        downloaded=0; failed=0

        local zip_url="https://github.com/leecyno1/auto-install-openclaw/archive/refs/heads/main.zip"
        local zip_file="$tmp_dir/repo.zip"

        echo -e "${GREEN}[INFO]${NC} 正在下载仓库..."
        if ! curl -fsSL --connect-timeout 15 --max-time 120 \
            -o "$zip_file" "$zip_url" 2>/dev/null; then
            echo -e "${YELLOW}[WARN]${NC} 技能包下载失败，将跳过技能同步"
            rm -rf "$tmp_dir"
            return 0
        fi

        echo -e "${GREEN}[INFO]${NC} 正在解压技能包..."
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
                echo -e "${YELLOW}[WARN]${NC} skills/default 目录在仓库中不存在"
            fi
        else
            echo -e "${YELLOW}[WARN]${NC} ZIP 解压失败"
        fi

        rm -rf "$tmp_dir"
        echo -e "${GREEN}[INFO]${NC} 技能下载完成: 成功 ${downloaded}, 失败 ${failed}"
        return 0
    fi

    # 本地存在时，直接复制
    echo -e "${BLUE}[STEP]${NC} 同步技能包 (档位: ${level}) ..."

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

    echo -e "${GREEN}[INFO]${NC} 技能同步完成: 新增 ${copied}, 保留 ${skipped}, 缺失 ${missing}"
}

# ================================ Persona 应用 ================================

apply_persona_profile() {
    local role="${1:-${PERSONA_ROLE_SELECTED:-druid}}"
    set_persona_role "$role"

    log_step "应用工作档案: ${PERSONA_ROLE_EMOJI} ${PERSONA_ROLE_NAME}"

    [ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.openclaw"
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
    upsert_env "OPENCLAW_USER_GOAL" "$PERSONA_ROLE_DEFAULT_GOAL"
    upsert_env "OPENCLAW_ASSISTANT_PERSONALITY" "$PERSONA_ROLE_DEFAULT_STYLE"
    upsert_env "OPENCLAW_PERSONA_AGENCY" "$PERSONA_ROLE_AGENCY"
    log_info "工作档案已写入: $persona_dir/"
}

# ================================ Token 档位应用 ================================

apply_token_profile() {
    local level="${1:-${RULE_PROFILE_SELECTED:-medium}}"
    level="$(normalize_rule_profile_level "$level")"
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

    [ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.openclaw"

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

# ================================ Python 技能依赖 ================================

install_skill_python_deps() {
    [ "${OPENCLAW_INSTALL_SKILL_DEPS:-1}" = "1" ] || return 0
    command -v python3 &>/dev/null || return 0

    echo -e "${BLUE}[STEP]${NC} 安装 Python 技能依赖..."
    local pkgs="${OPENCLAW_SKILL_PIP_PACKAGES:-duckduckgo-search akshare requests pyyaml pypdf pillow openpyxl python-pptx python-docx lxml defusedxml pdf2image}"
    for pkg in $pkgs; do
        python3 -m pip install --user --disable-pip-version-check -q "$pkg" 2>/dev/null || \
        python3 -m pip install --break-system-packages --disable-pip-version-check -q "$pkg" 2>/dev/null || true
    done
    echo -e "${GREEN}[INFO]${NC} Python 依赖安装完成"
}

# ================================ 网站集成 ================================

# 网站连接配置
WEBSITE_SERVER_IP="${OPENCLAW_WEBSITE_SERVER_IP:-60.205.58.39}"
WEBSITE_SERVER_USER="${OPENCLAW_WEBSITE_SERVER_USER:-root}"
WEBSITE_DOMAIN="${OPENCLAW_WEBSITE_DOMAIN:-monkeykingfury.com}"
WEBSITE_PORT="${OPENCLAW_WEBSITE_PORT:-8787}"
WEBSITE_DASHBOARD_PORT="${OPENCLAW_DASHBOARD_PORT:-13145}"

# 写入网站环境变量到 ~/.openclaw/env
write_website_env() {
    [ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.openclaw"
    mkdir -p "$CONFIG_DIR"

    log_step "写入网站集成配置..."

    upsert_env "OPENCLAW_WEBSITE_SERVER_IP" "$WEBSITE_SERVER_IP"
    upsert_env "OPENCLAW_WEBSITE_SERVER_USER" "$WEBSITE_SERVER_USER"
    upsert_env "OPENCLAW_WEBSITE_DOMAIN" "$WEBSITE_DOMAIN"
    upsert_env "OPENCLAW_WEBSITE_PORT" "$WEBSITE_PORT"
    upsert_env "OPENCLAW_DASHBOARD_PORT" "$WEBSITE_DASHBOARD_PORT"

    log_info "网站集成配置已写入: $CONFIG_DIR/env"
}

# ================================ SSH 隧道管理 ================================

# 启动 SSH 隧道（远程端口转发，让服务器访问本地 Dashboard）
ssh_tunnel_start() {
    local remote_port="${1:-$WEBSITE_DASHBOARD_PORT}"
    local local_port="${2:-$WEBSITE_DASHBOARD_PORT}"
    local server_ip="${3:-$WEBSITE_SERVER_IP}"
    local server_user="${4:-$WEBSITE_SERVER_USER}"

    # 检查是否已有隧道在运行
    if ssh_tunnel_status "$remote_port" >/dev/null 2>&1; then
        log_warn "SSH 隧道已在运行 (远程端口: $remote_port)"
        return 0
    fi

    # 检查 SSH 连接
    if ! command -v ssh &>/dev/null; then
        log_error "ssh 命令未找到，无法创建隧道"
        return 1
    fi

    log_step "启动 SSH 隧道: 本地 :${local_port} → ${server_user}@${server_ip}::${remote_port}"

    # 远程端口转发：服务器可通过 localhost:<remote_port> 访问本地 Dashboard
    if ssh -fNR "${remote_port}:127.0.0.1:${local_port}" \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ExitOnForwardFailure=yes \
        -o StrictHostKeyChecking=accept-new \
        "${server_user}@${server_ip}" 2>&1; then
        log_info "SSH 隧道已建立: 服务器 ${server_ip} 可通过 localhost:${remote_port} 访问本地 Dashboard"
    else
        log_error "SSH 隧道创建失败，请检查 SSH 密钥配置"
        return 1
    fi
}

# 停止 SSH 隧道
ssh_tunnel_stop() {
    local remote_port="${1:-$WEBSITE_DASHBOARD_PORT}"

    local pid=""
    pid="$(pgrep -f "ssh -fNR ${remote_port}:127.0.0.1" 2>/dev/null | head -1)" || true

    if [ -z "$pid" ]; then
        log_warn "未找到运行中的 SSH 隧道 (远程端口: $remote_port)"
        return 0
    fi

    kill "$pid" 2>/dev/null && log_info "SSH 隧道已停止 (PID: $pid)" || log_error "停止 SSH 隧道失败"
}

# 查看 SSH 隧道状态
ssh_tunnel_status() {
    local remote_port="${1:-$WEBSITE_DASHBOARD_PORT}"

    local pid=""
    pid="$(pgrep -f "ssh -fNR ${remote_port}:127.0.0.1" 2>/dev/null | head -1)" || true

    if [ -n "$pid" ]; then
        log_info "SSH 隧道运行中 (PID: $pid, 远程端口: $remote_port)"
        return 0
    else
        log_warn "SSH 隧道未运行"
        return 1
    fi
}

# ================================ Hermes 代理管理 ================================

# 安装 Hermes（从 GitHub 源码安装）
install_hermes() {
    log_step "安装 Hermes Agent..."

    # 检查 Python
    if ! command -v python3 &>/dev/null; then
        log_error "Python3 未安装，Hermes 需要 Python 3.10+"
        return 1
    fi

    local py_ver
    py_ver="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')" || true
    if [ "${py_ver%%.*}" -lt 3 ] 2>/dev/null || [ "${py_ver#*.}" -lt 10 ] 2>/dev/null; then
        log_error "Python 版本过低 ($py_ver)，Hermes 需要 Python 3.10+"
        return 1
    fi

    # 检查是否已安装
    if command -v hermes &>/dev/null; then
        log_info "Hermes 已安装: $(hermes --version 2>&1 | head -1)"
        return 0
    fi

    # 检查 git
    if ! command -v git &>/dev/null; then
        log_error "git 未安装，无法从 GitHub 克隆 Hermes"
        return 1
    fi

    # 从 GitHub 克隆并安装
    local install_dir="/tmp/hermes-agent"
    log_info "从 GitHub 克隆 Hermes Agent..."
    if [ -d "$install_dir" ]; then
        rm -rf "$install_dir"
    fi

    if ! git clone https://github.com/nousresearch/hermes-agent.git "$install_dir" 2>&1; then
        log_error "克隆 Hermes 仓库失败，请检查网络"
        return 1
    fi

    # pip 安装（支持 Ubuntu 24.04+ 的外部管理环境）
    log_info "安装 Hermes Agent..."
    local pip_opts="--break-system-packages --ignore-installed"
    cd "$install_dir" && python3 -m pip install $pip_opts -e . 2>&1 || {
        log_error "Hermes 安装失败，请检查 pip 权限"
        return 1
    }

    # 验证
    if command -v hermes &>/dev/null; then
        log_info "Hermes 安装成功: $(hermes --version 2>&1 | head -1)"
    else
        log_warn "Hermes 已安装但不在 PATH 中，请添加 /usr/local/bin 到 PATH"
        return 1
    fi
}

# 配置 Hermes 模型
configure_hermes_model() {
    local model="${1:-}"
    local provider="${2:-}"
    local api_url="${3:-}"
    local api_key="${4:-}"

    command -v hermes &>/dev/null || { log_error "Hermes 未安装"; return 1; }

    if [ -n "$model" ]; then
        log_step "配置 Hermes 模型: $model"
        hermes config set model.default "$model" 2>&1 || true
    fi

    if [ -n "$provider" ]; then
        log_step "配置 Hermes Provider: $provider"
        hermes config set model.provider "$provider" 2>&1 || true
    fi

    if [ -n "$api_url" ]; then
        log_step "配置 Hermes API URL: $api_url"
        hermes config set api.base_url "$api_url" 2>&1 || true
    fi

    if [ -n "$api_key" ]; then
        log_step "配置 Hermes API Key"
        hermes config set api.key "$api_key" 2>&1 || true
    fi
}

# 启动 Hermes Gateway
start_hermes_gateway() {
    command -v hermes &>/dev/null || { log_error "Hermes 未安装"; return 1; }

    # 先检查是否已在运行
    if hermes gateway status &>/dev/null 2>&1; then
        log_info "Hermes Gateway 已在运行"
        return 0
    fi

    log_step "启动 Hermes Gateway..."
    hermes gateway start 2>&1 || {
        log_warn "Gateway 启动失败，尝试前台模式安装服务..."
        hermes gateway install 2>&1 || true
        hermes gateway start 2>&1 || true
    }
}

# 停止 Hermes Gateway
stop_hermes_gateway() {
    command -v hermes &>/dev/null || { log_error "Hermes 未安装"; return 1; }
    log_step "停止 Hermes Gateway..."
    hermes gateway stop 2>&1 || true
}

# Hermes 状态
status_hermes() {
    command -v hermes &>/dev/null || { log_warn "Hermes 未安装"; return 1; }
    hermes status 2>&1
}

# ================================ 模型路由管理 ================================

# 显示当前路由/Token 档位状态
show_routing_status() {
    local config_dir="${CONFIG_DIR:-$HOME/.openclaw}"

    echo -e "${CYAN}📊 路由与 Token 档位状态${NC}"
    echo ""

    # 从 openclaw config 读取
    if command -v openclaw &>/dev/null; then
        local profile
        profile="$(openclaw config get vendor.control.profile 2>/dev/null)" || true
        if [ -n "$profile" ] && [ "$profile" != "undefined" ] && [ "$profile" != "null" ]; then
            echo -e "  ${GREEN}✅${NC} 档位: $profile"
        else
            echo -e "  ${YELLOW}⚠️${NC} 档位: 未配置"
        fi

        local window max_req max_tok
        window="$(openclaw config get vendor.control.rate.windowHours 2>/dev/null)" || true
        max_req="$(openclaw config get vendor.control.rate.maxRequests 2>/dev/null)" || true
        max_tok="$(openclaw config get vendor.control.rate.maxTokens 2>/dev/null)" || true

        echo -e "  时间窗口: ${window:-未设置}h"
        echo -e "  最大请求: ${max_req:-未设置}次"
        echo -e "  最大 Token: ${max_tok:-未设置}"
    else
        echo -e "  ${YELLOW}⚠️${NC} OpenClaw 未安装，无法读取路由状态"
    fi

    # 从 policy 文件读取
    local policy_file="$config_dir/policy/vendor-control-profile.json"
    if [ -f "$policy_file" ]; then
        echo ""
        echo -e "  ${GRAY}策略文件: $policy_file${NC}"
        if command -v jq &>/dev/null; then
            jq '.' "$policy_file" 2>/dev/null | sed 's/^/  /'
        fi
    fi
}

# 配置模型路由（独立命令，不需要完整安装流程）
configure_model_routing() {
    local level="${1:-}"

    if [ -z "$level" ]; then
        echo -e "${CYAN}选择 Token 档位:${NC}"
        echo ""
        echo "  [1] 基础档 (low)   - 5h/100次, 60万Token"
        echo "  [2] 扩展档 (medium) - 5h/300次, 240万Token"
        echo "  [3] 超级档 (high)  - 请求不限, 600万Token"
        echo "  [4] 不限 (none)    - 无限制"
        echo "  [0] 取消"
        echo ""

        read -p "请选择 [0-4]: " choice < "${TTY_INPUT:-/dev/stdin}"
        case "$choice" in
            1) level="low" ;;
            2) level="medium" ;;
            3) level="high" ;;
            4) level="none" ;;
            *) return 0 ;;
        esac
    fi

    case "$level" in
        low|medium|high|none)
            RULE_PROFILE_SELECTED="$level"
            apply_token_profile "$level"
            ;;
        *)
            log_error "无效档位: $level (可选: low/medium/high/none)"
            return 1
            ;;
    esac
}
