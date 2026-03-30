#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_DIR = REPO_ROOT / 'skills' / 'default'
INDEX_PATH = REPO_ROOT / 'docs' / 'skills-guides.md'
UPSTREAM_PATH = REPO_ROOT / 'docs' / 'upstream-sources.md'

PROFILE_BASIC = set("""capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator subagent-driven-development using-superpowers verification-before-completion writing-skills agent-browser chrome-devtools-mcp github mcp-builder model-usage shell minimax-image-understanding tavily-search web-search minimax-web-search news-radar url-to-markdown pdf nano-pdf docx pptx xlsx stock-monitor-skill multi-search-engine akshare-stock content-strategy social-content ai-image-generation media-downloader marketingskills inference-skills agentmail agentmail-cli agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill skill-security-auditor weather data-analyst finance-data task todo""".split())
PROFILE_EXTENDED = set("""capability-evolver openclaw-cron-setup proactive-agent self-improving-agent-cn brainstorming reflection find-skills skill-creator subagent-driven-development using-superpowers verification-before-completion writing-skills agent-browser chrome-devtools-mcp github mcp-builder model-usage shell minimax-image-understanding tavily-search web-search minimax-web-search news-radar url-to-markdown pdf nano-pdf docx pptx xlsx stock-monitor-skill multi-search-engine akshare-stock content-strategy social-content ai-image-generation animation media-downloader marketingskills inference-skills gemini-image-service oracle paperless-docs paperless-ngx-tools writing-plans agentmail agentmail-cli agentmail-mcp agentmail-toolkit lark-calendar notebooklm-skill skill-security-auditor weather data-analyst finance-data task todo""".split())

