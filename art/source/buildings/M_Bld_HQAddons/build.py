"""M_Bld_HQAddons: the HQ's Lv4 radio wing and Lv5 gold beacon tower, Lego style (docs/25 A/B/J; docs/05 2.2, 3, 4, 5).

The Lv1-3 station stays the code-built `station()` in src/shared/DockPieces.luau. This asset adds only the two level
add-ons at the station's final frame: 54 x 32 stud lot, ground at z 0, plinth top 0.5, walls x +/-26 / y +/-15, roof
eave 16 and ridge 25, front -Y, origin the HQ ground centre, 1x (place at the HQ frame with no extra scale).

Lv4 (docs/25 A: "+ radio mast wing"): a walk-in two-storey radio hall built against the station's east wall (the
parapet stays under the station eave, z 16), red and white courses on a tan stud plinth, a navy roof with a white
parapet, a red cap with studs, a door with a navy frame, big front / east / back windows on both storeys, a white
signal plaque and a yellow lifebuoy on the front. Inside (double height): a long white desk with three big dark radio
sets (glass screens, red/green buttons), a big chart board with a cyan sea, tan islands, a red route and yellow pins,
a shelf of binders and two warm ceiling lamps. A red/white lattice mast rises from a white pad on the roof. The floor
stays clear.

Lv5 (docs/25 A: "+ gold beacon tower"): a red/white beacon tower standing east of the wing on its own stud base,
joined to it by a raised bridge (a tan deck resting on the wing's parapet cap, a navy girder with knee braces, Lego
fence panels each side, a step plate on the wing roof) into a second-floor door; two stages (10 + 7 courses, red
bands every fourth course) to 38.6, a red-framed door, a 7 x 10 stud shield crest (gold anchor on navy, red border)
facing the approach, a wide studded balcony with real fence panels (posts, red top rail), and a glazed gold lantern
room: a light-blue pane in every bay up to a gold top rail, an open band above the panes where the lamp head shows,
a trimmed gold eave, a tight red stepped roof and a gold finial. The lamp is a separate mesh (Lv5_L05_Beacon, an
8-sided lens drum with a gold band) so the game can light it. Inside: a ground floor with a notice board and a
second floor (the bridge's landing); the floors stay clear.

Each level is a top-level node (Lv4, Lv5) holding 6 construction layers (L01_* bottom to L06_* top), one palette
mesh per layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). Collision is one simple box per
object, <Node>_ColNN_COL (Roblox hulls each mesh, so a merged proxy would fill the doorway): walls in bites around
the doors, the plinths, floors, roof, desk, mast, balcony, fence, lantern and crest, so the doorways and interiors
stay walkable.

    python3 art/source/buildings/M_Bld_HQAddons/maketex.py \
        --out build/prod/M_Bld_HQAddons/textures/M_Bld_HQAddons --name HQAddons --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_HQAddons/build.py \
        --out-root build/prod/M_Bld_HQAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_HQAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "HQAddons", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_HQAddons_Brick_ALB.png")

# --- Lv4 wing (two storeys, parapet cap under the station eave at z 16)
FLOOR = 0.6
FLOOR_TOP = 0.72
WALL = 0.6
WALL_TOP = 14.55
COURSES = 12
COURSE = (WALL_TOP - FLOOR) / COURSES
WEST_END = 26.4
WX0, WX1 = 26.8, 43.2
WY0, WY1 = -3.0, 9.0
PL_X0, PL_X1 = 26.4, 44.0
PL_Y0, PL_Y1 = -3.8, 9.8
DOOR_X0, DOOR_X1 = 30.4, 36.4
DOOR_TOP = FLOOR + 6 * COURSE
ROOF_X0, ROOF_X1 = 26.4, 43.7
ROOF_Y0, ROOF_Y1 = -3.3, 9.3
ROOF_TOP = 15.05
PAR_TOP = 15.5
CAP_TOP = 15.62
MAST_X, MAST_Y = 36.0, 4.2
PAD_TOP = 15.4
MAST_TOP = 30.5

# --- Lv5 tower (east of the wing, on the same base; walkway between the two plinths)
T_FLOOR = 0.6
T_FLOOR_TOP = 0.72
T_WALL = 0.6
TCX, TCY = 55.0, 3.0
TX0, TX1 = 50.9, 59.1
TY0, TY1 = -1.1, 7.1
QX0, QX1 = 49.0, 61.0
QY0, QY1 = -3.0, 9.0
S1_N, S1_C = 10, 2.2
S1_TOP = T_FLOOR + S1_N * S1_C
F2 = T_FLOOR + 7 * S1_C
LEDGE_TOP = S1_TOP + 0.6
UX0, UX1 = 51.5, 58.5
UY0, UY1 = -0.5, 6.5
U_N, U_C = 7, 2.2
T_TOP = LEDGE_TOP + U_N * U_C
T_DOOR_X0, T_DOOR_X1 = 52.9, 57.1
T_DOOR_TOP = T_FLOOR + 3 * S1_C
W_DY0, W_DY1 = 0.9, 5.1
BX0, BX1 = 49.3, 60.7
BY0, BY1 = -2.7, 8.7
B_Z0, B_Z1 = T_TOP, T_TOP + 0.6
FX0, FX1 = 49.5, 60.5
FY0, FY1 = -2.5, 8.5
RAIL_TOP = B_Z1 + 2.6
LAN_CX, LAN_CY = TCX, TCY
LAN_HALF = 3.5
LAN_Z0, LAN_Z1 = B_Z1 + 0.9, B_Z1 + 6.6
PANE_TOP = LAN_Z1 - 2.0
LAMP_Z0 = LAN_Z0 + 1.0
CREST_Z1, CREST_W, CREST_H = 19.6, 7.0, 10.0
BR_X0, BR_X1 = ROOF_X1 - 0.6, TX0
BR_Y0, BR_Y1 = 0.4, 5.6
BR_Z0, BR_Z1 = CAP_TOP, F2


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def studs_on(b, x0, x1, y0, y1, z, c, step=2.2, r=0.5, h=0.26, skip=(), n=6):
    nx = max(1, int(round((x1 - x0) / step)))
    ny = max(1, int(round((y1 - y0) / step)))
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    for ix in range(nx):
        for iy in range(ny):
            x, y = x0 + (ix + 0.5) * dx, y0 + (iy + 0.5) * dy
            if any(sx0 - r < x < sx1 + r and sy0 - r < y < sy1 + r for sx0, sy0, sx1, sy1 in skip):
                continue
            b.cyl(x, y, z, z + h, r, c, n)


def win_y(b, x0, x1, z0, z1, y, d):
    """A window on a wall plane y facing d (-1 front, +1 back): navy frame, glass, white sill."""
    b.box((x0, y, z0), (x1, y + d * 0.08, z1), P.INK, bevel=0.02)
    b.box((x0 + 0.25, y + d * 0.08, z0 + 0.25), (x1 - 0.25, y + d * 0.12, z1 - 0.25), P.GLASS, bevel=0.01)
    b.box((x0 - 0.1, y, z0 - 0.2), (x1 + 0.1, y + d * 0.14, z0), P.WHITE, bevel=0.02)


def win_x(b, y0, y1, z0, z1, x, d):
    b.box((x, y0, z0), (x + d * 0.08, y1, z1), P.INK, bevel=0.02)
    b.box((x + d * 0.08, y0 + 0.25, z0 + 0.25), (x + d * 0.12, y1 - 0.25, z1 - 0.25), P.GLASS, bevel=0.01)
    b.box((x, y0 - 0.1, z0 - 0.2), (x + d * 0.14, y1 + 0.1, z0), P.WHITE, bevel=0.02)


def fence_x(b, x0, x1, y, z0, step, post=0.36, h=2.2):
    """Lego fence panel along X at plane y: white posts and a red top rail."""
    n = max(1, int(round((x1 - x0) / step)))
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        b.box((x - post / 2, y - post / 2, z0), (x + post / 2, y + post / 2, z0 + h), P.WHITE, bevel=0.03)
    b.box((x0 - 0.2, y - 0.3, z0 + h), (x1 + 0.2, y + 0.3, z0 + h + 0.4), P.RED, bevel=0.03)
    b.box((x0, y - 0.12, z0 + h * 0.45), (x1, y + 0.12, z0 + h * 0.45 + 0.25), P.WHITE, bevel=0.02)


def fence_y(b, y0, y1, x, z0, step, post=0.36, h=2.2):
    n = max(1, int(round((y1 - y0) / step)))
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        b.box((x - post / 2, y - post / 2, z0), (x + post / 2, y + post / 2, z0 + h), P.WHITE, bevel=0.03)
    b.box((x - 0.3, y0 - 0.2, z0 + h), (x + 0.3, y1 + 0.2, z0 + h + 0.4), P.RED, bevel=0.03)
    b.box((x - 0.12, y0, z0 + h * 0.45), (x + 0.12, y1, z0 + h * 0.45 + 0.25), P.WHITE, bevel=0.02)


# ------------------------------------------------------------------ Lv4 radio wing
def wing_base(b):
    b.box((PL_X0, PL_Y0, 0.0), (PL_X1, PL_Y1, FLOOR), P.TAN, bevel=0.06)
    b.box((WEST_END, -2.4, FLOOR), (WX1, 8.4, FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((DOOR_X0, WY0, FLOOR), (DOOR_X1, -2.4, FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((30.6, -4.6, 0.0), (36.2, PL_Y0, 0.3), P.TAN, bevel=0.04)
    for x in (31.8, 33.4, 35.0):
        b.cyl(x, -4.2, 0.3, 0.5, 0.4, P.TAN, 6)
    studs_on(b, 26.7, 43.7, -3.7, -3.1, FLOOR, P.TAN, step=2.6)
    studs_on(b, 26.7, 43.7, 9.1, 9.7, FLOOR, P.TAN, step=2.6)
    studs_on(b, 43.35, 43.9, -2.6, 9.0, FLOOR, P.TAN, step=2.6)


def wing_walls(b):
    yf0, yf1 = WY0, WY0 + WALL
    yb0, yb1 = WY1 - WALL, WY1
    for k in range(COURSES):
        z = FLOOR + k * COURSE
        col = P.RED if k in (0, 4, 8) else P.WHITE
        b.box((WEST_END, yf0, z), (DOOR_X0, yf1, z + COURSE), col, bevel=0.05)
        b.box((DOOR_X1, yf0, z), (WX1, yf1, z + COURSE), col, bevel=0.05)
        if k >= 6:
            b.box((DOOR_X0, yf0, z), (DOOR_X1, yf1, z + COURSE), col, bevel=0.05)
        b.box((WEST_END, yb0, z), (WX1, yb1, z + COURSE), col, bevel=0.05)
        b.box((WX0, yf1, z), (WX0 + WALL, yb0, z + COURSE), col, bevel=0.05)
        b.box((WX1 - WALL, yf1, z), (WX1, yb0, z + COURSE), col, bevel=0.05)
    for x0, y0 in ((WX0 - 0.06, yf0 - 0.06), (WX0 - 0.06, yb1 - 0.49),
                   (WX1 - 0.49, yf0 - 0.06), (WX1 - 0.49, yb1 - 0.49)):
        b.box((x0, y0, FLOOR), (x0 + 0.55, y0 + 0.55, WALL_TOP), P.RED, bevel=0.03)


def wing_trim(b):
    for x0, x1 in ((30.15, 30.55), (36.25, 36.65)):
        b.box((x0, -3.1, FLOOR), (x1, -2.9, 7.75), P.INK, bevel=0.02)
    b.box((30.15, -3.1, 7.55), (36.65, -2.9, 8.15), P.INK, bevel=0.02)

    win_y(b, 37.8, 42.2, 3.4, 6.8, WY0, -1)
    win_x(b, 0.8, 5.2, 3.4, 6.8, WX1, 1)
    for x0, x1 in ((27.9, 31.3), (33.5, 36.9), (39.1, 42.5)):
        win_y(b, x0, x1, 11.5, 13.95, WY0, -1)
        win_y(b, x0, x1, 11.5, 13.95, WY1, 1)
    win_x(b, 1.4, 4.6, 11.5, 13.95, WX1, 1)

    for z0 in (9.62, 14.27):
        b.box((WEST_END, -3.05, z0), (WX1, -3.0, z0 + 0.28), P.INK, bevel=0.01)
        b.box((WEST_END, 9.0, z0), (WX1, 9.05, z0 + 0.28), P.INK, bevel=0.01)
        b.box((WX1, -3.05, z0), (WX1 + 0.04, 9.05, z0 + 0.28), P.INK, bevel=0.01)

    b.box((32.2, -3.14, 8.3), (34.8, -3.0, 9.35), P.INK, bevel=0.02)
    for i, x in enumerate((32.7, 33.4, 34.1)):
        b.box((x, -3.2, 8.45), (x + 0.2, -3.14, 8.45 + 0.4 + 0.2 * i), P.WHITE, bevel=0.0)
    b.box((32.35, -3.2, 8.45), (32.55, -3.14, 8.65), P.YELLOW, bevel=0.0)

    lx = 40.0
    b.ring_y(lx, -3.12, 8.4, 0.7, 0.22, P.YELLOW, maj=10, mnr=4)
    for dx, z0 in ((-0.2, 8.9), (-0.2, 7.5), (-0.8, 8.2), (0.4, 8.2)):
        b.box((lx + dx, -3.36, z0), (lx + dx + 0.4, -3.3, z0 + 0.4), P.WHITE, bevel=0.0)


def wing_interior(b):
    dx0, dx1 = 40.6, 42.5
    b.box((dx0, 0.2, 3.0), (dx1, 7.9, 3.3), P.WHITE, bevel=0.03)
    for x in (40.75, 42.35):
        for y in (0.35, 7.75):
            b.box((x - 0.15, y - 0.15, FLOOR_TOP), (x + 0.15, y + 0.15, 3.0), P.DBG, bevel=0.01)
    b.box((42.25, 0.4, FLOOR_TOP), (dx1, 7.7, 2.8), P.INK, bevel=0.02)
    for y0 in (0.45, 2.95, 5.45):
        b.box((40.9, y0, 3.3), (42.4, y0 + 2.2, 5.5), P.DBG, bevel=0.03)
        b.box((40.82, y0 + 0.1, 3.4), (40.9, y0 + 2.1, 5.4), P.BLACK, bevel=0.01)
        b.box((40.77, y0 + 0.35, 4.1), (40.82, y0 + 1.5, 5.25), P.GLASS, bevel=0.01)
        b.box((40.77, y0 + 1.65, 3.5), (40.82, y0 + 1.95, 3.9), P.RED, bevel=0.0)
        b.box((40.77, y0 + 1.65, 4.05), (40.82, y0 + 1.95, 4.45), P.GREEN, bevel=0.0)
        b.box((40.77, y0 + 0.3, 3.5), (40.82, y0 + 0.8, 3.95), P.LBG, bevel=0.0)

    x0, x1, z0, z1 = 29.8, 38.6, 3.8, 9.0
    W, H = x1 - x0 - 0.24, z1 - z0 - 0.24
    u = lambda f: x0 + 0.12 + f * W
    v = lambda f: z0 + 0.12 + f * H
    yb = WY1 - WALL
    b.box((x0, yb - 0.2, z0), (x1, yb, z1), P.INK, bevel=0.03)
    for xa, za, xb, zb in ((x0, z0, x1, z0 + 0.12), (x0, z1 - 0.12, x1, z1), (x0, z0, x0 + 0.12, z1), (x1 - 0.12, z0, x1, z1)):
        b.box((xa, yb - 0.28, za), (xb, yb - 0.2, zb), P.WHITE, bevel=0.0)
    b.box((u(0), yb - 0.24, v(0)), (u(1), yb - 0.2, v(1)), P.CYAN, bevel=0.0)
    for fx0, fz0, fx1, fz1 in ((0.10, 0.12, 0.35, 0.40), (0.50, 0.45, 0.68, 0.85), (0.72, 0.12, 0.92, 0.36)):
        b.box((u(fx0), yb - 0.28, v(fz0)), (u(fx1), yb - 0.24, v(fz1)), P.TAN, bevel=0.0)
    for f in (0.25, 0.5, 0.75):
        b.box((u(f), yb - 0.3, v(0)), (u(f) + 0.03, yb - 0.28, v(1)), P.WHITE, bevel=0.0)
    for f in (0.33, 0.66):
        b.box((u(0), yb - 0.3, v(f)), (u(1), yb - 0.28, v(f) + 0.03), P.WHITE, bevel=0.0)
    for fx, fz in ((0.14, 0.84), (0.31, 0.74), (0.48, 0.61)):
        b.box((u(fx), yb - 0.32, v(fz)), (u(fx) + 0.9, yb - 0.3, v(fz) + 0.14), P.RED, bevel=0.0)
    for fx, fz in ((0.18, 0.86), (0.4, 0.7), (0.58, 0.5)):
        b.box((u(fx), yb - 0.36, v(fz)), (u(fx) + 0.26, yb - 0.32, v(fz) + 0.26), P.YELLOW, bevel=0.0)

    b.box((42.0, 1.0, 8.4), (42.6, 7.4, 8.65), P.BROWN, bevel=0.02)
    for y0, col in ((1.8, P.RED), (3.4, P.INK), (5.0, P.YELLOW)):
        b.box((42.05, y0, 8.65), (42.55, y0 + 0.8, 9.8), col, bevel=0.02)

    for cx in (31.5, 38.0):
        b.box((cx - 0.7, 2.3, WALL_TOP - 0.1), (cx + 0.7, 3.7, WALL_TOP), P.INK, bevel=0.02)
        b.box((cx - 0.5, 2.5, WALL_TOP - 0.2), (cx + 0.5, 3.5, WALL_TOP - 0.1), P.WARM, bevel=0.01)


def wing_roof(b):
    b.box((ROOF_X0, ROOF_Y0, WALL_TOP), (ROOF_X1, ROOF_Y1, ROOF_TOP), P.INK, bevel=0.05)
    b.box((ROOF_X0, ROOF_Y0, ROOF_TOP), (ROOF_X1, ROOF_Y0 + 0.5, PAR_TOP), P.WHITE, bevel=0.03)
    b.box((ROOF_X0, ROOF_Y1 - 0.5, ROOF_TOP), (ROOF_X1, ROOF_Y1, PAR_TOP), P.WHITE, bevel=0.03)
    b.box((ROOF_X1 - 0.5, ROOF_Y0 + 0.5, ROOF_TOP), (ROOF_X1, ROOF_Y1 - 0.5, PAR_TOP), P.WHITE, bevel=0.03)
    b.box((ROOF_X0, ROOF_Y0 - 0.06, PAR_TOP), (ROOF_X1 + 0.06, ROOF_Y0 + 0.56, CAP_TOP), P.RED, bevel=0.02)
    b.box((ROOF_X0, ROOF_Y1 - 0.56, PAR_TOP), (ROOF_X1 + 0.06, ROOF_Y1 + 0.06, CAP_TOP), P.RED, bevel=0.02)
    b.box((ROOF_X1 - 0.56, ROOF_Y0 + 0.56, PAR_TOP), (ROOF_X1 + 0.06, ROOF_Y1 - 0.56, CAP_TOP), P.RED, bevel=0.02)
    studs_on(b, ROOF_X0 + 0.9, ROOF_X1 - 0.9, ROOF_Y0 + 0.9, ROOF_Y1 - 0.9, ROOF_TOP, P.INK, step=3.4,
             skip=((MAST_X - 1.8, MAST_Y - 1.8, MAST_X + 1.8, MAST_Y + 1.8),))
    # parapet studs on the red cap
    studs_on(b, ROOF_X0 + 0.6, ROOF_X1 - 0.3, ROOF_Y0 + 0.1, ROOF_Y0 + 0.5, CAP_TOP, P.RED, step=1.9, r=0.3, h=0.22, n=5)
    studs_on(b, ROOF_X0 + 0.6, ROOF_X1 - 0.3, ROOF_Y1 - 0.5, ROOF_Y1 - 0.1, CAP_TOP, P.RED, step=1.9, r=0.3, h=0.22, n=5)
    studs_on(b, ROOF_X1 - 0.5, ROOF_X1 - 0.1, ROOF_Y0 + 0.9, ROOF_Y1 - 0.9, CAP_TOP, P.RED, step=1.9, r=0.3, h=0.22, n=5)
    b.box((MAST_X - 1.8, MAST_Y - 1.8, ROOF_TOP), (MAST_X + 1.8, MAST_Y + 1.8, PAD_TOP), P.WHITE, bevel=0.04)


def wing_mast(b):
    cx, cy = MAST_X, MAST_Y
    z0 = PAD_TOP
    n = 6
    seg = (MAST_TOP - z0) / n

    def half(t):
        return 1.35 + (0.55 - 1.35) * t

    for i in range(n):
        za, zb = z0 + i * seg, z0 + (i + 1) * seg
        wa, wb = half(i / n), half((i + 1) / n)
        col = P.RED if i % 2 == 0 else P.WHITE
        rung = P.WHITE if i % 2 == 0 else P.RED
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            b.beam((cx + sx * wa, cy + sy * wa, za), (cx + sx * wb, cy + sy * wb, zb), 0.26, 0.26, col)
        zr = zb - 0.08
        b.beam((cx - wb, cy - wb, zr), (cx + wb, cy - wb, zr), 0.16, 0.16, rung)
        b.beam((cx - wb, cy + wb, zr), (cx + wb, cy + wb, zr), 0.16, 0.16, rung)
        b.beam((cx - wb, cy - wb, zr), (cx - wb, cy + wb, zr), 0.16, 0.16, rung)
        b.beam((cx + wb, cy - wb, zr), (cx + wb, cy + wb, zr), 0.16, 0.16, rung)
        b.beam((cx - wa, cy - wa, za + 0.15), (cx + wb, cy - wb, zb - 0.15), 0.14, 0.14, rung)
        b.beam((cx + wa, cy + wa, za + 0.15), (cx - wb, cy + wb, zb - 0.15), 0.14, 0.14, rung)
        b.beam((cx - wa, cy + wa, za + 0.15), (cx - wb, cy - wb, zb - 0.15), 0.14, 0.14, rung)
        b.beam((cx + wa, cy - wa, za + 0.15), (cx + wb, cy + wb, zb - 0.15), 0.14, 0.14, rung)

    t = MAST_TOP
    b.box((cx - 0.7, cy - 0.7, t), (cx + 0.7, cy + 0.7, t + 0.3), P.INK, bevel=0.03)
    b.box((cx - 0.07, cy - 0.07, t + 0.3), (cx + 0.07, cy + 0.07, t + 2.4), P.WHITE, bevel=0.01)
    b.box((cx - 3.6, cy - 0.08, t + 0.47), (cx + 3.6, cy + 0.08, t + 0.63), P.WHITE, bevel=0.01)
    b.box((cx - 0.08, cy - 2.7, t + 0.32), (cx + 0.08, cy + 2.7, t + 0.48), P.WHITE, bevel=0.01)
    for sx in (-1, 1):
        b.box((cx + sx * 3.6 - 0.15, cy - 0.17, t + 0.39), (cx + sx * 3.6 + 0.15, cy + 0.17, t + 0.71), P.RED, bevel=0.0)
    b.cyl(cx, cy, t + 2.4, t + 3.0, 0.4, P.RED, 6)
    b.cyl(cx, cy, t + 3.0, t + 3.15, 0.45, P.INK, 6)


def wing_col(c):
    c.box((PL_X0, PL_Y0, 0.0), (PL_X1, PL_Y1, FLOOR))
    c.box((WEST_END, WY0, FLOOR), (WX1, WY1, FLOOR_TOP))
    c.box((WEST_END, WY0, FLOOR), (DOOR_X0, WY0 + WALL, WALL_TOP))
    c.box((DOOR_X1, WY0, FLOOR), (WX1, WY0 + WALL, WALL_TOP))
    c.box((DOOR_X0, WY0, DOOR_TOP), (DOOR_X1, WY0 + WALL, WALL_TOP))
    c.box((WEST_END, WY1 - WALL, FLOOR), (WX1, WY1, WALL_TOP))
    c.box((WX0, WY0 + WALL, FLOOR), (WX0 + WALL, WY1 - WALL, WALL_TOP))
    c.box((WX1 - WALL, WY0 + WALL, FLOOR), (WX1, WY1 - WALL, WALL_TOP))
    c.box((ROOF_X0, ROOF_Y0, WALL_TOP), (ROOF_X1, ROOF_Y1, CAP_TOP))
    c.box((40.6, 0.2, FLOOR_TOP), (42.5, 7.9, 5.6))
    c.box((MAST_X - 1.35, MAST_Y - 1.35, PAD_TOP), (MAST_X + 1.35, MAST_Y + 1.35, MAST_TOP))
    c.box((30.6, -4.6, 0.0), (36.2, PL_Y0, 0.3))


# ------------------------------------------------------------------ Lv5 beacon tower
def tower_base(b):
    b.box((QX0, QY0, 0.0), (QX1, QY1, T_FLOOR), P.TAN, bevel=0.06)
    b.box((TX0 + T_WALL, TY0 + T_WALL, T_FLOOR), (TX1 - T_WALL, TY1 - T_WALL, T_FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((T_DOOR_X0, TY0, T_FLOOR), (T_DOOR_X1, TY0 + T_WALL, T_FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((52.5, QY0 - 1.2, 0.0), (57.5, QY0, 0.3), P.TAN, bevel=0.04)
    for x in (53.6, 55.0, 56.4):
        b.cyl(x, QY0 - 0.6, 0.3, 0.5, 0.35, P.TAN, 6)
    studs_on(b, 49.4, 60.6, -2.8, -1.7, T_FLOOR, P.TAN, step=2.9)
    studs_on(b, 49.4, 60.6, 7.7, 8.8, T_FLOOR, P.TAN, step=2.9)
    studs_on(b, 49.2, 50.3, -0.8, 6.8, T_FLOOR, P.TAN, step=2.9)
    studs_on(b, 59.7, 60.8, -0.8, 6.8, T_FLOOR, P.TAN, step=2.9)


def tower_walls(b):
    yf0, yf1 = TY0, TY0 + T_WALL
    yb0, yb1 = TY1 - T_WALL, TY1
    for k in range(S1_N):
        z = T_FLOOR + k * S1_C
        col = P.RED if k % 4 == 0 else P.WHITE
        if k < 3:
            b.box((TX0, yf0, z), (T_DOOR_X0, yf1, z + S1_C), col, bevel=0.04)
            b.box((T_DOOR_X1, yf0, z), (TX1, yf1, z + S1_C), col, bevel=0.04)
        else:
            b.box((TX0, yf0, z), (TX1, yf1, z + S1_C), col, bevel=0.04)
        b.box((TX0, yb0, z), (TX1, yb1, z + S1_C), col, bevel=0.04)
        if z > F2 - 0.01:
            b.box((TX0, yf1, z), (TX0 + T_WALL, W_DY0, z + S1_C), col, bevel=0.04)
            b.box((TX0, W_DY1, z), (TX0 + T_WALL, yb0, z + S1_C), col, bevel=0.04)
        else:
            b.box((TX0, yf1, z), (TX0 + T_WALL, yb0, z + S1_C), col, bevel=0.04)
        b.box((TX1 - T_WALL, yf1, z), (TX1, yb0, z + S1_C), col, bevel=0.04)
    b.box((TX0 + T_WALL, yf1, F2 - 0.6), (TX1 - T_WALL, yb0, F2), P.TAN, bevel=0.02)
    for j in range(U_N):
        z = LEDGE_TOP + j * U_C
        col = P.RED if (S1_N + j) % 4 == 0 else P.WHITE
        b.box((UX0, UY0, z), (UX1, UY1, z + U_C), col, bevel=0.04)


def shield(b, cx, y0, y1, ztop, W, H, col, inset=0.0):
    """A stepped heater shield (full width on top, narrowing to a point), one box per band; `inset` shrinks the
    same outline on every side, so the navy field keeps the red border's steps."""
    z = ztop
    for fh, fw in ((0.55, 1.0), (0.1, 0.88), (0.1, 0.72), (0.1, 0.54), (0.1, 0.36), (0.05, 0.18)):
        zt, zb = z, z - H * fh
        w = W * fw - 2 * inset
        if w > 0.3:
            b.box((cx - w / 2, y0, zb), (cx + w / 2, y1, zt - (inset if zt == ztop else 0.0)), col, bevel=0.0)
        z = zb


