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
def stud_on(b, p, n, cell):
    """One stud on a curved surface, sunk a little so its rim never floats."""
    n = V(n).normalized()
    b.stud((0, 0, 0), cell, T=kitgeo.orient(V(p) - n * .04, n))


def bolt_heads(b, pts, axis, cell):
    for p in pts:
        stud_on(b, p, axis, cell)


def mega_outboard(b):
    n = b.seg(20)
    zc = 14.2
    # one huge cowl in the hull's charcoal and orange, low enough to leave the driver in view; the hull's Engines part hides from L12
    b.rbox((0, 3.0, 11.15), (4.6, 2.9, .7), "Tube", r=.16)     # transom plate: the bracket reads bolted on
    bolt_heads(b, [(sx * 1.9, sy, 11.5) for sx in SIDES for sy in (2.0, 4.0)], EZ, "Tube")
    loft(b, [ring((0, 3.0, z), EX, EY, hx, hy, 4, n) for z, hx, hy in ((11.1, 1.9, 1.15), (12.6, 1.7, 1.05), (13.6, 1.4, .95))], "Dark")
    loft(b, [ring((0, y, cz), EX, EZ, hx, hz, 3.5, n) for y, hx, hz, cz in ((.25, .55, 1.3, 14.5), (1.4, .85, 1.6, zc), (3.9, 1.5, 2.1, zc))], "Dark")
    st = ((3.1, 2.1, 2.3), (3.3, 2.5, 2.7), (3.9, 2.8, 3.0), (4.62, 2.92, 3.12), (4.68, 2.84, 3.04), (4.76, 2.84, 3.04), (4.82, 2.98, 3.18), (5.5, 2.98, 3.18),
          (5.56, 2.9, 3.1), (5.64, 2.9, 3.1), (5.7, 2.95, 3.15), (7.2, 2.8, 3.0), (7.9, 2.4, 2.6), (8.2, 1.85, 2.05))
    loft(b, [ring((0, y, zc), EX, EZ, hx, hz, 3.2, n) for y, hx, hz in st], lambda i, j: "Tube" if 6 <= i <= 6 else "Mouth" if i in (4, 8) else "Dark")
    brick(b, (0, 8.32, zc), (3.2, .45, 3.2), "Tube", r=.14)
    for s in SIDES:
        for k in range(2):
            b.rbox((s * 2.93, 6.3 + k * .5, zc), (.2, .26, 2.6), "Tube", r=.08)
    b.rbox((0, 1.45, 14.7), (3.6, .4, 3.8), "Dark", r=.14)
    b.lathe(V((0, .55, 12.8)), EZ, [(0, 0), (.5, .3), (.82, 1.2), (.82, 2.4), (.7, 3.0), (0, 3.05)], "Dark", n=12)
    hub = V((0, .75, 15.8))
    b.lathe(hub, EZ, [(0, 0), (.72, 0), (.72, .7), (.46, 1.1), (0, 1.3)], "Chrome", n=14)
    blade = [(.4, -.7), (1.3, -1.1), (2.6, -1.0), (3.3, -.35), (3.3, .4), (2.6, 1.0), (1.3, 1.1), (.4, .6)]
    for k in range(3):
        b.extrude(blade, .2, .1, .1, "Blue", T=Tr(hub + V((0, 0, .5))) @ Rz(math.pi / 2 + k * 2 * math.pi / 3) @ Rx(.45) @ Ry(math.pi / 2))
    # one yellow bolt on the back: the only yellow on the engine
    b.extrude(BOLT, .25, .08, .08, "Yellow", T=face_z((0, 6.0, zc + 3.1)))
    for s in SIDES:
        b.lathe(V((s * 1.5, 7.5, zc + 1.8)), V((s * .12, .78, .6)), [(0, 0), (.42, 0), (.42, 1.2), (.62, 1.6), (.62, 1.8), (.3, 1.8), (.3, 1.5), (0, 1.5)], "Chrome", n=12)


