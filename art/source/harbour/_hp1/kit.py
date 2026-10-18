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
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
sys.path.insert(0, G + "art/source/buildings/M_Bld_Station")
sys.path.insert(0, HERE)
import geo  # noqa: E402
from geo import Part  # noqa: E402


class MT:   # layout constants shared with maketex.py (no PIL inside Blender)
    SEA = -1.333
    PKIT = {"Float": (0.0, 0.125), "Tread": (0.125, 0.1875), "Galv": (0.1875, 0.25), "Rubber": (0.25, 0.375),
            "Frame": (0.375, 0.5), "Deck0": (0.5, 0.625), "Deck1": (0.625, 0.75), "Deck2": (0.75, 0.875), "Deck3": (0.875, 1.0)}
    FLOAT_Z = (-0.95, 0.0)
    LADDER_Z = (-4.2, 1.2)


TEX = G + "assets/textures/"
SEA = MT.SEA
FOOT = -4.0
COPE_T, COPE_D, COPE_O = 0.3, 0.6, 0.05     # coping thickness, depth (front to back), overhang over the face
SETBACK = 0.045                            # stepped batter per course (each course down steps 4.5 cm further out)
COURSES = [0.5, 0.45, 0.55, 0.5, 0.45, 0.5, 0.55]   # block courses below the coping, top down (sum 3.5 + 0.3 = 3.8)
JOINT = 0.012


def L(*lods):
    geo.LEVEL = lods if lods else 3


# ---------------------------------------------------------------- UV modes
def tide_fn(p):
    """T_QuayKit_Tide: u along the wall (4 m tile), v = height (z 0 -> v 1, z -4 -> v 0). Depth (y) nudges both so
    horizontal faces (treads, block tops) do not smear one texel row."""
    return ((p.x + 0.6 * p.y) / 4.0, min(0.999, max(0.001, (p.z + 4.0 + 0.12 * p.y) / 4.0)))


TIDE = ("fn", tide_fn)


def armour_fn(p):
    """tide_fn without the clamp (rock undersides dip a few cm under the wall foot; tiling UVs)."""
    return ((p.x + 0.6 * p.y + 0.05 * p.z) / 4.0, (p.z + 4.0 + 0.12 * p.y - 0.09 * p.x) / 4.0)


ARMOUR = ("fn", armour_fn)
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


# ---------------------------------------------------------------- masonry
def block(part, x0, x1, yf, yb, z0, z1, mode, ch=0.035, tilt=0.0):
    """A granite block, its face at y = yf (sea side, yf < yb), chamfered front arrises top and bottom (LOD0)."""
    ya, yb2 = yf - tilt, yf + tilt
    bulge = 0.012 + 0.02 * abs(math.sin(x0 * 7.3 + z0 * 3.1))       # pitch-faced: the face swells 1 to 3 cm
    prof = [(yb, z0), (yf + ch, z0), (ya, z0 + ch), (yf - bulge, (z0 + z1) / 2 - 0.05), (yf - bulge * 0.8, (z0 + z1) / 2 + 0.06),
            (yb2, z1 - ch), (yf + ch, z1), (yb, z1)]
    part.prism(prof, "x", x0, x1, mode)


