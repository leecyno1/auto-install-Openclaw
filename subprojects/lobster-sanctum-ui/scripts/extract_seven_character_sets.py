#!/usr/bin/env python3
"""
Extract seven curated multi-action character sets from local archive library.
Output folder:
  subprojects/lobster-sanctum-ui/materials/character-sets/seven-multi-action-v1
"""

from __future__ import annotations

import json
import subprocess
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class RoleSpec:
    archive_no: str
    role_name: str
    theme: str


SPECS = [
    RoleSpec("55", "Heavy Armored Defender Knight", "tank"),
    RoleSpec("56", "Black Wizard", "mage"),
    RoleSpec("59", "Lich", "undead-caster"),
    RoleSpec("60", "Rogue", "assassin"),
    RoleSpec("62", "Hell_Knight", "dark-knight"),
    RoleSpec("63", "Death_Knight", "death-knight"),
    RoleSpec("64", "Spartan Knight with Spear", "spear-warrior"),
]


def list_entries(archive: Path) -> list[str]:
    r = subprocess.run(["bsdtar", "-tf", str(archive)], capture_output=True, check=True)
    return [x.strip() for x in r.stdout.decode("utf-8", "ignore").splitlines() if x.strip()]


def extract_entry(archive: Path, entry: str, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(["bsdtar", "-xOf", str(archive), entry], capture_output=True, check=True)
    out_path.write_bytes(r.stdout)


def main() -> int:
    root = Path("/Volumes/PSSD/A051RPG像素游戏素材地图场景平铺图块rpgmaker人物角色UI道具美术资源/2000套-像素风格游戏素材/更新/2105141")
    repo = Path(__file__).resolve().parents[1]
    out_root = repo / "materials" / "character-sets" / "seven-multi-action-v1"
    out_root.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "name": "seven-multi-action-v1",
        "source_root": str(root),
        "roles": [],
    }

    for spec in SPECS:
        archive = root / f"{spec.archive_no}.zip"
        entries = list_entries(archive)
        prefix = f"{spec.role_name}/PNG/PNG Sequences/"
        role_entries = [e for e in entries if e.startswith(prefix) and not e.endswith("/")]
        if not role_entries:
            raise RuntimeError(f"no entries found for {spec.role_name} in {archive}")

        role_dir = out_root / spec.role_name
        role_dir.mkdir(parents=True, exist_ok=True)

        action_map: dict[str, list[str]] = defaultdict(list)
        for entry in role_entries:
            rel = entry[len(prefix) :]
            if "/" not in rel:
                continue
            action, file_name = rel.split("/", 1)
            action_map[action].append(file_name)
            extract_entry(archive, entry, role_dir / "PNG Sequences" / action / file_name)

        # keep metadata for each role
        clean_actions = []
        for action, files in sorted(action_map.items()):
            clean_actions.append(
                {
                    "name": action,
                    "frame_count": len(files),
                    "sample_file": files[0] if files else "",
                }
            )

        (role_dir / "README.md").write_text(
            "\n".join(
                [
                    f"# {spec.role_name}",
                    "",
                    f"- Source archive: `{archive.name}`",
                    f"- Theme tag: `{spec.theme}`",
                    f"- Actions: {len(clean_actions)}",
                    "",
                    "## Action List",
                    *[f"- `{a['name']}`: {a['frame_count']} frames" for a in clean_actions],
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        manifest["roles"].append(
            {
                "archive": archive.name,
                "archive_no": spec.archive_no,
                "role": spec.role_name,
                "theme": spec.theme,
                "action_count": len(clean_actions),
                "actions": clean_actions,
                "root": str(role_dir),
            }
        )

    (out_root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[ok] extracted 7 role sets to: {out_root}")
    print(f"[ok] manifest: {out_root / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
