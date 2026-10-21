"""R2 M_Road_DryStoneWall (docs/12 2.4, Haven Head road): a Cornish dry-stone wall, one 5 m modular section.

    python3 art/source/roads/M_Road_DryStoneWall/walltex.py            (trim set, once; no heavy slot)
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/roads/M_Road_DryStoneWall/build.py \
        --out-root build/prod/M_Road_DryStoneWall --steps build,lod,validate,export,turntable

Real dimensions (verify, art/reference/M_Road_DryStoneWall/dims.md): 1.20 m high including the coping, 0.62 m thick
at the base, 0.46 m at the bed. Two skins of split granite, six courses of rubble with staggered joints and no
mortar, through stones tying the skins together, hearting between them, and a row of coping stones standing on edge
along the top (0.30 m of the 1.20 m). Every stone is its own irregular convex block (hulled from jittered corners,
its outer face domed, about a third of them with a knocked-off corner), so nothing reads as a textured box.

The piece tiles end to end: the +X end of every module is a through-stone quoin (a stone that runs right through the
wall, a real dry-stone feature), the -X end's stones are drawn 15 mm in, so two modules placed 5 m apart lap without
sharing a plane and a run never shows a seam. The origin is on the ground at the -X end (x runs along Blender +X =
Roblox -X). ATT_Snap_Start / ATT_Snap_End are the end snap points (local -Y forward, pointing out of the piece),
ATT_Base the ground point, ATT_Vault the centre of the wall's top (a step-over point).

M_Road_DryStoneWall_EndCap_LOD0 is the terminal cap (a big cope stone and two wedges on the quoin): keep it on the
last piece of a run, or leave it on every piece, where it reads as a chunkier coping stone every 5 m.

The game road kit (kit.py) supplies Part / box / transforms / empties / the collision proxy; the trim set is
art/source/roads/M_Road_DryStoneWall/walltex.py on layout.py, in M_Road_CrashBarrier's style.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROADS = os.path.dirname(HERE)
sys.path.insert(0, ROADS)
sys.path.insert(0, HERE)
import kit  # noqa: E402
import layout as L  # noqa: E402

S = kit.S

# ---------------------------------------------------------------------------------------------------- real sizes (m)
L_MOD = 5.00            # module length between snap points
OVER = 0.015            # the -X end's stones stick this far past the snap point, so modules lap
X0, X1 = -OVER, L_MOD + OVER
HALF_Y = 0.310          # 0.62 m thick at the base
W0, W1 = 0.285, 0.212   # outer face half-width at the ground and at the cope bed (batter)
Z_BED = 0.900           # top of the wall body, where the coping is bedded
Z_TOP = 1.200           # top of the coping
COPE_H = 0.300
COPE_T = (0.135, 0.180)  # coping stone thickness (Y)
COPE_L = (0.210, 0.350)  # coping stone length (X)
SKIN = (0.130, 0.195)   # stone depth into the wall
COURSES = ((0.000, 0.170), (0.170, 0.335), (0.335, 0.490), (0.490, 0.635), (0.635, 0.770), (0.770, Z_BED))
JOINT_V = (0.006, 0.015)     # vertical joint between two stones in a course
JOINT_H = (0.006, 0.013)     # bed joint between courses
THROUGH_X = (0.06, 1.66, 3.30, 4.94)   # through stones (full thickness) along the module; the last is the quoin
THROUGH_L = 0.34
JIT = 0.013             # corner jitter (m) - small, so the joints stay open and read
DIMS_M = (X1 - X0, 2 * HALF_Y, Z_TOP)

U_OFF_JOINT = 0.12      # joint cell: U where the mouth of a joint starts
MID_U = 0.42            # U / V a face with no length to give (a top or bottom) takes its patch about
MID_V = 0.45


def half_w(z):
    """Outer face half-width (m) at height z: the wall batters in as it rises."""
    return W0 + (W1 - W0) * min(max(z / Z_BED, 0.0), 1.0)


# ---------------------------------------------------------------------------------------------------- blocks
def hull(points):
    """Convex hull of a point cloud, triangulated, as a bmesh."""
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=list(bm.verts))
    bmesh.ops.delete(bm, geom=list({g for g in res["geom_interior"] + res["geom_unused"]
                                    if isinstance(g, bmesh.types.BMVert)}), context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def block(size, rng, outer=-1, bulge=0.010, top_bulge=0.0, taper=0.0, chip=0.0, jit=JIT):
    """A split granite block centred on the origin, its outer face (-Y when outer = -1) domed by `bulge` metres and
    its corners jittered: the hull of the 8 corners plus the pushed face centres. `taper` shrinks the outer face into
    a wedge, `chip` knocks a corner off."""
    l, d, h = size
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                p = [sx * l / 2.0, sy * d / 2.0, sz * h / 2.0]
                if sy == outer and taper:
                    p[0] *= taper
                    p[2] *= taper
                pts.append(p)
    if chip:
        i = int(rng.integers(0, 8))
        pts[i][0] *= 1.0 - 0.30 * chip
        pts[i][2] *= 1.0 - 0.22 * chip
        pts[i][1] *= 1.0 - 0.14 * chip
    for p in pts:
        p[0] += rng.uniform(-jit, jit)
        p[1] += rng.uniform(-jit, jit) * 1.4
        p[2] += rng.uniform(-jit, jit)
    if bulge:
        b = bulge * rng.uniform(0.5, 1.0)
        pts.append([0.0, outer * (d / 2.0 + b), 0.0])
        pts.append([rng.uniform(-0.22, 0.22) * l, outer * (d / 2.0 + b * rng.uniform(0.30, 0.75)),
                    rng.uniform(-0.30, 0.30) * h])
    if top_bulge:
        pts.append([0.0, 0.0, h / 2.0 + top_bulge * rng.uniform(0.4, 1.0)])
    return hull(pts)


def lump(size, rng):
    """A moss lump: a flattened blob, hulled from jittered points on an ellipsoid."""
    pts = []
    for _ in range(7):
        a, b = rng.uniform(0, 2 * math.pi), rng.uniform(-1, 1)
        r = math.sqrt(max(0.0, 1 - b * b)) * rng.uniform(0.55, 1.0)
        pts.append([size[0] * r * math.cos(a) / 2.0, size[1] * r * math.sin(a) / 2.0, size[2] * b * 0.5])
    pts.append([0.0, 0.0, size[2] * 0.5])
    return hull(pts)


def tube(rings, cap_start=True, cap_end=True):
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


# ---------------------------------------------------------------------------------------------------- UVs
def uv_faces(bm, cell, off, ref, out_axis=1, face_at=0.0, top_cell=None):
    """UVs a block, already in its final place, into the trim cells. `cell` takes the outer faces (out_axis 1: the
    +-Y faces, `face_at` the y of the wall's face; out_axis 0: the +-X faces, `face_at` the x of the run's end), the
    joint cell takes the sides of the joints (U = depth back from the face) and `top_cell`, when given, the up-facing
    faces. ref: (x_ref, z_ref) metres; off: (u, v) offset inside `cell`."""
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    top = top_cell or "joint"
    x_ref, z_ref = ref
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        if ax == out_axis:
            c, um, vm = cell, *L.CELL_M[cell]
            u0, v0, u1, v1 = L.region_rect(cell)
            vr, ou, ov = L.V_REF[cell], off[0], off[1]
        elif ax == 2 and f.normal.z > 0.4:
            c, um, vm = top, *L.CELL_M[top]
            u0, v0, u1, v1 = L.region_rect(top)
            vr, ou, ov = L.V_REF[top], 0.0, 0.0
        else:
            c, um, vm = "joint", *L.CELL_M["joint"]
            u0, v0, u1, v1 = L.region_rect("joint")
            vr, ou, ov = L.V_REF["joint"], 0.0, 0.0
        for lo in f.loops:
            v = lo.vert.co
            if ax == 2:
                # a top or bottom face: a local patch about the face's own centre, so nothing ever clamps to a line
                ctr = f.calc_center_median()
                uu = MID_U + (v.x - ctr.x) / um + ou
                vv = MID_V + (v.y - ctr.y) / vm + ov
            elif c != "joint":
                # the cell's own surface: a box projection at the cell's scale
                if out_axis == 1:
                    uu = (v.x - x_ref) / um + ou
                else:
                    uu = (v.y + HALF_Y) / um + ou
                vv = (v.z - vr) / vm + ov
            else:
                # a joint: U runs back from the wall's face, so a joint is gritty at its mouth and black inside
                uu = abs((v.y if out_axis == 1 else v.x) - face_at) / um + U_OFF_JOINT
                vv = (v.z - vr) / vm
            lo[uvl].uv = (u0 + min(max(uu, 0.0), 1.0) * (u1 - u0), v0 + min(max(vv, 0.0), 1.0) * (v1 - v0))
    return bm


# ---------------------------------------------------------------------------------------------------- the wall
def stone_cell(rng, z_mid):
    """Which cell a stone's face takes: most are plain granite, some carry a lichen community, the low shaded ones
    moss."""
    r = rng.random()
    if r < (0.13 if z_mid > 0.30 else 0.07):
        return "lichen"
    if r < (0.18 if z_mid > 0.30 else 0.15):
        return "moss"
    return "wall"


def course(z0, z1, skin, rng, joints):
    """One course of rubble on one skin: lengths, joints, projection, depth and UV cell per stone, placed and
    returned as bmeshes."""
    out = []
    x = X0
    first = True
    while x < X1 - 0.12:
        l = rng.uniform(0.19, 0.40) * (1.0 - 0.24 * z0 / Z_BED)
        if first:
            l = max(l, 0.30)
        if x + l > X1 - 0.24:                        # the last stone takes the rest of the course
            l = X1 - x
            if l < 0.17 and out:
                break
        wav = 0.013 * math.sin(x * 1.7 + z0 * 6.0) + rng.uniform(-0.011, 0.011)   # wavy, uneven courses
        z0s = z0 + rng.uniform(0.0, 0.45 * JOINT_H[1]) + wav
        z1s = z1 - rng.uniform(0.45 * JOINT_H[1], JOINT_H[1]) + wav * 0.6
        h = z1s - z0s
        d = rng.uniform(*SKIN)
        z_mid = (z0s + z1s) / 2.0
        y_face = skin * (half_w(z_mid) + rng.uniform(-0.018, 0.024))
        cell = stone_cell(rng, z_mid)
        um = L.CELL_M[cell][0]
        off = (rng.uniform(0.0, max(0.0, 1.0 - l / um)), 0.0)
        bm = block((l, d, h), rng, outer=-1, bulge=rng.uniform(0.014, 0.034), taper=rng.uniform(0.62, 1.0),
                   chip=(rng.uniform(0.30, 0.95) if rng.random() < 0.5 else 0.0))
        flip = Matrix.Rotation(math.pi, 4, "Z") if skin > 0 else Matrix.Identity(4)
        spin = (Matrix.Rotation(rng.uniform(-0.050, 0.050), 4, "Y")
                @ Matrix.Rotation(rng.uniform(-0.060, 0.060), 4, "Z")
                @ Matrix.Rotation(rng.uniform(-0.022, 0.022), 4, "X"))
        cx = x + l / 2.0
        cy = y_face - skin * d / 2.0
        kit.transform(bm, Matrix.Translation((cx, cy, z_mid)) @ spin @ flip)
        out.append(uv_faces(bm, cell, off, (x, 0.0), out_axis=1, face_at=y_face))
        joints.append((x, x + l, z0s, z1s, skin, y_face))
        x += l + rng.uniform(*JOINT_V)
        first = False
    return out


def through_stones(rng, joints):
    """The through stones: one block right through the wall every 1.65 m, the last one the +X quoin (the finished end
    of a run). They are what a real dry-stone wall is tied together with, and they give the module its end."""
    out = []
    for i, xt in enumerate(THROUGH_X):
        z0, z1 = COURSES[2 if i % 2 else 1]
        h = z1 - z0
        z_mid = (z0 + z1) / 2.0
        d = 2 * half_w(z_mid) + 0.020
        cx = xt if i < len(THROUGH_X) - 1 else X1 - THROUGH_L / 2.0
        bm = block((THROUGH_L, d, h), rng, outer=-1, bulge=0.012, taper=rng.uniform(0.88, 1.0),
                   chip=(0.5 if rng.random() < 0.4 else 0.0))
        cell = "lichen" if rng.random() < 0.30 else "wall"
        um = L.CELL_M[cell][0]
        off = (rng.uniform(0.0, max(0.0, 1.0 - THROUGH_L / um)), 0.0)
        kit.transform(bm, Matrix.Translation((cx, 0.0, z_mid)))
        out.append(uv_faces(bm, cell, off, (cx - THROUGH_L / 2.0, 0.0), out_axis=1, face_at=-half_w(z_mid)))
        for skin in (-1, 1):
            joints.append((cx - THROUGH_L / 2.0, cx + THROUGH_L / 2.0, z0, z1, skin, skin * half_w(z_mid)))
    return out


def hearting():
    """The hearting: the rubble core between the two skins, a tapered prism that blocks every joint from behind."""
    rings = []
    for z in [c[0] for c in COURSES] + [Z_BED]:
        hw = max(0.02, half_w(z) - SKIN[0] + 0.010)
        rings.append([(X0, -hw, z), (X1, -hw, z), (X1, hw, z), (X0, hw, z)])
    return uv_faces(tube(rings), "joint", (0.0, 0.0), (0.0, 0.0), out_axis=1, face_at=0.0)


def cope(rng):
    """The coping: stones standing on edge along the wall's top, leaning a little, uneven, with mossy joints."""
    out = []
    x = X0
    while x < X1 - 0.10:
        l = rng.uniform(*COPE_L)
        if x + l > X1 - 0.10:
            l = X1 - x
            if l < 0.15 and out:
                break
        t = rng.uniform(*COPE_T)
        h = COPE_H * rng.uniform(0.90, 1.06)
        bm = block((l, t, h), rng, outer=-1, bulge=rng.uniform(0.010, 0.026), top_bulge=rng.uniform(0.006, 0.018),
                   taper=rng.uniform(0.78, 1.0), chip=(rng.uniform(0.35, 0.95) if rng.random() < 0.55 else 0.0),
                   jit=0.010)
        cx = x + l / 2.0
        cy = rng.uniform(-0.024, 0.024)
        cz = Z_BED - 0.040 + h / 2.0 + rng.uniform(-0.012, 0.006)
        spin = (Matrix.Rotation(rng.uniform(-0.075, 0.075), 4, "X")
                @ Matrix.Rotation(rng.uniform(-0.055, 0.055), 4, "Z"))
        cell = "cope" if rng.random() < 0.70 else ("lichen" if rng.random() < 0.5 else "moss")
        um = L.CELL_M[cell][0]
        off = (rng.uniform(0.0, max(0.0, 1.0 - l / um)), 0.0)
        kit.transform(bm, Matrix.Translation((cx, cy, cz)) @ spin)
        out.append(uv_faces(bm, cell, off, (cx - l / 2.0, 0.0), out_axis=1, face_at=cy - t / 2.0, top_cell="cope"))
        x += l + rng.uniform(0.008, 0.026)
    return out


