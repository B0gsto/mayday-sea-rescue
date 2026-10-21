"""S2 M_Veg_Kelp_Kit (docs/12 2.5): four Laminaria plants for Old Ned's gully and the Haven Head / Skerries kelp
beds (WorldConfig `KelpBeds`). Every plant is a broad blade gripped to a granite boulder by root-like haptera, on a
short to tall stipe, streaming downstream in the current:

  M_Veg_Kelp_01  young oarweed, short stipe, broad blade already as long as the stipe, heavy wet mop
  M_Veg_Kelp_02  L. digitata: short flexible stipe, the broad palm lying almost flat on the rock
  M_Veg_Kelp_03  tall forest kelp (L. hyperborea): the longest straps, storm-torn, highest out of the bed
  M_Veg_Kelp_04  twin-stiped clump out of one crowned holdfast, dense low mop

The four plants stand on a display line 2 m apart along +X (the kit's own grid, as the sign kit's 4 m line: every
plant's base is its own ground point, so the Roblox offsets from the model pivot are in RESULT.md). Each plant's
base sits at Z 0, is scaled so its measured height matches the target real height, and carries an `ATT_Holdfast`
empty at the crown (the plant's sway pivot and place point).

Each plant's blade is a broad palm (a ruffled lamina off the stipe top) splitting into 11 to 14 long, wide straps,
7 to 10.5 cm across: they leave the crown together, low and downstream, and arc over into the flood so the whole
bundle streams almost horizontally and sags like a heavy wet mop, overlapping and clumping rather than fanning like
a palm crown. The blade is as long as or longer than the stipe and dominates the silhouette. Straps are thin strap
geometry, not alpha cards, with ragged forked tips; the front and back surfaces are offset 6 mm apart with their true
(keel-tilted) normals, so there are no coincident double faces and Roblox needs no DoubleSided. LODs are rebuilt
from the same strap list (rank cut, fewer segments and columns, coarser rock), not decimated. Every vertex carries a
"Sway" colour attribute for underwater sway: R weight 0 at the holdfast to 1 at the blade tips, G phase per plant /
strap, B stiffness (1 rock, 0.55 stipe, 0.12 blade), A 1.

1 Blender unit = 1 stud (3 per metre). Current: the flood runs +X, every plant leans and streams that way, so the
placer yaws it to the local tide.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(GAME, "tools/blender"))
sys.path.insert(0, HERE)
import common  # noqa: E402
import kelp_tex  # noqa: E402

M = 3.0                                                   # studs per metre
CURRENT = Vector((1.0, 0.0, 0.0))                         # the prevailing flood direction
GRID = 2.0                                                # metres between the four plants' bases (display line)
KIT_TRIS = 6000                                           # vegetation class ceiling (docs/12 row: 2,000 to 4,000 each)

# name, seed, rock R m, stipe m / radius m, digits, digit L m, digit W m, target height m, twin, split odds, storm, note
VARIANTS = (
    ("M_Veg_Kelp_01", 101, 0.29, ((0.95, 0.034),), 11, (1.05, 1.35), (0.070, 0.100), 1.22, False, 0.18, 0.0,
     "young oarweed: short stipe, broad blade streaming downstream in a wet mop"),
    ("M_Veg_Kelp_02", 102, 0.37, ((0.45, 0.030),), 13, (1.20, 1.50), (0.080, 0.105), 0.62, False, 0.22, 0.0,
     "L. digitata: short flexible stipe, broad palm lying almost flat on the rock"),
    ("M_Veg_Kelp_03", 103, 0.33, ((1.35, 0.036),), 14, (1.30, 1.50), (0.075, 0.100), 1.78, False, 0.20, 0.55,
     "tall forest kelp (L. hyperborea): long broad straps, storm-torn"),
    ("M_Veg_Kelp_04", 104, 0.46, ((1.05, 0.033), (0.85, 0.028)), 13, (1.00, 1.35), (0.070, 0.095), 1.36, True, 0.18, 0.0,
     "twin-stiped clump from one holdfast, dense low mop"),
)


# ---------------------------------------------------------------------------------------------------- prims
class Prim:
    """verts (metres), faces (index tuples), per-vertex uvs, per-vertex sway (r, g, b), kind: card | solid."""

    def __init__(self, kind="solid", flat=False):
        self.kind = kind
        self.flat = flat                                      # solids: faceted (rock) instead of smooth
        self.v, self.f, self.uv, self.sway, self.n = [], [], [], [], []

    def add(self, p, st, sway):
        self.v.append(Vector(p))
        self.uv.append(st)
        self.sway.append(sway)
        return len(self.v) - 1


def rand_dir_xy(rng):
    a = rng.uniform(0.0, 2.0 * math.pi)
    return Vector((math.cos(a), math.sin(a), 0.0))


def tube(prim, pts, radii, sides, uv_at, sway_at, flat_end=False):
    """A tube along pts: u 0..1 around (periodic: the atlas strip tiles across u), v from uv_at(t) per ring."""
    n = len(pts)
    total = sum((pts[i + 1] - pts[i]).length for i in range(n - 1)) or 1.0
    acc, rows = 0.0, []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
        a = d.cross(ref).normalized()
        b = d.cross(a).normalized()
        if i > 0:
            acc += (pts[i] - pts[i - 1]).length
        t = acc / total
        row = [prim.add(p + (a * math.cos(2 * math.pi * s / sides) + b * math.sin(2 * math.pi * s / sides)) * radii[i],
                        uv_at(s / sides, t), sway_at(t)) for s in range(sides + 1)]
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for s in range(sides):
            prim.f.append((r0[s], r0[s + 1], r1[s + 1], r1[s]))
    return rows


# ---------------------------------------------------------------------------------------------------- rock + holdfast
def rock_part(rng, R, lod):
    """An irregular rounded granite boulder: a squashed sphere with several octaves of radial and vertical noise,
    smooth-shaded, its base sunk into the ground. No facet ring, no cone."""
    prim = Prim("solid")
    rows, cols = ((5, 30), (4, 14), (3, 9))[lod]
    ph1, ph2, ph3 = rng.uniform(0, 6.28), rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    sx, sy = rng.uniform(0.72, 1.12), rng.uniform(0.72, 1.12)
    Rz = R * rng.uniform(0.82, 1.02)
    tilt = rng.uniform(-0.10, 0.10)

    def radial(a, th):
        return (1.0 + 0.17 * math.sin(3 * a + ph1) + 0.10 * math.sin(5 * a + ph2)
                + 0.06 * math.sin(7 * a + th * 2 + ph3) + 0.07 * math.sin(2 * a + th * 5))

    def st(a, t):
        return kelp_tex.uv_wrap("Rock", a / (2 * math.pi), 0.04 + 0.92 * t)

    sway = (0.0, 0.0, 1.0)
    top = prim.add((tilt * R * 0.3, 0, Rz * (1.0 + 0.045 * math.sin(ph1))), st(0.5, 0.02), sway)
    ringidx = []
    thmax = 1.95                                          # well past the equator, so the base tucks under the ground
    for r in range(1, rows + 1):
        th = (r / rows) * thmax
        row = []
        for c in range(cols + 1):
            a = 2 * math.pi * c / cols
            rr = R * math.sin(th) * radial(a, th)
            lump = 1.0 + 0.13 * math.sin(3 * a + ph2) + 0.08 * math.sin(5 * a + th * 3 + ph1)
            lump += 0.05 * math.sin(7 * a + th * 6 + ph3)
            z = max(0.006, Rz * math.cos(th) * lump)
            row.append(prim.add((rr * math.cos(a) * sx + tilt * z, rr * math.sin(a) * sy, z),
                                st(c / cols, 0.04 + 0.92 * th / thmax), sway))
        ringidx.append(row)
    for c in range(cols):
        prim.f.append((top, ringidx[0][c], ringidx[0][c + 1]))
    for r0, r1 in zip(ringidx, ringidx[1:]):
        for c in range(cols):
            prim.f.append((r0[c], r1[c], r1[c + 1], r0[c + 1]))
    return prim, Rz


def crown_part(rng, R, z0, lod):
    """The holdfast's knobbly mass at the rock top, where the stipe grips."""
    prim = Prim("solid")
    rows, cols = ((3, 9), (2, 7), (2, 6))[lod]
    ph = rng.uniform(0, 6.28)
    h = R * rng.uniform(0.34, 0.46)
    r0 = R * rng.uniform(0.34, 0.46)

    def st(a, t):
        return kelp_tex.uv("Holdfast", 0.05 + 0.90 * a / (2 * math.pi), 0.06 + 0.88 * t)

    sway = (0.05, 0.0, 0.9)
    top = prim.add((rng.uniform(-0.02, 0.02) * R, rng.uniform(-0.02, 0.02) * R, z0 + h), st(0.5, 1.0), sway)
    ringidx = []
    for r in range(1, rows + 1):
        th = (r / rows) * (math.pi / 2.0)
        row = []
        for c in range(cols + 1):
            a = 2 * math.pi * c / cols
            rad = r0 * math.sin(th) * (1.0 + 0.22 * math.sin(3 * a + ph) + 0.10 * math.sin(5 * a + 2 * ph))
            row.append(prim.add((rad * math.cos(a), rad * math.sin(a), z0 + max(0.0, math.cos(th) * h)), st(c / cols, 1.0 - th / (math.pi / 2)), sway))
        ringidx.append(row)
    for c in range(cols):
        prim.f.append((top, ringidx[0][c], ringidx[0][c + 1]))
    for r0_, r1 in zip(ringidx, ringidx[1:]):
        for c in range(cols):
            prim.f.append((r0_[c], r1[c], r1[c + 1], r0_[c + 1]))
    return prim


