"""Lv2 and Lv2+Lv3 review renders, states kept apart (the way the Workshop yard stacks levels).

Each state gets a close read and a whole-layout read: Lv2 = west benches, saw shed, all-high; Lv2+Lv3 = boat frame,
all-front, all-high. Neutral HDRI, grey ground at the add-ons' plinth top (z 0.96). There is no Lv1 render: the yard
itself is code-built. views_sheet.py composes the contact sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_WorkshopAddons/views.py
    python3 art/source/buildings/M_Bld_WorkshopAddons/views_sheet.py
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import template  # noqa: E402
import turntable  # noqa: E402

BLEND = os.path.join(HERE, "M_Bld_WorkshopAddons.blend")
OUT = os.path.join(G, "build/prod/M_Bld_WorkshopAddons/review/M_Bld_WorkshopAddons/levels")
SIZE = 640

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

objs = [o for o in scene.objects if o.type == "MESH"
        and not any(s in o.name for s in ("_LOD1", "_LOD2", "_COL")) and not o.name.startswith(("TPL_", "VIEWS_"))]
assert objs, "no meshes in %s" % BLEND
lv3 = [o for o in objs if o.name.startswith("Lv3_")]
lv2 = [o for o in objs if not o.name.startswith("Lv3_")]
pick = lambda prefixes: [o for o in objs if o.name.startswith(prefixes)]
RENDERS = (
    ("Lv2_Benches", pick(("Lv2_L01",)), 100.0, 15.0),
    ("Lv2_SawShed", pick(("Lv2_L02", "Lv2_L03", "Lv2_L04", "Lv2_L05")), 25.0, 12.0),
    ("Lv2_All", lv2, 340.0, 40.0),
    ("Lv2Lv3_Boat", lv3, 32.0, 12.0),
    ("Lv2Lv3_Front", objs, 35.0, 12.0),
    ("Lv2Lv3_All", objs, 340.0, 40.0),
)
assert all(r[1] for r in RENDERS), "empty render group: %s" % [r[0] for r in RENDERS if not r[1]]

os.makedirs(OUT, exist_ok=True)
template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

pts = turntable.corners(objs)
lo, hi = turntable.bounds(pts)
size = max(hi.x - lo.x, hi.y - lo.y, 1.0)
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=size * 4.0, fill_type="NGON", location=(0, 0, lo.z - 0.002))
ground = bpy.context.active_object
ground.name = "VIEWS_Ground"
ground.data.materials.append(template.material("MI_VIEWS_Ground", rgb=(0.16, 0.16, 0.155), roughness=0.9))

cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

for name, show, az, el in RENDERS:
    want = set(show) | {ground}
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    d = turntable.view_dir(az, el)
    turntable.fit(cam, turntable.corners(show), d)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)
print("[views] done ->", OUT)
