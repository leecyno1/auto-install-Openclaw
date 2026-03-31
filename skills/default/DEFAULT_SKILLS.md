# Default Skills Bundle

Source priority used for this bundle:
1. `~/.openclaw/skills/<name>`
2. `/Users/lichengyin/.codex/skills/<name>` (fallback)

This file is the install-facing quick reference. It keeps the default bundle readable and explains what each core skill is for.
For the full install matrix, API-key requirements, and guide paths, use `docs/skills-guides.md`.

## 基础执行与自检

- `capability-evolver`: 自演化引擎，分析运行历史并提出能力补强方向。
- `openclaw-cron-setup`: 配置 OpenClaw 定时任务和例行执行入口。
- `proactive-agent`: 让代理主动推进任务，而不是只做一步一停。
- `self-improving-agent-cn`: 中文自我复盘与持续改进工作流。
- `brainstorming`: 在动手前先梳理需求、目标、限制和设计方向。
- `reflection`: 任务结束前做复核、回看和结果修正。
- `find-skills`: 根据任务找到合适的技能并提示调用。
- `skill-creator`: 创建或更新技能目录、说明和工作流骨架。
- `subagent-driven-development`: 把复杂开发任务拆成可并行的子代理执行。
- `using-superpowers`: 强制先找技能、再回答，防止跳过已有能力。
- `verification-before-completion`: 先验证再宣称完成，防止“没测就说好了”。
- `writing-skills`: 为技能编写更清晰的说明、用法和验证文档。

## 浏览器、系统与外部集成

- `agent-browser`: 用结构化命令驱动浏览器，适合网页登录、抓取、点选和自动化。
- `chrome-devtools-mcp`: 用浏览器 DevTools 能力做页面调试、抓请求和性能分析。
- `github`: 处理仓库、Issue、PR 和 GitHub 流程。
- `mcp-builder`: 构建 MCP 服务，把外部 API 或系统封装成工具。
- `model-usage`: 记录和分析模型调用情况，帮助看成本与路由。
- `shell`: 执行命令行任务和系统脚本，是很多自动化动作的基础。
- `agentmail`: 给代理分配独立邮箱，用于收发信、附件处理和草稿审批。
- `agentmail-cli`: 通过命令行方式调用 AgentMail 邮件能力。
- `agentmail-mcp`: 把 AgentMail 包装成 MCP 工具，便于模型直接调用。
- `agentmail-toolkit`: 给邮件代理补充更完整的工具链与接口能力。
- `lark-calendar`: 管理飞书日历和待办，支持事件创建、更新和人员解析。

## 搜索、情报与信息获取

- `minimax-image-understanding`: 用 MiniMax 做图片理解、图像内容识别和视觉问答。
- `tavily-search`: 使用 Tavily 搜索，适合检索网页资料和结构化结果。
- `web-search`: 通用联网搜索能力，适合资料检索和信息查找。
- `minimax-web-search`: 优先走 MiniMax MCP 搜索链路，处理最新资讯和网页检索。
- `blogwatcher`: 跟踪博客更新，做订阅式情报获取。
- `news-radar`: 汇总新闻和热点，适合监控市场与外部变化。
- `multi-search-engine`: 聚合多搜索源，减少单一搜索结果偏差。
- `url-to-markdown`: 把网页内容转换为 Markdown，便于整理与二次处理。
- `media-downloader`: 按描述搜索并下载图片、视频素材，可辅助搜图和拉片。

## 文档、知识与办公处理

- `summarize`: 对长内容做摘要、提炼重点和结构整理。
- `pdf`: 处理 PDF 提取、合并、拆分、表单填写和批量分析。
- `nano-pdf`: 用自然语言编辑 PDF，适合改字、补内容和快速修订。
- `docx`: 创建、修改和分析 Word 文档，保留格式与批注工作流。
- `pptx`: 生成和编辑演示文稿，适合汇报与提案材料。
- `xlsx`: 处理表格、公式、数据分析和表单型工作。
- `notebooklm-skill`: 直接查询 NotebookLM 笔记库，得到带来源依据的答案。
- `task`: 任务管理与执行拆解能力。
- `todo`: 待办整理与任务追踪能力。
- `weather`: 查询天气，为出行、日程或本地建议提供环境信息。

