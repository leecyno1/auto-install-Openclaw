# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenClaw Installer is a modular deployment solution for OpenClaw AI assistant infrastructure. **v2.0 introduces a complete architectural refactor**: installation and configuration are fully decoupled, with independent modules for Skills, tier rules, Pixel House, and API configuration.

**Core Purpose**: Provide a minimal installer that delegates to the official OpenClaw installation, plus independent configuration modules for custom features (Skills management, quota enforcement, Pixel House workbench, API endpoint replacement).

## Key Commands

### Installation

```bash
# One-click install (minimal mode)
curl -fsSL https://gitee.com/leecyno1/auto-install-openclaw/raw/main/install.sh | bash

# GitHub direct
curl -fsSL https://raw.githubusercontent.com/leecyno1/auto-install-Openclaw/main/install.sh | bash
```

### Configuration Modules

```bash
# Interactive menu
openclaw-setup config

# Skills management
openclaw-setup config skills --tier basic      # ~60 skills
openclaw-setup config skills --tier extended   # ~80 skills
openclaw-setup config skills --tier super      # ~100+ skills

# Tier rules configuration
openclaw-setup config tier-rules --level low       # 100 req/5h
openclaw-setup config tier-rules --level medium    # 300 req/5h
openclaw-setup config tier-rules --level high      # unlimited
openclaw-setup config tier-rules --with-monitoring # start gateway proxy

# Pixel House workbench
openclaw-setup config pixel-house --install
openclaw-setup config pixel-house --start
openclaw-setup config pixel-house --status

# API configuration (replace hardcoded URLs in skills)
openclaw-setup config api --show
openclaw-setup config api --replace-service nanobanana --with https://my-service.com/api
openclaw-setup config api --replace-service gemini --with https://my-gemini-proxy.com/v1

# Dashboard pairing fix (fix "pairing required" errors)
openclaw-setup config dashboard-pairing --fix
openclaw-setup config dashboard-pairing --show

# Migration from old version
openclaw-setup config migrate
```

### OpenClaw Gateway Management

```bash
source ~/.openclaw/env && openclaw gateway start
source ~/.openclaw/env && openclaw gateway status
source ~/.openclaw/env && openclaw doctor
source ~/.openclaw/env && openclaw health
```

### Development & Testing

```bash
# Run preflight checks
./scripts/preflight-check.sh

# Shell script linting
./scripts/lint-shell.sh

# Media quota unit tests
python3 -m unittest tests/test_media_quota.py
```

## Architecture (v2.0 Modular)

### Design Principles

1. **Minimal Installer**: `install.sh` (~250 lines) only handles environment detection and official installer invocation
2. **Independent Modules**: Skills, tier rules, Pixel House, and API config are separate scripts in `scripts/modules/`
3. **No Duplication**: Removed features that duplicate official OpenClaw CLI (model config, channel management, status monitoring)
4. **Flexible Replacement**: Support replacing hardcoded third-party service URLs in skills
5. **Hybrid Strategy**: Basic skills from local repo (fast), extended skills from official source (up-to-date)
6. **Data Safety**: All modifications create backups, support rollback

### Repository Structure

```
.
├── install.sh                          # Minimal installer (~250 lines)
├── openclaw-setup.sh                   # Unified configuration entry point
├── config-menu.sh.deprecated           # Old monolithic config (archived)
├── scripts/
│   ├── modules/                        # Independent configuration modules
│   │   ├── skills.sh                   # Skills management (~389 lines)
│   │   ├── tier-rules.sh               # Tier rules config (~420 lines)
│   │   ├── pixel-house.sh              # Pixel House management (~406 lines)
│   │   ├── api-config.sh               # API configuration (~413 lines)
│   │   └── api_replacer.py             # URL replacement tool (~335 lines)
│   ├── migrate-to-modular.sh           # Migration wizard (~399 lines)
│   ├── lobster-world.sh                # Pixel House launcher
│   ├── apply-web-profile.sh            # Vendor control profile injection
│   └── *.py                            # Skills sync, quota management, etc.
├── skills/default/                     # Local skills repository (100+ skills)
├── docs/                               # Documentation
├── subprojects/
│   └── lobster-sanctum-ui/             # Pixel House workbench (Flask backend)
└── tests/                              # Unit tests
```

### Core Components

**1. Minimal Installer (`install.sh`)**
- ~250 lines (simplified from 439 lines)
- Environment detection (OS, Node.js 22.12+, required commands)
- Delegates to official OpenClaw installer (`openclaw.ai/install.sh`)
- Applies basic patches (Feishu cleanup)
- Shows next steps guide for module configuration
- TTY detection for pipe-safe execution

**2. Skills Module (`scripts/modules/skills.sh`)**
- Hybrid installation strategy: basic skills from local repo, extended from official source
- Three tiers: basic (~60), extended (~80), super (~100+)
- Uses `skills/manifest.json` as single source of truth
- Automatic fallback to local repo if official source fails
- CLI: `openclaw-setup config skills --tier <basic|extended|super>`

**3. Tier Rules Module (`scripts/modules/tier-rules.sh`)**
- Four quota levels: none (unlimited), low (100 req/5h), medium (300 req/5h), high (unlimited req)
- Configures request limits, token budgets, image/video quotas
- Optional gateway monitoring proxy (port 13147)
- Bash version detection for macOS compatibility (3.2 vs 5.3)
- CLI: `openclaw-setup config tier-rules --level <low|medium|high|none>`

**4. Pixel House Module (`scripts/modules/pixel-house.sh`)**
- Independent deployment of Pixel House workbench
- Flask backend + frontend UI (default port 19000)
- Python dependency management (virtual environment)
- Lifecycle management (install/start/stop/status)
- CLI: `openclaw-setup config pixel-house --install|--start|--stop|--status`

