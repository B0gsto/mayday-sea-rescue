"""Geometry for M_Veh_JetSki and M_Veh_JetSki_CloseUp (batch V1). 1 Blender unit = 1 stud (3 studs per metre).

Axes (pipeline): X beam (port +X, starboard -X), Y length (bow -Y, stern +Y), Z up, keel bottom at z 0. The build
frame is the greybox frame (src/shared/Boat/Builder.luau buildJetSki): Blender (x, y, z) = (-rx, rz, ry + 1.1);
build.py recentres it ("base" origin) and writes frame_offset.json for the close-up set.

Generic three-seat rescue PWC (no maker shapes or marks): deep-V hull 3.37 m with a spray-rail chine, rub rail,
footwells, a long two-tone saddle, steering pod with bars and mirrors, nav lights, all-round white on a short stern
pole, tow eye, bow eye, jet nozzle with reverse bucket, and a rescue sled (board with six handles) on two stainless
arms at the stern. Gale Isles Coastguard livery: muted Hull Orange topsides, charcoal bottom, white lettering on a charcoal
band, fleet number GI-17, the lighthouse-and-compass crest, RESCUE on the sled.
"""
import math

import bmesh
from mathutils import Vector, Matrix

import pwcgeo as R

R.PALETTE.update({
    "PWCOrange": ("#CC5A26", 0.40, 0.0),       # muted Hull Orange gelcoat (not over-saturated, V2 review)
    "PWCOrangeDark": ("#A84A22", 0.48, 0.0),
    "DeckGrey": ("#4E5357", 0.55, 0.0),        # footwell walls, pedestal moulding
    "RubBlack": ("#2F3235", 0.70, 0.0),
    "SeatSide": ("#5C6166", 0.55, 0.0),
    "SeatSeam": ("#202224", 0.70, 0.0),
    "SledOrange": ("#C2552E", 0.55, 0.0),
    "SledHull": ("#3A3F44", 0.62, 0.0),
    "HoseBlack": ("#2B2D2F", 0.65, 0.0),
    "Mirror": ("#D2D6D8", 0.04, 1.0),
    "LCDText": ("#C8D4D6", 0.10, 0.0),
    "LCDAmber": ("#D08A2A", 0.10, 0.0),
    "LanyardRed": ("#9E2E28", 0.45, 0.0),
    "GripRubber": ("#2A2C2D", 0.86, 0.0),
    "HandsetGrey": ("#3A3E42", 0.50, 0.0),
    # V1 fix round (AD): worn foredeck gelcoat, dark mirror glass, muted SOLAS tape (the full-length light retro
    # strip read as floating white lines), hatch seam groove
    "PWCDeck": ("#C85A28", 0.42, 0.0),
    "MirrorGlass": ("#1E2428", 0.05, 0.0),
    "Reflective": ("#9EA3A6", 0.42, 0.0),
    "HatchSeam": ("#3A2A22", 0.70, 0.0),
})
R.PROC.update({
    "PWCOrange": dict(mottle=(0.8, 0.05), grime=("#8A4426", 0.25), streak=("#A85A3E", 0.16), salt=("#B9A698", 0.18),
                      scuff=("#9A5034", 0.30), zgrime=("#5A3A2A", 0.45, 0.85, 1.2), zsalt=("#C4B6A8", 0.30, 1.15, 1.5),
                      rough_var=0.10, bump=("peel", 0.03, 6)),
    # V1 fix: the foredeck fills the first-person frame: heavy grime, scuffs, salt streaks, strong roughness variation
    "PWCDeck": dict(mottle=(1.2, 0.07), grime=("#7E4024", 0.34), streak=("#A55A3C", 0.26), salt=("#BFAE9F", 0.32),
                    scuff=("#8A4A30", 0.45), rough_var=0.16, bump=("peel", 0.04, 6)),
    "HatchSeam": dict(mottle=(4, 0.05), grime=("#2A2018", 0.30), rough_var=0.05),
    "PWCOrangeDark": dict(mottle=(1.5, 0.06), grime=("#6A3A24", 0.30), rough_var=0.10, bump=("peel", 0.03, 8)),
    "DeckGrey": dict(mottle=(2, 0.06), grime=("#3A3C3A", 0.30), salt=("#8C8E8A", 0.12), rough_var=0.08, bump=("peel", 0.04, 8)),
    "RubBlack": dict(mottle=(2, 0.08), grime=("#4A4A46", 0.30), scuff=("#55585A", 0.35), rough_var=0.10, bump=("grain", 0.12, 20)),
    "SeatSide": dict(mottle=(4, 0.05), grime=("#45484A", 0.25), rough_var=0.10, bump=("grain", 0.12, 60)),
    "SledOrange": dict(mottle=(0.8, 0.06), grime=("#7A3A24", 0.28), salt=("#B9A698", 0.20), scuff=("#9A5034", 0.35),
                       zgrime=("#5A3A2A", 0.5, 1.05, 1.25), rough_var=0.10, bump=("peel", 0.04, 6)),
    "SledHull": dict(mottle=(1.5, 0.08), grime=("#2E3236", 0.35), scuff=("#5A5E62", 0.30), rough_var=0.10, bump=("peel", 0.05, 8)),
    "HoseBlack": dict(mottle=(4, 0.08), grime=("#3E3C38", 0.25), rough_var=0.08, bump=("grain", 0.12, 80)),
    "GripRubber": dict(mottle=(5, 0.08), grime=("#4A4744", 0.30), salt=("#77756F", 0.22), scuff=("#55524E", 0.40),
                       rough_var=0.14, bump=("diamond", 0.6, 9)),   # V1 fix: worn grips (palm wear, salt, grime)
    "HandsetGrey": dict(mottle=(4, 0.04), grime=("#2E3236", 0.20), rough_var=0.06),
})

