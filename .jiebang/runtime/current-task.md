# Current Task

## Objective

进行正式上市前最后一轮安装稳定性与健壮性迭代：收口默认安装入口、配置菜单、像素小屋接线、发布门禁和文档一致性，避免新用户首次安装被实验性链路或旧修复入口干扰。

## Success Criteria

- 新安装默认不再把 `13147` 作为外部统一入口，也不默认写入 `OPENCLAW_PUBLIC_API_URL=http://127.0.0.1:13147`
- `13147` quota enforcer 仅作为显式启动的兼容/高级能力保留，相关 runtime 测试仍通过
- README、help、preflight 不再推荐 `dashboard-pairing` / `repair-pairing` 或旧配对修复入口
- 像素小屋默认只自动接线并启动 `13146` 健康检查，不默认启动 quota proxy
- `scripts/preflight-check.sh` 和 `scripts/release-check.sh` 覆盖上市默认入口负向检查并通过
- `.jiebang/runtime` handoff 能让下一代理直接接续发布前收尾
- 网站项目 `/Volumes/PSSD/Projects/网站` 可通过 SSH 隧道接入 13145 OpenClaw Dashboard、9119 Hermes Dashboard 与 19000 像素小屋，安装器会写入对应 env 和白名单

## Open Questions

- 是否在后续版本彻底删除 `lobster-quota-enforcer.service` 生成逻辑，还是继续保留一版兼容窗口
- 是否增加真实服务器/临时 HOME 的完整安装演练作为上市前人工验收步骤
- 是否继续回到 skills 同步主线，补 `ClawHub 旧 slug -> 新 slug` 纠偏表
