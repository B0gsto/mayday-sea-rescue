"""M_Bld_BoatYardAddons: the Boat Yard's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

The Lv1 yard stays the code-built `boatYard()` in src/shared/DockPieces.luau: plinth, workboat on its cradle, tall
yellow gantry, fence, slipway planks, front clutter. This asset adds only what the two levels add, in the code yard's
final frame: 39.5 x 43.5 stud lot, ground at z 0, plinth top z 0.92, front -Y (Roblox -Z), origin the yard's ground
centre. Place at the yard frame with no extra scale.

Lv2 (engine: 3 -> 5 builder slots): a yellow portal crane straddling the dry dock's line in the west third: west legs on
a concrete footing where the west dock wall goes, east legs on a footing on the yard beside the east wall, studded base
plates, side ties above head height, a girder with dark end caps, a cab on a railed platform (ladder up from the yard,
door onto the platform) on the east front leg, and a red trolley whose black chain lowers a 2 x 3 stud red engine over a
studded yellow engine cradle (Lv2) / the hull's open engine hatch (Lv3). A work bench stands against the east fence with
brick tools (3D, on pegs) over a tan board, stock on its two shelves.

Lv3 (5 -> 8 builder slots): a walled dry dock in the west third, open to the sea at the back: dark grey brick walls
(staggered seams) with a light coping, a yellow safety edge, solid grey/yellow fence panels and bollards; a dry floor
with a strip of water at the sea end behind a yellow/black hazard-striped caisson (orange posts and winch beam), a stair
down the south wall and a flight up from the yard, a ladder, a walk-in 6 x 6 pump house east of the dock (orange walls,
studded red roof, open door, pipe through the dock wall into the water) and a second boat hull on three dark-grey keel
blocks (the Lv2 engine cradle is the fourth) with two shores per side: solid red hull (bilge chine, raked bow) with a
white stripe, tan deck with an open engine hatch under the hook, white cabin.

Each level is a top-level node (Lv2, Lv3) holding 5-6 construction layers (L01_* bottom to L06_* top), one palette mesh
per layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). Collision is `<Node>_ColNN_COL`, one
convex box per object: posts, plates, bench, board, dock walls, steps, gate, hull in three bites, blocks and ladder, so
the walkways, the basin and the space under the crane stay open.

    python3 art/source/buildings/M_Bld_BoatYardAddons/maketex.py \
        --out build/prod/M_Bld_BoatYardAddons/textures/M_Bld_BoatYardAddons --name BoatYard --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_BoatYardAddons/build.py --out-root build/prod/M_Bld_BoatYardAddons \
        --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_BoatYardAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "BoatYard", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_BoatYard_Brick_ALB.png")
FLOOR = 0.92                    # code yard plinth top (0.8 at 1x, scaled 1.15)

# Lv2 bench against the east fence (inner face x 18.75), top just under the fence cap (3.68)
BX0, BX1 = 16.30, 18.72
BY0, BY1 = -4.10, 4.10
BTOP = 3.62
FACE = 18.30                    # tool board face, toward the yard (-X)
# Lv3 dry dock in the west third, open to the sea at the back plinth edge
WX0, WX1 = -18.75, -17.15       # west wall (1.6 thick)
EX0, EX1 = -11.10, -9.90        # east wall (1.2 thick)
SY0, SY1 = -9.40, -8.20         # south wall (1.2 thick)
NY = 21.40                      # wall ends just inside the plinth edge (21.73)
WALL_Z1, CAP_Z1 = 3.00, 3.26    # wall top / walkway top
HX, HY = -14.125, 6.30          # hull centre in the basin, bow to -Y
HZ = 2.80                       # hull keel bottom (on the keel blocks)
DFLOOR = 1.05                   # dry dock floor top
HB = 1.75                       # hull half beam
HTAPER = ((-6.80, HB), (2.60, HB), (4.00, 1.65), (5.20, 1.15), (6.10, 0.62), (6.60, 0.28))   # (x, half beam)
# hull bands (z0, z1, half-beam scale, colour): red hull, white stripe, red sheer
HBANDS = ((2.10, 2.75, 1.02, P.WHITE), (2.75, 3.35, 1.00, P.RED))      # over the red bilge hull (hull())
HKEEL = (0.00, 0.00, 0.25, 0.85, 1.55, 1.95)    # keel bottom per HTAPER station: flat, then a raked bow
KEEL_BLOCKS = ((3.40, 0.60), (9.00, 0.70), (12.00, 0.70))   # (y, half length); the cradle (CY0..CY1) sits between
DECK = 3.55
HUT_X0, HUT_X1, HUT_Y0, HUT_Y1 = -8.20, -2.20, 12.40, 18.40      # pump house footprint (6 x 6)
HUT_T, HUT_Z = 0.50, 6.50
DOOR_X0, DOOR_X1 = -6.80, -4.20
# Lv2 crane: a portal straddling the dock (Lv3): west legs on the west wall line, east legs on the yard beside the east
# wall (clear of the code gantry leg at x -9.78, y +-0.69); the hook hangs over the hull's engine hatch
GXW, GXE = -19.15, -9.20        # post centres: the west legs stand on the code yard's side wall line (x -19.55..-18.75)
FOOTW, FOOTE = (-19.72, -18.70), (-9.90, -8.50)     # concrete footings (x); the west one keeps the dock walkway clear
PHW, PHE = 0.40, 0.55           # post half widths (west narrower: it fits the code side wall's 0.8 width)
GYC, GY = 5.70, 3.70            # hatch / cradle centre y; posts at GYC +- GY
FY0, FY1 = GYC - GY - 1.0, GYC + GY + 1.0
POST = 1.10
FOOT_Z = 3.70                   # footing top, above the dock coping (3.26)
PLATE_Z = 4.00                  # base plate top
BEAM_Z0, BEAM_Z1 = 16.80, 18.00
TIES = (9.40, 13.40)            # side ties, above head height on the walkway
CY0, CY1 = 4.10, 7.30           # engine stand (Lv2) between the keel blocks, under the hull bottom (Lv3)
PLAT_Z = 9.30                   # cab platform top, on the east front post


def patch_lod_names():
    """Layer meshes use game node names (Lv2_L01_..., Lv3_L01_...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def slab(b, xa, xb, ya, yb, za, zb, t, c):
    """A plank between two vertical sections at (xa, ya) and (xb, yb), t thick in Y; za / zb = (z0, z1) per end."""
    h = t / 2
    b._emit([(xa, ya - h, za[0]), (xa, ya + h, za[0]), (xa, ya + h, za[1]), (xa, ya - h, za[1]),
             (xb, yb - h, zb[0]), (xb, yb + h, zb[0]), (xb, yb + h, zb[1]), (xb, yb - h, zb[1])],
            ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)), c)