NOSE, TRANSOM = -5.05, 5.05
ZF = 1.5                                   # footwell floor
SLED_Y0, SLED_Y1, SLED_Z0, SLED_Z1, SLED_HX = 5.35, 9.75, 1.0, 1.36, 1.62
# V1 fix round: seated rider eye (was 6.2 high / standing: the bars fell out of the bottom of the FOV 40 frame);
# the first-person camera looks EYE_PITCH below level so bars, display and kill cord sit in the lower-middle
EYE = Vector((0.0, 0.9, 5.2))
EYE_PITCH = -30.0
BAR_Y, BAR_Z = -1.2, 3.32
DISPLAY_C = Vector((0.0, -1.66, 3.3))
DISPLAY_N = (EYE - DISPLAY_C).normalized()


def M(g, name, lo="X"):
    return name if g.hi else lo


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# =========================================================================== hull surface
def _u(y):
    return (y - NOSE) / (TRANSOM - NOSE)


def half_beam(y):
    u = _u(y)
    a = min(u / 0.55, 1.0)
    b = 1.86 * max(0.0, 1 - (1 - a) ** 2.0) ** 0.65   # V1 fix: finer bow entry (was a round sqrt entry)
    return max(b - 0.14 * max(0.0, (u - 0.62) / 0.38) ** 2, 0.06)


def keel_z(y):
    return 1.3 * max(0.0, (0.36 - _u(y)) / 0.36) ** 2.0


def deadrise(y):
    return 0.40 + 0.45 * max(0.0, (0.5 - _u(y)) / 0.5) ** 1.5


def gunwale_z(y):
    return 2.0 + 0.35 * max(0.0, (0.5 - _u(y)) / 0.5) ** 1.6


def footwell(y):
    return smooth(-1.5, -0.7, y)


def top_z(x, y):
    """Deck top at |x|: hood crown forward, footwell floor aft (blended)."""
    b, zg = half_beam(y), gunwale_z(y)
    crown = (3.0 - zg - 0.06) * (0.12 + 0.88 * smooth(NOSE, -1.5, y) ** 0.8)
    hood = zg + 0.06 + crown * max(0.0, 1 - (abs(x) / b) ** 2) ** 0.6
    return hood + (ZF - hood) * footwell(y)


def profile(y):
    """Half section (x >= 0) from the keel round the side and over the deck to the centreline: 15 points."""
    b, zk, t, zg = half_beam(y), keel_z(y), deadrise(y), gunwale_z(y)
    zr = zg - 0.42
    z3 = zk + 0.8 * b * t + 0.015
    zr = max(zr, z3 + 0.12)
    x10, x11 = b - min(0.2, 0.1 * b), b - min(0.28, 0.15 * b)
    f = footwell(y)
    pts = [(0.0, zk), (0.42 * b, zk + 0.42 * b * t), (0.8 * b, zk + 0.8 * b * t), (0.9 * b, z3),   # V1 fix: hard chine
           (0.92 * b, z3 + 0.22 * (zr - z3)), (b, zr), (b + 0.08, zr + 0.05), (b + 0.08, zr + 0.15), (b, zr + 0.2),
           (b - 0.03, zg), (x10, zg + 0.05)]
    hood11 = top_z(x11, y)
    pts.append((x11, hood11 + (ZF - hood11) * f))
    for x in (0.35 * b, 0.17 * b, 0.0):
        pts.append((x, top_z(x, y)))
    return pts


def ring(y):
    p = profile(y)
    port = [Vector((x, y, z)) for x, z in p]
    stbd = [Vector((-x, y, z)) for x, z in reversed(p[1:-1])]
    return port + stbd


NP = 15   # profile points


def _seg_mat(k, y):
    f = footwell(y)
    if k <= 2:
        return "HullCharcoal"
    if k in (3, 4):
        return "PWCOrange"
    if k in (5, 6, 7):
        return "RubBlack"
    if k == 8:
        return "Reflective" if (0.6 < y < 1.7 or 3.0 < y < 4.2) else "PWCOrange"   # short SOLAS tape blocks
    if k == 9:
        return "PWCOrange"
    if k == 10:
        return "DeckGrey" if f > 0.5 else "PWCOrange"
    return "NonSlip" if f > 0.5 else "PWCDeck"


def stations(hi):
    n = 110 if hi else 62
    ys = [NOSE + (TRANSOM - NOSE) * (i / (n - 1)) ** 1.3 for i in range(n)]
    return ys


def hull(g):
    ys = stations(g.hi)
    rings = [ring(y) for y in ys]
    nseg = len(rings[0])

    def matfn(i, j):
        k = j if j < NP - 1 else (2 * NP - 3) - j
        return _seg_mat(k, 0.5 * (ys[i] + ys[i + 1]))

    g.rings(rings, M(g, "PWCOrange"), closed=True, cap0=True, matfn=matfn if g.hi else None)
    vs = [g.bm.verts.new(p) for p in rings[-1]]
    f = g.face(vs, M(g, "PWCOrange"))
    if f:
        g.orient([f], lambda c: Vector((0, 1, 0)))
        bmesh.ops.triangulate(g.bm, faces=[f], quad_method="BEAUTY", ngon_method="EAR_CLIP")
    return nseg


def side_point(sx, y, t, h=0.0):
    """Point on the lower topside (profile points 4 -> 5) at fraction t, h along the outward normal."""
    def p(yy, tt):
        pr = profile(yy)
        (x4, z4), (x5, z5) = pr[4], pr[5]
        return Vector((sx * (x4 + (x5 - x4) * tt), yy, z4 + (z5 - z4) * tt))
    c = p(y, t)
    if not h:
        return c
    n = (p(y + 0.01, t) - p(y - 0.01, t)).cross(p(y, t + 0.01) - p(y, t - 0.01)).normalized()
    if n.x * sx < 0:
        n = -n
    return c + n * h


