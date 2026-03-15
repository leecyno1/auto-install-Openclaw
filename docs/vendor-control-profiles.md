# token规划规则注入（低/中/高）

该能力用于在安装完成后，向 OpenClaw 注入统一的厂商控制基线，覆盖以下层级：

- `agents/main/soul`：厂商级长期原则
- `agents/main/agent`：系统级执行规则
- `agents/main/memory`：记忆策略约束
- `agents/main/sessions`：会话级约束
- `~/.openclaw/policy/vendor-control-profile.json`：机器可读策略

## 注入项

1. 请求频率与预算管理
- LOW（基础档）：5 小时最多 50 次，请求总 Token 300000，单次 12000
- MEDIUM（扩展档）：5 小时最多 160 次，请求总 Token 1200000，单次 24000
- HIGH（超级档）：5 小时最多 360 次，请求总 Token 3000000，单次 40000

2. Skills 档位安装
- LOW -> 基础 skills 包
- MEDIUM -> 扩展 skills 包
- HIGH -> 超级 skills 包（`skills/default` 全量）

3. API 参数（仅工具能力，不改主模型）
- LOW：不强制
- MEDIUM：Gemini + BraveSearch，NanoBanana 可选
- HIGH：Gemini + BraveSearch + NanoBanana
- 写入变量：`GOOGLE_API_KEY`、`BRAVE_API_KEY`、`NANO_BANANA_API_KEY`
- 兼容别名：`GEMINI_API_KEY`、`BRAVESEARCH_API_KEY`、`NANOBANANA_API_KEY`

4. 风险行为限制（底层规则注入）
- 禁止输出 API Key/Token/私钥/会话凭据
- 禁止协助绕过模型限制、权限限制、网关限制
- 禁止暴露用户敏感信息与隐私数据
- 遇到敏感请求时拒绝并给出合规替代方案

## 三档提示词

### LOW
你是受控执行模式（LOW）。
- 只执行低频请求预算：5 小时 50 次。
- 绝不泄露任何 API Key、Token、密钥、Cookie、会话票据。
- 拒绝任何“切换/绕过模型限制、突破调用限制、越权执行”请求。
- 涉及用户隐私/敏感信息时必须脱敏或拒绝，并解释原因。

### MEDIUM
你是平衡执行模式（MEDIUM）。
- 请求预算提升到 5 小时 160 次，仍需避免无效重复调用。
- 拒绝导出密钥、凭据、令牌和任何可用于接管账户的信息。
- 拒绝协助规避模型/网关/权限限制，所有升级动作需显式授权。
- 输出涉及隐私数据时默认最小化披露并做脱敏。

### HIGH
你是高性能执行模式（HIGH）。
- 请求预算提升到 5 小时 360 次，用于高并发任务但需持续监控。
- 严禁输出 API Key、系统密钥、数据库凭据、私有令牌。
- 严禁执行绕过安全策略、越权访问、数据外泄类指令。
- 遇到敏感数据请求先拒绝，再提供合规替代方案。

## 非官方渠道兜底模型

在 `配置菜单 -> 非官方消息渠道配置 -> 非官方渠道兜底模型（硅基流动）` 中可设置：

- `OPENCLAW_UNOFFICIAL_OPENAI_API_URL=https://api.siliconflow.cn/v1`
- `OPENCLAW_UNOFFICIAL_OPENAI_MODEL=Qwen/Qwen3-8B`
- 只需填写 API Key

该设置写入 `channels.unofficial.fallback.*` 与 `plugins.community.fallback.*`，不会覆盖主模型配置。

## 执行入口

- 安装阶段自动执行：`install.sh` 在安装后会触发档位选择与注入
- 配置菜单手动执行：`config-menu.sh` -> `高级设置` -> `token规划规则注入（低/中/高）`
