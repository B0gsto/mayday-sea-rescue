"""HP1 harbour kit geometry (Blender): quay kit pieces, pontoon sections, the quay ladder. Authored in metres with the
H1 geometry kit (art/source/buildings/M_Bld_Station/geo.py), written in studs (1 m = 3 studs).

Conventions (every piece):
  * Pivot (origin "free") = the snap origin on the quay top / deck top. Front = -Y = the sea side. Z up.
  * Quay top z = 0 = map Y 4 studs (the greybox quay); sea level z = -1.333 m (map Y 0); wall foot z = -4 m.
  * The quay grid is 3 m (9 studs): straight pieces are 3 m, the steps 6 m, the pier head is 6 m across, footprints 3 m
    deep behind the face. Pontoon deck top z = 0 at 0.5 m freeboard (water at z = -0.5).
  * ATT_Snap_* sit on the joint plane at quay-top / deck-top level, facing out of the piece (Attachment look = the
    direction the neighbour continues); a neighbour snaps with its own ATT_Snap_* facing the opposite way.
    ATT_Moor_* are mooring points (cleat horns, coping edge), ATT_Ladder* the ladder recess / ladder top and bottom.
LODs are hand-made per feature via geo.LEVEL tuples: (0,) LOD0 only, (1,) LOD1 only, (1, 2) LOD1 + LOD2, 3 = all.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

HERE = os.path.dirname(os.path.abspath(__file__))
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
sys.path.insert(0, G + "art/source/buildings/M_Bld_Station")
sys.path.insert(0, HERE)
import geo  # noqa: E402
from geo import Part  # noqa: E402


class MT:   # layout constants shared with maketex.py (no PIL inside Blender)
    SEA = -1.333
    PKIT = {"Float": (0.0, 0.125), "Tread": (0.125, 0.15), "GwSteel": (0.15, 0.1875), "Galv": (0.1875, 0.25), "Rubber": (0.25, 0.375),
            "Frame": (0.375, 0.5), "Deck0": (0.5, 0.625), "Deck1": (0.625, 0.75), "Deck2": (0.75, 0.875), "Deck3": (0.875, 1.0)}
    FLOAT_Z = (-0.95, 0.0)
    LADDER_Z = (-4.2, 1.2)


TEX = G + "assets/textures/"
SEA = MT.SEA
FOOT = -4.0
COPE_T, COPE_D, COPE_O = 0.3, 0.6, 0.05     # coping thickness, depth (front to back), overhang over the face
COURSES = [0.5, 0.45, 0.55, 0.5, 0.45, 0.5, 0.55]   # block courses below the coping, top down (sum 3.5 + 0.3 = 3.8)
JOINT = 0.012


def L(*lods):
    geo.LEVEL = lods if lods else 3


# ---------------------------------------------------------------- UV modes
STONE = ("tile", 2.0)
SETTS = ("tile", 2.0)


def pk_fn(strip, scale=2.0, along="x"):
    v0, v1 = MT.PKIT[strip]
    return ("trim", v0 + 0.004, v1 - 0.004, scale)


def float_fn(p):
    v0, v1 = MT.PKIT["Float"]
    z0, z1 = MT.FLOAT_Z
    t = min(0.995, max(0.005, (p.z - z0) / (z1 - z0) + 0.02 * p.x + 0.01 * math.sin(p.y * 2.1)))
    return ((p.x + p.y + 0.1 * p.z) / 4.0, v0 + 0.003 + t * (v1 - v0 - 0.006))


def ladder_fn(p):
    z0, z1 = MT.LADDER_Z
    return ((p.x + p.y * 0.7 + 0.05 * p.z) / 1.0, min(0.999, max(0.001, (p.z + 0.5 * p.y + 0.1 * p.x - z0) / (z1 - z0))))


# ---------------------------------------------------------------- transforms
def place(src, dst, yaw_deg=0.0, offset=(0, 0, 0)):
    """Copies src's faces into dst rotated about Z and moved (UVs as authored in the local frame)."""
    m = Matrix.Rotation(math.radians(yaw_deg), 3, "Z")
    o = Vector(offset)
    base = dst.prim + 1
    for pts, uvs, lv, pid in src.faces:
        dst.faces.append(([m @ p + o for p in pts], uvs, lv, pid + base))
    dst.prim = base + src.prim + 1


def att(name, pos_m, look=(0, -1, 0)):
    e = bpy.data.objects.new(name, None)
    e.location = Vector(pos_m) * 3.0
    e.rotation_euler = (0.0, 0.0, math.atan2(look[0], -look[1]))   # empty -Y = Roblox look
    bpy.context.scene.collection.objects.link(e)
    return e


# ---------------------------------------------------------------- masonry (HP1b: random-rubble Cornish granite)
TIDE_U = 0.75                 # T_QuayKit_Tide: u 0..0.75 = granite block faces (3 m of scan, zoned by v = z) ...
MORTAR_U = (0.79, 0.99)       # ... u 0.79..0.99 = the lime mortar strip (same zonation)
BATTER = 0.09                 # continuous batter: the face steps out 9 cm per metre down (0.33 m at the foot)
JH = 0.015                    # half joint (3 cm joints)
JD = 0.06                     # mortar face set back behind the block arrises (deep raked joints)


def batter(z):
    return BATTER * max(0.0, -COPE_T - z)


def tide_v(z, y=0.0):
    return min(0.999, max(0.001, (z + 4.0 + 0.12 * y) / 4.0))


def tmode(rnd, x_ref=0.0, y_ref=0.0, span=1.0):
    """Tide UVs for a dressed block / plain face: u = u0 + ((x - x_ref) + 0.6 (y - y_ref)) / 4 from a random u0 kept
    inside the granite region, v = z (the shore zonation)."""
    u0 = rnd.uniform(0.005, max(0.006, TIDE_U - 0.01 - span / 4.0)) if rnd else 0.01
    return ("fn", lambda p: (min(TIDE_U - 0.002, max(0.002, u0 + ((p.x - x_ref) + 0.6 * (p.y - y_ref)) / 4.0)),
                             tide_v(p.z, p.y)))


def uvface(part, pts, uvs, centre=None, outward=None):
    """part.face with explicit per-vertex UVs."""
    vs = [Vector(p) for p in pts]
    lut = {(round(v.x, 4), round(v.y, 4), round(v.z, 4)): uv for v, uv in zip(vs, uvs)}
    part.face(vs, ("fn", lambda q: lut[(round(q.x, 4), round(q.y, 4), round(q.z, 4))]), centre=centre, outward=outward)


def skyline(s0, s1, z0, z1, rnd, wr=(0.26, 1.15), hr=(0.15, 0.62)):
    """Random (uncoursed) rubble layout: blocks dropped onto the lowest gap of a skyline, so joints break everywhere
    and sizes run from 15 cm pinning stones to 1.1 m bonders. Returns [(s0, s1, z0, z1)]."""
    sky, out = [[s0, s1, z0]], []
    for _ in range(4000):
        m = [sky[0]]
        for seg in sky[1:]:
            if abs(seg[2] - m[-1][2]) < 1e-6:
                m[-1][1] = seg[1]
            else:
                m.append(seg)
        sky = m
        i = min(range(len(sky)), key=lambda k: sky[k][2])
        sa, sb, h = sky[i]
        if h >= z1 - 1e-6:
            break
        avail = sb - sa
        w = wr[0] + (wr[1] - wr[0]) * rnd.random() ** 1.3
        if w > avail - 0.2:
            w = avail
        hh = hr[0] + (hr[1] - hr[0]) * rnd.random() ** 1.5
        hh = min(hh, max(hr[0], w * 1.1))
        top = h + hh
        for k in (i - 1, i + 1):          # line up with a neighbour within 7 cm (no slivers)
            if 0 <= k < len(sky) and abs(sky[k][2] - top) < 0.07 and sky[k][2] > h + 0.12:
                top = sky[k][2]
        if z1 - top < 0.15:
            top = z1
        out.append((sa, sa + w, h, top))
        new = [[sa, sa + w, top]]
        if w < avail - 1e-6:
            new.append([sa + w, sb, h])
        sky[i:i + 1] = new
    return out


