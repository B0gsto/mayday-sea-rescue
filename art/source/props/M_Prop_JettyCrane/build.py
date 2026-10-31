"""M_Prop_JettyCrane: the Harbour Lv3 dockside crane, Lego style (replaces the code-built DockPieces.slipCrane Parts:
white pole, flat navy boom, dangling hook; owner 2026-10-29: "it looks cheap, needs to be redone via Blender").
Round 2 (AD round 1 6.5/10: "stock Lego crane, cheap bits"): wider studded base, a real counter-jib with ballast
bricks, a jib that tapers to a red tip cap, stiff rod ties, a chunky hook block with a hook and one smooth life ring.
Round 3 (AD round 2 7.6/10): a deep zigzag (Warren) truss on the tower instead of X braces ("reads as XXX"), two chunky
yellow ties instead of three thin dark rods, a yellow operator cab with a big windscreen at the slewing ring, and a
bigger hook block and a ~2x life ring so both read over the water.
Round 4 (AD round 3 8.3/10 in game): a 1.4x deeper jib with thicker chords and braces (read as a truss, not a line
on a phone), tower diagonals standing proud of the frames (were sunk behind them: "printed"), a bigger cab glazed on
three sides under an overhanging red roof, thick black stepped hoist falls with a trolley sheave, a yellow/black
hazard band on the ballast, and amber lamp housings at the jib tip and on the cab roof (ATT_Lamp_*: DockPieces hangs a
Neon bulb + night PointLight there).
Round 5 (AD round 4 8.3/10): straight chamfered tower diagonals set into each bay, ending on the frames under grey pin
caps (were kinked ribbons cutting through the frames), chamfered long beams and glossier plastic, a grey slewing deck
(no orange wedge or dark disc under the cab), the life ring resting in a bigger hook bowl instead of through it, the
hook-block sheave between two cheek plates with the falls running into it, an even stud row on the jib, pin caps on
the tie ends, a smoother ring.
Round 6 (AD round 5 8.7/10): a smooth swept round hook (hex swivel nut, latch, round tip) with the ring seated in its
throat, sheave discs and axle bosses on the hook block's faces, rounder studs, chamfered tower posts and frames,
light-grey pins (dark ones read as holes), clevis pins at both tie ends, a grey trim plate seating the cab, and the
cab lamp on a real stud position.
Round 7 (AD round 6 8.7, tour 7.9): a slotted hook block (two cheek plates, a grooved sheave on a cross-pin in the
slot, a tile on top) with thin 6-sided black falls from a matching trolley sheave, a centred 2x3 stud grid on a
plate-thin cab roof (lamp on a corner stud), inset lighter glazing with glints, a red trim band round the cab, a toothed
slewing ring, 8-sided tower pins, life ring at 90% with its bands on the ring's edge loops.

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
HW = 1.75                    # tower post offset (posts at +-HW)
JIB_Z = 20.0                 # jib axis height
TOWER_Z0, TOWER_Z1 = B2_H, JIB_Z - 1.9
JIB_L = 39.4                 # reach toward -Y
COUNTER = 8.0                # counter-jib length toward +Y
HOOK_Y = -JIB_L + 2.6        # trolley + hook line
HOOK_Z = 13.4                # hook block centre
CAB_STUDS = [(-2.0, -2.4)] + [(x, y) for x in (-4.2, -2.0) for y in (-2.4, -0.4, 1.6) if (x, y) != (-2.0, -2.4)]


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def stud(b, x, y, z, c, r=0.6, h=0.42, n=12):
    b.cyl(x, y, z - SINK, z + h, r, c, n)


def cbeam(b, p0, p1, w, h, c, ch=0.1):
    """A beam with chamfered long edges (an octagon section lofted p0 -> p1): reads as bevelled plastic."""
    import mathutils
    p0, p1 = mathutils.Vector(p0), mathutils.Vector(p1)
    d = (p1 - p0).normalized()
    up = mathutils.Vector((0, 0, 1)) if abs(d.z) < 0.95 else mathutils.Vector((0, 1, 0))
    side = d.cross(up).normalized()
    up = side.cross(d).normalized()
    a, e = w / 2, h / 2
    sec = [(a - ch, -e), (a, -e + ch), (a, e - ch), (a - ch, e), (-a + ch, e), (-a, e - ch), (-a, -e + ch), (-a + ch, -e)]
    ring = lambda p: [tuple(p + side * u + up * v) for u, v in sec]
    faces = [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)] + [tuple(range(8)), tuple(range(15, 7, -1))]
    b._emit(ring(p0) + ring(p1), faces, c)


def hook_arc(b, cx, cy, cz, R, r, a0, a1, c, seg=16, mnr=10):
    """torus_arc in the x-z plane (round the Y axis): the swept hook."""
    t = lego.B()
    torus_arc(t, cy, cx, cz, R, r, a0, a1, c, seg, mnr)
    b._emit([(y, x, z) for x, y, z in t.v], [f for f, _ in t.f], c)


def gear(b, cx, cy, z0, z1, r, tooth, n, c):
    """A toothed ring prism (2n verts round: r and r + tooth alternating, two per tooth): the slewing gear."""
    ring = []
    for i in range(2 * n):
        rad = r + (tooth if (i // 2) % 2 == 0 else 0.0)
        a = 2 * math.pi * (i + 0.5 * (i % 2)) / (2 * n)
        ring.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    m = len(ring)
    verts = [(x, y, z0) for x, y in ring] + [(x, y, z1) for x, y in ring]
    faces = [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)]
    faces += [tuple(reversed(range(m))), tuple(range(m, 2 * m))]
    b._emit(verts, faces, c)


def frame(b, lo, hi, axis, t, c):
    """A hollow window frame (four bars of width t) in the box lo..hi, open along `axis` ("x" or "y")."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    if axis == "y":
        bars = [((x0, y0, z0), (x1, y1, z0 + t)), ((x0, y0, z1 - t), (x1, y1, z1)),
                ((x0, y0, z0 + t - 0.05), (x0 + t, y1, z1 - t + 0.05)), ((x1 - t, y0, z0 + t - 0.05), (x1, y1, z1 - t + 0.05))]
    else:
        bars = [((x0, y0, z0), (x1, y1, z0 + t)), ((x0, y0, z1 - t), (x1, y1, z1)),
                ((x0, y0, z0 + t - 0.05), (x1, y0 + t, z1 - t + 0.05)), ((x0, y1 - t, z0 + t - 0.05), (x1, y1, z1 - t + 0.05))]
    for a, e in bars:
        b.box(a, e, c, bevel=0.04)


