"""C3 M_Veh_MooredBoat_02: a 10 m Cornish inshore crabber (1980s-2000s GRP displacement type), moored set dressing.

Navy topsides, white sheer and boot-top stripes, red antifouling, high flared bow, forward cream wheelhouse with
raked windows and a wiper, long open working deck aft with bulwarks, a starboard pot hauler on a davit, stacked
parlour creels, fish boxes, rope coils, dhan buoys, tyres and waterline weed. Painted "PH 117" and "MORWENNA ROSE"
on both bow quarters. Shared T_FishingBoat_Atlas (2048): _01's band ranges and files are untouched.

Blender axes: X beam (+X port), Y length (bow -Y), Z up. Origin at the waterline, midships.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C1"))
import c1geo as K  # noqa: E402
from c1geo import Buf, V, W  # noqa: E402
import c2geo as C  # noqa: E402
import versions  # noqa: E402

NAME = "M_Veh_MooredBoat_02"
BUDGET, BUDGET_TRIS = "small_craft", 25000
S = 3.0
L0, L1 = -5.00, 4.85
BEAM = 1.55

BANDS = {
    "antifoul": (0.000, 0.100), "blue": (0.100, 0.240), "sheer": (0.240, 0.310),
    "inner": (0.310, 0.390), "varnish": (0.390, 0.530), "wood": (0.530, 0.620),
    "metal": (0.620, 0.690), "motor": (0.690, 0.770), "dark": (0.770, 0.825),
    "rope": (0.825, 0.875), "water": (0.875, 0.905), "weed": (0.905, 0.945),
    "white": (0.945, 0.972), "bailer": (0.972, 1.000),
}
B = K.bandfn(BANDS)

COLORS = {
    "Antifoul": "#71392F", "Navy": "#344D5B", "Sheer": "#D6D4C6", "Inner": "#6F8185",
    "Varnish": "#9B6A3C", "Wood": "#7C664A", "Metal": "#8B8E88", "Cream": "#C6C2AD",
    "Dark": "#34393B", "Rope": "#9C8A68", "Glass": "#26332E", "Weed": "#4A5C2C",
    "White": "#E4E2D7", "Green": "#3F6B52",
}
SLOT = {
    "Antifoul": (0.0, 0.74), "Navy": (0.0, 0.46), "Sheer": (0.0, 0.58), "Inner": (0.0, 0.70),
    "Varnish": (0.0, 0.56), "Wood": (0.0, 0.82), "Metal": (1.0, 0.44), "Cream": (0.0, 0.52),
    "Dark": (0.0, 0.80), "Rope": (0.0, 0.90), "Glass": (0.0, 0.07), "Weed": (0.0, 0.86),
    "White": (0.0, 0.56), "Green": (0.0, 0.62),
}
PROC = {
    "Antifoul": dict(mottle=(3.5, 0.08), grime=("#4E2C27", 0.30), salt=("#8E8678", 0.20)),
    "Navy": dict(mottle=(3.0, 0.07), grime=("#152B39", 0.24), salt=("#9EA3A0", 0.16)),
    "Sheer": dict(mottle=(4.0, 0.045), grime=("#B4B2A5", 0.26), salt=("#A9A79A", 0.16)),
    "Inner": dict(mottle=(3.0, 0.07), grime=("#5E6E70", 0.30)),
    "Varnish": dict(mottle=(5.0, 0.06), grain=("#6C4926", 0.24), salt=("#A79E8A", 0.13)),
    "Wood": dict(mottle=(2.6, 0.08), grain=("#52422C", 0.24), salt=("#9A9280", 0.18)),
    "Metal": dict(mottle=(6.0, 0.04), grime=("#6F736E", 0.24)),
    "Cream": dict(mottle=(4.5, 0.05), grime=("#8E8D7E", 0.22), salt=("#BDBAA8", 0.14)),
    "Dark": dict(mottle=(6.0, 0.04), grime=("#24282A", 0.20)),
    "Rope": dict(mottle=(9.0, 0.07), grime=("#6E6047", 0.22)),
    "Glass": dict(mottle=(2.2, 0.03)),
    "Weed": dict(mottle=(7.0, 0.12), grime=("#3C4926", 0.28)),
    "White": dict(mottle=(6.0, 0.03), grime=("#C9C6B8", 0.16)),
    "Green": dict(mottle=(5.0, 0.05), grime=("#2E5140", 0.20)),
}


def t_of(y):
    return (y - L0) / (L1 - L0)


def cl(x, a=0.0, b=1.0):
    return min(max(x, a), b)


def half_beam(y):
    t = cl(t_of(y))
    if t < 0.48:
        return BEAM * math.sin(0.5 * math.pi * t / 0.48) ** 0.90
    if t < 0.80:
        return BEAM + 0.028 * math.sin(math.pi * (t - 0.48) / 0.32)
    return BEAM - (BEAM - 0.93) * ((t - 0.80) / 0.20) ** 1.45


def sheer_z(y):
    t = cl(t_of(y))
    return 1.16 + 0.92 * max(0.0, (0.33 - t) / 0.33) ** 1.65 + 0.04 * max(0.0, (t - 0.82) / 0.18) ** 2


def keel_z(y):
    t = cl(t_of(y))
    return -1.04 + 0.50 * max(0.0, (0.24 - t) / 0.24) ** 1.8 + 0.28 * max(0.0, (t - 0.78) / 0.22) ** 1.5


def deck_z(y):
    t = cl(t_of(y))
    return 0.60 + 0.20 * max(0.0, (0.30 - t) / 0.30) ** 1.2 + 0.06 * max(0.0, (t - 0.78) / 0.22) ** 2


def flare_of(y):
    t = cl(t_of(y))
    return 0.18 * max(0.0, (0.42 - t) / 0.42) ** 1.5


def sec_raw(y, s):
    w = half_beam(y)
    z0 = keel_z(y)
    h = sheer_z(y) - z0
    x = w * max(math.sin(0.5 * math.pi * s), 0.0) ** 0.62 * (1.0 + flare_of(y) * s * s)
    return x, z0 + h * s ** 1.8


def sec(y, s, side=1, off=0.0):
    x, z = sec_raw(y, s)
    if off:
        ds = 1e-3
        xa, za = sec_raw(y, min(1.0, s + ds))
        xb, zb = sec_raw(y, max(0.0, s - ds))
        dx, dz = xa - xb, za - zb
        n = math.hypot(dz, dx) or 1.0
        x += off * (dz * side) / n
        z += off * (-dx) / n
    return V(side * x, y, z)


def s_at_z(y, z):
    z0, z1 = keel_z(y), sheer_z(y)
    return cl((z - z0) / max(z1 - z0, 1e-5)) ** (1 / 1.8)


def hull_x(y, z, side=1):
    x, _ = sec_raw(y, s_at_z(y, z))
    return side * x


def stations(n=20, a=0.012, b=0.995):
    return [L0 + (L1 - L0) * (a + (b - a) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1)))) for i in range(n)]


def hull_grid(b, zlo, zhi, band, tu, uoff, nrows, off=0.0):
    v0, v1 = BANDS[band]
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(22):
            s0 = 0.0 if zlo <= keel_z(y) + 1e-4 else s_at_z(y, zlo)
            s1 = 1.0 if zhi >= sheer_z(y) - 1e-4 else s_at_z(y, zhi)
            rr.append([sec(y, s0 + (s1 - s0) * j / (nrows - 1), side, off) for j in range(nrows)])
            uu.append([((y - L0) / tu + uoff, v0 + 0.004 + (v1 - v0 - 0.008) * j / (nrows - 1))
                       for j in range(nrows)])
        K.ogrid(b, rr, uu, lambda c: Vector((c.x, 0.0, (c.z - 0.4) * 0.12)))


def transom_grid(b, zlo, zhi, band, nrows, uoff):
    v0, v1 = BANDS[band]
    zk, zs = keel_z(L1), sheer_z(L1)
    rr, uu = [], []
    for k in range(nrows):
        f = k / (nrows - 1)
        z = zlo + (zhi - zlo) * f
        ff = cl((z - zk) / max(zs - zk, 1e-5))
        yy = L1 + 0.012 + 0.075 * ff
        hw = hull_x(L1 - 0.02, z)
        rr.append([V(-hw + 2 * hw * j / 10, yy, z) for j in range(11)])
        uu.append([(uoff + 2.1 * (j / 10), v0 + 0.004 + (v1 - v0 - 0.008) * f) for j in range(11)])
    K.ogrid(b, rr, uu, (0, 1, 0))


def hull_strip(b, dlo, dhi, band, tu, uoff, nrows, off=0.0):
    v0, v1 = BANDS[band]
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(22):
            s0 = s_at_z(y, sheer_z(y) + dlo)
            s1 = s_at_z(y, sheer_z(y) + dhi)
            rr.append([sec(y, s0 + (s1 - s0) * j / (nrows - 1), side, off) for j in range(nrows)])
            uu.append([((y - L0) / tu + uoff, v0 + 0.004 + (v1 - v0 - 0.008) * j / (nrows - 1))
                       for j in range(nrows)])
        K.ogrid(b, rr, uu, lambda c: Vector((c.x, 0.0, (c.z - 0.4) * 0.12)))


def bow_face(b, zlo, zhi, band, nrows=3):
    y0 = stations(22)[0]
    v0, v1 = BANDS[band]
    rr, uu = [], []
    for k in range(nrows):
        z = zlo + (zhi - zlo) * k / (nrows - 1)
        hw = hull_x(y0, z)
        f = cl((z - keel_z(y0)) / max(sheer_z(y0) - keel_z(y0), 1e-5))
        apex = -4.975 - 0.165 * f
        rr.append([V(-hw, y0, z), V(0, apex, z), V(hw, y0, z)])
        uu.append([(0.02, v0 + 0.004 + (v1 - v0 - 0.008) * k / (nrows - 1)),
                   (0.03, v0 + 0.004 + (v1 - v0 - 0.008) * k / (nrows - 1)),
                   (0.04, v0 + 0.004 + (v1 - v0 - 0.008) * k / (nrows - 1))])
    K.ogrid(b, rr, uu, (0, -1, 0))


def build_hull():
    anti, navy, stripe, boot = Buf(), Buf(), Buf(), Buf()
    hull_grid(anti, -1.5, 0.10, "antifoul", 3.0, 0.00, 4)
    transom_grid(anti, keel_z(L1), 0.10, "antifoul", 2, 0.02)
    hull_grid(navy, 0.10, 2.6, "blue", 3.0, 0.11, 6)
    transom_grid(navy, 0.10, sheer_z(L1), "blue", 7, 0.13)
    hull_strip(stripe, -0.36, -0.23, "sheer", 3.0, 0.23, 2, off=0.005)
    hull_grid(boot, 0.10, 0.19, "white", 3.0, 0.34, 2, off=0.005)
    bow_face(anti, keel_z(-4.94), 0.10, "antifoul", 2)
    bow_face(navy, 0.10, sheer_z(-4.94), "blue", 5)
    return {"HullAntifoul": anti, "HullTopsides": navy, "HullStripe": stripe, "BootTop": boot}


def build_deck_inner():
    b = Buf()
    v0, v1 = BANDS["inner"]
    rr, uu = [], []
    for y in stations(16, 0.02, 0.985):
        hw = max(hull_x(y, deck_z(y)) - 0.038, 0.03)
        row = []
        for j in range(11):
            x = -hw + 2 * hw * j / 10
            row.append(V(x, y, deck_z(y) + 0.028 * (1.0 - (x / hw) ** 2)))
        rr.append(row)
        uu.append([((y - L0) / 1.7, v0 + 0.006 + (v1 - v0 - 0.012) * (j / 10)) for j in range(11)])
    K.ogrid(b, rr, uu, (0, 0, 1))
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(16, 0.02, 0.985):
            row = []
            for j in range(4):
                z = deck_z(y) - 0.01 + (sheer_z(y) - 0.045 - (deck_z(y) - 0.01)) * j / 3
                row.append(V(hull_x(y, z, side) - 0.026 * side, y, z))
            rr.append(row)
            uu.append([((y - L0) / 1.7 + (0.0 if side > 0 else 0.41), v0 + 0.006 + (v1 - v0 - 0.012) * (j / 3))
                       for j in range(4)])
        K.ogrid(b, rr, uu, lambda c: Vector((-c.x, 0.0, 0.0)))
    zs = sheer_z(L1)
    rr, uu = [], []
    for k in range(4):
        z = deck_z(L1) + (zs - 0.05 - deck_z(L1)) * k / 3
        hw = hull_x(L1 - 0.12, z)
        rr.append([V(-hw + 2 * hw * j / 8, L1 - 0.12 + 0.05 * (k / 3), z) for j in range(9)])
        uu.append([(0.45 + 0.40 * (j / 8), v0 + 0.006 + (v1 - v0 - 0.012) * (k / 3)) for j in range(9)])
    K.ogrid(b, rr, uu, (0, -1, 0))
    return b


def build_cap_rail():
    b = Buf()
    uv = B("varnish", 1.6)
    for side in (1, -1):
        pts = [V(side * (half_beam(y) - 0.006), y, sheer_z(y) + 0.018) for y in stations(24, 0.0, 0.998)]
        W.sweep(b, pts, W.rect_profile(0.115, 0.062, 0.014), uv, axes=[((1, 0, 0), (0, 0, 1))] * len(pts),
                caps=(True, True))
    zb = sheer_z(L1) + 0.035
    W.sweep(b, [V(-half_beam(L1) + 0.03, L1 + 0.07, zb), V(half_beam(L1) - 0.03, L1 + 0.07, zb)],
            W.rect_profile(0.10, 0.055, 0.012), uv, axes=[((0, 1, 0), (0, 0, 1))] * 2, caps=(True, True))
    return b


CAB_YF, CAB_YB = -3.34, -1.02
CAB_HW = 1.03
CAB_BASE = 0.64
CAB_ROOF = 2.46


def cab_front_y(z):
    return CAB_YF + 0.085 * (z - CAB_BASE) / (CAB_ROOF - CAB_BASE)


def cab_hw(z):
    return CAB_HW - 0.055 * (z - CAB_BASE) / (CAB_ROOF - CAB_BASE)


def cab_ring(z):
    hw = cab_hw(z)
    yf = cab_front_y(z)
    yb = CAB_YB
    r = 0.10
    pts = []
    for (cx, cy, a0) in ((-hw + r, yf + r, math.pi), (hw - r, yf + r, 1.5 * math.pi),
                         (hw - r, yb - r, 0.0), (-hw + r, yb - r, 0.5 * math.pi)):
        for i in range(3):
            a = a0 + (math.pi / 2) * i / 2
            pts.append(V(cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def build_cabin():
    b = Buf()
    zs = [CAB_BASE, CAB_BASE + 0.14, CAB_ROOF - 0.16, CAB_ROOF]
    rings = [cab_ring(z) for z in zs]
    v0, v1 = BANDS["motor"]
    for k in range(len(rings) - 1):
        A, Q = rings[k], rings[k + 1]
        for j in range(len(A)):
            j2 = (j + 1) % len(A)
            c = (A[j] + Q[j2]) / 2
            want = Vector((c.x, (c.y + 2.84) * 0.7, 0.0))
            uv = [(j / len(A) * 2.4, v0 + 0.004 + (v1 - v0 - 0.008) * (k / 3)),
                  ((j + 1) / len(A) * 2.4, v0 + 0.004 + (v1 - v0 - 0.008) * (k / 3)),
                  ((j + 1) / len(A) * 2.4, v0 + 0.004 + (v1 - v0 - 0.008) * ((k + 1) / 3)),
                  (j / len(A) * 2.4, v0 + 0.004 + (v1 - v0 - 0.008) * ((k + 1) / 3))]
            K.oface(b, [A[j], A[j2], Q[j2], Q[j]], uv, want)
    K.oface(b, rings[-1], [((j / len(rings[-1])) * 2.4, v0 + 0.015) for j in range(len(rings[-1]))], (0, 0, 1))
    return b


def build_roof():
    b = Buf()
    t = Buf()
    uv = B("sheer", 1.5)
    hw = cab_hw(CAB_ROOF) + 0.075
    yf = cab_front_y(CAB_ROOF) - 0.04
    yb = CAB_YB + 0.02
    W.obox(b, (0.0, (yf + yb) / 2, CAB_ROOF - 0.02), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (hw, (yb - yf) / 2, 0.045), uv)
    uv2 = B("metal", 0.8)
    W.obox(t, (0.0, (yf + yb) / 2, CAB_ROOF + 0.032), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (hw - 0.10, (yb - yf) / 2 - 0.10, 0.006), uv2)
    return b, t


def window(b_glass, b_trim, quad, normal, frame=0.035):
    gq = [p + Vector(normal) * 0.012 for p in quad]
    w0, w1 = BANDS["water"]
    K.oface(b_glass, gq, [(0.06, w0 + 0.007), (0.18, w0 + 0.007), (0.18, w1 - 0.007), (0.06, w1 - 0.007)], normal)
    nrm = Vector(normal)
    m0, m1 = BANDS["metal"]
    for i in range(4):
        p0, p1 = gq[i], gq[(i + 1) % 4]
        d = p1 - p0
        if d.length < 1e-6:
            continue
        out = d.normalized().cross(nrm).normalized() * frame
        K.oface(b_trim, [p0 - out, p0 + out, p1 + out, p1 - out],
                [(0.10, m0 + 0.006), (0.20, m0 + 0.006), (0.20, m1 - 0.006), (0.10, m1 - 0.006)], nrm)


def build_windows(glass, trim):
    z0, z1 = CAB_BASE + 0.86, CAB_BASE + 1.72
    yf0, yf1 = cab_front_y(z0), cab_front_y(z1)
    hw0, hw1 = cab_hw(z0), cab_hw(z1)
    for (xa, xb) in ((-0.90, -0.52), (-0.44, 0.44), (0.52, 0.90)):
        quad = [V(xa, yf0, z0), V(xb, yf0, z0), V(xb * (hw1 / hw0), yf1, z1), V(xa * (hw1 / hw0), yf1, z1)]
        window(glass["front"], trim, quad, (0, -1, 0.05))
    for side in (1, -1):
        zs = [CAB_BASE + 0.86, CAB_BASE + 1.66]
        for (ya, yb) in ((CAB_YF + 0.28, CAB_YF + 0.92), (CAB_YF + 1.02, CAB_YB - 0.28)):
            q = []
            for z in zs:
                hw = cab_hw(z) * side
                q += [V(hw, ya, z), V(hw, yb, z)]
            window(glass["side"], trim, [q[0], q[2], q[3], q[1]], (side, 0, 0))
    yb = CAB_YB + 0.005
    window(glass["rear"], trim, [V(-0.62, yb, CAB_BASE + 0.86), V(-0.20, yb, CAB_BASE + 0.86),
                                 V(-0.20, yb, CAB_BASE + 1.60), V(-0.62, yb, CAB_BASE + 1.60)], (0, 1, -0.02))
    window(glass["rear"], trim, [V(0.28, yb, CAB_BASE + 1.06), V(0.78, yb, CAB_BASE + 1.06),
                                 V(0.78, yb, CAB_BASE + 1.62), V(0.28, yb, CAB_BASE + 1.62)], (0, 1, -0.02))


def build_cabin_trim():
    b = Buf()
    uv = B("metal", 0.8)
    yb = CAB_YB + 0.008
    W.sweep(b, [V(0.16, yb + 0.016, CAB_BASE + 0.04), V(0.16, yb + 0.016, CAB_BASE + 1.82)],
            W.rect_profile(0.026, 0.026, 0.006), uv, axes=[((0, 1, 0), (1, 0, 0))] * 2, caps=(True, True))
    W.sweep(b, [V(0.16, yb + 0.016, CAB_BASE + 1.82), V(0.94, yb + 0.016, CAB_BASE + 1.82)],
            W.rect_profile(0.026, 0.026, 0.006), uv, axes=[((0, 1, 0), (1, 0, 0))] * 2, caps=(True, True))
    for dz in (0.18, 0.70, 1.40):
        C.tube(b, [V(0.16, yb + 0.010, CAB_BASE + dz), V(0.10, yb + 0.010, CAB_BASE + dz)], 0.011, uv, sides=6)
    C.tube(b, [V(0.88, yb + 0.030, CAB_BASE + 0.95), V(0.88, yb + 0.030, CAB_BASE + 1.20)], 0.014, uv, sides=8)
    for side in (1, -1):
        x = cab_hw(CAB_BASE + 1.0) * side + side * 0.06
        W.sweep(b, [V(x, CAB_YF + 0.40, CAB_BASE + 0.78), V(x + side * 0.045, CAB_YF + 0.58, CAB_BASE + 0.78),
                    V(x + side * 0.045, CAB_YB - 0.55, CAB_BASE + 0.78), V(x, CAB_YB - 0.28, CAB_BASE + 0.78)],
                W.round_profile(0.018, 6), uv, axes=[((0, 0, 1), (side, 0, 0))] * 4, caps=(True, True))
        C.tube(b, [V(side * 0.55, CAB_YB + 0.10, CAB_ROOF + 0.06), V(side * 0.55, CAB_YB + 0.10, CAB_ROOF + 0.28),
                   V(side * 0.55, CAB_YF + 1.10, CAB_ROOF + 0.28), V(side * 0.55, CAB_YF + 1.10, CAB_ROOF + 0.06)], 0.017, uv, sides=6)
    p0 = V(-0.02, cab_front_y(CAB_BASE + 0.92) - 0.030, CAB_BASE + 0.92)
    p1 = V(-0.31, cab_front_y(CAB_BASE + 1.42) - 0.034, CAB_BASE + 1.44)
    C.tube(b, [p0, p1], 0.008, uv, sides=5)
    W.sweep(b, [p0, p1], W.rect_profile(0.030, 0.008, 0.003), uv, axes=[((0, 1, 0), (0, 0, 1))] * 2,
            caps=(True, True))
    C.tube(b, [p0 + V(0, 0.02, -0.03), p0 + V(0, -0.01, 0.0)], 0.026, uv, sides=8)
    C.tube(b, [V(0.78, CAB_YB + 0.14, CAB_ROOF), V(0.78, CAB_YB + 0.14, CAB_ROOF + 0.44)], 0.055, uv, sides=10)
    C.tube(b, [V(0.78, CAB_YB + 0.14, CAB_ROOF + 0.44), V(0.78, CAB_YB + 0.14, CAB_ROOF + 0.48)], 0.066, uv, sides=10)
    C.tube(b, [V(-0.28, cab_front_y(CAB_ROOF) - 0.02, CAB_ROOF + 0.05),
               V(-0.28, cab_front_y(CAB_ROOF) - 0.15, CAB_ROOF + 0.07)], 0.038, uv, sides=8)
    W.obox(b, (0.48, cab_front_y(CAB_ROOF) - 0.05, CAB_ROOF + 0.09), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (0.11, 0.10, 0.055), uv)
    return b


def build_mast_gear():
    b = Buf()
    uv = B("metal", 0.9)
    base = CAB_ROOF + 0.02
    C.tube(b, [V(0, -2.12, base), V(0, -2.12, base + 1.72)], 0.045, uv, sides=8)
    C.tube(b, [V(-0.56, -2.12, base + 1.32), V(0.56, -2.12, base + 1.32)], 0.018, uv, sides=6)
    for side in (1, -1):
        C.tube(b, [V(side * 0.56, -2.12, base + 1.32), V(side * 0.56, -2.12, base + 1.42)], 0.012, uv, sides=6)
        C.tube(b, [V(0, -2.12, base + 1.70), V(side * 0.72, CAB_YB + 0.12, CAB_ROOF + 0.10)], 0.007, uv, sides=5)
    W.obox(b, (0, -2.12, base + 1.78), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.055, 0.045, 0.07), uv)
    C.tube(b, [V(0, -2.62, CAB_ROOF + 0.01), V(0, -2.62, CAB_ROOF + 0.20)], 0.055, uv, sides=8)
    C.tube(b, [V(0, -2.62, CAB_ROOF + 0.20), V(0, -2.62, CAB_ROOF + 0.235)], 0.21, uv, sides=14)
    C.tube(b, [V(0.68, -1.98, CAB_ROOF + 0.01), V(0.68, -1.98, CAB_ROOF + 1.36)], 0.007, uv, sides=5)
    C.tube(b, [V(0.68, -1.98, CAB_ROOF + 0.05), V(0.68, -1.98, CAB_ROOF + 0.13)], 0.022, uv, sides=8)
    C.tube(b, [V(-0.62, -2.48, CAB_ROOF + 0.02), V(-0.62, -2.48, CAB_ROOF + 0.10)], 0.052, uv, sides=10)
    return b


def build_radome():
    b = Buf()
    prof = [(0.03, 0.0), (0.20, 0.015), (0.29, 0.075), (0.30, 0.15), (0.25, 0.22), (0.12, 0.27), (0.0, 0.285)]
    v0, v1 = BANDS["motor"]
    W.lathe(b, prof, 18, lambda k, a: (a * 0.45 + 0.02, v0 + 0.006 + (v1 - v0 - 0.012) * k / 6),
            centre=(0, -2.62, CAB_ROOF + 0.20))
    return b


def build_nav_lights():
    dark = Buf()
    red = Buf()
    green = Buf()
    uv = B("dark", 0.4)
    for side, lens in ((1, red), (-1, green)):
        x = cab_hw(CAB_BASE + 1.40) * side + side * 0.055
        W.obox(dark, (x, -3.45, CAB_BASE + 1.86), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
              (0.025, 0.060, 0.050), uv)
        W.obox(lens, (x + side * 0.026, -3.45, CAB_BASE + 1.86), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
              (0.006, 0.042, 0.036), B("bailer" if side < 0 else "antifoul", 0.2))
    W.obox(dark, (0, CAB_YB + 0.01, CAB_BASE + 1.92), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (0.045, 0.02, 0.035), uv)
    return dark, red, green


def build_fittings():
    b = Buf()
    uv = B("metal", 0.8)
    pts = [V(0, -4.975, keel_z(-4.99) + 0.04), V(0, -5.005, 0.10), V(0, -5.075, 0.90), V(0, -5.12, 1.55),
           V(0, -5.135, sheer_z(-4.99))]
    W.sweep(b, pts, W.rect_profile(0.10, 0.055, 0.012), uv, axes=[((1, 0, 0), (0, 0, 1))] * len(pts),
            caps=(True, True))
    zt = sheer_z(-4.99) + 0.02
    C.tube(b, [V(-0.11, -5.12, zt), V(0.11, -5.12, zt)], 0.045, uv, sides=10)
    for sx in (-1, 1):
        W.sweep(b, [V(sx * 0.13, -5.12, zt - 0.07), V(sx * 0.13, -5.12, zt + 0.07)],
                W.rect_profile(0.025, 0.10, 0.006), uv, axes=[((0, 1, 0), (0, 0, 1))] * 2, caps=(True, True))

    def cleat(x, y, z, ang=0.0):
        ca, sa = math.cos(ang), math.sin(ang)
        for dx in (-0.13, 0.13):
            C.tube(b, [V(x + ca * dx, y + sa * dx, z), V(x + ca * dx, y + sa * dx, z + 0.075)], 0.017, uv, sides=6)
        C.tube(b, [V(x - ca * 0.17, y - sa * 0.17, z + 0.075), V(x + ca * 0.17, y + sa * 0.17, z + 0.075)],
               0.028, uv, sides=8)

    cleat(0.0, -4.35, deck_z(-4.35) + 0.03, 0.0)
    cleat(-1.14, 4.18, sheer_z(4.18) + 0.05, 0.2)
    cleat(1.14, 4.18, sheer_z(4.18) + 0.05, -0.2)
    for side in (1, -1):
        W.ring(b, V(side * (half_beam(4.1) - 0.03), 4.1, sheer_z(4.1) + 0.02), (0, 1, 0), (0, 0, 1),
                0.075, 0.013, 12, 6, uv)
    for yy in (0.10, 0.70):
        x = hull_x(0.4, 1.05) + 0.075
        C.tube(b, [V(x, yy, 1.30), V(x + 0.02, yy, 0.25)], 0.014, uv, sides=6)
    for zz in (0.40, 0.62, 0.84, 1.06):
        x = hull_x(0.4, zz) + 0.095
        C.tube(b, [V(x, 0.08, zz), V(x, 0.72, zz)], 0.012, uv, sides=6)
    for side in (1, -1):
        for y in (-1.2, 0.45, 2.0, 3.3):
            z = deck_z(y) + 0.10
            x = hull_x(y, z, side) + side * 0.012
            K.oface(b, [V(x, y - 0.10, z - 0.04), V(x, y + 0.10, z - 0.04),
                        V(x, y + 0.10, z + 0.04), V(x, y - 0.10, z + 0.04)],
                    [(0.30, 0.642), (0.35, 0.642), (0.35, 0.662), (0.30, 0.662)], (side, 0, 0))
    return b


def build_hatches():
    b = Buf()
    t = Buf()
    uv = B("inner", 1.1)
    W.obox(b, (-0.28, 0.25, deck_z(0.25) + 0.05), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.38, 0.30, 0.05), uv)
    W.obox(b, (0.50, 0.12, deck_z(0.12) + 0.04), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.22, 0.26, 0.04), uv)
    uv2 = B("metal", 0.6)
    for x in (-0.62, 0.06):
        C.tube(t, [V(x, 0.08, deck_z(0.08) + 0.12), V(x, 0.52, deck_z(0.52) + 0.12)], 0.010, uv2, sides=6)
    return b, t


def creel_templates():
    fr = Buf()
    uv = B("blue", 0.45)
    L, Wd, H, r = 0.86, 0.55, 0.43, 0.011
    for yy in (-Wd / 2, Wd / 2):
        C.tube(fr, [V(-L / 2, yy, 0.035), V(L / 2, yy, 0.035)], r * 1.15, uv, sides=5)
    for xx in (-L / 2, 0.0, L / 2):
        C.tube(fr, [V(xx, -Wd / 2, 0.035), V(xx, Wd / 2, 0.035)], r * 1.15, uv, sides=5)
    for xx in (-L / 2, 0.0, L / 2):
        pts = [V(xx, (Wd / 2) * math.cos(math.pi * j / 10), 0.035 + (H - 0.035) * math.sin(math.pi * j / 10))
               for j in range(11)]
        C.tube(fr, pts, r, uv, sides=5)
    C.tube(fr, [V(-L / 2, 0, H + 0.005), V(L / 2, 0, H + 0.005)], r, uv, sides=5)
    for xx in (-L / 4, L / 4):
        C.tube(fr, [V(xx, -0.10, H + 0.005), V(xx, -0.10, H + 0.10), V(xx, 0.0, H + 0.16)], 0.005, uv, sides=5)
    net = Buf()
    nuv = B("rope", 0.32)
    for yy in (-0.22, -0.075, 0.075, 0.22):
        pts = []
        for j in range(7):
            u = j / 6
            z = 0.035 + (H - 0.035) * math.cos(0.9 * (u - 0.5) * math.pi) * 0.55 + 0.10
            pts.append(V(-L / 2 + L * u, yy * (0.85 + 0.15 * math.cos((u - 0.5) * 3.0)), z))
        C.tube(net, pts, 0.0045, nuv, sides=3)
    for xx in (-0.30, -0.10, 0.10, 0.30):
        pts = [V(xx, -Wd / 2 + 0.01, 0.03), V(xx, -Wd / 2 + 0.01, 0.38), V(xx, 0.0, H + 0.005),
               V(xx, Wd / 2 - 0.01, 0.38), V(xx, Wd / 2 - 0.01, 0.03)]
        C.tube(net, pts, 0.0045, nuv, sides=3)
    return fr, net


def build_creels():
    fr, net = creel_templates()
    bf, bn = Buf(), Buf()
    placements = [
        (-0.55, 1.95, 0.665, 0.03, 0.0), (0.45, 1.95, 0.665, -0.03, 0.0),
        (-0.55, 1.95, 1.105, 0.05, 0.0), (0.45, 1.95, 1.105, -0.02, 0.01),
        (-0.05, 1.95, 1.545, 0.01, 0.0), (0.20, 2.92, 0.66, 0.06, 0.0),
    ]
    for (x, y, z, yaw, tilt) in placements:
        M = Matrix.Translation(Vector((x, y, z))) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(tilt, 4, "X")
        bf.extend(fr, M)
        bn.extend(net, M)
    return bf, bn


def build_fish_boxes():
    b = Buf()
    uv = B("blue", 0.8)

    def box(cx, cy, z0, yaw=0.0):
        M = Matrix.Translation(Vector((cx, cy, z0))) @ Matrix.Rotation(yaw, 4, "Z")
        L, Wd, H = 0.72, 0.44, 0.24
        shell = []
        for z in (0.0, H):
            sh = 0.016 * (1.0 - z / H)
            shell.append([V(-L / 2 + sh, -Wd / 2 + sh, z), V(L / 2 - sh, -Wd / 2 + sh, z),
                          V(L / 2 - sh, Wd / 2 - sh, z), V(-L / 2 + sh, Wd / 2 - sh, z)])
        for i in range(4):
            q = [shell[0][i], shell[0][(i + 1) % 4], shell[1][(i + 1) % 4], shell[1][i]]
            K.oface(b, [M @ p for p in q],
                    [(0.1 + i * 0.1, 0.114), (0.1 + (i + 1) * 0.1, 0.114),
                     (0.1 + (i + 1) * 0.1, 0.172), (0.1 + i * 0.1, 0.172)], (0, 0, 1))
        K.oface(b, [M @ p for p in shell[1]], [(0.2 + j * 0.1, 0.120) for j in range(4)], (0, 0, 1))
        for i in range(4):
            q = [shell[1][i], shell[1][(i + 1) % 4], shell[1][(i + 1) % 4] + V(0.035, 0, 0.035),
                 shell[1][i] + V(0.035, 0, 0.035)]
            K.oface(b, [M @ p for p in q], [(0.1, 0.196), (0.2, 0.196), (0.2, 0.204), (0.1, 0.204)], (0, 0, 1))

    box(0.52, 0.60, deck_z(0.60) + 0.02, 0.12)
    box(0.52, 0.60, deck_z(0.60) + 0.20, 0.10)
    box(-0.62, 0.68, deck_z(0.68) + 0.02, -0.20)
    box(0.60, 1.35, deck_z(1.35) + 0.02, -0.10)
    return b


def build_ropes():
    b = Buf()
    uv = B("rope", 0.55)
    for (cx, cy, turns, rr) in ((0.55, -0.55, 4, 0.24), (0.18, 3.25, 4, 0.24)):
        cz = deck_z(cy) + 0.06
        pts = []
        for i in range(int(turns * 16)):
            a = 2 * math.pi * i / 14.0
            rad = rr - 0.011 * i / (turns * 16)
            pts.append(V(cx + rad * math.cos(a), cy + rad * math.sin(a), cz - 0.004 * (i // 22)))
        C.tube(b, pts, 0.014, uv, sides=5)
    C.tube(b, [V(0.98, CAB_YB - 0.45, 1.26), V(0.94, CAB_YB - 0.70, 1.06), V(0.98, CAB_YB - 0.95, 1.26)], 0.012, uv, sides=5)
    pts = [V(-1.30, -0.94, 1.05), V(-1.62, -0.98, 1.55), V(-1.88, -1.06, 1.90),
           V(-1.90, -1.12, 1.90), V(-1.74, -1.20, 1.25), V(-1.55, -1.32, 0.80)]
    C.tube(b, pts, 0.013, uv, sides=5)
    return b


def build_tyres():
    b = Buf()
    uv = B("dark", 0.5)
    for (y, z, r) in ((0.2, 0.56, 0.27), (1.7, 0.53, 0.25), (3.1, 0.55, 0.27)):
        x = hull_x(y, z) + 0.10
        ring = [V(x, y + r * math.cos(2 * math.pi * i / 14), z + r * math.sin(2 * math.pi * i / 14)) for i in range(14)]
        W.sweep(b, ring, W.round_profile(0.075, 7), uv, closed_path=True, caps=(False, False))
        C.tube(b, [V(x - 0.02, y, z + r + 0.02), V(x - 0.02, y, sheer_z(y) + 0.02)], 0.009, uv, sides=5)
        C.tube(b, [V(x - 0.03, y, z + r + 0.01), V(x - 0.03, y + r * 0.9, z + r * 0.55)], 0.009, uv, sides=5)
    return b


def build_buoys():
    red, white, wood = Buf(), Buf(), Buf()
    uv = B("varnish", 0.5)
    v0, v1 = BANDS["antifoul"]
    w0, w1 = BANDS["white"]
    for (x, y, z, h, tilt) in ((-0.62, 3.95, 0.72, 1.30, 0.10), (0.58, 4.12, 0.72, 1.22, -0.06),
                               (0.02, 3.72, 0.72, 1.15, 0.04), (-0.18, 4.28, 0.72, 1.05, -0.12)):
        M = Matrix.Translation(Vector((x, y, z))) @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Rotation(tilt * 0.5, 4, "X")
        prof = [(0.02, 0.0), (0.09, 0.01), (0.105, 0.06), (0.105, 0.20), (0.085, 0.27), (0.04, 0.29), (0.028, 0.30)]
        tmp = Buf()
        W.lathe(tmp, prof, 12, lambda k, a: (a * 0.30, v0 + 0.006 + (v1 - v0 - 0.012) * k / 6))
        red.extend(tmp, M)
        tmp = Buf()
        W.lathe(tmp, [(0.104, 0.11), (0.104, 0.155)], 12, lambda k, a: (a * 0.30, w0 + 0.006 + 0.012 * k))
        white.extend(tmp, M)
        tmp = Buf()
        C.tube(tmp, [V(0, 0, 0.28), V(0, 0, h)], 0.015, uv, sides=5)
        C.tube(tmp, [V(0, 0, 0.30), V(0, 0, 0.34)], 0.028, uv, sides=6)
        wood.extend(tmp, M)
        flag = [V(0, 0, h), V(0.28, 0.01, h - 0.03), V(0.02, 0.02, h - 0.20)]
        K.oface(red, [M @ p for p in flag], [(0.02, 0.02), (0.06, 0.02), (0.06, 0.06)], (0, 1, 0))
        K.oface(red, [M @ p for p in flag], [(0.02, 0.02), (0.06, 0.02), (0.06, 0.06)], (0, -1, 0))
    return red, white, wood


def build_lifebuoy(lb, strip, trim):
    uv = B("white", 0.4)
    c = V(-0.55, CAB_YB + 0.10, CAB_BASE + 1.45)
    ring = [c + V(0.30 * math.cos(2 * math.pi * i / 16), 0, 0.30 * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    W.sweep(lb, ring, W.round_profile(0.072, 7), uv, closed_path=True, caps=(False, False))
    for k in range(4):
        a = 2 * math.pi * k / 4
        p = c + V(0.30 * math.cos(a), -0.075, 0.30 * math.sin(a))
        K.oface(strip, [p + V(0.05 * math.cos(a + 1.4), 0, 0.05 * math.sin(a + 1.4)),
                        p + V(0.05 * math.cos(a - 1.4), 0, 0.05 * math.sin(a - 1.4)),
                        p + V(-0.05 * math.cos(a + 1.4), 0, -0.05 * math.sin(a + 1.4)),
                        p + V(-0.05 * math.cos(a - 1.4), 0, -0.05 * math.sin(a - 1.4))],
                [(0.01, 0.01), (0.03, 0.01), (0.03, 0.03), (0.01, 0.03)], (0, -1, 0))
    C.tube(trim, [c + V(-0.12, 0.02, 0.34), c + V(0.12, 0.02, 0.34)], 0.010, B("metal", 0.4), sides=5)
    C.tube(trim, [c + V(-0.30, 0.0, 0.0), c + V(-0.30, 0.0, -0.12)], 0.006, B("metal", 0.4), sides=4)


def build_hauler_winch():
    b = Buf()
    d = Buf()
    uv = B("metal", 0.7)
    pts = [V(-1.18, -1.10, deck_z(-1.10)), V(-1.18, -1.10, 1.92), V(-1.36, -1.10, 2.06),
           V(-1.78, -1.10, 2.04), V(-1.90, -1.10, 1.90)]
    C.tube(b, pts, 0.052, uv, sides=8)
    C.tube(b, [V(-1.18, -1.10, 1.10), V(-1.42, -1.10, 1.86)], 0.028, uv, sides=6)
    C.tube(b, [V(-1.18, -1.10, deck_z(-1.10) + 0.02), V(-1.18, -1.10, deck_z(-1.10) + 0.18)], 0.10, uv, sides=10)
    C.tube(b, [V(-1.945, -1.10, 1.80), V(-1.835, -1.10, 1.80)], 0.090, uv, sides=12)
    for sx in (-1.952, -1.828):
        C.tube(b, [V(sx, -1.10, 1.80), V(sx + 0.012, -1.10, 1.80)], 0.125, uv, sides=12)
    C.tube(b, [V(-1.89, -1.10, 1.80), V(-1.89, -1.10, 1.86)], 0.080, uv, sides=10)
    W.obox(b, (-1.27, -0.90, 0.95), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.19, 0.20, 0.15), uv)
    uv2 = B("dark", 0.5)
    C.tube(d, [V(-1.32, -1.02, 1.02), V(-1.32, -0.50, 1.02)], 0.125, uv2, sides=12)
    for yy in (-0.98, -0.55):
        C.tube(d, [V(-1.32, yy, 1.02), V(-1.32, yy + 0.02, 1.02)], 0.155, uv2, sides=12)
    C.tube(b, [V(-1.32, -0.50, 1.02), V(-1.32, -0.44, 1.02)], 0.075, uv, sides=8)
    W.obox(b, (-1.27, -0.66, 1.28), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.13, 0.11, 0.07), uv)
    C.tube(d, [V(-1.10, -0.80, 1.10), V(-1.02, -0.40, 1.05), V(-0.96, -0.10, 0.82)], 0.018, uv2, sides=5)
    C.tube(d, [V(-1.10, -0.86, 1.00), V(-1.00, -0.55, 0.86), V(-0.95, -0.30, 0.74)], 0.016, uv2, sides=5)
    return b, d


def build_weed():
    b = Buf()
    uv = B("weed", 0.9)
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(20, 0.02, 0.98):
            p0 = sec(y, s_at_z(y, -0.015), side, 0.006)
            p1 = sec(y, s_at_z(y, 0.045 + 0.010 * math.sin(y * 2.7)), side, 0.006)
            rr.append([p0, p1])
            uu.append([((y - L0) / 1.5, BANDS["weed"][0] + 0.005),
                       ((y - L0) / 1.5, BANDS["weed"][1] - 0.005)])
        K.ogrid(b, rr, uu, lambda c: Vector((c.x, 0, -0.4)))
        for y in (-4.5, -4.0, -3.4, -2.7, -2.0, -1.2, -0.4, 0.4, 1.2, 2.0, 2.9, 3.7, 4.4):
            x = hull_x(y, -0.01, side)
            for j in range(3):
                yy = y + (j - 1) * 0.07
                p0 = V(x + side * 0.004, yy, -0.005)
                p1 = V(x + side * 0.02, yy + (j - 1) * 0.02, -0.06)
                p2 = V(x + side * 0.035, yy + (j - 1) * 0.04, -0.14 - 0.02 * (j % 2))
                W.sweep(b, [p0, p1, p2], W.round_profile(0.005, 4), uv, scale=[1.0, 0.6, 0.15],
                        caps=(True, True), smooth=True)
    return b


GLYPHS = {
    "M": [(0, 0, 0, 1), (0, 1, 0.5, 0.38), (0.5, 0.38, 1, 1), (1, 1, 1, 0)],
    "O": [(0.18, 0, 0.82, 0), (0.82, 0, 1, 0.18), (1, 0.18, 1, 0.82), (1, 0.82, 0.82, 1),
          (0.82, 1, 0.18, 1), (0.18, 1, 0, 0.82), (0, 0.82, 0, 0.18), (0, 0.18, 0.18, 0)],
    "R": [(0, 0, 0, 1), (0, 1, 0.70, 1), (0.70, 1, 0.82, 0.86), (0.82, 0.86, 0.82, 0.64),
          (0.82, 0.64, 0.70, 0.52), (0.70, 0.52, 0, 0.52), (0.44, 0.52, 1, 0)],
    "W": [(0, 1, 0.22, 0), (0.22, 0, 0.5, 0.56), (0.5, 0.56, 0.78, 0), (0.78, 0, 1, 1)],
    "E": [(1, 0, 0, 0), (0, 0, 0, 1), (0, 1, 1, 1), (0, 0.5, 0.82, 0.5)],
    "N": [(0, 0, 0, 1), (0, 1, 1, 0), (1, 0, 1, 1)],
    "A": [(0, 0, 0.5, 1), (0.5, 1, 1, 0), (0.14, 0.42, 0.86, 0.42)],
    "S": [(1, 1, 0.15, 1), (0.15, 1, 0, 0.82), (0, 0.82, 0, 0.64), (0, 0.64, 0.20, 0.50),
          (0.20, 0.50, 0.80, 0.50), (0.80, 0.50, 1, 0.36), (1, 0.36, 1, 0.16), (1, 0.16, 0.84, 0), (0.84, 0, 0, 0)],
    "P": [(0, 0, 0, 1), (0, 1, 0.72, 1), (0.72, 1, 0.85, 0.86), (0.85, 0.86, 0.85, 0.64),
          (0.85, 0.64, 0.72, 0.52), (0.72, 0.52, 0, 0.52)],
    "H": [(0, 0, 0, 1), (1, 0, 1, 1), (0, 0.5, 1, 0.5)],
    "1": [(0.20, 0.80, 0.50, 1), (0.50, 1, 0.50, 0), (0.28, 0, 0.76, 0)],
    "7": [(0, 1, 1, 1), (1, 1, 0.34, 0)],
    "3": [(0, 1, 0.9, 1), (0.9, 1, 0.9, 0.55), (0.9, 0.55, 0.20, 0.55), (0.9, 0.55, 0.9, 0),
          (0.9, 0, 0, 0)],
    " ": [],
}


def paint_text(b, text, ystart, direc, side, cellw, cellh, z_of_y, thick=0.013):
    u = 0.0
    for ch in text:
        for (ax, az, bx, bz) in GLYPHS.get(ch, []):
            y0 = ystart + direc * (u + ax * cellw)
            y1 = ystart + direc * (u + bx * cellw)
            z0 = z_of_y(y0) + az * cellh
            z1 = z_of_y(y1) + bz * cellh
            dy, dz = y1 - y0, z1 - z0
            ln = math.hypot(dy, dz) or 1.0
            ny, nz = -dz / ln * thick, dy / ln * thick
            ty, tz = dy / ln * thick, dz / ln * thick
            corners = [(y0 - ty + ny, z0 - tz + nz), (y1 + ty + ny, z1 + tz + nz),
                       (y1 + ty - ny, z1 + tz - nz), (y0 - ty - ny, z0 - tz - nz)]
            pts = [V(hull_x(y, z, side) + side * 0.014, y, z) for (y, z) in corners]
            K.oface(b, pts, [(0.955, 0.947), (0.968, 0.947), (0.968, 0.958), (0.955, 0.958)], (side, 0, 0))
        u += cellw * 1.26


def paint_transom_text(b, text, xstart, direc, cellw, cellh, zbase, y_of_z, thick=0.012):
    u = 0.0
    for ch in text:
        for (ax, az, bx, bz) in GLYPHS.get(ch, []):
            x0 = xstart + direc * (u + ax * cellw)
            x1 = xstart + direc * (u + bx * cellw)
            z0 = zbase + az * cellh
            z1 = zbase + bz * cellh
            dx, dz = x1 - x0, z1 - z0
            ln = math.hypot(dx, dz) or 1.0
            nx, nz = -dz / ln * thick, dx / ln * thick
            tx, tz = dx / ln * thick, dz / ln * thick
            corners = [(x0 - tx + nx, z0 - tz + nz), (x1 + tx + nx, z1 + tz + nz),
                       (x1 + tx - nx, z1 + tz - nz), (x0 - tx - nx, z0 - tz - nz)]
            pts = [V(x, y_of_z(z), z) for (x, z) in corners]
            K.oface(b, pts, [(0.955, 0.947), (0.968, 0.947), (0.968, 0.958), (0.955, 0.958)], (0, 1, 0))
        u += cellw * 1.26


def build_letters():
    b = Buf()
    n = len("MORWENNA ROSE") * 0.105 * 1.26
    r = len("PH 117") * 0.090 * 1.26
    for side, start_name, start_reg in ((1, -4.94, -4.92), (-1, -4.94 + n, -4.92 + r)):
        direc = 1 if side > 0 else -1

        def zname(y):
            return 1.00 + 0.22 * max(0.0, (-3.8 - y) / 1.1) ** 1.2

        paint_text(b, "MORWENNA ROSE", start_name, direc, side, 0.105, 0.205, zname)
        paint_text(b, "PH 117", start_reg, direc, side, 0.090, 0.150, lambda y: zname(y) - 0.235, thick=0.010)

    def yt(z):
        zk, zs = keel_z(L1), sheer_z(L1)
        return L1 + 0.016 + 0.078 * cl((z - zk) / (zs - zk))

    paint_transom_text(b, "MORWENNA ROSE", 0.80, -1, 0.10, 0.145, 0.86, yt)
    paint_transom_text(b, "PH 117", 0.62, -1, 0.085, 0.115, 0.69, yt, thick=0.009)
    return b


def _ci(node, k):
    return [i for i in node.inputs if i.type == "RGBA"][k]


def _co(node):
    return [o for o in node.outputs if o.type == "RGBA"][0]


def hex_srgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def material(key):
    name = "MI_Crabber_" + key
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes.get("Principled BSDF")
    col = hex_srgb(COLORS[key])
    p.inputs["Base Color"].default_value = (*[c ** 2.2 for c in col], 1.0)
    p.inputs["Roughness"].default_value = SLOT[key][1]
    p.inputs["Metallic"].default_value = SLOT[key][0]
    spec = PROC.get(key)
    if not spec:
        return m
    L = nt.links.new
    N = nt.nodes.new
    tc = N("ShaderNodeTexCoord")
    coord = tc.outputs["Object"]
    cvec = coord
    if spec.get("grain"):
        mp = N("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (7.0, 0.22, 7.0)
        L(coord, mp.inputs["Vector"])
        cvec = mp.outputs[0]
    scale, amt = spec.get("mottle", (4.0, 0.05))
    nz = N("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 6.0
    nz.inputs["Roughness"].default_value = 0.62
    L(cvec, nz.inputs["Vector"])
    dark = N("ShaderNodeRGB")
    dark.outputs[0].default_value = tuple(c * (1 - amt * 1.8) for c in col) + (1.0,)
    lite = N("ShaderNodeRGB")
    lite.outputs[0].default_value = tuple(min(1.0, c * (1 + amt * 0.8)) for c in col) + (1.0,)
    mix = N("ShaderNodeMix")
    mix.data_type = "RGBA"
    L(nz.outputs["Fac"], mix.inputs["Factor"])
    L(dark.outputs[0], _ci(mix, 0))
    L(lite.outputs[0], _ci(mix, 1))
    c = _co(mix)
    if "grime" in spec:
        gc, ga = spec["grime"]
        mp = N("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (5.0, 0.30, 5.0) if spec.get("grain") else (9.0, 9.0, 0.35)
        L(coord, mp.inputs["Vector"])
        g = N("ShaderNodeTexNoise")
        g.inputs["Scale"].default_value = 1.2 if spec.get("grain") else 1.8
        g.inputs["Detail"].default_value = 7.0
        g.inputs["Roughness"].default_value = 0.6
        L(mp.outputs[0], g.inputs["Vector"])
        mr = N("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = 0.52, 0.70
        mr.inputs["To Max"].default_value = ga
        L(g.outputs["Fac"], mr.inputs["Value"])
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = hex_srgb(gc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(mr.outputs[0], mx.inputs["Factor"])
        L(c, _ci(mx, 0))
        L(gcol.outputs[0], _ci(mx, 1))
        c = _co(mx)
    if "salt" in spec:
        sc, sa = spec["salt"]
        g = N("ShaderNodeTexNoise")
        g.inputs["Scale"].default_value = 2.4
        g.inputs["Detail"].default_value = 3.0
        L(coord, g.inputs["Vector"])
        mr = N("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = 0.60, 0.78
        mr.inputs["To Max"].default_value = sa
        L(g.outputs["Fac"], mr.inputs["Value"])
        gcol = N("ShaderNodeRGB")
        gcol.outputs[0].default_value = hex_srgb(sc) + (1.0,)
        mx = N("ShaderNodeMix")
        mx.data_type = "RGBA"
        L(mr.outputs[0], mx.inputs["Factor"])
        L(c, _ci(mx, 0))
        L(gcol.outputs[0], _ci(mx, 1))
        c = _co(mx)
    out = N("ShaderNodeGamma")
    out.name = "BAKE_BASE"
    out.inputs["Gamma"].default_value = 1.0
    L(c, out.inputs["Color"])
    rgh = N("ShaderNodeTexNoise")
    rgh.inputs["Scale"].default_value = 3.0
    rgh.inputs["Detail"].default_value = 3.0
    L(coord, rgh.inputs["Vector"])
    mr2 = N("ShaderNodeMapRange")
    mr2.inputs["From Min"].default_value, mr2.inputs["From Max"].default_value = 0.25, 0.75
    mr2.inputs["To Min"].default_value = max(0.05, SLOT[key][1] - 0.10)
    mr2.inputs["To Max"].default_value = min(1.0, SLOT[key][1] + 0.10)
    L(rgh.outputs["Fac"], mr2.inputs["Value"])
    cmb = N("ShaderNodeCombineXYZ")
    cmb.name = "BAKE_MR"
    cmb.inputs["X"].default_value = SLOT[key][0]
    L(mr2.outputs[0], cmb.inputs["Y"])
    m["bake_custom"] = 1
    return m


def make_spec(parts, col, atts, hps=()):
    vis = list(parts.values())
    lo, hi = W.bbox(vis)
    dims = tuple((hi[i] - lo[i]) / S for i in range(3))
    for o in vis + [col]:
        K.fix_uv(o)
    print("[boat] bbox studs %.3f x %.3f x %.3f  m %.3f x %.3f x %.3f" % (tuple(hi - lo) + dims))
    print("[boat] tris %s total %d" % ({k: C.tri_count(o) for k, o in parts.items()},
                                       sum(C.tri_count(o) for o in vis)))
    meshes = [{"object": o, "set": "Atlas"} for o in vis] + [{"object": col}]
    meshes += [{"object": o, "role": "hp"} for o in hps]
    slots = {("MI_Crabber_" + k): {"base_color": COLORS[k], "metal": SLOT[k][0], "roughness": SLOT[k][1]}
             for k in COLORS}
    return {
        "name": NAME, "asset": NAME, "budget": BUDGET, "tris": BUDGET_TRIS, "tier": "standard",
        "dims_m": dims, "size_note": None, "origin": "free",
        "sets": [{"name": "FishingBoat", "set": "Atlas", "size": 2048, "wet": True, "slots": slots,
                  "wear": {"edge": 0.56, "edge_range": (0.13, 0.48), "edge_color": (0.57, 0.54, 0.47),
                           "edge_rough": 0.66, "salt": 0.19, "salt_range": (0.36, 0.80),
                           "salt_color": (0.71, 0.69, 0.62), "rust": 0.10, "rust_color": (0.40, 0.29, 0.21),
                           "rust_rough": 0.88, "rust_length": 0.44, "rust_fingers": 8, "ao_strength": 0.28}}],
        "atlas": "FishingBoat", "meshes": meshes, "attachments": atts, "bake_size": 2048,
        "tiling": True,
        "closeups": [
            {"name": "bow", "target": [0.0, -13.5, 4.2], "dist": 11.0, "az": 40, "el": 12},
            {"name": "wheelhouse", "target": [0.0, -8.4, 5.4], "dist": 13.0, "az": 128, "el": 16},
            {"name": "deck", "target": [0.0, 5.4, 3.4], "dist": 15.0, "az": 24, "el": 36},
            {"name": "hauler", "target": [-4.3, -3.0, 4.2], "dist": 9.0, "az": 200, "el": 20},
        ],
        "waivers": {"LOD UV layout": "trim-sheet bands tile in U; decimation keeps the same bands, islands move"},
    }


def clean_part(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=list(bm.edges))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()


_orig_run_lod = versions.run_lod
_orig_decimate = versions.decimate


def _decimate_tolerant(obj, target, symmetry=None):
    try:
        _orig_decimate(obj, target, symmetry)
    except RuntimeError:
        obj["lod_failed"] = 1
        print("[boat] %s: could not reach %d tris; proxied at LOD2" % (obj.name, target))


def lod_proxy(o):
    lo, hi = W.bbox([o])
    c = (lo + hi) / 2
    mats = [m for m in o.data.materials]
    bm = bmesh.new()
    d = 0.03
    vs = [bm.verts.new(c + Vector(v)) for v in ((-d, 0, -d), (d, 0, -d), (d, 0, d), (-d, 0, d))]
    f = bm.faces.new(vs)
    lay = bm.loops.layers.uv.new("UVMap")
    for l, uv in zip(f.loops, ((0.5, 0.5), (0.51, 0.5), (0.51, 0.51), (0.5, 0.51))):
        l[lay].uv = uv
    old = o.data
    mname = old.name
    me = bpy.data.meshes.new(mname + "_proxy")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    o.data = me
    bpy.data.meshes.remove(old)
    me.name = mname
    me.update()


def _run_lod_clean(spec):
    made = _orig_run_lod(spec)
    for o in list(bpy.data.objects):
        if o.type != "MESH" or not o.name.startswith("M_Veh_MooredBoat_"):
            continue
        if o.get("lod_failed") and o.name.endswith("_LOD2"):
            lod_proxy(o)
        if not (o.name.endswith("_LOD1") or o.name.endswith("_LOD2")):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=list(bm.edges))
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
        K.fix_uv(o, eps=2e-3)
    return made


if not getattr(versions, "_mooredboat2_clean", False):
    versions.run_lod = _run_lod_clean
    versions.decimate = _decimate_tolerant
    versions._mooredboat2_clean = True


def patch_bake():
    import numpy as np
    import bake
    if getattr(bake, "_mooredboat2_flat_nor", False):
        return
    orig = bake.finish_maps

    def flat_nor(baked, covered, size, set_spec):
        maps, masks = orig(baked, covered, size, set_spec)
        maps[("NOR", False)] = np.full((size, size, 3), (0.5, 0.5, 1.0), dtype=np.float32)
        return maps, masks

    bake.finish_maps = flat_nor
    bake._mooredboat2_flat_nor = True


def build():
    patch_bake()
    C.clear_scene()
    bufs = {}
    bufs.update(build_hull())
    bufs["DeckInner"] = build_deck_inner()
    bufs["CapRail"] = build_cap_rail()
    bufs["Cabin"] = build_cabin()
    roof, roof_trim = build_roof()
    bufs["Roof"] = roof
    bufs["RoofTrim"] = roof_trim
    glass = {"front": Buf(), "side": Buf(), "rear": Buf()}
    trim = Buf()
    build_windows(glass, trim)
    bufs["GlassFront"] = glass["front"]
    bufs["GlassSide"] = glass["side"]
    bufs["GlassRear"] = glass["rear"]
    bufs["CabinTrim"] = trim
    bufs["CabinTrim2"] = build_cabin_trim()
    bufs["Mast"] = build_mast_gear()
    bufs["Radome"] = build_radome()
    nav_d, nav_r, nav_g = build_nav_lights()
    bufs["NavDark"] = nav_d
    bufs["NavRed"] = nav_r
    bufs["NavGreen"] = nav_g
    bufs["Fittings"] = build_fittings()
    hatch, hatch_trim = build_hatches()
    bufs["Hatches"] = hatch
    bufs["HatchTrim"] = hatch_trim
    bf, bn = build_creels()
    bufs["CreelFrames"] = bf
    bufs["CreelNet"] = bn
    bufs["FishBoxes"] = build_fish_boxes()
    bufs["Ropes"] = build_ropes()
    bufs["Tyres"] = build_tyres()
    br, bw, bwd = build_buoys()
    bufs["Buoys"] = br
    bufs["BuoyBands"] = bw
    bufs["Dhan"] = bwd
    lb, lstrip, ltrim = Buf(), Buf(), Buf()
    build_lifebuoy(lb, lstrip, ltrim)
    bufs["Lifebuoy"] = lb
    bufs["LifebuoyBand"] = lstrip
    bufs["LifebuoyTrim"] = ltrim
    hauler, hauler_drum = build_hauler_winch()
    bufs["Hauler"] = hauler
    bufs["HaulerDrum"] = hauler_drum
    bufs["Weed"] = build_weed()
    bufs["Letters"] = build_letters()

    mat_of = {
        "HullAntifoul": "Antifoul", "HullTopsides": "Navy", "HullStripe": "Sheer", "BootTop": "White",
        "DeckInner": "Inner", "CapRail": "Varnish", "Cabin": "Cream", "Roof": "Sheer",
        "GlassFront": "Glass", "GlassSide": "Glass", "GlassRear": "Glass",
        "CabinTrim": "Metal", "CabinTrim2": "Metal", "Mast": "Metal", "Radome": "Cream",
        "NavDark": "Dark", "NavRed": "Antifoul", "NavGreen": "Green",
        "Fittings": "Metal", "Hatches": "Inner", "HatchTrim": "Metal",
        "CreelFrames": "Navy", "CreelNet": "Rope", "RoofTrim": "Metal",
        "FishBoxes": "Navy", "Ropes": "Rope", "Tyres": "Dark",
        "Buoys": "Antifoul", "BuoyBands": "White", "Dhan": "Varnish",
        "Lifebuoy": "White", "LifebuoyBand": "Antifoul", "LifebuoyTrim": "Metal",
        "Hauler": "Metal", "HaulerDrum": "Dark", "Weed": "Weed", "Letters": "White",
    }
    parts = {}
    for k, buf in bufs.items():
        parts[k] = buf.to_object("M_Veh_MooredBoat_%s_02_LOD0" % k, material(mat_of[k]).name)
    K.finish(NAME, parts, recalc=("Fittings", "Hauler", "CabinTrim2", "NavDark", "NavRed", "NavGreen"))
    for o in parts.values():
        clean_part(o)
    hps = []
    for o in parts.values():
        hp = o.copy()
        hp.data = o.data.copy()
        hp.name = o.name[:-5] + "_HP"
        hp.data.name = hp.name
        for c in o.users_collection:
            c.objects.link(hp)
        hps.append(hp)
    atts = [W.empty("ATT_Waterline", (0, 0, 0)),
            W.empty("ATT_Moor_Bow", (0, -4.35, deck_z(-4.35) + 0.10), look=(0, -1, 0)),
            W.empty("ATT_Moor_Stern", (1.14, 4.18, sheer_z(4.18) + 0.12), look=(0, 1, 0)),
            W.empty("ATT_Boarding_Port", (1.42, 0.4, 1.20), look=(1, 0, 0)),
            W.empty("ATT_Boarding_Stbd", (-1.42, 0.4, 1.20), look=(-1, 0, 0))]
    I = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    col = W.col_boxes([((0, -0.05, 0.20), I, (1.60, 4.90, 1.30)),
                       ((0, -2.84, 1.62), I, (1.08, 1.06, 0.98))], "M_Veh_MooredBoat_Hull_02_COL")
    return make_spec(parts, col, atts, hps)





