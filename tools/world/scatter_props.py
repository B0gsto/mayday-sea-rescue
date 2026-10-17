#!/usr/bin/env python3
"""Deterministic rock (K1) and vegetation (G1) scatter for the Gale Isles (docs/10-world-and-map.md).

usage: python3 tools/world/scatter_props.py [--seed N] [--preview build/world/props_preview.png]

Reads the terrain bake (map/generated/terrain.json + terrain_height.i16 + terrain_material.u8) and
tools/world/layout.py, and writes map/generated/props.json (compact):
  {"generator", "seed", "assets": [names], "rocks": [[a,x,y,z,yaw,tx,tz,s,b],...], "plants": [...], "stats": {...}}
a = 1-based index into assets; y = bilinear terrain height (studs); yaw / tx / tz in degrees, applied as
CFrame.new(x,y,z) * CFrame.Angles(rad(tx), 0, rad(tz)) * CFrame.Angles(0, rad(yaw), 0); s = uniform scale;
b = bury fraction of the scaled model height sunk below y. b = -1 is waterline mode: the asset's ATT_Waterline goes
to height y, and y is then the water height (0 + a small tide jitter), not the terrain height.
Same inputs + seed = byte-identical output. Needs numpy (Pillow only for --preview)."""
import hashlib, json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402
import gen_terrain as G  # noqa: E402  (noise, coast_field, catmull, box_blur; its main() is guarded)

# ---------------------------------------------------------------- assets
# footprint (x, y) and height in metres at scan / build scale (art/status/K1.csv, G1.csv); 1 m = 3 studs.
ROCKS = {
    "M_Rock_Boulder_01": (1.27, 1.83, 1.00), "M_Rock_Boulder_02": (1.36, 0.75, 0.54),
    "M_Rock_Boulder_03": (0.67, 1.21, 0.65), "M_Rock_Boulder_04": (2.53, 1.23, 0.88),
    "M_Rock_Boulder_05": (2.41, 3.07, 1.47), "M_Rock_Boulder_06": (2.52, 2.50, 1.90),
    "M_Rock_Cliff_01": (4.95, 3.83, 3.56), "M_Rock_Cliff_02": (2.71, 2.13, 2.47),
    "M_Rock_Cliff_03": (10.21, 5.25, 10.52), "M_Rock_Cliff_04": (8.28, 4.39, 4.96),
    "M_Rock_Cliff_05": (20.23, 6.59, 7.18),
    "M_Rock_Ledge_01": (4.89, 10.45, 1.40), "M_Rock_Ledge_02": (8.98, 5.63, 1.53),
    "M_Rock_Ledge_03": (4.04, 3.75, 1.33),
}
PLANTS = {
    "M_Veg_Grass_Turf_01": (0.45, 0.42, 0.22), "M_Veg_Grass_Turf_02": (0.6, 0.55, 0.3),
    "M_Veg_Grass_Marram_01": (0.9, 0.8, 0.8), "M_Veg_Grass_Marram_02": (1.2, 1.0, 1.0),
    "M_Veg_Gorse_01": (1.6, 1.4, 1.2), "M_Veg_Gorse_02": (2.0, 1.7, 1.6), "M_Veg_Gorse_03": (1.0, 0.9, 0.7),
    "M_Veg_Heather_01": (0.7, 0.6, 0.35), "M_Veg_Heather_02": (0.55, 0.5, 0.3), "M_Veg_Heather_03": (0.9, 0.75, 0.4),
    "M_Veg_SeaThrift_01": (0.3, 0.28, 0.24), "M_Veg_SeaThrift_02": (0.22, 0.2, 0.2),
    "M_Veg_Bracken_01": (1.3, 1.2, 1.0), "M_Veg_Bracken_02": (1.2, 1.1, 0.8),
    "M_Veg_Hawthorn_01": (3.6, 2.6, 2.4), "M_Veg_Hawthorn_02": (2.6, 2.0, 1.9),
}
ASSETS = list(ROCKS) + list(PLANTS)
AI = {n: i + 1 for i, n in enumerate(ASSETS)}
FOOT = {n: 1.5 * max(d[0], d[1]) for n, d in {**ROCKS, **PLANTS}.items()}  # footprint radius, studs, at s = 1

PLANT_CAP = 3500
WIND_YAW = 45.0  # hawthorns share a heading (prevailing south-westerly), +-18 deg jitter

# rock stage budgets (target 500-900 total)
ROCK_BUDGET = {"waterline": 280, "clifffoot": 170, "reef": 200, "cliffchunk": 220}

