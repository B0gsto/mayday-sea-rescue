"""Spike 1 test meshes (docs/06 section 2.2). One Blender run, about a minute:

    ~/RobloxProjects/tools/blender-run.sh art/spike1/build_spike1.py

Writes assets/fbx/Spike1/*.fbx (one FBX per test so one rejection does not block the others), art/spike1/spike1.blend and
art/spike1/fbx_readback.json. 1 Blender unit = 1 stud. Export settings are rbxkit.export_fbx's exactly (-Z forward, Y up,
FBX_SCALE_UNITS, scale 1, triangulated, no leaf bones, deterministic), called directly because rbxkit asserts <= 20,000 tris
and the limit probes must go above it. Armatures export with the mesh (object_types MESH + ARMATURE, as in rbxkit)."""
import json
import math
import os
import sys

import bpy
import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
import rbxkit  # noqa: E402
import export as bexport  # noqa: E402  (inspect_fbx read-back)

OUT = os.path.join(REPO, "assets", "fbx", "Spike1")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.unit_settings.system = 'NONE'
    s.unit_settings.scale_length = 1.0


def material(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1.0)
    return m


def apply_all(ob):
    rbxkit.select_only(ob)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def export(objs, name, anim=False):
    rbxkit.make_fbx_deterministic()
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT, name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH', 'ARMATURE'},
        apply_unit_scale=True, apply_scale_options='FBX_SCALE_UNITS', global_scale=1.0,
        axis_forward='-Z', axis_up='Y', use_mesh_modifiers=True, mesh_smooth_type='FACE',
        use_triangles=True, use_tspace=True, add_leaf_bones=False, bake_anim=anim,
        path_mode='STRIP', embed_textures=False)
    info = bexport.inspect_fbx(path)
    info["blender_tris"] = {o.name: rbxkit.tris(o) for o in objs if o.type == 'MESH'}
    return info


def box(name, dims, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, dims[2] / 2))
    ob = bpy.context.active_object
    ob.name = ob.data.name = name
    ob.scale = dims
    apply_all(ob)
    ob.data.materials.append(mat)
    return ob


def tri_grid(name, T, size=12.0, cols=100):
    """Exactly T triangles: rows of a cols-wide quad grid, triangulated, truncated to T, displaced (bumpy) so it is not a
    trivially collapsible plane; UVs = planar xy mapped to 0..1."""
    rows = math.ceil(T / (2 * cols))
    verts, faces = [], []
    for j in range(rows + 1):
        for i in range(cols + 1):
            u, v = i / cols, j / rows
            z = 0.4 * math.sin(u * 17.0) * math.cos(v * 13.0) + 0.15 * math.sin((u + v) * 41.0)
            verts.append(((u - 0.5) * size, (v - 0.5) * size, z))
    vid = lambda i, j: j * (cols + 1) + i
    for j in range(rows):
        for i in range(cols):
            a, b, c, d = vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)
            faces += [(a, b, c), (a, c, d)]
    faces = faces[:T]
    used = sorted({k for f in faces for k in f})
    remap = {k: n for n, k in enumerate(used)}
    me = bpy.data.meshes.new(name)
    me.from_pydata([verts[k] for k in used], [], [tuple(remap[k] for k in f) for f in faces])
    uv = me.uv_layers.new(name="UVMap")
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.x / size + 0.5, co.y / size + 0.5)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material("M_" + name, (0.6, 0.6, 0.6)))
    assert rbxkit.tris(ob) == T, (name, rbxkit.tris(ob))
    return ob


