# OpenClaw Stock 使用指南

## 1. 功能定位
- 一个 AI 驱动的自动化交易系统项目，包含短线、长线、回测、报警、风控与多数据源方案。
- 适合做系统参考、模拟盘研究、自动交易方案设计。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/openclaw-stock`
- 安装后目录: `~/.openclaw/skills/openclaw-stock`

## 2. 常见依赖与密钥
- 股票数据: `FINNHUB_API_KEY`
- AI 分析: `GOOGLE_AI_API_KEY`、`DEEPSEEK_API_KEY`
- 新闻/资讯: `NAVER_CLIENT_SECRET`、`CRYPTOPANIC_API_KEY`
- 通知: `TELEGRAM_BOT_TOKEN`
- 其他扩展源按 `API_CONFIGURATION_GUIDE.md` 配置

## 3. 推荐使用方式
- 先读 `QUICKSTART.md` 和 `FREE_DATA_SOURCES_GUIDE.md`
- 再按 `BACKTEST_GUIDE.md` 做回测
- 最后才考虑模拟盘或接入通知

## 4. 推荐提问方式
- 请用 openclaw-stock 给我一套低成本的自动交易架构方案。
- 请用 openclaw-stock 整理短线监控、报警和风控流程。
- 请用 openclaw-stock 说明 Finnhub、Gemini、DeepSeek 分别承担什么角色。

## 5. 手动验证
```bash
ls skills/default/openclaw-stock
```

## 6. 参考资料
- 上游来源: https://github.com/Superandyfre/Openclaw-stock
- 本地说明: `SKILL.md`

## 7. 注意事项
- 该项目面向自动交易，风险高于普通分析 skill。
- 本仓库收录它是为了本地可检索与方案复用，不代表建议默认实盘启用。
