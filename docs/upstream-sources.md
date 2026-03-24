# 本地插件与 Skills 上游更新地址索引

本文档用于维护本仓库内置资产（`plugins/official` 与 `skills/default`）的上游来源与更新入口。

## 1) 默认消息渠道插件（安装后自动同步）

> 默认同步目标：`tele / feishu / wechat / dingtalk / qq / discord / whatsapp / imessage`

| 渠道 | 本地同步方式 | 本地包路径（仓库） | 上游更新地址 |
|---|---|---|---|
| Telegram (`tele`) | 内置启用（随 OpenClaw Core） | 无（内置） | https://docs.openclaw.ai/channel/telegram |
| Feishu | 本地插件包安装 | `plugins/official/feishu` 或 `plugins/official/archives/openclaw-feishu-*.tgz` | https://www.npmjs.com/package/@openclaw/feishu |
| WeChat | 本地插件包安装 | `plugins/official/archives/openclaw-wechat-channel-*.tgz` | https://www.npmjs.com/package/openclaw-wechat-channel |
| DingTalk | 本地插件包安装 | `plugins/official/archives/openclaw-channel-dingtalk-*.tgz` | https://www.npmjs.com/package/openclaw-channel-dingtalk |
| QQ | 本地插件包安装 | `plugins/official/archives/sliverp-qqbot-*.tgz` | https://www.npmjs.com/package/@sliverp/qqbot |
| Discord | 本地插件包安装 | `plugins/official/archives/openclaw-discord-*.tgz` | https://www.npmjs.com/package/@openclaw/discord |
| WhatsApp | 本地插件包安装 | `plugins/official/archives/openclaw-whatsapp-*.tgz` | https://www.npmjs.com/package/@openclaw/whatsapp |
| iMessage | 内置启用（随 OpenClaw Core） | 无（内置） | https://docs.openclaw.ai/channel/imessage |

### 插件更新建议流程

1. 用 `npm view <package> version` 检查新版本。
2. 用 `npm pack <package>@<version>` 生成 tgz。
3. 将 tgz 放入 `plugins/official/archives/`。
4. 提交后，安装器会优先使用本地包（仅在显式开启 `OPENCLAW_ALLOW_REMOTE_PLUGIN_FALLBACK=1` 时才会远端兜底）。

### 仓库插件库存（完整）

