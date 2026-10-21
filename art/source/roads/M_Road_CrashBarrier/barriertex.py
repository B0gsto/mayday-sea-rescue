"""M_Road_CrashBarrier trim set T_CrashBarrier_Galv_* (docs/12 2.4; system python3 + numpy + Pillow, no heavy slot).

    python3 art/source/roads/M_Road_CrashBarrier/barriertex.py [--out DIR]

Writes assets/textures/M_Road_CrashBarrier/ (masters 2048 -> art/source/roads/M_Road_CrashBarrier/textures/), plus the
signal mask for check_textures.py. One set for the whole asset (docs/12: trim + MaterialVariant), three regions
(layout.py):

  galv  (U tiles every 1.35 m along the part, V = height above ground 0..1.15 m): hot-dip galvanised W-beam and posts
        from the metal_plate scan (Poly Haven CC0) - bright zinc spangle, rolled-in smut, road splash and grit up to
        0.35 m, a spray film that thins with height, rust bloom weeping from the fastener lines and the beam's top
        edge, dried salt bloom higher up, scuffed bright steel where helmets and loads have rubbed. Metalness is 1 on
        clean zinc and drops to ~0.15 where rust or road dirt covers the steel (rust is a dielectric and the ALB check
        wants metal pixels bright).
  plate (0.10 x 0.06 m reflector plate face): retroreflective white field with the red hazard half, glass-bead
        honeycomb, grime flecks. Signal colour: the mask covers this cell.
  dark  (nut heads, plate backs and frames): dull oiled steel, low metalness, scratched.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import texlib as T  # noqa: E402
import layout as L  # noqa: E402

F32 = np.float32
M = 2048
SHIP = 1024
MASTERS = os.path.join(HERE, "textures")
DEFAULT_OUT = os.path.join(T.GAME, "assets/textures/M_Road_CrashBarrier")
STEM = "T_CrashBarrier_Galv"

_scans = {}


def scan(pid):
    if pid not in _scans:
        _scans[pid] = T.load(T.fetch(pid))
    return _scans[pid]


def renorm(n):
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def region_px(region):
    u0, v0, u1, v1 = L.region_rect(region)
    return int(round(u0 * M)), int(round((1 - v1) * M)), int(round(u1 * M)), int(round((1 - v0) * M))


def smear_down(mask, steps, decay):
    """Vertical run-off: the mask repeated downward (down the image = down the part) with decaying strength."""
    out = mask.copy()
    for i in range(1, steps + 1):
        out = np.maximum(out, np.roll(mask, i, 0) * (decay ** i))
    return out


def streaks(hw, seed, length, wobble=0.03):
    """A soft vertical run-off field: many thin streams, each with its own strength, periodic both ways."""
    h, w = hw
    cols = T.noise((h, max(8, w // 6)), 12, seed + 1, 3)
    cols = np.asarray(Image.fromarray(cols, "F").resize((w, h), Image.BILINEAR), F32)
    thin = T.noise(hw, 34, seed + 2, 2, aniso=(0.10, 1.0))
    line = (1 - T.sstep(0.0, 0.055, np.abs(thin - 0.5))) * T.sstep(0.42, 0.72, cols)
    return smear_down(line, max(1, int(length)), 0.985)


# ---------------------------------------------------------------------------------------------------- galvanised steel
def galv(w, h, seed):
    """Hot-dip galvanised sheet: a flat mid-grey zinc surface, its spangle mottle, faint rolling smudge, then the layer
    stack of site dirt - road splash and grit at the bottom, a spray film, dried salt, rust weeping from the fastener
    lines and the beam's top edge, bright scuff scratches. No scan: a tread-plate or paint scan reads as the wrong
    surface on a 4 m beam (POL1-B)."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.TILE_U_M, h / L.GALV_H_M
    z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * L.GALV_H_M          # m above ground
    nz = T.noise(hw, 9, seed + 3, 3)
    spang = T.noise(hw, max(10, int(ppm_u * 0.05)), seed, 3)                      # zinc crystal mottle, ~5 cm
    fine = T.noise(hw, max(24, int(ppm_u * 0.012)), seed + 1, 2)                  # grain, ~1 cm
    roll = T.noise(hw, 5, seed + 2, 3, aniso=(0.22, 1.0))                         # rolling / rub smudge along the part
    v = 190.0 + 5.0 * (spang - 0.5) * 2 + 2.5 * (fine - 0.5) * 2 + 4.0 * (roll - 0.5) * 2
    a = np.dstack([v, v, v * 1.004]).astype(F32)
    rgh = 0.34 + 0.09 * (spang - 0.5) * 2 + 0.05 * (fine - 0.5) * 2
    hgt = (fine - 0.5) * 0.00005 + (spang - 0.5) * 0.00006
    n = T.height_normal_uv(hgt, ppm_u / 8.0, ppm_v / 8.0, 1.0)
    met = np.ones(hw, F32)
    # ---- weathered zinc: broad oxide patches (the dull grey-white bloom of galvanising a few winters old)
    patina = T.sstep(0.38, 0.68, T.noise(hw, 5, seed + 21, 3)) * (0.60 + 0.40 * T.noise(hw, 18, seed + 22, 3))
    a = T.blend(a, np.dstack([168 + 10 * nz, 167 + 9 * nz, 162 + 8 * nz]).astype(F32), patina * 0.9)
    rgh = rgh + 0.14 * patina
    met = met * (1 - 0.9 * T.sstep(0.35, 0.75, patina))
    hgt = hgt - patina * 0.0001
    # ---- road splash and grit on everything below about 0.4 m
    splash = np.clip(np.exp(-np.maximum(z - 0.06, 0.0) / 0.17) * (0.70 + 0.65 * nz) - 0.12, 0, 1)
    grit = T.noise(hw, max(64, int(w / 0.004)), seed + 5, 1)
    splash = np.clip(splash * (0.75 + 0.5 * grit), 0, 1)
    a = T.blend(a, np.dstack([116 + 22 * nz, 105 + 18 * nz, 90 + 14 * nz]).astype(F32), splash * 0.9)
    met = met * (1 - 0.90 * splash)
    rgh = rgh * (1 - splash) + 0.90 * splash
    hgt = hgt * (1 - splash) + splash * ((grit - 0.5) * 0.0010)
    n = T.flatten_normal(n, splash * 0.6)
    # ---- a grime film that thins with height, streaking down off every ledge
    film = np.exp(-z / 0.62) * (0.55 + 0.45 * T.noise(hw, 11, seed + 6, 3))
    drip = streaks(hw, seed + 20, 210) * (0.35 + 0.75 * np.exp(-z / 0.5))
    grime = np.clip(film * 0.70 + drip * 0.55, 0, 1)
    a = T.blend(a, np.dstack([126 + 16 * nz, 118 + 13 * nz, 106 + 10 * nz]).astype(F32), grime * 0.65)
    rgh = rgh + 0.16 * grime
    hgt = hgt - grime * (0.0002 + (grit - 0.5) * 0.0006)
    # ---- dried salt bloom (spray that has dried on the steel), fine and patchy
    salt = T.sstep(0.68, 0.84, T.noise(hw, 34, seed + 7, 3, aniso=(0.85, 1.0))) * (0.30 + 0.70 * np.exp(-z / 0.8))
    a = T.blend(a, np.dstack([206 + 5 * nz] * 2 + [200 + 4 * nz]).astype(F32), salt * 0.30)
    rgh = rgh + 0.14 * salt
    # ---- rust: bloom cores, run-off weeping along the fastener lines and the beam's top edge, surface pitting
    core = T.sstep(0.78, 0.88, T.noise(hw, 13, seed + 8, 4))
    lines = np.zeros(hw, F32)
    for x_frac, amp in ((0.000, 0.9), (0.095, 0.55), (0.053, 0.9), (0.545, 0.7), (0.72, 0.35)):
        col = int(round(x_frac * w)) % w
        band = np.exp(-((np.arange(w) - col + w / 2) % w - w / 2) ** 2 / (2 * (0.010 * w) ** 2))[None, :]
        lines = np.maximum(lines, band * amp)
    weep = smear_down(lines * (0.45 + 0.55 * T.noise(hw, 30, seed + 9, 2)), 230, 0.988)
    weep = weep * (0.5 + 0.5 * np.exp(-np.maximum(z - 0.30, 0) / 0.45))
    top_edge = np.exp(-((z - 0.71) / 0.045) ** 2) * T.sstep(0.42, 0.70, T.noise(hw, 40, seed + 10, 2, aniso=(0.25, 1.0)))
    rust = np.clip(core * (0.30 + 0.85 * np.exp(-np.maximum(z - 0.25, 0) / 0.45)) + weep * 1.05 + top_edge * 0.85, 0, 1)
    rust = rust * (0.60 + 0.40 * T.noise(hw, 70, seed + 11, 2))
    pit = T.noise(hw, max(48, int(w / 0.006)), seed + 12, 1)
    a = T.blend(a, np.dstack([172 + 22 * pit, 152 + 18 * pit, 132 + 14 * pit]).astype(F32),
                np.clip(rust * 1.7 - 0.7, 0, 1) * 0.65)                            # thinned rust halo
    a = T.blend(a, np.dstack([142 + 26 * pit + 8 * nz, 108 + 18 * pit + 6 * nz, 84 + 12 * pit + 4 * nz]).astype(F32),
                T.sstep(0.20, 0.60, rust))
    met = met * (1 - 0.90 * T.sstep(0.15, 0.45, rust))
    rgh = rgh * (1 - T.sstep(0.15, 0.5, rust)) + T.sstep(0.15, 0.5, rust) * 0.82
    hgt = hgt - T.sstep(0.1, 0.5, rust) * (pit - 0.5) * 0.0006 - T.sstep(0.25, 0.6, rust) * 0.0002
    # ---- scuffs and bright scratches: bare steel showing through (loads, helmets, grazing traffic)
    sc = T.noise(hw, 46, seed + 13, 2, aniso=(0.12, 1.0))
    line = (1 - T.sstep(0.0, 0.028, np.abs(sc - 0.5))) * T.sstep(0.52, 0.76, T.noise(hw, 6, seed + 14, 3))
    sc2 = T.noise(hw, 90, seed + 15, 2, aniso=(0.3, 1.0))
    line2 = (1 - T.sstep(0.0, 0.015, np.abs(sc2 - 0.5))) * T.sstep(0.45, 0.70, T.noise(hw, 9, seed + 16, 3))
    scuff = np.clip(line + 0.6 * line2, 0, 1) * (0.30 + 0.70 * np.exp(-np.maximum(z - 0.30, 0) / 0.55))
    deep = scuff * T.sstep(0.52, 0.82, T.noise(hw, 70, seed + 17, 2))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (214, 214, 208)]), scuff * 0.16 + deep * 0.35)
    met = np.maximum(met, T.sstep(0.3, 0.7, scuff))
    rgh = rgh * (1 - scuff * 0.5) + scuff * 0.5 * 0.28
    hgt = hgt - deep * 0.00012
    # ---- the beam's top edge and the splash line gather a dirt collar
    collar = np.exp(-((z - 0.705) / 0.05) ** 2) * (0.4 + 0.6 * nz)
    a = a * (1 - 0.09 * collar[..., None])
    rgh = rgh + 0.10 * collar
    # ---- large-scale tonal drift so a 4 m run never reads as one tile
    a = a * (1 + 0.04 * (T.noise(hw, 3, seed + 18, 2)[..., None] - 0.5))
    rgh = np.clip(rgh, 0.24, 0.94)
    n = T.combine_normals(n, T.height_normal_uv(hgt, ppm_u, ppm_v, 1.0))
    a = np.clip(a, 30, 244)
    # ---- metalness: clean zinc (bright, metal) or covered steel (dirt and rust, dielectric); the boundary is sharp so
    # the ALB check never sees a dark pixel wearing a metal mask
    met = met * T.sstep(190.0, 197.0, T.luma(a))
    return a, rgh, n, np.clip(met, 0, 1)


