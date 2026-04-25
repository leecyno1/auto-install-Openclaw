# auto-install-openclaw

<p align="center">
  <strong>OpenClaw 一键部署 - 官方优先 + 自定义可选 + 低内存优化 + 批量部署</strong><br />
  把 OpenClaw 官方安装、自定义增强层、配置管理、像素小屋工作台收敛到一个仓库。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-v2.0.0-1f6feb?style=for-the-badge" alt="Version" />
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-0f766e?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/node-22.14%2B-15803d?style=for-the-badge" alt="Node" />
  <img src="https://img.shields.io/badge/代码量-1763行-7c3aed?style=for-the-badge" alt="Lines of Code" />
  <img src="https://img.shields.io/badge/压缩率-91%25-b91c1c?style=for-the-badge" alt="Compression" />
</p>

> [!IMPORTANT]
> v2.0.0 重构版：**官方优先**，以 `npm install -g openclaw@latest` + `openclaw onboard` 为核心安装流程，自定义配置（角色档案、Token 档位、技能包）全部作为**可选增强层**。代码量从 20,086 行缩减到 1,763 行（-91%）。

---

## 快速开始

### 一键安装（交互式）

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash
```

### 全自动安装（批量部署）

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all
```

### 仅安装官方版本

```bash
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --no-custom
```

---

## 架构设计

```
Phase 1: 环境准备          Phase 2: 官方安装          Phase 3: 自定义增强层（可选）
├── OS 检测                ├── npm install -g         ├── A. 工作档案（Persona）
├── Node.js 检查/安装      │   openclaw@latest        ├── B. Token 档位策略
├── 系统依赖安装           ├── openclaw onboard       ├── C. 技能包同步
└── 低内存 Swap 优化       └── openclaw gateway       └── D. Python 技能依赖
```

### 核心原则

| 原则 | 说明 |
|------|------|
| **官方优先** | 核心安装直接使用 `npm install` + `openclaw onboard` |
| **自定义可选** | 角色、档位、技能包全部可选，可跳过 |
| **共享库** | 颜色、Persona、技能定义提取为 `scripts/lib/openclaw-custom.sh` |
| **低内存优化** | 云端服务器内存不足时自动创建 Swap，防止 OOM |
| **批量部署** | `--auto-confirm-all` 支持上百台服务器无人值守安装 |

---

## 安装选项

### 核心选项

| 选项 | 说明 | 默认 |
|------|------|------|
| `--auto-confirm-all` | 全自动模式（批量部署专用） | 关闭 |
| `--no-custom` | 跳过自定义层，仅安装官方版本 | 关闭 |
| `--no-onboard` | 跳过官方 onboarding | 关闭 |
| `--version <ver>` | 指定 OpenClaw 版本 | latest |
| `--dry-run` | 仅打印计划，不执行 | 关闭 |

### 自定义层选项

| 选项 | 说明 | 默认 |
|------|------|------|
| `--persona <role>` | 工作档案 | druid |
| `--rule-profile <level>` | Token 档位 | medium |
| `--assistant-name <name>` | 机器人名称 | 龙虾小助理 |
| `--user-goal <text>` | 用户主要目标 | - |

### 低内存选项

| 选项 | 说明 | 默认 |
|------|------|------|
| `--no-swap` | 不自动创建 Swap | 关闭 |
| `--swap-size <MB>` | 手动指定 Swap 大小 | 自动计算 |
| `--swap-file <path>` | Swap 文件路径 | /swapfile.openclaw |

---

## 批量部署示例

```bash
# 100 台云服务器全自动安装
for host in server-{1..100}; do
  ssh $host "curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all" &
done
wait

# 指定工作档案和档位
curl -fsSL <url>/install.sh | bash -s -- \
  --auto \
  --persona warrior \
  --rule-profile high

# 仅安装官方，自定义配置后续通过 openclaw-setup 完成
curl -fsSL <url>/install.sh | bash -s -- --auto --no-custom
```

---

## 统一入口

安装后可使用 `openclaw-setup` 管理所有功能：

```bash
openclaw-setup install                    # 安装
openclaw-setup install --auto             # 全自动
openclaw-setup config                     # 配置菜单
openclaw-setup repair                     # 修复配置
openclaw-setup doctor --fix               # 健康检查并修复
openclaw-setup workbench start            # 启动工作台
openclaw-setup skills medium              # 同步技能包
openclaw-setup status                     # 查看服务状态
openclaw-setup backup                     # 备份配置
openclaw-setup persona                    # 设置工作档案
```

---

## 配置中心

运行 `openclaw-setup config` 或 `bash ~/.openclaw/config-menu.sh` 打开配置菜单：

```
  ╔═══════════════════════════════════════════╗
  ║   🦞 OpenClaw 配置中心                     ║
  ╚═══════════════════════════════════════════╝

  [1] 模型配置      → 运行官方 onboard 向导
  [2] 插件管理      → 安装/卸载消息渠道插件
  [3] 技能管理      → 同步本地技能包
  [4] 工作档案      → 初始化 AI 助手角色
  [5] Token 档位    → 设置请求限与安全规则
  [6] 服务管理      → Gateway 控制
  [7] 配置修复      → 清理错误配置
  [8] 像素小屋工作台 → 可视化管理界面
  [0] 退出
```

---

## 工作档案（7 选 1）

| 编号 | 角色 | 适用场景 |
|------|------|---------|
| 1 | 🦞 综合助理（通用） | 通用总管，适合绝大多数用户 |
| 2 | 🗡️ 分析研究（投资） | 数据深挖、价值发现、投资机会 |
| 3 | 🧙 学术研究 | 学术科研、论文写作、知识沉淀 |
| 4 | 🪄 团队管理 | 团队管理、流程制度、组织协同 |
| 5 | ⚔️ 工程开发 | 编程交付、测试排障、工程上线 |
| 6 | 🛡️ 市场增长 | 市场增长、SEO投放、渠道运营 |
| 7 | 🏹 设计创作 | 前端/UI/视觉/平面/工业/建筑概念 |

---

## Token 档位

| 档位 | 请求预算 | 总 Token | 单次 Token | 适用场景 |
|------|---------|---------|-----------|---------|
| low | 5h / 100 次 | 60 万 | 2.4 万 | 轻量部署 |
| medium | 5h / 300 次 | 240 万 | 4.8 万 | 默认推荐 |
| high | 不限 | 600 万 | 8 万 | 重度使用 |

---

## 仓库结构

```
.
├── install.sh                          # 主安装脚本（759 行）
├── config-menu.sh                      # 配置中心菜单（437 行）
├── openclaw-setup.sh                   # 统一入口（294 行）
├── scripts/
│   ├── lib/
│   │   └── openclaw-custom.sh          # 共享库（273 行）
│   ├── lobster-world.sh                # 像素小屋工作台管理
│   ├── health-server.sh                # 健康检查服务
│   ├── refresh_default_skills.py       # 技能缓存重建
│   ├── gateway-quota-enforcer.py       # 配额强制执行
│   └── ...
├── skills/default/                     # 本地技能包
├── docs/                               # 配套文档
└── subprojects/
    └── lobster-sanctum-ui/             # 像素小屋工作台源码
```

---

## 常用命令

### Gateway

```bash
source ~/.openclaw/env && openclaw gateway start
source ~/.openclaw/env && openclaw gateway status
source ~/.openclaw/env && openclaw doctor
```

### 像素小屋工作台

```bash
~/.openclaw/lobster-world.sh start     # 启动（端口 19000）
~/.openclaw/lobster-world.sh status    # 查看状态
~/.openclaw/lobster-world.sh stop      # 停止
```

---

## 适合谁

- **批量部署**：需要在数十/上百台云服务器上快速部署 OpenClaw
- **低内存环境**：2GB/4GB 内存的云服务器，自动创建 Swap 防 OOM
- **官方优先**：希望以官方安装为核心，自定义配置作为可选补充
- **可视化管理**：需要通过 Web 界面管理 AI 助手状态
- **运维友好**：需要统一的安装、配置、修复、备份入口

---

## v2.0.0 重构说明

| 指标 | v1.x | v2.0.0 |
|------|------|--------|
| install.sh | 6,672 行 | 759 行 (-89%) |
| config-menu.sh | 13,097 行 | 437 行 (-97%) |
| 总计 | 20,086 行 | 1,763 行 (-91%) |
| 重复定义 | 15+ 对 | 0（共享库） |
| 安装核心 | 自定义脚本包裹 | 直接使用 npm + openclaw onboard |
| 自定义层 | 强制捆绑 | 全部可选 |

---

## License

MIT
