"""C3 M_Veh_MooredBoat_03: a 15 m Cornish steel stern trawler (1970s-90s type), moored set dressing.

Faded black topsides, ivory boot-top and sheer lines, red antifouling, white panel-seamed wheelhouse, raised
whaleback forecastle and an open working deck aft with a stern A-frame gantry, net drum with green/orange net,
trawl winch, gallows, warps, otter boards, mast with derrick, radar bar and nav lights. Painted "PH 42" and
"GALE ISLE PROVIDER" on both bows and the transom. Shared T_FishingBoat_Atlas (2048): _01's/_02's bands and
files are untouched.

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

NAME = "M_Veh_MooredBoat_03"
BUDGET, BUDGET_TRIS = "small_craft", 25000
S = 3.0
L0, L1 = -7.50, 7.50
BEAM = 2.05

BANDS = {
    "antifoul": (0.000, 0.100), "blue": (0.100, 0.240), "sheer": (0.240, 0.310),
    "inner": (0.310, 0.390), "varnish": (0.390, 0.530), "wood": (0.530, 0.620),
    "metal": (0.620, 0.690), "motor": (0.690, 0.770), "dark": (0.770, 0.825),
    "rope": (0.825, 0.875), "water": (0.875, 0.905), "weed": (0.905, 0.945),
    "white": (0.945, 0.972), "bailer": (0.972, 1.000),
}
B = K.bandfn(BANDS)

COLORS = {
    "Antifoul": "#6B332A", "Navy": "#2B2F30", "Sheer": "#D9D5C7", "Inner": "#74736B",
    "Varnish": "#8A6038", "Wood": "#6D5941", "Metal": "#8E918C", "Cream": "#C4BFA9",
    "Dark": "#2D3032", "Rope": "#9E8A64", "Glass": "#1F2D2B", "Weed": "#46582A",
    "White": "#E3E0D4", "Green": "#3D6B4D", "Motor": "#A95A33", "Rust": "#4F3526",
}
SLOT = {
    "Antifoul": (0.0, 0.78), "Navy": (0.0, 0.48), "Sheer": (0.0, 0.60), "Inner": (0.0, 0.72),
    "Varnish": (0.0, 0.58), "Wood": (0.0, 0.82), "Metal": (1.0, 0.42), "Cream": (0.0, 0.55),
    "Dark": (0.0, 0.82), "Rope": (0.0, 0.90), "Glass": (0.0, 0.08), "Weed": (0.0, 0.86),
    "White": (0.0, 0.55), "Green": (0.0, 0.60), "Motor": (0.0, 0.62), "Rust": (0.0, 0.90),
}
PROC = {
    "Antifoul": dict(mottle=(3.0, 0.09), grime=("#43211D", 0.34), salt=("#8B8072", 0.22)),
    "Navy": dict(mottle=(2.6, 0.07), grime=("#15191A", 0.28), salt=("#9CA09B", 0.22)),
    "Sheer": dict(mottle=(4.0, 0.045), grime=("#AEA99A", 0.30), salt=("#ABA89B", 0.18)),
    "Inner": dict(mottle=(5.0, 0.09), grime=("#54534C", 0.34), salt=("#8D8B80", 0.20)),
    "Varnish": dict(mottle=(4.5, 0.06), grain=("#62441F", 0.26), salt=("#A79E8A", 0.14)),
    "Wood": dict(mottle=(3.0, 0.08), grain=("#4E3F2C", 0.26), salt=("#978D79", 0.18)),
    "Metal": dict(mottle=(6.0, 0.05), grime=("#656963", 0.28)),
    "Cream": dict(mottle=(4.5, 0.05), grime=("#8E8B7C", 0.24)),
    "Dark": dict(mottle=(6.0, 0.04), grime=("#1E2122", 0.22)),
    "Rope": dict(mottle=(9.0, 0.07), grime=("#6E5F44", 0.24)),
    "Glass": dict(mottle=(2.2, 0.03)),
    "Weed": dict(mottle=(7.0, 0.12), grime=("#3A4724", 0.30)),
    "White": dict(mottle=(4.5, 0.04), grime=("#C0BCAD", 0.24), salt=("#BDB9AA", 0.14)),
    "Green": dict(mottle=(6.0, 0.05), grime=("#2C4F39", 0.22)),
    "Motor": dict(mottle=(4.0, 0.06), grime=("#7C3F24", 0.26), salt=("#A99A86", 0.14)),
    "Rust": dict(mottle=(7.0, 0.14), grime=("#33200F", 0.30), salt=("#7B6450", 0.10)),
}


def cl(x, a=0.0, b=1.0):
    return min(max(x, a), b)


def t_of(y):
    return (y - L0) / (L1 - L0)


def half_beam(y):
    t = cl(t_of(y))
    if t < 0.42:
        return BEAM * math.sin(0.5 * math.pi * t / 0.42) ** 0.82 * (0.94 + 0.06 * t / 0.42)
    if t < 0.80:
        return BEAM + 0.025 * math.sin(math.pi * (t - 0.42) / 0.38)
    return BEAM - (BEAM - 1.86) * ((t - 0.80) / 0.20) ** 1.7


def sheer_z(y):
    t = cl(t_of(y))
    return 2.36 + 1.02 * max(0.0, (0.30 - t) / 0.30) ** 1.55 + 0.04 * max(0.0, (t - 0.90) / 0.10) ** 2


def keel_z(y):
    t = cl(t_of(y))
    return -2.05 + 0.95 * max(0.0, (0.22 - t) / 0.22) ** 1.7 + 0.35 * max(0.0, (t - 0.80) / 0.20) ** 1.6


def deck_z(y):
    t = cl(t_of(y))
    return 1.55 + 0.55 * max(0.0, (0.30 - t) / 0.30) ** 1.5


def flare_of(y):
    t = cl(t_of(y))
    return 0.16 * max(0.0, (0.40 - t) / 0.40) ** 1.6


def sec_raw(y, s):
    w = half_beam(y)
    z0 = keel_z(y)
    h = sheer_z(y) - z0
    x = w * max(math.sin(0.5 * math.pi * s), 0.0) ** 0.64 * (1.0 + flare_of(y) * s * s)
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


def stations(n=20, a=0.010, b=0.995):
    return [L0 + (L1 - L0) * (a + (b - a) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1)))) for i in range(n)]


def _zlim(v, y):
    return v(y) if callable(v) else v


def hull_band(b, band, zlo, zhi, tu, uoff, nrows, off=0.0):
    v0, v1 = BANDS[band]
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(24):
            zl, zh = _zlim(zlo, y), _zlim(zhi, y)
            s0 = 0.0 if zl <= keel_z(y) + 1e-4 else s_at_z(y, zl)
            s1 = 1.0 if zh >= sheer_z(y) - 1e-4 else s_at_z(y, zh)
            rr.append([sec(y, s0 + (s1 - s0) * j / (nrows - 1), side, off) for j in range(nrows)])
            uu.append([((y - L0) / tu + uoff, v0 + 0.004 + (v1 - v0 - 0.008) * j / (nrows - 1))
                       for j in range(nrows)])
        K.ogrid(b, rr, uu, lambda c: Vector((c.x, 0.0, (c.z - 0.4) * 0.1)))


def transom_grid(b, zlo, zhi, band, nrows):
    v0, v1 = BANDS[band]
    zk, zs = keel_z(L1), sheer_z(L1)
    rr, uu = [], []
    for k in range(nrows):
        f = k / (nrows - 1)
        z = _zlim(zlo, L1) + (_zlim(zhi, L1) - _zlim(zlo, L1)) * f
        ff = cl((z - zk) / max(zs - zk, 1e-5))
        yy = L1 + 0.010 + 0.085 * ff
        hw = hull_x(L1 - 0.02, z)
        rr.append([V(-hw + 2 * hw * j / 10, yy, z) for j in range(11)])
        uu.append([(0.84 + 0.15 * (j / 10), v0 + 0.004 + (v1 - v0 - 0.008) * f) for j in range(11)])
    K.ogrid(b, rr, uu, (0, 1, 0))


def bow_face(b, zlo, zhi, band, nrows=3):
    y0 = stations(24)[0]
    v0, v1 = BANDS[band]
    rr, uu = [], []
    for k in range(nrows):
        z = zlo + (zhi - zlo) * k / (nrows - 1)
        hw = hull_x(y0, z)
        f = cl((z - keel_z(y0)) / max(sheer_z(y0) - keel_z(y0), 1e-5))
        apex = y0 - 0.19 * f
        rr.append([V(-hw, y0, z), V(0, apex, z), V(hw, y0, z)])
        uu.append([(0.805, v0 + 0.004 + (v1 - v0 - 0.008) * k / (nrows - 1)),
                   (0.810, v0 + 0.004 + (v1 - v0 - 0.008) * k / (nrows - 1)),
                   (0.815, v0 + 0.004 + (v1 - v0 - 0.008) * k / (nrows - 1))])
    K.ogrid(b, rr, uu, (0, -1, 0))


def build_hull():
    anti, black, boot, stripe = Buf(), Buf(), Buf(), Buf()
    hull_band(anti, "antifoul", keel_z, 0.10, 18.75, 0.0, 5)
    transom_grid(anti, keel_z, 0.10, "antifoul", 3)
    hull_band(black, "blue", 0.20, lambda y: sheer_z(y) - 0.17, 18.75, 0.0, 8)
    transom_grid(black, 0.20, lambda y: sheer_z(y) - 0.17, "blue", 8)
    hull_band(boot, "white", 0.10, 0.20, 18.75, 0.0, 2, off=0.004)
    transom_grid(boot, 0.10, 0.20, "white", 2)
    hull_band(stripe, "sheer", lambda y: sheer_z(y) - 0.17, lambda y: sheer_z(y) - 0.08, 18.75, 0.0, 2, off=0.005)
    transom_grid(stripe, lambda y: sheer_z(y) - 0.17, lambda y: sheer_z(y) - 0.08, "sheer", 2)
    bow_face(anti, keel_z(stations(24)[0]), 0.10, "antifoul", 3)
    bow_face(boot, 0.10, 0.20, "white", 2)
    bow_face(black, 0.20, sheer_z(stations(24)[0]) - 0.17, "blue", 6)
    bow_face(stripe, sheer_z(stations(24)[0]) - 0.17, sheer_z(stations(24)[0]) - 0.08, "sheer", 2)
    return {"HullAntifoul": anti, "HullTopsides": black, "BootTop": boot, "HullStripe": stripe}


def build_keel():
    b = Buf()
    kd = Buf()
    uv = B("metal", 0.9)
    pts = [V(0, y, keel_z(y) - 0.02) for y in stations(14, 0.01, 0.985)]
    W.sweep(b, pts, W.rect_profile(0.13, 0.12, 0.02), uv, axes=[((1, 0, 0), (0, 0, 1))] * len(pts),
            caps=(True, True))
    uv2 = B("dark", 0.5)
    W.sweep(kd, [V(0, 6.95, -0.35), V(0, 7.62, -1.42), V(0, 7.66, -1.05), V(0, 7.62, -0.55)],
            W.rect_profile(0.06, 0.5, 0.02), uv2, axes=[((1, 0, 0), (0, 1, 0))] * 4, caps=(True, True))
    C.tube(kd, [V(0, 7.05, -0.88), V(0, 6.55, -0.88)], 0.16, uv2, sides=10)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.3
        dirv = Vector((0, math.cos(a), math.sin(a)))
        W.sweep(kd, [V(0, 6.78, -0.88), V(0, 6.78, -0.88) + dirv * 0.42],
                W.rect_profile(0.16, 0.035, 0.01), uv2,
                axes=[((1, 0, 0), dirv.cross(Vector((1, 0, 0))))] * 2, caps=(True, True))
    return b, kd


def build_deck():
    b = Buf()
    v0, v1 = BANDS["inner"]
    rr, uu = [], []
    for y in stations(20, 0.015, 0.988):
        hw = max(hull_x(y, deck_z(y)) - 0.055, 0.05)
        row = []
        for j in range(13):
            x = -hw + 2 * hw * j / 12
            row.append(V(x, y, deck_z(y) + 0.045 * (1.0 - (x / hw) ** 2)))
        rr.append(row)
        uu.append([((y - L0) / 1.8, v0 + 0.006 + (v1 - v0 - 0.012) * (j / 12)) for j in range(13)])
    K.ogrid(b, rr, uu, (0, 0, 1))
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(20, 0.015, 0.988):
            row = []
            for j in range(4):
                z = deck_z(y) + (sheer_z(y) - 0.045 - deck_z(y)) * j / 3
                x = hull_x(y, z, side) - 0.028 * side
                row.append(V(x, y, z))
            rr.append(row)
            uu.append([((y - L0) / 1.8 + (0.0 if side > 0 else 0.43), v0 + 0.006 + (v1 - v0 - 0.012) * (j / 3))
                       for j in range(4)])
        K.ogrid(b, rr, uu, lambda c: Vector((-c.x, 0.0, 0.0)))
    zs = sheer_z(L1)
    rr, uu = [], []
    for k in range(4):
        z = deck_z(L1) + (zs - 0.055 - deck_z(L1)) * k / 3
        hw = hull_x(L1 - 0.14, z)
        rr.append([V(-hw + 2 * hw * j / 8, L1 - 0.14 + 0.04 * (k / 3), z) for j in range(9)])
        uu.append([(0.48 + 0.38 * (j / 8), v0 + 0.006 + (v1 - v0 - 0.012) * (k / 3)) for j in range(9)])
    K.ogrid(b, rr, uu, (0, -1, 0))
    return b


def build_cap_rail():
    b = Buf()
    uv = B("metal", 1.4)
    for side in (1, -1):
        pts = [V(side * (half_beam(y) + 0.004), y, sheer_z(y) + 0.022) for y in stations(26, 0.004, 0.997)]
        W.sweep(b, pts, W.rect_profile(0.165, 0.085, 0.018), uv, axes=[((1, 0, 0), (0, 0, 1))] * len(pts),
                caps=(True, True))
    zb = sheer_z(L1) + 0.040
    W.sweep(b, [V(-half_beam(L1) + 0.03, L1 + 0.10, zb), V(half_beam(L1) - 0.03, L1 + 0.10, zb)],
            W.rect_profile(0.12, 0.060, 0.012), uv, axes=[((0, 1, 0), (0, 0, 1))] * 2, caps=(True, True))
    return b


def build_breakwater():
    b = Buf()
    y = -2.92
    hw = hull_x(y, deck_z(y)) - 0.06
    z0 = deck_z(y) + 0.03
    z1 = z0 + 0.42
    v0, v1 = BANDS["metal"]
    rr, uu = [], []
    for k in range(3):
        z = z0 + (z1 - z0) * k / 2
        yy = y + 0.10 * (k / 2)
        rr.append([V(-hw + 2 * hw * j / 8, yy, z) for j in range(9)])
        uu.append([(0.30 + 0.42 * (j / 8), v0 + 0.006 + (v1 - v0 - 0.012) * (k / 2)) for j in range(9)])
    K.ogrid(b, rr, uu, (0, -1, 0.25))
    return b


CAB_YF, CAB_YB = -3.45, -0.85
CAB_HW = 1.46
CAB_BASE = 1.64
CAB_ROOF = 4.34


def cab_front_y(z):
    return CAB_YF + 0.105 * (z - CAB_BASE) / (CAB_ROOF - CAB_BASE)


def cab_hw(z):
    return CAB_HW - 0.050 * (z - CAB_BASE) / (CAB_ROOF - CAB_BASE)


def cab_ring(z, pad=0.0):
    hw = cab_hw(z) + pad
    yf = cab_front_y(z) - pad
    yb = CAB_YB + pad
    r = 0.075
    pts = []
    for (cx, cy, a0) in ((-hw + r, yf + r, math.pi), (hw - r, yf + r, 1.5 * math.pi),
                         (hw - r, yb - r, 0.0), (-hw + r, yb - r, 0.5 * math.pi)):
        for i in range(2):
            a = a0 + (math.pi / 2) * i
            pts.append(V(cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def build_cabin():
    b = Buf()
    zs = [CAB_BASE, CAB_BASE + 0.12, 2.28, 3.53, CAB_ROOF - 0.12, CAB_ROOF]
    rings = [cab_ring(z) for z in zs]
    v0, v1 = BANDS["white"]
    for k in range(len(rings) - 1):
        A, Q = rings[k], rings[k + 1]
        for j in range(len(A)):
            j2 = (j + 1) % len(A)
            c = (A[j] + Q[j2]) / 2
            want = Vector((c.x, (c.y + 2.1) * 0.55, 0.0))
            uv = [(j / len(A) * 2.2, v0 + 0.004 + (v1 - v0 - 0.008) * (k / (len(rings) - 1))),
                  ((j + 1) / len(A) * 2.2, v0 + 0.004 + (v1 - v0 - 0.008) * (k / (len(rings) - 1))),
                  ((j + 1) / len(A) * 2.2, v0 + 0.004 + (v1 - v0 - 0.008) * ((k + 1) / (len(rings) - 1))),
                  (j / len(A) * 2.2, v0 + 0.004 + (v1 - v0 - 0.008) * ((k + 1) / (len(rings) - 1)))]
            K.oface(b, [A[j], A[j2], Q[j2], Q[j]], uv, want)
    return b


def build_roof():
    b = Buf()
    t = Buf()
    uv = B("sheer", 1.4)
    hw = cab_hw(CAB_ROOF) + 0.085
    yf = cab_front_y(CAB_ROOF) - 0.05
    yb = CAB_YB + 0.03
    W.obox(b, (0.0, (yf + yb) / 2, CAB_ROOF - 0.025), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (hw, (yb - yf) / 2, 0.055), uv)
    uv2 = B("metal", 0.7)
    W.obox(t, (0.0, (yf + yb) / 2, CAB_ROOF + 0.040), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (hw - 0.11, (yb - yf) / 2 - 0.11, 0.008), uv2)
    return b, t


def window(b_glass, b_trim, quad, normal, frame=0.050, mullion=False, sill=False):
    gq = [p + Vector(normal) * 0.014 for p in quad]
    w0, w1 = BANDS["water"]
    K.oface(b_glass, gq, [(0.07, w0 + 0.007), (0.19, w0 + 0.007), (0.19, w1 - 0.007), (0.07, w1 - 0.007)], normal)
    nrm = Vector(normal)
    m0, m1 = BANDS["dark"]
    for i in range(4):
        p0, p1 = gq[i], gq[(i + 1) % 4]
        d = p1 - p0
        if d.length < 1e-6:
            continue
        out = d.normalized().cross(nrm).normalized() * frame
        K.oface(b_trim, [p0 - out, p0 + out, p1 + out, p1 - out],
                [(0.10, m0 + 0.006), (0.22, m0 + 0.006), (0.22, m1 - 0.006), (0.10, m1 - 0.006)], nrm)
    if mullion:
        a, q = (gq[0] + gq[3]) / 2, (gq[1] + gq[2]) / 2
        d = (q - a)
        out = d.normalized().cross(nrm).normalized() * 0.016
        K.oface(b_trim, [a - out, a + out, q + out, q - out],
                [(0.30, m0 + 0.006), (0.34, m0 + 0.006), (0.34, m1 - 0.006), (0.30, m1 - 0.006)], nrm)
    if sill:
        p0, p1 = gq[0], gq[1]
        d = (p1 - p0).normalized()
        down = nrm.cross(d).normalized() * -1.0
        for s0, s1 in ((0.055, 0.075),):
            q0, q1 = p0 - down * 0.012, p1 - down * 0.012
            K.oface(b_trim, [q0, q1, q1 + nrm * 0.075 + down * s1 + d * 0.0,
                             q0 + nrm * 0.075 + down * s1],
                    [(0.38, m0 + 0.006), (0.44, m0 + 0.006), (0.44, m1 - 0.006), (0.38, m1 - 0.006)], nrm)


def build_windows(glass, trim):
    z0, z1 = 2.56, 3.68
    yf0, yf1 = cab_front_y(z0), cab_front_y(z1)
    hw0, hw1 = cab_hw(z0), cab_hw(z1)
    for (xa, xb) in ((-1.24, -0.70), (-0.54, 0.02), (0.02, 0.54), (0.70, 1.24)):
        quad = [V(xa, yf0, z0), V(xb, yf0, z0), V(xb * (hw1 / hw0), yf1, z1), V(xa * (hw1 / hw0), yf1, z1)]
        window(glass["front"], trim, quad, (0, -1, 0.06), frame=0.058, mullion=True, sill=True)
    for side in (1, -1):
        zs = (2.58, 3.64)
        for (ya, yb) in ((CAB_YF + 0.42, CAB_YF + 1.12), (CAB_YF + 1.28, CAB_YB - 0.24)):
            q = []
            for z in zs:
                hw = cab_hw(z) * side
                q += [V(hw, ya, z), V(hw, yb, z)]
            window(glass["side"], trim, [q[0], q[2], q[3], q[1]], (side, 0, 0), frame=0.052, mullion=True, sill=True)
    yb = CAB_YB + 0.008
    window(glass["rear"], trim, [V(-1.18, yb, 2.60), V(-0.56, yb, 2.60),
                                 V(-0.56, yb, 3.56), V(-1.18, yb, 3.56)], (0, 1, -0.02), frame=0.048)
    window(glass["rear"], trim, [V(0.58, yb, 2.62), V(1.16, yb, 2.62),
                                 V(1.16, yb, 3.56), V(0.58, yb, 3.56)], (0, 1, -0.02), frame=0.048)
    xd = -cab_hw(2.4) - 0.028
    window(glass["side"], trim, [V(xd, -1.80, 2.56), V(xd, -1.48, 2.56),
                                 V(xd, -1.48, 2.96), V(xd, -1.80, 2.96)], (-1, 0, 0), frame=0.032)


def build_cabin_trim():
    b = Buf()
    uv = B("dark", 0.8)
    m0, m1 = BANDS["metal"]
    # horizontal panel seams, wrapping each wall
    for z in (2.34, 4.03):
        for side in (1, -1):
            x = cab_hw(z) * side + side * 0.010
            W.obox(b, (x, (cab_front_y(z) + CAB_YB) / 2, z), ((0, 1, 0), (side, 0, 0), (0, 0, 1)),
                  ((cab_front_y(z) - CAB_YB) / 2 - 0.06, 0.010, 0.007), uv)
        yf = cab_front_y(z) - 0.010
        W.obox(b, (0, yf, z), ((1, 0, 0), (0, -1, 0), (0, 0, 1)), (cab_hw(z) - 0.05, 0.010, 0.007), uv)
        W.obox(b, (0, CAB_YB + 0.010, z), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (cab_hw(z) - 0.05, 0.010, 0.007), uv)
    # vertical seams on the sides, front and rear
    for side in (1, -1):
        for y in (CAB_YF + 0.72, CAB_YF + 1.62, CAB_YB - 0.52):
            x = cab_hw(2.9) * side + side * 0.010
            W.obox(b, (x, y, 2.92), ((0, 1, 0), (side, 0, 0), (0, 0, 1)), (0.64, 0.010, 0.007), uv)
    for x in (-0.60, 0.60):
        yf = cab_front_y(2.95) - 0.010
        W.obox(b, (x, yf, 2.95), ((0, 0, 1), (0, -1, 0), (1, 0, 0)), (1.22, 0.010, 0.007), uv)
    for x in (-0.60, 0.60):
        W.obox(b, (x, CAB_YB + 0.010, 2.95), ((0, 0, 1), (0, 1, 0), (1, 0, 0)), (1.20, 0.010, 0.007), uv)
    # window sills and drip rail
    for side in (1, -1):
        x = cab_hw(2.54) * side + side * 0.075
        W.obox(b, (x, (CAB_YF + CAB_YB) / 2 + 0.25, 2.53), ((0, 1, 0), (side, 0, 0), (0, 0, 1)),
              ((CAB_YB - CAB_YF) / 2 - 0.20, 0.070, 0.020), uv)
    yf = cab_front_y(2.53) - 0.075
    W.obox(b, (0, yf, 2.53), ((1, 0, 0), (0, -1, 0), (0, 0, 1)), (cab_hw(2.53) - 0.02, 0.070, 0.020), uv)
    # door (starboard aft): frame, panel, porthole, handle, kick plate
    xd = -cab_hw(2.2) - 0.012
    yc, zd = -1.64, 2.42
    W.obox(b, (xd, yc, zd), ((0, 1, 0), (-1, 0, 0), (0, 0, 1)), (0.48, 0.020, 0.84), uv)
    for dz in (-0.80, 0.80):
        W.obox(b, (xd - 0.020, yc, zd + dz), ((0, 1, 0), (-1, 0, 0), (0, 0, 1)), (0.50, 0.016, 0.038), uv)
    for dy in (-0.49, 0.49):
        W.obox(b, (xd - 0.020, yc + dy, zd), ((0, 0, 1), (-1, 0, 0), (0, 1, 0)), (0.83, 0.016, 0.036), uv)
    C.tube(b, [V(xd - 0.055, yc - 0.36, zd + 0.02), V(xd - 0.10, yc - 0.36, zd + 0.02)], 0.014, uv, sides=6)
    W.obox(b, (xd - 0.030, yc, zd - 0.68), ((0, 1, 0), (-1, 0, 0), (0, 0, 1)), (0.44, 0.010, 0.16), B("dark", 0.6))
    # plinth skirt around the cabin base
    for side in (1, -1):
        x = cab_hw(CAB_BASE) * side + side * 0.014
        W.obox(b, (x, (cab_front_y(CAB_BASE) + CAB_YB) / 2, CAB_BASE + 0.075),
              ((0, 1, 0), (side, 0, 0), (0, 0, 1)), ((cab_front_y(CAB_BASE) - CAB_YB) / 2 - 0.04, 0.012, 0.075), uv)
    W.obox(b, (0, cab_front_y(CAB_BASE) - 0.014, CAB_BASE + 0.075),
          ((1, 0, 0), (0, -1, 0), (0, 0, 1)), (cab_hw(CAB_BASE) - 0.06, 0.012, 0.075), uv)
    W.obox(b, (0, CAB_YB + 0.014, CAB_BASE + 0.075),
          ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (cab_hw(CAB_BASE) - 0.06, 0.012, 0.075), uv)
    # extra vertical panel ribs on the lower wall band
    for side in (1, -1):
        for y in (CAB_YF + 0.30, CAB_YF + 1.30, CAB_YB - 0.30):
            x = cab_hw(1.95) * side + side * 0.012
            W.obox(b, (x, y, 1.98), ((0, 1, 0), (side, 0, 0), (0, 0, 1)), (0.20, 0.012, 0.007), uv)
    # aft-wall vent grilles
    for (cy, cz) in ((-0.25, 3.95), (0.18, 3.95)):
        y = CAB_YB + 0.020
        W.obox(b, (cy, y, cz), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.16, 0.020, 0.12), uv)
        for k in range(3):
            W.obox(b, (cy, y + 0.026, cz - 0.07 + k * 0.07), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
                  (0.15, 0.006, 0.020), B("dark", 0.4))
    # access ladder on the aft wall (port side)
    z0, z1 = CAB_BASE + 0.02, CAB_ROOF + 0.10
    yl = CAB_YB - 0.09
    for x in (0.34, 0.68):
        C.tube(b, [V(x, yl, z0), V(x, yl, z1)], 0.024, uv, sides=6)
    for k in range(9):
        z = z0 + 0.18 + (z1 - z0 - 0.24) * k / 8
        C.tube(b, [V(0.34, yl, z), V(0.68, yl, z)], 0.016, uv, sides=5)
    # roof gutter and fascia
    for side in (1, -1):
        x = (cab_hw(CAB_ROOF) + 0.085) * side
        C.tube(b, [V(x, cab_front_y(CAB_ROOF) - 0.06, CAB_ROOF - 0.065),
                   V(x, CAB_YB + 0.02, CAB_ROOF - 0.065)], 0.014, uv, sides=5)
    C.tube(b, [V(-cab_hw(CAB_ROOF) - 0.07, cab_front_y(CAB_ROOF) - 0.06, CAB_ROOF - 0.065),
               V(cab_hw(CAB_ROOF) + 0.07, cab_front_y(CAB_ROOF) - 0.06, CAB_ROOF - 0.065)], 0.014, uv, sides=5)
    return b


def build_roof_gear():
    b = Buf()          # rails + liferaft cradle + vents, metal
    raft = Buf()
    white2 = Buf()
    uv = B("metal", 0.7)
    rz = CAB_ROOF + 0.05
    hw = cab_hw(CAB_ROOF) + 0.06
    yf = cab_front_y(CAB_ROOF) - 0.02
    yb = CAB_YB + 0.01
    posts = [(-hw + 0.06, yf + 0.05), (hw - 0.06, yf + 0.05), (-hw + 0.06, yb - 0.05), (hw - 0.06, yb - 0.05),
             (-hw + 0.06, (yf + yb) / 2), (hw - 0.06, (yf + yb) / 2)]
    for (x, y) in posts:
        C.tube(b, [V(x, y, rz), V(x, y, rz + 0.72)], 0.019, uv, sides=6)
    for (x, y0, y1) in ((-hw + 0.06, yf + 0.05, yb - 0.05), (hw - 0.06, yf + 0.05, yb - 0.05)):
        C.tube(b, [V(x, y0, rz + 0.72), V(x, y1, rz + 0.72)], 0.016, uv, sides=6)
    C.tube(b, [V(-hw + 0.06, yf + 0.05, rz + 0.72), V(hw - 0.06, yf + 0.05, rz + 0.72)], 0.016, uv, sides=6)
    C.tube(b, [V(-hw + 0.06, yb - 0.05, rz + 0.72), V(hw - 0.06, yb - 0.05, rz + 0.72)], 0.016, uv, sides=6)
    # liferaft canister (white, orange bands) on a cradle
    rx, ry, rz2 = 0.92, -1.72, CAB_ROOF + 0.34
    # simple capsule along Y from discs + tube
    C.tube(white2, [V(rx, ry - 0.48, rz2), V(rx, ry + 0.48, rz2)], 0.245, B("white", 0.7), sides=14)
    for yy in (ry - 0.48, ry + 0.48):
        C.tube(white2, [V(rx, yy, rz2), V(rx, yy + (0.06 if yy > ry else -0.06), rz2)], 0.17, B("white", 0.7),
               sides=14)
    for yy in (ry - 0.30, ry + 0.30):
        C.tube(raft, [V(rx, yy - 0.045, rz2), V(rx, yy + 0.045, rz2)], 0.252, B("motor", 0.5), sides=14)
    for yy in (ry - 0.34, ry + 0.34):
        for xoff in (-0.18, 0.18):
            C.tube(b, [V(rx + xoff, yy, CAB_ROOF + 0.06), V(rx + xoff, yy, rz2 - 0.24)], 0.020, uv, sides=5)
    b.extend(white2)
    # vents and a searchlight base on the roof
    C.tube(b, [V(-0.55, cab_front_y(CAB_ROOF) - 0.10, rz), V(-0.55, cab_front_y(CAB_ROOF) - 0.10, rz + 0.30)],
           0.055, uv, sides=8)
    C.tube(b, [V(-0.55, cab_front_y(CAB_ROOF) - 0.10, rz + 0.30), V(-0.55, cab_front_y(CAB_ROOF) - 0.16, rz + 0.36)],
           0.070, uv, sides=8)
    return b, raft, white2


def build_funnel():
    b = Buf()
    d = Buf()
    uv = B("motor", 0.65)
    pts = [V(0, -0.02, CAB_BASE + 0.02), V(0, 0.02, 3.55), V(0, 0.06, 4.72)]
    W.sweep(b, pts, W.rect_profile(0.60, 0.46, 0.06), uv, axes=[((1, 0, 0), (0, 1, 0))] * 3,
            scale=[1.0, 0.92, 0.84], caps=(True, True))
    C.tube(d, [V(0, 0.05, 4.60), V(0, 0.05, 4.98)], 0.105, B("dark", 0.6), sides=10)
    C.tube(d, [V(0, 0.05, 4.98), V(0, 0.15, 5.02)], 0.125, B("dark", 0.6), sides=10)
    C.tube(b, [V(0, 0.05, 4.62), V(0, 0.05, 4.70)], 0.30, B("metal", 0.6), sides=10)
    for side in (1, -1):
        C.tube(b, [V(side * 0.20, CAB_YB + 0.05, 3.04), V(side * 0.20, 0.02, 3.10)], 0.022, B("metal", 0.5), sides=5)
    return b, d


def build_mast():
    b = Buf()
    dark = Buf()
    red = Buf()
    green = Buf()
    wht = Buf()
    uv = B("metal", 0.75)
    x, y = 0.0, -1.12
    z0 = CAB_ROOF + 0.03
    C.tube(b, [V(x, y, z0), V(x, y, 6.50)], 0.088, uv, sides=8)
    C.tube(b, [V(x - 0.62, y, 5.34), V(x + 0.62, y, 5.34)], 0.030, uv, sides=6)
    C.tube(b, [V(x, y, 5.28), V(x, y, 5.44)], 0.12, uv, sides=8)
    # radar bar on a small pedestal
    W.obox(dark, (0, y, 5.66), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.60, 0.065, 0.075), B("dark", 0.6))
    W.obox(dark, (0.60, y, 5.66), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.09, 0.055, 0.055), B("dark", 0.6))
    W.obox(dark, (-0.60, y, 5.66), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.09, 0.055, 0.055), B("dark", 0.6))
    C.tube(b, [V(x, y, 5.44), V(x, y, 5.60)], 0.085, uv, sides=8)
    # derrick boom over the working deck, topping lift and heel
    boom0 = V(x, y, 4.72)
    boom1 = V(x, 4.35, 6.62)
    C.tube(b, [boom0, boom1], 0.055, uv, sides=7)
    C.tube(b, [boom0 - V(0, 0.10, 0), boom0 + V(0, 0.30, 0.12)], 0.075, uv, sides=8)
    wob = B("dark", 0.4)
    C.tube(dark, [boom1, V(x, y, 6.46)], 0.012, wob, sides=4)
    C.tube(dark, [V(x, y, 6.45), V(-1.40, CAB_YF + 0.20, CAB_ROOF + 0.05)], 0.010, wob, sides=4)
    C.tube(dark, [V(x, y, 6.45), V(1.40, CAB_YF + 0.20, CAB_ROOF + 0.05)], 0.010, wob, sides=4)
    C.tube(b, [V(x, y, 6.50), V(x, y + 0.05, 6.72)], 0.030, uv, sides=6)
    # VHF whips at the roof rear corners
    for side in (1, -1):
        C.tube(b, [V(side * 1.18, CAB_YB + 0.10, CAB_ROOF + 0.04),
                   V(side * 1.18, CAB_YB + 0.10, CAB_ROOF + 2.20)], 0.014, uv, sides=5)
        C.tube(wht, [V(side * 1.18, CAB_YB + 0.10, CAB_ROOF + 1.95),
                     V(side * 1.18, CAB_YB + 0.10, CAB_ROOF + 2.20)], 0.022, B("white", 0.4), sides=5)
    # nav lights on the crossbar (red to port +X, green to starboard)
    for side, lens in ((1, red), (-1, green)):
        W.obox(dark, (side * 0.63, y, 5.50), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.035, 0.045, 0.045), B("dark", 0.4))
        W.obox(lens, (side * 0.665, y, 5.50), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.010, 0.036, 0.036),
              B("antifoul" if side > 0 else "bailer", 0.2))
    W.obox(wht, (0, y, 6.78), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.055, 0.055, 0.060), B("white", 0.4))
    # searchlight on the roof front
    C.tube(b, [V(0.0, cab_front_y(CAB_ROOF) - 0.12, CAB_ROOF + 0.05),
               V(0.0, cab_front_y(CAB_ROOF) - 0.12, CAB_ROOF + 0.20)], 0.035, uv, sides=6)
    W.obox(b, (0.0, cab_front_y(CAB_ROOF) - 0.20, CAB_ROOF + 0.30), ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
          (0.15, 0.13, 0.12), uv)
    W.obox(wht, (0.0, cab_front_y(CAB_ROOF) - 0.36, CAB_ROOF + 0.30), ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
          (0.075, 0.10, 0.10), B("white", 0.4))
    return b, dark, red, green, wht


def build_wheelhouse_letters():
    return Buf()


def build_gantry():
    b = Buf()
    d = Buf()
    uv = B("metal", 0.8)
    deckz = deck_z(6.2)
    for side in (1, -1):
        p0 = V(side * 1.72, 5.78, deckz + 0.05)
        p1 = V(side * 1.15, 6.60, 4.55)
        p2 = V(side * 0.78, 7.38, 6.10)
        W.sweep(b, [p0, p1, p2], W.rect_profile(0.19, 0.19, 0.03), uv,
                axes=[((1, 0, 0), (0, 1, 0))] * 3, caps=(True, True))
        W.obox(b, (side * 1.66, 5.92, deckz + 0.20), ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
              (0.22, 0.13, 0.30), uv)
        W.obox(b, (side * 1.40, 6.20, 3.55), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.22, 0.11, 0.30), uv)
        for (za, zb) in ((2.25, 3.15), (3.55, 4.55)):
            C.tube(b, [V(side * 1.62, 5.98, deckz + za), V(side * 1.22, 6.55, deckz + zb)], 0.030, uv, sides=5)
        C.tube(b, [V(side * 1.72, 5.78, deckz + 0.05), V(side * 1.65, 7.10, deckz + 0.05)], 0.050, uv, sides=6)
    C.tube(b, [V(-0.86, 7.40, 6.12), V(0.86, 7.40, 6.12)], 0.105, uv, sides=8)
    C.tube(b, [V(-1.18, 6.60, 4.55), V(1.18, 6.60, 4.55)], 0.075, uv, sides=6)
    for side in (1, -1):
        W.obox(b, (side * 0.78, 7.38, 6.02), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.16, 0.13, 0.16), uv)
    # central head block with two sheaves and the net wire
    W.obox(d, (0, 7.40, 6.02), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.20, 0.16, 0.10), B("dark", 0.5))
    for x in (-0.14, 0.14):
        C.tube(b, [V(x - 0.03, 7.40, 6.02), V(x + 0.03, 7.40, 6.02)], 0.15, uv, sides=10)
    C.tube(d, [V(0, 7.38, 5.92), V(0, 0.92, 2.92)], 0.016, B("dark", 0.4), sides=4)
    # stern roller / gallows sheaves at the quarters
    for side in (1, -1):
        C.tube(b, [V(side * 1.44, 5.02, deckz + 0.02), V(side * 1.44, 5.02, deckz + 1.18)], 0.058, uv, sides=7)
        C.tube(b, [V(side * 1.20, 5.02, deckz + 1.18), V(side * 1.70, 5.02, deckz + 1.18)], 0.026, uv, sides=5)
        W.obox(d, (side * 1.62, 5.02, deckz + 1.10), ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
              (0.055, 0.16, 0.16), B("dark", 0.5))
    return b, d


def build_winch():
    b = Buf()
    d = Buf()
    uv = B("metal", 0.7)
    cy = 2.62
    dz = deck_z(cy)
    for side in (1, -1):
        W.obox(b, (side * 0.98, cy, dz + 0.34), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.30, 0.10, 0.34), uv)
    W.obox(b, (0, cy, dz + 0.64), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (1.12, 0.10, 0.08), uv)
    for side in (1, -1):
        C.tube(d, [V(side * 0.30, cy, dz + 0.68), V(side * 0.68, cy, dz + 0.68)], 0.30, B("dark", 0.45), sides=12)
        for xx in (side * 0.30, side * 0.68):
            C.tube(b, [V(xx, cy - 0.02, dz + 0.68), V(xx, cy + 0.02, dz + 0.68)], 0.34, uv, sides=12)
        C.tube(d, [V(side * 0.30, cy, dz + 0.68), V(side * 0.30, cy + 0.12, dz + 0.30)], 0.016, B("dark", 0.4), sides=4)
    W.obox(b, (0.86, cy + 0.24, dz + 0.26), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.22, 0.16, 0.24), uv)
    C.tube(b, [V(0.86, cy + 0.24, dz + 0.52), V(0.86, cy + 0.24, dz + 0.72)], 0.020, uv, sides=5)
    W.obox(d, (0.86, cy + 0.24, dz + 0.74), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.07, 0.05, 0.04), B("dark", 0.4))
    # warps from the drums aft through the gallows and down to the doors
    for side in (1, -1):
        C.tube(d, [V(side * 0.49, cy, dz + 0.86), V(side * 0.94, 4.10, dz + 0.82),
                   V(side * 1.44, 5.02, dz + 1.05), V(side * 1.58, 6.00, dz + 0.72),
                   V(side * 1.72, 6.92, 2.30)], 0.014, B("dark", 0.4), sides=4)
    return b, d


def build_net_drum():
    b = Buf()
    net = Buf()
    band = Buf()
    uv = B("metal", 0.7)
    cy, cz = 0.92, 2.34
    for side in (1, -1):
        W.obox(b, (side * 1.16, cy, deck_z(cy) + 0.32), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.36, 0.12, 0.32), uv)
        C.tube(b, [V(side * 1.05, cy, cz), V(side * 1.16, cy, cz)], 0.10, uv, sides=8)
    C.tube(b, [V(-1.05, cy, cz), V(1.05, cy, cz)], 0.11, uv, sides=8)
    # wound net: corrugated green cylinder
    nuv = B("bailer", 1.1)
    prof = []
    for k in range(13):
        r = 0.56 if k % 2 == 0 else 0.525
        prof.append((r, -0.94 + 1.88 * k / 12))
    rr, uu = [], []
    for k, (r, x) in enumerate(prof):
        row = []
        for i in range(17):
            a = 2 * math.pi * i / 16
            row.append(V(x, cy + r * math.cos(a), cz + r * math.sin(a)))
        rr.append(row)
        uu.append([(a / (2 * math.pi) * 2.4, BANDS["bailer"][0] + 0.006 + 0.028 * k / 12) for a in
                   (2 * math.pi * i / 16 for i in range(17))])
    K.ogrid(net, rr, uu, lambda c: Vector((0, c.y - cy, c.z - cz)))
    # orange bands and the net tail bunched on deck
    for x in (-0.70, 0.66):
        C.tube(band, [V(x - 0.06, cy, cz), V(x + 0.06, cy, cz)], 0.575, B("motor", 0.5), sides=16)
    W.sweep(net, [V(0.30, cy + 0.38, cz - 0.25), V(0.52, 1.48, 1.90), V(0.78, 2.10, 0.85),
                  V(0.60, 2.70, 0.40), V(0.10, 3.00, 0.22)], W.round_profile(0.075, 5), nuv,
            scale=[1.0, 0.7, 0.9, 1.1, 0.6], caps=(True, True))
    W.sweep(net, [V(-0.10, cy + 0.40, cz - 0.20), V(-0.20, 1.62, 1.55), V(-0.10, 2.20, 0.60),
                  V(0.20, 2.78, 0.30)], W.round_profile(0.055, 5), nuv, caps=(True, True))
    return b, net, band


def build_doors():
    b = Buf()
    m = Buf()
    d = Buf()
    uv = B("antifoul", 0.8)
    for side in (1, -1):
        cx, cy, cz = side * 2.02, 7.06, 2.08
        M = Matrix.Translation(Vector((cx, cy, cz)))
        L, Wd, H = 0.075, 0.90, 1.34
        W.obox(b, M @ Vector((0, 0, 0)), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (L, Wd, H / 2), uv)
        for dz in (-H / 2 + 0.08, H / 2 - 0.08):
            W.obox(m, M @ Vector((0, 0, dz)), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
                  (L + 0.025, Wd + 0.04, 0.05), B("metal", 0.5))
        for dy in (-Wd + 0.07, Wd - 0.07):
            W.obox(m, M @ Vector((0, dy, 0)), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
                  (L + 0.025, 0.045, H / 2 - 0.05), B("metal", 0.5))
        wob = B("dark", 0.4)
        C.tube(d, [M @ Vector((0, -0.30, H / 2)), V(side * 1.86, 7.40, 6.02)], 0.015, wob, sides=4)
        C.tube(d, [M @ Vector((0, 0.30, H / 2)), V(side * 1.86, 7.40, 6.02)], 0.015, wob, sides=4)
    return b, m, d


def build_foredeck():
    b = Buf()
    d = Buf()
    uv = B("metal", 0.7)
    # anchor windlass
    y = -6.52
    z = deck_z(y)
    W.obox(b, (0, y, z + 0.14), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.42, 0.26, 0.12), uv)
    C.tube(b, [V(-0.28, y, z + 0.30), V(0.28, y, z + 0.30)], 0.115, uv, sides=10)
    C.tube(d, [V(-0.28, y, z + 0.30), V(0.28, y, z + 0.30)], 0.075, B("dark", 0.4), sides=10)
    # cable/chain to the hawse pipe (port) and stowed anchor
    C.tube(d, [V(0.32, y + 0.05, z + 0.22), V(1.02, -6.80, deck_z(-6.80) + 0.12),
               V(1.28, -6.88, 2.34)], 0.026, B("dark", 0.4), sides=5)
    C.tube(b, [V(1.30, -6.88, 2.34), V(1.42, -6.92, 2.42)], 0.09, uv, sides=8)
    C.tube(b, [V(1.42, -6.94, 2.36), V(1.42, -6.94, 1.48)], 0.055, uv, sides=7)
    W.obox(b, (1.42, -6.94, 1.44), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.075, 0.34, 0.055), uv)
    for side in (-1, 1):
        W.obox(b, (1.42, -6.94, 1.52), ((0, 0, 1), (0, 1, 0), (1, 0, 0)), (0.30, 0.045, 0.10), uv)
        W.obox(b, (1.42 + side * 0.2, -6.94, 1.62), ((0, 0, 1), (0, 1, 0), (side, 0, 0)), (0.16, 0.04, 0.07), uv)
    # hawse lips both sides
    for side in (1, -1):
        C.tube(b, [V(side * 1.28, -6.88, 2.34), V(side * 1.36, -6.80, 2.36)], 0.085, uv, sides=8)
    # breakwater lip and bollards on the forecastle
    for side in (1, -1):
        for yy in (-5.20, -3.95):
            cleat(b, side * (hull_x(yy, deck_z(yy) + 0.02) - 0.25), yy, deck_z(yy) + 0.05)
    # a small deck locker
    W.obox(b, (-0.78, -5.30, deck_z(-5.30) + 0.22), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (0.40, 0.34, 0.22), uv)
    W.obox(d, (-0.78, -5.30, deck_z(-5.30) + 0.46), ((1, 0, 0), (0, 1, 0), (0, 0, 1)),
          (0.42, 0.36, 0.03), B("dark", 0.5))
    return b, d


def cleat(b, x, y, z, ang=0.0):
    uv = B("metal", 0.5)
    ca, sa = math.cos(ang), math.sin(ang)
    for dx in (-0.15, 0.15):
        C.tube(b, [V(x + ca * dx, y + sa * dx, z), V(x + ca * dx, y + sa * dx, z + 0.09)], 0.020, uv, sides=6)
    C.tube(b, [V(x - ca * 0.21, y - sa * 0.21, z + 0.09), V(x + ca * 0.21, y + sa * 0.21, z + 0.09)],
           0.032, uv, sides=8)


def build_deck_fittings():
    b = Buf()
    t = Buf()
    rp = Buf()
    sc = Buf()
    uv = B("metal", 0.7)
    # flush hatches with rims
    for (cy, w, ln) in ((3.55, 0.62, 0.82), (5.42, 0.52, 0.72)):
        z = deck_z(cy) + 0.05
        W.obox(b, (0, cy, z), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (w / 2, ln / 2, 0.045), B("inner", 0.7))
        for side in (1, -1):
            W.obox(t, (side * w / 2, cy, z + 0.03), ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
                  (ln / 2, 0.035, 0.018), uv)
        for yy in (cy - ln / 2, cy + ln / 2):
            W.obox(t, (0, yy, z + 0.03), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (w / 2, 0.035, 0.018), uv)
    # deck plating seams across the camber
    for cy in (-2.35, -0.95, 0.45, 1.85, 3.20, 4.55, 5.95, 7.15):
        hw = max(hull_x(cy, deck_z(cy)) - 0.16, 0.35)
        rr, uu = [], []
        for yy in (cy - 0.012, cy + 0.012):
            row = []
            for j in range(9):
                x = -hw + 2 * hw * j / 8
                row.append(V(x, yy, deck_z(cy) + 0.048 * (1.0 - (x / hw) ** 2) + 0.004))
            rr.append(row)
        uu.append([(0.30 + 0.42 * (j / 8), 0.626) for j in range(9)])
        uu.append([(0.30 + 0.42 * (j / 8), 0.638) for j in range(9)])
        K.ogrid(t, rr, uu, (0, 0, 1))
    # scuppers and freeing ports
    for side in (1, -1):
        for y in (-1.6, 0.2, 2.0, 3.8, 5.6):
            z = deck_z(y) + 0.06
            x = hull_x(y, z, side) + side * 0.012
            K.oface(sc, [V(x, y - 0.13, z - 0.05), V(x, y + 0.13, z - 0.05),
                         V(x, y + 0.13, z + 0.05), V(x, y - 0.13, z + 0.05)],
                    [(0.30, 0.78), (0.36, 0.78), (0.36, 0.812), (0.30, 0.812)], (side, 0, 0))
    # rope coils
    for (cx, cy) in ((0.95, 4.45), (-0.92, 1.10)):
        cz = deck_z(cy) + 0.08
        pts = []
        for i in range(52):
            a = 2 * math.pi * i / 13.0
            rad = 0.22 - 0.009 * i / 52
            pts.append(V(cx + rad * math.cos(a), cy + rad * math.sin(a), cz - 0.003 * (i // 17)))
        C.tube(rp, pts, 0.014, B("rope", 0.55), sides=5)
    return b, t, rp, sc


FISH = []


def fish_box_template():
    b = Buf()
    uv = B("bailer", 0.8)
    L, Wd, H = 0.78, 0.46, 0.26
    shell = []
    for z in (0.0, H):
        sh = 0.020 * (1.0 - z / H)
        shell.append([V(-L / 2 + sh, -Wd / 2 + sh, z), V(L / 2 - sh, -Wd / 2 + sh, z),
                      V(L / 2 - sh, Wd / 2 - sh, z), V(-L / 2 + sh, Wd / 2 - sh, z)])
    for i in range(4):
        q = [shell[0][i], shell[0][(i + 1) % 4], shell[1][(i + 1) % 4], shell[1][i]]
        K.oface(b, q, [(0.02 + i * 0.1, 0.976), (0.10 + i * 0.1, 0.976),
                       (0.10 + i * 0.1, 0.994), (0.02 + i * 0.1, 0.994)], (0, 0, 1))
    K.oface(b, shell[1], [(0.02 + j * 0.08, 0.978) for j in range(4)], (0, 0, 1))
    for i in range(4):
        q = [shell[1][i], shell[1][(i + 1) % 4], shell[1][(i + 1) % 4] + V(0.035, 0, 0.035),
             shell[1][i] + V(0.035, 0, 0.035)]
        K.oface(b, q, [(0.3, 0.996), (0.4, 0.996), (0.4, 1.000), (0.3, 1.000)], (0, 0, 1))
    return b


def build_fish_boxes():
    fr = fish_box_template()
    b = Buf()
    places = [(1.36, 3.30, 0.02, 0.10), (1.36, 3.30, 0.30, 0.06), (1.36, 3.30, 0.58, 0.12),
              (-1.34, 3.35, 0.02, -0.10), (-1.34, 3.35, 0.30, -0.05), (-1.34, 4.22, 0.02, 0.04),
              (1.30, 4.20, 0.02, -0.14), (0.30, 5.62, 0.02, 0.20)]
    for (x, y, dz, yaw) in places:
        M = Matrix.Translation(Vector((x, y, deck_z(y) + dz))) @ Matrix.Rotation(yaw, 4, "Z")
        b.extend(fr, M)
    return b


def build_baskets():
    b = Buf()
    rp = Buf()
    uv = B("dark", 0.6)
    for (x, y, h) in ((0.62, 4.98, 0.26), (0.28, 5.30, 0.26), (-0.72, 5.62, 0.24)):
        z = deck_z(y) + 0.02
        prof = [(0.02, 0.0), (0.20, 0.01), (0.235, h * 0.7), (0.25, h), (0.23, h + 0.01)]
        W.lathe(b, prof, 14, lambda k, a: (a * 0.33, 0.786 + 0.028 * k / 4), centre=(x, y, z))
        for side in (1, -1):
            C.tube(rp, [V(x + side * 0.2, y, z + h), V(x + side * 0.2, y + 0.03, z + h + 0.10),
                        V(x + side * 0.08, y + 0.02, z + h + 0.14)], 0.012, B("rope", 0.4), sides=4)
    return b, rp


def build_buoys():
    b = Buf()
    band = Buf()
    rp = Buf()
    uv = B("motor", 0.5)
    for (x, y, z, tilt) in ((1.62, 7.12, 2.30, 0.05), (-1.60, 7.14, 2.28, -0.04),
                            (0.92, 6.30, deck_z(6.3) + 0.30, 0.10), (-1.18, 6.60, deck_z(6.6) + 0.30, -0.08)):
        M = Matrix.Translation(Vector((x, y, z))) @ Matrix.Rotation(tilt, 4, "Y") @ Matrix.Rotation(tilt * 0.6, 4, "X")
        prof = [(0.02, 0.0), (0.10, 0.01), (0.115, 0.07), (0.115, 0.21), (0.09, 0.28), (0.04, 0.31), (0.03, 0.32)]
        tmp = Buf()
        W.lathe(tmp, prof, 12, lambda k, a: (a * 0.30, BANDS["motor"][0] + 0.006 + 0.062 * k / 6))
        b.extend(tmp, M)
        tmp = Buf()
        W.lathe(tmp, [(0.113, 0.11), (0.113, 0.16)], 12, lambda k, a: (a * 0.30, 0.948 + 0.008 * k))
        band.extend(tmp, M)
        C.tube(rp, [M @ V(0, 0, 0.30), M @ V(0, 0, 0.60)], 0.014, B("rope", 0.4), sides=4)
    for side in (1, -1):
        for (y, z) in ((1.1, 2.30), (4.6, 2.30)):
            C.tube(rp, [V(side * 1.90, y, z), V(side * 1.90, y, z - 0.30)], 0.014, B("rope", 0.4), sides=4)
    return b, band, rp


def build_tyres():
    b = Buf()
    rp = Buf()
    uv = B("dark", 0.5)
    for (y, z, r) in ((-0.4, 0.98, 0.28), (2.2, 0.96, 0.26), (4.8, 0.99, 0.28)):
        x = hull_x(y, z) + 0.11
        ring = [V(x, y + r * math.cos(2 * math.pi * i / 14), z + r * math.sin(2 * math.pi * i / 14)) for i in range(14)]
        W.ring(b, V(x, y, z), (0, 1, 0), (0, 0, 1), r, 0.075, 14, 7, uv)
        rx = x - 0.03
        C.tube(rp, [V(rx, y, z + r + 0.02), V(rx, y, sheer_z(y) + 0.02)], 0.022, B("rope", 0.4), sides=5)
    return b, rp


def build_lifebuoy(lb, strip, trim):
    uv = B("white", 0.4)
    c = V(0.55, CAB_YB - 0.05, 2.78)
    ring = [c + V(0.31 * math.cos(2 * math.pi * i / 16), 0, 0.31 * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    W.ring(lb, c, (1, 0, 0), (0, 0, 1), 0.31, 0.075, 16, 7, uv)
    for k in range(4):
        a = 2 * math.pi * k / 4
        p = c + V(0.31 * math.cos(a), -0.078, 0.31 * math.sin(a))
        K.oface(strip, [p + V(0.055 * math.cos(a + 1.4), 0, 0.055 * math.sin(a + 1.4)),
                        p + V(0.055 * math.cos(a - 1.4), 0, 0.055 * math.sin(a - 1.4)),
                        p + V(-0.055 * math.cos(a + 1.4), 0, -0.055 * math.sin(a + 1.4)),
                        p + V(-0.055 * math.cos(a - 1.4), 0, -0.055 * math.sin(a - 1.4))],
                [(0.01, 0.01), (0.03, 0.01), (0.03, 0.03), (0.01, 0.03)], (0, -1, 0))
    C.tube(trim, [c + V(-0.12, 0.02, 0.34), c + V(0.12, 0.02, 0.34)], 0.010, B("metal", 0.4), sides=5)


def build_rust():
    b = Buf()
    v0, v1 = BANDS["wood"]
    streaks = [(-6.50, 2.16, 1.26, 0.070), (-3.30, 2.26, 1.32, 0.085),
               (-1.55, 2.27, 1.44, 0.060), (1.40, 2.29, 1.35, 0.095),
               (3.90, 2.26, 1.24, 0.070), (6.30, 2.12, 1.15, 0.080)]
    for side in (1, -1):
        for (y, ztop, zbot, w) in streaks:
            rr, uu = [], []
            for k in range(4):
                f = k / 3
                z = ztop + (zbot - ztop) * f
                ww = w * (1.0 - 0.55 * f)
                x = hull_x(y, z, side) + side * 0.004
                rr.append([V(x, y - ww, z), V(x, y + ww, z)])
                uu.append([(0.02, v0 + 0.004 + (v1 - v0 - 0.008) * f),
                           (0.10, v0 + 0.004 + (v1 - v0 - 0.008) * f)])
            K.ogrid(b, rr, uu, (side, 0, 0))
    return b


def build_wheelhouse_rust():
    b = Buf()
    v0, v1 = BANDS["wood"]
    for side in (1, -1):
        for (y, ztop, zbot, w) in ((CAB_YF + 0.48, 2.62, 2.10, 0.020), (CAB_YF + 1.22, 2.60, 2.22, 0.014),
                                   (CAB_YB - 0.30, 2.55, 2.02, 0.018), (CAB_YB - 0.02, 3.94, 3.40, 0.022)):
            rr, uu = [], []
            for k in range(3):
                f = k / 2
                z = ztop + (zbot - ztop) * f
                x = cab_hw(z) * side + side * 0.008
                ww = w * (1.0 - 0.5 * f)
                rr.append([V(x, y - ww, z), V(x, y + ww, z)])
                uu.append([(0.06, v0 + 0.004 + (v1 - v0 - 0.008) * f),
                           (0.14, v0 + 0.004 + (v1 - v0 - 0.008) * f)])
            K.ogrid(b, rr, uu, (side, 0, 0))
    return b


def build_boarding_gates():
    b = Buf()
    uv = B("metal", 0.5)
    for side in (1, -1):
        y0, y1 = 0.64, 1.36
        z0 = deck_z(1.0) + 0.06
        z1 = sheer_z(1.0) - 0.05
        # solid gate plating, two stout posts and a single top rail (no cage bars)
        rr, uu = [], []
        for k in range(3):
            z = z0 + (z1 - z0) * k / 2
            rr.append([V(hull_x(y, z, side) + side * 0.010, y, z) for y in (y0, (y0 + y1) / 2, y1)])
            uu.append([(0.10 + 0.10 * j, 0.626 + 0.020 * k) for j in range(3)])
        K.ogrid(b, rr, uu, (side, 0, 0))
        for yy in (y0, y1):
            W.obox(b, (hull_x(yy, (z0 + z1) / 2, side) + side * 0.030, yy, (z0 + z1) / 2 + 0.03),
                  ((0, 1, 0), (side, 0, 0), (0, 0, 1)), (0.055, 0.045, (z1 - z0) / 2 + 0.05), uv)
        C.tube(b, [V(hull_x(y, z1 + 0.02, side) + side * 0.030, y, z1 + 0.02)
                   for y in (y0, (y0 + y1) / 2, y1)], 0.038, uv, sides=8)
    return b


def build_stern_ramp():
    b = Buf()
    d = Buf()
    uv = B("metal", 0.8)
    y0, y1 = 7.34, 7.60
    z0, z1 = deck_z(7.3) + 0.02, 1.05
    hw = 0.78
    rr, uu = [], []
    for k in range(3):
        f = k / 2
        yy = y0 + (y1 - y0) * f
        zz = z0 + (z1 - z0) * f
        rr.append([V(-hw + 2 * hw * j / 8, yy, zz) for j in range(9)])
        uu.append([(0.3 + 0.45 * (j / 8), 0.626 + 0.05 * f) for j in range(9)])
    K.ogrid(b, rr, uu, (0, -0.3, 0.95))
    for side in (1, -1):
        C.tube(b, [V(side * hw, y0, z0), V(side * hw, y1, z1)], 0.055, uv, sides=6)
    for k in range(3):
        zz = z1 + 0.10 + k * 0.10
        C.tube(d, [V(-hw + 0.05, y1 + 0.02 + k * 0.02, zz), V(hw - 0.05, y1 + 0.02 + k * 0.02, zz)],
               0.055, B("dark", 0.4), sides=8)
    return b, d


def build_weed():
    b = Buf()
    uv = B("weed", 0.9)
    for side in (1, -1):
        rr, uu = [], []
        for y in stations(20, 0.02, 0.98):
            p0 = sec(y, s_at_z(y, -0.015), side, 0.006)
            p1 = sec(y, s_at_z(y, 0.045 + 0.010 * math.sin(y * 1.9)), side, 0.006)
            rr.append([p0, p1])
            uu.append([((y - L0) / 1.5, BANDS["weed"][0] + 0.005),
                       ((y - L0) / 1.5, BANDS["weed"][1] - 0.005)])
        K.ogrid(b, rr, uu, lambda c: Vector((c.x, 0, -0.4)))
        for y in (-6.4, -5.6, -4.8, -4.0, -3.1, -2.2, -1.3, -0.4, 0.5, 1.4, 2.3, 3.2, 4.1, 5.0, 5.9, 6.8):
            x = hull_x(y, -0.01, side)
            for j in range(2):
                yy = y + (j - 0.5) * 0.09
                p0 = V(x + side * 0.004, yy, -0.005)
                p1 = V(x + side * 0.02, yy + (j - 0.5) * 0.02, -0.06)
                p2 = V(x + side * 0.035, yy + (j - 0.5) * 0.05, -0.14 - 0.02 * (j % 2))
                W.sweep(b, [p0, p1, p2], W.round_profile(0.005, 4), uv, scale=[1.0, 0.6, 0.15],
                        caps=(True, True), smooth=True)
    return b


def _span(ya, yb, n=20):
    return [ya + (yb - ya) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1))) for i in range(n)]


def _bead(b, pts, vertical=False):
    up = (0, 1, 0) if vertical else (0, 0, 1)
    W.sweep(b, pts, W.rect_profile(0.024, 0.050, 0.009), B("metal", 1.0), up_hint=up,
            caps=(True, True), smooth=True)


def _weld_h(b, side, zc, ya, yb, n=26):
    pts = []
    for y in _span(ya, yb, n):
        pts.append(V(hull_x(y, zc, side) + side * 0.002, y, zc))
    _bead(b, pts)
    for y in _span(ya + 0.3, yb - 0.3, 40):
        p = V(hull_x(y, zc - 0.06, side) + side * 0.002, y, zc - 0.06)
        _rivet(b, p, V(side, 0, 0))


def _weld_v(b, side, y, z0, z1, n=7):
    pts = []
    for k in range(n + 1):
        z = z0 + (z1 - z0) * k / n
        pts.append(V(hull_x(y, z, side) + side * 0.002, y, z))
    _bead(b, pts, vertical=True)


def _rivet(b, p, n, r=0.020):
    W.sweep(b, [p, p + n * 0.009], W.round_profile(r, 6), B("metal", 1.0),
            scale=[1.0, 0.70], caps=(True, True), smooth=True)


def build_hp_relief(key, b):
    """HP-only surface detail (welds, plate edges, rivets, belts); never part of LOD0."""
    if key == "HullTopsides":
        for side in (1, -1):
            for zc in (0.95, 1.38, 1.80):
                _weld_h(b, side, zc, -7.35, 7.42)
            # one butt lands in the baked 3 m UV repeat (tiling repeats it aft), clear of the name and PH 42
            _weld_v(b, side, -6.95, 0.24, sheer_z(-6.95) - 0.20)
    elif key == "HullAntifoul":
        for side in (1, -1):
            for zc in (-1.52, -0.78):
                _weld_h(b, side, zc, -6.10, 7.34)
    elif key == "DeckInner":
        for side in (1, -1):
            for y in (-5.9, -4.5, -3.1, -1.7, -0.3, 1.1, 2.5, 3.9, 5.3, 6.7):
                z0, z1 = deck_z(y) + 0.08, sheer_z(y) - 0.12
                pts = []
                for k in range(5):
                    z = z0 + (z1 - z0) * k / 4
                    pts.append(V(hull_x(y, z, side) - side * 0.030, y, z))
                _bead(b, pts, vertical=True)
            for y in _span(-5.9, 6.7, 34):
                p = V(hull_x(y, sheer_z(y) - 0.13, side) - side * 0.030, y, sheer_z(y) - 0.13)
                _rivet(b, p, V(-side, 0, 0), 0.018)


def add_relief(hp, buf, mat_name):
    tmp = buf.to_object(hp.name + "_relief", mat_name)
    bm = bmesh.new()
    bm.from_mesh(hp.data)
    bm.from_mesh(tmp.data)
    bm.to_mesh(hp.data)
    bm.free()
    me = tmp.data
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.meshes.remove(me)
    hp.data.update()


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
    "G": [(1, 1, 0.18, 1), (0.18, 1, 0, 0.82), (0, 0.82, 0, 0.18), (0, 0.18, 0.18, 0),
          (0.18, 0, 0.85, 0), (0.85, 0, 1, 0.15), (1, 0.15, 1, 0.44), (1, 0.44, 0.56, 0.44)],
    "L": [(0, 0, 0, 1), (0, 0, 0.92, 0)],
    "I": [(0.5, 0, 0.5, 1)],
    "D": [(0, 0, 0, 1), (0, 1, 0.64, 1), (0.64, 1, 0.88, 0.80), (0.88, 0.80, 0.88, 0.20),
          (0.88, 0.20, 0.64, 0), (0.64, 0, 0, 0)],
    "V": [(0, 1, 0.5, 0), (0.5, 0, 1, 1)],
    "4": [(0.62, 1, 0.62, 0), (0.62, 1, 0, 0.32), (0, 0.32, 0.92, 0.32)],
    "2": [(0.10, 0.86, 0.88, 0.86), (0.88, 0.86, 0.88, 0.62), (0.88, 0.62, 0.10, 0.06), (0.10, 0.06, 1.0, 0.06)],
    " ": [],
}


def paint_text(b, text, ystart, direc, side, cellw, cellh, z_of_y, thick=0.014):
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
            pts = [V(hull_x(y, z, side) + side * 0.016, y, z) for (y, z) in corners]
            K.oface(b, pts, [(0.955, 0.947), (0.968, 0.947), (0.968, 0.958), (0.955, 0.958)], (side, 0, 0))
        u += cellw * 1.26


def paint_transom_text(b, text, xstart, direc, cellw, cellh, zbase, y_of_z, thick=0.013):
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
    nm = "GALE ISLE PROVIDER"
    rg = "PH 42"
    cw, ch = 0.095, 0.205
    rw, rh = 0.085, 0.145
    nlen = len(nm) * cw * 1.26
    rlen = len(rg) * rw * 1.26

    def zname(y):
        return 2.13 + 0.20 * cl((-5.10 - y) / 2.0)

    for side in (1, -1):
        direc = 1 if side > 0 else -1
        start = -6.32 if side > 0 else -6.32 + nlen
        paint_text(b, nm, start, direc, side, cw, ch, zname)
        startr = -6.30 if side > 0 else -6.30 + rlen
        paint_text(b, rg, startr, direc, side, rw, rh, lambda y: zname(y) - 0.235, thick=0.011)

    def yt(z):
        zk, zs = keel_z(L1), sheer_z(L1)
        return L1 + 0.024 + 0.078 * cl((z - zk) / (zs - zk))

    paint_transom_text(b, nm, 1.005, -1, 0.094, 0.140, 1.92, yt)
    paint_transom_text(b, rg, 0.246, -1, 0.078, 0.108, 1.75, yt, thick=0.010)
    for side in (1, -1):
        for (z, ln) in ((-1.55, 0.10), (-1.15, 0.16), (-0.75, 0.10), (-0.35, 0.16)):
            y = -6.10
            x = hull_x(y, z, side) + side * 0.006
            K.oface(b, [V(x, y - 0.05, z), V(x, y + 0.05, z), V(x, y + 0.05, z + ln), V(x, y - 0.05, z + ln)],
                    [(0.950, 0.950), (0.960, 0.950), (0.960, 0.960), (0.950, 0.960)], (side, 0, 0))
    return b


def _ci(node, k):
    return [i for i in node.inputs if i.type == "RGBA"][k]


def _co(node):
    return [o for o in node.outputs if o.type == "RGBA"][0]


def hex_srgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def material(key):
    name = "MI_Trawler_" + key
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


HP_DETAIL = ("HullTopsides", "HullAntifoul", "DeckInner")


def make_spec(parts, col, atts, hps=()):
    # relief parts last: bake fills flat NOR for HP-less parts as it goes, and last writer wins
    order = [k for k in parts if k not in HP_DETAIL] + [k for k in HP_DETAIL if k in parts]
    vis = [parts[k] for k in order]
    lo, hi = W.bbox(vis)
    dims = tuple((hi[i] - lo[i]) / S for i in range(3))
    for o in vis + [col]:
        K.fix_uv(o)
    print("[boat3] bbox studs %.3f x %.3f x %.3f  m %.3f x %.3f x %.3f" % (tuple(hi - lo) + dims))
    print("[boat3] tris %s total %d" % ({k: C.tri_count(o) for k, o in parts.items()},
                                        sum(C.tri_count(o) for o in vis)))
    meshes = [{"object": o, "set": "Atlas"} for o in vis] + [{"object": col}]
    meshes += [{"object": o, "role": "hp"} for o in hps]
    slots = {("MI_Trawler_" + k): {"base_color": COLORS[k], "metal": SLOT[k][0], "roughness": SLOT[k][1]}
             for k in COLORS}
    return {
        "name": NAME, "asset": NAME, "budget": BUDGET, "tris": BUDGET_TRIS, "tier": "standard",
        "dims_m": dims, "size_note": None, "origin": "free",
        "sets": [{"name": "FishingBoat", "set": "Atlas", "size": 2048, "wet": True, "slots": slots,
                  "wear": {"edge": 0.62, "edge_range": (0.13, 0.48), "edge_color": (0.52, 0.49, 0.43),
                           "edge_rough": 0.70, "salt": 0.30, "salt_range": (0.30, 0.80),
                           "salt_color": (0.68, 0.66, 0.59), "rust": 0.34, "rust_color": (0.36, 0.22, 0.14),
                           "rust_rough": 0.92, "rust_length": 0.85, "rust_fingers": 14, "ao_strength": 0.36}}],
        "atlas": "FishingBoat", "meshes": meshes, "attachments": atts, "bake_size": 2048,
        "tiling": True,
        "closeups": [
            {"name": "bow", "target": [0.0, -16.0, 6.9], "dist": 20.0, "az": 82, "el": 6},
            {"name": "wheelhouse", "target": [0.0, -8.6, 8.8], "dist": 16.0, "az": 118, "el": 10},
            {"name": "gantry", "target": [0.0, 19.8, 10.6], "dist": 15.0, "az": 205, "el": 14},
            {"name": "deck", "target": [0.0, 18.0, 10.0], "dist": 16.0, "az": 195, "el": 38},
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
        print("[boat3] %s: could not reach %d tris; proxied at LOD2" % (obj.name, target))


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


if not getattr(versions, "_mooredboat3_clean", False):
    versions.run_lod = _run_lod_clean
    versions.decimate = _decimate_tolerant
    versions._mooredboat3_clean = True


def build():
    C.clear_scene()
    bufs = {}
    bufs.update(build_hull())
    kb, kd = build_keel()
    bufs["KeelGear"] = kb
    bufs["KeelDark"] = kd
    bufs["DeckInner"] = build_deck()
    bufs["CapRail"] = build_cap_rail()
    bufs["Breakwater"] = build_breakwater()
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
    bufs["WindowFrames"] = trim
    bufs["CabinTrim"] = build_cabin_trim()
    rg, raftband, raftwhite = build_roof_gear()
    bufs["RoofGear"] = rg
    bufs["RaftBand"] = raftband
    bufs["RaftCanister"] = raftwhite
    fun, fundark = build_funnel()
    bufs["Funnel"] = fun
    bufs["FunnelDark"] = fundark
    mast, mdark, mred, mgreen, mwht = build_mast()
    bufs["Mast"] = mast
    bufs["MastDark"] = mdark
    bufs["NavRed"] = mred
    bufs["NavGreen"] = mgreen
    bufs["NavWhite"] = mwht
    gantry, gdark = build_gantry()
    bufs["Gantry"] = gantry
    bufs["GantryWire"] = gdark
    winch, wdark = build_winch()
    bufs["Winch"] = winch
    bufs["WinchWire"] = wdark
    nd, nnet, nband = build_net_drum()
    bufs["NetDrum"] = nd
    bufs["Net"] = nnet
    bufs["NetBands"] = nband
    doors, doorm, doorw = build_doors()
    bufs["OtterBoards"] = doors
    bufs["DoorFrames"] = doorm
    bufs["DoorWires"] = doorw
    fore, fored = build_foredeck()
    bufs["Foredeck"] = fore
    bufs["ForedeckDark"] = fored
    dk, dkt, dkr, dks = build_deck_fittings()
    bufs["DeckFittings"] = dk
    bufs["DeckSeams"] = dkt
    bufs["DeckRopes"] = dkr
    bufs["Scuppers"] = dks
    bufs["FishBoxes"] = build_fish_boxes()
    bk, bkh = build_baskets()
    bufs["Baskets"] = bk
    bufs["BasketHandles"] = bkh
    bu, bub, bur = build_buoys()
    bufs["Buoys"] = bu
    bufs["BuoyBands"] = bub
    bufs["BuoyRopes"] = bur
    tb, tr = build_tyres()
    bufs["Tyres"] = tb
    bufs["TyreRopes"] = tr
    lb, lstrip, ltrim = Buf(), Buf(), Buf()
    build_lifebuoy(lb, lstrip, ltrim)
    bufs["Lifebuoy"] = lb
    bufs["LifebuoyBand"] = lstrip
    bufs["LifebuoyTrim"] = ltrim
    ramp, rampd = build_stern_ramp()
    bufs["SternRamp"] = ramp
    bufs["SternRollers"] = rampd
    bufs["RustStreaks"] = build_rust()
    bufs["WheelhouseRust"] = build_wheelhouse_rust()
    bufs["BoardingGates"] = build_boarding_gates()
    bufs["Weed"] = build_weed()
    bufs["Letters"] = build_letters()

    mat_of = {
        "HullAntifoul": "Antifoul", "HullTopsides": "Navy", "BootTop": "White", "HullStripe": "Sheer",
        "KeelGear": "Metal", "KeelDark": "Dark", "DeckInner": "Inner", "CapRail": "Metal", "Breakwater": "Metal",
        "Cabin": "White", "Roof": "Sheer", "RoofTrim": "Metal",
        "GlassFront": "Glass", "GlassSide": "Glass", "GlassRear": "Glass",
        "WindowFrames": "Dark", "CabinTrim": "Dark", "RoofGear": "Metal",
        "RaftBand": "Motor", "RaftCanister": "White", "Funnel": "Motor", "FunnelDark": "Dark",
        "Mast": "Metal", "MastDark": "Dark", "NavRed": "Antifoul", "NavGreen": "Green", "NavWhite": "White",
        "Gantry": "Metal", "GantryWire": "Dark", "Winch": "Metal", "WinchWire": "Dark",
        "NetDrum": "Metal", "Net": "Green", "NetBands": "Motor",
        "OtterBoards": "Antifoul", "DoorFrames": "Metal", "DoorWires": "Dark",
        "Foredeck": "Metal", "ForedeckDark": "Dark", "DeckFittings": "Inner", "DeckSeams": "Metal",
        "DeckRopes": "Rope", "Scuppers": "Dark",
        "FishBoxes": "Green", "Baskets": "Dark", "BasketHandles": "Rope", "Buoys": "Motor", "BuoyBands": "White",
        "BuoyRopes": "Rope",
        "Tyres": "Dark", "TyreRopes": "Rope", "Lifebuoy": "White", "LifebuoyBand": "Antifoul", "LifebuoyTrim": "Metal",
        "SternRamp": "Metal", "SternRollers": "Dark", "RustStreaks": "Rust",
        "WheelhouseRust": "Rust", "BoardingGates": "Dark",
        "Weed": "Weed", "Letters": "White",
    }
    parts = {}
    for k, buf in bufs.items():
        parts[k] = buf.to_object("M_Veh_MooredBoat_%s_03_LOD0" % k, material(mat_of[k]).name)
    K.finish(NAME, parts, recalc=("KeelGear", "WindowFrames", "CabinTrim", "RoofGear", "FunnelDark",
                                  "MastDark", "NavRed", "NavGreen", "NavWhite", "OtterBoards"))
    for o in parts.values():
        clean_part(o)
    relief = {}
    for k in HP_DETAIL:
        rb = Buf()
        build_hp_relief(k, rb)
        relief[k] = rb
    hps = []
    for k, rb in relief.items():
        o = parts[k]
        hp = o.copy()
        hp.data = o.data.copy()
        hp.name = o.name[:-5] + "_HP"
        hp.data.name = hp.name
        for c in o.users_collection:
            c.objects.link(hp)
        add_relief(hp, rb, material(mat_of[k]).name)
        hps.append(hp)
    atts = [W.empty("ATT_Waterline", (0, 0, 0)),
            W.empty("ATT_Moor_Bow", (0, -6.95, deck_z(-6.95) + 0.12), look=(0, -1, 0)),
            W.empty("ATT_Moor_Stern", (0, 7.25, deck_z(7.25) + 0.10), look=(0, 1, 0)),
            W.empty("ATT_Boarding_Port", (2.20, 1.0, 1.85), look=(1, 0, 0)),
            W.empty("ATT_Boarding_Stbd", (-2.20, 1.0, 1.85), look=(-1, 0, 0))]
    I = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    col = W.col_boxes([((0, -0.15, 0.35), I, (2.10, 7.45, 2.15)),
                       ((0, -2.15, 3.05), I, (1.55, 1.40, 1.45)),
                       ((0, 6.85, 4.10), I, (1.85, 0.90, 2.05))], "M_Veh_MooredBoat_Hull_03_COL")
    return make_spec(parts, col, atts, hps)
