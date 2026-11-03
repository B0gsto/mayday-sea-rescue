"""M_Prop_LagoonKit: Lego refine of the Mermaid Lagoon's code-built dressing (PERF-BL12; same places and ideas as
src/server/World/Islands/MermaidLagoon/{Kit,init}.luau, baseline 5.8).

One FBX, one flat palette material, every module its own mesh; modules sit side by side along Roblox +x, each with an ATT_<Slot>
at its origin (Roblox axes: x across, y up, front -z). LAYOUT is where the wiring code puts them, at the code's real world
coordinates; y None = groundY(x, z) raycast (and skip when gy <= 0.5, as today). Collision: simple code Parts, no per-module _COL.
The terrain's white sand is not in this kit.

    python3 art/source/props/M_Prop_LagoonKit/maketex.py --out build/prod/M_Prop_LagoonKit/textures/M_Prop_LagoonKit
    run.py --build art/source/props/M_Prop_LagoonKit/build.py --out-root build/prod/M_Prop_LagoonKit --steps build,lod,validate,export
LODs are hand-made (patch_lod): LOD1 drops the studs, LOD2 merges bricks into boxes.
"""
import math
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Prop_LagoonKit"
BUDGET = "hero_building"
TIER = "standard"
SET_NAME, SET = "LagoonKit", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_LagoonKit_Brick_ALB.png")
SINK = 0.05


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def patch_lod(prebuilt):
    """The lod step starts from our hand-made LOD1 / LOD2 meshes; versions.decimate only cuts if one is over its target."""
    import bpy
    import versions
    orig = getattr(versions, "_orig_decimate", versions.decimate)
    versions._orig_decimate = orig

    def decimate(obj, target, symmetry=None):
        m = prebuilt.pop(obj.name, None)
        if m is not None:
            old = obj.data
            obj.data = m
            bpy.data.meshes.remove(old)
            m.name = obj.name
        orig(obj, target, symmetry)
    versions.decimate = decimate


class K:
    """Roblox-axes authoring (x, y up, z back) on a lego.B at a slot origin; Blender = (-x, z, y). lod 0/1/2."""

    def __init__(self, b, ox, lod=0):
        self.b, self.ox, self.lod = b, ox, lod

    def p(self, x, y, z):
        return (-(x + self.ox), z, y)

    def brick(self, lo, hi, c, bev=0.2, bottom=False):
        """Straight-sided brick, chamfered top; bottom only where it hangs in the air; LOD2, or a small chamfer nobody can see the rim of (8 tris cheaper): a box, its sides tapered by that chamfer."""
        if self.lod == 2 or bev <= 0.14:
            self.box(lo, hi, c, bev=min(bev, 0.2), drop=() if bottom else ("bottom",))
        else:
            self.b.brick(self.p(*lo), self.p(*hi), c, bevel=bev, bottom=bottom)

    def box(self, lo, hi, c, bev=None, drop=()):
        ids = {"bottom": 0, "top": 1, "front": 2, "back": 4}
        self.b.box(self.p(*lo), self.p(*hi), c, bevel=bev, drop=tuple(ids[d] for d in drop))

    def cyl(self, x, z, y0, y1, r, c, n=8, bottom=True):
        bx, by, _ = self.p(x, 0, z)
        self.b.cyl(bx, by, y0, y1, r, c, n, bottom=bottom)

    def stud(self, x, y, z, c, r=1.1, h=0.5):
        """A stud on the top at height y (dropped from the LODs); 12 sides on the big ones, 8 on the middling (both bevelled), 6 and no bevel on the small: nobody sees that rim, and they're most of the budget."""
        if not self.lod:
            bx, by, _ = self.p(x, 0, z)
            if r >= 1.2:
                self.b.stud(bx, by, y - SINK, y + h, r, c, 12 if r >= 2.0 else 8)
            else:
                self.b.cyl(bx, by, y - SINK, y + h, r, c, 5 if r < 0.7 else 6, bottom=False)

    def stud_grid(self, x0, x1, z0, z1, y, c, pitch=2.0, r=0.7, h=0.4, skip=None):
        nx, nz = max(1, round((x1 - x0) / pitch)), max(1, round((z1 - z0) / pitch))
        for i in range(nx):
            for j in range(nz):
                x, z = x0 + (i + 0.5) * (x1 - x0) / nx, z0 + (j + 0.5) * (z1 - z0) / nz
                if not (skip and skip(x, z)):
                    self.stud(x, y, z, c, r, h)

    def beam(self, p0, p1, w, h, c):
        self.b.beam(self.p(*p0), self.p(*p1), w, h, c)

    def frustum(self, x, z, rings, c, n=10, rot=0.0):
        """Stacked rings [(y, r)] round a vertical axis, capped both ends."""
        n = max(min(n, 5), n - 2 * self.lod)
        self.b.loft([[self.p(x + r * math.cos(rot + 2 * math.pi * i / n), y, z + r * math.sin(rot + 2 * math.pi * i / n))
                      for i in range(n)] for y, r in rings], c)

    def prism(self, rings, c, smooth=False, bottom=True):
        """A flat-shaded solid through equal-length rings of Roblox points; caps both ends (bottom=False: the first ring open)."""
        n = len(rings[0])
        verts = [self.p(*q) for ring in rings for q in ring]
        faces = [(s * n + i, s * n + (i + 1) % n, (s + 1) * n + (i + 1) % n, (s + 1) * n + i)
                 for s in range(len(rings) - 1) for i in range(n)]
        faces += [tuple(range(n))] if bottom else []
        faces += [tuple(reversed(range((len(rings) - 1) * n, len(rings) * n)))]
        self.b._emit(verts, faces, c, smooth=smooth)

    def ring(self, cx, cy, cz, R, r, colours, seg=8, sub=2, mnr=6):
        """A lifebuoy round the Roblox z axis: seg capped arcs cycling colours."""
        sub, mnr = ((sub, mnr), (1, 6), (1, 4))[self.lod]
        for k in range(seg):
            verts = []
            for i in range(sub + 1):
                u = 2 * math.pi * (k + i / sub) / seg
                for j in range(mnr):
                    v = 2 * math.pi * j / mnr
                    rr = R + r * math.cos(v)
                    verts.append(self.p(cx + rr * math.cos(u), cy + rr * math.sin(u), cz + r * math.sin(v)))
            faces = [(i * mnr + j, (i + 1) * mnr + j, (i + 1) * mnr + (j + 1) % mnr, i * mnr + (j + 1) % mnr)
                     for i in range(sub) for j in range(mnr)]
            self.b._emit(verts, faces, colours[k % len(colours)], smooth=True)

    def tilt(self, start, at, yaw=0.0, pitch=0.0, roll=0.0, lift=(0.0, 0.0, 0.0)):
        """Rigidly turn every vertex emitted since `start` round `at` (yaw about y, then pitch about z, roll about x; degrees)."""
        cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
        cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
        v = self.b.v
        for i in range(start, len(v)):
            x, z, y = -v[i][0] - self.ox - at[0], v[i][1] - at[2], v[i][2] - at[1]
            x, z = x * cy + z * sy, -x * sy + z * cy
            x, y = x * cp - y * sp, x * sp + y * cp
            y, z = y * cr - z * sr, y * sr + z * cr
            v[i] = self.p(x + at[0] + lift[0], y + at[1] + lift[1], z + at[2] + lift[2])


    def grow(self, start, at, s):
        """Scale every vertex emitted since `start` by s round the Roblox point `at`."""
        v = self.b.v
        for i in range(start, len(v)):
            x, z, y = -v[i][0] - self.ox, v[i][1], v[i][2]
            v[i] = self.p(at[0] + (x - at[0]) * s, at[1] + (y - at[1]) * s, at[2] + (z - at[2]) * s)




# ------------------------------------------------------------------ shared bits
def plates(cs, rng):
    """Greedy 2x4, 2x2, 1x2 (either way round) over the cells; a lone 1x1 only where nothing else fits."""
    out, left = [], set(cs)
    for i, j in sorted(cs, key=lambda c: (c[1], c[0])):
        if (i, j) in left:
            shapes = [(4, 2), (2, 4), (2, 2), (2, 1), (1, 2)]
            rng.shuffle(shapes)
            for w, d in shapes + [(1, 1)]:
                need = {(i + a, j + b) for a in range(w) for b in range(d)}
                if need <= left:
                    left -= need
                    out.append((i, j, i + w, j + d))
                    break
    return out
    return out



def gull(k, x, y, z, yaw=0.0):
    """A chunky Lego gull: a small point of life on a rock (LOD0/1 only)."""
    if k.lod == 2:
        return
    at = len(k.b.v)
    k.box((x - 0.35, y - SINK, z - 0.2), (x + 0.35, y + 0.65, z + 0.2), P.YELLOW, bev=0.05, drop=("bottom",))
    k.box((x - 0.8, y + 0.6, z - 1.25), (x + 0.8, y + 2.0, z + 1.1), P.WHITE, bev=0.2)
    k.box((x - 1.05, y + 1.2, z - 0.5), (x + 1.05, y + 1.85, z + 1.5), P.STONE, bev=0.12)
    k.box((x - 0.55, y + 2.0 - SINK, z - 1.5), (x + 0.55, y + 3.0, z - 0.45), P.WHITE, bev=0.14)
    k.box((x - 0.26, y + 2.25, z - 2.2), (x + 0.26, y + 2.65, z - 1.45), P.CORAL, bev=0.06)
    k.tilt(at, (x, y, z), yaw=yaw)



def tier(k, cs, u, ox, oz, y0, y1, colour, rng, stud=None, r=None, h=None, bev=0.3, bottom=False):
    """One course of cs (cells, u studs a cell) in 2x4 / 2x2 bricks; a stud per cell where stud(i, j). LOD1 / LOD2: one box over the cells."""
    if k.lod:
        a, b = min(c[0] for c in cs), min(c[1] for c in cs)
        c, d = max(c[0] for c in cs) + 1, max(c[1] for c in cs) + 1
        k.brick((ox + a * u, y0, oz + b * u), (ox + c * u, y1, oz + d * u), colour(rng), bev=0.3, bottom=bottom)
        return
    for a, b, c, d in plates(cs, rng):
        col = colour(rng)
        k.brick((ox + a * u + 0.06, y0, oz + b * u + 0.06), (ox + c * u - 0.06, y1, oz + d * u - 0.06), col, bev=bev, bottom=bottom)
        for i in range(a, c):
            for j in range(b, d):
                if stud is None or stud(i, j):
                    k.stud(ox + (i + 0.5) * u, y1, oz + (j + 0.5) * u, col, r or 0.3 * u, h or 0.14 * u)


def rect(i0, j0, i1, j1, cut=False):
    """Cells of a rectangle; cut: without its four corners (a stepped outline)."""
    cs = {(i, j) for i in range(i0, i1) for j in range(j0, j1)}
    return cs - {(i0, j0), (i1 - 1, j0), (i0, j1 - 1), (i1 - 1, j1 - 1)} if cut else cs


def greys(rng):
    return P.DBG if rng.random() < 0.35 else P.STONE


STUD_R, STUD_P = 0.57, 2.0     # every base plate's stud as placed in the world: one size, about 40% under r4's (AD r4)


def plate(k, w, d, y0=-1.0, y1=0.5, c=P.DTAN, rim=P.UMBER, clear=None, s=1.0, rows=1):
    """The clean rectangular base a prop stands on (terrain never shows white at its foot): a bevelled darker-tan top, a rim course 0.5 proud, a wide foot when it stands tall enough for one (the downhill side reads as steps).
    Rows of small studs round the edge; clear: (x, z) half-size kept free of studs; s: the layout scale the module is placed at, so studs and steps come out one size."""
    q = 1.0 / s
    mid = y1 - 0.8 * q
    y = y0
    if y0 < mid - 1.6 * q:
        y = mid - 0.9 * q
        k.brick((-w / 2 - 1.6 * q, y0, -d / 2 - 1.6 * q), (w / 2 + 1.6 * q, y, d / 2 + 1.6 * q), P.UMBER, bev=0.2 * q)
        y -= 0.05
    k.brick((-w / 2 - 0.5 * q, y, -d / 2 - 0.5 * q), (w / 2 + 0.5 * q, mid, d / 2 + 0.5 * q), rim, bev=0.16 * q)
    k.brick((-w / 2, mid - 0.05, -d / 2), (w / 2, y1, d / 2), c, bev=0.22 * q)
    ix, iz = clear or (w / 2 - rows * STUD_P * q, d / 2 - rows * STUD_P * q)
    k.stud_grid(-w / 2, w / 2, -d / 2, d / 2, y1, c, pitch=STUD_P * q, r=STUD_R * q, h=0.3 * q, skip=lambda x, z: abs(x) < ix and abs(z) < iz)


def fan(k, x, y, z, R, c0=P.CORAL, c1=P.SAND, depth=1.6):
    """A scallop in the x-y plane: five ribs radiating from a stepped hinge at (x, y, z), coral and cream, each widening in steps; small or far: one brick a rib.
    Each rib's faces sit 0.06 off the others', so where they overlap near the hinge no two share a plane."""
    segs = ((0.16, 0.44, 0.11), (0.45, 0.72, 0.17), (0.73, 1.0, 0.22)) if R >= 8 and k.lod < 2 else ((0.16, 1.0, 0.19),)
    for off, lay in ((0, 0.0), (-1, 0.06), (1, 0.12), (-2, 0.18), (2, 0.24)):
        c = c1 if off % 2 else c0
        L = R * (1.0, 0.95, 0.82)[abs(off)]
        d = depth / 2 - lay
        at = len(k.b.v)
        for f0, f1, w in segs:
            k.brick((x - w * R, y + f0 * L, z - d), (x + w * R, y + f1 * L, z + d), c, bev=min(0.22, 0.06 * R), bottom=True)
        k.tilt(at, (x, y, z), pitch=off * 29.0)
    k.brick((x - 0.17 * R, y - 0.06 * R, z - depth / 2 - 0.06), (x + 0.17 * R, y + 0.2 * R, z + depth / 2 + 0.06), c0, bev=min(0.22, 0.06 * R), bottom=True)


