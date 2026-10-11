"""
The Last Knight - asset generator
---------------------------------
สร้าง asset ทั้งหมดของเกมจากแพ็ก Legacy-Fantasy High Forest (ที่อยู่ใน Assets/Tileset)
และวาด asset เพิ่มเติม (กับดัก ไอเท็ม พื้นหลัง เพลง) ด้วยโค้ด

    python tools/make_assets.py

ผลลัพธ์ทั้งหมดอยู่ที่ Assets/LastKnight/
"""
import math
import os
import random
import wave
from collections import defaultdict

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "Assets", "Tileset", "Legacy-Fantasy - High Forest 2.3")
DEBUG_PACK = os.path.join(ROOT, "Assets", "Tileset", "Legacy Fantasy - Debug Map")
OUT = os.path.join(ROOT, "Assets", "LastKnight")
SCALE = 2  # pixel-art scale (16px tile -> 32px)

random.seed(7)


def out(*parts):
    path = os.path.join(OUT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def load(path):
    return Image.open(path).convert("RGBA")


def up(img, s=SCALE):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


# ---------------------------------------------------------------------------
# Characters
# ---------------------------------------------------------------------------
# Each source sheet: (file, frame count, anchor = foot point inside a frame)
HERO_SHEETS = [
    ("idle", "Character/Idle/Idle-Sheet.png", 4, (32, 64)),
    ("run", "Character/Run/Run-Sheet.png", 8, (42, 66)),
    ("attack", "Character/Attack-01/Attack-01-Sheet.png", 8, (48, 64)),
    ("jump", "Character/Jumlp-All/Jump-All-Sheet.png", 15, (24, 64)),
    ("dead", "Character/Dead/Dead-Sheet.png", 8, (32, 48)),
]
CELL_W, CELL_H = 112, 96
ANCHOR = (56, 84)  # foot point inside a packed cell


def pack_character(recolor=None):
    """Repack all hero sheets into one sheet: one row per animation, feet aligned."""
    cols = max(n for _, _, n, _ in HERO_SHEETS)
    sheet = Image.new("RGBA", (cols * CELL_W, len(HERO_SHEETS) * CELL_H))
    for row, (_, path, n, (ax, ay)) in enumerate(HERO_SHEETS):
        src = load(os.path.join(PACK, path))
        fw = src.width // n
        for i in range(n):
            frame = src.crop((i * fw, 0, (i + 1) * fw, src.height))
            if recolor:
                frame = recolor(frame)
            sheet.alpha_composite(frame, (i * CELL_W + ANCHOR[0] - ax, row * CELL_H + ANCHOR[1] - ay))
    return sheet


def palette_map(mapping, default=None):
    def fn(img):
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                if (r, g, b) in mapping:
                    px[x, y] = mapping[(r, g, b)] + (a,)
                elif default:
                    px[x, y] = default((r, g, b)) + (a,)
        return img
    return fn


ZOMBIE_MAP = {
    # skin -> rotten green
    (239, 193, 147): (148, 176, 118),
    (188, 131, 86): (104, 134, 84),
    (156, 96, 76): (78, 104, 64),
    (143, 79, 52): (64, 88, 52),
    # hair -> dirty dark
    (219, 219, 226): (92, 98, 84),
    (241, 241, 241): (120, 126, 110),
    (182, 182, 182): (74, 80, 68),
    (200, 188, 180): (96, 90, 80),
    # shirt -> torn grey-blue
    (171, 154, 110): (96, 100, 118),
    (118, 106, 85): (70, 72, 88),
    (82, 66, 56): (48, 48, 62),
    # gold hilt -> rust
    (241, 193, 70): (150, 92, 54),
    (139, 107, 28): (104, 62, 40),
    (90, 68, 13): (70, 40, 28),
    # eyes -> glowing red
    (0, 125, 255): (255, 40, 40),
}

BOSS_MAP = {
    (239, 193, 147): (170, 160, 190),
    (188, 131, 86): (124, 110, 150),
    (156, 96, 76): (96, 80, 120),
    (143, 79, 52): (80, 64, 104),
    (219, 219, 226): (40, 30, 52),
    (241, 241, 241): (64, 50, 80),
    (182, 182, 182): (30, 22, 40),
    (200, 188, 180): (52, 40, 64),
    (171, 154, 110): (90, 30, 120),
    (118, 106, 85): (62, 20, 86),
    (82, 66, 56): (40, 12, 58),
    (103, 61, 49): (40, 36, 48),
    (75, 47, 37): (28, 24, 36),
    (48, 28, 25): (18, 14, 24),
    (138, 138, 143): (150, 60, 200),
    (83, 83, 90): (100, 30, 150),
    (52, 52, 58): (60, 20, 90),
    (241, 193, 70): (220, 60, 255),
    (139, 107, 28): (150, 40, 190),
    (90, 68, 13): (100, 20, 130),
    (0, 125, 255): (255, 0, 200),
}


def tint(img, color, amount=0.6, keep_luma=True):
    """Colorize an RGBA image toward `color` keeping brightness."""
    arr = np.asarray(img).astype(np.float32)
    rgb, a = arr[..., :3], arr[..., 3:]
    luma = (rgb @ np.array([0.299, 0.587, 0.114]))[..., None] / 255.0
    target = np.array(color, np.float32)[None, None, :] * (luma * 1.6 if keep_luma else 1)
    res = rgb * (1 - amount) + np.clip(target, 0, 255) * amount
    return Image.fromarray(np.concatenate([np.clip(res, 0, 255), a], -1).astype(np.uint8))


def make_characters():
    up(pack_character()).save(out("characters", "knight.png"))
    up(pack_character(palette_map(ZOMBIE_MAP))).save(out("characters", "zombie.png"))
    up(pack_character(palette_map(BOSS_MAP))).save(out("characters", "necro_knight.png"))

    # Zombie boar: run (6 frames 48x32) + hit (4 frames)
    run = load(os.path.join(PACK, "Mob/Boar/Run/Run-Sheet.png"))
    hit = load(os.path.join(PACK, "Mob/Boar/Hit-Vanish/Hit-Sheet.png"))
    boar = Image.new("RGBA", (6 * 48, 64))
    boar.alpha_composite(run, (0, 0))
    boar.alpha_composite(hit, (0, 32))
    boar = tint(boar, (120, 170, 90), 0.55)
    # red glowing eye
    px = boar.load()
    for y in range(boar.height):
        for x in range(boar.width):
            r, g, b, a = px[x, y]
            if a and r > 200 and g > 200 and b > 200:
                px[x, y] = (255, 50, 50, a)
    up(boar).save(out("characters", "zombie_boar.png"))

    # Ghost wasp: fly (4 frames 64x64) + hit
    fly = load(os.path.join(PACK, "Mob/Small Bee/Fly/Fly-Sheet.png"))
    bhit = load(os.path.join(PACK, "Mob/Small Bee/Hit/Hit-Sheet.png"))
    bee = Image.new("RGBA", (256, 128))
    bee.alpha_composite(fly, (0, 0))
    bee.alpha_composite(bhit, (0, 64))
    bee = tint(bee, (170, 110, 230), 0.65)
    up(bee).save(out("characters", "ghost_wasp.png"))


# ---------------------------------------------------------------------------
# Tiles & decoration
# ---------------------------------------------------------------------------
def make_tiles():
    tiles = load(os.path.join(PACK, "Assets/Tiles.png"))
    up(tiles).save(out("tiles", "forest_tiles.png"))
    # Cursed (night) variant used for the later levels
    night = ImageEnhance.Brightness(tint(tiles, (110, 100, 150), 0.35)).enhance(0.85)
    up(night).save(out("tiles", "cursed_tiles.png"))


def crop_components(img, min_area=200):
    """Return bounding boxes of separated sprites (by alpha) in a sheet."""
    a = np.asarray(img)[..., 3] > 0
    h, w = a.shape
    seen = np.zeros_like(a)
    boxes = []
    for y in range(h):
        for x in range(w):
            if a[y, x] and not seen[y, x]:
                stack = [(y, x)]
                seen[y, x] = True
                x0 = x1 = x
                y0 = y1 = y
                n = 0
                while stack:
                    cy, cx = stack.pop()
                    n += 1
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            ny, nx = cy + dy, cx + dx
                            if 0 <= ny < h and 0 <= nx < w and a[ny, nx] and not seen[ny, nx]:
                                seen[ny, nx] = True
                                stack.append((ny, nx))
                if n >= min_area:
                    boxes.append((x0, y0, x1 + 1, y1 + 1))
    return boxes


def make_decor():
    d = out("decor", "x")[:-1]
    tree = load(os.path.join(PACK, "Trees/Green-Tree.png"))
    dark = load(os.path.join(PACK, "Trees/Dark-Tree.png"))
    # first row of the tree sheet: full tree, dead tree
    tree.crop(tree.crop((0, 0, 112, 370)).getbbox()).save(d + "tree_green.png")
    t = tree.crop((340, 0, 440, 370))
    t.crop(t.getbbox()).save(d + "tree_dead.png")
    t = dark.crop((0, 0, 112, 370))
    t.crop(t.getbbox()).save(d + "tree_dark.png")
    t = tree.crop((0, 940, 100, 1090))
    t.crop(t.getbbox()).save(d + "tree_small.png")

    rocks = load(os.path.join(PACK, "Assets/Props-Rocks.png"))
    for name, box in {"rock_big": (0, 0, 64, 80), "rock_moss": (0, 80, 64, 160),
                      "stone_pillar": (0, 160, 60, 256), "stone_tall": (60, 160, 110, 256),
                      "rock_flat": (150, 160, 220, 256), "rock_small": (124, 40, 152, 80)}.items():
        c = rocks.crop(box)
        up(c.crop(c.getbbox())).save(d + name + ".png")

    tiles = load(os.path.join(PACK, "Assets/Tiles.png"))
    # mushrooms & plants from the tiles sheet
    up(tiles.crop((256, 240, 288, 272))).save(d + "mushroom_big.png")
    up(tiles.crop((288, 240, 320, 272))).save(d + "mushroom_tall.png")
    up(tiles.crop((240, 240, 256, 272))).save(d + "mushroom_small.png")
    up(tiles.crop((0, 210, 64, 272))).save(d + "bush.png")

    trees_assets = load(os.path.join(PACK, "Assets/Tree-Assets.png"))
    leaves = trees_assets.crop((208, 0, 336, 96))
    up(leaves.crop(leaves.getbbox())).save(d + "bush_big.png")

    # Graveyard props drawn by hand -------------------------------------------------
    up(draw_tombstone(0)).save(d + "tomb_round.png")
    up(draw_tombstone(1)).save(d + "tomb_cross.png")
    up(draw_fence()).save(d + "fence.png")
    up(draw_torch_post()).save(d + "torch_post.png")


def draw_tombstone(kind):
    img = Image.new("RGBA", (20, 26))
    d = ImageDraw.Draw(img)
    stone, dark, light, moss = (122, 122, 132), (78, 78, 90), (160, 160, 170), (92, 128, 60)
    if kind == 0:
        d.rounded_rectangle((3, 2, 16, 25), radius=6, fill=stone, outline=dark)
        d.line((5, 5, 5, 22), fill=light)
        d.line((7, 9, 12, 9), fill=dark)
        d.line((9, 7, 9, 14), fill=dark)
        d.line((6, 18, 13, 18), fill=dark)
        d.point([(4, 24), (5, 23), (14, 24), (15, 23), (13, 24)], fill=moss)
    else:
        d.rectangle((8, 1, 11, 25), fill=stone, outline=dark)
        d.rectangle((3, 6, 16, 9), fill=stone, outline=dark)
        d.line((9, 2, 9, 24), fill=light)
        d.point([(8, 24), (11, 23), (10, 24)], fill=moss)
    return img


def draw_fence():
    img = Image.new("RGBA", (32, 20))
    d = ImageDraw.Draw(img)
    iron, hi = (40, 38, 48), (80, 78, 92)
    d.line((0, 6, 31, 6), fill=iron, width=1)
    d.line((0, 14, 31, 14), fill=iron, width=1)
    for x in range(2, 32, 6):
        d.line((x, 3, x, 19), fill=iron)
        d.polygon([(x - 1, 3), (x, 0), (x + 1, 3)], fill=hi)
    return img


def draw_torch_post():
    img = Image.new("RGBA", (10, 30))
    d = ImageDraw.Draw(img)
    d.rectangle((4, 8, 5, 29), fill=(90, 60, 40))
    d.rectangle((2, 6, 7, 8), fill=(60, 50, 50))
    return img


# ---------------------------------------------------------------------------
# Backgrounds (one set per level)
# ---------------------------------------------------------------------------
LEVEL_THEMES = {
    # top sky, bottom sky, cloud tint, far tint, near tint, celestial
    1: dict(top=(120, 200, 230), bot=(230, 240, 220), cloud=(255, 255, 255), far=(70, 120, 110),
            near=(40, 80, 70), sun=("sun", (255, 240, 180))),
    2: dict(top=(70, 60, 120), bot=(240, 140, 90), cloud=(255, 170, 140), far=(110, 70, 90),
            near=(60, 40, 60), sun=("sun", (255, 150, 90))),
    3: dict(top=(10, 20, 40), bot=(40, 80, 80), cloud=(90, 140, 120), far=(30, 60, 60),
            near=(16, 34, 36), sun=("moon", (220, 240, 210))),
    4: dict(top=(20, 5, 20), bot=(110, 20, 40), cloud=(150, 50, 70), far=(60, 15, 40),
            near=(25, 6, 20), sun=("moon", (255, 80, 80))),
}


def gradient(w, h, top, bot):
    t = np.linspace(0, 1, h)[:, None, None]
    arr = np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t
    arr = np.repeat(arr, w, axis=1)
    alpha = np.full((h, w, 1), 255)
    return Image.fromarray(np.concatenate([arr, alpha], -1).astype(np.uint8))


def silhouette(img, color, alpha_mul=1.0):
    arr = np.asarray(img).astype(np.float32)
    luma = (arr[..., :3] @ np.array([0.299, 0.587, 0.114]))[..., None] / 255.0
    rgb = np.array(color)[None, None, :] * (0.75 + luma * 0.6)
    a = arr[..., 3:] * alpha_mul
    return Image.fromarray(np.concatenate([np.clip(rgb, 0, 255), a], -1).astype(np.uint8))


def make_backgrounds():
    clouds = load(os.path.join(PACK, "Background/Background.png"))
    trees = load(os.path.join(PACK, "Trees/Background.png"))
    strips = [trees.crop(b) for b in [(0, 0, 96, 256), (112, 0, 208, 256), (224, 0, 351, 256),
                                      (352, 0, 448, 256), (464, 0, 560, 256), (576, 0, 703, 256),
                                      (704, 0, 800, 256), (800, 0, 896, 256)]]
    dark_strips, light_strips = strips[0:3], strips[3:6]
    mountains = [strips[6], strips[7]]

    def strip_layer(parts, width, order):
        layer = Image.new("RGBA", (width, 720))
        x, i = 0, 0
        while x < width:
            p = up(parts[order[i % len(order)]])
            layer.alpha_composite(p, (x, 0))
            # extend the bottom so the layer never shows a gap
            base = p.crop((0, p.height - 2, p.width, p.height)).resize((p.width, 720 - p.height))
            layer.alpha_composite(base, (x, p.height))
            x += p.width
            i += 1
        return layer.crop((0, 0, min(x, width), 720))

    W = 1200
    for lv, th in LEVEL_THEMES.items():
        sky = gradient(W, 648, th["top"], th["bot"])
        kind, col = th["sun"]
        d = ImageDraw.Draw(sky)
        cx, cy = (900, 140) if lv != 2 else (820, 430)
        r = 70 if kind == "moon" else 60
        glow = Image.new("RGBA", sky.size)
        gd = ImageDraw.Draw(glow)
        for i in range(10, 0, -1):
            gd.ellipse((cx - r - i * 12, cy - r - i * 12, cx + r + i * 12, cy + r + i * 12),
                       fill=col + (int(10 + (10 - i) * 4),))
        sky.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=col)
        if kind == "moon":
            shade = tuple(int(c * 0.85) for c in col)
            for (ox, oy, rr) in [(-20, -15, 14), (18, 10, 10), (-5, 28, 8), (25, -25, 6)]:
                d.ellipse((cx + ox - rr, cy + oy - rr, cx + ox + rr, cy + oy + rr), fill=shade)
        if lv >= 3:  # stars
            for _ in range(140):
                x, y = random.randrange(W), random.randrange(330)
                b = random.randint(120, 255)
                d.point((x, y), fill=(b, b, b))
        # keep only the bright cloud shapes (the base sky colour becomes transparent)
        carr = np.asarray(clouds).astype(np.float32)
        lum = carr[..., :3].mean(-1)
        alpha = np.clip((lum - lum[-1].mean()) / (255 - lum[-1].mean()), 0, 1) * 200
        cimg = np.zeros(carr.shape, np.float32)
        cimg[..., :3] = np.array(th["cloud"])
        cimg[..., 3] = alpha
        cl = Image.fromarray(cimg.astype(np.uint8)).crop((0, 0, 480, 140))
        sky.alpha_composite(cl.resize((W, 320), Image.NEAREST), (0, 0))
        sky.convert("RGB").save(out("bg", f"sky_{lv}.png"))

        # far: mountains, mid: light trees, near: dark trees
        silhouette(strip_layer(mountains, 1152, [0, 1, 1, 0, 1, 0]), th["far"]).save(out("bg", f"far_{lv}.png"))
        mid_col = tuple(int((a + b) / 2) for a, b in zip(th["far"], th["near"]))
        silhouette(strip_layer(light_strips, 1600, [0, 1, 2, 1, 0, 2, 1, 2]), mid_col).save(out("bg", f"mid_{lv}.png"))
        silhouette(strip_layer(dark_strips, 1600, [2, 0, 1, 2, 1, 0, 2, 1]), th["near"]).save(out("bg", f"near_{lv}.png"))


