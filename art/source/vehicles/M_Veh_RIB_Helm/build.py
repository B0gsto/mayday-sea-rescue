"""M_Veh_RIB_Helm: the RIB's helm for close-up and first person (batch V2). Same frame as M_Veh_RIB (reads
../M_Veh_RIB/frame_offset.json), so `PivotTo` the RIB's pivot and it sits on the console shell and the deck.

Console set (2048, hero): dash panel, chartplotter, VHF with handset, switch panel, twin engine gauges, compass,
wheel with helm pump, twin throttle binnacle, kill cord, stainless grab rails. Seats set (1024, hero): three
jockey seats (helm, two crew) with pods, saddle cushions, bolsters, handlebars and foot bars.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Veh_RIB_Helm --steps build,lod,validate,export
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
RIB_DIR = os.path.join(os.path.dirname(HERE), "M_Veh_RIB")
sys.path.insert(0, RIB_DIR)
import ribgeo as R  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Veh_RIB_Helm"
TEX = "RIBHelm"
D = R.DECK


def M(g, name):
    return name if g.hi else "X"


# sloping dash: from (y -0.8, z 5.1) down to (y -0.05, z 4.6) on the console shell
DASH_C = Vector((0.0, -0.425, 4.85))
DASH_S = Vector((0.0, -0.75, 0.5)).normalized()        # up the slope, forward
DASH_N = Vector((0.0, 0.5, 0.75)).normalized()         # out of the dash, up and aft
DASH_ROT = Matrix.Rotation(math.atan2(0.5, 0.75), 3, "X")


def on_dash(u, v, h):
    return DASH_C + Vector((u, 0, 0)) + DASH_S * v + DASH_N * h


def dash_box(g, u, v, h, size, mat):
    R.box(g, tuple(on_dash(u, v, h + size[2] / 2)), size, mat, rot=DASH_ROT)


def dial(g, u, v, r, segs):
    R.lathe(g, on_dash(u, v, 0.04), DASH_N, [(r, 0.0), (r, 0.03), (r * 0.85, 0.035), (r * 0.85, 0.02), (0.0, 0.02)],
            segs, M(g, "Stainless"), matfn=(lambda i, j: "Dial" if i >= 3 else "Stainless") if g.hi else None)


def console_kit(g):
    seg = 24 if g.hi else 16
    dash_box(g, 0, 0, 0, (2.36, 0.86, 0.04), M(g, "BlackPlastic"))
    # chartplotter: bezel, glass, chart content (_HP only, baked into the albedo)
    dash_box(g, 0.45, 0.04, 0.04, (0.8, 0.54, 0.09), M(g, "BlackPlastic"))
    dash_box(g, 0.45, 0.05, 0.13, (0.68, 0.42, 0.012), M(g, "Screen"))
    if g.hi:
        for (u, v, w, h) in ((0.3, 0.12, 0.22, 0.14), (0.62, -0.05, 0.16, 0.2), (0.5, 0.18, 0.12, 0.06)):
            dash_box(g, u, v, 0.142, (w, h, 0.004), "ScreenChart")
        dash_box(g, 0.45, -0.02, 0.146, (0.5, 0.008, 0.003), "LensWhite")
        for k in range(5):
            dash_box(g, 0.2 + 0.12 * k, -0.2, 0.09, (0.06, 0.035, 0.012), "Stainless")
    # VHF with handset and two knobs
    dash_box(g, -0.6, 0.2, 0.04, (0.52, 0.22, 0.13), M(g, "BlackPlastic"))
    dash_box(g, -0.62, 0.2, 0.17, (0.26, 0.1, 0.01), M(g, "Screen"))
    for u in (-0.8, -0.42):
        R.lathe(g, on_dash(u, 0.2, 0.17), DASH_N, [(0.035, 0.0), (0.035, 0.035), (0.0, 0.04)], 12, M(g, "BlackPlastic"))
    dash_box(g, -0.98, 0.12, 0.04, (0.14, 0.28, 0.07), M(g, "BlackPlastic"))
    # switch panel with six toggles
    dash_box(g, -0.6, -0.2, 0.04, (0.64, 0.18, 0.02), M(g, "Aluminium"))
    for k in range(6):
        u = -0.85 + 0.1 * k
        R.lathe(g, on_dash(u, -0.2, 0.06), DASH_N, [(0.018, 0.0), (0.012, 0.06), (0.0, 0.065)], 8, M(g, "Stainless"))
    # twin engine gauges
    dial(g, -0.12, 0.18, 0.1, seg)
    dial(g, -0.12, -0.12, 0.1, seg)
    # compass binnacle on the console top
    R.lathe(g, (0, -1.15, 5.1), (0, 0, 1), [(0.24, 0.0), (0.24, 0.06), (0.2, 0.1), (0.2, 0.12), (0.18, 0.2), (0.12, 0.26),
                                          (0.0, 0.28)], 32 if g.hi else 20, M(g, "BlackPlastic"),
            matfn=(lambda i, j: "Acrylic" if i >= 3 else "BlackPlastic") if g.hi else None)
    # wheel: helm pump housing on the aft face, shaft, hub, three spokes, rubber rim
    R.box(g, (0, 0.17, 4.12), (0.38, 0.24, 0.38), M(g, "BlackPlastic"))
    axis = Vector((0, 0.94, 0.34)).normalized()
    hub = Vector((0, 0.5, 4.25))
    R.lathe(g, hub - axis * 0.25, axis, [(0.05, 0.0), (0.05, 0.2), (0.08, 0.22), (0.08, 0.3), (0.0, 0.32)], 16,
            M(g, "Stainless"))
    u = Vector((1, 0, 0))
    w = axis.cross(u).normalized()
    rim_r = 0.52
    n = 48 if g.hi else 32
    rim = [hub + axis * 0.05 + (u * math.cos(2 * math.pi * k / n) + w * math.sin(2 * math.pi * k / n)) * rim_r
           for k in range(n)]
    R.sweep(g, rim + [rim[0]], R.circle_profile(0.045, 16 if g.hi else 10), M(g, "Rubber"), cap0=False, cap1=False)
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 2
        d = u * math.cos(a) + w * math.sin(a)
        R.tube(g, [tuple(hub + axis * 0.06 + d * 0.06), tuple(hub + axis * 0.05 + d * (rim_r - 0.02))], 0.022,
               M(g, "Stainless"), 10, caps=True)
    # twin throttle binnacle (starboard, -X) with levers and knobs; kill cord switch (port)
    R.box(g, (-0.88, 0.2, 4.32), (0.42, 0.3, 0.34), M(g, "BlackPlastic"))
    for x in (-0.96, -0.8):
        R.tube(g, [(x, 0.3, 4.42), (x, 0.42, 4.62), (x, 0.5, 4.86)], 0.024, M(g, "Stainless"), 10, fillet=0.08, fseg=3)
        R.box(g, (x, 0.52, 4.9), (0.1, 0.1, 0.14), M(g, "BlackPlastic"))
    R.box(g, (0.66, 0.1, 4.42), (0.14, 0.1, 0.14), M(g, "BlackPlastic"))
    R.lathe(g, (0.66, 0.15, 4.42), (0, 1, 0), [(0.04, 0.0), (0.04, 0.03), (0.0, 0.035)], 12, M(g, "LensRed"))
    # stainless grab rails: both console sides, the console front (casualty handhold)
    rseg = 20 if g.hi else 14
    for sx in (1, -1):
        x = sx * 1.47
        R.tube(g, [(x, 0.12, 4.0), (x, 0.12, 5.25), (x, -1.0, 5.4), (x, -2.25, 5.25), (x, -2.25, 4.3)], 0.07,
               M(g, "Stainless"), rseg, fillet=0.25, fseg=5)
        for y, z in ((0.12, 4.0), (-2.25, 4.3)):
            R.box(g, (sx * 1.39, y, z), (0.14, 0.2, 0.2), M(g, "Stainless"))
    R.tube(g, [(1.2, -2.42, 3.2), (1.2, -2.62, 3.4), (1.2, -2.62, 4.15), (-1.2, -2.62, 4.15), (-1.2, -2.62, 3.4),
               (-1.2, -2.42, 3.2)], 0.065, M(g, "Stainless"), rseg, fillet=0.2, fseg=5)
    # bolted brackets: rail feet, binnacle, throttle box, kill cord
    for sx in (1, -1):
        bolts(g, [(sx * 1.46, y + dy, z + dz) for y, z in ((0.12, 4.0), (-2.25, 4.3)) for dy in (-0.06, 0.06)
                  for dz in (-0.06, 0.06)], (sx, 0, 0))
    bolts(g, [(0.24 * math.cos(a), -1.15 + 0.24 * math.sin(a), 5.12) for a in (0.5, 2.6, 4.7)], (0, 0, 1))
    bolts(g, [(-0.88 + dx, 0.35, 4.32 + dz) for dx in (-0.15, 0.15) for dz in (-0.12, 0.12)], (0, 1, 0))
    bolts(g, [(0.7 + 0.05 * k, 0.18 - 0.03 * k, 4.24) for k in range(0)], (0, 1, 0))
    for (u, v) in ((0.45 - 0.36, 0.04 - 0.24), (0.45 + 0.36, 0.04 - 0.24), (0.45 - 0.36, 0.04 + 0.24), (0.45 + 0.36, 0.04 + 0.24)):
        bolts(g, [tuple(on_dash(u, v, 0.13))], tuple(DASH_N))
    cables(g)


BOLT = [(0.03, 0.0), (0.03, 0.02), (0.022, 0.028), (0.0, 0.03)]


def bolts(g, pts, axis):
    if g.hi:
        for p in pts:
            R.lathe(g, p, axis, BOLT, 6, "Bolt")


def cables(g):
    """Cable runs from the dash electronics over the console top edge, down the aft face into a gland; VHF coil cord."""
    for k, u in enumerate((0.75, 0.85, 0.95)):
        top = on_dash(u, -0.4, 0.02)
        R.tube(g, [tuple(top), (u, -0.02, 4.58), (u + 0.02, 0.1, 4.4), (u + 0.04, 0.1, 3.7)], 0.018 + 0.004 * k,
               M(g, "Cable"), 8 if g.hi else 5, fillet=0.08, fseg=3)
        R.box(g, (u + 0.04, 0.09, 3.95), (0.07, 0.04, 0.05), M(g, "BlackPlastic"))
    R.box(g, (0.9, 0.09, 3.66), (0.34, 0.06, 0.12), M(g, "BlackPlastic"))
    bolts(g, [(x, 0.13, 3.66) for x in (0.76, 1.04)], (0, 1, 0))
    # VHF handset coil cord (helix) from the radio to the handset clip
    a, b = on_dash(-0.8, 0.1, 0.06), on_dash(-0.98, 0.0, 0.12)
    n = 60 if g.hi else 18
    pts = []
    d = (b - a)
    t1 = d.normalized()
    t2 = t1.cross(DASH_N).normalized()
    for i in range(n + 1):
        t = i / n
        ang = t * 2 * math.pi * 7
        sag = Vector((0, 0.06, -0.12)) * math.sin(math.pi * t)
        pts.append(a + d * t + sag + (t2 * math.cos(ang) + DASH_N * math.sin(ang)) * 0.022)
    R.sweep(g, pts, R.circle_profile(0.007, 6 if g.hi else 4), M(g, "Cable"), cap0=True, cap1=True)


def seat_kit(g):
    """Webbing straps over the saddle cushions with buckles; bolts on the base plates and foot bars."""
    for x, y, bar in SEATS:
        if g.hi:
            for ys in (y - 0.3, y + 0.32):
                prof = [(0.5, 3.96), (0.5, 4.3), (0.47, 4.5), (0.36, 4.62), (0.2, 4.665), (0.0, 4.68)]
                path = [Vector((x - dx, ys, z)) for dx, z in prof] + [Vector((x + dx, ys, z)) for dx, z in reversed(prof[:-1])]
                w = 0.06
                fs = g.rings([[p + Vector((0, -w, 0)) for p in path], [p + Vector((0, w, 0)) for p in path]], "Strap",
                             closed=False, recalc=False)
                g.orient(fs, lambda c, x=x: Vector((c.x - x, 0, c.z - 4.1)))
                R.box(g, (x + 0.505, ys, 4.12), (0.025, 0.14, 0.1), "Stainless")
        bolts(g, [(x + dx, y + dy, D + 0.045) for dx in (-0.45, 0.45) for dy in (-0.7, 0.0, 0.7)], (0, 0, 1))


SEATS = [(0.0, 1.6, False), (1.3, 4.8, True), (-1.3, 4.8, True)]


def seats(g):
    seg = 48 if g.hi else 32
    for x, y, bar in SEATS:
        R.loft(g, [(x, y, D, 0.5, 0.78), (x, y, D + 0.2, 0.48, 0.76), (x, y, 3.7, 0.42, 0.68), (x, y, 3.96, 0.45, 0.73)],
               seg, M(g, "PodGrey"), cap0=False, cap1=True, p=3.4)
        R.loft(g, [(x, y, 3.94, 0.46, 0.75), (x, y, 4.3, 0.48, 0.79), (x, y + 0.03, 4.52, 0.44, 0.75),
                   (x, y + 0.05, 4.61, 0.35, 0.63), (x, y + 0.05, 4.645, 0.2, 0.42)], seg, M(g, "Vinyl"), p=3.0,
               matfn=(lambda i, j: "BlackPlastic" if i == 0 else "Vinyl") if g.hi else None)
        R.loft(g, [(x, y + 0.62, 4.5, 0.36, 0.16), (x, y + 0.64, 4.8, 0.36, 0.16), (x, y + 0.66, 4.9, 0.28, 0.11),
                   (x, y + 0.66, 4.93, 0.12, 0.05)], seg // 2, M(g, "Vinyl"), p=3.0)
        tseg = 16 if g.hi else 12
        R.tube(g, [(x + 0.46, y - 0.3, 2.45), (x + 0.46, y - 0.95, 2.45), (x - 0.46, y - 0.95, 2.45),
                   (x - 0.46, y - 0.3, 2.45)], 0.045, M(g, "Stainless"), tseg, fillet=0.15, fseg=4)
        if bar:
            R.tube(g, [(x + 0.36, y - 0.62, 3.9), (x + 0.38, y - 0.78, 4.55), (x + 0.32, y - 0.86, 4.9),
                       (x - 0.32, y - 0.86, 4.9), (x - 0.38, y - 0.78, 4.55), (x - 0.36, y - 0.62, 3.9)], 0.05,
                   M(g, "Stainless"), tseg, fillet=0.18, fseg=5)
        R.box(g, (x, y, D + 0.02), (1.08, 1.64, 0.04), M(g, "Stainless"))
    seat_kit(g)


def build():
    with open(os.path.join(RIB_DIR, "frame_offset.json")) as f:
        off = Vector(json.load(f)["offset"])
    con = R.build_set("Console", [(NAME + "_Console_LOD0", console_kit)], rbxkit.smart_uv, "MI_RIBHelm_Console")
    sea = R.build_set("Seats", [(NAME + "_Seats_LOD0", seats)], rbxkit.smart_uv, "MI_RIBHelm_Seats")
    hps = [R.build_hp(NAME + "_Console_HP", [console_kit], bevel=dict(width=0.01, segments=2, angle=40)),
           R.build_hp(NAME + "_Seats_HP", [seats], bevel=dict(width=0.01, segments=2, angle=40))]
    att = bpy.data.objects.new("ATT_WheelHub", None)
    att.location = (0, 0.5, 4.25)
    bpy.context.scene.collection.objects.link(att)
    for o in con + sea + hps:
        o.data.transform(Matrix.Translation(off))
    att.location = att.location + off
    meshes = [{"object": o, "set": "Console"} for o in con] + [{"object": o, "set": "Seats"} for o in sea]
    meshes += [{"object": h} for h in hps]
    wear = {"rust": 0.0, "edge": 0.2, "salt": 0.1, "salt_color": (0.6, 0.6, 0.58), "edge_color": (0.56, 0.56, 0.55), "ao_strength": 0.2}   # fix round 3: no white salt blotches
    return {
        "name": NAME,
        "budget": "helm_interior",
        "tris": 15000,
        "tier": "hero",
        "dims_m": (1.2, 2.77, 1.12),
        "origin": "free",
        "sets": [{"name": TEX, "set": "Console", "size": 2048, "wet": True, "wet_darken": 0.35, "wet_gloss": 0.45, "wet_streaks": 0.35, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": wear},
                 {"name": TEX, "set": "Seats", "size": 1024, "wet": True, "wet_darken": 0.35, "wet_gloss": 0.5, "wet_streaks": 0.35, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(wear, edge=0.2, ao_strength=0.12),
                  "slots": {"Stainless": {"base_color": "#DCDFE0"}}}],
        "meshes": meshes,
        "attachments": [att],
        "bake_samples": 16,
        "waivers": {"geometry": "Console LOD0: one zero-area sliver (collinear verts left by a clamped chamfer on a 12 mm "
                                "dash part); not visible, no loose verts; the open edges are the dash cards"},
    }
