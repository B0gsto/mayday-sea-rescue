"""M_Veh_ATV geometry: invented beach-lifeguard utility quad (420 to 700 cc class) and its towed casualty sled.

Model frame in studs, 3 per metre: X across, Y rearwards (front bumper at Y 0), Z up (ground 0). The quad is
2.10 x 1.20 x 1.14 m; the rescue board overhangs the rear rack and the sled sits in its towed position behind, so the
combined rig is about 4.7 m long. Wheels and seat follow LandVehicleConfig.BeachATV / src/shared/Car/Builder.luau:
1.29 m wheelbase, 0.95 m track, 0.32 m wheel radius, 0.25 m wheel, seat at the saddle.

Built twice from the same functions: LOD0 (Geo hi False, chamfer bevels, low segments) and _HP (named materials,
finer bevels and fasteners for the bake). Sets: Body (moulded red / yellow panels, seat, lamps, decals) and Gear
(wheels, chassis, racks, board, tubes, sled).
"""
import math

from mathutils import Vector, Matrix

import atvgeo as V

STUDS_M = 3.0
L = 6.30
W = 3.60
AX_F = 1.35
AX_R = 5.22
HUB_X = 1.42
WHEEL_R = 0.96
WHEEL_W = 0.72
WHEEL_Z = WHEEL_R
FENDER_X = 1.38
FENDER_R = 1.08
SEAT_Y = 3.55
SEAT_TOP = 2.42
HITCH = (0.0, 6.45, 1.12)
SLED_F = 8.15
SLED_R = 14.20
BOARD_Z = 2.55


def P(*a):
    return Vector(a)


def loft_y(g, stations, mat, seg=20, cap0=True, cap1=True, matfn=None):
    rings = []
    for y, cx, cz, hx, hz, p in stations:
        ring = []
        for j in range(seg):
            t = 2 * math.pi * j / seg
            c, s = math.cos(t), math.sin(t)
            x = cx + hx * math.copysign(abs(c) ** (2.0 / p), c)
            z = cz + hz * math.copysign(abs(s) ** (2.0 / p), s)
            ring.append(P(x, y, z))
        rings.append(ring)
    return g.rings(rings, mat, closed=True, cap0=cap0, cap1=cap1, matfn=matfn)


def fender(g, side, cy, a0, a1, mat="PaintRed"):
    n = 17 if g.hi else 8
    pts = []
    for k in range(n):
        a = math.radians(a0 + (a1 - a0) * k / (n - 1))
        pts.append(P(side * FENDER_X, cy + FENDER_R * math.sin(a), WHEEL_Z + FENDER_R * math.cos(a)))
    hw = 0.42
    prof = [(-hw, -0.10), (-hw + 0.05, 0.01), (-0.25, 0.07), (0.0, 0.10),
            (0.25, 0.07), (hw - 0.05, 0.01), (hw, -0.10), (hw - 0.06, -0.16), (-hw + 0.06, -0.16)]
    V.sweep(g, pts, prof, mat, closed=True, cap0=True, cap1=True)
    # yellow moulded stripe along the crown of the guard
    ns = 12 if g.hi else 8
    sp = [P(side * FENDER_X, cy + (FENDER_R + 0.104) * math.sin(math.radians(a0 + (a1 - a0) * k / ns)),
            WHEEL_Z + (FENDER_R + 0.104) * math.cos(math.radians(a0 + (a1 - a0) * k / ns))) for k in range(ns + 1)]
    V.sweep(g, sp, [(-0.12, 0.0), (-0.12, 0.016), (0.12, 0.016), (0.12, 0.0)],
            "PaintYellow", closed=True, cap0=True, cap1=True)


def footboards(g):
    for side in (-1, 1):
        V.box(g, (side * 0.86, 3.62, 0.80), (0.54, 2.30, 0.09), "BlackPlastic", bev=0.03)
        V.box(g, (side * 1.10, 3.62, 0.90), (0.08, 2.30, 0.24), "ArchPlastic", bev=0.04)
        V.box(g, (side * 0.92, 4.80, 1.02), (0.48, 0.10, 0.42), "ArchPlastic", bev=0.04)
        for k in range(3):
            V.box(g, (side * 0.86, 2.90 + 0.62 * k, 0.855), (0.46, 0.06, 0.025), "Rubber", bev=0.006)
        if g.hi:
            V.box(g, (side * 1.13, 3.62, 0.92), (0.015, 1.9, 0.05), "BlackMetal")


