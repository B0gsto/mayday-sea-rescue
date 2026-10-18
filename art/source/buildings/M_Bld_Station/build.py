"""H1 M_Bld_Station: Port Haven lifeboat station (Gale Isles Coastguard), docs/12 2.2 row, 05 (North Atlantic harbour).

Two parallel sea-facing gables: the boat hall (coursed granite ashlar, own Granite set) with a 6 x 4.6 m roller bay
door (guide channels, roll hood, slatted curtain) and the framed station board, and the two-storey crew wing (lime
render with long-and-short granite quoins) with the crew room, the first-floor watch-room bay window facing the sea,
chimney and mast. Walls are pierced: sashes sit in real reveals behind projecting sills (drips) and lintels; weathered
plinths; modelled slate courses (0.25 m gauge), angled ridge tiles, verges with bargeboards, half-round gutters on
brackets, fascias, soffits and downpipes. Front (sea side) is -Y; 1 unit = 1 stud; authored in metres (geo.py).

Integration (map/Build.luau, greybox Station at x -140..-80, z -90..-40): place the pivot at (-110, 4, -65) yawed
180 degrees so the front faces +Z (the sea). ATT_Bay_01..04 are the greybox Bay1..Bay4 centres in that placement.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_Station --steps build,lod,validate,export,turntable
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geo  # noqa: E402
from geo import Part, Wall, trim  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Station"
D = {  # Details atlas rects (maketex.DETAILS)
    "Sign": (0.0, 0.84, 1.0, 1.0), "RollerDoor": (0.0, 0.28, 0.5, 0.84), "Glass": (0.5, 0.56, 0.75, 0.84),
    "Steel": (0.5, 0.28, 0.75, 0.56), "CrewDoor": (0.75, 0.28, 1.0, 0.84), "Lead": (0.0, 0.0, 0.5, 0.28),
    "Housing": (0.5, 0.0, 0.75, 0.28), "Orange": (0.75, 0.0, 1.0, 0.28)}


def rect(name, w, h):
    u0, v0, u1, v1 = D[name]
    pad = 0.003
    return ("rect", u0 + pad, v0 + pad, u1 - pad, v1 - pad, w, h)


STONE = ("tile", 2.0)
RENDER = ("tile", 4.0)
SLATE = ("tile", 2.0)
STEEL = rect("Steel", 0.4, 0.4)
ORANGE = rect("Orange", 1.5, 0.3)
BASE = ("tile", 2.0)       # H2 GraniteBase: v = z / 2 m, rising damp below ~1.1 m

XL, XM, XR = -9.75, -0.75, 9.75
YF, YB = -8.1, 8.1
T = 0.5
EAV = 7.0
XH, HH = -5.25, 4.5          # hall centre / half span
XW, HW = 4.5, 5.25           # wing
RIDGE = 10.78
TH, TW = (RIDGE - EAV) / HH, (RIDGE - EAV) / HW
OVH = 0.25                   # eaves overhang
SLAB = 0.14


EOV = 0.31       # slate edge beyond the eaves wall face (was 0.25)
FASC = 0.255     # fascia back face (rafter feet) beyond the eaves wall face
VG = 0.30        # verge: slate edge beyond the gable face
GAUGE = 0.25     # slate course gauge: texture 8 courses per 2 m tile, tail of course k at v = k/8
CR = 0.4         # granite course: texture 5 courses per 2 m tile, bed joints at z = 0.4 k on vertical faces
SB = 0.12        # window sill block height
DW, DH, DT = 1.0, 2.2, 2.8   # crew door opening width, leaf height, head height


def gable_poly(x0, x1, slope):
    xc = (x0 + x1) / 2
    return [(x0, 0.0), (x1, 0.0), (x1, EAV), (xc, EAV + (x1 - x0) / 2 * slope), (x0, EAV)]


def build():
    stone, render, roof, tr, det, door = (Part("Stone"), Part("Render"), Part("Roof"), Part("Trim"), Part("Details"),
                                          Part("BayDoor"))
    plinth, lit = Part("Plinth"), Part("GlassLit")      # H2: damp base courses; switchable night glazing / lamp lenses
    atts = {}
    rng = random.Random(7)
    front, back = Wall((0, -1, 0), YF), Wall((0, 1, 0), YB)
    west, east = Wall((-1, 0, 0), XL), Wall((1, 0, 0), XR)
    side_rect = [(YF + T, 0.0), (YB - T, 0.0), (YB - T, EAV), (YF + T, EAV)]
    WALLS = {   # key: (part, frame, axis, a0, a1, profile, uv) - gable walls stop under the roof (verges, no parapets)
        "hall_front": (stone, front, "y", YF, YF + T, gable_poly(XL, XM, TH), STONE),
        "hall_west": (stone, west, "x", XL, XL + T, side_rect, STONE),
        "hall_back": (stone, back, "y", YB - T, YB, gable_poly(XL, XM, TH), STONE),
        "wing_front": (render, front, "y", YF, YF + T, gable_poly(XM, XR, TW), RENDER),
        "wing_east": (render, east, "x", XR - T, XR, side_rect, RENDER),
        "wing_back": (render, back, "y", YB - T, YB, gable_poly(XM, XR, TW),
                      ("tileo", 4.6, 0.37, 0.61, 0.055)),
    }
    # windows (wall, s, sill top, width, height, sash bars, keystone); granite-wall heads and sills sit on bed joints
    WIN = [("hall_west", -y, 2.4, 1.0, 2.0, True, False) for y in (-4.5, 0.0, 4.5)]
    WIN += [("hall_back", 3.5, 1.2, 1.2, 1.2, True, False), ("hall_front", XH, 7.6, 0.9, 0.8, False, False)]
    WIN += [("wing_front", x, 1.0, 1.2, 1.4, True, True) for x in (4.6, 7.8)]
    WIN += [("wing_front", 1.2, 4.4, 0.9, 1.2, True, True), ("wing_front", XW, 7.6, 0.8, 0.8, False, True)]
    WIN += [("wing_east", y, sill, 1.2, h, True, True) for y in (-5.0, 0.0, 5.0) for sill, h in ((1.0, 1.4), (4.4, 1.2))]
    WIN += [("wing_back", x, 1.0, 1.2, 1.4, True, True) for x in (-5.0, -8.0)]
    WIN += [("wing_back", x, 4.4, 1.1, 1.2, True, True) for x in (-2.0, -5.0, -8.0)]
    DOORS = [("hall_back", 7.5, "ATT_HallBackDoor"), ("wing_front", 1.2, "ATT_CrewDoor"), ("wing_back", -2.0, "ATT_WingBackDoor")]

    holes = {k: [] for k in WALLS}

    def hole(key, s0, s1, z0, z1):
        h0, h1 = sorted((WALLS[key][1].h(s0), WALLS[key][1].h(s1)))
        holes[key].append((h0, h1, z0, z1))
    for key, s, sill, w, h, _, _ in WIN:
        hole(key, s - w / 2, s + w / 2, sill - SB, sill + h)
    for key, s, _ in DOORS:
        hole(key, s - DW / 2, s + DW / 2, -1.0, DT)
    hole("hall_front", -8.25, -2.25, -1.0, 5.2)          # boat bay: 6 x 5.2 m opening, roller hood in its head

    # ------------------------------------------------ walls with real openings (reveals = the cut faces)
    geo.LEVEL = 3
    for key, (part, wall, axis, a0, a1, poly, mode) in WALLS.items():
        part.pierced(poly, axis, a0, a1, holes[key], mode)
    stone.box((-1.0, YF + T, 0), (-0.5, YB - T, EAV), STONE, skip=("-z",))      # partition
    stone.box((XL + T, YF + T, 0), (-1.0, YB - T, 0.08), STONE, skip=("-z",))   # hall floor (granite flags)

    # plinth with a weathered (sloped) top, both buildings, two courses (0 - 0.8 m), stopped at the doors
    geo.LEVEL = 3          # H2: plinth is its own MeshPart (GraniteBase), present in every LOD
    PL = [(-0.02, 0.0), (0.08, 0.0), (0.08, 0.66), (0.0, 0.8), (-0.02, 0.8)]
    for wall, s0, s1 in ((front, XL - 0.08, -8.65), (front, -1.85, 0.48), (front, 1.92, XR + 0.08),
                         (east, YF - 0.08, YB + 0.08), (west, -(YB + 0.08), -(YF - 0.08)),
                         (back, -(XR + 0.08), -2.72), (back, -1.28, 6.78), (back, 8.22, -(XL - 0.08))):
        wall.prism(plinth, s0, s1, PL, BASE)
    geo.LEVEL = 2
    # crew wing quoins: alternating long (0.6) and short (0.3) faces, one 0.4 m course each, 1.5 cm proud, 12 mm joints
    z, k = 0.8, 0
    while z + CR <= EAV - 0.15:
        lf, ls = (0.6, 0.3) if k % 2 == 0 else (0.3, 0.6)
        stone.box((XR - lf, YF - 0.015, z + 0.006), (XR + 0.015, YF + ls, z + CR - 0.006), STONE)
        stone.box((XR - lf, YB - ls, z + 0.006), (XR + 0.015, YB + 0.015, z + CR - 0.006), STONE)
        z += CR
        k += 1

    # ------------------------------------------------ windows: sash frames set 7-17 cm into the reveal, glass at -0.13
    def window(key, s, sill, w, h, bars, keystone):
        wall = WALLS[key][1]
        s0, s1, t0, top = s - w / 2, s + w / 2, sill - SB, sill + h
        f = 0.07
        geo.LEVEL = 2
        wall.prism(stone, s0 - 0.08, s1 + 0.08, [(-0.17, t0), (0.045, t0), (0.045, t0 - 0.015), (0.075, t0 - 0.015),
                                                   (0.075, t0 + 0.065), (-0.06, sill), (-0.17, sill)], STONE)   # sill, drip
        wall.box(stone, s0 - 0.18, s1 + 0.18, -0.17, 0.035, top - 0.004, top + CR, STONE)     # lintel through the reveal
        for a, b, z0, z1 in ((s0, s0 + f, sill, top), (s1 - f, s1, sill, top), (s0 + f, s1 - f, top - f, top),
                             (s0 + f, s1 - f, sill, sill + 0.06)):
            wall.box(tr, a, b, -0.17, -0.07, z0, z1, trim("WindowFrame"))
        geo.LEVEL = 1
        if keystone:
            wall.plate(stone, [(s - 0.08, top - 0.06), (s + 0.08, top - 0.06), (s + 0.11, top + CR + 0.03),
                               (s - 0.11, top + CR + 0.03)], 0.0, 0.065, STONE)
        if bars:
            mid = sill + h * 0.5
            wall.box(tr, s0 + f, s1 - f, -0.16, -0.08, mid - 0.03, mid + 0.03, trim("WindowFrame"))   # meeting rail
            wall.box(tr, s - 0.018, s + 0.018, -0.145, -0.105, sill + 0.06, top - f, trim("GlazingBar"))
        geo.LEVEL = 3
        wall.quad(det, s0 + f, s1 - f, -0.13, sill + 0.06, top - f, rect("Glass", w - 2 * f, h - f - 0.06))

    def crew_door(key, s, name):
        wall = WALLS[key][1]
        s0, s1 = s - DW / 2, s + DW / 2
        geo.LEVEL = 2
        wall.box(stone, s0 - 0.3, s1 + 0.3, -0.22, 0.34, 0, 0.15, STONE)                 # granite step / threshold
        for a, b in ((s0 - 0.22, s0), (s1, s1 + 0.22)):
            wall.box(stone, a, b, 0, 0.04, 0.15, DT, STONE)                              # architrave jambs
        wall.box(stone, s0 - 0.26, s1 + 0.26, -0.22, 0.06, DT - 0.004, DT + CR, STONE)    # lintel
        for a, b, z0, z1 in ((s0, s0 + 0.08, 0.15, DT), (s1 - 0.08, s1, 0.15, DT), (s0 + 0.08, s1 - 0.08, DT - 0.08, DT),
                             (s0 + 0.08, s1 - 0.08, DH, DH + 0.08)):
            wall.box(tr, a, b, -0.22, -0.1, z0, z1, trim("WindowFrame"))
        geo.LEVEL = 3
        wall.box(det, s0 + 0.08, s1 - 0.08, -0.2, -0.15, 0.15, DH, rect("CrewDoor", DW - 0.16, DH - 0.15))
        wall.quad(det, s0 + 0.08, s1 - 0.08, -0.17, DH + 0.08, DT - 0.08, rect("Glass", DW - 0.16, DT - DH - 0.16))
        geo.LEVEL = 1
        wall.plate(stone, [(s - 0.09, DT - 0.05), (s + 0.09, DT - 0.05), (s + 0.12, DT + CR + 0.03),
                           (s - 0.12, DT + CR + 0.03)], 0.0, 0.09, STONE)                # keystone
        if name == "ATT_CrewDoor":      # H2 swan-neck bracket lamp: wall plate, arm, lantern, lit lens (ATT_Lamp_Door)
            zl = DT + 0.62
            wall.box(det, s - 0.07, s + 0.07, 0.0, 0.02, zl + 0.1, zl + 0.36, STEEL)
            wall.box(det, s - 0.018, s + 0.018, 0.02, 0.34, zl + 0.3, zl + 0.34, STEEL)
            wall.box(det, s - 0.018, s + 0.018, 0.3, 0.34, zl + 0.2, zl + 0.32, STEEL)
            wall.box(det, s - 0.12, s + 0.12, 0.2, 0.44, zl + 0.16, zl + 0.2, ORANGE)       # hood
            wall.box(det, s - 0.09, s + 0.09, 0.23, 0.41, zl, zl + 0.16, STEEL)
            for o0 in (0.229, 0.411):
                wall.box(lit, s - 0.075, s + 0.075, o0 - 0.002, o0 + 0.002, zl + 0.015, zl + 0.15, rect("Glass", 0.15, 0.14))
            pl = wall.world(s, 0.32, zl + 0.05)
            atts["ATT_Lamp_Door"] = Vector((pl.x, pl.y, pl.z))
        else:
            wall.box(det, s - 0.09, s + 0.09, 0.05, 0.25, DT + 0.55, DT + 0.82, STEEL)       # lamp
            wall.box(det, s - 0.02, s + 0.02, 0, 0.25, DT + 0.8, DT + 0.84, STEEL)
        geo.LEVEL = 3
        p = wall.world(s, 0.3, 0.05)
        atts[name] = Vector((p.x, p.y, 0.0))

    for args in WIN:
        window(*args)
    for key, s, name in DOORS:
        crew_door(key, s, name)

    # ------------------------------------------------ watch-room bay: corbelled granite base, deep posts, recessed lights
    x0, x1, yo = 2.6, 7.4, YF - 0.75
    geo.LEVEL = 3
    stone.prism([(YF, 3.2), (YF, 4.0), (yo - 0.1, 4.0), (yo - 0.1, 3.72)], "x", x0 - 0.12, x1 + 0.12, STONE)
    render.box((x0, yo, 4.0), (x1, YF, 4.4), RENDER, skip=("+y",))
    stone.extrude([(YF, 4.4), (yo - 0.05, 4.4), (yo - 0.05, 4.385), (yo - 0.09, 4.385), (yo - 0.09, 4.45), (yo + 0.02, 4.52),
                   (YF, 4.52)], "x", x0 - 0.1, x1 + 0.1, STONE)                             # weathered sill with drip
    posts = [x0, x0 + 1.6, x0 + 3.2, x1]
    for xp in posts:
        tr.box((xp - 0.07, yo - 0.05, 4.52), (xp + 0.07, yo + 0.12, 6.15), trim("WindowFrame"))
    for xs in (x0, x1):
        tr.box((xs - 0.07, YF - 0.14, 4.52), (xs + 0.07, YF, 6.15), trim("WindowFrame"))
    for xa, xb in zip(posts, posts[1:]):
        det.face([(xa + 0.07, yo + 0.07, 4.62), (xb - 0.07, yo + 0.07, 4.62), (xb - 0.07, yo + 0.07, 6.05),
                  (xa + 0.07, yo + 0.07, 6.05)], rect("Glass", 1.46, 1.43), outward=(0, -1, 0))
        lit.face([(xa + 0.07, yo + 0.066, 4.62), (xb - 0.07, yo + 0.066, 4.62), (xb - 0.07, yo + 0.066, 6.05),
                  (xa + 0.07, yo + 0.066, 6.05)], rect("Glass", 1.46, 1.43), outward=(0, -1, 0))
    for xs, sgn in ((x0, -1), (x1, 1)):
        det.face([(xs, yo + 0.12, 4.62), (xs, YF - 0.14, 4.62), (xs, YF - 0.14, 6.05), (xs, yo + 0.12, 6.05)],
                 rect("Glass", 0.49, 1.43), outward=(sgn, 0, 0))
        lit.face([(xs + sgn * 0.004, yo + 0.12, 4.62), (xs + sgn * 0.004, YF - 0.14, 4.62), (xs + sgn * 0.004, YF - 0.14, 6.05),
                  (xs + sgn * 0.004, yo + 0.12, 6.05)], rect("Glass", 0.49, 1.43), outward=(sgn, 0, 0))
    det.box((x0 - 0.1, yo - 0.1, 6.15), (x1 + 0.1, YF, 6.3), ORANGE, skip=("+y",))          # H2 rescue-orange fascia
    det.prism([(YF, 6.33), (yo - 0.16, 6.33), (yo - 0.16, 6.37), (YF, 6.6)], "x", x0 - 0.16, x1 + 0.16, rect("Lead", 5.2, 1.0))
    geo.LEVEL = 2
    for xb in (x0 + 0.12, x0 + 1.6, x0 + 3.2, x1 - 0.12):                                    # corbel brackets
        stone.prism([(YF, 2.85), (YF, 3.3), (yo + 0.1, 3.7), (yo + 0.1, 3.5)], "x", xb - 0.12, xb + 0.12, STONE)
    tr.box((x0 - 0.14, yo - 0.14, 6.27), (x1 + 0.14, YF, 6.33), trim("Coping"), skip=("+y",))  # cornice
    for xa, xb in zip(posts, posts[1:]):
        for z0, z1 in ((4.52, 4.62), (6.05, 6.15), (5.55, 5.62)):
            tr.box((xa + 0.07, yo + 0.0, z0), (xb - 0.07, yo + 0.1, z1), trim("WindowFrame"))
    for xs in (x0, x1):
        for z0, z1 in ((4.52, 4.62), (6.05, 6.15), (5.55, 5.62)):
            tr.box((xs - 0.05, yo + 0.12, z0), (xs + 0.05, YF - 0.14, z1), trim("WindowFrame"))
    det.box((x0 - 0.16, YF - 0.025, 6.5), (x1 + 0.16, YF, 6.75), rect("Lead", 5.2, 0.25), skip=("+y",))   # upstand
    geo.LEVEL = 1
    for xa, xb in zip(posts, posts[1:]):
        xm = (xa + xb) / 2
        tr.box((xm - 0.018, yo + 0.03, 5.62), (xm + 0.018, yo + 0.09, 6.05), trim("GlazingBar"))
        tr.box((xm - 0.03, yo + 0.01, 4.62), (xm + 0.03, yo + 0.1, 5.55), trim("WindowFrame"))  # casement stiles
    for xr in (x0 + 1.6, x0 + 3.2):                                                             # lead rolls
        det.tube((xr, yo - 0.13, 6.385), (xr, YF - 0.03, 6.6), 0.022, 6, rect("Lead", 1.0, 0.1))
    geo.LEVEL = 3
    atts["ATT_WatchRoom"] = Vector(((x0 + x1) / 2, YF + 1.2, 5.2))

    # ------------------------------------------------ boat bay: granite surround, roller door, guides, hood, sign
    geo.LEVEL = 2
    for a, b in ((-8.65, -8.25), (-2.25, -1.85)):
        front.box(stone, a, b, 0, 0.12, 0, 5.2, STONE)
    front.box(stone, -8.75, -1.75, 0, 0.15, 5.2, 5.6, STONE)                                   # heavy lintel, 1 course
    geo.LEVEL = 3
    det.prism([(YF + 0.5, 4.585), (YF + 0.5, 5.2), (YF + 0.08, 5.2), (YF + 0.08, 4.80), (YF + 0.10, 4.69),
               (YF + 0.15, 4.62), (YF + 0.21, 4.585)], "x", -8.25, -2.25, rect("Housing", 6.0, 0.62))   # roll hood
    geo.LEVEL = 2
    chan = [(-8.25, 0.15), (-8.15, 0.15), (-8.15, 0.18), (-8.235, 0.18), (-8.235, 0.34), (-8.15, 0.34), (-8.15, 0.37),
            (-8.25, 0.37)]
    for mirror in (False, True):
        det.extrude([((2 * XH - x) if mirror else x, YF + y) for x, y in chan], "z", 0.0, 4.62, STEEL)   # guide channels
    U0, V0, U1, V1 = D["RollerDoor"]
    U0, V0, U1, V1 = U0 + 0.003, V0 + 0.003, U1 - 0.003, V1 - 0.003
    def door_uv(p):     # one RollerDoor rect over the whole curtain (x -8.25..-2.25, z 0..4.6); depth folds in for side faces
        dy = 0.05 * (p.y - YF - 0.2)
        fu = 0.01 + 0.98 * (p.x + 8.25) / 6.0 + dy
        fv = 0.01 + 0.98 * p.z / 4.6 + dy
        return (U0 + max(0.0, min(1.0, fu)) * (U1 - U0), V0 + max(0.0, min(1.0, fv)) * (V1 - V0))
    DUV = ("fn", door_uv)
    curtain = [(YF + 0.30, 0.1), (YF + 0.30, 4.6), (YF + 0.226, 4.6)]
    for j in range(45, 0, -1):                       # 46 slats of 0.1 m (texture slat joints at z = k/10)
        zj = j * 0.1
        curtain += [(YF + 0.213, zj + 0.075), (YF + 0.211, zj + 0.03), (YF + 0.226, zj)]
    geo.LEVEL = (0, 1)
    door.extrude(curtain, "x", -8.25, -2.25, DUV, caps=False)
    geo.LEVEL = (2,)
    door.box((-8.25, YF + 0.22, 0.1), (-2.25, YF + 0.30, 4.6), DUV, skip=("-z", "+z", "-x", "+x"))
    geo.LEVEL = 3
    door.prism([(YF + 0.20, 0.025), (YF + 0.33, 0.025), (YF + 0.33, 0.115), (YF + 0.215, 0.115), (YF + 0.195, 0.09)],
               "x", -8.25, -2.25, DUV)                                                          # bottom lip rail
    geo.LEVEL = 2
    door.box((-8.25, YF + 0.215, 0.0), (-2.25, YF + 0.31, 0.025), rect("Lead", 6.0, 0.1))      # rubber seal
    geo.LEVEL = 1
    for xh in (-6.6, -3.9):
        door.box((xh - 0.12, YF + 0.17, 0.05), (xh + 0.12, YF + 0.195, 0.085), STEEL)
        door.tube((xh + 0.2, YF + 0.195, 0.07), (xh + 0.2, YF + 0.175, 0.07), 0.018, 6, STEEL)
    geo.LEVEL = 3
    atts["ATT_BayDoor"] = Vector((XH, YF - 0.5, 0.0))
    atts["ATT_BayDoorTop"] = Vector((XH, YF + 0.26, 4.6))
    atts["ATT_BoatHall"] = Vector((XH, 0.0, 0.08))
    atts["ATT_Sign"] = Vector((XH, YF - 0.22, 5.8))

    # station board 6.4 x 1.0 in a bolted steel frame on stand-off brackets
    det.box((-8.45, YF - 0.22, 5.3), (-2.05, YF - 0.18, 6.3), rect("Sign", 6.4, 1.0))
    geo.LEVEL = 2
    for lo_, hi_ in (((-8.51, 6.3), (-1.99, 6.36)), ((-8.51, 5.24), (-1.99, 5.3)), ((-8.51, 5.3), (-8.45, 6.3)),
                     ((-2.05, 5.3), (-1.99, 6.3))):
        det.box((lo_[0], YF - 0.25, lo_[1]), (hi_[0], YF - 0.16, hi_[1]), STEEL)
    geo.LEVEL = 1
    for i in range(13):
        xb = -8.48 + i * 6.46 / 12
        for zb in (5.27, 6.33):
            det.tube((xb, YF - 0.25, zb), (xb, YF - 0.262, zb), 0.014, 6, STEEL)
    for xb in (-8.48, -2.02):
        for zb in (5.63, 5.97):
            det.tube((xb, YF - 0.25, zb), (xb, YF - 0.262, zb), 0.014, 6, STEEL)
    for xb in (-7.9, -6.2, -4.3, -2.6):
        det.box((xb - 0.03, YF - 0.17, 5.9), (xb + 0.03, YF, 5.98), STEEL)                    # stand-off arm
        det.box((xb - 0.07, YF - 0.012, 5.8), (xb + 0.07, YF, 6.08), STEEL)                   # wall plate
        for zb in (5.84, 6.04):
            det.tube((xb, YF - 0.012, zb), (xb, YF - 0.024, zb), 0.012, 6, STEEL)
    for k, xl in enumerate((-9.0, -1.5)):            # H2 floodlights: wall plate, yoke arm, tilted housing, lit lens
        det.box((xl - 0.08, YF - 0.02, 5.36), (xl + 0.08, YF, 5.62), STEEL)
        det.box((xl - 0.02, YF - 0.3, 5.47), (xl + 0.02, YF - 0.02, 5.51), STEEL)
        det.prism([(YF - 0.26, 5.52), (YF - 0.5, 5.4), (YF - 0.42, 5.2), (YF - 0.2, 5.36)], "x", xl - 0.15, xl + 0.15, STEEL)
        lit.face([(xl - 0.13, YF - 0.505, 5.395), (xl + 0.13, YF - 0.505, 5.395), (xl + 0.13, YF - 0.425, 5.215),
                  (xl - 0.13, YF - 0.425, 5.215)], rect("Glass", 0.26, 0.2), outward=(0, -1, -1))
        atts["ATT_Lamp_Flood_%02d" % (k + 1)] = Vector((xl, YF - 0.5, 5.28))
    det.box((-8.25, YF - 0.03, 4.92), (-2.25, YF + 0.09, 5.2), ORANGE, skip=("+y",))       # H2 orange pelmet over the shutter
    for sw_, xa, xb in ((front, XM, XR + 0.016),):                       # orange band under the wing eaves
        sw_.box(det, xa, xb, 0.0, 0.025, 6.8, 6.98, ORANGE)
    east.box(det, YF - 0.016, YB + 0.016, 0.0, 0.025, 6.42, 6.6, ORANGE)

    # ------------------------------------------------ roofs: battens/sarking slab + modelled slate courses
    def roof_plane(xe, xr, slope, outer):
        side = 1 if xr > xe else -1
        cos = 1.0 / math.sqrt(1.0 + slope * slope)
        x_edge = xe - side * EOV if outer else xe
        x_base = xe - side * FASC if outer else xe

        def zt(x):
            return EAV + (x - xe) * side * slope + SLAB

        def sl(x):
            return (x - x_edge) * side / cos
        # slate UV: u along the ridge (left to right from outside), v up the slope with the eaves tail at v = 0
        top_uv = ("fn", lambda p: (-side * p.y / 2.0, sl(p.x) / 2.0))

        def riser_uv(k):
            return ("fn", lambda p: (-side * p.y / 2.0, (k * GAUGE + 0.006 * (p.z - zt(p.x)) / 0.03) / 2.0))
        geo.LEVEL = 3
        roof.extrude([(x_base, zt(x_base) - SLAB), (xr, zt(xr) - SLAB), (xr, zt(xr)), (x_base, zt(x_base))], "y",
                     YF - VG + 0.07, YB + VG - 0.07, [SLATE, SLATE, top_uv, SLATE], cap_mode=SLATE)
        L = (xr - x_edge) * side / cos
        n = int(math.ceil(L / GAUGE - 1e-6))
        LO = 0.006
        hk = [0.027] + [0.019 + rng.uniform(-0.004, 0.004) for _ in range(n - 1)]
        top = []
        for k in range(n):
            sa, sb = k * GAUGE, min((k + 1) * GAUGE, L)
            xa, xb = x_edge + side * sa * cos, x_edge + side * sb * cos
            ob = LO if (k + 1) * GAUGE < L - 1e-6 else hk[k] + (LO - hk[k]) * (sb - sa) / GAUGE
            top += [(xa, zt(xa) + hk[k]), (xb, zt(xb) + ob)]
        prof = [(x_edge, zt(x_edge)), (xr, zt(xr))] + top[::-1]
        modes = [SLATE, SLATE]
        for i in range(2, len(prof)):
            j = 2 * n + 1 - i                      # prof[i] is top[j]
            if i == len(prof) - 1:
                modes.append(riser_uv(0))          # eaves tail face
            elif j % 2 == 1:
                modes.append(top_uv)               # course top, tail to the next course's tail
            else:
                modes.append(riser_uv(j // 2))     # tail riser of course j / 2
        geo.LEVEL = 2
        roof.extrude(prof, "y", YF - VG, YB + VG, modes, cap_mode=SLATE)
        return zt, side

    zt_hw, _ = roof_plane(XL, XH, TH, True)
    zt_he, _ = roof_plane(XM, XH, TH, False)
    zt_ww, _ = roof_plane(XM, XW, TW, False)
    zt_we, _ = roof_plane(XR, XW, TW, True)

    # ridge: angled ridge tiles 0.45 m with 10 mm joints over a mortar bed (one plain ridge in LOD2)
    for xc, slope in ((XH, TH), (XW, TW)):
        zw = RIDGE + SLAB - 0.21 * slope + 0.012
        prof = [(xc - 0.21, zw), (xc + 0.21, zw), (xc + 0.21, zw + 0.035), (xc, zw + 0.047 + 0.21 * slope),
                (xc - 0.21, zw + 0.035)]
        geo.LEVEL = (2,)
        tr.prism(prof, "y", YF - VG - 0.03, YB + VG + 0.03, trim("Coping"))
        geo.LEVEL = (0, 1)
        tr.prism([(xc - 0.19, zw), (xc + 0.19, zw), (xc, zw + 0.03 + 0.19 * slope)], "y", YF - VG - 0.02, YB + VG + 0.02,
                 trim("Coping"))
        y = YF - VG - 0.03
        while y < YB + VG + 0.03 - 1e-6:
            y1 = min(y + 0.45, YB + VG + 0.03)
            tr.prism(prof, "y", y, y1 - 0.01, trim("Coping"))
            y = y1

    # bargeboards on all four gables (slates oversail them by 4 cm)
    geo.LEVEL = 2
    for xa, xc, zt, outer in ((XL, XH, zt_hw, True), (XM, XH, zt_he, False), (XM, XW, zt_ww, False), (XR, XW, zt_we, True)):
        sd = 1 if xc > xa else -1
        xs = xa - sd * 0.28 if outer else xa
        bp = [(xs, zt(xs) - SLAB - 0.1), (xc, zt(xc) - SLAB - 0.1), (xc, zt(xc) - 0.005), (xs, zt(xs) - 0.005)]
        for y0, y1 in ((YF - VG + 0.04, YF - VG + 0.07), (YB + VG - 0.07, YB + VG - 0.04)):
            tr.prism(bp, "y", y0, y1, trim("Fascia"))

    # valley: lead lining over the slates
    geo.LEVEL = 3
    for zt, sd in ((zt_he, -1), (zt_ww, 1)):
        xv = XM + sd * 0.48
        det.prism([(XM, zt(XM) + 0.027), (xv, zt(xv) + 0.027), (xv, zt(xv) + 0.037), (XM, zt(XM) + 0.037)], "y",
                  YF - VG, YB + VG, rect("Lead", 2, 2))

    # eaves: fascia, boxed soffit, half-round gutters (open channel, rolled bead, brackets), downpipes
    for xe, out, slope in ((XL, -1, TH), (XR, 1, TW)):
        xbase = xe + out * FASC
        zsof = EAV - FASC * slope
        zc = EAV - EOV * slope + SLAB - 0.02             # gutter rim, just under the slate edge
        geo.LEVEL = 3
        tr.box((min(xbase, xe + out * 0.28), YF - VG + 0.07, zsof - 0.08), (max(xbase, xe + out * 0.28), YB + VG - 0.07,
               zsof + SLAB), trim("Fascia"))
        r, th = 0.065, 0.005

        def arc(rr, d0, z0, a0=math.pi, a1=2 * math.pi, segs=7):
            return [(xe + out * (d0 + rr * math.cos(a0 + (a1 - a0) * i / segs)), z0 + rr * math.sin(a0 + (a1 - a0) * i / segs))
                    for i in range(segs + 1)]
        gut = arc(r, 0.345, zc) + arc(r - th, 0.345, zc)[::-1]
        tr.extrude(gut, "y", YF - VG + 0.04, YB + VG - 0.04, trim("Gutter"), cap_mode=trim("Gutter"))
        geo.LEVEL = 2
        tr.box((min(xe, xbase), YF - VG + 0.07, zsof - 0.025), (max(xe, xbase), YB + VG - 0.07, zsof), trim("Fascia"))
        xw = xe + out * 0.13
        xg = xe + out * 0.345
        for yp in ((YF + 0.35, YB - 0.35) if out < 0 else (YF + 0.9, YB - 0.9)):
            geo.LEVEL = 2
            tr.tube((xg, yp, zc - 0.05), (xg, yp, zc - 0.16), 0.04, 8, trim("Downpipe"), caps=False)
            tr.tube((xg, yp, zc - 0.16), (xw, yp, zc - 0.42), 0.045, 8, trim("Downpipe"), caps=False)
            tr.tube((xw, yp, 0.22), (xw, yp, zc - 0.42), 0.045, 8, trim("Downpipe"))
            tr.tube((xw + out * 0.06, yp, 0.02), (xw, yp, 0.24), 0.05, 8, trim("Downpipe"))
            geo.LEVEL = 1
            zz = 1.2
            while zz < zc - 0.8:
                tr.box((xw - 0.055, yp - 0.055, zz), (xw + 0.055, yp + 0.055, zz + 0.05), trim("Flashing"))
                tr.box((min(xe, xw), yp - 0.015, zz + 0.01), (max(xe, xw), yp + 0.015, zz + 0.04), trim("Flashing"))
                zz += 1.6
        geo.LEVEL = 1
        tr.tube((xe + out * 0.414, YF - VG + 0.04, zc + 0.004), (xe + out * 0.414, YB + VG - 0.04, zc + 0.004), 0.008, 6,
                trim("Gutter"))                                                                  # rolled bead
        yb = YF - VG + 0.25
        while yb < YB + VG - 0.2:
            tr.extrude(arc(r + 0.006, 0.345, zc) + arc(r + 0.0005, 0.345, zc)[::-1], "y", yb, yb + 0.025, trim("Flashing"))
            tr.box((min(xe + out * 0.28, xe + out * 0.287), yb, zc - 0.01), (max(xe + out * 0.28, xe + out * 0.287), yb + 0.025,
                   zc + 0.05), trim("Flashing"))
            yb += 0.8
    geo.LEVEL = 2
    tr.tube((XM, YB + 0.14, 0.22), (XM, YB + 0.14, EAV - 0.45), 0.05, 8, trim("Downpipe"))      # valley downpipe
    tr.tube((XM, YB + 0.2, 0.02), (XM, YB + 0.14, 0.24), 0.055, 8, trim("Downpipe"))
    tr.box((XM - 0.13, YB + 0.03, EAV - 0.62), (XM + 0.13, YB + 0.28, EAV - 0.36), trim("Flashing"))   # hopper
    tr.tube((XM, YF - 0.14, 0.22), (XM, YF - 0.14, EAV - 0.45), 0.05, 8, trim("Downpipe"))      # H2 front valley downpipe
    tr.tube((XM, YF - 0.2, 0.02), (XM, YF - 0.14, 0.24), 0.055, 8, trim("Downpipe"))
    tr.box((XM - 0.13, YF - 0.28, EAV - 0.62), (XM + 0.13, YF - 0.03, EAV - 0.36), trim("Flashing"))
    det.prism([(XM - 0.5, EAV + 0.2), (XM + 0.5, EAV + 0.2), (XM + 0.5, EAV + 0.24), (XM - 0.5, EAV + 0.24)], "y",
              YF - VG - 0.06, YF - VG + 0.02, rect("Lead", 1.0, 0.1))                                    # valley outlet lip
    # H2 rear gable furniture: meter box, conduit to the eaves, vent grille, hose reel (breaks up the render)
    geo.LEVEL = 2
    back.box(det, -3.6, -3.1, 0.0, 0.16, 0.9, 1.55, rect("Housing", 0.5, 0.65))
    back.box(det, -3.37, -3.33, 0.0, 0.05, 1.55, 6.7, STEEL)
    back.box(det, -6.75, -6.25, 0.0, 0.03, 2.55, 2.85, rect("Lead", 0.5, 0.3))
    back.box(det, -9.1, -8.95, 0.0, 0.2, 1.05, 1.25, STEEL)
    geo.LEVEL = 1
    p_ = back.world(-9.0, 0.32, 1.15)
    det.tube((p_.x - 0.17, p_.y, p_.z), (p_.x + 0.17, p_.y, p_.z), 0.24, 12, ORANGE)
    geo.LEVEL = 2

    # chimney (granite, oversailing course, coping, pots, lead collar)
    geo.LEVEL = 2
    stone.box((6.0, 4.4, 9.0), (7.0, 5.1, 12.0), STONE, skip=("-z",))
    stone.box((5.96, 4.36, 11.6), (7.04, 5.14, 11.8), STONE)
    tr.box((5.92, 4.32, 12.0), (7.08, 5.18, 12.12), trim("Coping"))
    det.prism([(5.94, zt_we(5.94)), (7.06, zt_we(7.06)), (7.06, zt_we(7.06) + 0.16), (5.94, zt_we(5.94) + 0.16)], "y",
              4.34, 5.16, rect("Lead", 1.2, 0.2))
    det.prism([(7.0, zt_we(7.0) + 0.012), (7.3, zt_we(7.3) + 0.012), (7.3, zt_we(7.3) + 0.024), (7.03, zt_we(7.0) + 0.22),
               (7.0, zt_we(7.0) + 0.22)], "y", 4.3, 5.2, rect("Lead", 1.0, 0.3))                  # H2 apron flashing
    det.prism([(5.68, zt_we(5.68) + 0.03), (6.0, zt_we(6.0) + 0.03), (6.0, zt_we(6.0) + 0.26), (5.97, zt_we(6.0) + 0.26),
               (5.68, zt_we(5.68) + 0.07)], "y", 4.3, 5.2, rect("Lead", 1.0, 0.3))                 # back gutter
    geo.LEVEL = 1
    for xa in (6.0, 6.25, 6.5, 6.75):                                                             # step flashings
        for y0, y1 in ((4.385, 4.4), (5.1, 5.115)):
            det.box((xa, y0, zt_we(xa + 0.25) + 0.1), (xa + 0.25, y1, zt_we(xa) + 0.3), rect("Lead", 0.25, 0.2))
    for xp in (6.28, 6.72):
        det.tube((xp, 4.75, 12.12), (xp, 4.75, 12.45), 0.11, 8, rect("Housing", 0.7, 0.33))

    # mast on the hall ridge (front)
    geo.LEVEL = 2
    det.tube((XH, YF + 0.6, RIDGE + 0.1), (XH, YF + 0.6, RIDGE + 3.6), 0.05, 8, STEEL)
    det.tube((XH - 0.6, YF + 0.6, RIDGE + 3.0), (XH + 0.6, YF + 0.6, RIDGE + 3.0), 0.025, 6, STEEL)
    det.box((XH - 0.1, YF + 0.5, RIDGE + 0.15), (XH + 0.1, YF + 0.7, RIDGE + 0.36), STEEL)     # ridge clamp
    geo.LEVEL = 3

    # ------------------------------------------------ recentre (origin "base"), objects, collision
    parts = [p for p in (stone, render, roof, tr, det, door, plinth, lit) if p.faces]
    lo = Vector((min(p.bbox()[0].x for p in parts), min(p.bbox()[0].y for p in parts), min(p.bbox()[0].z for p in parts)))
    hi = Vector((max(p.bbox()[1].x for p in parts), max(p.bbox()[1].y for p in parts), max(p.bbox()[1].z for p in parts)))
    off = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    mats = {
        "Stone": ("Granite", geo.material("MI_Station_Granite", (0.28, 0.27, 0.25), 0.85)),
        "Render": ("Render", geo.material("MI_Station_Render", (0.42, 0.40, 0.36), 0.88)),
        "Roof": ("Slate", geo.material("MI_Station_Slate", (0.07, 0.08, 0.09), 0.6)),
        "Trim": ("Sheet", geo.material("MI_Station_Trim", (0.3, 0.3, 0.3), 0.6)),
        "Details": ("Details", geo.material("MI_Station_Details", (0.1, 0.12, 0.15), 0.4)),
        "BayDoor": ("Details", geo.material("MI_Station_BayDoor", (0.06, 0.09, 0.12), 0.5)),
        "Plinth": ("GraniteBase", geo.material("MI_Station_GraniteBase", (0.2, 0.2, 0.18), 0.7)),
        "GlassLit": ("Details", geo.material("MI_Station_GlassLit", (1.0, 0.72, 0.4), 0.3)),
    }
    meshes = []
    for p in parts:
        s, mat = mats[p.name]
        obj = p.to_object("%s_%s_LOD0" % (NAME, p.name), mat, off)
        meshes.append({"object": obj, "set": s})
        for li, lod in ((1, "LOD1"), (2, "LOD2")):
            o = p.to_object("%s_%s_%s" % (NAME, p.name, lod), mat, off, lod=li)
            meshes.append({"object": o, "set": s})
        print("[H1] %s tris LOD0 %d LOD1 %d LOD2 %d" % (p.name, p.tris(0), p.tris(1), p.tris(2)))
    print("[H1] total tris LOD0 %d LOD1 %d LOD2 %d" % tuple(sum(p.tris(i) for p in parts) for i in range(3)))

    col = Part("COL")
    col.box((XL, YF, 0), (XL + T, YB, EAV), STONE)
    col.box((XL + T, YB - T, 0), (XM, YB, EAV), STONE)
    col.box((XL, YF, 0), (-8.25, YF + T, EAV), STONE)
    col.box((-2.25, YF, 0), (XM, YF + T, EAV), STONE)
    col.box((-8.25, YF, 4.6), (-2.25, YF + T, EAV), STONE)
    col.box((XM - 0.25, YF, 0), (XR, YB, EAV), STONE)
    col.box((2.5, YF - 0.85, 3.5), (7.5, YF, 6.4), STONE)
    col.prism([(XL - OVH, EAV - 0.2), (XM, EAV - 0.2), (XH, RIDGE + 0.2)], "y", YF, YB, STONE)
    col.prism([(XM, EAV - 0.2), (XR + OVH, EAV - 0.2), (XW, RIDGE + 0.2)], "y", YF, YB, STONE)
    colobj = col.to_object(NAME + "_COL", None, off, weld=False)

    att_objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = ((p.x + off.x) * 3, (p.y + off.y) * 3, (p.z + off.z) * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)
    # greybox bays in station space (pivot at world (-110, 4, -65), yaw 180: world = pivot + (bx, bz, -by))
    for i in range(1, 5):
        wz = 4 + i * 22 - 8
        e = bpy.data.objects.new("ATT_Bay_%02d" % i, None)
        e.location = (-95 + 110, -(wz + 65), 0.2 - 4)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)

    sz = (hi - lo)
    print("[H1] bbox m %.2f x %.2f x %.2f" % (sz.x, sz.y, sz.z))
    tex = G + "assets/textures/"
    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 40000,
        "tier": "hero",
        "dims_m": (20.0, 16.7, None),
        "size_note": "depth includes the 0.75 m watch-room bay and the door surround",
        "origin": "base",
        "tiling": True,
        "waivers": {"texture sets": "H2: 6 sets = 5 own + the shared BldTrim sheet; GraniteBase (damp, salt-lined, algae base courses) is the granite with a rising-damp gradient, kept separate so the 2 m wall tile stays clean",
                    "LOD UV layout": "world-scale tiling UVs (trim sheet and own tiling sets): hand-made LODs drop small parts, so the UV bounds change; no baked layout to keep"},
        "sets": [
            {"name": "Station", "set": "Render", "size": 1024, "wet": True},
            {"name": "Station", "set": "Slate", "size": 1024, "wet": True},
            {"name": "Station", "set": "Details", "size": 1024, "wet": True},
            {"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": True, "dir": tex + "M_Bld_TrimSheet"},
            {"name": "Station", "set": "Granite", "size": 1024, "wet": True},
            {"name": "Station", "set": "GraniteBase", "size": 1024, "wet": True},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "bay_door_sign", "target": [(XH + off.x) * 3, (YF + off.y) * 3, 15.0], "dist": 30, "az": 15, "el": 8},
            {"name": "watch_room", "target": [(XW + off.x) * 3, (YF - 0.4 + off.y) * 3, 15.0], "dist": 18, "az": -25, "el": 5},
            {"name": "crew_door", "target": [(1.2 + off.x) * 3, (YF + off.y) * 3, 4.5], "dist": 9, "az": 20, "el": 5},
            {"name": "eaves_gutter_downpipe", "target": [(XR + off.x) * 3, (YF + 0.4 + off.y) * 3, 19.0], "dist": 8, "az": 50, "el": 10},
            {"name": "quoins_plinth", "target": [(XR + off.x) * 3, (YF + off.y) * 3, 3.0], "dist": 8, "az": 40, "el": 10},
            {"name": "rear_gable", "target": [(XW + off.x) * 3, (YB + off.y) * 3, 12.0], "dist": 34, "az": 180, "el": 8},
            {"name": "roof_ridge_chimney", "target": [(6.5 + off.x) * 3, (4.7 + off.y) * 3, 32.0], "dist": 14, "az": 150, "el": 25},
        ],
    }
