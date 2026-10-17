"""M_Chr_Casualty_Swimmer skinned export (rig pass): LOD0 mesh + R15 skeleton -> assets/fbx/M_Chr_Casualty_Swimmer/
M_Chr_Casualty_Swimmer_Rig.fbx. The GEOMETRY IS NOT TOUCHED (docs/06 2.1a): the .blend is opened read-only (never saved),
the LOD0 vertex/index/UV hash is checked against build/ch1/fix/fp_new.json, and the exported FBX Vertices /
PolygonVertexIndex / UV arrays are compared with the uploaded M_Chr_Casualty_Swimmer_LOD0.fbx.
Skeleton: Roblox R15 skinned-mesh hierarchy (create.roblox.com/docs/art/characters/specifications): Root (origin, no
influences) > HumanoidRootNode > LowerTorso > ... the 15 R15 part bones that already carry the weights from the base rig.
Same FBX settings as rbxkit.export_fbx (-Z forward, Y up, FBX_SCALE_UNITS, scale 1, deterministic), rest pose.
    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Chr_Casualty_Swimmer/export_rig.py
"""
import hashlib
import json
import os
import sys
import bpy
import numpy as np
sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
import rbxkit  # noqa: E402

ASSET = "M_Chr_Casualty_Swimmer"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(REPO, "assets", "fbx", ASSET, ASSET + "_Rig.fbx")
UPLOADED = os.path.join(REPO, "assets", "fbx", ASSET, ASSET + "_LOD0.fbx")
FP = os.path.join(REPO, "build", "ch1", "fix", "fp_new.json")
R15 = ["LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm",
       "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]


def fingerprint(o):
    me = o.data
    P = np.zeros(len(me.vertices) * 3, np.float32); me.vertices.foreach_get("co", P)
    F = np.zeros(len(me.loops), np.int32); me.loops.foreach_get("vertex_index", F)
    U = np.zeros(len(me.loops) * 2, np.float32); me.uv_layers.active.data.foreach_get("uv", U)
    return {"v": len(me.vertices), "f": len(me.polygons), "pos": hashlib.sha1(np.round(P, 5).tobytes()).hexdigest(),
            "idx": hashlib.sha1(F.tobytes()).hexdigest(), "uv": hashlib.sha1(np.round(U, 5).tobytes()).hexdigest()}


def fbx_geometry(path):
    import importlib
    pf = None
    for base in ("io_scene_fbx", "bl_ext.blender_org.io_scene_fbx"):
        try:
            pf = importlib.import_module(base + ".parse_fbx"); break
        except ImportError:
            pass
    root, _ = pf.parse(path)
    out = {}

    def walk(e):
        for c in e.elems:
            if c.id == b"Geometry" and len(c.props) > 1 and b"Mesh" in (c.props[-1] or b""):
                d = {}
                for g in c.elems:
                    if g.id in (b"Vertices", b"PolygonVertexIndex"):
                        d[g.id.decode()] = hashlib.sha1(np.asarray(g.props[0]).tobytes()).hexdigest()
                    if g.id == b"LayerElementUV":
                        for u in g.elems:
                            if u.id in (b"UV", b"UVIndex"):
                                d["UV_" + u.id.decode()] = hashlib.sha1(np.asarray(u.props[0]).tobytes()).hexdigest()
                out[c.props[1].split(b"\x00")[0].decode()] = d
            walk(c)
    walk(root)
    return out


bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, ASSET + ".blend"))
mesh = bpy.data.objects[ASSET + "_LOD0"]
rig = bpy.data.objects["RIG_Human"]
fp = fingerprint(mesh)
want = json.load(open(FP))[ASSET + "_LOD0"]
assert fp == want, f"LOD0 geometry differs from the uploaded build: {fp} vs {want}"
print("[rig] LOD0 fingerprint matches fp_new.json:", fp)

# weights: every vertex weighted, <= 4 influences, only R15 groups
names = {g.index: g.name for g in mesh.vertex_groups}
infl = np.array([sum(1 for g in v.groups if g.weight > 1e-6) for v in mesh.data.vertices])
wsum = np.array([sum(g.weight for g in v.groups) for v in mesh.data.vertices])
assert set(names.values()) <= set(R15), f"unexpected groups {set(names.values()) - set(R15)}"
print("[rig] groups %d; influences max %d mean %.2f; unweighted %d; weight sum min %.3f max %.3f"
      % (len(names), infl.max(), infl.mean(), int((infl == 0).sum()), wsum.min(), wsum.max()))
assert infl.max() <= 4 and (infl > 0).all()

# skeleton: add the R15 'Root' bone at the origin above HumanoidRootNode (bones only; mesh data untouched)
rbxkit.select_only(rig) if hasattr(rbxkit, "select_only") else None
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = rig.data.edit_bones
if "Root" not in eb:
    r = eb.new("Root"); r.head = (0, 0, 0); r.tail = (0, 0, eb["HumanoidRootNode"].length); r.roll = 0.0
    eb["HumanoidRootNode"].parent = r
bpy.ops.object.mode_set(mode='OBJECT')
for pb in rig.pose.bones:
    pb.matrix_basis.identity()
rig.data.pose_position = 'REST'
mw = rig.matrix_world
print("[rig] RIG_Human matrix_world identity:", all(abs(mw[i][j] - (i == j)) < 1e-6 for i in range(4) for j in range(4)))
for b in rig.data.bones:
    print("[rig] bone %-17s parent %-17s head %s" % (b.name, b.parent.name if b.parent else "-",
                                                    tuple(round(x, 3) for x in (rig.matrix_world @ b.head_local))))
assert fingerprint(mesh) == want

rbxkit.make_fbx_deterministic()
for o in bpy.context.view_layer.objects:
    o.select_set(o is mesh or o is rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, object_types={'MESH', 'ARMATURE'},
    apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0,
    axis_forward='-Z', axis_up='Y', use_mesh_modifiers=True, mesh_smooth_type='FACE',
    use_triangles=True, use_tspace=True, add_leaf_bones=False, bake_anim=False,
    use_armature_deform_only=False, path_mode='STRIP', embed_textures=False)
new, old = fbx_geometry(OUT), fbx_geometry(UPLOADED)
print("[rig] exported", os.path.relpath(OUT, REPO), os.path.getsize(OUT), "bytes")
print("[rig] FBX geometry new:", json.dumps(new))
print("[rig] FBX geometry uploaded LOD0:", json.dumps(old))
assert len(new) == len(old) == 1 and list(new.values()) == list(old.values()), "exported FBX geometry arrays differ from the uploaded LOD0.fbx"
print("[rig] GEOMETRY IDENTICAL to uploaded LOD0.fbx (Vertices, PolygonVertexIndex, UV, UVIndex)")
