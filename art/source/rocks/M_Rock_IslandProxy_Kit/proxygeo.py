"""Heightmap -> island proxy geometry, terrain-material colour image, UV atlas and bake material."""
import json
import math
import os

import bpy
import bmesh
import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
MAP = os.path.join(REPO, "map/generated")
MATERIALS = os.path.join(REPO, "assets/textures/Materials")
SINK = 1.0
SKIRT_Y = -14.0

VARIANTS = {
    "Sand": "SandDry", "Sandstone": "SandWet", "Salt": "SeabedSand", "Limestone": "ShellGravel",
    "CrackedLava": "Shingle", "Rock": "Granite", "Slate": "KelpRock", "Basalt": "SplashRock",
    "Grass": "Turf", "LeafyGrass": "Moor", "Snow": "TurfStraw", "WoodPlanks": "TurfOlive",
    "Brick": "TurfWorn", "Glacier": "SandRipple", "Ice": "Wrack", "Mud": "Mud", "Ground": "Earth",
    "Pavement": "Gravel", "Asphalt": "Asphalt", "Cobblestone": "Cobbles", "Concrete": "Concrete",
}
FALLBACK = {
    "SandDry": (205, 187, 152), "SandWet": (140, 123, 98), "SeabedSand": (170, 160, 130),
    "ShellGravel": (190, 185, 170), "Shingle": (105, 98, 90), "Granite": (138, 135, 129),
    "KelpRock": (75, 74, 38), "SplashRock": (78, 76, 73), "Turf": (178, 169, 162), "Moor": (110, 90, 100),
    "TurfStraw": (150, 135, 90), "TurfOlive": (84, 87, 60), "TurfWorn": (94, 89, 64),
    "SandRipple": (200, 182, 146), "Wrack": (81, 72, 54), "Mud": (90, 75, 60), "Earth": (120, 100, 75),
    "Gravel": (115, 89, 70), "Asphalt": (40, 40, 42), "Cobbles": (110, 105, 100), "Concrete": (180, 180, 175),
}
GRASS_TINT = np.array((148, 154, 112), np.float32) / 255.0


def load_terrain():
    meta = json.load(open(os.path.join(MAP, "terrain.json")))
    h = np.fromfile(os.path.join(MAP, meta["height"]), dtype="<i2").reshape(meta["nz"], meta["nx"])
    h = h.astype(np.float32) / meta["heightScale"]
    mat = np.fromfile(os.path.join(MAP, meta["material"]), dtype=np.uint8).reshape(meta["nz"], meta["nx"])
    return meta, h, mat


def labels(land):
    nz, nx = land.shape
    parent = {}

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        a, b = find(a), find(b)
        if a != b:
            parent[b] = a

    runs, prev, nxt = [], [], 0
    for j in range(nz):
        idx = np.flatnonzero(land[j])
        row = []
        if len(idx):
            sp = np.flatnonzero(np.diff(idx) > 1)
            for s, e in zip(np.r_[0, sp + 1], np.r_[sp, len(idx) - 1]):
                a, b = int(idx[s]), int(idx[e])
                lab = None
                for pa, pb, pl in prev:
                    if pa <= b and pb >= a:
                        if lab is None:
                            lab = pl
                        else:
                            union(lab, pl)
                if lab is None:
                    lab = nxt
                    parent[nxt] = nxt
                    nxt += 1
                row.append((a, b, lab))
        runs.append(row)
        prev = row
    out = np.full((nz, nx), -1, np.int32)
    for j, row in enumerate(runs):
        for a, b, lab in row:
            out[j, a:b + 1] = find(lab)
    return out


def components(meta, h):
    land = h > 0.5
    lab = labels(land)
    found = []
    for v in np.unique(lab):
        if v < 0:
            continue
        m = lab == v
        area = int(m.sum())
        if area < 500:
            continue
        zz, xx = np.nonzero(m)
        found.append({"label": int(v), "mask": m, "area": area,
                      "i0": int(xx.min()), "i1": int(xx.max()), "j0": int(zz.min()), "j1": int(zz.max())})
    found.sort(key=lambda c: -c["area"])
    return found


def _corner(meta, h, ci, cj):
    ci = min(ci, meta["nx"] - 1)
    cj = min(cj, meta["nz"] - 1)
    wx = meta["originX"] + meta["cell"] * ci
    wz = meta["originZ"] + meta["cell"] * cj
    return (-wx, wz, float(h[cj, ci]) - SINK)


