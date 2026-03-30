# OpenClaw 配置分层规范 V1

> 目的：在不改动 OpenClaw 核心执行链路的前提下，将安装与配置体验升级为“职业 + 技能树 + 装备 + 等级”的分层配置体系。
> 原则：体验层游戏化，执行层工程化；所有配置仍落地到 `~/.openclaw/` 与 `openclaw config`。

---

## 1. 设计目标

1. 提升可理解性：把复杂配置翻译为用户熟悉的游戏概念。
2. 提升可操作性：配置菜单按角色成长路径组织，而不是按技术术语堆叠。
3. 提升粘性：通过等级、成就、悬赏任务增强长期使用动力。
4. 保持稳定性：不破坏现有脚本、命令与配置兼容性。

---

## 2. 核心映射模型

| 游戏概念 | OpenClaw 真实能力 | 说明 |
|---|---|---|
| 工作档案（Profile） | 工作档案（identity.role + persona files） | 7 选 1，定义默认风格与能力偏好 |
| 技能分层（Skills Tier） | `skills/default/*` + 档位安装策略 | 基础/进阶/终极三层解锁 |
| 工具配置（Tools） | 模型、API、工具开关、安全策略 | 模型=主副武器，安全=护甲，渠道=护符 |
| 运行状态（Stats） | 服务状态、token、任务统计、成功率 | 实时显示角色战斗状态 |
| 使用统计（XP/Level） | 使用时长+Token+任务完成+成功数 | 推动角色成长与功能解锁 |

---

## 3. 七类工作档案定义（与当前系统对齐）

1. 综合助理（通用）：通用助手，平衡调度与执行。
2. 分析研究（投资）：数据采集、价值挖掘、投研分析。
3. 学术研究：论文科研、知识整理、结构化学习。
4. 团队管理：团队管理、流程治理、组织协同。
5. 工程开发：工程开发、测试排障、稳定性保障。
6. 市场增长：增长运营、SEO、内容分发与转化。
7. 设计创作：前端/UI/视觉/多媒体创作与设计交付。

> 职业数据来源：`identity.role.*` + `docs/persona-roles.md` + `~/.openclaw/agents/main/persona/*`

---

## 4. 技能分层设计

### 4.1 分层

1. 基础技能集（Level 1+）
- 对应当前 `PROFILE_BASIC_SKILLS`

2. 进阶技能集（Level 8+）
- 对应当前 `PROFILE_EXTENDED_SKILLS`

3. 高级技能集（Level 15+）
- 对应当前 `PROFILE_SUPER_SKILLS=__ALL_DEFAULT__`

### 4.2 解锁规则（V1）

- 默认安装档位可直接装配对应技能层。
- 若用户等级不足，仅隐藏“推荐启用”，不阻断手动安装（避免业务卡死）。
- 职业只影响推荐权重，不限制技能安装自由。

---

## 5. 装备系统设计（Tools 映射）

| 装备位 | 配置映射 | 示例 |
|---|---|---|
| 主武器 | 主模型配置 | GPT/Claude/Gemini 主模型 |
| 副武器 | 兜底模型配置 | SiliconFlow Qwen 兜底 |
| 头盔 | 记忆能力 | `boot-md.enabled`, `session-memory.enabled` |
| 护甲 | 安全策略 | `security.*`, token规划规则 |
| 护符 | 渠道与自动化 | telegram/feishu + cron/proactive |
| 戒指1 | 搜索能力 | web-search/tavily/minimax-web-search |
| 戒指2 | 多媒体能力 | gemini-image/nano-banana/video tools |

---

## 6. 角色状态系统（Stats）

## 6.1 核心指标

1. 使用时长（hours_played）
2. Token 消耗（tokens_used）
3. 完成任务数（tasks_completed）
4. 成功任务数（tasks_success）
5. 成功率（success_rate）
6. 服务健康（gateway_health）

## 6.2 等级计算（V1）

- 经验公式：

```text
XP = hours_played*8
   + log2(tokens_used/1000 + 1)*35
   + tasks_completed*10
   + tasks_success*22
   + success_bonus
```

- 成功率奖励：
  - success_rate >= 90%: +120
  - 75% <= success_rate < 90%: +60
  - 其余: +0

- 等级阈值：

```text
XP_required(level) = 120 * level^1.45
```

> 说明：防止单靠 token 冲级，鼓励高质量完成任务。

---

## 7. 菜单重构（脚本 UI）

> 仅改“显示层文案 + 分组”，底层命令逻辑不变。

1. 系统状态（原 系统状态）
2. 身份与个性（原 身份与个性配置）
3. Skills 管理（原 Skills 管理）
4. 模型与工具配置（原 AI模型配置 + API参数配置）
5. 消息渠道插件（原 官方消息渠道插件）
6. 安全与 token 规则（原 安全设置 + token规则注入）
7. 快速测试（原 快速测试）
8. 高级设置（原 高级设置）
9. 当前配置（原 查看当前配置）
10. 服务管理（原 服务管理）
11. 配置修复与迁移（原 `--repair-config` 能力菜单化）

---

## 8. 数据文件规划（新增）

### 8.1 持久化文件

- `~/.openclaw/profile/game-profile.json`
- `~/.openclaw/profile/game-progress.json`
- `~/.openclaw/profile/game-achievements.json`

### 8.2 数据结构（示例）

```json
{
  "version": "v1",
  "hero": {
    "classId": "warrior",
    "name": "龙虾小助理",
    "level": 12,
    "xp": 4860
  },
  "stats": {
    "hoursPlayed": 84.5,
    "tokensUsed": 1823400,
    "tasksCompleted": 263,
    "tasksSuccess": 231,
    "successRate": 0.878
  },
  "skillTree": {
    "tier": "extended",
    "equipped": ["github", "shell", "mcp-builder"]
  },
  "gear": {
    "mainModel": "gpt-5.1-codex",
    "fallbackModel": "Qwen/Qwen3-8B",
    "memory": { "bootMd": true, "sessionMemory": true },
    "security": { "sandboxMode": false }
  }
}
```

---

## 9. 脚本优化清单（进入三阶段前先做）

1. 配置菜单重命名为游戏化文案（保持原编号兼容）。
2. 新增“系统状态”聚合页：
- Gateway状态、Token预算、任务成功率、等级与经验条。
3. 新增“Skills 分层视图”：
- 基础/进阶/终极三栏显示已安装、可安装、缺失。
4. 新增“装备视图”：
- 模型、API、工具能力以装备槽形式显示。
5. 新增“成长统计刷新”命令：
- 计算 XP/Level 并落盘 `game-progress.json`。

---

## 10. 三阶段落地路线（正式启动前的对齐版本）

1. 第一阶段：脚本体验层改造
- 完成菜单重命名、面板展示、等级计算与本地 JSON 落盘。

2. 第二阶段：映射封装层
- 抽象统一配置映射（角色/技能树/装备 -> openclaw config 与文件写入）。

3. 第三阶段：API/Web 层
- 将第二阶段映射能力封装成 API，提供独立网页配置台。

---

## 11. 边界与兼容

1. 不替代 `openclaw onboard`：官方模型流程保持优先。
2. 不破坏 `--auto-confirm-all`、`--repair-config`、`openclaw doctor --fix`。
3. 不强制清会话：所有“重置类”操作默认保留记忆与对话，二次确认后才删除。
4. 所有游戏化字段均可回退，不影响原始配置可读性。
