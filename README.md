# 大圣之怒 OpenClaw / Hermes 安装器

<p align="center">
  <img src="photo/dasheng-openclaw-promo.png" alt="Auto-Install OpenClaw 宣传图" width="100%" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Featured-大圣之怒-red?style=for-the-badge" alt="Featured" />
  <img src="https://img.shields.io/badge/version-v2.0.0-008cff?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-111827?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/node-22.12%2B-ff2d2d?style=for-the-badge" alt="Node" />
  <img src="https://img.shields.io/badge/Gitee-default%20source-008cff?style=for-the-badge" alt="Gitee default" />
</p>

<p align="center">
  <img src="photo/openclaw-installer-logo.svg" alt="OpenClaw Installer 技术栈 Logo 卡片" width="860" />
</p>

<p align="center"><strong>一键安装 OpenClaw / Hermes，把模型、Skills、规则、像素小屋和网站联动收束到一个可重复部署的入口。</strong></p>

## 快速开始

默认国内源走 Gitee，当前验证分支是 `release/hermes-website-minimax-hardening-20260503`。

```bash
# OpenClaw
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install-openclaw.sh | bash

# Hermes
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install-hermes.sh | bash

# 双引擎
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install.sh | bash -s -- --engine both
```

全自动批量部署示例：

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install-openclaw.sh | bash -s -- \
  --auto-confirm-all \
  --provider minimax \
  --model MiniMax-M2.7-highspeed \
  --api-key "$MINIMAX_API_KEY" \
  --base-url https://api.minimaxi.com/anthropic \
  --rule-profile medium \
  --install-skills extended \
  --install-pixel-house \
  --enable-advanced-routing \
  --extra-model "id=gpt-5-5,name=GPT-5.5,base_url=https://yfy.zhouyang168.top/v1,api_key=$GPT55_API_KEY,model=gpt-5.5,api_type=openai-completions,image_tool=responses-image-generation,image_model=gpt-image-2"
```

兼容总入口：

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install.sh | bash -s -- --engine openclaw
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install.sh | bash -s -- --engine hermes
curl -fsSL https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/release/hermes-website-minimax-hardening-20260503/install.sh | bash
curl -fsSL https://mirror.ghproxy.com/https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/release/hermes-website-minimax-hardening-20260503/install.sh | bash
```

无人值守快捷命令：

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install-openclaw.sh | bash -s -- --auto-confirm-all
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install-hermes.sh | bash -s -- --auto-confirm-all
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install.sh | bash -s -- --auto-confirm-all --engine openclaw
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install.sh | bash -s -- --auto-confirm-all --engine hermes
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/release/hermes-website-minimax-hardening-20260503/install.sh | bash -s -- --auto-confirm-all --engine both
```

## 统一入口

`openclaw-setup` 是主入口，`lobster-setup` 仅作为兼容别名。

```bash
openclaw-setup install openclaw
openclaw-setup install hermes
openclaw-setup install both
openclaw-setup config
openclaw-setup repair
openclaw-setup repair minimax
openclaw-setup workbench
openclaw-setup status
openclaw-setup doctor
openclaw-setup engine
openclaw-setup backup
openclaw-setup help
```

安装后执行 `openclaw-setup config` 完成模型、Skills、规则、像素小屋与网站联动配置。对历史服务器执行 `openclaw-setup repair` 清理重复 Provider 和旧配置；MiniMax 官方/中转切换异常时执行 `openclaw-setup repair minimax`。需要可视化界面时执行 `openclaw-setup workbench`。

## Skills 仓库边界

本项目后续只负责安装器、网站接线、模型注册表、发布测试和运行时配置。默认 skills 的维护、分档、手册和来源链接迁移到独立仓库：[boutique-openclaw-skills](https://github.com/leecyno1/boutique-openclaw-skills)。技能如果需要同步从 boutique 仓库进行同步。

默认国内技能源：`OPENCLAW_SKILLS_REPO_URL=https://gitee.com/leecyno1/boutique-openclaw-skills.git`。GitHub 兜底源：`OPENCLAW_SKILLS_REPO_GITHUB_URL=https://github.com/leecyno1/boutique-openclaw-skills.git`。

| 档位 | 说明 | 命令 |
| --- | --- | --- |
| 低档 / low | 首次安装和轻量生产 | `openclaw-setup config skills --tier basic` 或 `--tier low` |
| 中档 / medium | 标准生产和常用扩展 | `openclaw-setup config skills --tier extended` 或 `--tier medium` |
| 高档 / high | 完整专家包、金融交易研究和创作套件 | `openclaw-setup config skills --tier super` 或 `--tier high` |

## 全部技能

当前 boutique catalog 共 179 个技能：L1 20 个、L2 61 个、L3 98 个；直连 115 个，API Key 49 个，浏览器 10 个，MCP 5 个。

