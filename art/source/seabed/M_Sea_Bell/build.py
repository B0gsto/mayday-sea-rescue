"""S1a M_Sea_Bell: the Morwenna's cast bronze ship's bell, 0.26 m mouth, "MORWENNA 1902" cast on the waist band,
verdigris (docs/12 2.7). Shares the wreck metal set (assets/textures/M_Sea_Morwenna/T_Morwenna_Metal_*): body and
crown in the bronze strip (v 0.25..0.5), the waist band in the lettering strip (v 0..0.25, text centred at u 0.5 =
the bell's front, -Y), iron clapper in the iron strip. Upright, origin at the base (mouth); integration lays it at the
Morwenna's ATT_Bell. ATT_Bell at the crown loop (diver pick-up point).
"""
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
    W.lathe(b, OUTER, N, outer_uv)
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
    lod0 = b.to_object(NAME + "_LOD0", "MI_Morwenna_Metal")
    att = W.empty("ATT_Bell", (0, 0, 0.30), look=(0, -1, 0))
    W.shift_to_base([lod0], empties=[att])
    tris = sum(len(p.vertices) - 2 for p in lod0.data.polygons)
    lo, hi = W.bbox([lod0])
    print("[S1a] bell tris", tris, "bbox m %.3f x %.3f x %.3f" % tuple((hi - lo) / W.S))
    return {
        "name": NAME, "budget": "small_prop", "tris": 1500, "tier": "hero", "dims_m": (0.26, 0.26, 0.35),
        "size_note": None, "origin": "base", "tiling": True, "atlas": "Morwenna_Metal",
        "sets": [{"name": "Morwenna", "set": "Metal", "size": 1024, "wet": False,
                  "dir": os.path.join(G, "assets/textures/M_Sea_Morwenna")}],
        "meshes": [{"object": lod0, "set": "Metal"}], "attachments": [att],
        "waivers": {"LOD UV layout": "lathe seam columns and the two canon loops merge under collapse; the LOD samples the same strips"},
        "closeups": [{"name": "lettering", "target": [0, 0, 0.42], "dist": 2.2, "az": 0, "el": 5}],
    }
