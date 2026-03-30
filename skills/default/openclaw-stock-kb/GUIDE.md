# OpenClaw Stock KB 使用指南

## 1. 功能定位
- 一套本地化的股票研究知识库，覆盖量化策略、技术指标、社媒情绪、风险管理、回测工具。
- 适合给 Agent 提供“投研脑库”，而不是直接执行下单。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/openclaw-stock-kb`
- 安装后目录: `~/.openclaw/skills/openclaw-stock-kb`

## 2. 包含内容
- `strategies/`：均值回归、动量、因子、事件驱动等
- `indicators/`：MA、MACD、RSI、ATR、布林带等
- `sentiment/`：Twitter/Reddit/微博/新闻情绪方法
- `risk-management/`：止损、仓位、组合风险、回撤管理
- `tools/`：Backtrader、VectorBT、Pandas 金融分析等

## 3. 推荐提问方式
- 请用 openclaw-stock-kb 解释 RSI 与 MACD 如何组合使用。
- 请用 openclaw-stock-kb 设计一个低波动 + 价值因子选股框架。
- 请用 openclaw-stock-kb 给我一份股票风控清单。

## 4. 手动验证
```bash
find skills/default/openclaw-stock-kb -type f | head
```

## 5. 参考资料
- 上游来源: https://github.com/freestylefly/openclaw-stock-kb
- 本地说明: `SKILL.md`

## 6. 注意事项
- 这是知识参考库，不直接提供实时行情与交易执行能力。
- 建议配合 `tushare-openclaw-skill`、`stock-analysis`、`openclaw-stock-analyzer` 一起用。
