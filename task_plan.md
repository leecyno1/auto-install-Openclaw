# Task Plan

## Goal

Re-center the OpenClaw game experience around the pixel house as the primary world scene, and embed existing persona/loadout/configuration pages as room-native workbench interfaces instead of separate primary pages.

## Phases

| Phase | Status | Notes |
|---|---|---|
| Audit current pixel-house runtime, event model, and detached config pages | completed | Confirmed the room/runtime and config UI had become parallel systems |
| Write integration design for room-as-base architecture | completed | Design doc added under `docs/plans/2026-03-26-pixel-house-workbench-design.md` |
| Implement first room-native workbench integration | completed | Added same-origin workbench routes and in-room modal launcher |
| Verify behavior and resource impact | completed | Verified Python/JS syntax, backend routes, and browser-level modal loading |

## Risks

- Vendor `star-office-ui/frontend/index.html` is large and contains inline logic, so edits must be surgical.
- Existing config pages assume static hosting from `18188`; same-origin serving must be added to the pixel-house backend.
- The room must remain lightweight at idle, so workbench content should load lazily.
