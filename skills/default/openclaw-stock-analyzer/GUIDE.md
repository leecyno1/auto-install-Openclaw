# OpenClaw Stock Analyzer 使用指南

## 1. 功能定位
- 面向价值投资的个股深度分析技能，内置巴菲特 + 段永平框架、五维评分、DCF、PEG、建仓计划、财报解读。
- 更适合做美股/港股公司的深度研究与长线仓位规划。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/openclaw-stock-analyzer`
- 安装后目录: `~/.openclaw/skills/openclaw-stock-analyzer`

## 2. 使用前准备
- Python 3
- 建议联网环境正常，便于获取行情、财务与公告数据
- 无强制 API Key 要求，但若你后续接入自有行情源，可按上游脚本扩展

## 3. 使用方式
- `analyze-stock` 适合快速看公司
- `analyze-value` 适合做价值投资深度分析
- `analyze-earnings` 适合财报后复盘

## 4. 推荐提问方式
- 请用 openclaw-stock-analyzer 深度分析 AAPL，给出估值、护城河和建仓区间。
- 请用 openclaw-stock-analyzer 对比 `AMZN` 和 `META` 哪个更适合长期持有。
- 请用 openclaw-stock-analyzer 生成 COIN 最新财报解读。

## 5. 手动验证
```bash
cd skills/default/openclaw-stock-analyzer
python3 analyze-value AAPL
```

## 6. 参考资料
- 上游来源: https://github.com/feiyuggg/openclaw-stock-analyzer
- 方法论文档: `METHODOLOGY.md`
- 本技能说明: `SKILL.md`

## 7. 注意事项
- 该技能偏研究和估值，不适合高频盯盘。
- 输出含主观判断，使用前应结合基本面和风险承受能力二次确认。
