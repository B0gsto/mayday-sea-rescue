"""M_Road_FieldGate trim set T_FieldGate_Timber_* (docs/12 2.4; system python3 + numpy + Pillow, no heavy slot).

    python3 art/source/roads/M_Road_FieldGate/gatetex.py [--out DIR]

Writes build/prod/M_Road_FieldGate/textures/M_Road_FieldGate/ (ship 1024) and masters 2048 to
art/source/roads/M_Road_FieldGate/textures/. One set for the whole asset (docs/12: trim + MaterialVariant), three
regions (layout.py):

  timber  the five-bar gate's weathered oak: the fine_grained_wood scan (CC0 Poly Haven, Rob Tuytel) rotated so the
          grain runs along U, graded to a silver-grey brown, then the coastal layers - mud splash and grit in the
          bottom 0.35 m, moss and soil at the post feet, growth rings, surface checks along the grain, rain wash down
          the V axis, silver bleaching and grey-green lichen crusts (Voronoi cells) higher up, rust weeping from the
          fittings, scuffs and saw marks.
  metal   hot-dip galvanised fittings: zinc spangle, rolled-in smut, grit, spray film, rust bloom from the fastener
          edges, scuffed bright steel (same stack as M_Road_CrashBarrier's galv region).
  dark    dull oiled steel for bolt heads, nuts and the pin shanks.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import texlib as T  # noqa: E402
import layout as L  # noqa: E402

F32 = np.float32
M = 2048
SHIP = 1024
MASTERS = os.path.join(HERE, "textures")
DEFAULT_OUT = os.path.join(T.GAME, "build/prod/M_Road_FieldGate/textures/M_Road_FieldGate")
STEM = "T_FieldGate_Timber"

_scans = {}


def scan(pid):
    if pid not in _scans:
        _scans[pid] = T.load(T.fetch(pid))
    return _scans[pid]


def region_px(region):
    u0, v0, u1, v1 = L.REGIONS[region]
    return int(round(u0 * M)), int(round((1 - v1) * M)), int(round(u1 * M)), int(round((1 - v0) * M))


def smear_down(mask, steps, decay):
    """Run-off: the mask repeated downward (down the image = down the part) with decaying strength."""
    out = mask.copy()
    for i in range(1, steps + 1):
        out = np.maximum(out, np.roll(mask, i, 0) * (decay ** i))
    return out


def streaks(hw, seed, length, thin=0.055):
    """A soft field of thin vertical streams (rain wash, rust runs), periodic both ways."""
    h, w = hw
    cols = T.noise((h, max(8, w // 6)), 12, seed + 1, 3)
    cols = np.asarray(Image.fromarray(cols, "F").resize((w, h), Image.BILINEAR), F32)
    f = T.noise(hw, 34, seed + 2, 2, aniso=(0.10, 1.0))
    line = (1 - T.sstep(0.0, thin, np.abs(f - 0.5))) * T.sstep(0.42, 0.72, cols)
    return smear_down(line, max(1, int(length)), 0.985)


# ---------------------------------------------------------------------------------------------------- weathered timber
def timber(w, h, seed):
    """Sawn oak-softwood, weathered silver, grain along U, height (mud to bleached) along V."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.TILE_U_M, h / L.GATE_H_M
    z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * L.GATE_H_M            # m above ground
    x = (np.arange(w, dtype=F32) + 0.5)[None, :] / ppm_u                             # m along U (one 1.2 m tile)
    sa, sr, sn, sd = scan("fine_grained_wood")
    sa, sr = np.rot90(sa).copy(), np.rot90(sr).copy()                               # the scan's grain runs up: along U
    sn = np.rot90(sn).copy()
    sn = np.dstack([-sn[..., 1], sn[..., 0], sn[..., 2]])
    tp = (w * 0.6 / L.TILE_U_M, h * 0.6 / L.GATE_H_M)                               # 0.6 m scan tiles
    a = T.tile_to(sa, tp, hw)
    n = T.tile_to(sn, tp, hw)
    n = n / np.linalg.norm(n, axis=2, keepdims=True)
    rgh = T.tile_to(sr, tp, hw) / 255.0
    a = T.grade(a, 112, 22)
    a = T.desat(a, 0.58, tint=(1.07, 1.0, 0.91))                                    # grey-brown, a warm undertone
    blurred = np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2)), F32)
    a = 0.55 * a + 0.45 * blurred                                                   # the scan's grain relief stays in the map
    # ---- growth rings: latewood lines along the grain, wandering, 12 to 20 mm apart
    warp = (T.noise(hw, 3, seed + 2, 3, aniso=(0.25, 1.0)) - 0.5) * 0.06
    ph = (z + warp) / 0.0155 + (T.noise(hw, 9, seed + 3, 2, aniso=(0.2, 1.0)) - 0.5) * 2.5
    ring = np.abs(np.sin(np.pi * ph)) ** 3
    a = a * (1 - 0.21 * ring[..., None])
    fib = T.noise(hw, 110, seed + 4, 2, aniso=(0.04, 1.0))                          # open-pore fibre streaks
    a = a * (1 + 0.15 * (fib[..., None] - 0.5))
    # ---- silver bleaching with height: bare board above 0.6 m, a soft transition, patchy
    sil = T.sstep(0.35, 1.15, z) * (0.45 + 0.55 * T.noise(hw, 5, seed, 3, aniso=(0.3, 1.0)))
    silver = T.desat(T.grade(a, 128, 18), 0.86, tint=(1.0, 1.0, 0.97))
    a = T.blend(a, silver, sil * 0.62)
    rgh = rgh * 0.6 + 0.30 + 0.10 * sil
    # ---- rain wash: thin dark streams down the V axis, strongest between 0.3 and 0.9 m
    wash = streaks(hw, seed + 20, 260, 0.045) * np.exp(-np.maximum(z - 0.35, 0.0) / 0.75) * 0.55
    wash = wash * (0.30 + 0.70 * T.sstep(0.35, 0.75, T.noise(hw, 7, seed + 21, 3)))
    a = T.blend(a, np.dstack([100 + 14 * fib, 92 + 12 * fib, 82 + 10 * fib]).astype(F32), wash * 0.45)
    rgh = rgh + 0.08 * wash
    # ---- surface checks and splits, long and thin along the grain, mostly low (drying cracks)
    ch = T.sstep(0.875, 0.925, T.noise(hw, 22, seed + 1, 2, aniso=(0.02, 1.0)))
    ch = ch * (0.25 + 0.75 * T.sstep(0.9, 0.1, z))
    a = a * (1 - 0.46 * ch[..., None])
    a = a * (1 + 0.10 * np.roll(ch, 3, 0)[..., None])                               # a bright lip on one side
    # ---- mud splash, grit and a buried line at the very bottom (0 to 0.4 m)
    nz = T.noise(hw, 8, seed + 5, 3)
    splash = np.clip(np.exp(-np.maximum(z - 0.05, 0.0) / 0.19) * (0.85 + 0.45 * nz) - 0.05, 0, 1)
    grit = T.noise(hw, max(64, int(ppm_u * 0.0035)), seed + 6, 1)
    splash = np.clip(splash * (0.7 + 0.6 * grit), 0, 1)
    a = T.blend(a, np.dstack([96 + 24 * nz, 82 + 18 * nz, 64 + 12 * nz]).astype(F32), splash * 0.86)
    rgh = rgh * (1 - splash) + splash * 0.93
    # ---- moss and soil at the feet (the bottom 0.22 m) plus a few lichen-green speckles up to 0.4 m
    moss_m = T.sstep(0.26, 0.03, z) * (0.35 + 0.65 * T.noise(hw, 7, seed + 7, 3))
    speck = T.sstep(0.87, 0.95, T.noise(hw, 60, seed + 8, 2)) * T.sstep(0.45, 0.05, z) * 0.7
    moss = np.clip(moss_m + speck, 0, 1)
    moss_col = np.dstack([66 + 18 * nz, 82 + 22 * nz, 50 + 14 * nz]).astype(F32)
    a = T.blend(a, moss_col, moss * 0.80)
    rgh = rgh * (1 - moss) + moss * 0.78                                            # damp, matte
    # ---- lichen: sparse grey-green crustose patches in colonies (Voronoi cells), above the splash line
    patch = T.sstep(0.44, 0.74, T.noise(hw, 10, seed + 9, 3, aniso=(0.5, 1.0)))
    f1, f2, cid = T.voronoi(x + np.zeros_like(z), z + np.zeros_like(x), 0.020, L.TILE_U_M, None, seed + 9)
    rad = 0.0030 + 0.0070 * T.hash01(cid, 3)
    cov = T.sstep(0.70, 0.97, T.hash01(cid, 11))
    lic = (T.sstep(rad, rad + 0.0015, f1) < 0.5) * cov * patch * T.sstep(0.62, 0.86, z) * (1 - T.sstep(1.30, 1.5, z))
    tone = T.hash01(cid, 7)
    pale = np.dstack([124 + 30 * tone, 130 + 30 * tone, 110 + 26 * tone]).astype(F32)
    a = T.blend(a, pale, lic * 0.30)
    rgh = rgh + 0.06 * lic
    # ---- rust weeping from the fittings: three narrow orange runs down the V axis
    rl = np.zeros(hw, F32)
    for xf, amp in ((0.06, 0.85), (0.42, 0.55), (0.71, 0.7)):
        col = int(round(xf * w)) % w
        band = np.exp(-((np.arange(w) - col + w / 2) % w - w / 2) ** 2 / (2 * (0.0025 * w) ** 2))[None, :]
        rl = np.maximum(rl, band * amp)
    rust = smear_down(rl * (0.35 + 0.65 * T.noise(hw, 30, seed + 10, 2)), 200, 0.988)
    rust = rust * np.exp(-np.maximum(z - 0.35, 0.0) / 0.7) * (1 - T.sstep(1.25, 1.45, z))
    a = T.blend(a, np.dstack([112 + 16 * nz, 80 + 12 * nz, 58 + 10 * nz]).astype(F32), np.clip(rust, 0, 1) * 0.42)
    rgh = rgh + 0.08 * np.clip(rust, 0, 1)
    # ---- scuffs and boot / bar rubs, and faint saw marks across the grain
    sc = T.noise(hw, 40, seed + 11, 2, aniso=(0.12, 1.0))
    scuff = (1 - T.sstep(0.0, 0.03, np.abs(sc - 0.5))) * T.sstep(0.55, 0.78, T.noise(hw, 6, seed + 12, 3))
    scuff = scuff * (0.3 + 0.7 * np.exp(-np.maximum(z - 0.25, 0.0) / 0.5))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (196, 194, 184)]), scuff * 0.15)
    rgh = rgh - 0.10 * scuff
    saw = 0.5 + 0.5 * np.sin(z * 2 * np.pi / 0.0042 + (T.noise(hw, 4, seed + 13, 2) - 0.5) * 3.0)
    saw = (1 - T.sstep(0.0, 0.35, np.abs(saw - 0.5))) * 0.05
    a = a * (1 - saw[..., None])
    # ---- large-scale tonal drift so a 3.6 m bar never reads as one tile, and a dirt collar low down
    a = a * (1 + 0.05 * (T.noise(hw, 3, seed + 14, 2)[..., None] - 0.5))
    rgh = np.clip(rgh + 0.05 * (T.noise(hw, 11, seed + 15, 3) - 0.5), 0.45, 0.96)
    n = T.combine_normals(T.boost_normal(n, 0.55),
                          T.height_normal_uv(ring * 0.00030 - ch * 0.0009 + (grit - 0.5) * 0.00025 * splash
                                             + moss * (nz - 0.5) * 0.0008 + lic * 0.00012 - scuff * 0.00010,
                                              ppm_u, ppm_v, 1.0))
    a = np.clip(a, 26, 240)
    return a, np.clip(rgh, 0.45, 0.96), n, np.zeros(hw, F32)


