"""Bosun, the Newfoundland (docs/12 2.9 row M_Chr_Bosun, CH6): geometry for the body, the fur cards and the harness.

Built in metres on a quadruped skeleton graph (Skin modifier + Subdivision, so every limb is a clean quad tube with
edge loops at the joints and the rest pose is a natural four-square stand, ready for RIG_Bosun in CH7), shaped by
continuous space warps (deep chest, broad skull, square deep muzzle with flews, big webbed paws), then scaled to studs
(1 m = 3 studs). Front is -Y, Z up, origin at the ground between the feet.

Meshes (one material each, UVMap only):
  M_Chr_Bosun_BodyHead / _BodyFore / _BodyHind   set Body (2048)   split so each MeshPart stays under 10,000 tris;
                                                 custom normals from the unsplit body so the cuts do not show
  M_Chr_Bosun_Harness                            set Harness (1024) Hull Orange water-rescue harness
  M_Chr_Bosun_FurFront / _FurRear                set Fur (2048, RGBA) alpha fur cards on the silhouette
Per-vertex attributes used by bake_bosun.py: flow (fur direction), long, short, bleach, nose, pad, lip, eye, eye_r,
and on the harness tape, metal, plastic, grip.
"""
import math
import random

import bmesh
import bpy
import mathutils
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

S = 3.0                      # studs per metre
NAME = "M_Chr_Bosun"
SEED = 1868                  # Newfoundland's colony charter year; any fixed seed

# ------------------------------------------------------------------ skeleton (metres): (x, y, z, radius)
SPINE = [(0, -0.43, 0.515, 0.160), (0, -0.36, 0.530, 0.180), (0, -0.28, 0.535, 0.192), (0, -0.16, 0.530, 0.198),
         (0, -0.04, 0.530, 0.192), (0, 0.08, 0.540, 0.178), (0, 0.20, 0.548, 0.166), (0, 0.32, 0.553, 0.166),
         (0, 0.42, 0.548, 0.150)]
NECK = [(0, -0.43, 0.515, 0.160), (0, -0.50, 0.600, 0.150), (0, -0.55, 0.680, 0.140), (0, -0.585, 0.750, 0.130)]
HEAD = [(0, -0.585, 0.750, 0.130), (0, -0.615, 0.800, 0.125), (0, -0.655, 0.822, 0.128), (0, -0.700, 0.822, 0.118),
        (0, -0.745, 0.805, 0.098), (0, -0.785, 0.787, 0.084), (0, -0.820, 0.777, 0.074), (0, -0.850, 0.774, 0.064),
        (0, -0.872, 0.774, 0.052)]
TAIL = [(0, 0.42, 0.548, 0.150), (0, 0.50, 0.553, 0.074), (0, 0.56, 0.500, 0.060), (0, 0.60, 0.420, 0.050),
        (0, 0.62, 0.320, 0.042), (0, 0.625, 0.225, 0.033), (0, 0.618, 0.155, 0.026), (0, 0.600, 0.112, 0.020)]


def fore(sx):
    return [(0, -0.28, 0.535, 0.192), (sx * 0.100, -0.290, 0.455, 0.088), (sx * 0.118, -0.240, 0.335, 0.066),
            (sx * 0.120, -0.248, 0.215, 0.052), (sx * 0.120, -0.252, 0.110, 0.047), (sx * 0.121, -0.268, 0.058, 0.046),
            (sx * 0.124, -0.300, 0.032, 0.050), (sx * 0.125, -0.338, 0.026, 0.043)]


def hind(sx):
    return [(0, 0.32, 0.553, 0.166), (sx * 0.100, 0.330, 0.480, 0.100), (sx * 0.128, 0.265, 0.305, 0.080),
            (sx * 0.126, 0.335, 0.215, 0.058), (sx * 0.124, 0.402, 0.132, 0.048), (sx * 0.123, 0.392, 0.058, 0.045),
            (sx * 0.124, 0.358, 0.032, 0.050), (sx * 0.125, 0.318, 0.026, 0.043)]


CHAINS = {"spine": SPINE, "neck": NECK, "head": HEAD, "tail": TAIL,
          "fl_l": fore(1), "fl_r": fore(-1), "hl_l": hind(1), "hl_r": hind(-1)}
SPACING = {"spine": 0.036, "neck": 0.030, "head": 0.020, "tail": 0.034, "fl_l": 0.030, "fl_r": 0.030,
           "hl_l": 0.030, "hl_r": 0.030}
EYE_GUESS = [(0.058, -0.752, 0.842), (-0.058, -0.752, 0.842)]
NOSE_TIP = (0.0, -0.925, 0.785)


# ------------------------------------------------------------------ small helpers

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def resample(chain, spacing):
    pts = np.array([c[:3] for c in chain], float)
    rad = np.array([c[3] for c in chain], float)
    out = [(pts[0], rad[0])]
    for a in range(len(pts) - 1):
        seg = np.linalg.norm(pts[a + 1] - pts[a])
        n = max(1, int(round(seg / spacing)))
        for k in range(1, n + 1):
            t = k / n
            out.append((pts[a] * (1 - t) + pts[a + 1] * t, rad[a] * (1 - t) + rad[a + 1] * t))
    return out


