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
             "Mud", "Ground", "Asphalt", "Cobblestone", "Concrete", "Pavement"]
MI = {name: i for i, name in enumerate(MATERIALS)}
# Rippled seabed sand: doc 10 gives it the Salt slot, but stock Salt renders near-white, so Sand stands in until
# the Salt MaterialVariant exists (then set this to "Salt" and re-run the pipeline).
SEABED_SAND = "Sand"

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


# ---------------------------------------------------------------- bake


def bake():
    s = L.SEED
    xs = np.arange(-L.HALF_EXTENT, L.HALF_EXTENT + 1, L.CELL, dtype=np.float64)
    X, Z = np.meshgrid(xs, xs)  # rows are z
    d, H, W = coast_field(X, Z)
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
    beach_l = np.minimum(dl, bw) / 28 + dunes + 0.9 * rise_d(np.maximum(dl - bw - dw, 0)) + 1.0 * dune_t
    harb_l = 4 + rise_d(np.maximum(dl - 200, 0))
    mud_l = dl / 90 + 0.5 * rise_d(dl)
    h_land = wc * cliff_l + wr * rocky_l + wb * beach_l + wh * harb_l + wm * mud_l + beacon * smoothstep(0, 400, dl)

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
    cove_h = cv["topY"] + (cv["toeY"] - cv["topY"]) * ct ** 1.3
    cw = smoothstep(cv["minX"], cv["minX"] + 30, X) * smoothstep(cv["toeZ"] + 70, cv["toeZ"], Z)
    h = np.where(cove, h + (cove_h - h) * cw, h)
    feat[cove & (cw > 0.5)] = 6
    tp = L.TOWN_PLATFORM
    ex = np.maximum(np.maximum(tp["minX"] - X, X - tp["maxX"]), 0)
    ez = np.maximum(np.maximum(tp["minZ"] - Z, Z - tp["maxZ"]), 0)
    tw = smoothstep(tp["blend"], 0, np.hypot(ex, ez)) * (h > 0) * ~basin
    h = h + (tp["y"] - h) * tw

    # ---- materials
    gz_, gx_ = np.gradient(h, L.CELL)
    slope = np.hypot(gx_, gz_)
    mat = np.full(X.shape, MI["Grass"], dtype=np.uint8)
    above = h >= 0
    n80 = fbm(X, Z, 80, s + 20)
    mat[above & (h > 115 + 30 * fbm(X, Z, 260, s + 21))] = MI["LeafyGrass"]
    mat[above & (n80 > 0.42)] = MI["Ground"]
    mat[above & ((slope > 0.8) | ((wc > 0.5) & (slope > 0.55)))] = MI["Rock"]
    rockout = above & (ridged(X, Z, 50, s + 22) > 0.93) & (h > 20)
    mat[rockout] = MI["Rock"]
    beachy = (wb > 0.5) & (d >= -2)
    mat[beachy & (dl < bw) & (h < 1.6)] = MI["Sandstone"]
    mat[beachy & (dl < bw) & (h >= 1.6)] = MI["Sand"]
    duney = beachy & (dl >= bw) & (dl < bw + dw)
    mat[duney] = MI["Sand"]
    mat[duney & (fbm(X, Z, 34, s + 23) > 0.1 + 0.5 * (1 - dune_t))] = MI["Grass"]  # marram on the back dunes
    rocky_coast = (wc + wr) > 0.5
    mat[rocky_coast & (h > -6) & (h < 7) & (np.abs(d) < 45)] = MI["Basalt"]
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
    mat[(feat == 6)] = np.where(h[feat == 6] > 1.5, MI["Sand"], MI["Sandstone"])
    mat[(X > -180) & (X < 180) & (Z > -62) & (Z < -20)] = MI["Cobblestone"]  # quayside setts

    h, mat = pave(X, Z, h, mat)
    return xs, h, mat, d


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
    mat = np.where(core, surface_mat, mat)
    verge = (best > halfw) & (best < halfw + 3) & (mat != MI["Sand"]) & (h > 0)
    return h, np.where(verge & (surface_mat == MI["Asphalt"]), MI["Ground"], mat).astype(np.uint8)


def pave(X, Z, h, mat):
    for cp in L.CAR_PARKS:
        cx, cz = cp["center"]
        sx, sz = cp["size"]
        a = math.radians(cp["yaw"])
        lx = (X - cx) * math.cos(a) + (Z - cz) * math.sin(a)
        lz = -(X - cx) * math.sin(a) + (Z - cz) * math.cos(a)
        e = np.hypot(np.maximum(np.abs(lx) - sx / 2, 0), np.maximum(np.abs(lz) - sz / 2, 0))
        y = max(float(sample(h, cx, cz)), 4.0)
        h = h + (y - h) * smoothstep(20, 0, e)
        mat = np.where(e <= 0, MI[cp["surface"]], mat).astype(np.uint8)
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
        h, mat = stamp(X, Z, h, mat, [(pts, ys, road["width"] / 2)], MI[road["surface"]])
    return h, mat


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
        roads.append({"id": r["id"], "name": r["name"], "surface": r["surface"], "width": r["width"],
                      "points": [Vec(p[0], y, p[1]) for p, y in zip(pts, ys)]})
    cfg = {
        "MapRadius": L.MVP_RADIUS,
        "SeaLevel": 0,
        "Terrain": {"cell": L.CELL, "halfExtent": L.HALF_EXTENT, "seabedFloorY": L.SEABED_FLOOR_Y, "seed": L.SEED},
        "Roads": roads,
        "CarParks": [{"id": c["id"], "name": c["name"], "surface": c["surface"],
                      "center": pos((c["center"][0], None, c["center"][1])), "size": list(c["size"]), "yaw": c["yaw"]}
                     for c in L.CAR_PARKS],
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
              "Cobblestone": (110, 105, 100), "Concrete": (180, 180, 175), "Pavement": (150, 150, 150), "Air": (0, 0, 0)}
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