def side_len(y):
    pr = profile(y)
    return math.hypot(pr[5][0] - pr[4][0], pr[5][1] - pr[4][1])


# =========================================================================== seat, decals
SEAT_C, SEAT_HY = 1.85, 2.45


def seat(g):
    seg = 64 if g.hi else 44
    secs = [(1.46, 0.76, 2.52), (2.02, 0.74, 2.5), (2.12, 0.76, 2.52), (2.16, 0.74, 2.5), (2.42, 0.72, 2.46),
            (2.45, 0.715, 2.455), (2.6, 0.62, 2.36), (2.69, 0.44, 2.2), (2.72, 0.18, 2.0)]
    mats = ["DeckGrey", "BlackPlastic", "BlackPlastic", "SeatSide", "SeatSeam", "Vinyl", "Vinyl", "Vinyl"]
    start = len(g.bm.verts)
    R.loft(g, [(0, SEAT_C, z, hx, hy) for z, hx, hy in secs], seg, M(g, "Vinyl"), cap0=False, cap1=True, p=3.2,
           matfn=(lambda i, j: mats[i]) if g.hi else None)
    # stepped saddle: the passenger section sits higher than the rider's
    R.deform(g, start, lambda c: Vector((c.x, c.y, c.z + (0.16 * smooth(1.8, 2.8, c.y) if c.z > 2.2 else 0.0))))


def _topside_patch(g, sx, y0, y1, t0, t1, mat, off, nu, nv):
    pts = [[side_point(sx, y0 + (y1 - y0) * i / nu, t0 + (t1 - t0) * j / nv, off) for j in range(nv + 1)]
           for i in range(nu + 1)]
    fs = g.rings(pts, mat, closed=False, recalc=False)
    g.orient(fs, lambda c, sx=sx: Vector((sx, 0, 0.2)))


def _topside_text(g, sx, yc, tc, body, size, mat, off, scale_x=1.0):
    me = R.text_mesh(body, size, font_scale_x=scale_x)
    sd = 1.0 if sx > 0 else -1.0

    def mapfn(co):
        y = yc + sd * co.x
        return side_point(sx, y, tc + co.y / side_len(y), off)
    fs = g.add_mesh(me, mat, mapfn)
    g.orient(fs, lambda c, sx=sx: Vector((sx, 0, 0.2)))
    import bpy
    bpy.data.meshes.remove(me)


def _topside_disc(g, sx, yc, tc, r, mat, off, n=24, star=None):
    """Disc (or an n-point star when star = inner radius) on the topside, (y, t) metric."""
    L = side_len(yc)
    cen = side_point(sx, yc, tc, off)
    rim = []
    for k in range(n):
        a = 2 * math.pi * k / n
        rr = r if (star is None or k % 2 == 0) else star
        rim.append(side_point(sx, yc + rr * math.cos(a), tc + rr * math.sin(a) / L, off))
    cv = g.bm.verts.new(cen)
    vs = [g.bm.verts.new(p) for p in rim]
    fs = [g.face((vs[k], vs[(k + 1) % n], cv), mat) for k in range(n)]
    g.orient([f for f in fs if f], lambda c, sx=sx: Vector((sx, 0, 0.2)))


BAND = (-2.2, 3.5, 0.14, 0.86)
NUMBER = (-4.25, -3.05, 0.12, 0.88)
CREST = (-2.65, 0.5, 0.2)
OFF = 0.025


def decals(g):
    for sx in (1, -1):
        y0, y1, t0, t1 = BAND
        _topside_patch(g, sx, y0, y1, t0, t1, M(g, "PanelCharcoal"), OFF, 40 if g.hi else 18, 4 if g.hi else 2)
        y0n, y1n, t0n, t1n = NUMBER
        _topside_patch(g, sx, y0n, y1n, t0n, t1n, M(g, "PWCOrange"), OFF, 16 if g.hi else 8, 4 if g.hi else 2)
        yc, tc, r = CREST
        _topside_disc(g, sx, yc, tc, r, M(g, "PanelCharcoal"), OFF, n=28 if g.hi else 16)
        if g.hi:
            _topside_text(g, sx, (y0 + y1) / 2, 0.5 - 0.02, "GALE ISLES COASTGUARD", 0.30, "LetterWhite", OFF + 0.004, 0.95)
            _topside_text(g, sx, (y0n + y1n) / 2, 0.5 - 0.03, "GI-17", 0.34, "LetterCharcoal", OFF + 0.004, 1.0)
            # crest: white compass star, orange rim ring, charcoal lighthouse with a white lamp
            _topside_disc(g, sx, yc, tc, r * 0.82, "LetterWhite", OFF + 0.003, n=16, star=r * 0.3)
            _topside_disc(g, sx, yc, tc, r * 0.34, "PWCOrange", OFF + 0.005, n=16)
            _topside_text(g, sx, yc, tc + 0.02 / side_len(yc), "I", 0.3, "LetterCharcoal", OFF + 0.007, 1.6)


# =========================================================================== fittings (Sled set)
BOLT = [(0.03, 0.0), (0.03, 0.02), (0.022, 0.028), (0.0, 0.03)]


def bolts(g, pts, axis):
    if g.hi:
        for p in pts:
            R.lathe(g, p, axis, BOLT, 6, "Bolt")


