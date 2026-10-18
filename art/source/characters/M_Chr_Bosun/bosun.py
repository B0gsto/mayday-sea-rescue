"""Bosun, the Newfoundland (docs/12 2.9 row M_Chr_Bosun, CH6): geometry for the body and the fur cards (the harness
geometry lives in bosun_harness.py; harness_mesh() below is the shim the pipeline calls).

Built in metres on a quadruped skeleton graph (Skin modifier + Subdivision, so every limb is a clean quad tube with
edge loops at the joints and the rest pose is a natural four-square stand, ready for RIG_Bosun in CH7). The head and
the paws are refined locally (the head tube cut around, then the muzzle, nose, eyes and paws cut fully), shaped by
continuous space warps (short cobby trunk, deep heavy chest, level topline, heavy column legs, broad skull with a flat
squared crown and a defined stop, a square deep box muzzle with flews hanging below the lower jaw, big webbed paws) and fine displacements along the normal (brow ridges,
cheeks, jowls, nose leather with nostrils and philtrum, lip crease, toes and grooves, toe pads and main pad). Separate
pieces in the body mesh set: eyeballs, bulged cornea shells, eyelid rims, heavy triangular ears lying close to the
head, nails, and the tongue in the slightly open mouth. Scaled to studs (1 m = 3 studs). Front is -Y, Z up, origin at the ground between the feet.

Meshes (one material each, UVMap only):
  M_Chr_Bosun_BodyHead / _BodyFore / _BodyHind   set Body (2048)   split so each MeshPart stays under 10,000 tris;
                                                 custom normals from the unsplit body so the cuts do not show
  M_Chr_Bosun_Harness                            set Harness (1024) Hull Orange water-rescue harness (bosun_harness.py)
  M_Chr_Bosun_FurHead / _FurFront / _FurRear / _FurTail (r5: head and tail fur split out; Tail = tail skin, Body set) set Fur (2048, RGBA) alpha fur cards in two layers (fur_cards)

Per-vertex POINT attributes on the body parts for bake_bosun.py (FLOAT 0..1 unless noted):
  flow     FLOAT_VECTOR groom direction, unit and tangent to the skin: head nose-to-back, body to the rear, sides and
           legs downward, tail and ears root to tip
  long     long-coat weight (ruff, chest, belly fringe, leg feathering, breeches, tail)
  short    short-coat weight (muzzle, lower legs, paws; 0.6 on the ears)
  bleach   sun-bleached brown tips on the top surfaces of the coat
  nose     nose leather, including the nostrils
  pad      paw pads: four toe pads and the main pad on each sole
  lip      lip skin: the crease along the lower edge of the flews, and the philtrum
  eye      1 on the eye geometry (eyeball and cornea shell)
  eye_r    radians from the eye's optical axis, measured at the eyeball centre (pi off the eye): pupil and iris rings
  nail     1 on the nails (one per toe, 16)
  web      interdigital webbing: the skin in the grooves between the toes and between the toe pads
  lid      1 on the eyelid rims (upper and lower lid, a tube wrapping the eye opening)
  cornea   1 on the cornea shell, a cap bulged 2 mm in front of the eyeball. One opaque material in-engine, so the
           bake paints iris and pupil onto the cornea from eye_r / iris and keeps it glossy
  iris     1 inside the iris disc (on the eyeball and the cornea), soft edge at ~0.84 rad; the pupil is eye_r < ~0.3
  tear     tear line / moisture: the inner eye corner, the lower-lid margin, a short streak below the inner corner
  brow     brow ridges above the eyes
  ear      1 on the ear leather (both ears)
  sunfade  sun-faded coat: the back, the top of the neck and head, and the ear tops
  tongue   1 on the tongue piece (pink; lies in the slightly open, panting mouth and drapes over the lower lip)
  mouth_inner  the dark inner mouth / gums: the recessed gap between the upper and the lower lip at the front
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
SPINE = [(0, -0.41, 0.520, 0.172), (0, -0.35, 0.532, 0.192), (0, -0.28, 0.535, 0.202), (0, -0.22, 0.532, 0.205),
         (0, -0.16, 0.532, 0.199), (0, -0.10, 0.540, 0.187), (0, -0.04, 0.548, 0.176), (0, 0.02, 0.553, 0.170),
         (0, 0.07, 0.548, 0.155)]      # short, cobby trunk: point of shoulder to buttock ~1.15 x the withers height
NECK = [(0, -0.41, 0.520, 0.172), (0, -0.49, 0.600, 0.166), (0, -0.55, 0.680, 0.153), (0, -0.585, 0.750, 0.138)]
HEAD = [(0, -0.585, 0.750, 0.138), (0, -0.615, 0.800, 0.128), (0, -0.655, 0.822, 0.128), (0, -0.700, 0.822, 0.118),
        (0, -0.745, 0.805, 0.094), (0, -0.785, 0.787, 0.088), (0, -0.820, 0.777, 0.084), (0, -0.850, 0.774, 0.078),
        (0, -0.872, 0.774, 0.066)]
TAIL = [(0, 0.07, 0.548, 0.165), (0, 0.15, 0.548, 0.122), (0, 0.205, 0.500, 0.100), (0, 0.240, 0.420, 0.082),
        (0, 0.258, 0.320, 0.064), (0, 0.264, 0.225, 0.054), (0, 0.270, 0.160, 0.044), (0, 0.290, 0.118, 0.034)]
# round 5: heavier root (0.165 / 0.122 / 0.100). round 4: thick, otter-like (broad at the root, tapering evenly), hanging low to the hocks, the tip curling back


def fore(sx):
    return [(0, -0.28, 0.535, 0.202), (sx * 0.102, -0.315, 0.455, 0.108), (sx * 0.124, -0.276, 0.335, 0.090),
            (sx * 0.126, -0.280, 0.215, 0.078), (sx * 0.126, -0.282, 0.110, 0.070), (sx * 0.127, -0.296, 0.058, 0.063),
            (sx * 0.128, -0.330, 0.032, 0.060), (sx * 0.129, -0.370, 0.026, 0.051)]   # heavy-boned straight columns


def hind(sx):
    return [(0, 0.02, 0.553, 0.170), (sx * 0.104, 0.060, 0.480, 0.118), (sx * 0.132, -0.005, 0.305, 0.104),
            (sx * 0.130, 0.065, 0.215, 0.080), (sx * 0.128, 0.132, 0.132, 0.068), (sx * 0.127, 0.122, 0.058, 0.061),
            (sx * 0.128, 0.088, 0.032, 0.058), (sx * 0.129, 0.048, 0.026, 0.049)]


CHAINS = {"spine": SPINE, "neck": NECK, "head": HEAD, "tail": TAIL,
          "fl_l": fore(1), "fl_r": fore(-1), "hl_l": hind(1), "hl_r": hind(-1)}
SPACING = {"spine": 0.036, "neck": 0.030, "head": 0.020, "tail": 0.034, "fl_l": 0.030, "fl_r": 0.030,
           "hl_l": 0.030, "hl_r": 0.030}
EYE_GUESS = [(0.061, -0.745, 0.860), (-0.061, -0.745, 0.860)]
NOSE_TIP = (0.0, -0.925, 0.785)


# ------------------------------------------------------------------ small helpers

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def resample(chain, spacing, max_dr=None):
    """Points along a chain every ~spacing; with max_dr, also no more than max_dr radius change per step (so the leg
    and tail roots blend into the torso instead of pinching under Subsurf)."""
    pts = np.array([c[:3] for c in chain], float)
    rad = np.array([c[3] for c in chain], float)
    out = [(pts[0], rad[0])]
    for a in range(len(pts) - 1):
        seg = np.linalg.norm(pts[a + 1] - pts[a])
        n = max(1, int(round(seg / spacing)))
        if max_dr:
            n = max(n, int(math.ceil(abs(rad[a + 1] - rad[a]) / max_dr)))
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

BODY_SPACING = {"spine": 0.075, "neck": 0.060, "head": 0.040, "tail": 0.100, "fl_l": 0.090, "fl_r": 0.090,
                "hl_l": 0.090, "hl_r": 0.090}      # skeleton node spacing for the body (SPACING stays for the harness)
EYE_A, EYE_B, EYE_R = 0.0165, 0.0102, 0.0125      # eye opening half-width / half-height, eyeball radius (m)
TOE_X = (-0.036, -0.012, 0.012, 0.036)            # toe centres across each paw, from the paw centre line (m)
HEADM = {}                                        # measured head landmarks (build metres)
PAWS = []                                         # (chain, centre x, front y) per paw
TAG_SKIN, TAG_EYEBALL, TAG_CORNEA, TAG_LID, TAG_EAR, TAG_NAIL, TAG_TONGUE = range(7)
EYE_LOCS = []                                     # eye opening centres on the skin (build metres), for the fur


def skeleton_object(level, spacing=None, max_dr=None):
    spacing = spacing or SPACING
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
        for p, r in resample(chain, spacing[name], max_dr):
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


def gauss(V, c, s):
    """Gaussian blob mirrored in x (uses |x|): centre c, per-axis sigmas s (metres)."""
    P = np.column_stack([np.abs(V[:, 0]), V[:, 1], V[:, 2]])
    d = (P - np.asarray(c, float)) / np.asarray(s, float)
    return np.exp(-np.sum(d * d, axis=1))


def band(x, a, b, soft):
    return smoothstep(a - soft, a + soft, x) * (1 - smoothstep(b - soft, b + soft, x))


def flew_profile(V):
    """Where the upper-lip flews hang: the lower sides of the muzzle between the nose and the mouth corner."""
    y, ax = V[:, 1], np.abs(V[:, 0])
    return smoothstep(-0.735, -0.780, y) * (1 - smoothstep(-0.860, -0.895, y)) * smoothstep(0.016, 0.046, ax)


def squircle(phi, p):
    c, s = np.cos(phi), np.sin(phi)
    k = (np.abs(c) ** p + np.abs(s) ** p) ** (-1.0 / p)
    return c * k, s * k


def head_box(V, o, axis, t, rad, dirs, o_s):
    """The head tube re-formed in its own cross-section: a broad skull with a flat, squared crown, then (past the
    stop) a square deep box muzzle of constant width whose top steps down below the forehead. o_s is the plain
    scaled offset kept elsewhere. Returns the new offsets from the head axis."""
    a = np.sum(o * dirs, axis=1)
    orad = o - a[:, None] * dirs
    ex = np.array([1.0, 0.0, 0.0])
    ez = np.cross(dirs, ex)
    ez /= np.maximum(np.linalg.norm(ez, axis=1, keepdims=True), 1e-9)
    ez *= np.sign(ez[:, 2:3] + 1e-9)
    r = np.maximum(rad, 1e-4)
    u, v = orad @ ex / r, np.sum(orad * ez, axis=1) / r
    rho, phi = np.hypot(u, v), np.arctan2(v, u)
    top = v > 0
    # skull: squared on top (flat, wide crown), rounder under the jaw
    cx, cz = squircle(phi, np.where(top, 2.05, 2.3))          # round 4: domed skull (p ~2 = round)
    sk = (ex[None] * (rho * cx * r * 1.26)[:, None] +
          ez * (rho * cz * r * np.where(top, 1.06, 1.0))[:, None] + a[:, None] * dirs)
    # muzzle box (world heights): top nearly level, a deep square front, flews hang from the lower corners
    y = V[:, 1]
    q = np.clip((y + 0.775) / (-0.872 + 0.775), 0, 1)
    Xw = 0.091 - 0.005 * q
    Zt, Zb = 0.843 - 0.013 * q, 0.690 + 0.010 * q
    zc = (Zt + Zb) / 2
    bx, bz = squircle(phi, np.where(top, 3.0, 3.6))
    hz = np.where(top, Zt - zc, zc - Zb)
    af = np.where(t > 0.999, np.maximum(a, 0) * 0.72 + np.minimum(a, 0), a)    # flatter front face
    mz = ex[None] * (rho * bx * Xw)[:, None] + ez * ((zc - axis[:, 2]) + rho * bz * hz)[:, None] + af[:, None] * dirs
    m_sk = smoothstep(0.06, 0.20, t)
    m_mz = smoothstep(-0.728, -0.778, y)
    out = o_s * (1 - m_sk)[:, None] + sk * m_sk[:, None]
    return out * (1 - m_mz)[:, None] + mz * m_mz[:, None]


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
            s[:, 0] = 1.08 + 0.08 * smoothstep(-0.45, -0.22, y) * (1 - smoothstep(-0.06, 0.10, y))   # barrel ribs
            below = o[:, 2] < 0
            deep = 1.27 - 0.22 * smoothstep(-0.26, 0.08, y)            # deep heavy brisket, little tuck-up
            s[:, 2] = np.where(below, deep, 0.90)                       # flat, level topline
        elif name == "neck":
            s[:, 0] = 1.20                                              # thick neck under the ruff
            s[:, 2] = np.where(o[:, 2] < 0, 1.08, 1.0)
        elif name == "head":
            s[:, 0] = 1.22
            s[:, 2] = np.where(o[:, 2] < 0, 1.0, 0.93)
            disp += w[:, ci:ci + 1] * (head_box(V, o, axis, t, rad, dirs, o * s) - o)
            continue
        elif name.startswith(("fl", "hl")):
            paw = smoothstep(0.74, 0.86, t)
            s[:, 0] = 1.0 + 0.22 * paw                                   # big, wide paws
            s[:, 1] = 1.0 + 0.15 * paw + (0.06 if name.startswith("hl") else 0.0) * (1 - smoothstep(0.1, 0.35, t))
        disp += w[:, ci:ci + 1] * (o * s - o)
    V = V + disp

    # prosternum keel
    keel = np.exp(-(((V[:, 1] + 0.43) / 0.07) ** 2 + ((V[:, 2] - 0.43) / 0.09) ** 2 + (V[:, 0] / 0.10) ** 2))
    V[:, 1] -= 0.030 * keel
    # round 5: deeper chest: the brisket drops to the elbows (below the front of the ribcage)
    brisket = np.exp(-(((V[:, 1] + 0.30) / 0.11) ** 2) - ((V[:, 0] / 0.13) ** 2)) * smoothstep(0.42, 0.30, V[:, 2]) \
        * (w[:, names.index("spine")] + w[:, names.index("neck")])
    V[:, 2] -= 0.030 * brisket
    # flat broad crown and occiput; a defined stop
    head_w = w[:, names.index("head")]
    crown = np.exp(-(((V[:, 1] + 0.665) / 0.06) ** 2)) * smoothstep(0.88, 0.93, V[:, 2]) * head_w
    V[:, 2] += 0.008 * crown * np.exp(-(V[:, 0] / 0.09) ** 2)      # round 4: domed crown
    stop = np.exp(-(((V[:, 1] + 0.752) / 0.016) ** 2) - ((V[:, 2] - 0.862) / 0.022) ** 2 - (V[:, 0] / 0.05) ** 2) * head_w
    V[:, 1] += 0.016 * stop
    V[:, 2] -= 0.012 * stop
    # flews: the upper lips hang below the lower jaw at the sides; the chin (lower jaw) is narrower and higher
    flew = flew_profile(V) * smoothstep(0.770, 0.715, V[:, 2]) * head_w
    V[:, 2] -= 0.036 * flew                                    # round 4: pendulous flews
    V[:, 0] += np.sign(V[:, 0]) * 0.011 * flew
    ax = np.abs(V[:, 0])
    chin = smoothstep(-0.77, -0.81, V[:, 1]) * (1 - smoothstep(0.018, 0.042, ax)) * smoothstep(0.725, 0.695, V[:, 2]) * head_w
    V[:, 2] += 0.005 * chin
    # paws on the ground
    V[:, 2] = np.maximum(V[:, 2], 0.0)
    return V


def bmesh_smooth(me, factor=0.4, iters=2, protect_z0=True):
    bm = bmesh.new()
    bm.from_mesh(me)
    for _ in range(iters):
        verts = [v for v in bm.verts if not (protect_z0 and v.co.z < 1e-4)]
        bmesh.ops.smooth_vert(bm, verts=verts, factor=factor, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.to_mesh(me)
    bm.free()
    me.update()


def refine(me, face_mask, edge_ok=None, cuts=1):
    """Local subdivision (smooth) of the faces in face_mask; edge_ok (per mesh edge) limits which edges are cut."""
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bm.edges.index_update()
    edges = set()
    for f in bm.faces:
        if face_mask[f.index]:
            for e in f.edges:
                if edge_ok is None or edge_ok[e.index]:
                    edges.add(e)
    if edges:
        bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=cuts, smooth=1.0, use_grid_fill=True,
                                  use_smooth_even=True)
    bm.to_mesh(me)
    bm.free()
    me.update()


def face_centres(me):
    C = np.zeros(len(me.polygons) * 3)
    me.polygons.foreach_get("center", C)
    return C.reshape(-1, 3)


def refine_head_and_paws(me):
    """The skin tubes are 16 quads around: too coarse for a face. Cut the head tube around (2x), then the muzzle,
    nose, eyes and brows fully (2x), and the paws fully (2x), before shaping."""
    C = face_centres(me)
    names, w, data = chain_fields(C)
    Cs = shape(C)
    head = (w[:, names.index("head")] > 0.45) & (Cs[:, 1] < -0.615)
    V = mesh_arrays(me)
    E = np.zeros(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get("vertices", E)
    E = E.reshape(-1, 2)
    ev = V[E[:, 1]] - V[E[:, 0]]
    ev /= np.maximum(np.linalg.norm(ev, axis=1, keepdims=True), 1e-9)
    hdir = nearest_on_chain((V[E[:, 0]] + V[E[:, 1]]) / 2, HEAD)[4]
    around = np.abs(np.sum(ev * hdir, axis=1)) < 0.55
    refine(me, head, around)

    C = face_centres(me)
    names, w, data = chain_fields(C)
    Cs = shape(C)
    hw = w[:, names.index("head")]
    eyes = np.min([np.linalg.norm(Cs - np.array(g), axis=1) for g in EYE_GUESS], axis=0) < 0.034
    detail = ((hw > 0.3) & (Cs[:, 1] < -0.79)) | (eyes & (hw > 0.3))
    paws = np.zeros(len(C), bool)
    for name in ("fl_l", "fl_r", "hl_l", "hl_r"):
        d, axis, t, rad, dirs = data[name]
        toe_y = CHAINS[name][-1][1]
        paws |= (t > 0.83) & (d < 0.11) & (w[:, names.index(name)] > 0.5) & (Cs[:, 1] < toe_y + 0.030) & (Cs[:, 2] < 0.075)
    refine(me, detail | paws)

    C = face_centres(me)
    names, w, data = chain_fields(C)
    Cs = shape(C)
    hw = w[:, names.index("head")]
    mouth = (hw > 0.3) & (Cs[:, 1] < -0.835) & (Cs[:, 2] > 0.695) & (Cs[:, 2] < 0.775) & (np.abs(Cs[:, 0]) < 0.07)
    refine(me, mouth)                                             # the open mouth and the lip edges


def head_detail(V, N, hw, masks):
    """Fine head forms along the normal: brows, cheeks, jowls, occiput, medial furrow, nose leather with nostrils and
    philtrum, the lip crease under the flews. Measures HEADM."""
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    ax = np.abs(x)
    front = (ax < 0.03) & (z > 0.70) & (z < 0.86) & (hw > 0.5)
    yf = float(y[front].min())
    sel = (y < yf + 0.012) & (ax < 0.02) & (hw > 0.5)
    ztop, zbot = float(z[sel].max()), float(z[sel].min())
    ncz = ztop - 0.030
    HEADM.update(y_front=yf, nose_z=ncz, z_top=ztop, z_bot=zbot)
    print("[bosun] muzzle front y %.3f m, nose centre z %.3f, front z %.3f..%.3f" % (yf, ncz, zbot, ztop))
    fy = smoothstep(-0.15, -0.55, N[:, 1])                      # facing forward
    tip = (y < yf + 0.035) * hw
    d = np.zeros(len(V))
    brow = gauss(V, (0.060, -0.727, 0.879), (0.026, 0.016, 0.009)) * hw
    d += 0.011 * brow
    d += 0.008 * gauss(V, (0.088, -0.680, 0.805), (0.030, 0.040, 0.030)) * hw          # cheek muscles
    d += 0.010 * gauss(V, (0.072, -0.718, 0.718), (0.028, 0.030, 0.024)) * hw          # heavy jowls
    d += 0.004 * gauss(V, (0.0, -0.615, 0.935), (0.020, 0.030, 0.020)) * hw            # occiput
    d -= 0.004 * np.exp(-(x / 0.009) ** 2) * band(y, -0.765, -0.665, 0.01) * smoothstep(0.85, 0.875, z) * hw
    ne = (x / 0.039) ** 2 + ((z - ncz) / 0.027) ** 2
    nose = (1 - smoothstep(0.80, 1.05, ne)) * fy * tip
    d += 0.005 * (1 - smoothstep(0.6, 1.0, ne)) * fy * tip                            # leather stands proud
    nostril = np.zeros(len(V))
    for s in (1, -1):
        nostril = np.maximum(nostril, np.exp(-(((x - s * 0.016) / 0.0072) ** 2 + ((z - ncz + 0.003) / 0.0042) ** 2)))
        nostril = np.maximum(nostril, 0.45 * np.exp(-(((x - s * 0.027) / 0.0055) ** 2 + ((z - ncz + 0.009) / 0.003) ** 2)))
    nostril *= fy * tip
    d -= 0.008 * nostril
    phil = np.exp(-(x / 0.0035) ** 2) * band(z, ncz - 0.055, ncz - 0.014, 0.004) * fy * tip
    d -= 0.003 * phil
    crease = flew_profile(V) * np.exp(-((N[:, 2] + 0.45) / 0.2) ** 2) * smoothstep(0.78, 0.76, z) * hw
    d -= 0.0045 * crease
    # the mouth slightly open (panting): a dark gap between the upper lip and the lower lip across the front of the
    # muzzle, drooping toward the corners; the tongue piece lies in it (build_body)
    zm0 = ncz - 0.050
    HEADM["mouth_z"] = zm0
    zm = zm0 - 0.012 * np.clip(x / 0.06, -1, 1) ** 2
    hh = 0.0095 * (1 - 0.45 * np.clip((x / 0.06) ** 2, 0, 1))
    mouth = np.exp(-((z - zm) / hh) ** 2) * smoothstep(-0.15, -0.55, N[:, 1]) * (1 - smoothstep(0.045, 0.068, ax))
    mouth *= (y < yf + 0.045) * hw
    d -= 0.020 * mouth
    masks.update(brow=np.clip(brow, 0, 1), nose=np.clip(np.maximum(nose, nostril), 0, 1),
                 lip=np.clip(np.maximum(crease * 1.4, phil), 0, 1) * (1 - smoothstep(0.3, 0.6, mouth)),
                 mouth_inner=np.clip(1.6 * mouth - 0.2, 0, 1))
    return V + N * d[:, None]


def paw_detail(V, N, names, w, data, masks):
    """Four toes with grooves (webbed between), toe pads and a main pad on the sole (the rest of the sole lifted)."""
    PAWS.clear()
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    disp, pad, web, rise = (np.zeros(len(V)) for _ in range(4))
    for name in ("fl_l", "fl_r", "hl_l", "hl_r"):
        d, axis, t, rad, dirs = data[name]
        sel = (t > 0.78) & (d < 0.10) & (w[:, names.index(name)] > 0.5) & (z < 0.10)
        low = sel & (z < 0.03)
        cx = float(x[low].mean())
        yf = float(y[low & (np.abs(x - cx) < 0.03)].min())
        PAWS.append((name, cx, yf))
        rel = x - cx
        g = 0.5 + 0.5 * np.cos(2 * np.pi * rel / 0.024)          # 1 in the grooves, 0 on the toes
        inw = 1 - smoothstep(0.044, 0.054, np.abs(rel))
        zone = 1 - smoothstep(yf + 0.035, yf + 0.060, y)
        face = np.clip(smoothstep(0.1, 0.5, -N[:, 1]) + smoothstep(0.3, 0.7, N[:, 2]), 0, 1)
        m = sel * inw * zone * face * smoothstep(0.002, 0.008, z)
        disp += m * (-0.0065 * g + 0.002 * (1 - g))
        web = np.maximum(web, m * g * (1 - smoothstep(0.02, 0.045, z)))
        under = sel * (z < 0.006) * (N[:, 2] < -0.3)
        pm = np.zeros(len(V))
        for tx in TOE_X:
            ty = yf + 0.020 + (0.007 if abs(tx) > 0.02 else 0.0)
            e = ((rel - tx) / 0.0095) ** 2 + ((y - ty) / 0.011) ** 2
            pm = np.maximum(pm, 1 - smoothstep(0.6, 1.0, e))
        e = (rel / 0.024) ** 2 + ((y - yf - 0.062) / 0.017) ** 2
        pm = np.maximum(pm, 1 - smoothstep(0.6, 1.0, e))
        pad = np.maximum(pad, pm * under)
        rise += under * (1 - pm)
        web = np.maximum(web, under * (1 - pm) * (1 - smoothstep(yf + 0.035, yf + 0.045, y)))
    V = V + N * disp[:, None]
    V[:, 2] += 0.004 * np.clip(rise, 0, 1)
    masks.update(pad=pad, web=web)
    return V


def eye_sockets(me):
    """Almond eye openings dented into the skin; returns the eye frames."""
    tree = bvh_of(me)
    eyes = []
    for g in EYE_GUESS:
        loc, nrm, _, _ = tree.ray_cast(Vector((g[0], g[1] - 0.3, g[2])), Vector((0, 1, 0)), 0.6)
        if loc is None:
            loc, nrm, _, _ = tree.find_nearest(Vector(g))
        axis = (Vector((0, -1, 0)) * 0.62 + nrm * 0.38).normalized()
        axis = (axis + Vector((math.copysign(0.16, g[0]), 0, 0.05))).normalized()     # wide-set, a little outward
        centre = loc - nrm * 0.0092                                  # proud of the lids, so the cornea catches light
        side = Vector((0, 0, 1)).cross(axis).normalized()
        up = axis.cross(side).normalized()
        V = mesh_arrays(me)
        rel = V - np.array(loc)
        a = rel @ np.array(side) / EYE_A
        b = rel @ np.array(up) / EYE_B
        e = np.sqrt(a * a + b * b)
        k = (1 - smoothstep(0.8, 1.35, e)) * (np.linalg.norm(rel, axis=1) < 0.04)
        V = V - np.array(nrm) * (0.016 * k)[:, None]
        set_coords(me, V)
        c1, c2 = loc + side * EYE_A, loc - side * EYE_A
        inner = c1 if abs(c1.x) < abs(c2.x) else c2
        eyes.append({"centre": centre, "axis": axis, "loc": loc, "nrm": nrm, "side": side, "up": up, "inner": inner})
    return eyes


def eyeball(center, axis, radius):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=radius)
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis))
    for v in bm.verts:
        v.co = rot @ v.co + Vector(center)
    return bm


def cornea(eye, Rc=0.0095, bulge=0.0020, rings=4, segs=12, max_ang=1.12):
    """A bulged cornea cap in front of the eyeball (spherical cap, smaller radius, 1.6 mm proud of the eyeball)."""
    ax, sd, up = eye["axis"], eye["side"], eye["up"]
    cc = eye["centre"] + ax * (EYE_R - Rc + bulge)
    bm = bmesh.new()
    pole = bm.verts.new(cc + ax * Rc)
    prev = None
    for i in range(1, rings + 1):
        a = max_ang * i / rings
        ring = [bm.verts.new(cc + (ax * math.cos(a) + (sd * math.cos(p) + up * math.sin(p)) * math.sin(a)) * Rc)
                for p in np.linspace(0, 2 * math.pi, segs, endpoint=False)]
        for j in range(segs):
            if prev is None:
                bm.faces.new((pole, ring[j], ring[(j + 1) % segs]))
            else:
                bm.faces.new((prev[j], ring[j], ring[(j + 1) % segs], prev[(j + 1) % segs]))
        prev = ring
    orient_out(bm, eye["centre"])
    return bm


def orient_out(bm, centre, axis_from=None):
    """Flip faces so they face away from centre (or from the line centre + s * axis_from)."""
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        q = Vector(centre)
        if axis_from is not None:
            q = q + axis_from * (c - q).dot(axis_from)
        if (c - q).dot(f.normal) < 0:
            f.normal_flip()
    bm.normal_update()


def lid_rims(eye, skin_tree, segs=24, around=5):
    """Upper and lower eyelid rims: a closed tube around the almond opening, bridging the dented skin and the eyeball.
    Returns (bm, lower) with lower = 1 on the lower-lid verts."""
    loc, ctr, sd, up = eye["loc"], eye["centre"], eye["side"], eye["up"]
    mids, rts, lower = [], [], []
    for i in range(segs):
        th = 2 * math.pi * i / segs
        st = math.sin(th)
        p = loc + sd * (EYE_A * 0.95 * math.cos(th)) + up * (EYE_B * 0.95 * st * (0.65 + 0.35 * abs(st)) * (1.08 if st < 0 else 1.0))
        dirc = (p - ctr).normalized()
        eyept = ctr + dirc * EYE_R
        s = skin_tree.find_nearest(p)[0] or p
        gap = (s - eyept).length
        rt = min(max(0.35 * gap + 0.0005, 0.0013 if st < 0 else 0.0017), 0.0030)
        mids.append(eyept * 0.65 + s * 0.35)
        rts.append(rt)
        lower.append(1.0 if st < -0.2 else 0.0)
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        T = (mids[(i + 1) % segs] - mids[i - 1]).normalized()
        n1 = (mids[i] - ctr).normalized()
        n1 = (n1 - T * n1.dot(T)).normalized()
        n2 = T.cross(n1)
        rings.append([bm.verts.new(mids[i] + (n1 * math.cos(a) + n2 * math.sin(a)) * rts[i])
                      for a in np.linspace(0, 2 * math.pi, around, endpoint=False)])
    for i in range(segs):
        r0, r1 = rings[i], rings[(i + 1) % segs]
        for j in range(around):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % around], r0[(j + 1) % around]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, np.repeat(lower, around)


EAR_ROOT, EAR_TIP = (0.112, -0.640, 0.900), (0.142, -0.672, 0.690)    # round 5: tip at the jaw line (r4: below)


def ear(sx, head_tree):
    """A heavy triangular Newfoundland ear lying close to the head: thick at the root, thin at the rounded tip, set
    back level with the brow and hanging beside the cheek. Returns (bm, t) with t = 0 root .. 1 tip per vertex."""
    rows, cols = 9, 6
    root = np.array(EAR_ROOT) * [sx, 1, 1]
    tipp = np.array(EAR_TIP) * [sx, 1, 1]
    axisd = tipp - root
    L = float(np.linalg.norm(axisd))
    axisd /= L
    fwd = np.array([0, -1.0, 0.0])
    fwd -= (fwd @ axisd) * axisd
    fwd /= np.linalg.norm(fwd)
    bm = bmesh.new()
    outer, inner, tpar, hang_x = {}, {}, [], {}
    for i in range(rows):
        t = i / (rows - 1)
        width = 0.140 * (1 - 0.92 * t) ** 0.85              # round 5: broader triangle
        for j in range(cols):
            u = j / (cols - 1) - 0.5
            p = root + axisd * L * t + fwd * u * width - axisd * (0.035 * (2 * u) ** 2 * t ** 3)
            loc, nrm, _, _ = head_tree.find_nearest(Vector(p.tolist()))
            loc, nrm = np.array(loc), np.array(nrm)
            if i > 0 and abs(loc[0]) < hang_x.get(j, 0.0):     # below the cheek the ear hangs free, not on the throat
                loc = np.array([sx * hang_x[j], loc[1], loc[2]])
                nrm = np.array([sx * 1.0, 0.0, 0.0])
            hang_x[j] = max(hang_x.get(j, 0.0), abs(loc[0]))
            gap = -0.005 if i == 0 else 0.0015 + 0.003 * t
            th = (0.017 * (1 - t) + 0.006) * (1 - 0.55 * (2 * u) ** 2)
            inner[i, j] = bm.verts.new((loc + nrm * gap).tolist())
            outer[i, j] = bm.verts.new((loc + nrm * (gap + th)).tolist())
            tpar += [t, t]
    for i in range(rows - 1):
        for j in range(cols - 1):
            bm.faces.new((outer[i, j], outer[i, j + 1], outer[i + 1, j + 1], outer[i + 1, j]))
            bm.faces.new((inner[i + 1, j], inner[i + 1, j + 1], inner[i, j + 1], inner[i, j]))
    loop = [(i, 0) for i in range(rows)] + [(rows - 1, j) for j in range(1, cols)] + \
           [(i, cols - 1) for i in range(rows - 2, -1, -1)] + [(0, j) for j in range(cols - 2, 0, -1)]
    for k in range(len(loop)):
        a, b = loop[k], loop[(k + 1) % len(loop)]
        bm.faces.new((outer[a], outer[b], inner[b], inner[a]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, np.array(tpar)


def nails(skin_tree):
    """One curved nail per toe, from the toe front down and forward to the ground."""
    bm = bmesh.new()
    dvec = Vector((0, -0.80, -0.60)).normalized()
    sidev = Vector((1, 0, 0))
    upv = dvec.cross(sidev).normalized()
    if upv.z < 0:
        upv = -upv
    angs = np.linspace(0, 2 * math.pi, 6, endpoint=False)
    for name, cx, yf in PAWS:
        for tx in TOE_X:
            hit = skin_tree.ray_cast(Vector((cx + tx, yf - 0.10, 0.017)), Vector((0, 1, 0)), 0.25)
            if hit[0] is None:
                continue
            b = hit[0] + Vector((0, 0.003, 0))
            L, r0 = 0.013, 0.0050
            rings = []
            for tt, rr in ((0.0, 1.0), (0.5, 0.8), (0.85, 0.5)):
                c = b + dvec * (L * tt) + Vector((0, 0, -0.004 * tt * tt))
                rings.append([bm.verts.new(c + (sidev * math.cos(a) + upv * math.sin(a) * 1.15) * (r0 * rr)) for a in angs])
            tipv = bm.verts.new(b + dvec * L + Vector((0, 0, -0.004)))
            new_faces = []
            for r0_, r1_ in zip(rings[:-1], rings[1:]):
                for j in range(6):
                    new_faces.append(bm.faces.new((r0_[j], r0_[(j + 1) % 6], r1_[(j + 1) % 6], r1_[j])))
            for j in range(6):
                new_faces.append(bm.faces.new((rings[-1][j], rings[-1][(j + 1) % 6], tipv)))
            bm.normal_update()
            for f in new_faces:
                c = f.calc_center_median()
                q = b + dvec * (c - b).dot(dvec)
                if (c - q).dot(f.normal) < 0:
                    f.normal_flip()
    bm.normal_update()
    return bm


def tongue(skin_tree):
    """A pink panting tongue lying in the mouth gap: from inside the mouth over the lower lip, its tip draping a little
    in front of the chin. A flattened tube with a shallow centre groove, closed at both ends. Returns (bm, mouth point)."""
    zm0 = HEADM["mouth_z"]

    def front_y(z, x=0.0):
        hit = skin_tree.ray_cast(Vector((x, -1.3, z)), Vector((0, 1, 0)), 1.0)
        return hit[0].y if hit[0] is not None else HEADM["y_front"]

    y_in, y_ll = front_y(zm0), front_y(zm0 - 0.017)
    path = [np.array(p) for p in ((0, y_in + 0.012, zm0 + 0.000), (0, y_in - 0.001, zm0 - 0.003),
                                  (0, y_ll - 0.004, zm0 - 0.010), (0, y_ll - 0.008, zm0 - 0.019),
                                  (0, y_ll - 0.009, zm0 - 0.028), (0, y_ll - 0.007, zm0 - 0.034))]
    widths = (0.036, 0.040, 0.041, 0.039, 0.033, 0.020)
    th, segs = 0.0085, 10
    bm = bmesh.new()
    rings = []
    for k, (c, wk) in enumerate(zip(path, widths)):
        T = path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]
        T /= np.linalg.norm(T)
        side = np.array([1.0, 0, 0])
        nrm = np.cross(T, side)
        if nrm @ np.array([0, -0.3, 1.0]) < 0:
            nrm = -nrm
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            ca, sa = math.cos(a), math.sin(a)
            hn = th / 2 * sa * (1 - 0.35 * math.exp(-(ca / 0.3) ** 2) if sa > 0 else 1.0)
            ring.append(bm.verts.new((c + side * (wk / 2) * ca + nrm * hn).tolist()))
        rings.append(ring)
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for j in range(segs):
            bm.faces.new((r0[j], r1[j], r1[(j + 1) % segs], r0[(j + 1) % segs]))
    for ring, c in ((rings[0], path[0] + (path[0] - path[1]) * 0.15), (rings[-1], path[-1] + (path[-1] - path[-2]) * 0.35)):
        cv = bm.verts.new(c.tolist())
        for j in range(segs):
            bm.faces.new((ring[j], ring[(j + 1) % segs], cv))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    print("[bosun] mouth gap y %.3f, lower lip y %.3f, z %.3f; tongue %d faces" % (y_in, y_ll, zm0, len(bm.faces)))
    return bm, (0.0, y_ll - 0.006, zm0 - 0.006)


def append_piece(bm, piece, tags, tag, extra=None, extras=None):
    tmp = bpy.data.meshes.new("piece_tmp")
    piece.to_mesh(tmp)
    piece.free()
    n = len(tmp.vertices)
    bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    tags.append(np.full(n, tag))
    if extras is not None:
        extras.append(np.zeros(n) if extra is None else np.asarray(extra, float))


def build_body(level=2):
    """Returns (body mesh in metres, eyes) with eyes, cornea shells, lids, ears and nails joined, attributes set."""
    skel = skeleton_object(level, BODY_SPACING, 0.025)
    me = evaluated_copy(skel, "BosunBody")
    bpy.data.objects.remove(skel, do_unlink=True)
    refine_head_and_paws(me)
    set_coords(me, shape(mesh_arrays(me)))
    bmesh_smooth(me, 0.35, 2)
    V = mesh_arrays(me)
    N = vertex_normals(me)
    names, w, data = chain_fields(V)
    masks = {}
    V = head_detail(V, N, w[:, names.index("head")], masks)
    V = paw_detail(V, N, names, w, data, masks)
    # coat lumps: low-frequency waves along the normal on the long coat (silhouette break-up)
    lump = np.array([mathutils.noise.noise(Vector(p * 14.0)) for p in V])
    V = V + N * (0.006 * lump * long_coat(V, N, names, w, data))[:, None]
    set_coords(me, V)
    global MOUTH

    eyes = eye_sockets(me)
    EYE_LOCS[:] = [np.array(e["loc"]) for e in eyes]
    skin_tree = bvh_of(me)
    n_skin = len(me.vertices)
    bm = bmesh.new()
    bm.from_mesh(me)
    tags, ear_t, lid_low = [np.zeros(n_skin)], [np.zeros(n_skin)], [np.zeros(n_skin)]

    def add(piece, tag, et=None, ll=None):
        append_piece(bm, piece, tags, tag)
        n = len(tags[-1])
        ear_t.append(np.zeros(n) if et is None else et)
        lid_low.append(np.zeros(n) if ll is None else ll)

    for e in eyes:
        add(eyeball(e["centre"], e["axis"], EYE_R), TAG_EYEBALL)
        add(cornea(e), TAG_CORNEA)
        lb, low = lid_rims(e, skin_tree)
        add(lb, TAG_LID, ll=low)
    for sx in (1, -1):
        eb, t = ear(sx, skin_tree)
        add(eb, TAG_EAR, et=t)
    add(nails(skin_tree), TAG_NAIL)
    tb, MOUTH = tongue(skin_tree)
    add(tb, TAG_TONGUE)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    body_attributes(me, eyes, masks, np.concatenate(tags), np.concatenate(ear_t), np.concatenate(lid_low))
    set_coords(me, head_warp(mesh_arrays(me)))                   # round 4: shorter deeper muzzle, lower head carriage
    MOUTH = tuple(head_warp(np.array([MOUTH]))[0])
    EYE_LOCS[:] = list(head_warp(np.array(EYE_LOCS)))
    return me, eyes


MUZZLE_Y0, MUZZLE_K, MUZZLE_DEEP = -0.765, 0.24, 0.16
CARRIAGE = (-0.035, -0.045)       # head forward / down (m): neck ~45 deg, not upright


def head_warp(V):
    """Round 4 space warp after the attributes are set (they are per vertex, so they ride along): the muzzle in
    front of the stop shortened by MUZZLE_K and deepened below its centre line (flews / lower jaw), then the whole
    head carried lower and further forward, blended over the neck."""
    V = np.array(V, float).copy()
    y, z = V[:, 1], V[:, 2]
    m = smoothstep(MUZZLE_Y0, MUZZLE_Y0 - 0.045, y)
    d = np.minimum(y - MUZZLE_Y0, 0.0)
    V[:, 1] = y - MUZZLE_K * d * m
    zc = 0.772
    V[:, 2] = z - MUZZLE_DEEP * np.maximum(zc - z, 0.0) * m * smoothstep(MUZZLE_Y0, MUZZLE_Y0 - 0.08, y)
    c = smoothstep(-0.44, -0.62, V[:, 1]) * smoothstep(0.40, 0.60, V[:, 2])
    V[:, 1] += CARRIAGE[0] * c
    V[:, 2] += CARRIAGE[1] * c
    return V


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


def body_attributes(me, eyes, masks, tag, ear_t, lid_low):
    V = mesh_arrays(me)
    N = vertex_normals(me)
    n = len(V)

    def full(a):
        out = np.zeros(n)
        out[:len(a)] = a
        return out

    names, w, data = chain_fields(V)
    wn = dict(zip(names, w.T))
    y, z = V[:, 1], V[:, 2]
    skin = (tag == TAG_SKIN).astype(float)
    is_ear = (tag == TAG_EAR).astype(float)
    # fur flow: root to tip of each chain, head nose-to-back, sides fall downward; ears root to tip
    flow = np.zeros_like(V)
    for name in names:
        d, axis, t, rad, dirs = data[name]
        if name == "spine":
            f = np.tile([0, 1.0, 0], (len(V), 1))
        elif name in ("neck", "head"):
            f = -dirs                                       # from the nose / head towards the body
        else:
            f = dirs                                        # legs and tail: root to tip
        side = np.abs(N[:, 0:1]) + np.clip(-N[:, 2:3], 0, 1)
        f = f + np.array([0, 0, -1.0]) * (0.9 * side)
        flow += wn[name][:, None] * f
    ear_dir = np.array(EAR_TIP) - np.array(EAR_ROOT)
    ef = np.column_stack([np.sign(V[:, 0]) * ear_dir[0], np.full(n, ear_dir[1]), np.full(n, ear_dir[2])])
    flow = np.where(is_ear[:, None] > 0.5, ef, flow)
    flow -= (np.sum(flow * N, axis=1, keepdims=True)) * N
    flow /= np.maximum(np.linalg.norm(flow, axis=1, keepdims=True), 1e-6)
    longw = long_coat(V, N, names, w, data) * skin
    head_t = data["head"][2]
    short = np.clip(wn["head"] * smoothstep(0.38, 0.55, head_t) + sum(wn[k] * smoothstep(0.55, 0.8, data[k][2])
                                                                       for k in ("fl_l", "fl_r", "hl_l", "hl_r")), 0, 1)
    short *= 1 - longw * 0.7
    short = np.where(is_ear > 0.5, 0.6, short * skin)
    bleach_mask = 1 - full(masks["mouth_inner"])
    bleach = np.clip(N[:, 2], 0, 1) ** 1.5 * (0.55 + 0.45 * longw) * (1 - 0.6 * short)
    bleach *= smoothstep(0.25, 0.6, z) * np.maximum(skin, is_ear) * bleach_mask
    nose, pad, lip, web, brow, mouth_inner = (full(masks[k]) for k in ("nose", "pad", "lip", "web", "brow", "mouth_inner"))
    print("[bosun] nose verts %d, pad verts %d, nails %d verts" % (int((nose > 0.5).sum()), int((pad > 0.5).sum()),
                                                                   int((tag == TAG_NAIL).sum())))
    eye = np.zeros(n)
    eye_r = np.full(n, math.pi)
    iris = np.zeros(n)
    tear = np.zeros(n)
    on_eye = (tag == TAG_EYEBALL) | (tag == TAG_CORNEA)
    for e in eyes:
        rel = V - np.array(e["centre"])
        dist = np.linalg.norm(rel, axis=1)
        mine = on_eye & (dist < 0.02)
        ang = np.arccos(np.clip((rel @ np.array(e["axis"])) / np.maximum(dist, 1e-9), -1, 1))
        eye = np.where(mine, 1.0, eye)
        eye_r = np.where(mine, ang, eye_r)
        iris = np.where(mine, 1 - smoothstep(0.80, 0.88, ang), iris)
        r = V - np.array(e["inner"])
        t1 = np.exp(-(np.linalg.norm(r, axis=1) / 0.0055) ** 2)
        t2 = np.exp(-((r[:, 0] / 0.005) ** 2 + (r[:, 1] / 0.007) ** 2 + ((r[:, 2] + 0.010) / 0.011) ** 2)) * (r[:, 2] < 0.002)
        near = np.linalg.norm(V - np.array(e["loc"]), axis=1) < 0.03
        tear = np.maximum(tear, np.maximum(t1, 0.8 * t2) * near)
    tear = np.maximum(tear, 0.5 * lid_low * (tag == TAG_LID))
    tear *= ~on_eye
    sunfade = np.clip(N[:, 2], 0, 1) ** 1.3 * smoothstep(0.55, 0.70, z) * \
        np.clip(wn["spine"] + wn["neck"] + 0.6 * wn["head"], 0, 1) * skin * (1 - nose)
    sunfade = np.where(is_ear > 0.5, 0.9 * (1 - smoothstep(0.2, 0.55, ear_t)), sunfade)
    fl = lambda k: (tag == k).astype(float)  # noqa: E731
    for name, vals, kind in (("flow", flow, "FLOAT_VECTOR"), ("long", longw, "FLOAT"), ("short", short, "FLOAT"),
                             ("bleach", bleach, "FLOAT"), ("nose", nose, "FLOAT"), ("pad", pad, "FLOAT"),
                             ("lip", lip, "FLOAT"), ("eye", eye, "FLOAT"), ("eye_r", eye_r, "FLOAT"),
                             ("nail", fl(TAG_NAIL), "FLOAT"), ("web", web, "FLOAT"), ("lid", fl(TAG_LID), "FLOAT"),
                             ("cornea", fl(TAG_CORNEA), "FLOAT"), ("iris", iris, "FLOAT"), ("tear", tear, "FLOAT"),
                             ("brow", brow, "FLOAT"), ("ear", is_ear, "FLOAT"), ("sunfade", np.clip(sunfade, 0, 1), "FLOAT"),
                             ("tongue", fl(TAG_TONGUE), "FLOAT"), ("mouth_inner", mouth_inner, "FLOAT")):
        set_attr(me, name, vals, kind)


def withers_height(V):
    sel = (np.abs(V[:, 0]) < 0.05) & (V[:, 1] > -0.34) & (V[:, 1] < -0.22)
    return float(V[sel, 2].max())


# ------------------------------------------------------------------ harness (geometry lives in bosun_harness.py)

def harness_mesh(body_me):
    global HANDLE_APEX, DRING_POS
    import importlib
    import bosun_harness
    importlib.reload(bosun_harness)
    me = bosun_harness.harness_mesh(body_me)
    HANDLE_APEX, DRING_POS = bosun_harness.HANDLE_APEX, bosun_harness.DRING_POS
    return me


# ------------------------------------------------------------------ fur cards

CARD_TYPES = {  # atlas column (4 x 2 cells, rows = two variants, roots at V=0): long wavy clump, medium clump,
    "long": 0, "medium": 1, "short": 2, "plume": 3}    # short tuft, tail plume / feathering
REGIONS = [  # name, count, card type, length range (m), width factor, lift (rad), droop, segments
    # round 5: long on the chest, ruff, belly, legs (feathering); short and flat on the face and ears
    ("under", 1050, "medium", (0.034, 0.052), 0.95, 0.10, 0.35, 1),     # inner layer: short, close to the skin, everywhere
    ("ruff", 330, "long", (0.120, 0.170), 0.52, 0.45, 0.55, 3),
    ("chest", 150, "long", (0.115, 0.165), 0.47, 0.30, 0.85, 3),
    ("back", 150, "medium", (0.060, 0.090), 0.55, 0.20, 0.30, 3),
    ("flank", 135, "medium", (0.070, 0.100), 0.50, 0.18, 0.60, 3),
    ("belly", 120, "long", (0.095, 0.135), 0.45, 0.25, 0.95, 3),
    ("feather", 140, "plume", (0.080, 0.120), 0.45, 0.35, 0.80, 3),
    ("breeches", 160, "long", (0.095, 0.140), 0.50, 0.35, 0.80, 3),
    ("tail", 190, "plume", (0.100, 0.160), 0.55, 0.45, 0.70, 3),
    ("head", 95, "short", (0.018, 0.032), 0.60, 0.18, 0.20, 2),
    ("ear", 70, "short", (0.014, 0.024), 0.70, 0.04, 0.30, 1),       # smooth, flat, short: the ear reads on the ruff
    ("leg", 120, "medium", (0.050, 0.075), 0.55, 0.20, 0.55, 2),
    ("paw", 64, "short", (0.022, 0.032), 0.60, 0.50, 0.40, 2),
    # outer silhouette tiers (tier 2 on the ruff, chest, belly fringe, leg feathering, breeches, tail;
    # tier 3 on the ruff and tail): longer, more lift, so the outline breaks up in 2-3 layers (r5: no ear fringe)
    ("ruff:2", 115, "long", (0.160, 0.215), 0.45, 0.60, 0.65, 3),
    ("chest:2", 60, "long", (0.150, 0.205), 0.42, 0.40, 0.95, 3),
    ("belly:2", 40, "long", (0.125, 0.170), 0.40, 0.30, 1.05, 3),
    ("feather:2", 60, "plume", (0.110, 0.150), 0.42, 0.45, 0.90, 3),
    ("breeches:2", 45, "long", (0.125, 0.170), 0.45, 0.45, 0.90, 3),
    ("tail:2", 70, "plume", (0.140, 0.200), 0.50, 0.60, 0.80, 3),
    ("ruff:3", 40, "long", (0.200, 0.250), 0.40, 0.75, 0.70, 3),
    ("tail:3", 25, "plume", (0.180, 0.240), 0.45, 0.70, 0.85, 3),
]
FUR_TRIS = 14800                     # LOD0 card triangles (dog_fur_cards budget 15,000)
TAPER = {1: [1.0, 0.45], 2: [1.0, 0.72, 0.28], 3: [1.0, 0.86, 0.55, 0.20]}   # round 5: strand-clump taper to a point


def classify_points(C, N, ear):
    """Outer-layer region per triangle centre ('' = inner layer only: muzzle, tail root)."""
    names, w, data = chain_fields(C)
    best = np.array(names)[np.argmax(w, axis=1)]
    y, z, ny, nz = C[:, 1], C[:, 2], N[:, 1], N[:, 2]
    t = {n: data[n][2] for n in names}
    reg = np.full(len(C), "", dtype=object)
    sp = best == "spine"
    fl = np.isin(best, ["fl_l", "fl_r"])
    hl = np.isin(best, ["hl_l", "hl_r"])
    tleg = np.zeros(len(C))
    for n in ("fl_l", "fl_r", "hl_l", "hl_r"):
        tleg = np.where(best == n, t[n], tleg)

    def put(mask, name):
        reg[(reg == "") & mask] = name

    put(ear > 0.5, "ear")
    put((best == "neck") | (sp & (y < -0.33) & (z > 0.47)), "ruff")
    put(sp & (y < -0.25) & (z <= 0.47) & (nz < 0.3), "chest")
    put(sp & (nz < -0.2) & (z < 0.42), "belly")
    put(sp & (nz >= 0.35), "back")
    put(sp, "flank")
    put((fl | hl) & (tleg > 0.84), "paw")
    put(fl & (tleg > 0.15) & (tleg < 0.75) & (ny > 0.15), "feather")
    put(hl & (tleg < 0.58) & (ny > -0.1), "breeches")
    put(fl | hl, "leg")
    put((best == "tail") & (t["tail"] > 0.08), "tail")
    put((best == "head") & (t["head"] < 0.42) & (ny > -0.55), "head")
    return reg


def sample_surface(idx, area, V, tris, count, nprng, reject):
    """Blue-noise (dart throwing) points on the triangles idx: no clumps, no holes. Returns [(tri, bary)]."""
    A = float(area[idx].sum())
    r = 0.56 * math.sqrt(A / count)
    picks = nprng.choice(idx, size=count * 12, p=area[idx] / A)
    R = nprng.random((len(picks), 2))
    flip = R.sum(axis=1) > 1
    R[flip] = 1 - R[flip]
    bary = np.column_stack([1 - R.sum(axis=1), R[:, 0], R[:, 1]])
    P = np.einsum("ij,ijk->ik", bary, V[tris[picks]])
    grid, out, r2 = {}, [], r * r
    for k in range(len(picks)):
        key = tuple(np.floor(P[k] / r).astype(int))
        ok = True
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for q in grid.get((key[0] + dx, key[1] + dy, key[2] + dz), ()):
                        if float(np.sum((q - P[k]) ** 2)) < r2:
                            ok = False
                            break
                    if not ok:
                        break
                if not ok:
                    break
        if not ok or reject(P[k]):
            continue
        grid.setdefault(key, []).append(P[k])
        out.append((picks[k], bary[k]))
        if len(out) >= count:
            break
    return out


def fur_cards(body_me, harness_me):
    """Two layers of alpha cards following the groom (flow): an inner layer of short single-quad tufts lying close to
    the skin over every furred surface (blue-noise, so no holes), and an outer layer of longer bent cards per region
    (ruff, chest, back, flanks, belly fringe, fore-leg feathering, breeches, tail plume, skull, ears, legs, paws).
    Card normals are blended 70/30 toward the body normal for soft shading. Returns card dicts (root, n, verts
    (2*(segs+1), 3), uv, nrm, region, segs, front, size)."""
    rng = random.Random(SEED)
    nprng = np.random.default_rng(SEED)
    me = body_me
    me.calc_loop_triangles()
    V = mesh_arrays(me)
    Nv = vertex_normals(me)
    flow = get_attr(me, "flow", "FLOAT_VECTOR")
    at = {k: get_attr(me, k) for k in ("eye", "lid", "nose", "pad", "nail", "lip", "ear", "short", "tongue",
                                       "mouth_inner")}
    tris = np.array([t.vertices[:] for t in me.loop_triangles])
    A, B, Cc = V[tris[:, 0]], V[tris[:, 1]], V[tris[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(B - A, Cc - A), axis=1)
    cent = (A + B + Cc) / 3
    fn = np.cross(B - A, Cc - A)
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    bare = np.max([at[k][tris].max(axis=1) for k in ("eye", "lid", "nose", "pad", "nail", "tongue", "mouth_inner")],
                  axis=0) > 0.3
    bare |= at["lip"][tris].max(axis=1) > 0.4
    ear_t = at["ear"][tris].min(axis=1)
    bare |= (ear_t > 0.5) & (fn[:, 0] * np.sign(cent[:, 0]) < 0.15)          # ear inner side lies on the head
    bare |= at["ear"][tris].max(axis=1) - ear_t > 0.5                          # ear root seam
    bare |= area < 1e-9
    bare |= (cent[:, 2] < 0.008) & (fn[:, 2] < -0.3)                           # paw soles
    reg = classify_points(cent, fn, ear_t)
    body_tree = bvh_of(me)
    harn_tree = bvh_of(harness_me)
    eye_locs = list(EYE_LOCS) or [np.array(g) for g in EYE_GUESS]
    from mathutils import kdtree
    ear_v = V[at["ear"] > 0.5]
    ear_kd = kdtree.KDTree(max(1, len(ear_v)))
    for i, p in enumerate(ear_v):
        ear_kd.insert(Vector(p.tolist()), i)
    ear_kd.balance()
    cards = []
    for name, count, ctype, (l0, l1), wf, lift, droop, segs in REGIONS:
        inner = name == "under"
        rname = name.split(":")[0]
        idx = np.nonzero(~bare if inner else ~bare & (reg == rname))[0]
        if len(idx) == 0:
            continue
        keep_off = 0.022 if inner else 0.036          # round 5: cards trimmed under / beside the straps (seated)
        ear_off = 0.0 if rname == "ear" else 0.030 if inner else 0.055   # round 5: nothing grows over the ears

        def reject(p):
            hn = harn_tree.find_nearest(Vector(p))
            if hn[0] is not None and hn[3] < keep_off:
                return True
            if ear_off and len(ear_v) and ear_kd.find(Vector(p.tolist()))[2] < ear_off:
                return True
            return min(float(np.linalg.norm(p - e)) for e in eye_locs) < 0.026

        for ti, bary in sample_surface(idx, area, V, tris, count, nprng, reject):
            a, b, c = tris[ti]
            root = bary @ V[[a, b, c]]
            n = bary @ Nv[[a, b, c]]
            n /= np.linalg.norm(n)
            f = bary @ flow[[a, b, c]]
            f = f - (f @ n) * n
            if np.linalg.norm(f) < 1e-4:
                continue
            f /= np.linalg.norm(f)
            sh = float(bary @ at["short"][[a, b, c]])
            L = (l0 + (l1 - l0) * rng.random()) * (1.0 if inner else rng.uniform(0.78, 1.22))   # r5: varied lengths
            kind = ctype
            if inner:
                L *= 1 - 0.45 * sh
                kind = "short" if sh > 0.45 else "medium"
                if float(bary @ at["ear"][[a, b, c]]) > 0.5:
                    L *= 0.55                              # r5: ears: shorter, smoother than the body
            if rname == "tail":
                L *= 0.75 + 0.5 * classify_t(root, "tail")
            W = L * wf * (0.8 + 0.4 * rng.random())
            lf = lift * (0.7 + 0.6 * rng.random())
            dr = droop * (0.6 + 0.8 * rng.random())
            twist = rng.uniform(-0.35, 0.35) if inner else rng.uniform(-0.95, 0.95)
            side = np.cross(n, f)
            side /= np.linalg.norm(side)
            wv = side * math.cos(twist) + n * math.sin(twist)
            d = f * math.cos(lf) + n * math.sin(lf)
            pts = [root - n * (0.004 if inner else 0.006)]
            dirs = []
            for k in range(segs):
                d = d + np.array([0, 0, -1.0]) * (dr * 0.45 * math.sqrt(3.0 / segs))
                d /= np.linalg.norm(d)
                q = pts[-1] + d * (L / segs)
                hit = body_tree.find_nearest(Vector(q))
                if hit[0] is not None:
                    loc, nrm = np.array(hit[0]), np.array(hit[1])
                    if (q - loc) @ nrm < (0.003 if inner else 0.004):
                        q = loc + nrm * (0.003 if inner else 0.004)
                dirs.append(q - pts[-1])
                pts.append(q)
            dirs = [dirs[0]] + dirs
            taper = TAPER[segs]
            col = CARD_TYPES[kind]
            row = rng.randint(0, 1)
            u0, u1 = col / 4 + 0.006, (col + 1) / 4 - 0.006
            v0, v1 = row / 2 + 0.004, (row + 1) / 2 - 0.004
            verts, uvs, nrms = [], [], []
            for k, q in enumerate(pts):
                hw = W * taper[k] / 2
                verts += [q - wv * hw, q + wv * hw]
                vv = v0 + (v1 - v0) * k / segs
                uvs += [(u0, vv), (u1, vv)]
                hit = body_tree.find_nearest(Vector(q))
                nb = np.array(hit[1]) if hit[0] is not None else n
                cf = np.cross(wv, dirs[k])
                cf /= max(np.linalg.norm(cf), 1e-9)
                if cf @ nb < 0:
                    cf = -cf
                nk = 0.7 * nb + 0.3 * cf
                nk /= np.linalg.norm(nk)
                nrms += [nk, nk]
            verts = np.array(verts)
            verts[:, 2] = np.maximum(verts[:, 2], 0.0)
            q0, q1 = verts[0::2], verts[1::2]                  # skip degenerate cards (crushed on the ground / folded)
            ta = np.linalg.norm(np.cross(q1[:-1] - q0[:-1], q0[1:] - q0[:-1]), axis=1)
            tb = np.linalg.norm(np.cross(q1[1:] - q1[:-1], q0[1:] - q1[:-1]), axis=1)
            if min(ta.min(), tb.min()) < 4e-6:
                continue
            cards.append({"root": root, "n": n, "verts": verts, "uv": uvs, "nrm": nrms, "region": name, "segs": segs,
                          "front": root[1] < -0.13, "size": L * W, "group": card_group(root, rname)})
    # hold the LOD0 card budget: drop the smallest inner tufts first
    tot = sum(2 * c["segs"] for c in cards)
    if tot > FUR_TRIS:
        under = sorted([c for c in cards if c["region"] == "under"], key=lambda c: c["size"])
        drop = set()
        for c in under:
            if tot <= FUR_TRIS:
                break
            drop.add(id(c))
            tot -= 2 * c["segs"]
        cards = [c for c in cards if id(c) not in drop]
    counts = {}
    for c in cards:
        counts[c["region"]] = counts.get(c["region"], 0) + 1
    print("[bosun] fur cards %d (%d tris): %s" % (len(cards), sum(2 * c["segs"] for c in cards), counts))
    return cards


def card_group(root, rname):
    """Fur MeshPart of a card (r5): FurHead turns with BodyHead, FurTail moves with Tail, else FurFront / FurRear."""
    p = part_of(root)
    if p == "Head":
        return "FurHead"
    if p == "Tail" or rname == "tail":
        return "FurTail"
    return "FurFront" if root[1] < -0.13 else "FurRear"


def classify_t(p, chain):
    return float(nearest_on_chain(np.array([p]), CHAINS[chain])[2][0])


def cards_mesh(cards, name, width_scale=1.0, length_scale=1.0):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    normals = []
    for c in cards:
        verts = c["verts"].copy()
        rows = len(verts) // 2
        if width_scale != 1.0 or length_scale != 1.0:
            root = (verts[0] + verts[1]) / 2
            for k in range(rows):
                mid = (verts[2 * k] + verts[2 * k + 1]) / 2
                half = (verts[2 * k + 1] - verts[2 * k]) / 2 * width_scale
                mid = root + (mid - root) * length_scale
                verts[2 * k], verts[2 * k + 1] = mid - half, mid + half
        bv = [bm.verts.new((verts[i] * S).tolist()) for i in range(len(verts))]
        normals += [tuple(v) for v in c["nrm"]]
        for k in range(rows - 1):
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
    me.normals_split_custom_set_from_vertices(normals)
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


LEG_LIFT, LEG_Z = 0.032, (0.03, 0.30)   # round 5: longer legs: z in LEG_Z stretched, everything above raised


def leg_warp(V):
    """build metres -> build metres with longer legs (piecewise linear in z, so the inverse is exact)."""
    V = np.array(V, float)
    z = V[..., 2]
    V[..., 2] = z + LEG_LIFT * np.clip((z - LEG_Z[0]) / (LEG_Z[1] - LEG_Z[0]), 0.0, 1.0)
    return V


def leg_unwarp(V):
    V = np.array(V, float)
    z = V[..., 2]
    k = (LEG_Z[1] - LEG_Z[0] + LEG_LIFT) / (LEG_Z[1] - LEG_Z[0])
    V[..., 2] = np.where(z <= LEG_Z[0], z, np.where(z >= LEG_Z[1] + LEG_LIFT, z - LEG_LIFT, LEG_Z[0] + (z - LEG_Z[0]) / k))
    return V


def to_final(p):
    return (leg_warp(p) + XFORM["shift"]) * XFORM["k"] * S


def from_final(p):
    return leg_unwarp(np.asarray(p, float) / (XFORM["k"] * S) - XFORM["shift"])


HANDLE_APEX = DRING_POS = None
MOUTH = (0.0, -0.905, 0.738)


def attachments():
    """ATT_ empties (Roblox Attachments on import): the harness grab handle, the tow-line D-ring, the mouth (CH7 line carry)."""
    made = []
    for name, p in (("ATT_HarnessHandle", HANDLE_APEX), ("ATT_TowRing", DRING_POS), ("ATT_Mouth", MOUTH),
                    ("ATT_TailRoot", TAIL_ROOT)):
        e = bpy.data.objects.new(name, None)
        e.empty_display_size = 0.15
        e.location = tuple(to_final(p))
        bpy.context.scene.collection.objects.link(e)
        made.append(e)
    return made


TAIL_ROOT_Y = 0.11                    # round 5: the tail is its own part from here back (scripted wag / tuck)
TAIL_ROOT = (0.0, TAIL_ROOT_Y, 0.548)  # ATT_TailRoot (build metres): on the tail chain at the split


def parts_of(C):
    """Body split (metres, (N, 3)): head + upper neck, fore body + fore legs, hind body + hind legs, tail."""
    C = np.atleast_2d(np.asarray(C, float))
    names, w, _ = chain_fields(C)
    best = np.array(names)[np.argmax(w, axis=1)]
    out = np.where(C[:, 1] < -0.13, "Fore", "Hind").astype(object)
    out[(best == "tail") & (C[:, 1] > TAIL_ROOT_Y)] = "Tail"
    out[(C[:, 1] < -0.54) & (C[:, 2] > 0.60)] = "Head"
    return out


def part_of(c):
    return parts_of(c)[0]


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
    bm0 = bmesh.new()
    bm0.from_mesh(me)
    lab = parts_of(from_final(np.array([f.calc_center_median()[:] for f in bm0.faces])))
    bm0.free()
    for part in ("Head", "Fore", "Hind", "Tail"):
        bm = bmesh.new()
        bm.from_mesh(me)
        kill = [f for f, l in zip(bm.faces, lab) if l != part]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bmesh.ops.delete(bm, geom=[ed for ed in bm.edges if not ed.link_faces], context="EDGES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        name = "%s_%s_%s" % (base, "Tail" if part == "Tail" else "Body" + part, lod_suffix)   # r5: Tail part
        pme = bpy.data.meshes.new(name)
        bm.to_mesh(pme)
        bm.free()
        for p in pme.polygons:
            p.use_smooth = True
        Vp = mesh_arrays(pme)
        pme.normals_split_custom_set_from_vertices([tuple(Nn[kd.find(v)[1]]) for v in Vp])
        parts[part] = new_object(name, pme)
    return parts
