#!/usr/bin/env python3
"""Deterministic heightmap + material map baker for the Gale Isles (docs/10-world-and-map.md).

usage: python3 tools/world/gen_terrain.py [--preview build/world/terrain_preview.png]

Reads tools/world/layout.py (island polygons, coast kinds, harbour, roads, reefs, POIs) and writes
  map/generated/terrain.json          grid metadata, material table, stats
  map/generated/terrain_height.i16    int16 LE, surface Y * 8, row-major [z][x], CELL-stud samples
  map/generated/terrain_material.u8   uint8 material index (terrain.json "materials")
  src/shared/Config/WorldConfig.luau  pure-data module: POIs, roads, car parks, beach / launch points (generated)
Same layout + SEED = byte-identical output. Needs numpy (and Pillow for --preview)."""
import json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

MATERIALS = ["Air", "Sand", "Sandstone", "Salt", "Limestone", "Rock", "Slate", "Basalt", "Grass", "LeafyGrass",
             "Mud", "Ground", "Asphalt", "Cobblestone", "Concrete", "Pavement", "CrackedLava", "Snow", "WoodPlanks",
             "Brick", "Glacier", "Ice"]
MI = {name: i for i, name in enumerate(MATERIALS)}
# Rippled seabed sand: doc 10's Salt slot (stock Salt renders near-white; B02's SeabedSand MaterialVariant fixes it).
SEABED_SAND = "Salt"
# Shingle (pebbles): Pebble is not a Terrain material, so the Shingle MaterialVariant overrides the unused CrackedLava
# slot (art/source/materials/library.py; Tyre.luau already grips it as Rock).
SHINGLE = "CrackedLava"
# Terrain pass T3: two more turf variants as island-scale macro patches on unused Terrain slots (library.py):
# TurfStraw (dry straw / dead-grass sward) on Snow, TurfOlive (dark lush sward in hollows and lee slopes) on WoodPlanks.
STRAW = "Snow"
OLIVE = "WoodPlanks"
# Terrain pass T4: three more variants on unused slots (library.py; Tyre.luau grips them as Dirt / Sand / Sand):
# TurfWorn (trampled turf over earth: the mid-tone between turf and mud / earth) on Brick, SandRipple (wind-rippled dune
# sand) on Glacier, Wrack (damp sand under the dried weed of the strand line) on Ice.
WORN = "Brick"
# farmland field classes by field hash (gen_terrain.materials, scatter_props): green < FIELD_GREEN <= olive < FIELD_OLIVE
# <= straw < FIELD_STRAW <= heath < FIELD_HEATH <= bracken
# WP-3: more hay / stubble fields (16 %) so the patchwork reads from the air
FIELD_GREEN, FIELD_OLIVE, FIELD_STRAW, FIELD_HEATH = 0.42, 0.7, 0.86, 0.93
RIPPLE = "Glacier"
WRACK = "Ice"

# ---------------------------------------------------------------- noise (seeded integer-hash value noise)


