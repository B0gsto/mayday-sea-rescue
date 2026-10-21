"""Pose check for M_Ani_GreySeal: renders each clip at a few frames and the two lower LODs, into
build/prod/M_Ani_GreySeal/review/M_Ani_GreySeal/poses/. Not part of the pipeline (run.py's clips steps are not
ported); it is the visual check that the skinning and the actions do what the clip table says.

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Ani_GreySeal/posepass.py [out-root]
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
for p in (HERE, os.path.join(REPO, "tools/blender")):
    if p not in sys.path:
        sys.path.insert(0, p)
import common  # noqa: E402
import template  # noqa: E402
import turntable as tt  # noqa: E402

NAME = "M_Ani_GreySeal"
SHOTS = [("Swim", [1, 19, 37, 55], 34.0, 22.0),
         ("Surface", [1, 13, 25, 37], 20.0, 8.0),
         ("Look", [1, 19, 37, 55], 96.0, 16.0),
         ("HaulOut", [1, 12, 22, 34, 48], 118.0, 30.0),
         ("Flee", [1, 10, 18, 28, 40], 40.0, 26.0)]


def eval_bounds(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_world
        pts.extend([mw @ v.co for v in me.vertices])
        ev.to_mesh_clear()
    return pts


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args:
        common.set_out_root(args[0])
    blend = os.path.join(HERE, NAME + ".blend")
    if not os.path.isfile(blend):
        raise SystemExit("build first: no %s" % blend)
    bpy.ops.wm.open_mainfile(filepath=blend)
    scene = bpy.context.scene
    rig = bpy.data.objects["RIG_Seal"]
    lod0 = [bpy.data.objects[n] for n in ("%s_Body_LOD0" % NAME, "%s_Head_LOD0" % NAME)]
    out_dir = os.path.join(common.review_dir(NAME), "poses")
    os.makedirs(out_dir, exist_ok=True)
    template.set_eevee(scene, 24)
    if bpy.data.worlds.get("WLD_OvercastSea") is None:
        template.set_world("WLD_OvercastSea")
    template.set_world("WLD_OvercastSea")
    scene.render.resolution_x = scene.render.resolution_y = 512
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=40.0, fill_type="NGON", location=(0, 0, -1.35))
    ground = bpy.context.active_object
    ground.data.materials.append(template.material("MI_Pose_Ground", rgb=(0.20, 0.21, 0.21), roughness=0.9))
    cam_data = bpy.data.cameras.new("CAM_Pose")
    cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 40.0, 36.0, 0.05
    cam = bpy.data.objects.new("CAM_Pose", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    lods = [o for o in bpy.context.scene.objects if o.type == 'MESH' and NAME in o.name
            and not o.name.endswith("_LOD0")]
    man = bpy.data.objects.get("TPL_Mannequin")
    if man:
        man.hide_render = True
    for o in lods:                                  # the lower LODs are static (no armature modifier): not posed
        o.hide_render = True

    def shot(name, az, el, margin=1.55):
        pts = eval_bounds(lod0)
        c = sum(pts, Vector((0, 0, 0))) / len(pts)
        d = tt.view_dir(az, el)
        span = max((p - c).length for p in pts)
        cam.matrix_world = template.look_matrix(-d, location=c + d * (span * margin + 2.0))
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)

    for name, frames, az, el in SHOTS:
        act = bpy.data.actions["A_Seal_" + name]
        rig.animation_data_create()
        rig.animation_data.action = act
        for f in frames:
            scene.frame_set(f)
            shot("pose_%s_%03d" % (name, f), az, el)
        print("[posepass] %s: %s" % (name, frames))
    rig.animation_data.action = None
    scene.frame_set(1)
    for lod in ("LOD1", "LOD2"):
        for o in bpy.context.scene.objects:
            if o.type == 'MESH' and NAME in o.name:
                o.hide_render = not o.name.endswith(lod)
        shot("lod_%s_side" % lod, 96.0, 14.0)
        print("[posepass] %s rendered" % lod)
    print("[posepass] -> %s" % os.path.relpath(out_dir, common.REPO_DIR))


if __name__ == "__main__":
    main()