# plant budgets per kind and region (sum = PLANT_CAP; regions without suitable ground simply fall short)
PLANT_BUDGET = {
    "marram": {"HavenSands": 640, "WestCoast": 110},
    "turf": {"Town": 280, "CoastRoad": 300, "HavenSands": 150, "HavenHead": 130, "Inland": 140, "WestCoast": 110,
             "SkerryIsle": 40},
    "gorse": {"HavenHead": 160, "CoastRoad": 70, "WestCoast": 120, "SkerryIsle": 50, "EastCliffs": 60, "Town": 40},
    "heather": {"HavenHead": 120, "WestCoast": 100, "SkerryIsle": 50, "EastCliffs": 60, "Inland": 60},
    "thrift": {"HavenHead": 150, "WestCoast": 110, "SkerryIsle": 80, "EastCliffs": 50, "Town": 30},
    "bracken": {"Inland": 90, "CoastRoad": 60, "Town": 30, "WestCoast": 40, "HavenHead": 20},
    "hawthorn": {"CoastRoad": 12, "Town": 8, "HavenHead": 6, "WestCoast": 8, "Inland": 6},
}
# kind: (assets with weights, cluster sigma studs, mean members per cluster, spacing factor)
PLANT_KIND = {
    "marram": ({"M_Veg_Grass_Marram_01": 3, "M_Veg_Grass_Marram_02": 2}, 9.0, 9, 0.8),
    "turf": ({"M_Veg_Grass_Turf_01": 3, "M_Veg_Grass_Turf_02": 2}, 5.0, 7, 0.9),
    "gorse": ({"M_Veg_Gorse_01": 3, "M_Veg_Gorse_02": 2, "M_Veg_Gorse_03": 2}, 10.0, 5, 0.85),
    "heather": ({"M_Veg_Heather_01": 3, "M_Veg_Heather_02": 2, "M_Veg_Heather_03": 2}, 7.0, 7, 0.85),
    "thrift": ({"M_Veg_SeaThrift_01": 3, "M_Veg_SeaThrift_02": 2}, 4.0, 6, 1.0),
    "bracken": ({"M_Veg_Bracken_01": 3, "M_Veg_Bracken_02": 2}, 7.0, 6, 0.8),
    "hawthorn": ({"M_Veg_Hawthorn_01": 1, "M_Veg_Hawthorn_02": 1}, 0.0, 1, 1.0),
}
REGIONS = ["Town", "HavenSands", "HavenHead", "CoastRoad", "SkerryIsle", "WestCoast", "EastCliffs", "Inland",
           "Reefs"]

# exclusion radii / margins (studs)
ROAD_VERGE = 8
SLIPWAY_MARGIN = 12
CARPARK_MARGIN = 10
POINT_RADIUS = 30
POI_RADIUS = 25
STATION_BOX = (-380, 240, -320, 60)  # station compound + Chandlery (+40, -20) + yard, minX maxX minZ maxZ
HARBOUR_BOX = (L.HARBOUR["minX"] - 40, L.HARBOUR["maxX"] + 40, -60, L.HARBOUR["maxZ"] + 40)  # basin + quay + arms


def smooth(e0, e1, x):
    return G.smoothstep(e0, e1, x)


# ---------------------------------------------------------------- terrain


def load_terrain():
    gd = os.path.join(REPO, "map/generated")
    meta = json.load(open(os.path.join(gd, "terrain.json")))
    nx, nz = meta["nx"], meta["nz"]
    h = np.fromfile(os.path.join(gd, meta["height"]), dtype="<i2").reshape(nz, nx).astype(np.float64) / meta["heightScale"]
    mat = np.fromfile(os.path.join(gd, meta["material"]), dtype=np.uint8).reshape(nz, nx)
    return meta, h, mat


