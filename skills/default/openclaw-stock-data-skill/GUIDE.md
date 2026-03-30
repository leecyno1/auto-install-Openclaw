# OpenClaw Stock Data Skill 使用指南

## 1. 功能定位
- 通过 `data.diemeng.chat` 的股票数据接口查询日线、分钟线、财务因子、快照、可转债等数据。
- 适合接入自建或第三方股票数据服务，给 OpenClaw 提供统一行情接口。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/openclaw-stock-data-skill`
- 安装后目录: `~/.openclaw/skills/openclaw-stock-data-skill`

## 2. 使用前准备
- 在 `https://data.diemeng.chat/` 注册账号并开通接口权限
- 环境变量 `STOCK_API_KEY`
- 可选配置 `baseUrl`，默认 `https://data.diemeng.chat`

## 3. 配置步骤
1. 申请并确认目标接口权限已开通。
2. 写入环境变量:
```bash
export STOCK_API_KEY="你的_api_key"
```
3. 如需在 OpenClaw 中长期启用，建议在 `skills.entries.openclaw-stock-skill` 下配置 `apiKey/env/config.baseUrl`。

## 4. 推荐提问方式
- 请用 openclaw-stock-data-skill 查询 `000001.SZ` 最近 30 日日线。
- 请用 openclaw-stock-data-skill 查询 `600519.SH` 5 分钟线和财务因子。
- 请用 openclaw-stock-data-skill 查今天的集合竞价和收盘快照。

## 5. 手动验证
```bash
cd skills/default/openclaw-stock-data-skill
python3 example.py
```

## 6. 参考资料
- 上游来源: https://github.com/1018466411/openclaw-stock-data-skill
- 服务官网: https://data.diemeng.chat/
- 本技能说明: `SKILL.md`

## 7. 注意事项
- 如果返回 `403`，通常是权限未开通，不是脚本问题。
- 不要把 `apiKey` 放在 URL 查询参数中，按技能说明用 Header 传递。
