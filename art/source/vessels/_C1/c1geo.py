"""C1 shared Blender helpers (The Optimist, sit-on-top kayak, inflatable SUP). Builds on art/source/vessels/_C2/c2geo.py
(Buf, sweep, tube, ring, lathe_strip, col_boxes, empty, shift_to_base, make_lods). Adds faces oriented by a wanted
direction (so open shells never depend on bmesh's guess), oriented grids, closed slabs with planar UVs, band UVs and the
spec finaliser shared by the three build files. Metres in, studs out (W.S = 3)."""
import math
import os
import sys

from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C2"))
import c2geo as C  # noqa: E402
from c2geo import Buf, V, W  # noqa: E402,F401


def oface(buf, pts, uvs, want, smooth=False):
    """Add a polygon from points (metres) wound so its normal agrees with `want` (vector or callable(centre))."""
    P = [Vector(p) for p in pts]
    n = Vector()
    for i in range(len(P)):     # Newell normal
        a, b = P[i], P[(i + 1) % len(P)]
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    c = sum(P, Vector()) / len(P)
    w = Vector(want(c) if callable(want) else want)
    idx = [buf.add_vert(p) for p in P]
    if n.dot(w) < 0:
        idx, uvs = idx[::-1], list(uvs)[::-1]
    buf.face(idx, uvs, smooth)


def ogrid(buf, rows, uvs, want, smooth=True):
    """Quad grid from rows of points (same length) with matching uv rows; every quad wound toward `want`.
    Shared verts so smooth shading is continuous."""
    idx = [[buf.add_vert(Vector(p)) for p in r] for r in rows]
    for i in range(len(rows) - 1):
        for j in range(len(rows[0]) - 1):
            q = [idx[i][j], idx[i][j + 1], idx[i + 1][j + 1], idx[i + 1][j]]
            u = [uvs[i][j], uvs[i][j + 1], uvs[i + 1][j + 1], uvs[i + 1][j]]
            P = [buf.v[k] for k in q]
            n = (P[1] - P[0]).cross(P[3] - P[0]) + (P[2] - P[3]).cross(P[2] - P[1])
            if n.length < 1e-12:
                n = (P[2] - P[0]).cross(P[3] - P[1])
            c = sum(P, Vector()) / 4
            w = Vector(want(c) if callable(want) else want)
            if n.dot(w) < 0:
                q, u = q[::-1], u[::-1]
            buf.face(q, u, smooth)
    return idx


def slab(buf, quad, th, uvfn, out=None, smooth=False):
    """Closed slab: front quad (4 points, metres, any winding) facing `out` (default: its own winding normal),
    thickness th behind it. uvfn(point) -> uv for every corner (planar mapping)."""
    a, b, c, d = [Vector(p) for p in quad]
    n = (b - a).cross(d - a).normalized()
    if out is not None and n.dot(Vector(out)) < 0:
        n = -n
    back = [p - n * th for p in (a, b, c, d)]
    front = [a, b, c, d]
    oface(buf, front, [uvfn(p) for p in front], n, smooth)
    oface(buf, back, [uvfn(p) for p in back], -n, smooth)
    ctr = sum(front + back, Vector()) / 8
    fu = [Vector(uvfn(p)) for p in front]
    # texel density of the front face (uv length per metre), for the edge strips
    dens = max(((fu[1] - fu[0]).length + (fu[2] - fu[3]).length) / max((b - a).length + (c - d).length, 1e-6),
               ((fu[3] - fu[0]).length + (fu[2] - fu[1]).length) / max((d - a).length + (c - b).length, 1e-6), 0.2)
    for i in range(4):
        p, q = front[i], front[(i + 1) % 4]
        p2, q2 = back[i], back[(i + 1) % 4]
        up, uq = fu[i], fu[(i + 1) % 4]
        du = uq - up
        if du.length < 1e-6:
            du = Vector((dens * (q - p).length + 1e-3, 0.0))
        e = Vector((-du.y, du.x)).normalized() * max(th * dens, 1e-3)
        quad_e = [p, q, q2, p2]
        mid = sum(quad_e, Vector()) / 4
        oface(buf, quad_e, [tuple(up), tuple(up + du), tuple(up + du + e), tuple(up + e)], mid - ctr, smooth)


def bandfn(bands):
    def band(k, tu=1.0):
        v0, v1 = bands[k]
        return ("strip", v0 + 0.004, v1 - 0.004, tu)
    return band


