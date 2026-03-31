# CLAWPANEL-BORROW 改造清单

> 来源：对 `qingchencloud/clawpanel` 的深度审计
> 目标：吸收后端可靠性工程能力，不改变像素小屋 UI 路线

---

## 一、可直接借鉴（优先级：高）

### 1. 前端 API 缓存 + In-Flight 去重
**来源**：`clawpanel/src/lib/tauri-api.js`
**问题**：当前 `configure.js` / `world-console.js` 每次页面切换都 `fetch({ cache: "no-store" })`，无去重无缓存，2C2G 机器并发拉起多个进程。
**落地文件**：`subprojects/lobster-sanctum-ui/web/api-client.js`（新建）

```
改造内容：
- 简单 Map 缓存（TTL: 读 15s / 写 5s）
- In-flight 去重（同一 key 并发只发一个请求）
- invalidate() 清缓存（写操作后自动调用）
- 导出 cachedFetch / invalidate 供各模块使用
```

### 2. 配对/配置一键修复入口
**来源**：`clawpanel/src-tauri/src/commands/pairing.rs` + 脚本已有 `apply_dashboard_pairing_bypass_*`
**问题**：服务器换 IP/域名后 allowedOrigins 失效，网页端持续 pairing required。
**落地文件**：`config-menu.sh` 新增 `repair-pairing` 入口 + `install.sh` 强化

```
改造内容：
- 新增菜单项 [X] 一键修复配对与登录权限（整合 allowedOrigins + pairing bypass）
- 独立 CLI 命令：openclaw-config-harden（底层 Python 脚本）
- 自动读取当前 server IP/hostname 追加到 allowedOrigins
```

### 3. Skills 列表容错回退
**来源**：`clawpanel/src-tauri/src/commands/skills.rs`
**问题**：CLI 超时/解析失败时 skill 页空白。
**落地文件**：`subprojects/lobster-sanctum-ui/projection-api/server.py`

```
改造内容：
- get_skills() 增加 local_scan_fallback：
  1. 优先调 CLI（timeout 12s）
  2. CLI 失败 → 扫描 ~/.openclaw/skills 目录
  3. 返回合并结果 + diagnostic 字段
```

### 4. Gateway 守护状态机（轻量版）
**来源**：`clawpanel/src-tauri/src/commands/service.rs` + `src/lib/app-state.js`
**落地文件**：`subprojects/lobster-sanctum-ui/openclaw-runtime-bridge.sh` + `projection-api/server.py`

```
改造内容：
- 冷却窗口：Gateway 异常退出后 60s 内不重复拉起
- 稳定窗口：连续运行 120s 后清零重启计数
- 最多自动重启 3 次，3 次后放弃并写 guardian.log
- 每 15s 检测一次（端口连通检测，无系统命令依赖）
```

### 5. 前端热更新 + 哈希校验
**来源**：`clawpanel/src-tauri/src/commands/update.rs`
**落地时机**：像素小屋独立部署后（Phase 2）

```
改造内容（后续）：
- update manifest: https://<cdn>/lobster-sanctum/latest.json
- 下载 zip → SHA-256 校验 → 解压到 web-update/
- 热加载：下次访问自动生效
- rollback：删除 web-update/ 目录即可回退
```

### 6. 版本策略矩阵
**来源**：`clawpanel/openclaw-version-policy.json` + `config.rs`
**落地文件**：`install.sh` 新增 `select_version_policy()`

```
改造内容：
- 内置 JSON：面板版本 → 推荐 OpenClaw 版本映射
- 安装时按面板版本自动选推荐版本，避免装错
- 支持 official / chinese 双源
```

---

## 二、可适配后使用（优先级：中）

### 7. 配置写入 Guardian 防抖
**来源**：`clawpanel/src/lib/tauri-api.js` `_debouncedReloadGateway`
**落地文件**：`projection-api/server.py` + `world-console.js`

```
改造内容：
- 写配置后 3s 内多次操作只触发一次 Gateway reload
- 防止用户批量修改时反复重启 Gateway
```

### 8. 静态资源长缓存策略
**来源**：`clawpanel/scripts/serve.js`
**落地文件**：`scripts/lobster-world.sh`

```
改造内容：
- HTML 不缓存
- /assets/* 长缓存 (max-age=31536000, immutable)
- 每次构建自动给 JS/CSS 加 hash 后缀
```

---

## 三、不建议照搬

| 方案 | 原因 |
|------|------|
| Tauri/Rust 桌面架构 | 服务器版无需，引入成本高 |
| clawpanel UI 风格 | 不是像素世界产品，视觉路线不同 |
| 实时写入（不改保存按钮） | 风险高，当前"点保存再执行"更可控 |
| 全部 Rust 重写 | 偏离轻量化目标 |

---

## 四、分阶段实施路线

| 阶段 | 内容 | 文件 |
|------|------|------|
| **Phase 1-A** | API 缓存层 + In-Flight 去重 | `api-client.js` 新建 |
| **Phase 1-B** | projection-api Skills 容错回退 | `server.py` |
| **Phase 1-C** | 独立配对修复脚本 + 菜单入口 | `repair-pairing.sh` 新建 |
| **Phase 2-A** | Gateway 守护状态机（轻量版） | `openclaw-runtime-bridge.sh` |
| **Phase 2-B** | 静态资源 hash + 长缓存 | `build-runtime-assets.sh` |
| **Phase 3** | 热更新 manifest + 校验 | `server.py` + CDN |
| **Phase 4** | 版本策略矩阵 | `install.sh` |

---
*生成时间：2026-03-31 | 来源：clawpanel 审计报告*
