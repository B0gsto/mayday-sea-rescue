"""M_Prop_CommonsKit: the idle crew's commons (shared/Hangout) and the six sold decorations as one Lego kit (SPEC.md).

One FBX, one flat palette material (BoardKit cells, 9 green / 13 pink), every module its own mesh. Modules sit side by
side along Roblox +X; each has an ATT_<Slot> empty at its own origin = the code frame it replaces (Hangout.frame(prop) /
DockConfig.decorSpot(key): ground centre, Roblox axes x right, y up, front -z). Authoring below is in that frame, so every
ATT_<Prop>_<Spot> equals the Hangout.SPOTS rest (sit / lie) or stand point the worker code already uses. The code Parts
stay as invisible colliders + fallback; seats keep Hangout's heights (CANTEEN_FLOOR 0.4 + STOOL 1.6, LOG 1.3,
BENCH 1.5, HAMMOCK 2.3). Lit parts (lamp globes, flame core) and the fountain water are separate meshes (<Module>Glow /
D06_FountainWater) so the code can make them Neon / Glass.

    python3 art/source/props/M_Prop_CommonsKit/maketex.py --out build/prod/M_Prop_CommonsKit/textures/M_Prop_CommonsKit
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_CommonsKit/build.py \
        --out-root build/prod/M_Prop_CommonsKit --steps build,lod,validate,export
(or, in the Blender MCP GUI: sys.path.insert(0, <this dir>); import build; build.build())
LODs are hand-made (patch_lod): LOD1 drops studs, LOD2 also drops small details (food, leaves, ropes); versions.decimate
only cuts further if one is over its target.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Prop_CommonsKit"
BUDGET = "hero_building"      # only for its triangle ceilings (15 modules); waiver below
TIER = "standard"
SET_NAME, SET = "CommonsKit", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_CommonsKit_Brick_ALB.png")

Y0 = -0.06          # every foot just under the ground: never coplanar with it
SINK = 0.04         # studs / props sink this far into the top they stand on (no bottom cap, nothing coplanar)
LIT = 100           # colour + LIT = drawn into the module's lit mesh (<Module>Glow / water) instead of the main mesh

# shared/Hangout.luau seat heights (keep in sync)
F, STOOL, LOG, BENCH, HAMMOCK = 0.4, 1.6, 1.3, 1.5, 2.3
PATIO = 0.10        # patio tile top (feet stand at 0: they sink 0.1 into the tiles, never float)
CURB = 0.5          # 1x brick edge top (studs on it)

# module origins in the kit strip, Roblox x (studs); Bench is shared by H04 (placed at BenchA and BenchB) and H05 (BenchA)
SLOTS = {"Canteen": 0, "Campfire": 18, "Bench": 31, "Hammock": 51, "Cart": 59, "ChatEast": 67, "ChatWest": 74,
         "FlowerBed": 83, "PicnicTable": 93, "LampRow": 103, "FlagPole": 113, "Statue": 122, "Fountain": 131}


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def patch_lod(prebuilt):
    """The lod step starts from our hand-made LOD1 / LOD2 meshes; LOD2 is decimated to fit the 3,000 asset ceiling."""
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
        if obj.name.endswith("_LOD1"):
            return          # hand LOD1 (12.4k) is under the 15k asset ceiling; the per-mesh 37.5% target is stricter
        try:                # LOD2: per-mesh targets are 7.5% of LOD0, the asset ceiling (3,000) allows ~15%
            orig(obj, 1.6 * target, symmetry)    # r4: 1.6 (was 1.75) for the 3,000 ceiling
        except RuntimeError:
            pass            # tiny meshes (a few closed pieces) keep their hand LOD2; validate checks the total
    versions.decimate = decimate


class K:
    """Roblox-axes authoring (x, y up, z back) on a lego.B at a slot origin; Blender = (-x, z, y). lod 0/1/2.
    lit=True keeps only parts whose colour has LIT added (the lit mesh); lit=False skips them."""

    def __init__(self, b, ox, oy=0.0, lod=0, lit=False):
        self.b, self.ox, self.oy, self.lod, self.lit = b, ox, oy, lod, lit

    def p(self, x, y, z):
        return (-(x + self.ox), z, y + self.oy)

    def _c(self, c):
        """The palette cell, or None when this part belongs to the other mesh."""
        return (c % LIT) if (c >= LIT) == self.lit else None

    def box(self, lo, hi, c, bev=None, drop=()):
        """drop: hidden faces left out: 'bottom', 'top', 'front' (-z), 'back' (+z)."""
        c = self._c(c)
        if c is None:
            return
        ids = {"bottom": 0, "top": 1, "front": 2, "back": 4}
        self.b.box(self.p(*lo), self.p(*hi), c, bevel=bev, drop=tuple(ids[d] for d in drop))

    def cyl(self, x, z, y0, y1, r, c, n=8, bottom=True):
        c = self._c(c)
        if c is None:
            return
        bx, by, _ = self.p(x, 0, z)
        self.b.cyl(bx, by, y0 + self.oy, y1 + self.oy, r, c, max(5, n - 2 * self.lod), bottom=bottom)

    def stud(self, x, y, z, c, r=0.3, h=0.2):
        """A Lego stud standing on the top at height y (dropped from the LODs)."""
        if not self.lod:
            self.cyl(x, z, y - SINK, y + h, r, c, 6, bottom=False)

    def studs(self, x0, x1, z0, z1, y, c, pitch=1.0, skip=None):
        """A grid of studs on the top rectangle x0..x1, z0..z1 at height y (pitch 1 = one Roblox stud, BoardKit scale)."""
        if self.lod:
            return
        nx, nz = max(1, round((x1 - x0) / pitch)), max(1, round((z1 - z0) / pitch))
        for i in range(nx):
            for j in range(nz):
                x, z = x0 + (i + 0.5) * (x1 - x0) / nx, z0 + (j + 0.5) * (z1 - z0) / nz
                if not (skip and skip(x, z)):
                    self.stud(x, y, z, c)

    def prism(self, lo, hi, c, smooth=False):
        """A closed solid between two equal rings of Roblox points (bottom ring lo, top ring hi)."""
        c = self._c(c)
        if c is None:
            return
        n = len(lo)
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        faces += [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
        self.b._emit([self.p(*q) for q in lo] + [self.p(*q) for q in hi], faces, c, smooth=smooth)

    def frustum(self, x, z, rings, c, n=10, rot=0.0):
        """Stacked rings [(y, r)] round a vertical axis, capped both ends (flat facets under 8 sides)."""
        c = self._c(c)
        if c is None:
            return
        n = max(4, n - 2 * self.lod) if n > 4 else n
        secs = [[self.p(x + r * math.cos(rot + 2 * math.pi * i / n), y, z + r * math.sin(rot + 2 * math.pi * i / n))
                 for i in range(n)] for y, r in rings]
        verts = [q for s in secs for q in s]
        faces = []
        for s in range(len(secs) - 1):
            for i in range(n):
                j = (i + 1) % n
                faces.append((s * n + i, s * n + j, (s + 1) * n + j, (s + 1) * n + i))
        faces += [tuple(reversed(range(n))), tuple(range((len(secs) - 1) * n, len(secs) * n))]
        self.b._emit(verts, faces, c, smooth=n >= 8)

    def rbox(self, cx, cz, yaw, w, d, y0, y1, c):
        """A box w (local x) by d (local z) turned yaw radians round y at (cx, cz)."""
        ca, sa = math.cos(yaw), math.sin(yaw)
        ring = [(cx + u * ca - v * sa, cz + u * sa + v * ca) for u, v in
                ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]
        self.prism([(a, y0, b) for a, b in ring], [(a, y1, b) for a, b in ring], c)

    def log(self, x0, x1, cy, cz, r, c, n=8):
        """A closed cylinder along x with a flat facet on top (seat tops land exactly on cy + r cos(pi / n))."""
        n = max(6, n - 2 * self.lod)
        ring = [(cy + r * math.cos(math.pi / n + 2 * math.pi * i / n), cz + r * math.sin(math.pi / n + 2 * math.pi * i / n))
                for i in range(n)]
        self.prism([(x0, y, z) for y, z in ring], [(x1, y, z) for y, z in ring], c, smooth=True)

    def logz(self, z0, z1, cx, cy, r, c, n=8):
        """A closed cylinder along z (wheels, hubs)."""
        n = max(6, n - 2 * self.lod)
        ring = [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        self.prism([(x, y, z0) for x, y in ring], [(x, y, z1) for x, y in ring], c, smooth=True)

    def ribbon(self, pts, y0, y1, t, c):
        """A closed cloth strip through (x, z) points (rippled flag), t half-thick in x, y0..y1 tall."""
        c = self._c(c)
        if c is None:
            return
        v, f = [], []
        for x, z in pts:
            v += [self.p(x - t, y0, z), self.p(x + t, y0, z), self.p(x + t, y1, z), self.p(x - t, y1, z)]
        for i in range(len(pts) - 1):
            a, b = 4 * i, 4 * i + 4
            f += [(a + j, b + j, b + (j + 1) % 4, a + (j + 1) % 4) for j in range(4)]
        f += [(0, 1, 2, 3), tuple(reversed(range(len(v) - 4, len(v))))]
        self.b._emit(v, f, c, smooth=False)

    def beam(self, p0, p1, w, h, c):
        c = self._c(c)
        if c is not None:
            self.b.beam(self.p(*p0), self.p(*p1), w, h, c)

    def prof_x(self, x0, x1, profile, c):
        """A (z, y) profile extruded along Roblox x (awning stripes)."""
        c = self._c(c)
        if c is not None:
            self.b.prof_x(-(x0 + self.ox), -(x1 + self.ox), [(z, y + self.oy) for z, y in profile], c)

    def ring(self, cx, cy, cz, R, r, colours, seg=8, sub=2, mnr=6, axis="z"):
        """A lifebuoy round the Roblox z (or x) axis: seg capped arcs cycling colours (BoardKit)."""
        if self.lit:
            return
        sub, mnr = ((sub, mnr), (1, 6), (1, 4))[self.lod]
        for k in range(seg):
            verts = []
            for i in range(sub + 1):
                u = 2 * math.pi * (k + i / sub) / seg
                for j in range(mnr):
                    v = 2 * math.pi * j / mnr
                    rr = R + r * math.cos(v)
                    if axis == "x":
                        verts.append(self.p(cx + r * math.sin(v), cy + rr * math.sin(u), cz + rr * math.cos(u)))
                    else:
                        verts.append(self.p(cx + rr * math.cos(u), cy + rr * math.sin(u), cz + r * math.sin(v)))
            faces = [(i * mnr + j, (i + 1) * mnr + j, (i + 1) * mnr + (j + 1) % mnr, i * mnr + (j + 1) % mnr)
                     for i in range(sub) for j in range(mnr)]
            self.b._emit(verts, faces, colours[k % len(colours)], smooth=True)


# ------------------------------------------------------------------ shared Lego pieces
def stack(k, x, z, y0, y1, w, colours, unit=1.2, gap=0.05, bev=0.04, d=None, seam=P.DBG):
    """A flush column of square bricks (BoardKit): crisp gap grooves over a dark core inset 0.1; LOD2 one box."""
    d = d or w
    n = 1 if k.lod == 2 else max(1, round((y1 - y0) / unit))
    ys = [y0 + i * (y1 - y0) / n for i in range(n + 1)]
    for i in range(n):
        k.box((x - w / 2, ys[i] + (gap if i else 0), z - d / 2), (x + w / 2, ys[i + 1], z + d / 2),
              colours[i % len(colours)], bev=bev, drop=("bottom",))
    if n > 1:
        k.box((x - w / 2 + 0.1, y0 + 0.03, z - d / 2 + 0.1), (x + w / 2 - 0.1, y1 - 0.1, z + d / 2 - 0.1), seam, bev=0,
              drop=("bottom", "top"))


def wall(k, axis, a0, a1, t0, t1, y0, y1, c, course=1.2, base=0.36, L=3.0, gap=0.05, seam=P.LBG):
    """Running-bond brick wall segment along `axis` ('x' or 'z'), a0..a1 long, t0..t1 thick. Courses sit on the global
    grid base + i * course (so segments round a window line up); joints stagger by half a brick per course."""
    def B(lo_a, hi_a, lo_y, hi_y, col, bev, drop):
        if axis == "x":
            k.box((lo_a, lo_y, t0), (hi_a, hi_y, t1), col, bev=bev, drop=drop)
        else:
            k.box((t0, lo_y, lo_a), (t1, hi_y, hi_a), col, bev=bev, drop=drop)
    if k.lod == 2:
        B(a0, a1, y0, y1, c, 0.04, ("bottom",))
        return
    i0 = math.floor((y0 - base) / course + 1e-6)
    i1 = math.ceil((y1 - base) / course - 1e-6)
    for i in range(i0, i1):
        cy0, cy1 = max(y0, base + i * course), min(y1, base + (i + 1) * course)
        if cy1 - cy0 < 0.1:
            continue
        off = (L / 2) * (i % 2)
        j = math.floor((a0 - off) / L)
        while off + j * L < a1:
            ba, bb = max(a0, off + j * L), min(a1, off + (j + 1) * L)
            if bb - ba > 0.15:
                B(ba + (gap / 2 if ba > a0 else 0), bb - (gap / 2 if bb < a1 else 0),
                  cy0 + (gap if cy0 > y0 else 0), cy1, c, 0.04, ("bottom",))
            j += 1
    m = 0.1 * (1 if t1 > t0 else -1)
    if axis == "x":
        k.box((a0 + 0.05, y0 + 0.03, t0 + m), (a1 - 0.05, y1 - 0.06, t1 - m), seam, bev=0, drop=("bottom", "top"))
    else:
        k.box((t0 + m, y0 + 0.03, a0 + 0.05), (t1 - m, y1 - 0.06, a1 - 0.05), seam, bev=0, drop=("bottom", "top"))


def patio(k, x0, x1, z0, z1, curbs=(), gaps=None):
    """A tan 1x-plate patio: dark tan seam slab (top 0.05) under 2 x 2 tan tiles (top PATIO, 0.1 inset from the slab edge),
    and a reddish-brown 1x brick edge (top CURB, studded, 0.04 inset) on the listed sides ('front' z0, 'back' z1,
    'left' x0, 'right' x1). gaps: {side: [(a, b), ...]} runs along the side left open (walk-ins, logs, flower boxes)."""
    gaps = gaps or {}
    k.box((x0, Y0, z0), (x1, 0.05, z1), P.DTAN, bev=0.02, drop=("bottom",))
    e = 0.1
    nx, nz = max(1, round((x1 - x0 - 2 * e) / 2.0)), max(1, round((z1 - z0 - 2 * e) / 2.0))
    tx, tz = (x1 - x0 - 2 * e) / nx, (z1 - z0 - 2 * e) / nz
    if k.lod == 2:
        k.box((x0 + e, 0.0, z0 + e), (x1 - e, PATIO, z1 - e), P.TAN, bev=0.02, drop=("bottom",))
    else:
        for i in range(nx):
            for j in range(nz):
                a, b = x0 + e + i * tx, z0 + e + j * tz
                k.box((a + 0.025, 0.0, b + 0.025), (a + tx - 0.025, PATIO, b + tz - 0.025), P.TAN, bev=0.02,
                      drop=("bottom",))
    i, w = 0.04, 1.0

    def run(side, a0, a1, fixed):
        cuts = sorted(gaps.get(side, []))
        segs, s = [], a0
        for g0, g1 in cuts:
            if g0 > s:
                segs.append((s, min(g0, a1)))
            s = max(s, g1)
        if s < a1:
            segs.append((s, a1))
        for s0, s1 in segs:
            n = max(1, round((s1 - s0) / 2.0))
            bl = (s1 - s0) / n
            for m in range(n):
                p0, p1 = s0 + m * bl + 0.025, s0 + (m + 1) * bl - 0.025
                if side in ("front", "back"):
                    lo, hi = (p0, 0.0, fixed), (p1, CURB, fixed + w)
                    k.box(lo, hi, P.BROWN, bev=0.05, drop=("bottom",))
                    k.studs(p0, p1, fixed, fixed + w, CURB, P.BROWN)
                else:
                    lo, hi = (fixed, 0.0, p0), (fixed + w, CURB, p1)
                    k.box(lo, hi, P.BROWN, bev=0.05, drop=("bottom",))
                    k.studs(fixed, fixed + w, p0, p1, CURB, P.BROWN)
    zs0 = z0 + i + (w + 0.05 if "front" in curbs else 0)
    zs1 = z1 - i - (w + 0.05 if "back" in curbs else 0)
    if "front" in curbs:
        run("front", x0 + i, x1 - i, z0 + i)
    if "back" in curbs:
        run("back", x0 + i, x1 - i, z1 - i - w)
    if "left" in curbs:
        run("left", zs0, zs1, x0 + i)
    if "right" in curbs:
        run("right", zs0, zs1, x1 - i - w)


def round_pad(k, r, n=12):
    """A round tan patio: dark tan seam disc (top 0.05) under a tan tile disc (top PATIO), 0.15 in."""
    k.frustum(0, 0, [(Y0, r), (0.05, r)], P.DTAN, n=n, rot=math.pi / n)
    k.frustum(0, 0, [(0.0, r - 0.15), (PATIO, r - 0.15)], P.TAN, n=n, rot=math.pi / n)


def flower(k, x, z, y, h, c, round_head=False):
    """A brick-built flower: green 1x1 round-bar stem, two 1x1 plate leaves, a 5-petal flower plate, a stud centre.
    round_head: a dense-bed bloom instead (icon): stem + a round 1x1 brick head, no leaves."""
    k.cyl(x, z, y - SINK, y + h, 0.1, P.GREEN, n=6, bottom=False)
    if round_head:
        rings = [(y + h, 0.3), (y + h + 0.1, 0.4), (y + h + 0.36, 0.4), (y + h + 0.44, 0.3)]
        k.frustum(x, z, rings if not k.lod else [(y + h, 0.4)] + rings[2:], c, n=8)      # r6: LOD1/2 one ring less (LOD1 15k cap)
        k.stud(x, y + h + 0.44, z, c, r=0.18, h=0.1)
        return
    if k.lod < 2:
        for s in (-1, 1):
            k.rbox(x + s * 0.28, z, s * 0.5, 0.5, 0.24, y + h * (0.35 if s < 0 else 0.55),
                   y + h * (0.35 if s < 0 else 0.55) + 0.1, P.GREEN)
    pts = [(x + (0.42 if i % 2 == 0 else 0.2) * math.cos(math.pi * i / 5),
            z + (0.42 if i % 2 == 0 else 0.2) * math.sin(math.pi * i / 5)) for i in range(10)]
    if k.lod == 2:
        k.cyl(x, z, y + h, y + h + 0.14, 0.38, c, n=6)
    else:
        k.prism([(a, y + h, b) for a, b in pts], [(a, y + h + 0.14, b) for a, b in pts], c)
    k.cyl(x, z, y + h + 0.1, y + h + 0.24, 0.14, P.WHITE if c == P.YELLOW else P.YELLOW, n=6, bottom=False)


BLOOMS = (P.PINK, P.YELLOW, P.WHITE, P.RED, P.PINK, P.ORANGE)


def flower_box(k, x, z, w=2, d=2, y=0.0, seed=0):
    """A green 2 x 2 brick planter with a flower on every stud."""
    top = y + 0.9
    k.box((x - w / 2, y + Y0, z - d / 2), (x + w / 2, top, z + d / 2), P.GREEN, bev=0.08, drop=("bottom",))
    for i in range(w):
        for j in range(d):
            n = seed + i * 2 + j
            flower(k, x - w / 2 + 0.5 + i, z - d / 2 + 0.5 + j, top, 0.7 + 0.25 * (n % 2), BLOOMS[n % len(BLOOMS)])


def shade_lamp(k, x, z, by, hc):
    """The LampRow icon lamp (r2): a thick round black post straight on the plate, collars, a round warm globe (lit
    mesh) in a black cup under a wide black conical shade with a stud. hc = globe centre height."""
    k.cyl(x, z, by - SINK, by + 0.3, 0.6, P.BLACK, n=10, bottom=False)        # round foot collar
    k.cyl(x, z, by + 0.26, hc - 0.6, 0.38, P.BLACK, n=10, bottom=False)
    for y in (by + 2.4, by + 5.0):
        k.cyl(x, z, y, y + 0.25, 0.5, P.BLACK, n=10)
    k.frustum(x, z, [(hc - 0.95, 0.42), (hc - 0.6, 0.62)], P.BLACK, n=10)     # globe cup
    k.frustum(x, z, [(hc - 0.66, 0.4), (hc - 0.4, 0.6), (hc, 0.68), (hc + 0.4, 0.6), (hc + 0.62, 0.36)],
              P.WHITE + LIT, n=10)
    k.frustum(x, z, [(hc + 0.45, 1.15), (hc + 0.62, 1.12), (hc + 1.45, 0.24)], P.BLACK, n=12)
    k.cyl(x, z, hc + 1.4, hc + 1.62, 0.2, P.BLACK, n=8, bottom=False)


def lamp(k, x, z, by, hc, base=1.6):
    """Lego park lamp: black 2 x 2 base plate (studs), round black post with collars, a lantern head: plate, warm globe
    (lit mesh), black plate and a four-sided black cap with a stud. hc = globe centre height."""
    k.box((x - base / 2, by + Y0 * (by == 0), z - base / 2), (x + base / 2, by + 0.4, z + base / 2), P.BLACK, bev=0.08,
          drop=("bottom",))
    k.studs(x - base / 2, x + base / 2, z - base / 2, z + base / 2, by + 0.4, P.BLACK, skip=None)
    k.cyl(x, z, by + 0.36, hc - 0.78, 0.28, P.BLACK, n=8, bottom=False)
    y = by + 2.2
    while y < hc - 1.6:
        k.cyl(x, z, y, y + 0.22, 0.38, P.BLACK, n=8)
        y += 2.4
    k.box((x - 0.65, hc - 0.8, z - 0.65), (x + 0.65, hc - 0.6, z + 0.65), P.BLACK, bev=0.05)
    k.frustum(x, z, [(hc - 0.62, 0.42), (hc - 0.45, 0.6), (hc + 0.45, 0.6), (hc + 0.62, 0.42)], P.WHITE + LIT, n=8)
    k.box((x - 0.7, hc + 0.6, z - 0.7), (x + 0.7, hc + 0.8, z + 0.7), P.BLACK, bev=0.05)
    k.frustum(x, z, [(hc + 0.78, 0.98), (hc + 1.45, 0.16)], P.BLACK, n=4, rot=math.pi / 4)
    k.cyl(x, z, hc + 1.42, hc + 1.62, 0.16, P.BLACK, n=6, bottom=False)


def cup(k, x, z, y, c, r=0.25, h=0.7):
    k.cyl(x, z, y - SINK, y + h, r, c, n=8, bottom=False)


# ------------------------------------------------------------------ H01 canteen (Hangout "Canteen", 14 x 12)
CANTEEN_EAT = {"EatFL": (-1.6, -2.9, 4), "EatBR": (1.6, 1.9, 5), "EatFR": (1.6, -2.9, 15), "EatBL": (-1.6, 1.9, 20)}
WIN = (-2.1, 1.1, 3.2, 5.6)       # side windows: z0, z1, y0, y1 (code CanteenWindow)


def canteen(k):
    T = F + 2.8                                       # table top 3.2
    k.box((-7, Y0, -6), (7, F - 0.04, 6), P.DTAN, bev=0.06, drop=("bottom",))
    # white / tan checker tiles inside, a stud row along the open front
    nx, nz, x0, z0 = 6, 5, -6.15, -5.4
    tx, tz = 12.3 / nx, 10.55 / nz
    if k.lod == 2:
        k.box((x0, F - 0.1, z0), (x0 + 12.3, F, z0 + 10.55), P.TAN, bev=0.02, drop=("bottom",))
    else:
        for i in range(nx):
            for j in range(nz):
                a, b = x0 + i * tx, z0 + j * tz
                k.box((a + 0.025, F - 0.1, b + 0.025), (a + tx - 0.025, F, b + tz - 0.025),
                      P.WHITE if (i + j) % 2 else P.TAN, bev=0.02, drop=("bottom",))
    k.studs(-6.5, 6.5, -5.95, -5.45, F - 0.04, P.DTAN)
    # walls: white running bond on a light grey core, blue-framed glazed side windows
    top = F + 7.05                                     # into the roof plate (no slit under it)
    wall(k, "x", -7.0, 7.0, 5.2, 6.0, F - 0.04, top, P.WHITE)
    z0w, z1w, y0w, y1w = WIN
    for s in (-1, 1):
        t0, t1 = s * 6.2, s * 7.0
        wall(k, "z", -5.6, z0w, t0, t1, F - 0.04, top, P.WHITE)
        wall(k, "z", z1w, 5.2, t0, t1, F - 0.04, top, P.WHITE)
        wall(k, "z", z0w, z1w, t0, t1, F - 0.04, y0w, P.WHITE)
        wall(k, "z", z0w, z1w, t0, t1, y1w, top, P.WHITE)
        f0, f1 = s * 6.15, s * 7.05
        k.box((f0, y0w - 0.25, z0w - 0.25), (f1, y0w, z1w + 0.25), P.BLUE, bev=0.04)          # sill
        k.box((f0, y1w, z0w - 0.25), (f1, y1w + 0.25, z1w + 0.25), P.BLUE, bev=0.04)          # head
        for za, zb in ((z0w - 0.25, z0w), (z1w, z1w + 0.25)):
            k.box((f0, y0w, za), (f1, y1w, zb), P.BLUE, bev=0.03)
        k.box((s * 6.55, y0w - 0.05, z0w - 0.05), (s * 6.65, y1w + 0.05, z1w + 0.05), P.GLASS, bev=0)
        k.box((f0, y0w + 1.15, z0w), (f1, y0w + 1.3, z1w), P.BLUE, bev=0)                    # glazing bar
    # red studded roof plate (code CanteenRoof 15.6 x 0.8 x 13.6), a stud ring round a raised red tile centre
    R0, R1 = F + 7.0, F + 7.8
    # r3: the roof front pulled back to z -5.6 (was -6.8) so the 3/4 game camera sees the front eaters and their food
    RZ = -5.6
    k.box((-7.8, R0, RZ), (7.8, R1, 6.8), P.RED, bev=0.08)
    k.box((-6.7, R1 - 0.04, RZ + 1.1), (6.7, R1 + 0.12, 5.7), P.RED, bev=0.04, drop=("bottom",))
    ring = lambda x, z: abs(x) < 6.9 and RZ + 0.9 < z < 5.9
    k.studs(-7.8, 7.8, RZ, 6.8, R1, P.RED, skip=ring)
    # r2: stepped centre (white course, studded red step) under a red ridge cap, so the roof reads from above
    S1 = R1 + 0.12
    k.box((-5.6, S1 - 0.04, -4.6), (5.6, S1 + 0.45, 4.6), P.WHITE, bev=0.06, drop=("bottom",))
    k.box((-4.6, S1 + 0.41, -3.6), (4.6, S1 + 0.9, 3.6), P.RED, bev=0.06, drop=("bottom",))
    k.studs(-5.6, 5.6, -4.6, 4.6, S1 + 0.45, P.WHITE, skip=lambda x, z: abs(x) < 4.7 and abs(z) < 3.7)
    k.prism([(-4.2, S1 + 0.86, -3.2), (4.2, S1 + 0.86, -3.2), (4.2, S1 + 0.86, 3.2), (-4.2, S1 + 0.86, 3.2)],
            [(-3.6, S1 + 1.9, -0.45), (3.6, S1 + 1.9, -0.45), (3.6, S1 + 1.9, 0.45), (-3.6, S1 + 1.9, 0.45)], P.RED)
    k.box((-3.75, S1 + 1.86, -0.6), (3.75, S1 + 2.1, 0.6), P.WHITE, bev=0.06, drop=("bottom",))      # ridge cap
    k.studs(-3.75, 3.75, -0.5, 0.5, S1 + 2.1, P.WHITE)
    # r2: sign plate standing on the front fascia: a yellow board, white border, a red noodle bowl with chopsticks
    zs = RZ - 0.21
    k.box((-3.2, R0 + 0.1, zs - 0.16), (3.2, R1 + 1.7, zs), P.WHITE, bev=0.06)
    k.box((-2.95, R0 + 0.35, zs - 0.22), (2.95, R1 + 1.45, zs - 0.12), P.YELLOW, bev=0.03, drop=("back",))
    bowl = [(1.05 * math.cos(math.pi + math.pi * i / 8), R1 + 0.75 + 0.95 * math.sin(math.pi + math.pi * i / 8))
            for i in range(9)]
    k.prism([(x, y, zs - 0.18) for x, y in bowl], [(x, y, zs - 0.3) for x, y in bowl], P.RED)
    k.box((-1.2, R1 + 0.72, zs - 0.31), (1.2, R1 + 0.9, zs - 0.18), P.RED, bev=0.02)
    for x in (0.2, 0.55):
        k.beam((x, R1 + 0.7, zs - 0.26), (x + 0.75, R1 + 1.35, zs - 0.26), 0.1, 0.1, P.BROWN)
    # r3: a striped red / white valance on the roof's front face (was a sloping awning that hid the eaters)
    n = 8
    for i in range(n):
        xa, xb = -7.8 + 15.6 * i / n, -7.8 + 15.6 * (i + 1) / n
        k.box((xa + 0.03, R0 - 0.2, RZ - 0.16), (xb - 0.03, R1 - 0.15, RZ - 0.05), P.RED if i % 2 == 0 else P.WHITE,
              bev=0.08)
    # serving counter: blue courses, white top, soup pot, bread crate
    stack(k, -2.5, 4.4, F - 0.04, F + 2.8, 5.0, [P.BLUE], unit=1.4, d=1.4)
    stack(k, 2.5, 4.4, F - 0.04, F + 2.8, 4.95, [P.BLUE], unit=1.4, d=1.4)
    k.box((-5.2, F + 2.8, 3.5), (5.2, F + 3.05, 5.15), P.WHITE, bev=0.05)
    k.studs(-5.2, -4.2, 3.5, 5.15, F + 3.05, P.WHITE)
    k.studs(4.2, 5.2, 3.5, 5.15, F + 3.05, P.WHITE)
    k.cyl(-2.5, 4.4, F + 3.01, F + 4.25, 0.8, P.DBG, n=12, bottom=False)
    k.cyl(-2.5, 4.4, F + 4.21, F + 4.45, 0.9, P.DBG, n=12)                     # pot rim
    k.cyl(-2.5, 4.4, F + 4.41, F + 4.5, 0.7, P.ORANGE, n=12, bottom=False)     # soup
    for s in (-1, 1):
        k.box((-2.5 + s * 0.8, F + 3.9, 4.25), (-2.5 + s * 1.05, F + 4.1, 4.55), P.DBG, bev=0.03)
    k.box((1.6, F + 3.01, 3.85), (3.4, F + 3.6, 4.95), P.BROWN, bev=0.06, drop=("bottom",))
    if k.lod < 2:
        for i in range(3):
            k.box((1.75 + i * 0.55, F + 3.55, 4.05), (2.2 + i * 0.55, F + 3.85, 4.75), P.TAN, bev=0.08)
    # r2: drinks and food on the counter ends: a blue juice jug, stacked plates, a fruit bowl
    if k.lod < 2:
        k.cyl(4.7, 4.3, F + 3.01, F + 4.1, 0.38, P.BLUE, n=10, bottom=False)
        k.box((4.95, F + 3.4, 4.22), (5.15, F + 3.9, 4.38), P.BLUE, bev=0.02)
        for i in range(3):
            k.cyl(-4.7, 4.3, F + 3.21 + 0.12 * i, F + 3.33 + 0.12 * i, 0.5 - 0.02 * i, P.WHITE, n=10, bottom=False)
        k.cyl(3.9, 4.6, F + 3.01, F + 3.35, 0.45, P.GREEN, n=10, bottom=False)
        for i, c in enumerate((P.RED, P.ORANGE, P.YELLOW)):
            a = 2 * math.pi * i / 3
            k.frustum(3.9 + 0.2 * math.cos(a), 4.6 + 0.2 * math.sin(a), [(F + 3.25, 0.12), (F + 3.38, 0.2),
                      (F + 3.55, 0.18), (F + 3.62, 0.08)], c, n=6)
    # the table: yellow studded-corner top on brown legs, laid for four (code Table / FoodBowl / FoodCup / plate)
    k.box((-3.6, T - 0.4, -2), (3.6, T, 1), P.YELLOW, bev=0.06)        # r4: 0.6 wider each end for the food
    for x in (-3.4, 3.4):
        for z in (-1.8, 0.8):
            k.stud(x, T, z, P.YELLOW)
    for x in (-2.5, 2.5):
        for z in (-1.5, 0.5):
            k.box((x - 0.25, F - 0.04, z - 0.25), (x + 0.25, T - 0.4, z + 0.25), P.BROWN, bev=0.04, drop=("bottom", "top"))
    for name, (x, z, _) in CANTEEN_EAT.items():
        # r4: food 1.5x (plate r 1.0, bowl r 0.96, noodle dome to +1.5); the front pair's beside them on the camera
        # side of the table edge (x +-2.6, z -1.0), clear of their arms; the back pair's in front of them
        fx, fz = (x * 1.62, -1.0) if z < -0.5 else (x, 0.0)
        k.cyl(fx, fz, T - SINK, T + 0.14, 0.95, P.WHITE, n=14, bottom=False)          # plate
        k.frustum(fx, fz, [(T + 0.1, 0.6), (T + 0.35, 0.82), (T + 0.92, 0.96)], P.RED, n=14)   # bowl
        k.frustum(fx, fz, [(T + 0.86, 0.84), (T + 1.18, 0.75), (T + 1.45, 0.45), (T + 1.55, 0.12)], P.YELLOW, n=12)
        if not k.lod:
            k.beam((fx + 0.2, T + 1.2, fz - 0.3), (fx + 0.9, T + 2.0, fz - 0.55), 0.12, 0.12, P.BROWN)   # chopsticks
        if k.lod < 2:
            cup(k, *((x * 0.55, -1.0) if z < -0.5 else (x * 1.9, 0.3)), T, P.BLUE, r=0.28, h=0.8)
        # Lego stool: round 2 x 2 tile seat (top = Hangout rest) on a dark round post
        k.cyl(x, z, F - 0.04, F + STOOL - 0.36, 0.3, P.DBG, n=8, bottom=False)
        k.cyl(x, z, F + STOOL - 0.4, F + STOOL, 0.6, P.RED, n=12)
    # r4: a front serving counter at the open front (right corner, clear of the walk-in): blue bricks, white studded
    # top, a dark till with a glass screen and a stack of orange / red trays
    stack(k, 4.95, -4.7, F - 0.04, F + 2.4, 2.3, [P.BLUE], unit=1.2, d=1.2)
    k.box((3.7, F + 2.4, -5.4), (6.15, F + 2.65, -4.0), P.WHITE, bev=0.05)
    k.box((5.0, F + 2.61, -5.0), (5.95, F + 3.2, -4.2), P.DBG, bev=0.06, drop=("bottom",))          # till
    k.rbox(5.47, -4.5, 0.0, 0.8, 0.12, F + 3.15, F + 3.75, P.DBG)
    k.box((5.12, F + 3.25, -4.62), (5.82, F + 3.65, -4.5), P.GLASS, bev=0.0)                        # screen
    for i, c in enumerate((P.ORANGE, P.RED, P.ORANGE, P.RED)):                                      # tray stack
        k.box((3.95, F + 2.61 + 0.14 * i, -5.15), (4.85, F + 2.75 + 0.14 * i, -4.25), c, bev=0.03, drop=("bottom",))
    if k.lod < 2:
        k.cyl(0, 0.35, T - SINK, T + 0.1, 0.62, P.WHITE, n=12, bottom=False)        # plate
        k.box((-0.5, T + 0.1, 0.12), (0.05, T + 0.5, 0.58), P.TAN, bev=0.1)        # bread
        k.frustum(0.3, 0.4, [(T + 0.08, 0.18), (T + 0.2, 0.27), (T + 0.48, 0.25), (T + 0.58, 0.12)], P.RED, n=8)
        k.cyl(0.3, 0.4, T + 0.54, T + 0.7, 0.05, P.GREEN, n=5, bottom=False)


# ------------------------------------------------------------------ H02 campfire (12 x 12)
CAMP_SIT = {"SitFL": (-1.3, -4.5, 9), "SitBR": (1.3, 4.5, 10), "SitFR": (1.3, -4.5, 21), "SitBL": (-1.3, 4.5, 24)}
CAMP_WARM = {"WarmR": (4.6, 0.0, 16), "WarmL": (-4.6, 0.0, 25)}
CAMP_LAMP = (3.8, 4.8, 6.2)       # x, z, globe centre (back-right corner, clear of the log ends)


def campfire(k):
    # patio: open front / back edges (the log benches hang to them), side curbs with a walk-in to each warm spot
    patio(k, -5.9, 5.9, -5.9, 5.9, curbs=("left", "right"), gaps={"left": [(-1.6, 1.6)], "right": [(-1.6, 1.6)]})
    # (side curbs run the full depth; the corner flower boxes / lamp stand on the tiles inside them)
    for x, z, s in ((-3.8, -4.8, 0), (3.8, -4.8, 3), (-3.8, 4.8, 5)):
        flower_box(k, math.copysign(4.3, x), z, w=1, y=PATIO - 0.04, seed=s)      # r2: 1 x 2, clear of the logs
    lamp(k, CAMP_LAMP[0], CAMP_LAMP[1], PATIO - 0.04, CAMP_LAMP[2], base=1.0)
    # r3: a raised stone hearth (dark round 2-course base) in a ring of 8 round 2 x 2 grey stones, studded
    k.cyl(0, 0, Y0, 0.5, 1.45, P.DBG, n=16, bottom=False)
    k.cyl(0, 0, 0.46, 0.9, 1.25, P.DBG, n=16, bottom=False)
    k.cyl(0, 0, 0.86, 1.3, 1.05, P.DBG, n=16, bottom=False)            # r4: +1 plate (hearth top 1.3)
    ST = 2.3                                          # r6: stone ring +1 plate again (top 2.3: reads over the logs)
    for i in range(8):
        a = (i + 0.5) / 8 * math.pi * 2
        x, z = 2.05 * math.sin(a), -2.05 * math.cos(a)
        if k.lod:                                     # LOD1/2: one round brick (LOD1 15k cap)
            k.cyl(x, z, Y0, ST, 0.67, P.STONE, n=10, bottom=False)
        else:
            k.cyl(x, z, Y0, 0.9, 0.68, P.STONE, n=12, bottom=False)
            k.cyl(x, z, 0.95, ST, 0.66, P.STONE, n=12, bottom=False)
        k.stud(x, ST, z, P.STONE)
    # r6: two chunky round fire logs (r 0.68) stacked crosswise on the hearth, big tan end caps with a dark-tan core
    # (the top log's caps stand clear over the stones)
    for lx, ly in ((True, 1.94), (False, 3.0)):
        (k.log if lx else k.logz)(-1.42, 1.42, *((ly, 0.0) if lx else (0.0, ly)), 0.68, P.BROWN, n=10)
        if not k.lod:
            for s in (-1, 1):
                a0, a1 = sorted((s * 1.36, s * 1.52))
                b0, b1 = sorted((s * 1.48, s * 1.58))
                if lx:
                    k.log(a0, a1, ly, 0.0, 0.56, P.TAN, n=10)
                    k.log(b0, b1, ly, 0.0, 0.26, P.DTAN, n=8)
                else:
                    k.logz(a0, a1, 0.0, ly, 0.56, P.TAN, n=10)
                    k.logz(b0, b1, 0.0, ly, 0.26, P.DTAN, n=8)
    # r6: three stacked Lego flame pieces (orange bulb, the yellow lit core = H02_CampfireGlow, orange tip), each a
    # bulb pinched to a point inside the next, with five orange tongues licking out round the base. Tip clears the
    # seated minifigs' heads (4.9)
    flame = [(0.0, 0.3), (0.35, 0.95), (0.8, 1.0), (1.35, 0.6), (1.9, 0.08)]       # (rise, radius scale)
    for y0, sc, c, rot in ((2.5, 1.2, P.ORANGE, 0.0), (3.9, 1.0, P.YELLOW + LIT, math.pi / 8),
                           (5.15, 0.75, P.ORANGE, 0.0)):
        k.frustum(0, 0, [(y0 + dy * sc * 1.05, r * sc) for dy, r in flame], c, n=8, rot=rot)
    if not k.lod:                                     # (LOD1 15k cap)
        for i in range(5):                            # tongues: tilted 4-sided spikes, base inside the bulb
            a = 2 * math.pi * (i + 0.25) / 5
            ca, sa = math.cos(a), math.sin(a)
            base = [(0.75 * ca + 0.32 * math.cos(b), 3.0, 0.75 * sa + 0.32 * math.sin(b))
                    for b in (a, a + math.pi / 2, a + math.pi, a + 1.5 * math.pi)]
            k.prism(base, [(1.45 * ca + 0.04 * math.cos(b), 4.5, 1.45 * sa + 0.04 * math.sin(b))
                           for b in (a, a + math.pi / 2, a + math.pi, a + 1.5 * math.pi)], P.ORANGE)
    # log benches (code LogBench d 1.3 at z +-4.5): flat-topped reddish-brown logs at Hangout.LOG on tan end rings
    r = (LOG + 0.04) / 2 / math.cos(math.pi / 8)      # flat top facet at LOG, bottom facet 0.04 under the ground
    for z in (-4.5, 4.5):
        k.log(-3.15, 3.15, (LOG - 0.04) / 2, z, r, P.BROWN)               # r2: longer than the two sitters
        if not k.lod:                                 # r4: cut ends LOD0 only (LOD1 15k cap)
            for s in (-1, 1):
                k.log(min(s * 3.11, s * 3.21), max(s * 3.11, s * 3.21), (LOG - 0.04) / 2, z, r * 0.8, P.TAN)   # cut end


# ------------------------------------------------------------------ H04 park bench (BenchA / BenchB, 6 x 3)
BENCH_SIT = {"SitL": (-1.2, 0.0, (3, 17)), "SitR": (1.2, 0.0, (12, 22))}


def bench(k):
    """r2: an open Lego park bench: 1x1 dark legs on foot plates, three green seat slats (tops at Hangout.BENCH), two
    back slats on the back legs, studded top slat, 1x1 armrests on front posts."""
    L = 3.4                                           # r2: half length: the seat shows past the two sitters
    for x in (-2.9, 2.9):
        k.box((x - 0.4, Y0, -0.85), (x + 0.4, 0.22, 1.1), P.DBG, bev=0.05, drop=("bottom",))           # foot plate
        k.box((x - 0.25, 0.18, -0.75), (x + 0.25, BENCH - 0.4, -0.25), P.DBG, bev=0.04, drop=("bottom", "top"))
        k.box((x - 0.25, 0.18, 0.62), (x + 0.25, 4.45, 1.12), P.DBG, bev=0.04, drop=("bottom", "top"))    # back leg
    for i in range(3):                                # r4: tan seat slats (lift off the green hedge), tops at BENCH
        z0 = -0.8 + i * 0.47
        k.box((-L, BENCH - 0.4, z0), (L, BENCH, z0 + 0.42), P.TAN, bev=0.06)
    for y0 in (1.95, 3.0):                            # r6: two thin tan back slats with 1.5-plate open gaps (0.6)
        k.box((-L, y0, 0.48), (L, y0 + 0.45, 0.66), P.TAN, bev=0.05)
    k.box((-L, 4.05, 0.45), (L, 4.45, 0.69), P.TAN, bev=0.05)                      # rail over the shoulders (3.6)
    k.box((-L, 4.41, 0.42), (L, 4.65, 1.12), P.TAN, bev=0.05)
    k.studs(-L, L, 0.42, 1.12, 4.65, P.TAN)
    for s in (-1, 1):                                 # r4: armrests: a tan 1 x 2 plate on a dark 1 x 1 brick post
        x = s * (L + 0.42)
        k.box((x - 0.4, Y0, -0.82), (x + 0.4, 2.15, -0.02), P.DBG, bev=0.06, drop=("bottom",))
        k.box((x - 0.42, 2.11, -0.86), (x + 0.42, 2.5, 0.6), P.TAN, bev=0.06)
        k.studs(x - 0.42, x + 0.42, -0.06, 0.6, 2.5, P.TAN, pitch=0.82)
        k.box((x - 0.38, 2.46, -0.82), (x + 0.38, 3.66, -0.06), P.DBG, bev=0.08, drop=("bottom",))    # r6: 1 x 1 brick
        k.stud(x, 3.66, -0.44, P.DBG)                                                # end block, dark on the tan
        k.box((x - 0.3, BENCH - 0.35, 0.05), (x + 0.3, 2.15, 0.5), P.DBG, bev=0.04, drop=("top",))


# ------------------------------------------------------------------ H05 bench patio (BenchA frame; BenchB at x +12)
BENCH_LAMP = (6.0, 1.55, 6.2)


def bench_patio(k):
    x0, x1, z0, z1 = -5.0, 17.0, -2.6, 2.6           # r2: shallower (z was -3.5), wider for the longer benches
    patio(k, x0, x1, z0, z1, curbs=("back", "left", "right"), gaps={"back": [(3.0, 9.0)]})
    for x, s in ((4.0, 1), (8.0, 4)):
        flower_box(k, x, 1.55, y=PATIO - 0.04, seed=s)
    lamp(k, BENCH_LAMP[0], BENCH_LAMP[1], PATIO - 0.04, BENCH_LAMP[2])
    # r2: a green Lego litter bin between the benches (round 2 x 2 bricks, dark lid with a stud)
    for i in range(2):
        k.cyl(6.0, -0.9, PATIO - 0.04 + 0.72 * i, PATIO + 0.68 + 0.72 * i, 0.62, P.GREEN, n=12, bottom=False)
    k.cyl(6.0, -0.9, PATIO + 1.38, PATIO + 1.62, 0.7, P.DBG, n=12)
    k.stud(6.0, PATIO + 1.62, -0.9, P.DBG)


# ------------------------------------------------------------------ H06 hammock (3 x 10)
def hammock(k):
    """r4: two matching 2 x 2 brown brick posts (4 bricks, tan studded caps) at z +-4.5, a long red / white striped
    sling hung between them in a U (flat middle = the lie rest at Hangout.HAMMOCK, r6: ties 1.2 higher, posts 7.16), spreader bars,
    white ropes up to the post tops, a pillow at +z (r6: side table cut).
    shortcut: the pad grows to z +-5.5 (Hangout 3 x 10 is +-5); check the plot clearance if the hammock moves."""
    PZ = 4.5
    patio(k, -1.5, 1.5, -PZ - 1.0, PZ + 1.0)
    for z in (-PZ, PZ):                               # 2 x 2 posts
        stack(k, 0, z, PATIO - 0.04, 6.8, 1.96, [P.BROWN], unit=1.12 * (1 + k.lod), d=1.96)   # r5: 6 bricks (LOD1 3, 15k cap)
        k.box((-1.05, 6.76, z - 1.05), (1.05, 7.16, z + 1.05), P.TAN, bev=0.06, drop=("bottom",))
        k.studs(-1.05, 1.05, z - 1.05, z + 1.05, 7.16, P.TAN)
    H = HAMMOCK
    # five lengthwise stripes, white / red; the red ones 0.02 lower (no shared faces)
    # r4: 3.0 wide (past the 2 x 2 posts by 0.45 a side) so the stripes show round the front post at game camera
    # r6: the sling 80% of the spreader bar (2.6 of 3.24), five 0.52 stripes
    stripes = [(x, 0.52, -0.02 if i % 2 else 0.0, P.RED if i % 2 else P.WHITE)
               for i, x in enumerate((-1.04, -0.52, 0.0, 0.52, 1.04))]
    # r6: an even sag: flat under the body, then a smooth curve up to ties 1 brick (1.2) above the lie rest
    prof = [(0.0, 0.0), (0.9, 0.0)] + [(z, 1.2 * ((z - 0.9) / 2.4) ** 2) for z in (1.5, 2.1, 2.7, 3.3)]   # (z, rise)
    for xc, w, dy, c in stripes:
        h = 0.25 if not dy else 0.21
        k.box((xc - w / 2, H + dy - h, -0.9), (xc + w / 2, H + dy, 0.9), c, bev=0.04)
        for s in (-1, 1):
            for (za, ra), (zb, rb) in zip(prof[1:], prof[2:]):
                k.beam((xc, H + dy + ra - h / 2, s * (za - 0.06)), (xc, H + dy + rb - h / 2, s * (zb + 0.03)), w, h, c)
    TY = H + 1.2                                      # spreader bar height (tie line)
    for s in (-1, 1):
        k.log(-1.62, 1.62, TY, s * 3.36, 0.14, P.BROWN, n=6)                     # spreader bar
        # r6: white ropes from the bar ends + middle straight up to the post top (under the cap; LOD1/2: one)
        for x in ((-1.45, 0.0, 1.45) if not k.lod else (0.0,)):
            k.beam((x, TY + 0.05, s * 3.36), (x * 0.4, 6.7, s * 3.62), 0.14, 0.14, P.WHITE)
    if k.lod < 2:
        k.beam((0, H + 0.4, 2.0), (0, H + 0.8, 2.75), 1.4, 0.32, P.YELLOW)        # pillow at the head end (+z)


# ------------------------------------------------------------------ H07 ice-cream cart (5 x 4)
CART_CONE = {"ConeL": (-1.3, -3.2, 6), "ConeR": (1.3, -3.2, 19)}


def cart(k):
    """r4: the cart body one brick taller again (glass top 5.4) so the counter, cones and topper read over the queue's
    heads (5.6); r6: four dark grey wheels with tan hubs on the long sides, a front serving tray, a push handle on the camera end (-x), giant
    cone + scoop topper, pink / white umbrella."""
    U = 1.2                                               # r4 lift of everything above the chassis
    patio(k, -3.0, 3.0, -4.2, 2.75, curbs=("back",))      # r6: curb 1.71..2.71, clear of the back wheels (1.66)
    k.box((-2.0, 0.95, -1.2), (2.0, 3.95 + U, 1.2), P.WHITE, bev=0.08)
    k.box((-2.05, 2.6 + U, -1.25), (2.05, 3.1 + U, 1.25), P.PINK, bev=0.04)
    k.box((-2.05, 1.3, -1.25), (2.05, 1.6, 1.25), P.PINK, bev=0.04)                 # r4: lower trim band
    k.box((-2.1, 3.91 + U, -1.3), (2.1, 4.2 + U, 1.3), P.GLASS, bev=0.06, drop=("bottom",))
    CONES, BIG, POLE = (-0.6, 0.2, 1.0), (-1.3, 0.35), (1.7, 0.6)
    k.studs(-2.1, 2.1, -1.3, 1.3, 4.2 + U, P.GLASS,
            skip=lambda x, z: (abs(z + 0.65) < 0.5 and -1.1 < x < 1.5) or math.hypot(x - BIG[0], z - BIG[1]) < 0.8
            or math.hypot(x - POLE[0], z - POLE[1]) < 0.5)
    k.box((-1.9, 0.7, -1.0), (1.9, 0.99, 1.0), P.DBG, bev=0.03)                    # chassis plate
    # r6: four wheels on the long sides (two show on the camera's front side): dark grey tyre r 0.86, tan hub, axles
    for x in (-1.25, 1.25):
        k.logz(-1.6, 1.6, x, 0.8, 0.1, P.LBG, n=6)                                  # axle
        for s in (-1, 1):
            k.logz(*sorted((s * 1.15, s * 1.5)), x, 0.8, 0.86, P.DBG, n=14)
            k.logz(*sorted((s * 1.46, s * 1.6)), x, 0.8, 0.42, P.TAN, n=10)
            if not k.lod:
                k.logz(*sorted((s * 1.56, s * 1.66)), x, 0.8, 0.18, P.TAN, n=8)
    # r6: a front serving tray at the counter (grey shelf on two dark brackets) with two cones waiting
    k.box((-1.7, 3.0 + U, -1.95), (1.7, 3.24 + U, -1.15), P.LBG, bev=0.05)
    for x in (-1.3, 1.3):
        k.beam((x, 2.2 + U, -1.25), (x, 3.02 + U, -1.8), 0.2, 0.2, P.DBG)
    if k.lod < 2:
        for x, c in ((-0.7, P.PINK), (0.5, P.YELLOW)):
            k.frustum(x, -1.55, [(3.2 + U, 0.06), (3.75 + U, 0.2)], P.DTAN, n=6)
            k.frustum(x, -1.55, [(3.7 + U, 0.22), (3.85 + U, 0.27), (4.05 + U, 0.2), (4.12 + U, 0.06)], c, n=6)
    for z in (-0.85, 0.85):                                                        # push handle at -x (camera)
        k.beam((-1.95, 3.0 + U, z), (-2.95, 3.85 + U, z), 0.2, 0.2, P.LBG)
    k.box((-3.1, 3.72 + U, -1.05), (-2.8, 4.02 + U, 1.05), P.DBG, bev=0.08)        # handle grip
    # three cones with round-brick scoops (code ConeShow / Scoop)
    for x, c in zip(CONES, (P.PINK, P.WHITE, P.YELLOW)):
        k.frustum(x, -0.65, [(4.16 + U, 0.07), (4.85 + U, 0.24)], P.DTAN, n=6)
        k.frustum(x, -0.65, [(4.8 + U, 0.26), (4.98 + U, 0.33), (5.2 + U, 0.28), (5.32 + U, 0.1)], c, n=8)
    # the giant cone + scoop topper (reads "ice cream" over the minifigs' heads at game camera)
    bx, bz = BIG
    k.frustum(bx, bz, [(4.16 + U, 0.14), (6.0 + U, 0.7)], P.DTAN, n=8)
    k.frustum(bx, bz, [(5.9 + U, 0.72), (6.05 + U, 0.86), (6.45 + U, 0.92), (6.9 + U, 0.8), (7.2 + U, 0.5),
                       (7.32 + U, 0.16)], P.PINK, n=10)
    k.frustum(bx, bz, [(5.86 + U, 0.76), (5.98 + U, 0.95), (6.1 + U, 0.8)], P.WHITE, n=10)          # drip ring
    k.frustum(bx, bz, [(7.22 + U, 0.12), (7.32 + U, 0.22), (7.5 + U, 0.2), (7.6 + U, 0.06)], P.RED, n=6)  # cherry
    # striped pink / white umbrella on a white pole (raised over the topper)
    cx, cz, n = POLE[0], POLE[1], 8
    U2 = U + 0.4                                          # r6: umbrella 1 plate higher, clear of the topper
    k.cyl(cx, cz, 4.16 + U, 7.6 + U2, 0.1, P.WHITE, n=6, bottom=False)
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        ra = (cx + 2.2 * math.cos(a0), cz + 2.2 * math.sin(a0))
        rb = (cx + 2.2 * math.cos(a1), cz + 2.2 * math.sin(a1))
        k.prism([(cx, 8.0 + U2, cz), (ra[0], 7.4 + U2, ra[1]), (rb[0], 7.4 + U2, rb[1])],
                [(cx, 8.15 + U2, cz), (ra[0], 7.55 + U2, ra[1]), (rb[0], 7.55 + U2, rb[1])], P.PINK if i % 2 else P.WHITE)
    k.cyl(cx, cz, 8.08 + U2, 8.35 + U2, 0.32, P.WHITE, n=8)


# ------------------------------------------------------------------ H08 / H09 chat circles
CHAT_E = {"01": (0.0, -2.35, 1), "02": (2.035, 1.175, 2), "03": (-2.035, 1.175, 11)}   # r6: radius 2.35 (was 1.8)
CHAT_W = {"L": (-1.4, 0.0, 13), "R": (1.4, 0.0, 14)}   # r6: was +-1.1
CHATW_LAMP = (0.0, 0.95, 5.8)


def chat_east(k):
    """r2: a round patio, a bar-height round high-top in the middle (one drink per talker) under a big blue / white
    umbrella over the talkers' heads."""
    round_pad(k, 2.45)
    k.cyl(0, 0, PATIO - 0.04, PATIO + 0.3, 0.8, P.DBG, n=12, bottom=False)
    # r4: a wide white 3 x 3 round top (r 1.45, top 4.2 at the talkers' shoulders) on a blue rim, 2 cups in the gaps
    # between the front talker and the back pair, where the 3/4 camera sees them past the front head
    T = 0.4                                                                      # r6: top +1 plate (4.6)
    k.cyl(0, 0, PATIO + 0.26, 3.85 + T, 0.3, P.DBG, n=8, bottom=False)
    k.cyl(0, 0, 2.2, 2.45, 0.45, P.DBG, n=10)                                    # foot-rest collar
    k.cyl(0, 0, 3.81 + T, 3.97 + T, 1.55, P.BLUE, n=20)                          # blue rim plate
    k.cyl(0, 0, 3.93 + T, 4.2 + T, 1.45, P.WHITE, n=20)
    if k.lod < 2:
        k.studs(-0.5, 0.5, -0.5, 0.5, 4.2 + T, P.WHITE)
    for x, c in ((1.0, P.RED), (-1.0, P.ORANGE)):
        cup(k, x, -0.3, 4.2 + T, c, r=0.27, h=0.66)
    # r4: umbrella raised 1.5 bricks (rim 8.4) so the table shows under it
    n, UY = 8, 1.8
    k.cyl(0, 0, 4.56, 7.0 + UY, 0.1, P.WHITE, n=6, bottom=False)
    for i in range(n):
        a0, a1 = 2 * math.pi * (i + 0.5) / n, 2 * math.pi * (i + 1.5) / n
        ra, rb = (2.7 * math.cos(a0), 2.7 * math.sin(a0)), (2.7 * math.cos(a1), 2.7 * math.sin(a1))
        k.prism([(0, 7.3 + UY, 0), (ra[0], 6.6 + UY, ra[1]), (rb[0], 6.6 + UY, rb[1])],
                [(0, 7.46 + UY, 0), (ra[0], 6.76 + UY, ra[1]), (rb[0], 6.76 + UY, rb[1])], P.BLUE if i % 2 else P.WHITE)
    k.cyl(0, 0, 7.38 + UY, 7.65 + UY, 0.3, P.WHITE, n=8)


