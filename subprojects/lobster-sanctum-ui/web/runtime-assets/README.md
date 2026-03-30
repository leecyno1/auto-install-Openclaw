# Runtime Assets

Stage 4 runtime asset decoupling.

## Structure

- `manifest.json`: global pack index (generated)
- `packs/<id>/pack.json`: source descriptor (editable)
- `packs/<id>/cache-manifest.json`: generated cache manifest
- `packs/<id>/styles/*`: lightweight CSS assets for lazy mode loading

## Pack Descriptor Schema

```json
{
  "id": "diablo-console",
  "name": "Diablo Console",
  "description": "...",
  "bodyClass": "runtime-pack-diablo",
  "baseAssets": [
    { "type": "css", "path": "styles/base.css", "id": "base-style" }
  ],
  "modeAssets": {
    "executing": [
      { "type": "css", "path": "styles/executing.css", "id": "mode-executing" }
    ]
  }
}
```

- `baseAssets`: loaded when the pack is applied.
- `modeAssets.<state>`: lazy-loaded when runtime enters state (`idle/writing/researching/executing/syncing/error`).

## Build

```bash
cd subprojects/lobster-sanctum-ui
bash ./build-runtime-assets.sh
```

`dev-server.sh start` will run manifest generation automatically.
