"""M_Road_ParkedCar_01 geometry: invented 2010s European 5-door supermini (generic parked hatchback).

Model frame (studs, before recentre): X across (+X kerb side), Y length (front bumper at 0, rear at 12.0), Z up.
4.0 m x 1.75 m x 1.48 m at 3 studs/m. Body panels, glass, trim and bumpers are one Body set; wheels and underbody
are the Wheels set. The same functions build LOD0 (lo) and _HP (hi, finer segments and bake-only details).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix

import cargeo as V

STUDS_M = 3.0
L = 12.0
HX = 2.45
BELT_F = 2.90
BELT_R = 3.18
ROOF = 4.44
ROOF_HX = 1.98
Z_BOT = 0.56
AX_F = 2.35
AX_R = 10.0
HUB_X = 1.95
WHEEL_R = 0.93
WHEEL_W = 0.66
ARCH_R = 1.03
DOOR_F0, DOOR_F1 = 2.62, 5.12
DOOR_R0, DOOR_R1 = 5.38, 8.55


def M(g, name, lo="X"):
    return name if g.hi else lo


def P(x, y, z):
    return Vector((x, y, z))


def sstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def curve(pts, y):
    return V.spline(pts, y)


DECK = [(0.26, 1.62), (0.40, 2.20), (0.60, 2.50), (0.90, 2.70), (1.30, 2.84),
        (1.75, 2.92), (2.20, 2.96), (2.60, 2.99)]
HATCH = [(10.45, 3.10), (10.60, 2.97), (10.85, 2.56), (11.10, 2.08), (11.38, 1.62), (11.55, 1.24)]
CANOPY = [(2.58, 3.01), (2.90, 3.44), (3.25, 3.86), (3.60, 4.18), (3.88, 4.39), (4.20, 4.45),
          (5.0, 4.46), (6.0, 4.45), (7.0, 4.42), (7.9, 4.38), (8.5, 4.33), (8.82, 4.28),
          (9.10, 4.13), (9.45, 3.87), (9.80, 3.58), (10.15, 3.30), (10.38, 3.12)]


def belt(y):
    return BELT_F + (BELT_R - BELT_F) * sstep(3.1, 8.8, y)


def deck_z(y):
    if y <= 2.60:
        return curve(DECK, y)
    if y <= 10.45:
        return belt(y)
    return curve(HATCH, y)


def plan_hw(y):
    if y < 1.35:
        w = 2.05 + 0.40 * sstep(0.26, 1.35, y) ** 0.75
    elif y > 10.2:
        w = 2.45 - 0.45 * sstep(10.2, 11.55, y)
    else:
        w = HX
    for ax in (AX_F, AX_R):
        d = (y - ax) / 0.62
        if abs(d) < 1.0:
            w += 0.032 * (1.0 - d * d)
    return w


def arch_z(y):
    z = Z_BOT
    for hy in (AX_F, AX_R):
        d = abs(y - hy)
        if d < ARCH_R:
            z = max(z, WHEEL_R + math.sqrt(max(0.0, ARCH_R * ARCH_R - d * d)))
        elif d < ARCH_R + 0.22:
            t = (d - ARCH_R) / 0.22
            z = max(z, WHEEL_R * (1 - t) + Z_BOT * t)
    return z


def canopy_top(y):
    return curve(CANOPY, y)


def canopy_wr(y):
    wb = plan_hw(y) - 0.07
    k = sstep(2.6, 4.15, y)
    return (wb - 0.04) * (1 - k) + ROOF_HX * k - 0.20 * sstep(8.9, 10.5, y)


def body_stations():
    ys = [0.26, 0.36, 0.48, 0.62, 0.80, 1.02, 1.30, 1.60, 1.90, 2.20, 2.50, 2.80, 3.15, 3.60,
          5.6, 6.3, 7.0, 8.4, 8.9, 9.9, 10.35, 10.7, 11.0, 11.3, 11.55]
    for hy in (AX_F, AX_R):
        for k in range(9):
            ys.append(hy - 1.12 + 2.24 * k / 8)
    return sorted(set(round(v, 3) for v in ys if 0.24 <= v <= 11.56))


def body_ring(y):
    hw = plan_hw(y)
    zb = arch_z(y)
    top = deck_z(y)
    u = min(belt(y), top)
    right = [
        P(0.0, y, Z_BOT),
        P(1.44, y, Z_BOT),     # arch tunnel: inner wall, roof at zb, outer lip (WheelWell)
        P(1.50, y, max(zb, Z_BOT)),
        P(hw - 0.18, y, max(zb, Z_BOT)),
        P(hw + 0.020, y, zb + 0.30 * (u - zb)),
        P(hw + 0.040, y, zb + 0.50 * (u - zb)),
        P(hw + 0.020, y, zb + 0.64 * (u - zb)),
        P(hw - 0.03, y, u - 0.09),
        P(hw - 0.07, y, u),
        P(hw - 0.16, y, u),
        P(hw - 0.42, y, top),
        P(0.85, y, top + 0.035),
        P(0.0, y, top + 0.045),
    ]
    return right + [P(-p.x, p.y, p.z) for p in reversed(right[1:-1])]


def body_shell(g):
    n = len(body_ring(0.0))
    well = (1, 2, n - 3, n - 2)     # ring segments: tunnel wall and roof, both sides
    V.smooth_loft(g, body_ring, body_stations(), M(g, "PaintBlue"), cap0=True, cap1=True,
                  matfn=lambda i, j: M(g, "WheelWell" if j in well else "PaintBlue"))


_SNAP = {}


def snap(g):
    """The shell and canopy surface exactly as built for this LOD, for flush lamps and grille."""
    if g.hi not in _SNAP:
        _SNAP[g.hi] = V.Snap([(V.refine_rings(body_ring, body_stations(), True, g.hi)[0], True),
                              (V.refine_rings(canopy_ring, CANOPY_YS, False, g.hi)[0], False)], (0, L / 2, 2.4))
    return _SNAP[g.hi]


def wheel_arches(g):
    if not g.hi:     # 1 cm lip: baked into the shell's normal map, no LOD0 tris
        return
    for side in (1, -1):
        for hy in (AX_F, AX_R):
            pts = []
            for k in range(11):
                a = math.radians(-98 + 196 * k / 10)
                yy = hy + (ARCH_R + 0.03) * math.sin(a)
                pts.append(P(side * (plan_hw(yy) - 0.001), yy,
                             WHEEL_R + (ARCH_R + 0.03) * math.cos(a)))
            prof = [(0.0, -0.012), (0.008 * side, -0.014), (0.010 * side, 0.0),
                    (0.008 * side, 0.014), (0.0, 0.016)]
            V.sweep(g, pts, prof, M(g, "PaintBlue"), closed=True, cap0=True, cap1=True)


CANOPY_YS = [2.58, 2.85, 3.15, 3.45, 3.75, 4.05, 4.45, 4.95, 5.06, 5.36, 5.5, 6.1,
             6.7, 7.3, 7.9, 8.35, 8.7, 9.0, 9.35, 9.7, 10.05, 10.38]


def canopy_ring(y):
    b = belt(y)
    r = max(canopy_top(y), b + 0.015)
    wb = plan_hw(y) - 0.07
    wr = canopy_wr(y)
    k = min(1.0, max(0.0, (r - b) / 1.45))
    right = [
        P(wb, y, b),
        P(wb - 0.03, y, b + 0.30 * (r - b)),
        P(wb - 0.10 - 0.06 * k, y, b + 0.62 * (r - b)),
        P(wr + 0.05, y, r - 0.16),
        P(wr, y, r - 0.02),
        P(wr - 0.26, y, r + 0.015),
        P(wr * 0.55, y, r + 0.035),
        P(0.0, y, r + 0.04),
    ]
    return right + [P(-p.x, p.y, p.z) for p in reversed(right[:-1])]


def canopy_mat(i, j):
    ym = 0.5 * (CANOPY_YS[i] + CANOPY_YS[i + 1])
    if j in (0, 1, 2, 11, 12, 13):
        if 3.30 <= ym <= 5.06 or 5.36 <= ym <= 8.45:
            return "Glass"
        if 5.06 < ym < 5.36:
            return "GlassSeal"
        return "PaintBlue"
    if ym <= 3.88 or ym >= 8.90:
        return "Glass"
    return "PaintBlue"


def canopy(g):
    V.smooth_loft(g, canopy_ring, CANOPY_YS, M(g, "PaintBlue"), closed=False,
                  matfn=lambda i, j: M(g, canopy_mat(i, j)))


def body(g):
    body_shell(g)
    wheel_arches(g)
    canopy(g)
    roof_tail(g)
    seams(g)


def roof_tail(g):
    V.box(g, (0, 8.98, 4.33), (3.36, 0.46, 0.11), M(g, "PaintBlue"),
          rot=Matrix.Rotation(math.radians(-7), 3, "X"), bev=0.035)
    V.box(g, (0, 9.20, 4.27), (3.20, 0.13, 0.06), M(g, "BlackPlastic"), bev=0.014)
    V.box(g, (0, 8.30, 4.49), (0.10, 0.34, 0.11), M(g, "PaintBlue"), bev=0.035)


def seams(g):
    for side in (1, -1):
        V.box(g, (side * 2.455, 6.20, 0.88), (0.05, 5.30, 0.20), M(g, "BumperPlastic"), bev=0.03)


def glass(g):
    V.box(g, (0, 2.575, 3.015), (2 * (plan_hw(2.58) - 0.10), 0.10, 0.075), M(g, "GlassSeal"), bev=0.015)
    V.box(g, (0.12, 9.98, 3.42), (1.12, 0.05, 0.05), M(g, "BlackPlastic"),
          rot=Matrix.Rotation(math.radians(-38), 3, "X"), bev=0.01)
    V.box(g, (0, 8.86, 4.335), (0.44, 0.09, 0.05), M(g, "LensRed"), bev=0.01)


# --------------------------------------------------------------------------- interior
def interior(g):
    V.box(g, (0, 5.55, 1.12), (2.84, 6.0, 0.10), M(g, "Carpet"), bev=0.02)
    V.box(g, (0, 3.30, 2.42), (4.34, 0.62, 0.86), M(g, "InteriorDark"), bev=0.07)
    V.box(g, (0, 3.52, 2.88), (4.24, 0.46, 0.10), M(g, "InteriorMid"), bev=0.03)
    # RHD steering wheel
    c = P(-1.20, 3.08, 2.62)
    u = P(0, math.sin(math.radians(-24)), math.cos(math.radians(-24)))
    v = P(1, 0, 0)
    path = [c + u * (0.50 * math.cos(2 * math.pi * k / 20)) + v * (0.50 * math.sin(2 * math.pi * k / 20))
            for k in range(20)] + [c + u * 0.50]
    V.sweep(g, path, V.circle_profile(0.065, 8 if g.hi else 6), M(g, "BlackPlastic"), closed=True)
    V.lathe(g, tuple(c), (0, -math.sin(math.radians(-24)), -math.cos(math.radians(-24))),
            [(0.14, 0.0), (0.14, 0.04), (0.09, 0.07), (0.0, 0.075)], 14 if g.hi else 10, M(g, "InteriorDark"))
    V.box(g, (0.10, 3.30, 2.20), (0.72, 0.30, 0.42), M(g, "InteriorDark"), bev=0.03)
    # front seats
    for sx in (-1, 1):
        x = sx * 1.12
        V.box(g, (x, 4.64, 1.62), (0.94, 0.86, 0.26), M(g, "InteriorDark"), bev=0.04)
        V.box(g, (x, 4.66, 1.86), (0.96, 0.92, 0.22), M(g, "SeatFabric"), bev=0.08)
        V.box(g, (x, 4.96, 2.55), (0.96, 0.20, 1.18), M(g, "SeatFabric"),
              rot=Matrix.Rotation(math.radians(-14), 3, "X"), bev=0.09)
        V.box(g, (x, 5.08, 3.18), (0.56, 0.18, 0.28), M(g, "SeatFabric"), bev=0.07)
    # rear bench, parcel shelf, headliner
    V.box(g, (0, 7.30, 1.76), (3.55, 0.92, 0.24), M(g, "SeatFabric"), bev=0.08)
    V.box(g, (0, 7.63, 2.42), (3.55, 0.18, 1.02), M(g, "SeatFabric"),
          rot=Matrix.Rotation(math.radians(-16), 3, "X"), bev=0.08)
    # centre console
    V.box(g, (0.18, 4.20, 1.58), (0.26, 1.4, 0.48), M(g, "InteriorDark"), bev=0.05)


# --------------------------------------------------------------------------- body detail
def _rprofile(ht, hh, n=10, p=3.2, off=0.0):
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        pts.append((off + ht * math.copysign(abs(c) ** (2 / p), c),
                    hh * math.copysign(abs(s) ** (2 / p), s)))
    return pts


def _head_inner(g, st, depth):
    V.strip_cup(g, st, 0.16, 0.46, 0.10, depth, "Chrome")
    p, n = st.at(0.16, 0.45, depth - 0.006)
    V.lathe(g, tuple(p), tuple(n), [(0.05, 0.0), (0.05, 0.014), (0.03, 0.026), (0.0, 0.03)], 12, "LensDark")
    V.strip_cup(g, st, 0.42, 0.46, 0.11, depth, "Chrome")
    V.strip_patch(g, st, 0.56, 0.80, 0.20, 0.72, depth - 0.012, "Chrome", nr=2)
    V.strip_patch(g, st, 0.82, 0.97, 0.25, 0.70, depth - 0.02, "LensAmber", nr=2)
    V.strip_patch(g, st, 0.04, 0.95, 0.80, 0.91, 0.008, "DRLWhite", nr=1)


def _tail_inner(g, st, depth):
    for r0 in (0.12, 0.36):
        V.strip_patch(g, st, 0.05, 0.95, r0, r0 + 0.09, 0.01, "LensRed", nr=1)
    V.strip_patch(g, st, 0.05, 0.45, 0.64, 0.90, depth - 0.02, "Chrome", nr=1)
    V.strip_patch(g, st, 0.50, 0.68, 0.64, 0.90, depth - 0.02, "TailAmber", nr=1)


def lamps(g):
    sn = snap(g)
    # swept headlamps: lens flush with the nose and wing, reflectors / projector / DRL under it (_HP bake)
    path = [(0.76, 0.440, 0.86), (1.18, 0.475, 1.0), (1.68, 0.585, 1.0), (2.06, 0.790, 0.90), (2.32, 1.070, 0.72),
            (2.44, 1.400, 0.52)]
    for side in (1, -1):
        tops = [P(side * x, y, 2.20 + 0.17 * r) for x, y, r in path]
        bots = [P(side * x, y, 2.20 - 0.15 * r) for x, y, r in path]
        V.flush_lamp(g, V.Strip(sn, tops, bots, 24, toward=(0.0, 2.2)), "LensWhite", _head_inner)
    # rear clusters: flush lens on the hatch wrapping round the corner onto the quarter
    for sx in (-1, 1):
        tops = [P(sx * x, y, z) for x, y, z in ((1.25, 10.72, 2.78), (1.60, 10.72, 2.78), (1.92, 10.70, 2.78),
                                               (2.15, 10.62, 2.80), (2.34, 10.40, 2.84))]
        bots = [P(sx * x, y, z) for x, y, z in ((1.25, 11.17, 1.95), (1.60, 11.17, 1.95), (1.92, 11.12, 2.00),
                                               (2.17, 10.95, 2.20), (2.38, 10.62, 2.48))]
        V.flush_lamp(g, V.Strip(sn, tops, bots, 18, toward=(0.0, 9.0)), "LensRed", _tail_inner, floor="TailRed")
    # hatch shut lines, inboard of the lamps
    for sx in (-1, 1):
        pts = [sn.at(P(sx * 1.20, y, deck_z(y)), -0.006)[0] for y in (10.60, 10.85, 11.10, 11.32)]
        V.sweep(g, pts, V.circle_profile(0.012, 5), M(g, "GlassSeal"), closed=True)
    V.sweep(g, [sn.at(P(x, 11.40, 1.72), -0.006)[0] for x in (-1.20, -0.6, 0.0, 0.6, 1.20)],
            V.circle_profile(0.012, 5), M(g, "GlassSeal"), closed=True)


def bumpers(g):
    front = []
    for k in range(15):
        x = -2.36 + 4.72 * k / 14
        front.append(P(x, 0.30 + 1.05 * (abs(x) / 2.36) ** 2.4, 1.12))
    V.sweep(g, front, _rprofile(0.115, 0.50, 12, 3.6), M(g, "PaintBlue"), closed=True,
            cap0=True, cap1=True)
    V.box(g, (0, 0.115, 0.64), (3.55, 0.12, 0.12), M(g, "BlackPlastic"), bev=0.03)
    V.box(g, (0, 0.150, 1.30), (2.54, 0.06, 0.30), M(g, "GrilleDark"), bev=0.03)
    for k in range(3):
        V.box(g, (0, 0.113, 1.21 + 0.09 * k), (2.36, 0.02, 0.022), M(g, "BlackPlastic"), bev=0.0)
    rear = []
    for k in range(15):
        x = -2.10 + 4.20 * k / 14
        rear.append(P(x, 11.60 - 0.16 * (abs(x) / 2.10) ** 2.0, 1.00))
    V.sweep(g, rear, _rprofile(0.115, 0.40, 12, 3.6), M(g, "PaintBlue"), closed=True,
            cap0=True, cap1=True)
    V.box(g, (0, 11.60, 0.62), (3.55, 0.12, 0.12), M(g, "BlackPlastic"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 0.72, 11.735, 0.84), (0.52, 0.03, 0.07), M(g, "LensRed"), bev=0.01)
    V.tube(g, [(-1.42, 11.53, 0.63), (-1.42, 11.31, 0.63)], 0.075, M(g, "Exhaust"),
           12 if g.hi else 8, caps=True)


def _grille_inner(g, st, depth):
    for k in range(3):
        r0 = 0.12 + 0.28 * k
        V.strip_patch(g, st, 0.02, 0.98, r0, r0 + 0.10, 0.012, "BlackPlastic", nr=1)


def grille(g):
    xs = (-0.67, -0.33, 0.0, 0.33, 0.67)
    st = V.Strip(snap(g), [P(x, 0.38, 2.235) for x in xs], [P(x, 0.43, 2.07) for x in xs], 8)
    V.flush_lamp(g, st, "GrilleDark", _grille_inner, depth=0.06, floor="GrilleDark")
    V.strip_patch(g, st, 0.0, 1.0, -0.20, -0.10, -0.006, M(g, "Chrome"), nr=1)


def mirrors(g):
    for side in (1, -1):
        V.tube(g, [(side * 2.35, 3.30, 3.06), (side * 2.54, 3.24, 3.16), (side * 2.61, 3.18, 3.22)],
               0.052, M(g, "BlackPlastic"), 10 if g.hi else 8, fillet=0.08)
        V.box(g, (side * 2.615, 3.13, 3.28), (0.16, 0.34, 0.24), M(g, "BlackPlastic"), bev=0.055)
        V.box(g, (side * 2.685, 3.13, 3.28), (0.03, 0.28, 0.19), M(g, "PaintBlue"), bev=0.03)
        V.box(g, (side * 2.655, 3.33, 3.28), (0.05, 0.05, 0.18), M(g, "BlackPlastic"), bev=0.01)
        V.box(g, (side * 2.669, 3.13, 3.28), (0.012, 0.22, 0.14), M(g, "Glass"), bev=0.01)


def handles(g):
    for side in (1, -1):
        for y, z in ((4.60, 2.745), (7.85, 2.855)):
            V.box(g, (side * 2.455, y, z), (0.055, 0.44, 0.10), M(g, "BlackPlastic"), bev=0.03)
            V.box(g, (side * 2.478, y - 0.09, z + 0.035), (0.012, 0.25, 0.035),
                  M(g, "Chrome"), bev=0.008)
    V.lathe(g, (-2.435, 10.15, 2.05), (-1, 0, 0),
            [(0.24, 0.0), (0.24, 0.012), (0.19, 0.02), (0.0, 0.02)], 18 if g.hi else 12, M(g, "PaintBlue"))
    V.lathe(g, (-2.45, 10.15, 2.05), (-1, 0, 0),
            [(0.15, 0.0), (0.15, 0.015), (0.0, 0.02)], 16 if g.hi else 10, M(g, "BlackPlastic"))


def wipers(g):
    for sx in (-1, 1):
        V.box(g, (sx * 0.76, 2.66, 3.06), (1.05, 0.07, 0.05), M(g, "BlackPlastic"),
              rot=Matrix.Rotation(math.radians(9), 3, "X"), bev=0.01)
    V.box(g, (0, 2.63, 3.05), (3.10, 0.05, 0.040), M(g, "BlackPlastic"), bev=0.008)


def plates_and_text(g):
    V.box(g, (0, 0.170, 1.02), (1.62, 0.035, 0.36), M(g, "PlateWhite"), bev=0.012)
    V.box(g, (0, 11.738, 1.02), (1.62, 0.035, 0.36), M(g, "PlateYellow"), bev=0.012)
    me = V.text_mesh("GI15 KXR", 0.30, resolution=1)
    def mp(co):
        return P(co.x, 0.145, 1.02 + co.y)
    fs = g.add_mesh(me, M(g, "PlateLetter"), mp)
    g.orient(fs, lambda c: P(0, -1, 0))
    bpy.data.meshes.remove(me)
    me = V.text_mesh("GI15 KXR", 0.30, resolution=1)
    def mpr(co):
        return P(-co.x, 11.762, 1.02 + co.y)
    fs = g.add_mesh(me, M(g, "PlateLetter"), mpr)
    g.orient(fs, lambda c: P(0, 1, 0))
    bpy.data.meshes.remove(me)


def body_detail(g):
    lamps(g)
    bumpers(g)
    grille(g)
    mirrors(g)
    handles(g)
    wipers(g)
    plates_and_text(g)


# --------------------------------------------------------------------------- wheels and underbody
def tyre(g, side):
    profile = [(0.60, -0.27), (0.67, -0.315), (0.79, -0.335), (0.875, -0.325), (0.915, -0.28),
               (0.93, -0.19), (0.93, 0.19), (0.915, 0.28), (0.875, 0.325), (0.79, 0.335),
               (0.67, 0.315), (0.60, 0.27)]
    seg = 20 if g.hi else 16
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0), [(r, h * side) for r, h in profile], seg, M(g, "Tyre"))
    # lateral tread sipes
    n = 9 if g.hi else 0     # sipes are baked from the _HP
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        rot = Matrix.Rotation(-a, 3, "X")
        c = (0.0, 0.918 * math.sin(a), WHEEL_R + 0.918 * math.cos(a))
        V.box(g, c, (0.50, 0.075, 0.026), M(g, "Tyre"), rot=rot, bev=0.0)
        c2 = (0.0, 0.925 * math.sin(a + 0.16), WHEEL_R + 0.925 * math.cos(a + 0.16))
        V.box(g, c2, (0.46, 0.050, 0.022), M(g, "Tyre"), rot=Matrix.Rotation(-(a + 0.16), 3, "X"), bev=0.0)


def rim(g, side):
    face = side * 0.275
    seg = 20 if g.hi else 16
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.60, 0.13 * side), (0.625, 0.18 * side), (0.635, 0.27 * side), (0.615, 0.305 * side),
             (0.585, 0.30 * side)], seg, M(g, "RimSilver"))
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.0, 0.255 * side), (0.56, 0.255 * side), (0.56, 0.235 * side), (0.0, 0.235 * side)],
            seg, M(g, "RimDark"))
    # five alloy spokes
    for k in range(5):
        a = math.radians(72 * k)
        c = (side * 0.295, 0.30 * math.sin(a), WHEEL_R + 0.30 * math.cos(a))
        V.box(g, c, (0.075, 0.155, 0.46), M(g, "RimSilver"),
              rot=Matrix.Rotation(-a, 3, "X"), bev=0.02)
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.585, 0.30 * side), (0.605, 0.33 * side), (0.60, 0.28 * side), (0.57, 0.275 * side)],
            seg, M(g, "RimSilver"))
    V.lathe(g, (0, 0, WHEEL_R), (side, 0, 0),
            [(0.0, 0.32), (0.16, 0.32), (0.17, 0.345), (0.14, 0.37), (0.0, 0.375)],
            16 if g.hi else 12, M(g, "RimSilver"))
    for k in range(5):
        a = math.radians(72 * k + 36)
        V.lathe(g, (side * 0.365, 0.115 * math.sin(a), WHEEL_R + 0.115 * math.cos(a)), (side, 0, 0),
                [(0.035, 0.0), (0.035, 0.02), (0.0, 0.025)], 6, M(g, "Chrome"))
    # brake disc and caliper behind the spokes
    V.lathe(g, (side * 0.10, 0, WHEEL_R), (side, 0, 0),
            [(0.0, 0.0), (0.50, 0.0), (0.50, 0.035), (0.0, 0.04)], seg, M(g, "BrakeSteel"))
    V.box(g, (side * 0.12, 0.30, WHEEL_R + 0.26), (0.09, 0.34, 0.20), M(g, "BlackMetal"), bev=0.03)
    # valve stem
    V.tube(g, [(side * 0.30, 0.10, WHEEL_R + 0.55), (side * 0.30, 0.10, WHEEL_R + 0.61)],
           0.022, M(g, "BlackPlastic"), 6)


def wheel(g, side, front):
    start = len(g.bm.verts)
    tyre(g, side)
    rim(g, side)
    g.bm.verts.ensure_lookup_table()
    cx, cy = side * HUB_X, AX_F if front else AX_R
    for v in g.bm.verts[start:]:
        v.co = P(v.co.x + cx, v.co.y + cy, v.co.z)


def underbody(g):
    V.box(g, (0, 6.0, 0.58), (2.84, 8.60, 0.08), M(g, "Underseal"), bev=0.02)
    V.box(g, (0, 1.25, 0.56), (2.84, 1.40, 0.10), M(g, "Underseal"), bev=0.03)
    V.box(g, (0, 10.75, 0.60), (2.84, 1.10, 0.10), M(g, "Underseal"), bev=0.03)
    for side in (1, -1):
        V.box(g, (side * 1.22, 6.05, 0.50), (0.12, 6.6, 0.12), M(g, "BlackMetal"), bev=0.02)
    V.tube(g, [(-0.55, 0.90, 0.50), (-0.55, 3.6, 0.50), (-0.35, 6.4, 0.52), (-0.55, 8.9, 0.50),
               (-0.55, 10.5, 0.55), (-1.25, 11.5, 0.62)], 0.075, M(g, "Exhaust"), 8 if g.hi else 6,
           fillet=0.45, fseg=3)
    V.lathe(g, (-0.55, 8.25, 0.50), (0, 1, 0),
            [(0.0, -0.85), (0.12, -0.80), (0.15, -0.55), (0.15, 0.55), (0.12, 0.80), (0.0, 0.85)],
            12 if g.hi else 8, M(g, "Exhaust"))
    V.box(g, (0, 9.8, 0.55), (0.12, 1.8, 0.10), M(g, "BlackMetal"), bev=0.02)


def collision():
    bm = bmesh.new()
    pts = []
    for y in (0.2, 1.2, 2.4, 4.2, 6.0, 8.0, 9.8, 11.2, 11.8):
        for x in (-2.48, -1.25, 0.0, 1.25, 2.48):
            pts += [(x, y, 0.62), (x, y, 1.5), (x, y, 2.8)]
        pts += [(-2.30, y, 4.2), (0.0, y, 4.42), (2.30, y, 4.2)]
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("M_Road_ParkedCar_01_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("M_Road_ParkedCar_01_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob
