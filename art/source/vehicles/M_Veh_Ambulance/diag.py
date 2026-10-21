"""Model check: renders the _HP materials of the saved asset at a few framings (pre-bake)."""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(REPO, "tools/blender"))
import template
import turntable as TT

NAME = "M_Veh_Ambulance"
OUT = os.path.join(REPO, "build/prod", NAME, "diag")

bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, NAME + ".blend"))
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
cam_data = bpy.data.cameras.new("CAM_Diag")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("CAM_Diag", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.resolution_x = scene.render.resolution_y = 900
os.makedirs(OUT, exist_ok=True)

# whole asset, and the cab, at 900 px
views = [("whole_fq", (0, 0, 4.4), 62, 18, 46), ("whole_side", (0, 0, 4.4), 92, 14, 44),
         ("whole_rq", (0, 0, 4.4), 200, 20, 44), ("cab_fq", (0.0, -5.4, 5.0), 42, 14, 16),
         ("cab_top", (0.0, -6.0, 5.0), 20, 74, 20), ("cab_hi", (0.0, -4.0, 5.6), 320, 38, 16),
         ("cab_front", (0.0, -8.6, 3.0), 4, 8, 12), ("cab_side", (0.0, -5.4, 5.0), 88, 8, 15)]
for name, target, az, el, dist in views:
    t = Vector(target)
    d = TT.view_dir(az, el)
    if dist > 30:
        TT.fit(cam, pts, d)
    else:
        cam.location = t + d * dist
        cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
print("[diag] wrote", OUT)
