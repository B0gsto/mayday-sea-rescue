"""H1 M_Bld_Slipway: the Port Haven station slipway (docs/12 2.2 row; map/Build.luau StationSlipway).

Concrete ramp 6.67 m (20 studs) wide between 0.33 m kerbs, 22 m run x 3.33 m drop (1:6.6, the greybox gradient; RNLI
slipways run about 1:5 to 1:7), cast in 3 m bays with chamfered expansion joints (tarred filler strips). Dry B02 Concrete
above the intertidal band, B02 WeedyConcrete below it, and between them (slope distance 3 .. 9 m from the head) the own
T_Slipway_Tide band: a noisy tide line, barnacles, kelp streaks, wet sheen, weed in the joints and at the rail feet. All
three slab sets tile 3 m (Tide 6 m = 2 x 2 repeats) on one slope-distance UV, so the band seams are invisible.
Twin flat-bottom launch rails (head, web, foot; rusted, a polished running band on the head) on bolted sole plates and
clips, barnacle encrustation and weed clumps at the rail feet in the band, steel kerb nosings, a stepped toe, a flat head
apron with bollards, the winch (drum with flanges, side frames, motor box, wire and hook block) and the block-built winch
house: coursed blockwork with drip stains, a framed panelled steel door in a reveal with a lever handle, a louvred vent
and a barred window in reveals, a corrugated mono-pitch roof (real ribs), fascia, verges, gutter and downpipe.

Pivot (origin "free") = top centre of the ramp at the quay edge; the ramp runs down towards -Y (front). Greybox
placement: pivot at world (-165, 4, 4) yawed 180 degrees, so the ramp runs down to +Z (the sea).

    python3 art/source/buildings/M_Bld_Slipway/maketex.py
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_Slipway --steps build,lod,validate,export,turntable
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "M_Bld_Station"))
import geo  # noqa: E402
from geo import Part, newell  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Slipway"
RUN, DROP = 22.0, 10.0 / 3.0
K = DROP / RUN
LS = math.sqrt(1 + K * K)    # slope length per metre of run
HW = 10.0 / 3.0            # half width of the ramp
KW, KH = 0.33, 0.2         # kerbs
SPLIT = -6.0               # weed line (0.4 m above sea level), the middle of the tide band
TOE = -23.0
BAY = 3.0                  # slab bays along the slope (m of slope)
S_TOP, S_BOT = -3.0, -9.0  # tide band, slope distance from the head (one T_Slipway_Tide tile in v)
TT, TIDE_T = 3.0, 6.0      # tile metres: Concrete / WeedyConcrete, Tide
RAILS = (-0.75, 0.75)
CON = ("tile", TT)

# T_Slipway_Steel kit atlas (maketex.KIT)
KIT = {"Wall": (0.0, 0.5, 0.5, 1.0), "Door": (0.5, 0.5, 0.75, 1.0), "Vent": (0.75, 0.75, 1.0, 1.0),
       "Plate": (0.75, 0.5, 1.0, 0.75), "Roof": (0.0, 0.375, 1.0, 0.5), "Rust": (0.0, 0.25, 1.0, 0.375),
       "RailHead": (0.0, 0.125, 1.0, 0.25), "Paint": (0.0, 0.0, 1.0, 0.125)}


def strip(name, metres):
    u0, v0, u1, v1 = KIT[name]
    return ("trim", v0 + 0.006, v1 - 0.006, metres)


def rect(name, w, h):
    u0, v0, u1, v1 = KIT[name]
    e = 0.003
    return ("rect", u0 + e, v0 + e, u1 - e, v1 - e, w, h)


RUST = strip("Rust", 1.5)
PAINT = strip("Paint", 1.0)
HEAD = strip("RailHead", 3.0)
ROOF = strip("Roof", 2.0)


def z(y):
    return y * K if y < 0 else 0.0


def S(y):
    """Slope distance from the head (apron: plain y)."""
    return y if y >= 0 else y * LS


def yS(s):
    return s if s >= 0 else s / LS


def R(y):
    """Winch house: top of the walls / underside of the roof sheet (mono-pitch rising to the back)."""
    return 2.55 + (y - 3.8) * (0.5 / 3.4)


# ------------------------------------------------------------------ helpers
def remap(part, start, fn):
    for i in range(start, len(part.faces)):
        pts, uvs, lv, pid = part.faces[i]
        part.faces[i] = (pts, fn(pts), lv, pid)


def slab_uv(T):
    off = -S_TOP if T == TIDE_T else 0.0      # Tide: v = 0 .. -1 spans the band exactly (top edge s = S_TOP)

    def fn(pts):
        n = newell(pts)
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        if ax >= ay and ax >= az:
            return [(p.z / T, (S(p.y) + off) / T) for p in pts]
        if az >= ay:
            return [(p.x / T, (S(p.y) + off) / T) for p in pts]
        return [(p.x / T, p.z / T) for p in pts]
    return fn


def wall_uv(pts):
    u0, v0, u1, v1 = KIT["Wall"]
    n = newell(pts)
    out = []
    for p in pts:
        if abs(n.x) > max(abs(n.y), abs(n.z)):
            a, b = (p.y - 4.0) / 3.0, p.z / 3.05
        elif abs(n.y) >= abs(n.z):
            a, b = (p.x + 1.5) / 3.0, p.z / 3.05
        else:
            a, b = (p.x + 1.5) / 3.0, (p.y - 4.0) / 3.05
        out.append((u0 + 0.003 + min(max(a, 0), 1) * (u1 - u0 - 0.006), v0 + 0.003 + min(max(b, 0), 1) * (v1 - v0 - 0.006)))
    return out


def planar(name, lo, hi):
    """Box projection into a kit rect: front / back faces (normal y) map x, z; sides map y, z; tops map x, y."""
    u0, v0, u1, v1 = KIT[name]

    def fn(pts):
        n = newell(pts)
        ax = (1, 2) if abs(n.x) >= max(abs(n.y), abs(n.z)) else ((0, 2) if abs(n.y) >= abs(n.z) else (0, 1))
        out = []
        for p in pts:
            a = min(max((p[ax[0]] - lo[ax[0]]) / (hi[ax[0]] - lo[ax[0]]), 0), 1)
            b = min(max((p[ax[1]] - lo[ax[1]]) / (hi[ax[1]] - lo[ax[1]]), 0), 1)
            out.append((u0 + 0.004 + a * (u1 - u0 - 0.008), v0 + 0.004 + b * (v1 - v0 - 0.008)))
        return out
    return fn


def sweep(part, prof, y0, y1, x0, modes, zf=z, caps=True):
    """Extrude a convex profile [(dx, h)] along the slope from y0 to y1: points (x0 + dx, y, zf(y) + h).
    modes: one mode or a list (one per profile edge; caps use the last entry)."""
    part.prim += 1
    ms = modes if isinstance(modes, list) else [modes] * (len(prof) + 1)

    def P(p, y):
        return (x0 + p[0], y, zf(y) + p[1])
    ym = (y0 + y1) / 2
    c = Vector((x0 + sum(p[0] for p in prof) / len(prof), ym, zf(ym) + sum(p[1] for p in prof) / len(prof)))
    for i, p in enumerate(prof):
        q = prof[(i + 1) % len(prof)]
        part.face([P(p, y0), P(q, y0), P(q, y1), P(p, y1)], ms[min(i, len(ms) - 1)], centre=c)
    if caps:
        for y in (y0, y1):
            part.face([P(p, y) for p in prof], ms[-1], centre=c)


def sweep_slope(part, prof, y0, y1, x0, modes, caps=True):
    """sweep() that splits at the apron kink (y = 0)."""
    if y0 > 0 > y1:
        sweep(part, prof, y0, 0.0, x0, modes, caps=caps)
        sweep(part, prof, 0.0, y1, x0, modes, caps=caps)
    else:
        sweep(part, prof, y0, y1, x0, modes, caps=caps)


def mound(part, cx, cy, rx, ry, h, n, rnd, mode, top=0.5, lift=-0.01):
    """A low irregular lump on the slab (weed clump, barnacle encrustation): base ring, smaller top ring, top cap."""
    part.prim += 1
    ang = [2 * math.pi * (i + rnd.uniform(-0.2, 0.2)) / n for i in range(n)]
    jit = [rnd.uniform(0.8, 1.15) for _ in range(n)]

    def ring(sc, dz):
        pts = []
        for a, j in zip(ang, jit):
            x, y = cx + math.cos(a) * rx * j * sc, cy + math.sin(a) * ry * j * sc
            pts.append(Vector((x, y, z(y) + dz)))
        return pts
    b, t = ring(1.0, lift), ring(top, h)
    c = sum(b, Vector()) / n + Vector((0, 0, -0.5))
    for i in range(n):
        j = (i + 1) % n
        part.face([b[i], b[j], t[j], t[i]], mode, centre=c)
    part.face(t, mode, centre=c)


def zone(s):
    return "dry" if s > S_TOP + 1e-6 else ("tide" if s > S_BOT + 1e-6 else "weed")


# ------------------------------------------------------------------ build
def build():
    con, weed, tide, st = Part("Ramp"), Part("Weedy"), Part("Tide"), Part("Steel")
    slab = {"dry": con, "tide": tide, "weed": weed}
    rnd = random.Random(1207)
    geo.LEVEL = 3
    g, ch = 0.015, 0.02       # half joint gap, top-edge chamfer
    # head apron (flat, y 0..3) and the slope bays (3 m of slope each) to the toe
    bays = [(3.0, 0.0)]
    s = 0.0
    while s - BAY > S(TOE) + 0.5:
        bays.append((yS(s), yS(s - BAY)))
        s -= BAY
    bays.append((yS(s), TOE))
    for i, (ya, yb) in enumerate(bays):
        p = slab[zone((S(ya) + S(yb)) / 2)]
        a = ya - (g if i > 0 else 0.0)
        b = yb + (g if yb > TOE else 0.0)
        bot = -4.0 if yb > -12 else -4.5
        dz = 0.0 if i == 0 else rnd.uniform(-0.006, 0.0)
        k0 = len(p.faces)
        prof = [(a, -4.0 if a > -12 else bot), (a, z(a) - (ch if i > 0 else 0.0) + dz), (a - ch, z(a - ch) + dz),
                (b + ch, z(b + ch) + dz), (b, z(b) - ch + dz), (b, bot)]
        if i == 0:
            prof = [(a, -4.0), (a, 0.0), (b + ch, 0.0), (b, -ch), (b, -4.0)]
        p.prism(prof, "x", -HW, HW, CON)
        for x0, x1 in ((-HW - KW, -HW), (HW, HW + KW)):
            kp = [(a, bot), (a, z(a) + KH - (ch if i > 0 else 0)), (a - ch, z(a - ch) + KH), (b + ch, z(b + ch) + KH),
                  (b, z(b) + KH - ch), (b, bot)]
            p.prism(kp, "x", x0, x1, CON)
        remap(p, k0, slab_uv(TIDE_T if p is tide else TT))
        # tarred expansion-joint filler at the bottom of each gap
        if i > 0:
            geo.LEVEL = 2
            sweep(st, [(-HW - KW, -0.06), (HW + KW, -0.06), (HW + KW, -0.03), (-HW - KW, -0.03)], ya + g, ya - g, 0.0, RUST)
            geo.LEVEL = 3
    # stepped toe (two weedy steps down to the bed)
    zt = z(TOE)
    for (y0, y1, top) in ((TOE, TOE - 0.9, zt - 0.3), (TOE - 0.9, TOE - 1.7, zt - 0.6)):
        k0 = len(weed.faces)
        weed.prism([(y0, top), (y1 + ch, top), (y1, top - ch), (y1, -4.5), (y0, -4.5)], "x", -HW - KW, HW + KW, CON)
        remap(weed, k0, slab_uv(TT))

    # ---- launch rails: flat-bottom profile (foot, web, head), end stops, sole plates with clips and bolts
    head = [(-0.036, 0.148), (-0.036, 0.122), (-0.03, 0.114), (0.03, 0.114), (0.036, 0.122), (0.036, 0.148),
            (0.03, 0.16), (-0.03, 0.16)]
    head_modes = [RUST, RUST, RUST, RUST, RUST, RUST, HEAD, RUST]
    web = [(-0.009, 0.03), (0.009, 0.03), (0.009, 0.116), (-0.009, 0.116)]
    foot = [(-0.075, 0.03), (0.075, 0.03), (0.075, 0.042), (0.022, 0.056), (-0.022, 0.056), (-0.075, 0.042)]
    y_top = 0.6
    for xr in RAILS:
        sweep_slope(st, head, y_top, TOE, xr, head_modes)
        sweep_slope(st, web, y_top, TOE, xr, RUST)
        geo.LEVEL = 2
        sweep_slope(st, foot, y_top, TOE, xr, RUST)
        st.box((xr - 0.12, y_top, -0.01), (xr + 0.12, y_top + 0.25, 0.26), PAINT)        # end stop
        y = 0.3
        while y > TOE + 0.4:
            sweep(st, [(-0.17, -0.01), (0.17, -0.01), (0.17, 0.03), (-0.17, 0.03)], y + 0.12, y - 0.12, xr, RUST)
            geo.LEVEL = 1
            for sx in (-1, 1):
                sweep(st, [(sx * 0.076, 0.03), (sx * 0.11, 0.03), (sx * 0.11, 0.05), (sx * 0.076, 0.062)][::sx],
                      y + 0.05, y - 0.05, xr, RUST)
                st.prism([(xr + sx * 0.14 + 0.016 * math.cos(a + 0.4), y + 0.016 * math.sin(a + 0.4))
                          for a in [k * math.pi / 3 for k in range(6)]], "z", z(y) + 0.02, z(y) + 0.058, RUST)
            geo.LEVEL = 2
            y -= 1.5
        geo.LEVEL = 3
    # kerb nosings: steel angle on the inner top edge of each kerb
    geo.LEVEL = 2
    for xk, sx in ((-HW, -1), (HW, 1)):
        sweep_slope(st, [(0.0, KH - 0.07), (0.0, KH + 0.008), (sx * 0.06, KH + 0.008), (sx * 0.06, KH)][::sx], 3.0, TOE,
                    xk - sx * 0.008, RUST)
    geo.LEVEL = 3

    # ---- intertidal growth: barnacle encrustation at the rail feet and plates, weed clumps, joint weed
    def tide_or_weed(y):
        return tide if zone(S(y)) == "tide" else weed

    for xr in RAILS:
        y = yS(S_TOP - 0.6)
        while y > yS(S_BOT + 0.15):
            for sx in (-1, 1):
                if rnd.random() < 0.8:
                    p = tide_or_weed(y)
                    k0 = len(p.faces)
                    geo.LEVEL = 2 if rnd.random() < 0.4 else 1
                    mound(p, xr + sx * rnd.uniform(0.08, 0.13), y, rnd.uniform(0.04, 0.07), rnd.uniform(0.06, 0.14),
                          rnd.uniform(0.02, 0.045), 6, rnd, CON)
                    remap(p, k0, slab_uv(TIDE_T if p is tide else TT))
            y -= rnd.uniform(0.25, 0.45)
    geo.LEVEL = 1
    for _ in range(90):        # single barnacle cones on the plates, the rail foot and the slab near the rails
        xr = rnd.choice(RAILS)
        s = rnd.uniform(S_TOP - 1.2, S_TOP - 3.6)
        y = yS(s)
        x = xr + rnd.choice((-1, 1)) * rnd.uniform(0.08, 0.2)
        k0 = len(tide.faces)
        mound(tide, x, y, 0.012, 0.012, rnd.uniform(0.012, 0.022), 5, rnd, CON, top=0.35)
        remap(tide, k0, slab_uv(TIDE_T))
    for _ in range(26):        # weed clumps: lower band and below, along joints, kerb corners and rails
        s = rnd.uniform(S_TOP - 2.6, S(TOE) + 0.8)
        y = yS(s)
        if rnd.random() < 0.4:      # snap to a joint
            s = round(s / BAY) * BAY
            y = yS(s) - rnd.uniform(0.02, 0.1)
        x = rnd.choice((rnd.uniform(-HW + 0.1, HW - 0.1), rnd.choice((-1, 1)) * (HW - 0.08), rnd.choice(RAILS) + rnd.uniform(-0.25, 0.25)))
        p = tide_or_weed(y)
        k0 = len(p.faces)
        geo.LEVEL = 2 if rnd.random() < 0.5 else 1
        mound(p, x, y - 0.1, rnd.uniform(0.06, 0.14), rnd.uniform(0.15, 0.35), rnd.uniform(0.015, 0.04), 7, rnd, CON, top=0.6)
        remap(p, k0, slab_uv(TIDE_T if p is tide else TT))
    geo.LEVEL = 3

    # ---- winch house: coursed block walls (kit Wall rect), openings with reveals
    k0 = len(st.faces)
    fy = [(4.0, 0.0), (4.2, 0.0), (4.2, R(4.2)), (4.0, R(4.0))]
    st.prism(fy, "x", -1.5, 0.35, CON)                                               # front wall, door opening 0.35..1.25
    st.prism(fy, "x", 1.25, 1.5, CON)
    st.prism([(4.0, 2.1), (4.2, 2.1), (4.2, R(4.2)), (4.0, R(4.0))], "x", 0.35, 1.25, CON)
    st.prism([(6.8, 0.0), (7.0, 0.0), (7.0, R(7.0)), (6.8, R(6.8))], "x", -1.5, 1.5, CON)
    VY0, VY1, VZ0, VZ1 = 5.0, 5.9, 1.2, 1.85
    for x0, x1 in ((-1.5, -1.3), (1.3, 1.5)):
        st.prism([(4.2, 0.0), (VY0, 0.0), (VY0, R(VY0)), (4.2, R(4.2))], "x", x0, x1, CON)
        st.prism([(VY1, 0.0), (6.8, 0.0), (6.8, R(6.8)), (VY1, R(VY1))], "x", x0, x1, CON)
        st.prism([(VY0, 0.0), (VY1, 0.0), (VY1, VZ0), (VY0, VZ0)], "x", x0, x1, CON)
        st.prism([(VY0, VZ1), (VY1, VZ1), (VY1, R(VY1)), (VY0, R(VY0))], "x", x0, x1, CON)
    remap(st, k0, wall_uv)
    for sx in (-1, 1):
        xo = sx * 1.5
        st.box((min(xo, xo + sx * 0.06), VY0 - 0.08, VZ0 - 0.06), (max(xo, xo + sx * 0.06), VY1 + 0.08, VZ0), PAINT)  # sill
        k0 = len(st.faces)
        st.face([(sx * 1.36, VY0, VZ0), (sx * 1.36, VY1, VZ0), (sx * 1.36, VY1, VZ1), (sx * 1.36, VY0, VZ1)],
                rect("Vent", 0.9, 0.65), centre=(0, 5.5, 1.5))                      # dark backing (closes the opening)
        geo.LEVEL = 2
        if sx > 0:      # louvred vent: frame + 7 inclined blades
            for (a0, a1, b0, b1) in ((VY0, VY0 + 0.04, VZ0, VZ1), (VY1 - 0.04, VY1, VZ0, VZ1),
                                     (VY0, VY1, VZ0, VZ0 + 0.04), (VY0, VY1, VZ1 - 0.04, VZ1)):
                st.box((1.38, a0, b0), (1.47, a1, b1), PAINT)
            geo.LEVEL = 1
            for k in range(7):
                zc = VZ0 + 0.08 + k * 0.083
                st.prism([(1.38, zc - 0.035), (1.40, zc - 0.04), (1.47, zc + 0.03), (1.45, zc + 0.035)], "y",
                         VY0 + 0.04, VY1 - 0.04, PAINT)
        else:           # barred window: frame + 5 vertical bars
            for (a0, a1, b0, b1) in ((VY0, VY0 + 0.05, VZ0, VZ1), (VY1 - 0.05, VY1, VZ0, VZ1),
                                     (VY0, VY1, VZ0, VZ0 + 0.05), (VY0, VY1, VZ1 - 0.05, VZ1)):
                st.box((-1.45, a0, b0), (-1.38, a1, b1), PAINT)
            geo.LEVEL = 1
            for k in range(5):
                yb = VY0 + 0.15 + k * 0.15
                st.tube((-1.42, yb, VZ0 + 0.04), (-1.42, yb, VZ1 - 0.04), 0.012, 6, PAINT, caps=False)
        geo.LEVEL = 3
    # door: steel frame in the reveal, recessed panelled leaf, lever handle, threshold step
    DX0, DX1, DZ0, DZ1 = 0.41, 1.19, 0.02, 2.04
    st.box((0.35, 3.98, 0.0), (0.41, 4.2, 2.1), PAINT)
    st.box((1.19, 3.98, 0.0), (1.25, 4.2, 2.1), PAINT)
    st.box((0.35, 3.98, 2.04), (1.25, 4.2, 2.1), PAINT)
    k0 = len(st.faces)
    st.box((DX0, 4.06, DZ0), (DX1, 4.1, DZ1), CON)
    geo.LEVEL = 1
    for (za, zb) in ((0.15, 0.9), (1.1, 1.85)):
        for (xa, xb) in ((0.07, 0.42), (0.48, 0.83)):
            st.box((DX0 + xa / 0.9 * 0.78, 4.05, DZ0 + za / 2.0 * 2.02), (DX0 + xb / 0.9 * 0.78, 4.06, DZ0 + zb / 2.0 * 2.02), CON,
                   skip=("+y",))
    remap(st, k0, planar("Door", (DX0, 4.0, DZ0), (DX1, 4.1, DZ1)))
    hx, hz = DX0 + 0.78 / 0.9 * 0.78, 1.03
    st.box((hx - 0.025, 4.045, hz - 0.11), (hx + 0.025, 4.06, hz + 0.11), PAINT)     # back plate
    st.box((hx - 0.13, 3.99, hz - 0.012), (hx + 0.012, 4.012, hz + 0.012), PAINT)  # lever
    st.box((hx - 0.01, 4.012, hz - 0.01), (hx + 0.01, 4.045, hz + 0.01), PAINT)    # spindle
    geo.LEVEL = 3
    con.box((0.25, 3.6, 0.0), (1.35, 4.0, 0.12), CON, skip=("-z",))
    # corrugated roof: base sheet + ribs (100 mm pitch), fascia, verges, gutter, downpipe
    sweep(st, [(-1.7, -0.012), (1.7, -0.012), (1.7, 0.012), (-1.7, 0.012)], 7.2, 3.8, 0.0, ROOF, zf=R)
    geo.LEVEL = 2
    rib = [(-0.03, 0.012), (0.03, 0.012), (0.012, 0.034), (-0.012, 0.034)]
    for i in range(34):
        sweep(st, rib, 7.2, 3.8, -1.65 + i * 0.1, ROOF, zf=R)
    for yb in (3.8, 7.2):
        st.box((-1.72, yb - 0.025 if yb < 5 else yb, R(yb) - 0.16), (1.72, yb if yb < 5 else yb + 0.025, R(yb) + 0.01), PAINT)
    for sx in (-1, 1):
        sweep(st, [(0.0, -0.16), (sx * 0.025, -0.16), (sx * 0.025, 0.05), (0.0, 0.05)][::sx], 7.225, 3.775, sx * 1.7, PAINT, zf=R)
    gz = R(3.8) - 0.12
    st.box((-1.72, 3.66, gz - 0.07), (1.72, 3.665, gz + 0.03), PAINT)
    st.box((-1.72, 3.665, gz - 0.07), (1.72, 3.775, gz - 0.065), PAINT)
    geo.LEVEL = 1
    for xe in (-1.72, 1.72):
        st.box((xe - 0.005, 3.66, gz - 0.07), (xe + 0.005, 3.775, gz + 0.03), PAINT)
    geo.LEVEL = 2
    st.tube((-1.42, 3.72, gz - 0.06), (-1.42, 3.72, 0.25), 0.04, 8, PAINT)
    st.tube((-1.42, 3.72, 0.25), (-1.42, 3.55, 0.08), 0.04, 8, PAINT)                    # shoe
    geo.LEVEL = 1
    for zc in (0.6, 1.4, 2.1):
        st.box((-1.46, 3.76, zc - 0.02), (-1.38, 4.0, zc + 0.02), PAINT)                  # pipe brackets
    geo.LEVEL = 3

    # ---- winch: drum with flanges, side frames, motor box, wire to a hook block; bollards on the apron
    st.tube((-0.6, 2.8, 0.6), (0.6, 2.8, 0.6), 0.26, 14, RUST)
    geo.LEVEL = 2
    for xf in (-0.63, 0.63):
        st.tube((xf - 0.03, 2.8, 0.6), (xf + 0.03, 2.8, 0.6), 0.36, 14, PAINT)
    st.tube((-0.85, 2.8, 0.6), (0.85, 2.8, 0.6), 0.05, 8, PAINT)
    geo.LEVEL = 3
    for xf in (-0.78, 0.78):
        st.prism([(2.35, 0.0), (3.25, 0.0), (2.95, 0.95), (2.65, 0.95)], "x", xf - 0.05, xf + 0.05, PAINT)
        geo.LEVEL = 2
        st.box((xf - 0.12, 2.3, 0.0), (xf + 0.12, 3.3, 0.06), PAINT)
        geo.LEVEL = 3
    k0 = len(st.faces)
    st.box((0.9, 2.45, 0.0), (1.45, 3.15, 0.7), CON)
    remap(st, k0, planar("Plate", (0.9, 2.45, 0.0), (1.45, 3.15, 0.7)))
    geo.LEVEL = 2
    st.tube((0.85, 2.8, 0.6), (0.9, 2.8, 0.6), 0.12, 10, PAINT)
    geo.LEVEL = 3
    st.tube((0.0, 2.55, 0.36), (0.0, 0.2, 0.08), 0.014, 6, RUST, caps=False)
    st.tube((0.0, 0.2, 0.08), (0.0, -3.0, z(-3.0) + 0.2), 0.014, 6, RUST, caps=False)
    st.box((-0.1, -3.3, z(-3.3) + 0.0), (0.1, -3.0, z(-3.0) + 0.22), PAINT)
    geo.LEVEL = 2
    st.tube((0.0, -3.3, z(-3.3) + 0.1), (0.0, -3.48, z(-3.48) + 0.1), 0.045, 8, RUST)
    geo.LEVEL = 3
    for xb in (-2.9, 2.9):
        st.tube((xb, 2.0, 0.0), (xb, 2.0, 0.55), 0.13, 12, PAINT)
        st.tube((xb, 2.0, 0.55), (xb, 2.0, 0.62), 0.17, 12, PAINT)
        geo.LEVEL = 2
        st.tube((xb, 2.0, 0.0), (xb, 2.0, 0.05), 0.2, 12, PAINT)
        geo.LEVEL = 3

    mats = {"Ramp": ("Concrete", geo.material("MI_Slipway_Concrete", (0.35, 0.34, 0.32), 0.9)),
            "Weedy": ("WeedyConcrete", geo.material("MI_Slipway_Weedy", (0.2, 0.22, 0.17), 0.8)),
            "Tide": ("Tide", geo.material("MI_Slipway_Tide", (0.26, 0.26, 0.22), 0.6)),
            "Steel": ("Steel", geo.material("MI_Slipway_Steel", (0.3, 0.27, 0.24), 0.8, 0.0))}
    meshes = []
    for p in (con, tide, weed, st):
        s, mat = mats[p.name]
        for li, lod in ((0, "LOD0"), (1, "LOD1"), (2, "LOD2")):
            meshes.append({"object": p.to_object("%s_%s_%s" % (NAME, p.name, lod), mat, lod=li), "set": s})
        print("[H1] %s %d tris (LOD0 faces)" % (p.name, p.tris()))
    col = Part("COL")
    col.prism([(7.0, 0.0), (0.0, 0.0), (TOE, z(TOE)), (TOE, -4.5), (7.0, -4.5)], "x", -HW - KW, HW + KW, CON)
    col.box((-1.5, 4.0, 0.0), (1.5, 7.0, 3.1), CON)
    colobj = col.to_object(NAME + "_COL", None, weld=False)
    atts = {"ATT_SlipwayTop": (0, 0, 0), "ATT_SlipwayBottom": (0, -RUN, -DROP), "ATT_WaterLine": (0, -1.333 / K, -1.333),
            "ATT_WeedLine": (0, SPLIT, z(SPLIT)), "ATT_Winch": (0, 2.8, 0.6), "ATT_WinchHouseDoor": (0.8, 3.5, 0)}
    objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = Vector(p) * 3.0
        bpy.context.scene.collection.objects.link(e)
        objs.append(e)
    tex = G + "assets/textures/"
    yr = yS(-7.0)
    return {
        "name": NAME, "budget": "large_prop", "tris": 8000, "tier": "hero",
        "dims_m": (2 * (HW + KW), None, None), "origin": "free", "tiling": True,
        "sets": [{"name": "Mat", "set": "Concrete", "size": 1024, "wet": True, "dir": tex + "Materials"},
                 {"name": "Mat", "set": "WeedyConcrete", "size": 1024, "wet": True, "dir": tex + "Materials"},
                 {"name": "Slipway", "set": "Tide", "size": 1024, "wet": True},
                 {"name": "Slipway", "set": "Steel", "size": 1024, "wet": True}],
        "waivers": {"texture sets": "2 own sets inside the large_prop (1, 2) budget: Steel (kit atlas: rails, winch, winch "
                                    "house walls / door / vent / roof) and Tide (the intertidal band, which has to be its own "
                                    "tiling set to blend the two shared sets seamlessly); Concrete and WeedyConcrete are the "
                                    "shared B02 library sets (docs/12 row, no new texture budget)",
                    "LOD UV layout": "world-scale tiling UVs; hand-made LODs drop small parts"},
        "meshes": meshes + [{"object": colobj}],
        "attachments": objs,
        "closeups": [
            {"name": "tide_line", "target": [0.4 * 3, SPLIT * 3, z(SPLIT) * 3], "dist": 11, "az": 25, "el": 28},
            {"name": "rail_base", "target": [0.75 * 3, yr * 3, (z(yr) + 0.08) * 3], "dist": 4.5, "az": 55, "el": 30},
            {"name": "winch_house_door", "target": [0.6 * 3, 4.0 * 3, 1.2 * 3], "dist": 9, "az": 20, "el": 10},
            {"name": "winch_house_vent", "target": [1.5 * 3, 5.5 * 3, 1.6 * 3], "dist": 8, "az": 70, "el": 12},
            {"name": "head_winch_rails", "target": [0, 1.0 * 3, 1.5], "dist": 10, "az": 150, "el": 30},
        ],
    }