def disc_y(b, cx, cy, cz, r, length, c, n=10):
    """A closed cylinder lying along Y (trolley wheels)."""
    y0, y1 = cy - length / 2, cy + length / 2
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def prism_y(b, y0, y1, profile, c):
    """An (x, z) polygon extruded along Y."""
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def clip(poly, x0, x1, z0, z1):
    """Sutherland-Hodgman clip of a convex (x, z) polygon to a rectangle."""
    for axis, lim, keep_below in ((0, x1, True), (0, x0, False), (1, z1, True), (1, z0, False)):
        out = []
        for i, p in enumerate(poly):
            q = poly[(i + 1) % len(poly)]
            pin = (p[axis] <= lim) if keep_below else (p[axis] >= lim)
            qin = (q[axis] <= lim) if keep_below else (q[axis] >= lim)
            if pin:
                out.append(p)
            if pin != qin:
                t = (lim - p[axis]) / (q[axis] - p[axis])
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
        poly = [p for i, p in enumerate(out) if abs(p[0] - out[i - 1][0]) + abs(p[1] - out[i - 1][1]) > 1e-6]
        if not poly:
            break
    return poly


def hazard(b, x0, x1, y, z0, z1, depth, thick=1.0, period=1.5):
    """Black plate (thick in Y) with yellow 45-degree stripes on its -Y face (y is the face plane, depth proud)."""
    b.box((x0, y, z0), (x1, y + thick, z1), P.BLACK, bevel=0.05)
    k = x0 - (z1 - z0)
    while k < x1:
        poly = [(k, z0), (k + period / 2, z0), (k + period / 2 + (z1 - z0), z1), (k + (z1 - z0), z1)]
        poly = clip(poly, x0, x1, z0, z1)
        if len(poly) >= 3:
            prism_y(b, y - depth, y, poly, P.YELLOW)
        k += period


# ------------------------------------------------------------------ Lv2 kit
def gantry(b):
    """Yellow portal crane over the dock line: concrete footings, studded base plates, four posts, ties, the girder, and
    a cab on a railed platform on the east front post with a ladder up from the yard."""
    for xc, (fx0, fx1), ph in ((GXW, FOOTW, PHW), (GXE, FOOTE, PHE)):
        b.box((fx0, FY0, FLOOR), (fx1, FY1, FOOT_Z), P.DBG, bevel=0.08)                  # concrete footing
        b.box((fx0 + 0.06, FY0 + 0.25, FOOT_Z), (fx1 - 0.06, FY1 - 0.25, PLATE_Z), P.YELLOW, bevel=0.06)
        for sy in (-1, 1):
            py = GYC + sy * GY
            b.studs(fx0 + 0.25, fx1 - 0.25, py + sy * 0.70, py + sy * 1.55, PLATE_Z, P.YELLOW, step=0.85, r=0.30,
                    h=0.22, n=10)                                                         # studs beside each post
            b.box((xc - ph - 0.10, py - 0.65, PLATE_Z), (xc + ph + 0.10, py + 0.65, PLATE_Z + 0.14), P.DBG, bevel=0.04)
            b.box((xc - ph, py - POST / 2, PLATE_Z + 0.14), (xc + ph, py + POST / 2, BEAM_Z0), P.YELLOW, bevel=0.06)
            b.box((xc - ph - 0.11, py - 0.66, BEAM_Z1), (xc + ph + 0.11, py + 0.66, BEAM_Z1 + 0.18), P.DBG, bevel=0.04)
            ya, yb = sorted((py - sy * 0.80, py - sy * 2.35))
            b.studs(xc - 0.3, xc + 0.3, ya, yb, BEAM_Z1, P.YELLOW, step=0.80, r=0.30, h=0.24, n=10)   # end beam studs
        for z0 in TIES:                                                                   # front post to back post
            b.box((xc - ph + 0.05, GYC - GY, z0), (xc + ph - 0.05, GYC + GY, z0 + 0.80), P.YELLOW, bevel=0.05)
        b.box((xc - ph - 0.05, GYC - GY - 0.60, BEAM_Z0), (xc + ph + 0.05, GYC + GY + 0.60, BEAM_Z1), P.YELLOW,
              bevel=0.06)
    gx0, gx1 = GXW - PHW - 0.15, GXE + 0.70
    b.box((gx0, GYC - 1.20, BEAM_Z0), (gx1, GYC + 1.20, BEAM_Z1), P.YELLOW, bevel=0.07)    # girder across the dock
    b.box((gx1, GYC - 1.30, BEAM_Z0 - 0.10), (gx1 + 0.30, GYC + 1.30, BEAM_Z1 + 0.16), P.DBG, bevel=0.04)
    b.box((gx0 - 0.30, GYC - 1.30, BEAM_Z0 - 0.10), (gx0, GYC + 1.30, BEAM_Z1 + 0.16), P.DBG, bevel=0.04)
    b.studs(gx0 + 0.3, gx1 - 0.3, GYC - 0.95, GYC + 0.95, BEAM_Z1, P.YELLOW, step=1.80, r=0.36, h=0.26, n=10)
    # cab platform bolted to the east front post's yard side, two braces under it
    py = GYC - GY
    px0, px1, py0, py1 = GXE + POST / 2, GXE + 4.30, py - 1.45, py + 1.45
    b.box((px0, py0, PLAT_Z - 0.30), (px1, py1, PLAT_Z), P.DBG, bevel=0.05)
    for y in (py0 + 0.35, py1 - 0.35):
        b.beam((px0, y, PLAT_Z - 2.60), (px1 - 0.60, y, PLAT_Z - 0.30), 0.30, 0.30, P.DBG)
    # cab: yellow box, windows front, back and toward the hook, white studded roof, red door onto the platform
    cx0, cx1, cy0, cy1, cz0, cz1 = px0 + 0.10, px0 + 2.30, py0 + 0.15, py1 - 0.15, PLAT_Z, PLAT_Z + 2.60
    b.box((cx0, cy0, cz0), (cx1, cy1, cz1), P.YELLOW, bevel=0.07)
    b.box((cx0 + 0.25, cy0 - 0.05, cz0 + 1.00), (cx1 - 0.25, cy0, cz1 - 0.35), P.INK)         # front window
    b.box((cx0 + 0.25, cy1, cz0 + 1.00), (cx1 - 0.25, cy1 + 0.05, cz1 - 0.35), P.INK)         # back window
    b.box((cx1 - 0.04, py - 0.70, cz0), (cx1 + 0.08, py + 0.70, cz0 + 2.15), P.WHITE, bevel=0.03)   # door frame
    b.box((cx1, py - 0.52, cz0 + 0.05), (cx1 + 0.12, py + 0.52, cz0 + 2.00), P.RED, bevel=0.03)       # door
    b.box((cx1 + 0.12, py - 0.32, cz0 + 1.15), (cx1 + 0.15, py + 0.32, cz0 + 1.75), P.INK)           # door window
    b.box((cx0 - 0.20, cy0 - 0.20, cz1), (cx1 + 0.20, cy1 + 0.20, cz1 + 0.28), P.WHITE, bevel=0.05)
    b.studs(cx0, cx1, cy0, cy1, cz1 + 0.28, P.WHITE, step=1.2, r=0.34, h=0.22, n=10)
    # platform railing on the back edge and the far end; the front edge stays open where the ladder from the yard arrives
    rx = px1 - 0.10
    for x, y in ((cx1 + 0.15, py1 - 0.10), (rx, py1 - 0.10), (rx, py0 + 0.10)):
        b.box((x - 0.08, y - 0.08, PLAT_Z), (x + 0.08, y + 0.08, PLAT_Z + 1.20), P.YELLOW, bevel=0.02)
    b.box((cx1, py1 - 0.21, PLAT_Z + 1.10), (px1, py1, PLAT_Z + 1.32), P.YELLOW, bevel=0.03)
    b.box((rx - 0.11, py0, PLAT_Z + 1.10), (rx + 0.11, py1, PLAT_Z + 1.32), P.YELLOW, bevel=0.03)
    lx0, lx1, ly = cx1 + 0.25, px1 - 0.45, py0 - 0.12
    for x in (lx0, lx1):
        b.box((x - 0.08, ly - 0.10, FLOOR), (x + 0.08, ly + 0.10, PLAT_Z + 1.20), P.YELLOW, bevel=0.02)
    z = FLOOR + 0.60
    while z < PLAT_Z - 0.20:
        b.box((lx0 + 0.08, ly - 0.07, z), (lx1 - 0.08, ly + 0.07, z + 0.12), P.DBG, bevel=0.0)
        z += 0.65


