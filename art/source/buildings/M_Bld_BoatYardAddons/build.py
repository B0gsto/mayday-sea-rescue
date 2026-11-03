"""M_Bld_BoatYardAddons: the Boat Yard as a mesh, Lego style (PERF-BL9; docs/25 B and J; docs/05 2.2, 3, 4, 5).

Built in the code yard's final frame (`boatYard()` in src/shared/DockPieces.luau): 39.5 x 43.5 stud lot, ground at z
0, plinth top z 0.92, front -Y (Roblox -Z), origin the yard's ground centre, Blender +X = in-game -X. The code keeps
the plinth, the name sign on the gantry beam, the rock and a hidden Console.

Lv1: tiled floor with a tan work strip, white brick walls with grey cap plates and orange piers, the workboat on two grey
brick cradles under the yellow gantry, a walk-in brick office (double door on the path face), props, the slipway, a storage
pad in the right half. Lv2: a tall red jib crane right of the gantry and a red tool bench left of the gate mouth. Lv3: a
wet dock with a dark rim, a low red/white water gate in the front wall's place and a half-open boat shed in the right front,
a bigger hull afloat in it. Lv1_L07_Paint (with the right front wall) gives way to the dock at Lv3 (DockPieces).

Each level is a top-level node (Lv1, Lv2, Lv3) holding construction layers (L01_* bottom up), one palette mesh per
layer (flat colours via UVs). Collision is `<Node>_ColNN_COL`, one convex box per object.

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
BUDGET = "hero_building"   # Lv1 joined (PERF-BL9): 40k class, one flat palette set (waived)
TIER = "standard"
SET_NAME, SET = "BoatYard", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_BoatYard_Brick_ALB.png")
FLOOR = 0.92                    # code yard plinth top (0.8 at 1x, scaled 1.15)
# PERF-BL9 r5 layout (each level grows its own shape where the path sees it): Lv2 = a tall red jib crane right of the gantry
# + a red tool bench left of the gate mouth; Lv3 = a wet dock in the right front: dark rim, clear water, a low red/white
# water gate at the path end, a red hull afloat and a half-open boat shed (blue studded roof, white gable) over its stern
FACE = 18.30                    # tool() board plane in its build frame (bench_lv2 rotates it to face -Y)
BENCH_X, BENCH_Y = -5.60, -14.40    # Lv2 bench centre x, pegboard plane y: in the gate mouth, plinth front y -17.8 leaves the corridor to the office door
BENCH_S, BENCH_PL = 1.25, 0.70  # bench scale, plinth height (one brick: the board stands clear above the gate post)
TOOL_S = 1.50                   # the three hung tools
BTOP = 3.50
BBOARD = 7.50                   # pegboard top (before the scale)
AWN_D = 1.90                    # awning depth (before the scale): 2 studs in the world
TWX, TWY = 12.50, 18.00         # Lv2 jib crane tower centre: in the path view it stands between the gantry leg and the Lv3 shed
TW = 1.30                       # tower half width
TBASE = 3.00                    # two-course red/white base half width (6x6)
TOWER_Z = 28.30                 # slewing ring (r3 20.7): the crane is its own skyline step beside the gantry
JIB_X1 = 19.35                  # jib tip, outward over the right half: nothing crosses the gantry leg
HOOK_X = 17.30                  # trolley / load x (the load hangs clear right of the tower)
CRATE_S, CRATE_H = 4.68, 4.20   # the load, 1.3x
DX0, DX1, DY0, DY1 = 9.60, 18.60, -20.55, -2.00     # Lv3 dock outer rim
RIM, RIM_Z, COPE_Z = 0.90, 2.40, 2.60
WATER_Z = 2.30
WATER_C = P.BLUE
SHED_Y0, EAVE = -10.10, 15.00   # boat shed over the dock's back third (roof y SHED_Y0..DY1): the bow lies in open water
SHED_PX = (12.60, 19.10)        # shed post x: left on a quay strip (a crane-width of sky between its eave and the crane tower in the path view), right on the side wall
QUAY_X1 = 13.20                 # quay strip right edge
SHED_XA, SHED_XB = 12.00, 19.70 # shed roof x
CAISSON_Z = 2.22                # the low path-side water gate replaces the front wall at Lv3: hull and water show over it
HX, HY = 15.40, -10.60          # Lv3 hull centre in the dock, bow to -Y (the path)
HS = 1.10                       # Lv3 hull scale
HZ = 1.00                       # hull keel bottom (afloat: the water hides the bilge)
HB = 1.75                       # hull half beam
HTAPER = ((-6.80, HB), (2.60, HB), (4.00, 1.65), (5.20, 1.15), (6.10, 0.62), (6.60, 0.28))   # (x, half beam)
# hull bands (z0, z1, half-beam scale, colour): red hull, white stripe, red sheer
HBANDS = ((2.10, 2.75, 1.02, P.WHITE), (2.75, 3.35, 1.00, P.RED))      # over the red bilge hull (hull())
HKEEL = (0.00, 0.00, 0.25, 0.85, 1.55, 1.95)    # keel bottom per HTAPER station: flat, then a raked bow
DECK = 3.55


def patch_lod_targets():
    """LODs keep the large_prop shares (50% / 25%) the add-ons shipped with: the hero_building LOD2 ceiling collapses
    the small Lego detail meshes (session-only patch, like M_Bld_FishMarketAddons)."""
    import budgets
    orig = getattr(budgets, "_by_orig_lod_target", budgets.lod_target)
    budgets._by_orig_lod_target = orig
    budgets.lod_target = lambda budget_class, lod, lod0_tris, asset_tris=None: orig("large_prop", lod, lod0_tris)


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
        part(-0.48, 0.48, 1.20, 1.80, P.RED, True)
        part(-0.48, -0.25, 1.80, 2.00, P.RED)
    elif kind == "wrench":
        part(-0.18, 0.18, 0.0, 1.50, P.BLUE, True)
        part(-0.45, 0.45, 1.50, 1.80, P.BLUE)
        part(-0.45, -0.17, 1.80, 2.15, P.BLUE)
        part(0.17, 0.45, 1.80, 2.15, P.BLUE)
    elif kind == "drill":
        part(-0.30, 0.30, 0.65, 1.50, P.DBG, True)
        part(-0.14, 0.14, 0.10, 0.65, P.ORANGE)
        part(-0.06, 0.06, 1.50, 2.10, P.LBG)
        part(-0.50, 0.50, 1.50, 1.80, P.ORANGE)
    else:  # saw
        part(-0.55, 0.55, 0.75, 1.95, P.DBG)
        part(-0.20, 0.20, 0.0, 0.75, P.YELLOW, True)
        for i in range(4):
            part(-0.48 + i * 0.32, -0.27 + i * 0.32, 0.55, 0.75, P.DBG)

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
    hx = 0.30                                   # open engine hatch amidships: yellow coaming, dark hole
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
        b.v[i] = (HX + HS * y, HY - HS * x, HZ + HS * z)


# ------------------------------------------------------------------ Lv1 yard (PERF-BL9: refines the code `boatYard()`)
# The code yard at 1.15 (Blender +X = in-game -X, +Y = in-game +Z). The code keeps the plinth, the name sign on the
# gantry beam (Lv1) / crane girder (Lv2+), the rock and the Console part (the craft-board act) hidden inside the mesh
# console. Lv1_L07_Paint (the paint pallet in the right front) gives way to the Lv3 dock (DockPieces drops it at Lv3).
K = 1.15
YW = 18.70                      # side wall inner face (code 19.15 - 0.40, inset 0.05 into the Lv3 dock wall)
YWO = 19.55                     # side wall outer face
FZ0, FZ1 = -21.55, -20.75       # front wall (y)
GATE = 6.90                     # gate post centres (+-x), 13.8 opening
WALL_TOP = 3.68
TILE_TOP = 0.99
HULL_Z0, HULL_Z1 = 6.21, 9.89
HULL_HW, HULL_Y = 4.255, 8.625
BOW_TIP = -13.69
BOW_Z = 6.60                    # the stem's foot: the bow's underside stays out of the path camera's sight (it shaded muddy)
BOW_ST = ((HULL_HW, -8.50), (3.05, -12.00), (0.90, BOW_TIP))    # plan stations: a blunt front facet catches the light
YEL_Z0, YEL_Z1 = 8.25, 9.00     # yellow band
PATH_X = 6.233                  # tan path half width (a tile edge)
TSX, TSY = 2 * YW / 12, (21.65 - FZ1) / 14     # floor tile size
# colour tile patches on the grey floor (x0, x1, y0, y1, colour): a tile takes the colour its centre falls in
PATCHES = ((13.0, 18.7, -16.0, -12.0, P.BLUE), (15.4, 18.7, -8.0, -3.0, P.RED), (8.5, 12.5, 8.0, 14.0, P.YELLOW),
           (14.0, 18.7, 11.0, 14.0, P.BLUE), (-14.5, -9.0, 2.0, 8.0, P.BLUE))
DECK_Z1 = 10.465
GLEG_X, GLEG_HX, GLEG_HY = 7.60, 0.65, 0.45
GBEAM_Z0, GBEAM_Z1 = 27.40, 28.70
OX0, OX1, OY0, OY1 = -18.40, -9.60, -17.80, -9.40       # yard office (front -X corner, set back: its door faces the path)
OWT, OWALL = 0.50, 9.60
ODX0, ODX1, ODZ1 = -12.45, -10.15, FLOOR + 5.60         # doorway in the -Y face
WZ0, WZ1 = 4.40, 6.90                                   # window band


def tile_edges(j):
    """Tile edges of floor row j: a running bond, split at the tan path's edges."""
    if j % 2 == 0:
        return [-YW + k * TSX for k in range(13)]
    return sorted([-YW, YW, -PATH_X, PATH_X] + [-YW + (k + 0.5) * TSX for k in range(12)])


def tile_colour(cx, cy):
    if abs(cx) < PATH_X:
        return P.TAN
    return next((c for x0, x1, y0, y1, c in PATCHES if x0 <= cx < x1 and y0 <= cy < y1), P.LBG)


def floor_studs(b, x0, x1, y0, y1, step=1.25):
    """A stud grid on the floor, each stud in its tile's colour."""
    nx, ny = max(1, round((x1 - x0) / step)), max(1, round((y1 - y0) / step))
    for ix in range(nx):
        for iy in range(ny):
            x, y = x0 + (ix + 0.5) * (x1 - x0) / nx, y0 + (iy + 0.5) * (y1 - y0) / ny
            j = int((y - FZ1) / TSY)
            ed = tile_edges(j)
            cx = next(((a + d) / 2 for a, d in zip(ed, ed[1:]) if a <= x < d), x)
            b.cyl(x, y, TILE_TOP, TILE_TOP + 0.20, 0.34, tile_colour(cx, FZ1 + (j + 0.5) * TSY), n=8, bottom=False)


