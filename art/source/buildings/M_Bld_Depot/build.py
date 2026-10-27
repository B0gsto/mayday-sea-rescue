"""M_Bld_Depot: the island's walk-in Lego brick store (docs/25 D, J "walk-in buildings, no clutter"; docs/05 2.2/4/5).

Three level nodes (Lv1, Lv2, Lv3; levels add pieces, never reshape Lv1) on a 36 x 30 stud lot, plus a separate
FreightQuay node (12 x 26 stud jetty) on its east side.
Lv1: one open-front bay (interior 18 x 16.6, 18-stud opening, 10.9 headroom) on a studded tan floor, white walls on a
red two-course brick base. Along the back wall a 3-shelf rack holds the stock as four columns of same-colour 2x2
bricks (Stack_1..4, each reads alone). In front of the rack a yellow pick-up plate with an arrow; centred in the
mouth a blue drop plate of the same size with a white 2x2 brick glyph; between them a smooth tan lane with blue then
yellow painted edges. Sign: a giant yellow 2x2 brick on the front roof slope over the opening.
Lv2: a second bay on the west in the same language (its own rack, stacks, plates, lane, blue base, orange roof brick).
Lv3: a yellow lift tower at the back raises bricks from a feed tray at the quay corner onto a belt that runs up the OUTSIDE east
wall and over the eave (yellow rails, four bright bricks, one yellow trestle, clear gaps) into a yellow hopper on a yellow leg
(reads from the top-down build camera); a closed chute tucked behind the lintel drops straight down to a red flared mouth
6 studs over the drop plate.
Nothing loose stands on any floor.
FreightQuay: chunky timber piles, a tan deck with a yellow / black edge stripe and tyre fenders flush with the sea face
(the barge gap stays 0.9), two bollards and a crane by the feed plate (4x4 studded base, turntable, 3x3 mast, cab, long
red jib out over the berth, big counterweight, tie cables, black cable, hook and a green 2x2 brick), 2+ studs apart.

Lego rules win over the photoreal brief: one flat palette set (T_Depot_Brick, 16 saturated cells), no scans, no wear;
one mesh per layer, multiple colours per mesh via palette UVs (low draw calls). Layers are the construction beat,
bottom to top (Lv1_L01_Foundation ... Lv3_L04_Hopper, FreightQuay_L01_Piles ... L04_Derrick). The FBX importer
flattens empty parents, so each layer mesh carries its node as a name prefix; the node empties are kept in the .blend.
Collision is one `<Node>_COL` per node, built from separate convex boxes / prisms (doorways and interiors stay open).

Front is -Y (Roblox -Z), origin is the centre of the lot at ground level.

    python3 art/source/buildings/M_Bld_Depot/maketex.py --out build/prod/M_Bld_Depot/textures/M_Bld_Depot \
        --name Depot --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/buildings/M_Bld_Depot/build.py \
        --out-root build/prod/M_Bld_Depot --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_Depot"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "Depot", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_Depot_Brick_ALB.png")
FLOOR = 0.9            # lot slab top
FL = 1.1               # bay floor top
DECK = 2.2             # quay deck top
EAVE = 13.4
RUST = P.PINK          # cell 10 is a warm reddish brown in the Depot set (maketex.py)

# bays: outer x, interior x, y (front opening at Y0, back wall inner face at Y1)
Y0, Y1 = -3.0, 13.6
B1 = dict(x0=-10.4, x1=9.6, ix0=-9.4, ix1=8.6, walk=(-5.4, 4.4), drop=(-3.5, 2.5), roof=P.RED, sign=P.YELLOW,
          cols=(P.RED, P.BLUE, P.YELLOW, P.ORANGE), studs=(2, 2))
B2 = dict(x0=-24.0, x1=-10.4, ix0=-23.0, ix1=-10.4, walk=(-19.2, -11.0), drop=(-18.1, -12.1), roof=P.BLUE,
          sign=P.ORANGE, cols=(P.ORANGE, P.YELLOW, P.RED, P.BLUE), studs=(1, 2))
DROP_Y = (-2.4, 0.4)             # same size as the pick-up plate (6 x 2.8), centred in the bay mouth
PICK_Y = (7.2, 10.0)
RACK_Y = (10.4, Y1)
SHELVES = (0.5, 3.4, 6.3)        # shelf tops above FL; the top cap sits at 9.2..9.6
BRICK_H = 2.0

# Lv3 conveyor: a lift at the back lifts bricks from the feed tray; the belt runs x 10.75..13.25 outside bay 1's east
# wall (clear of the roof overhang, x 10.5) from the lift head (y 12.6) up over the eave to the hopper (y 0.2), top
# facing up so it reads from the high camera. The chute is tucked behind the lintel (y -2..0) and drops straight
# down onto the drop plate.
BELT_X, BELT_LO, BELT_HI = 12.0, (12.6, 14.6), (0.2, 16.0)   # belt top z at the two ends
HOP = (10.8, 14.4, -2.6, 1.0, 12.0, 15.2)   # hopper x0, x1, y0, y1, floor, wall top
CHUTE_Y, SPOUT_Z = (-2.0, 0.0), 7.1      # chute y span, flared mouth bottom (6.0 over the bay floor)
PORT = (-2.0, 0.0, 11.9, 13.1)   # y0, y1, z0, z1 of the port in bay 1's east wall


def belt_z(y):
    (ya, za), (yb, zb) = BELT_LO, BELT_HI
    return za + (ya - y) * (zb - za) / (ya - yb)


def patch_lod_names():
    """Layer meshes use game node names (Lv1_L01_...), not M_<Cat>_ names: keep the lod step working on them."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ small parts