def claw_part(rng, R, Rz, z0, n, lod, phase):
    """Haptera: tapering root claws leaving the crown, hugging the boulder's curve down to flared adhesive pads
    on the stone."""
    prim = Prim("solid")
    sides = (5, 4, 4)[lod]
    pts_n = (5, 4, 3)[lod]
    for k in range(n):
        a = 2 * math.pi * k / n + phase + rng.uniform(-0.22, 0.22)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        spread = rng.uniform(0.94, 1.06)
        pts = []
        for i in range(pts_n):
            s = i / (pts_n - 1)
            th = 0.12 + 1.48 * s                         # from the crown shoulder round to the stone
            rr = R * math.sin(th) * spread * (1.0 + 0.05 * math.sin(4 * a + 2 * s))
            z = max(0.012, Rz * math.cos(th) + R * (0.03 - 0.02 * s))
            pts.append(Vector((d.x * rr, d.y * rr, z)))
        rr0 = R * 0.085
        radii = [rr0 * (1.12 - 0.62 * i / (pts_n - 1)) for i in range(pts_n)]
        radii[-1] = radii[-1] * 1.75                     # flattened pad, splayed on the stone
        tube(prim, pts, radii, sides,
             lambda s, t: kelp_tex.uv_wrap("Holdfast", s, 0.10 + 0.80 * t),
             lambda t: (0.04 + 0.10 * t, 0.0, 0.9))
    return prim