def polyline(chain):
    return np.array([c[:3] for c in chain], float), np.array([c[3] for c in chain], float)


def nearest_on_chain(V, chain):
    """For points V (N,3): distance to the chain polyline, the axis point, the parameter t (0..1 by length), the
    interpolated radius and the local direction."""
    P, R = polyline(chain)
    seglen = np.linalg.norm(P[1:] - P[:-1], axis=1)
    cum = np.concatenate([[0], np.cumsum(seglen)])
    total = cum[-1]
    best = np.full(len(V), np.inf)
    axis = np.zeros_like(V)
    tpar = np.zeros(len(V))
    rad = np.zeros(len(V))
    dirs = np.zeros_like(V)
    for i in range(len(P) - 1):
        a, b = P[i], P[i + 1]
        ab = b - a
        L2 = max(float(ab @ ab), 1e-12)
        u = np.clip(((V - a) @ ab) / L2, 0, 1)
        q = a + u[:, None] * ab
        d = np.linalg.norm(V - q, axis=1)
        m = d < best
        best[m] = d[m]
        axis[m] = q[m]
        tpar[m] = (cum[i] + u[m] * seglen[i]) / total
        rad[m] = R[i] * (1 - u[m]) + R[i + 1] * u[m]
        dirs[m] = ab / math.sqrt(L2)
    return best, axis, tpar, rad, dirs


def chain_fields(V):
    """Soft chain weights (N, C), plus per-chain nearest data."""
    names = list(CHAINS)
    data = {n: nearest_on_chain(V, CHAINS[n]) for n in names}
    q = np.stack([data[n][0] / np.maximum(data[n][3], 0.02) for n in names], axis=1)
    w = np.exp(-10.0 * (q - q.min(axis=1, keepdims=True)))
    w /= w.sum(axis=1, keepdims=True)
    return names, w, data


def new_object(name, bm_or_mesh):
    if isinstance(bm_or_mesh, bmesh.types.BMesh):
        me = bpy.data.meshes.new(name)
        bm_or_mesh.to_mesh(me)
    else:
        me = bm_or_mesh
        me.name = name
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def evaluated_copy(obj, name):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    me.name = name
    return me


def mesh_arrays(me):
    V = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("co", V)
    return V.reshape(-1, 3)


def set_coords(me, V):
    me.vertices.foreach_set("co", np.ascontiguousarray(V, dtype=np.float32).ravel())
    me.update()


