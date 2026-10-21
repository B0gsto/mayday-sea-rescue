"""M_Road_ParkedCar_03 geometry: invented 2010s European small panel van (tradesman / delivery).

Model frame (studs, before recentre): X across (+X kerb side), Y length (front plate at 0.284, rear bumper 13.50),
Z up. 4.41 m x 1.80 m x 1.85 m at 3 studs/m. Short sloped bonnet, steep windscreen, tall boxy load area,
windowless load sides, sliding side door with track and handle, twin rear barn doors, tall vertical tail lamps,
black plastic bumpers / mirrors / rubbing strips, steel wheels with plastic hub caps. Body panels, glass, trim,
lamps, plates and livery are the Body set; wheels and underbody are the Wheels set. The same functions build LOD0
(lo) and _HP (hi, finer segments and bake-only details).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix

import cargeo as V

V.PALETTE["PaintVanWhite"] = ("#E9E8E2", 0.40, 0.0)
V.PROC["PaintVanWhite"] = dict(mottle=(2.2, 0.010), grime=("#7F7B72", 0.21), grime_z=(0.42, 3.05),
                               streak=("#A5A299", 0.14), salt=("#C9C6BC", 0.14), scuff=("#D6D5CF", 0.16),
                               rough_var=0.04, bump=("peel", 0.015, 10))
V.PALETTE.update({
    "PillarBlack": ("#121517", 0.20, 0.0),
    "TrimBlack": ("#1A1D1F", 0.46, 0.0),
    "SeamDark": ("#0A0B0C", 0.70, 0.0),
    "LensDark": ("#161A1F", 0.05, 0.0),
    "DRLWhite": ("#ECF0F2", 0.06, 0.0),
    "TailRed": ("#7C0A11", 0.09, 0.0),
    "TailClear": ("#C7CBC9", 0.07, 0.0),
    "TailAmber": ("#B4640E", 0.10, 0.0),
    "LiveryBlue": ("#1D4E79", 0.40, 0.0),
    "HubCap": ("#8E9194", 0.52, 0.0),
    "SteelWheel": ("#6E7275", 0.46, 0.55),
})
V.PROC.update({
    "PillarBlack": dict(mottle=(4.0, 0.03), grime=("#1E2123", 0.14), rough_var=0.04, bump=("grain", 0.04, 30)),
    "TrimBlack": dict(mottle=(3.5, 0.05), grime=("#1E2022", 0.22), salt=("#8E8C86", 0.10),
                      rough_var=0.06, bump=("grain", 0.09, 28)),
    "LiveryBlue": dict(mottle=(3.0, 0.02), grime=("#2E3A44", 0.09), rough_var=0.03),
    "HubCap": dict(mottle=(3.5, 0.03), grime=("#6E7174", 0.20), salt=("#B8B4AA", 0.12),
                   rough_var=0.06, bump=("grain", 0.05, 30)),
    "SteelWheel": dict(mottle=(3.0, 0.05), grime=("#3A3C3E", 0.24), salt=("#A8A49C", 0.14),
                       rough_var=0.08, bump=("grain", 0.06, 26)),
    "TailRed": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "TailClear": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "TailAmber": dict(mottle=(4.0, 0.02), rough_var=0.03),
    "DRLWhite": dict(mottle=(4.0, 0.02), rough_var=0.02),
})

STUDS_M = 3.0
L = 13.21
HX = 2.70
BELT = 3.45
ROOF = 5.54
HX_CAB = 2.645
Z_BOT = 0.52
AX_F = 2.90
AX_R = 10.90
HUB_X = 2.16
WHEEL_R = 0.95
WHEEL_W = 0.66
ARCH_R = 1.10
DOOR_F0, DOOR_F1 = 4.55, 7.05
SLIDE0, SLIDE1 = 7.25, 9.55
CAB_END = 7.15


def M(g, name, lo="X"):
    return name if g.hi else lo


def P(x, y, z):
    return Vector((x, y, z))


def sstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def curve(pts, y):
    return V.spline(pts, y)


DECK = [(0.40, 2.58), (0.48, 2.74), (0.62, 2.88), (0.85, 2.98), (1.15, 3.06),
        (1.55, 3.14), (2.00, 3.22), (2.50, 3.30), (3.00, 3.37), (3.35, 3.41), (3.55, 3.43)]
CANOPY = [(3.50, 3.47), (3.60, 3.60), (3.75, 3.82), (3.92, 4.06), (4.10, 4.33),
          (4.30, 4.62), (4.50, 4.90), (4.70, 5.16), (4.90, 5.34), (5.10, 5.46),
          (5.35, 5.52), (5.65, 5.54), (6.00, 5.54), (6.30, 5.54), (6.60, 5.54),
          (6.85, 5.54), (7.00, 5.54), (CAB_END, 5.535)]


def belt(y):
    return BELT


def deck_z(y):
    if y <= 3.55:
        return curve(DECK, y)
    return BELT


def plan_hw(y):
    if y < 1.00:
        w = 2.36 + 0.34 * sstep(0.40, 1.00, y) ** 0.72
    elif y > 12.90:
        w = HX - 0.03 * sstep(12.90, 13.32, y)
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


def roof_z(y):
    return ROOF - 0.01 * sstep(12.8, 13.30, y)


def canopy_top(y):
    return curve(CANOPY, y)


def body_stations():
    ys = [0.40, 0.55, 0.72, 0.95, 1.25, 1.60, 2.00, 2.45, 2.90, 3.35, 3.65, 4.05,
          4.55, 5.10, 5.75, 6.40, 7.05, 7.70, 8.40, 9.10, 9.55, 10.10, 10.70, 11.30,
          11.90, 12.40, 12.80, 13.05, 13.30]
    for hy in (AX_F, AX_R):
        for k in range(9):
            ys.append(hy - 1.18 + 2.36 * k / 8)
    return sorted(set(round(v, 3) for v in ys if 0.38 <= v <= 13.31))


def body_ring(y):
    hw = plan_hw(y)
    zb = arch_z(y)
    top = deck_z(y)
    u = min(BELT, top)
    d = u - zb
    right = [
        P(0.0, y, Z_BOT),
        P(1.62, y, Z_BOT),     # arch tunnel: inner wall, roof at zb, outer lip (WheelWell)
        P(1.68, y, max(zb, Z_BOT)),
        P(hw - 0.19, y, max(zb, Z_BOT)),
        P(hw - 0.045, y, zb + 0.20 * d),
        P(hw + 0.015, y, zb + 0.40 * d),
        P(hw + 0.015, y, zb + 0.62 * d),
        P(hw - 0.020, y, zb + 0.82 * d),
        P(hw - 0.075, y, u - 0.050),
        P(hw - 0.055, y, u - 0.005),
        P(hw - 0.160, y, u),
        P(hw - 0.460, y, top),
        P(0.85, y, top + 0.033),
        P(0.0, y, top + 0.042),
    ]
    return right + [P(-p.x, p.y, p.z) for p in reversed(right[1:-1])]


def body_shell(g):
    n = len(body_ring(0.0))
    well = (1, 2, n - 3, n - 2)     # ring segments: tunnel wall and roof, both sides
    V.smooth_loft(g, body_ring, body_stations(), M(g, "PaintVanWhite"), cap0=True, cap1=True,
                  matfn=lambda i, j: M(g, "WheelWell" if j in well else "PaintVanWhite"))


_SNAP = {}


def snap(g):
    """Shell, cab canopy and load box exactly as built for this LOD, for flush lamps, grille, seams and livery."""
    if g.hi not in _SNAP:
        _SNAP[g.hi] = V.Snap([(V.refine_rings(body_ring, body_stations(), True, g.hi)[0], True),
                              (V.refine_rings(canopy_ring, CANOPY_YS, False, g.hi)[0], False),
                              (V.refine_rings(load_ring, LOAD_YS, False, g.hi)[0], False)], (0, L / 2, 2.8))
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
            V.sweep(g, pts, prof, M(g, "PaintVanWhite"), closed=True, cap0=True, cap1=True)


CANOPY_YS = [3.50, 3.60, 3.75, 3.92, 4.10, 4.30, 4.50, 4.70, 4.90, 5.10, 5.35,
             5.65, 6.00, 6.30, 6.60, 6.85, 7.00, CAB_END]
SIDE_BANDS = {0, 1, 2, 3, 8, 9, 10, 11}


def canopy_base(y):
    return BELT


def canopy_ring(y, base=None, hi_ratio=False):
    b = base if base is not None else canopy_base(y)
    r = max(canopy_top(y), b + 0.015)
    wb = plan_hw(y) - 0.055
    wr = wb - 0.22
    d = r - b
    right = [
        P(wb, y, b),
        P(wb + 0.004, y, b + 0.20 * d),
        P(wb - 0.004, y, b + 0.80 * d),
        P(wb - 0.035, y, r - 0.10),
        P(wr + 0.040, y, r - 0.015),
        P(wr - 0.280, y, r + 0.012),
        P(0.0, y, r + 0.018),
    ]
    return right + [P(-p.x, p.y, p.z) for p in reversed(right[:-1])]


def canopy_mat(i, j):
    ym = 0.5 * (CANOPY_YS[i] + CANOPY_YS[i + 1])
    if ym < 5.05:
        return "PillarBlack" if j in SIDE_BANDS else "Glass"
    if 5.05 <= ym < 7.00:
        if j in (1, 10):
            return "Glass"
        if j in SIDE_BANDS:
            return "PaintVanWhite"
        return "PaintVanWhite"
    return "PillarBlack" if j in SIDE_BANDS else "PaintVanWhite"


def canopy(g):
    V.smooth_loft(g, canopy_ring, CANOPY_YS, M(g, "PaintVanWhite"), closed=False,
                  matfn=lambda i, j: M(g, canopy_mat(i, j)))


LOAD_YS = [CAB_END, 7.35, 7.75, 8.25, 8.80, 9.35, 9.90, 10.45, 11.00, 11.55,
           12.05, 12.45, 12.80, 13.05, 13.30]


def load_ring(y):
    b = BELT
    r = roof_z(y)
    wb = plan_hw(y) - 0.055
    wr = wb - 0.22
    d = r - b
    right = [
        P(wb, y, b),
        P(wb + 0.004, y, b + 0.45 * d),
        P(wb + 0.002, y, r - 0.55),
        P(wb - 0.035, y, r - 0.10),
        P(wr + 0.040, y, r - 0.015),
        P(wr - 0.280, y, r + 0.012),
        P(0.0, y, r + 0.018),
    ]
    return right + [P(-p.x, p.y, p.z) for p in reversed(right[:-1])]


def load_box(g):
    V.smooth_loft(g, load_ring, LOAD_YS, M(g, "PaintVanWhite"), closed=False)


def side_x(ring, z):
    pts = ring[:7]
    for a, b in zip(pts, pts[1:]):
        if (a.z - z) * (b.z - z) <= 0 and abs(b.z - a.z) > 1e-6:
            t = (z - a.z) / (b.z - a.z)
            return a.x + (b.x - a.x) * t
    return min(pts, key=lambda p: abs(p.z - z)).x


def body(g):
    body_shell(g)
    wheel_arches(g)
    canopy(g)
    load_box(g)
    b_pillar(g)
    roof_details(g)
    seams(g)


def b_pillar(g):
    ring = load_ring(CAB_END)
    for side in (1, -1):
        zs = (BELT + 0.01, 4.05, 4.70, 5.20, 5.34)
        pts = [P(side * (side_x(ring, z) + 0.008), CAB_END, z) for z in zs]
        V.sweep(g, pts, [(0.012, 0.105), (0.012, -0.105), (-0.008, -0.105), (-0.008, 0.105)],
                M(g, "PillarBlack"), closed=True, cap0=True, cap1=True)


def roof_details(g):
    for side in (1, -1):
        V.box(g, (side * 2.472, 9.30, ROOF - 0.012), (0.045, 8.1, 0.05), M(g, "TrimBlack"), bev=0.012)
    V.box(g, (0, CAB_END, ROOF + 0.017), (4.55, 0.14, 0.028), M(g, "TrimBlack"), bev=0.008)
    # roof ribs in the load area
    for y in (8.35, 10.60, 12.35):
        V.box(g, (0, y, ROOF + 0.026), (4.20, 0.075, 0.024), M(g, "PaintVanWhite"), bev=0.008)


def _side_x(y, z):
    pts = body_ring(y)[3:11]     # from the arch lip (0..2: floor, arch tunnel wall)
    for a, b in zip(pts, pts[1:]):
        if (a.z - z) * (b.z - z) <= 0 and abs(b.z - a.z) > 1e-6:
            t = (z - a.z) / (b.z - a.z)
            return a.x + (b.x - a.x) * t
    return min(pts, key=lambda p: abs(p.z - z)).x


def _top_z(y, x):
    pts = body_ring(y)[10:14]
    ax = abs(x)
    for a, b in zip(pts, pts[1:]):
        if (a.x - ax) * (b.x - ax) <= 0 and abs(b.x - a.x) > 1e-6:
            t = (ax - a.x) / (b.x - a.x)
            return a.z + (b.z - a.z) * t
    return pts[0].z


def _on(g, pts, off=0.002):
    return [snap(g).at(p, -off)[0] for p in pts]


def _seam_side(g, y, side, z0, z1, n=8):
    pts = _on(g, [P(side * _side_x(y, z0 + (z1 - z0) * k / (n - 1)), y,
                    z0 + (z1 - z0) * k / (n - 1)) for k in range(n)])
    V.sweep(g, pts, [(0.004, 0.009), (0.004, -0.009), (-0.002, -0.009), (-0.002, 0.009)],
            "SeamDark", closed=True, cap0=True, cap1=True)


def _seam_hood(g, x, y0, y1, n=14):
    pts = _on(g, [P(x, y0 + (y1 - y0) * k / (n - 1),
                    _top_z(y0 + (y1 - y0) * k / (n - 1), x)) for k in range(n)])
    V.sweep(g, pts, [(0.009, 0.004), (0.009, -0.002), (-0.009, -0.002), (-0.009, 0.004)],
            "SeamDark", closed=True, cap0=True, cap1=True)


def seams(g):
    if not g.hi:
        return
    for side in (1, -1):
        for y in (DOOR_F0, DOOR_F1, SLIDE0, SLIDE1):
            _seam_side(g, y, side, max(1.05, arch_z(y) + 0.08), BELT - 0.045)
        _seam_hood(g, side * 1.34, 0.78, 3.42)


def glass(g):
    # sliding door upper track and roller, and the cab window sill seal
    for side in (1, -1):
        V.box(g, (side * 2.664, 8.38, 3.235), (0.030, 2.62, 0.055), M(g, "TrimBlack"), bev=0.010)
        V.box(g, (side * 2.652, 7.10, 3.235), (0.052, 0.16, 0.075), M(g, "TrimBlack"), bev=0.012)
        lpts = [P(side * (_side_x(7.00 + 2.60 * k / 8, 1.010) + 0.010), 7.00 + 2.60 * k / 8, 1.010)
                for k in range(9)]
        V.sweep(g, lpts, [(0.014, 0.024), (0.014, -0.024), (-0.006, -0.024), (-0.006, 0.024)],
                M(g, "TrimBlack"), closed=True, cap0=True, cap1=True)
        pts = []
        for k in range(9):
            y = 5.05 + (6.98 - 5.05) * k / 8
            pts.append(P(side * (plan_hw(y) - 0.048), y, 3.868))
        V.sweep(g, pts, [(0.014, 0.008), (0.014, -0.008), (-0.010, -0.008), (-0.010, 0.008)],
                M(g, "TrimBlack"), closed=True, cap0=True, cap1=True)
    # wipers on the steep screen
    for sx in (-0.82, 0.82):
        V.box(g, (sx, 3.73, 3.80), (1.02, 0.075, 0.030), M(g, "TrimBlack"),
              rot=Matrix.Rotation(math.radians(49), 3, "X"), bev=0.008)
    V.box(g, (0, 3.63, 3.62), (3.05, 0.05, 0.034), M(g, "TrimBlack"), bev=0.006)


# --------------------------------------------------------------------------- interior
def interior(g):
    V.box(g, (0, 5.90, 0.98), (4.52, 3.55, 0.10), M(g, "Carpet"), bev=0.02)
    V.box(g, (0, 4.52, 2.55), (4.42, 0.52, 0.80), M(g, "InteriorDark"), bev=0.07)
    V.box(g, (0, 4.62, 2.98), (4.24, 0.48, 0.10), M(g, "InteriorMid"), bev=0.03)
    V.box(g, (0, 6.95, 4.55), (4.36, 3.60, 0.05), M(g, "Headliner"), bev=0.02)
    V.box(g, (0, CAB_END, 3.20), (4.46, 0.07, 4.40), M(g, "InteriorMid"), bev=0.03)
    # RHD steering wheel
    c = P(-1.24, 5.28, 3.10)
    u = P(0, math.sin(math.radians(-26)), math.cos(math.radians(-26)))
    v = P(1, 0, 0)
    path = [c + u * (0.50 * math.cos(2 * math.pi * k / 20)) + v * (0.50 * math.sin(2 * math.pi * k / 20))
            for k in range(20)] + [c + u * 0.50]
    V.sweep(g, path, V.circle_profile(0.065, 8 if g.hi else 6), M(g, "BlackPlastic"), closed=True)
    V.lathe(g, tuple(c), (0, -math.sin(math.radians(-26)), -math.cos(math.radians(-26))),
            [(0.14, 0.0), (0.14, 0.04), (0.09, 0.07), (0.0, 0.075)], 14 if g.hi else 10, M(g, "InteriorDark"))
    V.box(g, (-1.24, 4.42, 3.24), (0.92, 0.18, 0.34), M(g, "InteriorDark"), bev=0.04)
    V.box(g, (-1.24, 4.31, 3.28), (0.64, 0.03, 0.20), M(g, "Screen"), bev=0.02)
    V.box(g, (0.10, 5.45, 2.52), (0.66, 0.28, 0.40), M(g, "InteriorDark"), bev=0.03)
    # front seats
    for sx in (-1, 1):
        x = sx * 1.14
        V.box(g, (x, 6.42, 1.62), (0.94, 0.90, 0.26), M(g, "InteriorDark"), bev=0.04)
        V.box(g, (x, 6.44, 1.87), (0.96, 0.95, 0.22), M(g, "SeatFabric"), bev=0.08)
        V.box(g, (x, 6.78, 2.59), (0.96, 0.20, 1.22), M(g, "SeatFabric"),
              rot=Matrix.Rotation(math.radians(-13), 3, "X"), bev=0.09)
        V.box(g, (x, 6.92, 3.24), (0.56, 0.18, 0.28), M(g, "SeatFabric"), bev=0.07)
    # door cards
    for side in (1, -1):
        V.box(g, (side * 2.42, 5.82, 2.36), (0.10, 2.40, 1.60), M(g, "InteriorMid"), bev=0.05)


# --------------------------------------------------------------------------- body detail
def _rprofile(ht, hh, n=10, p=3.2, off=0.0):
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        c, s = math.cos(a), math.sin(a)
        pts.append((off + ht * math.copysign(abs(c) ** (2 / p), c),
                    hh * math.copysign(abs(s) ** (2 / p), s)))
    return pts


def _band(ht, hh, up=0.0, n=8, p=3.2, off=0.0):
    return [(x, y + up) for x, y in _rprofile(ht, hh, n, p, off)]


def _head_inner(g, st, depth):
    V.strip_cup(g, st, 0.20, 0.42, 0.12, depth, "Chrome")
    p, n = st.at(0.20, 0.42, depth - 0.006)
    V.lathe(g, tuple(p), tuple(n), [(0.06, 0.0), (0.06, 0.014), (0.036, 0.026), (0.0, 0.03)], 12, "LensDark")
    V.strip_cup(g, st, 0.50, 0.42, 0.14, depth, "Chrome")
    V.strip_patch(g, st, 0.68, 0.84, 0.15, 0.70, depth - 0.012, "Chrome", nr=2)
    V.strip_patch(g, st, 0.86, 0.97, 0.20, 0.70, depth - 0.02, "LensAmber", nr=2)
    V.strip_patch(g, st, 0.04, 0.84, 0.80, 0.90, 0.008, "DRLWhite", nr=1)


def lamps(g):
    sn = snap(g)
    # headlamps: lens flush with the cab nose, wrapping round the corner; reflectors / projector / DRL baked from _HP
    path = [(0.84, 0.40, 2.44, 2.02), (1.30, 0.40, 2.45, 2.00), (1.80, 0.40, 2.46, 2.02), (2.15, 0.43, 2.46, 2.08),
            (2.42, 0.53, 2.46, 2.14), (2.60, 0.72, 2.46, 2.22)]
    for side in (1, -1):
        tops = [P(side * x, y, zt) for x, y, zt, zb in path]
        bots = [P(side * x, y, zb) for x, y, zt, zb in path]
        V.flush_lamp(g, V.Strip(sn, tops, bots, 22, toward=(0.0, 2.4)), "LensWhite", _head_inner)
    # tall flush vertical tail lamps in the rear corners
    for sx in (-1, 1):
        V.box(g, (sx * 2.56, 13.345, 2.72), (0.30, 0.085, 2.44), M(g, "TrimBlack"), bev=0.035)
        V.box(g, (sx * 2.56, 13.394, 2.90), (0.23, 0.014, 1.36), M(g, "TailRed"), bev=0.012)
        V.box(g, (sx * 2.56, 13.394, 3.74), (0.23, 0.012, 0.30), M(g, "TailClear"), bev=0.008)
        V.box(g, (sx * 2.56, 13.394, 1.55), (0.23, 0.012, 0.16), M(g, "TailAmber"), bev=0.006)
        V.box(g, (sx * 2.56, 13.394, 2.10), (0.23, 0.012, 0.32), M(g, "TailRed"), bev=0.010)
        V.box(g, (sx * 2.56, 13.400, 2.34), (0.17, 0.006, 0.020), M(g, "TailClear"), bev=0.0)


def bumpers(g):
    front = []
    for k in range(15):
        x = -2.50 + 5.00 * k / 14
        front.append(P(x, 0.42 + 0.45 * (abs(x) / 2.50) ** 3.0, 0.92))
    V.sweep(g, front, _rprofile(0.130, 0.44, 12, 3.6), M(g, "TrimBlack"), closed=True,
            cap0=True, cap1=True)
    V.box(g, (0, 0.298, 0.56), (3.30, 0.055, 0.10), M(g, "BlackPlastic"), bev=0.025)
    rear = []
    for k in range(15):
        x = -2.46 + 4.92 * k / 14
        rear.append(P(x, 13.37 - 0.34 * (abs(x) / 2.46) ** 3.0, 0.88))
    V.sweep(g, rear, _rprofile(0.130, 0.40, 12, 3.6), M(g, "TrimBlack"), closed=True,
            cap0=True, cap1=True)
    V.box(g, (0, 13.420, 1.295), (3.70, 0.14, 0.06), M(g, "BlackPlastic"), bev=0.018)
    V.tube(g, [(-1.36, 13.28, 0.60), (-1.36, 13.10, 0.60)], 0.078, M(g, "Exhaust"),
           12 if g.hi else 8, caps=True)
    # fog lamps and their chrome rims
    for side in (1, -1):
        V.lathe(g, (side * 1.52, 0.397, 0.96), (0, -1, 0),
                [(0.0, 0.0), (0.105, 0.0), (0.118, 0.014), (0.090, 0.028), (0.0, 0.034)],
                12 if g.hi else 8, M(g, "Chrome"))
        V.lathe(g, (side * 1.52, 0.360, 0.96), (0, -1, 0),
                [(0.0, 0.0), (0.088, 0.0), (0.0, 0.004)], 12 if g.hi else 8, M(g, "LensDark"))


def _grille_inner(g, st, depth):
    for k in range(3):
        r0 = 0.12 + 0.28 * k
        V.strip_patch(g, st, 0.02, 0.98, r0, r0 + 0.10, 0.012, "TrimBlack", nr=1)


def grille(g):
    xs = (-0.76, -0.38, 0.0, 0.38, 0.76)
    st = V.Strip(snap(g), [P(x, 0.40, 2.14) for x in xs], [P(x, 0.40, 1.82) for x in xs], 8)
    V.flush_lamp(g, st, "GrilleDark", _grille_inner, depth=0.06, floor="GrilleDark")
    V.strip_patch(g, st, 0.0, 1.0, -0.14, -0.07, -0.006, M(g, "Chrome"), nr=1)
    V.box(g, (0, 0.350, 1.48), (1.84, 0.055, 0.24), M(g, "GrilleDark"), bev=0.03)
    for k in range(3):
        V.box(g, (0, 0.322, 1.42 + 0.06 * k), (1.72, 0.018, 0.018), M(g, "TrimBlack"), bev=0.0)


def mirrors(g):
    for side in (1, -1):
        V.tube(g, [(side * 2.600, 4.66, 3.86), (side * 2.720, 4.70, 3.96), (side * 2.775, 4.73, 4.02)],
               0.056, M(g, "BlackPlastic"), 10 if g.hi else 8, fillet=0.06)
        V.box(g, (side * 2.795, 4.76, 4.05), (0.16, 0.40, 0.56), M(g, "TrimBlack"), bev=0.06)
        V.box(g, (side * 2.880, 4.965, 4.05), (0.135, 0.012, 0.46), M(g, "Glass"), bev=0.02)
        V.box(g, (side * 2.795, 4.575, 4.05), (0.13, 0.035, 0.50), M(g, "BlackPlastic"), bev=0.02)


def handles(g):
    for side in (1, -1):
        # front door pull
        V.box(g, (side * 2.690, 6.53, 3.02), (0.055, 0.44, 0.10), M(g, "TrimBlack"), bev=0.03)
        V.box(g, (side * 2.716, 6.45, 3.055), (0.012, 0.24, 0.035), M(g, "Chrome"), bev=0.008)
        # sliding door pull
        V.box(g, (side * 2.700, 8.62, 2.80), (0.060, 0.46, 0.11), M(g, "TrimBlack"), bev=0.032)
        V.box(g, (side * 2.728, 8.54, 2.835), (0.012, 0.26, 0.040), M(g, "Chrome"), bev=0.008)
        # rubbing strips, cab + sliding and rear quarter
        V.box(g, (side * 2.729, 6.82, 2.09), (0.036, 5.34, 0.115), M(g, "TrimBlack"), bev=0.028)
        V.box(g, (side * 2.726, 12.74, 2.09), (0.032, 1.12, 0.110), M(g, "TrimBlack"), bev=0.026)
    # fuel filler on the left rear quarter
    V.box(g, (-2.722, 12.55, 1.62), (0.022, 0.40, 0.34), M(g, "SeamDark"), bev=0.01)
    V.box(g, (-2.740, 12.55, 1.62), (0.014, 0.34, 0.28), M(g, "PaintVanWhite"), bev=0.02)


def wipers_clear(g):
    return


def plates_and_text(g):
    V.box(g, (0, 0.305, 1.05), (1.62, 0.035, 0.36), M(g, "PlateWhite"), bev=0.012)
    V.box(g, (-0.95, 13.400, 1.52), (1.62, 0.035, 0.36), M(g, "PlateYellow"), bev=0.012)
    for y, z, xc, ry in ((0.284, 1.05, 0.0, False), (13.421, 1.52, -0.95, True)):
        me = V.text_mesh("GI16 VNX", 0.30, resolution=1)
        if ry:
            def mp(co, xc=xc, z=z, y=y):
                return P(xc - co.x, y, z + co.y)
            fs = g.add_mesh(me, M(g, "PlateLetter"), mp)
            g.orient(fs, lambda c: P(0, 1, 0))
        else:
            def mp(co, xc=xc, z=z, y=y):
                return P(xc + co.x, y, z + co.y)
            fs = g.add_mesh(me, M(g, "PlateLetter"), mp)
            g.orient(fs, lambda c: P(0, -1, 0))
        bpy.data.meshes.remove(me)
    # invented trade livery, both sides
    for side in (1, -1):
        for txt, size, zc in (("GALE ISLE PLUMBING", 0.315, 3.00), ("01872 555 021", 0.165, 2.66)):
            me = V.text_mesh(txt, size, resolution=1)
            def mp(co, side=side, zc=zc):
                y = 11.02 + side * co.x
                z = zc + co.y
                return snap(g).at(P(side * _side_x(y, z), y, z), -0.007)[0]
            fs = g.add_mesh(me, M(g, "LiveryBlue"), mp)
            g.orient(fs, lambda c, side=side: P(side, 0, 0))
            bpy.data.meshes.remove(me)
        y0, y1, n = 9.58, 12.46, 10
        pts = _on(g, [P(side * _side_x(y0 + (y1 - y0) * k / (n - 1), 2.47),
                        y0 + (y1 - y0) * k / (n - 1), 2.47) for k in range(n)], 0.005)
        V.sweep(g, pts, [(0.004, 0.024), (0.004, -0.024), (-0.004, -0.024), (-0.004, 0.024)],
                M(g, "LiveryBlue"), closed=True, cap0=True, cap1=True)
    # barn door hardware
    for side in (1, -1):
        for z in (1.28, 2.90, 4.55):
            V.box(g, (side * 2.360, 13.405, z), (0.20, 0.045, 0.24), M(g, "BlackMetal"), bev=0.02)
            V.box(g, (side * 2.365, 13.429, z), (0.07, 0.020, 0.30), M(g, "Chrome"), bev=0.008)
        V.box(g, (side * 0.30, 13.405, 2.62), (0.24, 0.045, 0.10), M(g, "BlackMetal"), bev=0.02)
        V.box(g, (side * 0.36, 13.429, 2.62), (0.12, 0.016, 0.045), M(g, "Chrome"), bev=0.006)


def rear_doors(g):
    V.box(g, (0, 13.306, 3.20), (4.82, 0.012, 4.46), M(g, "SeamDark"), bev=0.0)
    for sx in (-1, 1):
        V.box(g, (sx * 1.21, 13.350, 3.175), (2.38, 0.070, 4.42), M(g, "PaintVanWhite"), bev=0.02)


def body_detail(g):
    rear_doors(g)
    lamps(g)
    bumpers(g)
    grille(g)
    mirrors(g)
    handles(g)
    plates_and_text(g)


# --------------------------------------------------------------------------- wheels and underbody
def tyre(g, side):
    profile = [(0.610, -0.270), (0.680, -0.315), (0.800, -0.335), (0.890, -0.325), (0.935, -0.282),
               (0.950, -0.195), (0.950, 0.195), (0.935, 0.282), (0.890, 0.325), (0.800, 0.335),
               (0.680, 0.315), (0.610, 0.270)]
    seg = 16 if g.hi else 14
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0), [(r, h * side) for r, h in profile], seg, M(g, "Tyre"))
    n = 9 if g.hi else 0     # sipes are baked from the _HP
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        c = (0.0, 0.938 * math.sin(a), WHEEL_R + 0.938 * math.cos(a))
        V.box(g, c, (0.50, 0.076, 0.026), M(g, "Tyre"), rot=Matrix.Rotation(-a, 3, "X"), bev=0.0)


def rim(g, side):
    seg = 16 if g.hi else 12
    # painted steel rim with a rolled lip
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.605, 0.12 * side), (0.632, 0.18 * side), (0.645, 0.285 * side), (0.628, 0.315 * side),
             (0.598, 0.305 * side)], seg, M(g, "SteelWheel"))
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.0, 0.235 * side), (0.585, 0.235 * side), (0.585, 0.220 * side), (0.0, 0.220 * side)],
            seg, M(g, "RimDark"))
    # full-face plastic hub cap with an outer crease and eight vent slots
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.0, 0.315 * side), (0.300, 0.315 * side), (0.455, 0.325 * side), (0.540, 0.352 * side),
             (0.552, 0.372 * side), (0.520, 0.395 * side), (0.300, 0.410 * side), (0.0, 0.414 * side)],
            seg, M(g, "HubCap"))
    for k in range(6):
        a = math.radians(60 * k + 30)
        V.box(g, (0.400 * side, 0.398 * math.sin(a), WHEEL_R + 0.398 * math.cos(a)),
              (0.016, 0.066, 0.050), M(g, "RimDark"), rot=Matrix.Rotation(-a, 3, "X"), bev=0.0)
    # centre boss (blank, no badge)
    V.lathe(g, (0, 0, WHEEL_R), (side, 0, 0),
            [(0.0, 0.414), (0.105, 0.414), (0.115, 0.430), (0.095, 0.442), (0.0, 0.445)],
            14 if g.hi else 12, M(g, "HubCap"))
    # brake disc and caliper behind the cap
    V.lathe(g, (side * 0.10, 0, WHEEL_R), (side, 0, 0),
            [(0.0, 0.0), (0.52, 0.0), (0.52, 0.035), (0.0, 0.04)], seg, M(g, "BrakeSteel"))
    V.box(g, (side * 0.12, 0.31, WHEEL_R + 0.27), (0.09, 0.35, 0.21), M(g, "BlackMetal"), bev=0.0)
    V.tube(g, [(side * 0.31, 0.10, WHEEL_R + 0.57), (side * 0.31, 0.10, WHEEL_R + 0.62)],
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
    V.box(g, (0, 6.8, 0.54), (3.20, 10.4, 0.08), M(g, "Underseal"), bev=0.02)
    V.box(g, (0, 1.30, 0.54), (3.20, 1.55, 0.10), M(g, "Underseal"), bev=0.03)
    V.box(g, (0, 12.55, 0.56), (3.20, 1.30, 0.10), M(g, "Underseal"), bev=0.03)
    for side in (1, -1):
        V.box(g, (side * 1.38, 6.8, 0.48), (0.12, 9.6, 0.12), M(g, "BlackMetal"), bev=0.02)
    V.tube(g, [(-0.58, 0.95, 0.48), (-0.58, 3.9, 0.48), (-0.36, 7.0, 0.50), (-0.58, 9.6, 0.48),
               (-0.58, 11.6, 0.52), (-1.30, 13.1, 0.58)], 0.076, M(g, "Exhaust"), 8 if g.hi else 6,
           fillet=0.45, fseg=3)
    V.lathe(g, (-0.58, 8.9, 0.48), (0, 1, 0),
            [(0.0, -0.90), (0.12, -0.85), (0.15, -0.58), (0.15, 0.58), (0.12, 0.85), (0.0, 0.90)],
            10 if g.hi else 8, M(g, "Exhaust"))


def collision():
    bm = bmesh.new()
    pts = []
    for y in (0.40, 1.4, 2.9, 4.4, 6.4, 8.4, 10.4, 12.2, 13.3):
        for x in (-2.70, -1.35, 0.0, 1.35, 2.70):
            pts += [(x, y, 0.62), (x, y, 1.5), (x, y, 3.0)]
        pts += [(-2.45, y, 5.30), (0.0, y, 5.54), (2.45, y, 5.30)]
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("M_Road_ParkedCar_03_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("M_Road_ParkedCar_03_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob
