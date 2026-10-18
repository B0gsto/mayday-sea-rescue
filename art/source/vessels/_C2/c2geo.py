"""C2 shared Blender helpers (Gale Queen ferry + SOLAS liferaft). Builds on art/source/seabed/_S1a/wreckgeo.py (Buf,
sweep, ring, lathe, obox, col_boxes, empty, shift_to_base); adds a lofted grid surface, tube runs and the LOD maker
(versions.decimate, the run.py lod step's own code, with each part's share of the LOD ceilings). Metres in, studs out."""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "art/source/seabed/_S1a"))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
import budgets  # noqa: E402
import versions  # noqa: E402
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf, V  # noqa: E402,F401


def grid(buf, rows, uvs, smooth=True, flip=False):
    """Quad grid from rows of points (list of lists, same length) and matching uv rows."""
    idx = [[buf.add_vert(p) for p in r] for r in rows]
    for i in range(len(rows) - 1):
        for j in range(len(rows[0]) - 1):
            q = [idx[i][j], idx[i][j + 1], idx[i + 1][j + 1], idx[i + 1][j]]
            u = [uvs[i][j], uvs[i][j + 1], uvs[i + 1][j + 1], uvs[i + 1][j]]
            if flip:
                q, u = q[::-1], u[::-1]
            buf.face(q, u, smooth)
    return idx


def tube(buf, pts, r, uv, sides=6, caps=(True, True), smooth=True, up_hint=(0, 0, 1)):
    return W.sweep(buf, pts, W.round_profile(r, sides), uv, up_hint=up_hint, caps=caps, smooth=smooth)


def box(buf, lo, hi, uv, axes=None):
    """Axis-aligned box from lo / hi corners (metres)."""
    lo, hi = Vector(lo), Vector(hi)
    c = (lo + hi) / 2
    h = (hi - lo) / 2
    ax = axes or ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    # sweep along the longest axis so tiling U runs along it
    order = sorted(range(3), key=lambda i: -h[i])
    A = [Vector(ax[i]) for i in order]
    if A[0].cross(A[1]).dot(A[2]) < 0:
        A[2] = -A[2]
    return W.obox(buf, c, A, [h[i] for i in order], uv)


def catenary(a, b, sag, n):
    a, b = Vector(a), Vector(b)
    return [a.lerp(b, i / n) - Vector((0, 0, sag * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]


def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def make_lods(objs, budget, budget_tris, lods=("LOD1", "LOD2"), keep=()):
    """LOD1 / LOD2 for every part: collapse decimation to the class target, each part capped at its share of the
    class ceiling (x 0.92). Parts in `keep` are copied unchanged at LOD1 (decals: 2 tris a letter)."""
    import bmesh
    out = []
    tot = sum(tri_count(o) for o in objs.values())
    for k, src in objs.items():
        n = tri_count(src)
        for lod in lods:
            name = src.name.replace("_LOD0", "_" + lod)
            old = bpy.data.objects.get(name)
            if old is not None:
                bpy.data.objects.remove(old, do_unlink=True)
            target = budgets.lod_target(budget, lod, n, budget_tris)
            ceil = budgets.lod_ceiling(budget, lod, budget_tris) * 0.92
            target = max(12, min(target, int(n * ceil / tot)))
            obj = versions.copy_object(src, name)
            if not (k in keep and lod == "LOD1"):
                try:
                    versions.decimate(obj, target)
                except RuntimeError as e:
                    print("[C2] %s: %s (kept the closest)" % (name, e))
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
            bm.to_mesh(obj.data)
            bm.free()
            versions.weighted_normals(obj)
            print("[lod] %s %d triangles (target %d, LOD0 %d)" % (name, versions.triangles(obj.data), target, n))
            out.append((obj, lod, src))
    return out


def clear_scene():
    for o in list(bpy.context.scene.objects):
        if not o.name.startswith("TPL_"):
            bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)


def lathe_strip(buf, profile, n, v0, v1, u_tiles, centre=(0, 0, 0), skip=None, smooth=True, flip=False):
    """Revolve (radius, z) about +Z; u = angle fraction * u_tiles, v = v0..v1 by profile arc length.
    skip(angle_rad, z_mid) -> True drops a face (openings)."""
    c = Vector(centre)
    arc = [0.0]
    for k in range(1, len(profile)):
        arc.append(arc[-1] + math.hypot(profile[k][0] - profile[k - 1][0], profile[k][1] - profile[k - 1][1]))
    rows = []
    for (r, z) in profile:
        rows.append([buf.add_vert(c + Vector((r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z)))
                     for i in range(n + 1)])
    for k in range(len(profile) - 1):
        for i in range(n):
            if skip and skip(2 * math.pi * (i + 0.5) / n, (profile[k][1] + profile[k + 1][1]) / 2):
                continue
            va = v0 + (v1 - v0) * arc[k] / arc[-1]
            vb = v0 + (v1 - v0) * arc[k + 1] / arc[-1]
            ua, ub = i / n * u_tiles, (i + 1) / n * u_tiles
            q = [rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i]]
            uv = [(ua, va), (ub, va), (ub, vb), (ua, vb)]
            if flip:
                q, uv = q[::-1], uv[::-1]
            buf.face(q, uv, smooth)
    return rows