def vertex_normals(me):
    me.update()
    N = np.zeros(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", N)
    return N.reshape(-1, 3)


def set_attr(me, name, values, kind="FLOAT"):
    if name in me.attributes:
        me.attributes.remove(me.attributes[name])
    a = me.attributes.new(name, kind, "POINT")
    if kind == "FLOAT_VECTOR":
        a.data.foreach_set("vector", np.ascontiguousarray(values, dtype=np.float32).ravel())
    else:
        a.data.foreach_set("value", np.ascontiguousarray(values, dtype=np.float32).ravel())


def get_attr(me, name, kind="FLOAT"):
    a = me.attributes[name]
    n = len(a.data)
    if kind == "FLOAT_VECTOR":
        out = np.zeros(n * 3)
        a.data.foreach_get("vector", out)
        return out.reshape(-1, 3)
    out = np.zeros(n)
    a.data.foreach_get("value", out)
    return out


def bvh_of(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    bm.free()
    return tree


# ------------------------------------------------------------------ body

def skeleton_object(level):
    verts, edges, radii, index = [], [], [], {}

    def add(p, r):
        key = tuple(round(float(c), 5) for c in p)
        if key in index:
            return index[key]
        index[key] = len(verts)
        verts.append(tuple(float(c) for c in p))
        radii.append(float(r))
        return index[key]

    for name, chain in CHAINS.items():
        prev = None
        for p, r in resample(chain, SPACING[name]):
            i = add(p, r)
            if prev is not None and prev != i:
                edges.append((prev, i))
            prev = i
    me = bpy.data.meshes.new("BosunSkeleton")
    me.from_pydata(verts, edges, [])
    obj = bpy.data.objects.new("BosunSkeleton", me)
    bpy.context.scene.collection.objects.link(obj)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.35
    skin.use_smooth_shade = True
    sv = me.skin_vertices[0].data
    for i, r in enumerate(radii):
        sv[i].radius = (r, r)
        sv[i].use_root = False
    sv[index[tuple(round(c, 5) for c in SPINE[4][:3])]].use_root = True
    sub = obj.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = level
    sub.render_levels = level
    return obj


def shape(V):
    """Continuous space warps that turn the skin tubes into a Newfoundland. V in metres (N, 3), returned shaped."""
    names, w, data = chain_fields(V)
    disp = np.zeros_like(V)
    for ci, name in enumerate(names):
        d, axis, t, rad, dirs = data[name]
        o = V - axis
        s = np.ones_like(V)
        if name == "spine":
            y = V[:, 1]
            s[:, 0] = 1.04 + 0.04 * smoothstep(-0.45, -0.2, y) * (1 - smoothstep(0.1, 0.45, y))
            below = o[:, 2] < 0
            deep = 1.16 - 0.20 * smoothstep(-0.30, 0.42, y)            # deep brisket, little tuck-up
            s[:, 2] = np.where(below, deep, 0.90)
        elif name == "neck":
            s[:, 0] = 1.10
        elif name == "head":
            skull = 1 - smoothstep(0.35, 0.6, t)
            s[:, 0] = 1.14 * skull + 1.10 * (1 - skull)                  # broad skull, broad square muzzle
            below = o[:, 2] < 0
            muzzle = smoothstep(0.42, 0.62, t)
            s[:, 2] = np.where(below, 1.0 + 0.42 * muzzle * (1 - smoothstep(0.9, 1.0, t) * 0.4), 0.93 - 0.08 * muzzle)
        elif name.startswith(("fl", "hl")):
            paw = smoothstep(0.74, 0.86, t)
            s[:, 0] = 1.0 + 0.22 * paw
            s[:, 1] = 1.0 + 0.16 * paw + (0.06 if name.startswith("hl") else 0.0) * (1 - smoothstep(0.1, 0.35, t))
        disp += w[:, ci:ci + 1] * (o * s - o)
    V = V + disp

    # prosternum keel and a level topline
    keel = np.exp(-(((V[:, 1] + 0.44) / 0.07) ** 2 + ((V[:, 2] - 0.44) / 0.09) ** 2 + (V[:, 0] / 0.10) ** 2))
    V[:, 1] -= 0.025 * keel
    # flat broad crown and occiput; a defined stop
    head_w = w[:, names.index("head")]
    crown = np.exp(-(((V[:, 1] + 0.665) / 0.06) ** 2)) * smoothstep(0.88, 0.93, V[:, 2]) * head_w
    V[:, 2] -= 0.012 * crown
    stop = np.exp(-(((V[:, 1] + 0.748) / 0.016) ** 2) - ((V[:, 2] - 0.86) / 0.03) ** 2 - (V[:, 0] / 0.05) ** 2) * head_w
    V[:, 1] += 0.010 * stop
    V[:, 2] -= 0.012 * stop
    # blunt square nose front
    tip = smoothstep(-0.895, -0.915, V[:, 1]) * head_w
    V[:, 1] = V[:, 1] * (1 - tip * 0.6) + (-0.905 + (V[:, 1] + 0.905) * 0.4) * tip * 0.6
    # flews: the upper lips hang below the jaw line at the sides of the muzzle
    flew = smoothstep(-0.70, -0.78, V[:, 1]) * (1 - smoothstep(-0.89, -0.91, V[:, 1])) * smoothstep(0.02, 0.05, np.abs(V[:, 0]))
    flew *= smoothstep(0.77, 0.73, V[:, 2]) * head_w
    V[:, 2] -= 0.022 * flew
    # paws on the ground
    V[:, 2] = np.maximum(V[:, 2], 0.0)
    return V


def toes(V, N, w_paw, chains_data):
    """Four toe lobes on the front and top of each paw (webbed between: shallow grooves only)."""
    out = V.copy()
    for name in ("fl_l", "fl_r", "hl_l", "hl_r"):
        d, axis, t, rad, dirs = chains_data[name]
        sel = (t > 0.8) & (d < 0.09)
        cx = CHAINS[name][-1][0]
        phase = (V[:, 0] - cx) / 0.022 * math.pi
        groove = 0.5 + 0.5 * np.cos(phase * 2)                  # 0 between toes
        front = smoothstep(0.0, 0.5, -N[:, 1]) * smoothstep(0.015, 0.03, V[:, 2])
        k = sel * front * (1 - groove) * (np.abs(V[:, 0] - cx) < 0.045)
        out -= N * (0.005 * k)[:, None]
    return out


def bmesh_smooth(me, factor=0.4, iters=2, protect_z0=True):
    bm = bmesh.new()
    bm.from_mesh(me)
    for _ in range(iters):
        verts = [v for v in bm.verts if not (protect_z0 and v.co.z < 1e-4)]
        bmesh.ops.smooth_vert(bm, verts=verts, factor=factor, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(me)
    bm.free()
    me.update()


def eyeball(center, axis, radius):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=radius)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis))
    for v in bm.verts:
        v.co = rot @ v.co + Vector(center)
    return bm