# ---------------------------------------------------------------------------
# Props: traps, platforms, items, effects (drawn pixel by pixel, then scaled)
# ---------------------------------------------------------------------------
STEEL, STEEL_D, STEEL_L = (150, 155, 170), (80, 84, 100), (220, 225, 235)


def draw_spikes():
    img = Image.new("RGBA", (16, 10))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 7, 15, 9), fill=(60, 58, 70))
    for x in (0, 4, 8, 12):
        d.polygon([(x, 7), (x + 2, 0), (x + 3, 7)], fill=STEEL)
        d.line((x + 2, 1, x + 2, 6), fill=STEEL_L)
        d.point((x + 3, 6), fill=STEEL_D)
    return img


def draw_saw(frames=4):
    size = 32
    sheet = Image.new("RGBA", (size * frames, size))
    for f in range(frames):
        img = Image.new("RGBA", (size, size))
        d = ImageDraw.Draw(img)
        c = size / 2
        pts = []
        teeth = 12
        for i in range(teeth * 2):
            ang = (i / (teeth * 2)) * math.tau + f * (math.tau / teeth / frames)
            r = 15.5 if i % 2 == 0 else 11.5
            pts.append((c + math.cos(ang) * r, c + math.sin(ang) * r))
        d.polygon(pts, fill=STEEL, outline=STEEL_D)
        d.ellipse((c - 9, c - 9, c + 9, c + 9), fill=(120, 124, 140))
        d.arc((c - 9, c - 9, c + 9, c + 9), 200 + f * 20, 300 + f * 20, fill=STEEL_L)
        d.ellipse((c - 3, c - 3, c + 3, c + 3), fill=(60, 30, 30))
        d.point((c - 1, c - 1), fill=(200, 60, 60))
        sheet.alpha_composite(img, (f * size, 0))
    return sheet


