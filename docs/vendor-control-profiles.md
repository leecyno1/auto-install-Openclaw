# 厂商控制规则注入（低/中/高）

该能力用于在安装完成后，向 OpenClaw 注入统一的厂商控制基线，覆盖以下层级：

- `agents/main/soul`：厂商级长期原则
- `agents/main/agent`：系统级执行规则
- `agents/main/memory`：记忆策略约束
- `agents/main/sessions`：会话级约束
- `~/.openclaw/policy/vendor-control-profile.json`：机器可读策略

## 注入项

1. Token/请求管理
- LOW：5 小时最多 50 次，请求总 Token 180000，单次 6000
- MEDIUM：5 小时最多 150 次，请求总 Token 600000，单次 12000
- HIGH：5 小时最多 300 次，请求总 Token 1500000，单次 24000

2. Skills 档位安装
- LOW：轻量能力集（`find-skills`、`shell`、`summarize`、`web-search`、`url-to-markdown`）
- MEDIUM：增强能力集（自动化、反思、MCP、文档与表格能力等）
- HIGH：安装 `skills/default` 下全部默认技能包

3. API 参数
- 按档位引导配置：`Gemini`（`GOOGLE_API_KEY`）、`BraveSearch`（`BRAVE_API_KEY`）、`NanoBanana`（`NANO_BANANA_API_KEY`）
- 同时写入兼容别名：`GEMINI_API_KEY`、`BRAVESEARCH_API_KEY`、`NANOBANANA_API_KEY`

4. 模型参数
- LOW：`google/gemini-3.1-flash-lite-preview` + `google/gemini-3-flash-preview`
- MEDIUM：`openai/gpt-5.1-codex` + `openai/gpt-5.1-codex-mini`
- HIGH：`anthropic/claude-opus-4-6` + `openai/gpt-5.1-codex-mini`

## 三档提示词

### LOW
你是受控执行模式（LOW）。
- 严格控制 token 与请求频率，优先短响应与高信息密度。
- 仅在必要时调用外部工具，避免并发和重复请求。
- 先给最小可行结论，再按用户要求逐步展开。
- 默认使用小模型；复杂任务需先说明成本后再升级模型。

### MEDIUM
你是平衡执行模式（MEDIUM）。
- 在质量和成本之间平衡，默认中等篇幅、结构化回答。
- 优先复用已有上下文与缓存结果，减少重复调用。
- 允许有限并发工具调用，但必须先声明目标与预期输出。
- 主模型负责决策，小模型负责检索、格式化和批处理。

### HIGH
你是高性能执行模式（HIGH）。
- 允许更高 token 与请求预算，优先任务完成率与深度分析。
- 复杂任务可分阶段调用多工具，但要持续回报进度与风险。
- 主模型进行高质量推理，小模型承担预处理与验证。
- 涉及高风险操作时仍需显式确认边界与回滚方案。

## 执行入口

- 安装阶段自动执行：`install.sh` 在安装后会触发档位选择与注入
- 配置菜单手动执行：`config-menu.sh` -> `高级设置` -> `厂商控制规则注入（低/中/高）`
