# OpenClaw World Phase 1 Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 `subprojects/openclaw-world` 从可跑骨架推进为第一阶段可验收的独立实验项目，完成单龙虾基地、任务派发、实时反馈和共享世界入口壳。

**Architecture:** 前端维持 `Vite + TypeScript + Phaser 3` 的双层结构，外层为轻量控制台 DOM，内层为世界画布；后端维持轻量 Node HTTP + WebSocket 网关，负责草稿构筑、任务模拟与 OpenClaw 适配。配置修改采用“保存草稿 + 应用到 OpenClaw”的双阶段机制。Shared World 只保留独立场景壳与入口，不做多人态。

**Tech Stack:** TypeScript, Phaser 3, Vite, Node HTTP, ws, Vitest

---

### Task 1: 完成阶段文档与工作记忆文件

**Files:**
- Create: `subprojects/openclaw-world/task_plan.md`
- Create: `subprojects/openclaw-world/findings.md`
- Create: `subprojects/openclaw-world/progress.md`
- Create: `docs/plans/2026-04-02-openclaw-world-phase1-design.md`

**Step 1: 写入目标、阶段、约束与风险**

**Step 2: 记录现有骨架能力和仓库脏区边界**

**Step 3: 保存到仓库，后续开发同步更新**

### Task 2: 重构前端 UI 为世界驱动控制台

**Files:**
- Modify: `subprojects/openclaw-world/client/src/main.ts`
- Modify: `subprojects/openclaw-world/client/src/styles.css`

**Step 1: 将控制台拆分成世界画布、任务条、构筑摘要、对象面板**

**Step 2: 六个基地对象分别映射职业台、技能书架、装备台、任务桌、状态镜、世界门**

**Step 3: 保留统一的保存草稿/应用按钮，避免即点即写**

### Task 3: 增强 Phaser 世界表达

**Files:**
- Modify: `subprojects/openclaw-world/client/src/world.ts`

**Step 1: 为 Home Base 提供稳定的对象热点和当前对象高亮**

**Step 2: 为 runtime state 提供人物移动、状态文案和共享世界场景切换**

**Step 3: Shared World 场景只提供入口骨架和返回 Home Base 的视觉反馈**

### Task 4: 补齐网关状态边界

**Files:**
- Modify: `subprojects/openclaw-world/gateway/src/server.ts`
- Modify: `subprojects/openclaw-world/gateway/src/services/store.ts`
- Modify: `subprojects/openclaw-world/gateway/src/services/catalog.ts`
- Modify: `subprojects/openclaw-world/gateway/src/connectors/openclaw.ts`

**Step 1: 确保保存草稿与应用结果清晰分离**

**Step 2: 返回更完整的 build/runtime/world 快照给前端**

**Step 3: 保持 OpenClaw 缺席时的本地镜像模式**

### Task 5: 测试与运行脚本

**Files:**
- Modify: `subprojects/openclaw-world/gateway/tests/state.test.ts`
- Create: `subprojects/openclaw-world/scripts/dev.sh`
- Modify: `subprojects/openclaw-world/README.md`

**Step 1: 增加 store 和 catalog 的测试覆盖**

**Step 2: 增加开发/运行脚本，减少手工操作**

**Step 3: 跑通 `npm test`、`npm run build`、`npm start` 并做页面截图验证**