OVERRIDES = {
    'agent-browser': {
        'title': 'Agent Browser',
        'purpose': '浏览器自动化 CLI。适合网页打开、点击、表单填写、抓取页面文本。',
        'needs': ['Node.js / npm', '建议执行 `npm install -g agent-browser && agent-browser install`'],
        'setup': ['确认 `agent-browser --help` 可执行。', '首次运行后用 `agent-browser snapshot -i` 获取页面元素引用。'],
        'examples': ['请用 agent-browser 打开这个页面并提取标题与按钮文案。', '请用 agent-browser 登录测试站点，遇到交互元素先 snapshot 再操作。'],
        'verify': 'agent-browser --help',
    },
    'agentmail': {
        'title': 'AgentMail SDK',
        'purpose': '给 Agent 提供独立邮箱能力，可创建邮箱、收发邮件、管理线程与附件。',
        'needs': ['AgentMail 账号', '环境变量 `AGENTMAIL_API_KEY`'],
        'setup': ['访问 https://console.agentmail.to 获取 API Key。', '把 `AGENTMAIL_API_KEY=你的密钥` 写入 `~/.openclaw/env` 或当前 Shell。', 'Node 场景执行 `npm install agentmail`；Python 场景执行 `pip install agentmail`。'],
        'examples': ['请用 AgentMail 新建一个客户支持邮箱，并把地址告诉我。', '请用 AgentMail 给某个收件人发送一封 HTML + 纯文本双版本邮件。'],
        'verify': 'echo $AGENTMAIL_API_KEY',
        'notes': ['官方文档首页: https://docs.agentmail.to/welcome', 'OpenClaw 集成参考: https://docs.agentmail.to/integrations/openclaw'],
    },
    'agentmail-cli': {
        'title': 'AgentMail CLI',
        'purpose': '通过命令行管理 AgentMail 邮箱、邮件、草稿、Webhook 与域名。',
        'needs': ['环境变量 `AGENTMAIL_API_KEY`', 'CLI: `npm install -g agentmail-cli`'],
        'setup': ['先配置 `AGENTMAIL_API_KEY`。', '安装 CLI 后执行 `agentmail inboxes list` 验证鉴权。'],
        'examples': ['请用 agentmail-cli 创建一个新的邮箱并列出 inbox。', '请用 agentmail-cli 给指定邮箱发送测试邮件。'],
        'verify': 'agentmail inboxes list',
        'notes': ['支持 `--api-key`、`--base-url`、`--environment`、`--format`、`--debug`。'],
    },
    'agentmail-mcp': {
        'title': 'AgentMail MCP',
        'purpose': '把 AgentMail 作为 MCP 服务接入 OpenClaw、Claude Desktop、Cursor 等客户端。',
        'needs': ['环境变量 `AGENTMAIL_API_KEY`', '任选其一: 远程 MCP / `npx -y agentmail-mcp` / `pip install agentmail-mcp`'],
        'setup': ['最简单的方式是远程 MCP：`https://mcp.agentmail.to`。', '本地方式可在 MCP 配置里写 `command: npx` 和 `args: ["-y", "agentmail-mcp"]`。', 'OpenClaw 集成时，把 `AGENTMAIL_API_KEY` 放到对应 MCP server 的 `env` 中。'],
        'examples': ['请把 AgentMail MCP 加到 OpenClaw 的 MCP 配置里。', '请通过 AgentMail MCP 创建一个邮箱并读取最新邮件。'],
        'verify': 'npx -y agentmail-mcp --help',
        'notes': ['支持按 `--tools` 只暴露部分工具，降低权限面。'],
    },
    'agentmail-toolkit': {
        'title': 'AgentMail Toolkit',
        'purpose': '把邮件工具快速接到 AI SDK、LangChain、OpenAI Agents SDK、LiveKit 等框架。',
        'needs': ['环境变量 `AGENTMAIL_API_KEY`', '`npm install agentmail-toolkit` 或 `pip install agentmail-toolkit`'],
        'setup': ['先确认 SDK 项目本身能运行。', '再引入对应框架版本的 AgentMailToolkit 并把工具注册给 Agent。'],
        'examples': ['请在 LangChain agent 中挂载 AgentMailToolkit。', '请在 OpenAI Agents SDK 中接入 AgentMailToolkit 发送邮件。'],
        'verify': 'python3 - <<\'PY\'\nprint("install agentmail-toolkit in your venv first")\nPY',
    },
    'akshare-stock': {
        'title': 'AkShare Stock',
        'purpose': 'A 股行情、财务、板块、资金流向等数据分析。',
        'needs': ['Python 依赖 `akshare`'],
        'setup': ['执行 `pip install akshare`。', '若要长期使用，建议安装到 OpenClaw 运行环境同一 Python。'],
        'examples': ['请用 akshare-stock 查询 600519 最近 3 个月日线。', '请用 akshare-stock 分析半导体板块近 20 日资金流向。'],
        'verify': 'python3 -c "import akshare; print(akshare.__version__)"',
    },
    'blogwatcher': {
        'title': 'Blogwatcher',
        'purpose': '监控博客与 RSS/Atom 订阅源更新。',
        'needs': ['二进制 `blogwatcher`'],
        'setup': ['Go 安装: `go install github.com/Hyaxia/blogwatcher/cmd/blogwatcher@latest`。', '先执行 `blogwatcher add \"名称\" URL` 建立订阅，再执行 `blogwatcher scan`。'],
        'examples': ['请帮我新增一个 RSS 订阅并扫描最近更新。', '请用 blogwatcher 列出未读文章。'],
        'verify': 'blogwatcher --help',
    },
    'brainstorming': {
        'title': 'Brainstorming',
        'purpose': '在开始做功能、方案或复杂改造前，先做需求澄清与发散。',
        'examples': ['先用 brainstorming 帮我拆解这个需求，再决定怎么做。', '这个功能先不要写代码，先 brainstorming 出 3 套方案。'],
    },
    'capability-evolver': {
        'title': 'Capability Evolver',
        'purpose': '基于历史运行记录做能力进化、策略优化与沉淀。',
        'needs': ['纯本地可运行；若要发布公开报告，可额外配置 `GITHUB_TOKEN` 或 `GH_TOKEN`。'],
        'setup': ['日常使用不强制 API Key。', '需要发布或同步报告时，再配置 GitHub Token。'],
        'examples': ['请用 capability-evolver 复盘最近的任务日志并给出可执行改进。', '请用 capability-evolver 生成近期能力演进报告。'],
    },
    'chrome-devtools-mcp': {
        'title': 'Chrome DevTools MCP',
        'purpose': 'Google 官方的 Chrome/CDP 自动化与调试能力，适合网页调试、性能分析和复杂表单自动化。',
        'needs': ['Node.js v20.19+', 'Chrome/Chromium'],
        'setup': ['先执行 `npx -y chrome-devtools-mcp@latest --help`。', '服务器环境建议加 `--headless`。', '如需持久配置，可用 `python3 scripts/setup_chrome_mcp.py setup`。'],
        'examples': ['请用 chrome-devtools-mcp 打开网页并导出性能 trace。', '请用 chrome-devtools-mcp 自动填写表单并截图。'],
        'verify': 'npx -y chrome-devtools-mcp@latest --help',
    },
    'docx': {
        'title': 'DOCX',
        'purpose': '创建、编辑、批注 Word 文档，并尽量保持格式。',
        'needs': ['Python 依赖通常由安装脚本补齐；缺失时补 `python-docx`。'],
        'examples': ['请用 docx 生成一份会议纪要 Word。', '请在现有 docx 文件中加入批注并保持排版。'],
        'verify': 'python3 -c "import docx; print(docx.__version__)"',
    },
    'find-skills': {
        'title': 'Find Skills',
        'purpose': '根据任务需求搜索和推荐适合安装的 skill。',
        'examples': ['请用 find-skills 找适合做舆情监控的 skill。', '我想做自动化办公，先用 find-skills 给我列一组 skill。'],
    },
    'frontend-design': {
        'title': 'Frontend Design',
        'purpose': '高质量前端界面设计与实现。',
        'examples': ['请用 frontend-design 重做这个页面，强调层次与品牌感。', '请用 frontend-design 设计一个移动端仪表盘。'],
    },
    'gemini-image-service': {
        'title': 'Gemini Image Service',
        'purpose': '通过 Gemini 兼容服务生成图片，支持第三方代理地址与自定义模型名。',
        'needs': ['`GEMINI_API_KEY`', '`GEMINI_BASE_URL`', '`GEMINI_IMAGE_MODEL`'],
        'setup': ['推荐写入 `~/.openclaw/skills/gemini-image-service/service.env`。', '也可以写入 `~/.openclaw/env`，但服务 env 优先更清晰。', '配置后用 `python3 scripts/generate_image.py --prompt \"测试\" --output /tmp/gemini.png` 验证。'],
        'examples': ['请用 gemini-image-service 生成一张产品海报。', '请用 gemini-image-service 按第三方地址生成 1:1 方图。'],
        'verify': 'python3 skills/default/gemini-image-service/scripts/generate_image.py --help',
    },
    'github': {
        'title': 'GitHub',
        'purpose': '通过 `gh` CLI 操作 issue / PR / Actions / API。',
        'needs': ['GitHub CLI `gh`', '已登录 `gh auth login` 或 `GH_TOKEN`'],
        'setup': ['先执行 `gh auth status` 确认登录。', '非仓库目录中操作时，命令补 `--repo owner/repo`。'],
        'examples': ['请用 github 看一下这个 PR 的 CI 为什么失败。', '请用 github 列出某仓库最近 10 个 issue。'],
        'verify': 'gh auth status',
    },
    'grok-imagine-1.0-video': {
        'title': 'Grok Imagine Video',
        'purpose': '调用 `grok-imagine-1.0-video` 或兼容代理服务生成短视频。',
        'needs': ['`GROK_IMAGINE_API_KEY`', '`GROK_IMAGINE_BASE_URL`', '`GROK_IMAGINE_MODEL`'],
        'setup': ['建议把 3 个环境变量写入 `~/.openclaw/env`。', '如服务商不是 xAI 官方，务必核对路径与异步任务轮询方式。'],
        'examples': ['请用 grok-imagine-1.0-video 生成 6 秒产品展示视频。'],
        'verify': 'python3 skills/default/grok-imagine-1.0-video/scripts/generate_video.py --help',
    },
    'mcp-builder': {
        'title': 'MCP Builder',
        'purpose': '构建 MCP 服务与工具接入规范。',
        'examples': ['请用 mcp-builder 设计一个接入企业内部 API 的 MCP server。', '请用 mcp-builder 审查这个 MCP 服务的工具设计。'],
    },
    'minimax-image-understanding': {
        'title': 'MiniMax Understand Image',
        'purpose': '优先用 MiniMax 做识图、OCR、截图理解与视觉分析。',
        'needs': ['`MINIMAX_API_KEY` 或 `~/.openclaw/config/minimax.json`'],
        'setup': ['确保 `~/.openclaw/config/minimax.json` 含有效 `api_key`。', '若无配置，可在当前 shell 导出 `MINIMAX_API_KEY`。', '本 skill 的脚本支持本地图片路径和远程 URL。'],
        'examples': ['请用 minimax-image-understanding 识别这张图里的错误信息。', '请用 minimax-image-understanding 解释这个 UI 截图。'],
        'verify': 'python3 skills/default/minimax-image-understanding/scripts/understand_image.py --help',
    },
    'minimax-web-search': {
        'title': 'MiniMax Web Search',
        'purpose': '优先使用 MiniMax MCP 做联网搜索。适合实时信息、新闻、资料查找。',
        'needs': ['`uvx` / `uv tool`', '`MINIMAX_API_KEY` 或 `~/.openclaw/config/minimax.json`'],
        'setup': ['先确认 `uvx minimax-coding-plan-mcp --help` 可用。', '没有的话先安装 `uv`，再执行 `uv tool install minimax-coding-plan-mcp`。', '把 MiniMax key 存到 `~/.openclaw/config/minimax.json`。'],
        'examples': ['请用 minimax-web-search 搜今天的 AI 新闻。', '请用 minimax-web-search 查某公司的最新财报消息。'],
        'verify': 'python3 skills/default/minimax-web-search/scripts/web_search.py --help',
        'notes': ['购买/开通入口参见 skill 内说明。'],
    },
    'model-usage': {
        'title': 'Model Usage',
        'purpose': '按模型维度统计 Codex / Claude 的成本使用情况。',
        'needs': ['`codexbar` CLI（目前更偏 macOS）'],
        'setup': ['先确认 `codexbar cost --format json` 能输出。', '再用脚本做按模型汇总。'],
        'examples': ['请用 model-usage 统计最近使用最贵的模型。', '请用 model-usage 输出 codex provider 的全部模型费用。'],
        'verify': 'python3 skills/default/model-usage/scripts/model_usage.py --help',
    },
    'multi-search-engine': {
        'title': 'Multi Search Engine',
        'purpose': '17 个搜索引擎聚合，无需 API Key，适合国内外网页搜索与高级操作符检索。',
        'needs': ['无需 API Key'],
        'setup': ['直接按 skill 文档拼接搜索 URL 即可。', '更适合用作搜索策略参考，而非单一脚本入口。'],
        'examples': ['请用 multi-search-engine 设计一条跨 Google/百度/Brave 的检索方案。', '请用 multi-search-engine 给出 site: + 时间过滤的搜索链接。'],
    },
    'nano-pdf': {
        'title': 'Nano PDF',
        'purpose': '自然语言 PDF 编辑与处理。',
        'needs': ['视运行环境安装 `nano-pdf` 包'],
        'setup': ['先确认 `nano-pdf` 命令或对应 Python 包存在。', '若缺失，请按上游发行页安装。'],
        'examples': ['请用 nano-pdf 修改 PDF 中的某段文字。', '请用 nano-pdf 从 PDF 中抽取表格并整理。'],
    },
    'news-radar': {
        'title': 'News Radar',
        'purpose': '通过 TrendRadar MCP 聚合国际新闻、热点话题和来源分析。',
        'needs': ['TrendRadar MCP 服务 `http://localhost:3333/mcp`'],
        'setup': ['先确认 TrendRadar MCP 容器/服务已运行。', '如果只想做普通网页搜索，不要优先用这个 skill。'],
        'examples': ['请用 news-radar 汇总过去 24 小时的 AI 热点。', '请用 news-radar 比较 Reuters 和 Bloomberg 对同一事件的报道。'],
        'verify': 'python3 skills/default/news-radar/scripts/get_trending_news.py --help',
    },
    'openclaw-cron-setup': {
        'title': 'OpenClaw Cron Setup',
        'purpose': '配置定时唤醒和主动任务执行框架。',
        'examples': ['请用 openclaw-cron-setup 配一个每天 9 点的巡检任务。', '请用 openclaw-cron-setup 设计定时执行但由 cron delivery 投递结果的流程。'],
    },
    'pdf': {
        'title': 'PDF',
        'purpose': 'PDF 解析、表单填写、合并拆分与结构化提取。',
        'needs': ['依赖通常由安装脚本自动补齐；缺失时安装 `pypdf` / `pdf2image`。'],
        'examples': ['请用 pdf 填写这份 PDF 表单。', '请用 pdf 把多个 PDF 合并并抽取第一页。'],
        'verify': 'python3 skills/default/pdf/scripts/check_fillable_fields.py --help',
    },
    'pptx': {
        'title': 'PPTX',
        'purpose': '创建、编辑、重排和导出 PowerPoint。',
        'needs': ['Python 依赖 `python-pptx`'],
        'examples': ['请用 pptx 生成一份 10 页路演稿。', '请用 pptx 调整这个演示文稿的顺序并替换标题。'],
        'verify': 'node -e "console.log(\"pptx skill ready\")"',
    },
    'proactive-agent': {
        'title': 'Proactive Agent',
        'purpose': '让 Agent 主动巡检、主动跟进，而不是只等用户输入。',
        'examples': ['请按 proactive-agent 的规则设计一套主动巡检流程。', '请用 proactive-agent 复核这套 heartbeat 机制是否足够主动。'],
    },
    'reflection': {
        'title': 'Reflection',
        'purpose': '对对话、工具调用和执行结果做复盘与改进建议。',
        'examples': ['请用 reflection 复盘这次失败的自动化任务。', '请用 reflection 总结最近 5 次交互中的共性问题。'],
    },
    'self-improving-agent-cn': {
        'title': 'Self Improving Agent CN',
        'purpose': '中文增强版自我反思、自我纠错与改进沉淀。',
        'examples': ['请用 self-improving-agent-cn 记录这次错误和改进建议。', '请用 self-improving-agent-cn 输出一条最佳实践。'],
    },
    'shell': {
        'title': 'Shell',
        'purpose': '命令行自动化、脚本执行、进程和文件操作。',
        'examples': ['请用 shell 自动整理日志文件。', '请用 shell 检查端口占用并给出清理方案。'],
    },
    'skill-creator': {
        'title': 'Skill Creator',
        'purpose': '创建与迭代自定义 skill 的方法论和脚手架。',
        'examples': ['请用 skill-creator 帮我设计一个新的投研 skill。', '请用 skill-creator 审查这个 skill 的结构是否合格。'],
        'verify': 'python3 skills/default/skill-creator/scripts/quick_validate.py --help',
    },
    'stock-monitor-skill': {
        'title': 'Stock Monitor',
        'purpose': '股票监控预警系统，支持成本线、均线、RSI、量能、跳空和动态止盈。',
        'needs': ['建议安装 `akshare` 与默认 Python 运行依赖'],
        'setup': ['先根据 README/SKILL 配置监控标的。', '后台常驻可执行 `./control.sh start`。'],
        'examples': ['请用 stock-monitor-skill 配置 600519 的预警规则。', '请用 stock-monitor-skill 启动后台监控并查看状态。'],
        'verify': 'bash skills/default/stock-monitor-skill/scripts/control.sh status',
    },
    'summarize': {
        'title': 'Summarize',
        'purpose': '总结网页、PDF、本地文件、图片、音视频和 YouTube 链接。',
        'needs': ['二进制 `summarize`', '至少一种模型 API Key：`OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `XAI_API_KEY` / `GEMINI_API_KEY`'],
        'setup': ['安装 summarize CLI。', '在 `~/.openclaw/env` 或当前 shell 设置所选模型厂商的 key。', '如需 YouTube 回退可再配置 `APIFY_API_TOKEN`；如需网页反爬回退可配置 `FIRECRAWL_API_KEY`。'],
        'examples': ['请用 summarize 总结这个 PDF。', '请用 summarize 概括这个 YouTube 视频内容。'],
        'verify': 'summarize --help',
    },
    'tavily-search': {
        'title': 'Tavily Search',
        'purpose': 'LLM 优化的网页搜索，适合高质量检索和带筛选条件的搜索。',
        'needs': ['Tavily OAuth 或 `TAVILY_API_KEY`'],
        'setup': ['首次运行可走 OAuth 浏览器登录。', '或直接把 `TAVILY_API_KEY` 写入环境变量。'],
        'examples': ['请用 tavily-search 搜索最近一周的 AI Agent 新闻。', '请用 tavily-search 仅搜索 arxiv.org 和 github.com 的资料。'],
        'verify': 'bash skills/default/tavily-search/scripts/search.sh --help',
    },
    'url-to-markdown': {
        'title': 'URL to Markdown',
        'purpose': '把网页转换成 Markdown，适合做资料存档和进一步摘要。',
        'needs': ['Node/TS 运行环境', '如需指定浏览器可配 `URL_CHROME_PATH`'],
        'setup': ['无 API Key。', '若默认浏览器不可用，可配置 `URL_CHROME_PATH`、`URL_DATA_DIR`、`URL_CHROME_PROFILE_DIR`。'],
        'examples': ['请用 url-to-markdown 把这个网页转成 Markdown。', '请用 url-to-markdown 抽取正文并保存。'],
        'verify': 'node --version',
    },
    'web-design': {
        'title': 'Web Design',
        'purpose': '做 UI/可用性审查与网页设计建议。',
        'examples': ['请用 web-design 审查这个页面的可用性问题。', '请用 web-design 给出一个更适合移动端的设计方向。'],
    },
    'web-search': {
        'title': 'Web Search',
        'purpose': '基于 DuckDuckGo 的通用网页/新闻/图片/视频搜索。',
        'needs': ['Python 依赖 `duckduckgo-search`'],
        'setup': ['执行 `pip install duckduckgo-search`。', '不需要 API Key。'],
        'examples': ['请用 web-search 搜今天的科技新闻。', '请用 web-search 搜指定主题的图片结果。'],
        'verify': 'python3 skills/default/web-search/scripts/search.py --help',
    },
    'xlsx': {
        'title': 'XLSX',
        'purpose': '表格读写、公式处理、分析和导出。',
        'needs': ['Python 依赖 `openpyxl`'],
        'examples': ['请用 xlsx 读取这个 Excel 并统计每列汇总。', '请用 xlsx 生成一个带公式的财务表。'],
        'verify': 'python3 -c "import openpyxl; print(openpyxl.__version__)"',
    },
}

