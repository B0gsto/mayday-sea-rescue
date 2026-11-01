"""M_Bld_RescueHQ: the island's Rescue HQ, levels 1 and 2, Lego style (docs/25 A + J, docs/05 2.2/5).

Walk-in (owner rule, docs/25 J): a 6-stud front doorway (door leaves swung open against the jambs), a 6-stud side
doorway on the east wall, a tan floor, big windows, and an uncluttered room: radio desk and chart table; on the walls a
chart board, a clock, a lifebuoy and a hook rail with two life jackets; a clear walkway.

Lv1 Rescue Hut: 24 x 18 studs (walls), 1-stud plinth, 1x6 white bricks in running bond (flat panels, 0.1 grooves, over
a cream core wall), a red gable with faint course lines and a studded white ridge, a lifebuoy sign over the doorway.
Lv2 Rescue Post = ONLY the added pieces on top of Lv1 (the game shows Lv1 + Lv2): a 1-brick red band over the hut eave,
a second storey on the band footprint (hides the hut roof) with one wrap-round window band, a red tiled deck with
course lines inside a white studded rim and a lifebuoy on a white 4x4 pad, a 16 x 10 glass watch room under the Lv1
gable scaled down (1-stud overhang, ridge studs, lifebuoy sign on its pedestal), a signal mast (yardarm, 4 pennants,
radar bar), and an 8-stud side wing (red-cross plaque on the street face) with a medic counter facing the east doorway.

Both levels share the origin (lot centre, ground level); the door faces Blender -Y = Roblox -Z. Every mesh is one colour
and one construction layer L01..L07 under its level empty. Door leaves carry OwnerColour in the name. One flat palette set
T_RescueHQ_Brick (palette.py, maketex.py): each mesh's UVs sit in its colour's cell (Roblox ignores FBX colours).

    python3 art/source/buildings/M_Bld_RescueHQ/maketex.py --out build/prod/M_Bld_RescueHQ/textures/M_Bld_RescueHQ
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build \
      art/source/buildings/M_Bld_RescueHQ/build.py --out-root build/prod/M_Bld_RescueHQ \
      --steps build,validate,export,turntable
(no lod step: LOD1 / LOD2 are made here with a triangle floor, the small Lego fittings have no collapse form)
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hqgeo as H  # noqa: E402
import budgets  # noqa: E402
import names  # noqa: E402
import palette as P  # noqa: E402
import versions  # noqa: E402

NAME = "M_Bld_RescueHQ"
MATS = {k: H.material(k, *v) for k, v in [*P.COLOURS.items(), P.OWNER]}

CH, GROOVE = 1.1, 0.1
BRICK = float(os.environ.get("HQ_BRICK", "6.0"))   # 1x6 brick length (studs): 1x4 bricks cost 30% more wall triangles than the 2k budget allows
TS, TC = 0.4, 0.8                     # wall = 0.4 brick skin + 0.8 cream core
FLOOR, E1, N1 = 1.0, 9.8, 8          # plinth top, Lv1 eave, Lv1 courses (E1 = FLOOR + N1 * CH)
DOOR_H = 6.6                          # 6 courses
GL = {}                               # one Group per (level, layer, word)


def G(level, layer, word, mat):
    key = (level, layer, word)
    if key not in GL:
        GL[key] = H.Group("%s_%s_%s_%s_LOD0" % (NAME, level, layer, word), MATS[mat], P.CELL_OF[mat])
    return GL[key]


# ----------------------------------------------------------------------------------------------- helpers
def box_on(g, face, a, d, z, along, deep, tall, bevel=0.0):
    """Box on a wall: `a` along the wall, `d` across it (world coordinate), sizes along / deep / tall."""
    if face in ("-Y", "+Y"):
        g.box((a, d, z), (along, deep, tall), bevel)
    else:
        g.box((d, a, z), (deep, along, tall), bevel)


def opening(face, outer, a0, a1, z0, z1, frame, glass=None, bar=0.3, mullion=True, sill=None, head=True):
    """Frame bars inside the wall opening (the opening is exactly a0..a1 x z0..z1, so there are no gaps) and a pane.
    With `sill`: a 0.3-proud surround on the wall face (head bar unless head=False) and a 0.5-proud studded sill brick, both
    0.05 into the wall and 0.05 over the opening edge (no coplanar faces); the pane then sits 0.9 behind the surround."""
    sgn = 1.0 if face in ("-Y", "-X") else -1.0           # direction into the wall
    d = outer + sgn * 0.6
    a, w, z, h = (a0 + a1) / 2.0, a1 - a0, (z0 + z1) / 2.0, z1 - z0
    if glass is not None and sill is not None:
        sb, ds = 0.3, outer - sgn * 0.125                 # surround bar width; depth centre (0.3 proud .. 0.05 in)
        zt = z1 - 0.05 if head else z1
        if head:
            box_on(frame, face, a, ds, z1 + (sb - 0.05) / 2.0, w + 2 * sb, 0.35, sb + 0.05, 0.04)
        for s in (-1, 1):
            box_on(frame, face, a + s * (w / 2.0 + (sb - 0.05) / 2.0), ds, (z0 + 0.05 + zt) / 2.0, sb + 0.05, 0.35,
                   zt - z0 - 0.05, 0.04)
        box_on(sill, face, a, outer - sgn * 0.225, z0 - 0.175, w + 0.9, 0.55, 0.45, 0.04)
        for s in (-1, 1):
            p = (a + s * w / 4.0, outer - sgn * 0.25)
            sill.stud(*(p if face in ("-Y", "+Y") else p[::-1]), z0 + 0.05, 0.22, 0.25, 6)
    box_on(frame, face, a, d, z1 - bar / 2.0, w, 1.2, bar)
    if glass is not None:
        box_on(frame, face, a, d, z0 + bar / 2.0, w, 1.2, bar)
        for s in (-1, 1):
            box_on(frame, face, a + s * (w / 2.0 - bar / 2.0), d, z, bar, 1.2, h - 2 * bar)
        if mullion and w >= 3.5:
            box_on(frame, face, a, d, z, 0.24, 0.7, h - 2 * bar)
        box_on(glass, face, a, d, z, w - 2 * bar, 0.12, h - 2 * bar)
    else:                                                  # doorway: jambs and a lintel strip, the leaf is separate
        for s in (-1, 1):
            box_on(frame, face, a + s * (w / 2.0 - bar / 2.0), d, z, bar, 1.2, h)
        box_on(frame, face, a, d, z1 - bar / 2.0, w, 1.2, bar)


def shell(skins, core, x0, x1, y0, y1, zb, n, holes, skip=()):
    """Four walls: n courses of 1x4 skin panels (skins[i] is course i's Group) over a cream core. Front is -Y.
    holes = {'F': [...], 'B': ..., 'L': ..., 'R': ...} in wall-length coordinates (x for F/B, y for L/R)."""
    for i in range(n):
        z0, z1 = zb + i * CH, zb + (i + 1) * CH - GROOVE
        kw = dict(gap=GROOVE, brick=BRICK, bevel=0.0, phase=(i % 2) * BRICK / 2.0)
        g = skins[i]
        H.face_run(g, x0, x1, z0, z1, y0 + TS / 2, 'x', TS, holes.get('F', ()), **kw)
        H.face_run(g, x0, x1, z0, z1, y1 - TS / 2, 'x', TS, holes.get('B', ()), **kw)
        if 'L' not in skip:
            H.face_run(g, y0 + TS, y1 - TS, z0, z1, x0 + TS / 2, 'y', TS, holes.get('L', ()), **kw)
        if 'R' not in skip:
            H.face_run(g, y0 + TS, y1 - TS, z0, z1, x1 - TS / 2, 'y', TS, holes.get('R', ()), **kw)
    zt = zb + n * CH - GROOVE
    xa = x0 if 'L' in skip else x0 + TS
    xb = x1 if 'R' in skip else x1 - TS
    H.solid_wall(core, xa, xb, zb, zt, y0 + TS + TC / 2, 'x', TC, holes.get('F', ()))
    H.solid_wall(core, xa, xb, zb, zt, y1 - TS - TC / 2, 'x', TC, holes.get('B', ()))
    if 'L' not in skip:
        H.solid_wall(core, y0 + TS + TC, y1 - TS - TC, zb, zt, x0 + TS + TC / 2, 'y', TC, holes.get('L', ()))
    if 'R' not in skip:
        H.solid_wall(core, y0 + TS + TC, y1 - TS - TC, zb, zt, x1 - TS - TC / 2, 'y', TC, holes.get('R', ()))


def sign_board(frame, face, red, white, cx, face_y, cz, w, h, major, bz, minor=0.3):
    """Framed navy plaque on a wall plane face_y (front is -Y) with the red lifebuoy icon (OD 2 * major + 0.6) at
    height bz: r3 keeps the buoy above the band where the game lays its white name ribbon (att z -1.65 .. -0.55)."""
    frame.box((cx, face_y - 0.15, cz), (w + 0.6, 0.3, h + 0.6), 0.0)
    face.box((cx, face_y - 0.35, cz), (w, 0.1, h), 0.0)
    buoy(red, white, (cx, face_y - 0.62, bz), major, minor=minor, segs=12, minor_segs=4)


def gable(roof, cap, ridge, studs, lines, cx, cy, length, half, rise, z0, n_lines, over=0.0, cap_h=1.0, cap_w=2.4, stud_r=0.5):
    """Red pitched roof along X (slopes face -Y / +Y), a white ridge cap (`over` past each gable end), darker course
    lines, and rows of red tile studs between the lines (running bond, 0.05 sunk).
    r5 cap (matches the L3 hall): stepped 2-stud white segments in `ridge` (a cap_w tier, a 0.7 narrower tier, one red
    stud each, 0.05 seams) between red end caps; `cap` keeps one inner core box for LOD2.
    Studs and end caps go to `studs`; `studs` and `ridge` are LOD0/LOD1 only (see add_lods)."""
    slope, top = rise / half, 1.0
    zc = z0 + rise - slope * top
    roof.prism([(cy - half, z0), (cy + half, z0), (cy + top, zc), (cy - top, zc)], length, axis='X', at=cx)
    zb, run, e = zc - 0.05, length + 2 * over, 0.5
    cap.box((cx, cy, zb - 0.05 + cap_h / 2), (run - 0.1, cap_w - 0.8, cap_h), 0.0)      # core, inside the segments
    for sx in (-1, 1):
        studs.box((cx + sx * (run - e) / 2, cy, zb - 0.05 + cap_h / 2 + 0.025), (e, cap_w + 0.2, cap_h + 0.05), 0.04)
    n = max(1, round((run - 2 * e) / 2.0))
    sl = (run - 2 * e) / n
    t1 = cap_h * 0.6
    for i in range(n):
        m = cx - run / 2 + e + (i + 0.5) * sl
        ridge.box((m, cy, zb + t1 / 2), (sl - 0.05, cap_w, t1), 0.03)
        ridge.box((m, cy, zb + (t1 - 0.05 + cap_h) / 2), (sl - 0.25, cap_w - 0.7, cap_h - t1 + 0.05), 0.03)
        studs.stud(m, cy, zb + cap_h, stud_r, 0.4, 6)
    a = math.atan(slope)
    gap = (half - top) / (n_lines + 1)
    for k in range(n_lines + 1):
        d = half - (k + 0.5) * gap
        z = z0 + slope * (half - d)
        nx = int((length - 1.8) // 2.0) - (k % 2)
        for s in (-1, 1):
            n = Vector((0.0, s * math.sin(a), math.cos(a)))
            for i in range(nx + 1):
                x = cx - (nx * 2.0) / 2.0 + i * 2.0
                studs.cyl(Vector((x, cy + s * d, z)) + n * 0.15, 0.42, 0.4, segs=6, rot=Matrix.Rotation(-s * a, 4, 'X'))
    for k in range(1, n_lines + 1):
        d = half - k * (half - top) / (n_lines + 1)          # distance from the ridge axis
        z = z0 + slope * (half - d)
        for s in (-1, 1):                                    # s=-1 front slope (rises toward +Y), +1 back slope
            n = Vector((0.0, s * math.sin(a), math.cos(a)))
            lines.box(Vector((cx, cy + s * d, z)) + n * 0.01, (length + 0.04, 0.14, 0.05), 0.0,
                      rot=Matrix.Rotation(-s * a, 4, 'X'))
    return zc - 0.05 + cap_h


def buoy(red, white, centre, major=1.3, minor=0.34, segs=12, minor_segs=5):
    c = Vector(centre)
    red.torus(c, major, minor, segs=segs, minor_segs=minor_segs, axis='Y')
    for k in range(4):
        a = math.radians(45.0 + 90.0 * k)
        white.box(c + Vector((major * math.cos(a), 0.0, major * math.sin(a))), (0.5, 0.5, 0.8), 0.0,
                  rot=Matrix.Rotation(-a, 4, 'Y'))


def buoy_wall(red, white, centre, major=1.3):
    """Interior lifebuoy hung on a side wall (ring in the YZ plane)."""
    c = Vector(centre)
    red.torus(c, major, 0.34, segs=10, minor_segs=4, axis='X')
    for k in range(4):
        a = math.radians(45.0 + 90.0 * k)
        white.box(c + Vector((0.0, major * math.cos(a), major * math.sin(a))), (0.5, 0.8, 0.5), 0.0,
                  rot=Matrix.Rotation(a, 4, 'X'))


def bell(steel, gold, x, y, base_z, post_h, inward=-1.0):
    steel.cyl((x, y, base_z + post_h / 2.0), 0.28, post_h, segs=8)
    steel.box((x + inward * 0.8, y, base_z + post_h - 0.15), (2.4, 0.32, 0.32), 0.0)
    bx = x + inward * 1.55
    gold.cyl((bx, y, base_z + post_h - 0.85), 0.8, 1.15, segs=10, radius_top=0.48)
    gold.cyl((bx, y, base_z + post_h - 0.2), 0.24, 0.55, segs=8)
    gold.cyl((bx, y, base_z + post_h - 1.55), 0.2, 0.45, segs=8)


def stud_row(g, pts, z, r=0.6, segs=6):
    for x, y in pts:
        g.stud(x, y, z, r, 0.4, segs)


def skin_groups(level, layer_of, n):
    """Course 0 red 'BaseCourse' (L01), the rest white 'Walls' (layer_of(i))."""
    return [G(level, "L01", "BaseCourse", "Red") if i == 0 else G(level, layer_of(i), "Walls", "White")
            for i in range(n)]


# ----------------------------------------------------------------------------------------------------- Lv1
def interior_lv1(L):
    """Radio desk, chart table; on the walls: chart board, clock, lifebuoy, life-jacket hooks. Inner faces x +-10.8, y +-7.8."""
    wood, navy, steel = G(L, "L03", "Wood", "Wood"), G(L, "L03", "Radio", "Navy"), G(L, "L03", "Steel", "Steel")
    gold, red, white = G(L, "L03", "Dials", "Gold"), G(L, "L03", "Red", "Red"), G(L, "L03", "White", "White")
    sea, cork, yellow = G(L, "L03", "Sea", "Sea"), G(L, "L03", "Cork", "Tan"), G(L, "L03", "Jackets", "Yellow")
    top = 4.4
    # radio desk: back-left corner, set + headset on top
    wood.box((-7.4, 6.8, 2.75), (6.0, 2.0, 3.3), 0.0)
    wood.box((-7.4, 6.8, top + 0.1), (6.4, 2.2, 0.2), 0.0)
    navy.box((-8.4, 7.0, top + 0.2 + 0.55), (2.8, 1.2, 1.1), 0.0)
    navy.box((-8.4, 6.35, top + 0.2 + 0.3), (2.8, 0.1, 0.5), 0.0)
    steel.cyl((-9.2, 6.35, top + 1.0), 0.18, 0.2, segs=6, axis='Y')
    steel.cyl((-7.6, 6.35, top + 1.0), 0.18, 0.2, segs=6, axis='Y')
    steel.cyl((-9.6, 7.3, top + 1.1 + 0.9), 0.07, 1.8, segs=4)                       # antenna stub
    gold.cyl((-8.4, 6.35, top + 1.0), 0.28, 0.2, segs=8, axis='Y')                   # tuning dial
    red.box((-7.0, 6.35, top + 0.95), (0.4, 0.1, 0.4), 0.0)                          # call lamp (flat, no glow)
    steel.box((-5.8, 6.8, top + 0.2 + 0.1), (0.5, 0.5, 0.2), 0.0)                    # mic base
    steel.cyl((-5.8, 6.8, top + 0.75), 0.07, 1.1, segs=4)
    navy.box((-5.8, 6.55, top + 1.3), (0.4, 0.5, 0.3), 0.0)
    navy.torus((-5.0, 6.6, top + 0.2 + 0.7), 0.5, 0.1, segs=8, minor_segs=4, axis='X')   # headset band
    for s in (-0.5, 0.5):
        navy.cyl((-5.0, 6.6 + s, top + 0.2 + 0.6), 0.28, 0.25, segs=8, axis='Y')    # ear cups
    # chart table: back centre, sea chart on top
    wood.box((0.0, 6.8, 2.75), (6.0, 2.0, 3.3), 0.0)
    wood.box((0.0, 6.8, top + 0.1), (6.4, 2.2, 0.2), 0.0)
    white.box((0.0, 6.8, top + 0.24), (5.0, 1.8, 0.08), 0.0)
    sea.box((-0.2, 6.8, top + 0.3), (4.4, 1.4, 0.06), 0.0)
    cork.box((-1.2, 6.9, top + 0.35), (1.3, 0.7, 0.06), 0.0)                         # island on the chart
    cork.box((1.2, 6.6, top + 0.35), (0.8, 0.5, 0.06), 0.0)
    for i in range(3):
        red.box((-0.3 + i * 0.7, 6.75 - 0.15 * i, top + 0.4), (0.4, 0.14, 0.06), 0.0)   # route marks
    # chart board 4 x 3 above the chart table (back wall), round clock beside it
    navy.box((0.0, 7.72, 6.9), (4.4, 0.16, 3.4), 0.0)
    sea.box((0.0, 7.6, 6.9), (4.0, 0.1, 3.0), 0.0)
    cork.box((-0.9, 7.53, 7.4), (1.4, 0.06, 0.9), 0.0)
    cork.box((1.1, 7.53, 6.2), (0.8, 0.06, 0.6), 0.0)
    for i in range(3):
        red.box((-0.6 + i * 0.6, 7.5, 6.9 - 0.25 * i), (0.36, 0.06, 0.14), 0.0)        # route marks
    navy.cyl((-3.9, 7.74, 7.6), 0.85, 0.12, segs=10, axis='Y')
    white.cyl((-3.9, 7.64, 7.6), 0.7, 0.1, segs=10, axis='Y')
    navy.box((-3.9, 7.57, 7.85), (0.1, 0.04, 0.55), 0.0)                             # hands at 3 o'clock
    navy.box((-3.7, 7.57, 7.6), (0.45, 0.04, 0.12), 0.0)
    # west wall: lifebuoy, a hook rail with two yellow life jackets
    buoy_wall(red, white, (-10.4, 2.0, 5.4))
    wood.box((-10.7, -2.0, 6.95), (0.2, 3.8, 0.3), 0.0)
    for y in (-3.0, -1.0):
        steel.box((-10.45, y, 6.85), (0.4, 0.12, 0.12), 0.0)
        yellow.box((-10.5, y, 5.65), (0.5, 1.5, 2.0), 0.04)
        navy.box((-10.24, y, 6.4), (0.04, 0.5, 0.5), 0.0)                             # neck opening
        navy.box((-10.24, y, 5.0), (0.04, 1.52, 0.18), 0.0)                           # straps
        navy.box((-10.24, y, 5.5), (0.04, 1.52, 0.18), 0.0)


def build_lv1():
    L = "Lv1"
    lv1 = bpy.data.objects.new("Lv1", None)
    bpy.context.scene.collection.objects.link(lv1)
    g_plinth, g_floor, g_runner = G(L, "L01", "Plinth", "Plinth"), G(L, "L01", "Floor", "Tan"), G(L, "L01", "Runner", "Red")
    g_core = G(L, "L02", "Core", "Cream")
    g_frames, g_glass = G(L, "L02", "Frames", "Navy"), G(L, "L02", "Glass", "Glass")
    g_door = G(L, "L02", "OwnerColour_Door", "OwnerColour")
    g_dfr, g_sill = G(L, "L02", "DoorFrame", "Red"), G(L, "L02", "Sills", "Red")   # r5: red studded sills
    g_roof, g_cap, g_lines = G(L, "L04", "Roof", "Red"), G(L, "L04", "Trim", "White"), G(L, "L04", "Lines", "RoofLine")
    g_steel, g_white, g_red = G(L, "L05", "Steel", "Steel"), G(L, "L05", "Trim", "White"), G(L, "L05", "Red", "Red")
    g_gold, g_navy = G(L, "L05", "Bell", "Gold"), G(L, "L05", "Navy", "Navy")

    # plinth ring 26.6 x 22, front step, studs (kept off the doorway, the flag pole and the bell post)
    g_plinth.box((0.0, 0.0, 0.5), (26.6, 22.0, 1.0), 0.1)
    g_plinth.box((0.0, -11.9, 0.25), (8.0, 1.8, 0.5), 0.08)
    stud_row(g_plinth, [(x, -10.0) for x in (-9.0, -6.4, 6.4, 9.0)], FLOOR)
    stud_row(g_plinth, [(x, 10.0) for x in (-10.8, -7.2, -3.6, 0.0, 3.6, 7.2, 10.8)], FLOOR)
    stud_row(g_plinth, [(s * 12.65, y) for s in (-1, 1) for y in (-6.0, 6.0)], FLOOR)
    # floor: tan slab + doorway thresholds + red runner (the walkway)
    g_floor.box((0.0, 0.0, FLOOR + 0.05), (21.6, 15.6, 0.1), 0.0)
    g_floor.box((0.0, -8.4, FLOOR + 0.05), (6.0, 2.4, 0.1), 0.0)
    g_floor.box((11.6, 0.0, FLOOR + 0.05), (3.4, 6.0, 0.1), 0.0)
    g_runner.box((0.0, -3.4, FLOOR + 0.13), (3.2, 12.4, 0.06), 0.0)

    # walls: openings sized to the frames
    FZ0, FZ1 = FLOOR + 2 * CH, FLOOR + 5 * CH           # front windows 3.2 .. 6.5
    BZ0 = FLOOR + 3 * CH                                  # back / side windows 4.3 .. 6.5
    holes = {'F': [(-3.0, 3.0, FLOOR, FLOOR + DOOR_H), (-11.0, -7.0, FZ0, FZ1), (4.2, 8.8, FZ0, FZ1)],
             'B': [(-9.2, -5.6, BZ0, FZ1), (3.8, 7.4, BZ0, FZ1)],
             'L': [(4.6, 7.4, FZ0, FZ1), (-7.4, -4.6, FZ0, FZ1)],
             'R': [(-3.0, 3.0, FLOOR, FLOOR + DOOR_H), (4.8, 7.4, FZ0, FZ1), (-7.4, -4.8, FZ0, FZ1)]}
    shell(skin_groups(L, lambda i: "L02" if i < 4 else "L03", N1), g_core, -12.0, 12.0, -9.0, 9.0, FLOOR, N1, holes)
    for a0, a1 in ((-11.0, -7.0), (4.2, 8.8)):
        opening("-Y", -9.0, a0, a1, FZ0, FZ1, g_frames, g_glass, sill=g_sill)
    for a0, a1 in ((-9.2, -5.6), (3.8, 7.4)):
        opening("+Y", 9.0, a0, a1, BZ0, FZ1, g_frames, g_glass, sill=g_sill)
    for a0, a1 in ((4.6, 7.4), (-7.4, -4.6)):
        opening("-X", -12.0, a0, a1, FZ0, FZ1, g_frames, g_glass, sill=g_sill)
    for a0, a1 in ((4.8, 7.4), (-7.4, -4.8)):
        opening("+X", 12.0, a0, a1, FZ0, FZ1, g_frames, g_glass, sill=g_sill)
    opening("-Y", -9.0, -3.0, 3.0, FLOOR, FLOOR + DOOR_H, g_dfr)
    opening("+X", 12.0, -3.0, 3.0, FLOOR, FLOOR + DOOR_H, g_frames)
    # big red portal round the front doorway: 0.4-proud jambs and lintel (0.05 into the wall and over the opening)
    for s in (-1, 1):
        g_dfr.box((s * 3.325, -9.175, FLOOR + 3.725), (0.75, 0.45, 7.45), 0.06)
    g_dfr.box((0.0, -9.175, FLOOR + DOOR_H + 0.4), (5.9, 0.45, 0.9), 0.06)
    for s in (-1, 1):                                     # r3: leaves swung open 110 deg outward so their faces show
        a = math.radians(20.0)                            # past 90: the leaf leans 20 deg away from the opening
        u, n = Vector((s * math.sin(a), -math.cos(a), 0.0)), Vector((-s * math.cos(a), -math.sin(a), 0.0))
        rot = Matrix.Rotation(s * a, 4, 'Z')              # leaf length along u, its outer face along n (toward -Y)
        hinge = Vector((s * 3.75, -9.65, FLOOR + 3.25))   # clear of the portal, sills and plinth top
        g_door.box(hinge + u * 1.0 - n * 0.15, (0.3, 2.0, 6.4), 0.04, rot=rot)
        g_door.box(hinge + u * 1.0 + n * 0.04, (0.1, 1.3, 3.6), 0.0, rot=rot)

    # one solid red gable: flat white ridge cap with a stud row, faint course lines on both slopes
    gable(g_roof, g_cap, G(L, "L04", "Ridge", "White"), G(L, "L04", "Studs", "Red"), g_lines, 0.0, 0.0, 25.2, 9.6, 3.0, E1, 4,
          over=0.04,
          cap_h=1.35, cap_w=2.8, stud_r=0.6)   # r4: taller, wider cap clears the tile studs from the path; Lv2 storey hides it

    # facade fittings: flag pole at the front-left corner, bell right, lifebuoy beside the door, blank sign
    g_steel.box((-12.2, -10.2, FLOOR + 0.3), (1.2, 1.2, 0.6), 0.04)
    FZ = 18.6                                                                        # r5: pole 3 taller (19), flag with it
    g_steel.cyl((-12.2, -10.2, FLOOR + 9.5), 0.3, 19.0, segs=8)
    g_red.box((-12.2 + 2.15, -10.2, FZ), (4.0, 0.16, 2.5), 0.0)
    g_white.torus((-10.05, -10.3, FZ), 0.72, 0.17, segs=12, minor_segs=4, axis='Y')
    for k in range(4):
        a = math.radians(45.0 + 90.0 * k)
        g_red.box((-10.05 + 0.72 * math.cos(a), -10.34, FZ + 0.72 * math.sin(a)), (0.3, 0.1, 0.3), 0.0)
    buoy(g_red, g_white, (-5.35, -9.8, 5.2), major=0.9, minor=0.3, minor_segs=4)    # between window and portal
    g_steel.box((-5.35, -9.3, 6.2), (0.3, 0.6, 0.3), 0.0)                            # its peg
    g_navy.box((0.0, -9.36, 8.7), (3.0, 0.72, 2.0), 0.0)                             # bracket under the eave
    sign_board(g_red, g_navy, g_red, g_white, 0.0, -9.72, 10.2, 6.6, 4.7, 1.3, 10.7, minor=0.39)   # r5: buoy 1.3x
    # face 7.85..12.55, ribbon 7.8..8.9, buoy 9.01..12.39
    bell(g_steel, g_gold, 11.4, -10.0, FLOOR, 4.4, inward=-1.0)
    interior_lv1(L)

    att = bpy.data.objects.new("ATT_Sign_01", None)
    att.location = (0.0, -10.12, 9.45)
    bpy.context.scene.collection.objects.link(att)
    return lv1, att


# ----------------------------------------------------------------------------------------------------- Lv2
def interior_wing(L):
    """Medic counter on the east wall (inner face x 18.8): white front with a red cross, first-aid box hung above."""
    white, red, grey = G(L, "L02", "White", "White"), G(L, "L02", "Red", "Red"), G(L, "L02", "Top", "Plinth")
    white.box((17.9, 0.0, 2.75), (1.8, 5.6, 3.3), 0.0)
    grey.box((17.9, 0.0, 4.5), (2.0, 6.0, 0.2), 0.05)
    red.box((16.97, 0.0, 2.9), (0.06, 1.8, 0.5), 0.0)
    red.box((16.97, 0.0, 2.9), (0.06, 0.5, 1.8), 0.0)
    white.box((18.4, -2.6, 6.0), (0.8, 1.3, 1.1), 0.04)                              # first-aid box beside the window
    red.box((17.98, -2.6, 6.0), (0.04, 0.8, 0.24), 0.0)
    red.box((17.98, -2.6, 6.0), (0.04, 0.24, 0.8), 0.0)


def build_lv2():
    L = "Lv2"
    lv2 = bpy.data.objects.new("Lv2", None)
    bpy.context.scene.collection.objects.link(lv2)
    # --- wing: 8 studs east of the hut, open through the Lv1 east doorway
    g_wp, g_wf = G(L, "L01", "Plinth", "Plinth"), G(L, "L01", "Floor", "Tan")
    g_core, g_frames, g_glass = G(L, "L02", "Core", "Cream"), G(L, "L02", "Frames", "Navy"), G(L, "L02", "Glass", "Glass")
    g_wroof = G(L, "L02", "Roof", "Red")
    g_wp.box((17.15, 0.0, 0.5), (7.7, 11.8, 1.0), 0.1)                              # x 13.3 .. 21.0
    stud_row(g_wp, [(20.4, y) for y in (-4.8, 0.0, 4.8)], FLOOR)
    g_wf.box((14.8, 0.0, FLOOR + 0.05), (8.0, 6.8, 0.1), 0.0)                       # x 10.8 .. 18.8
    wz1 = FLOOR + 5 * CH
    wholes = {'F': [(13.0, 16.2, FLOOR + 2 * CH, wz1)], 'R': [(-1.8, 1.8, FLOOR + 2 * CH, wz1)]}
    shell(skin_groups(L, lambda i: "L02", 6), g_core, 12.0, 20.0, -4.6, 4.6, FLOOR, 6, wholes, skip=('L',))
    g_wsill = G(L, "L02", "Sills", "Plinth")
    opening("-Y", -4.6, 13.0, 16.2, FLOOR + 2 * CH, wz1, g_frames, g_glass, sill=g_wsill)
    opening("+X", 20.0, -1.8, 1.8, FLOOR + 2 * CH, wz1, g_frames, g_glass, sill=g_wsill)
    g_wroof.box((16.2, 0.0, FLOOR + 6 * CH + 0.3), (8.8, 9.8, 0.6), 0.06)
    gable(g_wroof, G(L, "L02", "RoofTrim", "White"), G(L, "L02", "Ridge", "White"), G(L, "L02", "RoofStuds", "Red"),
          G(L, "L02", "RoofLines", "RoofLine"), 16.2, 0.0, 8.8, 4.9, 1.4, FLOOR + 6 * CH + 0.55, 2, over=0.4)   # r3: tile studs + ridge cap; 0.05 into the slab
    interior_wing(L)
    # the link is Lv1's east doorway (5.4 clear between the jambs, floor to wing ceiling); a red runner leads to the counter
    G(L, "L01", "Runner", "Red").box((14.0, 0.0, FLOOR + 0.13), (5.6, 3.2, 0.06), 0.0)
    # street face: white 3x3 plaque with a red cross beside the window
    G(L, "L02", "White", "White").box((18.1, -4.75, FLOOR + 3.85), (3.0, 0.3, 3.0), 0.04)
    for sz in ((2.2, 0.1, 0.7), (0.7, 0.1, 2.2)):
        G(L, "L02", "Red", "Red").box((18.1, -4.93, FLOOR + 3.85), sz, 0.0)

    # --- one red course over the hut eave, then the upper storey on the band's footprint (it hides the hut roof)
    g_band = G(L, "L03", "Band", "Red")
    X2, Y2 = 12.7, 9.7
    g_band.box((0.0, 0.0, E1 + CH / 2.0), (2 * X2, 2 * Y2, CH), 0.06)
    s0 = E1 + CH                                        # 10.9
    G(L, "L03", "Floor", "Tan").box((0.0, 0.0, 13.9), (23.0, 16.8, 0.3), 0.0)    # seen through the window band
    NS, WB0, WB1 = 6, s0 + 3 * CH, s0 + 6 * CH          # window band = courses 3..5 (14.2 .. 17.5), deck on top
    sh = {'F': [(-10.5, 10.5, WB0, WB1)], 'B': [(-10.5, 10.5, WB0, WB1)],
          'L': [(-7.5, 7.5, WB0, WB1)], 'R': [(-7.5, 7.5, WB0, WB1)]}
    shell([G(L, "L04", "Walls", "White")] * NS, G(L, "L04", "Core", "Plinth"), -X2, X2, -Y2, Y2, s0, NS, sh)
    f4, g4 = G(L, "L04", "Frames", "Navy"), G(L, "L04", "Glass", "Glass")
    for face, outer, (a0, a1, _, _) in (("-Y", -Y2, sh['F'][0]), ("+Y", Y2, sh['B'][0]),
                                        ("-X", -X2, sh['L'][0]), ("+X", X2, sh['R'][0])):
        opening(face, outer, a0, a1, WB0, WB1, f4, g4, mullion=False, sill=G(L, "L04", "Sills", "Plinth"), head=False)
        n = max(2, round((a1 - a0) / 3.6))
        sgn = 1.0 if face in ("-Y", "-X") else -1.0
        for i in range(1, n):
            box_on(f4, face, a0 + i * (a1 - a0) / n, outer + sgn * 0.6, (WB0 + WB1) / 2.0, 0.3, 1.0, WB1 - WB0 - 0.6)

    # --- roof deck: white studded deck edged with red studded plates, a flat lifebuoy on a navy disc
    zd = s0 + NS * CH                                   # 17.5
    g_deck, g_edge = G(L, "L05", "Deck", "Red"), G(L, "L05", "Edge", "White")
    g_em_r, g_em_w = G(L, "L05", "Emblem", "Red"), G(L, "L05", "Trim", "White")
    DX, DY, EW = X2 + 0.2, Y2 + 0.2, 2.0
    g_deck.box((0.0, 0.0, zd + 0.3), (2 * DX, 2 * DY, 0.6), 0.08)
    ztop = zd + 0.6
    for sy in (-1, 1):
        g_edge.box((0.0, sy * (DY - EW / 2), ztop + 0.2), (2 * DX, EW, 0.4), 0.04)
    for sx in (-1, 1):
        g_edge.box((sx * (DX - EW / 2), 0.0, ztop + 0.2), (EW, 2 * DY - 2 * EW, 0.4), 0.04)
    ex, ey = DX - 1.5, DY - 1.5                         # inner stud of the rim; the outer stud carries the parapet
    ring = [(x * ex / 4.0, sy * ey) for x in range(-4, 5) for sy in (-1, 1)]
    ring += [(sx * ex, y * ey / 3.0) for y in range(-2, 3) for sx in (-1, 1)]
    stud_row(G(L, "L05", "EdgeStuds", "White"), [(x, y) for x, y in ring if not (y < 0 and abs(x) < 8.6)], ztop + 0.4, r=0.45)
    g_par = G(L, "L05", "Parapet", "Red")                 # r3: red 1x2 bricks, 0.1 seams, a stud each (front gap: plaque)
    pz, pts_p = ztop + 0.35, []
    px, py = 2 * DX / 13, 2 * (DY - 1.0) / 9            # front/back run the full width, the sides fit between them
    for sy in (-1, 1):
        for i in range(13):
            x = -DX + px * (i + 0.5)
            if sy < 0 and abs(x) < 5.0:
                continue
            g_par.box((x, sy * (DY - 0.5), pz + 0.35), (px - 0.1, 1.0, 0.7), 0.05)
            pts_p.append((x, sy * (DY - 0.5)))
    for sx in (-1, 1):
        for i in range(9):
            y = -(DY - 1.0) + py * (i + 0.5)
            g_par.box((sx * (DX - 0.5), y, pz + 0.35), (1.0, py - 0.1, 0.7), 0.05)
            pts_p.append((sx * (DX - 0.5), y))
    stud_row(G(L, "L05", "ParapetStuds", "Red"), pts_p, pz + 0.7, r=0.4)
    fx = DX - EW                                        # tile field x -10.9 .. 10.9, course lines between stud rows
    for y in (-4.2, -0.6, 3.0, 6.6):
        G(L, "L05", "Lines", "RoofLine").box((0.0, y, ztop + 0.025), (2 * fx, 0.16, 0.05), 0.0)
    ecx, ecy, mx, my, cl = -4.6, 5.55, 8.6, 6.6, (2.0, 6.6)
    pts = [(x, y) for x in (-9.0, -5.4, -1.8, 1.8, 5.4, 9.0) for y in (-6.0, -2.4, 1.2, 4.8)
           if not (abs(x) < 9.8 and y < 3.6) and (abs(x - ecx) > 2.8 or abs(y - ecy) > 2.8)
           and math.hypot(x - mx, y - my) > 2.6 and math.hypot(x - cl[0], y - cl[1]) > 1.6]
    stud_row(g_deck, pts, ztop)
    g_em_w.box((ecx, ecy, ztop + 0.1), (4.0, 4.0, 0.2), 0.04)                        # white 4x4 pad
    G(L, "L05", "Navy", "Navy").cyl((ecx, ecy, ztop + 0.25), 1.15, 0.1, segs=12)
    g_em_r.torus((ecx, ecy, ztop + 0.5), 1.45, 0.34, segs=16, minor_segs=4, axis='Z')
    for k in range(4):
        a = math.radians(45.0 + 90.0 * k)
        g_em_w.box((ecx + 1.45 * math.cos(a), ecy + 1.45 * math.sin(a), ztop + 0.5), (0.8, 0.6, 0.72), 0.0,
                   rot=Matrix.Rotation(a, 4, 'Z'))

    # --- watch room on a pedestal (lifebuoy sign on its front), striped posts, glass, small red pitched roof
    base = ztop
    wx0, wx1, wy0, wy1 = -8.0, 8.0, -8.6, 1.6
    PED = 3.6
    g_ped, g_sill = G(L, "L06", "Pedestal", "White"), G(L, "L06", "Sill", "Navy")
    g_pr, g_pw = G(L, "L06", "Stripes", "Red"), G(L, "L06", "Posts", "White")
    g_gl, g_cap = G(L, "L06", "Glass", "Glass"), G(L, "L06", "Roof", "Red")
    g_ctrim, g_lines = G(L, "L06", "Trim", "White"), G(L, "L06", "Lines", "RoofLine")
    g_ped.box(((wx0 + wx1) / 2, (wy0 + wy1) / 2, base + PED / 2), (wx1 - wx0 + 0.4, wy1 - wy0 + 0.4, PED), 0.08)
    # r4: a 1.5x board (navy 11.1 x 4.6, chunky red frame 0.5, 0.35 proud, studded top rail) on two navy brackets,
    # proud of the pedestal and the sill (back y -9.06). The game ribbon (base+0.35..1.45, y -9.3..-9.6) lies on the
    # face and the bottom rail (front -9.55; the deck rim hides it below base+0.4); the buoy (OD 3.32) clears the band.
    fy = -9.2                                                                         # navy face front
    for s in (-1, 1):
        g_sill.box((s * 3.6, -8.925, base + 2.2), (0.8, 0.35, 2.4), 0.04)            # brackets into the pedestal
    g_sill.box((0.0, -9.13, base + 2.9), (11.1, 0.14, 4.6), 0.0)                     # face base+0.6..5.2
    g_sr = G(L, "L06", "SignFrame", "Red")
    g_sr.box((0.0, -9.325, base + 5.35), (11.9, 0.45, 0.5), 0.05)                     # top rail 5.1..5.6
    g_sr.box((0.0, -9.325, base + 0.525), (11.9, 0.45, 0.65), 0.05)                   # bottom rail 0.2..0.85
    for s in (-1, 1):
        g_sr.box((s * 5.67, -9.31, base + 2.975), (0.5, 0.42, 4.45), 0.05)            # sides 0.75..5.2, inside the rails
    stud_row(G(L, "L06", "SignStuds", "Red"), [(-4.4 + i * 2.2, -9.325) for i in range(5)], base + 5.6, r=0.35)
    buoy(g_pr, g_pw, (0.0, fy - 0.38, base + 3.35), 1.3, minor=0.36, segs=12, minor_segs=4)   # 1.69..5.01
    # r5: grey course lines (0.04 proud) every 1.2 and staggered head joints every 4 (0.03 proud) on the white pedestal
    g_seam, PX = G(L, "L06", "Seams", "Plinth"), wx1 + 0.2
    for face, d, sg, segs in (("-Y", wy0 - 0.2, -1, ((-PX + 0.1, -6.1), (6.1, PX - 0.1))),
                              ("+Y", wy1 + 0.2, 1, ((-PX + 0.1, PX - 0.1),)),
                              ("-X", -PX, -1, ((wy0 - 0.1, wy1 + 0.1),)), ("+X", PX, 1, ((wy0 - 0.1, wy1 + 0.1),))):
        zs = [base + (0.45 if face == "-Y" else 0.05), base + 1.2, base + 2.4, base + PED - 0.05]   # front: deck rim
        for s0, s1 in segs:
            for z in zs[1:3]:
                box_on(g_seam, face, (s0 + s1) / 2, d + sg * 0.01, z, s1 - s0, 0.06, 0.1)
            for c in range(3):
                k = math.ceil((s0 + 0.3 - 2.0 * (c % 2)) / 4.0)
                while 2.0 * (c % 2) + 4.0 * k < s1 - 0.3:
                    box_on(g_seam, face, 2.0 * (c % 2) + 4.0 * k, d + sg * 0.005, (zs[c] + zs[c + 1]) / 2, 0.1, 0.05,
                           zs[c + 1] - zs[c])
                    k += 1
    wz0 = base + PED
    g_sill.box(((wx0 + wx1) / 2, (wy0 + wy1) / 2, wz0 + 0.2), (wx1 - wx0 + 0.8, wy1 - wy0 + 0.8, 0.4), 0.04)
    for cx in (wx0, wx1):
        for cy in (wy0, wy1):
            for i in range(5):
                (g_pr if i % 2 == 0 else g_pw).box((cx, cy, wz0 + 0.4 + 0.52 + i * 0.52), (0.8, 0.8, 0.52), 0.0)
    wzm = wz0 + 0.4 + 1.5
    for cy in (wy0, wy1):
        g_gl.box((0.0, cy, wzm), (wx1 - wx0 - 0.8, 0.14, 2.6), 0.0)
        for cx in (-wx1 / 3, wx1 / 3):
            g_pw.box((cx, cy, wzm), (0.3, 0.3, 2.6), 0.0)
    for cx in (wx0, wx1):
        g_gl.box((cx, (wy0 + wy1) / 2, wzm), (0.14, wy1 - wy0 - 0.8, 2.6), 0.0)
        g_pw.box((cx, (wy0 + wy1) / 2, wzm), (0.3, 0.3, 2.6), 0.0)
    zr = wz0 + 0.4 + 2.6 + 0.4                          # eave plate on the posts, then the Lv1 gable scaled down
    g_ctrim.box(((wx0 + wx1) / 2, (wy0 + wy1) / 2, zr - 0.2), (wx1 - wx0 + 1.2, wy1 - wy0 + 1.2, 0.4), 0.04)
    half = (wy1 - wy0) / 2 + 1.6                       # 1 stud past the eave plate
    wtop = gable(g_cap, g_ctrim, G(L, "L06", "Ridge", "White"), G(L, "L06", "Studs", "Red"), g_lines, (wx0 + wx1) / 2,
                 (wy0 + wy1) / 2, wx1 - wx0 + 3.2, half, half * 3.0 / 9.6, zr, 3, over=0.4,
                 cap_h=1.3, cap_w=2.6, stud_r=0.5)   # Lv1's slope (3 / 9.6); r5: taller cap, L2's own peak

    # --- signal mast: thin white pole, one yardarm, four pennants on a halyard, flat radar bar on top
    g_st, g_mw, g_mn = G(L, "L07", "Steel", "Steel"), G(L, "L07", "Trim", "White"), G(L, "L07", "Navy", "Navy")
    pen = [G(L, "L07", w, m) for w, m in (("Red", "Red"), ("Yellow", "Yellow"), ("Sea", "Sea"), ("Trim", "White"))]
    MH, YA = 17.0, 15.4                                 # PERF-HQ: tall enough to read over the watch room from the path
    g_mn.box((mx, my, ztop + 0.3), (2.0, 2.0, 0.6), 0.05)
    g_mw.cyl((mx, my, ztop + 0.6 + MH / 2), 0.36, MH, segs=8)
    for zb in (27.0, 29.4, 31.8):                                                    # red bands above the roof line
        pen[0].cyl((mx, my, zb), 0.46, 1.2, segs=8)
    g_mw.box((mx, my, ztop + YA), (5.6, 0.22, 0.22), 0.0)
    top = Vector((mx - 2.7, my, ztop + YA - 0.1))
    bot = Vector((cl[0], cl[1], ztop + 0.6))
    g_mn.box((cl[0], cl[1], ztop + 0.3), (0.8, 0.8, 0.6), 0.0)                       # cleat block on the deck
    d = top - bot
    ln = d.length
    t = Matrix.Rotation(math.atan2(d.x, d.z), 4, 'Y')
    g_st.box((top + bot) / 2, (0.07, 0.07, ln), 0.0, rot=t)
    u = d.normalized()
    out = Vector((-u.z, 0.0, u.x))                      # perpendicular in the XZ plane, away from the mast
    if out.x > 0:
        out = -out
    for i in range(int((ln - 2.6) // 2.4) + 1):
        g = pen[i % 4]
        p0 = top - u * (0.5 + i * 2.4)
        p1 = p0 - u * 2.1
        apex = (p0 + p1) / 2 + out * 1.95
        g.prism([(p0.x, p0.z), (p1.x, p1.z), (apex.x, apex.z)], 0.12, axis='Y', at=my)
    zt = ztop + 0.6 + MH
    g_st.cyl((mx, my, zt + 0.2), 0.3, 0.4, segs=6)
    g_mn.box((mx, my, zt + 0.55), (0.5, 3.0, 0.3), 0.03)                            # radar bar
    pen[0].box((mx + 2.4, my, zt - 0.95), (3.6, 0.12, 2.0), 0.0)                      # masthead flag, faces the path
    g_mw.torus((mx + 2.4, my, zt - 0.95), 0.6, 0.16, segs=12, minor_segs=4, axis='Y')   # white lifebuoy on it

    att = bpy.data.objects.new("ATT_Sign_02", None)
    att.location = (0.0, wy0 - 0.65, base + 2.0)
    bpy.context.scene.collection.objects.link(att)
    return lv2, att


# ------------------------------------------------------------------------------------------- collision, LODs
LOD_FLOOR = {"LOD1": 40, "LOD2": 24}
NO_LOD2 = ("Studs_", "_Parapet_", "_Sills_", "_Ridge_", "_Seams_")   # r3 detail: LOD0/LOD1 only (disjoint bricks have no decimation form; LOD2 <= 3000)


def box_uv(obj, cell):
    me = obj.data
    uv = me.uv_layers.get("UVMap") or me.uv_layers.new(name="UVMap")
    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
    span = [(hi[i] - lo[i]) or 1.0 for i in range(3)]
    for poly in me.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [i for i in range(3) if i != axis]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv = P.cell_uv(cell, (co[a] - lo[a]) / span[a], (co[b] - lo[b]) / span[b])


def add_lods(spec):
    out = []
    for e in [x for x in spec["meshes"] if x.get("role", "visual") == "visual" and x.get("lod", "LOD0") == "LOD0"
              and not x["object"].name.endswith("_COL")]:
        src = e["object"]
        tris = versions.triangles(src.data)
        for lod, floor in LOD_FLOOR.items():
            if lod == "LOD2" and (any(k in src.name for k in NO_LOD2)          # + the Lv1 interior (not seen that far)
                                  or ("_Lv1_L03_" in src.name and "_Walls_" not in src.name)):
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
            box_uv(obj, P.CELL_OF[src.data.materials[0].name[len("MI_"):]])
            versions.weighted_normals(obj)
            entry = {"object": obj, "role": "visual", "lod": lod, "of": src.name}
            if e.get("set"):
                entry["set"] = e["set"]
            out.append(entry)
    spec["meshes"].extend(out)


def collision(level, boxes):
    """One _COL object per box: Roblox hulls a multi-box MeshPart into pieces that fill the doorways."""
    out = []
    for i, (c, s) in enumerate(boxes, 1):
        g = H.Group("%s_%s_Col%02d_COL" % (NAME, level, i), MATS["Plinth"])
        g.box(c, s, 0.0)
        out.append(g.done())
    return out


def span(x0, x1, y0, y1, z0, z1):
    return ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0)


def col_lv1():
    fl, dz = FLOOR + 0.1, FLOOR + DOOR_H
    b = [span(-13.3, 13.3, -11.0, 11.0, 0, fl), span(-4, 4, -12.8, -11.0, 0, 0.5)]                 # floor + step
    b += [span(-12, -3.0, -9, -7.8, fl, E1), span(3.0, 12, -9, -7.8, fl, E1), span(-3.0, 3.0, -9, -7.8, dz, E1)]  # front
    b += [span(-12, 12, 7.8, 9, fl, E1), span(-12, -10.8, -9, 9, fl, E1)]                          # back, west
    b += [span(10.8, 12, -9, -3.0, fl, E1), span(10.8, 12, 3.0, 9, fl, E1), span(10.8, 12, -3.0, 3.0, dz, E1)]  # east
    b += [span(-12.6, 12.6, -9.6, 9.6, E1, E1 + 2.7)]                                              # roof
    b += [span(-10.4, -4.4, 5.8, 7.8, fl, 4.5), span(-3.0, 3.0, 5.8, 7.8, fl, 4.5)]                 # desk, chart table
    return collision("Lv1", b)


def col_lv2():
    fl = FLOOR + 0.1
    b = [span(13.3, 21.0, -5.9, 5.9, 0, fl)]                                                       # wing floor
    b += [span(12, 20, -4.6, -3.4, fl, 7.6), span(12, 20, 3.4, 4.6, fl, 7.6), span(18.8, 20, -4.6, 4.6, fl, 7.6)]
    b += [span(12, 20.4, -4.9, 4.9, 7.6, 8.2), span(16.9, 18.8, -2.9, 2.9, fl, 4.6)]               # wing roof, counter
    b += [span(-12.7, 12.7, -9.7, 9.7, E1, 17.5), span(-12.9, 12.9, -9.9, 9.9, 17.5, 18.5)]       # band + storey, deck
    b += [span(-8.4, 8.4, -9.0, 2.0, 18.1, 25.1), span(-9.7, 9.7, -10.2, 3.2, 24.7, 27.7)]         # watch room, roof
    b += [span(7.6, 9.6, 5.6, 7.6, 18.1, 18.7), span(8.2, 9.0, 6.2, 7.0, 18.7, 35.7)]             # mast base, pole
    return collision("Lv2", b)


def build():
    lv1, att1 = build_lv1()
    lv2, att2 = build_lv2()
    visual = []
    for (level, layer, word), g in GL.items():
        if not g.bm.verts:
            continue
        ob = g.done()
        ob.parent = lv1 if level == "Lv1" else lv2
        visual.append(ob)
    cols = col_lv1() + col_lv2()
    for ob in cols:
        ob.parent = lv1 if "_Lv1_" in ob.name else lv2

    meshes = []
    for ob in visual:
        ob.data.name = ob.name
        meshes.append({"object": ob, "set": "Brick"})
    meshes += [{"object": c} for c in cols]

    pts = [ob.matrix_world @ v.co for ob in visual for v in ob.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = [hi[i] - lo[i] for i in range(3)]
    tris = {lv: sum(versions.triangles(o.data) for o in visual if ("_%s_" % lv) in o.name) for lv in ("Lv1", "Lv2")}
    walls = {lv: sum(versions.triangles(o.data) for o in visual
                     if ("_%s_" % lv) in o.name and ("_Walls_" in o.name or "_Core_" in o.name or "_BaseCourse_" in o.name))
             for lv in ("Lv1", "Lv2")}
    print("[hq] LOD0 tris %s, wall tris (skin+core+base) %s" % (tris, walls))
    print("[hq] bbox studs %.2f x %.2f x %.2f (x %.2f..%.2f, y %.2f..%.2f, z %.2f..%.2f)"
          % (dims[0], dims[1], dims[2], lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))

    spec = {
        "name": NAME, "budget": "hero_building", "tier": "standard",
        "dims_m": (dims[0] / 3.0, dims[1] / 3.0, dims[2] / 3.0),
        "size_note": "Lv1 + Lv2 together incl. the 8-stud east wing, the flag pole and the mast",
        "origin": "free", "tiling": True,
        "sets": [{"name": "RescueHQ", "set": "Brick", "size": 1024, "wet": False}],   # maketex.py, flat palette cells
        "waivers": {"texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_Depot), no PBR scans",
                    "LOD UV layout": "flat palette cells (one colour per mesh): LOD UVs are re-projected inside the "
                                     "same cell, not a unique unwrap (tiling=True skips the density check)"},
        "meshes": meshes, "attachments": [att1, att2],
        "closeups": [
            {"name": "Lv1Door", "target": [0.0, -9.0, 6.0], "dist": 22.0, "az": 24.0, "el": 10.0},
            {"name": "ThroughDoor", "target": [-1.0, 3.0, 3.6], "dist": 22.0, "az": 9.0, "el": 5.0},
            {"name": "Lv2Wing", "target": [16.0, -2.0, 5.0], "dist": 24.0, "az": 58.0, "el": 14.0},
            {"name": "Lv2Watch", "target": [0.0, -4.0, 23.0], "dist": 28.0, "az": 28.0, "el": 14.0},
            {"name": "Lv2Mast", "target": [6.0, 6.6, 25.0], "dist": 30.0, "az": 20.0, "el": 12.0},
            {"name": "Lv2Deck", "target": [0.0, 0.0, 19.0], "dist": 40.0, "az": 200.0, "el": 62.0},
        ],
    }
    add_lods(spec)
    return spec
