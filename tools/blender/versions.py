"""The `lod` step (docs/12 1.1 and 1.2): every visual _LOD0 mesh gets _LOD1 (and _LOD2 unless its class culls)
by collapse decimation, with the LOD0 UVs and texture sets kept and weighted normals re-applied.

Targets: budgets.lod_target (the class share of the actual LOD0 count, never above the LOD ceiling share).
Ported from Gulp's versions.py `lod` step; vertex-colour snapping, outline shells and the review sheet dropped.
"""
import bpy

import budgets
import names


def triangles(mesh):
    return sum(len(p.vertices) - 2 for p in mesh.polygons)


def copy_object(src, name):
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = name
    obj.data.name = name
    obj.modifiers.clear()
    for coll in src.users_collection:
        coll.objects.link(obj)
    return obj


def _evaluated_mesh(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    return bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)


def decimate(obj, target, symmetry=None):
    """Collapse-decimate `obj` to at most `target` triangles, in place, bisecting the ratio for the most triangles at
    or under the target. UVs and the material slot are carried by the modifier. symmetry: None or 'X' / 'Y' / 'Z'."""
    if triangles(obj.data) <= target:
        return
    if triangles(obj.data) > 12 * target:       # big steps collapse small meshes to nothing: go down in stages
        decimate(obj, 4 * target, symmetry)
    source = obj.data
    ratio = target / float(triangles(source))
    lo, hi, best, best_got = 0.0, 1.0, None, -1
    for _ in range(14):
        mod = obj.modifiers.new("Decimate", 'DECIMATE')
        mod.decimate_type = 'COLLAPSE'
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        if symmetry:
            mod.use_symmetry = True
            mod.symmetry_axis = symmetry
        new = _evaluated_mesh(obj)
        obj.modifiers.remove(mod)
        got = triangles(new)
        if got <= target and got > best_got:
            if best is not None:
                bpy.data.meshes.remove(best)
            best, best_got, lo = new, got, ratio
        else:
            bpy.data.meshes.remove(new)
            if got > target:
                hi = ratio
        if best_got >= 0.95 * target:
            break
        ratio = (lo + hi) / 2.0
    if best is None:
        raise RuntimeError("%s: decimation could not reach %d triangles" % (obj.name, target))
    name = source.name
    obj.data = best
    bpy.data.meshes.remove(source)
    best.name = name


def weighted_normals(obj):
    """Smooth by angle plus a Weighted Normal pass, applied, so hard edges survive decimation."""
    mesh = obj.data
    for p in mesh.polygons:
        p.use_smooth = True
    mod = obj.modifiers.new("WeightedNormal", 'WEIGHTED_NORMAL')
    mod.keep_sharp = True
    mod.weight = 50
    new = _evaluated_mesh(obj)
    obj.modifiers.remove(mod)
    name = mesh.name
    obj.data = new
    bpy.data.meshes.remove(mesh)
    new.name = name
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(new)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(new)
    bm.free()


def run_lod(spec):
    """Adds the LOD meshes to spec['meshes'] (role visual, lod LOD1 / LOD2). Returns [(name, tris, target)]."""
    budget_class = spec["budget"]
    made = []
    for entry in [e for e in spec["meshes"] if e.get("role", "visual") == "visual" and e.get("lod", "LOD0") == "LOD0"]:
        src = entry["object"]
        src_tris = triangles(src.data)
        for lod in budgets.lods_made(budget_class):
            name = names.with_suffix(src.name, lod)
            old = bpy.data.objects.get(name)
            if old is not None:
                bpy.data.objects.remove(old, do_unlink=True)
            obj = copy_object(src, name)
            target = budgets.lod_target(budget_class, lod, src_tris, spec.get("tris"))
            decimate(obj, target, spec.get("lod_symmetry"))
            weighted_normals(obj)
            new = {"object": obj, "role": "visual", "lod": lod, "of": src.name}
            if entry.get("set"):
                new["set"] = entry["set"]
            spec["meshes"].append(new)
            made.append((name, triangles(obj.data), target))
            print("[lod] %s %d triangles (target %d, LOD0 %d)" % (name, triangles(obj.data), target, src_tris))
    return made
