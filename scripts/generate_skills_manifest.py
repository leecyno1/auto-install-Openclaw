#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOUTIQUE_ROOT = Path(__file__).resolve().parents[2] / 'boutique-openclaw-skills'
SKILLS_DIR = Path(__import__('os').environ.get('OPENCLAW_SKILLS_SOURCE_DIR', BOUTIQUE_ROOT / 'skills' / 'default'))
MANIFEST = ROOT / 'skills' / 'manifest.json'

MINIMAX_OFFICIAL = set(
    'android-native-dev buddy-sings flutter-dev frontend-dev fullstack-dev gif-sticker-maker '
    'ios-application-dev minimax-docx minimax-multimodal-toolkit minimax-music-gen '
    'minimax-music-playlist minimax-pdf minimax-xlsx pptx-generator react-native-dev '
    'shader-dev vision-analysis'.split()
)
MINIMAX_LOCAL = set('minimax-image-understanding minimax-web-search'.split())
CORE = (
    set(
        'capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn '
        'brainstorming reflection find-skills skill-creator subagent-driven-development '
        'using-superpowers verification-before-completion writing-skills agent-browser '
        'chrome-devtools-mcp github mcp-builder model-usage shell tavily-search web-search '
        'news-radar url-to-markdown pdf nano-pdf docx pptx xlsx stock-monitor-skill '
        'multi-search-engine content-strategy social-content ai-image-generation '
        'media-downloader marketingskills inference-skills agentmail agentmail-cli '
        'agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill '
        'skill-security-auditor weather data-analyst task todo'.split()
    )
    | MINIMAX_OFFICIAL
    | MINIMAX_LOCAL
    | {'akshare-stock', 'finance-data'}
)
EXTENDED = set('animation gemini-image-service oracle paperless-docs paperless-ngx-tools writing-plans planning-with-files'.split())
TRADING_FINANCE = set(
    '''backtest-expert breadth-chart-analyst breakout-trade-planner canslim-screener
    data-quality-checker dividend-growth-pullback-screener downtrend-duration-analyzer
    dual-axis-skill-reviewer earnings-calendar earnings-trade-analyzer economic-calendar-fetcher
    edge-candidate-agent edge-concept-synthesizer edge-hint-extractor edge-pipeline-orchestrator
    edge-signal-aggregator edge-strategy-designer edge-strategy-reviewer exposure-coach
    finviz-screener ftd-detector ibd-distribution-day-monitor institutional-flow-tracker
    kanchi-dividend-review-monitor kanchi-dividend-sop kanchi-dividend-us-tax-accounting
    macro-regime-detector market-breadth-analyzer market-environment-analysis market-news-analyst
    market-top-detector options-strategy-advisor pair-trade-screener parabolic-short-trade-planner
    pead-screener portfolio-manager position-sizer scenario-analyzer sector-analyst signal-postmortem
    skill-designer skill-idea-miner skill-integration-tester stanley-druckenmiller-investment
    strategy-pivot-designer technical-analyst theme-detector trade-hypothesis-ideator trader-memory-core
    uptrend-analyzer us-market-bubble-detector us-stock-analysis value-dividend-screener vcp-screener
    finance-sentiment funda-data hormuz-strait company-valuation earnings-preview earnings-recap
    estimate-analysis etf-premium options-payoff saas-valuation-compression sepa-strategy
    stock-correlation stock-liquidity yfinance-data finance-skill-creator discord-reader linkedin-reader
    opencli-reader telegram-reader twitter-reader yc-reader startup-analysis generative-ui
    alphaear-deepear-lite alphaear-logic-visualizer alphaear-news alphaear-predictor alphaear-reporter
    alphaear-search alphaear-sentiment alphaear-signal-tracker alphaear-stock'''.split()
)
TRADERMONTY_SKILLS = set(
    '''backtest-expert breadth-chart-analyst breakout-trade-planner canslim-screener
    data-quality-checker dividend-growth-pullback-screener downtrend-duration-analyzer
    dual-axis-skill-reviewer earnings-calendar earnings-trade-analyzer economic-calendar-fetcher
    edge-candidate-agent edge-concept-synthesizer edge-hint-extractor edge-pipeline-orchestrator
    edge-signal-aggregator edge-strategy-designer edge-strategy-reviewer exposure-coach
    finviz-screener ftd-detector ibd-distribution-day-monitor institutional-flow-tracker
    kanchi-dividend-review-monitor kanchi-dividend-sop kanchi-dividend-us-tax-accounting
    macro-regime-detector market-breadth-analyzer market-environment-analysis market-news-analyst
    market-top-detector options-strategy-advisor pair-trade-screener parabolic-short-trade-planner
    pead-screener portfolio-manager position-sizer scenario-analyzer sector-analyst signal-postmortem
    skill-designer skill-idea-miner skill-integration-tester stanley-druckenmiller-investment
    strategy-pivot-designer technical-analyst theme-detector trade-hypothesis-ideator trader-memory-core
    uptrend-analyzer us-market-bubble-detector us-stock-analysis value-dividend-screener vcp-screener'''.split()
)
HIMSELF65_FINANCE_SKILLS = set(
    '''finance-sentiment funda-data hormuz-strait company-valuation earnings-preview earnings-recap
    estimate-analysis etf-premium options-payoff saas-valuation-compression sepa-strategy
    stock-correlation stock-liquidity yfinance-data finance-skill-creator discord-reader linkedin-reader
    opencli-reader telegram-reader twitter-reader yc-reader startup-analysis generative-ui'''.split()
)
ALPHAEAR_SKILLS = set(
    '''alphaear-deepear-lite alphaear-logic-visualizer alphaear-news alphaear-predictor alphaear-reporter
    alphaear-search alphaear-sentiment alphaear-signal-tracker alphaear-stock'''.split()
)