# ---------------------------------------------------------------------------------------------------- stipe + fronds
def stipe_part(rng, start, length, r0, lean, lod):
    """A stiff, slightly flattened stipe: near vertical low down, streaming in the current higher up."""
    prim = Prim("solid")
    sides = (5, 4, 4)[lod]
    rings = (6, 5, 4)[lod]
    flat = Vector((-lean.y, lean.x, 0.0)).normalized() if lean.length > 1e-3 else Vector((0, 1, 0))
    pts, radii = [], []
    p = Vector(start)
    for i in range(rings):
        t = (i + 1) / rings
        d = (Vector((0, 0, 1)) + lean * (0.25 + 0.85 * t ** 1.6) + CURRENT * 0.20 * t ** 1.4
             + Vector((rng.gauss(0, 0.03), rng.gauss(0, 0.03), 0))).normalized()
        p = p + d * (length / rings)
        pts.append(p.copy())
        radii.append(r0 * (1.25 - 0.30 * t + 0.12 * sm_step(t, 0.85, 1.0)))   # a small flare at the crown
    pts.insert(0, Vector(start))
    radii.insert(0, r0 * 1.25)

    def uv_at(s, t):
        return kelp_tex.uv("Stipe", s, 0.04 + 0.92 * t)

    def sway_at(t):
        return (0.12 + 0.52 * t ** 1.3, 0.0, 0.55 - 0.10 * t)

    tube(prim, pts, radii, sides, uv_at, sway_at)
    prim.top = pts[-1]
    prim.dir = (pts[-1] - pts[-2]).normalized()
    return prim


