"""M_Bld_BoathouseAddons: the whole Boathouse by level, Lego style (docs/25; docs/05 2.2, 3; PERF-BL11).

Lv1_*: the code boathouse (`boathouse()` in src/shared/DockPieces.luau, its Parts stay the fallback; the code keeps the plinth,
name sign and board slot): blue brick walls, white piers, an arched boat-bay door with a half-rolled shutter, a stepped red roof,
a hull-number sticker, a flag, a boat on a walk-over lane that runs out to the cove.
Lv2_*: the code lifeboat slip's shed (`lifeboatSlip()`, 1x on its lot x 29..79, the code keeps plinth, slipway and signs): a blue
stepped roof on stacked-brick posts, a cross gable on its own pad facing the path, the lifeboat in its mouth, a lane to the water.
Authored in the boathouse's local frame at its final 1.2 scale: ground z 0 (the plate top), origin the boathouse ground centre.
Game frame: right = -80 - y, fwd = 58 + x (the export flips Blender X); the sea is +x, the plaza -x, the cove -Y.
The Lv3 bay lies along the cove quay (y -35..-47 over the water, x 12.6..36, clear of the Lv1 lane) because the Harbour pontoon (right -32..-24,
fwd 60..140) closes the cove beyond y -48; the ramp runs out toward the sea along the channel.

Lv3 (engine: the boathouse launches a lifeboat quickly): a third hall on a 37.5 x 12 stud timber jetty deck: one tall stepped red gable (ridge along Y,
facing the path, "03" sticker, a blue lookout with a studded cap on the ridge) over a blue ready room with a walk-in door and the code "Launch" sign on
the path side, slim stacked-brick corner piers. Beside it, in the open, a yellow winch whose cable hooks a yellow trolley at the top of the slipway carrying an
orange-and-white Lego lifeboat, tilted bow-down to the sea. A big green go lamp on its own banded mast off the deck's sea end (the deck takes Lv2's wet lane's spot, Lv2_L05_LaneWet drops at Lv3). The stone slipway runs on to
below the water (x 36..52). The static lifeboat is its own mesh (Lv3_L07_Lifeboat) so code can hide it while a spawned boat launches
from ATT_Launch.

Layers: L01_Deck, L02_QuayEdge (the kerb), L03_Ramp, L04_Roof, L05_ReadyRoom, L06_Launch, L07_Lifeboat (one palette
mesh each, flat colours via UVs, one draw call per layer). Collision: one simple box per object, Lv3_ColNN_COL, so the deck, ramp and
walk-in room stay open. Attachments: ATT_Launch (ramp), ATT_Work_Winch (behind the winch), ATT_ReadyRoom.

    python3 art/source/buildings/M_Bld_BoathouseAddons/maketex.py \
        --out build/prod/M_Bld_BoathouseAddons/textures/M_Bld_BoathouseAddons \
        --name Boathouse --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- \
        --build art/source/buildings/M_Bld_BoathouseAddons/build.py \
        --out-root build/prod/M_Bld_BoathouseAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_BoathouseAddons"
BUDGET = "hero_building"   # Lv1 + Lv2 joined (PERF-BL11): 40k class, one flat palette set (waived)
TIER = "standard"
SET_NAME, SET = "Boathouse", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_Boathouse_Brick_ALB.png")

WATER, DECK = -4.0, 0.55
# Game frame: right = -80 - y, fwd = 58 + x (Boathouse spot isle(-80, 58, -90); Blender X flips on export). Sea = +x.
# PERF-BL11 r4: Lv3 reads alone: the hall stands at the deck's sea end, right of Lv2's boat and clear of the sign from the plaza, and the low launch
# runs the other way (turned 180 deg about LAUNCH_X / 2, YC), so only low things stand in front of Lv2's colonnade.
BAY = (30.0, 67.5, -35.0, -47.0)             # deck x0 (ramp head), x1 (sea end, past Lv2's lane: r6), y0 (quay side), y1 (water side)
YC = -41.0                                   # the bay's centre line (ramp, winch)
KERB = ((32.0, 54.0),)                       # studded kerb on the plate edge
LAUNCH_X = 66.0                              # local x -> LAUNCH_X - x: the head at 30, the water end at 14
RAMP = (36.0, 52.0, -36.5, -45.5)            # local: x head (deck end), x water end, y quay side, y water side
RAILS = (-38.5, -43.5)
CRADLE = (1.0, 12.0)                         # trolley s0 (winch end) .. s1 (water end), along the slope from the head
HALL = (44.0, 61.0, -45.0, -38.0)            # the blue cabin: x0, x1, y0 (front, the path side), y1 (quay side); r6: on the deck over Lv2's wet lane, a sky gap past the Lifeboat gable
HALL_CX = (HALL[0] + HALL[1]) / 2
HALL_DOOR, HALL_DOOR_Z = 3.60, 7.40          # the door's half width, head
HALL_ROOF = (9.50, 11.90, 6, 1.20, -45.80, -37.90)    # half width, eave, courses, rise, y0, y1: ridge 19.1, cap 20.6 (the cap's back end clears the Lifeboat sign from the plaza)
HALL_TOP, HALL_FASCIA = 11.25, 10.50          # wall top, the fascia's top
LAUNCH_Z, LAUNCH_HW, LAUNCH_HH, LAUNCH_Y = 10.20, 7.00, 1.55, -45.60   # DockPieces.boathouseLevel: the code sign "Launch" over the hall's door, 14 x 3.1
MAST_X, MAST_Y, LAMP_Z = 69.10, -45.8, 22.0  # the go-lamp mast off the deck's sea end: Lv3's own peak, sky either side, the head inside the path frame
SLOPE = math.atan2(DECK + 4.2, RAMP[1] - RAMP[0])   # the ramp's pitch (down toward the sea)
WINCH = (32.4, -41.0)                        # local, like RAMP


def launch_turn(x, y, z):
    """The launch's local frame (ramp toward +x, as authored) -> the world: turned 180 deg, the ramp runs toward the plaza."""
    return (LAUNCH_X - x, 2 * YC - y, z)


def patch_lod_targets():
    """LODs keep the large_prop shares (50% / 25%): the hero_building LOD2 ceiling collapses the small Lego detail."""
    import budgets
    orig = getattr(budgets, "_by_orig_lod_target", budgets.lod_target)
    budgets._by_orig_lod_target = orig
    budgets.lod_target = lambda budget_class, lod, lod0_tris, asset_tris=None: orig("large_prop", lod, lod0_tris)


def patch_lod_names():
    """Layer meshes use game node names (Lv3_L01_...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ small helpers
def grid_studs(b, x0, x1, y0, y1, z, c, nx=2, ny=6, r=0.42, h=0.24, n=8):
    for i in range(nx):
        for j in range(ny):
            b.cyl(x0 + (i + 0.5) * (x1 - x0) / nx, y0 + (j + 0.5) * (y1 - y0) / ny,
                  z, z + h, r, c, n, bottom=False)


def planks(b, x0, x1, y0, y1, z, along_y=True, pitch=1.02, run=4.40):
    """Tan deck planks: dark seam lines between the boards and staggered butt joints, flat on the deck top."""
    a0, a1, c0, c1 = (x0, x1, y0, y1) if along_y else (y0, y1, x0, x1)    # across the boards, along them

    def seam(p0, q0, p1, q1):
        lo, hi = ((p0, q0, z), (p1, q1, z + 0.03)) if along_y else ((q0, p0, z), (q1, p1, z + 0.03))
        b.box(lo, hi, P.DTAN, bevel=0.01)

    n = max(1, round((a1 - a0) / pitch))
    w = (a1 - a0) / n
    for i in range(1, n):
        seam(a0 + i * w - 0.03, c0, a0 + i * w + 0.03, c1)
    for i in range(n):
        y = c0 + (i * 1.7) % run
        while y < c1 - 0.2:
            if y > c0 + 0.2:
                seam(a0 + i * w + 0.03, y - 0.03, a0 + (i + 1) * w - 0.03, y + 0.03)
            y += run


def disc_y(b, cx, cy, cz, r, length, c, n=10):
    """A closed cylinder along Y (go-light lens)."""
    y0, y1 = cy - length / 2, cy + length / 2
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def torus_y(b, cx, cy, cz, R, r, c, maj=10, mnr=4):
    """A ring around the Y axis (the white rim on the go light)."""
    verts = []
    for i in range(maj):
        u = 2 * math.pi * i / maj
        for j in range(mnr):
            v = 2 * math.pi * j / mnr
            verts.append((cx + (R + r * math.cos(v)) * math.cos(u), cy + r * math.sin(v),
                          cz + (R + r * math.cos(v)) * math.sin(u)))
    faces = []
    for i in range(maj):
        for j in range(mnr):
            a, b2 = i * mnr, ((i + 1) % maj) * mnr
            k = (j + 1) % mnr
            faces.append((a + j, b2 + j, b2 + k, a + k))
    b._emit(verts, faces, c)


def rope(b, p0, p1, sag, c=P.BLACK, n=3, w=0.09):
    """A slack line between two points (short beams, lowest in the middle)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t,
                    p0[2] + (p1[2] - p0[2]) * t - sag * math.sin(math.pi * t)))
    for a, b2 in zip(pts, pts[1:]):
        b.beam(a, b2, w, w, c)


def z_ramp(x):
    """Ramp top height at x (flat DECK to the head x RAMP[0], then down to -4.2 at the water end x RAMP[1])."""
    if x <= RAMP[0]:
        return DECK
    return DECK + (x - RAMP[0]) * ((-4.2 - DECK) / (RAMP[1] - RAMP[0]))


def tilt(src, dst):
    """Copy a builder made flat (x = RAMP head + distance along the slope, z = height above the ramp) onto the
    slope: rotate about the ramp head (x RAMP[0], z DECK) by the ramp pitch."""
    c, s = math.cos(SLOPE), math.sin(SLOPE)
    base = len(dst.v)
    for x, y, z in src.v:
        dx, dz = x - RAMP[0], z
        dst.v.append((RAMP[0] + dx * c + dz * s, y, DECK - dx * s + dz * c))
    dst.f.extend((tuple(base + i for i in f), cell) for f, cell in src.f)


def prism_y(b, y0, y1, prof, c):
    """A closed (x, z) profile extruded along Y (the ramp wedge)."""
    n = len(prof)
    verts = [(x, y0, z) for x, z in prof] + [(x, y1, z) for x, z in prof]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def column(b, x, y, z0, z1, top_studs=True, k=1.0, n=None, foot=0.80, stepped=False, cap_studs=False, band=False, cap=1.55):
    """A stacked-brick post, Lv2's and Lv3's: a grey footing with corner studs, white / pale courses, a bevelled red cap. k scales its width;
    stepped adds a wider first footing course (half of foot) and a neck under the cap; band adds a dark base seam and a proud red middle course."""
    f = 1.70 * k
    if stepped:
        b.box((x - f - 0.30, y - f - 0.30, z0), (x + f + 0.30, y + f + 0.30, z0 + foot * 0.55), P.STONE, bevel=0.12)
    b.box((x - f, y - f, z0 + (foot * 0.55 if stepped else 0.0)), (x + f, y + f, z0 + foot), P.STONE, bevel=0.12)
    if top_studs:
        for sx in (-f + 0.32, f - 0.32):
            for sy in (-f + 0.32, f - 0.32):
                b.cyl(x + sx, y + sy, z0 + foot, z0 + foot + 0.20, 0.24, P.STONE, 6, bottom=False)
    z, zc = z0 + foot, z1 - 0.70
    zt = zc - 0.40 if stepped else zc
    if band:
        b.box((x - 1.15 * k, y - 1.15 * k, z), (x + 1.15 * k, y + 1.15 * k, z + 0.30), P.DBG, bevel=0.04)
        z += 0.30
    n = n or max(2, round((zt - z) / 1.9))
    h = (zt - z) / n
    for i in range(n):
        red = band and i == n // 2
        d = 0.24 if red else 0.0 if i % 2 else 0.12
        s = 1.10 * k + d
        b.box((x - s, y - s, z + i * h), (x + s, y + s, z + (i + 1) * h + 0.02), P.RED if red else P.WHITE if i % 2 == 0 else P.LBG, bevel=0.12)
    if stepped:
        b.box((x - 1.32 * k, y - 1.32 * k, zt), (x + 1.32 * k, y + 1.32 * k, zc), P.RED, bevel=0.10)
    b.box((x - cap * k, y - cap * k, zc), (x + cap * k, y + cap * k, z1), P.RED, bevel=0.14)
    if cap_studs:
        for sx in (-1.0 * k, 1.0 * k):
            for sy in (-1.0 * k, 1.0 * k):
                b.cyl(x + sx, y + sy, z1, z1 + 0.18, 0.24, P.RED, 6, bottom=False)


