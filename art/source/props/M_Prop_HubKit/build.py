"""M_Prop_HubKit: a small Lego landmark for the empty ring centre (PERF-BL12, tour: "Empty open water; nothing to look at").

One FBX, one flat palette material, every module its own mesh; modules sit side by side along Roblox +x, each with an
ATT_<Slot> at its ground origin (Roblox axes: x across, y up, front -z; y 0 = sea level, the Beacon's y 0 = its foot).
LAYOUT is where the wiring code puts them (ring centre = world origin; uniform scale per instance). Collision: simple code Parts, no per-module _COL.

  L01_Atoll       round sandbar on an axis-aligned 8-stud brick grid (stepped outline, radius 41 + a wet step to 49): wet-sand
                  step with inset 2-stud white foam pieces, studded beach tier, stepped plank ramp at -z
  L02_Beacon      red/white banded tower, 139 above the sea on the atoll: walk-in arched running-bond room with windows (stud-edged
                  plank floor, bench, lifebuoys, lit stove, wall lamps), dark base course + door step
  L03_Wreck       half-sunk broken boat alone in open water, bow up: white waterline band, red hull, clean torn break, four separate
                  ribs (one brown), tilted cabin + funnel, two orange crates
  L04_Buoy        red over green channel buoy: dark rim, studded white collar, striped mast and flag (one mesh, code instances it)
  L05_RockA/B     tan waterline ledge + three stepped grey brick tiers (A green cap + gull; B sand cap + red/white marker)
  L07_Raft        crate raft: lifering, red/white cargo crate, 16 x 20 red/white brick sail
  L08_BeaconLens  the gold lantern alone (so the code can make it Neon); ATT_Light at its centre
  L09_AtollDress  the atoll's top tier, kerbs, brick palms, brick bushes and rocks (own mesh, ATT_Atoll origin: one MeshPart's budget)
  L10_BeaconGlass pale-blue panes round the lantern (the code makes them clear, Transparency ~0.75)
  L11_BeaconTop   the beacon from the gallery up (own mesh, ATT_Beacon origin: one MeshPart's budget)

    python3 art/source/props/M_Prop_HubKit/maketex.py --out build/prod/M_Prop_HubKit/textures/M_Prop_HubKit
    run.py --build art/source/props/M_Prop_HubKit/build.py --out-root build/prod/M_Prop_HubKit --steps build,lod,validate,export
LODs are hand-made (patch_lod): LOD1 drops the studs, LOD2 merges bricks into tiers and bands.
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

NAME = "M_Prop_HubKit"
BUDGET = "hero_building"
TIER = "standard"
SET_NAME, SET = "HubKit", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_HubKit_Brick_ALB.png")


SINK = 0.05
SLOTS = {"Atoll": 0, "Beacon": 100, "Wreck": 170, "Buoy": 235, "RockA": 275, "RockB": 330, "Raft": 390}
TIER_TOPS = (1.2, 2.4, 3.6)         # wet step, beach, top (sea level 0)
GT, C0, C1 = 82.2, 85.1, 101.9      # beacon gallery deck top, lantern cage bottom and top (from the beacon's foot)
LENS_Y = (C0 + C1) / 2
PITCH = 8.0                         # the atoll's grid: one brick cell, one stud
RAMP_W, RAMP_Z = 12.0, -40.0        # plank half width (kerbs fill out to 16, the corridor's cell edge); top end, flush with the beach
RAMP_STEPS = tuple((-74.0 + 6.8 * i, y) for i, y in enumerate((-0.4, 0.2, 0.8, 1.4, 1.9)))   # z start, top; each 6.8 deep
PALMS = ((-36.0, 4.0, 27.0, -0.18, 0.05), (36.0, -12.0, 24.0, 0.2, -0.1), (12.0, 36.0, 21.0, 0.05, 0.2))    # x, z, height, lean: cell centres
BUSHES = ((-20.0, -28.0, 3.6), (28.0, 20.0, 3.6), (-20.0, 28.0, 3.6))                                       # x, z, half size
ATOLL_ROCKS = ((-40.0, -20.0, ((-2, -1, 2, 1, 3.5), (-1, -1, 1, 1, 3.5)), 11, P.GREEN),                      # x, z, tiers (4-stud cells), seed, cap
               (44.0, 16.0, ((-1, -2, 1, 2, 4.0), (-1, -1, 1, 1, 3.0)), 12, P.SAND),
               (-16.0, 44.0, ((-2, -1, 2, 1, 3.0), (-2, -1, 0, 1, 3.0)), 13, P.WHITE))


def _ring(r, deg):
    a = math.radians(deg)
    return (round(r * math.cos(a), 1), round(r * math.sin(a), 1))


def _at(module, r, deg, yaw, scale):
    x, z = _ring(r, deg)
    return (module, x, 0, z, yaw, scale)


# Where the wiring code places each module (Roblox world, ring centre = origin): (module, x, y, z, yaw degrees, uniform scale).
# Scatter bearings keep ~30 degrees off every plate's sight line to the tower; radii and scales vary. The wreck sits in the atoll's
# front-left quarter seen from the ramp (bearing 330, between two plates, ~13 studs clear of the atoll), its long red/white side to
# the boat approach; the rafts' sails face out along their bearing (yaw 90 - bearing), so a plate never sees one edge-on.
LAYOUT = [("L01_Atoll", 0, 0, 0, 0, 1.0), ("L09_AtollDress", 0, 0, 0, 0, 1.0), ("L02_Beacon", 0, TIER_TOPS[2] - SINK, 0, 0, 1.0),
          ("L08_BeaconLens", 0, TIER_TOPS[2] - SINK, 0, 0, 1.0), ("L10_BeaconGlass", 0, TIER_TOPS[2] - SINK, 0, 0, 1.0),
          ("L11_BeaconTop", 0, TIER_TOPS[2] - SINK, 0, 0, 1.0),
          _at("L03_Wreck", 92, 330, 35, 1.0)]
LAYOUT += [_at("L04_Buoy", r, b, 0, q) for r, b, q in ((172, 269, 1.0), (215, 275, 1.2),      # three channel gates: staggered pairs
                                                       (160, 151, 1.15), (195, 146, 0.88), (152, 323, 0.9), (184, 314, 1.2))]
LAYOUT += [_at("L05_RockA", r, b, b, q) for r, b, q in ((218, 44, 0.85), (229, 137, 1.15), (191, 21, 1.0))]
LAYOUT += [_at("L06_RockB", r, b, b, q) for r, b, q in ((236, 212, 1.15), (198, 158, 0.85), (219, 99, 1.0))]
LAYOUT += [_at("L07_Raft", r, b, 90 - b, 1.0) for r, b in ((138, 94), (162, 216), (186, 332))]


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
        """Straight-sided brick, chamfered top (box tapers its sides); bottom only where it hangs in the air; LOD2 a plain box."""
        if self.lod == 2:
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
        """A bevelled stud on the top at height y (dropped from the LODs); 16 sides on the atoll's big ones, 12 on most, 10 on the tiny."""
        if not self.lod:
            bx, by, _ = self.p(x, 0, z)
            self.b.stud(bx, by, y - SINK, y + h, r, c, 16 if r >= 2.0 else 12 if r >= 0.9 else 10)

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
def disc(R):
    """The grid cells whose centre lies inside radius R: a stepped round."""
    return {(i, j) for i in range(-8, 8) for j in range(-8, 8) if math.hypot((i + 0.5) * PITCH, (j + 0.5) * PITCH) < R}


def runs(cs):
    """Contiguous runs per row: [(i0, j, i1)], i1 exclusive."""
    out = []
    for j in sorted({c[1] for c in cs}):
        row = sorted(c[0] for c in cs if c[1] == j)
        start = row[0]
        for a, b in zip(row, row[1:] + [None]):
            if b != a + 1:
                out.append((start, j, a + 1))
                start = b
    return out


