"""M_Bld_FishMarketAddons: the Fish Market's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

The Lv1 market stays the code-built `fishMarket()` in src/shared/DockPieces.luau. This asset adds only what the two
levels add, at the market's final frame: 40 x 34 stud lot, ground at z 0, plinth top z 0.92 (the code plinth is 0.8
studs at 1x, scaled 1.15), front -Y (Roblox -Z), origin the market's ground centre. Place at the market frame with no
extra scale.

Lv2 (engine: 2 -> 4 fish slots): two more market stalls on the flanks, facing inward across the square. Each has a
blue counter with a white top, two blue posts, a seven-stripe blue/white studded awning with a stepped front edge and
an orange fish plaque on top (reads from above), an inset light-blue ice tray with a dark rim holding one row of four
big Lego fish (silver, orange, yellow; body, wedge tail, stud eye). Behind the counter the vendor stands on a smooth
white 3-stud tile between two brown slatted crate stacks. The tan pads carry a 1-stud grid of studs.

Lv3 (engine: 4 -> 8 fish slots): a small walk-in smokehouse at the back centre, 9 x 8 studs, brown plank walls on a
blue base course, a blue gable roof with a studded dark ridge cap and brown gables carrying a gold fish glyph, and a
red brick chimney with a studded cap. The doorway is 6.6 studs wide. Inside: two brown/tan fish racks along the side
walls with smoked orange/gold fish, a central rail with five hanging smoked fish; outside, a 2-barrel plank bench
flush against the front wall. The floor is clear.

Each level is a top-level node (Lv2, Lv3) holding 5-6 construction layers (L01_* bottom to L06_* top), one palette
mesh per layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). Collision is one simple box per
object, <Node>_ColNN_COL (Roblox hulls each mesh, so a merged proxy would fill the doorway): counters, crates, upper
posts and awnings; smokehouse walls in six bites, the roof and chimney overhead, the side racks, bench and firewood, so the door and the interior walkway stay open.

    python3 art/source/buildings/M_Bld_FishMarketAddons/maketex.py \
        --out build/prod/M_Bld_FishMarketAddons/textures/M_Bld_FishMarketAddons --name FishMarket --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_FishMarketAddons/build.py \
        --out-root build/prod/M_Bld_FishMarketAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_FishMarketAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "FishMarket", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_FishMarket_Brick_ALB.png")

FLOOR = 0.92
PAD = 0.95
STALL_X, STALL_Y = 14.0, 3.0
COUNTER_TOP, POST_TOP, AWNING_Z = 2.76, 7.95, 7.9
AWNING_TILT = math.radians(12.0)
AW_HALF_W, AW_HALF_S, AW_T = 3.9525, 2.53, 0.23     # awning half width, half length along the slope, half thickness
AW_STRIPES = 7
STUD_R, STUD_H = 0.32, 0.2                          # Lego stud on a 1-stud grid

SH_X0, SH_X1 = -3.0, 6.0
SH_Y0, SH_Y1 = 8.0, 16.0
WALL = 0.6
EAVE, RIDGE = 9.8, 12.0
COURSE = (EAVE - PAD) / 9.0                         # plank course height: 9 courses from floor to eave
ROOF_X0, ROOF_X1 = -3.6, 6.6
ROOF_Y0, ROOF_Y1 = 7.4, 16.6
DOOR_X0, DOOR_X1 = -1.8, 4.8                        # 6.0 clear between the 0.3 frames' inner edges is 5.4; 6.6 outer
DOOR_TOP = PAD + 6 * COURSE
WIN_Y0, WIN_Y1 = 10.6, 13.0
WIN_Z0, WIN_Z1 = PAD + 4 * COURSE, PAD + 6 * COURSE
CH_X0, CH_X1 = 0.7, 2.3
CH_Y0, CH_Y1 = 13.7, 15.2
CH_TOP, CAP_TOP = 13.4, 13.7


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def prism_y(b, y0, y1, profile, c):
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def prism_z(b, z0, z1, profile, c):
    """A plan-view (x, y) polygon extruded up from z0 to z1 (fish tails)."""
    n = len(profile)
    verts = [(x, y, z0) for x, y in profile] + [(x, y, z1) for x, y in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def place(dst, src, cx, cy, left):
    base = len(dst.v)
    if left:
        dst.v.extend((cx - y, cy + x, z) for x, y, z in src.v)
    else:
        dst.v.extend((cx + y, cy - x, z) for x, y, z in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


def place_rot(dst, src, cx, cy, z, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    base = len(dst.v)
    dst.v.extend((cx + x * ca - y * sa, cy + x * sa + y * ca, z + zz) for x, y, zz in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


def stud(b, x, y, z, c, r=STUD_R, h=STUD_H):
    b.cyl(x, y, z, z + h, r, c, 6)


def grid_studs(b, xs, ys, z, c, skip=()):
    for x in xs:
        for y in ys:
            if not any(x0 - STUD_R < x < x1 + STUD_R and y0 - STUD_R < y < y1 + STUD_R for x0, y0, x1, y1 in skip):
                stud(b, x, y, z, c)


def pad(b, x0, x1, y0, y1):
    b.box((x0, y0, FLOOR), (x1, y1, PAD), P.TAN, bevel=0.01)
    t, h = 0.12, 1.07
    b.box((x0, y0, FLOOR), (x1, y0 + t, h), P.BLUE, bevel=0.02)
    b.box((x0, y1 - t, FLOOR), (x1, y1, h), P.BLUE, bevel=0.02)
    b.box((x0, y0 + t, FLOOR), (x0 + t, y1 - t, h), P.BLUE, bevel=0.02)
    b.box((x1 - t, y0 + t, FLOOR), (x1, y1 - t, h), P.BLUE, bevel=0.02)


# ------------------------------------------------------------------ stall (local frame: x along the counter, -y customer side)
COUNTER_RECT = (-3.68, -1.495, 3.68, 1.495)
CRATE_A = (-4.3, 1.8, -1.75, 4.1, 1.6)              # x0, y0, x1, y1, height: crate stacks beside the vendor spot
CRATE_A2 = (-4.0, 2.0, -2.05, 3.9, 1.2)             # stacked on A
CRATE_B = (1.75, 1.9, 4.3, 4.1, 1.35)
CRATE_B2 = (2.05, 2.1, 4.0, 3.9, 1.0)               # stacked on B
SPOT = (-1.5, 1.6, 1.5, 3.9)                        # smooth white standing tile behind the counter (ATT_Work_Stall*)
TRAY = (-2.85, -1.5, 2.85, 1.5)                     # ice tray between the posts, dark rim
FISH_SETS = ((P.ORANGE, P.YELLOW), (P.LBG, P.DBG), (P.YELLOW, P.ORANGE), (P.LBG, P.DBG))


def fish(b, cx, cy, z, L, body, accent, ang=0.0, eye=P.WHITE):
    """A Lego fish ~L studs long, head +x before rotation: body brick, wedge tail, accent dorsal plate, stud eye."""
    f = lego.B()
    h, w = 0.3 * L, 0.17 * L
    f.box((-0.22 * L, -w, 0), (0.5 * L, w, h), body, bevel=0.08)
    prism_z(f, 0.06 * L, h - 0.04 * L, [(-0.2 * L, 0), (-0.5 * L, -0.27 * L), (-0.5 * L, 0.27 * L)], accent)
    f.box((-0.12 * L, -0.06 * L, h), (0.22 * L, 0.06 * L, h + 0.06 * L), accent, bevel=0.02)
    f.cyl(0.36 * L, 0.0, h, h + 0.08 * L, 0.075 * L, eye, 6)
    place_rot(b, f, cx, cy, z, ang)


def flat_fish(b, cx, cy, z, L, body, accent, ang):
    """A fish lying on its side on the ice, head +x before rotation: pointed body plate, V tail, ink eye."""
    f = lego.B()
    w = 0.19 * L
    prism_z(f, 0.0, 0.35, [(0.5 * L, 0), (0.3 * L, -w), (-0.25 * L, -0.7 * w), (-0.32 * L, 0),
                           (-0.25 * L, 0.7 * w), (0.3 * L, w)], body)
    prism_z(f, 0.05, 0.27, [(-0.28 * L, 0), (-0.5 * L, -0.21 * L), (-0.5 * L, 0.21 * L)], accent)
    f.box((0.12 * L, -0.8 * w, 0.35), (0.17 * L, 0.8 * w, 0.4), accent, bevel=0.01)            # gill line
    f.cyl(0.34 * L, 0.0, 0.35, 0.42, 0.11, P.INK, 6)
    place_rot(b, f, cx, cy, z, ang)


def slat_crate(b, x0, y0, x1, y1, z0, h):
    """Brown crate, tan slats on the front and both sides, studs on the top."""
    b.box((x0, y0, z0), (x1, y1, z0 + h), P.BROWN, bevel=0.05)
    n = 2 if h < 1.3 else 3
    for k in range(n):
        z = z0 + 0.12 + k * (h - 0.12) / n
        sh = (h - 0.12) / n - 0.14
        b.box((x0 + 0.1, y0 - 0.05, z), (x1 - 0.1, y0 + 0.02, z + sh), P.TAN, bevel=0.02)
        for xs in (x0 - 0.05, x1 - 0.02):
            b.box((xs, y0 + 0.1, z), (xs + 0.07, y1 - 0.1, z + sh), P.TAN, bevel=0.02)


def stall_pad_studs(b):
    crates = [(x0, y0, x1, y1) for x0, y0, x1, y1, _ in (CRATE_A, CRATE_B)]
    grid_studs(b, range(-4, 5), range(-1, 4), PAD, P.TAN, skip=[COUNTER_RECT, SPOT] + crates)
    b.box((SPOT[0], SPOT[1], PAD), (SPOT[2], SPOT[3], PAD + 0.1), P.WHITE, bevel=0.03)


def stall_counter(b):
    b.box((-3.68, -1.495, PAD), (3.68, 1.495, 2.5), P.BLUE)
    b.box((-3.78, -1.595, 2.5), (3.78, 1.595, COUNTER_TOP), P.WHITE, bevel=0.06)


def stall_frames(b):
    for x in (-3.22, 3.22):
        b.box((x - 0.345, -0.345, PAD), (x + 0.345, 0.345, POST_TOP), P.BLUE)


def stall_awnings(b, k):
    ca, sa = math.cos(AWNING_TILT), math.sin(AWNING_TILT)
    dy, dz = AW_HALF_S * ca, AW_HALF_S * sa
    ty, tz = -AW_T * sa, AW_T * ca
    profile = [(dy + ty, AWNING_Z + dz + tz), (dy - ty, AWNING_Z + dz - tz),
               (-dy - ty, AWNING_Z - dz - tz), (-dy + ty, AWNING_Z - dz + tz)]
    front_top = (-dy + ty, AWNING_Z - dz + tz)
    front_bot_z = AWNING_Z - dz - tz
    sw = 2 * AW_HALF_W / AW_STRIPES
    for i in range(AW_STRIPES):
        c = (P.WHITE, P.BLUE)[(i + k) % 2]
        x0 = -AW_HALF_W + i * sw
        b.prof_x(x0, x0 + sw, profile, c)
        drop = 0.5 if i % 2 == 0 else 0.25                      # stepped front edge
        b.box((x0 + 0.02, front_top[0] - 0.06, front_bot_z - drop), (x0 + sw - 0.02, front_top[0] + 0.14, front_bot_z + 0.2),
              c, bevel=0.03)
        for u in (0.88, 1.98, 3.08, 4.18):                      # studs along the slope, one per stripe per row
            if not (u in (1.98, 3.08) and abs(x0 + sw / 2) < 2.75):  # under the fish plaque
                _tilted_stud(b, x0 + sw / 2, front_top, u, ca, sa, c)
    plaque = lambda pts, o0, o1, col: _tilted_poly(b, pts, front_top, ca, sa, o0, o1, col)
    plaque([(-2.4, 1.45), (2.4, 1.45), (2.4, 3.65), (-2.4, 3.65)], -0.05, 0.12, P.DBG)   # fish plaque, read from above
    plaque([(-1.1, 1.85), (1.4, 1.85), (1.4, 3.25), (-1.1, 3.25)], 0.12, 0.24, P.ORANGE)
    plaque([(-0.8, 2.55), (-2.0, 1.7), (-2.0, 3.4)], 0.12, 0.24, P.YELLOW)
    plaque([(-0.4, 3.25), (0.6, 3.25), (0.6, 3.45), (-0.4, 3.45)], 0.12, 0.24, P.YELLOW)
    plaque([(0.75, 2.6), (1.1, 2.6), (1.1, 2.95), (0.75, 2.95)], 0.24, 0.3, P.WHITE)


def _tilted_poly(b, pts, front_top, ca, sa, o0, o1, c):
    """A plan polygon (x, u along the slope) on the awning top, extruded along its normal from o0 to o1."""
    if sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1])) > 0:
        pts = pts[::-1]                                         # clockwise, like prism_z
    p = lambda x, u, o: (x, front_top[0] + u * ca - o * sa, front_top[1] + u * sa + o * ca)
    n = len(pts)
    verts = [p(x, u, o0) for x, u in pts] + [p(x, u, o1) for x, u in pts]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def _tilted_stud(b, x, front_top, u, ca, sa, c):
    y0, z0 = front_top[0] + u * ca, front_top[1] + u * sa
    n = (0.0, -sa, ca)
    ring = [(STUD_R * math.cos(2 * math.pi * i / 6), STUD_R * math.sin(2 * math.pi * i / 6)) for i in range(6)]
    base = [(x + dx, y0 + dt * ca - 0.05 * n[1], z0 + dt * sa - 0.05 * n[2]) for dx, dt in ring]
    top = [(vx, vy + (STUD_H + 0.05) * n[1], vz + (STUD_H + 0.05) * n[2]) for vx, vy, vz in base]
    faces = [(i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i) for i in range(6)]
    faces += [tuple(reversed(range(6))), tuple(range(6, 12))]
    b._emit(base + top, faces, c)


def stall_stock(b):
    x0, y0, x1, y1 = TRAY
    r, rim_top, ice_top = 0.25, COUNTER_TOP + 0.3, COUNTER_TOP + 0.16                 # ice sits below the rim
    for lo, hi in (((x0, y0), (x1, y0 + r)), ((x0, y1 - r), (x1, y1)),
                   ((x0, y0 + r), (x0 + r, y1 - r)), ((x1 - r, y0 + r), (x1, y1 - r))):
        b.box((*lo, COUNTER_TOP), (*hi, rim_top), P.DBG, bevel=0.04)
    b.box((x0 + r, y0 + r, COUNTER_TOP), (x1 - r, y1 - r, ice_top), P.GLASS, bevel=0.02)
    for i, cx in enumerate((-1.95, -0.65, 0.65, 1.95)):                                   # one tidy row, heads to the customer
        body, accent = FISH_SETS[i]
        flat_fish(b, cx, 0.0, ice_top, 2.3, body, accent, -math.pi / 2)
    for (bx0, by0, bx1, by1, h), (sx0, sy0, sx1, sy1, sh), xs in ((CRATE_A, CRATE_A2, (-3.5, -2.5)),
                                                                   (CRATE_B, CRATE_B2, (2.5, 3.5))):
        slat_crate(b, bx0, by0, bx1, by1, PAD, h)
        slat_crate(b, sx0, sy0, sx1, sy1, PAD + h, sh)
        grid_studs(b, xs, (2.5, 3.5), PAD + h + sh, P.BROWN)


def stall_col(c, cx, left):
    local = lego.B()
    local.box((-3.68, -1.495, PAD), (3.68, 1.495, COUNTER_TOP), P.WHITE)
    local.box((-AW_HALF_W, -AW_HALF_S, 7.14), (AW_HALF_W, AW_HALF_S, 8.64), P.WHITE)
    for xa, xb in ((-3.565, -2.875), (2.875, 3.565)):
        local.box((xa, -0.345, COUNTER_TOP), (xb, 0.345, POST_TOP), P.WHITE)
    for (x0, y0, x1, y1, h), top in ((CRATE_A, CRATE_A2), (CRATE_B, CRATE_B2)):
        local.box((x0, y0, PAD), (x1, y1, PAD + h + top[4]), P.WHITE)
    place(c, local, cx, STALL_Y, left)


# ------------------------------------------------------------------ smokehouse
def smokehouse_base(b):
    b.box((SH_X0, SH_Y0, FLOOR), (SH_X1, SH_Y1, PAD), P.TAN, bevel=0.01)
    b.box((DOOR_X0, SH_Y0 - 0.3, FLOOR), (DOOR_X1, SH_Y0, PAD + 0.03), P.TAN, bevel=0.01)


def planks(b, x0, y0, x1, y1, k):
    z = PAD + k * COURSE
    b.box((x0, y0, z), (x1, y1, z + COURSE), P.BROWN, bevel=0.07)


def smokehouse_walls(b):
    yf0, yf1 = SH_Y0, SH_Y0 + WALL
    yb0, yb1 = SH_Y1 - WALL, SH_Y1
    for k in range(9):
        planks(b, SH_X0, yf0, DOOR_X0, yf1, k)
        planks(b, DOOR_X1, yf0, SH_X1, yf1, k)
        if k >= 6:
            planks(b, DOOR_X0, yf0, DOOR_X1, yf1, k)
        planks(b, SH_X0, yb0, SH_X1, yb1, k)
        for x0, x1 in ((SH_X0, SH_X0 + WALL), (SH_X1 - WALL, SH_X1)):
            if k in (4, 5):
                planks(b, x0, yf1, x1, WIN_Y0, k)
                planks(b, x0, WIN_Y1, x1, yb0, k)
            else:
                planks(b, x0, yf1, x1, yb0, k)
    for face in (SH_X0, SH_X1):
        b.box((face - 0.06, WIN_Y0 - 0.1, WIN_Z0 - 0.15), (face + 0.04, WIN_Y1 + 0.1, WIN_Z0 + 0.05), P.DBG, bevel=0.02)
        b.box((face - 0.06, WIN_Y0 - 0.1, WIN_Z1 - 0.05), (face + 0.04, WIN_Y1 + 0.1, WIN_Z1 + 0.15), P.DBG, bevel=0.02)
        b.box((face - 0.06, WIN_Y0 - 0.1, WIN_Z0), (face + 0.04, WIN_Y0 + 0.1, WIN_Z1), P.DBG, bevel=0.02)
        b.box((face - 0.06, WIN_Y1 - 0.1, WIN_Z0), (face + 0.04, WIN_Y1 + 0.1, WIN_Z1), P.DBG, bevel=0.02)
        g = 0.2 if face == SH_X0 else -0.4
        b.box((face + g, WIN_Y0 + 0.1, WIN_Z0 + 0.1), (face + g + 0.2, WIN_Y1 - 0.1, WIN_Z1 - 0.1), P.GLASS, bevel=0.01)
    b.box((SH_X0, SH_Y0 - 0.06, PAD), (DOOR_X0, SH_Y0, 1.65), P.BLUE, bevel=0.02)
    b.box((DOOR_X1, SH_Y0 - 0.06, PAD), (SH_X1, SH_Y0, 1.65), P.BLUE, bevel=0.02)
    b.box((SH_X0 - 0.06, SH_Y0, PAD), (SH_X0, SH_Y1, 1.65), P.BLUE, bevel=0.02)
    b.box((SH_X1, SH_Y0, PAD), (SH_X1 + 0.06, SH_Y1, 1.65), P.BLUE, bevel=0.02)
    b.box((SH_X0, SH_Y1, PAD), (SH_X1, SH_Y1 + 0.06, 1.65), P.BLUE, bevel=0.02)
    b.box((DOOR_X0, SH_Y0 - 0.06, PAD), (DOOR_X0 + 0.3, SH_Y0 + 0.06, DOOR_TOP), P.BLUE, bevel=0.02)
    b.box((DOOR_X1 - 0.3, SH_Y0 - 0.06, PAD), (DOOR_X1, SH_Y0 + 0.06, DOOR_TOP), P.BLUE, bevel=0.02)
    b.box((DOOR_X0, SH_Y0 - 0.06, DOOR_TOP - 0.3), (DOOR_X1, SH_Y0 + 0.06, DOOR_TOP), P.BLUE, bevel=0.02)


def smokehouse_roof(b):
    prism_y(b, SH_Y0, SH_Y0 + 0.4, [(SH_X0, EAVE), (SH_X1, EAVE), (1.5, RIDGE)], P.BROWN)
    prism_y(b, SH_Y1 - 0.4, SH_Y1, [(SH_X0, EAVE), (SH_X1, EAVE), (1.5, RIDGE)], P.BROWN)
    prism_y(b, ROOF_Y0, ROOF_Y1, [(ROOF_X0, EAVE), (ROOF_X0, EAVE + 0.35), (1.5, RIDGE + 0.35), (1.5, RIDGE)], P.BLUE)
    prism_y(b, ROOF_Y0, ROOF_Y1, [(1.5, RIDGE), (1.5, RIDGE + 0.35), (ROOF_X1, EAVE + 0.35), (ROOF_X1, EAVE)], P.BLUE)
    b.box((1.2, ROOF_Y0 - 0.1, RIDGE + 0.35), (1.8, ROOF_Y1 + 0.1, RIDGE + 0.6), P.DBG, bevel=0.03)
    for y in range(8, 17):
        b.cyl(1.5, y, RIDGE + 0.6, RIDGE + 0.6 + STUD_H, 0.2, P.DBG, 6)
    b.box((ROOF_X0, ROOF_Y0 - 0.05, EAVE - 0.15), (ROOF_X1, ROOF_Y0 + 0.15, EAVE + 0.15), P.WHITE, bevel=0.03)
    b.box((ROOF_X0, ROOF_Y1 - 0.15, EAVE - 0.15), (ROOF_X1, ROOF_Y1 + 0.05, EAVE + 0.15), P.WHITE, bevel=0.03)
    b.box((0.5, SH_Y0 - 0.06, 10.25), (2.1, SH_Y0, 10.85), P.YELLOW, bevel=0.02)     # gold fish glyph on the gable
    b.box((2.1, SH_Y0 - 0.06, 10.15), (2.8, SH_Y0, 10.95), P.YELLOW, bevel=0.02)
    b.box((1.1, SH_Y0 - 0.06, 10.85), (1.6, SH_Y0, 11.05), P.YELLOW, bevel=0.02)
    b.box((0.7, SH_Y0 - 0.07, 10.55), (0.85, SH_Y0 - 0.06, 10.7), P.INK, bevel=0.01)


def side_rack(b, x0, x1, y0, y1):
    for x in (x0 + 0.09, x1 - 0.09):
        for y in (y0 + 0.09, y1 - 0.09):
            b.box((x - 0.09, y - 0.09, PAD), (x + 0.09, y + 0.09, 7.6), P.BROWN)
    for z in (2.2, 4.3, 6.4, 7.6):
        b.box((x0, y0, z - 0.12), (x1, y1, z), P.TAN, bevel=0.02)


BENCH_X0, BENCH_X1 = -3.1, -0.9           # 2 barrels and a plank seat, flush against the front wall (y 8.0)
BENCH_Y0, BENCH_TOP = 7.0, 1.7


def smokehouse_racks(b):
    side_rack(b, -2.4, -1.6, 9.4, 14.6)
    side_rack(b, 4.6, 5.4, 9.4, 14.6)
    b.box((-1.6, 12.73, 8.53), (4.6, 12.87, 8.67), P.BROWN)
    for x in (-2.5, -1.5):
        b.cyl(x, 7.5, PAD, 1.45, 0.5, P.BROWN, 10)
        for z in (PAD + 0.2, 1.15):
            b.cyl(x, 7.5, z, z + 0.15, 0.53, P.DBG, 10)
    b.box((BENCH_X0, BENCH_Y0, 1.45), (BENCH_X1, SH_Y0, BENCH_TOP), P.TAN, bevel=0.04)
    grid_studs(b, (-2.5, -1.5), (7.5,), BENCH_TOP, P.TAN)


def fish_hang(b, cx, cy, rail_z):
    """A smoked fish hung tail-up in the xz plane (readable from the door): wedge tail, orange body, gold band."""
    top = rail_z - 0.3
    b.box((cx - 0.03, cy - 0.03, top), (cx + 0.03, cy + 0.03, rail_z), P.BROWN)
    prism_y(b, cy - 0.2, cy + 0.2, [(cx - 0.45, top), (cx + 0.45, top), (cx, top - 0.55)], P.YELLOW)
    b.box((cx - 0.38, cy - 0.21, top - 2.1), (cx + 0.38, cy + 0.21, top - 0.55), P.ORANGE, bevel=0.1)
    b.box((cx - 0.3, cy - 0.24, top - 1.55), (cx + 0.3, cy - 0.2, top - 1.0), P.YELLOW, bevel=0.01)
    b.box((cx - 0.2, cy - 0.24, top - 1.95), (cx - 0.06, cy - 0.2, top - 1.8), P.INK, bevel=0.01)


def smokehouse_fish(b):
    b.box((1.0, CH_Y0 + 0.13, 1.3), (2.0, CH_Y0 + 0.17, 2.2), P.WARM, bevel=0.02)
    b.box((1.1, CH_Y0 + 0.11, 1.05), (1.4, CH_Y0 + 0.15, 1.25), P.ORANGE, bevel=0.02)
    b.box((1.6, CH_Y0 + 0.11, 1.05), (1.9, CH_Y0 + 0.15, 1.25), P.ORANGE, bevel=0.02)
    for x in (-2.0, 5.0):
        for y0, z in ((9.8, 2.2), (11.35, 4.3), (12.9, 6.4)):
            fish(b, x, y0 + 0.7, z, 1.45, P.ORANGE, P.YELLOW, ang=math.pi / 2)
    for x in (-1.0, 0.25, 1.5, 2.75, 4.0):
        fish_hang(b, x, 12.8, 8.6)


def smokehouse_chimney(b):
    b.box((0.75, 13.85, PAD), (2.25, 15.15, 2.6), P.DBG, bevel=0.04)
    b.box((CH_X0, CH_Y0, 2.6), (CH_X1, CH_Y1, CH_TOP), P.RED)
    for z in (3.2, 6.4, 9.6, 12.0):
        b.box((CH_X0 - 0.05, CH_Y0 - 0.05, z), (CH_X1 + 0.05, CH_Y1 + 0.05, z + 0.3), P.DBG, bevel=0.02)
    b.box((CH_X0 - 0.15, CH_Y0 - 0.15, CH_TOP), (CH_X1 + 0.15, CH_Y1 + 0.15, CAP_TOP), P.DBG, bevel=0.04)
    grid_studs(b, (1, 2), (14, 15), CAP_TOP, P.DBG)


def smokehouse_col(c):
    c.box((SH_X0, SH_Y0, PAD), (DOOR_X0 + 0.3, SH_Y0 + WALL, EAVE), P.WHITE)
    c.box((DOOR_X1 - 0.3, SH_Y0, PAD), (SH_X1, SH_Y0 + WALL, EAVE), P.WHITE)
    c.box((DOOR_X0 + 0.3, SH_Y0, DOOR_TOP), (DOOR_X1 - 0.3, SH_Y0 + WALL, EAVE), P.WHITE)
    c.box((SH_X0, SH_Y1 - WALL, PAD), (SH_X1, SH_Y1, EAVE), P.WHITE)
    c.box((SH_X0, SH_Y0 + WALL, PAD), (SH_X0 + WALL, SH_Y1 - WALL, EAVE), P.WHITE)
    c.box((SH_X1 - WALL, SH_Y0 + WALL, PAD), (SH_X1, SH_Y1 - WALL, EAVE), P.WHITE)
    c.box((ROOF_X0, ROOF_Y0, EAVE), (ROOF_X1, ROOF_Y1, RIDGE + 0.6), P.BLUE)
    c.box((CH_X0, CH_Y0, PAD), (CH_X1, CH_Y1, CAP_TOP), P.RED)
    c.box((-2.4, 9.4, PAD), (-1.6, 14.6, 7.6), P.BROWN)
    c.box((4.6, 9.4, PAD), (5.4, 14.6, 7.6), P.BROWN)
    c.box((BENCH_X0, BENCH_Y0, PAD), (BENCH_X1, SH_Y0, BENCH_TOP), P.TAN)


def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_FishMarket_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv2", "Lv3")}

    def out(name, b, node):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[fishmarket] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills doorways
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    pad(b, 11.9, 18.3, -1.5, 7.5)
    pad(b, -18.3, -11.9, -1.5, 7.5)
    for cx, left in ((STALL_X, False), (-STALL_X, True)):
        local = lego.B()
        stall_pad_studs(local)
        place(b, local, cx, STALL_Y, left)
    out("Lv2_L01_Base", b, "Lv2")

    b = lego.B()
    for cx, left in ((STALL_X, False), (-STALL_X, True)):
        local = lego.B()
        stall_counter(local)
        place(b, local, cx, STALL_Y, left)
    out("Lv2_L02_Counters", b, "Lv2")

    b = lego.B()
    for cx, left in ((STALL_X, False), (-STALL_X, True)):
        local = lego.B()
        stall_frames(local)
        place(b, local, cx, STALL_Y, left)
    out("Lv2_L03_Frames", b, "Lv2")

    b = lego.B()
    for cx, left, k in ((STALL_X, False, 1), (-STALL_X, True, 0)):
        local = lego.B()
        stall_awnings(local, k)
        place(b, local, cx, STALL_Y, left)
    out("Lv2_L04_Awnings", b, "Lv2")

    b = lego.B()
    for cx, left in ((STALL_X, False), (-STALL_X, True)):
        local = lego.B()
        stall_stock(local)
        place(b, local, cx, STALL_Y, left)
    out("Lv2_L05_Stock", b, "Lv2")

    c = lego.B()
    stall_col(c, STALL_X, False)
    stall_col(c, -STALL_X, True)
    out_cols("Lv2", c)

    b = lego.B()
    smokehouse_base(b)
    out("Lv3_L01_Base", b, "Lv3")

    b = lego.B()
    smokehouse_walls(b)
    out("Lv3_L02_Walls", b, "Lv3")

    b = lego.B()
    smokehouse_roof(b)
    out("Lv3_L03_Roof", b, "Lv3")

    b = lego.B()
    smokehouse_racks(b)
    out("Lv3_L04_Racks", b, "Lv3")

    b = lego.B()
    smokehouse_fish(b)
    out("Lv3_L05_Fish", b, "Lv3")

    b = lego.B()
    smokehouse_chimney(b)
    out("Lv3_L06_Chimney", b, "Lv3")

    c = lego.B()
    smokehouse_col(c)
    out_cols("Lv3", c)

    atts = []
    for name, loc in (("ATT_Work_Stall3", (STALL_X + 2.75, STALL_Y, PAD)),     # the white tile behind each counter
                      ("ATT_Work_Stall4", (-STALL_X - 2.75, STALL_Y, PAD)),
                      ("ATT_Work_RackLeft", (-1.2, 11.5, PAD)),
                      ("ATT_Work_RackRight", (4.2, 11.5, PAD))):
        atts.append(lego.attach(name, loc))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[fishmarket] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[fishmarket] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, sitting on the code market's plinth (z 0.92) inside its 40 x 34 stud lot; the "
                     "bbox is the two flank stall pads and the back-centre smokehouse, not the whole lot; front -Y, "
                     "origin the market ground centre, built at the market's final 1.15 scale (place with no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 B/J): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., Lv3_Col01_COL..; the FBX "
                      "importer flattens empty parents, so the node name is the mesh name prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "stalls", "target": [0.0, 2.0, 4.5], "dist": 55, "az": 15, "el": 12},
            {"name": "stall_detail", "target": [14.0, 3.0, 4.0], "dist": 15, "az": 325, "el": 10},
            {"name": "smokehouse", "target": [1.5, 11.5, 5.5], "dist": 23, "az": 15, "el": 10},
            {"name": "chimney", "target": [1.5, 14.5, 10.5], "dist": 19, "az": 35, "el": 20},
            {"name": "interior", "target": [1.5, 11.5, 4.0], "dist": 14, "az": 0, "el": 2},
        ],
    }