class Terrain:
    def __init__(self, seed):
        self.meta, self.h, self.mat = load_terrain()
        m = self.meta
        self.cell, self.ox, self.oz = m["cell"], m["originX"], m["originZ"]
        self.nx, self.nz = m["nx"], m["nz"]
        self.MI = {n: i for i, n in enumerate(m["materials"])}
        xs = self.ox + np.arange(self.nx) * self.cell
        zs = self.oz + np.arange(self.nz) * self.cell
        self.X, self.Z = np.meshgrid(xs, zs)  # rows are z
        h = self.h
        gz_, gx_ = np.gradient(h, self.cell)
        self.gx, self.gz = gx_, gz_
        self.slope = np.hypot(gx_, gz_)
        self.hollow = G.box_blur(h, 6) - h
        # coast distance + kind weights at 8-stud resolution (same perturbation as the bake), nearest-upsampled
        Xc, Zc = self.X[::2, ::2], self.Z[::2, ::2]
        d, H, W = G.coast_field(Xc, Zc)
        s = L.SEED
        wc, wr, wb, wh, wm = W
        amp = 34 * wc + 24 * wr + 5 * wb + 12 * wm
        d = d + amp * G.fbm(Xc, Zc, 220, s + 1) + 0.35 * amp * G.fbm(Xc, Zc, 60, s + 2)
        up = lambda a: np.repeat(np.repeat(a, 2, 0), 2, 1)[:self.nz, :self.nx]  # noqa: E731
        self.d = up(d)
        self.W = np.stack([up(w) for w in W])
        self.dl = np.maximum(self.d, 0)
        land = h >= 0
        sea = ~land
        nb_sea = np.zeros_like(land)
        nb_sea[1:, :] |= sea[:-1, :]
        nb_sea[:-1, :] |= sea[1:, :]
        nb_sea[:, 1:] |= sea[:, :-1]
        nb_sea[:, :-1] |= sea[:, 1:]
        self.shore = land & nb_sea  # land cells touching the sea: the waterline
        self.near_shore = G.box_blur(self.shore.astype(np.float64), 6) > 0  # within 24 studs of the waterline
        self.steep_near = G.box_blur((self.slope > 0.75).astype(np.float64), 4) > 0.04
        self.edges(seed)

    def idx(self, x, z):
        i = int(round((x - self.ox) / self.cell))
        j = int(round((z - self.oz) / self.cell))
        return min(max(j, 0), self.nz - 1), min(max(i, 0), self.nx - 1)

    def height(self, x, z):
        u = min(max((x - self.ox) / self.cell, 0), self.nx - 1.001)
        v = min(max((z - self.oz) / self.cell, 0), self.nz - 1.001)
        i, j = int(u), int(v)
        fu, fv = u - i, v - j
        h = self.h
        return float(h[j, i] * (1 - fu) * (1 - fv) + h[j, i + 1] * fu * (1 - fv) + h[j + 1, i] * (1 - fu) * fv
                     + h[j + 1, i + 1] * fu * fv)

    def normal(self, x, z):
        j, i = self.idx(x, z)
        n = np.array([-self.gx[j, i], 1.0, -self.gz[j, i]])
        return n / np.linalg.norm(n)

    def edges(self, seed):
        """Distance-outside rasters for the roads (and the slipway) and the car parks."""
        X, Z = self.X, self.Z
        self.road_edge = np.full(X.shape, 1e9)  # asphalt roads + tracks
        self.slip_edge = np.full(X.shape, 1e9)
        for road in L.ROADS:
            pts = G.catmull(road["points"], 4)
            hw = road["width"] / 2
            r = int(math.ceil((hw + 200) / self.cell)) + 1
            target = self.slip_edge if road["surface"] == "Concrete" else self.road_edge
            for px, pz in pts:
                j0, i0 = self.idx(px, pz)
                sl = (slice(max(j0 - r, 0), j0 + r + 1), slice(max(i0 - r, 0), i0 + r + 1))
                np.minimum(target[sl], np.hypot(X[sl] - px, Z[sl] - pz) - hw, out=target[sl])
        self.park_edge = np.full(X.shape, 1e9)
        for cp in L.CAR_PARKS:
            cx, cz = cp["center"]
            sx, sz = cp["size"]
            a = math.radians(cp["yaw"])
            lx = (X - cx) * math.cos(a) + (Z - cz) * math.sin(a)
            lz = -(X - cx) * math.sin(a) + (Z - cz) * math.cos(a)
            e = np.hypot(np.maximum(np.abs(lx) - sx / 2, 0), np.maximum(np.abs(lz) - sz / 2, 0))
            self.park_edge = np.minimum(self.park_edge, e)


# ---------------------------------------------------------------- masks: exclusions, regions, eligibility


def in_box(X, Z, box):
    x0, x1, z0, z1 = box
    return (X >= x0) & (X <= x1) & (Z >= z0) & (Z <= z1)


