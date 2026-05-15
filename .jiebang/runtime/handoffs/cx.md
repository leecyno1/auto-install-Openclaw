---
agent: cx
status: active
updated_at: 2026-05-14 00:00 CST
task: boutique-skills-repository-split
mode: manual
---

# Handoff

## Goal

完成正式上市前最后一轮安装稳定性与健壮性迭代，并收口当前脏工作区：保护新用户首次安装链路、保留 Hermes/网站/像素小屋增强能力、审查新增 skills 与模型注册表变更能否进入发布提交。

## Done

- 恢复并核对 `.jiebang` 上下文；确认主要交接源是 `.jiebang/runtime/handoffs/cx.md`，`cc` / `ag` 仍是模板。
- 确认当前分支为 `release/hermes-website-minimax-hardening-20260503`。
- 确认发布收口方向仍是：`13147` 从默认入口降级为显式兼容能力；新安装不默认写入 `OPENCLAW_PUBLIC_API_URL=http://127.0.0.1:13147` 或 `OPENCLAW_QUOTA_ENFORCER_URL=http://127.0.0.1:13147`；README/help/preflight 不推荐 `dashboard-pairing` / `repair-pairing`。
- 完整复跑 `./scripts/release-check.sh`：第一次偶发失败在 `tests/test_health_server_runtime.py` 的健康服务启动；随后单独复跑健康服务测试通过，`./scripts/preflight-check.sh` 通过，最后完整 `./scripts/release-check.sh` 通过，包含 `[PASS] preflight`、`[PASS] secret scan`、`release check passed`。
- 单独复跑新增模型注册表测试：`python3 -m unittest discover -s tests -p 'test_model_registry.py'` 通过。
- 审查新增文件规模：新增 skills 很多，最大新增文件包括 `skills/default/alphaear-predictor/scripts/predictor/exports/models/kronos_news_v1_20260101_0015.pt` 约 1.3MB，以及若干 jpeg 资产；当前没有新增超过 5MB 的未跟踪文件。
- 已对未跟踪 `AGENTS.md` 做最小一致性修正：移除旧 `dashboard-pairing`、`--with-monitoring` 默认 proxy、`main/install.sh` 入口描述，改为 release 分支入口、`website --sync` 和 13147 显式兼容语义。
- 新增跨仓库改造：`boutique-openclaw-skills` 已导入安装器默认 skills，生成 `low` / `medium` / `high` 三档 JSON、三档文档、统一手册索引和安装脚本。
- 安装器默认远端技能源已切到 `boutique-openclaw-skills`，保留本地 `skills/manifest.json` 作为兼容缓存和测试契约。
- 验证通过：OpenClawInstaller `python3 -m unittest discover -s tests -p 'test_config_surface.py'`；boutique `python3 -m unittest discover -s tests`；boutique `./scripts/install-tier.sh high --dry-run`。
- 已完成安装器瘦身：删除本仓库 `skills/default` 大包，仅保留 `skills/default/README.md` 占位和 `skills/manifest.json` 兼容缓存；manifest 生成器改为读取 sibling boutique 仓库或 `OPENCLAW_SKILLS_SOURCE_DIR`。
- 安装器测试/预检已改为读取 boutique skills：`tests/test_skills_manifest.py`、`tests/test_config_surface.py`、`scripts/preflight-check.sh`。
- 最新验证通过：OpenClawInstaller `./scripts/release-check.sh`；boutique `python3 -m unittest discover -s tests`；boutique `./scripts/install-tier.sh low|medium|high --dry-run`。
- Boutique README 与 `scripts/build_skills_directory.py` 已改为默认三档优先，不再宣传旧 npm OpenClaw 默认统计；`scripts/sync-upstream.sh` 移除作者本机绝对路径。
- 默认 skills 远端源已切到国内 Gitee：`OPENCLAW_SKILLS_REPO_URL=https://gitee.com/leecyno1/boutique-openclaw-skills.git`；GitHub 通过 `OPENCLAW_SKILLS_REPO_GITHUB_URL` 作为回退。
- boutique 仓库已添加 `gitee-leecyno1` remote；README 增加国内源发布顺序：先 `git push gitee-leecyno1 main`，再 `git push origin main`。
- 已提交 boutique：`54d5dec feat: maintain default OpenClaw skills tiers`，并成功推送 GitHub `origin/main`。Gitee `leecyno1/boutique-openclaw-skills` 当前不存在/无权限，推送返回 404；需先在 Gitee 创建仓库后再执行 `git push gitee-leecyno1 main`。
- 已提交安装器：`bf5b31b refactor: externalize default skills to boutique registry`，并成功推送 Gitee `gitee-leecyno1/release/hermes-website-minimax-hardening-20260503` 与 GitHub `mine/release/hermes-website-minimax-hardening-20260503`。
- 最终验证：OpenClawInstaller `./scripts/release-check.sh` 通过；boutique `python3 -m unittest discover -s tests` 与 `./scripts/install-tier.sh high --dry-run` 通过。