def tower_trim(b):
    for x0, x1 in ((T_DOOR_X0 - 0.2, T_DOOR_X0 + 0.2), (T_DOOR_X1 - 0.2, T_DOOR_X1 + 0.2)):
        b.box((x0, TY0 - 0.2, T_FLOOR), (x1, TY0, T_DOOR_TOP), P.RED, bevel=0.02)
    b.box((T_DOOR_X0 - 0.2, TY0 - 0.2, T_DOOR_TOP), (T_DOOR_X1 + 0.2, TY0, T_DOOR_TOP + 0.3), P.RED, bevel=0.02)

    b.box((TX0 - 0.35, TY0 - 0.35, S1_TOP), (TX1 + 0.35, TY1 + 0.35, LEDGE_TOP), P.INK, bevel=0.04)

    # crest: red border shield, navy field, gold anchor
    cx = TCX
    shield(b, cx, TY0 - 0.3, TY0, CREST_Z1, CREST_W, CREST_H, P.RED)
    shield(b, cx, TY0 - 0.55, TY0 - 0.3, CREST_Z1, CREST_W, CREST_H, P.INK, inset=0.6)
    ya, yb_ = TY0 - 0.8, TY0 - 0.55
    ym = (ya + yb_) / 2
    b.ring_y(cx, ym, 17.6, 0.55, 0.14, P.GOLD, maj=8, mnr=4)
    b.box((cx - 0.25, ya, 11.3), (cx + 0.25, yb_, 17.0), P.GOLD, bevel=0.0)
    b.box((cx - 1.5, ya, 15.4), (cx + 1.5, yb_, 15.85), P.GOLD, bevel=0.0)
    for s in (-1, 1):
        b.beam((cx, ym, 11.55), (cx + s * 2.0, ym, 13.1), 0.25, 0.5, P.GOLD)
        b.box((cx + s * 2.0 - 0.25, ya, 12.9), (cx + s * 2.0 + 0.25, yb_, 14.0), P.GOLD, bevel=0.0)

    for z0 in (LEDGE_TOP + 3.0, LEDGE_TOP + 9.0):
        win_y(b, TCX - 0.6, TCX + 0.6, z0, z0 + 2.6, UY0, -1)
        win_y(b, TCX - 0.6, TCX + 0.6, z0, z0 + 2.6, UY1, 1)
        win_x(b, TCY - 0.6, TCY + 0.6, z0, z0 + 2.6, UX0, -1)
        win_x(b, TCY - 0.6, TCY + 0.6, z0, z0 + 2.6, UX1, 1)

    yb = TY1 - T_WALL
    b.box((52.4, yb - 0.18, 2.8), (57.6, yb, 6.2), P.INK, bevel=0.02)
    b.box((52.9, yb - 0.24, 3.2), (54.3, yb - 0.18, 5.8), P.WHITE, bevel=0.0)
    b.box((54.9, yb - 0.24, 3.4), (55.2, yb - 0.18, 5.4), P.YELLOW, bevel=0.0)
    b.box((55.9, yb - 0.24, 4.4), (56.9, yb - 0.18, 5.0), P.RED, bevel=0.0)
    for zc in (S1_TOP, F2 - 0.6):
        b.box((TCX - 0.6, TCY - 0.6, zc - 0.1), (TCX + 0.6, TCY + 0.6, zc), P.INK, bevel=0.02)
        b.box((TCX - 0.4, TCY - 0.4, zc - 0.2), (TCX + 0.4, TCY + 0.4, zc - 0.1), P.WARM, bevel=0.01)
    win_y(b, TCX - 0.7, TCX + 0.7, F2 + 2.0, F2 + 5.0, TY1, 1)
    win_x(b, TCY - 0.7, TCY + 0.7, F2 + 2.0, F2 + 5.0, TX1, 1)

    # second-floor door on the west face, red frame under the navy ledge
    for y0, y1 in ((W_DY0 - 0.2, W_DY0 + 0.2), (W_DY1 - 0.2, W_DY1 + 0.2)):
        b.box((TX0 - 0.2, y0, F2), (TX0, y1, S1_TOP), P.RED, bevel=0.02)

    # raised bridge from the wing roof to the second floor: a tan deck resting on the wing's parapet cap (its studs
    # sit in the deck, Lego style), a navy girder under it, Lego fence panels each side, a step plate on the roof
    b.box((BR_X0, BR_Y0, BR_Z0), (BR_X1, BR_Y1, BR_Z1), P.TAN, bevel=0.04)
    b.box((ROOF_X1 + 0.06, BR_Y0 + 0.3, BR_Z0 - 0.9), (BR_X1, BR_Y1 - 0.3, BR_Z0), P.INK, bevel=0.04)
    for y in (BR_Y0 + 0.5, BR_Y1 - 0.5):
        b.beam((TX0, y, BR_Z0 - 4.5), (ROOF_X1 + 3.0, y, BR_Z0 - 0.9), 0.4, 0.4, P.INK)
    b.box((ROOF_X1 - 2.2, BR_Y0 + 0.2, ROOF_TOP), (BR_X0, BR_Y1 - 0.2, ROOF_TOP + 0.5), P.TAN, bevel=0.03)
    fence_x(b, ROOF_X1 + 0.4, BR_X1 - 0.4, BR_Y0 + 0.2, BR_Z1, 1.1)
    fence_x(b, ROOF_X1 + 0.4, BR_X1 - 0.4, BR_Y1 - 0.2, BR_Z1, 1.1)