def cyl_y(b, cx, cy, cz, r, length, c, n=8):
    """A closed cylinder lying along Y (lego.B.cyl_x with x and y swapped)."""
    t = lego.B()
    t.cyl_x(cy, cx, cz, r, length, c, n)
    b._emit([(y, x, z) for x, y, z in t.v], [f for f, _ in t.f], c)


def jib_half(y):
    """(half width of the lower chords, half depth) of the jib at y: tapers from the root (y 0) to the tip."""
    t = min(1.0, max(0.0, -y / JIB_L))
    return 1.25 - 0.55 * t, 1.4 - 0.65 * t


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
                stud(b, x, y, B1_H, P.RED, 0.66, 0.45, 12)
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
            cbeam(b, (sx * HW, sy * HW, TOWER_Z0 - SINK), (sx * HW, sy * HW, TOWER_Z1), 1.2, 1.2, P.WHITE, 0.12)
    for z in zs[1:]:                                     # square frames at each level (inside the posts' faces)
        for sy in (-1, 1):
            cbeam(b, (-HW, sy * HW, z), (HW, sy * HW, z), 0.9, 0.76, P.WHITE, 0.1)
        for sx in (-1, 1):
            cbeam(b, (sx * HW, -HW, z), (sx * HW, HW, z), 0.84, 0.72, P.WHITE, 0.1)
    # one straight red bar per bay, chord to chord between the posts (Warren truss: neighbours share a pin on the frame),
    # set just inside the frame face (+-0.45) so nothing cuts through; a grey pin cap on every node
    ix, o = HW - 0.62, HW + 0.12
    for i in range(nb):
        a, e = zs[i] + (0.38 if i else 0.1), zs[i + 1] - 0.38
        k = 1 if i % 2 == 0 else -1
        for s in (-1, 1):
            cbeam(b, (-k * ix, s * o, a), (k * ix, s * o, e), 0.8, 0.5, P.RED, 0.09)
            cbeam(b, (s * o, k * ix, a), (s * o, -k * ix, e), 0.8, 0.5, P.RED, 0.09)
    for i in range(nb):                                  # pin caps where bay i meets bay i+1, on the frame face
        k, z = (1 if i % 2 == 0 else -1), zs[i + 1]
        for s in (-1, 1):
            cyl_y(b, k * ix, s * (HW + 0.45), z, 0.3, 0.3, P.LBG, 8)
            b.cyl_x(s * (HW + 0.45), -k * ix, z, 0.3, 0.3, P.LBG, 8)
    # slewing ring, deck, cab, A-frame, beacon
    z = TOWER_Z1
    b.cyl(0, 0, z - SINK, z + 0.9 + SINK, 2.2, P.DBG, 12)                                   # slewing ring core
    gear(b, 0, 0, z + 0.2, z + 0.75, 2.45, 0.18, 20, P.DBG)                                  # toothed slewing gear
    b.box((-2.8, -2.8, z + 0.9), (2.8, 2.8, z + 1.3), P.STONE, bevel=0.08)                   # grey slewing deck
    cz = z + 1.3
    # yellow operator cab on the slewing deck: big glass windscreen toward the jib, side window, red studded roof
    # round 4: bigger, glazed on three sides (a light-blue band that reads at range), roof overhanging all round
    X0, X1, Y0, Y1 = -4.9, -1.1, -3.1, 2.3
    b.box((X0, Y0, cz - SINK), (X1, Y1, cz + 4.0), P.YELLOW, bevel=0.16)
    b.box((X0 - 0.12, Y0 - 0.12, cz - 0.02), (X1 + 0.12, Y1 + 0.12, cz + 0.32), P.STONE, bevel=0.06)  # trim: seats the cab
    frame(b, (X0 + 0.25, Y0 - 0.15, cz + 1.1), (X1 - 0.25, Y0 + 0.1, cz + 3.5), "y", 0.3, P.WHITE)   # windscreen frame
    b.box((X0 + 0.5, Y0 - 0.1, cz + 1.35), (X1 - 0.5, Y0 + 0.08, cz + 3.25), P.GLASS, bevel=0.0)     # windscreen (inset)
    frame(b, (X0 + 0.25, Y1 - 0.1, cz + 1.1), (X1 - 0.25, Y1 + 0.15, cz + 3.5), "y", 0.3, P.WHITE)   # rear frame
    b.box((X0 + 0.5, Y1 - 0.08, cz + 1.35), (X1 - 0.5, Y1 + 0.1, cz + 3.25), P.GLASS, bevel=0.0)     # rear window
    frame(b, (X0 - 0.15, Y0 + 0.3, cz + 1.1), (X0 + 0.1, Y1 - 0.3, cz + 3.5), "x", 0.3, P.WHITE)     # side frame
    b.box((X0 - 0.1, Y0 + 0.55, cz + 1.35), (X0 + 0.08, Y1 - 0.55, cz + 3.25), P.GLASS, bevel=0.0)   # side window
    # one white glint strip across each pane (a hair proud of the glass, inside the frame face)
    b.beam((X0 + 0.95, Y0 - 0.125, cz + 1.55), (X0 + 1.85, Y0 - 0.125, cz + 3.05), 0.03, 0.28, P.WHITE)
    b.beam((X0 + 0.95, Y1 + 0.125, cz + 1.55), (X0 + 1.85, Y1 + 0.125, cz + 3.05), 0.03, 0.28, P.WHITE)
    b.beam((X0 - 0.125, Y0 + 1.2, cz + 1.55), (X0 - 0.125, Y0 + 2.2, cz + 3.05), 0.03, 0.28, P.WHITE)
    b.box((X0 - 0.04, Y0 - 0.04, cz + 0.45), (X1 + 0.04, Y1 + 0.04, cz + 0.85), P.RED, bevel=0.0)   # red trim band
    b.box((X0 - 0.55, Y0 - 0.55, cz + 4.0 - SINK), (X1 + 0.35, Y1 + 0.55, cz + 4.4), P.RED, bevel=0.08)  # roof plate
    for x, y in CAB_STUDS[1:]:                                                     # centred 2x3 grid, lamp on a corner
        stud(b, x, y, cz + 4.4, P.RED, 0.55, 0.38, 16)
    lx, ly = CAB_STUDS[0]                         # amber lamp (ATT_Lamp_Cab sits on it: DockPieces adds the Neon bulb)
    b.cyl(lx, ly, cz + 4.4 - SINK, cz + 4.65, 0.5, P.DBG, 16)
    b.cyl(lx, ly, cz + 4.65 - SINK, cz + 5.0, 0.4, P.ORANGE, 16)                              # amber lens
    apex = (0, 0.4, JIB_Z + 8.5)
    for sx in (-1, 1):
        cbeam(b, (sx * 1.2, -0.2, cz), apex, 0.6, 0.6, P.WHITE, 0.08)
        cbeam(b, (sx * 1.2, 1.4, cz), apex, 0.6, 0.6, P.WHITE, 0.08)
    b.box((-0.55, -0.15, apex[2] - 0.2), (0.55, 0.95, apex[2] + 0.75), P.RED, bevel=0.08)    # beacon
    # two chunky yellow ties (AD r2: thin dark rods read as lines): apex to mid-jib and to the counter-jib end
    _, d1 = jib_half(-21.0)
    tz = apex[2] - 0.3
    for p0, p1 in (((0, 0.2, tz), (0, -21.0, JIB_Z + d1 + 0.3)), ((0, 0.6, tz), (0, COUNTER - 0.6, JIB_Z + 1.2))):
        cbeam(b, p0, p1, 1.1, 0.8, P.YELLOW, 0.12)
        for q in (p0, p1):                                                                     # clevis pins, both ends
            b.cyl_x(0, q[1], q[2], 0.38, 1.5, P.LBG, 12)


def jib(b):
    L = JIB_L
    w0, d0 = jib_half(0.0)
    w1, d1 = jib_half(-L)
    y0, y1 = 0.6, -L + 0.4
    cbeam(b, (0, y0, JIB_Z + d0), (0, y1, JIB_Z + d1), 1.5, 1.0, P.YELLOW, 0.14)              # top chord
    for sx in (-1, 1):
        cbeam(b, (sx * w0, y0, JIB_Z - d0), (sx * w1, y1, JIB_Z - d1), 0.75, 0.75, P.WHITE, 0.1)      # lower chords
    n = 12
    for i in range(n):
        ya, ye = -0.4 - i * (L - 1.4) / n, -0.4 - (i + 1) * (L - 1.4) / n
        wa, da = jib_half(ya)
        we, de = jib_half(ye)
        up = i % 2 == 0
        for sx in (-1, 1):
            pa = (sx * wa, ya, JIB_Z - da) if up else (0, ya, JIB_Z + da)
            pe = (0, ye, JIB_Z + de) if up else (sx * we, ye, JIB_Z - de)
            b.beam(pa, pe, 0.52, 0.52, P.RED)
        b.beam((-wa, ya, JIB_Z - da), (wa, ya, JIB_Z - da), 0.44, 0.44, P.WHITE)               # cross ties
    for i in range(19):                                                                        # even stud row, top chord
        y = -1.6 - i * 2.0
        if abs(y + 21.0) < 0.9:                                                                # the tie's pin lands here
            continue
        _, d = jib_half(y)
        stud(b, 0, y, JIB_Z + d + 0.5 - 0.06, P.YELLOW, 0.5, 0.36, 14)
    # tip cap
    b.box((-w1 - 0.35, -L - 0.5, JIB_Z - d1 - 0.45), (w1 + 0.35, -L + 0.7, JIB_Z + d1 + 0.5), P.RED, bevel=0.15)
    b.cyl(0, -L + 0.1, JIB_Z + d1 + 0.5 - SINK, JIB_Z + d1 + 0.75, 0.5, P.DBG, 12)          # lamp housing (ATT_Lamp_JibTip)
    b.cyl(0, -L + 0.1, JIB_Z + d1 + 0.75 - SINK, JIB_Z + d1 + 1.1, 0.4, P.ORANGE, 12)      # amber lens
    # counter-jib: walkway truss toward +Y, ballast bricks stacked at its end
    zt, zb = JIB_Z + 1.0, JIB_Z - 0.8
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
    zh = zb - 1.6 + 1.3                                  # hazard band round the middle course (yellow/black, a hair proud)
    for i in range(6):
        c = P.YELLOW if i % 2 == 0 else P.BLACK
        xa = -2.0 + i * 4.0 / 6
        b.box((xa, COUNTER + 0.4 - SINK, zh + 0.3), (xa + 4.0 / 6, COUNTER + 0.47, zh + 1.0), c, bevel=0.0)
    for sx in (-1, 1):
        for i in range(5):
            c = P.YELLOW if i % 2 == 0 else P.BLACK
            ya = COUNTER - 3.0 + i * 3.4 / 5
            xo, xi = sx * 2.07, sx * (2.0 - SINK)
            b.box((min(xo, xi), ya, zh + 0.3), (max(xo, xi), ya + 3.4 / 5, zh + 1.0), c, bevel=0.0)
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
    # trolley sheave and a slotted hook block: two cheek plates with a grooved sheave on a cross-pin in the slot,
    # two thin 6-sided black falls between the sheaves (AD r6: the block read as a box with a washer)
    HB = 1.6                                                                                   # block half height
    SZ = HOOK_Z + 0.3                                                                          # block sheave centre
    for sz_, r_ in ((zc - 1.6, 1.0), (SZ, 1.15)):
        for s in (-1, 1):
            cyl_y(b, 0, y + s * 0.33, sz_, r_, 0.2, P.DBG, 16)                                  # flanges
        cyl_y(b, 0, y, sz_, r_ - 0.17, 0.5, P.BLACK, 16)                                        # rope in the groove
    cyl_y(b, 0, y, SZ, 0.36, 3.4, P.LBG, 12)                                                   # cross-pin + bosses
    for sx in (-1, 1):
        b.cyl(sx * 0.98, y, SZ, zc - 1.6, 0.28, P.BLACK, 6)
    b.box((-2.2, y - 1.5, HOOK_Z - HB), (2.2, y + 1.5, HOOK_Z - HB + 0.7), P.YELLOW, bevel=0.1)   # bottom plate
    for s in (-1, 1):                                    # side plates: square shoulders, a round top round the sheave
        b.box((-2.2, y + s * 0.55, HOOK_Z - HB + 0.7 - SINK), (2.2, y + s * 1.5, SZ), P.YELLOW, bevel=0.0)
        cyl_y(b, 0, y + s * 1.025, SZ - SINK, 1.6, 0.95, P.YELLOW, 16)
        b.box((-2.27, y + s * 0.6, HOOK_Z - 0.75), (2.27, y + s * 1.57, HOOK_Z - 0.15), P.RED, bevel=0.06)
    # the hook: a shank and a J curve in the x-z plane
    R, hr = 1.55, 0.38                                                                         # bowl clears the ring tube
    hc = HOOK_Z - HB - 2.3                                                                     # bowl centre
    b.cyl(0, y, HOOK_Z - HB - 0.45, HOOK_Z - HB + SINK, 0.66, P.LBG, 6)                         # hex swivel nut
    b.cyl(0, y, hc + R - 0.1, HOOK_Z - HB - 0.45 + SINK, hr, P.DBG, 12)                        # shank
    hook_arc(b, 0, y, hc, R, hr, math.radians(90), math.radians(390), P.DBG, seg=18, mnr=10)  # round swept bowl
    tx, tz = R * math.cos(math.radians(30)), hc + R * math.sin(math.radians(30))
    b.cyl(tx, y, tz - 0.1, tz + 0.3, hr + 0.04, P.DBG, 12)                                    # round tip
    cbeam(b, (0.3, y, hc + R - 0.05), (tx - 0.15, y, tz + 0.25), 0.22, 0.3, P.LBG, 0.06)      # safety latch
    # life ring hung on the hook bowl: one smooth red torus, four white bands (a hair proud of it)
    RR, rr = 3.15, 0.9                                                                         # AD r6: 90%
    rc = hc - R + hr + rr - RR + 0.04                                                          # tube seated in the throat
    torus_arc(b, 0, y, rc, RR, rr, 0, 2 * math.pi, P.RED, seg=32, mnr=14)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        torus_arc(b, 0, y, rc, RR, rr + 0.07, a - math.pi / 16, a + math.pi / 16, P.WHITE, seg=2, mnr=14)  # on loops


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_JettyCrane_Brick", ALB, rough=0.32)
    meshes = []

    def out(name, b):
        obj = b.to_object(name, mat)
        obj.data.set_sharp_from_angle(angle=math.radians(40))  # chamfers stay crisp facets (lego.py smooths at 50)
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

    _, d1 = jib_half(-JIB_L)
    cz = TOWER_Z1 + 1.3
    atts = [lego.attach("ATT_Hook", (0, HOOK_Y, HOOK_Z)),
            lego.attach("ATT_Lamp_JibTip", (0, -JIB_L + 0.1, JIB_Z + d1 + 1.35)),
            lego.attach("ATT_Lamp_Cab", (CAB_STUDS[0][0], CAB_STUDS[0][1], cz + 5.25))]
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
            {"name": "jibroot", "target": [0, -5, 20], "dist": 20, "az": -125, "el": 18},
            {"name": "hook", "target": [0, HOOK_Y, 9], "dist": 20, "az": -60, "el": 10},
            {"name": "base", "target": [0, 4, 6], "dist": 26, "az": -40, "el": 18},
        ],
    }