def draw_ball():
    img = Image.new("RGBA", (32, 32))
    d = ImageDraw.Draw(img)
    c = 15.5
    for ang in range(0, 360, 45):
        a0, a1 = math.radians(ang - 14), math.radians(ang + 14)
        d.polygon([(c + math.cos(a0) * 11, c + math.sin(a0) * 11),
                   (c + math.cos(math.radians(ang)) * 15.5, c + math.sin(math.radians(ang)) * 15.5),
                   (c + math.cos(a1) * 11, c + math.sin(a1) * 11)], fill=STEEL)
    d.ellipse((4, 4, 27, 27), fill=(70, 70, 82), outline=(30, 30, 40))
    d.ellipse((8, 7, 15, 13), fill=(120, 120, 135))
    d.point([(10, 9), (11, 9)], fill=(190, 190, 200))
    return img


def draw_chain():
    img = Image.new("RGBA", (6, 8))
    d = ImageDraw.Draw(img)
    d.ellipse((1, 0, 4, 5), outline=(110, 110, 120))
    d.line((3, 5, 3, 7), fill=(70, 70, 80))
    return img


def draw_anchor():
    img = Image.new("RGBA", (12, 8))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 11, 4), fill=(70, 60, 60), outline=(40, 30, 30))
    d.ellipse((4, 3, 7, 7), outline=(110, 110, 120))
    return img