BAOYU_SKILLS = set(
    'baoyu-skills baoyu-article-illustrator baoyu-comic baoyu-compress-image '
    'baoyu-cover-image baoyu-danger-gemini-web baoyu-danger-x-to-markdown '
    'baoyu-format-markdown baoyu-image-gen baoyu-infographic baoyu-markdown-to-html '
    'baoyu-post-to-wechat baoyu-post-to-weibo baoyu-post-to-x baoyu-slide-deck '
    'baoyu-translate baoyu-url-to-markdown baoyu-xhs-images baoyu-youtube-transcript'.split()
)
SUPER = BAOYU_SKILLS | TRADING_FINANCE

MENU_ENHANCED = set(
    'capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn '
    'brainstorming reflection find-skills skill-creator subagent-driven-development '
    'using-superpowers verification-before-completion writing-skills agent-browser '
    'chrome-devtools-mcp github mcp-builder model-usage shell tavily-search web-search '
    'news-radar url-to-markdown pdf nano-pdf docx pptx xlsx frontend-design web-design '
    'stock-monitor-skill stock-daily-analysis-skill openclaw-stock-kb stock_datasource '
    'openclaw-stock-analyzer tushare-openclaw-skill openclaw-stock-data-skill '
    'stock-analysis openclaw-stock multi-search-engine akshare-stock content-strategy '
    'social-content ai-image-generation animation media-downloader marketingskills '
    'inference-skills gemini-image-service oracle paperless-docs paperless-ngx-tools '
    'writing-plans agentmail agentmail-cli agentmail-mcp agentmail-toolkit '
    'lark-calendar notebooklm-skill skill-security-auditor weather data-analyst '
    'finance-data task todo'.split()
) | MINIMAX_OFFICIAL | MINIMAX_LOCAL | TRADING_FINANCE
DEFAULT_SENTINELS = (
    set(
        'agentmail agentmail-cli agentmail-mcp agentmail-toolkit content-strategy '
        'social-content ai-image-generation media-downloader marketingskills inference-skills '
        'subagent-driven-development using-superpowers verification-before-completion '
        'writing-skills lark-calendar notebooklm-skill skill-security-auditor weather '
        'data-analyst finance-data task todo'.split()
    )
    | MINIMAX_OFFICIAL
    | MINIMAX_LOCAL
)
API_ENV_RE = re.compile(r'\b[A-Z][A-Z0-9_]*(?:API_KEY|TOKEN|SECRET|APP_SECRET)\b')
API_ENV_PLACEHOLDERS = {'YOUR_API_KEY'}


