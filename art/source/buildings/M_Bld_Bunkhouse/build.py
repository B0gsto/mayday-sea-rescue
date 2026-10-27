"""M_Bld_Bunkhouse: the survivors' home in the Village, levels 1 to 5, Lego style (docs/25 B + J, docs/05 2.2/5).

Walk-in (owner rule, docs/25 J): a 6-stud front doorway, a lobby (rug, lockers on the east wall, a coat rail with life jackets
on the wall facing the door) and two bunk rooms through wide doorways. Beds, lockers and the dresser stand against walls,
nothing loose on any floor. Windows are flat warm-yellow panes (the "lights at night" look, no glow). Logs are 2 studs
thick (flat tan courses with 0.1 grooves over a cream core wall), roofs are blue studded plates, the trim is white.

Lv1 Bunk Hut     28 x 20 studs, 5 log courses, flat studded roof, sleeps 10 (5 bunks), side doorway west for the Lv4 wing.
Lv2 Upper Floor  second floor on the Lv1 roof plates: hall + dorm (5 more bunks), outside stair up the east wall, front balcony.
Lv3 Loft         smaller loft on the Lv2 roof (hammocks), a deck plate over the Lv2 roof (the terrace), a second stair
                 along the back wall up to the deck, gable roof.
Lv4 Side Wing    one-storey 14 x 9 annex west of Lv1: own front doorway + 2 windows, Lv1's side doorway, washstand, one bunk,
                 studded blue roof, chimney.
Lv5 Roof Terrace solid studded fence round the Lv3 deck, two benches against it (open floor), light poles with drooping
                 rope-tan strands of plain coloured bulbs, a 4 x 3 flag on the loft ridge.

Levels only add (Lv2 stands on Lv1's roof studs, Lv3 on Lv2's, the wing on Lv1's open side doorway). Every mesh is one colour
and one construction layer L01..L05 under its level; doors carry OwnerColour in the name. Pivot = ground centre of the lot,
door faces Blender -Y = Roblox -Z. Flat palette colours in one texture set
T_Bunkhouse_Brick (palette.py, as M_Bld_Depot; Roblox ignores FBX material colours). Collision is one box per
_Lv<l>_Col<NN>_COL object (Roblox hulls each MeshPart; doorways, stairs and interiors stay open).

    python3 art/source/buildings/M_Bld_Bunkhouse/maketex.py --out build/prod/M_Bld_Bunkhouse/textures/M_Bld_Bunkhouse

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/buildings/M_Bld_Bunkhouse/build.py --out-root build/prod/M_Bld_Bunkhouse \
      --steps build,validate,export,turntable
(no lod step: LOD1 / LOD2 are made here with a triangle floor, as in M_Bld_RescueHQ)
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bkgeo as H  # noqa: E402
import budgets  # noqa: E402
import names  # noqa: E402
import palette as P  # noqa: E402
import versions  # noqa: E402

NAME = "M_Bld_Bunkhouse"
SET_NAME, SET = "Bunkhouse", "Brick"
TEX = os.path.normpath(os.path.join(HERE, "../../../../build/prod", NAME, "textures", NAME))
STEM = "T_%s_%s_" % (SET_NAME, SET)
MATS = {k: (H.material("MI_Lamp" if k == "Lamp" else "MI_Bunkhouse_Brick", TEX, STEM), P.CELL[k]) for k in P.COLOURS}
# the Lamp panes keep their own material (same palette set) so views.py can light them in the night render

CH, TS, GROOVE = 2.0, 1.0, 0.0                   # log course, wall thickness, groove (courses touch; two tones tell them apart)
FLOOR, FL1 = 1.0, 1.1                            # plinth top, Lv1 floor top
E1 = FLOOR + 5 * CH                              # Lv1 eave 11.0
R1 = E1 + 1.2                                    # roof plate top 12.2 (studs +0.5)
Z2, F2 = R1, R1 + 0.5                            # Lv2 wall base, floor top (plate covers the Lv1 studs)
E2 = Z2 + 5 * CH
R2 = E2 + 1.2
Z3, F3 = R2, R2 + 0.5                            # Lv3 wall base, deck / loft floor top
E3 = Z3 + 5 * CH
DOOR = 3 * CH                                    # 6.0, three courses
RAIL = 0.8                                       # rails, stair posts and handrails: chunky enough to read at 30 studs
GL = {}                                          # one Group per (level, layer, word)
COLS = {"Lv1": [], "Lv2": [], "Lv3": [], "Lv4": [], "Lv5": []}
NODES = {}
ATTS = []


def G(level, layer, word, mat):
    key = (level, layer, word)
    if key not in GL:
        GL[key] = H.Group("%s_%s_%s_%s_LOD0" % (NAME, level, layer, word), *MATS[mat])
    return GL[key]


def col(level, x0, x1, y0, y1, z0, z1):
    COLS[level].append((((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0)))


def lay_logs(i):
    return "L02" if i < 3 else "L03"


# ----------------------------------------------------------------------------------------------- helpers
def box_on(g, face, a, d, z, along, deep, tall, bevel=0.0, drop=""):
    """drop letters in wall terms: s = both ends along the wall, b/t, i = the face toward the wall (inside)."""
    if face in ("-Y", "+Y"):
        tr = {"s": "xX", "b": "b", "t": "t", "i": "Y" if face == "-Y" else "y"}
        g.box((a, d, z), (along, deep, tall), bevel, drop="".join(tr[c] for c in drop))
    else:
        tr = {"s": "yY", "b": "b", "t": "t", "i": "X" if face == "-X" else "x"}
        g.box((d, a, z), (deep, along, tall), bevel, drop="".join(tr[c] for c in drop))


def win(L, layer, face, outer, a0, a1, z0, z1, shutter=None):
    """A warm-yellow flat pane in the wall hole, a white sill, a mullion on wide windows (flat colour, no glow)."""
    sgn = 1.0 if face in ("-Y", "-X") else -1.0
    fr, gl = G(L, layer, "Frames", "White"), G(L, layer, "Lamp", "Lamp")
    a, w, z, h = (a0 + a1) / 2.0, a1 - a0, (z0 + z1) / 2.0, z1 - z0
    box_on(gl, face, a, outer + sgn * 0.5, z, w, 0.14, h, drop="sbt")          # pane edges are inside the hole
    if h >= 4.0:                                   # tall windows get a sill, wide ones a mullion; clerestory strips stay a pane
        box_on(fr, face, a, outer - sgn * 0.12, z0 + 0.12, w + 0.5, 0.4, 0.28)
        if w >= 3.5:
            box_on(fr, face, a, outer + sgn * 0.5, z, 0.25, 0.3, h, drop="bt")
    if shutter:                                    # a pair of flat coloured shutters
        sh = G(L, layer, "Shutter", shutter)
        for da in (a0 - 0.6, a1 + 0.6):
            box_on(sh, face, da, outer - sgn * 0.1, z, 1.0, 0.2, h, drop="i")


def door_frame(L, layer, face, outer, a0, a1, z0, z1):
    """White jambs and lintel trim round a doorway."""
    sgn = 1.0 if face in ("-Y", "-X") else -1.0
    fr = G(L, layer, "Frames", "White")
    d = outer + sgn * 0.5
    for a in (a0 + 0.15, a1 - 0.15):
        box_on(fr, face, a, d, (z0 + z1) / 2.0, 0.3, 1.1, z1 - z0)
    box_on(fr, face, (a0 + a1) / 2.0, d, z1 - 0.15, a1 - a0, 1.1, 0.3)


def segs(a0, a1, z0, z1, holes):
    """Wall pieces a0..a1 of one course z0..z1 left between the holes [(a0, a1, z0, z1)]."""
    out = [(a0, a1)]
    for h0, h1, hz0, hz1 in holes:
        if hz1 <= z0 + 1e-6 or hz0 >= z1 - 1e-6:
            continue
        out = [p for s0, s1 in out for p in ((s0, min(s1, h0)), (max(s0, h1), s1)) if p[1] - p[0] > 0.05]
    return out


def shell(L, x0, x1, y0, y1, zb, n, holes, lay, skip=()):
    """n solid log courses (two tones), 1 stud thick, front is -Y. holes: {'F','B','L','R': [...]}, course-aligned.
    Hidden faces are left out: a course's top / bottom where the next course (or the roof / floor) covers it, and the
    side walls' ends that butt into the front and back walls."""
    walls = (('F', x0, x1, y0 + TS / 2, 'x'), ('B', x0, x1, y1 - TS / 2, 'x'),
             ('L', y0 + TS, y1 - TS, x0 + TS / 2, 'y'), ('R', y0 + TS, y1 - TS, x1 - TS / 2, 'y'))
    for i in range(n):
        z0, z1 = zb + i * CH, zb + (i + 1) * CH - GROOVE
        g = G(L, lay(i), "LogA" if i % 2 == 0 else "LogB", "Log1" if i % 2 == 0 else "Log2")
        for w, a0, a1, fixed, axis in walls:
            if w in skip:
                continue
            hs = holes.get(w, ())
            for s0, s1 in segs(a0, a1, z0, z1, hs):
                drop = "".join(k for k, j in (("t", i + 1), ("b", i - 1))
                               if not 0 <= j < n or segs(s0, s1, zb + j * CH, zb + (j + 1) * CH, hs) == [(s0, s1)])
                if axis == 'x':
                    g.box(((s0 + s1) / 2, fixed, (z0 + z1) / 2), (s1 - s0, TS, z1 - z0), 0.0, drop=drop)
                else:
                    drop += ("y" if abs(s0 - a0) < 1e-6 else "") + ("Y" if abs(s1 - a1) < 1e-6 else "")
                    g.box((fixed, (s0 + s1) / 2, (z0 + z1) / 2), (TS, s1 - s0, z1 - z0), 0.0, drop=drop)