| 本地归档包 | 本地路径 | 对应上游更新地址 |
|---|---|---|
| `openclaw-feishu-*.tgz` | `plugins/official/archives/openclaw-feishu-*.tgz` | https://www.npmjs.com/package/@openclaw/feishu |
| `openclaw-discord-*.tgz` | `plugins/official/archives/openclaw-discord-*.tgz` | https://www.npmjs.com/package/@openclaw/discord |
| `openclaw-whatsapp-*.tgz` | `plugins/official/archives/openclaw-whatsapp-*.tgz` | https://www.npmjs.com/package/@openclaw/whatsapp |
| `openclaw-msteams-*.tgz` | `plugins/official/archives/openclaw-msteams-*.tgz` | https://www.npmjs.com/package/@openclaw/msteams |
| `openclaw-mattermost-*.tgz` | `plugins/official/archives/openclaw-mattermost-*.tgz` | https://www.npmjs.com/package/@openclaw/mattermost |
| `openclaw-matrix-*.tgz` | `plugins/official/archives/openclaw-matrix-*.tgz` | https://www.npmjs.com/package/@openclaw/matrix |
| `openclaw-line-*.tgz` | `plugins/official/archives/openclaw-line-*.tgz` | https://www.npmjs.com/package/@openclaw/line |
| `openclaw-nextcloud-talk-*.tgz` | `plugins/official/archives/openclaw-nextcloud-talk-*.tgz` | https://www.npmjs.com/package/@openclaw/nextcloud-talk |
| `openclaw-twitch-*.tgz` | `plugins/official/archives/openclaw-twitch-*.tgz` | https://www.npmjs.com/package/@openclaw/twitch |
| `openclaw-zalo-*.tgz` | `plugins/official/archives/openclaw-zalo-*.tgz` | https://www.npmjs.com/package/@openclaw/zalo |
| `openclaw-zalouser-*.tgz` | `plugins/official/archives/openclaw-zalouser-*.tgz` | https://www.npmjs.com/package/@openclaw/zalouser |
| `openclaw-nostr-*.tgz` | `plugins/official/archives/openclaw-nostr-*.tgz` | https://www.npmjs.com/package/@openclaw/nostr |
| `openclaw-tlon-*.tgz` | `plugins/official/archives/openclaw-tlon-*.tgz` | https://www.npmjs.com/package/@openclaw/tlon |
| `openclaw-synology-chat-*.tgz` | `plugins/official/archives/openclaw-synology-chat-*.tgz` | https://www.npmjs.com/package/@openclaw/synology-chat |
| `openclaw-bluebubbles-*.tgz` | `plugins/official/archives/openclaw-bluebubbles-*.tgz` | https://www.npmjs.com/package/@openclaw/bluebubbles |
| `openclaw-wechat-channel-*.tgz` | `plugins/official/archives/openclaw-wechat-channel-*.tgz` | https://www.npmjs.com/package/openclaw-wechat-channel |
| `openclaw-channel-dingtalk-*.tgz` | `plugins/official/archives/openclaw-channel-dingtalk-*.tgz` | https://www.npmjs.com/package/openclaw-channel-dingtalk |
| `sliverp-qqbot-*.tgz` | `plugins/official/archives/sliverp-qqbot-*.tgz` | https://www.npmjs.com/package/@sliverp/qqbot |
| `tencent-connect-openclaw-qqbot-*.tgz` | `plugins/official/archives/tencent-connect-openclaw-qqbot-*.tgz` | https://www.npmjs.com/package/@tencent-connect/openclaw-qqbot |
| `wecom-wecom-openclaw-plugin-*.tgz` | `plugins/official/archives/wecom-wecom-openclaw-plugin-*.tgz` | https://www.npmjs.com/package/@wecom/wecom-openclaw-plugin |
| `openclaw-china-wecom-*.tgz` | `plugins/official/archives/openclaw-china-wecom-*.tgz` | https://www.npmjs.com/package/@openclaw-china/wecom |
| `openclaw-china-channels-*.tgz` | `plugins/official/archives/openclaw-china-channels-*.tgz` | https://www.npmjs.com/package/@openclaw-china/channels |
| `marshulll-openclaw-wecom-*.tgz` | `plugins/official/archives/marshulll-openclaw-wecom-*.tgz` | https://www.npmjs.com/package/@marshulll/openclaw-wecom |

## 2) 默认 Skills 包上游索引

来源优先级（与 `skills/default/DEFAULT_SKILLS.md` 一致）：

1. `~/.openclaw/skills/<name>`
2. `/Users/lichengyin/.codex/skills/<name>`（回退来源）