def seal(k, cs, y):
    """A dark floor just under a tier's top, so the seams never show the sea: row boxes across the x seams, column boxes across the z seams."""
    for i0, j, i1 in runs(cs):
        k.box((i0 * PITCH + 0.1, y - 1.0, j * PITCH + 0.1), (i1 * PITCH - 0.1, y, (j + 1) * PITCH - 0.1), P.DTAN, bev=0, drop=("bottom",))
    for j0, i, j1 in runs({(b, a) for a, b in cs}):
        k.box((i * PITCH + 0.13, y - 1.04, j0 * PITCH + 0.13), ((i + 1) * PITCH - 0.13, y - 0.04, j1 * PITCH - 0.13), P.DTAN, bev=0, drop=("bottom",))


def qbrick(k, pts, y0, y1, c, bev=0.3):
    """A bevelled brick over any four corners [(x, z)] (no bottom face: it sinks into what it stands on)."""
    cx, cz = sum(p[0] for p in pts) / 4, sum(p[1] for p in pts) / 4
    top = []
    for x, z in pts:
        t = min(0.4, bev / max(0.01, math.hypot(cx - x, cz - z)))
        top.append((x + (cx - x) * t, y1, z + (cz - z) * t))
    k.prism([[(x, y0, z) for x, z in pts], [(x, y1 - bev, z) for x, z in pts], top], c, bottom=False)


def bond(cs):
    """Running bond: 2x1 bricks staggered row by row, a 1x1 only where a row's edge needs it. [(i0, j0, i1, j1)]."""
    out, left = [], set(cs)
    for i, j in sorted(cs, key=lambda c: (c[1], c[0])):
        if (i, j) not in left:
            continue
        w = 2 if (i + j) % 2 == 0 and (i + 1, j) in left else 1
        left -= {(i + q, j) for q in range(w)}
        out.append((i, j, i + w, j + 1))
    return out


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


def lay(k, bricks, y0, y1, c, ok=None, r=2.4, h=1.0, bev=0.22, gap=0.06):
    """Straight bricks on the grid, a stud per cell where ok(i, j, x, z)."""
    for i0, j0, i1, j1 in bricks:
        k.brick((i0 * PITCH + gap, y0, j0 * PITCH + gap), (i1 * PITCH - gap, y1, j1 * PITCH - gap), c, bev=bev)
        for i in range(i0, i1):
            for j in range(j0, j1):
                x, z = (i + 0.5) * PITCH, (j + 0.5) * PITCH
                if ok is None or ok(i, j, x, z):
                    k.stud(x, y1, z, c, r, h)


def perim(k, w, y0, y1, c, n=3, bev=0.14, gap=0.05):
    """One course round a square tower: n x n bricks, hollow inside."""
    d = w / n
    for i in range(n):
        for j in range(n):
            if 0 < i < n - 1 and 0 < j < n - 1:
                continue
            x0, z0 = -w / 2 + i * d, -w / 2 + j * d
            k.box((x0 + gap, y0, z0 + gap), (x0 + d - gap, y1, z0 + d - gap), c, bev=bev, drop=("bottom",))


def band(k, w, y0, y1, c, seam, h=1.8, n=(3, 4)):
    """A banded tower section: staggered courses on a dark core; LOD2 one box."""
    if k.lod == 2:
        k.box((-w / 2, y0, -w / 2), (w / 2, y1, w / 2), c, bev=0.1, drop=("bottom",))
        return
    m = max(1, round((y1 - y0) / h))
    for i in range(m):
        perim(k, w, y0 + i * (y1 - y0) / m, y0 + (i + 1) * (y1 - y0) / m + (SINK if i < m - 1 else 0), c, n[i % 2], bev=0.24, gap=0.08)
    k.box((-w / 2 + 0.28, y0, -w / 2 + 0.28), (w / 2 - 0.28, y1 - 0.2, w / 2 - 0.28), seam, bev=0, drop=("bottom", "top"))


def cornice(k, w, y0, h, c):
    k.box((-w / 2, y0, -w / 2), (w / 2, y0 + h, w / 2), c, bev=0.2)


def rock(k, x, z, plan, u, seed, cap, y=1.0, tones=(P.STONE, P.DBG)):
    """A stepped stack on a cell grid (u studs a cell): plan = [(i0, j0, i1, j1, height)] bottom up, round (x, z), each tier built of
    2x4 and 2x2 bricks, a stud per cell only where the tier above leaves it bare. Lowest tier mixes tones, the top tier is the cap.
    Returns the top tier's centre (x, y, z)."""
    rng = random.Random(seed)
    top = y
    for li, (i0, j0, i1, j1, h) in enumerate(plan):
        bot, top = (-3.0 if li == 0 else top - SINK), top + h
        last = li == len(plan) - 1
        rect = (x + i0 * u, z + j0 * u, x + i1 * u, z + j1 * u)
        if k.lod == 2:
            k.brick((rect[0], bot, rect[1]), (rect[2], top, rect[3]), cap if last else (tones[1] if li == 0 else tones[0]), bev=0.3)
            continue
        if li == 0:     # the seams never show the sea
            k.box((rect[0] + 0.1, bot, rect[1] + 0.1), (rect[2] - 0.1, top - 0.35, rect[3] - 0.1), P.DBG, bev=0, drop=("bottom",))
        above = plan[li + 1] if not last else None
        cells = {(i, j) for i in range(i0, i1) for j in range(j0, j1)}
        for a, b, c, d in plates(cells, rng):
            col = cap if last else (tones[rng.random() < 0.4] if li == 0 else tones[0])
            k.brick((x + a * u + 0.06, bot, z + b * u + 0.06), (x + c * u - 0.06, top, z + d * u - 0.06), col, bev=0.3)
            for i in range(a, c):
                for j in range(b, d):
                    if not (above and above[0] <= i < above[2] and above[1] <= j < above[3]):
                        k.stud(x + (i + 0.5) * u, top, z + (j + 0.5) * u, col, 0.33 * u, 0.18 * u)
    return x + (plan[-1][0] + plan[-1][2]) / 2 * u, top, z + (plan[-1][1] + plan[-1][3]) / 2 * u


def palm(k, x, y, z, h=24.0, lx=0.15, lz=0.1):
    """A trunk of offset square bricks, a studded hub, six fronds of three stepped studded plates (each hanging lower)."""
    segs = (6, 4, 2)[k.lod]
    dh = h / segs
    for i in range(segs):
        t = i / segs
        tx, tz = x + lx * h * t * t, z + lz * h * t * t
        s = 2.3 - 0.6 * t
        k.brick((tx - s, y + i * dh - SINK, tz - s), (tx + s, y + (i + 1) * dh, tz + s), P.BROWN if i % 2 else P.RIB, bev=0.3, bottom=True)
    cx, cz, cy = x + lx * h, z + lz * h, y + h
    k.brick((cx - 3.2, cy - 0.6, cz - 3.2), (cx + 3.2, cy + 1.5, cz + 3.2), P.DGREEN, bev=0.3, bottom=True)
    k.stud(cx, cy + 1.5, cz, P.DGREEN, 1.6, 0.6)
    if k.lod < 2:
        k.brick((cx + 1.6, cy - 2.2, cz - 2.6), (cx + 3.2, cy - 0.55, cz - 1.0), P.BROWN, bev=0.2, bottom=True)     # coconuts
        k.brick((cx - 3.0, cy - 2.2, cz + 1.0), (cx - 1.4, cy - 0.55, cz + 2.6), P.BROWN, bev=0.2, bottom=True)
    leaves = ((1.5, 7.4, 3.1, 0.8), (6.8, 11.8, 2.5, -0.6), (11.2, 15.6, 1.7, -2.2))    # from, to, half width, plate top (from the crown)
    if k.lod == 2:
        leaves = ((1.5, 13.0, 2.8, 0.0),)
    for f in range((6, 6, 4)[k.lod]):
        at = len(k.b.v)
        c = P.GREEN if f % 2 else P.DGREEN
        for x0, x1, w, ty in leaves:
            k.brick((cx + x0, cy + ty - 1.1, cz - w), (cx + x1, cy + ty, cz + w), c, bev=0.16, bottom=True)
            if w > 3.0:
                k.stud(cx + (x0 + x1) / 2, cy + ty, cz, c, 1.15, 0.42)
        k.tilt(at, (cx, cy, cz), yaw=(60.0 if k.lod < 2 else 90.0) * f + 20.0)


def gull(k, x, y, z, yaw=0.0):
    """A chunky Lego gull: a small point of life on a rock (LOD0/1 only)."""
    if k.lod == 2:
        return
    at = len(k.b.v)
    k.box((x - 0.35, y - SINK, z - 0.2), (x + 0.35, y + 0.65, z + 0.2), P.YELLOW, bev=0.05, drop=("bottom",))
    k.box((x - 0.8, y + 0.6, z - 1.25), (x + 0.8, y + 2.0, z + 1.1), P.WHITE, bev=0.2)
    k.box((x - 1.05, y + 1.2, z - 0.5), (x + 1.05, y + 1.85, z + 1.5), P.STONE, bev=0.12)
    k.box((x - 0.55, y + 2.0 - SINK, z - 1.5), (x + 0.55, y + 3.0, z - 0.45), P.WHITE, bev=0.14)
    k.box((x - 0.26, y + 2.25, z - 2.2), (x + 0.26, y + 2.65, z - 1.45), P.ORANGE, bev=0.06)
    k.tilt(at, (x, y, z), yaw=yaw)


def bush(k, x, y, z, r=3.6):
    """Three stacked studded green bricks."""
    k.brick((x - r, y - SINK, z - r), (x + r, y + 1.8, z + r), P.GREEN, bev=0.25)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.stud(x + sx * 0.76 * r, y + 1.8, z + sz * 0.76 * r, P.GREEN, 0.72, 0.34)
    k.brick((x - 0.6 * r, y + 1.75, z - 0.6 * r), (x + 0.6 * r, y + 3.5, z + 0.6 * r), P.DGREEN, bev=0.22)
    k.brick((x - 0.3 * r, y + 3.45, z - 0.3 * r), (x + 0.3 * r, y + 4.8, z + 0.3 * r), P.GREEN, bev=0.18)
    k.stud(x, y + 4.8, z, P.GREEN, 0.72, 0.34)


def crate(k, x, y, z, s=3.6, c=P.BROWN, band_c=P.TAN):
    k.box((x - s / 2, y, z - s / 2), (x + s / 2, y + s, z + s / 2), c, bev=0.14, drop=("bottom",))
    k.box((x - s / 2 - 0.05, y + s * 0.42, z - s / 2 - 0.05), (x + s / 2 + 0.05, y + s * 0.58, z + s / 2 + 0.05), band_c, bev=0.03)
    k.stud_grid(x - s / 2 + 0.2, x + s / 2 - 0.2, z - s / 2 + 0.2, z + s / 2 - 0.2, y + s, c, pitch=2.1, r=0.62, h=0.3)


# ------------------------------------------------------------------ L01 atoll
TOP_C = disc(31.0)
BEACH_C = disc(41.0)
SKIRT_C = disc(49.0) - {(i, -6) for i in range(-2, 2)}       # the ramp's corridor (|x| < 16, z < -40) is kept clear
UNDER_PLINTH = {(i, j) for i in range(-2, 2) for j in range(-2, 2)}


def covers(x0, z0, x1, z1):
    return {(i, j) for i in range(-8, 8) for j in range(-8, 8)
            if x0 < (i + 1) * PITCH and (i * PITCH) < x1 and z0 < (j + 1) * PITCH and (j * PITCH) < z1}


TAKEN = set()                                               # cells with something standing on them: no stud
for _x, _z, *_ in PALMS:
    TAKEN |= covers(_x - 1, _z - 1, _x + 1, _z + 1)
for _x, _z, _ in BUSHES:
    TAKEN |= covers(_x - 1, _z - 1, _x + 1, _z + 1)
for _x, _z, _plan, *_ in ATOLL_ROCKS:
    TAKEN |= covers(_x + _plan[0][0] * 4.0, _z + _plan[0][1] * 4.0, _x + _plan[0][2] * 4.0, _z + _plan[0][3] * 4.0)


def foam_pieces():
    """White 2-stud pieces along the wet step, every 2-4 cells: the wet sand shows between them."""
    ring = sorted(SKIRT_C - BEACH_C - TAKEN, key=lambda c: math.atan2(c[1] + 0.5, c[0] + 0.5))
    out, i, n = [], 0, 0
    while i + 1 < len(ring):
        a, b = ring[i], ring[i + 1]
        if abs(a[0] - b[0]) + abs(a[1] - b[1]) == 1:
            out.append((a, b))
            i += 3 + (n % 3 == 1)
            n += 1
        else:
            i += 1
    return out


FOAM = foam_pieces()
FOAM_C = {c for piece in FOAM for c in piece}


def atoll(k):
    """The wet step and the beach tier (the top tier is in L09), one axis-aligned grid: edges step, nothing skews or cracks."""
    y0, y1, _ = TIER_TOPS
    if k.lod == 2:
        for i0, j, i1 in runs(SKIRT_C):
            k.box((i0 * PITCH, -8.0, j * PITCH), (i1 * PITCH, y0, (j + 1) * PITCH), P.DTAN, bev=0.2, drop=("bottom",))
        for i0, j, i1 in runs(BEACH_C):
            k.box((i0 * PITCH, y0 - SINK, j * PITCH), (i1 * PITCH, y1, (j + 1) * PITCH), P.SAND, bev=0.2, drop=("bottom",))
    else:
        seal(k, SKIRT_C, y0 - 0.3)
        lay(k, bond(SKIRT_C - BEACH_C), -8.0, y0, P.DTAN, ok=lambda i, j, x, z: (i, j) not in FOAM_C and (i, j) not in TAKEN)
        seal(k, BEACH_C, y1 - 0.3)
        lay(k, bond(BEACH_C - TOP_C), y0 - SINK, y1, P.SAND, ok=lambda i, j, x, z: (i, j) not in TAKEN)
    for a, b in FOAM:        # inset on the wet step, one stud per cell
        x0, z0, x1, z1 = min(a[0], b[0]) * PITCH, min(a[1], b[1]) * PITCH, (max(a[0], b[0]) + 1) * PITCH, (max(a[1], b[1]) + 1) * PITCH
        k.brick((x0 + 0.6, y0 - SINK, z0 + 0.6), (x1 - 0.6, y0 + 0.5, z1 - 0.6), P.WHITE, bev=0.16)
        for i, j in (a, b):
            k.stud((i + 0.5) * PITCH, y0 + 0.5, (j + 0.5) * PITCH, P.WHITE, 2.1, 0.7)
    # stepped plank ramp up the -z side, from under the sea to the beach tier
    for n, (a, top) in enumerate(RAMP_STEPS):
        c = P.RIB if n % 2 else P.TAN
        k.brick((-RAMP_W, -8.0, a + 0.04), (RAMP_W, top, a + 6.8 - 0.04), c, bev=0.25)
        if top > 0:
            for x in (-8.0, 0.0, 8.0):
                k.stud(x, top, a + 3.4, c, 1.7, 0.6)


