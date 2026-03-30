# stock_datasource 使用指南

## 1. 功能定位
- 一个完整的 A 股数据与多 Agent 投研平台项目，本地打包后作为增强技能提供。
- 适合需要自建金融数据底座、实时订阅、MCP 查询和 Tushare 插件生成的用户。
- 安装形态: 增强技能，按需手动安装
- 仓库目录: `skills/default/stock_datasource`
- 安装后目录: `~/.openclaw/skills/stock_datasource`

## 2. 主要内容
- `README.md`：平台总体说明
- `docs/`：数据库、CLI、设计与部署资料
- `skills/stock-mcp-query/`：查询 MCP 服务
- `skills/stock-rt-subscribe/`：订阅实时行情节点
- `skills/tushare-plugin-builder/`：自动生成 Tushare 采集插件
- `skills/mcp-api-key-auth/`：MCP API 鉴权适配

## 3. 常见依赖与密钥
- 基础数据侧: `TUSHARE_TOKEN`
- 数据库侧: `CLICKHOUSE_HOST`、`CLICKHOUSE_PORT`
- AI 侧: `OPENAI_API_KEY`、`OPENAI_BASE_URL`、`OPENAI_MODEL`
- 实时订阅侧: `STOCK_RT_NODE_URL`、`STOCK_RT_TOKEN`
- MCP 查询侧: `STOCK_MCP_TOKEN`、`STOCK_MCP_SERVER_URL`

## 4. 推荐提问方式
- 请用 stock_datasource 帮我梳理本地 A 股数据平台部署方案。
- 请用 stock_datasource 看看如何接入 ClickHouse 和 Tushare。
- 请用 stock_datasource 说明 `stock-mcp-query` 和 `stock-rt-subscribe` 的区别。

## 5. 手动验证
```bash
find skills/default/stock_datasource/skills -maxdepth 2 -name 'SKILL.md'
```

## 6. 参考资料
- 上游来源: https://github.com/Yourdaylight/stock_datasource
- 本地说明: `SKILL.md`

## 7. 注意事项
- 这是平台级项目，安装后并不等于自动完成部署。
- 建议先从子技能开始单独验证，再推进整体平台落地。
