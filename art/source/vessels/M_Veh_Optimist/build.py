"""C1 M_Veh_Optimist: Barnaby's *The Optimist*, the casualty vessel of Operation 2 (Disabled Vessel). A generic
well-used 7 m GRP inshore fishing / leisure boat (Cornish / Orkney-style hard-chine displacement hull, not a replica):
small walk-in wheelhouse amidships, foredeck with a timber samson post, two bow cleats and a stainless pulpit (the three
tow strong-point choices of Mechanics/Tow/Procedures: samson | bridle to both cleats | one cleat | rail), open aft
cockpit with stern cleats, a tiller outboard on the transom (rusty, corroded leg), stowed fenders, fish box, fuel tank,
rope coil and a rope trailing over the stern towards the propeller (the Op 2 assessment hazard; own MeshPart).

Blender axes: X width (+X = port, since Roblox = (-bx, bz, by)), Y length (bow -Y = Roblox -Z, like the greybox
BowPoint), Z up; pivot = centre of the base (keel bottom). Waterline ATT_Waterline (0.62 m).
MeshParts / sets: Hull (shell, transom, liner, keel; T_Optimist_Hull), Cabin (wheelhouse walls; T_Optimist_Hull),
Deck (foredeck, cockpit sole, wheelhouse roof, console; T_Optimist_Deck), Fittings (strakes, pulpit, cleats, roller,
anchor, glass, mast, wheel, seat, name boards, fish box, tank, rope coil, stowed fenders; T_Optimist_Fittings),
SamsonPost (hide when the scenario's bow = "cleats"), Outboard, TrailingRope (hide when trailingRope = false).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C1"))
import c1geo as K  # noqa: E402
from c1geo import Buf, V, W, C  # noqa: E402

NAME = "M_Veh_Optimist"
BUDGET, BUDGET_TRIS = "rib", 25000          # docs/12 row: 25,000 / 10,000 / 2,500, 3 sets (rib class ceilings)
SETS = {"name": "Optimist", "sets": ("Hull", "Deck", "Fittings"),
        "map": {"Hull": "Hull", "Cabin": "Hull", "Deck": "Deck", "Fittings": "Fittings", "SamsonPost": "Fittings",
                "Outboard": "Fittings", "TrailingRope": "Fittings"}}
FB = {"steel": (0.000, 0.125), "wood": (0.125, 0.250), "rubber": (0.250, 0.375), "fender": (0.375, 0.500),
      "rope": (0.500, 0.625), "outboard": (0.625, 0.750), "orange": (0.750, 0.875), "glass": (0.875, 1.000)}
band = K.bandfn(FB)
L, WL, SOLE, HU = 6.30, 0.62, 0.86, 3.5      # hull length, waterline, cockpit sole, hull U tile (m)
GL = (0.0, 0.30)          # glass, name and PLN rects in the top Fittings band (U ranges)
NM = (0.30, 0.78)
PLN = (0.78, 1.00)
TW = 0.30                 # wheelhouse front station
TA = 0.57                 # wheelhouse back station


def Y(t):
    return -L / 2 + t * L


def bb(t):
    if t < 0.55:
        return 0.04 + 1.13 * math.sin(min(t / 0.55, 1.0) * math.pi / 2) ** 0.8
    return 1.17 - 0.13 * ((t - 0.55) / 0.45) ** 1.6


def zs(t):
    return 1.12 + 0.50 * (1 - t) ** 1.6


def zk(t):
    return 0.20 + (0.92 * ((0.24 - t) / 0.24) ** 2 if t < 0.24 else 0.0)


def zc(t):
    return min(zk(t) + 0.28, zk(t) + (zs(t) - zk(t)) * 0.45)


def hp(t, s):
    """Port hull point at station t (0 bow .. 1 transom), girth s (0 keel .. 1 sheer)."""
    b, k, c = bb(t), zk(t), zc(t)
    bc = 0.80 * b
    if s <= 0.42:
        u = s / 0.42
        return V(bc * u, Y(t), k + (c - k) * u ** 1.25)
    u = (s - 0.42) / 0.58
    return V(bc + (b - bc) * math.sin(u * math.pi / 2) ** 0.6, Y(t), c + (zs(t) - c) * u)


def hx(t, z):
    """Hull half-width at height z (above the chine)."""
    c = zc(t)
    u = max(0.0, min(1.0, (z - c) / max(zs(t) - c, 1e-4)))
    return hp(t, 0.42 + 0.58 * u).x


def hv(z):
    """Hull set V: 0 at the base .. 0.5 at the waterline .. 0.95 at the sheer (1.62 m)."""
    if z <= WL:
        return 0.5 * max(z, 0.0) / WL
    return min(0.5 + 0.45 * (z - WL) / (1.62 - WL), 0.97)


def zd(t):
    return zs(t) - 0.10 if t < TW else SOLE


def xin(t, z=None):
    return hx(t, zd(t) if z is None else z) - 0.05


def axis_out(c):
    return V(c.x, 0, c.z - 0.9)


def stations(n, a=0.0, b=1.0):
    return [a + (b - a) * 0.5 * (1 - math.cos(math.pi * i / n)) for i in range(n + 1)]


# ------------------------------------------------------------------ hull shell, transom, liner, keel
def build_hull():
    b = Buf()
    ts = stations(34)
    ss = [j / 14 for j in range(15)]
    for side in (1, -1):
        rows, uvs = [], []
        for t in ts:
            pr = [hp(t, s) for s in ss]
            rows.append([V(side * p.x, p.y, p.z) for p in pr])
            uvs.append([((p.y + L / 2) / HU, hv(p.z)) for p in pr])
        K.ogrid(b, rows, uvs, axis_out)
    # stem: close the 4 cm gap between the two sides at t = 0
    for j in range(14):
        p0, p1 = hp(0, ss[j]), hp(0, ss[j + 1])
        quad = [V(-p0.x, p0.y, p0.z), V(p0.x, p0.y, p0.z), V(p1.x, p1.y, p1.z), V(-p1.x, p1.y, p1.z)]
        K.oface(b, quad, [(0.0, hv(q.z)) if q.x < 0 else (0.02, hv(q.z)) for q in quad], (0, -1, 0))
    # transom (flat, raked a touch) outside + inside face above the sole
    for j in range(14):
        p0, p1 = hp(1, ss[j]), hp(1, ss[j + 1])
        quad = [V(-p0.x, p0.y, p0.z), V(p0.x, p0.y, p0.z), V(p1.x, p1.y, p1.z), V(-p1.x, p1.y, p1.z)]
        K.oface(b, quad, [((q.x + 1.2) / HU, hv(q.z)) for q in quad], (0, 1, 0))
    yt = L / 2 - 0.05
    tin = [V(-xin(1), yt, SOLE), V(xin(1), yt, SOLE), V(xin(1, zs(1)), yt, zs(1)), V(-xin(1, zs(1)), yt, zs(1))]
    K.oface(b, tin, [((q.x + 1.2) / HU, 0.80 + 0.14 * (q.z - SOLE) / (zs(1) - SOLE)) for q in tin], (0, -1, 0))
    # liner (inside of the topsides above the deck) and the gunwale capping, each side
    tl = [t for t in stations(30, 0.03, 1.0)]
    tl = sorted(set(tl + [TW, TW + 1e-4]))
    for side in (1, -1):
        rows, uvs, cap, cuv = [], [], [], []
        for t in tl:
            zb = zs(t) - 0.10 if t <= TW else SOLE
            r, u = [], []
            for k in range(3):
                z = zb + (zs(t) - zb) * k / 2
                r.append(V(side * xin(t, z), Y(t), z))
                u.append(((Y(t) + L / 2) / HU, 0.80 + 0.14 * k / 2))
            rows.append(r)
            uvs.append(u)
            top = zs(t)
            cap.append([V(side * hx(t, top), Y(t), top), V(side * xin(t, top), Y(t), top)])
            cuv.append([((Y(t) + L / 2) / HU, 0.955), ((Y(t) + L / 2) / HU, 0.965)])
        K.ogrid(b, rows, uvs, lambda c: V(-c.x, 0, 0))
        K.ogrid(b, cap, cuv, (0, 0, 1))
    # keel / skeg
    q = [V(0.04, Y(0.24), 0.30), V(0.04, Y(0.33), 0.0), V(0.04, Y(0.93), 0.0), V(0.04, Y(0.97), 0.20)]
    K.slab(b, q, 0.08, lambda p: ((p.y + L / 2) / HU, hv(p.z)), out=(1, 0, 0))
    return b


# ------------------------------------------------------------------ decks
def build_deck():
    b = Buf()
    ts = [t for t in stations(10, 0.02, TW)] + [t for t in stations(16, TW, 1.0)]
    rows, uvs = [], []
    for i, t in enumerate(ts):
        fore = i <= 10
        z0 = zs(t) - 0.10 if fore else SOLE
        w = xin(t, z0)
        r = []
        for j in range(9):
            x = -w + 2 * w * j / 8
            z = z0 + (0.04 * (1 - (x / max(w, 1e-3)) ** 2) if fore else 0.0)
            r.append(V(x, Y(t) if i != 11 else Y(t) + 1e-4, z))
        rows.append(r)
        uvs.append([(p.x / 2.5, (p.y + p.z) / 2.5) for p in r])
    K.ogrid(b, rows, uvs, lambda c: V(0, -1, 2), smooth=False)
    # wheelhouse roof (cambered slab with overhang)
    y0, y1 = Y(TW), Y(TA)
    K.slab(b, [V(-0.92, y0 + 0.10, 2.76), V(0.92, y0 + 0.10, 2.76), V(0.92, y1 + 0.14, 2.76), V(-0.92, y1 + 0.14, 2.76)], 0.07,
           lambda p: (p.x / 2.5, (p.y + p.z) / 2.5), out=(0, 0, 1))
    # helm console + chart shelf
    K.slab(b, [V(-0.78, y0 + 0.30, 1.42), V(0.78, y0 + 0.30, 1.42), V(0.78, y0 + 0.62, 1.42), V(-0.78, y0 + 0.62, 1.42)], 0.56,
           lambda p: (p.x / 2.5, (p.y + p.z) / 2.5), out=(0, 0, 1))
    K.slab(b, [V(-0.78, y0 + 0.30, 1.42), V(0.78, y0 + 0.30, 1.42), V(0.78, y0 + 0.12, 1.66), V(-0.78, y0 + 0.12, 1.66)], 0.04,
           lambda p: (p.x / 2.5, (p.y + p.z) / 2.5), out=(0, 1, 1))
    # helm seat box and engine box seat in the cockpit
    K.slab(b, [V(0.12, y0 + 1.00, 1.30), V(0.62, y0 + 1.00, 1.30), V(0.62, y0 + 1.40, 1.30), V(0.12, y0 + 1.40, 1.30)], 0.44,
           lambda p: (p.x / 2.5, (p.y + p.z) / 2.5), out=(0, 0, 1))
    return b


# ------------------------------------------------------------------ wheelhouse walls
def build_cabin():
    b = Buf()
    y0, y1 = Y(TW), Y(TA)
    zt, ztop = 2.70, 2.70
    uv_s = lambda p: ((p.y + L / 2) / HU, 0.80 + 0.14 * (p.z - SOLE) / (zt - SOLE))
    uv_f = lambda p: ((p.x + 1.2) / HU, 0.80 + 0.14 * (p.z - SOLE) / (zt - SOLE))
    zf = zs(TW) - 0.10
    K.slab(b, [V(-0.85, y0, zf), V(0.85, y0, zf), V(0.80, y0 + 0.18, ztop), V(-0.80, y0 + 0.18, ztop)], 0.045, uv_f, out=(0, -1, 0.1))
    for sx in (1, -1):
        K.slab(b, [V(sx * 0.85, y0, SOLE), V(sx * 0.85, y1, SOLE), V(sx * 0.80, y1, ztop), V(sx * 0.80, y0 + 0.18, ztop)], 0.045,
               uv_s, out=(sx, 0, 0))
        # back wall either side of the door
        K.slab(b, [V(sx * 0.36, y1, SOLE), V(sx * 0.84, y1, SOLE), V(sx * 0.80, y1, ztop), V(sx * 0.36, y1, ztop)], 0.045, uv_f,
               out=(0, 1, 0))
    K.slab(b, [V(-0.36, y1, 2.42), V(0.36, y1, 2.42), V(0.36, y1, ztop), V(-0.36, y1, ztop)], 0.045, uv_f, out=(0, 1, 0))
    return b


def glass_quad(b, pts, out, u=GL):
    v0, v1 = FB["glass"][0] + 0.006, FB["glass"][1] - 0.006
    K.oface(b, pts, [(u[0] + 0.01, v0), (u[1] - 0.01, v0), (u[1] - 0.01, v1), (u[0] + 0.01, v1)], out)


def board(b, pts, out, u, smooth=False):
    v0, v1 = FB["glass"][0] + 0.006, FB["glass"][1] - 0.006
    K.oface(b, pts, [(u[0], v0), (u[1], v0), (u[1], v1), (u[0], v1)], out, smooth)


def cleat(b, x, y, z, along=(0, 1, 0), s=1.0):
    ax = V(*along).normalized()
    sd = ax.cross(V(0, 0, 1)).normalized()
    c = V(x, y, z)
    for k in (-0.06, 0.06):
        p = c + ax * k * s
        C.tube(b, [p, p + V(0, 0, 0.055 * s)], 0.018 * s, band("steel", 0.5), sides=6)
    C.tube(b, [c - ax * 0.13 * s + V(0, 0, 0.05 * s), c - ax * 0.07 * s + V(0, 0, 0.065 * s), c + ax * 0.07 * s + V(0, 0, 0.065 * s),
               c + ax * 0.13 * s + V(0, 0, 0.05 * s)], 0.016 * s, band("steel", 0.5), sides=6)


def fender(b, centre, axis, length=0.55, r=0.105):
    """Cylindrical fender with rounded ends and an eye at each end, lying along `axis`."""
    import mathutils
    prof = [(0.0, 0.0), (r * 0.55, 0.012), (r * 0.9, 0.04), (r, 0.09), (r, length - 0.09), (r * 0.9, length - 0.04),
            (r * 0.55, length - 0.012), (0.0, length)]
    tb = Buf()
    C.lathe_strip(tb, prof, 14, FB["fender"][0] + 0.004, FB["fender"][1] - 0.004, 1)
    C.tube(tb, [V(0, 0, -0.03), V(0, 0, 0.01)], 0.022, band("fender", 0.3), sides=6)
    C.tube(tb, [V(0, 0, length - 0.01), V(0, 0, length + 0.03)], 0.022, band("fender", 0.3), sides=6)
    rot = V(0, 0, 1).rotation_difference(V(*axis).normalized()).to_matrix().to_4x4()
    M = mathutils.Matrix.Translation(V(*centre)) @ rot @ mathutils.Matrix.Translation((0, 0, -length / 2))
    b.extend(tb, M)


# ------------------------------------------------------------------ fittings (one part)
def build_fittings():
    b = Buf()
    # rubbing strakes along the sheer (black rubber D-section) and a lower rub rail aft
    ts = stations(28, 0.0, 1.0)
    for side in (1, -1):
        pts = [V(side * (hx(t, zs(t) - 0.05) + 0.025), Y(t), zs(t) - 0.05) for t in ts]
        W.sweep(b, pts, W.rect_profile(0.05, 0.08, 0.015), band("rubber", 1.0), smooth=True)
    # pulpit (stainless bow rail): top rail and mid rail, stanchions
    for hgt, r in ((0.58, 0.0125), (0.30, 0.010)):
        tr = stations(10, 0.03, 0.27)
        pts = [V(xin(t) - 0.03, Y(t), zd(t) + hgt) for t in reversed(tr)] + [V(0, Y(0.0) - 0.04, zd(0.03) + hgt)] + \
              [V(-(xin(t) - 0.03), Y(t), zd(t) + hgt) for t in tr]
        C.tube(b, pts, r, band("steel", 1.0), sides=6, caps=(True, True))
    for t in (0.06, 0.16, 0.27):
        for side in (1, -1):
            x = side * (xin(t) - 0.03)
            C.tube(b, [V(x, Y(t), zd(t) - 0.01), V(x, Y(t), zd(t) + 0.58)], 0.012, band("steel", 1.0), sides=6)
            K.slab(b, [V(x - 0.04, Y(t) - 0.04, zd(t) + 0.01), V(x + 0.04, Y(t) - 0.04, zd(t) + 0.01),
                       V(x + 0.04, Y(t) + 0.04, zd(t) + 0.01), V(x - 0.04, Y(t) + 0.04, zd(t) + 0.01)], 0.02,
                   lambda p: (p.x, FB["steel"][0] + 0.06 + p.y * 0.2), out=(0, 0, 1))
    # bow cleats, stern cleats
    for side in (1, -1):
        cleat(b, side * (xin(0.16) - 0.10), Y(0.16), zd(0.16) + 0.015, (0.25 * side, 1, 0))
        cleat(b, side * (hx(0.93, zs(0.93)) - 0.03), Y(0.93), zs(0.93), (0, 1, 0), 0.9)
        cleat(b, side * (hx(0.62, zs(0.62)) - 0.03), Y(0.62), zs(0.62), (0, 1, 0), 0.8)   # midship spring cleats
    # bow roller, fairlead plate and anchor (galvanised plough) with chain to the deck pipe
    zst = zs(0.0)
    K.slab(b, [V(-0.07, Y(0.0) + 0.30, zst + 0.01), V(0.07, Y(0.0) + 0.30, zst + 0.01), V(0.07, Y(0.0) - 0.16, zst + 0.01),
               V(-0.07, Y(0.0) - 0.16, zst + 0.01)], 0.02, lambda p: (p.y, FB["steel"][0] + 0.06 + p.x * 0.3), out=(0, 0, 1))
    for sx in (-0.065, 0.065):
        K.slab(b, [V(sx, Y(0.0) - 0.16, zst), V(sx, Y(0.0) + 0.05, zst), V(sx, Y(0.0) + 0.05, zst + 0.10),
                   V(sx, Y(0.0) - 0.16, zst + 0.10)], 0.012, lambda p: (p.y, FB["steel"][0] + 0.03 + p.z * 0.5), out=(1, 0, 0))
    C.tube(b, [V(-0.055, Y(0.0) - 0.12, zst + 0.05), V(0.055, Y(0.0) - 0.12, zst + 0.05)], 0.035, band("rubber", 0.3), sides=8)
    C.tube(b, [V(0, Y(0.0) + 0.30, zst + 0.05), V(0, Y(0.0) - 0.14, zst + 0.09)], 0.016, band("steel", 0.6), sides=6)
    a0 = V(0, Y(0.0) - 0.16, zst + 0.02)
    K.slab(b, [a0 + V(-0.16, -0.02, -0.02), a0 + V(0.16, -0.02, -0.02), a0 + V(0.02, -0.04, -0.30), a0 + V(-0.02, -0.04, -0.30)], 0.03,
           lambda p: (p.x, FB["steel"][0] + 0.06 + p.z * 0.25), out=(0, -1, 0))
    chain = [V(0, Y(0.0) + 0.30, zst + 0.07)] + [V(0.01 * math.sin(k), Y(0.0) + 0.30 + 0.12 * k, zd(0.02 + 0.016 * k) + 0.07 - 0.02 * k / 6)
                                                for k in range(1, 7)]
    C.tube(b, chain, 0.010, band("steel", 0.2), sides=4)
    C.tube(b, [V(0, Y(0.08), zd(0.08) + 0.04), V(0, Y(0.08), zd(0.08) - 0.01)], 0.05, band("steel", 0.4), sides=8)   # deck pipe
    # wheelhouse glass (outside + inside), name boards, mast, aerial, nav light, searchlight, wheel, wipers
    y0, y1 = Y(TW), Y(TA)
    zf = zs(TW) - 0.10

    def front_pt(x, z, off):
        k = (z - zf) / (2.70 - zf)
        return V(x * (1 - 0.06 * k), y0 + 0.18 * k + off, z)
    for xa, xb in ((-0.74, -0.04), (0.04, 0.74)):
        for off, out in ((-0.006, (0, -1, 0.1)), (0.051, (0, 1, -0.1))):
            glass_quad(b, [front_pt(xa, 1.92, off), front_pt(xb, 1.92, off), front_pt(xb, 2.56, off), front_pt(xa, 2.56, off)], out)
        C.tube(b, [front_pt((xa + xb) / 2, 1.95, -0.02), front_pt((xa + xb) / 2 + 0.22, 2.40, -0.02)], 0.007, band("rubber", 0.3), sides=4)
    for sx in (1, -1):
        def side_pt(y, z, off):
            k = (z - SOLE) / (2.70 - SOLE)
            return V(sx * (0.85 - 0.05 * k + off), y, z)
        for off, out in ((0.006, (sx, 0, 0)), (-0.051, (-sx, 0, 0))):
            glass_quad(b, [side_pt(y0 + 0.42, 1.80, off), side_pt(y1 - 0.15, 1.80, off), side_pt(y1 - 0.15, 2.52, off),
                           side_pt(y0 + 0.32, 2.52, off)], out)
        # name boards below the side windows: U runs bow -> stern on port (+X), stern -> bow on starboard
        ya, yb = (y0 + 0.25, y1 - 0.10) if sx > 0 else (y1 - 0.10, y0 + 0.25)
        board(b, [side_pt(ya, 1.36, 0.012), side_pt(yb, 1.36, 0.012), side_pt(yb, 1.62, 0.012), side_pt(ya, 1.62, 0.012)], (sx, 0, 0), NM)
    # PLN on both bows, conforming to the hull
    for sx in (1, -1):
        tA, tB = (0.09, 0.21) if sx > 0 else (0.21, 0.09)
        rows, uvs = [], []
        for k in range(5):
            t = tA + (tB - tA) * k / 4
            u = PLN[0] + (PLN[1] - PLN[0]) * k / 4
            r = []
            for zz in (zs(t) - 0.40, zs(t) - 0.16):
                r.append(V(sx * (hx(t, zz) + 0.008), Y(t), zz))
            rows.append(r)
            uvs.append([(u, FB["glass"][0] + 0.006), (u, FB["glass"][1] - 0.006)])
        K.ogrid(b, rows, uvs, (sx, 0, 0), smooth=False)
    # transom name board ("THE OPTIMIST" over the port of registry is in the same strip)
    yt = L / 2 + 0.008
    board(b, [V(0.62, yt, 0.84), V(-0.62, yt, 0.84), V(-0.62, yt, 1.02), V(0.62, yt, 1.02)], (0, 1, 0), NM)
    mx, my = 0.0, y1 - 0.25
    C.tube(b, [V(mx, my, 2.76), V(mx, my, 3.50)], 0.028, band("steel", 0.5), sides=8)
    C.tube(b, [V(mx, my, 3.50), V(mx, my, 3.60)], 0.045, band("rubber", 0.3), sides=8)          # all-round light
    C.tube(b, [V(mx - 0.25, my, 3.20), V(mx + 0.25, my, 3.20)], 0.015, band("steel", 0.5), sides=6)  # cross-tree
    C.tube(b, [V(0.62, y1 - 0.10, 2.76), V(0.62, y1 - 0.10, 3.95)], 0.009, band("rubber", 0.2), sides=4)  # VHF whip
    C.tube(b, [V(-0.55, y0 + 0.35, 2.80), V(-0.55, y0 + 0.35, 2.92)], 0.03, band("steel", 0.3), sides=6)
    C.tube(b, [V(-0.55, y0 + 0.30, 2.95), V(-0.55, y0 + 0.48, 2.95)], 0.07, band("steel", 0.3), sides=10)   # searchlight
    wc = V(0.36, y0 + 0.66, 1.72)
    W.ring(b, wc, (1, 0, 0), (0, 0.5, 0.86), 0.19, 0.014, 18, 5, band("rubber", 1.0))   # wheel
    C.tube(b, [wc, wc + V(0, -0.14, -0.08)], 0.02, band("steel", 0.3), sides=6)
    for k in range(3):
        a = 2 * math.pi * k / 3
        C.tube(b, [wc, wc + V(0.18 * math.cos(a), 0.09 * math.sin(a), 0.155 * math.sin(a))], 0.008, band("steel", 0.3), sides=4)
    # helm seat cushion (on the Deck seat box) and the throttle box
    K.slab(b, [V(0.14, y0 + 1.02, 1.36), V(0.60, y0 + 1.02, 1.36), V(0.60, y0 + 1.38, 1.36), V(0.14, y0 + 1.38, 1.36)], 0.06,
           lambda p: (p.y * 2, FB["rubber"][0] + 0.01 + (p.x + 1) * 0.05), out=(0, 0, 1))
    # cockpit: fish box, fuel tank (+ fuel line), rope coil, two stowed fenders on the sole, a bucket
    ob = lambda p: ((p.x + p.y) * 1.2, FB["orange"][0] + 0.006 + 0.11 * min(max((p.z - SOLE) / 0.35, 0), 1))
    K.slab(b, [V(-0.80, Y(0.68), SOLE + 0.32), V(-0.20, Y(0.68), SOLE + 0.32), V(-0.20, Y(0.80), SOLE + 0.32),
               V(-0.80, Y(0.80), SOLE + 0.32)], 0.32, ob, out=(0, 0, 1))
    K.slab(b, [V(0.42, Y(0.88), SOLE + 0.27), V(0.78, Y(0.88), SOLE + 0.27), V(0.78, Y(0.95), SOLE + 0.27),
               V(0.42, Y(0.95), SOLE + 0.27)], 0.27, ob, out=(0, 0, 1))
    C.tube(b, [V(0.60, Y(0.91), SOLE + 0.28), V(0.58, Y(0.91), SOLE + 0.32)], 0.025, band("rubber", 0.2), sides=6)
    C.tube(b, C.catenary(V(0.58, Y(0.92), SOLE + 0.30), V(0.10, L / 2 + 0.10, 1.22), 0.25, 8), 0.008, band("rubber", 0.5), sides=4)
    for k in range(4):
        W.ring(b, (0.35, Y(0.74), SOLE + 0.018 + 0.03 * k), (1, 0, 0), (0, 1, 0), 0.19 - 0.012 * k, 0.014, 16, 4, band("rope", 1.0))
    for sx in (1, -1):
        fender(b, (sx * 0.80, Y(0.70) if sx > 0 else Y(0.84), SOLE + 0.11), (0, 1, 0.04))
    C.tube(b, [V(-0.30, Y(0.92), SOLE), V(-0.30, Y(0.92), SOLE + 0.28)], 0.13, band("orange", 0.6), sides=10, caps=(True, False))
    return b


def build_samson():
    b = Buf()
    t = 0.10
    c = V(0, Y(t), zd(t) + 0.03)
    w = 0.07
    wd = lambda p: ((p.z - c.z) * 1.5 + (p.x + p.y) * 0.4, FB["wood"][0] + 0.01 + 0.10 * ((p.x + p.y * 0.7) % 1.0))
    K.slab(b, [c + V(-w, -w, 0.46), c + V(w, -w, 0.46), c + V(w, w, 0.46), c + V(-w, w, 0.46)], 0.48, wd, out=(0, 0, 1))
    C.tube(b, [c + V(-0.19, 0, 0.36), c + V(0.19, 0, 0.36)], 0.016, band("steel", 0.4), sides=6)       # norman pin
    K.slab(b, [c + V(-w - 0.01, -w - 0.01, 0.475), c + V(w + 0.01, -w - 0.01, 0.475), c + V(w + 0.01, w + 0.01, 0.475),
               c + V(-w - 0.01, w + 0.01, 0.475)], 0.02, lambda p: (p.x, FB["steel"][0] + 0.06 + p.y * 0.3), out=(0, 0, 1))
    K.slab(b, [c + V(-0.11, -0.11, 0.02), c + V(0.11, -0.11, 0.02), c + V(0.11, 0.11, 0.02), c + V(-0.11, 0.11, 0.02)], 0.02,
           lambda p: (p.x, FB["steel"][0] + 0.06 + p.y * 0.3), out=(0, 0, 1))
    return b, c


def build_outboard():
    b = Buf()
    yt = L / 2
    zt = zs(1.0)
    up = (FB["outboard"][0] + 0.004 + 0.0625, FB["outboard"][1] - 0.004)      # cowl paint (upper half of the band)
    lo = (FB["outboard"][0] + 0.004, FB["outboard"][0] + 0.058)               # corroded leg (lower half)
    UP, LO = ("strip", up[0], up[1], 0.6), ("strip", lo[0], lo[1], 0.6)
    # transom clamp bracket + swivel
    K.slab(b, [V(-0.14, yt + 0.005, zt + 0.06), V(0.14, yt + 0.005, zt + 0.06), V(0.14, yt + 0.005, zt - 0.22),
               V(-0.14, yt + 0.005, zt - 0.22)], 0.06, lambda p: ((p.x + p.z) * 1.4, lo[0] + 0.004 + 0.05 * ((p.z - 0.8) % 1.0)),
           out=(0, -1, 0))
    for sx in (-0.10, 0.10):
        C.tube(b, [V(sx, yt - 0.10, zt + 0.04), V(sx, yt - 0.10, zt - 0.10)], 0.018, band("steel", 0.3), sides=6)   # clamp screws
        C.tube(b, [V(sx - 0.05, yt - 0.10, zt - 0.10), V(sx + 0.05, yt - 0.10, zt - 0.10)], 0.012, band("steel", 0.3), sides=4)
    K.slab(b, [V(-0.11, yt + 0.07, 0.70), V(0.11, yt + 0.07, 0.70), V(0.11, yt + 0.07, zt + 0.02), V(-0.11, yt + 0.07, zt + 0.02)],
           0.20, lambda p: ((p.x + p.z) * 1.4, lo[0] + 0.004 + 0.05 * ((p.y * 2) % 1.0)), out=(0, -1, 0))
    # cowl: rounded box swept along Y, tapered at the back, a lower pan
    cy = [yt - 0.06, yt + 0.02, yt + 0.30, yt + 0.48, yt + 0.55]
    W.sweep(b, [V(0, y, zt + 0.30) for y in cy], W.rect_profile(0.40, 0.42, 0.10), UP, scale=[0.80, 0.97, 1.0, 0.92, 0.72],
            smooth=True)
    W.sweep(b, [V(0, y, zt + 0.06) for y in (yt - 0.04, yt + 0.25, yt + 0.50)], W.rect_profile(0.36, 0.10, 0.03), LO,
            scale=[0.85, 1.0, 0.85], smooth=True)
    # leg, anti-cavitation plate, gearcase torpedo, skeg, 3-blade propeller
    W.sweep(b, [V(0, yt + 0.26, 0.74), V(0, yt + 0.26, 0.24)], W.rect_profile(0.09, 0.24, 0.035), LO, up_hint=(0, 1, 0), smooth=True)
    K.slab(b, [V(-0.17, yt + 0.10, 0.42), V(0.17, yt + 0.10, 0.42), V(0.17, yt + 0.46, 0.42), V(-0.17, yt + 0.46, 0.42)], 0.012,
           lambda p: (p.x * 1.6, lo[0] + 0.004 + 0.05 * ((p.y * 2) % 1.0)), out=(0, 0, 1))
    W.sweep(b, [V(0, yt + 0.08 + 0.08 * k, 0.24) for k in range(6)], W.round_profile(0.065, 10), LO,
            scale=[0.25, 0.85, 1.0, 1.0, 0.9, 0.55], smooth=True)
    K.slab(b, [V(0.008, yt + 0.22, 0.20), V(0.008, yt + 0.40, 0.20), V(0.008, yt + 0.40, 0.06), V(0.008, yt + 0.30, 0.06)], 0.016,
           lambda p: (p.y * 1.6, lo[0] + 0.004 + 0.05 * ((p.z * 3) % 1.0)), out=(1, 0, 0))
    hub = V(0, yt + 0.50, 0.24)
    C.tube(b, [hub, hub + V(0, 0.08, 0)], 0.035, LO, sides=8)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        rd, tg = V(math.cos(a), 0, math.sin(a)), V(-math.sin(a), 0, math.cos(a))
        K.slab(b, [hub + rd * 0.03 + tg * 0.05 + V(0, 0.02, 0), hub + rd * 0.16 + tg * 0.06 + V(0, 0.035, 0),
                   hub + rd * 0.16 - tg * 0.04 + V(0, 0.065, 0), hub + rd * 0.03 - tg * 0.05 + V(0, 0.06, 0)], 0.008,
               lambda p: (p.x * 2, lo[0] + 0.004 + 0.05 * ((p.z * 3) % 1.0)), out=(0, 1, 0))
    # tiller arm with twist grip, pull-start handle, kill cord
    C.tube(b, [V(0.0, yt - 0.02, zt + 0.16), V(0.03, yt - 0.40, zt + 0.12), V(0.05, yt - 0.62, zt + 0.10)], 0.026, UP, sides=8)
    C.tube(b, [V(0.05, yt - 0.62, zt + 0.10), V(0.06, yt - 0.80, zt + 0.09)], 0.022, band("rubber", 0.3), sides=8)
    C.tube(b, [V(0.16, yt + 0.05, zt + 0.32), V(0.21, yt + 0.05, zt + 0.32)], 0.015, band("rubber", 0.3), sides=6)
    return b


def build_trailing_rope():
    b = Buf()
    sc = V(-(hx(0.93, zs(0.93)) - 0.03), Y(0.93), zs(0.93) + 0.06)
    pts = [sc, sc + V(0.05, 0.12, 0.02), V(-0.55, L / 2 + 0.01, zs(1.0) + 0.03), V(-0.52, L / 2 + 0.07, zs(1.0) - 0.15),
           V(-0.45, L / 2 + 0.10, WL + 0.05), V(-0.36, L / 2 + 0.16, WL - 0.12), V(-0.22, L / 2 + 0.30, 0.38),
           V(-0.08, L / 2 + 0.42, 0.28), V(0.06, L / 2 + 0.49, 0.30), V(0.10, L / 2 + 0.47, 0.20), V(0.03, L / 2 + 0.52, 0.14)]
    C.tube(b, pts, 0.012, band("rope", 1.0), sides=6)
    for k in range(3):   # wraps round the propeller hub (the fouled prop)
        a = 2 * math.pi * k / 3
        W.ring(b, (0, L / 2 + 0.53 + 0.012 * k, 0.24), (1, 0, 0), (0, 0, 1), 0.045, 0.011, 10, 4, band("rope", 1.0))
    return b, pts[-1]


def build():
    C.clear_scene()
    parts = {}
    sb, post = build_samson()
    rb, rope_end = build_trailing_rope()
    for k, buf in (("Hull", build_hull()), ("Cabin", build_cabin()), ("Deck", build_deck()), ("Fittings", build_fittings()),
                   ("SamsonPost", sb), ("Outboard", build_outboard()), ("TrailingRope", rb)):
        parts[k] = buf.to_object("%s_%s_LOD0" % (NAME, k), K.mat(NAME, SETS, k))
    K.finish(NAME, parts, recalc=("SamsonPost", "Outboard", "TrailingRope"))
    y0, y1 = Y(TW), Y(TA)
    xs = lambda t, z: hx(t, z)
    atts = [W.empty("ATT_Waterline", (0, 0, WL)),
            W.empty("ATT_BowPoint", (0, Y(0.0) - 0.12, zs(0.0) + 0.08)),                    # greybox BowPoint (stem head roller)
            W.empty("ATT_Tow_SamsonPost", (0, post.y, post.z + 0.36)),
            W.empty("ATT_Cleat_Bow_Port", (xin(0.16) - 0.10, Y(0.16), zd(0.16) + 0.08)),
            W.empty("ATT_Cleat_Bow_Stbd", (-(xin(0.16) - 0.10), Y(0.16), zd(0.16) + 0.08)),
            W.empty("ATT_Bridle", (0, Y(0.0) - 0.12, zs(0.0) + 0.06)),                       # bridle apex at the fairlead
            W.empty("ATT_BowRail", (0, Y(0.0) - 0.04, zd(0.03) + 0.58)),
            W.empty("ATT_Cleat_Stern_Port", (xs(0.93, zs(0.93)) - 0.03, Y(0.93), zs(0.93) + 0.07), look=(0, 1, 0)),
            W.empty("ATT_Cleat_Stern_Stbd", (-(xs(0.93, zs(0.93)) - 0.03), Y(0.93), zs(0.93) + 0.07), look=(0, 1, 0)),
            W.empty("ATT_Cleat_Spring_Port", (xs(0.62, zs(0.62)) - 0.03, Y(0.62), zs(0.62) + 0.06), look=(1, 0, 0)),
            W.empty("ATT_Cleat_Spring_Stbd", (-(xs(0.62, zs(0.62)) - 0.03), Y(0.62), zs(0.62) + 0.06), look=(-1, 0, 0)),
            W.empty("ATT_Boarding_Port", (xs(0.80, zs(0.80)), Y(0.80), zs(0.80)), look=(1, 0, 0)),
            W.empty("ATT_Boarding_Stbd", (-xs(0.80, zs(0.80)), Y(0.80), zs(0.80)), look=(-1, 0, 0)),
            W.empty("ATT_Fender_Port", (xs(0.72, zs(0.72) - 0.35) + 0.12, Y(0.72), zs(0.72) - 0.35), look=(1, 0, 0)),
            W.empty("ATT_Fender_Stbd", (-(xs(0.72, zs(0.72) - 0.35) + 0.12), Y(0.72), zs(0.72) - 0.35), look=(-1, 0, 0)),
            W.empty("ATT_Seat_Helm", (0.37, y0 + 1.20, 1.42)),
            W.empty("ATT_Seat_01", (0.42, Y(0.16) + 0.05, zd(0.16) + 0.02)),                  # foredeck, the skipper waving
            W.empty("ATT_Seat_02", (-0.42, Y(0.20), zd(0.20) + 0.02)),
            W.empty("ATT_Seat_03", (0.45, Y(0.82), SOLE)),                                      # cockpit
            W.empty("ATT_Seat_04", (-0.45, Y(0.82), SOLE)),
            W.empty("ATT_Door", (0, y1 + 0.05, SOLE), look=(0, 1, 0)),
            W.empty("ATT_Smoke", (0, L / 2 + 0.30, zs(1.0) + 0.52)),
            W.empty("ATT_Prop", (0, L / 2 + 0.54, 0.24), look=(0, 1, 0)),
            W.empty("ATT_TrailingRope", tuple(rope_end), look=(0, 1, 0)),
            W.empty("ATT_Stern", (0, L / 2, zs(1.0)), look=(0, 1, 0)),
            W.empty("ATT_NavLight", (0, y1 - 0.25, 3.60))]
    I = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    col = W.col_boxes([((0, 0, 0.72), I, (1.12, 3.05, 0.55)), ((0, (y0 + y1) / 2, 1.85), I, (0.85, 0.92, 0.92)),
                       ((0, L / 2 + 0.25, 0.80), I, (0.20, 0.30, 0.62))], NAME + "_COL")
    return K.spec(NAME, BUDGET, BUDGET_TRIS, parts, SETS, atts, col, (2.4, 7.0, None),
                  size_note=None)
