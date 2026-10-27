"""M_Bld_SubPenAddons: the Sub Pen's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

The Lv1 sub pen stays the code-built `subPen()` in src/shared/DockPieces.luau: 38 x 38 plinth (top z 0.80), 30 x 30 grey
deck (top z 1.20), the 16-stud pool (water z 1.75), the grey/yellow gantry (beams z 16) and the domed shell. This asset
adds only what the two levels add, in the pen's final frame: origin the pen's ground centre, front -Y (seaward), 1x.

Lv2 Gantry: a yellow brick cantilever gantry on the east rim (hazard-striped footings, black brick seams, an 8-stud lane
between the legs), jib over the pool edge with a red winch (visible drum), a thick black cable to a red hook block and
two straight straps holding an 8.5-stud yellow mini-sub (portholes, red fin) in free air, and a dive-gear rack against
a navy wall with a red studded cap on the east rim just north of the gantry (air tanks, bench, fins, masks; seams, a red
band and a diver-down flag on its back).

Lv3 Salvage: behind the plinth (+Y; built east, turned by lv3_xf), a walled wet dock (dark brick, light coping,
studs, bollards, water) with a walk-on tan pontoon: open coin crate and spilled hoard, closed crate with gold bars,
gold ship's wheel, big gold anchor, sorting table, red salvage crane with a hanging crate, a red crate with gold trim under a gold anchor, and a navy flag board with
the diver-down flag and a gold anchor icon.

Each level is a top-level node (Lv2, Lv3) holding 4-6 construction layers (L01_* bottom to L06_* top), one palette mesh
per layer (flat colours via UVs, one draw call per layer). Collision is `<Node>_ColNN_COL`, one convex box per object,
so the pen deck, the stair, the brow, the pontoon lane (7 studs) and the rim stay open.

    python3 art/source/buildings/M_Bld_SubPenAddons/maketex.py \
        --out build/prod/M_Bld_SubPenAddons/textures/M_Bld_SubPenAddons --name SubPen --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_SubPenAddons/build.py --out-root build/prod/M_Bld_SubPenAddons \
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

NAME = "M_Bld_SubPenAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "SubPen", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_SubPen_Brick_ALB.png")
FLOOR = 0.80                    # code plinth top
DECK = 1.20                     # code deck top

# Lv2 gantry on the east rim (plinth x 15..19)
GX, GY = 16.90, 5.60            # leg centre x / +-y
PAD_Z, PLATE_Z = 1.05, 1.75
LEG_Z0 = PLATE_Z + 0.45
BEAM_Z0, BEAM_Z1 = 12.80, 14.20
JIB_Z0, JIB_Z1 = 12.90, 14.00
JIB_X0, JIB_X1 = 4.70, 17.65
# mini-sub hanging in front of the jib tip, centred over the pool (inside r 8): built in its own frame (SUB_X, hull
# centre y 0.2, z 7.15), then scaled SUB_S and moved to (XS, 0, SUB_ZC) by sub_xf
XS = 3.95
SUB_X, SUB_S, SUB_ZC = 5.40, 1.1, 5.87
SUP_Z0, SUP_Z1 = 6.00, 8.20
HOOK_Z0, HOOK_Z1 = 10.00, 11.30
LUG_Y = (-2.00, 2.30)           # strap lugs on the hull top, sub frame
# dive rack wall: built on a west-rim frame, then mirrored onto the east rim north of the gantry by rack_xf
WX0, WX1 = -18.60, -17.40
WY0, WY1 = -5.40, 5.40
WALL_Z1, WCOPE_Z1 = 8.20, 8.65
RACK_DY = 13.40
# Lv3 salvage wet dock, built east of the pen, then turned onto the back (+Y) by lv3_xf: east it ran 3 studs onto
# the cove walk (island right 48..56); behind the pen it lands on island right 78..102, fwd 91..107, off every lot
BX0, BX1 = 20.90, 37.10
BY0, BY1 = -12.10, 12.10
IX0, IX1 = 22.00, 36.00
IY0, IY1 = -11.00, 11.00
CURB_Z1, COPE_Z1 = 1.35, 1.45
GAP_Y0, GAP_Y1 = -1.90, 1.90
WATER_Z1 = 1.10
PBX0, PBX1 = 22.60, 34.40
PBY0, PBY1 = -9.80, 9.80
PDECK = 1.50
LOW = 1.50                      # pontoon / top step


def patch_lod_names():
    """Layer meshes use game node names (Lv2_L01_..., Lv3_L01_...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def keep_faces(b, keep):
    """Keep only these faces of the box just emitted (lego.B.box order: bottom, top, -Y, +X, +Y, -X)."""
    last = b.f[-6:]
    b.f[-6:] = [last[i] for i in keep]


SEAM = 0.07
BRICK = 4.0


def seams_y(b, x, face, y0, y1, z0, z1, courses=3, sd=SEAM, st=SEAM, c=P.BLACK):
    """Brick seams on a wall face at x (face = -1 / +1 outward normal), staggered joints every BRICK; sd deep, st wide."""
    h = (z1 - z0) / courses
    xa, xb = (x - sd, x) if face < 0 else (x, x + sd)
    keep = (2, 4, 3 if face > 0 else 5)
    for i in range(1, courses):
        b.box((xa, y0, z0 + i * h - st / 2), (xb, y1, z0 + i * h + st / 2), c, bevel=0.0)
        keep_faces(b, keep)
    for i in range(courses):
        y = y0 + (BRICK / 2 if i % 2 else BRICK)
        while y < y1 - 0.3:
            b.box((xa, y - st / 2, z0 + i * h), (xb, y + st / 2, z0 + (i + 1) * h), c, bevel=0.0)
            keep_faces(b, keep)
            y += BRICK


def seams_x(b, y, face, x0, x1, z0, z1, courses=3, sd=SEAM, st=SEAM, c=P.BLACK):
    h = (z1 - z0) / courses
    ya, yb = (y - sd, y) if face < 0 else (y, y + sd)
    keep = (3, 5, 4 if face > 0 else 2)
    for i in range(1, courses):
        b.box((x0, ya, z0 + i * h - st / 2), (x1, yb, z0 + i * h + st / 2), c, bevel=0.0)
        keep_faces(b, keep)
    for i in range(courses):
        x = x0 + (BRICK / 2 if i % 2 else BRICK)
        while x < x1 - 0.3:
            b.box((x - st / 2, ya, z0 + i * h), (x + st / 2, yb, z0 + (i + 1) * h), c, bevel=0.0)
            keep_faces(b, keep)
            x += BRICK


def hazard(b, axis, c0, sign, u0, u1, z0, z1, w=0.4, depth=0.06, c=P.BLACK):
    """Slanted black hazard stripes on a yellow plate face (axis 'y': face at y = c0, runs along x; 'x': at x = c0,
    runs along y); sign is the outward direction. Only whole parallelograms, so the plate ends stay yellow."""
    s = 0.5 * (z1 - z0)
    u = u0 + 0.1
    while u + w + s <= u1 - 0.1 + 1e-6:
        prof = [(u, z0), (u + w, z0), (u + w + s, z1), (u + s, z1)]
        c1 = c0 + sign * depth
        if axis == "y":
            prism_y(b, min(c0, c1), max(c0, c1), prof, c)
        else:
            b.prof_x(min(c0, c1), max(c0, c1), prof, c)
        u += 2 * w


def xform(b, i0, fn):
    """Moves every vertex emitted since index i0 through fn(x, y, z) -> (x, y, z)."""
    b.v[i0:] = [fn(*p) for p in b.v[i0:]]


def sub_xf(x, y, z):
    s = SUB_S
    return (XS + s * (x - SUB_X), s * (y - 0.2), SUB_ZC + s * (z - 7.15))


def rack_xf(x, y, z):
    return (-x, y + RACK_DY, z)


def lv3_xf(x, y, z):
    return (-y, x, z)


def disc_y(b, cx, cy, cz, r, length, c, n=10):
    """A closed cylinder lying along Y."""
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


def anchor(b, gx, y0, y1, zb, k, c=None):
    """A flat anchor icon facing -Y: square ring, stem, stock bar, a U base with two flukes. Centre x gx, base z zb, scale
    k (1 = 2.9 wide, 2.55 tall), slab y0..y1."""
    c = c if c is not None else P.GOLD

    def bx(x0, x1, z0, z1):
        b.box((gx + k * x0, y0, zb + k * z0), (gx + k * x1, y1, zb + k * z1), c, bevel=0.0)

    for x0, x1, z0, z1 in ((-0.40, -0.18, 1.75, 2.55), (0.18, 0.40, 1.75, 2.55), (-0.40, 0.40, 2.33, 2.55),
                           (-0.18, 0.18, 1.75, 1.97),                     # ring
                           (-0.17, 0.17, 0.20, 1.75),                     # stem
                           (-0.85, 0.85, 1.20, 1.50),                     # stock
                           (-1.00, 1.00, 0.00, 0.35),                     # U base
                           (-1.05, -0.75, 0.00, 0.85), (0.75, 1.05, 0.00, 0.85)):
        bx(x0, x1, z0, z1)
    for sx in (-1, 1):
        prism_y(b, y0, y1, [(gx + sx * k * 1.45, zb + k * 0.55), (gx + sx * k * 0.75, zb + k * 1.05),
                            (gx + sx * k * 0.75, zb + k * 0.55)], c)


def coin(b, x, y, z, r=0.90, c=None, h=0.32, n=10):
    b.cyl(x, y, z, z + h, r, c or P.GOLD, n=n)


# ------------------------------------------------------------------ Lv2 kit
def gantry(b):
    """Four yellow brick legs on dark footings on the east rim: a yellow hazard-striped plate with studs at each foot, a
    dark collar, black brick seams up the legs, side ties, a cross beam with brick seams and hazard-striped end plates,
    and a jib cantilevered over the pool (seams, studs, two braces)."""
    for sy in (-1, 1):
        cy = sy * GY
        b.box((15.30, cy - 1.60, FLOOR), (18.50, cy + 1.60, PAD_Z), P.DBG, bevel=0.08, bottom=False)
        b.box((15.45, cy - 1.45, PAD_Z), (18.35, cy + 1.45, PLATE_Z), P.YELLOW, bevel=0.06, bottom=False)
        hazard(b, "x", 15.45, -1, cy - 1.45, cy + 1.45, PAD_Z + 0.08, PLATE_Z - 0.08, w=0.36)
        hazard(b, "y", cy + sy * 1.45, sy, 15.45, 18.35, PAD_Z + 0.08, PLATE_Z - 0.08, w=0.36)
        for sx in (15.85, 17.95):
            b.stud_row(sx, cy - 1.0, sx, cy + 1.0, PLATE_Z, P.YELLOW, spacing=1.0, r=0.32, h=0.24, n=6)
        b.box((16.05, cy - 0.85, PLATE_Z), (17.75, cy + 0.85, LEG_Z0), P.DBG, bevel=0.04, bottom=False)
        b.box((16.15, cy - 0.75, LEG_Z0), (17.65, cy + 0.75, BEAM_Z0), P.YELLOW, bevel=0.06, bottom=False)
        for face in (-1, 1):
            seams_y(b, 16.15 if face < 0 else 17.65, face, cy - 0.75, cy + 0.75, LEG_Z0, BEAM_Z0, courses=5,
                    sd=0.12, st=0.20)
            seams_x(b, cy + sy * 0.75 * face, face, 16.15, 17.65, LEG_Z0, BEAM_Z0, courses=5, sd=0.12, st=0.20)
    for z0 in (5.60, 9.20):
        b.box((16.55, -GY, z0), (17.25, GY, z0 + 0.80), P.YELLOW, bevel=0.05, bottom=False)
        for y in (-3.6, 0.0, 3.6):
            b.cyl(GX, y, z0 + 0.80, z0 + 1.02, 0.28, P.YELLOW, n=6, bottom=False)
    for sy in (-1, 1):
        yp = sy * 6.60
        b.box((15.95, min(yp, yp + sy * 0.40), BEAM_Z0 - 0.10), (17.85, max(yp, yp + sy * 0.40), BEAM_Z1 + 0.10),
              P.YELLOW, bevel=0.04)
        hazard(b, "y", yp + sy * 0.40, sy, 15.95, 17.85, BEAM_Z0 - 0.02, BEAM_Z1 + 0.02, w=0.30)
    b.box((16.15, -6.60, BEAM_Z0), (17.65, 6.60, BEAM_Z1), P.YELLOW, bevel=0.06)
    seams_y(b, 16.15, -1, -6.60, 6.60, BEAM_Z0, BEAM_Z1, courses=2, sd=0.12, st=0.20)
    seams_y(b, 17.65, 1, -6.60, 6.60, BEAM_Z0, BEAM_Z1, courses=2, sd=0.12, st=0.20)
    for sy in (-1, 1):
        for y in (1.60, 3.60, 5.60):
            b.cyl(GX, sy * y, BEAM_Z1, BEAM_Z1 + 0.30, 0.42, P.YELLOW, n=6, bottom=False)
    b.box((JIB_X0, -0.85, JIB_Z0), (JIB_X1, 0.85, JIB_Z1), P.YELLOW, bevel=0.06)
    for face in (-1, 1):
        seams_x(b, face * 0.85, face, JIB_X0, JIB_X1, JIB_Z0, JIB_Z1, courses=1, sd=0.12, st=0.20)
    b.box((JIB_X0 + 0.20, -0.60, JIB_Z0 - 0.10), (JIB_X1 - 0.20, 0.60, JIB_Z0 + 0.02), P.DBG, bevel=0.03)
    b.box((JIB_X0, -0.95, JIB_Z0 - 0.10), (JIB_X0 + 0.30, 0.95, JIB_Z1 + 0.10), P.DBG, bevel=0.03)
    for sy in (-1, 1):
        for x in (6.20, 8.20, 10.20, 12.20, 14.20):
            b.cyl(x, sy * 0.55, JIB_Z1, JIB_Z1 + 0.26, 0.30, P.YELLOW, n=6, bottom=False)
        b.beam((GX, sy * 3.80, BEAM_Z1), (11.40, sy * 0.85, JIB_Z1 - 0.10), 0.35, 0.35, P.YELLOW)


def winch(b):
    """Red winch housing on the jib tip with a visible dark drum (light flanges) poking out of both sides, a thick black
    cable over a tip sheave and straight down to a red hook block with a dark shackle, and four black slings to the
    lifting lugs on the sub: the sub hangs in free air on them."""
    b.box((4.75, -1.10, JIB_Z1), (7.15, 1.10, JIB_Z1 + 0.20), P.DBG, bevel=0.03, bottom=False)
    b.box((4.90, -0.95, JIB_Z1 + 0.20), (6.85, 0.95, JIB_Z1 + 1.15), P.RED, bevel=0.06, bottom=False)
    for y in (-0.5, 0.5):
        b.cyl(5.9, y, JIB_Z1 + 1.10, JIB_Z1 + 1.32, 0.30, P.RED, n=6, bottom=False)
    dz = JIB_Z1 + 0.65
    disc_y(b, 5.875, 0.0, dz, 0.52, 2.50, P.LBG, n=10)
    for y in (-1.25, 1.25):
        disc_y(b, 5.875, y, dz, 0.68, 0.14, P.DBG, n=10)
    b.beam((5.30, 0.0, dz + 0.50), (XS, 0.0, JIB_Z1 + 0.45), 0.22, 0.22, P.BLACK)
    for y in (-0.55, 0.55):                                    # hanger plates on the jib tip, the cable runs between
        b.box((XS - 0.50, y - 0.07, JIB_Z0 + 0.10), (4.75, y + 0.07, JIB_Z1 + 0.90), P.YELLOW, bevel=0.02)
    disc_y(b, XS, 0.0, JIB_Z1 + 0.45, 0.45, 0.90, P.DBG, n=10)
    b.cyl(XS, 0.0, HOOK_Z1, JIB_Z1 + 0.45, 0.23, P.BLACK, n=8, bottom=False)
    b.box((XS - 0.60, -0.75, HOOK_Z0 + 0.30), (XS + 0.60, 0.75, HOOK_Z1), P.RED, bevel=0.08)
    disc_y(b, XS, 0.0, HOOK_Z1 - 0.45, 0.36, 1.62, P.DBG, n=8)
    b.box((XS - 0.35, -0.80, HOOK_Z0), (XS + 0.35, 0.80, HOOK_Z0 + 0.30), P.DBG, bevel=0.03)
    for ly in LUG_Y:                                           # two straight flat straps, block to lug
        _, y, z = sub_xf(SUB_X, ly, 8.65)
        b.beam((XS, math.copysign(0.62, y), HOOK_Z0 + 0.05), (XS, y, z - 0.05), 0.55, 0.14, P.DBG)


def minisub(b):
    """The hanging yellow mini-sub (8.5 studs long, no stand under it): a long rounded hull with a red nose dome, three
    round portholes a side, a red sail with navy windows and a dark periscope, a swept red tail fin, red stern planes and
    a dark propeller, two dark lugs on top for the straps. Built in the original frame, then sub_xf scales and moves
    it."""
    i0 = len(b.v)
    x = SUB_X

    def ring(y, w, zb, zt):
        h = zt - zb
        return [(x - 0.55 * w, y, zb), (x + 0.55 * w, y, zb), (x + w, y, zb + 0.32 * h),
                (x + w, y, zt - 0.32 * h), (x + 0.55 * w, y, zt), (x - 0.55 * w, y, zt),
                (x - w, y, zt - 0.32 * h), (x - w, y, zb + 0.32 * h)]

    b.loft([ring(-2.60, 0.90, 6.55, 8.05), ring(-3.15, 0.62, 6.80, 7.80), ring(-3.55, 0.26, 7.15, 7.45)], P.RED)
    b.loft([ring(-2.60, 0.90, 6.55, 8.05), ring(-1.60, 1.15, 6.05, 8.25),
            ring(0.60, 1.15, SUP_Z0, SUP_Z1), ring(2.40, 1.10, 6.10, 8.20),
            ring(3.30, 0.85, 6.35, 7.95), ring(3.95, 0.45, 6.85, 7.55)], P.YELLOW)
    b.box((x - 0.60, -0.90, SUP_Z1), (x + 0.60, 1.00, 9.55), P.RED, bevel=0.10)
    b.box((x - 0.66, -0.95, 9.55), (x + 0.66, 1.05, 9.75), P.DBG, bevel=0.04)
    b.box((x - 0.52, -0.96, 8.55), (x + 0.52, -0.90, 9.05), P.INK)
    for sx in (-1, 1):
        b.box((x + sx * 0.60, -0.60, 8.55), (x + sx * 0.66, 0.70, 9.05), P.INK)
    b.cyl(x - 0.22, 0.40, 9.75, 10.25, 0.14, P.DBG, n=8)
    b.box((x - 0.42, 0.15, 10.15), (x - 0.02, 0.65, 10.32), P.DBG, bevel=0.02)
    b.prof_x(x - 0.22, x + 0.22, [(2.45, 7.95), (3.80, 7.55), (4.05, 10.30), (3.40, 10.40)], P.RED)
    for sx in (-1, 1):
        for y in (-1.60, 0.00, 1.60):
            b.cyl_x(x + sx * 1.17, y, 7.12, 0.38, 0.14, P.LBG)
            b.cyl_x(x + sx * 1.22, y, 7.12, 0.25, 0.12, P.INK)
    for ly in LUG_Y:
        b.box((x - 0.45, ly - 0.25, 8.05), (x + 0.45, ly + 0.25, 8.65), P.DBG, bevel=0.04, bottom=False)
    for sx in (-1, 1):
        b.box((x + sx * 0.95, 3.35, 6.55), (x + sx * 1.50, 3.85, 7.00), P.RED, bevel=0.03)
    disc_y(b, x, 4.05, 7.10, 0.24, 0.35, P.DBG, n=8)
    for a in (90, 210, 330):
        r = math.radians(a)
        b.beam((x, 4.10, 7.10), (x + 0.60 * math.cos(r), 4.10, 7.10 + 0.60 * math.sin(r)), 0.24, 0.24, P.DBG)
    xform(b, i0, sub_xf)


def dive_rack(b):
    """Navy brick wall (red studded cap, a white board strip) with a tan bench, three air tanks, hanging fins and masks:
    gear you read at a glance from the deck. Built on the west rim, then mirrored onto the east rim north of the gantry
    by rack_xf; the gear faces the deck."""
    i0 = len(b.v)
    b.box((WX0 - 0.10, WY0 - 0.10, FLOOR), (WX1 + 0.10, WY1 + 0.10, FLOOR + 0.55), P.DBG, bevel=0.05, bottom=False)
    b.box((WX0, WY0, FLOOR + 0.55), (WX1, WY1, WALL_Z1), P.INK, bevel=0.06, bottom=False)
    for sy in (-1, 1):
        seams_x(b, sy * WY1, sy, WX0, WX1, FLOOR + 0.55, WALL_Z1)
    seams_y(b, WX1, +1, WY0, WY1, FLOOR + 0.55, WALL_Z1)
    seams_y(b, WX0, -1, WY0, WY1, FLOOR + 0.55, WALL_Z1)
    b.box((WX0 - 0.09, WY0 + 0.30, 3.00), (WX0 + 0.02, WY1 - 0.30, 3.60), P.RED, bevel=0.02)
    b.box((WX0 - 0.12, -1.70, 4.40), (WX0 + 0.02, 1.70, 7.20), P.RED, bevel=0.0)
    b.prof_x(WX0 - 0.15, WX0 - 0.11, [(-1.70, 4.40), (-1.15, 4.40), (1.70, 6.65), (1.70, 7.20), (1.15, 7.20),
                                      (-1.70, 4.95)], P.WHITE)
    b.box((WX1 - 0.02, WY0 + 0.30, 3.00), (WX1 + 0.09, WY1 - 0.30, 3.60), P.RED, bevel=0.02)
    b.box((WX0 - 0.15, WY0 - 0.15, WALL_Z1), (WX1 + 0.15, WY1 + 0.15, WCOPE_Z1), P.RED, bevel=0.04, bottom=False)
    b.studs(WX0 + 0.30, WX1 - 0.30, WY0 + 0.35, WY1 - 0.35, WCOPE_Z1, P.RED, step=1.80, r=0.40, h=0.32, n=6)
    b.box((WX0, WY0 + 0.30, WALL_Z1 - 0.45), (WX1 + 0.05, WY1 - 0.30, WALL_Z1 - 0.20), P.WHITE, bevel=0.02)
    for cy, col in ((-4.35, P.YELLOW), (-2.45, P.YELLOW), (-0.55, P.RED)):
        b.cyl(-16.45, cy, FLOOR, 1.05, 0.95, P.DBG, n=12, bottom=False)
        b.cyl(-16.45, cy, 1.05, 5.55, 0.85, col, n=12, bottom=False)
        b.cyl(-16.45, cy, 4.80, 5.05, 0.90, P.LBG, n=12, bottom=False)
        b.cyl(-16.45, cy, 5.55, 5.85, 0.34, P.DBG, n=10, bottom=False)
        b.box((-16.70, cy - 0.45, 5.85), (-16.20, cy + 0.45, 6.05), P.DBG, bevel=0.02)
    b.box((WX1, 0.80, 2.45), (WX1 + 1.30, 5.10, 2.80), P.TAN, bevel=0.05)
    for xx in (WX1 + 0.18, WX1 + 0.92):
        for y in (1.00, 4.80):
            b.box((xx, y, FLOOR), (xx + 0.32, y + 0.32, 2.45), P.DBG, bevel=0.02, bottom=False)
    b.box((WX1 + 0.10, 1.10, 1.55), (WX1 + 1.20, 4.80, 1.75), P.DBG, bevel=0.02)
    b.studs(WX1 + 0.35, WX1 + 1.00, 1.20, 4.70, 2.80, P.TAN, step=1.45, r=0.26, h=0.20, n=6)
    b.box((WX1 + 0.15, 1.35, 2.80), (WX1 + 1.10, 2.55, 3.55), P.RED, bevel=0.05, bottom=False)
    b.box((WX1 + 0.35, 1.70, 3.55), (WX1 + 0.90, 2.20, 3.65), P.WHITE, bevel=0.02, bottom=False)
    b.box((WX1 + 0.15, 3.10, 2.80), (WX1 + 1.10, 4.70, 2.95), P.DBG, bevel=0.02)
    for y in (3.20, 3.85, 4.50):
        b.box((WX1 + 0.22, y, 2.95), (WX1 + 1.00, y + 0.45, 3.30), P.YELLOW, bevel=0.03, bottom=False)
    for cy in (1.50, 3.05, 4.60):
        b.cyl(WX1 + 0.06, cy, 7.75, 7.95, 0.10, P.DBG, n=6)
        b.box((WX1 + 0.02, cy - 0.60, 7.10), (WX1 + 0.52, cy + 0.60, 7.90), P.RED, bevel=0.05)
        b.box((WX1 + 0.12, cy - 0.55, 4.05), (WX1 + 0.34, cy + 0.55, 7.10), P.INK, bevel=0.04)
        b.box((WX1 + 0.02, cy - 0.16, 4.05), (WX1 + 0.36, cy + 0.16, 7.40), P.INK, bevel=0.03)
        b.box((WX1 + 0.36, cy - 0.52, 7.60), (WX1 + 0.44, cy + 0.52, 7.85), P.DBG, bevel=0.01)
    for cy in (-4.35, -2.45):
        b.box((WX1 + 0.02, cy - 0.78, 6.30), (WX1 + 0.40, cy + 0.78, 7.55), P.INK, bevel=0.05)
        b.box((WX1 + 0.40, cy - 0.55, 6.50), (WX1 + 0.47, cy + 0.55, 7.35), P.GLASS, bevel=0.02)
        b.box((WX1 + 0.05, cy - 0.88, 6.70), (WX1 + 0.20, cy - 0.78, 7.20), P.LBG, bevel=0.01)
        b.box((WX1 + 0.05, cy + 0.78, 6.70), (WX1 + 0.20, cy + 0.88, 7.20), P.LBG, bevel=0.01)
    b.cyl(WX1 + 0.16, -1.55, 6.20, 8.05, 0.10, P.YELLOW, n=6)
    b.box((WX1 + 0.16, -2.10, 7.55), (WX1 + 0.36, -1.55, 8.15), P.YELLOW, bevel=0.03)
    xform(b, i0, rack_xf)


# ------------------------------------------------------------------ Lv3 kit
def basin(b):
    """Walled wet dock east of the lot: dark brick walls, light coping with a yellow inner edge, studs, corner
    bollards and water. The west wall is cut where the stair arrives from the pen plinth."""
    b.box((IX0, IY0, 0.55), (IX1, IY1, WATER_Z1), P.BLUE, bevel=0.03)
    walls = (
        (BX0, BX1, BY0, IY0),
        (BX0, BX1, IY1, BY1),
        (IX1, BX1, BY0, BY1),
        (BX0, IX0, BY0, GAP_Y0),
        (BX0, IX0, GAP_Y1, BY1),
    )
    for x0, x1, y0, y1 in walls:
        b.box((x0, y0, 0.0), (x1, y1, CURB_Z1), P.DBG, bevel=0.06)
        b.box((x0 - 0.06, y0 - 0.06, CURB_Z1), (x1 + 0.06, y1 + 0.06, COPE_Z1), P.LBG, bevel=0.04)
    seams_x(b, BY0, -1, BX0, BX1, 0.0, CURB_Z1, courses=2)
    seams_x(b, BY1, +1, BX0, BX1, 0.0, CURB_Z1, courses=2)
    seams_y(b, BX1, +1, BY0, BY1, 0.0, CURB_Z1, courses=2)
    seams_y(b, BX0, -1, BY0, GAP_Y0, 0.0, CURB_Z1, courses=2)
    seams_y(b, BX0, -1, GAP_Y1, BY1, 0.0, CURB_Z1, courses=2)
    edges = ((IX1 - 0.02, IX1 + 0.18, IY0 - 0.02, IY1 + 0.02),
             (IX0, IX1, IY0 - 0.18, IY0 + 0.02), (IX0, IX1, IY1 - 0.02, IY1 + 0.18),
             (IX0 - 0.18, IX0 + 0.02, IY0 - 0.02, GAP_Y0), (IX0 - 0.18, IX0 + 0.02, GAP_Y1, IY1 + 0.02))
    for x0, x1, y0, y1 in edges:
        b.box((x0, y0, COPE_Z1), (x1, y1, COPE_Z1 + 0.08), P.YELLOW, bevel=0.0)
    b.stud_row(21.50, -10.70, 21.50, -2.35, COPE_Z1, P.LBG, spacing=2.2, r=0.34, h=0.26)
    b.stud_row(21.50, 2.35, 21.50, 10.70, COPE_Z1, P.LBG, spacing=2.2, r=0.34, h=0.26)
    b.stud_row(36.50, -10.70, 36.50, 10.70, COPE_Z1, P.LBG, spacing=2.2, r=0.34, h=0.26)
    b.stud_row(21.50, -11.50, 36.50, -11.50, COPE_Z1, P.LBG, spacing=2.2, r=0.34, h=0.26)
    b.stud_row(21.50, 11.50, 36.50, 11.50, COPE_Z1, P.LBG, spacing=2.2, r=0.34, h=0.26)
    for x, y in ((21.50, -11.50), (36.50, -11.50), (21.50, 11.50), (36.50, 11.50)):
        b.cyl(x, y, COPE_Z1, COPE_Z1 + 0.75, 0.32, P.ORANGE, n=8, bottom=False)
        b.cyl(x, y, COPE_Z1 + 0.75, COPE_Z1 + 0.95, 0.42, P.BLACK, n=8)


def pontoon(b):
    """Three tan treads up from the plinth, the walk-on pontoon, its navy edge trim and studs, two cleats with
    mooring ropes to the corner bollards, black tyre fenders and two grey float drums."""
    for x0, x1, top in ((18.60, 19.80, 1.00), (19.80, 21.00, 1.25), (21.00, 22.80, LOW)):
        b.box((x0, -1.70, 0.0), (x1, 1.70, top), P.TAN, bevel=0.05)
        b.box((x0, -1.70, top - 0.10), (x0 + 0.18, 1.70, top + 0.04), P.YELLOW, bevel=0.0)
    b.box((PBX0 + 0.15, PBY0 + 0.15, 0.55), (PBX1 - 0.15, PBY1 - 0.15, 1.05), P.DBG, bevel=0.05)
    b.box((PBX0, PBY0, 1.05), (PBX1, PBY1, PDECK), P.TAN, bevel=0.06)
    for x0, x1, y0, y1 in ((PBX0, PBX1, PBY0, PBY0 + 0.35), (PBX0, PBX1, PBY1 - 0.35, PBY1),
                           (PBX0, PBX0 + 0.35, PBY0 + 0.35, PBY1 - 0.35),
                           (PBX1 - 0.35, PBX1, PBY0 + 0.35, PBY1 - 0.35)):
        b.box((x0, y0, PDECK), (x1, y1, PDECK + 0.06), P.INK, bevel=0.0)
    for x, y in ((30.20, -9.15), (32.20, -9.15), (33.65, -8.40), (33.65, -5.40), (33.65, -2.40),
                 (33.65, 0.60), (30.20, 9.15), (32.40, 9.15), (23.60, 3.60), (23.60, -3.60),
                 (25.00, 1.40), (27.20, 1.40), (25.00, 3.40), (27.20, 3.40)):
        b.cyl(x, y, PDECK, PDECK + 0.30, 0.34, P.TAN, n=8, bottom=False)
    for x, y in ((23.20, 8.90), (33.80, 8.90)):
        b.box((x - 0.50, y - 0.30, PDECK), (x + 0.50, y + 0.30, PDECK + 0.14), P.DBG, bevel=0.02)
        b.box((x - 0.35, y - 0.12, PDECK + 0.14), (x + 0.35, y + 0.12, PDECK + 0.40), P.DBG, bevel=0.02)
    b.beam((23.20, 8.90, PDECK + 0.30), (21.50, 11.50, COPE_Z1 + 0.55), 0.16, 0.16, P.BROWN)
    b.beam((33.80, 8.90, PDECK + 0.30), (36.50, 11.50, COPE_Z1 + 0.55), 0.16, 0.16, P.BROWN)
    for y in (-5.00, 5.00):
        b.torus(PBX1 - 0.02, y, 0.90, 0.50, 0.22, P.BLACK, maj=8, mnr=4)
    for y in (-2.60, 2.60):
        disc_y(b, 35.20, y, 0.85, 0.42, 1.60, P.DBG, n=8)


def treasure(b):
    """The recovered hoard: a low open crate overflowing with gold coins and a spill on the deck, a closed crate with
    two gold bars, the ship's wheel leaning on it, and a big gold anchor on a pallet."""
    x0, x1, y0, y1 = 23.20, 27.80, -6.80, -2.20
    zb, zt, t = 1.50, 3.70, 0.42
    b.box((x0, y0, zb), (x1, y1, zb + 0.25), P.BROWN, bevel=0.03)
    b.box((x0, y0, zb), (x0 + t, y1, zt), P.BROWN, bevel=0.05)
    b.box((x1 - t, y0, zb), (x1, y1, zt), P.BROWN, bevel=0.05)
    b.box((x0 + t, y0, zb), (x1 - t, y0 + t, zt), P.BROWN, bevel=0.05)
    b.box((x0 + t, y1 - t, zb), (x1 - t, y1, zt), P.BROWN, bevel=0.05)
    for x in (x0 + 0.06, x1 - 0.28):
        for y in (y0 + 0.06, y1 - 0.28):
            b.box((x, y, zb + 0.10), (x + 0.22, y + 0.22, zt - 0.10), P.DBG, bevel=0.02)
    for z in (2.45, 3.45):
        b.box((x0 - 0.05, y0 - 0.05, z), (x1 + 0.05, y0 + 0.03, z + 0.24), P.GOLD, bevel=0.0)
        b.box((x1 - 0.03, y0, z), (x1 + 0.05, y1 + 0.05, z + 0.24), P.GOLD, bevel=0.0)
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2                          # a stepped coin mound that climbs over the rims
    for r, z0, z1 in ((1.85, 2.00, 3.95), (1.45, 3.95, 4.55), (1.00, 4.55, 5.10), (0.55, 5.10, 5.45)):
        b.cyl(mx, my, z0, z1, r, P.GOLD, n=10, bottom=False)
    for cx, cy, cz in ((24.90, -5.45, 3.95), (26.20, -3.60, 3.95), (26.30, -5.40, 3.95), (24.70, -3.70, 3.95),
                       (25.30, -4.20, 5.45), (24.60, -6.60, 3.70), (26.20, -6.60, 3.70), (27.60, -4.60, 3.70)):
        coin(b, cx, cy, cz, r=0.78, n=8)
    for cx, cy, cz, h in ((24.20, -7.55, 1.50, 0.3), (25.70, -7.90, 1.50, 0.3),
                          (26.90, -7.35, 1.50, 0.3), (24.10, -7.85, 2.10, 0.3)):
        b.cyl(cx, cy, cz, cz + h, 0.90, P.GOLD, n=10)
    b.cyl_x(23.55, -7.70, 2.40, 0.90, 0.28, P.GOLD, n=10)
    # closed red crate with gold bands and lock; the gold anchor stands on it
    b.box((28.80, 4.80, 1.50), (32.40, 8.40, 4.50), P.RED, bevel=0.06, bottom=False)
    for z in (2.25, 3.75):
        b.box((28.75, 4.75, z), (32.45, 8.45, z + 0.24), P.GOLD, bevel=0.0)
    b.box((30.10, 4.72, 3.00), (31.10, 4.80, 3.90), P.GOLD, bevel=0.0)
    anchor(b, 30.60, 6.30, 6.90, 4.50, 1.45)
    # ship's wheel on the crate's east side
    wx, wy, wz = 33.20, 6.60, 4.55
    b.torus(wx, wy, wz, 2.35, 0.35, P.GOLD, maj=10, mnr=4)
    for i in range(8):
        a = 2 * math.pi * i / 8
        b.beam((wx, wy, wz), (wx, wy + 2.15 * math.cos(a), wz + 2.15 * math.sin(a)), 0.32, 0.32, P.GOLD)
    b.cyl_x(wx, wy, wz, 0.55, 0.90, P.GOLD, n=10)
    b.box((wx - 0.42, wy - 0.42, 1.50), (wx + 0.35, wy + 0.42, 1.85), P.BROWN, bevel=0.03)


def crane(b):
    """Small red salvage crane at the pontoon's south-east: dark pad, yellow slew, body and counterweight, mast, cab
    with a light studded roof and navy windows, a jib north with a yellow tip, a cable, hook and a hanging crate."""
    b.box((31.40, -9.50, 1.50), (34.40, -6.50, 1.85), P.DBG, bevel=0.05)
    b.cyl(32.90, -7.90, 1.85, 2.15, 1.15, P.YELLOW, n=12)
    b.box((31.90, -8.90, 2.15), (33.90, -6.90, 3.40), P.RED, bevel=0.06)
    b.box((33.90, -8.70, 2.45), (34.00, -7.10, 3.20), P.DBG, bevel=0.02)
    b.box((31.70, -9.55, 2.60), (34.10, -8.90, 3.60), P.RED, bevel=0.05)
    b.box((32.35, -8.45, 3.40), (33.45, -7.35, 12.30), P.RED, bevel=0.06)
    b.box((32.25, -8.55, 5.30), (33.55, -7.25, 5.60), P.DBG, bevel=0.02)
    b.box((31.30, -8.40, 6.50), (32.40, -7.40, 6.80), P.DBG, bevel=0.03)
    b.box((30.85, -8.45, 6.80), (32.35, -7.35, 9.20), P.RED, bevel=0.06)
    b.box((30.85, -8.30, 7.50), (30.90, -7.50, 8.70), P.INK)
    b.box((31.05, -8.50, 7.40), (32.15, -8.45, 8.70), P.INK)
    b.box((30.75, -8.55, 9.20), (32.45, -7.25, 9.42), P.LBG, bevel=0.03)
    for x in (31.05, 32.15):
        for y in (-8.25, -7.55):
            b.cyl(x, y, 9.42, 9.64, 0.28, P.LBG, n=8, bottom=False)
    b.box((32.35, -7.90, 10.80), (33.45, -6.90, 11.40), P.RED, bevel=0.04)
    b.box((32.45, -7.90, 11.20), (33.35, 3.20, 12.10), P.RED, bevel=0.05)
    b.box((32.60, -7.60, 11.10), (33.20, 2.95, 11.24), P.DBG, bevel=0.0)
    b.box((32.40, 2.40, 11.15), (33.40, 3.20, 12.15), P.YELLOW, bevel=0.04)
    b.box((31.80, -9.55, 10.70), (34.00, -8.60, 11.50), P.RED, bevel=0.05)
    b.box((31.85, -9.50, 11.50), (33.95, -8.65, 11.62), P.DBG, bevel=0.02)
    b.box((32.70, 2.70, 10.95), (33.10, 3.20, 11.25), P.DBG, bevel=0.02)
    b.beam((32.90, 3.00, 11.10), (32.90, 3.00, 9.30), 0.14, 0.14, P.BLACK)
    b.box((32.60, 2.70, 8.85), (33.20, 3.30, 9.30), P.DBG, bevel=0.03)
    b.box((32.00, 1.90, 7.45), (33.80, 3.50, 9.25), P.BLUE, bevel=0.05)
    for z in (7.85, 8.90):
        b.box((31.95, 1.85, z), (33.85, 3.55, z + 0.20), P.DBG, bevel=0.0)
    disc_y(b, 32.90, 1.90, 8.35, 0.52, 0.08, P.GOLD, n=10)
    for y in (2.35, 3.05):
        b.beam((32.90, y, 8.85), (32.90, y, 9.25), 0.10, 0.10, P.DBG)


def table(b):
    """Sorting table on the pontoon: tan top, dark legs and shelf, a red coin tray, a glass magnifier, a light
    ledger and two studs to keep it Lego."""
    b.box((23.60, 5.20, 3.10), (28.20, 8.60, 3.45), P.TAN, bevel=0.06)
    for x in (23.80, 27.65):
        for y in (5.40, 8.10):
            b.box((x, y, LOW), (x + 0.35, y + 0.35, 3.10), P.DBG, bevel=0.02)
    b.box((23.95, 5.55, 1.80), (27.85, 8.25, 1.98), P.DBG, bevel=0.02)
    for x, y in ((24.20, 8.10), (27.60, 5.70)):
        b.cyl(x, y, 3.45, 3.71, 0.34, P.TAN, n=8, bottom=False)
    b.box((23.90, 5.55, 3.45), (25.30, 7.00, 3.65), P.RED, bevel=0.04)
    for x, y in ((24.25, 5.95), (24.85, 5.95), (24.55, 6.55)):
        b.cyl(x, y, 3.65, 3.87, 0.30, P.GOLD, n=8)
    b.cyl(26.50, 6.10, 3.45, 3.52, 0.50, P.GLASS, n=12)
    b.beam((26.90, 6.10, 3.50), (27.35, 5.85, 3.50), 0.16, 0.10, P.DBG)
    b.box((26.20, 7.50, 3.45), (27.60, 8.20, 3.60), P.LBG, bevel=0.02)
    b.box((26.20, 7.50, 3.45), (26.34, 8.20, 3.64), P.DBG, bevel=0.02)
    b.box((27.05, 7.35, 3.45), (27.20, 7.75, 3.66), P.RED, bevel=0.0)


FBX0, FBX1 = 22.45, 28.95          # flag board footprint on the pontoon's south rim
FZ0, FZ1 = 6.00, 9.20              # navy field, above the coin pile


def flagboard(b):
    """Salvage flag sign at the pontoon's south edge, raised above the coin pile: two navy posts behind it, a navy
    field with light trim, the red diver-down flag with its white stripe on the left, a big gold anchor icon on the
    right, a studded yellow cap and dark rails on the back."""
    for x0 in (22.60, 28.15):
        b.box((x0, -9.32, LOW), (x0 + 0.40, -8.82, FZ1), P.INK, bevel=0.04, bottom=False)
        b.box((x0 - 0.15, -9.47, LOW), (x0 + 0.55, -8.72, 1.85), P.DBG, bevel=0.03, bottom=False)
    fx0, fx1 = FBX0 + 0.35, FBX1 - 0.35
    b.box((fx0, -9.30, FZ0), (fx1, -9.20, FZ1), P.INK, bevel=0.0)
    for x0, x1, z0, z1 in ((fx0, fx1, FZ1 - 0.25, FZ1), (fx0, fx1, FZ0, FZ0 + 0.25),
                           (fx0, fx0 + 0.25, FZ0 + 0.25, FZ1 - 0.25), (fx1 - 0.25, fx1, FZ0 + 0.25, FZ1 - 0.25)):
        b.box((x0, -9.36, z0), (x1, -9.30, z1), P.LBG, bevel=0.0)
    b.box((23.30, -9.35, 6.50), (25.50, -9.30, 8.70), P.RED, bevel=0.0)
    prism_y(b, -9.38, -9.35, [(23.30, 6.50), (23.75, 6.50), (25.50, 8.70), (25.05, 8.70)], P.WHITE)
    anchor(b, 27.10, -9.42, -9.30, 6.35, 1.0)
    for z0 in (FZ0 + 0.35, FZ1 - 0.65):
        b.box((23.00, -9.20, z0), (28.40, -9.14, z0 + 0.16), P.DBG, bevel=0.0)
    b.box((FBX0, -9.45, FZ1), (FBX1, -8.80, FZ1 + 0.25), P.YELLOW, bevel=0.03)
    b.studs(FBX0 + 0.35, FBX1 - 0.35, -9.35, -8.90, FZ1 + 0.25, P.YELLOW, step=1.7, r=0.32, h=0.24, n=6)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_SubPen_Brick", ALB)
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
        print("[subpen] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    # ================================================================ Lv2: gantry over the pool edge + hanging sub
    b = lego.B()
    gantry(b)
    out("Lv2_L01_Gantry", b, "Lv2")

    b = lego.B()
    winch(b)
    out("Lv2_L02_Hoist", b, "Lv2")

    b = lego.B()
    minisub(b)
    out("Lv2_L03_MiniSub", b, "Lv2")

    b = lego.B()
    dive_rack(b)
    out("Lv2_L04_DiveRack", b, "Lv2")

    c = lego.B()
    for sy in (-1, 1):
        c.box((15.30, sy * GY - 1.60, FLOOR), (18.50, sy * GY + 1.60, LEG_Z0), P.DBG)
        c.box((16.15, sy * GY - 0.75, LEG_Z0), (17.65, sy * GY + 0.75, BEAM_Z1), P.YELLOW)
    c.box((16.15, -6.60, BEAM_Z0), (17.65, 6.60, BEAM_Z1), P.YELLOW)
    c.box(rack_xf(WX0 - 0.10, WY0 - 0.10, FLOOR), rack_xf(WX1 + 0.10, WY1 + 0.10, WCOPE_Z1), P.INK)
    c.box(rack_xf(WX1, 0.80, FLOOR), rack_xf(WX1 + 1.30, 5.10, 2.80), P.TAN)
    c.box(sub_xf(SUB_X - 1.25, -3.60, SUP_Z0), sub_xf(SUB_X + 1.25, 4.00, SUP_Z1), P.YELLOW)
    c.box(sub_xf(SUB_X - 0.68, -0.97, SUP_Z1), sub_xf(SUB_X + 0.68, 1.07, 9.77), P.DBG)
    out_cols("Lv2", c)

    # ================================================================ Lv3: salvage basin, pontoon and the treasure
    layers = (("Lv3_L01_Basin", basin), ("Lv3_L02_Pontoon", pontoon), ("Lv3_L03_Treasure", treasure),
              ("Lv3_L04_Crane", crane), ("Lv3_L05_Table", table), ("Lv3_L06_Flag", flagboard))
    for name, fn in layers:
        b = lego.B()
        fn(b)
        xform(b, 0, lv3_xf)
        out(name, b, "Lv3")

    c = lego.B()
    for x0, x1, y0, y1 in ((BX0, BX1, BY0, IY0), (BX0, BX1, IY1, BY1), (IX1, BX1, BY0, BY1),
                           (BX0, IX0, BY0, GAP_Y0), (BX0, IX0, GAP_Y1, BY1)):
        c.box((x0, y0, 0.0), (x1, y1, COPE_Z1), P.DBG)
    for x0, x1, top in ((18.60, 19.80, 1.00), (19.80, 21.00, 1.25), (21.00, 22.80, LOW)):
        c.box((x0, -1.70, 0.0), (x1, 1.70, top), P.TAN)
    c.box((PBX0, PBY0, 0.55), (PBX1, PBY1, PDECK), P.TAN)
    c.box((23.20, -6.80, LOW), (27.80, -2.20, 4.00), P.BROWN)
    c.box((28.80, 4.80, LOW), (32.40, 8.40, 4.50), P.BROWN)
    c.box((32.85, 3.85, LOW), (33.55, 9.35, 7.25), P.GOLD)
    c.box((23.60, 5.20, LOW), (28.20, 8.60, 3.45), P.TAN)
    c.box((FBX0, -9.45, LOW), (FBX1, -8.72, FZ1 + 0.25), P.INK)
    c.box((31.40, -9.50, LOW), (34.40, -6.50, 1.85), P.DBG)
    c.box((31.70, -9.55, 1.85), (34.10, -6.90, 3.60), P.RED)
    c.box((32.35, -8.45, 3.60), (33.45, -7.35, 12.30), P.RED)
    c.box((30.85, -8.55, 6.50), (32.45, -7.25, 9.42), P.LBG)
    xform(c, 0, lv3_xf)
    out_cols("Lv3", c)

    atts = []
    for name, loc in (("ATT_Work_Gantry", (14.60, 0.00, DECK)),
                      ("ATT_Work_DiveRack", (14.60, RACK_DY - 0.60, DECK)),
                      ("ATT_Work_Salvage", lv3_xf(27.50, 0.00, PDECK)),
                      ("ATT_Work_Crane", lv3_xf(30.60, 0.40, PDECK)),
                      ("ATT_Sign_Salvage", lv3_xf(25.70, -9.58, 7.60))):
        atts.append(lego.attach(name, loc))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[subpen] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[subpen] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "level add-ons, not the whole pen: the code subPen() plinth (38 x 38, top z 0.80) and deck are "
                     "not modelled. The bbox spans the east gantry and dive-rack wall, the salvage wet dock and "
                     "pontoon behind the pen (+Y, off the 40 x 40 lot, clear of the cove walk; fit_check.py) and the "
                     "gantry 15.3 studs tall; front -Y (toward the sea), origin the pen ground centre, placed at the "
                     "pen's world 0 offset and 1x scale",
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
            {"name": "gantry", "target": [8.0, 0.0, 9.0], "dist": 38, "az": -40, "el": 10},
            {"name": "winch", "target": [4.5, 0.0, 11.5], "dist": 22, "az": -35, "el": 12},
            {"name": "minisub", "target": [3.95, 0.0, 8.5], "dist": 24, "az": -50, "el": 12},
            {"name": "dive_rack", "target": [16.9, RACK_DY - 0.5, 4.5], "dist": 18, "az": -58, "el": 12},
            {"name": "salvage", "target": [0.0, 27.5, 5.0], "dist": 38, "az": 75, "el": 18},
            {"name": "treasure", "target": [2.5, 29.0, 3.5], "dist": 24, "az": 70, "el": 16},
            {"name": "crane", "target": [-1.0, 31.0, 8.0], "dist": 22, "az": 40, "el": 12},
            {"name": "flag", "target": [9.2, 25.7, 7.6], "dist": 16, "az": 82, "el": 4},
        ],
    }