def hoist(b):
    """Red trolley over the dock, a black chain, a hook block and a 2 x 3 stud red engine hanging over the cradle /
    hatch, and the studded engine cradle on the floor under it."""
    x, y = HX, GYC
    b.box((x - 0.85, y - 1.00, 15.62), (x + 0.85, y + 1.00, 16.78), P.RED, bevel=0.06)      # trolley body
    for cx in (x - 0.45, x + 0.45):
        for sy in (-1, 1):
            disc_y(b, cx, y + sy * 1.34, 17.15, 0.30, 0.24, P.DBG, n=12)                    # rollers on the girder
    z, k = 15.62, 0
    while z > 11.30:                                                              # chain links, alternating 90 degrees
        if k % 2:
            b.box((x - 0.20, y - 0.07, z - 0.50), (x + 0.20, y + 0.07, z), P.BLACK)
        else:
            b.box((x - 0.07, y - 0.20, z - 0.50), (x + 0.07, y + 0.20, z), P.BLACK)
        z -= 0.40
        k += 1
    b.box((x - 0.55, y - 0.45, 10.70), (x + 0.55, y + 0.45, 11.30), P.DBG, bevel=0.05)  # hook block
    # engine: red block 2 x 3 studs (2.0 x 3.0, fits the hull's 2.2 x 3.4 hatch), black heads, silver pulley at the front
    # round 4: lowered to just above the engine stand (Lv2) and the hatch coaming (Lv3, world z 6.75)
    ex0, ex1, ey0, ey1, ez0, ez1 = x - 1.00, x + 1.00, y - 1.50, y + 1.50, 7.30, 9.20
    for sy in (-1, 1):
        b.beam((x, y + sy * 0.35, 10.75), (x, y + sy * 1.10, ez1 + 0.55), 0.22, 0.22, P.BLACK)   # slings
    b.box((ex0, ey0, ez0), (ex1, ey1, ez1), P.RED, bevel=0.10)
    b.box((ex0 + 0.15, ey0 + 0.15, ez0 - 0.40), (ex1 - 0.15, ey1 - 0.15, ez0), P.DBG, bevel=0.05)   # sump
    for i in range(3):
        yy = ey0 + 0.50 + i * 1.00
        b.cyl(x, yy, ez1, ez1 + 0.80, 0.40, P.BLACK, n=12)                                    # cylinder heads
        b.cyl(x, yy, ez1 + 0.80, ez1 + 0.98, 0.26, P.DBG, n=10)
        for sx in (-1, 1):
            b.cyl(x + sx * 0.66, yy, ez1, ez1 + 0.22, 0.24, P.RED, n=10, bottom=False)       # studs
    disc_y(b, x, ey0 - 0.18, ez0 + 0.95, 0.72, 0.30, P.LBG, n=14)                            # pulley
    disc_y(b, x, ey0 - 0.42, ez0 + 0.95, 0.30, 0.20, P.DBG, n=10)
    b.box((ex1, y - 0.80, ez0 + 0.40), (ex1 + 0.40, y + 0.80, ez1 - 0.35), P.DBG, bevel=0.04)   # exhaust manifold
    # engine stand: the landing spot under the hook. Lv3: its base is a fourth support under the hull bottom (z HZ)
    # and the column hides inside the solid hull (inside the flat bottom, +-1.26); the studded top and the chocks
    # show in the hatch (hole x +-1.1, y GYC +-1.7, deck world z 6.35)
    b.box((x - 1.50, CY0, FLOOR), (x + 1.50, CY1, 2.25), P.DBG, bevel=0.07)
    b.box((x - 1.40, CY0 + 0.10, 2.25), (x + 1.40, CY1 - 0.10, 2.58), P.YELLOW, bevel=0.06)
    b.box((x - 1.10, CY0 + 0.30, 2.58), (x + 1.10, CY1 - 0.30, 5.95), P.DBG, bevel=0.05)          # column
    b.box((x - 1.22, CY0 + 0.20, 5.95), (x + 1.22, CY1 - 0.20, 6.28), P.YELLOW, bevel=0.05)        # top plate
    b.studs(x - 1.05, x + 1.05, y - 1.05, y + 1.05, 6.28, P.YELLOW, step=1.05, r=0.34, h=0.20, n=10)
    for sy in (-1, 1):                                                            # timber chocks either end
        b.box((x - 1.05, y + sy * 1.40 - 0.18, 6.28), (x + 1.05, y + sy * 1.40 + 0.18, 6.60), P.BROWN, bevel=0.04)