**5. API Configuration Module (`scripts/modules/api-config.sh` + `api_replacer.py`)**
- Replaces hardcoded third-party service URLs in skills
- Supports: NanoBanana, Gemini, OpenAI, MiniMax, Replicate
- Scans multiple file types (.py, .js, .sh, .ts, .tsx, .jsx)
- Uses `~/.openclaw/api-overrides.json` for service mappings
- Smart backup: creates one backup per hour (not per file) to avoid slowdown
- CLI: `openclaw-setup config api --replace-service <name> --with <url>`

**6. Migration Tool (`scripts/migrate-to-modular.sh`)**
- Migrates from old monolithic config-menu.sh to new modular architecture
- Extracts existing configuration (Skills tier, tier rules, API config)
- Preserves user data (memory, sessions, API keys)
- Creates backup before migration, supports rollback
- CLI: `openclaw-setup config migrate`

**7. Unified Entry Point (`openclaw-setup.sh`)**
- Routes commands to appropriate modules
- Provides interactive configuration menu
- Backward compatibility with old command patterns
- CLI: `openclaw-setup config [module] [options]`

**8. Dashboard Pairing Fix Module (`scripts/modules/dashboard-pairing.sh`)**
- Fixes "pairing required" errors in Dashboard
- Configures gateway.controlUi.allowedOrigins
- Disables device authentication for embedded/proxy scenarios
- Automatically restarts Gateway to apply changes
- CLI: `openclaw-setup config dashboard-pairing --fix`

## Tier Rules Configuration

Four quota levels with different limits:

| Level | Requests | Tokens | Images | Videos | Use Case |
|-------|----------|--------|--------|--------|----------|
| none | unlimited | unlimited | unlimited | unlimited | No restrictions |
| low | 100/5h | 600K | 0 | 0 | Basic deployment |
| medium | 300/5h | 2.4M | 20 | 1 | Default config |
| high | unlimited | 6M | 50 | 2 | High quota |

Configuration is stored in:
- `~/.openclaw/env` - Environment variables
- `~/.openclaw/profile/web-config-profile.json` - Web profile
- Applied via `scripts/apply-web-profile.sh`

Optional gateway monitoring proxy runs on port 13147 to enforce quotas at the gateway level.

## API Configuration & URL Replacement

The API configuration module allows replacing hardcoded third-party service URLs in skills that don't provide URL configuration options.

**Supported services:**
- NanoBanana (image generation)
- Gemini (Google AI)
- OpenAI (GPT models)
- MiniMax (Chinese AI)
- Replicate (model hosting)

**Configuration file:** `~/.openclaw/api-overrides.json`

```json
{
  "nanobanana": {
    "original": "https://api.nanobanana.com",
    "replacement": "https://my-custom-service.com/api"
  },
  "gemini": {
    "original": "https://generativelanguage.googleapis.com",
    "replacement": "https://my-gemini-proxy.com/v1"
  }
}
```

The `api_replacer.py` script scans all skills and replaces URLs using regex patterns, backing up files before modification.

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
- Smart backup strategy: one backup per hour instead of per-file to avoid slowdown
- Migration tool preserves user data (memory, sessions, API keys)

**Compatibility**:
- Maintain official OpenClaw installer compatibility (use `openclaw.ai/install.sh` as source of truth)
- Support both GitHub and Gitee mirrors for China accessibility
- Handle TTY/non-TTY contexts (pipe-safe execution)
- Node.js 22.12+ is minimum requirement
- Bash version compatibility: detect and use homebrew bash 5.3+ on macOS (system bash is 3.2)

**Modular Architecture**:
- Each module must be independently executable
- Modules should not depend on each other (except via shared utilities)
- All modules must support `--help` flag
- Configuration changes should be idempotent
- Always provide dry-run mode for destructive operations

**Naming**:
- Repository: `leecyno1/auto-install-Openclaw`
- Main command: `openclaw-setup` (not `lobster-setup`)
- Use `OpenClaw` (capital C) in user-facing text, `openclaw` in commands/paths
- Old `config-menu.sh` is archived as `config-menu.sh.deprecated`

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

**Installing from scratch**:
1. Run minimal installer: `curl -fsSL https://gitee.com/.../install.sh | bash`
2. Configure skills: `openclaw-setup config skills --tier basic`
3. Configure tier rules: `openclaw-setup config tier-rules --level medium`
4. Install Pixel House: `openclaw-setup config pixel-house --install`
5. Start services: `openclaw-setup config pixel-house --start`

**Migrating from old version**:
1. Run migration wizard: `openclaw-setup config migrate`
2. Verify configuration: `openclaw-setup config skills --list`
3. Check tier rules: `openclaw-setup config tier-rules --show`
4. Test Pixel House: `openclaw-setup config pixel-house --status`

**Replacing hardcoded service URLs**:
1. Check current config: `openclaw-setup config api --show`
2. Replace service URL: `openclaw-setup config api --replace-service nanobanana --with https://my-service.com/api`
3. Verify changes: `grep -r "my-service.com" ~/.openclaw/skills/`
4. Rollback if needed: `openclaw-setup config api --rollback`

**Adding a new skill**:
1. Create `skills/default/<name>/` with `GUIDE.md` + `SKILL.md` + `_meta.json`
2. Update `skills/default/DEFAULT_SKILLS.md` with one-line description
3. Run `python3 scripts/generate_skill_guides.py` to regenerate docs
4. Test installation: `openclaw-setup config skills --tier basic`

**Modifying a module**:
1. Edit module script in `scripts/modules/`
2. Test module directly: `bash scripts/modules/<module>.sh --help`
3. Test via entry point: `openclaw-setup config <module> --help`
4. Update documentation if user-facing behavior changes
