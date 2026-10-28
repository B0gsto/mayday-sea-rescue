"""Z-fight check: coplanar, same-facing, overlapping faces inside a Blender-made mesh (the in-game Part scan can't see
them). Every asset must pass this before upload (art/bench/PROD_BRIEF.md).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/zfight_check.py -- [--out report.json] <file.blend|fbx> ...
    python3 tools/blender/zfight_check.py --selftest        # the pure geometry, no Blender
    ... zfight_check.py -- --fix-fbx <in.fbx> <out.fbx>      # fix a shipped FBX whose build.py no longer rebuilds

A pair is reported when two triangles lie in planes within TOL (0.002 BU = studs) of each other, their normals point
the same way (dot > 0.9995; opposite-facing pairs are back-face culled in Roblox) and they overlap by more than
MIN_AREA, and they differ in object, material or flat-palette cell (the Lego assets give each face one cell of a
4 x 4 atlas, so the cell is its colour). Same object + material + cell overlaps render identical pixels: not listed.
  severity "colour": different material / palette cell (visible flicker); "object": same colour, different objects
  (flickers only if the MeshParts differ in Color / Material / Transparency in game, e.g. OwnerColour tints).
_COL hulls, _HP bake sources and ATT_ empties are skipped; LOD0/1/2 never show together, so pairs stay inside one LOD. Level names
(`Lv<k>_...` / `..._Lv<k>_L<nn>_...`) are cumulative in game (DockPieces: level n shows Lv1..n), so every level pair
counts; each pair lists `levels` and is visible from the higher one. Exit code 1 if any file has a pair.
"""
import json
import math
import os
import re
import sys

TOL = 0.002            # plane distance, BU
DOT = 0.9995           # normals parallel and same-facing
MIN_AREA = 0.01        # stud^2 of overlap (0.1 x 0.1); edge contact is ~0
GRID = 4               # flat-palette atlas cells per side (lego.py palettes)
OFFSET = 0.006         # fix(): the smaller face of a visible pair moves out this far per layer
EXCLUSIVE = [({"Damage", "GrabLines"}, {"Undamaged"})]    # name tokens never shown together (FerryRig.STATE_PARTS)


# ------------------------------------------------------------------ pure geometry (selftest-able)
def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
    ln = math.sqrt(_dot(a, a))
    return (a[0] / ln, a[1] / ln, a[2] / ln) if ln > 1e-12 else None


def basis(n):
    """Two unit axes spanning the plane with normal n."""
    t = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
    u = _norm(_cross(n, t))
    return u, _cross(n, u)


