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
2. `~/.codex/skills/<name>`（回退来源）
3. `~/.agents/skills/<name>`（第三方/扩展技能源）

| Skill | 本地目录 | 上游更新地址 |
|---|---|---|
| agent-browser | `skills/default/agent-browser` | ~/.codex/skills/agent-browser |
| agentmail | `skills/default/agentmail` | https://github.com/agentmail-to/agentmail-skills |
| agentmail-cli | `skills/default/agentmail-cli` | https://github.com/agentmail-to/agentmail-skills |
| agentmail-mcp | `skills/default/agentmail-mcp` | https://github.com/agentmail-to/agentmail-skills |
| agentmail-toolkit | `skills/default/agentmail-toolkit` | https://github.com/agentmail-to/agentmail-skills |
| akshare-stock | `skills/default/akshare-stock` | ~/.codex/skills/akshare-stock |
| ai-image-generation | `skills/default/ai-image-generation` | https://github.com/inference-sh/skills/tree/main/tools/image/ai-image-generation |
| android-native-dev | `skills/default/android-native-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/android-native-dev |
| baoyu-skills | `skills/default/baoyu-skills` | https://github.com/JimLiu/baoyu-skills |
| baoyu-article-illustrator | `skills/default/baoyu-article-illustrator` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-article-illustrator |
| baoyu-comic | `skills/default/baoyu-comic` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-comic |
| baoyu-compress-image | `skills/default/baoyu-compress-image` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-compress-image |
| baoyu-cover-image | `skills/default/baoyu-cover-image` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-cover-image |
| baoyu-danger-gemini-web | `skills/default/baoyu-danger-gemini-web` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-danger-gemini-web |
| baoyu-danger-x-to-markdown | `skills/default/baoyu-danger-x-to-markdown` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-danger-x-to-markdown |
| baoyu-format-markdown | `skills/default/baoyu-format-markdown` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-format-markdown |
| baoyu-image-gen | `skills/default/baoyu-image-gen` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-image-gen |
| baoyu-infographic | `skills/default/baoyu-infographic` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-infographic |
| baoyu-markdown-to-html | `skills/default/baoyu-markdown-to-html` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-markdown-to-html |
| baoyu-post-to-wechat | `skills/default/baoyu-post-to-wechat` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-wechat |
| baoyu-post-to-weibo | `skills/default/baoyu-post-to-weibo` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-weibo |
| baoyu-post-to-x | `skills/default/baoyu-post-to-x` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-x |
| baoyu-slide-deck | `skills/default/baoyu-slide-deck` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-slide-deck |
| baoyu-translate | `skills/default/baoyu-translate` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-translate |
| baoyu-url-to-markdown | `skills/default/baoyu-url-to-markdown` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-url-to-markdown |
| baoyu-xhs-images | `skills/default/baoyu-xhs-images` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-xhs-images |
| baoyu-youtube-transcript | `skills/default/baoyu-youtube-transcript` | https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-youtube-transcript |
| blogwatcher | `skills/default/blogwatcher` | https://github.com/Hyaxia/blogwatcher |
| brainstorming | `skills/default/brainstorming` | ~/.codex/skills/brainstorming |
| buddy-sings | `skills/default/buddy-sings` | https://github.com/MiniMax-AI/skills/tree/main/skills/buddy-sings |
| capability-evolver | `skills/default/capability-evolver` | ~/.codex/skills/capability-evolver |
| chrome-devtools-mcp | `skills/default/chrome-devtools-mcp` | https://github.com/ChromeDevTools/chrome-devtools-mcp |
| content-strategy | `skills/default/content-strategy` | https://github.com/coreyhaines31/marketingskills/tree/main/skills/content-strategy |
| docx | `skills/default/docx` | ~/.codex/skills/docx |
| find-skills | `skills/default/find-skills` | ~/.codex/skills/find-skills |
| flutter-dev | `skills/default/flutter-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/flutter-dev |
| frontend-design | `skills/default/frontend-design` | ~/.codex/skills/frontend-design |
| frontend-dev | `skills/default/frontend-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/frontend-dev |
| fullstack-dev | `skills/default/fullstack-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/fullstack-dev |
| gemini-image-service | `skills/default/gemini-image-service` | ~/.codex/skills/gemini-image-service |
| gif-sticker-maker | `skills/default/gif-sticker-maker` | https://github.com/MiniMax-AI/skills/tree/main/skills/gif-sticker-maker |
| github | `skills/default/github` | ~/.codex/skills/github |
| grok-imagine-1.0-video | `skills/default/grok-imagine-1.0-video` | ~/.codex/skills/grok-imagine-1.0-video |
| inference-skills | `skills/default/inference-skills` | https://github.com/inference-sh/skills |
| ios-application-dev | `skills/default/ios-application-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/ios-application-dev |
| marketingskills | `skills/default/marketingskills` | https://github.com/coreyhaines31/marketingskills |
| mcp-builder | `skills/default/mcp-builder` | ~/.codex/skills/mcp-builder |
| minimax-image-understanding | `skills/default/minimax-image-understanding` | ~/.codex/skills/minimax-image-understanding |
| minimax-docx | `skills/default/minimax-docx` | https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-docx |
| minimax-multimodal-toolkit | `skills/default/minimax-multimodal-toolkit` | https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-multimodal-toolkit |
| minimax-music-gen | `skills/default/minimax-music-gen` | https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-music-gen |
| minimax-music-playlist | `skills/default/minimax-music-playlist` | https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-music-playlist |
| minimax-pdf | `skills/default/minimax-pdf` | https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-pdf |
| minimax-web-search | `skills/default/minimax-web-search` | ~/.codex/skills/minimax-web-search |
| minimax-xlsx | `skills/default/minimax-xlsx` | https://github.com/MiniMax-AI/skills/tree/main/skills/minimax-xlsx |
| model-usage | `skills/default/model-usage` | ~/.codex/skills/model-usage |
| multi-search-engine | `skills/default/multi-search-engine` | ~/.codex/skills/multi-search-engine |
| nano-banana-service | `skills/default/nano-banana-service` | ~/.codex/skills/nano-banana-service |
| nano-pdf | `skills/default/nano-pdf` | https://pypi.org/project/nano-pdf/ |
| news-radar | `skills/default/news-radar` | ~/.codex/skills/news-radar |
| notebooklm-skill | `skills/default/notebooklm-skill` | https://github.com/PleasePrompto/notebooklm-skill |
| openclaw-cron-setup | `skills/default/openclaw-cron-setup` | ~/.codex/skills/openclaw-cron-setup |
| pdf | `skills/default/pdf` | ~/.codex/skills/pdf |
| pptx | `skills/default/pptx` | ~/.codex/skills/pptx |
| pptx-generator | `skills/default/pptx-generator` | https://github.com/MiniMax-AI/skills/tree/main/skills/pptx-generator |
| proactive-agent | `skills/default/proactive-agent` | ~/.codex/skills/proactive-agent |
| react-native-dev | `skills/default/react-native-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/react-native-dev |
| reflection | `skills/default/reflection` | https://clawic.com/skills/reflection |
| self-improving-agent-cn | `skills/default/self-improving-agent-cn` | ~/.codex/skills/self-improving-agent-cn |
| shader-dev | `skills/default/shader-dev` | https://github.com/MiniMax-AI/skills/tree/main/skills/shader-dev |
| shell | `skills/default/shell` | ~/.codex/skills/shell |
| skill-creator | `skills/default/skill-creator` | ~/.codex/skills/skill-creator |
| social-content | `skills/default/social-content` | https://github.com/coreyhaines31/marketingskills/tree/main/skills/social-content |
| stock-monitor-skill | `skills/default/stock-monitor-skill` | ~/.codex/skills/stock-monitor-skill |
| summarize | `skills/default/summarize` | https://summarize.sh |
| tavily-search | `skills/default/tavily-search` | ~/.codex/skills/tavily-search |
| url-to-markdown | `skills/default/url-to-markdown` | ~/.codex/skills/url-to-markdown |
| vision-analysis | `skills/default/vision-analysis` | https://github.com/MiniMax-AI/skills/tree/main/skills/vision-analysis |
| web-design | `skills/default/web-design` | ~/.agents/skills/vercel-agent-skills/skills/web-design-guidelines |
| web-search | `skills/default/web-search` | ~/.codex/skills/web-search |
| xlsx | `skills/default/xlsx` | ~/.codex/skills/xlsx |

### Skills 更新建议流程

1. 先检查目标 skill 的上游版本（ClawHub、GitHub 或本机 codex skills 源）。
2. 用上游版本覆盖 `skills/default/<name>/`。
3. 运行预检：`./scripts/preflight-check.sh`。
4. 提交并在发布说明中标注变更的 skill 名称与来源。