def _hash(ix, iz, seed):
    h = (ix.astype(np.int64) * 374761393 + iz.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return h.astype(np.float64) / 4294967295.0


def vnoise(x, z, scale, seed):
    u, v = x / scale, z / scale
    i, j = np.floor(u), np.floor(v)
    fu, fv = u - i, v - j
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    i, j = i.astype(np.int64), j.astype(np.int64)
    a, b = _hash(i, j, seed), _hash(i + 1, j, seed)
    c, d = _hash(i, j + 1, seed), _hash(i + 1, j + 1, seed)
    return (a + (b - a) * fu + (c - a) * fv + (a - b - c + d) * fu * fv) * 2 - 1


def fbm(x, z, scale, seed, octaves=4):
    total, amp, norm = 0.0, 1.0, 0.0
    for k in range(octaves):
        total = total + amp * vnoise(x, z, scale / (2 ** k), seed + 101 * k)
        norm += amp
        amp *= 0.5
    return total / norm


def ridged(x, z, scale, seed, octaves=3):
    return 1 - np.abs(fbm(x, z, scale, seed, octaves))


_BLUE = {}


def blue(ix, iz, seed, n=64):
    """Tileable blue-noise dither (uniform 0..1 per voxel cell): white noise high-passed in the Fourier domain and
    rank-normalised, so neighbouring cells differ and no two-cell clumps form; a seeded offset per call."""
    if n not in _BLUE:
        rng = np.random.default_rng(9137)
        F = np.fft.fft2(rng.standard_normal((n, n)))
        f = np.fft.fftfreq(n) * n
        r = np.hypot(f[:, None], f[None, :])
        w = np.real(np.fft.ifft2(F * smoothstep(n * 0.12, n * 0.3, r)))
        _BLUE[n] = (np.argsort(np.argsort(w.ravel())).reshape(n, n) + 0.5) / (n * n)
    t = _BLUE[n]
    ox, oz = (seed * 37) % n, (seed * 53 + 11) % n
    return t[(iz + oz) % n, (ix + ox) % n]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- coast distance and kind weights


def coast_field(X, Z):
    """Signed distance to the nearest island coast (+ on land), the coast-top height H and kind weights."""
    best_d = np.full(X.shape, -1e9)
    best_H = np.zeros(X.shape)
    best_w = np.zeros((len(L.KINDS),) + X.shape)
    for poly in L.ISLANDS:
        n = len(poly)
        dmin = np.full(X.shape, 1e18)
        H = np.zeros(X.shape)
        W = np.zeros((len(L.KINDS),) + X.shape)
        inside = np.zeros(X.shape, dtype=bool)
        segs = []
        for k in range(n):
            x0, z0, k0, h0 = poly[k]
            x1, z1, k1, h1 = poly[(k + 1) % n]
            dx, dz = x1 - x0, z1 - z0
            t = np.clip(((X - x0) * dx + (Z - z0) * dz) / (dx * dx + dz * dz), 0, 1)
            dist = np.sqrt((X - (x0 + t * dx)) ** 2 + (Z - (z0 + t * dz)) ** 2)
            dmin = np.minimum(dmin, dist)
            segs.append((dist, t, k0, h0, k1, h1))
            crosses = ((z0 > Z) != (z1 > Z)) & (X < x0 + (Z - z0) * dx / (dz if dz != 0 else 1e-9))
            inside ^= crosses
        # soft nearest-segment blend (no seams along the medial axis); sharper near the coast
        tau = 40 + 0.3 * dmin
        wsum = np.zeros(X.shape)
        for dist, t, k0, h0, k1, h1 in segs:
            w = np.exp(-(dist - dmin) / tau)
            wsum += w
            H += w * (h0 + (h1 - h0) * t)
            for ki, kind in enumerate(L.KINDS):
                W[ki] += w * ((1 - t) * (kind == k0) + t * (kind == k1))
        H /= wsum
        W /= wsum[None]
        d = dmin * np.where(inside, 1, -1)
        take = d > best_d
        best_d = np.where(take, d, best_d)
        best_H = np.where(take, H, best_H)
        best_w = np.where(take[None], W, best_w)
    return best_d, best_H, best_w


def flat_keep(X, Z):
    """T3: 0 on and within ~16 studs of every road centre line, car park (+12 studs) and point / POI (30 studs), fading to
    1 over the next ~20 studs. The T3 relief (hummocks, outcrops, dune banks) is multiplied by it, so the paved road
    profiles, the quay, pads and the station keep their T2 heights."""
    x0 = X[0, 0]
    m = np.zeros(X.shape)
    for road in L.ROADS:
        for x, z in catmull(road["points"], 2.0):
            i, j = int(round((z - x0) / L.CELL)), int(round((x - x0) / L.CELL))
            if 0 <= i < m.shape[0] and 0 <= j < m.shape[1]:
                m[i, j] = 1
    near = box_blur(m, 4) > 0
    for cp in L.CAR_PARKS + L.FARMS:
        cx, cz = cp["center"]
        a = math.radians(cp["yaw"])
        lx = (X - cx) * math.cos(a) + (Z - cz) * math.sin(a)
        lz = -(X - cx) * math.sin(a) + (Z - cz) * math.cos(a)
        near |= (np.abs(lx) < cp["size"][0] / 2 + 12) & (np.abs(lz) < cp["size"][1] / 2 + 12)
    for p in list(L.POINTS) + list(L.POIS):
        near |= np.hypot(X - p["pos"][0], Z - p["pos"][2]) < 30
    return 1 - np.clip(box_blur(near.astype(np.float64), 5) * 2, 0, 1)


def micro_relief(X, Z, hl, dl, wb, s, fk=1.0):
    """Land micro-relief: hummocks (0.5-1 stud), sheep-track terracettes along the contours of moderate slopes, and
    erosion gullies (up to 2 studs deep) running down the fall line of steeper banks. Masked off the beach, the dunes
    and the waterline, the town platform and harbour, and 25-45 studs round every point and POI; roads and car parks
    are flattened over it by pave(). Returns (height, gully mask for the materials)."""
    gz_, gx_ = np.gradient(box_blur(hl, 10), L.CELL)  # fall line, smoothed over ~84 studs
    g = np.maximum(np.hypot(gx_, gz_), 1e-6)
    sz_, sx_ = np.gradient(box_blur(hl, 1), L.CELL)
    slope = np.hypot(sx_, sz_)
    Xw, Zw = warp(X, Z, s + 500, 30, 120)
    keep = smoothstep(4, 24, dl) * smoothstep(0.6, 0.35, wb)
    tp = L.TOWN_PLATFORM
    ex = np.maximum(np.maximum(tp["minX"] - X, X - tp["maxX"]), 0)
    ez = np.maximum(np.maximum(tp["minZ"] - Z, Z - tp["maxZ"]), 0)
    keep = keep * smoothstep(tp["blend"] * 0.6, tp["blend"] + 40, np.hypot(ex, ez))
    for p in list(L.POINTS) + list(L.POIS):
        px, _, pz = p["pos"]
        keep = keep * smoothstep(25, 45, np.hypot(X - px, Z - pz))
    bump = 1.3 * fbm(Xw, Zw, 34, s + 510, 3) + 0.35 * vnoise(X, Z, 10, s + 511)
    # T3: mid-scale hummocks (5-15 studs) in patchy fields, stronger on gentle turf than on banks
    field = 0.35 + 0.65 * smoothstep(-0.35, 0.35, fbm(X, Z, 170, s + 522, 2))
    hum = field * (1.1 * fbm(Xw, Zw, 13, s + 520, 2) + 0.55 * vnoise(X + 3.7, Z - 1.3, 7, s + 521)) \
        * smoothstep(0.75, 0.35, slope)
    # T3: rock outcrops: knuckles of granite breaking the turf on ridges and knolls (convex ground), 2-6 studs proud
    convex = smoothstep(0.05, 0.6, hl - box_blur(hl, 6))
    rid = ridged(Xw, Zw, 55, s + 530, 3)
    # T6: larger and more numerous (thresholds down, 3-9 studs proud, a wider regional gate)
    outc = smoothstep(0.88, 0.965, rid + 0.12 * convex) * (0.45 + 0.55 * convex) * smoothstep(0.05, 0.16, slope) \
        * smoothstep(0.95, 0.7, slope) * smoothstep(12, 26, hl) * smoothstep(-0.4, 0.1, fbm(X, Z, 260, s + 532, 2))
    rock_h = outc * (3.0 + 4.8 * ridged(X, Z, 11, s + 531, 2) + 1.4 * vnoise(X, Z, 6, s + 533))
    phase = 2 * np.pi * (box_blur(hl, 2) + 1.2 * fbm(Xw, Zw, 50, s + 512, 2)) / 2.6
    # T4: sheep-track terracettes stronger (0.5 studs) over a wider slope range, and a fine low-amplitude
    # 8-16 stud roughness so the near ground is never a smooth sheet
    bump = bump + 0.3 * vnoise(X + 1.9, Z + 0.7, 8, s + 540) + 0.2 * vnoise(X, Z, 16, s + 541)
    terr = 0.5 * np.sin(phase) * smoothstep(0.1, 0.24, slope) * smoothstep(0.72, 0.5, slope) \
        * smoothstep(0.0, 0.3, fbm(Xw, Zw, 140, s + 513, 2))
    across = X * (-gz_ / g) + Z * (gx_ / g)  # coordinate along the contour: gullies are lines of constant value
    v = smoothstep(0.8, 1.0, np.cos(across / 9 + 2.5 * fbm(Xw, Zw, 90, s + 514, 2)))
    gully = v * smoothstep(0.22, 0.4, slope) * smoothstep(1.1, 0.8, slope) \
        * smoothstep(-0.1, 0.3, fbm(X, Z, 200, s + 515, 2)) * smoothstep(8, 22, hl) * keep
    outc = outc * keep * fk
    return hl + (bump + terr) * keep + (hum + rock_h) * keep * fk - 2.0 * gully, (gully, smoothstep(0.15, 0.45, outc))


def harbour_hill(X, Z):
    """T6: 0..1 over the hillside behind the harbour town (south of the town platform, 14-520 studs out)."""
    tp = L.TOWN_PLATFORM
    ex = np.maximum(np.maximum(tp["minX"] - X, X - tp["maxX"]), 0)
    ez = np.maximum(np.maximum(tp["minZ"] - Z, Z - tp["maxZ"]), 0)
    dp = np.hypot(ex, ez)
    return smoothstep(14, 40, dp) * smoothstep(520, 380, dp) * smoothstep(tp["minZ"] + 40, tp["minZ"] - 10, Z)


def field_cells(X, Z, s, size=74.0):
    """T6 Cornish field pattern: a warped jittered-grid Voronoi. Returns (distance to the nearest field boundary,
    studs; a 0..1 hash per field)."""
    Xw, Zw = warp(X, Z, s + 700, 12, 90)
    gx, gz = np.floor(Xw / size), np.floor(Zw / size)
    f1, f2, cid = np.full(X.shape, 1e9), np.full(X.shape, 1e9), np.zeros(X.shape)
    for dx in (-1, 0, 1):
        for dz in (-1, 0, 1):
            ci, cj = (gx + dx).astype(np.int64), (gz + dz).astype(np.int64)
            px = (ci + 0.15 + 0.7 * _hash(ci, cj, s + 701)) * size
            pz = (cj + 0.15 + 0.7 * _hash(ci, cj, s + 702)) * size
            dd = np.hypot(Xw - px, Zw - pz)
            closer = dd < f1
            f2 = np.where(closer, f1, np.minimum(f2, dd))
            cid = np.where(closer, _hash(ci, cj, s + 703), cid)
            f1 = np.where(closer, dd, f1)
    return (f2 - f1) * 0.5, cid


def hill_relief(X, Z, s):
    """T6 harbour hillside relief (the T5 hillside was a flat straw plane: the town-platform mask kept the
    micro-relief off it): Cornish hedges (turf-and-stone field banks, 2-3 studs high, ~9 studs across, with gateways)
    on the field boundaries, 0.8-1.6 stud hummocks inside the fields and granite outcrops 2-6 studs proud.
    Returns (height, hedge 0..1, field hash, outcrop 0..1); the caller multiplies by harbour_hill() and flat_keep()."""
    edge, cid = field_cells(X, Z, s)
    gate = smoothstep(-0.62, -0.45, fbm(X, Z, 46, s + 710, 2))  # gateways and slumped gaps
    hedge = smoothstep(5.0, 1.2, edge + 0.8 * vnoise(X, Z, 9, s + 711)) * gate
    hedge_h = hedge * (2.3 + 0.7 * vnoise(X, Z, 21, s + 712))
    Xw, Zw = warp(X, Z, s + 720, 16, 70)
    hum = (1.1 * fbm(Xw, Zw, 17, s + 721, 2) + 0.45 * vnoise(X, Z, 8, s + 722)) \
        * (0.5 + 0.5 * smoothstep(-0.3, 0.3, fbm(X, Z, 120, s + 723, 2)))
    rk = smoothstep(0.95, 0.99, ridged(Xw, Zw, 48, s + 730, 3)) * smoothstep(-0.25, 0.2, fbm(X, Z, 180, s + 731, 2)) \
        * smoothstep(4.0, 9.0, edge)
    rock_h = rk * (2.2 + 3.6 * ridged(X, Z, 8, s + 732, 2) + 0.9 * vnoise(X, Z, 5, s + 733))
    return hedge_h + hum * (1 - hedge) + rock_h, hedge, cid, smoothstep(0.12, 0.4, rk)


def ridge_z(X, s):
    return L.MOOR_RIDGE["z"] + 110 * fbm(X, 0 * X, 600, s + 93)


def moor_ridge(X, Z, dl, s):
    """WP-3: the moor ridge behind Port Haven (the town's skyline), lower at the High Road's col."""
    R = L.MOOR_RIDGE
    col = 1 - 0.7 * np.exp(-((X - R["colX"]) / 260) ** 2)
    amp = (R["height"] + 35 * fbm(X, 0 * X, 450, s + 94)) * smoothstep(1950, 1450, np.abs(X)) * col \
        * smoothstep(60, 260, dl)
    return amp * np.exp(-((Z - ridge_z(X, s)) / R["width"]) ** 2) * (0.85 + 0.15 * ridged(X, Z, 140, s + 95))


def town_hill(X, Z, h, s):
    """WP-3: the hillside north of the town platform stays a natural rising slope. Granite retaining walls only as
    short, noise-gated runs (`step` studs high) in the steep band just above the town and along Chapel Hill; across the
    slope, field hedges (turf-and-stone banks with gaps) follow the wobbly contours every `hedgeRise` studs of height,
    so with the Voronoi field banks the fields are irregular. Returns (h, wall mask, contour hedge 0..1, zone 0..1)."""
    th, tp = L.TOWN_HILL, L.TOWN_PLATFORM
    step, wf = th["step"], th["wall"]
    hs = box_blur(h, 12)
    zone = smoothstep(tp["minX"] - th["fadeX"], tp["minX"], X) * smoothstep(tp["maxX"] + th["fadeX"], tp["maxX"], X) \
        * smoothstep(tp["minZ"], tp["minZ"] - 14, Z) * smoothstep(tp["minZ"] - th["depth"], tp["minZ"] - th["depth"] + 60, Z)
    # walls: the band just above the town edge and the flanks of Chapel Hill, in short runs with gaps between
    lane = next(r for r in L.ROADS if r["id"] == "TownLane")
    dr = np.full(X.shape, 1e9)
    for px, pz in catmull(lane["points"], 8):
        dr = np.minimum(dr, np.hypot(X - px, Z - pz))
    band = np.maximum(smoothstep(tp["minZ"] - th["wallBand"], tp["minZ"] - th["wallBand"] + 50, Z),
                      smoothstep(th["roadBand"] + 40, th["roadBand"], dr))
    Xw, Zw = warp(X, Z, s + 760, 20, 120)
    seg = zone * band * smoothstep(0.0, 0.25, fbm(Xw, Zw, 70, s + 761, 2))
    t = np.maximum(hs - tp["y"], 0) / step
    k = np.floor(t)
    f = t - k
    rise = smoothstep(1 - wf, 1, f)
    q = tp["y"] + step * (k + rise) + 1.0 * f * (1 - rise)
    detail = np.clip(h - box_blur(h, 3), -1.5, 2.5) * (1 - rise)
    h = h + (q + detail - h) * seg
    wall = (seg > 0.5) & (f > 1 - wf - 0.04)
    # contour hedges: lines of constant (warped) height, ~2.5 studs either side, with gateways and slumped gaps
    gz_, gx_ = np.gradient(hs, L.CELL)
    c = hs / th["hedgeRise"] + 0.45 * fbm(Xw, Zw, 160, s + 762, 3)
    dist = np.abs(c - np.round(c)) * th["hedgeRise"] / np.maximum(np.hypot(gx_, gz_), 0.05)
    gaps = smoothstep(-0.2, 0.0, fbm(X, Z, 55, s + 763, 2))
    ch = smoothstep(4.0, 1.5, dist) * gaps * zone * (1 - seg) * smoothstep(0.06, 0.12, np.hypot(gx_, gz_))
    return h + 2.2 * ch, wall, ch, zone


def tors(X, Z, h, s):
    """WP-3: granite tors along the moor ridge crest: 2-4 stacks of rounded slabs (5-stud layers shrinking upward,
    sat down into the slope). Returns (h, tor mask)."""
    R = L.MOOR_RIDGE
    rnd = lambda n, k: float(_hash(np.array([n]), np.array([k]), s + 800)[0])  # noqa: E731
    out = h.copy()
    x0 = X[0, 0]
    for n in range(R["tors"]):
        xc = -1600 + 3200 * (n + 0.2 + 0.6 * rnd(n, 0)) / R["tors"]
        if abs(xc - R["colX"]) < 220:  # keep the High Road clear
            continue
        zc = float(ridge_z(np.array([xc]), s)[0]) + 80 * (rnd(n, 1) - 0.5)
        for m in range(2 + int(3 * rnd(n, 2))):
            sx = xc + 26 * (rnd(n, 10 + m) - 0.5) * 2
            sz = zc + 26 * (rnd(n, 20 + m) - 0.5) * 2
            a, b = 7 + 8 * rnd(n, 30 + m), 6 + 6 * rnd(n, 40 + m)
            yaw = math.pi * rnd(n, 50 + m)
            i0, j0 = int((sx - x0) / L.CELL), int((sz - x0) / L.CELL)
            sl = (slice(j0 - 10, j0 + 11), slice(i0 - 10, i0 + 11))
            u = (X[sl] - sx) * math.cos(yaw) + (Z[sl] - sz) * math.sin(yaw)
            v = -(X[sl] - sx) * math.sin(yaw) + (Z[sl] - sz) * math.cos(yaw)
            base = h[j0 - 5:j0 + 6, i0 - 5:i0 + 6].min() - 1
            for k in range(3 + int(4 * rnd(n, 60 + m))):
                sc = 1 - 0.13 * k
                inside = (np.abs(u) / (a * sc)) ** 3 + (np.abs(v) / (b * sc)) ** 3 < 1
                out[sl] = np.where(inside, np.maximum(out[sl], base + 5 * (k + 1)), out[sl])
    return out, out > h + 0.5


# ---------------------------------------------------------------- bake


def bake():
    s = L.SEED
    xs = np.arange(-L.HALF_EXTENT, L.HALF_EXTENT + 1, L.CELL, dtype=np.float64)
    X, Z = np.meshgrid(xs, xs)  # rows are z
    d, H, W = coast_field(X, Z)
    # the bake window cuts Great Gale (it runs on to x -5,600 and z -4,500): close the island inside the window with a
    # rounded, wandering cliff / rocky shore, so it meets the sea all round (no square land edge from the air)
    r6 = (np.abs(X) ** 6 + np.abs(Z) ** 6) ** (1 / 6)
    # WP-3: on the west, north and east sides (not the gameplay south coast or Skerry) the shore swings out into
    # 2-3 headlands and in to round coves per side; headlands are 30-60 stud cliffs, beaches only in the coves
    ws = smoothstep(250, -150, Z)
    lob = np.sin(9 * np.arctan2(Z, X) + np.pi + 1.3 * fbm(X, Z, 900, s + 92))  # pi: a headland at the HighRoad's end
    cove = smoothstep(-0.35, -0.75, lob) * ws
    lobe = (200 * np.maximum(lob, 0) ** 1.6 - 190 * np.maximum(-lob, 0) ** 0.7) * (0.75 + 0.5 * fbm(X, Z, 800, s + 96)) - 60
    d_win = L.HALF_EXTENT - 360 + 110 * fbm(X, Z, 520, s + 90) + lobe * ws - r6
    d_win = np.minimum(d_win, L.HALF_EXTENT - 160 - r6)  # headland tips stay inside the window's 120-stud ramp
    tw_ = smoothstep(-80, 80, d - d_win)[None]  # 1 where the window shore is the nearer coast
    d = np.minimum(d, d_win)
    H_win = (55 + 35 * fbm(X, Z, 300, s + 91)) * (1 - ws) + (45 + 15 * fbm(X, Z, 300, s + 91)) * (1 - cove) * ws
    W_win = np.array([0.55, 0.45, 0, 0, 0])[:, None, None] * (1 - ws) \
        + np.stack([1 - cove, 0 * cove, cove, 0 * cove, 0 * cove]) * ws
    # inland the window coast's kind and height fade back to the island's, so no scarp runs along the medial axis
    # where the nearer coast switches (the long grey rock streaks seen from the air)
    near = (np.exp(-np.maximum(d_win, 0) / 250) * ws + (1 - ws))
    H_win = H + (H_win - H) * near
    W_win = W + (W_win - W) * near[None]
    H = H * (1 - tw_[0]) + H_win * tw_[0]
    W = W * (1 - tw_) + W_win * tw_
    wc, wr, wb, wh, wm = W  # cliff, rocky, beach, harbour, mud

    # irregular coastline: rocky and cliff coasts get headlands and coves, beaches stay smooth
    amp = 34 * wc + 24 * wr + 5 * wb + 12 * wm
    d = d + amp * fbm(X, Z, 220, s + 1) + 0.35 * amp * fbm(X, Z, 60, s + 2)
    land = d >= 0
    dl, ds = np.maximum(d, 0), np.maximum(-d, 0)

    # ---- land
    rise_d = lambda dd: (150 * (1 - np.exp(-dd / 1500)) * (1 + 0.35 * fbm(X, Z, 900, s + 3))  # noqa: E731
                         + 26 * fbm(X, Z, 320, s + 4) * smoothstep(0, 300, dd))
    beacon = 200 * np.exp(-((X - 800) ** 2 + (Z + 2600) ** 2) / (2 * 750 ** 2))  # Gale Beacon [L]
    cliff_l = H * smoothstep(0, 14 + 0.2 * H, dl) * (0.92 + 0.16 * ridged(X, Z, 90, s + 5)) + rise_d(dl)
    rocky_l = (H + 4) * smoothstep(0, 40 + 0.8 * H, dl) + rise_d(dl)
    bw, dw = L.BEACH_WIDTH, L.DUNE_WIDTH
    dune_t = np.clip((dl - bw) / dw, 0, 1)
    dunes = (7 + 9 * (0.5 + 0.5 * fbm(X, Z, 70, s + 6))) * np.sin(np.pi * dune_t) ** 0.8 * (dl > bw)
    dunes = dunes + 3 * np.abs(vnoise(X, Z, 26, s + 7)) * (dl > bw) * (dune_t < 1)
    # T3: sea-cut dune front: a 3-5 stud scarp at the dune toe and a second, lower step behind it (storm cut terraces),
    # falling back off behind the second step
    cut = (3.0 + 1.6 * fbm(X, Z, 90, s + 8)) * smoothstep(bw - 3, bw + 3, dl + 5 * fbm(X, Z, 36, s + 9)) \
        + (1.6 + 1.0 * fbm(X, Z, 70, s + 10)) * smoothstep(bw + 15, bw + 20, dl + 7 * fbm(X, Z, 44, s + 17))
    cut = cut * smoothstep(bw + 52, bw + 30, dl)  # a bank behind the dune toe; the hinterland (roads, pads) keeps its height
    fk = flat_keep(X, Z)
    beach_l = np.minimum(dl, bw) / 28 + dunes + cut * fk + 0.9 * rise_d(np.maximum(dl - bw - dw, 0)) + 1.0 * dune_t
    harb_l = 4 + rise_d(np.maximum(dl - 200, 0))
    mud_l = dl / 90 + 0.5 * rise_d(dl)
    h_land = wc * cliff_l + wr * rocky_l + wb * beach_l + wh * harb_l + wm * mud_l + beacon * smoothstep(0, 400, dl) \
        + moor_ridge(X, Z, dl, s)
    # farmland (the T8 farm mask, before the platform blend) is rolling pasture: no granite knuckles or hummock fields
    farm0 = smoothstep(60, 180, dl) * smoothstep(230, 170, h_land)
    h_land, (gully, outc) = micro_relief(X, Z, h_land, dl, wb, s, fk * (1 - 0.85 * farm0))

    # ---- sea
    shelf = np.where(ds < 600, ds / 30, np.where(ds < 1600, 20 + (ds - 600) / 20, 70 + (ds - 1600) / 9))
    dep = (wc * np.maximum(shelf, np.minimum(ds * 0.6, 45))
           + wr * np.maximum(shelf, np.minimum(ds / 4, 25))
           + wb * shelf
           + wh * np.maximum(shelf, np.minimum(10 + ds * 0.065, 70))
           + wm * ds / 60)
    open_t = smoothstep(80, 400, ds)
    dep = dep + 7 * fbm(X, Z, 420, s + 8) * open_t + 2.5 * fbm(X, Z, 90, s + 9) * smoothstep(20, 200, ds)
    sandwave = 1.4 * np.sin((X * 0.8 + Z * 0.6) / 17 + 2.2 * fbm(X, Z, 200, s + 10)) * smoothstep(60, 400, ds)
    h_sea = -dep + sandwave * smoothstep(-15, -25, -dep)
    h = np.where(land, h_land, h_sea)
    h = np.maximum(h, L.SEABED_FLOOR_Y)

    feat = np.zeros(X.shape, dtype=np.int8)  # 1 reef rock, 2 boulder, 3 gully floor, 4 bar, 5 basin, 6 cove

    # Haven Sands Bar: a sandbar about 1 m under water, tapering at the ends (the mild rips)
    (bx0, bz0), (bx1, bz1) = L.BAR["from"], L.BAR["to"]
    bdx, bdz = bx1 - bx0, bz1 - bz0
    bt = np.clip(((X - bx0) * bdx + (Z - bz0) * bdz) / (bdx * bdx + bdz * bdz), 0, 1)
    off = np.abs(d + L.BAR["offshore"])  # distance from the line BAR.offshore studs out from the beach
    near_bar = np.hypot(X - (bx0 + bt * bdx), Z - (bz0 + bt * bdz)) < 450
    taper = smoothstep(0, 0.2, bt) * smoothstep(1, 0.8, bt)
    bar_h = L.BAR["topY"] - 9 * (off / L.BAR["width"]) ** 2
    bar_mask = near_bar & (wb > 0.6) & ~land & (bar_h > h)
    h = np.where(bar_mask, h + (bar_h - h) * taper, h)
    feat[bar_mask & (taper > 0.3)] = 4

    # rock reefs (granite ledges), scattered boulders
    for reef in L.REEFS:
        cx, cz = reef["center"]
        r = np.hypot(X - cx, Z - cz) * (1 + 0.35 * fbm(X, Z, 120, s + 16))
        m = smoothstep(reef["radius"], reef["radius"] * 0.35, r)
        rid = ridged(X, Z, 70, s + 11) * (0.6 + 0.4 * ridged(X, Z, 25, s + 12))
        top = reef["topY"] - 26 * (1 - rid) - 10 * (1 - m)
        raise_ = (top > h) & (m > 0.02) & ~land
        h = np.where(raise_, h + (top - h) * smoothstep(0, 0.5, m), h)
        feat[raise_ & (m > 0.15)] = 1
    boulder = (_hash(np.floor(X / 20).astype(np.int64), np.floor(Z / 20).astype(np.int64), s + 13) > 0.965) \
        & (h < -18) & (h > -120) & ~land
    bump = 4.5 * np.clip(1 - (np.hypot(X % 20 - 10, Z % 20 - 10) / 9) ** 2, 0, 1)
    h = np.where(boulder, h + bump, h)
    feat[boulder & (bump > 0.5)] = 2

    # Old Ned's kelp gully
    (gx0, gz0), (gx1, gz1) = L.GULLY["from"], L.GULLY["to"]
    gdx, gdz = gx1 - gx0, gz1 - gz0
    gt = np.clip(((X - gx0) * gdx + (Z - gz0) * gdz) / (gdx * gdx + gdz * gdz), 0, 1)
    gdist = np.hypot(X - (gx0 + gt * gdx), Z - (gz0 + gt * gdz)) + 6 * vnoise(X, Z, 30, s + 14)
    gm = smoothstep(L.GULLY["halfWidth"] + 14, L.GULLY["halfWidth"] - 4, gdist) * ~land
    h = np.where(gm > 0, h + (np.minimum(h, L.GULLY["floorY"]) - h) * gm, h)
    feat[gm > 0.6] = 3

    # ---- the harbour: dredged basin inside the greybox breakwater, town platform, the small sand cove
    hb = L.HARBOUR
    in_x = (X >= hb["minX"]) & (X <= hb["maxX"])
    basin = in_x & (Z >= hb["minZ"]) & (Z <= hb["maxZ"] + 8)
    tz = np.clip((Z - hb["minZ"]) / (hb["maxZ"] - hb["minZ"]), 0, 1)
    bed = hb["innerY"] + (hb["mouthY"] - hb["innerY"]) * tz
    bed = np.minimum(bed, hb["mouthY"] + (hb["innerY"] + 4 - hb["mouthY"]) * smoothstep(hb["channelHalf"], hb["channelHalf"] + 60, np.abs(X)))
    toe = smoothstep(0, 46, hb["maxX"] - np.abs(X)) * smoothstep(0, 20, Z - hb["minZ"])
    bed = -9 + (bed + 9) * toe + 0.8 * fbm(X, Z, 40, s + 15)
    h = np.where(basin, bed, h)
    feat[basin] = 5
    land_strip = in_x & (Z < hb["minZ"]) & (Z > -40)
    h = np.where(land_strip, np.maximum(h, 4.0), h)
    # outside the arms, keep the seabed above the breakwater footing (parts reach Y = -40)
    arm_zone = (np.abs(X) < 400) & (Z < hb["maxZ"] + 60) & ~basin & ~land
    h = np.where(arm_zone, np.maximum(h, -36), h)
    cv = L.HARBOUR_COVE
    cove = (X >= cv["minX"]) & (X <= cv["maxX"]) & (Z >= cv["topZ"]) & (Z <= cv["toeZ"] + 70)
    ct = np.clip((Z - cv["topZ"]) / (cv["toeZ"] - cv["topZ"]), 0, 1)
    # T6: a fuller upper beach (ct^1.8, was ^1.3): the dry sand sits above the calm swell (about 1.25 studs), which
    # washed a dark wet sheet over the T5 foreground; the swash band is narrower and further out
    cove_h = cv["topY"] + (cv["toeY"] - cv["topY"]) * ct ** 1.8
    cw = smoothstep(cv["minX"], cv["minX"] + 30, X) * smoothstep(cv["toeZ"] + 70, cv["toeZ"], Z)
    h = np.where(cove, h + (cove_h - h) * cw, h)
    feat[cove & (cw > 0.5)] = 6
    tp = L.TOWN_PLATFORM
    ex = np.maximum(np.maximum(tp["minX"] - X, X - tp["maxX"]), 0)
    ez = np.maximum(np.maximum(tp["minZ"] - Z, Z - tp["maxZ"]), 0)
    tw = smoothstep(tp["blend"], 0, np.hypot(ex, ez)) * (h > 0) * ~basin
    h = h + (tp["y"] - h) * tw
    # T6: harbour hillside: field banks, hummocks, outcrops (after the platform blend, so the town edge stays flat)
    # T8: the same Cornish field pattern on all gentle inland ground below the high moor (was a blotchy heath)
    farm = smoothstep(60, 180, dl) * smoothstep(230, 170, h) * smoothstep(14, 40, np.hypot(ex, ez))  # off the town
    hm = np.maximum(harbour_hill(X, Z), farm) * fk * smoothstep(2, 5, h) * smoothstep(6, 20, dl)
    hdh, hedge, hcid, hrock = hill_relief(X, Z, s)
    h = h + hdh * hm
    h, granite, chedge, hillzone = town_hill(X, Z, h, s)
    hill = (np.maximum(hm, chedge), np.maximum(hedge * hm, chedge), hcid, hrock * hm)
    h, tor = tors(X, Z, h, s)
    granite = granite | tor

    # T8: the bake window cuts the island; ramp land under the sea over the last 120 studs so the edge is no wall
    edge = smoothstep(0, 120, L.HALF_EXTENT - np.maximum(np.abs(X), np.abs(Z)))
    h = np.where(h > -12, -12 + (h + 12) * edge, h)

    # ---- paving first (heights only change here), then materials on the final surface
    h, road_mat, road_edge, road_surf = pave(X, Z, h)
    mat = materials(X, Z, h, d, W, feat, road_edge, road_surf, np.where(land, gully, 0), np.where(land, outc, 0), hill)
    mat = np.where(road_mat != 255, road_mat, mat).astype(np.uint8)
    mat[(X > -180) & (X < 180) & (Z > -62) & (Z < -20)] = MI["Cobblestone"]  # quayside setts
    # the town platform is paved (roads here, footways in Town.paint) or tidy grass, never moor / straw / earth;
    # the blend ring up to the hills is grass with lush patches (rock stays on its steep banks)
    dp = np.hypot(ex, ez)
    soft = np.isin(mat, [MI[k] for k in ("Grass", "LeafyGrass", STRAW, OLIVE, "Ground", WORN, "Mud")])
    town = (Z < tp["maxZ"] + 8) & (h > 2)
    mat = np.where(town & (dp < 40) & (soft | (mat == MI["Rock"]) | (mat == MI["Basalt"])), MI["Grass"], mat)
    lush = fbm(X, Z, 70, s + 95, 2) > 0.25
    mat = np.where(town & (dp >= 40) & (dp < tp["blend"] + 20) & soft, np.where(lush, MI[OLIVE], MI["Grass"]), mat)
    mat = np.where(granite & (road_mat == 255), MI["Rock"], mat).astype(np.uint8)  # retaining walls and tors
    # the town hillside is green fields: no rock dither on its banks or hedges (granite only in the wall runs)
    mat = np.where((hillzone > 0.5) & ~granite & (mat == MI["Rock"]), np.where(lush, MI[OLIVE], MI["Grass"]), mat)
    return xs, h, mat, d


def box_blur(a, r):
    """Mean over a (2r+1)^2 window (edge-clamped), via summed-area tables."""
    k = 2 * r + 1
    p = np.pad(a, ((r + 1, r), (r + 1, r)), mode="edge")
    c = p.cumsum(0).cumsum(1)
    n0, n1 = a.shape
    return (c[k:k + n0, k:k + n1] - c[:n0, k:k + n1] - c[k:k + n0, :n1] + c[:n0, :n1]) / (k * k)


def warp(X, Z, s, amp=48.0, scale=180.0):
    """Domain warp: X, Z pushed by low-frequency noise so patch outlines meander instead of reading as noise blobs."""
    return X + amp * fbm(X, Z, scale, s + 60, 3), Z + amp * fbm(X, Z, scale, s + 61, 3)


def choose(weights, Xw, Zw, ix, iz, seed, patch=None, jitter=0.6, dither=0.55, soft=0.8):
    """Soft argmax per cell: log(weight) + a smooth multi-octave patch noise per material (domain-warped coords; scale,
    amplitude in `patch`) + a little per-cell white noise. Where weights compete the noise decides, so materials form
    coherent organic patches 10-200 studs across whose borders feather over 1-2 cells (Roblox's voxel blending then
    softens them), instead of the old per-cell dither that speckled 2-3 materials into blotches."""
    names = list(weights)
    patch = patch or {}
    cx, cz = np.floor_divide(ix, L.CELL), np.floor_divide(iz, L.CELL)  # voxel cell indices for the blue noise
    best = None
    for k, name in enumerate(names):
        w = np.maximum(np.broadcast_to(weights[name], ix.shape), 0)
        sc, amp = patch.get(name, (60, 1.0))
        # T3: + a fine 6-stud value noise and per-cell jitter: where two weights are within about a log unit the
        # border dithers at voxel scale over the whole fringe (wide weight gradients = wide fringes), no hard edge
        # T4: the per-cell jitter is blue noise through a Gumbel transform (stochastic soft-argmax: where weights are
        # comparable each material wins in proportion, dithered across 2-3 voxels with no clumps), the 10-stud value
        # noise spreads the fringe and soft < 1 flattens the log weights, so smooth fields never threshold into bands
        u = np.clip(blue(cx, cz, seed + 7 * k + 3), 1e-4, 1 - 1e-4)
        score = soft * np.log(w + 1e-6) + amp * fbm(Xw, Zw, sc, seed + 7 * k, 4) + 0.55 * jitter * -np.log(-np.log(u)) \
            + dither * vnoise(ix + 0.5, iz + 0.5, 10, seed + 7 * k + 5)
        if best is None:
            best, idx = score, np.zeros(ix.shape, dtype=np.int64)
        else:
            take = score > best
            best, idx = np.where(take, score, best), np.where(take, k, idx)
    return np.array([MI[n] for n in names], dtype=np.uint8)[idx]


def turf(w, straw, olive):
    """Split a turf weight into Turf / TurfStraw / TurfOlive by the macro fields (0..1)."""
    # T4: Grass (the Turf variant, the only slot that carries the animated Decoration blades) is the main sward again;
    # straw and olive are patches within it
    # T6: Grass's share down (straw / olive patches wider) so the single-colour Decoration blades break into patches
    return {"Grass": 0.85 * w * (1 - 0.6 * straw) * (1 - 0.55 * olive) + 1e-4, STRAW: 0.95 * w * straw,
            OLIVE: 0.9 * w * olive}


def materials(X, Z, h, d, W, feat, road_edge, road_surf, gully, outc, hill=None):
    """Coastal material layering (docs/05 terrain, docs/10 6.1). Weights by slope, height, curvature, distance to the
    sea and to the roads; a soft argmax with domain-warped multi-octave patch noise per material (choose()) on land,
    hard zones under the sea. Land: turf with heather / gorse (Moor) patches, more on cliff tops and the Beacon,
    worn earth on banks and in erosion gullies, mud in wet hollows, rock outcrops and every steep face rock (grass
    never on slopes over ~37 deg). Beaches: wet sand -> dry sand -> a shingle strand line -> marram dunes (Turf with
    sand blowouts) -> turf. Rocky coves: shingle at the back. Harbour foreshore: mud and shingle."""
    s = L.SEED
    wc, wr, wb, wh, wm = W
    gz_, gx_ = np.gradient(box_blur(h, 2), L.CELL)  # 20-stud slope: ignores the micro-relief hummocks (T3)
    slope = np.hypot(gx_, gz_)
    hollow = box_blur(h, 6) - h  # > 0 in hollows and gullies, < 0 on knolls and ridges
    dl, ds = np.maximum(d, 0), np.maximum(-d, 0)
    bw, dw = L.BEACH_WIDTH, L.DUNE_WIDTH
    ix, iz = np.round(X).astype(np.int64), np.round(Z).astype(np.int64)
    Xw, Zw = warp(X, Z, s)
    n_mid = fbm(Xw, Zw, 46, s + 31)  # clumps
    n_big = fbm(X, Z, 420, s + 32)  # regional
    rocky_coast = (wc + wr) > 0.5
    beachy = (wb > 0.5) & (d >= -2)
    cliff_top = smoothstep(260, 40, dl) * smoothstep(0.3, 0.8, wc + 0.6 * wr)  # exposed coastal fringe: heath
    upland = smoothstep(125, 200, h + 30 * n_big)  # Gale Beacon heath
    exposure = smoothstep(-0.2, 0.6, n_big)  # windward moorland swathes

    # ---- land
    # T4: noise-broken slope and height drivers, so slope / height transitions never follow a contour line
    n_fine = fbm(Xw, Zw, 16, s + 33, 3)
    slope_n = slope + 0.06 * n_mid + 0.05 * n_fine
    h_n = h + 14 * fbm(Xw, Zw, 70, s + 34, 3) + 4 * n_fine
    upland = smoothstep(105, 230, h_n + 30 * n_big)
    steep = smoothstep(0.45, 0.75, slope + 0.08 * n_mid)  # 24 -> 37 deg: turf gives way to rock
    crag = smoothstep(0.8, 1.2, slope)
    outcrop = smoothstep(0.915, 0.97, ridged(Xw, Zw, 70, s + 22) + 0.05 * smoothstep(0.15, 0.45, slope)) \
        * smoothstep(14, 32, h) * smoothstep(0.08, 0.2, slope)
    wet_hollow = smoothstep(0.3, 1.5, hollow + 0.3 * n_fine) * smoothstep(0.24, 0.05, slope_n) * smoothstep(95, 45, h_n) \
        * (h > 2.5)
    wet_soft = box_blur(wet_hollow, 3)  # a 28-stud halo round every wet hollow: the trampled mid-tone fringe
    bank = smoothstep(0.22, 0.58, slope_n) * (1 - crag)
    # T3 macro colour: straw on exposed, dry, convex ground; olive in hollows, lee slopes and near water courses
    straw = smoothstep(0.05, 0.6, fbm(Xw, Zw, 150, s + 600, 3) + 0.45 * exposure + 0.35 * cliff_top
                       - 0.6 * smoothstep(0, 1.0, hollow) + 0.2 * smoothstep(0.12, 0.6, slope_n))
    olive = smoothstep(-0.15, 0.5, fbm(Xw, Zw, 120, s + 601, 3) + 0.8 * smoothstep(0, 1.2, hollow) - 0.3 * exposure)
    # T6: the harbour hillside is a patchwork of fields, each its own sward: green pasture, straw / rough grazing,
    # lush olive, heather and gorse heath, bracken; patch noise inside every field
    if hill is not None:
        hm, hedge, hcid, hrock = hill
        hedge = smoothstep(0.3, 0.75, hedge)  # material line narrower than the bank: 1-2 voxels from the air
        fn = 0.08 * fbm(Xw, Zw, 30, s + 740, 2)  # low: each field reads as one even sward
        # mostly green pasture and lush (olive) grass; hay / stubble, heath and bracken fields are the exception
        f_green, f_olive = (hcid < FIELD_GREEN).astype(float), ((hcid >= FIELD_GREEN) & (hcid < FIELD_OLIVE)).astype(float)
        f_straw = ((hcid >= FIELD_OLIVE) & (hcid < FIELD_STRAW)).astype(float)
        f_heath = ((hcid >= FIELD_STRAW) & (hcid < FIELD_HEATH)).astype(float)
        f_brack = (hcid >= FIELD_HEATH).astype(float)
        hstraw = np.clip(0.85 * f_straw + 0.25 * f_heath + 0.45 * f_brack + fn, 0, 1)
        holive = np.clip(0.25 * f_green + 0.9 * f_olive + 0.15 * f_heath + fn, 0, 1)
        straw = straw * (1 - 0.85 * hm) + hstraw * 0.85 * hm
        olive = olive * (1 - 0.85 * hm) + holive * 0.85 * hm
        steep, crag = steep * (1 - 0.85 * hedge), crag * (1 - 0.85 * hedge)  # bank sides are turfed, not cliff
    lw = {
        **turf(1.0 * (1 - steep) * (1 - 0.45 * cliff_top) * (1 - 0.5 * upland) * (1 - 0.2 * exposure), straw, olive),
        "LeafyGrass": (0.03 + 0.6 * cliff_top + 1.2 * upland + 0.05 * exposure + 0.1 * bank) * (1 - steep),
        "Ground": (0.01 + 0.12 * bank + 1.1 * gully * smoothstep(0.2, 0.4, slope)) * (1 - 0.7 * wet_hollow) * (1 - crag),
        WORN: (0.04 + 2.4 * wet_soft * (1 - 0.5 * wet_hollow) + 0.3 * bank * smoothstep(0.3, 0.55, slope_n)
               + 0.9 * box_blur(gully, 2)) * (1 - crag),
        "Mud": 1.7 * wet_hollow + 0.6 * smoothstep(0.5, 0.8, wm) * smoothstep(60, 5, dl),
        "Rock": 6.0 * steep + 4.0 * outcrop + 6.0 * crag + 9.0 * outc + 1e-3,
        "Basalt": 2.0 * steep * smoothstep(0.1, 0.5, n_mid) * smoothstep(60, 15, h),
    }
    if hill is not None:
        heath_p = smoothstep(-0.3, 0.3, fbm(Xw, Zw, 22, s + 741, 3))
        # T7: heath fields and hedge banks were solid Moor (a dark mossy blotch in the HarbourHillside foreground):
        # heath is now patchy over the field's straw / olive sward, banks mostly turf with only a Moor share
        # field floors read as one even sward from the air (the brown / tan blotches were worn turf, earth, moor and
        # outcrops dithered through every field); the hedges are granite-faced banks with gorse
        calm = 1 - 0.92 * hm * (1 - hedge)
        for k in ("LeafyGrass", "Ground", WORN, "Mud", "Basalt"):
            lw[k] = lw[k] * calm
        lw["Rock"] = lw["Rock"] * (1 - 0.8 * hm * (1 - hedge))
        lw["LeafyGrass"] = lw["LeafyGrass"] + hm * (1 - steep) * (0.6 * f_heath * heath_p * heath_p + 0.3 * f_brack) \
            + 0.4 * hedge
        lw[WORN] = lw[WORN] + 0.5 * hm * f_brack * (1 - heath_p)
        lw["Rock"] = lw["Rock"] + 9.0 * hrock + 0.35 * hedge * smoothstep(-0.2, 0.4, fbm(Xw, Zw, 7, s + 742, 2))  # hedge stone
    mat = choose(lw, Xw, Zw, ix, iz, s + 200, {"Grass": (150, 1.6), STRAW: (110, 1.5), OLIVE: (90, 1.4),
                                                "LeafyGrass": (85, 1.6), "Ground": (26, 1.2), WORN: (22, 1.2),
                                                "Mud": (30, 0.8), "Rock": (40, 0.9), "Basalt": (30, 0.8)})

    # rocky / cliff shore above the sea: splash-zone rock, kelp rock at the tide line, shingle at the cove backs
    shore = rocky_coast & (h >= 0) & (np.abs(d) < 60) & (h < 9 + 3 * n_mid)
    cove_back = smoothstep(0.32, 0.12, slope) * smoothstep(8, 2.5, h)
    # T4: the cove back is a strand: wet sand at the foot, shingle, the wrack line at the top of the shingle, then
    # trampled turf; heights noise-broken so the bands wander
    hs = h + 0.5 * n_mid + 0.35 * n_fine
    sz = {"Basalt": 1.0 + 0.5 * smoothstep(3, 8, h), "Rock": 0.7 + 0.6 * smoothstep(4, 9, h),
          "Slate": 2.6 * smoothstep(3.5, 0.5, h) * (1 - 0.6 * cove_back),
          "Sandstone": 3.0 * cove_back * smoothstep(1.8, 0.6, hs),
          SHINGLE: 4.0 * cove_back * smoothstep(0.8, 1.8, hs) * (1 - 0.6 * smoothstep(3.6, 4.6, hs)),
          WRACK: 3.4 * cove_back * smoothstep(2.6, 3.4, hs) * smoothstep(4.8, 3.9, hs),
          WORN: 2.0 * cove_back * smoothstep(4.2, 5.6, hs)}
    # T5: break the single brown: damp dark patches (seepage) up into the shingle, pale dry sand pockets between
    # the shingle and the wrack, a little sand blown up into the worn turf
    cpatch = smoothstep(-0.1, 0.5, fbm(Xw, Zw, 18, s + 262, 3))
    sz["Sandstone"] = sz["Sandstone"] + 0.9 * cove_back * cpatch * smoothstep(2.6, 1.2, hs)  # T6: softer, lower
    sz[RIPPLE] = 1.5 * cove_back * (1 - cpatch) * smoothstep(1.2, 2.0, hs) * smoothstep(4.4, 3.2, hs) \
        * smoothstep(-0.2, 0.4, fbm(Xw, Zw, 24, s + 263, 3))
    sz["Sand"] = 0.9 * cove_back * smoothstep(3.6, 4.6, hs) * smoothstep(-0.1, 0.5, fbm(Xw, Zw, 20, s + 264, 3))
    mat = np.where(shore, choose(sz, Xw, Zw, ix, iz, s + 260, {SHINGLE: (24, 1.0), WRACK: (16, 1.0), "Sandstone": (18, 0.9),
                                                               RIPPLE: (16, 0.9), "Sand": (14, 0.9)}), mat)

    # ---- beaches and dunes: wet sand + kelp rock at the tide line, dry sand, a shingle strand line at the dune toe,
    # then marram (Turf, with sand blowouts) taking over the dunes and heath on the back dunes
    on_sand = beachy & (dl < bw)
    tide = smoothstep(2.2, 1.1, h + 0.4 * n_mid)
    berm = smoothstep(bw - 30, bw - 14, dl + 8 * n_mid) * smoothstep(bw + 4, bw - 6, dl)
    rocky_end = smoothstep(0.75, 0.55, wb)  # beach ends grading into the rocky coast
    # T4: the high-water strand line (wrack) above the wet sand; wind ripples on the upper dry beach
    hh = h + 0.35 * n_mid + 0.3 * n_fine
    strand = smoothstep(1.7, 2.15, hh) * smoothstep(2.9, 2.35, hh) * (0.4 + 0.6 * smoothstep(-0.3, 0.4, fbm(Xw, Zw, 30, s + 304, 3)))
    upper = smoothstep(bw * 0.45, bw * 0.85, dl + 10 * n_mid)
    bwts = {"Sandstone": 4.0 * tide + 1e-3, "Sand": (1.0 - tide) * (1 - 0.6 * berm) * (1 - 0.55 * upper) + 0.02,
            RIPPLE: 1.1 * (1.0 - tide) * upper * (1 - 0.6 * berm), WRACK: 1.6 * strand,
            SHINGLE: 0.8 * berm * smoothstep(-0.35, 0.45, fbm(Xw, Zw, 55, s + 302, 3)) + 0.7 * rocky_end * (1 - tide),
            "Slate": tide * (0.05 + 1.6 * rocky_end) * smoothstep(0.35, 0.7, n_mid + 0.5),
            "Rock": 0.5 * rocky_end * smoothstep(0.2, 0.6, n_mid)}
    # T5: macro variation on the open beach: damp dark patches and runnels on the mid / lower beach, pale dry
    # (rippled) pockets above them, so the beach is no longer one brown between the tide line and the berm
    damp = smoothstep(0.1, 0.55, fbm(Xw, Zw, 26, s + 306, 3)) * smoothstep(bw * 0.75, bw * 0.25, dl + 6 * n_fine)
    pale = smoothstep(0.15, 0.6, fbm(Xw, Zw, 34, s + 307, 3)) * (1 - damp)
    bwts["Sandstone"] = bwts["Sandstone"] + 1.5 * damp * (1 - tide)
    bwts[RIPPLE] = bwts[RIPPLE] + 0.9 * pale * (1.0 - tide) * (1 - upper)
    bwts[WRACK] = bwts[WRACK] + 0.25 * damp * smoothstep(-0.2, 0.5, fbm(Xw, Zw, 12, s + 308, 3))
    mat = np.where(on_sand, choose(bwts, Xw, Zw, ix, iz, s + 300, {"Sandstone": (40, 0.6), "Sand": (40, 0.6),
                                                                   SHINGLE: (14, 1.2), "Slate": (20, 1.0),
                                                                   RIPPLE: (30, 0.8), WRACK: (12, 1.0)}), mat)
    # T3: the dune zone reaches 80 studs past the dunes so blown sand fringes onto the turf; marram is mostly straw
    duney = beachy & (dl >= bw) & (dl < bw + dw + 80) & ((dl < bw + dw + 30) | (slope < 0.45))
    dt = np.clip((dl - bw) / (dw + 30), 0, 1)
    marram = smoothstep(0.08, 0.7, dt + 0.25 * fbm(Xw, Zw, 60, s + 23))
    fringe = smoothstep(bw + dw + 80, bw + dw - 20, dl + 25 * fbm(Xw, Zw, 40, s + 24))
    # T4: open dune faces wind-rippled (SandRipple), slumped steep faces and the turf fringe plain sand
    dwts = {RIPPLE: 1.3 * (1 - marram) * smoothstep(0.7, 0.3, slope) + 0.03,
            "Sand": 0.5 * (1 - marram) + 0.05 + 0.9 * smoothstep(0.3, 0.6, slope) + 0.4 * fringe,
            "Grass": 0.7 * marram, STRAW: 1.0 * marram, OLIVE: 0.15 * marram * (1 - fringe),
            "LeafyGrass": 0.9 * marram * smoothstep(0.55, 1.0, dt), "Ground": 0.01 * marram,
            # T5: damp dune slacks (dark sand in the hollows) and darker blown-sand drifts on the open faces
            "Sandstone": (1 - marram) * (0.9 * smoothstep(0.2, 1.0, hollow) + 0.35 * smoothstep(0.2, 0.6, fbm(Xw, Zw, 22, s + 342, 3)))
            * smoothstep(0.6, 0.25, slope) + 1e-4}
    mat = np.where(duney & (slope < 0.9), choose(dwts, Xw, Zw, ix, iz, s + 340, {"Sand": (22, 1.4), RIPPLE: (26, 1.2), "Grass": (30, 1.2), "Sandstone": (16, 1.0),
                                                                                  STRAW: (40, 1.2), "LeafyGrass": (50, 1.2)},
                                                 jitter=0.8, dither=0.8), mat)

    # ---- harbour foreshore: mud and shingle between the tides outside the quay and the cove
    hb = L.HARBOUR
    fore = (wh > 0.45) & (h > -4) & (h < 3.2) & (d < 60) & ~((feat == 6) | (feat == 5))
    fore &= ~((X > hb["minX"]) & (X < hb["maxX"]) & (Z > -62) & (Z < hb["maxZ"]))
    mat = np.where(fore, choose({"Mud": 1.0 + smoothstep(0, -3, h), SHINGLE: 0.6 + 0.6 * smoothstep(0.5, 2.5, h),
                                 "Slate": 0.15}, Xw, Zw, ix, iz, s + 380, {"Mud": (30, 1.2), SHINGLE: (18, 1.2)}), mat)

    # ---- road verges: gravel and worn earth along the asphalt and the track, worn ground fading into the grass
    land_nat = (h > 0.5) & ~on_sand & ~shore & (slope < 0.8)
    e = road_edge + 2.5 * fbm(Xw, Zw, 14, s + 43, 3)
    gravel = smoothstep(7, 0.5, e) * (road_surf == 1)
    trackside = smoothstep(8, 1.0, e) * (road_surf == 2)
    wear = smoothstep(16, 2, e)
    verge = land_nat & (road_edge < 20)
    # T5: a near-solid 2-4 stud gravel / soil fringe right at the edge (the T4 dither let the turf touch the road),
    # soil spilling a little further in clumpy fingers
    lip = smoothstep(4.5, 1.0, road_edge + 1.2 * fbm(Xw, Zw, 8, s + 44, 2))
    spill = smoothstep(8, 2.5, e) * smoothstep(-0.2, 0.4, fbm(Xw, Zw, 10, s + 45, 3))
    vw = {"Pavement": 2.4 * gravel ** 1.5 + 0.9 * trackside + 5.0 * lip * (road_surf == 1),
          "Ground": 0.3 * gravel + 1.1 * trackside + 0.3 * wear + 1.6 * lip + 1.2 * spill,
          **turf(1.0 - 0.6 * wear, np.clip(straw + 0.4 * wear, 0, 1), olive * (1 - wear)), "LeafyGrass": 0.2 + 0.15 * wear}
    mat = np.where(verge, choose(vw, Xw, Zw, ix, iz, s + 420, {"Ground": (12, 1.0), "Grass": (40, 0.8)},
                                 jitter=0.9, dither=0.8), mat)
    mat = np.where(verge & (slope > 0.7), MI["Rock"], mat)  # road cuttings: rock, not grass

    # ---- seabed (under the mesh ocean)
    sea = h < 0
    mat[sea] = MI[SEABED_SAND]
    mat[sea & (wb > 0.4) & (h > -6)] = MI["Sandstone"]
    gravel = sea & (h < -25) & (fbm(X, Z, 150, s + 24) > 0.32 - 0.004 * np.clip(-h - 25, 0, 80))
    mat[gravel] = MI["Limestone"]
    near_rock = sea & rocky_coast & (ds < 70 + 50 * fbm(X, Z, 60, s + 25))
    mat[near_rock & (h >= -6)] = MI["Basalt"]
    mat[near_rock & (h < -6) & (h > -45)] = MI["Slate"]
    mat[near_rock & (h <= -45)] = MI["Rock"]
    mat[sea & (slope > 0.9)] = MI["Rock"]
    reef = feat == 1
    mat[reef & (h >= -6)] = MI["Rock"]
    mat[reef & (h < -6) & (h > -45)] = MI["Slate"]
    mat[reef & (h <= -45)] = MI["Rock"]
    mat[feat == 2] = MI["Rock"]
    for kb in L.KELP_BEDS:
        cx, cz = kb["center"]
        inbed = (np.hypot(X - cx, Z - cz) < kb["radius"]) & sea & (h < -6) & (h > -48)
        mat[inbed & ((mat == MI["Rock"]) | (mat == MI["Basalt"]) | (slope > 0.3))] = MI["Slate"]
    mat[(feat == 3) & (h <= L.GULLY["floorY"] + 2)] = MI["Limestone"]
    mat[(feat == 3) & (h > L.GULLY["floorY"] + 2)] = MI["Slate"]
    mat[(feat == 4)] = MI["Sandstone"]
    mat[(feat == 5) & (Z < 250)] = MI["Mud"]
    mat[(feat == 5) & (Z >= 250)] = MI[SEABED_SAND]
    # Harbour Cove: shingle at the back, then dry sand, wet sand at the tide line
    hc = h + 0.8 * fbm(X, Z, 20, s + 44)
    c6 = feat == 6
    # T4: banded by noise-broken height through choose() instead of hard thresholds: wet sand, dry sand, shingle,
    # the wrack line along the top of the shingle
    cw6 = {"Sandstone": smoothstep(2.0, 1.0, hc) + 1e-3, "Sand": smoothstep(1.0, 1.8, hc) * smoothstep(3.4, 2.6, hc),
           SHINGLE: 1.2 * smoothstep(2.6, 3.4, hc), WRACK: 1.8 * smoothstep(3.3, 3.8, hc) * smoothstep(4.8, 4.0, hc)}
    # T5: damp patches up the beach and pale dry pockets under the shingle
    c6p = smoothstep(-0.1, 0.5, fbm(X, Z, 16, s + 462, 3))
    cw6["Sandstone"] = cw6["Sandstone"] + 0.6 * c6p * smoothstep(2.2, 1.2, hc)  # T6: damp patches only near the tide
    cw6[RIPPLE] = 1.0 * (1 - c6p) * smoothstep(1.4, 2.0, hc) * smoothstep(3.6, 2.8, hc)
    ixc, izc = np.round(X).astype(np.int64), np.round(Z).astype(np.int64)
    m6 = choose(cw6, X, Z, ixc, izc, s + 460, {SHINGLE: (16, 0.8), WRACK: (12, 0.8), "Sandstone": (14, 0.8), RIPPLE: (14, 0.8)})
    mat[c6] = m6[c6]
    return mat


def catmull(points, step):
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (np.array(p, dtype=float) for p in pts[i - 1:i + 3])
        n = max(2, int(np.linalg.norm(p2 - p1) / step))
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(points[-1], dtype=float))
    return np.array(out)


