# OpenClaw 初始化工作档案（7 选 1）

> 目标：安装阶段与配置菜单统一采用“工作档案”选择，不再使用旧的人格问答。
> 说明：该能力只写入 `identity` 与 `persona` 规则文件，不会强制安装新技能包。

## 档案总览

| 选择 | 档案 | 定位 | agency-agents 对照 |
|---|---|---|---|
| 1 | 🦞 综合助理（通用） | 通用总管，覆盖日程、写作、搜索、协作、复盘 | `specialized/agents-orchestrator` + `project-management/project-manager-senior` |
| 2 | 🗡️ 分析研究（投资） | 券商式数据分析、估值拆解、机会挖掘 | `sales/sales-pipeline-analyst` + `support/support-finance-tracker` + `product/product-trend-researcher` |
| 3 | 🧙 学术研究 | 论文科研、知识管理、结构化学习输出 | `marketing/marketing-book-co-author` + `specialized/specialized-document-generator` + `testing/testing-evidence-collector` |
| 4 | 🪄 团队管理 | 招聘、人力、流程、团队协同与组织管理 | `specialized/recruitment-specialist` + `project-management/project-management-studio-operations` + `project-management/project-manager-senior` |
| 5 | ⚔️ 工程开发 | 编程交付、测试排障、DevOps 与稳定性 | `engineering/engineering-senior-developer` + `engineering/engineering-code-reviewer` + `engineering/engineering-devops-automator` + `engineering/engineering-sre` |
| 6 | 🛡️ 市场增长 | 增长运营、SEO、投放、内容分发与客户运营 | `marketing/marketing-growth-hacker` + `marketing/marketing-seo-specialist` + `marketing/marketing-social-media-strategist` + `marketing/marketing-content-creator` |
| 7 | 🏹 设计创作 | 前端/UI/视觉/平面/工业/建筑概念与自媒体设计 | `design/design-ui-designer` + `design/design-ux-architect` + `design/design-visual-storyteller` + `design/design-image-prompt-engineer` |

## 每个档案推荐 Skills（核心 + 扩展）

### 1) 综合助理（通用）
- 核心：`proactive-agent` `openclaw-cron-setup` `reflection` `find-skills` `shell` `web-search` `summarize` `docx` `xlsx` `agentmail`
- 扩展：`task` `todo` `todoist-api` `ai-meeting-notes` `openclaw-feeds` `weather`

### 2) 分析研究（投资）
- 核心：`akshare-stock` `stock-monitor-skill` `multi-search-engine` `web-search` `tavily-search` `news-radar` `summarize` `url-to-markdown` `xlsx`
- 扩展：`finance-data` `data-analyst` `google-trends` `openclaw-feeds` `reddit` `requesthunt` `producthunt` `session-logs`

### 3) 学术研究
- 核心：`brainstorming` `summarize` `web-search` `tavily-search` `url-to-markdown` `docx` `pdf` `nano-pdf` `pptx` `xlsx`
- 扩展：`ai-meeting-notes` `ai-ppt-generate` `paperless-docs` `paperless-ngx-tools` `format-pro` `byterover`

### 4) 团队管理
- 核心：`proactive-agent` `openclaw-cron-setup` `docx` `xlsx` `pptx` `agentmail` `github` `reflection`
- 扩展：`task` `todo` `todoist-api` `ai-meeting-notes` `lark-calendar` `data-reconciliation-exceptions` `publish-guard` `session-logs`

### 5) 工程开发
- 核心：`shell` `github` `mcp-builder` `chrome-devtools-mcp` `agent-browser` `model-usage` `web-search` `minimax-image-understanding` `reflection`
- 扩展：`tdd` `test-driven-development` `subagent-driven-development` `skill-security-auditor` `github-actions-generator` `gitclassic` `prisma-database-setup` `database` `preflight-checks` `tmux`

### 6) 市场增长
- 核心：`web-search` `tavily-search` `news-radar` `summarize` `url-to-markdown` `docx` `xlsx` `agentmail` `frontend-design` `web-design`
- 扩展：`programmatic-seo` `seo-geo` `social-content` `content-strategy` `google-trends` `twitter` `weibo-manager` `weibo-fresh-posts` `xiaohongshu-ops` `xiaohongshu-auto` `douyin-hot-trend` `douyin-upload-skill` `bilibili-hot-monitor` `baoyu-post-to-wechat` `baoyu-post-to-x`

### 7) 设计创作
- 核心：`frontend-design` `web-design` `gemini-image-service` `nano-banana-service` `grok-imagine-1.0-video` `pptx` `docx` `summarize`
- 扩展：`ai-image-generation` `banner-creator` `logo-creator` `infographic-pro` `ai-ppt-generate` `baoyu-article-illustrator` `baoyu-comic` `baoyu-cover-image` `baoyu-infographic` `baoyu-slide-deck` `video-frames` `tailwind-design-system` `web-design-guidelines`

## 融合落地方案（避免与现有规则冲突）

- 注入位置：
  - `~/.openclaw/agents/main/persona/SOUL.md`
  - `~/.openclaw/agents/main/persona/AGENTS.md`
  - `~/.openclaw/agents/main/persona/USER.md`
  - `~/.openclaw/agents/main/persona/IDENTITY.md`
- 规则优先级：
  - 安全与 token 规划规则 > 工作档案风格
  - 工作档案只影响目标、语气、工作方式、技能建议，不覆盖安全红线
- 可切换：
  - 安装阶段可选 1 次
  - 配置菜单 `9 身份与个性` 可随时改

## 明确排除（全角色统一）

以下技能不纳入本次 7 角色推荐：
- `apple-calendar`
- `apple-notes`
- `apple-reminders`
- `things-mac`
