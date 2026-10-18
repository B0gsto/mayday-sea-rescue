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
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
import json  # noqa: E402
import versions  # noqa: E402
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf  # noqa: E402

NAME = "M_Sea_AdmiraltyAnchor"
UV = ("tile", 1.0, 1.0)
rnd = random.Random(1841)
SHANK = 3.2
ARM_R = 1.05            # arm arc radius about a centre on the shank
SINK = 0.06             # S1a-fix: stock half buried: the whole anchor sits 0.06 m into the seabed (terrain z = 0)


def crusty(ob, target, seed):
    """S1a-fix: thicken and roughen the iron under concretion: simple subdivision, a two-scale noise displacement
    along the normals (lumpy crust 2 to 6 cm), then collapse back to the triangle target (UVs kept)."""
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.subdivision_type, sub.levels, sub.render_levels = "SIMPLE", 2, 2
    for k, (size, depth) in enumerate(((0.35, 0.16), (0.09, 0.07))):
        tx = bpy.data.textures.new("S1aCrust%d" % k, "CLOUDS")
        tx.noise_scale, tx.noise_depth, tx.noise_basis = size, 2, "VORONOI_F1" if k == 0 else "BLENDER_ORIGINAL"
        d = ob.modifiers.new("Crust%d" % k, "DISPLACE")
        d.texture, d.strength, d.mid_level, d.direction = tx, depth, 0.25, "NORMAL"
        d.texture_coords = "GLOBAL"
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    me.name = ob.name
    versions.decimate(ob, target)
    versions.weighted_normals(ob)


SAND_UV = (-3.0, -3.05, 6.0)   # POL2: u0, v0 (m, before the base shift) and span (m) of the sand set; maketex.py mirrors it


