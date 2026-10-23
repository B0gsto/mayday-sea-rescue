#!/usr/bin/env python3
"""Check the terrain bake against the gameplay coordinates (run after gen_terrain.py; exit 1 on any failure).

usage: python3 tools/world/check_zones.py

Reads map/generated/terrain_height.i16 and checks that every place gameplay code hard-codes is still water or land
as before WP-3: GameConfig.Zones, CallTypes.SpawnZones fallbacks and fixed sites, RipCurrent, ColdOpen, the
WildlifeController seal haul-outs, MapConfig blips, LandVehicleConfig's Haven Head spawn, layout.POINTS (vehicle
spawns, handovers, the tower), the town platform (flat at Y 4), the harbour basin, every road centre line on land and
the Haven Sands beach (sand behind the waterline, sea in front)."""
import os, sys
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
    for f in fails:
        print("FAIL", f)
    print(f"check_zones: {len(POINTS)} points, platform, basin, {len(L.ROADS)} roads, beach: "
          + ("OK" if not fails else f"{len(fails)} failures"))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
