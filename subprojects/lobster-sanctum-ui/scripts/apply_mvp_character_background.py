#!/usr/bin/env python3
"""
MVP asset patch for Star Office world:
- Restore all assets to official backup baseline.
- Replace only character spritesheets (single character).
- Replace only background (same room layout, style-tuned).
"""

from __future__ import annotations

import io
import math
import shutil
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


@dataclass(frozen=True)
class Ctx:
    subproject_root: Path
    frontend_dir: Path
    backups_root: Path
    output_dir: Path
    source_root: Path
    char_archive: Path


TARGET_ASSETS = (
    "office_bg_small.webp",
    "office_bg.webp",
    "star-idle-v5.png",
    "star-working-spritesheet-grid.webp",
    "sync-animation-v3-grid.webp",
    "desk-v3.webp",
    "sofa-idle-v3.png",
    "posters-spritesheet.webp",
    "plants-spritesheet.webp",
    "coffee-machine-v3-grid.webp",
    "coffee-machine-shadow-v1.png",
    "serverroom-spritesheet.webp",
)


def build_ctx() -> Ctx:
    subproject_root = Path(__file__).resolve().parents[1]
    frontend_dir = subproject_root / "vendor" / "star-office-ui" / "frontend"
    backups_root = subproject_root / "materials" / "packs" / "backups"
    output_dir = subproject_root / "materials" / "packs" / "mvp-character-bg"
    source_root = Path(
        "/Volumes/PSSD/A051RPG像素游戏素材地图场景平铺图块rpgmaker人物角色UI道具美术资源/2000套-像素风格游戏素材"
    )
    return Ctx(
        subproject_root=subproject_root,
        frontend_dir=frontend_dir,
        backups_root=backups_root,
        output_dir=output_dir,
        source_root=source_root,
        char_archive=source_root / "人物行走图素材(XP)(2937个).rar",
    )


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def latest_original_backup(backups_root: Path) -> Path:
    p = backups_root / "star-office-ui-20260329-110029"
    if p.is_dir():
        return p
    cands = sorted([x for x in backups_root.glob("star-office-ui-*") if x.is_dir()], key=lambda x: x.name)
    if not cands:
        raise FileNotFoundError(f"no original backup under {backups_root}")
    return cands[0]


def extract_image(archive: Path, member: str) -> Image.Image:
    proc = subprocess.run(["bsdtar", "-xOf", str(archive), member], check=True, capture_output=True)
    return Image.open(io.BytesIO(proc.stdout)).convert("RGBA")


def dark_grade_keep_alpha(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(0.92)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.08)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.92)
    r, g, b = rgb.split()
    # red+blue style bias, keep subtle
    r = r.point(lambda v: min(255, int(v * 0.97 + 6)))
    g = g.point(lambda v: min(255, int(v * 0.93 + 3)))
    b = b.point(lambda v: min(255, int(v * 1.08 + 5)))
    out = Image.merge("RGB", (r, g, b)).convert("RGBA")
    out.putalpha(alpha)
    return out


