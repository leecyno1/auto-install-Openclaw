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

默认国内源走 Gitee，当前稳定入口直接使用 `main`。

```bash
# OpenClaw
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-openclaw.sh | bash

# Hermes
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-hermes.sh | bash

# 双引擎
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --engine both
```

全自动批量部署示例：

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-openclaw.sh | bash -s -- \
  --auto-confirm-all \
  --provider minimax \
  --model MiniMax-M2.7-highspeed \
  --api-key "$MINIMAX_API_KEY" \
  --base-url https://api.minimaxi.com/anthropic \
  --rule-profile medium \
  --install-skills standard \
  --install-pixel-house \
  --enable-advanced-routing \
  --extra-model "id=gpt-5-5,name=GPT-5.5,base_url=https://yfy.zhouyang168.top/v1,api_key=$GPT55_API_KEY,model=gpt-5.5,api_type=openai-completions,image_tool=responses-image-generation,image_model=gpt-image-2"
```

兼容总入口：

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --engine openclaw
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --engine hermes
curl -fsSL https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh | bash
curl -fsSL https://mirror.ghproxy.com/https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh | bash
```

无人值守快捷命令：

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-openclaw.sh | bash -s -- --auto-confirm-all
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install-hermes.sh | bash -s -- --auto-confirm-all
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all --engine openclaw
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all --engine hermes
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all --engine both
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
| 标准包 / standard | 一键安装默认包，随 boutique `catalog/standard-bundle.json` 更新 | `openclaw-setup config skills --tier standard` |
| 低档 / low | 首次安装和轻量生产，安装后在配置中心显式选择 | `openclaw-setup config skills --tier low` 或 `--tier basic` |
| 中档 / medium | 标准生产和常用扩展，安装后在配置中心显式选择 | `openclaw-setup config skills --tier medium` 或 `--tier extended` |
| 高档 / high | 完整专家包、金融交易研究和创作套件，安装后在配置中心显式选择 | `openclaw-setup config skills --tier high` 或 `--tier super` |

## Skills 索引

本仓库不再保存完整 skills 表格、GUIDE 文档或生成后的本地 manifest，避免安装器仓库和 boutique 仓库双写漂移。完整清单、三档说明、使用手册和原仓库链接以 boutique 仓库为准：

| 内容 | 入口 |
| --- | --- |
| 全部技能清单 | [boutique README](https://github.com/leecyno1/boutique-openclaw-skills) |
| 完整使用手册 | [SKILL_MANUALS.md](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/SKILL_MANUALS.md) |
| 低档说明 | [low.md](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/tiers/low.md) |
| 中档说明 | [medium.md](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/tiers/medium.md) |
| 高档说明 | [high.md](https://github.com/leecyno1/boutique-openclaw-skills/blob/main/docs/tiers/high.md) |


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
openclaw-setup config skills --tier standard
openclaw-setup config skills --tier medium
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