def draw_spear():
    img = Image.new("RGBA", (8, 48))
    d = ImageDraw.Draw(img)
    d.rectangle((3, 10, 4, 47), fill=(110, 76, 44))
    d.line((3, 10, 3, 47), fill=(150, 110, 70))
    d.polygon([(1, 11), (3.5, 0), (6, 11)], fill=STEEL)
    d.line((3, 2, 3, 10), fill=STEEL_L)
    d.rectangle((2, 11, 5, 12), fill=(60, 60, 70))
    return img


def draw_spear_base():
    img = Image.new("RGBA", (16, 6))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 1, 15, 5), fill=(60, 58, 70), outline=(30, 30, 38))
    d.rectangle((6, 0, 9, 1), fill=(20, 20, 26))
    return img


def draw_brazier():
    img = Image.new("RGBA", (20, 12))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (19, 0), (15, 7), (4, 7)], fill=(70, 60, 64), outline=(30, 26, 30))
    d.line((2, 1, 17, 1), fill=(120, 100, 90))
    d.rectangle((8, 7, 11, 11), fill=(50, 44, 48))
    d.point([(5, 3), (9, 3), (13, 3)], fill=(255, 120, 40))
    return img


def draw_spring():
    sheet = Image.new("RGBA", (64, 16))
    for f, h in enumerate((10, 4, 13, 10)):
        img = Image.new("RGBA", (16, 16))
        d = ImageDraw.Draw(img)
        d.rectangle((1, 13, 14, 15), fill=(80, 60, 50), outline=(40, 30, 26))
        top = 13 - h
        for i, y in enumerate(range(top + 2, 13, 2)):
            d.line((4, y, 11, y), fill=(200, 200, 210) if i % 2 == 0 else (130, 130, 150))
        d.rectangle((2, top, 13, top + 2), fill=(200, 60, 50), outline=(110, 30, 30))
        d.line((3, top, 12, top), fill=(255, 140, 120))
        sheet.alpha_composite(img, (f * 16, 0))
    return sheet


