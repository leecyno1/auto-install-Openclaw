#!/usr/bin/env bash

# Shared skill catalog helpers. The installer repository no longer vendors a
# local skills/manifest.json; callers keep these functions for compatibility
# with older cached installer copies and fall back to hardcoded/boutique tier
# lists when no manifest is present.

openclaw_skills_lib_dir() {
    local src="${BASH_SOURCE[0]:-$0}"
    cd "$(dirname "$src")" >/dev/null 2>&1 && pwd
}

openclaw_repo_root_from_skills_lib() {
    local lib_dir
    lib_dir="$(openclaw_skills_lib_dir)"
    cd "$lib_dir/../.." >/dev/null 2>&1 && pwd
}

openclaw_skill_manifest_path() {
    local root="${OPENCLAW_INSTALLER_ROOT:-}"
    if [ -n "$root" ] && [ -f "$root/skills/manifest.json" ]; then
        echo "$root/skills/manifest.json"
        return 0
    fi
    root="$(openclaw_repo_root_from_skills_lib)"
    if [ -f "$root/skills/manifest.json" ]; then
        echo "$root/skills/manifest.json"
        return 0
    fi
    return 1
}

openclaw_skill_manifest_list() {
    local selector="${1:-}"
    local manifest
    manifest="$(openclaw_skill_manifest_path)" || return 1
    python3 - "$manifest" "$selector" <<'PY'
import json, sys
path, selector = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding='utf-8'))
if selector.startswith('tier:'):
    tier = selector.split(':', 1)[1]
    values = [s['id'] for s in data.get('skills', []) if tier in s.get('tiers', [])]
elif selector.startswith('group:'):
    group = selector.split(':', 1)[1]
    values = [s['id'] for s in data.get('skills', []) if group in s.get('groups', [])]
elif selector.startswith('bundles:'):
    bundle = selector.split(':', 1)[1]
    values = data.get('bundles', {}).get(bundle, [])
else:
    bundles = data.get('bundles', {})
    if selector in bundles:
        values = bundles[selector]
    else:
        values = [s['id'] for s in data.get('skills', []) if selector in s.get('groups', [])]
print(' '.join(dict.fromkeys(values)))
PY
}

openclaw_skill_manifest_default_sentinels() {
    openclaw_skill_manifest_list default_sentinels
}

openclaw_skill_manifest_description() {
    local skill_id="${1:-}"
    local manifest
    manifest="$(openclaw_skill_manifest_path)" || return 1
    python3 - "$manifest" "$skill_id" <<'PY'
import json, sys
path, skill_id = sys.argv[1], sys.argv[2]
for item in json.load(open(path, encoding='utf-8')).get('skills', []):
    if item.get('id') == skill_id:
        print(item.get('description', ''))
        break
PY
}

openclaw_skill_manifest_has_skill() {
    local skill_id="${1:-}"
    local manifest
    manifest="$(openclaw_skill_manifest_path)" || return 1
    python3 - "$manifest" "$skill_id" <<'PY'
import json, sys
path, skill_id = sys.argv[1], sys.argv[2]
skills = {s.get('id') for s in json.load(open(path, encoding='utf-8')).get('skills', [])}
sys.exit(0 if skill_id in skills else 1)
PY
}

