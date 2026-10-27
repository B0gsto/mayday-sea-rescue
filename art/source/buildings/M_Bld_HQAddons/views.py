"""Per-level review renders for the HQ add-ons: Lv4 alone, then Lv4 + Lv5, against a plain grey station for context.

Per row Front3Q / Side / Top (turntable angles, neutral HDRI), a detail view (Lv4: through the open front door into
the radio room, the desk with the three sets and the chart board; Lv4 + Lv5: the lantern room from below) and a Night
Front3Q (dark sky, the beacon mesh emits and the lantern glass glows warm, a point light in the lantern and one in
the radio room, as the game lights them at dusk: steady light, no halo or bloom; the .blend keeps them unlit). A 5.5-stud blocky figure stands by each door for scale.

    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_HQAddons/views.py
    python3 art/source/buildings/M_Bld_HQAddons/views_sheet.py
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

OUT = os.path.join(G, "build/prod/M_Bld_HQAddons/review/M_Bld_HQAddons/levels")
VIEWS = (("Front3Q", 35.0, 12.0), ("Side", 90.0, 5.0), ("Top", 0.0, 80.0))
SIZE = 640

bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "M_Bld_HQAddons.blend"))
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
lv = lambda *ks: [o for o in all_objs if any(o.name.startswith(k + "_") for k in ks)]
groups = {"Lv4": lv("Lv4"), "Lv4-5": all_objs}
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


def part(name, lo_, hi_, rgb):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=[(a + b) / 2 for a, b in zip(lo_, hi_)])
    o = bpy.context.active_object
    o.name = name
    o.scale = [b - a for a, b in zip(lo_, hi_)]
    o.data.materials.append(template.material("MI_VIEWS_" + name, rgb=rgb, roughness=0.6))
    return o


def prism(name, verts, faces, rgb):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    o.data.materials.append(template.material("MI_VIEWS_" + name, rgb=rgb, roughness=0.7))
    scene.collection.objects.link(o)
    return o


# plain grey station (render only, the Site view): plinth, walls, roof prism, door and side windows, as the code builds it
CTX = [part("TPL_Plinth", (-28, -17, 0.0), (28, 17, 0.5), (0.46, 0.46, 0.44)),
       part("TPL_Walls", (-26, -15, 0.5), (26, 15, 16.0), (0.56, 0.55, 0.52)),
       prism("TPL_Roof", [(-27.5, -16.5, 16), (27.5, -16.5, 16), (27.5, 16.5, 16), (-27.5, 16.5, 16),
                          (-27.5, 0, 25), (27.5, 0, 25)],
             [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)], (0.34, 0.35, 0.37)),
       part("TPL_Door", (-5, -15.1, 0.5), (5, -15.0, 9.0), (0.24, 0.25, 0.27))]
for sy in (-8, 0, 8):
    CTX.append(part("TPL_WinS%+d" % sy, (26.0, sy - 1.6, 5.5), (26.1, sy + 1.6, 10.0), (0.30, 0.35, 0.38)))
    CTX.append(part("TPL_WinN%+d" % sy, (-26.1, sy - 1.6, 5.5), (-26.0, sy + 1.6, 10.0), (0.30, 0.35, 0.38)))
scene_meshes = [o for o in scene.objects if o.type == "MESH"]


def show(objs, ctx=False):
    keep = set(objs) | (set(CTX) if ctx else set())
    for o in scene_meshes:
        o.hide_render = o not in keep
    ground.hide_render = False


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


# Detail: Lv4 through the open front door at the desk + chart board; Lv4 + Lv5 the lantern room from below.
DETAIL = {"Lv4": ((32.0, -1.6, 5.0), (40.5, 4.0, 4.0), 16.0),
          "Lv4-5": ((55.0, -20.0, 38.5), (55.0, 3.0, 43.8), 35.0)}
for group, objs in groups.items():
    show(objs)
    for view, az, el in VIEWS:
        render("level_%s_%s.png" % (group, view), fit=(objs, (az, el)))
    fig = figure(33.0, -5.6, 0.0) + figure(55.0, -5.2, 0.0)
    show(objs + fig, ctx=True)
    render("level_%s_Site.png" % group, fit=(objs + CTX, (35.0, 30.0)))
    eye, look, lens = DETAIL[group]
    show(objs + fig)
    render("level_%s_Detail.png" % group, lens=lens, eye=eye, look=look)
    if group == "Lv4-5":
        # the raised bridge from the wing roof to the tower's second floor, a figure on the deck
        fig += figure(47.3, 3.0, 16.0)
        show(objs + fig)
        render("level_Lv4-5_Bridge.png", lens=35.0, eye=(36.0, -36.0, 30.0), look=(48.0, 3.0, 15.0))
    for o in fig:
        bpy.data.objects.remove(o, do_unlink=True)
    print("[views]", group)

# night: dark blue sky, a dim moon, the beacon emits (render only, the asset stays flat colour)
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

beacon = scene.objects["Lv5_L05_Beacon"]
glow = bpy.data.materials.new("MI_VIEWS_BeaconGlow")
glow.use_nodes = True
nt = glow.node_tree
nt.nodes.clear()
out = nt.nodes.new("ShaderNodeOutputMaterial")
em = nt.nodes.new("ShaderNodeEmission")
em.inputs["Color"].default_value = (1.0, 0.45, 0.05, 1.0)
em.inputs["Strength"].default_value = 1.2
nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
beacon.data.materials.clear()
beacon.data.materials.append(glow)

# the lantern glass reads lit from inside: the palette's glass cell (14) glows warm, nothing else (4 x 4 cell mask)
lantern = scene.objects["Lv5_L05_Lantern"]
lit = lantern.data.materials[0].copy()
lit.name = "MI_VIEWS_LanternLit"
mask = bpy.data.images.new("VIEWS_GlassMask", 4, 4)
mask.pixels = [c for i in range(16) for c in ((1.0,) * 3 if i == 14 else (0.0,) * 3) + (1.0,)]
ln = lit.node_tree
mt = ln.nodes.new("ShaderNodeTexImage")
mt.image, mt.interpolation = mask, "Closest"
ln.links.new(next(n for n in ln.nodes if n.type == "UVMAP").outputs["UV"], mt.inputs["Vector"])
bsdf = ln.nodes["Principled BSDF"]
bsdf.inputs["Emission Color"].default_value = (1.0, 0.8, 0.45, 1.0)
mul = ln.nodes.new("ShaderNodeMath")
mul.operation, mul.inputs[1].default_value = "MULTIPLY", 0.8
ln.links.new(mt.outputs["Color"], mul.inputs[0])
ln.links.new(mul.outputs[0], bsdf.inputs["Emission Strength"])
lantern.data.materials[0] = lit
night_lights = []
for name, loc, energy, colour in (("Lantern", (55.0, 3.0, 44.6), 2500.0, (1.0, 0.78, 0.35)),
                                  ("RadioRoom", (35.0, 1.0, 9.0), 400.0, (1.0, 0.75, 0.45)),
                                  ("MastTop", (36.0, 4.2, 33.4), 20.0, (1.0, 0.15, 0.1))):
    lamp = bpy.data.objects.new("VIEWS_" + name, bpy.data.lights.new("VIEWS_" + name, "POINT"))
    lamp.data.energy, lamp.data.color, lamp.data.shadow_soft_size = energy, colour, 0.6
    lamp.location = loc
    scene.collection.objects.link(lamp)
    night_lights.append(lamp)
for group, objs in groups.items():
    show(objs)
    for lamp in night_lights:
        lamp.hide_render = group == "Lv4" and lamp.name == "VIEWS_Lantern"
    render("level_%s_Night.png" % group, fit=(objs, VIEWS[0][1:]))
print("[views] night")
print("[views] done ->", OUT)
