"""The RIB stage's nine upgrade pieces (levels 12-20), from the owner-cleared concept (artifact 0ae647e2).

One asset per piece (thin build.py in ../M_Upg_RIB_<Piece>), all sharing one palette set. Built in the frame of the shipped
M_Veh_RIB, so each piece's Model pivot is the hull origin. Authored in the concept frame (X starboard, Y up from the skeg base,
Z aft); the pipeline frame is bx = -X, by = Z + frame_offset, bz = Y. Mesh helpers come from ../_UpgJetSki/kitgeo.py.

    python3 art/source/vehicles/_UpgRIB/palette.py build/prod/_UpgRIB/textures
    In Blender: import pipeline; pipeline.run_all()
"""
import importlib
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
HULL = os.path.join(HERE, "..", "M_Veh_RIB")
sys.path[:0] = [HERE, os.path.join(HERE, "..", "_UpgJetSki")]    # HERE first: kitgeo must pick up this folder's palette
import palette as PAL  # noqa: E402

from mathutils import Matrix, Vector  # noqa: E402

import kitgeo  # noqa: E402

importlib.reload(PAL)
importlib.reload(kitgeo)
kitgeo.STUD_P, kitgeo.STUD_R, kitgeo.STUD_H = 1.0, 0.34, 0.22   # the RIB is seen from further away than the ski

PREFIX = "M_Upg_RIB_"
SET_NAME, SET = "UpgRIB", "Brick"
TEX_DIR = os.path.join(G, "build/prod/_UpgRIB/textures")
STEM = os.path.join(TEX_DIR, "T_%s_%s_" % (SET_NAME, SET))
HULL_OFF = json.load(open(os.path.join(HULL, "frame_offset.json")))["offset"][1]
Rx = lambda a: Matrix.Rotation(a, 4, "X")
Ry = lambda a: Matrix.Rotation(a, 4, "Y")
Rz = lambda a: Matrix.Rotation(a, 4, "Z")
Tr = Matrix.Translation
V = Vector
EX, EY, EZ = V((1, 0, 0)), V((0, 1, 0)), V((0, 0, 1))
SIDES = (1, -1)
DECK = 2.1
SPOILER_Y = 15.0    # high enough that the driver and the crowd read under it from the chase camera
FAT = dict(x=5.0, y=4.0, r=2.0, z0=-6.0, z1=-13.0, rise=0.5, stern=11.3, k=2 / .825)
BOLT = [(-.9, 1.6), (1.1, 1.6), (.1, .1), (1.2, .1), (-.9, -2.2), (-.2, -.45), (-1.2, -.45)]    # shape x, y


def ring(c, a, b, ha, hb, p=2.0, n=16, start=0.0):
    """Superellipse ring round c in the plane of unit vectors a, b."""
    pts = []
    for j in range(n):
        t = start + 2 * math.pi * j / n
        ca, sa = math.cos(t), math.sin(t)
        pts.append(V(c) + a * (ha * math.copysign(abs(ca) ** (2 / p), ca)) + b * (hb * math.copysign(abs(sa) ** (2 / p), sa)))
    return pts


def loft(b, rings, cell, T=None, caps=True):
    """Closed skin through same-size rings, smooth normals. cell: name, or f(i, j) -> name for face j of band i."""
    ni, nj = len(rings), len(rings[0])
    vs, ns, fs, cs = [], [], [], []
    mids = [sum(r, V((0, 0, 0))) / nj for r in rings]
    for i, r in enumerate(rings):
        for j, p in enumerate(r):
            du = r[(j + 1) % nj] - r[j - 1]
            dv = rings[min(i + 1, ni - 1)][j] - rings[max(i - 1, 0)][j]
            m = du.cross(dv)
            m = m.normalized() if m.length > 1e-6 else (p - mids[i]).normalized()
            vs.append(p)
            ns.append(m if m.dot(p - mids[i]) >= 0 else -m)
    for i in range(ni - 1):
        for j in range(nj):
            j2 = (j + 1) % nj
            fs.append((i * nj + j, (i + 1) * nj + j, (i + 1) * nj + j2, i * nj + j2))
            cs.append(PAL.CELL[cell(i, j) if callable(cell) else cell])
    if caps:
        for i, axis in ((0, mids[0] - mids[1]), (ni - 1, mids[-1] - mids[-2])):
            base = len(vs)
            vs += rings[i]
            ns += [axis.normalized()] * nj
            fs.append(tuple(base + j for j in range(nj)))
            cs.append(PAL.CELL[cell(max(i - 1, 0), nj - 1) if callable(cell) else cell])
    return b.emit(vs, ns, fs, cs, T)


