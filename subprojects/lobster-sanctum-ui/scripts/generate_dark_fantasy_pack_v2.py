#!/usr/bin/env python3
"""
Generate dark-fantasy pack v2 (refined, frame-safe).

Strategy:
- Keep original Star Office asset geometry/layout from backup.
- Apply dark blue/red grading consistently.
- Inject curated dungeon/graveyard details from local archive packs.
- Preserve exact output dimensions and spritesheet frame grids.
"""

from __future__ import annotations

import argparse
import io
import math
import random
import shutil
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


RNG = random.Random(20260329)


@dataclass(frozen=True)
class Ctx:
    subproject_root: Path
    frontend_dir: Path
    backups_root: Path
    output_dir: Path
    source_root: Path
    char_archive: Path
    graveyard_archive: Path
    dungeon_archive: Path
    interior_archive: Path


def build_ctx() -> Ctx:
    subproject_root = Path(__file__).resolve().parents[1]
    frontend_dir = subproject_root / "vendor" / "star-office-ui" / "frontend"
    backups_root = subproject_root / "materials" / "packs" / "backups"
    output_dir = subproject_root / "materials" / "packs" / "dark-fantasy-v2"
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
        graveyard_archive=source_root / "RPG像素风格森林郊外墓地恐怖暗黑场景地图素材.zip",
        dungeon_archive=source_root / "像素地牢游戏关卡场景地图图块素材.zip",
        interior_archive=source_root / "室内像素风格地图场景图块元素游戏素材.zip",
    )


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def latest_backup_dir(backups_root: Path) -> Path:
    cands = sorted([p for p in backups_root.glob("star-office-ui-*") if p.is_dir()], key=lambda p: p.name)
    if not cands:
        raise FileNotFoundError(f"no backup folder found under {backups_root}")
    return cands[-1]


def extract_image(archive: Path, member: str) -> Image.Image:
    proc = subprocess.run(
        ["bsdtar", "-xOf", str(archive), member],
        check=True,
        capture_output=True,
    )
    return Image.open(io.BytesIO(proc.stdout)).convert("RGBA")


def cover_resize(img: Image.Image, width: int, height: int) -> Image.Image:
    sw, sh = img.size
    s = max(width / sw, height / sh)
    r = img.resize((max(1, int(sw * s)), max(1, int(sh * s))), Image.Resampling.NEAREST)
    x = (r.width - width) // 2
    y = (r.height - height) // 2
    return r.crop((x, y, x + width, y + height))