def exclusions(T):
    """(excl_all, excl_turf): cells where nothing may go; turf additionally may use the town platform's rim."""
    X, Z = T.X, T.Z
    ex = (T.road_edge < ROAD_VERGE) | (T.slip_edge < SLIPWAY_MARGIN) | (T.park_edge < CARPARK_MARGIN)
    ex |= in_box(X, Z, HARBOUR_BOX) | in_box(X, Z, STATION_BOX)
    cv = L.HARBOUR_COVE
    ex |= in_box(X, Z, (cv["minX"] - 10, cv["maxX"] + 30, cv["topZ"] - 10, cv["toeZ"] + 80))
    for p in L.POINTS:
        ex |= np.hypot(X - p["pos"][0], Z - p["pos"][2]) < POINT_RADIUS
    for p in L.POIS:
        ex |= np.hypot(X - p["pos"][0], Z - p["pos"][2]) < POI_RADIUS
    wb = T.W[2]
    beach_sand = (wb > 0.5) & (T.d < L.BEACH_WIDTH + 8) & (T.d > -40)  # the sand strip used by beach rescues
    ex |= beach_sand
    paving = np.isin(T.mat, [T.MI[n] for n in ("Asphalt", "Cobblestone", "Concrete", "Pavement")])
    ex |= paving
    tp = L.TOWN_PLATFORM
    platform = in_box(X, Z, (tp["minX"], tp["maxX"], tp["minZ"], tp["maxZ"]))
    rim = platform & ~in_box(X, Z, (tp["minX"] + 20, tp["maxX"] - 20, tp["minZ"] + 20, tp["maxZ"] - 20))
    ex_turf = ex | (platform & ~rim)
    ex_all = ex | platform
    return ex_all, ex_turf


def regions(T):
    X, Z, d = T.X, T.Z, T.d
    reg = np.full(X.shape, REGIONS.index("Inland"), dtype=np.int8)
    put = lambda m, name: np.copyto(reg, np.int8(REGIONS.index(name)), where=m)  # noqa: E731
    # lowest priority first, later overrides
    put(X > 2100, "EastCliffs")
    put((X < -820) & (d < 450), "WestCoast")
    put(T.road_edge < 150, "CoastRoad")
    put(in_box(X, Z, (1380, 2400, 1450, 2100)), "SkerryIsle")
    put(in_box(X, Z, (1420, 2100, 380, 1200)), "HavenHead")
    put(in_box(X, Z, (540, 1420, -60, 760)), "HavenSands")
    put(in_box(X, Z, (-820, 640, -620, 120)), "Town")
    for rf in L.REEFS:
        cx, cz = rf["center"]
        put((np.hypot(X - cx, Z - cz) < rf["radius"] * 1.15) & (T.h < 0), "Reefs")
    return reg


def plant_weights(T, seed):
    """Eligibility / density weight per plant kind (0 = not allowed), noise-modulated."""
    X, Z, h, mat, slope, dl = T.X, T.Z, T.h, T.mat, T.slope, T.dl
    wc, wr, wb, wh, wm = T.W
    M = T.MI
    mw = lambda table: sum(v * (mat == M[k]) for k, v in table.items())  # noqa: E731
    patch = lambda sc, k: smooth(-0.25, 0.45, G.fbm(X, Z, sc, seed + 500 + k))  # noqa: E731
    dry = (h > 1.5) & ~T.shore
    bw, dw = L.BEACH_WIDTH, L.DUNE_WIDTH
    cliffy = smooth(0.3, 0.8, wc + 0.6 * wr)
    cliff_top = smooth(260, 40, dl) * cliffy
    upland = smooth(110, 180, h)
    w = {}
    dune = (wb > 0.5) & (dl >= bw + 6) & (dl < bw + dw + 30) & (slope < 0.9)
    dt = np.clip((dl - bw) / (dw + 30), 0, 1)
    w["marram"] = dune * dry * mw({"Grass": 1.0, "LeafyGrass": 0.9, "Sand": 0.55, "Ground": 0.3}) \
        * (0.35 + 0.65 * smooth(0.0, 0.5, dt)) * (0.25 + 0.75 * patch(60, 1))
    w["turf"] = dry * (slope < 0.6) * mw({"Grass": 1.0, "LeafyGrass": 0.35, "Ground": 0.15}) \
        * (0.1 + 0.9 * patch(90, 2)) * (1 - 0.7 * dune)
    w["gorse"] = dry * (slope < 0.75) * (dl > 14) * (h > 4) * cliff_top \
        * mw({"LeafyGrass": 1.0, "Grass": 0.6, "Ground": 0.3}) * (0.1 + 0.9 * patch(120, 3))
    w["heather"] = dry * (slope < 0.7) * (h > 4) * np.maximum(cliff_top * smooth(25, 80, dl), 0.8 * upland) \
        * mw({"LeafyGrass": 1.0, "Grass": 0.3, "Ground": 0.2}) * (0.1 + 0.9 * patch(100, 4))
    w["thrift"] = dry * (slope < 0.9) * (h > 3) * cliffy * smooth(95, 12, dl) \
        * mw({"Grass": 0.9, "LeafyGrass": 1.0, "Rock": 0.6, "Ground": 0.5, "Basalt": 0.3}) * (0.2 + 0.8 * patch(50, 5))
    w["bracken"] = dry * (h > 4) * (h < 140) * (dl > 40) * smooth(0.3, 1.2, T.hollow) * smooth(0.45, 0.15, slope) \
        * mw({"Grass": 0.8, "LeafyGrass": 1.0, "Ground": 0.6}) * (0.2 + 0.8 * patch(80, 6))
    w["hawthorn"] = dry * (h > 6) * (dl > 30) * smooth(0.18, 0.32, slope) * smooth(0.75, 0.55, slope) \
        * mw({"Grass": 1.0, "LeafyGrass": 0.8})
    mvp = np.hypot(X, Z) <= L.MVP_RADIUS
    return {k: (v * mvp).astype(np.float64) for k, v in w.items()}


