# Lobster Runtime Four-Stage Roadmap

## Stage 1 - Projection API Foundation (Done)

Goal:
- Build a lightweight projection backend independent from heavy UI assets.

Delivered:
- `subprojects/lobster-sanctum-ui/projection-api/server.py`
- `subprojects/lobster-sanctum-ui/projection-api.sh`
- `subprojects/lobster-sanctum-ui/projection-push.sh`
- Runtime adapter default switched to `projection-api` profile.

Endpoints:
- `GET /health`
- `GET /runtime/state`
- `POST /runtime/state`
- `GET /runtime/events`
- `POST /runtime/events`
- `GET /runtime/stream` (SSE)

## Stage 2 - Runtime State Mapping and Event Semantics (Done)

Goal:
- Normalize OpenClaw execution lifecycle into stable runtime phases.

Plan:
- Add structured event schema (`task_id`, `phase`, `tool`, `model`, `latency`, `error_code`).
- Add mapper from raw OpenClaw status/logs to projection state/events.
- Add idempotency strategy for duplicate events.

Delivered (current round):
- `projection-api/server.py` upgraded to V2 with structured event fields.
- Added `POST /runtime/ingest` raw payload mapping endpoint.
- Added event signature de-dup and TTL-based idempotency.
- Added incremental pull support (`GET /runtime/events?since_id=...`).
- Added stream resume support (`Last-Event-ID` / `since_id`).
- Added OpenClaw bridge manager:
  - `subprojects/lobster-sanctum-ui/openclaw-runtime-bridge.sh`

## Stage 3 - Multi-Agent Presence and Collaboration Runtime (Done)

Goal:
- Represent multiple Lobsters in one world with role-based activity.

Plan:
- Add `/runtime/agents` and `/runtime/agents/stream`.
- Support agent join/leave/heartbeat and per-agent state.
- Add team task board and shared mission progress.

Delivered (current round):
- Added `/runtime/agents` (GET/POST) with agent heartbeat/upsert model.
- Added `/runtime/agents/stream` SSE for collaboration presence updates.
- Added `/runtime/missions` (GET/POST) mission board and progress summary.
- Runtime page wired to show:
  - online/offline squad list
  - mission board (running/blocked/done counters)
  - SSE realtime transport status with polling fallback

## Stage 4 - Asset and Rendering Decoupling (Done)

Goal:
- Keep runtime responsive while supporting richer art and scenes.

Plan:
- Split asset packs by theme/profile and lazy-load by runtime mode.
- Keep runtime core independent from large vendor assets.
- Add build pipeline for asset optimization and cache manifests.

Delivered (current round):
- Added decoupled runtime asset system under `web/runtime-assets/`.
- Added pack descriptors (`pack.json`) + generated per-pack `cache-manifest.json`.
- Added global manifest build pipeline:
  - `subprojects/lobster-sanctum-ui/scripts/build-runtime-assets.py`
  - `subprojects/lobster-sanctum-ui/build-runtime-assets.sh`
- Runtime UI now supports:
  - asset pack selection from manifest
  - lazy asset load by runtime mode (`researching/writing/executing/syncing/error`)
  - body-class theme isolation to avoid cross-pack style pollution
- `dev-server.sh` now auto-refreshes runtime asset manifests before startup.