## 内容、运营与增长

- `content-strategy`: 做内容规划、选题设计、栏目结构和内容路线图。
- `social-content`: 生成和优化社媒内容，适合微博、X、LinkedIn 等渠道分发。
- `marketingskills`: 一组市场运营技能，覆盖内容、渠道和营销动作。
- `frontend-design`: 设计并实现更有辨识度的前端页面和组件。
- `web-design`: 通用 Web 页面设计与视觉搭建能力。

## 数据、金融与分析

- `stock-monitor-skill`: 监控股票信息、行情变化与提醒逻辑。
- `akshare-stock`: 通过 AkShare 获取股票和金融数据。
- `data-analyst`: 做数据整理、分析和结论提炼。
- `finance-data`: 处理金融数据查询、加工与基础分析。
- `skill-security-auditor`: 审查技能安全边界、潜在风险和调用规范。

## 图像、视觉与生成

- `ai-image-generation`: 统一走多模型生图能力，适合封面、配图、营销图和视觉草稿。
- `gemini-image-service`: 调用 Gemini 图像能力做图片生成或改写。
- `grok-imagine-1.0-video`: 处理 Grok 视频/视觉生成链路。
- `inference-skills`: inference.sh 相关工具集合，扩展图像与多模态能力。

## 高级内容与渠道扩展

- `baoyu-skills`: Baoyu 技能集合入口，覆盖内容生产与分发场景。
- `baoyu-article-illustrator`: 为文章自动匹配插图方案和图片生成流程。
- `baoyu-comic`: 生成漫画式视觉内容。
- `baoyu-compress-image`: 压缩图片资源，方便分发和上传。
- `baoyu-cover-image`: 生成文章封面图。
- `baoyu-danger-gemini-web`: 使用 Gemini Web 风格链路做网页型能力扩展。
- `baoyu-danger-x-to-markdown`: 把 X/Twitter 内容转成 Markdown。
- `baoyu-format-markdown`: 把 Markdown 做成更适合发布的格式化版本。
- `baoyu-image-gen`: Baoyu 自带图像生成工作流。
- `baoyu-infographic`: 生成信息图和高密度视觉摘要。
- `baoyu-markdown-to-html`: 把 Markdown 转成适合公众号等渠道的 HTML。
- `baoyu-post-to-wechat`: 推送内容到微信公众号工作流。
- `baoyu-post-to-weibo`: 推送内容到微博。
- `baoyu-post-to-x`: 推送内容到 X/Twitter。
- `baoyu-slide-deck`: 生成演示稿页面和配套视觉。
- `baoyu-translate`: 文稿翻译与多语言处理。
- `baoyu-url-to-markdown`: 把网页内容转为可编辑 Markdown。
- `baoyu-xhs-images`: 生成小红书风格图文图卡。
- `baoyu-youtube-transcript`: 获取和整理 YouTube 字幕文本。

## 进阶档附加能力

- `oracle`: 把代码和提示词打包给第二模型复核，适合调试、重构和设计检查。
- `paperless-docs`: 对接 Paperless-ngx 文档库，检索、上传、打标签、回收资料。
- `planning-with-files`: 复杂任务走文件化规划，自动拆出计划、发现和进度文件。

## 说明

- 基础档默认安装的是稳定常用技能。
- 扩展档会叠加更多搜索、图像和文档相关能力。
- 超级档再叠加更重的内容生产和高级工作流技能。
- 菜单内查看技能时，已支持直接显示一句话简介，不再只显示技能名。
