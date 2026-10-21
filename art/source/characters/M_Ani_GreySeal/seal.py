"""M_Ani_GreySeal ("Old Ned") geometry, armature and skinning (Blender; no bpy.ops mesh editing).

Grey seal bull (Halichoerus grypus), authored in metres with the shape maths in seal_shape.py, then scaled to studs
and centred on its bounding box by build.py. Front is -Y, up is +Z.

Two meshes, one texture set each (the pipeline allows one material per mesh):
  M_Ani_GreySeal_Body_LOD0   set Coat: the body from the tail tip through the chest and the fore-flippers to the
                             fold valley at the neck, plus the four flippers and their claws
  M_Ani_GreySeal_Head_LOD0   set Face: the neck folds, skull, the long convex Roman nose muzzle, the eyes, the
                             nostrils' pads and the rows of whiskers
The two tubes share the station at y -0.575 and the neck ripple at that station is a valley, so the seam sits inside a
fold and both meshes carry the same weights there: the neck bends without a gap. The nose and tail tips are capped;
the muzzle, the whiskers, the claws and the flipper tips carry the species detail that all the character is in.

Skinning is analytic (RIG_Seal): a smooth partition over the spine bones, a jaw weight under the mouth line, and
flipper chains that blend into the body weights at the root so the joints cannot crack.
"""
import math

import bmesh
import bpy
import numpy as np

import seal_shape as S

M = 1.0                                     # metres here; build.py multiplies by common.STUDS_PER_METRE
N_BODY = 48                                 # points around the body
N_HEAD = 48
N_FLIP = 24                                 # points around a flipper
N_WHISK = 3                                 # a whisker is a thin three-sided prism


class Builder:
    def __init__(self):
        self.verts = []
        self.faces = []                     # (indices, [uv per loop])
        self.tag = []                       # (part, s) per vertex
        self.anchor = []                    # the position the weights are read at (whiskers, claws: their root)

    def v(self, co, part, s=0.0, anchor=None):
        self.verts.append((float(co[0]), float(co[1]), float(co[2])))
        self.tag.append((part, float(s)))
        self.anchor.append(tuple(anchor) if anchor is not None else
                           (float(co[0]), float(co[1]), float(co[2])))
        return len(self.verts) - 1

    def face(self, idx, uvs, flip=False):
        if flip:
            idx = list(idx)[::-1]
            uvs = list(uvs)[::-1]
        self.faces.append((tuple(idx), list(uvs)))


def uv_of(regions, region, tu, tv):
    u0, v0, u1, v1 = regions[region]
    return (u0 + tu * (u1 - u0), v0 + tv * (v1 - v0))


def surface(B, stations, regions, region, part, flip=False, s_of=None):
    """stations[i][j] = (co, tv): an (nu x nv) closed-in-j tube. Returns the row lists (index, uv)."""
    nu, nv = len(stations), len(stations[0])
    rows = []
    for i, st in enumerate(stations):
        tu = i / float(nu - 1)
        row = []
        for j, (co, tv) in enumerate(st):
            s = s_of(i, j) if s_of else tu
            row.append((B.v(co, part, s), uv_of(regions, region, tu, tv)))
        rows.append(row)
    for i in range(nu - 1):
        for j in range(nv):
            j2 = (j + 1) % nv
            a, b = rows[i][j], rows[i][j2]
            c, d = rows[i + 1][j2], rows[i + 1][j]
            B.face([a[0], b[0], c[0], d[0]], [a[1], b[1], c[1], d[1]], flip)
    return rows


def cap_fan(B, row, centre_co, regions, region, uv_c, radius=0.03, flip=False, anchor=None):
    """Closes a tube end with a fan; the ring's UVs are replaced by a small disc so no face has zero UV area."""
    part, s = B.tag[row[0][0]]
    c = B.v(centre_co, part, s, anchor=anchor)
    n = len(row)
    idx, uvs = [], []
    for k, (vi, _) in enumerate(row):
        a = 2.0 * math.pi * k / n
        idx.append(vi)
        uvs.append(uv_of(regions, region, uv_c[0] + radius * math.cos(a), uv_c[1] + radius * math.sin(a)))
    for k in range(n):
        k2 = (k + 1) % n
        cuv = uv_of(regions, region, uv_c[0], uv_c[1])
        B.face([c, idx[k], idx[k2]], [cuv, uvs[k], uvs[k2]], flip)


