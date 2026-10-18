"""S1a M_Sea_AdmiraltyAnchor: an 1841 Admiralty-pattern, iron-stocked merchant bower (about 15 to 20 cwt) under
concretion, lying with the stock flat and the arms upright (docs/12 2.7; replaces map/Build.luau buildAnchor).

Size: shank 3.2 m + ring, stock 3.2 m, arm span 1.9 m (art/reference/M_Sea_AdmiraltyAnchor/dims.md). WorldConfig's
15 x 9 studs (5 x 3 m) is a ship-of-the-line anchor and would not match its own proportions: recommend 11 x 10 studs.
Blender: shank along Y (ring / stock end at -Y = front), stock along X at the head, arms in the YZ plane at the crown.
One MeshPart, set T_AdmiraltyAnchor_Iron (tiling, 1 m repeat). ATT_Anchor at the ring (diver interaction),
ATT_AnchorCrown at the crown.
"""
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(HERE, "../_S1a"))
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf  # noqa: E402

NAME = "M_Sea_AdmiraltyAnchor"
UV = ("tile", 1.0, 1.0)
rnd = random.Random(1841)
SHANK = 3.2
ARM_R = 1.05            # arm arc radius about a centre on the shank


def build():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_Anchor"):
            bpy.data.objects.remove(o, do_unlink=True)
    b = Buf()
    yh, yc = -SHANK / 2, SHANK / 2          # head (stock / ring) and crown
    zc = 0.0                                # shank axis height (set below)
    # stock: round iron bar, flat on the seabed along X, balls at the ends, collar at the shank
    zs = 0.075
    st = [Vector((x, yh + 0.12, zs)) for x in [-1.6 + 3.2 * i / 14 for i in range(15)]]
    sc = [0.8 + 0.2 * math.cos(math.pi * (i / 14 - 0.5)) for i in range(15)]
    W.sweep(b, st, W.round_profile(0.06, 12), UV, scale=sc, smooth=True)
    for sx in (-1.6, 1.6):
        W.lathe(b, [(0.001, -0.075), (0.05, -0.065), (0.072, -0.03), (0.075, 0.0), (0.072, 0.03), (0.05, 0.065), (0.001, 0.075)],
                10, lambda k, a: (a, k / 6.0), centre=(sx, yh + 0.12, zs))
    # shank: octagonal, tapering from crown (0.17) to head (0.12), resting on the stock at the head and the lower arm
    # at the crown -> rises toward the crown
    zc = 0.075 + 0.06 + 0.075
    pts = [Vector((0, yh + 0.05 + (yc - yh - 0.05) * i / 10, zc)) for i in range(11)]
    W.sweep(b, pts, W.rect_profile(0.15, 0.15, 0.035), UV, up_hint=(0, 0, 1), scale=[0.8 + 0.2 * i / 10 for i in range(11)])
    # shank head: flattened eye boss through which the stock passes, and the shackle + ring
    W.obox(b, (0, yh + 0.12, zc - 0.03), ((0, 0, 1), (1, 0, 0), (0, 1, 0)), (0.12, 0.10, 0.09), UV)
    W.ring(b, (0, yh - 0.12, zc), (0, 1, 0), (0, 0, 1), 0.07, 0.022, 12, 6, UV, stretch=0.08)          # shackle
    W.ring(b, (0, yh - 0.42, zc), (0, 1, 0), (1, 0.0, 0.35), 0.24, 0.032, 18, 7, UV)                 # ring, slumped
    # arms: arcs in the YZ plane, centre on the shank toward the head, tips (bills) pointing back toward the head
    cy = yc - ARM_R
    crown = Vector((0, yc, zc))
    arm_tips = []
    for sgn in (1, -1):
        arc = []
        for i in range(11):
            a = math.radians(4 + 58 * i / 10)
            arc.append(Vector((0, cy + ARM_R * math.cos(a), zc + sgn * ARM_R * math.sin(a))))
        arc[0] = crown + Vector((0, 0.02, 0))
        W.sweep(b, arc, W.rect_profile(0.13, 0.15, 0.03), UV, up_hint=(1, 0, 0), scale=[1.15 - 0.45 * i / 10 for i in range(11)])
        tip = arc[-1]
        arm_tips.append(tip)
        # palm (fluke): a spade plate on the inner face, bill pointing beyond the tip
        t = (arc[-1] - arc[-3]).normalized()
        inward = Vector((0, -(tip.y - cy), -(tip.z - zc))).normalized()
        c = arc[-3].lerp(arc[-1], 0.5) + inward * 0.06
        side = Vector((1, 0, 0))
        prof = [(-0.20, -0.02), (0.20, -0.02), (0.20, 0.02), (-0.20, 0.02)]
        pp = [c - t * 0.22, c, c + t * 0.14, c + t * 0.24]
        W.sweep(b, pp, prof, UV, axes=[(side, inward)] * 4, scale=[0.6, 1.0, 0.75, 0.12])
    # crown: a rounded boss where shank and arms meet
    W.lathe(b, [(0.001, -0.12), (0.09, -0.1), (0.13, -0.04), (0.13, 0.04), (0.09, 0.1), (0.001, 0.12)], 10,
            lambda k, a: (a, k / 5.0), centre=(0, yc - 0.02, zc))
    # concretion: lumpy nodules on shank, stock and crown
    for k in range(9):
        where = rnd.choice(["shank", "shank", "stock", "crown"])
        if where == "shank":
            c = Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(yh + 0.3, yc - 0.3), zc + rnd.choice([-1, 1]) * 0.07))
        elif where == "stock":
            c = Vector((rnd.uniform(-1.4, 1.4), yh + 0.12, zs + 0.05))
        else:
            c = Vector((0, yc - 0.02, zc)) + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized() * 0.12
        r = rnd.uniform(0.035, 0.07)
        prof = [(r * rr, z) for rr, z in ((0.001, -r * 0.5), (0.8, -r * 0.4), (1.0, 0.0), (0.7, r * 0.45), (0.001, r * 0.6))]
        W.lathe(b, prof, 7, lambda kk, a: (a * 0.3, kk / 4.0 * 0.3), centre=tuple(c))
    lod0 = b.to_object(NAME + "_LOD0", "MI_AdmiraltyAnchor_Iron")
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    boxes = [((0, 0, zc), (Y, X, Z), (SHANK / 2, 0.09, 0.09)), ((0, yh + 0.12, zs), (X, Y, Z), (1.65, 0.08, 0.08))]
    for tip in arm_tips:
        mid = crown.lerp(tip, 0.5)
        d = (tip - crown)
        boxes.append((tuple(mid), (d.normalized(), X, d.normalized().cross(X)), (d.length / 2 + 0.1, 0.1, 0.1)))
    col = W.col_boxes(boxes, NAME + "_COL")
    atts = [W.empty("ATT_Anchor", (0, yh - 0.42, zc), look=(0, -1, 0)), W.empty("ATT_AnchorCrown", (0, yc, zc + 0.2), look=(0, 1, 0))]
    W.shift_to_base([lod0], empties=atts, others=[col])
    tris = sum(len(p.vertices) - 2 for p in lod0.data.polygons)
    lo, hi = W.bbox([lod0])
    print("[S1a] anchor tris", tris, "bbox m %.2f x %.2f x %.2f" % tuple((hi - lo) / W.S))
    return {
        "name": NAME, "budget": "large_prop", "tris": 4000, "tier": "standard",
        "dims_m": (3.35, 4.0, 1.93), "size_note": None, "origin": "base", "tiling": True,
        "sets": [{"name": "AdmiraltyAnchor", "set": "Iron", "size": 1024, "wet": False}],
        "meshes": [{"object": lod0, "set": "Iron"}, {"object": col}], "attachments": atts,
        "closeups": [
            {"name": "crown_palm", "target": [0, (yc - 0.4) * 3, 1.2 * 3], "dist": 7, "az": 60, "el": 20},
            {"name": "ring_stock", "target": [0, (yh) * 3, 0.4 * 3], "dist": 6, "az": -30, "el": 30},
        ],
    }
