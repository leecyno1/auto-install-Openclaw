# Current Task

## Objective

持续完善 `OpenClawInstaller` 的安装与技能同步链路，重点收口默认技能包的上游来源解析、ClawHub/本地技能仓同步策略、manifest 一致性，以及脚本级预检稳定性。

## Success Criteria

- `scripts/refresh_default_skills.py` 只依赖已验证的同步通道，并对不可用来源明确降级
- 本地技能搜索可覆盖 `~/.openclaw/skills`、`~/.codex/skills`、`~/.agents/skills` 以及高置信别名
- `docs/skills-update-report.md` 能真实反映 `已最新 / 已更新 / 保留现状`
- `skills/manifest.json` 与当前 skills 目录一致，`preflight` 与 `release-check` 通过
- `.jiebang/runtime` 中的 handoff 能让下一代理直接接续当前改造

## Open Questions

- 是否继续建立一份 `ClawHub 旧 slug -> 新 slug` 的纠偏表
- 是否把更多默认 skill 的上游来源补写进 `docs/upstream-sources.md`
- 是否允许在 CI 或显式参数下启用 `OPENCLAW_ENABLE_NPX_CLAWHUB=1` 做重型远程同步
