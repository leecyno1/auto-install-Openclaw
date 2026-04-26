# 🐵 大圣之怒 · auto-install-openclaw

<p align="center">
  <strong>OpenClaw / Hermes 一键部署 — 官方优先 + 自定义可选 + 批量部署 + 网站集成</strong><br />
  龙虾与 Hermes 两种智能体按需选装，共享配置体系，统一管理入口。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-v2.0.0-1f6feb?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-0f766e?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/智能体-龙虾%20%7C%20Hermes-7c3aed?style=for-the-badge" alt="Agents" />
</p>

---

## 快速开始

### 安装龙虾（OpenClaw）

```bash
# 克隆仓库
git clone https://github.com/leecyno1/auto-install-openclaw.git
cd auto-install-openclaw

# 交互式安装
bash openclaw-setup.sh install

# 全自动安装
bash openclaw-setup.sh install --auto

# 一键配置模型+密钥
bash openclaw-setup.sh install --auto --model gpt-4o --api-key sk-xxx

# 仅安装官方版本（不装自定义层）
bash openclaw-setup.sh install --no-custom

# curl|bash 一键安装
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash
```

### 安装 Hermes

```bash
# 独立安装 Hermes
bash openclaw-setup.sh hermes install

# 安装后运行配置向导
bash openclaw-setup.sh hermes setup

# 指定模型
bash openclaw-setup.sh hermes model MiniMax-M2.7-highspeed
```

> **注意：** 龙虾和 Hermes 一般只装一个，按需选择。

---

## 安装选项

### 龙虾安装选项

| 选项 | 说明 | 默认 |
|------|------|------|
| `--auto-confirm-all` | 全自动模式（批量部署专用） | 关闭 |
| `--no-custom` | 跳过自定义层，仅安装官方版本 | 关闭 |
| `--no-onboard` | 跳过官方 onboarding | 关闭 |
| `--version <ver>` | 指定 OpenClaw 版本 | latest |
| `--gateway-bind <mode>` | 绑定模式: loopback/lan/tailnet | loopback |
| `--gateway-port <port>` | Gateway 端口 | 13145 |
| `--persona <role>` | 工作档案: druid/assassin/mage/summoner/warrior/paladin/designer | druid |
| `--rule-profile <level>` | Token 档位: low/medium/high/none | medium |
| `--model <name>` | 指定默认模型 | - |
| `--api-key <key>` | 设置 API 密钥 | - |
| `--api-url <url>` | 设置 API Base URL | - |
| `--api-provider <name>` | 设置 API Provider | - |
| `--dry-run` | 仅打印计划，不执行 | 关闭 |

### 批量部署示例

```bash
# 100 台服务器全自动部署
for host in server-{1..100}; do
  ssh $host "curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all" &
done
wait

# 指定模型和密钥
bash install.sh --auto --model gpt-4o --api-key sk-xxx --api-provider openai

# 指定工作档案和档位
bash install.sh --auto --persona warrior --rule-profile high
```

---

## 统一入口命令

安装后使用 `openclaw-setup.sh` 管理所有功能：

### 安装与配置

```bash
bash openclaw-setup.sh install [选项]     # 安装龙虾
bash openclaw-setup.sh config             # 打开配置中心菜单
bash openclaw-setup.sh repair             # 修复历史错误配置
bash openclaw-setup.sh doctor --fix       # 健康检查并修复
bash openclaw-setup.sh doctor --status    # 仅显示状态
```

### 服务管理

```bash
bash openclaw-setup.sh status             # 查看所有服务状态
bash openclaw-setup.sh gateway start      # 启动 Gateway
bash openclaw-setup.sh gateway stop       # 停止 Gateway
bash openclaw-setup.sh gateway restart    # 重启 Gateway
bash openclaw-setup.sh workbench start    # 启动像素小屋工作台
bash openclaw-setup.sh workbench status   # 查看工作台状态
```

### 网站集成（SSH 隧道）

```bash
bash openclaw-setup.sh tunnel start       # 启动 SSH 隧道到网站服务器
bash openclaw-setup.sh tunnel stop        # 停止 SSH 隧道
bash openclaw-setup.sh tunnel status      # 查看隧道状态
bash openclaw-setup.sh website            # 配置网站集成（交互菜单）
```

### Hermes 代理

```bash
bash openclaw-setup.sh hermes install     # 安装 Hermes
bash openclaw-setup.sh hermes setup       # 运行配置向导
bash openclaw-setup.sh hermes model       # 配置/查看模型
bash openclaw-setup.sh hermes start       # 启动 Hermes Gateway
bash openclaw-setup.sh hermes stop        # 停止 Hermes Gateway
bash openclaw-setup.sh hermes status      # 查看 Hermes 状态
```

### 路由与档位

```bash
bash openclaw-setup.sh routing low        # 设置基础档
bash openclaw-setup.sh routing medium     # 设置扩展档
bash openclaw-setup.sh routing high       # 设置超级档
bash openclaw-setup.sh routing status     # 查看当前路由状态
bash openclaw-setup.sh routing set        # 交互选择档位
```

### 工具

```bash
bash openclaw-setup.sh persona            # 设置/切换工作档案
bash openclaw-setup.sh skills low         # 同步基础档技能包
bash openclaw-setup.sh skills medium      # 同步扩展档技能包
bash openclaw-setup.sh skills high        # 同步超级档技能包
bash openclaw-setup.sh backup             # 备份配置和数据
```

