#!/usr/bin/env python3
"""Check the terrain bake against the layout (run after gen_terrain.py; exit 1 on any failure).

usage: python3 tools/world/check_zones.py

Reads map/generated/terrain_height.i16 and the island windows: the six player islands are Lego plates built from
Parts (WP-24) round an open lagoon (WP-27), so their ring must be open water deep enough for boats and the submarine (tests/HubLayout.spec.luau checks every lot, berth and
bridge); the bake windows are disjoint and on the tile grid; every outer island's landmark / stamp / landing is land,
its dock water a boat floats in, its pads dry; the Arches' Door channel is open."""
import json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))
X0, Z0, X1, Z1 = L.HUB_WINDOW["window"]
H = np.fromfile(os.path.join(REPO, "map/generated/terrain_height.i16"), "<i2").reshape(
    (Z1 - Z0) // L.CELL + 1, (X1 - X0) // L.CELL + 1) / 8.0

def at(x, z):
    return float(H[int(round((z - Z0) / L.CELL)), int(round((x - X0) / L.CELL))])


def check_islands(fails):
    """docs/21 archipelago: windows disjoint and on the tile grid, every island's landmark / stamp / landing on land,
    its dock in water a boat floats in (<= -4), every pad on land and the Door's channel open. Returns the number of points checked."""
    meta = json.load(open(os.path.join(REPO, "map/generated/terrain.json")))
    grids = {}
    for w in meta.get("windows", []):
        g = np.fromfile(os.path.join(REPO, "map/generated", w["height"]), "<i2").reshape(w["nz"], w["nx"]) / 8.0
        grids[w["id"]] = (w["originX"], w["originZ"], g)
    if sorted(grids) != sorted(i["id"] for i in L.ISLAND_WINDOWS):
        fails.append(f"bake windows {sorted(grids)} do not match layout.ISLAND_WINDOWS (re-run gen_terrain.py)")
        return 0
    boxes = [("Main", L.HUB_WINDOW["window"])] \
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
    arches = next(i for i in L.ISLAND_WINDOWS if i["id"] == "TheArches")
    for a in L.ARCHES:
        if y(arches, *a["center"]) > -4:
            fails.append(f"arch {a['id']} channel is not open water: bake Y {y(arches, *a['center']):.1f}")
    return n


def main():
    fails = []
    # WP-24 / WP-27: the player islands are Lego plates built from Parts round an open lagoon; the ring must be open
    # water deep enough for boats and the submarine round each plate, and the lagoon has no island.
    r = L.RING["islandRadius"]
    for p in L.PLAYER_ISLANDS:
        (cx, cz), b = p["center"], p["bearing"]
        for right, fwd in ((0, 0), (0.5 * r, -0.3 * r), (-0.5 * r, -0.3 * r), (0, -0.7 * r), (0, 0.5 * r),
                           (r + 40, 0), (-r - 40, 0), (0, r + 40), (0, -(r + 40))):
            y = at(*L.local(cx, cz, b, right, fwd))
            if y > -22:
                fails.append(f"plate ring at ({cx:.0f}, {cz:.0f}) +({right:.0f}, {fwd:.0f}) is only Y {y:.1f} deep")
    if at(*L.CENTER) > -22:
        fails.append(f"the lagoon centre is only Y {at(*L.CENTER):.1f} deep")
    n_isl = check_islands(fails)
    for f in fails:
        print("FAIL", f)
    print(f"check_zones: {len(L.PLAYER_ISLANDS)} plate rings, the lagoon, {n_isl} island points: "
          + ("OK" if not fails else f"{len(fails)} failures"))
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