# ---------------------------------------------------------------------------------------------------- fittings
def metal(w, h, seed):
    """Hot-dip galvanised fittings: zinc spangle, smut, grit, spray film, rust bloom, scuffed bright steel."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.MET_TILE_M[0], h / L.MET_TILE_M[1]
    z = np.linspace(0.0, 1.0, h, dtype=F32)[:, None] * np.ones((1, w), F32)         # 0 at the region's bottom
    nz = T.noise(hw, 9, seed + 3, 3)
    spang = T.noise(hw, max(12, int(ppm_u * 0.045)), seed, 3)                         # zinc crystal mottle, ~4.5 cm
    fine = T.noise(hw, max(24, int(ppm_u * 0.009)), seed + 1, 2)
    roll = T.noise(hw, 5, seed + 2, 3, aniso=(0.22, 1.0))
    v = 196.0 + 5.0 * (spang - 0.5) * 2 + 3.0 * (fine - 0.5) * 2 + 4.0 * (roll - 0.5) * 2
    a = np.dstack([v, v, v * 1.004]).astype(F32)
    rgh = 0.32 + 0.09 * (spang - 0.5) * 2 + 0.05 * (fine - 0.5) * 2
    hgt = (fine - 0.5) * 0.00004 + (spang - 0.5) * 0.00005
    met = np.ones(hw, F32)
    patina = T.sstep(0.42, 0.70, T.noise(hw, 5, seed + 21, 3)) * (0.6 + 0.4 * T.noise(hw, 18, seed + 22, 3))
    a = T.blend(a, np.dstack([166 + 10 * nz, 165 + 9 * nz, 160 + 8 * nz]).astype(F32), patina * 0.85)
    rgh = rgh + 0.15 * patina
    met = met * (1 - 0.9 * T.sstep(0.35, 0.75, patina))
    grit = T.noise(hw, max(64, int(w / 0.0028)), seed + 5, 1)
    dirt = np.clip((0.55 + 0.9 * nz) * (0.35 + 0.75 * grit), 0, 1)
    a = T.blend(a, np.dstack([112 + 22 * nz, 102 + 18 * nz, 88 + 14 * nz]).astype(F32), dirt * 0.34)
    met = met * (1 - 0.85 * dirt * 0.5)
    rgh = rgh * (1 - dirt * 0.4) + dirt * 0.4 * 0.90
    film = T.noise(hw, 11, seed + 6, 3) * 0.5 + streaks(hw, seed + 26, 200) * (0.45 + 0.55 * T.noise(hw, 9, seed + 27, 3))
    a = T.blend(a, np.dstack([124 + 16 * nz, 116 + 13 * nz, 104 + 10 * nz]).astype(F32), np.clip(film, 0, 1) * 0.35)
    rgh = rgh + 0.12 * np.clip(film, 0, 1)
    core = T.sstep(0.74, 0.87, T.noise(hw, 13, seed + 8, 4))
    l2 = streaks(hw, seed + 29, 250, 0.022)
    rust = np.clip(core * 0.75 + l2 * 0.95, 0, 1) * (0.6 + 0.4 * T.noise(hw, 70, seed + 11, 2))
    pit = T.noise(hw, max(48, int(w / 0.004)), seed + 12, 1)
    a = T.blend(a, np.dstack([170 + 22 * pit, 150 + 18 * pit, 130 + 14 * pit]).astype(F32),
                np.clip(rust * 1.7 - 0.7, 0, 1) * 0.6)
    a = T.blend(a, np.dstack([140 + 26 * pit + 8 * nz, 106 + 18 * pit + 6 * nz, 82 + 12 * pit + 4 * nz]).astype(F32),
                T.sstep(0.20, 0.60, rust))
    met = met * (1 - 0.9 * T.sstep(0.15, 0.45, rust))
    rgh = rgh * (1 - T.sstep(0.15, 0.5, rust)) + T.sstep(0.15, 0.5, rust) * 0.82
    hgt = hgt - T.sstep(0.1, 0.5, rust) * (pit - 0.5) * 0.0005 - T.sstep(0.25, 0.6, rust) * 0.0002
    sc = T.noise(hw, 46, seed + 13, 2, aniso=(0.12, 1.0))
    line = (1 - T.sstep(0.0, 0.028, np.abs(sc - 0.5))) * T.sstep(0.52, 0.76, T.noise(hw, 6, seed + 14, 3))
    sc2 = T.noise(hw, 90, seed + 15, 2, aniso=(0.3, 1.0))
    line2 = (1 - T.sstep(0.0, 0.015, np.abs(sc2 - 0.5))) * T.sstep(0.45, 0.70, T.noise(hw, 9, seed + 16, 3))
    scuff = np.clip(line + 0.6 * line2, 0, 1)
    deep = scuff * T.sstep(0.52, 0.82, T.noise(hw, 70, seed + 17, 2))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (216, 216, 210)]), scuff * 0.18 + deep * 0.34)
    met = np.maximum(met, T.sstep(0.3, 0.7, scuff))
    rgh = rgh * (1 - scuff * 0.5) + scuff * 0.5 * 0.26
    hgt = hgt - deep * 0.00012
    a = a * (1 + 0.04 * (T.noise(hw, 3, seed + 18, 2)[..., None] - 0.5))
    n = T.height_normal_uv(hgt + (grit - 0.5) * 0.00012 * dirt + (spang - 0.5) * 0.00004, ppm_u, ppm_v, 1.0)
    met = met * T.sstep(176.0, 186.0, T.luma(a))   # only clean, bright zinc counts as metal (the ALB check wants it bright)
    return np.clip(a, 30, 244), np.clip(rgh, 0.22, 0.94), n, np.clip(met, 0, 1)


def dark(w, h, seed):
    """Dull oiled steel: bolt heads, nuts, pin shanks."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.DARK_TILE_M[0], h / L.DARK_TILE_M[1]
    nz = T.noise(hw, 14, seed, 3)
    v = 106 + 22 * (nz - 0.5) * 2 + 6 * (T.noise(hw, 7, seed + 1, 2) - 0.5)
    a = np.dstack([v * 1.02, v * 0.99, v * 0.94]).astype(F32)
    pits = T.noise(hw, 70, seed + 2, 2)
    a = a * (1 - 0.10 * T.sstep(0.6, 0.8, pits)[..., None])
    dust = T.sstep(0.55, 0.85, T.noise(hw, 9, seed + 3, 3))
    a = T.blend(a, np.dstack([130, 120, 102]).astype(F32), dust * 0.28)
    rust = T.sstep(0.80, 0.90, T.noise(hw, 16, seed + 4, 3))
    a = T.blend(a, np.dstack([122, 88, 64]).astype(F32), rust * 0.5)
    rgh = 0.50 + 0.14 * (nz - 0.5) * 2 + 0.15 * dust + 0.12 * rust
    bright = T.sstep(0.56, 0.62, T.noise(hw, 26, seed + 6, 3))                     # worn through to bare steel
    a = T.blend(a, np.dstack([200 + 14 * nz, 198 + 12 * nz, 192 + 10 * nz]).astype(F32), bright)
    rgh = rgh * (1 - bright * 0.6) + bright * 0.6 * 0.30
    met = np.full(hw, 0.06, F32)                                                    # oiled and painted over: dielectric
    n = T.height_normal((pits - 0.5) * 0.00032 - rust * 0.0002, 1.0, ppm_u)
    return np.clip(a, 30, 236), np.clip(rgh, 0.3, 0.9), n, np.clip(met, 0, 1)


