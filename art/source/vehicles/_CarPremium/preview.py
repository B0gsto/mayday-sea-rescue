"""Fast look check while modelling (pre-bake): renders the _HP materials of a saved car .blend.

    ~/RobloxProjects/tools/blender-run.sh art/source/vehicles/_CarPremium/preview.py -- M_Veh_HarbourGT
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(REPO, "tools/blender"))
import template  # noqa: E402
import turntable as TT  # noqa: E402

NAME = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(REPO, "build/prod", NAME, "preview")

bpy.ops.wm.open_mainfile(filepath=os.path.join(os.path.dirname(HERE), NAME, NAME + ".blend"))
scene = bpy.context.scene
objs = [o for o in scene.objects if o.name.startswith(NAME + "_") and o.name.endswith("_HP")]
pts = TT.corners(objs)
lo, hi = TT.bounds(pts)
for o in scene.objects:
    o.hide_render = o not in objs and o.type != "CAMERA"
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=(hi - lo).length * 3.0, fill_type="NGON",
                                  location=(0, 0, lo.z - 0.01))
ground = bpy.context.active_object
ground.data.materials.append(template.material("MI_PreviewGround", rgb=(0.15, 0.15, 0.15), roughness=0.9))
ground.hide_render = False

template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
cam_data = bpy.data.cameras.new("CAM_Preview")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("CAM_Preview", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = 640
os.makedirs(OUT, exist_ok=True)

for name, az, el in (("front", 35, 10), ("side", 90, 3), ("rear", 215, 12), ("high", 325, 40), ("nose", 0, 6),
                     ("tail", 180, 8)):
    d = TT.view_dir(az, el)
    TT.fit(cam, pts, d)
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
print("[preview] wrote", OUT)