def fascia(b, u0, u1, v, s, ez, along_x=True, pitch=3.0):
    """Eave trim on the outer plane v (s = the outward sign): one course of white bricks in 3-stud lengths with vertical seams over a pale
    backing, a red trim plate on top."""
    def plate(a, d, o, z0, z1, c, bev):
        i0, i1 = sorted((v - s * 0.5, v + s * o))
        b.box(*(((a, i0, z0), (d, i1, z1)) if along_x else ((i0, a, z0), (i1, d, z1))), c, bevel=bev)
    plate(u0, u1, 0.05, ez - 0.90, ez, P.LBG, 0.0)
    n = max(1, round((u1 - u0) / pitch))
    w = (u1 - u0) / n
    for i in range(n):
        plate(u0 + i * w + 0.08, u0 + (i + 1) * w - 0.08, 0.24, ez - 0.86, ez - 0.04, P.WHITE, 0.07)
    plate(u0 - 0.1, u1 + 0.1, 0.44, ez, ez + 0.35, P.RED, 0.10)


def rakes(b, pt, hw, dx, ez, rise, c, w=0.50, fascia=P.WHITE):
    """A continuous bevelled barge board over a stepped roof's gable end, both slopes, a thin white fascia under it: the stair's ends read as
    one clean line. pt(u, z) -> (x, y, z)."""
    k = rise / dx
    h = 1.15 * dx * rise / math.hypot(dx, rise)
    off = h / 2 * math.hypot(1.0, k)
    d = (h / 2 + 0.22) * math.hypot(1.0, k)     # the fascia's drop, bedded 0.03 into the board
    for s in (-1, 1):
        b.beam(pt(s * (hw + 0.1), ez + rise - 0.1 * k - off), pt(s * 1.0, ez + rise + (hw - 1.0) * k - off), w, h, c)
        b.beam(pt(s * (hw + 0.1), ez + rise - 0.1 * k - off - d), pt(0.0, ez + rise + hw * k - off - d), w - 0.14, 0.50, fascia)


# ------------------------------------------------------------------ L01 deck
def lv3_deck(b):
    """Timber deck on thick 2x2 columns, a studded yellow rim round the water edges."""
    x0, x1, y0, y1 = BAY
    b.box((x0 - 0.12, y1 - 0.12, 0.15), (x1 + 0.12, y0, DECK - 0.10), P.DBG, bevel=0.05)      # the dark edge trim
    nx, w, dd = 8, (x1 - x0) / 8, (y0 - y1) / 2                                  # tan plates, dark seams between
    for i in range(nx):
        for j in range(2):
            b.box((x0 + i * w + 0.025, y1 + j * dd + 0.025, DECK - 0.15), (x0 + (i + 1) * w - 0.025, y1 + (j + 1) * dd - 0.025, DECK), P.TAN, bevel=0.06)
    b.stud_row(x0 + 1.2, y1 + 0.95, x1 - 1.2, y1 + 0.95, DECK, P.TAN, spacing=2.55, r=0.36, h=0.20, n=6)
    for x in (31.60, 36.40):                                                     # two bollards
        b.box((x - 0.85, -45.25, DECK), (x + 0.85, -43.55, DECK + 0.35), P.STONE, bevel=0.08)
        b.cyl(x, -44.40, DECK + 0.35, DECK + 1.55, 0.58, P.DBG, 8, bottom=False)
        b.cyl(x, -44.40, DECK + 1.55, DECK + 1.95, 0.80, P.YELLOW, 8)
    r = 0.4                                                                      # a calm white edge trim: water edge, sea end, the head's corners
    for lo, hi in (((x0, y1, DECK), (x1, y1 + r, DECK + 0.25)), ((x1 - r, y1 + r + 0.05, DECK), (x1, y0, DECK + 0.25)),
                   ((x0, y0 - 1.5, DECK), (x0 + r, y0, DECK + 0.25)), ((x0, y1 + r + 0.05, DECK), (x0 + r, y1 + 1.5, DECK + 0.25))):
        b.box(lo, hi, P.WHITE, bevel=0.05)
    far = [(x, y1 + 1.9) for x in (32.0, 43.5, 54.5, 66.3)]
    mid = [(x, -39.0) for x in (32.0, 66.3)]
    for x, y in far + mid:
        column(b, x, y, WATER - 0.6, 0.15, top_studs=False, k=0.7, n=3, band=True)
    # where Lv2's lane meets the deck (its wet end drops at Lv3): a low stop bar over the rail ends, walk-over
    b.box((BAY_CX - LANE2_HW - 0.10, -36.40, DECK - 0.05), (BAY_CX + LANE2_HW + 0.10, -34.96, 1.25), P.STONE, bevel=0.10)
    b.stud_row(BAY_CX - LANE2_HW + 0.8, -35.68, BAY_CX + LANE2_HW - 0.8, -35.68, 1.25, P.STONE, spacing=2.4, r=0.34, h=0.18, n=6)


# ------------------------------------------------------------------ L02 quay kerb
def lv3_quay(b):
    """A short raised studded kerb tied to the bay on the plate edge."""
    for x0, x1 in KERB:
        b.box((x0, -35.0, 0.0), (x1, -33.8, 0.5), P.STONE, bevel=0.06)
        b.stud_row(x0 + 1.5, -34.4, x1 - 1.5, -34.4, 0.5, P.STONE, spacing=2.4, r=0.42, h=0.2, n=6)


# ------------------------------------------------------------------ L03 ramp
def lv3_ramp(b):
    """The slipway: stone wedge from the deck head down below the water, dark rails, stone curbs, yellow handrails."""
    xh, xw, ya, yb = RAMP
    prism_y(b, yb, ya, [(xh, DECK), (xw, -4.2), (xw, -4.8), (xh, 0.15)], P.STONE)
    for y in RAILS:
        b.beam((xh - 2.0, y, DECK + 0.08), (xw - 0.4, y, -4.10), 0.6, 0.22, P.DBG)
    for i in range(6):                                                           # dark sleeper plates under the rails
        x = xh + 1.3 + i * 2.5
        b.beam((x, ya - 0.75, z_ramp(x) + 0.05), (x, yb + 0.75, z_ramp(x) + 0.05), 1.10, 0.10, P.DBG)
    for y in (ya - 0.35, yb + 0.35):
        b.beam((xh, y, DECK + 0.15), (xw - 0.3, y, -4.05), 0.7, 0.5, P.STONE)
    for y in (ya - 0.35, yb + 0.35):                                             # chunky yellow curb tops (was thin handrails)
        b.beam((xh, y, DECK + 0.50), (xw - 0.3, y, -3.70), 0.9, 0.3, P.YELLOW)


# ------------------------------------------------------------------ L04 roof
def lv3_roof(b):
    """The hall: one studded red gable at the main roof's slope, ridge along Y, barge boards, white coursed gable walls, the "03" sticker on the path side."""
    x0, x1, y0, y1 = HALL
    hw, ez, n, rise, ra, rb = HALL_ROOF
    warped(b, lambda t: stepped_roof(t, hw, n, ez, rise, ra, rb, P.RED, P.RRED, P.RRED), lambda x, y, z: (x + HALL_CX, y, z))
    for y in (ra, rb):
        rakes(b, lambda u, z, y=y: (HALL_CX + u, y, z), hw, hw / n, ez, rise, P.RRED)
    for ya, yb, z0 in ((y0, y0 + 0.90, HALL_FASCIA + 0.20), (y1 - 0.90, y1, HALL_TOP)):
        b.box((x0 + 0.90, ya + 0.05, z0), (x1 - 0.90, yb - 0.05, ez + 0.05), P.WHITE, bevel=0.0)
        stepped_gable(b, HALL_CX, hw - 0.60, n, ez - 0.05, rise, ya, yb, P.WHITE, seams=P.LBG)
    sign_frame(b, HALL_CX, LAUNCH_Z, LAUNCH_HW, LAUNCH_HH, LAUNCH_Y, t=0.55)
    hull_sticker(b, HALL_CX, 14.45, "03", y0 - 0.20, k=1.0)       # as big as 01, over the Launch plaque, clear of the barge boards
    # the lookout on the ridge: Lv3's own shape (Lv1 and Lv2 are plain gables), blue with a window each way, a big studded red cap
    ly, hx, hy, z0, z1 = -42.30, 2.80, 2.40, 17.20, 21.40
    b.box((HALL_CX - hx, ly - hy, z0), (HALL_CX + hx, ly + hy, z1), P.BLUE, bevel=0.0)
    b.box((HALL_CX - hx - 0.18, ly - hy - 0.18, 18.30), (HALL_CX + hx + 0.18, ly + hy + 0.18, 18.72), P.WHITE, bevel=0.06)
    for u0, u1 in ((-hy + 0.65, hy - 0.65),):
        b.box((HALL_CX - hx - 0.08, ly + u0, 18.95), (HALL_CX + hx + 0.08, ly + u1, 20.85), P.GLASS, bevel=0.0)
    for u0, u1 in ((-hx + 0.65, hx - 0.65),):
        b.box((HALL_CX + u0, ly - hy - 0.08, 18.95), (HALL_CX + u1, ly + hy + 0.08, 20.85), P.GLASS, bevel=0.0)
    b.box((HALL_CX - hx - 0.70, ly - hy - 0.70, z1), (HALL_CX + hx + 0.70, ly + hy + 0.70, z1 + 0.70), P.RED, bevel=0.14)
    b.box((HALL_CX - hx + 0.20, ly - hy + 0.20, z1 + 0.70), (HALL_CX + hx - 0.20, ly + hy - 0.20, z1 + 1.30), P.WHITE, bevel=0.12)
    grid_studs(b, HALL_CX - hx + 0.5, HALL_CX + hx - 0.5, ly - hy + 0.5, ly + hy - 0.5, z1 + 1.30, P.WHITE, nx=2, ny=2, r=0.75, h=0.32, n=8)


# ------------------------------------------------------------------ L05 ready room
def jacket(b, x, y, z):
    """One orange life jacket hanging on the quay-side wall (front faces -Y), white bands and a dark zip."""
    b.box((x - 0.70, y - 0.42, z), (x + 0.70, y, z + 1.90), P.ORANGE, bevel=0.05)
    b.box((x - 0.55, y - 0.48, z + 1.90), (x + 0.55, y, z + 2.15), P.ORANGE, bevel=0.04)
    for zz in (0.45, 1.25):
        b.box((x - 0.70, y - 0.46, z + zz), (x + 0.70, y - 0.38, z + zz + 0.25), P.WHITE, bevel=0.01)
    b.box((x - 0.07, y - 0.48, z + 0.20), (x + 0.07, y - 0.40, z + 1.85), P.DBG, bevel=0.02)
    b.box((x - 0.11, y - 0.12, z + 2.15), (x + 0.11, y + 0.06, z + 2.35), P.DBG, bevel=0.02)


