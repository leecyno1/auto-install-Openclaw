# Findings

## 2026-04-15
- Shared helper library initially only contained OpenClaw-specific normalization helpers.
- install.sh main anchors: print_usage, parse_args, create_directories, install_config_menu_launcher, main.
- config-menu.sh main anchors: get_env_value, check_openclaw_installed, show_main_menu, main.
- Hermes upstream exposes install script, CLI status/doctor, and optional claw migration.
- Hermes `.env.example` supports key env vars needed for first-pass mapping: OpenAI, OpenRouter, Google/Gemini, MiniMax, Exa, Parallel, Firecrawl, FAL.
- Hermes `config.py` confirms `hermes config set` accepts arbitrary dotted keys, writes `_API_KEY`/`_TOKEN`-style keys into `~/.hermes/.env`, and writes other keys into `~/.hermes/config.yaml`.
- Hermes `tools_config.py` confirms non-interactive `hermes tools enable|disable ... --platform cli` is stable for built-in toolsets and better suited than trying to automate the interactive setup UI.
- Hermes `model` command remains interactive/TTY-bound, so automatic role application should not depend on it.
- OpenClaw already materializes the real rule profile into env (`OPENCLAW_RULE_MAX_*`, `OPENCLAW_CONTEXT_*`) and can therefore expose a stable engine-neutral compatibility manifest without re-parsing markdown policy files.
- The safest Hermes bridge for shared skill semantics is not “install all OpenClaw skills into Hermes automatically”, but to sync the resolved skill-pack manifest and let later Hermes-specific consumers decide how to use it.
- Hermes skill discovery reads from the local Hermes skills dir first, so symlinking installed OpenClaw skills into `~/.hermes/skills` is a lower-risk sharing strategy than trying to mutate `skills.external_dirs` in YAML.
- The repo already centralizes most user-facing config writes into OpenClaw env + menu save points, making a Lobster shared-env derivation layer the lowest-risk integration path.

## 2026-04-17 MiniMax / API / Menu Retrying Fixes
- Root cause: config menu exposed both advanced model and expert model as separate entries even though both configure complex-model routing; image generation API had a separate less-visible entry.
- Root cause: install.sh referenced DEFAULT_SKILLS_BUNDLE_SENTINELS but did not define it, which can break default skill bundle detection under set -u.
- MiniMax official skills were cloned under /tmp/minimax-skills.ocQkAn and merged into skills/default.
- API probe: https://api.sfkey.cn/v1/messages returned HTTP 200 using Anthropic messages with model MiniMax-M2.7-highspeed; config should still store raw provider root URL as entered.

## 2026-04-17 Config Surface Hardening Findings
- The old expert-model menu function remained in config-menu.sh even after the menu item was replaced, making future maintenance ambiguous.
- TDD regression confirmed the stale function was still present; after deleting it, config surface tests pass.
- OpenClaw provider URL handling and image endpoint splitting are now covered by unit tests instead of only grep markers.

## 2026-04-17 Skills Catalog / Sync Findings
- The installer and config menu still maintained overlapping hardcoded skill lists, which made MiniMax additions and package-tier updates fragile and drift-prone.
- A lightweight manifest plus shell reader is the lowest-risk next step: it centralizes bundle membership without forcing a full installer rewrite.
- `openclaw_read_shell_kv_value()` previously propagated `grep` exit code 1 under `set -e`, causing missing optional env keys to abort dual-engine sync with no useful output; this could surface as random save/apply failures.
- Isolated HOME smoke coverage is necessary because many installer regressions only appear when no pre-existing `~/.openclaw` / `~/.hermes` state is present.
- Release-time secret scanning must target release-facing files, not the whole repo, otherwise tests/examples/reference docs create too much noise and hide real problems.
- `config-menu.sh` had a second, menu-specific “enhanced skills” universe that diverged from the basic/extended/super installer tiers; manifest-level `menu_enhanced` is a safer bridge than leaving that list hardcoded forever.