def draw_portal(frames=6):
    size = 40
    sheet = Image.new("RGBA", (size * frames, size))
    for f in range(frames):
        img = Image.new("RGBA", (size, size))
        d = ImageDraw.Draw(img)
        d.ellipse((6, 2, 34, 38), fill=(40, 0, 70, 220))
        for i in range(6, 0, -1):
            col = (120 + i * 18, 40 + i * 10, 220, 60 + i * 30)
            r = 4 + i * 2.6
            d.ellipse((20 - r * 0.7, 20 - r, 20 + r * 0.7, 20 + r), outline=col, width=1)
        for k in range(8):
            ang = k / 8 * math.tau + f / frames * math.tau / 4
            x, y = 20 + math.cos(ang) * 11, 20 + math.sin(ang) * 16
            d.point((x, y), fill=(255, 220, 255, 255))
        sheet.alpha_composite(img, (f * size, 0))
    return sheet


def draw_flag():
    sheet = Image.new("RGBA", (48, 32))
    for f, col in enumerate([(110, 110, 120), (230, 190, 60), (255, 220, 90)]):
        img = Image.new("RGBA", (16, 32))
        d = ImageDraw.Draw(img)
        d.rectangle((3, 2, 4, 31), fill=(90, 70, 50))
        d.ellipse((2, 0, 5, 3), fill=(200, 170, 80))
        wave = 0 if f != 2 else 1
        d.polygon([(5, 3), (15, 5 + wave), (13, 9), (15, 13 - wave), (5, 12)], fill=col)
        if f > 0:  # cross emblem of the Order of Dawn
            d.line((9, 5, 9, 11), fill=(255, 255, 255))
            d.line((7, 7, 11, 7), fill=(255, 255, 255))
        d.rectangle((1, 29, 6, 31), fill=(70, 60, 60))
        sheet.alpha_composite(img, (f * 16, 0))
    return sheet


