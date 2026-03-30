# Progress

- 2026-03-26: Audited detached config UI and vendor pixel-house runtime.
- 2026-03-26: Confirmed architecture drift: room and configuration became parallel systems.
- 2026-03-26: Chosen direction for first recovery step: serve existing workbench pages from the room backend and open them as an in-room modal.
- 2026-03-26: Added `/workbench/...` routes to the room backend so persona/loadout/configure pages are same-origin under the house server.
- 2026-03-26: Added room-native workbench modal and in-room entry points for role, skills, equipment, status, and tasks.
- 2026-03-26: Verified `http://127.0.0.1:19000/` and workbench pages in a real browser session; modal and iframe loading are working.
- 2026-03-30: Extended `build_role_state_sprites.py` to generate both the compressed full-action local reserve library and the current four-state runtime sprite packs.
- 2026-03-30: Rebuilt sprite assets and verified 7 roles / 118 compressed action archives plus intact runtime four-state packs.
