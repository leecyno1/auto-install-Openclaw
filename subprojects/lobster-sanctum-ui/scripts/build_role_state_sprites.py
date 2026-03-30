#!/usr/bin/env python3
"""
Build role-specific state spritesheets for Star Office runtime.

Output:
  materials/character-library/seven-multi-action-v1-compressed/
    - manifest.json
    - <role-id>/manifest.json
    - <role-id>/actions/<action-id>.webp     # all preserved local actions, compressed

  vendor/star-office-ui/frontend/role-sprites/<role-id>/
    - star-idle-v5.png                  (8x6, 256x256)
    - star-working-spritesheet-grid.webp (8x5, 300x300)
    - sync-animation-v3-grid.webp       (7x7, 256x256)  # sync -> lying down
    - error-bug-spritesheet-grid.webp   (9x8, 220x220)  # alarm
"""

from __future__ import annotations

import json
import math
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


@dataclass(frozen=True)
class RoleMap:
    role_id: str
    source_name: str


ROLE_MAPS = [
    RoleMap("druid", "Heavy Armored Defender Knight"),
    RoleMap("assassin", "Rogue"),
    RoleMap("mage", "Black Wizard"),
    RoleMap("summoner", "Lich"),
    RoleMap("warrior", "Spartan Knight with Spear"),
    RoleMap("paladin", "Hell_Knight"),
    RoleMap("archer", "Death_Knight"),
]

RUNTIME_OUTPUTS = {
    "idle": {"fw": 256, "fh": 256, "cols": 8, "rows": 6, "format": "png", "file": "star-idle-v5.png"},
    "working": {
        "fw": 300,
        "fh": 300,
        "cols": 8,
        "rows": 5,
        "format": "webp",
        "file": "star-working-spritesheet-grid.webp",
    },
    "sync": {"fw": 256, "fh": 256, "cols": 7, "rows": 7, "format": "webp", "file": "sync-animation-v3-grid.webp"},
    "error": {
        "fw": 220,
        "fh": 220,
        "cols": 9,
        "rows": 8,
        "format": "webp",
        "file": "error-bug-spritesheet-grid.webp",
    },
}

LIBRARY_FRAME_W = 160
LIBRARY_FRAME_H = 160
LIBRARY_WEBP_QUALITY = 86
LIBRARY_COLS = 6
LIBRARY_NAME = "seven-multi-action-v1-compressed"


def normalize_action_name(name: str) -> str:
    return " ".join(name.lower().replace("_", " ").replace("-", " ").split())


def slugify_action_name(name: str) -> str:
    normalized = normalize_action_name(name)
    chars: list[str] = []
    last_dash = False
    for ch in normalized:
        keep = ch.isalnum()
        if keep:
            chars.append(ch)
            last_dash = False
            continue
        if not last_dash:
            chars.append("-")
            last_dash = True
    return "".join(chars).strip("-") or "action"


def rel_path(path: Path, base: Path) -> str:
    return path.resolve().relative_to(base.resolve()).as_posix()


def list_action_dirs(role_dir: Path) -> dict[str, Path]:
    seq_root = role_dir / "PNG Sequences"
    out: dict[str, Path] = {}
    if not seq_root.is_dir():
        return out
    for p in seq_root.iterdir():
        if p.is_dir():
            out[normalize_action_name(p.name)] = p
    return out


def pick_action(action_dirs: dict[str, Path], kind: str) -> Path:
    # strict priorities for requested 4-state mapping
    priorities = {
        "idle": ["idle", "idle blinking"],
        "working": ["running", "walking", "run attacking", "run slashing", "run throwing", "run swinging rod"],
        "sync": ["dying", "falling down", "sliding"],
        "error": ["hurt", "attacking", "slashing", "throwing"],
    }
    for key in priorities[kind]:
        if key in action_dirs:
            return action_dirs[key]
    # fallback: first available directory
    if not action_dirs:
        raise RuntimeError(f"no actions found for {kind}")
    return sorted(action_dirs.values(), key=lambda p: p.name)[0]


def load_frames(action_dir: Path) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for p in sorted(action_dir.glob("*.png")):
        try:
            frames.append(Image.open(p).convert("RGBA"))
        except Exception:
            continue
    if not frames:
        raise RuntimeError(f"no png frames in {action_dir}")
    return frames


