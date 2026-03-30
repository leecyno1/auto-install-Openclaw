#!/usr/bin/env python3
"""
Generate a dark-fantasy pixel asset pack for Star Office UI from local archive library.

Usage:
  python3 scripts/generate_dark_fantasy_pack.py --build
  python3 scripts/generate_dark_fantasy_pack.py --build --apply
"""

from __future__ import annotations

import argparse
import io
import random
import shutil
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


RNG = random.Random(20260329)


@dataclass(frozen=True)
class Ctx:
    repo_root: Path
    subproject_root: Path
    frontend_dir: Path
    pack_dir: Path
    source_root: Path
    char_archive: Path
    graveyard_archive: Path
    dungeon_archive: Path
    interior_archive: Path


def build_ctx() -> Ctx:
    repo_root = Path(__file__).resolve().parents[2]
    subproject_root = Path(__file__).resolve().parents[1]
    frontend_dir = subproject_root / "vendor" / "star-office-ui" / "frontend"
    pack_dir = subproject_root / "materials" / "packs" / "dark-fantasy-v1"
    source_root = Path(
        "/Volumes/PSSD/A051RPG像素游戏素材地图场景平铺图块rpgmaker人物角色UI道具美术资源/2000套-像素风格游戏素材"
    )
    return Ctx(
        repo_root=repo_root,
        subproject_root=subproject_root,
        frontend_dir=frontend_dir,
        pack_dir=pack_dir,
        source_root=source_root,
        char_archive=source_root / "人物行走图素材(XP)(2937个).rar",
        graveyard_archive=source_root / "RPG像素风格森林郊外墓地恐怖暗黑场景地图素材.zip",
        dungeon_archive=source_root / "像素地牢游戏关卡场景地图图块素材.zip",
        interior_archive=source_root / "室内像素风格地图场景图块元素游戏素材.zip",
    )


def extract_image(archive: Path, member: str) -> Image.Image:
    proc = subprocess.run(
        ["bsdtar", "-xOf", str(archive), member],
        check=True,
        capture_output=True,
    )
    return Image.open(io.BytesIO(proc.stdout)).convert("RGBA")


