"""M_Prop_Chandlery textures (system python3 + numpy + Pillow, no heavy slot). Procedural, no AI images.

    python3 art/source/props/M_Prop_Chandlery/maketex.py

Writes assets/textures/M_Prop_Chandlery/:
  T_ChandleryProps_Atlas_ALB/NOR/RGH/MET.png  2048 px shared prop atlas (atlas.py layout): fabrics, rubber, plastics,
      galvanised / stainless / brass / chrome, pine, paint, wicker, tartan, paper, and painted decals (product tags,
      VHF radio face, horn board, livery swatch board)
  T_ChandleryProps_Rope_*                     1024 px rope trim: 4 single ropes (three-strand, braid) + 4 hank bundles
and art/source/props/M_Prop_Chandlery/signal_mask.png (lifejacket orange, hi-vis yellow, buoy orange, and the orange /
yellow livery swatches) for check_textures --signal-mask. Noise / bump frequencies stay <= 10 cycles per stud.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(G, "tools/blender"))
import atlas  # noqa: E402
import rope   # noqa: E402

OUT = os.path.join(G, "assets/textures/M_Prop_Chandlery")
C = atlas.CELL
FONT_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_K = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
FONT_N = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"


def noise(n, cycles, seed, aniso=(1.0, 1.0)):
    """Periodic band-limited noise 0..1 on an n x n tile, energy below `cycles` per tile."""
    r = np.random.default_rng(seed)
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[0]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[1]
    k = np.sqrt(fx ** 2 + fy ** 2)
    spec = np.fft.fft2(r.standard_normal((n, n))) * np.exp(-(k / cycles) ** 2)
    spec[0, 0] = 0
    v = np.real(np.fft.ifft2(spec))
    return (v - v.min()) / (v.max() - v.min() + 1e-9)


def grid(n):
    x = (np.arange(n) + 0.5)[None, :] / n
    y = (np.arange(n) + 0.5)[:, None] / n
    return x + 0 * y, y + 0 * x


def pattern(kind, n, seed):
    """-> (albedo multiplier (n, n) or rgb override (n, n, 3), height (n, n), roughness offset (n, n))."""
    x, y = grid(n)
    m = noise(n, 4, seed)
    f = noise(n, 10, seed + 1)
    grime = noise(n, 3, seed + 2)
    mul = 0.94 + 0.10 * m - 0.05 * np.clip(grime - 0.6, 0, 1) * 2.5
    h = 0.5 + 0.0 * x
    rg = 0.05 * (f - 0.5)
    if kind == "nylon":
        rip = np.maximum(np.abs(np.cos(np.pi * 8 * x)), np.abs(np.cos(np.pi * 8 * y))) ** 24
        h = 0.5 + 0.18 * (f - 0.5) + 0.06 * rip
        mul = mul - 0.03 * rip
    elif kind == "pvc":
        h = 0.5 + 0.08 * (f - 0.5)
        scuff = np.clip(noise(n, 8, seed + 3, (1, 0.3)) - 0.72, 0, 1) * 3
        mul = mul - 0.08 * scuff
        rg = rg + 0.18 * scuff
    elif kind == "foam":
        pores = noise(n, 12, seed + 4)
        h = 0.3 + 0.5 * pores
        mul = mul * (0.95 + 0.06 * pores)
        rg = rg + 0.06 * (pores - 0.5)
    elif kind == "wax":
        crease = np.clip(noise(n, 9, seed + 5, (1, 0.35)) - 0.55, 0, 1) * 2.2
        h = 0.5 + 0.25 * crease + 0.1 * (f - 0.5)
        mul = mul * (1.0 + 0.10 * crease)
        rg = rg + 0.25 * crease - 0.08 * m
    elif kind in ("rubber", "plastic", "smooth"):
        amp = {"rubber": 0.12, "plastic": 0.06, "smooth": 0.03}[kind]
        h = 0.5 + amp * (f - 0.5)
        if kind == "smooth":
            mul = 0.98 + 0.03 * m
    elif kind == "webbing":
        rib = 0.5 + 0.5 * np.cos(2 * np.pi * 8 * y)
        h = 0.35 + 0.45 * rib + 0.1 * f
        mul = mul * (0.92 + 0.1 * rib)
    elif kind == "tape":
        cx = np.floor(x * 8) + np.floor(y * 8)
        cellv = noise(n, 6, seed + 6)
        mul = 0.96 + 0.05 * (cx % 2) + 0.03 * cellv
        h = 0.5 + 0.05 * (cx % 2)
        rg = rg + 0.05 * (cx % 2)
    elif kind == "linen":
        h = 0.5 + 0.15 * (noise(n, 10, seed + 7, (1, 0.5)) - 0.5) + 0.1 * (noise(n, 10, seed + 8, (0.5, 1)) - 0.5)
        mul = mul * (0.97 + 0.05 * f)
    elif kind == "galv":
        pts = np.random.default_rng(seed).random((60, 2))
        d = np.full((n, n), 9.0)
        idx = np.zeros((n, n), int)
        for i, (px, py) in enumerate(pts):
            dx = np.abs(x - px)
            dx = np.minimum(dx, 1 - dx)
            dy = np.abs(y - py)
            dy = np.minimum(dy, 1 - dy)
            dd = dx * dx + dy * dy
            sel = dd < d
            d[sel] = dd[sel]
            idx[sel] = i
        val = np.random.default_rng(seed + 9).random(60)[idx]
        mul = 0.96 + 0.06 * val + 0.02 * m
        h = 0.5 + 0.05 * val
        rg = 0.12 * (val - 0.5) + 0.08 * (grime - 0.5)
    elif kind == "brushed":
        br = noise(n, 12, seed + 10, (1.0, 0.08))
        mul = 0.97 + 0.05 * br
        h = 0.5 + 0.06 * br
        rg = 0.10 * (br - 0.5)
    elif kind == "brass":
        tarn = np.clip(noise(n, 4, seed + 11) - 0.5, 0, 1) * 2
        mul = 1.0 - 0.06 * tarn + 0.02 * f
        h = 0.5 + 0.04 * f
        rg = 0.2 * tarn
    elif kind == "grain":
        warp = noise(n, 3, seed + 12)
        rings = 0.5 + 0.5 * np.sin(2 * np.pi * (8 * y + 1.2 * warp + 0.15 * np.sin(2 * np.pi * x)))
        streak = noise(n, 10, seed + 13, (1.0, 0.1))
        mul = (0.86 + 0.16 * rings ** 3) * (0.95 + 0.08 * streak)
        h = 0.5 + 0.12 * rings + 0.08 * streak
        rg = 0.06 * rings
    elif kind == "paint":
        brush = noise(n, 10, seed + 14, (1.0, 0.15))
        chip = np.clip((noise(n, 9, seed + 15) - 0.82) * 12, 0, 1)
        mul = (0.95 + 0.07 * brush) * (1 - 0.15 * chip)
        h = 0.5 + 0.06 * brush - 0.25 * chip
        rg = 0.06 * (brush - 0.5) + 0.25 * chip
        mul = np.stack([mul] * 3, -1)
        wood = np.array([164, 130, 96]) / np.array([52, 76, 70])
        mul = mul * (1 - chip[..., None]) + chip[..., None] * wood[None, None, :] * 0.85
    elif kind == "wicker":
        k = 4
        cx, cy = np.floor(x * k), np.floor(y * k)
        horiz = (cx + cy) % 2 == 0
        su, sv = (y * k * 3) % 1.0, (x * k * 3) % 1.0
        strand = np.where(horiz, np.sin(np.pi * su), np.sin(np.pi * sv)) ** 0.6
        h = 0.2 + 0.7 * strand
        mul = (0.72 + 0.32 * strand) * (0.95 + 0.08 * f)
        rg = 0.08 * (1 - strand)
    elif kind == "tartan":
        def bands(t):
            t = (t * 2) % 1.0
            g = (t < 0.30).astype(float)
            nv = ((t > 0.42) & (t < 0.50)).astype(float)
            cr = ((t > 0.70) & (t < 0.735)).astype(float)
            return g, nv, cr
        gx, nx, crx = bands(x)
        gy, ny, cry = bands(y)
        base = np.array([118, 78, 70], float)
        green = np.array([62, 82, 68], float)
        navy = np.array([52, 58, 78], float)
        cream = np.array([176, 166, 146], float)
        col = np.zeros((n, n, 3)) + base
        for a, b, c in ((gx, gy, green), (nx, ny, navy), (crx, cry, cream)):
            w = (0.5 * a + 0.5 * b)[..., None]
            col = col * (1 - w) + c * w
        twill = 0.5 + 0.5 * np.cos(2 * np.pi * 10 * (x + y))
        mul = col / base * (0.95 + 0.06 * twill[..., None]) * (0.96 + 0.06 * m[..., None])
        h = 0.5 + 0.12 * twill + 0.1 * f
    elif kind == "zip":
        teeth = (np.sin(2 * np.pi * 8 * y) > 0).astype(float) * (np.abs(x - 0.5) < 0.22)
        h = 0.3 + 0.5 * teeth
        mul = 0.9 + 0.15 * teeth
    elif kind == "tread":
        chev = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (6 * y + 2 * np.abs(x - 0.5))))
        h = 0.3 + 0.5 * chev
        mul = 0.9 + 0.1 * chev
    elif kind == "paper":
        h = 0.5 + 0.08 * f
        mul = 0.96 + 0.06 * m
    return mul, h, rg


def edge_fade(h, px=5):
    """Fade the height to its mean over the last `px` pixels of a region, so normals stay continuous across cells."""
    hh, ww = h.shape
    ry = np.minimum(np.arange(hh), np.arange(hh)[::-1])[:, None]
    rx = np.minimum(np.arange(ww), np.arange(ww)[::-1])[None, :]
    w = np.clip(np.minimum(rx, ry) / float(px), 0, 1)
    w = w * w * (3 - 2 * w)
    return h.mean() + (h - h.mean()) * w


def normal(h, strength, wrap, fade=False):
    if fade:
        h, wrap = edge_fade(h), False
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5
    else:
        gy, gx = np.gradient(h)
        dx, dy = gx, -gy
    nrm = np.stack([-dx * strength, -dy * strength, np.ones_like(h)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    return nrm * 0.5 + 0.5


def font(path, size):
    return ImageFont.truetype(path, size)


def draw_tags(w, hgt):
    img = Image.new("RGB", (w, hgt), (214, 204, 178))
    d = ImageDraw.Draw(img)
    items = [("LIFEJACKET", "150N AUTO", "LVL 2", "450 C"), ("BUOYANCY", "AID 50N", "LVL 1", "180 C"),
             ("3-STRAND", "12 MM / M", "LVL 1", "12 C"), ("BRAID", "10 MM / M", "LVL 2", "18 C"),
             ("SHACKLE", "BOW 8 MM", "S/S", "35 C"), ("JACKET", "OFFSHORE", "LVL 3", "900 C"),
             ("DOG COAT", "WAXED", "SIZE M", "220 C"), ("FENDER", "F2 NAVY", "LVL 1", "95 C")]
    bands = [(66, 82, 110), (128, 72, 64), (66, 96, 76), (96, 90, 84)]
    tw = w // atlas.N_TAGS
    for i, (a, b, c, p) in enumerate(items):
        x0 = i * tw
        d.rectangle([x0, 0, x0 + tw - 1, hgt - 1], fill=(214 - 3 * (i % 3), 204 - 2 * (i % 2), 178))
        d.rectangle([x0 + 6, 52, x0 + tw - 7, 86], fill=bands[i % 4])
        d.text((x0 + tw // 2, 69), "PORT HAVEN", fill=(206, 198, 176), font=font(FONT_N, 15), anchor="mm")
        d.ellipse([x0 + tw // 2 - 12, 12, x0 + tw // 2 + 12, 36], fill=(186, 176, 150))
        d.ellipse([x0 + tw // 2 - 6, 18, x0 + tw // 2 + 6, 30], fill=(60, 56, 50))
        for j, (t, s) in enumerate(((a, 19), (b, 16), (c, 16))):
            d.text((x0 + tw // 2, 108 + 26 * j), t, fill=(48, 46, 44), font=font(FONT_N, s), anchor="mm")
        d.line([x0 + 14, 186, x0 + tw - 15, 186], fill=(120, 112, 98), width=2)
        d.text((x0 + tw // 2, 218), p, fill=(58, 44, 40), font=font(FONT_K, 26), anchor="mm")
    return img


def kraft(w, hgt, seed):
    mul, _, _ = pattern("paper", 256, seed)
    base = np.array(atlas.R["Kraft"][6], float)
    fib = noise(256, 8, seed + 5, (1.0, 0.25))
    tile = np.clip(base * (mul * (0.94 + 0.1 * fib))[..., None], 0, 255)
    return np.tile(tile, (hgt // 256 + 1, w // 256 + 1, 1))[:hgt, :w]


def pict(d, kind, cx, cy, s, ink, wd):
    """Line pictogram of a bin item, centred at (cx, cy), half-size s px."""
    if kind in ("bow", "dee"):
        if kind == "bow":
            d.arc([cx - s, cy - s, cx + s, cy + s * 0.9], 180, 360, fill=ink, width=wd)
            d.arc([cx - s * 0.9, cy - s * 0.6, cx + s * 0.9, cy + s * 0.6], 160, 200, fill=ink, width=wd)
            d.arc([cx - s * 0.9, cy - s * 0.6, cx + s * 0.9, cy + s * 0.6], 340, 20, fill=ink, width=wd)
        else:
            d.arc([cx - s * 0.7, cy - s, cx + s * 0.7, cy + s * 0.4], 180, 360, fill=ink, width=wd)
            for sx in (-1, 1):
                d.line([cx + sx * s * 0.7, cy - s * 0.3, cx + sx * s * 0.7, cy + s * 0.6], fill=ink, width=wd)
        d.line([cx - s * 1.05, cy + s * 0.65, cx + s * 1.05, cy + s * 0.65], fill=ink, width=wd + 2)
    elif kind == "snap":
        d.ellipse([cx - s * 0.4, cy - s * 1.1, cx + s * 0.4, cy - s * 0.45], outline=ink, width=wd)
        d.polygon([(cx - s * 0.3, cy - s * 0.4), (cx + s * 0.3, cy - s * 0.4), (cx + s * 0.45, cy + s * 0.3),
                   (cx - s * 0.45, cy + s * 0.3)], fill=ink)
        d.arc([cx - s * 0.6, cy - s * 0.1, cx + s * 0.6, cy + s * 1.1], 0, 200, fill=ink, width=wd)
    else:
        for sy in (-1, 1):
            d.ellipse([cx - s * 0.38, cy + sy * s * 0.62 - s * 0.38, cx + s * 0.38, cy + sy * s * 0.62 + s * 0.38],
                      outline=ink, width=wd)
        d.rectangle([cx - s * 0.2, cy - s * 0.28, cx + s * 0.2, cy + s * 0.28], fill=ink)


def draw_bin_labels(w, hgt):
    img = Image.new("RGB", (w, hgt), (222, 216, 202))
    d = ImageDraw.Draw(img)
    bands = [(66, 82, 110), (96, 90, 84), (66, 96, 76), (128, 72, 64)]
    lw, lh = w // 4, hgt // 2
    ink = (40, 40, 42)
    for i, (a, b, kind) in enumerate(atlas.BIN_LABELS):
        x0, y0 = (i % 4) * lw, (i // 4) * lh
        d.rectangle([x0, y0, x0 + lw - 1, y0 + lh - 1], fill=(56, 58, 62))          # black label holder rim
        d.rectangle([x0 + 7, y0 + 7, x0 + lw - 8, y0 + lh - 8], fill=(226 - 3 * (i % 3), 220 - 2 * (i % 2), 204))
        d.rectangle([x0 + 7, y0 + 7, x0 + lw - 8, y0 + 30], fill=bands[i % 4])
        d.text((x0 + lw // 2, y0 + 19), "PORT HAVEN CHANDLERY", fill=(214, 206, 184), font=font(FONT_N, 14), anchor="mm")
        pict(d, kind, x0 + 44, y0 + 78, 22, ink, 5)
        d.text((x0 + 160, y0 + 58), a, fill=ink, font=font(FONT_N, 24), anchor="mm")
        d.text((x0 + 160, y0 + 86), b, fill=(70, 66, 60), font=font(FONT_N, 20), anchor="mm")
        d.text((x0 + 160, y0 + 108), "%d.%02d EACH" % (2 + 3 * i % 9, (15 * i) % 100), fill=(110, 52, 44), font=font(FONT_B, 15),
               anchor="mm")
    return img


def draw_fender_box(w, hgt):
    img = Image.fromarray(kraft(w, hgt, 71).astype(np.uint8))
    d = ImageDraw.Draw(img)
    ink, navy = (54, 46, 40), (56, 66, 92)
    d.rectangle([10, 10, w - 11, hgt - 11], outline=ink, width=4)
    d.rectangle([w - 182, 10, w - 11, hgt - 11], fill=(214, 206, 186))                  # white end panel
    d.text((w - 96, 54), "F2", fill=navy, font=font(FONT_K, 60), anchor="mm")
    d.text((w - 96, 112), "NAVY", fill=ink, font=font(FONT_B, 28), anchor="mm")
    d.text((w - 96, 150), "220 x 600 MM", fill=ink, font=font(FONT_N, 22), anchor="mm")
    for k in range(9):                                                                   # barcode
        d.rectangle([w - 160 + 16 * k, 184, w - 160 + 16 * k + 4 + 4 * (k % 3), 228], fill=ink)
    d.text((166, 48), "PORT HAVEN", fill=ink, font=font(FONT_K, 40), anchor="mm")
    d.text((166, 88), "MARINE FENDERS", fill=ink, font=font(FONT_B, 22), anchor="mm")
    d.rounded_rectangle([40, 128, 292, 206], 36, fill=navy)                              # fender silhouette
    for sx in (24, 308):
        d.ellipse([sx - 12, 155, sx + 12, 179], outline=navy, width=6)
    d.line([60, 136, 272, 136], fill=(88, 98, 124), width=6)
    return img


def draw_stock_box(w, hgt):
    img = Image.fromarray(kraft(w, hgt, 83).astype(np.uint8))
    d = ImageDraw.Draw(img)
    ink = (54, 46, 40)
    d.rectangle([8, 8, w - 9, hgt - 9], outline=ink, width=3)
    d.rectangle([28, 60, w - 29, 196], fill=(216, 208, 188))
    d.text((w // 2, 32), "PORT HAVEN", fill=ink, font=font(FONT_K, 26), anchor="mm")
    pict(d, "bow", 70, 128, 26, ink, 5)
    d.text((168, 100), "SHACKLES", fill=ink, font=font(FONT_N, 24), anchor="mm")
    d.text((168, 130), "S/S  A4", fill=ink, font=font(FONT_N, 22), anchor="mm")
    d.text((168, 166), "x 25", fill=(110, 52, 44), font=font(FONT_K, 26), anchor="mm")
    d.text((w // 2, 224), "TRADE PACK", fill=ink, font=font(FONT_B, 18), anchor="mm")
    return img


def draw_radio(w, hgt):
    img = Image.new("RGB", (w, hgt), (54, 56, 58))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, w - 5, hgt - 5], 14, outline=(78, 80, 82), width=4)
    d.rounded_rectangle([26, 34, 252, 150], 8, fill=(36, 38, 40))
    d.rectangle([34, 42, 244, 142], fill=(116, 128, 104))
    d.text((150, 96), "16", fill=(46, 52, 44), font=font(FONT_K, 70), anchor="mm")
    d.text((58, 60), "CH", fill=(56, 62, 52), font=font(FONT_B, 18), anchor="mm")
    d.text((58, 124), "HI", fill=(56, 62, 52), font=font(FONT_B, 18), anchor="mm")
    d.text((222, 60), "DSC", fill=(56, 62, 52), font=font(FONT_B, 14), anchor="mm")
    for r in range(3):
        for c in range(4):
            x0, y0 = 280 + c * 54, 40 + r * 40
            d.rounded_rectangle([x0, y0, x0 + 42, y0 + 28], 6, fill=(78, 80, 84))
            d.text((x0 + 21, y0 + 14), "16 9 H/L SCN DW WX MENU ENT CLR + - CALL".split()[r * 4 + c],
                   fill=(176, 176, 172), font=font(FONT_N, 13), anchor="mm")
    d.rounded_rectangle([280, 168, 330, 224], 6, fill=(150, 72, 60))
    d.text((305, 196), "DIST", fill=(214, 200, 186), font=font(FONT_N, 13), anchor="mm")
    for gy in range(176, 234, 11):
        for gx in range(350, 490, 11):
            d.ellipse([gx, gy, gx + 5, gy + 5], fill=(34, 35, 37))
    d.text((140, 196), "SEACALL  VHF 25W", fill=(150, 150, 146), font=font(FONT_B, 20), anchor="mm")
    d.text((140, 224), "MARINE TRANSCEIVER", fill=(112, 112, 110), font=font(FONT_N, 14), anchor="mm")
    return img


def draw_board(w, hgt, kind, seed):
    base = np.array(atlas.R["PaintBoard"][6], float)
    mul, hh, _ = pattern("paint", 512, seed)
    tile = np.clip(base * mul, 0, 255)
    bg = np.tile(tile, (hgt // 512 + 1, w // 512 + 1, 1))[:hgt, :w]
    img = Image.fromarray(bg.astype(np.uint8))
    d = ImageDraw.Draw(img)
    cream = (200, 190, 160)
    d.rectangle([22, 22, w - 23, hgt - 23], outline=cream, width=5)
    mask = Image.new("L", (w, hgt), 0)
    md = ImageDraw.Draw(mask)
    if kind == "hornboard":
        d.text((w // 2, 88), "HORN PACK", fill=cream, font=font(FONT_K, 78), anchor="mm")
        d.text((w // 2, 152), "PRESS TO HEAR", fill=(170, 162, 138), font=font(FONT_B, 28), anchor="mm")
        for i, t in enumerate(("FOGHORN", "TWIN TONE", "AIR HORN", "SHIP'S HORN")):
            cx = int(w * (0.14 + 0.24 * i))
            d.rounded_rectangle([cx - 92, hgt - 120, cx + 92, hgt - 70], 6, fill=(176, 148, 100), outline=(120, 98, 64), width=3)
            d.text((cx, hgt - 95), t, fill=(52, 42, 30), font=font(FONT_B, 24), anchor="mm")
    else:
        d.text((w // 2, 70), "LIVERIES", fill=cream, font=font(FONT_K, 58), anchor="mm")
        chips = [("STORM CHASER", (70, 86, 108), (206, 214, 52), True), ("COASTGUARD", (224, 100, 36), (226, 224, 216), True),
                 ("HI-VIS", (206, 214, 52), (44, 54, 80), True), ("HARBOUR", (44, 54, 80), (226, 224, 216), False),
                 ("LIFEBOAT", (150, 70, 60), (44, 54, 80), False), ("RACING", (50, 90, 66), (210, 200, 170), False),
                 ("NIGHT", (40, 42, 44), (120, 124, 128), False), ("STARTER", (226, 224, 216), (90, 104, 120), False)]
        for i, (t, c1, c2, sig) in enumerate(chips):
            r, c = divmod(i, 4)
            x0, y0 = 60 + c * 232, 118 + r * 190
            d.rectangle([x0 - 4, y0 - 4, x0 + 204, y0 + 134], fill=(30, 32, 34))
            d.rectangle([x0, y0, x0 + 200, y0 + 130], fill=c1)
            d.polygon([(x0, y0 + 80), (x0 + 200, y0 + 30), (x0 + 200, y0 + 60), (x0, y0 + 110)], fill=c2)
            if sig:
                md.rectangle([x0, y0, x0 + 200, y0 + 130], fill=255)
            d.text((x0 + 100, y0 + 156), t, fill=cream, font=font(FONT_B, 22), anchor="mm")
    return img, mask


def main():
    os.makedirs(OUT, exist_ok=True)
    N = atlas.ATLAS
    alb = np.zeros((N, N, 3))
    hgt = np.full((N, N), 0.5)
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
            strength = {"wicker": 5, "webbing": 4, "zip": 5, "tread": 5, "foam": 3, "grain": 3, "tape": 3}.get(pat, 4.0)
            nn = normal(hh, strength, False, fade=True)
        else:
            if pat == "tags":
                im, m = draw_tags(w, h), None
            elif pat == "radio":
                im, m = draw_radio(w, h), None
            elif pat == "binlabels":
                im, m = draw_bin_labels(w, h), None
            elif pat == "fenderbox":
                im, m = draw_fender_box(w, h), None
            elif pat == "stockbox":
                im, m = draw_stock_box(w, h), None
            else:
                im, m = draw_board(w, h, pat, 300 + i)
            a = np.asarray(im, float)
            lum = a.mean(-1) / 255.0
            hh = 0.5 + 0.3 * (lum - lum.mean())
            nn = normal(hh, 3.0, False, fade=True)
            if m is not None:
                sig[y0:y0 + h, x0:x0 + w] = np.asarray(m, float) / 255.0
            rg = 0.0 * hh
            if pat == "swatch":
                rg = np.where(np.asarray(m) > 0, -0.25, 0.0) + np.where(lum < 0.15, 0.0, 0.0)
        lo, hi = (188, 246) if metal else (34, 236)
        alb[y0:y0 + h, x0:x0 + w] = np.clip(a, lo, hi)
        nor[y0:y0 + h, x0:x0 + w] = nn
        rgh[y0:y0 + h, x0:x0 + w] = np.clip(rough + rg, 0.05, 1.0)
        met[y0:y0 + h, x0:x0 + w] = 1.0 if metal else 0.0
        if signal:
            sig[y0:y0 + h, x0:x0 + w] = 1.0
    # empty cells: neutral grey card so nothing reads as a hole
    used = np.zeros((N, N), bool)
    for cx, cy, cw, ch in (v[:4] for v in atlas.R.values()):
        used[N - (cy + ch) * C:N - cy * C, cx * C:(cx + cw) * C] = True
    alb[~used] = (110, 108, 104)
    stem = os.path.join(OUT, "T_ChandleryProps_Atlas_")
    Image.fromarray(alb.astype(np.uint8)).save(stem + "ALB.png")
    Image.fromarray(np.round(nor * 255).astype(np.uint8)).save(stem + "NOR.png")
    Image.fromarray(np.round(rgh * 255).astype(np.uint8)).save(stem + "RGH.png")
    Image.fromarray(np.round(met * 255).astype(np.uint8)).save(stem + "MET.png")
    Image.fromarray(np.round(sig * 255).astype(np.uint8)).save(os.path.join(HERE, "signal_mask.png"))

    # rope trim: 8 strips x 128 px, each 128 px tile repeated 8x in V
    S, T = atlas.ROPE_SIZE, atlas.ROPE_SIZE // 8
    ralb, rnor, rrgh = np.zeros((S, S, 3)), np.zeros((S, S, 3)), np.zeros((S, S))
    for i, (name, rgb, rough, profile, hank) in enumerate(atlas.ROPE_STRIPS):
        if hank:
            k = 4
            mini = rope.trim_height(profile, T // k, seed=11 + i)
            u = (np.arange(T) + 0.5)[None, :] / T
            ridge = np.sqrt(np.abs(np.sin(np.pi * ((u * k) % 1.0)))) + 0 * u.T
            h = ridge * (0.55 + 0.45 * np.tile(mini, (k, k)))
        else:
            h = rope.trim_height(profile, T, seed=11 + i)
        blotch = noise(T, 4, 50 + i)
        shade = (0.45 + 0.55 * h) * (0.9 + 0.2 * blotch)
        shade = np.maximum(shade, 36.0 / min(rgb))
        a = np.clip(np.array(rgb, float)[None, None, :] * shade[..., None], 34, 236)
        nn = normal(h, 3.0, True)
        rr = np.clip(rough + 0.12 * (1 - h) + 0.05 * (blotch - 0.5), 0, 1)
        sl = slice(i * T, (i + 1) * T)
        ralb[:, sl] = np.tile(a, (8, 1, 1))
        rnor[:, sl] = np.tile(nn, (8, 1, 1))
        rrgh[:, sl] = np.tile(rr, (8, 1))
    stem = os.path.join(OUT, "T_ChandleryProps_Rope_")
    Image.fromarray(ralb.astype(np.uint8)).save(stem + "ALB.png")
    Image.fromarray(np.round(rnor * 255).astype(np.uint8)).save(stem + "NOR.png")
    Image.fromarray(np.round(rrgh * 255).astype(np.uint8)).save(stem + "RGH.png")
    Image.fromarray(np.zeros((S, S), np.uint8)).save(stem + "MET.png")
    print("wrote", OUT)
    # map checks; signal_mask.png next to this script is picked up by check_textures' convention (auto_signal_masks)
    sys.path.insert(0, os.path.join(G, "tools/blender"))
    import check_textures
    rep = os.path.join(G, "assets/review", os.path.basename(OUT))
    os.makedirs(rep, exist_ok=True)
    return check_textures.main([OUT, "--json", os.path.join(rep, "check_textures.json")])


if __name__ == "__main__":
    sys.exit(main())