def corner_posts(L, x0, x1, y0, y1, zb, zt, skip=()):
    g = G(L, "L02", "Posts", "LogDark")
    for sx, x in ((-1, x0), (1, x1)):
        for sy, y in ((-1, y0), (1, y1)):
            if (sx < 0 and 'L' in skip) or (sx > 0 and 'R' in skip):
                continue
            g.box((x - sx * 0.3, y - sy * 0.3, (zb + zt) / 2), (1.0, 1.0, zt - zb), 0.0, drop="bt")


def inner_walls(L, zb, zt, ztop_split, cross_holes, partition=None, xr=13.0, xl=-13.0, y_cross=0.0):
    """Cream cross wall at y 0 (holes = doorways) and an optional partition x 0 from the cross wall to the back."""
    for z0, z1, layer in ((zb, zt, "L02"),):
        g = G(L, layer, "Core", "Cream")
        H.solid_wall(g, xl, xr, z0, z1, y_cross, 'x', 0.8, cross_holes)
        if partition:
            H.solid_wall(g, 0.4, 9.0, z0, z1, 0.0, 'y', 0.8)


def bunk(L, fl, x, y, axis, open_hi, blanket, ln=6.4, w=3.0, head_hi=False):
    """Double bunk against a wall. (x, y) = min corner; axis 'y' / 'x' = long side direction; open_hi: room side is +u.
    Head board at v = 0 (v = ln with head_hi), ladder on the room side near the foot, upper tier 3.6 above the lower."""
    def put(g, u0, u1, v0, v1, z0, z1, drop=""):
        if not open_hi:
            u0, u1 = w - u1, w - u0
        if head_hi:
            v0, v1 = ln - v1, ln - v0
        if axis == 'y':
            c, s = (x + (u0 + u1) / 2.0, y + (v0 + v1) / 2.0), (u1 - u0, v1 - v0)
        else:
            c, s = (x + (v0 + v1) / 2.0, y + (u0 + u1) / 2.0), (v1 - v0, u1 - u0)
        g.box((c[0], c[1], fl + (z0 + z1) / 2.0), (s[0], s[1], z1 - z0), 0.0, drop=drop)

    wood, wood_u = G(L, "L02", "Bed", "LogDark"), G(L, "L03", "Bed", "LogDark")
    pil, pil_u = G(L, "L02", "Pillow", "White"), G(L, "L03", "Pillow", "White")
    bl, bl_u = G(L, "L02", "Blanket" + blanket, blanket), G(L, "L03", "Blanket" + blanket, blanket)
    put(wood, 0, w, 0, 0.4, 0, 6.2, "b")                              # head board
    for g_w, g_b, g_p, z in ((wood, bl, pil, 0.0), (wood_u, bl_u, pil_u, 3.6)):
        put(g_w, 0, w, 0.4, ln, 1.2 + z, 1.7 + z)                      # bed base
        put(g_b, 0.1, w - 0.1, 2.0, ln - 0.1, 1.7 + z, 2.0 + z, "b")   # blanket
        put(g_p, 0.35, w - 0.35, 0.5, 1.8, 1.7 + z, 2.15 + z, "b")    # pillow
    put(wood_u, w - 0.25, w, 0.4, ln - 2.4, 4.1, 4.9)                  # guard rail on the room side
    put(wood, w, w + 0.2, ln - 2.2, ln - 0.5, 0, 4.4, "b")             # ladder, one plate
    u0 = 0.0 if open_hi else -0.3
    if axis == 'y':
        return (x + u0, x + w + (0.3 if open_hi else 0.0), y, y + ln)
    return (x, x + ln, y + u0, y + w + (0.3 if open_hi else 0.0))


