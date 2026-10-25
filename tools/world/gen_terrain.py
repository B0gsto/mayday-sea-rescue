#!/usr/bin/env python3
"""Deterministic heightmap + material map baker for the Gale Isles (docs/10-world-and-map.md).

usage: python3 tools/world/gen_terrain.py [--preview build/world/terrain_preview.png]

Reads tools/world/layout.py (island polygons, coast kinds, basins, reefs, POIs) and writes
  map/generated/terrain.json          grid metadata, material table, stats
  map/generated/terrain_height.i16    int16 LE, surface Y * 8, row-major [z][x], CELL-stud samples
  map/generated/terrain_material.u8   uint8 material index (terrain.json "materials")
  src/shared/Config/WorldConfig.luau  pure-data module: the island ring, islands, POIs (generated)
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


def coast_field(X, Z, islands):
    """Signed distance to the nearest island coast (+ on land), the coast-top height H and kind weights."""
    best_d = np.full(X.shape, -1e9)
    best_H = np.zeros(X.shape)
    best_w = np.zeros((len(L.KINDS),) + X.shape)
    for poly in islands:
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


def micro_relief(X, Z, hl, dl, wb, s, fk=1.0):
    """Land micro-relief: hummocks (0.5-1 stud), sheep-track terracettes along the contours of moderate slopes, and
    erosion gullies (up to 2 studs deep) running down the fall line of steeper banks. Masked off the beach, the dunes
    and the waterline. Returns (height, gully mask for the materials)."""
    gz_, gx_ = np.gradient(box_blur(hl, 10), L.CELL)  # fall line, smoothed over ~84 studs
    g = np.maximum(np.hypot(gx_, gz_), 1e-6)
    sz_, sx_ = np.gradient(box_blur(hl, 1), L.CELL)
    slope = np.hypot(sx_, sz_)
    Xw, Zw = warp(X, Z, s + 500, 30, 120)
    keep = smoothstep(4, 24, dl) * smoothstep(0.6, 0.35, wb)
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


def bake_island(isl):
    """One bake window (layout.HUB_WINDOW or an ARCHIPELAGO island, docs/21 6.1): only its own polygons, with the
    coast profiles plus gaussian peaks, flat pads, dredged basins and
    shoals (reef rock or lagoon sand); the seabed ramps to the deep floor at the window edge over `edgeRamp` studs.
    Rough massing only: the per-island build modules (src/server/World/Islands) dress it. Returns (xs, zs, h, mat)."""
    s = L.SEED
    x0, z0, x1, z1 = isl["window"]
    xs = np.arange(x0, x1 + 1, L.CELL, dtype=np.float64)
    zs = np.arange(z0, z1 + 1, L.CELL, dtype=np.float64)
    X, Z = np.meshgrid(xs, zs)  # rows are z
    d, H, W = coast_field(X, Z, isl["polys"])
    wc, wr, wb, wh, wm = W
    amp = 34 * wc + 24 * wr + 5 * wb + 12 * wm
    d = d + amp * fbm(X, Z, 220, s + 1) + 0.35 * amp * fbm(X, Z, 60, s + 2)
    land = d >= 0
    dl, ds = np.maximum(d, 0), np.maximum(-d, 0)

    # land: the main bake's coast profiles on a smaller island rise, plus the island's hills
    rise = lambda dd: (40 * (1 - np.exp(-dd / 400)) * (1 + 0.35 * fbm(X, Z, 500, s + 3))  # noqa: E731
                       + 10 * fbm(X, Z, 200, s + 4) * smoothstep(0, 150, dd))
    cliff_l = H * smoothstep(0, 14 + 0.2 * H, dl) * (0.92 + 0.16 * ridged(X, Z, 90, s + 5)) + rise(dl)
    rocky_l = (H + 4) * smoothstep(0, 40 + 0.8 * H, dl) + rise(dl)
    bw, dw = 50, 60
    dune_t = np.clip((dl - bw) / dw, 0, 1)
    dunes = (4 + 6 * (0.5 + 0.5 * fbm(X, Z, 70, s + 6))) * np.sin(np.pi * dune_t) ** 0.8 * (dl > bw)
    beach_l = np.minimum(dl, bw) / 20 + dunes + 0.9 * rise(np.maximum(dl - bw - dw, 0)) + 1.5 * dune_t
    harb_l = 4 + rise(np.maximum(dl - 120, 0))
    mud_l = dl / 90 + 0.5 * rise(dl)
    peaks = sum(ph * np.exp(-((X - px) ** 2 + (Z - pz) ** 2) / (2 * pr ** 2)) for px, pz, ph, pr in isl["peaks"])
    h_land = wc * cliff_l + wr * rocky_l + wb * beach_l + wh * harb_l + wm * mud_l + peaks * smoothstep(0, 80, dl)
    h_land, (gully, outc) = micro_relief(X, Z, h_land, dl, wb, s)

    # sea: the main shelf, a little steeper (small islands drop off faster). The kind weights are blurred (~100
    # studs) first: coast_field switches hard between polygons, which left step lines on the seabed between stacks
    shelf = np.where(ds < 400, ds / 25, np.where(ds < 1000, 16 + (ds - 400) / 15, 56 + (ds - 1000) / 8))
    sc, sr, sb, sh, sm = (box_blur(w, 12) for w in W)
    dep = (sc * np.maximum(shelf, np.minimum(ds * 0.6, 45)) + sr * np.maximum(shelf, np.minimum(ds / 4, 25))
           + sb * shelf + sh * np.maximum(shelf, np.minimum(10 + ds * 0.065, 70)) + sm * ds / 60)
    dep = dep + 7 * fbm(X, Z, 420, s + 8) * smoothstep(80, 400, ds) + 2.5 * fbm(X, Z, 90, s + 9) * smoothstep(20, 200, ds)
    if not isl["polys"]:  # docs/23 (p): a window with no island (the ring) is deep floor until its shoals raise it
        dep = np.full(X.shape, -float(L.SEABED_FLOOR_Y))
    h = np.where(land, h_land, -dep)

    feat = np.zeros(X.shape, dtype=np.int8)  # 1 reef rock (materials())
    for cx, cz, rad, top, rock in isl.get("shoals", []):
        r = np.hypot(X - cx, Z - cz) * (1 + 0.3 * fbm(X, Z, 120, s + 16))
        m = smoothstep(rad, rad * 0.4, r)
        if rock:
            t = top - 22 * (1 - ridged(X, Z, 70, s + 11) * (0.6 + 0.4 * ridged(X, Z, 25, s + 12))) - 10 * (1 - m)
        else:
            t = top - 2.5 * (0.5 + 0.5 * fbm(X, Z, 60, s + 18)) - 6 * (1 - m)
        up = (t > h) & (m > 0.02) & ~land
        h = np.where(up, h + (t - h) * smoothstep(0, 0.5, m), h)
        if rock:
            feat[up & (m > 0.15)] = 1
    for px0, pz0, px1, pz1, py in isl["pads"]:
        inside = (X >= px0) & (X <= px1) & (Z >= pz0) & (Z <= pz1)
        py = float(h[inside].mean()) if py is None else py
        e = np.hypot(np.maximum(np.maximum(px0 - X, X - px1), 0), np.maximum(np.maximum(pz0 - Z, Z - pz1), 0))
        h = h + (py - h) * smoothstep(160, 0, e) * (h > 0)
    for cx, cz, rad, fy in isl.get("basins", []):
        m = smoothstep(rad, rad * 0.5, np.hypot(X - cx, Z - cz)) * (h < 1)
        h = h + (np.minimum(h, fy + 0.8 * fbm(X, Z, 40, s + 15)) - h) * m

    # window edge: down to the deep floor
    sides = np.minimum.reduce([X - x0, x1 - X, Z - z0, z1 - Z])
    h = h + (L.SEABED_FLOOR_Y - h) * smoothstep(isl.get("edgeRamp", 260), 0, sides)
    h = np.maximum(h, L.SEABED_FLOOR_Y)

    mat = materials(X, Z, h, d, W, feat, np.where(land, gully, 0), np.where(land, outc, 0))
    # biome accents: guano / chalk streaks on the cliffs, dark wet rock on the reef
    rockish = (mat == MI["Rock"]) | (mat == MI["Basalt"])
    # streaks only (ShellGravel is pale: wider cover read as a sand dune from the sea in Studio)
    streak = fbm(X * 3, Z, 40, s + 900, 3) > {"chalk": 0.3, "guano": 0.25}.get(isl["biome"], 9)
    mat = np.where((h > 6) & rockish & streak, MI["Limestone"], mat)
    if isl["biome"] == "guano":  # a dark granite stack, not a turf hump: the whole top is bare rock
        mat = np.where((h > 6) & ~rockish & (mat != MI["Limestone"]), MI["Rock"], mat)
    if isl["biome"] == "reef":
        mat = np.where((h > 0) & rockish, MI["Basalt"], mat)
    return xs, zs, h, mat.astype(np.uint8)


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


def materials(X, Z, h, d, W, feat, gully, outc):
    """Coastal material layering (docs/05 terrain, docs/10 6.1). Weights by slope, height, curvature, distance to the
    sea; a soft argmax with domain-warped multi-octave patch noise per material (choose()) on land,
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
    fore = (wh > 0.45) & (h > -4) & (h < 3.2) & (d < 60)
    mat = np.where(fore, choose({"Mud": 1.0 + smoothstep(0, -3, h), SHINGLE: 0.6 + 0.6 * smoothstep(0.5, 2.5, h),
                                 "Slate": 0.15}, Xw, Zw, ix, iz, s + 380, {"Mud": (30, 1.2), SHINGLE: (18, 1.2)}), mat)

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
    return mat


