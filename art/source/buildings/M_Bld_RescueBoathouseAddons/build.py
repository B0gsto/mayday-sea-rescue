"""M_Bld_RescueBoathouseAddons: the Rescue Boathouse's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3).

The Lv1 boathouse stays the code-built `rescueBoathouse()` in src/shared/DockPieces.luau: an open pen with four
posts, the dinghy on its slip and the rescue clutter. This asset adds only what the two levels add, at the code
boathouse's final frame: 44 x 36 stud lot, ground at z 0, plinth top z 0.92 (the code plinth is 0.8 studs at 1x,
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
with a side step, bollards and cleats, and a solid red stepped shed roof with a studded ridge over the stern only;
bow, wheelhouse and mast stand open to the sky. The lifeboat (20 long, the RIB is 11.6) is orange with a navy
two-tier wheelhouse and a mast. A yellow davit on the far (east) quay edge swings a block and hook over the
foredeck; a crew bench with an orange/navy slat seat sits on the walkway. Front sign: a white life ring on navy in the gable opening.

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
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "RescueBoathouse", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_RescueBoathouse_Brick_ALB.png")
PLINTH, SLIP, DECK = 0.92, 1.30, 1.62     # code plinth top, water surface, pontoon deck top

# Lv2 RIB pontoon, right side of the pen (world studs, front -Y)
B2 = (12.40, 17.90, -12.40, 3.80)         # wet slip water x0, x1, y0, y1
RIB_CX, RIB_CY = 15.15, -4.30
RIB_ST = ((5.60, 2.15), (4.20, 2.15), (2.00, 2.12), (0.00, 2.08), (-2.00, 1.98),
          (-3.60, 1.72), (-4.60, 1.28), (-5.40, 0.72), (-5.80, 0.30), (-5.95, 0.12))
RIB_Z = (1.05, 1.75, 2.80)                # keel, chine, gunwale
D2 = (17.90, 23.00, -12.90, 5.10)         # deck x0, x1, y0, y1

# Lv3 lifeboat berth, left side of the pen (the boat is 20.0 long, 4.9 wide, wheelhouse to z 7.5, mast to z 12.4)
B3 = (-21.00, -14.80, -12.60, 11.00)
LB_CX, LB_CY = -17.90, -0.60
LB_K = 1.28                               # lifeboat() draws a 15.6 boat and stretches it along Y to 20.0
LB_ST = ((7.80, 2.38), (6.00, 2.46), (3.00, 2.46), (0.00, 2.40), (-3.00, 2.26),
         (-5.00, 1.98), (-6.40, 1.52), (-7.20, 0.95), (-7.80, 0.35))
LB_Z = (1.02, 1.80, 3.10)                 # keel, chine, gunwale
D3 = (-14.80, -10.90, -13.10, 12.60)      # walk-on deck x0, x1, y0, y1
ROOF_X0, ROOF_X1, RIDGE_X = -22.95, -10.65, -16.80   # shed roof over the stern: bow, deck, wheelhouse and mast open
ROOF_Y0, ROOF_Y1 = 7.60, 14.80            # code back posts start at y 16.0
EAVE_Z, RIDGE_Z = 7.20, 9.60
POST_Y = (ROOF_Y0 + 0.90, ROOF_Y1 - 0.90)
ROOF_N = 6                                # slope courses per side
DVT_X, DVT_Y = -14.00, -4.60            # davit on the far (east) quay edge, arm reaching west over the foredeck
BENCH = (-12.55, -12.40, -11.10, -6.40)   # crew bench on the walkway's east edge: x0, y0, x1, y1


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
    b.box((x0, y0, PLINTH), (x1, y1, SLIP), P.INK, bevel=0.03)
    rim(b, 11.90, -12.90, x0, 4.30, "+x")
    rim(b, x0, -12.90, x1, y0, "+y")
    rim(b, x0, y1, x1, 4.30, "-y")
    dx0, dx1, dy0, dy1 = D2
    b.box((dx0, dy0, PLINTH), (dx1, dy1, DECK - 0.18), P.DBG, bevel=0.05)
    b.box((dx0, dy0, DECK - 0.18), (dx1, dy1, DECK), P.TAN, bevel=0.06)
    planks(b, dx0 + 0.10, dx1 - 0.10, dy0 + 0.10, dy1 - 0.10, DECK)
    b.box((dx0 + 0.10, dy0 + 0.14, DECK), (dx0 + 0.26, dy1 - 0.14, DECK + 0.05), P.YELLOW, bevel=0.02)
    dashes(b, 20.30, -12.00, 2.20, DECK + 0.03)
    for y in (-11.20, -4.30, 4.20):
        bollard(b, 18.50, y, DECK)
    for y in (-8.60, 2.40):
        cleat(b, 18.35, y, DECK, 1.4)
    b.box((18.40, 6.70, PLINTH), (22.50, 5.90, 1.16), P.STONE, bevel=0.05)
    b.box((18.40, 5.90, PLINTH), (22.50, 5.10, 1.40), P.STONE, bevel=0.05)
    b.box((18.52, 6.60, 1.16), (22.38, 6.70, 1.21), P.YELLOW, bevel=0.01)
    b.box((18.52, 5.80, 1.40), (22.38, 5.90, 1.45), P.YELLOW, bevel=0.01)
    grid_studs(b, 18.90, 22.00, 6.06, 6.56, 1.16, P.LBG, nx=2, ny=1, r=0.30, h=0.18)
    grid_studs(b, 18.90, 22.00, 5.26, 5.76, 1.40, P.LBG, nx=2, ny=1, r=0.30, h=0.18)
    for rx, ry, w, l in ((13.20, -9.60, 0.16, 2.60), (16.70, 0.90, 0.14, 1.80), (14.10, 1.90, 0.16, 1.20)):
        b.box((rx - w / 2, ry - l / 2, SLIP), (rx + w / 2, ry + l / 2, SLIP + 0.02), P.BLUE, bevel=0.01)


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
    b.box((x0, y0, PLINTH), (x1, y1, SLIP), P.INK, bevel=0.03)
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
    b.box((-10.90, -4.60, PLINTH), (-10.30, -0.20, 1.27), P.STONE, bevel=0.05)
    b.box((-10.46, -4.50, 1.27), (-10.36, -0.30, 1.32), P.YELLOW, bevel=0.01)
    grid_studs(b, -10.82, -10.44, -3.90, -0.90, 1.27, P.LBG, nx=1, ny=2, r=0.24, h=0.14)
    for rx, ry, w, l in ((-19.90, -11.70, 0.16, 1.40), (-15.10, 3.00, 0.12, 1.60), (-18.40, 10.30, 0.16, 1.10)):
        b.box((rx - w / 2, ry - l / 2, SLIP), (rx + w / 2, ry + l / 2, SLIP + 0.02), P.BLUE, bevel=0.01)


def lv3_frame(b):
    """Stone posts and a shed roof over the stern: solid red stepped Lego slope courses and gables, studded ridge."""
    for x in (-22.20, -11.70):
        for y in POST_Y:
            b.box((x - 0.50, y - 0.50, PLINTH), (x + 0.50, y + 0.50, EAVE_Z), P.STONE, bevel=0.05)
            b.box((x - 0.66, y - 0.66, PLINTH), (x + 0.66, y + 0.66, 1.06), P.YELLOW, bevel=0.04)
            b.box((x - 0.60, y - 0.60, EAVE_Z - 0.22), (x + 0.60, y + 0.60, EAVE_Z), P.INK, bevel=0.04)
            s = -1 if x > RIDGE_X else 1
            b.beam((x, y, EAVE_Z - 1.40), (x + s * 1.15, y, EAVE_Z - 0.16), 0.30, 0.34, P.YELLOW)
    dx = (RIDGE_X - ROOF_X0) / ROOF_N
    rise = (RIDGE_Z - EAVE_Z) / ROOF_N
    for side in (0, 1):
        for i in range(ROOF_N):
            xa = ROOF_X0 + i * dx if side == 0 else ROOF_X1 - (i + 1) * dx
            zt = EAVE_Z + (i + 1) * rise
            b.box((xa - 0.01, ROOF_Y0, zt - 0.70), (xa + dx + 0.01, ROOF_Y1, zt), P.RED, bevel=0.05)
            # gable fill under the course, front and back
            for y in (ROOF_Y0 + 0.05, ROOF_Y1 - 0.45):
                b.box((xa, y, EAVE_Z - 0.30), (xa + dx, y + 0.40, zt - 0.50), P.RED, bevel=0.03)
    b.box((RIDGE_X - 0.55, ROOF_Y0 - 0.12, RIDGE_Z - 0.05), (RIDGE_X + 0.55, ROOF_Y1 + 0.12, RIDGE_Z + 0.36),
          P.RED, bevel=0.06)                                                                      # ridge cap
    grid_studs(b, RIDGE_X - 0.22, RIDGE_X + 0.22, ROOF_Y0 + 0.30, ROOF_Y1 - 0.30, RIDGE_Z + 0.36,
               P.RED, nx=1, ny=8, r=0.24, h=0.18)
    sy = ROOF_Y0 - 0.12
    b.box((RIDGE_X - 1.40, sy, EAVE_Z + 0.15), (RIDGE_X + 1.40, sy + 0.12, EAVE_Z + 1.45), P.INK, bevel=0.04)
    torus_y(b, RIDGE_X, sy - 0.04, EAVE_Z + 0.80, 0.38, 0.10, P.WHITE, 10, 4)
    for xx in (RIDGE_X - 0.38, RIDGE_X + 0.38):
        b.box((xx - 0.05, sy - 0.02, EAVE_Z + 0.70), (xx + 0.05, sy + 0.06, EAVE_Z + 0.90), P.RED)
    for y in (ROOF_Y0 + 0.25, ROOF_Y1 - 0.25):
        b.beam((ROOF_X0 - 0.05, y, EAVE_Z - 0.20), (ROOF_X1 + 0.05, y, EAVE_Z - 0.20), 0.30, 0.34, P.RRED)    # eave tie


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
    b.box((bx - 0.12, py - 0.09, bz - 2.00), (bx + 0.12, py + 0.09, bz - 0.20), P.BLACK)           # fall
    b.box((bx - 0.60, py - 0.42, 4.15), (bx + 0.60, py + 0.42, 4.90), P.YELLOW, bevel=0.05)        # hook block
    b.box((bx - 0.60, py - 0.42, 4.55), (bx + 0.60, py + 0.42, 4.75), P.RED, bevel=0.03)
    b.box((bx - 0.14, py - 0.14, 3.55), (bx + 0.14, py + 0.14, 4.15), P.DBG, bevel=0.02)           # hook shank
    b.box((bx - 0.56, py - 0.14, 3.30), (bx + 0.14, py + 0.14, 3.56), P.DBG, bevel=0.02)
    b.box((bx - 0.56, py - 0.14, 3.30), (bx - 0.30, py + 0.14, 3.95), P.DBG, bevel=0.02)
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


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_RescueBoathouse_Brick", ALB)
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
    rope(b, (RIB_CX + 0.72, RIB_CY - 4.70, 3.02), (18.35, -8.60, 2.20), 0.20, P.BLACK, 3, 0.07)
    rope(b, (RIB_CX + 1.52, RIB_CY + 4.90, 3.04), (18.35, 2.40, 2.20), 0.24, P.BLACK, 3, 0.07)
    out("Lv2_L05_Mooring", b, "Lv2")

    c = lego.B()
    c.box((D2[0], D2[2], PLINTH), (D2[1], D2[3], DECK), P.DBG, bevel=0)                  # pontoon deck
    c.box((18.40, 5.10, PLINTH), (22.50, 5.90, 1.40), P.DBG, bevel=0)                    # step up
    c.box((18.40, 5.90, PLINTH), (22.50, 6.70, 1.16), P.DBG, bevel=0)                    # step low
    c.box((B2[0], B2[2], PLINTH), (B2[1], B2[3], SLIP), P.DBG, bevel=0)                  # wet slip
    c.box((11.90, -12.90, PLINTH), (B2[0], 4.30, DECK), P.DBG, bevel=0)                  # rim west
    c.box((B2[0], -12.90, PLINTH), (B2[1], B2[2], DECK), P.DBG, bevel=0)                 # rim front
    c.box((B2[0], B2[3], PLINTH), (B2[1], 4.30, DECK), P.DBG, bevel=0)                   # rim back
    c.box((RIB_CX - 2.45, RIB_CY - 5.80, 1.10), (RIB_CX + 2.45, RIB_CY + 6.10, 4.30), P.DBG, bevel=0)
    c.box((FUEL[0], FUEL[1], DECK), (FUEL[0] + 2.50, FUEL[1] + 2.00, DECK + 5.60), P.DBG, bevel=0)  # fuel pump
    c.box((22.00, RACK_Y[0], DECK), (23.00, RACK_Y[1], 6.40), P.DBG, bevel=0)            # jacket rack
    out_cols("Lv2", c)

    # ================================================================ Lv3: covered lifeboat berth
    b = lego.B()
    lv3_berth(b)
    out("Lv3_L01_Berth", b, "Lv3")

    b = lego.B()
    lv3_frame(b)
    out("Lv3_L02_Frame", b, "Lv3")

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
    c.box((-10.90, -4.60, PLINTH), (-10.30, -0.20, 1.27), P.DBG, bevel=0)                # side step
    K = LB_K
    c.box((LB_CX - 2.65, LB_CY - 7.85 * K, 1.08), (LB_CX + 2.65, LB_CY + 7.85 * K, 3.50), P.DBG, bevel=0)  # hull
    c.box((LB_CX - 1.95, LB_CY + 0.40 * K, 3.50), (LB_CX + 1.95, LB_CY + 5.80 * K, 7.52), P.DBG, bevel=0)  # wheelhouse
    c.box((BENCH[0], BENCH[1], DECK), (BENCH[2], BENCH[3], DECK + 1.80), P.DBG, bevel=0)           # bench seat
    c.box((BENCH[2] - 0.32, BENCH[1], DECK + 1.80), (BENCH[2], BENCH[3], DECK + 3.40), P.DBG, bevel=0)  # bench back
    c.box((DVT_X - 0.80, DVT_Y - 0.80, DECK), (DVT_X + 0.80, DVT_Y + 0.80, 8.50), P.DBG, bevel=0)      # davit post
    c.box((ROOF_X0, ROOF_Y0, EAVE_Z), (ROOF_X1, ROOF_Y1, RIDGE_Z), P.DBG, bevel=0)       # roof overhead
    for x in (-22.20, -11.70):
        for y in POST_Y:
            c.box((x - 0.50, y - 0.50, PLINTH), (x + 0.50, y + 0.50, EAVE_Z), P.DBG, bevel=0)
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
        "size_note": "add-ons only, sitting on the code boathouse's plinth (z 0.92) inside its 44 x 36 stud lot; "
                     "the bbox is the right-hand RIB pontoon and the left-hand lifeboat berth, not the whole pen; "
                     "front -Y, origin the boathouse ground centre, built at its final 1.15 scale (no extra scale)",
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
            {"name": "rib", "target": [RIB_CX, RIB_CY, 3.0], "dist": 16, "az": -38, "el": 16},
            {"name": "jackets", "target": [22.3, -5.7, 4.2], "dist": 17, "az": -55, "el": 10},
            {"name": "pump", "target": [20.5, 3.9, 4.0], "dist": 14, "az": -40, "el": 14},
            {"name": "lifeboat", "target": [LB_CX, LB_CY, 5.5], "dist": 38, "az": -30, "el": 16},
            {"name": "davit", "target": [DVT_X - 2.2, DVT_Y, 5.2], "dist": 19, "az": 35, "el": 18},
        ],
    }