def clip(p, q):
    """Intersection of two convex CCW 2D polygons (Sutherland-Hodgman): (area, polygon)."""
    out = list(p)
    for i in range(len(q)):
        a, b = q[i], q[(i + 1) % len(q)]
        inp, out = out, []
        if not inp:
            return 0.0, []
        side = lambda c: (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        for j in range(len(inp)):
            c, d = inp[j], inp[(j + 1) % len(inp)]
            sc, sd = side(c), side(d)
            if sc >= 0:
                out.append(c)
            if (sc >= 0) != (sd >= 0):
                t = sc / (sc - sd)
                out.append((c[0] + t * (d[0] - c[0]), c[1] + t * (d[1] - c[1])))
    area = abs(sum(out[i][0] * out[(i + 1) % len(out)][1] - out[(i + 1) % len(out)][0] * out[i][1]
                   for i in range(len(out)))) / 2 if len(out) > 2 else 0.0
    return area, out


def find_pairs(tris):
    """tris: dicts with v (3 world xyz), obj, mat, cell, lod. Returns overlapping coplanar pairs
    (i < j, area, sample points: the overlap's centroid and four points halfway to its corners, world xyz)."""
    buckets = {}
    for i, t in enumerate(tris):
        n = _norm(_cross(_sub(t["v"][1], t["v"][0]), _sub(t["v"][2], t["v"][0])))
        if n is None:
            continue
        t["n"], t["d"] = n, _dot(n, t["v"][0])
        key = (t["lod"], round(n[0] * 20), round(n[1] * 20), round(n[2] * 20), math.floor(t["d"] / 0.05))
        buckets.setdefault(key, []).append(i)
    pairs, seen = [], set()
    for key, idx in buckets.items():
        cand = []
        for dx in (-1, 0, 1):          # neighbour buckets catch values on a rounding edge
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for dd in (-1, 0, 1):
                        k2 = (key[0], key[1] + dx, key[2] + dy, key[3] + dz, key[4] + dd)
                        if k2 >= key:
                            cand.append(k2)
        n = tris[idx[0]]["n"]
        u, w = basis(n)
        for k2 in cand:
            other = buckets.get(k2)
            if not other:
                continue
            group = sorted(set(idx) | set(other))
            pts = {}
            for i in group:
                p = [(_dot(v, u), _dot(v, w)) for v in tris[i]["v"]]
                if (p[1][0] - p[0][0]) * (p[2][1] - p[0][1]) - (p[1][1] - p[0][1]) * (p[2][0] - p[0][0]) < 0:
                    p.reverse()
                pts[i] = (p, min(x for x, _ in p), max(x for x, _ in p), min(y for _, y in p), max(y for _, y in p))
            group.sort(key=lambda i: pts[i][1])
            active = []
            for i in group:                # sweep along u
                pi = pts[i]
                active = [j for j in active if pts[j][2] > pi[1]]
                for j in active:
                    a, b = (j, i) if j < i else (i, j)
                    if (a, b) in seen:
                        continue
                    ta, tb = tris[a], tris[b]
                    if ta["obj"] == tb["obj"] and ta["mat"] == tb["mat"] and ta["cell"] == tb["cell"]:
                        continue
                    if ta["obj"] != tb["obj"] and exclusive(ta["obj"], tb["obj"]):
                        continue
                    pj = pts[j]
                    if pj[3] >= pi[4] or pi[3] >= pj[4]:
                        continue
                    if _dot(ta["n"], tb["n"]) < DOT or abs(ta["d"] - tb["d"]) > TOL:
                        continue
                    seen.add((a, b))
                    area, poly = clip(pts[a][0], pts[b][0])
                    if area > MIN_AREA:
                        cx, cy = sum(x for x, _ in poly) / len(poly), sum(y for _, y in poly) / len(poly)
                        uv2 = [(cx, cy)] + [((cx + x) / 2, (cy + y) / 2) for x, y in poly[:4]]
                        dd = ta["d"]
                        pairs.append((a, b, area, [tuple(u[k] * x + w[k] * y + n[k] * dd for k in range(3))
                                                   for x, y in uv2]))
                active.append(i)
    return pairs


def exclusive(a, b):
    ta, tb = set(re.split(r"[_.]", a)), set(re.split(r"[_.]", b))
    return any((ta & x and tb & y) or (ta & y and tb & x) for x, y in EXCLUSIVE)


def level(name):
    m = re.match(r"^Lv(\d)_", name) or re.search(r"_Lv(\d)_", name)
    return int(m.group(1)) if m else 0


def lod(name):
    m = re.search(r"_LOD(\d)", name)
    return int(m.group(1)) if m else 0


def _selftest():
    sq = [(0, 0), (2, 0), (2, 2), (0, 2)]
    assert abs(clip(sq, [(1, 1), (3, 1), (3, 3), (1, 3)])[0] - 1.0) < 1e-9
    assert clip(sq, [(2, 0), (4, 0), (4, 2), (2, 2)])[0] < 1e-9            # edge contact only
    tri = lambda o, z, c, dz=0.0: {"v": [(0, 0, z), (2, 0, z + dz), (0, 2, z)], "obj": o, "mat": "M", "cell": c, "lod": 0}
    (_, _, _, sp), = find_pairs([tri("A", 1.0, 0), tri("B", 1.0, 1)])
    assert all(abs(p[2] - 1.0) < 1e-9 and 0 <= p[0] <= 2 and 0 <= p[1] <= 2 for p in sp)   # samples on the faces
    assert len(find_pairs([tri("A", 1.0, 0), tri("B", 1.001, 0)])) == 1    # within TOL, other object
    assert len(find_pairs([tri("A", 1.0, 0), tri("B", 1.01, 0)])) == 0     # offset 0.01 clears it
    assert len(find_pairs([tri("A", 1.0, 0), tri("A", 1.0, 0)])) == 0      # identical pixels
    assert len(find_pairs([tri("A", 1.0, 0), tri("A", 1.0, 5)])) == 1      # other palette cell
    assert len(find_pairs([tri("X_Damage_LOD0", 1.0, 0), tri("X_Undamaged_LOD0", 1.0, 1)])) == 0   # never together
    flip = {"v": [(0, 0, 1.0), (0, 2, 1.0), (2, 0, 1.0)], "obj": "B", "mat": "M", "cell": 0, "lod": 0}
    assert len(find_pairs([tri("A", 1.0, 0), flip])) == 0                  # opposite-facing: culled
    print("zfight_check selftest OK")


# ------------------------------------------------------------------ Blender side
def load(path):
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.wm.open_mainfile(filepath=path)
    return bpy


def collect(bpy, objects=None):
    tris = []
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in objects or bpy.context.scene.objects:
        if ob.type != "MESH" or "_COL" in ob.name or "_HP" in ob.name:      # hulls and bake sources never render
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        mw = ob.matrix_world
        vs = [tuple(mw @ v.co) for v in me.vertices]
        uv = me.uv_layers.active.data if me.uv_layers.active else None
        mats = [s.material.name if s.material else "" for s in ob.material_slots]
        for lt in me.loop_triangles:
            cell = None
            if uv:
                cu = sum(uv[li].uv[0] for li in lt.loops) / 3
                cv = sum(uv[li].uv[1] for li in lt.loops) / 3
                cell = (math.floor(cu * GRID), math.floor(cv * GRID))
            tris.append({"v": [vs[i] for i in lt.vertices], "obj": ob.name, "lod": lod(ob.name), "cell": cell,
                         "ob": ob, "poly": lt.polygon_index, "parea": me.polygons[lt.polygon_index].area,
                         "mat": mats[lt.material_index] if lt.material_index < len(mats) else ""})
        ev.to_mesh_clear()
    return tris


RAYS = [(math.cos(2.39996 * i) * math.sqrt(1 - z * z), math.sin(2.39996 * i) * math.sqrt(1 - z * z), z)
        for i, z in ((i, 1 - (i + 0.5) / 48) for i in range(96))]     # Fibonacci sphere, 96 directions


def escapes(bvh, pts, n):
    """Most rays (of the hemisphere over n, from any sample point 0.01 off the face) that leave the model without a hit.
    Rays heading down steeper than 0.2 count as hitting the ground / sea the asset stands in."""
    from mathutils import Vector
    best = 0
    for p in pts:
        o = Vector(p) + Vector(n) * 0.01
        k = sum(1 for d in RAYS if _dot(d, n) > 0.05 and d[2] > -0.2 and bvh.ray_cast(o, Vector(d))[0] is None)
        best = max(best, k)
    return best


def analyse(tris):
    """Rows (one per overlapping pair, visible first) for collected tris; row["_ab"] keeps the tri indices."""
    from mathutils.bvhtree import BVHTree
    bvh = {}
    for l in {t["lod"] for t in tris}:
        lt = [t for t in tris if t["lod"] == l]
        bvh[l] = BVHTree.FromPolygons([v for t in lt for v in t["v"]], [(3 * i, 3 * i + 1, 3 * i + 2)
                                                                        for i in range(len(lt))])
    base = {l: min(v[2] for t in tris if t["lod"] == l for v in t["v"]) for l in bvh}
    rows = []
    for a, b, area, sp in find_pairs(tris):
        ta, tb = tris[a], tris[b]
        c = [round(x, 2) for x in sp[0]]
        on_ground = ta["n"][2] < -0.9 and c[2] < base[ta["lod"]] + 0.5      # a bottom face resting on the plate
        esc = 0 if on_ground else escapes(bvh[ta["lod"]], sp, ta["n"])
        rows.append({"a": ta["obj"], "b": tb["obj"], "mat": [ta["mat"], tb["mat"]], "cell": [ta["cell"], tb["cell"]],
                     "severity": "colour" if (ta["mat"], ta["cell"]) != (tb["mat"], tb["cell"]) else "object",
                     "levels": sorted({level(ta["obj"]), level(tb["obj"])}), "gap": round(abs(ta["d"] - tb["d"]), 5),
                     "area": round(area, 3), "at": c, "normal": [round(x, 3) for x in ta["n"]],
                     "visible": esc >= 2, "escapes": esc, "_ab": (a, b)})
    rows.sort(key=lambda r: (not r["visible"], r["severity"] != "colour", -r["area"]))
    return rows


def check(path):
    bpy = load(path)
    tris = collect(bpy)
    rows = analyse(tris)
    for r in rows:
        del r["_ab"]
    vis = [r for r in rows if r["visible"]]
    return {"file": path, "tris": len(tris), "pairs": len(rows), "visible": len(vis),
            "visible_colour": sum(r["severity"] == "colour" for r in vis), "rows": rows}


def fix(objects):
    """Nudge the smaller face of every visible pair outward along its normal (OFFSET per layer, so a sign on a trim on
    a wall stays on top of both). Called by run.py right after build(), before the LODs. Returns (moved, left)."""
    import bpy
    objects = [o for o in objects if o.type == "MESH" and "_COL" not in o.name and "_HP" not in o.name]
    for o in objects:
        if o.data.users > 1:           # shared mesh data: edit this object's own copy
            o.data = o.data.copy()
    total, left = 0, []
    for _ in range(3):                 # a nudge can meet a third face (glass pushed level with the cabin side): repeat
        moved, left = _fix_pass(bpy, objects)
        total += moved
        if not left or not moved:
            break
    print("[zfight] moved %d faces; %d visible pairs left" % (total, len(left)))
    for r in left[:10]:
        print("[zfight] left %s / %s at %s area %s" % (r["a"], r["b"], r["at"], r["area"]))
    return total, len(left)


def _fix_pass(bpy, objects):
    from mathutils import Vector
    tris = collect(bpy, objects)
    rows = [r for r in analyse(tris) if r["visible"]]
    size = {}                          # an object's surface area: the smaller part (decal, trim) is the detail on top
    for t in tris:
        size[t["obj"]] = size.get(t["obj"], 0.0) + math.sqrt(_dot(*(2 * [_cross(_sub(t["v"][1], t["v"][0]),
                                                                              _sub(t["v"][2], t["v"][0]))]))) / 2
    off, edges = {}, []
    for r in rows:
        a, b = (tris[i] for i in r["_ab"])
        ka, kb = ((a["parea"], a["obj"]), (b["parea"], b["obj"])) if a["obj"] == b["obj"] else \
                 ((size[a["obj"]], a["obj"]), (size[b["obj"]], b["obj"]))
        w, l = (a, b) if ka < kb else (b, a)
        edges.append(((w["obj"], w["poly"]), (l["obj"], l["poly"]), w["n"]))
    for _ in range(6):                 # relax: winner >= loser + OFFSET
        for wk, lk, n in edges:
            if off.get(wk, (0, n))[0] < off.get(lk, (0, n))[0] + OFFSET:
                off[wk] = (off.get(lk, (0, n))[0] + OFFSET, n)
    byname = {o.name: o for o in objects}
    moves = {}                         # per vertex: the largest shift per direction (triangles of one face share verts)
    for (name, pi), (d, n) in off.items():
        ob = byname[name]
        local = ob.matrix_world.inverted().to_3x3() @ (Vector(n) * d)        # the world shift in mesh space
        for vi in ob.data.polygons[pi].vertices:
            per = moves.setdefault((name, vi), {})
            key = tuple(round(x, 2) for x in n)
            if key not in per or per[key].length < local.length:
                per[key] = local
    for (name, vi), per in moves.items():
        byname[name].data.vertices[vi].co += sum(per.values(), Vector())
    for o in objects:
        o.data.update()
    print("[zfight] pass: %d visible pairs, moved %d faces" % (len(rows), len(off)))
    return len(off), [r for r in analyse(collect(bpy, objects)) if r["visible"]]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if "--selftest" in argv:
        return _selftest()
    if "--fix-fbx" in argv:            # same export as the pipeline (rbxkit.export_fbx, textures stripped)
        src, dst = argv[argv.index("--fix-fbx") + 1:][:2]
        bpy = load(src)
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import common  # noqa: F401  (puts rbxkit on sys.path)
        import rbxkit
        meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        left = fix(meshes)[1]
        rbxkit.export_fbx(meshes, dst, bake_z=False, embed_textures=False)
        sys.exit(1 if left else 0)
    out = None
    if "--out" in argv:
        k = argv.index("--out")
        out = argv[k + 1]
        del argv[k:k + 2]
    results = []
    for path in argv:
        try:
            r = check(path)
        except Exception as e:             # one broken file must not hide the rest
            r = {"file": path, "error": str(e), "pairs": -1}
        results.append(r)
        print("ZF %s visible=%s (colour %s) buried=%s %s" % (
            "FAIL" if r.get("visible", 1) else "ok  ", r.get("visible"), r.get("visible_colour"),
            r["pairs"] - (r.get("visible") or 0), path), flush=True)
    if out:
        with open(out, "w") as f:
            json.dump(results, f, indent=1)
    if any(r.get("visible", 1) for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