def brick(b, c, size, cell, r=0.14, T=None, studs=True, xs=None, mask=None):
    b.rbox(c, size, cell, r=r, T=T)
    if studs:
        b.studs(c, size, cell, T=T, xs=xs, mask=mask)


def face_z(at):
    """Frame whose extrude shape (x, y) lies in world X, Y, thickness along Z."""
    return Tr(at) @ Ry(math.pi / 2)


# ------------------------------------------------------------------ L12
def mega_outboard(b):
    n = b.seg(20)
    zc = 14.2
    # one huge cowl, low enough to leave the driver in view from the chase camera; the hull's own Engines part hides from L12
    loft(b, [ring((0, 3.0, z), EX, EY, hx, hy, 4, n) for z, hx, hy in ((10.8, 1.9, 1.15), (12.6, 1.7, 1.05), (13.6, 1.4, .95))], "Dark")
    loft(b, [ring((0, y, cz), EX, EZ, hx, hz, 3.5, n) for y, hx, hz, cz in ((.25, .55, 1.3, 14.5), (1.4, .85, 1.6, zc), (3.9, 1.5, 2.1, zc))], "Blue")
    st = ((3.3, 2.3, 2.5), (3.9, 2.8, 3.0), (4.7, 2.95, 3.15), (5.3, 2.98, 3.18), (6.0, 2.95, 3.15), (7.3, 2.8, 3.0), (8.0, 2.35, 2.55), (8.3, 1.7, 1.9))
    loft(b, [ring((0, y, zc), EX, EZ, hx, hz, 3.2, n) for y, hx, hz in st], lambda i, j: "Blue" if i == 2 else "Yellow")
    brick(b, (0, 8.45, zc), (2.6, .5, 2.6), "Blue")
    b.rbox((0, 1.45, 14.7), (3.6, .4, 3.8), "Yellow", r=.14)
    b.lathe(V((0, .55, 12.8)), EZ, [(0, 0), (.5, .3), (.82, 1.2), (.82, 2.4), (.7, 3.0), (0, 3.05)], "Blue", n=12)
    hub = V((0, .75, 15.8))
    b.lathe(hub, EZ, [(0, 0), (.72, 0), (.72, .7), (.46, 1.1), (0, 1.3)], "Chrome", n=14)
    blade = [(.4, -.7), (1.3, -1.1), (2.6, -1.0), (3.3, -.35), (3.3, .4), (2.6, 1.0), (1.3, 1.1), (.4, .6)]
    for k in range(3):
        b.extrude(blade, .2, .1, .1, "Blue", T=Tr(hub + V((0, 0, .5))) @ Rz(math.pi / 2 + k * 2 * math.pi / 3) @ Rx(.45) @ Ry(math.pi / 2))
    # big bolt on the back, seen from the chase camera; flared stacks on the top shoulders
    b.extrude([(x * 1.0, y * .95) for x, y in BOLT], .25, .08, .08, "Blue", T=face_z((0, 5.9, zc + 3.1)))
    for s in SIDES:
        b.lathe(V((s * 1.5, 7.5, zc + 1.8)), V((s * .12, .78, .6)), [(0, 0), (.42, 0), (.42, 1.2), (.62, 1.6), (.62, 1.8), (.3, 1.8), (.3, 1.5), (0, 1.5)], "Chrome", n=12)


