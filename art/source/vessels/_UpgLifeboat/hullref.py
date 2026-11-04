"""Reference only, never exported: rebuilds the code-built lifeboat in Blender from hull_ref.json so the pieces can be fitted and
rendered on the real hull. hull_ref.json = every visible part of Builder.build(VehicleConfig.Lifeboat), dumped under Lune."""
import json
import os

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
# the mast group rides 6.5 higher on the battle bridge at L30, the stays come off (concept buildHull; code must do the same)
MAST = {"MastBase", "Mast", "MastTop", "Yard", "RadarPedestal", "Radar", "NavMasthead", "Antenna-1", "Antenna1", "BeaconBase", "Beacon"}


def _shape(p):
    x, y, z = (v / 2 for v in p["s"])
    if p["k"] == "WedgePart":   # bottom rectangle, tall edge at +Z
        vs = [(-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (-x, y, z), (x, y, z)]
        return vs, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)]
    if p["sh"] == "Cylinder":   # axis X
        import math
        n = 16
        vs = [(s * x, y * math.cos(2 * math.pi * i / n), z * math.sin(2 * math.pi * i / n)) for s in (-1, 1) for i in range(n)]
        return vs, [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    vs = [(sx * x, sy * y, sz * z) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    return vs, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]


def build(level=21, name="HullRef"):
    """One joined mesh, one material per colour, Blender axes (-x, z, y)."""
    parts = json.load(open(os.path.join(HERE, "hull_ref.json")))
    verts, faces, mats, face_mat = [], [], [], []
    keys = {}
    for p in parts:
        if level >= 30 and p["n"].startswith("Stay"):
            continue
        up = 6.5 if level >= 30 and p["n"] in MAST else 0.0
        c = p["cf"]
        m = Matrix(((c[3], c[4], c[5], c[0]), (c[6], c[7], c[8], c[1] + up), (c[9], c[10], c[11], c[2]), (0, 0, 0, 1)))
        vs, fs = _shape(p)
        base = len(verts)
        for v in vs:
            w = m @ Vector(v)
            verts.append((-w.x, w.z, w.y))
        key = (*[round(a, 3) for a in p["col"]], "G" if p["tr"] > 0 else "")
        if key not in keys:
            keys[key] = len(mats)
            mat = bpy.data.materials.new("Ref_%d" % len(mats))
            mat.use_nodes = True
            b = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            b.inputs["Base Color"].default_value = (*[pow(a, 2.2) for a in p["col"]], 1)
            b.inputs["Roughness"].default_value = 0.12 if p["tr"] > 0 else 0.42
            mats.append(mat)
        for f in fs:
            faces.append(tuple(base + i for i in f))
            face_mat.append(keys[key])
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    for mat in mats:
        me.materials.append(mat)
    me.polygons.foreach_set("material_index", face_mat)
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob
