"""M_Ani_GreySeal ("Old Ned") geometry, armature and skinning (Blender; no bpy.ops mesh editing).

Grey seal bull (Halichoerus grypus), authored in metres with the shape maths in seal_shape.py, then scaled to studs
and centred on its bounding box by build.py. Front is -Y, up is +Z.

Two meshes, one texture set each (the pipeline allows one material per mesh):
  M_Ani_GreySeal_Body_LOD0   set Coat: the body from the tail tip through the chest and the fore-flippers to the
                             fold valley at the neck, plus the four flippers and the back stud
  M_Ani_GreySeal_Head_LOD0   set Face: the neck folds, skull, the long convex Roman nose muzzle, the eyes, the
                             nostrils' pads (r1: whiskers are painted dots)
The two tubes share the station at y -0.575 and the neck ripple at that station is a valley, so the seam sits inside a
fold and both meshes carry the same weights there: the neck bends without a gap. The nose and tail tips are capped;
r1 (2026-11-01) made it a toy: rounded-box sections, a blocky muzzle, slab flippers, big bead eyes, a stud.

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


def surface(B, stations, regions, region, part, flip=False, s_of=None, tus=None):
    """stations[i][j] = (co, tv): an (nu x nv) closed-in-j tube. Returns the row lists (index, uv)."""
    nu, nv = len(stations), len(stations[0])
    rows = []
    for i, st in enumerate(stations):
        tu = float(tus[i]) if tus is not None else i / float(nu - 1)
        row = []
        for j, (co, tv) in enumerate(st):
            s = s_of(i, j) if s_of else tu
            row.append((B.v(co, part, s), uv_of(regions, region, tu, tv)))
        rows.append(row)
    v_end = regions[region][3]
    for i in range(nu - 1):
        for j in range(nv):
            j2 = (j + 1) % nv
            a, b = rows[i][j], rows[i][j2]
            c, d = rows[i + 1][j2], rows[i + 1][j]
            buv, cuv = (b[1], c[1]) if j2 else ((b[1][0], v_end), (c[1][0], v_end))   # the wrap face ends at v = 1
            B.face([a[0], b[0], c[0], d[0]], [a[1], buv, cuv, d[1]], flip)
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


def sph(B, centre, r, rings, sides, regions, region, part, s=0.0, anchor=None, mx=1.0):
    """Small UV sphere (an eye): latitude rings between two fans. mx -1 mirrors it in x (the right eye), so both
    eyes share one painted catch-light that sits up front and outward."""
    rows = []
    for i in range(1, rings):
        lat = math.pi * i / rings
        st = []
        for j in range(sides):
            lon = 2.0 * math.pi * j / sides
            st.append(((centre[0] + mx * r * math.sin(lat) * math.cos(lon),
                        centre[1] + r * math.sin(lat) * math.sin(lon),
                        centre[2] + r * math.cos(lat)), j / float(sides)))
        rows.append(st)
    uvl = [[(co, tv) for co, tv in st] for st in rows]
    nu, nv = len(uvl), len(uvl[0])
    grid = []
    for i, st in enumerate(uvl):
        tu = i / float(nu - 1)
        grid.append([(B.v(co, part, s, anchor=anchor), uv_of(regions, region, tu, tv)) for co, tv in st])
    v_end = regions[region][3]
    for i in range(nu - 1):
        for j in range(nv):
            j2 = (j + 1) % nv
            a, b = grid[i][j], grid[i][j2]
            c, d = grid[i + 1][j2], grid[i + 1][j]
            buv, cuv = (b[1], c[1]) if j2 else ((b[1][0], v_end), (c[1][0], v_end))
            B.face([a[0], b[0], c[0], d[0]], [a[1], buv, cuv, d[1]])
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
            ox, oz = S.rr(ang, w, h, spec["bevel"])
            p = c + u1 * float(ox) + u2 * float(oz) + a * ext
            st.append((tuple(p), j / float(n)))
        sts.append(st)
    grid = surface(B, sts, regions, spec["region"], part,
                   s_of=lambda i, j: max(0.0, secs[i][0]), flip=(spec["side"] < 0), tus=S.ring_tus(spec))
    cap_fan(B, grid[0], tuple(S.flipper_centre(spec, -0.20, a, u1)), regions, spec["region"], (0.02, 0.5), 0.03,
            flip=True)
    if spec.get("front"):                   # r4: a flat front face, UVs projected straight on (LODs keep its area)
        c = S.flipper_centre(spec, 1.0, a, u1)
        w, h = secs[-1][1], secs[-1][2]
        uv = lambda p: uv_of(regions, spec["front"], 0.5 + float((np.asarray(p) - c) @ u1) / (2 * w),
                             0.5 + float((np.asarray(p) - c) @ u2) / (2 * h))
        ci = B.v(tuple(c), part, 1.0)
        for k in range(n):
            i0, i1 = grid[-1][k][0], grid[-1][(k + 1) % n][0]
            B.face([ci, i0, i1], [uv(c), uv(B.verts[i0]), uv(B.verts[i1])])
        return
    cap_fan(B, grid[-1], tuple(S.flipper_centre(spec, 1.0, a, u1) + a * (sc * 0.5)), regions, spec["region"],
            (0.97, 0.5), 0.03)


def eyes(B, regions):
    for side in (+1.0, -1.0):
        c = S.eye_centre(side)
        sph(B, c, S.EYE_R, 8, 16, regions, "EYE", "eye", s=0.0, anchor=c, mx=side)


# r5: studs 0.72 stud across, 0.32 tall, on a wider 1x3 plate centred on the spine; the plate's top sits flat on the
# flat back panel with a 0.05 stud lip. r6: moved back onto the flat (unbent) back, so the three studs stand level
STUD_YS, STUD_R, STUD_H, STUD_SINK = (0.600, 0.320, 0.040), 0.120, 0.107, 0.030
STUD_LIP = 0.018                                                 # a crisp bevel lip
PLATE_Y, PLATE_W, PLATE_T, PLATE_D, PLATE_B = (0.740, -0.100), 0.158, 0.050, 0.050, 0.017


def _crest(y):
    zc, rx, rz, flat, u = S.rows_at_y("body", y)
    return zc + rz                                            # the back's crest at this y


def plate(B, regions, n=24):
    """r4: a bevelled 1x3 plate following the back's crest, PLATE_T proud, its underside sunk PLATE_D into the body."""
    y0, y1 = PLATE_Y
    ends = [(0.0, PLATE_B), (0.005, 0.004), (0.015, 0.0)]            # (distance in from the end, inset): the end bevel
    rows = [(y0 - d, k) for d, k in ends] + [(y, 0.0) for y in np.linspace(y0 - 0.06, y1 + 0.06, 5)] + \
        [(y1 + d, k) for d, k in ends[::-1]]
    hh = 0.5 * (PLATE_T + PLATE_D)
    sts = []
    for y, k in rows:
        zc = _crest(y) + 0.5 * (PLATE_T - PLATE_D)
        st = []
        for j in range(n):
            ox, oz = S.rr(2.0 * math.pi * j / n, PLATE_W - k, hh - k, PLATE_B)
            st.append(((float(ox), y, zc + float(oz)), j / float(n)))
        sts.append(st)
    grid = surface(B, sts, regions, "STUD", "body", s_of=lambda i, j: 0.0)
    cap_fan(B, grid[0], (0.0, rows[0][0], _crest(rows[0][0]) + 0.5 * (PLATE_T - PLATE_D)), regions, "STUD",
            (0.5, 0.5), 0.3, flip=True)
    cap_fan(B, grid[-1], (0.0, rows[-1][0], _crest(rows[-1][0]) + 0.5 * (PLATE_T - PLATE_D)), regions, "STUD",
            (0.5, 0.5), 0.3)