def stud(b, x, y, z, c, r=0.55, h=0.3, n=8):
    """A floor / brick stud without its hidden bottom cap."""
    ring0 = [(x + r * math.cos(2 * math.pi * i / n), y + r * math.sin(2 * math.pi * i / n), z) for i in range(n)]
    ring1 = [(px, py, z + h) for px, py, _ in ring0]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n, 2 * n))]
    b._emit(ring0 + ring1, faces, c)


def prism_z(b, pts, z0, z1, c):
    """A convex plan polygon (x, y) extruded along Z (arrow heads)."""
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def gable(b, x0, x1, y0, y1, eave, ridge, c):
    """Convex gable prism (collision for a roof)."""
    b.prof_x(x0, x1, [(y0, eave), (y1, eave), ((y0 + y1) / 2, ridge)], c)


def ostud(b, c, up, d, side, r=0.5, h=0.38, colour=P.RED, n=8):
    """One stud on a tilted face: ring in the side/dir plane, extruded along up."""
    base = [tuple(c[k] + side[k] * r * math.cos(2 * math.pi * i / n) + d[k] * r * math.sin(2 * math.pi * i / n)
                  for k in range(3)) for i in range(n)]
    top = [tuple(p[k] + up[k] * h for k in range(3)) for p in base]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)] + [tuple(range(n, 2 * n))]
    b._emit(base + top, faces, colour)


def belt_brick(b, y, colour, length=2.4, width=1.6, height=1.0):
    """A 2x2 brick riding the inclined belt (the belt climbs toward -Y)."""
    (ya, za), (yb, zb) = BELT_LO, BELT_HI
    L = math.hypot(ya - yb, zb - za)
    d = (0.0, (yb - ya) / L, (zb - za) / L)
    up = (0.0, d[2], -d[1])                                  # belt normal (points up)
    side = (1.0, 0.0, 0.0)
    z = belt_z(y)
    ctr = (BELT_X, y + up[1] * height / 2, z + up[2] * height / 2)
    b.beam(tuple(ctr[k] - d[k] * length / 2 for k in range(3)), tuple(ctr[k] + d[k] * length / 2 for k in range(3)),
           width, height, colour)
    for u in (-0.25, 0.25):
        for v in (-0.25, 0.25):
            p = tuple(ctr[k] + d[k] * u * length + side[k] * v * width + up[k] * height / 2 for k in range(3))
            ostud(b, p, up, d, side, r=0.34, colour=colour, n=6)


