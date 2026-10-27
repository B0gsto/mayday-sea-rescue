"""M_Bld_WorkshopAddons: the Workshop's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

The Lv1 yard stays the code-built `workshopYard()` in src/shared/DockPieces.luau. This asset adds only what the two
levels add, at the code yard's final frame: 36 x 26 stud lot, ground at z 0, plinth top z 0.96 (the code plinth is
0.8 studs at 1x, scaled 1.2), front -Y (Roblox -Z), origin the yard's ground centre. Place at the yard frame with no
extra scale.

Lv2 (engine: 3 -> 5 builder slots): two workbenches against the west fence, each with a wall tool board; a covered
saw bench in the back-right corner under a red lean-to roof on yellow posts, with an open four-tier lumber rack on
its west side, coloured plank ends facing the yard. Walk in under the roof, stand at each bench; nothing loose on the floor (stock sits on
shelves, tools on the wall).

Lv3 (5 -> 8 builder slots): a half-built Lego boat hull (11 studs) on a two-beam cradle in the back-centre: keel, six
ribs, the bottom strake the whole length and the bow half planked up to a sheer that sweeps up at the bow; a small
timber A-frame hoist straddles the ends and lowers the next white strake over the open stern half. You can walk right round the hull; the A-frames only take the two ends.

Each level is a top-level node (Lv2, Lv3) holding 4-5 construction layers (L01_* bottom to L05_* top), one palette
mesh per layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). Collision is one <Node>_COL built
from separate convex boxes: posts, bench frames, rack and roof up high, hull in four bites, hoist legs in two
segments each, so the walkways and the space under the A-frames stay open.

    python3 art/source/buildings/M_Bld_WorkshopAddons/maketex.py \
        --out build/prod/M_Bld_WorkshopAddons/textures/M_Bld_WorkshopAddons --name WorkshopAddons --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_WorkshopAddons/build.py --out-root build/prod/M_Bld_WorkshopAddons \
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

NAME = "M_Bld_WorkshopAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "WorkshopAddons", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_WorkshopAddons_Brick_ALB.png")
FLOOR = 0.96                    # code yard plinth top (0.8 at 1x, scaled 1.2)
TOP = 3.70                      # workbench top

# west workbenches (x against the fence, y along it)
WB_X, WB_S, WB_N = (-18.40, -15.90), (1.10, 5.90), (7.40, 12.20)
# saw bench lean-to (back-right): the roof reaches 3.5 studs in front of the bench so the sawyer stands under cover
SB_X, SB_Y, SB_TOP = (11.10, 17.40), (8.50, 11.20), 3.65
SLOT = (9.55, 9.90)             # blade slot (y)
BLADE = (13.90, 3.65 + 0.05, 1.70)   # blade centre x, z and radius: the top half stands above the table
POST_X = (10.10, 17.60)
POST_ROWS = (6.40, 12.75)        # lean-to post rows (y), front / back: no middle row, the west side stays open
ROOF_X, ROOF_Y = (9.90, 18.50), (6.30, 13.55)
ROOF_Z0, ROOF_SLOPE = 7.20, 0.30   # roof underside at the front eave, rise per stud going back
RACK_X, RACK_Y = (7.25, 9.85), (9.40, 12.60)    # rack on the open west side, plank ends facing the yard (-Y)
# boat (Lv3): hull x -5.5..5.5, centreline y HC, gunwale z 6.0; hoist frames x +-6.3
HC = 10.20
AFRAME_X, APEX_Z = 6.30, 11.90
TAPER = ((2.0, 2.40), (3.0, 2.10), (4.0, 1.50), (4.8, 0.90), (5.4, 0.40))   # hull half-beam over the bow 3.4 studs
STRAKES = ((3.05, 4.10), (4.10, 5.10), (5.10, 5.70))                              # plank courses (z0, z1)
STEPS = ((1.0, 3.30, 4.25), (0.6, 4.15, 5.15), (0.2, 5.00, 5.70))           # U section: (inset, z0, z1) per step
SHEER = 0.80                    # the gunwale sweeps up two plates over the bow taper
HOOK_X = -2.60                  # hoist trolley over the open stern half


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


def disc_y(b, cx, cy, cz, r, length, c, n=12):
    """A closed cylinder lying along Y (saw blade, thin in Y, disc in XZ)."""
    y0, y1 = cy - length / 2, cy + length / 2
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


# ------------------------------------------------------------------ Lv2 kit
def workbench(b, x0, x1, y0, y1, top=TOP, shelf=True):
    """A chunky bench: four dark legs, a tan studded top and a low shelf (nothing on the floor)."""
    for x in (x0 + 0.20, x1 - 0.70):
        for y in (y0 + 0.20, y1 - 0.70):
            b.box((x, y, FLOOR), (x + 0.50, y + 0.50, top - 0.40), P.DBG)
    b.box((x0, y0, top - 0.40), (x1, y1, top), P.TAN, bevel=0.08)
    b.studs(x0 + 0.35, x1 - 0.35, y0 + 0.40, y1 - 0.40, top, P.TAN, step=1.0, r=0.38, h=0.26)
    if shelf:
        b.box((x0 + 0.15, y0 + 0.30, 1.55), (x1 - 0.15, y1 - 0.30, 1.90), P.DBG, bevel=0.05)


FACE = -18.42                   # west tool boards: panel front face (x)


def tool(b, kind, y, z):
    """One hung tool on a board over a coloured outline of the same shape (face = FACE)."""
    o = 0.12
    if kind == "hammer":
        parts = (((-0.18, 0.18), (0.0, 1.45), P.BROWN), ((-0.36, 0.36), (1.20, 1.70), P.DBG))
        col = P.RED
    elif kind == "wrench":
        parts = (((-0.16, 0.16), (0.0, 1.50), P.LBG), ((-0.34, 0.34), (1.25, 1.75), P.LBG))
        col = P.GREEN
    else:  # saw
        parts = (((-0.45, 0.45), (0.45, 1.60), P.LBG), ((-0.20, 0.20), (0.0, 0.50), P.YELLOW))
        col = P.BLUE
    for (y0, y1), (z0, z1), _ in parts:
        b.box((FACE, y + y0 - o, z + z0 - o), (FACE + 0.04, y + y1 + o, z + z1 + o), col)
    for (y0, y1), (z0, z1), c in parts:
        b.box((FACE + 0.04, y + y0, z + z0), (FACE + 0.30, y + y1, z + z1), c)


def toolboard(b, y0, y1, kinds):
    """A tan pegboard in a dark frame on the west fence; the frame's side posts run down to the bench top."""
    b.box((FACE - 0.30, y0, 4.60), (FACE, y1, 7.50), P.TAN)
    for ya, yb, za, zb in ((y0, y0 + 0.30, TOP, 7.50), (y1 - 0.30, y1, TOP, 7.50),
                           (y0, y1, 4.60, 4.90), (y0, y1, 7.20, 7.50)):
        b.box((FACE - 0.34, ya, za), (FACE + 0.06, yb, zb), P.DBG, bevel=0.04)
    step = (y1 - y0 - 0.60) / len(kinds)
    for i, kind in enumerate(kinds):
        tool(b, kind, y0 + 0.30 + (i + 0.5) * step, 5.10)


