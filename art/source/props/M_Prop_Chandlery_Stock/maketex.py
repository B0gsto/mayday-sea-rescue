"""M_Prop_Chandlery_Stock textures (system python3 + numpy + Pillow). Procedural, no AI images, invented labels only.

    python3 art/source/props/M_Prop_Chandlery_Stock/maketex.py

Writes assets/textures/M_Prop_Chandlery_Stock/T_ChandleryStock_Atlas_ALB/NOR/RGH/MET.png (2048 px, atlas.py layout):
woods, galvanised / brass, rubber, iron, paper, knits, glass, enamel, five rope and three hank tiles, and painted decals
(tin labels, book spines, flare boxes, chart, box fronts, covers, handheld VHF face, shelf tickets), all with wear.
Also art/source/props/M_Prop_Chandlery_Stock/signal_mask.png (oilskin yellow, signal orange / red, flare boxes) for
check_textures --signal-mask (auto-picked up). The generic material patterns are imported read-only from M_Prop_Chandlery.
"""
import importlib.util
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(G, "tools/blender"))
import atlas  # noqa: E402  (this asset's atlas; cached first so the props modules resolve `atlas` to it)
import rope   # noqa: E402

_spec = importlib.util.spec_from_file_location("props_maketex", os.path.join(G, "art/source/props/M_Prop_Chandlery/maketex.py"))
PM = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(PM)
noise, grid, normal = PM.noise, PM.grid, PM.normal

OUT = os.path.join(G, "assets/textures/M_Prop_Chandlery_Stock")
C = atlas.CELL
FONT_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_K = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
FONT_N = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
FONT_S = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
if not os.path.exists(FONT_S):
    FONT_S = FONT_B


def font(path, size):
    return ImageFont.truetype(path, size)


def pattern(kind, n, seed):
    x, y = grid(n)
    if kind == "knit":
        cols, rows = 16, 22
        fx = (x * cols) % 1.0
        p = (y * rows + np.abs(fx - 0.5) * 1.2) % 1.0
        h = np.sqrt(np.abs(np.sin(np.pi * p))) * (0.75 + 0.25 * np.sqrt(np.abs(np.sin(np.pi * fx))))
        fuzz = noise(n, 40, seed + 9)
        h = 0.25 + 0.6 * h + 0.15 * fuzz
        mul = 0.80 + 0.26 * h + 0.06 * (noise(n, 3, seed) - 0.5)
        return mul, h, 0.04 * (fuzz - 0.5)
    if kind == "glass":
        streak = noise(n, 6, seed, (0.2, 1.0))
        return 0.97 + 0.05 * streak, 0.5 + 0.03 * streak, -0.04 + 0.08 * np.clip(noise(n, 5, seed + 1) - 0.6, 0, 1)
    if kind == "enamel":
        chips = np.clip(noise(n, 14, seed + 3) - 0.83, 0, 1) * 8
        chips = np.clip(chips, 0, 1)
        mul = (0.96 + 0.04 * noise(n, 3, seed))[..., None] * np.ones(3)
        rgb = mul * (1 - chips[..., None]) + chips[..., None] * (np.array((60, 62, 70)) / 206.0)
        return rgb, 0.5 - 0.2 * chips, 0.5 * chips
    if kind == "iron":
        m = noise(n, 4, seed)
        rust = np.clip(noise(n, 7, seed + 4) - 0.62, 0, 1) * 3.5
        rust = np.clip(rust, 0, 1)
        pit = noise(n, 18, seed + 5)
        base = (0.9 + 0.18 * m)[..., None] * np.ones(3)
        rcol = np.array((112, 84, 66)) / 52.0
        rgb = base * (1 - rust[..., None]) + rust[..., None] * rcol * (0.85 + 0.2 * pit[..., None])
        return rgb, 0.5 + 0.12 * (pit - 0.5) + 0.1 * rust, 0.15 * rust
    return PM.pattern(kind, n, seed)