def draw_coin(frames=6):
    sheet = Image.new("RGBA", (12 * frames, 12))
    for f in range(frames):
        w = [5, 4, 2, 1, 2, 4][f]
        img = Image.new("RGBA", (12, 12))
        d = ImageDraw.Draw(img)
        d.ellipse((6 - w, 0, 5 + w, 11), fill=(240, 190, 50), outline=(150, 90, 20))
        if w > 2:
            d.line((6 - w + 2, 2, 6 - w + 2, 9), fill=(255, 240, 150))
            d.line((6, 3, 6, 8), fill=(170, 110, 20))
        sheet.alpha_composite(img, (f * 12, 0))
    return sheet


def draw_heart(color=(220, 40, 60), plus=False):
    img = Image.new("RGBA", (15, 14))
    d = ImageDraw.Draw(img)
    outline = tuple(int(c * 0.45) for c in color)
    d.ellipse((1, 1, 8, 8), fill=color)
    d.ellipse((6, 1, 13, 8), fill=color)
    d.polygon([(1, 5), (13, 5), (7, 12)], fill=color)
    d.point([(3, 3), (4, 3), (3, 4)], fill=(255, 230, 230))
    if plus:
        d.line((7, 3, 7, 8), fill=(255, 255, 255))
        d.line((5, 5, 9, 5), fill=(255, 255, 255))
    a = np.asarray(img)[..., 3] > 0
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if not a[y, x] and any(0 <= y + dy < img.height and 0 <= x + dx < img.width and a[y + dy, x + dx]
                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = outline + (255,)
    return img


def draw_potion(color):
    img = Image.new("RGBA", (12, 16))
    d = ImageDraw.Draw(img)
    glass = (200, 220, 230)
    d.rectangle((4, 0, 7, 2), fill=(140, 90, 50))
    d.rectangle((4, 3, 7, 5), fill=glass)
    d.ellipse((0, 4, 11, 15), fill=glass, outline=(90, 100, 120))
    d.ellipse((2, 7, 9, 14), fill=color)
    d.point([(3, 8), (3, 9)], fill=(255, 255, 255))
    return img


def draw_gem():
    img = Image.new("RGBA", (14, 12))
    d = ImageDraw.Draw(img)
    d.polygon([(3, 0), (10, 0), (13, 4), (7, 11), (0, 4)], fill=(80, 200, 255), outline=(20, 80, 160))
    d.line((1, 4, 12, 4), fill=(40, 140, 220))
    d.polygon([(4, 1), (6, 1), (5, 3)], fill=(230, 250, 255))
    return img


def draw_slash(frames=3):
    w, h = 32, 40
    sheet = Image.new("RGBA", (w * frames, h))
    for f in range(frames):
        img = Image.new("RGBA", (w * 4, h * 4))
        d = ImageDraw.Draw(img)
        alpha = [255, 220, 160][f]
        d.ellipse((-40, 8, 108, 152), fill=(170, 230, 255, alpha))
        d.ellipse((-70, 20, 86, 140), fill=(0, 0, 0, 0))
        d.arc((-40, 8, 108, 152), -70, 70, fill=(255, 255, 255, alpha), width=8)
        sheet.alpha_composite(img.resize((w, h), Image.LANCZOS), (f * w, 0))
    return sheet


def draw_sword_icon():
    img = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(img)
    d.line((4, 11, 14, 1), fill=(220, 225, 235), width=2)
    d.line((5, 11, 14, 2), fill=(150, 155, 170))
    d.line((2, 9, 6, 13), fill=(240, 190, 60), width=2)
    d.line((1, 14, 3, 12), fill=(120, 70, 40), width=2)
    return img


def make_props():
    p = lambda n: out("props", n)
    tiles = load(os.path.join(PACK, "Assets/Tiles.png"))
    up(draw_spikes()).save(p("spikes.png"))
    up(draw_saw()).save(p("saw.png"))
    up(draw_ball()).save(p("spike_ball.png"))
    up(draw_chain()).save(p("chain.png"))
    up(draw_anchor()).save(p("anchor.png"))
    up(draw_spear()).save(p("spear.png"))
    up(draw_spear_base()).save(p("spear_base.png"))
    up(draw_brazier()).save(p("brazier.png"))
    up(tiles.crop((80, 96, 128, 112))).save(p("plank.png"))         # wooden plank (cols 5..7, row 6)
    up(tiles.crop((176, 240, 224, 256))).save(p("stone_ledge.png"))  # mossy stone ledge
    up(draw_spring()).save(p("spring.png"))
    up(draw_portal()).save(p("portal.png"))
    up(draw_flag()).save(p("checkpoint.png"))
    up(draw_coin(), 3).save(p("coin.png"))
    up(draw_gem(), 3).save(p("gem.png"))
    up(draw_heart(), 3).save(p("heart.png"))
    up(draw_heart((255, 200, 40), True), 3).save(p("life.png"))
    up(draw_potion((60, 140, 255)), 3).save(p("potion_speed.png"))
    up(draw_potion((90, 220, 80)), 3).save(p("potion_jump.png"))
    up(draw_slash()).save(p("slash.png"))
    up(draw_sword_icon(), 3).save(p("sword_icon.png"))
    # level exit: the door top given by the user + a stretched middle part
    door = load(os.path.join(ROOT, "Assets/Tileset/door_open_top.png"))
    full = Image.new("RGBA", (64, 112))
    full.alpha_composite(door, (0, 0))
    full.alpha_composite(door.crop((0, 56, 64, 64)).resize((64, 48), Image.NEAREST), (0, 64))
    glow = Image.new("RGBA", full.size)
    ImageDraw.Draw(glow).rectangle((14, 22, 49, 111), fill=(255, 220, 120, 60))
    full.alpha_composite(glow)
    full.save(p("door.png"))


# ---------------------------------------------------------------------------
# UI backgrounds (menu / story / game over / win)
# ---------------------------------------------------------------------------
def scene_bg(level, extra_dark=0.0):
    sky = Image.open(out("bg", f"sky_{level}.png")).convert("RGBA")
    for n, y in [("far", 230), ("mid", 300), ("near", 380)]:
        l = Image.open(out("bg", f"{n}_{level}.png"))
        sky.alpha_composite(l.crop((0, 0, min(1200, l.width), 648 - y)), (0, y))
    if extra_dark:
        sky = ImageEnhance.Brightness(sky).enhance(1 - extra_dark)
    return sky


def place_char(bg, sheet_name, row, frame, x, y, scale=2, flip=False):
    sheet = Image.open(out("characters", sheet_name))
    cw, ch = CELL_W * SCALE, CELL_H * SCALE
    f = sheet.crop((frame * cw, row * ch, (frame + 1) * cw, (row + 1) * ch))
    if flip:
        f = f.transpose(Image.FLIP_LEFT_RIGHT)
    k = scale / SCALE
    f = f.resize((int(f.width * k), int(f.height * k)), Image.NEAREST)
    bg.alpha_composite(f, (int(x - ANCHOR[0] * scale), int(y - ANCHOR[1] * scale)))


def ground_strip(bg, y, tiles_name="forest_tiles.png"):
    tiles = Image.open(out("tiles", tiles_name))
    t = 32
    for x in range(0, bg.width, t):
        col = 1 + (x // t) % 3
        bg.alpha_composite(tiles.crop((col * t, 0, col * t + t, t)), (x, y - t))
        bg.alpha_composite(tiles.crop((col * t, t, col * t + t, 2 * t)), (x, y))
        for yy in range(y + t, bg.height, t):
            bg.alpha_composite(tiles.crop((2 * t, 2 * t, 3 * t, 3 * t)), (x, yy))


def make_ui():
    tomb = Image.open(out("decor", "tomb_cross.png"))
    tomb2 = Image.open(out("decor", "tomb_round.png"))
    # Menu: blood moon, the knight facing the undead horde
    bg = scene_bg(4)
    ground_strip(bg, 560, "cursed_tiles.png")
    for x, t in [(720, tomb), (830, tomb2), (1110, tomb), (60, tomb2)]:
        bg.alpha_composite(t, (x, 560 - t.height))
    place_char(bg, "knight.png", 0, 0, 260, 560, 4)
    for i, x in enumerate([880, 980, 1070, 1160]):
        place_char(bg, "zombie.png", 1, i * 2, x, 560, 3, flip=True)
    bg.convert("RGB").save(out("ui", "menu_bg.png"))

    over = scene_bg(4, 0.45)
    ground_strip(over, 540, "cursed_tiles.png")
    place_char(over, "knight.png", 4, 7, 600, 540, 4)
    over.convert("RGB").save(out("ui", "gameover_bg.png"))

    win = scene_bg(1)
    ground_strip(win, 540)
    place_char(win, "knight.png", 0, 0, 600, 540, 4)
    win.convert("RGB").save(out("ui", "win_bg.png"))

    scene_bg(3, 0.55).convert("RGB").save(out("ui", "story_bg.png"))


# ---------------------------------------------------------------------------
# Audio: chiptune music synthesised with numpy
# ---------------------------------------------------------------------------
SR = 22050


def note_freq(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def osc(kind, freq, dur, duty=0.5):
    t = np.arange(int(SR * dur)) / SR
    ph = (t * freq) % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw":
        return 2 * ph - 1
    return np.sin(2 * np.pi * ph)


def env(n, attack=0.005, release=0.08):
    e = np.ones(n)
    a, r = int(SR * attack), int(SR * release)
    e[:a] = np.linspace(0, 1, a) if a else 1
    if r and r < n:
        e[-r:] = np.linspace(1, 0, r)
    return e


def drum(kind):
    if kind == "k":
        n = int(SR * 0.18)
        t = np.arange(n) / SR
        f = 120 * np.exp(-t * 18) + 40
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)
    if kind == "s":
        n = int(SR * 0.15)
        t = np.arange(n) / SR
        return np.random.uniform(-1, 1, n) * np.exp(-t * 22) * 0.7
    n = int(SR * 0.04)
    return np.random.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * 80) * 0.3


def render_song(bpm, chords, scale, steps_per_chord=8, lead="square", seed=1, drums="k.h.s.h.", bars_lead=True,
                lead_oct=0, gain=0.35):
    rnd = random.Random(seed)
    step = 60 / bpm / 2  # 8th notes
    total = len(chords) * steps_per_chord
    out_buf = np.zeros(int(SR * step * total) + SR)
    prev = scale[0]
    for ci, chord in enumerate(chords):
        root = chord[0]
        for s in range(steps_per_chord):
            i = ci * steps_per_chord + s
            pos = int(i * step * SR)
            # bass: root on beats, fifth on offbeats
            bn = root - 24 if s % 2 == 0 else root - 24 + 7
            b = osc("tri", note_freq(bn), step * 0.95)
            out_buf[pos:pos + len(b)] += b * env(len(b)) * 0.45
            # arpeggio (soft)
            an = chord[s % len(chord)] + 12
            a = osc("square", note_freq(an), step * 0.5, 0.125)
            out_buf[pos:pos + len(a)] += a * env(len(a), release=0.05) * 0.06
            # lead melody: walk on scale, prefer chord tones on strong beats
            if bars_lead and (s % 2 == 0 or rnd.random() < 0.35):
                if s % 4 == 0:
                    cand = [n + 12 for n in chord]
                else:
                    cand = [n for n in scale if abs(n - prev) <= 4]
                n = min(cand, key=lambda c: abs(c - prev) + rnd.random() * 5)
                prev = n
                length = step * (2 if s % 4 == 0 and rnd.random() < 0.5 else 1)
                l = osc(lead, note_freq(n + lead_oct), length * 0.9, 0.25)
                vib = 1 + 0.003 * np.sin(np.arange(len(l)) / SR * 2 * np.pi * 5)
                out_buf[pos:pos + len(l)] += l * vib * env(len(l), 0.01, 0.06) * 0.16
            # drums
            dch = drums[s % len(drums)]
            if dch != ".":
                d = drum(dch)
                out_buf[pos:pos + len(d)] += d * 0.5
    out_buf = out_buf[: int(SR * step * total)]
    out_buf = np.tanh(out_buf * 1.2) * gain / 0.35 * 0.8
    return out_buf


def render_jingle(notes, bpm, wave_kind="square"):
    step = 60 / bpm / 2
    buf = np.zeros(int(SR * step * sum(n[1] for n in notes)) + SR)
    pos = 0
    for n, l in notes:
        if n:
            w = osc(wave_kind, note_freq(n), step * l * 0.95, 0.25) * 0.3
            w += osc("tri", note_freq(n - 12), step * l * 0.95) * 0.3
            buf[pos:pos + len(w)] += w * env(len(w), 0.01, 0.15)
        pos += int(step * l * SR)
    return np.tanh(buf)


def save_wav(path, buf):
    data = (np.clip(buf, -1, 1) * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def make_audio():
    np.random.seed(3)
    A_MIN = [57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]
    D_MIN = [62, 64, 65, 67, 69, 70, 72, 74, 76, 77, 79]
    E_MIN = [64, 66, 67, 69, 71, 72, 74, 76, 78, 79, 81, 83]
    Am, F, C, G, Dm, E = [57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62], [50, 53, 57], [52, 56, 59]
    Em, Bm, Cmaj, D = [52, 55, 59], [47, 50, 54], [48, 52, 55], [50, 54, 57]
    Bb, Gm, A = [46, 50, 53], [43, 46, 50], [45, 49, 52]
    forest = [Am, F, C, G, Am, F, E, E, Am, Dm, G, C, F, Dm, E, Am]
    save_wav(out("audio", "music_forest.wav"), render_song(118, forest, A_MIN, seed=4))
    cursed = [Dm, Bb, Gm, A, Dm, Bb, Gm, A, Gm, Dm, Bb, A]
    save_wav(out("audio", "music_cursed.wav"), render_song(96, cursed, D_MIN, seed=9, lead="saw", drums="k...s...", lead_oct=-12))
    boss = [Em, Cmaj, D, Bm, Em, Cmaj, D, [52, 56, 59], Em, Cmaj, Bm, Em]
    save_wav(out("audio", "music_boss.wav"), render_song(150, boss, E_MIN, seed=13, drums="khskkhsh"))
    menu = [Am, F, C, E, Am, F, Dm, E]
    save_wav(out("audio", "music_menu.wav"), render_song(84, menu, A_MIN, seed=21, drums="k.......", lead="tri"))
    save_wav(out("audio", "jingle_win.wav"), render_jingle([(72, 1), (76, 1), (79, 1), (84, 3), (79, 1), (84, 6)], 140))
    save_wav(out("audio", "jingle_over.wav"), render_jingle([(69, 2), (68, 2), (67, 2), (66, 2), (57, 8)], 110, "saw"))

if __name__ == "__main__":
    import sys
    steps = sys.argv[1:] or ["characters", "tiles", "decor", "backgrounds", "props", "ui", "audio"]
    for s in steps:
        print("==>", s)
        globals()["make_" + s]()