def bench(b):
    """Tan studded bench on dark legs with two shelves, a tan back board in a dark frame against the east fence."""
    for x in (BX0 + 0.15, BX1 - 0.52):
        for y in (BY0 + 0.15, BY1 - 0.65):
            b.box((x, y, FLOOR), (x + 0.50, y + 0.50, 3.30), P.DBG)
    b.box((BX0, BY0, 3.30), (BX1, BY1, BTOP), P.TAN, bevel=0.08)
    b.studs(BX0 + 0.35, BX1 - 0.35, BY0 + 0.45, BY1 - 0.45, BTOP, P.TAN, step=1.20, r=0.34, h=0.22)
    for z in (1.75, 2.65):
        b.box((BX0 + 0.15, BY0 + 0.25, z), (BX1 - 0.12, BY1 - 0.25, z + 0.22), P.DBG, bevel=0.04)
    b.box((18.30, -3.60, BTOP), (BX1, 3.60, 7.10), P.TAN, bevel=0.04)            # back board on the bench top
    for y0, y1 in ((-3.90, -3.55), (3.55, 3.90)):                                # dark frame: end posts
        b.box((18.26, y0, BTOP), (18.30, y1, 7.12), P.DBG, bevel=0.02)
    b.box((18.26, -3.90, 6.92), (18.30, 3.90, 7.12), P.DBG, bevel=0.02)          # top rail
    b.box((18.26, -3.90, BTOP), (18.30, 3.90, BTOP + 0.24), P.DBG, bevel=0.02)   # bottom rail


def tool(b, kind, y, z):
    """One hung brick tool, 3D (0.6 deep) with studs on its handle, on two pegs; tools point into the yard (-X)."""
    d = 0.60
    def part(y0, y1, z0, z1, c, studs=False):
        b.box((FACE - d, y + y0, z + z0), (FACE - 0.08, y + y1, z + z1), c, bevel=0.06)
        if studs:
            b.cyl_x(FACE - d - 0.07, y + (y0 + y1) / 2, z + (z0 + z1) / 2, 0.15, 0.14, c, n=6)
    for pz in (0.35, 1.30):
        b.cyl_x(FACE - 0.09, y, z + pz, 0.10, 0.18, P.DBG, n=6)
    if kind == "hammer":
        part(-0.20, 0.20, 0.0, 1.45, P.BROWN, True)
        part(-0.48, 0.48, 1.20, 1.80, P.DBG, True)
        part(-0.48, -0.25, 1.80, 2.00, P.DBG)
    elif kind == "wrench":
        part(-0.18, 0.18, 0.0, 1.50, P.LBG, True)
        part(-0.45, 0.45, 1.50, 1.80, P.LBG)
        part(-0.45, -0.17, 1.80, 2.15, P.LBG)
        part(0.17, 0.45, 1.80, 2.15, P.LBG)
    elif kind == "drill":
        part(-0.30, 0.30, 0.65, 1.50, P.DBG, True)
        part(-0.14, 0.14, 0.10, 0.65, P.ORANGE)
        part(-0.06, 0.06, 1.50, 2.10, P.LBG)
        part(-0.50, 0.50, 1.50, 1.80, P.ORANGE)
    else:  # saw
        part(-0.55, 0.55, 0.75, 1.95, P.LBG)
        part(-0.20, 0.20, 0.0, 0.75, P.YELLOW, True)
        for i in range(4):
            part(-0.48 + i * 0.32, -0.27 + i * 0.32, 0.55, 0.75, P.LBG)


def bench_tools(b):
    """Tools on the board, a vice and a toolbox on the top, stock on the upper shelf: no loose props on the floor."""
    for i, kind in enumerate(("hammer", "saw", "wrench", "drill")):
        tool(b, kind, -2.60 + i * 1.75, 4.25)
    b.box((16.60, -3.55, BTOP), (17.40, -3.05, BTOP + 0.50), P.DBG, bevel=0.04)   # vice body
    b.box((16.60, -3.55, BTOP + 0.50), (17.40, -3.40, BTOP + 0.78), P.LBG, bevel=0.02)
    b.box((16.60, -3.20, BTOP + 0.50), (17.40, -3.05, BTOP + 0.78), P.LBG, bevel=0.02)
    b.box((16.10, -3.38, BTOP + 0.34), (17.90, -3.22, BTOP + 0.48), P.RED, bevel=0.02)
    b.box((16.60, 2.50, BTOP), (17.60, 3.60, BTOP + 0.80), P.RED, bevel=0.06)     # toolbox on the top
    b.box((16.85, 2.80, BTOP + 0.80), (17.35, 3.30, BTOP + 0.92), P.WHITE, bevel=0.02)
    b.box((16.80, 0.40, BTOP), (18.00, 0.85, BTOP + 0.18), P.BROWN, bevel=0.03)   # a board off the saw
    b.box((16.60, -3.45, 2.87), (17.50, -2.35, 3.18), P.RED, bevel=0.04)          # shelf stock
    b.box((16.55, -3.50, 3.18), (17.55, -2.30, 3.26), P.DBG, bevel=0.03)
    for i in range(3):
        b.box((16.60, 1.00 + i * 0.05, 2.87 + i * 0.12), (18.55, 3.60 - i * 0.06, 2.99 + i * 0.12), P.BROWN, bevel=0.02)
    b.box((16.70, -0.40, 2.87), (18.40, 0.35, 3.18), P.BLUE, bevel=0.04)
    b.box((16.85, -0.32, 3.18), (18.25, 0.27, 3.24), P.LBG, bevel=0.02)


# ------------------------------------------------------------------ Lv3 kit
SEAM = 0.07                     # brick seam width / proud
COURSES = 3
BRICK = 4.0


def keep_faces(b, keep):
    """Keep only these faces of the box just emitted (lego.B.box order: bottom, top, -Y, +X, +Y, -X)."""
    last = b.f[-6:]
    b.f[-6:] = [last[i] for i in keep]


