# Upstream source

Base inspiration and initial asset source:
- Project: https://github.com/KsanaDock/Microverse
- Snapshot used during bootstrap: local clone at `/tmp/Microverse`
- Observed commit during analysis: `6f30155`

Current phase keeps only:
- Godot project structure as the frontend mainline direction
- pixel font and selected pixel UI assets
- character sprite sheets and portraits for OpenClaw roles
- interior texture sheets for Home Base baseline

Current phase intentionally excludes:
- original Microverse AI social simulation
- original memory/dialog/storage semantics
- original autoload graph and save system
- original office scene runtime as the primary business layer

Reason:
OpenClaw business semantics remain the truth source. `world-gateway` is the only adapter to OpenClaw, and the Godot client consumes that protocol instead of introducing a second business system.