def tower_balcony(b):
    b.box((BX0 + 0.6, BY0 + 0.6, B_Z0 - 0.6), (BX1 - 0.6, BY1 - 0.6, B_Z0), P.INK, bevel=0.04)
    b.box((BX0, BY0, B_Z0), (BX1, BY1, B_Z1), P.INK, bevel=0.04)
    fence_x(b, FX0 + 0.5, FX1 - 0.5, FY0, B_Z1, 1.25)
    fence_x(b, FX0 + 0.5, FX1 - 0.5, FY1, B_Z1, 1.25)
    fence_y(b, FY0 + 0.5, FY1 - 0.5, FX0, B_Z1, 1.25)
    fence_y(b, FY0 + 0.5, FY1 - 0.5, FX1, B_Z1, 1.25)
    for x, y in ((FX0, FY0), (FX0, FY1), (FX1, FY0), (FX1, FY1)):
        b.box((x - 0.3, y - 0.3, B_Z1), (x + 0.3, y + 0.3, RAIL_TOP + 0.4), P.RED, bevel=0.03)
        b.cyl(x, y, RAIL_TOP + 0.4, RAIL_TOP + 0.65, 0.22, P.RED, 5)


def tower_lantern(b):
    cx, cy, H = LAN_CX, LAN_CY, LAN_HALF
    b.box((cx - H, cy - H, B_Z1), (cx + H, cy + H, LAN_Z0), P.GOLD, bevel=0.04)
    pc = H - 0.3
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = cx + sx * pc, cy + sy * pc
        b.box((x - 0.3, y - 0.3, LAN_Z0), (x + 0.3, y + 0.3, LAN_Z1), P.GOLD, bevel=0.03)
    # glazing: a light-blue pane in every bay (two per side, split by a gold mullion) up to PANE_TOP; the open band
    # above the panes shows the lamp head
    for s_ in (-1, 1):
        for along_x in (True, False):
            c0, c1 = (cx - pc + 0.3, cx + pc - 0.3) if along_x else (cy - pc + 0.3, cy + pc - 0.3)
            f = (cy if along_x else cx) + s_ * pc
            mid = cx if along_x else cy
            span = lambda lo, hi, z0, z1, c, t=0.25, bev=0.02: (
                b.box((lo, f - t, z0), (hi, f + t, z1), c, bevel=bev) if along_x else
                b.box((f - t, lo, z0), (f + t, hi, z1), c, bevel=bev))
            span(c0, c1, LAN_Z0, PANE_TOP, P.GLASS, 0.08, 0.0)
            span(c0, c1, LAN_Z0, LAN_Z0 + 0.3, P.GOLD)
            span(c0, c1, PANE_TOP, PANE_TOP + 0.3, P.GOLD)
            span(c0, c1, LAN_Z0 + 1.6, LAN_Z0 + 1.75, P.GOLD, 0.14, 0.0)
            span(mid - 0.18, mid + 0.18, LAN_Z0 + 0.3, PANE_TOP, P.GOLD)
    # lamp pedestal, a gold lens band around the lamp and its cap (the lamp itself is Lv5_L05_Beacon)
    b.cyl(cx, cy, LAN_Z0, LAMP_Z0, 0.8, P.DBG, 8)
    b.cyl(cx, cy, PANE_TOP + 0.85, PANE_TOP + 1.0, 1.68, P.GOLD, 8)
    b.cyl(cx, cy, LAN_Z1 - 0.3, LAN_Z1, 0.9, P.GOLD, 8)
    # trimmed eaves: a thin gold eave just past the posts and a tight red stepped roof
    b.box((cx - 3.7, cy - 3.7, LAN_Z1), (cx + 3.7, cy + 3.7, LAN_Z1 + 0.45), P.GOLD, bevel=0.04)
    z = LAN_Z1 + 0.45
    for half in (3.2, 2.5, 1.8, 1.1):
        b.box((cx - half, cy - half, z), (cx + half, cy + half, z + 0.65), P.RED, bevel=0.04)
        z += 0.65
    b.cyl(cx, cy, z, z + 0.8, 0.35, P.GOLD, 6)


