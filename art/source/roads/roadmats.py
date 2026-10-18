"""R1a road surfaces (docs/12 2.4): ribbon strip sets, tiling MaterialVariant sets and the UK markings decal set.

    python3 art/source/roads/roadmats.py            (system python3, no heavy slot; scans: texlib.fetch, Poly Haven CC0)

Writes assets/textures/M_Road_Ribbon/ at SHIP 1024 (masters 2048 in art/source/roads/M_Road_Ribbon/textures/), each with _Wet:
  Strip sets (U along the road, tiles; V across, 0 = left kerb line, 1 = right kerb line; edge grime baked in):
    T_Road_Asphalt_*   8 m x 6 m carriageway: asphalt_04 + clean_asphalt patches, tar crack sealing and joint overband,
                       wheel-track polish, oil drips, kerb-line silt and grime (gutter puddles on _Wet)
    T_Road_Cobbles_*   8 m x 6 m Harbour Road granite setts: cobblestone_04, sand / moss joints, wheel polish, gutter grime
    T_Road_Gravel_*    8 m x 3.33 m track: gravel_road, compacted ruts (puddles on _Wet), loose centre, grassy earth edges
    T_Road_Kerb_*      1.8 m x 0.40 m granite kerb profile (2 stones): V 0-0.125 road face, 0.125-0.145 arris, 0.145-0.295 top,
                       0.295-0.40 back; granite_tile speckle, road-dirt on the face, tyre scuffs, joints, lichen on the top
  Tile sets (seamless both ways, for MaterialVariants; StudsPerTile in roads_variants.json):
    T_Road_AsphaltTile_* 4 m, T_Road_CobblesTile_* 2 m, T_Road_GravelTile_* 2 m, T_Road_KerbTile_* 1 m
  Decal set (RGBA, AlphaMode Transparency): T_Road_Markings_* UK thermoplastic markings, rects in roads_variants.json
and assets/materials/roads_variants.json (variant rows, strip and decal layout).
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import texlib as T  # noqa: E402

GAME = T.GAME
OUT = os.path.join(GAME, "assets/textures/M_Road_Ribbon")
MASTERS = os.path.join(HERE, "M_Road_Ribbon/textures")
M = 2048
SHIP = 1024
F32 = np.float32


def grid(h, w, len_u, len_v):
    """x (along, m) and y (across from v = 0, m) per pixel; row 0 is v = 1."""
    x = (np.arange(w, dtype=F32) + 0.5) / w * len_u
    y = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h) * len_v
    return np.meshgrid(x, y)


def scan(pid, tile_px, hw, offset=(0, 0)):
    meta = T.fetch(pid)
    a, r, n, d = T.load(meta)
    return [T.tile_to(m, tile_px, hw, offset) for m in (a, r, n, d)]


def renorm(n):
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def crack_lines(hw, cycles, seed, width, density_seed, density=0.55):
    """Meandering periodic crack network (iso-lines of periodic noise), width in noise units; masked to patches."""
    n = T.noise(hw, cycles, seed, octaves=3)
    line = 1.0 - T.sstep(0.0, width, np.abs(n - 0.5))
    keep = T.sstep(density - 0.08, density + 0.08, T.noise(hw, 2, density_seed, octaves=2))
    return line * keep


def periodic_rect(x, y, x0, x1, y0, y1, len_u, soft=0.01):
    """Soft rectangle mask that wraps in x (period len_u)."""
    dx = (x - x0) % len_u
    w = (x1 - x0) % len_u
    mx = T.sstep(-soft, soft, dx) * (1 - T.sstep(w - soft, w + soft, dx))
    my = T.sstep(y0 - soft, y0 + soft, y) * (1 - T.sstep(y1 - soft, y1 + soft, y))
    return mx * my


# ----------------------------------------------------------------------------------------------------------- asphalt
def asphalt(len_u, len_v, edges=True, seed=0):
    hw = (M, M)
    ppm_u, ppm_v = M / len_u, M / len_v
    x, y = grid(M, M, len_u, len_v)
    reps = int(round(len_u / 4.0))
    a, r, n, d = scan("asphalt_04", (M / reps, 4.0 * ppm_v), hw)
    a = T.grade(a, 98, 17, tint=(1.0, 1.0, 1.02), desat=0.55)
    r = np.clip(0.80 + (r - r.mean()) * 0.8, 0.6, 0.97)
    # fresh patches (utility reinstatements): clean_asphalt, darker and tighter
    pa, pr, pn, _ = scan("clean_asphalt", (M / (reps * 2), 2.0 * ppm_v), hw, offset=(301, 177))
    pa = T.grade(pa, 66, 11, desat=0.7)
    pr = np.clip(0.72 + (pr - pr.mean()) * 0.7, 0.55, 0.9)
    jitter = (T.noise(hw, 40, seed + 9, 2) - 0.5) * 0.03
    if edges:
        rects = [(1.1, 2.0, 0.0, 3.1), (4.6, 7.0, 0.7, 2.0), (5.2, 7.6, 4.3, 5.6)]   # trench across the nearside lane, 2 boxes
    else:
        rects = [(0.6, 1.5, 0.2, 2.9), (2.3, 3.6, 2.4, 3.6)]
    patch = np.zeros(hw, F32)
    for (x0, x1, y0, y1) in rects:
        patch = np.maximum(patch, periodic_rect(x + jitter, y + jitter, x0, x1, y0, y1, len_u, 0.006))
    a, r = T.blend(a, pa, patch), T.blend(r, pr, patch)
    n = renorm(T.blend(n, pn, patch))
    # tar overbanding: patch borders, the centre joint, meandering crack sealing
    edge_d = np.abs(patch - 0.5)
    seal = 1 - T.sstep(0.08, 0.5, edge_d)
    seal *= T.sstep(0.25, 0.6, T.noise(hw, 18, seed + 4, 2)) * 0.6 + 0.4
    if edges:
        wob = (T.noise(hw, 6, seed + 5, 2) - 0.5) * 0.05
        joint = 1 - T.sstep(0.025, 0.045, np.abs(y - len_v / 2 + wob))
        seal = np.maximum(seal, joint * (0.75 + 0.25 * T.noise(hw, 30, seed + 6, 2)))
    cracks = crack_lines(hw, 3, seed + 7, 0.010, seed + 8, 0.5)
    seal = np.maximum(seal, cracks * (1 - patch))
    tar = np.array([40, 39, 38], F32) + (T.noise(hw, 90, seed + 10, 2)[..., None] - 0.5) * 8
    a = T.blend(a, np.broadcast_to(tar, a.shape), seal * 0.92)
    r = r * (1 - seal) + 0.38 * seal
    hgt = seal * 0.0015 - patch * 0.002
    if edges:
        # wheel-track polish and oil drips (two 3 m lanes)
        track = np.zeros(hw, F32)
        for c in (0.8, 2.2, 3.8, 5.2):
            track = np.maximum(track, np.exp(-((y - c) / 0.28) ** 2))
        track *= 0.6 + 0.4 * T.noise(hw, 8, seed + 11, 2)
        a = a * (1 - 0.10 * track[..., None])
        r = r - 0.10 * track
        n = T.flatten_normal(n, 0.35 * track)
        oil = np.zeros(hw, F32)
        for c in (1.5, 4.5):
            oil = np.maximum(oil, np.exp(-((y - c) / 0.35) ** 2))
        oil *= T.sstep(0.62, 0.8, T.noise(hw, 22, seed + 12, 3))
        a = a * (1 - 0.30 * oil[..., None])
        r = r - 0.12 * oil
        # kerb-line silt (sand, leaf litter, grit) and dark grime against both kerbs
        dist = np.minimum(y, len_v - y)
        nz = T.noise(hw, 14, seed + 13, 3)
        silt = np.clip(np.exp(-dist / 0.16) * (0.55 + 0.6 * nz) - 0.15, 0, 1)
        grime = np.exp(-dist / 0.35) * 0.6 * T.noise(hw, 9, seed + 14, 3)
        silt_c = np.dstack([118 + 18 * nz, 106 + 14 * nz, 88 + 10 * nz]).astype(F32)
        a = a * (1 - 0.28 * grime[..., None])
        a = T.blend(a, silt_c, silt * 0.85)
        r = r * (1 - silt) + 0.93 * silt
        n = T.flatten_normal(n, 0.6 * silt)
        pool = T.sstep(0.45, 0.62, np.exp(-dist / 0.22) * (0.5 + 0.7 * T.noise(hw, 6, seed + 15, 3)))
    else:
        pool = T.sstep(0.70, 0.80, T.noise(hw, 3, seed + 15, 3)) * 0.6
    n = T.combine_normals(n, T.height_normal(hgt, 1.0, ppm_u))
    r = np.clip(r, 0.3, 0.97)
    wa, wr = T.wet(a, r, pool=pool)
    wr = np.minimum(wr, np.where(seal > 0.5, 0.1, 1.0))
    return a, r, n, (wa, wr)


# ----------------------------------------------------------------------------------------------------------- cobbles
def cobbles(len_u, len_v, edges=True, seed=20):
    hw = (M, M)
    ppm_u, ppm_v = M / len_u, M / len_v
    x, y = grid(M, M, len_u, len_v)
    reps = int(round(len_u / 2.0))
    a, r, n, d = scan("cobblestone_04", (M / reps, 2.0 * ppm_v), hw)
    a = T.grade(a, 112, 24, tint=(1.03, 1.0, 0.97), desat=0.55)
    r = np.clip(0.70 + (r - r.mean()) * 0.9, 0.45, 0.95)
    joint = 1 - T.sstep(0.25, 0.5, d)                                  # low displacement = joints
    nz = T.noise(hw, 10, seed + 1, 3)
    sand = np.dstack([128 + 14 * nz, 114 + 12 * nz, 92 + 8 * nz]).astype(F32)
    a = T.blend(a, sand, joint * 0.55)
    if edges:
        dist = np.minimum(y, len_v - y)
        mossy = np.clip(np.exp(-dist / 0.6) * 1.2, 0, 1)
    else:
        dist = np.full(hw, 9.0, F32)
        mossy = np.full(hw, 0.35, F32)
    moss_c = np.dstack([76 + 20 * nz, 86 + 18 * nz, 58 + 8 * nz]).astype(F32)
    moss = joint * mossy * T.sstep(0.45, 0.7, T.noise(hw, 16, seed + 2, 3))
    a = T.blend(a, moss_c, moss * 0.8)
    r = r * (1 - joint) + 0.92 * joint
    # dark tops worn smooth in the wheel tracks
    if edges:
        track = np.zeros(hw, F32)
        for c in (0.8, 2.2, 3.8, 5.2):
            track = np.maximum(track, np.exp(-((y - c) / 0.32) ** 2))
        top = (1 - joint) * track
        a = a * (1 - 0.09 * top[..., None])
        r = r - 0.16 * top
        grime = np.exp(-dist / 0.3) * T.noise(hw, 8, seed + 3, 3)
        a = a * (1 - 0.25 * grime[..., None])
    a = a * (1 - 0.08 * (T.noise(hw, 3, seed + 4, 2)[..., None] - 0.5))   # large-scale tonal drift
    pool = joint * T.sstep(0.35, 0.6, T.noise(hw, 5, seed + 5, 3)) + (np.exp(-dist / 0.18) * 0.6 if edges else 0)
    pool = np.clip(pool, 0, 1)
    r = np.clip(r, 0.3, 0.97)
    wa, wr = T.wet(alb_ok(a), r, pool=pool)
    return a, r, n, (wa, wr)


def alb_ok(a):
    return np.clip(a, 26, 236)


# ----------------------------------------------------------------------------------------------------------- gravel
def gravel(len_u, len_v, edges=True, seed=40):
    hw = (M, M)
    ppm_u, ppm_v = M / len_u, M / len_v
    x, y = grid(M, M, len_u, len_v)
    reps = int(round(len_u / 2.0))
    a, r, n, d = scan("gravel_road", (M / reps, 2.0 * ppm_v), hw)
    a = T.grade(a, 118, 22, tint=(1.03, 1.0, 0.95), desat=0.82)
    a = np.maximum(a, 40)
    r = np.clip(0.86 + (r - r.mean()) * 0.6, 0.65, 0.98)
    pool = T.sstep(0.72, 0.82, T.noise(hw, 3, seed + 9, 3)) * 0.5
    if edges:
        wob = (T.noise(hw, 3, seed + 1, 2) - 0.5) * 0.12
        rut = np.zeros(hw, F32)
        for c in (len_v / 2 - 0.8, len_v / 2 + 0.8):
            rut = np.maximum(rut, np.exp(-((y - c + wob) / 0.22) ** 2))
        fine = T.noise(hw, 60, seed + 2, 3)
        earth = np.dstack([96 + 18 * fine, 84 + 14 * fine, 68 + 10 * fine]).astype(F32)
        a = T.blend(a, earth, rut * 0.55)
        r = r * (1 - rut) + 0.82 * rut
        n = T.flatten_normal(n, 0.55 * rut)
        # loose centre with sparse grass, grassy earth verges
        dist = np.minimum(y, len_v - y)
        verge = T.sstep(0.35, 0.0, dist + (T.noise(hw, 7, seed + 3, 3) - 0.5) * 0.3)
        tuft = T.sstep(0.62, 0.78, T.noise(hw, 26, seed + 4, 3))
        centre = np.exp(-((y - len_v / 2) / 0.25) ** 2) * tuft
        g = T.noise(hw, 120, seed + 5, 2)
        grass = np.dstack([92 + 26 * g, 102 + 24 * g, 62 + 12 * g]).astype(F32)
        green = np.clip(verge * (0.4 + 0.6 * tuft) + centre * 0.7, 0, 1)
        a = T.blend(a, grass, green * 0.8)
        r = r * (1 - green) + 0.9 * green
        pool = np.clip(rut * T.sstep(0.55, 0.7, T.noise(hw, 4, seed + 6, 3)) * 1.4, 0, 1)
    r = np.clip(r, 0.3, 0.98)
    wa, wr = T.wet(a, r, pool=pool)
    wy = T.luma(wa)[..., None]
    wa = wy + (wa - wy) * 0.85
    return a, r, n, (wa, wr)


# ----------------------------------------------------------------------------------------------------------- granite
def granite_patch():
    """A seam-free crop of granite_tile (between its grout lines), mirror-tiled 2 x 2 so it tiles."""
    meta = T.fetch("granite_tile")
    a, r, n, d = T.load(meta)
    y = T.luma(a)

    def span(profile):
        p = np.convolve(profile, np.ones(9) / 9, mode="same")
        lo = p < (np.median(p) - 1.2 * p.std())
        best, start, cur = (0, len(p)), None, None
        runs, s = [], None
        for i, v in enumerate(~lo):
            if v and s is None:
                s = i
            if (not v or i == len(p) - 1) and s is not None:
                runs.append((s, i))
                s = None
        if runs:
            best = max(runs, key=lambda t: t[1] - t[0])
        m = int((best[1] - best[0]) * 0.06)
        return best[0] + m, best[1] - m
    x0, x1 = span(y.mean(0))
    y0, y1 = span(y.mean(1))
    sl = (slice(y0, y1), slice(x0, x1))
    a, r, n = a[sl], r[sl], n[sl].copy()
    px_per_m = a.shape[1] / 1.0 if False else 2048 / meta["dims_m"][0]

    def mirror(m, flipx_sign=None):
        top = np.concatenate([m, m[:, ::-1]], 1)
        return np.concatenate([top, top[::-1]], 0)
    nx = n.copy()
    q = [n, n[:, ::-1] * np.array([-1, 1, 1], F32)]
    top = np.concatenate(q, 1)
    bot = top[::-1] * np.array([1, -1, 1], F32)
    nm = np.concatenate([top, bot], 0)
    return mirror(a), mirror(r), nm, px_per_m


def kerb(len_u=1.8, len_v=0.4, seed=60, tile=False):
    h, w = (M // 4, M) if not tile else (M, M)
    if tile:
        len_u = len_v = 1.0
    hw = (h, w)
    ppm_u, ppm_v = w / len_u, h / len_v
    x, y = grid(h, w, len_u, len_v)
    ga, gr, gn, gppm = granite_patch()
    tpx = (ga.shape[1] / gppm * ppm_u * 0.85, ga.shape[0] / gppm * ppm_v * 0.85)
    if tile:
        tpx = (w / max(1, round(w / tpx[0])), h / max(1, round(h / tpx[1])))
    a = T.tile_to(ga, tpx, hw)
    r = T.tile_to(gr, tpx, hw)
    n = renorm(T.tile_to(gn, tpx, hw))
    a = T.grade(a, 138, 26, tint=(1.0, 1.0, 1.01), desat=0.6)
    r = np.clip(0.62 + (r - r.mean()) * 0.5, 0.45, 0.85)       # sawn / flame-textured, not polished
    tooled = T.noise(hw, 220, seed + 1, 2)
    n = T.combine_normals(n, T.height_normal((tooled - 0.5) * 0.0006, 1.0, ppm_u))
    r = np.clip(r + (tooled - 0.5) * 0.12, 0.45, 0.9)
    pool = np.zeros(hw, F32)
    if not tile:
        stone = np.floor(x / 0.9).astype(int)
        tone = np.where(stone % 2 == 0, 1.0, 0.94).astype(F32)
        a = a * tone[..., None] * np.array([1.0, 1.0, 1.0], F32)
        jd = np.minimum(x % 0.9, 0.9 - (x % 0.9))
        joint = 1 - T.sstep(0.004, 0.009, jd)
        a = T.blend(a, np.broadcast_to(np.array([62, 60, 56], F32), a.shape), joint * 0.85)
        r = r * (1 - joint) + 0.9 * joint
        hgt = -joint * 0.004
        face = (y < 0.125).astype(F32)
        arris = ((y >= 0.125) & (y < 0.145)).astype(F32)
        topz = ((y >= 0.145) & (y < 0.295)).astype(F32)
        back = (y >= 0.295).astype(F32)
        nz = T.noise(hw, 12, seed + 2, 3)
        dirt = face * np.clip(T.sstep(0.09, 0.0, y) * (0.5 + 0.7 * nz), 0, 1)
        dirt_c = np.dstack([92 + 16 * nz, 86 + 12 * nz, 76 + 8 * nz]).astype(F32)
        a = T.blend(a, dirt_c, dirt * 0.85)
        r = r * (1 - dirt) + 0.92 * dirt
        scuff = face * T.sstep(0.03, 0.06, y) * T.sstep(0.11, 0.08, y) * T.sstep(0.7, 0.8, T.noise(hw, 10, seed + 3, 2,
                                                                                            aniso=(6.0, 1.0)))
        a = a * (1 - 0.55 * scuff[..., None])
        r = r - 0.15 * scuff
        wornedge = arris * (0.6 + 0.4 * T.noise(hw, 40, seed + 4, 2))
        a = a * (1 + 0.08 * wornedge[..., None])
        chips = arris * T.sstep(0.78, 0.85, T.noise(hw, 50, seed + 5, 2))
        hgt -= chips * 0.003
        a = a * (1 + 0.1 * chips[..., None])
        lich = topz * T.sstep(0.74, 0.8, T.noise(hw, 30, seed + 6, 3))
        lich_c = np.dstack([168 + 10 * nz, 170 + 10 * nz, 150 + 6 * nz]).astype(F32)
        a = T.blend(a, lich_c, lich * 0.55)
        backd = back * (0.4 + 0.5 * nz)
        a = T.blend(a, np.dstack([88 + 0 * nz, 92 + 0 * nz, 70 + 0 * nz]).astype(F32), backd * 0.5)
        r = r * (1 - backd) + 0.9 * backd
        pool = np.clip(dirt * 0.5 + joint * 0.3, 0, 1)
        n = T.combine_normals(n, T.height_normal(hgt, 1.0, ppm_u))
    r = np.clip(r, 0.3, 0.95)
    wa, wr = T.wet(a, r, pool=pool)
    return a, r, n, (wa, wr), hw


# ----------------------------------------------------------------------------------------------------------- markings
PPM = 256  # markings atlas pixels per metre at the 2048 master (cat's eyes 512)
CELLS = {  # name: (x, y, w, h) master px, row 0 top; along = x
    "CentreDash":   (0, 0, 1152, 128),      # Diagram 1008: 4 m mark (centred), 100 mm wide (verify)
    "EdgeLine":     (0, 128, 1024, 128),    # Diagram 1012.1: continuous 100 mm, 4 m period (tiles along U)
    "DoubleYellow": (0, 256, 1024, 128),    # Diagram 1018.1: two 100 mm lines, 75 mm gap, 4 m period (verify)
    "GiveWayLines": (0, 384, 1024, 256),    # Diagram 1003: 600 mm marks, 300 mm gaps, 2 x 200 mm lines 300 mm apart (verify)
    "GiveWayTriangle": (1216, 0, 448, 1024),  # Diagram 1023: 3.75 m long, 1.5 m base, 150 mm outline (verify)
    "CatsEyeWhite": (1728, 0, 128, 128),    # 0.25 m cell at 512 px/m: cast housing, rubber pad, 2 lenses
    "CatsEyeRed":   (1856, 0, 128, 128),
}


def markings(seed=80):
    hw = (M, M)
    yy, xx = np.mgrid[0:M, 0:M].astype(F32)
    shape = np.zeros(hw, F32)
    yellow = np.zeros(hw, F32)
    signal = np.zeros(hw, F32)
    metal = np.zeros(hw, F32)
    rgh = np.full(hw, 0.6, F32)
    alb = np.full(hw + (3,), 128.0, F32)
    hgt = np.zeros(hw, F32)

    def box(x0, y0, x1, y1, soft=1.2):
        return (T.sstep(x0 - soft, x0 + soft, xx) * (1 - T.sstep(x1 - soft, x1 + soft, xx)) *
                T.sstep(y0 - soft, y0 + soft, yy) * (1 - T.sstep(y1 - soft, y1 + soft, yy)))
    cx, cy, cw, ch = CELLS["CentreDash"]
    mid = cy + ch / 2
    shape = np.maximum(shape, box(cx + 64, mid - 12.8, cx + 64 + 4 * PPM, mid + 12.8))
    cx, cy, cw, ch = CELLS["EdgeLine"]
    mid = cy + ch / 2
    shape = np.maximum(shape, box(cx - 4, mid - 12.8, cx + cw + 4, mid + 12.8, 0.01) * box(cx - 4, mid - 12.8, cx + cw + 4, mid + 12.8))
    cx, cy, cw, ch = CELLS["DoubleYellow"]
    mid = cy + ch / 2
    g = 0.075 * PPM / 2
    dy = box(cx - 4, mid - g - 25.6, cx + cw + 4, mid - g) + box(cx - 4, mid + g, cx + cw + 4, mid + g + 25.6)
    shape = np.maximum(shape, dy)
    yellow = np.maximum(yellow, box(cx, cy, cx + cw, cy + ch, 0.01))
    cx, cy, cw, ch = CELLS["GiveWayLines"]
    mid = cy + ch / 2
    per = 0.9 * PPM
    for k in range(5):
        x0 = cx + 0.15 * PPM + k * per
        if x0 + 0.6 * PPM > cx + cw:
            break
        for off in (-0.25, 0.25):
            yc = mid + off * PPM
            shape = np.maximum(shape, box(x0, yc - 0.1 * PPM, x0 + 0.6 * PPM, yc + 0.1 * PPM))
    cx, cy, cw, ch = CELLS["GiveWayTriangle"]
    # apex towards +x? the triangle points along the road: base (1.5 m) at the top of the cell, apex 3.75 m below
    tx0, ty0 = cx + cw / 2, cy + 32
    L, B, s = 3.75 * PPM, 1.5 * PPM, 0.15 * PPM
    u = (yy - ty0) / L
    half = (1 - u) * B / 2
    inside = (u >= 0) & (u <= 1) & (np.abs(xx - tx0) <= half)
    # inset triangle: distance to the edges
    slope = np.hypot(L, B / 2)
    d_side = (half - np.abs(xx - tx0)) * L / slope
    d_base = yy - ty0
    d = np.minimum(d_side, d_base)
    tri = inside * (1 - T.sstep(s - 1, s + 1, d))
    shape = np.maximum(shape, tri.astype(F32))
    # paint texture, glass-bead speckle, wear breakup
    nz = T.noise(hw, 160, seed + 1, 3)
    wear = T.noise(hw, 40, seed + 2, 4)
    erode = T.sstep(0.70, 0.80, wear) * 0.9 + T.sstep(0.55, 0.9, T.noise(hw, 300, seed + 3, 2)) * 0.25
    white = np.dstack([224 + 10 * nz, 224 + 10 * nz, 216 + 10 * nz]).astype(F32)
    yel = np.dstack([206 + 12 * nz, 168 + 12 * nz, 64 + 8 * nz]).astype(F32)
    paint = T.blend(white, yel, yellow)
    grime = T.noise(hw, 12, seed + 4, 3)
    paint = paint * (1 - 0.14 * grime[..., None])
    alpha = np.clip(shape * (1 - erode), 0, 1)
    alb = T.blend(alb, paint, np.clip(shape * 4, 0, 1))
    bead = T.sstep(0.6, 0.75, T.noise(hw, 500, seed + 5, 1))
    rgh = np.where(shape > 0.02, 0.55 - 0.25 * bead, rgh)
    hgt = alpha * 0.003
    signal = np.maximum(signal, yellow)
    # cat's eyes (top view, 512 px/m): grey cast housing (metal), black rubber pad, two lenses
    for name, lens in (("CatsEyeWhite", (226, 224, 214)), ("CatsEyeRed", (190, 46, 40))):
        cx, cy, cw, ch = CELLS[name]
        k = 512.0
        ccx, ccy = cx + cw / 2, cy + ch / 2
        hous = box(ccx - 0.11 * k, ccy - 0.08 * k, ccx + 0.11 * k, ccy + 0.08 * k, 2.0)
        pad = box(ccx - 0.085 * k, ccy - 0.05 * k, ccx + 0.085 * k, ccy + 0.05 * k, 1.5)
        lensm = np.zeros(hw, F32)
        for sx in (-0.045, 0.045):
            lensm = np.maximum(lensm, box(ccx + sx * k - 0.022 * k, ccy - 0.012 * k, ccx + sx * k + 0.022 * k, ccy + 0.012 * k, 1.0))
        cell = box(cx, cy, cx + cw, cy + ch, 0.01)
        hc = np.dstack([206 + 12 * nz, 206 + 12 * nz, 202 + 12 * nz]).astype(F32)
        alb = T.blend(alb, hc, hous * cell)
        metal = np.maximum(metal, (hous > 0.95) * (pad < 0.02) * cell)
        rgh = np.where(hous * cell > 0.5, 0.5, rgh)
        alb = T.blend(alb, np.dstack([40 + 8 * nz] * 3).astype(F32), pad * cell)
        rgh = np.where(pad * cell > 0.5, 0.82, rgh)
        alb = T.blend(alb, np.broadcast_to(np.array(lens, F32), alb.shape), lensm * cell)
        rgh = np.where(lensm * cell > 0.5, 0.12, rgh)
        alpha = np.maximum(alpha, hous * cell)
        hgt = hgt + cell * (hous * 0.006 + pad * 0.004)
        if name == "CatsEyeRed":
            signal = np.maximum(signal, lensm * cell)
    metal = np.zeros(hw, F32)  # weathered cast housing reads as dull grey (non-metal) at road scale
    nrm = T.height_normal(hgt, 1.0, PPM)
    wa, wr = T.wet(alb, rgh, darken=0.2, gloss=0.35)
    return alb, rgh, nrm, metal, alpha, (wa, wr), signal


def write_markings_signal(sig):
    d = os.path.join(HERE, "M_Road_Ribbon")
    os.makedirs(d, exist_ok=True)
    m = Image.fromarray((np.clip(sig, 0, 1) * 255).astype(np.uint8)).resize((SHIP, SHIP), Image.NEAREST)
    m = m.point(lambda v: 255 if v > 0 else 0)
    m.save(os.path.join(d, "T_Road_Markings_signal.png"))


def main():
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
    jobs = {
        "Asphalt": lambda: asphalt(8.0, 6.0),
        "Cobbles": lambda: cobbles(8.0, 6.0),
        "Gravel": lambda: gravel(8.0, 3.333),
        "AsphaltTile": lambda: asphalt(4.0, 4.0, edges=False, seed=5),
        "CobblesTile": lambda: cobbles(2.0, 2.0, edges=False, seed=25),
        "GravelTile": lambda: gravel(2.0, 2.0, edges=False, seed=45),
    }
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        a, r, n, w = fn()
        T.save_set(OUT, "T_Road_%s" % name, alb_ok(a), r, n, size=SHIP, wet_maps=(alb_ok(w[0]), w[1]), master_dir=MASTERS)
        print("wrote", name)
    if not only or "Kerb" in only:
        a, r, n, w, hw = kerb()
        T.save_set(OUT, "T_Road_Kerb", alb_ok(a), r, n, size=(SHIP, SHIP // 4), wet_maps=(alb_ok(w[0]), w[1]), master_dir=MASTERS)
        a, r, n, w, hw = kerb(tile=True)
        T.save_set(OUT, "T_Road_KerbTile", alb_ok(a), r, n, size=SHIP, wet_maps=(alb_ok(w[0]), w[1]), master_dir=MASTERS)
        print("wrote Kerb, KerbTile")
    if not only or "Markings" in only:
        a, r, n, met, alpha, w, sig = markings()
        T.save_set(OUT, "T_Road_Markings", alb_ok(a), r, n, met=met, alpha=alpha, size=SHIP, wet_maps=(alb_ok(w[0]), w[1]),
                   master_dir=MASTERS)
        write_markings_signal(sig)
        print("wrote Markings")
    write_layout()


def write_layout():
    rect = {k: [round(x / M, 5), round(1 - (y + h) / M, 5), round((x + w) / M, 5), round(1 - y / M, 5)]
            for k, (x, y, w, h) in CELLS.items()}
    out = {
        "note": "R1a road surfaces (art/source/roads/roadmats.py, INTEGRATION.md). Texture ids: AssetIds.Textures.M_Road_Ribbon.<Set>",
        "strips": {
            "Asphalt": {"len_u_m": 8.0, "width_m": 6.0, "edge_band_m": 0.9},
            "Cobbles": {"len_u_m": 8.0, "width_m": 6.0, "edge_band_m": 0.9},
            "Gravel": {"len_u_m": 8.0, "width_m": 3.333, "edge_band_m": 0.5},
            "Kerb": {"len_u_m": 1.8, "profile_v_m": {"face": [0.0, 0.125], "arris": [0.125, 0.145], "top": [0.145, 0.295],
                                                     "back": [0.295, 0.4]}, "stone_m": 0.9},
        },
        "variants": [
            # name, set, BaseMaterial, StudsPerTile, pattern, use
            {"name": "RoadAsphaltWorn", "set": "AsphaltTile", "base": "Asphalt", "studsPerTile": 12, "pattern": "Organic",
             "use": "verges of the ribbon, car parks, lay-bys, terrain Asphalt slot"},
            {"name": "RoadHarbourCobbles", "set": "CobblesTile", "base": "Cobblestone", "studsPerTile": 6, "pattern": "Regular",
             "use": "Harbour Road quay apron, slipway heads"},
            {"name": "RoadGravelTrack", "set": "GravelTile", "base": "Pavement", "studsPerTile": 6, "pattern": "Organic",
             "use": "Haven Head track shoulders, viewpoint car park"},
            {"name": "RoadKerbGranite", "set": "KerbTile", "base": "Granite", "studsPerTile": 3, "pattern": "Regular",
             "use": "kerb Parts / steps where the ribbon kerb mesh is not used"},
        ],
        "markings": {"ppm": PPM, "catseye_ppm": 512, "uv": "u0, v0, u1, v1 (v up)", "rects": rect,
                     "dims_m": {"CentreDash": [4.0, 0.1], "EdgeLine": [4.0, 0.1], "DoubleYellow": [4.0, 0.275],
                                "GiveWayLines": [4.0, 0.7], "GiveWayTriangle": [1.5, 3.75], "CatsEye": [0.22, 0.16]},
                     "cell_m": {k: [w / (512 if k.startswith("CatsEye") else PPM), h / (512 if k.startswith("CatsEye") else PPM)]
                                for k, (x, y, w, h) in CELLS.items()}},
    }
    os.makedirs(os.path.join(GAME, "assets/materials"), exist_ok=True)
    json.dump(out, open(os.path.join(GAME, "assets/materials/roads_variants.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
