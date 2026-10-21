"""M_Ani_HerringGull skinned export (the repo's characters use their own export_rig.py: tools/blender/export.py writes
meshes only and run.py's "clips" steps are not ported).

Opens the .blend tools/blender/run.py saved next to build.py, checks the skinning (every vertex weighted, at most 4
influences, weights summing to 1, only RIG_HerringGull groups), then writes into <out>/fbx/M_Ani_HerringGull/:
  M_Ani_HerringGull_Rig.fbx    LOD0 + RIG_HerringGull in the glide rest pose (the Roblox skinned-mesh import)
  M_Ani_HerringGull_Anims.fbx  the same, plus the five clips stashed as NLA strips and baked (glide, flap, land,
                               stand, call) - the animations themselves, not yet verified in Studio
Same FBX settings as rbxkit.export_fbx (-Z forward, Y up, FBX_SCALE_UNITS, scale 1: 1 unit = 1 stud).

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Ani_HerringGull/export_rig.py -- [<out root>]
"""
import importlib
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
ASSET = "M_Ani_HerringGull"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.join(argv[0] if argv else os.path.join(REPO, "build/prod", ASSET), "fbx", ASSET)
sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
import rbxkit  # noqa: E402

CLIPS = ("A_HerringGull_Glide", "A_HerringGull_Flap", "A_HerringGull_Land", "A_HerringGull_Stand",
         "A_HerringGull_Call")


def fbx_counts(path):
    """(mesh model names, Deformer count, AnimationStack names) read back from the file."""
    pf = None
    for base in ("io_scene_fbx", "bl_ext.blender_org.io_scene_fbx"):
        try:
            pf = importlib.import_module(base + ".parse_fbx")
            break
        except ImportError:
            pass
    root, _ = pf.parse(path)
    geo, deform, stacks = [], [], []

    def walk(e):
        name = e.props[1].split(b"\x00")[0].decode() if len(e.props) > 1 and isinstance(e.props[1], bytes) else ""
        if e.id == b"Geometry":
            geo.append(name)
        elif e.id == b"Deformer":
            deform.append(name)
        elif e.id == b"AnimationStack":
            stacks.append(name)
        for c in e.elems:
            walk(c)
    walk(root)
    return geo, deform, stacks


bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, ASSET + ".blend"))
mesh = bpy.data.objects[ASSET + "_LOD0"]
rig = bpy.data.objects["RIG_HerringGull"]
os.makedirs(OUT, exist_ok=True)

bones = [b.name for b in rig.data.bones]
groups = {g.index: g.name for g in mesh.vertex_groups}
infl = np.array([sum(1 for g in v.groups if g.weight > 1e-6) for v in mesh.data.vertices])
wsum = np.array([sum(g.weight for g in v.groups) for v in mesh.data.vertices])
assert set(groups.values()) <= set(bones), "unexpected groups %s" % (set(groups.values()) - set(bones))
assert mesh.parent is rig and any(m.type == 'ARMATURE' and m.object is rig for m in mesh.modifiers)
print("[rig] bones %d: %s" % (len(bones), ", ".join(bones)))
print("[rig] weights: influences max %d mean %.2f; unweighted %d; weight sum min %.3f max %.3f"
      % (infl.max(), infl.mean(), int((infl == 0).sum()), wsum.min(), wsum.max()))
assert infl.max() <= 4 and (infl > 0).all() and abs(wsum.min() - 1.0) < 1e-4 and abs(wsum.max() - 1.0) < 1e-4
tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
print("[rig] LOD0 %d tris, %d verts, %d groups" % (tris, len(mesh.data.vertices), len(groups)))

for pb in rig.pose.bones:
    pb.matrix_basis.identity()
rig.data.pose_position = 'REST'


def export(path, anim):
    rbxkit.make_fbx_deterministic()
    for o in bpy.context.scene.objects:
        o.select_set(o in (mesh, rig))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH', 'ARMATURE'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0,
                             axis_forward='-Z', axis_up='Y', use_mesh_modifiers=True, mesh_smooth_type='FACE',
                             use_triangles=True, use_tspace=True, add_leaf_bones=False, bake_anim=anim,
                             use_armature_deform_only=False, path_mode='STRIP', embed_textures=False)
    geo, deform, stacks = fbx_counts(path)
    print("[rig] %s  %d bytes  meshes %s  deformers %d  anim stacks %s"
          % (os.path.relpath(path, REPO), os.path.getsize(path), geo, len(deform), stacks))
    return deform, stacks


rest = os.path.join(OUT, ASSET + "_Rig.fbx")
deform, stacks = export(rest, False)
assert deform and not stacks, "the rest export must carry the skin and no animation"

for act in bpy.data.actions:
    act.use_fake_user = True
if rig.animation_data is None:
    rig.animation_data_create()
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
for name in CLIPS:
    act = bpy.data.actions.get(name)
    if act is None:
        print("[rig] clip %s missing" % name)
        continue
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, int(act.frame_range[0]), act)
    st.name = name
rig.animation_data.action = None
anims = os.path.join(OUT, ASSET + "_Anims.fbx")
deform, stacks = export(anims, True)
assert len(stacks) >= 1, "the animation export must carry AnimationStack elements"
print("[rig] clips exported: %s" % ", ".join(sorted(stacks)))