# ---------------------------------------------------------------- placement helpers


class Spacing:
    """Spatial hash of placed discs; a candidate passes if it keeps factor * (r_i + r_j) from every disc."""

    def __init__(self, cell=16.0):
        self.cell, self.grid, self.maxr = cell, {}, 0.0

    def ok(self, x, z, r, factor):
        reach = int(math.ceil((r + self.maxr) / self.cell))
        ci, cj = int(math.floor(x / self.cell)), int(math.floor(z / self.cell))
        for a in range(ci - reach, ci + reach + 1):
            for b in range(cj - reach, cj + reach + 1):
                for (px, pz, pr) in self.grid.get((a, b), ()):
                    if (px - x) ** 2 + (pz - z) ** 2 < (factor * (r + pr)) ** 2:
                        return False
        return True

    def add(self, x, z, r):
        self.grid.setdefault((int(math.floor(x / self.cell)), int(math.floor(z / self.cell))), []).append((x, z, r))
        self.maxr = max(self.maxr, r)


def tilt_angles(n, follow, cap_deg):
    """Euler (tx, tz) degrees for CFrame.Angles(tx, 0, tz) taking +Y toward the normal n, by `follow`, capped."""
    ang = math.acos(max(-1.0, min(1.0, n[1])))
    t = min(ang * follow, math.radians(cap_deg))
    hz = math.hypot(n[0], n[2])
    if hz < 1e-9 or t < 1e-6:
        return 0.0, 0.0
    nx_, nz_ = math.sin(t) * n[0] / hz, math.sin(t) * n[2] / hz
    ny_ = math.cos(t)
    # CFrame.Angles(tx, 0, tz) * (0,1,0) = (-sin tz, cos tz cos tx, cos tz sin tx)
    return math.degrees(math.atan2(nz_, ny_)), math.degrees(-math.asin(nx_))


def pick_asset(rng, table):
    names = list(table)
    w = np.array([table[k] for k in names], dtype=np.float64)
    return names[int(rng.choice(len(names), p=w / w.sum()))]


def rnd(v, k):
    v = round(float(v), k)
    return 0.0 if v == 0 else v  # no -0.0


def row(asset, x, y, z, yaw, tx, tz, s, b):
    return [AI[asset], rnd(x, 1), rnd(y, 2), rnd(z, 1), rnd(yaw % 360, 1), rnd(tx, 1), rnd(tz, 1), rnd(s, 2),
            rnd(b, 2)]


# ---------------------------------------------------------------- rocks