def safe_extract_image(archive: Path, member: str) -> Image.Image | None:
    try:
        return extract_image(archive, member)
    except Exception:
        return None


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def cover_resize(img: Image.Image, width: int, height: int) -> Image.Image:
    src_w, src_h = img.size
    scale = max(width / src_w, height / src_h)
    resized = img.resize((int(src_w * scale), int(src_h * scale)), Image.Resampling.NEAREST)
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def contain_resize(img: Image.Image, width: int, height: int) -> Image.Image:
    src_w, src_h = img.size
    scale = min(width / src_w, height / src_h)
    resized = img.resize((max(1, int(src_w * scale)), max(1, int(src_h * scale))), Image.Resampling.NEAREST)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.alpha_composite(resized, ((width - resized.width) // 2, (height - resized.height) // 2))
    return out


def grade_dark_fantasy(img: Image.Image) -> Image.Image:
    base = img.convert("RGB")
    base = ImageEnhance.Color(base).enhance(0.82)
    base = ImageEnhance.Contrast(base).enhance(1.18)
    base = ImageEnhance.Brightness(base).enhance(0.86)
    r, g, b = base.split()
    b = b.point(lambda v: min(255, int(v * 1.12)))
    r = r.point(lambda v: min(255, int(v * 0.95)))
    return Image.merge("RGB", (r, g, b)).convert("RGBA")


def add_vignette(img: Image.Image, strength: int = 110) -> Image.Image:
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rectangle((0, 0, w, h), fill=255)
    blur = max(20, min(w, h) // 7)
    inner = (int(w * 0.08), int(h * 0.08), int(w * 0.92), int(h * 0.92))
    cut = Image.new("L", (w, h), 0)
    ImageDraw.Draw(cut).rectangle(inner, fill=255)
    cut = cut.filter(ImageFilter.GaussianBlur(blur))
    inv = ImageOps.invert(cut)
    overlay = Image.new("RGBA", (w, h), (8, 10, 20, strength))
    overlay.putalpha(inv)
    out = img.copy()
    out.alpha_composite(overlay)
    return out


def tile_fill(texture: Image.Image, width: int, height: int, tile_size: int = 32) -> Image.Image:
    texture = texture.convert("RGBA")
    if texture.width < tile_size or texture.height < tile_size:
        texture = contain_resize(texture, tile_size, tile_size)
    x_count = max(1, texture.width // tile_size)
    y_count = max(1, texture.height // tile_size)
    cells: list[Image.Image] = []
    for y in range(y_count):
        for x in range(x_count):
            c = texture.crop((x * tile_size, y * tile_size, (x + 1) * tile_size, (y + 1) * tile_size))
            alpha_nonzero = c.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox() is not None
            if alpha_nonzero:
                cells.append(c)
    if not cells:
        cells = [contain_resize(texture, tile_size, tile_size)]
    out = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    for y in range(0, height, tile_size):
        for x in range(0, width, tile_size):
            out.alpha_composite(RNG.choice(cells), (x, y))
    return out


def extract_cells(sprite: Image.Image, cell: int = 32) -> list[Image.Image]:
    sprite = sprite.convert("RGBA")
    cells: list[Image.Image] = []
    for y in range(0, sprite.height, cell):
        for x in range(0, sprite.width, cell):
            c = sprite.crop((x, y, min(x + cell, sprite.width), min(y + cell, sprite.height)))
            if c.width != cell or c.height != cell:
                continue
            alpha = c.getchannel("A")
            if alpha.getbbox() is None:
                continue
            cells.append(c)
    return cells


def load_base_sources(ctx: Ctx) -> dict[str, Image.Image]:
    char_sheet = extract_image(ctx.char_archive, "Characters/314-黑魔法导师.png")
    bg_map = extract_image(ctx.graveyard_archive, "ForestGraveyardRPGMakerExample1088x832.png")
    props = extract_image(ctx.dungeon_archive, "Tiles-Props-pack.png")
    items = extract_image(ctx.dungeon_archive, "Tiles-Items-pack.png")
    sand = extract_image(ctx.dungeon_archive, "Tiles-SandstoneDungeons.png")
    interior = extract_image(ctx.interior_archive, "Pixel_Interiors/Interior.png")
    return {
        "char_sheet": char_sheet,
        "bg_map": bg_map,
        "props": props,
        "items": items,
        "sand": sand,
        "interior": interior,
    }


def char_frames_from_sheet(sheet: Image.Image) -> list[Image.Image]:
    cols = 4
    rows = 4
    cw = max(1, sheet.width // cols)
    ch = max(1, sheet.height // rows)
    frames: list[Image.Image] = []
    walk_cols = [1, 2, 1, 0]
    for r in range(rows):
        for c in walk_cols:
            crop = sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            bbox = crop.getbbox()
            frames.append(crop.crop(bbox) if bbox else crop)
    return frames


def draw_shadow(canvas: Image.Image, x: int, y: int, w: int, h: int, alpha: int = 110) -> None:
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(sh)
    draw.ellipse((x, y, x + w, y + h), fill=(6, 8, 12, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(4))
    canvas.alpha_composite(sh)


def make_character_frame(
    sprite: Image.Image,
    frame_w: int,
    frame_h: int,
    offset_x: int,
    bob: int,
    aura_strength: int = 0,
    working: bool = False,
) -> Image.Image:
    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    target_h = int(frame_h * (0.72 if not working else 0.66))
    scale = target_h / max(1, sprite.height)
    s = sprite.resize((max(1, int(sprite.width * scale)), target_h), Image.Resampling.NEAREST)
    x = (frame_w - s.width) // 2 + offset_x
    y = frame_h - s.height - (34 if not working else 42) + bob
    draw_shadow(frame, x - 4, y + s.height - 16, s.width + 8, 18, alpha=120)
    if aura_strength > 0:
        aura = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
        ad = ImageDraw.Draw(aura)
        ax0, ay0 = x - 10, y - 6
        ax1, ay1 = x + s.width + 10, y + s.height + 4
        ad.rounded_rectangle((ax0, ay0, ax1, ay1), radius=16, outline=(70, 130, 255, aura_strength), width=3)
        aura = aura.filter(ImageFilter.GaussianBlur(3))
        frame.alpha_composite(aura)
    frame.alpha_composite(s, (x, y))
    if working:
        console = Image.new("RGBA", (int(frame_w * 0.52), int(frame_h * 0.23)), (18, 24, 30, 225))
        cd = ImageDraw.Draw(console)
        cd.rounded_rectangle((0, 0, console.width - 1, console.height - 1), radius=10, outline=(100, 160, 255, 190), width=2)
        for k in range(5):
            yy = 12 + k * 11
            cd.line((10, yy, console.width - 12, yy), fill=(110, 220 if k % 2 == 0 else 160, 255, 200), width=2)
        frame.alpha_composite(console, ((frame_w - console.width) // 2, frame_h - console.height - 12))
    return frame


def compose_grid(frames: Iterable[Image.Image], cols: int, rows: int, frame_w: int, frame_h: int) -> Image.Image:
    out = Image.new("RGBA", (cols * frame_w, rows * frame_h), (0, 0, 0, 0))
    seq = list(frames)
    assert len(seq) >= cols * rows
    i = 0
    for y in range(rows):
        for x in range(cols):
            out.alpha_composite(seq[i], (x * frame_w, y * frame_h))
            i += 1
    return out


def build_bg(base: dict[str, Image.Image]) -> Image.Image:
    bg = cover_resize(base["bg_map"], 1280, 720)
    interior_overlay = contain_resize(base["interior"], 640, 640)
    interior_overlay = grade_dark_fantasy(interior_overlay)
    interior_overlay = ImageEnhance.Brightness(interior_overlay).enhance(0.65)
    bg = grade_dark_fantasy(bg)
    bg.alpha_composite(interior_overlay, (640, 42))
    # subtle top strip for UI readability
    top = Image.new("RGBA", (1280, 86), (8, 10, 16, 130))
    bg.alpha_composite(top, (0, 0))
    return add_vignette(bg, strength=120)


def build_star_idle(char_sheet: Image.Image) -> Image.Image:
    base_frames = char_frames_from_sheet(char_sheet)
    frames: list[Image.Image] = []
    for i in range(8 * 6):
        spr = base_frames[i % len(base_frames)]
        aura = 140 if i % 6 in (2, 3) else 70
        bob = -4 if i % 8 in (3, 4) else 0
        offset_x = -4 if (i % 4) == 1 else 0
        frames.append(make_character_frame(spr, 256, 256, offset_x=offset_x, bob=bob, aura_strength=aura, working=False))
    return compose_grid(frames, cols=8, rows=6, frame_w=256, frame_h=256)


def build_star_working(char_sheet: Image.Image) -> Image.Image:
    base_frames = char_frames_from_sheet(char_sheet)
    frames: list[Image.Image] = []
    for i in range(8 * 5):
        spr = base_frames[(i * 2) % len(base_frames)]
        aura = 155 if i % 5 in (1, 2, 3) else 80
        bob = -6 if i % 7 in (3, 4) else 0
        offset_x = -8 if i % 3 == 0 else (6 if i % 3 == 2 else 0)
        frames.append(make_character_frame(spr, 300, 300, offset_x=offset_x, bob=bob, aura_strength=aura, working=True))
    return compose_grid(frames, cols=8, rows=5, frame_w=300, frame_h=300)


def build_sync_anim() -> Image.Image:
    cols = rows = 7
    fw = fh = 256
    frames: list[Image.Image] = []
    for i in range(cols * rows):
        f = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        d = ImageDraw.Draw(f)
        t = i / (cols * rows)
        r1 = 46 + int(22 * (1 + (t * 6.28)))
        r2 = 84 + int(28 * (1 + (t * 6.28)))
        r3 = 114 + int(24 * (1 + (t * 6.28)))
        cx, cy = fw // 2, fh // 2
        for rr, a, col in (
            (r3, 70, (80, 140, 255)),
            (r2, 120, (190, 90, 255)),
            (r1, 180, (110, 210, 255)),
        ):
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=(*col, a), width=3)
        for k in range(8):
            ang = (i * 0.19 + k * 0.78)
            px = int(cx + (r2 + 8) * (0.85 if k % 2 else 1.0) * __import__("math").cos(ang))
            py = int(cy + (r2 + 8) * (0.85 if k % 2 else 1.0) * __import__("math").sin(ang))
            d.ellipse((px - 4, py - 4, px + 4, py + 4), fill=(255, 180 if k % 2 else 220, 70, 220))
        f = f.filter(ImageFilter.GaussianBlur(0.5))
        frames.append(f)
    return compose_grid(frames, cols=cols, rows=rows, frame_w=fw, frame_h=fh)


def build_posters(props_cells: list[Image.Image], items_cells: list[Image.Image], sand: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (640, 1280), (0, 0, 0, 0))
    frames = 32
    for i in range(frames):
        frame = tile_fill(sand, 160, 160, tile_size=32)
        frame = grade_dark_fantasy(frame)
        frame = ImageEnhance.Brightness(frame).enhance(0.7)
        icon = RNG.choice(items_cells if i % 2 else props_cells)
        icon = contain_resize(icon, 116, 116)
        icon = ImageEnhance.Color(icon).enhance(1.25)
        # metallic frame
        d = ImageDraw.Draw(frame)
        d.rectangle((2, 2, 157, 157), outline=(196, 162, 80, 230), width=3)
        d.rectangle((10, 10, 149, 149), outline=(76, 90, 130, 160), width=2)
        frame.alpha_composite(icon, (22, 22))
        x = (i % 4) * 160
        y = (i // 4) * 160
        out.alpha_composite(frame, (x, y))
    return out


def build_plants(tree_frames: list[Image.Image], sand: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (640, 640), (0, 0, 0, 0))
    for i in range(16):
        frame = tile_fill(sand, 160, 160, tile_size=32)
        frame = ImageEnhance.Brightness(grade_dark_fantasy(frame)).enhance(0.62)
        tree = contain_resize(tree_frames[i % max(1, len(tree_frames))], 132, 132)
        tree = ImageEnhance.Color(tree).enhance(0.9)
        tree = ImageEnhance.Brightness(tree).enhance(0.95)
        frame.alpha_composite(tree, (14, 16))
        d = ImageDraw.Draw(frame)
        d.rectangle((4, 4, 155, 155), outline=(56, 80, 110, 170), width=2)
        x = (i % 4) * 160
        y = (i // 4) * 160
        out.alpha_composite(frame, (x, y))
    return out


def build_desk(props_cells: list[Image.Image], sand: Image.Image) -> Image.Image:
    base = tile_fill(sand, 276, 214, tile_size=32)
    base = ImageEnhance.Brightness(grade_dark_fantasy(base)).enhance(0.7)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((22, 74, 252, 182), radius=14, fill=(24, 28, 36, 230), outline=(150, 110, 66, 210), width=3)
    d.rectangle((30, 88, 244, 170), outline=(80, 110, 160, 180), width=2)
    icon = contain_resize(RNG.choice(props_cells), 92, 92)
    base.alpha_composite(icon, (92, 74))
    return base


def build_sofa(items_cells: list[Image.Image], sand: Image.Image) -> Image.Image:
    base = tile_fill(sand, 256, 256, tile_size=32)
    base = ImageEnhance.Brightness(grade_dark_fantasy(base)).enhance(0.66)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((26, 120, 230, 214), radius=18, fill=(28, 34, 44, 238), outline=(130, 160, 210, 180), width=3)
    d.rounded_rectangle((40, 90, 216, 134), radius=14, fill=(40, 48, 62, 238), outline=(90, 120, 160, 170), width=2)
    icon = contain_resize(RNG.choice(items_cells), 84, 84)
    base.alpha_composite(icon, (86, 132))
    return base


def build_coffee_machine(props_cells: list[Image.Image], items_cells: list[Image.Image], sand: Image.Image) -> Image.Image:
    cols, rows = 12, 8
    fw, fh = 230, 230
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i in range(cols * rows):
        frame = tile_fill(sand, fw, fh, tile_size=32)
        frame = ImageEnhance.Brightness(grade_dark_fantasy(frame)).enhance(0.68)
        d = ImageDraw.Draw(frame)
        d.rounded_rectangle((48, 28, 182, 196), radius=16, fill=(24, 30, 36, 240), outline=(138, 103, 64, 220), width=3)
        glow = 60 + (i % 8) * 18
        d.rounded_rectangle((72, 54, 160, 126), radius=8, fill=(24, 40, 58, 255), outline=(80, 160, 255, glow + 60), width=2)
        d.ellipse((96, 146, 134, 184), fill=(80, 120, 180, 200), outline=(170, 200, 255, 220), width=2)
        rune = contain_resize(RNG.choice(items_cells if i % 2 else props_cells), 50, 50)
        frame.alpha_composite(rune, (90, 72))
        x = (i % cols) * fw
        y = (i // cols) * fh
        out.alpha_composite(frame, (x, y))
    return out


def build_serverroom(props_cells: list[Image.Image], sand: Image.Image) -> Image.Image:
    cols, rows = 40, 1
    fw, fh = 180, 251
    out = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i in range(cols):
        frame = tile_fill(sand, fw, fh, tile_size=32)
        frame = ImageEnhance.Brightness(grade_dark_fantasy(frame)).enhance(0.7)
        d = ImageDraw.Draw(frame)
        d.rounded_rectangle((24, 22, 156, 226), radius=12, fill=(18, 22, 30, 236), outline=(90, 110, 150, 170), width=3)
        for k in range(6):
            y = 38 + k * 28
            pulse = 80 if (i + k) % 5 else 230
            d.rectangle((40, y, 140, y + 12), fill=(26, 32, 46, 220), outline=(80, 170, 255, pulse), width=2)
        icon = contain_resize(RNG.choice(props_cells), 40, 40)
        frame.alpha_composite(icon, (70, 194))
        out.alpha_composite(frame, (i * fw, 0))
    return out


def save_webp(img: Image.Image, path: Path, quality: int = 90) -> None:
    img.convert("RGBA").save(path, format="WEBP", quality=quality, method=6)


def save_png(img: Image.Image, path: Path) -> None:
    img.convert("RGBA").save(path, format="PNG")


def build_pack(ctx: Ctx) -> dict[str, Path]:
    ensure_dir(ctx.pack_dir)
    sources = load_base_sources(ctx)
    props_cells = extract_cells(sources["props"], cell=32)
    items_cells = extract_cells(sources["items"], cell=32)
    tree_frames = []
    for idx in range(1, 9):
        m = f"Tilemaps/AnimatedTreeFrames/Redtree{idx}.png"
        f = safe_extract_image(ctx.graveyard_archive, m)
        if f is not None:
            tree_frames.append(f)
    if not tree_frames:
        tree_frames = props_cells[:8] if props_cells else [sources["props"]]

    outputs: dict[str, Path] = {}

    bg = build_bg(sources)
    outputs["office_bg_small.webp"] = ctx.pack_dir / "office_bg_small.webp"
    save_webp(bg, outputs["office_bg_small.webp"], quality=92)
    outputs["office_bg.webp"] = ctx.pack_dir / "office_bg.webp"
    save_webp(bg, outputs["office_bg.webp"], quality=90)

    star_idle = build_star_idle(sources["char_sheet"])
    outputs["star-idle-v5.png"] = ctx.pack_dir / "star-idle-v5.png"
    save_png(star_idle, outputs["star-idle-v5.png"])

    star_working = build_star_working(sources["char_sheet"])
    outputs["star-working-spritesheet-grid.webp"] = ctx.pack_dir / "star-working-spritesheet-grid.webp"
    save_webp(star_working, outputs["star-working-spritesheet-grid.webp"], quality=92)

    sync_anim = build_sync_anim()
    outputs["sync-animation-v3-grid.webp"] = ctx.pack_dir / "sync-animation-v3-grid.webp"
    save_webp(sync_anim, outputs["sync-animation-v3-grid.webp"], quality=92)

    desk = build_desk(props_cells, sources["sand"])
    outputs["desk-v3.webp"] = ctx.pack_dir / "desk-v3.webp"
    save_webp(desk, outputs["desk-v3.webp"], quality=90)

    sofa = build_sofa(items_cells, sources["sand"])
    outputs["sofa-idle-v3.png"] = ctx.pack_dir / "sofa-idle-v3.png"
    save_png(sofa, outputs["sofa-idle-v3.png"])

    posters = build_posters(props_cells, items_cells, sources["sand"])
    outputs["posters-spritesheet.webp"] = ctx.pack_dir / "posters-spritesheet.webp"
    save_webp(posters, outputs["posters-spritesheet.webp"], quality=90)

    plants = build_plants(tree_frames, sources["sand"])
    outputs["plants-spritesheet.webp"] = ctx.pack_dir / "plants-spritesheet.webp"
    save_webp(plants, outputs["plants-spritesheet.webp"], quality=90)

    coffee = build_coffee_machine(props_cells, items_cells, sources["sand"])
    outputs["coffee-machine-v3-grid.webp"] = ctx.pack_dir / "coffee-machine-v3-grid.webp"
    save_webp(coffee, outputs["coffee-machine-v3-grid.webp"], quality=90)

    server = build_serverroom(props_cells, sources["sand"])
    outputs["serverroom-spritesheet.webp"] = ctx.pack_dir / "serverroom-spritesheet.webp"
    save_webp(server, outputs["serverroom-spritesheet.webp"], quality=90)

    # keep shadow with same size, darkened variant
    shadow_src = ctx.frontend_dir / "coffee-machine-shadow-v1.png"
    if shadow_src.exists():
        shadow = Image.open(shadow_src).convert("RGBA")
        shadow = ImageEnhance.Brightness(shadow).enhance(0.8)
        outputs["coffee-machine-shadow-v1.png"] = ctx.pack_dir / "coffee-machine-shadow-v1.png"
        save_png(shadow, outputs["coffee-machine-shadow-v1.png"])

    readme = ctx.pack_dir / "README.md"
    readme.write_text(
        "\n".join(
            [
                "# Dark Fantasy Pack v1",
                "",
                "- 来源：本地像素素材库（地牢/墓地/人物素材）+ 自动尺寸适配。",
                "- 目标：替换 `star-office-ui` 的主要人物、房屋背景、关键设施素材。",
                "- 生成时间：" + datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "",
                "## 目标文件",
                *[f"- `{k}`" for k in sorted(outputs.keys())],
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return outputs


def apply_pack(ctx: Ctx, outputs: dict[str, Path]) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = ctx.subproject_root / "materials" / "packs" / "backups" / f"star-office-ui-{timestamp}"
    ensure_dir(backup_dir)
    for name, src in outputs.items():
        target = ctx.frontend_dir / name
        if target.exists():
            shutil.copy2(target, backup_dir / name)
        shutil.copy2(src, target)
    return backup_dir


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate dark fantasy pixel asset pack")
    parser.add_argument("--build", action="store_true", help="Build pack assets")
    parser.add_argument("--apply", action="store_true", help="Apply generated assets to frontend")
    args = parser.parse_args()

    if not args.build and not args.apply:
        parser.error("at least one flag required: --build and/or --apply")

    ctx = build_ctx()
    outputs: dict[str, Path] = {}
    if args.build:
        outputs = build_pack(ctx)
        print(f"[ok] built pack: {ctx.pack_dir}")
        for k in sorted(outputs):
            print(f"  - {k}: {outputs[k]}")

    if args.apply:
        if not outputs:
            # apply latest generated files
            outputs = {}
            for name in (
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
                p = ctx.pack_dir / name
                if p.exists():
                    outputs[name] = p
        if not outputs:
            raise RuntimeError("no pack artifacts found, run --build first")
        backup = apply_pack(ctx, outputs)
        print(f"[ok] applied assets to: {ctx.frontend_dir}")
        print(f"[ok] backup saved at: {backup}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