def ear(sx, head_tree):
    """A small triangular Newfoundland ear lying close to the head, rounded tip, set back level with the brow."""
    bm = bmesh.new()
    rows, cols = 7, 5
    grid = []
    root = np.array([sx * 0.105, -0.640, 0.885])
    tipp = np.array([sx * 0.140, -0.668, 0.770])
    fwd = np.array([0, -1.0, 0.0])
    for i in range(rows):
        t = i / (rows - 1)
        width = 0.105 * (1 - t) ** 0.8 * (1 - 0.25 * t) + 0.012
        c = root * (1 - t) + tipp * t
        row = []
        for j in range(cols):
            u = j / (cols - 1) - 0.5
            p = c + fwd * u * width
            row.append(bm.verts.new(p.tolist()))
        grid.append(row)
    for i in range(rows - 1):
        for j in range(cols - 1):
            f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # lie on the head surface, outward
    for v in bm.verts:
        hit = head_tree.find_nearest(v.co)
        if hit[0] is not None:
            loc, nrm = hit[0], hit[1]
            if (v.co - loc).dot(nrm) < 0.010:
                v.co = loc + nrm * 0.010
    for f in bm.faces:
        if (f.calc_center_median() - Vector((0, -0.64, 0.82))).dot(f.normal) < 0:
            f.normal_flip()
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.010)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def build_body(level=2):
    """Returns (body mesh in metres, skeleton object) with eyes and ears joined, attributes set."""
    skel = skeleton_object(level)
    me = evaluated_copy(skel, "BosunBody")
    V = shape(mesh_arrays(me))
    set_coords(me, V)
    bmesh_smooth(me, 0.35, 2)
    V = mesh_arrays(me)
    N = vertex_normals(me)
    names, w, data = chain_fields(V)
    V = toes(V, N, None, data)
    # coat lumps: low-frequency waves along the normal on the long coat (silhouette break-up)
    lump = np.array([mathutils.noise.noise(Vector(p * 14.0)) for p in V])
    longw = long_coat(V, N, names, w, data)
    V = V + N * (0.006 * lump * longw)[:, None]
    set_coords(me, V)

    # eye sockets
    tree = bvh_of(me)
    eyes = []
    for g in EYE_GUESS:
        loc, nrm, _, _ = tree.find_nearest(Vector(g))
        axis = (Vector((0, -1, 0)) * 0.62 + nrm * 0.38).normalized()
        axis = (axis + Vector((0, 0, 0.05))).normalized()
        centre = loc - nrm * 0.0105
        eyes.append((centre, axis))
        V = mesh_arrays(me)
        rel = V - np.array(loc)
        side = np.array(Vector((0, 0, 1)).cross(axis).normalized())
        up = np.array(axis.cross(Vector(side)).normalized())
        a = rel @ side / 0.0175
        b = rel @ up / 0.0105
        e = np.sqrt(a * a + b * b)
        k = (1 - smoothstep(0.75, 1.25, e)) * (np.linalg.norm(rel, axis=1) < 0.04)
        V = V - np.array(nrm) * (0.022 * k)[:, None]
        set_coords(me, V)
    bm = bmesh.new()
    bm.from_mesh(me)
    for centre, axis in eyes:
        eb = eyeball(centre, axis, 0.0125)
        tmp = bpy.data.meshes.new("eye_tmp")
        eb.to_mesh(tmp)
        eb.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    tree = bvh_of(me)
    for sx in (1, -1):
        eb = ear(sx, tree)
        tmp = bpy.data.meshes.new("ear_tmp")
        eb.to_mesh(tmp)
        eb.free()
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    body_attributes(me, eyes)
    bpy.data.objects.remove(skel, do_unlink=True)
    return me, eyes


def long_coat(V, N, names, w, data):
    """0..1 weight of the long coat (ruff, chest, belly fringe, feathering, breeches, tail)."""
    y, z = V[:, 1], V[:, 2]
    wn = dict(zip(names, w.T))
    ruff = wn["neck"] + wn["spine"] * smoothstep(-0.25, -0.38, y)
    belly = wn["spine"] * smoothstep(-0.1, -0.5, N[:, 2])
    legs = sum(wn[n] for n in ("fl_l", "fl_r", "hl_l", "hl_r"))
    feather = legs * smoothstep(0.05, 0.5, N[:, 1]) * smoothstep(0.08, 0.2, z)
    tail = wn["tail"] * smoothstep(0.1, 0.3, data["tail"][2])
    return np.clip(ruff + belly + feather + tail, 0, 1)