def scatter_rocks(T, ex_all, reg, seed, space):
    h, mat, slope, dl = T.h, T.mat, T.slope, T.dl
    wc, wr, wb, wh, wm = T.W
    M = T.MI
    X, Z = T.X, T.Z
    inside = (np.abs(X) < L.HALF_EXTENT - 30) & (np.abs(Z) < L.HALF_EXTENT - 30)
    noise = 0.5 + 0.5 * G.fbm(X, Z, 150, seed + 300)
    rocky = (wc + wr > 0.5) & (wb < 0.4) & (wh < 0.3) & (wm < 0.3)
    rock_mats = np.isin(mat, [M[n] for n in ("Rock", "Basalt", "Slate", "Ground", "Grass", "LeafyGrass", "Limestone")])
    reef_m = np.zeros(X.shape, dtype=bool)
    for rf in L.REEFS:
        cx, cz = rf["center"]
        reef_m |= np.hypot(X - cx, Z - cz) < rf["radius"]
    stages = [
        # name, candidate mask, weight, assets, waterline?, tilt follow, tilt cap, spacing factor
        ("waterline", T.shore & rocky & inside & ~ex_all, 0.3 + noise,
         {"M_Rock_Ledge_01": 3, "M_Rock_Ledge_02": 3, "M_Rock_Ledge_03": 3, "M_Rock_Boulder_04": 2,
          "M_Rock_Boulder_05": 2}, True, 0.0, 3.0, 0.75),
        ("clifffoot", T.near_shore & T.steep_near & (h > 0.5) & (h < 14) & (wc > 0.2) & rocky & rock_mats & inside
         & ~ex_all, 0.15 + noise ** 2,
         {"M_Rock_Boulder_01": 3, "M_Rock_Boulder_02": 2, "M_Rock_Boulder_03": 2, "M_Rock_Boulder_04": 1,
          "M_Rock_Boulder_05": 1, "M_Rock_Boulder_06": 3}, False, 0.7, 15.0, 0.85),
        ("reef", reef_m & (h < -0.3) & (h > -7) & np.isin(mat, [M["Rock"], M["Basalt"], M["Slate"]]) & inside
         & ~ex_all, 0.2 + noise * smooth(-7, -1.5, h),
         {"M_Rock_Boulder_01": 2, "M_Rock_Boulder_02": 2, "M_Rock_Boulder_03": 2, "M_Rock_Boulder_04": 2,
          "M_Rock_Boulder_05": 3, "M_Rock_Boulder_06": 3}, False, 0.7, 15.0, 0.85),
        ("cliffchunk", (slope > 0.84) & (wc + 0.5 * wr > 0.4) & (h > 1) & (dl < 400) & rock_mats & inside & ~ex_all,
         (0.2 + noise) * smooth(0.84, 1.3, slope + 0.2),
         {"M_Rock_Cliff_01": 3, "M_Rock_Cliff_02": 3, "M_Rock_Cliff_03": 1.5, "M_Rock_Cliff_04": 2,
          "M_Rock_Cliff_05": 1}, False, 0.8, 15.0, 0.7),
    ]
    out, meta = [], []
    for k, (name, cand, wgt, assets, waterline, follow, cap, fac) in enumerate(stages):
        rng = np.random.default_rng([seed, 11, k])
        jj, ii = np.nonzero(cand)
        if len(jj) == 0:
            continue
        wv = np.asarray(np.broadcast_to(wgt, cand.shape)[jj, ii], dtype=np.float64) + 1e-6
        # weighted random order (Efraimidis-Spirakis keys), then greedy Poisson-disk acceptance
        keys = np.log(rng.random(len(jj))) / wv
        order = np.argsort(-keys, kind="stable")
        budget, placed = ROCK_BUDGET[name], 0
        for o in order:
            if placed >= budget:
                break
            j, i = int(jj[o]), int(ii[o])
            x = float(T.X[j, i]) + rng.uniform(-1.8, 1.8)
            z = float(T.Z[j, i]) + rng.uniform(-1.8, 1.8)
            asset = pick_asset(rng, assets)
            s = rng.uniform(0.8, 1.4)
            r = FOOT[asset] * s
            if not space.ok(x, z, r, fac):
                continue
            yaw = rng.uniform(0, 360)
            if not waterline and name != "reef" and T.height(x, z) < 0.2:
                continue  # nothing under water except reef boulders and the waterline pieces
            if waterline:
                y, b = rng.uniform(-0.6, 0.6), -1.0
                n = T.normal(x, z)
                tx, tz = tilt_angles(n, 0.15 if "Ledge" in asset else 0.5, cap if "Ledge" in asset else 10.0)
            else:
                y, b = T.height(x, z), rng.uniform(0.15, 0.30)
                tx, tz = tilt_angles(T.normal(x, z), follow, cap)
            space.add(x, z, r)
            out.append(row(asset, x, y, z, yaw, tx, tz, s, b))
            meta.append(REGIONS[int(reg[j, i])] if name != "reef" else "Reefs")
            placed += 1
        print(f"  rocks/{name}: {placed} of {budget} ({len(jj)} candidate cells)")
    return out, meta


# ---------------------------------------------------------------- plants