def sm_step(x, a, b):
    t = min(1.0, max(0.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


def digit_part(rng, base, heading, elev, L, W, rect, segs, cols, droop, bend, flat, storm=0.0):
    """One broad strap of the blade: leaves the crown low and downstream, then arcs over into the flood so its
    whole length streams almost horizontally, sagging as it goes. The strap stays wide through its middle and tapers
    only near the ragged, often forked tip. Real surface normals per vertex (keel tilt included): make_mesh offsets
    the front and back surfaces 6 mm apart, so there are two real faces, no coincident double face, and Roblox needs
    no DoubleSide."""
    prim = Prim("card")
    p = Vector(base)
    step = L / segs
    pts = [p.copy()]
    ph = rng.uniform(0, 2 * math.pi)
    ph2 = rng.uniform(0, 2 * math.pi)
    wav = rng.uniform(0.05, 0.13)                          # heading meander: the strap does not run dead straight
    for i in range(segs):
        t = (i + 0.5) / segs
        ang = heading + bend * t + wav * math.sin(2 * math.pi * (0.8 * t + ph2))
        e = elev - droop * (t ** 1.30) + 0.045 * math.sin(2 * math.pi * (1.1 * t + ph))
        e = max(-1.15, min(0.65, e))
        d = Vector((math.cos(ang) * math.cos(e), math.sin(ang) * math.cos(e), math.sin(e)))
        p = p + d * step
        pts.append(p.copy())

    lat = Vector((-math.sin(heading), math.cos(heading), 0.0))
    sway_phase = rng.random()
    amp = rng.uniform(0.020, 0.048) * min(1.25, L / 0.9)
    freq = rng.uniform(0.9, 1.8)
    drift = rng.uniform(-0.08, 0.08) * L                    # a slow lateral S, so strands do not share a plane
    drif = rng.uniform(0.2, 1.0) * rng.choice((-1.0, 1.0))
    for i in range(1, segs + 1):
        t = i / segs
        pts[i] += lat * (amp * math.sin(2 * math.pi * freq * t + ph) * sm_step(t, 0.08, 0.45))
        pts[i] += lat * (drift * drif * math.sin(2 * math.pi * (0.6 * t + 0.35 * drif)) * sm_step(t, 0.12, 0.6))

    fl = 0.62 - 0.32 * flat
    twist0 = rng.uniform(-0.55, 0.55) * fl
    twist = rng.uniform(-1.05, 1.05) * fl
    twv = rng.uniform(0.22, 0.55) * fl
    tph = rng.uniform(0, 2 * math.pi)
    rfl = rng.uniform(0.18, 0.40) * W * (1.0 - 0.6 * flat)  # margin crinkle, out of plane
    rff = rng.uniform(1.3, 2.6)
    rph = rng.uniform(0, 2 * math.pi)
    fold = rng.uniform(0.20, 0.38) * (1.0 - 0.55 * flat)
    crib = rng.uniform(0.10, 0.24) * W * (1.0 - 0.5 * flat)  # transverse leathery corrugation along the strap
    crf = rng.uniform(1.6, 3.4)
    cph = rng.uniform(0, 2 * math.pi)
    notch = rng.uniform(0.35, 0.75) * (1.0 + 0.5 * storm)  # how far the forked tip's middle recedes
    torn = rng.uniform(0.06, 0.30) * (1.0 + 1.4 * storm)   # ragged end pull-back
    if storm > 0.5 and rng.random() < 0.4:                 # a storm-cut strap: torn off mid-length
        torn = min(0.9, torn + rng.uniform(0.2, 0.45))
    for i in range(segs + 1):
        t = i / segs
        tang = (pts[min(i + 1, segs)] - pts[max(i - 1, 0)]).normalized()
        side = lat - tang * lat.dot(tang)
        if side.length < 1e-5:
            side = Vector((0.0, 1.0, 0.0)) - tang * tang.y
        side.normalize()
        phi = twist0 + twist * t + twv * math.sin(2 * math.pi * (1.2 * t + tph))
        side = (side * math.cos(phi) + tang.cross(side) * math.sin(phi)).normalized()
        n = tang.cross(side).normalized()
        hw = W * 0.5 * (0.86 + 0.14 * sm_step(t, 0.0, 0.10))
        hw *= 1.0 + 0.06 * math.sin(2 * math.pi * (2.3 * t + ph * 1.7))
        hw *= 1.0 - 0.26 * sm_step(t, 0.68, 1.0)
        rag = 0.86 + 0.14 * math.sin(2 * math.pi * (3.9 * t + ph * 0.6)) if t > 0.74 else 1.0
        hw = hw * rag + W * 0.035
        tip_back = torn * W * sm_step(t, 0.86, 1.0)
        w_fr = 0.40 + 0.60 * t
        for j in range(cols + 1):
            fx = j / cols * 2.0 - 1.0
            keel = fold * hw * (1.0 - 1.35 * fx * fx)
            back = tip_back * (notch if (cols > 1 and j == 1) else 0.35)
            v = pts[i] + side * (hw * fx) - tang * back + n * keel
            v += n * (rfl * fx * fx * math.sin(2 * math.pi * (rff * t + rph)))
            v += n * (crib * math.sin(2 * math.pi * (crf * t + cph)))
            nv = (n + side * (3.0 * fold * fx)).normalized()
            prim.n.append(nv)
            prim.add(v, kelp_tex.uv(rect, 0.5 + 0.5 * fx, t), (min(1.0, 0.40 + 0.60 * w_fr), sway_phase, 0.12))
    for i in range(segs):
        for j in range(cols):
            a0 = i * (cols + 1) + j
            prim.f.append((a0, a0 + 1, a0 + cols + 2, a0 + cols + 1))
    return prim


def blade_base_part(rng, top, heading, L, W, rect, flat, segs=4, cols=4):
    """The palm of the blade: a broad, slightly ruffled lamina widening out of the stipe top, from which the long
    straps split. It gives the bundle one solid root instead of a tuft of separate ribbons."""
    prim = Prim("card")
    p = Vector(top)
    step = L / segs
    pts = [p.copy()]
    ph = rng.uniform(0, 2 * math.pi)
    for i in range(segs):
        t = (i + 0.5) / segs
        e = 0.05 - 0.10 * t + 0.025 * math.sin(2 * math.pi * (1.1 * t + ph))
        ang = heading + 0.06 * math.sin(2 * math.pi * (0.9 * t + ph))
        d = Vector((math.cos(ang) * math.cos(e), math.sin(ang) * math.cos(e), math.sin(e)))
        p = p + d * step
        pts.append(p.copy())
    lat = Vector((-math.sin(heading), math.cos(heading), 0.0))
    ph2 = rng.uniform(0, 2 * math.pi)
    for i in range(segs + 1):
        t = i / segs
        tang = (pts[min(i + 1, segs)] - pts[max(i - 1, 0)]).normalized()
        side = lat - tang * lat.dot(tang)
        side.normalize()
        n = tang.cross(side).normalized()
        hw = W * 0.5 * (0.16 + 0.84 * sm_step(t, 0.0, 0.38))
        hw *= 0.94 + 0.06 * math.sin(2 * math.pi * (1.6 * t + ph2))
        for j in range(cols + 1):
            fx = j / cols * 2.0 - 1.0
            keel = 0.10 * hw * (1.0 - 1.35 * fx * fx)
            v = pts[i] + side * (hw * fx) + n * keel
            v += n * (0.05 * W * fx * fx * math.sin(2 * math.pi * (1.9 * t + ph2)))
            prim.n.append((n + side * (2.2 * 0.10 * fx)).normalized())
            prim.add(v, kelp_tex.uv(rect, 0.5 + 0.5 * fx, 0.04 + 0.42 * t), (0.30 + 0.30 * t, 0.5, 0.14))
    for i in range(segs):
        for j in range(cols):
            a0 = i * (cols + 1) + j
            prim.f.append((a0, a0 + 1, a0 + cols + 2, a0 + cols + 1))
    return prim


def crown_digits(rng, top, dirv, n, L0, L1, W0, W1, split_odds, segs, cols, upright, storm=0.0, flat=0.0):
    """The blade of one stipe: `n` broad straps leaving the stipe top close together and all streaming downstream
    in the flood, layered and overlapping into one heavy wet mop. Each strap is long (at least the stipe's height),
    low-angled and sagging, with its width across the current. Some split into a shorter second strap. Returns a
    list of Prim."""
    out = []
    for k in range(n):
        heading = rng.gauss(0.0, 0.13)
        if k % 7 == 6:                                    # one side strap, still in the bundle
            heading = rng.choice((-1.0, 1.0)) * rng.uniform(0.45, 0.72)
        heading = max(-0.80, min(0.80, heading))
        elev = rng.uniform(0.05, 0.22) - 0.06 * abs(heading)
        if flat:
            elev = rng.uniform(0.0, 0.06)
        L = rng.uniform(L0, L1) * (1.0 - 0.10 * abs(heading)) * rng.uniform(0.94, 1.06)
        L *= 1.0 - 0.10 * storm
        W = rng.uniform(W0, W1)
        rect = "BladeB" if rng.random() < 0.30 else "BladeA"
        base = (Vector(top) + CURRENT * rng.uniform(0.04, 0.16)
                + Vector((rng.gauss(0, 0.020), rng.gauss(0, 0.080),
                          rng.gauss(0, 0.014) + 0.024 * ((k % 3) - 1))))
        droop = rng.uniform(0.55, 0.95) * (0.36 if flat else 1.0) * (0.85 + 0.30 * L / max(0.6, L1))
        bend = rng.uniform(-0.12, 0.12)
        prim = digit_part(rng, base, heading, elev, L, W, rect, segs, cols, droop, bend, flat, storm)
        out.append(prim)
        if cols > 1 and rng.random() < split_odds:
            i0 = int(segs * rng.uniform(0.48, 0.64))
            j0 = cols // 2
            vi = i0 * (cols + 1) + j0
            sl = L * rng.uniform(0.30, 0.48)
            sw = W * rng.uniform(0.62, 0.85)
            sh = heading + rng.uniform(-0.12, 0.12)
            se = max(0.01, elev * rng.uniform(0.2, 0.6))
            out.append(digit_part(rng, prim.v[vi] + prim.n[vi] * 0.004, sh, se, sl, sw, rect, max(3, segs - 3),
                                  max(1, cols - 1), droop * rng.uniform(0.8, 1.05), bend + rng.uniform(-0.12, 0.12),
                                  flat, storm))
    return out


# ---------------------------------------------------------------------------------------------------- a plant
def plant(variant, lod):
    name, seed, R, stipes, ndigits, (L0, L1), (W0, W1), height, twin, split_odds, storm, note = variant
    rng = random.Random(seed * 100 + lod)
    prims = []
    rock, Rz = rock_part(rng, R, lod)
    prims.append(rock)
    z0 = Rz * 0.72
    prims.append(crown_part(rng, R, z0, lod))
    prims.append(claw_part(rng, R, Rz, z0, (6, 5, 4)[lod], lod, rng.uniform(0, 6.28)))

    flat = 1.0 if name.endswith("_02") else 0.0
    tops = []
    for si, (slen, sr) in enumerate(stipes):
        if flat:
            lean_dir = Vector((2.40, rng.uniform(-0.25, 0.25), 0.0))
        else:
            lean_dir = rand_dir_xy(rng) * 0.20 + Vector((1, 0, 0)) * 0.42
        start = Vector((0, 0, z0 + R * 0.22)) if si == 0 else Vector((R * 0.5 * (1 if si % 2 else -1), R * 0.35, z0 + R * 0.12))
        sp = stipe_part(rng, start, slen, sr, lean_dir, lod)
        prims.append(sp)
        tops.append(sp)

    segs_lod = (7, 5, 3)[lod]
    cols_lod = (2, 1, 1)[lod]
    per_stipe = [ndigits // len(stipes) + (1 if i < ndigits % len(stipes) else 0) for i in range(len(stipes))]
    for si, sp in enumerate(tops):
        L0s = L0 * (0.82 if (si and not flat) else 1.0)
        L1s = L1 * (0.85 if (si and not flat) else 1.0)
        prims.append(blade_base_part(rng, sp.top, 0.0, 0.38, W1 * 4.4,
                                     "BladeB" if storm else "BladeA", flat,
                                     segs=4 if lod == 0 else 3, cols=4 if lod == 0 else 2))
        prims.extend(crown_digits(rng, sp.top, sp.dir, per_stipe[si], L0s, L1s, W0, W1, split_odds,
                                  segs_lod, cols_lod, 0.0, storm, flat))
    return prims, z0, R


# ---------------------------------------------------------------------------------------------------- mesh + material
def make_mesh(name, prims, centre, up_blend):
    """Cards are emitted as two real surfaces (front +n, back -n, 6 mm apart, reversed winding), so every face has
    its true normal: no coincident double faces and no DoubleSided needed. Solids (rock, holdfast, stipe, claws) are
    single surfaces: flat-faceted for the rock, smooth for the tubes. `centre`/`up_blend` are kept for the pipeline's
    signature; the fronds carry real normals."""
    THICK = 0.003                                         # per side, in metres: 6 mm blade
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    loop_normals, sway_seq = [], []
    for prim in prims:
        if prim.kind == "card":
            for back in (False, True):
                bv = [bm.verts.new(v + prim.n[i] * (THICK if not back else -THICK)) for i, v in enumerate(prim.v)]
                for f in prim.f:
                    f2 = tuple(reversed(f)) if back else f
                    face = bm.faces.new([bv[i] for i in f2])
                    for lp, vi in zip(face.loops, f2):
                        lp[uvl].uv = prim.uv[vi]
                        loop_normals.append(tuple(-prim.n[vi] if back else prim.n[vi]))
                sway_seq.extend(prim.sway)
        else:
            bv = [bm.verts.new(v) for v in prim.v]
            for f in prim.f:
                face = bm.faces.new([bv[i] for i in f])
                fn = face.normal.copy()
                for lp, vi in zip(face.loops, f):
                    lp[uvl].uv = prim.uv[vi]
                    loop_normals.append(tuple(fn) if prim.flat else None)
            sway_seq.extend(prim.sway)
    bm.normal_update()
    smooth_normals = [tuple(v.normal) for v in bm.verts]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    final = []
    for i, lp in enumerate(me.loops):
        n = loop_normals[i]
        final.append(tuple(n) if n is not None else smooth_normals[lp.vertex_index])
    me.normals_split_custom_set(final)
    sway = me.color_attributes.new(name="Sway", type='FLOAT_COLOR', domain='POINT')
    for i, c in enumerate(sway_seq):
        sway.data[i].color = (c[0], c[1], c[2], 1.0)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material():
    mat = bpy.data.materials.get("MAT_FoliageMarine") or bpy.data.materials.new("MAT_FoliageMarine")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    alb = common.map_file(common.textures_dir("M_Veg_Kelp_Kit"), "T_FoliageMarine_Main_ALB")
    if bsdf and alb and not any(n.type == "TEX_IMAGE" for n in nt.nodes):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(alb, check_existing=True)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        if hasattr(mat, "blend_method"):
            mat.blend_method = 'CLIP'
    return mat


def empty(name, loc_studs):
    e = bpy.data.objects.new(name, None)
    e.location = Vector(loc_studs)
    bpy.context.scene.collection.objects.link(e)
    return e


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


# ---------------------------------------------------------------------------------------------------- build
def build():
    kelp_tex.write_all()                                  # the atlas maps, before validate looks for them
    mat = material()
    meshes, cols, atts = [], [], []
    for k, variant in enumerate(VARIANTS):
        name, seed, R, stipes, ndigits, dL, dW, height, twin, split_odds, storm, note = variant
        obs = []
        for lod in range(3):
            prims, z0, Rz = plant(variant, lod)
            ob = make_mesh("%s_LOD%d" % (name, lod), prims, Vector((0, 0, 0)), 0.62)
            obs.append(ob)
        xs = [v.co for v in obs[0].data.vertices]
        hi = max(v.z for v in xs)
        sc = (height * M) / hi if hi > 1e-6 else 1.0
        off = Vector((k * GRID * M, 0.0, 0.0))
        for lod, ob in enumerate(obs):
            ob.data.transform(Matrix.Diagonal((sc, sc, sc, 1)))
            ob.data.transform(Matrix.Translation(off))
            ob.data.materials.clear()
            ob.data.materials.append(mat)
            ob.data.update()
            meshes.append({"object": ob, "set": "Main", "lod": "LOD%d" % lod})
        atts.append(empty("ATT_Holdfast_%02d" % (k + 1), (k * GRID * M, 0.0, z0 * sc)))
        print("[M_Veg_Kelp_Kit] %s: %d / %d / %d tris, height %.2f m, rock %s" %
              (name, tris(obs[0]), tris(obs[1]), tris(obs[2]), height, R))
    total = sum(tris(m["object"]) for m in meshes if m["lod"] == "LOD0")
    print("[M_Veg_Kelp_Kit] LOD0 total %d tris (ceiling %d)" % (total, KIT_TRIS))

    sets = [{"name": "FoliageMarine", "set": "Main", "size": kelp_tex.SHIP, "wet": False}]
    return {
        "name": "M_Veg_Kelp_Kit",
        "budget": "vegetation",
        "tris": KIT_TRIS,
        "tier": "standard",
        "dims_m": (None, None, max(v[7] for v in VARIANTS)),
        "size_note": ("four plants on a 2 m display line (docs/12 row: 2,000 to 4,000 tris per plant, instanced); "
                      "the vegetation class ceiling of 6,000 caps the kit, so each plant gets about 1,450. Z is the "
                      "tallest plant (M_Veg_Kelp_03, 2.90 m); X and Y are the display line's, free"),
        "origin": "free",
        "sets": sets,
        "atlas": "FoliageMarine",
        "meshes": meshes,
        "attachments": atts,
        "waivers": {
            "LOD UV layout": "lobe LODs drop fronds and columns by design (docs/12 2.5: distant plants reduce); "
                             "every LOD samples the same M_Veg_Kelp cell of the FoliageMarine atlas, so a LOD's UV "
                             "area differs from LOD0's",
        },
        "note": ("wet-only set (kelp never dries): the maps are the wet look. Fronds are thin lobed geometry (no "
                 "alpha mode, no sorting cost). Sway: vertex colours on every mesh, R weight / G phase / B stiffness"),
        "closeups": [
            {"name": "kelp01_young", "target": [0.9 * M, 0.0, 0.80 * M], "dist": 3.0 * M, "az": 34, "el": 18},
            {"name": "kelp02_oarweed", "target": [GRID * M + 0.9 * M, 0.0, 0.40 * M], "dist": 3.2 * M, "az": 28, "el": 16},
            {"name": "kelp03_tall", "target": [2 * GRID * M + 0.8 * M, 0.0, 1.45 * M], "dist": 4.2 * M, "az": 30, "el": 20},
            {"name": "kelp04_clump", "target": [3 * GRID * M + 0.7 * M, 0.0, 0.95 * M], "dist": 3.6 * M, "az": 26, "el": 14},
            {"name": "holdfast_rock", "target": [GRID * M, 0.0, 0.18 * M], "dist": 2.4 * M, "az": 42, "el": 8},
            {"name": "frond_tip", "target": [1.1 * GRID * M, 0.4 * M, 0.85 * M], "dist": 2.4 * M, "az": 12, "el": 22},
        ],
    }
