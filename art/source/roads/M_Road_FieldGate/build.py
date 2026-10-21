"""R2 M_Road_FieldGate (docs/12 2.4, Haven Head road): a Cornish five-bar timber field gate, hung between its
hanging and slamming posts, with hook-and-band hinges, a latch bar and keeper, and a holding-open chain.

    python3 art/source/roads/M_Road_FieldGate/gatetex.py                      (trim set, once; no heavy slot)
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/roads/M_Road_FieldGate/build.py \
        --out-root build/prod/M_Road_FieldGate --steps build,lod,validate,export,turntable

Real dimensions (verify): a five-bar gate's leaf is 3.60 m from heel to head stile (the docs/12 row's "about 3.6 m")
and 1.20 m high at the top bar, five bars at 0.235 m centres (100 x 40 mm), stiles 110 x 40 mm, a middle stile and a
diagonal brace from the bottom of the heel stile up to the top of the head stile. The hanging post is 200 x 200 mm,
1.55 m above ground, the slamming post 150 x 150 mm, 1.30 m, 10 mm clear of the leaf's head. The leaf hangs 130 mm
off the post line, so its back face clears both posts: two galvanised hook-and-band hinges (a 60 x 6 mm strap bolted
to the leaf, its hook curled 240 degrees round a 20 mm pin driven into the hanging post's front face) at the bottom
and top bars. The latch bar rides on a bracket on the head stile and its end drops into a forged staple keeper on the
slamming post at 1.02 m; a nine-link galvanised chain hangs from a ring on the slamming post and the leaf's head stile
carries the hook it is held open on. Soil and moss mounds and a few grass blades sit round both post feet. The origin
is on the ground at the hanging post's centre.

The leaf is its own MeshPart (`M_Road_FieldGate_Leaf_LOD0`, with its own collision proxy) so the game can swing it;
ATT_Hinge marks the leaf's pivot - the vertical line through the two hinge pins, 60 mm behind the leaf's face. The
game road kit (kit.py) supplies Part / box / sweep / lathe / transforms / empties / the collision proxy; the trim set
is art/source/roads/M_Road_FieldGate/gatetex.py on layout.py, in M_Road_CrashBarrier's style.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROADS = os.path.dirname(HERE)
sys.path.insert(0, ROADS)
sys.path.insert(0, HERE)
import kit  # noqa: E402
import layout as L  # noqa: E402

S = kit.S

# ---------------------------------------------------------------------------------------------------- real sizes (m)
LEAF_X0, LEAF_X1 = 0.100, 3.700     # the leaf: 3.60 m clear between the posts; its -X face touches the hanging post
LEAF_Y = -0.130                     # the leaf's mid plane: its back face 10 mm clear of the hanging post's front
BAR_Z = (0.210, 0.445, 0.680, 0.915, 1.150)          # five bars, 0.235 m centres; top bar top = 1.200 m
BAR_T, BAR_W = 0.040, 0.100         # bar thickness (Y) and height (Z)
STILE_T, STILE_W = 0.040, 0.110     # stiles, flush with the bars' faces
MID_W = 0.075                       # middle stile width
Z_LEAF0, Z_LEAF1 = BAR_Z[0] - BAR_W / 2.0, BAR_Z[-1] + BAR_W / 2.0     # 0.160 .. 1.200
HPOST, HPOST_TOP = 0.200, 1.550     # hanging post: 200 square, 1.55 m above ground
SPOST, SPOST_TOP = 0.150, 1.300     # slamming post
SLAM_X = LEAF_X1 + 0.010 + SPOST / 2.0               # 3.785: a 10 mm gap between the leaf's head and the post
X_PIN = 0.065                       # hinge pin axis: 35 mm inside the hanging post's +X face, on its front face
Z_PINS = (BAR_Z[0], BAR_Z[-1])      # hinges on the bottom and top bars
HOOK_R, HOOK_T, HOOK_W = 0.022, 0.006, 0.050         # hook: curl mid radius, plate thickness, plate width
STRAP_T, STRAP_W, STRAP_X1 = 0.006, 0.060, 0.685     # hinge strap plate, bolted along the bar
STRAP_Y = LEAF_Y - 0.020 - 0.003                     # the strap's mid plane, on the leaf's front face
PIN_PROF = ((0.000, -0.185), (0.0105, -0.181), (0.0100, -0.177), (0.0100, -0.115), (0.0148, -0.113),
            (0.0148, -0.098), (0.0100, -0.096), (0.0100, -0.080), (0.000, -0.079))       # y from the tip inward
LATCH_Z, LATCH_X0, LATCH_X1 = 1.020, 3.260, 3.800    # latch bar, its end 100 mm past the head stile
LATCH_Y = -0.165                     # the bar's mid plane: 5 mm proud of its bracket plate
KEEPER_X, KEEPER_Y0, KEEPER_Y1 = SLAM_X, -0.065, -0.196                               # keeper staple
CHAIN_TOP = 1.100                    # the chain ring's centre on the slamming post
MOUND = ((0.0, 0.0, 0.095, 0.185, 0.075), (SLAM_X, 0.0, 0.062, 0.150, 0.058))        # cx, cy, rx, ry, h
DENTS = ((2.14, 0.680, 0.30, 0.004), (3.31, 0.210, 0.22, 0.006),
         (0.62, 1.150, 0.26, 0.005), (1.31, 0.445, 0.20, 0.004))                      # x, z, radius, depth
DIMS_M = (3.970, 0.376, 1.550)      # X: the mound to the slamming post's front; Y: keeper staple to mound back


# ---------------------------------------------------------------------------------------------------- helpers
def clamp_uv(vals, lo=0.0, hi=1.0):
    return [min(max(v, lo), hi) for v in vals]


def u_cuts(a0, a1, u_off, tile):
    """Stations on this member's own U tile lines (U = length/tile + u_off), so no face spans more than one tile."""
    xs = {a0, a1}
    for n in range(math.floor(a0 / tile + u_off) - 1, math.ceil(a1 / tile + u_off) + 2):
        x = (n - u_off) * tile
        if a0 + 1e-6 < x < a1 - 1e-6:
            xs.add(round(x, 5))
    return sorted(xs)