def body(g):
    stations = [
        (0.98, 0, 1.26, 0.40, 0.19, 2.5),
        (1.16, 0, 1.30, 0.58, 0.25, 2.6),
        (1.55, 0, 1.36, 0.74, 0.32, 2.7),
        (2.02, 0, 1.44, 0.82, 0.39, 2.8),
        (2.50, 0, 1.54, 0.86, 0.48, 2.8),
        (3.05, 0, 1.56, 0.82, 0.48, 2.8),
        (3.62, 0, 1.50, 0.70, 0.42, 2.8),
        (4.32, 0, 1.46, 0.69, 0.41, 2.8),
        (5.02, 0, 1.43, 0.76, 0.41, 2.8),
        (5.58, 0, 1.38, 0.74, 0.35, 2.7),
        (6.02, 0, 1.30, 0.57, 0.25, 2.6),
        (6.22, 0, 1.24, 0.39, 0.14, 2.5),
    ]
    seg = 26 if g.hi else 12

    def bm(i, j):
        if 4 <= i <= 6 and abs((j - seg // 4 + seg // 2) % seg - seg // 2) <= 1:
            return "PaintYellow"
        return "PaintRed"

    loft_y(g, stations, "PaintRed", seg=seg, matfn=bm)
    for side in (-1, 1):
        # moulded rub strip and side accent along the tank shoulder
        V.box(g, (side * 0.865, 2.38, 1.50), (0.025, 1.35, 0.16), "PaintYellow", bev=0.012)
        V.box(g, (side * 0.862, 2.38, 1.60), (0.018, 1.35, 0.03), "BumperPlastic", bev=0.004)
        # seat rail / side panel seam
        V.box(g, (side * 0.70, 3.55, 1.32), (0.03, 1.6, 0.05), "BlackPlastic", bev=0.006)
    # fuel cap, filler neck, breather
    V.lathe(g, (0.30, 2.25, 2.015), (0, 0, 1), [(0.0, 0.0), (0.15, 0.0), (0.15, 0.035), (0.11, 0.055), (0.0, 0.06)],
            14 if g.hi else 10, "BlackPlastic")
    V.tube(g, [(0.30, 2.25, 2.02), (0.30, 2.25, 2.08), (0.44, 2.30, 2.10)], 0.035, "Rubber", 8 if g.hi else 6)
    # saddle
    seat = [
        (2.82, 0, 2.29, 0.30, 0.10, 2.2),
        (3.02, 0, 2.32, 0.48, 0.13, 2.4),
        (3.55, 0, 2.34, 0.55, 0.14, 2.6),
        (4.12, 0, 2.34, 0.53, 0.14, 2.5),
        (4.52, 0, 2.40, 0.44, 0.15, 2.3),
        (4.70, 0, 2.36, 0.30, 0.10, 2.1),
    ]
    loft_y(g, seat, "SeatFabric", seg=18 if g.hi else 8)
    for side in (-1, 1):
        V.tube(g, [(side * 0.50, 3.05, 2.36), (side * 0.54, 3.6, 2.38), (side * 0.51, 4.15, 2.37),
                   (side * 0.41, 4.52, 2.44)], 0.022, "PaintYellow", 7 if g.hi else 5, fillet=0.12)
    # rear tail panel and lamp pods
    V.box(g, (0, 6.20, 1.34), (0.86, 0.06, 0.34), "PaintRed", bev=0.03)
    for side in (-1, 1):
        V.box(g, (side * 0.60, 6.19, 1.62), (0.30, 0.06, 0.20), "BlackPlastic", bev=0.02)
        V.lathe(g, (side * 0.60, 6.235, 1.62), (0, 1, 0),
                [(0.0, 0.0), (0.105, 0.0), (0.105, 0.012), (0.075, 0.02), (0.0, 0.022)],
                12 if g.hi else 8, "LensRed")
        V.lathe(g, (side * 0.60, 6.24, 1.62), (0, 1, 0), [(0.0, 0.0), (0.13, 0.0), (0.13, 0.008)],
                12 if g.hi else 8, "BlackPlastic")
    # front nose panel and lamp pods
    V.box(g, (0, 1.00, 1.38), (0.78, 0.06, 0.30), "PaintRed", bev=0.03)
    for side in (-1, 1):
        V.box(g, (side * 0.56, 1.02, 1.70), (0.36, 0.20, 0.26), "BlackPlastic", bev=0.04)
        V.lathe(g, (side * 0.56, 0.935, 1.70), (0, -1, 0),
                [(0.0, 0.0), (0.145, 0.0), (0.155, -0.018), (0.11, -0.035), (0.0, -0.04)],
                16 if g.hi else 10, "LensWhite")
        V.lathe(g, (side * 0.56, 0.94, 1.70), (0, -1, 0), [(0.0, 0.0), (0.175, 0.0), (0.175, 0.012)],
                16 if g.hi else 10, "BlackPlastic")
    for k in range(4):
        V.box(g, (0, 0.985, 1.31 + 0.085 * k), (0.42, 0.035, 0.036), "BlackPlastic", bev=0.006)
    # nose tow loop / bumper
    V.tube(g, [(-0.72, 1.02, 1.02), (-0.76, 0.82, 1.09), (0.76, 0.82, 1.09), (0.72, 1.02, 1.02)],
           0.048, "BlackMetal", 9 if g.hi else 7, fillet=0.12)
    # rear mud flaps
    for side in (-1, 1):
        V.box(g, (side * 1.36, 6.20, 0.84), (0.66, 0.05, 0.62), "Rubber", bev=0.03)
    # tail text
    text_panel(g, "RESCUE", 0.10, P(0, 6.235, 1.34), P(0, 1, 0), "LetterWhite")


def text_panel(g, body, size, origin, normal, mat, sx=1.0):
    me = V.text_mesh(body, size, font_scale_x=sx, resolution=2)
    n = Vector(normal).normalized()
    if abs(n.x) > 0.5:
        side = 1 if n.x > 0 else -1
        mp = lambda co: origin + P(0, side * co.x, co.y)
    else:
        sgn = -1 if n.y > 0 else 1
        mp = lambda co: origin + P(sgn * co.x, 0, co.y)
    fs = g.add_mesh(me, mat, mp)
    g.orient(fs, lambda c: n)
    import bpy
    bpy.data.meshes.remove(me)


def body_detail(g):
    # handlebar guards (red plastic with yellow edge) and small mirrors
    for side in (-1, 1):
        rot = Matrix.Rotation(math.radians(side * 16), 3, "Y") @ Matrix.Rotation(math.radians(9), 3, "X")
        V.box(g, (side * 0.78, 1.69, 3.26), (0.40, 0.34, 0.035), "PaintRed", rot=rot, bev=0.02)
        V.box(g, (side * 0.78, 1.55, 3.27), (0.40, 0.035, 0.05), "PaintYellow", rot=rot, bev=0.008)
        V.tube(g, [(side * 0.80, 1.78, 3.18), (side * 0.72, 1.70, 3.29)], 0.022, "BlackMetal", 6)
    # handlebar pad
    V.box(g, (0, 1.82, 3.17), (0.52, 0.16, 0.10), "BlackPlastic", bev=0.03)
    V.box(g, (0, 1.74, 3.26), (0.30, 0.16, 0.10), "BlackPlastic", bev=0.03)
    # side decals
    for side in (-1, 1):
        text_panel(g, "LIFEGUARD", 0.125, P(side * 0.885, 2.32, 1.66), P(side, 0, 0), "LetterWhite", sx=1.0)

    # front rack number plate
    V.box(g, (0, 0.455, 2.12), (0.44, 0.035, 0.20), "PlateWhite", bev=0.02)
    text_panel(g, "1", 0.14, P(0, 0.435, 2.12), P(0, -1, 0), "PlateLetter")



def wheels_body(g):
    pass


def tyre(g, cx, side):
    prof = [(0.47, 0.33), (0.62, 0.36), (0.78, 0.37), (0.88, 0.36), (0.945, 0.31), (0.965, 0.22),
            (0.965, -0.22), (0.945, -0.31), (0.88, -0.36), (0.78, -0.37), (0.62, -0.36), (0.47, -0.33)]
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0), [(r, h * side) for r, h in prof],
            18 if g.hi else 14, "Tyre")
    n = 15 if g.hi else 8
    for row, xoff in ((0, -0.185), (1, 0.185)):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * row) / n
            rot = Matrix.Rotation(-a, 3, "X")
            c = (cx + xoff * side, 0.945 * math.sin(a), WHEEL_Z + 0.945 * math.cos(a))
            V.box(g, c, (0.26, 0.24, 0.10), "Tyre", rot=rot, bev=0.0)
    # steel rim, five lightening holes, hub and lug nuts
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0),
            [(0.0, 0.30 * side), (0.18, 0.30 * side), (0.20, 0.325 * side), (0.43, 0.325 * side),
             (0.50, 0.30 * side), (0.50, 0.20 * side), (0.46, 0.12 * side), (0.47, -0.30 * side),
             (0.35, -0.33 * side), (0.0, -0.33 * side)],
            16 if g.hi else 10, "SteelWorn")
    face = cx + side * 0.29
    for k in range(5):
        a = math.radians(72 * k + 36)
        if g.hi:
            V.lathe(g, (face, 0.275 * math.sin(a), WHEEL_Z + 0.275 * math.cos(a)), (side, 0, 0),
                    [(0.13, 0.032), (0.115, 0.040), (0.115, 0.044), (0.085, 0.048), (0.0, 0.048)],
                    10, "SledWhite")
        else:
            V.lathe(g, (face, 0.275 * math.sin(a), WHEEL_Z + 0.275 * math.cos(a)), (side, 0, 0),
                    [(0.115, 0.038), (0.0, 0.041)], 10, "RimDark")
    V.lathe(g, (face, 0, WHEEL_Z), (side, 0, 0),
            [(0.0, 0.0), (0.17, 0.0), (0.17, 0.03), (0.13, 0.05), (0.0, 0.055)],
            14 if g.hi else 8, "RimSilver")
    for k in range(5):
        a = math.radians(72 * k)
        V.lathe(g, (face, 0.11 * math.sin(a), WHEEL_Z + 0.11 * math.cos(a)), (side, 0, 0),
                [(0.042, 0.035), (0.042, 0.055), (0.0, 0.06)], 6, "Chrome")
    V.tube(g, [(face, 0.0, WHEEL_Z + 0.20), (face, 0.0, WHEEL_Z + 0.29)], 0.022, "BlackPlastic", 6)