UPSTREAM_OVERRIDES = {
    'agentmail': 'https://github.com/agentmail-to/agentmail-skills',
    'agentmail-cli': 'https://github.com/agentmail-to/agentmail-skills',
    'agentmail-mcp': 'https://github.com/agentmail-to/agentmail-skills',
    'agentmail-toolkit': 'https://github.com/agentmail-to/agentmail-skills',
}


def parse_description(skill_dir: Path) -> str:
    skill_md = skill_dir / 'SKILL.md'
    if not skill_md.exists():
        return '未提供描述。'
    text = skill_md.read_text(encoding='utf-8', errors='ignore')
    m = re.search(r'^description:\s*["\']?(.*?)["\']?$', text, re.M)
    if m and m.group(1).strip():
        return m.group(1).strip()
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith('#') and not line.startswith('---'):
            return line[:140]
    return '未提供描述。'


def load_upstreams() -> dict[str, str]:
    data = {}
    text = UPSTREAM_PATH.read_text(encoding='utf-8')
    in_table = False
    for line in text.splitlines():
        if line.startswith('| Skill |'):
            in_table = True
            continue
        if in_table:
            if not line.startswith('|'):
                break
            if line.startswith('|---|'):
                continue
            parts = [p.strip() for p in line.strip('|').split('|')]
            if len(parts) >= 3:
                data[parts[0]] = parts[2]
    data.update(UPSTREAM_OVERRIDES)
    return data