def add_soft_vignette(img: Image.Image) -> Image.Image:
    w, h = img.size
    inner = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(inner)
    d.ellipse((int(w * 0.06), int(h * 0.08), int(w * 0.94), int(h * 1.02)), fill=255)
    inner = inner.filter(ImageFilter.GaussianBlur(max(20, min(w, h) // 8)))
    mask = ImageOps.invert(inner)
    shade = Image.new("RGBA", (w, h), (8, 10, 18, 72))
    shade.putalpha(mask)
    out = img.copy()
    out.alpha_composite(shade)
    return out


def make_bg_variant(base_bg: Image.Image) -> Image.Image:
    out = dark_grade_keep_alpha(base_bg)
    # subtle top bar to improve panel readability
    top = Image.new("RGBA", (out.width, 74), (8, 12, 20, 82))
    out.alpha_composite(top, (0, 0))
    return add_soft_vignette(out)


def split_char_frames(sheet: Image.Image) -> list[Image.Image]:
    # RPGMaker XP style 4x4
    cw = max(1, sheet.width // 4)
    ch = max(1, sheet.height // 4)
    seq = [1, 2, 1, 0]
    frames: list[Image.Image] = []
    for r in range(4):
        for c in seq:
            part = sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            bbox = part.getbbox()
            frames.append(part.crop(bbox) if bbox else part)
    return frames


def render_character_frame(sprite: Image.Image, fw: int, fh: int, i: int, work: bool = False) -> Image.Image:
    out = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    target_h = int(fh * (0.70 if not work else 0.66))
    scale = target_h / max(1, sprite.height)
    resized = sprite.resize((max(1, int(sprite.width * scale)), target_h), Image.Resampling.NEAREST)
    x = (fw - resized.width) // 2 + int(3 * math.sin(i * 0.6))
    y = fh - resized.height - (34 if not work else 42) + int(2 * math.sin(i * 0.5))

    shadow = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((x - 6, y + resized.height - 16, x + resized.width + 6, y + resized.height - 2), fill=(6, 8, 14, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(2))
    out.alpha_composite(shadow)
    out.alpha_composite(resized, (x, y))
    return out


def compose_grid(frames: list[Image.Image], cols: int, rows: int, fw: int, fh: int) -> Image.Image:
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    idx = 0
    for y in range(rows):
        for x in range(cols):
            out.alpha_composite(frames[idx], (x * fw, y * fh))
            idx += 1
    return out


def build_character_sheets(char_sheet: Image.Image) -> tuple[Image.Image, Image.Image]:
    pool = split_char_frames(char_sheet)
    idle_frames: list[Image.Image] = []
    for i in range(48):
        idle_frames.append(render_character_frame(pool[i % len(pool)], 256, 256, i, work=False))
    idle = compose_grid(idle_frames, cols=8, rows=6, fw=256, fh=256)

    work_frames: list[Image.Image] = []
    for i in range(40):
        work_frames.append(render_character_frame(pool[(i * 2) % len(pool)], 300, 300, i, work=True))
    work = compose_grid(work_frames, cols=8, rows=5, fw=300, fh=300)
    return idle, work


def save_webp(img: Image.Image, path: Path, quality: int = 92) -> None:
    img.convert("RGBA").save(path, format="WEBP", quality=quality, method=6)


def save_png(img: Image.Image, path: Path) -> None:
    img.convert("RGBA").save(path, format="PNG")


def restore_all_from_backup(backup_dir: Path, frontend_dir: Path) -> None:
    for name in TARGET_ASSETS:
        src = backup_dir / name
        dst = frontend_dir / name
        if src.exists():
            shutil.copy2(src, dst)


def build_outputs(ctx: Ctx, backup_dir: Path) -> dict[str, Path]:
    ensure_dir(ctx.output_dir)

    base_small = Image.open(backup_dir / "office_bg_small.webp").convert("RGBA")
    base_big = Image.open(backup_dir / "office_bg.webp").convert("RGBA")
    char_sheet = extract_image(ctx.char_archive, "Characters/314-黑魔法导师.png")

    bg_small = make_bg_variant(base_small)
    bg_big = make_bg_variant(base_big)
    idle, work = build_character_sheets(char_sheet)

    outputs: dict[str, Path] = {}
    outputs["office_bg_small.webp"] = ctx.output_dir / "office_bg_small.webp"
    outputs["office_bg.webp"] = ctx.output_dir / "office_bg.webp"
    outputs["star-idle-v5.png"] = ctx.output_dir / "star-idle-v5.png"
    outputs["star-working-spritesheet-grid.webp"] = ctx.output_dir / "star-working-spritesheet-grid.webp"

    save_webp(bg_small, outputs["office_bg_small.webp"], quality=92)
    save_webp(bg_big, outputs["office_bg.webp"], quality=92)
    save_png(idle, outputs["star-idle-v5.png"])
    save_webp(work, outputs["star-working-spritesheet-grid.webp"], quality=93)

    (ctx.output_dir / "README.md").write_text(
        "\n".join(
            [
                "# MVP Character + Background",
                "",
                "- 仅替换：背景（office_bg_small/office_bg）+ 主角（idle/working）。",
                "- 其余设施素材全部回滚官方原始备份。",
                "- 角色来源：Characters/314-黑魔法导师.png（单一角色）。",
                "- 生成时间：" + datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return outputs


def apply_outputs(ctx: Ctx, outputs: dict[str, Path]) -> Path:
    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
    rollback_dir = ctx.subproject_root / "materials" / "packs" / "backups" / f"mvp-apply-{ts}"
    ensure_dir(rollback_dir)
    for name in TARGET_ASSETS:
        src = ctx.frontend_dir / name
        if src.exists():
            shutil.copy2(src, rollback_dir / name)
    for name, src in outputs.items():
        shutil.copy2(src, ctx.frontend_dir / name)
    return rollback_dir


def main() -> int:
    ctx = build_ctx()
    backup_dir = latest_original_backup(ctx.backups_root)
    restore_all_from_backup(backup_dir, ctx.frontend_dir)
    outputs = build_outputs(ctx, backup_dir)
    rollback = apply_outputs(ctx, outputs)
    print(f"[ok] restored all assets from: {backup_dir}")
    print(f"[ok] applied MVP outputs: {ctx.output_dir}")
    print(f"[ok] rollback backup: {rollback}")
    for k, v in sorted(outputs.items()):
        print(f"  - {k}: {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