def wheel(g, side, front):
    cx = side * HUB_X
    cy = AX_F if front else AX_R
    start = len(g.bm.verts)
    tyre(g, 0.0, side)
    g.bm.verts.ensure_lookup_table()
    for v in g.bm.verts[start:]:
        v.co = P(v.co.x + cx, v.co.y + cy, v.co.z)


def spring(g, base, axis, length, r, turns=4, wire=0.035, n=10):
    axis = Vector(axis).normalized()
    if not g.hi:
        n, turns = 5, max(2, turns - 2)
    ref = Vector((0, 1, 0)) if abs(axis.z) > 0.8 else Vector((0, 0, 1))
    u = axis.cross(ref).normalized()
    w = axis.cross(u).normalized()
    pts = []
    for k in range(turns * n + 1):
        t = k / (turns * n)
        a = 2 * math.pi * turns * t
        pts.append(Vector(base) + axis * (length * t) + (u * math.cos(a) + w * math.sin(a)) * r)
    V.sweep(g, pts, V.circle_profile(wire, 6 if g.hi else 4), "BrakeSteel", closed=True, cap0=True, cap1=True)


def chassis(g):
    # main frame rails, cross members and skid plate
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.44, 1.25, 0.78), (sx * 0.44, 3.55, 0.72), (sx * 0.48, 4.35, 0.80),
                   (sx * 0.48, 5.65, 0.86)], 0.085, "BlackMetal", 10 if g.hi else 8, fillet=0.18)
        V.tube(g, [(sx * 0.44, 2.10, 1.30), (sx * 0.44, 3.35, 1.78), (sx * 0.40, 4.62, 1.66)],
               0.065, "BlackMetal", 9 if g.hi else 7, fillet=0.20)
    for y in (1.50, 2.85, 5.20):
        V.tube(g, [(-0.50, y, 0.80), (0.50, y, 0.80)], 0.06, "BlackMetal", 8 if g.hi else 6)
    V.box(g, (0, 1.62, 0.66), (0.94, 0.92, 0.06), "Aluminium", bev=0.03)
    V.box(g, (0, 3.55, 0.64), (1.00, 1.65, 0.05), "Aluminium", bev=0.03)
    # engine: cases, cylinder with fins, CVT cover, intake and exhaust
    V.box(g, (0, 3.62, 0.98), (0.72, 0.94, 0.50), "BlackMetal", bev=0.06)
    V.lathe(g, (0.10, 2.92, 1.06), (0, -0.25, 1), [(0.0, 0.0), (0.20, 0.02), (0.22, 0.10), (0.22, 0.28),
                                                  (0.17, 0.34), (0.0, 0.36)], 14 if g.hi else 10, "BrakeSteel")
    for k in range(5):
        V.lathe(g, (0.10, 2.87 + 0.028 * k, 1.03), (0, -0.25, 1),
                [(0.24, 0.0), (0.24, 0.022), (0.21, 0.03), (0.0, 0.032)], 12 if g.hi else 9, "BrakeSteel")
    V.lathe(g, (-0.46, 3.62, 0.99), (-1, 0, 0), [(0.0, 0.0), (0.30, 0.02), (0.33, 0.10), (0.30, 0.17),
                                                 (0.0, 0.19)], 18 if g.hi else 8, "BlackMetal")
    V.box(g, (-0.56, 3.95, 1.10), (0.03, 0.42, 0.26), "BlackPlastic", bev=0.02)
    # front suspension: A-arms, coil-overs, discs, steering rods
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.46, AX_F + 0.18, 0.82), (sx * 1.20, AX_F + 0.10, 0.94), (sx * 1.35, AX_F, WHEEL_Z)],
               0.062, "BlackMetal", 9 if g.hi else 7, fillet=0.12)
        V.tube(g, [(sx * 0.46, AX_F - 0.18, 0.82), (sx * 1.18, AX_F - 0.06, 0.94), (sx * 1.35, AX_F, WHEEL_Z)],
               0.062, "BlackMetal", 9 if g.hi else 7, fillet=0.12)
        V.box(g, (sx * 1.36, AX_F, WHEEL_Z), (0.16, 0.26, 0.34), "BlackMetal", bev=0.03)
        spring(g, (sx * 0.95, AX_F + 0.12, 0.86), (sx * 0.16, 0.06, 1), 0.72, 0.14, 4, 0.028, 8)
        V.tube(g, [(sx * 0.96, AX_F + 0.12, 0.82), (sx * 1.15, AX_F + 0.02, 1.56)], 0.045, "BrakeSteel",
               8 if g.hi else 6)
        V.box(g, (sx * 1.12, AX_F + 0.22, 1.08), (0.09, 0.18, 0.22), "BlackPlastic", bev=0.02)
        V.tube(g, [(sx * 0.40, AX_F + 0.10, 1.20), (sx * 1.28, AX_F + 0.12, 1.20)], 0.028, "BrakeSteel",
               7 if g.hi else 5)
    # rear swingarm and shock
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.42, 3.85, 0.82), (sx * 0.95, 4.75, 0.82), (sx * 1.24, AX_R, WHEEL_Z)],
               0.095, "BlackMetal", 10 if g.hi else 8, fillet=0.12)
        V.tube(g, [(sx * 0.42, 3.85, 0.82), (sx * 0.78, 3.95, 0.84)], 0.075, "BlackMetal", 8 if g.hi else 6)
        V.box(g, (sx * 1.30, AX_R, WHEEL_Z), (0.15, 0.24, 0.30), "BlackMetal", bev=0.03)
    spring(g, (0.12, 4.20, 0.86), (0.04, -0.20, 1), 0.74, 0.15, 4, 0.030, 8)
    V.tube(g, [(0.10, 4.20, 0.86), (0.18, 3.95, 1.58)], 0.05, "BrakeSteel", 8 if g.hi else 6)
    # exhaust header, heat shield, muffler
    V.tube(g, [(0.20, 2.78, 0.92), (0.42, 2.45, 1.02), (0.52, 2.35, 1.24), (0.48, 2.70, 1.42)],
           0.075, "Exhaust", 9 if g.hi else 7, fillet=0.15)
    V.tube(g, [(0.48, 2.70, 1.42), (0.48, 3.40, 1.34), (0.55, 4.45, 1.00), (0.55, 5.05, 0.94)],
           0.075, "Exhaust", 9 if g.hi else 7, fillet=0.18)
    V.lathe(g, (0.55, 5.05, 0.94), (0, 1, 0), [(0.0, 0.0), (0.13, 0.03), (0.18, 0.16), (0.18, 0.60),
                                               (0.14, 0.72), (0.10, 0.75)], 12 if g.hi else 9, "Exhaust")
    V.tube(g, [(0.55, 5.73, 0.94), (0.55, 5.98, 0.94), (0.32, 6.12, 0.98)], 0.08, "Exhaust",
           9 if g.hi else 7, fillet=0.10)
    # airbox and fuel tank under the saddle
    V.box(g, (0.0, 3.55, 1.70), (0.64, 1.10, 0.32), "BlackPlastic", bev=0.10)
    # foot pegs, brake and gear levers
    for sx in (-1, 1):
        V.box(g, (sx * 0.96, 4.08, 0.80), (0.22, 0.10, 0.06), "BlackMetal", bev=0.02)
        V.tube(g, [(sx * 0.80, 4.08, 0.80), (sx * 0.98, 4.08, 0.80)], 0.025, "BlackMetal", 6)
    V.tube(g, [(0.62, 2.72, 0.98), (0.78, 2.55, 0.90), (0.86, 2.60, 0.84)], 0.022, "BlackMetal", 6)
    V.tube(g, [(-0.62, 4.20, 0.98), (-0.84, 4.10, 0.92)], 0.022, "BlackMetal", 6)
    # steering column and handlebars
    V.tube(g, [(0.0, 2.30, 1.88), (0.0, 2.10, 2.55), (0.0, 1.92, 3.01)], 0.085, "BlackMetal",
           10 if g.hi else 8, fillet=0.12)
    V.tube(g, [(-0.86, 1.76, 3.13), (-0.55, 1.82, 3.18), (0.0, 1.85, 3.19), (0.55, 1.82, 3.18),
               (0.86, 1.76, 3.13)], 0.048, "BlackMetal", 10 if g.hi else 8, fillet=0.10)
    for sx in (-1, 1):
        V.lathe(g, (sx * 0.86, 1.76, 3.13), (sx, 0, 0), [(0.0, 0.0), (0.065, 0.0), (0.075, 0.03),
                                                        (0.075, 0.22), (0.05, 0.26), (0.0, 0.27)],
                10 if g.hi else 8, "Rubber")
        V.tube(g, [(sx * 0.74, 1.87, 3.17), (sx * 0.80, 1.98, 3.19), (sx * 0.84, 2.02, 3.23)],
               0.018, "Chrome", 6, fillet=0.04)
    # instrument pod and key
    V.box(g, (0.0, 1.98, 3.09), (0.26, 0.16, 0.12), "BlackPlastic", bev=0.03)
    V.box(g, (0.0, 1.90, 3.09), (0.20, 0.02, 0.08), "Screen", bev=0.01)
    # tow hitch: plate, ball and safety loops
    V.box(g, (0.0, 6.24, 1.18), (0.42, 0.16, 0.08), "BlackMetal", bev=0.02)
    V.tube(g, [(0.0, 6.30, 1.05), (0.0, 6.40, 1.12)], 0.055, "Chrome", 8 if g.hi else 6)
    V.lathe(g, (0.0, 6.40, 1.12), (0, 0, 1), [(0.0, 0.0), (0.10, 0.0), (0.11, 0.05), (0.07, 0.09), (0.0, 0.10)],
            12 if g.hi else 9, "Chrome")
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.26, 6.28, 1.10), (sx * 0.26, 6.36, 1.10), (sx * 0.26, 6.36, 1.02)],
               0.022, "SteelWorn", 6)


