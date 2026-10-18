"""R1a street atlas T_Street_Main_* (system python3 + numpy + Pillow; no heavy slot, no AI images).

    python3 art/source/roads/streettex.py

Regions (street_layout.REGIONS) are filled from CC0 Poly Haven scans (rusty_painted_metal for the paint breakup and rust,
fine_grained_wood for the slats, metal_plate for galvanised steel) plus procedural masks: orange-peel paint, chips with
rust, road-splash dirt and salt bloom on the absz regions (fading up to h), an invented column ID plate, the bin's muted
gold LITTER band, the bollard's retroreflective band and the LED lantern lens (3 x 8 LED optics in a frosted diffuser).
Master 2048 -> art/source/roads/_street/textures/; shipped 1024 copies in assets/textures/<Asset>/ for every furniture
asset (identical bytes, one upload; gen_asset_ids maps each asset to the same ids).
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import street_layout as SL  # noqa: E402
import texlib as T  # noqa: E402

M = 2048
F32 = np.float32
MASTER_DIR = os.path.join(HERE, "_street/textures")
STAGE = os.path.join(T.GAME, "build/roads/street")
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

_scans = {}


def scan(pid):
    if pid not in _scans:
        _scans[pid] = T.load(T.fetch(pid))
    return _scans[pid]


def region_px(asset, region):
    c = SL.CELLS[asset]
    r = SL.REGIONS[asset][region][0]
    cw, ch = c[2] - c[0], c[3] - c[1]
    u0, v0, u1, v1 = c[0] + r[0] * cw, c[1] + r[1] * ch, c[0] + r[2] * cw, c[1] + r[3] * ch
    x0, x1 = int(round(u0 * M)), int(round(u1 * M))
    y0, y1 = int(round((1 - v1) * M)), int(round((1 - v0) * M))
    return x0, y0, x1, y1


def orange_peel(hw, strength, ppm, seed):
    return T.height_normal((T.noise(hw, max(4, hw[1] // 10), seed, 2) - 0.5) * 0.00012 * strength, 1.0, ppm)


def paint(hw, tile_m, seed, base=(38, 42, 40), absz_h=None, bloom=0.0, scuffs=0.0):
    """Black-painted iron / steel: scan breakup, chips to dark primer and rust, orange peel; absz adds splash and salt."""
    h, w = hw
    sa, sr, sn, sd = scan("rusty_painted_metal")
    reps = (max(1, round(tile_m[0] / 0.55)), max(1, round(tile_m[1] / 0.55)) if absz_h is None else 1)
    a = T.tile_to(sa, (w / reps[0], h / reps[1]), hw)
    y = T.luma(a)
    redness = np.clip((a[..., 0] - a[..., 2]) / 80.0, 0, 1)
    var = (y - y.mean()) / (y.std() + 1e-6)
    out = np.dstack([np.full(hw, c, F32) for c in base]) * (1 + 0.07 * var[..., None])
    ppm = w / tile_m[0]
    wear = T.noise(hw, 9, seed, 4)
    chips = T.sstep(0.80, 0.86, wear) * (0.4 + 0.6 * redness)
    primer = np.dstack([np.full(hw, c, F32) for c in (72, 66, 60)])
    rust = np.dstack([96 + 20 * var, 64 + 10 * var, 46 + 6 * var]).astype(F32)
    out = T.blend(out, primer, chips * 0.7)
    rust_m = chips * T.sstep(0.5, 0.8, T.noise(hw, 30, seed + 1, 2))
    out = T.blend(out, rust, rust_m)
    rgh = 0.42 + 0.06 * var + chips * 0.3 + rust_m * 0.2
    n = orange_peel(hw, 1.0, ppm, seed + 2)
    n = T.combine_normals(n, T.height_normal(-chips * 0.00025, 1.0, ppm))
    if absz_h is not None:
        z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * absz_h * np.ones((1, w), F32)
        nz = T.noise(hw, 8, seed + 3, 3)
        splash = np.clip(np.exp(-z / 0.14) * (0.7 + 0.6 * nz) - 0.1, 0, 1)
        dirt = np.dstack([92 + 14 * nz, 86 + 10 * nz, 76 + 8 * nz]).astype(F32)
        out = T.blend(out, dirt, splash * 0.8)
        salt = np.exp(-z / 0.3) * T.sstep(0.68, 0.8, T.noise(hw, 40, seed + 4, 2))
        out = T.blend(out, np.dstack([np.full(hw, c, F32) for c in (150, 150, 146)]), salt * 0.45)
        rgh = rgh + splash * 0.4 + salt * 0.2
        n = T.flatten_normal(n, splash * 0.5)
    # rain run-off streaks, running down the image (= down the part); noise aniso (x, small y) is smooth along V
    streak = T.noise(hw, 6, seed + 5, 3, aniso=(1.0, 0.12))
    out = out * (1 + 0.10 * (streak[..., None] - 0.5))
    if bloom > 0:   # rust bloom: blistered paint lifting round rust cores, orange halo, rust run-off running down
        b = T.noise(hw, 10, seed + 6, 4)
        core = T.sstep(0.70, 0.78, b) * bloom
        halo = np.clip(T.sstep(0.58, 0.74, b) * (0.55 + 0.45 * T.noise(hw, 70, seed + 7, 2)), 0, 1) * bloom
        run = halo.copy()
        step = max(1, h // 90)
        for i in range(1, 28):
            run = np.maximum(run, np.roll(halo, i * step, 0) * (0.93 ** i))
        run = run * T.sstep(0.45, 0.7, T.noise(hw, 30, seed + 8, 2, aniso=(1.0, 0.08)))
        orange = np.dstack([128 + 18 * var, 70 + 8 * var, 38 + 4 * var]).astype(F32)
        brown = np.dstack([78 + 10 * var, 46 + 6 * var, 30 + 3 * var]).astype(F32)
        out = T.blend(out, orange, np.clip(halo * 0.75 + run * 0.45, 0, 1))
        out = T.blend(out, brown, core)
        rgh = rgh + halo * 0.3 + core * 0.2
        n = T.combine_normals(n, T.height_normal((core * 0.5 + T.sstep(0.6, 0.66, b) * 0.5) * 0.0004 * bloom
                                                 * (0.6 + 0.4 * T.noise(hw, 90, seed + 9, 2)), 1.0, ppm))
    if scuffs > 0:  # scratches and kick scuffs through to primer and bright steel; denser low down
        sc = T.noise(hw, 40, seed + 10, 2, aniso=(0.12, 1.0))       # smooth along U: horizontal strokes
        line = (1 - T.sstep(0.0, 0.035, np.abs(sc - 0.5))) * T.sstep(0.55, 0.75, T.noise(hw, 5, seed + 11, 3))
        sc2 = T.noise(hw, 70, seed + 12, 2, aniso=(0.3, 1.0))
        line2 = (1 - T.sstep(0.0, 0.02, np.abs(sc2 - 0.5))) * T.sstep(0.5, 0.7, T.noise(hw, 7, seed + 13, 3))
        if absz_h is not None:
            zz = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * np.ones((1, w), F32)
            line = line * (0.5 + 1.0 * (1 - zz))
        m = np.clip((line + line2 * 0.7) * scuffs, 0, 1)
        deep = m * T.sstep(0.5, 0.8, T.noise(hw, 60, seed + 14, 2))
        out = T.blend(out, np.dstack([np.full(hw, c, F32) for c in (96, 92, 86)]), m * 0.8)
        out = T.blend(out, np.dstack([np.full(hw, c, F32) for c in (150, 148, 142)]), deep * 0.6)
        rgh = rgh + m * 0.15 - deep * 0.1
        n = T.combine_normals(n, T.height_normal(-m * 0.00012, 1.0, ppm))
    return out, np.clip(rgh, 0.3, 0.95), n, np.zeros(hw, F32)


def powder_grey(hw, tile_m, seed):
    a, r, n, m = paint(hw, tile_m, seed, base=(80, 84, 88))
    return a, np.clip(r + 0.04, 0.3, 0.9), n, m


def galv(hw, tile_m, seed, dark=False):
    h, w = hw
    sa, sr, sn, sd = scan("metal_plate")
    a = T.tile_to(sa, (w / max(1, round(tile_m[0] / 0.5)), h), hw)
    y = T.luma(a)
    var = (y - y.mean()) / (y.std() + 1e-6)
    base = 186 if dark else 204
    spang = T.noise(hw, max(6, w // 24), seed, 2)               # galvanised spangle
    v = base + 6 * var + 8 * (spang - 0.5)
    out = np.dstack([v, v, v * 1.01]).astype(F32)
    rgh = 0.42 + (0.18 if dark else 0.0) + 0.06 * var + 0.08 * (spang - 0.5)
    n = T.height_normal((spang - 0.5) * 0.00005, 1.0, w / tile_m[0])
    return np.clip(out, 182, 245), np.clip(rgh, 0.25, 0.85), n, np.ones(hw, F32)


def wood(hw, tile_m, seed):
    """Weathered teak / iroko slats: fine_grained_wood scan for figure, desaturated after grading (grade's contrast gain
    scales chroma), a straight growth-ring grain along U (the slat length) with raised-grain relief, silver weathering
    and checks that follow the grain (noise aniso small x = long along U)."""
    h, w = hw
    sa, sr, sn, sd = scan("fine_grained_wood")
    gx = np.abs(np.diff(T.luma(sa), axis=1)).mean()
    gy = np.abs(np.diff(T.luma(sa), axis=0)).mean()
    if gx > gy:   # grain runs vertically in the scan: rotate so it runs along U (the slat length)
        sa, sr = np.rot90(sa).copy(), np.rot90(sr).copy()
        sn = np.rot90(sn).copy()
        sn = np.dstack([-sn[..., 1], sn[..., 0], sn[..., 2]])
    tp = (w / max(1, round(tile_m[0] / 0.6)), h / max(1, round(tile_m[1] / 0.6)))
    a = T.tile_to(sa, tp, hw)
    n = T.tile_to(sn, tp, hw)
    n = n / np.linalg.norm(n, axis=2, keepdims=True)
    ppm = w / tile_m[0]
    a = T.desat(T.grade(a, 100, 22), 0.82, tint=(1.07, 1.0, 0.89))         # grey-brown teak
    # growth rings: lines along U, spacing 5 to 9 mm, wandering with a low-frequency warp
    yy = np.arange(h, dtype=F32)[:, None] * np.ones((1, w), F32) / ppm
    warp = (T.noise(hw, 3, seed + 2, 3, aniso=(0.25, 1.0)) - 0.5) * 0.05
    ph = (yy + warp) / 0.0068 + (T.noise(hw, 8, seed + 3, 2, aniso=(0.2, 1.0)) - 0.5) * 3
    ring = np.abs(np.sin(np.pi * ph)) ** 3                                   # latewood lines
    a = a * (1 - 0.20 * ring[..., None])
    fib = T.noise(hw, 90, seed + 4, 2, aniso=(0.05, 1.0))                   # open-pore fibre streaks
    a = a * (1 + 0.12 * (fib[..., None] - 0.5))
    grey = T.noise(hw, 5, seed, 3, aniso=(0.25, 1.0))
    silver = T.desat(T.grade(a, 124, 20), 0.95, tint=(1.0, 1.0, 0.98))
    a = T.blend(a, silver, T.sstep(0.30, 0.70, grey) * 0.55)                 # weathered silver-grey, along the grain
    checks = T.sstep(0.84, 0.92, T.noise(hw, 40, seed + 1, 2, aniso=(0.06, 1.0)))
    a = a * (1 - 0.40 * checks[..., None])                                   # surface checks / splits along the grain
    dirt = T.sstep(0.6, 0.85, T.noise(hw, 12, seed + 5, 3))
    a = a * (1 - 0.12 * dirt[..., None])
    rgh = 0.74 + 0.08 * grey + 0.1 * checks - 0.05 * ring
    n = T.combine_normals(T.boost_normal(n, 0.6), T.height_normal(ring * 0.00025 - checks * 0.0005, 1.0, ppm))
    return a, np.clip(rgh, 0.45, 0.95), n, np.zeros(hw, F32)


def text_layer(hw, items, font_px):
    img = Image.new("L", (hw[1], hw[0]), 0)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, font_px)
    for (x, y, s) in items:
        bb = d.textbbox((0, 0), s, font=f)
        d.text((x - (bb[2] - bb[0]) / 2 - bb[0], y - (bb[3] - bb[1]) / 2 - bb[1]), s, fill=255, font=f)
    return np.asarray(img, dtype=F32) / 255.0


def id_plate(hw, seed):
    h, w = hw
    a = np.dstack([np.full(hw, c, F32) for c in (222, 222, 216)])
    txt = text_layer(hw, [(w / 2, h * 0.52, "PH 23")], int(h * 0.55))
    border = np.zeros(hw, F32)
    b = max(2, h // 14)
    border[:b], border[-b:], border[:, :b], border[:, -b:] = 1, 1, 1, 1
    ink = np.clip(txt + border * 0.9, 0, 1)
    a = T.blend(a, np.dstack([np.full(hw, 34, F32)] * 3), ink)
    a = a * (1 - 0.15 * T.noise(hw, 6, seed, 3)[..., None])
    rgh = 0.45 + 0.1 * ink
    n = T.height_normal(ink * 0.0003, 1.0, w / 0.10)
    return a, rgh, n, np.zeros(hw, F32)


def gold_band(hw, seed):
    h, w = hw
    a = np.dstack([np.full(hw, c, F32) for c in (168, 142, 98)])
    a = a * (1 + 0.06 * (T.noise(hw, 20, seed, 3)[..., None] - 0.5))
    # the band region wraps half the circumference (0.685 m over w px, 0.10 m over h px): text widened to true aspect
    sx = (0.10 / h) / (0.685 / w)
    wide = text_layer((h, int(w / sx)), [(w / sx * 0.5, h * 0.5, "L I T T E R")], int(h * 0.6))
    txt = np.asarray(Image.fromarray(wide, "F").resize((w, h), Image.BICUBIC), dtype=F32).clip(0, 1)
    lines = np.zeros(hw, F32)
    k = max(2, h // 16)
    lines[:k], lines[-k:] = 1, 1
    ink = np.clip(txt + lines, 0, 1)
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (38, 42, 40)]), ink)
    wear = T.sstep(0.8, 0.88, T.noise(hw, 50, seed + 1, 2))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (72, 66, 60)]), wear * 0.6)
    rgh = 0.45 + 0.05 * ink + wear * 0.3
    n = T.height_normal(ink * 0.0002, 1.0, w / 0.685)
    return a, rgh, n, np.zeros(hw, F32)


def reflective_band(hw, seed):
    h, w = hw
    a = np.dstack([np.full(hw, c, F32) for c in (224, 224, 218)])
    z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * np.ones((1, w), F32)
    dirt = np.clip((0.4 - z) * 1.5, 0, 1) * T.noise(hw, 10, seed, 3)
    a = a * (1 - 0.25 * dirt[..., None])
    scuff = T.sstep(0.82, 0.9, T.noise(hw, 30, seed + 1, 2))
    a = T.blend(a, np.dstack([np.full(hw, 60, F32)] * 3), scuff * 0.5)
    hexes = (np.sin(np.arange(w)[None, :] * 0.9) * np.sin(np.arange(h)[:, None] * 0.9)).astype(F32)
    n = T.height_normal(hexes * 0.00001, 1.0, w / 0.66)
    rgh = 0.32 + 0.3 * scuff + 0.2 * dirt
    return a, rgh, n, np.zeros(hw, F32)


def led_lens(hw, seed):
    h, w = hw
    a = np.dstack([np.full(hw, c, F32) for c in (226, 220, 204)])
    yy, xx = np.mgrid[0:h, 0:w].astype(F32)
    cols, rows = 8, 3
    px, py = w / cols, h / rows
    dx = (xx % px) - px / 2
    dy = (yy % py) - py / 2
    r = np.sqrt(dx * dx + dy * dy) / (min(px, py) * 0.38)
    optic = np.clip(1 - r, 0, 1)
    ring = T.sstep(0.85, 0.95, r) * (1 - T.sstep(1.0, 1.1, r))
    a = a * (1 + 0.05 * optic[..., None]) * (1 - 0.18 * ring[..., None])
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    frame = 1 - T.sstep(2, 6, edge)
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (80, 84, 88)]), frame)
    rgh = 0.22 + 0.1 * ring + 0.3 * frame
    n = T.height_normal(np.sqrt(np.clip(1 - r * r, 0, 1)) * 0.0012, 1.0, w / 0.46)
    return np.minimum(a, 238), rgh, n, np.zeros(hw, F32)


def build():
    alb = np.full((M, M, 3), 128.0, F32)
    rgh = np.full((M, M), 0.8, F32)
    nor = np.dstack([np.zeros((M, M)), np.zeros((M, M)), np.ones((M, M))]).astype(F32)
    met = np.zeros((M, M), F32)
    wet_dark = np.full((M, M), 0.26, F32)
    seed = 100
    for asset, regs in SL.REGIONS.items():
        for region, (rect, kind, mat, par) in regs.items():
            x0, y0, x1, y1 = region_px(asset, region)
            hw = (y1 - y0, x1 - x0)
            seed += 7
            if mat == "paint_black":
                res = paint(hw, (par[0], par[1]), seed, absz_h=par[1] if kind == "absz" else None,
                            bloom={"M_Road_Bench": 1.0, "M_Road_Bin": 0.35}.get(asset, 0.0),
                            scuffs={"M_Road_Bin": 1.0, "M_Road_Bollard": 0.4}.get(asset, 0.0))
            elif mat == "powder_grey":
                res = powder_grey(hw, par, seed)
            elif mat in ("galv", "galv_dark"):
                res = galv(hw, par, seed, dark=(mat == "galv_dark"))
            elif mat == "wood_slat":
                res = wood(hw, par, seed)
            elif mat == "id_plate":
                res = id_plate(hw, seed)
            elif mat == "gold_band":
                res = gold_band(hw, seed)
            elif mat == "reflective_band":
                res = reflective_band(hw, seed)
            elif mat == "led_lens":
                res = led_lens(hw, seed)
            a, r, n, m = res
            alb[y0:y1, x0:x1] = a
            rgh[y0:y1, x0:x1] = r
            nor[y0:y1, x0:x1] = n
            met[y0:y1, x0:x1] = m
            if m.max() > 0.5:
                wet_dark[y0:y1, x0:x1] = 0.06
    wa, wr = T.wet(alb, rgh)
    wa = alb * (1 - wet_dark[..., None]) + (wa - alb * 0.74) * (wet_dark[..., None] / 0.26)
    wa = np.where(met[..., None] > 0.5, np.maximum(alb * 0.94, 182), wa)
    alb = np.where(met[..., None] > 0.5, alb, np.clip(alb, 26, 236))
    wa = np.where(met[..., None] > 0.5, wa, np.clip(wa, 22, 236))
    stem = SL.ATLAS_PREFIX
    T.save_set(STAGE, stem, alb, np.clip(rgh, 0.05, 1), nor, met=met, size=1024, wet_maps=(wa, wr), master_dir=MASTER_DIR)
    for asset in SL.CELLS:
        d = os.path.join(T.GAME, "assets/textures", asset)
        os.makedirs(d, exist_ok=True)
        for f in os.listdir(STAGE):
            shutil.copyfile(os.path.join(STAGE, f), os.path.join(d, f))
    print("street atlas written:", sorted(os.listdir(STAGE)))


if __name__ == "__main__":
    build()