def scatter_plants(T, weights, ex_all, ex_turf, reg, seed, space_rocks):
    space = Spacing(8.0)
    out, meta = [], []
    total_budget = 0
    for kind, per_region in PLANT_BUDGET.items():
        assets, sigma, members, fac = PLANT_KIND[kind]
        wk = weights[kind] * ~(ex_turf if kind == "turf" else ex_all)
        for ri, (rname, budget) in enumerate(per_region.items()):
            budget = min(budget, PLANT_CAP - total_budget)
            total_budget += budget
            if budget <= 0:
                continue
            rng = np.random.default_rng([seed, 23, list(PLANT_BUDGET).index(kind), ri])
            m = wk * (reg == REGIONS.index(rname))
            jj, ii = np.nonzero(m > 0.02)
            if len(jj) == 0:
                continue
            wv = m[jj, ii]
            p = wv / wv.sum()
            placed, tries = 0, 0
            while placed < budget and tries < budget * 6:
                tries += 1
                c = int(rng.choice(len(jj), p=p))
                cx = float(T.X[jj[c], ii[c]]) + rng.uniform(-2, 2)
                cz = float(T.Z[jj[c], ii[c]]) + rng.uniform(-2, 2)
                n_mem = 1 if members <= 1 else max(1, int(rng.poisson(members)))
                for q in range(n_mem):
                    if placed >= budget:
                        break
                    if q == 0:
                        x, z = cx, cz
                    else:
                        x, z = cx + rng.normal(0, sigma), cz + rng.normal(0, sigma)
                    if x * x + z * z > L.MVP_RADIUS ** 2:
                        continue
                    j, i = T.idx(x, z)
                    wcell = m[j, i]
                    if wcell <= 0.02 or rng.random() > 0.3 + 0.7 * min(1.0, wcell / max(wv.max(), 1e-9) * 1.5):
                        continue
                    asset = pick_asset(rng, assets)
                    s = rng.uniform(0.8, 1.3)
                    r = FOOT[asset] * s
                    spacing = fac if kind != "hawthorn" else 6.0
                    if not space.ok(x, z, r, spacing) or not space_rocks.ok(x, z, r, 0.9):
                        continue
                    if kind == "hawthorn":
                        yaw = WIND_YAW + rng.uniform(-18, 18)
                    else:
                        yaw = rng.uniform(0, 360)
                    tx, tz = tilt_angles(T.normal(x, z), 0.6, 8.0)
                    space.add(x, z, r)
                    out.append(row(asset, x, T.height(x, z), z, yaw, tx, tz, s, rng.uniform(0.02, 0.08)))
                    meta.append(rname)
                    placed += 1
    return out, meta


# ---------------------------------------------------------------- performance thinning (I1 perf pass)

ROCK_MIN_STUDS = 4.5  # scaled rocks smaller than this (largest dimension) add triangles, not shape: dropped
SEEN_EDGE = 36  # studs either side of a road, track, slipway or car park
SEEN_RADIUS = 220  # studs round the station, the land points and the viewpoints
STATION = (-165, 30)
UNSEEN_KEEP = 0.35  # share of plants kept away from where the player walks / looks
ALWAYS_KEEP = ("M_Veg_Hawthorn_01", "M_Veg_Hawthorn_02", "M_Veg_Gorse_02")  # silhouettes read from afar


def seen_mask_at(T, x, z):
    j, i = T.idx(x, z)
    if min(T.road_edge[j, i], T.slip_edge[j, i], T.park_edge[j, i]) < SEEN_EDGE:
        return True
    wb = T.W[2][j, i]
    if wb > 0.5 and T.d[j, i] < L.BEACH_WIDTH + L.DUNE_WIDTH + 40:  # beaches and the dune front
        return True
    spots = [STATION] + [(p["pos"][0], p["pos"][2]) for p in L.POINTS]
    spots += [(p["pos"][0], p["pos"][2]) for p in L.POIS if p["kind"] in ("Viewpoint", "RockPool")]
    return any((x - sx) ** 2 + (z - sz) ** 2 < SEEN_RADIUS ** 2 for sx, sz in spots)


def thin(T, rocks, rmeta, plants, pmeta, seed):
    """Drops tiny rocks; keeps plants at full density only where they are seen (roads, paths, beaches, the
    station, the land points and viewpoints), UNSEEN_KEEP of them elsewhere. Plant rows gain a 10th column:
    1 = seen (the client keeps these first on low graphics quality), 0 = filler."""
    kr = [i for i, r in enumerate(rocks) if max(ROCKS[ASSETS[r[0] - 1]]) * 3 * r[7] >= ROCK_MIN_STUDS]
    rng = np.random.default_rng([seed, 99])
    kp, flags = [], []
    for i, r in enumerate(plants):
        asset = ASSETS[r[0] - 1]
        seen = seen_mask_at(T, r[1], r[3])
        if seen or asset in ALWAYS_KEEP or rng.random() < UNSEEN_KEEP:
            kp.append(i)
            flags.append(1 if seen else 0)
    print(f"thin: rocks {len(rocks)} -> {len(kr)}, plants {len(plants)} -> {len(kp)} ({sum(flags)} seen)")
    plants2 = [plants[i] + [f] for i, f in zip(kp, flags)]
    return [rocks[i] for i in kr], [rmeta[i] for i in kr], plants2, [pmeta[i] for i in kp]


