"""Clothed-silhouette check (docs/06 2.1a) for M_Chr_Casualty_Swimmer: renders silhouettes (front, side, back, 3/4),
clay renders (no textures) of the same views, two cutaways through the mesh (proof: no body inside the clothing) and the
LOD1 / LOD2 clay, to build/ch1/clothed/*.png; clothed_sheet.py composes assets/review/M_Chr_Casualty_Swimmer/clothed_check.png.
    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Chr_Casualty_Swimmer/clothed_check.py"""
import math
import os
import bpy
import mathutils

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(REPO, "build", "ch1", "clothed")
os.makedirs(OUT, exist_ok=True)
A = "M_Chr_Casualty_Swimmer"
bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, A + ".blend"))
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = eng
        break
    except TypeError:
        pass
sc.render.resolution_x, sc.render.resolution_y = 420, 700
sc.render.film_transparent = False
sc.view_settings.view_transform = 'Standard'
lods = {l: bpy.data.objects[A + "_" + l] for l in ("LOD0", "LOD1", "LOD2")}
for o in sc.objects:
    o.hide_render = True
for o in lods.values():
    o.location = (0, 0, 0)


def mat(name, color, emit=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if emit:
        s = nt.nodes.new("ShaderNodeEmission")
        s.inputs["Color"].default_value = color
    else:
        s = nt.nodes.new("ShaderNodeBsdfPrincipled")
        s.inputs["Base Color"].default_value = color
        s.inputs["Roughness"].default_value = 0.65
    nt.links.new(s.outputs[0], out.inputs["Surface"])
    m.use_backface_culling = False
    return m


CLAY, SIL = mat("CHK_Clay", (0.55, 0.55, 0.55, 1)), mat("CHK_Sil", (0, 0, 0, 1), True)


def cut_mat():
    """Clay outside, bright orange emission on back faces: in a cutaway every inside face of the clothing shell glows
    orange, so the hollow interior (no body inside) reads at a glance."""
    m = mat("CHK_Cut", (0.55, 0.55, 0.55, 1))
    nt = m.node_tree
    out = nt.nodes["Material Output"]
    bsdf = nt.nodes["Principled BSDF"]
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.42, 0.05, 1)
    em.inputs["Strength"].default_value = 1.6
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs[0])
    nt.links.new(bsdf.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


CUT = cut_mat()
world = bpy.data.worlds.new("CHK_World")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
sc.world = world
cam = bpy.data.objects.new("CHK_Cam", bpy.data.cameras.new("CHK_Cam"))
sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 5.9
sc.camera = cam
sun = bpy.data.objects.new("CHK_Sun", bpy.data.lights.new("CHK_Sun", 'SUN'))
sc.collection.objects.link(sun)
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
fill = bpy.data.objects.new("CHK_Fill", bpy.data.lights.new("CHK_Fill", 'SUN'))
sc.collection.objects.link(fill)
fill.data.energy = 1.0
fill.rotation_euler = (math.radians(60), 0, math.radians(150))
C = mathutils.Vector((0, 0, 2.7))
VIEWS = {"front": -90, "side": 0, "back": 90, "threequarter": -45}


def shoot(obj, material, view, name, clip=None, sil=False):
    for o in lods.values():
        o.hide_render = o is not obj
    keep = list(obj.data.materials)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    bg.inputs["Color"].default_value = (1, 1, 1, 1) if sil else (0.32, 0.34, 0.37, 1)
    bg.inputs["Strength"].default_value = 1.0
    sun.hide_render = fill.hide_render = sil
    a = math.radians(VIEWS[view])
    d = 20.0
    cam.location = C + mathutils.Vector((math.cos(a) * d, math.sin(a) * d, 0))
    cam.rotation_euler = (C - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_start = clip if clip else 0.1
    cam.data.clip_end = 100
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    obj.data.materials.clear()
    for m in keep:
        obj.data.materials.append(m)


L0 = lods["LOD0"]
for v in VIEWS:
    shoot(L0, SIL, v, "sil_" + v, sil=True)
    shoot(L0, CLAY, v, "clay_" + v)
shoot(L0, CUT, "side", "cut_side", clip=20.0)        # camera on +X, near plane at x = 0: the left half is cut away
shoot(L0, CUT, "front", "cut_front", clip=20.0)      # camera on -Y, near plane at y = 0: the front half is cut away
shoot(lods["LOD1"], CLAY, "threequarter", "clay_lod1")
shoot(lods["LOD2"], CLAY, "threequarter", "clay_lod2")
me = L0.data
print("[clothed_check] %s %d tris, %d verts -> %s" % (L0.name, sum(len(p.vertices) - 2 for p in me.polygons), len(me.vertices), OUT))
