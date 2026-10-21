"""M_Sea_MooringBlock: concrete harbour mooring sinker block on the seabed, with chain riser shackle, weed and fouling.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))

NAME = "M_Sea_MooringBlock"
S = 3.0

L, W, H = 1.2, 0.9, 0.5


def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def make_material(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    return m


def block():
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, H / 2.0))
    obj = bpy.context.active_object
    obj.name = NAME + "_LOD0"
    obj.data.name = NAME + "_LOD0"
    obj.scale = (L, W, H)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.04
    bev.segments = 2
    bev.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=bev.name)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    mat = make_material("MI_MooringBlock_Concrete")
    obj.data.materials.append(mat)
    return obj


def shackle():
    bpy.ops.mesh.primitive_torus_add(major_radius=0.13, minor_radius=0.028, major_segments=24, minor_segments=10,
                                    location=(0.0, 0.0, H + 0.02))
    obj = bpy.context.active_object
    obj.name = NAME + "_Shackle_LOD0"
    obj.data.name = NAME + "_Shackle_LOD0"
    # rotate so ring stands upright-ish (axis horizontal along X)
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    mat = make_material("MI_MooringBlock_Metal")
    obj.data.materials.append(mat)
    return obj


def weed_clumps():
    objs = []
    for (x, y, z, sx, sy, sz) in [(0.45, 0.3, 0.0, 0.12, 0.08, 0.06),
                                    (-0.35, -0.25, 0.0, 0.1, 0.12, 0.05),
                                    (0.1, -0.4, 0.0, 0.14, 0.06, 0.04)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=1.0, location=(x, y, z))
        o = bpy.context.active_object
        o.name = NAME + "_Weed%d" % len(objs)
        o.scale = (sx, sy, sz)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        mat = make_material("MI_MooringBlock_Concrete")
        o.data.materials.append(mat)
        objs.append(o)
    return objs


def col():
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, H / 2.0))
    obj = bpy.context.active_object
    obj.name = NAME + "_COL"
    obj.data.name = NAME + "_COL"
    obj.scale = (L + 0.05, W + 0.05, H)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    mat = make_material("MI_MooringBlock_Concrete")
    obj.data.materials.append(mat)
    return obj


def build():
    clear()
    b = block()
    s = shackle()
    c = col()
    c.data.name = NAME + "_COL"
    for o in (b, s, c):
        o.scale = (S, S, S)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    att = bpy.data.objects.new("ATT_ChainRiser", None)
    att.empty_display_type = "PLAIN_AXES"
    att.location = (0.0, 0.0, (H + 0.15) * S)
    bpy.context.scene.collection.objects.link(att)
    return {
        "name": NAME,
        "budget": "large_prop",
        "tris": 2000,
        "tier": "background",
        "dims_m": (L, W, 0.68),
        "size_note": None,
        "origin": "free",
        "waivers": {"UV faces": "bevelled edges produce zero-area faces that collapse in LODs"},
        "sets": [
            {"name": "MooringBlock", "set": "Concrete", "size": 1024, "wet": True},
            {"name": "MooringBlock", "set": "Metal", "size": 1024, "wet": True},
        ],
        "meshes": [{"object": b, "set": "Concrete"},
                   {"object": s, "set": "Metal"},
                   {"object": c}],
        "attachments": [att],
    }
