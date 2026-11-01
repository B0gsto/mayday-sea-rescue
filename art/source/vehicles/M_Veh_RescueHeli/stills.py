"""Art-director stills for M_Veh_RescueHeli in the live Blender MCP session, after run.py built the asset.

    MCP: stills.py -- <out_dir> [<fbx_dir_with_JetSki_and_RIB>]
Flat sunny daylight, light sea-blue ground, Roblox-like; shots placed in Roblox axes (x right, y up, nose -z).
Writes overview, g_chase, g_phone (320 px wide; upscale 2x nearest outside Blender), side, c_winch, c_cabin, c_rear, scale.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
FBX = ARGS[1] if len(ARGS) > 1 else None
KEEP = ("M_Veh_RescueHeli_Body_LOD0", "M_Veh_RescueHeli_Paint_LOD0", "M_Veh_RescueHeli_Glass_LOD0", "M_Veh_RescueHeli_Gear_LOD0", "M_Veh_RescueHeli_MainRotor_LOD0", "M_Veh_RescueHeli_TailRotor_LOD0")
SKID_Y = -4.5
REAR_EYE = (3.0, -1.0, 24.0)     # r7: rear doors close-up, low behind the tail (under boom + stabiliser)


def p(x, y, z):
    return Vector((-x, z, y))


def rgb(r, g, b):
    return (r / 255) ** 2.2, (g / 255) ** 2.2, (b / 255) ** 2.2, 1.0


def setup():
    sc = bpy.context.scene
    for o in sc.objects:
        hide = o.name not in KEEP and not o.name.startswith(("STL_", "REF_"))
        o.hide_render = hide
        o.hide_set(hide)
    ground = bpy.data.objects.get("STL_Ground")
    if ground is None:
        bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, SKID_Y - 0.02))
        ground = bpy.context.active_object
        ground.name = "STL_Ground"
        m = bpy.data.materials.new("STL_Sea")
        m.use_nodes = True
        bs = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bs.inputs["Base Color"].default_value = rgb(120, 190, 225)
        bs.inputs["Roughness"].default_value = 0.6
        ground.data.materials.append(m)
    sun = bpy.data.objects.get("STL_Sun")
    if sun is None:
        sun = bpy.data.objects.new("STL_Sun", bpy.data.lights.new("STL_Sun", "SUN"))
        sc.collection.objects.link(sun)
    sun.data.energy = 4.0
    sun.data.angle = math.radians(3)
    sun.rotation_euler = (math.radians(40), 0, math.radians(-35))     # high, from the front-right
    w = bpy.data.worlds.new("STL_Sky")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = rgb(165, 210, 245)
    bg.inputs["Strength"].default_value = 1.0
    sc.world = w
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    try:
        sc.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    sc.render.image_settings.file_format = "PNG"
    sc.render.film_transparent = False
    cam = bpy.data.objects.get("STL_Cam")
    if cam is None:
        cam = bpy.data.objects.new("STL_Cam", bpy.data.cameras.new("STL_Cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def shot(sc, cam, name, eye, target, fov_v=None, lens=None, w=1000, h=625):
    cam.location = p(*eye)
    cam.rotation_euler = (p(*target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    if fov_v:
        cam.data.sensor_fit = "VERTICAL"
        cam.data.angle_y = math.radians(fov_v)
    else:
        cam.data.sensor_fit = "AUTO"
        cam.data.lens = lens
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.resolution_percentage = 100
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath


def scale_refs():
    """Shipped JetSki and RIB LOD0 beside the heli, feet on the ground."""
    if not FBX:
        return
    for asset, x in (("M_Veh_JetSki", -16.0), ("M_Veh_RIB", 22.0)):
        path = os.path.join(FBX, asset, asset + "_LOD0.fbx")
        if not os.path.isfile(path) or bpy.data.objects.get("REF_" + asset):
            continue
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=path)
        objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        for o in objs:
            if o.name.endswith("_COL"):
                o.hide_render = True
                o.hide_set(True)
        vis = [o for o in objs if not o.hide_render]
        pts = [o.matrix_world @ Vector(c) for o in vis for c in o.bound_box]
        lo = Vector([min(q[i] for q in pts) for i in range(3)])
        hi = Vector([max(q[i] for q in pts) for i in range(3)])
        shift = p(x, 0, 0) - Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z - (SKID_Y - 0.02)))
        for o in objs:
            o.location += shift
            o.name = "REF_" + o.name
        print("[stills] %s %d meshes, size %s" % (asset, len(vis), tuple(round(v, 1) for v in hi - lo)))


def main():
    os.makedirs(OUT, exist_ok=True)
    sc, cam = setup()
    out = [
        shot(sc, cam, "overview", (30, 14, -30), (0, 0.5, 3), lens=40),
        shot(sc, cam, "g_chase", (0, 16, 47), (0, 2, 4), fov_v=70, w=1000, h=562),
        shot(sc, cam, "g_phone", (0, 16, 47), (0, 2, 4), fov_v=70, w=320, h=180),
        shot(sc, cam, "side", (75, 1.0, 5), (0, 0.5, 5), lens=55),
        shot(sc, cam, "c_winch", (17, 3.0, -6.0), (6.0, -0.6, 2.4), lens=38),
        shot(sc, cam, "c_cabin", (-9, 4.0, -14), (0, 0.3, -3.2), lens=45),
        shot(sc, cam, "c_rear", REAR_EYE, (0, -0.3, 5.8), lens=65),
    ]
    scale_refs()
    out.append(shot(sc, cam, "scale", (4, 24, -52), (3, -2, 2), lens=35))
    print("[stills]", out)


main()
