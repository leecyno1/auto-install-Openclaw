# Progress Log

## 2026-04-15
- Initialized planning files for dual-engine implementation.
- Added Lobster shared control-layer helpers in scripts/lib/openclaw-common.sh.
- Extended install.sh with --engine support, Hermes install path, lobster-setup/openclaw-setup launcher generation, separate Lobster state persistence, and split OpenClaw/Hermes flow.
- Extended config-menu.sh with Hermes-aware engine management, status/doctor/migration/install actions, and --engine-menu shortcut.
- Added Lobster shared input sync: `~/.lobster/config/shared.env` plus derived `~/.hermes/.env` generation.
- Hooked shared sync into installer identity/rule/image flows and config-menu identity/rule/provider/image flows.
- Added Hermes role/profile mapping artifacts: `~/.hermes/lobster-profile.env` and `~/.hermes/lobster-profile.md`.
- Mapped 7 roles to stable Hermes profile hints (primary model, secondary model, toolset hint, skill focus) and propagated role skill lists into the profile artifact.
- Switched Hermes mapping from passive profile hints to active CLI application: `openclaw_sync_dual_engine_state` now runs `hermes config set` plus `hermes tools enable/disable --platform cli` when Hermes is available.
- Added Lobster-managed Hermes toolset mapping for the 7 roles and rule-profile mapping for delegation reasoning, delegation iteration budget, and agent max turns.
- Added safe Hermes persistence keys under `lobster.*` so role/profile metadata is written into `~/.hermes/config.yaml` without guessing unsupported upstream schema.
- Wired explicit menu action to re-apply Hermes role/rule/tool mapping after install or later config changes.
- Verified with a mock-Hermes smoke test that sync executes real CLI commands instead of only generating profile files.
- Extended the shared Lobster env to carry resolved skill-pack metadata, request/token quotas, media quotas, and context-guard thresholds.
- Added Hermes-side compatibility outputs:
  - `~/.hermes/lobster-profile.env`
  - `~/.hermes/lobster-profile.md`
  - `~/.hermes/lobster-runtime.env`
- Extended Hermes CLI apply flow to persist these values under `lobster.rate.*`, `lobster.media.*`, `lobster.context.*`, `lobster.image.*`, and `lobster.skill_*`.
- Updated OpenClaw installer/menu skill-pack application to export the resolved skill list, skill count, and human-readable pack label into env before shared sync.
- Added Hermes skill bridge: installed skills under `~/.openclaw/skills` are now exposed into `~/.hermes/skills` as managed symlinks, without duplicating skill content.
- Verified with an additional smoke test that `openclaw_sync_dual_engine_state` creates Hermes skill links correctly and keeps runtime/config sync intact.
- Updated scripts/preflight-check.sh with dual-engine and Hermes-profile regression markers.
- Verified with bash -n and ./scripts/preflight-check.sh.

## 2026-04-17 MiniMax / API / Menu Work
- Merged 17 official MiniMax-AI skills into skills/default.
- Added MINIMAX_OFFICIAL_SKILLS/MINIMAX_SKILLS to install.sh and config-menu.sh skill packs.
- Defined DEFAULT_SKILLS_BUNDLE_SENTINELS in install.sh and expanded menu sentinels to include official MiniMax skills.
- Replaced advanced settings item 12 from expert model config to image generation API config.
- Updated script color variables toward red-blue theme.
- Added preflight checks for MiniMax official skills and raw custom provider URL preservation.

## 2026-04-17 Config Surface Hardening
- Added tests/test_config_surface.py to cover MiniMax provider URL behavior, image API URL splitting, official MiniMax skill presence, and advanced menu de-duplication.
- Removed the dead expert-model menu function from config-menu.sh after confirming the new regression test failed on the stale entry.
- Removed remaining OPENCLAW_EXPERT_* fallback dependencies from the visible advanced model path.
- Added config surface unit tests to scripts/preflight-check.sh.
- Verified bash syntax, media quota tests, config surface tests, and full preflight.

## 2026-04-17 Skills Catalog Hardening
- Added `skills/manifest.json` as an installer-facing catalog generated from local `skills/default/*/SKILL.md`, including tiers, groups, real descriptions, source tags, and API-key hints.
- Added `scripts/lib/skills.sh` to read bundle membership from the manifest and expose reusable shell helpers for default sentinels and tier/group lookups.
- Updated `install.sh` and `config-menu.sh` to prefer manifest-driven skill lists for MiniMax bundles, basic/extended/super tiers, and sentinel detection while keeping existing hardcoded shell lists as fallback.
- Added `tests/test_skills_manifest.py` to prevent future drift between local skills, bundle tiers, MiniMax official skills, and script integration points.
- Added `tests/test_dual_engine_smoke.py` to validate isolated HOME shared-state generation, raw MiniMax provider URL propagation, and Hermes skill symlink bridging.
- Fixed a silent `set -e` breakage in `openclaw_read_shell_kv_value()` so missing env keys no longer abort dual-engine sync/apply flows.
- Extended `scripts/preflight-check.sh` to include the new manifest and dual-engine smoke tests; full preflight now passes.
- Added `scripts/generate_skills_manifest.py` so the manifest is reproducible and checked in CI/release flow instead of hand-maintained.
- Added `scripts/release-check.sh` to run manifest freshness, full preflight, and a focused secret scan over release-facing files.
- Extended the manifest with `menu_enhanced` and `baoyu` group outputs so `config-menu.sh` no longer needs a separately drifting enhanced/super skill source list.