def body_attributes(me, eyes):
    V = mesh_arrays(me)
    N = vertex_normals(me)
    names, w, data = chain_fields(V)
    wn = dict(zip(names, w.T))
    y, z = V[:, 1], V[:, 2]
    # fur flow: root to tip of each chain, head nose-to-back, sides fall downward
    flow = np.zeros_like(V)
    for name in names:
        d, axis, t, rad, dirs = data[name]
        if name == "spine":
            f = np.tile([0, 1.0, 0], (len(V), 1))
        elif name in ("neck",):
            f = -dirs                                       # from the head towards the body
        elif name == "head":
            f = -dirs
        else:
            f = dirs                                        # legs and tail: root to tip
        side = np.abs(N[:, 0:1]) + np.clip(-N[:, 2:3], 0, 1)
        f = f + np.array([0, 0, -1.0]) * (0.9 * side)
        flow += wn[name][:, None] * f
    flow -= (np.sum(flow * N, axis=1, keepdims=True)) * N
    flow /= np.maximum(np.linalg.norm(flow, axis=1, keepdims=True), 1e-6)
    longw = long_coat(V, N, names, w, data)
    head_t = data["head"][2]
    short = np.clip(wn["head"] * smoothstep(0.38, 0.55, head_t) + sum(wn[n] * smoothstep(0.55, 0.8, data[n][2])
                                                                       for n in ("fl_l", "fl_r", "hl_l", "hl_r")), 0, 1)
    short *= 1 - longw * 0.7
    bleach = np.clip(N[:, 2], 0, 1) ** 1.5 * (0.55 + 0.45 * longw) * (1 - 0.6 * short)
    bleach *= smoothstep(0.25, 0.6, z)
    front = (np.abs(V[:, 0]) < 0.03) & (z > 0.70) & (z < 0.86) & (wn["head"] > 0.5)
    y_front = float(y[front].min())
    tipc = np.array([0.0, y_front + 0.016, 0.780])
    nose_d = np.linalg.norm(V - tipc, axis=1)
    nose = (1 - smoothstep(0.034, 0.044, nose_d)) * smoothstep(y_front + 0.040, y_front + 0.022, y) * wn["head"]
    print("[bosun] muzzle front y %.3f m, nose verts %d" % (y_front, int((nose > 0.5).sum())))
    pad = smoothstep(0.012, 0.002, z) * smoothstep(-0.3, -0.7, N[:, 2])
    # lip line along the side of the muzzle, from the nose to the corner of the mouth
    lip_z = 0.738 + 0.010 * smoothstep(-0.74, -0.90, y)
    lip = np.exp(-((z - lip_z) / 0.006) ** 2) * smoothstep(-0.745, -0.77, y) * (1 - nose) * smoothstep(0.015, 0.035, np.abs(V[:, 0]))
    lip *= wn["head"]
    eye = np.zeros(len(V))
    eye_r = np.full(len(V), math.pi)
    for centre, axis in eyes:
        rel = V - np.array(centre)
        dist = np.linalg.norm(rel, axis=1)
        on = np.abs(dist - 0.0125) < 0.0015
        ang = np.arccos(np.clip((rel @ np.array(axis)) / np.maximum(dist, 1e-9), -1, 1))
        eye = np.where(on, 1.0, eye)
        eye_r = np.where(on, ang, eye_r)
    for name, vals, kind in (("flow", flow, "FLOAT_VECTOR"), ("long", longw, "FLOAT"), ("short", short, "FLOAT"),
                             ("bleach", bleach, "FLOAT"), ("nose", nose, "FLOAT"), ("pad", pad, "FLOAT"),
                             ("lip", lip, "FLOAT"), ("eye", eye, "FLOAT"), ("eye_r", eye_r, "FLOAT")):
        set_attr(me, name, vals, kind)


def withers_height(V):
    sel = (np.abs(V[:, 0]) < 0.05) & (V[:, 1] > -0.34) & (V[:, 1] < -0.22)
    return float(V[sel, 2].max())


# ------------------------------------------------------------------ harness

