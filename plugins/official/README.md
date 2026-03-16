# 官方插件本地包（离线优先）

本目录用于给 `install.sh` / `config-menu.sh` 提供“仓库内本地插件包”安装源，避免配置阶段强依赖远端下载。

## 目录结构

- `archives/*.tgz`：官方插件 npm 归档包（优先使用）
- `feishu/`：飞书插件源码快照（目录安装兜底）

## 当前已打包（可本地安装）

- `@openclaw/feishu`
- `@wecom/wecom-openclaw-plugin`
- `@openclaw-china/wecom`
- `@openclaw-china/channels`
- `@marshulll/openclaw-wecom`
- `@tencent-connect/openclaw-qqbot`
- `@sliverp/qqbot`
- `openclaw-channel-dingtalk`
- `@openclaw/msteams`
- `@openclaw/mattermost`
- `@openclaw/matrix`
- `@openclaw/line`
- `@openclaw/nextcloud-talk`
- `@openclaw/twitch`
- `@openclaw/zalo`
- `@openclaw/zalouser`
- `@openclaw/nostr`
- `@openclaw/tlon`
- `@openclaw/synology-chat`
- `@openclaw/bluebubbles`

## 更新方式

在仓库根目录执行：

```bash
mkdir -p plugins/official/archives
for p in \
  @openclaw/feishu @wecom/wecom-openclaw-plugin @openclaw-china/wecom \
  @openclaw-china/channels @marshulll/openclaw-wecom @tencent-connect/openclaw-qqbot \
  @sliverp/qqbot openclaw-channel-dingtalk @openclaw/msteams @openclaw/mattermost \
  @openclaw/matrix @openclaw/line @openclaw/nextcloud-talk @openclaw/twitch \
  @openclaw/zalo @openclaw/zalouser @openclaw/nostr @openclaw/tlon \
  @openclaw/synology-chat @openclaw/bluebubbles; do
  npm pack "$p" --silent
done
mv -f ./*.tgz plugins/official/archives/
```

说明：`signal/googlechat/irc` 等包如 npm 暂不可得，脚本会提示缺包并跳过；若确需远端拉取，可设置：

```bash
export OPENCLAW_ALLOW_REMOTE_PLUGIN_FALLBACK=1
```
