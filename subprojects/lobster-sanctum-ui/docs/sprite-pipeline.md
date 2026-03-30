# Sprite Pipeline

`Lobster Sanctum` now keeps character animation assets in two layers.

## 1. Source Layer

Raw extracted action sequences stay in:

- `materials/character-sets/seven-multi-action-v1/`

This is the full local source set. It is intentionally kept in the repository workspace so future role expansion does not depend on downloading assets again.

## 2. Compressed Reserve Library

All available actions for all seven roles are compressed into a local reserve library:

- `materials/character-library/seven-multi-action-v1-compressed/`

Structure:

- `manifest.json`: global index of all roles and actions
- `<role-id>/manifest.json`: per-role action manifest
- `<role-id>/actions/*.webp`: compressed action sheets for every preserved action

Current build spec:

- action frame: `160x160`
- format: `webp`
- columns: `6`

This reserve library is for local storage and future expansion. It is not shipped in the production runtime package.

## 3. Runtime Layer

The runtime still only consumes four mapped states per role:

- `idle`
- `working`
- `sync`
- `error`

Output path:

- `vendor/star-office-ui/frontend/role-sprites/<role-id>/`

The front-end continues to load only the current role pack. It does not preload all seven roles.

## Build

Regenerate both layers with:

```bash
cd subprojects/lobster-sanctum-ui
python3 scripts/build_role_state_sprites.py
```

## Packaging Rule

Production package excludes the whole `materials/` tree, including the compressed reserve library, so deployment stays lightweight.