def saw_bench(b):
    """The table saw: split tan top (studs), dark frame, an upright light-grey blade through the slot with a red
    guard above it, and a plank being ripped along the yellow fence."""
    x0, x1 = SB_X
    y0, y1 = SB_Y
    top = SB_TOP
    for x in (x0 + 0.50, x1 - 1.10):
        for y in (y0 + 0.40, y1 - 1.00):
            b.box((x, y, FLOOR), (x + 0.60, y + 0.60, top - 0.50), P.DBG)
    b.box((x0, y0, top - 0.50), (x1, SLOT[0], top), P.TAN, bevel=0.07)       # front slab
    b.box((x0, SLOT[1], top - 0.50), (x1, y1, top), P.TAN, bevel=0.07)      # back slab (blade slot between)
    b.stud_row(x0 + 0.6, 8.88, x1 - 0.6, 8.88, top, P.TAN, spacing=1.1, r=0.30, h=0.26)
    b.stud_row(x0 + 0.6, 10.95, x1 - 0.6, 10.95, top, P.TAN, spacing=1.1, r=0.22, h=0.26)
    b.box((x0 + 0.30, y0 + 0.35, 1.50), (x1 - 0.30, y1 - 0.35, 1.85), P.DBG, bevel=0.05)
    for i in range(2):                                                        # board stack on the shelf
        b.box((15.85, 8.95 + 0.1 * i, 1.85 + i * 0.42), (17.05, 10.75, 2.27 + i * 0.42),
              (P.TAN, P.BROWN)[i], bevel=0.04)
    b.box((12.25, 9.30, 1.85), (15.65, 10.15, 3.15), P.DBG, bevel=0.05)       # saw housing hides the blade's foot
    bx, bz, r = BLADE
    yc = (SLOT[0] + SLOT[1]) / 2
    disc_y(b, bx, yc, bz, r, 0.20, P.DBG, 20)                                 # dark rim (the tooth line)
    disc_y(b, bx, yc, bz, r - 0.28, 0.28, P.LBG, 20)                          # light silver blade face
    disc_y(b, bx, yc, bz, 0.34, 0.36, P.DBG, 8)                               # arbor
    kx = bx + r + 0.05                                                        # riving knife just behind the blade
    b.box((kx, yc - 0.12, top), (kx + 0.30, yc + 0.12, top + r + 0.30), P.LBG)
    b.box((bx - 1.00, yc - 0.30, top + r + 0.20), (kx + 0.30, yc + 0.30, top + r + 0.55), P.RED, bevel=0.06)  # guard
    p0, p1 = yc - 0.50, yc + 0.50                                             # the plank: whole before, ripped after
    b.box((11.90, p0, top), (bx, p1, top + 0.35), P.RIB, bevel=0.04)
    b.box((bx, p0, top), (16.00, yc - 0.17, top + 0.35), P.RIB, bevel=0.04)
    b.box((bx, yc + 0.17, top), (16.00, p1, top + 0.35), P.RIB, bevel=0.04)
    b.box((11.40, 10.35, top), (17.20, 10.65, top + 0.50), P.YELLOW, bevel=0.05)   # rip fence