def branch(k, x, z, y, h, c):
    """A branching coral h studs tall standing at (x, y, z): a stem, three stepped arms that turn up, a stud on the tips (LOD2: the stem)."""
    s = h / 5.0
    a, b = 0.55 * s, 0.4 * s
    k.brick((x - a, y - SINK, z - a), (x + a, y + h * 0.72, z + a), c, bev=0.1 * s)
    k.stud(x, y + h * 0.72, z, c, 0.4 * s, 0.22 * s)
    if k.lod == 2:
        return
    for dx, dz, t, l, up in ((1, 0, 0.2, 1.5, 1.0), (-1, 0, 0.36, 1.3, 1.3), (0, 1, 0.5, 1.1, 1.3)):
        y0, e = y + h * t, a + l * s
        x0, x1 = sorted((x + dx * a * 0.5, x + dx * e)) if dx else (x - b, x + b)
        z0, z1 = sorted((z + dz * a * 0.5, z + dz * e)) if dz else (z - b, z + b)
        k.brick((x0, y0, z0), (x1, y0 + 0.7 * s, z1), c, bev=0.08 * s, bottom=True)
        tx, tz = x + dx * (e - b), z + dz * (e - b)
        k.brick((tx - b, y0 + 0.7 * s, tz - b), (tx + b, y0 + (0.7 + up) * s, tz + b), c, bev=0.08 * s)


def drum(k, x, z, y0, y1, r, c, n=12, top=True):
    k.cyl(x, z, y0, y1, r, c, n=(n, n - 2, 6)[k.lod], bottom=False)


# ------------------------------------------------------------------ the mermaid: capsules voxelised into stud-grid bricks
U = 9.1                       # one unit of the code's Kit.mermaid pose = this many studs (the code's scale was 4; 7 until AD r4 asked 1.3x)
PLINTH_TOP = 19.2
CELL = 3.9                    # the statue's brick, grown with her so the voxel count (and the budget) holds
SHIFT = -15.0                 # centres the long pose on the plinth (head at -x, fluke at +x; she faces -z)


def _pt(x, y, z):
    return (x * U + SHIFT, y * U + PLINTH_TOP, z * U)