### 短别名

| 命令 | 别名 | 命令 | 别名 |
|------|------|------|------|
| install | i | gateway | gw / g |
| config | c | skills | sk |
| repair | r / fix | tunnel | t |
| doctor | d | hermes | h |
| workbench | wb / w | routing | rt |
| status | s | backup | b |

---

## 配置中心

运行 `bash openclaw-setup.sh config` 打开配置菜单：

```
  ╔═══════════════════════════════════════════╗
  ║   🐵 大圣之怒 · 配置中心                    ║
  ╚═══════════════════════════════════════════╝

  [1] 模型配置          [6] 服务管理
  [2] 插件管理          [7] 配置修复
  [3] 技能管理          [8] 像素小屋工作台
  [4] 工作档案          [9] 网站集成
  [5] Token 档位        [A] Hermes 代理
                        [B] 路由与档位
  [0] 退出
```

---

## 工作档案（7 选 1）

| 编号 | 角色 | 适用场景 |
|------|------|---------|
| 1 | 🦞 综合助理（Druid） | 通用总管，适合绝大多数用户 |
| 2 | 🗡️ 分析研究（Assassin） | 数据深挖、价值发现、投资机会 |
| 3 | 🧙 学术研究（Mage） | 学术科研、论文写作、知识沉淀 |
| 4 | 🪄 团队管理（Summoner） | 团队管理、流程制度、组织协同 |
| 5 | ⚔️ 工程开发（Warrior） | 编程交付、测试排障、工程上线 |
| 6 | 🛡️ 市场增长（Paladin） | 市场增长、SEO投放、渠道运营 |
| 7 | 🏹 设计创作（Designer） | 前端/UI/视觉/平面/工业设计 |

---

## Token 档位

| 档位 | 请求预算 | 总 Token | 单次 Token | 适用场景 |
|------|---------|---------|-----------|---------|
| low | 5h / 100 次 | 60 万 | 2.4 万 | 轻量部署 |
| medium | 5h / 300 次 | 240 万 | 4.8 万 | 默认推荐 |
| high | 不限 | 600 万 | 8 万 | 重度使用 |
| none | 不限 | 不限 | 不限 | 无限制 |

---

## 架构设计

```
龙虾安装流程：
Phase 1: 环境准备          Phase 2: 官方安装          Phase 3: 自定义增强层（可选）
├── Node.js 检查            ├── npm install -g         ├── 工作档案（Persona）
├── OpenClaw 安装           │   openclaw@latest        ├── Token 档位策略
└── Swap 优化               └── openclaw onboard       ├── 技能包同步
                                                           └── Python 技能依赖

Hermes 安装流程：
├── Python3 检查            ├── pip install            ├── 配置向导
├── 版本验证                │   hermes-agent            └── 模型设置
└── PATH 配置               └── hermes setup

共享层（两者通用）：
├── scripts/lib/openclaw-custom.sh    ← 唯一数据源
├── 网站集成 + SSH 隧道               ← 60.205.58.39
├── 路由与档位管理
└── 配置中心 TUI
```

### 核心原则

| 原则 | 说明 |
|------|------|
| **官方优先** | 龙虾用 `npm install`，Hermes 用 `pip install`，都是官方方法 |
| **按需选装** | 龙虾和 Hermes 只装一个，不捆绑 |
| **共享库** | 所有配置函数提取为 `scripts/lib/openclaw-custom.sh` 唯一数据源 |
| **嵌入式库** | install.sh 尾部嵌入共享库，支持 curl\|bash 模式 |
| **3 层回退** | 本地 source → sed 提取嵌入库 → GitHub 远程下载 |
| **批量部署** | `--auto` + `--model` + `--api-key` 支持无人值守 |

---

## 仓库结构

```
.
├── install.sh                          # 主安装脚本（含嵌入库）
├── openclaw-setup.sh                   # 统一入口工具
├── config-menu.sh                      # 配置中心 TUI 菜单
├── scripts/
│   ├── lib/
│   │   └── openclaw-custom.sh          # 共享库（唯一数据源）
│   ├── lobster-world.sh                # 像素小屋工作台
│   ├── health-server.sh                # 健康检查服务
│   └── ...
├── skills/default/                     # 本地技能包
├── docs/                               # 配套文档
└── subprojects/
    └── lobster-sanctum-ui/             # 像素小屋工作台源码
```

---

## 网站集成

通过 SSH 远程端口转发，让网站服务器访问本地 Dashboard：

```bash
# 启动隧道（让 60.205.58.39 可通过 localhost:13145 访问本地 Dashboard）
bash openclaw-setup.sh tunnel start

# 查看状态
bash openclaw-setup.sh tunnel status

# 写入网站环境变量
bash openclaw-setup.sh website    # 交互菜单，选择 [1]
```

| 配置项 | 默认值 | 环境变量 |
|--------|--------|---------|
| 服务器 IP | 60.205.58.39 | `OPENCLAW_WEBSITE_SERVER_IP` |
| 服务器用户 | root | `OPENCLAW_WEBSITE_SERVER_USER` |
| 域名 | monkeykingfury.com | `OPENCLAW_WEBSITE_DOMAIN` |
| 网站端口 | 8787 | `OPENCLAW_WEBSITE_PORT` |
| Dashboard 端口 | 13145 | `OPENCLAW_DASHBOARD_PORT` |

---

## License

MIT