# ---------------------------------------------------------------------------------------------------- sheet
def build():
    alb = np.full((M, M, 3), 128.0, F32)
    rgh = np.full((M, M), 0.8, F32)
    nor = np.dstack([np.zeros((M, M)), np.zeros((M, M)), np.ones((M, M))]).astype(F32)
    met = np.zeros((M, M), F32)
    seed = 520
    for region, fn in (("timber", timber), ("metal", metal), ("dark", dark)):
        x0, y0, x1, y1 = region_px(region)
        a, r, n, m = fn(x1 - x0, y1 - y0, seed)
        seed += 11
        alb[y0:y1, x0:x1] = a
        rgh[y0:y1, x0:x1] = r
        nor[y0:y1, x0:x1] = n
        met[y0:y1, x0:x1] = m
    wa, wr = T.wet(alb, rgh, darken=0.24, gloss=0.28)
    wa = T.desat(wa, 0.14)                                                          # wet() lifts saturation: keep it under the 0.45 ceiling
    wa = np.where(met[..., None] > 0.5, alb * 0.80, wa)                             # wet zinc dulls, it does not darken
    alb = np.where(met[..., None] > 0.5, alb, np.clip(alb, 22, 240))
    wa = np.where(met[..., None] > 0.5, wa, np.clip(wa, 20, 240))
    return alb, rgh, nor, met, wa, wr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT, help="shipping map folder (default build/prod/M_Road_FieldGate/...)")
    args = ap.parse_args()
    alb, rgh, nor, met, wa, wr = build()
    T.save_set(args.out, STEM, alb, rgh, nor, met=met, size=SHIP, wet_maps=(wa, wr), master_dir=MASTERS)
    print("wrote", STEM, "->", os.path.relpath(args.out, T.GAME), "masters", os.path.relpath(MASTERS, T.GAME))


if __name__ == "__main__":
    main()
