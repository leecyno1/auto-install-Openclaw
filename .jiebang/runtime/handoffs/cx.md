---
agent: cx
status: active
updated_at: 2026-04-30 00:00
task: prelaunch-installer-hardening
mode: manual
---

# Handoff

## Goal

完成正式上市前最后一轮安装稳定性与健壮性迭代，优先保护新用户首次安装链路：不直接回滚 13147 相关代码，但将其从默认路径降级为显式兼容能力，并清理旧 dashboard pairing 修复入口。

## Done

- 将 13147 从默认推荐路径降级：README / installer help / website sync / pixel-house 默认接线不再称其为外部统一入口
- 新安装不再默认写入 `OPENCLAW_PUBLIC_API_URL=http://127.0.0.1:13147` 或 `OPENCLAW_QUOTA_ENFORCER_URL=http://127.0.0.1:13147`
- 像素小屋默认只自动接线并启动 13146 健康检查；不再默认重启 quota enforcer
- `restart_quota_enforcer_menu` 增加 `OPENCLAW_ENABLE_LEGACY_QUOTA_PROXY=1` 保护，避免配置档位时自动启动旧代理
- `scripts/modules/tier-rules.sh` 保留 `--start/stop/restart-enforcer` 显式兼容命令，但 `--with-monitoring` 不再自动刷新代理
- README 删除 `gateway-quota-enforcer.py status` 作为用户常用命令，三档规则改为写入配额规则而非强制前置代理
- 保留删除 `dashboard-pairing` / `repair-pairing` 方向，并更新 `docs/CLAWPANEL_BORROW_PLAN.md` 为官方渠道配置流程
- `scripts/preflight-check.sh` 新增上市默认入口负向门禁：禁止旧 pairing 修复入口、13147 推荐入口、默认 env 写入 13147
- 更新相关测试断言：README/launcher/config/install smoke 覆盖 13147 非默认和 pairing 不残留
- 分析 `/Volumes/PSSD/Projects/网站`：网站后端默认读取 `OPENCLAW_DASHBOARD_PORT=13145`、`HERMES_DASHBOARD_PORT=9119`、`OPENCLAW_DASHBOARD_ALLOWED_ORIGINS`，并通过 SSH tunnel 访问服务器本机 Dashboard
- 安装器和配置菜单新增网站 Dashboard 对接：写入 13145/9119 env、网站域名白名单，并 patch OpenClaw `gateway.controlUi.allowedOrigins` / `allowInsecureAuth` / `dangerouslyDisableDeviceAuth`
- Hermes 安装完成后会尝试以 `127.0.0.1:9119` 启动 Hermes Dashboard（兼容 `hermes dashboard` / `hermes web` / `hermes ui` 命令，失败不阻断安装）

## In Progress

- `./scripts/preflight-check.sh` 已通过
- `./scripts/release-check.sh` 已通过
- 下一步建议在真实服务器上验证网站后台 SSH tunnel 打开 13145 / 9119 / 19000 三个页面

## Changed Files

- README.md
- install.sh
- config-menu.sh
- scripts/modules/tier-rules.sh
- scripts/health-server.sh
- scripts/preflight-check.sh
- docs/CLAWPANEL_BORROW_PLAN.md
- tests/test_readme_launcher_alignment.py
- tests/test_launcher_contract.py
- tests/test_lobster_setup_runtime.py
- tests/test_install_entry_smoke.py
- tests/test_media_quota.py
- tests/test_quota_enforcer_runtime.py
- tests/test_config_surface.py
- docs/plans/2026-04-30-cloud-to-local-reverse-ssh-control.md
- scripts/remote-local-control.sh
- .jiebang/runtime/current-task.md
- .jiebang/runtime/handoffs/cx.md

## Risks

- `install.sh` 仍会生成 `lobster-quota-enforcer.service` unit 文件作为兼容资产，但默认不 enable/restart；后续可决定是否彻底移除
- `scripts/health-server.sh` 仍报告 13147 服务状态，语义已改为 `legacy_quota_proxy`
- 当前仓库此前已有较大脏改动，提交前应再次核对 `git diff --stat` 和 release-check 输出

## Next Step

在真实云服务器执行安装脚本后，登录网站后台添加服务器，分别验证 OpenClaw Dashboard 13145、Hermes Dashboard 9119、像素小屋 19000 的 SSH 隧道会话是否能打开；若 Hermes 当前版本没有 dashboard/web/ui 命令，需根据实际 CLI 调整 `start_hermes_dashboard_*`。