openclaw_skill_fallback_init() {
    local mode="${1:-install}"

    MINIMAX_OFFICIAL_SKILLS="android-native-dev buddy-sings flutter-dev frontend-dev fullstack-dev gif-sticker-maker ios-application-dev minimax-docx minimax-multimodal-toolkit minimax-music-gen minimax-music-playlist minimax-pdf minimax-xlsx pptx-generator react-native-dev shader-dev vision-analysis"
    MINIMAX_LOCAL_COMPAT_SKILLS="minimax-image-understanding minimax-web-search"
    MINIMAX_SKILLS="${MINIMAX_LOCAL_COMPAT_SKILLS} ${MINIMAX_OFFICIAL_SKILLS}"
    TRADING_FINANCE_SKILLS="backtest-expert breadth-chart-analyst breakout-trade-planner canslim-screener data-quality-checker dividend-growth-pullback-screener downtrend-duration-analyzer dual-axis-skill-reviewer earnings-calendar earnings-trade-analyzer economic-calendar-fetcher edge-candidate-agent edge-concept-synthesizer edge-hint-extractor edge-pipeline-orchestrator edge-signal-aggregator edge-strategy-designer edge-strategy-reviewer exposure-coach finviz-screener ftd-detector ibd-distribution-day-monitor institutional-flow-tracker kanchi-dividend-review-monitor kanchi-dividend-sop kanchi-dividend-us-tax-accounting macro-regime-detector market-breadth-analyzer market-environment-analysis market-news-analyst market-top-detector options-strategy-advisor pair-trade-screener parabolic-short-trade-planner pead-screener portfolio-manager position-sizer scenario-analyzer sector-analyst signal-postmortem skill-designer skill-idea-miner skill-integration-tester stanley-druckenmiller-investment strategy-pivot-designer technical-analyst theme-detector trade-hypothesis-ideator trader-memory-core uptrend-analyzer us-market-bubble-detector us-stock-analysis value-dividend-screener vcp-screener finance-sentiment funda-data hormuz-strait company-valuation earnings-preview earnings-recap estimate-analysis etf-premium options-payoff saas-valuation-compression sepa-strategy stock-correlation stock-liquidity yfinance-data finance-skill-creator discord-reader linkedin-reader opencli-reader telegram-reader twitter-reader yc-reader startup-analysis generative-ui alphaear-deepear-lite alphaear-logic-visualizer alphaear-news alphaear-predictor alphaear-reporter alphaear-search alphaear-sentiment alphaear-signal-tracker alphaear-stock"

    CORE_SKILLS="capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator subagent-driven-development using-superpowers verification-before-completion writing-skills agent-browser chrome-devtools-mcp github mcp-builder model-usage shell ${MINIMAX_SKILLS} tavily-search web-search news-radar url-to-markdown pdf nano-pdf docx pptx xlsx stock-monitor-skill multi-search-engine content-strategy social-content ai-image-generation media-downloader marketingskills inference-skills agentmail agentmail-cli agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill skill-security-auditor weather data-analyst task todo"
    EXTENDED_SKILLS="animation akshare-stock gemini-image-service oracle paperless-docs paperless-ngx-tools writing-plans planning-with-files finance-data"
    SUPER_CURATED_SKILLS="baoyu-skills baoyu-article-illustrator baoyu-comic baoyu-compress-image baoyu-cover-image baoyu-danger-gemini-web baoyu-danger-x-to-markdown baoyu-format-markdown baoyu-image-gen baoyu-infographic baoyu-markdown-to-html baoyu-post-to-wechat baoyu-post-to-weibo baoyu-post-to-x baoyu-slide-deck baoyu-translate baoyu-url-to-markdown baoyu-xhs-images baoyu-youtube-transcript"
    PROFILE_BASIC_SKILLS="${CORE_SKILLS}"
    PROFILE_EXTENDED_SKILLS="${CORE_SKILLS} ${EXTENDED_SKILLS}"
    PROFILE_SUPER_SKILLS="${CORE_SKILLS} ${EXTENDED_SKILLS} ${SUPER_CURATED_SKILLS} ${TRADING_FINANCE_SKILLS}"
    DEFAULT_SKILLS_BUNDLE_SENTINELS="agentmail agentmail-cli agentmail-mcp agentmail-toolkit content-strategy social-content ai-image-generation media-downloader marketingskills inference-skills ${MINIMAX_SKILLS} subagent-driven-development using-superpowers verification-before-completion writing-skills lark-calendar notebooklm-skill skill-security-auditor weather data-analyst task todo"

    if [ "$mode" = "menu" ]; then
        ENHANCED_SKILLS_LIST="capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator subagent-driven-development using-superpowers verification-before-completion writing-skills agent-browser chrome-devtools-mcp github mcp-builder model-usage shell ${MINIMAX_SKILLS} ${TRADING_FINANCE_SKILLS} tavily-search web-search news-radar url-to-markdown pdf nano-pdf docx pptx xlsx frontend-design web-design stock-monitor-skill stock-daily-analysis-skill openclaw-stock-kb stock_datasource openclaw-stock-analyzer tushare-openclaw-skill openclaw-stock-data-skill stock-analysis openclaw-stock multi-search-engine akshare-stock content-strategy social-content ai-image-generation animation media-downloader marketingskills inference-skills gemini-image-service oracle paperless-docs paperless-ngx-tools writing-plans agentmail agentmail-cli agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill skill-security-auditor weather data-analyst finance-data task todo"
        SUPER_CURATED_SKILLS_LIST="${SUPER_CURATED_SKILLS}"
    fi
}
