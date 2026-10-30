"""M_Prop_JettyCrane: the Harbour Lv3 dockside crane, Lego style (replaces the code-built DockPieces.slipCrane Parts:
white pole, flat navy boom, dangling hook; owner 2026-10-29: "it looks cheap, needs to be redone via Blender").
Round 2 (AD round 1 6.5/10: "stock Lego crane, cheap bits"): wider studded base, a real counter-jib with ballast
bricks, a jib that tapers to a red tip cap, stiff rod ties, a chunky hook block with a hook and one smooth life ring.

Same envelope as the Parts crane: origin the mast's ground centre (the base stands on the jetty deck), jib reaching
39.4 studs toward the berth along -Y (Blender front = Roblox -Z: the game turns the Model with CFrame.lookAt toward
the tip). The jib axis sits at 20 studs (was 23.5) so the crane stays about 4 characters tall to the jib and does not
dominate the jetty. Decoration only: nothing animates it (the "crane" the gameplay mentions is the Harbour Lv3 unlock).

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
Z0 = -0.06                   # base bottom just below the deck top: never coplanar with it
B1_W, B1_H = 7.6, 1.2        # red studded footing
B2_W, B2_H = 5.0, 2.0        # grey plinth top
HW = 1.5                     # tower post offset (posts at +-HW)
JIB_Z = 20.0                 # jib axis height
TOWER_Z0, TOWER_Z1 = B2_H, JIB_Z - 1.9
JIB_L = 39.4                 # reach toward -Y
COUNTER = 8.0                # counter-jib length toward +Y
HOOK_Y = -JIB_L + 2.6        # trolley + hook line
HOOK_Z = 11.0                # hook block centre


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def stud(b, x, y, z, c, r=0.6, h=0.42, n=12):
    b.cyl(x, y, z - SINK, z + h, r, c, n)


def jib_half(y):
    """(half width of the lower chords, half depth) of the jib at y: tapers from the root (y 0) to the tip."""
    t = min(1.0, max(0.0, -y / JIB_L))
    return 1.25 - 0.55 * t, 1.0 - 0.45 * t


def torus_arc(b, cx, cy, cz, R, r, a0, a1, c, seg=8, mnr=10):
    """A capped piece of a torus round the X axis (ring in the y-z plane) from angle a0 to a1 (radians)."""
    verts = []
    for i in range(seg + 1):
        u = a0 + (a1 - a0) * i / seg
        for j in range(mnr):
            v = 2 * math.pi * j / mnr
            verts.append((cx + r * math.sin(v), cy + (R + r * math.cos(v)) * math.cos(u),
                          cz + (R + r * math.cos(v)) * math.sin(u)))
    faces = [(i * mnr + j, (i + 1) * mnr + j, (i + 1) * mnr + (j + 1) % mnr, i * mnr + (j + 1) % mnr)
             for i in range(seg) for j in range(mnr)]
    faces += [tuple(range(mnr)), tuple(seg * mnr + j for j in reversed(range(mnr)))]
    b._emit(verts, faces, c)


# ------------------------------------------------------------------ layers
def base(b):
    h = B1_W / 2
    b.box((-h, -h, Z0), (h, h, B1_H), P.RED, bevel=0.22)
    for x in (-2.7, 0.0, 2.7):
        for y in (-2.7, 0.0, 2.7):
            if x or y:
                stud(b, x, y, B1_H, P.RED, 0.66, 0.45)
    for s in (-1, 1):                                    # hazard blocks on the four faces
        for t in (-1, 1):
            b.box((t * 1.6 - 0.7, s * h - 0.06, 0.25), (t * 1.6 + 0.7, s * h + 0.06, 0.95), P.YELLOW, bevel=0.0)
            b.box((s * h - 0.06, t * 1.6 - 0.7, 0.25), (s * h + 0.06, t * 1.6 + 0.7, 0.95), P.YELLOW, bevel=0.0)
    g = B2_W / 2
    b.box((-g, -g, B1_H - SINK), (g, g, B2_H), P.DBG, bevel=0.15)
    for sx in (-1, 1):
        for sy in (-1, 1):
            stud(b, sx * 2.0, sy * 2.0, B2_H, P.DBG, 0.4, 0.3)


def tower(b):
    nb = 4
    zs = [TOWER_Z0 + (TOWER_Z1 - TOWER_Z0) * i / nb for i in range(nb + 1)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * HW - 0.45, sy * HW - 0.45, TOWER_Z0 - SINK), (sx * HW + 0.45, sy * HW + 0.45, TOWER_Z1),
                  P.WHITE, bevel=0.06)
    for z in zs[1:]:                                     # square frames at each level (inside the posts' faces)
        for sy in (-1, 1):
            b.box((-HW, sy * HW - 0.3, z - 0.3), (HW, sy * HW + 0.3, z + 0.3), P.WHITE, bevel=0.03)
        for sx in (-1, 1):
            b.box((sx * HW - 0.28, -HW, z - 0.28), (sx * HW + 0.28, HW, z + 0.28), P.WHITE, bevel=0.03)
    for i in range(nb):                                  # red X braces on the four faces
        a, e = zs[i], zs[i + 1]
        for s in (-1, 1):
            b.beam((-HW, s * HW, a), (HW, s * HW, e), 0.4, 0.4, P.RED)
            b.beam((HW, s * HW, a), (-HW, s * HW, e), 0.4, 0.4, P.RED)
            b.beam((s * HW, -HW, a), (s * HW, HW, e), 0.4, 0.4, P.RED)
            b.beam((s * HW, HW, a), (s * HW, -HW, e), 0.4, 0.4, P.RED)
    # slewing ring, deck, cab, A-frame, beacon
    z = TOWER_Z1
    b.cyl(0, 0, z - SINK, z + 0.9, 3.0, P.DBG, 20)
    b.box((-2.8, -2.8, z + 0.9 - SINK), (2.8, 2.8, z + 1.3), P.ORANGE, bevel=0.08)
    cz = z + 1.3
    b.box((-3.9, -2.4, cz - SINK), (-1.0, 1.8, cz + 3.4), P.RED, bevel=0.14)                 # cab
    b.box((-3.96, -2.0, cz + 1.1), (-3.8, 1.4, cz + 2.9), P.INK, bevel=0.0)                   # side window
    b.box((-3.7, -2.46, cz + 1.1), (-1.2, -2.3, cz + 2.9), P.INK, bevel=0.0)                  # windscreen
    for y in (-1.0, 0.8):
        stud(b, -2.45, y, cz + 3.4, P.RED, 0.52, 0.36)
    apex = (0, 0.4, JIB_Z + 8.5)
    for sx in (-1, 1):
        b.beam((sx * 1.2, -0.2, cz), apex, 0.55, 0.55, P.WHITE)
        b.beam((sx * 1.2, 1.4, cz), apex, 0.55, 0.55, P.WHITE)
    b.box((-0.55, -0.15, apex[2] - 0.2), (0.55, 0.95, apex[2] + 0.75), P.RED, bevel=0.08)    # beacon
    # stiff rod ties (phone-readable): apex to two points on the jib and to the counter-jib end
    _, d1 = jib_half(-14.0)
    _, d2 = jib_half(-27.0)
    tz = apex[2] - 0.3
    b.beam((0, 0.2, tz), (0, -14.0, JIB_Z + d1 + 0.2), 0.62, 0.62, P.DBG)
    b.beam((0, 0.2, tz), (0, -27.0, JIB_Z + d2 + 0.2), 0.62, 0.62, P.DBG)
    b.beam((0, 0.6, tz), (0, COUNTER - 0.6, JIB_Z + 1.2), 0.62, 0.62, P.DBG)


def jib(b):
    L = JIB_L
    w0, d0 = jib_half(0.0)
    w1, d1 = jib_half(-L)
    y0, y1 = 0.6, -L + 0.4
    b.beam((0, y0, JIB_Z + d0), (0, y1, JIB_Z + d1), 1.3, 0.8, P.YELLOW)                      # top chord
    for sx in (-1, 1):
        b.beam((sx * w0, y0, JIB_Z - d0), (sx * w1, y1, JIB_Z - d1), 0.6, 0.6, P.WHITE)      # lower chords
    n = 12
    for i in range(n):
        ya, ye = -0.4 - i * (L - 1.4) / n, -0.4 - (i + 1) * (L - 1.4) / n
        wa, da = jib_half(ya)
        we, de = jib_half(ye)
        up = i % 2 == 0
        for sx in (-1, 1):
            pa = (sx * wa, ya, JIB_Z - da) if up else (0, ya, JIB_Z + da)
            pe = (0, ye, JIB_Z + de) if up else (sx * we, ye, JIB_Z - de)
            b.beam(pa, pe, 0.4, 0.4, P.RED)
        b.beam((-wa, ya, JIB_Z - da), (wa, ya, JIB_Z - da), 0.36, 0.36, P.WHITE)               # cross ties
    for i in range(12):                                                                        # studs on the top chord
        y = -1.6 - i * 3.0
        _, d = jib_half(y)
        stud(b, 0, y, JIB_Z + d + 0.4 - 0.06, P.YELLOW, 0.5, 0.36)
    # tip cap
    b.box((-w1 - 0.35, -L - 0.5, JIB_Z - d1 - 0.45), (w1 + 0.35, -L + 0.7, JIB_Z + d1 + 0.5), P.RED, bevel=0.15)
    stud(b, 0, -L + 0.1, JIB_Z + d1 + 0.5, P.RED, 0.45, 0.32)
    # counter-jib: walkway truss toward +Y, ballast bricks stacked at its end
    zt, zb = JIB_Z + 0.8, JIB_Z - 0.8
    b.box((-0.65, 0.0, zt - 0.4), (0.65, COUNTER, zt + 0.4), P.YELLOW, bevel=0.08)
    for sx in (-1, 1):
        b.box((sx * 1.25 - 0.3, -0.2, zb - 0.3), (sx * 1.25 + 0.3, COUNTER + 0.2, zb + 0.3), P.WHITE, bevel=0.04)
    for i in range(3):
        ya, ye = 0.8 + i * 1.6, 0.8 + (i + 1) * 1.6
        for sx in (-1, 1):
            b.beam((sx * 1.25, ya, zb), (0, ye, zt), 0.36, 0.36, P.RED)
    b.box((-1.6, 0.4, zb - 0.5), (1.6, COUNTER - 2.8, zb - 0.22), P.DBG, bevel=0.04)          # walkway grating
    for k, c in enumerate((P.STONE, P.DBG, P.STONE)):
        zk = zb - 1.6 + k * 1.3
        b.box((-2.0, COUNTER - 3.0, zk - (SINK if k else 0)), (2.0, COUNTER + 0.4, zk + 1.3), c, bevel=0.14)
    for sx in (-1, 1):
        for y in (COUNTER - 2.1, COUNTER - 0.5):
            stud(b, sx * 1.0, y, zb - 1.6 + 3 * 1.3, P.STONE, 0.6, 0.42)


def hook(b):
    y = HOOK_Y
    w, d = jib_half(y)
    zc = JIB_Z - d                                                                             # lower chord axis
    # trolley riding the lower chords, wheels on top
    b.box((-w - 0.5, y - 1.0, zc - 1.3), (w + 0.5, y + 1.0, zc - 0.36), P.RED, bevel=0.12)
    for sx in (-1, 1):
        for dy in (-0.55, 0.55):
            b.cyl_x(sx * w, y + dy, zc - 0.25, 0.32, 0.5, P.DBG, 10)
    # two stiff falls to the hook block
    top = HOOK_Z + 1.1
    for sx in (-1, 1):
        b.box((sx * 0.6 - 0.23, y - 0.23, top - SINK), (sx * 0.6 + 0.23, y + 0.23, zc - 1.3 + SINK), P.DBG,
              bevel=0.0)
    # chunky yellow hook block with a red band and sheave hubs
    b.box((-1.5, y - 1.05, HOOK_Z - 1.1), (1.5, y + 1.05, HOOK_Z + 1.1), P.YELLOW, bevel=0.24)
    b.box((-1.56, y - 1.11, HOOK_Z - 0.28), (1.56, y + 1.11, HOOK_Z + 0.28), P.RED, bevel=0.0)
    b.cyl_x(0, y, HOOK_Z + 0.6, 0.6, 3.3, P.DBG, 14)
    stud(b, 0, y, HOOK_Z + 1.1, P.YELLOW, 0.3, 0.3)
    # the hook: a shank and a J curve in the x-z plane
    hc = HOOK_Z - 2.4                                                                          # bowl centre
    b.box((-0.28, y - 0.28, hc + 0.4), (0.28, y + 0.28, HOOK_Z - 1.1 + SINK), P.DBG, bevel=0.05)
    R = 0.85
    pts = [(R * math.cos(a), hc + R * math.sin(a)) for a in
           [math.radians(d_) for d_ in (100, 150, 200, 250, 290, 330, 10, 40)]]
    pts[0] = (0.0, hc + 0.6)
    for (xa, za), (xe, ze) in zip(pts, pts[1:]):
        b.beam((xa, y, za), (xe, y, ze), 0.55, 0.55, P.DBG)
    b.box((pts[-1][0] - 0.24, y - 0.24, pts[-1][1] - 0.1), (pts[-1][0] + 0.24, y + 0.24, pts[-1][1] + 0.5),
          P.DBG, bevel=0.08)                                                                   # tip
    # life ring hung on the hook bowl: one smooth red torus, four white bands (a hair proud of it)
    RR, rr = 1.9, 0.55
    rc = hc - R - 0.05 + rr - RR
    torus_arc(b, 0, y, rc, RR, rr, 0, 2 * math.pi, P.RED, seg=32, mnr=12)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        torus_arc(b, 0, y, rc, RR, rr + 0.06, a - 0.28, a + 0.28, P.WHITE, seg=4, mnr=12)


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
    for k, (lo, hi) in enumerate((((-B1_W / 2, -B1_W / 2, Z0), (B1_W / 2, B1_W / 2, B2_H)),
                                  ((-1.95, -1.95, B2_H), (1.95, 1.95, TOWER_Z1)))):
        c = lego.B()
        c.box(lo, hi, P.DBG, bevel=0)
        out("Col%02d_COL" % (k + 1), c)

    atts = [lego.attach("ATT_Hook", (0, HOOK_Y, HOOK_Z))]
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
        "size_note": "stylised Lego crane: 20 studs to the jib, 39.4 stud jib toward -Y (the berth), as the Parts crane",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Base..., Col01_COL...: DockPieces.slipCrane places the Model as one piece",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "cab", "target": [0, 0, 21], "dist": 22, "az": -35, "el": 14},
            {"name": "hook", "target": [0, HOOK_Y, 9], "dist": 14, "az": -60, "el": 10},
            {"name": "base", "target": [0, 4, 6], "dist": 26, "az": -40, "el": 18},
        ],
    }