# ------------------------------------------------------------------ L13
def arch_spoiler(b):
    n = b.seg(14)
    rake = math.radians(12)
    chord, thick = V((0, math.sin(rake), math.cos(rake))), V((0, math.cos(rake), -math.sin(rake)))
    arch = lambda x: SPOILER_Y - .85 * (x / 6.2) ** 2     # arched like the name: high in the middle, down to the endplates
    for s in SIDES:
        # one fat raked wedge per side on a stepped plinth, clamped to the foil: bolted on, not stuck on
        st = ((3.2, 11.0, 1.05, 1.5), (5.0, 11.2, .9, 1.25), (SPOILER_Y - .9, 12.1, .62, .85))
        loft(b, [ring((s * 3.6, y, z), EX, EZ, hx, hz, 4, n) for y, z, hx, hz in st], "Dark")
        b.rbox((s * 3.6, 3.2, 11.0), (3.0, .5, 3.8), "Tube", r=.16)
        brick(b, (s * 3.6, 3.65, 11.0), (2.3, .5, 3.1), "Dark", r=.14, xs=[-.75, .75], mask=lambda lx, lz: abs(lz) > 1.0)
        for y, z, hx, hz in ((7.0, 11.45, 1.0, 1.32), (SPOILER_Y - 2.1, 11.95, .92, 1.15)):
            loft(b, [ring((s * 3.6, y + d, z), EX, EZ, hx - (.06 if abs(d) > .3 else 0), hz - (.06 if abs(d) > .3 else 0), 4, n) for d in (-.36, -.26, .26, .36)], "Tube")
        b.rbox((s * 3.6, arch(3.6) - .62, 12.15), (2.0, .4, 2.9), "Tube", r=.14, T=None)
        ep = [(-2.9, -1.7), (2.9, -1.2), (3.2, 1.3), (-2.4, 1.3)]
        b.extrude(ep, .4, .14, .14, "Blue", T=Tr((s * 6.3, SPOILER_Y - .8, 12.4)))
        bolt_heads(b, [(s * 6.74, SPOILER_Y - .8 + yy, 12.4 + zz) for yy in (-.5, .5) for zz in (-1.4, 1.4)], (s, 0, 0), "White")
    k = max(b.seg(16) // 2, 4)
    xs = [-6.3 + 12.6 * i / k for i in range(k + 1)]
    loft(b, [ring((x, arch(x), 12.4), chord, thick, 2.5, .55, 2.6, n) for x in xs], "Blue")
    for f, cell in ((-.25, "Blue"), (.25, "Blue")):
        for i in range(12):
            x = -5.5 + i
            stud_on(b, V((x, arch(x), 12.4)) + chord * (f * 2.5) + thick * .52, thick, cell)
    b.rbox((0, 0, 0), (12.5, .09, .16), "BlueDeep", r=.03, T=Tr((0, arch(0) + .32, 12.4 + 1.5)) @ Rx(rake))
    T = Tr((0, arch(0) + .46, 12.4)) @ Rx(rake)
    brick(b, (0, 0, -1.65), (3.2, .22, 1.1), "Tube", r=.08, T=T)


# ------------------------------------------------------------------ L14
FIN = [(-3.1, 0), (2.8, 0), (2.1, 1.3), (2.5, 3.3), (3.9, 7.0), (1.4, 5.2), (-1.0, 2.5)]


def neon_fins(b):
    # tall on purpose: from L15 the fat tube swallows the root and about half the fin still stands clear
    for s in SIDES:
        for z in (-5.0, 8.8):
            T = Tr((s * 3.86, 3.0, z)) @ Rz(-s * math.radians(28))
            b.extrude(FIN, .36, .14, .14, "Neon", T=T)
            b.rbox((0, .1, 0), (1.5, .6, 5.6), "Dark", r=.16, T=T)
            brick(b, (0, .55, -1.6), (1.1, .34, 2.0), "Dark", r=.1, T=T, xs=[0], studs=False)


# ------------------------------------------------------------------ L15
SEAMS = (-3.9, 0.1, 4.1, 8.1)


def fat_stations(lod):
    """Port stern, round the bow, starboard stern: (centre, outward, radius, seam)."""
    F = FAT
    half = []
    tail = [(12.16, .1), (12.1, .3), (12.0, .48), (11.85, .63), (11.68, .74), (11.5, .8)]
    for s, r in (tail if lod < 2 else tail[1::2]):
        half.append((V((F["x"], F["y"], F["stern"] + (s - 11.3) * F["k"])), EX, r * F["k"], False))
    half.append((V((F["x"], F["y"], F["stern"])), EX, F["r"], False))
    for z in SEAMS[::-1] if lod < 2 else ():
        half += [(V((F["x"], F["y"], z + .07)), EX, F["r"], False), (V((F["x"], F["y"], z + .06)), EX, F["r"] - .05, True),
                 (V((F["x"], F["y"], z - .06)), EX, F["r"] - .05, True), (V((F["x"], F["y"], z - .07)), EX, F["r"], False)]
    half.append((V((F["x"], F["y"], F["z0"])), EX, F["r"], False))
    steps = {0: 16, 1: 9, 2: 5}[lod]
    for i in range(1, steps + 1):
        t = i / steps * math.pi / 2
        o = V((7 * math.cos(t), 0, -5 * math.sin(t))).normalized()
        half.append((V((F["x"] * math.cos(t), F["y"] + F["rise"] * math.sin(t) ** 1.6, F["z0"] + (F["z1"] - F["z0"]) * math.sin(t))), o, F["r"] * (1 - .05 * math.sin(t)), False))
    port = [(V((-c.x, c.y, c.z)), V((-o.x, o.y, o.z)), r, f) for c, o, r, f in half]
    return port + half[-2::-1]


def collar(b, s, z, w, cell, r=None, n=None):
    """Chunky band right round the fat tube, chamfered both sides."""
    r = r or FAT["r"]
    n = n or b.seg(20)
    c = lambda zz, rr: ring((s * FAT["x"], FAT["y"], zz), EX, EY, rr, rr, 2, n)
    loft(b, [c(z - w, r - .02), c(z - w + .12, r + .16), c(z + w - .12, r + .16), c(z + w, r - .02)], cell)


def fat_tubes(b):
    n = 24 if b.lod == 0 else 12
    step = 360 / n
    st = fat_stations(b.lod)
    rows = [[c + (o * math.cos(math.radians(15 + j * step)) + EY * math.sin(math.radians(15 + j * step))) * r for j in range(n)] for c, o, r, _ in st]
    # white band, not yellow: the hull's orange stays the anchor
    loft(b, rows, lambda i, j: "Dark" if st[i][3] and st[i + 1][3] else "White" if 15 <= 15 + j * step < 45 else "Tube")
    F = FAT
    for s in SIDES:
        for a in (72, 100):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            nrm = V((s * ca, sa, 0))
            for k in range(16):
                z = -5.4 + k + .5
                if any(abs(z - q) < .5 for q in SEAMS) or abs(z - 11) < 1.9 or abs(z - 7) < 1.4 or abs(z - 4.9) < 1.2 or abs(z + 2.6) < 1.2 or abs(z - 8.8) < 2.0 or abs(z + 5) < 0:
                    continue
                stud_on(b, V((s * F["x"], F["y"], z)) + nrm * F["r"], nrm, "Tube")
        # wrap-round collars carry the fenders; nothing is a pad stuck on the skin
        for z in (-2.6, 4.9):      # clear of the organ's collar (z 5.95 up), which shows with these from L19
            collar(b, s, z, .85, "Dark")
            T = Tr((s * 7.25, 3.6, z)) @ Rz(-s * math.pi / 2)
            brick(b, (0, 0, 0), (1.7, .55, 1.7), "Dark", r=.16, T=T)
        # sockets where the spoiler posts and neon fins come through the fat skin
        T = Tr((s * 3.6, 5.72, 11.2)) @ Rz(-s * .95)
        b.rbox((0, 0, 0), (2.5, 1.0, 3.3), "Dark", r=.24, T=T)
        for z in (-5.0, 8.8):
            T = Tr((s * 5.45, 5.92, z + .75)) @ Rz(-s * .22)
            b.rbox((0, 0, 0), (1.5, .36, 4.7), "Dark", r=.14, T=T)


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
    tiers = ((-3.4, 2.1, 3.9, "White"), (-5.4, 3.9, 5.7, "Tube"), (-7.4, 5.7, 7.5, "White"))
    back = -9.2
    for z0, y0, y1, cell in tiers:
        size = (4.6, y1 - y0, z0 - back)
        c = (0, (y0 + y1) / 2, (z0 + back) / 2)
        brick(b, c, size, cell, mask=lambda lx, lz, h=size[2]: lz > h / 2 - 1.6)
        b.rbox((0, y1 - .22, z0 + .04), (4.5, .44, .24), "Dark", r=.08)
    wedge = [(-3.15, 1.9), (-9.45, 1.9), (-9.45, 8.1), (-7.1, 8.1), (-3.15, 4.3)]
    for s in SIDES:
        b.extrude(wedge, .3, .1, .1, "Tube", T=Tr((s * 2.62, 0, 0)))
        bolt_heads(b, [(s * 2.92, y, z) for y, z in ((2.9, -4.2), (2.9, -8.6), (6.9, -8.6))], (s, 0, 0), "White")
    fan(b, (-1.3, 5.7, -6.2), .95, "Yellow", "Blue")
    fan(b, (1.3, 5.7, -6.2), .95, "White", "Blue")
    fan(b, (0, 7.5, -8.3), .95, "Yellow", "Blue")


# ------------------------------------------------------------------ L17
def paddle_wheel(b):
    cy, cz, R = 4.25, 1.5, 3.3
    n = b.seg(16)
    arc = b.seg(14)
    for s in SIDES:
        cx = s * 8.4
        Tc = Tr((cx, cy, cz))
        Tax = Tc @ Rz(-math.pi / 2)     # local Y along X
        for off in (-.9, .9):
            b.torus((0, off, 0), R - .35, .32, "Dark", maj=24, mnr=6, T=Tax)
        for k in range(6):
            a = k * math.pi / 3 + math.pi / 6
            b.rbox((0, R - .2, 0), (2.4, 1.5, .5), "White", r=.1, T=Tc @ Rx(a))
        for k in range(3):
            for off in (-.9, .9):
                b.rbox((off, 0, 0), (.56, 2 * (R - .5), .56), "Dark", r=.1, T=Tc @ Rx(k * math.pi / 3 + math.pi / 6))
        b.lathe(V((cx - 1.2, cy, cz)), EX, [(0, 0), (.9, 0), (.9, 2.4), (0, 2.4)], "Chrome", n=12)
        b.sphere((cx + s * 1.2, cy, cz), .55, "Dark", n=10)
        # the fat tube carries the box: flange on the skin, sculpted sponson wedge, solid inner wall, thick arch
        loft(b, [ring((s * x, cy, cz), EY, EZ, hy, hz, 4, n) for x, hy, hz in ((5.4, 1.5, 1.9), (6.9, 1.1, 1.3), (7.3, .85, .95))], "Dark")
        b.rbox((s * 6.72, cy + .1, cz), (.42, 2.9, 3.4), "Tube", r=.14)
        bolt_heads(b, [(s * 6.93, cy + .1 + y, cz + z) for y in (-1.1, 1.1) for z in (-1.3, 1.3)], (s, 0, 0), "White")
        wall = [(4.3 * math.sin(-1.2 + 2.4 * i / 8), 4.3 * math.cos(-1.2 + 2.4 * i / 8)) for i in range(9)] + [(1.5, -.2), (-1.5, -.2)]
        b.extrude(wall[::-1], .2, .08, .08, "Tube", T=Tr((cx - s * 1.4, cy, cz)))
        rows = []
        for i in range(arc + 1):
            t = -1.25 + 2.5 * i / arc
            rad = V((0, math.cos(t), math.sin(t)))
            rows.append(ring(V((cx, cy, cz)) + rad * 4.3, EX, rad, 1.62, .3, 5, 10))
        loft(b, rows, lambda i, j: "White" if i in (0, arc - 1) else "Tube")
        for off in (-.7, .7):
            for k in range(7):
                t = -.9 + 1.8 * k / 6
                rad = V((0, math.cos(t), math.sin(t)))
                stud_on(b, V((cx + off, cy, cz)) + rad * 4.6, rad, "Tube")


# ------------------------------------------------------------------ L18
def dome_rows(zc, cy, hx, hz, top, under, cell_top, cell_under, nz, n, bow=1.0, seam=None):
    """Half-domed jaw lofted bow to stern: top height `top` above cy, `under` below."""
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


def dome_point(x, z, zc, cy, hx, hz, top):
    u = (z - zc) / hz
    w = math.sqrt(max(1 - u * u, .002))
    c = max(-1, min(1, x / (hx * w)))
    return V((x, cy + top * math.sqrt(1 - c * c) * w ** .8, z))


def shark_jaws(b):
    # the hero of the stage: much bigger head, jaws wide open, big teeth, a dorsal fin rising behind the crowd, pectoral fins that read from the chase camera
    n = b.seg(32)
    nz = {0: 14, 1: 8, 2: 5}[b.lod]
    up, ul = (0, 6.4, -13.8), (6.0, 3.6, 4.8)
    lo, ll = (0, 2.5, -13.4), (5.2, 1.75, 4.6)
    rows, cf = dome_rows(up[2], up[1], ul[0], ul[2], ul[1], .4, "Blue", "Mouth", nz, n, bow=.95)
    loft(b, rows, cf)
    rows, cf = dome_rows(lo[2], lo[1], ll[0], ll[2], .3, ll[1], "Mouth", "White", nz, n, bow=.85)
    loft(b, rows, cf)
    # dark mouth back wall (hides the fat tube's nose), fat cheeks tying the jaws together
    loft(b, [ring((0, 4.45, z), EX, EY, hx, 2.5, 3, n) for z, hx in ((-15.7, 4.2), (-14.8, 4.6))], "Mouth")
    for s in SIDES:
        b.rbox((s * 4.75, 4.45, -11.7), (1.8, 5.2, 4.4), "Blue", r=.6, soft=True)
        for k in range(3):
            T = Tr((s * 5.45, 7.0 - k * .1, -12.2 + k * 1.0)) @ Rz(-s * .4)
            b.rbox((0, 0, 0), (.36, 1.9, .44), "BlueDeep", r=.12, T=T)
        fin = [(-2.3, 0), (2.5, 0), (3.6, 4.2), (.9, 3.2), (-1.0, 1.5)]
        T = Tr((s * 5.1, 4.4, -10.4)) @ Rz(-s * math.radians(72))
        b.extrude(fin, .34, .14, .14, "Blue", T=T)
    # teeth: few and big
    cone = [(0, 0), (.56, 0), (.5, .4), (.3, .95), (.1, 1.35), (0, 1.42)]
    for i in range(8):
        a = -1.15 + 2.3 * i / 7
        k = 1.35 if i % 2 else 1.6
        b.lathe(V((ul[0] * .9 * math.sin(a), up[1] - .3, up[2] - ul[2] * .9 * math.cos(a))), -EY, [(r * k, h * k) for r, h in cone], "White", n=9)
    for i in range(6):
        a = -1.05 + 2.1 * i / 5
        k = 1.15 if i % 2 else 1.35
        b.lathe(V((ll[0] * .88 * math.sin(a), lo[1] + .2, lo[2] - ll[2] * .88 * math.cos(a))), EY, [(r * k, h * k) for r, h in cone], "White", n=9)
    for s in SIDES:
        eye = V((s * 3.3, 8.75, -14.5))
        look = V((s * .16, .2, -1)).normalized()
        b.sphere(eye, 1.55, "White", n=18)
        b.sphere(eye + look * .92, .88, "Mouth", n=14)
        b.sphere(eye + look * 1.75 + V((-s * .26, .3, 0)), .22, "White", n=8)
        b.rbox((s * 3.35, 10.55, -14.7), (2.4, .5, .85), "BlueDeep", r=.18)
    # premium toy: studs along the back of the head, either side of the fin
    for x in (-3.4, -2.4, -1.4, 1.4, 2.4, 3.4):
        for z in (-12.6, -11.6, -10.6):
            p = dome_point(x, z, up[2], up[1], ul[0], ul[2], ul[1])
            q = dome_point(x + .05, z, up[2], up[1], ul[0], ul[2], ul[1])
            r = dome_point(x, z + .05, up[2], up[1], ul[0], ul[2], ul[1])
            stud_on(b, p, (q - p).cross(r - p) * (1 if (q - p).cross(r - p).y > 0 else -1), "Blue")
    # dorsal fin sculpted to a point, so it reads as a fin from behind too, not a flat-topped slab
    st = ((7.4, -12.6, 3.2, 1.15), (10.0, -12.0, 2.8, 1.0), (12.5, -11.0, 2.0, .8), (14.6, -10.0, 1.2, .55), (16.0, -9.3, .6, .3), (16.8, -8.9, .12, .08))
    loft(b, [ring((0, y, z), EX, EZ, hx, hz, 2.5, b.seg(16)) for y, z, hz, hx in st], "Blue")


# ------------------------------------------------------------------ L19
def exhaust_organ(b):
    # small on purpose: three stepped pipes per side on a collar round the fat tube, tops under the spoiler in the chase view
    zc = 7.0
    r = .44
    for s in SIDES:
        collar(b, s, zc, 1.05, "Dark")
        brick(b, (s * 5.2, 6.3, zc), (3.2, .5, 2.2), "Dark", r=.14, studs=False)
        b.rbox((s * 5.2, 6.68, zc), (3.0, .3, 1.8), "Tube", r=.1)
        for x, top in ((4.3, 10.8), (5.2, 11.8), (6.1, 12.8)):
            base = V((s * x, 6.7, zc))
            h = top - base.y
            b.lathe(base, EY, [(0, 0), (r, 0), (r, h - .6), (r + .16, h - .32), (r + .3, h - .1), (r + .3, h), (r - .12, h), (r - .12, h - .34), (0, h - .34)], "Chrome", n=14)
            b.torus((s * x, top - .08, zc), r + .26, .13, "Tube", maj=14, mnr=5)
            b.rbox((s * x, 8.0, zc + r - .02), (.54, .46, .12), "Mouth", r=.04)
            b.lathe(base + V((0, 1.9, 0)), EY, [(0, 0), (r + .08, 0), (r + .08, .34), (0, .34)], "Dark", n=14)


# ------------------------------------------------------------------ L20
def thunder_wing(b):
    # the spoiler sprouts one clean lightning bolt each side: one kink, nothing else
    bolt = [(-.7, 1.2), (3.6, 1.6), (2.9, .35), (8.0, .35), (3.9, -1.5), (4.5, -.25), (-.7, -1.2)]
    rise = math.radians(46)
    bev = .22 if b.lod < 2 else 0.01
    for s in SIDES:
        at = V((s * 5.7, SPOILER_Y - .2, 12.3))
        pos = lambda u, v: (s * (u * math.cos(rise) - v * math.sin(rise)), u * math.sin(rise) + v * math.cos(rise))
        b.extrude([pos(u, v) for u, v in bolt], 1.25, bev, bev, "Yellow", T=face_z(at))
        for u, v in ((.8, 0), (1.8, .1), (2.8, .3), (4.2, .55 - .35), (5.2, .25)):
            x, y = pos(u, v)
            stud_on(b, at + V((x, y, 1.25)), EZ, "Yellow")


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
