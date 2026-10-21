"""C3 M_Veh_MooredBoat_01: a clinker-built Cornish harbour punt (about 4 m), moored set dressing.

Faded Cornish-blue topsides with a chalky white sheer strake, oxblood antifouling below the waterline, varnished
thwarts, gunwale and transom, weathered bilge timber, galvanised rowlocks, two oars stowed aboard, a rainwater
bilge with a bailer, weed at the waterline and a small outboard tilted up on the transom. Painted registration
"PH 41" raised on both bow quarters (so it reads correctly from either side).

Blender axes: X beam (+X port), Y length (bow -Y), Z up. Origin at the waterline, midships: waterline z = 0,
bow -Y. One shared trim atlas T_FishingBoat_Atlas (2048) for _01.._03: material bands are stable, so the crabber
and trawler reuse the same set layout. MeshParts are one material each; _COL is three closed boxes.
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

NAME = "M_Veh_MooredBoat_01"
BUDGET, BUDGET_TRIS = "small_craft", 12000
S = 3.0
L0, L1 = -1.86, 1.86
BEAM = 0.742

# atlas bands (v ranges); shared by _01.._03
BANDS = {
    "antifoul": (0.000, 0.100), "blue": (0.100, 0.240), "sheer": (0.240, 0.310),
    "inner": (0.310, 0.390), "varnish": (0.390, 0.530), "wood": (0.530, 0.620),
    "metal": (0.620, 0.690), "motor": (0.690, 0.770), "dark": (0.770, 0.825),
    "rope": (0.825, 0.875), "water": (0.875, 0.905), "weed": (0.905, 0.945),
    "white": (0.945, 0.972), "bailer": (0.972, 1.000),
}
B = K.bandfn(BANDS)

COLORS = {  # sRGB base colours (also the bake slot colours)
    "Antifoul": "#71392F", "Blue": "#46697C", "Sheer": "#D6D4C6", "Inner": "#6F8185",
    "Varnish": "#9B6A3C", "Wood": "#7C664A", "Metal": "#92958F", "Motor": "#C6C2AD",
    "Dark": "#34393B", "Rope": "#9C8A68", "Water": "#2B3A33", "Weed": "#4A5C2C",
    "White": "#E4E2D7", "Bailer": "#3F6B52",
}
SLOT = {  # metal / roughness per material
    "Antifoul": (0.0, 0.80), "Blue": (0.0, 0.62), "Sheer": (0.0, 0.66), "Inner": (0.0, 0.72),
    "Varnish": (0.0, 0.58), "Wood": (0.0, 0.82), "Metal": (1.0, 0.38), "Motor": (0.0, 0.55),
    "Dark": (0.85, 0.42), "Rope": (0.0, 0.90), "Water": (0.0, 0.10), "Weed": (0.0, 0.85),
    "White": (0.0, 0.58), "Bailer": (0.0, 0.48),
}
PROC = {
    "Antifoul": dict(mottle=(3.5, 0.08), grime=("#4E2C27", 0.30), salt=("#8E8678", 0.20)),
    "Blue": dict(mottle=(3.0, 0.06), grime=("#2C4658", 0.27), salt=("#9EA3A0", 0.18)),
    "Sheer": dict(mottle=(4.0, 0.045), grime=("#B4B2A5", 0.26), salt=("#A9A79A", 0.16)),
    "Inner": dict(mottle=(3.0, 0.07), grime=("#5E6E70", 0.30)),
    "Varnish": dict(mottle=(5.0, 0.06), grain=("#6C4926", 0.24), salt=("#A79E8A", 0.13)),
    "Wood": dict(mottle=(2.6, 0.08), grain=("#52422C", 0.24), salt=("#9A9280", 0.18)),
    "Metal": dict(mottle=(6.0, 0.04), grime=("#6F736E", 0.24)),
    "Motor": dict(mottle=(4.5, 0.05), grime=("#8E8D7E", 0.22), salt=("#BDBAA8", 0.14)),
    "Dark": dict(mottle=(5.0, 0.04), grime=("#24282A", 0.20)),
    "Rope": dict(mottle=(9.0, 0.07), grime=("#6E6047", 0.22)),
    "Water": dict(mottle=(2.2, 0.03)),
    "Weed": dict(mottle=(7.0, 0.12), grime=("#3C4926", 0.28)),
    "White": dict(mottle=(6.0, 0.03), grime=("#C9C6B8", 0.16)),
    "Bailer": dict(mottle=(5.0, 0.05), grime=("#2E5140", 0.20)),
}


# ------------------------------------------------------------------ hull form (metres; waterline z = 0)
def t_of(y):
    return (y - L0) / (L1 - L0)


def half_beam(y):
    t = min(max(t_of(y), 0.0), 1.0)
    if t < 0.45:
        return BEAM * math.sin(0.5 * math.pi * t / 0.45) ** 0.62
    if t < 0.72:
        return BEAM + 0.012 * math.sin(math.pi * (t - 0.45) / 0.27)
    return BEAM - (BEAM - 0.526) * ((t - 0.72) / 0.28) ** 1.5


def sheer_z(y):
    t = min(max(t_of(y), 0.0), 1.0)
    return 0.44 + 0.175 * max(0.0, (0.42 - t) / 0.42) ** 1.5 + 0.02 * max(0.0, (t - 0.75) / 0.25)


def keel_z(y):
    t = min(max(t_of(y), 0.0), 1.0)
    return -0.205 + 0.185 * max(0.0, (0.30 - t) / 0.30) ** 1.9 + 0.055 * max(0.0, (t - 0.75) / 0.25) ** 1.6


def sec_raw(y, s):
    w = half_beam(y)
    z0 = keel_z(y)
    h = sheer_z(y) - z0
    return w * max(math.sin(0.5 * math.pi * s), 0.0) ** 1.22, z0 + h * s ** 2.15


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


def hull_x(y, z, side=1):
    z0, z1 = keel_z(y), sheer_z(y)
    s = min(max((max(z, z0) - z0) / max(z1 - z0, 1e-5), 0.0), 1.0) ** (1 / 2.15)
    return side * sec_raw(y, s)[0]


def stations(n=16, a=0.004, b=0.996):
    return [L0 + (L1 - L0) * (a + (b - a) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1)))) for i in range(n)]


STRAKES = [(0.00, 0.24), (0.24, 0.42), (0.42, 0.60), (0.60, 0.78), (0.78, 0.90), (0.90, 1.00)]


def strake_rows(a, b, first):
    out = []
    if first and a <= 1e-6:
        out.append((0.0, 0.0))
    else:
        out += [(a - 0.0012, 0.0015), (a + 0.0012, 0.0105)]
    out += [(a + 0.33 * (b - a), 0.0088), (a + 0.66 * (b - a), 0.0062), (b - 0.002, 0.0020)]
    return out


def hull_group(buf, s0, s1, band, uoff=0.0):
    rows_s = []
    for idx, (a, b) in enumerate(STRAKES):
        if b <= s0 + 1e-6 or a >= s1 - 1e-6:
            continue
        rows_s += strake_rows(max(a, s0), min(b, s1), idx == 0 and s0 <= 1e-6)
    rows, uvs = [], []
    for side in (1, -1):
        for y in stations():
            row = [sec(y, s, side, off) for s, off in rows_s]
            rows.append(row)
            uvs.append([((y - L0) / 3.1 + uoff + (0.0 if side > 0 else 0.47), 0.0) for _ in row])
    # split sides into separate grids so the want vectors stay per-side
    for side in (1, -1):
        rr = [r for r, u in zip(rows, uvs) if r[0].x * side >= -1e-6 and r[len(r) // 2].x * side >= -1e-6]
        uu = [u for r, u in zip(rows, uvs) if r[0].x * side >= -1e-6 and r[len(r) // 2].x * side >= -1e-6]
        v0, v1 = BANDS[band]
        uu = [[(u[0], v0 + 0.004 + (v1 - v0 - 0.008) * (j / max(len(r) - 1, 1))) for j, u in enumerate(r)]
              for r in uu]
        K.ogrid(buf, rr, uu, lambda c: Vector((c.x, 0.0, (c.z - 0.34) * 0.6)))
    return buf


def build_hull():
    parts = {}
    for key, band, s0, s1, uo in (("HullAntifoul", "antifoul", 0.00, 0.60, 0.00),
                                  ("HullTopsides", "blue", 0.60, 0.90, 0.11),
                                  ("HullSheer", "sheer", 0.90, 1.00, 0.23)):
        b = Buf()
        hull_group(b, s0, s1, band, uo)
        parts[key] = b
    # inner skin, both sides, one mesh
    b = Buf()
    rows, uvs = [], []
    ss = [0.055 + (1.0 - 0.055) * (j / 11) ** 1.05 for j in range(12)]
    for side in (1, -1):
        rr = []
        for y in stations(14, 0.012, 0.988):
            rr.append([sec(y, s, side, -0.021) for s in ss])
        v0, v1 = BANDS["inner"]
        uu = [[((p.y - L0) / 2.9 + (0.02 if side > 0 else 0.51), v0 + 0.004 + (v1 - v0 - 0.008) * (j / 11))
               for j, p in enumerate(row)] for row in rr]
        K.ogrid(b, rr, uu, lambda c: -Vector((c.x, 0.0, (c.z - 0.34) * 0.6)))
    parts["Inner"] = b
    return parts


# ------------------------------------------------------------------ timber
def build_joinery():
    b = Buf()
    uv = B("varnish", 2.8)
    # gunwale rubbing strakes
    prof = [(-0.046, -0.020), (0.048, -0.020), (0.048, 0.008), (0.032, 0.034), (-0.046, 0.034)]
    for side in (1, -1):
        pts = [V(side * (half_beam(y) - 0.004), y, sheer_z(y)) for y in stations(16, 0.0, 0.994)]
        pr = [(side * dx, dz) for dx, dz in prof]
        W.sweep(b, pts, pr, uv, axes=[((1, 0, 0), (0, 0, 1))] * len(pts), caps=(True, True))
    # stem band (vertical) and keel band
    W.sweep(b, [V(0, -1.885, -0.03), V(0, -1.89, 0.15), V(0, -1.885, 0.40), V(0, -1.87, 0.615)],
            W.rect_profile(0.055, 0.048, 0.008), uv, axes=[((1, 0, 0), (0, 1, 0))] * 4, caps=(True, True))
    kb = [V(0, y, keel_z(y) - 0.006) for y in stations(10, 0.08, 0.995)]
    W.sweep(b, kb, W.rect_profile(0.052, 0.030, 0.006), uv, axes=[((1, 0, 0), (0, 0, 1))] * len(kb),
            caps=(True, True))
    # transom: clinker panel, raked aft, varnished
    transom(b, uv)
    # transom cap
    w = half_beam(L1)
    W.sweep(b, [V(-w - 0.045, 1.885, sheer_z(L1) + 0.018), V(w + 0.045, 1.885, sheer_z(L1) + 0.018)],
            W.rect_profile(0.052, 0.062, 0.008), uv, axes=[((0, 1, 0), (0, 0, 1))] * 2, caps=(True, True))
    # thwarts
    for y, zt in ((-0.78, 0.315), (0.06, 0.300), (1.16, 0.320)):
        thwart(b, y, zt, uv)
    # rowlock pads
    for side in (1, -1):
        x = side * (half_beam(0.06) - 0.012)
        W.sweep(b, [V(x, 0.06, sheer_z(0.06) + 0.030), V(x, 0.06, sheer_z(0.06) + 0.062)],
                W.round_profile(0.030, 8), uv, axes=[((1, 0, 0), (0, 1, 0))] * 2, caps=(True, True))
    return b


def transom(b, uv):
    z0, z1 = keel_z(L1) - 0.01, sheer_z(L1)
    ws = half_beam(L1)
    rows, uvs = [], []
    n = 11
    for k in range(n):
        z = z0 + (z1 - z0) * k / (n - 1)
        f = (z - z0) / (z1 - z0)
        hw = ws * (0.94 + 0.06 * f)
        yy = 1.868 + 0.052 * f
        rows.append([V(-hw + 2 * hw * j / 8, yy, z) for j in range(9)])
        uvs.append([(-hw + 2 * hw * j / 8, 0.0) for j in range(9)])
    # outer face, planks: every 2 rows nudge the lap outward
    for i in range(n - 1):
        if i % 2 == 1:
            rows[i] = [p + V(0, 0.006, 0.0) for p in rows[i]]
    uu = [[(p.x, BANDS["varnish"][0] + 0.005 + (BANDS["varnish"][1] - BANDS["varnish"][0] - 0.01) * (j / 8))
           for j, p in enumerate(r)] for r in rows]
    K.ogrid(b, rows, uu, (0, 1, 0))
    # inner face
    rin = [[p - V(0, 0.030, 0.0) for p in r] for r in rows]
    K.ogrid(b, rin, uu, (0, -1, 0))
    # edges
    for i in range(n - 1):
        K.oface(b, [rows[i][0], rows[i + 1][0], rin[i + 1][0], rin[i][0]],
                [(0.01, 0.01), (0.01, 0.02), (0.02, 0.02), (0.02, 0.01)], (-1, 0, 0))
        K.oface(b, [rows[i][-1], rin[i][-1], rin[i + 1][-1], rows[i + 1][-1]],
                [(0.01, 0.01), (0.02, 0.01), (0.02, 0.02), (0.01, 0.02)], (1, 0, 0))
    for j in range(8):
        K.oface(b, [rows[0][j], rows[0][j + 1], rin[0][j + 1], rin[0][j]],
                [(0.01, 0.01), (0.02, 0.01), (0.02, 0.02), (0.01, 0.02)], (0, 0, -1))
        K.oface(b, [rows[-1][j], rin[-1][j], rin[-1][j + 1], rows[-1][j + 1]],
                [(0.01, 0.01), (0.02, 0.01), (0.02, 0.02), (0.01, 0.02)], (0, 0, 1))


def thwart(b, y, zt, uv):
    xh = half_beam(y) - 0.038
    ys = [y + 0.118, y + 0.088, y - 0.088, y - 0.118]
    widths = [0.52, 1.0, 1.0, 0.52]
    rings = []
    for yy, wf in zip(ys, widths):
        ring = []
        for j in range(7):
            x = -xh * wf + 2 * xh * wf * j / 6
            camber = 0.011 * (1 - (x / max(xh * wf, 1e-5)) ** 2)
            ring.append(V(x, yy, zt + camber))
        for j in range(6, -1, -1):
            x = -xh * wf + 2 * xh * wf * j / 6
            ring.append(V(x, yy, zt - 0.033 - 0.002 * (1 - (x / max(xh * wf, 1e-5)) ** 2)))
        rings.append(ring)
    v0, v1 = BANDS["varnish"]
    for k in range(len(rings) - 1):
        for j in range(14):
            a, c = rings[k][j], rings[k][(j + 1) % 14]
            d, e = rings[k + 1][(j + 1) % 14], rings[k + 1][j]
            vv = v0 + 0.008 + (v1 - v0 - 0.016) * (j / 14)
            vv2 = v0 + 0.008 + (v1 - v0 - 0.016) * ((j + 1) / 14)
            K.oface(b, [a, c, d, e], [(0.05 + j * 0.06, vv), (0.05 + (j + 1) * 0.06, vv),
                                      (0.05 + (j + 1) * 0.06, vv2), (0.05 + j * 0.06, vv2)],
                    lambda c: Vector((c.x, 0.0, c.z - zt)))
    for ring, want in ((rings[0], (0, 1, 0)), (rings[-1], (0, -1, 0))):
        K.oface(b, ring, [(0.02 + i * 0.05, BANDS["varnish"][0] + 0.06) for i in range(14)], want)


def build_bilge_wood():
    b = Buf()
    uv = B("wood", 2.2)
    # six steamed ribs following the inner skin
    nrm = lambda c, sd: Vector((c.x, 0, (c.z - 0.34) * 0.6))
    for y in (-1.30, -0.90, -0.40, 0.15, 0.65, 1.15):
        path = []
        for side in (1, -1):
            ss = [0.985 - (0.985 - 0.055) * (j / 9) for j in range(10)] if side > 0 else \
                 [0.055 + (0.985 - 0.055) * (j / 9) for j in range(10)]
            seg = [sec(y, s, side, -0.014) for s in ss]
            if side == 1:
                path += seg
            else:
                path += seg[1:]
        axes = []
        for i, p in enumerate(path):
            sd = 1 if p.x >= 0 else -1
            axes.append(((0, 1, 0), -Vector((p.x * sd, 0, (p.z - 0.34) * 0.6)).normalized()))
        W.sweep(b, path, W.rect_profile(0.032, 0.016, 0.004), uv, axes=axes, caps=(True, True))
    # floorboards, three slats, raised clear of the waterline: the game's sea is one opaque surface that also
    # runs through the hull (no stencil), so anything below z ~0.1 reads as flooded
    for x in (-0.24, 0.0, 0.24):
        pts = []
        for y in (-1.15, -0.7, -0.2, 0.3, 0.8, 1.3):
            z = 0.115 + 0.028 * (abs(x) / 0.30) ** 2
            pts.append(V(x, y, z))
        W.sweep(b, pts, W.rect_profile(0.145, 0.022, 0.005), uv, axes=[((1, 0, 0), (0, 0, 1))] * len(pts),
                caps=(True, True))
    return b


def build_oars():
    b = Buf()
    uv = B("varnish", 1.4)
    for side, y0, y1 in ((1, -0.78, 1.30), (-1, -0.64, 1.38)):
        a = V(side * 0.25, y0, 0.170)
        c = V(side * 0.38, y1, 0.260)
        d = (c - a).normalized()
        W.sweep(b, [a, a.lerp(c, 0.45), a.lerp(c, 0.62), c], W.round_profile(0.023, 8), uv,
                scale=[1.0, 1.0, 0.92, 0.82], caps=(True, True))
        # blade at the inboard end (forward), flat, 0.44 x 0.15
        bc = a - d * 0.24
        up = V(0, 0, 1)
        sd = d.cross(up).normalized()
        ring = [bc + d * 0.26, bc + d * 0.13 + sd * 0.075, bc - d * 0.16 + sd * 0.062,
                bc - d * 0.23, bc - d * 0.16 - sd * 0.062, bc + d * 0.13 - sd * 0.075]
        top = [p + up * 0.008 for p in ring]
        bot = [p - up * 0.008 for p in ring]
        K.oface(b, top, [(0.3 + i * 0.04, 0.405) for i in range(6)], (0, 0, 1), smooth=True)
        K.oface(b, bot, [(0.3 + i * 0.04, 0.505) for i in range(6)], (0, 0, -1), smooth=True)
        for i in range(6):
            K.oface(b, [ring[i], top[i], top[(i + 1) % 6], ring[(i + 1) % 6]],
                    [(0.3 + i * 0.04, 0.455), (0.3 + i * 0.04, 0.475), (0.3 + (i + 1) * 0.04, 0.475),
                     (0.3 + (i + 1) * 0.04, 0.455)], (0, 0, 1))
    return b


# ------------------------------------------------------------------ metal fittings
def build_fittings():
    b = Buf()
    uv = B("metal", 1.0)
    for side in (1, -1):
        x = side * (half_beam(0.06) - 0.012)
        z = sheer_z(0.06) + 0.062
        # rowlock: socket + U crutch
        W.sweep(b, [V(x, 0.06, z - 0.02), V(x, 0.06, z + 0.020)], W.round_profile(0.024, 10), uv,
                axes=[((1, 0, 0), (0, 1, 0))] * 2, caps=(True, True))
        for dy in (-0.055, 0.055):
            C.tube(b, [V(x, 0.06 + dy, z + 0.012), V(x, 0.06 + dy, z + 0.095)], 0.012, uv, sides=8)
        C.tube(b, [V(x, 0.005, z + 0.095), V(x, 0.06, z + 0.118), V(x, 0.115, z + 0.095)], 0.012, uv, sides=8)
        # a pad under the socket
        W.sweep(b, [V(x, 0.06, sheer_z(0.06) + 0.020), V(x, 0.06, sheer_z(0.06) + 0.040)],
                W.rect_profile(0.10, 0.075, 0.014), uv, axes=[((1, 0, 0), (0, 1, 0))] * 2, caps=(True, True))
    # bow ring through the stem
    W.ring(b, V(0, -1.925, 0.455), (1, 0, 0), (0, 0, 1), 0.045, 0.008, 14, 6, uv)
    C.tube(b, [V(0, -1.893, 0.455), V(0, -1.918, 0.455)], 0.011, uv, sides=8)
    # stern cleat
    W.sweep(b, [V(-0.10, 1.88, 0.50), V(0.10, 1.88, 0.50)], W.round_profile(0.016, 8), uv,
            axes=[((0, 1, 0), (0, 0, 1))] * 2, caps=(True, True))
    for dx in (-0.075, 0.075):
        C.tube(b, [V(dx, 1.86, 0.475), V(dx, 1.88, 0.505)], 0.012, uv, sides=8)
        C.tube(b, [V(dx, 1.86, 0.475), V(dx, 1.84, 0.502)], 0.012, uv, sides=8)
    return b


# ------------------------------------------------------------------ outboard
def outboard_parts():
    cowl = Buf()
    uv = B("motor", 1.0)
    # cowling: loft of rounded rectangles, faded cream
    lev = [(0.075, 0.100, 0.085), (0.16, 0.135, 0.118), (0.27, 0.138, 0.120), (0.325, 0.105, 0.090)]
    rings = []
    for z, hx, hy in lev:
        ring = []
        for j in range(16):
            a = 2 * math.pi * j / 16
            cx, cy = math.cos(a), math.sin(a)
            rx = hx * (1 if abs(cx) > 0.55 else 0.86)
            ry = hy * (1 if abs(cy) > 0.55 else 0.86)
            ring.append(V(rx * cx, ry * cy, z))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for j in range(16):
            a, c = rings[k][j], rings[k][(j + 1) % 16]
            d, e = rings[k + 1][(j + 1) % 16], rings[k + 1][j]
            K.oface(cowl, [a, c, d, e], [(j / 16, 0.70), ((j + 1) / 16, 0.70), ((j + 1) / 16, 0.76), (j / 16, 0.76)],
                    lambda q: Vector((q.x, q.y, 0.0)))
    K.oface(cowl, rings[-1], [(j / 16, 0.705) for j in range(16)], (0, 0, 1))
    # lower pan under the cowl
    W.sweep(cowl, [V(0, 0, 0.045), V(0, 0, 0.085)], W.rect_profile(0.24, 0.20, 0.03), uv,
            axes=[((1, 0, 0), (0, 1, 0))] * 2, caps=(True, True))
    # tiller
    C.tube(cowl, [V(0.04, -0.10, 0.16), V(0.04, -0.28, 0.15), V(0.04, -0.44, 0.165)], 0.016, uv, sides=8)
    C.tube(cowl, [V(0.04, -0.40, 0.163), V(0.04, -0.48, 0.168)], 0.020, uv, sides=8)
    # fuel cap
    C.tube(cowl, [V(-0.07, 0.0, 0.323), V(-0.07, 0.0, 0.343)], 0.028, uv, sides=10)

    gear = Buf()
    gv = B("dark", 0.8)
    # leg, tapering down
    W.sweep(gear, [V(0, 0, 0.075), V(0, 0, -0.18), V(0, 0, -0.40)], W.rect_profile(0.075, 0.090, 0.012), gv,
            axes=[((1, 0, 0), (0, 1, 0))] * 3, scale=[1.0, 0.92, 0.72], caps=(True, True))
    # cavitation plate + skeg
    W.sweep(gear, [V(0, -0.09, -0.365), V(0, 0.10, -0.365)], W.rect_profile(0.23, 0.016, 0.005), gv,
            axes=[((1, 0, 0), (0, 0, 1))] * 2, caps=(True, True))
    W.sweep(gear, [V(0, -0.07, -0.44), V(0, 0.02, -0.47), V(0, 0.10, -0.44)], W.rect_profile(0.030, 0.090, 0.006),
            gv, axes=[((1, 0, 0), (0, 0, 1))] * 3, caps=(True, True))
    # gearcase bullet + prop (disc in XZ, shaft along Y)
    C.tube(gear, [V(0, -0.03, -0.435), V(0, 0.13, -0.425)], 0.047, gv, sides=10)
    C.tube(gear, [V(0, 0.12, -0.425), V(0, 0.19, -0.425)], 0.026, gv, sides=8)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        sd = V(math.cos(a), 0, math.sin(a)) * 0.085
        tip = V(0, 0.175, -0.425)
        quad = [tip - sd * 0.35, tip + sd * 0.55, tip + sd + V(0, 0.022, 0.012),
                tip - sd + V(0, 0.022, 0.012)]
        top = [p + V(0, 0.005, 0) for p in quad]
        bot = [p - V(0, 0.005, 0) for p in quad]
        K.oface(gear, top, [(0.5, 0.780), (0.56, 0.780), (0.56, 0.800), (0.5, 0.800)], (0, 1, 0))
        K.oface(gear, bot, [(0.5, 0.780), (0.56, 0.780), (0.56, 0.800), (0.5, 0.800)], (0, -1, 0))
        for i in range(4):
            K.oface(gear, [quad[i], top[i], top[(i + 1) % 4], quad[(i + 1) % 4]],
                    [(0.5 + i * 0.015, 0.786), (0.5 + i * 0.015, 0.794), (0.5 + (i + 1) * 0.015, 0.794),
                     (0.5 + (i + 1) * 0.015, 0.786)], lambda q: Vector((q.x, 0.0, q.z + 0.425)))
    C.tube(gear, [V(0, 0.18, -0.425), V(0, 0.205, -0.425)], 0.020, gv, sides=8)

    band = Buf()
    buv = B("antifoul", 0.4)
    for j in range(16):
        a0, a1 = 2 * math.pi * j / 16, 2 * math.pi * (j + 1) / 16
        p0 = V(0.138 * math.cos(a0), 0.120 * math.sin(a0), 0.243)
        p1 = V(0.138 * math.cos(a1), 0.120 * math.sin(a1), 0.243)
        p2 = V(0.136 * math.cos(a1), 0.118 * math.sin(a1), 0.272)
        p3 = V(0.136 * math.cos(a0), 0.118 * math.sin(a0), 0.272)
        K.oface(band, [p0, p1, p2, p3], [(j / 16, 0.004), ((j + 1) / 16, 0.004), ((j + 1) / 16, 0.096),
                                       (j / 16, 0.096)], (math.cos(a0), math.sin(a0), 0))

    mount = Buf()
    mv = B("metal", 0.7)
    # clamp bracket straddling the transom top (static, not tilted)
    for dx in (-0.105, 0.105):
        W.sweep(mount, [V(0.30 + dx, 1.84, 0.47), V(0.30 + dx, 1.84, 0.60)], W.rect_profile(0.20, 0.016, 0.004), mv,
                axes=[((1, 0, 0), (0, 1, 0))] * 2, caps=(True, True))
        C.tube(mount, [V(0.30 + dx, 1.825, 0.455), V(0.30 + dx, 1.825, 0.535)], 0.010, mv, sides=8)
        C.tube(mount, [V(0.30 + dx, 1.775, 0.535), V(0.30 + dx, 1.875, 0.535)], 0.008, mv, sides=6)
    W.sweep(mount, [V(0.30, 1.83, 0.585), V(0.30, 1.95, 0.585)], W.round_profile(0.036, 10), mv,
            axes=[((1, 0, 0), (0, 0, 1))] * 2, caps=(True, True))
    return cowl, gear, band, mount


def place_motor(buf, mount, tilt=95.0):
    M = Matrix.Translation(Vector(mount)) @ Matrix.Rotation(math.radians(tilt), 4, "X")
    buf.transform(M)


# ------------------------------------------------------------------ rope, bilge, weed, letters
def build_rope():
    b = Buf()
    uv = B("rope", 0.55)
    ring = V(0, -1.925, 0.415)
    pts = [ring + V(0.035, -0.012, -0.020), ring + V(0.040, 0.020, -0.010),
           V(0.018, -1.90, 0.55), V(0.075, -1.82, 0.585), V(0.15, -1.66, 0.48),
           V(0.12, -1.42, 0.40), V(0.08, -1.12, 0.38), V(0.03, -0.90, 0.355)]
    C.tube(b, pts, 0.0095, uv, sides=6)
    coil = []
    for i in range(40):
        a = 2 * math.pi * i / 12.0
        r = 0.108 - 0.007 * i / 40
        coil.append(V(0.02 + r * math.cos(a), -0.78 + r * math.sin(a), 0.335 - 0.002 * (i // 14)))
    C.tube(b, coil, 0.0095, uv, sides=6)
    return b


def build_bilge_water():
    b = Buf()
    rows, uvs = [], []
    for i in range(9):
        y = -0.62 + (1.48 + 0.62) * i / 8
        z = -0.104
        wl = 0.0
        for s in [j / 40 for j in range(41)]:
            if sec_raw(y, s)[1] >= z:
                wl = sec_raw(y, s)[0]
                break
        hw = max(wl - 0.028, 0.02)
        row = []
        for j in range(7):
            x = -hw + 2 * hw * j / 6
            ripple = 0.0022 * math.sin(x * 11 + y * 4) + 0.0015 * math.cos(y * 13 - x * 6)
            row.append(V(x, y, z + ripple))
        rows.append(row)
    uvs = [[(0.06 + 0.90 * j / 6, BANDS["water"][0] + 0.006 + (BANDS["water"][1] - BANDS["water"][0] - 0.012) * i / 8)
            for j in range(7)] for i in range(9)]
    K.ogrid(b, rows, uvs, (0, 0, 1), smooth=True)
    return b


def build_bailer():
    b = Buf()
    uv = B("bailer", 0.6)
    prof = [(0.004, 0.0), (0.062, 0.0), (0.080, 0.135), (0.074, 0.135), (0.056, 0.014), (0.004, 0.014)]
    W.lathe(b, prof, 14, lambda k, a: (a * 0.24, BANDS["bailer"][0] + 0.005 + (k / 5) * 0.06))
    C.tube(b, [V(-0.075, 0, 0.125), V(0, 0.005, 0.145), V(0.075, 0, 0.125)], 0.0055, uv, sides=6)
    M = Matrix.Translation(Vector((-0.24, 0.72, 0.145))) @ Matrix.Rotation(math.radians(28), 4, "X") @ \
        Matrix.Rotation(math.radians(-18), 4, "Y")
    b.transform(M)
    return b


def build_weed():
    b = Buf()
    uv = B("weed", 0.8)
    for side in (1, -1):
        # waterline strip
        rows = []
        for y in stations(18, 0.03, 0.97):
            z0, z1 = 0.002, 0.030 + 0.010 * math.sin(y * 3.1)
            p0 = sec(y, min(max((z0 - keel_z(y)) / (sheer_z(y) - keel_z(y)), 0), 1) ** (1 / 2.15), side, 0.004)
            p1 = sec(y, min(max((z1 - keel_z(y)) / (sheer_z(y) - keel_z(y)), 0), 1) ** (1 / 2.15), side, 0.004)
            rows.append([p0, p1])
        uu = [[((row[0].y - L0) / 1.3, BANDS["weed"][0] + 0.005), ((row[1].y - L0) / 1.3, BANDS["weed"][1] - 0.005)] for row in rows]
        K.ogrid(b, rows, uu, lambda c: Vector((c.x, 0, -0.3)))
        # weed tufts
        for k, y in enumerate([-1.55, -1.25, -0.95, -0.62, -0.30, 0.02, 0.34, 0.66, 0.98, 1.30, 1.55, 1.74]):
            x = hull_x(y, 0.006, side)
            for j in range(3):
                yy = y + (j - 1) * 0.045
                p0 = V(x + side * 0.002, yy, 0.012)
                p1 = V(x + side * 0.016, yy + (j - 1) * 0.02, -0.030)
                p2 = V(x + side * 0.028, yy + (j - 1) * 0.035, -0.075 - 0.02 * (j % 2))
                W.sweep(b, [p0, p1, p2], W.round_profile(0.0045, 4), uv, scale=[1.0, 0.65, 0.15],
                        caps=(True, True), smooth=True)
    return b


def build_letters():
    b = Buf()
    glyphs = {
        "P": [(0.00, 0.00, 0.020, 0.140), (0.00, 0.120, 0.078, 0.140), (0.060, 0.062, 0.078, 0.140),
              (0.000, 0.062, 0.060, 0.082)],
        "H": [(0.00, 0.00, 0.020, 0.140), (0.070, 0.00, 0.090, 0.140), (0.000, 0.060, 0.090, 0.080)],
        "4": [(0.060, 0.000, 0.080, 0.140), (0.000, 0.066, 0.080, 0.086), (0.000, 0.066, 0.020, 0.140)],
        "1": [(0.038, 0.000, 0.058, 0.140), (0.018, 0.116, 0.038, 0.140), (0.038, 0.000, 0.078, 0.020)],
    }
    text = "PH 41"
    def zb(y):
        return 0.140 + 0.040 * max(0.0, min(1.0, (-1.20 - y) / 0.40))
    for side, ystart, direc in ((1, -1.58, 1), (-1, -1.14, -1)):
        u = 0.0
        for ch in text:
            if ch == " ":
                u += 0.050
                continue
            for (ax, az, bx, bz) in glyphs[ch]:
                y0, y1 = ystart + direc * (u + ax * 0.92), ystart + direc * (u + bx * 0.92)
                if direc < 0:
                    y0, y1 = y1, y0
                z0, z1 = zb(y0) + az * 0.82, zb(y0) + bz * 0.82
                z0b, z1b = zb(y1) + az * 0.82, zb(y1) + bz * 0.82
                corners = [(y0, z0), (y1, z0b), (y1, z1b), (y0, z1)]
                outer = [V(hull_x(y, z, side) + side * 0.0130, y, z) for y, z in corners]
                inner = [V(hull_x(y, z, side) + side * 0.0080, y, z) for y, z in corners]
                uv = B("white", 0.5)
                vv = [(0.01, 0.01), (0.02, 0.01), (0.02, 0.02), (0.01, 0.02)]
                K.oface(b, outer, [(j * 0.02, 0.96) for j in range(4)], (side, 0, 0))
                K.oface(b, inner, [(j * 0.02, 0.96) for j in range(4)], (-side, 0, 0))
                for i in range(4):
                    K.oface(b, [outer[i], inner[i], inner[(i + 1) % 4], outer[(i + 1) % 4]],
                            [(0.01, 0.01), (0.015, 0.01), (0.015, 0.015), (0.01, 0.015)], (0, 0, 1))
            u += 0.096
    return b


# ------------------------------------------------------------------ materials
def _ci(node, k):
    return [i for i in node.inputs if i.type == "RGBA"][k]


def _co(node):
    return [o for o in node.outputs if o.type == "RGBA"][0]


def hex_srgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def material(key):
    name = "MI_MooredBoat_" + key
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
        gvec = coord
        if spec.get("grain"):
            mp = N("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = (5.0, 0.30, 5.0)
            L(coord, mp.inputs["Vector"])
            gvec = mp.outputs[0]
        else:
            mp = N("ShaderNodeMapping")
            mp.inputs["Scale"].default_value = (9.0, 9.0, 0.35)
            L(coord, mp.inputs["Vector"])
            gvec = mp.outputs[0]
        g = N("ShaderNodeTexNoise")
        g.inputs["Scale"].default_value = 1.2 if spec.get("grain") else 1.8
        g.inputs["Detail"].default_value = 7.0
        g.inputs["Roughness"].default_value = 0.6
        L(gvec, g.inputs["Vector"])
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


# ------------------------------------------------------------------ spec
def make_spec(parts, col, atts, hps=()):
    vis = list(parts.values())
    lo, hi = W.bbox(vis)
    dims = tuple((hi[i] - lo[i]) / S for i in range(3))
    for o in vis + [col]:
        K.fix_uv(o)
    print("[boat] bbox studs %.3f x %.3f x %.3f  m %.3f x %.3f x %.3f" % (tuple(hi - lo) + dims))
    print("[boat] tris %s total %d" % ({k: C.tri_count(o) for k, o in parts.items()}, sum(C.tri_count(o) for o in vis)))
    meshes = [{"object": o, "set": "Atlas"} for o in vis] + [{"object": col}]
    meshes += [{"object": o, "role": "hp"} for o in hps]
    slots = {("MI_MooredBoat_" + k): {"base_color": COLORS[k], "metal": SLOT[k][0], "roughness": SLOT[k][1]}
             for k in COLORS}
    return {
        "name": NAME, "asset": NAME, "budget": BUDGET, "tris": BUDGET_TRIS, "tier": "standard",
        "dims_m": dims, "size_note": "punt includes the tilted outboard aft", "origin": "free",
        "sets": [{"name": "FishingBoat", "set": "Atlas", "size": 2048, "wet": True, "slots": slots,
                  "wear": {"edge": 0.72, "edge_range": (0.11, 0.44), "edge_color": (0.60, 0.56, 0.48),
                           "edge_rough": 0.62, "salt": 0.20, "salt_range": (0.34, 0.78),
                           "salt_color": (0.73, 0.71, 0.64), "rust": 0.07, "rust_color": (0.40, 0.29, 0.21),
                           "rust_rough": 0.86, "rust_length": 0.30, "rust_fingers": 7, "ao_strength": 0.26}}],
        "atlas": "FishingBoat", "meshes": meshes, "attachments": atts, "bake_size": 2048,
        "tiling": True,
        "closeups": [
            {"name": "bow", "target": [0.0, -4.0, 1.0], "dist": 5.2, "az": 36, "el": 14},
            {"name": "stern", "target": [0.9, 5.6, 1.7], "dist": 5.4, "az": 152, "el": 16},
            {"name": "bilge", "target": [0.0, 1.2, 0.1], "dist": 5.0, "az": 28, "el": 38},
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
    return made


if not getattr(versions, "_mooredboat_clean", False):
    versions.run_lod = _run_lod_clean
    versions.decimate = _decimate_tolerant
    versions._mooredboat_clean = True


def patch_bake():
    import numpy as np
    import bake
    if getattr(bake, "_mooredboat_flat_nor", False):
        return
    orig = bake.finish_maps

    def flat_nor(baked, covered, size, set_spec):
        maps, masks = orig(baked, covered, size, set_spec)
        maps[("NOR", False)] = np.full((size, size, 3), (0.5, 0.5, 1.0), dtype=np.float32)
        return maps, masks

    bake.finish_maps = flat_nor
    bake._mooredboat_flat_nor = True


def build():
    patch_bake()
    C.clear_scene()
    parts_buf = {}
    parts_buf.update(build_hull())
    parts_buf["Joinery"] = build_joinery()
    parts_buf["BilgeWood"] = build_bilge_wood()
    parts_buf["Oars"] = build_oars()
    parts_buf["Fittings"] = build_fittings()
    cowl, gear, band, mount = outboard_parts()
    for bb in (cowl, gear, band):
        place_motor(bb, V(0.30, 1.875, 0.585))
    parts_buf["Motor"] = cowl
    parts_buf["MotorGear"] = gear
    parts_buf["MotorBand"] = band
    parts_buf["MotorMount"] = mount
    parts_buf["Painter"] = build_rope()
    parts_buf["BilgeWater"] = build_bilge_water()
    parts_buf["Bailer"] = build_bailer()
    parts_buf["Weed"] = build_weed()
    parts_buf["Letters"] = build_letters()

    mat_of = {"HullAntifoul": "Antifoul", "HullTopsides": "Blue", "HullSheer": "Sheer", "Inner": "Inner",
              "Joinery": "Varnish", "BilgeWood": "Wood", "Oars": "Varnish", "Fittings": "Metal",
              "Motor": "Motor", "MotorGear": "Dark", "MotorBand": "Antifoul", "MotorMount": "Metal",
              "Painter": "Rope",
              "BilgeWater": "Water",
              "Bailer": "Bailer", "Weed": "Weed", "Letters": "White"}
    parts = {}
    for k, buf in parts_buf.items():
        parts[k] = buf.to_object("M_Veh_MooredBoat_%s_01_LOD0" % k, material(mat_of[k]).name)
    K.finish(NAME, parts, recalc=("Fittings", "MotorGear", "Bailer"))
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
            W.empty("ATT_Moor_Bow", (0, -1.925, 0.415), look=(0, -1, 0)),
            W.empty("ATT_Moor_Stern", (0, 1.88, 0.50), look=(0, 1, 0)),
            W.empty("ATT_Outboard", (0.30, 1.88, 0.60), look=(0, 1, 0)),
            W.empty("ATT_Boarding_Port", (0.72, 0.1, 0.30), look=(1, 0, 0)),
            W.empty("ATT_Boarding_Stbd", (-0.72, 0.1, 0.30), look=(-1, 0, 0))]
    I = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    col = W.col_boxes([((0, 0, 0.18), I, (0.76, 1.87, 0.40)),
                       ((0.30, 1.95, 0.58), I, (0.22, 0.48, 0.10))], "M_Veh_MooredBoat_Hull_01_COL")
    return make_spec(parts, col, atts, hps)
