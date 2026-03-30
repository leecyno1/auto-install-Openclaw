# Lobster Sanctum Studio

`Lobster Sanctum Studio` is the standalone visual configuration project for OpenClaw.

Scope:
- UI/UX design and art polish for the 3-stage configuration flow.
- Persona selection, talent tree, armory/loadout, and build export UX.
- Pixel-world runtime projection for Lobster activity, task state, and multi-agent presence.
- Visual language iteration independent from installer/config shell logic.
- Pixel-first runtime optimization for low-resource servers.

Out of scope:
- Installer orchestration logic in `install.sh`.
- Main CLI menu orchestration in `config-menu.sh`.

Project layout:
- `web/`: workbench frontend source (`index.html`, `loadout.html`, `configure.html`, JS/CSS/assets), now served under `/workbench/*` by the world backend.
- `vendor/star-office-ui/`: imported upstream pixel-office baseline from `ringhyacinth/Star-Office-UI`.
- `../../scripts/lobster-world.sh`: local world service manager (default `19000`).
- `dev-server.sh`: frontend-only static preview helper for isolated workbench development. Not used as the main entry anymore.
- `projection-api/`: lightweight backend for runtime projection (`/runtime/state`, `/runtime/events`, `/runtime/stream`).
- `projection-api.sh`: projection backend service manager (default `19100`).
- `projection-push.sh`: CLI push tool for runtime state updates.
- `openclaw-runtime-bridge.sh`: OpenClaw -> Projection API bridge (`/status` -> `/runtime/ingest`).
- `SESSION.md`: dedicated session definition for UI/art-focused development.

Upstream references:

- `Star-Office-UI`: `https://github.com/ringhyacinth/Star-Office-UI`

## Integration direction

This subproject now has two distinct layers:

- `web/` is the Lobster build/configuration layer. It owns persona selection, skill trees, equipment, status, and exported presets.
- `vendor/star-office-ui/` is the imported world/runtime reference. It provides the pixel-room, state projection, area movement, and multi-agent office metaphor.

The next custom runtime should be built by deriving from the imported world layer, not by mixing raw upstream files directly into the existing `web/` pages.

Recommended rule:

- Keep upstream reference synchronized in `vendor/star-office-ui/`.
- Build Lobster-specific runtime pages and adapters in this subproject.
- Treat current Stage I / II / III pages as the “build chamber” for the runtime world.
- Runtime pages must request only the current role sprite pack, not all role packs.
- Production output must exclude `materials/`, previews, and backup art sources.

## Performance Policy

Runtime work should assume a small server target such as `2 CPU / 2 GB RAM`.

- Keep backend processes lightweight and single-process by default.
- Prefer pixel assets over large illustration assets.
- Compress new backgrounds and animated sheets before merging.
- Do not add development art source folders to runtime deployment payloads.

Detailed rules:

- `docs/pixel-runtime-performance.md`
- `docs/sprite-pipeline.md`

## Start

```bash
bash ../../scripts/lobster-world.sh start
```

## Session workflow

Use dedicated UI session:

```bash
bash ../../scripts/ui-studio-session.sh
```

Or manually open a new coding session with cwd:

```bash
subprojects/lobster-sanctum-ui
```

## URLs

- World / Home Base: `http://127.0.0.1:19000/`
- Workbench Role Station: `http://127.0.0.1:19000/workbench/index.html`
- Workbench Skill Station: `http://127.0.0.1:19000/workbench/loadout.html`
- Workbench Command Center: `http://127.0.0.1:19000/workbench/configure.html`
- Static preview only: `http://127.0.0.1:18188/index.html` via `dev-server.sh` when needed for isolated frontend debugging

## Runtime Adapter V1

Runtime page supports adapter profiles:

- `projection-api`: poll `http://127.0.0.1:19100/runtime/state` (default, recommended).
- `local-feed`: poll `./runtime-feed.json` (offline fallback).
- `star-office`: parse Star Office style `/status` JSON.
- `openclaw`: heuristic parse for OpenClaw-like status payloads.
- `auto`: auto-detect common state/detail/progress fields.
- `generic`: use custom JSON paths (`state/detail/progress`).

## Projection API V2+

Start backend:

```bash
cd subprojects/lobster-sanctum-ui
bash ./projection-api.sh start
```

Check backend:

```bash
curl -s http://127.0.0.1:19100/health
curl -s http://127.0.0.1:19100/runtime/state
```

Stage2 semantics (structured runtime event fields):

- `task_id`
- `phase`
- `tool`
- `model`
- `latency_ms`
- `error_code`
- `agent_id`
- `signature` (idempotency/de-dup key)

Additional endpoint:

- `POST /runtime/ingest` (accept raw payload, normalize + map to runtime event/state)
- `GET/POST /runtime/agents` (collaboration agents heartbeat/upsert)
- `GET /runtime/agents/stream` (agents SSE stream)
- `GET/POST /runtime/missions` (team mission board)

Notes:

- Duplicate events are auto de-duplicated by `signature` within a short TTL window.
- `GET /runtime/events` supports `since_id` for incremental pull.
- `GET /runtime/stream` supports resume via `Last-Event-ID` header or `since_id` query.
- Runtime UI uses agents SSE first and falls back to polling automatically.

Push runtime state:

```bash
bash ./projection-push.sh executing "正在执行安装与修复任务" 46 openclaw-bridge
```

Bridge OpenClaw runtime state to projection backend:

```bash
cd subprojects/lobster-sanctum-ui
bash ./openclaw-runtime-bridge.sh start
bash ./openclaw-runtime-bridge.sh status
```

Bridge env options:

- `OPENCLAW_STATUS_URL` (default `http://127.0.0.1:13145/status`)
- `PROJECTION_API_INGEST_URL` (default `http://127.0.0.1:19100/runtime/ingest`)
- `BRIDGE_INTERVAL_SEC` (default `3`)

## Runtime Asset Packs (Stage 4)

Runtime page now supports decoupled asset packs with lazy mode loading.

- Manifest: `web/runtime-assets/manifest.json`
- Pack descriptors: `web/runtime-assets/packs/<pack-id>/pack.json`
- Per-pack cache manifest: `web/runtime-assets/packs/<pack-id>/cache-manifest.json`

Build/update manifests:

```bash
cd subprojects/lobster-sanctum-ui
bash ./build-runtime-assets.sh
```

Build a trimmed production package:

```bash
bash ./scripts/build-production-package.sh
```

This package intentionally excludes:

- `materials/`
- preview screenshots
- backup packs
- Electron / desktop shell files

Rebuild local sprite reserve library and runtime role packs:

```bash
cd subprojects/lobster-sanctum-ui
python3 scripts/build_role_state_sprites.py
```

This generates:

- full compressed local action reserves under `materials/character-library/`
- current 4-state runtime packs under `vendor/star-office-ui/frontend/role-sprites/`

Default packs:

- `core` (minimal)
- `diablo-console` (red/blue/black enhanced style, mode lazy-load)
- `pixel-office-lite` (pixel-lite, no heavy vendor dependency)

`dev-server.sh start` now auto-refreshes asset manifests before serving UI.

Use local bridge script to update runtime feed:

```bash
cd subprojects/lobster-sanctum-ui
bash ./runtime-feed.sh executing "正在执行安装与修复任务" 46 openclaw-bridge
```