def lv3_room(b):
    """The blue ready room under the hall's gable: coursed brick walls, a big walk-in door with a red surround on the path side, one big window toward
    the plaza, stacked-brick corner piers, a brick course and red trim under the eaves; a lit back wall with four jackets, a bench."""
    x0, x1, y0, y1 = HALL
    cx, yc, t, top = HALL_CX, (y0 + y1) / 2, 0.90, HALL_TOP
    d0, d1 = cx - HALL_DOOR, cx + HALL_DOOR
    fz, zc = HALL_FASCIA, HALL_FASCIA - 0.90              # the fascia's top and bottom: the coursed wall ends under it
    win = (-2.40, 2.40, 3.40, 8.00)

    def side(w):
        L = (y1 - y0) / 2
        wall_holes(w, -L, L, 0.0, t, DECK, top, [win], P.BLUE)
        courses(w, 0.0, -1, -L, L, 1.55, zc, n=4, brick=3.60, holes=[(-3.10, 3.10, 2.70, 8.60)])
        window(w, 0.0, 4.80, 3.40, 8.00, 0.0)
        w.box((-L, -0.14, DECK), (L, 0.05, 1.55), P.RED, bevel=0.06)
        wall_holes(w, -L + t, L - t, t, t + 0.06, DECK + 0.02, top - 0.12, [win], P.LBG)   # lit, seen through the door
    for s, x in ((-1, x0), (1, x1)):
        turned(b, side, s, x, yc)
    # front wall: stubs and a header round the door
    for a, d in ((x0 + t, d0), (d1, x1 - t)):
        b.box((a, y0, DECK), (d, y0 + t, fz + 0.20), P.BLUE, bevel=0.0)
    b.box((d0, y0, HALL_DOOR_Z), (d1, y0 + t, fz + 0.20), P.BLUE, bevel=0.0)
    courses(b, y0, -1, x0 + t, x1 - t, 1.55, zc, n=4, brick=3.60, holes=[(d0 - 0.80, d1 + 0.80, 0.0, 9.0)])
    for a, d in ((x0 + t, d0 - 0.75), (d1 + 0.75, x1 - t)):
        b.box((a, y0 - 0.14, DECK), (d, y0 + 0.05, 1.55), P.RED, bevel=0.06)
    # the door's red surround, a jamb lining so the opening reads from the side
    for a, d in ((d0 - 0.70, d0), (d1, d1 + 0.70)):
        b.box((a, y0 - 0.30, DECK), (d, y0 + 0.05, HALL_DOOR_Z + 0.55), P.RED, bevel=0.10)
    b.box((d0, y0 - 0.30, HALL_DOOR_Z), (d1, y0 + 0.05, HALL_DOOR_Z + 0.55), P.RED, bevel=0.10)
    # back wall: blue outside, lit inside
    b.box((x0 + t, y1 - t, DECK), (x1 - t, y1, top), P.BLUE, bevel=0.0)
    b.box((x0 + t, y1 - t - 0.06, DECK + 0.02), (x1 - t, y1 - t, top - 0.12), P.LBG, bevel=0.0)
    b.box((x0 + t, y0 + t, top - 0.10), (x1 - t, y1 - t, top), P.WHITE, bevel=0.0)                 # ceiling
    for x in (cx - 3.60, cx - 1.20, cx + 1.20, cx + 3.60):
        jacket(b, x, y1 - t - 0.06, 3.00)
    # bench along the sea-side wall: grey frame, orange seat and back
    bx0, bx1, by0, by1 = x1 - t - 1.80, x1 - t, y0 + 1.40, y1 - 1.60
    b.box((bx0, by0, DECK), (bx1 - 0.06, by1, 2.40), P.STONE, bevel=0.04)
    b.box((bx0 - 0.05, by0 - 0.05, 2.40), (bx1 - 0.06, by1 + 0.05, 2.80), P.ORANGE, bevel=0.05)
    b.box((bx1 - 0.36, by0, 2.80), (bx1 - 0.06, by1, 4.60), P.ORANGE, bevel=0.05)
    # corner piers: Lv2's post at 80%, three courses, red stud caps
    for x in (x0 + 0.35, x1 - 0.35):
        for y in (y0 + 0.35, y1 - 0.35):
            column(b, x, y, DECK, zc, k=0.8, n=3, foot=0.60, cap_studs=True)
    fascia(b, x0 - 0.10, x1 + 0.10, y0, -1, fz)
    fascia(b, x0 - 0.10, x1 + 0.10, y1, 1, fz)
    for x, s in ((x0, -1), (x1, 1)):
        fascia(b, y0 + 0.50, y1 - 0.50, x, s, fz, along_x=False)


# ------------------------------------------------------------------ L06 launch
def lv3_winch(b):
    """One clean grey winch: a studded base, two side plates, a yellow drum (along Y; the cable leaves toward the ramp)."""
    x, y = WINCH
    b.box((x - 1.60, y - 1.90, DECK), (x + 1.60, y + 1.90, DECK + 0.50), P.STONE, bevel=0.06)
    grid_studs(b, x - 1.30, x + 1.30, y - 1.60, y + 1.60, DECK + 0.50, P.STONE, nx=2, ny=2, r=0.32, h=0.18, n=6)
    for ya, yb in ((y - 1.75, y - 1.30), (y + 1.30, y + 1.75)):
        b.box((x - 1.30, ya, DECK + 0.50), (x + 1.30, yb, 4.40), P.STONE, bevel=0.06)
    disc_y(b, x, y, 3.20, 1.15, 2.40, P.YELLOW, 12)


def lv3_cradle(b):
    """A plain grey trolley at the top of the slipway, tilted down the slope, seated on the rails: two long bunks on black wheels, three cross
    members, a hook eye at the winch end. Built flat, then tilt()."""
    t = lego.B()
    s0, s1 = RAMP[0] + CRADLE[0], RAMP[0] + CRADLE[1]
    for ry in RAILS:
        t.box((s0, ry - 0.8, 0.9), (s1, ry + 0.8, 2.6), P.STONE, bevel=0.08)        # the hull bilge rests on them
        for wx in (s0 + 1.2, s1 - 1.2):
            disc_y(t, wx, ry, 0.75, 0.7, 1.2, P.BLACK, 10)
    for wx in (s0 + 1.2, (s0 + s1) / 2, s1 - 1.2):
        t.box((wx - 0.6, RAILS[1] + 0.8, 1.0), (wx + 0.6, RAILS[0] - 0.8, 1.9), P.DBG, bevel=0.05)
    t.box((s0 - 1.0, YC - 0.6, 1.0), (s0, YC + 0.6, 1.9), P.DBG, bevel=0.05)                            # hook eye
    tilt(t, b)


def lifeboat_hull(t, s0, s1, yc, keel=1.9, k=1.0):
    """Orange-and-white Lego lifeboat flat along +X, bow at s1: orange hull, white gunwale deck, white wheelhouse with a
    navy window band, orange studded roof. k scales its beam and height over the keel."""
    def Z(z):
        return keel + (z - 1.9) * k
    w0 = 2.3 * k
    st = ((s0, w0, Z(1.9), Z(4.5)), (s0 + 7.0, w0, Z(1.9), Z(4.5)), (s1 - 2.4, 1.8 * k, Z(2.3), Z(4.7)), (s1, 0.35 * k, Z(3.5), Z(5.1)))
    for q, u0, u1, c in ((0.62, 0.0, 0.30, P.RED), (0.86, 0.30, 0.64, P.ORANGE), (1.0, 0.64, 1.0, P.ORANGE)):     # stepped brick courses, a red waterline
        t.loft([[(x, yc + sy * w * q, bot + (top - bot) * u) for sy, u in ((1, u1), (1, u0), (-1, u0), (-1, u1))]
                for x, w, bot, top in st], c)
    t.loft([[(x, yc + sy * (w + 0.15), z) for sy, z in ((1, top), (1, top + 0.6), (-1, top + 0.6), (-1, top))]
            for x, w, bot, top in st[:3] + ((s1 + 0.1, 0.5 * k, 0, Z(5.1)),)], P.WHITE)
    t.box((s0 - 0.1, yc - w0 - 0.2, Z(3.4)), (s0 + 0.3, yc + w0 + 0.2, Z(4.0)), P.INK, bevel=0.03)        # transom band
    c0, c1 = s0 + 1.6 * k, s0 + 6.8 * k                                                                   # wheelhouse
    hw = 1.7 * k
    t.box((c0, yc - hw, Z(5.0)), (c1, yc + hw, Z(7.5)), P.WHITE, bevel=0.08)
    t.box((c0 + 0.6, yc - hw - 0.08, Z(6.2)), (c1 - 0.4, yc + hw + 0.08, Z(7.0)), P.INK, bevel=0.02)
    t.box((c1 - 0.1, yc - hw + 0.4, Z(6.2)), (c1 + 0.08, yc + hw - 0.4, Z(7.0)), P.INK, bevel=0.02)
    t.box((c0 - 0.2, yc - hw - 0.25, Z(7.5)), (c1 + 0.3, yc + hw + 0.25, Z(7.5) + 0.45), P.ORANGE, bevel=0.06)
    grid_studs(t, c0 + 0.4, c1 - 0.4, yc - hw + 0.1, yc + hw - 0.1, Z(7.5) + 0.45, P.ORANGE, nx=3, ny=2, r=0.42, h=0.22, n=6)
    t.stud_row(c1 + 1.0, yc, s1 - 2.0, yc, Z(5.1), P.WHITE, spacing=1.9, r=0.55, h=0.24, n=8)             # foredeck


def lifeboat(b):
    """The Lv3 lifeboat on the trolley, bow down the ramp, tilted down the slope."""
    def local(u):
        t = lego.B()
        lifeboat_hull(t, RAMP[0] + CRADLE[0], RAMP[0] + CRADLE[1] + 0.4, YC, k=1.15)
        tilt(t, u)
    warped(b, local, launch_turn)


