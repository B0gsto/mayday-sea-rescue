"""UV checks for PBR sets (docs/12 1.1): UV islands, texel density per tier, and "same layout across LODs".

The maths on plain lists (uv_stats, compare_layouts) is pure and tested without Blender; the mesh readers need bpy.
Ported from Gulp's uvlayout.py; the creature family layout is dropped.
"""
import texgen

try:
    import bmesh
except ImportError:
    bmesh = None


def poly_area_2d(pts):
    a = 0.0
    for i in range(1, len(pts) - 1):
        a += abs((pts[i][0] - pts[0][0]) * (pts[i + 1][1] - pts[0][1]) - (pts[i + 1][0] - pts[0][0]) * (pts[i][1] - pts[0][1])) / 2.0
    return a


def uv_stats(faces_uv, faces_area3d):
    """faces_uv: [[(u, v), ...] per face]; faces_area3d: [area per face]. Returns bounds, UV area used (overlaps
    counted twice, so mirrored halves count per side), 3D area and the share of faces with zero UV area."""
    us = [p[0] for f in faces_uv for p in f]
    vs = [p[1] for f in faces_uv for p in f]
    uv_area = sum(poly_area_2d(f) for f in faces_uv)
    degenerate = sum(1 for f, a in zip(faces_uv, faces_area3d) if a > 1e-8 and poly_area_2d(f) < 1e-12)
    return {"min": (min(us), min(vs)) if us else (0.0, 0.0), "max": (max(us), max(vs)) if us else (0.0, 0.0),
            "uv_area": uv_area, "area3d": sum(faces_area3d), "faces": len(faces_uv),
            "zero_area_faces": degenerate}


def in_unit_square(stats, eps=1e-6):
    return stats["min"][0] >= -eps and stats["min"][1] >= -eps and stats["max"][0] <= 1 + eps and stats["max"][1] <= 1 + eps


def compare_layouts(lod0, lodn, bounds_tol=0.02, area_tol=0.15):
    """(ok, detail): a LOD keeps the LOD0 layout when its UV bounds match within `bounds_tol` and its UV area used
    within `area_tol` (collapse decimation moves UVs a little; a re-unwrap moves them a lot)."""
    db = max(abs(a - b) for a, b in zip(lod0["min"] + lod0["max"], lodn["min"] + lodn["max"]))
    da = abs(lodn["uv_area"] - lod0["uv_area"]) / lod0["uv_area"] if lod0["uv_area"] > 0 else 1.0
    ok = db <= bounds_tol and da <= area_tol
    return ok, "UV bounds differ by %.3f (max %.2f), UV area by %.1f%% (max %.0f%%)" % (db, bounds_tol, 100 * da, 100 * area_tol)


def density_verdict(density, tier_target, tolerance):
    lo, hi = tier_target
    ok = density >= lo * tolerance
    rule = "%d%s px/stud (pass at %.0f)" % (lo, " to %d" % hi if hi else " or more", lo * tolerance)
    return ok, rule


# ---------------------------------------------------------------- Blender side

def mesh_faces(mesh):
    """([[(u, v), ...] per face], [3D area per face]) from the active UV layer."""
    uv = mesh.uv_layers.active.data
    faces = [[tuple(uv[li].uv) for li in p.loop_indices] for p in mesh.polygons]
    return faces, [p.area for p in mesh.polygons]


def mesh_stats(mesh):
    faces, areas = mesh_faces(mesh)
    return uv_stats(faces, areas)


def texel_density(mesh, size):
    s = mesh_stats(mesh)
    return texgen.texel_density_px_per_stud(s["uv_area"], s["area3d"], size)


def islands(mesh):
    """Number of UV islands: faces joined across an edge where both faces' UVs agree at both ends."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uv = bm.loops.layers.uv.active
    seen, count = set(), 0

    def joined(f, g, edge):
        for v in edge.verts:
            a = next(l[uv].uv for l in f.loops if l.vert == v)
            b = next(l[uv].uv for l in g.loops if l.vert == v)
            if abs(a.x - b.x) > 1e-6 or abs(a.y - b.y) > 1e-6:
                return False
        return True

    for f in bm.faces:
        if f.index in seen:
            continue
        count += 1
        stack = [f]
        seen.add(f.index)
        while stack:
            cur = stack.pop()
            for e in cur.edges:
                for o in e.link_faces:
                    if o.index not in seen and joined(cur, o, e):
                        seen.add(o.index)
                        stack.append(o)
    bm.free()
    return count