def lumber_rack(b):
    """Open four-tier rack on the lean-to's open west side: planks run front to back, coloured ends face the yard."""
    x0, x1 = RACK_X
    y0, y1 = RACK_Y
    zs = (1.40, 2.75, 4.10, 5.45)
    for x in (x0, x1 - 0.40):
        for y in (y0, y1 - 0.40):
            b.box((x, y, FLOOR), (x + 0.40, y + 0.40, 6.70), P.DBG)
    for z in zs:
        b.box((x0, y0, z), (x1, y1, z + 0.30), P.DBG, bevel=0.04)
    b.box((x0, y0, 6.70), (x1, y1, 7.00), P.DBG, bevel=0.05)
    cols = (P.RED, P.WHITE, P.RIB, P.TAN, P.BLUE, P.YELLOW)                   # boat stock: the ends face the yard
    w = (x1 - x0 - 0.90) / 3
    for i, z in enumerate(zs):
        for k in range(2):
            for j in range(3):
                xa = x0 + 0.45 + j * w
                b.box((xa + 0.04, y0 - 0.25 + 0.12 * ((i + j + k) % 2), z + 0.30 + 0.45 * k),
                      (xa + w - 0.04, y1 - 0.30, z + 0.73 + 0.45 * k), cols[(2 * i + 3 * k + j) % 6], bevel=0.04)


def zr(y):
    """Lean-to roof underside height at y."""
    return ROOF_Z0 + (y - ROOF_Y[0]) * ROOF_SLOPE


def lean_to_posts(b):
    """Bright yellow posts in three rows and the ties at the front and back eaves (roof is the next layer)."""
    for y in POST_ROWS:
        for x in POST_X:
            b.box((x, y, FLOOR), (x + 0.80, y + 0.80, zr(y + 0.80)), P.YELLOW, bevel=0.06)
    for y in POST_ROWS:
        b.box((9.95, y, zr(y + 0.80) - 0.45), (18.45, y + 0.80, zr(y + 0.80)), P.YELLOW, bevel=0.05)