# ------------------------------------------------------------------ wear helpers (decals)
def wear(img, seed, edge=0.22, scratches=24, grime=0.10):
    """Edge darkening, grime blotches and pale scratches on a painted decal (PIL RGB -> PIL RGB)."""
    a = np.asarray(img, float)
    h, w = a.shape[:2]
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum(np.minimum(xx, w - 1 - xx) / max(w, 1), np.minimum(yy, h - 1 - yy) / max(h, 1))
    e = np.clip(1 - d / 0.08, 0, 1) ** 2
    nz = np.asarray(Image.fromarray((noise(256, 6, seed) * 255).astype(np.uint8)).resize((w, h)), float) / 255.0
    a *= (1 - edge * e * (0.6 + 0.4 * nz))[..., None]
    a *= (1 - grime * np.clip(nz - 0.55, 0, 1) * 2.2)[..., None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    dr = ImageDraw.Draw(im)
    for _ in range(scratches):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        L = rng.uniform(4, 22)
        t = rng.uniform(0, math.pi)
        c = tuple(int(v) for v in np.clip(a[int(min(y0, h - 1)), int(min(x0, w - 1))] * 1.18 + 14, 0, 236))
        dr.line([x0, y0, x0 + L * math.cos(t), y0 + L * math.sin(t)], fill=c, width=1)
    return im


def anchor_glyph(d, cx, cy, s, col, width=3):
    d.ellipse([cx - s * 0.12, cy - s * 0.5, cx + s * 0.12, cy - s * 0.26], outline=col, width=width)
    d.line([cx, cy - s * 0.26, cx, cy + s * 0.45], fill=col, width=width)
    d.line([cx - s * 0.28, cy - s * 0.12, cx + s * 0.28, cy - s * 0.12], fill=col, width=width)
    d.arc([cx - s * 0.42, cy - s * 0.05, cx + s * 0.42, cy + s * 0.5], 20, 160, fill=col, width=width)


def draw_tins(w, hgt):
    img = Image.new("RGB", (w, hgt), (200, 190, 170))
    tw, th = w // 4, hgt // 2
    for i, (brand, prod, line, size, band, ground) in enumerate(atlas.TIN_NAMES):
        c, r = i % 4, i // 4
        x0, y0 = c * tw, r * th
        lab = Image.new("RGB", (tw, th), ground)
        d = ImageDraw.Draw(lab)
        d.rectangle([0, 0, tw, 34], fill=band)
        d.rectangle([0, th - 30, tw, th], fill=band)
        d.line([0, 40, tw, 40], fill=band, width=3)
        d.line([0, th - 36, tw, th - 36], fill=band, width=3)
        d.text((tw * 0.30, 17), brand, fill=ground, font=font(FONT_K, 22), anchor="mm")
        d.text((tw * 0.78, 17), size, fill=ground, font=font(FONT_B, 20), anchor="mm")
        d.text((tw * 0.30, 112), prod, fill=(40, 38, 36), font=font(FONT_K, 34 if len(prod) < 12 else 28), anchor="mm")
        d.text((tw * 0.30, 150), line, fill=(64, 60, 56), font=font(FONT_N, 22), anchor="mm")
        swatch = band if i >= 3 else (150, 112, 70)
        d.rounded_rectangle([tw * 0.62, 70, tw * 0.94, 176], 8, fill=swatch, outline=(40, 38, 36), width=2)
        anchor_glyph(d, tw * 0.78, 123, 80, (214, 206, 186), 4)
        d.text((tw * 0.30, 190), "Read the label before use  Keep away from drains", fill=(80, 76, 70), font=font(FONT_N, 14), anchor="mm")
        d.text((tw * 0.78, th - 15), "BATCH %04d" % (1207 + 37 * i), fill=ground, font=font(FONT_N, 14), anchor="mm")
        d.text((tw * 0.30, th - 15), "Made in Port Haven", fill=ground, font=font(FONT_N, 15), anchor="mm")
        lab = wear(lab, 40 + i, scratches=40)
        a = np.asarray(lab, float)
        # drips running down from the lid (varnish / paint)
        rng = np.random.default_rng(60 + i)
        dc = np.array(band) * 0.8 if i >= 3 else np.array((126, 88, 50))
        for _ in range(3):
            xc, L, wd = int(rng.uniform(10, tw - 10)), int(rng.uniform(20, 70)), int(rng.uniform(3, 6))
            a[0:L, xc:xc + wd] = a[0:L, xc:xc + wd] * 0.35 + dc * 0.65
        img.paste(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), (x0, y0))
    return img