def wall_run(wall, stone, length, rnd, x_from=-1.5, top_mode=None, coping=True, skip_x=None):
    """A straight battered block wall from x_from to x_from + length, face at y ~ 0 (going out with the batter
    below), coping on top. Courses use per-course random joints; the end joints sit on the piece edges."""
    x0, x1 = x_from, x_from + length
    z = -COPE_T
    # LOD2: one plane per wall, LOD1: one prism per course, LOD0: chamfered blocks + recessed joint backing
    L(2)
    zf = FOOT
    wall.face([(x0, -SETBACK * 4, zf), (x1, -SETBACK * 4, zf), (x1, -0.02, -COPE_T), (x0, -0.02, -COPE_T)], TIDE,
              outward=(0, -1, 0))
    for ci, h in enumerate(COURSES + [z - sum(COURSES) - FOOT]):
        if h <= 0.02:
            continue
        za, zb = z - h, z
        yf = -SETBACK * (ci + 0.5)
        L(1)
        wall.box((x0, yf, za), (x1, 0.4, zb), TIDE, skip=("+y", "-x", "+x", "+z", "-z"))
        L(0)
        wall.box((x0, yf + 0.03, za), (x1, 0.4, zb), TIDE, skip=("+y", "-x", "+x", "+z", "-z"))   # joint backing
        xs = [x0]
        while xs[-1] < x1 - 0.5:
            nx = xs[-1] + rnd.uniform(0.8, 1.45) * (0.5 if ci % 2 and len(xs) == 1 else 1.0)
            xs.append(min(nx, x1) if x1 - nx > 0.45 else x1)
        if xs[-1] < x1:
            xs[-1] = x1
        for a, b in zip(xs, xs[1:]):
            a2 = a + (JOINT if a > x0 + 1e-6 else 0.0)
            b2 = b - (JOINT if b < x1 - 1e-6 else 0.0)
            block(wall, a2, b2, yf + rnd.uniform(-0.012, 0.012), 0.35, za + JOINT, zb - JOINT, TIDE,
                  ch=rnd.uniform(0.025, 0.05), tilt=rnd.uniform(-0.008, 0.008))
        z = za
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
        L()
        wall.face([(-rw, rd, FOOT), (rw, rd, FOOT), (rw, rd, -COPE_T), (-rw, rd, -COPE_T)], TIDE, outward=(0, -1, 0))
        for sx in (-1, 1):
            wall.face([(sx * rw, -0.2, FOOT), (sx * rw, rd, FOOT), (sx * rw, rd, -COPE_T), (sx * rw, -0.2, -COPE_T)], TIDE,
                      outward=(-sx, 0, 0))
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
    wall_run(a_w, a_s, 3.0, rnd, x_from=-1.5, coping=False)
    place(a_w, wall)
    b_w, b_s = Part("b"), Part("bs")
    wall_run(b_w, b_s, 3.0, rnd, x_from=-1.5, coping=False)
    place(b_w, wall, yaw_deg=90.0, offset=(1.5, 1.5, 0.0))           # face B: local -Y -> +X
    # quoins: long-and-short dressed blocks wrapping the arris (cover the two run ends)
    z = -COPE_T
    for ci, h in enumerate(COURSES):
        za = z - h
        o = SETBACK * (ci + 0.5) + 0.02
        long_a = 0.9 if ci % 2 == 0 else 0.45
        L(0, 1)
        wall.box((1.5 - long_a, -o, za + JOINT), (1.5 + o, 0.35, z - JOINT), TIDE, skip=("+y",))
        wall.box((1.15, -o, za + JOINT), (1.5 + o, 1.35 - long_a, z - JOINT), TIDE, skip=("-x",))
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
    wall_run(wall, stone, 3.0, rnd, x_from=-3.0)
    wall_run(wall, stone, 3.0, rnd, x_from=0.0)
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
                     (yf, zt), (yb, zt)], "x", xa - 0.025, x, TIDE)
        L(1, 2)
        wall.box((xa, yf, zt - 0.2), (x, yb, zt), TIDE, skip=("+y", "-z"))
        L(0, 1)  # masonry column under the tread
        wall.box((xa, yf + 0.04, FOOT), (x, yb, zt - 0.2), TIDE, skip=("+y", "+z"))
        L(2)
        wall.face([(xa, yf, FOOT), (x, yf, FOOT), (x, yf, zt - 0.2), (xa, yf, zt - 0.2)], TIDE, outward=(0, -1, 0))
        x = xa
        k += 1
    L()
    wall.face([(x, yf + 0.04, FOOT), (x, yb, FOOT), (x, yb, -R * (k - 1) - 0.2), (x, yf + 0.04, -R * (k - 1) - 0.2)], TIDE,
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
    segs = 12
    z = -COPE_T
    for ci, h in enumerate(COURSES + [z - sum(COURSES) - FOOT]):
        za, zb = z - h, z
        ro = R0 + SETBACK * (ci + 0.5)
        off = (ci % 2) * 0.5
        for lods, n in (((0,), segs + (ci % 2)), ((1,), 6)):
            geo.LEVEL = lods
            for i in range(n):
                a0 = math.pi + math.pi * max(0.0, (i - (off if lods == (0,) else 0))) / (n - (off if lods == (0,) else 0))
                a1 = math.pi + math.pi * min(1.0, (i + 1 - (off if lods == (0,) else 0)) / (n - (off if lods == (0,) else 0)))
                if a1 - a0 < 1e-4:
                    continue
                g = 0.004 if lods == (0,) else 0.0
                rr = ro + (rnd.uniform(-0.01, 0.01) if lods == (0,) else 0.0)
                ri = ro - 0.5
                pts = [(ri * math.cos(a0 + g), ri * math.sin(a0 + g)), (rr * math.cos(a0 + g), rr * math.sin(a0 + g)),
                       (rr * math.cos(a1 - g), rr * math.sin(a1 - g)), (ri * math.cos(a1 - g), ri * math.sin(a1 - g))]
                wall.prism(pts, "z", za + (JOINT if lods == (0,) else 0), zb - (JOINT if lods == (0,) else 0),
                           HEADUV)
        z = za
    L(2)
    for i in range(4):
        a0, a1 = math.pi + math.pi * i / 4, math.pi + math.pi * (i + 1) / 4
        ro = R0 + SETBACK * 4
        wall.face([(ro * math.cos(a0), ro * math.sin(a0), FOOT), (ro * math.cos(a1), ro * math.sin(a1), FOOT),
                   (R0 * math.cos(a1), R0 * math.sin(a1), -COPE_T), (R0 * math.cos(a0), R0 * math.sin(a0), -COPE_T)],
                  HEADUV,
                  outward=(math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2), 0))
    L()
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