def rubble(part, S, s0, s1, z0, z1, rnd, cell=0.1, bulge=(0.02, 0.06), mortar_col=0.75, lod2_col=3.0):
    """Random-rubble granite on a parametric face S(s, z, d) -> Vector (s along the face, z up, d out of the face).
    LOD0: every block a pitch-faced pillow (real relief, a grid of ~cell m displaced by a dome + noise) with its arris
    sides running back JD to a recessed lime-mortar face; LOD1: flat blocks + mortar; LOD2: one face per lod2_col."""
    def P(s, z, d):
        return S(s, z, d)

    def outv(s, z):
        return S(s, z, 0.1) - S(s, z, 0.0)
    for sa, sb, za, zb in skyline(s0, s1, z0, z1, rnd):
        w, h = sb - sa, zb - za
        j = lambda: rnd.uniform(-0.011, 0.011)  # noqa: E731
        cs = lambda s: min(s1 - 0.006, max(s0 + 0.006, s))  # noqa: E731
        c = [(cs(sa + JH + j()), za + JH + j() * 0.6), (cs(sb - JH + j()), za + JH + j() * 0.6),
             (cs(sb - JH + j()), min(z1 - 0.008, zb - JH + j() * 0.6)), (cs(sa + JH + j()), min(z1 - 0.008, zb - JH + j() * 0.6))]
        nu, nv = max(1, min(8, round(w / cell))), max(1, min(5, round(h / cell)))
        amp = rnd.uniform(*bulge) * min(1.0, 0.4 + h / 0.4)
        ph = Vector((rnd.uniform(0, 50), rnd.uniform(0, 50), rnd.uniform(0, 50)))
        u0 = rnd.uniform(0.005, max(0.006, TIDE_U - 0.01 - (w + 0.1) / 4.0))
        tilt = (rnd.uniform(-0.012, 0.012), rnd.uniform(-0.012, 0.012))

        def grid(i, k):
            a, b = i / nu, k / nv
            s = (c[0][0] * (1 - a) + c[1][0] * a) * (1 - b) + (c[3][0] * (1 - a) + c[2][0] * a) * b
            z = (c[0][1] * (1 - a) + c[1][1] * a) * (1 - b) + (c[3][1] * (1 - a) + c[2][1] * a) * b
            ex = min(a, 1 - a, b, 1 - b)
            pil = (1 - (2 * a - 1) ** 4) * (1 - (2 * b - 1) ** 4)
            n1 = noise.noise(Vector((s * 2.7, z * 2.7, 0.0)) + ph)
            n2 = noise.noise(Vector((s * 8.0, z * 8.0, 3.0)) + ph)
            d = 0.003 + tilt[0] * (2 * a - 1) + tilt[1] * (2 * b - 1) + amp * pil * (0.8 + 0.5 * n1) \
                + 0.012 * n2 * min(1.0, ex * 5)
            return s, z, max(-0.01, d)

        def uv(s, z, d):
            return (min(TIDE_U - 0.002, max(0.002, u0 + (s - sa) / 4.0 - 0.15 * d)), tide_v(z + 0.4 * d))
        L(0)
        part.prim += 1
        gp = {(i, k): grid(i, k) for i in range(nu + 1) for k in range(nv + 1)}
        for i in range(nu):
            for k in range(nv):
                q = [gp[(i, k)], gp[(i + 1, k)], gp[(i + 1, k + 1)], gp[(i, k + 1)]]
                sc, zc = sum(t[0] for t in q) / 4, sum(t[1] for t in q) / 4
                uvface(part, [P(*t) for t in q], [uv(*t) for t in q], outward=outv(sc, zc))
        ring = ([(i, 0) for i in range(nu)] + [(nu, k) for k in range(nv)] + [(i, nv) for i in range(nu, 0, -1)]
                + [(0, k) for k in range(nv, 0, -1)])
        smid, zmid = (c[0][0] + c[2][0]) / 2, (c[0][1] + c[2][1]) / 2
        cen = P(smid, zmid, -JD * 0.5)
        for e0, e1 in zip(ring, ring[1:] + ring[:1]):
            (sa_, za_, da), (sb_, zb_, db) = gp[e0], gp[e1]
            q = [(sa_, za_, da), (sb_, zb_, db), (sb_, zb_, -JD), (sa_, za_, -JD)]
            uvface(part, [P(*t) for t in q], [uv(*t) for t in q], centre=cen)
        L(1)                                   # LOD1: flat block (front + 4 arris sides)
        part.prim += 1
        q = [(c[0][0], c[0][1], 0.02), (c[1][0], c[1][1], 0.02), (c[2][0], c[2][1], 0.02), (c[3][0], c[3][1], 0.02)]
        uvface(part, [P(*t) for t in q], [uv(*t) for t in q], outward=outv(smid, zmid))
        for t0, t1 in zip(q, q[1:] + q[:1]):
            qq = [t0, t1, (t1[0], t1[1], -JD), (t0[0], t0[1], -JD)]
            uvface(part, [P(*t) for t in qq], [uv(*t) for t in qq], centre=cen)
    # mortar face behind the blocks (LOD0 + LOD1), columns of <= mortar_col so the strip keeps its texel density
    L(0, 1)
    n = max(1, math.ceil((s1 - s0) / mortar_col - 1e-6))
    du = MORTAR_U[1] - MORTAR_U[0]
    for i in range(n):
        a, b = s0 + (s1 - s0) * i / n, s0 + (s1 - s0) * (i + 1) / n
        k = (b - a) / mortar_col
        zs = [z0, (z0 + z1) / 2, z1]
        for za_, zb_ in zip(zs, zs[1:]):
            q = [(a, za_), (b, za_), (b, zb_), (a, zb_)]
            uvface(part, [P(s, z, -JD) for s, z in q],
                   [(MORTAR_U[0] + 0.002 + (s - a) / (b - a) * (du - 0.004) * k, tide_v(z)) for s, z in q],
                   outward=outv((a + b) / 2, (za_ + zb_) / 2))
    # LOD2: one face per column, the block texture
    L(2)
    n = max(1, math.ceil((s1 - s0) / lod2_col - 1e-6))
    for i in range(n):
        a, b = s0 + (s1 - s0) * i / n, s0 + (s1 - s0) * (i + 1) / n
        q = [(a, z0), (b, z0), (b, z1), (a, z1)]
        uvface(part, [P(s, z, 0.0) for s, z in q], [(0.002 + (s - a) / 4.0, tide_v(z)) for s, z in q],
               outward=outv((a + b) / 2, (z0 + z1) / 2))
    L()