def floor_studs(b, x0, x1, y0, y1, z, avoid, step=3.0):
    """Tan studs on a bay floor, kept off the walkway, the plates and the rack (avoid: x0, x1, y0, y1 rects)."""
    nx, ny = int((x1 - x0) // step), int((y1 - y0) // step)
    ox, oy = x0 + (x1 - x0 - (nx - 1) * step) / 2, y0 + (y1 - y0 - (ny - 1) * step) / 2
    for i in range(nx):
        for j in range(ny):
            x, y = ox + i * step, oy + j * step
            if not any(a - 0.8 < x < bb + 0.8 and c - 0.8 < y < d + 0.8 for a, bb, c, d in avoid):
                stud(b, x, y, z, P.TAN)


def arrow(b, cx, y0, y1, z, c, w=1.2, head=3.0):
    """Floor arrow glyph pointing +Y (toward the rack)."""
    b.box((cx - w / 2, y0, z), (cx + w / 2, y1 - head * 0.55, z + 0.1), c, bevel=0.03)
    prism_z(b, [(cx - head / 2, y1 - head * 0.6), (cx + head / 2, y1 - head * 0.6), (cx, y1)], z, z + 0.1, c)


# ------------------------------------------------------------------ bay kit
def drop_plate(b, x0, x1, y0, y1, z):
    """Blue drop plate with a white 2x2 brick glyph (raised square, four studs)."""
    b.box((x0, y0, z), (x1, y1, z + 0.15), P.BLUE, bevel=0.05)
    cx, cy, s = (x0 + x1) / 2, (y0 + y1) / 2, min(x1 - x0, y1 - y0) * 0.38
    b.box((cx - s, cy - s, z + 0.15), (cx + s, cy + s, z + 0.27), P.WHITE, bevel=0.04)
    for dx in (-s / 2, s / 2):
        for dy in (-s / 2, s / 2):
            stud(b, cx + dx, cy + dy, z + 0.27, P.WHITE, r=s * 0.3, h=0.22)


def bay_floor(b, bay):
    """Studded tan bay floor; blue drop plate in the mouth, yellow pick-up plate (arrow) by the rack, a stud-free lane
    between them with painted edges, blue by the drop plate, yellow by the pick-up plate."""
    ix0, ix1 = bay["ix0"], bay["ix1"]
    d0, d1 = bay["drop"]
    pc = (d0 + d1) / 2
    b.box((ix0, Y0, FLOOR), (ix1, Y1, FL), P.TAN, bevel=0.05)
    drop_plate(b, d0, d1, DROP_Y[0], DROP_Y[1], FL)
    b.box((pc - 3.0, PICK_Y[0], FL), (pc + 3.0, PICK_Y[1], FL + 0.15), P.YELLOW, bevel=0.05)    # pick-up plate
    arrow(b, pc, PICK_Y[0] + 0.4, PICK_Y[1] - 0.3, FL + 0.15, P.DBG)
    ym = (DROP_Y[1] + PICK_Y[0]) / 2
    for x in (pc - 3.0, pc + 2.6):                                                               # lane edges
        b.box((x, DROP_Y[1] + 0.3, FL), (x + 0.4, ym - 0.15, FL + 0.06), P.BLUE, bevel=0.02)
        b.box((x, ym + 0.15, FL), (x + 0.4, PICK_Y[0] - 0.3, FL + 0.06), P.YELLOW, bevel=0.02)
    avoid = [(pc - 3.6, pc + 3.6, Y0, PICK_Y[1]), (ix0, ix1, RACK_Y[0], Y1)]
    floor_studs(b, ix0 + 0.4, ix1 - 0.4, Y0 + 0.6, RACK_Y[0], FL, avoid)


def course(b, x0, x1, y0, y1, c, seg=4.0, h=1.2):
    """Two staggered courses of bricks along a wall foot (the long side of x0..x1 / y0..y1 runs along the wall)."""
    ax = x1 - x0 >= y1 - y0
    a0, a1 = (x0, x1) if ax else (y0, y1)
    n = max(1, round((a1 - a0) / seg))
    L = (a1 - a0) / n
    for row in range(2):
        z = FLOOR + row * h
        cuts = sorted({a0, a1} | {a0 + (k - 0.5 * row) * L for k in range(1, n + row)})
        for s0, s1 in zip(cuts, cuts[1:]):
            lo, hi = ((s0 + 0.05, y0, z), (s1 - 0.05, y1, z + h - 0.06)) if ax else \
                ((x0, s0 + 0.05, z), (x1, s1 - 0.05, z + h - 0.06))
            b.box(lo, hi, c, bevel=0.08)


def bay_walls(b, bay, west=True, port=False, eave=EAVE):
    """White walls of an open-front bay: back, east (with the conveyor port), optional west; front lintel."""
    x0, x1, ix0, ix1 = bay["x0"], bay["x1"], bay["ix0"], bay["ix1"]
    b.box((x0 if west else ix0, Y1, FLOOR), (x1, Y1 + 1.0, eave), P.WHITE)                    # back
    b.box((ix0 + 0.1, Y1 - 0.1, FL), (ix1 - 0.1, Y1, FL + 10.2), P.LBG, bevel=0.03)          # grey panel behind the rack
    if ix1 < x1:                                                                               # east wall
        if port:
            py0, py1, pz0, pz1 = PORT
            b.box((ix1, Y0, FLOOR), (x1, Y1, pz0), P.WHITE)
            b.box((ix1, Y0, pz1), (x1, Y1, eave), P.WHITE)
            b.box((ix1, Y0, pz0), (x1, py0, pz1), P.WHITE)
            b.box((ix1, py1, pz0), (x1, Y1, pz1), P.WHITE)
        else:
            b.box((ix1, Y0, FLOOR), (x1, Y1, eave), P.WHITE)
    if west:
        b.box((x0, Y0, FLOOR), (ix0, Y1, eave), P.WHITE)
    b.box((ix0, Y0, eave - 1.4), (ix1, Y0 + 1.0, eave), P.WHITE)                                 # lintel
    b.box((ix0, Y0 - 0.06, eave - 1.5), (ix1, Y0 + 1.0, eave - 1.3), bay["roof"], bevel=0.05)  # lintel trim
    for xx in ((x0, ix0) if west else ()) + ((ix1, x1) if ix1 < x1 else ()):                   # front pillars
        b.box((xx - 0.1 if xx == x0 else xx, Y0 - 0.15, FLOOR), (xx + 1.0 + (0.1 if xx != x0 else 0), Y0 + 1.0, eave),
              P.LBG)
    c = bay["roof"]                                                                            # brick base course
    course(b, x0 - 0.15, x1 + 0.15, Y1 + 1.0, Y1 + 1.15, c)
    if west:
        course(b, x0 - 0.15, x0, Y0 - 0.15, Y1 + 1.0, c)
        course(b, x0 - 0.15, x0 + 1.1, Y0 - 0.3, Y0 - 0.15, c)
    if ix1 < x1:
        course(b, x1, x1 + 0.15, Y0 - 0.15, Y1 + 1.0, c)
        course(b, ix1, x1 + 0.15, Y0 - 0.3, Y0 - 0.15, c)


def rack(b, bay):
    """A 3-shelf Lego rack on the back wall: dark uprights and shelves (the bricks are the Stack meshes)."""
    x0, x1 = bay["ix0"] + 0.4, bay["ix1"] - 0.4
    y0, y1 = RACK_Y
    up = 0.5 if bay is B1 else 0.4
    col_w = (x1 - x0 - 5 * up) / 4
    b.box((x0, y0, FL), (x1, y1, FL + SHELVES[0]), P.DBG)                                      # plinth / bottom shelf
    for s in SHELVES[1:]:
        b.box((x0, y0, FL + s - 0.4), (x1, y1, FL + s), P.DBG, bevel=0.06)
    b.box((x0, y0, FL + 9.2), (x1, y1, FL + 9.6), P.DBG, bevel=0.06)                          # top cap
    for k in range(5):
        xx = x0 + k * (col_w + up)
        b.box((xx, y0 - 0.05, FL), (xx + up, y1, FL + 9.6), P.DBG, bevel=0.05)
    b.stud_row(x0 + 1.0, (y0 + y1) / 2, x1 - 1.0, (y0 + y1) / 2, FL + 9.6, P.DBG, spacing=2.6, r=0.5, h=0.3)
    return [x0 + up + k * (col_w + up) + col_w / 2 for k in range(4)], col_w


def stack(b, bay, cx, col_w, colour):
    """One column of same-colour bricks, one per shelf."""
    nx, ny = bay["studs"]
    w, d = col_w - 0.5, 2.6
    yc = (RACK_Y[0] + RACK_Y[1]) / 2 - 0.1
    for s in SHELVES:
        z = FL + s
        b.box((cx - w / 2, yc - d / 2, z), (cx + w / 2, yc + d / 2, z + BRICK_H), colour)
        for i in range(nx):
            for j in range(ny):
                stud(b, cx - w / 2 + (i + 0.5) * w / nx, yc - d / 2 + (j + 0.5) * d / ny, z + BRICK_H, colour,
                     r=min(0.55, 0.3 * w / nx * 2), h=0.38)


def roof(b, x0, x1, y0, y1, eave, ridge, colour, oh=0.8):
    """Gable slope-brick roof (x0/x1 are the slab ends): two slabs, stepped courses, ridge cap, gable infill."""
    ym = (y0 + y1) / 2
    th = 0.6
    for side, ye in ((-1, y0 - oh), (1, y1 + oh)):
        dy, dz = ye - ym, eave - ridge
        L = (dy * dy + dz * dz) ** 0.5
        ny, nz = dz / L * th, -dy / L * th
        pts = [(ym, ridge), (ye, eave), (ye + ny, eave + nz), (ym + ny, ridge + nz)]
        if side < 0:
            pts.reverse()
        b.prof_x(x0, x1, pts, colour)
        for k in range(1, 5):
            t = k / 5.0
            y = ym + dy * t
            z = ridge + dz * t + nz
            b.box((x0, min(y - 1.5 * side, y + 0.6 * side), z - 0.1), (x1, max(y - 1.5 * side, y + 0.6 * side), z + 0.42),
                  colour)
    b.box((x0 - 0.2, ym - 0.55, ridge + 0.15), (x1 + 0.2, ym + 0.55, ridge + 0.7), P.DBG)
    b.stud_row(x0 + 1.4, ym, x1 - 1.4, ym, ridge + 0.7, P.DBG, spacing=3.0, r=0.55, h=0.35)


def gable_infill(b, xa, xb, eave, ridge):
    b.prof_x(xa, xb, [(Y0, eave - 0.1), ((Y0 + Y1 + 1.0) / 2, ridge - 0.1), (Y1 + 1.0, eave - 0.1)], P.WHITE)


def sign_brick(b, cx, eave, ridge, colour, w=5.2, h=3.0):
    """Giant 2x2 brick standing on the front roof slope over the opening; its bottom follows the slope (kept above
    the roof underside, so nothing shows inside)."""
    y0, y1 = -2.4, 2.6
    k = (ridge - eave) / ((Y1 + 1.0 - Y0) / 2 + 0.8)        # roof pitch (rise per stud of y)
    z0 = eave + k * (y0 + 3.8) + 0.4                         # just under the slope top at the brick's front face
    b.prof_x(cx - w / 2, cx + w / 2, [(y0, z0), (y1, z0 + k * (y1 - y0)), (y1, z0 + h), (y0, z0 + h)], colour)
    b.studs(cx - w / 2 + 0.3, cx + w / 2 - 0.3, y0 + 0.3, y1 - 0.3, z0 + h, colour, step=2.2, r=0.95, h=0.6, n=12)
    return (cx - w / 2, y0, z0), (cx + w / 2, y1, z0 + h + 0.6)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_Depot_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv1", "Lv2", "Lv3", "FreightQuay")}

    def out(name, b, node):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[depot] %-26s %5d tris" % (name, b.tris()))

    ridge1, ridge2 = 17.0, 16.4

    # ================================================================ Lv1: one walk-in bay + empty yard
    b = lego.B()
    b.box((-24.4, -15.4, 0.0), (12.4, 15.4, 0.45), P.DBG)                    # plinth / kerb
    b.box((-24.0, -15.0, 0.45), (12.0, 15.0, FLOOR), P.TAN)                  # yard slab
    b.stud_row(-22.0, -14.1, 10.0, -14.1, FLOOR, P.TAN, spacing=4.0, r=0.65, h=0.4)
    b.box((10.9, -13.0, FLOOR), (12.0, -3.6, 1.55), P.TAN)                   # step up to the quay deck
    bay_floor(b, B1)
    out("Lv1_L01_Foundation", b, "Lv1")

    b = lego.B()
    bay_walls(b, B1, west=True, port=True)
    out("Lv1_L02_Frame", b, "Lv1")

    b = lego.B()
    cxs1, cw1 = rack(b, B1)
    out("Lv1_L03_Rack", b, "Lv1")

    b = lego.B()
    roof(b, B1["x0"] - 0.5, B1["x1"] + 0.7, Y0, Y1 + 1.0, EAVE, ridge1, P.RED)
    gable_infill(b, B1["x0"] + 0.05, B1["ix0"] - 0.05, EAVE, ridge1)
    gable_infill(b, B1["ix1"] + 0.05, B1["x1"] - 0.05, EAVE, ridge1)
    out("Lv1_L04_Roof", b, "Lv1")

    b = lego.B()
    sx = sum(B1["drop"]) / 2
    sign1 = sign_brick(b, sx, EAVE, ridge1, B1["sign"])
    out("Lv1_L05_Sign", b, "Lv1")

    for i, (cx, col) in enumerate(zip(cxs1, B1["cols"]), 1):
        b = lego.B()
        stack(b, B1, cx, cw1, col)
        out("Lv1_Stack_%d" % i, b, "Lv1")

    c = lego.B()
    c.box((-24.0, -15.0, 0.0), (12.0, 15.0, FLOOR), P.TAN)                   # yard slab
    c.box((B1["ix0"], Y0, FLOOR), (B1["ix1"], Y1, FL), P.TAN)                # bay floor
    c.box((10.9, -13.0, FLOOR), (12.0, -3.6, 1.55), P.TAN)                   # step
    c.box((B1["x0"], Y0, FLOOR), (B1["ix0"], Y1 + 1.0, EAVE), P.WHITE)      # west wall
    c.box((B1["ix1"], Y0, FLOOR), (B1["x1"], Y1 + 1.0, EAVE), P.WHITE)      # east wall
    c.box((B1["ix0"], Y1, FLOOR), (B1["ix1"], Y1 + 1.0, EAVE), P.WHITE)     # back wall
    c.box((B1["ix0"], Y0, EAVE - 1.5), (B1["ix1"], Y0 + 1.0, EAVE), P.WHITE)   # lintel
    c.box((B1["ix0"] + 0.4, RACK_Y[0], FL), (B1["ix1"] - 0.4, Y1, FL + 9.6), P.DBG)   # rack
    gable(c, B1["x0"] - 0.5, B1["x1"] + 0.7, Y0 - 0.8, Y1 + 1.8, EAVE, ridge1 + 0.7, P.RED)
    c.box(*sign1, P.YELLOW)                                                  # roof brick
    out("Lv1_COL", c, "Lv1")

    # ================================================================ Lv2: second bay on the west
    b = lego.B()
    bay_floor(b, B2)
    out("Lv2_L01_Base", b, "Lv2")

    b = lego.B()
    bay_walls(b, B2, west=True, eave=EAVE - 0.4)
    for y in (2.0, 9.0):                                                     # two windows on the west wall
        b.box((B2["x0"] - 0.12, y - 1.6, 6.0), (B2["x0"], y + 1.6, 9.6), P.LBG, bevel=0.04)
        b.box((B2["x0"] - 0.2, y - 1.2, 6.4), (B2["x0"] - 0.1, y + 1.2, 9.2), P.GLASS, bevel=0.02)
    out("Lv2_L02_Frame", b, "Lv2")

    b = lego.B()
    cxs2, cw2 = rack(b, B2)
    out("Lv2_L03_Rack", b, "Lv2")

    b = lego.B()
    eave2 = EAVE - 0.4
    roof(b, B2["x0"] - 0.7, B1["x0"] - 0.5, Y0, Y1 + 1.0, eave2, ridge2, P.BLUE)
    gable_infill(b, B2["x0"] + 0.05, B2["ix0"] - 0.05, eave2, ridge2)
    out("Lv2_L04_Roof", b, "Lv2")

    b = lego.B()
    sign2 = sign_brick(b, sum(B2["drop"]) / 2, eave2, ridge2, B2["sign"])
    out("Lv2_L05_Sign", b, "Lv2")

    for i, (cx, col) in enumerate(zip(cxs2, B2["cols"]), 1):
        b = lego.B()
        stack(b, B2, cx, cw2, col)
        out("Lv2_Stack_%d" % i, b, "Lv2")

    c = lego.B()
    c.box((B2["ix0"], Y0, FLOOR), (B2["ix1"], Y1, FL), P.TAN)
    c.box((B2["x0"], Y0, FLOOR), (B2["ix0"], Y1 + 1.0, eave2), P.WHITE)
    c.box((B2["ix0"], Y1, FLOOR), (B2["ix1"], Y1 + 1.0, eave2), P.WHITE)
    c.box((B2["ix0"], Y0, eave2 - 1.5), (B2["ix1"], Y0 + 1.0, eave2), P.WHITE)
    c.box((B2["ix0"] + 0.4, RACK_Y[0], FL), (B2["ix1"] - 0.4, Y1, FL + 9.6), P.DBG)
    gable(c, B2["x0"] - 0.7, B1["x0"] - 0.5, Y0 - 0.8, Y1 + 1.8, eave2, ridge2 + 0.7, P.BLUE)
    c.box(*sign2, P.ORANGE)
    out("Lv2_COL", c, "Lv2")

    # ================================================================ Lv3: feed tray -> lift -> belt over the eave -> hopper -> chute
    (ya, za), (yb, zb) = BELT_LO, BELT_HI
    hx0, hx1, hy0, hy1, hz0, hz1 = HOP
    trestles = (6.6,)                                                        # one mid trestle: clear gaps
    cy0, cy1 = CHUTE_Y
    sx = sum(B1["drop"]) / 2
    X = BELT_X
    b = lego.B()
    for y in trestles + (-0.8,):
        b.box((X - 1.4, y - 1.4, FLOOR), (X + 1.4, y + 1.4, 2.45), P.DBG)                    # trestle feet
    b.box((X - 1.2, 11.2, 0.0), (X + 1.2, 13.4, 3.0), P.DBG)                                 # feed tray plinth
    drop_plate(b, 13.0, 16.0, 9.6, 12.6, DECK)                                                 # quay drop plate (feed)
    out("Lv3_L01_Base", b, "Lv3")

    b = lego.B()
    for y in trestles + (-0.8,):                                             # yellow trestle + hopper leg
        top = belt_z(y + 0.8) - 0.9 if y > 0 else hz0
        b.box((X - 0.8, y - 0.8, 2.45), (X + 0.8, y + 0.8, top), P.YELLOW)
        b.box((X - 0.88, y - 0.88, 6.0), (X + 0.88, y + 0.88, 6.3), P.DBG, bevel=0.04)      # brick seam
    b.box((X - 1.2, 13.4, 0.0), (X + 1.2, 15.0, 13.2), P.YELLOW)                              # lift tower
    out("Lv3_L02_Trestles", b, "Lv3")

    b = lego.B()
    b.box((X - 1.3, 11.0, 3.0), (X + 1.3, 13.4, 3.4), P.YELLOW)                               # open feed tray
    for xa, xb, y0, y1 in ((X - 1.3, X + 1.3, 11.0, 11.4), (X - 1.3, X - 0.9, 11.0, 13.4), (X + 0.9, X + 1.3, 11.0, 13.4)):
        b.box((xa, y0, 3.4), (xb, y1, 4.4), P.YELLOW)
    b.box((X - 0.8, 13.2, 3.4), (X + 0.8, 13.4, 13.2), P.BLACK)                               # lift belt
    for z, col in ((6.4, P.RED), (10.0, P.BLUE)):                                              # bricks riding up
        b.box((X - 0.7, 12.4, z), (X + 0.7, 13.2, z + 1.0), col)
    b.box((X - 1.45, 12.6, 13.2), (X + 1.45, 15.2, 15.2), P.YELLOW)                          # lift head
    b.beam((X, ya, za - 0.25), (X, yb, zb - 0.25), 1.8, 0.5, P.BLACK)                          # belt
    for x in (X - 1.05, X + 1.05):                                                              # yellow side rails
        b.beam((x, ya, za - 0.3), (x, yb, zb - 0.3), 0.4, 1.2, P.YELLOW)
    for y, col in ((11.0, P.RED), (7.9, P.BLUE), (4.8, P.GREEN), (1.7, P.ORANGE)):
        belt_brick(b, y, col, length=2.0)
    b.box((sx - 0.9, cy0, hz0), (hx0 + 0.5, cy1, hz0 + 0.9), P.YELLOW, bevel=0.06)           # closed chute behind the lintel
    b.box((sx - 0.9, cy0, SPOUT_Z + 1.0), (sx + 0.9, cy1, hz0), P.YELLOW)                      # straight drop tube
    ring = lambda w, d, z: [(sx - w, cy0 - d, z), (sx + w, cy0 - d, z), (sx + w, cy1 + d, z), (sx - w, cy1 + d, z)]
    b.loft([ring(1.7, 0.7, SPOUT_Z), ring(0.95, 0.05, SPOUT_Z + 1.0)], P.RED)                # red flared mouth
    b.box((9.6, cy0 - 0.2, hz0 - 0.5), (hx0, cy1 + 0.2, hz0), P.DBG)                          # bracket outside
    out("Lv3_L03_Belt", b, "Lv3")

    b = lego.B()
    for lo, hi in (((hx0, hy0, hz0), (hx1, hy0 + 0.4, hz1)), ((hx0, hy1 - 0.4, hz0), (hx1, hy1, hz1)),
                   ((hx0, hy0 + 0.4, hz0), (hx0 + 0.4, hy1 - 0.4, hz1)), ((hx1 - 0.4, hy0 + 0.4, hz0), (hx1, hy1 - 0.4, hz1)),
                   ((hx0 + 0.4, hy0 + 0.4, hz0), (hx1 - 0.4, hy1 - 0.4, hz0 + 0.4))):
        b.box(lo, hi, P.YELLOW)                                                                 # open hopper
    b.box((hx0 - 0.1, hy0 - 0.1, hz1), (hx1 + 0.1, hy1 + 0.1, hz1 + 0.3), P.DBG, bevel=0.05)  # rim
    out("Lv3_L04_Hopper", b, "Lv3")

    c = lego.B()
    c.box((X - 1.3, 11.0, 0.0), (X + 1.3, 13.4, 4.4), P.YELLOW)                               # feed tray
    c.box((X - 1.45, 13.4, 0.0), (X + 1.45, 15.2, 15.2), P.YELLOW)                            # lift
    c.beam((X, ya, za - 0.5), (X, yb, zb - 0.5), 2.6, 1.4, P.DBG)                              # belt (overhead)
    for y in trestles + (-0.8,):
        c.box((X - 1.4, y - 1.4, FLOOR), (X + 1.4, y + 1.4, belt_z(y + 0.8) - 0.9 if y > 0 else hz0), P.YELLOW)
    c.box((hx0 - 0.1, hy0 - 0.1, hz0), (hx1 + 0.1, hy1 + 0.1, hz1 + 0.3), P.YELLOW)          # hopper
    c.box((sx - 0.9, cy0, hz0), (hx0, cy1, hz0 + 0.9), P.YELLOW)                              # chute (overhead)
    c.box((sx - 1.7, cy0 - 0.7, SPOUT_Z), (sx + 1.7, cy1 + 0.7, hz0), P.YELLOW)               # drop tube, 6.0 up
    out("Lv3_COL", c, "Lv3")

    # ================================================================ FreightQuay (12 x 26 stud jetty)
    b = lego.B()
    for x in (14.0, 22.0):
        for y in (-11.0, -5.5, 0.0, 5.5, 11.0):
            b.box((x - 1.8, y - 1.8, 0.0), (x + 1.8, y + 1.8, 0.5), P.DBG)
            b.box((x - 1.1, y - 1.1, 0.5), (x + 1.1, y + 1.1, 1.6), P.BROWN)
    for y in (-11.0, -5.5, 0.0, 5.5, 11.0):
        b.beam((14.0, y, 0.6), (22.0, y, 1.2), 0.35, 0.35, P.DBG)
    for x in (14.0, 22.0):
        b.beam((x, -11.0, 1.2), (x, 11.0, 1.2), 0.3, 0.3, P.DBG)
    out("FreightQuay_L01_Piles", b, "FreightQuay")

    QE = 23.4                                                                # water-side deck face (tyres to 24.0)
    b = lego.B()
    b.box((12.0, -13.0, 1.6), (QE, 13.0, 2.0), RUST)                         # deck base, one plate
    for k in range(4):
        y0 = -12.3 + k * 6.325
        b.box((12.7, y0, 2.0), (QE - 0.7, y0 + 6.125, DECK), P.TAN)
    b.box((12.0, -13.0, 1.6), (12.7, 13.0, 2.35), P.DBG)                     # land-side kerb
    for k in range(13):                                                       # yellow / black edge stripe, sea side
        b.box((QE - 0.7, -13.0 + 2 * k, 1.6), (QE, -11.0 + 2 * k, 2.4), (P.YELLOW, P.BLACK)[k % 2])
    for k in range(5):                                                        # ... and the south end
        b.box((QE - 2.7 - 2 * k, -13.0, 1.6), (QE - 0.7 - 2 * k, -12.3, 2.4), (P.BLACK, P.YELLOW)[k % 2])
    for y in (-11.5, -7.5, -3.5, 0.5, 4.5):                                  # one stud row on the land side
        stud(b, 13.6, y, DECK, P.TAN, r=0.62, h=0.4)
    for y in (-12.6, -11.4):                                                  # ladder down the sea side
        b.box((QE, y - 0.1, 0.3), (QE + 0.3, y + 0.1, 2.3), P.DBG)
    for k in range(4):
        b.box((QE, -12.5, 0.6 + k * 0.5), (QE + 0.3, -11.5, 0.8 + k * 0.5), P.LBG)
    out("FreightQuay_L02_Deck", b, "FreightQuay")

    b = lego.B()
    for y in (-5.0, 5.0):
        b.cyl(21.6, y, DECK, 3.7, 0.8, P.DBG, 8)
        b.cyl(21.6, y, 3.7, 4.15, 1.05, P.BLUE, 8)
    for y in (-8.25, -2.75, 2.75, 8.25):                                     # tyre fenders flush to x 24 (barge gap)
        b.torus(QE + 0.25, y, 1.3, 0.75, 0.35, P.BLACK)
    out("FreightQuay_L03_Bollards", b, "FreightQuay")

    b = lego.B()
    mx, my, top = 20.4, 10.6, 13.0                                           # crane by the feed plate
    tip = (31.2, 4.4)                                                        # jib tip over the berth
    L = math.hypot(tip[0] - mx, tip[1] - my)
    u = ((tip[0] - mx) / L, (tip[1] - my) / L)
    at = lambda t, z: (mx + u[0] * t, my + u[1] * t, z)                      # a point along the jib line
    b.box((mx - 2.2, my - 2.2, DECK), (mx + 2.2, my + 2.2, DECK + 1.0), P.DBG)               # 4x4 base
    for dx in (-1.85, 1.85):
        for dy in (-1.85, 1.85):
            stud(b, mx + dx, my + dy, DECK + 1.0, P.DBG, r=0.3, h=0.35, n=6)
    b.cyl(mx, my, DECK + 1.0, DECK + 1.7, 1.75, P.LBG, 12)                                   # turntable
    b.box((mx - 1.65, my - 1.65, DECK + 1.7), (mx + 1.65, my + 1.65, top), P.YELLOW)         # 3x3 mast
    for z in (6.5, 10.0):
        b.box((mx - 1.75, my - 1.75, z), (mx + 1.75, my + 1.75, z + 0.3), P.DBG, bevel=0.04) # brick seams
    b.box((mx - 1.9, my - 1.9, top), (mx + 1.9, my + 1.9, top + 0.5), P.DBG)                 # slewing ring
    b.beam(at(-5.4, top + 1.2), at(L, top + 1.2), 1.6, 1.4, P.RED)                           # long red jib
    for t in range(5):
        stud(b, *at(2.4 + t * (L - 3.2) / 4, top + 1.9), P.RED, r=0.45, h=0.35)
    b.beam(at(-5.6, top + 1.1), at(-2.6, top + 1.1), 3.2, 3.6, P.DBG)                        # big counterweight
    b.beam(at(-5.65, top + 1.4), at(-2.55, top + 1.4), 3.3, 0.3, P.BLACK)                    # its brick seam
    b.beam(at(1.8, top - 0.6), at(4.0, top - 0.6), 2.2, 1.6, P.YELLOW)                       # cab
    b.beam(at(3.95, top - 0.5), at(4.1, top - 0.5), 1.6, 0.9, P.GLASS)
    b.box((mx - 0.6, my - 0.6, top + 1.9), (mx + 0.6, my + 0.6, top + 4.2), P.YELLOW)        # cat-head
    for t in (L - 0.4, -5.2):
        b.beam((mx, my, top + 4.0), at(t, top + 1.9), 0.2, 0.2, P.BLACK)                      # tie cables
    h = at(L - 1.6, 0)
    b.beam(at(L - 2.2, top + 0.25), at(L - 1.0, top + 0.25), 1.8, 0.5, P.DBG)                # trolley
    b.box((h[0] - 0.1, h[1] - 0.1, 10.8), (h[0] + 0.1, h[1] + 0.1, top), P.BLACK)            # cable
    b.box((h[0] - 0.6, h[1] - 0.6, 10.0), (h[0] + 0.6, h[1] + 0.6, 10.8), P.DBG)             # hook block
    b.box((h[0] - 0.2, h[1] - 0.2, 9.5), (h[0] + 0.2, h[1] + 0.2, 10.0), P.YELLOW)          # hook
    for dx in (-0.85, 0.85):
        for dy in (-0.85, 0.85):
            b.beam((h[0] + dx, h[1] + dy, 9.2), (h[0], h[1], 9.6), 0.12, 0.12, P.BLACK)        # slings
    b.box((h[0] - 1.3, h[1] - 1.3, 7.3), (h[0] + 1.3, h[1] + 1.3, 9.2), P.GREEN)             # bright 2x2 brick
    for dx in (-0.65, 0.65):
        for dy in (-0.65, 0.65):
            stud(b, h[0] + dx, h[1] + dy, 9.2, P.GREEN, r=0.45, h=0.4, n=6)
    out("FreightQuay_L04_Derrick", b, "FreightQuay")

    c = lego.B()
    c.box((12.0, -13.0, 0.0), (24.0, 13.0, DECK), P.TAN)
    for y in (-5.0, 5.0):
        c.box((20.55, y - 1.05, DECK), (22.65, y + 1.05, 4.15), P.DBG)
    c.box((mx - 2.2, my - 2.2, DECK), (mx + 2.2, my + 2.2, DECK + 1.7), P.DBG)
    c.box((mx - 1.65, my - 1.65, DECK), (mx + 1.65, my + 1.65, top), P.YELLOW)
    out("FreightQuay_COL", c, "FreightQuay")

    # ================================================================ attachments (floor centre of each plate)
    pz = FL + 0.15
    for name, loc in (("ATT_PickUp_Lv1", (sum(B1["walk"]) / 2, sum(PICK_Y) / 2, pz)),
                      ("ATT_DropOff_Lv1", (sum(B1["drop"]) / 2, sum(DROP_Y) / 2, pz)),
                      ("ATT_PickUp_Lv2", (sum(B2["walk"]) / 2, sum(PICK_Y) / 2, pz)),
                      ("ATT_DropOff_Lv2", (sum(B2["drop"]) / 2, sum(DROP_Y) / 2, pz)),
                      ("ATT_DropOff_Lv3", (14.5, 11.1, DECK + 0.15)),
                      ("ATT_ConveyorEnd", (sum(B1["drop"]) / 2, sum(CHUTE_Y) / 2, SPOUT_Z)),
                      ("ATT_BargeMoor", (32.8, 0.0, 0.5))):
        lego.attach(name, loc)

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[depot] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": (16.0, 10.0, 6.0), "origin": "free", "tiling": True,
        "size_note": "36 x 30 stud Depot + its 12 x 26 stud FreightQuay on the east side (48 x 30 studs overall); "
                     "origin stays the lot centre at ground level, the crane jib overhangs the berth (bbox x to 32)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "real size x": "the quay crane's jib reaches 8 studs out over the barge berth (AD v2 r2); the footprint "
                           "is still 48 studs",
            "naming": "gameplay node/layer names (docs/25 D): Lv1_L01_..., FreightQuay_L01_..., Stack_i, <Node>_COL; "
                      "the FBX importer flattens empty parents, so the node name is the mesh name prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "closeups": [
            {"name": "bay_front", "target": [-0.4, 0.0, 7.0], "dist": 34, "az": 12, "el": 8},
            {"name": "rack", "target": [-0.4, 11.0, 5.0], "dist": 16, "az": 0, "el": 12},
            {"name": "second_bay", "target": [-17.0, 2.0, 7.0], "dist": 28, "az": 345, "el": 8},
            {"name": "conveyor", "target": [12.0, 6.0, 11.0], "dist": 32, "az": 60, "el": 22},
            {"name": "freight_quay", "target": [22.0, 3.0, 7.0], "dist": 36, "az": 64, "el": 22},
        ],
    }