def atoll_dress(k):
    """The top tier, the ramp's kerbs, palms, bushes and rocks (own mesh: one MeshPart's budget)."""
    y0, y1, y2 = TIER_TOPS
    for a, top in RAMP_STEPS:    # stepped kerbs, a stud on each
        for s in (-1, 1):
            xa, xb = sorted((s * (RAMP_W - 0.1), s * 15.94))
            k.brick((xa, -2.5, a + 0.06), (xb, top + 1.3, a + 6.8 - 0.06), P.STONE, bev=0.3)
            k.stud(s * 14.0, top + 1.3, a + 3.4, P.STONE, 1.45, 0.55)
    if k.lod == 2:
        for i0, j, i1 in runs(TOP_C):
            k.box((i0 * PITCH, y1 - SINK, j * PITCH), (i1 * PITCH, y2, (j + 1) * PITCH), P.TAN, bev=0.2, drop=("bottom",))
    else:
        seal(k, TOP_C, y2 - 0.3)
        lay(k, bond(TOP_C - UNDER_PLINTH), y1 - SINK, y2, P.TAN,
            ok=lambda i, j, x, z: (i, j) not in TAKEN and max(abs(x), abs(z)) > 20.8)
    for x, z, h, lx, lz in PALMS:
        k.brick((x - 3.8, y1 - SINK, z - 3.8), (x + 3.8, y1 + 0.9, z + 3.8), P.GREEN, bev=0.22)
        palm(k, x, y1 + 0.9, z, h, lx, lz)
    if k.lod < 2:
        for x, z, r in BUSHES:
            bush(k, x, y1, z, r)
    for x, z, plan, seed, cap in ATOLL_ROCKS:
        rock(k, x, z, plan, 4.0, seed, cap, y=y0)


# ------------------------------------------------------------------ L02 beacon
def wall_run(k, x_or_z, a, b, breaks, y0, y1, axis, c, t=2.6, c2=None, i0=0):
    """One course of a room wall along x (axis 'x', wall at z = x_or_z..+t) or z; straight bricks, flat faces, 0.05 seams;
    every third brick in c2 so the courses read."""
    pts = [a + (b - a) * q for q in breaks]
    for n, (u0, u1) in enumerate(zip(pts, pts[1:])):
        col = c2 if c2 is not None and (n + i0) % 3 == 0 else c
        if axis == "x":
            k.brick((u0 + 0.05, y0, x_or_z + 0.05), (u1 - 0.05, y1, x_or_z + t - 0.05), col, bev=0.1)
        else:
            k.brick((x_or_z + 0.05, y0, u0 + 0.05), (x_or_z + t - 0.05, y1, u1 - 0.05), col, bev=0.1)


def window(k, x, y, zw, hw, hh):
    """On the wall face at zw, looking -z: yellow frame, navy pane, white glazing bars."""
    for s in (-1, 1):
        k.box((x - hw, y + s * (hh - 0.4) - 0.4, zw - 0.5), (x + hw, y + s * (hh - 0.4) + 0.4, zw + 0.2), P.YELLOW, bev=0.12)
        k.box((x + s * (hw - 0.4) - 0.4, y - hh + 0.8, zw - 0.45), (x + s * (hw - 0.4) + 0.4, y + hh - 0.8, zw + 0.2), P.YELLOW, bev=0.1)
    k.box((x - hw + 0.75, y - hh + 0.75, zw - 0.14), (x + hw - 0.75, y + hh - 0.75, zw + 0.2), P.INK, bev=0)
    if k.lod < 2:
        k.box((x - 0.26, y - hh + 0.75, zw - 0.3), (x + 0.26, y + hh - 0.75, zw + 0.1), P.WHITE, bev=0.05)
        k.box((x - hw + 0.75, y - 0.26, zw - 0.36), (x + hw - 0.75, y + 0.26, zw + 0.1), P.WHITE, bev=0.05)