def chat_west(k):
    """r3: a brown barrel high-top between the two talkers (round 2 x 2 barrel with dark hoops, a 3 x 3 round tan top,
    two drinks) and a short lean rail behind them; one small lantern on the rail (the lit mesh; ATT_ChatWest_Lamp
    stays the code's light point above)."""
    patio(k, -2.5, 2.5, -1.5, 1.5)
    R = 0.65                                          # r5: lean rail 0.65 taller, posts out past the talkers (x +-1.1)
    for x in (-2.1, 2.1):
        stack(k, x, 1.05, PATIO - 0.04, 2.6 + R, 0.5, [P.BROWN], unit=0.83)
    k.box((-2.45, 2.6 + R, 0.75), (2.45, 2.85 + R, 1.35), P.DTAN, bev=0.05)
    k.studs(-2.45, 2.45, 0.75, 1.35, 2.85 + R, P.DTAN, skip=lambda x, z: abs(x) < 0.5)
    k.box((-0.3, 2.81 + R, 0.75), (0.3, 3.0 + R, 1.35), P.BLACK, bev=0.04, drop=("bottom",))         # lantern
    k.frustum(0, 1.05, [(2.96 + R, 0.2), (3.06 + R, 0.26), (3.4 + R, 0.26), (3.5 + R, 0.2)], P.WHITE + LIT, n=8)
    k.frustum(0, 1.05, [(3.46 + R, 0.34), (3.7 + R, 0.08)], P.BLACK, n=4, rot=math.pi / 4)
    # r4: a small crate stack on the camera side (-x) so the corner reads as a hang-out
    k.box((-2.45, PATIO - 0.04, -1.05), (-1.6, 0.95, -0.2), P.BROWN, bev=0.06, drop=("bottom",))
    k.box((-2.4, 0.91, -1.0), (-1.65, 1.0, -0.25), P.DTAN, bev=0.02, drop=("bottom",))
    if not k.lod:
        for i, c in enumerate((P.ORANGE, P.YELLOW, P.RED, P.ORANGE)):          # a crate of fruit on top
            fx, fz = -2.25 + 0.4 * (i % 2), -0.85 + 0.4 * (i // 2)
            k.frustum(fx, fz, [(0.96, 0.12), (1.06, 0.19), (1.3, 0.18), (1.38, 0.08)], c, n=6)
    # the barrel (feet on the ground: its front stands past the patio edge); r4: a hip-height barrel (top 2.2, under the
    # talkers' hands) with a wide 3 x 3 round tan top, a cup and a white mug, in front where the camera sees it
    bz = -2.0
    k.frustum(0, bz, [(Y0, 0.62), (0.6, 0.74), (1.4, 0.74), (1.9, 0.64)], P.BROWN, n=14)
    for y in (0.3, 1.5):
        k.cyl(0, bz, y, y + 0.2, 0.73, P.DBG, n=14)
    k.cyl(0, bz, 1.86, 1.98, 0.7, P.DTAN, n=14)
    k.cyl(0, bz, 1.94, 2.2, 1.45, P.TAN, n=20)
    if k.lod < 2:
        k.studs(-0.5, 0.5, bz - 0.5, bz + 0.5, 2.2, P.TAN, pitch=1.0)
    cup(k, -0.85, bz - 0.35, 2.2, P.RED, r=0.26, h=0.6)
    k.cyl(0.8, bz - 0.4, 2.16, 2.95, 0.32, P.WHITE, n=10, bottom=False)          # mug
    k.cyl(0.8, bz - 0.4, 2.91, 3.07, 0.36, P.WHITE, n=10)                        # foam
    if k.lod < 2:
        k.box((1.1, 2.35, bz - 0.5), (1.32, 2.75, bz - 0.3), P.WHITE, bev=0.04)  # handle


# ------------------------------------------------------------------ D01..D06 decorations (DockConfig sizes)
def flower_bed(k):
    """8 x 8 (r2, icon): green studded base plate, a wood-brown 2-course brick bed (studded top), dark chocolate soil,
    a dense 6 x 6 field of round pastel pink / lilac / yellow 1x1 flower heads."""
    k.box((-4, Y0, -4), (4, 0.4, 4), P.GREEN, bev=0.06, drop=("bottom",))
    k.studs(-4, 4, -4, 4, 0.4, P.GREEN, skip=lambda x, z: max(abs(x), abs(z)) < 3.45)
    o, t = 3.15, 2.4                                    # bed wall outer / inner half widths (clear of the stud ring)
    for y0, y1 in ((0.36, 0.9), (0.95, 1.45)):
        for s in (-1, 1):
            k.box((-o, y0, s * t), (o, y1, s * o), P.BROWN, bev=0.05, drop=("bottom",))
            k.box((s * t, y0, -t + 0.05), (s * o, y1, t - 0.05), P.BROWN, bev=0.05, drop=("bottom",))
    for s in (-1, 1):
        k.studs(-o, o, min(s * t, s * o), max(s * t, s * o), 1.45, P.BROWN)
        k.studs(min(s * t, s * o), max(s * t, s * o), -t + 0.05, t - 0.05, 1.45, P.BROWN)
    k.box((-t - 0.05, 0.36, -t - 0.05), (t + 0.05, 1.2, t + 0.05), P.CHOC, bev=0.0, drop=("bottom",))   # soil
    bed = (P.PINK, P.LILAC, P.YELLOW, P.LILAC, P.PINK, P.WHITE, P.YELLOW)
    for i in range(6):
        for j in range(6):
            flower(k, -1.95 + 0.78 * i, -1.95 + 0.78 * j, 1.2, 0.5 + 0.28 * ((i + j) % 2) + 0.1 * ((i * j) % 3 == 1),
                   bed[(i * 3 + j * 2) % len(bed)], round_head=True)


def picnic_table(k):
    """8 x 8 (r2): wood plank tiles over a brown core (no studs: planks, not brick courses), a small centred coral /
    white checked mat, two plank benches, brown A-frames."""
    top0, top1, b0, b1 = 2.05, 2.55, 1.15, 1.65         # code TableTop / Bench heights

    def planks(z0, z1, y0, y1, n):
        k.box((-2.96, y0, z0 + 0.04), (2.96, y1 - 0.12, z1 - 0.04), P.CHOC, bev=0.03)
        w = (z1 - z0) / n
        for i in range(n):                              # r3: 0.16 gaps between the boards over a dark core
            k.box((-3.0, y1 - 0.16, z0 + i * w + 0.08), (3.0, y1, z0 + (i + 1) * w - 0.08), P.DTAN, bev=0.05,
                  drop=("bottom",))
    planks(-2.0, 2.0, top0, top1, 5)
    k.box((-1.3, top1 - 0.03, -1.3), (1.3, top1 + 0.04, 1.3), P.CORAL, bev=0.03, drop=("bottom",))   # r3: one salmon
    for s in (-1, 1):                                   # mat tile; benches 0.3 out so the far one shows past the top
        planks(min(s * 2.3, s * 3.6), max(s * 2.3, s * 3.6), b0, b1, 2)
    for x in (-2.2, 2.2):                               # A-frame legs and the bench bearer
        for s in (-1, 1):
            k.beam((x, 0.05, s * 2.3), (x, top0 - 0.05, s * 0.4), 0.45, 0.45, P.BROWN)
        k.box((x - 0.22, b0 - 0.35, -3.6), (x + 0.22, b0, 3.6), P.BROWN, bev=0.04, drop=("top",))
        k.box((x - 0.22, top0 - 0.3, -1.9), (x + 0.22, top0, 1.9), P.BROWN, bev=0.04, drop=("top",))


LAMP_ROW = (-3.0, 0.0, 3.0)
LAMP_HC = 9.5          # code LampBulb centre


def lamp_row(k):
    """9 x 6 (r2, icon): green studded plate (code Rail 9 x 0.6 x 1.6), three thick black lamps straight on it (round
    warm globes under black conical shades), flower bricks between."""
    k.box((-4.5, Y0, -0.8), (4.5, 0.6, 0.8), P.GREEN, bev=0.06, drop=("bottom",))
    k.studs(-4.5, 4.5, -0.8, 0.8, 0.6, P.GREEN, skip=lambda x, z: min(abs(x - l) for l in LAMP_ROW) < 0.9 or
            min(abs(x - l) for l in (-1.5, 1.5)) < 0.6)
    for x in LAMP_ROW:
        shade_lamp(k, x, 0.0, 0.6, LAMP_HC)
    for x, s in ((-1.5, 2), (1.5, 5)):
        flower_box(k, x, 0.0, w=1, d=1, y=0.56, seed=s)


FLAG = (0.0, 17.8, 3.6)       # code Flag centre (0.15 x 4.5 x 7): ATT_FlagPole_Cloth stays here
CLOTH = (11.7, 20.1, 0.8, 14.6)     # r6: 1.38x r4 each way off the 2-stud pole (cloth: y0, y1, z0, z1)
EMBLEM = (15.9, 4.1, 1.87)   # lifebuoy emblem centre y, z, ring radius (on the cloth's flat inner half; r6 1.17x)


def flag_pole(k):
    """7 x 7: wide grey round studded base, white studded brick, white pole with grey collars, gold ball finial, cleat,
    clips holding the cloth."""
    # r3: the grey round base stands on a green studded plate (icon)
    k.box((-3.0, Y0, -3.0), (3.0, 0.36, 3.0), P.GREEN, bev=0.06, drop=("bottom",))
    k.studs(-3.0, 3.0, -3.0, 3.0, 0.36, P.GREEN, skip=lambda x, z: math.hypot(x, z) < 2.75)
    k.frustum(0, 0, [(0.32, 2.6), (0.76, 2.6)], P.STONE, n=16, rot=math.pi / 16)
    for i in range(12):
        a = 2 * math.pi * (i + 0.5) / 12
        k.stud(2.15 * math.cos(a), 0.76, 2.15 * math.sin(a), P.STONE)
    k.box((-1.55, 0.72, -1.55), (1.55, 1.16, 1.55), P.WHITE, bev=0.08, drop=("bottom",))      # r6: wider for the pole
    for x, z in ((-1.15, -1.15), (1.15, -1.15), (-1.15, 1.15), (1.15, 1.15)):
        k.stud(x, 1.16, z, P.WHITE)
    k.cyl(0, 0, 1.12, 1.56, 1.2, P.LBG, n=12, bottom=False)
    k.cyl(0, 0, 1.52, 20.4, 1.0, P.WHITE, n=12, bottom=False)                      # r6: a true 2-stud round pole
    for y in (5.0, 10.0):
        k.cyl(0, 0, y, y + 0.3, 1.12, P.LBG, n=12)
    k.cyl(0, 0, 20.3, 20.5, 1.12, P.LBG, n=12)                                      # r4: collar under the finial
    k.frustum(0, 0, [(20.46, 0.5), (20.58, 0.95), (20.95, 1.25), (21.4, 1.35), (21.85, 1.25), (22.2, 0.95),
                     (22.35, 0.4)], P.GOLD, n=14)                                     # r6: gold ball over the 2-stud pole
    
    k.box((0.95, 2.9, -0.15), (1.3, 3.7, 0.15), P.LBG, bev=0.03)                    # halyard cleat
    for y in (CLOTH[0] + 0.5, CLOTH[1] - 0.5):                                      # Lego clips holding the flag
        k.box((-0.16, y - 0.3, 0.9), (0.16, y + 0.3, 1.25), P.LBG, bev=0.04)


def flag_cloth(k):
    """The flag as its own mesh (the code tints it the owner colour; coral by default, the icon's salmon red): flat by
    the pole under the emblem, then r3: a full two-bend ripple (one wave, amplitude 0.6) to the fly end."""
    y0, y1, z0, z1 = CLOTH
    zr, st = 6.7, 0.4 * (1 + k.lod)                    # r6: ripple from 6.7 (scaled cloth)                  # LOD1/2 coarser ripple (LOD1 15k cap)
    pts = [(0.0, z0)] + [(0.7 * math.sin(2 * math.pi * (z - zr) / (z1 - zr)), z)
                         for z in [zr + i * (z1 - zr) / round((z1 - zr) / st) for i in range(round((z1 - zr) / st) + 1)]]
    k.ribbon(pts, y0, y1, 0.075, P.CORAL)


def flag_emblem(k):
    """The white lifebuoy emblem through the cloth (own mesh, not named Flag, so the owner tint leaves it white)."""
    y, z, R = EMBLEM
    k.ring(0.0, y, z, R, 0.66, [P.WHITE, P.RED], seg=8, sub=2, mnr=8, axis="x")    # r6: scaled with the cloth


def statue(k):
    """7 x 7: stepped grey plinth with a white studded top plate, a gold minifig (right arm raised) holding a red /
    white lifebuoy (icon). Gold = palette cell 3."""
    # r2: stepped plinth: 6 x 6 studded base, a bevelled 1-stud grey step, grooved column, bevelled white top
    k.box((-3.0, Y0, -3.0), (3.0, 0.6, 3.0), P.STONE, bev=0.08, drop=("bottom",))
    k.studs(-3.0, 3.0, -3.0, 3.0, 0.6, P.STONE, skip=lambda x, z: max(abs(x), abs(z)) < 2.45)
    k.box((-2.2, 0.56, -2.2), (2.2, 1.0, 2.2), P.STONE, bev=0.12, drop=("bottom",))
    stack(k, 0, 0, 0.96, 1.8, 4.1, [P.STONE], unit=0.42, seam=P.DBG)
    k.box((-2.3, 1.7, -2.3), (2.3, 1.86, 2.3), P.STONE, bev=0.06)                # r4: bevelled plinth cap
    k.box((-1.1, 1.08, -2.12), (1.1, 1.62, -2.0), P.GOLD, bev=0.04, drop=("back",))   # r4: front tile plaque
    k.box((-2.1, 1.8, -2.1), (2.1, 2.2, 2.1), P.WHITE, bev=0.14)
    for x, z in ((-1.6, -1.6), (1.6, -1.6), (-1.6, 1.6), (1.6, 1.6)):
        k.stud(x, 2.2, z, P.WHITE)
    Gd = P.GOLD
    for s in (-1, 1):                                  # legs, feet forward
        k.box((s * 0.05, 2.16, -0.8), (s * 1.3, 4.1, 0.8), Gd, bev=0.1, drop=("bottom",))
    k.box((-1.3, 4.05, -0.8), (1.3, 4.5, 0.8), Gd, bev=0.06)               # hips, into the torso
    k.prism([(-1.55, 4.45, -0.8), (1.55, 4.45, -0.8), (1.55, 4.45, 0.8), (-1.55, 4.45, 0.8)],
            [(-1.2, 7.0, -0.7), (1.2, 7.0, -0.7), (1.2, 7.0, 0.7), (-1.2, 7.0, 0.7)], Gd)          # torso
    k.cyl(0, 0, 6.96, 7.25, 0.5, Gd, n=10, bottom=False)
    k.frustum(0, 0, [(7.2, 0.9), (7.3, 1.0), (8.9, 1.0), (9.0, 0.9)], Gd, n=14)                   # head
    k.cyl(0, 0, 8.96, 9.4, 0.55, Gd, n=10, bottom=False)
    k.beam((-1.45, 6.6, 0), (-2.0, 4.9, -0.2), 0.8, 0.8, Gd)                                       # left arm down
    k.beam((1.45, 6.6, 0), (1.9, 9.3, 0), 0.8, 0.8, Gd)                                             # right arm up
    k.cyl(1.95, 0, 9.25, 9.85, 0.4, Gd, n=8)                                                        # raised hand
    k.ring(-2.3, 4.4, -0.45, 1.0, 0.36, [P.RED, P.WHITE])                                         # lifebuoy


def seg(k, a0, a1, r0, r1, y0, y1, c):
    """One curved brick: the annulus sector a0..a1 (radians) between radii r0 and r1."""
    ring = [(r0 * math.cos(a0), r0 * math.sin(a0)), (r1 * math.cos(a0), r1 * math.sin(a0)),
            (r1 * math.cos(a1), r1 * math.sin(a1)), (r0 * math.cos(a1), r0 * math.sin(a1))]
    k.prism([(x, y0, z) for x, z in ring], [(x, y1, z) for x, z in ring], c)


def fountain(k):
    """7 x 7 (r2, icon proportions): wide round basin (thin curved grey bricks, staggered white studded coping, a dark
    inner rim at the water line), a low grey column with a collar, a white upper bowl with a rim, a spout. Water (the
    D06_FountainWater mesh): lower disc, upper disc, a water column and splash crown up to the jet (5.15)."""
    n, g = 16, 0.012                                     # bricks per ring, angular groove (~0.04 studs)
    k.frustum(0, 0, [(Y0, 3.05), (0.5, 3.05)], P.STONE, n=n)
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        seg(k, a0 + g, a1 - g, 2.98, 3.45, Y0, 0.85, P.STONE)
        h = math.pi / n                                  # coping staggered half a brick
        seg(k, a0 + h + g, a1 + h - g, 2.94, 3.49, 0.9, 1.25, P.WHITE)
        k.stud(3.2 * math.cos(a0 + 2 * h), 1.25, 3.2 * math.sin(a0 + 2 * h), P.WHITE)
        seg(k, a0 + g, a1 - g, 2.86, 3.02, 0.82, 1.1, P.DBG)                         # dark inner rim
    k.cyl(0, 0, 0.46, 2.75, 0.7, P.STONE, n=12, bottom=False)
    k.cyl(0, 0, 1.5, 1.75, 0.85, P.LBG, n=12)
    k.frustum(0, 0, [(2.7, 0.64), (2.9, 1.5), (3.35, 1.75)], P.WHITE, n=n)
    for i in range(n if k.lod < 2 else 8):
        m = n if k.lod < 2 else 8
        seg(k, 2 * math.pi * i / m + g, 2 * math.pi * (i + 1) / m - g, 1.45, 1.8, 3.3, 3.6, P.WHITE)
    k.cyl(0, 0, 3.4, 4.1, 0.32, P.STONE, n=8, bottom=False)                           # spout
    k.frustum(0, 0, [(4.05, 0.45), (4.2, 0.5), (4.35, 0.25)], P.WHITE, n=10)
    k.frustum(0, 0, [(0.46, 2.9), (1.0, 2.9)], P.GLASS + LIT, n=n)       # lower water (code Water top 1.4)
    k.frustum(0, 0, [(3.3, 1.5), (3.45, 1.5)], P.GLASS + LIT, n=n)       # upper water, inside the rim
    k.cyl(0, 0, 4.3, 4.95, 0.17, P.GLASS + LIT, n=8, bottom=False)       # water column
    k.frustum(0, 0, [(4.9, 0.15), (5.08, 0.5), (5.15, 0.56), (5.25, 0.36)], P.GLASS + LIT, n=10)   # splash crown


# (mesh name, slot, builder, lit mesh?)
MODULES = [
    ("H01_Canteen", "Canteen", canteen, False),
    ("H02_Campfire", "Campfire", campfire, False), ("H02_CampfireGlow", "Campfire", campfire, True),
    ("H04_ParkBench", "Bench", bench, False),
    ("H05_BenchPatio", "Bench", bench_patio, False), ("H05_BenchPatioGlow", "Bench", bench_patio, True),
    ("H06_Hammock", "Hammock", hammock, False),
    ("H07_IceCart", "Cart", cart, False),
    ("H08_ChatEast", "ChatEast", chat_east, False),
    ("H09_ChatWest", "ChatWest", chat_west, False), ("H09_ChatWestGlow", "ChatWest", chat_west, True),
    ("D01_FlowerBed", "FlowerBed", flower_bed, False),
    ("D02_PicnicTable", "PicnicTable", picnic_table, False),
    ("D03_LampRow", "LampRow", lamp_row, False), ("D03_LampRowGlow", "LampRow", lamp_row, True),
    ("D04_FlagPole", "FlagPole", flag_pole, False), ("D04_FlagCloth", "FlagPole", flag_cloth, False),
    ("D04_FlagEmblem", "FlagPole", flag_emblem, False),
    ("D05_Statue", "Statue", statue, False),
    ("D06_Fountain", "Fountain", fountain, False), ("D06_FountainWater", "Fountain", fountain, True),
]

# LOD0 tri ceilings per module (SPEC.md); build() warns over them
TRIS = {"H01_Canteen": 6000, "H02_Campfire": 3500, "H04_ParkBench": 1200, "H05_BenchPatio": 2500, "H06_Hammock": 1200,
        "H07_IceCart": 2200, "H08_ChatEast": 900, "H09_ChatWest": 1500, "D01_FlowerBed": 4500, "D02_PicnicTable": 1500,
        "D03_LampRow": 1800, "D04_FlagPole": 1000, "D04_FlagCloth": 200, "D04_FlagEmblem": 400, "D05_Statue": 2000, "D06_Fountain": 2200}
GLOW_TRIS = 300


def _spots():
    """Every worker idle point as (ATT name, slot, (x, y, z)): the rest (sit / lie) when the spot has one, else the
    stand point on the ground. Names carry no SPOTS index (SPEC.md maps them); code matches by name or nearest."""
    out = [("ATT_Canteen_" + n, "Canteen", (x, F + STOOL, z)) for n, (x, z, _) in CANTEEN_EAT.items()]
    out += [("ATT_Campfire_" + n, "Campfire", (x, LOG, z)) for n, (x, z, _) in CAMP_SIT.items()]
    out += [("ATT_Campfire_" + n, "Campfire", (x, 0.0, z)) for n, (x, z, _) in CAMP_WARM.items()]
    out += [("ATT_Bench_" + n, "Bench", (x, BENCH, z)) for n, (x, z, _) in BENCH_SIT.items()]
    out += [("ATT_Hammock_Lie", "Hammock", (0.0, HAMMOCK, 0.0))]
    out += [("ATT_Cart_" + n, "Cart", (x, 0.0, z)) for n, (x, z, _) in CART_CONE.items()]
    out += [("ATT_ChatEast_" + n, "ChatEast", (x, 0.0, z)) for n, (x, z, _) in CHAT_E.items()]
    out += [("ATT_ChatWest_" + n, "ChatWest", (x, 0.0, z)) for n, (x, z, _) in CHAT_W.items()]
    # light / code anchors
    out += [("ATT_Campfire_Flame", "Campfire", (0.0, 2.3, 0.0)),
            ("ATT_Campfire_Lamp", "Campfire", (CAMP_LAMP[0], CAMP_LAMP[2], CAMP_LAMP[1])),
            ("ATT_BenchPatio_Lamp", "Bench", (BENCH_LAMP[0], BENCH_LAMP[2], BENCH_LAMP[1])),
            ("ATT_ChatWest_Lamp", "ChatWest", (CHATW_LAMP[0], CHATW_LAMP[2], CHATW_LAMP[1])),
            ("ATT_FlagPole_Cloth", "FlagPole", FLAG),
            ("ATT_FlagPole_Top", "FlagPole", (0.0, 20.8, 0.0)),
            ("ATT_Fountain_Jet", "Fountain", (0.0, 5.15, 0.0))]
    out += [("ATT_LampRow_Lamp_%02d" % (i + 1), "LampRow", (x, LAMP_HC, 0.0)) for i, x in enumerate(LAMP_ROW)]
    return out


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_CommonsKit_Brick", ALB)
    meshes, lods = [], {}
    for name, slot, fn, lit in MODULES:
        tris = []
        for lod in (0, 1, 2):
            b = lego.B()
            fn(K(b, SLOTS[slot], lod=lod, lit=lit))
            tris.append(b.tris())
            if lod:
                lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat)
            else:
                obj = b.to_object(name, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        cap = GLOW_TRIS if lit else TRIS[name]
        print("[commons] %-20s %5d / %5d / %5d tris%s" % (name, *tris, "  OVER %d" % cap if tris[0] > cap else ""))
    patch_lod(lods)
    c = lego.B()
    K(c, SLOTS["Canteen"]).box((-3, Y0, -1), (3, 1.0, 1), P.DBG, bev=0)
    meshes.append({"object": c.to_object("Col01_COL", mat), "role": "col"})

    def att(n, x, y=0.0, z=0.0):
        return lego.attach(n, (-x, z, y))
    atts = [att("ATT_" + s, x) for s, x in SLOTS.items()]
    atts += [att(n, SLOTS[s] + p[0], p[1], p[2]) for n, s, p in _spots()]

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[commons] LOD0 %d tris; dims_m %s" % (total, dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "a kit strip: every module is placed on its own by its code (ATT_<Slot> origins)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names H01_Canteen... / D01_FlowerBed...: the wiring code places each module by name",
            "LOD UV layout": "flat palette cells (one shared material): hand-made LODs drop studs and details, UVs "
                             "are not a unique unwrap by design (tiling=True skips the density check)",
            "texture sets": "one flat Lego palette set like every Lego kit; hero_building only for its triangle "
                            "ceilings (15 modules)",
        },
        "meshes": meshes,
        "attachments": atts,
    }