def wall_run(wall, stone, length, rnd, x_from=-1.5, top_mode=None, coping=True, skip_x=None, cell=0.1):
    """A straight battered random-rubble wall from x_from to x_from + length, face at y ~ 0 at the coping (going out
    with the batter below), coping on top. The end joints sit on the piece edges (snapping neighbours share them)."""
    x0, x1 = x_from, x_from + length
    rubble(wall, lambda s, z, d: Vector((s, -batter(z) - d, z)), x0, x1, FOOT, -COPE_T, rnd, cell=cell)
    if coping:
        cope(stone, x0, x1, rnd)
    L()


def cope(stone, x0, x1, rnd, depth=COPE_D):
    """Granite copings: 0.6 m deep, 0.3 m thick, 1.0 to 1.5 m long, rounded (3-step) front arris, overhanging 5 cm."""
    L(1, 2)
    stone.box((x0, -COPE_O, -COPE_T), (x1, depth - COPE_O, 0.0), STONE, skip=("+y", "-x", "+x", "-z"))
    L(0)
    xs = [x0]
    while xs[-1] < x1 - 0.6:
        nx = xs[-1] + rnd.uniform(1.0, 1.5)
        xs.append(nx if x1 - nx > 0.6 else x1)
    xs[-1] = x1
    yf = -COPE_O
    for a, b in zip(xs, xs[1:]):
        a2 = a + (0.008 if a > x0 + 1e-6 else 0.0)
        b2 = b - (0.008 if b < x1 - 1e-6 else 0.0)
        dz = rnd.uniform(-0.012, 0.0)
        prof = [(depth - COPE_O, -COPE_T), (yf + 0.02, -COPE_T), (yf, -COPE_T + 0.04), (yf, -0.07 + dz),
                (yf + 0.012, -0.03 + dz), (yf + 0.035, -0.008 + dz), (yf + 0.07, dz), (depth - COPE_O, dz)]
        stone.prism(prof, "x", a2, b2, STONE)
    L()


def setts(top, x0, x1, y0, y1):
    """Quay surface behind the coping: granite setts (B02 Cobbles), with a slab edge."""
    L()
    top.face([(x0, y0, -0.005), (x1, y0, -0.005), (x1, y1, -0.005), (x0, y1, -0.005)], SETTS, outward=(0, 0, 1))


# ---------------------------------------------------------------- rock armour
def hull_rock(part, c, size, rnd, mode, n=26, lods=(0,)):
    bm = bmesh.new()
    sx, sy, sz = size
    for _ in range(n):
        th = rnd.uniform(0, 2 * math.pi)
        ph = math.acos(rnd.uniform(-1, 1))
        r = rnd.uniform(0.82, 1.0)
        v = Vector((math.sin(ph) * math.cos(th) * sx, math.sin(ph) * math.sin(th) * sy, math.cos(ph) * sz)) * r
        v.x, v.y, v.z = (max(min(v.x, sx * 0.86), -sx * 0.86), max(min(v.y, sy * 0.86), -sy * 0.86),
                         max(min(v.z, sz * 0.8), -sz * 0.8))     # quarried: flattened faces
        bm.verts.new(v)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.dissolve_degenerate(bm, dist=0.06 * min(sx, sy, sz) / 0.3, edges=bm.edges)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.0), verts=bm.verts, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    yaw = rnd.uniform(0, 2 * math.pi)
    m = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(rnd.uniform(-0.3, 0.3), 3, "X")
    geo.LEVEL = lods
    part.prim += 1
    cv = Vector(c)
    for f in bm.faces:
        pts = [m @ v.co + cv for v in f.verts]
        part.face(pts, mode, centre=cv)
    bm.free()
    L()


# ---------------------------------------------------------------- quay pieces
def quay_parts():
    return Part("Wall"), Part("Stone"), Part("Top")


def quay_straight(rnd, ladder_bay=False):
    wall, stone, top = quay_parts()
    if not ladder_bay:
        wall_run(wall, stone, 3.0, rnd)
    else:
        # two 1.15 m wall runs either side of a 0.7 m recess 0.22 m deep, recess lined with dressed blocks
        wall_run(wall, stone, 1.15, rnd, x_from=-1.5)
        wall_run(wall, stone, 1.15, rnd, x_from=0.35)
        rw, rd = 0.35, 0.22
        # recess back: small rubble (no batter), recess sides: plain dressed reveals from the battered face to the back
        rubble(wall, lambda s, z, d: Vector((s, rd - d, z)), -rw, rw, FOOT, -COPE_T, rnd, cell=0.12, bulge=(0.01, 0.03))
        L()
        for sx in (-1, 1):
            wall.face([(sx * rw, -batter(FOOT) - 0.03, FOOT), (sx * rw, rd, FOOT), (sx * rw, rd, -COPE_T),
                       (sx * rw, -0.03, -COPE_T)], tmode(rnd, sx * rw, -0.4, 0.4), outward=(-sx, 0, 0))
        # coping over the recess, cut back to the recess line
        L()
        stone.box((-rw, rd, -COPE_T), (rw, COPE_D - COPE_O, 0.0), STONE, skip=("+y", "-x", "+x", "-z"))
        stone.box((-rw - 0.01, rd - 0.02, -COPE_T), (rw + 0.01, rd, -0.02), STONE, skip=("+y", "-z", "+z"))
    setts(top, -1.5, 1.5, COPE_D - COPE_O, 3.0)
    return wall, stone, top


def quay_corner(rnd):
    """Outer 90-degree corner: face A along -Y (x -1.5..1.5), face B along +X (y 0..3), quoins at the arris."""
    wall, stone, top = quay_parts()
    a_w, a_s = Part("a"), Part("as")
    wall_run(a_w, a_s, 3.0, rnd, x_from=-1.5, coping=False, cell=0.13)
    place(a_w, wall)
    b_w, b_s = Part("b"), Part("bs")
    wall_run(b_w, b_s, 3.0, rnd, x_from=-1.5, coping=False, cell=0.13)
    place(b_w, wall, yaw_deg=90.0, offset=(1.5, 1.5, 0.0))           # face B: local -Y -> +X
    # quoins: long-and-short dressed blocks wrapping the arris (cover the two run ends)
    z = -COPE_T
    for ci, h in enumerate(COURSES):
        za = z - h
        o = batter(za) + 0.035
        long_a = 0.9 if ci % 2 == 0 else 0.45
        L(0, 1)
        wall.box((1.5 - long_a, -o, za + JOINT), (1.5 + o, 0.35, z - JOINT), tmode(rnd, 1.5 - long_a, -o, long_a + 0.5),
                 skip=("+y",))
        wall.box((1.15, -o, za + JOINT), (1.5 + o, 1.35 - long_a, z - JOINT), tmode(rnd, 1.15, -o, 1.2), skip=("-x",))
        z = za
    L()
    cs = Part("cs")
    cope(cs, -1.5, 0.95, rnd)
    place(cs, stone)
    cb = Part("cb")
    cope(cb, -1.5, 0.95, rnd)
    place(cb, stone, yaw_deg=90.0, offset=(1.5, 1.5, 0.0))
    stone.box((0.95, -COPE_O, -COPE_T), (1.5 + COPE_O, COPE_D - COPE_O, 0.0), STONE, skip=("-z",))   # corner stone
    setts(top, -1.5, 1.5 - (COPE_D - COPE_O), COPE_D - COPE_O, 3.0)
    return wall, stone, top


