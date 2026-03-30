#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ASSETS_ROOT = ROOT / "web" / "runtime-assets"
PACKS_ROOT = ASSETS_ROOT / "packs"
MANIFEST_FILE = ASSETS_ROOT / "manifest.json"

ALLOWED_TYPES = {"css", "image", "script", "font", "json"}


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


@dataclass
class AssetRow:
    id: str
    type: str
    mode: str
    path: str
    size: int
    sha256: str

    def to_json(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "type": self.type,
            "mode": self.mode,
            "path": self.path,
            "size": self.size,
            "sha256": self.sha256,
        }


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def collect_assets(pack_dir: Path, descriptor: dict[str, Any]) -> list[AssetRow]:
    assets: list[AssetRow] = []

    def add_entry(entry: dict[str, Any], mode: str, idx: int) -> None:
        typ = str(entry.get("type", "")).strip().lower()
        if typ not in ALLOWED_TYPES:
            raise ValueError(f"[{pack_dir.name}] invalid asset type: {typ}")
        rel = str(entry.get("path", "")).strip()
        if not rel:
            raise ValueError(f"[{pack_dir.name}] asset path required")
        file_path = pack_dir / rel
        if not file_path.exists() or not file_path.is_file():
            raise FileNotFoundError(f"[{pack_dir.name}] asset missing: {rel}")
        public_path = str(file_path.relative_to(ROOT / "web")).replace("\\", "/")
        asset_id = str(entry.get("id", "")).strip() or f"{mode}:{idx}:{rel}"
        assets.append(
            AssetRow(
                id=asset_id,
                type=typ,
                mode=mode,
                path=public_path,
                size=file_path.stat().st_size,
                sha256=sha256_file(file_path),
            )
        )

    base = descriptor.get("baseAssets", [])
    if not isinstance(base, list):
        raise ValueError(f"[{pack_dir.name}] baseAssets must be list")
    for idx, entry in enumerate(base):
        if not isinstance(entry, dict):
            raise ValueError(f"[{pack_dir.name}] base asset must be object")
        add_entry(entry, "base", idx)

    mode_assets = descriptor.get("modeAssets", {})
    if not isinstance(mode_assets, dict):
        raise ValueError(f"[{pack_dir.name}] modeAssets must be object")
    for mode, rows in mode_assets.items():
        if not isinstance(rows, list):
            raise ValueError(f"[{pack_dir.name}] modeAssets.{mode} must be list")
        for idx, entry in enumerate(rows):
            if not isinstance(entry, dict):
                raise ValueError(f"[{pack_dir.name}] mode asset must be object")
            add_entry(entry, str(mode), idx)

    return assets


def build_pack_manifest(pack_dir: Path) -> dict[str, Any]:
    desc_file = pack_dir / "pack.json"
    if not desc_file.exists():
        raise FileNotFoundError(f"pack descriptor missing: {desc_file}")

    descriptor = load_json(desc_file)
    pack_id = str(descriptor.get("id", "")).strip() or pack_dir.name
    name = str(descriptor.get("name", "")).strip() or pack_id
    description = str(descriptor.get("description", "")).strip()
    body_class = str(descriptor.get("bodyClass", "")).strip()

    rows = collect_assets(pack_dir, descriptor)
    rows_json = [row.to_json() for row in rows]
    total_bytes = sum(row.size for row in rows)

    pack_manifest = {
        "id": pack_id,
        "name": name,
        "description": description,
        "bodyClass": body_class,
        "generatedAt": now_iso(),
        "assets": rows_json,
        "totals": {
            "assets": len(rows_json),
            "bytes": total_bytes,
        },
    }

    out_file = pack_dir / "cache-manifest.json"
    out_file.write_text(json.dumps(pack_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return pack_manifest


def main() -> None:
    PACKS_ROOT.mkdir(parents=True, exist_ok=True)
    pack_dirs = sorted([p for p in PACKS_ROOT.iterdir() if p.is_dir()])
    pack_manifests: list[dict[str, Any]] = []

    for pack_dir in pack_dirs:
        pack_manifests.append(build_pack_manifest(pack_dir))

    default_pack = "core"
    if not any(item.get("id") == default_pack for item in pack_manifests) and pack_manifests:
        default_pack = str(pack_manifests[0].get("id"))

    global_manifest = {
        "version": 1,
        "generatedAt": now_iso(),
        "defaultPack": default_pack,
        "packs": [
            {
                "id": item.get("id"),
                "name": item.get("name"),
                "description": item.get("description"),
                "bodyClass": item.get("bodyClass"),
                "manifest": f"runtime-assets/packs/{item.get('id')}/cache-manifest.json",
                "assets": item.get("assets", []),
                "totals": item.get("totals", {"assets": 0, "bytes": 0}),
            }
            for item in pack_manifests
        ],
    }

    MANIFEST_FILE.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_FILE.write_text(json.dumps(global_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    summary = {
        "packs": len(pack_manifests),
        "assets": sum(int(item.get("totals", {}).get("assets", 0)) for item in pack_manifests),
        "bytes": sum(int(item.get("totals", {}).get("bytes", 0)) for item in pack_manifests),
        "defaultPack": default_pack,
        "manifest": str(MANIFEST_FILE),
    }
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