def lv3_golight(b):
    """Big green go lamp on its own banded mast at the deck's sea corner: a two-course stepped studded plinth in the water, chunky white-and-red
    courses, a yellow stepped bracket, a bevelled studded yellow head, a green lens with a white ring each way (toward the plaza and out to sea)."""
    x, y = MAST_X, MAST_Y
    hx, hy, hz, lens = 1.95, 2.60, 2.85, 1.17
    b.box((x - 1.40, y - 1.40, WATER - 0.6), (x + 1.40, y + 1.40, -0.30), P.STONE, bevel=0.12)   # 1.40: the Harbour pontoon starts at y -48
    for sx in (-1.18, 1.18):
        for sy in (-1.18, 1.18):
            b.cyl(x + sx, y + sy, -0.30, -0.08, 0.18, P.STONE, 6, bottom=False)
    b.box((x - 1.20, y - 1.20, -0.30), (x + 1.20, y + 1.20, 0.45), P.STONE, bevel=0.10)          # brick courses, a dark seam
    b.box((x - 1.05, y - 1.05, 0.45), (x + 1.05, y + 1.05, 0.60), P.DBG, bevel=0.0)
    b.box((x - 1.20, y - 1.20, 0.60), (x + 1.20, y + 1.20, 1.10), P.STONE, bevel=0.10)
    for sx in (-0.92, 0.92):
        for sy in (-0.92, 0.92):
            b.cyl(x + sx, y + sy, 1.10, 1.32, 0.20, P.STONE, 6, bottom=False)
    z0, z1 = 1.10, LAMP_Z - hz - 1.00
    n = 5
    h = (z1 - z0) / n
    for i in range(n):
        d = 0.0 if i % 2 else 0.12
        b.box((x - 0.95 - d, y - 0.95 - d, z0 + i * h), (x + 0.95 + d, y + 0.95 + d, z0 + (i + 1) * h + 0.02), P.WHITE if i % 2 else P.RED, bevel=0.10)
    b.box((x - 1.35, y - 1.35, z1), (x + 1.35, y + 1.35, z1 + 0.50), P.STONE, bevel=0.10)       # the chunky stepped bracket, the head centred on it
    b.box((x - hx + 0.15, y - hy + 0.15, z1 + 0.50), (x + hx - 0.15, y + hy - 0.15, LAMP_Z - hz), P.STONE, bevel=0.12)
    b.box((x - hx, y - hy, LAMP_Z - hz), (x + hx, y + hy, LAMP_Z + hz), P.YELLOW, bevel=0.20)
    b.box((x - hx - 0.22, y - hy - 0.22, LAMP_Z + hz), (x + hx + 0.22, y + hy + 0.22, LAMP_Z + hz + 0.55), P.RED, bevel=0.18)    # the bevelled studded hood
    grid_studs(b, x - hx + 0.1, x + hx - 0.1, y - hy + 0.1, y + hy - 0.1, LAMP_Z + hz + 0.55, P.RED, nx=2, ny=2, r=0.60, h=0.28, n=8)
    for sx in (1, -1):
        xx = x + sx * hx
        b.cyl_x(xx + sx * 0.15, y, LAMP_Z, 2.05 * lens, 0.30, P.DBG, 14)
        b.cyl_x(xx + sx * 0.45, y, LAMP_Z, 1.75 * lens, 0.60, P.GREEN, 14)
        b.torus(xx + sx * 0.55, y, LAMP_Z, 1.98 * lens, 0.26, P.WHITE, 14, 4)


def lv3_launch(b):
    lv3_golight(b)

    def local(t):
        lv3_winch(t)
        lv3_cradle(t)
        x, y = WINCH
        c, s = math.cos(SLOPE), math.sin(SLOPE)
        hx = RAMP[0] + (CRADLE[0] - 1.0) * c + 1.45 * s                                 # the tilted hook eye
        rope(t, (x + 1.0, y, 3.45), (hx, y, DECK - (CRADLE[0] - 1.0) * s + 1.45 * c), 0.25, P.DBG, 4, 0.16)
    warped(b, local, launch_turn)


# ------------------------------------------------------------------ PERF-BL11: Lv1 and Lv2 as meshes
PLINTH = 0.48                              # the code plinth's top (0.4 x 1.2); the code keeps plinth, name sign, board slot
SIDE_X, FACE_Y, WALL_T = 18.48, 22.08, 0.96     # outer faces (the code walls x 1.2)
WALL_TOP = 15.70                           # under the white course (z 15.6..16.8)
EAVE, ROOF_N, RISE, ROOF_HW, ROOF_END = 16.80, 8, 1.05, 19.44, 23.04    # the code gable x 1.2: ridge 25.2
ARCH_RX, ARCH_RZ, ARCH_Z, ARCH_N = 12.00, 8.20, 6.00, 15    # the clear opening stays the code's +-12; crown z 14.2
RING_RX, RING_RZ = 13.30, 9.40
SHUT_Z = 10.50                             # the half-rolled door's bottom edge
LANE_HW, LANE_Z, LANE_Y0, LANE_Y1 = 5.20, 0.62, -35.00, 4.00   # the boat lane: walk-over, no collision
RAIL_X = 3.20
LANE2_HW, LANE2_RAIL, LANE2_RW, LANE2_RH = 6.24, 3.68, 1.36, 0.50   # Lv2's lane: 20% wider, the rails 1.5x, under the boat's stands (RAIL_X x BOAT_K)
WIN_W, WIN_Z0, WIN_Z1 = 6.34, 6.65, 11.83    # Lv1's side windows, +20%
PIL_US = (-5.40, 5.40)                        # Lv1's side pilasters, between the windows
WATER_Y = -47.00
SIGN_Z, SIGN_HW, SIGN_HH, SIGN_Y = 18.00, 9.30, 1.86, -23.34   # DockPieces.boathouse: the code sign 18.6 x 3.72, front y -23.58
SHED_X0, SHED_X1, SHED_CX = 29.00, 79.00, 54.00  # the code lifeboatSlip (1x): plinth y +-12, top 0.8
SHED_Y, SHED_TOP, SHED_EAVE = 12.00, 0.80, 11.80
SHED_BAND, SHED_OVER = 9.60, 1.00          # the red plate band's underside; the roof's eave overhang
SHED_RISE, SHED_N = 1.20, 6                # ridge 19 (the code's 16.8 + 2.2)
BAY_CX, BAY_HW, BAY_N, BAY_RISE, BAY_EAVE = 61.00, 14.00, 7, 2.80, 13.20   # the path-facing cross gable: peak 32.8, Lv2's own silhouette
BAY_FACE, BAY_END = -19.60, -20.50         # PERF-BL11 r2: 7 nearer the path, on its own pad, clear of Lv3's ridge from the plaza
PAD_Y = -23.40                             # the pad's front edge, the walk's at -24
PAD_Z = 0.85                               # 0.05 over the code plinth
BOAT_K = 1.15                              # the Lv2 lifeboat: Lv1's workboat x this
BAYSIGN_Z, BAYSIGN_HW, BAYSIGN_HH, BAYSIGN_Y = 16.40, 11.00, 2.40, -20.85    # DockPieces.lifeboatSlip: the code sign 22 x 4.8 facing -Y
POST_XS = (30.40, 77.60)                   # shed back row: the corners, the dark back wall between
FRONT_XS = (30.40, 39.20, 48.00, 74.00)    # front row: 48 and 74 carry the bay's sides
POST_K, POST_R = 1.55, 1.90                # the shed posts' width factor, their collision half width
QUOIN_L, QUOIN_S = 2.20, 0.75              # a corner quoin's long and short sides


def keep_faces(b, keep):
    """Keep only these faces of the box just emitted (lego.B.box order: bottom, top, -Y, +X, +Y, -X)."""
    last = b.f[-6:]
    b.f[-6:] = [last[i] for i in keep]


def courses(b, y, s, u0, u1, z0, z1, n=6, brick=7.20, holes=(), c=P.DBLUE):
    """Staggered brick seams 0.05 proud of a wall face at y (s = the outward normal's sign); holes = (u0, u1, z0, z1)."""
    t, p = 0.12, 0.05
    a, d = sorted((y, y + s * p))
    back = 2 if s > 0 else 4

    def seg(ua, ub, za, zb, drop):
        b.box((ua, a, za), (ub, d, zb), c, bevel=0.0)
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


def wall_holes(b, x0, x1, y0, y1, z0, z1, holes, c):
    """A wall box with rectangular openings (u0, u1, zb, zt), sorted by u."""
    u = x0
    for h0, h1, zb, zt in holes:
        b.box((u, y0, z0), (h0, y1, z1), c, bevel=0.0)
        b.box((h0, y0, z0), (h1, y1, zb), c, bevel=0.0)
        b.box((h0, y0, zt), (h1, y1, z1), c, bevel=0.0)
        u = h1
    b.box((u, y0, z0), (x1, y1, z1), c, bevel=0.0)


def window(b, cx, w, z0, z1, y, s=-1, c=P.WHITE, sill=P.STONE):
    """A framed inset window on a wall face at y (s = the outward normal's sign): proud frame, glass 0.3 back, cross
    mullion, a stud-topped sill brick."""
    out, ins = y + s * 0.20, y - s * 0.30
    fa, fb = sorted((out, ins))
    for x0, x1 in ((cx - w / 2 - 0.40, cx - w / 2 + 0.16), (cx + w / 2 - 0.16, cx + w / 2 + 0.40)):
        b.box((x0, fa, z0 - 0.16), (x1, fb, z1 + 0.40), c, bevel=0.05)
    b.box((cx - w / 2 + 0.16, fa, z1 - 0.16), (cx + w / 2 - 0.16, fb, z1 + 0.40), c, bevel=0.05)
    b.box((cx - w / 2 + 0.16, fa, z0 - 0.16), (cx + w / 2 - 0.16, fb, z0 + 0.14), c, bevel=0.03)
    ga, gb = sorted((ins, ins - s * 0.10))
    b.box((cx - w / 2 + 0.16, ga, z0 + 0.14), (cx + w / 2 - 0.16, gb, z1 - 0.16), P.GLASS, bevel=0.0)
    ma, mb = sorted((ins + s * 0.04, ins + s * 0.16))
    b.box((cx - 0.15, ma, z0 + 0.14), (cx + 0.15, mb, z1 - 0.16), c, bevel=0.0)
    zm = (z0 + z1) / 2
    b.box((cx - w / 2 + 0.16, ma, zm - 0.15), (cx + w / 2 - 0.16, mb, zm + 0.15), c, bevel=0.0)
    sa, sb = sorted((y + s * 0.62, y))
    b.box((cx - w / 2 - 0.62, sa, z0 - 0.74), (cx + w / 2 + 0.62, sb, z0 - 0.26), sill, bevel=0.06)
    b.stud_row(cx - w / 2 - 0.2, y + s * 0.31, cx + w / 2 + 0.2, y + s * 0.31, z0 - 0.26, sill, spacing=1.6, r=0.24,
               h=0.14, n=6)


def turned(b, fn, s, X, Y=0.0):
    """fn(t) draws facing -Y at local y 0 in a temp; here it comes out facing s * X at (X, Y), local x along world Y."""
    t = lego.B()
    fn(t)
    k = len(b.v)
    b.v.extend((X - y, Y + x, z) if s > 0 else (X + y, Y - x, z) for x, y, z in t.v)
    b.f.extend((tuple(i + k for i in f), c) for f, c in t.f)


def warped(b, fn, f):
    """fn(t) draws in a temp; every vertex comes out through f(x, y, z)."""
    t = lego.B()
    fn(t)
    k = len(b.v)
    b.v.extend(f(*p) for p in t.v)
    b.f.extend((tuple(i + k for i in fc), c) for fc, c in t.f)


def stepped_roof(b, hw, n, eave, rise, y0, y1, c, edge, eave_c, band=None, band_c=P.WHITE, ridge=True, cap_c=None,
                 stud=3.60, r=0.95, end=1.20):
    """A thick stepped Lego roof, ridge along Y at x 0: bevelled courses, edge tiles at both ends, a stud row on every tread,
    an eave course, one band, a stepped ridge cap."""
    dx = hw / n
    for s in (-1, 1):
        for i in range(n):
            xo, xi = s * (hw - i * dx), s * (hw - (i + 1) * dx - 0.08)    # runs 0.08 under the next course: no shared plane
            x0, x1 = sorted((xo, xi))
            z0, z1 = eave + i * rise - (0.80 if i == 0 else 0.30), eave + (i + 1) * rise
            cc = eave_c if i == 0 else band_c if i == band else c
            b.box((x0, y0 + end, z0), (x1, y1 - end, z1), cc, bevel=0.10)
            for a, d in ((y0, y0 + end), (y1 - end, y1)):
                b.box((x0, a, z0), (x1, d, z1), edge, bevel=0.10)
            b.stud_row(s * (hw - (i + 0.5) * dx), y0 + end + stud / 2, s * (hw - (i + 0.5) * dx), y1 - end - stud / 2, z1, cc,
                       spacing=stud, r=min(r, 0.40 * dx), h=0.42, n=8)
    if ridge:
        zr = eave + n * rise
        cc = cap_c if cap_c is not None else P.WHITE
        b.box((-1.90, y0 - 0.08, zr - 0.20), (1.90, y1 + 0.08, zr + 0.75), cc, bevel=0.14)      # chunky, stepped ends
        b.box((-1.15, y0 + 0.90, zr + 0.75), (1.15, y1 - 0.90, zr + 1.50), cc, bevel=0.14)
        b.stud_row(0.0, y0 + 2.2, 0.0, y1 - 2.2, zr + 1.50, cc, spacing=stud, r=0.60, h=0.30, n=8)


