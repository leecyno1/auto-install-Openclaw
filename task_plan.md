# Hermes Dual-Engine Integration Plan

## Goal
Implement dual-engine installer/config support for OpenClaw and Hermes while keeping OpenClaw as default, Hermes optional, runtime directories separate, and pixel house OpenClaw-only.

## Phases
- [completed] Phase 1: Inspect current installer/config architecture and identify insertion points.
- [completed] Phase 2: Add Lobster shared control-layer helpers in scripts/lib/openclaw-common.sh.
- [completed] Phase 3: Extend install.sh with engine selection, Hermes install path, shared launcher, and success output.
- [completed] Phase 4: Extend config-menu.sh with engine management and Hermes status/migration/install entry points.
- [completed] Phase 5: Add shared-input mapping into Lobster control state and generate Hermes .env from common values.
- [completed] Phase 6: Add/adjust validation coverage and run syntax/lint/preflight verification.
- [completed] Phase 7: Apply Hermes CLI mapping for role/rule/tool semantics via `hermes config set` and `hermes tools enable/disable`.
- [completed] Phase 8: Add Hermes compatibility layer for shared skill-pack, quota, context-guard, and image-generation semantics.
- [completed] Phase 9: Bridge Lobster/OpenClaw local skills into Hermes via managed symlinks under `~/.hermes/skills`.
- [pending] Phase 10: Validate real Hermes sessions can discover and invoke bridged skills end-to-end on a live install.

## Constraints
- Keep OpenClaw default.
- Keep runtime dirs separate: ~/.openclaw and ~/.hermes.
- No automatic migration.
- Pixel house remains OpenClaw-only.
- Do not revert unrelated dirty worktree changes.

## Errors Encountered
- Local env-derivation smoke test inherited existing exported variables; future isolated tests should use a cleaner environment when validating precedence.
- Hermes `model` command is TTY-only, so automatic model switching must avoid it and use `config set` / explicit delegation routing instead.

- [completed] Phase 11: Integrate official MiniMax skills, de-duplicate advanced/expert model menu, preserve raw custom provider URLs, and verify installer scripts.
- [completed] Phase 12: Add manifest-driven skills catalog, shared shell reader, isolated dual-engine smoke coverage, and fix silent shared-env sync exits.
- [completed] Phase 13: Add manifest generator, release-check pipeline, and manifest-backed menu-enhanced skill grouping.
