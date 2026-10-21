"""M_Ani_GreySeal rigged export: RIG_Seal + the LOD0 MeshParts + every clip in one FBX for the Roblox importer.

run.py's `clips` / `clips-rbxm` steps are not ported (docs/12 1.1), so the rigged file is written by this script:
same axis and scale settings as tools/blender/export.py (roblox = (-bx, bz, by), 1 unit = 1 stud), skinning on,
one animation per action. Run it after build.py has saved M_Ani_GreySeal.blend:

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Ani_GreySeal/export_rig.py

It then re-imports the file into an empty scene and prints what came back (meshes, bones, animations, triangles).
"""
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
for p in (HERE, os.path.join(REPO, "tools/blender")):
    if p not in sys.path:
        sys.path.insert(0, p)
import common  # noqa: E402

NAME = "M_Ani_GreySeal"
RIG = "RIG_Seal"


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_root = args[0] if args else None
    if out_root:
        common.set_out_root(out_root)
    blend = os.path.join(HERE, NAME + ".blend")
    if not os.path.isfile(blend):
        raise SystemExit("build first: no %s" % blend)
    bpy.ops.wm.open_mainfile(filepath=blend)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name.endswith("_LOD0")]
    rig = bpy.data.objects.get(RIG)
    if not rig or not meshes:
        raise SystemExit("no %s or no _LOD0 meshes in %s" % (RIG, blend))
    out_dir = os.path.join(common.out_root(), "fbx", NAME)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, NAME + "_RIG.fbx")
    for o in bpy.context.scene.objects:
        o.select_set(o in meshes or o is rig)
    bpy.context.view_layer.objects.active = rig
    actions = sorted(a.name for a in bpy.data.actions if a.name.startswith("A_Seal"))
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={'MESH', 'ARMATURE'}, apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0, axis_forward='-Z', axis_up='Y',
        use_mesh_modifiers=True, mesh_smooth_type='FACE', use_triangles=True, use_tspace=True, add_leaf_bones=False,
        bake_anim=True, bake_anim_use_all_actions=True, bake_anim_force_startend_keying=True, bake_anim_step=1.0,
        bake_anim_simplify_factor=0.0, path_mode='STRIP', embed_textures=False)
    print("[export_rig] wrote %s (%.2f MB)" % (os.path.relpath(path, common.REPO_DIR),
                                              os.path.getsize(path) / 1e6))
    meta = {"asset": NAME, "file": os.path.relpath(path, common.REPO_DIR), "rig": RIG,
            "meshes": sorted(o.name for o in meshes), "clips": actions,
            "settings": "rbxkit axis/scale (roblox = (-bx, bz, by), 1 BU = 1 stud), skinning on, one animation per action",
            "next": "Roblox upload: FBX with skinning + animations (docs/12 2.10 AN1); clips also authored in-clips.py"}
    with open(os.path.join(out_dir, NAME + "_RIG.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    # read back
    verts = sum(len(o.data.vertices) for o in meshes)
    tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    got_m = sorted(o.name for o in bpy.context.scene.objects if o.type == 'MESH')
    got_a = sorted(o.name for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    bones = sum(len(o.data.bones) for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    anims = sorted(a.name for a in bpy.data.actions)
    print("[export_rig] read back: meshes %s, armatures %s (%d bones), %d actions" % (got_m, got_a, bones, len(anims)))
    print("[export_rig] source: %d verts, %d tris, clips %s" % (verts, tris, actions))
    import posepass                       # same run: the pose check renders (skinning + every clip)
    posepass.main()


if __name__ == "__main__":
    main()