def flat_roof(L, zE, hx, hy, studs=True):
    """Blue plate with a white lip, chunky studs on top (the next level's floor plate covers them)."""
    G(L, "L04", "Roof", "Blue").slab((0, 0, zE + 0.6), (2 * hx + 1.6, 2 * hy + 1.6, 1.2), 0.12)
    G(L, "L04", "Trim", "White").slab((0, 0, zE + 0.25), (2 * hx + 1.8, 2 * hy + 1.8, 0.5), 0.05)
    if studs:
        g = G(L, "L05", "Studs", "Blue")
        for x in (-10, -5, 0, 5, 10):                # regular 5 x 3 grid
            for y in (-5, 0, 5):
                g.pstud(x, y, zE + 1.2, 1.2, 0.45)          # 0.05 under the next floor plate: no coplanar tops


def fence(L, layer, a, b, h=2.6):
    """Solid Lego fence panel from bottom point a to b (x or y constant, may slope), white, blue studded cap on top.
    Flat x runs own the corners (panel +0.25, cap +0.45 past the ends); flat y runs end at the x run's inner face and
    their cap stops 0.2 short, so caps never overlap coplanar. Flat runs get a collision box."""
    ax = 'X' if abs(a[0] - b[0]) < 1e-6 else 'Y'
    u = 1 if ax == 'X' else 0
    flat = a[2] == b[2]
    sg = math.copysign(1.0, b[u] - a[u])
    p, c = (sg * 0.25, sg * 0.45) if flat and u == 0 else (0.0, -sg * 0.2 if flat else 0.0)
    G(L, layer, "Fence", "White").prism([(a[u] - p, a[2]), (b[u] + p, b[2]), (b[u] + p, b[2] + h), (a[u] - p, a[2] + h)],
                                        0.5, axis=ax, at=a[1 - u])
    G(L, layer, "FenceCap", "Blue").prism([(a[u] - c, a[2] + h), (b[u] + c, b[2] + h), (b[u] + c, b[2] + h + 0.4),
                                           (a[u] - c, a[2] + h + 0.4)], 0.9, axis=ax, at=a[1 - u])
    if flat:
        lo, hi = min(a[u] - p, b[u] + p), max(a[u] - p, b[u] + p)
        box = (lo, hi, a[1 - u] - 0.25, a[1 - u] + 0.25) if u == 0 else (a[0] - 0.25, a[0] + 0.25, lo, hi)
        col(L, *box, a[2], a[2] + h + 0.4)
    n = Vector(b) - Vector(a)
    k = max(1, round(n.length / 3.5))
    for i in range(k):                            # studs about every 3.5 studs along the cap
        q = Vector(a) + n * ((i + 0.5) / k)
        G(L, layer, "FenceStud", "Blue").pstud(q.x, q.y, q.z + h + 0.3, 0.38, 0.35)