def crop_alpha(img: Image.Image) -> Image.Image:
    bbox = img.getchannel("A").getbbox()
    return img.crop(bbox) if bbox else img


def frame_for_library(src: Image.Image, fw: int, fh: int) -> Image.Image:
    out = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    cut = crop_alpha(src)
    if cut.width == 0 or cut.height == 0:
        return out

    max_w = int(fw * 0.76)
    max_h = int(fh * 0.78)
    scale = min(max_w / max(1, cut.width), max_h / max(1, cut.height))
    resized = cut.resize(
        (max(1, int(cut.width * scale)), max(1, int(cut.height * scale))),
        Image.Resampling.LANCZOS,
    )
    x = (fw - resized.width) // 2
    y = fh - resized.height - max(8, int(fh * 0.10))

    shadow = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse(
        (x - 8, y + resized.height - 14, x + resized.width + 8, y + resized.height - 2),
        fill=(6, 8, 12, 92),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    out.alpha_composite(shadow)
    out.alpha_composite(resized, (x, y))
    return out


def frame_with_shadow(
    src: Image.Image,
    fw: int,
    fh: int,
    i: int,
    mode: str,
) -> Image.Image:
    out = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    cut = crop_alpha(src)

    if mode == "sync":
        # sync state should be lying down: use wider pose fit, center-lower
        target = int(fh * 0.60)
        scale = target / max(1, cut.height)
        resized = cut.resize((max(1, int(cut.width * scale)), target), Image.Resampling.LANCZOS)
        x = (fw - resized.width) // 2
        y = fh - resized.height - 34
    elif mode == "working":
        target = int(fh * 0.66)
        scale = target / max(1, cut.height)
        resized = cut.resize((max(1, int(cut.width * scale)), target), Image.Resampling.LANCZOS)
        x = (fw - resized.width) // 2 + int(4 * math.sin(i * 0.6))
        y = fh - resized.height - 44
    elif mode == "error":
        target = int(fh * 0.68)
        scale = target / max(1, cut.height)
        resized = cut.resize((max(1, int(cut.width * scale)), target), Image.Resampling.LANCZOS)
        x = (fw - resized.width) // 2 + int(5 * math.sin(i * 0.8))
        y = fh - resized.height - 32
    else:  # idle
        target = int(fh * 0.70)
        scale = target / max(1, cut.height)
        resized = cut.resize((max(1, int(cut.width * scale)), target), Image.Resampling.LANCZOS)
        x = (fw - resized.width) // 2 + int(3 * math.sin(i * 0.5))
        y = fh - resized.height - 34

    shadow = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((x - 10, y + resized.height - 18, x + resized.width + 10, y + resized.height - 2), fill=(8, 10, 16, 108))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    out.alpha_composite(shadow)
    out.alpha_composite(resized, (x, y))

    if mode == "working":
        # subtle work panel
        panel_w, panel_h = int(fw * 0.5), int(fh * 0.2)
        panel = Image.new("RGBA", (panel_w, panel_h), (18, 24, 30, 216))
        pd = ImageDraw.Draw(panel)
        pd.rounded_rectangle((0, 0, panel_w - 1, panel_h - 1), radius=8, outline=(98, 160, 255, 190), width=2)
        for k in range(4):
            yy = 9 + k * 11
            pd.line((9, yy, panel_w - 10, yy), fill=(120, 210 if k % 2 else 170, 255, 184), width=2)
        out.alpha_composite(panel, ((fw - panel_w) // 2, fh - panel_h - 8))

    if mode == "error":
        # red warning tint
        tint = Image.new("RGBA", (fw, fh), (220, 40, 60, 22))
        out.alpha_composite(tint)

    if mode == "sync":
        # soft blue sync tint
        tint = Image.new("RGBA", (fw, fh), (80, 140, 255, 18))
        out.alpha_composite(tint)

    return out


def build_archive_sheet(frames_src: list[Image.Image], fw: int, fh: int, cols: int) -> tuple[Image.Image, int, int]:
    prepared = [frame_for_library(frame, fw, fh) for frame in frames_src]
    cols = max(1, min(cols, len(prepared)))
    rows = max(1, math.ceil(len(prepared) / cols))
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for idx, frame in enumerate(prepared):
        x = (idx % cols) * fw
        y = (idx // cols) * fh
        out.alpha_composite(frame, (x, y))
    return out, cols, rows


def build_sheet(
    frames_src: list[Image.Image],
    fw: int,
    fh: int,
    cols: int,
    rows: int,
    mode: str,
) -> Image.Image:
    need = cols * rows
    prepared: list[Image.Image] = []

    if mode == "sync":
        # enforce lying look: prefer wide frames first
        wide = [f for f in frames_src if crop_alpha(f).width > crop_alpha(f).height * 1.08]
        pool = wide if wide else frames_src[-max(1, min(8, len(frames_src))) :]
    else:
        pool = frames_src
    if not pool:
        pool = frames_src

    for i in range(need):
        prepared.append(frame_with_shadow(pool[i % len(pool)], fw, fh, i, mode))

    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    idx = 0
    for y in range(rows):
        for x in range(cols):
            out.alpha_composite(prepared[idx], (x * fw, y * fh))
            idx += 1
    return out


def save_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG")


def save_webp(img: Image.Image, path: Path, quality: int = 93) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="WEBP", quality=quality, method=6)


def build_compressed_library(
    role: RoleMap,
    source_dir: Path,
    library_root: Path,
    subproject_root: Path,
    runtime_action_dirs: dict[str, Path],
) -> dict[str, object]:
    role_out = library_root / role.role_id
    shutil.rmtree(role_out, ignore_errors=True)
    actions_dir = role_out / "actions"
    actions_dir.mkdir(parents=True, exist_ok=True)

    action_dirs = list_action_dirs(source_dir)
    role_actions: list[dict[str, object]] = []
    for _, action_dir in sorted(action_dirs.items(), key=lambda item: item[1].name.lower()):
        frames = load_frames(action_dir)
        source_pngs = sorted(action_dir.glob("*.png"))
        action_id = slugify_action_name(action_dir.name)
        archive_sheet, cols, rows = build_archive_sheet(
            frames,
            fw=LIBRARY_FRAME_W,
            fh=LIBRARY_FRAME_H,
            cols=LIBRARY_COLS,
        )
        archive_rel = Path("actions") / f"{action_id}.webp"
        save_webp(archive_sheet, role_out / archive_rel, quality=LIBRARY_WEBP_QUALITY)
        role_actions.append(
            {
                "action_id": action_id,
                "source_action": action_dir.name,
                "normalized_name": normalize_action_name(action_dir.name),
                "source_dir": rel_path(action_dir, subproject_root),
                "sample_frame": rel_path(source_pngs[0], subproject_root),
                "frame_count": len(frames),
                "archive": {
                    "file": archive_rel.as_posix(),
                    "format": "webp",
                    "frame_width": LIBRARY_FRAME_W,
                    "frame_height": LIBRARY_FRAME_H,
                    "columns": cols,
                    "rows": rows,
                    "quality": LIBRARY_WEBP_QUALITY,
                },
            }
        )

    role_manifest = {
        "role_id": role.role_id,
        "source_name": role.source_name,
        "source_dir": rel_path(source_dir, subproject_root),
        "runtime_mapping": {key: value.name for key, value in runtime_action_dirs.items()},
        "action_total": len(role_actions),
        "actions": role_actions,
    }
    (role_out / "manifest.json").write_text(
        json.dumps(role_manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return role_manifest


def main() -> int:
    subproject_root = Path(__file__).resolve().parents[1]
    src_root = subproject_root / "materials" / "character-sets" / "seven-multi-action-v1"
    library_root = subproject_root / "materials" / "character-library" / LIBRARY_NAME
    out_root = subproject_root / "vendor" / "star-office-ui" / "frontend" / "role-sprites"
    library_root.mkdir(parents=True, exist_ok=True)
    out_root.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "roles": [],
    }
    library_manifest: dict[str, object] = {
        "name": LIBRARY_NAME,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_set": "seven-multi-action-v1",
        "frame_spec": {
            "frame_width": LIBRARY_FRAME_W,
            "frame_height": LIBRARY_FRAME_H,
            "columns": LIBRARY_COLS,
            "format": "webp",
            "quality": LIBRARY_WEBP_QUALITY,
        },
        "roles": [],
    }

    for role in ROLE_MAPS:
        source_dir = src_root / role.source_name
        action_dirs = list_action_dirs(source_dir)
        if not action_dirs:
            raise RuntimeError(f"missing action dirs: {source_dir}")

        idle_dir = pick_action(action_dirs, "idle")
        work_dir = pick_action(action_dirs, "working")
        sync_dir = pick_action(action_dirs, "sync")
        error_dir = pick_action(action_dirs, "error")
        runtime_action_dirs = {
            "idle": idle_dir,
            "working": work_dir,
            "sync": sync_dir,
            "error": error_dir,
        }

        idle_frames = load_frames(idle_dir)
        work_frames = load_frames(work_dir)
        sync_frames = load_frames(sync_dir)
        error_frames = load_frames(error_dir)

        idle_sheet = build_sheet(
            idle_frames,
            fw=RUNTIME_OUTPUTS["idle"]["fw"],
            fh=RUNTIME_OUTPUTS["idle"]["fh"],
            cols=RUNTIME_OUTPUTS["idle"]["cols"],
            rows=RUNTIME_OUTPUTS["idle"]["rows"],
            mode="idle",
        )
        work_sheet = build_sheet(
            work_frames,
            fw=RUNTIME_OUTPUTS["working"]["fw"],
            fh=RUNTIME_OUTPUTS["working"]["fh"],
            cols=RUNTIME_OUTPUTS["working"]["cols"],
            rows=RUNTIME_OUTPUTS["working"]["rows"],
            mode="working",
        )
        sync_sheet = build_sheet(
            sync_frames,
            fw=RUNTIME_OUTPUTS["sync"]["fw"],
            fh=RUNTIME_OUTPUTS["sync"]["fh"],
            cols=RUNTIME_OUTPUTS["sync"]["cols"],
            rows=RUNTIME_OUTPUTS["sync"]["rows"],
            mode="sync",
        )
        error_sheet = build_sheet(
            error_frames,
            fw=RUNTIME_OUTPUTS["error"]["fw"],
            fh=RUNTIME_OUTPUTS["error"]["fh"],
            cols=RUNTIME_OUTPUTS["error"]["cols"],
            rows=RUNTIME_OUTPUTS["error"]["rows"],
            mode="error",
        )

        role_out = out_root / role.role_id
        shutil.rmtree(role_out, ignore_errors=True)
        save_png(idle_sheet, role_out / RUNTIME_OUTPUTS["idle"]["file"])
        save_webp(work_sheet, role_out / RUNTIME_OUTPUTS["working"]["file"])
        save_webp(sync_sheet, role_out / RUNTIME_OUTPUTS["sync"]["file"])
        save_webp(error_sheet, role_out / RUNTIME_OUTPUTS["error"]["file"])

        role_library_manifest = build_compressed_library(
            role=role,
            source_dir=source_dir,
            library_root=library_root,
            subproject_root=subproject_root,
            runtime_action_dirs=runtime_action_dirs,
        )
        library_manifest["roles"].append(role_library_manifest)

        manifest["roles"].append(
            {
                "role_id": role.role_id,
                "source": role.source_name,
                "mapping": {
                    "idle": idle_dir.name,
                    "working": work_dir.name,
                    "sync": sync_dir.name,
                    "error": error_dir.name,
                },
                "counts": {
                    "idle_src_frames": len(idle_frames),
                    "working_src_frames": len(work_frames),
                    "sync_src_frames": len(sync_frames),
                    "error_src_frames": len(error_frames),
                },
                "library": {
                    "manifest": rel_path(library_root / role.role_id / "manifest.json", subproject_root),
                    "action_total": role_library_manifest["action_total"],
                },
                "outputs": {
                    "idle": RUNTIME_OUTPUTS["idle"]["file"],
                    "working": RUNTIME_OUTPUTS["working"]["file"],
                    "sync": RUNTIME_OUTPUTS["sync"]["file"],
                    "error": RUNTIME_OUTPUTS["error"]["file"],
                },
            }
        )

    (out_root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (library_root / "manifest.json").write_text(
        json.dumps(library_manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"[ok] built compressed local action library: {library_root}")
    print(f"[ok] built role sprite packs: {out_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