def beacon(k):
    FLOOR, W2, I2, TOPW = 2.4, 14.4, 11.8, 21.0        # plinth top, wall outer / inner half widths, room top
    SP, RI, RO, ZF, ZB = 9.0, 5.6, 8.2, -W2 - 0.6, -I2 + 0.4   # arch spring, radii, frame depth
    # plinth + entry step
    if k.lod == 2:
        k.box((-18.4, -SINK, -18.4), (18.4, FLOOR, 18.4), P.STONE, bev=0.3, drop=("bottom",))
    else:
        perim(k, 36.8, -SINK, FLOOR, P.STONE, n=5, bev=0.3, gap=0.08)
        k.box((-11.9, -SINK, -11.9), (11.9, FLOOR - 0.3, 11.9), P.DBG, bev=0, drop=("bottom",))
        for s in (-1, 1):
            k.stud_grid(-18.4, 18.4, s * 16.4 - 1.9, s * 16.4 + 1.9, FLOOR, P.STONE, pitch=7.4, r=1.6, h=0.65,
                        skip=lambda x, z: abs(x) < 10.0 and z < 0)
            k.stud_grid(s * 16.4 - 1.9, s * 16.4 + 1.9, -14.5, 14.5, FLOOR, P.STONE, pitch=7.2, r=1.6, h=0.65)
    k.box((-9.0, -SINK, -23.2), (9.0, 1.2, -18.35), P.STONE, bev=0.25, drop=("bottom",))
    k.stud_grid(-9.0, 9.0, -23.2, -18.4, 1.2, P.STONE, pitch=4.5, r=1.4, h=0.55)
    # room: brick courses (two reds) on a dark core
    n = 7
    ys = [FLOOR - SINK + i * (TOPW - FLOOR + SINK) / n for i in range(n + 1)]
    if k.lod == 2:
        for s in (-1, 1):
            k.box((s * RI, FLOOR, -W2), (s * W2, TOPW, -I2), P.RED, bev=0.1)
            k.box((-W2, FLOOR, s * I2 if s > 0 else -I2), (-I2, TOPW, W2 if s > 0 else I2), P.RED, bev=0.1)
            k.box((I2, FLOOR, s * I2 if s > 0 else -I2), (W2, TOPW, W2 if s > 0 else I2), P.RED, bev=0.1)
        k.box((-RI, SP + RO - 2, -W2), (RI, TOPW, -I2), P.RED, bev=0.1)
    else:
        for i in range(n):
            y0, y1 = ys[i], ys[i + 1] - (0.05 if i < n - 1 else 0)
            br_long = (0, 1 / 4, 1 / 2, 3 / 4, 1) if i % 2 else (0, 1 / 8, 3 / 8, 5 / 8, 7 / 8, 1)
            wall_run(k, I2, -W2, W2, br_long, y0, y1, "x", P.RED, c2=P.RRED, i0=i)              # back
            br = (0, 1 / 3, 2 / 3, 1) if i % 2 else (0, 1 / 6, 1 / 2, 5 / 6, 1)
            wall_run(k, -W2, -I2, I2, br, y0, y1, "z", P.RED, c2=P.RRED, i0=i + 1)                # sides
            wall_run(k, I2, -I2, I2, br, y0, y1, "z", P.RED, c2=P.RRED, i0=i + 2)
            if y0 < SP + RI:                                                   # front, either side of the door
                wall_run(k, -W2, -W2, -RI, (0, 0.5, 1) if i % 2 else (0, 1), y0, y1, "x", P.RED, c2=P.RRED, i0=i)
                wall_run(k, -W2, RI, W2, (0, 0.5, 1) if i % 2 else (0, 1), y0, y1, "x", P.RED, c2=P.RRED, i0=i + 1)
            else:
                wall_run(k, -W2, -W2, W2, br_long, y0, y1, "x", P.RED, c2=P.RRED, i0=i)
        mid = W2 - 1.3                                                         # the dark line in the seams
        k.box((-mid - 0.3, FLOOR, mid - 0.3), (mid + 0.3, TOPW - 0.3, mid + 0.3), P.INK, bev=0)
        for s in (-1, 1):
            k.box((s * mid - 0.3, FLOOR, -mid + 0.35), (s * mid + 0.3, TOPW - 0.3, mid - 0.35), P.INK, bev=0)
            k.box((s * (RO + mid) / 2 - (mid - RO) / 2, FLOOR, -mid - 0.3), (s * (RO + mid) / 2 + (mid - RO) / 2, TOPW - 0.3, -mid + 0.3), P.INK, bev=0)
        for i in range(6):                                                     # plank floor
            u = -I2 + i * 2 * I2 / 6
            k.box((u + 0.05, FLOOR - 0.15, -I2 + 0.01), (u + 2 * I2 / 6 - 0.05, FLOOR + 0.1, I2 - 0.01), P.RIB if i % 2 else P.TAN, bev=0.05, drop=("bottom",))
        k.box((-RI, FLOOR - 0.15, -W2 - 0.7), (RI, FLOOR + 0.1, -I2), P.TAN, bev=0.05, drop=("bottom",))
        for i in range(6):                                                     # the planks' stud edge, along both end walls
            u = -I2 + (i + 0.5) * 2 * I2 / 6
            for z in (-I2 + 1.3, -2.0, 6.6):
                k.stud(u, FLOOR + 0.1, z, P.RIB if i % 2 else P.TAN, 0.95, 0.3)
    # a 1-stud darker base course round the room, proud of the wall; a stud-topped door step at the join
    bt = FLOOR + 1.0
    for s in (-1, 1):
        k.brick((s * W2 - 1.0 if s > 0 else -W2 - 0.25, FLOOR - SINK, -W2 + 1.05), (W2 + 0.25 if s > 0 else -W2 + 1.0, bt, W2 - 1.05), P.DBG, bev=0.12)
        xa, xb = sorted((s * RO, s * (W2 + 0.25)))
        k.brick((xa, FLOOR - SINK, -W2 - 0.25), (xb, bt, -W2 + 1.0), P.DBG, bev=0.12)
    k.brick((-W2 - 0.25, FLOOR - SINK, W2 - 1.0), (W2 + 0.25, bt, W2 + 0.25), P.DBG, bev=0.12)
    k.brick((-RO - 0.6, FLOOR - SINK, -W2 - 3.4), (RO + 0.6, FLOOR + 0.6, -W2 - 0.7), P.STONE, bev=0.2)
    for x in (-5.4, 0.0, 5.4):
        k.stud(x, FLOOR + 0.6, -W2 - 2.05, P.STONE, 1.05, 0.4)
    # arch frame: jambs and voussoirs, white / yellow
    steps = 7
    for s in (-1, 1):
        h = (SP - FLOOR) / 3
        for i in range(3):
            k.box((s * RI, FLOOR - SINK + i * h, ZF), (s * RO, FLOOR + (i + 1) * h, ZB), P.YELLOW if i % 2 else P.WHITE, bev=0.2,
                  drop=("bottom",))
    for i in range(steps):
        a0, a1 = math.pi * (i + 0.03) / steps, math.pi * (i + 0.97) / steps
        quad = [(RI * math.cos(a0), SP + RI * math.sin(a0)), (RO * math.cos(a0), SP + RO * math.sin(a0)),
                (RO * math.cos(a1), SP + RO * math.sin(a1)), (RI * math.cos(a1), SP + RI * math.sin(a1))]
        k.prism([[(x, y, ZF) for x, y in quad], [(x, y, ZB) for x, y in quad]], P.YELLOW if i % 2 else P.WHITE)
    # windows: flanking the door, two on each other wall
    for s in (-1, 1):
        window(k, s * 11.4, 12.5, -W2, 2.6, 3.6)
    for yaw in (90, 180, 270):
        at = len(k.b.v)
        for s in (-1, 1):
            window(k, s * 6.6, 12.0, -W2, 3.6, 4.2)
        k.tilt(at, (0, 0, 0), yaw=yaw)
    # inside: human-sized bench, two lifebuoys, a crate
    if k.lod < 2:
        for s in (-1, 1):
            k.box((s * 5.0 - 0.55, FLOOR + 0.05, 8.6), (s * 5.0 + 0.55, 4.2 + FLOOR - 1.6, 11.6), P.BROWN, bev=0.08, drop=("bottom",))
        k.box((-6.2, 4.2 + FLOOR - 1.65, 8.3), (6.2, 4.9 + FLOOR - 1.6, 11.7), P.RIB, bev=0.1)
        k.ring(-4.2, 11.8, 11.25, 2.1, 0.6, (P.ORANGE, P.WHITE), sub=1)
        k.ring(4.2, 11.8, 11.25, 2.1, 0.6, (P.ORANGE, P.WHITE), sub=1)
        crate(k, -8.5, FLOOR + 0.05, 1.0, 3.2)
        # a straight trim course hides the wall top; 0.05 under the ceiling
        ty0, ty1, q = TOPW - 2.0, TOPW - 0.15, I2 - 0.3
        for s in (-1, 1):
            k.box((-I2 + 0.05, ty0, s * q - 0.3), (I2 - 0.05, ty1, s * q + 0.3), P.WHITE, bev=0.08)
            k.box((s * q - 0.3, ty0, -q + 0.35), (s * q + 0.3, ty1, q - 0.35), P.WHITE, bev=0.08)
        # lit stove: iron body, orange door, yellow fire, pipe to the ceiling
        k.box((6.4, FLOOR + 0.05, 3.6), (10.8, FLOOR + 5.2, 8.0), P.DBG, bev=0.25, drop=("bottom",))
        k.box((6.2, FLOOR + 5.15, 3.4), (11.0, FLOOR + 5.8, 8.2), P.INK, bev=0.15)
        k.box((7.0, FLOOR + 1.0, 3.3), (10.2, FLOOR + 4.2, 3.7), P.ORANGE, bev=0.1)
        k.box((7.7, FLOOR + 1.6, 3.15), (9.5, FLOOR + 3.6, 3.4), P.YELLOW, bev=0.08)
        k.cyl(8.6, 5.8, FLOOR + 5.75, TOPW - 0.05, 0.9, P.INK, n=10, bottom=False)
        # wall lamps: over the bench, over the crate
        for at_x, at_z, yaw in ((0.0, 11.0, 0), (-10.9, 1.0, 90)):
            at = len(k.b.v)
            k.box((at_x - 0.5, 11.2, at_z - 0.1), (at_x + 0.5, 13.4, at_z + 0.8), P.DBG, bev=0.1)
            k.frustum(at_x, at_z - 0.8, [(11.9, 0.7), (12.5, 1.15), (13.3, 1.15), (13.9, 0.6)], P.YELLOW, n=10)
            k.tilt(at, (at_x, 12.0, at_z), yaw=yaw)
    # cornice + bands
    cornice(k, 31.6, TOPW - 0.1, 1.9, P.WHITE)
    if k.lod == 0:
        for s in (-1, 1):
            k.stud_grid(-15.6, 15.6, s * 14.0 - 1.4, s * 14.0 + 1.4, TOPW + 1.8, P.WHITE, pitch=6.2, r=1.5, h=0.65)
            k.stud_grid(s * 14.0 - 1.4, s * 14.0 + 1.4, -11.0, 11.0, TOPW + 1.8, P.WHITE, pitch=7.3, r=1.5, h=0.65)
    band(k, 24.8, 22.7, 41.4, P.WHITE, P.STONE, h=3.2)
    cornice(k, 26.0, 41.3, 0.8, P.RED)
    band(k, 22.6, 42.0, 60.2, P.RED, P.RRED, h=3.2)
    cornice(k, 23.8, 60.1, 0.8, P.WHITE)
    band(k, 20.4, 60.8, 78.1, P.WHITE, P.STONE, h=3.2)
    for i in range(4):                                 # one big lifebuoy on each face of the red band
        at = len(k.b.v)
        k.ring(0.0, 51.1, -12.2, 4.2, 1.2, (P.WHITE, P.YELLOW), sub=2, mnr=4)
        k.tilt(at, (0, 51.1, 0), yaw=90.0 * i)


