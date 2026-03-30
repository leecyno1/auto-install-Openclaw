# baoyu-post-to-wechat 使用指南

## 1. 功能定位
- Posts content to WeChat Official Account (微信公众号) via API or Chrome CDP. Supports article posting (文章) with HTML, markdown, or plain text input, and image-text posting (贴图, formerly 图文) with multiple images. Markdown article workflows default to converting ordinary external links into bottom citations for WeChat-friendly output. Use when user mentions "发布公众号", "post to wechat", "微信公众号", or "贴图/图文/文章".
- 默认档位: 仅全量默认包/手动同步
- 仓库目录: `skills/default/baoyu-post-to-wechat`
- 安装后目录: `~/.openclaw/skills/baoyu-post-to-wechat`

## 2. 使用前准备
- 无强制 API Key；按 skill 自身依赖运行。

## 3. 配置步骤
1. 通常无需额外配置。若运行时报缺依赖，再按 `SKILL.md` 补装。

## 4. 推荐提问方式
- 请使用 baoyu-post-to-wechat 帮我处理当前任务。
- 如果 baoyu-post-to-wechat 需要额外配置，请先告诉我缺少什么。

## 5. 手动验证
```bash
ls -la ~/.openclaw/skills/baoyu-post-to-wechat
```

## 6. 参考资料
- 上游来源: https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-post-to-wechat
- 本技能说明: `SKILL.md`