def sand_bed(yh, yc, zc):
    """S1a-fix MeshPart _Sand (shares T_Morwenna_Silt): sand drifted over the stock, against the shank and over the
    buried arm, rippled just above the terrain (z = 0) and sinking under it along an irregular outline."""
    b = Buf()
    x0, x1, y0, y1, st = -2.6, 2.6, -3.0, 2.9, 0.16
    nx, ny = int(round((x1 - x0) / st)), int(round((y1 - y0) / st))

    def seg(px, py, ax, ay, bx, by):
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        return math.hypot(px - ax - t * dx, py - ay - t * dy)

    def height(x, y):
        h = 0.03 + 0.02 * math.sin(y * 7.0 + 1.3 * math.sin(x * 2.1)) + 0.015 * math.sin(x * 5.3 - y * 3.1)
        lump = 0.75 + 0.25 * math.sin(x * 9 + y * 6)
        h += lump * (0.10 * math.exp(-seg(x, y, 0, yh + 0.3, 0, yc) / 0.30) + 0.03 * math.exp(-seg(x, y, -1.6, yh + 0.12, 1.6, yh + 0.12) / 0.2)
                     + 0.14 * math.exp(-math.hypot(x, y - yc) / 0.35))
        th = math.atan2(y, x * 1.1)
        edge = 1.9 + 0.35 * math.sin(3 * th + 0.7) + 0.25 * math.sin(5 * th + 2.1) + 0.15 * math.sin(9 * th)
        h -= 0.35 * max(0.0, min(1.0, (math.hypot(x * 1.1, y * 0.85) - edge) / 0.6))
        return h
    idx = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            x, y = x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny
            x += rnd.uniform(-0.03, 0.03)
            y += rnd.uniform(-0.03, 0.03)
            idx[i, j] = b.add_vert((x, y, height(x, y)))
    for j in range(ny):
        for i in range(nx):
            q = [idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]]
            if max(b.v[k].z for k in q) < -0.08:
                continue
            # POL2: planar top-down UV over the whole bed (SAND_UV, metres) onto its own non-tiling set
            # T_AdmiraltyAnchor_Sand: ripples, grit in the troughs, smoothed drifts at the iron, alpha-faded rim
            b.face(q, [((b.v[k].x - SAND_UV[0]) / SAND_UV[2], (b.v[k].y - SAND_UV[1]) / SAND_UV[2]) for k in q], True)
    used = sorted({k for f in b.f for k in f})
    remap = {o: n for n, o in enumerate(used)}
    b.v = [b.v[o] for o in used]
    b.f = [[remap[k] for k in f] for f in b.f]
    return b.to_object(NAME + "_Sand_LOD0", "MI_AdmiraltyAnchor_Sand")


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
    sc = [(0.8 + 0.2 * math.cos(math.pi * (i / 14 - 0.5))) * rnd.uniform(1.0, 1.45) for i in range(15)]
    W.sweep(b, st, W.round_profile(0.06, 12), UV, scale=sc, smooth=True)
    for sx in (-1.6, 1.6):
        W.lathe(b, [(0.001, -0.075), (0.05, -0.065), (0.072, -0.03), (0.075, 0.0), (0.072, 0.03), (0.05, 0.065), (0.001, 0.075)],
                10, lambda k, a: (a, k / 6.0), centre=(sx, yh + 0.12, zs))
    # shank: octagonal, tapering from crown (0.17) to head (0.12), resting on the stock at the head and the lower arm
    # at the crown -> rises toward the crown
    zc = 0.075 + 0.06 + 0.075
    pts = [Vector((0, yh + 0.05 + (yc - yh - 0.05) * i / 10, zc)) for i in range(11)]
    W.sweep(b, pts, W.rect_profile(0.15, 0.15, 0.035), UV, up_hint=(0, 0, 1), scale=[(0.8 + 0.2 * i / 10) * rnd.uniform(1.05, 1.4) for i in range(11)])
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
    for k in range(46):                                  # S1a-fix: thick, merging concretion (was 9 nodules)
        where = rnd.choice(["shank", "shank", "stock", "stock", "crown", "arm"])
        if where == "shank":
            c = Vector((rnd.uniform(-0.05, 0.05), rnd.uniform(yh + 0.3, yc - 0.3), zc + rnd.choice([-1, 1]) * 0.07))
        elif where == "stock":
            c = Vector((rnd.uniform(-1.4, 1.4), yh + 0.12, zs + 0.05))
        elif where == "arm":
            a = math.radians(rnd.uniform(8, 58))
            c = Vector((rnd.uniform(-0.05, 0.05), cy + ARM_R * math.cos(a), zc + rnd.choice((1, -1)) * ARM_R * math.sin(a)))
        else:
            c = Vector((0, yc - 0.02, zc)) + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized() * 0.12
        r = rnd.uniform(0.05, 0.11)
        prof = [(r * rr, z) for rr, z in ((0.001, -r * 0.5), (0.8, -r * 0.4), (1.0, 0.0), (0.7, r * 0.45), (0.001, r * 0.6))]
        W.lathe(b, prof, 7, lambda kk, a: (a * 0.3, kk / 4.0 * 0.3), centre=tuple(c))
    b.transform(Matrix.Translation((0, 0, -SINK)))
    lod0 = b.to_object(NAME + "_LOD0", "MI_AdmiraltyAnchor_Iron")
    crusty(lod0, 5600, 1841)
    sand = sand_bed(yh, yc, zc - SINK)
    zs, zc = zs - SINK, zc - SINK
    crown = crown - Vector((0, 0, SINK))
    arm_tips = [t - Vector((0, 0, SINK)) for t in arm_tips]
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    boxes = [((0, 0, zc), (Y, X, Z), (SHANK / 2, 0.09, 0.09)), ((0, yh + 0.12, zs), (X, Y, Z), (1.65, 0.08, 0.08))]
    for tip in arm_tips:
        mid = crown.lerp(tip, 0.5)
        d = (tip - crown)
        boxes.append((tuple(mid), (d.normalized(), X, d.normalized().cross(X)), (d.length / 2 + 0.1, 0.1, 0.1)))
    col = W.col_boxes(boxes, NAME + "_COL")
    atts = [W.empty("ATT_Anchor", (0, yh - 0.42, zc), look=(0, -1, 0)), W.empty("ATT_AnchorCrown", (0, yc, zc + 0.2), look=(0, 1, 0))]
    off = W.shift_to_base([lod0, sand], empties=atts, others=[col])
    out = os.path.join(G, "assets/fbx", NAME)
    os.makedirs(out, exist_ok=True)
    terr = round(off.z, 3)
    json.dump({"asset": NAME, "terrain_z_studs_above_base": terr,
               "use": "place the pivot (base) this far below the seabed terrain: the stock is half buried, the lower arm in the sand"},
              open(os.path.join(out, NAME + ".placement.json"), "w"), indent=1)
    print("[S1a] anchor terrain level %.2f studs above the pivot base" % terr)
    tris = sum(len(p.vertices) - 2 for p in lod0.data.polygons) + sum(len(p.vertices) - 2 for p in sand.data.polygons)
    lo, hi = W.bbox([lod0])
    print("[S1a] anchor tris", tris, "bbox m %.2f x %.2f x %.2f" % tuple((hi - lo) / W.S))
    return {
        "name": NAME, "budget": "large_prop", "tris": 8000, "tier": "standard",
        "dims_m": (None, None, 1.93), "size_note": "iron 3.35 x 4.0 m (dims.md); the _Sand bed (4.6 x 5.3 m) sets the footprint", "origin": "base", "tiling": True,
        "sets": [{"name": "AdmiraltyAnchor", "set": "Iron", "size": 1024, "wet": False},
                 {"name": "AdmiraltyAnchor", "set": "Sand", "size": 1024, "wet": False}],
        "meshes": [{"object": lod0, "set": "Iron"}, {"object": sand, "set": "Sand"}, {"object": col}], "attachments": atts,
        "closeups": [
            {"name": "crown_palm", "target": [0, (yc - 0.4) * 3, 1.2 * 3], "dist": 7, "az": 60, "el": 20},
            {"name": "ring_stock", "target": [0, (yh) * 3, 0.4 * 3], "dist": 6, "az": -30, "el": 30},
        ],
    }
