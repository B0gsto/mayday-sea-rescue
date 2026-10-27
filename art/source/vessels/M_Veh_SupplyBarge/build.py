"""M_Veh_SupplyBarge: the Lego freight barge that feeds the Depot's freight quay (docs/25 D, docs/05 2.2/4/5).

A chunky flat-deck barge: red lower hull at the waterline, blue flared topsides, tan studded deck tiles, white gunwales
with studs, orange hung fender pads, four blue-capped bollards, a white stern wheelhouse with tall glass, a blue studded
roof and red funnel, and three separate cargo meshes (Crate_1..Crate_3) that the game can unload one at a time.
Shared flat palette set with M_Bld_Depot (lego.py / palette.py are reused from art/source/buildings/M_Bld_Depot).

Blender axes: X beam, Y length (bow -Y = Roblox -Z), Z up. Pivot: centre at the waterline (z = 0), midships. Hull
bottom -1.2 studs (0.4 m draft), wheelhouse roof 8.0, funnel top 9.0, bow mast lamp 6.55. Bbox x 15.6 (fender pads), y 36.3 (rudder), z 10.2 studs (incl. draft).

    python3 art/source/vessels/M_Veh_SupplyBarge/maketex.py --out build/prod/M_Veh_SupplyBarge/textures/M_Veh_SupplyBarge \
        --name Barge --set Hull
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/vessels/M_Veh_SupplyBarge/build.py \
        --out-root build/prod/M_Veh_SupplyBarge --steps build,lod,validate,export,turntable
"""
import os
import re
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(HERE, "../../buildings/M_Bld_Depot"))
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Veh_SupplyBarge"
BUDGET = "small_craft"
TIER = "standard"
SET_NAME, SET = "Barge", "Hull"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_Barge_Hull_ALB.png")
DECK = 2.0          # hull deck line (wheelhouse, crates and fittings sit on the tiled deck at 2.35)