def lean_to_roof(b):
    """Red lean-to roof slab, low at the front eave, high at the back fence, with stepped courses."""
    y0, y1 = ROOF_Y
    b.prof_x(ROOF_X[0], ROOF_X[1], [(y0, zr(y0)), (y1, zr(y1)), (y1, zr(y1) + 0.50), (y0, zr(y0) + 0.50)], P.RED)
    for y in (7.50, 9.20, 10.90, 12.60):
        z = zr(y) + 0.50
        b.box((ROOF_X[0] + 0.05, y - 0.35, z - 0.12), (ROOF_X[1] - 0.05, y + 0.35, z + 0.12), P.RED, bevel=0.03)


# ------------------------------------------------------------------ Lv3 kit
def hw(x):
    """Hull half-beam at x: full amidships, tapering over the bow."""
    if x <= TAPER[0][0]:
        return TAPER[0][1]
    for (xa, wa), (xb, wb) in zip(TAPER, TAPER[1:]):
        if x <= xb:
            return wa + (wb - wa) * (x - xa) / (xb - xa)
    return TAPER[-1][1]


def edge(x, i):
    """Outer edge (half-beam) of the rib on step i at x; the U insets shrink with the beam."""
    return hw(x) - STEPS[i][0] * hw(x) / TAPER[0][1]


def cradle(b):
    """Two skids, two cross beams and the keel spine: the hull rests 1.5 studs over the yard floor."""
    for y in (HC - 2.80, HC + 2.05):
        b.box((-5.00, y, FLOOR), (5.00, y + 0.75, 1.50), P.BROWN, bevel=0.06)
    for x in (-3.90, 3.10):
        b.box((x, HC - 2.90, 1.50), (x + 0.80, HC + 2.85, 2.10), P.BROWN, bevel=0.06)
    b.box((-5.40, HC - 0.38, 2.10), (5.10, HC + 0.38, 3.00), P.RIB, bevel=0.07)   # keel spine


def sh(x):
    """Sheer rise at x: flat amidships, sweeping up SHEER over the bow taper."""
    return SHEER * (max(x - TAPER[0][0], 0.0) / (TAPER[-1][0] - TAPER[0][0])) ** 2


def ribs(b):
    """Six U ribs on the keel: a floor arm, then a raked side frame that stops flush under the gunwale."""
    for x in (-4.50, -2.70, -0.90, 0.90, 2.70, 4.50):
        o0, o2 = edge(x, 0), edge(x, 2)
        b.box((x - 0.24, HC - o0, 2.90), (x + 0.24, HC + o0, 3.30), P.RIB)
        for s in (-1, 1):
            b.beam((x, HC + s * (o0 - 0.20), 3.05), (x, HC + s * (o2 - 0.20), 5.65 + sh(x)), 0.48, 0.40, P.RIB)


def strake(b, i, x0, colour):
    """One plank course along step i from x0 to the stem on both sides; the top course follows the sheer."""
    z0, z1 = STRAKES[i]
    lift = sh if i == 2 else (lambda x: 0.0)
    pts = [x0] + [t[0] for t in TAPER if t[0] > x0]
    for s in (-1, 1):
        for xa, xb in zip(pts, pts[1:]):
            slab(b, xa, xb, HC + s * (edge(xa, i) + 0.20), HC + s * (edge(xb, i) + 0.20),
                 (z0, z1 + lift(xa)), (z0, z1 + lift(xb)), 0.40, colour)


def planking(b):
    """Bottom strake (red) the whole length, then the bow half finished white / red up to a sheer that sweeps up
    at the bow; a flat trapezoid transom, gunwales and the stem post one stud over the sheer."""
    strake(b, 0, -5.75, P.RED)
    strake(b, 1, 0.30, P.WHITE)
    strake(b, 2, 0.30, P.RED)
    o0, o2 = edge(-5.0, 0), edge(-5.0, 2)                                     # transom: one board on the rib line
    b.prof_x(-5.75, -5.35, [(HC - o0, 3.05), (HC + o0, 3.05), (HC + o2, 5.65), (HC - o2, 5.65)], P.RIB)
    b.box((-5.85, HC - 2.55, 5.65), (-5.25, HC + 2.55, 6.00), P.RED, bevel=0.05)   # transom cap
    pts = [-5.50] + [t[0] for t in TAPER]
    for s in (-1, 1):                                                         # gunwales follow outline + sheer
        for xa, xb in zip(pts, pts[1:]):
            slab(b, xa, xb, HC + s * (edge(xa, 2) + 0.05), HC + s * (edge(xb, 2) + 0.05),
                 (5.65 + sh(xa), 6.00 + sh(xa)), (5.65 + sh(xb), 6.00 + sh(xb)), 0.55, P.RIB)
    b.beam((4.90, HC, 2.60), (5.70, HC, 7.00 + SHEER), 0.55, 0.50, P.RIB)    # stem post, 1 stud over the sheer


