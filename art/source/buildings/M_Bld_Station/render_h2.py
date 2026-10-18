"""H2 review renders (EEVEE): station + slipway LOD0 with their PBR sets, a water plane at sea level, seabed, day and night.
    ~/RobloxProjects/tools/blender-run.sh art/source/buildings/M_Bld_Station/render_h2.py
Writes assets/review/M_Bld_Station/h2/*.png (the contact sheet is contact_sheet_h2.py, system python)."""
import math
import os
import bpy
from mathutils import Vector

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/review/M_Bld_Station/h2/"
TX = G + "assets/textures/"
bpy.ops.wm.open_mainfile(filepath=G + "art/source/buildings/M_Bld_Station/M_Bld_Station.blend")
sc = bpy.context.scene
with bpy.data.libraries.load(G + "art/source/buildings/M_Bld_Slipway/M_Bld_Slipway.blend") as (src, dst):
    dst.objects = [n for n in src.objects if n.endswith("_LOD0") or n.startswith("ATT_")]
S = Vector((-55.0, -69.0, 0.0))            # slipway pivot relative to the station pivot (greybox placements, both yaw 180)
for o in dst.objects:
    o.name = "SW_" + o.name if o.name.startswith("ATT_") else o.name
    sc.collection.objects.link(o)
    o.location = o.location + S
for o in sc.objects:
    if o.type == "MESH" and not o.name.endswith("_LOD0"):
        o.hide_render = True

SETS = {"Station_Stone": "M_Bld_Station/T_Station_Granite", "Station_Render": "M_Bld_Station/T_Station_Render",
        "Station_Roof": "M_Bld_Station/T_Station_Slate", "Station_Trim": "M_Bld_TrimSheet/T_BldTrim_Sheet",
        "Station_Details": "M_Bld_Station/T_Station_Details", "Station_BayDoor": "M_Bld_Station/T_Station_Details",
        "Station_GlassLit": "M_Bld_Station/T_Station_Details", "Station_Plinth": "M_Bld_Station/T_Station_GraniteBase",
        "Slipway_Ramp": "Materials/T_Mat_Concrete", "Slipway_Weedy": "Materials/T_Mat_WeedyConcrete",
        "Slipway_Tide": "M_Bld_Slipway/T_Slipway_Tide", "Slipway_Steel": "M_Bld_Slipway/T_Slipway_Steel",
        "Slipway_Wall": "Materials/T_Mat_QuayStone", "Slipway_Rock": "Materials/T_Mat_KelpRock"}
WET = {"Slipway_Weedy", "Slipway_Tide", "Slipway_Rock"}


def img(path, data):
    im = bpy.data.images.load(path, check_existing=True)
    im.colorspace_settings.name = "Non-Color" if data else "sRGB"
    return im


def pbr(key, stem, wet, lit=False):
    m = bpy.data.materials.new("H2_" + key)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    for kind in ("ALB", "RGH", "MET", "NOR"):
        p = TX + stem + "_" + kind + ("_Wet" if wet and kind in ("ALB", "RGH") else "") + ".png"
        if not os.path.exists(p):
            continue
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = img(p, kind != "ALB")
        nt.links.new(uv.outputs["UV"], t.inputs["Vector"])
        if kind == "ALB":
            nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        elif kind == "RGH":
            nt.links.new(t.outputs["Color"], b.inputs["Roughness"])
        elif kind == "MET":
            nt.links.new(t.outputs["Color"], b.inputs["Metallic"])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nm.uv_map = "UVMap"
            nt.links.new(t.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    if lit:
        b.inputs["Emission Color"].default_value = (1.0, 0.62, 0.3, 1)
        b.inputs["Emission Strength"].default_value = 0.0
    return m


LIT = None
for o in sc.objects:
    if o.type == "MESH" and o.name.endswith("_LOD0"):
        key = o.name.replace("M_Bld_", "").replace("_LOD0", "")
        if key in SETS:
            m = pbr(key, SETS[key], key in WET, lit=key == "Station_GlassLit")
            o.data.materials.clear()
            o.data.materials.append(m)
            if key == "Station_GlassLit":
                LIT = m
# sea, seabed
bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, 0, -4.0))
sea = bpy.context.object
wm = bpy.data.materials.new("H2_Sea")
wm.use_nodes = True
wb = wm.node_tree.nodes.get("Principled BSDF")
wb.inputs["Base Color"].default_value = (0.02, 0.06, 0.06, 1)
wb.inputs["Roughness"].default_value = 0.04
wb.inputs["Alpha"].default_value = 0.62
wm.surface_render_method = "BLENDED"
sea.data.materials.append(wm)
bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, 0, -16.2))
bed = bpy.context.object
bm = bpy.data.materials.new("H2_Bed")
bm.use_nodes = True
bm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.16, 0.15, 0.11, 1)
bed.data.materials.append(bm)
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, -0.02))     # ground/apron around the station
gnd = bpy.context.object
gm = bpy.data.materials.new("H2_Gnd")
gm.use_nodes = True
gm.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.12, 0.12, 0.115, 1)
gnd.data.materials.append(gm)
gnd.scale = (0.25, 0.22, 1)
gnd.location = (0, 10, -0.02)