def profile_label(skill: str) -> str:
    if skill in PROFILE_BASIC:
        return '基础档默认安装'
    if skill in PROFILE_EXTENDED:
        return '扩展档默认安装'
    return '仅全量默认包/手动同步'


def render_guide(skill: str, skill_dir: Path, upstream: str) -> str:
    meta = OVERRIDES.get(skill, {})
    title = meta.get('title', skill)
    purpose = meta.get('purpose', parse_description(skill_dir))
    needs = meta.get('needs', ['无强制 API Key；按 skill 自身依赖运行。'])
    setup = meta.get('setup', ['通常无需额外配置。若运行时报缺依赖，再按 `SKILL.md` 补装。'])
    examples = meta.get('examples', [f'请使用 {skill} 帮我处理当前任务。', f'如果 {skill} 需要额外配置，请先告诉我缺少什么。'])
    verify = meta.get('verify', 'ls -la ~/.openclaw/skills/{}'.format(skill))
    notes = meta.get('notes', [])
    lines = [
        f'# {title} 使用指南',
        '',
        '## 1. 功能定位',
        f'- {purpose}',
        f'- 默认档位: {profile_label(skill)}',
        f'- 仓库目录: `skills/default/{skill}`',
        f'- 安装后目录: `~/.openclaw/skills/{skill}`',
        '',
        '## 2. 使用前准备',
    ]
    lines.extend(f'- {item}' for item in needs)
    lines.extend(['', '## 3. 配置步骤'])
    for idx, item in enumerate(setup, 1):
        lines.append(f'{idx}. {item}')
    lines.extend(['', '## 4. 推荐提问方式'])
    lines.extend(f'- {item}' for item in examples)
    lines.extend(['', '## 5. 手动验证'])
    lines.extend(['```bash', verify, '```', '', '## 6. 参考资料', f'- 上游来源: {upstream}', '- 本技能说明: `SKILL.md`'])
    if notes:
        lines.extend(['', '## 7. 备注'])
        lines.extend(f'- {item}' for item in notes)
    lines.append('')
    return '\n'.join(lines)