def hoist(b):
    """Timber A-frame gantry over the hull ends, studded yellow ridge beam; a red trolley block over the open stern
    half lowers the next white strake on a rope and two slings."""
    for x in (-AFRAME_X, AFRAME_X):
        for y in (7.40, 13.00):
            b.beam((x, y, FLOOR), (x, 10.20, APEX_Z), 0.55, 0.50, P.BROWN)
        b.beam((x, 8.60, 5.40), (x, 11.80, 5.40), 0.40, 0.40, P.BROWN)       # the A tie
    b.beam((-AFRAME_X - 0.30, 10.20, APEX_Z - 0.15), (AFRAME_X + 0.30, 10.20, APEX_Z - 0.15),
           0.70, 0.60, P.YELLOW)                                              # ridge
    b.stud_row(-AFRAME_X, 10.20, AFRAME_X, 10.20, APEX_Z + 0.15, P.YELLOW, spacing=1.0, r=0.25, h=0.26)
    h = HOOK_X
    b.box((h - 0.50, 9.85, 10.70), (h + 0.50, 10.55, 11.60), P.RED, bevel=0.05)   # trolley pulley block
    b.box((h - 0.10, 10.10, 9.10), (h + 0.10, 10.30, 10.70), P.BLACK)             # rope
    b.box((h - 0.28, 9.92, 8.50), (h + 0.28, 10.48, 9.10), P.DBG, bevel=0.04)     # hook block
    b.box((h - 0.10, 9.95, 8.15), (h + 0.10, 10.45, 8.50), P.DBG)                 # hook
    p0, p1, pz = -5.00, -0.20, (6.75, 7.75)                                       # the next strake, lowered in
    b.box((p0, HC - 0.20, pz[0]), (p1, HC + 0.20, pz[1]), P.WHITE, bevel=0.05)
    for xe in (p0 + 0.60, p1 - 0.60):                                             # slings: hook to both ends
        b.beam((h, HC, 8.20), (xe, HC, pz[1] - 0.05), 0.14, 0.14, P.BLACK)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_WorkshopAddons_Brick", ALB)
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
        print("[workshop] %-26s %5d tris" % (name, b.tris()))

    # ================================================================ Lv2: 2 workbenches + saw bench lean-to
    b = lego.B()
    workbench(b, *WB_X, *WB_S)
    workbench(b, *WB_X, *WB_N)
    toolboard(b, 1.60, 5.40, ("hammer", "wrench", "saw"))
    toolboard(b, 7.90, 11.70, ("saw", "hammer", "wrench"))
    b.box((-17.55, 4.95, TOP), (-16.75, 5.75, TOP + 0.70), P.DBG, bevel=0.04)     # vice body
    b.box((-17.95, 5.25, TOP + 0.28), (-16.35, 5.45, TOP + 0.48), P.RED, bevel=0.03)  # vice handle
    b.box((-17.60, 7.70, TOP), (-16.20, 8.90, TOP + 1.10), P.RED, bevel=0.06)     # bench B toolbox ...
    b.box((-17.40, 7.70, TOP + 1.10), (-17.00, 8.90, TOP + 1.24), P.WHITE, bevel=0.03)  # ... with a pale handle
    b.box((-18.05, 9.90, TOP), (-16.10, 10.30, TOP + 0.24), P.BROWN, bevel=0.03)  # a board on the top
    out("Lv2_L01_Workbenches", b, "Lv2")

    b = lego.B()
    saw_bench(b)
    out("Lv2_L02_SawBench", b, "Lv2")

    b = lego.B()
    lumber_rack(b)
    out("Lv2_L03_LumberRack", b, "Lv2")

    b = lego.B()
    lean_to_posts(b)
    out("Lv2_L04_LeanToPosts", b, "Lv2")

    b = lego.B()
    lean_to_roof(b)
    out("Lv2_L05_Roof", b, "Lv2")

    c = lego.B()
    c.box((-18.40, 1.10, FLOOR), (-15.90, 5.90, TOP), P.TAN)                      # bench A frame
    c.box((-18.40, 7.40, FLOOR), (-15.90, 12.20, TOP), P.TAN)                     # bench B frame
    c.box((SB_X[0], SB_Y[0], FLOOR), (SB_X[1], SB_Y[1], SB_TOP), P.TAN)           # saw bench
    c.box((BLADE[0] - 1.00, SLOT[0], SB_TOP), (BLADE[0] + BLADE[2] + 0.35, SLOT[1], SB_TOP + BLADE[2] + 0.55),
          P.DBG)                                                                    # blade + guard
    for y in POST_ROWS:
        for x in POST_X:
            c.box((x, y, FLOOR), (x + 0.80, y + 0.80, zr(y + 0.80)), P.YELLOW)
    c.box((ROOF_X[0], ROOF_Y[0], zr(ROOF_Y[0])), (ROOF_X[1], ROOF_Y[1], zr(ROOF_Y[1]) + 0.55), P.RED)  # roof (overhead)
    c.box((RACK_X[0], RACK_Y[0] - 0.25, FLOOR), (RACK_X[1], RACK_Y[1], 7.00), P.DBG)   # lumber rack
    out("Lv2_COL", c, "Lv2")

    # ================================================================ Lv3: half-built boat + A-frame hoist
    b = lego.B()
    cradle(b)
    out("Lv3_L01_Cradle", b, "Lv3")

    b = lego.B()
    ribs(b)
    out("Lv3_L02_Ribs", b, "Lv3")

    b = lego.B()
    planking(b)
    out("Lv3_L03_Planks", b, "Lv3")

    b = lego.B()
    hoist(b)
    out("Lv3_L04_Hoist", b, "Lv3")

    c = lego.B()
    for x0, x1, h, z1 in ((-5.95, -1.80, 2.65, 6.0), (-1.80, 1.80, 2.65, 6.0), (1.80, 3.40, 2.30, 6.2),
                          (3.40, 5.95, 1.00, 6.8)):
        c.box((x0, HC - h, FLOOR), (x1, HC + h, z1), P.BROWN)                     # hull in four bites (bow narrows)
    for x in (-AFRAME_X - 0.30, AFRAME_X - 0.25):
        for ya, yb, z1 in ((7.10, 8.60, 6.50), (8.60, 10.20, 12.20),
                           (11.80, 13.30, 6.50), (10.20, 11.80, 12.20)):
            c.box((x, ya, FLOOR), (x + 0.55, yb, z1), P.BROWN)                    # hoist legs, two bites
    c.box((-AFRAME_X - 0.60, 9.85, 11.30), (AFRAME_X + 0.60, 10.55, 12.30), P.DBG)  # ridge (overhead)
    out("Lv3_COL", c, "Lv3")

    # ================================================================ attachments (feet on the yard plinth)
    for name, loc in (("ATT_Work_Bench2", (-15.25, 3.60, FLOOR)),
                      ("ATT_Work_Bench3", (-15.25, 9.90, FLOOR)),
                      ("ATT_Work_SawBench", (14.20, 7.85, FLOOR)),
                      ("ATT_Work_BoatFrame", (0.00, 7.00, FLOOR))):
        lego.attach(name, loc)

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[workshop] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": (12.42, 4.17, 3.78), "origin": "free", "tiling": True,
        "size_note": "add-ons only, sitting on the code yard's plinth (z 0.96) inside its 36 x 26 lot; the bbox is "
                     "the occupied west benches, back-right lean-to and back-centre boat, not the whole lot",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 J): Lv2_L01_..., Lv3_L01_..., Lv2_COL, Lv3_COL; the FBX "
                      "importer flattens empty parents, so the node name is the mesh name prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "closeups": [
            {"name": "saw_bench", "target": [14.2, 9.8, 4.6], "dist": 14, "az": 8, "el": 8},
            {"name": "workbenches", "target": [-16.8, 6.5, 3.6], "dist": 18, "az": 70, "el": 10},
            {"name": "boat_frame", "target": [0.0, 10.2, 5.2], "dist": 22, "az": 32, "el": 12},
        ],
    }