def tentacle(name, nbones, length=20.0, r0=1.0, r1=0.3, seg=16, rings_per_bone=4):
    """Open tapered tube along +Z with a connected chain of nbones bones; at most 4 normalized weights per vertex."""
    rings = nbones * rings_per_bone + 1
    verts, faces, uvs = [], [], []
    for j in range(rings):
        t = j / (rings - 1)
        r = r0 + (r1 - r0) * t
        for i in range(seg):
            a = 2 * math.pi * i / seg
            verts.append((r * math.cos(a), r * math.sin(a), t * length))
    for j in range(rings - 1):
        for i in range(seg):
            a, b = j * seg + i, j * seg + (i + 1) % seg
            faces.append((a, b, b + seg, a + seg))
            uvs.append([(i / seg, j / (rings - 1)), ((i + 1) / seg, j / (rings - 1)),
                        ((i + 1) / seg, (j + 1) / (rings - 1)), (i / seg, (j + 1) / (rings - 1))])
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    uv = me.uv_layers.new(name="UVMap")
    for p, quv in zip(me.polygons, uvs):
        for k, li in enumerate(p.loop_indices):
            uv.data[li].uv = quv[k]
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(material("M_" + name, (0.7, 0.35, 0.3)))

    arm_data = bpy.data.armatures.new("RIG_" + name)
    arm = bpy.data.objects.new("RIG_" + name, arm_data)
    bpy.context.scene.collection.objects.link(arm)
    rbxkit.select_only(arm)
    bpy.ops.object.mode_set(mode='EDIT')
    step = length / nbones
    prev = None
    bone_names = []
    for b in range(nbones):
        eb = arm_data.edit_bones.new(f"Bone_{b:02d}")
        eb.head, eb.tail = (0, 0, b * step), (0, 0, (b + 1) * step)
        if prev:
            eb.parent, eb.use_connect = prev, True
        prev = eb
        bone_names.append(eb.name)
    bpy.ops.object.mode_set(mode='OBJECT')

    groups = [ob.vertex_groups.new(name=n) for n in bone_names]
    sigma = step * 0.6
    maxinf = 0
    for v in me.vertices:
        z = v.co.z
        w = [(math.exp(-((z - (b + 0.5) * step) ** 2) / (2 * sigma ** 2)), b) for b in range(nbones)]
        w = sorted(w, reverse=True)[:4]
        w = [x for x in w if x[0] > 1e-3]
        s = sum(x[0] for x in w)
        for wt, b in w:
            groups[b].add([v.index], wt / s, 'REPLACE')
        maxinf = max(maxinf, len(w))
    ob.parent = arm
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    return ob, arm, maxinf


def main():
    os.makedirs(OUT, exist_ok=True)
    reset()
    report = {}
    grey = material("M_Spike1_Grey", (0.5, 0.5, 0.5))
    cube = box("M_Spike1_ScaleCube", (3.0, 3.0, 3.0), grey)              # exactly 1 m = 3 studs
    report["M_Spike1_ScaleCube"] = export([cube], "M_Spike1_ScaleCube")
    ref = box("M_Spike1_RefBox", (1.0, 1.0, 5.5), grey)                  # 5.5-stud tall reference
    report["M_Spike1_RefBox"] = export([ref], "M_Spike1_RefBox")
    bpy.ops.mesh.primitive_plane_add(size=12.0)                           # 12 x 12 studs texture display plane
    plane = bpy.context.active_object
    plane.name = plane.data.name = "M_Spike1_TexPlane"
    plane.data.materials.append(grey)
    report["M_Spike1_TexPlane"] = export([plane], "M_Spike1_TexPlane")
    for T in (9990, 19990, 20500, 21500, 30000):
        n = f"M_Spike1_Tris{T:05d}"
        report[n] = export([tri_grid(n, T)], n)
    for nb in (20, 40):
        n = f"M_Spike1_Tentacle{nb}"
        ob, arm, maxinf = tentacle(n, nb)
        report[n] = export([ob, arm], n)
        report[n].update(bones=len(arm.data.bones), max_influences=maxinf)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "spike1.blend"))
    with open(os.path.join(HERE, "fbx_readback.json"), "w") as f:
        json.dump(report, f, indent=1, default=str)
    for k, v in report.items():
        print("SPIKE1", k, v.get("blender_tris"), v.get("bytes"), v.get("unit_scale_factor"), v.get("axes"),
              [(g.get("min"), g.get("max"), g.get("polygons")) for g in v["geometry"]], v.get("bones", ""), v.get("max_influences", ""))


main()