def beacon_top(k):
    """Gallery, lantern room, roof, day mark (own mesh: the beacon fills one MeshPart's budget). 20% wider than round 3, glass area x2."""
    # wide gallery on two stepped corbels
    k.box((-12.5, 78.0, -12.5), (12.5, 79.0, 12.5), P.STONE, bev=0.25)
    k.box((-17.5, 78.9, -17.5), (17.5, 80.0, 17.5), P.DBG, bev=0.3)
    k.box((-22.2, 79.9, -22.2), (22.2, GT, 22.2), P.YELLOW, bev=0.4)
    if k.lod == 0:
        for s in (-1, 1):
            k.stud_grid(-19.2, 19.2, s * 19.2 - 1.2, s * 19.2 + 1.2, GT, P.YELLOW, pitch=9.6, r=1.15, h=0.55)
            k.stud_grid(s * 19.2 - 1.2, s * 19.2 + 1.2, -9.6, 9.6, GT, P.YELLOW, pitch=9.6, r=1.15, h=0.55)
    if k.lod < 2:
        for i in range(6):
            u = -20.9 + i * 41.8 / 5
            for s in (-1, 1):
                k.box((u - 0.6, GT - SINK, s * 20.9 - 0.6), (u + 0.6, GT + 4.3, s * 20.9 + 0.6), P.WHITE, bev=0.14, drop=("bottom",))
                if 0 < i < 5:
                    k.box((s * 20.9 - 0.6, GT - SINK, u - 0.6), (s * 20.9 + 0.6, GT + 4.3, u + 0.6), P.WHITE, bev=0.14, drop=("bottom",))
    for s in (-1, 1):
        k.box((-21.8, GT + 4.2, s * 20.9 - 0.8), (21.8, GT + 5.1, s * 20.9 + 0.8), P.RED, bev=0.14)
        k.box((s * 20.9 - 0.75, GT + 4.25, -20.0), (s * 20.9 + 0.75, GT + 5.05, 20.0), P.RED, bev=0.12)
    # lantern room: red drum, white posts round the gold lantern and the glass (L08, L10), white lid
    k.frustum(0, 0, [(GT - 0.05, 17.0), (C0 - 0.5, 17.0), (C0, 16.7)], P.RED, n=24)
    k.cyl(0, 0, C0 - 0.1, LENS_Y - 7.1, 3.8, P.DBG, n=12, bottom=False)
    for i in range(8):
        at = len(k.b.v)
        k.box((14.2, C0 - 0.1, -1.1), (16.3, C1 + 0.1, 1.1), P.WHITE, bev=0.18, drop=("bottom",))
        k.tilt(at, (0, 0, 0), yaw=45.0 * i)
    k.frustum(0, 0, [(C1 - 0.05, 16.8), (C1 + 1.55, 16.8)], P.WHITE, n=24)
    # roof: three stepped red brick rings (like the HQ lantern cap), a stud per brick on each step
    T = C1 + 1.4
    rings = ((21.1, 12, 16.3), (16.3, 10, 11.5), (11.5, 8, 6.2))
    for li, (R, nb, R2) in enumerate(rings):
        y0, y1 = T + li * 3.6, T + (li + 1) * 3.6
        k.frustum(0, 0, [(y0 - 0.05, R - 0.25), (y1 - 0.15, R - 0.25)], P.RRED, n=24 - 4 * li)
        if k.lod == 2:
            k.frustum(0, 0, [(y0, R), (y1, R)], P.RED, n=12)
            continue
        for i in range(nb):
            a0, a1 = 2 * math.pi * (i + 0.015) / nb + li * 0.2, 2 * math.pi * (i + 0.985) / nb + li * 0.2
            am = (a0 + a1) / 2
            c = P.RED if i % 2 else P.RRED
            qbrick(k, [(q * math.cos(a), q * math.sin(a)) for q, a in ((R, a0), (R, a1), (R - 5.3, a1), (R - 5.3, a0))], y0, y1 + 0.05, c, bev=0.25)
            k.stud((R + R2) / 2 * math.cos(am), y1 + 0.05, (R + R2) / 2 * math.sin(am), c, 1.5, 0.65)
    T += 3.6 * len(rings)
    k.frustum(0, 0, [(T - 0.1, 5.5), (T + 2.4, 5.5), (T + 3.4, 3.4)], P.YELLOW, n=16)
    # day mark on a short mast: one bold faceted yellow diamond with a red belt, the same from every bearing
    y = T + 4.4
    k.box((-1.0, T + 3.3, -1.0), (1.0, y + 0.8, 1.0), P.WHITE, bev=0.12, drop=("bottom",))
    k.frustum(0, 0, [(y, 1.2), (y + 7.4, 10.1)], P.YELLOW, n=4, rot=math.pi / 4)
    k.frustum(0, 0, [(y + 7.3, 10.6), (y + 9.4, 10.6)], P.RED, n=4, rot=math.pi / 4)
    k.frustum(0, 0, [(y + 9.3, 10.1), (y + 16.7, 1.2)], P.YELLOW, n=4, rot=math.pi / 4)
    k.stud(0, y + 16.7, 0, P.YELLOW, 0.85, 0.45)


def beacon_lens(k):
    """The gold lantern (the code makes it Neon)."""
    rings = [(LENS_Y - 7.2, 5.4), (LENS_Y - 4.5, 8.4), (LENS_Y + 4.5, 8.4), (LENS_Y + 7.2, 5.4)]
    if k.lod == 2:
        rings = [(LENS_Y - 7.2, 7.4), (LENS_Y + 7.2, 7.4)]
    k.frustum(0, 0, rings, P.YELLOW, n=16)


def beacon_glass(k):
    """Pale-blue panes inside the lantern's posts (the code makes them clear; the same eight sides at every LOD)."""
    k.frustum(0, 0, [(C0 - 0.2, 14.6), (C1 + 0.2, 14.6)], P.GLASS, n=8 + 2 * k.lod)


# ------------------------------------------------------------------ L03 wreck
def hull_half(x):
    s = max(0.0, (x + 17.0) / 34.0)
    return 0.9 + 6.2 * min(1.0, s / 0.42) ** 0.55


