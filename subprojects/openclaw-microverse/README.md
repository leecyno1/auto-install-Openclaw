# OpenClaw Microverse

Microverse/Godot-based replacement frontend for OpenClaw world visualization.

## Scope of this phase

- `Home Base` single-base closed loop
- six in-world stations
- role / skill / equipment / task / status / portal semantics
- `world-gateway` remains the only OpenClaw adapter
- browser runtime through Godot Web export

## Project layout

- `project.godot`: Godot project root
- `scenes/`: main scenes for Home Base and Shared World shell
- `scripts/`: gateway client, state store, and UI/world controllers
- `assets/`: minimal subset copied from Microverse for phase 1
- `scripts/export-web.sh`: exports Web build for gateway serving

## Export

```bash
cd /Volumes/PSSD/Projects/OpenClawInstaller/subprojects/openclaw-microverse
./scripts/install-web-templates.sh /path/to/Godot_v4.6.2-stable_export_templates.tpz
./scripts/export-web.sh
```

The export target is `build/web/index.html` by default.

`WorldGatewayClient.gd` defaults to same-origin gateway access when running in the browser.
You can override this with either:

- query string: `?gateway=https://your-host:19200`
- global JS: `window.OPENCLAW_WORLD_BASE_URL`
- environment variable during native debugging: `OPENCLAW_WORLD_BASE_URL`

## Gateway serving

Point `OPENCLAW_WORLD_PUBLIC_DIR` to the exported web directory when starting the existing gateway.
