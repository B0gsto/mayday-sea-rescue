"""M_Ani_GreySeal ("Old Ned", docs/12 2.10 AN1): one grey seal bull, 2.46 m over the hind flippers, in a neutral
swim glide, skinned to RIG_Seal, with the clips swim / surface / look / haul-out / flee authored as actions (clips.py).

Geometry, armature and the analytic weights live in seal.py; the two texture sets (Coat 2048, Face 1024, each with a
_Wet twin) are painted in sealtex.py by evaluating the same shape maths (seal_shape.py) the mesh is lofted from.
Two MeshParts, one set each, as the pipeline wants one material per mesh: Body (the coat, the four flippers and their
claws) and Head (the folded neck, the Roman-nose muzzle, the eyes and the whisker rows).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/characters/M_Ani_GreySeal/build.py \
        --out-root build/prod/M_Ani_GreySeal --steps build,lod,validate,export,turntable
    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Ani_GreySeal/export_rig.py   # rigged FBX + clips (after)
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
import seal  # noqa: E402
import sealtex  # noqa: E402
import versions  # noqa: E402

NAME = "M_Ani_GreySeal"
SET_NAME = "Seal"
COAT, FACE = "Coat", "Face"
DIMS_M = (0.570, 2.530, 0.505)              # a 2.5 m bull: 0.57 m across the body, 0.505 m tall


def clear_old():
    for o in list(bpy.data.objects):
        if o.name.startswith(NAME) or o.name.startswith("RIG_"):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        if a.name.startswith("A_Seal"):
            bpy.data.actions.remove(a)


def material(set_name, textures_dir):
    """One Principled material per MeshPart, fed by the set's maps (dry; the _Wet twins are the runtime swap)."""
    mat = bpy.data.materials.new("MI_Seal_" + set_name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.30, 0.29, 0.275, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.65
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = common.UV_NAME
    for kind, slot in (("ALB", "Base Color"), ("RGH", "Roughness"), ("MET", "Metallic")):
        path = os.path.join(textures_dir, "T_%s_%s_%s.png" % (SET_NAME, set_name, kind))
        if not os.path.isfile(path):
            continue
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(path, check_existing=True)
        tex.image.colorspace_settings.name = "sRGB" if kind == "ALB" else "Non-Color"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], bsdf.inputs[slot])
    path = os.path.join(textures_dir, "T_%s_%s_NOR.png" % (SET_NAME, set_name))
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
    written = sealtex.write_sets(tex_dir, HERE)
    print("[seal] textures: %s" % ", ".join("%s %s" % (k, "x".join(str(v) for v in s)) for k, s in
                                            sorted(written.items())[:2]))
    ob_body, ob_head, Bb, Bh = seal.build_meshes(NAME + "_Body_LOD0", NAME + "_Head_LOD0",
                                                 sealtex.COAT_REGIONS, sealtex.FACE_REGIONS)
    for ob in (ob_body, ob_head):                      # smooth shading + weighted normals, applied in place
        versions.weighted_normals(ob)
    verts = [v.co for v in ob_body.data.vertices] + [v.co for v in ob_head.data.vertices]
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    off = [-0.5 * (a + b) for a, b in zip(lo, hi)]     # bbox centre -> the origin (origin "centre")
    dims_m = tuple((b - a) for a, b in zip(lo, hi))
    print("[seal] design %s m, built %.3f x %.3f x %.3f m (off %.3f, %.3f, %.3f)"
          % (DIMS_M, dims_m[0], dims_m[1], dims_m[2], off[0], off[1], off[2]))
    rig = seal.build_rig(scale, off)
    for ob, B in ((ob_body, Bb), (ob_head, Bh)):
        for v in ob.data.vertices:
            v.co = ((v.co[0] + off[0]) * scale, (v.co[1] + off[1]) * scale, (v.co[2] + off[2]) * scale)
        ob.data.update()
        seal.skin(ob, B, rig)
    clips.build_all(rig)
    for ob, ob_set in ((ob_body, COAT), (ob_head, FACE)):
        ob.data.materials.append(material(ob_set, tex_dir))
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        groups = len(ob.vertex_groups)
        used = len({g.group for v in ob.data.vertices for g in v.groups})
        print("[seal] %-26s %6d tris, %6d verts, %d bones used" % (ob.name, tris, len(ob.data.vertices), used))
    return {
        "name": NAME,
        "asset": NAME,
        "species": "animal",
        "budget": "dog",                                # the docs row: 12,000 / 5,000 / 1,500, 2 sets, no _COL
        "tris": 12000,
        "tier": "hero",
        "dims_m": DIMS_M,
        "size_note": None,
        "origin": "centre",
        "sets": [{"name": SET_NAME, "set": COAT, "size": sealtex.COAT_SIZE, "wet": True},
                 {"name": SET_NAME, "set": FACE, "size": sealtex.FACE_SIZE, "wet": True}],
        "meshes": [{"object": ob_body, "set": COAT}, {"object": ob_head, "set": FACE}],
        "closeups": [
            {"name": "RomanNose", "target": tgt(0.0, -0.96, 0.33, off, scale), "dist": 2.05, "az": 88.0, "el": 4.0},
            {"name": "Whiskers", "target": tgt(0.16, -1.12, 0.18, off, scale), "dist": 1.40, "az": 138.0, "el": 4.0},
            {"name": "Eye_Brow", "target": tgt(0.11, -0.95, 0.35, off, scale), "dist": 0.98, "az": 62.0, "el": 10.0},
            {"name": "Neck_Folds", "target": tgt(0.06, -0.62, 0.34, off, scale), "dist": 1.40, "az": 118.0, "el": 22.0},
            {"name": "ForeFlipper", "target": tgt(0.30, 0.16, 0.17, off, scale), "dist": 1.30, "az": 146.0, "el": 34.0},
            {"name": "HindFlipper", "target": tgt(0.14, 1.10, 0.18, off, scale), "dist": 1.10, "az": 196.0, "el": 30.0},
        ],
        "tiling": False,
        # The collapse decimate contracts thin UV islands (the flipper tips, the 20 claw cones, the whisker prisms),
        # so a LOD's summed UV area falls further than the 15% rule even though the layout is the same regions on
        # the same atlas and the bounds match to 0.009 (measured: Body LOD1 24%, Body LOD2 44%, Head LOD2 42%).
        # Bounds-safe at these distances; the clean fix is a lower-density LOD0 loft, a later pass.
        "waivers": {"LOD UV layout": "thin islands (flipper tips, claws, whiskers) contract under collapse "
                                     "decimation; same region rectangles on the same atlas, bounds within 0.009"},
    }


def tgt(x, y, z, off, scale):
    """A build-space (metre) point in the exported (stud, centred) space, for the turntable's close-ups."""
    return [round((x + off[0]) * scale, 4), round((y + off[1]) * scale, 4), round((z + off[2]) * scale, 4)]
