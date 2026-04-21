---
agent: cx
status: active
updated_at: 2026-04-21 00:00
task: installer-skill-sync-hardening
mode: manual
---

# Handoff

## Goal

继续收口 `OpenClawInstaller` 的脚本稳定性，降低 skills 同步中的假缺失、假可同步和作者机器路径依赖，让安装脚本与默认技能仓在本地优先前提下更稳。

## Done

- 将 `refresh_default_skills.py` 的 ClawHub 拉取逻辑改为只走已验证通道：官方 `clawhub inspect --json`
- 移除对不存在的 `https://clawhub.ai/api/skills/<slug>/latest` 的依赖
- 默认关闭 `npx clawhub` 回退，避免批量同步时过慢；显式开关为 `OPENCLAW_ENABLE_NPX_CLAWHUB=1`
- 增强本地技能搜索：支持 `~/.openclaw/skills`、`~/.codex/skills`、`~/.agents/skills`
- 增加高置信别名解析：`openai-docs`、`plugin-creator`、`skill-installer`、`tdd`、`frontend-dev`、`fullstack-dev`、`flutter-dev`、`ios-application-dev`、`react-native-dev`、`pptx-generator`
- 重跑 `docs/skills-update-report.md`，把 `missing_unknown` 从 100 压到 78，并将 `web-design` 进一步接回上游别名
- 重新生成 `skills/manifest.json`
- 修复全局 `jiebang.sh` 可执行权限，`skills/jiebang/scripts/jiebang.sh validate` 可用
- 通过 `python3 -m unittest discover -s tests -p 'test_refresh_default_skills_logic.py'`
- 通过 `./scripts/preflight-check.sh`

## In Progress

- 已补齐一批 MiniMax 官方 skill 上游索引，并将 `missing_unknown` 压到 78
- 已补 `web-design -> web-design-guidelines` 高置信别名
- 下一轮可继续建立 `ClawHub slug` 纠偏映射，减少 `hint-only` 的 54 项
- 下一轮可继续补 `docs/upstream-sources.md` 中剩余确有上游的 skill

## Changed Files

- scripts/refresh_default_skills.py
- tests/test_refresh_default_skills_logic.py
- docs/skills-update-report.md
- skills/manifest.json
- .jiebang/runtime/current-task.md
- .jiebang/runtime/handoffs/cx.md

## Risks

- 许多 `.clawhub/origin.json` 里的 slug 可能已经过时，即使装了官方 CLI 也无法直接拉取
- 当前默认不启用 `npx` 远程回退，保守但会保留更多 `保留现状`
- 某些 skill 的“别名映射”仍然是经验型高置信映射，不是官方声明源

## Next Step

优先做 `ClawHub slug` 纠偏表：从 `docs/skills-update-report.md` 里的 `hint-only` skills 中选一批高价值项，结合 `clawhub search` 结果建立 `old_slug -> new_slug` 映射，并接入 `refresh_default_skills.py`。