def lv1_floor(b):
    """Warm grey 3-stud tiles in a running bond on a dark bed (crisp seams), colour tile patches, a tan path from the gate
    to the bow, an orange trim round the slab edge."""
    gap = 0.12
    Zb = FLOOR + 0.03
    b._emit([(-YW, FZ1, Zb), (YW, FZ1, Zb), (YW, 21.65, Zb), (-YW, 21.65, Zb)], ((0, 1, 2, 3),), P.DBG)
    b._emit([(-GATE + 0.6, FZ0, Zb), (GATE - 0.6, FZ0, Zb), (GATE - 0.6, FZ1, Zb), (-GATE + 0.6, FZ1, Zb)], ((0, 1, 2, 3),), P.DBG)
    for j in range(14):
        y0, ed = FZ1 + j * TSY, tile_edges(j)
        cy = y0 + TSY / 2
        for i, (x0, x1) in enumerate(zip(ed, ed[1:])):
            cx = (x0 + x1) / 2
            b.box((x0 + gap / 2, y0 + gap / 2, FLOOR - 0.02), (x1 - gap / 2, y0 + TSY - gap / 2, TILE_TOP), tile_colour(cx, cy),
                  bevel=0.05)
            keep_faces(b, (1, 2, 3, 4, 5))
            covered = (cx < -9.0 and (cy < -9.0 or cy > 11.5)) or (cx > 9.0 and cy < -1.5) or abs(cx) < 6.3
            if not covered and cx < 0 and x1 - x0 > 2.5 and (i * 5 + j * 3) % 7 == 0:    # stud patches break the grey field (left half)
                b.studs(cx - 0.9, cx + 0.9, cy - 0.9, cy + 0.9, TILE_TOP, tile_colour(cx, cy), step=0.9, r=0.30, h=0.20, n=10)
    # the gate mouth (between the front wall pieces) and the trim: orange band proud of the plinth edge
    for i in range(4):
        x0 = -GATE + 0.6 + i * (2 * GATE - 1.2) / 4
        b.box((x0 + 0.06, FZ0 + 0.06, FLOOR - 0.02), (x0 + (2 * GATE - 1.2) / 4 - 0.06, FZ1 - 0.06, TILE_TOP), P.TAN,
              bevel=0.05)
        keep_faces(b, (1, 2, 3, 4, 5))
    E, T = 0.06, 0.30
    for s in (-1, 1):
        b.box((s * (19.725 - T), -21.725 - E, 0.50), (s * (19.725 + E), 21.725 + E, 0.97), P.ORANGE, bevel=0.03)
    b.box((-19.725 + T, -21.725 - E, 0.50), (19.725 - T, -21.725 + T, 0.97), P.ORANGE, bevel=0.03)
    b.box((-19.725 + T, 21.725 - T, 0.50), (19.725 - T, 21.725 + E, 0.97), P.ORANGE, bevel=0.03)
    b.studs(-GATE + 0.8, GATE - 0.8, -21.70, -21.45, 0.97, P.ORANGE, step=1.25, r=0.28, h=0.18, n=10)


def courses(b, along, plane, s, u0, u1, z0, z1, n=6, brick=2.80, holes=(), c=P.DBG):
    """Staggered brick seams 0.05 proud of a wall face: along "x" (face at y = plane) or "y" (face at x = plane), s the
    outward normal's sign; holes = (u0, u1, z0, z1) rectangles the seams stop at (windows, doors, plaques)."""
    t, p = 0.08, 0.05
    a, d = sorted((plane, plane + s * p))
    back = {("x", 1): 2, ("x", -1): 4, ("y", 1): 5, ("y", -1): 3}[(along, s)]

    def seg(ua, ub, za, zb, drop):
        lo, hi = ((ua, a, za), (ub, d, zb)) if along == "x" else ((a, ua, za), (d, ub, zb))
        b.box(lo, hi, c, bevel=0.0)
        keep_faces(b, [k for k in range(6) if k not in drop])

    h = (z1 - z0) / n
    for i in range(1, n):
        z = z0 + i * h
        cuts = sorted((max(u0, r[0]), min(u1, r[1])) for r in holes if r[2] < z + t / 2 and r[3] > z - t / 2)
        ua = u0
        for ca, cb in cuts + [(u1, u1)]:
            if ca - ua > 0.15:
                seg(ua, ca, z - t / 2, z + t / 2, (back,))
            ua = max(ua, cb)
    for i in range(n):
        za, zb = z0 + i * h, z0 + (i + 1) * h
        u = u0 + (brick / 2 if i % 2 else brick)
        while u < u1 - 0.3:
            if not any(r[0] - 0.05 < u < r[1] + 0.05 and r[2] < zb and r[3] > za for r in holes):
                seg(u - t / 2, u + t / 2, za + t / 2, zb - t / 2, (back, 0, 1))
            u += brick


def wall_run(b, x0, x1, y0, y1, skip=()):
    """A white two-course brick wall (staggered 4-stud bricks, bevelled so the seams read) with a stud row on top."""
    along_y = (y1 - y0) > (x1 - x0)
    L = (y1 - y0) if along_y else (x1 - x0)
    a0 = y0 if along_y else x0
    zs = (FLOOR, 2.30, WALL_TOP)
    for k in range(2):
        cuts = [a0] + [a0 + t for t in [((i + 0.5 * k) * 4.0) for i in range(1, 12)] if t < L - 1.0] + [a0 + L]
        for u0, u1 in zip(cuts, cuts[1:]):
            lo = (x0, u0, zs[k]) if along_y else (u0, y0, zs[k])
            hi = (x1, u1, zs[k + 1]) if along_y else (u1, y1, zs[k + 1])
            b.box(lo, hi, P.WHITE, bevel=0.07)
    n = max(1, int(L / 2.0))                     # clean 1x2 cap plates (light grey), two studs each
    for i in range(n):
        u0, u1 = a0 + i * L / n + 0.04, a0 + (i + 1) * L / n - 0.04
        lo = (x0 - 0.08, u0, WALL_TOP) if along_y else (u0, y0 - 0.08, WALL_TOP)
        hi = (x1 + 0.08, u1, WALL_TOP + 0.20) if along_y else (u1, y1 + 0.08, WALL_TOP + 0.20)
        b.box(lo, hi, P.LBG, bevel=0.04)
        for t in (0.27, 0.73):
            u = u0 + (u1 - u0) * t
            cx, cy = ((x0 + x1) / 2, u) if along_y else (u, (y0 + y1) / 2)
            b.cyl(cx, cy, WALL_TOP + 0.20, WALL_TOP + 0.40, 0.30, P.LBG, n=10, bottom=False)


def pier(b, cx, cy, hx, hy, z1, c=P.ORANGE):
    b.box((cx - hx, cy - hy, FLOOR), (cx + hx, cy + hy, z1), c, bevel=0.08)
    b.box((cx - hx - 0.08, cy - hy - 0.08, z1), (cx + hx + 0.08, cy + hy + 0.08, z1 + 0.30), P.WHITE, bevel=0.06)
    b.studs(cx - hx, cx + hx, cy - hy, cy + hy, z1 + 0.30, P.WHITE, step=0.9, r=0.30, h=0.22, n=10)


def front_wall(b, s):
    """A front wall piece either side of the gate: white brick courses with a blue accent course on the path face."""
    xa, xb = sorted((s * (GATE + 0.80), s * YWO))
    wall_run(b, xa, xb, FZ0, FZ1)
    for u0 in range(0, 3):
        x0, x1 = xa + u0 * (xb - xa) / 3 + 0.04, xa + (u0 + 1) * (xb - xa) / 3 - 0.04
        b.box((x0, FZ0 - 0.07, 2.05), (x1, FZ0 + 0.04, 2.65), P.BLUE, bevel=0.03)


def lv1_walls(b):
    """The code yard's white edge walls as brick courses with stud caps, orange pilasters every ~8.6 studs, chunky
    orange gate piers (studded white caps). The right front wall is in Lv1_L07 (the Lv3 water gate replaces it)."""
    for s in (-1, 1):
        x0, x1 = sorted((s * YW, s * YWO))
        wall_run(b, x0, x1, -21.55, 21.55)
        for y in (-17.2, -8.6, 0.0, 8.6, 17.2):
            pier(b, s * 19.125, y, 0.58, 0.55, 4.05)
        if s < 0:
            front_wall(b, s)
        pier(b, s * GATE, (FZ0 + FZ1) / 2, 0.85, 0.85, 4.20)
        pier(b, s * 19.125, -21.15, 0.58, 0.58, 4.05)


def porthole(b, x, y, z, s):
    b.cyl_x(x + s * 0.06, y, z, 0.62, 0.14, P.WHITE, n=12)
    b.cyl_x(x + s * 0.16, y, z, 0.42, 0.10, P.INK, n=12)