def moss(rng, joints):
    """Moss lumps in the joints and along the foot, and a little on the cope bed: the wall's damp corners."""
    out = []
    for (xa, xb, z0, z1, skin, y_face) in joints:
        if rng.random() > 0.30:
            continue
        z = z0 + rng.uniform(0.15, 0.85) * (z1 - z0)
        s = rng.uniform(0.045, 0.115)
        bm = lump((s * rng.uniform(1.2, 2.0), s, s * rng.uniform(0.5, 0.9)), rng)
        y = y_face - skin * 0.030
        bm = uv_faces(bm, "moss", (rng.uniform(0.15, 0.70), rng.uniform(0.05, 0.80)), (0.0, 0.0), out_axis=1,
                      face_at=y)
        kit.transform(bm, Matrix.Translation(((xa + xb) / 2.0 + rng.uniform(-0.02, 0.02), y, z)))
        out.append(bm)
    for _ in range(7):                              # a little moss on the cope bed, either side of the coping
        s = rng.uniform(0.05, 0.12)
        bm = lump((s * rng.uniform(1.4, 2.2), s * rng.uniform(0.8, 1.4), s * 0.6), rng)
        y = rng.choice([-1.0, 1.0]) * rng.uniform(0.12, 0.20)
        bm = uv_faces(bm, "moss", (rng.uniform(0.15, 0.70), rng.uniform(0.05, 0.80)), (0.0, 0.0), out_axis=1,
                      face_at=y)
        kit.transform(bm, Matrix.Translation((rng.uniform(X0 + 0.2, X1 - 0.2), y, Z_BED - 0.006)))
        out.append(bm)
    return out


