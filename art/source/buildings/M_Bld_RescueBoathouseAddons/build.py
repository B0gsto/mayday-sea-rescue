"""M_Bld_RescueBoathouseAddons: the Rescue Boathouse's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3).

PERF-BL11: Lv1_* layers mesh the whole code boathouse (`rescueBoathouse()` in src/shared/DockPieces.luau keeps its Parts
as the fallback, plus the plinth, name sign, lamp and the hidden Console): stepped studded roof with a dormer pair, red boat-bay
portal with a striped drum and hazard apron, framed windows, dinghy on its slip. Lv1_L07_FlankR drops at Lv2, Lv1_L08_FlankL + Lv1_L09_Chair at Lv3. Lv2/Lv3 sit at the
code boathouse's final frame: 44 x 36 stud lot, ground at z 0, plinth top z 0.92 (the code plinth is 0.8 studs at 1x,
scaled 1.15), front -Y (Roblox -Z), origin the boathouse's ground centre. Place at the boathouse frame with no
extra scale.

Lv2 (engine: Rescuers get a RIB): a short pontoon finger down the right side of the pen, inside the code posts and
clear of the dinghy, table and lifeguard chair. A raised wet slip (dark water in a light-grey rim) holds an
orange-and-grey RIB: grey faceted hull, orange inflatable collar, navy console and windscreen, two orange jockey
seats, black outboard, yellow grab rails, red life ring. The pontoon deck is walked onto by two steps at the back
(studded, yellow safety edge, three cleats); bow and stern lines tie it to the deck. At the back of the deck a red
fuel pump with a hose reel and a hose to the RIB; against the right fence a life-jacket rack: navy gear locker,
white frame and four orange jackets with white reflective bands.

Lv3 (engine: Rescuers get a lifeboat, more trips): a long berth down the left side (mirror of the pontoon),
inside the code posts and clear of the trailer and the lifeguard chair. A raised wet slip, a plank walk-on deck
with a side step, bollards and cleats, and a red/white watch tower in the back corner, its cabin above the roof.
The lifeboat (20 long, the RIB is 11.6) is orange with a navy
two-tier wheelhouse and a mast. A yellow davit on the far (east) quay edge swings a block and hook over the
foredeck; a crew bench with an orange/navy slat seat sits on the walkway.

Each level is a top-level node (Lv2, Lv3) holding 4-5 layers (L01_* bottom to L05_* top), one palette mesh per
layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). The RIB and the lifeboat are their own
meshes (Lv2_L04_RIB, Lv3_L03_Lifeboat) so the game can bob or sail them. Collision is one simple box per object,
<Node>_ColNN_COL, so the pontoon decks, steps, slips and walkways stay open.

    python3 art/source/buildings/M_Bld_RescueBoathouseAddons/maketex.py \
        --out build/prod/M_Bld_RescueBoathouseAddons/textures/M_Bld_RescueBoathouseAddons \
        --name RescueBoathouse --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_RescueBoathouseAddons/build.py \
        --out-root build/prod/M_Bld_RescueBoathouseAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_RescueBoathouseAddons"
BUDGET = "hero_building"   # Lv1 joined (PERF-BL11): 40k class, one flat palette set (waived)
TIER = "standard"
SET_NAME, SET = "RescueBoathouse", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_RescueBoathouse_Brick_ALB.png")
PLINTH, SLIP, DECK = 0.92, 1.30, 1.62     # code plinth top, water surface, pontoon deck top

# Lv2 RIB pontoon, right side of the pen (world studs, front -Y)
B2 = (11.20, 17.90, -18.15, 3.80)         # wet slip water x0, x1, y0, y1
RIB_CX, RIB_CY = 14.55, -10.60         # r5: the bow where it was, the slip 1.2 wider for the 25% bigger boat
RIB_K = 1.25                              # rib() draws the 11.5 boat and scales it about the keel
RIB_ST = ((5.60, 2.15), (4.20, 2.15), (2.00, 2.12), (0.00, 2.08), (-2.00, 1.98),
          (-3.60, 1.72), (-4.60, 1.28), (-5.40, 0.72), (-5.80, 0.30), (-5.95, 0.12))
RIB_Z = (1.05, 1.75, 2.80)                # keel, chine, gunwale
D2 = (17.90, 23.00, -14.20, 5.10)         # deck x0, x1, y0, y1

# Lv3 lifeboat berth, left side of the pen (the boat is 20.0 long, 4.9 wide, wheelhouse to z 7.5, mast to z 12.4)
B3 = (-21.00, -14.80, -12.60, 11.00)
LB_CX, LB_CY = -17.90, -0.60
LB_K = 1.28                               # lifeboat() draws a 15.6 boat and stretches it along Y to 20.0
LB_ST = ((7.80, 2.38), (6.00, 2.46), (3.00, 2.46), (0.00, 2.40), (-3.00, 2.26),
         (-5.00, 1.98), (-6.40, 1.52), (-7.20, 0.95), (-7.80, 0.35))
LB_Z = (1.02, 1.80, 3.10)                 # keel, chine, gunwale
D3 = (-14.80, -10.90, -13.10, 12.60)      # walk-on deck x0, x1, y0, y1
DVT_X, DVT_Y = -14.00, 7.60             # davit on the far (east) quay edge aft, arm over the stern: the wheelhouse stays clear from the path
BENCH = (-12.55, -12.40, -11.10, -6.40)   # crew bench on the walkway's east edge: x0, y0, x1, y1


def patch_lod_targets():
    """LODs keep the large_prop shares (50% / 25%): the hero_building LOD2 ceiling collapses the small Lego detail."""
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


# ------------------------------------------------------------------ small helpers
def grid_studs(b, x0, x1, y0, y1, z, c, nx=2, ny=6, r=0.42, h=0.24, n=8):
    for i in range(nx):
        for j in range(ny):
            b.cyl(x0 + (i + 0.5) * (x1 - x0) / nx, y0 + (j + 0.5) * (y1 - y0) / ny,
                  z, z + h, r, c, n)


def rim(b, x0, y0, x1, y1, water):
    """A stone-grey rim at deck height with a yellow safety edge on the water side ('+x', '+y' or '-y')."""
    b.box((x0, y0, PLINTH), (x1, y1, DECK), P.STONE, bevel=0.06)
    e = 0.18
    if water == "+x":
        s = (x1 - e, y0 + 0.05, x1, y1 - 0.05)
    elif water == "+y":
        s = (x0 + 0.05, y1 - e, x1 - 0.05, y1)
    else:
        s = (x0 + 0.05, y0, x1 - 0.05, y0 + e)
    b.box((s[0], s[1], DECK - 0.02), (s[2], s[3], DECK + 0.04), P.YELLOW, bevel=0.02)


def cleat(b, x, y, z, k=1.0, c=P.YELLOW):
    """A T-shaped mooring cleat on a deck (base plate, post, cross bar), k times the plain size."""
    b.box((x - 0.42 * k, y - 0.20 * k, z), (x + 0.42 * k, y + 0.20 * k, z + 0.16 * k), P.DBG, bevel=0.03)
    b.box((x - 0.24 * k, y - 0.16 * k, z + 0.16 * k), (x + 0.24 * k, y + 0.16 * k, z + 0.34 * k), c, bevel=0.04)
    b.box((x - 0.50 * k, y - 0.11 * k, z + 0.34 * k), (x + 0.50 * k, y + 0.11 * k, z + 0.48 * k), c, bevel=0.03)


def bollard(b, x, y, z):
    """A yellow mooring bollard with a dark collar and cap on a deck edge."""
    b.cyl(x, y, z, z + 1.00, 0.46, P.YELLOW, 10)
    b.cyl(x, y, z + 0.66, z + 0.82, 0.60, P.DBG, 10)
    b.cyl(x, y, z + 1.00, z + 1.14, 0.56, P.YELLOW, 10)


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


def dashes(b, x, y0, y1, z, c=P.YELLOW, w=0.26, on=1.50, off=0.90):
    """A painted walk line along Y: dashes just above the deck."""
    y = y0
    while y + on <= y1:
        b.box((x - w / 2, y, z), (x + w / 2, y + on, z + 0.04), c, bevel=0.01)
        y += on + off


def disc_y(b, cx, cy, cz, r, length, c, n=10):
    """A closed cylinder along Y (steering wheel, hose reel)."""
    y0, y1 = cy - length / 2, cy + length / 2
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def torus_y(b, cx, cy, cz, R, r, c, maj=10, mnr=4):
    """A ring around the Y axis (life rings hung on a fore-and-aft face)."""
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


# ------------------------------------------------------------------ hulls, collars, decks
def hull(b, cx, cy, stations, z, colour):
    """A solid faceted hull through the stations (y, half-beam); the top is a shallow V deck."""
    zk, zc, zg = z
    sections = []
    for y, hw in stations:
        sections.append([
            (cx - hw, cy + y, zg),
            (cx - hw * 0.97, cy + y, zc),
            (cx - hw * 0.62, cy + y, zk + 0.10),
            (cx, cy + y, zk),
            (cx + hw * 0.62, cy + y, zk + 0.10),
            (cx + hw * 0.97, cy + y, zc),
            (cx + hw, cy + y, zg),
            (cx + hw * 0.55, cy + y, zg - 0.05),
            (cx, cy + y, zg - 0.14),
            (cx - hw * 0.55, cy + y, zg - 0.05),
        ])
    b.loft(sections, colour)


def collar(b, cx, cy, stations, z0, z1, colour, bow=None, stern=None, w=0.66):
    """A square collar / gunwale cap around the hull outline, one beam per station side."""
    h = z1 - z0
    zc = (z0 + z1) / 2
    for side in (-1, 1):
        for (ya, ha), (yb, hb) in zip(stations, stations[1:]):
            b.beam((cx + side * (ha + 0.02), cy + ya, zc), (cx + side * (hb + 0.02), cy + yb, zc), w, h, colour)
    b.beam((cx - stations[-1][1] - 0.02, cy + stations[-1][0], zc),
           (cx + stations[-1][1] + 0.02, cy + stations[-1][0], zc), w, h, bow or colour)
    b.beam((cx - stations[0][1] - 0.02, cy + stations[0][0], zc),
           (cx + stations[0][1] + 0.02, cy + stations[0][0], zc), w, h, stern or colour)


def deck_spans(b, cx, cy, spans, z, colour):
    for y0, y1, hw in spans:
        b.box((cx - hw, cy + y0, z), (cx + hw, cy + y1, z + 0.12), colour, bevel=0.05)


def hw_at(stations, y):
    """Half-beam at a local station y (linear between stations)."""
    for (ya, ha), (yb, hb) in zip(stations, stations[1:]):
        if yb <= y <= ya:
            t = (y - yb) / (ya - yb)
            return hb + (ha - hb) * t
    return stations[0][1] if y > stations[0][0] else stations[-1][1]


# ------------------------------------------------------------------ Lv2 kit
def lv2_slip(b):
    """The wet slip, stone rims, tan plank pontoon deck with a painted walk line, two steps, yellow bollards and cleats."""
    x0, x1, y0, y1 = B2
    b.box((x0, y0, PLINTH), (x1, y1, SLIP), P.BLUE, bevel=0.03)
    b.box((x1, y0, PLINTH), (22.70, D2[2], SLIP), P.BLUE, bevel=0.03)    # r4: the mouth, wall to wall, ~4 deep
    rim(b, x0 - 0.50, y0 - 0.50, x0, 4.30, "+x")
    rim(b, x0, y0 - 0.50, 22.70, y0, "+y")
    rim(b, x0, y1, x1, 4.30, "-y")
    dx0, dx1, dy0, dy1 = D2
    b.box((dx0, dy0, PLINTH), (dx1, dy1, DECK - 0.18), P.DBG, bevel=0.05)
    b.box((dx0, dy0, DECK - 0.18), (dx1, dy1, DECK), P.TAN, bevel=0.06)
    planks(b, dx0 + 0.10, dx1 - 0.10, dy0 + 0.10, dy1 - 0.10, DECK)
    b.box((dx0 + 0.10, dy0 + 0.14, DECK), (dx0 + 0.26, dy1 - 0.14, DECK + 0.05), P.YELLOW, bevel=0.02)
    dashes(b, 20.30, -13.40, 2.20, DECK + 0.03)
    for y in (-13.40, -6.00, 4.20):
        bollard(b, 18.50, y, DECK)
    for y in (-12.60, -4.00):
        cleat(b, 18.35, y, DECK, 1.4)
    b.box((18.40, 6.70, PLINTH), (22.50, 5.90, 1.16), P.STONE, bevel=0.05)
    b.box((18.40, 5.90, PLINTH), (22.50, 5.10, 1.40), P.STONE, bevel=0.05)
    b.box((18.52, 6.60, 1.16), (22.38, 6.70, 1.21), P.YELLOW, bevel=0.01)
    b.box((18.52, 5.80, 1.40), (22.38, 5.90, 1.45), P.YELLOW, bevel=0.01)
    grid_studs(b, 18.90, 22.00, 6.06, 6.56, 1.16, P.LBG, nx=2, ny=1, r=0.30, h=0.18)
    grid_studs(b, 18.90, 22.00, 5.26, 5.76, 1.40, P.LBG, nx=2, ny=1, r=0.30, h=0.18)
    for rx, ry, w, l in ((13.20, -14.40, 0.16, 2.60), (16.70, 0.90, 0.14, 1.80), (14.10, 1.90, 0.16, 1.20)):
        b.box((rx - w / 2, ry - l / 2, SLIP), (rx + w / 2, ry + l / 2, SLIP + 0.02), P.GLASS, bevel=0.01)


FUEL = (19.30, 2.95)                      # fuel pump bund corner (x0, y0), 2.5 x 2.0, 5.6 tall: a mannequin high


def lv2_fuel(b):
    """A mannequin-high fuel pump: yellow base block, red body, grey canopy, display, side holster, hose to the RIB."""
    x0, y0 = FUEL
    z = DECK
    b.box((x0, y0, z), (x0 + 2.50, y0 + 2.00, z + 0.15), P.DBG, bevel=0.04)
    b.box((x0 + 0.06, y0 + 0.06, z + 0.15), (x0 + 2.44, y0 + 1.94, z + 0.19), P.YELLOW, bevel=0.02)
    b.box((x0 + 0.18, y0 + 0.18, z + 0.19), (x0 + 2.32, y0 + 1.82, z + 1.45), P.YELLOW, bevel=0.06)      # colour block
    b.box((x0 + 0.24, y0 + 0.24, z + 1.45), (x0 + 2.26, y0 + 1.76, z + 4.40), P.RED, bevel=0.07)
    b.box((x0 + 0.10, y0 + 0.10, z + 4.40), (x0 + 2.40, y0 + 1.90, z + 4.75), P.STONE, bevel=0.06)      # canopy
    b.box((x0 + 0.36, y0 + 0.36, z + 4.75), (x0 + 2.14, y0 + 1.64, z + 5.60), P.YELLOW, bevel=0.06)     # price sign
    b.box((x0 + 0.52, y0 + 0.30, z + 4.92), (x0 + 1.98, y0 + 0.37, z + 5.44), P.INK, bevel=0.02)
    for xx in (x0 + 0.62, x0 + 1.18):
        b.box((xx, y0 + 0.28, z + 5.06), (xx + 0.36, y0 + 0.33, z + 5.30), P.WHITE)
    b.box((x0 + 0.52, y0 + 0.14, z + 2.60), (x0 + 1.98, y0 + 0.26, z + 3.95), P.WHITE, bevel=0.03)       # display
    b.box((x0 + 0.62, y0 + 0.12, z + 2.74), (x0 + 1.88, y0 + 0.19, z + 3.81), P.INK, bevel=0.02)
    b.box((x0 + 0.62, y0 + 0.12, z + 1.75), (x0 + 1.88, y0 + 0.20, z + 2.10), P.WHITE, bevel=0.02)
    b.box((x0 + 0.06, y0 + 0.62, z + 2.20), (x0 + 0.28, y0 + 1.38, z + 3.60), P.LBG, bevel=0.04)         # holster
    b.box((x0 - 0.20, y0 + 0.82, z + 2.80), (x0 + 0.08, y0 + 1.18, z + 3.30), P.BLACK, bevel=0.04)
    disc_y(b, x0 + 1.25, y0 + 2.14, z + 2.80, 0.95, 0.30, P.DBG, 12)                                    # hose reel
    disc_y(b, x0 + 1.25, y0 + 2.14, z + 2.80, 0.36, 0.40, P.YELLOW, 8)
    for xx in (x0 + 0.12, x0 + 2.38):
        b.cyl(xx, y0 - 0.45, z, z + 1.40, 0.27, P.YELLOW, 8)
    rope(b, (x0 - 0.12, y0 + 1.00, z + 2.95), (17.55, 1.90, 3.45), 0.70, P.BLACK, 6, 0.20)


def jacket(b, xf, y, z, k=1.5):
    """One orange life jacket hanging on the rack (front faces -X), white bands, dark zip; k times the plain size."""
    def bx(x0, y0, z0, x1, y1, z1, c, bevel):
        b.box((xf + x0 * k, y + y0 * k, z + z0 * k), (xf + x1 * k, y + y1 * k, z + z1 * k), c, bevel=bevel * k)
    bx(0, -0.55, 0, 0.30, 0.55, 1.30, P.ORANGE, 0.05)
    bx(-0.02, -0.43, 1.30, 0.26, 0.43, 1.52, P.ORANGE, 0.04)
    bx(-0.03, -0.52, 0.42, 0.02, 0.52, 0.66, P.WHITE, 0.01)
    bx(-0.03, -0.52, 0.88, 0.02, 0.52, 1.04, P.WHITE, 0.01)
    bx(0.12, -0.08, 0.08, 0.31, 0.08, 1.30, P.DBG, 0.02)
    bx(-0.04, -0.18, 1.40, 0.10, 0.18, 1.53, P.INK, 0.02)
    bx(0.20, -0.05, 1.34, 0.24, 0.05, 1.98, P.BLACK, 0.0)


RACK_Y = (-10.40, -1.10)                  # life-jacket rack along the right fence


def lv2_jackets(b):
    """Navy gear locker against the fence, stone rack frame with a yellow rail, four big orange jackets."""
    y0, y1 = RACK_Y
    top = DECK + 1.60
    b.box((22.05, y0, DECK), (22.95, y1, top), P.INK, bevel=0.06)
    b.box((22.00, y0 - 0.06, top), (23.00, y1 + 0.06, top + 0.20), P.LBG, bevel=0.04)
    for y in (-8.20, -5.80, -3.40):
        b.box((22.03, y, DECK + 0.20), (22.07, y + 0.05, top - 0.15), P.DBG)
    for y in (y0 + 0.20, y1 - 0.20):
        b.box((22.52, y - 0.14, top + 0.20), (22.80, y + 0.14, 6.40), P.STONE, bevel=0.04)
    b.box((22.50, y0 + 0.06, 6.15), (22.82, y1 - 0.06, 6.40), P.YELLOW, bevel=0.04)
    for y in (-9.00, -6.90, -4.80, -2.70):
        jacket(b, 22.30, y, top + 0.24)


def rib(b):
    """r5: the RIB 25% bigger about its keel."""
    warped(b, rib_body, lambda x, y, z: (RIB_CX + RIB_K * (x - RIB_CX), RIB_CY + RIB_K * (y - RIB_CY), RIB_Z[0] + RIB_K * (z - RIB_Z[0])))


def rib_body(b):
    """The Lv2 RIB: grey hull, orange collar, navy console and screen, two jockey seats, black outboard."""
    cx, cy = RIB_CX, RIB_CY
    hull(b, cx, cy, RIB_ST, RIB_Z, P.LBG)
    collar(b, cx, cy, RIB_ST, 2.80, 3.50, P.ORANGE, bow=P.WHITE)
    deck_spans(b, cx, cy, ((-5.10, -4.40, 0.85), (-4.40, -1.60, 1.35), (-1.60, 1.00, 1.85),
                           (1.00, 5.40, 1.90)), 2.78, P.DBG)
    grid_studs(b, cx - 0.9, cx + 0.9, cy - 4.0, cy - 2.6, 2.88, P.LBG, nx=2, ny=1, r=0.28, h=0.18)
    b.box((cx - 0.60, cy - 5.30, 2.90), (cx + 0.60, cy - 4.85, 2.98), P.WHITE, bevel=0.03)
    yy = cy + 0.40
    b.box((cx - 0.85, cy - 1.20, 2.86), (cx + 0.85, yy, 4.12), P.INK, bevel=0.06)
    b.box((cx - 0.72, cy - 1.10, 4.12), (cx + 0.72, cy - 0.45, 4.22), P.INK, bevel=0.03)
    b.beam((cx, cy - 1.18, 4.18), (cx, cy - 0.58, 4.82), 1.66, 0.10, P.GLASS)
    for xx in (cx - 0.86, cx + 0.86):
        b.beam((xx, cy - 1.18, 4.20), (xx, cy - 0.58, 4.84), 0.12, 0.12, P.WHITE)
    b.beam((cx - 0.86, cy - 0.56, 4.82), (cx + 0.86, cy - 0.56, 4.82), 0.12, 0.12, P.WHITE)
    disc_y(b, cx, cy + 0.46, 3.66, 0.30, 0.10, P.DBG, 10)
    b.box((cx + 0.52, cy - 0.28, 4.12), (cx + 0.76, cy - 0.10, 4.36), P.YELLOW, bevel=0.02)
    b.cyl(cx - 0.52, cy - 0.60, 4.12, 4.34, 0.13, P.WHITE, 8)
    b.box((cx - 0.02, cy - 1.24, 3.06), (cx + 0.86, cy - 1.20, 3.92), P.WHITE, bevel=0.02)
    torus_y(b, cx + 0.42, cy - 1.27, 3.49, 0.34, 0.10, P.RED, 10, 4)
    for sy in (1.20, 2.90):
        b.box((cx - 0.66, cy + sy, 2.88), (cx + 0.66, cy + sy + 1.10, 3.42), P.ORANGE, bevel=0.05)
        b.box((cx - 0.62, cy + sy + 0.06, 3.42), (cx + 0.62, cy + sy + 1.06, 3.58), P.WHITE, bevel=0.03)
        b.box((cx - 0.66, cy + sy + 0.86, 3.58), (cx + 0.66, cy + sy + 1.10, 4.34), P.ORANGE, bevel=0.05)
        b.box((cx - 0.50, cy + sy + 0.54, 3.70), (cx + 0.50, cy + sy + 0.64, 3.80), P.YELLOW, bevel=0.02)
    b.box((cx - 0.56, cy + 5.30, 3.00), (cx + 0.56, cy + 6.10, 4.24), P.DBG, bevel=0.06)
    b.box((cx - 0.60, cy + 5.34, 3.60), (cx + 0.60, cy + 6.06, 3.78), P.YELLOW, bevel=0.02)
    b.box((cx - 0.30, cy + 5.42, 1.95), (cx + 0.30, cy + 6.02, 3.00), P.BLACK, bevel=0.04)
    xm = cx + hw_at(RIB_ST, 4.95) - 0.12
    b.box((xm - 0.10, cy + 4.86, 3.10), (xm + 0.10, cy + 5.06, 5.20), P.WHITE, bevel=0.03)
    b.box((xm - 0.24, cy + 4.90, 5.20), (xm + 0.24, cy + 5.02, 5.42), P.YELLOW, bevel=0.03)
    b.box((xm - 0.04, cy + 4.94, 5.42), (xm + 0.04, cy + 4.98, 5.80), P.LBG)
    for side, y, hw in ((-1, 3.90, 2.13), (1, 3.90, 2.13), (-1, -4.00, 1.55), (1, -4.00, 1.55)):
        x = cx + side * (hw_at(RIB_ST, y) - 0.16)
        b.box((x - 0.08, cy + y - 0.38, 3.50), (x + 0.08, cy + y + 0.38, 3.66), P.YELLOW, bevel=0.02)
        for dy in (-0.34, 0.34):
            b.box((x - 0.05, cy + y + dy - 0.05, 3.30), (x + 0.05, cy + y + dy + 0.05, 3.50), P.YELLOW)
    for xx, yy2 in ((cx + 0.72, cy - 4.70), (cx + 1.52, cy + 4.90)):
        b.box((xx - 0.12, yy2 - 0.12, 2.90), (xx + 0.12, yy2 + 0.12, 3.04), P.DBG, bevel=0.02)


# ------------------------------------------------------------------ Lv3 kit
def lv3_berth(b):
    """The lifeboat berth: wet slip, stone rims, tan plank walkway and back deck with a walk line, side step, bollards."""
    x0, x1, y0, y1 = B3
    b.box((x0, y0, PLINTH), (x1, y1, SLIP), P.BLUE, bevel=0.03)
    rim(b, -21.50, -13.10, x0, y1 + 0.50, "+x")
    rim(b, x0, -13.10, x1, y0, "+y")
    rim(b, x0, y1, x1, y1 + 0.50, "-y")
    dx0, dx1, dy0, dy1 = D3
    b.box((dx0, dy0, PLINTH), (dx1, dy1, DECK - 0.18), P.DBG, bevel=0.05)
    b.box((dx0, dy0, DECK - 0.18), (dx1, dy1, DECK), P.TAN, bevel=0.06)
    planks(b, dx0 + 0.10, dx1 - 0.10, dy0 + 0.10, dy1 - 0.10, DECK)
    b.box((x0, y1 + 0.50, PLINTH), (dx0, dy1, DECK - 0.18), P.DBG, bevel=0.05)
    b.box((x0, y1 + 0.50, DECK - 0.18), (dx0, dy1, DECK), P.TAN, bevel=0.06)
    planks(b, x0 + 0.10, dx0 - 0.10, y1 + 0.60, dy1 - 0.10, DECK, along_y=False)
    b.box((dx1 - 0.26, dy0 + 0.14, DECK), (dx1 - 0.10, dy1 - 0.14, DECK + 0.05), P.YELLOW, bevel=0.02)
    dashes(b, -12.95, -12.40, 11.60, DECK + 0.03)
    for y in (-11.20, 1.00, 10.50):
        bollard(b, -14.35, y, DECK)
    for y in (-8.80, 5.60):
        cleat(b, -14.38, y, DECK, 1.4)
    b.box((-10.90, 0.40, PLINTH), (-10.30, 4.80, 1.27), P.STONE, bevel=0.05)      # clear of the Lv1 work table
    b.box((-10.46, 0.50, 1.27), (-10.36, 4.70, 1.32), P.YELLOW, bevel=0.01)
    grid_studs(b, -10.82, -10.44, 1.10, 4.10, 1.27, P.LBG, nx=1, ny=2, r=0.24, h=0.14)
    for rx, ry, w, l in ((-19.90, -11.70, 0.16, 1.40), (-15.10, 3.00, 0.12, 1.60), (-18.40, 10.30, 0.16, 1.10)):
        b.box((rx - w / 2, ry - l / 2, SLIP), (rx + w / 2, ry + l / 2, SLIP + 0.02), P.GLASS, bevel=0.01)


def lifeboat(b):
    """The Lv3 lifeboat: 20.0 long, orange hull, a tall two-tier navy wheelhouse with window strips, orange top, mast."""
    t = lego.B()
    lifeboat_body(t)
    k = len(b.v)
    b.v.extend((x, LB_CY + (y - LB_CY) * LB_K, z) for x, y, z in t.v)
    b.f.extend((tuple(i + k for i in f), c) for f, c in t.f)
    # studs go on after the stretch so they stay round
    cx, cy, K = LB_CX, LB_CY, LB_K
    grid_studs(b, cx - 0.85, cx + 0.85, cy - 4.60 * K, cy - 3.20 * K, 3.18, P.ORANGE, nx=2, ny=1, r=0.28, h=0.16)
    grid_studs(b, cx - 1.20, cx + 1.20, cy + 3.10 * K, cy + 4.80 * K, 7.52, P.ORANGE, nx=3, ny=2, r=0.26, h=0.16)


def lifeboat_body(b):
    """The lifeboat drawn 15.6 long; lifeboat() stretches it by LB_K along Y."""
    cx, cy = LB_CX, LB_CY
    hull(b, cx, cy, LB_ST, LB_Z, P.ORANGE)
    collar(b, cx, cy, LB_ST, 3.08, 3.30, P.WHITE, w=0.34)
    deck_spans(b, cx, cy, ((-7.60, -6.00, 0.70), (-6.00, -3.00, 1.45), (-3.00, 0.60, 1.95),
                           (0.60, 5.80, 2.10), (5.80, 7.70, 2.20)), 3.06, P.STONE)
    for s in (-1, 1):
        b.beam((cx, cy - 6.40, 3.20), (cx + s * 1.20, cy - 4.80, 3.20), 0.34, 0.08, P.WHITE)
    # lower tier: navy walls, glass strip on four sides
    b.box((cx - 1.75, cy + 0.60, 3.10), (cx + 1.75, cy + 5.60, 5.50), P.INK, bevel=0.08)
    b.box((cx - 1.50, cy + 0.54, 4.20), (cx + 1.50, cy + 0.62, 5.15), P.GLASS)
    b.box((cx - 1.50, cy + 5.58, 4.20), (cx + 1.50, cy + 5.66, 5.15), P.GLASS)
    for s in (-1, 1):
        x = cx + s * 1.75
        b.box((x - 0.04, cy + 0.95, 4.20), (x + 0.04, cy + 5.25, 5.15), P.GLASS)
        for yy in (2.00, 3.30, 4.60):
            b.box((x - 0.06, cy + yy - 0.05, 4.20), (x + 0.06, cy + yy + 0.05, 5.15), P.WHITE)
        b.box((x - 0.05, cy + 5.05, 3.10), (x + 0.05, cy + 5.55, 4.05), P.DBG, bevel=0.02)       # door
    b.box((cx - 0.06, cy + 0.50, 4.20), (cx + 0.06, cy + 0.62, 5.15), P.WHITE)
    b.box((cx - 1.95, cy + 0.40, 5.50), (cx + 1.95, cy + 5.80, 5.72), P.LBG, bevel=0.05)           # ledge
    # upper tier: narrower, glass strip
    b.box((cx - 1.40, cy + 1.10, 5.72), (cx + 1.40, cy + 4.90, 7.20), P.INK, bevel=0.07)
    b.box((cx - 1.20, cy + 1.04, 6.30), (cx + 1.20, cy + 1.12, 7.05), P.GLASS)
    b.box((cx - 1.20, cy + 4.88, 6.30), (cx + 1.20, cy + 4.96, 7.05), P.GLASS)
    for s in (-1, 1):
        x = cx + s * 1.40
        b.box((x - 0.04, cy + 1.40, 6.30), (x + 0.04, cy + 4.60, 7.05), P.GLASS)
        for yy in (2.40, 3.40):
            b.box((x - 0.06, cy + yy - 0.05, 6.30), (x + 0.06, cy + yy + 0.05, 7.05), P.WHITE)
    b.box((cx - 0.06, cy + 1.00, 6.30), (cx + 0.06, cy + 1.12, 7.05), P.WHITE)
    b.box((cx - 1.65, cy + 0.90, 7.20), (cx + 1.65, cy + 5.10, 7.52), P.ORANGE, bevel=0.07)      # orange top
    # mast with spar, light bar and aerial
    b.box((cx - 0.42, cy + 1.90, 7.52), (cx + 0.42, cy + 2.50, 7.90), P.DBG, bevel=0.03)
    b.box((cx - 0.15, cy + 2.05, 7.90), (cx + 0.15, cy + 2.35, 11.50), P.WHITE, bevel=0.03)
    b.box((cx - 1.50, cy + 2.08, 9.30), (cx + 1.50, cy + 2.32, 9.48), P.WHITE, bevel=0.03)
    b.box((cx - 1.20, cy + 1.85, 10.55), (cx + 1.20, cy + 2.55, 10.95), P.DBG, bevel=0.04)       # light bar
    for xx in (-1.20, 0.55):
        b.box((cx + xx, cy + 1.85, 10.95), (cx + xx + 0.65, cy + 2.55, 11.28), P.BLUE, bevel=0.06)
    b.box((cx - 0.55, cy + 1.85, 10.95), (cx + 0.55, cy + 2.55, 11.28), P.WHITE, bevel=0.05)
    b.box((cx - 0.05, cy + 2.15, 11.50), (cx + 0.05, cy + 2.25, 12.20), P.LBG)
    b.box((cx - 0.09, cy + 2.11, 12.20), (cx + 0.09, cy + 2.29, 12.40), P.YELLOW, bevel=0.02)
    # stern cockpit: orange engine hatch, rail, life ring
    b.box((cx - 1.10, cy + 6.00, 3.10), (cx + 1.10, cy + 7.20, 3.95), P.ORANGE, bevel=0.06)
    b.box((cx - 0.80, cy + 6.05, 3.55), (cx + 0.80, cy + 6.17, 3.75), P.DBG, bevel=0.02)
    for xx in (cx - 2.00, cx, cx + 2.00):
        b.box((xx - 0.07, cy + 7.60, 3.10), (xx + 0.07, cy + 7.76, 4.30), P.YELLOW, bevel=0.02)
    b.beam((cx - 2.00, cy + 7.68, 4.26), (cx + 2.00, cy + 7.68, 4.26), 0.14, 0.14, P.YELLOW)
    torus_y(b, cx + 1.00, cy + 7.85, 3.85, 0.42, 0.11, P.RED, 10, 4)
    for y in (5.40, 1.80, -2.20):
        for s in (-1, 1):
            x = cx + s * (hw_at(LB_ST, y) + 0.12)
            b.cyl(x, cy + y, 1.90, 3.10, 0.20, P.BLACK, 8)
    b.box((cx - 0.22, cy - 7.75, 3.15), (cx + 0.22, cy - 7.45, 3.32), P.DBG, bevel=0.02)


def lv3_fittings(b):
    """The yellow davit on the walkway edge, arm, block and hook over the foredeck; the long crew bench on the walkway."""
    px, py = DVT_X, DVT_Y
    b.box((px - 0.80, py - 0.80, DECK), (px + 0.80, py + 0.80, DECK + 0.26), P.DBG, bevel=0.04)
    b.box((px - 0.55, py - 0.55, DECK + 0.26), (px + 0.55, py + 0.55, 8.20), P.YELLOW, bevel=0.05)
    for z in (DECK + 0.26, 4.60):
        b.box((px - 0.66, py - 0.66, z), (px + 0.66, py + 0.66, z + 0.30), P.DBG, bevel=0.03)
    b.box((px - 0.66, py - 0.66, 8.20), (px + 0.66, py + 0.66, 8.50), P.DBG, bevel=0.04)
    b.beam((px, py, 7.75), (px - 2.80, py, 7.75), 0.95, 0.95, P.YELLOW)
    b.beam((px - 2.80, py, 7.75), (px - 4.30, py, 7.25), 0.90, 0.90, P.YELLOW)
    b.beam((px - 0.50, py, 4.80), (px - 2.60, py, 7.20), 0.46, 0.46, P.YELLOW)                  # brace
    disc_y(b, px, py + 0.75, 5.90, 0.62, 0.40, P.DBG, 12)                                         # winch drum
    disc_y(b, px, py + 0.80, 5.90, 0.22, 0.50, P.LBG, 8)
    b.box((px - 0.10, py + 0.90, 5.90), (px + 0.10, py + 1.30, 6.90), P.LBG, bevel=0.02)          # crank
    bx, bz = px - 4.30, 6.60
    b.box((bx - 0.70, py - 0.50, bz - 0.20), (bx + 0.70, py + 0.50, bz + 0.65), P.RED, bevel=0.06)  # head block
    dz = 0.95                                 # the hook hangs clear of the stern hatch
    b.box((bx - 0.12, py - 0.09, bz - 2.00 + dz), (bx + 0.12, py + 0.09, bz - 0.20), P.BLACK)      # fall
    b.box((bx - 0.60, py - 0.42, 4.15 + dz), (bx + 0.60, py + 0.42, 4.90 + dz), P.YELLOW, bevel=0.05)   # hook block
    b.box((bx - 0.60, py - 0.42, 4.55 + dz), (bx + 0.60, py + 0.42, 4.75 + dz), P.RED, bevel=0.03)
    b.box((bx - 0.14, py - 0.14, 3.55 + dz), (bx + 0.14, py + 0.14, 4.15 + dz), P.DBG, bevel=0.02)      # hook shank
    b.box((bx - 0.56, py - 0.14, 3.30 + dz), (bx + 0.14, py + 0.14, 3.56 + dz), P.DBG, bevel=0.02)
    b.box((bx - 0.56, py - 0.14, 3.30 + dz), (bx - 0.30, py + 0.14, 3.95 + dz), P.DBG, bevel=0.02)
    # crew bench: navy frame, orange slat seat and back
    bx0, by0, bx1, by1 = BENCH
    for y in (by0 + 0.30, (by0 + by1) / 2, by1 - 0.30):
        b.box((bx0 + 0.10, y - 0.15, DECK), (bx1 - 0.10, y + 0.15, DECK + 1.40), P.INK, bevel=0.02)
    b.box((bx0, by0, DECK + 1.40), (bx1, by1, DECK + 1.60), P.INK, bevel=0.04)
    slat = (bx1 - 0.30 - bx0) / 3
    for i in range(3):
        b.box((bx0 + i * slat + 0.03, by0 + 0.04, DECK + 1.60), (bx0 + (i + 1) * slat - 0.03, by1 - 0.04, DECK + 1.80),
              P.ORANGE, bevel=0.03)
    for y in (by0 + 0.30, by1 - 0.30):
        b.box((bx1 - 0.32, y - 0.15, DECK + 1.80), (bx1, y + 0.15, DECK + 3.40), P.INK, bevel=0.02)
    for z in (DECK + 2.20, DECK + 2.90):
        b.box((bx1 - 0.22, by0 + 0.06, z), (bx1 - 0.04, by1 - 0.06, z + 0.45), P.ORANGE, bevel=0.03)
    grid_studs(b, bx0 + 0.25, bx1 - 0.55, by0 + 0.40, by1 - 0.40, DECK + 1.80, P.ORANGE, nx=2, ny=5, r=0.24, h=0.14)


# ------------------------------------------------------------------ PERF-BL11: shared craft
FW_Y0, FW_Y1 = -17.70, -16.90             # front wall faces (the code name sign stands proud at y -18.0)
BW_Y0, BW_Y1 = 18.20, 18.90               # back wall
WALL_X0, WALL_X1 = 22.75, 23.55           # low side wall (the code fence)
WALL_TOP = 3.68
GATE = 8.00                               # r3: low front wall stops here; gate posts x 6.62..8.00, the mouth 20% wider
DOOR_X, PIER_X, CORNER_X = 7.70, 9.20, 22.20   # r3: clear opening x +-7.20 (was 6.00)
DOOR_Z = 9.20                             # r4: the lintel 1.4 up, the cabin clears it in the game view
BOAT_DZ, BOAT_K = 1.35, 1.20              # r5: the dinghy 20% bigger about its stands, ~1 up; the bow past the door line
EAVE, RISE, ROOF_N, ROOF_HW = 12.55, 0.875, 8, 24.00
RIDGE = EAVE + ROOF_N * RISE
ROOF_Y0, ROOF_Y1 = -18.70, 19.70
SIGN_Z, SIGN_HW, SIGN_HH = 12.8225, 8.28, 2.50   # DockPieces: the code name sign 16.56 x 5.0 at y -17.77 (-18.0..-17.54)
SIGN_ICON_X = -5.78                       # the code icon's centre (0.03 + 0.1208 of the sign width): under the life ring
CONSOLE_TOP = 7.35
BOAT_Y = -15.00                           # r4: past the door line onto the apron; the blunter bow stays on the plinth
BOAT_ST = ((5.70, 2.45), (3.00, 2.45), (0.00, 2.38), (-1.82, 2.20), (-3.14, 1.85), (-3.97, 1.35), (-4.46, 0.75),
           (-4.70, 0.25))
CHAIR = (-18.00, 13.86)
TWR = (-23.20, -16.20, -19.30, -12.66)    # r4: Lv3 watch tower lower shaft x0, x1, y0, y1: 25% wider, over the slip's front rim
TWR_STEP = 0.40                           # r4: the upper shaft barely steps in: it holds on a phone
CUPOLA_LIFT = 2.50                        # r5: on a stalk, clear of the crest from the path
BAY_JAMB = (-16.70, -14.90)               # r4: the crane mast is the Lv3 bay's left jamb, in the tower's side
BAY_CX, BAY_HW, BAY_N, BAY_RISE, BAY_BASE = 16.60, 7.10, 6, 2.60, 13.55   # r5: peak 29.15, clears the main roof from the path


def keep_faces(b, keep):
    """Keep only these faces of the box just emitted (lego.B.box order: bottom, top, -Y, +X, +Y, -X)."""
    last = b.f[-6:]
    b.f[-6:] = [last[i] for i in keep]


def prism_y(b, y0, y1, profile, c):
    """An (x, z) polygon extruded along Y."""
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def courses(b, y, s, u0, u1, z0, z1, n=6, brick=3.60, holes=(), c=P.STONE):
    """Staggered brick seams 0.05 proud of a wall face at y (s = the outward normal's sign); holes = (u0, u1, z0, z1)."""
    t, p = 0.09, 0.05
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


def wall_holes(b, x0, x1, y0, y1, z0, z1, holes, c=P.WHITE):
    """A wall box with rectangular openings (u0, u1, zb, zt), sorted by u."""
    u = x0
    for h0, h1, zb, zt in holes:
        b.box((u, y0, z0), (h0, y1, z1), c, bevel=0.0)
        b.box((h0, y0, z0), (h1, y1, zb), c, bevel=0.0)
        b.box((h0, y0, zt), (h1, y1, z1), c, bevel=0.0)
        u = h1
    b.box((u, y0, z0), (x1, y1, z1), c, bevel=0.0)


def window(b, cx, w, z0, z1, y, s=-1, c=P.RED):
    """A framed inset window on a wall face at y (s = the outward normal's sign): proud frame, glass 0.3 back, cross
    mullion, a stud-topped sill brick."""
    out, ins = y + s * 0.20, y - s * 0.30
    fa, fb = sorted((out, ins))
    for x0, x1 in ((cx - w / 2 - 0.34, cx - w / 2 + 0.16), (cx + w / 2 - 0.16, cx + w / 2 + 0.34)):
        b.box((x0, fa, z0 - 0.16), (x1, fb, z1 + 0.34), c, bevel=0.05)
    b.box((cx - w / 2 + 0.16, fa, z1 - 0.16), (cx + w / 2 - 0.16, fb, z1 + 0.34), c, bevel=0.05)
    b.box((cx - w / 2 + 0.16, fa, z0 - 0.16), (cx + w / 2 - 0.16, fb, z0 + 0.14), c, bevel=0.03)
    ga, gb = sorted((ins, ins - s * 0.10))
    b.box((cx - w / 2 + 0.16, ga, z0 + 0.14), (cx + w / 2 - 0.16, gb, z1 - 0.16), P.GLASS, bevel=0.0)
    ma, mb = sorted((ins + s * 0.04, ins + s * 0.16))
    b.box((cx - 0.13, ma, z0 + 0.14), (cx + 0.13, mb, z1 - 0.16), P.WHITE, bevel=0.0)
    zm = (z0 + z1) / 2
    b.box((cx - w / 2 + 0.16, ma, zm - 0.13), (cx + w / 2 - 0.16, mb, zm + 0.13), P.WHITE, bevel=0.0)
    sa, sb = sorted((y + s * 0.62, y))
    b.box((cx - w / 2 - 0.62, sa, z0 - 0.74), (cx + w / 2 + 0.62, sb, z0 - 0.26), P.STONE, bevel=0.06)
    b.stud_row(cx - w / 2 - 0.2, y + s * 0.31, cx + w / 2 + 0.2, y + s * 0.31, z0 - 0.26, P.STONE, spacing=1.3, r=0.22,
               h=0.14, n=8)


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


def proud_window(b, cx, w, z0, z1, y, c=P.RED):
    """A lean window on a solid face at y (facing -Y): glass just proud of it, a proud frame round it, a mullion, a grey sill."""
    fo, fi = y - 0.34, y + 0.02
    for a, d in ((cx - w / 2 - 0.30, cx - w / 2), (cx + w / 2, cx + w / 2 + 0.30)):
        b.box((a, fo, z0 - 0.08), (d, fi, z1 + 0.30), c, bevel=0.04)
    b.box((cx - w / 2, fo, z1), (cx + w / 2, fi, z1 + 0.30), c, bevel=0.04)
    b.box((cx - w / 2, y - 0.09, z0), (cx + w / 2, y + 0.02, z1), P.GLASS, bevel=0.0)
    b.box((cx - 0.12, y - 0.18, z0), (cx + 0.12, y + 0.02, z1), P.WHITE, bevel=0.0)
    b.box((cx - w / 2 - 0.46, y - 0.62, z0 - 0.42), (cx + w / 2 + 0.46, y + 0.02, z0), P.STONE, bevel=0.05)


def ring_y(b, cx, y, cz, R, r, a=P.RED, d=P.WHITE, seg=4, sub=3):
    """A chunky life ring facing -Y: seg x 2 alternating sectors, each a closed tube."""
    for k in range(seg * 2):
        rings = []
        for i in range(sub + 1):
            u = 2 * math.pi * (k + i / sub) / (seg * 2) + math.pi / 8
            rings.append([(cx + (R + r * m) * math.cos(u), y + r * q, cz + (R + r * m) * math.sin(u))
                          for m, q in ((1, 0), (0, 1), (-1, 0), (0, -1))])
        b.loft(rings, a if k % 2 == 0 else d)


def brick_stack(b, x0, x1, y0, y1, z0, z1, n, c, c2=None, foot=True):
    """A post of stacked bricks over a slimmer dark core, seams showing, on a grey footing (foot=2: two steps)."""
    if foot == 2:
        b.box((x0 - 0.30, y0 - 0.30, z0), (x1 + 0.30, y1 + 0.30, z0 + 0.34), P.STONE, bevel=0.05)
        z0 += 0.34
    if foot:
        b.box((x0 - 0.14, y0 - 0.14, z0), (x1 + 0.14, y1 + 0.14, z0 + 0.50), P.STONE, bevel=0.05)
        z0 += 0.50
    b.box((x0 + 0.12, y0 + 0.12, z0), (x1 - 0.12, y1 - 0.12, z1), P.DBG, bevel=0.0)
    h = (z1 - z0) / n
    for i in range(n):
        b.box((x0, y0, z0 + i * h + 0.06), (x1, y1, z0 + (i + 1) * h - 0.06), (c2 if c2 is not None and i % 2 else c), bevel=0.05)


def low_wall(b, x0, x1, y0, y1):
    """The code's low white fence as a Lego wall: staggered 4-stud bricks on a grey base, stud-capped plates."""
    along_y = (y1 - y0) > (x1 - x0)
    L = (y1 - y0) if along_y else (x1 - x0)
    a0 = y0 if along_y else x0
    zs = (PLINTH, 1.60, 2.64, WALL_TOP - 0.20)
    for k in range(3):
        cuts = [a0] + [a0 + t for t in [((i + 0.5 * (k % 2)) * 4.0) for i in range(1, 12)] if t < L - 1.0] + [a0 + L]
        for u0, u1 in zip(cuts, cuts[1:]):
            lo = (x0, u0, zs[k]) if along_y else (u0, y0, zs[k])
            hi = (x1, u1, zs[k + 1]) if along_y else (u1, y1, zs[k + 1])
            b.box(lo, hi, P.STONE if k == 0 else P.WHITE, bevel=0.07)
    n = max(1, int(L / 2.6))
    for i in range(n):
        u0, u1 = a0 + i * L / n + 0.04, a0 + (i + 1) * L / n - 0.04
        lo = (x0 - 0.08, u0, WALL_TOP - 0.20) if along_y else (u0, y0 - 0.08, WALL_TOP - 0.20)
        hi = (x1 + 0.08, u1, WALL_TOP) if along_y else (u1, y1 + 0.08, WALL_TOP)
        b.box(lo, hi, P.RED, bevel=0.04)
        u = (u0 + u1) / 2
        cx, cy = ((x0 + x1) / 2, u) if along_y else (u, (y0 + y1) / 2)
        b.cyl(cx, cy, WALL_TOP, WALL_TOP + 0.22, 0.34, P.RED, n=6, bottom=False)


def stepped_roof(b, cx, hw, n, base, rise, y0, y1, thick, r=0.85, h=0.45, spacing=3.20, seam=6.40, bands=None, cap=P.WHITE, cap_stud=P.RED, eave=(), edge=P.RED, edge_t=None):
    """Thick stepped Lego slope courses meeting at a ridge along Y: staggered bricks, dark-red edge tiles front and back,
    a row of chunky studs on every tread. bands = {course: colour} (r2: trim courses); a stepped white ridge cap, 2 tall.
    eave = the sides whose first tread carries eave_row's tiles instead of studs."""
    dx = hw / n
    bands = bands or {}
    for side in (-1, 1):
        for i in range(n):
            xa, xb = cx + side * (hw - i * dx), cx + side * (hw - (i + 1) * dx - 0.02)
            zt = base + (i + 1) * rise
            z0 = max(base, zt - thick)
            E = 1.30                                # edge tile length
            cuts = [y0 + E]
            y = y0 + E + (seam / 2 if i % 2 else seam)
            while y < y1 - E - 1.0:
                cuts.append(y)
                y += seam
            cuts.append(y1 - E)
            field = bands.get(i, P.RED)                # r6: bright edge tiles, no muddy stepped band on the front
            ze = max(base, zt - edge_t) if edge_t else z0
            b.box((min(xa, xb), y0, ze), (max(xa, xb), cuts[0], zt), edge, bevel=0.07)
            b.box((min(xa, xb), cuts[-1], ze), (max(xa, xb), y1, zt), edge, bevel=0.07)
            for u0, u1 in zip(cuts, cuts[1:]):
                b.box((min(xa, xb), u0, z0), (max(xa, xb), u1, zt), field, bevel=0.07)
            xm = cx + side * (hw - (i + 0.5) * dx)
            if i < n - 1 and not (i == 0 and side in eave):
                b.cyl(xm, y0 + E / 2, zt, zt + h, min(r, 0.60), edge, 6, bottom=False)
                b.cyl(xm, y1 - E / 2, zt, zt + h, min(r, 0.60), edge, 6, bottom=False)
                b.stud_row(xm, y0 + E + spacing / 2, xm, y1 - E - spacing / 2, zt, field, spacing=spacing,
                           r=r, h=h, n=8)
    top = base + n * rise
    b.box((cx - 2.10, y0 - 0.12, top - 0.10), (cx + 2.10, y1 + 0.12, top + 0.85), cap, bevel=0.08)
    b.box((cx - 1.25, y0 - 0.06, top + 0.83), (cx + 1.25, y1 + 0.06, top + 1.80), cap, bevel=0.08)
    b.stud_row(cx, y0 + 0.5, cx, y1 - 0.5, top + 1.80, cap_stud, spacing=3.60, r=0.62, h=0.30, n=8)


def eave_row(b, s, x_out, y0, y1, z_lip, z_lip_top, z_tread, width, r, step=4.80):
    """A stepped white eave on the s * X slope: a solid lip, then full-size 2-stud tiles on the first tread above it."""
    x0, x1 = sorted((s * (x_out - 0.06), s * (x_out + 0.46)))
    b.box((x0, y0, z_lip), (x1, y1, z_lip_top), P.WHITE, bevel=0.06)
    x0, x1 = sorted((s * (x_out + 0.10), s * (x_out + 0.10 - width)))
    k = int((y1 - y0) / step)
    t = (y1 - y0) / k
    for i in range(k):
        ya = y0 + i * t
        b.box((x0, ya + 0.03, z_tread - 0.05), (x1, ya + t - 0.03, z_tread + 0.55), P.WHITE, bevel=0.07)
        for y in (ya + t / 4, ya + 3 * t / 4):
            b.cyl((x0 + x1) / 2, y, z_tread + 0.55, z_tread + 0.87, r, P.WHITE, 8, bottom=False)


def gable_rows(b, cx, hw, n, base, rise, y0, y1, c):
    """A stepped gable fill under a stepped_roof: one bevelled course per step."""
    dx = hw / n
    for j in range(n):
        h = hw - (j + 0.5) * dx
        b.box((cx - h, y0, base - 0.12 + j * rise), (cx + h, y1, base - 0.12 + (j + 1) * rise), c, bevel=0.04)   # under the treads: no white at the seams


def plaque(b, x0, x1, z0, z1, y, rim, board=P.INK):
    """A framed sign proud of a wall at y (facing -Y): bevelled rim, depth 0.5, a stud row on top; returns the board face."""
    out = y - 0.50
    for a, d in ((x0 - 0.42, x0), (x1, x1 + 0.42)):
        b.box((a, out, z0 - 0.42), (d, y + 0.02, z1 + 0.42), rim, bevel=0.07)
    b.box((x0, out, z0 - 0.42), (x1, y + 0.02, z0), rim, bevel=0.05)
    b.box((x0, out, z1), (x1, y + 0.02, z1 + 0.42), rim, bevel=0.05)
    b.box((x0, y - 0.22, z0), (x1, y + 0.02, z1), board, bevel=0.0)
    b.stud_row(x0 + 0.3, y - 0.25, x1 - 0.3, y - 0.25, z1 + 0.42, rim, spacing=1.25, r=0.26, h=0.16, n=8)
    return y - 0.22


# ------------------------------------------------------------------ Lv1
def lv1_floor(b):
    """Calm light-grey 4-stud tiles in a running bond on a dark bed, a tan path from the gate to the slip's end, two
    dark slip rails under the boat, a red trim round the slab."""
    TS, gap, top = 3.60, 0.12, 0.99
    PX, PY1 = 4.60, 6.30
    Zb = PLINTH + 0.03
    y0, y1 = -19.40, 18.40
    b._emit([(-23.4, y0, Zb), (23.4, y0, Zb), (23.4, y1, Zb), (-23.4, y1, Zb)], ((0, 1, 2, 3),), P.DBG)
    n = int((y1 - y0) / TS)
    ts = (y1 - y0) / n
    for j in range(n):
        ya = y0 + j * ts
        ed = [-23.4 + (k + (0.5 if j % 2 else 0.0)) * TS for k in range(14)]
        ed = sorted({-23.4, 23.4, -PX, PX} | {e for e in ed if -23.4 < e < 23.4 and abs(abs(e) - PX) > 0.9})
        for x0, x1 in zip(ed, ed[1:]):
            c = P.TAN if abs((x0 + x1) / 2) < PX and ya < PY1 else P.LBG
            b.box((x0 + gap / 2, ya + gap / 2, PLINTH - 0.02), (x1 - gap / 2, ya + ts - gap / 2, top), c, bevel=0.05)
            keep_faces(b, (1, 2, 3, 4, 5))
    # r3: the slip mouth's apron, wall to wall: a 2-deep yellow/red hazard edge at the gate, a white slab through the door
    AW, HY0, HY1 = 6.55, -19.70, -17.70
    k = 8
    for i in range(k):
        xa, xd = -AW + i * 2 * AW / k, -AW + (i + 1) * 2 * AW / k
        b.box((xa + 0.03, HY0, top - 0.03), (xd - 0.03, HY1, top + 0.27), P.YELLOW if i % 2 else P.DBG, bevel=0.05)
        keep_faces(b, (1, 2, 3, 4, 5))
    b.box((-DOOR_X + 0.52, HY1 + 0.04, top - 0.04), (DOOR_X - 0.52, -15.70, top + 0.13), P.WHITE, bevel=0.04)
    keep_faces(b, (1, 2, 3, 4, 5))
    # the bright slip ramp, from the apron through the door: white slabs with crisp seams, two big yellow rails
    RY0, RY1, RW = HY1 + 0.04, HALL_Y[0] - 0.10, 5.20
    k = int(round((RY1 - RY0) / 5.8))
    for i in range(k):
        ya, yd = RY0 + i * (RY1 - RY0) / k, RY0 + (i + 1) * (RY1 - RY0) / k
        b.box((-RW, ya + 0.04, top - 0.02), (RW, yd - 0.04, top + 0.19), P.WHITE, bevel=0.04)
    for s in (-1, 1):
        x0, x1 = sorted((s * 4.20, s * 5.00))           # r6: launch rails each side of the hull, stopping short of the boat slot
        b.box((x0, RY0 + 0.02, top + 0.15), (x1, -4.60, top + 0.52), P.YELLOW, bevel=0.06)
        b.stud_row(s * 4.60, RY0 + 0.8, s * 4.60, -5.40, top + 0.52, P.YELLOW, spacing=2.9, r=0.26, h=0.16, n=8)
    # r5: the bright water wedge under the hull, stepping in from the door to the ramp's rails
    for ya, yd, hw in ((HY1 + 0.04, -13.90, 6.60), (-13.90, -10.30, 5.30), (-10.30, -6.70, 4.10), (-6.70, -3.10, 2.90)):
        b.box((-hw, ya, top - 0.02), (hw, yd, top + 0.30), P.BLUE, bevel=0.04)
        keep_faces(b, (1, 2, 3, 4, 5))
    for x, y, w in ((-5.00, -15.60, 2.20), (4.60, -14.60, 1.60), (-3.90, -10.20, 1.40), (3.70, -8.70, 1.20)):
        b.box((x - w / 2, y - 0.16, top + 0.30 - 0.01), (x + w / 2, y + 0.16, top + 0.34), P.GLASS, bevel=0.0)
        keep_faces(b, (1, 2, 3, 4, 5))
    E, T = 0.06, 0.30
    for s in (-1, 1):
        b.box((s * (23.725 - T), -19.725 - E, 0.50), (s * (23.725 + E), 19.725 + E, 0.97), P.RED, bevel=0.03)
    b.box((-23.725 + T, -19.725 - E, 0.50), (23.725 - T, -19.725 + T, 0.97), P.RED, bevel=0.03)
    b.box((-23.725 + T, 19.725 - T, 0.50), (23.725 - T, 19.725 + E, 0.97), P.RED, bevel=0.03)


HALL_Y, HALL_HW = (1.40, 2.00), 10.00       # r5: fills the door's view from the path, clear of the trailer's drawbar
CREST_Z0, CREST_TILT = 17.87, math.radians(16)    # r5: the board's foot, 1.3 clear of the sign; leans back for the game angle


def crest(b):
    """The life ring on a white gable plaque with a red rim, leaning back on red stepped backing; r6: nothing dark behind it."""
    z0, Y, HW, H = CREST_Z0, -19.60, 2.15, 4.10
    ca, sa = math.cos(CREST_TILT), math.sin(CREST_TILT)

    def face(t):
        fz = plaque(t, -HW, HW, z0, z0 + H, Y, P.RED, P.WHITE)
        disc_y(t, 0.0, fz - 0.03, z0 + H / 2, 2.02, 0.05, P.RED, 16)      # the white sectors stay outlined on the white board
        ring_y(t, 0.0, fz - 0.40, z0 + H / 2, 1.44, 0.50)

    warped(b, face, lambda x, y, z: (x, Y + (y - Y) * ca + (z - z0) * sa, z0 + (z - z0) * ca - (y - Y) * sa))
    b.box((-1.80, -19.85, z0 - 0.95), (1.80, -18.60, z0 - 0.38), P.RED, bevel=0.06)         # foot, on the roof's edge
    b.box((-1.80, -18.70, z0 - 0.40), (1.80, FW_Y0 + 0.04, z0 + 3.00), P.RED, bevel=0.06)   # backing, behind the board


def lv1_walls(b):
    """Low fence walls, red gate posts, the big red boat-bay portal with a rolled-up striped door, corner and mid posts,
    the eave bands, the white gable with its life-ring sign, the back wall with a big window and a ceiling."""
    for s in (-1, 1):
        low_wall(b, *sorted((s * WALL_X0, s * WALL_X1)), FW_Y0 - 1.05, BW_Y0)
        # gate posts
        x0, x1 = sorted((s * (GATE - 1.38), s * GATE))
        brick_stack(b, x0 + 0.14, x1 - 0.14, -19.56, -18.60, PLINTH, 4.83, 3, P.RED)
        b.cyl((x0 + x1) / 2, -19.08, 4.83, 5.08, 0.42, P.RED, 10, bottom=False)
        # portal piers: red bricks on dark footings, proud of the wall
        x0, x1 = sorted((s * DOOR_X, s * PIER_X))
        brick_stack(b, x0, x1, FW_Y0 - 0.25, FW_Y1 + 0.15, PLINTH, DOOR_Z, 7, P.RED, foot=2)
        # the thick door frame: a white jamb inside each pier, two stepped arch bricks at the head
        x0, x1 = sorted((s * (DOOR_X - 0.50), s * DOOR_X))
        b.box((x0, FW_Y0 - 0.32, PLINTH + 0.08), (x1, FW_Y1 + 0.05, DOOR_Z - 0.10), P.WHITE, bevel=0.05)
        # r3: the 1-stud red arch's stepped corners
        for a, d, zb in ((DOOR_X - 1.60, DOOR_X - 0.50, DOOR_Z - 1.25), (DOOR_X - 2.70, DOOR_X - 1.60, DOOR_Z - 0.75)):   # r6: 1 brick up, the whole hull shows
            x0, x1 = sorted((s * a, s * d))
            b.box((x0, FW_Y0 - 0.26, zb), (x1, FW_Y1 + 0.05, DOOR_Z - 0.10), P.RED, bevel=0.05)
        # corner piers and the side mid posts
        x0, x1 = sorted((s * CORNER_X, s * 23.60))
        brick_stack(b, x0, x1, FW_Y0 - 0.15, FW_Y1 + 0.20, PLINTH, EAVE - 0.85, 8, P.RED, foot=2)
        x0, x1 = sorted((s * 22.45, s * 23.75))
        brick_stack(b, x0, x1, -0.75, 0.75, WALL_TOP - 0.20, EAVE, 6, P.RED, foot=False)
        # eave band over the flanks
        x0, x1 = sorted((s * (PIER_X + 0.15), s * 23.70))
        b.box((x0, FW_Y0 - 0.15, 11.70), (x1, FW_Y1, EAVE), P.STONE, bevel=0.05)
    # portal header round the code sign, sign rim, the arch's crown and the red/white striped roller drum: the door is up
    b.box((-PIER_X - 0.15, FW_Y0 - 0.15, DOOR_Z), (PIER_X + 0.15, FW_Y1 + 0.15, EAVE), P.RED, bevel=0.06)
    b.box((-DOOR_X + 0.46, FW_Y0 - 0.26, DOOR_Z - 0.14), (DOOR_X - 0.46, FW_Y1 + 0.05, DOOR_Z + 0.04), P.RED, bevel=0.03)
    k = 14
    for i in range(k):
        xa = -PIER_X - 0.15 + i * 2 * (PIER_X + 0.15) / k
        b.box((xa + 0.02, FW_Y0 - 0.42, DOOR_Z - 0.06), (xa + 2 * (PIER_X + 0.15) / k - 0.02, FW_Y0 - 0.10, DOOR_Z + 0.65), P.WHITE if i % 2 else P.RED, bevel=0.05)
        keep_faces(b, (0, 1, 2, 3, 5))
    rx, rz0, rz1 = SIGN_HW + 0.05, SIGN_Z - SIGN_HH - 0.05, SIGN_Z + SIGN_HH + 0.05
    fy0, fy1 = FW_Y0 - 0.60, FW_Y0 - 0.14
    FW, FT, RM = 0.60, 0.50, 0.14                 # r5: a thicker gold frame + a white rim part the red sign from the red roof
    for s in (-1, 1):
        x0, x1 = sorted((s * rx, s * (rx + FW)))
        b.box((x0, fy0, rz0 - 0.42), (x1, fy1, rz1 + FT), P.YELLOW, bevel=0.07)
        x0, x1 = sorted((s * (rx + FW), s * (rx + FW + RM)))
        b.box((x0, fy0 + 0.06, rz0 - 0.42), (x1, fy1, rz1 + FT + RM), P.WHITE, bevel=0.03)
    b.box((-rx, fy0, rz0 - 0.42), (rx, fy1, rz0), P.YELLOW, bevel=0.05)
    b.box((-rx, fy0, rz1), (rx, fy1, rz1 + FT), P.YELLOW, bevel=0.05)
    b.box((-rx - FW, fy0 + 0.06, rz1 + FT), (rx + FW, fy1, rz1 + FT + RM), P.WHITE, bevel=0.03)
    b.stud_row(-rx + 0.3, -18.05, rx - 0.3, -18.05, rz1 + FT + RM, P.WHITE, spacing=1.8, r=0.20, h=0.16, n=6)
    disc_y(b, SIGN_ICON_X, -18.05, SIGN_Z, 2.10, 0.08, P.WHITE, 16)      # covers the code icon under the ring
    ring_y(b, SIGN_ICON_X, -18.68, SIGN_Z, 1.50, 0.60)                  # inside the sign, off the pier
    # the white gable, front (with the rescue sign) and back
    gable_rows(b, 0.0, ROOF_HW, ROOF_N, EAVE, RISE, FW_Y0, FW_Y1, P.WHITE)
    gable_rows(b, 0.0, ROOF_HW, ROOF_N, EAVE, RISE, BW_Y0, BW_Y1, P.WHITE)
    for j in range(ROOF_N):
        h = ROOF_HW - (j + 0.5) * ROOF_HW / ROOF_N
        z0, z1 = EAVE + j * RISE, EAVE + (j + 1) * RISE
        u = -h + (2.8 if j % 2 else 5.6)
        while u < h - 0.6:
            if abs(u) > 3.9:
                b.box((u - 0.05, FW_Y0 - 0.05, z0 + 0.04), (u + 0.05, FW_Y0, z1 - 0.04), P.STONE, bevel=0.0)
                keep_faces(b, (1, 2, 3, 5))
            u += 5.6
    crest(b)
    # the back wall: bricks, a base and eave band, one big window on the slip's line (lit from the sea side)
    wall_holes(b, -WALL_X1, WALL_X1, BW_Y0, BW_Y1, PLINTH, 11.70, [(-4.20, 4.20, 4.80, 10.40)])
    holes = [(-5.0, 5.0, 3.6, 11.0)]
    for y, s in ((BW_Y0, -1), (BW_Y1, 1)):
        if s > 0:                                 # the inside stays calm
            courses(b, y, s, -WALL_X1 + 0.1, WALL_X1 - 0.1, PLINTH + 0.95, 11.60, n=7, holes=holes)
            window(b, 0.0, 8.40, 4.80, 10.40, y, s)
    b.box((-4.20, BW_Y0 + 0.05, 4.80), (4.20, BW_Y0 + 0.15, 10.40), P.WHITE, bevel=0.0)   # r5: the hero's backdrop: one calm white wall, the window only outside
    b.box((-WALL_X1, BW_Y0 - 0.14, PLINTH), (WALL_X1, BW_Y0, PLINTH + 0.80), P.STONE, bevel=0.05)
    b.box((-23.70, BW_Y0 - 0.14, 11.70), (23.70, BW_Y1 + 0.14, EAVE), P.STONE, bevel=0.05)
    # r3, the rear: a 2-brick base course, red corner piers, 2 pilasters, a red + white stepped eave
    for k in range(2):
        u = -WALL_X1 + (2.8 if k else 0.0)
        cuts = [-WALL_X1] + [u + 5.6 * i for i in range(1, 9) if -WALL_X1 < u + 5.6 * i < WALL_X1 - 0.5] + [WALL_X1]
        for a, d in zip(cuts, cuts[1:]):
            b.box((a + 0.03, BW_Y1 - 0.02, PLINTH + k * 0.62), (d - 0.03, BW_Y1 + 0.22, PLINTH + (k + 1) * 0.62), P.STONE, bevel=0.05)
            keep_faces(b, (1, 3, 4, 5))
    for s in (-1, 1):
        x0, x1 = sorted((s * CORNER_X, s * 23.60))
        brick_stack(b, x0, x1, BW_Y0 - 0.20, BW_Y1 + 0.30, PLINTH, 11.70, 6, P.RED, foot=2)
        x0, x1 = sorted((s * 10.50, s * 11.90))
        brick_stack(b, x0, x1, BW_Y1 - 0.10, BW_Y1 + 0.30, PLINTH, 11.20, 5, P.RED)
    b.box((-23.70, BW_Y1 - 0.02, 11.14), (23.70, BW_Y1 + 0.34, 11.72), P.RED, bevel=0.05)
    b.box((-23.80, BW_Y1 + 0.10, 11.68), (23.80, BW_Y1 + 0.62, 12.50), P.WHITE, bevel=0.06)
    # r5: the slip hall's back wall right behind the hero, calm and near the light; walk round it on either side to the trailer
    HY0_, HY1_ = HALL_Y
    b.box((-HALL_HW, HY0_, 0.97), (HALL_HW, HY1_, EAVE - 0.09), P.WHITE, bevel=0.0)
    b.box((-HALL_HW, HY0_ - 0.12, 0.97), (HALL_HW, HY0_ + 0.02, 1.75), P.STONE, bevel=0.05)
    courses(b, HY0_, -1, -HALL_HW + 0.05, HALL_HW - 0.05, 1.75, 9.45, n=2, brick=6.40)
    # ceiling and two light tie beams: no dark void under the roof
    b.box((-23.90, FW_Y1, EAVE - 0.11), (23.90, ROOF_Y1 - 0.05, EAVE - 0.05), P.WHITE, bevel=0.0)
    for s in (-1, 1):                         # the front soffit stops at the sign frame: no line across the name
        x0, x1 = sorted((s * 8.85, s * 23.90))
        b.box((x0, ROOF_Y0 + 0.05, EAVE - 0.11), (x1, FW_Y1, EAVE - 0.05), P.WHITE, bevel=0.0)
    for y in (-9.00, 9.00):
        b.box((-22.70, y - 0.45, 12.00), (22.70, y + 0.45, EAVE - 0.11), P.STONE, bevel=0.0)


def lv1_roof(b):
    """The thick stepped red roof: bevelled courses, dark-red edge tiles front and back, studs on every tread, ridge cap."""
    stepped_roof(b, 0.0, ROOF_HW, ROOF_N, EAVE, RISE, ROOF_Y0, ROOF_Y1, 2.20, bands={0: P.WHITE},
                 eave=(-1, 1))
    for s in (-1, 1):                           # the lip closes the corners and the ceiling edge
        eave_row(b, s, ROOF_HW, ROOF_Y0 - 0.10, ROOF_Y1 + 0.10, 12.20, 13.30, EAVE + RISE, 2.60, 0.62)
    # r6: one straight 2-stud white tile course on a red lip along the front eave, either side of the sign
    k = 6
    for s in (-1, 1):
        x0, x1 = sorted((s * 9.05, s * 24.40))
        b.box((x0, -18.85, 12.60), (x1, -17.80, 13.00), P.RED, bevel=0.05)
        for i in range(k):
            a, d = 9.05 + i * (24.40 - 9.05) / k + 0.03, 9.05 + (i + 1) * (24.40 - 9.05) / k - 0.03
            x0, x1 = sorted((s * a, s * d))
            b.box((x0, -18.80, 12.96), (x1, -17.80, 13.75), P.WHITE, bevel=0.07)
            for u in (x0 + (x1 - x0) / 4, x0 + 3 * (x1 - x0) / 4):
                b.cyl(u, -18.30, 13.75, 14.03, 0.42, P.WHITE, 8, bottom=False)
    cupola(b, 0.0, -8.00, RIDGE + 1.70 + CUPOLA_LIFT)
    brick_stack(b, -2.30, 2.30, -10.30, -5.70, RIDGE + 1.70, RIDGE + 1.32 + CUPOLA_LIFT, 2, P.RRED, foot=False)


def cupola(b, cx, cy, z):
    """The mid-ridge cupola, Lv1's own peak: a red base, white posts round a glass lantern, a stepped red cap, a yellow knob."""
    b.box((cx - 3.00, cy - 3.00, z - 0.40), (cx + 3.00, cy + 3.00, z + 0.40), P.RED, bevel=0.07)
    b.box((cx - 2.00, cy - 2.00, z + 0.40), (cx + 2.00, cy + 2.00, z + 2.70), P.GLASS, bevel=0.0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            xa, xd = sorted((cx + sx * 2.45, cx + sx * 1.60))
            ya, yd = sorted((cy + sy * 2.45, cy + sy * 1.60))
            b.box((xa, ya, z + 0.40), (xd, yd, z + 2.70), P.WHITE, bevel=0.05)
    zc = z + 2.70
    for d, t, c in ((3.20, 0.55, P.WHITE), (2.30, 0.60, P.RED), (1.30, 0.60, P.RED)):
        b.box((cx - d, cy - d, zc), (cx + d, cy + d, zc + t), c, bevel=0.07)
        zc += t
    b.cyl(cx, cy, zc, zc + 0.55, 0.62, P.YELLOW, 10, bottom=False)


FLANK_WX = (12.84, 18.73)                  # r4: window centres, frames ~1 brick clear of the red piers
DORMER_X, DORMER_Y = 13.50, -13.50         # r3: a symmetric pair on the slopes, far enough forward to clear the eave from the path


def dormer(b, s, x, y):
    """A real dormer on the s * X slope: white walls in a band / corner shell round framed inset blue windows on its -Y and
    outward faces, a two-tier stepped red cap, a stud on top."""
    cx = s * x
    z = 17.35                                  # r6: 1 brick up; the window's sill clears the tread on the ridge side
    hx, hy, W, zw0, zw1 = 2.40, 2.50, 2.60, z + 0.40, z + 2.00
    z0, z1 = z - 2.20, zw1 + 0.60
    b.box((cx - hx - 0.30, y - hy - 0.30, z0), (cx + hx + 0.30, y + hy + 0.30, 17.05), P.RED, bevel=0.07)    # r6: a square red collar, seated in the tiles
    b.box((cx - hx, y - hy, 16.95), (cx + hx, y + hy, zw0 - 0.10), P.WHITE, bevel=0.05)
    keep_faces(b, (1, 2, 3, 4, 5))
    b.box((cx - hx, y - hy, zw1 + 0.28), (cx + hx, y + hy, z1), P.WHITE, bevel=0.05)
    b.box((cx - hx + 0.45, y - hy + 0.45, zw0 - 0.14), (cx + hx - 0.45, y + hy - 0.45, zw1 + 0.32), P.WHITE, bevel=0.0)
    keep_faces(b, (2, 3, 4, 5))
    cw, ch = hx - W / 2 - 0.32, hy - W / 2 - 0.32
    for sx in (-1, 1):
        for sy in (-1, 1):
            xa, xd = sorted((cx + sx * hx, cx + sx * (hx - cw)))
            ya, yd = sorted((y + sy * hy, y + sy * (hy - ch)))
            b.box((xa, ya, zw0 - 0.14), (xd, yd, zw1 + 0.32), P.WHITE, bevel=0.0)
            keep_faces(b, (2, 3, 4, 5))
    window(b, cx, W, zw0, zw1, y - hy)
    turned(b, lambda t: window(t, 0.0, W, zw0, zw1, 0.0), s, cx + s * hx, y)
    zc = z1
    for d, t in ((0.45, 0.45), (-0.25, 0.50), (-1.05, 0.50)):
        b.box((cx - hx - d, y - hy - d, zc), (cx + hx + d, y + hy + d, zc + t), P.RED, bevel=0.07)
        zc += t
    b.cyl(cx, y, zc, zc + 0.30, 0.70, P.RED, 6, bottom=False)


def lv1_boat(b):
    """The rescue dinghy on its slip, the Lv1 hero: white hull, red stripe, chunky orange tube, navy console, two brick stands."""
    cy, D, K = BOAT_Y, BOAT_DZ, BOAT_K

    def body(t):
        for y in (cy - 2.6, cy + 3.2):
            for s in (-1, 1):
                t.box((s * 1.30 - 0.55, y - 0.80, 1.15), (s * 1.30 + 0.55, y + 0.80, 1.75 + D), P.LBG, bevel=0.05)
                t.box((s * 1.30 - 0.62, y - 0.87, 1.75 + D), (s * 1.30 + 0.62, y + 0.87, 2.10 + D), P.YELLOW, bevel=0.05)
        hull(t, 0.0, cy, BOAT_ST, (1.55 + D, 2.10 + D, 3.45 + D), P.WHITE)
        collar(t, 0.0, cy, BOAT_ST, 2.46 + D, 2.80 + D, P.RED, w=0.14)
        collar(t, 0.0, cy, BOAT_ST, 3.40 + D, 4.30 + D, P.ORANGE, bow=P.ORANGE, w=0.92)
        deck_spans(t, 0.0, cy, ((-3.80, -2.97, 1.10), (-2.97, -1.32, 1.55), (-1.32, 5.30, 1.85)), 3.46 + D, P.LBG)
        y = cy + 4.57
        t.box((-1.05, y - 0.85, 3.60 + D), (1.05, y + 0.85, 4.25 + D), P.ORANGE, bevel=0.06)
        t.box((-1.00, y - 0.80, 4.25 + D), (1.00, y + 0.80, 4.45 + D), P.WHITE, bevel=0.04)
        t.box((-0.68, cy + 5.50, 3.40 + D), (0.68, cy + 6.38, 5.00 + D), P.DBG, bevel=0.07)     # outboard
        t.box((-0.72, cy + 5.46, 4.10 + D), (0.72, cy + 6.42, 4.32 + D), P.YELLOW, bevel=0.03)
        t.box((-0.36, cy + 5.62, 2.00 + D), (0.36, cy + 6.26, 3.40 + D), P.BLACK, bevel=0.04)
        grid_studs(t, -0.9, 0.9, cy - 2.9, cy - 1.7, 3.58 + D, P.LBG, nx=2, ny=1, r=0.30, h=0.18)

    warped(b, body, lambda x, y, z: (K * x, cy + K * (y - cy), 1.15 + K * (z - 1.15)))
    # console round the code Console part (x +-1.035, y cy + 0.81..2.88, z 4.145..5.755: hidden in the hull and console);
    # not scaled up: the arch's lintel crops anything over ~8 from the path
    b.box((-1.40, cy + 0.72, 5.40), (1.40, cy + 3.40, CONSOLE_TOP), P.INK, bevel=0.06)
    b.box((-1.15, cy + 0.69, 6.10), (1.15, cy + 0.74, CONSOLE_TOP - 0.30), P.WHITE, bevel=0.0)
    b.beam((0.0, cy + 0.74, CONSOLE_TOP + 0.07), (0.0, cy + 1.36, CONSOLE_TOP + 0.75), 2.50, 0.12, P.GLASS)
    b.box((-1.45, cy + 0.68, CONSOLE_TOP), (1.45, cy + 1.62, CONSOLE_TOP + 0.13), P.WHITE, bevel=0.03)


def lv1_props(b):
    """One work table and the boat trailer: r5, the oars and fuel can gone from behind the hero."""
    # work table (code spot: x -8.05, y -2.88)
    x0, x1, y0, y1 = -11.03, -5.07, -4.72, -1.04
    for x in (x0 + 0.65, x1 - 0.65):
        b.box((x - 0.35, y0 + 0.45, PLINTH), (x + 0.35, y1 - 0.45, 2.82), P.STONE, bevel=0.04)
    b.box((x0, y0, 2.82), (x1, y1, 3.40), P.WHITE, bevel=0.07)
    b.studs(x0 + 0.2, x1 - 0.2, y0 + 0.2, y1 - 0.2, 3.40, P.WHITE, step=1.25, r=0.32, h=0.18, n=8)
    b.box((-9.70, -3.70, 3.40), (-7.30, -2.10, 4.70), P.RED, bevel=0.08)     # a big red tool chest
    b.box((-9.74, -3.75, 4.05), (-7.26, -2.05, 4.25), P.YELLOW, bevel=0.03)
    # the boat trailer (code spot: x 5.75, y 12.7; 1 stud forward for the back wall)
    cx, cy = 5.75, 11.70
    b.box((cx - 3.45 - 0.35, cy - 0.35, 2.05), (cx + 3.45 + 0.35, cy + 0.35, 2.55), P.DBG, bevel=0.03)
    for s in (-1, 1):
        b.cyl_x(cx + s * 3.45, cy, 2.30, 1.38, 1.05, P.BLACK, 16)
        b.cyl_x(cx + s * 3.45, cy, 2.30, 0.55, 1.15, P.LBG, 10)
        b.box((cx + s * 2.53 - 0.48, cy - 5.75, 2.55), (cx + s * 2.53 + 0.48, cy + 5.75, 3.25), P.YELLOW, bevel=0.06)
        b.studs(cx + s * 2.53 - 0.4, cx + s * 2.53 + 0.4, cy - 5.6, cy + 5.6, 3.25, P.YELLOW, step=2.6, r=0.32, h=0.18, n=8)
    for y in (cy - 4.0, cy + 4.0):
        b.box((cx - 2.10, y - 0.42, 2.60), (cx + 2.10, y + 0.42, 3.10), P.YELLOW, bevel=0.04)
    b.box((cx - 0.46, cy - 9.60, 2.20), (cx + 0.46, cy - 5.75, 2.80), P.DBG, bevel=0.04)
    b.cyl(cx, cy - 9.20, PLINTH, 2.20, 0.40, P.DBG, 8, bottom=False)


def side_wall(b, s):
    """A flank's side wall over the low fence (window + red piers), dropped with its flank when the bay opens. Built facing -Y
    in a temp, turned to face s * X."""
    t = lego.B()
    z0, z1 = WALL_TOP - 0.20, 11.70
    for a, d, cy in ((FW_Y1, -0.75, -8.82), (0.75, BW_Y0, 9.47)):
        h = (cy - 2.60, cy + 2.60, 5.20, 9.80)
        wall_holes(t, a, d, -0.30, 0.30, z0, z1, [h])
        window(t, cy, 5.20, 5.20, 9.80, -0.30)
        courses(t, -0.30, -1, a + 0.05, d - 0.05, z0 + 0.05, 10.60, n=5, holes=[(cy - 3.00, cy + 3.00, 4.40, 10.30)])
        t.box((a + 0.03, -0.44, 10.62), (d - 0.03, -0.20, 11.16), P.RED, bevel=0.05)       # r3: a red + white course under the eave
        t.box((a + 0.03, -0.54, 11.12), (d - 0.03, -0.20, 11.76), P.WHITE, bevel=0.05)
    # r5: the blank flank gets a rhythm: a pilaster each side of the windows, one life-ring plaque on the mid post
    for u in (-14.30, 15.30):
        brick_stack(t, u - 0.70, u + 0.70, -0.62, -0.25, WALL_TOP, 10.62, 5, P.RED, foot=False)
    fz = plaque(t, -2.20, 2.20, 5.40, 9.80, -0.62, P.WHITE, P.INK)
    ring_y(t, 0.0, fz - 0.30, 7.60, 1.45, 0.52)
    k = len(b.v)
    b.v.extend((s * (23.15 - y), x, z) for x, y, z in t.v)   # local -Y (the face) -> outward
    b.f.extend((tuple(i + k for i in f), c) for f, c in t.f)


def lv1_flank_r(b):
    """The right front wall (gives way to the Lv2 RIB bay): white bricks, two framed windows, a brick clear of the red piers."""
    a, d = FLANK_WX
    low_wall(b, GATE, WALL_X1, -19.55, -18.75)
    holes = [(a - 2.10, a + 2.10, 5.00, 9.60), (d - 2.10, d + 2.10, 5.00, 9.60)]
    wall_holes(b, PIER_X, CORNER_X, FW_Y0, FW_Y1, PLINTH, 11.70, holes)
    for x in (a, d):
        window(b, x, 4.20, 5.00, 9.60, FW_Y0)
    courses(b, FW_Y0, -1, PIER_X + 0.05, CORNER_X - 0.05, PLINTH + 0.05, 11.60, n=7,
            holes=[(a - 2.50, a + 2.50, 3.9, 10.1), (d - 2.50, d + 2.50, 3.9, 10.1)])
    side_wall(b, 1)
    dormer(b, 1, DORMER_X, DORMER_Y)                     # the pair's right half gives way to the Lv2 bay


DOOR_L = (-14.84, -10.84, 8.00)            # r5: the walk-in door beside the slip, 4 x 7, the inner left window's place
DOOR_GAP = (-15.35, -10.35)                # its gap in the low front wall


def lv1_flank_l(b):
    """The left front wall (gives way to the Lv3 lifeboat bay): one window and a framed blue walk-in door, ajar, on a step."""
    d = -FLANK_WX[1]
    x0, x1, zt = DOOR_L
    low_wall(b, -WALL_X1, DOOR_GAP[0], -19.55, -18.75)
    low_wall(b, DOOR_GAP[1], -GATE, -19.55, -18.75)
    holes = [(d - 2.10, d + 2.10, 5.00, 9.60), (x0, x1, PLINTH + 0.02, zt)]
    wall_holes(b, -CORNER_X, -PIER_X, FW_Y0, FW_Y1, PLINTH, 11.70, holes)
    window(b, d, 4.20, 5.00, 9.60, FW_Y0)
    courses(b, FW_Y0, -1, -CORNER_X + 0.05, -PIER_X - 0.05, PLINTH + 0.05, 11.60, n=7,
            holes=[(d - 2.50, d + 2.50, 3.9, 10.1), (DOOR_GAP[0], DOOR_GAP[1], PLINTH, zt + 0.70)])
    for a, c in ((x0 - 0.40, x0), (x1, x1 + 0.40)):
        b.box((a, FW_Y0 - 0.30, 0.99), (c, FW_Y1 + 0.04, zt + 0.50), P.YELLOW, bevel=0.05)
    b.box((x0, FW_Y0 - 0.30, zt), (x1, FW_Y1 + 0.04, zt + 0.50), P.YELLOW, bevel=0.05)
    zm = (1.03 + zt - 0.06) / 2
    hinge, tip = (x0 + 0.10, FW_Y1 + 0.05, zm), (x0 + 2.10, FW_Y1 + 3.50, zm)    # ajar inward: blue from the path, no collision
    b.beam(hinge, tip, 0.30, zt - 1.09, P.BLUE)
    p, q = (x0 + 0.60, FW_Y1 + 0.91, 5.70), (x0 + 1.60, FW_Y1 + 2.64, 5.70)
    b.beam(p, q, 0.38, 1.60, P.GLASS)
    b.box((x0 - 0.40, -19.62, 0.97), (x1 + 0.40, FW_Y0 - 0.30, 1.34), P.STONE, bevel=0.05)    # r6: a 2-stud step
    keep_faces(b, (1, 2, 3, 4, 5))
    b.stud_row(x0 + 0.40, -19.20, x1 - 0.40, -19.20, 1.34, P.STONE, spacing=1.05, r=0.30, h=0.16, n=6)
    # r6: a small white-red awning on the lintel, stepped back to the wall
    k = 5
    for i in range(k):
        a, d = x0 - 0.70 + i * (x1 - x0 + 1.40) / k + 0.02, x0 - 0.70 + (i + 1) * (x1 - x0 + 1.40) / k - 0.02
        b.box((a, -19.35, 8.46), (d, -17.90, 8.92), P.RED if i % 2 == 0 else P.WHITE, bevel=0.05)
    b.box((x0 - 0.50, -18.70, 8.90), (x1 + 0.50, -17.90, 9.32), P.RED, bevel=0.05)
    side_wall(b, -1)
    dormer(b, -1, DORMER_X, DORMER_Y)                    # the left half gives way to the Lv3 crane


def lv1_chair(b):
    """The tall lifeguard chair on its corner (gives way to the Lv3 tower)."""
    cx, cy = CHAIR
    b.box((cx - 1.95, cy - 1.95, PLINTH), (cx + 1.95, cy + 1.95, 1.84), P.YELLOW, bevel=0.06)
    b.studs(cx - 1.8, cx + 1.8, cy - 1.8, cy + 1.8, 1.84, P.YELLOW, step=1.25, r=0.32, h=0.18, n=8)
    brick_stack(b, cx - 0.70, cx + 0.70, cy - 0.70, cy + 0.70, 1.84, 7.40, 5, P.WHITE, foot=False)
    b.box((cx - 1.85, cy - 1.85, 7.40), (cx + 1.85, cy + 1.85, 8.00), P.YELLOW, bevel=0.06)
    b.box((cx - 1.85, cy + 1.25, 8.00), (cx + 1.85, cy + 1.85, 10.70), P.YELLOW, bevel=0.06)
    b.box((cx - 1.15, cy - 1.65, 4.50), (cx + 1.15, cy - 0.70, 4.95), P.WHITE, bevel=0.04)


def lv1_cols(c):
    """Lv1 collision: one plain box per object; the gate, portal and aisles stay open."""
    for s in (-1, 1):
        c.box((min(s * WALL_X0, s * WALL_X1), -18.75, PLINTH), (max(s * WALL_X0, s * WALL_X1), BW_Y0, WALL_TOP), P.WHITE, bevel=0)
        c.box((min(s * (GATE - 1.38), s * GATE), -19.56, PLINTH), (max(s * (GATE - 1.38), s * GATE), -18.60, 4.83), P.RED, bevel=0)
        c.box((min(s * (DOOR_X - 0.50), s * PIER_X), FW_Y0, PLINTH), (max(s * (DOOR_X - 0.50), s * PIER_X), FW_Y1, DOOR_Z), P.RED, bevel=0)
        c.box((min(s * CORNER_X, s * 23.60), FW_Y0, PLINTH), (max(s * CORNER_X, s * 23.60), FW_Y1, EAVE), P.RED, bevel=0)
        c.box((min(s * 22.45, s * 23.75), -0.75, WALL_TOP), (max(s * 22.45, s * 23.75), 0.75, EAVE), P.RED, bevel=0)
    c.box((-WALL_X1, BW_Y0, PLINTH), (WALL_X1, BW_Y1, EAVE), P.WHITE, bevel=0)              # back wall
    c.box((-PIER_X, FW_Y0, DOOR_Z), (PIER_X, FW_Y1, EAVE), P.RED, bevel=0)                  # portal header
    c.box((-HALL_HW, HALL_Y[0], PLINTH), (HALL_HW, HALL_Y[1], EAVE), P.WHITE, bevel=0)      # the slip hall's back wall
    c.box((-ROOF_HW, ROOF_Y0, EAVE), (ROOF_HW, ROOF_Y1, RIDGE), P.RED, bevel=0)             # roof
    K, ZT = BOAT_K, 1.15 + BOAT_K * (4.30 + BOAT_DZ - 1.15)
    c.box((-2.85 * K, BOAT_Y - 3.14 * K, 1.00), (2.85 * K, BOAT_Y + 5.75 * K, ZT), P.WHITE, bevel=0)   # dinghy
    c.box((-1.70 * K, -19.70, 1.00), (1.70 * K, BOAT_Y - 3.14 * K, ZT), P.WHITE, bevel=0)              # its bow, to the plinth's edge: the door aisles stay wide
    c.box((-1.40, BOAT_Y + 0.72, ZT), (1.40, BOAT_Y + 3.40, CONSOLE_TOP), P.INK, bevel=0)              # dinghy console
    c.box((-11.03, -4.72, PLINTH), (-5.07, -1.04, 3.40), P.WHITE, bevel=0)                   # table
    c.box((5.75 - 3.95, 11.70 - 5.75, PLINTH), (5.75 + 3.95, 11.70 + 5.75, 3.25), P.YELLOW, bevel=0)   # trailer


# ------------------------------------------------------------------ Lv2 / Lv3 silhouettes
def bay_header(b, s, z0=9.80, z1=11.70, y=FW_Y0):
    """The opened flank's header: an orange beam with a white lip, seams on it."""
    x0, x1 = sorted((s * (PIER_X + 0.15), s * CORNER_X))
    b.box((x0, y - 0.15, z0), (x1, FW_Y1 + 0.02, z1), P.ORANGE, bevel=0.06)
    b.box((x0 + 0.04, y - 0.25, z0), (x1 - 0.04, y + 0.10, z0 + 0.40), P.WHITE, bevel=0.04)
    courses(b, y - 0.15, -1, x0 + 0.1, x1 - 0.1, z0 + 0.40, z1 - 0.04, n=2, brick=3.0, c=P.RED)


def bay_curb(b, s):
    """The low front wall gives way to a walk-over curb when a bay opens: the boat shows from the path."""
    x0, x1 = sorted((s * GATE, s * WALL_X1))
    b.box((x0, -19.55, PLINTH), (x1, -18.75, 1.32), P.STONE, bevel=0.05)
    n = int((x1 - x0) / 2.6)
    for i in range(n):
        u0, u1 = x0 + i * (x1 - x0) / n + 0.04, x0 + (i + 1) * (x1 - x0) / n - 0.04
        b.box((u0, -19.60, 1.32), (u1, -18.70, 1.72), P.YELLOW, bevel=0.05)     # r4: the raised yellow lip, low enough to show the water from the path
        b.cyl((u0 + u1) / 2, -19.15, 1.72, 1.94, 0.42, P.YELLOW, 8, bottom=False)


def lv2_bay(b):
    """The Lv2 side bay, its own mass from above: a raised orange gable projecting past the front wall on a tall beam with an
    orange/white/blue trim, its own stepped red roof with an orange eave, a white band and ridge, a RIB plaque on blue."""
    cx, hw, n, rise, base = BAY_CX, BAY_HW, BAY_N, BAY_RISE, BAY_BASE
    y0, y1 = -20.70, 6.20
    wy = -20.30                                 # r3: the gable's face, 2.6 proud of the front wall
    bay_curb(b, 1)
    b.box((PIER_X + 0.15, wy + 0.12, 12.20), (CORNER_X, FW_Y1 + 0.02, 13.30), P.ORANGE, bevel=0.0)   # the beam behind the drum
    b.box((PIER_X + 0.15, wy - 0.10, 13.30), (23.70, FW_Y1 + 0.02, base), P.BLUE, bevel=0.05)    # the blue trim band
    b.box((CORNER_X, wy + 0.05, 12.20), (23.70, FW_Y1 + 0.02, 13.30), P.ORANGE, bevel=0.06)       # the beam's outer end
    # r3: the blue/white header drum, 1 brick tall, the roller door half up under it, red brick corbels carrying the beam (r4: 1 up)
    x0, x1, k = PIER_X + 0.15, 23.70, 10
    for i in range(k):
        xa = x0 + i * (x1 - x0) / k
        b.box((xa + 0.02, wy - 0.14, 12.14), (xa + (x1 - x0) / k - 0.02, wy + 0.12, 13.34), P.WHITE if i % 2 else P.BLUE, bevel=0.05)
    for a, d in ((PIER_X + 0.15, PIER_X + 1.25), (22.60, 23.70)):
        b.box((a, wy + 0.10, 11.10), (d, FW_Y0, 12.24), P.RED, bevel=0.05)
        b.box((a, wy + 1.20, 10.00), (d, FW_Y0, 11.14), P.RED, bevel=0.05)
    dx0, dx1 = PIER_X + 1.29, 22.56
    for za, zd, c in ((9.80, 10.20, P.BLUE), (10.20, 11.20, P.WHITE), (11.24, 12.20, P.WHITE)):
        b.box((dx0, wy + 0.20, za), (dx1, wy + 0.50, zd), c, bevel=0.04)
    eave_row(b, 1, cx + hw, y0 - 0.10, y1 + 0.10, base - 0.35, base + 0.75, base + rise, 1.50, 0.50)
    b.box((cx - hw + 0.10, y0 + 0.05, 13.30), (cx + hw - 0.05, y1 - 0.05, base + 0.05), P.ORANGE, bevel=0.0)  # closes the gap on the main roof
    stepped_roof(b, cx, hw, n, base, rise, y0, y1, 3.20, r=0.50, h=0.34, spacing=2.40, seam=5.20, bands={0: P.WHITE}, cap=P.BLUE, cap_stud=P.BLUE, eave=(1,), edge=P.WHITE, edge_t=rise)
    # r6: under the white stepped edge tiles one red stair-step chevron, a white field inside it, a thin orange trim by the plaque
    dx = hw / n
    for j in range(n - 1):
        v = hw - (j + 1) * dx                   # the half-width the edge tile above leaves showing
        za, zd = base - 0.12 + j * rise, base - 0.12 + (j + 1) * rise
        cells = ((v, v - dx, P.RED), (v - dx, 3.86, P.ORANGE)) if j == 0 else ((v, max(v - dx, 0.0), P.RED),)
        for a, d, c in cells:
            for s in (-1, 1):
                x0, x1 = sorted((cx + s * a, cx + s * d))
                b.box((x0, wy, za), (x1, wy + 0.10, zd), c, bevel=0.03)
        inner = 3.86 if j == 0 else v - dx
        if inner > 0.0:
            b.box((cx - inner, wy, za), (cx + inner, wy + 0.10, zd), P.WHITE, bevel=0.03)
    # the outer half tile, hidden behind the edge tiles: no gap at the rake
    for j in range(n):
        h, v = hw - (j + 0.5) * dx, hw - (j + 1) * dx
        for s in (-1, 1):
            x0, x1 = sorted((cx + s * v, cx + s * h))
            b.box((x0, wy + 0.02, base - 0.12 + j * rise), (x1, wy + 0.12, base - 0.12 + (j + 1) * rise), P.WHITE, bevel=0.0)
    gable_rows(b, cx, hw, n, base, rise, 5.40, 5.50, P.WHITE)
    # r6: a red/white stripe on the blue ridge cap: along both sides and across its front end
    top = base + n * rise
    for s in (-1, 1):
        x0, x1 = sorted((cx + s * 1.25, cx + s * 2.06))
        b.box((x0, y0 - 0.07, top + 0.78), (x1, y1 + 0.07, top + 0.90), P.WHITE, bevel=0.0)
        keep_faces(b, (1, 2, 3, 4, 5))
        x0, x1 = sorted((cx + s * 2.06, cx + s * 2.15))
        b.box((x0, y0 - 0.07, top + 0.22), (x1, y1 + 0.07, top + 0.56), P.RED, bevel=0.0)
    b.box((cx - 2.15, y0 - 0.17, top + 0.22), (cx + 2.15, y0 - 0.07, top + 0.56), P.RED, bevel=0.0)
    b.box((cx - 2.06, y0 - 0.17, top + 0.56), (cx + 2.06, y0 - 0.07, top + 0.90), P.WHITE, bevel=0.0)
    # r5: a stepped studded lintel over the opening: a white ledge, studs on it, a blue step above
    b.box((PIER_X + 0.15, wy - 0.72, 13.30), (23.70, wy + 0.02, 13.92), P.WHITE, bevel=0.06)
    b.stud_row(PIER_X + 0.8, wy - 0.46, 23.05, wy - 0.46, 13.92, P.WHITE, spacing=1.8, r=0.24, h=0.16, n=6)
    b.box((PIER_X + 0.95, wy - 0.22, 13.90), (22.90, wy + 0.02, 14.42), P.BLUE, bevel=0.05)
    fz = plaque(b, cx - 3.44, cx + 3.44, 14.90, 20.40, wy, P.RED, P.BLUE)       # r5: +25%; r6: a red brick frame on the white gable
    fy0, fy1 = fz - 0.18, fz + 0.04                                               # r6: the boat in relief
    K = 1.25
    bx = lambda u: cx + K * u
    bz = lambda z: 17.65 + K * (z - 15.875)
    prism_y(b, fy0, fy1, [(bx(-2.30), bz(15.75)), (bx(2.40), bz(15.75)), (bx(2.20), bz(14.30)), (bx(-1.10), bz(14.30))], P.ORANGE)
    b.box((bx(-2.45), fy0 - 0.04, bz(15.75)), (bx(2.55), fy1, bz(16.20)), P.WHITE, bevel=0.0)
    keep_faces(b, (2, 1, 0, 3, 5))
    b.box((bx(0.20), fy0, bz(16.20)), (bx(1.40), fy1, bz(17.45)), P.WHITE, bevel=0.0)
    keep_faces(b, (2, 1, 3, 5))


def shaft_part(b, x0, x1, y0, y1, zb, zt, cols):
    """One step of the tower's shaft: bold bands (one colour each), 3 bricks tall, mid-grey seams, no checks."""
    b.box((x0 + 0.15, y0 + 0.15, zb), (x1 - 0.15, y1 - 0.15, zt), P.STONE, bevel=0.0)
    keep_faces(b, (2, 3, 4, 5))
    h = (zt - zb) / (3 * len(cols))
    for i in range(3 * len(cols)):
        b.box((x0, y0, zb + i * h + 0.05), (x1, y1, zb + (i + 1) * h - 0.05), cols[i // 3], bevel=0.07)


def lv3_tower(b):
    """The Lv3 watch tower on the front-left corner: a grey stepped plinth, 4 bold red/white bands, a door, 2 big framed windows
    per seen face, a corbel collar, a railed gallery, a mullioned lantern, a 2-step studded roof, a blue-white light bar: the
    building's tallest peak. A low wall with a yellow rail closes the bay beside it, the yellow lift crane's mast is its jamb."""
    x0, x1, y0, y1 = TWR
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    bay_header(b, -1)
    # the bay's low wall: the hull shows over it, the rail 1 brick lower
    zs = (PLINTH, 1.70, 2.50)
    a, d = x1 + 0.20, -GATE
    for k, c in enumerate((P.STONE, P.WHITE)):
        cuts = [a + (d - a) * i / 3 for i in range(4)]
        for u0, u1 in zip(cuts, cuts[1:]):
            b.box((u0 + 0.02, -19.55, zs[k]), (u1 - 0.02, -18.75, zs[k + 1]), c, bevel=0.06)
            keep_faces(b, (1, 2, 3, 4, 5))
    n = 3
    for i in range(n):
        u0, u1 = a + i * (d - a) / n + 0.04, a + (i + 1) * (d - a) / n - 0.04
        b.box((u0, -19.63, 2.50), (u1, -18.67, 2.76), P.RED, bevel=0.04)
        b.cyl((u0 + u1) / 2, -19.15, 2.76, 2.98, 0.34, P.RED, 6, bottom=False)
    for x in (BAY_JAMB[1], -11.60, -8.40):
        b.box((x - 0.20, -19.35, 2.76), (x + 0.20, -18.95, 4.72), P.YELLOW, bevel=0.04)
    b.box((BAY_JAMB[1] - 0.25, -19.40, 4.40), (-8.10, -18.90, 4.76), P.YELLOW, bevel=0.05)
    # plinth
    for d_, za, zd in ((0.40, PLINTH, 1.50), (0.18, 1.50, 2.10)):
        b.box((x0 - d_, y0 - d_, za), (x1 + d_, y1 + min(d_, 0.10), zd), P.STONE, bevel=0.07)
        keep_faces(b, (1, 2, 3, 4, 5))
    # shaft: red + white bands, a grey ledge, red + white bands
    zb, zl, zu, zt = 2.10, 12.90, 13.50, 23.00
    dw = (cx - 1.50, cx + 1.50)                # the door
    wl, wu = (8.50, 11.80), (18.85, 21.85)     # the windows, in the white bands
    shaft_part(b, x0, x1, y0, y1, zb, zl, (P.RED, P.WHITE))
    ux0, ux1, uy0, uy1 = x0 + TWR_STEP, x1 - TWR_STEP, y0 + TWR_STEP, y1 - TWR_STEP
    b.box((x0 - 0.12, y0 - 0.12, zl - 0.04), (x1 + 0.12, y1 + 0.12, zu + 0.04), P.STONE, bevel=0.20)
    keep_faces(b, (1, 2, 3, 4, 5))
    shaft_part(b, ux0, ux1, uy0, uy1, zu, zt, (P.RED, P.WHITE))
    # the door: a yellow frame, a blue panel with a window slot
    fo, fi = y0 - 0.32, y0 + 0.02
    for a, d in ((dw[0] - 0.36, dw[0]), (dw[1], dw[1] + 0.36)):
        b.box((a, fo, zb - 0.02), (d, fi, 6.62), P.YELLOW, bevel=0.04)
    b.box((dw[0] - 0.36, fo, 6.20), (dw[1] + 0.36, fi, 6.66), P.YELLOW, bevel=0.05)
    b.box((dw[0], y0 - 0.12, zb - 0.02), (dw[1], fi, 6.22), P.BLUE, bevel=0.0)
    b.box((cx - 0.85, y0 - 0.16, 4.40), (cx + 0.85, y0 - 0.10, 5.70), P.GLASS, bevel=0.0)
    b.box((dw[1] - 0.46, y0 - 0.20, 3.50), (dw[1] - 0.14, y0 - 0.10, 3.82), P.YELLOW, bevel=0.0)
    # 2 big framed windows on the seen faces
    proud_window(b, cx, 3.60, wl[0], wl[1], y0)
    proud_window(b, cx, 3.40, wu[0], wu[1], uy0)
    turned(b, lambda t: proud_window(t, cy, 3.60, wl[0], wl[1], 0.0), 1, x1)
    turned(b, lambda t: proud_window(t, cy, 3.40, wu[0], wu[1], 0.0), 1, ux1)
    # r5: a 2-stud red/white top band under the collar, one course; r6: a 2-brick stage of them between the two windows
    def band(za, zd, proud, flip=0):
        for a0, a1, fixed, axis_x in ((ux0, ux1, uy0, True), (uy0, uy1, ux1, False), (ux0, ux1, uy1, True), (uy0, uy1, ux0, False)):
            k = 3
            for i in range(k):
                ua, ud = a0 + i * (a1 - a0) / k + 0.02, a0 + (i + 1) * (a1 - a0) / k - 0.02
                ca, cd = sorted((fixed - proud, fixed + 0.04)) if fixed in (uy0, ux0) else sorted((fixed + proud, fixed - 0.04))
                lo, hi = ((ua, ca, za), (ud, cd, zd)) if axis_x else ((ca, ua, za), (cd, ud, zd))
                b.box(lo, hi, P.RED if (i + flip) % 2 else P.WHITE, bevel=0.04)

    band(22.20, 23.00, 0.14)
    band(14.70, 15.85, 0.28)
    band(15.89, 17.04, 0.28, 1)
    # r5: a 1-stud grey seam where the tower meets the shed's roof, stepped with the treads (back and bay sides)
    b.box((x1 - 0.05, -18.65, 15.12), (x1 + 1.05, y1 + 1.00, 15.68), P.STONE, bevel=0.05)
    for xa, xd, tz in ((x0, -21.00, 13.425), (-21.00, -18.00, 14.30), (-18.00, x1 - 0.05, 15.175)):
        b.box((xa, y1 - 0.05, tz - 0.05), (xd, y1 + 1.00, tz + 0.50), P.STONE, bevel=0.05)
    # corbel collar, stepping out to the gallery
    hux, huy = (ux1 - ux0) / 2, (uy1 - uy0) / 2
    z = zt
    for d_, c in ((0.45, P.WHITE), (1.05, P.RED), (1.65, P.WHITE)):
        b.box((cx - hux - d_, cy - huy - d_, z - 0.02), (cx + hux + d_, cy + huy + d_, z + 0.50), c, bevel=0.07)
        z += 0.50
    # the railed gallery: 20% wider, fewer and thicker posts
    hx, hy = 4.90, 4.12                        # r5: +10%
    gx, gy = hx + 0.90, hy + 0.90
    b.box((cx - gx, cy - gy, z - 0.02), (cx + gx, cy + gy, z + 0.42), P.RED, bevel=0.07)
    z += 0.42
    r0, r1 = z, z + 1.35
    for i in range(4):
        xp = cx - gx + 0.30 + i * (2 * gx - 0.60) / 3
        for yp in (cy - gy + 0.30, cy + gy - 0.30):
            b.box((xp - 0.18, yp - 0.18, r0), (xp + 0.18, yp + 0.18, r1), P.YELLOW, bevel=0.0)
            keep_faces(b, (2, 3, 4, 5))
    for xp in (cx - gx + 0.30, cx + gx - 0.30):
        b.box((xp - 0.18, cy - 0.18, r0), (xp + 0.18, cy + 0.18, r1), P.YELLOW, bevel=0.0)
        keep_faces(b, (2, 3, 4, 5))
    for sy in (-1, 1):
        b.box((cx - gx + 0.05, cy + sy * (gy - 0.30) - 0.24, r1), (cx + gx - 0.05, cy + sy * (gy - 0.30) + 0.24, r1 + 0.32), P.YELLOW, bevel=0.04)
    for sx in (-1, 1):
        b.box((cx + sx * (gx - 0.30) - 0.24, cy - gy + 0.56, r1 + 0.01), (cx + sx * (gx - 0.30) + 0.24, cy + gy - 0.56, r1 + 0.30), P.YELLOW, bevel=0.04)
    # the lantern: 20% wider, corner posts, mullions
    z0, z1 = z, z + 5.06
    b.box((cx - hx + 0.30, cy - hy + 0.30, z0), (cx + hx - 0.30, cy + hy - 0.30, z1), P.GLASS, bevel=0.0)
    keep_faces(b, (2, 3, 4, 5))
    for sx in (-1, 1):
        for sy in (-1, 1):
            xa, xd = sorted((cx + sx * hx, cx + sx * (hx - 1.00)))
            ya, yd = sorted((cy + sy * hy, cy + sy * (hy - 1.00)))
            b.box((xa, ya, z0), (xd, yd, z1), P.WHITE, bevel=0.0)
            keep_faces(b, (2, 3, 4, 5))
    for x in (cx - 1.40, cx + 1.40):
        b.box((x - 0.20, cy - hy + 0.16, z0), (x + 0.20, cy - hy + 0.46, z1), P.WHITE, bevel=0.0)
        keep_faces(b, (2, 3, 4, 5))
    for y in (cy - 1.10, cy + 1.10):
        for sx in (-1, 1):
            xa, xd = sorted((cx + sx * (hx - 0.16), cx + sx * (hx - 0.46)))
            b.box((xa, y - 0.20, z0), (xd, y + 0.20, z1), P.WHITE, bevel=0.0)
            keep_faces(b, (2, 3, 4, 5))
    b.box((cx - hx - 0.08, cy - hy - 0.08, z0 + 0.02), (cx + hx + 0.08, cy + hy + 0.08, z0 + 0.42), P.RED, bevel=0.05)
    # the 2-step studded roof: 2 plates thick, a 1-stud overhang
    zc = z1
    for k, (d_, t) in enumerate(((1.00, 0.90), (-0.40, 0.90))):
        b.box((cx - hx - d_, cy - hy - d_, zc), (cx + hx + d_, cy + hy + d_, zc + t), P.ORANGE, bevel=0.10)
        zc += t
        inset = 0.65
        if k == 0:                              # r6: studded white edge tiles round the crown
            gx_, gy_ = hx + d_ - 0.06, hy + d_ - 0.06
            for sy in (-1, 1):
                n_ = 5
                for i in range(n_):
                    a = cx - gx_ + i * 2 * gx_ / n_
                    y_a, y_d = sorted((cy + sy * gy_, cy + sy * (gy_ - 1.00)))
                    b.box((a + 0.03, y_a, zc - 0.05), (a + 2 * gx_ / n_ - 0.03, y_d, zc + 0.26), P.WHITE, bevel=0.05)
                    b.cyl(a + gx_ / n_, (y_a + y_d) / 2, zc + 0.26, zc + 0.48, 0.36, P.WHITE, 6, bottom=False)
            for sx in (-1, 1):
                n_ = 3
                y_0, y_1 = cy - gy_ + 1.00, cy + gy_ - 1.00
                for i in range(n_):
                    a = y_0 + i * (y_1 - y_0) / n_
                    x_a, x_d = sorted((cx + sx * gx_, cx + sx * (gx_ - 1.00)))
                    b.box((x_a, a + 0.03, zc - 0.05), (x_d, a + (y_1 - y_0) / n_ - 0.03, zc + 0.26), P.WHITE, bevel=0.05)
                    b.cyl((x_a + x_d) / 2, a + (y_1 - y_0) / n_ / 2, zc + 0.26, zc + 0.48, 0.36, P.WHITE, 6, bottom=False)
            continue
        yr = cy - hy - d_ + inset
        b.stud_row(cx - hx - d_ + inset, yr, cx + hx + d_ - inset, yr, zc, P.ORANGE, spacing=2.2, r=0.44, h=0.24, n=8)
        for xr in (cx - hx - d_ + inset, cx + hx + d_ - inset):
            b.stud_row(xr, cy - hy - d_ + inset + 2.2, xr, cy + hy + d_ - inset - 2.2, zc, P.ORANGE, spacing=2.2, r=0.44, h=0.24, n=8)
    b.box((cx - 3.00, cy - 0.85, zc), (cx + 3.00, cy + 0.85, zc + 0.50), P.STONE, bevel=0.05)
    for xx, w, col in ((-3.00, 2.00, P.BLUE), (-1.00, 2.00, P.WHITE), (1.00, 2.00, P.BLUE)):
        b.box((cx + xx, cy - 0.85, zc + 0.50), (cx + xx + w, cy + 0.85, zc + 1.50), col, bevel=0.08)
    # r5: the rescue flag behind the light bar, the top of the building
    py = cy + 1.60
    b.box((cx - 0.20, py - 0.20, zc), (cx + 0.20, py + 0.20, zc + 3.40), P.WHITE, bevel=0.03)
    b.cyl(cx, py, zc + 3.40, zc + 3.70, 0.34, P.YELLOW, 8, bottom=False)
    for za, zd, col in ((zc + 1.70, zc + 2.20, P.RED), (zc + 2.20, zc + 2.70, P.WHITE), (zc + 2.70, zc + 3.20, P.RED)):
        b.box((cx + 0.20, py - 0.09, za), (cx + 3.60, py + 0.09, zd), col, bevel=0.02)
    lift_crane(b)


CRANE_Z0, CRANE_TIP = 17.40, -5.20         # r5: the boom 1.5x long, 1.4 over the sign frame
CRANE_MAST_Y = (-19.65, -18.55)            # r5: the mast's back 0.85 clear of the facade


def lift_crane(b):
    """The yellow lift crane: a brick mast out of the tower, a long studded boom over the sign's corner, a strut, a red block and
    hook, a boat hanging over the low wall, its bow to the mast, stepped in bricks."""
    mx0, mx1 = BAY_JAMB
    z0, z1 = CRANE_Z0, CRANE_Z0 + 1.20
    ya, yd = -20.05, -18.85                    # the boom, just proud of the roof's front edge
    ym = (ya + yd) / 2
    X = -11.70                                 # the hook's line: the boat's stern stays clear of the portal pier
    brick_stack(b, mx0, mx1, CRANE_MAST_Y[0], CRANE_MAST_Y[1], PLINTH, z0 + 0.02, 10, P.YELLOW)
    b.box((-17.20, ya, z0), (CRANE_TIP, yd, z1), P.YELLOW, bevel=0.08)
    b.stud_row(-16.20, ym, CRANE_TIP - 0.60, ym, z1, P.YELLOW, spacing=2.2, r=0.42, h=0.24, n=8)
    b.beam((mx1 - 0.30, ym, 11.00), (X - 0.40, ym, z0 + 0.10), 0.90, 0.90, P.YELLOW)
    b.box((X - 0.90, ya + 0.10, z0 - 0.75), (X + 0.90, yd - 0.10, z0 + 0.02), P.RED, bevel=0.07)   # head block
    b.box((X - 0.15, ym - 0.15, 13.10), (X + 0.15, ym + 0.15, z0 - 0.73), P.DBG, bevel=0.0)        # fall
    b.box((X - 0.85, ym - 0.55, 12.10), (X + 0.85, ym + 0.55, 13.12), P.RED, bevel=0.07)           # hook block
    b.box((X - 0.24, ym - 0.24, 11.40), (X + 0.24, ym + 0.24, 12.12), P.RED, bevel=0.03)           # the red hook
    b.box((X - 0.80, ym - 0.24, 10.80), (X + 0.24, ym + 0.24, 11.42), P.RED, bevel=0.04)
    b.box((X - 0.80, ym - 0.24, 11.40), (X - 0.36, ym + 0.24, 11.80), P.RED, bevel=0.04)
    # r6: two clear slings, the kept dinghy's smooth hull lines in blue, a white rub rail, an orange cabin, 2 clear of the header
    for dx in (-1.95, 1.75):
        b.beam((X - 0.30, ym, 10.95), (X + dx, ym, 7.00), 0.40, 0.40, P.DBG)
    ST = [(y * 0.52, w * 0.56) for y, w in BOAT_ST]
    XC, Z = X - 0.40, (5.00, 5.60, 6.95)

    def body(t):
        hull(t, 0.0, 0.0, ST, Z, P.BLUE)
        collar(t, 0.0, 0.0, ST, 6.72, 7.08, P.WHITE, w=0.30)
        deck_spans(t, 0.0, 0.0, ((-1.40, 2.60, 0.95),), 6.90, P.WHITE)

    warped(b, body, lambda x, y, z: (XC + y, ym - x, z))                # bow (-y) to the mast (-X)
    b.box((X - 0.80, ym - 0.82, 6.98), (X + 1.00, ym + 0.82, 7.82), P.ORANGE, bevel=0.07)
    b.box((X - 0.52, ym - 0.88, 7.26), (X + 0.72, ym - 0.78, 7.66), P.GLASS, bevel=0.0)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    patch_lod_targets()
    mat = lego.material("MI_RescueBoathouse_Brick", ALB)
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

    def out_cols(node, c, prefix=None):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills decks
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (prefix or node, k + 1), box, node)

    # ================================================================ Lv1: the code boathouse as a mesh
    for name, fn in (("Lv1_L01_Floor", lv1_floor), ("Lv1_L02_Walls", lv1_walls), ("Lv1_L03_Boat", lv1_boat),
                     ("Lv1_L04_Roof", lv1_roof), ("Lv1_L05_Props", lv1_props),
                     ("Lv1_L07_FlankR", lv1_flank_r), ("Lv1_L08_FlankL", lv1_flank_l), ("Lv1_L09_Chair", lv1_chair)):
        b = lego.B()
        fn(b)
        out(name, b, "Lv1")
    c = lego.B()
    lv1_cols(c)
    out_cols("Lv1", c)
    for tag, s_ in (("Lv1_L07", 1), ("Lv1_L08", -1)):      # DockPieces drops these with their flank walls
        c = lego.B()
        if s_ > 0:
            c.box((s_ * PIER_X, FW_Y0, PLINTH), (s_ * CORNER_X, FW_Y1, 11.70), P.WHITE, bevel=0)
            c.box((s_ * GATE, -19.55, PLINTH), (s_ * WALL_X1, -18.75, WALL_TOP), P.WHITE, bevel=0)
        else:                                               # the walk-in door and its gap stay clear
            c.box((-CORNER_X, FW_Y0, PLINTH), (DOOR_L[0] - 0.40, FW_Y1, 11.70), P.WHITE, bevel=0)
            c.box((DOOR_L[1] + 0.40, FW_Y0, PLINTH), (-PIER_X, FW_Y1, 11.70), P.WHITE, bevel=0)
            c.box((DOOR_L[0] - 0.40, FW_Y0, DOOR_L[2]), (DOOR_L[1] + 0.40, FW_Y1, 11.70), P.WHITE, bevel=0)
            c.box((-WALL_X1, -19.55, PLINTH), (DOOR_GAP[0], -18.75, WALL_TOP), P.WHITE, bevel=0)
            c.box((DOOR_GAP[1], -19.55, PLINTH), (-GATE, -18.75, WALL_TOP), P.WHITE, bevel=0)
        c.box((s_ * 22.85, FW_Y1, WALL_TOP), (s_ * 23.45, BW_Y0, 11.70), P.WHITE, bevel=0)     # side wall
        out_cols("Lv1", c, tag)
    c = lego.B()
    c.box((CHAIR[0] - 1.95, CHAIR[1] - 1.95, PLINTH), (CHAIR[0] + 1.95, CHAIR[1] + 1.95, 1.84), P.YELLOW, bevel=0)
    c.box((CHAIR[0] - 0.70, CHAIR[1] - 0.70, 1.84), (CHAIR[0] + 0.70, CHAIR[1] + 0.70, 8.00), P.WHITE, bevel=0)
    out_cols("Lv1", c, "Lv1_L09")

    # ================================================================ Lv2: RIB pontoon, fuel pump, life jackets
    b = lego.B()
    lv2_slip(b)
    out("Lv2_L01_Pontoon", b, "Lv2")

    b = lego.B()
    lv2_fuel(b)
    out("Lv2_L02_FuelPump", b, "Lv2")

    b = lego.B()
    lv2_jackets(b)
    out("Lv2_L03_JacketRack", b, "Lv2")

    b = lego.B()
    rib(b)
    out("Lv2_L04_RIB", b, "Lv2")

    b = lego.B()
    k_, z_ = RIB_K, RIB_Z[0]
    rope(b, (RIB_CX + 0.72 * k_, RIB_CY - 4.70 * k_, z_ + k_ * (3.02 - z_)), (18.35, -12.60, 2.20), 0.20, P.BLACK, 3, 0.07)
    rope(b, (RIB_CX + 1.52 * k_, RIB_CY + 4.90 * k_, z_ + k_ * (3.04 - z_)), (18.35, -4.00, 2.20), 0.24, P.BLACK, 3, 0.07)
    out("Lv2_L05_Mooring", b, "Lv2")

    b = lego.B()
    lv2_bay(b)
    out("Lv2_L06_Bay", b, "Lv2")

    c = lego.B()
    c.box((D2[0], D2[2], PLINTH), (D2[1], D2[3], DECK), P.DBG, bevel=0)                  # pontoon deck
    c.box((18.40, 5.10, PLINTH), (22.50, 5.90, 1.40), P.DBG, bevel=0)                    # step up
    c.box((18.40, 5.90, PLINTH), (22.50, 6.70, 1.16), P.DBG, bevel=0)                    # step low
    c.box((B2[0], B2[2], PLINTH), (B2[1], B2[3], SLIP), P.DBG, bevel=0)                  # wet slip
    c.box((B2[0] - 0.50, B2[2] - 0.50, PLINTH), (B2[0], 4.30, DECK), P.DBG, bevel=0)              # rim west
    c.box((B2[1], B2[2], PLINTH), (22.70, D2[2], SLIP), P.DBG, bevel=0)                  # the wet mouth
    c.box((B2[0], B2[2] - 0.50, PLINTH), (22.70, B2[2], DECK), P.DBG, bevel=0)             # rim front
    c.box((B2[0], B2[3], PLINTH), (B2[1], 4.30, DECK), P.DBG, bevel=0)                   # rim back
    c.box((RIB_CX - 2.45 * RIB_K, RIB_CY - 5.80 * RIB_K, 1.10), (RIB_CX + 2.45 * RIB_K, RIB_CY + 6.10 * RIB_K, 5.10), P.DBG, bevel=0)
    c.box((FUEL[0], FUEL[1], DECK), (FUEL[0] + 2.50, FUEL[1] + 2.00, DECK + 5.60), P.DBG, bevel=0)  # fuel pump
    c.box((22.00, RACK_Y[0], DECK), (23.00, RACK_Y[1], 6.40), P.DBG, bevel=0)            # jacket rack
    c.box((PIER_X, FW_Y0, 12.20), (CORNER_X, FW_Y1, BAY_BASE), P.ORANGE, bevel=0)         # bay header
    out_cols("Lv2", c)

    # ================================================================ Lv3: covered lifeboat berth
    b = lego.B()
    lv3_berth(b)
    out("Lv3_L01_Berth", b, "Lv3")

    b = lego.B()
    lv3_tower(b)
    out("Lv3_L02_Tower", b, "Lv3")

    b = lego.B()
    lifeboat(b)
    out("Lv3_L03_Lifeboat", b, "Lv3")

    b = lego.B()
    lv3_fittings(b)
    out("Lv3_L04_Fittings", b, "Lv3")

    c = lego.B()
    c.box((D3[0], D3[2], PLINTH), (D3[1], D3[3], DECK), P.DBG, bevel=0)                 # walkway deck
    c.box((B3[0], 4.50, PLINTH), (D3[0], D3[3], DECK), P.DBG, bevel=0)                  # back deck
    c.box((B3[0], B3[2], PLINTH), (B3[1], B3[3], SLIP), P.DBG, bevel=0)                  # wet slip
    c.box((-21.50, -13.10, PLINTH), (B3[0], 4.50, DECK), P.DBG, bevel=0)                 # rim west
    c.box((B3[0], -13.10, PLINTH), (B3[1], B3[2], DECK), P.DBG, bevel=0)                 # rim front
    c.box((B3[0], B3[3], PLINTH), (B3[1], 4.50, DECK), P.DBG, bevel=0)                   # rim back
    c.box((-10.90, 0.40, PLINTH), (-10.30, 4.80, 1.27), P.DBG, bevel=0)                # side step
    K = LB_K
    c.box((LB_CX - 2.65, LB_CY - 7.85 * K, 1.08), (LB_CX + 2.65, LB_CY + 7.85 * K, 3.50), P.DBG, bevel=0)  # hull
    c.box((LB_CX - 1.95, LB_CY + 0.40 * K, 3.50), (LB_CX + 1.95, LB_CY + 5.80 * K, 7.52), P.DBG, bevel=0)  # wheelhouse
    c.box((BENCH[0], BENCH[1], DECK), (BENCH[2], BENCH[3], DECK + 1.80), P.DBG, bevel=0)           # bench seat
    c.box((BENCH[2] - 0.32, BENCH[1], DECK + 1.80), (BENCH[2], BENCH[3], DECK + 3.40), P.DBG, bevel=0)  # bench back
    c.box((DVT_X - 0.80, DVT_Y - 0.80, DECK), (DVT_X + 0.80, DVT_Y + 0.80, 8.50), P.DBG, bevel=0)      # davit post
    c.box((TWR[0] - 0.40, TWR[2] - 0.40, PLINTH), (TWR[1] + 0.40, TWR[3] + 0.10, 2.10), P.DBG, bevel=0)  # watch tower base
    c.box((TWR[0], TWR[2], 2.10), (TWR[1], TWR[3], 23.70), P.DBG, bevel=0)               # watch tower
    c.box((TWR[1] + 0.20, -19.55, PLINTH), (-GATE, -18.75, 2.76), P.WHITE, bevel=0)      # the bay's low wall
    c.box((BAY_JAMB[0], CRANE_MAST_Y[0], PLINTH), (BAY_JAMB[1], CRANE_MAST_Y[1], CRANE_Z0), P.YELLOW, bevel=0)   # the crane mast
    c.box((-CORNER_X, FW_Y0, 9.80), (-PIER_X, FW_Y1, EAVE), P.ORANGE, bevel=0)           # bay header
    out_cols("Lv3", c)

    # ================================================================ attachments (feet on the code plinth)
    atts = []
    for name, loc in (("ATT_Work_Pontoon", (20.30, -4.20, DECK)),
                      ("ATT_Work_Fuel", (20.55, 2.65, DECK)),
                      ("ATT_Work_Berth", (-13.00, 2.40, DECK)),
                      ("ATT_Work_Davit", (DVT_X + 0.40, DVT_Y + 1.80, DECK))):
        atts.append(lego.attach(name, loc))

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
        "size_note": "the boathouse on the code plinth (z 0.92, 47.45 x 39.45 stud lot) with its level add-ons; "
                     "front -Y, origin the boathouse ground centre, built at its final 1.15 scale (no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_HQAddons / M_Bld_BoatYardAddons), no PBR scans",
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
            {"name": "rib", "target": [RIB_CX, RIB_CY, 3.0], "dist": 16, "az": -38, "el": 16},
            {"name": "jackets", "target": [22.3, -5.7, 4.2], "dist": 17, "az": -55, "el": 10},
            {"name": "pump", "target": [20.5, 3.9, 4.0], "dist": 14, "az": -40, "el": 14},
            {"name": "roof", "target": [12.0, -10.0, 16.0], "dist": 26, "az": -30, "el": 25},
            {"name": "lifeboat", "target": [LB_CX, LB_CY, 5.5], "dist": 38, "az": -30, "el": 16},
            {"name": "davit", "target": [DVT_X - 2.2, DVT_Y, 5.2], "dist": 19, "az": 35, "el": 18},
        ],
    }
