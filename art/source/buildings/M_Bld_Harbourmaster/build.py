"""M_Bld_Harbourmaster (docs/12 H4 row): the harbourmaster's office on the Port Haven quay.

Small two-storey dressed-granite office, 10 x 8 m, with a grey Delabole slate roof, stone gable copings, a rear-slope
chimney with terracotta pots, white-painted timber sash windows and a panelled door. The big front window carries the
storm queue board (whiteboard, navy header, "NONE WAITING") behind the glass. A brass HARBOUR MASTER plate sits over
the door, with a tide table board on the front pier, a lifebuoy on a bracket on the east wall, and a signal mast with a
weather vane on the ridge. Salt-weathered granite and slate come from the shared kit sets.

    python3 art/source/buildings/M_Bld_Harbourmaster/maketex.py
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/buildings/M_Bld_Harbourmaster/build.py \
      --out-root build/prod/M_Bld_Harbourmaster --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import geo  # noqa: E402
from atlas import RECTS  # noqa: E402
from geo import Part, Wall, trim  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Harbourmaster"
TEXDIR = G + "build/prod/M_Bld_Harbourmaster/textures"

# frame (metres, x3 = studs)
X0, X1, Y0, Y1 = -5.0, 5.0, -4.0, 4.0
WALL = 0.5
IX0, IX1, IY0, IY1 = X0 + WALL, X1 - WALL, Y0 + WALL, Y1 - WALL
E, R = 5.2, 7.3                 # eaves / ridge
S = (R - E) / Y1
SLAB, OVH, PAR = 0.15, 0.25, 0.18
STONE_T, SLATE_T = 2.0, 2.0

DOOR = (-4.10, -3.00, 0.16, 2.38)
BIG = (-1.55, 2.45, 0.95, 2.45)
UP_FRONT = [(-3.75, -2.55, 3.45, 4.78), (0.80, 2.20, 3.45, 4.78)]
UP_BACK = [(-0.30, 1.10, 3.45, 4.72)]
GF_BACK = [(-2.85, -1.65, 1.15, 2.35)]
SIDE_E = [(-1.05, 0.25, 3.45, 4.72), (1.05, 2.05, 1.25, 2.35)]

GW = 6.0                          # own coursed-granite tile width (metres); band maps z over the full wall height
STONE = ("band", GW, 0.0, 1.0, 0.0, 7.70)     # z maps straight into the tile; top = the gable apex
STONE_CH = ("band", GW, 0.40, 0.44, 7.78, 0.26)                 # chimney: mid-tile courses at true block size
STONE_GA = STONE                                                # gable infill continues the wall courses
SLATE = ("tile", SLATE_T)
FRAME = ("trim", RECTS["WhiteJoin"][1] + 0.004, RECTS["WhiteJoin"][3] - 0.004, 1.0)
BAR = FRAME
SILL = ("trim", RECTS["Granite"][1] + 0.004, RECTS["Granite"][3] - 0.004, 1.0)
COPE = SILL
FASCIA = trim("Fascia")
PANEL = FRAME
GUTTER = trim("Gutter")
PIPE = trim("Downpipe")
FLASH = trim("Flashing")
GLASS = ("rect", *RECTS["Glass"], 2.0, 2.0)
BRASS = ("rect", *RECTS["Brass"], 0.35, 0.35)
IRON = ("rect", *RECTS["Iron"], 0.5, 0.5)
WHITE = ("rect", *RECTS["WhitePaint"], 0.5, 0.42)
RED = ("rect", *RECTS["RedPaint"], 0.5, 0.5)
ROPE = ("rect", *RECTS["Rope"], 0.5, 0.5)
POTS = ("rect", *RECTS["Pots"], 0.5, 0.5)


def rect(name, w, h):
    u0, v0, u1, v1 = RECTS[name]
    return ("rect", u0, v0, u1, v1, w, h)


def zu(y):
    return E + (Y1 - abs(y)) * S


def zt(y):
    return zu(y) + SLAB


def slope_prism(part, y0, y1, x0, x1, dz0, dz1, mode, caps=True):
    prof = [(y0, zu(y0) + dz0), (y1, zu(y1) + dz0), (y1, zu(y1) + dz1), (y0, zu(y0) + dz1)]
    part.prism(prof, "x", x0, x1, mode, caps=caps)


def holed_wall(part, axis, w_out, w_in, s0, s1, t0, t1, holes, mode, ends=(True, True), top=True):
    part.prim += 1

    def P(s, w, t):
        return (s, w, t) if axis == "y" else (w, s, t)

    wm = (w_out + w_in) / 2
    ss = sorted({s0, s1, *[h[0] for h in holes], *[h[1] for h in holes]})
    ts = sorted({t0, t1, *[h[2] for h in holes], *[h[3] for h in holes]})

    def solid(s, t):
        return not any(h[0] < s < h[1] and h[2] < t < h[3] for h in holes)

    for a, b in zip(ss, ss[1:]):
        for c, d in zip(ts, ts[1:]):
            if not solid((a + b) / 2, (c + d) / 2):
                continue
            for w in (w_out, w_in):
                part.face([P(a, w, c), P(b, w, c), P(b, w, d), P(a, w, d)], mode,
                          centre=P((a + b) / 2, wm, (c + d) / 2))
    for h in holes:
        a, b, c, d = h
        sm, tm = (a + b) / 2, (c + d) / 2
        part.face([P(a, w_out, c), P(a, w_in, c), P(a, w_in, d), P(a, w_out, d)], mode, centre=P(a - 1, wm, tm))
        part.face([P(b, w_out, c), P(b, w_in, c), P(b, w_in, d), P(b, w_out, d)], mode, centre=P(b + 1, wm, tm))
        if d < t1:
            part.face([P(a, w_out, d), P(b, w_out, d), P(b, w_in, d), P(a, w_in, d)], mode, centre=P(sm, wm, d + 1))
        if c > t0:
            part.face([P(a, w_out, c), P(b, w_out, c), P(b, w_in, c), P(a, w_in, c)], mode, centre=P(sm, wm, c - 1))
    for k, s in enumerate((s0, s1)):
        if not ends[k]:
            continue
        for c, d in zip(ts, ts[1:]):
            if solid(s + (1e-3 if k == 0 else -1e-3), (c + d) / 2):
                part.face([P(s, w_out, c), P(s, w_in, c), P(s, w_in, d), P(s, w_out, d)], mode,
                          centre=P(s + (1 if k == 0 else -1), wm, (c + d) / 2))
    if top:
        for a, b in zip(ss, ss[1:]):
            if solid((a + b) / 2, t1 - 1e-3):
                part.face([P(a, w_out, t1), P(b, w_out, t1), P(b, w_in, t1), P(a, w_in, t1)], mode,
                          centre=P((a + b) / 2, wm, t1 - 1))


def dress_window(pt, w, s0, s1, t0, t1):
    """Dressed granite surround: two-stone head, three-stone jambs each side, projecting sill with a drip step."""
    geo.LEVEL = 2
    mid = (s0 + s1) / 2
    for a, b in ((s0 - 0.18, mid - 0.005), (mid + 0.005, s1 + 0.18)):
        w.box(pt, a, b, -0.03, 0.185, t1, t1 + 0.26, SILL, skip_back=True)
    w.box(pt, s0 - 0.20, s1 + 0.20, -0.04, 0.22, t0 - 0.21, t0 - 0.11, SILL, skip_back=True)
    w.box(pt, s0 - 0.18, s1 + 0.18, -0.04, 0.24, t0 - 0.11, t0 + 0.005, SILL, skip_back=True)
    geo.LEVEL = 1
    for sa, sb in ((s0 - 0.16, s0), (s1, s1 + 0.16)):
        for i in range(3):
            za = t0 + (t1 - t0) * i / 3 + 0.006
            zb = t0 + (t1 - t0) * (i + 1) / 3 - 0.006
            w.box(pt, sa, sb, -0.03, 0.175, za, zb, SILL, skip_back=True)
    w.box(pt, s0 - 0.16, s1 + 0.16, 0.145, 0.190, t1 - 0.020, t1 + 0.005, SILL, skip_back=True)
    for k in range(3):
        sc = s0 + 0.28 + (s1 - s0 - 0.56) * k / 2.0
        w.box(pt, sc - 0.075, sc + 0.075, -0.02, 0.175, t0 - 0.30, t0 - 0.21, SILL, skip_back=True)
        w.box(pt, sc - 0.050, sc + 0.050, -0.02, 0.145, t0 - 0.37, t0 - 0.30, SILL, skip_back=True)
    geo.LEVEL = 2


def dress_door(pt, w, s0, s1, t0, t1):
    """Granite door surround: five-stone jambs, lintel with a keystone, threshold step."""
    for sa, sb in ((s0 - 0.16, s0), (s1, s1 + 0.16)):
        for i in range(5):
            za = 0.50 + (t1 - 0.50) * i / 5 + 0.006
            zb = 0.50 + (t1 - 0.50) * (i + 1) / 5 - 0.006
            w.box(pt, sa, sb, -0.03, 0.20, za, zb, SILL, skip_back=True)
    mid = (s0 + s1) / 2
    w.box(pt, s0 - 0.17, mid - 0.18, -0.03, 0.21, t1, t1 + 0.28, SILL, skip_back=True)
    w.box(pt, mid + 0.18, s1 + 0.17, -0.03, 0.21, t1, t1 + 0.28, SILL, skip_back=True)
    w.box(pt, mid - 0.18, mid + 0.18, -0.03, 0.23, t1 - 0.06, t1 + 0.34, SILL, skip_back=True)
    w.box(pt, s0 - 0.20, s1 + 0.20, -0.04, 0.24, t0 - 0.06, t0 + 0.02, SILL, skip_back=True)


def build():
    geo.LEVEL = 2
    stone, roof, tr, join, det, glass = (Part("Stone"), Part("Roof"), Part("Trim"), Part("Joinery"),
                                         Part("Details"), Part("Glass"))

    atts = {}
    front = Wall((0, -1, 0), Y0)
    back = Wall((0, 1, 0), Y1)
    east = Wall((1, 0, 0), X1)

    # ================================================= walls
    holes_front = [DOOR, BIG] + UP_FRONT
    holed_wall(stone, "y", Y0, IY0, X0, X1, 0.0, E, holes_front, STONE, top=False)
    holes_back = GF_BACK + [(-x1, -x0, z0, z1) for x0, x1, z0, z1 in UP_BACK]
    holed_wall(stone, "y", Y1, IY1, X0, X1, 0.0, E, holes_back, STONE, top=False)
    holes_e = [(y0, y1, z0, z1) for y0, y1, z0, z1 in SIDE_E]
    holed_wall(stone, "x", X1, IX1, IY0, IY1, 0.0, E, holes_e, STONE, ends=(False, False), top=False)
    holed_wall(stone, "x", X0, IX0, IY0, IY1, 0.0, E, [], STONE, ends=(False, False), top=False)
    for yo, yi in ((Y0, IY0), (Y1, IY1)):
        stone.prism([(yo, E), (yi, E), (yi, zu(yi))], "x", IX0, IX1, STONE)
    for x0, x1 in ((X0, IX0), (IX1, X1)):
        stone.prism([(Y0, E), (Y1, E), (Y1, zt(Y1) + PAR), (0.0, zt(0) + PAR), (Y0, zt(Y0) + PAR)],
                    "x", x0, x1, STONE_GA)

    # plinth (proud, weathered top)
    pl = [(Y0, 0.0), (Y0 - 0.07, 0.0), (Y0 - 0.07, 0.42), (Y0, 0.50)]
    for xa, xb in ((X0 - 0.02, DOOR[0] - 0.06), (DOOR[1] + 0.06, X1 + 0.02)):
        stone.prism(pl, "x", xa, xb, STONE)
    stone.prism([(Y1, 0.0), (Y1 + 0.07, 0.0), (Y1 + 0.07, 0.42), (Y1, 0.50)], "x", X0 - 0.02, X1 + 0.02, STONE)
    for xw, sg in ((X0, -1), (X1, 1)):
        stone.prism([(xw, 0.0), (xw + 0.07 * sg, 0.0), (xw + 0.07 * sg, 0.42), (xw, 0.50)], "y", Y0, Y1, STONE)

    # quoins, string course, eaves cornice
    z, k = 0.50, 0
    while z < E - 0.32:
        for xc, sx in ((X0, 1), (X1, -1)):
            for yc, sy in ((Y0, 1), (Y1, -1)):
                lx, ly = (0.62, 0.34) if k % 2 == 0 else (0.34, 0.62)
                xa, xb = sorted((xc - 0.03 * sx, xc + lx * sx))
                ya, yb = sorted((yc - 0.03 * sy, yc + ly * sy))
                join.box((xa, ya, z + 0.01), (xb, yb, z + 0.34), SILL)
        z += 0.35
        k += 1
    def course(w, s0, s1, t0, t1, nty):
        geo.LEVEL = 2
        w.box(join, s0, s1, -0.01, 0.052, t0 + 0.004, t1 - 0.004, COPE, skip_back=True)
        geo.LEVEL = 1
        step = (s1 - s0) / nty
        for i in range(nty):
            a = s0 + i * step + 0.005
            b = a + step - 0.010
            w.box(join, a, b, -0.01, 0.064 + 0.005 * (i % 2), t0, t1, COPE, skip_back=True)
        geo.LEVEL = 2
    for w, s0, s1 in ((front, X0 - 0.01, X1 + 0.01), (back, X0 - 0.01, X1 + 0.01)):
        course(w, s0, s1, 2.80, 2.90, 9)
        course(w, s0, s1, E - 0.18, E + 0.02, 9)
    for w in (east, Wall((-1, 0, 0), X0)):
        course(w, IY0, IY1, 2.80, 2.90, 7)
        course(w, IY0, IY1, E - 0.18, E + 0.02, 7)

    # gable kneelers and copings
    for xa, xb in ((X0 - 0.05, IX0 + 0.06), (IX1 - 0.06, X1 + 0.05)):
        for ya, yb in ((Y0 - OVH - 0.02, Y0 + 0.55), (Y1 - 0.55, Y1 + OVH + 0.02)):
            join.box((xa, ya, E - 0.30), (xb, yb, zt(Y0) + PAR + 0.12), COPE)
        for ya, yb in ((Y0 + 0.5, 0.0), (0.0, Y1 - 0.5)):
            prof = [(ya, zt(ya) + PAR), (yb, zt(yb) + PAR), (yb, zt(yb) + PAR + 0.12), (ya, zt(ya) + PAR + 0.12)]
            join.prism(prof, "x", xa, xb, COPE)

    # ================================================= roof
    slope_prism(roof, Y0 - OVH, 0.0, IX0, IX1, 0.0, SLAB, SLATE)
    slope_prism(roof, 0.0, Y1 + OVH, IX0, IX1, 0.0, SLAB, SLATE)
    # ridge: 20 lapped half-round ridge tiles, a lead strip each side, lead saddles at the verges
    zr = zt(0) - 0.02
    nrt, tl = 20, (IX1 - IX0) / 20.0
    for i in range(nrt):
        x0 = IX0 + i * tl - (0.025 if i else 0.0)
        x1 = x0 + tl + (0.030 if i < nrt - 1 else 0.0)
        tr.tube((x0, 0.0, zr), (x1, 0.0, zr), 0.120, 8, FLASH, caps=(i == 0 or i == nrt - 1))
    for sg in (-1, 1):
        slope_prism(tr, sg * 0.10, sg * 0.30, IX0 - 0.02, IX1 + 0.02, SLAB - 0.004, SLAB + 0.016, FLASH)
        join.box((IX0 - 0.03, min(sg * 0.02, sg * 0.20), zr - 0.02),
                 (IX0 + 0.12, max(sg * 0.02, sg * 0.20), zr + 0.13), FLASH)
        join.box((IX1 - 0.12, min(sg * 0.02, sg * 0.20), zr - 0.02),
                 (IX1 + 0.03, max(sg * 0.02, sg * 0.20), zr + 0.13), FLASH)
    # slate edge: thicker eaves course, three lapped courses, lead verges
    for sg in (-1, 1):
        for k in range(5):
            ya = sg * (Y1 + OVH - 0.02 - k * 0.23)
            yb = sg * (Y1 + OVH - 0.22 - k * 0.23)
            slope_prism(roof, min(ya, yb), max(ya, yb), IX0, IX1, -0.004, 0.012, SLATE)
        slope_prism(roof, sg * (Y1 + OVH - 0.02), sg * (Y1 + OVH + 0.015), IX0, IX1, -0.055, 0.006, SLATE)
    for xv, yv in ((-0.55, 1.55), (1.15, 2.35)):
        zv = zu(yv) + SLAB
        join.tube((xv, yv, zv - 0.02), (xv, yv, zv + 0.22), 0.058, 10, FLASH)
        join.tube((xv, yv, zv + 0.22), (xv, yv, zv + 0.30), 0.085, 10, FLASH)
        join.tube((xv, yv, zv + 0.30), (xv, yv, zv + 0.32), 0.060, 10, FLASH)
    for xa, xb in ((IX0 - 0.03, IX0 + 0.01), (IX1 - 0.01, IX1 + 0.03)):
        slope_prism(roof, Y0 - OVH, 0.0, xa, xb, -0.035, 0.010, SLATE)
        slope_prism(roof, 0.0, Y1 + OVH, xa, xb, -0.035, 0.010, SLATE)
        slope_prism(tr, Y0 - OVH, 0.0, (xa + xb) / 2 - 0.035, (xa + xb) / 2 + 0.035, 0.008, 0.020, FLASH)
        slope_prism(tr, 0.0, Y1 + OVH, (xa + xb) / 2 - 0.035, (xa + xb) / 2 + 0.035, 0.008, 0.020, FLASH)

    # chimney on the rear slope
    cx0, cx1, cy = -2.95, -2.25, 2.30
    stone.box((cx0, cy - 0.36, zt(cy) - 0.55), (cx1, cy + 0.36, 8.02), STONE_CH, skip=("-z",))
    join.box((cx0 - 0.07, cy - 0.43, 8.02), (cx1 + 0.07, cy + 0.43, 8.14), COPE)
    for zb in (7.82, 7.92):
        join.box((cx0 - 0.045, cy - 0.405, zb), (cx1 + 0.045, cy + 0.405, zb + 0.035), COPE)
    # tapered terracotta pots: stepped body, two collars, rolled rim on a square base
    for xp in (cx0 + 0.20, cx1 - 0.20):
        det.box((xp - 0.19, cy - 0.19, 8.14), (xp + 0.19, cy + 0.19, 8.20), POTS)
        prof = [(0.00, 0.150), (0.09, 0.143), (0.17, 0.132), (0.25, 0.122), (0.32, 0.116), (0.39, 0.120),
                (0.44, 0.132)]
        for (za, ra), (zb, rb) in zip(prof, prof[1:]):
            det.tube((xp, cy, 8.20 + za), (xp, cy, 8.20 + zb), (ra + rb) / 2, 14, POTS, caps=False)
            if za in (0.17, 0.32):
                det.tube((xp, cy, 8.20 + za - 0.015), (xp, cy, 8.20 + za + 0.015), rb + 0.012, 14, POTS, caps=False)
        det.tube((xp, cy, 8.64), (xp, cy, 8.665), 0.145, 14, POTS)
        det.tube((xp, cy, 8.20), (xp, cy, 8.30), 0.150, 14, POTS, caps=False)
    for sg in (-1, 1):
        slope_prism(tr, cy + sg * 0.36, cy + sg * 0.72, cx0 - 0.10, cx1 + 0.10, SLAB - 0.02, SLAB + 0.035, FLASH)

    # gutters, fascia, downpipes: ogee gutter, iron brackets, hoppers, collars, shoes
    geo.LEVEL = 1
    for sg in (-1, 1):
        ye = sg * (Y1 + OVH)
        yc = ye + sg * 0.10
        zo = zu(Y1 + OVH)
        tr.box((IX0 + 0.04, min(ye, ye + sg * 0.03), zo - 0.22), (IX1 - 0.04, max(ye, ye + sg * 0.03), zo + 0.04), FASCIA)
        tr.tube((IX0 + 0.04, yc, zo - 0.03), (IX1 - 0.04, yc, zo - 0.03), 0.072, 12, GUTTER)
        for k in range(11):
            xb = IX0 + 0.32 + k * (IX1 - IX0 - 0.64) / 10.0
            det.box((xb - 0.022, min(ye, yc + sg * 0.07), zo - 0.115),
                    (xb + 0.022, max(ye, yc + sg * 0.07), zo - 0.075), IRON)
        for xc0, xc1 in ((IX0 + 0.03, IX0 + 0.09), (IX1 - 0.09, IX1 - 0.03)):
            det.box((xc0, ye - 0.085, zo - 0.11), (xc1, ye + 0.085, zo + 0.06), IRON)
        for xp in (X0 + 0.55, X1 - 0.55):
            yw = Y0 - 0.10 if sg < 0 else Y1 + 0.10
            det.box((xp - 0.10, min(yc, yc + sg * 0.10), zo - 0.34),
                    (xp + 0.10, max(yc, yc + sg * 0.10), zo - 0.06), IRON)
            tr.tube((xp, yc, zo - 0.10), (xp, yw, zo - 0.55), 0.048, 10, PIPE, caps=False)
            tr.tube((xp, yw, zo - 0.55), (xp, yw, 0.24), 0.048, 10, PIPE)
            geo.LEVEL = 2
            zz = 0.95
            while zz < E - 0.5:
                geo.LEVEL = 1
                det.box((xp - 0.068, (Y0 - 0.17 if sg < 0 else Y1 + 0.09), zz),
                        (xp + 0.068, (Y0 - 0.09 if sg < 0 else Y1 + 0.17), zz + 0.05), IRON)
                geo.LEVEL = 2
                det.tube((xp, yw, zz + 0.14), (xp, yw, zz + 0.19), 0.060, 10, IRON, caps=False)
                zz += 1.55
            det.tube((xp, yw, 0.30), (xp, yw + (0.14 if sg < 0 else -0.14), 0.08), 0.050, 10, PIPE)
        geo.LEVEL = 2

    # ================================================= windows
    def sash(w, s0, s1, t0, t1, cols=3, lintel=True):
        if lintel:
            dress_window(join, w, s0, s1, t0, t1)
        o0, o1, f = 0.02, 0.10, 0.055
        w.box(join, s0, s0 + f, o0, o1, t0, t1, FRAME)
        w.box(join, s1 - f, s1, o0, o1, t0, t1, FRAME)
        w.box(join, s0 + f, s1 - f, o0, o1, t1 - f, t1, FRAME)
        w.box(join, s0 + f, s1 - f, o0, o1, t0, t0 + f, FRAME)
        mid = (t0 + t1) / 2
        w.box(join, s0 + f, s1 - f, o0, o1 - 0.015, mid - 0.03, mid + 0.03, FRAME)
        gs0, gs1, gt0, gt1 = s0 + f, s1 - f, t0 + f, t1 - f
        w.box(glass, gs0, gs1, 0.062, 0.067, gt0, gt1, GLASS, skip_back=False)
        for half in (0, 1):
            za = gt0 if half == 0 else mid + 0.03
            zb = mid - 0.03 if half == 0 else gt1
            geo.LEVEL = 1
            for i in range(1, cols):
                xg = gs0 + (gs1 - gs0) * i / cols
                w.box(join, xg - 0.010, xg + 0.010, 0.072, 0.095, za, zb, BAR)
            zh = (za + zb) / 2
            w.box(join, gs0, gs1, 0.072, 0.095, zh - 0.010, zh + 0.010, BAR)
            geo.LEVEL = 2

    for a, b, c, d in UP_FRONT:
        sash(front, a, b, c, d, cols=3)
    for a, b, c, d in UP_BACK:
        back_s0, back_s1 = -b, -a
        sash(back, back_s0, back_s1, c, d, cols=2)
    for a, b, c, d in GF_BACK:
        back_s0, back_s1 = -b, -a
        sash(back, back_s0, back_s1, c, d, cols=2)
    for a, b, c, d in SIDE_E:
        sash(east, a, b, c, d, cols=2)

    # big front window: four lights, dressed granite surround, storm queue board mounted in the opening
    a, b, c, d = BIG
    dress_window(join, front, a, b, c, d)
    o0, o1, f = 0.02, 0.10, 0.065
    front.box(join, a, a + f, o0, o1, c, d, FRAME)
    front.box(join, b - f, b, o0, o1, c, d, FRAME)
    front.box(join, a + f, b - f, o0, o1, d - f, d, FRAME)
    front.box(join, a + f, b - f, o0, o1, c, c + f, FRAME)
    mid = (c + d) / 2
    front.box(join, a + f, b - f, o0, o1 - 0.015, mid - 0.035, mid + 0.035, FRAME)
    front.box(glass, a + f, b - f, 0.062, 0.067, c + f, d - f, GLASS, skip_back=False)
    geo.LEVEL = 1
    for i in range(1, 4):
        xg = a + f + (b - a - 2 * f) * i / 4
        for za, zb in ((c + f, mid - 0.035), (mid + 0.035, d - f)):
            front.box(join, xg - 0.011, xg + 0.011, 0.072, 0.095, za, zb, BAR)
    for za, zb in ((c + f, mid - 0.035), (mid + 0.035, d - f)):
        zh = (za + zb) / 2
        front.box(join, a + f, b - f, 0.072, 0.095, zh - 0.010, zh + 0.010, BAR)
    geo.LEVEL = 2
    # storm board: 5 cm margin inside the painted frame, frame rebated over a painted backing
    bx0, bx1, bt0, bt1 = a + 0.34, b - 0.34, c + 0.20, d - 0.24
    ff = 0.055
    front.quad(det, bx0, bx1, 0.166, bt0, bt1, ("rect", *RECTS["BoardBack"], bx1 - bx0, bt1 - bt0))
    front.quad(det, bx0 + 0.05, bx1 - 0.05, 0.172, bt0 + 0.05, bt1 - 0.05,
               rect("StormBoard", bx1 - bx0 - 0.10, bt1 - bt0 - 0.10))
    for s0, s1, t0, t1 in ((bx0 - ff, bx1 + ff, bt0 - ff, bt0), (bx0 - ff, bx1 + ff, bt1, bt1 + ff),
                           (bx0 - ff, bx0, bt0, bt1), (bx1, bx1 + ff, bt0, bt1)):
        front.box(tr, s0, s1, 0.155, 0.205, t0, t1, FASCIA)

    # ================================================= door
    a, b, c, d = DOOR
    dress_door(join, front, a, b, c, d)
    stone.box((a - 0.14, Y0 - 0.28, 0.0), (b + 0.14, Y0 + 0.16, 0.09), STONE)
    stone.box((a - 0.10, Y0 - 0.19, 0.09), (b + 0.10, Y0 + 0.16, 0.16), STONE)
    o0, o1, f = 0.075, 0.155, 0.07
    front.box(join, a, a + f, o0, o1, c, d, FRAME)
    front.box(join, b - f, b, o0, o1, c, d, FRAME)
    front.box(join, a + f, b - f, o0, o1, d - f, d, FRAME)
    ls0, ls1 = a + f, b - f
    front.box(join, ls0, ls1, 0.095, 0.135, c, d - f, PANEL)
    sw = 0.105
    for s0, s1 in ((ls0, ls0 + sw), (ls1 - sw, ls1)):
        front.box(join, s0, s1, 0.135, 0.150, c, d - f, FRAME)
    for t0, t1 in ((c, c + 0.14), (1.12, 1.23), (1.82, 1.94), (d - f - 0.11, d - f)):
        front.box(join, ls0, ls1, 0.135, 0.150, t0, t1, FRAME)
    front.box(glass, ls0 + sw, ls1 - sw, 0.128, 0.133, 1.96, d - f - 0.12, GLASS, skip_back=False)
    front.box(join, (ls0 + ls1) / 2 - 0.012, (ls0 + ls1) / 2 + 0.012, 0.136, 0.155, 1.96, d - f - 0.12, BAR)
    for t0, t1 in ((0.20, 0.80), (0.92, 1.60)):
        front.box(join, ls0 + 0.16, ls1 - 0.16, 0.150, 0.156, t0, t1, PANEL)
        geo.LEVEL = 1
        for s0, s1, z0, z1 in ((ls0 + 0.16, ls0 + 0.178, t0, t1), (ls1 - 0.178, ls1 - 0.16, t0, t1),
                               (ls0 + 0.16, ls1 - 0.16, t0, t0 + 0.018), (ls0 + 0.16, ls1 - 0.16, t1 - 0.018, t1)):
            front.box(join, s0, s1, 0.155, 0.168, z0, z1, PANEL)
        geo.LEVEL = 2
    geo.LEVEL = 1
    det.box(((ls0 + ls1) / 2 + 0.28, Y0 - 0.18, 1.02), ((ls0 + ls1) / 2 + 0.36, Y0 - 0.145, 1.08), BRASS)
    det.box(((ls0 + ls1) / 2 - 0.30, Y0 - 0.165, 1.26), ((ls0 + ls1) / 2 + 0.06, Y0 - 0.145, 1.32), BRASS)
    geo.LEVEL = 2

    # brass nameplate between door and window: 1.02 x 0.36 m, big dark caps on bright brass
    nx0, nx1, nz0, nz1 = -2.79, -1.77, 1.52, 1.88
    front.box(join, nx0 - 0.04, nx1 + 0.04, 0.0, 0.03, nz0 - 0.03, nz1 + 0.03, COPE, skip_back=True)
    front.box(join, nx0, nx1, 0.03, 0.048, nz0, nz1, BRASS)
    front.quad(det, nx0, nx1, 0.049, nz0, nz1, ("rect", *RECTS["Nameplate"], nx1 - nx0, nz1 - nz0))

    # tide table board on the front pier
    tx0, tx1, tz0, tz1 = 3.28, 3.78, 1.18, 1.90
    for s0, s1, t0, t1 in ((tx0 - 0.06, tx1 + 0.06, tz0 - 0.06, tz0), (tx0 - 0.06, tx1 + 0.06, tz1, tz1 + 0.06),
                           (tx0 - 0.06, tx0, tz0, tz1), (tx1, tx1 + 0.06, tz0, tz1)):
        front.box(tr, s0, s1, -0.01, 0.042, t0, t1, FASCIA, skip_back=True)
    front.quad(det, tx0, tx1, 0.043, tz0, tz1, ("rect", *RECTS["TideBoard"], 0.5, 0.7))
    front.box(tr, tx0 - 0.10, tx1 + 0.10, -0.03, 0.10, tz1 + 0.06, tz1 + 0.12, FASCIA, skip_back=True)

    # ================================================= lifebuoy on the east wall
    lb_y, lb_z, XF = -2.55, 1.58, X1 + 0.02
    join.box((XF - 0.02, lb_y - 0.47, 1.05), (XF + 0.02, lb_y + 0.47, 2.10), PANEL, skip=("-x",))
    for yy in (lb_y - 0.39, lb_y + 0.39):
        det.box((XF + 0.02, yy - 0.02, 1.08), (XF + 0.06, yy + 0.02, 2.06), IRON)
    seg = 16
    ro, ri, th = 0.37, 0.215, 0.095
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        c0, s0 = math.cos(a0), math.sin(a0)
        c1, s1 = math.cos(a1), math.sin(a1)
        q = RED if (i // 2) % 2 == 0 else WHITE
        pf = [(XF + th, lb_y + ro * c0, lb_z + ro * s0), (XF + th, lb_y + ro * c1, lb_z + ro * s1),
              (XF + th, lb_y + ri * c1, lb_z + ri * s1), (XF + th, lb_y + ri * c0, lb_z + ri * s0)]
        pb = [(XF, lb_y + ri * c0, lb_z + ri * s0), (XF, lb_y + ri * c1, lb_z + ri * s1),
              (XF, lb_y + ro * c1, lb_z + ro * s1), (XF, lb_y + ro * c0, lb_z + ro * s0)]
        det.face(pf, q, centre=(XF - 1, lb_y, lb_z))
        det.face(pb, q, centre=(XF + 1, lb_y, lb_z))
        det.face([pf[0], pf[1], pb[1], pb[0]], q, centre=(XF + th / 2, lb_y + 2 * c0, lb_z + 2 * s0))
        det.face([pf[3], pf[2], pb[2], pb[3]], q, centre=(XF + th / 2, lb_y - 2 * c0, lb_z - 2 * s0))
    geo.LEVEL = 1
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        det.tube((XF + th / 2, lb_y + (ro + 0.045) * math.cos(a0), lb_z + (ro + 0.045) * math.sin(a0)),
                 (XF + th / 2, lb_y + (ro + 0.045) * math.cos(a1), lb_z + (ro + 0.045) * math.sin(a1)), 0.014, 4, ROPE)
    for sg in (-1, 1):
        det.tube((XF + 0.02, lb_y + sg * 0.15, lb_z + 0.34), (XF + 0.09, lb_y + sg * 0.10, lb_z + 0.30), 0.016, 4, IRON)
    geo.LEVEL = 2

    # ================================================= door lamp
    lx, lz = (a + b) / 2, 3.06
    geo.LEVEL = 1
    det.tube((lx, Y0, lz + 0.12), (lx, Y0 - 0.20, lz + 0.12), 0.016, 5, IRON)
    det.tube((lx, Y0 - 0.20, lz + 0.12), (lx, Y0 - 0.20, lz + 0.02), 0.016, 5, IRON)
    det.tube((lx, Y0 - 0.20, lz + 0.16), (lx, Y0 - 0.20, lz + 0.20), 0.085, 8, IRON)
    glass.tube((lx, Y0 - 0.20, lz - 0.10), (lx, Y0 - 0.20, lz + 0.15), 0.075, 8, GLASS)
    det.tube((lx, Y0 - 0.20, lz - 0.14), (lx, Y0 - 0.20, lz - 0.09), 0.085, 8, IRON)
    det.tube((lx, Y0 - 0.20, lz + 0.18), (lx, Y0 - 0.20, lz + 0.24), 0.025, 6, BRASS)
    geo.LEVEL = 2

    # ================================================= signal mast and weather vane
    mx, my = 3.15, 0.0
    det.box((mx - 0.16, my - 0.16, R - 0.02), (mx + 0.16, my + 0.16, R + 0.08), IRON)
    det.tube((mx, my, R), (mx, my, 9.56), 0.052, 10, WHITE)
    for zc in (8.05, 9.20):
        det.tube((mx, my, zc), (mx, my, zc + 0.06), 0.064, 10, BRASS)
    det.tube((mx - 0.56, my, 8.78), (mx + 0.56, my, 8.78), 0.022, 6, IRON)
    for sgx in (-1, 1):
        for sgy in (-1, 1):
            det.tube((mx, my, 9.05), (mx + sgx * 0.95, my + sgy * 0.75, zt(sgy * 0.75) + 0.12), 0.007, 4, IRON)
    # red signal pennant
    det.face([(mx + 0.055, my + 0.004, 8.20), (mx + 0.055, my + 0.004, 8.54), (mx + 0.62, my + 0.004, 8.28)], RED,
             centre=(mx, my - 1, 8.37))
    det.face([(mx + 0.055, my - 0.004, 8.20), (mx + 0.62, my - 0.004, 8.28), (mx + 0.055, my - 0.004, 8.54)], RED,
             centre=(mx, my + 1, 8.37))
    # weather vane
    det.tube((mx, my, 9.56), (mx, my, 9.94), 0.016, 6, BRASS)
    det.tube((mx, my, 9.92), (mx, my, 10.00), 0.052, 8, BRASS)
    det.box((mx - 0.55, my - 0.014, 9.845), (mx + 0.62, my + 0.014, 9.875), IRON)
    det.prism([(mx + 0.62, 9.78), (mx + 0.62, 9.94), (mx + 0.93, 9.86)], "y", my - 0.012, my + 0.012, IRON)
    for sg in (-1, 1):
        det.prism([(mx - 0.55, 9.72), (mx - 0.55, 10.00), (mx - 0.30, 9.86)], "y", my + sg * 0.011, my + sg * 0.013, IRON)
    det.box((mx - 0.48, my - 0.014, 9.60), (mx + 0.48, my + 0.014, 9.625), IRON)
    det.box((mx - 0.014, my - 0.44, 9.60), (mx + 0.014, my + 0.44, 9.625), IRON)

    # iron tie plates on the gable walls
    geo.LEVEL = 1
    for xw, sg in ((X0 - 0.01, -1), (X1 + 0.01, 1)):
        for yy, zz in ((0.95, 4.85), (-1.15, 6.15)):
            det.box((xw - 0.02 * sg, yy - 0.075, zz - 0.10), (xw + 0.03 * sg, yy + 0.075, zz + 0.10), IRON)
            det.box((xw - 0.02 * sg, yy - 0.022, zz - 0.14), (xw + 0.04 * sg, yy + 0.022, zz + 0.14), IRON)
    geo.LEVEL = 2

    # ================================================= LOD2 proxies (LEVEL (2,) only)
    geo.LEVEL = (2,)
    stone.box((X0, Y0, 0.0), (X1, Y0 + WALL, E), STONE)
    stone.box((X0, Y1 - WALL, 0.0), (X1, Y1, E), STONE)
    stone.box((X0, Y0, 0.0), (X0 + WALL, Y1, E), STONE)
    stone.box((X1 - WALL, Y0, 0.0), (X1, Y1, E), STONE)
    for xa, xb in ((X0, IX0), (IX1, X1)):
        stone.prism([(Y0, E), (Y1, E), (Y1, zt(Y1) + PAR), (0.0, zt(0) + PAR), (Y0, zt(Y0) + PAR)],
                    "x", xa, xb, STONE)
    stone.box((cx0, cy - 0.36, zt(cy) - 0.4), (cx1, cy + 0.36, 8.02), STONE_CH)
    slope_prism(roof, Y0 - OVH, 0.0, IX0, IX1, 0.0, SLAB, SLATE)
    slope_prism(roof, 0.0, Y1 + OVH, IX0, IX1, 0.0, SLAB, SLATE)
    join.tube((IX0, 0.0, zt(0) - 0.03), (IX1, 0.0, zt(0) - 0.03), 0.11, 6, COPE)
    join.box((DOOR[0] + 0.06, Y0, DOOR[2]), (DOOR[1] - 0.06, Y0 + 0.07, DOOR[3]), PANEL)
    front.box(join, BIG[0], BIG[1], 0.0, 0.04, BIG[2], BIG[3], FRAME)
    front.quad(glass, BIG[0] + 0.10, BIG[1] - 0.10, 0.041, BIG[2] + 0.10, BIG[3] - 0.10, GLASS)
    for a, b, c, d in UP_FRONT:
        front.box(join, a, b, 0.0, 0.04, c, d, FRAME)
        front.quad(glass, a + 0.08, b - 0.08, 0.041, c + 0.08, d - 0.08, GLASS)
    for a, b, c, d in UP_BACK:
        back.quad(glass, -b + 0.08, -a - 0.08, 0.02, c + 0.08, d - 0.08, GLASS)
    for a, b, c, d in GF_BACK:
        back.quad(glass, -b + 0.08, -a - 0.08, 0.02, c + 0.08, d - 0.08, GLASS)
    for a, b, c, d in SIDE_E:
        east.quad(glass, a + 0.08, b - 0.08, 0.02, c + 0.08, d - 0.08, GLASS)
    for sg in (-1, 1):
        ye = sg * (Y1 + OVH)
        tr.tube((IX0 + 0.04, ye + sg * 0.10, zu(Y1 + OVH) - 0.03),
                (IX1 - 0.04, ye + sg * 0.10, zu(Y1 + OVH) - 0.03), 0.065, 6, GUTTER)
        for xp in (X0 + 0.55, X1 - 0.55):
            yw = Y0 - 0.10 if sg < 0 else Y1 + 0.10
            tr.tube((xp, yw, 0.24), (xp, yw, zu(Y1 + OVH) - 0.55), 0.045, 6, PIPE)
    det.tube((mx, my, R), (mx, my, 9.94), 0.052, 6, WHITE)
    det.box((mx - 0.55, my - 0.02, 9.845), (mx + 0.93, my + 0.02, 9.875), IRON)
    for xp in (cx0 + 0.20, cx1 - 0.20):
        det.tube((xp, cy, 8.14), (xp, cy, 8.62), 0.135, 6, POTS)
    front.quad(det, -2.79, -1.77, 0.049, 1.52, 1.88, ("rect", *RECTS["Nameplate"], 1.02, 0.36))
    front.quad(det, 3.28, 3.78, 0.041, 1.18, 1.90, ("rect", *RECTS["TideBoard"], 0.5, 0.7))
    seg2 = 8
    for i in range(seg2):
        a0, a1 = 2 * math.pi * i / seg2, 2 * math.pi * (i + 1) / seg2
        q = RED if (i // 1) % 2 == 0 else WHITE
        det.face([(XF + th, lb_y + ro * math.cos(a0), lb_z + ro * math.sin(a0)),
                  (XF + th, lb_y + ro * math.cos(a1), lb_z + ro * math.sin(a1)),
                  (XF + th, lb_y + ri * math.cos(a1), lb_z + ri * math.sin(a1)),
                  (XF + th, lb_y + ri * math.cos(a0), lb_z + ri * math.sin(a0))], q, centre=(XF - 1, lb_y, lb_z))
    geo.LEVEL = 2

    # ================================================= objects, collision, attachments
    parts = [p for p in (stone, roof, tr, join, det, glass) if p.faces]
    mats = {
        "Stone": ("Granite", geo.material("MI_Harbourmaster_Stone", (0.30, 0.28, 0.24), 0.85)),
        "Roof": ("Slate", geo.material("MI_Harbourmaster_Slate", (0.08, 0.09, 0.10), 0.62)),
        "Trim": ("Sheet", geo.material("MI_Harbourmaster_Trim", (0.30, 0.29, 0.26), 0.62)),
        "Joinery": ("Details", geo.material("MI_Harbourmaster_Joinery", (0.80, 0.79, 0.75), 0.45)),
        "Details": ("Details", geo.material("MI_Harbourmaster_Details", (0.20, 0.20, 0.19), 0.55)),
        "Glass": ("Details", geo.material("MI_Harbourmaster_Glass", (0.04, 0.05, 0.055), 0.06)),
    }
    meshes, report = [], []
    for p in parts:
        s, mat = mats[p.name]
        for li, label in ((0, "LOD0"), (1, "LOD1"), (2, "LOD2")):
            if p.tris(li) == 0:
                continue
            obj = p.to_object("%s_%s_%s" % (NAME, p.name, label), mat, lod=li)
            meshes.append({"object": obj, "set": s})
        report.append("%s %d/%d/%d" % (p.name, p.tris(0), p.tris(1), p.tris(2)))
    print("[H4] tris LOD0/1/2: " + ", ".join(report))
    print("[H4] totals %d / %d / %d" % tuple(sum(p.tris(i) for p in parts) for i in range(3)))

    col = Part("COL")
    col.box((X0, Y0, 0.0), (X1, Y1, E), STONE)
    col.prism([(Y0, E), (Y1, E), (Y1, R), (Y0, R)], "x", X0, X1, STONE)
    col.box((cx0, cy - 0.36, zt(cy) - 0.4), (cx1, cy + 0.36, 8.2), STONE)
    colobj = col.to_object(NAME + "_COL", None, weld=False)

    att = {
        "ATT_Door": ((DOOR[0] + DOOR[1]) / 2, Y0 - 0.85, 1.20),
        "ATT_StormQueueBoard": ((BIG[0] + BIG[1]) / 2, Y0 - 0.55, 1.70),
        "ATT_Nameplate": (-2.28, Y0 - 0.22, 1.70),
        "ATT_TideBoard": (3.53, Y0 - 0.25, 1.55),
        "ATT_Lifebuoy": (X1 + 0.32, -2.55, 1.58),
        "ATT_SignalMast": (mx, my, 9.30),
        "ATT_WeatherVane": (mx, my, 9.86),
        "ATT_Lamp_Door": ((DOOR[0] + DOOR[1]) / 2, Y0 - 0.32, 3.02),
    }
    att_objs = []
    for n, p in att.items():
        e = bpy.data.objects.new(n, None)
        e.location = (p[0] * 3, p[1] * 3, p[2] * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)

    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 15000,
        "tier": "standard",
        "dims_m": (10.0, 8.0, None),
        "size_note": "depth adds the projecting sills, the two eaves gutters and the lifebuoy bracket (0.9 m); height is free with the signal mast",
        "origin": "base",
        "tiling": True,
        "waivers": {
            "LOD UV layout": "world-scale tiling UVs and one details atlas; hand-made LODs drop small parts, so the UV "
                             "bounds change; no baked layout to keep",
        },
        "sets": [
            {"name": "Harbourmaster", "set": "Details", "size": 1024, "wet": True, "dir": TEXDIR},
            {"name": "Harbourmaster", "set": "Granite", "size": 2048, "wet": True, "dir": TEXDIR},
            {"name": "Chandlery", "set": "Slate", "size": 1024, "wet": True, "dir": G + "assets/textures/M_Bld_Chandlery_Ext"},
            {"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": True, "dir": G + "assets/textures/M_Bld_TrimSheet"},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "nameplate", "target": (-2.28 * 3, Y0 * 3, 1.70 * 3), "dist": 9.5, "az": 4, "el": 2},
            {"name": "door", "target": ((DOOR[0] + DOOR[1]) / 2 * 3, Y0 * 3, 1.55 * 3), "dist": 7.5, "az": -6, "el": 3},
            {"name": "storm_queue_board", "target": ((BIG[0] + BIG[1]) / 2 * 3, Y0 * 3, 1.75 * 3), "dist": 15.5, "az": -12, "el": 3},
            {"name": "tide_board_lifebuoy", "target": (3.7 * 3, Y0 * 3, 1.6 * 3), "dist": 8.0, "az": 6, "el": 3},
            {"name": "roof_chimney_mast", "target": (0.4, 0.6, 7.9 * 3), "dist": 34.0, "az": -32, "el": 20},
            {"name": "granite_quoins", "target": (X1 * 3, Y0 * 3, 1.3 * 3), "dist": 8.0, "az": 26, "el": 6},
            {"name": "sash_upper", "target": (1.5 * 3, Y0 * 3, 4.1 * 3), "dist": 8.0, "az": 10, "el": 4},
        ],
    }