def draw_spines(w, hgt):
    img = Image.new("RGB", (w, hgt), (100, 90, 80))
    sw = w // atlas.N_SPINES
    for i, (title, rgb) in enumerate(atlas.SPINES):
        sp = Image.new("RGB", (hgt, sw), rgb)    # drawn horizontally, rotated into the spine
        d = ImageDraw.Draw(sp)
        gold = (196, 170, 112)
        for xx in (10, 16, hgt - 18, hgt - 12):
            d.line([xx, 4, xx, sw - 5], fill=gold, width=2)
        size = 22 if len(title) < 15 else 18
        d.text((hgt * 0.5, sw * 0.5), title, fill=gold if i % 3 else (222, 214, 196), font=font(FONT_N, size), anchor="mm")
        d.text((hgt - 32, sw * 0.5), "PH", fill=gold, font=font(FONT_B, 13), anchor="mm")
        sp = wear(sp, 80 + i, edge=0.3, scratches=10, grime=0.14).rotate(90, expand=True)
        img.paste(sp, (i * sw, 0))
    return img


def draw_flares(w, hgt):
    img = Image.new("RGB", (w, hgt), (186, 52, 44))
    bw = w // 2
    for i, (bg, t1, t2, t3) in enumerate((((180, 54, 44), "DISTRESS", "RED HAND FLARES", "PACK OF 3  SOLAS"),
                                           ((214, 98, 42), "ORANGE", "SMOKE SIGNAL", "BUOYANT  3 MIN"))):
        f = Image.new("RGB", (bw, hgt), bg)
        d = ImageDraw.Draw(f)
        d.rectangle([0, 0, bw, 44], fill=(234, 224, 200))
        d.text((bw / 2, 22), "BRIGHTSTAR", fill=(40, 36, 34), font=font(FONT_K, 26), anchor="mm")
        d.text((bw / 2, 84), t1, fill=(240, 232, 214), font=font(FONT_K, 34), anchor="mm")
        d.text((bw / 2, 122), t2, fill=(240, 232, 214), font=font(FONT_B, 22), anchor="mm")
        for k in range(6):
            d.polygon([(bw / 2, 150 + 0), (bw / 2 - 30 + k * 12, 196), (bw / 2 - 24 + k * 12, 196)], fill=(236, 214, 170))
        d.rectangle([0, hgt - 46, bw, hgt], fill=(40, 38, 36))
        d.text((bw / 2, hgt - 23), t3, fill=(232, 220, 196), font=font(FONT_N, 22), anchor="mm")
        d.text((bw / 2, 214), "EXPIRES 03 / 2029", fill=(240, 232, 214), font=font(FONT_N, 16), anchor="mm")
        img.paste(wear(f, 90 + i, scratches=20), (i * bw, 0))
    return img