def quay_steps(rnd):
    """6 m section with a flight of granite steps built out against the face, descending to -X below the water.
    0.3 m risers, 0.33 m treads with a nosing, 1.0 m wide; masonry outer side, the tide band continuous."""
    wall, stone, top = quay_parts()
    wall_run(wall, stone, 3.0, rnd, x_from=-3.0, cell=0.13)
    wall_run(wall, stone, 3.0, rnd, x_from=0.0, cell=0.13)
    setts(top, -3.0, 3.0, COPE_D - COPE_O, 3.0)
    W, R, T = 1.0, 0.3, 0.33
    yb = 0.1
    yf = -W - 0.25
    x = 2.85
    k = 1
    while -R * k > FOOT + 0.2:
        zt = -R * k
        xa = x - T
        L(0)     # tread stone with nosing
        wall.prism([(yb, zt - 0.2), (yf + 0.02, zt - 0.2), (yf - 0.02, zt - 0.17), (yf - 0.02, zt - 0.03),
                     (yf, zt), (yb, zt)], "x", xa - 0.025, x, tmode(rnd, xa, yf, 1.3))
        L(1, 2)
        wall.box((xa, yf, zt - 0.2), (x, yb, zt), tmode(rnd, xa, yf, 1.3), skip=("+y", "-z"))
        L(0, 1)  # masonry column under the tread
        wall.box((xa, yf + 0.04, FOOT), (x, yb, zt - 0.2), tmode(rnd, xa, yf, 1.3), skip=("+y", "+z"))
        L(2)
        wall.face([(xa, yf, FOOT), (x, yf, FOOT), (x, yf, zt - 0.2), (xa, yf, zt - 0.2)], tmode(rnd, xa, yf, 1.3),
                  outward=(0, -1, 0))
        x = xa
        k += 1
    L()
    wall.face([(x, yf + 0.04, FOOT), (x, yb, FOOT), (x, yb, -R * (k - 1) - 0.2), (x, yf + 0.04, -R * (k - 1) - 0.2)], tmode(rnd, x, yf, 1.4),
              outward=(-1, 0, 0))
    # top end of the flight: the coping returns along the steps' top side
    stone.box((2.85, yf - 0.02, -COPE_T), (3.0, -COPE_O, 0.0), STONE, skip=("-z",))
    return wall, stone, top, (2.6, (yf + yb) / 2, -R), (x + 0.2, (yf + yb) / 2, -R * (k - 1))


def head_fn(p):
    r = math.hypot(p.x, p.y)
    return (math.atan2(p.y, p.x) * 3.0 / 4.0 + 0.05 * p.z, min(0.999, max(0.001, (p.z + 4.0 + 0.15 * (r - 3.0)) / 4.0)))


HEADUV = ("fn", head_fn)


def quay_head(rnd):
    """Pier roundhead for a 6 m wide pier: semicircular block wall (r 3 m) on the sea side, radial copings, setts.
    Snaps to two Straight pieces turned to face -X / +X (their faces along x = -3 and x = +3)."""
    wall, stone, top = quay_parts()
    R0 = 3.0

    def S(s, z, d):
        a = math.pi + s / R0
        r = R0 + batter(z) + d
        return Vector((r * math.cos(a), r * math.sin(a), z))
    rubble(wall, S, 0.0, math.pi * R0, FOOT, -COPE_T, rnd, cell=0.2, bulge=(0.02, 0.055), mortar_col=0.6, lod2_col=1.2)
    # radial copings
    for lods, n in (((0,), 10), ((1,), 6), ((2,), 3)):
        geo.LEVEL = lods
        for i in range(n):
            g = 0.003 if lods == (0,) else 0.0
            a0 = math.pi + math.pi * i / n + g
            a1 = math.pi + math.pi * (i + 1) / n - g
            ro, ri = R0 + COPE_O, R0 + COPE_O - COPE_D
            dz = rnd.uniform(-0.012, 0.0) if lods == (0,) else 0.0
            pts = [(ri * math.cos(a0), ri * math.sin(a0)), (ro * math.cos(a0), ro * math.sin(a0)),
                   (ro * math.cos(a1), ro * math.sin(a1)), (ri * math.cos(a1), ri * math.sin(a1))]
            stone.prism(pts, "z", -COPE_T, dz, STONE)
    L()
    ri = R0 + COPE_O - COPE_D
    fan = [(ri * math.cos(math.pi + math.pi * i / 16), ri * math.sin(math.pi + math.pi * i / 16), -0.005) for i in range(17)]
    top.face(fan, SETTS, outward=(0, 0, 1))
    return wall, stone, top


ARMOUR_ZONES = 4      # T_QuayKit_Armour: 4 bands in v (each 1 m tall x 4 m wide, tiling in u), bottom up:
#                       0 submerged kelp film, 1 wrack + barnacles, 2 barnacles + tar lichen, 3 dry lichened granite


def zone_of(cz, nz, rnd):
    hs = cz - SEA + rnd.uniform(-0.18, 0.18)
    k = 0 if hs < -0.6 else 1 if hs < 0.05 else 2 if hs < 0.7 else 3
    if nz < -0.35:
        k = max(0, k - 1)         # undersides stay wetter / weedier
    return k


def band_mode(n, pts, zone, rnd):
    ua, va = geo.frame_of(n)
    b = [p.dot(va) for p in pts]
    a0, b0 = min(p.dot(ua) for p in pts), min(b)
    sc = 1.0 / max(1.0, (max(b) - b0) / 0.94)
    du = rnd.random()
    v0 = zone / float(ARMOUR_ZONES)
    return ("fn", lambda p: (du + (p.dot(ua) - a0) / 4.0,
                             v0 + (0.03 + min(0.94, max(0.0, (p.dot(va) - b0) * sc))) / ARMOUR_ZONES))


