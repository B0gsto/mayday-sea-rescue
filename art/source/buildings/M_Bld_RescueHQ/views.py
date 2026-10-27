"""Per-level review renders for the RescueHQ: Lv1 alone and Lv1+Lv2 (the way the game stacks levels).

Per level Front3Q / Side / High (turntable angles, neutral HDRI), an Interior view (eye outside the front doorway,
looking in over the clear walkway at the radio desk and chart table, a 5.5-stud blocky figure on the floor) and a
top-down CutAway with the roofs, deck and watch room hidden; Lv2 also a Wing view (roofs off) through the
east doorway to the medic counter.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_RescueHQ/views.py
    python3 art/source/buildings/M_Bld_RescueHQ/views_sheet.py
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

OUT = os.path.join(G, "build/prod/M_Bld_RescueHQ/review/M_Bld_RescueHQ/levels")
VIEWS = (("Front3Q", 35.0, 12.0), ("Side", 90.0, 5.0), ("High", 325.0, 45.0))
SIZE = 640

bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "M_Bld_RescueHQ.blend"))
scene = bpy.context.scene
os.makedirs(OUT, exist_ok=True)
template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

all_objs = [o for o in scene.objects if o.type == "MESH" and "LOD1" not in o.name and "LOD2" not in o.name
            and not o.name.endswith("_COL") and not o.name.startswith("TPL_")]
groups = {"Lv1": [o for o in all_objs if "_Lv1_" in o.name], "Lv2": all_objs}
assert groups["Lv1"] and len(groups["Lv2"]) > len(groups["Lv1"])

pts = turntable.corners(all_objs)
lo, hi = turntable.bounds(pts)
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=max(hi.x - lo.x, hi.y - lo.y) * 3.0, fill_type="NGON",
                                  location=(0, 0, -0.002))
ground = bpy.context.active_object
ground.name = "VIEWS_Ground"
ground.data.materials.append(template.material("MI_VIEWS_Ground", rgb=(0.16, 0.16, 0.155), roughness=0.9))
cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
scene_meshes = [o for o in scene.objects if o.type == "MESH"]


def show(objs):
    for o in scene_meshes:
        o.hide_render = o not in objs
    ground.hide_render = False


def part(name, lo_, hi_, rgb):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=[(a + b) / 2 for a, b in zip(lo_, hi_)])
    o = bpy.context.active_object
    o.name = name
    o.scale = [b - a for a, b in zip(lo_, hi_)]
    o.data.materials.append(template.material("MI_VIEWS_" + name, rgb=rgb, roughness=0.6))
    return o


def figure(x, y, z):
    shirt, pants, skin = (0.85, 0.25, 0.1), (0.1, 0.12, 0.3), (0.95, 0.75, 0.55)
    return [part("FigLegL", (x - 1.0, y - 0.5, z), (x - 0.05, y + 0.5, z + 2.0), pants),
            part("FigLegR", (x + 0.05, y - 0.5, z), (x + 1.0, y + 0.5, z + 2.0), pants),
            part("FigTorso", (x - 1.0, y - 0.5, z + 2.0), (x + 1.0, y + 0.5, z + 4.1), shirt),
            part("FigArmL", (x - 1.95, y - 0.5, z + 2.0), (x - 1.05, y + 0.5, z + 4.1), skin),
            part("FigArmR", (x + 1.05, y - 0.5, z + 2.0), (x + 1.95, y + 0.5, z + 4.1), skin),
            part("FigHead", (x - 0.6, y - 0.6, z + 4.3), (x + 0.6, y + 0.6, z + 5.5), skin)]


for group, objs in groups.items():
    show(objs)
    for view, az, el in VIEWS:
        turntable.fit(cam, turntable.corners(objs), turntable.view_dir(az, el))
        scene.render.filepath = os.path.join(OUT, "level_%s_%s.png" % (group, view))
        bpy.ops.render.render(write_still=True)
    # looking in through the front doorway: figure on the clear walkway, desk and chart table at the back wall
    fig = figure(3.5, -3.0, 1.2)
    show(objs + fig)
    cam_data.lens = 24.0
    eye, look = Vector((3.0, -22.0, 7.0)), Vector((-1.5, 5.0, 3.4))
    cam.matrix_world = template.look_matrix(-(eye - look).normalized(), location=eye)
    scene.render.filepath = os.path.join(OUT, "level_%s_Interior.png" % group)
    bpy.ops.render.render(write_still=True)
    cut = [o for o in objs if not any(k in o.name for k in ("_Lv1_L04_", "_Lv2_L05_", "_Lv2_L06_", "_Lv2_L07_",
                                                            "_Lv2_L03_", "_Lv2_L04_", "_Lv1_L05_Navy", "_Lv2_L02_Roof"))]
    show(cut)
    cam_data.lens = 50.0
    turntable.fit(cam, turntable.corners(cut), turntable.view_dir(0.0, 89.0))
    scene.render.filepath = os.path.join(OUT, "level_%s_CutAway.png" % group)
    bpy.ops.render.render(write_still=True)
    if group == "Lv2":                  # roofs off: from the main room through the east doorway to the medic counter
        show(cut + fig)
        cam_data.lens = 24.0
        eye, look = Vector((1.0, -2.0, 8.5)), Vector((17.5, 0.5, 3.4))
        cam.matrix_world = template.look_matrix(-(eye - look).normalized(), location=eye)
        scene.render.filepath = os.path.join(OUT, "level_%s_Wing.png" % group)
        bpy.ops.render.render(write_still=True)
    for o in fig:
        bpy.data.objects.remove(o, do_unlink=True)
    print("[views]", group)
print("[views] done ->", OUT)