def ring(which, row, n):
    """One station as n points around (0 top, .25 right, .5 belly, .75 left), sampled from seal_shape.point so the
    loft and the paint can never disagree."""
    v = np.arange(n) / float(n)
    x, y, z = S.surface(which, np.full(n, row["u"]), v)
    return [((float(x[j]), float(y[j]), float(z[j])), j / float(n)) for j in range(n)]


def sph(B, centre, r, rings, sides, regions, region, part, s=0.0, anchor=None):
    """Small UV sphere (an eye): latitude rings between two fans."""
    rows = []
    for i in range(1, rings):
        lat = math.pi * i / rings
        st = []
        for j in range(sides):
            lon = 2.0 * math.pi * j / sides
            st.append(((centre[0] + r * math.sin(lat) * math.cos(lon),
                        centre[1] + r * math.sin(lat) * math.sin(lon),
                        centre[2] + r * math.cos(lat)), j / float(sides)))
        rows.append(st)
    uvl = [[(co, tv) for co, tv in st] for st in rows]
    nu, nv = len(uvl), len(uvl[0])
    grid = []
    for i, st in enumerate(uvl):
        tu = i / float(nu - 1)
        grid.append([(B.v(co, part, s, anchor=anchor), uv_of(regions, region, tu, tv)) for co, tv in st])
    for i in range(nu - 1):
        for j in range(nv):
            j2 = (j + 1) % nv
            a, b = grid[i][j], grid[i][j2]
            c, d = grid[i + 1][j2], grid[i + 1][j]
            B.face([a[0], b[0], c[0], d[0]], [a[1], b[1], c[1], d[1]])
    cap_fan(B, grid[0], (centre[0], centre[1], centre[2] + r), regions, region, (0.5, 0.93), 0.02, anchor=anchor)
    cap_fan(B, grid[-1], (centre[0], centre[1], centre[2] - r), regions, region, (0.5, 0.07), 0.02, flip=True,
            anchor=anchor)


# ---------------------------------------------------------------- the two lofts
COAT = {}                                   # filled by build.py (region rectangles per set)
FACE = {}


def tube(B, which, n, regions, region, part, cap_first=None, cap_last=None):
    rows = S.stations(which)
    sts = [ring(which, r, n) for r in rows]
    grid = surface(B, sts, regions, region, part, s_of=lambda i, j: rows[i]["u"])
    if cap_first is not None:
        cap_fan(B, grid[0], cap_first, regions, region, (0.02, 0.5), 0.02, flip=True)
    if cap_last is not None:
        cap_fan(B, grid[-1], cap_last, regions, region, (0.98, 0.5), 0.02)
    return grid


# ---------------------------------------------------------------- flippers (the sections live in seal_shape)
def _norm(v):
    v = np.asarray(v, float)
    return v / max(float(np.linalg.norm(v)), 1e-9)


def flipper(B, spec, regions, n=N_FLIP):
    a, u1, u2 = S.flipper_frame(spec)
    part = spec["part"]
    sc = spec.get("scallop", 0.0)
    secs = [(-0.20, spec["secs"][0][1] * 0.72, spec["secs"][0][2] * 0.72)] + spec["secs"]
    sts = []
    for t, w, h in secs:
        c = S.flipper_centre(spec, t, a, u1)
        st = []
        for j in range(n):
            ang = 2.0 * math.pi * j / n
            # the hind blade's five digit lobes: the trailing edge grows them over the last fifth of the span
            ext = sc * max(0.0, (t - 0.78) / 0.22) * (0.5 + 0.5 * math.cos(5.0 * math.pi * math.sin(ang)))
            p = c + u1 * (w * math.sin(ang)) + u2 * (h * math.cos(ang)) + a * ext
            st.append((tuple(p), j / float(n)))
        sts.append(st)
    grid = surface(B, sts, regions, spec["region"], part,
                   s_of=lambda i, j: max(0.0, secs[i][0]), flip=(spec["side"] < 0))
    cap_fan(B, grid[0], tuple(S.flipper_centre(spec, -0.20, a, u1)), regions, spec["region"], (0.02, 0.5), 0.03,
            flip=True)
    cap_fan(B, grid[-1], tuple(S.flipper_centre(spec, 1.0, a, u1) + a * (sc * 0.5)), regions, spec["region"],
            (0.97, 0.5), 0.03)
    anchor = tuple(spec["root"])
    for k in range(spec["claws"]):
        base, direction = S.claw_points(spec, k)
        q = (k - (spec["claws"] - 1) / 2.0) / max(1.0, (spec["claws"] - 1) / 2.0)
        base = base + a * (sc * (0.5 + 0.5 * math.cos(5.0 * math.pi * q * 0.8)))
        claw(B, base, direction, spec["claw_len"], spec["claw_r"], regions, part, 1.0, anchor)


