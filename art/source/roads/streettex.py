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


def paint(hw, tile_m, seed, base=(38, 42, 40), absz_h=None):
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
    # streaks running down from the top of each tile (rain run-off)
    streak = T.noise(hw, 6, seed + 5, 3, aniso=(0.12, 1.0))
    out = out * (1 + 0.10 * (streak[..., None] - 0.5))
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
    h, w = hw
    sa, sr, sn, sd = scan("fine_grained_wood")
    gx = np.abs(np.diff(T.luma(sa), axis=1)).mean()
    gy = np.abs(np.diff(T.luma(sa), axis=0)).mean()
    if gx > gy:   # grain runs vertically in the scan: rotate so it runs along U (the slat length)
        sa, sr = np.rot90(sa).copy(), np.rot90(sr).copy()
        sn = np.rot90(sn).copy()
        sn = np.dstack([-sn[..., 1], sn[..., 0], sn[..., 2]])
    a = T.tile_to(sa, (w / max(1, round(tile_m[0] / 0.6)), h / max(1, round(tile_m[1] / 0.6))), hw)
    n = T.tile_to(sn, (w / max(1, round(tile_m[0] / 0.6)), h / max(1, round(tile_m[1] / 0.6))), hw)
    n = n / np.linalg.norm(n, axis=2, keepdims=True)
    a = T.grade(a, 118, 20, tint=(1.10, 0.97, 0.84), desat=0.55)
    grey = T.noise(hw, 5, seed, 3, aniso=(4.0, 1.0))
    silver = T.grade(a, 132, 14, desat=0.9)
    a = T.blend(a, silver, T.sstep(0.35, 0.75, grey) * 0.65)      # weathered silver-grey
    checks = T.sstep(0.8, 0.9, T.noise(hw, 40, seed + 1, 2, aniso=(5.0, 1.0)))
    a = a * (1 - 0.35 * checks[..., None])                        # surface checking / splits
    rgh = 0.72 + 0.1 * grey + 0.1 * checks
    n = T.combine_normals(n, T.height_normal(-checks * 0.0004, 1.0, w / tile_m[0]))
    return a, np.clip(rgh, 0.4, 0.95), n, np.zeros(hw, F32)


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
    txt = text_layer(hw, [(w * 0.25, h * 0.5, "L I T T E R"), (w * 0.75, h * 0.5, "L I T T E R")], int(h * 0.62))
    lines = np.zeros(hw, F32)
    k = max(2, h // 16)
    lines[:k], lines[-k:] = 1, 1
    ink = np.clip(txt + lines, 0, 1)
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (38, 42, 40)]), ink)
    wear = T.sstep(0.8, 0.88, T.noise(hw, 50, seed + 1, 2))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (72, 66, 60)]), wear * 0.6)
    rgh = 0.45 + 0.05 * ink + wear * 0.3
    n = T.height_normal(ink * 0.0002, 1.0, w / 1.35)
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
                res = paint(hw, (par[0], par[1]), seed, absz_h=par[1] if kind == "absz" else None)
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