def seams_y(b, x, face, y0, y1, z0, z1):
    """Brick seams on a wall face at x (face = -1 / +1 outward normal): COURSES courses, staggered joints every BRICK."""
    h = (z1 - z0) / COURSES
    xa, xb = (x - SEAM, x) if face < 0 else (x, x + SEAM)
    for i in range(1, COURSES):
        b.box((xa, y0, z0 + i * h - SEAM / 2), (xb, y1, z0 + i * h + SEAM / 2), P.BLACK, bevel=0.0)
    for i in range(COURSES):
        y = y0 + (BRICK / 2 if i % 2 else BRICK)
        while y < y1 - 0.3:
            b.box((xa, y - SEAM / 2, z0 + i * h), (xb, y + SEAM / 2, z0 + (i + 1) * h), P.BLACK, bevel=0.0)
            keep_faces(b, (2, 4, 3 if face > 0 else 5))     # back, top and bottom are hidden (wall, seams, floor)
            y += BRICK


def seams_x(b, y, face, x0, x1, z0, z1):
    h = (z1 - z0) / COURSES
    ya, yb = (y - SEAM, y) if face < 0 else (y, y + SEAM)
    for i in range(1, COURSES):
        b.box((x0, ya, z0 + i * h - SEAM / 2), (x1, yb, z0 + i * h + SEAM / 2), P.BLACK, bevel=0.0)
    for i in range(COURSES):
        x = x0 + (BRICK / 2 if i % 2 else BRICK)
        while x < x1 - 0.3:
            b.box((x - SEAM / 2, ya, z0 + i * h), (x + SEAM / 2, yb, z0 + (i + 1) * h), P.BLACK, bevel=0.0)
            keep_faces(b, (3, 5, 4 if face > 0 else 2))
            x += BRICK


def walls(b):
    """Dark grey brick dock walls (staggered seams), light coping with a yellow safety edge, studs, solid fence panels
    along the basin edge, bollards, a dry floor."""
    for x0, x1, y0, y1 in ((WX0, WX1, SY0, NY), (EX0, EX1, SY0, NY), (WX1, EX0, SY0, SY1)):
        b.box((x0, y0, FLOOR), (x1, y1, WALL_Z1), P.DBG, bevel=0.06)
    b.box((WX1, SY1, FLOOR), (EX0, NY, DFLOOR), P.LBG, bevel=0.03)                                   # dry basin floor
    b.box((WX0 - 0.05, SY0 - 0.05, WALL_Z1), (WX1 + 0.05, NY + 0.05, CAP_Z1), P.LBG, bevel=0.05)   # coping
    b.box((EX0 - 0.05, SY0 - 0.05, WALL_Z1), (EX1 + 0.05, NY + 0.05, CAP_Z1), P.LBG, bevel=0.05)
    b.box((WX1, SY0 - 0.05, WALL_Z1), (EX0, SY1 + 0.05, CAP_Z1), P.LBG, bevel=0.05)
    seams_y(b, WX1, +1, SY1, NY, FLOOR, WALL_Z1)                      # inner faces + the yard side of the east wall
    seams_y(b, EX0, -1, SY1, NY, DFLOOR, WALL_Z1)
    seams_y(b, EX1, +1, SY0, NY, FLOOR, WALL_Z1)
    seams_x(b, SY0, -1, WX1, EX0, FLOOR, WALL_Z1)
    z = CAP_Z1
    for x0, x1, y0, y1 in ((WX1 - 0.28, WX1, SY0 - 0.05, NY + 0.05), (EX0, EX0 + 0.28, SY0 - 0.05, NY + 0.05),
                           (WX1, EX0, SY1 - 0.23, SY1 + 0.05)):                                    # yellow safety edge
        b.box((x0, y0, z), (x1, y1, z + 0.07), P.YELLOW, bevel=0.0)
    for x0, x1, y0, y1 in ((WX0 + 0.25, WX1 - 0.45, SY0 + 0.30, NY - 0.30), (EX0 + 0.45, EX1 - 0.25, SY0 + 0.30, NY - 0.30)):
        b.studs(x0, x1, y0, y1, CAP_Z1, P.LBG, step=2.40, r=0.30, h=0.22)
    # solid fence panels along the basin edge of each walkway (light grey panel, yellow cap rail, dark posts: they must
    # not blur into the hull's red/white bands); gaps at the ladder, the south stair and the crane's west footing
    def fence(x, y0, y1):
        n = max(1, int(round((y1 - y0) / 3.0)))
        step = (y1 - y0) / n
        for i in range(n):
            ya, yb = y0 + i * step, y0 + (i + 1) * step
            b.box((x - 0.10, ya + 0.12, CAP_Z1 + 0.30), (x + 0.10, yb - 0.12, CAP_Z1 + 1.15), P.LBG, bevel=0.03)
            b.box((x - 0.14, ya, CAP_Z1 + 1.15), (x + 0.14, yb, CAP_Z1 + 1.40), P.YELLOW, bevel=0.04)
            b.cyl(x, ya, CAP_Z1, CAP_Z1 + 1.40, 0.24, P.DBG, n=8, bottom=False)
        b.cyl(x, y1, CAP_Z1, CAP_Z1 + 1.40, 0.24, P.DBG, n=8, bottom=False)
    fence(WX1 - 0.14, SY1 + 2.6, FY0 - 0.2)
    fence(WX1 - 0.14, FY1 + 0.2, 20.0)
    fence(EX0 + 0.14, SY1 + 2.6, 10.5)
    fence(EX0 + 0.14, 11.55, 20.0)
    for x, y in ((WX0 + 0.30, -4.0), (WX0 + 0.30, 13.0), (WX0 + 0.30, 17.5),
                 (EX1 - 0.30, -4.0), (EX1 - 0.30, 0.0), (EX1 - 0.30, 11.0)):                       # bollards
        b.cyl(x, y, CAP_Z1, CAP_Z1 + 0.80, 0.40, P.ORANGE, n=12, bottom=False)
        b.cyl(x, y, CAP_Z1 + 0.80, CAP_Z1 + 0.98, 0.52, P.BLACK, n=12)


def water(b):
    """A strip of water at the sea end of the basin (the dock stays dry), behind the caisson's line."""
    b.box((WX1 + 0.05, 16.30, DFLOOR), (EX0 - 0.05, 19.60, 1.24), P.BLUE, bevel=0.03)


def steps(b):
    """Three treads up from the yard to the east walkway, three down from the south walkway into the basin."""
    for y0, y1, z1 in ((-11.65, -10.90, 1.50), (-10.90, -10.15, 2.08), (-10.15, -9.40, 2.66)):
        b.box((-10.95, y0, FLOOR), (-9.45, y1, z1), P.LBG, bevel=0.04)
        b.box((-10.99, y0, z1 - 0.10), (-9.41, y0 + 0.10, z1), P.DBG, bevel=0.02)
    for y0, y1, z1 in ((SY1, SY1 + 0.80, 2.73), (SY1 + 0.80, SY1 + 1.60, 2.20), (SY1 + 1.60, SY1 + 2.40, 1.67)):
        b.box((WX1, y0, FLOOR), (EX0, y1, z1), P.LBG, bevel=0.04)
        b.box((WX1, y1 - 0.10, z1 - 0.10), (EX0, y1, z1), P.DBG, bevel=0.02)