def rack_frame(g, cy, hx, hy, z):
    y0, y1 = cy - hy, cy + hy
    for sx in (-1, 1):
        V.tube(g, [(sx * hx, y0, z), (sx * hx, y1, z)], 0.045, "BlackMetal", 8 if g.hi else 6)
    for y in (y0, y1):
        V.tube(g, [(-hx, y, z), (hx, y, z)], 0.045, "BlackMetal", 8 if g.hi else 6)
    n = 5
    for k in range(n):
        y = y0 + (y1 - y0) * (k + 0.5) / n
        V.box(g, (0, y, z), (2 * hx - 0.08, 0.055, 0.032), "BlackMetal", bev=0.012)
    for sx in (-1, 1):
        for y in (y0 + 0.12, y1 - 0.12):
            V.tube(g, [(sx * (hx - 0.05), y, z), (sx * (hx - 0.10), y, z - 0.34)], 0.038, "BlackMetal",
                   7 if g.hi else 5)
            V.box(g, (sx * (hx - 0.06), y, z - 0.30), (0.12, 0.16, 0.05), "BlackMetal", bev=0.012)
    if g.hi:
        for sx in (-1, 1):
            for y in (y0 + 0.12, y1 - 0.12):
                V.lathe(g, (sx * hx, y, z), (0, 0, 1), [(0.0, 0.0), (0.03, 0.0), (0.03, 0.02)],
                        6, "BlackMetal")


