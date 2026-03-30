# xiaohongshutools 使用指南

## 1. 功能定位
- XiaoHongShu (Little Red Book) data collection and interaction toolkit. Use when working with XiaoHongShu (小红书) platform for: (1) Searching and scraping notes/posts, (2) Getting user profiles and details, (3) Extracting comments and likes, (4) Following users and liking posts, (5) Fetching home feed and trending content. Automatically handles all encryption parameters (cookies, headers) including a1, webId, x-s, x-s-common, x-t, sec_poison_id, websectiga, gid, x-b3-traceid, x-xray-traceid. Supports guest mode and authenticated sessions via web_session cookie.
- 默认档位: 仅全量默认包/手动同步
- 仓库目录: `skills/default/xiaohongshutools`
- 安装后目录: `~/.openclaw/skills/xiaohongshutools`

## 2. 使用前准备
- 无强制 API Key；按 skill 自身依赖运行。

## 3. 配置步骤
1. 通常无需额外配置。若运行时报缺依赖，再按 `SKILL.md` 补装。

## 4. 推荐提问方式
- 请使用 xiaohongshutools 帮我处理当前任务。
- 如果 xiaohongshutools 需要额外配置，请先告诉我缺少什么。

## 5. 手动验证
```bash
ls -la ~/.openclaw/skills/xiaohongshutools
```

## 6. 参考资料
- 上游来源: 见 docs/upstream-sources.md
- 本技能说明: `SKILL.md`
