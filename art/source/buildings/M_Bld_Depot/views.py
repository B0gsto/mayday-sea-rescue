"""Per-node review renders for the Depot: Lv1, Lv1+Lv2, Lv1+Lv2+Lv3 (the way the game stacks levels), FreightQuay,
Lv3 + quay, and the whole depot with the Supply Barge moored at ATT_BargeMoor (x 32.8, z 0.5).

Per level also an Interior view (eye height 5 studs above the bay floor, looking at the rack, a 5.5-stud blocky
R15 figure on the pick-up plate) and a top-down CutAway with the roofs hidden.

Renders Front3Q / Side / High (same angles and neutral HDRI as the turntable) of each node group into
build/prod/M_Bld_Depot/review/M_Bld_Depot/levels/, then views_sheet.py composes the contact sheet.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_Depot/views.py
    python3 art/source/buildings/M_Bld_Depot/views_sheet.py
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

BLEND = os.path.join(HERE, "M_Bld_Depot.blend")
BARGE = os.path.join(G, "art/source/vessels/M_Veh_SupplyBarge/M_Veh_SupplyBarge.blend")
OUT = os.path.join(G, "build/prod/M_Bld_Depot/review/M_Bld_Depot/levels")
VIEWS = (("Front3Q", 35.0, 12.0), ("Side", 90.0, 5.0), ("High", 340.0, 45.0))
SIZE = 640

bpy.ops.wm.open_mainfile(filepath=BLEND)
scene = bpy.context.scene

with bpy.data.libraries.load(BARGE, link=False) as (src, dst):
    dst.objects = [n for n in src.objects
                   if n.startswith(("M_Veh_SupplyBarge_", "Crate_"))
                   and not any(s in n for s in ("_LOD1", "_LOD2", "_COL"))]
for o in dst.objects:
    if o is not None:
        scene.collection.objects.link(o)
        o.location.x += 32.8
        o.location.z += 0.5
os.makedirs(OUT, exist_ok=True)
template.set_eevee(scene, 24)
template.set_world(template.NEUTRAL)
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False

bpy.ops.object.select_all(action="DESELECT")
all_objs = [o for o in scene.objects if o.type == "MESH" and "LOD1" not in o.name and "LOD2" not in o.name
            and not o.name.endswith("_COL") and not o.name.startswith("TPL_")]
groups = {
    "Lv1": [o for o in all_objs if o.name.startswith("Lv1_")],
    "Lv2": [o for o in all_objs if o.name.startswith(("Lv1_", "Lv2_"))],
    "Lv3": [o for o in all_objs if o.name.startswith(("Lv1_", "Lv2_", "Lv3_"))],
    "Quay": [o for o in all_objs if o.name.startswith("FreightQuay_")],
    "Lv3Quay": [o for o in all_objs if o.name.startswith(("Lv1_", "Lv2_", "Lv3_", "FreightQuay_"))],
    "Moored": all_objs,
}
assert all(groups.values()), "no meshes per node: %s" % {k: len(v) for k, v in groups.items()}

pts = turntable.corners(all_objs)
lo, hi = turntable.bounds(pts)
size = max(hi.x - lo.x, hi.y - lo.y, 1.0)
bpy.ops.mesh.primitive_circle_add(vertices=64, radius=size * 3.0, fill_type="NGON", location=(0, 0, -0.002))
ground = bpy.context.active_object
ground.name = "VIEWS_Ground"
ground.data.materials.append(template.material("MI_VIEWS_Ground", rgb=(0.16, 0.16, 0.155), roughness=0.9))

cam_data = bpy.data.cameras.new("VIEWS_Cam")
cam_data.lens, cam_data.sensor_width, cam_data.clip_start = 50.0, 36.0, 0.05
cam = bpy.data.objects.new("VIEWS_Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

scene_meshes = [o for o in scene.objects if o.type == "MESH"]
for group, objs in groups.items():
    for o in scene_meshes:
        o.hide_render = o not in objs
    ground.hide_render = False
    for view, az, el in VIEWS:
        d = turntable.view_dir(az, el)
        turntable.fit(cam, turntable.corners(objs), d)
        scene.render.filepath = os.path.join(OUT, "level_%s_%s.png" % (group, view))
        bpy.ops.render.render(write_still=True)
        print("[views] %s %s" % (group, view))

# interior views and roof-less cut-aways (figure for scale on the pick-up plate)
def figure_part(name, lo, hi, rgb):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=[(a + b) / 2 for a, b in zip(lo, hi)])
    o = bpy.context.active_object
    o.name = name
    o.scale = [b - a for a, b in zip(lo, hi)]
    o.data.materials.append(template.material("MI_VIEWS_" + name, rgb=rgb, roughness=0.6))
    return o


def figure(x, y, z):
    """Blocky R15 stand-in, 5.5 studs tall, facing -Y."""
    shirt, pants, skin = (0.85, 0.25, 0.1), (0.1, 0.12, 0.3), (0.95, 0.75, 0.55)
    parts = [figure_part("FigLegL", (x - 1.0, y - 0.5, z), (x - 0.05, y + 0.5, z + 2.0), pants),
             figure_part("FigLegR", (x + 0.05, y - 0.5, z), (x + 1.0, y + 0.5, z + 2.0), pants),
             figure_part("FigTorso", (x - 1.0, y - 0.5, z + 2.0), (x + 1.0, y + 0.5, z + 4.1), shirt),
             figure_part("FigArmL", (x - 1.95, y - 0.5, z + 2.0), (x - 1.05, y + 0.5, z + 4.1), skin),
             figure_part("FigArmR", (x + 1.05, y - 0.5, z + 2.0), (x + 1.95, y + 0.5, z + 4.1), skin),
             figure_part("FigHead", (x - 0.6, y - 0.6, z + 4.3), (x + 0.6, y + 0.6, z + 5.5), skin)]
    return parts


FL = 1.1
INTERIOR = {   # group: (camera xyz, look-at xyz, figure xy)
    "Lv1": ((-0.5, -6.0, FL + 6.0), (-0.5, 12.0, FL + 2.0), (-0.5, 8.6)),
    "Lv2": ((-15.1, -6.0, FL + 6.0), (-15.1, 12.0, FL + 2.0), (-15.1, 8.6)),
    "Lv3": ((-6.0, 9.0, FL + 4.5), (4.0, -2.5, FL + 5.5), (4.5, 3.0)),
}
CUT = {"Lv1": "Lv1", "Lv2": "Lv2", "Lv3": "Lv3Quay"}
for group, (eye, look, (fx, fy)) in INTERIOR.items():
    fig = figure(fx, fy, FL + 0.15)
    objs = [o for o in groups[group]]
    for o in scene_meshes:
        o.hide_render = o not in objs
    ground.hide_render = False
    cam_data.lens = 16.0
    d = (Vector(eye) - Vector(look)).normalized()
    cam.matrix_world = template.look_matrix(-d, location=Vector(eye))
    scene.render.filepath = os.path.join(OUT, "level_%s_Interior.png" % group)
    bpy.ops.render.render(write_still=True)
    cut = [o for o in groups[CUT[group]] if "_Roof" not in o.name and "_Sign" not in o.name]
    for o in scene_meshes:
        o.hide_render = o not in cut
    cam_data.lens = 50.0
    turntable.fit(cam, turntable.corners(cut), turntable.view_dir(0.0, 89.0))
    scene.render.filepath = os.path.join(OUT, "level_%s_CutAway.png" % group)
    bpy.ops.render.render(write_still=True)
    for o in fig:
        bpy.data.objects.remove(o, do_unlink=True)
    print("[views] %s interior + cut-away" % group)
cam_data.lens = 50.0

# close-up of the moored barge against the quay edge, plus the measured hull-to-quay gap (target 1 stud)
barge = [o for o in dst.objects if o is not None and o.type == "MESH"]
quay = groups["Quay"]
hull_x = min((o.matrix_world @ v.co).x for o in barge for v in o.data.vertices if (o.matrix_world @ v.co).z < 3.0)
quay_x = max((o.matrix_world @ v.co).x for o in quay for v in o.data.vertices if (o.matrix_world @ v.co).z < 3.0)
print("[views] barge gap: hull x %.2f - quay x %.2f = %.2f studs" % (hull_x, quay_x, hull_x - quay_x))
for o in scene_meshes:
    o.hide_render = o not in groups["Moored"]
ground.hide_render = False
turntable.fit(cam, [Vector((x, y, z)) for x in (21.5, 27.5) for y in (-4.0, 4.0) for z in (0.0, 3.0)],
              turntable.view_dir(0.0, 72.0))
scene.render.filepath = os.path.join(OUT, "level_Moored_Gap.png")
bpy.ops.render.render(write_still=True)
print("[views] done ->", OUT)
