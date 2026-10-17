"""H2 M_Bld_Chandlery_Ext: the Port Haven Chandlery shell (docs/12 H2 row, 05 section 2 buildings, 10 section 1.2).

Two-storey granite harbour-front shop on the quay: dressed QuayStone ashlar walls 0.55 m thick with real reveals, darker
granite quoins, plinth, kneelers, step and lintels; a projecting timber shopfront (pilasters with console brackets, panelled
stall riser, deep six-light bay with glazing bars, fascia lettered PORT HAVEN CHANDLERY, cornice with a lead top); a
half-glazed panelled door with a fanlight (own MeshPart, hinged at x -8.0, ATT_DoorHinge; its glass is DoorGlass, weld it
to the door); a double-sided hanging sign on a wrought-iron bracket; an A-frame chalk board; three 6-over-6 loft sashes
with drip stains under the sills; slate roof with ridge tiles, gable parapets with copings, a west-gable chimney with two
pots, a cast-iron rooflight on the back slope, cast gutters, downpipes with brackets. All fixed glass is the Glass MeshPart
(Studio makes it transparent). The interior (M_Bld_Chandlery_Int) is not here: the shell is hollow, inner faces plain.

Frame: layout.py (shared with Int / Props, metres, x3 = studs), origin = frame origin (spec origin "free": the shopfront,
A-board and gutters push the bbox off the wall-footprint centre, and the three assets must share one pivot).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_Chandlery_Ext --steps build,validate,export,turntable
(no lod step: LOD1 / LOD2 are hand-made from geo levels, as H1)
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import geo  # noqa: E402
import layout as L  # noqa: E402
from geo import Part, trim  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Chandlery_Ext"
D = {  # Details atlas rects (maketex.DETAILS)
    "FasciaL": (0.0, 0.90, 1.0, 1.0), "FasciaR": (0.0, 0.80, 1.0, 0.90), "Door": (0.0, 0.36, 0.30, 0.62),
    "Sign": (0.30, 0.36, 0.70, 0.62), "Chalk": (0.70, 0.22, 1.0, 0.62), "Glass": (0.0, 0.22, 0.30, 0.36),
    "Brass": (0.30, 0.22, 0.45, 0.36), "Pots": (0.45, 0.22, 0.70, 0.36), "Stain": (0.0, 0.0, 0.25, 0.22)}
STRIP = {"Paint": (0.74, 0.80), "Iron": (0.68, 0.74), "Lead": (0.62, 0.68)}


def rect(name, w, h, pad=0.003):
    u0, v0, u1, v1 = D[name]
    return ("rect", u0 + pad, v0 + pad, u1 - pad, v1 - pad, w, h)


def strip(name, metres=1.0):
    v0, v1 = STRIP[name]
    return ("trim", v0 + 0.004, v1 - 0.004, metres)


STONE = ("tile", 2.0)
SLATE = ("tile", 2.0)
PAINT = strip("Paint", 2.0)
IRON = strip("Iron", 1.0)
LEAD = strip("Lead", 2.0)
GLASS = rect("Glass", 2.1, 2.1)
BRASS = rect("Brass", 0.5, 0.5)

X0, X1, Y0, Y1 = L.X0, L.X1, L.Y0, L.Y1
IX0, IX1, IY0, IY1 = L.IX0, L.IX1, L.IY0, L.IY1
E, R = L.EAVES, L.RIDGE
S = (R - E) / Y1                 # roof pitch (rise per m run), underside plane through the wall plate
SLAB = 0.16                      # slate + battens + sarking, vertical
OVH = 0.28                       # eaves overhang
PAR = 0.2                        # gable parapet above the slates


def zu(y):
    """Roof underside height at y."""
    return E + (Y1 - abs(y)) * S


def zt(y):
    return zu(y) + SLAB


def holed_wall(part, axis, w_out, w_in, s0, s1, t0, t1, holes, mode, ends=(True, True), top=True):
    """Solid wall between w_out (outer face) and w_in on the wall axis ('y' front / back, 'x' sides), s along, t up,
    with rectangular holes (s0, s1, t0, t1) through it: a conforming grid of face cells (no T-junctions) plus reveals."""
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
                part.face([P(a, w, c), P(b, w, c), P(b, w, d), P(a, w, d)], mode, centre=P((a + b) / 2, wm, (c + d) / 2))
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


def slope_prism(part, y0, y1, x0, x1, dz0, dz1, mode, caps=True):
    """A slab lying on the roof slope between horizontal y0..y1 (same side of the ridge), dz0..dz1 above the underside."""
    prof = [(y0, zu(y0) + dz0), (y1, zu(y1) + dz0), (y1, zu(y1) + dz1), (y0, zu(y0) + dz1)]
    part.prism(prof, "x", x0, x1, mode, caps=caps)


def frustum(part, c, r_top, r_bot, z_top, z_bot, segs, mode):
    """Open-bottomed lamp shade: a cone frustum around vertical axis at c = (x, y), closed at the top."""
    part.prim += 1
    ring = lambda r, z: [(c[0] + r * math.cos(2 * math.pi * i / segs), c[1] + r * math.sin(2 * math.pi * i / segs), z) for i in range(segs)]
    top, bot = ring(r_top, z_top), ring(r_bot, z_bot)
    cen = (c[0], c[1], (z_top + z_bot) / 2)
    for i in range(segs):
        j = (i + 1) % segs
        q = [bot[i], bot[j], top[j], top[i]]
        part.face(q, mode, centre=cen)
        part.face(list(reversed(q)), mode, centre=(c[0] + 50 * (bot[i][0] + bot[j][0] - 2 * c[0]), c[1] + 50 * (bot[i][1] + bot[j][1] - 2 * c[1]), cen[2]))
    part.face(top, mode, centre=(c[0], c[1], z_top - 1))


def build():
    stone, gran, roof, tr, det, shop, glass, door, dglass = (Part("Stone"), Part("Granite"), Part("Roof"), Part("Trim"),
                                                            Part("Details"), Part("Shopfront"), Part("Glass"), Part("Door"),
                                                            Part("DoorGlass"))
    atts = {}

    def gbox(lo, hi):          # thin glass slab (both sides render)
        glass.box(lo, hi, GLASS)

    # ================================================= walls (QuayStone ashlar, 0.55 m, real reveals)
    geo.LEVEL = 3
    DS = L.DOOR_STONE_OPENING
    holes_front = [(DS[0], DS[1], DS[2], DS[3]), (L.BAY_OPENING[0], L.BAY_OPENING[1], 0.0, L.BAY_OPENING[3])]
    holes_front += [(a, b, L.LOFT_WIN_Z[0], L.LOFT_WIN_Z[1]) for a, b in L.LOFT_WINDOWS]
    holed_wall(stone, "y", Y0, IY0, X0, X1, 0.0, E, holes_front, STONE, top=False)
    holed_wall(stone, "y", Y1, IY1, X0, X1, 0.0, E, [], STONE, top=False)
    holed_wall(stone, "x", X0, IX0, IY0, IY1, 0.0, E, [], STONE, ends=(False, False), top=False)
    holed_wall(stone, "x", X1, IX1, IY0, IY1, 0.0, E, [], STONE, ends=(False, False), top=False)
    for yo, yi in ((Y0, IY0), (Y1, IY1)):        # wall heads up to the roof underside
        stone.prism([(yo, E), (yi, E), (yi, zu(yi))], "x", IX0, IX1, STONE)
    for x0, x1 in ((X0, IX0), (IX1, X1)):        # gables with parapets
        stone.prism([(Y0, E), (Y1, E), (Y1, zt(Y1) + PAR), (0.0, zt(0) + PAR), (Y0, zt(Y0) + PAR)], "x", x0, x1, STONE)

    # granite plinth (sloped weathering top), quoins, kneelers, gable copings
    geo.LEVEL = 3
    pl = [(Y0, 0.0), (Y0 - 0.06, 0.0), (Y0 - 0.06, 0.4), (Y0, 0.46)]
    for x0, x1 in ((X0 - 0.06, DS[0] - 0.2), (DS[1] + 0.2, -5.0), (8.4, X1 + 0.06)):
        gran.prism(pl, "x", x0, x1, STONE)
    gran.prism([(Y1, 0.0), (Y1 + 0.06, 0.0), (Y1 + 0.06, 0.4), (Y1, 0.46)], "x", X0 - 0.06, X1 + 0.06, STONE)
    for xw, sg in ((X0, -1), (X1, 1)):
        gran.prism([(xw, 0.0), (xw + 0.06 * sg, 0.0), (xw + 0.06 * sg, 0.4), (xw, 0.46)], "y", Y0, Y1, STONE)
    geo.LEVEL = 2
    z, k = 0.46, 0
    while z < E - 0.35:
        for xc, sx in ((X0, 1), (X1, -1)):
            for yc, sy in ((Y0, 1), (Y1, -1)):
                lx, ly = (0.62, 0.32) if k % 2 == 0 else (0.32, 0.62)
                xa, xb = sorted((xc - 0.03 * sx, xc + lx * sx))
                ya, yb = sorted((yc - 0.03 * sy, yc + ly * sy))
                gran.box((xa, ya, z + 0.012), (xb, yb, z + 0.318), STONE)
        z += 0.33
        k += 1
    for xa, xb in ((X0 - 0.05, IX0 + 0.06), (IX1 - 0.06, X1 + 0.05)):
        for ya, yb in ((Y0 - OVH - 0.04, Y0 + 0.55), (Y1 - 0.55, Y1 + OVH + 0.04)):
            gran.box((xa, ya, E - 0.32), (xb, yb, zt(Y0) + PAR + 0.12), STONE)
    for xa, xb in ((X0 - 0.06, IX0 + 0.06), (IX1 - 0.06, X1 + 0.06)):
        for ya, yb in ((Y0 + 0.5, 0.0), (0.0, Y1 - 0.5)):
            prof = [(ya, zt(ya) + PAR), (yb, zt(yb) + PAR), (yb, zt(yb) + PAR + 0.12), (ya, zt(ya) + PAR + 0.12)]
            tr.prism(prof, "x", xa, xb, trim("Coping"))
    geo.LEVEL = (2,)                              # LOD2 stand-in for the quoins: one proud strip per corner face
    for xc, sx in ((X0, 1), (X1, -1)):
        for yc, sy in ((Y0, 1), (Y1, -1)):
            xa, xb = sorted((xc - 0.03 * sx, xc + 0.47 * sx))
            ya, yb = sorted((yc - 0.03 * sy, yc + 0.47 * sy))
            gran.box((xa, ya, 0.46), (xb, yb, E - 0.32), STONE, skip=("-z", "+z"))

    # ================================================= chimney (west gable): stack, oversail, cap, two pots
    geo.LEVEL = 3
    cx0, cx1, cy = -10.05, -9.15, 0.5
    stone.box((cx0, -cy, zt(cy) - 0.2), (cx1, cy, 10.05), STONE, skip=("-z",))
    gran.box((cx0 - 0.06, -cy - 0.06, 10.05), (cx1 + 0.06, cy + 0.06, 10.16), STONE)
    tr.box((cx0 - 0.02, -cy - 0.02, 10.16), (cx1 + 0.02, cy + 0.02, 10.24), trim("Coping"))
    geo.LEVEL = 2
    for yp in (-0.22, 0.22):
        det.tube((-9.6, yp, 10.24), (-9.6, yp, 10.7), 0.12, 10, rect("Pots", 0.8, 0.46))
        det.tube((-9.6, yp, 10.24), (-9.6, yp, 10.32), 0.15, 10, rect("Pots", 0.8, 0.46))
        geo.LEVEL = 1
        det.tube((-9.6, yp, 10.62), (-9.6, yp, 10.7), 0.14, 10, rect("Pots", 0.8, 0.46))
        geo.LEVEL = 2
    for yy0, yy1 in ((-cy - 0.04, 0.0), (0.0, cy + 0.04)):     # lead apron where the slates meet the stack
        slope_prism(det, yy0, yy1, cx1, cx1 + 0.12, SLAB + 0.0, SLAB + 0.05, LEAD)

    # ================================================= roof: slate slopes (skylight hole on the back), ridge tiles
    geo.LEVEL = 3
    slope_prism(roof, Y0 - OVH, 0.0, IX0, IX1, 0.0, SLAB, SLATE)
    (sy0, _), (sy1, _) = L.SKYLIGHT_YZ           # low edge y 4.286, high edge y 3.422
    sk0, sk1 = L.SKYLIGHT[0], L.SKYLIGHT[1]
    slope_prism(roof, 0.0, Y1 + OVH, IX0, sk0, 0.0, SLAB, SLATE)
    slope_prism(roof, 0.0, Y1 + OVH, sk1, IX1, 0.0, SLAB, SLATE)
    slope_prism(roof, 0.0, sy1, sk0, sk1, 0.0, SLAB, SLATE)
    slope_prism(roof, sy0, Y1 + OVH, sk0, sk1, 0.0, SLAB, SLATE)
    geo.LEVEL = 2
    x = IX0
    while x < IX1 - 0.05:
        xb = min(x + 0.6, IX1)
        tr.tube((x, 0.0, zt(0) - 0.03), (xb, 0.0, zt(0) - 0.03), 0.13, 8, trim("Coping"))
        x = xb - 0.0
    geo.LEVEL = (2,)
    tr.prism([(-0.16, zt(0.16)), (0.16, zt(0.16)), (0.0, zt(0) + 0.1)], "x", IX0, IX1, trim("Coping"))
    # rooflight: cast-iron kerb, glass, glazing bar, lead apron
    geo.LEVEL = 3
    kerb = [(sy1 - 0.05, sk0 - 0.06, sk0), (sy1 - 0.05, sk1, sk1 + 0.06)]
    for ya, xa, xb in kerb:
        slope_prism(det, sy1 - 0.05, sy0 + 0.05, xa, xb, SLAB - 0.04, SLAB + 0.1, IRON)
    slope_prism(det, sy0, sy0 + 0.05, sk0, sk1, SLAB - 0.04, SLAB + 0.1, IRON)
    slope_prism(det, sy1 - 0.05, sy1, sk0, sk1, SLAB - 0.04, SLAB + 0.12, IRON)
    slope_prism(glass, sy1, sy0, sk0, sk1, SLAB + 0.06, SLAB + 0.066, GLASS)
    geo.LEVEL = 2
    slope_prism(det, sy1, sy0, (sk0 + sk1) / 2 - 0.02, (sk0 + sk1) / 2 + 0.02, SLAB + 0.03, SLAB + 0.1, IRON)
    slope_prism(det, sy0 + 0.05, sy0 + 0.32, sk0 - 0.12, sk1 + 0.12, SLAB + 0.0, SLAB + 0.025, LEAD)

    # ================================================= eaves: fascia, soffit, cast gutters, downpipes with brackets
    zo = zu(Y1 + OVH)
    for sg in (-1, 1):
        ye = sg * (Y1 + OVH)
        geo.LEVEL = 3
        tr.box((IX0 + 0.06, min(ye, ye + sg * 0.03), zo - 0.2), (IX1 - 0.06, max(ye, ye + sg * 0.03), zo + 0.06), trim("Fascia"))
        geo.LEVEL = 2
        tr.box((IX0 + 0.06, min(ye, sg * Y1), zo - 0.06), (IX1 - 0.06, max(ye, sg * Y1), zo - 0.03), trim("Fascia"))
        yg, r = ye + sg * 0.11, 0.075
        prof = [(yg - r, zo - 0.04), (yg + r, zo - 0.04), (yg + r * 0.7, zo - 0.04 - r * 0.7), (yg, zo - 0.04 - r),
                (yg - r * 0.7, zo - 0.04 - r * 0.7)]
        tr.prism(prof, "x", IX0 + 0.06, IX1 - 0.06, trim("Gutter"))
        geo.LEVEL = 1
        xb = IX0 + 0.2
        while xb < IX1 - 0.1:
            det.box((xb - 0.015, min(ye, yg + sg * r), zo - 0.06), (xb + 0.015, max(ye, yg + sg * r), zo - 0.04), IRON)
            xb += 0.9
        yw = sg * (Y1 + 0.11)
        for xp in (X0 + 0.8, X1 - 0.8):
            geo.LEVEL = 3
            tr.tube((xp, yw, 0.2), (xp, yw, zo - 0.55), 0.045, 8, trim("Downpipe"))
            geo.LEVEL = 2
            tr.tube((xp, yg, zo - 0.1), (xp, yw, zo - 0.55), 0.045, 8, trim("Downpipe"), caps=False)
            tr.tube((xp, yw + sg * 0.08, 0.02), (xp, yw, 0.24), 0.052, 8, trim("Downpipe"))
            geo.LEVEL = 1
            zz = 0.9
            while zz < zo - 0.8:
                det.box((xp - 0.065, min(yw - sg * 0.065, sg * Y1), zz), (xp + 0.065, max(yw - sg * 0.065, sg * Y1), zz + 0.05), IRON)
                det.box((xp - 0.058, yw - 0.058, zz), (xp + 0.058, yw + 0.058, zz + 0.05), IRON)
                zz += 1.5
    geo.LEVEL = 3

    # ================================================= loft sashes (6 over 6), granite lintels and sills, drip stains
    yA = Y0 + 0.08                        # frame outer face, set back in the reveal
    for wi, (a, b) in enumerate(L.LOFT_WINDOWS):
        z0, z1 = L.LOFT_WIN_Z
        geo.LEVEL = 3
        gran.box((a - 0.16, Y0 - 0.03, z1), (b + 0.16, Y0, z1 + 0.3), STONE, skip=("+y",))
        tr.box((a - 0.1, Y0 - 0.08, z0 - 0.08), (b + 0.1, Y0 + 0.14, z0 + 0.03), trim("Sill"))
        f = 0.07
        for xa, xb, za, zb in ((a, a + f, z0 + 0.03, z1), (b - f, b, z0 + 0.03, z1), (a + f, b - f, z1 - f, z1)):
            tr.box((xa, yA, za), (xb, yA + 0.12, zb), trim("WindowFrame"))
        mid = (z0 + 0.03 + z1 - f) / 2
        geo.LEVEL = 2
        for (ya, yb, sz0, sz1) in ((yA + 0.01, yA + 0.05, mid - 0.02, z1 - f), (yA + 0.06, yA + 0.1, z0 + 0.03, mid + 0.02)):
            sw = 0.05
            for xa, xb, za, zb in ((a + f, a + f + sw, sz0, sz1), (b - f - sw, b - f, sz0, sz1),
                                   (a + f + sw, b - f - sw, sz1 - sw, sz1), (a + f + sw, b - f - sw, sz0, sz0 + (0.09 if sz0 < mid - 0.1 else 0.04))):
                tr.box((xa, ya, za), (xb, yb, zb), trim("WindowFrame"))
            geo.LEVEL = 1
            ga, gb = a + f + sw, b - f - sw
            for q in (1, 2):
                xg = ga + (gb - ga) * q / 3
                tr.box((xg - 0.012, ya + 0.005, sz0), (xg + 0.012, yb - 0.005, sz1), trim("GlazingBar"))
            zg = (sz0 + sz1) / 2
            tr.box((ga, ya + 0.005, zg - 0.012), (gb, yb - 0.005, zg + 0.012), trim("GlazingBar"))
            geo.LEVEL = 3
            gbox((ga, (ya + yb) / 2 - 0.003, sz0), (gb, (ya + yb) / 2 + 0.003, sz1))
            geo.LEVEL = 2
        # drip stains under the sill (only where there is wall below: the cornice runs under windows 2 and 3)
        geo.LEVEL = 1
        if b < -5.1:
            rs = [(a - 0.02, 0.07, 0.62), (a + 0.28, 0.05, 0.4), (a + 0.55, 0.09, 0.78), (b - 0.3, 0.05, 0.5), (b - 0.02, 0.07, 0.66)]
        else:
            rs = []
        for xc, w, ln in rs:
            zt0 = z0 - 0.08
            det.face([(xc - w / 2, Y0 - 0.012, zt0), (xc + w / 2, Y0 - 0.012, zt0), (xc + w * 0.1, Y0 - 0.012, zt0 - ln),
                      (xc - w * 0.1, Y0 - 0.012, zt0 - ln)], rect("Stain", 0.1, 0.8), centre=(xc, 0.0, zt0 - ln / 2))
    geo.LEVEL = 3

    # ================================================= door: linings, case, transom + fanlight, granite step, threshold
    dx0, dx1 = L.DOOR[0], L.DOOR[1]
    leaf_z0, leaf_z1 = L.DOOR_LEAF[2], L.DOOR_LEAF[3]
    ly0, ly1 = L.DOOR_LEAF[4], L.DOOR_LEAF[5]
    top = L.DOOR[3]
    gran.box((DS[0] - 0.25, Y0 - 0.38, 0.0), (DS[1] + 0.25, Y0, L.FLOOR), STONE, skip=("-z",))
    gran.box((DS[0], Y0, 0.0), (DS[1], IY0, L.FLOOR), STONE, skip=("-z", "-y"))
    for xa, xb in ((DS[0], dx0), (dx1, DS[1])):
        shop.box((xa, Y0, L.FLOOR), (xb, IY0, DS[3]), PAINT)
    shop.box((dx0, Y0, top), (dx1, IY0, DS[3]), PAINT)
    shop.box((dx0, ly0 - 0.05, leaf_z1), (dx1, ly1 + 0.05, leaf_z1 + 0.06), PAINT)        # transom
    gbox((dx0, -5.83, leaf_z1 + 0.06), (dx1, -5.824, top))                                # fanlight
    geo.LEVEL = 2
    for q in (1, 2, 3):
        xg = dx0 + (dx1 - dx0) * q / 4
        shop.box((xg - 0.012, -5.85, leaf_z1 + 0.06), (xg + 0.012, -5.80, top), PAINT)
    geo.LEVEL = 3
    for xa, xb in ((DS[0] - 0.2, DS[0]), (DS[1], DS[1] + 0.2)):                          # door case
        shop.box((xa, Y0 - 0.05, L.FLOOR), (xb, Y0, DS[3] + 0.12), PAINT, skip=("+y",))
    shop.box((DS[0], Y0 - 0.05, DS[3]), (DS[1], Y0, DS[3] + 0.12), PAINT, skip=("+y",))
    shop.box((DS[0] - 0.28, Y0 - 0.14, DS[3] + 0.12), (DS[1] + 0.28, Y0, DS[3] + 0.24), PAINT, skip=("+y",))
    geo.LEVEL = 2
    shop.prism([(Y0 - 0.14, DS[3] + 0.24), (Y0, DS[3] + 0.24), (Y0, DS[3] + 0.32)], "x", DS[0] - 0.28, DS[1] + 0.28, LEAD)
    geo.LEVEL = 3

    # door leaf (own MeshPart, hinge x -8.0 on the inner face, swings in)
    door.box((dx0, ly0, leaf_z0), (dx1, ly1, leaf_z0 + 0.98), rect("Door", 1.2, 0.98))
    for xa, xb in ((dx0, dx0 + 0.12), (dx1 - 0.12, dx1)):
        door.box((xa, ly0, leaf_z0 + 0.98), (xb, ly1, leaf_z1), PAINT)
    door.box((dx0 + 0.12, ly0, leaf_z1 - 0.12), (dx1 - 0.12, ly1, leaf_z1), PAINT)
    geo.LEVEL = 2
    door.box((dx0 + 0.12, ly0 - 0.01, leaf_z0 + 0.98), (dx1 - 0.12, ly0 + 0.012, leaf_z0 + 1.02), PAINT)   # glazing bead
    gx0, gx1, gz0, gz1 = dx0 + 0.12, dx1 - 0.12, leaf_z0 + 0.98, leaf_z1 - 0.12
    door.box(((gx0 + gx1) / 2 - 0.013, ly0 + 0.005, gz0), ((gx0 + gx1) / 2 + 0.013, ly1 - 0.005, gz1), PAINT)
    for q in (1, 2):
        zg = gz0 + (gz1 - gz0) * q / 3
        door.box((gx0, ly0 + 0.005, zg - 0.013), (gx1, ly1 - 0.005, zg + 0.013), PAINT)
    geo.LEVEL = 3
    dglass.box((gx0, (ly0 + ly1) / 2 - 0.003, gz0), (gx1, (ly0 + ly1) / 2 + 0.003, gz1), GLASS)
    geo.LEVEL = 1
    door.tube((dx1 - 0.09, ly0, leaf_z0 + 0.9), (dx1 - 0.09, ly0 - 0.07, leaf_z0 + 0.9), 0.028, 10, BRASS)    # knob
    door.tube((dx1 - 0.09, ly0, leaf_z0 + 0.9), (dx1 - 0.09, ly0 - 0.012, leaf_z0 + 0.9), 0.04, 10, BRASS)    # rose
    door.box((dx1 - 0.105, ly0 - 0.008, leaf_z0 + 0.78), (dx1 - 0.075, ly0, leaf_z0 + 0.82), BRASS)          # keyhole plate
    door.box((dx0 + 0.42, ly0 - 0.01, leaf_z0 + 0.88), (dx1 - 0.42, ly0, leaf_z0 + 0.94), BRASS)            # letter plate
    door.box((dx0 + 0.04, ly0 - 0.008, leaf_z0 + 0.02), (dx1 - 0.04, ly0, leaf_z0 + 0.22), BRASS)           # kick plate
    geo.LEVEL = 3
    atts["ATT_Door"] = Vector(L.ATT["ATT_Door"])
    atts["ATT_DoorHinge"] = Vector(L.DOOR_HINGE)

    # ================================================= shopfront: pilasters, consoles, riser, bay, fascia, cornice
    bx0, bx1 = L.BAY[0], L.BAY[1]
    sill, head = L.BAY[2], L.BAY[3]
    yF = Y0 - L.BAY_DEPTH                  # -6.6 front of the glazing frame
    for p0, p1 in L.SHOPFRONT_PILASTERS:
        gran.box((p0 - 0.04, yF - 0.17, 0.0), (p1 + 0.04, Y0, 0.12), STONE, skip=("-z", "+y"))
        shop.box((p0 - 0.03, yF - 0.13, 0.12), (p1 + 0.03, Y0, 0.42), PAINT, skip=("-z", "+y"))
        shop.box((p0, yF - 0.1, 0.42), (p1, Y0, 2.8), PAINT, skip=("-z", "+y"))
        shop.box((p0 - 0.03, yF - 0.13, 2.8), (p1 + 0.03, Y0, 3.0), PAINT, skip=("+y",))
        shop.prism([(Y0, 3.0), (Y0, 3.78), (yF - 0.26, 3.78), (yF - 0.26, 3.6), (yF - 0.14, 3.05), (yF - 0.1, 3.0)],
                   "x", p0 + 0.01, p1 - 0.01, PAINT)
        geo.LEVEL = 1
        for xs in (p0 + 0.07, p1 - 0.1):
            shop.box((xs, yF - 0.12, 0.55), (xs + 0.03, yF - 0.1, 2.68), PAINT, skip=("+y",))
        shop.tube((p0 + 0.03, yF - 0.2, 3.62), (p1 - 0.03, yF - 0.2, 3.62), 0.07, 10, PAINT)
        shop.tube((p0 + 0.05, yF - 0.13, 3.1), (p1 - 0.05, yF - 0.13, 3.1), 0.05, 8, PAINT)
        shop.box(((p0 + p1) / 2 - 0.06, yF - 0.17, 2.94), ((p0 + p1) / 2 + 0.06, yF - 0.1, 3.0), PAINT)
        geo.LEVEL = 3
    # stall riser on a granite base, raised panels, sloped stall board
    gran.box((bx0, yF - 0.06, 0.0), (bx1, yF + 0.1, 0.12), STONE, skip=("-z",))
    shop.box((bx0, yF - 0.02, 0.12), (bx1, yF + 0.08, sill - 0.07), PAINT)
    shop.prism([(yF - 0.12, sill - 0.07), (yF + 0.1, sill - 0.07), (yF + 0.1, sill), (yF - 0.12, sill - 0.035)], "x", bx0, bx1, PAINT)
    posts = [bx0 + (bx1 - bx0) * i / 6 for i in range(7)]
    geo.LEVEL = 2
    for pa, pb in zip(posts, posts[1:]):
        shop.box((pa + 0.14, yF - 0.045, 0.24), (pb - 0.14, yF - 0.02, sill - 0.17), PAINT, skip=("+y",))
    geo.LEVEL = 3
    # display bed (bay floor) to the inner wall face
    tr.box((bx0, yF + 0.08, 0.0), (bx1, IY0, L.FLOOR), trim("DoorPanel", 1.0), skip=("-z",))
    # glazing: bottom rail, mullions, head rail, glazing bars, glass
    shop.box((bx0, yF - 0.02, sill), (bx1, yF + 0.1, sill + 0.08), PAINT)
    shop.box((bx0, yF - 0.02, head - 0.1), (bx1, yF + 0.1, head), PAINT)
    for xp in posts[1:-1]:
        shop.box((xp - 0.045, yF - 0.03, sill + 0.08), (xp + 0.045, yF + 0.1, head - 0.1), PAINT)
    for i, (pa, pb) in enumerate(zip(posts, posts[1:])):
        ga = pa + (0.0 if i == 0 else 0.045)
        gb = pb - (0.0 if i == 5 else 0.045)
        gbox((ga, yF + 0.03, sill + 0.08), (gb, yF + 0.036, head - 0.1))
        geo.LEVEL = 2
        for q in (1, 2):
            xg = ga + (gb - ga) * q / 3
            shop.box((xg - 0.015, yF + 0.0, sill + 0.08), (xg + 0.015, yF + 0.06, head - 0.1), PAINT)
            zg = sill + 0.08 + (head - 0.18 - sill) * q / 3
            shop.box((ga, yF + 0.0, zg - 0.015), (gb, yF + 0.06, zg + 0.015), PAINT)
        geo.LEVEL = 3
    # head, frieze, fascia (two lettered halves), mouldings, cornice with lead top
    shop.box((bx0, yF, head), (bx1, Y0, 3.78), PAINT, skip=("+y",))
    xm = (bx0 + bx1) / 2
    fy0, fy1 = yF - 0.08, yF - 0.02
    shop.box((bx0, fy0, L.FASCIA[2]), (xm, fy1, L.FASCIA[3]), rect("FasciaL", xm - bx0, L.FASCIA[3] - L.FASCIA[2]), skip=("+y",))
    shop.box((xm, fy0, L.FASCIA[2]), (bx1, fy1, L.FASCIA[3]), rect("FasciaR", bx1 - xm, L.FASCIA[3] - L.FASCIA[2]), skip=("+y",))
    shop.box((bx0, fy0 - 0.03, L.FASCIA[2] - 0.05), (bx1, fy1, L.FASCIA[2]), PAINT, skip=("+y",))
    shop.box((bx0, fy0 - 0.05, L.FASCIA[3]), (bx1, fy1, L.FASCIA[3] + 0.06), PAINT, skip=("+y",))
    c0, c1 = L.FASCIA[0] - 0.08, L.FASCIA[1] + 0.08
    shop.box((c0, yF - 0.34, 3.71), (c1, Y0, 3.8), PAINT, skip=("+y",))
    shop.prism([(yF - 0.36, 3.8), (Y0, 3.8), (Y0, 3.88), (yF - 0.36, 3.815)], "x", c0 - 0.02, c1 + 0.02, LEAD)

    # ================================================= hanging sign on a wrought-iron bracket (double-sided)
    geo.LEVEL = 3
    sx, sy, sz = L.SIGN
    det.box((sx - 0.03, sy - 0.45, sz - 0.3), (sx + 0.03, sy + 0.45, sz + 0.3), rect("Sign", 0.9, 0.6))
    for (ya, yb, za, zb) in ((sy - 0.47, sy + 0.47, sz + 0.28, sz + 0.32), (sy - 0.47, sy + 0.47, sz - 0.32, sz - 0.28),
                             (sy - 0.47, sy - 0.43, sz - 0.28, sz + 0.28), (sy + 0.43, sy + 0.47, sz - 0.28, sz + 0.28)):
        det.box((sx - 0.04, ya, za), (sx + 0.04, yb, zb), PAINT)
    bar_z = sz + 0.38
    det.box((sx - 0.05, Y0 - 0.02, sz + 0.3), (sx + 0.05, Y0, 3.88), IRON, skip=("+y",))
    det.box((sx - 0.016, sy - 0.53, bar_z - 0.016), (sx + 0.016, Y0 - 0.02, bar_z + 0.016), IRON)
    geo.LEVEL = 2
    det.tube((sx, Y0 - 0.02, 3.82), (sx, sy - 0.3, bar_z + 0.01), 0.014, 4, IRON)
    det.tube((sx, sy - 0.56, bar_z), (sx, sy - 0.5, bar_z), 0.03, 8, IRON)
    for yh in (sy - 0.35, sy + 0.35):
        det.tube((sx, yh, bar_z - 0.016), (sx, yh, sz + 0.32), 0.008, 4, IRON)
    geo.LEVEL = 1
    ccy, ccz, rr = Y0 - 0.32, bar_z + 0.136, 0.12          # scroll between bar and brace
    pts = [(ccy + rr * math.cos(2 * math.pi * i / 10), ccz + rr * math.sin(2 * math.pi * i / 10)) for i in range(10)]
    for i in range(10):
        p, q = pts[i], pts[(i + 1) % 10]
        det.tube((sx, p[0], p[1]), (sx, q[0], q[1]), 0.009, 4, IRON, caps=False)
    for zb in (sz + 0.42, 3.78):
        det.tube((sx, Y0 - 0.02, zb), (sx, Y0 - 0.04, zb), 0.018, 6, IRON)                  # bolt heads
    geo.LEVEL = 3
    atts["ATT_Sign"] = Vector(L.ATT["ATT_Sign"])

    # ================================================= A-frame chalk board on the quay
    ax0, ax1, ayc, top_z = -3.62, -2.98, -6.95, 0.95
    for sg in (-1, 1):
        yb, yt = ayc + sg * 0.25, ayc + sg * 0.02
        def board(z0, z1, d0, d1):
            ya = yb + (yt - yb) * z0 / top_z
            yc = yb + (yt - yb) * z1 / top_z
            return [(ya + sg * d0, z0), (yc + sg * d0, z1), (yc + sg * d1, z1), (ya + sg * d1, z0)]
        det.prism(board(0.12, 0.92, 0.0, 0.018), "x", ax0 + 0.04, ax1 - 0.04, rect("Chalk", 0.56, 0.8))
        for xa, xb in ((ax0, ax0 + 0.04), (ax1 - 0.04, ax1)):
            det.prism(board(0.0, top_z, -0.012, 0.03), "x", xa, xb, PAINT)
        geo.LEVEL = 2
        for z0, z1 in ((0.08, 0.12), (0.92, top_z)):
            det.prism(board(z0, z1, -0.008, 0.026), "x", ax0 + 0.04, ax1 - 0.04, PAINT)
        geo.LEVEL = 3
    geo.LEVEL = 1
    det.tube((ax0 + 0.02, ayc - 0.14, 0.45), (ax0 + 0.02, ayc + 0.14, 0.45), 0.005, 4, IRON)
    det.tube((ax1 - 0.02, ayc - 0.14, 0.45), (ax1 - 0.02, ayc + 0.14, 0.45), 0.005, 4, IRON)
    geo.LEVEL = 3

    # ================================================= shopfront lamps (goosenecks over the cornice), blind windows, stains
    geo.LEVEL = 2
    for i, xl in enumerate((-3.2, 1.7, 6.7)):
        det.box((xl - 0.05, Y0 - 0.025, 4.04), (xl + 0.05, Y0, 4.26), IRON, skip=("+y",))
        arm = [(xl, Y0 - 0.025, 4.15), (xl, Y0 - 0.3, 4.32), (xl, Y0 - 0.72, 4.28), (xl, Y0 - 0.95, 4.08)]
        for p, q in zip(arm, arm[1:]):
            det.tube(p, q, 0.016, 6, IRON)
        frustum(det, (xl, Y0 - 1.0), 0.045, 0.14, 4.08, 3.95, 12, IRON)
        atts["ATT_Lamp_%02d" % (i + 1)] = Vector((xl, Y0 - 1.0, 3.93))
    geo.LEVEL = 2
    for xp in (X0 + 0.8, X1 - 0.8):                    # hopper heads at the top of the front and back downpipes
        for sg in (-1, 1):
            yw = sg * (Y1 + 0.11)
            det.box((xp - 0.1, yw - 0.08, zu(Y1 + OVH) - 0.7), (xp + 0.1, yw + 0.08, zu(Y1 + OVH) - 0.5), IRON)
    # blind (blocked-up) windows: granite infill, lintel, sill, stains below
    blind = [("y", 1, Y1, -4.0, 4.0, 5.3), ("y", 1, Y1, 4.0, 4.0, 5.3), ("y", 1, Y1, -6.0, 1.0, 2.3), ("x", 1, X1, 0.0, 4.0, 5.3)]
    for ax, sg, wf, c, z0, z1 in blind:
        def B(part, s0, s1, o0, o1, t0, t1, mode):
            if ax == "y":
                part.box((c + s0, wf + sg * o0, t0), (c + s1, wf + sg * o1, t1), mode)
            else:
                part.box((wf + sg * o0, c + s0, t0), (wf + sg * o1, c + s1, t1), mode)
        geo.LEVEL = 2
        B(gran, -0.56, 0.56, 0.0, 0.014, z0, z1, STONE)
        B(gran, -0.72, 0.72, 0.0, 0.035, z1, z1 + 0.28, STONE)
        B(tr, -0.66, 0.66, 0.0, 0.075, z0 - 0.08, z0, trim("Sill"))
        geo.LEVEL = 1
        for ds, w, ln in ((-0.5, 0.07, 0.55), (-0.12, 0.05, 0.35), (0.3, 0.08, 0.7), (0.62, 0.05, 0.42)):
            zt0 = z0 - 0.08
            o = wf + sg * 0.012
            if ax == "y":
                q = [(c + ds - w / 2, o, zt0), (c + ds + w / 2, o, zt0), (c + ds + w * 0.1, o, zt0 - ln), (c + ds - w * 0.1, o, zt0 - ln)]
                cen = (c + ds, wf - sg, zt0 - ln / 2)
            else:
                q = [(o, c + ds - w / 2, zt0), (o, c + ds + w / 2, zt0), (o, c + ds + w * 0.1, zt0 - ln), (o, c + ds - w * 0.1, zt0 - ln)]
                cen = (wf - sg, c + ds, zt0 - ln / 2)
            det.face(q, rect("Stain", 0.1, 0.8), centre=cen)
    geo.LEVEL = 1
    for yf, sg in ((-cy, -1), (cy, 1)):                # chimney stack: drips under the oversail course
        for xc, w, ln in ((-9.9, 0.08, 0.5), (-9.62, 0.06, 0.32), (-9.32, 0.09, 0.42)):
            o = yf + sg * 0.012
            det.face([(xc - w / 2, o, 10.05), (xc + w / 2, o, 10.05), (xc + w * 0.1, o, 10.05 - ln), (xc - w * 0.1, o, 10.05 - ln)],
                     rect("Stain", 0.1, 0.8), centre=(xc, yf - sg, 10.0))
    geo.LEVEL = 3

    # ================================================= objects, collision, attachments
    parts = [p for p in (stone, gran, roof, tr, det, shop, glass, door, dglass) if p.faces]
    mats = {
        "Stone": ("QuayStone", geo.material("MI_Chandlery_QuayStone", (0.26, 0.24, 0.21), 0.85)),
        "Granite": ("Granite", geo.material("MI_Chandlery_Granite", (0.11, 0.08, 0.06), 0.85)),
        "Roof": ("Slate", geo.material("MI_Chandlery_Slate", (0.07, 0.08, 0.09), 0.6)),
        "Trim": ("Sheet", geo.material("MI_Chandlery_Trim", (0.3, 0.3, 0.3), 0.6)),
        "Details": ("Details", geo.material("MI_Chandlery_Details", (0.03, 0.06, 0.04), 0.5)),
        "Shopfront": ("Details", geo.material("MI_Chandlery_Shopfront", (0.03, 0.06, 0.04), 0.45)),
        "Glass": ("Details", geo.material("MI_Chandlery_Glass", (0.03, 0.035, 0.04), 0.06)),
        "Door": ("Details", geo.material("MI_Chandlery_Door", (0.03, 0.06, 0.04), 0.45)),
        "DoorGlass": ("Details", geo.material("MI_Chandlery_DoorGlass", (0.03, 0.035, 0.04), 0.06)),
    }
    off = Vector((0, 0, 0))
    meshes, report = [], []
    for p in parts:
        s, mat = mats[p.name]
        obj = p.to_object("%s_%s_LOD0" % (NAME, p.name), mat, off)
        meshes.append({"object": obj, "set": s})
        for li, lod in ((1, "LOD1"), (2, "LOD2")):
            o = p.to_object("%s_%s_%s" % (NAME, p.name, lod), mat, off, lod=li)
            meshes.append({"object": o, "set": s})
        report.append("%s %d/%d/%d" % (p.name, p.tris(0), p.tris(1), p.tris(2)))
    print("[H2] tris LOD0/1/2: " + ", ".join(report))
    print("[H2] totals %d / %d / %d" % tuple(sum(p.tris(i) for p in parts) for i in range(3)))

    col = Part("COL")
    for a, b, c, d in ((X0, DS[0], 0, E), (DS[1], bx0, 0, E), (bx1, X1, 0, E), (DS[0], DS[1], DS[3], E), (bx0, bx1, head, E)):
        col.box((a, Y0, c), (b, IY0, d), STONE)
    col.box((X0, IY1, 0), (X1, Y1, E), STONE)
    col.box((X0, IY0, 0), (IX0, IY1, E), STONE)
    col.box((IX1, IY0, 0), (X1, IY1, E), STONE)
    col.box((-5.0, yF - 0.15, 0), (8.4, Y0, sill), STONE)
    col.box((bx0, yF - 0.02, sill), (bx1, yF + 0.1, head), STONE)
    col.box((c0, yF - 0.36, head), (c1, Y0, 3.88), STONE)
    for p0, p1 in L.SHOPFRONT_PILASTERS:
        col.box((p0, yF - 0.13, 0), (p1, Y0, head), STONE)
    col.box((DS[0] - 0.25, Y0 - 0.38, 0), (DS[1] + 0.25, Y0, L.FLOOR), STONE)
    col.box((bx0, yF + 0.08, 0), (bx1, IY0, L.FLOOR), STONE)
    col.box((ax0, ayc - 0.27, 0), (ax1, ayc + 0.27, top_z), STONE)
    col.box((cx0, -cy, zt(cy) - 0.2), (cx1, cy, 10.7), STONE)
    for sg in (-1, 1):
        col.prism([(sg * (Y1 + OVH), zu(Y1 + OVH)), (0.0, R), (0.0, R + 0.3), (sg * (Y1 + OVH), zu(Y1 + OVH) + 0.3)], "x", X0, X1, STONE)
    colobj = col.to_object(NAME + "_COL", None, off, weld=False)

    att_objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = (p.x * 3, p.y * 3, p.z * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)

    tex = G + "assets/textures/"
    st = lambda x, y, z: [x * 3, y * 3, z * 3]
    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 25000,
        "tier": "hero",
        "dims_m": (20.0, 12.0, 9.5),
        "size_note": ("depth adds the projecting shopfront and cornice (0.94 m), the eaves gutters (0.45 m) and the A-board on "
                      "the quay; height adds the chimney stack and pots on the west gable (top 10.7 m)"),
        "origin": "free",
        "tiling": True,
        "waivers": {"LOD UV layout": "world-scale tiling UVs (trim sheet, B02 library and own tiling sets): hand-made LODs "
                                     "drop small parts, so the UV bounds change; no baked layout to keep"},
        "sets": [
            {"name": "Chandlery", "set": "Slate", "size": 1024, "wet": True},
            {"name": "Chandlery", "set": "Details", "size": 1024, "wet": True},
            {"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": True, "dir": tex + "M_Bld_TrimSheet"},
            {"name": "Mat", "set": "QuayStone", "size": 1024, "wet": True, "dir": tex + "Materials"},
            {"name": "Mat", "set": "Granite", "size": 1024, "wet": True, "dir": tex + "Materials"},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "shopfront_fascia_bay", "target": st(1.7, -6.6, 2.6), "dist": 34, "az": 12, "el": 6},
            {"name": "hanging_sign", "target": st(sx, sy, sz), "dist": 8, "az": 60, "el": 8},
            {"name": "door", "target": st(-7.4, Y0, 1.3), "dist": 10, "az": -15, "el": 4},
            {"name": "eaves_gutter_downpipe", "target": st(X1 - 0.8, Y0 - 0.2, 5.3), "dist": 8, "az": 45, "el": 10},
            {"name": "roof_chimney", "target": st(-9.6, 0.0, 9.9), "dist": 18, "az": -40, "el": 28},
            {"name": "granite_plinth_2m", "target": st(-9.7, Y0, 0.45), "dist": 6, "az": -35, "el": 14},
        ],
    }