def stepped_gable(b, cx, hw, n, eave, rise, y0, y1, c, trim=None, seams=None):
    """A stepped brick gable wall under the roof's edge tiles, in y0..y1; trim = a 1-stud edge brick on each step, seams = brick seams proud of both faces."""
    for i in range(n):
        d = hw * (1 - (i + 1) / n) + 0.30
        z0, z1 = eave + i * rise, eave + (i + 1) * rise + 0.10
        b.box((cx - d, y0, z0), (cx + d, y1, z1), c, bevel=0.06)
        if seams is not None:
            b.box((cx - d + 0.02, y0 - 0.04, z0 - 0.05), (cx + d - 0.02, y1 + 0.04, z0 + 0.05), seams, bevel=0.0)
            u = -d + (1.80 if i % 2 else 3.60)
            while u < d - 0.60:
                b.box((cx + u - 0.05, y0 - 0.04, z0 + 0.05), (cx + u + 0.05, y1 + 0.04, z1 - 0.12), seams, bevel=0.0)
                u += 3.60
        if trim is not None and d > 1.0:
            for s in (-1, 1):
                a, e = sorted((cx + s * d, cx + s * (d - 1.0)))
                b.box((a, y0 - 0.08, z0), (e, y1 + 0.08, z1), trim, bevel=0.06)


def sign_frame(b, cx, cz, hw, hh, y, c=P.RED, t=0.60):
    """A chunky frame proud of the code sign at y (front y - 0.24), a stud row on top."""
    y0, y1 = y - 0.50, y + 0.80
    b.box((cx - hw - t, y0, cz + hh), (cx + hw + t, y1, cz + hh + t), c, bevel=0.10)
    b.box((cx - hw - t, y0, cz - hh - t), (cx + hw + t, y1, cz - hh), c, bevel=0.10)
    for s in (-1, 1):
        a, d = sorted((cx + s * hw, cx + s * (hw + t)))
        b.box((a, y0, cz - hh), (d, y1, cz + hh), c, bevel=0.10)
    b.stud_row(cx - hw, (y0 + y1) / 2, cx + hw, (y0 + y1) / 2, cz + hh + t, c, spacing=2.6, r=0.34, h=0.20, n=8)


SEG = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abcdg", "G": "acdefh"}


def digit(b, ch, cx, cz, w, h, t, y0, y1, c):
    """One seven-segment brick digit on a plane y0..y1."""
    x0, x1, z0, z1, zm = cx - w / 2, cx + w / 2, cz - h / 2, cz + h / 2, cz
    bars = {"a": (x0, x1, z1 - t, z1), "d": (x0, x1, z0, z0 + t), "g": (x0, x1, zm - t / 2, zm + t / 2), "h": (cx, x1, zm - t / 2, zm + t / 2),
            "f": (x0, x0 + t, zm, z1), "e": (x0, x0 + t, z0, zm), "b": (x1 - t, x1, zm, z1), "c": (x1 - t, x1, z0, zm)}
    for k in SEG[ch]:
        a, d, e, f = bars[k]
        b.box((a, y0, e), (d, y1, f), c, bevel=0.0)


def hull_sticker(b, cx, cz, text, y, k=1.0):
    """The hull-number sticker: a chamfered plate with a hard navy outline, a white face, big navy digits."""
    hw, hh, ch = 3.30 * k, 1.90 * k, 0.70 * k

    def oct(d):
        a, e, f = hw + d, hh + d, ch
        return [(cx - a + f, cz - e), (cx + a - f, cz - e), (cx + a, cz - e + f), (cx + a, cz + e - f),
                (cx + a - f, cz + e), (cx - a + f, cz + e), (cx - a, cz + e - f), (cx - a, cz - e + f)]
    prism_y(b, y - 0.20, y + 0.30, oct(0.0), P.INK)
    prism_y(b, y - 0.30, y - 0.20, oct(-0.32 * k), P.WHITE)
    w = 1.75 * k
    for i, ch_ in enumerate(text):
        digit(b, ch_, cx + (i - (len(text) - 1) / 2) * (w + 0.60 * k), cz, w, 2.50 * k, 0.56 * k, y - 0.36, y - 0.28, P.INK)


# ---- Lv1
def lerp(p, q, u):
    return (p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u)


def arch_pts(rx, rz, n=ARCH_N):
    """Ellipse points left to right over the springline."""
    return [(-rx * math.cos(math.pi * i / n), ARCH_Z + rz * math.sin(math.pi * i / n)) for i in range(n + 1)]


def tile_spans(hw, rail, rw):
    """A sleeper's tiles across a lane, between the rails: 0.05 seams at the rails."""
    a, d = rail - rw / 2 - 0.05, rail + rw / 2 + 0.05
    return ((-hw + 0.5, -d), (-a, a), (d, hw - 0.5))


def lv1_floor(b):
    """The boat lane: a calm stone strip from the bay out over the walk to the quay edge, yellow rails, grey sleepers, a winch
    at its inner end. All walk-over: no collision but the winch."""
    y0, y1 = LANE_Y0, LANE_Y1
    b.box((-LANE_HW, y0, PLINTH - 0.04), (LANE_HW, y1, LANE_Z), P.STONE, bevel=0.05)
    y = y0 + 2.0
    while y < y1 - 1.0:                                     # raised sleeper tiles every 3 studs
        for u0, u1 in tile_spans(LANE_HW, RAIL_X, 0.90):
            b.box((u0, y - 0.50, LANE_Z - 0.02), (u1, y + 0.50, LANE_Z + 0.18), P.LBG, bevel=0.05)
        y += 3.0
    for x in (-RAIL_X, RAIL_X):
        b.box((x - 0.45, y0, LANE_Z), (x + 0.45, y1, LANE_Z + 0.34), P.YELLOW, bevel=0.06)
        b.box((x - 0.65, y1 - 1.20, LANE_Z), (x + 0.65, y1 + 0.10, LANE_Z + 0.60), P.YELLOW, bevel=0.10)    # the rail's end cap
        b.cyl(x, y1 - 0.55, LANE_Z + 0.60, LANE_Z + 0.78, 0.36, P.YELLOW, 6, bottom=False)
    for s in (-1, 1):                                       # a bevelled 1-stud kerb the whole length of the slab
        xa, xb = sorted((s * LANE_HW, s * (LANE_HW + 1.00)))
        b.box((xa, y0, 0.10), (xb, y1, LANE_Z + 0.26), P.LBG, bevel=0.10)
    for x0, x1 in ((-19.84, -LANE_HW), (LANE_HW, 19.84)):   # the bevelled rim of the code plinth
        b.box((x0, -23.44, PLINTH - 0.10), (x1, -22.64, PLINTH + 0.22), P.STONE, bevel=0.10)
    for x in (-19.84, 19.04):
        b.box((x, -22.64, PLINTH - 0.10), (x + 0.80, 23.44, PLINTH + 0.22), P.STONE, bevel=0.10)
    b.box((-19.04, 22.64, PLINTH - 0.10), (19.04, 23.44, PLINTH + 0.22), P.STONE, bevel=0.10)
    wy = y1 + 0.20                                          # the winch
    b.box((-2.60, wy, PLINTH), (2.60, wy + 2.60, 1.10), P.DBG, bevel=0.06)
    for x in (-2.30, 2.30):
        b.box((x - 0.30, wy + 0.40, 1.10), (x + 0.30, wy + 2.20, 3.40), P.YELLOW, bevel=0.06)
    b.cyl_x(0.0, wy + 1.30, 2.60, 0.95, 4.00, P.RED, 12)
    b.box((-0.16, wy - 0.05, 2.45), (0.16, wy + 0.40, 2.75), P.DBG, bevel=0.0)
    b.beam((0.0, wy, 2.60), (0.0, -8.30, 2.70), 0.22, 0.22, P.DBG)     # cable to the stern


def lv1_wet(b, hw=LANE_HW, rail=RAIL_X, rw=0.90, rh=0.34):
    """The lane's wet end: down from the quay edge into the water."""
    b.prof_x(-hw, hw, [(LANE_Y0, LANE_Z), (WATER_Y, -4.2), (WATER_Y, -4.8), (LANE_Y0, -0.2)], P.STONE)
    for x in (-rail, rail):
        b.beam((x, LANE_Y0 + 0.2, LANE_Z + 0.16), (x, WATER_Y + 0.4, -3.98), rw, rh, P.YELLOW)
    for t in (0.2, 0.4, 0.6, 0.8):
        y = LANE_Y0 + t * (WATER_Y - LANE_Y0)
        z = LANE_Z + t * (-4.2 - LANE_Z)
        for u0, u1 in tile_spans(hw, rail, rw):
            b.beam((u0, y, z + 0.05), (u1, y, z + 0.05), 1.0, 0.20, P.LBG)


def base_course(b, x0, x1, ya, yb):
    """The red base course and the white course over it, bevelled, along a face."""
    b.box((x0, ya, PLINTH), (x1, yb, 1.70), P.RED, bevel=0.10)
    b.box((x0, ya + 0.06, 1.70), (x1, yb, 2.00), P.WHITE, bevel=0.06)


def lv1_side(t, holes):
    wall_holes(t, -21.12, 21.12, 0.0, WALL_T, PLINTH, WALL_TOP, [(c - WIN_W / 2, c + WIN_W / 2, WIN_Z0, WIN_Z1) for c in holes], P.BLUE)
    courses(t, 0.0, -1, -21.10, 21.10, 1.70, 15.60, n=7, holes=[(c - WIN_W / 2 - 0.66, c + WIN_W / 2 + 0.66, WIN_Z0 - 0.88, WIN_Z1 + 0.60) for c in holes])
    for c in holes:
        window(t, c, WIN_W, WIN_Z0, WIN_Z1, 0.0, c=P.DBG, sill=P.RED)
    base_course(t, -21.20, 21.20, -0.22, 0.10)
    h = (15.60 - 2.00) / 7
    for u in PIL_US:                                         # white brick pilasters: the long wall reads in three bays
        for i in range(7):
            d = 0.60 if i % 2 else 0.72
            t.box((u - d, -0.16, 2.00 + i * h), (u + d, 0.02, 2.00 + (i + 1) * h - 0.03), P.WHITE, bevel=0.05)


def wall_lamp(b, u, y, s, z):
    """A chunky lit lamp on a wall face at y (s = the outward normal's sign): a grey bracket, a bevelled yellow block."""
    a, d = sorted((y - s * 0.03, y + s * 0.34))
    b.box((u - 1.05, a, z - 0.40), (u + 1.05, d, z), P.STONE, bevel=0.06)
    a, d = sorted((y - s * 0.03, y + s * 0.72))
    b.box((u - 0.85, a, z), (u + 0.85, d, z + 1.40), P.YELLOW, bevel=0.12)


