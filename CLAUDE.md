# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenClaw Installer is a comprehensive deployment solution for OpenClaw AI assistant infrastructure. It combines installation automation, configuration management, repair utilities, local skills repository, and a pixel-based workbench UI (Lobster Sanctum Studio) into a unified system.

**Core Purpose**: Compress OpenClaw first-time deployment into a repeatable, environment-agnostic flow that handles installation, model configuration, plugin management, skills synchronization, and configuration repair while preserving user data (memory, sessions, API keys).

## Key Commands

### Installation & Configuration

```bash
# One-click install (interactive)
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash

# Fully automated install
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash -s -- --auto-confirm-all

# Open configuration center
bash ~/.openclaw/config-menu.sh
# or
lobster-setup config

# Repair legacy configurations (preserves memory/sessions)
lobster-setup repair
bash ~/.openclaw/config-menu.sh --repair-config

# Install/repair Pixel House workbench
lobster-setup workbench
```

### Configuration Shortcuts

```bash
lobster-setup config --model-only          # Model configuration
lobster-setup config --skills-only         # Skills management
lobster-setup config --image-api-only     # Image API configuration
lobster-setup config --status-detailed    # Detailed service status
lobster-setup config --advanced-model-only # Expert model config
lobster-setup config --official-channels-only # Official channels
lobster-setup config --engine-menu        # Engine management
lobster-setup repair minimax              # Repair MiniMax config
```

### OpenClaw Gateway Management

```bash
# All commands require sourcing environment first
source ~/.openclaw/env && openclaw gateway status
source ~/.openclaw/env && openclaw doctor
source ~/.openclaw/env && openclaw health
source ~/.openclaw/env && openclaw update --restart
source ~/.openclaw/env && openclaw plugins update --all
```

### Pixel House Workbench (Lobster Sanctum Studio)

```bash
~/.openclaw/lobster-world.sh start   # Start workbench (default port 19000)
~/.openclaw/lobster-world.sh status  # Check status
~/.openclaw/lobster-world.sh stop    # Stop workbench
```

### Development & Testing

```bash
# Run preflight checks (shell lint + smoke tests + compatibility checks)
./scripts/preflight-check.sh

# Shell script linting
./scripts/lint-shell.sh

# Media quota unit tests
python3 -m unittest tests/test_media_quota.py

# Regenerate skills documentation
python3 scripts/generate_skill_guides.py

# Refresh default skills cache
python3 scripts/refresh_default_skills.py
```

## Architecture

### Repository Structure

```
.
├── install.sh              # Main installer (handles OpenClaw + deps + env setup)
├── config-menu.sh          # Interactive configuration center (482KB, handles all config flows)
├── scripts/
│   ├── lobster-world.sh    # Pixel House workbench launcher/manager
│   ├── preflight-check.sh  # CI/CD validation pipeline
│   ├── repair-pairing.sh   # Dashboard pairing repair utility
│   ├── apply-web-profile.sh # Vendor control profile injection
│   └── *.py                # Skills sync, quota management, doc generation
├── skills/default/         # Local skills repository (100+ skills)
├── plugins/official/       # Official plugin bundles (e.g., Feishu)
├── docs/                   # Configuration guides, skill references, roadmaps
├── subprojects/
│   └── lobster-sanctum-ui/ # Pixel House workbench (Flask backend + frontend)
└── tests/                  # Unit tests for quota logic and core utilities
```

### Core Components

**1. Installer (`install.sh`)**
- Detects platform (macOS/Linux), validates Node.js 22.12+
- Handles official OpenClaw installation via `openclaw.ai/install.sh` or mirrors
- Sets up `~/.openclaw/` directory structure, environment variables, default configs
- Supports both interactive and fully automated modes (`--auto-confirm-all`)
- TTY detection for pipe-safe execution (`curl | bash`)

**2. Configuration Menu (`config-menu.sh`)**
- 482KB interactive TUI for model config, plugin management, skills sync, service control
- Repair mode: cleans legacy plugin entries, fixes channel configs, preserves user data
- Handles official plugin installation with local-first fallback strategy
- Manages vendor control profiles (LOW/MEDIUM/HIGH tiers with token budgets)

**3. Skills System**
- Local repository at `skills/default/` with 100+ skills
- Three-tier installation: basic (LOW), extended (MEDIUM), super (HIGH)
- Each skill has `GUIDE.md` for usage docs and `_meta.json` for metadata
- Skills sync via `scripts/refresh_default_skills.py`

**4. Pixel House Workbench (`subprojects/lobster-sanctum-ui/`)**
- Flask backend + frontend UI (default port 19000)
- Maps OpenClaw backend state to visual workbench (characters, skills, equipment, status)
- Managed via `scripts/lobster-world.sh` with PID/log tracking

