"""M_Road_ParkedCar_02 geometry: invented 2010s European family estate (station wagon).

Model frame (studs, before recentre): X across (+X kerb side), Y length (front bumper at 0.30, rear at 14.16), Z up.
4.62 m x 1.80 m x 1.49 m at 3 studs/m. Long bonnet, long flat roof with rails, near-vertical tailgate, tall
wrap-around tail lamps, three side windows. Body panels, glass, trim and bumpers are one Body set; wheels and
underbody are the Wheels set. The same functions build LOD0 (lo) and _HP (hi, finer segments and bake-only details).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix

import cargeo as V

# deep wine red, clear-coat gloss; metal 0: the bake snaps MET at 0.5 and metal albedo is floored at 180 (cherry)
V.PALETTE["PaintCrimson"] = ("#6E0E14", 0.25, 0.0)
V.PROC["PaintCrimson"] = dict(mottle=(2.2, 0.006), grime=("#39171A", 0.07), grime_z=(0.45, 1.50),
                              rough_var=0.012, bump=("flake", 0.007, 18))
V.PALETTE.update({
    # darks kept at sRGB luma >= 34: the bake shifts every non-metal texel of the set up to its floor of 32 when
    # its 1st percentile sits below, which brightened the paint
    "PillarBlack": ("#202428", 0.12, 0.0),
    "TrimBlack": ("#222528", 0.42, 0.0),
    "SeamDark": ("#202326", 0.68, 0.0),
    "LensDark": ("#202529", 0.05, 0.0),
    "GlassSeal": ("#222528", 0.78, 0.0),
    "DRLWhite": ("#ECF0F2", 0.06, 0.0),
    "TailRed": ("#8A0C14", 0.09, 0.0),
    "TailClear": ("#C7CBC9", 0.07, 0.0),
    "TailAmber": ("#B4640E", 0.10, 0.0),
})

STUDS_M = 3.0
L = 13.86
HX = 2.70
BELT_F = 2.98
BELT_R = 3.22
ROOF = 4.37
ROOF_HX = 2.02
Z_BOT = 0.58
AX_F = 2.62
AX_R = 10.72
HUB_X = 2.18
WHEEL_R = 0.95
WHEEL_W = 0.68
ARCH_R = 1.10
DOOR_F0, DOOR_F1 = 4.95, 7.55
DOOR_R0, DOOR_R1 = 7.80, 9.90


def M(g, name, lo="X"):
    return name if g.hi else lo


def P(x, y, z):
    return Vector((x, y, z))


def sstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def curve(pts, y):
    return V.spline(pts, y)


DECK = [(0.30, 1.96), (0.42, 2.20), (0.62, 2.38), (0.95, 2.52), (1.35, 2.64),
        (1.90, 2.76), (2.55, 2.86), (3.25, 2.94), (3.95, 2.99), (4.45, 3.01)]
HATCH = [(13.55, 3.20), (13.62, 2.98), (13.70, 2.55), (13.77, 2.08), (13.84, 1.62), (13.90, 1.38)]
CANOPY = [(4.42, 3.02), (4.70, 3.26), (5.00, 3.55), (5.30, 3.83), (5.60, 4.08), (5.88, 4.28),
          (6.10, 4.35), (6.30, 4.37), (7.5, 4.38), (9.0, 4.38), (10.5, 4.375), (11.8, 4.36),
          (12.35, 4.33), (12.55, 4.29), (12.75, 4.16), (12.95, 3.93), (13.15, 3.66),
          (13.35, 3.40), (13.55, 3.20)]


def belt(y):
    return BELT_F + (BELT_R - BELT_F) * sstep(3.1, 8.8, y)


def deck_z(y):
    if y <= 4.45:
        return curve(DECK, y)
    if y <= 13.52:
        return belt(y)
    return curve(HATCH, y)


def plan_hw(y):
    if y < 1.45:
        w = 2.22 + 0.46 * sstep(0.30, 1.45, y) ** 0.72
    elif y > 11.6:
        w = HX - 0.10 * sstep(11.6, 13.9, y)
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
    wb = plan_hw(y) - 0.06
    k = sstep(4.42, 5.95, y)
    return (wb - 0.03) * (1 - k) + ROOF_HX * k - 0.10 * sstep(11.7, 13.4, y)


def body_stations():
    ys = [0.30, 0.42, 0.58, 0.78, 1.05, 1.40, 1.80, 2.20, 2.60, 3.05, 3.50, 3.95,
          4.45, 5.15, 5.90, 6.30, 6.90, 7.55, 7.80, 8.55, 9.55, 9.85, 11.75, 12.55, 12.90,
          13.25, 13.55, 13.72, 13.90]
    for hy in (AX_F, AX_R):
        for k in range(9):
            ys.append(hy - 1.20 + 2.40 * k / 8)
    return sorted(set(round(v, 3) for v in ys if 0.28 <= v <= 13.91))


def body_ring(y):
    hw = plan_hw(y)
    zb = arch_z(y)
    top = deck_z(y)
    u = min(belt(y), top)
    d = u - zb
    right = [
        P(0.0, y, Z_BOT),
        P(1.64, y, Z_BOT),     # arch tunnel: inner wall, roof at zb, outer lip (WheelWell)
        P(1.70, y, max(zb, Z_BOT)),
        P(hw - 0.19, y, max(zb, Z_BOT)),
        P(hw - 0.045, y, zb + 0.20 * d),
        P(hw + 0.015, y, zb + 0.38 * d),
        P(hw + 0.015, y, zb + 0.56 * d),
        P(hw - 0.020, y, zb + 0.76 * d),
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
    V.smooth_loft(g, body_ring, body_stations(), M(g, "PaintCrimson"), cap0=True, cap1=True,
                  matfn=lambda i, j: M(g, "WheelWell" if j in well else "PaintCrimson"))


_SNAP = {}


def snap(g):
    """The shell and canopy surface exactly as built for this LOD, for flush lamps, grille and shut lines."""
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
            V.sweep(g, pts, prof, M(g, "PaintCrimson"), closed=True, cap0=True, cap1=True)


CANOPY_YS = [4.42, 4.66, 5.10, 5.50, 5.72, 5.95, 6.30, 6.90, 7.44, 7.92,
             8.40, 9.44, 10.12, 10.45, 11.10, 11.75, 12.35, 12.55, 12.80,
             13.05, 13.30, 13.55]


def canopy_ring(y):
    b = belt(y)
    r = max(canopy_top(y), b + 0.015)
    wb = plan_hw(y) - 0.07
    wr = canopy_wr(y)
    k = min(1.0, max(0.0, (r - b) / 1.45))
    right = [
        P(wb, y, b),
        P(wb - 0.02, y, b + 0.32 * (r - b)),
        P(wb - 0.07 - 0.04 * k, y, b + 0.66 * (r - b)),
        P(wr + 0.035, y, r - 0.11),
        P(wr, y, r - 0.01),
        P(wr - 0.24, y, r + 0.012),
        P(wr * 0.55, y, r + 0.028),
        P(0.0, y, r + 0.032),
    ]
    return right + [P(-p.x, p.y, p.z) for p in reversed(right[:-1])]


def canopy_mat(i, j):
    ym = 0.5 * (CANOPY_YS[i] + CANOPY_YS[i + 1])
    if j in (0, 1, 2, 11, 12, 13):
        if 7.44 <= ym <= 7.92 or 9.44 <= ym <= 10.12:
            return "PillarBlack"
        if 5.72 <= ym <= 9.44 or 10.12 <= ym <= 11.75:
            return "Glass"
        return "PaintCrimson"
    if ym <= 5.88 or ym >= 12.55:
        return "Glass"
    return "PaintCrimson"


def canopy(g):
    V.smooth_loft(g, canopy_ring, CANOPY_YS, M(g, "PaintCrimson"), closed=False,
                  matfn=lambda i, j: M(g, canopy_mat(i, j)))


def body(g):
    body_shell(g)
    wheel_arches(g)
    canopy(g)
    roof_tail(g)
    seams(g)


def roof_tail(g):
    V.box(g, (0, 12.38, 4.335), (3.52, 0.34, 0.085), M(g, "PaintCrimson"),
          rot=Matrix.Rotation(math.radians(-9), 3, "X"), bev=0.03)
    V.box(g, (0, 12.55, 4.245), (3.38, 0.11, 0.055), M(g, "BlackPlastic"), bev=0.012)
    V.box(g, (-0.55, 12.585, 4.20), (0.85, 0.05, 0.045), M(g, "TailRed"), bev=0.008)
    for side in (1, -1):
        V.box(g, (side * 1.58, 9.15, 4.435), (0.12, 6.5, 0.065), M(g, "BlackMetal"), bev=0.018)
        for y in (6.10, 12.15):
            V.box(g, (side * 1.58, y, 4.375), (0.09, 0.36, 0.10), M(g, "BlackMetal"), bev=0.02)


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


def _hatch_y(z):
    pts = [(zz, yy) for yy, zz in HATCH]
    if z >= pts[0][0]:
        return pts[0][1]
    for (z0, y0), (z1, y1) in zip(pts, pts[1:]):
        if z >= z1:
            return y0 + (y1 - y0) * (z0 - z) / (z0 - z1)
    return pts[-1][1]


def _on(g, pts):
    return [snap(g).at(p, -0.002)[0] for p in pts]


def _seam_side(g, y, side, z0, z1, n=8):
    pts = _on(g, [P(side * (_side_x(y, z0 + (z1 - z0) * k / (n - 1)) + 0.002), y,
                    z0 + (z1 - z0) * k / (n - 1)) for k in range(n)])
    V.sweep(g, pts, [(0.004, 0.009), (0.004, -0.009), (-0.002, -0.009), (-0.002, 0.009)],
            "SeamDark", closed=True, cap0=True, cap1=True)


def _seam_hood(g, x, y0, y1, n=14):
    pts = _on(g, [P(x, y0 + (y1 - y0) * k / (n - 1),
                    _top_z(y0 + (y1 - y0) * k / (n - 1), x) + 0.002) for k in range(n)])
    V.sweep(g, pts, [(0.009, 0.004), (0.009, -0.002), (-0.009, -0.002), (-0.009, 0.004)],
            "SeamDark", closed=True, cap0=True, cap1=True)


def _seam_hatch_x(g, z, x0, x1, n=12):
    pts = _on(g, [P(x0 + (x1 - x0) * k / (n - 1), _hatch_y(z) + 0.002, z) for k in range(n)])
    V.sweep(g, pts, [(-0.004, 0.009), (-0.004, -0.009), (0.002, -0.009), (0.002, 0.009)],
            "SeamDark", closed=True, cap0=True, cap1=True)


def _seam_hatch_z(g, x, z0, z1, n=8):
    pts = _on(g, [P(x, _hatch_y(z0 + (z1 - z0) * k / (n - 1)) + 0.002,
                    z0 + (z1 - z0) * k / (n - 1)) for k in range(n)])
    V.sweep(g, pts, [(0.009, 0.002), (0.009, -0.004), (-0.009, -0.004), (-0.009, 0.002)],
            "SeamDark", closed=True, cap0=True, cap1=True)


def seams(g):
    if not g.hi:
        return
    for side in (1, -1):
        for y in (4.95, 7.55, 7.80, 9.90):
            _seam_side(g, y, side, max(1.04, arch_z(y) + 0.08), belt(y) - 0.055)
        _seam_hood(g, side * 1.32, 0.74, 4.34)
        _seam_hatch_z(g, side * 1.42, 1.52, 2.98)
    _seam_hatch_x(g, 1.55, -1.30, 1.30)


def glass(g):
    V.box(g, (0, 4.425, 3.03), (2 * (plan_hw(4.42) - 0.12), 0.10, 0.075), M(g, "GlassSeal"), bev=0.015)
    V.box(g, (-1.05, 12.98, 3.92), (1.24, 0.045, 0.05), M(g, "BlackPlastic"),
          rot=Matrix.Rotation(math.radians(-37), 3, "X"), bev=0.01)
    V.box(g, (1.05, 12.98, 3.90), (0.09, 0.09, 0.16), M(g, "BlackPlastic"), bev=0.02)
    V.box(g, (0.42, 13.36, 3.55), (0.72, 0.035, 0.045), M(g, "BlackPlastic"),
          rot=Matrix.Rotation(math.radians(-37), 3, "X"), bev=0.008)
    V.box(g, (-1.44, 12.86, 3.99), (0.06, 0.06, 0.07), M(g, "BlackPlastic"), bev=0.012)



# --------------------------------------------------------------------------- interior
def interior(g):
    V.box(g, (0, 6.60, 1.10), (3.24, 11.0, 0.10), M(g, "Carpet"), bev=0.02)
    V.box(g, (0, 5.38, 2.40), (4.50, 0.64, 0.86), M(g, "InteriorDark"), bev=0.07)
    V.box(g, (0, 5.60, 2.86), (4.36, 0.46, 0.10), M(g, "InteriorMid"), bev=0.03)
    V.box(g, (0, 8.55, 4.19), (3.42, 7.10, 0.05), M(g, "Headliner"), bev=0.02)
    # RHD steering wheel
    c = P(-1.28, 5.12, 2.62)
    u = P(0, math.sin(math.radians(-24)), math.cos(math.radians(-24)))
    v = P(1, 0, 0)
    path = [c + u * (0.50 * math.cos(2 * math.pi * k / 20)) + v * (0.50 * math.sin(2 * math.pi * k / 20))
            for k in range(20)] + [c + u * 0.50]
    V.sweep(g, path, V.circle_profile(0.065, 8 if g.hi else 6), M(g, "BlackPlastic"), closed=True)
    V.lathe(g, tuple(c), (0, -math.sin(math.radians(-24)), -math.cos(math.radians(-24))),
            [(0.14, 0.0), (0.14, 0.04), (0.09, 0.07), (0.0, 0.075)], 14 if g.hi else 10, M(g, "InteriorDark"))
    V.box(g, (0.10, 5.35, 2.20), (0.72, 0.30, 0.42), M(g, "InteriorDark"), bev=0.03)
    # front seats
    for sx in (-1, 1):
        x = sx * 1.14
        V.box(g, (x, 6.52, 1.62), (0.94, 0.90, 0.26), M(g, "InteriorDark"), bev=0.04)
        V.box(g, (x, 6.54, 1.87), (0.96, 0.95, 0.22), M(g, "SeatFabric"), bev=0.08)
        V.box(g, (x, 6.86, 2.55), (0.96, 0.20, 1.18), M(g, "SeatFabric"),
              rot=Matrix.Rotation(math.radians(-14), 3, "X"), bev=0.09)
        V.box(g, (x, 6.98, 3.18), (0.56, 0.18, 0.28), M(g, "SeatFabric"), bev=0.07)
    # rear bench with two headrests, cargo bay and parcel shelf
    V.box(g, (0, 9.55, 1.76), (3.58, 0.94, 0.24), M(g, "SeatFabric"), bev=0.08)
    V.box(g, (0, 9.88, 2.42), (3.58, 0.18, 1.02), M(g, "SeatFabric"),
          rot=Matrix.Rotation(math.radians(-14), 3, "X"), bev=0.08)
    V.box(g, (0, 11.95, 1.24), (4.10, 3.25, 0.10), M(g, "Carpet"), bev=0.02)
    # centre console
    V.box(g, (0.18, 5.55, 1.58), (0.28, 1.5, 0.48), M(g, "InteriorDark"), bev=0.05)


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
    V.strip_cup(g, st, 0.13, 0.48, 0.105, depth, "Chrome")
    V.strip_cup(g, st, 0.36, 0.46, 0.125, depth, "Chrome")
    for s0, rad in ((0.13, 0.05), (0.36, 0.062)):          # projector lenses in the cups
        p, n = st.at(s0, 0.47, depth - 0.006)
        V.lathe(g, tuple(p), tuple(n), [(rad, 0.0), (rad, 0.014), (rad * 0.6, 0.026), (0.0, 0.03)], 12, "LensDark")
    V.strip_patch(g, st, 0.50, 0.76, 0.18, 0.74, depth - 0.012, "Chrome", nr=2)
    V.strip_patch(g, st, 0.79, 0.97, 0.22, 0.72, depth - 0.02, "LensAmber", nr=2)
    V.strip_patch(g, st, 0.04, 0.96, 0.80, 0.91, 0.008, "DRLWhite", nr=1)


def _tail_inner(g, st, depth):
    for r0 in (0.14, 0.40):                                  # light-guide bars
        V.strip_patch(g, st, 0.05, 0.95, r0, r0 + 0.09, 0.01, "LensRed", nr=1)
    V.strip_patch(g, st, 0.04, 0.42, 0.66, 0.92, depth - 0.02, "Chrome", nr=1)
    V.strip_patch(g, st, 0.46, 0.64, 0.66, 0.92, depth - 0.02, "TailAmber", nr=1)


def lamps(g):
    sn = snap(g)
    # headlamps: lens flush with the nose, wrapping round the wing; projector + reflector + DRL under it (_HP bake)
    path = [(0.80, 0.30, 1.80, 0.86), (1.16, 0.30, 1.81, 1.0), (1.58, 0.34, 1.83, 1.0), (1.98, 0.44, 1.86, 0.95),
            (2.30, 0.64, 1.90, 0.80), (2.55, 0.93, 1.93, 0.60), (2.67, 1.23, 1.95, 0.40)]
    for side in (1, -1):
        tops = [P(side * x, y, z + 0.17 * r) for x, y, z, r in path]
        bots = [P(side * x, y, z - 0.15 * r) for x, y, z, r in path]
        V.flush_lamp(g, V.Strip(sn, tops, bots, 26, toward=(0.0, 2.2)), "LensWhite", _head_inner)
    # tail lamps: one flush lens wrapping the tailgate corner onto the quarter, one up the D-pillar
    for sx in (-1, 1):
        tops = [P(sx * x, y, z) for x, y, z in ((1.50, 13.60, 3.10), (1.90, 13.59, 3.10), (2.20, 13.56, 3.10),
                                               (2.45, 13.44, 3.09), (2.60, 13.24, 3.07), (2.64, 12.98, 3.05))]
        bots = [P(sx * x, y, z) for x, y, z in ((1.50, 13.74, 2.30), (1.90, 13.74, 2.30), (2.20, 13.71, 2.34),
                                               (2.45, 13.60, 2.45), (2.60, 13.38, 2.62), (2.64, 13.12, 2.80))]
        V.flush_lamp(g, V.Strip(sn, tops, bots, 20, toward=(0.0, 11.6)), "LensRed", _tail_inner, floor="TailRed")
        tops = [P(sx * 2.56, 12.30, 3.74), P(sx * 2.55, 12.90, 3.66), P(sx * 2.48, 13.38, 3.50)]
        bots = [P(sx * 2.62, 12.30, 3.34), P(sx * 2.62, 12.90, 3.32), P(sx * 2.58, 13.38, 3.30)]
        V.flush_lamp(g, V.Strip(sn, tops, bots, 12, toward=(0.0, 12.8)), "LensRed",
                     lambda g, st, d: V.strip_patch(g, st, 0.05, 0.95, 0.30, 0.42, 0.01, "LensRed", nr=1),
                     floor="TailRed")


def bumpers(g):
    front = []
    for k in range(15):
        x = -2.52 + 5.04 * k / 14
        front.append(P(x, 0.43 + 1.02 * (abs(x) / 2.52) ** 2.4, 1.08))
    V.sweep(g, front, _rprofile(0.130, 0.52, 12, 3.6), M(g, "PaintCrimson"), closed=True,
            cap0=True, cap1=True)
    V.box(g, (0, 0.245, 0.62), (3.62, 0.12, 0.12), M(g, "BlackPlastic"), bev=0.03)
    V.box(g, (0, 0.300, 1.32), (2.70, 0.06, 0.32), M(g, "GrilleDark"), bev=0.03)
    for k in range(2):
        V.box(g, (0, 0.263, 1.26 + 0.09 * k), (2.52, 0.02, 0.022), M(g, "BlackPlastic"), bev=0.0)
    rear = []
    for k in range(15):
        x = -2.42 + 4.84 * k / 14
        rear.append(P(x, 14.02 - 0.14 * (abs(x) / 2.42) ** 2.0, 1.02))
    V.sweep(g, rear, _rprofile(0.130, 0.42, 12, 3.6), M(g, "PaintCrimson"), closed=True,
            cap0=True, cap1=True)
    V.box(g, (0, 14.02, 0.60), (3.62, 0.12, 0.12), M(g, "BlackPlastic"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 0.78, 14.155, 0.82), (0.56, 0.03, 0.07), M(g, "TailRed"), bev=0.01)
    V.tube(g, [(-1.48, 13.94, 0.64), (-1.48, 13.72, 0.64)], 0.075, M(g, "Exhaust"),
           12 if g.hi else 8, caps=True)


def _grille_inner(g, st, depth):
    for k in range(4):
        r0 = 0.10 + 0.22 * k
        V.strip_patch(g, st, 0.02, 0.98, r0, r0 + 0.08, 0.012, "BlackPlastic", nr=1)


def grille(g):
    sn = snap(g)
    xs = (-0.80, -0.40, 0.0, 0.40, 0.80)
    st = V.Strip(sn, [P(x, 0.30, 1.93) for x in xs], [P(x, 0.30, 1.67) for x in xs], 8)
    V.flush_lamp(g, st, "GrilleDark", _grille_inner, depth=0.06, floor="GrilleDark")
    V.strip_patch(g, st, 0.0, 1.0, -0.17, -0.09, -0.006, M(g, "Chrome"), nr=1)


def mirrors(g):
    for side in (1, -1):
        V.tube(g, [(side * 2.52, 5.06, 3.02), (side * 2.71, 4.99, 3.11), (side * 2.80, 4.93, 3.16)],
               0.052, M(g, "BlackPlastic"), 10 if g.hi else 8, fillet=0.08)
        V.box(g, (side * 2.805, 4.88, 3.22), (0.16, 0.36, 0.24), M(g, "BlackPlastic"), bev=0.055)
        V.box(g, (side * 2.875, 4.88, 3.22), (0.03, 0.30, 0.19), M(g, "PaintCrimson"), bev=0.03)
        V.box(g, (side * 2.845, 5.09, 3.22), (0.05, 0.05, 0.18), M(g, "BlackPlastic"), bev=0.01)
        V.box(g, (side * 2.859, 4.88, 3.22), (0.012, 0.23, 0.14), M(g, "Glass"), bev=0.01)


def handles(g):
    for side in (1, -1):
        for y, z in ((6.30, 2.78), (8.95, 2.88)):
            V.box(g, (side * 2.695, y, z), (0.055, 0.46, 0.10), M(g, "BlackPlastic"), bev=0.03)
            V.box(g, (side * 2.718, y - 0.09, z + 0.035), (0.012, 0.26, 0.035),
                  M(g, "Chrome"), bev=0.008)
    V.lathe(g, (-2.68, 12.42, 2.10), (-1, 0, 0),
            [(0.24, 0.0), (0.24, 0.012), (0.19, 0.02), (0.0, 0.02)], 18 if g.hi else 12, M(g, "PaintCrimson"))
    V.lathe(g, (-2.695, 12.42, 2.10), (-1, 0, 0),
            [(0.15, 0.0), (0.15, 0.015), (0.0, 0.02)], 16 if g.hi else 10, M(g, "BlackPlastic"))


def wipers(g):
    for sx in (-1, 1):
        V.box(g, (sx * 0.78, 4.56, 3.08), (1.10, 0.07, 0.05), M(g, "BlackPlastic"),
              rot=Matrix.Rotation(math.radians(11), 3, "X"), bev=0.01)
    V.box(g, (0, 4.53, 3.07), (3.25, 0.05, 0.040), M(g, "BlackPlastic"), bev=0.008)


def plates_and_text(g):
    V.box(g, (0, 0.300, 1.00), (1.68, 0.035, 0.37), M(g, "PlateWhite"), bev=0.012)
    V.box(g, (0, 14.155, 1.00), (1.68, 0.035, 0.37), M(g, "PlateYellow"), bev=0.012)
    me = V.text_mesh("GI18 WNE", 0.31, resolution=1)
    def mp(co):
        return P(co.x, 0.275, 1.00 + co.y)
    fs = g.add_mesh(me, M(g, "PlateLetter"), mp)
    g.orient(fs, lambda c: P(0, -1, 0))
    bpy.data.meshes.remove(me)
    me = V.text_mesh("GI18 WNE", 0.31, resolution=1)
    def mpr(co):
        return P(-co.x, 14.180, 1.00 + co.y)
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
    profile = [(0.615, -0.275), (0.685, -0.322), (0.805, -0.345), (0.89, -0.335), (0.935, -0.290),
               (0.95, -0.200), (0.95, 0.200), (0.935, 0.290), (0.89, 0.335), (0.805, 0.345),
               (0.685, 0.322), (0.615, 0.275)]
    seg = 18 if g.hi else 14
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0), [(r, h * side) for r, h in profile], seg, M(g, "Tyre"))
    # lateral tread sipes
    n = 9 if g.hi else 0     # sipes are baked from the _HP
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        rot = Matrix.Rotation(-a, 3, "X")
        c = (0.0, 0.938 * math.sin(a), WHEEL_R + 0.938 * math.cos(a))
        V.box(g, c, (0.52, 0.078, 0.026), M(g, "Tyre"), rot=rot, bev=0.0)
        c2 = (0.0, 0.944 * math.sin(a + 0.17), WHEEL_R + 0.944 * math.cos(a + 0.17))
        V.box(g, c2, (0.48, 0.052, 0.022), M(g, "Tyre"), rot=Matrix.Rotation(-(a + 0.17), 3, "X"), bev=0.0)


def rim(g, side):
    seg = 18 if g.hi else 14
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.615, 0.13 * side), (0.642, 0.18 * side), (0.652, 0.28 * side), (0.632, 0.315 * side),
             (0.600, 0.310 * side)], seg, M(g, "RimSilver"))
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.0, 0.255 * side), (0.575, 0.255 * side), (0.575, 0.232 * side), (0.0, 0.232 * side)],
            seg, M(g, "RimDark"))
    # seven slim split-alloy spokes with a machined outer lip
    for k in range(7):
        a = math.radians(360 * k / 7)
        c = (side * 0.298, 0.305 * math.sin(a), WHEEL_R + 0.305 * math.cos(a))
        V.box(g, c, (0.068, 0.125, 0.50), M(g, "RimSilver"),
              rot=Matrix.Rotation(-a, 3, "X"), bev=0.018)
    V.lathe(g, (0, 0, WHEEL_R), (1, 0, 0),
            [(0.600, 0.305 * side), (0.622, 0.335 * side), (0.612, 0.285 * side), (0.585, 0.280 * side)],
            seg, M(g, "RimSilver"))
    V.lathe(g, (0, 0, WHEEL_R), (side, 0, 0),
            [(0.0, 0.325), (0.18, 0.325), (0.19, 0.352), (0.155, 0.378), (0.0, 0.383)],
            16 if g.hi else 12, M(g, "RimSilver"))
    for k in range(5):
        a = math.radians(72 * k + 36)
        V.lathe(g, (side * 0.372, 0.125 * math.sin(a), WHEEL_R + 0.125 * math.cos(a)), (side, 0, 0),
                [(0.036, 0.0), (0.036, 0.02), (0.0, 0.025)], 4, M(g, "Chrome"))
    # brake disc and caliper behind the spokes
    V.lathe(g, (side * 0.10, 0, WHEEL_R), (side, 0, 0),
            [(0.0, 0.0), (0.52, 0.0), (0.52, 0.035), (0.0, 0.04)], seg, M(g, "BrakeSteel"))
    V.box(g, (side * 0.12, 0.31, WHEEL_R + 0.27), (0.09, 0.35, 0.21), M(g, "BlackMetal"), bev=0.03)
    # valve stem
    V.tube(g, [(side * 0.31, 0.10, WHEEL_R + 0.57), (side * 0.31, 0.10, WHEEL_R + 0.63)],
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
    V.box(g, (0, 6.8, 0.58), (3.24, 10.2, 0.08), M(g, "Underseal"), bev=0.02)
    V.box(g, (0, 1.35, 0.56), (3.24, 1.50, 0.10), M(g, "Underseal"), bev=0.03)
    V.box(g, (0, 12.35, 0.60), (3.24, 1.60, 0.10), M(g, "Underseal"), bev=0.03)
    for side in (1, -1):
        V.box(g, (side * 1.40, 6.7, 0.50), (0.12, 8.2, 0.12), M(g, "BlackMetal"), bev=0.02)
    V.tube(g, [(-0.58, 0.95, 0.50), (-0.58, 3.9, 0.50), (-0.36, 7.0, 0.52), (-0.58, 9.6, 0.50),
               (-0.58, 11.4, 0.55), (-1.30, 13.5, 0.62)], 0.078, M(g, "Exhaust"), 8 if g.hi else 6,
           fillet=0.45, fseg=3)
    V.lathe(g, (-0.58, 8.9, 0.50), (0, 1, 0),
            [(0.0, -0.95), (0.12, -0.90), (0.15, -0.60), (0.15, 0.60), (0.12, 0.90), (0.0, 0.95)],
            12 if g.hi else 8, M(g, "Exhaust"))


def collision():
    bm = bmesh.new()
    pts = []
    for y in (0.3, 1.3, 2.6, 4.4, 6.4, 8.4, 10.4, 12.0, 13.2, 14.1):
        for x in (-2.70, -1.35, 0.0, 1.35, 2.70):
            pts += [(x, y, 0.62), (x, y, 1.5), (x, y, 2.8)]
        pts += [(-2.45, y, 4.15), (0.0, y, 4.38), (2.45, y, 4.15)]
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("M_Road_ParkedCar_02_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("M_Road_ParkedCar_02_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob
