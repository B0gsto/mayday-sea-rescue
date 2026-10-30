"""M_Prop_TrophyCup: the Lego trophy cup on the Lv1 Trophy Hall's roof (replaces the code gold ball; AD int1 5/10).

A two-tier navy base with a red band, corner studs and a gold name plate, a flared gold foot, a stem with a knot, a
deep bowl with a thick lip and two big ear handles, a red star on the front. Origin the base's bottom centre, front -Y
(the hall's door side), 7.6 wide over the handles, 7.0 tall. DockPieces.smallHall stands it on the hall's lintel.

    python3 art/source/props/M_Prop_TrophyCup/maketex.py --out build/prod/M_Prop_TrophyCup/textures/M_Prop_TrophyCup
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_TrophyCup/build.py \
        --out-root build/prod/M_Prop_TrophyCup --steps build,lod,validate,export,turntable
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Prop_TrophyCup"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "TrophyCup", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_TrophyCup_Brick_ALB.png")
N = 32
BOWL = ((3.35, 0.5), (3.6, 1.15), (4.1, 1.75), (4.8, 2.15), (5.6, 2.35), (6.55, 2.45))   # (z, r)
HANDLE = ((2.2, 6.15), (3.15, 6.3), (3.75, 5.8), (3.8, 4.9), (3.35, 4.15), (2.5, 3.8), (1.3, 3.7))  # (x, z)


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def ring(z, r, n=N):
    return [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z) for i in range(n)]


def base(b):
    b.box((-2.0, -2.0, 0), (2.0, 2.0, 1.0), P.INK, bevel=0.15)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(sx * 1.6, sy * 1.6, 0.97, 1.3, 0.26, P.INK, 12)
    b.box((-1.3, -2.08, 0.25), (1.3, -1.9, 0.75), P.YELLOW, bevel=0.04)          # the name plate
    b.box((-1.5, -1.5, 0.97), (1.5, 1.5, 1.95), P.INK, bevel=0.12)
    b.box((-1.53, -1.53, 1.3), (1.53, 1.53, 1.5), P.RED, bevel=0.0)


def cup(b):
    b.loft([ring(1.92, 1.35), ring(2.45, 0.55)], P.YELLOW)                          # the flared foot
    b.cyl(0, 0, 2.4, 3.45, 0.42, P.YELLOW, 16)
    b.cyl(0, 0, 2.75, 3.1, 0.75, P.YELLOW, 20)                                      # the knot
    b.loft([ring(z, r) for z, r in BOWL], P.YELLOW)
    b.cyl(0, 0, 6.45, 6.9, 2.62, P.YELLOW, N)                                       # the lip
    b.cyl(0, 0, 6.85, 6.97, 2.25, P.ORANGE, N)                                      # the shadowed inside
    for s in (-1, 1):                                                               # ear handles
        pts = [(s * x, 0, z) for x, z in HANDLE]
        for p0, p1 in zip(pts, pts[1:]):
            b.beam(p0, p1, 0.55, 0.55, P.YELLOW)
        for x, y, z in pts[1:-1]:
            b.box((x - 0.29, -0.29, z - 0.29), (x + 0.29, 0.29, z + 0.29), P.YELLOW, bevel=0.08)
    # a red star sticker on the bowl's front (-Y)
    cz, ro, ri = 4.95, 0.75, 0.32
    star = [((ro if i % 2 == 0 else ri) * math.sin(math.pi * i / 5), (ro if i % 2 == 0 else ri) * math.cos(math.pi * i / 5))
            for i in range(10)]
    verts = [(x, -2.32, cz + z) for x, z in star] + [(x, -1.95, cz + z) for x, z in star]
    faces = [tuple(range(10)), tuple(reversed(range(10, 20)))] + [(i, (i + 1) % 10, 10 + (i + 1) % 10, 10 + i)
                                                                  for i in range(10)]
    b._emit(verts, faces, P.RED)


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_TrophyCup_Brick", ALB)
    meshes = []
    for name, fn in (("L01_Base", base), ("L02_Cup", cup)):
        b = lego.B()
        fn(b)
        meshes.append({"object": b.to_object(name, mat), "set": SET, "role": "visual", "lod": "LOD0"})
        print("[cup] %-10s %5d tris" % (name, b.tris()))
    pts = [e["object"].matrix_world @ v.co for e in meshes for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[cup] bbox %s..%s dims_m %s" % ([round(v, 2) for v in lo], [round(v, 2) for v in hi], dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "base", "tiling": True,
        "size_note": "stylised Lego trophy cup, sized to crown the 21-stud Lv1 hall",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Base, L02_Cup: DockPieces places the Model as one piece",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "closeups": [
            {"name": "front", "target": [0, 0, 4], "dist": 14, "az": -20, "el": 10},
            {"name": "handle", "target": [3, 0, 5], "dist": 9, "az": -60, "el": 15},
        ],
    }