def lv1_walls(b):
    """Blue brick side and back walls with the code's framed inset windows, white front piers, the arched boat-bay door."""
    for s in (-1, 1):
        turned(b, lambda t: lv1_side(t, (-10.80, 0.00, 10.80)), s, s * SIDE_X)
    hb = [(-9.0 - 2.64, -9.0 + 2.64, 7.08, 11.40), (9.0 - 2.64, 9.0 + 2.64, 7.08, 11.40)]
    wall_holes(b, -17.52, 17.52, 21.12, FACE_Y, PLINTH, WALL_TOP, hb, P.BLUE)
    courses(b, FACE_Y, 1, -17.50, 17.50, 1.70, 15.60, n=7, holes=[(c - 3.30, c + 3.30, 6.20, 12.00) for c in (-9.0, 9.0)])
    for c in (-9.0, 9.0):
        window(b, c, 5.28, 7.08, 11.40, FACE_Y, s=1)
    base_course(b, -17.60, 17.60, FACE_Y - 0.10, FACE_Y + 0.22)
    wall_holes(b, -17.40, 17.40, 21.00, 21.08, PLINTH, 15.20, hb, P.DBG)         # the back wall seen through the arch: dark mid tone, the boat stands out
    for s in (-1, 1):                                                            # and the side walls, mid grey, brick courses, two yellow lamps
        def inner(t, s=s):
            ws = (-10.80, 0.00, 10.80)
            wall_holes(t, -21.04 if s > 0 else -20.96, 20.96 if s > 0 else 21.04, 0.0, 0.08, PLINTH, 15.20, [(c - WIN_W / 2, c + WIN_W / 2, WIN_Z0, WIN_Z1) for c in ws], P.STONE)
            courses(t, 0.08, 1, -20.90, 20.90, PLINTH + 0.40, 15.10, n=7, c=P.DBG, holes=[(c - WIN_W / 2 - 0.10, c + WIN_W / 2 + 0.10, WIN_Z0 - 0.10, WIN_Z1 + 0.10) for c in ws])
            for u, z in ((-11.00, 3.80), (-2.00, 3.60)):                         # low enough to show under the shutter from the path
                wall_lamp(t, s * u, 0.13, 1, z)
        warped(b, inner, lambda x, y, z, s=s: (s * (17.50 - y), s * x, z))
    b._emit([(-17.45, -21.05, 15.20), (17.45, -21.05, 15.20), (17.45, 21.05, 15.20), (-17.45, 21.05, 15.20)], [(0, 1, 2, 3)], P.STONE)   # ceiling
    # white front piers + the fill over the arch
    y0, y1 = -FACE_Y, -FACE_Y + WALL_T
    pier = 18.48
    for s in (-1, 1):
        x0, x1 = sorted((s * 12.00, s * pier))
        b.box((x0, y0, PLINTH), (x1, y1, WALL_TOP), P.WHITE, bevel=0.0)
        courses(b, y0, -1, x0 + 1.32 if s > 0 else x0, x1 - 1.32 if s < 0 else x1, 1.70, 15.60, n=7, brick=3.60, c=P.LBG,
                holes=[(s * 15.2 - 2.6, s * 15.2 + 2.6, 6.0, 11.4)])
        base_course(b, x0 - (0.20 if s < 0 else -0.05), x1 + (0.20 if s > 0 else -0.05), y0 - 0.22, y0 + 0.10)
        # a big round porthole on each pier: a hull's detail, in the code's white
        torus_y(b, s * 15.20, y0 - 0.20, 8.70, 2.10, 0.42, P.RED, 16, 4)
        disc_y(b, s * 15.20, y0 - 0.06, 8.70, 2.05, 0.08, P.GLASS, 16)
    h = (15.60 - 2.00) / 7
    for sx in (-1, 1):                                       # chunky red quoins on the four corners, every other course
        for sy in (-1, 1):
            for i in range(0, 7, 2):
                z0, z1 = 2.00 + i * h + 0.05, 2.00 + (i + 1) * h - 0.05
                xa, xb = sorted((sx * (SIDE_X - QUOIN_S), sx * (SIDE_X + 0.26)))
                ya, yb = sorted((sy * (FACE_Y - QUOIN_L), sy * (FACE_Y + 0.26)))
                b.box((xa, ya, z0), (xb, yb, z1), P.RED, bevel=0.10)
                if sy > 0:                                   # the back face's long side, in two boxes: one box poked into the bay as red dashes
                    xa, xb = sorted((sx * (SIDE_X - QUOIN_L), sx * (SIDE_X - QUOIN_S)))
                    b.box((xa, 21.20, z0), (xb, yb, z1), P.RED, bevel=0.10)
    # the lit back wall, seen through the arch: brick courses, three navy panels, two hanging life rings
    courses(b, 21.00, -1, -17.40, 17.40, PLINTH + 0.40, 15.10, n=7, c=P.STONE, holes=[(c - 3.0, c + 3.0, 6.70, 11.80) for c in (-9.0, 9.0)])
    for x in (-10.50, 0.0, 10.50):
        b.box((x - 3.00, 20.86, 1.60), (x + 3.00, 21.00, 6.20), P.DBLUE, bevel=0.06)
    for x in (-3.90, 3.90):
        torus_y(b, x, 20.70, 9.20, 1.40, 0.36, P.WHITE, 14, 4)
        for dx, dz in ((1.40, 0.0), (-1.40, 0.0), (0.0, 1.40), (0.0, -1.40)):
            b.box((x + dx - 0.40, 20.46, 9.20 + dz - 0.40), (x + dx + 0.40, 20.92, 9.20 + dz + 0.40), P.RED, bevel=0.04)
    for x in (-14.00, 14.00):
        wall_lamp(b, x, 20.95, -1, 7.60)
    pts = arch_pts(ARCH_RX, ARCH_RZ)
    b.loft([[(x, y0, z), (x, y1, z), (x, y1, WALL_TOP), (x, y0, WALL_TOP)] for x, z in pts], P.WHITE)
    # the blue voussoir ring, a yellow keystone, brick jambs down to grey footings
    ya, yb = y0 - 0.60, y0 + WALL_T + 0.05
    inner = arch_pts(ARCH_RX, ARCH_RZ)
    outer = arch_pts(RING_RX, RING_RZ)
    for i in range(ARCH_N):
        kc = P.YELLOW if i == ARCH_N // 2 else P.BLUE
        m = 0.05 if kc == P.BLUE else -0.10         # 0.05 in from each side: the seam shows white behind
        a0, a1 = lerp(inner[i], inner[i + 1], m), lerp(inner[i], inner[i + 1], 1 - m)
        o0, o1 = lerp(outer[i], outer[i + 1], m), lerp(outer[i], outer[i + 1], 1 - m)
        grow = 0.30 if kc == P.YELLOW else 0.0
        o0, o1 = (o0[0], o0[1] + grow), (o1[0], o1[1] + grow)
        prism_y(b, ya - (0.14 if kc == P.YELLOW else 0.0), yb, [a0, a1, o1, o0], kc)
    for s in (-1, 1):
        x0, x1 = sorted((s * ARCH_RX, s * RING_RX))
        for z0, z1 in ((1.70, 3.20), (3.20, 4.60), (4.60, ARCH_Z)):
            b.box((x0, ya, z0), (x1, yb, z1 - 0.03), P.BLUE, bevel=0.10)
        x0, x1 = sorted((s * (ARCH_RX - 0.05), s * (RING_RX + 0.45)))
        b.box((x0, ya - 0.20, PLINTH), (x1, yb, 1.70), P.DBG, bevel=0.10)
    # the 1-stud dark reveal behind the arch: the door reads deep against the white wall
    for s in (-1, 1):
        x0, x1 = sorted((s * (ARCH_RX - 0.04), s * (ARCH_RX + 0.70)))
        b.box((x0, y1 + 0.03, PLINTH), (x1, y1 + 1.10, ARCH_Z), P.DBG, bevel=0.0)
        arc = [q for q in pts if q[1] < SHUT_Z and s * q[0] > 0]
        b.loft([[(x - s * 0.04, y1 + 0.03, z), (x - s * 0.04, y1 + 1.10, z), (x + s * 0.70, y1 + 1.10, z), (x + s * 0.70, y1 + 0.03, z)] for x, z in arc], P.DBG)
    # the half-rolled door in the arch's crown: red laths, a white bottom rail
    sy0, sy1 = y1 + 0.02, y1 + 0.34
    top = [(x, z) for x, z in pts if z > SHUT_Z]
    xe = ARCH_RX * math.sqrt(1 - ((SHUT_Z - ARCH_Z) / ARCH_RZ) ** 2)
    sec = [(-xe, SHUT_Z)] + top + [(xe, SHUT_Z)]
    b.loft([[(x, sy0, SHUT_Z), (x, sy1, SHUT_Z), (x, sy1, z + 0.10), (x, sy0, z + 0.10)] for x, z in sec], P.RED)
    for zl in (11.45, 12.25, 13.05):                         # the slats: chunky, with their shadow side
        xl = ARCH_RX * math.sqrt(max(0.0, 1 - ((zl + 0.26 - ARCH_Z) / ARCH_RZ) ** 2)) - 0.10
        b.box((-xl, sy0 - 0.12, zl - 0.24), (xl, sy0 + 0.02, zl + 0.24), P.RRED, bevel=0.05)
    b.box((-xe - 0.05, sy0 - 0.14, SHUT_Z - 0.40), (xe + 0.05, sy1 + 0.04, SHUT_Z + 0.10), P.WHITE, bevel=0.06)


def lv1_boat(b, stripe=P.BLUE):
    """A white workboat with a red boot stripe and a blue gunwale in the mouth of the bay, on brick stands on the rails, bow out."""
    y_s, y_b, xc = -8.50, -22.90, 0.0
    st = ((y_s, 3.30, 1.90, 5.30), (y_s - 6.0, 3.30, 1.90, 5.30), (y_b + 3.6, 2.60, 2.20, 5.50), (y_b + 1.2, 1.20, 3.10, 5.80),
          (y_b, 0.30, 4.40, 6.00))

    def z_at(bot, top, u):
        return bot + (top - bot) * u
    b.loft([[(xc + s * w * q, y, z_at(bot, top, u)) for s, q, u in ((1, 0.94, 0.42), (1, 0.45, 0.0), (-1, 0.45, 0.0), (-1, 0.94, 0.42))]
            for y, w, bot, top in st], P.RED)
    b.loft([[(xc + s * w * q, y, z_at(bot, top, u)) for s, q, u in ((1, 1.0, 1.0), (1, 0.94, 0.42), (-1, 0.94, 0.42), (-1, 1.0, 1.0))]
            for y, w, bot, top in st], P.WHITE)
    b.loft([[(xc + s * (w + 0.15), y, z) for s, z in ((1, top + 0.55), (1, top), (-1, top), (-1, top + 0.55))]
            for y, w, bot, top in st], stripe)
    c0, c1 = -16.60, -10.60                                 # cabin
    b.box((-2.30, c0, 5.70), (2.30, c1, 8.60), P.WHITE, bevel=0.10)
    b.box((-2.38, c0 + 0.5, 7.20), (2.38, c1 - 0.5, 8.10), P.GLASS, bevel=0.0)
    b.box((-1.80, c0 - 0.08, 7.20), (1.80, c0 + 0.5, 8.10), P.GLASS, bevel=0.0)
    b.box((-2.70, c0 - 0.30, 8.60), (2.70, c1 + 0.30, 9.10), stripe, bevel=0.10)
    b.studs(-2.30, 2.30, c0 + 0.1, c1 - 0.1, 9.10, stripe, step=2.4, r=0.62, h=0.26)
    b.stud_row(xc, -18.20, xc, -20.20, 5.90, P.WHITE, spacing=1.6, r=0.50, h=0.22, n=8)
    for y in (-19.00, -10.80):                              # stands: grey bricks, yellow bunks
        b.box((-3.60, y - 1.00, LANE_Z), (3.60, y + 1.00, 1.45), P.DBG, bevel=0.08)
        for x in (-RAIL_X, RAIL_X):
            b.box((x - 0.75, y - 0.80, 1.45), (x + 0.75, y + 0.80, 3.10), P.YELLOW, bevel=0.10)