world = bpy.data.worlds.new("H2W")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
sc.world = world
bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(-35)))
sun = bpy.context.object
sun.data.angle = math.radians(3)
cam = bpy.data.objects.new("H2Cam", bpy.data.cameras.new("H2Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 32
sc.render.engine = "BLENDER_EEVEE"
sc.eevee.taa_render_samples = 48
try:
    sc.eevee.use_raytracing = True
except Exception:
    pass
sc.render.resolution_x, sc.render.resolution_y = 1000, 562
sc.view_settings.view_transform = "AgX"

att = {o.name: o.location.copy() for o in sc.objects if o.name.startswith("ATT_") or o.name.startswith("SW_ATT_")}
off = att["ATT_WatchRoom"] / 3.0 - Vector((5.0, -8.1 + 1.2, 5.2))     # station recentre offset (m)


def st(x, y, z):     # station metres -> studs
    return (Vector((x, y, z)) + off) * 3.0


def sw(x, y, z):     # slipway metres -> studs
    return Vector((x, y, z)) * 3.0 + S


def shot(name, target, dist_m, az, el, lens=32):
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.location = target + d * dist_m * 3.0
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    sc.render.filepath = OUT + name + ".png"
    bpy.ops.render.render(write_still=True)
    print("[h2] wrote", name)


def day():
    bg.inputs["Color"].default_value = (0.55, 0.62, 0.72, 1)
    bg.inputs["Strength"].default_value = 0.9
    sun.data.energy, sun.data.color = 3.2, (1.0, 0.95, 0.88)


day()
shot("day_front3q", st(0.0, -8.1, 5.0), 34, 35, 9)
shot("slip_toe_waterline", sw(0.0, -19.0, -2.8), 17, 62, 22)
shot("slip_side_wall", sw(3.66, -4.6, -0.3), 5.0, -50, 12, lens=26)
shot("roof_closeup", st(3.0, 3.5, 10.4), 12, 145, 30)
shot("rear_gable", st(4.5, 8.1, 4.6), 17, 180, 6)
# night: warm lit glazing, door lamp, floodlights on the shutter
bg.inputs["Color"].default_value = (0.02, 0.03, 0.06, 1)
bg.inputs["Strength"].default_value = 0.25
sun.data.energy, sun.data.color = 0.06, (0.6, 0.7, 1.0)
LIT.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = 6.0
bpy.ops.object.light_add(type="POINT", location=att["ATT_Lamp_Door"])
bpy.context.object.data.energy, bpy.context.object.data.color = 900, (1.0, 0.7, 0.4)
bpy.context.object.data.shadow_soft_size = 0.2
for k in ("ATT_Lamp_Flood_01", "ATT_Lamp_Flood_02"):
    bpy.ops.object.light_add(type="SPOT", location=att[k], rotation=(math.radians(-45), 0, 0))
    L = bpy.context.object.data
    L.energy, L.color, L.spot_size, L.spot_blend = 9000, (1.0, 0.86, 0.7), math.radians(100), 0.5
    L.shadow_soft_size = 0.3
bpy.ops.object.light_add(type="POINT", location=att["ATT_WatchRoom"] + Vector((0, 4, 0)))
bpy.context.object.data.energy, bpy.context.object.data.color = 1500, (1.0, 0.7, 0.4)
shot("night_front3q", st(-1.0, -8.1, 4.5), 30, 28, 7)
print("[h2] done")