# ---------------------------------------------------------------- preview


def preview(T, rocks, plants, path):
    from PIL import Image, ImageDraw
    colors = {"Sand": (205, 187, 152), "Sandstone": (140, 123, 98), "Salt": (90, 120, 125), "Limestone": (190, 185, 170),
              "Rock": (120, 118, 112), "Slate": (75, 74, 38), "Basalt": (55, 55, 58), "Grass": (96, 128, 70),
              "LeafyGrass": (110, 90, 100), "Mud": (90, 75, 60), "Ground": (120, 100, 75), "Asphalt": (40, 40, 42),
              "Cobblestone": (110, 105, 100), "Concrete": (180, 180, 175), "Pavement": (150, 150, 150), "Air": (0, 0, 0)}
    lut = np.array([colors.get(m, (0, 0, 0)) for m in T.meta["materials"]], dtype=np.float64)
    rgb = lut[T.mat] * np.where(T.h < 0, 0.6, 1.0)[..., None]
    size = 1024
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).resize((size, size), Image.BILINEAR)
    dr = ImageDraw.Draw(img)
    k = size / (T.nx * T.cell)
    pal = {"Rock_L": (255, 255, 255), "Rock_B": (255, 60, 60), "Rock_C": (255, 160, 0), "Marram": (255, 240, 0),
           "Turf": (0, 255, 120), "Gorse": (255, 200, 0), "Heather": (220, 0, 255), "SeaThrift": (255, 120, 200),
           "Bracken": (180, 90, 0), "Hawthorn": (0, 200, 255)}
    for r in rocks + plants:
        name = ASSETS[r[0] - 1]
        key = next((p for p in pal if p in name), None) or ("Rock_" + name.split("_")[2][0])
        px, pz = (r[1] - T.ox) * k, (r[3] - T.oz) * k
        dr.point((px, pz), fill=pal.get(key, (255, 255, 255)))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


# ---------------------------------------------------------------- main


def main():
    argv = sys.argv[1:]
    seed = int(argv[argv.index("--seed") + 1]) if "--seed" in argv else L.SEED
    T = Terrain(seed)
    ex_all, ex_turf = exclusions(T)
    reg = regions(T)
    space_rocks = Spacing(16.0)
    rocks, rmeta = scatter_rocks(T, ex_all, reg, seed, space_rocks)
    plants, pmeta = scatter_plants(T, plant_weights(T, seed), ex_all, ex_turf, reg, seed, space_rocks)
    plants = plants[:PLANT_CAP]
    pmeta = pmeta[:PLANT_CAP]
    rocks, rmeta, plants, pmeta = thin(T, rocks, rmeta, plants, pmeta, seed)
    by_asset, by_region = {}, {}
    for r in rocks + plants:
        by_asset[ASSETS[r[0] - 1]] = by_asset.get(ASSETS[r[0] - 1], 0) + 1
    for g in rmeta + pmeta:
        by_region[g] = by_region.get(g, 0) + 1
    by_asset = {k: by_asset[k] for k in ASSETS if k in by_asset}
    by_region = {k: by_region[k] for k in REGIONS if k in by_region}
    doc = {"generator": "tools/world/scatter_props.py", "seed": seed, "assets": ASSETS, "rocks": rocks,
           "plants": plants, "stats": {"rocks": len(rocks), "plants": len(plants), "byAsset": by_asset,
                                       "byRegion": by_region}}
    text = json.dumps(doc, separators=(",", ":"))
    path = os.path.join(REPO, "map/generated/props.json")
    with open(path, "w") as f:
        f.write(text)
    if "--preview" in argv:
        preview(T, rocks, plants, argv[argv.index("--preview") + 1])
    rr = {}
    for g in rmeta:
        rr[g] = rr.get(g, 0) + 1
    print(f"rocks {len(rocks)} plants {len(plants)} seed {seed} sha256 {hashlib.sha256(text.encode()).hexdigest()[:16]}")
    print("byAsset", json.dumps(by_asset))
    print("byRegion (all)", json.dumps(by_region))
    print("byRegion (rocks)", json.dumps(rr))
    print("wrote", path)


if __name__ == "__main__":
    main()