def sled(g):
    seg = 56 if g.hi else 36
    sc, hy, hx, z0, z1 = (SLED_Y0 + SLED_Y1) / 2, (SLED_Y1 - SLED_Y0) / 2, SLED_HX, SLED_Z0, SLED_Z1
    body = [(0, sc, z0, hx - 0.14, hy - 0.14), (0, sc, z0 + 0.07, hx - 0.03, hy - 0.03), (0, sc, z0 + 0.18, hx, hy),
            (0, sc, z1 - 0.05, hx - 0.02, hy - 0.02), (0, sc, z1, hx - 0.1, hy - 0.1)]
    R.loft(g, body, seg, M(g, "SledHull"), cap0=True, cap1=False, p=4.0,
           matfn=(lambda i, j: "SledHull" if i < 2 else "SledOrange") if g.hi else None)
    R.loft(g, [body[-1], (0, sc, z1 + 0.002, hx - 0.105, hy - 0.105)], seg, M(g, "SledOrange"), cap0=False, cap1=True, p=4.0)
    # non-slip pad on the deck, rubber bumper round the rim
    R.loft(g, [(0, sc - 0.35, z1 - 0.005, 1.25, 1.55), (0, sc - 0.35, z1 + 0.03, 1.22, 1.52)], seg, M(g, "NonSlip"),
           cap0=False, cap1=True, p=4.0)
    rim = R.superellipse_ring(0, sc, z0 + 0.18, hx + 0.02, hy + 0.02, 64 if g.hi else 36, p=4.0)
    R.sweep(g, rim + [rim[0]], R.circle_profile(0.07, 12 if g.hi else 8), M(g, "Rubber"))
    # six hose handles: two a side, two at the stern, with stainless end clamps
    tseg = 12 if g.hi else 8
    hs = []
    for sx in (1, -1):
        for y in (6.6, 8.5):
            hs.append(([(sx * 1.40, y - 0.4, z1), (sx * 1.46, y - 0.32, z1 + 0.24), (sx * 1.46, y + 0.32, z1 + 0.24),
                        (sx * 1.40, y + 0.4, z1)], [(sx * 1.40, y - 0.4), (sx * 1.40, y + 0.4)]))
        x = sx * 0.62
        hs.append(([(x - 0.4, SLED_Y1 - 0.32, z1), (x - 0.32, SLED_Y1 - 0.26, z1 + 0.24), (x + 0.32, SLED_Y1 - 0.26, z1 + 0.24),
                    (x + 0.4, SLED_Y1 - 0.32, z1)], [(x - 0.4, SLED_Y1 - 0.32), (x + 0.4, SLED_Y1 - 0.32)]))
    for path, feet in hs:
        R.tube(g, path, 0.045, M(g, "HoseBlack"), tseg, fillet=0.12, fseg=4 if g.hi else 2)
        for fx, fy in feet:
            R.box(g, (fx, fy, z1 + 0.03), (0.16, 0.16, 0.06), M(g, "Stainless"))
            bolts(g, [(fx, fy, z1 + 0.06)], (0, 0, 1))
    # mount: two stainless arms from the transom to the sled nose, aluminium hinge tube, brackets
    for sx in (1, -1):
        R.tube(g, [(sx * 0.72, TRANSOM - 0.02, 1.32), (sx * 0.72, TRANSOM + 0.25, 1.36), (sx * 0.72, SLED_Y0 + 0.35, z1 + 0.06)],
               0.05, M(g, "Stainless"), tseg, fillet=0.15, fseg=3 if g.hi else 1)
        R.box(g, (sx * 0.72, TRANSOM + 0.04, 1.32), (0.22, 0.08, 0.3), M(g, "Stainless"))
        bolts(g, [(sx * 0.72 + dx, TRANSOM + 0.08, 1.32 + dz) for dx in (-0.07, 0.07) for dz in (-0.1, 0.1)], (0, 1, 0))
        R.box(g, (sx * 0.72, SLED_Y0 + 0.35, z1 + 0.05), (0.2, 0.3, 0.1), M(g, "Stainless"))
    R.tube(g, [(-0.95, SLED_Y0 + 0.35, z1 + 0.09), (0.95, SLED_Y0 + 0.35, z1 + 0.09)], 0.045, M(g, "Aluminium"), tseg)


def rescue_text(g):
    if not g.hi:
        return
    me = R.text_mesh("RESCUE", 0.5, font_scale_x=1.0)
    fs = g.add_mesh(me, "LetterWhite", lambda c: Vector((-c.x, SLED_Y1 - 0.85 - c.y, SLED_Z1 + 0.004)))
    g.orient(fs, lambda c: Vector((0, 0, 1)))
    import bpy
    bpy.data.meshes.remove(me)


NAV_Y = -3.9


def nav_light_pos(sx):
    b = half_beam(NAV_Y)
    return Vector((sx * (b - 0.12), NAV_Y, gunwale_z(NAV_Y) + 0.1))


MAST = Vector((0.0, 4.85, 3.48))


