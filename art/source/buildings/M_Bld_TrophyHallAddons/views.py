"""Lv2 and Lv2+Lv3 review renders, states kept apart (the way the Trophy Hall stacks levels).

Each state gets a front 3Q, side, top and one detail read: Lv2 = the rotunda + the plinth wing; Lv2+Lv3 = the
portico and the gold dome. Neutral HDRI, grey ground at the add-ons' pad base (z 0). There is no Lv1 render: the
trophy wall is code-built. views_sheet.py composes the contact sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_TrophyHallAddons/views.py
    python3 art/source/buildings/M_Bld_TrophyHallAddons/views_sheet.py
"""
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import template  # noqa: E402
import turntable  # noqa: E402

BLEND = os.path.join(HERE, "M_Bld_TrophyHallAddons.blend")
OUT = os.path.join(G, "build/prod/M_Bld_TrophyHallAddons/review/M_Bld_TrophyHallAddons/levels")
SIZE = 640

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

objs = [o for o in scene.objects if o.type == "MESH"
        and not any(s in o.name for s in ("_LOD1", "_LOD2", "_COL")) and not o.name.startswith(("TPL_", "VIEWS_"))]
assert objs, "no meshes in %s" % BLEND
lv2 = [o for o in objs if o.name.startswith("Lv2_")]
assert lv2, "no Lv2 meshes"
RENDERS = (
    ("Lv2_Front", lv2, 35.0, 12.0),
    ("Lv2_Side", lv2, 90.0, 5.0),
    ("Lv2_Top", lv2, 0.0, 76.0),
    ("Lv2Lv3_Front", objs, 35.0, 12.0),
    ("Lv2Lv3_Side", objs, 90.0, 5.0),
    ("Lv2Lv3_Top", objs, 0.0, 76.0),
)
assert all(r[1] for r in RENDERS), "empty render group: %s" % [r[0] for r in RENDERS if not r[1]]
DETAILS = (
    ("Lv2_Plinths", lv2, Vector((21.0, 0.0, 3.0)) + turntable.view_dir(42, 13) * 28.0, (21.0, 0.0, 3.0), 55.0),
    ("Lv2Lv3_Portico", objs, Vector((0.0, -12.4, 7.4)) + turntable.view_dir(14, 8) * 26.0, (0.0, -12.4, 7.4),
     55.0),
)

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
    cam.data.lens = 50.0
    d = turntable.view_dir(az, el)
    turntable.fit(cam, turntable.corners(show), d)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)

for name, show, loc, target, lens in DETAILS:
    want = set(show) | {ground}
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    cam.data.lens = lens
    cam.data.clip_end = 1000.0
    d = (Vector(loc) - Vector(target)).normalized()
    cam.matrix_world = template.look_matrix(-d, location=loc)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)
print("[views] done ->", OUT)
