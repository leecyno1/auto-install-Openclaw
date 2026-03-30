# Stock Analysis 使用指南

## 1. 功能定位
- 基于 Yahoo Finance 的股票/加密货币分析工具，支持个股分析、组合管理、观察列表、分红分析、热点扫描、传闻扫描。
- 更适合美股与加密市场的轻量研究和日常跟踪。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/stock-analysis`
- 安装后目录: `~/.openclaw/skills/stock-analysis`

## 2. 使用前准备
- `uv`
- Python 环境可联网访问 Yahoo Finance、Google News、CoinGecko
- 可选: 安装 `bird` CLI 做 X/Twitter 情绪扫描
- 可选环境变量: `AUTH_TOKEN`、`CT0`

## 3. 配置步骤
1. 安装 `uv`。
2. 如需启用社媒扫描，安装 bird:
```bash
npm install -g @steipete/bird
```
3. 如需读取 X/Twitter，配置 `.env` 或环境变量:
```bash
export AUTH_TOKEN="你的_auth_token"
export CT0="你的_ct0"
```

## 4. 推荐提问方式
- 请用 stock-analysis 分析 AAPL。
- 请用 stock-analysis 比较 NVDA、AMD、TSLA。
- 请用 stock-analysis 查最近的热点股票和加密货币。
- 请用 stock-analysis 检查我的观察列表是否触发预警。

## 5. 手动验证
```bash
cd skills/default/stock-analysis
uv run scripts/analyze_stock.py AAPL --fast
```

## 6. 参考资料
- 上游来源: https://github.com/moinsen-dev/stock-analysis
- 本技能说明: `SKILL.md`

## 7. 注意事项
- 行情主要来自 Yahoo Finance，存在延迟与限流风险。
- 社媒扫描依赖 bird 和登录态，不配置也可以使用基础分析能力。