def claw(B, base, direction, length, r, regions, part, s, anchor, n=5):
    """A small pointed claw: a five-sided cone with a base cap."""
    a = _norm(direction)
    ref = np.array([0.0, 0.0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u1 = _norm(ref - a * float(ref @ a))
    u2 = _norm(np.cross(a, u1))
    base = np.asarray(base, float)
    sts = [(0.0, r, 0.0), (0.45, r * 0.66, length * 0.45), (0.80, r * 0.34, length * 0.80), (1.0, r * 0.10, length)]
    rows = []
    for t, rr, d in sts:
        c = base + a * d
        st = [(tuple(c + u1 * (rr * math.cos(2 * math.pi * j / n)) + u2 * (rr * math.sin(2 * math.pi * j / n))),
               j / float(n)) for j in range(n)]
        rows.append(st)
    grid = surface(B, rows, regions, "CLAW", part, s_of=lambda i, j: s)
    cap_fan(B, grid[0], tuple(base), regions, "CLAW", (0.5, 0.06), 0.04, flip=True, anchor=anchor)
    cap_fan(B, grid[-1], tuple(base + a * (length * 1.06)), regions, "CLAW", (0.5, 0.94), 0.04, anchor=anchor)


# ---------------------------------------------------------------- whiskers
def whisker(B, root, direction, length, r0, regions, part, s=0.0, bow=(0.0, 0.30, -0.40), n=N_WHISK,
            root_sink=0.0):
    """One vibrissa: a thin three-sided tapered prism that arcs out, back and down from its root.
    Modelled rather than alpha-carded (the row allows both): at this size the prism holds up in every view."""
    a = _norm(direction)
    ref = np.array([0.0, 0.0, 1.0]) if abs(a[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u1 = _norm(ref - a * float(ref @ a))
    u2 = _norm(np.cross(a, u1))
    root = np.asarray(root, float)
    bv = np.asarray(bow, float)
    bv = bv / max(float(np.linalg.norm(bv)), 1e-9)
    if root_sink:                                   # plant the base under the skin so no seam shows at the pore
        zc = S.rows_at_y("head", float(root[1]))[0]
        inward = np.array([-root[0], 0.0, zc - root[2]])
        root = root + inward / max(float(np.linalg.norm(inward)), 1e-9) * root_sink
    prof = [(0.0, 1.00, 0.0), (0.35, 0.70, 0.16), (0.70, 0.38, 0.50), (1.0, 0.07, 0.92)]
    rows = []
    for t, rr, bend in prof:
        c = root + a * (length * t) + bv * (length * 0.55 * bend)
        st = [(tuple(c + u1 * (r0 * rr * math.cos(2 * math.pi * j / n)) + u2 * (r0 * rr * math.sin(2 * math.pi * j / n))),
               j / float(n)) for j in range(n)]
        rows.append(st)
    grid = surface(B, rows, regions, "WHISK", part, s_of=lambda i, j: s)
    cap_fan(B, grid[0], tuple(root), regions, "WHISK", (0.5, 0.08), 0.04, flip=True, anchor=tuple(root))
    cap_fan(B, grid[-1], tuple(root + a * (length * 1.02) + bv * (length * 0.55 * 0.92)), regions, "WHISK",
            (0.5, 0.92), 0.04, anchor=tuple(root))


def whiskers(B, regions):
    """Eight short, fine whiskers a side in rows over the muzzle pads (80 to 120 mm, swept back and down, gently
    curved), plus three short brow hairs above each eye. Modelled, not alpha-carded (the row allows both)."""
    for side in (+1.0, -1.0):
        part = "whiskL" if side > 0 else "whiskR"
        for y, a_deg in S.WHISKER_ROWS:
            root = S.whisker_root(y, a_deg, side)
            fwd = float(S.ss(-1.035, -1.275, y))                # the nose-most are the longest
            length = 0.080 + 0.034 * fwd
            direction = (side * 0.66, 0.26 + 0.12 * (1.0 - fwd), -0.30)
            whisker(B, root, direction, length, 0.00082, regions, part, s=y, bow=(0.0, 0.42, -0.86),
                    root_sink=0.004)
        for y, a_deg in S.BROW_ROWS:
            root = S.whisker_root(y, a_deg, side)
            whisker(B, root, (side * 0.56, 0.54, 0.44), 0.026, 0.00070, regions, part, s=y,
                    bow=(0.0, 0.18, -0.34), root_sink=0.004)


def eyes(B, regions):
    for side in (+1.0, -1.0):
        c = S.eye_centre(side)
        sph(B, c, S.EYE_R, 5, 12, regions, "EYE", "eye", s=0.0, anchor=c)


# ---------------------------------------------------------------- mesh assembly
def mesh_object(name, B, V, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in V], [], [f[0] for f in B.faces])
    me.validate(verbose=False)
    me.update()
    if len(me.polygons) != len(B.faces):
        raise RuntimeError("%s: %d of %d faces survived validate (a zero-area or duplicate face)"
                           % (name, len(me.polygons), len(B.faces)))
    uvl = me.uv_layers.new(name="UVMap")
    for poly, (_, uvs) in zip(me.polygons, B.faces):
        for k, li in enumerate(poly.loop_indices):
            uvl.data[li].uv = uvs[k]
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    me.update()
    return ob


def mirror_spec(spec):
    m = dict(spec)
    m["part"] = spec["part"][:-1] + "R"
    m["side"] = -1.0
    m["root"] = (-spec["root"][0], spec["root"][1], spec["root"][2])
    m["axis"] = (-spec["axis"][0], spec["axis"][1], spec["axis"][2])
    return m


def build_meshes(name_body, name_head, regions_coat, regions_face):
    """(body_object, head_object, Builder_body, Builder_head). Two MeshParts, one texture set each."""
    global COAT, FACE
    COAT, FACE = regions_coat, regions_face

    Bb = Builder()
    tail_c = S.stations("body")[0]
    tube(Bb, "body", N_BODY, regions_coat, "BODY", "body",
         cap_first=(0.0, tail_c["y"] + 0.020, tail_c["zc"] + 0.002))
    for spec in S.FLIPPERS:
        flipper(Bb, spec, regions_coat)
        flipper(Bb, mirror_spec(spec), regions_coat)
    ob_body = mesh_object(name_body, Bb, np.asarray(Bb.verts, float))

    Bh = Builder()
    tube(Bh, "head", N_HEAD, regions_face, "HEAD", "head", cap_last=(0.0, -1.216, 0.309))
    n_tube = len(Bh.verts)
    Vh = np.asarray(Bh.verts, float)
    Vh[:n_tube] = S.warp_points(Vh[:n_tube])
    Bh.verts = [tuple(v) for v in Vh]
    whiskers(Bh, regions_face)
    eyes(Bh, regions_face)
    ob_head = mesh_object(name_head, Bh, np.asarray(Bh.verts, float))
    return ob_body, ob_head, Bb, Bh


# ---------------------------------------------------------------- armature
BONES = {                                   # name: (head, tail, parent); metres, build space
    "Root": ((0.0, 0.400, 0.290), (0.0, -0.020, 0.290), None),
    "Spine_1": ((0.0, 0.800, 0.280), (0.0, 0.380, 0.290), "Root"),
    "Spine_2": ((0.0, 0.380, 0.290), (0.0, -0.060, 0.292), "Spine_1"),
    "Chest": ((0.0, -0.060, 0.292), (0.0, -0.440, 0.294), "Spine_2"),
    "Neck": ((0.0, -0.440, 0.294), (0.0, -0.760, 0.306), "Chest"),
    "Head": ((0.0, -0.760, 0.306), (0.0, -1.000, 0.316), "Neck"),
    "Jaw": ((0.0, -0.920, 0.300), (0.0, -1.170, 0.290), "Head"),
    "Tail": ((0.0, 0.960, 0.260), (0.0, 1.100, 0.250), "Spine_1"),
    "FlipperF_L_1": ((0.190, -0.140, 0.135), (0.235, 0.040, 0.092), "Chest"),
    "FlipperF_L_2": ((0.235, 0.040, 0.092), (0.279, 0.220, 0.050), "FlipperF_L_1"),
    "FlipperF_R_1": ((-0.190, -0.140, 0.135), (-0.235, 0.040, 0.092), "Chest"),
    "FlipperF_R_2": ((-0.235, 0.040, 0.092), (-0.279, 0.220, 0.050), "FlipperF_R_1"),
    "FlipperH_L_1": ((0.060, 0.850, 0.185), (0.081, 1.070, 0.158), "Spine_1"),
    "FlipperH_L_2": ((0.081, 1.070, 0.158), (0.103, 1.290, 0.131), "FlipperH_L_1"),
    "FlipperH_R_1": ((-0.060, 0.850, 0.185), (-0.081, 1.070, 0.158), "Spine_1"),
    "FlipperH_R_2": ((-0.081, 1.070, 0.158), (-0.103, 1.290, 0.131), "FlipperH_R_1"),
}


def build_rig(scale, off=(0.0, 0.0, 0.0)):
    arm = bpy.data.armatures.new("RIG_Seal")
    rig = bpy.data.objects.new("RIG_Seal", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bname, (head, tail, parent) in BONES.items():
        eb = arm.edit_bones.new(bname)
        eb.head = [(c + o) * scale for c, o in zip(head, off)]
        eb.tail = [(c + o) * scale for c, o in zip(tail, off)]
        eb.roll = 0.0
    for bname, (_, _, parent) in BONES.items():
        if parent:
            arm.edit_bones[bname].parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'OCTAHEDRAL'
    return rig


SPINE_BONES = [                             # (bone, the y where it rules, how far its influence reaches): a partition
    ("Head", -1.020, 0.460),
    ("Neck", -0.600, 0.300),
    ("Chest", -0.240, 0.300),
    ("Spine_2", 0.150, 0.320),
    ("Spine_1", 0.570, 0.420),
    ("Tail", 0.965, 0.160),
]
JAW_GATE = (-0.800, -0.940)


def spine_weights(y):
    w = {}
    for name, c, d in SPINE_BONES:
        k = float(S.ss(1.0, 0.0, abs(y - c) / d))
        if k > 1e-4:
            w[name] = k
    if not w:
        w = {min(SPINE_BONES, key=lambda b: abs(y - b[1]))[0]: 1.0}
    tot = sum(w.values())
    return {k: v / tot for k, v in w.items()}


def jaw_weight(y, z):
    """How much of the lower jaw (the chin and the lower muzzle under the mouth line) this vertex is."""
    mz = float(S.mouth_z(y))
    return float(S.ss(JAW_GATE[0], JAW_GATE[1], y)) * float(S.ss(0.002, 0.045, mz - z))


def weights_for(tag, co, anchor):
    """{bone: weight} for one vertex, from its part tag and the anchor position (metres). Always sums to 1."""
    part, s = tag
    x, y, z = anchor
    if part in ("body", "head") or part.startswith("whisk") or part == "eye":
        w = spine_weights(y)
        if part != "body":
            jw = 0.0 if part == "eye" else jaw_weight(y, z)
            if jw > 1e-4:
                w = {k: v * (1.0 - jw) for k, v in w.items()}
                w["Jaw"] = jw
        return w
    if part.startswith("fore") or part.startswith("hind"):
        side = "L" if part.endswith("L") else "R"
        chain = ("FlipperF_%s" % side) if part.startswith("fore") else ("FlipperH_%s" % side)
        kf = float(S.ss(0.06, 0.34, s))
        w = {}
        if kf < 0.999:
            w = {k: v * (1.0 - kf) for k, v in spine_weights(y).items()}
        if kf > 1e-4:
            k2 = float(S.ss(0.38, 0.70, s))
            w[chain + "_2"] = kf * k2
            w[chain + "_1"] = kf * (1.0 - k2)
        return w
    return {"Head": 1.0}


def skin(ob, B, rig):
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    groups = {bname: ob.vertex_groups.new(name=bname) for bname in BONES}
    for i, (tag, co) in enumerate(zip(B.tag, B.verts)):
        anchor = B.anchor[i]
        w = {k: v for k, v in weights_for(tag, co, anchor).items() if v > 1e-4}
        tot = sum(w.values())
        for bname, weight in w.items():
            groups[bname].add([i], weight / tot, 'REPLACE')
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    mod.use_deform_preserve_volume = False
    return rig