def tower_beacon(b):
    b.cyl(LAN_CX, LAN_CY, LAMP_Z0, LAN_Z1 - 0.3, 1.55, P.WARM, 8)


def tower_col(c):
    c.box((QX0, QY0, 0.0), (QX1, QY1, T_FLOOR))
    c.box((TX0 + T_WALL, TY0 + T_WALL, T_FLOOR), (TX1 - T_WALL, TY1 - T_WALL, T_FLOOR_TOP))
    c.box((T_DOOR_X0, TY0, T_FLOOR), (T_DOOR_X1, TY0 + T_WALL, T_FLOOR_TOP))
    c.box((TX0, TY0, T_FLOOR), (T_DOOR_X0, TY0 + T_WALL, S1_TOP))
    c.box((T_DOOR_X1, TY0, T_FLOOR), (TX1, TY0 + T_WALL, S1_TOP))
    c.box((T_DOOR_X0, TY0, T_DOOR_TOP), (T_DOOR_X1, TY0 + T_WALL, S1_TOP))
    c.box((TX0, TY1 - T_WALL, T_FLOOR), (TX1, TY1, S1_TOP))
    c.box((TX0, TY0 + T_WALL, T_FLOOR), (TX0 + T_WALL, TY1 - T_WALL, F2))
    c.box((TX0, TY0 + T_WALL, F2), (TX0 + T_WALL, W_DY0, S1_TOP))
    c.box((TX0, W_DY1, F2), (TX0 + T_WALL, TY1 - T_WALL, S1_TOP))
    c.box((TX0 + T_WALL, TY0 + T_WALL, F2 - 0.6), (TX1 - T_WALL, TY1 - T_WALL, F2))
    c.box((TX1 - T_WALL, TY0 + T_WALL, T_FLOOR), (TX1, TY1 - T_WALL, S1_TOP))
    c.box((TX0 - 0.35, TY0 - 0.35, S1_TOP), (TX1 + 0.35, TY1 + 0.35, LEDGE_TOP))
    c.box((UX0, UY0, LEDGE_TOP), (UX1, UY1, T_TOP))
    c.box((BX0, BY0, B_Z0), (BX1, BY1, B_Z1))
    c.box((FX0 - 0.3, FY0 - 0.3, B_Z1), (FX1 + 0.3, FY0 + 0.3, RAIL_TOP))
    c.box((FX0 - 0.3, FY1 - 0.3, B_Z1), (FX1 + 0.3, FY1 + 0.3, RAIL_TOP))
    c.box((FX0 - 0.3, FY0 + 0.3, B_Z1), (FX0 + 0.3, FY1 - 0.3, RAIL_TOP))
    c.box((FX1 - 0.3, FY0 + 0.3, B_Z1), (FX1 + 0.3, FY1 - 0.3, RAIL_TOP))
    c.box((LAN_CX - 3.5, LAN_CY - 3.5, B_Z1), (LAN_CX + 3.5, LAN_CY + 3.5, LAN_Z1))
    c.box((LAN_CX - 3.7, LAN_CY - 3.7, LAN_Z1), (LAN_CX + 3.7, LAN_CY + 3.7, LAN_Z1 + 3.05))
    c.box((TCX - CREST_W / 2, TY0 - 0.8, CREST_Z1 - CREST_H * 0.55), (TCX + CREST_W / 2, TY0, CREST_Z1))
    c.box((BR_X0, BR_Y0, BR_Z0 - 0.9), (BR_X1, BR_Y1, BR_Z1))
    c.box((ROOF_X1, BR_Y0, BR_Z1), (BR_X1, BR_Y0 + 0.5, BR_Z1 + 2.6))
    c.box((ROOF_X1, BR_Y1 - 0.5, BR_Z1), (BR_X1, BR_Y1, BR_Z1 + 2.6))
    c.box((ROOF_X1 - 2.2, BR_Y0 + 0.2, ROOF_TOP), (BR_X0, BR_Y1 - 0.2, ROOF_TOP + 0.5))
    c.box((52.5, QY0 - 1.2, 0.0), (57.5, QY0, 0.3))