def stud(B, regions, n=24):
    """Bevelled Lego studs on the plate: cylinders sunk into it with a chamfered top edge and a flat cap."""
    plate(B, regions)
    for sy in STUD_YS:
        top = _crest(sy) + PLATE_T                            # the plate's top at this y
        c = (0.0, sy, top)
        prof = [(STUD_R, -STUD_SINK), (STUD_R, STUD_H - STUD_LIP), (STUD_R - STUD_LIP, STUD_H)]
        sts = [[((c[0] + r * math.cos(2 * math.pi * j / n), c[1] + r * math.sin(2 * math.pi * j / n), top + dz),
                 j / float(n)) for j in range(n)] for r, dz in prof]
        grid = surface(B, sts, regions, "STUD", "body", s_of=lambda i, j: 0.0)
        for row in grid:                                      # weights read at the stud's centre: it rides the spine
            for vi, _ in row:
                B.anchor[vi] = c
        cap_fan(B, grid[-1], (c[0], c[1], top + STUD_H), regions, "STUD", (0.5, 0.5), 0.3, anchor=c)


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
    stud(Bb, regions_coat)
    ob_body = mesh_object(name_body, Bb, S.bend(Bb.verts))

    Bh = Builder()
    tip = S.stations("head")[-1]
    tube(Bh, "head", N_HEAD, regions_face, "HEAD", "head", cap_last=(0.0, tip["y"] - 0.0015, tip["zc"]))
    n_tube = len(Bh.verts)
    Vh = np.asarray(Bh.verts, float)
    Vh[:n_tube] = S.warp_points(Vh[:n_tube])
    Bh.verts = [tuple(v) for v in Vh]
    eyes(Bh, regions_face)                  # r1: whisker prisms dropped (unreadable); painted whisker-pad dots instead
    for spec in (S.MUZZLE, S.NOSE):         # r3: the cream muzzle box and the black nose block on the face plane
        flipper(Bh, spec, regions_face)
    ob_head = mesh_object(name_head, Bh, S.bend(Bh.verts))     # r2: the arched rest pose
    return ob_body, ob_head, Bb, Bh


