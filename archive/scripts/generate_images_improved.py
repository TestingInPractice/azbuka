#!/usr/bin/env python3
"""Generate improved 512x512 PNG illustrations for all 33 Russian alphabet letters."""

import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets", "images")
os.makedirs(OUT_DIR, exist_ok=True)

SCALE = 3
BIG = 512 * SCALE  # 1536
FINAL = 512

def _bg(size):
    """Create transparent RGBA image."""
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))

def _circle_gradient(size, r, g, b, center_r=1.0):
    """Radial gradient canvas."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        for x in range(size):
            dx = x - size // 2
            dy = y - size // 2
            dist = math.sqrt(dx * dx + dy * dy) / (size // 2)
            if dist > 1.0:
                dist = 1.0
            factor = 1.0 - dist * 0.5
            rr = int(r * factor)
            gg = int(g * factor)
            bb = int(b * factor)
            img.putpixel((x, y), (min(rr, 255), min(gg, 255), min(bb, 255), 255))
    return img

def _linear_gradient(size, colors):
    """Vertical linear gradient. colors = [(r,g,b), (r,g,b), ...]"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    n = len(colors) - 1
    for y in range(size):
        t = y / size * n
        idx = int(t)
        frac = t - idx
        if idx >= n:
            idx = n - 1
            frac = 1.0
        c1 = colors[idx]
        c2 = colors[min(idx + 1, n)]
        rr = int(c1[0] + (c2[0] - c1[0]) * frac)
        gg = int(c1[1] + (c2[1] - c1[1]) * frac)
        bb = int(c1[2] + (c2[2] - c1[2]) * frac)
        for x in range(size):
            img.putpixel((x, y), (min(rr, 255), min(gg, 255), min(bb, 255), 255))
    return img

def _shadow(mask, radius=None):
    """Create drop shadow from a mask."""
    if radius is None:
        radius = int(BIG * 0.04)
    shadow = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    if hasattr(mask, 'mode') and mask.mode == 'RGBA':
        # extract alpha as mask
        alpha = mask.split()[3]
        shadow = Image.new("RGBA", mask.size, (0, 0, 0, 0))
        shadow.putalpha(alpha)
    else:
        draw.bitmap((0, 0), mask, fill=(0, 0, 0, 180))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=radius))
    return shadow

def _paste_shadow(base, subject, offset=(0, 0), radius=None):
    """Paste drop shadow of subject onto base, then paste subject."""
    sh = _shadow(subject, radius)
    bx, by = offset
    base.paste(sh, (bx + int(BIG*0.015), by + int(BIG*0.03)), sh)
    base.paste(subject, (bx, by), subject)

def _rounded_rect(draw, xy, r, fill=None, outline=None, width=1):
    """Draw rounded rectangle."""
    x1, y1, x2, y2 = xy
    draw.rectangle((x1 + r, y1, x2 - r, y2), fill=fill)
    draw.rectangle((x1, y1 + r, x2, y2 - r), fill=fill)
    draw.pieslice((x1, y1, x1 + r * 2, y1 + r * 2), 180, 270, fill=fill)
    draw.pieslice((x2 - r * 2, y1, x2, y1 + r * 2), 270, 360, fill=fill)
    draw.pieslice((x1, y2 - r * 2, x1 + r * 2, y2), 90, 180, fill=fill)
    draw.pieslice((x2 - r * 2, y2 - r * 2, x2, y2), 0, 90, fill=fill)

def _ellipse(draw, xy, fill=None, outline=None, width=1):
    """Draw anti-aliased ellipse using oversampled approach on the big canvas."""
    draw.ellipse(xy, fill=fill, outline=outline, width=width)

def _downscale(img):
    """Downscale from BIG to FINAL."""
    return img.resize((FINAL, FINAL), Image.LANCZOS)

