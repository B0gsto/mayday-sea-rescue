"""H1 M_Bld_Station: Port Haven lifeboat station (Gale Isles Coastguard), docs/12 2.2 row, 05 (North Atlantic harbour).

Two parallel sea-facing gables: the boat hall (granite ashlar, QuayStone) with a 6 x 4.6 m roller bay door and the
station board, and the two-storey crew wing (lime render with granite quoins) with the crew room, the first-floor
watch-room bay window facing the sea, chimney and mast. Slate roofs, stone gable copings and kneelers, cast gutters,
fascias and downpipes with brackets. Front (sea side) is -Y; 1 unit = 1 stud; authored in metres (geo.py).

Integration (map/Build.luau, greybox Station at x -140..-80, z -90..-40): place the pivot at (-110, 4, -65) yawed
180 degrees so the front faces +Z (the sea). ATT_Bay_01..04 are the greybox Bay1..Bay4 centres in that placement.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_Station --steps build,lod,validate,export,turntable
"""
import os
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
    "Housing": (0.5, 0.0, 1.0, 0.28)}


def rect(name, w, h):
    u0, v0, u1, v1 = D[name]
    pad = 0.003
    return ("rect", u0 + pad, v0 + pad, u1 - pad, v1 - pad, w, h)


STONE = ("tile", 2.0)
RENDER = ("tile", 4.0)
SLATE = ("tile", 2.0)
STEEL = rect("Steel", 0.4, 0.4)

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


