"""M_Chr_Bosun_LP: Bosun, the black water-rescue dog, low-poly Roblox-character style.

One bevelled mesh per BosunRig PartSpec, authored in that part's rest frame (studs, origin between
the feet, front -Z, up +Y, his right +X) and exported in the pipeline's Roblox mapping. The rig and
BosunMotion are unchanged: every mesh fills its PartSpec box around the rest pivot, so the existing
Motor6Ds articulate the segments. Harness pieces stay separate (BosunRig.harness = true).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/characters/M_Chr_Bosun_LP/build.py --out-root build/prod/M_Chr_Bosun_LP \
      --steps build,lod,validate,export,turntable
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
import names

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
ASSET = "M_Chr_Bosun_LP"
PREFIX = "M_Chr_Bosun_" + "LP_"          # M_Chr_Bosun_LP_<Part>
SHIFT_Y = 0.0                             # set from the measured bbox (feet stay on z = 0)

COAT = "#1E1C1E"
NOSE = "#0C0C0D"
EYE = "#3B2414"
TONGUE = "#C9707E"
HARNESS = "#FF6600"
WEBBING = "#1C1D20"
TAPE = "#D6D9DC"

# ---------------------------------------------------------------- Roblox CFrame -> Blender

_X = lambda a: Matrix.Rotation(a, 3, "X")
_Y = lambda a: Matrix.Rotation(a, 3, "Y")
_Z = lambda a: Matrix.Rotation(a, 3, "Z")


def _rot_rb(rx=0.0, ry=0.0, rz=0.0):
    """CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz (radians), in authored Roblox axes."""
    return _X(rx) @ _Y(ry) @ _Z(rz)


def _to_bl(p, r=None):
    """Authored Roblox studs -> Blender studs: bx=-x, by=z, bz=y."""
    pb = Vector((-p[0], p[2], p[1]))
    if r is None:
        return Matrix.Translation(pb)
    m = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
    return Matrix.Translation(pb) @ (m.transposed() @ r @ m).to_4x4()


def cf(pos, rx=0.0, ry=0.0, rz=0.0):
    return _to_bl(pos, _rot_rb(rx, ry, rz))


def mul(c, x, y, z):
    return c @ Matrix.Translation(Vector((x, y, z)))


# ---------------------------------------------------------------- the BosunRig contract

PARTS = []


def add(name, size, cframe, parent, joint=None, pivot=None, harness=False):
    PARTS.append(dict(name=name, size=Vector(size), cframe=cframe, parent=parent,
                      joint=joint, pivot=(Vector(pivot) if pivot else None), harness=harness))
    return PARTS[-1]


D = math.radians
add("Torso", (0.95, 0.9, 2.3), cf((0, 1.68, 0.05)), "Body", "Root", (0, 0, -0.85))
add("Chest", (1.0, 1.0, 1.0), cf((0, 1.66, -1.0)), "Torso")
add("Rump", (0.92, 0.88, 0.88), cf((0, 1.74, 1.05)), "Torso")
add("Head", (0.78, 0.72, 0.8), cf((0, 2.62, -1.55)), "Torso", "Neck", (0, 2.0, -1.05))
add("Neck", (0.56, 0.95, 0.56), cf((0, 2.2, -1.28), D(-28)), "Head")
add("Muzzle", (0.48, 0.36, 0.55), cf((0, 2.48, -2.16)), "Head")
add("Nose", (0.24, 0.15, 0.08), cf((0, 2.6, -2.45)), "Head")
add("Jaw", (0.42, 0.12, 0.5), cf((0, 2.25, -2.12)), "Head", "Jaw", (0, 2.3, -1.86))
add("Tongue", (0.22, 0.04, 0.3), cf((0, 2.32, -2.12)), "Jaw")
for s, side in ((-1, "Left"), (1, "Right")):
    add("Eye" + side, (0.12, 0.12, 0.12), cf((0.22 * s, 2.76, -1.94)), "Head")
    add("Ear" + side, (0.1, 0.5, 0.34), cf((0.42 * s, 2.58, -1.42), 0, 0, D(8) * s), "Head")

TAIL = (0, 1.95, 1.4)
tail1 = cf(TAIL, D(40))
add("Tail1", (0.22, 0.22, 0.62), mul(tail1, 0, 0.31, 0), "Torso", "Tail1", TAIL)
tip = mul(tail1, 0, 0.6, 0)
TIP_RB = (0.0, 1.95 - 0.6 * math.sin(D(40)), 1.4 + 0.6 * math.cos(D(40)))
add("Tail2", (0.16, 0.16, 0.55), tip @ cf((0, 0, 0), D(15)) @ Matrix.Translation((0, 0.27, 0)),
    "Tail1", "Tail2", TIP_RB)

for end_, z in (("Front", -0.82), ("Back", 0.92)):
    for s, side in ((-1, "Left"), (1, "Right")):
        leg = end_ + side
        x = 0.28 * s
        w = 0.32 if end_ == "Back" else 0.27
        add(leg + "Upper", (w, 0.9, w + 0.06), cf((x, 1.15, z)), "Torso", leg + "Upper", (x, 1.5, z))
        add(leg + "Lower", (0.22, 0.66, 0.24), cf((x, 0.43, z)), leg + "Upper", leg + "Lower", (x, 0.72, z))
        add(leg + "Paw", (0.28, 0.14, 0.38), cf((x, 0.07, z - 0.06)), leg + "Lower")

HZ = -0.4
for nm, size, pos in (
    ("HarnessBack", (0.99, 0.08, 0.95), (0, 2.15, HZ)),
    ("HarnessSideLeft", (0.06, 0.78, 0.95), (-0.5, 1.78, HZ)),
    ("HarnessSideRight", (0.06, 0.78, 0.95), (0.5, 1.78, HZ)),
    ("HarnessTapeLeft", (0.02, 0.08, 0.9), (-0.535, 1.86, HZ)),
    ("HarnessTapeRight", (0.02, 0.08, 0.9), (0.535, 1.86, HZ)),
    ("HarnessBelly", (1.0, 0.07, 0.3), (0, 1.24, HZ)),
    ("HarnessChest", (0.86, 0.14, 0.08), (0, 1.82, -1.5)),
    ("HarnessHandle", (0.12, 0.08, 0.5), (0, 2.27, HZ)),
):
    add(nm, size, cf(pos), "Torso", harness=True)

# ---------------------------------------------------------------- geometry helpers

_rng = random.Random(11)
_zone_boxes = []          # (part, centre local, half local, zone, priority)


def _bevel(bm, width, segments):
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=width, offset_type="OFFSET", segments=segments,
                    profile=0.5, affect="EDGES", clamp_overlap=True)


def _box(size, centre=(0, 0, 0), bevel=0.05, segments=2, taper=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = (max(v, 1e-5) for v in size)
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    if taper:
        axis, neg, pos = taper
        half = {"x": sx, "y": sy, "z": sz}[axis] * 0.5
        ai = {"x": 0, "y": 1, "z": 2}[axis]
        for v in bm.verts:
            t = max(-1.0, min(1.0, v.co[ai] / half))
            k = neg if t < 0 else pos
            f = 1.0 + (k - 1.0) * abs(t)
            for a in range(3):
                if a != ai:
                    v.co[a] *= f
    _bevel(bm, bevel, segments)
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


def _sphere(size, centre=(0, 0, 0), u=12, v=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    for vert in bm.verts:
        vert.co.x *= size[0] * 0.5
        vert.co.y *= size[1] * 0.5
        vert.co.z *= size[2] * 0.5
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector(centre))
    return bm


def _merge(dst, src):
    me = bpy.data.meshes.new("_prim")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def _rot(bm, angle, axis, centre=(0, 0, 0)):
    m = Matrix.Rotation(angle, 4, axis)
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts, space=Matrix.Translation(-Vector(centre)))


# ---------------------------------------------------------------- each part's shape

def _torso(bm):
    _merge(bm, _box((0.95, 2.3, 0.9), (0, 0, 0), bevel=0.17, segments=2, taper=("y", 0.95, 0.9)))
    _merge(bm, _box((0.70, 0.9, 0.12), (0, -0.15, 0.42), bevel=0.05, segments=1))


def _chest(bm):
    _merge(bm, _sphere((1.0, 1.0, 1.0), (0, 0, 0), u=12, v=6))


def _rump(bm):
    _merge(bm, _sphere((0.92, 0.88, 0.88), (0, 0, 0), u=12, v=6))


def _head(bm):
    _merge(bm, _box((0.78, 0.80, 0.72), (0, 0, 0), bevel=0.14, segments=2, taper=("z", 0.96, 0.92)))
    for s in (-1, 1):
        brow = _box((0.20, 0.10, 0.055), (0.21 * s, -0.345, 0.245), bevel=0.022, segments=2)
        _rot(brow, D(-7) * s, "Y", (0.21 * s, -0.345, 0.245))
        _merge(bm, brow)


def _neck(bm):
    _merge(bm, _box((0.56, 0.56, 0.95), (0, 0, 0), bevel=0.11, segments=2, taper=("z", 0.9, 0.95)))


def _muzzle(bm):
    _merge(bm, _box((0.48, 0.55, 0.36), (0, 0, 0), bevel=0.075, segments=2, taper=("y", 0.86, 1.0)))


def _nose(bm):
    _merge(bm, _box((0.24, 0.08, 0.15), (0, 0, 0), bevel=0.026, segments=2))


def _jaw(bm):
    _merge(bm, _box((0.42, 0.50, 0.12), (0, 0, 0), bevel=0.035, segments=2, taper=("y", 0.88, 1.0)))


def _tongue(bm):
    _merge(bm, _box((0.20, 0.30, 0.06), (0, -0.02, -0.035), bevel=0.009, segments=2, taper=("y", 0.86, 1.0)))
    tip = _box((0.17, 0.15, 0.055), (0, -0.235, -0.085), bevel=0.008, segments=1, taper=("y", 0.72, 1.0))
    _rot(tip, D(18), "X", (0, -0.235, -0.085))
    _merge(bm, tip)


def _eye(bm, name, side):
    _merge(bm, _sphere((0.12, 0.09, 0.12), (0, 0, 0), u=12, v=6))
    h = (0.014 * side, -0.043, 0.020)
    _merge(bm, _sphere((0.034, 0.030, 0.034), h, u=8, v=4))
    _zone_boxes.append((name, Vector(h), Vector((0.026, 0.024, 0.026)), "highlight", 10))


def _ear(bm, side):
    bm_ear = _box((0.10, 0.34, 0.50), (0, 0, 0), bevel=0.026, segments=2, taper=("z", 0.72, 0.95))
    for v in bm_ear.verts:
        v.co.x += side * (0.018 * max(0.0, -v.co.z / 0.25))
    _merge(bm, bm_ear)


def _tail1(bm):
    _merge(bm, _box((0.26, 0.62, 0.30), (0, 0, 0), bevel=0.06, segments=2, taper=("y", 0.82, 0.96)))
    _merge(bm, _sphere((0.28, 0.28, 0.28), (0, 0.30, 0), u=10, v=5))


def _tail2(bm):
    _merge(bm, _box((0.20, 0.55, 0.22), (0, 0, 0), bevel=0.05, segments=2, taper=("y", 0.75, 0.94)))


def _upper(bm, back):
    w = 0.32 if back else 0.27
    _merge(bm, _box((w, w + 0.06, 0.90), (0, 0, 0), bevel=0.055, segments=2, taper=("z", 0.82, 1.07)))


def _lower(bm):
    _merge(bm, _box((0.22, 0.24, 0.66), (0, 0, 0), bevel=0.045, segments=2, taper=("z", 0.82, 0.95)))
    _merge(bm, _sphere((0.23, 0.21, 0.22), (0, 0, 0.285), u=10, v=5))


def _paw(bm):
    _merge(bm, _box((0.28, 0.38, 0.14), (0, 0, 0), bevel=0.045, segments=2, taper=("y", 0.9, 1.0)))


def _harness_back(bm):
    _merge(bm, _box((0.99, 0.95, 0.08), (0, 0, 0), bevel=0.022, segments=2))
    _merge(bm, _box((0.70, 0.12, 0.014), (0, -0.02, 0.046), bevel=0.006, segments=1))
    for s in (-1, 1):
        _merge(bm, _box((0.055, 0.90, 0.012), (0.40 * s, 0, 0.045), bevel=0.004, segments=1))
    _zone_boxes.append(("HarnessBack", Vector((0, -0.02, 0.046)), Vector((0.36, 0.08, 0.02)), "tape", 5))
    for s in (-1, 1):
        _zone_boxes.append(("HarnessBack", Vector((0.40 * s, 0, 0.045)), Vector((0.04, 0.46, 0.02)), "webbing", 5))


def _harness_side(bm, side):
    _merge(bm, _box((0.06, 0.95, 0.78), (0, 0, 0), bevel=0.022, segments=2))
    _merge(bm, _box((0.014, 0.12, 0.74), (0.033 * side, 0, 0), bevel=0.004, segments=1))
    _zone_boxes.append(("HarnessSide" + ("Left" if side < 0 else "Right"), Vector((0.033 * side, 0, 0)),
                        Vector((0.012, 0.06, 0.37)), "webbing", 5))


def _harness_tape(bm):
    _merge(bm, _box((0.02, 0.90, 0.08), (0, 0, 0), bevel=0.006, segments=2))


def _harness_belly(bm):
    _merge(bm, _box((1.0, 0.30, 0.07), (0, 0, 0), bevel=0.02, segments=2))


def _harness_chest(bm):
    _merge(bm, _box((0.50, 0.08, 0.14), (0, 0, 0), bevel=0.02, segments=1))
    for s in (-1, 1):
        seg = _box((0.26, 0.075, 0.135), (0, 0, 0), bevel=0.018, segments=1)
        _rot(seg, D(18) * s, "Z")
        bmesh.ops.translate(seg, verts=seg.verts, vec=Vector((0.36 * s, 0.035, 0)))
        _merge(bm, seg)
    _merge(bm, _box((0.16, 0.025, 0.11), (0, -0.043, 0), bevel=0.008, segments=1))
    _zone_boxes.append(("HarnessChest", Vector((0, -0.043, 0)), Vector((0.11, 0.02, 0.08)), "webbing", 5))


def _harness_handle(bm):
    for s in (-1, 1):
        _merge(bm, _box((0.11, 0.075, 0.17), (0, 0.205 * s, 0.075), bevel=0.018, segments=1))
    _merge(bm, _box((0.12, 0.44, 0.07), (0, 0, 0.155), bevel=0.022, segments=1))


SHAPES = {
    "Torso": _torso, "Chest": _chest, "Rump": _rump, "Head": _head, "Neck": _neck,
    "Muzzle": _muzzle, "Nose": _nose, "Jaw": _jaw, "Tongue": _tongue,
    "Tail1": _tail1, "Tail2": _tail2,
}

# ---------------------------------------------------------------- texture zones

ZONES = {
    "coat": (0.0, 0.5, 0.0, 0.5), "harness": (0.52, 0.72, 0.0, 0.5),
    "webbing": (0.74, 0.82, 0.0, 0.5), "tape": (0.84, 1.0, 0.0, 0.5),
    "eye": (0.52, 0.60, 0.52, 0.60), "highlight": (0.62, 0.70, 0.52, 0.60),
    "nose": (0.72, 0.80, 0.52, 0.60), "tongue": (0.82, 0.90, 0.52, 0.60),
    "inner": (0.92, 1.0, 0.52, 0.60),
}
GRADIENT = {"coat", "harness", "nose"}


def _zone_of(part, centre, normal):
    name = part["name"]
    for pn, c, half, zone, _pri in sorted(_zone_boxes, key=lambda b: -b[4]):
        if pn == name and all(abs(centre[i] - c[i]) <= half[i] for i in range(3)):
            return zone
    if name.startswith("Eye"):
        return "eye"
    if name == "Nose":
        return "nose"
    if name == "Tongue":
        return "tongue"
    if name.startswith("HarnessTape"):
        return "tape"
    if name == "HarnessHandle":
        return "webbing"
    if name.startswith("Harness"):
        return "harness"
    return "coat"


def _assign_uv(bm, part):
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        f.normal_update()
        zone = _zone_of(part, f.calc_center_median(), f.normal)
        x0, x1, y0, y1 = ZONES[zone]
        up = max(0.0, min(1.0, (f.normal.z + 1.0) * 0.5))
        u = _rng.uniform(x0 + 0.03 * (x1 - x0), x1 - 0.03 * (x1 - x0))
        if zone in GRADIENT:
            v = y0 + (0.05 + 0.90 * up) * (y1 - y0)
        else:
            v = _rng.uniform(y0 + 0.12 * (y1 - y0), y1 - 0.12 * (y1 - y0))
        s = 0.004
        u = max(x0 + s, min(x1 - s, u))
        v = max(y0 + s, min(y1 - s, v))
        for i, loop in enumerate(f.loops):
            a, b = ((0, 0), (s, 0), (s, s), (0, s))[min(i, 3)]
            loop[uv].uv = (u + a, v + b)


# ---------------------------------------------------------------- materials and build

def _material():
    out_dir = common.textures_dir(ASSET)
    import coattex
    paths = coattex.write(out_dir)
    mat = bpy.data.materials.get("M_Chr_Bosun_LP_Coat") or bpy.data.materials.new("M_Chr_Bosun_LP_Coat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    for kind, path, colour in (("ALB", paths[0], "sRGB"), ("NOR", paths[1], "Non-Color"),
                               ("RGH", paths[2], "Non-Color"), ("MET", paths[3], "Non-Color")):
        img = bpy.data.images.load(path, check_existing=True)
        img.colorspace_settings.name = colour
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        if kind == "ALB":
            nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        elif kind == "RGH":
            nt.links.new(node.outputs["Color"], bsdf.inputs["Roughness"])
        elif kind == "MET":
            nt.links.new(node.outputs["Color"], bsdf.inputs["Metallic"])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(node.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _make_part(part, mat):
    name = PREFIX + part["name"]
    bm = bmesh.new()
    _zone_boxes.clear()
    maker = SHAPES.get(part["name"])
    if part["name"].startswith("Eye"):
        _eye(bm, part["name"], -1 if part["name"].endswith("Left") else 1)
    elif part["name"].startswith("Ear"):
        _ear(bm, -1 if part["name"].endswith("Left") else 1)
    elif part["name"].startswith("HarnessSide"):
        _harness_side(bm, -1 if part["name"].endswith("Left") else 1)
    elif part["name"].startswith("HarnessTape"):
        _harness_tape(bm)
    elif part["name"] == "HarnessBack":
        _harness_back(bm)
    elif part["name"] == "HarnessBelly":
        _harness_belly(bm)
    elif part["name"] == "HarnessChest":
        _harness_chest(bm)
    elif part["name"] == "HarnessHandle":
        _harness_handle(bm)
    elif part["name"].endswith("Upper"):
        _upper(bm, part["name"].startswith("Back"))
    elif part["name"].endswith("Lower"):
        _lower(bm)
    elif part["name"].endswith("Paw"):
        _paw(bm)
    elif maker:
        maker(bm)
    else:
        raise RuntimeError("no shape for " + part["name"])
    m = part["cframe"]
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    bm.normal_update()
    _assign_uv(bm, part)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.name = name
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def _write_mapping(shapes):
    rows = {}
    for p in PARTS:
        cfm = p["cframe"]
        rot = cfm.to_3x3()
        # Blender part frame -> authored Roblox part frame: inverse of the authored conversion
        M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
        rr = M @ rot @ M.transposed()
        pos_b = cfm.translation
        pos = (-pos_b.x, pos_b.z, pos_b.y)
        rows[p["name"]] = {
            "part": p["name"],
            "mesh": p["name"],
            "pipeline_name": PREFIX + p["name"],
            "size": [round(v, 4) for v in p["size"]],
            "cframe": {"position": [round(v, 4) for v in pos],
                       "matrix": [[round(rr[i][j], 5) for j in range(3)] for i in range(3)]},
            "offset": [0, 0, 0],
            "parent": "Body" if p["parent"] == "Body" else p["parent"],
            "joint": p["joint"],
            "pivot": ([round(v, 4) for v in p["pivot"]] if p["pivot"] else None),
            "harness": bool(p["harness"]),
        }
    out = {
        "asset": ASSET,
        "source": "src/shared/Dog/BosunRig.luau",
        "axes": "authored studs: origin on the ground between the feet, front -Z, up +Y, his right +X; "
                 "FBX exported with rbxkit (roblox = (-bx, bz, by), 1 BU = 1 stud)",
        "names": "the exported FBX nodes are named exactly like BosunRig.PARTS (Torso, Head, ...); "
                 "pipeline_name is the validated Blender object name with the M_Chr_ asset prefix",
        "pivot_note": "Each mesh is authored around its PartSpec rest frame and exported with the node origin at that "
                      "part centre; cframe is the Part's rest CFrame (position + rotation matrix), offset is zero. "
                      "MeshParts already carry their mesh bounds: set CFrame only, do not force Size to size (the "
                      "grab handle deliberately rises above its flat placeholder box). If an importer collapses node "
                      "pivots, set the MeshPart CFrame to cframe.",
        "textures": {"set": "T_Bosun_Coat_<ALB|NOR|RGH|MET>.png", "size": 1024,
                     "dir": "textures/M_Chr_Bosun_LP"},
        "parts": rows,
    }
    path = os.path.join(common.out_root(), ASSET + ".mapping.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    return path


def _repose(spec, report):
    """After validate: put every LOD node's origin at its part centre and its transform at the rig rest CFrame.

    Until here the meshes are assembled at the authored rest layout (so the size / origin rows measure the dog);
    a node per part with its own pivot is what Roblox needs for the Motor6D swap. No scale is used."""
    if spec.get("_reposed"):
        return
    for e in spec["meshes"]:
        if e.get("role") != "visual":
            continue
        ob = e["object"]
        base = names.mesh_base(ob.name)
        root = REST_BL.get(base)
        if root is None:
            report.add(ob.name, "part pivot", False, "no rest CFrame for " + base)
            continue
        if SHIFT_Y:
            ob.data.transform(Matrix.Translation((0, -SHIFT_Y, 0)))
        ob.data.transform(root.inverted())
        ob.matrix_world = root
        short = base[len(PREFIX):] if base.startswith(PREFIX) else base
        new_name = short + ob.name[len(base):]
        ob.name = new_name
        ob.data.name = new_name
    spec["_reposed"] = True
    report.add(ASSET, "part pivots", True, "%d segmented MeshParts re-origined at their BosunRig rest CFrames" % len(spec["meshes"]))


def _bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


REST_BL = {}


def build():
    global SHIFT_Y
    for ob in list(bpy.data.objects):
        if ob.name.startswith(PREFIX):
            bpy.data.objects.remove(ob, do_unlink=True)
    mat = _material()
    meshes = []
    for p in PARTS:
        ob = _make_part(p, mat)
        meshes.append({"object": ob, "role": "visual", "lod": "LOD0"})
        REST_BL[ob.name] = p["cframe"]
    lo, hi = _bbox([e["object"] for e in meshes])
    SHIFT_Y = -(lo[1] + hi[1]) * 0.5
    if abs(SHIFT_Y) > 1e-6:
        for e in meshes:
            e["object"].data.transform(Matrix.Translation((0, SHIFT_Y, 0)))
    lo, hi = _bbox([e["object"] for e in meshes])
    dims_m = tuple(round((hi[i] - lo[i]) / common.STUDS_PER_METRE, 3) for i in range(3))
    _write_mapping(meshes)
    return {
        "name": ASSET,
        "budget": "dog",
        "species": "dog",
        "tris": 5000,
        "tier": "standard",
        "dims_m": dims_m,
        "origin": "base",
        "sets": [{"name": "Bosun", "set": "Coat", "size": 1024, "wet": False}],
        "meshes": meshes,
        "attachments": [],
        "extra_checks": [_repose],
        "waivers": {
            "texture sets": "one 1024 swatch set for a 35-part segmented character (dog class asks 2 to 3)",
            "texel density": "swatch atlas: per-face palette zones, form from bevelled low-poly geometry",
            "LOD UV layout": "segmented character: per-face palette swatches; collapsed LOD faces shift UV bounds",
            "LOD0 floor": "briefed 3,000 to 5,000 tris, far under the dog class 25,000",
            "origin": "rig origin is the ground between the feet (BosunRig); footprint centre is not the bbox centre",
        },
    }
