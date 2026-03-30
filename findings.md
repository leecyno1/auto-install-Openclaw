# Findings

- The pixel house is still the richest interactive surface, but it currently only models runtime state and decoration.
- The persona/loadout/configure flow in `subprojects/lobster-sanctum-ui/web/` was split into a separate static app, which demoted the room to a secondary surface.
- `vendor/star-office-ui/backend/app.py` already serves the room and is the correct place to mount same-origin workbench routes.
- `vendor/star-office-ui/frontend/index.html` already has a control bar and drawer system, so a room-native workbench modal can be integrated without rebuilding the scene engine.
- Lazy iframe loading is the lowest-risk way to embed existing pages while keeping the room process lightweight.
- 2026-03-30: The seven-role source set already contains 118 distinct action sequences; no new source extraction was required.
- 2026-03-30: Added a second asset layer under `materials/character-library/seven-multi-action-v1-compressed/` so all actions are reserved locally in compressed form while runtime still loads only four mapped states.