def wreck(k):
    start = len(k.b.v)
    ys = [-2.6, -0.5, 1.6, 3.7, 5.8]
    bend = lambda y: 0.56 + 0.44 * ((y + 2.6) / 8.4) ** 0.6
    cols = (P.WHITE, P.RED, P.RED, P.WHITE)                                # white waterline band, red hull, white rail; a clean stepped tear aft
    ends = {-1: (17, 8, 2, -5), 1: (17, 11, -1, -7)}
    T = 0.85
    stn = 8 if k.lod < 2 else 4
    for side in (-1, 1):
        for i in range(4):
            y0, y1 = ys[i] + 0.1, ys[i + 1]
            xs = [-17.0 + (ends[side][i] + 17.0) * q / stn for q in range(stn + 1)]
            rings = []
            for x in xs:
                b = hull_half(x)
                o0, o1 = b * bend(y0), b * bend(y1)
                i0, i1 = max(0.08, o0 - T), max(0.08, o1 - T)
                rub = 0.3 if i == 3 else 0.0
                rings.append([(x, y0, side * (o0 + rub)), (x, y1, side * (o1 + rub)), (x, y1, side * i1), (x, y0, side * i0)])
            k.prism(rings, cols[i])
    # keel + stem
    k.box((-17.2, -3.5, -0.8), (19.5, -2.5, 0.8), P.BROWN, bev=0.2)
    k.box((-18.0, -3.0, -0.9), (-16.4, 8.6, 0.9), P.YELLOW, bev=0.2)
    # bottom plating, so the raised bow is never hollow from below
    k.prism([[(x, -2.65, -hull_half(x) * 0.56), (x, -2.65, hull_half(x) * 0.56), (x, -2.35, hull_half(x) * 0.56), (x, -2.35, -hull_half(x) * 0.56)]
             for x in (-17.0, -8.0, 0.0, 8.0, 17.0)], P.BROWN)
    # ribs: four separate broken pairs, 2 studs thick after the grow (1 stud = 1/1.5 here), one brown, the rest fresh wood; tops clear the sea
    ribs = ((2.5, 8.0, P.RIB), (8.0, 10.0, P.BROWN), (13.5, 10.5, P.RIB), (19.0, 11.5, P.RIB))
    for x, top0, c in ribs if k.lod < 2 else ribs[1::2]:
        b = hull_half(min(x, 17.0))
        k.box((x - 0.67, -2.6, -b * bend(-2.45)), (x + 0.67, -1.3, b * bend(-2.45)), P.BROWN, bev=0.14)
        for side in (-1, 1):
            top = top0 - (3.0 if side > 0 else 0.0)                    # the far side snapped lower
            zc = lambda t: side * (b * bend(-1.35 + t * (top + 1.35)) - 0.8 - 1.6 * t ** 3)
            segs = 4 if k.lod < 2 else 2
            for j in range(segs):
                t0, t1 = j / segs, (j + 1) / segs
                y0, y1 = -1.35 + t0 * (top + 1.35), -1.35 + t1 * (top + 1.35)
                k.prism([[(x - 0.67, y, zc(t) - 0.67), (x + 0.67, y, zc(t) - 0.67), (x + 0.67, y, zc(t) + 0.67), (x - 0.67, y, zc(t) + 0.67)]
                         for y, t in ((y0, t0), (y1, t1))], c)
            k.stud(x, top, zc(1.0), c, 0.62, 0.3)
    # foredeck: three wide planks, studded
    for i in range(3 if k.lod < 2 else 1):
        x0 = -14.0 + i * 4.2
        x1 = x0 + 4.12 if k.lod < 2 else -1.5
        hb = min(hull_half(x0), hull_half(x1)) * bend(4.3) - 0.5
        c = P.TAN if i % 2 else P.RIB
        k.box((x0, 3.9, -hb), (x1, 4.6, hb), c, bev=0.14)
        k.stud_grid(x0, x1, -hb, hb, 4.6, c, pitch=3.4, r=1.0, h=0.42)
    # tilted cabin + funnel, knocked off square
    cab = len(k.b.v)
    y = 4.4
    for i in range(3):
        k.box((-10.5, y + i * 1.75, -3.6), (-3.0, y + (i + 1) * 1.8, 3.6), P.WHITE, bev=0.2, drop=("bottom",))
    for s in (-1, 1):
        for x0 in (-9.6, -6.2):
            k.box((x0, y + 1.9, s * 3.6 - 0.1), (x0 + 2.2, y + 4.1, s * 3.6 + 0.1), P.YELLOW, bev=0.06)
            k.box((x0 + 0.3, y + 2.2, s * 3.6 - 0.18), (x0 + 1.9, y + 3.8, s * 3.6 + 0.18), P.INK, bev=0.03)
    k.box((-3.1, y + 1.9, -2.6), (-2.85, y + 4.1, 2.6), P.YELLOW, bev=0.06)
    k.box((-2.95, y + 2.2, -2.2), (-2.75, y + 3.8, 2.2), P.INK, bev=0.03)
    k.box((-11.4, y + 5.3, -4.5), (-2.2, y + 6.2, 4.5), P.RED, bev=0.24)
    fun = len(k.b.v)
    k.cyl(-6.8, 0, y + 6.1, y + 9.9, 2.1, P.ORANGE, n=16, bottom=False)
    k.frustum(-6.8, 0, [(y + 9.85, 2.25), (y + 10.9, 2.25)], P.WHITE, n=16)
    k.frustum(-6.8, 0, [(y + 10.85, 2.1), (y + 11.9, 2.1), (y + 12.05, 1.5)], P.ORANGE, n=16)
    k.tilt(fun, (-6.8, y + 6.2, 0), pitch=9.0, roll=-13.0)
    k.stud_grid(-11.2, -2.4, -4.3, 4.3, y + 6.2, P.RED, pitch=3.0, r=1.0, h=0.42,
                skip=lambda a, b: math.hypot(a + 6.8, b) < 3.4)
    k.tilt(cab, (-6.5, y, 0), yaw=9.0, pitch=-3.0, roll=9.0)
    # snapped mast with a torn flag, ahead of the ribs
    k.beam((-1.4, -2.0, 0.0), (0.4, 13.0, 1.2), 1.9, 1.9, P.BROWN)
    if k.lod < 2:
        fx, fy, fz = 0.3, 12.4, 1.2
        k.box((fx, fy - 2.6, fz - 0.1), (fx + 3.2, fy, fz + 0.1), P.ORANGE, bev=0.02)
        k.box((fx + 3.0, fy - 1.4, fz - 0.1), (fx + 5.2, fy, fz + 0.1), P.ORANGE, bev=0.02)
    k.grow(start, (0, 0, 0), 1.5)                       # the second silhouette after the beacon
    k.tilt(start, (0, 0, 0), pitch=-23.0, roll=10.0, lift=(0, 3.0, 0))   # clear bow-up tilt: stern under, the waterline cuts the hull
    # two orange crates afloat, well clear of the hull (not tilted with it)
    crate(k, 38.0, -1.6, -8.0, 5.6, P.ORANGE, P.WHITE)
    crate(k, 21.0, -1.4, -22.0, 4.6, P.ORANGE, P.WHITE)


# ------------------------------------------------------------------ small modules
def buoy(k):
    start = len(k.b.v)
    n = (16, 10, 8)[k.lod]
    k.cyl(0, 0, -2.5, 0.9, 4.8, P.GREEN, n=n, bottom=False)        # float
    k.cyl(0, 0, 0.5, 1.05, 6.25, P.INK, n=n, bottom=True)           # dark rim course
    k.cyl(0, 0, 1.0, 1.9, 6.0, P.WHITE, n=n, bottom=False)          # white collar
    k.frustum(0, 0, [(1.85, 4.0), (3.3, 3.6), (3.95, 2.3)], P.RED, n=n)
    for i in range(3):                                              # cage
        a = 2 * math.pi * i / 3 + 0.5
        k.beam((3.3 * math.cos(a), 3.3, 3.3 * math.sin(a)), (1.1 * math.cos(a), 9.0, 1.1 * math.sin(a)), 0.7, 0.7, P.RED)
    k.frustum(0, 0, [(6.7, 2.7), (7.2, 2.7)], P.YELLOW, n=n)        # cage hoop
    k.frustum(0, 0, [(8.9, 1.55), (10.2, 1.45), (10.75, 0.7)], P.YELLOW, n=n)   # lamp
    for i in range(10):
        a = 2 * math.pi * i / 10
        k.stud(5.0 * math.cos(a), 1.9, 5.0 * math.sin(a), P.WHITE, 0.72, 0.36)
    k.grow(start, (0, 0, 0), 1.4)
    # striped mast + flag above the lamp
    for i in range(3):
        y0 = 14.9 + i * 2.6
        k.cyl(0, 0, y0 - (SINK if i else 0.0), y0 + 2.6, 0.82 + 0.07 * (i % 2), P.WHITE if i % 2 else P.RED, n=(10, 8, 6)[k.lod], bottom=False)
    k.box((0.7, 18.8, -0.2), (7.5, 22.7, 0.2), P.YELLOW, bev=0.06)