def lv1_boat(b):
    """The workboat on its cradle (the code hull, refined): bevelled red hull with a tapered raked bow, white stripe,
    portholes, white deck rails, the console (helm, windscreen), the cabin with framed windows, a studded red roof
    and a little mast; two grey brick cradles with yellow caps and wedges, the hull's underside open between them."""
    for y in (-5.75, 5.75):
        for sx in (-1, 1):                       # 2 clean grey brick cradles on the rails, the hull's underside open between them
            x = sx * 4.14
            b.box((x - 1.5, y - 1.5, FLOOR), (x + 1.5, y + 1.5, 1.61), P.LBG, bevel=0.08)
            b.studs(x - 1.2, x + 1.2, y - 1.2, y + 1.2, 1.61, P.LBG, step=1.2, r=0.38, h=0.22, n=10)
            brick_stack(b, x - 1.05, x + 1.05, y - 1.05, y + 1.05, 1.61, 5.35, 3, P.LBG)
            b.box((x - 1.28, y - 1.28, 5.35), (x + 1.28, y + 1.28, 5.72), P.YELLOW, bevel=0.06)        # yellow cap
            xa, xb = sorted((sx * 3.10, sx * 4.25))
            b.box((xa, y - 1.05, 5.72), (xb, y + 1.05, HULL_Z0 - 0.04), P.YELLOW, bevel=0.04)          # saddle under the hull
            prism_y(b, y - 0.80, y + 0.80, [(sx * 4.36, 5.72), (sx * 5.42, 5.72), (sx * 4.36, 7.00)], P.YELLOW)   # wedge on the hull side
    b.box((-HULL_HW, -HULL_Y, HULL_Z0), (HULL_HW, HULL_Y, HULL_Z1), P.RED, bevel=0.10)
    b.box((-0.25, -HULL_Y + 0.4, HULL_Z0 - 0.24), (0.25, HULL_Y - 0.2, HULL_Z0 + 0.02), P.LBG, bevel=0.05)   # slim keel
    b.beam((0, -8.10, HULL_Z0 - 0.11), (0, BOW_TIP - 0.08, BOW_Z - 0.04), 0.46, 0.26, P.LBG)
    # bow: lofted over the plan stations from the hull's front to a short stem (band z0, z1 at the root and at the tip)
    def bow(pad, a0, a1, t0, t1, c, tip=0.0):
        secs = []
        for w, y in BOW_ST:
            k = (y + 8.50) / (BOW_TIP + 8.50)
            y = y if w != BOW_ST[-1][0] else y - tip
            z0, z1 = a0 + (t0 - a0) * k, a1 + (t1 - a1) * k
            secs.append([(-w - pad, y, z0), (w + pad, y, z0), (w + pad, y, z1), (-w - pad, y, z1)])
        b.loft(secs, c)
    bow(0.0, HULL_Z0, HULL_Z1, BOW_Z, HULL_Z1, P.RED)
    zs0, zs1 = 9.03, 9.83
    b.box((-HULL_HW - 0.06, -HULL_Y + 0.12, zs0), (HULL_HW + 0.06, HULL_Y + 0.06, zs1), P.WHITE, bevel=0.03)
    bow(0.06, zs0, zs1, zs0, zs1, P.WHITE, 0.06)
    # the bright yellow band high under the white one, round the bow; a white waterline low on the hull
    b.box((-HULL_HW - 0.06, -HULL_Y + 0.12, YEL_Z0), (HULL_HW + 0.06, HULL_Y + 0.06, YEL_Z1), P.YELLOW, bevel=0.03)
    bow(0.06, YEL_Z0, YEL_Z1, YEL_Z0, YEL_Z1, P.YELLOW, 0.06)
    b.box((-HULL_HW - 0.06, -HULL_Y + 0.12, 6.26), (HULL_HW + 0.06, HULL_Y + 0.06, 6.70), P.WHITE, bevel=0.03)
    bow(0.06, 6.26, 6.70, BOW_Z + 0.02, BOW_Z + 0.46, P.WHITE, 0.06)
    b.beam((0, BOW_TIP - 0.12, BOW_Z - 0.10), (0, BOW_TIP + 0.9, HULL_Z1 + 0.25), 0.55, 0.55, P.RED)    # stem post
    # a small black anchor on the bow's front facet (starboard), hung from a lug on a short chain, over the yellow and red bands
    i0 = len(b.v)
    A = (BOW_ST[1][0] + 0.06, BOW_ST[1][1])
    B_ = (BOW_ST[2][0] + 0.06, BOW_TIP - 0.06)
    L = math.hypot(B_[0] - A[0], B_[1] - A[1])
    nx, ny = (A[1] - B_[1]) / L, (B_[0] - A[0]) / L     # the facet's outward normal
    px, py = A[0] + 0.45 * (B_[0] - A[0]) - 0.03 * nx, A[1] + 0.45 * (B_[1] - A[1]) - 0.03 * ny
    b.box((-0.25, -0.18, 9.25), (0.25, 0.0, 9.52), P.DBG, bevel=0.03)                  # lug on the white band
    for k, z in enumerate((8.76, 8.92, 9.08)):                                          # three chain links
        wx = 0.07 if k % 2 else 0.13
        b.box((-wx, -0.15, z), (wx, 0.0, z + 0.19), P.BLACK, bevel=0.02)
    b.box((-0.16, -0.20, 8.60), (0.16, 0.0, 8.77), P.BLACK, bevel=0.03)                 # ring
    b.box((-0.10, -0.16, 7.35), (0.10, 0.0, 8.62), P.BLACK, bevel=0.03)                 # shank
    b.box((-0.52, -0.16, 8.20), (0.52, 0.0, 8.38), P.BLACK, bevel=0.03)                 # stock
    for k in (-1, 1):
        b.beam((0, -0.08, 7.37), (k * 0.62, -0.08, 7.82), 0.18, 0.16, P.BLACK)          # flukes
        b.box((k * 0.62 - 0.11, -0.16, 7.76), (k * 0.62 + 0.11, 0.0, 8.00), P.BLACK, bevel=0.03)
    remap(b, i0, lambda x, y, z: (px - x * ny - y * nx, py + x * nx - y * ny, z))     # local -Y onto the facet normal
    # butt joints on the red strakes
    for s in (-1, 1):
        xa, xb = sorted((s * HULL_HW, s * (HULL_HW + 0.05)))
        for y in (-4.8, -1.6, 1.6, 4.8):
            b.box((xa, y - 0.04, 6.70), (xb, y + 0.04, YEL_Z0), P.BLACK, bevel=0.0)
            keep_faces(b, (2, 4, 3 if s > 0 else 5))
    for s in (-1, 1):
        for y in (-7.4, -3.2, 0.0, 3.2, 7.4):     # clear of the cradle wedges
            porthole(b, s * HULL_HW, y, 7.35, s)
    b.box((-3.565, -7.245, HULL_Z1 - 0.04), (3.565, 7.245, DECK_Z1), P.DBG, bevel=0.04)          # deck
    # rails: white posts round the gunwale, a top rail, converging over the bow
    RZ = DECK_Z1 + 1.15
    for s in (-1, 1):
        x = s * 3.85
        for y in (-7.6, -5.1, -2.6, -0.1, 2.4, 4.9, 7.4):
            b.box((x - 0.13, y - 0.13, HULL_Z1 - 0.02), (x + 0.13, y + 0.13, RZ), P.WHITE, bevel=0.03)
        b.box((x - 0.18, -7.75, RZ - 0.05), (x + 0.18, 7.55, RZ + 0.25), P.WHITE, bevel=0.04)
        kn = (s * 2.75, -11.60)                  # the rail follows the bow's plan
        b.beam((x, -7.6, RZ + 0.10), (kn[0], kn[1], RZ + 0.10), 0.34, 0.30, P.WHITE)
        b.beam((kn[0], kn[1], RZ + 0.10), (s * 0.55, -13.05, RZ + 0.10), 0.34, 0.30, P.WHITE)
        for px, py in (kn, (s * 1.60, -12.35)):
            b.box((px - 0.13, py - 0.13, HULL_Z1 - 0.02), (px + 0.13, py + 0.13, RZ), P.WHITE, bevel=0.03)
    b.box((-3.85, 7.40, RZ - 0.05), (3.85, 7.76, RZ + 0.25), P.WHITE, bevel=0.04)                 # stern rail
    # console (the code Console part hides inside it)
    b.box((-1.84, -4.37, DECK_Z1 - 0.04), (1.84, -1.15, 13.225), P.WHITE, bevel=0.07)
    b.prof_x(-1.70, 1.70, [(-4.25, 13.20), (-3.20, 13.20), (-3.55, 14.35), (-3.75, 14.35)], P.INK)  # windscreen
    b.box((-1.30, -1.20, 11.30), (1.30, -1.10, 12.70), P.INK)                                     # helm panel
    b.cyl(0, -0.95, 11.9, 12.05, 0.55, P.BROWN, n=10)                                              # helm wheel
    # cabin: white, framed windows (glass behind a proud white frame), studded red roof, mast + beacon
    cx0, cx1, cy0, cy1, cz0, cz1 = -2.645, 2.645, 1.265, 6.095, DECK_Z1 - 0.04, 14.60
    b.box((cx0, cy0, cz0), (cx1, cy1, cz1), P.WHITE, bevel=0.07)
    def win_y(x0, x1, y, s):                     # window on a -Y / +Y face
        b.box((x0, y + s * 0.02, 11.80), (x1, y + s * 0.08, 13.70), P.GLASS, bevel=0.0)
        for (a0, a1, z0, z1) in ((x0 - 0.22, x1 + 0.22, 11.58, 11.80), (x0 - 0.22, x1 + 0.22, 13.70, 13.92),
                                 (x0 - 0.22, x0, 11.80, 13.70), (x1, x1 + 0.22, 11.80, 13.70)):
            b.box((a0, y, z0), (a1, y + s * 0.20, z1), P.WHITE, bevel=0.02)
        b.box((x0 - 0.30, y, 11.30), (x1 + 0.30, y + s * 0.34, 11.58), P.DBG, bevel=0.03)        # sill
    win_y(-1.95, 1.95, cy0, -1)
    def win_x(x, y0, y1, s):
        b.box((x + s * 0.02, y0, 11.80), (x + s * 0.08, y1, 13.70), P.GLASS, bevel=0.0)
        for (a0, a1, z0, z1) in ((y0 - 0.22, y1 + 0.22, 11.58, 11.80), (y0 - 0.22, y1 + 0.22, 13.70, 13.92),
                                 (y0 - 0.22, y0, 11.80, 13.70), (y1, y1 + 0.22, 11.80, 13.70)):
            b.box((x, a0, z0), (x + s * 0.20, a1, z1), P.WHITE, bevel=0.02)
        b.box((x, y0 - 0.30, 11.30), (x + s * 0.34, y1 + 0.30, 11.58), P.DBG, bevel=0.03)
    for s in (-1, 1):
        win_x(s * 2.645, 2.10, 5.25, s)
    b.box((-3.105, 0.805, cz1), (3.105, 6.555, 15.06), P.RED, bevel=0.06)
    b.studs(-2.8, 2.8, 1.1, 6.25, 15.06, P.RED, step=1.15, r=0.34, h=0.22, n=10)
    b.box((-0.22, 5.20, 15.06), (0.22, 5.64, 16.60), P.WHITE, bevel=0.04)                         # mast
    b.box((-1.10, 5.30, 15.85), (1.10, 5.54, 16.10), P.WHITE, bevel=0.03)
    b.cyl(0, 5.42, 16.60, 17.00, 0.32, P.RED, n=10)


def chain(b, x, y, z0, z1, link=0.60):
    """Chunky chain: links crossing at right angles (each overlaps the next by 0.04)."""
    z, k = z0, 0
    while z < z1 - 0.02:
        wx, wy = (0.26, 0.12) if k % 2 else (0.12, 0.26)
        b.box((x - wx, y - wy, z), (x + wx, y + wy, min(z + link + 0.04, z1)), P.BLACK, bevel=0.03)
        z, k = z + link, k + 1


def lv1_gantry(b):
    """The tall yellow gantry over the boat (code, refined): studded dark base plates, knee braces, studded girder
    with dark end caps, a red trolley, black cable and an orange hook block over the deck."""
    for s in (-1, 1):
        x = s * GLEG_X
        b.box((x - 1.25, -1.05, FLOOR - 0.02), (x + 1.25, 1.05, 1.42), P.DBG, bevel=0.06)
        b.studs(x - 1.15, x + 1.15, -0.95, 0.95, 1.42, P.DBG, step=1.15, r=0.32, h=0.20, n=10)
        brick_stack(b, x - GLEG_HX, x + GLEG_HX, -GLEG_HY, GLEG_HY, 1.42, GBEAM_Z0, 13, P.YELLOW)     # courses every 2 studs
        b.box((x - 0.95, -0.75, 1.42), (x + 0.95, 0.75, 1.82), P.YELLOW, bevel=0.05)               # foot flange
        b.beam((x - s * 0.3, 0, 23.6), (s * 4.6, 0, GBEAM_Z0 + 0.05), 0.5, 0.5, P.YELLOW)
        b.box((s * 8.40, -0.66, GBEAM_Z0 - 0.08), (s * 8.70, 0.66, GBEAM_Z1 + 0.10), P.DBG, bevel=0.04)
    b.box((-8.30, -0.50, GBEAM_Z0 + 0.02), (8.30, 0.50, GBEAM_Z1 - 0.02), P.DBG, bevel=0.0)      # girder: 6 bricks on a dark core
    keep_faces(b, (2, 3, 4, 5))
    for k in range(6):
        x0, x1 = -8.40 + k * 2.80, -8.40 + (k + 1) * 2.80
        b.box((x0 + (0.08 if k else 0), -0.60, GBEAM_Z0), (x1 - (0.08 if k < 5 else 0), 0.60, GBEAM_Z1), P.YELLOW, bevel=0.07)
    b.studs(-8.0, 8.0, -0.40, 0.40, GBEAM_Z1, P.YELLOW, step=1.0, r=0.30, h=0.22, n=10)
    b.box((-0.80, -0.75, 26.40), (0.80, 0.75, GBEAM_Z0 - 0.01), P.RED, bevel=0.06)               # trolley
    b.box((-0.12, -0.12, 19.50), (0.12, 0.12, 26.40), P.BLACK, bevel=0.0)                        # cable
    b.box((-0.60, -0.45, 18.50), (0.60, 0.45, 19.50), P.ORANGE, bevel=0.08)                      # hook block
    b.box((-0.18, -0.18, 17.86), (0.18, 0.18, 18.50), P.ORANGE, bevel=0.03)
    b.box((-4.95, -0.30, 17.30), (4.95, 0.30, 17.90), P.ORANGE, bevel=0.06)                      # spreader, 2 studs over the cabin
    for s in (-1, 1):                    # slings: hook to the bar; two thick chains from the bar ends to lugs on the hull
        b.beam((0, 0, 17.96), (s * 4.40, 0, 17.92), 0.18, 0.18, P.BLACK)
        chain(b, s * 4.62, 0, 9.28, 17.32)
        b.box((s * 4.255 - 0.02, -0.34, 8.90), (s * 4.88, 0.34, 9.30), P.DBG, bevel=0.03)


def brick_stack(b, x0, x1, y0, y1, z0, z1, n, c, seam=0.16, bev=0.08, core=P.DBG):
    """A post of n stacked brick courses: a dark core shows through the seams between them."""
    b.box((x0 + 0.10, y0 + 0.10, z0 + 0.02), (x1 - 0.10, y1 - 0.10, z1 - 0.02), core, bevel=0.0)
    keep_faces(b, (2, 3, 4, 5))
    h = (z1 - z0) / n
    for k in range(n):
        b.box((x0, y0, z0 + k * h + (seam / 2 if k else 0)), (x1, y1, z0 + (k + 1) * h - (seam / 2 if k < n - 1 else 0)), c, bevel=bev)


def remap(b, i0, fn):
    """Move the vertices emitted since index i0 through fn(x, y, z) (normals are recomputed per shell)."""
    for i in range(i0, len(b.v)):
        b.v[i] = fn(*b.v[i])