def gate(b):
    """Orange gate posts, the yellow lifting beam with its drum, a hazard-striped yellow/black caisson in the mouth,
    and the pump house (walk-in, coloured walls, studded roof, open door) with a pipe into the basin."""
    for x0, x1 in ((WX0 + 0.75, WX1), (EX0, EX0 + 0.85)):
        b.box((x0, 20.30, CAP_Z1), (x1, 21.00, 4.00), P.ORANGE, bevel=0.05)
    b.box((-18.10, 20.35, 3.95), (-10.15, 21.00, 4.55), P.YELLOW, bevel=0.06)     # lifting beam
    b.cyl_x(-14.125, 20.67, 4.87, 0.32, 1.10, P.DBG)                             # winch drum
    for x in (-15.60, -12.65):
        b.box((x - 0.05, 20.42, 3.30), (x + 0.05, 20.55, 3.95), P.BLACK)          # chains to the caisson
    hazard(b, WX1, EX0, 19.50, DFLOOR, 3.30, 0.07, thick=1.10)                    # caisson: black body, yellow stripes
    b.box((WX1, 19.45, 3.30), (EX0, 20.65, 3.50), P.DBG, bevel=0.05)             # caisson deck
    b.studs(WX1 + 0.3, EX0 - 0.3, 19.60, 20.50, 3.50, P.YELLOW, step=1.5, r=0.40, h=0.22, n=10)
    # ---- pump house
    x0, x1, y0, y1, T, H = HUT_X0, HUT_X1, HUT_Y0, HUT_Y1, HUT_T, HUT_Z
    b.box((x0, y0, FLOOR), (x1, y1, FLOOR + 0.12), P.TAN, bevel=0.02)                       # floor
    b.box((x0, y0, FLOOR + 0.12), (x0 + T, y1, H), P.ORANGE, bevel=0.05)                   # west wall
    b.box((x1 - T, y0, FLOOR + 0.12), (x1, y1, H), P.ORANGE, bevel=0.05)                   # east wall
    b.box((x0 + T, y1 - T, FLOOR + 0.12), (x1 - T, y1, H), P.ORANGE, bevel=0.05)           # north wall
    b.box((x0 + T, y0, FLOOR + 0.12), (DOOR_X0, y0 + T, H), P.ORANGE, bevel=0.05)          # south wall, either side of the door
    b.box((DOOR_X1, y0, FLOOR + 0.12), (x1 - T, y0 + T, H), P.ORANGE, bevel=0.05)
    b.box((DOOR_X0, y0, 5.92), (DOOR_X1, y0 + T, H), P.ORANGE, bevel=0.05)                 # lintel
    b.box((x0, y0, FLOOR + 0.12), (x1, y0 + 0.08 + T, 1.70), P.DBG, bevel=0.0)             # dark base course
    for jx0, jx1 in ((DOOR_X0 - 0.30, DOOR_X0), (DOOR_X1, DOOR_X1 + 0.30)):                # door frame
        b.box((jx0, y0 - 0.06, FLOOR + 0.12), (jx1, y0 + T + 0.06, 5.98), P.WHITE, bevel=0.03)
    b.box((DOOR_X0 - 0.30, y0 - 0.06, 5.92), (DOOR_X1 + 0.30, y0 + T + 0.06, 6.22), P.WHITE, bevel=0.03)
    b.box((DOOR_X0 - 0.25, y0 - 2.50, FLOOR + 0.12), (DOOR_X0 - 0.02, y0 - 0.05, 5.80), P.BROWN, bevel=0.03)   # open door leaf
    b.box((x1 - 0.04, 14.20, 3.30), (x1 + 0.06, 16.60, 5.20), P.INK)                       # window, east face
    b.box((x1 - 0.04 - 0.16, 14.04, 3.14), (x1 + 0.02, 16.76, 3.30), P.WHITE, bevel=0.02)  # sill
    b.box((-5.30, y1 - 0.04, 3.30), (-3.30, y1 + 0.06, 5.20), P.INK)                       # window, north face
    b.box((x0 - 0.55, y0 - 0.55, H), (x1 + 0.55, y1 + 0.55, H + 0.50), P.RED, bevel=0.08)  # roof slab
    b.studs(x0 - 0.2, x1 + 0.2, y0 - 0.2, y1 + 0.2, H + 0.50, P.RED, step=1.5, r=0.42, h=0.30, n=10)
    # inside: pump block, red flywheel, the pipe leaving through the west wall
    b.box((x0 + T + 0.20, 15.90, FLOOR + 0.12), (x0 + T + 1.80, 17.90, 2.50), P.DBG, bevel=0.06)
    b.cyl_x(x0 + T + 1.10, 16.90, 3.20, 0.85, 0.35, P.RED, n=10)
    b.box((x0 + T + 0.30, 16.60, 2.50), (x0 + T + 0.90, 17.20, 3.20), P.LBG)
    # pipe: through the hut wall and the dock wall into the basin, saddles under the outdoor run, spout over the water
    PZ0, PZ1 = 1.70, 2.30
    b.box((-11.80, 16.60, PZ0), (x0 + T, 17.20, PZ1), P.LBG, bevel=0.04)
    for xs in (-9.30, -8.75):
        b.box((xs - 0.12, 16.52, PZ0 - 0.04), (xs + 0.12, 17.28, PZ1 + 0.04), P.DBG, bevel=0.0)          # flanges
    for xs in (-9.10, -8.55):
        b.box((xs - 0.15, 16.70, FLOOR), (xs + 0.15, 17.10, PZ0), P.DBG, bevel=0.02)                       # saddles
    b.box((-11.80, 16.60, 1.20), (-11.20, 17.20, PZ1), P.LBG, bevel=0.04)                                     # spout, down to the water
    b.box((-11.90, 16.52, 1.20), (-11.10, 17.28, 1.34), P.DBG, bevel=0.0)