def lv1_roof(b):
    """The stepped red roof on its white course: white coursed gables with a navy trim, a dark eave course, continuous barge boards, the name-sign frame,
    the hull-number sticker, a flag on the peak (Lv1's own silhouette)."""
    stepped_roof(b, ROOF_HW, ROOF_N, EAVE, RISE, -ROOF_END, ROOF_END, P.RED, P.RRED, P.RRED)
    for y in (-ROOF_END, ROOF_END):                         # one clean barge board a side, a thin white fascia
        rakes(b, lambda u, z, y=y: (u, y, z), ROOF_HW, ROOF_HW / ROOF_N, EAVE, RISE, P.RRED)
    for y0, y1 in ((-FACE_Y, -FACE_Y + WALL_T), (FACE_Y - WALL_T, FACE_Y)):
        stepped_gable(b, 0.0, ROOF_HW - 0.60, ROOF_N, EAVE - 0.05, RISE, y0, y1, P.WHITE, trim=P.DBLUE, seams=P.LBG)
    for s in (-1, 1):                                       # the white course round the top of the walls
        x0, x1 = sorted((s * 18.72, s * 18.20))
        b.box((x0, -22.32, 15.60), (x1, 22.32, EAVE), P.WHITE, bevel=0.06)
    for y in (-22.32, 21.80):
        b.box((-18.20, y, 15.60), (18.20, y + 0.52, EAVE), P.WHITE, bevel=0.06)
    sign_frame(b, 0.0, SIGN_Z, SIGN_HW, SIGN_HH, SIGN_Y)
    hull_sticker(b, 0.0, 22.80, "01", -ROOF_END - 0.10, k=1.0)
    # the flag: a chunky stacked mast off the ridge, a big red-and-white pennant toward the sea
    my, zr = -19.00, EAVE + ROOF_N * RISE + 1.30
    b.box((-0.80, my - 0.80, zr - 0.2), (0.80, my + 0.80, zr + 1.0), P.WHITE, bevel=0.10)
    b.box((-0.45, my - 0.45, zr + 1.0), (0.45, my + 0.45, zr + 8.0), P.WHITE, bevel=0.06)
    b.cyl(0.0, my, zr + 8.0, zr + 8.5, 0.70, P.YELLOW, 8, bottom=False)
    fz0, fz1 = zr + 4.2, zr + 7.8
    prism_y(b, my - 0.14, my + 0.14, [(0.45, fz0), (7.0, (fz0 + fz1) / 2), (0.45, fz1)], P.RED)
    prism_y(b, my - 0.20, my + 0.20, [(0.45, fz0 + 1.0), (3.1, (fz0 + fz1) / 2), (0.45, fz1 - 1.0)], P.WHITE)


def lv1_cols(c):
    y0, y1 = -FACE_Y, -FACE_Y + WALL_T
    for s in (-1, 1):
        c.box((s * 17.52, -21.12, PLINTH), (s * SIDE_X, 21.12, EAVE), P.DBG, bevel=0)     # side wall
        c.box((s * 12.00, y0, PLINTH), (s * SIDE_X, y1, EAVE), P.DBG, bevel=0)              # front pier
    c.box((-17.52, 21.12, PLINTH), (17.52, FACE_Y, EAVE), P.DBG, bevel=0)                   # back wall
    c.box((-12.00, y0, SHUT_Z), (12.00, y1, EAVE), P.DBG, bevel=0)                          # over the arch: clear to 10.5
    c.box((-3.60, -22.90, LANE_Z), (3.60, -8.50, 6.00), P.DBG, bevel=0)                     # the boat
    c.box((-2.60, LANE_Y1 + 0.20, PLINTH), (2.60, LANE_Y1 + 2.80, 3.40), P.DBG, bevel=0)    # winch
    c.box((-ROOF_HW, -ROOF_END, EAVE), (ROOF_HW, ROOF_END, EAVE + 2.0), P.DBG, bevel=0)     # roof
    c.box((-9.0, -ROOF_END, EAVE + 2.0), (9.0, ROOF_END, EAVE + 7.0), P.DBG, bevel=0)


# ---- Lv2: the code lifeboat slip's shed as a mesh (1x, its own lot: x 29..79, y +-12)
def shed_post(b, x, y, top=SHED_BAND):
    column(b, x, y, 0.0, top, k=POST_K, foot=1.75, stepped=True, n=3 if top == SHED_BAND else 5, band=True, cap=1.78)    # the first footing course stands on the ground, past the plinth's edge


def lv2_slip(b):
    """Inside the shed: a stone lane on the code plinth, yellow rails running out to the code slipway, a yellow winch. The bay's own ramp
    (like Lv1's): a pad of tiles with a studded rim under the cross gable, a stone lane over the walk and down into the water."""
    y0, y1 = -3.50, 3.50
    b.box((SHED_X0 + 2.0, y0, SHED_TOP - 0.02), (SHED_X1 - 0.05, y1, SHED_TOP + 0.10), P.STONE, bevel=0.04)
    for y in (-2.6, 2.6):
        b.box((SHED_X0 + 3.5, y - 0.40, SHED_TOP + 0.10), (SHED_X1 - 0.05, y + 0.40, SHED_TOP + 0.42), P.YELLOW, bevel=0.06)
    wx = SHED_X0 + 2.30
    b.box((wx - 1.50, -2.60, SHED_TOP), (wx + 1.50, 2.60, SHED_TOP + 2.10), P.YELLOW, bevel=0.12)
    b.studs(wx - 1.20, wx + 1.20, -2.30, 2.30, SHED_TOP + 2.10, P.YELLOW, step=2.3, r=0.55, h=0.24)
    b.box((wx + 1.50, -0.90, SHED_TOP + 0.60), (wx + 2.10, 0.90, SHED_TOP + 1.70), P.RED, bevel=0.08)
    px0, px1 = BAY_CX - 15.50, BAY_CX + 15.50
    b.box((px0, PAD_Y, 0.0), (px1, -11.00, PAD_Z), P.LBG, bevel=0.0)
    for x in (px0 + 3.875 * i for i in range(1, 8)):         # tile seams, mid grey
        if abs(x - BAY_CX) > LANE2_HW + 0.1:
            b.box((x - 0.05, PAD_Y + 0.75, PAD_Z), (x + 0.05, -11.00, PAD_Z + 0.04), P.STONE, bevel=0.0)
    for y in (-19.60, -15.30):
        for xa, xb in ((px0 + 0.1, BAY_CX - LANE2_HW), (BAY_CX + LANE2_HW, px1 - 0.1)):
            b.box((xa, y - 0.05, PAD_Z), (xb, y + 0.05, PAD_Z + 0.04), P.STONE, bevel=0.0)
    for xa, xb in ((px0, BAY_CX - LANE2_HW), (BAY_CX + LANE2_HW, px1)):   # white tile strips with a stud row on the walk's edge
        n = round((xb - xa) / 3.875)
        for i in range(n):
            b.box((xa + i * (xb - xa) / n + 0.05, PAD_Y, PAD_Z - 0.02), (xa + (i + 1) * (xb - xa) / n - 0.05, PAD_Y + 1.00, PAD_Z + 0.30), P.WHITE, bevel=0.08)
        b.stud_row(xa + 1.0, PAD_Y + 0.50, xb - 1.0, PAD_Y + 0.50, PAD_Z + 0.30, P.WHITE, spacing=2.4, r=0.30, h=0.18, n=6)
    for x0 in (px0, px1 - 1.00):                                        # and up the pad's two sides
        for i in range(3):
            b.box((x0, PAD_Y + 1.05 + i * 3.80, PAD_Z - 0.02), (x0 + 1.00, PAD_Y + 1.05 + (i + 1) * 3.80 - 0.10, PAD_Z + 0.30), P.WHITE, bevel=0.08)
    b.box((BAY_CX - LANE2_HW, -35.00, PLINTH - 0.04), (BAY_CX + LANE2_HW, PAD_Y, LANE_Z), P.STONE, bevel=0.05)
    b.box((BAY_CX - LANE2_HW, PAD_Y, 0.10), (BAY_CX + LANE2_HW, -3.60, PAD_Z + 0.06), P.STONE, bevel=0.05)
    for yy in (-33.00, -30.00, -27.00):
        for u0, u1 in tile_spans(LANE2_HW, LANE2_RAIL, LANE2_RW):
            b.box((BAY_CX + u0, yy - 0.50, LANE_Z - 0.02), (BAY_CX + u1, yy + 0.50, LANE_Z + 0.20), P.LBG, bevel=0.05)
    r = LANE2_RW / 2
    for x in (-LANE2_RAIL, LANE2_RAIL):
        b.box((BAY_CX + x - r, -35.00, LANE_Z), (BAY_CX + x + r, PAD_Y + 0.02, LANE_Z + LANE2_RH), P.YELLOW, bevel=0.08)
        b.box((BAY_CX + x - r, PAD_Y, LANE_Z + 0.10), (BAY_CX + x + r, -3.60, PAD_Z + 0.50), P.YELLOW, bevel=0.08)


def lv2_wet(b):
    """The lane's wet end: Lv3's deck takes this spot (DockPieces.boathouseLevel drops this part at Lv3)."""
    warped(b, lambda t: lv1_wet(t, LANE2_HW, LANE2_RAIL, LANE2_RW, LANE2_RH), lambda x, y, z: (BAY_CX + x, y, z))


def lv2_shed(b):
    """Stacked-brick posts round the slip, a blue course over them (the code's), the bay's corner posts and its red lintel on the pad."""
    for x in FRONT_XS:
        shed_post(b, x, -10.80)
    for x in POST_XS:
        shed_post(b, x, 10.80)
    b.box((33.00, 10.20, SHED_TOP - 0.05), (75.00, 10.60, SHED_BAND + 0.05), P.DBG, bevel=0.0)    # a dark mid-tone back wall: the bay reads deep, the posts stop being noise
    courses(b, 10.20, -1, 33.00, 75.00, SHED_TOP + 0.45, SHED_BAND, n=5, c=P.STONE)
    for i in range(14):                                   # one white tile band
        b.box((33.10 + i * 2.986 + 0.03, 10.06, 6.30), (33.10 + (i + 1) * 2.986 - 0.03, 10.20, 7.14), P.WHITE, bevel=0.03)
    z0, z1 = SHED_BAND, SHED_EAVE - 0.75                  # the red plate band, low enough to show under the eave from the path
    for x0, x1 in ((SHED_X0 + 0.20, BAY_CX - 13.00), (BAY_CX + 13.00, SHED_X1 - 0.20)):
        b.box((x0, -12.30, z0), (x1, -10.05, z1), P.RED, bevel=0.10)
    b.box((SHED_X0 + 0.20, 10.05, z0), (SHED_X1 - 0.20, 12.30, z1), P.RED, bevel=0.10)
    for x0, x1 in ((SHED_X0 + 0.20, SHED_X0 + 1.70), (SHED_X1 - 1.70, SHED_X1 - 0.20)):
        b.box((x0, -10.05, z0), (x1, 10.05, z1), P.RED, bevel=0.10)
    zt = BAY_EAVE - 1.0
    for s in (-1, 1):
        shed_post(b, BAY_CX + s * 13.00, -18.50, top=zt)
        # stepped corner bricks at the bay's shoulders: the opening reads as a door, not a gap
        for d, h in ((3.20, 1.10), (1.70, 2.20)):
            x0, x1 = sorted((BAY_CX + s * 13.00, BAY_CX + s * (13.00 - d - 1.10)))
            b.box((x0, -19.10, zt - h), (x1, -17.90, zt - (h - 1.10)), P.BLUE, bevel=0.08)