def att(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    bpy.context.scene.collection.objects.link(e)
    ATTS.append(e)


def ring(L, c, axis):
    """A red life ring hung on a cream wall (axis = the wall normal)."""
    G(L, "L03", "LifeRing", "Red").torus(c, 0.95, 0.3, segs=8, minor_segs=4, axis='Y' if axis == 'y' else 'X')


def shelf(L, c, along):
    """A wood shelf on a cream wall with three coloured boxes on it."""
    G(L, "L03", "Shelf", "Wood").box(c, (2.8, 0.7, 0.25) if along == 'x' else (0.7, 2.8, 0.25), 0)
    for k, cn in enumerate(("Red", "Yellow", "Blue")):
        o = -0.9 + 0.9 * k
        p = (c[0] + o, c[1], c[2] + 0.55) if along == 'x' else (c[0], c[1] + o, c[2] + 0.55)
        G(L, "L03", "Box" + cn, cn).box(p, (0.6, 0.45, 0.85) if along == 'x' else (0.45, 0.6, 0.85), 0)


SIDE1_L, SIDE1_R = ((1.4, 3.8), (5.6, 8.0)), ((-8.0, -5.2), (5.0, 8.0))
SIDE2_L, SIDE2_R = ((-8.0, -5.2), (3.0, 5.8)), ((-8.0, -5.2), (1.2, 3.8))


# ----------------------------------------------------------------------------------------------------- Lv1
def build_lv1():
    L = "Lv1"
    plinth, floor = G(L, "L01", "Plinth", "Plinth"), G(L, "L01", "Floor", "Floor")
    plinth.slab((0, 0, 0.5), (29.6, 21.6, 1.0), 0.12)
    plinth.slab((0, -11.4, 0.25), (8.0, 1.4, 0.5), 0.08)
    plinth.slab((-15.4, -5.0, 0.25), (1.4, 5.0, 0.5), 0.08)
    floor.box((0, 0, FL1 - 0.05), (26, 18, 0.1), 0)
    floor.box((0, -9.5, FL1 - 0.05), (6.0, 1.0, 0.1), 0)
    floor.box((-13.5, -5.0, FL1 - 0.05), (1.0, 5.0, 0.1), 0)
    rug = G(L, "L01", "Rug", "Blue")
    rug.box((0, -5.0, FL1 + 0.04), (10.0, 4.4, 0.08), 0)
    G(L, "L01", "RugCream", "Cream").box((0, -5.0, FL1 + 0.1), (8.6, 3.2, 0.04), 0)
    G(L, "L01", "RugRed", "Red").box((0, -5.0, FL1 + 0.14), (5.0, 0.7, 0.04), 0)

    c1, c2, c3 = FLOOR + CH, FLOOR + 2 * CH, FLOOR + 3 * CH     # 3, 5, 7
    holes = {'F': [(-3.0, 3.0, FLOOR, FLOOR + DOOR), (-11.0, -6.5, c1, c2 + CH), (6.5, 11.0, c1, c2 + CH)],
             'B': [(-10.5, -5.5, c3, c3 + CH), (5.5, 10.5, c3, c3 + CH)],
             'L': [(-7.5, -2.5, FLOOR, FLOOR + DOOR)] + [(a0, a1, c2, c2 + 2 * CH) for a0, a1 in SIDE1_L],
             'R': [(a0, a1, c2, c2 + 2 * CH) for a0, a1 in SIDE1_R]}
    shell(L, -14, 14, -10, 10, FLOOR, 5, holes, lay_logs)
    corner_posts(L, -14, 14, -10, 10, FLOOR, E1)
    for a0, a1 in ((-11.0, -6.5), (6.5, 11.0)):
        win(L, "L02", "-Y", -10.0, a0, a1, c1, c2 + CH, "Green")
    for a0, a1 in ((-10.5, -5.5), (5.5, 10.5)):
        win(L, "L03", "+Y", 10.0, a0, a1, c3, c3 + CH)
    for a0, a1 in SIDE1_R:                         # side windows clear the stair steps and sit above the lockers
        win(L, "L02", "+X", 14.0, a0, a1, c2, c2 + 2 * CH, "Green")
    for a0, a1 in SIDE1_L:                         # behind the Lv4 wing's roof line (y > 0.8)
        win(L, "L02", "-X", -14.0, a0, a1, c2, c2 + 2 * CH, "Green")
    door_frame(L, "L02", "-Y", -10.0, -3.0, 3.0, FLOOR, FLOOR + DOOR)
    door_frame(L, "L02", "-X", -14.0, -7.5, -2.5, FLOOR, FLOOR + DOOR)
    door = G(L, "L02", "OwnerColour_Door", "OwnerColour")
    for s in (-1, 1):                              # leaves swung open against the jambs
        door.box((s * 3.2, -10.9, FLOOR + 2.9), (0.3, 1.9, 5.8), 0)

    inner_walls(L, FLOOR, E1, c3, [(-9.5, -4.5, FLOOR - 1, FLOOR + DOOR), (4.5, 9.5, FLOOR - 1, FLOOR + DOOR)], partition=True)

    # coat rail with four life jackets on the cross wall facing the front door
    G(L, "L02", "Rail", "Wood").box((0, -0.55, 5.4), (7.6, 0.3, 0.4), 0)
    for k, x in enumerate((-2.7, -0.9, 0.9, 2.7)):
        G(L, "L02", "Jacket", "Yellow" if k % 2 == 0 else "Orange").box((x, -0.78, 4.0), (1.2, 0.5, 2.2), 0)
        G(L, "L02", "Strap", "Navy").box((x, -1.06, 3.5), (1.24, 0.06, 0.3), 0)
    # lockers along the east lobby wall
    for k, (y, cname) in enumerate(zip((-8.0, -6.2, -4.4, -2.6), ("Blue", "Red", "Yellow", "Green"))):
        G(L, "L02", "Locker" + cname, cname).box((12.3, y, FL1 + 1.8), (1.4, 1.7, 3.6), 0.0)
        G(L, "L02", "Vent", "Navy").box((11.58, y, FL1 + 3.0), (0.06, 1.1, 0.3), 0)
    col(L, 11.6, 13.0, -8.85, -1.75, FL1, FL1 + 3.6)
    # cream walls: life rings and shelves
    ring(L, (-11.3, -0.75, FL1 + 5.0), 'y')
    shelf(L, (11.3, -0.75, FL1 + 5.4), 'x')
    shelf(L, (-0.75, 7.4, FL1 + 4.6), 'y')
    ring(L, (0.75, 3.4, FL1 + 5.4), 'x')

    # bunks (sleeps 10): west room A, B, C; east room D, E; dresser against the partition
    for args, bl in (((-13, 1.0, 'y', True), "Blue"), ((-9.4, 6.0, 'x', False), "Red"), ((-3.4, 0.8, 'y', False), "Green"),
                     ((10.0, 1.0, 'y', False), "Orange"), ((3.0, 6.0, 'x', False), "Blue")):
        kw = {"ln": 5.0} if args[:2] == (-3.4, 0.8) else {}
        x0, x1, y0, y1 = bunk(L, FL1, *args, blanket=bl, **kw)
        col(L, x0, x1, y0, y1, FL1, FL1 + 6.2)
    G(L, "L02", "Dresser", "Wood").box((1.3, 3.4, FL1 + 1.7), (1.8, 4.8, 3.4), 0)
    for z in (0.7, 1.7, 2.7):
        G(L, "L02", "DresserFront", "Cork").box((0.35, 3.4, FL1 + z), (0.06, 4.4, 0.8), 0)
    col(L, 0.4, 2.2, 1.0, 5.8, FL1, FL1 + 3.4)

    flat_roof(L, E1, 14, 10)
    # red / white awning over the door, bed sign above it
    for k in range(6):
        G(L, "L05", "Awning" + ("Red" if k % 2 == 0 else "White"), "Red" if k % 2 == 0 else "White").prism(
            [(-10.0, 7.6), (-12.4, 6.6), (-12.4, 6.1), (-10.0, 7.1)], 1.2, axis='X', at=-3.0 + 1.2 * k)
    G(L, "L05", "SignBoard", "Navy").box((0, -10.15, 9.4), (4.6, 0.3, 3.0), 0)
    wh = G(L, "L05", "SignWhite", "White")
    wh.box((-1.5, -10.38, 9.4), (0.4, 0.1, 1.8), 0)
    wh.box((0.1, -10.38, 8.95), (2.8, 0.1, 0.5), 0)
    G(L, "L05", "SignOrange", "Orange").box((-0.8, -10.38, 9.5), (0.9, 0.1, 0.5), 0)
    G(L, "L05", "SignMoon", "Yellow").cyl((1.6, -10.4, 10.2), 0.4, 0.1, segs=8, axis='Y')
    att("ATT_Door_01", (0.0, -12.6, 0.0))
    att("ATT_Sign_01", (0.0, -10.4, 9.4))
    att("ATT_Bed_01", (-11.5, 4.2, FL1))

    # collision: floor, walls with open doorways, cross wall + partition, roof
    fl = FL1
    col(L, -14.8, 14.8, -10.8, 10.8, 0, fl)
    col(L, -4, 4, -12.0, -10.8, 0, 0.5)
    col(L, -16.0, -14.8, -7.5, -2.5, 0, 0.5)
    dz = FLOOR + DOOR
    col(L, -14, -3, -10, -9, fl, E1)
    col(L, 3, 14, -10, -9, fl, E1)
    col(L, -3, 3, -10, -9, dz, E1)
    col(L, -14, 14, 9, 10, fl, E1)
    col(L, 13, 14, -10, 10, fl, E1)
    col(L, -14, -13, -9, -7.5, fl, E1)
    col(L, -14, -13, -2.5, 9, fl, E1)
    col(L, -14, -13, -7.5, -2.5, dz, E1)
    col(L, -13, -9.5, -0.4, 0.4, fl, E1)
    col(L, -4.5, 4.5, -0.4, 0.4, fl, E1)
    col(L, 9.5, 13, -0.4, 0.4, fl, E1)
    col(L, -9.5, -4.5, -0.4, 0.4, dz, E1)
    col(L, 4.5, 9.5, -0.4, 0.4, dz, E1)
    col(L, -0.4, 0.4, 0.4, 9, fl, E1)
    col(L, -14.8, 14.2, -10.8, 10.8, E1, R1)      # stops at the east stair's inner edge (the plate overhangs it)


# ----------------------------------------------------------------------------------------------------- Lv2
def build_lv2():
    L = "Lv2"
    floor, wood, dark = G(L, "L01", "Floor", "Floor"), G(L, "L01", "Deck", "Wood"), G(L, "L01", "Posts", "LogDark")
    floor.box((0, 0, (Z2 + F2) / 2), (26, 18, F2 - Z2), 0)
    floor.box((0, -9.5, (Z2 + F2) / 2), (6.0, 1.0, F2 - Z2), 0)
    floor.box((13.5, 7.1, (Z2 + F2) / 2), (1.0, 4.0, F2 - Z2), 0)
    # balcony over the front door
    wood.slab((0, -11.8, F2 - 0.3), (18.0, 3.6, 0.6), 0.08)
    for x in (-4.6, 4.6):                          # 2x2 stilts between the awning and the Lv1 windows
        dark.box((x, -12.6, (F2 - 0.6) / 2), (2.0, 2.0, F2 - 0.6), 0)
        col(L, x - 1.0, x + 1.0, -13.6, -11.6, 0, F2 - 0.6)
    # east stair: 12 solid steps front to back, landing along the east wall, posts under the landing
    rs = F2 / 12.0
    for i in range(12):
        wood.box((16.0, -9.8 + 1.2 * i + 0.6, rs * (i + 1) / 2), (3.6, 1.2, rs * (i + 1)), 0, drop="bx" + ("Y" if i < 11 else ""))
        col("Lv2", 14.2, 17.8, -9.8 + 1.2 * i, -8.6 + 1.2 * i, 0, rs * (i + 1))
    wood.slab((16.0, 9.2, F2 - 0.3), (3.6, 9.2, 0.6), 0.08)
    col("Lv2", 14.2, 17.8, 4.6, 13.8, F2 - 0.6, F2)
    for y in (8.0, 12.8):                          # 2x2 stilts on the open edge (the top step carries the front)
        dark.box((16.8, y, (F2 - 0.6) / 2), (2.0, 2.0, F2 - 0.6), 0)
        col(L, 15.8, 17.8, y - 1.0, y + 1.0, 0, F2 - 0.6)

    c1, c2, c3 = Z2 + CH, Z2 + 2 * CH, Z2 + 3 * CH      # 14.2, 16.2, 18.2
    holes = {'F': [(-3.0, 3.0, Z2, Z2 + DOOR), (-9.5, -5.0, c1, c1 + 2 * CH), (5.0, 9.5, c1, c1 + 2 * CH)],
             'B': [(-10.5, -5.5, c3, c3 + CH)],
             'L': [(a0, a1, c2, c2 + 2 * CH) for a0, a1 in SIDE2_L],
             'R': [(5.2, 9.0, Z2, Z2 + DOOR)] + [(a0, a1, c2, c2 + 2 * CH) for a0, a1 in SIDE2_R]}
    shell(L, -14, 14, -10, 10, Z2, 5, holes, lay_logs)
    corner_posts(L, -14, 14, -10, 10, Z2, E2)
    for a0, a1 in ((-9.5, -5.0), (5.0, 9.5)):
        win(L, "L02", "-Y", -10.0, a0, a1, c1, c1 + 2 * CH, "Yellow")
    win(L, "L03", "+Y", 10.0, -10.5, -5.5, c3, c3 + CH)
    for a0, a1 in SIDE2_L:
        win(L, "L02", "-X", -14.0, a0, a1, c2, c2 + 2 * CH, "Yellow")
    for a0, a1 in SIDE2_R:
        win(L, "L02", "+X", 14.0, a0, a1, c2, c2 + 2 * CH, "Yellow")
    door_frame(L, "L02", "-Y", -10.0, -3.0, 3.0, Z2, Z2 + DOOR)
    door_frame(L, "L02", "+X", 14.0, 5.2, 9.0, Z2, Z2 + DOOR)
    door = G(L, "L02", "OwnerColour_Door", "OwnerColour")
    for s in (-1, 1):                              # balcony double door, leaves open
        door.box((s * 3.2, -10.9, Z2 + 3.2), (0.3, 1.9, 5.8), 0)
    for y in (5.65, 8.55):                         # stair doorway: two leaves swung open into the dorm, as Lv1's
        door.box((12.05, y, Z2 + 3.0), (1.9, 0.3, 5.8), 0)

    inner_walls(L, Z2, E2, c3, [(-4.0, 4.0, Z2 - 1, Z2 + DOOR)])
    G(L, "L02", "Cork", "Cork").box((0, 0.55, F2 + 4.4), (5.0, 0.15, 3.0), 0)         # bulletin board in the hall
    for k, (x, y, cn) in enumerate(((-1.6, 0.0, "Yellow"), (-0.2, 0.0, "Red"), (1.2, 0.0, "Blue"), (2.0, 0.0, "Green"))):
        G(L, "L02", "Note" + cn, cn).box((x, 0.65, F2 + 4.4 + (0.4 if k % 2 == 0 else -0.4)), (0.8, 0.05, 1.0), 0)
    G(L, "L02", "Bench", "Wood").box((5.0, 8.35, F2 + 1.5), (7.6, 1.2, 0.3), 0)
    for x in (1.6, 8.4):
        G(L, "L02", "BenchLeg", "LogDark").box((x, 8.35, F2 + 0.75), (0.5, 1.0, 1.5), 0)
    col(L, 1.0, 9.0, 7.7, 9.0, F2, F2 + 1.8)
    ring(L, (-6.5, 0.75, F2 + 4.6), 'y')                                             # cream cross wall: rings, shelf
    shelf(L, (7.5, 0.75, F2 + 5.0), 'x')
    for x in (-11.4, 11.4):
        ring(L, (x, -0.75, F2 + 5.0), 'y')

    # five more bunks: hall west wall, dorm west / east walls, two on the cross wall
    for args, bl, kw in (((-13, 1.0, 'y', True), "Purple", {}), ((-13, -8.9, 'y', True), "Orange", {}),
                         ((10.0, -8.9, 'y', False), "Blue", {}), ((-9.8, -3.4, 'x', True), "Green", {"ln": 5.4}),
                         ((4.4, -3.4, 'x', True), "Red", {"ln": 5.4, "head_hi": True})):
        x0, x1, y0, y1 = bunk(L, F2, *args, blanket=bl, **kw)
        col(L, x0, x1, y0, y1, F2, F2 + 6.2)

    flat_roof(L, E2, 14, 10)
    fence(L, "L05", (-8.75, -13.35, F2), (8.75, -13.35, F2))   # balcony: solid fence panels, studded caps
    for s in (-1, 1):
        fence(L, "L05", (s * 8.75, -13.1, F2), (s * 8.75, -9.8, F2))
    xr = 17.55                                                  # east stair: sloped panel along the step backs, landing
    fence(L, "L05", (xr, -9.8, 0.0), (xr, 4.6, F2), 3.0)
    fence(L, "L05", (xr, 4.6, F2), (xr, 13.75, F2), 3.0)
    fence(L, "L05", (14.2, 14.0, F2), (xr, 14.0, F2), 3.0)
    att("ATT_Stair_01", (16.0, -9.8, 0.0))
    att("ATT_Balcony_01", (0.0, -11.8, F2))

    fl = F2
    col(L, -14.8, 14.2, -10.8, 10.8, Z2, fl)      # east stair's inner edge, as Lv1's roof
    col(L, -9, 9, -13.6, -10.8, fl - 0.6, fl)
    dz = Z2 + DOOR
    col(L, -14, -3, -10, -9, fl, E2)
    col(L, 3, 14, -10, -9, fl, E2)
    col(L, -3, 3, -10, -9, dz, E2)
    col(L, -14, 14, 9, 10, fl, E2)
    col(L, -14, -13, -9, 9, fl, E2)
    col(L, 13, 14, -9, 5.2, fl, E2)
    col(L, 13, 14, 9.0, 9, fl, E2)
    col(L, 13, 14, 5.2, 9.0, dz, E2)
    col(L, -13, -4, -0.4, 0.4, fl, E2)
    col(L, 4, 13, -0.4, 0.4, fl, E2)
    col(L, -4, 4, -0.4, 0.4, dz, E2)
    col(L, -14.8, 14.8, -10.8, 10.0, E2, R2)      # stops at the back treads' inner edge (y 10.0)


# ----------------------------------------------------------------------------------------------------- Lv3
def hammock(L, xc, colour, sag=1.7):
    """A hammock hung front to back from two wall ropes: a lens-shaped prism seen in the y/z plane."""
    g = G(L, "L03", "Hammock" + colour, colour)
    top, bot = [], []
    for k in range(4):
        y = -4.6 + 9.2 * k / 3.0
        z = F3 + 5.8 - sag * (1.0 - (y / 4.6) ** 2)
        top.append((y, z))
        bot.append((y, z - 0.35))
    g.prism(top + bot[::-1], 1.6, axis='X', at=xc)
    rope = G(L, "L03", "Rope", "LogDark")
    for s in (-1, 1):
        rope.beam((xc, s * 4.6, F3 + 5.8), (xc, s * 5.95, F3 + 6.9), 0.12, 0.12)


def build_lv3():
    L = "Lv3"
    deck = G(L, "L01", "Deck", "Wood")
    deck.slab((0, 0, (Z3 + F3) / 2), (29.0, 21.0, F3 - Z3), 0.08)
    # stair 2 along the back wall: cantilevered treads from the Lv2 landing (z 12.7) to the deck (z 23.9)
    wood, dark = G(L, "L01", "Treads", "Wood"), G(L, "L01", "Stringer", "LogDark")
    r2 = (F3 - F2) / 11.0
    for k in range(11):
        x1 = 14.2 - 1.2 * k
        top = F2 + r2 * (k + 1)
        wood.box((x1 - 0.6, 11.8, top - 0.25), (1.2, 3.6, 0.5), 0)
        col(L, x1 - 1.2, x1, 10.0, 13.6, top - 0.5, top)
    slope = (F3 - F2) / 13.2
    zs = lambda x: F2 + 1.0 + (14.2 - x) * slope                  # stringer top
    dark.prism([(14.2, F2 - 0.5), (1.0, F3 - 0.5), (1.0, F3 + 1.0), (14.2, F2 + 1.0)], RAIL, axis='Y', at=13.6 + RAIL / 2)
    for x in (8.0, 2.6):                           # 2x2 stilts up to the lowest tread they carry
        zt = min(F2 + r2 * (k + 1) - 0.5 for k in range(11) if 14.2 - 1.2 * (k + 1) < x + 1.0 < 14.2 - 1.2 * k + 2.0)
        dark.box((x, 12.6, zt / 2), (2.0, 2.0, zt), 0)
        col(L, x - 1.0, x + 1.0, 11.6, 13.6, 0, zt)
    fence(L, "L05", (14.2, 13.6 + RAIL / 2, zs(14.2) - 0.5), (1.0, 13.6 + RAIL / 2, zs(1.0) - 0.5))   # on the stringer

    c1, c2, c3 = Z3 + CH, Z3 + 2 * CH, Z3 + 3 * CH
    holes = {'F': [(-7.0, -3.5, c1, c1 + 2 * CH), (3.5, 7.0, c1, c1 + 2 * CH)],
             'B': [(-2.5, 2.5, Z3, Z3 + DOOR), (-8.0, -5.0, c1, c1 + 2 * CH)],
             'L': [(-4.5, -1.5, c1, c1 + 2 * CH), (1.5, 4.5, c1, c1 + 2 * CH)],
             'R': [(-4.5, -1.5, c1, c1 + 2 * CH), (1.5, 4.5, c1, c1 + 2 * CH)]}
    shell(L, -10, 10, -7, 7, Z3, 5, holes, lay_logs)
    corner_posts(L, -10, 10, -7, 7, Z3, E3)
    for a0, a1 in ((-7.0, -3.5), (3.5, 7.0)):
        win(L, "L02", "-Y", -7.0, a0, a1, c1, c1 + 2 * CH, "Orange")
    win(L, "L02", "+Y", 7.0, -8.0, -5.0, c1, c1 + 2 * CH)
    for a0, a1 in ((-4.5, -1.5), (1.5, 4.5)):
        win(L, "L02", "+X", 10.0, a0, a1, c1, c1 + 2 * CH, "Orange")
        win(L, "L02", "-X", -10.0, a0, a1, c1, c1 + 2 * CH, "Orange")
    door_frame(L, "L02", "+Y", 7.0, -2.5, 2.5, Z3, Z3 + DOOR)
    G(L, "L02", "OwnerColour_Door", "OwnerColour").box((2.65, 7.9, Z3 + 2.9), (0.3, 1.9, 5.8), 0)

    for xc, cn in ((-7.8, "Orange"), (-5.4, "Yellow"), (5.4, "Blue"), (7.8, "Red")):
        hammock(L, xc, cn)
    gable_roof(L)
    att("ATT_Hammock_01", (-6.5, 0.0, F3 + 3.5))
    att("ATT_Deck_01", (1.6, 11.8, F3))

    fl = F3
    col(L, -14.5, 14.5, -10.5, 10.0, Z3 - 1.2, fl)    # back treads' inner edge, as Lv2's roof
    dz = Z3 + DOOR
    col(L, -10, 10, -7, -6, fl, E3)
    col(L, -10, -9, -6, 6, fl, E3)
    col(L, 9, 10, -6, 6, fl, E3)
    col(L, -10, -2.5, 6, 7, fl, E3)
    col(L, 2.5, 10, 6, 7, fl, E3)
    col(L, -2.5, 2.5, 6, 7, dz, E3)
    col(L, -11.2, 11.2, -8.2, 8.2, E3, E3 + 3.0)


def gable_roof(L):
    roof, cap, lines = G(L, "L04", "Roof", "Blue"), G(L, "L04", "Trim", "White"), G(L, "L04", "Lines", "Blue")
    half, rise, top = 8.2, 3.6, 1.0
    roof.prism([(-half, E3), (half, E3), (top, E3 + rise - rise / half * top), (-top, E3 + rise - rise / half * top)], 21.6, axis='X', at=0)
    zc = E3 + rise - rise / half * top
    cap.box((0, 0, zc + 0.2), (21.6, 2 * top, 0.4), 0.0)
    studs = G(L, "L05", "Studs", "White")
    for x in (-7.5, -2.5, 2.5, 7.5):
        studs.pstud(x, 0, zc + 0.4, 0.55, 0.4)


# ----------------------------------------------------------------------------------------------------- Lv4
def build_lv4():
    """One-storey annex west of Lv1 (14 x 9, front set 1 back so it shows in the front 3/4 view), entered through its own
    front doorway and through Lv1's side doorway (y -7.5 .. -2.5): two front windows, a bunk, a washstand."""
    L = "Lv4"
    x0, x1, y0, y1, wn = -28.0, -14.0, -9.0, 0.0, 4
    ew = FLOOR + wn * CH                                           # eave 9, under Lv1's eave
    plinth, floor = G(L, "L01", "Plinth", "Plinth"), G(L, "L01", "Floor", "Floor")
    plinth.slab((-21.8, -4.5, 0.5), (14.0, 10.6, 1.0), 0.12)       # stops at Lv1's plinth edge (no coplanar tops)
    plinth.slab((-17.2, -10.2, 0.25), (5.4, 1.4, 0.5), 0.08)
    floor.box((-20.5, -4.5, FL1 - 0.05), (13.0, 7.0, 0.1), 0)
    floor.box((-17.2, -8.5, FL1 - 0.05), (4.4, 1.0, 0.1), 0)
    c1, c2 = FLOOR + CH, FLOOR + 2 * CH
    fw = ((-26.4, -24.0), (-23.0, -20.6))
    holes = {'F': [(a0, a1, c1, c1 + 2 * CH) for a0, a1 in fw] + [(-19.4, -15.0, FLOOR, FLOOR + DOOR)],
             'B': [(-19.4, -16.6, c2, c2 + 2 * CH)], 'L': [(-7.0, -4.6, c1, c1 + 2 * CH)], 'R': []}
    shell(L, x0, x1, y0, y1, FLOOR, wn, holes, lambda i: "L02" if i < 2 else "L03", skip=('R',))
    corner_posts(L, x0, x1, y0, y1, FLOOR, ew, skip=('R',))
    for a0, a1 in fw:                              # front windows with red flower boxes (no room for shutters)
        win(L, "L02", "-Y", y0, a0, a1, c1, c1 + 2 * CH)
        G(L, "L02", "FlowerBox", "Red").box(((a0 + a1) / 2, y0 - 0.45, c1 - 0.35), (a1 - a0 + 0.4, 0.9, 0.7), 0)
        G(L, "L02", "Flowers", "Green").box(((a0 + a1) / 2, y0 - 0.45, c1 + 0.1), (a1 - a0, 0.6, 0.3), 0)
    win(L, "L03", "+Y", y1, -19.4, -16.6, c2, c2 + 2 * CH, "Yellow")
    win(L, "L02", "-X", x0, -7.0, -4.6, c1, c1 + 2 * CH, "Yellow")
    door_frame(L, "L02", "-Y", y0, -19.4, -15.0, FLOOR, FLOOR + DOOR)
    # bunk on the back wall, washstand under the back window
    bx0, bx1, by0, by1 = bunk(L, FL1, -27.0, -4.0, 'x', False, blanket="Green")
    col(L, bx0, bx1, by0, by1, FL1, FL1 + 6.2)
    G(L, "L02", "Counter", "Cream").box((-17.8, -1.7, FL1 + 1.6), (4.8, 1.4, 3.2), 0)
    G(L, "L02", "CounterTop", "Blue").box((-17.8, -1.75, FL1 + 3.3), (5.2, 1.6, 0.25), 0)
    for x in (-19.0, -16.6):
        G(L, "L02", "Basin", "Steel").box((x, -1.8, FL1 + 3.5), (1.6, 1.0, 0.15), 0)
        G(L, "L02", "Tap", "Steel").box((x, -1.15, FL1 + 3.9), (0.2, 0.2, 0.6), 0)
    col(L, -20.2, -15.4, -2.4, -1.0, FL1, FL1 + 3.4)

    G(L, "L04", "Roof", "Blue").slab((-21.4, -4.5, ew + 0.6), (14.8, 10.6, 1.2), 0.12)
    G(L, "L04", "Trim", "White").slab((-21.4, -4.5, ew + 0.25), (15.0, 10.8, 0.5), 0.05)
    st = G(L, "L05", "Studs", "Blue")
    for x in (-25.6, -21.4, -17.2):                # regular 3 x 2 grid, same studs as Lv1's roof
        for y in (-7.0, -2.6):
            st.pstud(x, y, ew + 1.2, 1.1, 0.45)
    G(L, "L05", "Chimney", "Brick").box((-27.0, -0.4, ew + 2.7), (2.0, 2.0, 3.0), 0.0)
    G(L, "L05", "ChimneyCap", "LogDark").box((-27.0, -0.4, ew + 4.4), (2.4, 2.4, 0.4), 0)
    att("ATT_Wing_01", (-21.0, -4.5, FL1))

    fl, dz = FL1, FLOOR + DOOR
    col(L, -28.8, -14.8, -9.8, 0.8, 0, fl)
    col(L, x0, -19.4, y0, y0 + TS, fl, ew)
    col(L, -15.0, x1, y0, y0 + TS, fl, ew)
    col(L, -19.4, -15.0, y0, y0 + TS, dz, ew)
    col(L, x0, x1, y1 - TS, y1, fl, ew)
    col(L, x0, x0 + TS, y0 + TS, y1 - TS, fl, ew)
    col(L, -28.8, -14.0, -9.8, 0.8, ew, ew + 1.2)


# ----------------------------------------------------------------------------------------------------- Lv5
def build_lv5():
    """Roof terrace on the Lv3 deck: solid fence panels with studded caps (gate at the stair head), two benches against
    the side fences, seven light poles with drooping rope-tan strands of plain coloured bulbs, a big flag on the loft ridge."""
    L = "Lv5"
    zd, ht, ph = F3, 2.8, 8.0                      # deck, rail height, light pole height
    poles = ((-14.0, -10.0), (0.0, -10.0), (14.0, -10.0), (-14.0, 0.0), (14.0, 0.0), (-14.0, 10.0), (14.0, 10.0))
    for a, b in (((-14.0, -10.0), (14.0, -10.0)), ((-14.0, -9.75), (-14.0, 9.75)), ((14.0, -9.75), (14.0, 9.75)),
                 ((-14.0, 10.0), (-0.4, 10.0)), ((2.5, 10.0), (14.0, 10.0))):     # solid fence, gate at the stair head
        fence(L, "L02", (*a, zd), (*b, zd), ht - 0.4)
    (cx, cy, cz), (sx, sy, sz) = COLS[L][-1]      # the stair-side run's box stops at the back treads' edge (y 10.0)
    COLS[L][-1] = ((cx, cy - 0.125, cz), (sx, sy - 0.25, sz))
    # benches against the side fences, the rest of the deck stays open floor
    for sx in (-1, 1):
        x = sx * 12.9
        G(L, "L02", "Bench", "Wood").box((x, -2.0, zd + 1.5), (1.6, 6.4, 0.4), 0)
        for y in (-4.6, 0.6):
            G(L, "L02", "BenchLeg", "LogDark").box((x, y, zd + 0.65), (1.2, 0.6, 1.3), 0)
        col(L, x - 0.8, x + 0.8, -5.2, 1.2, zd, zd + 1.7)
    # light poles and drooping strands (4 segments, 3 bulbs each), bulbs plain colour
    pole = G(L, "L03", "Pole", "LogDark")
    for x, y in poles:
        pole.box((x, y, zd + ph / 2), (0.9, 0.9, ph), 0)
    string = G(L, "L04", "String", "Cork")          # thick rope-tan wire, reads at 30 studs
    bulbs = ("Red", "Yellow", "Green", "Blue", "Orange")
    spans = ((poles[0], poles[1]), (poles[1], poles[2]), (poles[0], poles[3]), (poles[3], poles[5]),
             (poles[2], poles[4]), (poles[4], poles[6]))
    nb = 0
    for (ax, ay), (bx, by) in spans:
        pts = [(ax + (bx - ax) * k / 4.0, ay + (by - ay) * k / 4.0, zd + ph - 0.4 - 1.8 * (1 - ((k - 2) / 2.0) ** 2))
               for k in range(5)]
        for p0, p1 in zip(pts, pts[1:]):
            string.beam(p0, p1, 0.4, 0.4)
        for p in pts[1:4]:
            cn = bulbs[nb % len(bulbs)]
            nb += 1
            G(L, "L04", "Bulb" + cn, cn).box((p[0], p[1], p[2] - 0.5), (0.8, 0.8, 1.0), 0.0)
    # flag on the loft ridge: thick pole, 4 x 3 flag with a white and red mark, a yellow knob
    zc = E3 + 3.6 - 3.6 / 8.2 + 0.4
    G(L, "L05", "FlagPole", "Steel").box((-9.5, 0.0, zc + 4.0), (0.6, 0.6, 8.0), 0)
    G(L, "L05", "FlagKnob", "Yellow").pstud(-9.5, 0.0, zc + 8.0, 0.55, 0.4)
    G(L, "L05", "Flag", "Blue").box((-9.5, 2.3, zc + 6.3), (0.2, 4.0, 3.0), 0)
    G(L, "L05", "FlagMark", "White").box((-9.5, 2.5, zc + 6.3), (0.26, 1.8, 1.8), 0)
    G(L, "L05", "FlagDot", "Red").box((-9.5, 2.5, zc + 6.3), (0.32, 0.8, 0.8), 0)
    att("ATT_Flag_01", (-9.5, 0.0, zc + 8.0))


# ------------------------------------------------------------------------------------------- collision, LODs
LOD_FLOOR = {"LOD1": 12, "LOD2": 12}
LOD_MIN = {"LOD1": 24, "LOD2": 72}      # small fittings (studs, ropes, rails, bulbs) are culled from the far LODs


def add_lods(spec):
    out = []
    for e in [x for x in spec["meshes"] if x.get("role", "visual") == "visual" and x.get("lod", "LOD0") == "LOD0"
              and not x["object"].name.endswith("_COL")]:
        src = e["object"]
        tris = versions.triangles(src.data)
        for lod, floor in LOD_FLOOR.items():
            if tris < LOD_MIN[lod]:
                continue
            target = min(tris, max(floor, budgets.lod_target(spec["budget"], lod, tris, spec.get("tris"))))
            obj = versions.copy_object(src, names.with_suffix(src.name, lod))
            while True:                     # a ring of bricks has a decimation floor: accept the nearest count above
                try:
                    versions.decimate(obj, target)
                    break
                except RuntimeError:
                    if target >= tris:
                        break
                    target = min(tris, target + 4)
            versions.weighted_normals(obj)
            entry = {"object": obj, "role": "visual", "lod": lod, "of": src.name}
            if e.get("set"):
                entry["set"] = e["set"]
            out.append(entry)
    spec["meshes"].extend(out)


def collision(level):
    """One object per box: Roblox hulls each MeshPart, so a multi-box _COL would fill the doorways between its boxes."""
    out = []
    for i, (c, s) in enumerate(COLS[level], 1):
        g = H.Group("%s_%s_Col%02d_COL" % (NAME, level, i), *MATS["Plinth"])
        g.box(c, s, 0.0)
        out.append(g.done())
    return out


def build():
    for lv in COLS:
        e = bpy.data.objects.new(lv, None)
        bpy.context.scene.collection.objects.link(e)
        NODES[lv] = e
    build_lv1()
    build_lv2()
    build_lv3()
    build_lv4()
    build_lv5()
    visual = []
    for (level, layer, word), g in GL.items():
        if not g.bm.verts:
            continue
        ob = g.done()
        ob.parent = NODES[level]
        visual.append(ob)
    cols = [ob for lv in COLS for ob in collision(lv)]
    for ob in cols:
        ob.parent = NODES[[lv for lv in COLS if "_%s_" % lv in ob.name][0]]

    meshes = []
    for ob in visual:
        ob.data.name = ob.name
        meshes.append({"object": ob, "set": SET})
    meshes += [{"object": c} for c in cols]

    pts = [ob.matrix_world @ v.co for ob in visual for v in ob.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = [hi[i] - lo[i] for i in range(3)]
    tris = {lv: sum(versions.triangles(o.data) for o in visual if ("_%s_" % lv) in o.name) for lv in COLS}
    print("[bunk] LOD0 tris %s total %d in %d meshes" % (tris, sum(tris.values()), len(visual)))
    print("[bunk] bbox studs %.2f x %.2f x %.2f (x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f)"
          % (dims[0], dims[1], dims[2], lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))

    spec = {
        "name": NAME, "budget": "large_prop", "tier": "standard",
        "dims_m": (dims[0] / 3.0, dims[1] / 3.0, dims[2] / 3.0),
        "size_note": "Lv1 to Lv5 together incl. the Lv4 west wing, the east stair, the back stair, the balcony and the flag pole",
        "origin": "free", "tiling": True,
        "sets": [{"name": SET_NAME, "set": SET, "size": P.SIZE, "wet": False}],
        "waivers": {"LOD UV layout": "flat palette cells (one colour per mesh): decimation moves UVs inside the "
                                     "cell, UVs are not a unique unwrap by design (tiling=True skips the density check)"},
        "meshes": meshes, "attachments": ATTS,
        "closeups": [
            {"name": "Lv1Door", "target": [0.0, -10.0, 6.0], "dist": 24.0, "az": 24.0, "el": 10.0},
            {"name": "ThroughDoor", "target": [0.0, 2.0, 4.0], "dist": 22.0, "az": 6.0, "el": 4.0},
            {"name": "Lv2Balcony", "target": [0.0, -11.0, 16.0], "dist": 28.0, "az": 24.0, "el": 12.0},
            {"name": "Lv2Stair", "target": [16.0, 2.0, 8.0], "dist": 34.0, "az": 80.0, "el": 14.0},
            {"name": "Lv4Wing", "target": [-21.0, -9.0, 5.0], "dist": 26.0, "az": 330.0, "el": 12.0},
            {"name": "Lv5Terrace", "target": [2.0, -7.0, 27.5], "dist": 30.0, "az": 20.0, "el": 30.0},
        ],
    }
    add_lods(spec)
    return spec
