# UI Studio Session

Session name:
- `lobster_ui_studio`

Session objective:
- Focus on UI design, art direction, interaction polish, and visual consistency.
- Avoid touching installer/menu orchestration unless UI data contract changes require it.

Default constraints:
- Keep config UI port fixed at `18188`.
- Preserve 3-stage flow:
  - Stage I: Persona Temple
  - Stage II: Skill Tree + Armory Overview
  - Stage III: Command Center
- Keep dark red/blue/black visual identity, strong contrast, game-like hierarchy.

Development checklist:
1. Start server via `dev-server.sh`.
2. Iterate only in `web/`.
3. Validate desktop first, then mobile breakpoints.
4. Capture screenshots into `tmp/` for review.
5. Keep export/apply contract stable with:
   - `scripts/apply-web-profile.sh`
   - `install.sh` CLI mappings

Hand-off output:
- Changed files list.
- Before/after screenshots.
- Notes on interaction changes.