def blocks(b):
    """Three chunky dark-grey keel blocks (the Lv2 engine cradle is the fourth) and two brown shores per side."""
    for y, half in KEEL_BLOCKS:      # tops just into the hull bottom (no studs: the hull hides them)
        b.box((HX - 1.05, y - half, DFLOOR), (HX + 1.05, y + half, HZ + 0.10), P.DBG, bevel=0.07)
    for sx in (-1, 1):
        for y in (HY - 1.50, HY + 1.50):            # clear of the crane's west footing (y FY0..FY1)
            x_hull, x_foot = HX + sx * (HB - 0.10), HX + sx * (HB + 0.70)
            b.beam((x_foot, y, DFLOOR + 0.25), (x_hull, y, HZ + 2.30), 0.55, 0.55, P.BROWN)
            b.box((x_foot - 0.40, y - 0.45, DFLOOR), (x_foot + 0.40, y + 0.45, DFLOOR + 0.30), P.DBG, bevel=0.04)


def ladder(b):
    """A yellow dock ladder on the east wall, aft of the hull, down into the basin."""
    for y in (10.85, 11.23):
        b.box((-11.20, y, DFLOOR), (-11.08, y + 0.12, CAP_Z1), P.YELLOW, bevel=0.02)
    for z in (1.55, 1.95, 2.35, 2.75):
        b.box((-11.18, 10.97, z), (-11.10, 11.23, z + 0.12), P.DBG)


def hw(x):
    """Hull half beam at local x (full amidships, tapering over the bow)."""
    for (xa, wa), (xb, wb) in zip(HTAPER, HTAPER[1:]):
        if x <= xb:
            return wa + (wb - wa) * (x - xa) / (xb - xa)
    return HTAPER[-1][1]


def hull(b):
    """Local hull: bow +X, keel bottom z 0. Solid: red hull bands (white stripe), a tan studded deck, a white cabin
    aft, a red stem post. Placed by place_rot afterwards."""
    xs = [t[0] for t in HTAPER]
    sections = []                               # red hull: flat bottom, a bilge chine, vertical sides to the stripe
    for x, zb in zip(xs, HKEEL):
        w, zk = hw(x), zb + (2.10 - zb) * 0.52
        sections.append([(x, -0.72 * w, zb), (x, 0.72 * w, zb), (x, w, zk), (x, w, 2.10), (x, -w, 2.10), (x, -w, zk)])
    b.loft(sections, P.RED)
    for z0, z1, sc, colour in HBANDS:
        b.loft([[(x, -hw(x) * sc, z0), (x, hw(x) * sc, z0), (x, hw(x) * sc, z1), (x, -hw(x) * sc, z1)] for x in xs], colour)
    b.loft([[(x, -hw(x) * 0.88, 3.35), (x, hw(x) * 0.88, 3.35), (x, hw(x) * 0.88, DECK), (x, -hw(x) * 0.88, DECK)]
            for x in xs[:-2]], P.TAN)                                                    # solid deck
    hx = HY - GYC                               # open engine hatch under the crane hook: yellow coaming, dark hole
    b.box((hx - 1.70, -1.10, DECK), (hx + 1.70, 1.10, DECK + 0.03), P.INK, bevel=0.0)
    for y0, y1 in ((-1.30, -1.10), (1.10, 1.30)):
        b.box((hx - 1.90, y0, DECK), (hx + 1.90, y1, DECK + 0.40), P.YELLOW, bevel=0.04)
    for x0, x1 in ((hx - 1.90, hx - 1.70), (hx + 1.70, hx + 1.90)):
        b.box((x0, -1.10, DECK), (x1, 1.10, DECK + 0.40), P.YELLOW, bevel=0.04)
    b.studs(hx + 2.15, hx + 4.05, -0.95, 0.95, DECK, P.TAN, step=0.95, r=0.30, h=0.20, n=12)
    b.box((-5.60, -1.35, DECK), (-1.80, 1.35, 5.50), P.WHITE, bevel=0.07)                # cabin
    for sy in (-1, 1):
        b.box((-4.90, sy * 1.35 - (0.05 if sy < 0 else 0), 3.90), (-2.50, sy * 1.35 + (0.05 if sy > 0 else 0), 4.90), P.INK)
    b.box((-1.85, -1.00, 3.90), (-1.80, 1.00, 4.90), P.INK)
    b.box((-5.80, -1.55, 5.50), (-1.60, 1.55, 5.80), P.RED, bevel=0.06)                  # cabin roof
    b.studs(-5.40, -2.00, -1.20, 1.20, 5.80, P.RED, step=1.1, r=0.30, h=0.20, n=10)
    b.beam((6.50, 0, 1.75), (6.82, 0, 3.95), 0.45, 0.45, P.RED)                          # stem post on the bow


