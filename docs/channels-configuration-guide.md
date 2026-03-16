# OpenClaw 渠道插件详细配置手册

更新时间：2026-03-12  
适用项目：`auto-install-Openclaw`

## 1. 使用顺序（推荐）

1. 先运行官方模型向导：`openclaw onboard`
2. 再运行渠道菜单：`bash config-menu.sh`
3. 每次改动后执行：
   - `openclaw doctor --fix`
   - `openclaw gateway restart`
   - `openclaw channels list`
4. 如需追踪插件与 skills 上游来源，查看：`docs/upstream-sources.md`
5. 如需命令行快速配对，使用：`~/.openclaw/bin/openclaw-channel-pair`

### 快速配对示例

```bash
# QQ
~/.openclaw/bin/openclaw-channel-pair --channel qqbot --token "APP_ID:APP_SECRET" --restart

# 飞书
~/.openclaw/bin/openclaw-channel-pair --channel feishu --token "APP_ID:APP_SECRET" --restart

# 企业微信（官方插件，机器人模式）
~/.openclaw/bin/openclaw-channel-pair --channel wecom --token "TOKEN:ENCODING_AES_KEY:RECEIVE_ID" --restart

# 钉钉
~/.openclaw/bin/openclaw-channel-pair --channel dingtalk --token "CLIENT_ID:CLIENT_SECRET" --robot-code "<robotCode>" --restart
```

## 2. 渠道总览

| 菜单项 | 渠道 | 插件来源 | 插件包 |
|---|---|---|---|
| 1 | Telegram | 官方 | 内置 |
| 2 | Discord | 官方 | `@openclaw/discord` |
| 3 | WhatsApp | 官方 | `@openclaw/whatsapp` |
| 4 | Slack | 官方 | 内置 |
| 5 | 飞书 Feishu | 官方 | `@openclaw/feishu` |
| 6 | Signal | 官方 | `@openclaw/signal` |
| 7 | Microsoft Teams | 官方 | `@openclaw/msteams` |
| 8 | Mattermost | 官方 | `@openclaw/mattermost` |
| 9 | Google Chat | 官方 | `@openclaw/googlechat` |
| 10 | Matrix | 官方 | `@openclaw/matrix` |
| 11 | LINE | 官方 | `@openclaw/line` |
| 12 | Nextcloud Talk | 官方 | `@openclaw/nextcloud-talk` |
| 13 | 更多官方渠道 | 官方 | IRC/Twitch/Zalo/Nostr... |
| 15 | 微信 WeChatPad | 社区 | `openclaw-wechat-channel` |
| 17 | QQ | 社区 | `@sliverp/qqbot` |
| 18 | 企业微信 WeCom | 官方插件 | `@wecom/wecom-openclaw-plugin` |

## 3. 官方渠道配置要点

### Telegram
- 必填：`Bot Token`、`User ID`
- 菜单流程：`[3]消息渠道 -> [1]Telegram`

### Discord
- 必填：`Bot Token`、`Channel ID`
- 注意：需开启 `Message Content Intent`
- 菜单流程：`[3]消息渠道 -> [2]Discord`

### WhatsApp
- 通过 `openclaw channels login --channel whatsapp` 扫码登录
- 菜单流程：`[3]消息渠道 -> [3]WhatsApp`

### Slack
- 必填：`xoxb Bot Token`、`xapp App Token`
- 菜单流程：`[3]消息渠道 -> [4]Slack`

### 飞书（官方）
- 插件固定官方包：`@openclaw/feishu`
- 必填：`App ID`、`App Secret`
- 配置写入：`channels.feishu.accounts.main.*`
- 菜单流程：`[3]消息渠道 -> [5]飞书`

### Signal / Teams / Mattermost / Google Chat / Matrix / LINE / Nextcloud Talk
- 统一路径：`[3]消息渠道 -> 对应官方项`
- 由 `openclaw channels add --channel <name>` 引导完成

## 4. 社区渠道配置要点

### 微信（LangBot WeChatPad）
- 插件：`openclaw-wechat-channel`
- 必填：
  - `proxyUrl`
  - `apiKey`
  - 回调参数 `webhookHost/webhookPort/webhookPath`
- 菜单路径：`[3]消息渠道 -> [15]微信（社区）`

### QQ（社区）
- 插件：`@sliverp/qqbot`
- 必填：`AppID`、`AppSecret`
- 推荐配置：`allowFrom` 白名单
- 菜单路径：`[3]消息渠道 -> [17]QQ（社区）`

### 企业微信 WeCom（官方插件）
- 插件：`@wecom/wecom-openclaw-plugin`
- 当前安装器仅保留机器人模式（Webhook）
- 关键配置结构：
  - `channels.wecom.mode=bot`
  - `channels.wecom.defaultAccount=bot`
  - `channels.wecom.accounts.bot.*`
- 机器人模式必填：
  - `token`
  - `encodingAESKey`
  - `receiveId`
  - `webhookPath`（默认 `/wecom/bot`）
- 菜单路径：`[4]非官方消息渠道配置 -> [3]企业微信（WeCom，官方）`

### 非官方高级模型（Claude/GPT）与自动路由
- 高级模型入口：`[4]非官方消息渠道配置 -> [8]非官方渠道高级模型（Claude/GPT）`
- 自动路由入口：`[4]非官方消息渠道配置 -> [9]模型自动切换路由`
- 推荐策略：`auto`（复杂任务走高级模型，失败自动回退硅基流动兜底）

## 5. 常用排障命令

```bash
openclaw doctor --fix
openclaw plugins update --all
openclaw channels list
openclaw gateway restart
openclaw status
```

## 6. 版本策略建议

1. 生产环境优先使用官方渠道插件。  
2. 社区插件务必固定版本（`--pin`），避免 `latest` 漂移。  
3. 每次升级 OpenClaw 后，执行 `doctor -> plugins update --all -> 渠道探针`。
