"""K1 build(): the decimated scan LP from build/k1/work/<Asset>_lp.blend (bake_all.py), one Granite set, a convex-hull
_COL (at most 300 tris) and, on shore pieces, ATT_Waterline at the height the barnacle band was painted for (compose.py)."""
import json, os, sys
import bpy, bmesh
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kit import piece, WORK, SET, size, TEXEL_WAIVED  # noqa: E402


def build_piece(asset):
    p = piece(asset)
    info = json.load(open(WORK + asset + ".json"))
    with bpy.data.libraries.load(WORK + asset + "_lp.blend") as (src, dst):
        dst.meshes = [info["lp_mesh"]]
    me = dst.meshes[0]; me.name = asset + "_LOD0"
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    import mathutils
    vs = [v.co for v in me.vertices]
    lo = [min(v[i] for v in vs) for i in range(3)]; hi = [max(v[i] for v in vs) for i in range(3)]
    me.transform(mathutils.Matrix.Translation((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2])))
    lod0 = bpy.data.objects.new(asset + "_LOD0", me)
    bpy.context.scene.collection.objects.link(lod0)
    mat = bpy.data.materials.new("MI_%s_%s" % (p["tex"], SET)); mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.25, 0.24, 0.23, 1); bsdf.inputs["Roughness"].default_value = 0.8
    me.materials.clear(); me.materials.append(mat)
    # _COL: convex hull of 150 spread vertices (at most 296 tris, closed by construction)
    import random
    rnd = random.Random(7)
    co = [v.co.copy() for v in me.vertices]
    ext = set()
    for i in range(3):
        ext.add(min(range(len(co)), key=lambda k: co[k][i])); ext.add(max(range(len(co)), key=lambda k: co[k][i]))
    pick = list(ext) + rnd.sample(range(len(co)), min(150 - len(ext), len(co)))
    bm = bmesh.new()
    for k in pick:
        bm.verts.new(co[k])
    hull = bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.delete(bm, geom=list({g for g in hull["geom_interior"] + hull["geom_unused"] if isinstance(g, bmesh.types.BMVert)}), context="VERTS")
    bmesh.ops.triangulate(bm, faces=bm.faces)
    cme = bpy.data.meshes.new(asset + "_COL"); bm.to_mesh(cme); bm.free()
    col = bpy.data.objects.new(asset + "_COL", cme); bpy.context.scene.collection.objects.link(col)
    s = info["size_m"]
    spec = {"name": asset, "budget": p["budget"], "tris": p["tris"], "tier": p["tier"],
            "dims_m": tuple(round(x, 3) for x in s),
            "origin": "base",
            "sets": [{"name": p["tex"], "set": SET, "size": size(asset), "wet": True}],
            "meshes": [{"object": lod0, "set": SET}, {"object": col}],
            "attachments": [],
            "waivers": {"geometry": "photogrammetry scan surface: the open underside and scan edges sit inside the terrain (CC0 scan, kit rock)",
                         "LOD UV layout": "LOD2 of a decimated scan keeps the same UVs; area drift from collapsed micro-faces only"},
            "tiling": False, "lod_symmetry": None,
            "closeups": [{"name": "top", "target": [0, 0, s[2] * 3 * 0.9], "dist": max(s) * 3 * 0.45, "az": 30, "el": 35},
                         {"name": "flank", "target": [0, 0, s[2] * 3 * 0.45], "dist": max(s) * 3 * 0.5, "az": 200, "el": 10}]}
    if asset in TEXEL_WAIVED:
        spec["waivers"]["texel density"] = ("40-92 m headland wall: 2048 is the scan's 2k master; 25 px/stud needs a 4k upscale, "
                                            "and the face reads at background distance")
    if p["zone"] == "shore":
        wl = min(max(0.4 * s[2], 0.3), 1.5)
        att = bpy.data.objects.new("ATT_Waterline", None); att.location = (0, 0, wl * 3)
        bpy.context.scene.collection.objects.link(att); spec["attachments"] = [att]
        spec["closeups"][1] = {"name": "waterline", "target": [0, -s[1] * 1.2, wl * 3], "dist": max(s[2] * 3 * 1.6, 5), "az": 0, "el": 12}
    return spec
