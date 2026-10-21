"""M_Chr_Bosun_LP: low-poly Roblox-style Bosun, black water-rescue dog. bench: mimo-v2-6-pro."""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import common
import names

ASSET = "M_Chr_Bosun_LP"
TEX_NAME = "Bosun"
TEX_SET = "Chr"
TEX_SIZE = 1024

COAT = "1E1C1E"
NOSE = "0C0C0D"
EYE = "3B2414"
TONGUE = "C9707E"
HARNESS = "FF6600"
WEBBING = "1C1D20"
TAPE = "D6D9DC"


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def rx(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def rz(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


def tvec(x, y, z):
    m = Matrix.Translation(Vector((x, y, z)))
    return m


# ---- BosunRig part table (mirror of src/shared/Dog/BosunRig.luau, authored frame in studs) ----
# each: name, shape, size, rest matrix (authored), colour, parent, joint, pivot, harness
PARTS = []


def add(name, shape, size, rest, color, parent, joint=None, pivot=None, harness=False):
    PARTS.append({
        "name": name, "shape": shape, "size": size, "rest": rest, "color": color,
        "parent": parent, "joint": joint, "pivot": Vector(pivot) if pivot else None,
        "harness": harness,
    })


add("Torso", "Block", (0.95, 0.9, 2.3), tvec(0, 1.68, 0.05), COAT, "Body", "Root", (0, 0, -0.85))
add("Chest", "Ball", (1.0, 1.0, 1.0), tvec(0, 1.66, -1.0), COAT, "Torso")
add("Rump", "Ball", (0.92, 0.88, 0.88), tvec(0, 1.74, 1.05), COAT, "Torso")
add("Head", "Block", (0.78, 0.72, 0.8), tvec(0, 2.62, -1.55), COAT, "Torso", "Neck", (0, 2.0, -1.05))
add("Neck", "Block", (0.56, 0.95, 0.56), tvec(0, 2.2, -1.28) @ rx(-28), COAT, "Head")
add("Muzzle", "Block", (0.48, 0.36, 0.55), tvec(0, 2.48, -2.16), COAT, "Head")
add("Nose", "Block", (0.24, 0.15, 0.08), tvec(0, 2.6, -2.45), NOSE, "Head")
add("Jaw", "Block", (0.42, 0.12, 0.5), tvec(0, 2.25, -2.12), COAT, "Head", "Jaw", (0, 2.3, -1.86))
add("Tongue", "Block", (0.22, 0.04, 0.3), tvec(0, 2.32, -2.12), TONGUE, "Jaw")
for s, side in ((-1, "Left"), (1, "Right")):
    add(f"Eye{side}", "Ball", (0.12, 0.12, 0.12), tvec(0.22 * s, 2.76, -1.94), EYE, "Head")
    add(f"Ear{side}", "Block", (0.1, 0.5, 0.34), tvec(0.42 * s, 2.58, -1.42) @ rz(8 * s), COAT, "Head")
TAIL = Vector((0, 1.95, 1.4))
tail1 = tvec(*TAIL) @ rx(40)
add("Tail1", "Block", (0.22, 0.22, 0.62), tail1 @ tvec(0, 0, 0.31), COAT, "Torso", "Tail1", tuple(TAIL))
tip = tail1 @ tvec(0, 0, 0.6)
add("Tail2", "Block", (0.16, 0.16, 0.55), tip @ rx(15) @ tvec(0, 0, 0.27), COAT, "Tail1", "Tail2",
    tuple(tip.translation))
for end_, z, w in (("Front", -0.82, 0.27), ("Back", 0.92, 0.32)):
    for s, side in ((-1, "Left"), (1, "Right")):
        leg = f"{end_}{side}"
        x = 0.28 * s
        add(leg + "Upper", "Block", (w, 0.9, w + 0.06), tvec(x, 1.15, z), COAT, "Torso",
            leg + "Upper", (x, 1.5, z))
        add(leg + "Lower", "Block", (0.22, 0.66, 0.24), tvec(x, 0.43, z), COAT, leg + "Upper",
            leg + "Lower", (x, 0.72, z))
        add(leg + "Paw", "Block", (0.28, 0.14, 0.38), tvec(x, 0.07, z - 0.06), COAT, leg + "Lower")
HZ = -0.4
add("HarnessBack", "Block", (0.99, 0.08, 0.95), tvec(0, 2.15, HZ), HARNESS, "Torso", harness=True)
for s, side in ((-1, "Left"), (1, "Right")):
    add(f"HarnessSide{side}", "Block", (0.06, 0.78, 0.95), tvec(0.5 * s, 1.78, HZ), HARNESS, "Torso",
        harness=True)
    add(f"HarnessTape{side}", "Block", (0.02, 0.08, 0.9), tvec(0.535 * s, 1.86, HZ), TAPE, "Torso",
        harness=True)
add("HarnessBelly", "Block", (1.0, 0.07, 0.3), tvec(0, 1.24, HZ), HARNESS, "Torso", harness=True)
add("HarnessChest", "Block", (0.86, 0.14, 0.08), tvec(0, 1.82, -1.5), HARNESS, "Torso", harness=True)
add("HarnessHandle", "Block", (0.12, 0.08, 0.5), tvec(0, 2.27, HZ), WEBBING, "Torso", harness=True)

BY_NAME = {p["name"]: p for p in PARTS}


# ---- scene helpers ----
def clear_scene():
    for o in list(bpy.context.scene.objects):
        if o.type in ("MESH", "EMPTY", "CAMERA", "LIGHT"):
            bpy.data.objects.remove(o, do_unlink=True)


def new_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def create_material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.8
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


# ---- part meshes ----
def shape_box(bm, size, name):
    """Apply per-part silhouette shaping on a unit-ish box before bevel."""
    sx, sy, sz = size
    for v in bm.verts:
        x, y, z = v.co
        if name in ("Muzzle",):
            if z < 0:
                v.co.x *= 0.72
                v.co.y *= 0.72
        elif name in ("Jaw",):
            if z < 0:
                v.co.x *= 0.85
        elif name.startswith("Ear"):
            if y < 0:
                v.co.x *= 0.65
                v.co.z *= 0.65
        elif name.endswith("Paw"):
            if z > 0:
                v.co.x *= 0.82
                v.co.y *= 0.8
        elif name == "Tail1":
            if z > 0:
                v.co.x *= 0.8
                v.co.y *= 0.8
        elif name == "Tail2":
            if z > 0:
                v.co.x *= 0.55
                v.co.y *= 0.55
        elif name == "Neck":
            if y > 0:
                v.co.x *= 0.88
                v.co.z *= 0.88


def part_mesh(part):
    size = part["size"]
    bm = bmesh.new()
    if part["shape"] == "Ball":
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.5)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    else:
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        shape_box(bm, size, part["name"])
        r = max(0.008, min(size) * 0.16)
        if part["name"] in ("Nose", "EarLeft", "EarRight", "Tongue"):
            r = max(0.01, min(size) * 0.22)
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, segments=2, profile=0.7,
                        affect="EDGES", clamp_overlap=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    return bm


def assign_uv(obj, size, tile, tiles_n=8):
    """Map local (x+z, y) into this part's atlas tile."""
    me = obj.data
    uvl = me.uv_layers.new(name="UVMap")
    tw = 1.0 / tiles_n
    pad = 0.12 * tw
    tu = (tile % tiles_n) * tw
    tv = 1.0 - (tile // tiles_n + 1) * tw
    sx, sy, sz = size
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = (co.x / sx + co.z / sz) * 0.5 + 0.5
            v = co.y / sy + 0.5
            u = min(max(u, 0.0), 1.0)
            v = min(max(v, 0.0), 1.0)
            uvl.data[li].uv = (tu + pad + u * (tw - 2 * pad), tv + pad + v * (tw - 2 * pad))


# ---- textures ----
def save_png(name, arr, directory):
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, name + ".png")
    img = bpy.data.images.new(name, width=arr.shape[1], height=arr.shape[0],
                              alpha=(arr.shape[2] == 4))
    img.pixels = list(arr.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


ROUGHS = {COAT: 0.85, NOSE: 0.35, EYE: 0.22, TONGUE: 0.45, HARNESS: 0.55, WEBBING: 0.9, TAPE: 0.35}
METALS = {TAPE: 0.25}


def write_textures():
    directory = os.path.join(common.out_root(), "textures", ASSET)
    os.makedirs(directory, exist_ok=True)
    rng = np.random.default_rng(7)
    size = TEX_SIZE
    tiles_n = 8
    tw = size // tiles_n

    def make(kind, wet=False):
        img = np.ones((size, size, 4), dtype=np.float32)
        if kind == "NOR":
            img[:] = np.array([0.5, 0.5, 1.0, 1.0], dtype=np.float32)
            n = rng.uniform(-0.02, 0.02, (size, size, 3))
            img[:, :, :3] = np.clip(img[:, :, :3] + n, 0.0, 1.0)
            return img
        if kind == "MET":
            img[:] = np.array([0.0, 0.0, 0.0, 1.0], dtype=np.float32)
        for tile, part in enumerate(PARTS):
            col = part["color"]
            base = np.array(hex_rgb(col), dtype=np.float32)
            if kind == "ALB":
                if wet and col in (COAT, NOSE, EYE):
                    base *= 0.82
                # baked shape shading: lighter tops, darker undersides
                gy = np.linspace(0.72, 1.18, tw, dtype=np.float32).reshape(tw, 1, 1)
                tile_img = np.clip(base.reshape(1, 1, 3) * gy, 0.0, 1.0)
                tile_img = np.repeat(tile_img, tw, axis=1)
                tile_img += rng.uniform(-0.015, 0.015, (tw, tw, 3))
                if col == EYE:
                    yy, xx = np.ogrid[:tw, :tw]
                    hi = (xx - tw * 0.62) ** 2 + (yy - tw * 0.68) ** 2 < (tw * 0.13) ** 2
                    tile_img[hi] = np.clip(tile_img[hi] * 2.4 + 0.25, 0, 1)
                if col == NOSE:
                    tile_img *= 1.15
                tile_a = np.clip(tile_img, 0.0, 1.0)
                block = np.concatenate([tile_a, np.ones((tw, tw, 1), dtype=np.float32)], axis=2)
            elif kind == "RGH":
                v = ROUGHS.get(col, 0.8)
                if wet and col in (COAT, NOSE, EYE):
                    v *= 0.55
                block = np.ones((tw, tw, 4), dtype=np.float32) * np.array([v, v, v, 1.0], dtype=np.float32)
                block[:, :, 0] += rng.uniform(-0.03, 0.03, (tw, tw))
            else:  # MET
                v = METALS.get(col, 0.0)
                block = np.ones((tw, tw, 4), dtype=np.float32) * np.array([v, v, v, 1.0], dtype=np.float32)
            row = tile // tiles_n
            col_i = tile % tiles_n
            y0, x0 = row * tw, col_i * tw
            img[y0:y0 + tw, x0:x0 + tw, :] = block
        return img

    for kind in common.MAP_KINDS:
        save_png(names.texture_stem(TEX_NAME, TEX_SET, kind), make(kind), directory)
        if kind in ("ALB", "RGH"):
            save_png(names.texture_stem(TEX_NAME, TEX_SET, kind, wet=True), make(kind, True), directory)


# ---- poses (rotate at joint pivots, prove articulation) ----
def chain_matrix(name, pose):
    """world = A_root ... A_self @ rest, each A = T(p) R T(-p)."""
    m = Matrix.Identity(4)
    cur = name
    stack = []
    while cur != "Body":
        p = BY_NAME[cur]
        if p["joint"]:
            stack.append(p)
        cur = p["parent"]
    for p in reversed(stack):
        ang = pose.get(p["joint"], (0.0, 0.0, 0.0))
        r = Matrix.Rotation(math.radians(ang[0]), 4, "X")
        if ang[1]:
            r = r @ Matrix.Rotation(math.radians(ang[1]), 4, "Y")
        if ang[2]:
            r = r @ Matrix.Rotation(math.radians(ang[2]), 4, "Z")
        pv = p["pivot"]
        m = m @ Matrix.Translation(pv) @ r @ Matrix.Translation(-pv)
    return m @ p_rest(name)


def p_rest(name):
    return BY_NAME[name]["rest"]


POSES = {
    "sit": {
        "Root": (28, 0, 0), "Neck": (18, 0, 0), "Jaw": (6, 0, 0),
        "Tail1": (35, 0, 0), "Tail2": (10, 0, 0),
        "FrontLeftUpper": (-6, 0, 0), "FrontLeftLower": (4, 0, 0),
        "FrontRightUpper": (-6, 0, 0), "FrontRightLower": (4, 0, 0),
        "BackLeftUpper": (62, 0, 0), "BackLeftLower": (-78, 0, 0),
        "BackRightUpper": (62, 0, 0), "BackRightLower": (-78, 0, 0),
    },
    "trot": {
        "Root": (0, 0, 0), "Neck": (4, 0, 0),
        "Tail1": (-28, 0, 0), "Tail2": (-6, 0, 0),
        "FrontLeftUpper": (22, 0, 0), "FrontLeftLower": (-12, 0, 0),
        "FrontRightUpper": (-18, 0, 0), "FrontRightLower": (28, 0, 0),
        "BackLeftUpper": (-16, 0, 0), "BackLeftLower": (22, 0, 0),
        "BackRightUpper": (20, 0, 0), "BackRightLower": (-8, 0, 0),
    },
    "swim": {
        "Root": (-6, 0, 0), "Neck": (14, 0, 0),
        "Tail1": (-20, 0, 0), "Tail2": (8, 0, 0),
        "FrontLeftUpper": (18, 0, -28), "FrontLeftLower": (-20, 0, 0),
        "FrontRightUpper": (18, 0, 28), "FrontRightLower": (-20, 0, 0),
        "BackLeftUpper": (-12, 0, -32), "BackLeftLower": (-18, 0, 0),
        "BackRightUpper": (-12, 0, 32), "BackRightLower": (-18, 0, 0),
    },
}


def render_poses(objs):
    review = os.path.join(common.out_root(), "review")
    os.makedirs(review, exist_ok=True)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PoseCam")
    cam = bpy.data.objects.new("PoseCam", cam_data)
    scene.collection.objects.link(cam)
    sun_data = bpy.data.lights.new("PoseSun", type="SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("PoseSun", sun_data)
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("PoseWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.62, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    target = Vector((0, 1.5, -0.2))
    cam_pos = Vector((3.6, 2.3, -5.2))
    direction = target - cam_pos
    cam.location = cam_pos
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for pose_name, pose in POSES.items():
        for name, obj in objs.items():
            obj.matrix_world = chain_matrix(name, pose)
        scene.render.filepath = os.path.join(review, f"pose_{pose_name}.png")
        bpy.ops.render.render(write_still=True)
    for name, obj in objs.items():
        obj.matrix_world = p_rest(name)


# ---- build ----
def build():
    clear_scene()
    mat = create_material("MI_Bosun_Chr", hex_rgb(COAT))
    objs = {}
    meshes = []
    tri_total = 0
    for tile, part in enumerate(PARTS):
        bm = part_mesh(part)
        obj = new_object(part["name"], bm)
        assign_uv(obj, part["size"], tile)
        obj.data.materials.append(mat)
        obj.matrix_world = part["rest"]
        objs[part["name"]] = obj
        meshes.append({"object": obj, "set": TEX_SET})
        tri_total += len(obj.data.polygons)

    # _COL: box soup in the authored frame
    bm = bmesh.new()
    for part in PARTS:
        size = part["size"]
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * size[0] * 1.02, v.co.y * size[1] * 1.02, v.co.z * size[2] * 1.02))
        bmesh.ops.transform(tmp, matrix=part["rest"], verts=tmp.verts)
        me_tmp = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me_tmp)
        tmp.free()
        bm.from_mesh(me_tmp)
        bpy.data.meshes.remove(me_tmp)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    col = new_object(ASSET + "_COL", bm)
    meshes.append({"object": col})

    write_textures()
    render_poses(objs)

    mapping = {}
    for part in PARTS:
        mapping[part["name"]] = {
            "mesh": part["name"],
            "size": list(part["size"]),
            "offset": {"position": [0.0, 0.0, 0.0], "rotation_deg": [0.0, 0.0, 0.0]},
            "rest_position": [round(c, 4) for c in part["rest"].translation],
            "parent": part["parent"],
            "joint": part["joint"],
            "pivot": [round(c, 4) for c in part["pivot"]] if part["pivot"] else None,
            "harness": part["harness"],
            "color": part["color"],
        }
    out = common.out_root()
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "mapping.json"), "w") as f:
        json.dump({"asset": ASSET, "frame": "authored studs, origin ground between feet, front -Z, up +Y",
                   "parts": mapping}, f, indent=2)

    us = bpy.context.scene.unit_settings
    us.system = "NONE"
    us.scale_length = 1.0

    return {
        "name": ASSET,
        "budget": "dog",
        "tris": tri_total,
        "tier": "standard",
        "dims_m": (1.1 / 3.0, 3.0 / 3.0, 4.7 / 3.0),
        "size_note": "segmented character: bbox from rig envelope, shoulder ~2.1 studs",
        "origin": "base",
        "sets": [{"name": TEX_NAME, "set": TEX_SET, "size": TEX_SIZE, "wet": True,
                  "dir": os.path.join(common.out_root(), "textures", ASSET)}],
        "meshes": meshes,
        "attachments": [],
        "tiling": False,
        "lod_symmetry": None,
        "waivers": {},
    }


if __name__ == "__main__":
    spec = build()
    print(spec)
