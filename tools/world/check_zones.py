#!/usr/bin/env python3
"""Check the terrain bake against the gameplay coordinates (run after gen_terrain.py; exit 1 on any failure).

usage: python3 tools/world/check_zones.py

Reads map/generated/terrain_height.i16 and checks that every place gameplay code hard-codes is still water or land
as before WP-3: GameConfig.Zones, CallTypes.SpawnZones fallbacks and fixed sites, RipCurrent, ColdOpen, the
WildlifeController seal haul-outs, MapConfig blips, LandVehicleConfig's Haven Head spawn, layout.POINTS (vehicle
spawns, handovers, the tower), the town platform (flat at Y 4), the harbour basin, every road centre line on land and
the Haven Sands beach (sand behind the waterline, sea in front)."""
import json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402
from gen_terrain import catmull  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
N = 2 * L.HALF_EXTENT // L.CELL + 1
H = np.fromfile(os.path.join(REPO, "map/generated/terrain_height.i16"), "<i2").reshape(N, N) / 8.0

# (name, x, z, "water" | "land"); water = bake surface below sea level (some sit under quay / dock parts)
WATER, LAND = "water", "land"
POINTS = [
    ("Zone HarbourMouth", 0, 368, WATER), ("Zone CalmBay", 0, 190, WATER), ("Zone PortHaven", 0, -60, LAND),
    ("Call Near fallback", 40, 180, WATER), ("Call CalmBay / SinkingSite", 150, 260, WATER),
    ("Call Outer fallback", 0, 1100, WATER), ("Call HarbourMouth", 0, 420, WATER), ("Call FerrySite", 60, 500, WATER),
    ("Call HavenHeadCliff", 1740, 925, WATER), ("HavenHead casualty shelf", 1740, 890, WATER),
    ("Call HavenSandsRip", 888, 426, WATER), ("RipCurrent water", 1000, 282, WATER), ("RipCurrent dry", 970, 250, LAND),
    ("RipCurrent origin", 960, 330, LAND), ("ColdOpen spawn", -140, 200, WATER), ("ColdOpen station water", -165, 38, WATER),
    ("MapConfig Dock", -125, 92, WATER), ("Seals HavenHead", 1460, 720, WATER), ("Seals HavenHead sea", 1455, 790, WATER),
    ("Seals west", -550, 35, WATER), ("Seals west sea", -550, 95, WATER),
    ("LandVehicle HavenHead spawn", 1722, 800, LAND), ("HavenHead viewpoint", 1600, 665, LAND),
    ("Trevose Farm", -720, -920, LAND), ("Penmorvah Farm", 1040, -1180, LAND), ("West Cliff car park", -900, -5, LAND),
] + [(f"Point {p['id']}", p["pos"][0], p["pos"][2], LAND) for p in L.POINTS if p["kind"] != "Launch"]


def at(x, z):
    return float(H[int(round((z + L.HALF_EXTENT) / L.CELL)), int(round((x + L.HALF_EXTENT) / L.CELL))])


