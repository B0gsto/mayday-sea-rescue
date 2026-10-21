"""Render three articulation proofs for M_Chr_Bosun_LP: sit, trot and swim.

Loads build.py, poses the segmented meshes at the BosunRig joint pivots with rotations in the same
spirit as src/shared/Dog/BosunMotion.luau, and renders review/pose_<name>.png.

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Chr_Bosun_LP/poses.py
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, HERE)

import common  # noqa: E402
import build as bb  # noqa: E402

common.set_out_root(os.path.join(REPO, "build", "prod", "M_Chr_Bosun_LP"))
D = math.radians
M3 = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def bl_rot(rx, ry, rz):
    return M3.transposed() @ bb._rot_rb(D(rx), D(ry), D(rz)) @ M3


def bl_pivot(v):
    return Vector((-v[0], v[2], v[1]))


def joint(part_name):
    part = next(p for p in bb.PARTS if p["name"] == part_name)
    return part["joint"], bl_pivot(part["pivot"]) if part["pivot"] else Vector((0, 0, 0))


CHAIN = {}


def chain(part_name):
    if part_name in CHAIN:
        return CHAIN[part_name]
    out = []
    p = next(x for x in bb.PARTS if x["name"] == part_name)
    while p is not None:
        if p["joint"]:
            out.append(p["joint"])
        p = next((x for x in bb.PARTS if x["name"] == p["parent"]), None)
    CHAIN[part_name] = list(reversed(out))
    return CHAIN[part_name]


PIVOT = {name: bl_pivot(p["pivot"]) for p in bb.PARTS if p["pivot"] and p["joint"] for name in [p["joint"]]}
HIP = bl_pivot((0, 1.5, 1.77))
ROOT = bl_pivot((0, 0, -0.85))

POSES = {
    "sit": {
        "root": {"rot": bl_rot(35, 0, 0), "pivot": HIP, "move": Vector((0, 0, -0.55))},
        "neck": bl_rot(-28, 0, 0),
        "jaw": bl_rot(-4, 0, 0),
        "tail1": bl_rot(14, 0, 0),
        "front": bl_rot(-35, 0, 0),
        "back_up": bl_rot(35, 0, 0),
        "back_low": bl_rot(-150, 0, 0),
    },
    "trot": {
        "root": {"rot": bl_rot(3, 0, 0), "pivot": ROOT, "move": Vector((0, 0, 0.04))},
        "neck": bl_rot(-5, 0, 3),
        "jaw": bl_rot(-5, 0, 0),
        "tail1": bl_rot(-10, 12, 0),
        "tail2": bl_rot(-4, -12, 0),
        "fl_up": bl_rot(20, 0, 0),
        "fr_up": bl_rot(-20, 0, 0),
        "bl_up": bl_rot(-20, 0, 0),
        "br_up": bl_rot(20, 0, 0),
        "fl_lo": bl_rot(-18, 0, 0),
        "br_lo": bl_rot(-18, 0, 0),
        "fr_lo": bl_rot(-4, 0, 0),
        "bl_lo": bl_rot(-4, 0, 0),
    },
    "swim": {
        "root": {"rot": bl_rot(9, 0, 0), "pivot": ROOT, "move": Vector((0, 0, -0.10))},
        "neck": bl_rot(-6, 0, 0),
        "jaw": bl_rot(-9, 0, 0),
        "tail1": bl_rot(-22, 8, 0),
        "tail2": bl_rot(-4, 6, 0),
        "fl_up": bl_rot(32, 0, 0),
        "fr_up": bl_rot(-32, 0, 0),
        "bl_up": bl_rot(18, 0, 0),
        "br_up": bl_rot(-18, 0, 0),
        "fl_lo": bl_rot(-26, 0, 0),
        "fr_lo": bl_rot(-26, 0, 0),
        "bl_lo": bl_rot(-22, 0, 0),
        "br_lo": bl_rot(-22, 0, 0),
    },
}


def pose_rot(name, pose):
    key = {"FrontLeftUpper": "fl_up", "FrontRightUpper": "fr_up", "BackLeftUpper": "bl_up",
           "BackRightUpper": "br_up", "FrontLeftLower": "fl_lo", "FrontRightLower": "fr_lo",
           "BackLeftLower": "bl_lo", "BackRightLower": "br_lo"}.get(name)
    if name == "Root":
        return pose.get("root")
    if name == "Neck":
        return pose.get("neck")
    if name == "Jaw":
        return pose.get("jaw")
    if name == "Tail1":
        return pose.get("tail1")
    if name == "Tail2":
        return pose.get("tail2")
    if key:
        return pose.get(key)
    return None


def joint_matrix(name, pose):
    spec = pose_rot(name, pose)
    pivot = PIVOT.get(name, Vector((0, 0, 0)))
    if isinstance(spec, dict):
        pivot = spec.get("pivot", pivot)
        rot = spec["rot"]
        move = spec.get("move", Vector((0, 0, 0)))
    elif spec is not None:
        rot, move = spec, Vector((0, 0, 0))
    else:
        return Matrix.Identity(4)
    return Matrix.Translation(move) @ Matrix.Translation(pivot) @ rot.to_4x4() @ Matrix.Translation(-pivot)


def world_for(part_name, pose):
    m = Matrix.Identity(4)
    for jname in chain(part_name):
        m = m @ joint_matrix(jname, pose)
    return m


def look_at(cam, target):
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 900
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.eevee.taa_render_samples = 48
    world = bpy.data.worlds.new("W_Neutral")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.52, 0.55, 0.58, 1.0)
    bg.inputs["Strength"].default_value = 0.85
    sc.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.6
    sun.data.angle = D(8)
    sun.rotation_euler = (D(52), D(-12), D(28))
    sc.collection.objects.link(sun)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 220.0
    fill.data.size = 5.0
    fill.location = (-4, -6, 4)
    fill.rotation_euler = (D(55), 0, D(-32))
    sc.collection.objects.link(fill)
    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-20, -20, 0), (20, -20, 0), (20, 20, 0), (-20, 20, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new("Ground", ground)
    g.data.materials.append(bpy.data.materials.new("M_Ground"))
    g.data.materials[0].diffuse_color = (0.22, 0.24, 0.25, 1.0)
    g.data.materials[0].use_nodes = True
    g.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.16, 0.18, 0.19, 1.0)
    g.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    g.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Specular IOR Level"].default_value = 0.3
    sc.collection.objects.link(g)
    cam = bpy.data.objects.new("CAM", bpy.data.cameras.new("CAM"))
    cam.data.lens = 52
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def bounds(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    return lo, hi


def main():
    sc, cam = setup_scene()
    spec = bb.build()
    objs = [e["object"] for e in spec["meshes"] if e.get("role") == "visual" and e.get("lod") == "LOD0"]
    shift = bb.SHIFT_Y
    for o in objs:
        if shift:
            o.data.transform(Matrix.Translation((0, -shift, 0)))
    out_dir = common.review_dir("M_Chr_Bosun_LP")
    os.makedirs(out_dir, exist_ok=True)
    for pose_name, pose in POSES.items():
        for o in objs:
            part = o.name[len(bb.PREFIX):]
            o.matrix_world = world_for(part, pose)
        bpy.context.view_layer.update()
        lo, hi = bounds(objs)
        ground = Matrix.Translation((0, 0, -lo.z))
        for o in objs:
            o.matrix_world = ground @ o.matrix_world
        bpy.context.view_layer.update()
        lo, hi = bounds(objs)
        centre = (lo + hi) * 0.5
        size = max(hi - lo)
        cam.location = centre + Vector((0.78, -0.88, 0.38)).normalized() * (size * 1.65 + 2.2)
        look_at(cam, centre)
        path = os.path.join(out_dir, "pose_%s.png" % pose_name)
        sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("[poses] wrote", os.path.relpath(path, REPO))
    print("[poses] done")


main()