def rack(g):
    rack_frame(g, 0.98, 0.80, 0.48, 1.92)
    rack_frame(g, 5.28, 0.86, 0.66, 2.10)
    # raised board platform behind the saddle
    for sx in (-1, 1):
        for y in (4.66, 5.98):
            V.tube(g, [(sx * 0.82, y, 2.10), (sx * 0.80, y, 2.42)], 0.032, "BlackMetal", 7 if g.hi else 5)
    for y in (4.72, 5.94):
        V.tube(g, [(-0.80, y, 2.42), (0.80, y, 2.42)], 0.032, "BlackMetal", 7 if g.hi else 5)
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.80, 4.70, 2.42), (sx * 0.80, 5.96, 2.42)], 0.032, "BlackMetal", 7 if g.hi else 5)
    # two red rescue tubes across the front rack
    for y, z in ((0.76, 2.06), (1.24, 2.06)):
        V.lathe(g, (0.0, y, z), (1, 0, 0), [(0.0, -1.30), (0.10, -1.26), (0.185, -1.10), (0.185, 1.10),
                                           (0.10, 1.26), (0.0, 1.30)], 14 if g.hi else 12, "TubeRed")
        V.tube(g, [(0.0, y + 0.16, z), (0.0, y + 0.16, z + 0.16), (0.0, y - 0.14, z + 0.16),
                   (0.0, y - 0.14, z)], 0.024, "RopeWhite", 6, fillet=0.04)
        for sx in (-0.55, 0.55):
            V.box(g, (sx, y, z + 0.16), (0.10, 0.06, 0.36), "Webbing", bev=0.01)
    # rescue board on the raised rear platform
    ys = [4.18, 4.42, 4.72, 5.10, 5.55, 6.02, 6.42, 6.80, 7.12, 7.42, 7.72, 7.98]
    st = []
    for y in ys:
        t = (y - ys[0]) / (ys[-1] - ys[0])
        hw = 0.86 * (1 - 0.10 * max(0.0, (t - 0.78) / 0.22) ** 2)
        if t < 0.12:
            hw = 0.52 + (0.86 - 0.52) * (t / 0.12)
        zc = BOARD_Z + 0.06 * (1 - t) ** 2
        st.append((y, 0, zc, hw, 0.085 - 0.02 * (1 - t) ** 2, 2.6))
    loft_y(g, st, "BoardYellow", seg=20 if g.hi else 16)
    # red rails and nose flash
    for sx in (-1, 1):
        V.box(g, (sx * 0.72, 6.2, BOARD_Z + 0.055), (0.10, 3.3, 0.08), "BoardRed", bev=0.03)
    V.box(g, (0, 7.83, BOARD_Z + 0.035), (0.92, 0.30, 0.10), "BoardRed", bev=0.04)
    V.box(g, (0, 4.32, BOARD_Z + 0.035), (0.90, 0.24, 0.10), "BoardRed", bev=0.04)
    # board straps and leash
    for y in (5.05, 6.55):
        V.box(g, (0, y, BOARD_Z + 0.125), (1.66, 0.15, 0.035), "Webbing", bev=0.006)
        V.box(g, (0.64, y, BOARD_Z + 0.12), (0.14, 0.10, 0.10), "BlackPlastic", bev=0.012)
    V.tube(g, [(0.72, 7.82, BOARD_Z + 0.05), (1.10, 7.94, BOARD_Z - 0.15), (1.22, 7.72, 2.16)],
           0.026, "Webbing", 7 if g.hi else 5, fillet=0.16)
    # bungee cords and corner gussets
    for y in (5.25, 6.30):
        V.tube(g, [(-0.74, y, BOARD_Z + 0.135), (0.0, y, BOARD_Z + 0.155), (0.74, y, BOARD_Z + 0.135)],
               0.018, "RopeWhite", 6, fillet=0.15)
    for sx in (-1, 1):
        for y in (4.66, 5.94):
            V.box(g, (sx * 0.80, y, 2.18), (0.10, 0.14, 0.10), "BlackMetal", bev=0.02)
    # rack tie-down loops and tail reflector
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.80, 5.95, 2.10), (sx * 0.80, 5.98, 2.02)], 0.022, "SteelWorn", 6)