def quarry_block(c, half, rnd):
    """POL1: a big angular quarried granite block in world metres (kit coords): a box split by 4..6 deep plane cuts
    (split faces) and 4..7 shallow corner spalls, every facet planar. Returns (lod0 bmesh with a narrow 2..3.5 cm
    arris chamfer, lod1 bmesh without it)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 2 * half[0], v.co.y * 2 * half[1], v.co.z * 2 * half[2]))
    cuts = [(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.8, 1))), rnd.uniform(0.66, 0.86))
            for _ in range(rnd.randint(4, 6))]
    cuts += [(Vector((rnd.choice((-1, 1)) * rnd.uniform(0.6, 1), rnd.choice((-1, 1)) * rnd.uniform(0.6, 1),
                      rnd.choice((-1, 1)) * rnd.uniform(0.5, 1))), rnd.uniform(0.82, 0.93)) for _ in range(rnd.randint(4, 7))]
    for nrm, k in cuts:
        nrm = Vector((nrm.x / half[0], nrm.y / half[1], nrm.z / half[2])).normalized()   # cut relative to the block shape
        sup = max(v.co.dot(nrm) for v in bm.verts)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=nrm * sup * k,
                               plane_no=nrm, clear_outer=True)
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.004)
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts[:], edges=bm.edges[:])
    bmesh.ops.dissolve_degenerate(bm, dist=0.01, edges=bm.edges[:])
    m = (Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 3, "Z") @ Matrix.Rotation(rnd.uniform(-0.25, 0.25), 3, "X")
         @ Matrix.Rotation(rnd.uniform(-0.25, 0.25), 3, "Y"))
    cv = Vector(c)
    for v in bm.verts:
        v.co = m @ v.co + cv
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    lod1 = bm.copy()
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=rnd.uniform(0.02, 0.035), segments=1, affect="EDGES", profile=0.5,
                    clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, lod1


def _move(bms, dz):
    for b in bms:
        for v in b.verts:
            v.co.z += dz


def _clip_below(b, z):
    """cut a block flat at the seabed plane (the buried part goes; the cap closes the shell)."""
    if min(v.co.z for v in b.verts) >= z - 1e-5:
        return
    bmesh.ops.bisect_plane(b, geom=b.verts[:] + b.edges[:] + b.faces[:], plane_co=Vector((0, 0, z)),
                           plane_no=Vector((0, 0, -1)), clear_outer=True)
    bmesh.ops.holes_fill(b, edges=[e for e in b.edges if e.is_boundary], sides=0)
    bmesh.ops.remove_doubles(b, verts=b.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])


def quay_armour(rnd):
    """Breakwater rock armour: 3 m section of big quarried granite blocks (1.0 to 2.2 m) tipped against the wall
    face in 4 layers, crest about z -0.3 at the wall (above the waterline), toe 5 m out on the seabed; blocks overlap
    the piece edges so neighbouring sections interlock.
    POL1: planar quarried facets with crisp chamfered arrises (flat shaded, no noise relief / T-junction seams), and
    every block is settled under gravity: dropped until it touches the seabed (z = FOOT) or a block below it, sunk a
    few cm into its support, and clipped flat at the seabed plane. The pivot is then moved to the seabed plane (see
    quay_spec), so the bottom of the rocks sits exactly at the pivot plane and nothing hovers."""
    from mathutils.bvhtree import BVHTree
    wall = Part("Wall", smooth_angle=6.0)
    placed = []          # (lod0 bm, lod1 bm, BVHTree, layer)
    for layer, (zc, ymin, ymax, s, xs) in enumerate( ((-3.25, -4.9, -4.0, 1.9, -1.55), (-2.35, -3.5, -2.7, 1.75, -1.2),
                                  (-1.45, -2.25, -1.7, 1.4, -1.6), (-0.65, -1.15, -0.85, 0.9, -1.35))):
        x = xs + rnd.uniform(-0.1, 0.15)
        while x < 1.55:
            sz = s * rnd.uniform(0.8, 1.15)
            half = (sz * rnd.uniform(0.42, 0.58), sz * rnd.uniform(0.32, 0.45), sz * rnd.uniform(0.26, 0.38))
            c = (x + half[0] * 0.75, rnd.uniform(ymin, ymax), zc + rnd.uniform(-0.12, 0.15) + 0.6)
            b0, b1 = quarry_block(c, half, rnd)
            zmin = min(v.co.z for v in b0.verts)
            low = [v.co.copy() for v in b0.verts if v.co.z < zmin + 0.45 * half[2] * 2]
            drop = 1e9
            for p in low:
                sup = FOOT
                for _, _, tree, ly in placed:
                    if ly >= layer:                # rests on the layers below (same-layer neighbours interlock)
                        continue
                    hit = tree.ray_cast(Vector((p.x, p.y, 6.0)), Vector((0, 0, -1)))
                    if hit[0] is not None:
                        sup = max(sup, hit[0].z)
                drop = min(drop, p.z - sup)
            sink = 0.18 if (zmin - drop < FOOT + 0.05 or layer == 3) else 0.12       # bed the toe into the sediment
            _move((b0, b1), -(drop + sink))
            _clip_below(b0, FOOT)
            _clip_below(b1, FOOT)
            placed.append((b0, b1, BVHTree.FromBMesh(b0), layer))
            x += half[0] * 1.55
    print("[POL1] armour layer tops m", [round(max(max(v.co.z for v in b[0].verts) for b in placed if b[3] == k), 2)
                                          for k in range(4)])
    for b0, b1, _, _ in placed:
        cv = sum((v.co for v in b1.verts), Vector()) / len(b1.verts)
        for lods, b in (((0,), b0), ((1, 2), b1)):
            geo.LEVEL = lods
            wall.prim += 1
            for f in b.faces:
                pts = [v.co.copy() for v in f.verts]
                n = f.normal.copy()
                cz = sum(p.z for p in pts) / len(pts)
                # one zone per facet (same draw for LOD0 / LOD1 would need matching facets; zones are coarse anyway)
                wall.face(pts, band_mode(n, pts, zone_of(cz, n.z, rnd), rnd), outward=n)
        b0.free()
        b1.free()
    L()
    for i, (pts, uvs, lv, pid) in enumerate(wall.faces):       # pivot -> seabed plane (bottom of the rocks)
        wall.faces[i] = ([Vector((p.x, p.y, p.z - FOOT)) for p in pts], uvs, lv, pid)
    return wall


# ---------------------------------------------------------------- ladder
def ladder(part, top_z=0.0, bot_z=-4.1, y_face=0.22, rnd=None):
    """Galvanised quay ladder: 0.45 m between 60x12 mm flat-bar stiles, 25 mm round rungs at 0.3 m, brackets
    into the recess back every 1.2 m, stiles carried up over the coping as grab hoops 1.0 m above the quay."""
    rnd = rnd or random.Random(3)
    H = ("fn", ladder_fn)
    w = 0.225
    yl = y_face - 0.16          # stile centre line, 16 cm off the recess back
    for sx in (-1, 1):
        x = sx * w
        L()
        part.box((x - 0.006, yl - 0.03, bot_z), (x + 0.006, yl + 0.03, top_z - 0.05), H)
        # grab hoop: up 1.0 m above the quay then over onto the coping (segmented bend), 8 segs
        pts = [(yl, top_z - 0.05), (yl, top_z + 0.75)]
        for i in range(1, 7):
            a = math.pi * i / 12.0
            pts.append((yl + 0.25 - 0.25 * math.cos(a), top_z + 0.75 + 0.25 * math.sin(a)))
        pts.append((yl + 0.25 + 0.0, top_z + 1.0))
        pts.append((yl + 0.55, top_z + 1.0))
        pts.append((yl + 0.55, top_z + 0.0))
        for (ya, za), (yb, zb) in zip(pts, pts[1:]):
            L() if abs(zb - za) > 0.3 or abs(yb - ya) > 0.2 else L(0, 1)
            part.tube((x, ya, za), (x, yb, zb), 0.019, 8 if geo.LEVEL == 3 else 6, H, caps=False)
        L(0)
        part.box((x - 0.04, yl + 0.5, top_z), (x + 0.04, yl + 0.6, top_z + 0.012), H)       # base plate on coping
        # brackets into the recess back
        zb = bot_z + 0.3
        while zb < top_z - 0.3:
            L(0, 1)
            part.box((x - 0.006, yl + 0.03, zb - 0.03), (x + 0.006, y_face, zb + 0.03), H)
            L(0)
            part.box((x - 0.04, y_face - 0.012, zb - 0.06), (x + 0.04, y_face, zb + 0.06), H)
            zb += 1.2
    z = bot_z + 0.25
    while z < top_z - 0.1:
        L(0, 1)
        part.tube((-w, yl, z), (w, yl, z), 0.0125, 8, H, caps=False)
        L(2)
        part.box((-w, yl - 0.0125, z - 0.0125), (w, yl + 0.0125, z + 0.0125), H, skip=("-x", "+x"))
        z += 0.3
    L()
    # weed clumps and barnacle crust on the lower stiles and rungs (below the waterline band)
    L(0)
    for _ in range(14):
        zc = rnd.uniform(bot_z + 0.1, SEA + 0.3)
        sx = rnd.choice((-1, 1))
        c = (sx * w + rnd.uniform(-0.02, 0.02), yl + rnd.uniform(-0.03, 0.03), zc)
        hull_rock(part, c, (0.025, 0.04, rnd.uniform(0.05, 0.12)), rnd, H, n=8, lods=(0,))
    L()


# ---------------------------------------------------------------- pontoons
DECK_T = 0.03
FRAME_H = 0.32


def board(part, x0, x1, y0, y1, k):
    strip = "Deck%d" % (k % 4)
    v0, v1 = MT.PKIT[strip]
    mode = ("trim", v0 + 0.004, v1 - 0.004, 2.0)
    part.box((x0, y0, -DECK_T), (x1, y1, 0.0), mode, skip=("-z",))


def pontoon(part, length, width, rnd, cleats, floats_per=1.5, freeboard_float=-0.25, finger=False):
    """Deck along +Y from 0 to length (centred on x), composite boards across, galvanised edge channel, rubber
    D-fender rubbing strips on both long sides, HDPE floats under the frame, cleats on the frame."""
    hw = width / 2.0
    FR = pk_fn("Frame", 1.0)
    RB = pk_fn("Rubber", 1.0)
    GV = pk_fn("Galv", 0.5)
    FL = ("fn", float_fn)
    # boards (LOD0) / deck slab (LOD1, LOD2)
    L(0)
    pitch, bw = 0.146, 0.138
    y = 0.06
    k = 0
    while y + bw <= length - 0.06 + 1e-6:
        board(part, -hw + 0.07, hw - 0.07, y, y + bw, rnd.randrange(4))
        y += pitch
        k += 1
    L(1, 2)
    part.box((-hw + 0.07, 0.06, -DECK_T), (hw - 0.07, length - 0.06, 0.0), ("trim", 0.504, 0.621, 2.0), skip=("-z",))
    L(0, 1)
    part.box((-hw + 0.07, 0.06, -0.12), (hw - 0.07, length - 0.06, -DECK_T), FR, skip=("+z",))    # joists / underside
    L()
    # edge channel frame (C-section reading as a 0.32 m deep galvanised fascia), ends too
    for sx in (-1, 1):
        part.box((min(sx * hw, sx * (hw - 0.07)), 0.0, -FRAME_H), (max(sx * hw, sx * (hw - 0.07)), length, 0.01), FR)
    for ye in (0.0, length - 0.06):
        part.box((-hw + 0.07, ye, -FRAME_H), (hw - 0.07, ye + 0.06, 0.01), FR)
    # rubbing strips: D-section rubber on the long sides (and the tip end of a finger)
    runs = [(sx, 0.05, length - 0.05) for sx in (-1, 1)]
    for sx, y0, y1 in runs:
        for lods, prof in (((0, 1), [(0.0, -0.24), (0.035, -0.235), (0.06, -0.205), (0.07, -0.16), (0.06, -0.115),
                                      (0.035, -0.085), (0.0, -0.08)]), ((2,), [(0.0, -0.24), (0.06, -0.22), (0.06, -0.1), (0.0, -0.08)])):
            geo.LEVEL = lods
            pr = [(sx * (hw + o), zz) for o, zz in prof]
            if sx < 0:
                pr = pr[::-1]
            part.extrude(pr, "y", y0, y1, RB)
    if finger:
        L(0, 1)
        part.box((-hw + 0.04, length, -0.24), (hw - 0.04, length + 0.06, -0.08), RB)
    L()
    # floats: HDPE tanks (LOD0 chamfered, LOD1/2 boxes)
    fw = width - 0.3
    n = max(1, int(length / floats_per + 0.5))
    seg = length / n
    for i in range(n):
        ya, yb = i * seg + 0.15, (i + 1) * seg - 0.15
        z0, z1 = MT.FLOAT_Z[0] + 0.05, freeboard_float
        L(0)
        c = 0.06
        part.prism([(-fw / 2 + c, z0), (fw / 2 - c, z0), (fw / 2, z0 + c), (fw / 2, z1), (-fw / 2, z1), (-fw / 2, z0 + c)],
                   "y", ya, yb, FL)
        L(1, 2)
        part.box((-fw / 2, ya, z0), (fw / 2, yb, z1), FL, skip=("+z",))
        L(0)   # weed fronds hanging from the float bottoms, barnacle lumps at the waterline
        for _ in range(int(seg * 3)):
            cx, cy = rnd.uniform(-fw / 2, fw / 2), rnd.uniform(ya + 0.1, yb - 0.1)
            if rnd.random() < 0.5:
                cx = rnd.choice((-1, 1)) * fw / 2
            hull_rock(part, (cx, cy, rnd.uniform(z0 + 0.02, -0.5)), (0.04, 0.06, rnd.uniform(0.05, 0.12)), rnd, FL, n=8, lods=(0,))
        L()
    # cleats: galvanised horn cleats 0.3 m on base plates on the frame top
    atts = []
    for i, (cx, cy) in enumerate(cleats):
        sx = 1 if cx > 0 else -1
        x = sx * (hw - 0.04)
        L()
        part.box((x - 0.04, cy - 0.12, 0.01), (x + 0.04, cy + 0.12, 0.025), GV)      # base plate
        L(0, 1)
        part.box((x - 0.022, cy - 0.04, 0.025), (x + 0.022, cy + 0.04, 0.09), GV)    # waist
        part.extrude([(cy - 0.15, 0.1), (cy - 0.12, 0.08), (cy + 0.12, 0.08), (cy + 0.15, 0.1), (cy + 0.12, 0.115),
                          (cy - 0.12, 0.115)], "x", x - 0.02, x + 0.02, GV)
        L(0)
        for by in (cy - 0.09, cy + 0.09):
            part.tube((x, by, 0.025), (x, by, 0.034), 0.012, 6, GV)
        L(2)
        part.box((x - 0.02, cy - 0.13, 0.025), (x + 0.02, cy + 0.13, 0.11), GV)
        L()
        atts.append(("ATT_Moor_%02d" % (i + 1), (x, cy, 0.09), (sx, 0, 0)))
    return atts


def gangway(part, length=9.0, width=1.0, rnd=None):
    """Hinged aluminium gangway: pivot = the hinge line at the quay end (y 0), running out along +Y to the roller
    end; tread with transverse non-slip ribs, side stringers, posts and twin handrails 1.0 m above the tread,
    a hinge plate at the quay end and two rollers (wheels) at the pontoon end. Modelled level; integration rotates it
    about ATT_Hinge for the tide."""
    hw = width / 2.0
    TR = pk_fn("Tread", 1.0)
    GV = pk_fn("GwSteel", 0.5)        # HP1b: gangway steelwork has its own rust-streaked galvanised strip
    FR = pk_fn("GwSteel", 1.0)
    L()
    part.box((-hw, 0.0, -0.04), (hw, length, 0.0), TR, skip=("-z",))
    L(0)
    y = 0.25
    while y < length - 0.2:
        part.box((-hw + 0.02, y, 0.0), (hw - 0.02, y + 0.03, 0.018), TR)      # tread cleats (slats)
        y += 0.32
    L()
    for sx in (-1, 1):
        x0, x1 = sorted((sx * hw, sx * (hw + 0.06)))
        part.box((x0, 0.0, -0.22), (x1, length, 0.12), FR)                    # stringer
        # posts
        y = 0.1
        while y <= length - 0.05:
            L(0, 1)
            xc = sx * (hw + 0.03)
            part.tube((xc, y, 0.12), (xc, y, 1.0), 0.028, 8, GV, caps=False)
            y += 1.5 if y + 1.5 <= length - 0.05 else max(length - 0.1 - y, 1.0)
            if y > length - 0.05:
                break
        L()
        xc = sx * (hw + 0.03)
        part.tube((xc, 0.0, 1.0), (xc, length, 1.0), 0.032, 10, GV)            # top rail (64 mm)
        L(0, 1)
        part.tube((xc, 0.0, 0.55), (xc, length, 0.55), 0.024, 8, GV)           # knee rail (48 mm)
        L(0)
        for yr in (length - 0.25,):
            part.tube((sx * (hw - 0.1), yr, -0.2), (sx * (hw + 0.01), yr, -0.2), 0.11, 12, ("trim", 0.254, 0.371, 1.0))  # roller
        L()
    part.box((-hw - 0.08, -0.08, -0.06), (hw + 0.08, 0.0, 0.02), GV)          # hinge plate
    L(0)
    part.tube((-hw - 0.05, -0.04, -0.02), (hw + 0.05, -0.04, -0.02), 0.03, 10, GV)   # hinge pin
    L()


# ---------------------------------------------------------------- spec helpers
def mats():
    return {k: geo.material("MI_HP1_" + k, c, r, m) for k, c, r, m in
            (("Wall", (0.2, 0.2, 0.18), 0.7, 0.0), ("Stone", (0.4, 0.38, 0.35), 0.8, 0.0), ("Top", (0.3, 0.3, 0.3), 0.85, 0.0),
             ("Pontoon", (0.3, 0.29, 0.27), 0.6, 0.0), ("Ladder", (0.4, 0.4, 0.4), 0.5, 1.0))}


def emit(name, parts_sets):
    """[(Part, set name, material)] -> LOD meshes."""
    meshes = []
    for p, s, mat in parts_sets:
        if not p.faces:
            continue
        for li, lod in ((0, "LOD0"), (1, "LOD1"), (2, "LOD2")):
            meshes.append({"object": p.to_object("%s_%s_%s" % (name, p.name, lod), mat, lod=li), "set": s})
        print("[HP1] %s %s LOD0 %d / LOD1 %d / LOD2 %d tris" % (name, p.name, p.tris(0), p.tris(1), p.tris(2)))
    return meshes


def col_object(name, boxes):
    col = Part("COL")
    for lo, hi in boxes:
        col.box(lo, hi, ("tile", 1.0))
    return col.to_object(name + "_COL", None, weld=False)


QUAY_SETS = [{"name": "QuayKit", "set": "Tide", "size": 1024, "wet": True, "dir": TEX + "M_Hbr_QuayKit"},
             {"name": "QuayKit", "set": "Stone", "size": 1024, "wet": True, "dir": TEX + "M_Hbr_QuayKit"},
             {"name": "QuayKit", "set": "Armour", "size": 1024, "wet": True, "dir": TEX + "M_Hbr_QuayKit"},
             {"name": "Mat", "set": "Cobbles", "size": 1024, "wet": True, "dir": TEX + "Materials"}]
QUAY_WAIVER = {"texture sets": "HP1: 3 sets for a modular quay piece = 2 own kit sets shared by every QuayKit piece "
                               "(Tide: block faces with the shore zonation baked by height, v = z, so it cannot be a "
                               "MaterialVariant; Stone: dressed copings) + the shared B02 Cobbles setts",
               "LOD UV layout": "world-scale tiling UVs; hand-made LODs (blocks -> courses -> one plane)"}


def quay_spec(piece, rnd_seed, dims, closeups, extra_atts=()):
    name = "M_Hbr_QuayKit_" + piece
    rnd = random.Random(rnd_seed)
    m = mats()
    extra = {}
    if piece in ("Straight", "LadderBay"):
        wall, stone, top = quay_straight(rnd, ladder_bay=(piece == "LadderBay"))
        atts = [att("ATT_Snap_L", (-1.5, 0, 0), (-1, 0, 0)), att("ATT_Snap_R", (1.5, 0, 0), (1, 0, 0)),
                att("ATT_Moor_01", (0.0, -COPE_O, -0.15), (0, -1, 0)), att("ATT_WaterLine", (0, -0.1, SEA), (0, -1, 0))]
        if piece == "LadderBay":
            atts += [att("ATT_Ladder", (0, 0.22, 0), (0, -1, 0))]
            atts[2].location = Vector((1.0, -COPE_O, -0.15)) * 3.0
        cols = [((-1.5, -0.35, FOOT), (1.5, 3.0, 0.0))]
        if piece == "LadderBay":
            cols = [((-1.5, -0.35, FOOT), (-0.35, 3.0, 0.0)), ((0.35, -0.35, FOOT), (1.5, 3.0, 0.0)),
                    ((-0.35, 0.22, FOOT), (0.35, 3.0, 0.0))]
    elif piece == "Corner":
        wall, stone, top = quay_corner(rnd)
        atts = [att("ATT_Snap_A", (-1.5, 0, 0), (-1, 0, 0)), att("ATT_Snap_B", (1.5, 3.0, 0), (0, 1, 0)),
                att("ATT_Moor_01", (1.5, -COPE_O, -0.15), (1, -1, 0)), att("ATT_WaterLine", (1.4, -0.1, SEA), (1, -1, 0))]
        cols = [((-1.5, -0.35, FOOT), (1.85, 3.0, 0.0))]
    elif piece == "Steps":
        wall, stone, top, st_top, st_bot = quay_steps(rnd)
        atts = [att("ATT_Snap_L", (-3.0, 0, 0), (-1, 0, 0)), att("ATT_Snap_R", (3.0, 0, 0), (1, 0, 0)),
                att("ATT_Steps_Top", st_top, (-1, 0, 0)), att("ATT_Steps_Bottom", st_bot, (-1, 0, 0)),
                att("ATT_Moor_01", (-2.0, -COPE_O, -0.15), (0, -1, 0)), att("ATT_WaterLine", (0, -1.2, SEA), (0, -1, 0))]
        cols = [((-3.0, -0.35, FOOT), (3.0, 3.0, 0.0))]
        # stepped collision: 4 boxes approximating the flight
        for i in range(4):
            x1 = 2.85 - i * 1.15
            cols.append(((x1 - 1.15, -1.27, FOOT), (x1, -0.3, -0.3 - i * 1.05)))
    elif piece == "Head":
        wall, stone, top = quay_head(rnd)
        atts = [att("ATT_Snap_L", (-3.0, 0, 0), (0, 1, 0)), att("ATT_Snap_R", (3.0, 0, 0), (0, 1, 0)),
                att("ATT_Moor_01", (-2.12, -2.12, -0.15), (-1, -1, 0)), att("ATT_Moor_02", (0, -3.05, -0.15), (0, -1, 0)),
                att("ATT_Moor_03", (2.12, -2.12, -0.15), (1, -1, 0)), att("ATT_WaterLine", (0, -3.1, SEA), (0, -1, 0)),
                att("ATT_Light", (0, -1.5, 0), (0, -1, 0))]
        cols = [((-3.05, -3.05, FOOT), (3.05, 0.0, 0.0))]
    elif piece == "Armour":
        wall = quay_armour(rnd)
        stone, top = Part("Stone"), Part("Top")
        # POL1: pivot on the seabed plane (rock bottoms at z 0); the snaps stay at quay-top level (+4 m) so the
        # piece still snaps to the quay wall run, ATT_WaterLine at sea level (+2.667 m)
        H = -FOOT
        atts = [att("ATT_Snap_L", (-1.5, 0, H), (-1, 0, 0)), att("ATT_Snap_R", (1.5, 0, H), (1, 0, 0)),
                att("ATT_WaterLine", (0, -1.6, SEA + H), (0, -1, 0))]
        cols = [((-1.5, -1.3, 0.0), (1.5, 0.0, H - 0.45)), ((-1.5, -2.6, 0.0), (1.5, -1.3, H - 1.15)),
                ((-1.5, -4.0, 0.0), (1.5, -2.6, H - 2.1)), ((-1.5, -5.4, 0.0), (1.5, -4.0, H - 3.0))]
    meshes = emit(name, [(wall, "Armour" if piece == "Armour" else "Tide", m["Wall"]), (stone, "Stone", m["Stone"]),
                         (top, "Cobbles", m["Top"])])
    meshes.append({"object": col_object(name, cols)})
    used = {e["set"] for e in meshes if "set" in e}
    return {"name": name, "budget": "large_prop", "tris": 8000, "tier": "standard", "dims_m": dims,
            "origin": "free", "tiling": True,
            "sets": [s for s in QUAY_SETS if s["set"] in used],
            "waivers": QUAY_WAIVER, "meshes": meshes, "attachments": atts, "closeups": closeups}


PONTOON_SETS = [{"name": "Pontoon", "set": "Kit", "size": 1024, "wet": True, "dir": TEX + "M_Hbr_Pontoon"}]


def pontoon_spec(piece, closeups):
    """Straight6 / Straight12 (2.4 m wide), Corner (2.4 x 2.4), Finger (6 x 0.9 m), Gangway (9 x 1.0 m, hinged).
    Deck sections: pivot = deck top centre of the -Y end (y 0), length along +Y; ATT_Snap_Start / _End at the ends."""
    name = "M_Hbr_Pontoon_" + piece
    rnd = random.Random({"Straight6": 61, "Straight12": 121, "Corner": 24, "Finger": 9, "Gangway": 90}[piece])
    m = mats()
    p = Part("Deck")
    if piece == "Gangway":
        p.name = "Gangway"
        gangway(p, 9.0, 1.0, rnd)
        atts = [att("ATT_Hinge", (0, -0.04, -0.02), (0, -1, 0)), att("ATT_Roller", (0, 8.75, -0.31), (0, 1, 0)),
                att("ATT_Snap_Start", (0, 0, 0), (0, -1, 0)), att("ATT_Snap_End", (0, 9.0, 0), (0, 1, 0))]
        dims = (1.12, 9.0, None)
        cols = [((-0.56, 0.0, -0.22), (0.56, 9.0, 0.0)), ((-0.6, 0.0, 0.0), (-0.5, 9.0, 1.04)), ((0.5, 0.0, 0.0), (0.6, 9.0, 1.04))]
        budget, tris = "large_prop", 3000
    else:
        Lm, W = {"Straight6": (6.0, 2.4), "Straight12": (12.0, 2.4), "Corner": (2.4, 2.4), "Finger": (6.0, 0.9)}[piece]
        hw = W / 2
        if piece == "Corner":
            cl = [(hw, 1.2)]
        elif piece == "Finger":
            cl = [(-hw, 2.8), (hw, 2.8), (-hw, 5.7), (hw, 5.7)]
        else:
            ys = [0.6, Lm / 2, Lm - 0.6] if Lm > 7 else [0.6, Lm - 0.6]
            cl = [(sx * hw, y) for y in ys for sx in (-1, 1)]
        moor = pontoon(p, Lm, W, rnd, cl, floats_per=1.5 if W > 1 else 2.0, finger=(piece == "Finger"),
                       freeboard_float=-0.25 if W > 1 else -0.2)
        atts = [att(n, pos, lk) for n, pos, lk in moor]
        atts += [att("ATT_Snap_Start", (0, 0, 0), (0, -1, 0)), att("ATT_WaterLine", (0, Lm / 2, -0.5), (0, -1, 0))]
        if piece != "Finger":
            atts.append(att("ATT_Snap_End", (0, Lm, 0), (0, 1, 0)))
        if piece == "Corner":
            atts += [att("ATT_Snap_Side_L", (-hw, Lm / 2, 0), (-1, 0, 0)), att("ATT_Snap_Side_R", (hw, Lm / 2, 0), (1, 0, 0))]
        if piece in ("Straight6", "Straight12"):
            for i, y in enumerate([Lm / 2 - 1.5, Lm / 2 + 1.5] if Lm > 7 else [Lm / 2]):
                atts.append(att("ATT_Snap_Finger_%02d" % (i + 1), (hw + 0.07, y, 0), (1, 0, 0)))
            atts.append(att("ATT_Snap_Gangway", (0, 0.3, 0), (0, -1, 0)))
        dims = (W + 0.14, Lm, None)
        cols = [((-hw - 0.07, 0.0, -0.9), (hw + 0.07, Lm, 0.0))]
        budget, tris = "large_prop", 3000 if piece != "Straight12" else 6000
    meshes = emit(name, [(p, "Kit", m["Pontoon"])])
    meshes.append({"object": col_object(name, cols)})
    return {"name": name, "budget": budget, "tris": tris, "tier": "standard", "dims_m": dims,
            "size_note": "HP1: dims include the rubber D-fenders (deck width without them %.2f m)" % (dims[0] - 0.14),
            "origin": "free", "tiling": True, "sets": PONTOON_SETS,
            "waivers": {"LOD UV layout": "strip atlas tiling in u; hand-made LODs (boards -> slab)"},
            "meshes": meshes, "attachments": atts, "closeups": closeups}


def ladder_spec(closeups):
    name = "M_Hbr_Ladder"
    m = mats()
    p = Part("Steel")
    ladder(p, rnd=random.Random(45))
    atts = [att("ATT_Ladder_Top", (0, 0.06, 0.0), (0, -1, 0)), att("ATT_Ladder_Bottom", (0, 0.06, -4.1), (0, -1, 0)),
            att("ATT_Ladder_Mount", (0, 0.22, 0.0), (0, -1, 0)), att("ATT_WaterLine", (0, 0.06, SEA), (0, -1, 0))]
    meshes = emit(name, [(p, "Steel", m["Ladder"])])
    meshes.append({"object": col_object(name, [((-0.26, 0.0, -4.1), (0.26, 0.12, 0.0)),
                                              ((-0.26, 0.0, 0.0), (0.26, 0.6, 1.02))])})
    return {"name": name, "budget": "large_prop", "tris": 1500, "tier": "standard", "dims_m": (0.49, None, None),
            "size_note": "HP1: 0.45 m between stile centres; dims are over the 38 mm grab hoops",
            "origin": "free", "tiling": True,
            "sets": [{"name": "Ladder", "set": "Steel", "size": 1024, "wet": True, "dir": TEX + "M_Hbr_Ladder"}],
            "waivers": {"LOD UV layout": "height-mapped tiling UVs; hand-made LODs"},
            "meshes": meshes, "attachments": atts, "closeups": closeups}