def _circle(size, cx, cy, r, color):
    """Create circular mask."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    return img

def _save(img, name):
    path = os.path.join(OUT_DIR, name)
    final = _downscale(img)
    final.save(path, "PNG")
    print(f"  Saved {name}")

# ─── Image generation functions ──────────────────────────────────────────────

def draw_arbuz():
    """А → Арбуз (watermelon)"""
    img = _linear_gradient(BIG, [(30, 50, 10), (20, 80, 20), (30, 120, 30)])
    # Full watermelon - large oval
    wm = _bg(BIG)
    d = ImageDraw.Draw(wm)
    cx, cy = BIG // 2, BIG // 2 + 20
    rx, ry = BIG * 0.38, BIG * 0.30
    # Outer green shell
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(50, 130, 50))
    # Darker stripes
    for i in range(-3, 4):
        sx = cx + i * rx * 0.22
        sw = 12
        d.ellipse([sx - sw, cy - ry, sx + sw, cy + ry], fill=(30, 90, 30))
    # Inner red flesh (cut slice showing)
    d.ellipse([cx - rx * 0.75, cy - ry * 0.75, cx + rx * 0.75, cy + ry * 0.75], fill=(220, 40, 40))
    # Inner lighter red
    d.ellipse([cx - rx * 0.6, cy - ry * 0.6, cx + rx * 0.6, cy + ry * 0.6], fill=(240, 60, 60))
    # Seeds
    seed_positions = [
        (-0.45, -0.35), (0.15, -0.4), (0.5, -0.2),
        (-0.3, 0.0), (0.0, 0.0), (0.35, 0.05),
        (-0.5, 0.25), (-0.1, 0.3), (0.4, 0.25),
    ]
    for sx, sy in seed_positions:
        sx_p = int(cx + sx * rx * 0.7)
        sy_p = int(cy + sy * ry * 0.7)
        d.ellipse([sx_p - 6, sy_p - 9, sx_p + 6, sy_p + 9], fill=(20, 20, 20))
    # Highlight on rind
    d.ellipse([cx - rx * 0.85, cy - ry * 0.9, cx - rx * 0.4, cy - ry * 0.3], fill=(100, 200, 100, 60))
    _paste_shadow(img, wm, (0, 20))
    return img

def draw_banan():
    """Б → Банан (banana)"""
    img = _linear_gradient(BIG, [(60, 50, 20), (100, 90, 40), (60, 50, 20)])
    b = _bg(BIG)
    d = ImageDraw.Draw(b)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Banana body - curved arc shape using multiple ellipses overlaid
    # Main curve
    bw = int(BIG * 0.32)
    bh = int(BIG * 0.18)
    d.ellipse([cx - bw, cy - bh - 40, cx + bw, cy + bh - 40], fill=(240, 210, 50))
    d.ellipse([cx - bw - 20, cy - bh, cx + bw - 20, cy + bh], fill=(230, 200, 40))
    d.ellipse([cx - bw - 10, cy - bh + 30, cx + bw - 10, cy + bh + 30], fill=(210, 180, 30))
    # Fill to make continuous curve
    d.ellipse([cx - bw + 20, cy - bh - 10, cx + bw - 30, cy + bh - 10], fill=(230, 205, 45))
    # Stem
    d.rectangle([cx + bw - 15, cy - bh - 80, cx + bw + 5, cy - bh - 40], fill=(100, 80, 20))
    d.ellipse([cx + bw - 25, cy - bh - 95, cx + bw + 15, cy - bh - 55], fill=(90, 70, 15))
    # Tip (bottom)
    d.ellipse([cx - bw - 30, cy + bh - 15, cx - bw, cy + bh + 15], fill=(100, 80, 20))
    # Highlight
    d.ellipse([cx - bw * 0.3, cy - bh - 30, cx + bw * 0.0, cy + bh + 10], fill=(255, 255, 200, 80))
    _paste_shadow(img, b, (0, 25))
    return img

def draw_volk():
    """В → Волк (wolf)"""
    img = _linear_gradient(BIG, [(30, 40, 60), (50, 60, 80), (30, 40, 50)])
    w = _bg(BIG)
    d = ImageDraw.Draw(w)
    cx, cy = BIG // 2, BIG // 2 + 40
    # Body (oval, sitting)
    d.ellipse([cx - 180, cy - 100, cx + 140, cy + 180], fill=(130, 130, 145))
    # Head
    d.ellipse([cx - 130, cy - 230, cx + 90, cy - 60], fill=(140, 140, 155))
    # Ears (two triangles)
    d.polygon([(cx - 120, cy - 200), (cx - 90, cy - 290), (cx - 70, cy - 210)], fill=(130, 130, 145))
    d.polygon([(cx - 50, cy - 200), (cx - 20, cy - 290), (cx, cy - 210)], fill=(130, 130, 145))
    # Inner ears
    d.polygon([(cx - 110, cy - 210), (cx - 90, cy - 270), (cx - 75, cy - 215)], fill=(200, 180, 160))
    d.polygon([(cx - 50, cy - 210), (cx - 25, cy - 270), (cx - 10, cy - 215)], fill=(200, 180, 160))
    # Snout
    d.ellipse([cx - 60, cy - 140, cx + 40, cy - 70], fill=(160, 160, 170))
    # Nose
    d.ellipse([cx - 10, cy - 105, cx + 25, cy - 80], fill=(30, 30, 30))
    # Eyes
    d.ellipse([cx - 100, cy - 170, cx - 60, cy - 140], fill=(50, 50, 50))
    d.ellipse([cx - 40, cy - 170, cx, cy - 140], fill=(50, 50, 50))
    d.ellipse([cx - 90, cy - 165, cx - 70, cy - 145], fill=(255, 200, 50))
    d.ellipse([cx - 30, cy - 165, cx - 10, cy - 145], fill=(255, 200, 50))
    # Mouth
    d.arc([cx - 50, cy - 110, cx + 10, cy - 60], 0, 180, fill=(80, 80, 90), width=4)
    # Tail
    d.ellipse([cx + 120, cy + 30, cx + 200, cy + 130], fill=(130, 130, 145))
    # Paws
    d.ellipse([cx - 130, cy + 150, cx - 70, cy + 200], fill=(120, 120, 135))
    d.ellipse([cx - 20, cy + 150, cx + 40, cy + 200], fill=(120, 120, 135))
    # Chest fur (lighter)
    d.ellipse([cx - 90, cy - 80, cx + 40, cy + 30], fill=(180, 180, 190, 120))
    _paste_shadow(img, w, (0, 20))
    return img

def draw_grib():
    """Г → Гриб (mushroom)"""
    img = _linear_gradient(BIG, [(20, 80, 30), (40, 120, 50), (20, 60, 20)])
    gr = _bg(BIG)
    d = ImageDraw.Draw(gr)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Stem
    d.ellipse([cx - 80, cy - 30, cx + 80, cy + 170], fill=(230, 210, 180))
    d.ellipse([cx - 70, cy - 20, cx + 70, cy + 160], fill=(245, 230, 200))
    # Cap (large red dome)
    d.ellipse([cx - 220, cy - 180, cx + 220, cy + 60], fill=(210, 30, 30))
    d.ellipse([cx - 200, cy - 170, cx + 200, cy + 50], fill=(230, 40, 40))
    # Bottom of cap (gills visible)
    d.ellipse([cx - 210, cy - 20, cx + 210, cy + 40], fill=(180, 160, 140))
    d.ellipse([cx - 195, cy - 10, cx + 195, cy + 30], fill=(200, 180, 160))
    # White spots
    spot_positions = [
        (-130, -120, 35), (-30, -150, 30), (100, -100, 38),
        (-80, -60, 25), (50, -140, 28), (140, -60, 22),
        (-170, -80, 22), (10, -90, 20),
    ]
    for sx, sy, sr in spot_positions:
        d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(250, 250, 240))
    # Highlight on cap
    d.ellipse([cx - 150, cy - 160, cx - 30, cy - 60], fill=(255, 100, 100, 80))
    _paste_shadow(img, gr, (0, 25))
    return img

def draw_dom():
    """Д → Дом (house)"""
    img = _linear_gradient(BIG, [(60, 80, 100), (80, 110, 140), (50, 70, 90)])
    house = _bg(BIG)
    d = ImageDraw.Draw(house)
    cx, cy = BIG // 2, BIG // 2 + 40
    # House body
    bw, bh = 300, 250
    x1, y1 = cx - bw // 2, cy - bh // 2
    x2, y2 = cx + bw // 2, cy + bh // 2
    d.rectangle([x1, y1, x2, y2], fill=(180, 150, 100))
    # Log lines
    for row in range(5):
        ry = y1 + 10 + row * 50
        d.line([x1 + 5, ry, x2 - 5, ry], fill=(160, 130, 80), width=3)
    # Roof (triangle)
    roof_w = 360
    d.polygon([
        (cx - roof_w // 2, y1),
        (cx, y1 - 160),
        (cx + roof_w // 2, y1),
    ], fill=(160, 40, 40))
    d.polygon([
        (cx - roof_w // 2 + 10, y1),
        (cx, y1 - 145),
        (cx + roof_w // 2 - 10, y1),
    ], fill=(190, 50, 50))
    # Window
    wx1, wy1 = cx - 70, cy - 30
    wx2, wy2 = cx + 70, cy + 70
    d.rectangle([wx1, wy1, wx2, wy2], fill=(200, 220, 240))
    d.rectangle([wx1, wy1, wx2, wy2], outline=(100, 80, 50), width=6)
    d.line([cx, wy1, cx, wy2], fill=(100, 80, 50), width=4)
    d.line([wx1, cy + 20, wx2, cy + 20], fill=(100, 80, 50), width=4)
    # Window glow
    d.rectangle([wx1 + 8, wy1 + 8, wx2 - 8, wy2 - 8], fill=(255, 255, 200, 50))
    # Door
    dx1, dy1 = cx - 40, y2 - 120
    dx2, dy2 = cx + 40, y2
    d.rectangle([dx1, dy1, dx2, dy2], fill=(120, 80, 40))
    d.ellipse([dx2 - 15, dy1 + 55, dx2 - 5, dy1 + 65], fill=(220, 180, 50))
    # Chimney
    d.rectangle([cx + 60, y1 - 130, cx + 100, y1 - 30], fill=(140, 100, 60))
    d.rectangle([cx + 55, y1 - 140, cx + 105, y1 - 120], fill=(100, 80, 50))
    # Smoke puffs
    for i, (sx, sy, sr) in enumerate([(50, -180, 25), (70, -220, 30), (40, -260, 20)]):
        d.ellipse([cx + sx - sr, cy + sy - sr, cx + sx + sr, cy + sy + sr], fill=(200, 200, 210, 120 - i * 20))
    _paste_shadow(img, house, (0, 25))
    return img

def draw_enot():
    """Е → Енот (raccoon)"""
    img = _linear_gradient(BIG, [(40, 60, 50), (60, 90, 70), (30, 50, 40)])
    en = _bg(BIG)
    d = ImageDraw.Draw(en)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 160, cy - 50, cx + 130, cy + 200], fill=(140, 140, 150))
    # Tail (striped)
    d.ellipse([cx + 110, cy + 10, cx + 260, cy + 120], fill=(140, 140, 150))
    # Tail stripes
    d.ellipse([cx + 140, cy + 20, cx + 170, cy + 100], fill=(60, 60, 60))
    d.ellipse([cx + 180, cy + 15, cx + 220, cy + 100], fill=(60, 60, 60))
    d.ellipse([cx + 230, cy + 25, cx + 255, cy + 90], fill=(60, 60, 60))
    # Head
    d.ellipse([cx - 140, cy - 200, cx + 80, cy - 30], fill=(150, 150, 160))
    # Ears
    d.ellipse([cx - 125, cy - 240, cx - 80, cy - 180], fill=(140, 140, 150))
    d.ellipse([cx - 35, cy - 245, cx + 10, cy - 185], fill=(140, 140, 150))
    d.ellipse([cx - 118, cy - 230, cx - 87, cy - 190], fill=(200, 180, 170))
    d.ellipse([cx - 28, cy - 235, cx + 3, cy - 195], fill=(200, 180, 170))
    # Mask (dark patches around eyes)
    d.ellipse([cx - 120, cy - 150, cx - 40, cy - 90], fill=(50, 50, 55))
    d.ellipse([cx - 40, cy - 150, cx + 40, cy - 90], fill=(50, 50, 55))
    # Eyes
    d.ellipse([cx - 100, cy - 145, cx - 60, cy - 110], fill=(255, 255, 255))
    d.ellipse([cx - 20, cy - 145, cx + 20, cy - 110], fill=(255, 255, 255))
    d.ellipse([cx - 85, cy - 135, cx - 75, cy - 120], fill=(30, 30, 30))
    d.ellipse([cx - 5, cy - 135, cx + 5, cy - 120], fill=(30, 30, 30))
    d.ellipse([cx - 82, cy - 132, cx - 78, cy - 125], fill=(255, 255, 255, 150))
    d.ellipse([cx - 2, cy - 132, cx + 2, cy - 125], fill=(255, 255, 255, 150))
    # Snout
    d.ellipse([cx - 70, cy - 100, cx + 20, cy - 50], fill=(180, 180, 185))
    d.ellipse([cx - 20, cy - 75, cx + 5, cy - 55], fill=(30, 30, 30))
    # Stripes on face
    d.line([cx - 60, cy - 160, cx - 50, cy - 120], fill=(80, 80, 90), width=4)
    d.line([cx - 30, cy - 160, cx - 20, cy - 120], fill=(80, 80, 90), width=4)
    _paste_shadow(img, en, (0, 20))
    return img

def draw_yozh():
    """Ё → Ёж (hedgehog)"""
    img = _linear_gradient(BIG, [(50, 70, 30), (70, 100, 40), (50, 60, 30)])
    y = _bg(BIG)
    d = ImageDraw.Draw(y)
    cx, cy = BIG // 2, BIG // 2 + 40
    # Body (oval)
    d.ellipse([cx - 190, cy - 100, cx + 150, cy + 150], fill=(140, 100, 60))
    # Spikes (multiple triangles radiating from back)
    spike_color = (100, 70, 40)
    spike_positions = [
        (-200, -120, 30, 50), (-180, -160, 30, 50), (-150, -190, 30, 50),
        (-110, -210, 30, 50), (-70, -220, 30, 50), (-30, -220, 30, 50),
        (10, -215, 30, 50), (50, -200, 30, 50), (90, -180, 30, 50),
        (120, -155, 30, 50), (140, -125, 30, 50),
        (-210, -100, 30, 45), (145, -90, 30, 45),
    ]
    for sx, sy, bw, bh in spike_positions:
        d.polygon([
            (cx + sx - bw // 2, cy + sy),
            (cx + sx, cy + sy - bh),
            (cx + sx + bw // 2, cy + sy),
        ], fill=spike_color)
    # Lighter face/belly
    d.ellipse([cx - 140, cy - 80, cx + 100, cy + 120], fill=(180, 150, 110))
    d.ellipse([cx - 120, cy - 60, cx + 80, cy + 100], fill=(200, 170, 130))
    # Eyes
    d.ellipse([cx - 80, cy - 50, cx - 40, cy - 15], fill=(30, 30, 30))
    d.ellipse([cx - 30, cy - 50, cx + 10, cy - 15], fill=(30, 30, 30))
    d.ellipse([cx - 70, cy - 42, cx - 50, cy - 25], fill=(255, 255, 255))
    d.ellipse([cx - 20, cy - 42, cx, cy - 25], fill=(255, 255, 255))
    # Nose
    d.ellipse([cx - 15, cy - 30, cx + 5, cy - 10], fill=(40, 30, 30))
    # Smile
    d.arc([cx - 50, cy - 20, cx, cy + 15], 0, 180, fill=(80, 60, 40), width=3)
    # Small feet
    d.ellipse([cx - 130, cy + 120, cx - 80, cy + 160], fill=(140, 100, 60))
    d.ellipse([cx - 40, cy + 120, cx + 10, cy + 160], fill=(140, 100, 60))
    _paste_shadow(img, y, (0, 25))
    return img

def draw_zhuk():
    """Ж → Жук (beetle)"""
    img = _linear_gradient(BIG, [(50, 70, 40), (70, 100, 50), (40, 60, 30)])
    zh = _bg(BIG)
    d = ImageDraw.Draw(zh)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Body shell (oval)
    d.ellipse([cx - 170, cy - 130, cx + 170, cy + 130], fill=(30, 60, 80))
    d.ellipse([cx - 160, cy - 120, cx + 160, cy + 120], fill=(40, 80, 100))
    # Wing line
    d.line([cx, cy - 120, cx, cy + 110], fill=(20, 40, 60), width=4)
    # Shell shine
    d.ellipse([cx - 100, cy - 90, cx - 20, cy - 30], fill=(80, 160, 180, 80))
    d.ellipse([cx + 20, cy - 90, cx + 100, cy - 30], fill=(80, 160, 180, 80))
    # Head
    d.ellipse([cx - 80, cy - 200, cx + 80, cy - 110], fill=(25, 50, 70))
    d.ellipse([cx - 70, cy - 190, cx + 70, cy - 120], fill=(35, 65, 85))
    # Eyes
    d.ellipse([cx - 45, cy - 180, cx - 15, cy - 150], fill=(200, 50, 50))
    d.ellipse([cx + 15, cy - 180, cx + 45, cy - 150], fill=(200, 50, 50))
    d.ellipse([cx - 38, cy - 173, cx - 22, cy - 157], fill=(255, 100, 100))
    d.ellipse([cx + 22, cy - 173, cx + 38, cy - 157], fill=(255, 100, 100))
    # Antennae
    d.arc([cx - 80, cy - 270, cx - 20, cy - 180], 220, 320, fill=(30, 50, 70), width=5)
    d.arc([cx + 20, cy - 270, cx + 80, cy - 180], 220, 320, fill=(30, 50, 70), width=5)
    # Legs (6 legs)
    leg_color = (30, 50, 70)
    for side in [-1, 1]:
        d.polygon([(cx + side * 130, cy - 40), (cx + side * 230, cy - 80), (cx + side * 250, cy - 50)], fill=leg_color, outline=leg_color)
        d.polygon([(cx + side * 150, cy + 10), (cx + side * 240, cy + 10), (cx + side * 260, cy + 30)], fill=leg_color, outline=leg_color)
        d.polygon([(cx + side * 130, cy + 60), (cx + side * 220, cy + 80), (cx + side * 240, cy + 110)], fill=leg_color, outline=leg_color)
    _paste_shadow(img, zh, (0, 20))
    return img

def draw_zebra():
    """З → Зебра (zebra)"""
    img = _linear_gradient(BIG, [(50, 70, 30), (70, 100, 50), (40, 60, 30)])
    z = _bg(BIG)
    d = ImageDraw.Draw(z)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 190, cy - 70, cx + 150, cy + 180], fill=(230, 230, 230))
    # Neck
    d.ellipse([cx - 90, cy - 200, cx + 50, cy - 30], fill=(230, 230, 230))
    # Head
    d.ellipse([cx - 100, cy - 280, cx + 60, cy - 170], fill=(230, 230, 230))
    # Ears
    d.ellipse([cx - 70, cy - 320, cx - 40, cy - 260], fill=(230, 230, 230))
    d.ellipse([cx - 30, cy - 320, cx, cy - 260], fill=(230, 230, 230))
    d.ellipse([cx - 65, cy - 310, cx - 45, cy - 270], fill=(200, 100, 140))
    d.ellipse([cx - 25, cy - 310, cx - 5, cy - 270], fill=(200, 100, 140))
    # Stripes (black)
    stripe_color = (20, 20, 20)
    # Body stripes
    for i in range(8):
        sx = cx - 150 + i * 40
        d.ellipse([sx, cy - 50, sx + 18, cy + 150], fill=stripe_color)
    # Neck stripes
    for i in range(4):
        sx = cx - 70 + i * 30
        d.ellipse([sx, cy - 180, sx + 14, cy - 50], fill=stripe_color)
    # Face stripes
    for i in range(3):
        sx = cx - 80 + i * 35
        d.ellipse([sx, cy - 270, sx + 12, cy - 190], fill=stripe_color)
    # Muzzle (white)
    d.ellipse([cx - 50, cy - 240, cx + 30, cy - 185], fill=(250, 250, 250))
    # Nose
    d.ellipse([cx - 10, cy - 210, cx + 20, cy - 190], fill=(60, 60, 60))
    # Eye
    d.ellipse([cx - 60, cy - 250, cx - 35, cy - 225], fill=(30, 30, 30))
    d.ellipse([cx - 55, cy - 246, cx - 40, cy - 232], fill=(255, 255, 255))
    # Mane (short, upright)
    for i in range(10):
        mx = cx - 100 + i * 25
        my = cy - 200 + i * 12
        d.ellipse([mx, my - 35, mx + 12, my], fill=stripe_color)
    # Legs
    for ox in [-140, -60, 20, 100]:
        d.ellipse([cx + ox, cy + 150, cx + ox + 35, cy + 220], fill=(200, 200, 200))
    # Tail
    d.ellipse([cx + 135, cy - 20, cx + 190, cy + 50], fill=(230, 230, 230))
    d.ellipse([cx + 175, cy + 30, cx + 195, cy + 80], fill=(30, 30, 30))
    _paste_shadow(img, z, (0, 25))
    return img

def draw_iriska():
    """И → Ириска (candy/wrapper)"""
    img = _circle_gradient(BIG, 255, 200, 220)
    i = _bg(BIG)
    d = ImageDraw.Draw(i)
    cx, cy = BIG // 2, BIG // 2
    # Wrapper (twisted ends, candy in middle)
    # Left wrapper
    d.polygon([
        (cx - 200, cy - 40),
        (cx - 80, cy - 60),
        (cx - 80, cy + 60),
        (cx - 200, cy + 40),
    ], fill=(200, 50, 80))
    # Right wrapper
    d.polygon([
        (cx + 80, cy - 60),
        (cx + 200, cy - 40),
        (cx + 200, cy + 40),
        (cx + 80, cy + 60),
    ], fill=(200, 50, 80))
    # Candy body (oval)
    d.ellipse([cx - 100, cy - 80, cx + 100, cy + 80], fill=(255, 220, 150))
    d.ellipse([cx - 90, cy - 70, cx + 90, cy + 70], fill=(255, 230, 170))
    # Swirl on candy
    d.arc([cx - 70, cy - 50, cx + 40, cy + 50], 0, 360, fill=(200, 150, 80), width=8)
    d.arc([cx - 30, cy - 60, cx + 70, cy + 40], 0, 360, fill=(180, 120, 60), width=6)
    # Stripe on candy
    d.ellipse([cx - 60, cy - 15, cx + 60, cy + 15], fill=(180, 80, 100, 100))
    # Wrapper highlights
    d.ellipse([cx - 170, cy - 15, cx - 100, cy + 15], fill=(255, 100, 130, 80))
    d.ellipse([cx + 100, cy - 15, cx + 170, cy + 15], fill=(255, 100, 130, 80))
    # Candy highlight
    d.ellipse([cx - 50, cy - 55, cx - 10, cy - 15], fill=(255, 255, 255, 80))
    _paste_shadow(img, i, (0, 10))
    return img

def draw_yogurt():
    """Й → Йогурт (yogurt)"""
    img = _linear_gradient(BIG, [(80, 60, 100), (110, 90, 130), (70, 50, 90)])
    y = _bg(BIG)
    d = ImageDraw.Draw(y)
    cx, cy = BIG // 2, BIG // 2 + 10
    # Cup body (trapezoid-ish)
    cup_w_top = 280
    cup_w_bot = 200
    cup_h = 260
    d.polygon([
        (cx - cup_w_top // 2, cy - cup_h // 2),
        (cx + cup_w_top // 2, cy - cup_h // 2),
        (cx + cup_w_bot // 2, cy + cup_h // 2),
        (cx - cup_w_bot // 2, cy + cup_h // 2),
    ], fill=(220, 200, 240))
    # Yogurt inside (top)
    d.ellipse([cx - cup_w_top // 2 + 10, cy - cup_h // 2 - 10, cx + cup_w_top // 2 - 10, cy - cup_h // 2 + 40], fill=(255, 255, 240))
    d.ellipse([cx - cup_w_top // 2 + 10, cy - cup_h // 2 - 15, cx + cup_w_top // 2 - 10, cy - cup_h // 2 + 30], fill=(255, 255, 245))
    # Berry
    d.ellipse([cx - 20, cy - cup_h // 2 - 5, cx + 20, cy + 15], fill=(200, 40, 60))
    d.ellipse([cx - 15, cy - cup_h // 2, cx + 15, cy + 10], fill=(220, 50, 70))
    # Cup label
    d.rectangle([cx - 80, cy - 30, cx + 80, cy + 30], fill=(100, 60, 140, 150))
    d.rectangle([cx - 75, cy - 25, cx + 75, cy + 25], fill=(120, 80, 160, 150))
    # Cup bottom
    d.rectangle([cx - cup_w_bot // 2 + 10, cy + cup_h // 2 - 10, cx + cup_w_bot // 2 - 10, cy + cup_h // 2], fill=(180, 160, 200))
    _paste_shadow(img, y, (0, 20))
    return img

def draw_kot():
    """К → Кот (orange tabby cat)"""
    img = _linear_gradient(BIG, [(60, 70, 80), (80, 100, 110), (50, 60, 70)])
    cat = _bg(BIG)
    d = ImageDraw.Draw(cat)
    cx, cy = BIG // 2, BIG // 2 + 40
    # Body
    d.ellipse([cx - 160, cy - 50, cx + 140, cy + 180], fill=(220, 140, 60))
    # Head
    d.ellipse([cx - 130, cy - 220, cx + 100, cy - 40], fill=(230, 150, 70))
    # Ears (pointy triangles)
    d.polygon([(cx - 115, cy - 180), (cx - 90, cy - 280), (cx - 60, cy - 190)], fill=(230, 150, 70))
    d.polygon([(cx - 40, cy - 185), (cx - 15, cy - 280), (cx + 15, cy - 190)], fill=(230, 150, 70))
    # Inner ears
    d.polygon([(cx - 105, cy - 190), (cx - 90, cy - 260), (cx - 70, cy - 195)], fill=(255, 180, 130))
    d.polygon([(cx - 35, cy - 195), (cx - 18, cy - 260), (cx + 2, cy - 195)], fill=(255, 180, 130))
    # Tabby stripes
    stripe_color = (190, 110, 40)
    # Forehead M
    d.polygon([(cx - 50, cy - 150), (cx - 30, cy - 175), (cx - 10, cy - 155)], fill=stripe_color)
    d.polygon([(cx + 10, cy - 155), (cx + 30, cy - 175), (cx + 50, cy - 150)], fill=stripe_color)
    d.polygon([(cx - 30, cy - 175), (cx, cy - 185), (cx + 30, cy - 175)], fill=stripe_color)
    # Body stripes
    for i in range(5):
        sx = cx - 120 + i * 55
        d.ellipse([sx, cy, sx + 15, cy + 100], fill=stripe_color)
    # Eyes
    d.ellipse([cx - 90, cy - 160, cx - 45, cy - 125], fill=(50, 180, 50))
    d.ellipse([cx - 20, cy - 160, cx + 25, cy - 125], fill=(50, 180, 50))
    d.ellipse([cx - 78, cy - 150, cx - 57, cy - 135], fill=(30, 30, 30))
    d.ellipse([cx - 8, cy - 150, cx + 13, cy - 135], fill=(30, 30, 30))
    d.ellipse([cx - 73, cy - 147, cx - 62, cy - 140], fill=(255, 255, 255))
    d.ellipse([cx - 3, cy - 147, cx + 8, cy - 140], fill=(255, 255, 255))
    # Nose
    d.polygon([(cx - 8, cy - 110), (cx, cy - 100), (cx + 8, cy - 110)], fill=(220, 80, 80))
    # Mouth
    d.arc([cx - 20, cy - 105, cx, cy - 80], 0, 180, fill=(80, 50, 30), width=3)
    d.arc([cx, cy - 105, cx + 20, cy - 80], 0, 180, fill=(80, 50, 30), width=3)
    # Whiskers
    for s in [-1, 1]:
        for i, (dx, dy) in enumerate([(30, -15), (40, -5), (30, 5)]):
            d.line([cx + s * 25, cy - 95 + dy, cx + s * (60 + dx), cy - 90 + dy], fill=(200, 200, 200), width=2)
    # Tail
    d.ellipse([cx + 120, cy + 20, cx + 210, cy + 110], fill=(220, 140, 60))
    # Paws
    d.ellipse([cx - 120, cy + 150, cx - 70, cy + 195], fill=(220, 140, 60))
    d.ellipse([cx - 20, cy + 150, cx + 30, cy + 195], fill=(220, 140, 60))
    _paste_shadow(img, cat, (0, 20))
    return img

def draw_lisa():
    """Л → Лиса (fox)"""
    img = _linear_gradient(BIG, [(60, 70, 50), (80, 100, 70), (50, 60, 40)])
    fx = _bg(BIG)
    d = ImageDraw.Draw(fx)
    cx, cy = BIG // 2, BIG // 2 + 40
    # Body
    d.ellipse([cx - 160, cy - 60, cx + 130, cy + 170], fill=(220, 120, 40))
    # Head
    d.ellipse([cx - 120, cy - 230, cx + 90, cy - 60], fill=(230, 130, 50))
    # Ears (large, pointy)
    d.polygon([(cx - 100, cy - 200), (cx - 70, cy - 300), (cx - 40, cy - 205)], fill=(230, 130, 50))
    d.polygon([(cx - 30, cy - 205), (cx, cy - 300), (cx + 30, cy - 205)], fill=(230, 130, 50))
    d.polygon([(cx - 90, cy - 210), (cx - 70, cy - 280), (cx - 50, cy - 210)], fill=(255, 200, 150))
    d.polygon([(cx - 20, cy - 210), (cx + 2, cy - 280), (cx + 22, cy - 210)], fill=(255, 200, 150))
    # White cheeks/face bottom
    d.ellipse([cx - 90, cy - 140, cx + 50, cy - 60], fill=(250, 240, 230))
    # Eyes
    d.ellipse([cx - 75, cy - 175, cx - 35, cy - 140], fill=(30, 30, 30))
    d.ellipse([cx - 15, cy - 175, cx + 25, cy - 140], fill=(30, 30, 30))
    d.ellipse([cx - 66, cy - 168, cx - 44, cy - 147], fill=(255, 220, 80))
    d.ellipse([cx - 6, cy - 168, cx + 16, cy - 147], fill=(255, 220, 80))
    d.ellipse([cx - 62, cy - 164, cx - 48, cy - 152], fill=(255, 255, 255))
    d.ellipse([cx - 2, cy - 164, cx + 12, cy - 152], fill=(255, 255, 255))
    # Nose
    d.ellipse([cx - 10, cy - 125, cx + 12, cy - 105], fill=(30, 30, 30))
    # Smile
    d.arc([cx - 30, cy - 115, cx + 10, cy - 85], 0, 180, fill=(80, 50, 30), width=3)
    # White tail tip
    d.ellipse([cx + 115, cy + 20, cx + 230, cy + 110], fill=(220, 120, 40))
    d.ellipse([cx + 180, cy + 5, cx + 240, cy + 80], fill=(250, 240, 230))
    # Legs
    d.ellipse([cx - 130, cy + 140, cx - 80, cy + 195], fill=(200, 100, 30))
    d.ellipse([cx - 30, cy + 140, cx + 20, cy + 195], fill=(200, 100, 30))
    _paste_shadow(img, fx, (0, 20))
    return img

def draw_medved():
    """М → Медведь (bear, standing)"""
    img = _linear_gradient(BIG, [(50, 70, 60), (70, 100, 80), (40, 60, 50)])
    b = _bg(BIG)
    d = ImageDraw.Draw(b)
    cx, cy = BIG // 2, BIG // 2
    # Body (standing)
    d.ellipse([cx - 170, cy - 50, cx + 170, cy + 230], fill=(120, 80, 50))
    # Head
    d.ellipse([cx - 130, cy - 260, cx + 130, cy - 40], fill=(130, 90, 55))
    # Ears
    d.ellipse([cx - 100, cy - 300, cx - 50, cy - 240], fill=(130, 90, 55))
    d.ellipse([cx + 50, cy - 300, cx + 100, cy - 240], fill=(130, 90, 55))
    d.ellipse([cx - 92, cy - 292, cx - 58, cy - 250], fill=(180, 140, 100))
    d.ellipse([cx + 58, cy - 292, cx + 92, cy - 250], fill=(180, 140, 100))
    # Muzzle
    d.ellipse([cx - 70, cy - 160, cx + 70, cy - 70], fill=(180, 150, 110))
    # Nose
    d.ellipse([cx - 25, cy - 135, cx + 25, cy - 90], fill=(40, 30, 20))
    # Eyes
    d.ellipse([cx - 75, cy - 200, cx - 35, cy - 165], fill=(30, 30, 20))
    d.ellipse([cx + 35, cy - 200, cx + 75, cy - 165], fill=(30, 30, 20))
    d.ellipse([cx - 67, cy - 194, cx - 43, cy - 172], fill=(255, 255, 240))
    d.ellipse([cx + 43, cy - 194, cx + 67, cy - 172], fill=(255, 255, 240))
    # Mouth
    d.arc([cx - 30, cy - 115, cx + 30, cy - 75], 0, 180, fill=(60, 40, 30), width=4)
    # Belly (lighter)
    d.ellipse([cx - 100, cy - 20, cx + 100, cy + 150], fill=(160, 120, 80, 150))
    # Arms
    d.ellipse([cx - 230, cy + 10, cx - 150, cy + 130], fill=(120, 80, 50))
    d.ellipse([cx + 150, cy + 10, cx + 230, cy + 130], fill=(120, 80, 50))
    # Legs
    d.ellipse([cx - 120, cy + 200, cx - 40, cy + 290], fill=(110, 70, 45))
    d.ellipse([cx + 40, cy + 200, cx + 120, cy + 290], fill=(110, 70, 45))
    _paste_shadow(img, b, (0, 15))
    return img

def draw_nosorog():
    """Н → Носорог (rhinoceros)"""
    img = _linear_gradient(BIG, [(60, 70, 50), (80, 100, 70), (50, 60, 40)])
    r = _bg(BIG)
    d = ImageDraw.Draw(r)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body (large oval)
    d.ellipse([cx - 200, cy - 60, cx + 180, cy + 170], fill=(160, 155, 150))
    # Head
    d.ellipse([cx - 230, cy - 160, cx + 60, cy - 20], fill=(170, 165, 160))
    # Ear
    d.ellipse([cx - 50, cy - 200, cx - 10, cy - 150], fill=(160, 155, 150))
    d.ellipse([cx - 45, cy - 192, cx - 15, cy - 158], fill=(190, 185, 180))
    # Horn (main)
    d.polygon([(cx - 180, cy - 130), (cx - 150, cy - 250), (cx - 130, cy - 120)], fill=(180, 170, 150))
    d.polygon([(cx - 175, cy - 130), (cx - 150, cy - 235), (cx - 135, cy - 125)], fill=(200, 190, 170))
    # Second horn (small)
    d.polygon([(cx - 160, cy - 125), (cx - 145, cy - 175), (cx - 135, cy - 120)], fill=(180, 170, 150))
    # Eye
    d.ellipse([cx - 110, cy - 120, cx - 75, cy - 90], fill=(30, 30, 30))
    d.ellipse([cx - 103, cy - 115, cx - 82, cy - 97], fill=(255, 255, 240))
    # Legs
    for ox in [-150, -70, 10, 90]:
        d.ellipse([cx + ox, cy + 140, cx + ox + 40, cy + 220], fill=(150, 145, 140))
    # Tail
    d.ellipse([cx + 170, cy - 20, cx + 210, cy + 30], fill=(150, 145, 140))
    # Skin folds
    d.line([cx - 80, cy + 10, cx + 100, cy + 10], fill=(140, 135, 130), width=3)
    d.line([cx - 60, cy + 50, cx + 80, cy + 50], fill=(140, 135, 130), width=3)
    _paste_shadow(img, r, (0, 20))
    return img

def draw_okno():
    """О → Окно (window)"""
    img = _linear_gradient(BIG, [(60, 60, 80), (90, 90, 110), (50, 50, 70)])
    w = _bg(BIG)
    d = ImageDraw.Draw(w)
    cx, cy = BIG // 2, BIG // 2
    # Window frame (outer)
    frame_w = 380
    frame_h = 400
    x1 = cx - frame_w // 2
    y1 = cy - frame_h // 2
    x2 = cx + frame_w // 2
    y2 = cy + frame_h // 2
    d.rectangle([x1, y1, x2, y2], fill=(120, 80, 50))
    # Inner frame
    inset = 20
    d.rectangle([x1 + inset, y1 + inset, x2 - inset, y2 - inset], fill=(180, 200, 220))
    # Window pane (glass)
    pane_inset = 25
    d.rectangle([x1 + pane_inset, y1 + pane_inset, x2 - pane_inset, y2 - pane_inset], fill=(200, 225, 245))
    # Sky through window
    d.rectangle([x1 + pane_inset, y1 + pane_inset, x2 - pane_inset, y1 + frame_h // 2], fill=(150, 200, 240))
    # Cross dividers
    d.line([cx, y1 + inset, cx, y2 - inset], fill=(120, 80, 50), width=8)
    d.line([x1 + inset, cy, x2 - inset, cy], fill=(120, 80, 50), width=8)
    # Window sill
    sill_w = frame_w + 40
    d.rectangle([cx - sill_w // 2, y2 - 10, cx + sill_w // 2, y2 + 25], fill=(100, 65, 40))
    d.rectangle([cx - sill_w // 2 + 5, y2 - 5, cx + sill_w // 2 - 5, y2 + 20], fill=(130, 85, 55))
    # Curtains (left and right)
    # Left curtain
    d.polygon([
        (x1, y1),
        (x1 + 60, y1),
        (x1 + 90, cy),
        (x1 + 60, y2),
        (x1, y2),
    ], fill=(200, 80, 100, 180))
    # Right curtain
    d.polygon([
        (x2, y1),
        (x2 - 60, y1),
        (x2 - 90, cy),
        (x2 - 60, y2),
        (x2, y2),
    ], fill=(200, 80, 100, 180))
    # Curtain drapes
    d.line([x1 + 15, y1 + 20, x1 + 50, y1 + 20], fill=(180, 60, 80, 180), width=3)
    d.line([x1 + 20, y1 + 50, x1 + 60, y1 + 50], fill=(180, 60, 80, 180), width=3)
    d.line([x2 - 15, y1 + 20, x2 - 50, y1 + 20], fill=(180, 60, 80, 180), width=3)
    d.line([x2 - 20, y1 + 50, x2 - 60, y1 + 50], fill=(180, 60, 80, 180), width=3)
    # Curtain top valance
    d.rectangle([x1, y1 - 5, x2, y1 + 25], fill=(190, 70, 90, 200))
    # Clouds through window
    d.ellipse([x1 + 80, y1 + 50, x1 + 150, y1 + 90], fill=(255, 255, 255, 100))
    d.ellipse([x1 + 120, y1 + 40, x1 + 190, y1 + 85], fill=(255, 255, 255, 100))
    # Sun through window
    d.ellipse([x2 - 100, y1 + 40, x2 - 50, y1 + 95], fill=(255, 230, 100, 80))
    _paste_shadow(img, w, (0, 10))
    return img

def draw_pingvin():
    """П → Пингвин (penguin)"""
    img = _linear_gradient(BIG, [(30, 60, 90), (50, 80, 110), (30, 50, 70)])
    p = _bg(BIG)
    d = ImageDraw.Draw(p)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body (black oval)
    d.ellipse([cx - 140, cy - 130, cx + 140, cy + 190], fill=(30, 30, 35))
    # White belly
    d.ellipse([cx - 80, cy - 80, cx + 80, cy + 160], fill=(240, 240, 245))
    # Head (black)
    d.ellipse([cx - 100, cy - 240, cx + 100, cy - 90], fill=(30, 30, 35))
    # White face patch
    d.ellipse([cx - 55, cy - 160, cx + 55, cy - 100], fill=(250, 250, 250))
    # Eyes
    d.ellipse([cx - 45, cy - 180, cx - 15, cy - 155], fill=(255, 255, 255))
    d.ellipse([cx + 15, cy - 180, cx + 45, cy - 155], fill=(255, 255, 255))
    d.ellipse([cx - 35, cy - 174, cx - 25, cy - 163], fill=(20, 20, 20))
    d.ellipse([cx + 25, cy - 174, cx + 35, cy - 163], fill=(20, 20, 20))
    # Beak
    d.polygon([(cx - 5, cy - 145), (cx, cy - 125), (cx + 5, cy - 145)], fill=(255, 150, 30))
    d.polygon([(cx - 5, cy - 145), (cx, cy - 135), (cx + 5, cy - 145)], fill=(255, 120, 20))
    # Wings
    d.ellipse([cx - 200, cy - 60, cx - 120, cy + 80], fill=(30, 30, 35))
    d.ellipse([cx + 120, cy - 60, cx + 200, cy + 80], fill=(30, 30, 35))
    # Feet
    d.ellipse([cx - 60, cy + 170, cx, cy + 210], fill=(255, 150, 30))
    d.ellipse([cx, cy + 170, cx + 60, cy + 210], fill=(255, 150, 30))
    # Highlight
    d.ellipse([cx - 60, cy - 210, cx - 20, cy - 150], fill=(60, 60, 70, 80))
    _paste_shadow(img, p, (0, 20))
    return img

def draw_ryba():
    """Р → Рыба (fish)"""
    img = _linear_gradient(BIG, [(20, 60, 90), (40, 80, 110), (20, 50, 70)])
    f = _bg(BIG)
    d = ImageDraw.Draw(f)
    cx, cy = BIG // 2, BIG // 2 + 10
    # Body
    d.ellipse([cx - 200, cy - 110, cx + 170, cy + 110], fill=(50, 130, 180))
    d.ellipse([cx - 190, cy - 100, cx + 160, cy + 100], fill=(60, 150, 200))
    # Belly (lighter)
    d.ellipse([cx - 170, cy - 30, cx + 140, cy + 90], fill=(200, 230, 255, 120))
    # Tail
    d.polygon([
        (cx + 160, cy - 30),
        (cx + 280, cy - 100),
        (cx + 270, cy + 10),
        (cx + 280, cy + 100),
        (cx + 160, cy + 30),
    ], fill=(200, 100, 50))
    d.polygon([
        (cx + 165, cy - 25),
        (cx + 260, cy - 80),
        (cx + 255, cy + 5),
        (cx + 260, cy + 80),
        (cx + 165, cy + 25),
    ], fill=(220, 120, 60))
    # Dorsal fin
    d.polygon([
        (cx - 120, cy - 100),
        (cx - 60, cy - 190),
        (cx - 20, cy - 100),
    ], fill=(200, 100, 50))
    d.polygon([
        (cx - 110, cy - 105),
        (cx - 65, cy - 170),
        (cx - 30, cy - 105),
    ], fill=(220, 120, 60))
    # Pectoral fin
    d.ellipse([cx + 40, cy + 20, cx + 100, cy + 70], fill=(200, 100, 50))
    d.ellipse([cx + 45, cy + 22, cx + 95, cy + 60], fill=(220, 120, 60))
    # Eye
    d.ellipse([cx - 120, cy - 40, cx - 80, cy - 5], fill=(255, 255, 255))
    d.ellipse([cx - 112, cy - 32, cx - 88, cy - 13], fill=(30, 30, 30))
    d.ellipse([cx - 107, cy - 28, cx - 93, cy - 18], fill=(255, 255, 255))
    # Mouth
    d.ellipse([cx - 195, cy - 15, cx - 175, cy + 5], fill=(40, 40, 40))
    # Bubbles
    for bx, by, br in [(30, -160, 12), (60, -190, 8), (90, -170, 6)]:
        d.ellipse([cx + bx - br, cy + by - br, cx + bx + br, cy + by + br], fill=(200, 230, 255, 120))
    # Scales pattern
    for i in range(-3, 4):
        scx = cx + i * 45
        d.arc([scx - 20, cy - 30, scx + 20, cy + 30], 180, 360, fill=(100, 180, 220, 80), width=2)
    # Highlight on body
    d.ellipse([cx - 120, cy - 70, cx - 30, cy - 20], fill=(255, 255, 255, 50))
    _paste_shadow(img, f, (0, 15))
    return img

def draw_sova():
    """С → Сова (owl)"""
    img = _linear_gradient(BIG, [(40, 50, 70), (60, 70, 90), (30, 40, 60)])
    ow = _bg(BIG)
    d = ImageDraw.Draw(ow)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 160, cy - 60, cx + 160, cy + 200], fill=(130, 100, 70))
    d.ellipse([cx - 150, cy - 50, cx + 150, cy + 190], fill=(150, 115, 80))
    # Feather pattern on belly
    d.ellipse([cx - 100, cy + 20, cx + 100, cy + 160], fill=(180, 150, 110, 150))
    for i in range(-2, 3):
        fy = cy + 50 + i * 35
        d.arc([cx - 60, fy - 10, cx + 60, fy + 10], 0, 360, fill=(140, 110, 80), width=2)
    # Head
    d.ellipse([cx - 140, cy - 230, cx + 140, cy - 40], fill=(130, 100, 70))
    d.ellipse([cx - 130, cy - 220, cx + 130, cy - 50], fill=(150, 115, 80))
    # Ear tufts
    d.polygon([(cx - 120, cy - 200), (cx - 100, cy - 280), (cx - 70, cy - 200)], fill=(120, 90, 60))
    d.polygon([(cx + 70, cy - 200), (cx + 100, cy - 280), (cx + 120, cy - 200)], fill=(120, 90, 60))
    # Eye circles (large)
    d.ellipse([cx - 110, cy - 170, cx - 20, cy - 80], fill=(240, 240, 230))
    d.ellipse([cx + 20, cy - 170, cx + 110, cy - 80], fill=(240, 240, 230))
    # Irises (yellow)
    d.ellipse([cx - 85, cy - 150, cx - 45, cy - 105], fill=(255, 200, 50))
    d.ellipse([cx + 45, cy - 150, cx + 85, cy - 105], fill=(255, 200, 50))
    # Pupils
    d.ellipse([cx - 75, cy - 135, cx - 55, cy - 115], fill=(20, 20, 20))
    d.ellipse([cx + 55, cy - 135, cx + 75, cy - 115], fill=(20, 20, 20))
    # Eye highlights
    d.ellipse([cx - 70, cy - 130, cx - 62, cy - 122], fill=(255, 255, 255))
    d.ellipse([cx + 60, cy - 130, cx + 68, cy - 122], fill=(255, 255, 255))
    # Beak
    d.polygon([(cx - 5, cy - 120), (cx, cy - 95), (cx + 5, cy - 120)], fill=(220, 160, 50))
    d.polygon([(cx - 5, cy - 120), (cx, cy - 105), (cx + 5, cy - 120)], fill=(200, 140, 40))
    # Wings
    d.ellipse([cx - 210, cy - 40, cx - 150, cy + 100], fill=(120, 90, 60))
    d.ellipse([cx + 150, cy - 40, cx + 210, cy + 100], fill=(120, 90, 60))
    # Feet (talons)
    d.ellipse([cx - 50, cy + 180, cx - 20, cy + 215], fill=(200, 160, 60))
    d.ellipse([cx + 20, cy + 180, cx + 50, cy + 215], fill=(200, 160, 60))
    _paste_shadow(img, ow, (0, 20))
    return img

def draw_tigr():
    """Т → Тигр (tiger)"""
    img = _linear_gradient(BIG, [(50, 70, 50), (70, 100, 70), (40, 60, 40)])
    t = _bg(BIG)
    d = ImageDraw.Draw(t)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 180, cy - 50, cx + 150, cy + 190], fill=(220, 140, 50))
    # Head
    d.ellipse([cx - 130, cy - 230, cx + 110, cy - 50], fill=(230, 150, 60))
    # Ears
    d.ellipse([cx - 110, cy - 270, cx - 65, cy - 210], fill=(230, 150, 60))
    d.ellipse([cx - 30, cy - 270, cx + 15, cy - 210], fill=(230, 150, 60))
    d.ellipse([cx - 103, cy - 260, cx - 72, cy - 220], fill=(255, 200, 150))
    d.ellipse([cx - 23, cy - 260, cx + 8, cy - 220], fill=(255, 200, 150))
    # White face parts
    d.ellipse([cx - 100, cy - 150, cx + 70, cy - 55], fill=(240, 230, 220))
    # Stripes (black)
    stripe = (20, 20, 20)
    # Forehead stripes
    d.ellipse([cx - 50, cy - 190, cx - 30, cy - 155], fill=stripe)
    d.ellipse([cx - 15, cy - 195, cx + 5, cy - 160], fill=stripe)
    d.ellipse([cx + 20, cy - 190, cx + 40, cy - 155], fill=stripe)
    # Body stripes
    for i in range(6):
        sx = cx - 140 + i * 50
        d.ellipse([sx, cy - 30, sx + 18, cy + 150], fill=stripe)
    # Tail
    d.ellipse([cx + 135, cy + 10, cx + 230, cy + 100], fill=(220, 140, 50))
    d.ellipse([cx + 200, cy + 30, cx + 240, cy + 80], fill=stripe)
    # Eyes
    d.ellipse([cx - 90, cy - 165, cx - 50, cy - 130], fill=(100, 200, 80))
    d.ellipse([cx - 20, cy - 165, cx + 20, cy - 130], fill=(100, 200, 80))
    d.ellipse([cx - 80, cy - 157, cx - 60, cy - 138], fill=(30, 30, 30))
    d.ellipse([cx - 10, cy - 157, cx + 10, cy - 138], fill=(30, 30, 30))
    d.ellipse([cx - 75, cy - 153, cx - 65, cy - 143], fill=(255, 255, 255))
    d.ellipse([cx - 5, cy - 153, cx + 5, cy - 143], fill=(255, 255, 255))
    # Nose
    d.ellipse([cx - 10, cy - 110, cx + 10, cy - 92], fill=(220, 80, 80))
    # Mouth
    d.arc([cx - 25, cy - 100, cx, cy - 78], 0, 180, fill=(60, 40, 30), width=3)
    d.arc([cx, cy - 100, cx + 25, cy - 78], 0, 180, fill=(60, 40, 30), width=3)
    # Whiskers
    for s in [-1, 1]:
        for dy in [-5, 5, 15]:
            d.line([cx + s * 20, cy - 95 + dy, cx + s * 70, cy - 90 + dy], fill=(200, 200, 200), width=2)
    # Paws
    d.ellipse([cx - 140, cy + 160, cx - 80, cy + 210], fill=(200, 120, 40))
    d.ellipse([cx - 30, cy + 160, cx + 30, cy + 210], fill=(200, 120, 40))
    _paste_shadow(img, t, (0, 20))
    return img

def draw_utka():
    """У → Утка (duck)"""
    img = _linear_gradient(BIG, [(30, 70, 80), (50, 100, 110), (30, 60, 70)])
    dck = _bg(BIG)
    d = ImageDraw.Draw(dck)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 170, cy - 40, cx + 150, cy + 170], fill=(240, 220, 50))
    d.ellipse([cx - 160, cy - 30, cx + 140, cy + 160], fill=(250, 230, 80))
    # Neck
    d.ellipse([cx - 70, cy - 140, cx + 50, cy - 10], fill=(240, 220, 50))
    # Head
    d.ellipse([cx - 80, cy - 230, cx + 60, cy - 110], fill=(50, 170, 50))
    d.ellipse([cx - 70, cy - 220, cx + 50, cy - 120], fill=(60, 190, 60))
    # Eye
    d.ellipse([cx - 30, cy - 180, cx - 5, cy - 155], fill=(255, 255, 255))
    d.ellipse([cx - 25, cy - 175, cx - 10, cy - 160], fill=(20, 20, 20))
    d.ellipse([cx - 22, cy - 172, cx - 16, cy - 165], fill=(255, 255, 255))
    # Beak
    d.ellipse([cx - 60, cy - 150, cx, cy - 120], fill=(255, 150, 30))
    d.ellipse([cx - 55, cy - 148, cx - 5, cy - 125], fill=(255, 170, 50))
    d.line([cx - 50, cy - 135, cx - 5, cy - 135], fill=(220, 120, 20), width=2)
    # Wing
    d.ellipse([cx - 80, cy, cx + 30, cy + 100], fill=(230, 200, 40, 180))
    # Tail
    d.ellipse([cx + 130, cy + 10, cx + 190, cy + 70], fill=(230, 200, 40))
    d.ellipse([cx + 140, cy, cx + 200, cy + 40], fill=(240, 220, 50))
    # Feet
    d.ellipse([cx - 90, cy + 150, cx - 40, cy + 195], fill=(255, 150, 30))
    d.ellipse([cx - 20, cy + 150, cx + 30, cy + 195], fill=(255, 150, 30))
    # Water ripples at base
    for i in range(3):
        rx = cx - 120 + i * 80
        d.ellipse([rx, cy + 180, rx + 100, cy + 210], fill=(100, 180, 220, 80))
    _paste_shadow(img, dck, (0, 20))
    return img

def draw_filin():
    """Ф → Филин (eagle owl)"""
    img = _linear_gradient(BIG, [(40, 40, 60), (60, 60, 80), (30, 30, 50)])
    fl = _bg(BIG)
    d = ImageDraw.Draw(fl)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 140, cy - 50, cx + 140, cy + 190], fill=(110, 80, 50))
    d.ellipse([cx - 130, cy - 40, cx + 130, cy + 180], fill=(130, 100, 65))
    # Belly feathers
    d.ellipse([cx - 80, cy + 20, cx + 80, cy + 160], fill=(170, 140, 100, 150))
    for i in range(-1, 2):
        fy = cy + 50 + i * 40
        d.arc([cx - 50, fy - 10, cx + 50, fy + 10], 0, 360, fill=(120, 90, 60), width=2)
    # Head
    d.ellipse([cx - 130, cy - 220, cx + 130, cy - 40], fill=(110, 80, 50))
    d.ellipse([cx - 120, cy - 210, cx + 120, cy - 50], fill=(130, 100, 65))
    # Ear tufts (longer than owl)
    d.polygon([(cx - 110, cy - 190), (cx - 85, cy - 290), (cx - 55, cy - 190)], fill=(100, 70, 40))
    d.polygon([(cx + 55, cy - 190), (cx + 85, cy - 290), (cx + 110, cy - 190)], fill=(100, 70, 40))
    # Facial disc
    d.ellipse([cx - 100, cy - 170, cx + 100, cy - 80], fill=(170, 140, 100))
    # Eye patches (dark)
    d.ellipse([cx - 85, cy - 165, cx - 25, cy - 95], fill=(60, 50, 35))
    d.ellipse([cx + 25, cy - 165, cx + 85, cy - 95], fill=(60, 50, 35))
    # Eyes (big, yellow-orange)
    d.ellipse([cx - 75, cy - 155, cx - 35, cy - 110], fill=(255, 180, 50))
    d.ellipse([cx + 35, cy - 155, cx + 75, cy - 110], fill=(255, 180, 50))
    # Pupils
    d.ellipse([cx - 65, cy - 143, cx - 45, cy - 122], fill=(20, 20, 20))
    d.ellipse([cx + 45, cy - 143, cx + 65, cy - 122], fill=(20, 20, 20))
    # Eye highlights
    d.ellipse([cx - 60, cy - 140, cx - 52, cy - 130], fill=(255, 255, 255))
    d.ellipse([cx + 52, cy - 140, cx + 60, cy - 130], fill=(255, 255, 255))
    # Beak
    d.polygon([(cx - 6, cy - 120), (cx, cy - 95), (cx + 6, cy - 120)], fill=(200, 160, 50))
    # Wings
    d.ellipse([cx - 190, cy - 20, cx - 130, cy + 110], fill=(110, 80, 50))
    d.ellipse([cx + 130, cy - 20, cx + 190, cy + 110], fill=(110, 80, 50))
    # Feet
    d.ellipse([cx - 45, cy + 170, cx - 15, cy + 205], fill=(180, 140, 60))
    d.ellipse([cx + 15, cy + 170, cx + 45, cy + 205], fill=(180, 140, 60))
    _paste_shadow(img, fl, (0, 20))
    return img

def draw_hleb():
    """Х → Хлеб (bread)"""
    img = _linear_gradient(BIG, [(60, 50, 40), (80, 70, 50), (50, 40, 30)])
    b = _bg(BIG)
    d = ImageDraw.Draw(b)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Main loaf body (oval/dome)
    d.ellipse([cx - 200, cy - 60, cx + 200, cy + 100], fill=(190, 140, 80))
    d.ellipse([cx - 190, cy - 55, cx + 190, cy + 95], fill=(210, 160, 95))
    # Top crust (darker)
    d.ellipse([cx - 190, cy - 110, cx + 190, cy + 10], fill=(160, 100, 50))
    d.ellipse([cx - 185, cy - 105, cx + 185, cy + 5], fill=(180, 120, 60))
    # Score marks on top
    d.line([cx - 120, cy - 70, cx + 120, cy - 50], fill=(140, 80, 40), width=5)
    d.line([cx - 100, cy - 55, cx + 100, cy - 35], fill=(140, 80, 40), width=4)
    d.line([cx - 80, cy - 40, cx + 80, cy - 20], fill=(140, 80, 40), width=3)
    # Side highlight
    d.ellipse([cx - 170, cy - 30, cx - 60, cy + 60], fill=(240, 200, 140, 80))
    # Bottom shadow
    d.ellipse([cx - 180, cy + 70, cx + 180, cy + 100], fill=(140, 100, 60, 100))
    _paste_shadow(img, b, (0, 20))
    return img

def draw_cyplenok():
    """Ц → Цыпленок (chick)"""
    img = _linear_gradient(BIG, [(60, 80, 50), (80, 110, 70), (50, 70, 40)])
    c = _bg(BIG)
    d = ImageDraw.Draw(c)
    cx, cy = BIG // 2, BIG // 2 + 40
    # Body (fluffy yellow ball)
    d.ellipse([cx - 160, cy - 80, cx + 130, cy + 150], fill=(255, 220, 50))
    d.ellipse([cx - 150, cy - 70, cx + 120, cy + 140], fill=(255, 235, 80))
    # Fluffy texture
    for _ in range(30):
        import random
        rx = random.randint(cx - 140, cx + 110)
        ry = random.randint(cy - 60, cy + 120)
        rr = random.randint(8, 20)
        d.ellipse([rx - rr, ry - rr, rx + rr, ry + rr], fill=(255, 240, 100, 120))
    # Head
    d.ellipse([cx - 100, cy - 200, cx + 80, cy - 60], fill=(255, 220, 50))
    d.ellipse([cx - 90, cy - 190, cx + 70, cy - 70], fill=(255, 235, 80))
    # Eyes
    d.ellipse([cx - 55, cy - 145, cx - 25, cy - 115], fill=(30, 30, 30))
    d.ellipse([cx - 5, cy - 145, cx + 25, cy - 115], fill=(30, 30, 30))
    d.ellipse([cx - 48, cy - 140, cx - 32, cy - 123], fill=(255, 255, 255))
    d.ellipse([cx + 2, cy - 140, cx + 18, cy - 123], fill=(255, 255, 255))
    # Beak (small, orange)
    d.polygon([(cx - 8, cy - 110), (cx, cy - 95), (cx + 8, cy - 110)], fill=(255, 150, 30))
    d.polygon([(cx - 6, cy - 108), (cx, cy - 100), (cx + 6, cy - 108)], fill=(255, 180, 50))
    # Blush
    d.ellipse([cx - 75, cy - 115, cx - 50, cy - 90], fill=(255, 150, 100, 80))
    d.ellipse([cx + 30, cy - 115, cx + 55, cy - 90], fill=(255, 150, 100, 80))
    # Wings (small, yellow)
    d.ellipse([cx - 180, cy - 20, cx - 110, cy + 40], fill=(240, 200, 40))
    d.ellipse([cx + 100, cy - 20, cx + 170, cy + 40], fill=(240, 200, 40))
    # Feet (orange)
    d.ellipse([cx - 50, cy + 130, cx - 20, cy + 160], fill=(255, 150, 30))
    d.ellipse([cx + 10, cy + 130, cx + 40, cy + 160], fill=(255, 150, 30))
    # Tiny tuft on head
    d.ellipse([cx - 5, cy - 210, cx + 12, cy - 185], fill=(255, 220, 50))
    d.ellipse([cx - 15, cy - 215, cx + 5, cy - 190], fill=(255, 230, 70))
    _paste_shadow(img, c, (0, 20))
    return img

def draw_cherepaha():
    """Ч → Черепаха (turtle)"""
    img = _linear_gradient(BIG, [(50, 70, 50), (70, 100, 70), (40, 60, 40)])
    t = _bg(BIG)
    d = ImageDraw.Draw(t)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body (under shell)
    d.ellipse([cx - 160, cy - 20, cx + 160, cy + 180], fill=(100, 160, 80))
    # Shell (large dome)
    d.ellipse([cx - 200, cy - 120, cx + 200, cy + 100], fill=(50, 130, 50))
    d.ellipse([cx - 190, cy - 110, cx + 190, cy + 90], fill=(60, 150, 60))
    # Shell pattern (hexagons-like)
    # Center hex
    d.polygon([
        (cx, cy - 90), (cx + 50, cy - 60), (cx + 50, cy - 10),
        (cx, cy + 10), (cx - 50, cy - 10), (cx - 50, cy - 60),
    ], fill=(40, 110, 40))
    d.polygon([
        (cx, cy - 80), (cx + 40, cy - 55), (cx + 40, cy - 10),
        (cx, cy + 5), (cx - 40, cy - 10), (cx - 40, cy - 55),
    ], fill=(50, 130, 50))
    # Side patterns
    for dx, dy in [(-100, -20), (100, -20), (-60, 30), (60, 30)]:
        d.polygon([
            (cx + dx - 40, cy + dy - 30),
            (cx + dx, cy + dy - 50),
            (cx + dx + 40, cy + dy - 30),
            (cx + dx + 40, cy + dy + 10),
            (cx + dx, cy + dy + 20),
            (cx + dx - 40, cy + dy + 10),
        ], fill=(40, 110, 40))
    # Head
    d.ellipse([cx - 80, cy - 200, cx + 50, cy - 90], fill=(100, 160, 80))
    d.ellipse([cx - 70, cy - 190, cx + 40, cy - 100], fill=(120, 180, 95))
    # Eyes
    d.ellipse([cx - 40, cy - 160, cx - 15, cy - 135], fill=(255, 255, 255))
    d.ellipse([cx + 5, cy - 160, cx + 30, cy - 135], fill=(255, 255, 255))
    d.ellipse([cx - 33, cy - 153, cx - 22, cy - 142], fill=(30, 30, 30))
    d.ellipse([cx + 12, cy - 153, cx + 23, cy - 142], fill=(30, 30, 30))
    # Mouth (smile)
    d.arc([cx - 25, cy - 125, cx + 5, cy - 100], 0, 180, fill=(60, 100, 50), width=3)
    # Legs
    d.ellipse([cx - 180, cy + 30, cx - 120, cy + 90], fill=(100, 160, 80))
    d.ellipse([cx + 110, cy + 30, cx + 170, cy + 90], fill=(100, 160, 80))
    d.ellipse([cx - 140, cy + 70, cx - 80, cy + 130], fill=(90, 150, 70))
    d.ellipse([cx + 70, cy + 70, cx + 130, cy + 130], fill=(90, 150, 70))
    # Tail
    d.polygon([(cx + 140, cy + 50), (cx + 190, cy + 40), (cx + 150, cy + 70)], fill=(100, 160, 80))
    _paste_shadow(img, t, (0, 20))
    return img

def draw_shapka():
    """Ш → Шапка (winter hat)"""
    img = _linear_gradient(BIG, [(60, 70, 90), (80, 100, 120), (50, 60, 80)])
    h = _bg(BIG)
    d = ImageDraw.Draw(h)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Hat body (dome)
    d.ellipse([cx - 190, cy - 70, cx + 190, cy + 110], fill=(180, 40, 60))
    d.ellipse([cx - 180, cy - 65, cx + 180, cy + 105], fill=(200, 50, 70))
    # Hat dome top
    d.ellipse([cx - 170, cy - 200, cx + 170, cy - 10], fill=(180, 40, 60))
    d.ellipse([cx - 160, cy - 195, cx + 160, cy - 15], fill=(200, 50, 70))
    # Pompom (fur ball)
    d.ellipse([cx - 40, cy - 250, cx + 40, cy - 180], fill=(230, 230, 240))
    d.ellipse([cx - 30, cy - 240, cx + 30, cy - 190], fill=(245, 245, 255))
    for _ in range(15):
        import random
        px = cx + random.randint(-35, 35)
        py = cy - 220 + random.randint(-20, 20)
        pr = random.randint(10, 22)
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(250, 250, 255, 150))
    # Fur brim (bottom)
    d.ellipse([cx - 210, cy + 30, cx + 210, cy + 110], fill=(230, 230, 240))
    d.ellipse([cx - 200, cy + 35, cx + 200, cy + 105], fill=(245, 245, 255))
    # Brim fur texture
    for _ in range(20):
        import random
        bx = cx + random.randint(-180, 180)
        by = cy + 60 + random.randint(-15, 15)
        br = random.randint(10, 18)
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=(250, 250, 255, 140))
    # Stripe on hat
    d.ellipse([cx - 175, cy - 80, cx + 175, cy - 40], fill=(50, 150, 180, 180))
    d.ellipse([cx - 170, cy - 75, cx + 170, cy - 45], fill=(60, 170, 200, 180))
    # Star/flake pattern
    d.polygon([(cx, cy - 60), (cx + 5, cy - 48), (cx + 18, cy - 48),
               (cx + 8, cy - 38), (cx + 12, cy - 25), (cx, cy - 33),
               (cx - 12, cy - 25), (cx - 8, cy - 38), (cx - 18, cy - 48),
               (cx - 5, cy - 48)], fill=(255, 255, 255, 180))
    _paste_shadow(img, h, (0, 20))
    return img

def draw_shenok():
    """Щ → Щенок (puppy)"""
    img = _linear_gradient(BIG, [(60, 60, 50), (80, 90, 70), (50, 50, 40)])
    p = _bg(BIG)
    d = ImageDraw.Draw(p)
    cx, cy = BIG // 2, BIG // 2 + 40
    # Body
    d.ellipse([cx - 160, cy - 40, cx + 140, cy + 170], fill=(170, 120, 70))
    # Head
    d.ellipse([cx - 140, cy - 210, cx + 110, cy - 40], fill=(180, 130, 80))
    # Floppy ears
    d.ellipse([cx - 180, cy - 140, cx - 100, cy - 40], fill=(140, 95, 55))
    d.ellipse([cx + 70, cy - 140, cx + 150, cy - 40], fill=(140, 95, 55))
    d.ellipse([cx - 175, cy - 130, cx - 105, cy - 50], fill=(160, 110, 65))
    d.ellipse([cx + 75, cy - 130, cx + 145, cy - 50], fill=(160, 110, 65))
    # Face (lighter muzzle area)
    d.ellipse([cx - 90, cy - 140, cx + 55, cy - 50], fill=(210, 180, 140))
    # Eyes (big, cute)
    d.ellipse([cx - 80, cy - 155, cx - 40, cy - 120], fill=(255, 255, 255))
    d.ellipse([cx - 15, cy - 155, cx + 25, cy - 120], fill=(255, 255, 255))
    d.ellipse([cx - 70, cy - 148, cx - 50, cy - 130], fill=(40, 30, 20))
    d.ellipse([cx - 5, cy - 148, cx + 15, cy - 130], fill=(40, 30, 20))
    d.ellipse([cx - 65, cy - 145, cx - 55, cy - 135], fill=(255, 255, 255))
    d.ellipse([cx, cy - 145, cx + 10, cy - 135], fill=(255, 255, 255))
    # Eyebrows
    d.arc([cx - 85, cy - 168, cx - 35, cy - 145], 180, 360, fill=(140, 95, 55), width=4)
    d.arc([cx - 15, cy - 168, cx + 35, cy - 145], 180, 360, fill=(140, 95, 55), width=4)
    # Nose
    d.ellipse([cx - 20, cy - 110, cx + 5, cy - 90], fill=(50, 40, 35))
    d.ellipse([cx - 15, cy - 107, cx, cy - 94], fill=(80, 65, 55))
    # Mouth
    d.arc([cx - 25, cy - 100, cx, cy - 75], 0, 180, fill=(60, 50, 40), width=3)
    d.arc([cx, cy - 100, cx + 25, cy - 75], 0, 180, fill=(60, 50, 40), width=3)
    # Tongue
    d.ellipse([cx - 7, cy - 88, cx + 7, cy - 72], fill=(240, 100, 100))
    d.ellipse([cx - 5, cy - 86, cx + 5, cy - 76], fill=(255, 120, 120))
    # Tail (wagging)
    d.ellipse([cx + 125, cy - 10, cx + 190, cy + 40], fill=(170, 120, 70))
    # Paws
    d.ellipse([cx - 120, cy + 140, cx - 70, cy + 185], fill=(170, 120, 70))
    d.ellipse([cx - 20, cy + 140, cx + 30, cy + 185], fill=(170, 120, 70))
    _paste_shadow(img, p, (0, 20))
    return img

def draw_podjezd():
    """Ъ → Подъезд (building entrance)"""
    img = _linear_gradient(BIG, [(60, 60, 70), (80, 80, 90), (50, 50, 60)])
    ent = _bg(BIG)
    d = ImageDraw.Draw(ent)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Building wall
    wall_w, wall_h = 360, 400
    x1 = cx - wall_w // 2
    y1 = cy - wall_h // 2
    d.rectangle([x1, y1, x1 + wall_w, y1 + wall_h], fill=(180, 170, 155))
    # Brick pattern
    for row in range(10):
        ry = y1 + row * 40
        offset = 20 if row % 2 == 0 else 0
        for col in range(-1, 10):
            bx = x1 + offset + col * 40
            d.rectangle([bx, ry, bx + 38, ry + 38], fill=(170, 160, 145), outline=(160, 150, 135))
    # Door
    door_w, door_h = 140, 260
    dx1 = cx - door_w // 2
    dy1 = y1 + wall_h - door_h - 20
    d.rectangle([dx1, dy1, dx1 + door_w, dy1 + door_h], fill=(80, 60, 40))
    d.rectangle([dx1 + 5, dy1 + 5, dx1 + door_w - 5, dy1 + door_h - 5], fill=(100, 75, 50))
    # Door panels
    d.rectangle([dx1 + 15, dy1 + 15, dx1 + door_w // 2 - 5, dy1 + door_h // 2 - 5], fill=(85, 65, 45))
    d.rectangle([dx1 + door_w // 2 + 5, dy1 + 15, dx1 + door_w - 15, dy1 + door_h // 2 - 5], fill=(85, 65, 45))
    d.rectangle([dx1 + 15, dy1 + door_h // 2 + 5, dx1 + door_w // 2 - 5, dy1 + door_h - 15], fill=(85, 65, 45))
    d.rectangle([dx1 + door_w // 2 + 5, dy1 + door_h // 2 + 5, dx1 + door_w - 15, dy1 + door_h - 15], fill=(85, 65, 45))
    # Door handle
    d.ellipse([dx1 + door_w - 30, dy1 + door_h // 2 - 8, dx1 + door_w - 18, dy1 + door_h // 2 + 8], fill=(200, 180, 50))
    # Arch over door
    d.ellipse([dx1 - 10, dy1 - 30, dx1 + door_w + 10, dy1 + 30], fill=(180, 170, 155))
    d.ellipse([dx1 - 5, dy1 - 25, dx1 + door_w + 5, dy1 + 25], fill=(200, 190, 175))
    # Steps
    for i in range(3):
        sy = y1 + wall_h - 10 + i * 15
        d.rectangle([cx - 100 + i * 5, sy, cx + 100 - i * 5, sy + 15], fill=(150, 145, 130))
    # Roof/overhang
    d.rectangle([x1 - 20, y1 - 15, x1 + wall_w + 20, y1], fill=(120, 110, 95))
    # House number
    d.rectangle([cx - 25, y1 + 10, cx + 25, y1 + 40], fill=(200, 190, 175))
    d.rectangle([cx - 22, y1 + 13, cx + 22, y1 + 37], fill=(220, 210, 195))
    _paste_shadow(img, ent, (0, 20))
    return img

def draw_syr():
    """Ы → Сыр (cheese)"""
    img = _linear_gradient(BIG, [(60, 60, 40), (80, 80, 50), (50, 50, 30)])
    ch = _bg(BIG)
    d = ImageDraw.Draw(ch)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Cheese wedge (triangle/3D wedge)
    # Front face (triangle)
    d.polygon([
        (cx - 190, cy + 100),
        (cx + 10, cy - 160),
        (cx + 200, cy + 100),
    ], fill=(255, 200, 50))
    d.polygon([
        (cx - 180, cy + 90),
        (cx + 5, cy - 145),
        (cx + 190, cy + 90),
    ], fill=(255, 210, 70))
    # Side face (gives 3D wedge effect)
    d.polygon([
        (cx + 200, cy + 100),
        (cx + 150, cy - 70),
        (cx + 10, cy - 160),
    ], fill=(230, 170, 40))
    d.polygon([
        (cx + 190, cy + 90),
        (cx + 142, cy - 60),
        (cx + 10, cy - 145),
    ], fill=(240, 185, 50))
    # Top face
    d.polygon([
        (cx - 190, cy + 100),
        (cx - 140, cy - 70),
        (cx + 150, cy - 70),
        (cx + 200, cy + 100),
    ], fill=(255, 225, 80))
    d.polygon([
        (cx - 180, cy + 90),
        (cx - 132, cy - 62),
        (cx + 142, cy - 62),
        (cx + 190, cy + 90),
    ], fill=(255, 235, 100))
    # Holes
    hole_color = (230, 180, 60)
    hole_positions = [
        (-100, 0, 20), (-40, -60, 15), (30, -30, 25),
        (100, 20, 18), (-70, 50, 12), (50, 60, 22),
        (-130, -30, 14), (120, -10, 16),
    ]
    for hx, hy, hr in hole_positions:
        d.ellipse([cx + hx - hr, cy + hy - hr, cx + hx + hr, cy + hy + hr], fill=hole_color)
        d.ellipse([cx + hx - hr + 3, cy + hy - hr + 3, cx + hx + hr - 3, cy + hy + hr - 3], fill=(245, 195, 70))
    # Highlight on top
    d.polygon([
        (cx - 120, cy + 40),
        (cx - 80, cy - 30),
        (cx + 60, cy - 30),
        (cx + 100, cy + 40),
    ], fill=(255, 245, 180, 80))
    _paste_shadow(img, ch, (0, 20))
    return img

def draw_los():
    """Ь → Лось (moose)"""
    img = _linear_gradient(BIG, [(50, 60, 50), (70, 90, 70), (40, 50, 40)])
    moose = _bg(BIG)
    d = ImageDraw.Draw(moose)
    cx, cy = BIG // 2, BIG // 2 + 30
    # Body
    d.ellipse([cx - 190, cy - 60, cx + 160, cy + 190], fill=(130, 90, 60))
    # Neck
    d.ellipse([cx - 70, cy - 200, cx + 80, cy - 30], fill=(130, 90, 60))
    # Head
    d.ellipse([cx - 140, cy - 280, cx + 50, cy - 150], fill=(140, 100, 65))
    # Bell/dewlap (hanging skin under chin)
    d.ellipse([cx - 90, cy - 170, cx + 10, cy - 100], fill=(120, 80, 55))
    # Ears
    d.ellipse([cx - 160, cy - 260, cx - 120, cy - 210], fill=(130, 90, 60))
    d.ellipse([cx - 20, cy - 260, cx + 20, cy - 210], fill=(130, 90, 60))
    d.ellipse([cx - 153, cy - 252, cx - 127, cy - 218], fill=(180, 150, 120))
    d.ellipse([cx - 13, cy - 252, cx + 13, cy - 218], fill=(180, 150, 120))
    # Antlers (large)
    antler_color = (160, 140, 120)
    # Left antler
    d.ellipse([cx - 160, cy - 340, cx - 110, cy - 290], fill=antler_color)
    d.ellipse([cx - 190, cy - 330, cx - 140, cy - 280], fill=antler_color)
    d.ellipse([cx - 170, cy - 350, cx - 120, cy - 310], fill=antler_color)
    # Right antler
    d.ellipse([cx - 20, cy - 340, cx + 30, cy - 290], fill=antler_color)
    d.ellipse([cx + 10, cy - 350, cx + 60, cy - 300], fill=antler_color)
    d.ellipse([cx + 30, cy - 330, cx + 80, cy - 280], fill=antler_color)
    # Palms (flat parts of antlers)
    d.ellipse([cx - 220, cy - 340, cx - 110, cy - 260], fill=antler_color, width=3)
    d.ellipse([cx - 20, cy - 340, cx + 90, cy - 260], fill=antler_color, width=3)
    # Eyes
    d.ellipse([cx - 90, cy - 230, cx - 60, cy - 205], fill=(30, 30, 30))
    d.ellipse([cx - 15, cy - 230, cx + 15, cy - 205], fill=(30, 30, 30))
    d.ellipse([cx - 82, cy - 224, cx - 68, cy - 212], fill=(255, 255, 240))
    d.ellipse([cx - 7, cy - 224, cx + 7, cy - 212], fill=(255, 255, 240))
    # Snout
    d.ellipse([cx - 80, cy - 180, cx + 20, cy - 135], fill=(100, 70, 50))
    # Nostrils
    d.ellipse([cx - 40, cy - 165, cx - 25, cy - 155], fill=(50, 40, 35))
    d.ellipse([cx - 10, cy - 165, cx + 5, cy - 155], fill=(50, 40, 35))
    # Legs
    for ox in [-140, -50, 30, 120]:
        d.ellipse([cx + ox, cy + 160, cx + ox + 35, cy + 230], fill=(120, 80, 55))
    # Tail
    d.ellipse([cx + 150, cy - 10, cx + 185, cy + 20], fill=(130, 90, 60))
    _paste_shadow(img, moose, (0, 20))
    return img

def draw_eskimo():
    """Э → Эскимо (ice cream bar)"""
    img = _linear_gradient(BIG, [(80, 60, 80), (110, 80, 110), (70, 50, 70)])
    ice = _bg(BIG)
    d = ImageDraw.Draw(ice)
    cx, cy = BIG // 2, BIG // 2 + 10
    # Stick
    d.rectangle([cx - 30, cy + 130, cx + 30, cy + 220], fill=(200, 170, 120))
    d.rectangle([cx - 25, cy + 135, cx + 25, cy + 215], fill=(220, 190, 140))
    # Ice cream body (oval/choco coating)
    d.ellipse([cx - 120, cy - 120, cx + 120, cy + 130], fill=(120, 60, 40))
    d.ellipse([cx - 115, cy - 115, cx + 115, cy + 125], fill=(140, 75, 50))
    # Inner vanilla filling
    d.ellipse([cx - 95, cy - 95, cx + 95, cy + 100], fill=(250, 240, 220))
    d.ellipse([cx - 90, cy - 90, cx + 90, cy + 95], fill=(255, 250, 235))
    # Chocolate coating (top)
    d.ellipse([cx - 110, cy - 115, cx + 110, cy + 10], fill=(100, 50, 30))
    d.ellipse([cx - 105, cy - 110, cx + 105, cy + 5], fill=(120, 60, 40))
    # Drip details
    d.ellipse([cx - 90, cy + 5, cx - 70, cy + 35], fill=(120, 60, 40))
    d.ellipse([cx + 60, cy + 2, cx + 85, cy + 28], fill=(120, 60, 40))
    d.ellipse([cx - 20, cy + 8, cx + 5, cy + 40], fill=(120, 60, 40))
    # Crunch / sprinkles
    sprinkle_colors = [(50, 150, 200), (220, 50, 80), (255, 200, 50), (100, 200, 80)]
    for i in range(8):
        import random
        sx = cx + random.randint(-100, 100)
        sy = cy + random.randint(-80, 60)
        sc = random.choice(sprinkle_colors)
        d.ellipse([sx - 5, sy - 3, sx + 5, sy + 3], fill=sc)
    # Highlight
    d.ellipse([cx - 70, cy - 90, cx - 20, cy - 40], fill=(255, 255, 255, 60))
    _paste_shadow(img, ice, (0, 15))
    return img

def draw_yula():
    """Ю → Юла (spinning top)"""
    img = _circle_gradient(BIG, 100, 130, 180)
    y = _bg(BIG)
    d = ImageDraw.Draw(y)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Top body (cone/spindle shape)
    # Top handle
    d.rectangle([cx - 15, cy - 270, cx + 15, cy - 180], fill=(200, 180, 100))
    d.ellipse([cx - 20, cy - 285, cx + 20, cy - 260], fill=(220, 200, 120))
    # Upper cone (colored segments)
    d.polygon([
        (cx, cy - 180),
        (cx - 160, cy - 40),
        (cx + 160, cy - 40),
    ], fill=(200, 50, 70))
    # Lower cone
    d.polygon([
        (cx - 160, cy - 40),
        (cx, cy + 100),
        (cx + 160, cy - 40),
    ], fill=(50, 130, 200))
    # Middle stripe
    d.ellipse([cx - 155, cy - 50, cx + 155, cy + 30], fill=(255, 220, 60))
    d.ellipse([cx - 145, cy - 40, cx + 145, cy + 20], fill=(255, 235, 80))
    # Bottom tip
    d.polygon([
        (cx - 30, cy + 100),
        (cx, cy + 160),
        (cx + 30, cy + 100),
    ], fill=(100, 80, 60))
    # Spiral patterns on the cone
    d.arc([cx - 120, cy - 150, cx + 120, cy + 50], 180, 360, fill=(255, 255, 255, 100), width=4)
    d.arc([cx - 100, cy - 120, cx + 100, cy + 30], 0, 180, fill=(255, 255, 255, 100), width=4)
    # Highlight
    d.ellipse([cx - 80, cy - 130, cx - 30, cy - 50], fill=(255, 255, 255, 60))
    _paste_shadow(img, y, (0, 15))
    return img

def draw_yabloko():
    """Я → Яблоко (apple)"""
    img = _linear_gradient(BIG, [(50, 80, 50), (70, 110, 70), (40, 60, 40)])
    ap = _bg(BIG)
    d = ImageDraw.Draw(ap)
    cx, cy = BIG // 2, BIG // 2 + 20
    # Apple body
    d.ellipse([cx - 160, cy - 150, cx + 160, cy + 120], fill=(200, 30, 30))
    d.ellipse([cx - 150, cy - 140, cx + 150, cy + 110], fill=(220, 40, 40))
    # Highlight (shiny apple)
    d.ellipse([cx - 100, cy - 110, cx - 30, cy - 40], fill=(255, 100, 100, 80))
    d.ellipse([cx - 90, cy - 105, cx - 45, cy - 55], fill=(255, 150, 150, 60))
    # Bottom indent
    d.ellipse([cx - 20, cy + 90, cx + 20, cy + 110], fill=(160, 20, 20))
    # Leaf
    d.ellipse([cx + 60, cy - 200, cx + 120, cy - 150], fill=(50, 160, 50))
    d.ellipse([cx + 65, cy - 195, cx + 115, cy - 155], fill=(60, 190, 60))
    # Leaf vein
    d.line([cx + 70, cy - 175, cx + 115, cy - 172], fill=(40, 130, 40), width=2)
    # Stem
    d.rectangle([cx + 10, cy - 200, cx + 25, cy - 155], fill=(80, 60, 30))
    d.rectangle([cx + 13, cy - 195, cx + 22, cy - 160], fill=(100, 75, 40))
    # Small green highlight near stem
    d.ellipse([cx + 30, cy - 160, cx + 60, cy - 130], fill=(60, 190, 60, 60))
    _paste_shadow(img, ap, (0, 20))
    return img


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    generators = [
        ("arbuz.png", draw_arbuz),
        ("banan.png", draw_banan),
        ("volk.png", draw_volk),
        ("grib.png", draw_grib),
        ("dom.png", draw_dom),
        ("enot.png", draw_enot),
        ("yozh.png", draw_yozh),
        ("zhuk.png", draw_zhuk),
        ("zebra.png", draw_zebra),
        ("iriska.png", draw_iriska),
        ("yogurt.png", draw_yogurt),
        ("kot.png", draw_kot),
        ("lisa.png", draw_lisa),
        ("medved.png", draw_medved),
        ("nosorog.png", draw_nosorog),
        ("okno.png", draw_okno),
        ("pingvin.png", draw_pingvin),
        ("ryba.png", draw_ryba),
        ("sova.png", draw_sova),
        ("tigr.png", draw_tigr),
        ("utka.png", draw_utka),
        ("filin.png", draw_filin),
        ("hleb.png", draw_hleb),
        ("cyplenok.png", draw_cyplenok),
        ("cherepaha.png", draw_cherepaha),
        ("shapka.png", draw_shapka),
        ("shenok.png", draw_shenok),
        ("podjezd.png", draw_podjezd),
        ("syr.png", draw_syr),
        ("los.png", draw_los),
        ("eskimo.png", draw_eskimo),
        ("yula.png", draw_yula),
        ("yabloko.png", draw_yabloko),
    ]

    print(f"Generating {len(generators)} images at {BIG}x{BIG} → {FINAL}x{FINAL}...")
    for name, func in generators:
        try:
            _save(func(), name)
        except Exception as e:
            print(f"  FAILED {name}: {e}", file=sys.stderr)
    print("Done!")

if __name__ == "__main__":
    main()
