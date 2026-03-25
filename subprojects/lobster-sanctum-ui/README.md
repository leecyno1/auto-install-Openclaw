# Lobster Sanctum Studio

`Lobster Sanctum Studio` is the standalone visual configuration project for OpenClaw.

Scope:
- UI/UX design and art polish for the 3-stage configuration flow.
- Persona selection, talent tree, armory/loadout, and build export UX.
- Visual language iteration independent from installer/config shell logic.

Out of scope:
- Installer orchestration logic in `install.sh`.
- Main CLI menu orchestration in `config-menu.sh`.

Project layout:
- `web/`: static frontend (`index.html`, `loadout.html`, `configure.html`, JS/CSS/assets).
- `dev-server.sh`: local server manager for this subproject (default `18188`).
- `SESSION.md`: dedicated session definition for UI/art-focused development.

## Start

```bash
cd subprojects/lobster-sanctum-ui
bash ./dev-server.sh start
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

- Stage I: `http://127.0.0.1:18188/index.html`
- Stage II: `http://127.0.0.1:18188/loadout.html`
- Stage III: `http://127.0.0.1:18188/configure.html`