def parse_skill(path: Path) -> tuple[str, str, list[str]]:
    text = path.read_text(encoding='utf-8', errors='ignore')
    name = path.parent.name
    desc = ''
    declared_name = name
    frontmatter_lines: list[str] = []
    if text.startswith('---'):
        end = text.find('\n---', 3)
        if end != -1:
            frontmatter_lines = text[3:end].strip().splitlines()
            for idx, line in enumerate(frontmatter_lines):
                if line.startswith('name:'):
                    declared_name = line.split(':', 1)[1].strip().strip('"\'') or declared_name
                elif line.startswith('description:'):
                    raw = line.split(':', 1)[1].strip().strip('"\'')
                    if raw not in {'|', '>'}:
                        desc = raw
                    else:
                        parts = []
                        for follow in frontmatter_lines[idx + 1 :]:
                            if follow.startswith('  '):
                                parts.append(follow.strip())
                            else:
                                break
                        desc = ' '.join(parts).strip()
    if not desc:
        for line in text.splitlines():
            line = line.strip().lstrip('#').strip()
            if line and not line.startswith('---') and not line.startswith('name:'):
                desc = line
                break
    desc = re.sub(r'\s+', ' ', desc).strip()
    if len(desc) > 260:
        desc = desc[:257].rstrip() + '...'
    envs = sorted(set(API_ENV_RE.findall(text)) - API_ENV_PLACEHOLDERS)
    return declared_name, (desc or f'{name} skill'), envs


def build_manifest() -> dict:
    items = []
    for path in sorted(SKILLS_DIR.iterdir(), key=lambda p: p.name):
        if not path.is_dir():
            continue
        skill_file = path / 'SKILL.md'
        if not skill_file.exists():
            continue
        skill_id = path.name
        declared_name, desc, envs = parse_skill(skill_file)
        tiers = []
        if skill_id in CORE:
            tiers.append('basic')
        if skill_id in CORE or skill_id in EXTENDED:
            tiers.append('extended')
        if skill_id in CORE or skill_id in EXTENDED or skill_id in SUPER:
            tiers.append('super')
        groups = []
        if skill_id in MINIMAX_OFFICIAL:
            groups.append('minimax_official')
        if skill_id in MINIMAX_LOCAL:
            groups.append('minimax_local_compat')
        if skill_id in DEFAULT_SENTINELS:
            groups.append('default_sentinel')
        if skill_id in BAOYU_SKILLS:
            groups.append('baoyu')
        if skill_id in TRADING_FINANCE:
            groups.append('trading_finance')
        source = 'local'
        if skill_id in MINIMAX_OFFICIAL:
            source = 'github:MiniMax-AI/skills'
        elif skill_id.startswith('baoyu'):
            source = 'github:JimLiu/baoyu-skills'
        elif skill_id in {'content-strategy', 'social-content'}:
            source = 'github:coreyhaines31/marketingskills'
        elif skill_id in {'ai-image-generation', 'inference-skills'}:
            source = 'github:inference-sh/skills'
        elif skill_id in TRADERMONTY_SKILLS:
            source = 'github:tradermonty/claude-trading-skills'
        elif skill_id in HIMSELF65_FINANCE_SKILLS:
            source = 'github:himself65/finance-skills'
        elif skill_id in ALPHAEAR_SKILLS:
            source = 'github:RKiding/Awesome-finance-skills'
        items.append(
            {
                'id': skill_id,
                'name': declared_name,
                'description': desc,
                'path': f'skills/default/{skill_id}',
                'tiers': tiers,
                'groups': groups,
                'source': source,
                'requires_api_keys': bool(envs),
                'api_keys': envs,
            }
        )
    return {
        'version': 1,
        'generated_from': str(SKILLS_DIR),
        'notes': 'Installer-facing skill catalog. Scripts should read this manifest instead of growing new hardcoded lists.',
        'bundles': {
            'basic': sorted(CORE),
            'extended': sorted(CORE | EXTENDED),
            'super': sorted(CORE | EXTENDED | SUPER),
            'menu_enhanced': sorted(MENU_ENHANCED),
            'minimax_official': sorted(MINIMAX_OFFICIAL),
            'minimax_local_compat': sorted(MINIMAX_LOCAL),
            'default_sentinels': sorted(DEFAULT_SENTINELS),
            'trading_finance': sorted(TRADING_FINANCE),
        },
        'skills': items,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='fail if manifest is out of date')
    args = parser.parse_args()

    rendered = json.dumps(build_manifest(), ensure_ascii=False, indent=2) + '\n'
    current = MANIFEST.read_text(encoding='utf-8') if MANIFEST.exists() else ''
    if args.check:
        if current != rendered:
            print('skills/manifest.json is out of date', file=sys.stderr)
            return 1
        return 0
    MANIFEST.write_text(rendered, encoding='utf-8')
    print(f'wrote {MANIFEST}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