**5. Vendor Control Profiles**
- Three tiers: LOW (100 req/5h, 600K tokens), MEDIUM (300 req/5h, 2.4M tokens), HIGH (unlimited req, 6M tokens)
- Injects policies into `agents/main/soul`, `persona/`, and `~/.openclaw/policy/`
- Controls skills installation scope and API requirements (Gemini, BraveSearch, NanoBanana)

## Configuration Repair System

The repair flow (`--repair-config`) is critical for fixing historical misconfigurations:

1. **Preserves**: Memory files, session data, conversation history, API keys
2. **Cleans**: Legacy plugin entries, broken channel configs, orphaned plugin references
3. **Fixes**: `pairing required`, `plugin not found`, `unknown channel id` errors
4. **Rebuilds**: Skills cache, plugin manifests, configuration indexes

When modifying repair logic, ensure `config-menu.sh` repair functions never delete:
- `~/.openclaw/agents/main/memory/`
- `~/.openclaw/agents/main/sessions/`
- User-provided API keys in config files

## Skills Development

Skills are stored in `skills/default/<skill-name>/` with this structure:

```
skill-name/
├── GUIDE.md          # User-facing documentation (required)
├── SKILL.md          # Claude-facing instructions (required)
├── _meta.json        # Metadata (tier, API requirements, triggers)
├── scripts/          # Executable scripts (optional)
└── references/       # Additional docs (optional)
```

**Key conventions**:
- `GUIDE.md` is shown in config menu and docs
- `SKILL.md` contains Claude-specific prompts and tool usage
- `_meta.json` defines installation tier and dependencies
- Skills must be idempotent and handle missing dependencies gracefully

## Testing & Validation

**Preflight checks** (`scripts/preflight-check.sh`) validate:
1. Shell syntax via `shellcheck`
2. Install script smoke tests (`--help` flag parsing)
3. Media quota unit tests
4. Official upgrade command presence in config menu
5. Feishu plugin default markers
6. Installer compatibility flags (Node version, mirror support)
7. README command consistency
8. No legacy repository references (old upstream URLs)

**Before committing**:
- Run `./scripts/preflight-check.sh` to catch regressions
- Test install flow in clean environment if modifying `install.sh`
- Verify config menu changes with `bash config-menu.sh --help`

## Important Constraints

**Security**:
- Never commit API keys, tokens, or credentials
- Installer must validate all external downloads (checksums when available)
- Config repair must preserve user secrets while cleaning broken configs

**Compatibility**:
- Maintain official OpenClaw installer compatibility (use `openclaw.ai/install.sh` as source of truth)
- Support both GitHub and Gitee mirrors for China accessibility
- Handle TTY/non-TTY contexts (pipe-safe execution)
- Node.js 22.12+ is minimum requirement

**Naming**:
- Repository renamed from `miaoxworld/OpenClawInstaller` to `leecyno1/auto-install-Openclaw`
- Never reference old repository URLs in code or docs
- Use `OpenClaw` (capital C) in user-facing text, `openclaw` in commands/paths

## Default Ports

- OpenClaw Gateway: `127.0.0.1:13145` (localhost-only for security)
- Health Check Server: `127.0.0.1:13146` (monitors gateway and workbench)
- Quota Enforcer: `127.0.0.1:13147` (media generation quota enforcement)
- Pixel House Workbench: `127.0.0.1:19000` (configurable via `STAR_BACKEND_PORT`)

## Documentation

Key docs in `docs/`:
- `skills-guides.md`: Complete skills matrix with API requirements
- `vendor-control-profiles.md`: Token budget and tier rules
- `channels-configuration-guide.md`: Channel setup (Feishu, Slack, etc.)
- `feishu-setup.md`: Feishu plugin configuration walkthrough
- `persona-roles.md`: Persona system design and injection rules

## Common Workflows

**Adding a new skill**:
1. Create `skills/default/<name>/` with `GUIDE.md` + `SKILL.md` + `_meta.json`
2. Update `skills/default/DEFAULT_SKILLS.md` with one-line description
3. Run `python3 scripts/generate_skill_guides.py` to regenerate docs
4. Test installation via config menu skills sync

**Modifying installer**:
1. Edit `install.sh` with changes
2. Update version in `INSTALLER_VERSION` variable
3. Run `./scripts/preflight-check.sh` to validate
4. Test in clean environment (Docker or fresh VM)
5. Update `README.md` if user-facing behavior changes

**Fixing configuration issues**:
1. Identify broken config pattern (e.g., legacy plugin entry)
2. Add repair logic to `config-menu.sh` repair functions
3. Test with `bash config-menu.sh --repair-config` on affected system
4. Verify user data (memory/sessions) preserved after repair
