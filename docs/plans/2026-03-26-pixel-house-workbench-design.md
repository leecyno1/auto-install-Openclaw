# Pixel House Workbench Design

## Goal

Restore the pixel house as the primary game world for OpenClaw. The room is the player's home base and birth place. Persona switching, skill tree, equipment, status, task list, and future world travel should all be entered from this room instead of replacing it with detached configuration pages.

## What Went Wrong

The previous split created two parallel products:

- `vendor/star-office-ui/` remained the room runtime and state projection world.
- `web/` became a separate configuration site for persona, loadout, and command center.

That split broke the intended game fantasy. The room stopped being the world base and became only a visual monitor. The real control surface moved elsewhere, so the house lost authority and interaction density.

## Recovery Direction

Use the room as the only primary entry surface.

- Keep Phaser room rendering and movement in the Star Office runtime.
- Keep existing persona/loadout/configure pages for now, but stop presenting them as the main app.
- Serve those pages from the room backend under the same origin.
- Open them lazily as a room-native workbench overlay.

This gives a low-risk recovery path:

- No full rewrite of the room engine.
- No duplicate host/port dependency for normal use.
- Existing role/skill/equipment logic remains reusable.
- Room stays lightweight because the workbench iframe is created only when opened and released when closed.

## First Version

### In-room workbench

Add a modal workbench layer on top of the pixel room.

- `转职业` -> `/workbench/index.html`
- `技能树` -> `/workbench/loadout.html`
- `装备物品` -> `/workbench/configure.html?tab=equipment`
- `状态页` -> `/workbench/configure.html?tab=status`
- `任务页` -> `/workbench/configure.html?tab=tasks`

### Same-origin serving

Mount `subprojects/lobster-sanctum-ui/web/` into the room backend:

- `/workbench/...`

This preserves localStorage access for persona role state and avoids cross-origin iframe issues.

### Room object mapping

Bind core room objects to workbench entry points:

- plaque / poster -> role switching
- desk -> skill tree
- server room -> status
- coffee machine -> tasks

This is enough to make the house feel operational again without rebuilding every asset.

## Performance Strategy

Keep the room cheap at idle.

- Keep Phaser and current pixel asset pipeline.
- Do not pre-load the workbench pages.
- Load workbench iframe only on demand.
- Clear iframe back to `about:blank` when closed.
- Reuse the existing Flask backend instead of running a second mandatory config server.

This is materially better than moving the whole experience to a heavy SPA.

## Next Stages

### Stage 2

Replace the bottom control bar with a more diegetic house HUD:

- character sheet
- inventory bag
- quest log
- status codex
- class altar

### Stage 3

Expand the room size and support house upgrades:

- more rooms
- equipment wall
- mission board
- archive shelf
- party portal to future public world

### Stage 4

Unify state, projection, and build configuration into one game schema so the room, workbench, and future public world all read the same player profile.