def sample(h, x, z):
    n = h.shape[0]
    u = np.clip((x + L.HALF_EXTENT) / L.CELL, 0, n - 1.001)
    v = np.clip((z + L.HALF_EXTENT) / L.CELL, 0, n - 1.001)
    i, j = int(u), int(v)
    fu, fv = u - i, v - j
    return (h[j, i] * (1 - fu) * (1 - fv) + h[j, i + 1] * fu * (1 - fv) + h[j + 1, i] * (1 - fu) * fv
            + h[j + 1, i + 1] * fu * fv)


def stamp(X, Z, h, mat, paths, surface_mat):
    """paths: list of (points Nx2, y N, halfwidth). Flatten to y within halfwidth, blend in a shoulder."""
    best = np.full(h.shape, 1e9)
    target = np.zeros(h.shape)
    halfw = np.zeros(h.shape)
    for pts, ys, hw in paths:
        r = int(math.ceil((hw + 16) / L.CELL)) + 1
        for (px, pz), py in zip(pts, ys):
            i0 = int(round((px + L.HALF_EXTENT) / L.CELL))
            j0 = int(round((pz + L.HALF_EXTENT) / L.CELL))
            sl = (slice(max(j0 - r, 0), j0 + r + 1), slice(max(i0 - r, 0), i0 + r + 1))
            dd = np.hypot(X[sl] - px, Z[sl] - pz)
            closer = dd < best[sl]
            best[sl] = np.where(closer, dd, best[sl])
            target[sl] = np.where(closer, py, target[sl])
            halfw[sl] = np.where(closer, hw, halfw[sl])
    core = best <= halfw
    blend = smoothstep(halfw + 16, halfw, best)
    h = np.where(best < halfw + 16, h + (target - h) * blend, h)
    mat = np.where(core, surface_mat, mat).astype(np.uint8)
    return h, mat, best - halfw