def fittings(g):
    seg = 16 if g.hi else 10
    # rear grab handle and seat-side passenger handles
    R.tube(g, [(0.6, 4.42, ZF), (0.6, 4.58, 2.38), (-0.6, 4.58, 2.38), (-0.6, 4.42, ZF)], 0.05, M(g, "Stainless"), seg,
           fillet=0.2, fseg=4 if g.hi else 2)
    for sx in (1, -1):
        R.tube(g, [(sx * 0.70, 3.2, 2.2), (sx * 0.8, 3.3, 2.3), (sx * 0.8, 3.95, 2.3), (sx * 0.70, 4.05, 2.2)], 0.035,
               M(g, "Stainless"), seg, fillet=0.08, fseg=3 if g.hi else 1)
        R.box(g, (sx * 0.6, 4.42, ZF + 0.03), (0.2, 0.2, 0.06), M(g, "Stainless"))
    # nav lights on the gunwale, port red / starboard green
    for sx, lens in ((1, "LensRed"), (-1, "LensGreen")):
        p = nav_light_pos(sx)
        R.box(g, tuple(p - Vector((0, 0, 0.02))), (0.16, 0.32, 0.12), M(g, "BlackPlastic"))
        R.box(g, tuple(p + Vector((sx * 0.07, -0.03, 0.0))), (0.05, 0.22, 0.08), M(g, lens))
    # all-round white on a short stern pole
    R.lathe(g, (0, MAST.y, ZF), (0, 0, 1), [(0.12, 0.0), (0.12, 0.04), (0.05, 0.06), (0.04, 0.08), (0.04, 1.82),
                                          (0.07, 1.84), (0.07, 1.92)], seg, M(g, "Aluminium"))
    R.lathe(g, (0, MAST.y, ZF + 1.92), (0, 0, 1), [(0.075, 0.0), (0.075, 0.12), (0.06, 0.18), (0.0, 0.2)], seg,
            M(g, "LensWhite"))
    bolts(g, [(0.09 * math.cos(a), MAST.y + 0.09 * math.sin(a), ZF + 0.04) for a in (0.0, 2.1, 4.2)], (0, 0, 1))
    # bow eye and transom tow eye (stainless U-bolts) with backing plates
    R.tube(g, [(0.1, NOSE + 0.08, 1.62), (0.1, NOSE - 0.12, 1.62), (-0.1, NOSE - 0.12, 1.62), (-0.1, NOSE + 0.08, 1.62)],
           0.028, M(g, "Stainless"), seg, fillet=0.08, fseg=4 if g.hi else 2)
    R.tube(g, [(0.12, TRANSOM - 0.05, 1.18), (0.12, TRANSOM + 0.16, 1.18), (-0.12, TRANSOM + 0.16, 1.18),
               (-0.12, TRANSOM - 0.05, 1.18)], 0.03, M(g, "Stainless"), seg, fillet=0.08, fseg=4 if g.hi else 2)
    R.box(g, (0, TRANSOM + 0.015, 1.18), (0.42, 0.03, 0.16), M(g, "Stainless"))
    bolts(g, [(sx * 0.17, TRANSOM + 0.03, 1.18) for sx in (1, -1)], (0, 1, 0))
    # jet: steering nozzle, reverse bucket, pump cover, sponsons
    R.lathe(g, (0, TRANSOM - 0.35, 0.5), (0, 1, 0), [(0.3, 0.0), (0.3, 0.35), (0.25, 0.65), (0.22, 0.85), (0.18, 0.86),
                                                    (0.18, 0.7)], seg + 4, M(g, "Aluminium"),
            matfn=(lambda i, j: "Vent" if i >= 4 else "Aluminium") if g.hi else None)
    R.box(g, (0, TRANSOM + 0.62, 0.52), (0.62, 0.08, 0.56), M(g, "BlackPlastic"), bev=0.03)
    for sx in (1, -1):
        R.tube(g, [(sx * 0.33, TRANSOM + 0.62, 0.62), (sx * 0.33, TRANSOM + 0.1, 0.82), (sx * 0.33, TRANSOM - 0.02, 0.82)],
               0.025, M(g, "Stainless"), 8 if g.hi else 5, fillet=0.1, fseg=2)
    R.box(g, (0, TRANSOM - 0.3, 0.1), (0.8, 0.9, 0.05), M(g, "Aluminium"))
    for sx in (1, -1):
        b = half_beam(4.3)
        R.box(g, (sx * (b * 0.9), 4.3, 0.78), (0.12, 0.9, 0.18), M(g, "HullCharcoal"),
              rot=Matrix.Rotation(sx * math.radians(-28), 3, "Y"))
    # V1 fix: stainless mooring cleats on the aft gunwales and a bow cleat on the foredeck centreline
    for c, yaw in [((sx * (half_beam(4.55) - 0.16), 4.55, gunwale_z(4.55) + 0.05), 0.0) for sx in (1, -1)] + \
            [((0.0, -4.35, top_z(0.0, -4.35) - 0.005), 0.0)]:
        cleat(g, Vector(c))
    # base kill-cord lanyard (coiled) is part of base_bars


def cleat(g, c):
    R.box(g, tuple(c + Vector((0, 0, 0.02))), (0.08, 0.16, 0.04), M(g, "Stainless"))
    for dy in (-0.05, 0.05):
        R.box(g, tuple(c + Vector((0, dy, 0.06))), (0.045, 0.045, 0.06), M(g, "Stainless"))
    R.box(g, tuple(c + Vector((0, 0, 0.1))), (0.055, 0.36, 0.035), M(g, "Stainless"), bev=0.01 if g.hi else None)
    bolts(g, [tuple(c + Vector((0, dy, 0.04))) for dy in (-0.11, 0.11)], (0, 0, 1))


def _deck(x, y, h=0.0):
    return Vector((x, y, top_z(x, y) + h))


def _deck_n(x, y, e=0.01):
    dx = (top_z(x + e, y) - top_z(x - e, y)) / (2 * e)
    dy = (top_z(x, y + e) - top_z(x, y - e)) / (2 * e)
    return Vector((-dx, -dy, 1.0)).normalized()


SCREW = [(0.018, 0.0), (0.018, 0.008), (0.012, 0.013), (0.0, 0.014)]
HATCH = (-4.15, -2.55, 0.6)     # y0, y1, half width as a fraction of the beam