def place_rot(b):
    """Local hull (bow +X) -> the world basin: bow to -Y, keel at HZ, centre (HX, HY)."""
    for i, (x, y, z) in enumerate(b.v):
        b.v[i] = (HX + y, HY - x, HZ + z)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_BoatYard_Brick", ALB)
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
        print("[boatyard] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills the basin
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    # ================================================================ Lv2: portal crane over the boat + bench
    b = lego.B()
    gantry(b)
    out("Lv2_L01_Gantry", b, "Lv2")

    b = lego.B()
    hoist(b)
    out("Lv2_L02_Hoist", b, "Lv2")

    b = lego.B()
    bench(b)
    out("Lv2_L03_Bench", b, "Lv2")

    b = lego.B()
    bench_tools(b)
    out("Lv2_L04_Tools", b, "Lv2")

    c = lego.B()
    for xc, (fx0, fx1), ph in ((GXW, FOOTW, PHW), (GXE, FOOTE, PHE)):
        c.box((fx0, FY0, FLOOR), (fx1, FY1, PLATE_Z), P.DBG)                      # footing + base plate
        for sy in (-1, 1):
            c.box((xc - ph, GYC + sy * GY - 0.55, PLATE_Z), (xc + ph, GYC + sy * GY + 0.55, BEAM_Z1), P.YELLOW)
    c.box((GXW - PHW - 0.45, GYC - 1.30, BEAM_Z0 - 0.10), (GXE + 1.00, GYC + 1.30, BEAM_Z1 + 0.18), P.DBG)   # girder
    c.box((GXE + 0.55, GYC - GY - 1.45, PLAT_Z - 0.30), (GXE + 4.30, GYC - GY + 1.45, PLAT_Z), P.DBG)  # cab platform
    c.box((GXE + 0.65, GYC - GY - 1.30, PLAT_Z), (GXE + 2.85, GYC - GY + 1.30, PLAT_Z + 2.88), P.YELLOW)   # cab
    c.box((HX - 1.50, CY0, FLOOR), (HX + 1.50, CY1, 2.58), P.DBG)               # engine stand base
    c.box((HX - 1.22, CY0 + 0.20, 2.58), (HX + 1.22, CY1 - 0.20, 6.60), P.DBG)  # engine stand column + top
    c.box((BX0, BY0, FLOOR), (BX1, BY1, BTOP), P.TAN)                             # bench
    c.box((18.26, -3.90, BTOP), (18.75, 3.90, 7.12), P.DBG)                       # tool board
    out_cols("Lv2", c)

    # ================================================================ Lv3: walled dry dock + hull on blocks
    b = lego.B()
    walls(b)
    ladder(b)
    out("Lv3_L01_Walls", b, "Lv3")

    b = lego.B()
    water(b)
    out("Lv3_L02_Water", b, "Lv3")

    b = lego.B()
    steps(b)
    out("Lv3_L03_Steps", b, "Lv3")

    b = lego.B()
    gate(b)
    out("Lv3_L04_Gate", b, "Lv3")

    b = lego.B()
    blocks(b)
    out("Lv3_L05_Blocks", b, "Lv3")

    b = lego.B()
    hull(b)
    place_rot(b)
    out("Lv3_L06_Hull", b, "Lv3")

    c = lego.B()
    c.box((WX0, SY0, FLOOR), (WX1, NY, CAP_Z1), P.DBG)                            # west wall
    c.box((EX0, SY0, FLOOR), (EX1, NY, CAP_Z1), P.DBG)                            # east wall
    c.box((WX1, SY0, FLOOR), (EX0, SY1, CAP_Z1), P.DBG)                           # south wall
    c.box((WX1, 19.50, FLOOR), (EX0, 20.60, 3.30), P.DBG)                         # caisson
    c.box((WX0 + 0.75, 20.30, CAP_Z1), (WX1, 21.00, 4.00), P.ORANGE)              # gate posts
    c.box((EX0, 20.30, CAP_Z1), (EX0 + 0.85, 21.00, 4.00), P.ORANGE)
    c.box((-18.10, 20.35, 3.95), (-10.15, 21.00, 4.55), P.YELLOW)                 # beam, overhead
    for y0, y1, z1 in ((-11.65, -10.90, 1.50), (-10.90, -10.15, 2.08), (-10.15, -9.40, 2.66)):
        c.box((-10.95, y0, FLOOR), (-9.45, y1, z1), P.LBG)                        # steps up
    for y0, y1, z1 in ((SY1, SY1 + 0.80, 2.73), (SY1 + 0.80, SY1 + 1.60, 2.20), (SY1 + 1.60, SY1 + 2.40, 1.67)):
        c.box((WX1, y0, FLOOR), (EX0, y1, z1), P.LBG)                             # steps down
    c.box((HX - 1.80, 3.70, 3.50), (HX + 1.80, 13.10, 6.15), P.LBG)               # hull, four bites
    c.box((HX - 1.65, 2.30, 3.50), (HX + 1.65, 3.70, 6.25), P.LBG)
    c.box((HX - 1.10, 1.10, 3.50), (HX + 1.10, 2.30, 6.40), P.LBG)
    c.box((HX - 0.45, -0.30, 3.50), (HX + 0.45, 1.10, 6.70), P.LBG)
    c.box((HX - 1.05, 2.80, DFLOOR), (HX + 1.05, 12.70, HZ), P.DBG)               # keel blocks + the Lv2 cradle
    c.box((-11.24, 10.80, 1.15), (-11.06, 11.40, CAP_Z1), P.YELLOW)               # ladder
    c.box((WX1 - 0.34, SY1 + 2.6, CAP_Z1), (WX1, FY0 - 0.2, CAP_Z1 + 1.40), P.WHITE)   # fence panels (rails stop falls)
    c.box((WX1 - 0.34, FY1 + 0.2, CAP_Z1), (WX1, 20.0, CAP_Z1 + 1.40), P.WHITE)   # gap by the crane legs: 2-stud lane
    c.box((EX0, SY1 + 2.6, CAP_Z1), (EX0 + 0.34, 10.5, CAP_Z1 + 1.40), P.WHITE)
    c.box((EX0, 11.55, CAP_Z1), (EX0 + 0.34, 20.0, CAP_Z1 + 1.40), P.WHITE)
    c.box((HUT_X0, HUT_Y0, FLOOR), (HUT_X0 + HUT_T, HUT_Y1, HUT_Z), P.ORANGE)     # pump house walls (door side open)
    c.box((HUT_X1 - HUT_T, HUT_Y0, FLOOR), (HUT_X1, HUT_Y1, HUT_Z), P.ORANGE)
    c.box((HUT_X0, HUT_Y1 - HUT_T, FLOOR), (HUT_X1, HUT_Y1, HUT_Z), P.ORANGE)
    c.box((HUT_X0, HUT_Y0, FLOOR), (DOOR_X0, HUT_Y0 + HUT_T, HUT_Z), P.ORANGE)
    c.box((DOOR_X1, HUT_Y0, FLOOR), (HUT_X1, HUT_Y0 + HUT_T, HUT_Z), P.ORANGE)
    c.box((HUT_X0 + HUT_T + 0.20, 15.90, FLOOR), (HUT_X0 + HUT_T + 1.80, 17.90, 2.50), P.DBG)   # pump
    out_cols("Lv3", c)

    atts = []
    for name, loc in (("ATT_Work_Hull", (-10.50, 6.00, CAP_Z1)),
                      ("ATT_Work_Bench", (15.45, 0.00, FLOOR)),
                      ("ATT_Work_Dock", (-10.50, 13.40, CAP_Z1))):
        atts.append(lego.attach(name, loc))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[boatyard] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[boatyard] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, sitting on the code yard's plinth (z 0.92) inside its 39.5 x 43.5 stud lot; the "
                     "bbox spans the crane, the east bench and the west dock walls, not the whole lot; front -Y, "
                     "origin the yard ground centre, built at the yard's final 1.15 scale (place with no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 B/J): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., "
                      "Lv3_Col01_COL..; the FBX importer flattens empty parents, so the node name is the mesh prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "gantry", "target": [-12.0, GYC, 10.0], "dist": 36, "az": -30, "el": 10},
            {"name": "cab", "target": [GXE + 2.0, GYC - GY, 9.0], "dist": 16, "az": -30, "el": 12},
            {"name": "bench", "target": [17.0, 0.0, 4.6], "dist": 13, "az": -62, "el": 10},
            {"name": "dry_dock", "target": [HX, 6.0, 3.6], "dist": 34, "az": -40, "el": 26},
            {"name": "hull", "target": [HX, 6.0, 4.6], "dist": 24, "az": 90, "el": 16},
            {"name": "pump_house", "target": [-5.2, 15.4, 3.5], "dist": 20, "az": -35, "el": 14},
        ],
    }