def harness_mesh(body_me):
    """Hull Orange water-rescue harness: back saddle with a padded grab handle and a D-ring for the tow line, a chest
    strap, a girth strap with side-release buckles, retroreflective tape on the saddle sides and the chest strap."""
    skel = skeleton_object(1)
    low = evaluated_copy(skel, "BosunLow")
    bpy.data.objects.remove(skel, do_unlink=True)
    set_coords(low, shape(mesh_arrays(low)))
    tree = bvh_of(body_me)
    Vl = mesh_arrays(low)
    names, w, data = chain_fields(Vl)
    torso = w[:, names.index("spine")] + w[:, names.index("neck")] * 0.6
    bm_low = bmesh.new()
    bm_low.from_mesh(low)
    bm_low.faces.ensure_lookup_table()
    bm_low.normal_update()

    def region(test):
        faces = []
        for f in bm_low.faces:
            c = f.calc_center_median()
            n = f.normal
            tw = np.mean([torso[v.index] for v in f.verts])
            if tw > 0.6 and test(c, n):
                faces.append(f.index)
        return faces

    saddle = region(lambda c, n: -0.22 < c.y < 0.07 and n.z > 0.10)
    girth = region(lambda c, n: -0.135 < c.y < -0.075)
    chest = region(lambda c, n: c.y < -0.22 and 0.425 < c.z < 0.485 and n.y < 0.15 and c.y > -0.52)
    tape_s = region(lambda c, n: -0.19 < c.y < 0.04 and 0.30 < n.z < 0.62)
    tape_c = region(lambda c, n: c.y < -0.33 and 0.443 < c.z < 0.468 and n.y < -0.35)

    out = bmesh.new()
    kinds = {}

    def add_piece(face_ids, off, thick, kind):
        piece = bmesh.new()
        vmap = {}
        for fi in face_ids:
            f = bm_low.faces[fi]
            vs = []
            for v in f.verts:
                if v.index not in vmap:
                    loc, nrm, _, _ = tree.find_nearest(v.co)
                    vmap[v.index] = piece.verts.new(loc + nrm * off)
                vs.append(vmap[v.index])
            piece.faces.new(vs)
        bmesh.ops.recalc_face_normals(piece, faces=piece.faces)
        piece.normal_update()
        for f in piece.faces:
            loc, nrm, _, _ = tree.find_nearest(f.calc_center_median())
            if f.normal.dot(nrm) < 0:
                f.normal_flip()
        if thick > 0:
            bmesh.ops.solidify(piece, geom=piece.faces[:], thickness=-thick)
            bmesh.ops.recalc_face_normals(piece, faces=piece.faces)
        merge(piece, kind)

    def merge(piece, kind):
        bmesh.ops.recalc_face_normals(piece, faces=piece.faces[:])
        tmp = bpy.data.meshes.new("h_tmp")
        piece.to_mesh(tmp)
        piece.free()
        start = len(out.verts)
        out.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        out.verts.ensure_lookup_table()
        for i in range(start, len(out.verts)):
            kinds[i] = kind

    add_piece(saddle, 0.020, 0.011, "fabric")
    add_piece(girth, 0.014, 0.008, "fabric")
    add_piece(chest, 0.016, 0.008, "fabric")
    add_piece(tape_s, 0.0325, 0.0, "tape")
    add_piece(tape_c, 0.0255, 0.0, "tape")

    top = tree.ray_cast(Vector((0, -0.07, 1.2)), Vector((0, 0, -1)))[0].z + 0.031
    # grab handle: a padded strap loop along the spine, with a neoprene grip sleeve in the middle
    def tube(path, rw, rh, segs, kind):
        piece = bmesh.new()
        rings = []
        for i, p in enumerate(path):
            p = Vector(p)
            tdir = (Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
            side = Vector((1, 0, 0))
            up = tdir.cross(side).normalized()
            ring = [piece.verts.new(p + side * (rw * math.cos(a)) + up * (rh * math.sin(a)))
                    for a in [2 * math.pi * k / segs for k in range(segs)]]
            rings.append(ring)
        for a, b in zip(rings, rings[1:]):
            for k in range(segs):
                piece.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
        bmesh.ops.contextual_create(piece, geom=rings[0])
        bmesh.ops.contextual_create(piece, geom=rings[-1])
        bmesh.ops.recalc_face_normals(piece, faces=piece.faces)
        merge(piece, kind)

    arc = []
    for i in range(17):
        t = i / 16
        y = -0.165 + 0.19 * t
        arc.append((0.0, y, top + 0.075 * math.sin(math.pi * t) ** 0.8))
    tube(arc, 0.021, 0.0055, 8, "fabric")
    global HANDLE_APEX, DRING_POS
    HANDLE_APEX = arc[8]
    grip = [p for p in arc[5:12]]
    tube(grip, 0.026, 0.012, 10, "grip")
    # D-ring for the tow line at the back of the saddle
    ring = bmesh.new()
    bmesh.ops.create_circle(ring, cap_ends=False, radius=0.022, segments=16)
    tor = bmesh.new()
    rc = Vector((0, 0.085, top - 0.004))
    DRING_POS = (0.0, 0.085, top + 0.016)
    loops = []
    for k in range(16):
        a = 2 * math.pi * k / 16
        c = Vector((0.022 * math.cos(a), 0, 0.022 * math.sin(a) + 0.02))
        loop = []
        for m in range(6):
            b = 2 * math.pi * m / 6
            radial = Vector((math.cos(a), 0, math.sin(a)))
            loop.append(tor.verts.new(rc + c + radial * (0.0042 * math.cos(b)) + Vector((0, 1, 0)) * (0.0042 * math.sin(b))))
        loops.append(loop)
    for k in range(16):
        a, b = loops[k], loops[(k + 1) % 16]
        for m in range(6):
            tor.faces.new((a[m], a[(m + 1) % 6], b[(m + 1) % 6], b[m]))
    bmesh.ops.recalc_face_normals(tor, faces=tor.faces)
    ring.free()
    merge(tor, "metal")
    # side-release buckles on the girth strap
    for sx in (1, -1):
        hit = tree.ray_cast(Vector((sx * 0.6, -0.105, 0.43)), Vector((-sx, 0, 0)))
        loc, nrm = hit[0], hit[1]
        bx = bmesh.new()
        bmesh.ops.create_cube(bx, size=1.0)
        for v in bx.verts:
            v.co = Vector((v.co.x * 0.016, v.co.y * 0.034, v.co.z * 0.052))
        rot = Vector((1, 0, 0)).rotation_difference(nrm * sx if sx > 0 else -nrm)
        for v in bx.verts:
            v.co = loc + nrm * 0.022 + rot @ Vector((v.co.x * sx, v.co.y, v.co.z))
        merge(bx, "plastic")
    me = bpy.data.meshes.new("BosunHarness")
    out.to_mesh(me)
    out.free()
    bm_low.free()
    bpy.data.meshes.remove(low)
    for p in me.polygons:
        p.use_smooth = True
    n = len(me.vertices)
    for kind in ("tape", "metal", "plastic", "grip"):
        set_attr(me, kind, np.array([1.0 if kinds.get(i) == kind else 0.0 for i in range(n)]))
    return me


# ------------------------------------------------------------------ fur cards

CARD_TYPES = {  # atlas column: long wavy clump, medium clump, short tuft, tail plume
    "long": 0, "medium": 1, "short": 2, "plume": 3}
REGIONS = [  # name, count, card type, length range (m), width factor, lift (rad), droop
    ("ruff", 560, "long", (0.095, 0.140), 0.50, 0.42, 0.55),
    ("chest", 150, "long", (0.090, 0.125), 0.45, 0.30, 0.85),
    ("back", 430, "medium", (0.055, 0.085), 0.55, 0.22, 0.30),
    ("belly", 170, "long", (0.085, 0.120), 0.45, 0.25, 0.95),
    ("feather", 160, "long", (0.060, 0.090), 0.45, 0.35, 0.75),
    ("breeches", 250, "long", (0.085, 0.125), 0.50, 0.35, 0.80),
    ("tail", 270, "plume", (0.100, 0.160), 0.55, 0.45, 0.70),
    ("head", 120, "short", (0.028, 0.045), 0.60, 0.30, 0.20),
    ("paw", 64, "short", (0.022, 0.032), 0.60, 0.50, 0.40),
]


def classify_points(C, N):
    names, w, data = chain_fields(C)
    best = np.array(names)[np.argmax(w, axis=1)]
    y, z = C[:, 1], C[:, 2]
    reg = np.full(len(C), "", dtype=object)
    t = {n: data[n][2] for n in names}
    for i in range(len(C)):
        b = best[i]
        n = N[i]
        if b == "neck" or (b == "spine" and y[i] < -0.33 and z[i] > 0.47):
            reg[i] = "ruff"
        elif b == "spine" and y[i] < -0.25 and z[i] <= 0.47 and n[2] < 0.3:
            reg[i] = "chest"
        elif b == "spine" and z[i] >= 0.42:
            reg[i] = "back"
        elif b == "spine" and z[i] < 0.42 and n[2] < -0.2:
            reg[i] = "belly"
        elif b in ("fl_l", "fl_r"):
            if t[b][i] > 0.84:
                reg[i] = "paw"
            elif 0.15 < t[b][i] < 0.72 and n[1] > 0.15:
                reg[i] = "feather"
        elif b in ("hl_l", "hl_r"):
            if t[b][i] > 0.84:
                reg[i] = "paw"
            elif t[b][i] < 0.58 and n[1] > -0.1:
                reg[i] = "breeches"
        elif b == "tail" and t[b][i] > 0.08:
            reg[i] = "tail"
        elif b == "head" and t[b][i] < 0.42 and n[1] > -0.55:
            reg[i] = "head"
    return reg


def fur_cards(body_me, harness_me):
    """Returns a list of card dicts (root, normal, verts (8,3), uv (8,2), region, front?)."""
    rng = random.Random(SEED)
    me = body_me
    me.calc_loop_triangles()
    V = mesh_arrays(me)
    Nv = vertex_normals(me)
    flow = get_attr(me, "flow", "FLOAT_VECTOR")
    eye = get_attr(me, "eye")
    tris = np.array([t.vertices[:] for t in me.loop_triangles])
    keep = eye[tris].max(axis=1) < 0.5
    tris = tris[keep]
    A, B, Cc = V[tris[:, 0]], V[tris[:, 1]], V[tris[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(B - A, Cc - A), axis=1)
    cent = (A + B + Cc) / 3
    fn = np.cross(B - A, Cc - A)
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    reg = classify_points(cent, fn)
    body_tree = bvh_of(me)
    harn_tree = bvh_of(harness_me)
    cards = []
    nprng = np.random.default_rng(SEED)
    for name, count, ctype, (l0, l1), wf, lift, droop in REGIONS:
        idx = np.nonzero(reg == name)[0]
        if len(idx) == 0:
            continue
        p = area[idx] / area[idx].sum()
        picks = nprng.choice(idx, size=count * 2, p=p)
        made = 0
        for ti in picks:
            if made >= count:
                break
            r1, r2 = nprng.random(2)
            if r1 + r2 > 1:
                r1, r2 = 1 - r1, 1 - r2
            a, b, c = tris[ti]
            bary = np.array([1 - r1 - r2, r1, r2])
            root = bary @ V[[a, b, c]]
            n = bary @ Nv[[a, b, c]]
            n /= np.linalg.norm(n)
            f = bary @ flow[[a, b, c]]
            f = f - (f @ n) * n
            if np.linalg.norm(f) < 1e-4:
                continue
            f /= np.linalg.norm(f)
            hn = harn_tree.find_nearest(Vector(root))
            if hn[0] is not None and hn[3] < 0.04:
                continue
            L = l0 + (l1 - l0) * rng.random()
            if name == "tail":
                L *= 0.75 + 0.5 * classify_t(root, "tail")
            W = L * wf * (0.8 + 0.4 * rng.random())
            lf = lift * (0.7 + 0.6 * rng.random())
            dr = droop * (0.6 + 0.8 * rng.random())
            twist = rng.uniform(-0.95, 0.95)
            side = np.cross(n, f)
            side /= np.linalg.norm(side)
            wv = side * math.cos(twist) + n * math.sin(twist)
            d0 = f * math.cos(lf) + n * math.sin(lf)
            pts = [root - n * 0.006]
            d = d0.copy()
            for k in range(1, 4):
                d = d + np.array([0, 0, -1.0]) * (dr * 0.45)
                d /= np.linalg.norm(d)
                q = pts[-1] + d * (L / 3)
                hit = body_tree.find_nearest(Vector(q))
                if hit[0] is not None:
                    loc, nrm = np.array(hit[0]), np.array(hit[1])
                    if (q - loc) @ nrm < 0.004:
                        q = loc + nrm * 0.004
                pts.append(q)
            taper = [1.0, 0.95, 0.78, 0.5]
            verts, uvs = [], []
            col = CARD_TYPES[ctype]
            row = rng.randint(0, 1)
            u0, u1 = col / 4 + 0.006, (col + 1) / 4 - 0.006
            v0, v1 = row / 2 + 0.004, (row + 1) / 2 - 0.004
            for k, q in enumerate(pts):
                hw = W * taper[k] / 2
                verts += [q - wv * hw, q + wv * hw]
                vv = v0 + (v1 - v0) * k / 3
                uvs += [(u0, vv), (u1, vv)]
            verts = np.array(verts)
            V3 = np.maximum(verts[:, 2], 0.0)
            verts[:, 2] = V3
            cards.append({"root": root, "n": n, "verts": verts, "uv": uvs, "region": name, "front": root[1] < -0.05,
                          "size": L * W})
            made += 1
    return cards


def classify_t(p, chain):
    return float(nearest_on_chain(np.array([p]), CHAINS[chain])[2][0])


def cards_mesh(cards, name, width_scale=1.0, length_scale=1.0):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    normals = []
    for c in cards:
        verts = c["verts"].copy()
        if width_scale != 1.0 or length_scale != 1.0:
            root = (verts[0] + verts[1]) / 2
            for k in range(4):
                mid = (verts[2 * k] + verts[2 * k + 1]) / 2
                half = (verts[2 * k + 1] - verts[2 * k]) / 2 * width_scale
                mid = root + (mid - root) * length_scale
                verts[2 * k], verts[2 * k + 1] = mid - half, mid + half
        bv = [bm.verts.new((verts[i] * S).tolist()) for i in range(8)]
        normals += [c["n"]] * 8
        for k in range(3):
            quad = [2 * k, 2 * k + 1, 2 * k + 3, 2 * k + 2]
            a, b, d = verts[quad[0]], verts[quad[1]], verts[quad[3]]
            fnorm = np.cross(b - a, d - a)
            if fnorm @ c["n"] < 0:
                quad = quad[::-1]
            f = bm.faces.new([bv[i] for i in quad])
            for loop, i in zip(f.loops, quad):
                loop[uvl].uv = c["uv"][i]
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.normals_split_custom_set_from_vertices([tuple(n) for n in normals])
    return new_object(name, me)


# ------------------------------------------------------------------ assembly

def uv_unwrap(obj, margin=0.003):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.uv_layers[0].name = "UVMap"


def to_studs(me):
    set_coords(me, mesh_arrays(me) * S)


XFORM = {"shift": np.zeros(3), "k": 1.0}      # build metres -> studs: (v + shift) * k * S


def to_final(p):
    return (np.asarray(p, float) + XFORM["shift"]) * XFORM["k"] * S


def from_final(p):
    return np.asarray(p, float) / (XFORM["k"] * S) - XFORM["shift"]


HANDLE_APEX = DRING_POS = None
MOUTH = (0.0, -0.905, 0.738)


def attachments():
    """ATT_ empties (Roblox Attachments on import): the harness grab handle, the tow-line D-ring, the mouth (CH7 line carry)."""
    made = []
    for name, p in (("ATT_HarnessHandle", HANDLE_APEX), ("ATT_TowRing", DRING_POS), ("ATT_Mouth", MOUTH)):
        e = bpy.data.objects.new(name, None)
        e.empty_display_size = 0.15
        e.location = tuple(to_final(p))
        bpy.context.scene.collection.objects.link(e)
        made.append(e)
    return made


def part_of(c):
    """Body split (metres): head + upper neck, fore body + fore legs, hind body + hind legs + tail."""
    if c[1] < -0.50 and c[2] > 0.58:
        return "Head"
    return "Fore" if c[1] < 0.02 else "Hind"


def split_body(obj, base, lod_suffix):
    """Splits a body object into the three parts; custom normals copied from the unsplit mesh."""
    me = obj.data
    V = mesh_arrays(me)
    Nn = vertex_normals(me)
    kd = KDTree(len(V))
    for i, v in enumerate(V):
        kd.insert(v, i)
    kd.balance()
    parts = {}
    for part in ("Head", "Fore", "Hind"):
        bm = bmesh.new()
        bm.from_mesh(me)
        kill = [f for f in bm.faces if part_of(from_final(f.calc_center_median())) != part]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        name = "%s_Body%s_%s" % (base, part, lod_suffix)
        pme = bpy.data.meshes.new(name)
        bm.to_mesh(pme)
        bm.free()
        for p in pme.polygons:
            p.use_smooth = True
        Vp = mesh_arrays(pme)
        pme.normals_split_custom_set_from_vertices([tuple(Nn[kd.find(v)[1]]) for v in Vp])
        parts[part] = new_object(name, pme)
    return parts
