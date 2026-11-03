"""M_Ani_GreySeal ("Old Ned", docs/12 2.10 AN1): one grey seal bull, 2.46 m over the hind flippers, in a neutral
swim glide, skinned to RIG_Seal, with the clips swim / surface / look / haul-out / flee authored as actions (clips.py).

Geometry, armature and the analytic weights live in seal.py; the two texture sets (Coat 2048, Face 1024, each with a
_Wet twin) are painted in sealtex.py by evaluating the same shape maths (seal_shape.py) the mesh is lofted from.
Two MeshParts, one set each, as the pipeline wants one material per mesh: Body (the coat, the four flippers and the
back studs) and Head (the neck, the blocky muzzle, the bead eyes). r1 (2026-11-01) is the toy pass; r2 makes the rest
pose (what the game shows, static) the haul-out arch: head and chest raised, a bigger blocky head, splayed paddle
fore-flippers, thick V hind flippers, three spine studs, neutral Lego grey with a near-white belly. r3: warm stone
grey with flat dapples, a cream belly stepped in at the seam, a 1.25x boxy skull with a flat face carrying the eyes, a
cream muzzle box and black nose block (lofted like the flippers), a taller S-curve arch, bigger darker flippers.
r4: boxy hips-to-nose section, a narrower skull on a wider neck, a 1x3 brick plate with three studs on the back,
rounded-rectangle (crisp bevel) flippers and muzzle box, a planar-mapped muzzle front, three clean colour zones.
r5: rounded-rectangle body / head sections (flat panels), darker coat, bigger dapples, a darker seated plate,
a clearer Swim, eye rings, a wider creased neck. r6: crisp-cornered torso (flat back to the hips, blunt tail), neutral
stone grey with lighter flanks, a light plate, bigger slate flippers, a head-up Swim with the tail and hind flippers up.
r7: the back renders neutral mid grey over a warm off-white belly; the plate one step lighter, on a dark seam, ringed studs.

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
DIMS_M = (1.003, 2.543, 0.940)              # r6 rest pose: a 2.5 m bull, head raised (0.94 m tall), the 1.12x
                                            # fore-flippers splayed (1.0 m across them), the bigger muzzle box


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
            {"name": "RomanNose", "target": tgt(0.0, -1.20, 0.20, off, scale), "dist": 2.05, "az": 88.0, "el": 4.0},
            {"name": "Whiskers", "target": tgt(0.11, -1.22, 0.18, off, scale), "dist": 1.40, "az": 138.0, "el": 4.0},
            {"name": "Eye_Brow", "target": tgt(0.155, -1.05, 0.36, off, scale), "dist": 0.98, "az": 62.0, "el": 10.0},
            {"name": "Neck_Folds", "target": tgt(0.06, -0.62, 0.34, off, scale), "dist": 1.40, "az": 118.0, "el": 22.0},
            {"name": "ForeFlipper", "target": tgt(0.30, 0.16, 0.17, off, scale), "dist": 1.30, "az": 146.0, "el": 34.0},
            {"name": "HindFlipper", "target": tgt(0.14, 1.10, 0.18, off, scale), "dist": 1.10, "az": 196.0, "el": 30.0},
        ],
        "tiling": False,
        "lod_symmetry": "X",                            # r5: the flat panels decimate unevenly without it (LOD2 UV area)
        "waivers": {},                                  # r1: no claws / whisker prisms, the LOD UV layout passes
    }


def tgt(x, y, z, off, scale):
    """A build-space (metre) point in the exported (stud, centred) space, for the turntable's close-ups."""
    x, y, z = seal.S.bend([(x, y, z)])[0]
    return [round((x + off[0]) * scale, 4), round((y + off[1]) * scale, 4), round((z + off[2]) * scale, 4)]