def foredeck(g):
    """V1 fix (HP only, baked into the Hull set): the foredeck the rider sees: a moulded hatch seam with fasteners and
    a textured non-slip pad on the hatch lid."""
    if not g.hi:
        return
    y0, y1, fw = HATCH
    n = 28
    side = [(fw * half_beam(y0 + (y1 - y0) * i / n), y0 + (y1 - y0) * i / n) for i in range(n + 1)]
    loop = side + [(-x, y) for x, y in reversed(side)]          # port side bow -> aft, starboard aft -> bow
    m = len(loop)
    faces, outer = [], []
    for i in range(m):
        x, y = loop[i]
        xa, ya = loop[(i + 1) % m]
        xb, yb = loop[i - 1]
        t = Vector((xa - xb, ya - yb, 0)).normalized()
        o = Vector((t.y, -t.x, 0))                               # outward in plan (loop runs clockwise from above)
        if o.x * x < 0 and abs(x) > 0.05:
            o = -o
        outer.append((o, x, y))
    vin = [g.bm.verts.new(_deck(x - o.x * 0.018, y - o.y * 0.018, 0.006)) for o, x, y in outer]
    vout = [g.bm.verts.new(_deck(x + o.x * 0.018, y + o.y * 0.018, 0.006)) for o, x, y in outer]
    for i in range(m):
        f = g.face((vin[i], vout[i], vout[(i + 1) % m], vin[(i + 1) % m]), "HatchSeam")
        if f:
            faces.append(f)
    g.orient(faces, lambda c: Vector((0, 0, 1)))
    # fasteners just outside the seam, about every 0.3 studs
    for i in range(0, m, 3):
        o, x, y = outer[i]
        px, py = x + o.x * 0.07, y + o.y * 0.07
        R.lathe(g, _deck(px, py, 0.0), tuple(_deck_n(px, py)), SCREW, 8, "Bolt")
    # non-slip pad on the lid
    nu, nv = 18, 10
    py0, py1 = y0 + 0.25, y1 - 0.25
    grid = []
    for i in range(nu + 1):
        yy = py0 + (py1 - py0) * i / nu
        w = fw * half_beam(yy) - 0.16
        grid.append([g.bm.verts.new(_deck(-w + 2 * w * j / nv, yy, 0.008)) for j in range(nv + 1)])
    pad = []
    for i in range(nu):
        for j in range(nv):
            f = g.face((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]), "NonSlip")
            if f:
                pad.append(f)
    g.orient(pad, lambda c: Vector((0, 0, 1)))


# =========================================================================== bars (base) and the close-up set
def pod(g, hi_detail):
    seg = (40 if g.hi else 32) if hi_detail else (24 if g.hi else 14)
    zb = top_z(0, -1.35) - 0.25
    R.loft(g, [(0, -1.38, zb, 0.52, 0.42), (0, -1.38, 3.05, 0.5, 0.42), (0, -1.36, 3.22, 0.46, 0.38),
               (0, -1.34, 3.27, 0.36, 0.3), (0, -1.33, 3.285, 0.2, 0.18)], seg, M(g, "BlackPlastic"), cap0=False, p=3.0,
           matfn=(lambda i, j: "PWCOrangeDark" if i == 0 else "BlackPlastic") if g.hi else None)
    if hi_detail and g.hi:   # V1 fix: lid hinge seam, hinge barrel and screws on the console tub
        R.loft(g, [(0, -1.36, 3.19, 0.472, 0.392), (0, -1.36, 3.205, 0.47, 0.39)], seg, "HatchSeam", cap0=False,
               cap1=False, p=3.0)
        R.lathe(g, (0.22, -0.962, 3.212), (-1, 0, 0), [(0.0, 0.0), (0.016, 0.0), (0.016, 0.44), (0.0, 0.44)], 10,
                "Aluminium")
        for x in (-0.3, -0.12, 0.12, 0.3):
            y = -1.37 + 0.404 * max(0.0, 1 - abs(x / 0.484) ** 3) ** (1 / 3)
            R.lathe(g, (x, y, 3.12), (0, 1, 0), SCREW, 8, "Bolt")
        for sx in (1, -1):
            for y in (-1.6, -1.15):
                R.lathe(g, (sx * 0.487, y, 3.1), (sx, 0, 0), SCREW, 8, "Bolt")


def bar(g, hi_detail):
    tseg = (18 if g.hi else 14) if hi_detail else (10 if g.hi else 6)
    path = [(1.02, BAR_Y + 0.17, BAR_Z + 0.05), (0.72, BAR_Y + 0.08, BAR_Z + 0.03), (0.3, BAR_Y, BAR_Z),
            (-0.3, BAR_Y, BAR_Z), (-0.72, BAR_Y + 0.08, BAR_Z + 0.03), (-1.02, BAR_Y + 0.17, BAR_Z + 0.05)]
    R.tube(g, path, 0.035, M(g, "Aluminium"), tseg, fillet=0.2, fseg=4 if hi_detail else 2)
    R.box(g, (0, BAR_Y, BAR_Z - 0.01), (0.34, 0.16, 0.1), M(g, "BlackPlastic"))   # clamp
    bolts(g, [(dx, BAR_Y + 0.08, BAR_Z - 0.01) for dx in (-0.12, 0.12)] if hi_detail else [], (0, 1, 0))
    for sx in (1, -1):
        a = Vector((sx * 0.72, BAR_Y + 0.08, BAR_Z + 0.03))
        b = Vector((sx * 1.06, BAR_Y + 0.18, BAR_Z + 0.05))
        d = (b - a).normalized()
        n = 14 if hi_detail else 6
        prof = []
        for k in range(n + 1):
            h = (b - a).length * k / n
            r = 0.058 if 0 < k < n else 0.066          # flanges at both ends
            if hi_detail and 0 < k < n and k % 2 == 0:
                r = 0.054                               # moulded grip ribs
            prof.append((r, h))
        prof = [(0.066, -0.02)] + prof + [(0.03, (b - a).length + 0.015), (0.0, (b - a).length + 0.02)]
        R.lathe(g, a, d, prof, (18 if g.hi else 14) if hi_detail else 8, M(g, "GripRubber"),
                matfn=(lambda i, j, n=n: "BlackPlastic" if i in (0, 1, n + 1, n + 2) else "GripRubber") if g.hi else None)