def grass_tuft(rng, x, side):
    """A tuft of grass blades at the wall's foot, growing out of the joint it sits in."""
    bm = bmesh.new()
    base_y = side * (half_w(0.02) + 0.004)
    for _ in range(int(rng.integers(6, 10))):
        h = rng.uniform(0.13, 0.30)
        w = rng.uniform(0.006, 0.013)
        yaw = rng.uniform(-1.0, 1.0)
        lean = rng.uniform(0.05, 0.28) * side
        bx = x + rng.uniform(-0.05, 0.05)
        by = base_y - side * rng.uniform(0.0, 0.03)
        rings = []
        for t, kb in ((0.0, 0.0), (0.55, 0.5), (1.0, 1.0)):
            ww = w * (1.0 - 0.75 * t)
            dz = h * t
            dy = lean * h * kb
            dx = math.sin(yaw) * h * kb * rng.uniform(0.25, 0.55)
            rings.append([(bx - ww / 2.0 + dx, by + dy, dz), (bx + ww / 2.0 + dx, by + dy, dz)])
        vs = [[bm.verts.new(p) for p in r] for r in rings]
        for a, b in zip(vs, vs[1:]):
            bm.faces.new((a[0], a[1], b[1], b[0]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    uvl = bm.loops.layers.uv.verify()
    u0, v0, u1, v1 = L.region_rect("grass")
    um = L.CELL_M["grass"][0]
    off = rng.uniform(0.0, 0.72)
    for f in bm.faces:
        for lo in f.loops:
            c = lo.vert.co
            uu = off + (c.x - x + 0.06) / um
            vv = c.z / L.GRASS_V_M
            lo[uvl].uv = (u0 + min(max(uu, 0.0), 1.0) * (u1 - u0), v0 + min(max(vv, 0.0), 1.0) * (v1 - v0))
    return bm


def end_cap(rng):
    """The terminal cap: a big cope stone standing on the quoin's top plus two wedges under it. Keep it on the last
    piece of a run (or on every piece: it reads as a chunky coping stone every 5 m)."""
    out = []
    x_out = X1                                    # the cap's outer face, at the run's end
    rot = Matrix.Rotation(math.radians(-90), 4, "Z")      # the block's domed -Y face turns to face +X
    bm = block((2 * HALF_Y - 0.02, 0.34, 0.34), rng, outer=-1, bulge=0.012, top_bulge=0.010, taper=0.86, chip=0.5,
               jit=0.010)
    kit.transform(bm, Matrix.Translation((x_out - 0.17, 0.0, Z_BED + 0.125)) @ Matrix.Rotation(-0.05, 4, "X") @ rot)
    out.append(uv_faces(bm, "cope", (rng.uniform(0.0, 0.20), 0.0), (0.0, 0.0), out_axis=0, face_at=x_out))
    for (dy, dz, sx) in ((-0.13, Z_BED + 0.040, 0.26), (0.13, Z_BED + 0.048, 0.24)):
        bm = block((0.30, sx, 0.15), rng, outer=-1, bulge=0.010, chip=0.4, jit=0.010)
        kit.transform(bm, Matrix.Translation((x_out - 0.15, dy, dz)) @ rot)
        out.append(uv_faces(bm, "wall", (rng.uniform(0.0, 0.55), 0.0), (0.0, 0.0), out_axis=0, face_at=x_out))
    return out


def fit(bm):
    """Trims a block to the module's own box: stones, coping and grass are drawn a few mm proud, and this keeps the
    piece's real size exact (the same thing a mason does with the wall's face line)."""
    for v in bm.verts:
        v.co.x = min(max(v.co.x, X0), X1)
        v.co.y = min(max(v.co.y, -HALF_Y), HALF_Y)
        v.co.z = min(max(v.co.z, 0.0), Z_TOP)
    return bm


def geometry():
    body = kit.Part("M_Road_DryStoneWall_LOD0")
    rng = np.random.default_rng(20261019)
    joints = []
    for skin in (-1, 1):
        for (z0, z1) in COURSES:
            for bm in course(z0, z1, skin, rng, joints):
                body.add(fit(bm))
    for bm in through_stones(rng, joints):
        body.add(fit(bm))
    body.add(fit(hearting()))
    for bm in cope(rng):
        body.add(fit(bm))
    for bm in moss(rng, joints):
        body.add(fit(bm))
    foot = [j for j in joints if j[2] < 0.02]
    for i, (xa, xb, z0, z1, skin, y_face) in enumerate(foot):
        if i % 2 == 0 and rng.random() < 0.85:
            body.add(fit(grass_tuft(rng, (xa + xb) / 2.0, skin)))
    cap = kit.Part("M_Road_DryStoneWall_EndCap_LOD0")
    for bm in end_cap(rng):
        cap.add(fit(bm))
    mat = material()
    parts = {"Body": body.finish(mat, sharp_deg=34.0), "EndCap": cap.finish(mat, sharp_deg=34.0)}
    col = kit.col_object("M_Road_DryStoneWall_COL", [
        kit.box((X1 - X0, 2 * HALF_Y - 0.02, Z_TOP - 0.02), ((X0 + X1) / 2.0, 0.0, (Z_TOP - 0.02) / 2.0))])
    att = [kit.empty("ATT_Snap_Start", (0, 0, 0), (0, 0, math.radians(-90))),
           kit.empty("ATT_Snap_End", (L_MOD, 0, 0), (0, 0, math.radians(90))),
           kit.empty("ATT_Base", (0, 0, 0)),
           kit.empty("ATT_Vault", (L_MOD / 2.0, 0.0, Z_TOP))]
    return parts, col, att


def material():
    """Preview material on the trim set (turntable replaces it with the spec's maps from the texture folder)."""
    name = "MI_DryStoneWall_Granite"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    for cand in (os.path.join(kit.TEX, "M_Road_DryStoneWall"),
                 os.path.join(kit.GAME, "build/prod/M_Road_DryStoneWall/textures/M_Road_DryStoneWall")):
        if os.path.isdir(cand):
            for kind, inp, colour in (("ALB", "Base Color", True), ("RGH", "Roughness", False),
                                      ("MET", "Metallic", False)):
                p = os.path.join(cand, "T_DryStoneWall_Granite_%s.png" % kind)
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
    parts, col, att = geometry()
    return {
        "name": "M_Road_DryStoneWall",
        "budget": "large_prop",
        "tris": 6000,                    # docs/12 2.4: 1,000 to 6,000 per 5 m piece
        "tier": "standard",
        "dims_m": DIMS_M,
        "size_note": None,
        "origin": "free",                # the -X end's ground point sits on the origin
        "sets": [{"name": "DryStoneWall", "set": "Granite", "size": 1024, "wet": True}],
        "meshes": [{"object": o, "set": "Granite"} for o in parts.values()] + [{"object": col}],
        "attachments": att,
        "tiling": True,
        "waivers": {
            "LOD UV layout": "collapse decimation of a wall of about 180 separate stones removes the stones it drops: "
                             "the LODs keep the LOD0 bounds (0.000 to 0.007) but lose the UV area of the stones that "
                             "are gone, and the terminal cap's 44 tris go to 10",
            "UV faces": "at LOD1 / LOD2 the collapse decimator merges the UVs of the smallest stones it removes, "
                        "leaving a few faces with no UV area (21 of 1800 at LOD1); LOD0 has none",
            "geometry": "the LOD decimator collapses the smallest stones and moss lumps to single vertices (58 loose "
                        "verts at LOD1, no faces): they are inside the wall",
        },
        "closeups": [
            {"name": "stone_face", "target": [0.9 * S, -0.30 * S, 0.52 * S], "dist": 1.7 * S, "az": 8, "el": 6},
            {"name": "cope_top", "target": [2.5 * S, 0.0, 1.06 * S], "dist": 2.6 * S, "az": 200, "el": 26},
            {"name": "foot_grass", "target": [1.7 * S, -0.28 * S, 0.13 * S], "dist": 1.5 * S, "az": 24, "el": 16},
            {"name": "moss_joint", "target": [3.3 * S, -0.30 * S, 0.26 * S], "dist": 1.3 * S, "az": 12, "el": 10},
            {"name": "end_cap", "target": [4.95 * S, 0.0, 0.62 * S], "dist": 2.4 * S, "az": 62, "el": 12},
            {"name": "wall_run", "target": [2.5 * S, 0.0, 0.60 * S], "dist": 9.0 * S, "az": 34, "el": 14},
        ],
    }
