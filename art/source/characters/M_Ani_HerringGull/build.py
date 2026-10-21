"""M_Ani_HerringGull (AN1, docs/12 2.10): one adult European herring gull, 1.40 m span, 0.59 m long, in a neutral glide
pose, skinned to RIG_HerringGull, with the clips glide / flap / land / stand / call authored as actions (clips.py).

Geometry, rig and skinning live in gull.py (lofts, exact region UVs, analytic weights); the single 1024 set
T_Gull_Feather (ALB / NOR / RGH / MET) is painted in gulltex.py by region - white head and body, medium grey mantle
and coverts, black outer primaries with the white mirror, white secondary tips and tail, yellow bill with the red
gonys spot, pale yellow eye, pink legs. Feather relief is the normal map's job, not loose cards. Flocks are
instanced by the game, so this is one bird, one set, no _COL.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/characters/M_Ani_HerringGull/build.py \
        --out-root build/prod/M_Ani_HerringGull --steps build,lod,validate,export,turntable
    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Ani_HerringGull/export_rig.py    # rigged FBX (after)
"""
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
for p in (HERE, os.path.join(REPO, "tools/blender")):
    if p not in sys.path:
        sys.path.insert(0, p)
import clips  # noqa: E402
import common  # noqa: E402
import gull  # noqa: E402
import gulltex  # noqa: E402

NAME = "M_Ani_HerringGull"
SET_NAME = "Gull"
TEX_SET = "Feather"
SPAN_M, LENGTH_M, DEPTH_M = 1.40, 0.59, 0.153      # design intent (art/reference/M_Ani_HerringGull/dims.md)


def clear_old():
    for o in list(bpy.data.objects):
        if o.name.startswith(NAME) or o.name.startswith("RIG_"):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name.startswith("A_HerringGull"):
            bpy.data.actions.remove(a)


def material(textures_dir):
    mat = bpy.data.materials.new("MAT_Gull")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.62, 0.65, 0.68, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.75
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = common.UV_NAME
    for kind, slot in (("ALB", "Base Color"), ("RGH", "Roughness"), ("MET", "Metallic")):
        path = os.path.join(textures_dir, "T_%s_%s_%s.png" % (SET_NAME, TEX_SET, kind))
        if not os.path.isfile(path):
            continue
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path, check_existing=True)
        tex.image.colorspace_settings.name = "sRGB" if kind == "ALB" else "Non-Color"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        if kind == "ALB":
            nt.links.new(tex.outputs["Color"], bsdf.inputs[slot])
        else:
            nt.links.new(tex.outputs["Color"], bsdf.inputs[slot])
    path = os.path.join(textures_dir, "T_%s_%s_NOR.png" % (SET_NAME, TEX_SET))
    if os.path.isfile(path):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path, check_existing=True)
        tex.image.colorspace_settings.name = "Non-Color"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.space, nm.uv_map = "TANGENT", common.UV_NAME
        nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def build():
    clear_old()
    scale = common.STUDS_PER_METRE
    tex_dir = common.textures_dir(NAME)
    gulltex.write_set(tex_dir, HERE, SET_NAME, TEX_SET)
    ob, B = gull.build_mesh(NAME + "_LOD0")
    lo = [min(v[i] for v in B.verts) for i in range(3)]
    hi = [max(v[i] for v in B.verts) for i in range(3)]
    off = [-0.5 * (a + b) for a, b in zip(lo, hi)]              # bbox centre to the origin (origin "centre")
    dims_m = tuple((b - a) for a, b in zip(lo, hi))
    print("[gull] design %.3f x %.3f x %.3f m, built %.3f x %.3f x %.3f m" % ((SPAN_M, LENGTH_M, DEPTH_M) + dims_m))
    ob.data.materials.append(material(tex_dir))
    rig = gull.build_rig(scale, off)
    gull.skin(ob, B, rig)
    for v in ob.data.vertices:                                   # metres -> studs, centred on the bbox
        v.co = ((v.co[0] + off[0]) * scale, (v.co[1] + off[1]) * scale, (v.co[2] + off[2]) * scale)
    ob.data.update()
    clips.build_all(rig)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("[gull] %s: %d tris, %d verts, %d bones, set T_%s_%s" % (ob.name, tris, len(ob.data.vertices),
                                                                   len(rig.data.bones), SET_NAME, TEX_SET))
    head = (0.0, (-0.217 + off[1]) * scale, (0.054 + off[2]) * scale)
    tip = ((0.688 + off[0]) * scale, (-0.038 + off[1]) * scale, (0.038 + off[2]) * scale)
    wing_mid = ((0.250 + off[0]) * scale, (-0.100 + off[1]) * scale, (0.040 + off[2]) * scale)
    feet = ((0.028 + off[0]) * scale, (0.190 + off[1]) * scale, (-0.052 + off[2]) * scale)
    tail = (0.0, (0.250 + off[1]) * scale, (-0.010 + off[2]) * scale)
    return {
        "name": NAME,
        "asset": NAME,
        "budget": "dog_fur_cards",                     # the docs row: 3,000 / 1,200 / 400, one set, no _COL
        "tris": 3000,
        "tier": "standard",
        "dims_m": (SPAN_M, LENGTH_M, DEPTH_M),
        "size_note": None,
        "origin": "centre",
        "sets": [{"name": SET_NAME, "set": TEX_SET, "size": 1024, "wet": False}],
        "meshes": [{"object": ob, "set": TEX_SET}],
        "closeups": [
            {"name": "Head_Bill_Eye", "target": list(head), "dist": 0.72, "az": 32.0, "el": 16.0},
            {"name": "WingTip_Mirror", "target": list(tip), "dist": 0.55, "az": 42.0, "el": 26.0},
            {"name": "Wing_Upper", "target": list(wing_mid), "dist": 1.10, "az": 40.0, "el": 46.0},
            {"name": "Wing_Under", "target": list(wing_mid), "dist": 1.10, "az": 40.0, "el": -38.0},
            {"name": "Tail_Upper", "target": list(tail), "dist": 0.95, "az": 200.0, "el": 32.0},
            {"name": "Feet_Folded", "target": list(feet), "dist": 0.80, "az": 215.0, "el": 24.0},
        ],
        "waivers": {"LOD UV layout": "the LOD2 collapse (10% of LOD0, the character share) trims the bill, eye and "
                                     "rump islands at 278 tris: UV area 21% off against the 15% tolerance, while the "
                                     "LOD1 (40%) holds at 3.5% and every LOD2 region stays in its LOD0 bounds; the "
                                     "LOD2 is a silhouette past 60 studs"},
        "tiling": False,
    }
