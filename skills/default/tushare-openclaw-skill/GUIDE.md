# Tushare OpenClaw Skill 使用指南

## 1. 功能定位
- 面向中国市场的 Tushare Pro 数据查询技能，可查股票、基金、期货、债券、宏观与财务数据。
- 适合 A 股/基金/宏观数据检索、财务表拉取、策略数据补数。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/tushare-openclaw-skill`
- 安装后目录: `~/.openclaw/skills/tushare-openclaw-skill`

## 2. 使用前准备
- Tushare 账号
- 环境变量 `TUSHARE_TOKEN`
- Python 依赖 `tushare pandas`

## 3. 配置步骤
1. 到 https://tushare.pro 注册账号并获取 Token。
2. 写入环境变量:
```bash
export TUSHARE_TOKEN="你的_token"
```
3. 安装 Python 依赖，并确保 OpenClaw 运行环境可读取该变量。

## 4. 推荐提问方式
- 请用 tushare-openclaw-skill 查询 600519.SH 最近 60 个交易日的日线。
- 请用 tushare-openclaw-skill 拉取招商银行最近 3 年利润表与现金流。
- 请用 tushare-openclaw-skill 查询今天涨跌停列表。

## 5. 手动验证
```bash
cd skills/default/tushare-openclaw-skill
python3 scripts/tushare_examples.py
```

## 6. 参考资料
- 上游来源: https://github.com/DayDreammy/tushare-openclaw-skill
- Tushare 官网: https://tushare.pro
- 本技能说明: `SKILL.md`

## 7. 注意事项
- 免费积分和频次有限，高频批量任务前要先确认额度。
- A 股代码需带交易所后缀，例如 `600000.SH`、`000001.SZ`。