def pave(X, Z, h):
    """Car parks and roads: flattens h; returns (h, surface material or 255, distance outside the nearest road or
    track edge, which kind it is: 1 asphalt, 2 earth track, 0 other)."""
    mat = np.full(h.shape, 255, dtype=np.uint8)
    edge = np.full(h.shape, 1e9)
    kind = np.zeros(h.shape, dtype=np.int8)
    for cp in L.CAR_PARKS + L.FARMS:
        cx, cz = cp["center"]
        sx, sz = cp["size"]
        a = math.radians(cp["yaw"])
        lx = (X - cx) * math.cos(a) + (Z - cz) * math.sin(a)
        lz = -(X - cx) * math.sin(a) + (Z - cz) * math.cos(a)
        e = np.hypot(np.maximum(np.abs(lx) - sx / 2, 0), np.maximum(np.abs(lz) - sz / 2, 0))
        y = max(float(sample(h, cx, cz)), 4.0)
        h = h + (y - h) * smoothstep(20, 0, e)
        mat = np.where(e <= 0, MI[cp["surface"]], mat).astype(np.uint8)
        closer = e < edge
        edge = np.where(closer, e, edge)
        kind = np.where(closer, {"Asphalt": 1, "Ground": 2}.get(cp["surface"], 0), kind)
    for road in L.ROADS:
        pts = catmull(road["points"], 4)
        ys = np.array([sample(h, x, z) for x, z in pts])
        if road["surface"] == "Concrete":  # slipway: a straight ramp down to 1 m under water
            ys = np.linspace(max(ys[0], 3.0), -3.0, len(ys))
        else:
            k = 21
            pad = np.pad(ys, k // 2, mode="edge")
            for _ in range(3):
                ys = np.convolve(pad, np.ones(k) / k, mode="valid")
                pad = np.pad(ys, k // 2, mode="edge")
            ys = np.maximum(ys, 3.5)
        road["_y"] = ys
        road["_pts"] = pts
        h, mat, e = stamp(X, Z, h, mat, [(pts, ys, road["width"] / 2)], MI[road["surface"]])
        closer = e < edge
        edge = np.where(closer, e, edge)
        kind = np.where(closer, {"Asphalt": 1, "Ground": 2}.get(road["surface"], 0), kind)
    return h, mat, edge, kind


# ---------------------------------------------------------------- outputs


def luau_value(v, indent):
    tab = "\t" * indent
    if isinstance(v, dict):
        inner = "".join(f"{tab}\t{k} = {luau_value(v[k], indent + 1)},\n" for k in v)
        return "{\n" + inner + tab + "}"
    if isinstance(v, (list, tuple)):
        inner = "".join(f"{tab}\t{luau_value(x, indent + 1)},\n" for x in v)
        return "{\n" + inner + tab + "}"
    if isinstance(v, Vec):
        return f"Vector3.new({fmt(v.x)}, {fmt(v.y)}, {fmt(v.z)})"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return fmt(v)
    return json.dumps(v)


class Vec:
    def __init__(self, x, y, z):
        self.x, self.y, self.z = x, y, z


def fmt(n):
    n = round(float(n), 1)
    return str(int(n)) if n == int(n) else str(n)


def write_worldconfig(h):
    def y_at(x, z):
        return round(float(sample(h, x, z)), 1)

    def pos(p):
        x, y, z = p
        return Vec(x, y if y is not None else y_at(x, z), z)

    roads = []
    for r in L.ROADS:
        pts = r["_pts"][::6].tolist() + [r["_pts"][-1].tolist()]
        ys = list(r["_y"][::6]) + [r["_y"][-1]]
        road = {"id": r["id"], "name": r["name"], "surface": r["surface"], "width": r["width"],
                "points": [Vec(p[0], y, p[1]) for p, y in zip(pts, ys)]}
        if "town" in r:
            road["town"] = r["town"]
        roads.append(road)
    cfg = {
        "MapRadius": L.MVP_RADIUS,
        "SeaLevel": 0,
        "Terrain": {"cell": L.CELL, "halfExtent": L.HALF_EXTENT, "seabedFloorY": L.SEABED_FLOOR_Y, "seed": L.SEED},
        "Roads": roads,
        "Towns": [{"id": t["id"], "name": t["name"], "origin": pos((t["origin"][0], None, t["origin"][1])),
                   "width": t["width"], "footway": t["footway"], "avenues": [a for a, _ in t["avenues"]],
                   "streets": [b for b, _ in t["streets"]], "keep": [list(k) for k in t["keep"]]}
                  for t in L.TOWNS],
        "CarParks": [{"id": c["id"], "name": c["name"], "surface": c["surface"],
                      "center": pos((c["center"][0], None, c["center"][1])), "size": list(c["size"]), "yaw": c["yaw"]}
                     for c in L.CAR_PARKS],
        "Farms": [{"id": c["id"], "name": c["name"], "center": pos((c["center"][0], None, c["center"][1])),
                   "size": list(c["size"]), "yaw": c["yaw"]} for c in L.FARMS],
        "Points": [{"id": p["id"], "kind": p["kind"], "position": pos(p["pos"])} for p in L.POINTS],
        "POIs": [{"id": p["id"], "kind": p["kind"], "name": p["name"], "era": p["era"], "blurb": p["blurb"],
                  "position": pos(p["pos"]), "yaw": p["yaw"], "length": p["length"], "beam": p["beam"]}
                 for p in L.POIS],
        "Reefs": [{"id": r["id"], "center": Vec(r["center"][0], r["topY"], r["center"][1]), "radius": r["radius"]}
                  for r in L.REEFS],
        "KelpBeds": [{"id": k["id"], "center": Vec(k["center"][0], 0, k["center"][1]), "radius": k["radius"]}
                     for k in L.KELP_BEDS],
        "Eelgrass": [{"id": k["id"], "center": Vec(k["center"][0], 0, k["center"][1]), "radius": k["radius"]}
                     for k in L.EELGRASS],
        "Beaches": [{"id": "HavenSands", "name": "Haven Sands", "from": pos((640, None, 130)),
                     "to": pos((1340, None, 590)), "sandWidth": L.BEACH_WIDTH, "duneWidth": L.DUNE_WIDTH,
                     "bar": {"from": Vec(L.BAR["from"][0], L.BAR["topY"], L.BAR["from"][1]),
                             "to": Vec(L.BAR["to"][0], L.BAR["topY"], L.BAR["to"][1]),
                             "offshore": L.BAR["offshore"]}}],
    }
    body = "".join(f"\t{k} = {luau_value(v, 1)},\n" for k, v in cfg.items())
    src = ("--!strict\n-- GENERATED by tools/world/gen_terrain.py from tools/world/layout.py. Do not edit by hand.\n"
           "-- WorldConfig: the Gale Isles layout as pure data (docs/10-world-and-map.md): road splines (Y from the\n"
           "-- terrain bake), car parks, launch / spawn / handover points, seabed points of interest, reefs and\n"
           "-- kelp beds. Studs from the station slipway; +X east, -Z north, sea level Y = 0. Safe to load in Lune.\n\n"
           "local WorldConfig = {\n" + body + "}\n\nreturn WorldConfig\n")
    path = os.path.join(REPO, "src/shared/Config/WorldConfig.luau")
    with open(path, "w") as f:
        f.write(src)
    return path


def preview(h, mat, path):
    from PIL import Image
    colors = {"Sand": (205, 187, 152), "Sandstone": (140, 123, 98), "Salt": (170, 160, 130), "Limestone": (190, 185, 170),
              "Rock": (120, 118, 112), "Slate": (75, 74, 38), "Basalt": (55, 55, 58), "Grass": (96, 128, 70),
              "LeafyGrass": (110, 90, 100), "Mud": (90, 75, 60), "Ground": (120, 100, 75), "Asphalt": (40, 40, 42),
              "Cobblestone": (110, 105, 100), "Concrete": (180, 180, 175), "Pavement": (150, 150, 150), "Air": (0, 0, 0), "Snow": (150, 135, 90), "WoodPlanks": (80, 95, 55),
              SHINGLE: (105, 98, 90), WORN: (100, 92, 66), RIPPLE: (200, 182, 146), WRACK: (90, 80, 55)}
    lut = np.array([colors[m] for m in MATERIALS], dtype=np.float64)
    rgb = lut[mat]
    gz_, gx_ = np.gradient(h, L.CELL)
    shade = np.clip(0.75 + 0.6 * (-gx_ * 0.6 - gz_ * 0.4), 0.35, 1.3)
    rgb = rgb * shade[..., None]
    water = h < 0
    depth = np.clip(-h / 120, 0, 1)[..., None]
    tint = np.array([40, 110, 110]) * (1 - depth) + np.array([15, 40, 60]) * depth
    rgb = np.where(water[..., None], rgb * 0.45 + tint * 0.55, rgb)
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    img = img.resize((900, 900), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def main():
    xs, h, mat, _ = bake()
    out = os.path.join(REPO, "map/generated")
    os.makedirs(out, exist_ok=True)
    hq = np.clip(np.round(h * 8), -32768, 32767).astype("<i2")
    hq.tofile(os.path.join(out, "terrain_height.i16"))
    mat.astype(np.uint8).tofile(os.path.join(out, "terrain_material.u8"))
    counts = {MATERIALS[i]: int(c) for i, c in enumerate(np.bincount(mat.ravel(), minlength=len(MATERIALS))) if c}
    meta = {"generator": "tools/world/gen_terrain.py", "seed": L.SEED, "cell": L.CELL, "originX": float(xs[0]),
            "originZ": float(xs[0]), "nx": int(len(xs)), "nz": int(len(xs)), "heightScale": 8,
            "height": "terrain_height.i16", "material": "terrain_material.u8", "materials": MATERIALS,
            "shellLand": 40, "shellSea": 20,
            "stats": {"minY": round(float(h.min()), 1), "maxY": round(float(h.max()), 1),
                      "landFraction": round(float((h > 0).mean()), 3), "cells": counts}}
    with open(os.path.join(out, "terrain.json"), "w") as f:
        json.dump(meta, f, indent=1)
    wc = write_worldconfig(h)
    if "--preview" in sys.argv:
        preview(h, mat, sys.argv[sys.argv.index("--preview") + 1])
    print(f"baked {len(xs)}x{len(xs)} @ {L.CELL} studs, Y {h.min():.1f}..{h.max():.1f}, land {meta['stats']['landFraction']}")
    print("wrote", out, "and", wc)


if __name__ == "__main__":
    main()