def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_HQAddons_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv4", "Lv5")}

    def out(name, b, node):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[hqaddons] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    wing_base(b)
    out("Lv4_L01_Base", b, "Lv4")

    b = lego.B()
    wing_walls(b)
    out("Lv4_L02_Walls", b, "Lv4")

    b = lego.B()
    wing_trim(b)
    out("Lv4_L03_Trim", b, "Lv4")

    b = lego.B()
    wing_interior(b)
    out("Lv4_L04_Interior", b, "Lv4")

    b = lego.B()
    wing_roof(b)
    out("Lv4_L05_Roof", b, "Lv4")

    b = lego.B()
    wing_mast(b)
    out("Lv4_L06_Mast", b, "Lv4")

    c = lego.B()
    wing_col(c)
    out_cols("Lv4", c)

    b = lego.B()
    tower_base(b)
    out("Lv5_L01_Base", b, "Lv5")

    b = lego.B()
    tower_walls(b)
    out("Lv5_L02_Tower", b, "Lv5")

    b = lego.B()
    tower_trim(b)
    out("Lv5_L03_Trim", b, "Lv5")

    b = lego.B()
    tower_balcony(b)
    out("Lv5_L04_Balcony", b, "Lv5")

    b = lego.B()
    tower_lantern(b)
    out("Lv5_L05_Lantern", b, "Lv5")

    b = lego.B()
    tower_beacon(b)
    out("Lv5_L05_Beacon", b, "Lv5")

    c = lego.B()
    tower_col(c)
    out_cols("Lv5", c)

    atts = []
    for name, loc in (("ATT_Work_Radio", (39.6, 4.0, FLOOR_TOP)),
                      ("ATT_RadioMast", (MAST_X, MAST_Y, PAD_TOP)),
                      ("ATT_Beacon", (LAN_CX, LAN_CY, LAMP_Z0)),
                      ("ATT_Balcony", (LAN_CX, FY0 - 0.5, B_Z1))):
        atts.append(lego.attach(name, loc))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[hqaddons] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[hqaddons] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "HQ add-ons only: the Lv4 two-storey radio wing against the code station's east wall and the Lv5 "
                     "beacon tower beside it, joined by a walkway on one base, on the station's 54 x 32 stud lot "
                     "(isle 0,-12); the bbox is the two add-ons, not the station; front -Y, origin the HQ ground "
                     "centre, built at 1x (place at the HQ frame with no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 A/B/J): Lv4_L01_..., Lv5_L01_..., Lv4_Col01_COL.., "
                      "Lv5_Col01_COL..; the FBX importer flattens empty parents, so the node name is the mesh name "
                      "prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "radio_wing", "target": [35.0, 3.0, 8.0], "dist": 40, "az": 30, "el": 10},
            {"name": "radio_room", "target": [35.0, 3.0, 5.5], "dist": 18, "az": 0, "el": 2},
            {"name": "beacon_tower", "target": [55.0, 3.0, 24.0], "dist": 78, "az": 25, "el": 12},
            {"name": "lantern", "target": [55.0, 3.0, 43.5], "dist": 20, "az": 15, "el": 8},
            {"name": "bridge", "target": [47.0, 3.0, 17.0], "dist": 30, "az": 0, "el": 22},
            {"name": "crest", "target": [55.0, -1.5, 14.6], "dist": 20, "az": 0, "el": 0},
        ],
    }
