# wechat-title-generator 使用指南

## 1. 功能定位
- 公众号标题生成适配器。用于基于已确认的 Content Brief、文章大纲或初稿、目标读者与文章目标，生成 8 个公众号标题候选并推荐最佳标题。它只负责标题层，不负责全局主题判断与正文生成。
- 默认档位: 仅全量默认包/手动同步
- 仓库目录: `skills/default/wechat-title-generator`
- 安装后目录: `~/.openclaw/skills/wechat-title-generator`

## 2. 使用前准备
- 无强制 API Key；按 skill 自身依赖运行。

## 3. 配置步骤
1. 通常无需额外配置。若运行时报缺依赖，再按 `SKILL.md` 补装。

## 4. 推荐提问方式
- 请使用 wechat-title-generator 帮我处理当前任务。
- 如果 wechat-title-generator 需要额外配置，请先告诉我缺少什么。

## 5. 手动验证
```bash
ls -la ~/.openclaw/skills/wechat-title-generator
```

## 6. 参考资料
- 上游来源: 见 docs/upstream-sources.md
- 本技能说明: `SKILL.md`
