"""Lv2 and Lv2+Lv3 review renders, states kept apart (the way the Boat Yard stacks levels).

Each state gets a 3/4 front, a side and a high read, plus three detail renders (crane, bench, dry dock). Neutral HDRI,
grey ground at the add-ons' plinth top (z 0.92). There is no Lv1 render: the yard itself is code-built. The levels
sheet is composed by views_sheet.py.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_BoatYardAddons/views.py
    python3 art/source/buildings/M_Bld_BoatYardAddons/views_sheet.py
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import template  # noqa: E402
import turntable  # noqa: E402

BLEND = os.path.join(HERE, "M_Bld_BoatYardAddons.blend")
OUT = os.path.join(G, "build/prod/M_Bld_BoatYardAddons/review/M_Bld_BoatYardAddons/levels")
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
    ("Lv2_Front", lv2, -30, 12),
    ("Lv2_Side", lv2, -90, 8),
    ("Lv2_Top", lv2, -30, 55),
    ("Lv2Lv3_Front", objs, -30, 14),
    ("Lv2Lv3_Side", objs, -90, 10),
    ("Lv2Lv3_Top", objs, -30, 55),
    ("Detail_Crane", pick(("Lv2_L01", "Lv2_L02")), -34, 10),
    ("Detail_Bench", pick(("Lv2_L03", "Lv2_L04")), -62, 10),
    ("Detail_Dock", lv3, 55, 24),
)
assert all(r[1] for r in RENDERS), "empty render group: %s" % [r[0] for r in RENDERS if not r[1]]

os.makedirs(OUT, exist_ok=True)
turntable.MARGIN = 1.03                 # tighter than the turntable default, the cells are square and the asset wide
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
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=size * 3.0, depth=size * 4.0, end_fill_type="NOTHING",
                                    location=(0, 0, lo.z + size * 0.9))       # hides the HDRI softbox behind the asset
back = bpy.context.active_object
back.name = "VIEWS_Backdrop"
back_mat = bpy.data.materials.new("MI_VIEWS_Backdrop")            # emission only: a flat studio wall, no HDRI patches
back_mat.use_nodes = True
bsdf = back_mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1.0)
bsdf.inputs["Emission Color"].default_value = (0.16, 0.16, 0.155, 1.0)
bsdf.inputs["Emission Strength"].default_value = 1.0
back.data.materials.append(back_mat)

cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

for name, show, az, el in RENDERS:
    want = set(show) | {ground, back}
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in want
    d = turntable.view_dir(az, el)
    turntable.fit(cam, turntable.corners(show), d)
    scene.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    print("[views] %s" % name)
print("[views] done ->", OUT)
