"""M_Hbr_TravelHoist: the Port Haven boatyard's 35 t mobile boat travel hoist (Marine Travelift / Wise class).

Two box-section side frames joined by a rear cross beam, the front open to straddle a slipway dock; four steering
wheel bogies on solid tyres; the operator cab on the right rear leg; engine box and exhaust at the rear; four wide
webbing slings (blue forward, orange aft) hanging from winch blocks on the top beams; hydraulic hoses, ladders,
walkways, railings, warning stripes and a "35 T" capacity plate.

8.0 m wide over the tyres / cab, 11.3 m long, 9.0 m to the top rail and exhaust cap (docs/12 row: about 8 m wide,
9 m tall, 15,000 tris, shared yard atlas). Authored in metres, 1 unit = 1 stud via geo.STUDS.

The eleven visual MeshParts share one 2048 yard atlas set (Yard) so the boatyard assets can share it later. The
atlas is a grid of tiling regions (1024 px paint / steel, 512 px rubber / white / glass / hazard / webbing, a
1024 x 512 capacity plate); maketex.py writes the seamless paint, steel, rubber and decal maps.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/harbour/M_Hbr_TravelHoist/build.py --out-root build/prod/M_Hbr_TravelHoist \
      --steps build,lod,bake,validate,export,turntable
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import geo  # noqa: E402

NAME = "M_Hbr_TravelHoist"
STUDS = 3.0

# overall layout (metres, front -Y)
X = 2.95            # side frame centre
BEAM_X0, BEAM_X1 = 0.35, 0.70          # top beam half width / leg half width
TOP_Z0, TOP_Z1 = 7.00, 7.80
LEG_Y = 4.55
LEG_Z0, LEG_Z1 = 1.32, 7.05
WHEEL_X = 3.65
WHEEL_R = 0.785
CAB = (3.31, 3.70, 3.05, 4.03, 5.55, 4.95)      # x0 y0 z0 x1 y1 z1
WINCH_Y = (-2.25, 2.25)

# atlas: 4 x 4 cells of 512 px; the sign is two cells wide (1024 x 512)
from layout import REG, PAD, SCALES  # noqa: E402


MAT_DEFS = {
    "paint":  ("MI_Hoist_PaintBlue",   0.030, 0.080, 0.170, 0.58, 0.0),
    "white":  ("MI_Hoist_PaintWhite",  0.720, 0.710, 0.660, 0.62, 0.0),
    "steel":  ("MI_Hoist_Steel",       0.300, 0.315, 0.320, 0.46, 1.0),
    "dark":   ("MI_Hoist_DarkSteel",   0.060, 0.068, 0.072, 0.52, 0.9),
    "rubber": ("MI_Hoist_Rubber",      0.022, 0.024, 0.025, 0.84, 0.0),
    "blue":   ("MI_Hoist_FabricBlue",  0.050, 0.120, 0.260, 0.90, 0.0),
    "orange": ("MI_Hoist_FabricOrange",0.600, 0.190, 0.035, 0.90, 0.0),
    "glass":  ("MI_Hoist_Glass",       0.030, 0.045, 0.050, 0.10, 0.0),
    "hazard": ("MI_Hoist_Hazard",      0.620, 0.460, 0.030, 0.60, 0.0),
    "sign":   ("MI_Hoist_Sign",        0.780, 0.770, 0.720, 0.48, 0.0),
    "engine": ("MI_Hoist_Engine",      0.060, 0.075, 0.065, 0.55, 0.4),
}
MATS = {}
for _k, _v in MAT_DEFS.items():
    MATS[_k] = geo.material(_v[0], _v[1:4], _v[4], _v[5])

PARTS = {}


def part(key):
    if key not in PARTS:
        PARTS[key] = geo.Part(key)
    return PARTS[key]


def wr(region, scale=1.0):
    u0, v0, u1, v1 = REG[region]
    # fixed physical tile size per material (jittered off round numbers so no face spans an exact multiple)
    sc = SCALES[region]
    return ("worldreg", u0 + PAD, v0 + PAD, u1 - PAD, v1 - PAD, sc, sc, 0.0, 0.0)


def rect(region, w, h):
    u0, v0, u1, v1 = REG[region]
    return ("rect", u0 + PAD, v0 + PAD, u1 - PAD, v1 - PAD, w, h)


def box(key, lo, hi, mode, skip=()):
    part(key).box(lo, hi, mode, skip)


def box_modes(key, lo, hi, modes, skip=()):
    part(key).box_modes(lo, hi, modes, skip)


def beam(key, p0, p1, w, h, mode, up=(0, 0, 1)):
    p0, p1 = Vector(p0), Vector(p1)
    ax = (p1 - p0).normalized()
    up = Vector(up)
    if abs(ax.dot(up)) > 0.94:
        up = Vector((0, 1, 0)) if abs(ax.y) < 0.9 else Vector((1, 0, 0))
    side = ax.cross(up).normalized() * (w * 0.5)
    vert = side.normalized().cross(ax).normalized() * (h * 0.5)
    s = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
    a = [p0 + side * i + vert * j for i, j in s]
    b = [p1 + side * i + vert * j for i, j in s]
    c = (p0 + p1) * 0.5
    p = part(key)
    p.prim += 1
    for i in range(4):
        j = (i + 1) % 4
        p.face([a[i], a[j], b[j], b[i]], mode, centre=c)
    p.face(a, mode, centre=c + (p1 - p0) * 0.01)
    p.face(b, mode, centre=c - (p1 - p0) * 0.01)


def pipe(key, pts, r, sides, mode, caps=True):
    P = [Vector(p) for p in pts]
    m = len(P)
    T = []
    for i in range(m):
        a, b = P[max(0, i - 1)], P[min(m - 1, i + 1)]
        T.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = T[0].cross(ref).normalized()
    rings = []
    for i in range(m):
        if i:
            nrm = (nrm - T[i] * nrm.dot(T[i])).normalized()
        bn = T[i].cross(nrm)
        rings.append([P[i] + nrm * (r * math.cos(2 * math.pi * j / sides))
                      + bn * (r * math.sin(2 * math.pi * j / sides)) for j in range(sides)])
    p = part(key)
    p.prim += 1
    for i in range(m - 1):
        c = (P[i] + P[i + 1]) * 0.5
        for j in range(sides):
            j1 = (j + 1) % sides
            p.face([rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j]], mode, centre=c)
    if caps:
        p.face(list(reversed(rings[0])), mode, centre=P[0] + T[0] * 0.05)
        p.face(rings[-1], mode, centre=P[-1] - T[-1] * 0.05)


def lathe_x(key, cx, cy, cz, profile, segs, mode):
    """Revolve a (x_offset, radius) profile about the X axis at (cx, cy, cz)."""
    rings = []
    for xo, r in profile:
        rings.append([Vector((cx + xo, cy + r * math.cos(2 * math.pi * j / segs),
                              cz + r * math.sin(2 * math.pi * j / segs))) for j in range(segs)])
    p = part(key)
    p.prim += 1
    for i in range(len(rings) - 1):
        c = Vector((cx + (profile[i][0] + profile[i + 1][0]) * 0.5, cy, cz))
        for j in range(segs):
            j1 = (j + 1) % segs
            p.face([rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j]], mode, centre=c)
    p.face(rings[0], mode, centre=Vector((cx + profile[0][0] + 0.05, cy, cz)))
    p.face(rings[-1], mode, centre=Vector((cx + profile[-1][0] - 0.05, cy, cz)))


def bolt(key, p, axis="z", r=0.028, h=0.03, sides=6):
    p = Vector(p)
    if axis == "z":
        pipe(key, [p, p + Vector((0, 0, h))], r, sides, wr("steel", 0.35), caps=True)
    elif axis == "x":
        pipe(key, [p, p + Vector((h, 0, 0))], r, sides, wr("steel", 0.35), caps=True)
    else:
        pipe(key, [p, p + Vector((0, h, 0))], r, sides, wr("steel", 0.35), caps=True)


def apply_bevel(obj, width_m, segments, mat):
    m = obj.modifiers.new("Bevel", 'BEVEL')
    m.width = width_m * STUDS
    m.segments = segments
    m.limit_method = 'ANGLE'
    m.angle_limit = math.radians(30)
    m.use_clamp_overlap = True
    dg = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    old = obj.data
    obj.modifiers.clear()
    obj.data = new
    bpy.data.meshes.remove(old)
    new.name = obj.name
    if not new.materials and mat is not None:
        new.materials.append(mat)


def emit(key, label, mat_key, bevel=0.0, segments=1, lod=0):
    p = PARTS.get(key)
    if p is None:
        return None
    mat = MATS[mat_key]
    obj = p.to_object("%s_%s_LOD%d" % (NAME, label, lod), mat, lod=lod)
    if bevel:
        apply_bevel(obj, bevel, segments, mat)
    return {"object": obj, "set": "Yard"}


# ------------------------------------------------------------------ structure
def side_frame(sx):
    s = "paint"
    bx0, bx1 = sx * X - BEAM_X0, sx * X + BEAM_X0
    # top lifting beam + tapered nose + rear end cap
    box(s, (bx0, -5.25, TOP_Z0), (bx1, 5.25, TOP_Z1), wr(s, 1.25))
    nose = [(-5.25, TOP_Z0), (-5.74, TOP_Z0), (-5.74, TOP_Z0 + 0.36),
            (-5.55, TOP_Z0 + 0.62), (-5.25, TOP_Z1)]
    part(s).prism(nose, "x", bx0, bx1, wr(s, 1.0))
    box(s, (bx0, 5.25, TOP_Z0), (bx1, 5.48, TOP_Z1), wr(s, 0.8))
    # legs
    for sy in (-1, 1):
        y = sy * LEG_Y
        box(s, (sx * X - 0.35, y - 0.40, LEG_Z0), (sx * X + 0.35, y + 0.40, LEG_Z1), wr(s, 1.1))
        box(s, (sx * X - 0.43, y - 0.48, LEG_Z0 - 0.10), (sx * X + 0.43, y + 0.48, LEG_Z0 + 0.42), wr(s, 0.7))
        # knee gussets under the top beam
        g = [(-0.40, TOP_Z0 - 0.90), (-0.40, TOP_Z0), (-0.98, TOP_Z0)] if sy < 0 else \
            [(0.40, TOP_Z0 - 0.90), (0.40, TOP_Z0), (0.98, TOP_Z0)]
        prof = [(y + a, z) for a, z in g]
        part(s).prism(prof, "x", sx * X - 0.30, sx * X + 0.30, wr(s, 0.9))
        # welds / bolt pads at the leg foot
        box("steel", (sx * X - 0.46, y - 0.51, LEG_Z0 - 0.16), (sx * X + 0.46, y + 0.51, LEG_Z0 - 0.06),
            wr("steel", 0.6))
    # lower chassis beam and its front bumper
    box(s, (sx * X - 0.20, -4.95, 1.24), (sx * X + 0.20, 4.95, 1.76), wr(s, 0.9))
    box(s, (sx * X - 0.26, -5.18, 1.02), (sx * X + 0.26, -4.92, 1.42), wr(s, 0.6))
    box(s, (sx * X - 0.26, -5.20, 1.44), (sx * X + 0.26, -5.13, 1.72), wr(s, 0.5))
    # X bracing between the legs (keeps the side frames rigid, outside the boat space)
    beam("brace", (sx * X, -LEG_Y + 0.30, 2.05), (sx * X, LEG_Y - 0.30, 6.35), 0.20, 0.24, wr("paint", 1.0))
    beam("brace", (sx * X, LEG_Y - 0.30, 2.05), (sx * X, -LEG_Y + 0.30, 6.35), 0.20, 0.24, wr("paint", 1.0))
    # walkway plate and outboard railing
    box("steel", (bx0 + 0.04, -5.04, TOP_Z1), (bx1 - 0.04, 5.04, TOP_Z1 + 0.06), wr("steel", 0.6))
    for y in (-4.75, -2.38, 0.0, 2.38, 4.75):
        beam("white", (sx * (X + 0.30), y, TOP_Z1 + 0.05), (sx * (X + 0.30), y, 9.00), 0.06, 0.06,
             wr("white", 0.4))
    for z in (8.42, 8.96):
        beam("white", (sx * (X + 0.30), -4.80, z), (sx * (X + 0.30), 4.80, z), 0.055, 0.055, wr("white", 0.4))
    # handrail posts at the beam ends (nose + rear)
    beam("white", (sx * (X + 0.30), -5.24, TOP_Z1), (sx * (X + 0.30), -5.24, 9.00), 0.06, 0.06, wr("white", 0.4))
    beam("white", (sx * (X + 0.30), 5.44, TOP_Z1), (sx * (X + 0.30), 5.44, 8.96), 0.06, 0.06, wr("white", 0.4))
    # lifting eyes on the beam ends
    box("steel", (sx * X - 0.12, -5.42, TOP_Z1 + 0.02), (sx * X + 0.12, -5.24, TOP_Z1 + 0.24), wr("steel", 0.4))
    box("steel", (sx * X - 0.12, 5.32, TOP_Z1 + 0.02), (sx * X + 0.12, 5.50, TOP_Z1 + 0.24), wr("steel", 0.4))


def rear_frame():
    s = "paint"
    box(s, (-X - 0.35, 4.30, TOP_Z0), (X + 0.35, 4.92, TOP_Z1), wr(s, 1.2))
    # lower rear cross member under the engine
    box(s, (-X + 0.10, 4.34, 4.62), (X - 0.10, 4.88, 4.98), wr(s, 0.9))
    # rear railing
    for x in (-2.1, -1.0, 0.0, 1.0, 2.1):
        beam("white", (x, 4.68, TOP_Z1), (x, 4.68, 9.00), 0.06, 0.06, wr("white", 0.4))
    for z in (8.42, 8.96):
        beam("white", (-2.35, 4.68, z), (2.35, 4.68, z), 0.055, 0.055, wr("white", 0.4))


def wheel(sx, sy):
    cy = sy * LEG_Y
    cx = sx * WHEEL_X
    # solid tyre: sidewalls, shoulders, tread and four circumferential grooves
    prof = [(-0.34, 0.54), (-0.33, 0.63), (-0.305, 0.755), (-0.285, 0.785), (-0.19, 0.785),
            (-0.175, 0.752), (-0.06, 0.785), (0.06, 0.785), (0.175, 0.752), (0.19, 0.785),
            (0.285, 0.785), (0.305, 0.755), (0.33, 0.63), (0.34, 0.54)]
    lathe_x("rubber", cx, cy, WHEEL_R, prof, 20, wr("rubber", 0.5))
    # rim, hub and lug nuts
    lathe_x("steel", cx, cy, WHEEL_R, [(-0.355, 0.50), (-0.33, 0.53), (0.33, 0.53), (0.355, 0.50)], 12,
            wr("steel", 0.4))
    lathe_x("steel", cx, cy, WHEEL_R, [(-0.39, 0.17), (-0.35, 0.21), (0.35, 0.21), (0.39, 0.17)], 12,
            wr("steel", 0.35))
    for k in range(4):
        a = 2 * math.pi * (k + 0.5) / 4
        bolt("steel", (cx + sx * 0.355, cy + 0.30 * math.cos(a), WHEEL_R + 0.30 * math.sin(a)),
             axis="x", r=0.024, h=sx * 0.04)
    # steering bogie: box, kingpin, diagonal trailing arm and ram
    box("paint", (sx * X - 0.36, cy - 0.42, 1.24), (sx * X + 0.38, cy + 0.42, 1.96), wr("paint", 0.7))
    lathe_x("steel", sx * X + 0.06, cy, 1.16, [(-0.16, 0.19), (-0.12, 0.23), (0.12, 0.23), (0.16, 0.19)], 14,
            wr("steel", 0.35))
    beam("steel", (sx * X, cy, 1.72), (sx * (X + 0.16), cy, 1.72), 0.18, 0.18, wr("steel", 0.5))
    beam("steel", (sx * X - 0.05, cy, 1.62), (sx * WHEEL_X + sx * 0.02, cy, 0.92), 0.24, 0.20, wr("steel", 0.5))
    beam("steel", (sx * X + 0.02, cy - 0.32, 1.74), (sx * WHEEL_X - sx * 0.05, cy - 0.30, 1.10),
         0.15, 0.13, wr("steel", 0.45))
    # steering ram and hoses
    pipe("steel", [(sx * X + 0.08, cy + 0.30, 1.80), (sx * (X + 0.40), cy + 0.52, 1.72),
                   (sx * (X + 0.46), cy + 0.30, 1.44)], 0.055, 8, wr("steel", 0.4))
    pipe("rubber", [(sx * X + 0.18, cy + 0.42, 1.92), (sx * (X + 0.38), cy + 0.64, 1.72),
                    (sx * (X + 0.45), cy + 0.26, 1.50), (sx * (X + 0.34), cy + 0.05, 1.38)],
         0.035, 7, wr("rubber", 0.4))
    # arch fender + rubber mudflap
    a0, a1 = math.radians(18), math.radians(162)
    n = 8
    x0, x1 = sx * (WHEEL_X - 0.46), sx * (WHEEL_X + 0.44)
    for i in range(n):
        t0, t1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
        ro, ri = WHEEL_R + 0.12, WHEEL_R + 0.045
        def q(a, r):
            return (cx + 0.0, cy + r * math.cos(a), WHEEL_R + r * math.sin(a))
        pts = [q(t0, ri), q(t0, ro), q(t1, ro), q(t1, ri)]
        p = part("fender")
        p.prim += 1
        p.face([(x0, pts[0][1], pts[0][2]), (x1, pts[0][1], pts[0][2]),
                (x1, pts[1][1], pts[1][2]), (x0, pts[1][1], pts[1][2])], wr("paint", 0.7),
               centre=(cx, cy, WHEEL_R))
        p.face([(x0, pts[2][1], pts[2][2]), (x1, pts[2][1], pts[2][2]),
                (x1, pts[3][1], pts[3][2]), (x0, pts[3][1], pts[3][2])], wr("paint", 0.7),
               centre=(cx, cy, WHEEL_R))
        p.face([(x0, pts[1][1], pts[1][2]), (x1, pts[1][1], pts[1][2]),
                (x1, pts[2][1], pts[2][2]), (x0, pts[2][1], pts[2][2])], wr("paint", 0.7),
               centre=(cx, cy, WHEEL_R))
    box("rubber", (sx * (WHEEL_X - 0.38), cy - WHEEL_R - 0.24, 0.30),
        (sx * (WHEEL_X + 0.38), cy - WHEEL_R - 0.20, 0.72), wr("rubber", 0.4))


def winch(sx, y):
    cx = sx * X
    s = "steel"
    box(s, (cx - 0.45, y - 0.56, TOP_Z1), (cx + 0.45, y + 0.56, TOP_Z1 + 0.10), wr(s, 0.6))
    lathe_x("steel", cx, y, 8.34, [(-0.44, 0.22), (-0.40, 0.30), (-0.36, 0.33), (0.36, 0.33), (0.40, 0.30),
                                  (0.44, 0.22)], 20, wr("steel", 0.5))
    lathe_x("steel", cx, y, 8.34, [(-0.47, 0.30), (-0.44, 0.34), (-0.41, 0.34), (-0.41, 0.22)], 18,
            wr("steel", 0.4))
    lathe_x("steel", cx, y, 8.34, [(0.41, 0.22), (0.41, 0.34), (0.44, 0.34), (0.47, 0.30)], 18,
            wr("steel", 0.4))
    # wound cable on the drum (two proud bands) and hydraulic motor on the outboard end
    lathe_x("steel", cx, y, 8.34, [(-0.30, 0.285), (-0.27, 0.30), (0.27, 0.30), (0.30, 0.285)], 18,
            wr("steel", 0.3))
    lathe_x("steel", cx + sx * 0.50, y, 8.34, [(-0.10, 0.15), (0.10, 0.15)], 14, wr("steel", 0.3))
    pipe("rubber", [(cx + sx * 0.58, y + 0.12, 8.34), (cx + sx * 0.62, y + 0.24, 8.10),
                    (cx + sx * 0.60, y + 0.20, 7.72), (cx + sx * 0.48, y + 0.10, 7.52)],
         0.037, 7, wr("rubber", 0.4))
    # guard frame
    box("white", (cx - 0.40, y - 0.48, 8.64), (cx + 0.40, y + 0.48, 8.70), wr("white", 0.5))
    for sy in (-1, 1):
        box("white", (cx - 0.40, y + sy * 0.48 - 0.03, 8.56), (cx + 0.40, y + sy * 0.48 + 0.03, 8.70),
            wr("white", 0.4))
    # sheave block under the beam, offset inboard, with a pulley
    sx0 = cx - sx * 0.22
    box("steel", (sx0 - 0.15, y - 0.32, 6.68), (sx0 + 0.15, y + 0.32, 7.02), wr("steel", 0.45))
    lathe_x("steel", sx0, y, 6.82, [(-0.05, 0.22), (-0.03, 0.27), (0.03, 0.27), (0.05, 0.22)], 18,
            wr("steel", 0.35))
    # wire rope: drum -> edge roller -> sheave -> sling head
    rope = [(cx, y, 8.38), (cx - sx * 0.12, y, 8.10), (cx - sx * 0.34, y, 7.90),
            (sx0, y, 6.98), (sx0, y, 6.54)]
    pipe("steel", rope, 0.032, 7, wr("steel", 0.35))
    box("steel", (cx - sx * 0.38, y - 0.10, 7.88), (cx - sx * 0.28, y + 0.10, 8.00), wr("steel", 0.3))
    # sling head clevis / pin
    box("steel", (sx0 - 0.20, y - 0.10, 6.30), (sx0 + 0.20, y + 0.10, 6.58), wr("steel", 0.5))
    pipe("steel", [(sx0 - 0.28, y, 6.44), (sx0 + 0.28, y, 6.44)], 0.055, 10, wr("steel", 0.35))


def sling(sx, y, region):
    cx = sx * (X - 0.22)
    # Catmull-Rom loop in the YZ plane (a wide webbing sling draped over the head pin)
    ctrl = [(-0.06, 6.45), (-0.20, 6.32), (-0.28, 5.90), (-0.32, 4.90), (-0.35, 3.40),
            (-0.34, 2.45), (-0.27, 1.83), (-0.14, 1.55), (0.0, 1.48), (0.14, 1.55),
            (0.27, 1.83), (0.34, 2.45), (0.35, 3.40), (0.32, 4.90), (0.28, 5.90),
            (0.20, 6.32), (0.06, 6.45), (0.0, 6.62)]
    n = len(ctrl)
    pts = []
    per = 2
    for i in range(n):
        p0, p1, p2, p3 = (Vector(ctrl[(i - 1) % n]), Vector(ctrl[i]),
                          Vector(ctrl[(i + 1) % n]), Vector(ctrl[(i + 2) % n]))
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                       + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            pts.append(Vector((y + q.x, q.y)))
    m = len(pts)
    s = 0.0
    v0 = REG[region][1]
    dv = REG[region][3] - v0
    rings = []
    for i in range(m + 1):
        p = pts[i % m]
        a, b = pts[(i - 1) % m], pts[(i + 1) % m]
        t = (b - a).normalized()
        nrm = Vector((-t.y, t.x))
        if i:
            s += (p - pts[(i - 1) % m]).length
        v = v0 + ((s / 0.45) % 1.0) * dv
        rings.append((p, nrm, v))
    part(region).prim += 1
    for i in range(m):
        p0, n0, vv0 = rings[i]
        p1, n1, vv1 = rings[i + 1]
        # four faces: outer, inner, and two edges (band width along X)
        for off, sgn in ((0.018, -1.0), (-0.018, 1.0)):
            a0 = Vector((cx - 0.210, p0.x + n0.x * off, p0.y + n0.y * off))
            b0 = Vector((cx + 0.210, p0.x + n0.x * off, p0.y + n0.y * off))
            a1 = Vector((cx - 0.210, p1.x + n1.x * off, p1.y + n1.y * off))
            b1 = Vector((cx + 0.210, p1.x + n1.x * off, p1.y + n1.y * off))
            u0, u1 = REG[region][0], REG[region][2]
            if sgn < 0:
                uvs = [(u0, vv0), (u1, vv0), (u1, vv1), (u0, vv1)]
            else:
                uvs = [(u1, vv0), (u0, vv0), (u0, vv1), (u1, vv1)]
            part(region).face([a0, b0, b1, a1], ("uv", uvs),
                              centre=(cx, p0.x, p0.y))
        # side edges
        for xo in (-0.210, 0.210):
            a0 = Vector((cx + xo, p0.x + n0.x * 0.018, p0.y + n0.y * 0.018))
            a1 = Vector((cx + xo, p0.x - n0.x * 0.018, p0.y - n0.y * 0.018))
            b0 = Vector((cx + xo, p1.x + n1.x * 0.018, p1.y + n1.y * 0.018))
            b1 = Vector((cx + xo, p1.x - n1.x * 0.018, p1.y - n1.y * 0.018))
            u0e, u1e = REG[region][0], REG[region][2]
            uvs = [(u0e, vv0), (u1e, vv0), (u1e, vv1), (u0e, vv1)]
            part(region).face([a0, a1, b1, b0], ("uv", uvs),
                              centre=(cx, p0.x, p0.y))


def cab():
    x0, y0, z0, x1, y1, z1 = CAB
    s = "paint"
    box(s, (x0, y0, z0), (x1, y1, z0 + 0.30), wr(s, 0.7))                       # floor / sill
    box("white", (x0 - 0.05, y0 - 0.06, z1 - 0.20), (x1 + 0.05, y1 + 0.06, z1), wr("white", 0.55))
    for xx in (x0 + 0.02, x1 - 0.09):
        for yy in (y0 + 0.02, y1 - 0.09):
            box("white", (xx, yy, z0 + 0.24), (xx + 0.07, yy + 0.07, z1 - 0.18), wr("white", 0.4))
    # glazing (front, outboard, rear) with white mullions
    box("glass", (x0 + 0.08, y0 + 0.01, z0 + 0.42), (x1 - 0.08, y0 + 0.035, z1 - 0.26), wr("glass", 0.7))
    box("glass", (x1 - 0.035, y0 + 0.10, z0 + 0.42), (x1 - 0.005, y1 - 0.10, z1 - 0.26), wr("glass", 0.7))
    box("glass", (x0 + 0.08, y1 - 0.035, z0 + 0.42), (x1 - 0.08, y1 - 0.005, z1 - 0.26), wr("glass", 0.7))
    for yy in (3.72, 4.60, 5.50):
        box("white", (x0 + 0.04, yy - 0.035, z0 + 0.26), (x1 - 0.04, yy + 0.035, z1 - 0.18), wr("white", 0.35))
    box("white", (x0 + 0.04, y0 + 0.30, z0 + 0.34), (x1 - 0.04, y0 + 0.36, z1 - 0.18), wr("white", 0.35))
    # door on the outboard face: frame, handle, hinges
    box_modes("white", (x1 - 0.06, 3.94, z0 + 0.28), (x1 + 0.005, 3.99, z1 - 0.20),
              {"any": wr("white", 0.3), "+x": wr("white", 0.4)})
    for zz in (z0 + 0.45, z1 - 0.42):
        box("steel", (x1 - 0.01, 3.93, zz), (x1 + 0.03, 4.04, zz + 0.12), wr("steel", 0.3))
    box("steel", (x1 + 0.00, 4.52, 4.12), (x1 + 0.05, 4.82, 4.20), wr("steel", 0.25))
    # interior: seat, console, joystick, screen
    box("steel", (x0 + 0.08, 4.42, z0 + 0.30), (x1 - 0.10, 4.82, z0 + 0.44), wr("steel", 0.5))
    box("blue", (x0 + 0.10, 4.42, z0 + 0.44), (x1 - 0.12, 4.80, z0 + 0.54), wr("blue", 0.4))
    box("blue", (x0 + 0.10, 4.78, z0 + 0.50), (x1 - 0.12, 4.86, z0 + 1.10), wr("blue", 0.4))
    box("steel", (x0 + 0.08, y0 + 0.16, z0 + 0.66), (x1 - 0.08, y0 + 0.40, z0 + 0.86), wr("steel", 0.4))
    box("glass", (x0 + 0.14, y0 + 0.175, z0 + 0.70), (x0 + 0.44, y0 + 0.185, z0 + 0.84), wr("glass", 0.4))
    pipe("steel", [(x0 + 0.55, y0 + 0.30, z0 + 0.86), (x0 + 0.55, y0 + 0.30, z0 + 1.06)], 0.020, 8,
         wr("steel", 0.3))
    pipe("steel", [(x0 + 0.55, y0 + 0.30, z0 + 1.06), (x0 + 0.55, y0 + 0.30, z0 + 1.14)], 0.035, 8,
         wr("steel", 0.3))
    # roof beacon, mirror arm and wiper
    lathe_x("hazard", 3.70, 4.98, 5.04, [(-0.06, 0.12), (0.06, 0.12)], 12, wr("hazard", 0.3))
    lathe_x("glass", 3.70, 4.98, 5.12, [(-0.07, 0.10), (0.0, 0.12), (0.07, 0.10)], 12, wr("glass", 0.3))
    beam("steel", (x0 + 0.10, y0 - 0.02, 4.62), (x0 - 0.22, y0 - 0.22, 4.62), 0.035, 0.035, wr("steel", 0.25))
    box("steel", (x0 - 0.30, y0 - 0.24, 4.54), (x0 - 0.22, y0 - 0.18, 4.72), wr("steel", 0.3))
    pipe("steel", [(x0 + 0.18, y0 - 0.02, 3.76), (x1 - 0.18, y0 - 0.02, 4.20)], 0.012, 6, wr("steel", 0.25))
    # under-cab steps
    box("steel", (x0 + 0.10, y1 + 0.04, 2.92), (x1 - 0.10, y1 + 0.34, 2.98), wr("steel", 0.35))
    box("steel", (x0 + 0.10, y1 + 0.04, 2.44), (x1 - 0.10, y1 + 0.28, 2.50), wr("steel", 0.35))


def engine():
    x0, x1 = -1.36, 1.36
    y0, y1 = 4.92, 5.56
    z0, z1 = 4.98, 6.22
    box("paint", (x0, y0, z0), (x1, y1, z1), wr("paint", 0.9))
    box("white", (x0 - 0.03, y0 - 0.02, z1 - 0.10), (x1 + 0.03, y1 + 0.02, z1), wr("white", 0.5))
    # access doors and louvres
    for xx in (-0.92, 0.92):
        box("rubber", (xx - 0.30, y1 - 0.02, 5.20), (xx + 0.30, y1 + 0.01, 5.86), wr("rubber", 0.5))
        for k in range(6):
            box("steel", (xx - 0.27, y1 + 0.005, 5.25 + k * 0.095), (xx + 0.27, y1 + 0.025, 5.28 + k * 0.095),
                wr("steel", 0.3))
        box("steel", (xx + 0.31, y1 + 0.00, 5.35), (xx + 0.38, y1 + 0.04, 5.68), wr("steel", 0.25))
    # fuel / hydraulic tanks and exhaust
    box("white", (x0 + 0.10, y0 - 0.20, 4.38), (x1 - 0.10, y0 - 0.02, 4.86), wr("white", 0.55))
    box("steel", (1.42, y0 + 0.02, 4.44), (2.14, y1 - 0.02, 5.20), wr("steel", 0.6))
    box("glass", (2.15, 5.04, 4.62), (2.17, 5.10, 4.98), wr("glass", 0.3))
    box("steel", (-0.94, 5.10, 6.18), (-0.78, 5.30, 6.26), wr("steel", 0.3))
    pipe("rubber", [(-0.86, 5.20, 6.20), (-0.86, 5.20, 8.90)], 0.085, 10, wr("rubber", 0.4))
    pipe("steel", [(-0.86, 5.20, 6.28), (-0.86, 5.20, 7.40)], 0.115, 10, wr("steel", 0.4))
    pipe("rubber", [(-0.86, 5.20, 8.86), (-0.86, 5.33, 8.96), (-0.86, 5.46, 8.88)], 0.085, 10, wr("rubber", 0.35))
    box("steel", (-0.93, 5.13, 8.34), (-0.79, 5.27, 8.40), wr("steel", 0.3))
    # hydraulic hoses from power pack to the winches and cab
    for i, off in enumerate((0.0, 0.10, 0.20)):
        pipe("rubber", [(1.40, 5.02 + off, 4.92), (2.30, 5.10 + off, 5.24), (3.02, 4.70 + off, 5.70),
                        (3.28, 3.40, 6.30 + off), (3.28, 1.00, 6.66), (3.10, -1.20, 7.12),
                        (3.02, -2.25, 7.34)], 0.032, 7, wr("rubber", 0.4))
    for y in (3.4, 1.0, -1.2):
        box("steel", (3.24, y - 0.06, 6.56), (3.34, y + 0.06, 6.72), wr("steel", 0.3))


def rear_ladder():
    # caged access ladder to the top walkway on the left rear leg
    x = -3.06
    y = 5.02
    for sx in (-1, 1):
        beam("steel", (x + sx * 0.20, y, 0.20), (x + sx * 0.20, y, 7.78), 0.055, 0.055, wr("steel", 0.4))
    for k in range(10):
        z = 0.48 + k * 0.73
        beam("steel", (x - 0.20, y, z), (x + 0.20, y, z), 0.04, 0.04, wr("steel", 0.35))
    for k in range(7):
        z = 2.62 + k * 0.80
        pipe("steel", [(x - 0.34, y, z), (x - 0.34, y + 0.56, z), (x + 0.34, y + 0.56, z),
                       (x + 0.34, y, z)], 0.026, 6, wr("steel", 0.35))
    for k in range(4):
        z = 2.8 + k * 1.55
        beam("steel", (x - 0.30, y + 0.56, z), (x - 0.30, y + 0.56, z + 0.34), 0.035, 0.035, wr("steel", 0.3))
        beam("steel", (x + 0.30, y + 0.56, z), (x + 0.30, y + 0.56, z + 0.34), 0.035, 0.035, wr("steel", 0.3))


def cab_ladder():
    x, y = 3.06, 4.96
    for sx in (-1, 1):
        beam("steel", (x + sx * 0.18, y, 0.22), (x + sx * 0.18, y, 3.02), 0.05, 0.05, wr("steel", 0.4))
    for k in range(6):
        z = 0.42 + k * 0.48
        beam("steel", (x - 0.18, y, z), (x + 0.18, y, z), 0.035, 0.035, wr("steel", 0.35))
    box("steel", (2.92, 4.98, 3.02), (3.62, 5.40, 3.08), wr("steel", 0.5))


def decals():
    # rear cross beam: 35 T plate and a hazard band on the rear face
    box_modes("sign", (-0.72, 4.24, 7.10), (0.72, 4.30, 7.70),
              {"any": wr("sign", 0.6), "-y": rect("sign", 1.44, 0.60)})
    box_modes("hazard", (-2.70, 4.92, 7.02), (2.70, 4.96, 7.34),
              {"any": wr("hazard", 0.55), "+y": wr("hazard", 0.55)})
    # outboard plate on the right top beam
    box_modes("sign", (3.30, -0.92, 7.12), (3.35, 0.52, 7.66),
              {"any": wr("sign", 0.6), "+x": rect("sign", 1.44, 0.54)})
    # hazard bands on the front bumpers and top beam noses
    for sx in (-1, 1):
        box("hazard", (sx * X - 0.27, -5.205, 1.10), (sx * X + 0.27, -5.14, 1.40), wr("hazard", 0.45))
        box("hazard", (sx * X - 0.31, -5.755, 7.02), (sx * X + 0.31, -5.70, 7.34), wr("hazard", 0.45))
    # small "35 t" plate beside the cab door
    box_modes("sign", (4.04, 4.02, 3.64), (4.07, 4.62, 3.94),
              {"any": wr("sign", 0.4), "+x": rect("sign", 0.60, 0.30)})


def attachments():
    out = []

    def att(name, p):
        e = bpy.data.objects.new(name, None)
        e.location = (p[0] * STUDS, p[1] * STUDS, p[2] * STUDS)
        bpy.context.scene.collection.objects.link(e)
        out.append(e)

    for sx, side in ((1, "R"), (-1, "L")):
        for y, fb in ((-2.25, "F"), (2.25, "A")):
            att("ATT_SlingPoint_%s%s" % (fb, side), (sx * (X - 0.22), y, 6.44))
    att("ATT_Cab", (3.67, 4.62, 3.95))
    att("ATT_CabSeat", (3.67, 4.62, 3.40))
    att("ATT_EyePoint", (3.60, 4.15, 4.22))
    att("ATT_Control", (3.55, 3.95, 4.05))
    att("ATT_Beacon", (3.70, 4.98, 5.16))
    att("ATT_FuelCap", (0.0, 4.78, 4.88))
    att("ATT_LadderBase", (-3.06, 5.02, 0.20))
    att("ATT_Top", (0.0, 0.0, 8.98))
    return out


def collision():
    c = geo.Part("COL")
    wr = lambda region, scale=1.0: ("tile", 1.0)
    for sx in (-1, 1):
        c.box((sx * X - 0.40, -5.75, TOP_Z0 - 0.05), (sx * X + 0.40, 5.48, TOP_Z1), wr("paint", 1.0))
        c.box((sx * X - 0.48, -4.98, 0.0), (sx * X + 0.48, 4.98, 1.78), wr("paint", 1.0))
        for sy in (-1, 1):
            c.box((sx * X - 0.46, sy * LEG_Y - 0.44, LEG_Z0), (sx * X + 0.46, sy * LEG_Y + 0.44, TOP_Z0),
                  wr("paint", 1.0))
            c.box((sx * WHEEL_X - 0.40, sy * LEG_Y - WHEEL_R, 0.0),
                  (sx * WHEEL_X + 0.40, sy * LEG_Y + WHEEL_R, WHEEL_R * 2.0), wr("rubber", 1.0))
    c.box((-X - 0.35, 4.30, TOP_Z0), (X + 0.35, 4.96, TOP_Z1), wr("paint", 1.0))
    c.box((CAB[0], CAB[1], CAB[2]), (CAB[3], CAB[4], CAB[5]), wr("paint", 1.0))
    c.box((-1.36, 4.92, 4.98), (1.36, 5.56, 6.22), wr("paint", 1.0))
    c.box((-0.95, 5.12, 6.18), (-0.77, 5.32, 8.96), wr("steel", 1.0))
    return c.to_object(NAME + "_COL", None, lod=0, weld=False)


# ------------------------------------------------------------ hand-built LOD1 / LOD2
def wheel_lod1(sx, sy):
    cy = sy * LEG_Y
    cx = sx * WHEEL_X
    prof = [(-0.34, 0.54), (-0.32, 0.70), (-0.27, 0.785), (0.27, 0.785), (0.32, 0.70), (0.34, 0.54)]
    lathe_x("rubber", cx, cy, WHEEL_R, prof, 16, wr("rubber", 0.5))
    lathe_x("steel", cx, cy, WHEEL_R, [(-0.35, 0.50), (-0.31, 0.53), (0.31, 0.53), (0.35, 0.50)], 10,
            wr("steel", 0.4))
    box("paint", (sx * X - 0.34, cy - 0.40, 1.26), (sx * X + 0.36, cy + 0.40, 1.92), wr("paint", 0.7))
    beam("steel", (sx * X, cy, 1.62), (sx * WHEEL_X, cy, 0.94), 0.24, 0.20, wr("steel", 0.5))
    box("paint", (sx * (WHEEL_X - 0.44), cy - 0.90, 1.66), (sx * (WHEEL_X + 0.42), cy + 0.90, 1.73),
        wr("paint", 0.7))
    box("rubber", (sx * (WHEEL_X - 0.35), cy - WHEEL_R - 0.22, 0.34),
        (sx * (WHEEL_X + 0.35), cy - WHEEL_R - 0.18, 0.72), wr("rubber", 0.4))


def wheel_lod2(sx, sy):
    cx, cy = sx * WHEEL_X, sy * LEG_Y
    lathe_x("rubber", cx, cy, WHEEL_R, [(-0.32, 0.50), (-0.29, 0.78), (0.29, 0.78), (0.32, 0.50)], 10,
            wr("rubber", 0.6))
    box("paint", (sx * X - 0.32, cy - 0.36, 1.28), (sx * X + 0.34, cy + 0.36, 1.88), wr("paint", 0.8))


def winch_lod1(sx, y):
    cx = sx * X
    box("steel", (cx - 0.42, y - 0.50, TOP_Z1), (cx + 0.42, y + 0.50, TOP_Z1 + 0.10), wr("steel", 0.5))
    lathe_x("steel", cx, y, 8.34, [(-0.40, 0.24), (-0.34, 0.33), (0.34, 0.33), (0.40, 0.24)], 12,
            wr("steel", 0.5))
    box("steel", (cx - sx * 0.20 - 0.14, y - 0.28, 6.70), (cx - sx * 0.20 + 0.14, y + 0.28, 7.00),
        wr("steel", 0.4))
    lathe_x("steel", cx - sx * 0.20, y, 6.82, [(-0.04, 0.24), (0.04, 0.24)], 10, wr("steel", 0.4))
    pipe("steel", [(cx, y, 8.38), (cx - sx * 0.22, y, 7.96), (cx - sx * 0.20, y, 6.60)], 0.035, 5,
         wr("steel", 0.4))


def winch_lod2(sx, y):
    cx = sx * X
    box("steel", (cx - 0.40, y - 0.50, TOP_Z1), (cx + 0.40, y + 0.50, TOP_Z1 + 0.22), wr("steel", 0.6))
    box("steel", (cx - sx * 0.22 - 0.12, y - 0.26, 6.72), (cx - sx * 0.22 + 0.12, y + 0.26, 6.98),
        wr("steel", 0.5))


def sling_lod1(sx, y, region, segs=18):
    cx = sx * (X - 0.22)
    ctrl = [(-0.06, 6.45), (-0.28, 5.90), (-0.35, 3.40), (-0.27, 1.83), (0.0, 1.48), (0.27, 1.83),
            (0.35, 3.40), (0.28, 5.90), (0.06, 6.45), (0.0, 6.62)]
    pts = []
    n = len(ctrl)
    for i in range(segs):
        t = i / segs * n
        k = int(t) % n
        f = t - int(t)
        p0, p1, p2, p3 = (Vector(ctrl[(k - 1) % n]), Vector(ctrl[k]), Vector(ctrl[(k + 1) % n]),
                          Vector(ctrl[(k + 2) % n]))
        t2, t3 = f * f, f * f * f
        q = 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                   + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        pts.append(Vector((y + q.x, q.y)))
    rings = []
    for i in range(segs + 1):
        p = pts[i % segs]
        a, b = pts[(i - 1) % segs], pts[(i + 1) % segs]
        t = (b - a).normalized()
        rings.append((p, Vector((-t.y, t.x))))
    part(region).prim += 1
    u0, v0, u1, v1 = REG[region]
    for i in range(segs):
        p0, n0 = rings[i]
        p1, n1 = rings[i + 1]
        for off in (-0.015, 0.015):
            a0 = Vector((cx - 0.210, p0.x + n0.x * off, p0.y + n0.y * off))
            b0 = Vector((cx + 0.210, p0.x + n0.x * off, p0.y + n0.y * off))
            a1 = Vector((cx - 0.210, p1.x + n1.x * off, p1.y + n1.y * off))
            b1 = Vector((cx + 0.210, p1.x + n1.x * off, p1.y + n1.y * off))
            part(region).face([a0, b0, b1, a1], ("uv", [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]),
                              centre=(cx, p0.x, p0.y))
    box("steel", (cx - 0.20, y - 0.10, 6.32), (cx + 0.20, y + 0.10, 6.56), wr("steel", 0.4))


def sling_lod2(sx, y, region):
    cx = sx * (X - 0.22)
    u0, v0, u1, v1 = REG[region]
    pts = [(y - 0.06, 6.45), (y - 0.32, 3.4), (y - 0.18, 1.55), (y, 1.45), (y + 0.18, 1.55),
           (y + 0.32, 3.4), (y + 0.06, 6.45), (y, 6.60)]
    part(region).prim += 1
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        A0 = Vector((cx - 0.210, a[0], a[1]))
        B0 = Vector((cx + 0.210, a[0], a[1]))
        A1 = Vector((cx - 0.210, b[0], b[1]))
        B1 = Vector((cx + 0.210, b[0], b[1]))
        part(region).face([A0, B0, B1, A1], ("uv", [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]),
                          centre=(cx, a[0], a[1]))


def cab_lod1():
    x0, y0, z0, x1, y1, z1 = CAB
    box("paint", (x0, y0, z0), (x1, y1, z0 + 0.34), wr("paint", 0.7))
    box("white", (x0 - 0.04, y0 - 0.05, z1 - 0.20), (x1 + 0.04, y1 + 0.05, z1), wr("white", 0.6))
    box("glass", (x0 + 0.06, y0 + 0.01, z0 + 0.40), (x1 - 0.06, y0 + 0.04, z1 - 0.24), wr("glass", 0.7))
    box("glass", (x1 - 0.04, y0 + 0.10, z0 + 0.40), (x1 - 0.01, y1 - 0.10, z1 - 0.24), wr("glass", 0.7))
    box("glass", (x0 + 0.06, y1 - 0.04, z0 + 0.40), (x1 - 0.06, y1 - 0.01, z1 - 0.24), wr("glass", 0.7))
    box("steel", (x0 + 0.10, 4.44, z0 + 0.32), (x1 - 0.10, 4.82, z0 + 0.68), wr("steel", 0.5))
    box("steel", (x0 + 0.10, y0 + 0.16, z0 + 0.66), (x1 - 0.10, y0 + 0.40, z0 + 0.88), wr("steel", 0.4))
    lathe_x("hazard", 3.70, 4.98, 5.04, [(-0.05, 0.12), (0.05, 0.12)], 8, wr("hazard", 0.4))
    box("steel", (x0 + 0.10, y1 + 0.04, 2.94), (x1 - 0.10, y1 + 0.32, 3.00), wr("steel", 0.4))


def cab_lod2():
    x0, y0, z0, x1, y1, z1 = CAB
    box("paint", (x0, y0, z0), (x1, y1, z1), wr("paint", 0.8))
    box("white", (x0 - 0.04, y0 - 0.05, z1 - 0.18), (x1 + 0.04, y1 + 0.05, z1), wr("white", 0.7))
    box("glass", (x0 + 0.06, y0 + 0.01, z0 + 0.40), (x1 - 0.06, y0 + 0.04, z1 - 0.24), wr("glass", 0.8))


def engine_lod1():
    box("paint", (-1.36, 4.92, 4.98), (1.36, 5.56, 6.22), wr("paint", 0.9))
    box("white", (-1.39, 4.90, 6.12), (1.39, 5.58, 6.22), wr("white", 0.6))
    box("rubber", (-1.22, 5.55, 5.20), (-0.62, 5.58, 5.86), wr("rubber", 0.5))
    box("rubber", (0.62, 5.55, 5.20), (1.22, 5.58, 5.86), wr("rubber", 0.5))
    box("white", (-1.26, 4.72, 4.38), (1.26, 4.90, 4.86), wr("white", 0.6))
    pipe("rubber", [(-0.86, 5.20, 6.20), (-0.86, 5.20, 8.90)], 0.09, 6, wr("rubber", 0.5))
    pipe("rubber", [(-0.86, 5.20, 8.86), (-0.86, 5.34, 8.96), (-0.86, 5.46, 8.88)], 0.09, 6, wr("rubber", 0.4))
    pipe("rubber", [(1.40, 5.10, 4.96), (2.80, 4.80, 5.50), (3.22, 3.20, 6.20), (3.02, -2.25, 7.34)],
         0.035, 6, wr("rubber", 0.5))


def engine_lod2():
    box("paint", (-1.36, 4.92, 4.98), (1.36, 5.56, 6.22), wr("paint", 1.0))
    pipe("rubber", [(-0.86, 5.20, 6.20), (-0.86, 5.20, 8.90)], 0.10, 6, wr("rubber", 0.5))


def ladders_lod1():
    x, y = -3.06, 5.02
    for sx in (-1, 1):
        beam("steel", (x + sx * 0.20, y, 0.20), (x + sx * 0.20, y, 7.70), 0.06, 0.06, wr("steel", 0.5))
    for k in range(9):
        beam("steel", (x - 0.20, y, 0.48 + k * 0.78), (x + 0.20, y, 0.48 + k * 0.78), 0.04, 0.04,
             wr("steel", 0.4))
    pipe("steel", [(x - 0.30, y, 3.2), (x - 0.30, y + 0.50, 3.2), (x + 0.30, y + 0.50, 3.2),
                   (x + 0.30, y, 3.2)], 0.025, 5, wr("steel", 0.4))
    x, y = 3.06, 4.96
    for sx in (-1, 1):
        beam("steel", (x + sx * 0.18, y, 0.22), (x + sx * 0.18, y, 3.02), 0.05, 0.05, wr("steel", 0.5))
    for k in range(5):
        beam("steel", (x - 0.18, y, 0.42 + k * 0.58), (x + 0.18, y, 0.42 + k * 0.58), 0.035, 0.035,
             wr("steel", 0.4))


def ladders_lod2():
    for x, y, z1 in ((-3.06, 5.02, 7.70), (3.06, 4.96, 3.02)):
        box("steel", (x - 0.22, y - 0.03, 0.20), (x + 0.22, y + 0.03, z1), wr("steel", 0.6))


def decals_lod1():
    box_modes("sign", (-0.72, 4.24, 7.10), (0.72, 4.30, 7.70),
              {"any": wr("sign", 0.6), "-y": rect("sign", 1.44, 0.60)})
    box_modes("sign", (3.30, -0.92, 7.12), (3.35, 0.52, 7.66),
              {"any": wr("sign", 0.6), "+x": rect("sign", 1.44, 0.54)})
    for sx in (-1, 1):
        box("hazard", (sx * X - 0.27, -5.20, 1.10), (sx * X + 0.27, -5.14, 1.40), wr("hazard", 0.45))
        box("hazard", (sx * X - 0.31, -5.75, 7.02), (sx * X + 0.31, -5.70, 7.34), wr("hazard", 0.45))
    box("hazard", (-2.70, 4.92, 7.02), (2.70, 4.96, 7.34), wr("hazard", 0.55))


def decals_lod2():
    box("sign", (-0.72, 4.24, 7.10), (0.72, 4.30, 7.70), wr("sign", 0.6))
    box("sign", (3.30, -0.92, 7.12), (3.35, 0.52, 7.66), wr("sign", 0.6))
    box("hazard", (-2.70, 4.92, 7.02), (2.70, 4.96, 7.34), wr("hazard", 0.6))


def build_lod1():
    PARTS.clear()
    for sx in (-1, 1):
        bx0, bx1 = sx * X - BEAM_X0, sx * X + BEAM_X0
        box("paint", (bx0, -5.25, TOP_Z0), (bx1, 5.25, TOP_Z1), wr("paint", 1.25))
        nose = [(-5.25, TOP_Z0), (-5.74, TOP_Z0), (-5.74, TOP_Z0 + 0.36),
                (-5.55, TOP_Z0 + 0.62), (-5.25, TOP_Z1)]
        part("paint").prism(nose, "x", bx0, bx1, wr("paint", 1.0))
        for sy in (-1, 1):
            y = sy * LEG_Y
            box("paint", (sx * X - 0.35, y - 0.40, LEG_Z0), (sx * X + 0.35, y + 0.40, LEG_Z1), wr("paint", 1.1))
            box("paint", (sx * X - 0.42, y - 0.46, LEG_Z0 - 0.08), (sx * X + 0.42, y + 0.46, LEG_Z0 + 0.38),
                wr("paint", 0.8))
            box("paint", (sx * X - 0.28, y - 0.28, TOP_Z0 - 0.80), (sx * X + 0.28, y + 0.28, TOP_Z0),
                wr("paint", 0.8))
        box("paint", (sx * X - 0.20, -4.95, 1.24), (sx * X + 0.20, 4.95, 1.76), wr("paint", 0.9))
        box("paint", (sx * X - 0.26, -5.18, 1.02), (sx * X + 0.26, -4.92, 1.42), wr("paint", 0.7))
        beam("paint", (sx * X, -LEG_Y + 0.30, 2.05), (sx * X, LEG_Y - 0.30, 6.35), 0.20, 0.24, wr("paint", 1.0))
        beam("paint", (sx * X, LEG_Y - 0.30, 2.05), (sx * X, -LEG_Y + 0.30, 6.35), 0.20, 0.24, wr("paint", 1.0))
        box("steel", (bx0 + 0.04, -5.04, TOP_Z1), (bx1 - 0.04, 5.04, TOP_Z1 + 0.06), wr("steel", 0.7))
        for y in (-4.3, 0.0, 4.3):
            beam("white", (sx * (X + 0.30), y, TOP_Z1 + 0.05), (sx * (X + 0.30), y, 9.00), 0.06, 0.06,
                 wr("white", 0.5))
        beam("white", (sx * (X + 0.30), -4.6, 8.96), (sx * (X + 0.30), 4.6, 8.96), 0.055, 0.055, wr("white", 0.5))
        wheel_lod1(sx, -1)
        wheel_lod1(sx, 1)
        for y in WINCH_Y:
            winch_lod1(sx, y)
    box("paint", (-X - 0.35, 4.30, TOP_Z0), (X + 0.35, 4.92, TOP_Z1), wr("paint", 1.2))
    box("paint", (-X + 0.10, 4.34, 4.62), (X - 0.10, 4.88, 4.98), wr("paint", 1.0))
    for x in (-1.8, 0.0, 1.8):
        beam("white", (x, 4.68, TOP_Z1), (x, 4.68, 9.00), 0.06, 0.06, wr("white", 0.5))
    for sx in (-1, 1):
        sling_lod1(sx, -2.25, "blue")
        sling_lod1(sx, 2.25, "orange")
    cab_lod1()
    engine_lod1()
    ladders_lod1()
    decals_lod1()
    meshes = []
    for key, label, bw in (("paint", "Frame", 0.0), ("white", "Trim", 0.0), ("steel", "Steel", 0.0),
                           ("rubber", "Rubber", 0.0), ("blue", "SlingBlue", 0.0),
                           ("orange", "SlingOrange", 0.0), ("glass", "Glass", 0.0), ("hazard", "Hazard", 0.0),
                           ("sign", "Sign", 0.0)):
        e = emit(key, label, key, bevel=bw, lod=1)
        if e:
            meshes.append(e)
    return meshes


def build_lod2():
    PARTS.clear()
    for sx in (-1, 1):
        bx0, bx1 = sx * X - BEAM_X0, sx * X + BEAM_X0
        box("paint", (bx0, -5.25, TOP_Z0), (bx1, 5.25, TOP_Z1), wr("paint", 1.5))
        for sy in (-1, 1):
            y = sy * LEG_Y
            box("paint", (sx * X - 0.35, y - 0.40, LEG_Z0), (sx * X + 0.35, y + 0.40, LEG_Z1), wr("paint", 1.4))
        box("paint", (sx * X - 0.20, -4.95, 1.24), (sx * X + 0.20, 4.95, 1.76), wr("paint", 1.2))
        box("steel", (bx0 + 0.04, -5.04, TOP_Z1), (bx1 - 0.04, 5.04, TOP_Z1 + 0.06), wr("steel", 0.9))
        wheel_lod2(sx, -1)
        wheel_lod2(sx, 1)
        for y in WINCH_Y:
            winch_lod2(sx, y)
    box("paint", (-X - 0.35, 4.30, TOP_Z0), (X + 0.35, 4.92, TOP_Z1), wr("paint", 1.4))
    for sx in (-1, 1):
        sling_lod2(sx, -2.25, "blue")
        sling_lod2(sx, 2.25, "orange")
    cab_lod2()
    engine_lod2()
    ladders_lod2()
    decals_lod2()
    meshes = []
    for key, label in (("paint", "Frame"), ("white", "Trim"), ("steel", "Steel"),
                       ("rubber", "Rubber"), ("blue", "SlingBlue"), ("orange", "SlingOrange"),
                       ("glass", "Glass"), ("hazard", "Hazard"), ("sign", "Sign")):
        e = emit(key, label, key, lod=2)
        if e:
            meshes.append(e)
    return meshes


def build():
    for sx in (-1, 1):
        side_frame(sx)
        for sy in (-1, 1):
            wheel(sx, sy)
        for y in WINCH_Y:
            winch(sx, y)
    rear_frame()
    # slings: blue forward pair, orange aft pair
    for sx in (-1, 1):
        sling(sx, -2.25, "blue")
        sling(sx, 2.25, "orange")
    cab()
    engine()
    rear_ladder()
    cab_ladder()
    decals()

    meshes = []
    for k, lb in (("fender", "Fender"), ("brace", "Brace")):
        e = emit(k, lb, "paint", bevel=0.0)
        if e:
            meshes.append(e)
    for key, label, bw, segs in (
            ("paint", "Frame", 0.018, 1),
            ("white", "Trim", 0.0, 1),
            ("steel", "Steel", 0.0, 1),
            ("rubber", "Rubber", 0.0, 1),
            ("blue", "SlingBlue", 0.0, 1),
            ("orange", "SlingOrange", 0.0, 1),
            ("glass", "Glass", 0.0, 1),
            ("hazard", "Hazard", 0.0, 1),
            ("sign", "Sign", 0.0, 1)):
        e = emit(key, label, key, bevel=bw, segments=segs)
        if e:
            meshes.append(e)
    meshes += build_lod1()
    meshes += build_lod2()
    meshes.append({"object": collision()})

    tiles = [("paint", "Frame"), ("fender", "Fender"), ("brace", "Brace"), ("white", "Trim"), ("steel", "Steel"),
             ("rubber", "Rubber"), ("blue", "SlingBlue"), ("orange", "SlingOrange"),
             ("glass", "Glass"), ("hazard", "Hazard"), ("sign", "Sign")]
    for key, label in tiles:
        p = PARTS.get(key)
        if p:
            print("[TH] %-10s LOD0 %5d tris" % (label, p.tris(0)))
    col = next(e["object"] for e in meshes if e["object"].name.endswith("_COL"))
    print("[TH] COL %d tris" % sum(len(p.vertices) - 2 for p in col.data.polygons))
    tot = {}
    for e in meshes:
        o = e["object"]
        for sfx in ("_LOD0", "_LOD1", "_LOD2", "_COL"):
            if o.name.endswith(sfx):
                tot[sfx] = tot.get(sfx, 0) + sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("[TH] totals " + ", ".join("%s %d" % (k[1:], v) for k, v in sorted(tot.items())))

    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 15000,
        "tier": "hero",
        "dims_m": (8.18, 11.65, 9.03),
        "size_note": "8.2 m over the tyres, cab steps and fenders, 11.65 m long, 9.03 m to the top rail / exhaust cap (docs/12 row: about 8 m wide, 9 m tall)",
        "origin": "base",
        "atlas": "Yard",
        "bake_size": 2048,
        "bake_samples": 8,
        "sets": [{"name": "TravelHoist", "set": "Yard", "size": 2048, "wet": True,
                  "base_color": "#2c5875",
                  "metal": 0.0,
                  "roughness": 0.6,
                  "slots": {
                      "MI_Hoist_PaintBlue": {"base_color": "#2c5875", "metal": 0.0, "roughness": 0.56},
                      "MI_Hoist_PaintWhite": {"base_color": "#d7d4c8", "metal": 0.0, "roughness": 0.62},
                      "MI_Hoist_Steel": {"base_color": "#969b9e", "metal": 0.0, "roughness": 0.46},
                      "MI_Hoist_Rubber": {"base_color": "#2a2c2d", "metal": 0.0, "roughness": 0.84},
                      "MI_Hoist_FabricBlue": {"base_color": "#2e5c88", "metal": 0.0, "roughness": 0.90},
                      "MI_Hoist_FabricOrange": {"base_color": "#c0601e", "metal": 0.0, "roughness": 0.90},
                      "MI_Hoist_Glass": {"base_color": "#334147", "metal": 0.0, "roughness": 0.10},
                      "MI_Hoist_Hazard": {"base_color": "#c49a1e", "metal": 0.0, "roughness": 0.58},
                      "MI_Hoist_Sign": {"base_color": "#e2ded2", "metal": 0.0, "roughness": 0.48},
                  },
                  "wear": {"edge": 0.5, "edge_range": (0.55, 0.86), "edge_color": "#9ba0a0",
                           "edge_rough": 0.42, "edge_metal": 0.25,
                           "salt": 0.30, "salt_range": (0.34, 0.78), "salt_color": "#b8b8ae",
                           "rust": 0.55, "rust_color": "#523322", "rust_rough": 0.86,
                           "rust_length": 0.5, "rust_fingers": 13, "ao_strength": 0.38}}],
        "waivers": {
            "texture sets": "docs/12 row: one shared yard atlas for the boatyard group, not the class's 4-5 sets",
            "LOD UV layout": "hand-built LOD1/LOD2 for the many shells: same atlas regions, small detail faces dropped",
        },
        "meshes": meshes,
        "attachments": attachments(),
        "closeups": [
            {"name": "sign_35t", "target": (0.0, 12.7, 22.2), "dist": 13, "az": 5, "el": 8},
            {"name": "winch_sling", "target": (8.1, -6.75, 16.8), "dist": 16, "az": 145, "el": 8},
            {"name": "cab", "target": (10.65, 13.8, 12.3), "dist": 16, "az": 48, "el": 12},
            {"name": "wheel", "target": (10.95, 13.65, 2.7), "dist": 14, "az": 55, "el": 10},
            {"name": "engine", "target": (0.0, 15.3, 18.0), "dist": 17, "az": 168, "el": 12},
        ],
    }
