# Pixel Runtime Performance Rules

This document is the standing constraint for Lobster Sanctum runtime work.

## Core Rules

1. Only load the currently selected role sprite pack.
2. Do not preload all seven role packs in the world scene.
3. Production packages must exclude development materials, preview images, and backup packs.
4. New runtime art should prefer pixel assets over large illustration assets.
5. Resource compression is mandatory for any new animated spritesheet or background.

## Runtime Goals

- Target server: `2 CPU / 2 GB RAM`
- Keep backend services lightweight and single-process by default.
- Keep browser first-screen asset pressure as low as possible.

## Asset Budget Guidance

- Backgrounds:
  - prefer `1280x720` or lower
  - avoid oversized multi-megabyte PNG backgrounds when WebP is viable
- Character idle art:
  - prefer longest side `<= 1024`
- Character animated sheets:
  - prefer frame sizes around `160x160` to `192x192`
  - only exceed that when visually necessary
- Decorative animated props:
  - downscale aggressively if they occupy a small on-screen footprint

## Packaging Rules

Production output should exclude:

- `materials/`
- `materials/previews/`
- `materials/packs/backups/`
- temp screenshots
- local test outputs
- Electron or desktop-only shells unless explicitly required

## Review Checklist

Before merging any runtime visual change:

1. Is the asset pixel-first rather than illustration-heavy?
2. Is the displayed size much smaller than the source size?
3. Can the source be reduced without visible quality loss?
4. Is the asset loaded only in the state or role that needs it?
5. Will it increase first-screen browser memory materially?

If the answer to `2`, `3`, or `5` is yes, optimize before merge.