MIRROR_Z = top_z(0.92, -2.1) + 0.42
# V1 fix: dark glossy (non-metal) mirror glass with a subtle sky gradient baked in, instead of a white metal mirror
R.PROC["MirrorGlass"] = dict(mottle=(3, 0.02), zgrad=("#5A6874", MIRROR_Z - 0.09, MIRROR_Z + 0.11), rough_var=0.02)


def mirrors(g, hi_detail):
    for sx in (1, -1):
        base = Vector((sx * 0.92, -2.1, top_z(0.92, -2.1)))
        head = Vector((sx * 1.08, -2.08, base.z + 0.42))
        R.box(g, tuple(base + Vector((0, 0, 0.03))), (0.18, 0.24, 0.08), M(g, "BlackPlastic"))
        R.tube(g, [tuple(base + Vector((0, 0, 0.05))), tuple(base + Vector((sx * 0.04, 0.0, 0.25))), tuple(head - Vector((0, -0.06, 0.08)))],
               0.03, M(g, "BlackPlastic"), 10 if hi_detail else 6, fillet=0.08, fseg=2)
        rot = Matrix.Rotation(sx * math.radians(-12), 3, "Z")
        R.box(g, tuple(head), (0.46, 0.1, 0.24), M(g, "BlackPlastic"), rot=rot, bev=0.04)
        R.box(g, tuple(head + rot @ Vector((0, 0.052, 0))), (0.40, 0.006, 0.19), M(g, "MirrorGlass"), rot=rot, bev=0.0)
        if hi_detail and g.hi:   # V1 fix: rubber bezel round the dark glass and a visible fastener
            for c, sz in (((0.21, 0, 0), (0.024, 0.014, 0.214)), ((-0.21, 0, 0), (0.024, 0.014, 0.214)),
                          ((0, 0, 0.104), (0.444, 0.014, 0.024)), ((0, 0, -0.104), (0.444, 0.014, 0.024))):
                R.box(g, tuple(head + rot @ Vector((c[0], 0.056, c[2]))), sz, "Rubber", rot=rot)
            R.lathe(g, tuple(head + rot @ Vector((0, 0.062, -0.104))), tuple(rot @ Vector((0, 1, 0))), SCREW, 8, "Bolt")
        bolts(g, [tuple(base + Vector((dx, dy, 0.07))) for dx in (-0.05, 0.05) for dy in (-0.08, 0.08)] if hi_detail else [],
              (0, 0, 1))


def _frame(c, n):
    """(right, up) for a panel at c facing n, as the rider reads it (right = -X)."""
    r = Vector((-1, 0, 0))
    up = r.cross(-n).normalized()
    return r, up


def display_box(g, u, v, h, size, mat):
    r, up = _frame(DISPLAY_C, DISPLAY_N)
    rot = Matrix((r, up, DISPLAY_N)).transposed()
    R.box(g, tuple(DISPLAY_C + r * u + up * v + DISPLAY_N * (h + size[2] / 2)), size, mat, rot=rot, bev=min(0.01, size[2] / 3))


def display_text(g, body, size, u, v, h, mat):
    r, up = _frame(DISPLAY_C, DISPLAY_N)
    me = R.text_mesh(body, size)
    fs = g.add_mesh(me, mat, lambda c: DISPLAY_C + r * (u + c.x) + up * (v + c.y) + DISPLAY_N * h)
    g.orient(fs, lambda c: DISPLAY_N)
    import bpy
    bpy.data.meshes.remove(me)


def display_housing(g):
    """Binnacle in front of the bars, tilted to the rider's eye; bezel, buttons (the glass is its own part)."""
    display_box(g, 0, 0, -0.1, (0.62, 0.38, 0.1), M(g, "BlackPlastic"))
    display_box(g, 0, 0.0, 0.0, (0.56, 0.32, 0.03), M(g, "BlackPlastic"))
    R.box(g, tuple(DISPLAY_C - DISPLAY_N * 0.12 - Vector((0, 0, 0.1))), (0.3, 0.18, 0.2), M(g, "BlackPlastic"))
    for k, u in enumerate((-0.12, 0.0, 0.12)):
        display_box(g, u, -0.21, -0.06, (0.07, 0.04, 0.03), M(g, "HandsetGrey"))


def display_screen(g):
    display_box(g, 0, 0.01, 0.03, (0.46, 0.25, 0.006), M(g, "Screen"))
    if g.hi:
        h = 0.0365
        display_text(g, "27", 0.13, -0.07, 0.0, h, "LCDText")
        display_text(g, "KN", 0.04, 0.035, -0.035, h, "LCDText")
        display_text(g, "FUEL", 0.028, 0.15, 0.085, h, "LCDText")
        for k in range(5):
            display_box(g, 0.1 + 0.025 * k, 0.045, 0.034, (0.018, 0.035, 0.002), "LCDAmber" if k < 4 else "ScreenChart")
        display_text(g, "NW 312", 0.034, 0.14, -0.05, h, "LCDAmber")
        display_text(g, "14:05", 0.026, -0.16, 0.09, h, "LCDText")
        display_box(g, 0.075, 0.0, 0.034, (0.004, 0.2, 0.002), "ScreenChart")
        display_box(g, 0.0, -0.095, 0.034, (0.42, 0.004, 0.002), "ScreenChart")