# ---------------------------------------------------------------- outputs


def luau_value(v, indent):
    tab = "\t" * indent
    if isinstance(v, dict):
        inner = "".join(f"{tab}\t{k} = {luau_value(v[k], indent + 1)},\n" for k in v)
        return "{\n" + inner + tab + "}"
    if isinstance(v, (list, tuple)):
        inner = "".join(f"{tab}\t{luau_value(x, indent + 1)},\n" for x in v)
        return "{\n" + inner + tab + "}"
    if isinstance(v, Raw):
        return str(v)
    if isinstance(v, Vec):
        return f"Vector3.new({fmt(v.x)}, {fmt(v.y)}, {fmt(v.z)})"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return fmt(v)
    return json.dumps(v)


class Raw(str):
    pass


class Vec:
    def __init__(self, x, y, z):
        self.x, self.y, self.z = x, y, z


def fmt(n):
    n = round(float(n), 1)
    return str(int(n)) if n == int(n) else str(n)


def write_worldconfig(wins):
    def y_at(x, z):  # bake height at (x, z) from the window that holds it (deep floor outside every window)
        for wx, wz, wh in wins.values():
            if wx[0] <= x <= wx[-1] and wz[0] <= z <= wz[-1]:
                u = np.clip((x - wx[0]) / L.CELL, 0, len(wx) - 1.001)
                v = np.clip((z - wz[0]) / L.CELL, 0, len(wz) - 1.001)
                i, j = int(u), int(v)
                fu, fv = u - i, v - j
                return round(float(wh[j, i] * (1 - fu) * (1 - fv) + wh[j, i + 1] * fu * (1 - fv)
                                   + wh[j + 1, i] * (1 - fu) * fv + wh[j + 1, i + 1] * fu * fv), 1)
        return float(L.SEABED_FLOOR_Y)

    def ipos(isl, key):
        x, z = isl[key]
        return Vec(x, max(y_at(x, z), 0), z)

    def pos(p):
        x, y, z = p
        return Vec(x, y if y is not None else y_at(x, z), z)

    py = L.PLATEAU_Y
    cfg = {
        "MapRadius": L.MAP_RADIUS,
        "SeaLevel": 0,
        "Terrain": {"cell": L.CELL, "seabedFloorY": L.SEABED_FLOOR_Y, "seed": L.SEED,
                    "windows": [{"id": i["id"], "min": Vec(i["window"][0], L.SEABED_FLOOR_Y, i["window"][1]),
                                 "max": Vec(i["window"][2], 0, i["window"][3])} for i in L.ISLAND_WINDOWS]},
        # docs/23 (p): the six player islands in a ring round an open lagoon (HubLayout.luau lays the lots, berths and
        # bridges out from this). Bearings: 0 east, 90 south; islandNotch = the berth cove, facing out to sea
        "Ring": {"center": Vec(L.CENTER[0], py, L.CENTER[1]), "plateauY": py, "radius": L.RING["radius"],
                 "islandRadius": L.RING["islandRadius"], "islandNotch": L.RING["notch"],
                 "islands": [{"id": p["id"], "bearing": p["bearing"],
                              "center": Vec(p["center"][0], py, p["center"][1])} for p in L.PLAYER_ISLANDS]},
        # docs/21: one row per explorable island. landmark / stamp / landing sit on the bake surface; dock at sea
        # level (a boat's stop, B3's DropOff dock); radius = the island's zone
        "Islands": [{"id": i["id"], "name": i["name"], "center": Vec(i["center"][0], 0, i["center"][1]),
                     "radius": i["radius"], "landmark": ipos(i, "landmark"), "stamp": ipos(i, "stamp"),
                     "landing": ipos(i, "landing"), "dock": Vec(i["dock"][0], 0, i["dock"][1]),
                     "pads": [{"min": Vec(p[0], 0, p[1]), "max": Vec(p[2], 0, p[3]),
                               "y": y_at((p[0] + p[2]) / 2, (p[1] + p[3]) / 2)} for p in i.get("pads", [])]}
                    for i in L.ARCHIPELAGO],
        "POIs": [{"id": p["id"], "kind": p["kind"], "name": p["name"], "era": p["era"], "blurb": p["blurb"],
                  "position": pos(p["pos"]), "yaw": p["yaw"], "length": p["length"], "beam": p["beam"]}
                 for p in L.POIS],
        "Reefs": [{"id": r["id"], "center": Vec(r["center"][0], r["topY"], r["center"][1]), "radius": r["radius"]}
                  for r in L.REEFS],
        "KelpBeds": [{"id": k["id"], "center": Vec(k["center"][0], 0, k["center"][1]), "radius": k["radius"]}
                     for k in L.KELP_BEDS],
    }
    body = "".join(f"\t{k} = {luau_value(v, 1)},\n" for k, v in cfg.items())
    src = ("--!strict\n-- GENERATED by tools/world/gen_terrain.py from tools/world/layout.py. Do not edit by hand.\n"
           "-- WorldConfig: the Gale Isles layout as pure data (docs/23 (p), docs/21): the ring of six player\n"
           "-- islands, the outer islands, seabed points of interest, reefs and kelp beds. Studs from the map centre;\n"
           "-- +X east, -Z north, sea level Y = 0. Safe to load in Lune.\n\n"
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
    xs, zs, h, mat = bake_island(L.HUB_WINDOW)  # the main grid: the ring's open water (the islands are Lego plates)
    out = os.path.join(REPO, "map/generated")
    os.makedirs(out, exist_ok=True)
    hq = np.clip(np.round(h * 8), -32768, 32767).astype("<i2")
    hq.tofile(os.path.join(out, "terrain_height.i16"))
    mat.astype(np.uint8).tofile(os.path.join(out, "terrain_material.u8"))
    counts = {MATERIALS[i]: int(c) for i, c in enumerate(np.bincount(mat.ravel(), minlength=len(MATERIALS))) if c}
    # outer islands (docs/21 6.1): one small grid per island next to the main one, same format
    windows, wins = [], {"Hub": (xs, zs, h)}
    for isl in L.ISLAND_WINDOWS:
        wx, wz, wh, wm = bake_island(isl)
        name = f"island_{isl['id']}"
        np.clip(np.round(wh * 8), -32768, 32767).astype("<i2").tofile(os.path.join(out, name + "_height.i16"))
        wm.tofile(os.path.join(out, name + "_material.u8"))
        windows.append({"id": isl["id"], "originX": float(wx[0]), "originZ": float(wz[0]), "nx": int(len(wx)),
                        "nz": int(len(wz)), "height": name + "_height.i16", "material": name + "_material.u8",
                        "maxY": round(float(wh.max()), 1), "landFraction": round(float((wh > 0).mean()), 3)})
        wins[isl["id"]] = (wx, wz, wh)
        if "--preview" in sys.argv:
            preview(wh, wm, sys.argv[sys.argv.index("--preview") + 1].replace(".png", f"_{isl['id']}.png"))
        print(f"baked {isl['id']} {len(wx)}x{len(wz)}, Y {wh.min():.1f}..{wh.max():.1f}, land {windows[-1]['landFraction']}")
    meta = {"generator": "tools/world/gen_terrain.py", "seed": L.SEED, "cell": L.CELL, "originX": float(xs[0]),
            "originZ": float(zs[0]), "nx": int(len(xs)), "nz": int(len(zs)), "heightScale": 8,
            "height": "terrain_height.i16", "material": "terrain_material.u8", "materials": MATERIALS,
            "shellLand": 40, "shellSea": 20,
            "stats": {"minY": round(float(h.min()), 1), "maxY": round(float(h.max()), 1),
                      "landFraction": round(float((h > 0).mean()), 3), "cells": counts},
            "windows": windows}
    with open(os.path.join(out, "terrain.json"), "w") as f:
        json.dump(meta, f, indent=1)
    wc = write_worldconfig(wins)
    if "--preview" in sys.argv:
        preview(h, mat, sys.argv[sys.argv.index("--preview") + 1])
    print(f"baked {len(xs)}x{len(zs)} @ {L.CELL} studs, Y {h.min():.1f}..{h.max():.1f}, land {meta['stats']['landFraction']}")
    print("wrote", out, "and", wc)


if __name__ == "__main__":
    main()