def check_islands(fails):
    """docs/21 archipelago: windows disjoint and on the tile grid, every island's landmark / stamp / landing on land,
    its dock in water a boat floats in (<= -4), every pad on land, the Mount window meeting the main bake at the
    seam, the Mount causeway shallow all the way and the Door's channel open. Returns the number of points checked."""
    meta = json.load(open(os.path.join(REPO, "map/generated/terrain.json")))
    grids = {}
    for w in meta.get("windows", []):
        g = np.fromfile(os.path.join(REPO, "map/generated", w["height"]), "<i2").reshape(w["nz"], w["nx"]) / 8.0
        grids[w["id"]] = (w["originX"], w["originZ"], g)
    if sorted(grids) != sorted(i["id"] for i in L.ISLAND_WINDOWS):
        fails.append(f"bake windows {sorted(grids)} do not match layout.ISLAND_WINDOWS (re-run gen_terrain.py)")
        return 0
    boxes = [("Main", (-L.HALF_EXTENT, -L.HALF_EXTENT, L.HALF_EXTENT, L.HALF_EXTENT))] \
        + [(i["id"], i["window"]) for i in L.ISLAND_WINDOWS]
    for k, (a, (ax0, az0, ax1, az1)) in enumerate(boxes):
        if any(v % 256 for v in (ax0, az0, ax1, az1)):
            fails.append(f"window {a} is off the 256-stud tile grid")
        if max(abs(ax0), abs(az0), abs(ax1), abs(az1)) > L.MAP_CANVAS:
            fails.append(f"window {a} leaves the map canvas")
        for b, (bx0, bz0, bx1, bz1) in boxes[k + 1:]:
            if ax0 < bx1 and bx0 < ax1 and az0 < bz1 and bz0 < az1:
                fails.append(f"windows {a} and {b} overlap")

    def y(isl, x, z):
        if not isl["window"]:
            return at(x, z)
        ox, oz, g = grids[isl["id"]]
        return float(g[int(round((z - oz) / L.CELL)), int(round((x - ox) / L.CELL))])

    n = 0
    for isl in L.ARCHIPELAGO:
        for key in ("landmark", "stamp", "landing"):
            if key == "landmark" and any(a["center"] == isl["landmark"] for a in L.ARCHES):
                continue  # the Door stands over its own water channel (checked below)
            n += 1
            if y(isl, *isl[key]) <= 0.5:
                fails.append(f"{isl['id']} {key} {isl[key]} should be land, bake Y {y(isl, *isl[key]):.1f}")
        n += 1
        if y(isl, *isl["dock"]) > -4:
            fails.append(f"{isl['id']} dock {isl['dock']} needs water >= 4 studs deep, bake Y {y(isl, *isl['dock']):.1f}")
        if isl["window"] and math.hypot(isl["center"][0], isl["center"][1]) + isl["radius"] > L.MAP_RADIUS:
            fails.append(f"{isl['id']} reaches past MAP_RADIUS")
        for px0, pz0, px1, pz1, _ in isl.get("pads", []):
            n += 1
            if min(y(isl, px, pz) for px in (px0, px1) for pz in (pz0, pz1)) <= 1:
                fails.append(f"{isl['id']} pad ({px0}, {pz0}, {px1}, {pz1}) runs into the sea")
    mount = next(i for i in L.ISLAND_WINDOWS if i["id"] == "StElowensMount")
    ox, oz, g = grids[mount["id"]]
    seam = g[-1, :] - H[0, int((ox + L.HALF_EXTENT) / L.CELL):int((ox + L.HALF_EXTENT) / L.CELL) + g.shape[1]]
    cx = ox + L.CELL * np.arange(g.shape[1])
    seam[np.abs(cx - L.CAUSEWAY["to"][0]) < 2 * L.CAUSEWAY["width"]] = 0  # the causeway spit steps up on purpose
    if np.abs(seam).max() > 1:
        fails.append(f"Mount window seam steps {np.abs(seam).max():.1f} studs from the main bake")
    (ax, az), (bx, bz) = L.CAUSEWAY["from"], L.CAUSEWAY["to"]
    for t in np.linspace(0, 1, 40):
        x, z = ax + t * (bx - ax), az + t * (bz - az)
        cy = at(x, z) if z >= -L.HALF_EXTENT else y(mount, x, z)
        floor = -40 if z >= -L.HALF_EXTENT else -8  # main window: unchanged seabed under C4's walkway Parts
        if cy < floor:
            fails.append(f"causeway at ({x:.0f}, {z:.0f}) drops to Y {cy:.1f}")
            break
    arches = next(i for i in L.ISLAND_WINDOWS if i["id"] == "TheArches")
    for a in L.ARCHES:
        if y(arches, *a["center"]) > -4:
            fails.append(f"arch {a['id']} channel is not open water: bake Y {y(arches, *a['center']):.1f}")
    return n


def main():
    fails = []
    for name, x, z, want in POINTS:
        y = at(x, z)
        if (y > 0) != (want == LAND):
            fails.append(f"{name} ({x}, {z}) should be {want}, bake Y {y:.1f}")
    xs = np.arange(-L.HALF_EXTENT, L.HALF_EXTENT + 1, L.CELL, dtype=float)
    X, Z = np.meshgrid(xs, xs)
    tp = L.TOWN_PLATFORM
    plat = H[(np.abs(X) <= tp["maxX"] - 4) & (Z >= tp["minZ"] + 4) & (Z <= tp["maxZ"] - 4)]
    if plat.min() < 3.5 or plat.max() > 8:
        fails.append(f"town platform not flat: Y {plat.min():.1f}..{plat.max():.1f} (want 3.5..8)")
    basin = H[(np.abs(X) <= 180) & (Z >= 20) & (Z <= 360)]
    if basin.max() > -5:
        fails.append(f"harbour basin too shallow: max Y {basin.max():.1f}")
    for road in L.ROADS:
        if road["surface"] == "Concrete":  # slipways run into the sea
            continue
        low = min(at(x, z) for x, z in catmull(road["points"], 8))
        if low < 2:
            fails.append(f"road {road['id']} dips to Y {low:.1f}")
    (x0, z0), (x1, z1) = (640, 130), (1340, 590)  # Haven Sands, north to south end (layout GREAT_GALE)
    nx, nz = -(z1 - z0), x1 - x0
    k = 1 / np.hypot(nx, nz)
    nx, nz = nx * k, nz * k  # seaward normal (south-west)
    for t in np.linspace(0.15, 0.85, 8):
        bx, bz = x0 + t * (x1 - x0), z0 + t * (z1 - z0)
        if at(bx - 150 * nx, bz - 150 * nz) <= 0 or at(bx + 150 * nx, bz + 150 * nz) >= 0:
            fails.append(f"Haven Sands beach broken near ({bx:.0f}, {bz:.0f})")
    n_isl = check_islands(fails)
    for f in fails:
        print("FAIL", f)
    print(f"check_zones: {len(POINTS)} points, platform, basin, {len(L.ROADS)} roads, beach, {n_isl} island points: "
          + ("OK" if not fails else f"{len(fails)} failures"))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