## In Progress

- 正在做提交前分组和风险收口。
- 当前工作区仍很脏：安装器仓库包含发布收口改动、boutique 同步改动、`skills/default` 大包删除、`scripts/lib/model_registry.py`、`tests/test_model_registry.py`、根目录 `AGENTS.md`。
- 实际代码/文档已包含：`--extra-model` 多模型注册表、`~/.openclaw/model-capabilities.json`、`archivedProviders` 去重、Hermes Dashboard 9119、Hermes OpenAI bridge 8000、网站 SSH 隧道接入 13145/9119/19000/13146、`OPENCLAW_ENABLE_LEGACY_QUOTA_PROXY=1` 保护旧 13147 代理自动重启。

## Changed Files

已跟踪修改：
- README.md
- config-menu.sh
- docs/plans/2026-04-30-cloud-to-local-reverse-ssh-control.md
- docs/upstream-sources.md
- install-openclaw.sh
- install.sh
- scripts/gateway-quota-enforcer.py
- scripts/generate_skills_manifest.py
- scripts/lib/openclaw-common.sh
- scripts/lib/skills.sh
- scripts/media_quota.py
- scripts/refresh_default_skills.py
- scripts/remote-local-control.sh
- skills/default/*（大包删除）
- skills/default/README.md（占位说明）
- skills/manifest.json
- tests/test_config_surface.py
- tests/test_install_entry_smoke.py
- tests/test_launcher_contract.py
- tests/test_media_quota.py
- tests/test_readme_launcher_alignment.py

未跟踪重点：
- AGENTS.md
- scripts/lib/model_registry.py
- tests/test_model_registry.py
- `skills/default/README.md` 占位说明

## Risks

- `AGENTS.md` 仍是未跟踪文件，已做最小修正但是否纳入提交仍需拍板；若纳入，建议再通读一遍完整文件。
- boutique 仓库新增完整 skills 大包，需先提交/推送 boutique，再提交安装器引用，否则远端安装器会指向尚不存在的 skills 源内容。
- `scripts/health-server.sh` 仍返回 `quota_enforcer` 服务字段，语义通过 `role: legacy_quota_proxy` 表达；如果对外 API 要更名，测试也需同步。
- `install.sh` 仍生成 `lobster-quota-enforcer.service` 兼容资产但默认不 enable/restart；后续可决定是否移除。

## Next Step

下一步按仓库拆分提交：A) `boutique-openclaw-skills` 提交 skills/default、tiers、docs、install-tier/import 脚本与测试，并先推送 Gitee 再推送 GitHub；B) `OpenClawInstaller` 提交删除 skills/default 大包、保留占位 README、boutique 同步来源、README 边界说明、manifest 兼容缓存和测试。提交前再次确认两个仓库状态并按需 stage。
