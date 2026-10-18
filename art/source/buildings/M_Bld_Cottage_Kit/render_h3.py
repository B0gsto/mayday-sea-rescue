"""H3 review renders (EEVEE, overcast HDRI): each cottage LOD0 dry and wet (front 3/4), plus kit close-ups.
    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_Cottage_Kit/render_h3.py
Writes assets/review/H3/renders/*.png; the sheet is contact_h3.py (system python)."""
import math
import os
import sys

import bpy
from mathutils import Vector

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
HERE = G + "art/source/buildings/M_Bld_Cottage_Kit/"
sys.path.insert(0, HERE)
import variants as VR  # noqa: E402

OUT = G + "assets/review/H3/renders/"
os.makedirs(OUT, exist_ok=True)
KIT, TRIM = G + "assets/textures/M_Bld_Cottage_Kit/", G + "assets/textures/M_Bld_TrimSheet/"


def img(path, data):
    im = bpy.data.images.load(path, check_existing=True)
    if not data:
        im.colorspace_settings.name = "sRGB"
    else:
        im.colorspace_settings.name = "Non-Color"
    return im


def pbr(stem, wet, glass=False, lit=False):
    key = stem + ("_W" if wet else "") + ("_G" if glass else "") + ("_L" if lit else "")
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    sfx = "_Wet" if wet else ""
    t = lambda suf, data, w: nt.nodes.new("ShaderNodeTexImage")
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = img(stem + "_ALB" + sfx + ".png", False)
    tr = nt.nodes.new("ShaderNodeTexImage"); tr.image = img(stem + "_RGH" + sfx + ".png", True)
    tm = nt.nodes.new("ShaderNodeTexImage"); tm.image = img(stem + "_MET.png", True)
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img(stem + "_NOR.png", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(ta.outputs[0], b.inputs["Base Color"])
    nt.links.new(tr.outputs[0], b.inputs["Roughness"])
    nt.links.new(tm.outputs[0], b.inputs["Metallic"])
    nt.links.new(tn.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    if glass:
        b.inputs["Alpha"].default_value = 0.35
        b.inputs["Roughness"].default_value = 0.05
        nt.links.remove(b.inputs["Roughness"].links[0])
        m.surface_render_method = "BLENDED" if hasattr(m, "surface_render_method") else None
    if lit:
        nt.links.new(ta.outputs[0], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = 3.0
    return m


def setup_world():
    sc = bpy.context.scene
    w = bpy.data.worlds.new("H3_Overcast")
    w.use_nodes = True
    env = w.node_tree.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(G + "art/blender/hdri/gray_pier_2k.hdr")
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Strength"].default_value = 1.0
    w.node_tree.links.new(env.outputs[0], bg.inputs[0])
    sc.world = w
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 800, 600
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = "AgX"
    except Exception:
        pass


def shoot(path, target, dist, az, el, lens=35):
    sc = bpy.context.scene
    cam = sc.camera
    if cam is None:
        cam = bpy.data.objects.new("H3Cam", bpy.data.cameras.new("H3Cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.data.lens = lens
    t = Vector(target)
    a, e = math.radians(az), math.radians(el)
    cam.location = t + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


for i in range(1, 7):
    a = "M_Bld_Cottage_%02d" % i
    bpy.ops.wm.open_mainfile(filepath=G + "art/source/buildings/%s/%s.blend" % (a, a))
    setup_world()
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.type == "MESH" and not o.name.endswith("_LOD0"):
            o.hide_render = True
        if o.name.startswith("TPL_") and o.type == "MESH" and "Mannequin" not in o.name:
            o.hide_render = True
    bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -0.05))
    gnd = bpy.context.active_object
    v = VR.V[i]
    render = next((k for _, _, k in v["units"] if k != "Stone"), None) or next((k for _, _, k in v["chimneys"] if k != "Stone"), "Render_White")
    W, E = VR.W_of(i), VR.E_of(i)
    for wet in (False, True):
        gnd.data.materials.clear()
        gnd.data.materials.append(pbr(G + "assets/textures/Materials/T_Mat_Cobbles", wet))
        for o in sc.objects:
            if o.type != "MESH" or not o.name.endswith("_LOD0"):
                continue
            part = o.name.split("_")[3]
            stem = {"Walls": KIT + "T_Cottage_" + render, "Stone": KIT + "T_Cottage_Stone", "Roof": KIT + "T_Cottage_Slate",
                    "Trim": TRIM + "T_BldTrim_Sheet"}.get(part, KIT + "T_Cottage_Details")
            o.data.materials.clear()
            o.data.materials.append(pbr(stem, wet, glass=(part == "Glass"), lit=False))
            if part == "GlassLit":
                o.hide_render = True        # day shots: lit panes off
        tag = "wet" if wet else "dry"
        shoot(OUT + "%02d_%s.png" % (i, tag), (0, 0, E * 3 * 0.62), 3 * (W + 9.0), 28, 9)
        if not wet and i in (1, 2, 5):
            fx = v["front"][0][0]
            shoot(OUT + "close_%02d_window.png" % i, (fx * 3, -VR.D * 1.5, (v["front"][0][1] + 0.6) * 3), 9, 24, 3, lens=50)
        if not wet and i in (3, 5):
            cx = v["chimneys"][0][0]
            shoot(OUT + "close_%02d_roof.png" % i, (cx * 3, -2, VR.ridge(E) * 3 + 2), 16, 35, 22, lens=50)
        if not wet and i == 4:
            dx = v["doors"][0][0]
            shoot(OUT + "close_04_door.png", (dx * 3, -VR.D * 1.5 - 2, 3.5), 11, -20, 4, lens=50)
    # night: lit panes on
    for o in sc.objects:
        if o.name.endswith("_LOD0") and o.name.split("_")[3] == "GlassLit":
            o.hide_render = False
            o.data.materials.clear()
            o.data.materials.append(pbr(KIT + "T_Cottage_Details", False, lit=True))
    if i in (1, 5):
        sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.03
        shoot(OUT + "%02d_night.png" % i, (0, 0, E * 3 * 0.62), 3 * (W + 9.0), 28, 9)
print("[H3] renders done")