def main() -> int:
    upstreams = load_upstreams()
    guide_rows = []
    for skill_dir in sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir()):
        skill = skill_dir.name
        upstream = upstreams.get(skill, '见 docs/upstream-sources.md')
        guide = render_guide(skill, skill_dir, upstream)
        (skill_dir / 'GUIDE.md').write_text(guide, encoding='utf-8')
        needs_cfg = '是' if skill in OVERRIDES and 'needs' in OVERRIDES[skill] and not OVERRIDES[skill]['needs'][0].startswith('无强制') else '否'
        guide_rows.append((skill, profile_label(skill), needs_cfg, f'skills/default/{skill}/GUIDE.md'))

    lines = [
        '# Skills 使用指南总览',
        '',
        '所有默认 skill 都带有 `GUIDE.md`，安装到 `~/.openclaw/skills/<name>/GUIDE.md` 后，配置菜单可直接查看。',
        '',
        '| Skill | 默认档位 | 需要额外配置 | 指南路径 |',
        '|---|---|---|---|',
    ]
    for skill, profile, needs_cfg, path in guide_rows:
        lines.append(f'| {skill} | {profile} | {needs_cfg} | `{path}` |')
    INDEX_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'Wrote {INDEX_PATH} and {len(guide_rows)} guides')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