def ledge(k, x, z, i0, j0, i1, j1, u, under, seed):
    """A tan brick ledge round a stack, corners cut, studded, top just above the waves; under = the first tier's cells (no brick there)."""
    if k.lod == 2:
        k.brick((x + i0 * u, -2.5, z + j0 * u), (x + i1 * u, 1.0, z + j1 * u), P.TAN, bev=0.3)
        return
    k.box((x + (i0 + 1) * u, -2.5, z + j0 * u + 0.1), (x + (i1 - 1) * u, 0.65, z + j1 * u - 0.1), P.DTAN, bev=0, drop=("bottom",))
    k.box((x + i0 * u + 0.1, -2.5, z + (j0 + 1) * u + 0.03), (x + i1 * u - 0.1, 0.61, z + (j1 - 1) * u - 0.03), P.DTAN, bev=0, drop=("bottom",))
    corners = {(i0, j0), (i1 - 1, j0), (i0, j1 - 1), (i1 - 1, j1 - 1)}
    cells = {(i, j) for i in range(i0, i1) for j in range(j0, j1)} - corners - under
    for a, b, c, d in plates(cells, random.Random(seed)):
        k.brick((x + a * u + 0.06, -2.5, z + b * u + 0.06), (x + c * u - 0.06, 1.0, z + d * u - 0.06), P.TAN, bev=0.3)
        for i in range(a, c):
            for j in range(b, d):
                k.stud(x + (i + 0.5) * u, 1.0, z + (j + 0.5) * u, P.TAN, 0.33 * u, 0.18 * u)


def rock_a(k):
    plan = ((-2, -1, 2, 2, 5.0), (-1, -1, 2, 1, 4.5), (-1, -1, 1, 1, 4.0))     # 13.5 tall, 3/4 of round 3; green cap, a gull
    ledge(k, 0.0, 0.0, -3, -2, 3, 3, 5.0, {(i, j) for i in range(-2, 2) for j in range(-1, 2)}, 33)
    x, y, z = rock(k, 0.0, 0.0, plan, 5.0, 31, P.GREEN)
    at = len(k.b.v)
    gull(k, x, y, z, 40.0)
    k.grow(at, (x, y, z), 1.5)


def rock_b(k):
    plan = ((-2, -2, 2, 2, 6.5), (-2, -1, 1, 2, 6.0), (-1, -1, 1, 1, 7.0))     # 19.5 tall, 3/4 of round 3; sand cap, a red/white marker
    ledge(k, 0.0, 0.0, -3, -3, 3, 3, 6.0, {(i, j) for i in range(-2, 2) for j in range(-2, 2)}, 43)
    x, y, z = rock(k, 0.0, 0.0, plan, 6.0, 41, P.SAND)
    for i in range(4):
        c = P.WHITE if i % 2 else P.RED
        k.brick((x - 1.5, y + i * 2.4 - SINK, z - 1.5), (x + 1.5, y + (i + 1) * 2.4, z + 1.5), c, bev=0.2)
    k.stud(x, y + 9.6, z, P.RED, 1.05, 0.42)


def raft(k):
    start = len(k.b.v)
    logs = 6
    for i in range(logs):
        z = -5.75 + i * 2.3
        k.b.cyl_x(*k.p(0, 0.25, z), 1.15, 16.0 - abs(i - 2.5) * 0.4, P.BROWN if i % 2 else P.RIB, n=(9, 7, 5)[k.lod])
    for x in (-5.5, 5.5):
        k.box((x - 0.8, 1.15, -7.0), (x + 0.8, 1.75, 7.0), P.TAN, bev=0.1)
        k.stud_grid(x - 0.8, x + 0.8, -7.0, 7.0, 1.75, P.TAN, pitch=2.8, r=0.62, h=0.28)
    crate(k, -3.0, 1.7, 1.2, 4.8, P.RED, P.WHITE)                               # red/white cargo
    crate(k, 2.2, 1.7, -3.0, 3.4, P.BROWN, P.TAN)
    crate(k, -3.0, 6.45, 1.2, 2.7, P.WHITE, P.RED)
    k.frustum(4.2, 2.8, [(1.7, 1.4), (3.0, 1.6), (4.2, 1.4)], P.ORANGE, n=12)   # barrel
    if k.lod < 2:                                                                # lifering against the cargo, white rim
        k.ring(-3.0, 4.2, 4.1, 1.9, 0.5, (P.ORANGE, P.ORANGE, P.WHITE))
        k.ring(-3.0, 4.2, 4.1, 2.42, 0.17, (P.WHITE,), mnr=4)
    k.cyl(1.7, 4.8, 1.7, 18.6, 0.5, P.BROWN, n=8, bottom=False)                  # mast, behind the cargo
    for i in range(5):                                                           # red/white brick stripes, running bond
        y0 = 7.0 + i * 2.0
        c = P.RED if i % 2 == 0 else P.WHITE
        cuts = (-2.3, 1.7, 5.7) if i % 2 == 0 else (-2.3, -0.3, 3.7, 5.7)
        for a, b in zip(cuts, cuts[1:]):
            k.brick((a + 0.03, y0 + 0.03, 4.1), (b - 0.03, y0 + 1.97, 4.7), c, bev=0.1, bottom=True)
    k.brick((1.75, 17.2, 4.6), (4.2, 18.4, 5.0), P.YELLOW, bev=0.08, bottom=True)             # pennant
    k.grow(start, (0, 0, 0), 2.0)


MODULES = [("L01_Atoll", "Atoll", atoll), ("L09_AtollDress", "Atoll", atoll_dress), ("L02_Beacon", "Beacon", beacon), ("L03_Wreck", "Wreck", wreck), ("L04_Buoy", "Buoy", buoy),
           ("L05_RockA", "RockA", rock_a), ("L06_RockB", "RockB", rock_b), ("L07_Raft", "Raft", raft),
           ("L08_BeaconLens", "Beacon", beacon_lens), ("L10_BeaconGlass", "Beacon", beacon_glass), ("L11_BeaconTop", "Beacon", beacon_top)]


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_HubKit_Brick", ALB)
    meshes, lods = [], {}
    for name, slot, fn in MODULES:
        tris = []
        for lod in (0, 1, 2):
            b = lego.B()
            fn(K(b, SLOTS[slot], lod=lod))
            tris.append(b.tris())
            if lod:
                lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat)
            else:
                obj = b.to_object(name, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        print("[hub] %-16s %6d / %5d / %5d tris" % (name, *tris))
    patch_lod(lods)
    c = lego.B()
    K(c, SLOTS["Atoll"]).box((-3, -1, -3), (3, 1, 3), P.DBG, bev=0)
    meshes.append({"object": c.to_object("Col01_COL", mat), "role": "col"})

    def att(n, x, y=0.0, z=0.0):
        return lego.attach(n, (-x, z, y))
    atts = [att("ATT_" + s, x) for s, x in SLOTS.items()]
    atts.append(att("ATT_Light", SLOTS["Beacon"], LENS_Y))

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[hub] LOD0 %d tris; dims_m %s" % (total, dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "a kit strip: every module is placed on its own by the code (ATT_<Slot> origins, LAYOUT in build.py)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Atoll...: the wiring code places each module by name",
            "LOD UV layout": "flat palette cells (one shared material): hand-made LODs drop studs and merge bricks, UVs are "
                             "not a unique unwrap by design (tiling=True skips the density check)",
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_HQAddons / M_Bld_Depot), no PBR scans",
        },
        "meshes": meshes,
        "attachments": atts,
    }