def _tail_c(i, j, kk, y):
    return P.TEAL if (i // 3) % 2 else P.AQUA


def _skin(i, j, kk, y):
    return P.SKIN


def _hair(i, j, kk, y):
    return P.GOLD


def _top(i, j, kk, y):
    return P.CORAL if 2.75 <= (y - PLINTH_TOP) / U <= 4.0 else P.SKIN      # the bright top over the chest; bare shoulders


def _fluke(i, j, kk, y):
    return P.TEAL


def _belt(i, j, kk, y):
    return P.GOLD


# (p0, r0, p1, r1, colour fn); first match wins, so the head sits in front of the hair and the arms in front of the torso
CAPSULES = [
    ((-1.5, 6.25, 0.0), 1.12, (-1.25, 5.95, 0.95), 1.14, _hair),          # hair: a cap over the crown with a fringe (before the head, so it wins the fringe)
    ((-1.65, 5.5, -0.15), 1.2, (-1.35, 5.5, -0.15), 1.2, _skin),          # head
    ((-2.95, 6.1, 0.05), 0.56, (-3.05, 4.55, 0.3), 0.46, _hair),          # solid gold locks down both sides, framing the face (after the head, so they never cover it)
    ((-0.05, 6.1, 0.05), 0.56, (0.0, 3.9, 0.35), 0.5, _hair),
    ((-1.2, 4.2, 0), 0.55, (-1.45, 4.9, -0.05), 0.55, _skin),             # neck
    ((-0.9, 5.2, 1.15), 1.02, (-0.25, 3.1, 1.6), 0.92, _hair),            # hair: a gold mass down her back
    ((-0.25, 3.1, 1.6), 0.92, (0.35, 1.7, 1.65), 0.64, _hair),
    ((-1.0, 3.5, 0), 1.5, (-0.55, 2.75, 0), 1.26, _top),                  # chest, one stud wider a side
    ((-0.55, 2.75, 0), 1.26, (-0.2, 2.0, 0), 1.06, _skin),                # waist: two brick courses, narrow, so the tail reads as starting below it
    ((-0.2, 2.0, 0), 1.24, (0.0, 1.65, 0), 1.28, _belt),                  # a gold belt where the scales begin
    ((0.0, 1.4, 0), 1.36, (1.4, 1.2, 0), 1.42, _tail_c),                  # hips and tail, along the plinth, then curling up
    ((1.4, 1.2, 0), 1.42, (3.2, 1.05, -0.2), 1.18, _tail_c),
    ((3.2, 1.05, -0.2), 1.18, (4.6, 1.1, -0.4), 0.95, _tail_c),
    ((4.6, 1.1, -0.4), 0.95, (5.6, 2.0, -0.4), 0.76, _tail_c),
    ((5.6, 2.0, -0.4), 0.76, (5.9, 3.2, -0.4), 0.64, _tail_c),
    ((5.9, 3.3, -0.4), 0.72, (4.5, 5.0, -0.4), 0.42, _fluke),             # fluke, grown out of the tail's tip
    ((5.9, 3.3, -0.4), 0.72, (7.5, 4.7, -0.4), 0.42, _fluke),
]
SHELL_AT = (-4.5, 7.2, -1.1)      # the hinge, in the raised hand; the fan opens up in the x-y plane
# the arms are short stepped bricks, not 3-stud voxels (AD r3: staircase): (p0, r0, p1, r1), each segment 0.03 thinner than the last so elbows never share a plane
ARMS = (((-2.0, 4.05, -0.85), 0.62, (-4.2, 5.0, -1.1), 0.6), ((-4.2, 5.0, -1.1), 0.57, (-4.5, 7.2, -1.1), 0.54),      # raised: arm and wrist two bricks thick
        ((-1.7, 3.9, 1.1), 0.6, (-2.6, 2.1, 1.2), 0.58), ((-2.6, 2.1, 1.2), 0.55, (-3.4, 0.4, 0.8), 0.52))            # propping, hand on the plinth


def arms(k):
    step = (3.25, 6.0, 11.0)[k.lod]
    for p0, r0, p1, r1 in ARMS:
        a, b = _pt(*p0), _pt(*p1)
        ax = max(range(3), key=lambda q: abs(b[q] - a[q]))
        n = max(1, round(abs(b[ax] - a[ax]) / step))
        for i in range(n):
            t = (i + 0.5) / n
            c = [a[q] + (b[q] - a[q]) * t for q in range(3)]
            r = (r0 + (r1 - r0) * t) * U
            lo, hi = [v - r for v in c], [v + r for v in c]
            e0, e1 = sorted((a[ax] + (b[ax] - a[ax]) * i / n, a[ax] + (b[ax] - a[ax]) * (i + 1) / n))
            lo[ax], hi[ax] = e0 + 0.03, e1 - 0.03
            lo[1] = max(lo[1], PLINTH_TOP)
            k.brick(tuple(lo), tuple(hi), P.SKIN, bev=0.22, bottom=lo[1] > PLINTH_TOP)


def voxels(cell, course):
    """{(i, j, k): colour}, cell studs across and course studs tall, over the capsules; nothing below the plinth top."""
    out = {}
    for p0, r0, p1, r1, fn in CAPSULES:
        a, b = _pt(*p0), _pt(*p1)
        ra, rb = r0 * U, r1 * U
        rm = max(ra, rb)
        lo = [min(a[q], b[q]) - rm for q in range(3)]
        hi = [max(a[q], b[q]) + rm for q in range(3)]
        d = [b[q] - a[q] for q in range(3)]
        dd = sum(v * v for v in d) or 1.0
        for i in range(math.floor(lo[0] / cell), math.ceil(hi[0] / cell)):
            for kk in range(math.floor(lo[2] / cell), math.ceil(hi[2] / cell)):
                for j in range(max(0, math.floor((lo[1] - PLINTH_TOP) / course)), math.ceil((hi[1] - PLINTH_TOP) / course)):
                    if (i, j, kk) in out:
                        continue
                    q = ((i + 0.5) * cell, PLINTH_TOP + (j + 0.5) * course, (kk + 0.5) * cell)
                    t = max(0.0, min(1.0, sum((q[n] - a[n]) * d[n] for n in range(3)) / dd))
                    near = [a[n] + d[n] * t for n in range(3)]
                    if math.dist(q, near) <= ra + (rb - ra) * t:
                        out[(i, j, kk)] = fn(i, j, kk, q[1])
    return out


def sculpt(k, cells, cell, course):
    """Greedy bricks per course and colour, the long way alternating so seams stagger; a stud on every bare top; enclosed bricks culled."""
    for j in sorted({c[1] for c in cells}):
        layer = {(c[0], c[2]): v for c, v in cells.items() if c[1] == j}
        left = dict(layer)
        shapes = [(4, 2), (3, 2), (2, 2), (4, 1), (3, 1), (2, 1), (1, 2), (1, 1)]
        if j % 2:
            shapes = [(d, w) for w, d in shapes]
        for (i, kk) in sorted(layer):
            if (i, kk) not in left:
                continue
            col = left[(i, kk)]
            for w, d in shapes:
                need = [(i + a, kk + b) for a in range(w) for b in range(d)]
                if all(left.get(n) == col for n in need):
                    break
            for n in need:
                del left[n]
            hidden = all((n[0], j + 1, n[1]) in cells and all((n[0] + a, n[1] + b) in layer for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                         for n in need)
            if hidden:
                continue
            under = j > 0 and any((n[0], j - 1, n[1]) not in cells for n in need)
            y0 = PLINTH_TOP + j * course
            k.brick((i * cell + 0.06, y0, kk * cell + 0.06), ((i + w) * cell - 0.06, y0 + course, (kk + d) * cell - 0.06), col, bev=0.22, bottom=under)
            for n in need:
                if (n[0], j + 1, n[1]) not in cells and (n[0] + n[1]) % 3 == 0:
                    k.stud((n[0] + 0.5) * cell, y0 + course, (n[1] + 0.5) * cell, col, 0.3 * cell, 0.2 * cell)


def statue(k):
    cell = course = (CELL, 5.5, 7.5)[k.lod]
    cells = voxels(cell, course)
    sculpt(k, cells, cell, course)
    arms(k)
    sx, sy, sz = _pt(*SHELL_AT)
    fan(k, sx, sy, sz, 28.6, depth=5.2)
    if k.lod < 2:                           # a face on the head's front cells: big dark eyes with a highlight, a smile with its corners up
        _, hy, _ = _pt(-1.5, 5.5, -0.15)
        row = [c[0] for c in cells if c[1] == math.floor((hy - PLINTH_TOP) / course) and cells[c] == P.SKIN and c[2] * cell < -1.0]
        hx = (min(row) + max(row) + 1) * cell / 2
        def mark(x0, x1, y0, y1, c):
            j = math.floor(((y0 + y1) / 2 - PLINTH_TOP) / course)
            cols = range(math.floor(x0 / cell), math.floor(x1 / cell) + 1)
            z = min((q[2] for q in cells if q[0] in cols and q[1] == j), default=0) * cell + 0.06
            k.box((x0, y0, z - 0.06), (x1, y1, z + cell), c, bev=0.05, drop=("back",))
            return z
        for q in (-1, 1):
            z = mark(hx + q * 5.6 - 3.1, hx + q * 5.6 + 3.1, hy - 0.6, hy + 7.8, P.INK)
            k.box((hx + q * 5.6 - 2.2, hy + 4.4, z - 0.14), (hx + q * 5.6 - 0.2, hy + 6.8, z + 0.1), P.WHITE, bev=0.03)
            mark(hx + q * 5.0 - 1.2, hx + q * 5.0 + 1.2, hy - 5.6, hy - 3.4, P.RED)
        mark(hx - 3.7, hx + 3.7, hy - 7.2, hy - 5.0, P.RED)


def shell(cs, above):
    """cs without the cells no eye reaches: covered by what's above and walled in on all four sides."""
    return {c for c in cs if c not in above or any((c[0] + a, c[1] + b) not in cs for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


def statue_plinth(k):
    """Two-tier coral-and-shell plinth (stud-grid plan, 8 studs a cell) on a tan waterline ledge with tide pools: each tier in courses stepping in round a dark seam, coral below a teal trim course, cream above with big gold shells; coral clusters on the ledge."""
    rng = random.Random(51)
    u = 8.0
    t0, t1, t2 = rect(-8, -4, 8, 4, cut=True), rect(-7, -3, 7, 3, cut=True), rect(-6, -2, 6, 2, cut=True)
    pools = ((-39.0, -31.0, -25.0, -26.0), (25.0, 26.0, 39.0, 31.0))
    trim, top = 8.0, PLINTH_TOP
    seam = 0.4 if k.lod == 0 else 0.0                # the gap between courses, the dark backing shows through it
    if k.lod == 0:                                   # dark backing behind the seams of the walled-in shell, a cross so the stepped corners are backed too
        k.box((-7 * u + 0.1, -22.0, -3 * u + 0.1), (7 * u - 0.1, 1.2, 3 * u - 0.1), P.DTAN, bev=0, drop=("bottom",))
        for a, b, c, d, y0, y1 in ((6, 3, 7, 2, 1.6, trim), (5, 2, 6, 1, trim, top)):
            k.box((-a * u + 1.2, y0, -b * u + 1.2), (a * u - 1.2, y1, b * u - 1.2), P.INK, bev=0, drop=("bottom", "top"))
            k.box((-c * u + 1.3, y0, -d * u + 1.3), (c * u - 1.3, y1, d * u - 1.3), P.INK, bev=0, drop=("bottom", "top"))
    keep_clear = {(-4, -4), (4, 3), (6, 2)}
    foot = {(math.floor((c[0] * CELL + CELL / 2) / u), math.floor((c[2] * CELL + CELL / 2) / u)) for c in voxels(CELL, CELL) if c[1] == 0} if k.lod == 0 else set()
    coral = lambda r: P.CORAL if r.random() < 0.75 else P.MAGENTA if r.random() < 0.4 else P.SAND
    shellc = lambda r: P.SAND if r.random() < 0.7 else P.WHITE
    none = lambda i, j: False
    tier(k, t0, u, 0, 0, -22.0, 1.6, lambda _: P.TAN, rng, stud=lambda i, j: (i, j) not in t1 and i % 2 == 0 and j % 2 == 0 and (i, j) not in keep_clear, r=1.1, h=0.4)
    tier(k, shell(t1, t1), u, 0, 0, 1.6, 3.9, coral, rng, stud=none)
    tier(k, shell(t1, t1), u - 0.08, 0, 0, 3.9 + seam, 6.0, coral, rng, stud=none)
    tier(k, shell(t1, t2), u, 0, 0, 6.0 + seam, trim, lambda _: P.TEAL, rng, stud=lambda i, j: (i, j) not in t2 and (i + j) % 2 == 0, r=1.1, h=0.4)
    tier(k, shell(t2, t2), u, 0, 0, trim, 11.6, shellc, rng, stud=none)
    tier(k, shell(t2, t2), u - 0.08, 0, 0, 11.6 + seam, 15.2, shellc, rng, stud=none)
    tier(k, t2, u - 0.16, 0, 0, 15.2 + seam, top, shellc, rng, stud=lambda i, j: (i, j) not in foot and (i + j) % 2 == 0, r=1.1, h=0.4)
    if k.lod < 2:                                    # tide pools in the ledge, big gold shells on the upper tier
        for x0, z0, x1, z1 in pools:
            k.brick((x0, 1.2, z0), (x1, 1.68, z1), P.TIDE, bev=0.06)
        for x, z in ((-27.0, -1), (0.0, -1), (27.0, -1), (0.0, 1)):
            fan(k, x, trim + 0.5, z * (2 * u + 0.7), 7.6, P.GOLD, P.YELLOW, depth=1.2)
    for x, z, a in ((-52.0, -20.0, P.MAGENTA), (52.0, -20.0, P.ORANGE), (-52.0, 20.0, P.YELLOW), (52.0, 20.0, P.MAGENTA), (-5.7, -28.0, P.ORANGE)):
        branch(k, x, z, 1.6, 5.6, a)                     # chunky clusters on the ledge


# ------------------------------------------------------------------ day mark, telescope, stamp post
def daymark(k):
    plate(k, 15.0, 15.0, -3.0, 0.5)
    for s in (-1, 1):
        k.brick((s * 0.04, 0.5, -5.2), (s * 5.2, 2.0, 5.2), P.STONE, bev=0.2)
    y = 2.0
    for i in range(10):
        d = (8.0 - i * 0.45) / 2
        c = P.RED if i % 2 == 0 else P.WHITE
        if k.lod:
            k.box((-d, y, -d), (d, y + 5.0, d), c, bev=0.1, drop=("bottom",))
        else:
            for q, s in ((0, -1), (0, 1), (1, -1), (1, 1)):
                y0, y1 = y + q * 2.5, y + (q + 1) * 2.5
                if q == 0:
                    k.brick((min(0, s * d) + 0.03, y0, -d), (max(0, s * d) - 0.03, y1, d), c, bev=0.18, bottom=False)
                else:
                    k.brick((-d + 0.02, y0, min(0, s * d) + 0.03), (d - 0.02, y1, max(0, s * d) - 0.03), c, bev=0.18, bottom=False)
        y += 5.0
    k.brick((-3.0, y, -3.0), (3.0, y + 0.8, 3.0), P.INK, bev=0.15, bottom=True)
    k.cyl(0, 0, y + 0.75, y + 7.1, 0.65, P.INK, n=(10, 8, 6)[k.lod], bottom=False)
    k.brick((-2.5, y + 7, -2.5), (2.5, y + 9.4, 2.5), P.RED, bev=0.2, bottom=True)
    k.brick((-2.6, y + 9.4, -2.6), (2.6, y + 10.4, 2.6), P.WHITE, bev=0.15)
    k.brick((-2.0, y + 10.4, -2.0), (2.0, y + 12.0, 2.0), P.RED, bev=0.2)
    k.stud(0, y + 12.0, 0, P.RED, 1.2, 0.5)


def telescope(k):
    plate(k, 6.0, 6.0, -1.0, 0.4, clear=(1.1, 1.1))
    k.brick((-0.6, 0.4, -0.6), (0.6, 4.0, 0.6), P.INK, bev=0.12)
    tube = len(k.b.v)
    k.box((-0.7, 4.0, -2.4), (0.7, 5.2, 0.6), P.YELLOW, bev=0.12)
    k.box((-0.9, 3.8, 0.6), (0.9, 5.4, 2.6), P.YELLOW, bev=0.14)
    k.box((-0.5, 4.2, -3.2), (0.5, 5.0, -2.35), P.INK, bev=0.08)
    k.tilt(tube, (0, 4.6, 0), roll=-8.0)


def stamp_post(k):
    plate(k, 6.0, 6.0, -1.0, 0.4, clear=(1.1, 1.1))
    k.brick((-0.8, 0.4, -0.8), (0.8, 4.4, 0.8), P.WHITE, bev=0.14)
    k.brick((-1.6, 4.4, -1.3), (1.6, 6.6, 1.3), P.RED, bev=0.2, bottom=True)
    k.brick((-1.9, 6.6, -1.6), (1.9, 7.1, 1.6), P.INK, bev=0.12, bottom=True)
    k.stud(0, 7.1, 0, P.YELLOW, 0.9, 0.35)
    k.box((-1.1, 4.8, -1.45), (1.1, 6.0, -1.25), P.YELLOW, bev=0.04)         # the brass plate, on the café side (yaw 180)
    k.box((-0.7, 5.5, -1.52), (0.7, 5.8, -1.4), P.INK, bev=0.02)


# ------------------------------------------------------------------ jetty (origin = island.dock at sea level, y = world y)
DECK, HZ1, HZ2, STAIR_END, Z0, TOP = 3.5, 6.0, 16.0, 116.8, 136.0, 12.5


def jetty(k):
    lod = k.lod
    # deck: four plank strips, staggered lengths, stud rows along both edges
    for s, px in enumerate((-3, -1, 1, 3)):
        c = P.TAN if s % 2 else P.DTAN
        cuts = [HZ2] + [z for z in (HZ2 + 5.0 + 6.0 * s + 16.0 * q for q in range(6)) if z < STAIR_END - 3.0] + [STAIR_END]
        if lod == 2:
            cuts = [HZ2, STAIR_END]
        for a, b in zip(cuts, cuts[1:]):
            k.brick((px - 0.95, DECK - 0.5, a + 0.05), (px + 0.95, DECK, b - 0.05), c, bev=0.14, bottom=True)
    for sx in (-1, 1):                                  # the plank path's studded kerb, in lengths
        for q in range(5 if lod < 2 else 1):
            a, b = (HZ2 + q * 20.1 + 0.05, HZ2 + (q + 1) * 20.1 - 0.05) if lod < 2 else (HZ2, STAIR_END)
            k.brick((sx * 4.0 - 0.55, DECK - 0.45, a), (sx * 4.0 + 0.55, DECK + 0.45, b), P.UMBER, bev=0.14, bottom=True)
        for q in range(16):
            k.stud(sx * 4.0, DECK + 0.45, HZ2 + 3.0 + q * 6.3, P.UMBER, 0.42, 0.2)
    z = STAIR_END - 2.0
    n = 0
    while z > HZ2:                                      # pile bents every 12 studs
        if lod < 2 or n % 3 == 0:
            k.brick((-4.6, DECK - 1.3, z - 0.5), (4.6, DECK - 0.52, z + 0.5), P.BROWN, bev=0.1, bottom=True)
            for sx in (-3.9, 3.9):
                k.cyl(sx, z, -12.0, DECK - 1.25, 0.6, P.BROWN, n=(8, 6, 5)[lod], bottom=False)
        z -= 12.0
        n += 1
    # T-head
    for i in range(5):
        c = P.TAN if i % 2 else P.DTAN
        if lod == 2 and i:
            continue
        a, b = (HZ1 + i * 2, HZ1 + i * 2 + 1.94) if lod < 2 else (HZ1, HZ2)
        k.brick((-12.0, DECK - 0.5, a), (12.0, DECK, b), c, bev=0.14, bottom=True)
    for sx in (-8.0, 0.0, 8.0):
        for hz in (HZ1 + 1.0, HZ2 - 1.0):
            k.stud(sx - 2.0, DECK, hz, P.TAN, 0.7, 0.3)
            k.stud(sx + 2.0, DECK, hz, P.TAN, 0.7, 0.3)
    for sx in (-11.5, -4.0, 4.0, 11.5):
        for hz in (HZ1 + 0.6, HZ2 - 0.6):
            if lod < 2 or sx in (-11.5, 11.5):
                k.cyl(sx, hz, -12.0, DECK + 1.6, 0.75, P.BROWN, n=(8, 6, 5)[lod])
                k.stud(sx, DECK + 1.6, hz, P.TAN, 0.48, 0.2)
    for s in (-1, 1):                                   # bollards
        if lod < 2:
            k.brick((s * 8 - 0.8, DECK, HZ1 + 0.6), (s * 8 + 0.8, DECK + 1.2, HZ1 + 2.2), P.INK, bev=0.14)
            k.brick((s * 8 - 1.1, DECK + 1.2, HZ1 + 0.3), (s * 8 + 1.1, DECK + 1.7, HZ1 + 2.5), P.INK, bev=0.12, bottom=True)
    # lamp (code keeps its PointLight at ATT_Lamp) and pennant
    k.cyl(10.0, HZ2 - 1.5, DECK - 0.05, DECK + 9.0, 0.45, P.INK, n=(10, 8, 5)[lod], bottom=False)
    k.brick((9.1, DECK + 9.0, HZ2 - 2.4), (10.9, DECK + 11.0, HZ2 - 0.6), P.YELLOW, bev=0.15, bottom=True)
    k.brick((8.9, DECK + 11.0, HZ2 - 2.6), (11.1, DECK + 11.5, HZ2 - 0.4), P.INK, bev=0.12, bottom=True)
    k.cyl(-10.0, HZ2 - 1.5, DECK - 0.05, DECK + 13.0, 0.35, P.WHITE, n=(8, 6, 5)[lod], bottom=False)
    for i, (a, b, c) in enumerate(((0.3, 3.0, P.RED), (3.0, 5.6, P.WHITE), (5.6, 7.8, P.RED))):
        k.brick((-10 + a + 0.02, DECK + 9.8 + i * 0.35, HZ2 - 1.7), (-10 + b - 0.02, DECK + 12.8 - i * 0.35, HZ2 - 1.3), c, bev=0.08, bottom=True)
    # stairs from the dune edge down to the deck, side stringers and white rails; landing on top
    k.brick((-4.0, TOP - 1.2, Z0 + 1.0), (4.0, TOP, Z0 + 7.0), P.TAN, bev=0.18, bottom=True)
    for i in range(1, 13):
        y = TOP - 0.75 * i
        c = P.DTAN if i % 2 else P.TAN
        if lod < 2 or i % 3 == 0:
            k.brick((-3.0, y - 0.7, Z0 - 1.6 * i), (3.0, y, Z0 - 1.6 * (i - 1) - 0.04), c, bev=0.1, bottom=True)
    for sx in (-3.5, 3.5):
        k.beam((sx, TOP - 1.2, Z0 + 0.6), (sx, DECK - 0.8, STAIR_END), 0.9, 1.4, P.BROWN)
        if lod < 2:
            k.beam((sx, TOP + 2.8, Z0 + 0.6), (sx, DECK + 2.8, STAIR_END), 0.5, 0.5, P.WHITE)
            for q in range(4):
                z = Z0 - q * 6.2
                y = TOP - (Z0 - z) * 0.75 / 1.6
                k.brick((sx - 0.3, y - 0.6, z - 0.3), (sx + 0.3, y + 3.0, z + 0.3), P.WHITE, bev=0.08, bottom=True)
    for z in (STAIR_END + 8.0, Z0 - 2.0):
        if lod < 2:
            k.cyl(-3.5, z, -12.0, TOP - 0.75 * (Z0 - z) / 1.6 - 0.8, 0.6, P.BROWN, n=8, bottom=False)
            k.cyl(3.5, z, -12.0, TOP - 0.75 * (Z0 - z) / 1.6 - 0.8, 0.6, P.BROWN, n=8, bottom=False)


# ------------------------------------------------------------------ café (origin = pad centre x, pad.y, z 4993; floorTop 0.6)
FT, CH = 0.6, 9.0
CG = 1.22                     # the shack (walls, roof, awning, crest) grows by this round its back wall; the terrace keeps the pad's size
MARK = 1.4                    # the crest on top of that (AD r3)
CONE = 0.75                   # the ice-cream tower, 25% under r4's: straight on its post, clear of the crest (AD r4)
CONE_X, CONE_Z = 19.5, -9.0   # the cone's own post, on the terrace beside the hatch: clear of the door, of the crest and of her sightline from the landing
SZ1, SZ2, SX = -28.0, -14.0, 11.0


def course_x(k, x0, x1, z, t, y0, y1, c, L, offset, c2=None):
    """A running-bond course along x."""
    a = x0 + offset if offset else x0
    cuts = [x0]
    while a + L < x1 - 0.5:
        a += L
        cuts.append(a)
    cuts.append(x1)
    for i, (p, q) in enumerate(zip(cuts, cuts[1:])):
        k.brick((p + 0.04, y0, z - t / 2), (q - 0.04, y1, z + t / 2), c2 if c2 is not None and i % 3 == 1 else c, bev=0.12)


def course_z(k, z0, z1, x, t, y0, y1, c, L, offset, c2=None):
    a, cuts = z0 + offset if offset else z0, [z0]
    while a + L < z1 - 0.5:
        a += L
        cuts.append(a)
    cuts.append(z1)
    for i, (p, q) in enumerate(zip(cuts, cuts[1:])):
        k.brick((x - t / 2, y0, p + 0.04), (x + t / 2, y1, q - 0.04), c2 if c2 is not None and i % 3 == 1 else c, bev=0.12)


def cafe(k):
    lod = k.lod
    # floor: 4 x 4 pavers with a stud each (LOD1: planks), 0.05 seams over a dark skirt, a teal border course standing 0.3 proud
    if lod < 2:
        k.box((-22.95, -7.0, -28.95), (22.95, -0.1, 28.95), P.DTAN, bev=0, drop=("bottom",))
    if lod == 2:
        k.brick((-23.0, -7.0, -29.0), (23.0, FT, 29.0), P.TAN, bev=0.2)
    elif lod == 1:
        z = -28.0
        row = 0
        while z < 27.9:
            cuts = (-22.0, -8.0, 7.0, 22.0) if row % 2 else (-22.0, 0.0, 22.0)
            for a, b in zip(cuts, cuts[1:]):
                k.brick((a + 0.05, -0.6, z + 0.05), (b - 0.05, FT, z + 5.55), P.TAN if (row + round(a)) % 2 else P.TEAL, bev=0.16)
            z += 5.6
            row += 1
    else:
        tables = ((-13.0, 7.0), (0.0, 17.0), (13.0, 7.0))
        xs = (-22.0, -14.0, -7.0, 0.0, 7.0, 14.0, 22.0)
        rows = ((-28.0, -18.0), (-18.0, -8.0), (-6.0, 2.0), (2.0, 10.0), (12.0, 20.0), (20.0, 28.0))
        for j, (z0, z1) in enumerate(rows):                 # 8 x 8 plates, teal and warm tan checker, inset 0.05, a full stud grid
            for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
                if z1 <= -8.0 and abs(x0 + x1) < 28.0:      # under the grown shack: one slab below
                    continue
                c = P.TAN if (i + j) % 2 else P.TEAL
                k.brick((x0 + 0.05, -0.6, z0 + 0.05), (x1 - 0.05, FT, z1 - 0.05), c, bev=0.14)
                for fx, fz in ((0.25, 0.25), (0.75, 0.25), (0.25, 0.75), (0.75, 0.75)):
                    x, z = x0 + fx * (x1 - x0), z0 + fz * (z1 - z0)
                    if not any(abs(x - a) < 5.5 and abs(z - b) < 2.5 for a, b in tables) and not (abs(x - CONE_X) < 3.2 and abs(z - CONE_Z) < 3.2):
                        k.cyl(x, z, FT - SINK, FT + 0.22, 0.66, c, n=5, bottom=False)
        k.brick((-13.975, -0.6, -27.975), (13.975, FT, -8.025), P.TAN, bev=0.14)
        for a, b in ((-22.0, -7.525), (-7.475, 7.475), (7.525, 22.0)):                 # two inlay bands across the terrace
            k.brick((a + 0.05, -0.6, -7.95), (b, FT, -6.05), P.UMBER, bev=0.1)
            k.brick((a + 0.05, -0.6, 10.05), (b, FT, 11.95), P.UMBER, bev=0.1)
    # the kerb: square bevelled white and teal bricks, 0.5 proud, in lengths round the terrace; far: four teal strips
    KY = (-0.6, FT + 0.5)
    if lod == 2:
        for z0, z1 in ((-29.0, -28.0), (28.0, 29.0)):
            k.brick((-23.0, KY[0], z0), (23.0, KY[1], z1), P.TEAL, bev=0.14)
        for x0, x1 in ((-23.0, -22.0), (22.0, 23.0)):
            k.brick((x0, KY[0], -27.95), (x1, KY[1], 27.95), P.TEAL, bev=0.14)
    else:
        L = 46.0 / 8
        for i in range(8):
            for z0, z1, o in ((-29.0, -28.0, 0), (28.0, 29.0, 1)):
                k.brick((-23.0 + i * L + 0.03, KY[0], z0), (-23.0 + (i + 1) * L - 0.03, KY[1], z1), P.WHITE if (i + o) % 2 else P.TEAL, bev=0.16)
        for j in range(10):
            for x0, x1, o in ((-23.0, -22.0, 1), (22.0, 23.0, 0)):
                k.brick((x0, KY[0], -28.0 + j * 5.6 + 0.03), (x1, KY[1], -28.0 + (j + 1) * 5.6 - 0.03), P.WHITE if (j + o) % 2 else P.TEAL, bev=0.16)
    at = len(k.b.v)                                  # the shack is built at its old size, then grown 1.22x (CG) round its back wall
    # shack walls: running-bond aqua courses, white corner pillars, a counter across the front, door in the east wall
    h = 2.25
    if lod == 2:
        k.brick((-SX, FT, SZ1), (SX, FT + CH, SZ1 + 0.8), P.TEAL, bev=0.1)
        k.brick((-SX, FT, SZ1 + 0.8), (-SX + 0.8, FT + CH, SZ2), P.TEAL, bev=0.1)
        k.brick((SX - 0.8, FT, SZ1 + 0.8), (SX, FT + CH, SZ2), P.TEAL, bev=0.1)
        k.brick((-SX, FT, SZ2 - 0.8), (SX, FT + 3.6, SZ2), P.TEAL, bev=0.1)
    else:
        for i in range(4):
            y0, y1 = FT + i * h, FT + (i + 1) * h
            off = 2.5 if i % 2 else 0.0
            wall, alt = (P.TEAL, P.AQUA) if i % 2 == 0 else (P.AQUA, P.TEAL)         # alternate teal courses, a contrast brick every third: the seams read, pale walls wash out on a phone
            course_x(k, -SX + 0.5, SX - 0.5, SZ1 + 0.4, 0.8, y0, y1, wall, 5.0, off, alt)
            course_z(k, SZ1 + 0.8, SZ2 - 0.5, -SX + 0.4, 0.8, y0, y1, wall, 5.0, off, alt)
            if i < 3:                                # the door: 5.6 wide, 6.75 tall
                course_z(k, SZ1 + 0.8, -24.0, SX - 0.4, 0.8, y0, y1, wall, 5.0, 0.0, alt)
                course_z(k, -18.4, SZ2 - 0.5, SX - 0.4, 0.8, y0, y1, wall, 5.0, 0.0, alt)
            else:
                course_z(k, SZ1 + 0.8, SZ2 - 0.5, SX - 0.4, 0.8, y0, y1, wall, 5.0, 0.0, alt)
    for x in (-SX, SX):
        for z in (SZ1 + 0.5, SZ2 - 0.5):
            k.brick((x - 0.65, FT, z - 0.65), (x + 0.65, FT + CH, z + 0.65), P.WHITE, bev=0.14)
    if lod < 2:
        for z0, z1 in ((-25.5, -23.9), (-18.5, -16.9)):                # thick navy door frame, proud of the trim, same 5-stud opening
            k.brick((SX - 0.95, FT, z0), (SX + 0.75, FT + 6.75, z1), P.INK, bev=0.08)
        k.brick((SX - 0.95, FT + 6.75, -25.5), (SX + 0.75, FT + 8.3, -16.9), P.INK, bev=0.1, bottom=True)
        for i in range(2):                           # counter: two courses
            course_x(k, -SX + 0.8, SX - 0.8, SZ2 - 0.4, 0.8, FT + i * 1.8, FT + (i + 1) * 1.8, P.TEAL, 5.5, 2.5 if i else 0.0)
        for s in (-1, 1):                            # hatch pillars, lintel: navy
            k.brick((s * 9.95 - 1.0, FT + 3.6, SZ2 - 0.75), (s * 9.95 + 0.9, FT + CH, SZ2 - 0.05), P.INK, bev=0.1)
        course_x(k, -8.95, 8.95, SZ2 - 0.4, 0.7, FT + CH - 1.6, FT + CH, P.INK, 6.0, 0.0)
        y0, y1 = FT + 3.0, FT + 7.2                  # two windows: navy frames proud of the walls, a pane behind
        for a, b in ((-24.2, -17.8),):               # west wall
            k.box((-SX - 0.1, y0 + 0.5, a + 0.5), (-SX + 0.05, y1 - 0.5, b - 0.5), P.TIDE, bev=0.02, drop=("bottom", "top"))
            k.brick((-SX - 0.4, y0, a), (-SX + 0.05, y0 + 0.75, b), P.INK, bev=0.06)
            k.brick((-SX - 0.4, y1 - 0.75, a), (-SX + 0.05, y1, b), P.INK, bev=0.06)
            k.brick((-SX - 0.4, y0 + 0.8, a), (-SX + 0.05, y1 - 0.8, a + 0.75), P.INK, bev=0.06)
            k.brick((-SX - 0.4, y0 + 0.8, b - 0.75), (-SX + 0.05, y1 - 0.8, b), P.INK, bev=0.06)
        for a, b in ((-7.5, -1.5), (1.5, 7.5)):      # back wall, seen from the landing
            k.box((a + 0.5, y0 + 0.5, SZ1 - 0.1), (b - 0.5, y1 - 0.5, SZ1 + 0.05), P.TIDE, bev=0.02, drop=("bottom", "top"))
            k.brick((a, y0, SZ1 - 0.4), (b, y0 + 0.75, SZ1 + 0.05), P.INK, bev=0.06)
            k.brick((a, y1 - 0.75, SZ1 - 0.4), (b, y1, SZ1 + 0.05), P.INK, bev=0.06)
            k.brick((a, y0 + 0.8, SZ1 - 0.4), (a + 0.75, y1 - 0.8, SZ1 + 0.05), P.INK, bev=0.06)
            k.brick((b - 0.75, y0 + 0.8, SZ1 - 0.4), (b, y1 - 0.8, SZ1 + 0.05), P.INK, bev=0.06)
    if lod < 2:                                      # 0.3-stud red trim: a foot course round the shack, a band under the eaves; stools and a menu tile at the hatch
        for x0, x1, z0, z1, ys in ((-SX + 0.7, SX - 0.7, SZ1 - 0.3, SZ1 + 0.05, (0.0, 8.0)), (-SX + 0.7, SX - 0.7, SZ2 - 0.05, SZ2 + 0.3, (0.0,)),
                                   (-SX - 0.3, -SX + 0.05, SZ1 + 0.7, SZ2 - 0.7, (0.0, 8.0)), (SX - 0.05, SX + 0.3, SZ1 + 0.7, -25.55, (0.0,)),
                                   (SX - 0.05, SX + 0.3, -16.85, SZ2 - 0.7, (0.0,)), (SX - 0.05, SX + 0.3, SZ1 + 0.7, SZ2 - 0.7, (8.3,))):
            for y in ys:
                k.brick((x0, FT + y, z0), (x1, FT + y + 0.7, z1), P.RED, bev=0.08, bottom=y > 0)
        for x in (-7.5, -3.5, 0.5):
            k.cyl(x, SZ2 + 2.0, FT - SINK, FT + 2.1, 0.28, P.INK, n=6, bottom=False)
            k.cyl(x, SZ2 + 2.0, FT + 2.1, FT + 2.6, 0.95, P.RED, n=10)
        k.box((3.2, FT + 0.9, SZ2 - 0.05), (8.6, FT + 3.4, SZ2 + 0.14), P.INK, bev=0.03, drop=("back",))
        k.box((3.5, FT + 1.15, SZ2 - 0.05), (8.3, FT + 2.55, SZ2 + 0.2), P.SAND, bev=0.03, drop=("back",))
        k.box((3.5, FT + 2.6, SZ2 - 0.05), (8.3, FT + 3.15, SZ2 + 0.2), P.CORAL, bev=0.03, drop=("back",))
    k.brick((-9.5, FT + 3.6, SZ2 - 0.9), (9.5, FT + 3.95, SZ2 + 1.3), P.SAND, bev=0.1, bottom=True)
    for x in (-8.0, -4.0, 0.0, 4.0, 8.0):
        k.stud(x, FT + 3.95, SZ2 + 0.6, P.SAND, 0.68, 0.28)
    if lod < 2:                                      # inside: fridge, coffee machine, shelf of bottles
        k.brick((-9.5, FT, SZ1 + 1.0), (-6.3, FT + 6.0, SZ1 + 3.6), P.WHITE, bev=0.16)
        k.box((-6.3, FT + 2.5, SZ1 + 3.4), (-6.0, FT + 4.6, SZ1 + 3.8), P.INK, bev=0.03)
        k.brick((2.8, FT + 3.95, SZ2 - 2.2), (5.4, FT + 6.1, SZ2 - 0.95), P.RED, bev=0.14, bottom=True)
        k.brick((-3.0, FT + 5.7, SZ1 + 0.8), (7.0, FT + 6.0, SZ1 + 2.0), P.TAN, bev=0.06, bottom=True)
        for i, c in enumerate((P.CORAL, P.YELLOW, P.TEAL, P.GREEN, P.CORAL, P.YELLOW)):
            k.cyl(-2.0 + i * 1.6, SZ1 + 1.4, FT + 6.0 - SINK, FT + 7.2, 0.45, c, n=8, bottom=False)
    # ceiling, so the inside never shows the roof's back
    k.box((-SX + 0.4, FT + CH - 0.25, SZ1 + 0.4), (SX - 0.4, FT + CH + 0.02, SZ2 - 0.4), P.WHITE, bev=0, drop=("top",))
    # the striped roof: four stepped courses a side, ridge along x, 8 strips (the code's red/white)
    eave, ridge = FT + CH, FT + CH + 4.4
    zc = (SZ1 + SZ2) / 2
    run = (SZ2 - SZ1) / 2 + 2.6
    w = 28.0 / 8
    steps = 3 if lod < 2 else 1
    dz, dy = run / steps, 4.4 / steps
    for s in range(steps):
        y0, y1 = eave + s * dy, eave + (s + 1) * dy
        a = s * dz
        for side in (-1, 1):
            z0, z1 = zc + side * (run - a), zc + side * (run - a - dz)
            if lod == 2:
                k.brick((-14.0, y0, z0), (14.0, y1, z1), P.RED, bev=0.1, bottom=True)
                continue
            for i in range(8):
                x0 = -14.0 + w * i
                c = P.RED if i % 2 == 0 else P.WHITE
                k.brick((x0 + 0.03, y0, min(z0, z1) + 0.02), (x0 + w - 0.03, y1, max(z0, z1) - 0.02), c, bev=0.14, bottom=(s == 0))
                if s == 0:
                    k.stud(x0 + w / 2, y1, (z0 + z1) / 2, c, 0.82, 0.3)
    # gables: stepped aqua fill under the overhang
    if lod < 2:
        for side in (-1, 1):
            for s in range(steps - 1):
                y0, y1 = eave + s * dy, eave + (s + 1) * dy
                r = run - 2.6 - (s + 1) * dz + 0.3
                k.brick((side * SX - 0.4, y0, zc - max(r, 0.5)), (side * SX + 0.4, y1, zc + max(r, 0.5)), P.AQUA, bev=0.05)
    # awning over the hatch, 2 studs further forward: red/white strips in two steps, big stepped scallops along the front
    AW = 3.6
    for i in range(6):
        x0 = -10.8 + AW * i
        c = P.RED if i % 2 == 0 else P.WHITE
        if lod == 2 and i:
            continue
        x1 = x0 + AW - 0.04 if lod < 2 else 10.8
        k.brick((x0 + 0.02, FT + 7.5, SZ2), (x1, FT + 8.0, SZ2 + 4.2), c, bev=0.1, bottom=True)
        if lod < 2:
            k.brick((x0 + 0.02, FT + 6.9, SZ2 + 4.2), (x1, FT + 7.4, SZ2 + 8.0), c, bev=0.1, bottom=True)
            k.brick((x0 + 0.3, FT + 5.9, SZ2 + 7.4), (x1 - 0.28, FT + 6.88, SZ2 + 8.0), c, bev=0.08, bottom=True)
            k.brick((x0 + 1.0, FT + 5.1, SZ2 + 7.45), (x1 - 0.98, FT + 5.92, SZ2 + 7.95), c, bev=0.08, bottom=True)
            k.stud(x0 + 1.8, FT + 7.4, SZ2 + 6.0, c, 0.68, 0.26)
    if lod < 2:                                      # two hanging lanterns under the awning's corners: a cord, a navy cap, a warm body, a navy foot
        for x in (-9.0, 9.0):
            z = SZ2 + 6.2
            k.brick((x - 0.14, FT + 5.6, z - 0.14), (x + 0.14, FT + 6.95, z + 0.14), P.INK, bev=0.02, bottom=True)
            k.brick((x - 0.8, FT + 5.25, z - 0.8), (x + 0.8, FT + 5.7, z + 0.8), P.INK, bev=0.08, bottom=True)
            k.brick((x - 0.6, FT + 3.95, z - 0.6), (x + 0.6, FT + 5.3, z + 0.6), P.YELLOW, bev=0.08, bottom=True)
            k.brick((x - 0.8, FT + 3.55, z - 0.8), (x + 0.8, FT + 4.0, z + 0.8), P.INK, bev=0.08, bottom=True)
    # the name board on the roof's front eave, yellow CAFE on navy, facing the terrace; the shell sign stands right behind it, centred, over the awning
    by, bz = FT + CH + 0.1, zc + run + 0.1
    k.brick((-7.2, by, bz), (7.2, by + 5.0, bz + 0.6), P.INK, bev=0.1, bottom=True)
    if lod < 2:
        LETTERS = (((0, 0, 3, 1), (0, 4, 3, 5), (0, 1, 1, 4)), ((0, 0, 1, 5), (2, 0, 3, 5), (1, 2, 2, 3), (1, 4, 2, 5)),
                   ((0, 0, 1, 5), (1, 4, 3, 5), (1, 2, 2, 3)), ((0, 0, 1, 5), (1, 4, 3, 5), (1, 2, 2, 3), (1, 0, 3, 1)))
        px = 0.8
        for n, rects in enumerate(LETTERS):
            lx = -6.0 + n * 4 * px - 0.4
            for a, b, c, d in rects:
                k.box((lx + a * px + 0.02, by + 0.5 + b * px + 0.02, bz + 0.5), (lx + c * px - 0.02, by + 0.5 + d * px - 0.02, bz + 0.72), P.YELLOW, bev=0.02)
    k.brick((-3.0, eave + 1.4, zc + run - 3.2), (3.0, eave + 3.7, zc + run - 0.8), P.INK, bev=0.14, bottom=True)
    fan(k, 0.0, eave + 3.6, zc + run - 2.0, 8.0 * MARK, P.GOLD, P.YELLOW, depth=2.6)
    k.grow(at, (0.0, FT, SZ1), CG)
    # the giant ice cream on its own post (stepped wafer cone, two stepped scoops, a red cherry stud)
    q = CG * MARK * CONE
    iy = FT + (ridge - FT) * CG + 1.5
    k.brick((CONE_X - 2.2, FT - SINK, CONE_Z - 2.2), (CONE_X + 2.2, FT + 0.7, CONE_Z + 2.2), P.INK, bev=0.14)
    k.brick((CONE_X - 1.35, FT + 0.7 - SINK, CONE_Z - 1.35), (CONE_X + 1.35, iy + 0.4, CONE_Z + 1.35), P.INK, bev=0.1)
    for r, y0, y1 in ((1.5, 0, 1.4), (2.1, 1.4, 2.8), (2.7, 2.8, 4.2), (3.3, 4.2, 5.6)):
        k.brick((CONE_X - r * q, iy + y0 * q, CONE_Z - r * q), (CONE_X + r * q, iy + y1 * q, CONE_Z + r * q), P.DTAN if y0 % 2.8 else P.TAN, bev=0.2, bottom=True)
    for r, y0, y1, c in ((3.9, 5.6, 6.8, P.CORAL), (4.7, 6.8, 9.2, P.CORAL), (3.4, 9.2, 10.4, P.CORAL),
                         (3.0, 10.4, 11.6, P.YELLOW), (3.5, 11.6, 13.2, P.YELLOW), (2.2, 13.2, 14.4, P.YELLOW)):
        k.brick((CONE_X - r * q, iy + y0 * q, CONE_Z - r * q), (CONE_X + r * q, iy + y1 * q, CONE_Z + r * q), c, bev=0.26, bottom=True)
    k.stud(CONE_X, iy + 14.4 * q, CONE_Z, P.RED, 1.8, 0.8)
    # string-light posts at the front corners
    for s in (-1, 1):
        k.cyl(s * 21.0, 26.0, FT - SINK, FT + 9.0, 0.42, P.WHITE, n=(10, 8, 5)[lod], bottom=False)
        k.stud(s * 21.0, FT + 9.0, 26.0, P.WHITE, 0.56, 0.2)


def bulbs(k):
    """The strings' bulbs alone (the code makes them Neon and keeps its PointLight), same origin as the café."""
    n = (6, 6, 5)[k.lod]
    for s in (-1, 1):
        a = (s * 11.0 * CG, FT + (CH - 0.5) * CG, SZ1 + (SZ2 + 0.4 - SZ1) * CG)
        b = (s * 21.0, FT + 8.8, 26.0)
        for q in range(1, 7):
            t = q / 7
            sag = math.sin(t * math.pi) * 1.4
            x, y, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag, a[2] + (b[2] - a[2]) * t
            if k.lod == 2:
                k.brick((x - 0.5, y - 0.5, z - 0.5), (x + 0.5, y + 0.3, z + 0.5), P.YELLOW, bev=0.05, bottom=True)
            else:
                k.frustum(x, z, [(y - 0.5, 0.3), (y - 0.3, 0.55), (y + 0.3, 0.55)], P.YELLOW, n=n)


# ------------------------------------------------------------------ small furniture
def table(k):
    """A bistro table and two chairs (origin on the floor): round studded top, teal iron."""
    k.cyl(0, 0, 0.0, 2.3, 0.3, P.TEAL, n=(8, 6, 5)[k.lod], bottom=False)
    k.cyl(0, 0, 0.0 + 2.3 - SINK, 2.75, 1.9, P.WHITE, n=(16, 10, 6)[k.lod])
    for s in (-1, 1):
        k.brick((s * 3.2 - 1.05, 0.0, -1.05), (s * 3.2 + 1.05, 1.5, 1.05), P.TEAL, bev=0.16)
        k.brick((s * 3.2 + s * 0.65 - 0.42, 1.5, -1.05), (s * 3.2 + s * 0.65 + 0.42, 3.6, 1.05), P.TEAL, bev=0.12)
        k.stud(s * 3.2 - s * 0.3, 1.5, 0, P.TEAL, 0.5, 0.22)


def parasol(k, a, b=P.WHITE):
    """Pole and a stepped three-tier canopy (eight stripes round the lowest tier): the code's height, 4.2 half-span."""
    k.cyl(0, 0, -0.6, 7.2, 0.3, P.WHITE, n=(8, 6, 5)[k.lod], bottom=False)
    s = 4.6
    if k.lod == 2:
        k.brick((-s, 5.9, -s), (s, 6.6, s), a, bev=0.2, bottom=True)
        k.brick((-s / 2, 6.6, -s / 2), (s / 2, 7.8, s / 2), b, bev=0.2)
        return
    w = s / 2
    for i in range(4):
        for j in range(4):
            if 0 < i < 3 and 0 < j < 3:
                continue
            x0, z0 = -s + i * w, -s + j * w
            c = a if (i + j) % 2 == 0 else b
            k.brick((x0 + 0.02, 5.9, z0 + 0.02), (x0 + w - 0.02, 6.6, z0 + w - 0.02), c, bev=0.14, bottom=True)
            if i % 3 == 0 and j % 3 == 0:
                k.stud(x0 + w / 2, 6.6, z0 + w / 2, c, 0.62, 0.2)
    k.box((-w + 0.02, 5.9, -w + 0.02), (w - 0.02, 6.6, w - 0.02), P.WHITE, bev=0.05)     # underside centre
    for i in range(2):
        for j in range(2):
            c = a if (i + j) % 2 else b
            k.brick((-w + i * w + 0.02, 6.6, -w + j * w + 0.02), (i * w - 0.02, 7.35, j * w - 0.02), c, bev=0.14, bottom=False)
    k.brick((-1.0, 7.35, -1.0), (1.0, 7.95, 1.0), a, bev=0.14)
    k.stud(0, 7.95, 0, P.WHITE, 0.55, 0.3)


def lounger(k, c):
    """A wooden lounger, 1.3x the code's, back up at +z, foot at -z."""
    at = len(k.b.v)
    if k.lod == 2:
        k.brick((-1.75, 0.0, -3.2), (1.75, 1.85, 3.2), c, bev=0.1)
        k.brick((-1.4, 1.85, 2.0), (1.4, 3.5, 3.0), c, bev=0.1)
    else:
        for x0, z0 in ((-1.6, -3.0), (0.9, -3.0), (-1.6, 2.3), (0.9, 2.3)):
            k.brick((x0, 0.0, z0), (x0 + 0.7, 1.0, z0 + 0.7), P.BROWN, bev=0.1)
        k.brick((-1.75, 1.0, -3.2), (1.75, 1.45, 3.2), P.TAN, bev=0.1, bottom=True)
        k.brick((-1.4, 1.45, -3.0), (1.4, 1.85, 1.0), c, bev=0.12)
        k.stud(-0.7, 1.85, -1.8, c, 0.5, 0.22)
        k.stud(0.7, 1.85, -1.8, c, 0.5, 0.22)
        for z0, z1, y1 in ((1.0, 2.0, 2.5), (2.0, 3.0, 3.5)):                   # stepped back, not a skewed plate
            k.brick((-1.4, 1.45, z0 + 0.03), (1.4, y1, z1 - 0.03), c, bev=0.12)
    k.tilt(at, (0.0, 0.0, 0.0), lift=(0.0, 0.3, 0.0))


def towel(k, a, b, rim):
    """A chunky towel: a rim course, three stripes on it, a stud a stripe."""
    at = len(k.b.v)
    k.brick((-2.5, 0.0, -4.15), (2.5, 0.3, 4.15), rim, bev=0.08)
    for i, c in enumerate((a, b, a)):
        z0 = -3.75 + i * 2.5
        k.brick((-2.1, 0.25, z0 + 0.02), (2.1, 0.55, z0 + 2.48), c, bev=0.08)
        k.stud(0.0, 0.55, z0 + 1.25, c, 0.62, 0.22)
    k.tilt(at, (0.0, 0.0, 0.0), lift=(0.0, 0.3, 0.0))


# ------------------------------------------------------------------ plants
def palm(k, h=24.0):
    """A trunk of offset square bricks that steps sideways, a studded hub, six fronds of three stepped studded plates. Stands on its own L32_PalmBase, which the layout never scales."""
    segs = (6, 4, 2)[k.lod]
    dh = (h - 0.5) / segs
    lx, lz = 0.22, 0.12
    s0 = 2.2
    for i in range(segs):
        t = i / segs
        tx, tz = lx * h * t * t, lz * h * t * t
        s = s0 - 0.55 * t * s0 / 2.2
        k.brick((tx - s, 0.5 + i * dh if i else -1.5, tz - s), (tx + s, 0.5 + (i + 1) * dh, tz + s), P.BROWN if i % 2 else P.DTAN, bev=0.3, bottom=bool(i))
    cx, cz, cy = lx * h, lz * h, h + 0.5
    k.brick((cx - 3.2, cy, cz - 3.2), (cx + 3.2, cy + 2.0, cz + 3.2), P.DGREEN, bev=0.3, bottom=True)
    k.stud(cx, cy + 2.0, cz, P.DGREEN, 1.6, 0.6)
    fruit = P.BROWN
    if k.lod < 2:
        k.brick((cx + 1.2, cy - 1.7, cz - 2.6), (cx + 2.9, cy, cz - 0.9), fruit, bev=0.2, bottom=True)
        k.brick((cx - 2.9, cy - 1.7, cz + 0.9), (cx - 1.2, cy, cz + 2.6), fruit, bev=0.2, bottom=True)
    leaves = ((1.5, 7.4, 3.1, 1.2), (6.8, 11.8, 2.5, -0.2), (11.2, 15.6, 1.7, -1.8))
    if k.lod == 2:
        leaves = ((1.5, 13.0, 2.8, 0.4),)
    fronds = (6, 6, 3)[k.lod]
    for f in range(fronds):
        at = len(k.b.v)
        c = P.GREEN if f % 2 else P.DGREEN
        for x0, x1, w, ty in leaves:
            k.brick((cx + x0, cy + ty - 1.1, cz - w), (cx + x1, cy + ty, cz + w), c, bev=0.16, bottom=True)
            if w > 3.0:
                k.stud(cx + (x0 + x1) / 2, cy + ty, cz, c, 1.15, 0.42)
        k.tilt(at, (cx, cy, cz), yaw=360.0 / fronds * f + 20.0)


def palm_base(k):
    """The palm's clean plate, one size under every palm: a teal rim and an accent at each corner (rock, scallop, rock, starfish). Square to the world, however the trunk turns."""
    top = 1.4
    plate(k, 16.0, 16.0, -3.0, top, rim=P.TEAL, rows=2)
    if k.lod == 2:
        return
    for sx, sz in ((1, 1), (-1, -1)):
        k.brick((sx * 5.0 - 1.3, top - SINK, sz * 5.0 - 1.3), (sx * 5.0 + 1.3, top + 1.5, sz * 5.0 + 1.3), P.GREYTAN, bev=0.2)
    fan(k, -5.0, top, 5.0, 3.2, depth=1.0)
    starfish(k, 5.0, top + 0.05, -5.0, P.ORANGE)


def agapanthus(k):
    """Strap leaves as stepped plates, three stems with stepped blue/white heads."""
    plate(k, 8.0, 8.0, -1.0, 0.7, clear=(2.5, 2.5))
    if k.lod == 2:
        k.brick((-2.2, 0.4, -2.2), (2.2, 1.5, 2.2), P.GREEN, bev=0.1)
        k.brick((-1.6, 1.5, -1.4), (1.6, 8.5, 1.6), P.BLUE, bev=0.2)
        return
    for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        k.brick((sx * 1.0 - 0.9 - abs(sz) * 0.1, 0.4, sz * 1.0 - 0.9), (sx * 1.0 + 0.9, 1.5, sz * 1.0 + 0.9), P.GREEN, bev=0.14)
        if k.lod < 2:
            k.brick((sx * 2.0 - 0.6, 0.4, sz * 2.0 - 0.6), (sx * 2.0 + 0.6, 0.95, sz * 2.0 + 0.6), P.DGREEN, bev=0.1)
    for x, z, h, c in ((-1.0, -0.6, 5.6, P.BLUE), (1.2, -0.3, 6.6, P.WHITE), (0.0, 1.2, 7.4, P.BLUE)):
        k.brick((x - 0.22, 1.4, z - 0.22), (x + 0.22, h, z + 0.22), P.DGREEN, bev=0.04)
        k.brick((x - 1.0, h, z - 1.0), (x + 1.0, h + 0.8, z + 1.0), c, bev=0.14, bottom=True)
        k.brick((x - 1.3, h + 0.8, z - 1.3), (x + 1.3, h + 1.6, z + 1.3), c, bev=0.14, bottom=True)
        k.brick((x - 0.8, h + 1.6, z - 0.8), (x + 0.8, h + 2.2, z + 0.8), c, bev=0.12)
        k.stud(x, h + 2.2, z, c, 0.5, 0.24)


# ------------------------------------------------------------------ rocks, ruins, coral (new tour modules)
def rock_arch(k):
    """Cool grey-blue blocks on two tan bottom courses, a dark waterline band, a seamed span, a double moss cap; a white foam plate at the foot, tan stepped ledges, a chunky keystone; a boat fits through (20 wide on the foam, 16 under the lintel, 19.6 clear above the sea)."""
    rng = random.Random(71)
    u = 4.0
    base = rect(-8, -3, -3, 3, cut=True) | rect(3, -3, 8, 3, cut=True)
    if k.lod < 2:
        for s in (-1, 1):
            k.box((min(s * 12, s * 28) + 0.1, -12.0, -7.9), (max(s * 12, s * 28) - 0.1, 0.8, 7.9), P.DSLATE, bev=0, drop=("bottom",))     # below the band: one wet block
        k.box((-23.9, 0.8, -7.9), (-12.1, 21.6, 3.9), P.DBG, bev=0, drop=("bottom", "top"))       # no daylight through the seams
        k.box((12.1, 0.8, -3.9), (23.9, 21.6, 3.9), P.DBG, bev=0, drop=("bottom", "top"))
    L = rect(-7, -2, -3, 2)
    R = rect(3, -2, 7, 2)
    L2 = rect(-7, -2, -3, 1)
    R2 = rect(3, -1, 7, 2)
    L3 = rect(-6, -2, -2, 2)
    R3 = rect(2, -2, 6, 1)
    span = rect(-6, -2, 6, 2)
    roof = rect(-5, -1, 3, 2)
    cap = rect(-3, -1, 1, 1)
    bare = lambda above: (lambda i, j: (i, j) not in above and (i + j) % 2 == 0)     # the legs' shoulders
    full = lambda above: (lambda i, j: (i, j) not in above)                         # the top slabs: a stud a cell
    sandy = lambda r: P.TAN if r.random() < 0.8 else P.DTAN
    cool = lambda r: P.SLATE if r.random() < 0.7 else P.DSLATE
    moss = lambda r: P.GREEN if r.random() < 0.7 else P.DGREEN
    for s in (-1, 1):                                                               # a white foam plate round each foot
        k.brick((min(s * 10, s * 34), -0.5, -14.0), (max(s * 10, s * 34), 0.36, 14.0), P.WHITE, bev=0.2)
    for cs, abv in (({c for c in base if c[0] < 0}, L), ({c for c in base if c[0] > 0}, R)):
        tier(k, cs, u, 0, 0, 0.4, 1.6, lambda _: P.INK, rng, stud=bare(abv), r=1.0, h=0.4, bev=0.14)         # the 1-stud dark waterline band
    for cs, abv in ((L, L2), (R, R2)):
        tier(k, cs, u, 0, 0, 1.6, 4.8, sandy, rng, stud=lambda i, j: False)                                   # tan only on the bottom two courses
        tier(k, cs, u, 0, 0, 4.8, 8.0, sandy, rng, stud=bare(abv), r=1.0, h=0.4)
    if k.lod < 2:                                                                   # tan stepped ledges up the legs' outer sides and faces
        for s in (-1, 1):
            k.brick((min(s * 27.8, s * 31.0), 1.6, -9.0), (max(s * 27.8, s * 31.0), 3.5, 9.0), P.TAN, bev=0.2)
            k.brick((min(s * 27.8, s * 29.4), 3.5, -7.0), (max(s * 27.8, s * 29.4), 5.6, 7.0), P.DTAN, bev=0.2)
            for z0, z1 in ((-10.4, -7.8), (7.8, 10.4)):
                k.brick((min(s * 13.0, s * 27.8), 1.6, z0), (max(s * 13.0, s * 27.8), 3.5, z1), P.TAN, bev=0.2)
            k.stud_grid(min(s * 28.0, s * 31.0), max(s * 28.0, s * 31.0), -8.5, 8.5, 3.5, P.TAN, pitch=3.4, r=0.6, h=0.3)
    for cs, abv in ((L2, L3), (R2, R3)):
        tier(k, cs, u, 0, 0, 8.0, 14.6, cool, rng, stud=bare(abv), r=1.0, h=0.4)
    for cs in (L3, R3):
        tier(k, cs, u, 0, 0, 14.6, 21.6, cool, rng, stud=lambda i, j: False, bottom=True)
    tier(k, span, u, 0, 0, 21.6, 24.0, cool, rng, stud=lambda i, j: False, bottom=True)                       # the span in two running courses: seams
    tier(k, span, u, 0, 0, 24.0, 26.6, cool, random.Random(72), stud=full(roof), r=1.0, h=0.4)
    tier(k, roof, u, 0, 0, 26.6, 30.6, cool, rng, stud=lambda i, j: False)
    tier(k, roof, u, 0, 0, 30.6, 33.0, moss, rng, stud=full(cap), r=1.0, h=0.4)
    tier(k, cap, u, 0, 0, 33.0, 35.4, moss, rng, r=1.0, h=0.4)
    k.brick((-4.6, 19.6, -9.0), (4.6, 24.0, 9.0), P.LSLATE, bev=0.28, bottom=True)                            # a chunky keystone, proud of both faces
    k.brick((-6.8, 24.0 - 0.05, -9.8), (6.8, 28.0, 9.8), P.LSLATE, bev=0.28, bottom=True)
    if k.lod < 2:
        k.stud_grid(-6.8, 6.8, -9.8, -4.2, 28.0, P.LSLATE, pitch=3.4, r=1.0, h=0.4)
        for x0, x1 in ((-17.0, -9.5), (9.5, 16.0)):                                 # lighter top-face highlight bricks on the span's front shoulder
            k.brick((x0, 26.55, -7.6), (x1, 27.5, -4.4), P.LSLATE, bev=0.16)
        k.brick((14.5, 26.55, -2.6), (21.5, 27.5, 3.4), P.LSLATE, bev=0.16)
    at = len(k.b.v)
    gull(k, -6.0, 35.4, 0.0, 40.0)
    k.grow(at, (-6.0, 35.4, 0.0), 1.5)


def starfish(k, x, y, z, c=P.TEAL):
    """Five arms round a studded hub, lying on a top at height y."""
    for f in range(5):
        at = len(k.b.v)
        k.brick((x + 0.5, y - 0.05, z - 0.45), (x + 2.2, y + 0.3, z + 0.45), c, bev=0.06)
        k.tilt(at, (x, y, z), yaw=72.0 * f + 18.0)
    k.brick((x - 0.8, y - 0.05, z - 0.8), (x + 0.8, y + 0.5, z + 0.8), c, bev=0.08)
    k.stud(x, y + 0.5, z, c, 0.5, 0.2)


def brain(k, x, y, z, r):
    """A brain-coral dome: stepped drums in coral and magenta rings, a studded crown. Far: one drum."""
    if k.lod == 2:
        k.cyl(x, z, y - SINK, y + r, r, P.CORAL, n=6, bottom=False)
        return
    for f0, f1, q, c in ((0.0, 0.34, 1.0, P.CORAL), (0.32, 0.62, 0.86, P.MAGENTA), (0.6, 0.86, 0.66, P.CORAL), (0.84, 1.05, 0.36, P.MAGENTA)):
        k.cyl(x, z, y + f0 * r - SINK, y + f1 * r, r * q, c, n=10, bottom=False)
    for f in range(5):
        a = math.radians(72.0 * f)
        k.stud(x + 0.5 * r * math.cos(a), y + 0.86 * r, z + 0.5 * r * math.sin(a), P.CORAL, 0.5, 0.2)


def coral_cluster(k):
    """Shallow-water cluster (origin at sea level) on stacked stepped rocks: a tall magenta branch on the top rock, a brain-coral dome, shorter orange and yellow branches lower down, a scallop and a teal starfish on the base."""
    rng = random.Random(81)
    u = 4.0
    base, mid, high = rect(-3, -3, 3, 3), rect(-2, -3, 2, 1), rect(-2, -3, 0, -1)
    tan = lambda r: P.TAN if r.random() < 0.7 else P.DTAN
    rock = lambda r: P.GREYTAN if r.random() < 0.7 else P.DBG
    tier(k, base, u, 0, 0, -8.0, 1.2, tan, rng, stud=lambda i, j: (i, j) not in mid and (i + j) % 2 == 0, r=0.6, h=0.3)
    tier(k, mid, u, 0, 0, 1.2, 3.6, rock, rng, stud=lambda i, j: (i, j) not in high and (i + j) % 2 == 0, r=0.6, h=0.3)
    tier(k, high, u, 0, 0, 3.6, 6.0, rock, rng, stud=lambda i, j: False)
    branch(k, -4.0, -8.0, 6.0, 7.5, P.MAGENTA)
    brain(k, 3.5, 3.6, -5.0, 3.6)
    branch(k, 7.0, 7.5, 1.2, 6.0, P.ORANGE)
    branch(k, -5.0, 1.0, 3.6, 4.5, P.YELLOW)
    fan(k, -7.0, 1.2, 8.0, 4.5, depth=1.2)
    if k.lod < 2:
        starfish(k, 0.5, 1.2, 8.5)


def flute(k, x, z, y0, y1, r, c, lying=False):
    """A fluted marble drum: 12 alternating ribs, a chamfer in to a plain top. Lying: round the x axis, y0..y1 along x, (x, z) = the axis's y and z. Far LODs: a plain cylinder."""
    if k.lod:
        if lying:
            k.b.cyl_x(*k.p((y0 + y1) / 2, x, z), r, y1 - y0, c, n=(10, 6)[k.lod - 1])
        else:
            k.cyl(x, z, y0, y1, r, c, n=(10, 6)[k.lod - 1], bottom=False)
        return
    star = [r if i % 2 else r - 0.42 for i in range(12)]
    plain = [r - 0.7] * 12
    def ring(t, rs):
        return [(t, x + q * math.cos(i * math.pi / 6), z + q * math.sin(i * math.pi / 6)) if lying
                else (x + q * math.cos(i * math.pi / 6), t, z + q * math.sin(i * math.pi / 6)) for i, q in enumerate(rs)]
    if lying:
        k.prism([ring(y0, plain), ring(y0 + 0.3, star), ring(y1 - 0.3, star), ring(y1, plain)], c)
    else:
        k.prism([ring(y0, star), ring(y1 - 0.3, star), ring(y1, plain)], c, bottom=False)


def drums(k, y0, n, r, h=3.2):
    """A stack of fluted drums in warm tans, every other a step in, a dark seam course between them; a coral band over the lowest and under the top. Returns the top."""
    for i in range(n):
        y = y0 + i * h
        flute(k, 0, 0, y, y + h - 0.42, r - (i % 2) * 0.22, P.DTAN if i == 0 else P.TAN if i % 2 else P.SAND)
        if k.lod < 2 and i < n - 1:
            if i in (0, n - 2):
                k.cyl(0, 0, y + h - 0.46, y + h + 0.03, r + 0.12, P.CORAL, n=10)
            else:
                k.cyl(0, 0, y + h - 0.46, y + h + 0.03, r - 0.62, P.UMBER, n=8)
    return y0 + n * h


def capital(k, y):
    """A flared drum, a coral course, a seamed square abacus with one corner chipped away, a broken block and studs left on top."""
    k.cyl(0, 0, y - 0.04, y + 1.2, 4.3, P.TAN, n=(12, 10, 6)[k.lod], bottom=True)
    k.brick((-4.6, y + 1.2, -4.6), (4.6, y + 1.75, 4.6), P.CORAL, bev=0.14, bottom=True)
    t = y + 3.3
    for sx, sz, x, h in ((-1, -1, 5.0, t), (1, -1, 5.0, t), (-1, 1, 5.0, t), (1, 1, 3.4, y + 2.6)):     # the chipped corner: shorter both ways
        k.brick((min(sx * 0.03, sx * x), y + 1.7, min(sz * 0.03, sz * x)), (max(sx * 0.03, sx * x), h, max(sz * 0.03, sz * x)), P.SAND, bev=0.24, bottom=True)
    k.brick((-1.4, t - SINK, -3.6), (3.6, t + 1.2, -0.2), P.TAN, bev=0.18)    # one broken block left on top
    k.stud(1.1, t + 1.2, -1.9, P.TAN, 0.6, 0.3)
    for sx, sz in ((-3.5, -3.5), (-3.5, 3.5)):
        k.stud(sx, t, sz, P.SAND, 0.6, 0.3)


def column_tall(k):
    """A standing column from the seabed up through the sea (origin at sea level): eight fluted drums, a capital, one drum fallen on the ledge beside it."""
    k.brick((-5.6, -12.0, -5.6), (14.2, 1.0, 5.6), P.TAN, bev=0.24)
    k.stud_grid(-5.6, 5.6, -5.6, 5.6, 1.0, P.TAN, pitch=2.8, r=STUD_R, h=0.3, skip=lambda x, z: abs(x) < 3.5 and abs(z) < 3.5)
    k.brick((-4.6, 1.0, -4.6), (4.6, 2.6, 4.6), P.DTAN, bev=0.2)
    capital(k, drums(k, 2.6, 8, 3.6))
    flute(k, 3.7, 0.0, 7.0, 13.0, 2.75, P.SAND, lying=True)                          # the fallen drum


def column_stump(k):
    """The broken column: five fluted warm drums, a jagged brick top, a stud ring round the break."""
    k.brick((-5.4, -12.0, -5.4), (5.4, 0.9, 5.4), P.TAN, bev=0.24)
    k.stud_grid(-5.4, 5.4, -5.4, 5.4, 0.9, P.TAN, pitch=2.7, r=STUD_R, h=0.3, skip=lambda x, z: abs(x) < 3.5 and abs(z) < 3.5)
    top = drums(k, 0.9, 5, 3.6)
    if k.lod < 2:
        for f in range(4):
            a = math.radians(90.0 * f + 45.0)
            k.stud(2.3 * math.cos(a), top - 0.04, 2.3 * math.sin(a), P.SAND, 0.62, 0.3)
    k.brick((-1.7, top - 0.1, -1.7), (0.9, top + 2.6, 1.2), P.SAND, bev=0.16)
    k.brick((0.95, top - 0.1, -1.1), (1.9, top + 1.2, 0.8), P.SAND, bev=0.1)


def column_fallen(k):
    """A broken column on its side, half out of the water: two fluted drums and a toppled capital on a tan ledge."""
    k.brick((-11.0, -12.0, -5.0), (11.0, 0.7, 5.0), P.TAN, bev=0.24)
    if k.lod < 2:
        k.stud_grid(-11, 11, -5, 5, 0.7, P.TAN, pitch=2.8, r=STUD_R, h=0.3, skip=lambda x, z: abs(z) < 3.6)
    flute(k, 3.4, 0, -8.5, -1.5, 3.2, P.SAND, lying=True)
    flute(k, 3.4, 0, -1.42, 5.5, 3.0, P.TAN, lying=True)
    if k.lod < 2:
        k.b.cyl_x(*k.p(-4.0, 3.4, 0.0), 3.3, 0.8, P.CORAL, n=10)                     # a coral band
    k.brick((5.6, 0.7, -3.2), (7.3, 5.4, 3.2), P.TAN, bev=0.16)                      # the capital on its side: flare, then a seamed abacus
    k.brick((7.35, 0.7, -3.9), (10.0, 3.5, -0.03), P.SAND, bev=0.2)
    k.brick((7.35, 0.7, 0.03), (10.0, 3.5, 3.9), P.SAND, bev=0.2)
    k.brick((7.35, 3.5, -3.9), (10.0, 6.0, 3.9), P.SAND, bev=0.2)
    k.stud_grid(7.35, 10.0, -3.9, 3.9, 6.0, P.SAND, pitch=2.6, r=STUD_R, h=0.3)


def ruin_block(k):
    """The code's Block as a column end: a squared plinth, one short fluted drum, a capital slab."""
    k.brick((-5.0, -12.0, -4.0), (5.0, 0.8, 4.0), P.TAN, bev=0.24)
    k.brick((-4.0, 0.8, -3.4), (4.0, 2.4, 3.4), P.DTAN, bev=0.2)
    flute(k, 0, 0, 2.4, 6.4, 2.9, P.SAND)
    k.brick((-3.4, 6.36, -3.4), (3.4, 6.95, 3.4), P.CORAL, bev=0.12, bottom=True)
    k.brick((-3.6, 6.9, -3.6), (3.6, 8.1, 3.6), P.TAN, bev=0.2, bottom=True)
    k.stud_grid(-3.4, 3.4, -3.4, 3.4, 8.1, P.TAN, pitch=3.4, r=STUD_R, h=0.3)


# ------------------------------------------------------------------ beach props
def put(k, fn, x, y, z, yaw=0.0, q=1.0):
    """Build fn at the origin, then scale, turn and move it: a prop on a vignette's plate."""
    at = len(k.b.v)
    fn()
    k.grow(at, (0.0, 0.0, 0.0), q)
    k.tilt(at, (0.0, 0.0, 0.0), yaw=yaw, lift=(x, y, z))


VIG_TOP = 1.4                 # a vignette's plate stands this far above the raycast, so a sloping beach never buries its uphill side


def vig_plate(k, w, d, rim=P.CORAL):
    """The clean tiered plate under a vignette: a saturated rim, small studs round the edge; the wide foot stands the downhill side in steps."""
    plate(k, w, d, -4.0, VIG_TOP, rim=rim)


def vig_lounge(k, shade, seat0, seat1):
    """Two loungers under one parasol, feet at -z."""
    vig_plate(k, 30.0, 18.0)
    put(k, lambda: parasol(k, shade), 0.0, VIG_TOP, 0.0, q=2.1)
    put(k, lambda: lounger(k, seat0), -9.0, VIG_TOP + 0.05, 0.5, q=2.2)
    put(k, lambda: lounger(k, seat1), 9.0, VIG_TOP + 0.05, 0.5, q=2.2)


def vig_towels(k, shade, seat):
    """A lounger, a parasol and a big towel, feet at -z."""
    vig_plate(k, 32.0, 20.0, rim=P.TEAL)
    put(k, lambda: parasol(k, shade), -2.0, VIG_TOP, 1.0, q=2.1)
    put(k, lambda: lounger(k, seat), -10.5, VIG_TOP + 0.05, 0.5, q=2.2)
    put(k, lambda: towel(k, P.RED, P.YELLOW, P.TEAL), 8.5, VIG_TOP + 0.05, 0.0, yaw=8.0, q=2.2)


def vig_red(k):
    """An accent for the bare mid-beach: a red and white parasol over two loungers on a tight plate."""
    vig_plate(k, 26.0, 16.0, rim=P.RED)
    put(k, lambda: parasol(k, P.RED), 0.0, VIG_TOP, 0.0, q=2.1)
    put(k, lambda: lounger(k, P.TEAL), -7.6, VIG_TOP + 0.05, 0.3, q=2.0)
    put(k, lambda: lounger(k, P.YELLOW), 7.6, VIG_TOP + 0.05, 0.3, q=2.0)


def coral_clump(k):
    """An accent for the bare mid-beach: three branching corals 4-5 studs tall on a small rimmed plate."""
    plate(k, 12.0, 12.0, -2.5, 0.6, rim=P.CORAL)
    branch(k, -2.0, -1.5, 0.6, 5.0, P.MAGENTA)
    branch(k, 2.2, 2.0, 0.6, 4.2, P.ORANGE)
    if k.lod < 2:
        branch(k, 2.6, -2.6, 0.6, 3.0, P.YELLOW)


def sandcastle(k):
    """Bucket towers with gold caps, a keep and a red pennant: a thing a kid made, never a heap of rocks. 8 studs wide."""
    k.brick((-3.4, 0.0, -3.4), (3.4, 1.8, 3.4), P.SAND, bev=0.22)
    for sx, sz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        k.brick((sx * 2.6 - 1.3, 1.8, sz * 2.6 - 1.3), (sx * 2.6 + 1.3, 3.0, sz * 2.6 + 1.3), P.SAND, bev=0.12, bottom=True)
        k.brick((sx * 2.6 - 1.5, 3.0, sz * 2.6 - 1.5), (sx * 2.6 + 1.5, 3.9, sz * 2.6 + 1.5), P.GOLD, bev=0.16, bottom=True)
    k.brick((-1.1, 1.8, -1.1), (1.1, 4.6, 1.1), P.SAND, bev=0.16)
    k.brick((-1.4, 4.6, -1.4), (1.4, 5.3, 1.4), P.CORAL, bev=0.12, bottom=True)
    k.cyl(0, 0, 5.25, 8.0, 0.16, P.INK, n=6, bottom=False)
    k.brick((0.1, 6.7, -0.1), (2.5, 7.9, 0.1), P.RED, bev=0.03, bottom=True)


def beach_ball(k):
    """A stepped ball, four colour quarters."""
    if k.lod == 2:
        k.brick((-2.2, 0.0, -2.2), (2.2, 4.1, 2.2), P.RED, bev=0.2)
        return
    for r, y0, y1 in ((1.6, 0.0, 0.9), (2.6, 0.9, 3.0), (1.6, 3.0, 3.9)):
        for (a, b), c in zip((((-r, 0.03), (-r, 0.03)), ((0.03, r), (-r, 0.03)), ((0.03, r), (0.03, r)), ((-r, 0.03), (0.03, r))), (P.RED, P.WHITE, P.YELLOW, P.BLUE)):
            k.brick((a[0], y0, b[0]), (a[1], y1, b[1]), c, bev=0.1, bottom=True)
    k.stud(0.0, 3.9, 0.0, P.WHITE, 0.7, 0.2)


def cooler_kit(k):
    """A cool box and a bucket with a spade; chunky picnic reads at 60 studs."""
    k.brick((-6.4, 0.0, -3.0), (-0.6, 3.1, 2.2), P.TEAL, bev=0.22)
    k.brick((-6.7, 3.1, -3.3), (-0.3, 4.1, 2.5), P.WHITE, bev=0.18, bottom=True)
    k.stud(-3.5, 4.1, -0.4, P.WHITE, 0.95, 0.3)
    k.brick((1.8, 0.0, -2.4), (5.6, 3.3, 1.4), P.YELLOW, bev=0.2)            # bucket
    k.brick((1.5, 3.3, -2.7), (5.9, 4.0, 1.7), P.RED, bev=0.14, bottom=True)
    k.brick((3.2, 4.0, -1.1), (4.2, 7.9, -0.3), P.BROWN, bev=0.08)           # spade
    k.brick((2.8, 7.9, -1.3), (4.6, 8.9, -0.1), P.BLUE, bev=0.12, bottom=True)


def vig_castle(k):
    """The kids' corner: a small sandcastle, a ball, a cool box and a bucket."""
    vig_plate(k, 32.0, 18.0, rim=P.TEAL)
    put(k, lambda: sandcastle(k), -10.0, VIG_TOP - SINK, 0.0, yaw=15.0, q=1.35)
    put(k, lambda: beach_ball(k), -1.0, VIG_TOP - SINK, -5.0, q=1.5)
    put(k, lambda: cooler_kit(k), 7.5, VIG_TOP - SINK, 3.2, q=1.35)


def beach_hut(k, a, b):
    """A little walk-in changing hut for the shoreline, 10.5 studs tall: striped three-sided walls, open to -z, a bench inside, a stepped studded roof."""
    plate(k, 15.0, 15.0, -2.5, 0.5, rim=P.TEAL)
    for i in range(5):                                  # back wall
        x0 = -5.0 + i * 2.0
        k.brick((x0 + 0.03, 0.5, 3.6), (x0 + 1.97, 7.6, 4.6), a if i % 2 else b, bev=0.12)
    for s in (-1, 1):                                   # side walls
        for j in range(4):
            z0 = -4.4 + j * 2.0
            k.brick((s * 4.6 - 0.5, 0.5, z0 + 0.03), (s * 4.6 + 0.5, 7.6, z0 + 1.97), a if j % 2 else b, bev=0.12)
    if k.lod < 2:
        k.brick((-3.8, 0.5, 1.6), (3.8, 2.2, 3.5), P.BROWN, bev=0.14)   # bench
    k.brick((-6.4, 7.6, -5.8), (6.4, 8.8, 6.0), a, bev=0.24, bottom=True)
    k.brick((-4.2, 8.8, -3.6), (4.2, 10.0, 3.8), P.WHITE, bev=0.22, bottom=True)
    k.brick((-1.8, 10.0, -1.4), (1.8, 10.9, 1.6), a, bev=0.18, bottom=True)
    k.stud(0.0, 10.9, 0.1, P.WHITE, 1.0, 0.4)


def path_plate(k):
    """An 8 x 8 stud tan path plate: one of the stepping plates linking stairs, café and palms."""
    plate(k, 16.0, 16.0, -3.0, 1.2)


def surfboards(k):
    """A rack: two posts and a crossbar, three stood boards with stepped ends and a stripe, 7 studs tall (10 at the layout's scale)."""
    plate(k, 15.0, 7.0, -1.0, 0.5, s=BEACH, clear=(5.5, 1.6))
    for x in (-6.5, 6.5):
        k.brick((x - 0.5, 0.5, 0.6), (x + 0.5, 6.0, 1.6), P.BROWN, bev=0.1)
    k.brick((-7.0, 4.9, 0.55), (7.0, 5.7, 1.65), P.BROWN, bev=0.1, bottom=True)
    for x, c, sc in ((-3.8, P.TEAL, P.WHITE), (0.0, P.CORAL, P.YELLOW), (3.8, P.YELLOW, P.RED)):
        k.brick((x - 0.8, 0.5, -0.45), (x + 0.8, 1.2, 0.45), c, bev=0.1)
        k.brick((x - 1.6, 1.2, -0.45), (x + 1.6, 5.7, 0.45), c, bev=0.1)
        k.brick((x - 1.1, 5.7, -0.45), (x + 1.1, 6.5, 0.45), c, bev=0.1)
        k.brick((x - 0.5, 6.5, -0.45), (x + 0.5, 7.1, 0.45), c, bev=0.1)
        k.box((x - 1.62, 3.2, -0.5), (x + 1.62, 4.4, 0.5), sc, bev=0.02) if k.lod < 2 else None


def sand_plate(k):
    """The generic warm tan studded plate under loose beach props (parasols)."""
    plate(k, 9.0, 9.0, -1.0, 0.4, s=BEACH)


def beach_rock(k):
    """Three low stacks of squared stone bricks, grey-tan and grey, with studs on the steps."""
    for x, z, w, d, h, c0, c1 in ((-1.5, 0.5, 8.0, 7.0, 2.6, P.GREYTAN, P.DBG), (4.2, -2.4, 4.6, 4.4, 1.8, P.DBG, P.GREYTAN), (0.9, 5.0, 4.4, 3.6, 1.5, P.GREYTAN, P.DBG)):
        k.brick((x - w / 2, -0.6, z - d / 2), (x + w / 2, h, z + d / 2), c0, bev=0.24)
        k.brick((x - w * 0.34, h, z - d * 0.34), (x + w * 0.2, h * 1.8, z + d * 0.3), c1, bev=0.2)
        k.stud(x + w * 0.34, h, z + d * 0.28, c0, 0.6, 0.3)
        k.stud(x - w * 0.07, h * 1.8, z - d * 0.02, c1, 0.6, 0.3)


def beach_flag(k):
    """A tall colour accent: a post on a tan plate, a coral and teal banner, 7 studs (scaled up in the layout)."""
    plate(k, 7.0, 7.0, -1.0, 0.4, s=1.8)
    k.cyl(0, 0, 0.35, 7.2, 0.34, P.WHITE, n=6, bottom=False)
    k.brick((0.3, 4.2, -0.18), (4.4, 5.4, 0.18), P.TEAL, bev=0.05, bottom=True)
    k.brick((0.3, 5.4, -0.18), (4.4, 7.0, 0.18), P.CORAL, bev=0.05, bottom=True)
    k.stud(0, 7.2, 0, P.GOLD, 0.62, 0.3)


def shell_cluster(k):
    """Sand dressing for the blank beach: a tan studded plate, a scallop and a starfish."""
    plate(k, 11.0, 9.0, -1.0, 0.4, s=BEACH)
    fan(k, -2.3, 0.4, 0.8, 4.2, P.CORAL, P.SAND, depth=1.2)
    if k.lod < 2:
        at = len(k.b.v)
        starfish(k, 2.8, 0.35, -1.2, P.ORANGE)
        k.grow(at, (2.8, 0.35, -1.2), 1.35)


MODULES = [("L01_Statue", "Statue", statue), ("L02_StatuePlinth", "Statue", statue_plinth), ("L03_Jetty", "Jetty", jetty),
           ("L04_DayMark", "DayMark", daymark), ("L05_Telescope", "Telescope", telescope), ("L06_StampPost", "StampPost", stamp_post),
           ("L07_Cafe", "Cafe", cafe), ("L08_CafeBulbs", "Cafe", bulbs), ("L09_Table", "Table", table),
           ("L10_ParasolTeal", "ParasolTeal", lambda k: parasol(k, P.TEAL)), ("L11_ParasolCoral", "ParasolCoral", lambda k: parasol(k, P.CORAL)),
           ("L12_ParasolYellow", "ParasolYellow", lambda k: parasol(k, P.YELLOW)),
           ("L13_VigLounge", "VigLounge", lambda k: vig_lounge(k, P.CORAL, P.TEAL, P.CORAL)), ("L14_VigTowels", "VigTowels", lambda k: vig_towels(k, P.TEAL, P.YELLOW)),
           ("L15_VigCastle", "VigCastle", vig_castle), ("L16_HutCoral", "HutCoral", lambda k: beach_hut(k, P.CORAL, P.WHITE)), ("L17_HutTeal", "HutTeal", lambda k: beach_hut(k, P.TEAL, P.YELLOW)),
           ("L18_Palm", "Palm", palm), ("L19_PathPlate", "PathPlate", path_plate), ("L20_Agapanthus", "Agapanthus", agapanthus),
           ("L21_RockArch", "RockArch", rock_arch), ("L22_CoralCluster", "Coral", coral_cluster), ("L23_ColumnTall", "ColumnTall", column_tall),
           ("L24_ColumnStump", "ColumnStump", column_stump), ("L25_ColumnFallen", "ColumnFallen", column_fallen), ("L26_RuinBlock", "RuinBlock", ruin_block),
           ("L27_Surfboards", "Surfboards", surfboards), ("L28_SandPlate", "SandPlate", sand_plate), ("L29_BeachRock", "BeachRock", beach_rock),
           ("L30_BeachFlag", "BeachFlag", beach_flag), ("L31_ShellCluster", "ShellCluster", shell_cluster), ("L32_PalmBase", "PalmBase", palm_base),
           ("L33_VigRed", "VigRed", vig_red), ("L34_CoralClump", "CoralClump", coral_clump)]
SLOTS = {"Statue": 0, "Jetty": 100, "DayMark": 140, "Telescope": 165, "StampPost": 180, "Cafe": 240, "Table": 290, "ParasolTeal": 305, "ParasolCoral": 325,
         "ParasolYellow": 345, "VigLounge": 380, "VigTowels": 420, "VigCastle": 460, "HutCoral": 495, "HutTeal": 520, "Palm": 555, "PathPlate": 590,
         "Agapanthus": 610, "RockArch": 655, "Coral": 705, "ColumnTall": 730, "ColumnStump": 755, "ColumnFallen": 780, "RuinBlock": 805, "Surfboards": 825,
         "SandPlate": 845, "BeachRock": 865, "BeachFlag": 885, "ShellCluster": 905, "PalmBase": 930, "VigRed": 955, "CoralClump": 990}

# ---- LAYOUT, the wire step reads this: (module, world x, world y or None, world z, yaw degrees, uniform scale). y None = groundY(x, z) raycast, skip if
# gy <= 0.5, exactly as MermaidLagoon/init.luau places its props today. Yaw = CFrame.Angles(0, rad(yaw), 0). Tables below are the code's own.
CX, PAD_Y, FLOOR = 405.0, 16.3, 16.9       # island.pads[1] centre x, pad.y, floorTop
SX0, SZ0 = 300.0, 5265.0                   # statue(): the code's x, z
STATUE_YAW = 340.0                         # the code's yaw 200 turned her local forward (-z) out over the lagoon and her back to the shore, against its own comment ("looks up the lagoon toward the café"); 340 is -z pointing at the café
BEACH = 1.4                                # loose beach props read bigger than the code's (AD r1)
PALM_UP = 1.25                             # palms on top of the code's heights: the island reads from 120 studs (AD r2)
PALMS = ((334, 5054, 26), (356, 5062, 20), (455, 5042, 24), (466, 5052, 19), (472, 4978, 28), (484, 4990, 22), (214, 4992, 25), (226, 5006, 20), (186, 5040, 22),   # (368, 5046) moved to (334, 5054): it hid her head from the landing
         (132, 4988, 19), (522, 5002, 22), (446, 4932, 23), (330, 4926, 15), (262, 5050, 17), (900, 5480, 26), (926, 5602, 29), (956, 5528, 23), (906, 5682, 22),     # (432, 4938) moved to (446, 4932), same reason
         (-332, 5560, 26), (-320, 5574, 20), (-312, 5684, 23), (-362, 5742, 20), (640, 6162, 23), (700, 6184, 28), (742, 6160, 20), (-84, 6200, 25), (-22, 6214, 22), (-124, 6196, 19),
         (484, 4922, 34), (362, 4904, 32))    # the two taller palms for the far view (AD r3), either side of her sightline
AGAPANTHUS = ((364, 5034), (380, 5040), (440, 5038), (456, 5022), (458, 4994), (352, 4972), (330, 5004), (470, 4956), (488, 4962), (302, 4988), (912, 5540), (-320, 5620), (680, 6170))

_rng = random.Random(5601)
LAYOUT = [("L01_Statue", SX0, 0.0, SZ0, STATUE_YAW, 1.0), ("L02_StatuePlinth", SX0, 0.0, SZ0, STATUE_YAW, 1.0),
          ("L03_Jetty", 500.0, 0.0, 4810.0, 0.0, 1.0),                                                  # island.dock; deck 3.5 and stair top 12.5 are built in
          ("L04_DayMark", 300.0, None, 4950.0, 0.0, 1.0),                                               # island.landmark
          ("L05_Telescope", 294.0, None, 4958.0, 0.0, 1.0),
          ("L06_StampPost", 340.0, None, 4990.0, 180.0, 1.0),                                           # island.stamp; plate faces the café
          ("L07_Cafe", CX, PAD_Y, 4993.0, 0.0, 1.0), ("L08_CafeBulbs", CX, PAD_Y, 4993.0, 0.0, 1.0)]    # bulbs: Neon + PointLight in code
for _tx, _tz, _m in ((CX - 13, 5000.0, "L10_ParasolTeal"), (CX, 5010.0, "L11_ParasolCoral"), (CX + 13, 5000.0, "L12_ParasolYellow")):
    LAYOUT += [("L09_Table", _tx, FLOOR, _tz, 0.0, 1.0), (_m, _tx, FLOOR + 2.7, _tz, 0.0, 1.0)]
# the beach: three vignettes on their own plates, 6+ studs apart, long side along the shore, feet to the sea
LAYOUT += [("L13_VigLounge", 385.0, None, 5056.0, 227.0, 1.0), ("L14_VigTowels", 431.0, None, 5056.0, 247.0, 1.0), ("L15_VigCastle", 385.0, None, 5083.0, 225.0, 1.0)]
for _p in PALMS:
    LAYOUT.append(("L18_Palm", float(_p[0]), None, float(_p[1]), round(_rng.uniform(0, 360)), round(PALM_UP * _p[2] / 24.0, 3)))
    LAYOUT.append(("L32_PalmBase", float(_p[0]), None, float(_p[1]), 0.0, 1.0))
LAYOUT += [("L20_Agapanthus", float(_x), None, float(_z), round(_rng.uniform(0, 360)), 1.0) for _x, _z in AGAPANTHUS]


def _off(dx, dz):
    return SX0 + dx * 1.15, SZ0 + dz * 1.15        # 1.15: clears the plinth, which grew with her (AD r4)


# the drowned colonnade: the code's four spots pushed out ~2.2x round the bigger plinth; all stand on the sea level origin, skirts reach the seabed
LAYOUT += [("L23_ColumnTall", _off(-68, -38)[0], 0.0, _off(-68, -38)[1], 0.0, 1.0)]
LAYOUT += [("L25_ColumnFallen", _off(87, -36)[0], 0.0, _off(87, -36)[1], 28.0, 1.0), ("L24_ColumnStump", _off(72, 34)[0], 0.0, _off(72, 34)[1], 0.0, 1.0),
           ("L26_RuinBlock", _off(-48, 52)[0], 0.0, _off(-48, 52)[1], 40.0, 1.0), ("L23_ColumnTall", _off(80, -14)[0], 0.0, _off(80, -14)[1], 90.0, 0.8)]
# new modules: rock arches off the shores (sea level origin, boats pass under), coral / shell clusters in the shallows, beach props on the sand
LAYOUT += [("L21_RockArch", 590.0, 0.0, 4870.0, 20.0, 1.0), ("L21_RockArch", 215.0, 0.0, 5140.0, -25.0, 0.85), ("L21_RockArch", 430.0, 0.0, 5245.0, 70.0, 1.0),
           ("L22_CoralCluster", 440.0, 0.0, 5085.0, 15.0, 1.4), ("L22_CoralCluster", 350.0, 0.0, 5118.0, 200.0, 1.26), ("L22_CoralCluster", 232.0, 0.0, 5290.0, 75.0, 1.54),
           ("L22_CoralCluster", 368.0, 0.0, 5316.0, 300.0, 1.4)]
LAYOUT += [("L29_BeachRock", 325.0, None, 5068.0, 30.0, BEACH), ("L29_BeachRock", 456.0, None, 5064.0, 200.0, 1.0)]
# accents on the bare mid-beach: red and white parasol sets, coral clumps
LAYOUT += [("L33_VigRed", 345.0, None, 5082.0, 215.0, 1.0), ("L33_VigRed", 283.0, None, 5062.0, 180.0, 1.0),
           ("L34_CoralClump", 408.0, None, 5040.0, 20.0, 1.0), ("L34_CoralClump", 412.0, None, 5076.0, 140.0, 1.0)]
# the far view from the water: four shoreline clusters facing the landing (hut, parasol on a plate, flag), then the striped flag row behind the café
for _x, _z, _hut, _par in ((352.0, 4888.0, "L17_HutTeal", "L11_ParasolCoral"), (404.0, 4905.0, "L16_HutCoral", "L10_ParasolTeal"), (452.0, 4925.0, "L17_HutTeal", "L12_ParasolYellow"), (528.0, 4946.0, "L16_HutCoral", "L10_ParasolTeal")):
    LAYOUT += [(_hut, _x, None, _z, 0.0, 1.0), ("L28_SandPlate", _x + 14.0, None, _z - 2.0, 0.0, BEACH), (_par, _x + 14.0, None, _z - 2.0, 0.0, BEACH), ("L30_BeachFlag", _x - 12.0, None, _z + 2.0, 0.0, 1.8)]
LAYOUT += [("L30_BeachFlag", _x, None, 4952.0, 0.0, 1.8) for _x in (372.0, 386.0, 400.0, 414.0, 428.0)]
LAYOUT += [("L27_Surfboards", 470.0, None, 4950.0, 200.0, BEACH)]
# stepping plates: stair head to the café's door, then down the terrace's side to the palms
LAYOUT += [("L19_PathPlate", _x, None, _z, 0.0, 1.0) for _x, _z in ((495.0, 4962.0), (477.0, 4966.0), (459.0, 4970.0), (441.0, 4974.0), (438.0, 4992.0), (438.0, 5010.0), (440.0, 5028.0), (446.0, 5046.0))]
# tan and shell clusters on the blank sand
SHELLS = ((262, 5076), (318, 5094), (240, 4930), (300, 4905), (470, 5085))
LAYOUT += [("L31_ShellCluster", float(_x), None, float(_z), round(_rng.uniform(0, 360)), BEACH) for _x, _z in SHELLS]


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_LagoonKit_Brick", ALB)
    meshes, lods = [], {}
    sums = [0, 0, 0]
    for name, slot, fn in MODULES:
        tris = []
        for lod in (0, 1, 2):
            b = lego.B()
            fn(K(b, SLOTS[slot], lod=lod))
            tris.append(b.tris())
            sums[lod] += b.tris()
            if lod:
                lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat)
            else:
                obj = b.to_object(name, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        print("[lagoon] %-18s %6d / %5d / %5d tris" % (name, *tris))
    print("[lagoon] total %d / %d / %d" % tuple(sums))
    patch_lod(lods)
    c = lego.B()
    K(c, SLOTS["Statue"]).box((-3, -1, -3), (3, 1, 3), P.DBG, bev=0)
    meshes.append({"object": c.to_object("Col01_COL", mat), "role": "col"})

    def att(n, x, y=0.0, z=0.0):
        return lego.attach(n, (-x, z, y))
    atts = [att("ATT_" + s, x) for s, x in SLOTS.items()]
    atts.append(att("ATT_Lamp", SLOTS["Jetty"] + 10.0, DECK + 10.0, HZ2 - 1.5))       # the jetty lamp's PointLight

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "a kit strip: every module is placed on its own by the code (ATT_<Slot> origins, LAYOUT in build.py)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Statue...: the wiring code places each module by name",
            "LOD UV layout": "flat palette cells (one shared material): hand-made LODs drop studs and merge bricks, UVs are "
                             "not a unique unwrap by design (tiling=True skips the density check)",
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_HQAddons / M_Bld_Depot), no PBR scans",
        },
        "meshes": meshes,
        "attachments": atts,
    }
