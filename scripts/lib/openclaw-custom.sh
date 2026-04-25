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

show_persona_cards() {
    echo -e "${CYAN}请选择初始化工作档案（7选1）:${NC}"
    echo "  [1] 🦞 综合助理（通用）   - 通用总管，适合绝大多数用户"
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
