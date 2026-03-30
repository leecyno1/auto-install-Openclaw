# baoyu-image-gen 使用指南

## 1. 功能定位
- AI image generation with OpenAI, Google, OpenRouter, DashScope, Jimeng, Seedream and Replicate APIs. Supports text-to-image, reference images, aspect ratios, and batch generation from saved prompt files. Sequential by default; use batch parallel generation when the user already has multiple prompts or wants stable multi-image throughput. Use when user asks to generate, create, or draw images.
- 默认档位: 仅全量默认包/手动同步
- 仓库目录: `skills/default/baoyu-image-gen`
- 安装后目录: `~/.openclaw/skills/baoyu-image-gen`

## 2. 使用前准备
- 无强制 API Key；按 skill 自身依赖运行。

## 3. 配置步骤
1. 通常无需额外配置。若运行时报缺依赖，再按 `SKILL.md` 补装。

## 4. 推荐提问方式
- 请使用 baoyu-image-gen 帮我处理当前任务。
- 如果 baoyu-image-gen 需要额外配置，请先告诉我缺少什么。

## 5. 手动验证
```bash
ls -la ~/.openclaw/skills/baoyu-image-gen
```

## 6. 参考资料
- 上游来源: https://github.com/JimLiu/baoyu-skills/tree/main/skills/baoyu-image-gen
- 本技能说明: `SKILL.md`