def lv2_roof(b):
    """The stepped blue roof (the code's colour; ridge along X), white gable ends, straight barge boards; the cross gable facing the
    path: white stepped wall, the code's Lifeboat sign in a frame, a hull-number sticker, Lv2's own peak."""
    warped(b, lambda t: stepped_roof(t, SHED_Y + SHED_OVER, SHED_N, SHED_EAVE, SHED_RISE, SHED_X0 - 1.0, SHED_X1 + 1.0, P.BLUE, P.DBLUE, P.DBLUE),
           lambda x, y, z: (y, x, z))
    for x in (SHED_X0 - 1.0, SHED_X1 + 1.0):
        rakes(b, lambda u, z, x=x: (x, u, z), SHED_Y + SHED_OVER, (SHED_Y + SHED_OVER) / SHED_N, SHED_EAVE, SHED_RISE, P.DBLUE)
    for x0, x1 in ((SHED_X0 + 0.20, SHED_X0 + 1.20), (SHED_X1 - 1.20, SHED_X1 - 0.20)):
        for i in range(SHED_N):
            d = (SHED_Y - 0.6) * (1 - (i + 1) / SHED_N) + 0.30
            b.box((x0, -d, SHED_EAVE - 0.05 + i * SHED_RISE), (x1, d, SHED_EAVE - 0.05 + (i + 1) * SHED_RISE + 0.10), P.WHITE, bevel=0.06)
    warped(b, lambda t: stepped_roof(t, BAY_HW, BAY_N, BAY_EAVE, BAY_RISE, BAY_END, 1.50, P.BLUE, P.DBLUE, P.DBLUE),
           lambda x, y, z: (x + BAY_CX, y, z))
    rakes(b, lambda u, z: (BAY_CX + u, BAY_END, z), BAY_HW, BAY_HW / BAY_N, BAY_EAVE, BAY_RISE, P.DBLUE)
    stepped_gable(b, BAY_CX, BAY_HW - 0.60, BAY_N, BAY_EAVE - 0.05, BAY_RISE, BAY_FACE, BAY_FACE + 0.90, P.WHITE)
    b.box((BAY_CX - BAY_HW - 0.20, BAY_FACE - 0.30, BAY_EAVE - 1.0), (BAY_CX + BAY_HW + 0.20, BAY_FACE + 0.90, BAY_EAVE + 0.10), P.RED, bevel=0.10)
    b.stud_row(BAY_CX - BAY_HW + 1.0, BAY_FACE - 0.05, BAY_CX + BAY_HW - 1.0, BAY_FACE - 0.05, BAY_EAVE + 0.10, P.RED, spacing=3.0, r=0.20, h=0.14, n=6)
    sign_frame(b, BAY_CX, BAYSIGN_Z, BAYSIGN_HW, BAYSIGN_HH, BAYSIGN_Y)
    b.box((BAY_CX - BAYSIGN_HW, BAYSIGN_Y + 0.28, BAYSIGN_Z - BAYSIGN_HH), (BAY_CX + BAYSIGN_HW, BAY_FACE + 0.10, BAYSIGN_Z + BAYSIGN_HH), P.WHITE, bevel=0.0)
    hull_sticker(b, BAY_CX, 22.60, "02", BAY_END - 0.10, k=1.50)


def lv2_boat(b):
    """The lifeboat in the bay's mouth, bow out over the pad in the sun: Lv1's workboat x 1.15, red and white with an orange stripe, on
    the same stands and rails."""
    warped(b, lambda t: lv1_boat(t, P.ORANGE),
           lambda x, y, z: (BAY_CX + x * BOAT_K, -24.00 + (y + 22.90) * BOAT_K, PAD_Z + (z - LANE_Z) * BOAT_K))


def lv2_cols(c):
    for xs, y in ((FRONT_XS, -10.80), (POST_XS, 10.80)):
        for x in xs:
            c.box((x - POST_R, y - POST_R, SHED_TOP), (x + POST_R, y + POST_R, SHED_EAVE), P.DBG, bevel=0)
    c.box((33.00, 10.20, SHED_TOP), (75.00, 10.60, SHED_BAND), P.DBG, bevel=0)                            # back wall
    for s in (-1, 1):
        c.box((BAY_CX + s * 13.00 - POST_R, -18.50 - POST_R, SHED_TOP), (BAY_CX + s * 13.00 + POST_R, -18.50 + POST_R, BAY_EAVE), P.DBG, bevel=0)
    c.box((SHED_X0 - 1.0, -SHED_Y, SHED_EAVE), (SHED_X1 + 1.0, SHED_Y, SHED_EAVE + SHED_N * SHED_RISE), P.DBG, bevel=0)
    c.box((BAY_CX - BAY_HW, BAY_END, BAY_EAVE), (BAY_CX + BAY_HW, -SHED_Y, BAY_EAVE + 4.0), P.DBG, bevel=0)
    c.box((SHED_X0 + 0.80, -2.60, SHED_TOP), (SHED_X0 + 3.80, 2.60, SHED_TOP + 2.10), P.DBG, bevel=0)     # winch
    c.box((BAY_CX - 4.40, -24.00, PAD_Z), (BAY_CX + 4.40, -6.40, 11.00), P.DBG, bevel=0)                  # the boat
    c.box((BAY_CX - 15.50, PAD_Y, 0.0), (BAY_CX + 15.50, -12.00, PAD_Z), P.DBG, bevel=0)                  # the pad, a step like the plinth


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    patch_lod_targets()
    mat = lego.material("MI_Boathouse_Brick", ALB)
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
        print("[boathouse] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills decks
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    for name, fn, node in (("Lv1_L01_Lane", lv1_floor, "Lv1"), ("Lv1_L02_Walls", lv1_walls, "Lv1"), ("Lv1_L03_Boat", lv1_boat, "Lv1"),
                           ("Lv1_L04_Roof", lv1_roof, "Lv1"), ("Lv1_L07_LaneWet", lv1_wet, "Lv1"),
                           ("Lv2_L01_Slip", lv2_slip, "Lv2"), ("Lv2_L02_Shed", lv2_shed, "Lv2"), ("Lv2_L03_Roof", lv2_roof, "Lv2"),
                           ("Lv2_L04_Lifeboat", lv2_boat, "Lv2"), ("Lv2_L05_LaneWet", lv2_wet, "Lv2")):
        b = lego.B()
        fn(b)
        out(name, b, node)
    c = lego.B()
    lv1_cols(c)
    out_cols("Lv1", c)
    c = lego.B()
    lv2_cols(c)
    out_cols("Lv2", c)

    b = lego.B()
    lv3_deck(b)
    out("Lv3_L01_Deck", b, "Lv3")

    b = lego.B()
    lv3_quay(b)
    out("Lv3_L02_QuayEdge", b, "Lv3")

    b = lego.B()
    warped(b, lv3_ramp, launch_turn)
    out("Lv3_L03_Ramp", b, "Lv3")

    b = lego.B()
    lv3_roof(b)
    out("Lv3_L04_Roof", b, "Lv3")

    b = lego.B()
    lv3_room(b)
    out("Lv3_L05_ReadyRoom", b, "Lv3")

    b = lego.B()
    lv3_launch(b)
    out("Lv3_L06_Launch", b, "Lv3")

    b = lego.B()
    lifeboat(b)
    out("Lv3_L07_Lifeboat", b, "Lv3")

    c = lego.B()
    x0, x1, y0, y1 = HALL
    c.box((BAY[0], BAY[3], 0.10), (BAY[1], BAY[2], DECK), P.DBG, bevel=0)                 # deck
    for kx0, kx1 in KERB:
        c.box((kx0, -35.0, 0.0), (kx1, -33.8, 0.50), P.DBG, bevel=0)                      # kerb
    cx, t = HALL_CX, 0.9
    c.box((x0, y0, DECK), (x0 + t, y1, HALL_TOP), P.DBG, bevel=0)                         # cabin: sides
    c.box((x1 - t, y0, DECK), (x1, y1, HALL_TOP), P.DBG, bevel=0)
    c.box((x0 + t, y1 - t, DECK), (x1 - t, y1, HALL_TOP), P.DBG, bevel=0)                 # back
    c.box((x0 + t, y0, DECK), (cx - HALL_DOOR, y0 + t, HALL_TOP), P.DBG, bevel=0)         # door stubs, header: the door stays clear
    c.box((cx + HALL_DOOR, y0, DECK), (x1 - t, y0 + t, HALL_TOP), P.DBG, bevel=0)
    c.box((cx - HALL_DOOR, y0, HALL_DOOR_Z), (cx + HALL_DOOR, y0 + t, HALL_TOP), P.DBG, bevel=0)
    c.box((x1 - t - 1.8, y0 + 1.4, DECK), (x1 - t, y1 - 1.6, 4.60), P.DBG, bevel=0)       # bench

    def launch_cols(t):
        t.box((WINCH[0] - 1.6, WINCH[1] - 1.9, DECK), (WINCH[0] + 1.6, WINCH[1] + 1.9, 4.40), P.DBG, bevel=0)   # winch
        n = 6                                                                             # ramp steps
        for i in range(n):
            xa = RAMP[0] + i * (RAMP[1] - RAMP[0]) / n
            xb = xa + (RAMP[1] - RAMP[0]) / n
            t.box((xa, RAMP[3], -4.80), (xb, RAMP[2], z_ramp((xa + xb) / 2.0)), P.DBG, bevel=0)
        f = lego.B()                                                                      # lifeboat + trolley
        f.box((RAMP[0] + CRADLE[0], YC - 2.80, 0.0), (RAMP[0] + CRADLE[1] + 0.5, YC + 2.80, 8.80), P.DBG, bevel=0)
        tilt(f, t)
    warped(c, launch_cols, launch_turn)
    hw, ez, n_, rise, ra, rb = HALL_ROOF
    c.box((cx - hw, ra, HALL_TOP), (cx + hw, rb, ez + n_ * rise + 0.75), P.DBG, bevel=0)  # roof overhead
    c.box((MAST_X - 1.30, MAST_Y - 1.30, WATER - 0.6), (MAST_X + 1.30, MAST_Y + 1.30, LAMP_Z), P.DBG, bevel=0)   # go-lamp mast
    out_cols("Lv3", c)

    atts = [lego.attach("ATT_Launch", (LAUNCH_X - RAMP[0] - 12.0, YC, z_ramp(RAMP[0] + 12.0))),
            lego.attach("ATT_Work_Winch", (LAUNCH_X - WINCH[0], -37.6, DECK)),
            lego.attach("ATT_ReadyRoom", (HALL_CX, (HALL[2] + HALL[3]) / 2, DECK))]

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[boathouse] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[boathouse] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "the boathouse on the code plinth (Lv1), the slip shed on its own lot x 29..79 (Lv2) and the quick-launch "
                     "bay along the cove quay (Lv3); front -Y, origin the boathouse ground centre, authored at the code "
                     "boathouse's final 1.2 scale (no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_HQAddons / M_Bld_BoatYardAddons), no PBR scans",
            "LOD1 triangles": "LOD1 keeps the add-ons' 50% share (patch_lod_targets)",
            "LOD2 triangles": "LOD2 keeps the add-ons' 25% share (patch_lod_targets): the hero ceiling would collapse the "
                              "small Lego detail meshes",
            "naming": "gameplay node/layer names (docs/25): Lv3_L01_..., Lv3_Col01_COL..; the FBX importer "
                      "flattens empty parents, so the node name is the mesh prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "ready_room", "target": [HALL_CX, -41.0, 3.0], "dist": 22, "az": -150, "el": 10},
            {"name": "winch", "target": [LAUNCH_X - WINCH[0], WINCH[1], 2.6], "dist": 16, "az": 40, "el": 16},
            {"name": "lifeboat", "target": [24.0, -41.0, 2.5], "dist": 30, "az": 40, "el": 20},
            {"name": "go_light", "target": [MAST_X, MAST_Y, 23.0], "dist": 24, "az": 55, "el": 8},
            {"name": "roof", "target": [HALL_CX, -41.0, 13.0], "dist": 66, "az": 60, "el": 26},
        ],
    }
