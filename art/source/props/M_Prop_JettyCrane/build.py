"""M_Prop_JettyCrane: the Harbour Lv3 dockside crane, Lego style (replaces the code-built DockPieces.slipCrane Parts:
white pole, flat navy boom, dangling hook; owner 2026-10-29: "it looks cheap, needs to be redone via Blender").

Same envelope as the Parts crane: origin the mast's ground centre (the red base brick stands on the jetty deck), jib
axis 23.5 studs up, jib reaching 39.4 studs toward the berth along -Y (Blender front = Roblox -Z: the game turns the
Model with CFrame.lookAt toward the tip), counter-jib 5 behind, hook block hanging 9 below the tip. Decoration only:
nothing animates it (the "crane" the gameplay mentions is the Harbour Lv3 unlock).

White lattice tower with red cross braces on a red studded base, a slewing deck with a red operator cab (navy
windscreen), a yellow-studded jib truss with two black pendants from a red-beaconed A-frame, grey counterweight
bricks, a red trolley, a fall line to a yellow hook block with a life ring (red / white segments) hanging on it.

Layers: L01_Base, L02_Tower, L03_Jib, L04_Hook; collision = base + tower core boxes (_COL).

    python3 art/source/props/M_Prop_JettyCrane/maketex.py --out build/prod/M_Prop_JettyCrane/textures/M_Prop_JettyCrane
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_JettyCrane/build.py \
        --out-root build/prod/M_Prop_JettyCrane --steps build,lod,validate,export,turntable
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

NAME = "M_Prop_JettyCrane"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "JettyCrane", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_JettyCrane_Brick_ALB.png")

SINK = 0.04
BASE_W, BASE_H = 6.2, 1.4
HW = 1.5                     # tower post offset (posts at +-HW)
TOWER_Z0, TOWER_Z1 = BASE_H, 21.6
JIB_Z = 23.5                 # jib axis height (the Parts crane's boom)
JIB_L = 39.4                 # reach toward -Y
COUNTER = 5.0                # counter-jib length toward +Y
HOOK_Z = 14.0                # hook block centre (the Parts crane's hook)


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def stud(b, x, y, z, c, r=0.6, h=0.4, n=10):
    b.cyl(x, y, z - SINK, z + h, r, c, n)


# ------------------------------------------------------------------ layers
def base(b):
    b.box((-BASE_W / 2, -BASE_W / 2, 0), (BASE_W / 2, BASE_W / 2, BASE_H), P.RED, bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            stud(b, sx * 2.35, sy * 2.35, BASE_H, P.RED, 0.55, 0.4)
    for sx in (-1, 1):                                  # hazard feet strips on the front / back faces
        b.box((sx * 1.8 - 0.6, -BASE_W / 2 - 0.04, 0.3), (sx * 1.8 + 0.6, -BASE_W / 2 + 0.04, 1.1), P.YELLOW, bevel=0)
    for sy in (-1, 1):
        b.box((-0.5, sy * BASE_W / 2 - 0.04, 0.3), (0.5, sy * BASE_W / 2 + 0.04, 1.1), P.YELLOW, bevel=0)


def tower(b):
    zs = [TOWER_Z0 + (TOWER_Z1 - TOWER_Z0) * i / 5 for i in range(6)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * HW - 0.42, sy * HW - 0.42, TOWER_Z0 - SINK), (sx * HW + 0.42, sy * HW + 0.42, TOWER_Z1),
                  P.WHITE, bevel=0.05)
    for z in zs:                                         # square frames at each level
        for sy in (-1, 1):
            b.box((-HW, sy * HW - 0.26, z - 0.26), (HW, sy * HW + 0.26, z + 0.26), P.WHITE, bevel=0.03)
        for sx in (-1, 1):
            b.box((sx * HW - 0.26, -HW, z - 0.26), (sx * HW + 0.26, HW, z + 0.26), P.WHITE, bevel=0.03)
    for i in range(5):                                   # red X braces on the four faces
        a, e = zs[i], zs[i + 1]
        for s in (-1, 1):
            b.beam((-HW, s * HW, a), (HW, s * HW, e), 0.36, 0.36, P.RED)
            b.beam((HW, s * HW, a), (-HW, s * HW, e), 0.36, 0.36, P.RED)
            b.beam((s * HW, -HW, a), (s * HW, HW, e), 0.36, 0.36, P.RED)
            b.beam((s * HW, HW, a), (s * HW, -HW, e), 0.36, 0.36, P.RED)
    # slewing deck, cab, A-frame
    b.cyl(0, 0, TOWER_Z1 - SINK, 22.5, 3.0, P.DBG, 14)
    b.box((-2.8, -2.8, 22.5 - SINK), (2.8, 2.8, 22.9), P.ORANGE, bevel=0.08)                 # deck plate
    b.box((-3.8, -2.4, 22.9 - SINK), (-1.0, 1.8, 26.3), P.RED, bevel=0.12)                    # cab
    b.box((-3.84, -2.0, 24.0), (-3.7, 1.4, 25.8), P.INK, bevel=0.0)                            # side window
    b.box((-3.6, -2.44, 24.0), (-1.2, -2.3, 25.8), P.INK, bevel=0.0)                           # windscreen (front)
    for y in (-1.0, 0.5):
        stud(b, -2.4, y, 26.3, P.RED, 0.5, 0.35, 8)
    apex = (0, 0.4, 32.0)
    for sx in (-1, 1):
        b.beam((sx * 1.2, 0.0, 22.9), apex, 0.5, 0.5, P.WHITE)
        b.beam((sx * 1.2, 1.4, 22.9), apex, 0.5, 0.5, P.WHITE)
    b.box((-0.5, -0.1, 31.9), (0.5, 0.9, 32.7), P.RED, bevel=0.06)                          # beacon
    b.beam((0.0, 0.4, 31.8), (0, -13.0, JIB_Z + 0.8), 0.26, 0.26, P.BLACK)                      # pendants
    b.beam((0.0, 0.4, 31.8), (0, -29.0, JIB_Z + 0.8), 0.26, 0.26, P.BLACK)
    b.beam((0.0, 0.4, 31.8), (0, COUNTER - 0.4, JIB_Z + 0.8), 0.26, 0.26, P.BLACK)


def jib(b):
    zt, zb = JIB_Z + 0.8, JIB_Z - 0.8
    L = JIB_L
    b.box((-0.7, -L, zt - 0.4), (0.7, 0.4, zt + 0.4), P.YELLOW, bevel=0.08)                    # top chord
    for sx in (-1, 1):
        b.box((sx * 1.1 - 0.3, -L, zb - 0.3), (sx * 1.1 + 0.3, 0.4, zb + 0.3), P.WHITE, bevel=0.04)  # lower chords
    n = 14
    for i in range(n):
        y0, y1 = -0.2 - i * (L - 0.6) / n, -0.2 - (i + 1) * (L - 0.6) / n
        for sx in (-1, 1):
            up = i % 2 == 0
            b.beam((sx * 1.1, y0, zb if up else zt), (0, y1, zt if up else zb), 0.36, 0.36, P.RED)
        b.box((-1.1, y0 - 0.15, zb - 0.2), (1.1, y0 + 0.15, zb + 0.2), P.WHITE, bevel=0.03)    # cross ties
    for i in range(15):                                                                        # studs along the top
        stud(b, 0, -0.9 - i * 2.6, zt + 0.4, P.YELLOW, 0.48, 0.34, 8)
    # counter-jib + weights
    b.box((-0.7, 0.0, zt - 0.4), (0.7, COUNTER, zt + 0.4), P.YELLOW, bevel=0.08)
    for sx in (-1, 1):
        b.box((sx * 1.1 - 0.3, 0.0, zb - 0.3), (sx * 1.1 + 0.3, COUNTER, zb + 0.3), P.WHITE, bevel=0.04)
    b.box((-2.0, 1.8, zb - 0.4), (2.0, COUNTER + 0.6, zb + 1.3), P.DBG, bevel=0.1)
    b.box((-2.0, 1.8, zb + 1.3 - SINK), (2.0, COUNTER + 0.6, zb + 2.4), P.DBG, bevel=0.1)
    for sx in (-1, 1):
        stud(b, sx * 0.85, COUNTER - 0.9, zb + 2.4, P.DBG, 0.5, 0.35)
        stud(b, sx * 0.85, 3.2, zb + 2.4, P.DBG, 0.5, 0.35)
    # trolley at the tip
    b.box((-1.2, -L - 0.6, zb - 1.0), (1.2, -L + 0.6, zb + 0.3), P.RED, bevel=0.06)


def hook(b):
    zb = JIB_Z - 0.8
    y = -JIB_L
    b.box((-0.12, y - 0.12, HOOK_Z + 0.8), (0.12, y + 0.12, zb - 0.9), P.BLACK, bevel=0.0)    # fall line
    b.box((-0.8, y - 0.6, HOOK_Z), (0.8, y + 0.6, HOOK_Z + 1.2), P.YELLOW, bevel=0.06)        # hook block
    b.box((-0.82, y - 0.62, HOOK_Z + 0.45), (0.82, y + 0.62, HOOK_Z + 0.75), P.RED, bevel=0.03)
    b.box((-0.12, y - 0.12, HOOK_Z - 0.7), (0.12, y + 0.12, HOOK_Z), P.DBG, bevel=0.0)          # shank
    b.box((-0.12, y - 0.55, HOOK_Z - 1.0), (0.12, y + 0.12, HOOK_Z - 0.7), P.DBG, bevel=0.0)    # hook bend
    b.box((-0.12, y - 0.55, HOOK_Z - 0.7), (0.12, y - 0.3, HOOK_Z - 0.2), P.DBG, bevel=0.0)
    # life ring hanging on the hook: 8 chunky segments, red / white, ring in the y-z plane... facing the jib axis (x)
    cy, cz, R = y - 0.2, HOOK_Z - 3.6, 2.4
    n = 8
    pts = [(cy + R * math.cos(2 * math.pi * (i + 0.5) / n), cz + R * math.sin(2 * math.pi * (i + 0.5) / n))
           for i in range(n + 1)]
    for i in range(n):
        a, e = pts[i], pts[i + 1]
        b.beam((0, a[0], a[1]), (0, e[0], e[1]), 1.2, 1.2, P.RED if i % 2 == 0 else P.WHITE)
    b.beam((-0.04, cy - 0.5, cz + R), (-0.04, y - 0.5, HOOK_Z - 0.9), 0.16, 0.16, P.BLACK)       # sling


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_JettyCrane_Brick", ALB)
    meshes = []

    def out(name, b):
        obj = b.to_object(name, mat)
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[crane] %-14s %5d tris" % (name, b.tris()))

    for name, fn in (("L01_Base", base), ("L02_Tower", tower), ("L03_Jib", jib), ("L04_Hook", hook)):
        b = lego.B()
        fn(b)
        out(name, b)
    for k, (lo, hi) in enumerate((((-BASE_W / 2, -BASE_W / 2, 0), (BASE_W / 2, BASE_W / 2, BASE_H)),
                                  ((-1.9, -1.9, BASE_H), (1.9, 1.9, TOWER_Z1)))):
        c = lego.B()
        c.box(lo, hi, P.DBG, bevel=0)
        out("Col%02d_COL" % (k + 1), c)

    atts = [lego.attach("ATT_Hook", (0, -JIB_L, HOOK_Z))]
    pts = []
    for e in meshes:
        if e["role"] == "visual":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[crane] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[crane] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "stylised Lego crane: 24 studs of tower, 39.4 stud jib toward -Y (the berth), as the Parts crane",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Base..., Col01_COL...: DockPieces.slipCrane places the Model as one piece",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "cab", "target": [0, 0, 24], "dist": 22, "az": -35, "el": 14},
            {"name": "hook", "target": [0, -JIB_L, 13], "dist": 16, "az": -30, "el": 10},
            {"name": "base", "target": [0, 0, 8], "dist": 28, "az": -40, "el": 18},
        ],
    }
