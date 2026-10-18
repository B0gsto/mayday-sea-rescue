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


# ---------------------------------------------------------------- HP2a-fix helpers
def q(a, p):
    return float(np.quantile(a, p))


def blur(a, k):
    """Cheap periodic-ish blur by down / up resampling (k = factor)."""
    n0, n1 = a.shape[:2]
    if a.ndim == 3:
        return np.stack([blur(a[..., i], k) for i in range(a.shape[2])], -1)
    im = Image.fromarray(a.astype(np.float32), "F")
    return np.asarray(im.resize((max(1, n1 // k), max(1, n0 // k)), Image.BILINEAR).resize((n1, n0), Image.BICUBIC), np.float32)


def stretch(a, fx, fy):
    """Resample a square periodic map to (n/fx, n/fy) and back: streaks along the squashed axis."""
    n0, n1 = a.shape
    im = Image.fromarray(a.astype(np.float32), "F")
    return np.asarray(im.resize((max(2, int(n1 / fx)), max(2, int(n0 / fy))), Image.BILINEAR).resize((n1, n0), Image.BICUBIC), np.float32)


def rnoise(w, h, cycles, seed):
    """Periodic noise on a w x h decal (a square periodic tile resampled)."""
    n = max(w, h)
    a = noise(n, cycles, seed)
    if (w, h) == (n, n):
        return a
    return np.asarray(Image.fromarray(a, "F").resize((w, h), Image.BICUBIC), np.float32)


def rfbm(w, h, seed, base=4, octaves=4):
    n = max(w, h)
    a = fbm(n, seed, base, octaves)
    if (w, h) == (n, n):
        return a
    return np.asarray(Image.fromarray(a, "F").resize((w, h), Image.BICUBIC), np.float32)


def drip(mask, steps=40, shift=3, decay=0.94):
    """Trails running DOWN the image (towards V = 0) from a mask: rust bleed, grime runs."""
    acc = mask.copy()
    for _ in range(steps):
        acc = np.maximum(acc, np.roll(acc, shift, 0) * decay)
    return acc


# ---------------------------------------------------------------- metal recipes (each -> dict ALB, NOR, RGH, MET)
def m_iron_black(n, seed):
    """Cast iron under old black gloss paint: sand-cast lumps and pits telegraphing through, ~13 % chips to dark rust
    with lifted paint lips, rust bleed running down from the chips, chalky salt bloom."""
    s = atlas.scale("IronBlack")
    pd = crop("rusty_painted_metal", "diff", s, seed, n)
    pn = nor_vec(crop("rusty_painted_metal", "nor", s, seed, n))
    pr = crop("rusty_painted_metal", "rough", s, seed, n)
    rd = crop("rust_coarse_01", "diff", s, seed + 1, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", s, seed + 1, n))
    rr = crop("rust_coarse_01", "rough", s, seed + 1, n)
    warm = np.clip((pd[..., 0] - pd[..., 2]) * 3.0, 0, 1)
    field = fbm(n, seed + 5, 6) * 0.55 + warm * 0.35 + noise(n, 40, seed + 6) * 0.2
    t = q(field, 0.87)
    flake = ss(t - 0.012, t + 0.012, field)
    lip = np.clip(ss(t - 0.05, t - 0.012, field) - flake, 0, 1)
    pit = noise(n, 110, seed + 7) * 0.7 + noise(n, 50, seed + 8) * 0.3
    pits = ss(q(pit, 0.92), q(pit, 0.975), pit)
    cast = fbm(n, seed + 9, 10, 3)
    var = fbm(n, seed + 10, 3)
    paint = tint((27, 27, 29), 0.92 + 0.18 * var + 0.1 * (cast - 0.5))
    bloom = ss(0.55, 0.85, fbm(n, seed + 21, 5)) * 0.3
    paint = lerp(paint, tint((84, 84, 82), np.ones((n, n), np.float32)), bloom * 0.35)
    paint = lerp(paint, paint * 0.7, pits * 0.6)
    streak = drip(flake * (0.6 + 0.4 * stretch(noise(n, 60, seed + 11), 1, 12)), 45, 3, 0.955) - flake
    streak = np.clip(streak, 0, 1) * (0.55 + 0.45 * stretch(noise(n, 30, seed + 12), 1, 16))
    paint = lerp(paint, tint((74, 50, 38), np.ones((n, n), np.float32)), np.clip(streak, 0, 1) * 0.45)
    rust = grade_rust(rd, 0.6)
    rust = lerp(rust, tint((40, 34, 30), np.ones((n, n), np.float32)), ss(0.5, 0.8, fbm(n, seed + 13, 8)) * 0.5)
    alb = lerp(paint, rust, flake)
    alb = lerp(alb, tint((70, 68, 64), np.ones((n, n), np.float32)), lip * 0.55)
    h = (1 - flake) * 0.55 + lip * 0.15 + cast * 0.35 - pits * 0.5
    nor = ndetail(nor_from_h(h, 5.0), pn, 0.3)
    nor = nmix(nor, ndetail(rn, nor_from_h(-pits, 3.0), 1.0), flake)
    rgh = 0.42 + 0.1 * pr + bloom * 0.25 + np.clip(streak, 0, 1) * 0.15 + pits * 0.15
    rgh = np.clip(lerp(rgh, 0.84 + 0.1 * rr, flake), 0, 1)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def m_iron_worn(n, seed):
    """Rope-polished neck: U round the bollard, V up it, so the rope's rub striations run along U (image rows constant).
    Three polished grooves per tile, bright bare iron in the grooves and on the rub bands, black paint and rust left
    between them."""
    rd = crop("rust_coarse_01", "diff", 0.3, seed, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", 0.3, seed, n))
    v = (np.arange(n, dtype=np.float32) + 0.5) / n
    groove1 = np.exp(-((((v * 3) % 1.0) - 0.5) / 0.13) ** 2)
    groove = np.tile(groove1[:, None], (1, n))
    fine = stretch(noise(n, 160, seed + 2), 24, 1) * 0.6 + stretch(noise(n, 60, seed + 3), 16, 1) * 0.4
    pol = ss(0.3, 0.62, groove * 0.75 + fine * 0.45 + 0.15 * fbm(n, seed + 4, 3))
    paint = tint((28, 28, 30), 0.92 + 0.15 * fbm(n, seed + 5, 4))
    rust = grade_rust(rd, 0.62)
    between = lerp(paint, rust, ss(0.45, 0.7, fbm(n, seed + 6, 6)))
    steel = tint((196, 192, 186), 0.94 + 0.08 * fine)
    alb = lerp(between, steel, pol)
    met = pol * 0.92
    rgh = np.clip(lerp(0.7, 0.26 + 0.14 * (1 - fine), pol), 0, 1)
    h = groove * -0.6 + fine * 0.25
    nor = nmix(rn, ndetail(flat(n), nor_from_h(h, 8.0), 1.0), np.clip(pol + 0.3, 0, 1))
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


def m_iron_rust(n, seed):
    """Foot / base plate: dark harbour rust, pitted, half the old black paint left, salt crust in the low spots."""
    s = atlas.scale("IronRust")
    rd = crop("rust_coarse_01", "diff", s, seed, n)
    rn = nor_vec(crop("rust_coarse_01", "nor", s, seed, n))
    rr = crop("rust_coarse_01", "rough", s, seed, n)
    alb = grade_rust(rd, 0.62)
    alb = lerp(alb, tint((38, 32, 28), np.ones((n, n), np.float32)), ss(0.45, 0.75, fbm(n, seed + 3, 7)) * 0.55)
    f = fbm(n, seed + 9, 4)
    old_paint = ss(q(f, 0.45), q(f, 0.5), f)
    alb = lerp(alb, tint((30, 30, 32), 0.9 + 0.2 * fbm(n, seed + 10, 6)), old_paint)
    salt = ss(0.62, 0.8, fbm(n, seed + 7, 8)) * ss(0.4, 0.7, noise(n, 60, seed + 8))
    alb = lerp(alb, tint((176, 172, 162), np.ones((n, n), np.float32)), salt * 0.45)
    pit = noise(n, 120, seed + 11)
    pits = ss(q(pit, 0.9), q(pit, 0.97), pit)
    nor = nmix(ndetail(rn, nor_from_h(-pits, 3.0), 1.0), ndetail(nor_from_h(-pits * 0.5, 3.0), rn, 0.3), old_paint)
    rgh = np.clip(0.84 + 0.1 * rr + salt * 0.06 - old_paint * 0.3, 0, 1)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


def m_galv(n, seed, rusty=False, key="Galv"):
    """Weathered hot-dip galvanising: dull mid-grey zinc patina (part metallic, rough), faint spangle, darker handling
    patches, small powdery white-rust blooms; the rusty variant adds rust bleed from the bolt holes and edges."""
    s = atlas.scale(key)
    gd = crop("metal_plate_02", "diff", s, seed, n)
    gn = nor_vec(crop("metal_plate_02", "nor", s, seed, n))
    gr = crop("metal_plate_02", "rough", s, seed, n)
    l = lum(gd)
    l = (l - l.mean()) / max(l.std(), 1e-3)
    spangle = noise(n, 40, seed + 2)
    patina = fbm(n, seed + 3, 4)
    galv = tint((128, 130, 128), 1 + 0.04 * l + 0.05 * (spangle - 0.5) - 0.12 * ss(0.5, 0.8, patina))
    wf = fbm(n, seed + 4, 9) * 0.7 + noise(n, 70, seed + 5) * 0.3
    white = ss(q(wf, 0.9), q(wf, 0.96), wf)
    halo = np.clip(ss(q(wf, 0.82), q(wf, 0.9), wf) - white, 0, 1)
    alb = lerp(galv, tint((188, 188, 182), 0.95 + 0.08 * spangle), white * 0.9)
    alb = lerp(alb, alb * 1.12 + 8, halo * 0.4)
    met = np.clip(0.42 - 0.1 * ss(0.5, 0.8, patina) - white * 0.42, 0, 1)
    rgh = np.clip(0.6 + 0.12 * gr + 0.05 * spangle + white * 0.3 + halo * 0.1, 0, 1)
    nor = ndetail(nor_from_h(white * 0.6 + spangle * 0.1, 3.0), gn, 0.5)
    if rusty:
        rd = crop("rust_coarse_01", "diff", s, seed + 4, n)
        rn = nor_vec(crop("rust_coarse_01", "nor", s, seed + 4, n))
        rf = fbm(n, seed + 5, 5) * 0.8 + 0.25 * noise(n, 40, seed + 6)
        m = ss(q(rf, 0.84), q(rf, 0.9), rf)
        m = np.clip(m + np.clip(drip(m, 30, 3, 0.95) - m, 0, 1) * 0.5, 0, 1)
        alb = lerp(alb, grade_rust(rd, 0.7), m)
        met = met * (1 - m)
        rgh = lerp(rgh, 0.85, m)
        nor = nmix(nor, rn, m * 0.8)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


def m_chain(n, seed):
    """Mooring chain: dark brown rust and black mill scale with a little dull galvanising left, smooth (blurred) relief
    so the link shapes read rather than the noise."""
    s = atlas.scale("Chain")
    rd = blur(crop("rust_coarse_01", "diff", s, seed, n), 4)
    rn = nor_vec(blur(crop("rust_coarse_01", "nor", s, seed, n), 6))
    alb = grade_rust(rd, 0.62)
    alb = lerp(alb, tint((38, 34, 32), np.ones((n, n), np.float32)), ss(0.45, 0.7, fbm(n, seed + 3, 4)) * 0.6)
    gf = fbm(n, seed + 2, 4)
    g = ss(q(gf, 0.84), q(gf, 0.9), gf)
    alb = lerp(alb, tint((118, 120, 118), 0.95 + 0.1 * fbm(n, seed + 4, 8)), g)
    nor = nmix(flat(n), rn, 0.35)
    rgh = np.clip(lerp(0.8 + 0.08 * fbm(n, seed + 5, 6), 0.55, g), 0, 1)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": g * 0.4}


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
def r_rope(n, seed, rgb, profile, rough, dirt=0.25, contrast=0.5, strength=7.0):
    h = rope.trim_height(profile, n, seed).astype(np.float32)
    blotch = noise(n, 6, seed + 1)
    fuzz = noise(n, n / 3, seed + 2)
    shade = ((1 - contrast) + contrast * np.clip(h, 0, 1) ** 0.8) * (0.88 + 0.22 * blotch) * (0.94 + 0.12 * fuzz)
    alb = tint(rgb, shade)
    d = ss(0.5, 0.85, fbm(n, seed + 3, 3)) * dirt
    alb = lerp(alb, alb * 0.55 + tint((60, 52, 40), np.ones((n, n), np.float32)) * 0.25, d)
    alb = np.maximum(alb, 32)
    rgh = np.clip(rough + 0.12 * (1 - h) + 0.05 * (blotch - 0.5) + d * 0.1, 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(h * 0.9 + 0.1 * fuzz, strength), "RGH": rgh, "MET": np.zeros((n, n), np.float32)}


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
    """Weathered tyre rubber: oxidised grey-brown bloom, ozone crazing (fine crack network), pale abrasion scuffs, salt;
    the tread adds worn blocks with grit packed in the grooves."""
    key = "Tread" if tread else "Rubber"
    rr = crop("rubberized_track", "rough", atlas.scale(key), seed, n)
    rn = nor_vec(crop("rubberized_track", "nor", atlas.scale(key), seed, n))
    v = fbm(n, seed + 1, 5)
    alb = tint((46, 45, 46), 0.92 + 0.14 * v)
    bloom = ss(0.5, 0.85, fbm(n, seed + 2, 4)) * 0.55
    alb = lerp(alb, tint((98, 92, 84), np.ones((n, n), np.float32)), bloom)
    c1 = np.abs(noise(n, 22, seed + 3) - 0.5)
    c2 = np.abs(noise(n, 48, seed + 4) - 0.5)
    crack = np.maximum(1 - ss(0.0, 0.012, c1), (1 - ss(0.0, 0.008, c2)) * 0.7) * ss(0.35, 0.65, fbm(n, seed + 5, 3))
    alb = lerp(alb, tint((26, 26, 26), np.ones((n, n), np.float32)), crack * 0.8)
    sc = stretch(noise(n, 50, seed + 6), 10, 1)
    scuff = ss(q(sc, 0.9), q(sc, 0.97), sc)
    alb = lerp(alb, tint((104, 102, 100), np.ones((n, n), np.float32)), scuff * 0.6)
    salt = ss(0.7, 0.9, fbm(n, seed + 7, 8)) * 0.35
    alb = lerp(alb, tint((150, 148, 142), np.ones((n, n), np.float32)), salt)
    h = -crack * 0.5 - scuff * 0.15
    nor = ndetail(nor_from_h(h, 4.0), rn, 0.4)
    rgh = 0.8 + 0.08 * rr + bloom * 0.08 + scuff * 0.05
    if tread:
        x = np.arange(n) / n
        blocks = (np.sin(2 * np.pi * 6 * x)[None, :] > -0.3) & (np.sin(2 * np.pi * 4 * x + 1.0)[:, None] > -0.5)
        groove = (np.abs(((np.arange(n) / n * 3) % 1) - 0.5) < 0.06)[None, :]
        bh = blur(blocks.astype(np.float32) * (1 - groove), 8) * 0.6
        nor = ndetail(nor_from_h(bh, 6.0), nor, 1.0)
        grit = (1 - bh / 0.6) * ss(0.4, 0.7, fbm(n, seed + 8, 12))
        alb = lerp(alb, alb * 0.65, 1 - bh / 0.6)
        alb = lerp(alb, tint((92, 82, 66), np.ones((n, n), np.float32)), grit * 0.5)
        worn = bh / 0.6 * ss(0.4, 0.7, fbm(n, seed + 9, 4))
        alb = lerp(alb, tint((62, 61, 60), np.ones((n, n), np.float32)), worn * 0.4)
        rgh = rgh - worn * 0.1
    return {"ALB": alb, "NOR": nor, "RGH": np.clip(rgh, 0, 1), "MET": np.zeros((n, n), np.float32)}


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
    """Alpha net tile: diamond mesh of round knotted twine, `meshes` diamonds per tile along each diagonal, twine
    `twine` of the mesh period wide, a slight periodic wobble so the mesh is not machine-perfect, per-mesh fade."""
    n = w
    u, v = np.meshgrid((np.arange(n) + 0.5) / n, (np.arange(n) + 0.5) / n)
    wu = u + (noise(n, 6, seed + 1) - 0.5) * 0.35 / meshes + (noise(n, 24, seed + 2) - 0.5) * 0.08 / meshes
    wv = v + (noise(n, 6, seed + 3) - 0.5) * 0.35 / meshes + (noise(n, 24, seed + 4) - 0.5) * 0.08 / meshes
    a1, a2 = (wu + wv) * meshes, (wu - wv) * meshes
    e1 = np.abs(a1 - np.round(a1))
    e2 = np.abs(a2 - np.round(a2))
    tw = twine / 2
    t1 = np.clip(1 - e1 / tw, 0, 1)
    t2 = np.clip(1 - e2 / tw, 0, 1)
    h = np.maximum(np.sqrt(t1), np.sqrt(t2))
    knot = np.clip(1 - np.hypot(e1, e2) / (tw * 2.2), 0, 1)
    h = np.maximum(h, np.sqrt(knot) * 1.15)
    lay = 0.85 + 0.15 * np.cos(2 * np.pi * (a1 + a2) * 4)       # twisted-twine striation along the bars
    alpha = ss(0.08, 0.32, h)
    cell = (np.floor(a1) * 7.3 + np.floor(a2) * 3.1) % 1.0
    var = fbm(n, seed, 4)
    shade = (0.45 + 0.55 * np.clip(h, 0, 1)) * lay * (0.9 + 0.2 * var) * (0.94 + 0.12 * cell)
    alb = np.maximum(tint(rgb, shade), 30)
    rgh = np.clip(0.6 + 0.15 * (1 - h), 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(h * lay, 5.0), "RGH": rgh, "MET": np.zeros((n, n), np.float32), "A": alpha}


# ---------------------------------------------------------------- HP2a-fix decals (fit regions: U round, V along)
def _uv(w, h):
    return np.meshgrid((np.arange(w) + 0.5) / w, 1 - (np.arange(h) + 0.5) / h)


def f_pvc(w, h, seed, rgb, ball=False):
    """PVC fender body decal: orange-peel moulding, two mould seams (cylinders), UV chalking, black rub scuffs on the
    working side, scratches, grime runs from the top eye, green-brown waterline film below an irregular tide line.
    Dry roughness ~0.55-0.7 (weathered vinyl); _Wet drops it to ~0.2."""
    u, v = _uv(w, h)
    one = np.ones((h, w), np.float32)
    var = rfbm(w, h, seed, 4)
    alb = tint(rgb, 0.93 + 0.1 * var)
    chalk = ss(0.4, 0.8, rfbm(w, h, seed + 1, 3)) * 0.3
    alb = lerp(alb, alb * 0.72 + 62, chalk)
    tide = (0.14 if ball else 0.2) + 0.035 * (rnoise(w, h, 5, seed + 2) - 0.5) * 2 + 0.012 * (rnoise(w, h, 24, seed + 3) - 0.5)
    below = ss(tide + 0.015, tide - 0.02, v)
    film = below * (0.55 + 0.4 * rfbm(w, h, seed + 4, 6))
    algae = lerp(tint((88, 98, 62), one), tint((104, 86, 60), one), ss(0.3, 0.7, rfbm(w, h, seed + 5, 3)))
    alb = lerp(alb, alb * 0.35 + algae * 0.65, film)
    band = np.exp(-((v - tide) / 0.01) ** 2) * (0.5 + 0.5 * rnoise(w, h, 30, seed + 6))
    alb = lerp(alb, tint((84, 70, 50), one), band * 0.6)
    runs = stretch(rnoise(w, h, 40, seed + 7), 1, 14) if w == h else np.asarray(
        Image.fromarray(stretch(noise(max(w, h), 40, seed + 7), 1, 14), "F").resize((w, h)), np.float32)
    runs = ss(0.62, 0.85, runs) * ss(0.35, 0.95, v) * 0.35
    alb = lerp(alb, alb * 0.6 + tint((70, 62, 50), one) * 0.25, runs)
    side = np.exp(-((((u - 0.27 + 0.5) % 1.0) - 0.5) / 0.14) ** 2)
    rubn = np.asarray(Image.fromarray(noise(max(w, h), 64, seed + 8), "F").resize((max(2, w // 12), h)).resize((w, h), Image.BICUBIC), np.float32)
    rub = ss(0.6, 0.85, rubn) * side * ss(tide, tide + 0.12, v) * ss(1.0, 0.85, v)
    alb = lerp(alb, tint((46, 46, 46), one), rub * 0.75)
    scr = np.asarray(Image.fromarray(noise(max(w, h), 90, seed + 9), "F").resize((max(2, w // 20), max(2, h // 3))).resize((w, h), Image.BICUBIC), np.float32)
    scratch = ss(0.8, 0.9, scr) * (0.4 + 0.6 * side)
    alb = lerp(alb, alb * 0.82 + 34, scratch * 0.4)
    seam = np.zeros((h, w), np.float32)
    if not ball:
        for uc in (0.25, 0.75):
            seam += np.exp(-((u - uc) / 0.0035) ** 2)
        alb = lerp(alb, alb * 0.9 + 20, seam * 0.4)
    else:  # handling grime round the neck
        alb = lerp(alb, alb * 0.6, ss(0.88, 0.99, v) * 0.6)
    peel = rnoise(w, h, max(w, h) // 6, seed + 10)
    hgt = peel * 0.12 + seam * 0.7 - rub * 0.05 - scratch * 0.15 + var * 0.1
    rgh = np.clip(0.55 + chalk * 0.35 + film * 0.2 + rub * 0.08 + scratch * 0.08 + 0.04 * (peel - 0.5), 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(hgt, 3.0), "RGH": rgh, "MET": np.zeros((h, w), np.float32)}


def f_ring(w, h, seed):
    """SOLAS ring decal: U round the ring (tapes at 45 / 135 / 225 / 315 degrees, 50 mm wide, wrapping right round
    the section), V round the tube section. Orange-peel shell, UV chalking, grime; tape micro-prism, raised edges,
    dirty edges and a lifted corner."""
    u, v = _uv(w, h)
    one = np.ones((h, w), np.float32)
    var = rfbm(w, h, seed, 4)
    alb = tint((222, 92, 32), 0.94 + 0.08 * var)
    chalk = ss(0.45, 0.85, rfbm(w, h, seed + 1, 3)) * 0.3
    alb = lerp(alb, alb * 0.75 + 52, chalk)
    grime = ss(0.5, 0.85, rfbm(w, h, seed + 2, 6)) * (0.25 + 0.35 * ss(0.3, 0.5, np.abs(v - 0.5) * -1 + 0.8))
    alb = lerp(alb, alb * 0.55 + tint((50, 44, 36), one) * 0.2, grime * 0.6)
    hw = 0.05 / (2 * math.pi * 0.2975) / 2
    tape = np.zeros((h, w), np.float32)
    edge = np.zeros((h, w), np.float32)
    wob = (rnoise(w, h, 30, seed + 3) - 0.5) * 0.0015
    for k in range(4):
        dc = np.abs(((u - (2 * k + 1) / 8 + 0.5) % 1.0) - 0.5) + wob
        tape = np.maximum(tape, ss(hw + 0.0008, hw - 0.0008, dc))
        edge = np.maximum(edge, np.exp(-((dc - hw) / 0.0012) ** 2))
    lift = ss(0.86, 0.95, rnoise(w, h, 8, seed + 4)) * edge
    xx, yy = np.meshgrid(np.arange(w), np.arange(h))
    cs = 5.0
    prism = (np.cos(2 * np.pi * xx / cs) + np.cos(2 * np.pi * (xx * 0.5 + yy * 0.866) / cs) + np.cos(2 * np.pi * (xx * 0.5 - yy * 0.866) / cs))
    prism = ss(-1.0, 2.0, prism).astype(np.float32)
    talb = tint((214, 214, 208), 0.95 + 0.04 * prism + 0.03 * var)
    tdirt = ss(0.55, 0.85, rfbm(w, h, seed + 5, 6)) * 0.3 + edge * 0.35
    talb = lerp(talb, talb * 0.62 + 10, np.clip(tdirt, 0, 1))
    alb = lerp(alb, talb, tape)
    alb = lerp(alb, alb * 0.7, lift)
    peel = rnoise(w, h, max(w, h) // 8, seed + 6)
    hgt = peel * 0.15 * (1 - tape) + tape * 0.35 + prism * 0.04 * tape + lift * 0.3
    rgh = np.clip(lerp(0.52 + chalk * 0.3 + grime * 0.15, 0.24 + tdirt * 0.3, tape), 0, 1)
    return {"ALB": alb, "NOR": nor_from_h(hgt, 3.0), "RGH": rgh, "MET": np.zeros((h, w), np.float32)}


FITS = {"FenderWhite": lambda w, h, s: f_pvc(w, h, s, (210, 210, 204)),
        "FenderNavy": lambda w, h, s: f_pvc(w, h, s, (50, 60, 86)),
        "BallFit": lambda w, h, s: f_pvc(w, h, s, (206, 90, 38), ball=True),
        "RingFit": lambda w, h, s: f_ring(w, h, s)}


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
    "RopeBuff": lambda n, s: r_rope(n, s, (198, 190, 170), "three_strand", 0.72, dirt=0.35, contrast=0.78, strength=12.0),
    "RopeBraid": lambda n, s: r_rope(n, s, (196, 194, 184), "braid", 0.66, dirt=0.45),
    "RopeThrow": lambda n, s: r_rope(n, s, (214, 176, 52), "braid", 0.55),
    "RopeBlack": lambda n, s: r_rope(n, s, (52, 52, 54), "three_strand", 0.62, dirt=0.1),
    "PVCWhite": lambda n, s: r_plastic(n, s, (206, 206, 200), 0.55, scuff=0.45, algae=0.1),
    "PVCNavy": lambda n, s: r_plastic(n, s, (52, 62, 86), 0.55, scuff=0.3, algae=0.1),
    "BallOrange": lambda n, s: r_plastic(n, s, (200, 90, 40), 0.58, scuff=0.35, algae=0.15),
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
    for i, (rgb, meshes) in enumerate((((60, 88, 62), 9), ((72, 104, 74), 11), ((190, 104, 50), 11), ((76, 108, 78), 13))):
        m = r_net(n, seed + 11 * i, rgb, meshes, 0.16)
        m = {k: np.roll(np.roll(v, 37 * i, 0), 53 * i, 1) for k, v in m.items()}
        a = m["A"] if i != 2 else m["A"] * ss(0.55, 0.65, fbm(n, seed + 3, 3))
        depth = 0.55 + 0.15 * i
        alb = lerp(alb, m["ALB"] * depth, a)
        h = np.maximum(h, a * (0.4 + 0.2 * i))
        rgh = lerp(rgh, m["RGH"], a)
    return {"ALB": np.maximum(alb, 30), "NOR": nor_from_h(h, 3.0), "RGH": rgh, "MET": np.zeros((n, n), np.float32)}
NETS = {"NetGreen": ((72, 104, 74), 16, 0.16), "NetBlue": ((70, 92, 122), 10, 0.15),
        "NetOrange": ((198, 110, 52), 16, 0.16), "NetBlack": ((54, 56, 56), 10, 0.15)}


def wet(m, key):
    """_Wet: darker and glossier; porous rope / nets darker still, metal barely changes."""
    porous = key.startswith(("Rope", "Net")) or key == "NetDense" or key in ("Concrete", "IronRust", "Chain", "Rubber", "Tread", "PotBase")
    plastic = key.startswith(("Fender", "Ball", "PVC", "Fish")) or key in ("RingFit", "SOLAS", "Float", "PotCoat")
    metal = m["MET"]
    dk = 0.62 if porous else (0.8 if plastic else 0.74)
    k = (dk + (1 - dk) * 0.5 * metal)
    alb = m["ALB"] * (k[..., None] if np.ndim(k) == 2 else k)
    alb = np.maximum(alb, 26)
    if plastic:          # a water film on non-porous plastic: near-mirror wet sheen
        rgh = np.clip(m["RGH"] * 0.3 + 0.04, 0.08, 1)
    else:
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
        if key in FITS:
            m = FITS[key](w, h, seed)
        elif r[4] == "fit":
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