# ---------------------------------------------------------------------------------------------------- reflector plate
def plate(w, h, seed):
    """0.10 x 0.06 m retroreflective reflector plate: white field, red hazard half, bead honeycomb, grime."""
    hw = (h, w)
    red = np.array([186, 46, 40], F32)
    white = np.array([223, 222, 216], F32)
    a = np.broadcast_to(white, hw + (3,)).copy()
    yy, xx = np.mgrid[0:h, 0:w].astype(F32)
    a = np.where((xx < w * 0.46)[..., None], np.broadcast_to(red, hw + (3,)), a)
    # glass-bead honeycomb: the retroreflective sheeting's fine structure
    bead = (np.sin(xx * 0.55) * np.sin(yy * 0.55) + np.sin((xx + yy) * 0.31) * 0.6)
    a = a * (1 + 0.030 * bead[..., None])
    n = T.height_normal(bead * 0.00002, 1.0, w / L.PLATE_M[0])
    # grime film, heavier at the bottom edge, a few rust flecks from the fixing bolts
    dirt = 0.10 + 0.55 * T.sstep(0.25, 0.0, yy / h) * (0.5 + 0.5 * T.noise(hw, 12, seed, 3))
    a = T.blend(a, np.dstack([92 + 10 * T.noise(hw, 20, seed + 1, 2)] * 2 + [86 + 8 * T.noise(hw, 20, seed + 1, 2)]).astype(F32),
                dirt * 0.35)
    fleck = T.sstep(0.82, 0.90, T.noise(hw, 90, seed + 2, 2))
    a = T.blend(a, np.dstack([132, 96, 70]).astype(F32), fleck * 0.6)
    rgh = 0.30 + 0.35 * dirt + 0.25 * fleck
    return np.clip(a, 30, 240), np.clip(rgh, 0.2, 0.85), n, np.zeros(hw, F32)