def quay_armour(rnd):
    """Breakwater rock armour: 3 m section of quarried granite blocks (0.6 to 1.6 m) tipped against the wall face,
    crest at about z -0.6 at the wall, toe 4.5 m out on the seabed; overlaps the piece edges so sections interlock."""
    wall = Part("Wall")
    placed = []
    for layer, (zc, ymin, ymax, s) in enumerate(((-3.4, -4.6, -2.6, 1.2), (-2.6, -3.6, -1.6, 1.1),
                                                 (-1.8, -2.6, -0.9, 0.95), (-1.1, -1.6, -0.5, 0.85))):
        x = -1.5 + rnd.uniform(-0.2, 0.3)
        while x < 1.6:
            sz = s * rnd.uniform(0.75, 1.2)
            sx_, sy_, sz_ = sz * rnd.uniform(0.6, 0.85), sz * rnd.uniform(0.5, 0.7), sz * rnd.uniform(0.35, 0.55)
            c = (x + sx_ * 0.6, rnd.uniform(ymin, ymax), max(zc + rnd.uniform(-0.15, 0.2), FOOT + 0.03 + sz_ * 0.8))
            if c[0] < 1.75:
                placed.append(c)
                hull_rock(wall, c, (sx_, sy_, sz_), rnd, ARMOUR, n=34, lods=(0,))
                hull_rock(wall, c, (sx_ * 0.97, sy_ * 0.97, sz_ * 0.97), rnd, ARMOUR, n=10, lods=(1,))
            x += sx_ * 1.15
    L(2)
    for c in placed[::3]:
        hull_rock(wall, c, (0.9, 0.8, 0.5), rnd, ARMOUR, n=7, lods=(2,))
    L()
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
    GV = pk_fn("Galv", 0.5)
    FR = pk_fn("Frame", 1.0)
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
            part.tube((xc, y, 0.12), (xc, y, 1.0), 0.022, 8, GV, caps=False)
            y += 1.5 if y + 1.5 <= length - 0.05 else max(length - 0.1 - y, 1.0)
            if y > length - 0.05:
                break
        L()
        xc = sx * (hw + 0.03)
        part.tube((xc, 0.0, 1.0), (xc, length, 1.0), 0.024, 8, GV)             # top rail
        L(0, 1)
        part.tube((xc, 0.0, 0.55), (xc, length, 0.55), 0.016, 6, GV)           # knee rail
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
        atts = [att("ATT_Snap_L", (-1.5, 0, 0), (-1, 0, 0)), att("ATT_Snap_R", (1.5, 0, 0), (1, 0, 0)),
                att("ATT_WaterLine", (0, -1.6, SEA), (0, -1, 0))]
        cols = [((-1.5, -2.2, FOOT), (1.5, 0.0, -1.0)), ((-1.5, -4.0, FOOT), (1.5, -2.2, -2.4)),
                ((-1.5, -5.4, FOOT), (1.5, -4.0, -3.4))]
    meshes = emit(name, [(wall, "Tide", m["Wall"]), (stone, "Stone", m["Stone"]), (top, "Cobbles", m["Top"])])
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
        cols = [((-0.56, 0.0, -0.22), (0.56, 9.0, 0.0)), ((-0.6, 0.0, 0.0), (-0.5, 9.0, 1.02)), ((0.5, 0.0, 0.0), (0.6, 9.0, 1.02))]
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
