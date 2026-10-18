"""HP2a harbour prop atlas maps (system python3 + numpy + Pillow, no Blender).

    python3 art/source/harbour/M_Hbr_PropAtlas/fetch.py      # Poly Haven CC0 scans -> build/hp2a/src
    python3 art/source/harbour/M_Hbr_PropAtlas/maketex.py

Metal regions are cut from real Poly Haven CC0 scans (rust_coarse_01, rusty_painted_metal, metal_plate_02,
green_metal_rust), made periodic, graded and re-composited (black paint chipped over rust, rope-polished iron,
galvanising, chain). Rubber takes rubberized_track's scanned normal / roughness. Rope tiles use tools/blender/rope.py's
trim heights; plastics, nets and the sign are procedural (numpy) with scan-derived grime. Every set gets a _Wet twin
(darker, glossier; porous rope darker still, metal barely). Masters at atlas.MASTER in masters/, exports at
atlas.EXPORT in assets/textures/M_Hbr_PropAtlas/, signal masks T_HbrProps_<Set>_signal.png next to this file.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(ROOT, "tools/blender"))
import atlas  # noqa: E402
import rope  # noqa: E402  (trim heights, tileable noise; pure numpy outside Blender)

SRC = os.path.join(ROOT, "build/hp2a/src")
MASTERS = os.path.join(HERE, "masters")
OUT = os.path.join(ROOT, "assets/textures", atlas.ATLAS_ASSET)
C = atlas.MASTER // atlas.GRID          # cell px at the master size
SCAN_M = {"rust_coarse_01": 2.2, "rusty_painted_metal": 2.2, "metal_plate_02": 2.0, "green_metal_rust": 1.0,
          "rubberized_track": 2.0}
_cache = {}


# ---------------------------------------------------------------- helpers
def scan(pid, short):
    k = (pid, short)
    if k not in _cache:
        im = Image.open(os.path.join(SRC, pid, short + ".png"))
        im = im.convert("RGB") if short in ("diff", "nor") else im.convert("L")
        _cache[k] = np.asarray(im, np.float32) / 255.0
    return _cache[k]


def periodic(a):
    """Make a tile periodic: cross-fade with its half-shifted copy under a cosine window."""
    n = a.shape[0]
    w1 = np.sin(np.pi * (np.arange(n) + 0.5) / n) ** 2
    w = np.outer(w1, w1)
    if a.ndim == 3:
        w = w[..., None]
    b = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    return a * w + b * (1 - w)


def crop(pid, short, scale_m, seed, n):
    """A scale_m x scale_m window of the scan, resized to n px and made periodic."""
    img = scan(pid, short)
    H = img.shape[0]
    px = max(16, int(H * scale_m / SCAN_M[pid]))
    px = min(px, H)
    rng = np.random.default_rng(seed)
    y, x = rng.integers(0, H - px + 1), rng.integers(0, H - px + 1)
    win = img[y:y + px, x:x + px]
    mode = "RGB" if win.ndim == 3 else "F"
    if win.ndim == 3:
        im = Image.fromarray((win * 255).astype(np.uint8), "RGB").resize((n, n), Image.LANCZOS)
        out = np.asarray(im, np.float32) / 255.0
    else:
        im = Image.fromarray(win.astype(np.float32), mode).resize((n, n), Image.LANCZOS)
        out = np.asarray(im, np.float32)
    return periodic(out)


def nor_vec(rgb):
    v = rgb * 2 - 1
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)


def nor_from_h(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5 * strength
    v = np.stack([-dx, -dy, np.ones_like(h)], -1)
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


def nmix(a, b, t):
    if np.ndim(t) == 2:
        t = t[..., None]
    v = a * (1 - t) + b * t
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)


def ndetail(base, det, k=1.0):
    """Whiteout blend of a detail normal onto a base normal."""
    v = np.stack([base[..., 0] + k * det[..., 0], base[..., 1] + k * det[..., 1], base[..., 2] * det[..., 2]], -1)
    return v / np.linalg.norm(v, axis=-1, keepdims=True)


FLAT = None


def flat(n):
    v = np.zeros((n, n, 3), np.float32)
    v[..., 2] = 1
    return v


def noise(n, cycles, seed):
    return rope.tile_noise(n, cycles, seed).astype(np.float32)


def fbm(n, seed, base=4, octaves=4):
    out = np.zeros((n, n), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += amp * noise(n, base * 2 ** o, seed + 17 * o)
        tot += amp
        amp *= 0.5
    return out / tot


def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lum(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def tint(rgb_u8, shade):
    return np.clip(np.array(rgb_u8, np.float32)[None, None, :] * shade[..., None], 0, 255)


def lerp(a, b, t):
    if np.ndim(t) == 2 and np.ndim(a) == 3:
        t = t[..., None]
    return a * (1 - t) + b * t


def clamp_sat(a, smax):
    mx, mn = a.max(-1), a.min(-1)
    s = (mx - mn) / np.maximum(mx, 1e-6)
    k = np.where(s > smax, smax / np.maximum(s, 1e-6), 1.0)[..., None]
    return mx[..., None] - (mx[..., None] - a) * k


def grade_rust(rgb, dark=1.0):
    """Scan rust graded to a weathered harbour rust: brown, not orange, saturation <= 0.44."""
    l = lum(rgb)
    base = np.array([118, 74, 50], np.float32) * dark
    out = base[None, None, :] * (0.55 + 0.9 * (l / max(l.mean(), 1e-3)))[..., None] * 0.5 + rgb * 255 * 0.5 * dark
    return clamp_sat(np.clip(out, 34, 220), 0.44)


def region_px(key, n_cells=None):
    cx, cy, cw, ch = atlas.R[key][:4]
    return cw * C, ch * C


# ---------------------------------------------------------------- metal recipes (each -> dict ALB, NOR, RGH, MET)
def m_iron_black(n, seed):
    s = atlas.scale("IronBlack")
    pd = crop("rusty_painted_metal", "diff", s, seed, n)
    pn = nor_vec(crop("rusty_painted_metal", "nor", s, seed, n))
    pr = crop("rusty_painted_metal", "rough", s, seed, n)
    rd = crop("rust_coarse_01", "diff", s, seed + 1, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", s, seed + 1, n))
    # the scan's own rust (warm, rough) drives where our paint is chipped; fbm adds larger flaking
    warm = np.clip((pd[..., 0] - pd[..., 2]) * 3.0, 0, 1)
    flake = ss(0.62, 0.70, fbm(n, seed + 5, 6) * 0.6 + warm * 0.5 + pr * 0.15)
    paint_l = 0.8 + 0.4 * (lum(pd) / max(lum(pd).mean(), 1e-3) - 1) * 0.3 + 0.12 * fbm(n, seed + 9, 3)
    paint = tint((40, 40, 42), paint_l)
    # chalky salt bloom on the paint
    bloom = ss(0.55, 0.85, fbm(n, seed + 21, 5)) * 0.35
    paint = lerp(paint, np.full_like(paint, 120), bloom * 0.35)
    rust = grade_rust(rd, 0.85)
    alb = lerp(paint, rust, flake)
    # paint lip: lighter worn ring round each chip
    edge = np.clip(ss(0.45, 0.62, fbm(n, seed + 5, 6) * 0.6 + warm * 0.5 + pr * 0.15) - flake, 0, 1)
    alb = lerp(alb, tint((86, 80, 74), np.ones((n, n), np.float32)), edge * 0.5)
    nor = nmix(ndetail(flat(n), pn, 0.5), rn, flake)
    rgh = np.clip(lerp(0.48 + 0.1 * pr + bloom * 0.3, 0.86 + 0.08 * crop("rust_coarse_01", "rough", s, seed + 1, n), flake), 0, 1)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def m_iron_worn(n, seed):
    # rope-polished band: U round the bollard neck, rope rubs along U, so streaks run horizontally
    rd = crop("rust_coarse_01", "diff", 0.25, seed, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", 0.25, seed, n))
    streak = np.asarray(Image.fromarray(noise(n, 64, seed + 2)).resize((n, n)), np.float32)
    yy = np.linspace(0, 1, n, endpoint=False)
    band = noise(n, 3, seed + 4)
    sx = np.clip(np.tile(np.interp(np.arange(n), np.arange(n), noise(n, 40, seed + 3)[n // 2]), (n, 1)).T, 0, 1)
    pol = ss(0.45, 0.65, sx * 0.7 + band * 0.4)                      # horizontal bright bands
    rust = grade_rust(rd, 0.7)
    steel = tint((186, 182, 178), 0.97 + 0.06 * fbm(n, seed + 6, 8))
    alb = lerp(rust, steel, pol)
    met = pol * 0.9
    rgh = np.clip(lerp(0.74, 0.32 + 0.08 * band, pol), 0, 1)
    nor = nmix(rn, flat(n), pol * 0.8)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


def m_iron_rust(n, seed):
    s = atlas.scale("IronRust")
    rd = crop("rust_coarse_01", "diff", s, seed, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", s, seed, n))
    rr = crop("rust_coarse_01", "rough", s, seed, n)
    gd = crop("green_metal_rust", "diff", s, seed + 3, n)
    alb = grade_rust(rd, 0.8)
    salt = ss(0.62, 0.8, fbm(n, seed + 7, 8)) * ss(0.4, 0.7, noise(n, 60, seed + 8))
    alb = lerp(alb, tint((196, 192, 182), np.ones((n, n), np.float32)), salt * 0.7)
    old_paint = ss(0.68, 0.74, fbm(n, seed + 9, 4))
    alb = lerp(alb, tint((44, 43, 42), 0.9 + 0.2 * lum(gd)), old_paint)
    rgh = np.clip(0.82 + 0.1 * rr + salt * 0.08 - old_paint * 0.25, 0, 1)
    return {"ALB": alb, "NOR": rn, "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def m_galv(n, seed, rusty=False, key="Galv"):
    s = atlas.scale(key)
    gd = crop("metal_plate_02", "diff", s, seed, n)
    gn = nor_vec(crop("metal_plate_02", "nor", s, seed, n))
    gr = crop("metal_plate_02", "rough", s, seed, n)
    l = lum(gd)
    l = (l - l.mean()) / max(l.std(), 1e-3)
    spangle = noise(n, 48, seed + 2)
    galv = tint((196, 198, 196), 1 + 0.035 * l + 0.03 * (spangle - 0.5))
    white = ss(0.6, 0.78, fbm(n, seed + 3, 6)) * 0.8                   # white rust (zinc hydroxide), dielectric
    alb = lerp(galv, tint((206, 206, 200), 0.96 + 0.06 * spangle), white)
    met = (1 - white) * 0.95
    rgh = np.clip(0.48 + 0.18 * gr + 0.08 * spangle + white * 0.35, 0, 1)
    nor = ndetail(flat(n), gn, 0.7)
    if rusty:
        rd = crop("rust_coarse_01", "diff", s, seed + 4, n)
        rn = nor_vec(crop("rust_coarse_01", "nor", s, seed + 4, n))
        m = ss(0.55, 0.68, fbm(n, seed + 5, 5) * 0.8 + 0.25 * noise(n, 40, seed + 6))
        alb = lerp(alb, grade_rust(rd, 0.85), m)
        met = met * (1 - m)
        rgh = lerp(rgh, 0.85, m)
        nor = nmix(nor, rn, m)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


def m_chain(n, seed):
    s = atlas.scale("Chain")
    rd = crop("rust_coarse_01", "diff", s, seed, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", s, seed, n))
    g = m_galv(n, seed + 1, key="Chain")
    m = ss(0.35, 0.6, fbm(n, seed + 2, 5))
    alb = lerp(g["ALB"], grade_rust(rd, 0.75), m)
    return {"ALB": alb, "NOR": nmix(g["NOR"], rn, m), "RGH": lerp(g["RGH"], 0.82, m), "MET": g["MET"] * (1 - m)}


def m_stainless(n, seed):
    brushed = np.asarray(Image.fromarray(noise(n, 128, seed)).resize((n // 32, n)).resize((n, n), Image.BILINEAR), np.float32)
    alb = tint((200, 200, 198), 0.96 + 0.08 * brushed)
    tea = ss(0.7, 0.85, fbm(n, seed + 1, 6))                           # tea staining
    alb = lerp(alb, tint((150, 120, 92), np.ones((n, n), np.float32)), tea * 0.5)
    return {"ALB": clamp_sat(alb, 0.3), "NOR": nor_from_h(brushed, 0.6), "RGH": np.clip(0.3 + 0.1 * brushed + tea * 0.3, 0, 1),
            "MET": 1 - tea * 0.6}


def paint_coat(n, seed, rgb, rough, scan_pid="green_metal_rust", chip=0.0, key=None):
    s = atlas.scale(key) if key else 0.5
    gd = crop(scan_pid, "diff", s, seed, n)
    gn = nor_vec(crop(scan_pid, "nor", s, seed, n))
    var = fbm(n, seed + 1, 4)
    alb = tint(rgb, 0.92 + 0.12 * var)
    chalk = ss(0.5, 0.9, fbm(n, seed + 2, 3)) * 0.25                   # UV chalking
    alb = lerp(alb, alb * 0.6 + 90, chalk)
    grime = ss(0.55, 0.85, fbm(n, seed + 3, 6)) * 0.35
    alb = lerp(alb, alb * 0.55, grime)
    scratch = ss(0.92, 0.97, noise(n, 90, seed + 4))
    alb = lerp(alb, alb * 0.75 + 30, scratch * 0.6)
    rgh = np.clip(rough + 0.15 * chalk + 0.2 * grime + 0.1 * scratch, 0, 1)
    nor = ndetail(flat(n), gn, 0.25)
    if chip:
        m = ss(0.75 - chip, 0.8 - chip, lum(gd) * 0.0 + fbm(n, seed + 6, 7))
        rd = crop("rust_coarse_01", "diff", s, seed + 7, n)
        alb = lerp(alb, grade_rust(rd, 0.8), m)
        rgh = lerp(rgh, 0.85, m)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def m_concrete(n, seed):
    gd = crop("rusty_painted_metal", "rough", 0.6, seed, n)
    v = fbm(n, seed, 6)
    agg = ss(0.7, 0.8, noise(n, 100, seed + 1))
    alb = tint((132, 130, 124), 0.85 + 0.25 * v - 0.12 * agg)
    alb = lerp(alb, tint((84, 96, 70), np.ones((n, n), np.float32)), ss(0.7, 0.9, fbm(n, seed + 2, 3)) * 0.4)
    h = v * 0.6 + agg * 0.4 + gd * 0.3
    return {"ALB": clamp_sat(alb, 0.3), "NOR": nor_from_h(h, 3.0), "RGH": np.clip(0.82 + 0.1 * v, 0, 1),
            "MET": np.zeros((n, n), np.float32)}


def font(size, bold=True):
    for p in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf",
              "/Library/Fonts/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def m_sign(w, h, seed):
    im = Image.new("RGB", (w, h), (226, 222, 212))
    d = ImageDraw.Draw(im)
    red = (176, 44, 38)
    d.rectangle([0, 0, w - 1, int(h * 0.42)], fill=red)
    d.rectangle([3, 3, w - 4, h - 4], outline=red, width=6)
    f1, f2, f3 = font(int(h * 0.27)), font(int(h * 0.085)), font(int(h * 0.07), False)
    t = "LIFEBUOY"
    tw = d.textlength(t, font=f1)
    d.text(((w - tw) / 2, h * 0.06), t, font=f1, fill=(232, 228, 220))
    lines = [("IN AN EMERGENCY", f2), ("DIAL 999 OR 112 - ASK FOR THE COASTGUARD", f2),
             ("THROW THE LIFEBUOY - DO NOT ENTER THE WATER", f3), ("THEFT OR MISUSE ENDANGERS LIVES", f3)]
    y = h * 0.47
    for txt, f in lines:
        tw = d.textlength(txt, font=f)
        d.text(((w - tw) / 2, y), txt, font=f, fill=(40, 40, 42) if f is f3 else red)
        y += f.size * 1.32
    a = np.asarray(im, np.float32)
    n = np.asarray(Image.fromarray(fbm(max(w, h), seed, 4)).resize((w, h)), np.float32)
    grime = ss(0.55, 0.9, n) * 0.3
    a = lerp(a, a * 0.62 + 20, grime)
    rgh = np.clip(0.42 + grime * 0.4, 0, 1)
    nv = np.zeros((h, w, 3), np.float32)
    nv[..., 2] = 1
    return {"ALB": a, "NOR": nv, "RGH": rgh, "MET": np.zeros((h, w), np.float32)}


# ---------------------------------------------------------------- rope set recipes
def r_rope(n, seed, rgb, profile, rough, dirt=0.25):
    h = rope.trim_height(profile, n, seed).astype(np.float32)
    blotch = noise(n, 6, seed + 1)
    fuzz = noise(n, n / 3, seed + 2)
    shade = (0.5 + 0.5 * h) * (0.88 + 0.22 * blotch) * (0.94 + 0.12 * fuzz)
    alb = tint(rgb, shade)
    d = ss(0.5, 0.85, fbm(n, seed + 3, 3)) * dirt
    alb = lerp(alb, alb * 0.55 + tint((60, 52, 40), np.ones((n, n), np.float32)) * 0.25, d)
    alb = np.maximum(alb, 32)
    rgh = np.clip(rough + 0.12 * (1 - h) + 0.05 * (blotch - 0.5) + d * 0.1, 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(h * 0.9 + 0.1 * fuzz, 7.0), "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def r_plastic(n, seed, rgb, rough, scuff=0.35, algae=0.0, grain=0.4, mould=False):
    v = fbm(n, seed, 4)
    alb = tint(rgb, 0.94 + 0.1 * v)
    sc = ss(0.86, 0.96, noise(n, 70, seed + 1)) * scuff                 # black rub marks from quay walls
    alb = lerp(alb, tint((52, 52, 52), np.ones((n, n), np.float32)), sc)
    gr = ss(0.5, 0.9, fbm(n, seed + 2, 5)) * 0.3                        # grime
    alb = lerp(alb, alb * 0.62 + 18, gr)
    if algae:
        al = ss(0.6, 0.85, fbm(n, seed + 3, 3)) * algae
        alb = lerp(alb, tint((74, 92, 60), np.ones((n, n), np.float32)), al)
    else:
        al = 0
    fine = noise(n, n / 4, seed + 4)
    h = fine * grain * 0.25 + v * 0.2
    if mould:  # HDPE fish box: moulded ribs every 1/8 tile
        rib = 0.5 + 0.5 * np.cos(2 * np.pi * 8 * np.arange(n) / n)
        h = h + np.tile(ss(0.75, 0.95, rib), (n, 1)).T * 0.6
    scratches = ss(0.95, 0.99, np.asarray(Image.fromarray(noise(n, 96, seed + 5)).resize((n, n // 16)).resize((n, n)), np.float32))
    alb = lerp(alb, alb * 0.8 + 40, scratches * 0.4)
    rgh = np.clip(rough + 0.25 * gr + 0.2 * sc + 0.1 * scratches + 0.15 * (al if algae else 0), 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(h, 3.0), "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def r_rubber(n, seed, tread=False):
    key = "Tread" if tread else "Rubber"
    rr = crop("rubberized_track", "rough", atlas.scale(key), seed, n)
    rn = nor_vec(crop("rubberized_track", "nor", atlas.scale(key), seed, n))
    v = fbm(n, seed + 1, 5)
    alb = tint((48, 48, 50), 0.92 + 0.14 * v)
    bloom = ss(0.55, 0.85, fbm(n, seed + 2, 4)) * 0.4                    # grey ozone bloom / salt
    alb = lerp(alb, tint((104, 102, 98), np.ones((n, n), np.float32)), bloom)
    nor = ndetail(flat(n), rn, 0.4)
    if tread:
        x = np.arange(n) / n
        blocks = (np.sin(2 * np.pi * 6 * x)[None, :] > -0.3) & (np.sin(2 * np.pi * 4 * x + 1.0)[:, None] > -0.5)
        groove = (np.abs(((np.arange(n) / n * 3) % 1) - 0.5) < 0.06)[None, :]
        h = blocks.astype(np.float32) * (1 - groove) * 0.6
        nor = ndetail(nor_from_h(h, 6.0), nor, 1.0)
        alb = lerp(alb, alb * 0.7, 1 - h / 0.6)
    rgh = np.clip(0.78 + 0.1 * rr + bloom * 0.1, 0, 1)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def r_retro(n, seed):
    x, y = np.meshgrid(np.arange(n), np.arange(n))
    s = n / 24.0
    q = (np.cos(2 * np.pi * x / s) + np.cos(2 * np.pi * (x * 0.5 + y * 0.866) / s) + np.cos(2 * np.pi * (x * 0.5 - y * 0.866) / s))
    h = ss(-1.0, 2.0, q).astype(np.float32)
    v = fbm(n, seed, 4)
    alb = tint((204, 204, 200), 0.94 + 0.05 * h + 0.04 * v)
    gr = ss(0.55, 0.85, fbm(n, seed + 1, 5)) * 0.35
    alb = lerp(alb, alb * 0.6, gr)
    return {"ALB": alb, "NOR": nor_from_h(h, 1.5), "RGH": np.clip(0.28 + 0.3 * gr, 0, 1), "MET": np.zeros((n, n), np.float32)}


def r_net(w, seed, rgb, meshes, twine):
    """Alpha net tile: diamond mesh of knotted twine. Returns maps plus an alpha channel."""
    n = w
    u, v = np.meshgrid((np.arange(n) + 0.5) / n, (np.arange(n) + 0.5) / n)
    a1 = (u + v) * meshes
    a2 = (u - v) * meshes
    d1 = np.abs((a1 % 1.0) - 0.5)
    d2 = np.abs((a2 % 1.0) - 0.5)
    tw = twine * meshes
    t1 = np.clip(1 - (0.5 - d1) / tw, 0, 1)
    t2 = np.clip(1 - (0.5 - d2) / tw, 0, 1)
    h = np.maximum(np.sqrt(np.clip(t1, 0, 1)), np.sqrt(np.clip(t2, 0, 1)))
    knot = np.clip(1 - np.hypot(0.5 - d1, 0.5 - d2) / (tw * 1.9), 0, 1)
    h = np.maximum(h, np.sqrt(knot) * 1.1)
    # wobble so the mesh is not machine-perfect
    alpha = ss(0.15, 0.35, h)
    shade = 0.55 + 0.45 * np.clip(h, 0, 1)
    var = fbm(n, seed, 4)
    alb = tint(rgb, shade * (0.9 + 0.2 * var))
    alb = np.maximum(alb, 30)
    rgh = np.clip(0.62 + 0.15 * (1 - h), 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(h, 4.0), "RGH": rgh, "MET": np.zeros((n, n), np.float32), "A": alpha}


# ---------------------------------------------------------------- assembly
RECIPES = {
    "IronBlack": lambda n, s: m_iron_black(n, s),
    "IronWorn": lambda n, s: m_iron_worn(n, s),
    "IronRust": lambda n, s: m_iron_rust(n, s),
    "Galv": lambda n, s: m_galv(n, s),
    "GalvRust": lambda n, s: m_galv(n, s, rusty=True, key="GalvRust"),
    "Chain": lambda n, s: m_chain(n, s),
    "Stainless": lambda n, s: m_stainless(n, s),
    "BlackPaint": lambda n, s: paint_coat(n, s, (46, 46, 48), 0.42, chip=0.06, key="BlackPaint"),
    "HousingRed": lambda n, s: paint_coat(n, s, (172, 46, 40), 0.36, key="HousingRed"),
    "Concrete": lambda n, s: m_concrete(n, s),
    "RopeBlue": lambda n, s: r_rope(n, s, (74, 96, 132), "three_strand", 0.6),
    "RopeOrange": lambda n, s: r_rope(n, s, (196, 106, 50), "three_strand", 0.58),
    "RopeBuff": lambda n, s: r_rope(n, s, (160, 140, 106), "three_strand", 0.8, dirt=0.4),
    "RopeBraid": lambda n, s: r_rope(n, s, (196, 194, 184), "braid", 0.66, dirt=0.45),
    "RopeThrow": lambda n, s: r_rope(n, s, (214, 176, 52), "braid", 0.55),
    "RopeBlack": lambda n, s: r_rope(n, s, (52, 52, 54), "three_strand", 0.62, dirt=0.1),
    "PVCWhite": lambda n, s: r_plastic(n, s, (208, 208, 202), 0.36, scuff=0.45, algae=0.25),
    "PVCNavy": lambda n, s: r_plastic(n, s, (54, 64, 88), 0.38, scuff=0.3, algae=0.15),
    "BallOrange": lambda n, s: r_plastic(n, s, (204, 92, 40), 0.40, scuff=0.35, algae=0.15),
    "Rubber": lambda n, s: r_rubber(n, s),
    "Tread": lambda n, s: r_rubber(n, s, tread=True),
    "FishBlue": lambda n, s: r_plastic(n, s, (76, 102, 136), 0.5, scuff=0.25, mould=True),
    "FishRed": lambda n, s: r_plastic(n, s, (166, 62, 52), 0.5, scuff=0.25, mould=True),
    "PotCoat": lambda n, s: r_plastic(n, s, (50, 52, 50), 0.48, scuff=0.0, algae=0.2, grain=0.8),
    "SOLAS": lambda n, s: r_plastic(n, s, (222, 92, 32), 0.42, scuff=0.15, grain=0.6),
    "Retro": lambda n, s: r_retro(n, s),
    "Float": lambda n, s: r_plastic(n, s, (210, 118, 42), 0.44, scuff=0.2, algae=0.2),
    "PotBase": lambda n, s: r_rubber(n, s),
    "NetDense": lambda n, s: r_net_dense(n, s),
}


def r_net_dense(n, seed):
    """Opaque heaped net: four offset layers of green / orange twine over a dark shadowed interior."""
    alb = tint((30, 36, 30), 0.9 + 0.2 * fbm(n, seed, 4))
    h = np.zeros((n, n), np.float32)
    rgh = np.full((n, n), 0.8, np.float32)
    for i, (rgb, meshes) in enumerate((((60, 88, 62), 5), ((72, 104, 74), 6), ((190, 104, 50), 6), ((76, 108, 78), 7))):
        m = r_net(n, seed + 11 * i, rgb, meshes, 0.07)
        m = {k: np.roll(np.roll(v, 37 * i, 0), 53 * i, 1) for k, v in m.items()}
        a = m["A"] if i != 2 else m["A"] * ss(0.55, 0.65, fbm(n, seed + 3, 3))
        depth = 0.55 + 0.15 * i
        alb = lerp(alb, m["ALB"] * depth, a)
        h = np.maximum(h, a * (0.4 + 0.2 * i))
        rgh = lerp(rgh, m["RGH"], a)
    return {"ALB": np.maximum(alb, 30), "NOR": nor_from_h(h, 3.0), "RGH": rgh, "MET": np.zeros((n, n), np.float32)}
NETS = {"NetGreen": ((72, 104, 74), 8, 0.05), "NetBlue": ((70, 92, 122), 9, 0.05),
        "NetOrange": ((198, 110, 52), 8, 0.05), "NetBlack": ((50, 52, 52), 9, 0.055)}


def wet(m, key):
    """_Wet: darker and glossier; porous rope / nets darker still, metal barely changes."""
    porous = key.startswith(("Rope", "Net")) or key == "NetDense" or key in ("Concrete", "IronRust", "Chain")
    metal = m["MET"]
    dk = 0.62 if porous else 0.78
    k = (dk + (1 - dk) * 0.5 * metal)
    alb = m["ALB"] * (k[..., None] if np.ndim(k) == 2 else k)
    alb = np.maximum(alb, 26)
    gloss = 0.45 if porous else 0.55
    rgh = np.clip(m["RGH"] * (1 - gloss) + 0.04, 0.12, 1)
    out = dict(m, ALB=alb, RGH=rgh)
    return out


def build_set(set_name, size):
    alpha = set_name == "Rope"
    maps = {"ALB": np.full((size, size, 3), 128, np.float32), "NOR": flat(size), "RGH": np.full((size, size), 0.7, np.float32),
            "MET": np.zeros((size, size), np.float32), "A": np.ones((size, size), np.float32)}
    wmaps = {k: v.copy() for k, v in maps.items()}
    wmaps["ALB"][:] = 92
    wmaps["RGH"][:] = 0.4
    sig = np.zeros((size, size), np.uint8)
    for i, (key, r) in enumerate(sorted(atlas.R.items())):
        if r[6] != set_name:
            continue
        cx, cy, cw, ch = r[:4]
        w, h = cw * C, ch * C
        seed = 101 + 37 * i
        if r[4] == "fit":
            m = m_sign(w, h, seed)
        elif r[4] == "net":
            rgb, meshes, tw = NETS[key]
            m = r_net(w, seed, rgb, meshes, tw)
        else:
            m = RECIPES[key](w, seed)
        mw = wet(m, key)
        y0 = size - (cy + ch) * C
        x0 = cx * C
        for dst, src in ((maps, m), (wmaps, mw)):
            for k in ("ALB", "NOR", "RGH", "MET"):
                dst[k][y0:y0 + h, x0:x0 + w] = src[k]
            dst["A"][y0:y0 + h, x0:x0 + w] = src.get("A", 1.0)
        if r[7]:
            sig[y0:y0 + h, x0:x0 + w] = 255
    return maps, wmaps, sig, alpha


def to_images(m, alpha):
    alb = np.clip(m["ALB"], 0, 255)
    met = np.clip(m["MET"], 0, 1)
    # albedo range (05): dielectric 30..240 (1.4a), metal 180..250
    lo = np.where(met > 0.5, 186.0, 30.0)[..., None]
    hi = np.where(met > 0.5, 250.0, 240.0)[..., None]
    alb = np.clip(alb, lo, hi)
    if alpha:
        a = np.clip(m["A"] * 255, 0, 255)
        ALB = Image.fromarray(np.dstack([alb, a]).round().astype(np.uint8), "RGBA")
    else:
        ALB = Image.fromarray(alb.round().astype(np.uint8), "RGB")
    NOR = Image.fromarray(np.clip((m["NOR"] * 0.5 + 0.5) * 255, 0, 255).round().astype(np.uint8), "RGB")
    RGH = Image.fromarray(np.clip(m["RGH"] * 255, 0, 255).round().astype(np.uint8), "L")
    MET = Image.fromarray(np.clip(met * 255, 0, 255).round().astype(np.uint8), "L")
    return {"ALB": ALB, "NOR": NOR, "RGH": RGH, "MET": MET}


def downsize(im, size, kind):
    out = im.resize((size, size), Image.LANCZOS)
    if kind == "NOR":
        v = np.asarray(out, np.float32) / 127.5 - 1
        v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
        out = Image.fromarray(np.clip((v * 0.5 + 0.5) * 255, 0, 255).round().astype(np.uint8), "RGB")
    return out


def main():
    os.makedirs(MASTERS, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for set_name in atlas.SETS:
        maps, wmaps, sig, alpha = build_set(set_name, atlas.MASTER)
        for suffix, m in (("", maps), ("_Wet", wmaps)):
            ims = to_images(m, alpha)
            for k, im in ims.items():
                fn = "T_%s_%s_%s%s.png" % (atlas.NAME, set_name, k, suffix)
                im.save(os.path.join(MASTERS, fn), optimize=True)
                downsize(im, atlas.EXPORT, k).save(os.path.join(OUT, fn), optimize=True)
                print("wrote", fn)
        Image.fromarray(sig, "L").resize((atlas.EXPORT, atlas.EXPORT), Image.NEAREST).save(
            os.path.join(HERE, "T_%s_%s_signal.png" % (atlas.NAME, set_name)))


if __name__ == "__main__":
    main()