def sled(g):
    st = [
        (SLED_F, 0, 0.92, 0.24, 0.24, 2.4),
        (SLED_F + 0.26, 0, 0.89, 0.55, 0.35, 2.7),
        (SLED_F + 0.72, 0, 0.86, 0.92, 0.43, 2.8),
        (SLED_F + 1.55, 0, 0.86, 1.03, 0.46, 2.8),
        (SLED_R - 1.45, 0, 0.86, 1.03, 0.46, 2.8),
        (SLED_R - 0.55, 0, 0.87, 0.97, 0.44, 2.8),
        (SLED_R - 0.15, 0, 0.92, 0.78, 0.38, 2.7),
        (SLED_R, 0, 0.98, 0.50, 0.24, 2.5),
    ]
    loft_y(g, st, "SledRed", seg=20 if g.hi else 9)
    # shallow casualty bed, raised rim and head pad
    V.box(g, (0, 11.20, 1.325), (1.62, 5.10, 0.07), "BedGrey", bev=0.04)
    for sx in (-1, 1):
        V.box(g, (sx * 0.90, 11.20, 1.375), (0.14, 5.30, 0.16), "SledRed", bev=0.05)
    V.box(g, (0, 13.72, 1.38), (1.92, 0.14, 0.16), "SledRed", bev=0.04)
    V.box(g, (0, 8.78, 1.38), (1.70, 0.14, 0.16), "SledRed", bev=0.04)
    V.box(g, (0, 9.55, 1.39), (1.18, 0.55, 0.09), "SledWhite", bev=0.05)
    for k in range(2):
        V.box(g, (0, 10.9 + 1.35 * k, 1.375), (1.72, 0.20, 0.035), "Webbing", bev=0.006)
        V.box(g, (0.58, 10.9 + 0.95 * k, 1.39), (0.15, 0.12, 0.11), "BlackPlastic", bev=0.015)
    # runners with upturned noses
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.62, 7.82, 0.42), (sx * 0.62, 8.03, 0.22), (sx * 0.62, 8.55, 0.16),
                   (sx * 0.62, 13.75, 0.16), (sx * 0.62, 14.10, 0.24), (sx * 0.62, 14.18, 0.34)],
               0.085, "BlackPlastic", 9 if g.hi else 7, fillet=0.24, fseg=5)
        for y in (8.55, 10.25, 12.55):
            V.box(g, (sx * 0.62, y, 0.34), (0.24, 0.10, 0.22), "SledWhite", bev=0.02)
        # grab handles
        for y in (9.25, 12.85):
            V.tube(g, [(sx * 0.98, y - 0.20, 1.22), (sx * 1.12, y - 0.18, 1.34), (sx * 1.12, y + 0.18, 1.34),
                       (sx * 0.98, y + 0.20, 1.22)], 0.042, "SledWhite", 8 if g.hi else 6, fillet=0.08)

        # reflective side flash
        V.box(g, (sx * 1.005, 11.35, 1.23), (0.02, 2.90, 0.10), "PaintYellow", bev=0.004)
    # A-frame drawbar to the quad hitch
    for sx in (-1, 1):
        V.tube(g, [(0, HITCH[1] + 0.06, HITCH[2]), (sx * 0.74, 8.30, 0.92), (sx * 0.86, 8.85, 0.90)],
               0.058, "BlackMetal", 9 if g.hi else 7, fillet=0.18, fseg=5)
    V.tube(g, [(0, HITCH[1] + 0.05, HITCH[2]), (0, 8.10, 0.86), (0, 8.55, 0.84)],
           0.048, "BlackMetal", 8 if g.hi else 6, fillet=0.15)
    V.box(g, (0, HITCH[1] + 0.02, HITCH[2]), (0.20, 0.24, 0.12), "BlackMetal", bev=0.03)
    V.lathe(g, (0, HITCH[1] + 0.02, HITCH[2] + 0.02), (0, 0, 1),
            [(0.0, 0.0), (0.13, 0.0), (0.13, 0.04), (0.09, 0.06), (0.0, 0.07)], 12 if g.hi else 9, "Chrome")
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.60, 8.55, 0.96), (sx * 0.48, 8.20, 1.02)], 0.022, "SteelWorn", 6)
    # tow rope coiled on the nose
    for k in range(1):
        V.lathe(g, (0, 8.36, 1.34 + 0.035 * k), (0, 0, 1),
                [(0.20, 0.0), (0.26, 0.01), (0.28, 0.03), (0.21, 0.045)], 14 if g.hi else 9, "RopeWhite")


def fenders(g):
    for side, cy, a0, a1 in ((1, AX_F, -94, 76), (-1, AX_F, -94, 76),
                             (1, AX_R, -72, 97), (-1, AX_R, -72, 97)):
        fender(g, side, cy, a0, a1)
