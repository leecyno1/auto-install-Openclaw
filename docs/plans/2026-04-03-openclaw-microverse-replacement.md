# OpenClaw Microverse Replacement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the Phaser-based experimental world frontend with a Microverse/Godot-based Home Base frontend that preserves OpenClaw business semantics and uses `world-gateway` as the only adapter.

**Architecture:** Build a new Godot project under `subprojects/openclaw-microverse` that consumes `world-gateway` HTTP/WS APIs through a thin Godot client layer. Keep the existing gateway data model and apply/task flow as the system of record, and export the Godot Web build into a static directory that the gateway can serve.

**Tech Stack:** Godot 4, GDScript, Web export, existing `openclaw-world` TypeScript gateway, WebSocket + HTTP.

---

### Task 1: Establish the new Godot project

**Files:**
- Create: `subprojects/openclaw-microverse/project.godot`
- Create: `subprojects/openclaw-microverse/export_presets.cfg`
- Create: `subprojects/openclaw-microverse/scenes/Main.tscn`
- Create: `subprojects/openclaw-microverse/scenes/HomeBase.tscn`
- Create: `subprojects/openclaw-microverse/scenes/SharedWorld.tscn`
- Create: `subprojects/openclaw-microverse/scripts/*.gd`
- Copy subset from: `/tmp/Microverse/asset/*`

**Step 1:** Create a clean Godot root that keeps browser compatibility as a first-class target.
**Step 2:** Reuse Microverse assets and fonts only where they help the Home Base baseline.
**Step 3:** Do not import original AI-social/autoload systems.

### Task 2: Build the OpenClaw gateway client layer for Godot

**Files:**
- Create: `subprojects/openclaw-microverse/scripts/WorldGatewayClient.gd`
- Create: `subprojects/openclaw-microverse/scripts/WorldStateStore.gd`
- Create: `subprojects/openclaw-microverse/scripts/BuildDraftAdapter.gd`

**Step 1:** Fetch `GET /api/build`, `GET /api/runtime`, and `GET /api/world/state`.
**Step 2:** Maintain a WebSocket connection to `/ws/world`.
**Step 3:** Expose signals and normalized state so scenes do not bind directly to raw API payloads.

### Task 3: Rebuild Home Base semantics in Godot

**Files:**
- Create: `subprojects/openclaw-microverse/scenes/stations/*.tscn`
- Create: `subprojects/openclaw-microverse/scripts/HomeBaseController.gd`
- Create: `subprojects/openclaw-microverse/scripts/AvatarController.gd`
- Create: `subprojects/openclaw-microverse/scripts/panels/*.gd`

**Step 1:** Add six station objects: role altar, skill shelf, equipment forge, task desk, status mirror, world portal.
**Step 2:** Add a moving avatar that reflects runtime station and activity.
**Step 3:** Add panel flows for save draft, apply build, and dispatch task.

### Task 4: Integrate with the existing gateway and web serving

**Files:**
- Modify: `subprojects/openclaw-world/gateway/src/lib/paths.ts`
- Modify: `subprojects/openclaw-world/package.json`
- Create: `subprojects/openclaw-microverse/scripts/export-web.sh`
- Create: `subprojects/openclaw-microverse/README.md`

**Step 1:** Make the gateway capable of serving a configurable public directory.
**Step 2:** Export the Godot Web bundle to a path the gateway can serve.
**Step 3:** Keep Phaser client out of the primary path.

### Task 5: Verify the Phase 1 closed loop

**Files:**
- Modify: `subprojects/openclaw-world/gateway/tests/*.test.ts`
- Create: `subprojects/openclaw-microverse/docs/phase1.md`

**Step 1:** Add or update tests around gateway public dir/config where touched.
**Step 2:** Run existing gateway tests.
**Step 3:** Verify Godot project structure and editor import paths are valid.
