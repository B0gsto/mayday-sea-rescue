"""Pipeline self-test asset: a cast-iron mooring bollard at real size (about 0.35 m diameter, 0.55 m tall;
docs/12 2.3 row M_Hbr_Bollard, verify). Not a shipping asset (HP2 owns the real bollards): it exercises
build, lod, validate and export, with a _COL proxy, an ATT_* empty and one placeholder PBR set.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build tools/blender/selftest/PipelineBollard/build.py \
        --out-root build/blender-selftest --steps build,lod,validate,export
"""
import math
import os

import bmesh
import bpy

import common
import rbxkit

# PIPELINE_SELFTEST_BREAK=scale builds it in metres (1 unit = 1 m, the classic mistake): validate must fail, nothing exported.
BROKEN = os.environ.get("PIPELINE_SELFTEST_BREAK") == "scale"


def m(metres):
    return metres if BROKEN else common.metres_to_studs(metres)


NAME = "M_Prop_PipelineBollard"
SEGMENTS = 28

# Lathe profile (radius, height) in metres, bottom to top: base flange, waisted body, neck, mushroom head.
PROFILE = [(0.0, 0.0), (0.175, 0.0), (0.175, 0.03), (0.15, 0.045), (0.13, 0.08), (0.12, 0.2), (0.115, 0.33),
           (0.105, 0.40), (0.105, 0.43), (0.15, 0.47), (0.175, 0.50), (0.17, 0.53), (0.12, 0.55), (0.0, 0.55)]


def lathe(name, profile, segments):
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r == 0.0:
            rings.append([bm.verts.new((0.0, 0.0, m(z)))])
        else:
            rings.append([bm.verts.new((m(r) * math.cos(2 * math.pi * i / segments), m(r) * math.sin(2 * math.pi * i / segments), m(z)))
                          for i in range(segments)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            if len(a) == 1:
                bm.faces.new((a[0], b[j], b[i]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.035, 0.038, 0.04, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.65
    return mat


def build():
    body = lathe(NAME + "_LOD0", PROFILE, SEGMENTS)
    rbxkit.smart_uv(body, angle=60, margin=0.02)
    body.data.uv_layers[0].name = "UVMap"
    body.data.materials.append(material("MI_PipelineBollard_Iron"))
    for p in body.data.polygons:
        p.use_smooth = True

    col = lathe(NAME + "_COL", [(0.0, 0.0), (0.175, 0.0), (0.175, 0.55), (0.0, 0.55)], 8)

    att = bpy.data.objects.new("ATT_RopeNeck", None)
    att.location = (0.0, 0.0, m(0.415))
    bpy.context.scene.collection.objects.link(att)

    return {
        "name": NAME,
        "budget": os.environ.get("PIPELINE_SELFTEST_BUDGET", "small_prop"),   # large_prop exercises LOD2
        "tris": 800,                         # docs/12 2.3: bollards 800 each
        "tier": "standard",
        "dims_m": (0.35, 0.35, 0.55),
        "origin": "base",
        "sets": [{"name": "PipelineBollard", "set": "Iron", "size": 1024}],
        "meshes": [{"object": body, "set": "Iron"}, {"object": col}],
        "attachments": [att],
    }