# ---------------------------------------------------------------------------------------------------- dark fixings
def dark(w, h, seed):
    """Dull oiled steel: nut heads, plate backs and frames."""
    hw = (h, w)
    nz = T.noise(hw, 14, seed, 3)
    v = 104 + 22 * (nz - 0.5) * 2 + 6 * (T.noise(hw, 7, seed + 1, 2) - 0.5)
    a = np.dstack([v * 1.02, v * 0.99, v * 0.94]).astype(F32)
    pits = T.noise(hw, 70, seed + 2, 2)
    a = a * (1 - 0.10 * T.sstep(0.6, 0.8, pits)[..., None])
    dust = T.sstep(0.55, 0.85, T.noise(hw, 9, seed + 3, 3))
    a = T.blend(a, np.dstack([128, 118, 100]).astype(F32), dust * 0.25)
    rgh = 0.52 + 0.14 * (nz - 0.5) * 2 + 0.15 * dust
    met = 0.10 + 0.20 * (1 - dust)
    n = T.height_normal((pits - 0.5) * 0.0004, 1.0, w / 0.05)
    return np.clip(a, 30, 236), np.clip(rgh, 0.3, 0.9), n, np.clip(met, 0, 1)


# ---------------------------------------------------------------------------------------------------- sheet
def build():
    alb = np.full((M, M, 3), 128.0, F32)
    rgh = np.full((M, M), 0.8, F32)
    nor = np.dstack([np.zeros((M, M)), np.zeros((M, M)), np.ones((M, M))]).astype(F32)
    met = np.zeros((M, M), F32)
    sig = np.zeros((M, M), F32)
    seed = 300
    for region, fn in (("galv", galv), ("plate", plate), ("dark", dark)):
        x0, y0, x1, y1 = region_px(region)
        a, r, n, m = fn(x1 - x0, y1 - y0, seed)
        seed += 11
        alb[y0:y1, x0:x1] = a
        rgh[y0:y1, x0:x1] = r
        nor[y0:y1, x0:x1] = n
        met[y0:y1, x0:x1] = m
        if region == "plate":
            sig[y0:y1, x0:x1] = 1.0
    wa, wr = T.wet(alb, rgh, darken=0.24, gloss=0.30)
    wa = np.where(met[..., None] > 0.5, alb * 0.80, wa)                      # wet zinc darkens and dulls
    alb = np.where(met[..., None] > 0.5, alb, np.clip(alb, 22, 240))
    wa = np.where(met[..., None] > 0.5, wa, np.clip(wa, 20, 240))
    return alb, rgh, nor, met, wa, wr, sig


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT, help="shipping map folder (default assets/textures/M_Road_CrashBarrier)")
    args = ap.parse_args()
    alb, rgh, nor, met, wa, wr, sig = build()
    T.save_set(args.out, STEM, alb, rgh, nor, met=met, size=SHIP, wet_maps=(wa, wr), master_dir=MASTERS)
    sig_i = Image.fromarray((np.clip(sig, 0, 1) * 255).astype(np.uint8)).resize((SHIP, SHIP), Image.NEAREST)
    sig_i.point(lambda v: 255 if v > 0 else 0).save(os.path.join(HERE, "%s_signal.png" % STEM))
    print("wrote", STEM, "->", os.path.relpath(args.out, T.GAME), "masters", os.path.relpath(MASTERS, T.GAME))


if __name__ == "__main__":
    main()
