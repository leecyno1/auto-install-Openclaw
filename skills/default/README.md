# Skills cache moved

Default OpenClaw skills are maintained in the dedicated `boutique-openclaw-skills` repository.

- Repository: https://github.com/leecyno1/boutique-openclaw-skills
- Local sibling path during development: `/Volumes/PSSD/Projects/boutique-openclaw-skills`
- Installer compatibility manifest: `../manifest.json`

This directory intentionally does not vendor the full default skills bundle anymore. Runtime installers resolve skills from `OPENCLAW_SKILLS_REPO_URL` or an explicit `OPENCLAW_SKILLS_BUNDLE_DIR`.
