"""Per-level review renders for the Bunkhouse: Lv1 alone, Lv1-3 and Lv1-5 (the way the game stacks levels).

Per row Front3Q / Side / High (turntable angles, neutral HDRI), an Interior view (Lv1: eye outside the front doorway looking in
over the rug at the coat rail and the two bunk-room doorways; Lv1-3: through the balcony door into the Lv2 hall and dorm, the
loft through its back door), a top-down CutAway with the roofs hidden (Lv1 plan; Lv2 plan alone; Lv3 loft + Lv4 wing) and a
Night Front3Q (dark sky, the flat Lamp panes and terrace bulbs lit, a warm point light per bulb, as the game lights them at dusk; the .blend keeps them unlit).
A 5.5-stud blocky figure stands against a wall on each floor for scale.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_Bunkhouse/views.py
    python3 art/source/buildings/M_Bld_Bunkhouse/views_sheet.py
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

OUT = os.path.join(G, "build/prod/M_Bld_Bunkhouse/review/M_Bld_Bunkhouse/levels")
VIEWS = (("Front3Q", 35.0, 12.0), ("Side", 90.0, 5.0), ("High", 325.0, 45.0))
SIZE = 640
F1, F2, F3 = 1.1, 12.7, 23.9

bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "M_Bld_Bunkhouse.blend"))
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
lv = lambda *ks: [o for o in all_objs if any("_%s_" % k in o.name for k in ks)]
groups = {"Lv1": lv("Lv1"), "Lv1-3": lv("Lv1", "Lv2", "Lv3"), "Lv1-5": all_objs}
assert all(groups.values())

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


def render(path, lens=50.0, eye=None, look=None, fit=None):
    cam_data.lens = lens
    if eye is not None:
        d = (Vector(eye) - Vector(look)).normalized()
        cam.matrix_world = template.look_matrix(-d, location=Vector(eye))
    else:
        turntable.fit(cam, turntable.corners(fit[0]), turntable.view_dir(*fit[1]))
    scene.render.filepath = os.path.join(OUT, path)
    bpy.ops.render.render(write_still=True)


roofless = lambda objs, *lvls: [o for o in objs if not any(("_%s_L04_" % k in o.name or "_%s_L05_" % k in o.name) for k in lvls)]
# Interior: (eye, look, figure xy + floor z, lens)
INTERIOR = {"Lv1": ((0.8, -9.6, 5.2), (-0.3, 0.0, 4.0), (9.5, -6.0, F1), 15.0),
            "Lv1-3": ((0.8, -9.8, F2 + 5.2), (-0.3, 0.0, F2 + 4.0), (-6.5, -7.6, F2), 15.0),
            "Lv1-5": ((3.0, -1.0, F3 + 5.5), (-6.6, 0.0, F3 + 4.0), (-2.0, 4.9, F3), 20.0)}   # loft, hammocks side-on
CUT = {"Lv1": lambda: roofless(lv("Lv1"), "Lv1"),
       "Lv1-3": lambda: roofless(lv("Lv2"), "Lv2"),
       "Lv1-5": lambda: roofless(lv("Lv3", "Lv4"), "Lv3", "Lv4")}
for group, objs in groups.items():
    show(objs)
    for view, az, el in VIEWS:
        render("level_%s_%s.png" % (group, view), fit=(objs, (az, el)))
    eye, look, (fx, fy, fz), lens = INTERIOR[group]
    fig = figure(fx, fy, fz)
    show(objs + fig)
    render("level_%s_Interior.png" % group, lens=lens, eye=eye, look=look)
    cut = CUT[group]()
    show(cut + fig)
    render("level_%s_CutAway.png" % group, fit=(cut + fig, (0.0, 89.0)))
    for o in fig:
        bpy.data.objects.remove(o, do_unlink=True)
    print("[views]", group)

# night: dark blue sky, a dim moon, the Lamp panes emit (render only, the asset stays flat colour)
night = bpy.data.worlds.new("VIEWS_Night")
night.use_nodes = True
night.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.018, 0.045, 1.0)
night.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
scene.world = night
moon = bpy.data.objects.new("VIEWS_Moon", bpy.data.lights.new("VIEWS_Moon", "SUN"))
moon.data.energy, moon.data.color = 1.2, (0.6, 0.7, 1.0)
moon.rotation_euler = (0.9, 0.2, 2.4)
scene.collection.objects.link(moon)
for o in scene.objects:
    if o.type == "LIGHT" and o is not moon:
        o.hide_render = True
bulbs = [o for o in all_objs if "_Bulbs_" in o.name]
assert bulbs
lamps = []
for o in bulbs:                  # a plain warm point light per bulb (12 verts each), as the game lights them
    o.visible_shadow = False
    vs = o.data.vertices
    for k in range(len(vs) // 12):
        lamp = bpy.data.objects.new("VIEWS_Bulb%02d" % k, bpy.data.lights.new("VIEWS_Bulb%02d" % k, "POINT"))
        lamp.data.energy, lamp.data.color, lamp.data.shadow_soft_size = 40.0, (1.0, 0.75, 0.4), 0.4
        lamp.location = o.matrix_world @ (sum((v.co for v in vs[12 * k:12 * k + 12]), Vector()) / 12)
        scene.collection.objects.link(lamp)
        lamps.append(lamp)
nt = bpy.data.materials["MI_Lamp"].node_tree
nt.links.new(nt.nodes["ALB"].outputs["Color"], nt.nodes["Principled BSDF"].inputs["Emission Color"])
nt.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 4.0
for group, objs in groups.items():
    show(objs)
    for lamp in lamps:
        lamp.hide_render = bulbs[0] not in objs
    render("level_%s_Night.png" % group, fit=(objs, VIEWS[0][1:]))
print("[views] night")
print("[views] done ->", OUT)