def tile_cuts(x0, x1, u_off=0.0):
    """The member's own 1.2 m U tile lines, so the grain never jumps a tile inside a face."""
    return u_cuts(x0, x1, u_off, L.TILE_U_M)


def tube(rings, cap_start=False, cap_end=False):
    """Faces between consecutive rings (a ring is a list of (x, y, z) metres)."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start:
        bm.faces.new(list(reversed(vs[0])))
    if cap_end:
        bm.faces.new(vs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def loop_tube(path, section, up):
    """A closed tube along a closed path: chain links, the chain ring."""
    bm = bmesh.new()
    P = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(P):
        t = (P[(i + 1) % len(P)] - P[(i - 1) % len(P)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(t).normalized()
        rings.append([bm.verts.new(p + side * a + nrm * b) for a, b in section])
    n = len(section)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism(r, h, sides=6, taper=0.0):
    """Closed n-gon prism along +Z from z = 0 to z = h (bolt and nut heads)."""
    ring = lambda z, k: [(r * k * math.cos(2 * math.pi * i / sides), r * k * math.sin(2 * math.pi * i / sides), z)
                         for i in range(sides)]
    return tube([ring(0.0, 1.0), ring(h * 0.72, 1.0), ring(h, 1.0 - taper)], cap_start=True, cap_end=True)


def lathe_y(prof, segs, x, z):
    """A surface of revolution about the Y axis at (x, z): prof is [(radius, y)] (pins and shanks along Y)."""
    bm = kit.lathe(prof, segs)
    kit.transform(bm, Matrix.Translation((x, 0.0, z)) @ Matrix.Rotation(math.radians(-90), 4, "X"))
    return bm


def poly_round(pts, r, n=3):
    """A polyline with its corners replaced by n-point quadratic fillets (forged bends)."""
    P = [Vector(p) for p in pts]
    out = [tuple(P[0])]
    for i in range(1, len(P) - 1):
        a, v, b = P[i - 1], P[i], P[i + 1]
        da, db = v - a, b - v
        p0, p2 = v - da.normalized() * min(r, da.length * 0.45), v + db.normalized() * min(r, db.length * 0.45)
        for k in range(n + 1):
            t = k / float(n)
            out.append(tuple((1 - t) ** 2 * p0 + 2 * t * (1 - t) * v + t ** 2 * p2))
    out.append(tuple(P[-1]))
    return out


def wear(bm, k=1.0):
    """Hand-worn lumps knocked off the timber in service, so no two bars read as one extrusion."""
    for v in bm.verts:
        for (x, z, rad, dep) in DENTS:
            d2 = (v.co.x - x) ** 2 + ((v.co.z - z) * 1.7) ** 2
            if d2 < rad * rad:
                f = dep * k * (1.0 - d2 / (rad * rad)) ** 2
                v.co.z -= f
                v.co.y += f * 0.5
    return bm


# ---------------------------------------------------------------------------------------------------- UVs
def uv_timber(bm, mode, u_off=0.0, ref=(0.0, LEAF_Y)):
    """Timber UVs: U = length along the piece (X for horizontal members, Z for posts and stiles) so the grain runs
    along it, V = height above ground over GATE_H_M (mud at the bottom, bleached at the top). A face with no height to
    give (a bar's top, the top of a post) takes a slice of the region round MID_V, two-way, so it keeps UV area."""
    u0, v0, u1, v1 = L.region_rect("timber")
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        us, vs = [], []
        for l in f.loops:
            c = l.vert.co
            z_h = min(max(c.z / L.GATE_H_M, 0.0), 1.0)                 # height above ground, mud at 0
            if ax == 2:
                u, v = c.x / L.TILE_U_M, L.MID_V + (c.y - ref[1]) / L.GATE_H_M
            elif mode == "x":
                u, v = (c.y if ax == 0 else c.x) / L.TILE_U_M, z_h
            else:
                u = c.z / L.TILE_U_M
                v = L.MID_V + ((c.y - ref[1]) if ax == 0 else (c.x - ref[0])) / L.GATE_H_M
            us.append(u + u_off)
            vs.append(min(max(v, 0.0), 1.0))
        for l, u, v in zip(f.loops, us, vs):
            l[uvl].uv = (u0 + u * (u1 - u0), v0 + v * (v1 - v0))
    return bm


def uv_blade(bm, u_off=0.0):
    """Grass blades: a diagonal map low in the timber region's moss band; V rises with the blade's height."""
    u0, v0, u1, v1 = L.region_rect("timber")
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        us, vs = [], []
        for l in f.loops:
            c = l.vert.co
            us.append((c.x + 0.7 * c.y) / L.TILE_U_M + u_off)
            vs.append(0.020 + c.z * 0.26)
        for l, u, v in zip(f.loops, us, vs):
            l[uvl].uv = (u0 + u * (u1 - u0), v0 + v * (v1 - v0))
    return bm


def uv_box(bm, region, centre, u_off=0.0, v_off=0.0):
    """Box projection of one fitting about its own centre: the piece's faces keep one continuous mapping (so the
    LOD decimator holds its UV island together) and stay inside the region at any size up to a tile."""
    u0, v0, u1, v1 = L.region_rect(region)
    tile = L.MET_TILE_M if region == "metal" else L.DARK_TILE_M
    o = Vector(centre)
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        us, vs = [], []
        for l in f.loops:
            c = l.vert.co - o
            a, b = (c.y, c.z) if ax == 0 else ((c.x, c.z) if ax == 1 else (c.x, c.y))
            us.append(0.5 + a / tile[0] + u_off)
            vs.append(0.5 + b / tile[1] + v_off)
        us, vs = clamp_uv(us), clamp_uv(vs)
        for l, u, v in zip(f.loops, us, vs):
            l[uvl].uv = (u0 + u * (u1 - u0), v0 + v * (v1 - v0))
    return bm


def uv_ground(bm, cy, u_off):
    """Soil and moss round a post foot: a planar map at the very bottom of the timber region's V span."""
    u0, v0, u1, v1 = L.region_rect("timber")
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        us, vs = [], []
        for l in f.loops:
            c = l.vert.co
            us.append(c.x / L.TILE_U_M + u_off)
            vs.append(0.010 + min(max(c.y - cy + 0.30, 0.0), 0.55) * (0.22 / L.GATE_H_M))
        for l, u, v in zip(f.loops, us, vs):
            l[uvl].uv = (u0 + u * (u1 - u0), v0 + v * (v1 - v0))
    return bm


# ---------------------------------------------------------------------------------------------------- timber members
def member_x(x0, x1, y, z, t, w, u_off, r=0.006):
    """A horizontal timber member along +X, cut on the 1.2 m U tile lines so its grain never jumps a tile."""
    bm = kit.sweep([(x, y, z) for x in tile_cuts(x0, x1, u_off)], kit.rounded_rect(t, w, r, 2), up=Vector((0, 0, 1)))
    return uv_timber(wear(bm), "x", u_off, ref=(x0, y))


def member_z(z0, z1, x, y, w, t, u_off, r=0.006):
    """A vertical timber member (post, stile) along +Z: U along Z, so the grain runs up it."""
    zs = tile_cuts(z0, z1, u_off)
    bm = kit.sweep([(x, y, z) for z in zs], kit.rounded_rect(w, t, r, 2), up=Vector((0, 1, 0)))
    return uv_timber(wear(bm), "z", u_off, ref=(x, y))


def post(x, y, size, top, u_off):
    """A sawn post: rounded arrises, cut on the tile line, with a chamfered (rain-shedding) top."""
    sec = kit.rounded_rect(size, size, 0.008, 2)
    zs = tile_cuts(0.0, top - 0.050, u_off) + [top - 0.050, top - 0.018, top]
    ks = [1.0] * (len(zs) - 2) + [0.972, 0.938]
    rings = [[(x + a * k, y + b * k, z) for a, b in sec] for z, k in zip(zs, ks)]
    return uv_timber(wear(tube(rings, cap_start=True, cap_end=True), 0.5), "z", u_off, ref=(x, y))


def mound(cx, cy, rx, ry, h, u_off):
    """A lumpy soil and moss mound round a post foot: hides the ground line and carries the moss."""
    rings = []
    for k, kr in ((0.0, 1.0), (0.42, 0.78), (0.76, 0.46), (1.0, 0.16)):
        ring = []
        for i in range(16):
            th = 2 * math.pi * i / 16
            j = 0.85 + 0.22 * (0.5 + 0.5 * math.sin(th * 3.0 + 1.3) * math.sin(th * 5.0 + 0.7) + 0.3 * math.sin(th * 7.0))
            ring.append((cx + rx * kr * j * math.cos(th), cy + ry * kr * j * math.sin(th), h * k))
        rings.append(ring)
    return uv_ground(tube(rings, cap_start=True, cap_end=True), cy, u_off)


def grass(cx, cy, count, seed):
    """A few thin grass blades at a mound's edge (single-sided quads, on the moss band of the timber region)."""
    bm = bmesh.new()
    for i in range(count):
        a = math.pi * (1.05 + 0.90 * (i + 0.5) / count)
        rx, ry = 0.080 + 0.018 * ((i * seed) % 3), 0.150 + 0.022 * ((i * 2 * seed) % 3)
        bx, by = cx + rx * math.cos(a), cy + ry * math.sin(a)
        hgt = 0.070 + 0.025 * ((i + seed) % 3)
        lean = 0.02 + 0.015 * ((i * 3 + seed) % 3)
        side = Vector((math.cos(a + math.pi / 2), math.sin(a + math.pi / 2), 0.0)) * 0.006
        v0 = bm.verts.new((bx - side.x, by - side.y, 0.0))
        v1 = bm.verts.new((bx + side.x, by + side.y, 0.0))
        tip = Vector((bx + math.cos(a) * lean, by + math.sin(a) * lean, hgt))
        v2 = bm.verts.new(tuple(tip))
        v3 = bm.verts.new(tuple(tip + side * 0.3))
        bm.faces.new((v0, v1, v3, v2))
    return uv_blade(bm, 0.41)


# ---------------------------------------------------------------------------------------------------- fittings
def bolt(x, y_face, z, r=0.011, h=0.011, out=-1.0):
    """A hex bolt head (out = -1: proud of a face whose normal points -Y) or a nut (out = +1)."""
    bm = prism(r, h, 6, taper=0.30)
    kit.transform(bm, Matrix.Translation((x, y_face, z)) @ Matrix.Rotation(math.radians(-90 * out), 4, "X"))
    y_c = y_face - 0.5 * h * out
    return uv_box(bm, "dark", (x, y_c, z), 0.31 * ((x * 7.3) % 1.0) - 0.15, 0.27 * ((z * 5.1) % 1.0) - 0.13)


def strap(x0, x1, z, y, u_off):
    """A flat hinge strap: a 60 x 6 mm plate lying on the leaf's face, tapering to its far end, cut on tile lines."""
    bm = kit.sweep([(x, y, z) for x in (x0, x1)], kit.rounded_rect(STRAP_T, STRAP_W, 0.002, 1), up=Vector((0, 0, 1)))
    for v in bm.verts:                                    # the maker's taper on the far end
        t = max(0.0, (v.co.x - (x1 - 0.11)) / 0.11)
        v.co.z = z + (v.co.z - z) * (1.0 - 0.40 * t)
    return uv_box(bm, "metal", ((x0 + x1) / 2.0, y, z), u_off - 0.15, 0.02)


def hook(z_pin, flip, u_off):
    """The hook of a hook-and-band hinge: a 50 x 6 mm plate curled 240 degrees round the pin's 22 mm mid radius."""
    a0, a1 = (28.0, -212.0) if flip else (-28.0, 212.0)
    bm = kit.sweep(kit.arc((X_PIN, 0.0, z_pin), HOOK_R, a0, a1, 13, plane="xz"),
                   kit.rounded_rect(HOOK_T, HOOK_W, 0.0015, 1), up=Vector((0, 1, 0)))
    kit.transform(bm, Matrix.Translation((0.0, -0.147, 0.0)))
    return uv_box(bm, "metal", (X_PIN, -0.147, z_pin), u_off - 0.15, 0.10)


def pin(z_pin, u_off):
    """A 20 mm hinge pin driven into the hanging post's front face: domed tip, shank and a forged collar."""
    return uv_box(lathe_y(PIN_PROF, 10, X_PIN, z_pin), "metal", (X_PIN, 0.5 * (PIN_PROF[0][1] + PIN_PROF[-1][1]), z_pin),
                  u_off - 0.15, 0.16)


def latch():
    """The latch bar, its bracket plate, the pivot pin, the lifting tab and the bracket's bolts."""
    bm = kit.sweep([(x, LATCH_Y, LATCH_Z) for x in (LATCH_X0, LATCH_X1)],
                   kit.rounded_rect(0.010, 0.055, 0.003, 1), up=Vector((0, 0, 1)))
    out = [uv_box(bm, "metal", ((LATCH_X0 + LATCH_X1) / 2.0, LATCH_Y, LATCH_Z), 0.11, -0.04)]
    plate = kit.box((0.090, 0.010, 0.100), (3.360, -0.155, LATCH_Z), bevel=0.002)
    out.append(uv_box(plate, "metal", (3.360, -0.155, LATCH_Z), -0.06, 0.06))
    out.append(uv_box(lathe_y(((0.000, -0.174), (0.0085, -0.170), (0.0075, -0.166), (0.0075, -0.150), (0.000, -0.149)),
                              8, 3.360, LATCH_Z), "dark", (3.360, -0.162, LATCH_Z), -0.09, 0.02))
    tab = kit.box((0.028, 0.008, 0.050), (LATCH_X0 + 0.045, LATCH_Y, LATCH_Z + 0.048), bevel=0.003)
    out.append(uv_box(tab, "metal", (LATCH_X0 + 0.045, LATCH_Y, LATCH_Z + 0.048), 0.04, 0.12))
    for x in (3.325, 3.395):
        for dz in (0.040, -0.040):
            out.append(bolt(x, -0.160, LATCH_Z + dz, r=0.009, h=0.009))
    return out


def keeper():
    """The forged staple keeper on the slamming post: a 14 mm bar standing off the face with a throat the latch bar's
    end sits in, on a bolted plate."""
    pts = [(KEEPER_X, KEEPER_Y0, 0.960), (KEEPER_X, KEEPER_Y1, 0.960), (KEEPER_X, KEEPER_Y1, 1.062),
           (KEEPER_X, KEEPER_Y0, 1.062)]
    bm = kit.sweep(poly_round(pts, 0.028, 3), kit.circle(0.0072, 6), up=Vector((1, 0, 0)))
    out = [uv_box(bm, "metal", (KEEPER_X, 0.5 * (KEEPER_Y0 + KEEPER_Y1), 1.011), -0.13, 0.08)]
    plate = kit.box((0.045, 0.010, 0.090), (KEEPER_X, -0.080, 1.011), bevel=0.002)
    out.append(uv_box(plate, "metal", (KEEPER_X, -0.080, 1.011), 0.02, 0.14))
    for z in (0.975, 1.047):
        out.append(bolt(KEEPER_X, -0.085, z, r=0.009, h=0.009))
    return out


def chain_ring():
    """The chain's ring hung on a stub through a bolted plate on the slamming post's front face."""
    out = []
    plate = kit.box((0.050, 0.010, 0.055), (KEEPER_X, -0.080, CHAIN_TOP), bevel=0.002)
    out.append(uv_box(plate, "metal", (KEEPER_X, -0.080, CHAIN_TOP), 0.07, 0.05))
    stub = prism(0.0075, 0.055, 6)
    kit.transform(stub, Matrix.Translation((KEEPER_X, -0.085, CHAIN_TOP)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    out.append(uv_box(stub, "metal", (KEEPER_X, -0.1125, CHAIN_TOP), -0.05, 0.10))
    ring = loop_tube(kit.arc((KEEPER_X, -0.105, CHAIN_TOP - 0.036), 0.036, 0, 360, 9, plane="yz"),
                     kit.circle(0.0055, 5), up=Vector((1, 0, 0)))
    for i, v in enumerate(ring.verts):                   # a hand-forged ring: never quite round
        v.co.x += 0.0022 * math.sin(i * 2.1)
    out.append(uv_box(ring, "metal", (KEEPER_X, -0.105, CHAIN_TOP - 0.036), -0.12, -0.02))
    for z in (CHAIN_TOP + 0.030, CHAIN_TOP - 0.030):
        out.append(bolt(KEEPER_X, -0.085, z, r=0.008, h=0.008))
    return out


def link(centre, plane="xz", length=0.058, width=0.036, wire=0.004, arc=1.0):
    """One chain link: a stadium of wire; arc < 1 leaves it open (the chain's end hook)."""
    r = width / 2.0
    hz = max(length / 2.0 - r, 0.0006)
    pts = [(r * math.cos(math.pi * k / 4), hz + r * math.sin(math.pi * k / 4)) for k in range(5)]
    pts += [(r * math.cos(math.pi + math.pi * k / 4), -hz + r * math.sin(math.pi + math.pi * k / 4)) for k in range(1, 4)]
    if arc < 1.0:
        pts = pts[: max(4, int(round(len(pts) * arc)))]
    P = [(centre[0] + a, centre[1], centre[2] + b) for a, b in pts] if plane == "xz" else \
        [(centre[0], centre[1] + a, centre[2] + b) for a, b in pts]
    up = Vector((0, 1, 0)) if plane == "xz" else Vector((1, 0, 0))
    bm = loop_tube(P, kit.circle(wire, 5), up) if arc >= 1.0 else kit.sweep(P, kit.circle(wire, 5), up=up)
    return uv_box(bm, "metal", centre, 0.02 * ((centre[2] * 13.7) % 1.0) - 0.01, 0.08 * ((centre[2] * 7.1) % 1.0) - 0.04)


def chain():
    """The holding-open chain: nine links hanging off the ring, the last left open as the hook."""
    out = []
    z0, y0 = CHAIN_TOP - 0.090, -0.105
    for k in range(9):
        out.append(link((KEEPER_X, y0 - 0.005 * k, z0 - k * 0.0355), "xz" if k % 2 == 0 else "yz",
                        arc=(1.0 if k < 8 else 0.70)))
    return out


def leaf_hook():
    """The hook on the leaf's head stile that the chain is dropped over, on a bolted plate."""
    x, y = 3.610, LEAF_Y - 0.020 - 0.005
    out = [uv_box(kit.box((0.055, 0.010, 0.050), (x, y, 0.985), bevel=0.002), "metal", (x, y, 0.985), -0.04, 0.07)]
    path = kit.arc((x - 0.020, y - 0.004, 0.952), 0.021, -40, 215, 11, plane="xz")
    out.append(uv_box(kit.sweep(path, kit.circle(0.0055, 5), up=Vector((0, 1, 0))), "metal",
                      (x - 0.020, y - 0.004, 0.952), 0.05, -0.05))
    for z in (0.965, 1.005):
        out.append(bolt(x, y - 0.005, z, r=0.008, h=0.008))
    return out


# ---------------------------------------------------------------------------------------------------- assembly
def geometry():
    leaf = kit.Part("M_Road_FieldGate_Leaf_LOD0")
    for i, z in enumerate(BAR_Z):
        leaf.add(member_x(LEAF_X0, LEAF_X1, LEAF_Y, z, BAR_T, BAR_W, 0.05 + 0.113 * i))
    leaf.add(member_z(Z_LEAF0, Z_LEAF1, LEAF_X0 + STILE_W / 2.0, LEAF_Y, STILE_W, STILE_T, 0.31))
    leaf.add(member_z(Z_LEAF0, Z_LEAF1, LEAF_X1 - STILE_W / 2.0, LEAF_Y, STILE_W, STILE_T, 0.57))
    leaf.add(member_z(Z_LEAF0, Z_LEAF1, 1.900, LEAF_Y, MID_W, STILE_T, 0.72))
    bx = tile_cuts(0.155, 3.645, 0.86)
    brace = kit.sweep([(x, LEAF_Y, 0.245 + (x - 0.155) * 0.2493) for x in bx],
                      kit.rounded_rect(0.080, BAR_T, 0.006, 2), up=Vector((0, 1, 0)))
    leaf.add(uv_timber(wear(brace), "x", 0.86, ref=(0.155, LEAF_Y)))
    for i, z_pin in enumerate(Z_PINS):
        leaf.add(strap(0.085, STRAP_X1, z_pin, STRAP_Y, 0.13 + 0.22 * i))
        leaf.add(hook(z_pin, bool(i), 0.05 + 0.30 * i))
        for x in (0.145, 0.300, 0.450, 0.600):
            leaf.add(bolt(x, STRAP_Y - STRAP_T / 2.0 - 0.0005, z_pin, r=0.011, h=0.010))
            leaf.add(bolt(x, LEAF_Y + 0.020 + 0.0005, z_pin, r=0.010, h=0.009, out=1.0))
    for bm in latch() + leaf_hook():
        leaf.add(bm)
    body = kit.Part("M_Road_FieldGate_LOD0")
    body.add(post(0.0, 0.0, HPOST, HPOST_TOP, 0.0))
    body.add(post(SLAM_X, 0.0, SPOST, SPOST_TOP, 0.66))
    for i, (cx, cy, rx, ry, h) in enumerate(MOUND):
        body.add(mound(cx, cy, rx, ry, h, 0.12 + 0.37 * i))
        body.add(grass(cx, cy, 5, 3 + i))
    for i, z_pin in enumerate(Z_PINS):
        body.add(pin(z_pin, 0.02 + 0.31 * i))
    for bm in keeper() + chain_ring() + chain():
        body.add(bm)
    mat = material()
    parts = {"Body": body.finish(mat, sharp_deg=42.0), "Leaf": leaf.finish(mat, sharp_deg=42.0)}
    col = kit.col_object("M_Road_FieldGate_COL", [
        kit.box((HPOST, HPOST, HPOST_TOP), (0.0, 0.0, HPOST_TOP / 2.0)),
        kit.box((SPOST, SPOST, SPOST_TOP), (SLAM_X, 0.0, SPOST_TOP / 2.0)),
    ])
    col_leaf = kit.col_object("M_Road_FieldGate_Leaf_COL", [
        kit.box((LEAF_X1 - 0.085, 0.075, Z_LEAF1 - Z_LEAF0),
                ((LEAF_X1 + 0.085) / 2.0, LEAF_Y - 0.013, (Z_LEAF0 + Z_LEAF1) / 2.0)),
    ])
    att = [kit.empty("ATT_Base", (0, 0, 0)),
           kit.empty("ATT_Hinge", (X_PIN, -0.145, (Z_PINS[0] + Z_PINS[1]) / 2.0)),
           kit.empty("ATT_Latch", (KEEPER_X, -0.150, LATCH_Z), (0, 0, math.radians(-90))),
           kit.empty("ATT_Chain", (KEEPER_X, -0.105, CHAIN_TOP - 0.36))]
    return parts, (col, col_leaf), att


def material():
    """Preview material on the trim set (turntable replaces it with the spec's maps from the texture folder)."""
    name = "MI_FieldGate_Timber"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    for cand in (os.path.join(kit.TEX, "M_Road_FieldGate"),
                 os.path.join(kit.GAME, "build/prod/M_Road_FieldGate/textures/M_Road_FieldGate")):
        if os.path.isdir(cand):
            for kind, inp, colour in (("ALB", "Base Color", True), ("RGH", "Roughness", False), ("MET", "Metallic", False)):
                p = os.path.join(cand, "T_FieldGate_Timber_%s.png" % kind)
                if not os.path.exists(p):
                    continue
                n = nt.nodes.new("ShaderNodeTexImage")
                n.image = bpy.data.images.load(p, check_existing=True)
                if not colour:
                    n.image.colorspace_settings.name = "Non-Color"
                nt.links.new(n.outputs["Color"], bsdf.inputs[inp])
            return mat
    return mat


def build():
    parts, cols, att = geometry()
    return {
        "name": "M_Road_FieldGate",
        "budget": "large_prop",
        "tris": 6000,                    # docs/12 2.4: 1,000 to 6,000 per 5 m piece
        "tier": "standard",
        "dims_m": DIMS_M,
        "size_note": None,
        "origin": "free",                # the hanging post's centre sits on the origin, on the ground
        "sets": [{"name": "FieldGate", "set": "Timber", "size": 1024, "wet": True}],
        "meshes": [{"object": o, "set": "Timber"} for o in parts.values()] + [{"object": c} for c in cols],
        "attachments": att,
        "tiling": True,
        "closeups": [
            {"name": "hinge_bottom", "target": [X_PIN * S, -0.14 * S, Z_PINS[0] * S], "dist": 1.3 * S, "az": 14, "el": 6},
            {"name": "hinge_top", "target": [X_PIN * S, -0.14 * S, Z_PINS[1] * S], "dist": 1.3 * S, "az": 14, "el": 6},
            {"name": "latch", "target": [3.70 * S, -0.17 * S, LATCH_Z * S], "dist": 1.5 * S, "az": 10, "el": 8},
            {"name": "chain", "target": [KEEPER_X * S, -0.15 * S, (CHAIN_TOP - 0.20) * S], "dist": 1.3 * S, "az": 22, "el": 8},
            {"name": "post_base", "target": [0.0, -0.06 * S, 0.13 * S], "dist": 2.2 * S, "az": 24, "el": 20},
            {"name": "bar_wear", "target": [2.2 * S, LEAF_Y * S, 0.68 * S], "dist": 1.9 * S, "az": 16, "el": 4},
        ],
    }