KILL = Vector((0.2, -1.2, BAR_Z + 0.1))


def kill_switch(g, hi_detail):
    R.lathe(g, KILL - Vector((0, 0, 0.12)), (0, 0, 1), [(0.07, 0.0), (0.07, 0.1), (0.06, 0.12), (0.0, 0.12)],
            16 if hi_detail else 8, M(g, "BlackPlastic"))
    R.lathe(g, KILL, (0, 0, 1), [(0.055, 0.0), (0.055, 0.035), (0.045, 0.05), (0.0, 0.055)], 16 if hi_detail else 8,
            M(g, "LanyardRed"))
    # coiled lanyard: from the clip over the pod's back, down towards the rider's lifejacket, ending in a clip
    a = KILL + Vector((0, 0.03, 0.04))
    ctrl = [a, Vector((0.24, -0.95, 3.25)), Vector((0.3, -0.6, 2.95)), Vector((0.32, -0.42, 2.8))]
    n = (220 if g.hi else 110) if hi_detail else 36
    turns = 26 if hi_detail else 10
    pts = []
    for i in range(n + 1):
        t = i / n
        # quadratic-ish bezier through the control points
        p = ((1 - t) ** 3) * ctrl[0] + 3 * ((1 - t) ** 2) * t * ctrl[1] + 3 * (1 - t) * t * t * ctrl[2] + t ** 3 * ctrl[3]
        q = ((1 - t) ** 2) * (ctrl[1] - ctrl[0]) + 2 * (1 - t) * t * (ctrl[2] - ctrl[1]) + t * t * (ctrl[3] - ctrl[2])
        q = q.normalized()
        s1 = q.cross(Vector((1, 0, 0))).normalized()
        s2 = q.cross(s1).normalized()
        ang = 2 * math.pi * turns * t
        rad = 0.028 * smooth(0.0, 0.06, t) * (1 - smooth(0.94, 1.0, t))
        pts.append(p + (s1 * math.cos(ang) + s2 * math.sin(ang)) * rad)
    R.sweep(g, pts, R.circle_profile(0.009, 6 if g.hi else 4), M(g, "LanyardRed"), cap0=True, cap1=True)
    end = ctrl[3]
    R.box(g, tuple(end + Vector((0.0, 0.03, -0.05))), (0.05, 0.08, 0.12), M(g, "BlackPlastic"))


VHF = Vector((0.62, -1.5, 0.0))


def vhf(g):
    """Rescue VHF handset upright in a clip on the pod's port side (0.132 x 0.060 x 0.040 m)."""
    z0 = top_z(0.62, -1.5)
    c = Vector((VHF.x, VHF.y, z0 + 0.32))
    R.box(g, (VHF.x, VHF.y + 0.05, z0 + 0.2), (0.22, 0.06, 0.4), M(g, "BlackPlastic"))          # clip plate
    R.box(g, (VHF.x, VHF.y + 0.02, z0 + 0.03), (0.26, 0.2, 0.06), M(g, "BlackPlastic"))          # base
    R.box(g, tuple(c), (0.18, 0.12, 0.4), M(g, "HandsetGrey"), bev=0.03)
    R.lathe(g, c + Vector((0.04, 0, 0.2)), (0, 0, 1), [(0.022, 0.0), (0.02, 0.16), (0.012, 0.2), (0.0, 0.205)], 8,
            M(g, "Rubber"))
    R.box(g, tuple(c + Vector((0, -0.062, 0.08))), (0.12, 0.006, 0.09), M(g, "Screen"), bev=0.0)
    for k in range(3):
        R.box(g, tuple(c + Vector((-0.035 + 0.035 * k, -0.062, -0.04))), (0.025, 0.008, 0.02), M(g, "BlackPlastic"), bev=0.0)
    R.box(g, tuple(c + Vector((0.093, 0, 0.05))), (0.012, 0.05, 0.1), M(g, "LanyardRed"), bev=0.0)   # PTT key
    if g.hi:
        bolts(g, [(VHF.x + dx, VHF.y + 0.085, z0 + 0.3) for dx in (-0.07, 0.07)], (0, 1, 0))


def levers(g):
    for sx in (1, -1):
        R.box(g, (sx * 0.64, BAR_Y + 0.05, BAR_Z + 0.02), (0.14, 0.16, 0.14), M(g, "BlackPlastic"))   # switch housing
        R.tube(g, [(sx * 0.7, BAR_Y - 0.04, BAR_Z), (sx * 0.78, BAR_Y - 0.17, BAR_Z - 0.03), (sx * 1.0, BAR_Y - 0.12, BAR_Z - 0.01)],
               0.02, M(g, "BlackPlastic"), 8, fillet=0.06, fseg=2)                                     # finger levers
        for k, lens in enumerate(("HandsetGrey", "LensRed" if sx < 0 else "HandsetGrey")):
            R.lathe(g, (sx * (0.61 + 0.06 * k), BAR_Y + 0.05, BAR_Z + 0.09), (0, 0, 1), [(0.022, 0.0), (0.022, 0.015),
                                                                                        (0.0, 0.02)], 10, M(g, lens))
        bolts(g, [(sx * 0.64, BAR_Y + 0.13, BAR_Z + dz) for dz in (-0.03, 0.05)], (0, 1, 0))


def base_bars(g):
    pod(g, False)
    bar(g, False)
    mirrors(g, False)
    display_housing(g)
    display_box(g, 0, 0.01, 0.03, (0.46, 0.25, 0.006), M(g, "Screen"))
    kill_switch(g, False)


def closeup_bars(g):
    pod(g, True)
    bar(g, True)
    levers(g)
    mirrors(g, True)
    kill_switch(g, True)


def closeup_console(g):
    display_housing(g)
    vhf(g)
