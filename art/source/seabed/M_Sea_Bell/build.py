"""S1a M_Sea_Bell: the Morwenna's cast bronze ship's bell, 0.26 m mouth, "MORWENNA 1902" cast on the waist band,
verdigris (docs/12 2.7). Shares the wreck metal set (assets/textures/M_Sea_Morwenna/T_Morwenna_Metal_*): body and
crown in the bronze strip (v 0.25..0.5), the waist band in the lettering strip (v 0..0.25, text centred at u 0.5 =
the bell's front, -Y), iron clapper in the iron strip. Upright, origin at the base (mouth); integration lays it at the
Morwenna's ATT_Bell. ATT_Bell at the crown loop (diver pick-up point).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(HERE, "../_S1a"))
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf  # noqa: E402

NAME = "M_Sea_Bell"
N = 28                     # S1a-fix: rounder waist so the lettering band reads smooth (was 20)
# outer profile (radius, z) mouth -> shoulder, in metres; waist band between rows BAND
OUTER = [(0.130, 0.000), (0.131, 0.012), (0.124, 0.030), (0.112, 0.060), (0.103, 0.095), (0.098, 0.125),
         (0.096, 0.150), (0.095, 0.180), (0.093, 0.205), (0.088, 0.228), (0.074, 0.246), (0.050, 0.256), (0.0, 0.258)]
BAND = (4, 7)            # rows 4..7: z 0.095..0.180, the cast lettering band
INNER = [(0.0, 0.226), (0.045, 0.224), (0.072, 0.212), (0.083, 0.185), (0.088, 0.140), (0.096, 0.080),
         (0.108, 0.035), (0.118, 0.004), (0.130, 0.000)]


# POL2: the inscription, in two cast lines ("MORWENNA" over "1902") kept on the visible front (about +-48 deg of the
# waist; round 1/2 spread one line over 180 deg so only "RWENN" faced the camera and read as "RAVENN"). Raised in
# geometry (3 mm relief, Arial Bold glyphs from a Blender text object, wrapped onto the profile) and the same triangles
# go to lettering.json so maketex.py paints the rubbed bronze faces, bevel and silt feet exactly under them.
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
LINES = [("MORWENNA", 0.1405, 0.165), ("1902", 0.1065, None)]   # (text, baseline z m, fit width m or None = same size)
CAP = 0.025              # max cap height, m
RELIEF, SINKD = 0.0030, 0.0015
R_MID = 0.098


def radius_at(z):
    for (r0, z0_), (r1, z1_) in zip(OUTER, OUTER[1:]):
        if z0_ <= z <= z1_:
            return r0 + (r1 - r0) * (z - z0_) / (z1_ - z0_)
    return OUTER[-1][0]


def glyph_mesh(text, size):
    cu = bpy.data.curves.new("BellTxt_" + text, "FONT")
    cu.body = text
    cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    cu.size = size
    cu.align_x = "CENTER"
    cu.resolution_u = 3
    cu.space_character = 1.06
    ob = bpy.data.objects.new(cu.name, cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    verts = [(v.co.x, v.co.y) for v in me.vertices]
    me.calc_loop_triangles()
    tris = [tuple(me.loops[l].vertex_index for l in t.loops) for t in me.loop_triangles]
    count, directed = {}, []
    for p in me.polygons:
        vs = list(p.vertices)
        for a, c in zip(vs, vs[1:] + vs[:1]):
            k = (min(a, c), max(a, c))
            count[k] = count.get(k, 0) + 1
            directed.append((a, c))
    bnd = [(a, c) for a, c in directed if count[(min(a, c), max(a, c))] == 1]
    ob.evaluated_get(dg).to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    return verts, tris, bnd


def lettering(b, z0, z1):
    scale = None
    out = []
    for text, base, fit in LINES:
        verts, tris, bnd = glyph_mesh(text, 1.0)
        xs, ys = [v[0] for v in verts], [v[1] for v in verts]
        if scale is None:
            scale = min(fit / (max(xs) - min(xs)), CAP / max(ys))
        cx = (max(xs) + min(xs)) / 2
        pts = [((x - cx) * scale, base + y * scale) for x, y in verts]

        def place(x, z, d):
            th = x / R_MID
            r = radius_at(z) + d
            uv = (0.5 + th / (2 * math.pi), 0.01 + 0.23 * (z - z0) / (z1 - z0))
            return Vector((math.sin(th) * r, -math.cos(th) * r, z)), uv
        top = [place(x, z, RELIEF) for x, z in pts]
        bot = [place(x, z, -SINKD) for x, z in pts]
        ti = [b.add_vert(p) for p, _ in top]
        bi = [b.add_vert(p) for p, _ in bot]
        for t in tris:
            b.face([ti[k] for k in t], [top[k][1] for k in t], False)
            out.append([list(top[k][1]) for k in t])
        for a, c in bnd:
            # side walls: the foot UVs step 0.0008 outward (about 1.6 px of the 2048 master) into the bevel / silt
            # feet, so the walls sample the dark cast edge and keep UV area (validate: no zero-area UV faces)
            (ua, va), (uc, vc) = top[a][1], top[c][1]
            du, dv = uc - ua, vc - va
            ln = math.hypot(du, dv) or 1.0
            n = (dv / ln * 0.0008, -du / ln * 0.0008)
            fa, fc = (ua + n[0], va + n[1]), (uc + n[0], vc + n[1])
            b.face([bi[a], bi[c], ti[c], ti[a]], [fa, fc, top[c][1], top[a][1]], False)
    json.dump({"note": "POL2 bell inscription triangles in UV (u, v) of the T_Morwenna_Metal band; written by build.py, read by maketex.py",
               "tris": [[[round(c, 6) for c in uv] for uv in t] for t in out]}, open(os.path.join(HERE, "lettering.json"), "w"))
    print("[POL2] bell lettering cap %.1f mm, %d face tris" % (CAP if scale is None else scale * 1000 * 0.716, len(out)))


def build():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_Bell"):
            bpy.data.objects.remove(o, do_unlink=True)
    b = Buf()
    z0, z1 = OUTER[BAND[0]][1], OUTER[BAND[1]][1]

    def outer_uv(k, a):
        z = OUTER[k][1]
        if BAND[0] <= k <= BAND[1]:
            return (a, 0.01 + 0.23 * (z - z0) / (z1 - z0))
        return (a, 0.26 + 0.23 * (k / (len(OUTER) - 1)))
    # POL2: three lathes (sound bow, band, shoulder) with the seam rows duplicated. One lathe let the ring between
    # rows 3 and 4 interpolate v from the bronze strip (0.32) down to the band's foot (0.01), so it carried a squashed,
    # upside-down copy of the whole inscription under the real one (part of the garbled read)
    for k0, k1 in ((0, BAND[0]), BAND, (BAND[1], len(OUTER) - 1)):
        def part_uv(k, a, k0=k0, k1=k1):
            kk = k + k0
            if (k0, k1) == BAND:
                return outer_uv(kk, a)
            return (a, 0.26 + 0.23 * (kk / (len(OUTER) - 1)))
        W.lathe(b, OUTER[k0:k1 + 1], N, part_uv)
    W.lathe(b, INNER, 16, lambda k, a: (a, 0.26 + 0.23 * k / (len(INNER) - 1)))
    # crown: two canons (the cast loop) on top
    W.ring(b, (0, 0, 0.258 + 0.045), (0, 0, 1), (1, 0, 0), 0.034, 0.012, 10, 6, ("strip", 0.26, 0.49, 0.3))
    W.ring(b, (0, 0, 0.258 + 0.045), (0, 0, 1), (0, 1, 0), 0.034, 0.012, 10, 6, ("strip", 0.26, 0.49, 0.3))
    # S1a-fix: the iron clapper, readable: a staple loop under the crown, a tapered shank and a heavy ball hanging
    # level with the sound bow (it shows in the mouth), with a short flight below the ball
    W.ring(b, (0, 0, 0.212), (1, 0, 0), (0, 0, 1), 0.014, 0.005, 10, 5, ("strip", 0.52, 0.98, 0.3))
    W.sweep(b, [Vector((0, 0, 0.200)), Vector((0, 0, 0.12)), Vector((0, 0, 0.045))], W.round_profile(0.008, 8),
            ("strip", 0.52, 0.98, 0.3), scale=[0.9, 1.0, 1.35], smooth=True)
    W.lathe(b, [(0.001, -0.012), (0.012, -0.010), (0.016, 0.004), (0.026, 0.014), (0.031, 0.030), (0.027, 0.046),
                (0.014, 0.056), (0.001, 0.060)], 12, lambda k, a: (a * 0.3, 0.55 + 0.4 * k / 7))
    lettering(b, z0, z1)
    lod0 = b.to_object(NAME + "_LOD0", "MI_Morwenna_Metal")
    att = W.empty("ATT_Bell", (0, 0, 0.30), look=(0, -1, 0))
    W.shift_to_base([lod0], empties=[att])
    tris = sum(len(p.vertices) - 2 for p in lod0.data.polygons)
    lo, hi = W.bbox([lod0])
    print("[S1a] bell tris", tris, "bbox m %.3f x %.3f x %.3f" % tuple((hi - lo) / W.S))
    return {
        "name": NAME, "budget": "small_prop", "tris": 3000, "tier": "hero", "dims_m": (0.26, 0.26, 0.35),
        "size_note": None, "origin": "base", "tiling": True, "atlas": "Morwenna_Metal",
        "sets": [{"name": "Morwenna", "set": "Metal", "size": 1024, "wet": False,
                  "dir": os.path.join(G, "assets/textures/M_Sea_Morwenna")}],
        "meshes": [{"object": lod0, "set": "Metal"}], "attachments": [att],
        "waivers": {"LOD UV layout": "lathe seam columns and the two canon loops merge under collapse; the LOD samples the same strips"},
        "closeups": [{"name": "lettering", "target": [0, 0, 0.42], "dist": 2.2, "az": 0, "el": 5}],
    }