def lv1_office(b):
    """A walk-in yard office in the front -X corner: white brick courses with a red base course and a red band under the
    eaves; a big double door in a white frame on the path face: the left leaf shut (solid bright blue, a small window,
    a yellow knob; the wall stands behind it), the right one open (the walk-in doorway), a red step, a big framed plaque
    (a white boat icon on navy) over it (white boat icon on navy); a framed inset window with a white sill, a stepped studded blue roof with an
    orange studded ridge cap."""
    W0 = lambda lo, hi: b.box(lo, hi, P.WHITE, bevel=0.05)
    wins = ((-17.80, -15.95),)                       # front window
    y0f = OY0 + OWT
    W0((OX0, OY0, FLOOR), (ODX0, y0f, WZ0))
    W0((OX0, OY0, WZ0), (wins[0][0], y0f, WZ1))
    W0((wins[0][1], OY0, WZ0), (ODX0, y0f, WZ1))
    W0((OX0, OY0, WZ1), (ODX0, y0f, OWALL))
    W0((ODX0, OY0, ODZ1), (ODX1, y0f, OWALL))
    W0((ODX1, OY0, FLOOR), (OX1, y0f, OWALL))
    for wx0, wx1 in wins:
        b.box((wx0, OY0 + 0.27, WZ0), (wx1, OY0 + 0.33, WZ1), P.GLASS, bevel=0.0)      # glass 0.27 behind the face
        for a0, a1, z0, z1 in ((wx0 - 0.25, wx1 + 0.25, WZ0 - 0.25, WZ0), (wx0 - 0.25, wx1 + 0.25, WZ1, WZ1 + 0.25),
                               (wx0 - 0.25, wx0, WZ0, WZ1), (wx1, wx1 + 0.25, WZ0, WZ1)):
            b.box((a0, OY0 - 0.15, z0), (a1, OY0 + 0.05, z1), P.ORANGE, bevel=0.02)
        b.box((wx0 - 0.40, OY0 - 0.42, WZ0 - 0.55), (wx1 + 0.40, OY0 + 0.05, WZ0 - 0.25), P.WHITE, bevel=0.04)   # sill
    b.box((-16.93, OY0 + 0.20, WZ0), (-16.82, OY0 + 0.27, WZ1), P.WHITE, bevel=0.0)                        # mullion
    # the double door: white frame, the left leaf shut on the wall, the right bay open (the doorway), a red step
    DLX, FW = -15.05, 0.30                           # left leaf's outer edge, frame width
    MX0, MX1 = ODX0 - 0.30, ODX0                     # centre post
    for a0, a1 in ((DLX - FW, DLX), (MX0, MX1), (ODX1, ODX1 + FW)):
        b.box((a0, OY0 - 0.28, FLOOR), (a1, OY0 + 0.05, ODZ1), P.WHITE, bevel=0.05)
    b.box((DLX - FW - 0.10, OY0 - 0.34, ODZ1 - 0.02), (ODX1 + FW + 0.10, OY0 + 0.05, ODZ1 + FW), P.WHITE, bevel=0.06)
    b.box((DLX, OY0 - 0.12, FLOOR + 0.02), (MX0, OY0 + 0.05, ODZ1), P.BLUE, bevel=0.05)
    gx0, gx1, gz0, gz1 = DLX + 0.65, MX0 - 0.65, ODZ1 - 1.95, ODZ1 - 0.60   # the small window, framed proud on the leaf
    b.box((gx0, OY0 - 0.16, gz0), (gx1, OY0 - 0.08, gz1), P.GLASS, bevel=0.0)
    for a0, a1, z0, z1 in ((gx0 - 0.18, gx1 + 0.18, gz0 - 0.18, gz0), (gx0 - 0.18, gx1 + 0.18, gz1, gz1 + 0.18),
                           (gx0 - 0.18, gx0, gz0, gz1), (gx1, gx1 + 0.18, gz0, gz1)):
        b.box((a0, OY0 - 0.22, z0), (a1, OY0 - 0.08, z1), P.WHITE, bevel=0.02)
    b.box((MX0 - 0.55, OY0 - 0.30, FLOOR + 2.55), (MX0 - 0.22, OY0 - 0.10, FLOOR + 2.95), P.YELLOW, bevel=0.03)   # knob
    b.box((DLX - FW - 0.10, OY0 - 1.25, FLOOR), (ODX1 + FW + 0.10, OY0 - 0.02, FLOOR + 0.40), P.RED, bevel=0.06)   # step
    b.studs(DLX - FW, ODX1 + FW, OY0 - 1.05, OY0 - 0.75, FLOOR + 0.40, P.RED, step=1.25, r=0.26, h=0.14, n=8)
    # plaque over the door, 1.3x: orange frame, white board, red boat icon, two lettering bars
    pz0, pz1, px0, px1 = 7.28, 9.14, -15.25, -9.92
    fy, by, iy = OY0 - 0.62, OY0 - 0.68, OY0 - 0.78
    b.box((px0 - 0.18, fy, pz0 - 0.18), (px1 + 0.12, OY0 + 0.05, pz1 + 0.18), P.ORANGE, bevel=0.06)
    b.box((px0, by, pz0), (px1 - 0.06, fy, pz1), P.INK, bevel=0.0)
    zc, xc = (pz0 + pz1) / 2, (px0 + px1 - 0.06) / 2
    hx = [xc - 1.25, xc + 1.25, xc + 1.75, xc - 1.75]                                  # a clean white boat icon on the navy plate
    hz = [zc - 0.68, zc - 0.68, zc - 0.05, zc - 0.05]
    b._emit([(x, by, z) for x, z in zip(hx, hz)] + [(x, iy, z) for x, z in zip(hx, hz)],
            ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)), P.WHITE)
    b.box((xc - 0.80, iy, zc - 0.05), (xc + 0.40, by, zc + 0.62), P.YELLOW, bevel=0.0)
    # +X face (toward the bench and the path): one framed inset window with a white sill
    wy0, wy1 = -14.70, -12.40
    W0((OX1 - OWT, y0f, FLOOR), (OX1, OY1 - OWT, WZ0))
    W0((OX1 - OWT, y0f, WZ1), (OX1, OY1 - OWT, OWALL))
    W0((OX1 - OWT, y0f, WZ0), (OX1, wy0, WZ1))
    W0((OX1 - OWT, wy1, WZ0), (OX1, OY1 - OWT, WZ1))
    b.box((OX1 - 0.33, wy0, WZ0), (OX1 - 0.27, wy1, WZ1), P.GLASS, bevel=0.0)
    for a0, a1, z0, z1 in ((wy0 - 0.25, wy1 + 0.25, WZ0 - 0.25, WZ0), (wy0 - 0.25, wy1 + 0.25, WZ1, WZ1 + 0.25),
                           (wy0 - 0.25, wy0, WZ0, WZ1), (wy1, wy1 + 0.25, WZ0, WZ1)):
        b.box((OX1 - 0.05, a0, z0), (OX1 + 0.15, a1, z1), P.ORANGE, bevel=0.02)
    b.box((OX1 - 0.05, wy0 - 0.40, WZ0 - 0.55), (OX1 + 0.42, wy1 + 0.40, WZ0 - 0.25), P.WHITE, bevel=0.04)
    # back (+Y) and west (-X) walls
    W0((OX0, OY1 - OWT, FLOOR), (OX1, OY1, OWALL))
    W0((OX0, y0f, FLOOR), (OX0 + OWT, OY1 - OWT, OWALL))
    # brick courses, red base course (4-stud bricks), red band under the eaves
    BZ, EZ0, EZ1 = FLOOR + 1.05, 8.85, 9.26
    fh = [(wins[0][0] - 0.40, wins[0][1] + 0.40, WZ0 - 0.55, WZ1 + 0.25),
          (DLX - FW - 0.10, ODX1 + FW + 0.10, FLOOR, ODZ1 + FW), (px0 - 0.18, px1 + 0.12, pz0 - 0.18, pz1 + 0.18)]
    courses(b, "x", OY0, -1, OX0, OX1, BZ, EZ0, holes=fh)
    courses(b, "y", OX1, 1, OY0, OY1, BZ, EZ0, holes=[(wy0 - 0.40, wy1 + 0.40, WZ0 - 0.55, WZ1 + 0.25)])
    courses(b, "x", OY1, 1, OX0, OX1, BZ, EZ0)
    courses(b, "y", OX0, -1, OY0, OY1, BZ, EZ0)
    P_ = 0.14
    def base(lo, hi):
        along_x = hi[0] - lo[0] > hi[1] - lo[1]
        a0, a1 = (lo[0], hi[0]) if along_x else (lo[1], hi[1])
        n = max(1, round((a1 - a0) / 2.8))
        for i in range(n):
            u0, u1 = a0 + i * (a1 - a0) / n + 0.03, a0 + (i + 1) * (a1 - a0) / n - 0.03
            b.box((u0, lo[1], FLOOR) if along_x else (lo[0], u0, FLOOR), (u1, hi[1], BZ) if along_x else (hi[0], u1, BZ),
                  P.RED, bevel=0.07)
            keep_faces(b, (1, 2, 3, 4, 5))
    base((OX0 - P_, OY0 - P_), (DLX - FW - 0.12, OY0 + 0.05))
    base((OX1 - 0.05, OY0 + 0.08), (OX1 + P_, OY1 - 0.08))
    base((OX0 - P_, OY1 - 0.05), (OX1 + P_, OY1 + P_))
    base((OX0 - P_, OY0 + 0.08), (OX0 + 0.05, OY1 - 0.08))
    for lo, hi in (((OX0 - 0.10, OY0 - 0.10), (OX1 + 0.10, OY0 + 0.45)), ((OX0 - 0.10, OY1 - 0.45), (OX1 + 0.10, OY1 + 0.10)),
                   ((OX0 - 0.10, OY0 + 0.40), (OX0 + 0.45, OY1 - 0.40)), ((OX1 - 0.45, OY0 + 0.40), (OX1 + 0.10, OY1 - 0.40))):
        b.box((lo[0], lo[1], EZ0), (hi[0], hi[1], EZ1), P.RED, bevel=0.04)
    # interior: a desk with a chart
    b.box((OX0 + OWT + 0.05, -14.6, FLOOR), (OX0 + OWT + 1.6, -12.0, FLOOR + 2.4), P.BROWN, bevel=0.06)
    b.box((OX0 + OWT + 0.3, -14.0, FLOOR + 2.4), (OX0 + OWT + 1.3, -12.6, FLOOR + 2.44), P.WHITE, bevel=0.0)
    # stepped roof: blue tiers stepping in from the +-X eaves, stud rows on each ledge, orange studded ridge cap
    zr, th, st, ov = OWALL, 0.70, 1.00, 0.45
    xa, xb, ya, yb = OX0 - ov, OX1 + ov, OY0 - ov, OY1 + ov
    for t in range(4):
        b.box((xa + t * st, ya, zr + t * th), (xb - t * st, yb, zr + (t + 1) * th), P.BLUE, bevel=0.05)
        if t < 3:
            for x in (xa + t * st + st / 2, xb - t * st - st / 2):
                b.stud_row(x, ya + 0.6, x, yb - 0.6, zr + (t + 1) * th, P.BLUE, spacing=1.05, r=0.30, h=0.22, n=10)
    zt, xm = zr + 4 * th, (xa + xb) / 2
    b.box((xm - 0.60, ya - 0.10, zt), (xm + 0.60, yb + 0.10, zt + 0.45), P.ORANGE, bevel=0.05)
    b.stud_row(xm, ya + 0.4, xm, yb - 0.4, zt + 0.45, P.ORANGE, spacing=1.05, r=0.30, h=0.22, n=10)
    b.box((xa - 0.06, ya - 0.06, zr - 0.30), (xb + 0.06, yb + 0.06, zr), P.WHITE, bevel=0.04)   # eave course