| Skill | 本地目录 | 上游更新地址 |
|---|---|---|
| agent-browser | `skills/default/agent-browser` | /Users/lichengyin/.codex/skills/agent-browser |
| agentmail | `skills/default/agentmail` | https://github.com/agentmail-to/agentmail-skills |
| agentmail-cli | `skills/default/agentmail-cli` | https://github.com/agentmail-to/agentmail-skills |
| agentmail-mcp | `skills/default/agentmail-mcp` | https://github.com/agentmail-to/agentmail-skills |
| agentmail-toolkit | `skills/default/agentmail-toolkit` | https://github.com/agentmail-to/agentmail-skills |
| akshare-stock | `skills/default/akshare-stock` | /Users/lichengyin/.codex/skills/akshare-stock |
| ai-image-generation | `skills/default/ai-image-generation` | https://github.com/inference-sh/skills/tree/main/tools/image/ai-image-generation |
| blogwatcher | `skills/default/blogwatcher` | https://github.com/Hyaxia/blogwatcher |
| brainstorming | `skills/default/brainstorming` | /Users/lichengyin/.codex/skills/brainstorming |
| capability-evolver | `skills/default/capability-evolver` | /Users/lichengyin/.codex/skills/capability-evolver |
| chrome-devtools-mcp | `skills/default/chrome-devtools-mcp` | https://github.com/ChromeDevTools/chrome-devtools-mcp |
| content-strategy | `skills/default/content-strategy` | https://github.com/coreyhaines31/marketingskills/tree/main/skills/content-strategy |
| docx | `skills/default/docx` | /Users/lichengyin/.codex/skills/docx |
| find-skills | `skills/default/find-skills` | /Users/lichengyin/.codex/skills/find-skills |
| frontend-design | `skills/default/frontend-design` | /Users/lichengyin/.codex/skills/frontend-design |
| gemini-image-service | `skills/default/gemini-image-service` | /Users/lichengyin/.codex/skills/gemini-image-service |
| github | `skills/default/github` | /Users/lichengyin/.codex/skills/github |
| grok-imagine-1.0-video | `skills/default/grok-imagine-1.0-video` | /Users/lichengyin/.codex/skills/grok-imagine-1.0-video |
| inference-skills | `skills/default/inference-skills` | https://github.com/inference-sh/skills |
| marketingskills | `skills/default/marketingskills` | https://github.com/coreyhaines31/marketingskills |
| mcp-builder | `skills/default/mcp-builder` | /Users/lichengyin/.codex/skills/mcp-builder |
| minimax-understand-image | `skills/default/minimax-understand-image` | /Users/lichengyin/.codex/skills/minimax-understand-image |
| minimax-web-search | `skills/default/minimax-web-search` | /Users/lichengyin/.codex/skills/minimax-web-search |
| model-usage | `skills/default/model-usage` | /Users/lichengyin/.codex/skills/model-usage |
| multi-search-engine | `skills/default/multi-search-engine` | /Users/lichengyin/.codex/skills/multi-search-engine |
| nano-banana-service | `skills/default/nano-banana-service` | /Users/lichengyin/.codex/skills/nano-banana-service |
| nano-pdf | `skills/default/nano-pdf` | https://pypi.org/project/nano-pdf/ |
| news-radar | `skills/default/news-radar` | /Users/lichengyin/.codex/skills/news-radar |
| openclaw-cron-setup | `skills/default/openclaw-cron-setup` | /Users/lichengyin/.codex/skills/openclaw-cron-setup |
| pdf | `skills/default/pdf` | /Users/lichengyin/.codex/skills/pdf |
| pptx | `skills/default/pptx` | /Users/lichengyin/.codex/skills/pptx |
| proactive-agent | `skills/default/proactive-agent` | /Users/lichengyin/.codex/skills/proactive-agent |
| reflection | `skills/default/reflection` | https://clawic.com/skills/reflection |
| self-improving-agent-cn | `skills/default/self-improving-agent-cn` | /Users/lichengyin/.codex/skills/self-improving-agent-cn |
| shell | `skills/default/shell` | /Users/lichengyin/.codex/skills/shell |
| skill-creator | `skills/default/skill-creator` | /Users/lichengyin/.codex/skills/skill-creator |
| social-content | `skills/default/social-content` | https://github.com/coreyhaines31/marketingskills/tree/main/skills/social-content |
| stock-monitor-skill | `skills/default/stock-monitor-skill` | /Users/lichengyin/.codex/skills/stock-monitor-skill |
| summarize | `skills/default/summarize` | https://summarize.sh |
| tavily-search | `skills/default/tavily-search` | /Users/lichengyin/.codex/skills/tavily-search |
| url-to-markdown | `skills/default/url-to-markdown` | /Users/lichengyin/.codex/skills/url-to-markdown |
| web-design | `skills/default/web-design` | /Users/lichengyin/.codex/skills/web-design |
| web-search | `skills/default/web-search` | /Users/lichengyin/.codex/skills/web-search |
| xlsx | `skills/default/xlsx` | /Users/lichengyin/.codex/skills/xlsx |

### Skills 更新建议流程

1. 先检查目标 skill 的上游版本（ClawHub、GitHub 或本机 codex skills 源）。
2. 用上游版本覆盖 `skills/default/<name>/`。
3. 运行预检：`./scripts/preflight-check.sh`。
4. 提交并在发布说明中标注变更的 skill 名称与来源。