def draw_chart(w, hgt):
    rng = np.random.default_rng(5)
    sea = np.array((194, 204, 202), float)
    land = np.array((214, 198, 160), float)
    x, y = np.meshgrid(np.arange(w) / w, np.arange(hgt) / hgt)
    coast = 0.30 + 0.10 * np.sin(x * 9.0) + 0.06 * np.sin(x * 23 + 1.2)
    depth = y - coast
    a = np.where((depth < 0)[..., None], land, sea * (1 - 0.06 * np.clip(depth, 0, 1))[..., None])
    img = Image.fromarray(a.astype(np.uint8))
    d = ImageDraw.Draw(img)
    for k, off in enumerate((0.04, 0.09, 0.16, 0.26)):
        pts = [(i, (0.30 + 0.10 * math.sin(i / w * 9.0) + 0.06 * math.sin(i / w * 23 + 1.2) + off) * hgt) for i in range(0, w, 8)]
        d.line(pts, fill=(120, 140, 150), width=1)
    pts = [(i, (0.30 + 0.10 * math.sin(i / w * 9.0) + 0.06 * math.sin(i / w * 23 + 1.2)) * hgt) for i in range(0, w, 4)]
    d.line(pts, fill=(70, 66, 58), width=2)
    for _ in range(70):
        sx, sy = rng.uniform(10, w - 10), rng.uniform(0.45, 0.97) * hgt
        d.text((sx, sy), str(int(rng.uniform(2, 48))), fill=(70, 80, 92), font=font(FONT_N, 11), anchor="mm")
    cx, cy, R = w * 0.78, hgt * 0.70, 46
    d.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(130, 70, 80), width=2)
    d.ellipse([cx - R * 0.7, cy - R * 0.7, cx + R * 0.7, cy + R * 0.7], outline=(130, 70, 80), width=1)
    for k in range(16):
        t = k * math.pi / 8
        r0 = R * (0.15 if k % 2 else 0.0)
        d.line([cx + r0 * math.cos(t), cy + r0 * math.sin(t), cx + R * math.cos(t), cy + R * math.sin(t)], fill=(130, 70, 80), width=1)
    d.polygon([(cx, cy - R - 8), (cx - 5, cy - R + 4), (cx + 5, cy - R + 4)], fill=(130, 70, 80))
    d.text((w * 0.25, hgt * 0.10), "PORT HAVEN TO ST CARRA HEAD", fill=(60, 56, 50), font=font(FONT_S, 18), anchor="mm")
    d.text((w * 0.25, hgt * 0.17), "Soundings in metres  Scale 1:25 000", fill=(80, 74, 66), font=font(FONT_N, 13), anchor="mm")
    d.rectangle([2, 2, w - 3, hgt - 3], outline=(60, 56, 50), width=2)
    for k in range(1, 4):
        d.line([k * w / 4, 0, k * w / 4, hgt], fill=(176, 176, 166), width=1)    # fold creases
    d.line([0, hgt / 2, w, hgt / 2], fill=(176, 176, 166), width=1)
    d.ellipse([w * 0.12, hgt * 0.58, w * 0.12 + 50, hgt * 0.58 + 50], outline=(170, 150, 120), width=3)   # mug ring
    return wear(img, 7, edge=0.12, scratches=6, grime=0.12)


def draw_boxes(w, hgt):
    img = Image.new("RGB", (w, hgt), (178, 150, 112))
    bw = w // atlas.N_BOXES
    for i, t in enumerate(atlas.BOXES):
        b = Image.new("RGB", (bw, hgt), (178 - 6 * (i % 2), 150 - 4 * (i % 3), 112))
        d = ImageDraw.Draw(b)
        k = noise(256, 30, 120 + i)
        d.rectangle([22, 60, bw - 22, 196], fill=(226, 220, 204), outline=(60, 56, 50), width=2)
        d.text((bw / 2, 82), "PORT HAVEN CHANDLERY", fill=(60, 56, 50), font=font(FONT_N, 15), anchor="mm")
        words = t.split("  ")
        d.text((bw / 2, 124), words[0], fill=(40, 38, 36), font=font(FONT_K, 22 if len(words[0]) < 11 else 17), anchor="mm")
        if len(words) > 1:
            d.text((bw / 2, 158), words[1], fill=(40, 38, 36), font=font(FONT_B, 22), anchor="mm")
        d.text((bw / 2, 184), "QTY 25", fill=(90, 84, 76), font=font(FONT_N, 14), anchor="mm")
        d.rectangle([0, 0, bw, 14], fill=(150, 126, 92))
        d.rectangle([0, hgt - 14, bw, hgt], fill=(150, 126, 92))
        d.text((bw / 2, 34), "THIS WAY UP", fill=(80, 64, 50), font=font(FONT_N, 14), anchor="mm")
        a = np.asarray(b, float) * (0.94 + 0.08 * np.asarray(Image.fromarray((k * 255).astype(np.uint8)).resize((bw, hgt)), float)[..., None] / 255)
        img.paste(wear(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), 130 + i, edge=0.3, scratches=30), (i * bw, 0))
    return img