def crate(b, cx, cy, z, s, h, c):
    """A slatted Lego crate: dark core, corner posts and three proud slats per face in colour c, a studded lid."""
    a = s / 2
    b.box((cx - a + 0.12, cy - a + 0.12, z), (cx + a - 0.12, cy + a - 0.12, z + h - 0.25), P.DBG, bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((cx + sx * a - 0.22, cy + sy * a - 0.22, z), (cx + sx * a + 0.22, cy + sy * a + 0.22, z + h - 0.25), c,
                  bevel=0.04)
    sh = (h - 0.25) / 3
    for k in range(3):
        z0, z1 = z + k * sh + 0.08, z + (k + 1) * sh - 0.08
        for sy in (-1, 1):
            b.box((cx - a + 0.22, cy + sy * (a - 0.02) - 0.10, z0), (cx + a - 0.22, cy + sy * (a - 0.02) + 0.10, z1), c,
                  bevel=0.03)
        for sx in (-1, 1):
            b.box((cx + sx * (a - 0.02) - 0.10, cy - a + 0.22, z0), (cx + sx * (a - 0.02) + 0.10, cy + a - 0.22, z1), c,
                  bevel=0.03)
    b.box((cx - a - 0.05, cy - a - 0.05, z + h - 0.25), (cx + a + 0.05, cy + a + 0.05, z + h), c, bevel=0.05)
    b.studs(cx - a, cx + a, cy - a, cy + a, z + h, c, step=s / 2, r=0.40, h=0.24, n=10)


def tyre_stack(b, cx, cy, n):
    """Lego tyres lying flat: black rings with light grey hubs and dark centres."""
    for k in range(n):
        zc = FLOOR + 0.45 + k * 0.90
        i0 = len(b.v)
        b.torus(0, 0, 0, 1.00, 0.45, P.BLACK, maj=14, mnr=6)
        remap(b, i0, lambda x, y, z, zc=zc: (cx + y, cy + z, zc + x))
        b.cyl(cx, cy, zc - 0.30, zc + 0.30, 0.62, P.LBG, n=12)
        b.cyl(cx, cy, zc + 0.30, zc + 0.36, 0.26, P.DBG, n=8, bottom=False)


def pallet(b, x0, y0, z, w, d, c=P.TAN):
    """A bevelled Lego pallet: brown runners, three slats, studs on the slat ends; deck top at z."""
    for xx in (x0 + 0.5, x0 + w - 0.5):
        b.box((xx - 0.35, y0 + 0.1, z - 0.70), (xx + 0.35, y0 + d - 0.1, z - 0.34), P.BROWN, bevel=0.04)
    for k in range(3):
        yy = y0 + (k + 0.5) * d / 3
        b.box((x0, yy - d / 7, z - 0.34), (x0 + w, yy + d / 7, z), c, bevel=0.06)
        for xx in (x0 + 0.35, x0 + w - 0.35):
            b.cyl(xx, yy, z, z + 0.18, 0.24, c, n=8, bottom=False)


def lv1_props(b):
    """Chunky Lego yard stock: a red tool chest and a tyre stack by the bow, a winch with a cable to the cradle, a
    lumber pallet on the west side, slatted crates stacked two high at the west back."""
    x0, x1, y0, y1, zt = -9.55, -7.35, -8.10, -4.20, FLOOR + 2.60
    b.box((x0, y0, FLOOR), (x1, y1, zt), P.RED, bevel=0.08)
    for k in range(3):
        z = FLOOR + 0.30 + k * 0.78
        b.box((x1 - 0.02, y0 + 0.25, z), (x1 + 0.08, y1 - 0.25, z + 0.58), P.WHITE if k == 1 else P.RED, bevel=0.02)
        b.box((x1 + 0.08, (y0 + y1) / 2 - 0.55, z + 0.20), (x1 + 0.20, (y0 + y1) / 2 + 0.55, z + 0.38), P.LBG,
              bevel=0.0)
    b.studs(x0 + 0.1, x1 - 0.1, y0 + 0.1, y1 - 0.1, zt, P.RED, step=1.1, r=0.36, h=0.24, n=10)
    tyre_stack(b, -11.60, -7.00, 3)
    tyre_stack(b, -15.60, 5.20, 2)
    # winch: yellow studded base, two dark cheeks, a red drum with black cable, a crank on the -X side
    wx, wy = 7.85, -10.40
    b.box((wx - 1.6, wy - 1.3, FLOOR), (wx + 1.6, wy + 1.3, FLOOR + 0.70), P.YELLOW, bevel=0.06)
    b.studs(wx - 1.5, wx + 1.5, wy + 0.55, wy + 1.25, FLOOR + 0.70, P.YELLOW, step=1.0, r=0.30, h=0.20, n=10)
    for sx in (-1, 1):
        b.box((wx + sx * 1.35 - 0.2, wy - 0.7, FLOOR + 0.70), (wx + sx * 1.35 + 0.2, wy + 0.5, FLOOR + 2.50), P.LBG,
              bevel=0.04)
    b.cyl_x(wx, wy - 0.10, FLOOR + 1.80, 0.75, 2.30, P.RED, n=12)
    b.cyl_x(wx, wy - 0.10, FLOOR + 1.80, 0.85, 1.60, P.BLACK, n=12)
    b.box((wx - 1.75, wy - 0.25, FLOOR + 1.65), (wx - 1.55, wy + 0.10, FLOOR + 2.60), P.LBG, bevel=0.02)
    b.cyl_x(wx - 1.95, wy + 0.0, FLOOR + 2.55, 0.14, 0.50, P.RED, n=8)
    # lumber pallet (west side): three courses of brown planks with proud ends
    pallet(b, -17.40, -4.20, FLOOR + 0.70, 4.4, 3.2)
    for k in range(3):
        z = FLOOR + 0.70 + k * 0.42
        for j in range(4):
            y = -4.05 + j * 0.75
            b.box((-17.35 + 0.08 * (k % 2), y + 0.04, z), (-13.10 - 0.08 * (k % 2), y + 0.70, z + 0.38),
                  P.BROWN if (j + k) % 2 else P.ORANGE, bevel=0.04)
    # slatted crates, two high, at the west back
    for cx, cy, z, c in ((-16.0, 14.4, FLOOR, P.ORANGE), (-16.0, 10.8, FLOOR, P.BLUE), (-16.0, 18.0, FLOOR, P.YELLOW),
                         (-16.0, 14.4, FLOOR + 2.75, P.RED), (-16.0, 10.8, FLOOR + 2.75, P.GREEN)):
        crate(b, cx, cy, z, 3.2, 2.6, c)


def lane(b, x0, y0, x1, y1, c0=P.YELLOW, c1=P.BLACK, seg=1.2):
    """A painted yellow/black safety line on the floor tiles."""
    along_x = x1 - x0 > y1 - y0
    a0, a1 = (x0, x1) if along_x else (y0, y1)
    k, u = 0, a0
    while u < a1 - 0.05:
        v = min(u + seg, a1)
        lo, hi = ((u, y0), (v, y1)) if along_x else ((x0, u), (x1, v))
        b.box((lo[0], lo[1], TILE_TOP - 0.02), (hi[0], hi[1], TILE_TOP + 0.05), c0 if k % 2 else c1, bevel=0.0)
        keep_faces(b, (1, 2, 3, 4, 5))
        u, k = v, k + 1


def lv1_paint(b):
    """The right front until the Lv3 dock takes it (Lv1_L07): the front wall, a painted safety line, full stud rows, paint
    cans on a pallet."""
    front_wall(b, 1)
    lane(b, 9.75, -20.55, 10.15, -1.05)
    floor_studs(b, 10.8, 18.3, -19.8, -11.0)
    floor_studs(b, 15.3, 18.3, -10.8, -1.8)
    pallet(b, 10.60, -9.60, FLOOR + 0.70, 4.2, 3.6)
    for cx, cy, c in ((11.70, -8.70, P.RED), (13.75, -8.70, P.BLUE), (11.70, -6.90, P.YELLOW), (13.75, -6.90, P.GREEN)):
        z0 = FLOOR + 0.70
        b.cyl(cx, cy, z0, z0 + 1.30, 0.72, P.LBG, n=12, bottom=False)
        b.cyl(cx, cy, z0 + 1.30, z0 + 1.42, 0.76, c, n=12, bottom=False)
        b.cyl(cx, cy, z0 + 0.35, z0 + 0.95, 0.75, c, n=12, top=False, bottom=False)
        b.box((cx - 0.06, cy - 0.66, z0 + 1.42), (cx + 0.06, cy + 0.66, z0 + 1.75), P.DBG, bevel=0.0)


PAD = (10.40, 17.60, -0.60, 6.60)
PAD_Z = 1.15
PAD_CX = 16.00                  # crate stack x
CRATE_PS, CRATE_PH = 4.00, 3.90 # pad crates ~4 studs tall
CRATE_Y0, CRATE_Y1 = 1.55, 5.60 # front stack, back crate centres
TIMBER = (10.85, 13.73, -0.25, 3.45, 5.55)    # timber stack x0, x1, y0, y1, top


def lv1_pad(b):
    """The right half's storage (Lv1_L09, every level): tan plates (two coloured) on a dark bed, a red/blue border of
    2-stud plates, a timber stack as tall as the boat's cabin, big crates ~4 studs tall two high behind it, yellow bollards."""
    px0, px1, py0, py1 = PAD
    b._emit([(px0, py0, 1.04), (px1, py0, 1.04), (px1, py1, 1.04), (px0, py1, 1.04)], ((0, 1, 2, 3),), P.DBG)
    n, sx, sy = 4, (px1 - px0) / 4, (py1 - py0) / 4
    for i in range(n):
        for j in range(n):
            c = {(0, 3): P.YELLOW, (1, 3): P.BLUE}.get((i, j), P.TAN)
            b.box((px0 + i * sx + 0.07, py0 + j * sy + 0.07, TILE_TOP - 0.02),
                  (px0 + (i + 1) * sx - 0.07, py0 + (j + 1) * sy - 0.07, PAD_Z), c, bevel=0.05)
            keep_faces(b, (1, 2, 3, 4, 5))
    u, E, BZ = 1.20, 0.04, 1.22                      # border: 2-stud plates, alternating red and blue

    def plate(x, y, along_x, c):
        w, d = (2 * u, u) if along_x else (u, 2 * u)
        b.box((x + E, y + E, TILE_TOP - 0.02), (x + w - E, y + d - E, BZ), c, bevel=0.04)
        keep_faces(b, (1, 2, 3, 4, 5))
        for k in (0.5, 1.5):
            sx_, sy_ = (x + k * u, y + u / 2) if along_x else (x + u / 2, y + k * u)
            b.cyl(sx_, sy_, BZ, BZ + 0.20, 0.34, c, n=8, bottom=False)
    x0b, y0b = px0 - u, py0 - u
    for i in range(4):
        plate(x0b + i * 2 * u, y0b, True, P.RED if i % 2 else P.BLUE)
        plate(x0b + i * 2 * u, py1, True, P.BLUE if i % 2 else P.RED)
    for j in range(3):
        plate(x0b, py0 + j * 2 * u, False, P.RED if j % 2 else P.BLUE)
        plate(px1, py0 + j * 2 * u, False, P.BLUE if j % 2 else P.RED)
    floor_studs(b, 7.2, 8.6, 1.5, 7.2)
    floor_studs(b, 7.2, 18.2, 9.0, 11.2)
    floor_studs(b, 7.2, 8.9, 18.0, 21.0)
    # crates, two high: orange under blue at the front, a yellow one behind
    crate(b, PAD_CX, CRATE_Y0, PAD_Z, CRATE_PS, CRATE_PH, P.ORANGE)
    crate(b, PAD_CX, CRATE_Y0, PAD_Z + CRATE_PH, CRATE_PS, CRATE_PH, P.BLUE)
    crate(b, PAD_CX, CRATE_Y1, PAD_Z, CRATE_PS, CRATE_PH, P.YELLOW)
    # timber stack: four courses of three beams, their ends to the path, studs on top
    tx0, tx1, ty0, ty1, tz = TIMBER
    bw, bh = (tx1 - tx0) / 3, (tz - PAD_Z) / 4
    for k in range(4):
        for i in range(3):
            b.box((tx0 + i * bw + 0.03, ty0 + 0.12 * (k % 2), PAD_Z + k * bh), (tx0 + (i + 1) * bw - 0.03, ty1 - 0.12 * (k % 2), PAD_Z + (k + 1) * bh - 0.03),
                  P.RIB if (i + k) % 2 else P.TAN, bevel=0.09)
    b.studs(tx0, tx1, ty0 + 0.3, ty1 - 0.3, tz - 0.03, P.TAN, step=1.1, r=0.32, h=0.20, n=8)
    for x in (11.00, 13.40):                         # yellow bollards at the pad's front
        b.cyl(x, y0b + u / 2, BZ, BZ + 1.35, 0.52, P.YELLOW, n=12, top=False, bottom=False)
        b.cyl(x, y0b + u / 2, BZ + 1.35, BZ + 1.65, 0.68, P.YELLOW, n=12)
        b.cyl(x, y0b + u / 2, BZ + 1.65, BZ + 1.85, 0.30, P.YELLOW, n=8, bottom=False)


def lv1_slip(b):
    """The slipway: two continuous dark grey rails on darker sleepers from under the bow out to the sea, end stops,
    and yellow/black hazard edging along both sides."""
    y = -13.00
    while y < 21.0:
        b.box((-5.10, y, FLOOR + 0.05), (5.10, y + 0.70, 1.05), P.BLACK, bevel=0.04)    # low and spaced: stripes, not a black mass from the path
        keep_faces(b, (1, 2, 3, 4, 5))
        y += 2.00
    for x in (-4.14, 4.14):
        b.box((x - 0.50, -13.20, 1.05), (x + 0.50, 21.45, 1.35), P.DBG, bevel=0.06)                  # rails 1 wide, 0.3 proud
        b.box((x - 0.65, 21.05, FLOOR + 0.05), (x + 0.65, 21.62, 2.00), P.RED, bevel=0.06)          # end stops
    for s in (-1, 1):
        k, y = 0, -9.40
        while y < 21.4:
            b.box((s * 6.0, y, FLOOR + 0.03), (s * 6.4, min(y + 1.0, 21.5), 1.06), P.YELLOW if k % 2 else P.BLACK,
                  bevel=0.0)
            keep_faces(b, (1, 2, 3, 4, 5))
            y, k = y + 1.0, k + 1


def lv1_cols(c):
    """Lv1 collision boxes (walls, gate piers, cradle, hull, cabin, gantry legs, office walls round the door, props)."""
    for s in (-1, 1):
        xa, xb = sorted((s * YW, s * YWO))
        c.box((xa, -21.55, FLOOR), (xb, 21.55, WALL_TOP), P.WHITE)
    c.box((-YW, FZ0, FLOOR), (-GATE - 0.8, FZ1, WALL_TOP), P.WHITE)     # the right front wall's box is Lv1_L07's (gone at Lv3)
    for s in (-1, 1):
        c.box((s * GATE - 0.85, -22.0, FLOOR), (s * GATE + 0.85, -20.3, 4.50), P.ORANGE)
        c.box((s * GLEG_X - GLEG_HX, -GLEG_HY, FLOOR), (s * GLEG_X + GLEG_HX, GLEG_HY, GBEAM_Z0), P.YELLOW)
        for y in (-5.75, 5.75):
            c.box((s * 4.14 - 1.28, y - 1.5, FLOOR), (s * 4.14 + 1.28, y + 1.5, HULL_Z0), P.DBG)
    c.box((-HULL_HW, -HULL_Y, HULL_Z0), (HULL_HW, HULL_Y, DECK_Z1), P.RED)
    c.box((-2.6, BOW_TIP + 0.4, 8.0), (2.6, -HULL_Y, DECK_Z1), P.RED)
    c.box((-2.645, 1.265, DECK_Z1), (2.645, 6.095, 15.06), P.WHITE)
    c.box((OX0, OY0, FLOOR), (ODX0, OY0 + OWT, OWALL), P.WHITE)          # office: front either side of the door
    c.box((ODX1, OY0, FLOOR), (OX1, OY0 + OWT, OWALL), P.WHITE)
    c.box((OX0, OY1 - OWT, FLOOR), (OX1, OY1, OWALL), P.WHITE)
    c.box((OX0, OY0 + OWT, FLOOR), (OX0 + OWT, OY1 - OWT, OWALL), P.WHITE)
    c.box((OX1 - OWT, OY0 + OWT, FLOOR), (OX1, OY1 - OWT, OWALL), P.WHITE)
    c.box((OX0 - 0.45, OY0 - 0.45, OWALL), (OX1 + 0.45, OY1 + 0.45, OWALL + 2.8), P.BLUE)
    c.box((-9.55, -8.10, FLOOR), (-7.35, -4.20, FLOOR + 2.6), P.RED)
    c.box((-13.05, -8.45, FLOOR), (-10.15, -5.55, FLOOR + 2.7), P.BLACK)
    c.box((6.25, -11.7, FLOOR), (9.45, -9.1, FLOOR + 2.6), P.YELLOW)
    c.box((-17.4, -4.2, FLOOR), (-13.0, -1.0, FLOOR + 1.9), P.TAN)
    c.box((-17.6, 9.2, FLOOR), (-14.4, 19.6, FLOOR + 5.35), P.BROWN)
    a = CRATE_PS / 2
    c.box((PAD_CX - a, CRATE_Y0 - a, FLOOR), (PAD_CX + a, CRATE_Y0 + a, PAD_Z + 2 * CRATE_PH), P.BLUE)   # crate stack, two high
    c.box((PAD_CX - a, CRATE_Y1 - a, FLOOR), (PAD_CX + a, CRATE_Y1 + a, PAD_Z + CRATE_PH), P.YELLOW)     # crate
    c.box((TIMBER[0], TIMBER[2], FLOOR), (TIMBER[1], TIMBER[3], TIMBER[4]), P.TAN)      # timber stack


# ------------------------------------------------------------------ Lv2: red jib crane (right back) + tool bench (path front)
def crane_lv2(b):
    """A tall red jib crane right of the gantry, standing clear of its leg: a dark foot, a two-course red/white brick base,
    a chunky red tower with white collars, a slewing ring, a big white cab, a deep red truss jib (white braces, studded
    top) outward over the right half, a short counter-jib with studded blocks toward the gantry, an A-frame peak with tie
    bars, and a trolley whose short cable holds a hook, two slings and a big slatted blue crate high against the sky."""
    x, y, T, F = TWX, TWY, TW, TBASE
    b.box((x - F - 0.20, y - F - 0.20, FLOOR), (x + F + 0.20, y + F + 0.20, 1.40), P.DBG, bevel=0.08)
    keep_faces(b, (1, 2, 3, 4, 5))
    for hw_, z0, z1, c in ((F, 1.38, 3.20, P.RED), (F - 0.75, 3.18, 4.90, P.WHITE)):   # two courses, two bricks each
        for sx in (-1, 1):
            xa, xb = sorted((x + sx * 0.03, x + sx * hw_))
            b.box((xa, y - hw_, z0), (xb, y + hw_, z1), c, bevel=0.09)
    for sy in (-1, 1):
        b.stud_row(x - F + 0.40, y + sy * (F - 0.38), x + F - 0.40, y + sy * (F - 0.38), 3.20, P.RED, spacing=1.05, r=0.28, h=0.20, n=10)
        b.stud_row(x + sy * (F - 0.38), y - F + 1.40, x + sy * (F - 0.38), y + F - 1.40, 3.20, P.RED, spacing=1.05, r=0.28, h=0.20, n=10)
    z, zb = 7.20, 4.85                          # red brick courses between the white collars, a dark seam at each joint
    while z < TOWER_Z - 4.0:
        brick_stack(b, x - T, x + T, y - T, y + T, zb, z + 0.02, 2, P.RED)
        b.box((x - T - 0.06, y - T - 0.06, z), (x + T + 0.06, y + T + 0.06, z + 0.40), P.WHITE, bevel=0.04)
        zb, z = z + 0.38, z + 3.20
    brick_stack(b, x - T, x + T, y - T, y + T, zb, TOWER_Z, 3, P.RED)
    b.cyl(x, y, TOWER_Z, TOWER_Z + 0.35, T + 0.40, P.DBG, n=16)
    j0, j1 = TOWER_Z + 0.35, TOWER_Z + 2.05
    for za, zb in ((j0, j0 + 0.40), (j1 - 0.40, j1)):                          # jib chords
        b.box((x - 1.20, y - 0.80, za), (JIB_X1, y + 0.80, zb), P.RED, bevel=0.05)
    b.box((JIB_X1 - 0.45, y - 0.80, j0 + 0.40), (JIB_X1, y + 0.80, j1 - 0.40), P.RED, bevel=0.03)
    xx, up = x + 1.20, True
    while xx < JIB_X1 - 1.0:
        for sy in (-1, 1):
            b.beam((xx, y + sy * 0.68, j0 + (0.40 if up else 1.30)), (xx + 1.1, y + sy * 0.68, j0 + (1.30 if up else 0.40)),
                   0.22, 0.22, P.WHITE)
        xx, up = xx + 1.1, not up
    for sy in (-1, 1):
        b.stud_row(x + 0.9, y + sy * 0.40, JIB_X1 - 0.5, y + sy * 0.40, j1, P.RED, spacing=1.15, r=0.30, h=0.22, n=10)
    b.box((JIB_X1, y - 0.88, j0 - 0.05), (JIB_X1 + 0.28, y + 0.88, j1 + 0.05), P.DBG, bevel=0.04)      # tip cap
    b.box((x - 2.60, y - 0.80, j0), (x - 1.20, y + 0.80, j0 + 0.70), P.RED, bevel=0.05)                # counter-jib
    for k in range(2):
        b.box((x - 2.55, y - 1.00, j0 + 0.70 + k * 0.72), (x - 1.25, y + 1.00, j0 + 1.40 + k * 0.72), P.LBG, bevel=0.05)
    b.studs(x - 2.55, x - 1.25, y - 1.00, y + 1.00, j0 + 2.12, P.LBG, step=0.65, r=0.26, h=0.20, n=10)
    b.box((x - 0.45, y - 0.45, j1), (x + 0.45, y + 0.45, j1 + 3.2), P.RED, bevel=0.05)                 # peak
    b.cyl(x, y, j1 + 3.2, j1 + 3.6, 0.50, P.ORANGE, n=10)
    for tx in (x - 2.0, JIB_X1 - 1.5):
        b.beam((x, y, j1 + 3.0), (tx, y, j1 + 0.2), 0.16, 0.16, P.BLACK)
    # cab under the jib on the path side of the tower
    cz0, cz1 = TOWER_Z - 2.85, TOWER_Z + 0.30
    b.box((x - 1.15, y - 3.30, cz0), (x + 1.15, y - T + 0.05, cz1), P.WHITE, bevel=0.07)
    b.box((x - 0.85, y - 3.36, cz0 + 1.05), (x + 0.85, y - 3.30, cz1 - 0.35), P.INK, bevel=0.0)
    b.box((x - 1.21, y - 3.00, cz0 + 1.05), (x - 1.15, y - 1.50, cz1 - 0.35), P.INK, bevel=0.0)
    b.box((x - 1.25, y - 3.40, cz0 - 0.30), (x + 1.25, y - T + 0.05, cz0), P.RED, bevel=0.05)
    b.box((x - 1.25, y - 3.40, cz1), (x + 1.25, y - T + 0.05, cz1 + 0.05), P.DBG, bevel=0.0)
    # trolley, short cable, hook, slings and the big slatted crate
    hz = j0 - 2.00                                                             # hook block bottom
    b.box((HOOK_X - 0.75, y - 0.95, j0 - 0.60), (HOOK_X + 0.75, y + 0.95, j0), P.DBG, bevel=0.05)
    b.box((HOOK_X - 0.12, y - 0.12, hz + 0.70), (HOOK_X + 0.12, y + 0.12, j0 - 0.60), P.BLACK, bevel=0.0)
    b.box((HOOK_X - 0.60, y - 0.50, hz), (HOOK_X + 0.60, y + 0.50, hz + 0.70), P.ORANGE, bevel=0.08)
    ctop = hz - 0.45
    for sx in (-1, 1):
        b.beam((HOOK_X, y, hz + 0.08), (HOOK_X + sx * 1.60, y, ctop + 0.10), 0.18, 0.18, P.BLACK)
    crate(b, HOOK_X, y, ctop - CRATE_H, CRATE_S, CRATE_H, P.BLUE)


def bench_lv2(b):
    """A red tool bench left of the gate mouth, 2 studs clear of the hull in the path view: a red cabinet with white
    drawer handles, a studded tan top, a tan board (dark frame) with three big brick tools under a low
    five-stripe red/white awning 2 studs deep, on a one-brick studded plinth. Built in the tool() frame (board at x = FACE, tools toward -X), then turned
    so the tools face the path (-Y)."""
    i0 = len(b.v)
    x0, x1, y0, y1 = FACE - 2.10, FACE, -2.30, 2.30
    b.box((x0, y0, FLOOR), (x1, y1, BTOP - 0.30), P.RED, bevel=0.08)
    for ya, yb in ((y0 + 0.25, -0.10), (0.10, y1 - 0.25)):
        for j in range(2):
            z = FLOOR + 0.35 + j * 1.05
            b.box((x0 - 0.08, ya, z), (x0 + 0.02, yb, z + 0.85), P.RED, bevel=0.03)
            b.box((x0 - 0.20, (ya + yb) / 2 - 0.45, z + 0.55), (x0 - 0.08, (ya + yb) / 2 + 0.45, z + 0.70), P.WHITE,
                  bevel=0.0)
    b.box((x0 - 0.15, y0 - 0.15, BTOP - 0.30), (x1, y1 + 0.15, BTOP), P.TAN, bevel=0.06)
    b.studs(x0, x0 + 0.9, y0 + 0.9, y1 - 1.3, BTOP, P.TAN, step=0.9, r=0.30, h=0.20, n=10)
    b.box((x1, y0, BTOP), (x1 + 0.30, y1, BBOARD), P.WHITE, bevel=0.04)                            # bright pegboard
    for a0, a1, z0, z1 in ((y0 - 0.12, y0 + 0.18, BTOP, BBOARD + 0.02), (y1 - 0.18, y1 + 0.12, BTOP, BBOARD + 0.02),
                           (y0 - 0.12, y1 + 0.12, BBOARD - 0.22, BBOARD + 0.02)):
        b.box((x1 - 0.04, a0, z0), (x1 + 0.34, a1, z1), P.DBG, bevel=0.02)
    for i, kind in enumerate(("hammer", "wrench", "saw")):                        # three big tools, nothing else on the board
        ty, tz, j = -1.45 + i * 1.45, BTOP + 0.20, len(b.v)
        tool(b, kind, ty, tz)
        remap(b, j, lambda x, y, z, ty=ty, tz=tz: (FACE + TOOL_S * (x - FACE), ty + TOOL_S * (y - ty), tz + TOOL_S * (z - tz)))
    ay0, ay1, ns = y0 - 0.25, y1 + 0.25, 5                                                         # awning: red/white stripes, 2 studs deep
    zh, zl = BBOARD + 0.80, BBOARD + 0.12
    for k in range(ns):
        u0, u1 = ay0 + k * (ay1 - ay0) / ns + 0.02, ay0 + (k + 1) * (ay1 - ay0) / ns - 0.02
        col = P.RED if k % 2 == 0 else P.WHITE
        xf = x1 - AWN_D
        b._emit([(x1 + 0.30, u0, zh), (x1 + 0.30, u1, zh), (xf, u1, zl), (xf, u0, zl),
                 (x1 + 0.30, u0, zh + 0.22), (x1 + 0.30, u1, zh + 0.22), (xf, u1, zl + 0.22), (xf, u0, zl + 0.22)],
                ((0, 3, 2, 1), (4, 5, 6, 7), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (0, 1, 5, 4)), col)
        b.box((xf - 0.12, u0, zl - 0.40), (xf + 0.02, u1, zl + 0.22), col, bevel=0.03)
    for yy in (y0 + 0.10, y1 - 0.10):
        b.beam((x1, yy, BBOARD - 0.80), (x1 - AWN_D + 0.15, yy, zl - 0.02), 0.14, 0.14, P.DBG)
    remap(b, i0, lambda x, y, z: (BENCH_X - BENCH_S * y, BENCH_Y + BENCH_S * (x - FACE), FLOOR + BENCH_PL + BENCH_S * (z - FLOOR)))
    # plinth: orange plate with a stud row along the front
    px0, px1, py0, py1 = BENCH_X - 3.10, BENCH_X + 3.10, BENCH_Y - 3.40, BENCH_Y + 0.55
    b.box((px0, py0, TILE_TOP - 0.02), (px1, py1, FLOOR + BENCH_PL), P.ORANGE, bevel=0.05)
    keep_faces(b, (1, 2, 3, 4, 5))
    b.stud_row(px0 + 0.4, py0 + 0.30, px1 - 0.4, py0 + 0.30, FLOOR + BENCH_PL, P.ORANGE, spacing=1.2, r=0.22, h=0.16, n=8)


# ------------------------------------------------------------------ Lv3: wet dock + boat shed (right front)
def dock(b):
    """A grey brick rim round clear water (seams outside), a light coping with studs; a low red/white striped
    water gate at the path end in the front wall's place, a quay strip, two mooring bollards."""
    ix0, ix1, iy0, iy1 = DX0 + RIM, DX1 - RIM, DY0 + RIM, DY1 - RIM
    for lo, hi in (((DX0, DY0, FLOOR), (ix0, DY1, RIM_Z)), ((ix1, DY0, FLOOR), (DX1, DY1, RIM_Z)),
                   ((ix0, iy1, FLOOR), (ix1, DY1, RIM_Z))):
        b.box(lo, hi, P.DBG, bevel=0.06)
    b.box((DX0 - 0.05, DY0 - 0.05, RIM_Z), (ix0, DY1 + 0.05, COPE_Z), P.LBG, bevel=0.05)
    b.box((ix1, DY0 - 0.05, RIM_Z), (DX1 + 0.04, DY1 + 0.05, COPE_Z), P.LBG, bevel=0.05)
    b.box((ix0, iy1, RIM_Z), (ix1, DY1 + 0.05, COPE_Z), P.LBG, bevel=0.05)
    for x in (DX0 + 0.32, DX1 - 0.32):
        b.stud_row(x, DY0 + 1.2, x, DY1 - 0.6, COPE_Z, P.LBG, spacing=1.2, r=0.28, h=0.20, n=10)
    seams_y(b, DX0, -1, DY0, DY1, FLOOR, RIM_Z)
    seams_x(b, DY1, +1, DX0, DX1, FLOOR, RIM_Z)
    # the low water gate at the path end, in the front wall's place: white body, bold red stripes, a light studded deck
    cx0, cx1, cy0, cz1 = GATE + 0.85, DX1 - 0.05, FZ0 + 0.05, CAISSON_Z
    b.box((cx0, cy0, FLOOR - 0.02), (cx1, iy0, cz1), P.WHITE, bevel=0.06)
    keep_faces(b, (1, 2, 3, 4, 5))
    x = cx0 + 0.40
    while x < cx1 - 0.8:
        b.box((x, cy0 - 0.06, FLOOR + 0.22), (min(x + 1.20, cx1 - 0.20), cy0 + 0.02, cz1 - 0.20), P.RED, bevel=0.02)
        x += 2.40
    b.box((cx0 - 0.04, cy0 - 0.05, cz1), (cx1 + 0.05, iy0 + 0.05, cz1 + 0.18), P.LBG, bevel=0.05)
    b.stud_row(cx0 + 0.5, cy0 + 0.45, cx1 - 0.5, cy0 + 0.45, cz1 + 0.18, P.YELLOW, spacing=1.20, r=0.30, h=0.20, n=10)
    for px in (DX0 + 0.45, DX1 - 0.45):
        b.cyl(px, -14.2, COPE_Z, COPE_Z + 0.90, 0.30, P.BLACK, n=10, bottom=False)                  # mooring bollards
    # quay strip under the shed's left posts (the shed's eave stands right of the crane tower in the path view)
    b.box((ix0 - 0.05, SHED_Y0 - 0.75, FLOOR), (QUAY_X1, iy1 + 0.05, COPE_Z - 0.04), P.LBG, bevel=0.05)
    b.stud_row(11.30, SHED_Y0 - 0.05, 11.30, iy1 - 0.4, COPE_Z - 0.04, P.LBG, spacing=1.2, r=0.28, h=0.20, n=10)
    b.stud_row(ix0 + 0.35, SHED_Y0 - 0.40, QUAY_X1 - 0.35, SHED_Y0 - 0.40, COPE_Z - 0.04, P.YELLOW, spacing=1.0, r=0.28, h=0.20, n=10)


def water(b):
    """Deep blue water with cyan shallows along the walls, three raised pale wave plates, white stud ripples at the hull's
    waterline (its sides are hidden inside the walls)."""
    ix0, ix1, iy0, iy1 = DX0 + RIM, DX1 - RIM, DY0 + RIM, DY1 - RIM
    xa, xb, ya, yb = ix0 - 0.05, ix1 + 0.05, iy0 - 0.05, iy1 + 0.05
    b._emit([(xa, ya, WATER_Z), (xb, ya, WATER_Z), (xb, yb, WATER_Z), (xa, yb, WATER_Z)], ((0, 1, 2, 3),), WATER_C)
    for lo, hi in (((xa, ya), (11.75, SHED_Y0 - 0.70)), ((11.75, ya), (xb, -18.70)), ((17.05, -18.70), (xb, yb))):
        b.box((lo[0], lo[1], WATER_Z - 0.02), (hi[0], hi[1], WATER_Z + 0.05), P.CYAN, bevel=0.0)    # shallows
        keep_faces(b, (1, 2, 3, 4, 5))
    for x0, x1, y0, y1 in ((11.95, 13.25, -17.20, -16.10), (10.75, 12.45, -14.30, -13.20), (12.00, 13.20, -12.20, -11.25)):
        b.box((x0, y0, WATER_Z - 0.02), (x1, y1, WATER_Z + 0.14), P.GLASS, bevel=0.05)               # wave plates: a step up each
        keep_faces(b, (1, 2, 3, 4, 5))
        b.box((x0 + 0.30, y0 + 0.28, WATER_Z + 0.12), (x1 - 0.30, y1 - 0.28, WATER_Z + 0.24), P.WHITE, bevel=0.04)
        keep_faces(b, (1, 2, 3, 4, 5))
    for x, y0, y1 in ((13.30, -16.60, -11.20), (17.48, -17.40, -3.60)):
        b.stud_row(x, y0, x, y1, WATER_Z + 0.03, P.WHITE, spacing=0.95, r=0.14, h=0.12, n=6)      # ripples at the waterline
    b.stud_row(HX - 1.10, HY - HS * 6.95, HX + 1.10, HY - HS * 6.95, WATER_Z + 0.03, P.WHITE, spacing=0.75, r=0.14, h=0.12, n=6)


def shed(b):
    """Half-open boat shed over the dock's back third, stern of the hull inside: white posts (dark feet, stud seams), left
    on the quay strip, right on the side wall, white eave beams, a red tie beam, a white back wall with brick courses, a
    stepped studded blue roof with an orange studded ridge cap, a stepped white gable with a red rim and a framed plaque with a
    wrench, a dark inner wall behind the boat, and a red/white striped awning 1 stud deep."""
    pxs, pys = SHED_PX, (SHED_Y0 + 0.40, DY1 - 0.45)
    for x, foot in ((pxs[0], COPE_Z - 0.04), (pxs[1], WALL_TOP + 0.20)):
        for y in pys:
            b.box((x - 0.55, y - 0.55, foot), (x + 0.55, y + 0.55, foot + 0.40), P.DBG, bevel=0.04)
            b.box((x - 0.40, y - 0.40, foot + 0.40), (x + 0.40, y + 0.40, EAVE - 0.90), P.WHITE, bevel=0.06)
            for z in (6.4, 9.6, 12.8):
                b.box((x - 0.44, y - 0.44, z), (x + 0.44, y + 0.44, z + 0.10), P.DBG, bevel=0.0)
        b.box((x - 0.45, SHED_Y0 - 0.05, EAVE - 0.90), (x + 0.45, DY1, EAVE), P.WHITE, bevel=0.05)     # eave beams
    b.box((pxs[0] + 0.45, SHED_Y0 - 0.05, EAVE - 0.90), (pxs[1] - 0.45, SHED_Y0 + 0.80, EAVE), P.RED, bevel=0.05)    # tie beams
    b.box((pxs[0] + 0.45, DY1 - 0.85, EAVE - 0.90), (pxs[1] - 0.45, DY1 - 0.10, EAVE), P.WHITE, bevel=0.05)
    b.box((pxs[0] + 0.40, DY1 - 0.55, COPE_Z), (pxs[1] - 0.40, DY1 - 0.10, EAVE - 0.90), P.WHITE, bevel=0.04)
    b.box((pxs[0] + 0.40, DY1 - 0.60, COPE_Z), (pxs[1] - 0.40, DY1 - 0.53, EAVE - 0.90), P.INK, bevel=0.0)     # the dark opening behind the boat
    courses(b, "x", DY1 - 0.60, -1, pxs[0] + 0.45, pxs[1] - 0.45, COPE_Z, EAVE - 0.90, n=8, brick=2.40)
    zr, th, st = EAVE, 1.00, 0.70
    xa, xb, ya, yb = SHED_XA, SHED_XB, SHED_Y0 - 0.40, DY1 + 0.30
    for t in range(5):
        b.box((xa + t * st, ya, zr + t * th), (xb - t * st, yb, zr + (t + 1) * th), P.BLUE, bevel=0.05)
        if t < 4:
            for x in (xa + t * st + st / 2, xb - t * st - st / 2):
                b.stud_row(x, ya + 0.6, x, yb - 0.6, zr + (t + 1) * th, P.BLUE, spacing=1.30, r=0.30, h=0.22, n=10)
        # gable: each tier's front white with a red rim at its ends
        g0, g1, gy = xa + t * st, xb - t * st, ya - 0.07
        b.box((g0 + 0.34, gy, zr + t * th + 0.03), (g1 - 0.34, ya + 0.03, zr + (t + 1) * th - 0.03), P.WHITE, bevel=0.02)
        for a0, a1 in ((g0 + 0.02, g0 + 0.30), (g1 - 0.30, g1 - 0.02)):
            b.box((a0, gy, zr + t * th + 0.03), (a1, ya + 0.03, zr + (t + 1) * th - 0.03), P.RED, bevel=0.02)
    zt, xm = zr + 5 * th, (xa + xb) / 2
    b.box((xm - 0.65, ya - 0.10, zt), (xm + 0.65, yb + 0.10, zt + 0.45), P.ORANGE, bevel=0.05)
    b.stud_row(xm, ya + 0.4, xm, yb - 0.4, zt + 0.45, P.ORANGE, spacing=1.05, r=0.30, h=0.22, n=10)
    b.box((xa - 0.06, ya - 0.06, zr - 0.30), (xb + 0.06, yb + 0.06, zr), P.WHITE, bevel=0.04)       # eave course
    # the awning: seven red/white sloped stripes 1 stud deep with a hanging valance, under the eave
    ax0, ax1, n = pxs[0] - 0.40, pxs[1] + 0.40, 7
    y0a, y1a, zh, zl = SHED_Y0 + 0.05, ya - 1.25, EAVE - 0.45, EAVE - 1.45
    for k in range(n):
        u0, u1 = ax0 + k * (ax1 - ax0) / n + 0.02, ax0 + (k + 1) * (ax1 - ax0) / n - 0.02
        c = P.RED if k % 2 == 0 else P.WHITE
        b._emit([(u0, y0a, zh), (u1, y0a, zh), (u1, y1a, zl), (u0, y1a, zl),
                 (u0, y0a, zh + 0.22), (u1, y0a, zh + 0.22), (u1, y1a, zl + 0.22), (u0, y1a, zl + 0.22)],
                ((0, 3, 2, 1), (4, 5, 6, 7), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7), (0, 1, 5, 4)), c)
        b.box((u0, y1a - 0.12, zl - 0.38), (u1, y1a + 0.02, zl + 0.22), c, bevel=0.03)
    # gable plaque: orange frame, white board, a dark wrench at 30 degrees
    hw_, z0, z1 = 1.60, EAVE + 0.42, EAVE + 3.00
    fy, by, iy = ya - 0.50, ya - 0.56, ya - 0.66
    b.box((xm - hw_ - 0.18, fy, z0 - 0.18), (xm + hw_ + 0.18, ya + 0.05, z1 + 0.18), P.ORANGE, bevel=0.07)
    b.box((xm - hw_, by, z0), (xm + hw_, fy, z1), P.WHITE, bevel=0.0)
    b.stud_row(xm - hw_ + 0.2, ya - 0.25, xm + hw_ - 0.2, ya - 0.25, z1 + 0.18, P.ORANGE, spacing=0.95, r=0.20, h=0.14, n=8)
    zc, ca, sa = (z0 + z1) / 2, math.cos(math.radians(30)), math.sin(math.radians(30))
    rot = lambda u, v: (xm + 0.84 * (u * ca - v * sa), zc + 0.84 * (u * sa + v * ca))
    for u0, u1, v0, v1 in ((-1.70, 0.65, -0.30, 0.30), (0.65, 1.15, -0.72, 0.72), (1.15, 1.75, -0.72, -0.24), (1.15, 1.75, 0.24, 0.72),
                           (-2.05, -1.70, -0.42, 0.42)):
        prism_y(b, iy, by, [rot(u0, v0), rot(u1, v0), rot(u1, v1), rot(u0, v1)], P.DBG)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    patch_lod_targets()
    mat = lego.material("MI_BoatYard_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv1", "Lv2", "Lv3")}

    def out(name, b, node):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[boatyard] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c, prefix=None):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills the basin
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (prefix or node, k + 1), box, node)

    # ================================================================ Lv1: the code yard as a mesh
    for name, fn in (("Lv1_L01_Floor", lv1_floor), ("Lv1_L02_Walls", lv1_walls), ("Lv1_L03_Boat", lv1_boat),
                     ("Lv1_L04_Gantry", lv1_gantry), ("Lv1_L05_Office", lv1_office), ("Lv1_L06_Props", lv1_props),
                     ("Lv1_L07_Paint", lv1_paint), ("Lv1_L08_Slip", lv1_slip), ("Lv1_L09_Pad", lv1_pad)):
        b = lego.B()
        fn(b)
        out(name, b, "Lv1")
    c = lego.B()
    lv1_cols(c)
    out_cols("Lv1", c)
    c = lego.B()                                # named Lv1_L07_*: DockPieces drops it with the wall at Lv3
    c.box((GATE + 0.8, FZ0, FLOOR), (YW, FZ1, WALL_TOP), P.WHITE)
    out_cols("Lv1", c, "Lv1_L07")

    # ================================================================ Lv2: red jib crane (right back) + tool bench
    for name, fn in (("Lv2_L01_Crane", crane_lv2), ("Lv2_L02_Bench", bench_lv2)):
        b = lego.B()
        fn(b)
        out(name, b, "Lv2")
    c = lego.B()
    bz = lambda z: FLOOR + BENCH_PL + BENCH_S * (z - FLOOR)
    c.box((TWX - TBASE, TWY - TBASE, FLOOR), (TWX + TBASE, TWY + TBASE, 4.90), P.DBG)       # brick base
    c.box((TWX - TW, TWY - TW, 4.90), (TWX + TW, TWY + TW, TOWER_Z + 2.05), P.RED)          # tower
    c.box((BENCH_X - 3.10, BENCH_Y - 3.40, FLOOR), (BENCH_X + 3.10, BENCH_Y, bz(BTOP)), P.RED)   # bench + plinth
    c.box((BENCH_X - 3.00, BENCH_Y, FLOOR), (BENCH_X + 3.00, BENCH_Y + 0.42, bz(BBOARD + 0.80)), P.TAN)   # board
    out_cols("Lv2", c)

    # ================================================================ Lv3: wet dock + boat shed + hull (right front)
    for name, fn in (("Lv3_L01_Dock", dock), ("Lv3_L02_Water", water), ("Lv3_L03_Shed", shed)):
        b = lego.B()
        fn(b)
        out(name, b, "Lv3")
    b = lego.B()
    hull(b)
    place_rot(b)
    out("Lv3_L04_Hull", b, "Lv3")
    ix0, ix1, iy0, iy1 = DX0 + RIM, DX1 - RIM, DY0 + RIM, DY1 - RIM
    c = lego.B()
    c.box((DX0, DY0, FLOOR), (ix0, DY1, COPE_Z), P.DBG)                                   # rim walls
    c.box((ix1, DY0, FLOOR), (DX1, DY1, COPE_Z), P.DBG)
    c.box((ix0, iy1, FLOOR), (ix1, DY1, COPE_Z), P.DBG)
    c.box((GATE + 0.85, FZ0, FLOOR), (DX1, iy0, CAISSON_Z + 0.18), P.WHITE)               # water gate, the wall line's only box at Lv3
    c.box((ix0, SHED_Y0 - 0.75, FLOOR), (QUAY_X1, iy1, COPE_Z - 0.04), P.DBG)               # quay strip
    for px in SHED_PX:
        for py in (SHED_Y0 + 0.40, DY1 - 0.45):
            c.box((px - 0.55, py - 0.55, COPE_Z), (px + 0.55, py + 0.55, EAVE), P.WHITE)    # shed posts
    c.box((SHED_PX[0] + 0.40, DY1 - 0.55, COPE_Z), (SHED_PX[1] - 0.40, DY1 - 0.10, EAVE), P.WHITE)    # shed back wall
    c.box((HX - 1.80 * HS, HY - 2.60 * HS, HZ + 0.60 * HS), (HX + 1.80 * HS, HY + 6.80 * HS, HZ + 3.55 * HS), P.RED)  # hull, three bites
    c.box((HX - 1.20 * HS, HY - 5.40 * HS, HZ + 1.50 * HS), (HX + 1.20 * HS, HY - 2.60 * HS, HZ + 3.55 * HS), P.RED)
    c.box((HX - 1.35 * HS, HY + 1.80 * HS, HZ + 3.55 * HS), (HX + 1.35 * HS, HY + 5.60 * HS, HZ + 5.80 * HS), P.WHITE)
    out_cols("Lv3", c)

    atts = []
    for name, loc in (("ATT_Work_Hull", (TWX - 3.50, TWY, FLOOR)),          # Lv2: the crane's foot
                      ("ATT_Work_Bench", (BENCH_X, BENCH_Y - 4.10, FLOOR)),  # Lv2: in front of the bench plinth
                      ("ATT_Work_Dock", (DX0 - 0.90, -15.00, FLOOR))):      # Lv3: beside the dock's west rim
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
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_HQAddons / M_Bld_FishMarketAddons), no PBR scans",
            "LOD1 triangles": "LOD1 keeps the add-ons' 50% share (patch_lod_targets)",
            "LOD2 triangles": "LOD2 keeps the add-ons' 25% share (patch_lod_targets): the hero ceiling would collapse the "
                              "small Lego detail meshes",
            "naming": "gameplay node/layer names (docs/25 B/J): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., "
                      "Lv3_Col01_COL..; the FBX importer flattens empty parents, so the node name is the mesh prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "crane", "target": [TWX - 4.0, TWY, 12.0], "dist": 34, "az": -30, "el": 10},
            {"name": "bench", "target": [BENCH_X, BENCH_Y - 1.0, 4.6], "dist": 13, "az": 0, "el": 10},
            {"name": "dock", "target": [(DX0 + DX1) / 2, -11.0, 5.0], "dist": 34, "az": -30, "el": 22},
            {"name": "office", "target": [-14.0, -13.6, 6.0], "dist": 22, "az": 10, "el": 12},
        ],
    }