def finish(name, parts, recalc=()):
    """Delete loose verts; bmesh-recalc normals only on parts made of closed pieces (`recalc`)."""
    import bmesh
    for k, o in parts.items():
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        if k in recalc:
            bm.faces.ensure_lookup_table()
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()


def spec(name, budget, budget_tris, parts, sets, atts, col, dims_m, size_note=None, waivers=None, closeups=None,
         keep=()):
    lods = C.make_lods(parts, budget, budget_tris, keep=keep)
    for o, lod, src in lods:      # small detail parts that cannot decimate (tubes, cords): dropped at LOD2
        if lod == "LOD2" and C.tri_count(o) > 0.45 * C.tri_count(src):
            drop_proxy(o, src)
    vis = list(parts.values())
    W.shift_to_base(vis + [col], empties=atts, others=[o for o, _, _ in lods])
    lo, hi = W.bbox(vis)
    tri = {k: C.tri_count(o) for k, o in parts.items()}
    print("[C1] %s tris %s total %d bbox m %.3f x %.3f x %.3f" % ((name, tri, sum(tri.values())) + tuple((hi - lo) / W.S)))
    for e in atts:
        p = e.matrix_world.translation
        print("[C1-att] %s %s roblox studs (%.2f, %.2f, %.2f)" % (name, e.name, -p.x, p.z, p.y))
    for o in vis + [lo_ for lo_, _, _ in lods]:
        fix_uv(o)
    meshes = [{"object": o, "set": parts_set} for parts_set, o in ((sets_of(k, sets), o) for k, o in parts.items())]
    meshes += [{"object": col}]
    meshes += [{"object": o, "role": "visual", "lod": lod, "of": src.name, "set": next(m["set"] for m in meshes if m["object"] is src)}
               for o, lod, src in lods]
    out = {"name": name, "budget": budget, "tris": budget_tris, "tier": "standard", "dims_m": dims_m,
           "size_note": size_note, "origin": "base", "tiling": True,
           "sets": [{"name": sets["name"], "set": st, "size": 1024, "wet": True} for st in sets["sets"]],
           "meshes": meshes, "attachments": atts,
           "waivers": waivers or {"LOD UV layout": "thin strips (rails, cords, rope) decimate into fewer islands; every LOD samples the same trim sets"}}
    if closeups:
        out["closeups"] = closeups
    return out


def sets_of(part, sets):
    return sets["map"][part]


def mat(name, sets, part):
    return "MI_%s_%s_%s" % (name, sets["name"], sets["map"][part])


def drop_proxy(o, src):
    """Replace a LOD mesh with a 2-triangle 1 cm quad at the source's centre (the part is dropped at that LOD)."""
    import bmesh
    lo, hi = W.bbox([src])
    c = (lo + hi) / 2
    uv = src.data.uv_layers[0].data
    u0 = Vector(uv[0].uv)
    bm = bmesh.new()
    d = 0.03       # studs
    vs = [bm.verts.new(c + Vector(v)) for v in ((-d, 0, -d), (d, 0, -d), (d, 0, d), (-d, 0, d))]
    f = bm.faces.new(vs)
    lay = bm.loops.layers.uv.new("UVMap")
    for l, k in zip(f.loops, ((0, 0), (0.01, 0), (0.01, 0.01), (0, 0.01))):
        l[lay].uv = (u0.x + k[0], u0.y + k[1])
    me = o.data
    for layer in list(me.uv_layers):
        me.uv_layers.remove(layer)
    bm.to_mesh(me)
    bm.free()
    me.update()
    print("[C1] %s dropped (2-triangle proxy)" % o.name)


def fix_uv(o, eps=1.2e-3):
    """Give faces whose UVs collapsed to a line or point (tube caps, decimation) a 1-pixel UV footprint."""
    me = o.data
    uv = me.uv_layers[0].data
    n = 0
    for poly in me.polygons:
        li = list(poly.loop_indices)
        P = [Vector(uv[i].uv) for i in li]
        area = 0.0
        for k in range(1, len(P) - 1):
            a, b = P[k] - P[0], P[k + 1] - P[0]
            area += abs(a.x * b.y - a.y * b.x) / 2
        if area < 1e-9:
            c = sum(P, Vector((0, 0))) / len(P)
            for k, i in enumerate(li):
                ang = 2 * math.pi * k / len(li)
                uv[i].uv = (c.x + eps * math.cos(ang), c.y + eps * math.sin(ang))
            n += 1
    if n:
        print("[C1] %s: %d faces given a UV footprint" % (o.name, n))
