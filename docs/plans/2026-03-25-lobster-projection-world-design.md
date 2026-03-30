# Lobster Projection World - Initial Design

## Goal

Turn `Lobster Sanctum Studio` from a static configuration frontend into a game-like projection world for OpenClaw. The frontend should not only let the user choose a persona, install skills, and equip tools; it should also visualize what the running Lobster is doing in real time.

The imported `Star-Office-UI` provides a strong world baseline: a pixel room, state-driven movement, multi-agent presence, and a lightweight runtime model. The existing `Lobster Sanctum Studio` already provides the build layer: persona selection, skill package selection, equipment mapping, token rules, and gameified loadout UX.

The right direction is not replacement. It is a layered merge.

## Recommended Product Structure

Use a three-layer architecture.

1. Build Layer
   The current `index.html`, `loadout.html`, and `configure.html` remain the place where the user defines the Lobster build: persona, skill packs, equipped tools, routing, token rules, and security posture.

2. World Layer
   Derive a Lobster-specific pixel scene from `Star-Office-UI`. The room becomes the Lobster habitat and command space. Furniture, stations, doors, mission boards, terminals, and workshop objects represent functional zones.

3. Projection Layer
   Runtime events from OpenClaw map into the world layer. Searching, coding, writing, syncing, waiting, failing, recovering, and collaborating should move the Lobster avatar through the world and update world objects.

## Core Mapping

The earlier “Diablo-like” pages should not be discarded. They become the character build system behind the world.

- Persona page maps to class selection.
- Skill tree maps to unlocked ability graph.
- Equipment page maps to model / API / MCP / tool loadout.
- Status page maps to live stats, token posture, cooldowns, and risk controls.
- Task and level pages map to mission history, XP, success rate, and rank progression.

The pixel world then becomes the live embodiment of that build.

Example mappings:

- `researching` moves the Lobster to the archive desk or intel shelf.
- `writing` moves the Lobster to the drafting console.
- `executing` moves the Lobster to the forge / terminal.
- `syncing` moves the Lobster to the gateway uplink.
- `error` moves the Lobster to the repair pit or bug ward.
- `idle` returns the Lobster to lounge / observation mode.

## Game Systems

The world should expose five game systems.

1. Avatar System
   A single Lobster avatar with class skin, idle state, working state, and special action animations. Persona changes alter outfit, props, room highlights, and recommended stations.

2. Build System
   Skills are abilities, tools are equipment, models are core weapons or relics, APIs are network organs, MCPs are instruments, automation is summon or companion behavior.

3. Room System
   The house is not decoration only. Each room segment is an operational surface:
   command desk, memory archive, image studio, market board, automation altar, collaboration table, and vault.

4. Mission System
   Running tasks appear as active contracts. Completed tasks become trophies, logs, or memoir cards in the room.

5. Party System
   Multiple Lobsters should appear as a team in the same shared office. This is the basis for future collaborative writing and multi-agent execution. Each Lobster has its own build, current task, and presence indicator.

## Data Model

Use separate but connected state domains.

- `build_state`: persona, installed skills, equipped tools, rules, model routes, presets.
- `runtime_state`: current task, phase, detail text, progress, heartbeat, errors, active tool/model.
- `world_state`: room theme, furniture unlocks, decorations, placed objects, trophies, unlocked stations.
- `party_state`: other Lobsters, their roles, tasks, statuses, and permissions.

This separation matters. Build data changes slowly. Runtime data changes fast. World data changes over time. Party data is session-scoped and networked.

## Technical Recommendation

Near term, keep `vendor/star-office-ui/` as an upstream reference and do not heavily mutate it in place. Build a Lobster-specific runtime derived from it inside this subproject.

Recommended path:

1. Preserve current `web/` as the build chamber.
2. Extract a new runtime target from the imported pixel-office code.
3. Define an adapter that converts OpenClaw state into the runtime state model.
4. Add cross-links so build choices affect avatar skin, room props, and world behavior.
5. Introduce party sync after single-Lobster projection is stable.

## First Deliverable

The first concrete deliverable should be a “single Lobster runtime room”:

- one controllable Lobster avatar
- one room with several operational stations
- one adapter from OpenClaw state to avatar movement and status text
- one bridge from selected persona / skills / tools to visual loadout

This gets you to the real product shape fastest: a working game-console projection, not just another themed settings page.