def patch_lod_names():
    """Crate_1..3 keep their gameplay names (not M_<Cat>_ names), so keep the lod step working on them."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def hull_sections():
    """(y, half-beam deck, half-beam chine, z deck, half-beam keel, z keel): waterline chine, raked blunt bow."""
    return [
        (18.0, 6.6, 6.0, 2.00, 5.8, -1.20),
        (15.0, 7.1, 6.5, 2.00, 6.2, -1.20),
        (8.0, 7.2, 6.6, 2.00, 6.3, -1.20),
        (0.0, 7.2, 6.6, 2.00, 6.3, -1.20),
        (-8.0, 7.2, 6.6, 2.00, 6.3, -1.20),
        (-12.0, 7.0, 6.3, 2.10, 6.0, -1.15),
        (-15.0, 6.2, 5.4, 2.25, 5.1, -0.95),
        (-17.0, 4.8, 3.9, 2.50, 3.6, -0.60),
        (-17.8, 3.2, 2.6, 2.65, 2.4, -0.25),
    ]


def cargo(b, x, y, z, size, h, colour):
    """One unloadable brick crate: body, two bands, lid plate, two corner posts, ten studs."""
    x0, y0 = x - size / 2, y - size / 2
    x1, y1 = x + size / 2, y + size / 2
    b.box((x0, y0, z), (x1, y1, z + h), colour)
    for dz in (0.3, h - 0.5):
        b.box((x0 - 0.06, y0 - 0.06, z + dz), (x1 + 0.06, y1 + 0.06, z + dz + 0.22), P.BROWN)
    b.box((x0 + 0.12, y0 + 0.12, z + h), (x1 - 0.12, y1 - 0.12, z + h + 0.22), colour)
    for ix in (-0.33, -0.11, 0.11, 0.33):
        for iy in (-0.17, 0.17):
            b.cyl(x + size * ix, y + size * iy, z + h + 0.22, z + h + 0.6, 0.1 * size, colour, 8)


def build():
    patch_lod_names()
    mat = lego.material("MI_Barge_Hull", ALB)
    meshes = []
    secs = hull_sections()

    # ---------------------------------------------------------------- hull, deck and gunwales (one mesh)
    b = lego.B()
    lower = [[(-c, y, 0.0), (-k, y, zk), (k, y, zk), (c, y, 0.0)] for y, d, c, zd, k, zk in secs]
    upper = [[(-d, y, zd), (-c, y, 0.0), (c, y, 0.0), (d, y, zd)] for y, d, c, zd, k, zk in secs]
    b.loft(lower, P.RED)
    b.loft(upper, P.BLUE)
    b.box((-6.6, -14.6, DECK), (6.6, 17.1, DECK + 0.15), P.BROWN)             # deck base (seams)
    for ix in range(4):
        for iy in range(8):
            b.box((-6.55 + ix * 3.3, -14.55 + iy * 3.98, DECK + 0.15),
                  (-6.55 + ix * 3.3 + 3.1, -14.55 + iy * 3.98 + 3.78, DECK + 0.35), P.TAN)
            for sx in (0.25, 0.75):                                           # 2 x 2 studs on every deck tile
                for sy in (0.25, 0.75):
                    b.cyl(-6.55 + ix * 3.3 + 3.1 * sx, -14.55 + iy * 3.98 + 3.78 * sy, DECK + 0.35, DECK + 0.65,
                          0.5, P.TAN, 8)
    for sx in (-1, 1):
        b.box((sx * 6.55, -17.3, DECK), (sx * 7.25, 17.6, DECK + 0.5), P.WHITE)   # sheer rail
        b.stud_row(sx * 6.9, -16.6, sx * 6.9, 16.9, DECK + 0.5, P.WHITE, spacing=4.2, r=0.5, h=0.32)
    # ---------------------------------------------------------------- fenders, bollards, ropes, mast, rudder
    for sx in (-1, 1):
        for y in (-10.0, 0.0, 10.0):                                           # hung fender pads, tied to the rail
            b.box((sx * 7.0, y - 1.5, 0.95), (sx * 7.8, y + 1.5, 2.25), P.ORANGE)
            for dy in (-0.9, 0.9):                                             # rope straps over the pad and the rail
                b.box((sx * 6.9, y + dy - 0.14, 0.95), (sx * 7.9, y + dy + 0.14, 2.6), P.WHITE)
        for y in (-14.0, 6.5):                                                 # bollards on the rail, clear of the studs
            b.cyl(sx * 6.9, y, DECK + 0.5, DECK + 1.5, 0.4, P.DBG, 8)
            b.cyl(sx * 6.9, y, DECK + 1.5, DECK + 1.8, 0.58, P.BLUE, 8)
    b.cyl(0.0, -12.6, DECK + 0.35, 5.9, 0.28, P.WHITE, 8)                      # bow mast
    b.box((-0.5, -12.9, 5.6), (0.5, -12.3, 6.2), P.WARM)
    b.cyl(0.0, -12.6, 6.2, 6.55, 0.55, P.WARM, 8)
    b.box((-0.45, 17.85, -1.1), (0.45, 18.55, 1.1), P.DBG)                     # rudder
    b.torus(5.18, 12.6, 3.5, 0.75, 0.25, P.RED, maj=8, mnr=4)                  # life ring on the cabin side
    for dz in (-0.7, 0.7):
        b.box((5.02, 12.2, 3.5 + dz), (5.34, 13.0, 3.6 if dz > 0 else 3.4), P.WHITE)
    out_hull = b.to_object("M_Veh_SupplyBarge_Hull", mat)       # fittings share the hull mesh: LOD2 cannot collapse 40 small shells
    meshes.append({"object": out_hull, "set": SET, "role": "visual", "lod": "LOD0"})
    print("[barge] hull + fittings %d tris" % b.tris())

    # ---------------------------------------------------------------- wheelhouse (white cabin, blue studded roof)
    b = lego.B()
    b.box((-5.0, 9.0, DECK + 0.35), (5.0, 16.0, 7.5), P.WHITE)                 # cabin
    b.box((-5.4, 8.6, 7.5), (5.4, 16.4, 8.0), P.BLUE)                          # roof
    for xx in (-4.35, 1.45):                                                   # front glass, split by the door
        b.box((xx, 8.93, 4.55), (xx + 2.9, 9.03, 6.85), P.INK)
        b.box((xx + 0.15, 8.9, 4.7), (xx + 2.75, 9.05, 6.7), P.GLASS)
    for sx in (-1, 1):                                                         # side glass, two panes
        b.box((sx * 5.03 - 0.04, 10.45, 4.55), (sx * 5.03 + 0.04, 14.55, 6.85), P.INK)
        b.box((sx * 5.03 - 0.06, 10.6, 4.7), (sx * 5.03 + 0.06, 12.35, 6.7), P.GLASS)
        b.box((sx * 5.03 - 0.06, 12.65, 4.7), (sx * 5.03 + 0.06, 14.4, 6.7), P.GLASS)
        b.box((sx * 5.03 - 0.07, 12.35, 4.55), (sx * 5.03 + 0.07, 12.65, 6.85), P.INK)
    b.box((-1.25, 8.88, DECK + 0.35), (1.25, 9.02, 6.85), P.INK)               # door
    b.box((-1.0, 8.87, 5.1), (1.0, 8.9, 6.4), P.GLASS)                         # door window
    for xx in (-3.85, 0.3):                                                    # stern windows
        b.box((xx, 15.98, 4.55), (xx + 3.2, 16.06, 6.85), P.INK)
        b.box((xx + 0.15, 15.96, 4.7), (xx + 3.05, 16.07, 6.7), P.GLASS)
    for y in (15.6, 12.5, 9.4):
        b.stud_row(-4.3, y, 4.3, y, 8.0, P.BLUE, spacing=1.25, r=0.42, h=0.3)
    b.cyl(3.6, 14.6, 8.0, 8.8, 0.55, P.RED, 8)                                 # funnel
    b.cyl(3.6, 14.6, 8.8, 9.0, 0.64, P.BLACK, 8)
    out_wh = b.to_object("M_Veh_SupplyBarge_Wheelhouse", mat)
    meshes.append({"object": out_wh, "set": SET, "role": "visual", "lod": "LOD0"})
    print("[barge] wheelhouse %d tris" % b.tris())

    # ---------------------------------------------------------------- cargo (three separate unloadable meshes)
    for i, (x, y, size, h, col) in enumerate((
        (-2.6, -7.5, 5.0, 3.5, P.YELLOW),
        (2.7, -1.0, 5.0, 3.5, P.BLUE),
        (-2.7, 4.8, 5.0, 3.5, P.ORANGE),
    ), 1):
        b = lego.B()
        cargo(b, x, y, DECK + 0.35, size, h, col)
        obj = b.to_object("Crate_%d" % i, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        print("[barge] Crate_%d %d tris" % (i, b.tris()))

    # ---------------------------------------------------------------- collision proxy
    col = lego.B()
    col.box((-7.2, -17.6, -1.2), (7.2, 18.2, DECK + 0.35), P.BLUE)
    col.box((-5.0, 9.0, DECK + 0.35), (5.0, 16.0, 8.0), P.WHITE)
    for x, y, size in ((-2.6, -7.5, 5.0), (2.7, -1.0, 5.0), (-2.7, 4.8, 5.0)):
        col.box((x - size / 2, y - size / 2, DECK + 0.35), (x + size / 2, y + size / 2, DECK + 4.45), P.YELLOW)
    col_obj = col.to_object("M_Veh_SupplyBarge_COL", mat)

    for name, loc in (("ATT_Waterline", (0.0, 0.0, 0.0)), ("ATT_Bow", (0.0, -16.0, 0.8)),
                      ("ATT_Stern", (0.0, 16.8, 0.8)), ("ATT_Helm", (0.0, 12.5, 4.0))):
        lego.attach(name, loc)

    total = sum(sum(len(p.vertices) - 2 for p in e["object"].data.polygons) for e in meshes)
    print("[barge] LOD0 %d tris in %d meshes" % (total, len(meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": (5.33, 12.0, 3.4), "origin": "free", "tiling": True,
        "size_note": "pivot at the waterline (z 0) and midships; bow -Y; bbox includes the fender pads and rudder",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "cargo meshes keep their gameplay names Crate_1..3 (docs/25 D) so the game can unload them",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes + [{"object": col_obj, "role": "col"}],
        "closeups": [
            {"name": "cargo_deck", "target": [0.0, -4.0, 4.4], "dist": 17, "az": 34, "el": 24},
            {"name": "wheelhouse", "target": [0.5, 12.5, 5.4], "dist": 15, "az": 20, "el": 16},
            {"name": "fenders", "target": [0.0, 0.0, 1.3], "dist": 20, "az": 88, "el": 8},
            {"name": "bow", "target": [0.0, -13.0, 2.6], "dist": 15, "az": 12, "el": 18},
        ],
    }
