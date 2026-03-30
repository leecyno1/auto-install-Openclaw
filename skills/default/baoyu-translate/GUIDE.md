# baoyu-translate 使用指南

## 1. 功能定位
- Translates articles and documents between languages with three modes - quick (direct), normal (analyze then translate), and refined (analyze, translate, review, polish). Supports custom glossaries and terminology consistency via EXTEND.md. Use when user asks to "translate", "翻译", "精翻", "translate article", "translate to Chinese/English", "改成中文", "改成英文", "convert to Chinese", "localize", "本地化", or needs any document translation. Also triggers for "refined translation", "精细翻译", "proofread translation", "快速翻译", "快翻", "这篇文章翻译一下", or when a URL or file is provided with translation intent.
- 默认档位: 仅全量默认包/手动同步
- 仓库目录: `skills/default/baoyu-translate`
- 安装后目录: `~/.openclaw/skills/baoyu-translate`

## 2. 使用前准备
- 无强制 API Key；按 skill 自身依赖运行。

## 3. 配置步骤
1. 通常无需额外配置。若运行时报缺依赖，再按 `SKILL.md` 补装。

## 4. 推荐提问方式
- 请使用 baoyu-translate 帮我处理当前任务。
- 如果 baoyu-translate 需要额外配置，请先告诉我缺少什么。

## 5. 手动验证
```bash
ls -la ~/.openclaw/skills/baoyu-translate
```

## 6. 参考资料
- 上游来源: https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-translate
- 本技能说明: `SKILL.md`