if __name__ == "__main__":      # system python3 self-check: every spot ATT sits where Hangout.SPOTS puts it
    spots = {n: p for n, _, p in _spots()}
    assert spots["ATT_Canteen_EatFL"] == (-1.6, 2.0, -2.9) and spots["ATT_Bench_SitR"] == (1.2, 1.5, 0.0)
    assert spots["ATT_Campfire_SitBR"] == (1.3, 1.3, 4.5) and spots["ATT_Hammock_Lie"] == (0.0, 2.3, 0.0)
    idx = sorted([v[2] for v in CANTEEN_EAT.values()] + [v[2] for d in (CAMP_SIT, CAMP_WARM, CART_CONE, CHAT_E, CHAT_W)
                 for v in d.values()] + [i for v in BENCH_SIT.values() for i in v[2]] + [7])
    assert idx == sorted(set(range(1, 26)) - {8, 18, 23}), idx      # 8 / 18 / 23 are the Bunkhouse bunks
    names = [n for n, _, _ in _spots()] + ["ATT_" + s for s in SLOTS]
    rx = re.compile(r"^ATT_[A-Z][A-Za-z0-9]*(_[A-Z][A-Za-z0-9]*)*(_\d\d)?$")
    assert all(rx.match(n) for n in names) and len(set(names)) == len(names), names
    print("ok: %d ATT names, SPOTS 1..25 covered" % len(names))
