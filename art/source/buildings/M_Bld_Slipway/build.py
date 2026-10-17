"""H1 M_Bld_Slipway: the Port Haven station slipway (docs/12 2.2 row; map/Build.luau StationSlipway).

Concrete ramp 6.67 m (20 studs) wide between 0.33 m kerbs, 22 m run x 3.33 m drop (1:6.6, the greybox gradient; RNLI
slipways run about 1:5 to 1:7), dry B02 Concrete above the tide line and B02 WeedyConcrete below it (from 0.4 m above
sea level), twin steel launch rails on sole plates, steel kerb nosings, a flat head apron, bollards, the winch (drum,
frame, wire and hook block) and the block-built winch house with a corrugated steel mono-pitch roof.

Pivot (origin "free") = top centre of the ramp at the quay edge; the ramp runs down towards -Y (front). Greybox
placement: pivot at world (-165, 4, 4) yawed 180 degrees, so the ramp runs down to +Z (the sea).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_Slipway --steps build,validate,export,turntable
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "M_Bld_Station"))
import geo  # noqa: E402
from geo import Part  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Slipway"
RUN, DROP = 22.0, 10.0 / 3.0
K = DROP / RUN
HW = 10.0 / 3.0            # half width of the ramp
KW, KH = 0.33, 0.2         # kerbs
SPLIT = -6.0               # weed line (0.4 m above sea level)
TOE = -23.0
CON = ("tile", 2.5)
WEED = ("tile", 3.0)
STEEL = ("tile", 4.0 / 3.0)


def z(y):
    return y * K if y < 0 else 0.0


def build():
    con, weed, st = Part("Ramp"), Part("Weedy"), Part("Steel")
    geo.LEVEL = 3
    # slabs: dry upper with the head apron, weedy lower to the toe
    con.prism([(3.0, 0.0), (0.0, 0.0), (SPLIT, z(SPLIT)), (SPLIT, -4.0), (3.0, -4.0)], "x", -HW, HW, CON)
    weed.prism([(SPLIT, z(SPLIT)), (TOE, z(TOE)), (TOE, -4.5), (SPLIT, -4.5)], "x", -HW, HW, WEED)
    for x0, x1 in ((-HW - KW, -HW), (HW, HW + KW)):
        con.prism([(3.0, KH), (0.0, KH), (SPLIT, z(SPLIT) + KH), (SPLIT, -4.0), (3.0, -4.0)], "x", x0, x1, CON)
        weed.prism([(SPLIT, z(SPLIT) + KH), (TOE, z(TOE) + KH), (TOE, -4.5), (SPLIT, -4.5)], "x", x0, x1, WEED)
    # winch house: block walls (concrete), corrugated steel mono-pitch roof, steel door
    con.box((-1.5, 4.0, 0.0), (1.5, 7.0, 2.6), CON, skip=("-z",))
    st.prism([(3.8, 2.55), (7.2, 3.05), (7.2, 3.12), (3.8, 2.62)], "x", -1.7, 1.7, STEEL)
    geo.LEVEL = 1
    xr = -1.6
    while xr < 1.6:
        st.prism([(3.8, 2.62), (7.2, 3.12), (7.2, 3.16), (3.8, 2.66)], "x", xr, xr + 0.05, STEEL, caps=False)
        xr += 0.19
    geo.LEVEL = 3
    st.box((0.35, 3.96, 0.05), (1.25, 4.0, 2.05), STEEL)
    geo.LEVEL = 2
    st.box((1.1, 3.93, 1.0), (1.18, 3.96, 1.12), STEEL)
    # launch rails: head, web and sole plate along the slope, steel sole plates every 1.5 m
    geo.LEVEL = 3
    for xr in (-0.75, 0.75):
        st.prism([(0.6, 0.13), (0.6, 0.0), (TOE, z(TOE)), (TOE, z(TOE) + 0.13)], "x", xr - 0.035, xr + 0.035, STEEL)
        geo.LEVEL = 2
        st.prism([(0.6, 0.03), (0.6, -0.01), (TOE, z(TOE) - 0.01), (TOE, z(TOE) + 0.03)], "x", xr - 0.1, xr + 0.1, STEEL)
        y = 0.0
        while y > TOE + 0.5:
            st.box((xr - 0.2, y - 0.1, z(y) - 0.05), (xr + 0.2, y + 0.1, z(y) + 0.035), STEEL)
            geo.LEVEL = 1
            for xb in (xr - 0.15, xr + 0.15):
                st.box((xb - 0.02, y - 0.02, z(y) + 0.035), (xb + 0.02, y + 0.02, z(y) + 0.06), STEEL)
            geo.LEVEL = 2
            y -= 1.5
        geo.LEVEL = 3
    # kerb nosings (steel angle on the inner top edge)
    geo.LEVEL = 2
    for x0, x1 in ((-HW - 0.02, -HW + 0.04), (HW - 0.04, HW + 0.02)):
        st.prism([(0.0, KH + 0.01), (TOE, z(TOE) + KH + 0.01), (TOE, z(TOE) + KH - 0.08), (0.0, KH - 0.08)], "x", x0, x1, STEEL)
    # winch: drum, side frames, motor box, wire to a hook block on the ramp; bollards on the apron
    st.tube((-0.65, 2.8, 0.6), (0.65, 2.8, 0.6), 0.3, 12, STEEL)
    for xf in (-0.75, 0.75):
        st.box((xf - 0.05, 2.4, 0.0), (xf + 0.05, 3.2, 0.95), STEEL)
    st.box((0.8, 2.45, 0.0), (1.4, 3.15, 0.7), STEEL)
    st.tube((0.0, 2.55, 0.33), (0.0, 0.2, 0.06), 0.014, 6, STEEL, caps=False)
    st.tube((0.0, 0.2, 0.06), (0.0, -3.0, z(-3.0) + 0.06), 0.014, 6, STEEL, caps=False)
    st.box((-0.1, -3.3, z(-3.3) + 0.0), (0.1, -3.0, z(-3.0) + 0.2), STEEL)
    for xb in (-2.9, 2.9):
        st.tube((xb, 2.0, 0.0), (xb, 2.0, 0.55), 0.13, 10, STEEL)
        st.tube((xb, 2.0, 0.55), (xb, 2.0, 0.62), 0.17, 10, STEEL)

    mats = {"Ramp": ("Concrete", geo.material("MI_Slipway_Concrete", (0.35, 0.34, 0.32), 0.9)),
            "Weedy": ("WeedyConcrete", geo.material("MI_Slipway_Weedy", (0.2, 0.22, 0.17), 0.8)),
            "Steel": ("Steel", geo.material("MI_Slipway_Steel", (0.5, 0.5, 0.5), 0.5, 1.0))}
    meshes = []
    for p in (con, weed, st):
        s, mat = mats[p.name]
        for li, lod in ((0, "LOD0"), (1, "LOD1"), (2, "LOD2")):
            meshes.append({"object": p.to_object("%s_%s_%s" % (NAME, p.name, lod), mat, lod=li), "set": s})
        print("[H1] %s %d tris" % (p.name, p.tris()))
    col = Part("COL")
    col.prism([(7.0, 0.0), (0.0, 0.0), (TOE, z(TOE)), (TOE, -4.5), (7.0, -4.5)], "x", -HW - KW, HW + KW, CON)
    col.box((-1.5, 4.0, 0.0), (1.5, 7.0, 3.1), CON)
    colobj = col.to_object(NAME + "_COL", None, weld=False)
    atts = {"ATT_SlipwayTop": (0, 0, 0), "ATT_SlipwayBottom": (0, -RUN, -DROP), "ATT_WaterLine": (0, -1.333 / K, -1.333),
            "ATT_WeedLine": (0, SPLIT, z(SPLIT)), "ATT_Winch": (0, 2.8, 0.6), "ATT_WinchHouseDoor": (0.8, 3.5, 0)}
    objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = Vector(p) * 3.0
        bpy.context.scene.collection.objects.link(e)
        objs.append(e)
    tex = G + "assets/textures/"
    return {
        "name": NAME, "budget": "large_prop", "tris": 8000, "tier": "hero",
        "dims_m": (2 * (HW + KW), None, None), "origin": "free", "tiling": True,
        "sets": [{"name": "Mat", "set": "Concrete", "size": 1024, "wet": True, "dir": tex + "Materials"},
                 {"name": "Mat", "set": "WeedyConcrete", "size": 1024, "wet": True, "dir": tex + "Materials"},
                 {"name": "Slipway", "set": "Steel", "size": 1024, "wet": True}],
        "waivers": {"texture sets": "docs/12 row: concrete and weedy-concrete are the shared B02 library sets (no new texture budget) + 1 own set (Steel)",
                    "LOD UV layout": "world-scale tiling UVs; hand-made LODs drop small parts"},
        "meshes": meshes + [{"object": colobj}],
        "attachments": objs,
        "closeups": [
            {"name": "rails_weed_line", "target": [0, SPLIT * 3, z(SPLIT) * 3], "dist": 10, "az": 30, "el": 25},
            {"name": "winch_house", "target": [0, 4.5 * 3, 4.0], "dist": 16, "az": 200, "el": 15},
            {"name": "head_winch_rails", "target": [0, 1.0 * 3, 1.5], "dist": 9, "az": 150, "el": 30},
        ],
    }