# ------------------------------------------------------------------ L13
def arch_spoiler(b):
    n = b.seg(14)
    rake = math.radians(12)
    chord, thick = V((0, math.sin(rake), math.cos(rake))), V((0, math.cos(rake), -math.sin(rake)))
    arch = lambda x: SPOILER_Y - .85 * (x / 6.2) ** 2     # arched like the name: high in the middle, down to the endplates
    for s in SIDES:
        # one fat raked wedge per side, from the tube top up into the foil
        st = ((3.15, 11.0, 1.05, 1.5), (5.0, 11.2, .9, 1.25), (SPOILER_Y - .9, 12.1, .62, .85))
        loft(b, [ring((s * 3.6, y, z), EX, EZ, hx, hz, 4, n) for y, z, hx, hz in st], "Dark")
        brick(b, (s * 3.6, 3.15, 11.0), (2.4, .4, 3.2), "Blue", T=None, studs=False)
        ep = [(-2.9, -1.7), (2.9, -1.2), (3.2, 1.3), (-2.4, 1.3)]
        b.extrude(ep, .36, .1, .1, "Yellow", T=Tr((s * 6.3, SPOILER_Y - .8, 12.4)))
    k = b.seg(16)
    xs = [-6.3 + 12.6 * i / max(k // 2, 4) for i in range(max(k // 2, 4) + 1)]
    loft(b, [ring((x, arch(x), 12.4), chord, thick, 2.5, .55, 2.6, n, start=0) for x in xs], "Blue")
    T = Tr((0, arch(0) + .42, 12.2)) @ Rx(rake)
    brick(b, (0, 0, 0), (4.2, .3, 2.2), "Yellow", T=T)


# ------------------------------------------------------------------ L14
FIN = [(-3.1, 0), (2.8, 0), (2.1, 1.3), (2.5, 3.3), (3.9, 7.0), (1.4, 5.2), (-1.0, 2.5)]


def neon_fins(b):
    # tall on purpose: from L15 the fat tube swallows the root and about half the fin still stands clear
    for s in SIDES:
        for z in (-5.0, 8.8):
            T = Tr((s * 3.86, 3.0, z)) @ Rz(-s * math.radians(28))
            b.extrude(FIN, .36, .12, .12, "Neon", T=T)
            b.rbox((0, .1, 0), (1.3, .6, 5.2), "Dark", r=.14, T=T)


# ------------------------------------------------------------------ L15
def fat_stations(lod):
    """Port stern, round the bow, starboard stern: (centre, outward, radius)."""
    F = FAT
    half = []
    tail = [(12.16, .1), (12.1, .3), (12.0, .48), (11.85, .63), (11.68, .74), (11.5, .8)]
    for s, r in (tail if lod < 2 else tail[1::2]):
        half.append((V((F["x"], F["y"], F["stern"] + (s - 11.3) * F["k"])), EX, r * F["k"]))
    half += [(V((F["x"], F["y"], F["stern"])), EX, F["r"]), (V((F["x"], F["y"], F["z0"])), EX, F["r"])]
    steps = {0: 16, 1: 9, 2: 5}[lod]
    for i in range(1, steps + 1):
        t = i / steps * math.pi / 2
        o = V((7 * math.cos(t), 0, -5 * math.sin(t))).normalized()
        half.append((V((F["x"] * math.cos(t), F["y"] + F["rise"] * math.sin(t) ** 1.6, F["z0"] + (F["z1"] - F["z0"]) * math.sin(t))), o, F["r"] * (1 - .05 * math.sin(t))))
    port = [(V((-c.x, c.y, c.z)), V((-o.x, o.y, o.z)), r) for c, o, r in half]
    return port + half[-2::-1]


def fat_tubes(b):
    n = 24 if b.lod == 0 else 12
    step = 360 / n
    st = fat_stations(b.lod)
    rows = [[c + (o * math.cos(math.radians(15 + j * step)) + EY * math.sin(math.radians(15 + j * step))) * r for j in range(n)] for c, o, r in st]
    stripe = (15, 45)      # concept's stripe (14 to 38 deg), one colour run on a ring vertex
    loft(b, rows, lambda i, j: "Yellow" if stripe[0] <= 15 + j * step < stripe[1] else "Tube")
    for s in SIDES:
        for z in (-3.6, 9.6):
            T = Tr((s * 6.9, 3.5, z)) @ Rz(-s * math.pi / 2)
            brick(b, (0, 0, 0), (2.4, .8, 2.4), "Dark", r=.16, T=T)


# ------------------------------------------------------------------ L16
def fan(b, at, k, shirt, cap):
    """Blocky cheering fan facing aft, at the driver; fat arms up."""
    T = Tr(at) @ Matrix.Diagonal((k, k, k, 1))
    b.rbox((0, .4, 0), (1.5, .8, 1.4), "Dark", r=.12, T=T)
    b.rbox((0, 1.55, 0), (1.6, 1.7, 1.0), shirt, r=.2, T=T)
    for s in SIDES:
        b.tube([(s * .85, 2.15, 0), (s * 1.3, 3.0, .15), (s * 1.35, 3.9, .1)], .29, shirt, rs=8, f=.2, T=T)
        b.sphere((s * 1.35, 4.05, .1), .32, "Skin", n=8, T=T)
    b.rbox((0, 2.95, 0), (1.15, 1.05, 1.1), "Skin", r=.32, T=T)
    for s in SIDES:
        b.sphere((s * .24, 3.05, .53), .11, "Dark", n=6, T=T)
    b.rbox((0, 2.72, .54), (.5, .12, .08), "Dark", r=.03, T=T)
    b.rbox((0, 3.6, -.02), (1.25, .4, 1.25), cap, r=.14, T=T)
    b.rbox((0, 3.48, .72), (.9, .14, .6), cap, r=.05, T=T)


def grandstand(b):
    # stands the concept's stand round: the crowd faces aft, so the chase camera sees them cheering the driver
    tiers = ((-3.4, 2.1, 3.9, "Blue"), (-5.4, 3.9, 5.7, "White"), (-7.4, 5.7, 7.5, "Blue"))
    back = -9.2
    for z0, y0, y1, cell in tiers:
        size = (4.6, y1 - y0, z0 - back)
        c = (0, (y0 + y1) / 2, (z0 + back) / 2)
        brick(b, c, size, cell, mask=lambda lx, lz, h=size[2]: lz > h / 2 - 1.6)
        b.rbox((0, y1 - .22, z0 + .04), (4.5, .44, .24), "Yellow", r=.08)
    wedge = [(-3.15, 1.9), (-9.45, 1.9), (-9.45, 8.1), (-7.1, 8.1), (-3.15, 4.3)]
    for s in SIDES:
        b.extrude(wedge, .3, .08, .08, "Yellow", T=Tr((s * 2.62, 0, 0)))
    fan(b, (-1.3, 5.7, -6.2), .95, "Yellow", "Blue")
    fan(b, (1.3, 5.7, -6.2), .95, "White", "Blue")
    fan(b, (0, 7.5, -8.3), .95, "Yellow", "Blue")


# ------------------------------------------------------------------ L17
def paddle_wheel(b):
    cy, cz, R = 5.5, 3.6, 4.5
    n = b.seg(16)
    arc = b.seg(14)
    for s in SIDES:
        cx = s * 9.6
        Tc = Tr((cx, cy, cz))
        Tax = Tc @ Rz(-math.pi / 2)     # local Y along X
        for off in (-1.15, 1.15):
            b.torus((0, off, 0), R - .5, .42, "Yellow", maj=28, mnr=7, T=Tax)
        for k in range(6):
            a = k * math.pi / 3 + math.pi / 6
            b.rbox((0, R - .35, 0), (3.5, 2.1, .6), "White", r=.1, T=Tc @ Rx(a))
        for k in range(3):
            for off in (-1.15, 1.15):
                b.rbox((off, 0, 0), (.7, 2 * (R - .7), .7), "Yellow", r=.1, T=Tc @ Rx(k * math.pi / 3 + math.pi / 6))
        b.lathe(V((cx - 1.6, cy, cz)), EX, [(0, 0), (1.25, 0), (1.25, 3.2), (0, 3.2)], "Chrome", n=14)
        b.sphere((cx + s * 1.6, cy, cz), .8, "Yellow", n=12)
        # the fat tube carries the box: a sculpted sponson wedge in to the tube, a solid inner wall, a thick arch
        loft(b, [ring((s * x, cy, cz), EY, EZ, hy, hz, 4, n) for x, hy, hz in ((5.4, 1.9, 2.3), (7.2, 1.45, 1.7), (cx * s - 1.5, 1.1, 1.2))], "Dark")
        wall = [(5.6 * math.sin(-1.2 + 2.4 * i / 8), 5.6 * math.cos(-1.2 + 2.4 * i / 8)) for i in range(9)]
        wall = wall + [(2.0, -.2), (-2.0, -.2)]
        b.extrude(wall[::-1], .22, .08, .08, "Blue", T=Tr((cx - s * 2.05, cy, cz)))
        rows = []
        for i in range(arc + 1):
            t = -1.25 + 2.5 * i / arc
            rad = V((0, math.cos(t), math.sin(t)))
            rows.append(ring(V((cx, cy, cz)) + rad * 5.6, EX, rad, 2.3, .34, 5, 10))
        loft(b, rows, lambda i, j: "Yellow" if i in (0, arc - 1) else "Blue")


# ------------------------------------------------------------------ L18
def dome_rows(zc, cy, hx, hz, top, under, cell_top, cell_under, nz, n, bow=1.0):
    """Half-domed jaw lofted bow to stern: top height `top` above cy, `under` below. Rear stays open-ended in the head."""
    rows = []
    for i in range(nz + 1):
        u = -1 + (1 + bow) * i / nz
        u = math.copysign(abs(u) ** .85, u) if u else 0
        w = math.sqrt(max(1 - u * u, .002))
        ring_pts = []
        for j in range(n):
            t = 2 * math.pi * (j + .5) / n
            sa = math.sin(t)
            y = cy + (top * sa if sa > 0 else under * sa) * w ** .8
            ring_pts.append(V((hx * w * math.cos(t), y, zc + hz * u)))
        rows.append(ring_pts)
    half = n // 2
    return rows, (lambda i, j: cell_top if j < half else cell_under)


def shark_jaws(b):
    n = b.seg(28)
    nz = {0: 12, 1: 7, 2: 4}[b.lod]
    up, ul = (0, 5.9, -12.9), (4.7, 2.75, 3.75)
    lo, ll = (0, 2.45, -12.7), (4.1, 1.3, 3.5)
    rows, cf = dome_rows(up[2], up[1], ul[0], ul[2], ul[1], .35, "Blue", "Mouth", nz, n, bow=.82)
    loft(b, rows, cf)
    rows, cf = dome_rows(lo[2], lo[1], ll[0], ll[2], .3, ll[1], "Mouth", "White", nz, n, bow=.8)
    loft(b, rows, cf)
    # dark mouth back wall (hides the fat tube's nose) and fat cheeks tying the jaws together
    loft(b, [ring((0, 4.2, z), EX, EY, hx, 2.1, 3, n) for z, hx in ((-15.25, 3.1), (-14.5, 3.5))], "Mouth")
    for s in SIDES:
        b.rbox((s * 3.75, 4.15, -11.4), (1.5, 4.4, 3.6), "Blue", r=.5, soft=True)
        for k in range(3):
            T = Tr((s * 4.45, 6.5 - k * .1, -11.5 + k * .85)) @ Rz(-s * .35)
            b.rbox((0, 0, 0), (.3, 1.4, .36), "BlueDeep", r=.1, T=T)
    # teeth: few and big
    cone = [(0, 0), (.56, 0), (.5, .4), (.3, .95), (.1, 1.35), (0, 1.42)]
    for i in range(8):
        a = -1.15 + 2.3 * i / 7
        k = 1.0 if i % 2 else 1.14
        b.lathe(V((ul[0] * .9 * math.sin(a), up[1] - .25, up[2] - ul[2] * .9 * math.cos(a))), -EY, [(r * k, h * k) for r, h in cone], "White", n=9)
    for i in range(6):
        a = -1.05 + 2.1 * i / 5
        k = .85 if i % 2 else .98
        b.lathe(V((ll[0] * .88 * math.sin(a), lo[1] + .2, lo[2] - ll[2] * .88 * math.cos(a))), EY, [(r * k, h * k) for r, h in cone], "White", n=9)
    for s in SIDES:
        eye = V((s * 2.4, 7.4, -13.3))
        look = V((s * .16, .2, -1)).normalized()
        b.sphere(eye, 1.2, "White", n=18)
        b.sphere(eye + look * .72, .68, "Mouth", n=14)
        b.sphere(eye + look * 1.36 + V((-s * .2, .24, 0)), .17, "White", n=8)
        b.rbox((s * 2.45, 8.95, -13.5), (1.9, .42, .7), "BlueDeep", r=.15, T=None)
    fin = [(-2.9, -.8), (-1.6, 2.0), (.3, 4.5), (2.5, 6.4), (1.7, 3.6), (1.5, 1.4), (2.2, -.8)]
    b.extrude(fin, .55, .16, .16, "Blue", T=Tr((0, 7.5, -11.2)))


# ------------------------------------------------------------------ L19
def exhaust_organ(b):
    # two chunky banks with the driver in the gap, not one thin wall behind the helmet; tallest outside so the pair frames the crew
    zc = 5.7
    r = .6
    n = b.seg(16)
    for s in SIDES:
        st = ((1.75, 4.1, 2.0, 1.55), (3.0, 4.6, 2.5, 1.7), (5.9, 5.6, 2.15, 1.7))
        loft(b, [ring((s * x, y, zc), EY, EZ, hy, hz, 4, n) for x, y, hy, hz in st], lambda i, j: "Blue")
        for x, top in ((2.4, 13.4), (3.6, 15.4), (4.8, 17.4)):
            base = V((s * x, 5.0, zc))
            h = top - base.y
            b.lathe(base, EY, [(0, 0), (r, 0), (r, h - .75), (r + .22, h - .4), (r + .4, h - .12), (r + .4, h), (r - .14, h), (r - .14, h - .4), (0, h - .4)], "Chrome", n=14)
            b.torus((s * x, top - .1, zc), r + .36, .16, "Yellow", maj=16, mnr=5)
            b.rbox((s * x, 8.6, zc + r - .02), (.72, .6, .14), "Mouth", r=.04)
            b.lathe(base + V((0, h * .5, 0)), EY, [(0, 0), (r + .1, 0), (r + .1, .5), (0, .5)], "Blue", n=14)


# ------------------------------------------------------------------ L20
def thunder_wing(b):
    # one joke: the arch spoiler sprouts two huge lightning bolts. No second wing, posts or pipe slots.
    bolt = [(-.8, 1.5), (5.2, 2.0), (4.2, .5), (10.0, 1.15), (5.7, -1.55), (6.3, -.15), (-.8, -1.5)]
    rise = math.radians(26)
    for s in SIDES:
        pts = [(s * (u * math.cos(rise) - v * math.sin(rise)), u * math.sin(rise) + v * math.cos(rise)) for u, v in bolt]
        bev = 0.2 if b.lod < 2 else 0.01
        b.extrude(pts, 1.75, bev, bev, "Yellow", T=face_z((s * 5.6, SPOILER_Y - .3, 12.3)))


PIECES = [(12, "MegaOutboard", mega_outboard), (13, "ArchSpoiler", arch_spoiler), (14, "NeonFins", neon_fins), (15, "FatTubes", fat_tubes),
          (16, "Grandstand", grandstand), (17, "PaddleWheel", paddle_wheel), (18, "SharkJaws", shark_jaws), (19, "ExhaustOrgan", exhaust_organ),
          (20, "ThunderWing", thunder_wing)]


def patch_pipeline(prebuilt):
    """Hand-made LODs, the new Upg category and the 8 x 8 palette, without touching tools/."""
    import names
    import versions
    import zfight_check
    if "Upg" not in names.CATEGORIES:   # shortcut: run-time only, tools/ is not ours; add Upg to names.py when upgrade pieces settle
        names.CATEGORIES = (*names.CATEGORIES, "Upg")
    zfight_check.GRID = PAL.GRID
    orig = getattr(versions, "_orig_decimate", versions.decimate)
    versions._orig_decimate = orig

    def decimate(obj, target, symmetry=None):
        import bpy
        m = prebuilt.pop(obj.name, None)
        if m is not None:
            old = obj.data
            obj.data = m
            bpy.data.meshes.remove(old)
            m.name = obj.name
        if len(obj.data.polygons) > 240:     # a collapse pass eats the bolts' zigzag on the few-tri pieces; those stay hand-made
            orig(obj, target, symmetry)
    versions.decimate = decimate


def spec(short):
    level, fn = next((lv, f) for lv, s, f in PIECES if s == short)
    mat = kitgeo.material("MI_UpgRIB_Brick", STEM)
    name = PREFIX + short
    lods, tris = {}, []
    for lod in (0, 1, 2):
        b = kitgeo.B(lod)
        fn(b)
        tris.append(b.tris())
        if lod:
            lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat, HULL_OFF)
        else:
            obj = b.to_object(name + "_LOD0", mat, HULL_OFF)
    patch_pipeline(lods)
    vs = [v.co for v in obj.data.vertices]
    lo, hi = [min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)]
    cb = [(lo[i] + hi[i]) / 2 for i in range(3)]
    path = os.path.join(HERE, "offsets.json")
    table = json.load(open(path)) if os.path.exists(path) else {}
    table[short] = {"level": level, "tris_authored": tris, "meshpart_centre_roblox": [round(-cb[0], 3), round(cb[2], 3), round(cb[1], 3)],
                    "size_roblox": [round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)]}
    with open(path, "w") as f:
        json.dump(table, f, indent=1)
    return {
        "name": name, "budget": "large_prop", "tier": "standard",
        "dims_m": tuple(round((hi[i] - lo[i]) / 3.0, 3) for i in range(3)), "origin": "free", "tiling": True,
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False, "dir": TEX_DIR}],
        "meshes": [{"object": obj, "set": SET}],
        "attachments": [],
        "waivers": {
            "_COL proxy": "bolt-on look only: CanCollide off, the hull's own _COL is the collision",
            "LOD UV layout": "flat palette cells: hand-made LODs drop studs and bevels, UVs are not a unique unwrap by design",
            "LOD0 floor": "large_prop floor is for detailed props; these are fewer, bigger toy shapes on purpose (AD rule)",
            "texture sets": "one flat palette set shared by all nine pieces (toy-brick rule, like M_Prop_HubKit)",
        },
    }