def build():
    stone, render, roof, tr, det, door = (Part("Stone"), Part("Render"), Part("Roof"), Part("Trim"), Part("Details"),
                                          Part("BayDoor"))
    atts = {}
    geo.LEVEL = 3

    # ------------------------------------------------ walls
    def gable(part, x0, x1, y0, y1, slope, mode, parapet=0.22):
        xc = (x0 + x1) / 2
        rise = (x1 - x0) / 2 * slope
        part.prism([(x0, EAV), (x1, EAV), (x1, EAV + parapet), (xc, EAV + rise + parapet), (x0, EAV + parapet)], "y", y0, y1, mode)

    # boat hall, granite
    stone.box((XL, YF, 0), (XL + T, YB, EAV), STONE)
    stone.box((XL + T, YB - T, 0), (XM, YB, EAV), STONE)
    stone.box((XL, YF, 0), (-8.25, YF + T, EAV), STONE)                 # front piers
    stone.box((-2.25, YF, 0), (XM, YF + T, EAV), STONE)
    stone.box((-8.25, YF, 4.6), (-2.25, YF + T, EAV), STONE)            # over the door
    gable(stone, XL, XM, YF, YF + T, TH, STONE)
    gable(stone, XL, XM, YB - T, YB, TH, STONE)
    stone.box((-1.0, YF + T, 0), (-0.5, YB - T, EAV), STONE, skip=("-z",))  # partition
    stone.box((XL + T, YF + T, 0), (-1.0, YB - T, 0.08), STONE, skip=("-z",))   # hall floor (granite flags)
    # door surround, kneelers
    geo.LEVEL = 2
    stone.box((-8.62, YF - 0.12, 0), (-8.25, YF, 4.6), STONE, skip=("+y",))
    stone.box((-2.25, YF - 0.12, 0), (-1.88, YF, 4.6), STONE, skip=("+y",))
    stone.box((-8.7, YF - 0.16, 4.6), (-1.8, YF, 5.1), STONE, skip=("+y",))
    for x0, x1 in ((XL - 0.06, XL + 0.55), (XM - 0.55, XM + 0.55), (XR - 0.55, XR + 0.06)):
        for y0, y1 in ((YF - 0.06, YF + T), (YB - T, YB + 0.06)):
            stone.box((x0, y0, EAV - 0.35), (x1, y1, EAV + 0.32), STONE)
    # crew wing, lime render
    geo.LEVEL = 3
    render.box((XM, YF, 0), (XR, YF + T, EAV), RENDER, skip=("-z",))
    render.box((XR - T, YF + T, 0), (XR, YB - T, EAV), RENDER, skip=("-z",))
    render.box((XM, YB - T, 0), (XR, YB, EAV), RENDER, skip=("-z",))
    gable(render, XM, XR, YF, YF + T, TW, RENDER)
    gable(render, XM, XR, YB - T, YB, TW, RENDER)
    geo.LEVEL = 2
    # granite plinth (wing) with a gap for the crew door, quoins
    for (x0, x1) in ((XM, 0.55), (1.85, XR + 0.06)):
        stone.box((x0, YF - 0.06, 0), (x1, YF + 0.01, 0.6), STONE, skip=("-z", "+y"))
    stone.box((XR - 0.01, YF - 0.06, 0), (XR + 0.06, YB + 0.06, 0.6), STONE, skip=("-z", "-x"))
    stone.box((XM, YB - 0.01, 0), (XR, YB + 0.06, 0.6), STONE, skip=("-z", "-y"))
    geo.LEVEL = 1
    z, k = 0.6, 0
    while z < EAV - 0.4:
        long_x = k % 2 == 0
        for yc, sy in ((YF, 1), (YB, -1)):
            lx, ly = (0.6, 0.3) if long_x else (0.3, 0.6)
            ya, yb = sorted((yc - 0.06 * sy, yc + ly * sy))
            stone.box((XR - lx, ya, z), (XR + 0.06, yb, z + 0.3), STONE)
        z += 0.32
        k += 1
    # chimney
    geo.LEVEL = 2
    stone.box((6.0, 4.4, 9.0), (7.0, 5.1, 12.0), STONE, skip=("-z",))
    tr.box((5.92, 4.32, 12.0), (7.08, 5.18, 12.12), trim("Coping"))
    geo.LEVEL = 1
    for xp in (6.28, 6.72):
        det.tube((xp, 4.75, 12.12), (xp, 4.75, 12.45), 0.11, 8, rect("Housing", 0.7, 0.33))

    # ------------------------------------------------ roofs (slate), ridge caps, gable copings, gutters, fascia, valley
    def roof_plane(x_eave, x_ridge, slope, ovh=OVH):
        def zu(x):
            return EAV + abs(x - x_eave) * slope
        xo = x_eave - ovh if x_ridge > x_eave else x_eave + ovh
        zo = EAV - ovh * slope
        prof = [(xo, zo), (x_ridge, zu(x_ridge)), (x_ridge, zu(x_ridge) + SLAB), (xo, zo + SLAB)]
        roof.prism(prof, "y", YF + 0.2, YB - 0.2, SLATE)
        return xo, zo

    geo.LEVEL = 3
    xo1, zo1 = roof_plane(XL, XH, TH)
    roof_plane(XM, XH, TH, 0.0)
    roof_plane(XM, XW, TW, 0.0)
    xo4, zo4 = roof_plane(XR, XW, TW)
    for xc in (XH, XW):
        tr.prism([(xc - 0.17, RIDGE + 0.05), (xc + 0.17, RIDGE + 0.05), (xc + 0.1, RIDGE + 0.27), (xc - 0.1, RIDGE + 0.27)],
                 "y", YF + 0.15, YB - 0.15, trim("Coping"))
    geo.LEVEL = 2
    for x0, x1, slope in ((XL, XM, TH), (XM, XR, TW)):
        xc = (x0 + x1) / 2
        rise = (x1 - x0) / 2 * slope
        for y0, y1 in ((YF - 0.05, YF + T + 0.05), (YB - T - 0.05, YB + 0.05)):
            for xa, xb in ((x0 - 0.05, xc), (xc, x1 + 0.05)):
                za = EAV + 0.22 + (rise if xa == xc else 0.0) + (0 if xa == xc else -0.04)
                zb = EAV + 0.22 + (rise if xb == xc else 0.0) + (0 if xb == xc else -0.04)
                tr.prism([(xa, za), (xb, zb), (xb, zb + 0.13), (xa, za + 0.13)], "y", y0, y1, trim("Coping"))
    for xo, zo, out in ((xo1, zo1, -1), (xo4, zo4, 1)):
        xg = xo + out * 0.08
        r = 0.075
        prof = [(xg - r, zo + 0.02), (xg + r, zo + 0.02), (xg + r * 0.7, zo - r * 0.7), (xg, zo - r), (xg - r * 0.7, zo - r * 0.7)]
        tr.prism(prof, "y", YF - 0.1, YB + 0.1, trim("Gutter"))
        tr.box((min(xo, xo - out * 0.03), YF - 0.08, zo - 0.22), (max(xo, xo - out * 0.03), YB + 0.08, zo + 0.02), trim("Fascia"))
        # downpipes front and back with swan necks, brackets and shoes
        xw = XL - 0.07 if out < 0 else XR + 0.07
        for yp in ((YF + 0.35, YB - 0.35) if out < 0 else (YF + 0.9, YB - 0.9)):
            tr.tube((xw, yp, 0.18), (xw, yp, zo - 0.45), 0.045, 8, trim("Downpipe"))
            tr.tube((xg, yp, zo - 0.05), (xw, yp, zo - 0.45), 0.045, 8, trim("Downpipe"), caps=False)
            tr.tube((xw + out * 0.06, yp, 0.0), (xw, yp, 0.2), 0.055, 8, trim("Downpipe"))
            geo.LEVEL = 1
            zz = 1.0
            while zz < zo - 0.6:
                tr.box((xw - 0.07, yp - 0.07, zz), (xw + 0.07, yp + 0.07, zz + 0.06), trim("Flashing"))
                zz += 1.8
            geo.LEVEL = 2
    geo.LEVEL = 2
    det.prism([(XM - 0.3, 7.40), (XM, 7.16), (XM + 0.3, 7.37)], "y", YF + 0.2, YB - 0.2, rect("Lead", 2, 2))
    tr.tube((XM, YB + 0.12, 0.18), (XM, YB + 0.12, EAV - 0.4), 0.05, 8, trim("Downpipe"))
    tr.box((XM - 0.12, YB + 0.06, EAV - 0.6), (XM + 0.12, YB + 0.26, EAV - 0.36), trim("Flashing"))

    # ------------------------------------------------ windows and doors
    def window(wall, s, sill, w, h, part_jamb=stone, bars=True):
        geo.LEVEL = 2
        wall.box(part_jamb, s - w / 2 - 0.16, s + w / 2 + 0.16, 0, 0.07, sill + h, sill + h + 0.26, STONE)
        for a, b in ((s - w / 2 - 0.13, s - w / 2), (s + w / 2, s + w / 2 + 0.13)):
            wall.box(part_jamb, a, b, 0, 0.05, sill, sill + h, STONE)
        wall.box(tr, s - w / 2 - 0.1, s + w / 2 + 0.1, 0, 0.11, sill - 0.09, sill, trim("Sill"))
        f = 0.07
        for a, b, t0, t1 in ((s - w / 2, s - w / 2 + f, sill, sill + h), (s + w / 2 - f, s + w / 2, sill, sill + h),
                             (s - w / 2 + f, s + w / 2 - f, sill + h - f, sill + h), (s - w / 2 + f, s + w / 2 - f, sill, sill + f)):
            wall.box(tr, a, b, 0, 0.05, t0, t1, trim("WindowFrame"))
        geo.LEVEL = 1
        if bars:
            wall.box(tr, s - 0.02, s + 0.02, 0, 0.035, sill + f, sill + h - f, trim("GlazingBar"))
            wall.box(tr, s - w / 2 + f, s + w / 2 - f, 0, 0.045, sill + h * 0.5 - 0.03, sill + h * 0.5 + 0.03, trim("WindowFrame"))
        geo.LEVEL = 3
        wall.quad(det, s - w / 2 + f, s + w / 2 - f, 0.02, sill + f, sill + h - f, rect("Glass", w, h))

    def crew_door(wall, s, name):
        w, h = 1.0, 2.2
        geo.LEVEL = 2
        wall.box(stone, s - w / 2 - 0.2, s + w / 2 + 0.2, 0, 0.08, h + 0.45, h + 0.75, STONE)
        for a, b in ((s - w / 2 - 0.18, s - w / 2 - 0.06), (s + w / 2 + 0.06, s + w / 2 + 0.18)):
            wall.box(stone, a, b, 0, 0.06, 0, h + 0.45, STONE)
        for a, b, t0, t1 in ((s - w / 2 - 0.06, s - w / 2, 0, h + 0.45), (s + w / 2, s + w / 2 + 0.06, 0, h + 0.45),
                             (s - w / 2, s + w / 2, h, h + 0.08), (s - w / 2, s + w / 2, h + 0.39, h + 0.45)):
            wall.box(tr, a, b, 0, 0.07, t0, t1, trim("WindowFrame"))
        wall.box(det, s - w / 2, s + w / 2, 0, 0.04, 0, h, rect("CrewDoor", w, h))
        wall.quad(det, s - w / 2, s + w / 2, 0.02, h + 0.08, h + 0.39, rect("Glass", w, 0.31))
        wall.box(stone, s - w / 2 - 0.1, s + w / 2 + 0.1, 0, 0.3, 0, 0.12, STONE)        # granite step
        geo.LEVEL = 1
        wall.box(det, s - 0.09, s + 0.09, 0.05, 0.25, h + 0.85, h + 1.12, STEEL)         # lamp
        wall.box(det, s - 0.02, s + 0.02, 0, 0.25, h + 1.1, h + 1.14, STEEL)
        geo.LEVEL = 3
        p = wall.world(s, 0.3, 0.05)
        atts[name] = Vector((p.x, p.y, 0.0))

    front, back = Wall((0, -1, 0), YF), Wall((0, 1, 0), YB)
    west, east = Wall((-1, 0, 0), XL), Wall((1, 0, 0), XR)
    for y in (-4.5, 0.0, 4.5):
        window(west, -y, 2.6, 1.0, 2.0)
    window(back, 3.5, 1.0, 1.2, 1.4)
    crew_door(back, 7.5, "ATT_HallBackDoor")
    window(front, XH, 7.8, 0.9, 0.9, bars=False)
    crew_door(front, 1.2, "ATT_CrewDoor")
    for x in (4.6, 7.8):
        window(front, x, 0.95, 1.2, 1.5)
    window(front, 1.2, 4.3, 0.9, 1.3)
    window(front, XW, 7.75, 0.8, 1.0, bars=False)
    for y in (-5.0, 0.0, 5.0):
        for sill in (1.0, 4.3):
            window(east, y, sill, 1.2, 1.4)
    crew_door(back, -2.0, "ATT_WingBackDoor")
    for x in (-5.0, -8.0):
        window(back, x, 1.0, 1.2, 1.4)
    for x in (-2.0, -5.0, -8.0):
        window(back, x, 4.3, 1.1, 1.4)

    # watch-room bay (first floor, sea side): granite corbel, render apron, mullioned glazing, lead roof
    x0, x1, yo = 2.6, 7.4, YF - 0.75
    stone.box((x0 - 0.1, yo - 0.1, 3.5), (x1 + 0.1, YF, 3.8), STONE, skip=("+y",))
    render.box((x0, yo, 3.8), (x1, YF, 4.4), RENDER, skip=("+y",))
    tr.box((x0 - 0.04, yo - 0.06, 4.4), (x1 + 0.04, YF, 4.5), trim("Sill"), skip=("+y",))
    geo.LEVEL = 2
    posts = [x0, x0 + 1.6, x0 + 3.2, x1]
    for xp in posts:
        tr.box((xp - 0.06, yo - 0.02, 4.5), (xp + 0.06, yo + 0.1, 6.15), trim("WindowFrame"))
    for xa, xb in zip(posts, posts[1:]):
        det.face([(xa + 0.06, yo + 0.03, 4.5), (xb - 0.06, yo + 0.03, 4.5), (xb - 0.06, yo + 0.03, 6.15), (xa + 0.06, yo + 0.03, 6.15)],
                 rect("Glass", 1.5, 1.65), centre=((xa + xb) / 2, 0, 5.3))
        tr.box((xa + 0.06, yo - 0.0, 5.55), (xb - 0.06, yo + 0.08, 5.61), trim("GlazingBar"))
    for xs, sgn in ((x0, -1), (x1, 1)):
        tr.box((xs - 0.06, YF - 0.12, 4.5), (xs + 0.06, YF, 6.15), trim("WindowFrame"))
        det.face([(xs, yo + 0.1, 4.5), (xs, YF - 0.12, 4.5), (xs, YF - 0.12, 6.15), (xs, yo + 0.1, 6.15)],
                 rect("Glass", 0.5, 1.65), centre=(xs - sgn, (yo + YF) / 2, 5.3))
    tr.box((x0 - 0.05, yo - 0.05, 6.15), (x1 + 0.05, YF, 6.3), trim("Fascia"), skip=("+y",))
    geo.LEVEL = 3
    det.box((x0 - 0.12, yo - 0.12, 6.3), (x1 + 0.12, YF, 6.4), rect("Lead", 5.0, 1.0), skip=("+y",))
    atts["ATT_WatchRoom"] = Vector(((x0 + x1) / 2, YF + 1.2, 5.2))

    # station board over the bay door, lamps, mast
    det.box((-8.45, YF - 0.22, 5.3), (-2.05, YF - 0.16, 6.3), rect("Sign", 6.4, 1.0))
    geo.LEVEL = 1
    for xb in (-8.0, -2.5):
        det.box((xb - 0.03, YF - 0.16, 5.75), (xb + 0.03, YF, 5.85), STEEL)
    for xl in (-9.0, -1.5):
        det.box((xl - 0.1, YF - 0.45, 5.2), (xl + 0.1, YF - 0.25, 5.5), STEEL)
        det.box((xl - 0.02, YF - 0.3, 5.45), (xl + 0.02, YF, 5.49), STEEL)
    geo.LEVEL = 2
    det.tube((XH, YF + 0.6, RIDGE + 0.1), (XH, YF + 0.6, RIDGE + 3.6), 0.05, 8, STEEL)
    det.tube((XH - 0.6, YF + 0.6, RIDGE + 3.0), (XH + 0.6, YF + 0.6, RIDGE + 3.0), 0.025, 6, STEEL)
    det.box((XH - 0.12, YF + 0.48, RIDGE - 0.1), (XH + 0.12, YF + 0.72, RIDGE + 0.15), STEEL)

    # ------------------------------------------------ bay door (own MeshPart; rolls up into the housing)
    geo.LEVEL = 3
    door.box((-8.25, YF + 0.22, 0.0), (-2.25, YF + 0.3, 4.6), rect("RollerDoor", 6.0, 4.6), skip=("-z",))
    door.box((-8.25, YF + 0.18, 0.0), (-2.25, YF + 0.34, 0.08), STEEL)
    geo.LEVEL = 1
    for xg in (-8.25, -2.31):
        det.box((xg, YF + 0.14, 0), (xg + 0.06, YF + 0.38, 4.6), STEEL)
    geo.LEVEL = 2
    det.box((-8.35, YF + 0.36, 4.55), (-2.15, YF + 0.95, 5.2), rect("Housing", 6.2, 0.65))
    geo.LEVEL = 3
    atts["ATT_BayDoor"] = Vector((XH, YF - 0.5, 0.0))
    atts["ATT_BayDoorTop"] = Vector((XH, YF + 0.26, 4.6))
    atts["ATT_BoatHall"] = Vector((XH, 0.0, 0.08))
    atts["ATT_Sign"] = Vector((XH, YF - 0.22, 5.8))

    # ------------------------------------------------ recentre (origin "base"), objects, collision
    parts = [p for p in (stone, render, roof, tr, det, door) if p.faces]
    lo = Vector((min(p.bbox()[0].x for p in parts), min(p.bbox()[0].y for p in parts), min(p.bbox()[0].z for p in parts)))
    hi = Vector((max(p.bbox()[1].x for p in parts), max(p.bbox()[1].y for p in parts), max(p.bbox()[1].z for p in parts)))
    off = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    mats = {
        "Stone": ("QuayStone", geo.material("MI_Station_QuayStone", (0.28, 0.27, 0.25), 0.85)),
        "Render": ("Render", geo.material("MI_Station_Render", (0.42, 0.40, 0.36), 0.88)),
        "Roof": ("Slate", geo.material("MI_Station_Slate", (0.07, 0.08, 0.09), 0.6)),
        "Trim": ("Sheet", geo.material("MI_Station_Trim", (0.3, 0.3, 0.3), 0.6)),
        "Details": ("Details", geo.material("MI_Station_Details", (0.1, 0.12, 0.15), 0.4)),
        "BayDoor": ("Details", geo.material("MI_Station_BayDoor", (0.06, 0.09, 0.12), 0.5)),
    }
    meshes = []
    for p in parts:
        s, mat = mats[p.name]
        obj = p.to_object("%s_%s_LOD0" % (NAME, p.name), mat, off)
        meshes.append({"object": obj, "set": s})
        for li, lod in ((1, "LOD1"), (2, "LOD2")):
            o = p.to_object("%s_%s_%s" % (NAME, p.name, lod), mat, off, lod=li)
            meshes.append({"object": o, "set": s})
        print("[H1] %s %d tris" % (p.name, p.tris()))

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
        "waivers": {"LOD UV layout": "world-scale tiling UVs (trim sheet, B02 and own tiling sets): hand-made LODs drop small parts, so the UV bounds change; no baked layout to keep"},
        "sets": [
            {"name": "Station", "set": "Render", "size": 1024, "wet": True},
            {"name": "Station", "set": "Slate", "size": 1024, "wet": True},
            {"name": "Station", "set": "Details", "size": 1024, "wet": True},
            {"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": True, "dir": tex + "M_Bld_TrimSheet"},
            {"name": "Mat", "set": "QuayStone", "size": 1024, "wet": True, "dir": tex + "Materials"},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "bay_door_sign", "target": [(XH + off.x) * 3, (YF + off.y) * 3, 15.0], "dist": 30, "az": 15, "el": 8},
            {"name": "watch_room", "target": [(XW + off.x) * 3, (YF - 0.4 + off.y) * 3, 15.0], "dist": 18, "az": -25, "el": 5},
            {"name": "crew_door", "target": [(1.2 + off.x) * 3, (YF + off.y) * 3, 4.5], "dist": 9, "az": 20, "el": 5},
            {"name": "eaves_gutter_downpipe", "target": [(XR + off.x) * 3, (YF + 0.4 + off.y) * 3, 19.0], "dist": 8, "az": 50, "el": 10},
            {"name": "quoins_plinth", "target": [(XR + off.x) * 3, (YF + off.y) * 3, 3.0], "dist": 8, "az": 40, "el": 10},
            {"name": "roof_ridge_chimney", "target": [(6.5 + off.x) * 3, (4.7 + off.y) * 3, 32.0], "dist": 14, "az": 150, "el": 25},
        ],
    }