def contain_resize(img: Image.Image, width: int, height: int) -> Image.Image:
    sw, sh = img.size
    s = min(width / sw, height / sh)
    r = img.resize((max(1, int(sw * s)), max(1, int(sh * s))), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.alpha_composite(r, ((width - r.width) // 2, (height - r.height) // 2))
    return out


def dark_grade(img: Image.Image, sat: float = 0.85, ctr: float = 1.13, bri: float = 0.88) -> Image.Image:
    alpha = img.convert("RGBA").getchannel("A")
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(sat)
    rgb = ImageEnhance.Contrast(rgb).enhance(ctr)
    rgb = ImageEnhance.Brightness(rgb).enhance(bri)
    r, g, b = rgb.split()
    # shift toward blue/red fantasy palette
    r = r.point(lambda v: min(255, int(v * 0.95 + 8)))
    g = g.point(lambda v: min(255, int(v * 0.92 + 4)))
    b = b.point(lambda v: min(255, int(v * 1.12 + 6)))
    out = Image.merge("RGB", (r, g, b)).convert("RGBA")
    out.putalpha(alpha)
    return out


def add_vignette(img: Image.Image, alpha: int = 100) -> Image.Image:
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((0, 0, w, h), fill=255)
    inner = Image.new("L", (w, h), 0)
    ImageDraw.Draw(inner).ellipse((int(w * 0.02), int(h * 0.05), int(w * 0.98), int(h * 1.00)), fill=255)
    inner = inner.filter(ImageFilter.GaussianBlur(max(24, min(w, h) // 8)))
    vignette = ImageOps.invert(inner)
    overlay = Image.new("RGBA", (w, h), (6, 8, 18, alpha))
    overlay.putalpha(vignette)
    out = img.copy()
    out.alpha_composite(overlay)
    return out


def split_sheet(sheet: Image.Image, fw: int, fh: int) -> list[Image.Image]:
    frames: list[Image.Image] = []
    cols = sheet.width // fw
    rows = sheet.height // fh
    for y in range(rows):
        for x in range(cols):
            frames.append(sheet.crop((x * fw, y * fh, (x + 1) * fw, (y + 1) * fh)))
    return frames


def compose_sheet(frames: list[Image.Image], cols: int, rows: int, fw: int, fh: int) -> Image.Image:
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    idx = 0
    for y in range(rows):
        for x in range(cols):
            out.alpha_composite(frames[idx], (x * fw, y * fh))
            idx += 1
    return out


def cells_from_sheet(sheet: Image.Image, cell: int = 32) -> list[Image.Image]:
    out: list[Image.Image] = []
    for y in range(0, sheet.height, cell):
        for x in range(0, sheet.width, cell):
            c = sheet.crop((x, y, min(x + cell, sheet.width), min(y + cell, sheet.height)))
            if c.width != cell or c.height != cell:
                continue
            if c.getchannel("A").getbbox() is None:
                continue
            out.append(c)
    return out


def score_cell(img: Image.Image) -> float:
    # high alpha occupancy + color variance -> likely "usable object"
    a = img.getchannel("A")
    bbox = a.getbbox()
    if not bbox:
        return 0.0
    alpha_nonzero = sum(1 for v in a.getdata() if v > 16)
    occ = alpha_nonzero / (img.width * img.height)
    rgb = img.convert("RGB")
    stat = ImageStatLite.from_image(rgb)
    variance = stat.var_r + stat.var_g + stat.var_b
    return occ * 2.0 + variance / 10000.0


class ImageStatLite:
    def __init__(self, mean_r: float, mean_g: float, mean_b: float, var_r: float, var_g: float, var_b: float):
        self.mean_r = mean_r
        self.mean_g = mean_g
        self.mean_b = mean_b
        self.var_r = var_r
        self.var_g = var_g
        self.var_b = var_b

    @staticmethod
    def from_image(img: Image.Image) -> "ImageStatLite":
        px = list(img.getdata())
        n = len(px) or 1
        mr = sum(p[0] for p in px) / n
        mg = sum(p[1] for p in px) / n
        mb = sum(p[2] for p in px) / n
        vr = sum((p[0] - mr) ** 2 for p in px) / n
        vg = sum((p[1] - mg) ** 2 for p in px) / n
        vb = sum((p[2] - mb) ** 2 for p in px) / n
        return ImageStatLite(mr, mg, mb, vr, vg, vb)


def pick_icons(cells: list[Image.Image], n: int) -> list[Image.Image]:
    ranked = sorted(cells, key=score_cell, reverse=True)
    return ranked[: max(1, n)]


def draw_glow_rect(img: Image.Image, rect: tuple[int, int, int, int], color: tuple[int, int, int], alpha: int = 140) -> None:
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.rounded_rectangle(rect, radius=10, outline=(*color, alpha), width=2)
    glow = glow.filter(ImageFilter.GaussianBlur(2))
    img.alpha_composite(glow)


def build_background(base: Image.Image, grave: Image.Image, interior: Image.Image) -> Image.Image:
    out = dark_grade(base, sat=0.90, ctr=1.08, bri=0.90)
    grave_fit = dark_grade(cover_resize(grave, out.width, out.height), sat=0.75, ctr=1.14, bri=0.70)
    interior_fit = dark_grade(contain_resize(interior, int(out.width * 0.42), int(out.height * 0.86)), sat=0.80, ctr=1.08, bri=0.72)
    out = Image.blend(out, grave_fit, 0.22)
    out.alpha_composite(interior_fit, (int(out.width * 0.56), int(out.height * 0.06)))
    top_band = Image.new("RGBA", (out.width, 84), (10, 14, 22, 130))
    out.alpha_composite(top_band, (0, 0))
    out = add_vignette(out, alpha=88)
    return out


def char_frames(sheet: Image.Image) -> list[Image.Image]:
    cw = sheet.width // 4
    ch = sheet.height // 4
    sequence = [1, 2, 1, 0]
    frames: list[Image.Image] = []
    for r in range(4):
        for c in sequence:
            part = sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            bbox = part.getbbox()
            frames.append(part.crop(bbox) if bbox else part)
    return frames


def render_char_frame(sprite: Image.Image, fw: int, fh: int, idx: int, work: bool = False) -> Image.Image:
    out = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    target_h = int(fh * (0.70 if not work else 0.64))
    scale = target_h / max(1, sprite.height)
    s = sprite.resize((max(1, int(sprite.width * scale)), target_h), Image.Resampling.NEAREST)
    x = (fw - s.width) // 2 + int(4 * math.sin(idx * 0.5))
    y = fh - s.height - (36 if not work else 46) + int(2 * math.sin(idx * 0.6))
    shadow = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((x - 8, y + s.height - 18, x + s.width + 8, y + s.height - 2), fill=(6, 8, 16, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(3))
    out.alpha_composite(shadow)
    aura = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    ad = ImageDraw.Draw(aura)
    pulse = 80 + int(70 * (1 + math.sin(idx * 0.55)))
    ad.rounded_rectangle((x - 10, y - 6, x + s.width + 10, y + s.height + 4), radius=14, outline=(76, 160, 255, pulse), width=3)
    aura = aura.filter(ImageFilter.GaussianBlur(2))
    out.alpha_composite(aura)
    out.alpha_composite(s, (x, y))
    if work:
        panel_w, panel_h = int(fw * 0.50), int(fh * 0.20)
        panel = Image.new("RGBA", (panel_w, panel_h), (16, 22, 30, 220))
        pd = ImageDraw.Draw(panel)
        pd.rounded_rectangle((0, 0, panel_w - 1, panel_h - 1), radius=9, outline=(90, 150, 255, 210), width=2)
        for k in range(4):
            yy = 10 + k * 11
            pd.line((10, yy, panel_w - 10, yy), fill=(120, 220 if k % 2 else 170, 255, 200), width=2)
        out.alpha_composite(panel, ((fw - panel_w) // 2, fh - panel_h - 10))
    return out


def build_star_idle(sheet_a: Image.Image, sheet_b: Image.Image) -> Image.Image:
    a = char_frames(sheet_a)
    b = char_frames(sheet_b)
    frames: list[Image.Image] = []
    for i in range(48):
        src = a[i % len(a)] if i % 6 != 0 else b[(i // 3) % len(b)]
        frames.append(render_char_frame(src, 256, 256, idx=i, work=False))
    return compose_sheet(frames, cols=8, rows=6, fw=256, fh=256)


def build_star_work(sheet_a: Image.Image, sheet_b: Image.Image) -> Image.Image:
    a = char_frames(sheet_a)
    b = char_frames(sheet_b)
    frames: list[Image.Image] = []
    for i in range(40):
        src = a[(i * 2) % len(a)] if i % 5 else b[(i * 3) % len(b)]
        frames.append(render_char_frame(src, 300, 300, idx=i, work=True))
    return compose_sheet(frames, cols=8, rows=5, fw=300, fh=300)


def tint_sync(base: Image.Image) -> Image.Image:
    out = dark_grade(base, sat=0.90, ctr=1.10, bri=0.92)
    overlay = Image.new("RGBA", out.size, (70, 110, 255, 26))
    out.alpha_composite(overlay)
    return out


def decorate_frame(frame: Image.Image, icon: Image.Image, accent: tuple[int, int, int], pulse: int = 0) -> Image.Image:
    out = dark_grade(frame, sat=0.88, ctr=1.12, bri=0.88)
    draw_glow_rect(out, (6, 6, out.width - 7, out.height - 7), accent, alpha=110 + pulse)
    ic = contain_resize(icon, min(out.width, out.height) // 3, min(out.width, out.height) // 3)
    ox = (out.width - ic.width) // 2
    oy = (out.height - ic.height) // 2
    glow = Image.new("RGBA", out.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((ox - 10, oy - 8, ox + ic.width + 10, oy + ic.height + 8), fill=(*accent, 38 + pulse // 2))
    glow = glow.filter(ImageFilter.GaussianBlur(4))
    out.alpha_composite(glow)
    out.alpha_composite(ic, (ox, oy))
    return out


def build_posters(base: Image.Image, icons: list[Image.Image]) -> Image.Image:
    frames = split_sheet(base, 160, 160)
    new_frames: list[Image.Image] = []
    for i, fr in enumerate(frames):
        icon = icons[i % len(icons)]
        new_frames.append(decorate_frame(fr, icon, accent=(200, 160, 88), pulse=(i % 8) * 9))
    return compose_sheet(new_frames, cols=4, rows=8, fw=160, fh=160)


def build_plants(base: Image.Image, tree_frames: list[Image.Image]) -> Image.Image:
    frames = split_sheet(base, 160, 160)
    new_frames: list[Image.Image] = []
    for i, fr in enumerate(frames):
        icon = tree_frames[i % len(tree_frames)]
        icon = contain_resize(icon, 110, 110)
        out = dark_grade(fr, sat=0.82, ctr=1.08, bri=0.83)
        out.alpha_composite(icon, ((160 - icon.width) // 2, 28))
        draw_glow_rect(out, (12, 12, 148, 148), (90, 140, 210), alpha=90)
        new_frames.append(out)
    return compose_sheet(new_frames, cols=4, rows=4, fw=160, fh=160)


def build_desk(base: Image.Image, icon: Image.Image) -> Image.Image:
    out = dark_grade(base, sat=0.84, ctr=1.14, bri=0.84)
    draw_glow_rect(out, (14, 52, 260, 196), (130, 100, 70), alpha=120)
    ic = contain_resize(icon, 92, 92)
    out.alpha_composite(ic, ((out.width - ic.width) // 2, (out.height - ic.height) // 2 + 10))
    return out


def build_sofa(base: Image.Image, icon: Image.Image) -> Image.Image:
    out = dark_grade(base, sat=0.80, ctr=1.10, bri=0.82)
    ic = contain_resize(icon, 88, 88)
    out.alpha_composite(ic, ((out.width - ic.width) // 2, (out.height - ic.height) // 2 + 24))
    draw_glow_rect(out, (20, 96, 236, 236), (90, 120, 180), alpha=108)
    return out


def build_coffee(base: Image.Image, icons: list[Image.Image]) -> Image.Image:
    frames = split_sheet(base, 230, 230)
    new_frames: list[Image.Image] = []
    for i, fr in enumerate(frames):
        pulse = int(38 * (1 + math.sin(i * 0.23)))
        icon = icons[i % len(icons)]
        new_frames.append(decorate_frame(fr, icon, accent=(120, 180, 255), pulse=pulse))
    return compose_sheet(new_frames, cols=12, rows=8, fw=230, fh=230)


def build_server(base: Image.Image, icons: list[Image.Image]) -> Image.Image:
    frames = split_sheet(base, 180, 251)
    new_frames: list[Image.Image] = []
    for i, fr in enumerate(frames):
        out = dark_grade(fr, sat=0.84, ctr=1.12, bri=0.86)
        pulse = int(130 + 90 * (1 + math.sin(i * 0.45)))
        draw_glow_rect(out, (20, 18, 160, 232), (90, 150, 255), alpha=min(220, pulse))
        icon = contain_resize(icons[i % len(icons)], 34, 34)
        out.alpha_composite(icon, ((180 - icon.width) // 2, 194))
        new_frames.append(out)
    return compose_sheet(new_frames, cols=40, rows=1, fw=180, fh=251)


def save_webp(img: Image.Image, path: Path, quality: int = 92) -> None:
    img.convert("RGBA").save(path, format="WEBP", quality=quality, method=6)


def save_png(img: Image.Image, path: Path) -> None:
    img.convert("RGBA").save(path, format="PNG")


def build_v2(ctx: Ctx) -> dict[str, Path]:
    backup = latest_backup_dir(ctx.backups_root)
    ensure_dir(ctx.output_dir)

    # base/original assets from latest backup
    base = {
        "office_bg_small.webp": Image.open(backup / "office_bg_small.webp").convert("RGBA"),
        "office_bg.webp": Image.open(backup / "office_bg.webp").convert("RGBA"),
        "star-idle-v5.png": Image.open(backup / "star-idle-v5.png").convert("RGBA"),
        "star-working-spritesheet-grid.webp": Image.open(backup / "star-working-spritesheet-grid.webp").convert("RGBA"),
        "sync-animation-v3-grid.webp": Image.open(backup / "sync-animation-v3-grid.webp").convert("RGBA"),
        "desk-v3.webp": Image.open(backup / "desk-v3.webp").convert("RGBA"),
        "sofa-idle-v3.png": Image.open(backup / "sofa-idle-v3.png").convert("RGBA"),
        "posters-spritesheet.webp": Image.open(backup / "posters-spritesheet.webp").convert("RGBA"),
        "plants-spritesheet.webp": Image.open(backup / "plants-spritesheet.webp").convert("RGBA"),
        "coffee-machine-v3-grid.webp": Image.open(backup / "coffee-machine-v3-grid.webp").convert("RGBA"),
        "coffee-machine-shadow-v1.png": Image.open(backup / "coffee-machine-shadow-v1.png").convert("RGBA"),
        "serverroom-spritesheet.webp": Image.open(backup / "serverroom-spritesheet.webp").convert("RGBA"),
    }

    # source overlays
    grave = extract_image(ctx.graveyard_archive, "ForestGraveyardRPGMakerExample1088x832.png")
    interior = extract_image(ctx.interior_archive, "Pixel_Interiors/Interior.png")
    char_a = extract_image(ctx.char_archive, "Characters/314-黑魔法导师.png")
    char_b = extract_image(ctx.char_archive, "Characters/229-贵族将军.png")
    props = extract_image(ctx.dungeon_archive, "Tiles-Props-pack.png")
    items = extract_image(ctx.dungeon_archive, "Tiles-Items-pack.png")

    props_cells = pick_icons(cells_from_sheet(props, 32), 64)
    items_cells = pick_icons(cells_from_sheet(items, 32), 64)
    all_icons = props_cells[:32] + items_cells[:32]

    tree_frames: list[Image.Image] = []
    for i in range(1, 9):
        try:
            tree_frames.append(extract_image(ctx.graveyard_archive, f"Tilemaps/AnimatedTreeFrames/Redtree{i}.png"))
        except Exception:
            pass
    if not tree_frames:
        tree_frames = all_icons[:8]

    outputs: dict[str, Path] = {}

    bg_small = build_background(base["office_bg_small.webp"], grave, interior)
    outputs["office_bg_small.webp"] = ctx.output_dir / "office_bg_small.webp"
    save_webp(bg_small, outputs["office_bg_small.webp"], quality=93)

    bg = build_background(base["office_bg.webp"], grave, interior)
    outputs["office_bg.webp"] = ctx.output_dir / "office_bg.webp"
    save_webp(bg, outputs["office_bg.webp"], quality=92)

    star_idle = build_star_idle(char_a, char_b)
    outputs["star-idle-v5.png"] = ctx.output_dir / "star-idle-v5.png"
    save_png(star_idle, outputs["star-idle-v5.png"])

    star_work = build_star_work(char_a, char_b)
    outputs["star-working-spritesheet-grid.webp"] = ctx.output_dir / "star-working-spritesheet-grid.webp"
    save_webp(star_work, outputs["star-working-spritesheet-grid.webp"], quality=93)

    sync = tint_sync(base["sync-animation-v3-grid.webp"])
    outputs["sync-animation-v3-grid.webp"] = ctx.output_dir / "sync-animation-v3-grid.webp"
    save_webp(sync, outputs["sync-animation-v3-grid.webp"], quality=92)

    desk = build_desk(base["desk-v3.webp"], all_icons[0])
    outputs["desk-v3.webp"] = ctx.output_dir / "desk-v3.webp"
    save_webp(desk, outputs["desk-v3.webp"], quality=92)

    sofa = build_sofa(base["sofa-idle-v3.png"], all_icons[5])
    outputs["sofa-idle-v3.png"] = ctx.output_dir / "sofa-idle-v3.png"
    save_png(sofa, outputs["sofa-idle-v3.png"])

    posters = build_posters(base["posters-spritesheet.webp"], all_icons)
    outputs["posters-spritesheet.webp"] = ctx.output_dir / "posters-spritesheet.webp"
    save_webp(posters, outputs["posters-spritesheet.webp"], quality=92)

    plants = build_plants(base["plants-spritesheet.webp"], tree_frames)
    outputs["plants-spritesheet.webp"] = ctx.output_dir / "plants-spritesheet.webp"
    save_webp(plants, outputs["plants-spritesheet.webp"], quality=92)

    coffee = build_coffee(base["coffee-machine-v3-grid.webp"], all_icons)
    outputs["coffee-machine-v3-grid.webp"] = ctx.output_dir / "coffee-machine-v3-grid.webp"
    save_webp(coffee, outputs["coffee-machine-v3-grid.webp"], quality=92)

    server = build_server(base["serverroom-spritesheet.webp"], all_icons)
    outputs["serverroom-spritesheet.webp"] = ctx.output_dir / "serverroom-spritesheet.webp"
    save_webp(server, outputs["serverroom-spritesheet.webp"], quality=92)

    shadow = dark_grade(base["coffee-machine-shadow-v1.png"], sat=0.9, ctr=1.0, bri=0.75)
    outputs["coffee-machine-shadow-v1.png"] = ctx.output_dir / "coffee-machine-shadow-v1.png"
    save_png(shadow, outputs["coffee-machine-shadow-v1.png"])

    readme = ctx.output_dir / "README.md"
    readme.write_text(
        "\n".join(
            [
                "# Dark Fantasy Pack v2 (Refined)",
                "",
                "- 方案：基于原资产结构逐帧风格化，保证动画网格与锚点稳定。",
                "- 来源：本地素材库（人物/墓地/地牢/室内）+ 官方备份资产。",
                "- 生成时间：" + datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "",
                "## 输出资产",
                *[f"- `{k}`" for k in sorted(outputs.keys())],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return outputs


def apply_outputs(ctx: Ctx, outputs: dict[str, Path]) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = ctx.subproject_root / "materials" / "packs" / "backups" / f"star-office-ui-v2-{timestamp}"
    ensure_dir(backup_dir)
    for name, src in outputs.items():
        dst = ctx.frontend_dir / name
        if dst.exists():
            shutil.copy2(dst, backup_dir / name)
        shutil.copy2(src, dst)
    return backup_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate and apply dark fantasy v2 pack")
    parser.add_argument("--build", action="store_true", help="Build dark-fantasy-v2 pack")
    parser.add_argument("--apply", action="store_true", help="Apply pack to frontend")
    args = parser.parse_args()

    if not args.build and not args.apply:
        parser.error("need --build and/or --apply")

    ctx = build_ctx()
    outputs: dict[str, Path] = {}

    if args.build:
        outputs = build_v2(ctx)
        print(f"[ok] built pack: {ctx.output_dir}")
        for k in sorted(outputs):
            print(f"  - {k}: {outputs[k]}")

    if args.apply:
        if not outputs:
            for n in (
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
            ):
                p = ctx.output_dir / n
                if p.exists():
                    outputs[n] = p
        if not outputs:
            raise RuntimeError("no v2 outputs found; run with --build first")
        backup = apply_outputs(ctx, outputs)
        print(f"[ok] applied v2 assets to: {ctx.frontend_dir}")
        print(f"[ok] rollback backup: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