def draw_covers(w, hgt):
    img = Image.new("RGB", (w, hgt), (60, 70, 90))
    bw = w // 2
    b = Image.new("RGB", (bw, hgt), (64, 78, 98))
    d = ImageDraw.Draw(b)
    d.rectangle([20, 70, bw - 20, 150], fill=(214, 206, 186))
    d.text((bw / 2, 96), "RECEIPTS", fill=(40, 38, 36), font=font(FONT_K, 26), anchor="mm")
    d.text((bw / 2, 128), "Duplicate  No. 0417", fill=(60, 56, 50), font=font(FONT_N, 16), anchor="mm")
    d.text((bw / 2, 220), "PORT HAVEN CHANDLERY", fill=(190, 184, 164), font=font(FONT_N, 15), anchor="mm")
    img.paste(wear(b, 150, edge=0.35, scratches=30), (0, 0))
    b = Image.new("RGB", (bw, hgt), (60, 74, 98))
    d = ImageDraw.Draw(b)
    d.rectangle([12, 12, bw - 12, hgt - 12], outline=(196, 170, 112), width=3)
    d.text((bw / 2, 52), "WEST COUNTRY", fill=(214, 200, 160), font=font(FONT_S, 22), anchor="mm")
    d.text((bw / 2, 82), "PILOT", fill=(214, 200, 160), font=font(FONT_S, 34), anchor="mm")
    d.rectangle([40, 112, bw - 40, 200], fill=(180, 186, 180))
    d.line([(40, 170), (90, 150), (130, 162), (170, 140), (bw - 40, 150)], fill=(90, 84, 70), width=3)
    anchor_glyph(d, bw / 2, 226, 36, (196, 170, 112), 2)
    img.paste(wear(b, 151, edge=0.3, scratches=24), (bw, 0))
    return img


def draw_vhf(w, hgt):
    img = Image.new("RGB", (w, hgt), (46, 48, 50))
    d = ImageDraw.Draw(img)
    x0, x1 = w * 0.25, w * 0.75        # the face is mapped onto the middle half (aspect 1 : 2)
    d.rounded_rectangle([x0 + 4, 8, x1 - 4, hgt - 8], 10, fill=(54, 56, 58))
    for k in range(7):
        d.line([x0 + 18, 22 + k * 7, x1 - 18, 22 + k * 7], fill=(30, 30, 32), width=3)
    d.rectangle([x0 + 14, 82, x1 - 14, 128], fill=(150, 160, 146), outline=(30, 30, 32), width=2)
    d.text(((x0 + x1) / 2, 105), "16", fill=(40, 46, 40), font=font(FONT_K, 30), anchor="mm")
    d.text((x0 + 22, 90), "CH", fill=(50, 56, 50), font=font(FONT_N, 10), anchor="mm")
    for r in range(4):
        for c in range(3):
            cx, cy = x0 + 26 + c * 38, 148 + r * 24
            d.rounded_rectangle([cx - 13, cy - 8, cx + 13, cy + 8], 4, fill=(70, 72, 76))
            d.text((cx, cy), "123456789*0#"[r * 3 + c], fill=(200, 200, 196), font=font(FONT_N, 11), anchor="mm")
    d.rounded_rectangle([x0 + 14, 238, x0 + 54, 250], 4, fill=(150, 64, 54))
    d.text((x0 + 34, 244), "DSC", fill=(220, 210, 200), font=font(FONT_N, 9), anchor="mm")
    return wear(img, 160, edge=0.15, scratches=30, grime=0.05)


def draw_tags(w, hgt):
    img = Image.new("RGB", (w, hgt), (214, 204, 178))
    d = ImageDraw.Draw(img)
    th = hgt // atlas.N_TAGS
    for i, (a, p) in enumerate((("VARNISH 750", "28 C"), ("ROPE / M", "6 C"), ("PILOTS", "45 C"), ("LAMPS", "60 C"))):
        y0 = i * th
        d.rectangle([0, y0, w, y0 + th - 1], fill=(216 - 4 * i, 206, 180))
        d.rectangle([0, y0, 18, y0 + th - 1], fill=((66, 82, 110), (128, 72, 64), (66, 96, 76), (96, 90, 84))[i])
        d.text((96, y0 + th / 2), a, fill=(48, 46, 44), font=font(FONT_N, 20), anchor="mm")
        d.text((206, y0 + th / 2), p, fill=(58, 44, 40), font=font(FONT_K, 22), anchor="mm")
    return wear(img, 170, edge=0.2, scratches=8)