| 档位 | Skill | 分类 | 评分 | 依赖 | 一句话说明 | 手册 | 原仓库 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 低 / 中 / 高 | `agent-browser` | 核心 Agent 能力 | ★★★★☆ | 浏览器 | Headless browser automation CLI for AI agents. Use when interacting with websites — navigat… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/agent-browser/GUIDE.md) | [原仓库](https://openclawdoc.com/docs/skills/clawhub/) |
| 低 / 中 / 高 | `brainstorming` | 核心 Agent 能力 | ★★★★★ | 无 | Use before creative feature, component, behavior, or product design work. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/brainstorming/GUIDE.md) | [原仓库](https://github.com/baz-scm/agentskills/tree/main/skills/brainstorming) |
| 低 / 中 / 高 | `chrome-devtools-mcp` | 核心 Agent 能力 | ★★★★☆ | MCP | Chrome DevTools MCP — Google's official browser automation and testing server. Control Chro… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/chrome-devtools-mcp/GUIDE.md) | [原仓库](https://github.com/ChromeDevTools/chrome-devtools-mcp) |
| 低 / 中 / 高 | `find-skills` | 核心 Agent 能力 | ★★★★★ | 无 | Helps users discover and install agent skills when they ask questions like "how do I do X",… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/find-skills/GUIDE.md) | [原仓库](https://github.com/vercel-labs/skills/tree/main/skills/find-skills) |
| 低 / 中 / 高 | `github` | 核心 Agent 能力 | ★★★★☆ | GH_TOKEN, GITHUB_TOKEN | Interact with GitHub using the `gh` CLI. Use `gh issue`, `gh pr`, `gh run`, and `gh api` fo… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/github/GUIDE.md) | [原仓库](https://github.com/github/github-mcp-server) |
| 低 / 中 / 高 | `mcp-builder` | 核心 Agent 能力 | ★★★★☆ | MCP | Use when building MCP servers or tools for external APIs and services. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/mcp-builder/GUIDE.md) | [原仓库](https://modelcontextprotocol.io/docs/getting-started/intro) |
| 低 / 中 / 高 | `model-usage` | 核心 Agent 能力 | ★★★★★ | 无 | Use CodexBar CLI local cost usage to summarize per-model usage for Codex or Claude, includi… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/model-usage/GUIDE.md) | [原仓库](https://clawhub.ai/steipete/model-usage) |
| 中 / 高 | `planning-with-files` | 核心 Agent 能力 | ★★★★★ | 无 | Use for complex multi-step tasks that need file-based plans and progress tracking. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/planning-with-files/GUIDE.md) | [原仓库](https://github.com/OthmanAdi/planning-with-files) |
| 低 / 中 / 高 | `shell` | 核心 Agent 能力 | ★☆☆☆☆ | 无 | Use shell commands for file operations, scripts, process management, diagnostics, and autom… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/shell/GUIDE.md) | [原仓库](https://github.com/leecyno1/auto-install-Openclaw/tree/release/hermes-website-minimax-hardening-20260503/skills/default/shell) |
| 低 / 中 / 高 | `skill-creator` | 核心 Agent 能力 | ★★★★★ | 无 | Guide for creating effective skills. This skill should be used when users want to create a … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/skill-creator/GUIDE.md) | [原仓库](https://github.com/anthropics/skills/tree/main/skills/skill-creator) |
| 低 / 中 / 高 | `skill-security-auditor` | 核心 Agent 能力 | ★★★★★ | 无 | Command-line security analyzer for ClawHub skills. Run analyze-skill.sh to scan SKILL.md fi… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/skill-security-auditor/GUIDE.md) | [原仓库](https://clawhub.ai/akhmittra/skill-security-auditor) |
| 低 / 中 / 高 | `subagent-driven-development` | 核心 Agent 能力 | ★★★★★ | 无 | Use when executing implementation plans with independent subagent tasks. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/subagent-driven-development/GUIDE.md) | [原仓库](https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development) |
| 低 / 中 / 高 | `task` | 核心 Agent 能力 | ★★★★★ | 无 | Tasker docstore task management via tool-dispatch. Use for task lists, due today/overdue, w… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/task/GUIDE.md) | [原仓库](https://github.com/openclaw/skills/tree/main/skills/amirbrooks/task) |
| 低 / 中 / 高 | `todo` | 核心 Agent 能力 | ★★★★★ | 无 | This skill provides instructions for interacting with Todoist using the td CLI tool. It cov… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/todo/GUIDE.md) | [原仓库](https://github.com/sachaos/todoist) |
| 低 / 中 / 高 | `url-to-markdown` | 核心 Agent 能力 | ★★★★☆ | 浏览器 | Fetch any URL and convert to markdown using Chrome CDP. Supports two modes - auto-capture o… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/url-to-markdown/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-url-to-markdown) |
| 低 / 中 / 高 | `using-superpowers` | 核心 Agent 能力 | ★★★★★ | 无 | Use when starting any conversation to check and apply relevant skills. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/using-superpowers/GUIDE.md) | [原仓库](https://github.com/obra/superpowers/tree/main/skills/using-superpowers) |
| 低 / 中 / 高 | `verification-before-completion` | 核心 Agent 能力 | ★★★★★ | 无 | Use before claiming work is complete, fixed, or passing. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/verification-before-completion/GUIDE.md) | [原仓库](https://github.com/obra/superpowers/tree/main/skills/verification-before-completion) |
| 低 / 中 / 高 | `weather` | 核心 Agent 能力 | ★★★★★ | 无 | Get current weather and forecasts (no API key required). | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/weather/GUIDE.md) | [原仓库](https://open-meteo.com/) |
| 低 / 中 / 高 | `web-search` | 核心 Agent 能力 | ★☆☆☆☆ | 浏览器 | This skill should be used when users need to search the web for information, find current c… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/web-search/GUIDE.md) | [原仓库](https://github.com/leecyno1/auto-install-Openclaw/tree/release/hermes-website-minimax-hardening-20260503/skills/default/web-search) |
| 低 / 中 / 高 | `writing-skills` | 核心 Agent 能力 | ★★★★★ | 无 | Use when creating, editing, or verifying Codex skills. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/writing-skills/GUIDE.md) | [原仓库](https://github.com/obra/superpowers/tree/main/skills/writing-skills) |
| 低 / 中 / 高 | `agentmail` | 设计 / UI | ★★★☆☆ | AGENTMAIL_API_KEY | Give AI agents their own email inboxes using the AgentMail API. Use when building email age… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/agentmail/GUIDE.md) | [原仓库](https://github.com/agentmail-to/agentmail-skills) |
| 低 / 中 / 高 | `agentmail-mcp` | 编程 / 工程工具 | ★★★★☆ | AGENTMAIL_API_KEY | AgentMail MCP server for email tools in AI assistants. Use when setting up AgentMail with C… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/agentmail-mcp/GUIDE.md) | [原仓库](https://github.com/agentmail-to/agentmail-mcp) |
| 低 / 中 / 高 | `agentmail-toolkit` | 设计 / UI | ★★★★☆ | AGENTMAIL_API_KEY, OPENAI_API_KEY | Add email capabilities to AI agents using popular frameworks. Provides pre-built tools for … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/agentmail-toolkit/GUIDE.md) | [原仓库](https://github.com/agentmail-to/agentmail-toolkit) |
| 低 / 中 / 高 | `ai-image-generation` | 金融 / 交易 | ★★★☆☆ | GEMINI_API_KEY, OPENAI_API_KEY | Generate AI images with GPT-Image-2, FLUX, Gemini, Grok, Seedream, Reve and 50+ models via … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/ai-image-generation/GUIDE.md) | [原仓库](https://github.com/inference-sh/skills/tree/main/tools/image/ai-image-generation) |
| 低 / 中 / 高 | `android-native-dev` | 编程 / 工程工具 | ★★★★☆ | 无 | Android native application development and UI design guide. Covers Material Design 3, Kotli… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/android-native-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/android-native-dev) |
| 中 / 高 | `animation` | 设计 / UI | ★★★★★ | 无 | Generate CSS and SVG animation code snippets using bash and Python. Use when building UI an… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/animation/GUIDE.md) | [原仓库](https://github.com/bytesagain/ai-skills) |
| 高 | `backtest-expert` | 编程 / 工程工具 | ★★★★★ | 无 | Expert guidance for systematic backtesting of trading strategies. Use when developing, test… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/backtest-expert/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/backtest-expert) |
| 高 | `baoyu-danger-x-to-markdown` | 设计 / UI | ★★☆☆☆ | X_AUTH_TOKEN | Converts X (Twitter) tweets and articles to markdown with YAML front matter. Uses reverse-e… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-danger-x-to-markdown/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills#baoyu-danger-x-to-markdown) |
| 高 | `baoyu-image-gen` | 编程 / 工程工具 | ★★★★☆ | ARK_API_KEY, AZURE_OPENAI_API_KEY… | [Deprecated: use baoyu-imagine] AI image generation with OpenAI, Azure OpenAI, Google, Open… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-image-gen/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-image-gen) |
| 高 | `baoyu-url-to-markdown` | 搜索 / 研究 / 情报 | ★★★★☆ | 浏览器 | Fetch any URL and convert to markdown using baoyu-fetch CLI (Chrome CDP with site-specific … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-url-to-markdown/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-url-to-markdown) |
| 高 | `baoyu-youtube-transcript` | 数据分析 | ★★★★★ | 无 | Downloads YouTube video transcripts/subtitles and cover images by URL or video ID. Supports… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-youtube-transcript/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-youtube-transcript) |
| 低 / 中 / 高 | `content-strategy` | 金融 / 交易 | ★★★★☆ | 无 | When the user wants to plan a content strategy, decide what content to create, or figure ou… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/content-strategy/GUIDE.md) | [原仓库](https://github.com/coreyhaines31/marketingskills/tree/main/skills/content-strategy) |
| 低 / 中 / 高 | `data-analyst` | 数据分析 | ★★★★★ | 无 | Data visualization, report generation, SQL queries, and spreadsheet automation. Transform y… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/data-analyst/GUIDE.md) | [原仓库](https://github.com/openclaw/skills/blob/main/skills/oyi77/data-analyst/SKILL.md) |
| 高 | `discord-reader` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/discord-reader/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/social-readers/skills/discord-reader) |
| 低 / 中 / 高 | `docx` | 文档 / 办公 | ★☆☆☆☆ | 无 | Comprehensive document creation, editing, and analysis with support for tracked changes, co… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/docx/GUIDE.md) | [原仓库](https://github.com/leecyno1/auto-install-Openclaw/tree/release/hermes-website-minimax-hardening-20260503/skills/default/docx) |
| 高 | `dual-axis-skill-reviewer` | 数据分析 | ★★★★★ | 无 | Review skills in any project using a dual-axis method: (1) deterministic code-based checks … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/dual-axis-skill-reviewer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/dual-axis-skill-reviewer) |
| 高 | `edge-concept-synthesizer` | 设计 / UI | ★★★★★ | 无 | Abstract detector tickets and hints into reusable edge concepts with thesis, invalidation s… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-concept-synthesizer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-concept-synthesizer) |
| 高 | `edge-pipeline-orchestrator` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | Orchestrate the full edge research pipeline from candidate detection through strategy desig… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-pipeline-orchestrator/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-pipeline-orchestrator) |
| 高 | `edge-signal-aggregator` | 数据分析 | ★★★★★ | 无 | Aggregate and rank signals from multiple edge-finding skills (edge-candidate-agent, theme-d… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-signal-aggregator/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-signal-aggregator) |
| 高 | `edge-strategy-designer` | 设计 / UI | ★★★★★ | 无 | Convert abstract edge concepts into strategy draft variants and optional exportable ticket … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-strategy-designer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-strategy-designer) |
| 低 / 中 / 高 | `finance-data` | 金融 / 交易 | ★★★★☆ | MCP | Comprehensive financial data retrieval from OpenBB MCP and AKShare API. Query stock prices,… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/finance-data/GUIDE.md) | [原仓库](https://github.com/OpenBB-finance/OpenBB) |
| 低 / 中 / 高 | `flutter-dev` | 编程 / 工程工具 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/flutter-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/flutter-dev) |
| 低 / 中 / 高 | `frontend-dev` | 编程 / 工程工具 | ★★★★☆ | 无 | Use when building or improving high-quality frontend pages, components, dashboards, or apps. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/frontend-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/frontend-dev) |
| 低 / 中 / 高 | `fullstack-dev` | 编程 / 工程工具 | ★★★☆☆ | JWT_SECRET | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/fullstack-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/fullstack-dev) |
| 高 | `generative-ui` | 设计 / UI | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/generative-ui/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/ui-tools/skills/generative-ui) |
| 低 / 中 / 高 | `ios-application-dev` | 编程 / 工程工具 | ★★★★☆ | 无 | Use for iOS development, signing, TestFlight, App Store, privacy, or China-region release t… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/ios-application-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/ios-application-dev) |
| 低 / 中 / 高 | `lark-calendar` | 文档 / 办公 | ★★★★☆ | FEISHU_APP_SECRET | Create, update, and delete calendar events and tasks in Lark (Feishu). Includes employee di… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/lark-calendar/GUIDE.md) | [原仓库](https://github.com/larksuite/oapi-sdk-nodejs) |
| 高 | `linkedin-reader` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/linkedin-reader/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/social-readers/skills/linkedin-reader) |
| 低 / 中 / 高 | `media-downloader` | 媒体生成 / 处理 | ★★★☆☆ | PEXELS_API_KEY | \|- | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/media-downloader/GUIDE.md) | [原仓库](https://github.com/yizhiyanhua-ai/media-downloader.git) |
| 低 / 中 / 高 | `minimax-docx` | 文档 / 办公 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-docx/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-docx) |
| 低 / 中 / 高 | `minimax-multimodal-toolkit` | 搜索 / 研究 / 情报 | ★★★☆☆ | MINIMAX_API_KEY | Use mmx to generate text, images, video, speech, and music via the MiniMax AI platform. Use… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-multimodal-toolkit/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-multimodal-toolkit) |
| 低 / 中 / 高 | `minimax-pdf` | 文档 / 办公 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-pdf/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-pdf) |
| 低 / 中 / 高 | `minimax-web-search` | 搜索 / 研究 / 情报 | ★★★★☆ | MINIMAX_API_KEY | 使用 MiniMax MCP 进行网络搜索。触发条件：(1) 用户要求进行网络搜索、在线搜索、查找信息 (2) 需要查询最新资讯、新闻、资料 (3) 使用 MiniMax 的 web… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-web-search/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-web-search) |
| 低 / 中 / 高 | `minimax-xlsx` | 数据分析 | ★★★★☆ | 无 | Open, create, read, analyze, edit, or validate Excel/spreadsheet files (.xlsx, .xlsm, .csv,… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-xlsx/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-xlsx) |
| 低 / 中 / 高 | `multi-search-engine` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | Multi search engine integration with 16 engines (7 CN + 9 Global). Supports advanced search… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/multi-search-engine/GUIDE.md) | [原仓库](https://clawhub.ai/gpyAngyoujun/multi-search-engine) |
| 低 / 中 / 高 | `nano-pdf` | 文档 / 办公 | ★★★★★ | 无 | Edit PDFs with natural-language instructions using the nano-pdf CLI. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/nano-pdf/GUIDE.md) | [原仓库](https://github.com/steipete/clawdis/tree/main/skills/nano-pdf) |
| 低 / 中 / 高 | `news-radar` | 搜索 / 研究 / 情报 | ★★★★☆ | MCP | Comprehensive news aggregation from TrendRadar MCP server with focus on high-frequency inte… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/news-radar/GUIDE.md) | [原仓库](https://github.com/airinghost/TrendRadar) |
| 低 / 中 / 高 | `notebooklm-skill` | 浏览器 / 自动化 | ★★★☆☆ | GEMINI_API_KEY | Use this skill to query your Google NotebookLM notebooks directly from Claude Code for sour… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/notebooklm-skill/GUIDE.md) | [原仓库](https://github.com/PleasePrompto/notebooklm-skill) |
| 低 / 中 / 高 | `openclaw-cron-setup` | 多 Agent / 自动调度 | ★★★★☆ | 浏览器 | OpenClaw Gateway 内置定时任务调度器。用于创建一次性提醒、周期性任务、后台自动化。支持主会话系统事件和独立会话执行，可配置投递到聊天频道或 Webhook。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/openclaw-cron-setup/GUIDE.md) | [原仓库](https://clawhub.ai/skills/openclaw-cron-setup) |
| 高 | `opencli-reader` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/opencli-reader/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/social-readers/skills/opencli-reader) |
| 中 / 高 | `paperless-docs` | 搜索 / 研究 / 情报 | ★★★★☆ | PAPERLESS_TOKEN | Manage documents in Paperless-ngx - search, upload, tag, and retrieve. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/paperless-docs/GUIDE.md) | [原仓库](https://github.com/paperless-ngx/paperless-ngx) |
| 中 / 高 | `paperless-ngx-tools` | 搜索 / 研究 / 情报 | ★★★★☆ | PAPERLESS_TOKEN | Manage documents in Paperless-ngx - search, upload, tag, and retrieve. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/paperless-ngx-tools/GUIDE.md) | [原仓库](https://github.com/paperless-ngx/paperless-ngx) |
| 低 / 中 / 高 | `pdf` | 文档 / 办公 | ★☆☆☆☆ | 无 | Use when extracting, creating, merging, splitting, filling, or analyzing PDF files. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/pdf/GUIDE.md) | [原仓库](https://github.com/leecyno1/auto-install-Openclaw/tree/release/hermes-website-minimax-hardening-20260503/skills/default/pdf) |
| 低 / 中 / 高 | `pptx` | 文档 / 办公 | ★☆☆☆☆ | 无 | Presentation creation, editing, and analysis. When Claude needs to work with presentations … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/pptx/GUIDE.md) | [原仓库](https://github.com/leecyno1/auto-install-Openclaw/tree/release/hermes-website-minimax-hardening-20260503/skills/default/pptx) |
| 低 / 中 / 高 | `pptx-generator` | 文档 / 办公 | ★★★★☆ | 无 | Generate, edit, and read PowerPoint presentations. Create from scratch with PptxGenJS (cove… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/pptx-generator/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/pptx-generator) |
| 低 / 中 / 高 | `proactive-agent` | 效率 / 知识管理 | ★★★★★ | 无 | Transform AI agents from task-followers into proactive partners that anticipate needs and c… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/proactive-agent/GUIDE.md) | [原仓库](https://clawhub.ai/halthelobster/proactive-agent) |
| 低 / 中 / 高 | `react-native-dev` | 编程 / 工程工具 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/react-native-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/react-native-dev) |
| 低 / 中 / 高 | `reflection` | 媒体生成 / 处理 | ★★★★★ | 无 | Learns when to stop and review. Self-critiques before showing you, fewer revision rounds. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/reflection/GUIDE.md) | [原仓库](https://playbooks.com/skills/openclaw/skills/reflection) |
| 低 / 中 / 高 | `self-improving-agent-cn` | 多 Agent / 自动调度 | ★★★★★ | 无 | AI自我改进与记忆系统 - 解决'同类错误反复犯、用户纠正不长记性'的痛点。自动捕获错误、用户纠正、最佳实践，并转化为长期记忆。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/self-improving-agent-cn/GUIDE.md) | [原仓库](https://clawhub.ai/zhengxinjipai/self-improving-agent-cn) |
| 低 / 中 / 高 | `shader-dev` | 编程 / 工程工具 | ★★★★☆ | 无 | Comprehensive GLSL shader techniques for creating stunning visual effects — ray marching, S… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/shader-dev/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/shader-dev) |
| 高 | `skill-designer` | 设计 / UI | ★★★★★ | 无 | Design new Claude skills from structured idea specifications. Use when the skill auto-gener… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/skill-designer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/skill-designer) |
| 高 | `skill-integration-tester` | 数据分析 | ★★★★★ | 无 | Validate multi-skill workflows defined in CLAUDE.md by checking skill existence, inter-skil… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/skill-integration-tester/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/skill-integration-tester) |
| 低 / 中 / 高 | `social-content` | 文档 / 办公 | ★★★★☆ | 无 | When the user wants help creating, scheduling, or optimizing social media content for Linke… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/social-content/GUIDE.md) | [原仓库](https://github.com/coreyhaines31/marketingskills/tree/main/skills/social-content) |
| 高 | `strategy-pivot-designer` | 设计 / UI | ★★★★★ | 无 | Detect backtest iteration stagnation and generate structurally different strategy pivot pro… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/strategy-pivot-designer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/strategy-pivot-designer) |
| 低 / 中 / 高 | `tavily-search` | 搜索 / 研究 / 情报 | ★★★★☆ | TAVILY_API_KEY | Search the web using Tavily's LLM-optimized search API. Returns relevant results with conte… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/tavily-search/GUIDE.md) | [原仓库](https://github.com/tavily-ai/tavily-python) |
| 高 | `telegram-reader` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/telegram-reader/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/social-readers/skills/telegram-reader) |
| 高 | `twitter-reader` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/twitter-reader/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/social-readers/skills/twitter-reader) |
| 低 / 中 / 高 | `vision-analysis` | 媒体生成 / 处理 | ★★★☆☆ | MINIMAX_API_KEY | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/vision-analysis/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/vision-analysis) |
| 中 / 高 | `writing-plans` | 写作 / 内容 | ★★★★★ | 无 | Use when writing implementation plans from specs before editing code. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/writing-plans/GUIDE.md) | [原仓库](https://skills.sh/obra/superpowers/writing-plans) |
| 低 / 中 / 高 | `xlsx` | 数据分析 | ★☆☆☆☆ | 无 | Comprehensive spreadsheet creation, editing, and analysis with support for formulas, format… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/xlsx/GUIDE.md) | [原仓库](https://github.com/leecyno1/auto-install-Openclaw/tree/release/hermes-website-minimax-hardening-20260503/skills/default/xlsx) |
| 高 | `yc-reader` | 搜索 / 研究 / 情报 | ★★★★★ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/yc-reader/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/social-readers/skills/yc-reader) |
| 低 / 中 / 高 | `agentmail-cli` | 写作 / 内容 | ★★★☆☆ | AGENTMAIL_API_KEY | Send and receive emails programmatically using the AgentMail CLI. Use when agents need to m… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/agentmail-cli/GUIDE.md) | [原仓库](https://github.com/agentmail-to/agentmail-cli) |
| 低 / 中 / 高 | `akshare-stock` | 金融 / 交易 | ★★★★☆ | 无 | A股量化数据分析工具，基于AkShare库获取A股行情、财务数据、板块信息等。用于回答关于A股股票查询、行情数据、财务分析、选股等问题。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/akshare-stock/GUIDE.md) | [原仓库](https://clawhub.ai/skills/new-akshare-stock) |
| 高 | `alphaear-deepear-lite` | 金融 / 交易 | ★★★★☆ | 无 | Fetch the latest financial signals and transmission-chain analyses from DeepEar Lite. Use w… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-deepear-lite/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-deepear-lite) |
| 高 | `alphaear-logic-visualizer` | 金融 / 交易 | ★★★★☆ | 无 | Create visualize finance logic diagrams (e.g., Draw.io XML) to explain complex finance tran… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-logic-visualizer/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-logic-visualizer) |
| 高 | `alphaear-news` | 金融 / 交易 | ★★★★☆ | 无 | Fetch hot finance news, unified trends, and prediction financial market data. Use when the … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-news/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-news) |
| 高 | `alphaear-predictor` | 金融 / 交易 | ★★★★☆ | 无 | Market prediction skill using Kronos. Use when user needs finance market time-series foreca… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-predictor/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-predictor) |
| 高 | `alphaear-reporter` | 金融 / 交易 | ★★★★☆ | 无 | Plan, write, and edit professional financial reports; generate finance chart configurations… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-reporter/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-reporter) |
| 高 | `alphaear-search` | 金融 / 交易 | ★★★☆☆ | 浏览器 | Perform finance web searches and local context searches. Use when the user needs general fi… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-search/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-search) |
| 高 | `alphaear-sentiment` | 金融 / 交易 | ★★★★☆ | 无 | Analyze finance text sentiment using FinBERT or LLM. Use when the user needs to determine t… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-sentiment/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-sentiment) |
| 高 | `alphaear-signal-tracker` | 金融 / 交易 | ★★★★☆ | 无 | Track finance investment signal evolution and update logic based on new finance market info… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-signal-tracker/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-signal-tracker) |
| 高 | `alphaear-stock` | 金融 / 交易 | ★★★★☆ | 无 | Search A-Share/HK/US finance stock tickers and retrieve finance stock price history. Use wh… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/alphaear-stock/SKILL.md) | [原仓库](https://github.com/RKiding/Awesome-finance-skills/tree/main/skills/alphaear-stock) |
| 高 | `baoyu-article-illustrator` | 写作 / 内容 | ★★★★☆ | 无 | Use when adding article illustrations or visual aids to markdown or long-form writing. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-article-illustrator/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-article-illustrator) |
| 高 | `baoyu-comic` | 媒体生成 / 处理 | ★★★★☆ | 无 | Knowledge comic creator supporting multiple art styles and tones. Creates original educatio… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-comic/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-comic) |
| 高 | `baoyu-compress-image` | 媒体生成 / 处理 | ★★★☆☆ | 浏览器 | Compresses images to WebP (default) or PNG with automatic tool selection. Use when user ask… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-compress-image/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-compress-image) |
| 高 | `baoyu-cover-image` | 媒体生成 / 处理 | ★★★★☆ | 无 | Use when generating article cover images in cinematic, widescreen, or square formats. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-cover-image/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-cover-image) |
| 高 | `baoyu-danger-gemini-web` | 媒体生成 / 处理 | ★★☆☆☆ | GEMINI_API_KEY | Generates images and text via reverse-engineered Gemini Web API. Supports text generation, … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-danger-gemini-web/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills#baoyu-danger-gemini-web) |
| 高 | `baoyu-format-markdown` | 写作 / 内容 | ★★★★☆ | 无 | Use when formatting plain text or markdown articles with headings, summaries, lists, and po… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-format-markdown/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-format-markdown) |
| 高 | `baoyu-infographic` | 写作 / 内容 | ★★★★☆ | 无 | Use when turning content into professional infographics or visual summaries. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-infographic/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-infographic) |
| 高 | `baoyu-markdown-to-html` | 写作 / 内容 | ★★★★☆ | 无 | Use when converting Markdown to styled HTML, especially WeChat-compatible article HTML. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-markdown-to-html/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-markdown-to-html) |
| 高 | `baoyu-post-to-wechat` | 媒体生成 / 处理 | ★★★☆☆ | ACCESS_TOKEN, WECHAT_AI_TOOLS_APP_SECRET… | Use when posting articles or image-text content to WeChat Official Account. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-post-to-wechat/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-wechat) |
| 高 | `baoyu-post-to-weibo` | 媒体生成 / 处理 | ★★★☆☆ | 浏览器 | Posts content to Weibo (微博). Supports regular posts with text, images, and videos, and head… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-post-to-weibo/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-weibo) |
| 高 | `baoyu-post-to-x` | 媒体生成 / 处理 | ★★★☆☆ | 浏览器 | Posts content and articles to X (Twitter). Supports regular posts with images/videos and X … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-post-to-x/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-x) |
| 高 | `baoyu-skills` | 写作 / 内容 | ★★★★☆ | 无 | Baoyu 内容产出与分发技能包入口。用于在本地仓库中索引并路由 baoyu 系列子技能。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-skills/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills) |
| 高 | `baoyu-slide-deck` | 媒体生成 / 处理 | ★★★★☆ | 无 | Generates professional slide deck images from content. Creates outlines with style instruct… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-slide-deck/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-slide-deck) |
| 高 | `baoyu-translate` | 写作 / 内容 | ★★★★☆ | 无 | Use when translating articles or documents with terminology consistency or review polish. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-translate/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-translate) |
| 高 | `baoyu-xhs-images` | 媒体生成 / 处理 | ★★★★☆ | 无 | Use when creating Xiaohongshu/RedNote infographic image series from content. | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/baoyu-xhs-images/GUIDE.md) | [原仓库](https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-xhs-images) |
| 高 | `breadth-chart-analyst` | 金融 / 交易 | ★★★★☆ | 无 | This skill should be used when analyzing market breadth charts, specifically the S&P 500 Br… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/breadth-chart-analyst/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/breadth-chart-analyst) |
| 高 | `breakout-trade-planner` | 金融 / 交易 | ★★★★☆ | 无 | Generate Minervini-style breakout trade plans from VCP screener output with worst-case risk… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/breakout-trade-planner/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/breakout-trade-planner) |
| 低 / 中 / 高 | `buddy-sings` | 媒体生成 / 处理 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/buddy-sings/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/buddy-sings) |
| 高 | `canslim-screener` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Screen US stocks using William O'Neil's CANSLIM growth stock methodology. Use when user req… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/canslim-screener/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/canslim-screener) |
| 低 / 中 / 高 | `capability-evolver` | 多 Agent / 自动调度 | ★★★★☆ | 无 | A self-evolution engine for AI agents. Analyzes runtime history to identify improvements an… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/capability-evolver/GUIDE.md) | [原仓库](https://mcp.directory/skills/details/1368/capability-evolver) |
| 高 | `company-valuation` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/company-valuation/README.md) | [原仓库](https://github.com/himself65/finance-skills) |
| 高 | `data-quality-checker` | 金融 / 交易 | ★★★★☆ | 无 | Validate data quality in market analysis documents and blog articles before publication. Us… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/data-quality-checker/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/data-quality-checker) |
| 高 | `dividend-growth-pullback-screener` | 金融 / 交易 | ★★★☆☆ | FINVIZ_API_KEY, FMP_API_KEY | Use this skill to find high-quality dividend growth stocks (12%+ annual dividend growth, 1.… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/dividend-growth-pullback-screener/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/dividend-growth-pullback-screener) |
| 高 | `downtrend-duration-analyzer` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Analyze historical downtrend durations and generate interactive HTML histograms showing typ… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/downtrend-duration-analyzer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/downtrend-duration-analyzer) |
| 高 | `earnings-calendar` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | This skill retrieves upcoming earnings announcements for US stocks using the Financial Mode… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/earnings-calendar/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/earnings-calendar) |
| 高 | `earnings-preview` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/earnings-preview/README.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills) |
| 高 | `earnings-recap` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/earnings-recap/README.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills) |
| 高 | `earnings-trade-analyzer` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Analyze recent post-earnings stocks using a 5-factor scoring system (Gap Size, Pre-Earnings… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/earnings-trade-analyzer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/earnings-trade-analyzer) |
| 高 | `economic-calendar-fetcher` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Fetch upcoming economic events and data releases using FMP API. Retrieve scheduled central … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/economic-calendar-fetcher/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/economic-calendar-fetcher) |
| 高 | `edge-candidate-agent` | 金融 / 交易 | ★★★★☆ | 无 | Generate and prioritize US equity long-side edge research tickets from EOD observations, th… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-candidate-agent/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-candidate-agent) |
| 高 | `edge-hint-extractor` | 金融 / 交易 | ★★★★☆ | 无 | Extract edge hints from daily market observations and news reactions, with optional LLM ide… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-hint-extractor/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-hint-extractor) |
| 高 | `edge-strategy-reviewer` | 安全 / 审计 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/edge-strategy-reviewer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/edge-strategy-reviewer) |
| 高 | `estimate-analysis` | 商业运营 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/estimate-analysis/README.md) | [原仓库](https://github.com/himself65/finance-skills) |
| 高 | `etf-premium` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/etf-premium/README.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills) |
| 高 | `exposure-coach` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Generate a one-page Market Posture summary with net exposure ceiling, growth-vs-value bias,… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/exposure-coach/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/exposure-coach) |
| 高 | `finance-sentiment` | 金融 / 交易 | ★★★☆☆ | ADANOS_API_KEY | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/finance-sentiment/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/data-providers/skills/finance-sentiment) |
| 高 | `finance-skill-creator` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/finance-skill-creator/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/skill-creator/skills/finance-skill-creator) |
| 高 | `finviz-screener` | 金融 / 交易 | ★★★☆☆ | FINVIZ_API_KEY | Build and open FinViz screener URLs from natural language requests. Use when user wants to … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/finviz-screener/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/finviz-screener) |
| 高 | `ftd-detector` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Detects Follow-Through Day (FTD) signals for market bottom confirmation using William O'Nei… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/ftd-detector/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/ftd-detector) |
| 高 | `funda-data` | 金融 / 交易 | ★★★☆☆ | FUNDA_API_KEY | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/funda-data/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/data-providers/skills/funda-data) |
| 中 / 高 | `gemini-image-service` | 媒体生成 / 处理 | ★★★☆☆ | GEMINI_API_KEY | 使用 Gemini 第三方服务生成图片。读取 GEMINI_API_KEY/GEMINI_BASE_URL/GEMINI_IMAGE_MODEL。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/gemini-image-service/GUIDE.md) | [原仓库](https://ai.google.dev/gemini-api/docs/image-generation) |
| 低 / 中 / 高 | `gif-sticker-maker` | 媒体生成 / 处理 | ★★★☆☆ | MINIMAX_API_KEY | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/gif-sticker-maker/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/gif-sticker-maker) |
| 高 | `hormuz-strait` | 商业运营 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/hormuz-strait/README.md) | [原仓库](https://github.com/himself65/finance-skills) |
| 高 | `ibd-distribution-day-monitor` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Detect IBD-style Distribution Days for QQQ/SPY (close down at least 0.2% on higher volume),… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/ibd-distribution-day-monitor/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/ibd-distribution-day-monitor) |
| 低 / 中 / 高 | `inference-skills` | 商业运营 | ★★★☆☆ | OPENAI_API_KEY | Inference Skills Hub（上游: inference-sh/skills）- 用于索引与选择 inference-sh 的工具型技能。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/inference-skills/GUIDE.md) | [原仓库](https://github.com/inference-sh/skills) |
| 高 | `institutional-flow-tracker` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Use this skill to track institutional investor ownership changes and portfolio flows using … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/institutional-flow-tracker/README.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/institutional-flow-tracker) |
| 高 | `kanchi-dividend-review-monitor` | 金融 / 交易 | ★★★★☆ | 无 | Monitor dividend portfolios with Kanchi-style forced-review triggers (T1-T5) and convert an… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/kanchi-dividend-review-monitor/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/kanchi-dividend-review-monitor) |
| 高 | `kanchi-dividend-sop` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Convert Kanchi-style dividend investing into a repeatable US-stock operating procedure. Use… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/kanchi-dividend-sop/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/kanchi-dividend-sop) |
| 高 | `kanchi-dividend-us-tax-accounting` | 金融 / 交易 | ★★★★☆ | 无 | Provide US dividend tax and account-location workflow for Kanchi-style income portfolios. U… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/kanchi-dividend-us-tax-accounting/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/kanchi-dividend-us-tax-accounting) |
| 高 | `macro-regime-detector` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Detect structural macro regime transitions (1-2 year horizon) using cross-asset ratio analy… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/macro-regime-detector/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/macro-regime-detector) |
| 高 | `market-breadth-analyzer` | 金融 / 交易 | ★★★★☆ | 无 | Quantifies market breadth health using TraderMonty's public CSV data. Generates a 0-100 com… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/market-breadth-analyzer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/market-breadth-analyzer) |
| 高 | `market-environment-analysis` | 金融 / 交易 | ★★★★☆ | 无 | Comprehensive market environment analysis and reporting tool. Analyzes global markets inclu… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/market-environment-analysis/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/market-environment-analysis) |
| 高 | `market-news-analyst` | 金融 / 交易 | ★★★☆☆ | 浏览器 | This skill should be used when analyzing recent market-moving news events and their impact … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/market-news-analyst/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/market-news-analyst) |
| 高 | `market-top-detector` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Detects market top probability using O'Neil Distribution Days, Minervini Leading Stock Dete… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/market-top-detector/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/market-top-detector) |
| 低 / 中 / 高 | `marketingskills` | 金融 / 交易 | ★★★☆☆ | 无 | Marketing Skills Hub（上游: coreyhaines31/marketingskills）- 用于索引与选择营销类子技能（如 content-strategy、s… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/marketingskills/GUIDE.md) | [原仓库](https://github.com/coreyhaines31/marketingskills) |
| 低 / 中 / 高 | `minimax-image-understanding` | 媒体生成 / 处理 | ★★★☆☆ | MINIMAX_API_KEY | Analyze images using AI with the understand_image tool (priority) | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-image-understanding/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-image-understanding) |
| 低 / 中 / 高 | `minimax-music-gen` | 媒体生成 / 处理 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-music-gen/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-music-gen) |
| 低 / 中 / 高 | `minimax-music-playlist` | 媒体生成 / 处理 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/minimax-music-playlist/GUIDE.md) | [原仓库](https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-music-playlist) |
| 高 | `options-payoff` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/options-payoff/README.md) | [原仓库](https://github.com/himself65/finance-skills) |
| 高 | `options-strategy-advisor` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Options trading strategy analysis and simulation tool. Provides theoretical pricing using B… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/options-strategy-advisor/README.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/options-strategy-advisor) |
| 中 / 高 | `oracle` | 浏览器 / 自动化 | ★★★☆☆ | OPENAI_API_KEY | Use the @steipete/oracle CLI to bundle a prompt plus the right files and get a second-model… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/oracle/GUIDE.md) | [原仓库](https://github.com/steipete/oracle) |
| 高 | `pair-trade-screener` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Statistical arbitrage tool for identifying and analyzing pair trading opportunities. Detect… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/pair-trade-screener/README.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/pair-trade-screener) |
| 高 | `parabolic-short-trade-planner` | 金融 / 交易 | ★★★☆☆ | ALPACA_API_KEY, FMP_API_KEY | Screen US equities for parabolic exhaustion patterns and generate conditional pre-market sh… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/parabolic-short-trade-planner/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/parabolic-short-trade-planner) |
| 高 | `pead-screener` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Screen post-earnings gap-up stocks for PEAD (Post-Earnings Announcement Drift) patterns. An… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/pead-screener/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/pead-screener) |
| 高 | `portfolio-manager` | 金融 / 交易 | ★★★☆☆ | MCP | Comprehensive portfolio analysis using Alpaca MCP Server integration to fetch holdings and … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/portfolio-manager/README.md) | [原仓库](https://mcp.directory/skills/portfolio-manager) |
| 高 | `position-sizer` | 金融 / 交易 | ★★★★☆ | 无 | Calculate risk-based position sizes for long stock trades. Use when user asks about positio… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/position-sizer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/position-sizer) |
| 高 | `saas-valuation-compression` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/saas-valuation-compression/README.md) | [原仓库](https://github.com/himself65/finance-skills) |
| 高 | `scenario-analyzer` | 商业运营 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/scenario-analyzer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills) |
| 高 | `sector-analyst` | 金融 / 交易 | ★★★★☆ | 无 | This skill should be used when analyzing sector rotation patterns and market cycle position… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/sector-analyst/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/sector-analyst) |
| 高 | `sepa-strategy` | 商业运营 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/sepa-strategy/README.md) | [原仓库](https://github.com/himself65/finance-skills) |
| 高 | `signal-postmortem` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Record and analyze post-trade outcomes for signals generated by edge pipeline and other ski… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/signal-postmortem/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/signal-postmortem) |
| 高 | `skill-idea-miner` | 商业运营 | ★★★★☆ | 无 | Mine Claude Code session logs for skill idea candidates. Use when running the weekly skill … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/skill-idea-miner/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/skill-idea-miner) |
| 高 | `stanley-druckenmiller-investment` | 金融 / 交易 | ★★★★☆ | 无 | Druckenmiller Strategy Synthesizer - Integrates 8 upstream skill outputs (Market Breadth, U… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/stanley-druckenmiller-investment/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/stanley-druckenmiller-investment) |
| 高 | `startup-analysis` | 商业运营 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/startup-analysis/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/startup-tools/skills/startup-analysis) |
| 高 | `stock-correlation` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/stock-correlation/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/market-analysis/skills/stock-correlation) |
| 高 | `stock-liquidity` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/stock-liquidity/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/market-analysis/skills/stock-liquidity) |
| 低 / 中 / 高 | `stock-monitor-skill` | 金融 / 交易 | ★★★★☆ | 无 | 全功能智能股票监控预警系统。支持成本百分比、均线金叉死叉、RSI超买超卖、成交量异动、跳空缺口、动态止盈等7大预警规则。符合中国投资者习惯（红涨绿跌）。 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/stock-monitor-skill/GUIDE.md) | [原仓库](https://clawhub.ai/THIRTYFANG/stock-monitor-skill) |
| 高 | `technical-analyst` | 金融 / 交易 | ★★★★☆ | 无 | This skill should be used when analyzing weekly price charts for stocks, stock indices, cry… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/technical-analyst/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/technical-analyst) |
| 高 | `theme-detector` | 金融 / 交易 | ★★★☆☆ | FINVIZ_API_KEY, FMP_API_KEY | Detect and analyze trending market themes across sectors. Use when user asks about current … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/theme-detector/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/theme-detector) |
| 高 | `trade-hypothesis-ideator` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/trade-hypothesis-ideator/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/trade-hypothesis-ideator) |
| 高 | `trader-memory-core` | 金融 / 交易 | ★★★★☆ | 无 | Track investment theses across their lifecycle — from screening idea to closed position wit… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/trader-memory-core/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/trader-memory-core) |
| 高 | `uptrend-analyzer` | 金融 / 交易 | ★★★★☆ | 无 | Analyzes market breadth using Monty's Uptrend Ratio Dashboard data to diagnose the current … | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/uptrend-analyzer/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/uptrend-analyzer) |
| 高 | `us-market-bubble-detector` | 金融 / 交易 | ★★★★☆ | 无 | Evaluates market bubble risk through quantitative data-driven analysis using the revised Mi… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/us-market-bubble-detector/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/us-market-bubble-detector) |
| 高 | `us-stock-analysis` | 金融 / 交易 | ★★★★☆ | 无 | Comprehensive US stock analysis including fundamental analysis (financial metrics, business… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/us-stock-analysis/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/us-stock-analysis) |
| 高 | `value-dividend-screener` | 金融 / 交易 | ★★★☆☆ | FINVIZ_API_KEY, FMP_API_KEY | Screen US stocks for high-quality dividend opportunities combining value characteristics (P… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/value-dividend-screener/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/value-dividend-screener) |
| 高 | `vcp-screener` | 金融 / 交易 | ★★★☆☆ | FMP_API_KEY | Screen S&P 500 stocks for Mark Minervini's Volatility Contraction Pattern (VCP). Identifies… | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/vcp-screener/SKILL.md) | [原仓库](https://github.com/tradermonty/claude-trading-skills/tree/main/skills/vcp-screener) |
| 高 | `yfinance-data` | 金融 / 交易 | ★★★★☆ | 无 | 详见手册 | [手册](https://github.com/leecyno1/boutique-openclaw-skills/tree/main/skills/default/yfinance-data/README.md) | [原仓库](https://github.com/himself65/finance-skills/tree/main/plugins/market-analysis/skills/yfinance-data) |

## 模块概览

| 模块 | 默认端口/位置 | 做什么 |
| --- | --- | --- |
| OpenClaw Gateway | `127.0.0.1:13145` | Dashboard、模型与渠道入口，默认本机监听 |
| Hermes Dashboard | `127.0.0.1:9119` | Hermes 管理界面，供网站通过 SSH 隧道接入 |
| Hermes Chat API | `127.0.0.1:8000` | OpenAI 兼容 `/v1/models`、`/v1/chat/completions`，支持 SSE |
| 健康检查 | `127.0.0.1:13146` | 监控 Gateway、像素小屋和联动服务 |
| 像素小屋 | `127.0.0.1:19000` | 角色、技能、装备和状态工作台 |
| 规则档位 | `~/.openclaw/profile/` | low / medium / high 请求、图片、视频配额 |
| 模型注册表 | `~/.openclaw/model-capabilities.json` | 多模型能力目录，支持 `image_tool=responses-image-generation` 和 `gpt-5.5` |

## 常用配置

```bash
openclaw-setup config skills --tier extended
openclaw-setup config tier-rules --level medium
openclaw-setup config pixel-house --install
openclaw-setup config pixel-house --start
openclaw-setup config model
openclaw-setup config image
openclaw-setup config routing
openclaw-setup config website --sync
openclaw update --restart
openclaw plugins update --all
```

底层快捷脚本仍可直接调用：

```bash
bash ~/.openclaw/config-menu.sh
bash ~/.openclaw/config-menu.sh --model-only
bash ~/.openclaw/config-menu.sh --official-channels-only
bash ~/.openclaw/config-menu.sh --engine-menu
bash ~/.openclaw/config-menu.sh --repair-config
bash ~/.openclaw/config-menu.sh --repair-minimax
bash ~/.openclaw/config-menu.sh --install-pixel-house
bash ~/.openclaw/config-menu.sh --remote-local-control
~/.openclaw/lobster-world.sh start
~/.openclaw/health-server.sh status
```

## 可选：云端控制本地主机

该能力用于云端 OpenClaw/Hermes 通过反向 SSH 调用本地主机上的白名单命令。默认不会启用远程控制，也不会暴露本地 SSH 或 OpenClaw Gateway 到公网。

```bash
openclaw-setup config --remote-local-control
~/.openclaw/remote-local-control.sh install-cloud --identity ~/.ssh/openclaw-local-control --local-user YOUR_LOCAL_LOGIN_USER --port 24022 --apply
~/.openclaw/remote-local-control.sh configure-local --pairing-file ./openclaw-cloud-pairing.json --install-service
OPENCLAW_REMOTE_LOCAL_PAIRING_FILE=./openclaw-cloud-pairing.json ~/.openclaw/remote-local-control.sh configure-local --install-service
~/.openclaw/remote-local-control.sh bootstrap-local --cloud root@YOUR_CLOUD_HOST --cloud-public-key ./openclaw-local-control.pub --local-user YOUR_LOCAL_LOGIN_USER
~/.openclaw/remote-local-control.sh install-tunnel-service --cloud root@YOUR_CLOUD_HOST
openclaw-local-run desktop-write-article OpenClawRemote hello.md "$(printf 'hello from cloud' | base64 | tr -d '\n')"
```

## 旧有页面索引

旧说明已经收敛到以下文档，README 只保留入口和总表。

| 页面 | 内容 |
| --- | --- |
| [Skills 完整手册](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/SKILL_MANUALS.md) | 每个 skill 的使用说明 |
| [低档说明](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/tiers/low.md) | low 技能包 |
| [中档说明](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/tiers/medium.md) | medium 技能包 |
| [高档说明](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/tiers/high.md) | high 技能包 |
| [渠道配置](docs/channels-configuration-guide.md) | Feishu、Slack、Telegram 等渠道 |
| [Feishu 配置](docs/feishu-setup.md) | 飞书插件和机器人配置 |
| [规则档位](docs/vendor-control-profiles.md) | Token、请求、图片、视频配额 |
| [身份角色](docs/persona-roles.md) | Persona 注入和角色体系 |

## 开发与验证

```bash
./scripts/preflight-check.sh
./scripts/release-check.sh
python3 -m unittest discover -s tests -p 'test_readme_launcher_alignment.py'
```

## 许可证

MIT