# ---------------------------------------------------------------- armature
BONES = {                                   # name: (head, tail, parent); metres, build space
    "Root": ((0.0, 0.400, 0.290), (0.0, -0.020, 0.290), None),
    "Spine_1": ((0.0, 0.800, 0.280), (0.0, 0.380, 0.290), "Root"),
    "Spine_2": ((0.0, 0.380, 0.290), (0.0, -0.060, 0.292), "Spine_1"),
    "Chest": ((0.0, -0.060, 0.292), (0.0, -0.440, 0.294), "Spine_2"),
    "Neck": ((0.0, -0.440, 0.294), (0.0, -0.760, 0.306), "Chest"),
    "Head": ((0.0, -0.760, 0.306), (0.0, -1.000, 0.316), "Neck"),
    "Jaw": ((0.0, -1.050, 0.120), (0.0, -1.250, 0.110), "Head"),     # r3: hinged at the muzzle box's mouth line
    "Tail": ((0.0, 0.960, 0.260), (0.0, 1.100, 0.250), "Spine_1"),
}


def _flipper_bones():
    """r2: each flipper chain runs down its blade's axis (root, 45 %, tip), so the bones follow the new paddles."""
    for spec, chain in ((S.FLIPPERS[0], "FlipperF"), (S.FLIPPERS[1], "FlipperH")):
        for side, sx in (("L", 1.0), ("R", -1.0)):
            a = S._n(spec["axis"]) * np.array([sx, 1.0, 1.0])
            r = np.asarray(spec["root"], float) * np.array([sx, 1.0, 1.0])
            p0, p1, p2 = (tuple(r + a * spec["length"] * t) for t in (0.0, 0.45, 1.0))
            parent = "Chest" if chain == "FlipperF" else "Spine_1"
            BONES["%s_%s_1" % (chain, side)] = (p0, p1, parent)
            BONES["%s_%s_2" % (chain, side)] = (p1, p2, "%s_%s_1" % (chain, side))


_flipper_bones()


def build_rig(scale, off=(0.0, 0.0, 0.0)):
    arm = bpy.data.armatures.new("RIG_Seal")
    rig = bpy.data.objects.new("RIG_Seal", arm)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for bname, (head, tail, parent) in BONES.items():
        eb = arm.edit_bones.new(bname)
        head, tail = S.bend([head, tail])                    # r2: the bones follow the arched rest pose
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
JAW_GATE = (-1.030, -1.090)                 # r3: only the muzzle box out in front of the face plane


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


def jaw_weight(x, y, z):
    """How much of the lower jaw (the muzzle box under the painted mouth line) this vertex is."""
    return float(S.ss(JAW_GATE[0], JAW_GATE[1], y)) * float(S.ss(0.002, 0.030, S.MOUTH_Z - z))


def weights_for(tag, co, anchor):
    """{bone: weight} for one vertex, from its part tag and the anchor position (metres). Always sums to 1."""
    part, s = tag
    x, y, z = anchor
    if part in ("body", "head") or part.startswith("whisk") or part == "eye":
        w = spine_weights(y)
        if part != "body":
            jw = 0.0 if part == "eye" else jaw_weight(x, y, z)
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