DRAW = {"tins": draw_tins, "spines": draw_spines, "flares": draw_flares, "chart": draw_chart, "boxes": draw_boxes,
        "covers": draw_covers, "vhf": draw_vhf, "tags": draw_tags}


def rope_tile(pat, hank, seed, rgb, rough):
    T = C
    if hank:
        k = 4
        mini = rope.trim_height(pat, T // k, seed=seed)
        u = (np.arange(T) + 0.5)[None, :] / T
        ridge = np.sqrt(np.abs(np.sin(np.pi * ((u * k) % 1.0)))) + 0 * u.T
        h = ridge * (0.55 + 0.45 * np.tile(mini, (k, k)))
    else:
        h = rope.trim_height(pat, T, seed=seed)
    blotch = noise(T, 4, 50 + seed)
    shade = (0.45 + 0.55 * h) * (0.9 + 0.2 * blotch)
    shade = np.maximum(shade, 38.0 / min(rgb))
    a = np.clip(np.array(rgb, float)[None, None, :] * shade[..., None], 36, 234)
    return a, normal(h, 3.0, True), np.clip(rough + 0.12 * (1 - h) + 0.05 * (blotch - 0.5), 0, 1)


def clamp_sat(a, smax=0.42):
    """Pull HSV saturation above smax back to smax (keeps hue and value): painted labels stay inside the palette ceiling."""
    mx = a.max(-1, keepdims=True)
    mn = a.min(-1, keepdims=True)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    k = np.where(sat > smax, smax / np.maximum(sat, 1e-6), 1.0)
    return mx - (mx - a) * k


def main():
    os.makedirs(OUT, exist_ok=True)
    N = atlas.ATLAS
    alb = np.zeros((N, N, 3)) + (110, 108, 104)
    nor = np.zeros((N, N, 3)) + (0.5, 0.5, 1.0)
    rgh = np.full((N, N), 0.8)
    met = np.zeros((N, N))
    sig = np.zeros((N, N))
    for i, (key, (cx, cy, cw, ch, kind, scale, rgb, rough, metal, pat, signal)) in enumerate(atlas.R.items()):
        w, h = cw * C, ch * C
        x0, y0 = cx * C, N - (cy + ch) * C           # image rows run down, V up
        if kind == "tile":
            mul, hh, rg = pattern(pat, C, 100 + 17 * i)
            col = np.array(rgb, float)
            a = col * (mul if mul.ndim == 3 else mul[..., None])
            strength = {"knit": 5, "webbing": 4, "tread": 5, "grain": 3, "glass": 1}.get(pat, 4.0)
            nn = normal(hh, strength, False, fade=True)
        elif kind in ("rope", "hank"):
            a, nn, rg = rope_tile(pat, kind == "hank", 11 + i, rgb, rough)
            rg = rg - rough
        else:
            im = DRAW[pat](w, h)
            a = np.asarray(im, float)
            lum = a.mean(-1) / 255.0
            hh = 0.5 + 0.25 * (lum - lum.mean())
            nn = normal(hh, 2.5, False, fade=True)
            rg = 0.06 * (0.5 - lum)
        if not signal:
            a = clamp_sat(a)
        lo, hi = (188, 246) if metal else (36, 234)
        alb[y0:y0 + h, x0:x0 + w] = np.clip(a, lo, hi)
        nor[y0:y0 + h, x0:x0 + w] = nn
        rgh[y0:y0 + h, x0:x0 + w] = np.clip(rough + rg, 0.05, 1.0)
        met[y0:y0 + h, x0:x0 + w] = 1.0 if metal else 0.0
        if signal:
            sig[y0:y0 + h, x0:x0 + w] = 1.0
    stem = os.path.join(OUT, "T_ChandleryStock_Atlas_")
    Image.fromarray(alb.astype(np.uint8)).save(stem + "ALB.png")
    Image.fromarray(np.round(nor * 255).astype(np.uint8)).save(stem + "NOR.png")
    Image.fromarray(np.round(rgh * 255).astype(np.uint8)).save(stem + "RGH.png")
    Image.fromarray(np.round(met * 255).astype(np.uint8)).save(stem + "MET.png")
    Image.fromarray(np.round(sig * 255).astype(np.uint8)).save(os.path.join(HERE, "signal_mask.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