def top_mesh(meta, h, comp, stride):
    i0, i1 = comp["i0"], comp["i1"]
    j0, j1 = comp["j0"], comp["j1"]
    ni = int(math.ceil((i1 - i0) / stride)) + 1
    nj = int(math.ceil((j1 - j0) / stride)) + 1
    index = {}

    def vert(I, J):
        k = (I, J)
        if k not in index:
            index[k] = len(verts)
            verts.append(_corner(meta, h, i0 + I * stride, j0 + J * stride))
        return index[k]

    verts, faces = [], []
    for J in range(nj - 1):
        cj = j0 + (J * stride + stride // 2)
        for I in range(ni - 1):
            ci = i0 + (I * stride + stride // 2)
            if not comp["mask"][cj, ci]:
                continue
            a, b = vert(I, J), vert(I + 1, J)
            c, d = vert(I + 1, J + 1), vert(I, J + 1)
            faces.append((a, d, c, b))
    me = bpy.data.meshes.new(comp["name"] + "_LOD0")
    me.from_pydata(verts, [], faces)
    me.update()
    obj = bpy.data.objects.new(comp["name"] + "_LOD0", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def skirt(obj, depth=SKIRT_Y):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bottoms = {}
    new_faces = []
    for ed in [e for e in bm.edges if len(e.link_faces) == 1]:
        loop = ed.link_loops[0]
        v0, v1 = loop.vert, loop.link_loop_next.vert
        if (v1.co - v0.co).length < 1e-6:
            v0, v1 = v1, v0
        for v in (v0, v1):
            if v not in bottoms:
                z = min(depth, v.co.z - 2.0)
                bottoms[v] = bm.verts.new((v.co.x, v.co.y, z))
        new_faces.append(bm.faces.new((v0, bottoms[v0], bottoms[v1], v1)))
    for f in new_faces:
        f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=new_faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def unwrap(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.002)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.002, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def fit_rect(obj, rect):
    uv = obj.data.uv_layers.active.data
    arr = np.empty(len(uv) * 2, np.float32)
    uv.foreach_get("uv", arr)
    arr = arr.reshape(-1, 2)
    lo, hi = arr.min(0), arr.max(0)
    rw, rh = rect[2] - rect[0], rect[3] - rect[1]
    s = min(rw / max(hi[0] - lo[0], 1e-6), rh / max(hi[1] - lo[1], 1e-6))
    cx, cy = (lo[0] + hi[0]) / 2.0, (lo[1] + hi[1]) / 2.0
    out = np.empty_like(arr)
    out[:, 0] = (rect[0] + rect[2]) / 2.0 + (arr[:, 0] - cx) * s
    out[:, 1] = (rect[1] + rect[3]) / 2.0 + (arr[:, 1] - cy) * s
    uv.foreach_set("uv", out.ravel())


def variant_medians():
    out = {}
    for name, variant in VARIANTS.items():
        path = os.path.join(MATERIALS, "T_Mat_%s_ALB.png" % variant)
        col = np.array(FALLBACK.get(variant, (120, 118, 112)), np.float32)
        if os.path.isfile(path):
            img = bpy.data.images.load(path, check_existing=False)
            img.colorspace_settings.name = "Non-Color"
            w, hgt = img.size
            buf = np.empty(w * hgt * 4, np.float32)
            img.pixels.foreach_get(buf)
            px = buf.reshape(-1, 4)[::11, :3]
            col = np.median(px, axis=0) * 255.0
            bpy.data.images.remove(img)
        if name == "Grass":
            col = col * GRASS_TINT
        out[name] = col
    return out


def terrain_colour_image(meta, mat, medians, path):
    cols = np.zeros((len(meta["materials"]), 3), np.float32)
    for i, name in enumerate(meta["materials"]):
        cols[i] = medians.get(name, (120, 118, 112))
    cols[meta["materials"].index("Air")] = medians.get("Basalt", (78, 76, 73)) * 0.82
    rgb = cols[mat]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    import pbrmaps
    pbrmaps.write_png(path, np.clip(rgb[::-1] / 255.0, 0.0, 1.0))
    return path


def bake_material(name, image, meta):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (0.35, 0.34, 0.32, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])

    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    span = meta["cell"] * (meta["nx"] - 1)
    u = nt.nodes.new("ShaderNodeMath")
    u.operation = "MULTIPLY_ADD"
    u.inputs[1].default_value = -1.0 / span
    u.inputs[2].default_value = -meta["originX"] / span
    nt.links.new(sep.outputs["X"], u.inputs[0])
    v = nt.nodes.new("ShaderNodeMath")
    v.operation = "MULTIPLY_ADD"
    v.inputs[1].default_value = 1.0 / span
    v.inputs[2].default_value = -meta["originZ"] / span
    nt.links.new(sep.outputs["Y"], v.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(u.outputs[0], comb.inputs["X"])
    nt.links.new(v.outputs[0], comb.inputs["Y"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.name = "BAKE_BASE"
    tex.image = image
    tex.interpolation = "Linear"
    tex.extension = "EXTEND"
    nt.links.new(comb.outputs[0], tex.inputs["Vector"])
    mat["bake_custom"] = True
    return mat


def bounds(obj):
    co = np.empty(len(obj.data.vertices) * 3, np.float32)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return co.min(0), co.max(0)


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
