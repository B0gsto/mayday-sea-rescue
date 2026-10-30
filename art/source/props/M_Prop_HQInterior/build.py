"""M_Prop_HQInterior: the HQ station's walk-in furniture, Lego style (round 2 of the int1 interiors; AD r1 6/10:
"a big empty white box with small props at the edges").

Built in the HQ spot's frame at 1x, like M_Bld_HQAddons: origin the station's ground centre, front (the door) -Y.
The code station (DockPieces.station) has inner wall faces at game x +-25.6, z +-14.6, floor top 0.75, ceiling 15;
its windows are solid bricks on the outside, so the inside gets framed panes here. Coordinates below are the GAME's
(x right, y up, z back; door at z -14.6); `G` converts (Blender = -x, z, y).

  Lv3_L01_Dispatch  sea-chart table mid-hall, the dispatch console (3 screens, radio, mic) facing the door, 2 chairs
  Lv3_L02_Walls     framed windows (14), the clock, pinboards, wall charts, potted plants
  Lv3_L03_Ceiling   timber beams and 7 pendant lamps (DockPieces puts a PointLight under each, PENDANTS)
  Lv4_L01_Lockers   two banks of 3 crew lockers (doors, vents, handles, name tags) with benches
  Lv4_L02_Coffee    the coffee counter (machine, carafe, mugs, kettle, shelf) and the fridge
  Lv4_L03_Sofa      sofa with cushions and arms, coffee table, rug
  Lv<l>_ColNN_COL   collision boxes (the visual meshes don't collide)

    python3 art/source/props/M_Prop_HQInterior/maketex.py --out build/prod/M_Prop_HQInterior/textures/M_Prop_HQInterior
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_HQInterior/build.py \
        --out-root build/prod/M_Prop_HQInterior --steps build,lod,validate,export,turntable
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G_ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Prop_HQInterior"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "HQInterior", "Brick"
ALB = os.path.join(G_ROOT, "build/prod", NAME, "textures", NAME, "T_HQInterior_Brick_ALB.png")

IW, ID, FLOOR, CEIL = 25.6, 14.6, 0.72, 15.0   # inner wall faces, floor (sunk 0.03: no coplanar bottoms), ceiling
WIN_Y = 7.0
WINDOWS = {"back": (-18, -9, 0, 9, 18), "front": (9, 15, 21), "left": (-8, 0, 8), "right": (-8, 0, 8)}
PENDANTS = ((0, -2), (-10, -3), (10, -3), (-10, 7), (10, 7), (-20, 2), (20, 2))   # (x, z), bulb y 10.75


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


class G:
    """lego.B in game coordinates."""

    def __init__(self):
        self.b = lego.B()

    def box(self, x0, x1, y0, y1, z0, z1, c, bevel=None):
        self.b.box((-max(x0, x1), min(z0, z1), min(y0, y1)), (-min(x0, x1), max(z0, z1), max(y0, y1)), c, bevel)

    def cyl(self, x, z, y0, y1, r, c, n=12):         # upright
        self.b.cyl(-x, z, y0, y1, r, c, n)

    def cyl_x(self, x, y, z, r, length, c, n=10):    # lying along game x
        self.b.cyl_x(-x, z, y, r, length, c, n)

    def cyl_z(self, x, y, z0, z1, r, c, n=12):       # lying along game z (wall clocks, dials)
        ring = [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        a = [(-x + u, z0, y + v) for u, v in ring]
        e = [(-x + u, z1, y + v) for u, v in ring]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        faces += [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
        self.b._emit(a + e, faces, c)

    def cone(self, x, z, y0, r0, y1, r1, c, n=12):   # upright frustum
        self.b.loft([[(-x + r * math.cos(2 * math.pi * i / n), z + r * math.sin(2 * math.pi * i / n), y)
                      for i in range(n)] for y, r in ((y0, r0), (y1, r1))], c)

    def beam(self, p0, p1, w, h, c):
        self.b.beam((-p0[0], p0[2], p0[1]), (-p1[0], p1[2], p1[1]), w, h, c)

    def studs(self, x0, x1, z0, z1, y, c, step=1.6, r=0.45):
        self.b.studs(-x1, -x0, z0, z1, y, c, step=step, r=r, h=0.3, n=8)

    def wall(self, side, u0, u1, y0, y1, d0, d1, c, bevel=0.06):
        """A box on a wall: u along it (game x on front/back, game z on left/right), d out from the face."""
        if side == "back":
            self.box(u0, u1, y0, y1, ID - d1, ID - d0, c, bevel)
        elif side == "front":
            self.box(u0, u1, y0, y1, -ID + d0, -ID + d1, c, bevel)
        elif side == "left":
            self.box(-IW + d0, -IW + d1, y0, y1, u0, u1, c, bevel)
        else:
            self.box(IW - d1, IW - d0, y0, y1, u0, u1, c, bevel)


# ------------------------------------------------------------------ Lv3
def dispatch(g):
    # sea-chart table mid-hall: navy rim, blue sea, the ring of island studs round the green hub, a red boat
    tx, tz = 0.0, -2.0
    g.cyl(tx, tz, FLOOR, 1.1, 2.0, P.DBG, 16)
    g.cyl(tx, tz, 1.1, 3.1, 0.8, P.DBG, 12)
    g.cyl(tx, tz, 3.1, 3.5, 3.6, P.INK, 20)
    g.cyl(tx, tz, 3.5, 3.56, 3.2, P.BLUE, 20)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        ix, iz = tx + 2.15 * math.cos(a), tz + 2.15 * math.sin(a)
        g.cyl(ix, iz, 3.52, 3.66, 0.6, P.TAN, 10)
        g.cyl(ix, iz, 3.6, 3.82, 0.4, P.GREEN, 8)
    g.cyl(tx, tz, 3.52, 3.7, 0.9, P.TAN, 12)
    g.cyl(tx, tz, 3.6, 4.1, 0.6, P.GREEN, 10)
    g.box(tx + 1.0, tx + 1.6, 3.52, 3.82, tz - 1.1, tz - 0.8, P.RED, 0.04)          # the call: a red boat
    g.box(tx - 3.0, tx - 2.2, 3.52, 3.6, tz - 0.4, tz + 0.6, P.WHITE, 0.02)         # a note on the rim
    # the console, facing the door: blue body, red stripe, white desk, a riser with three screens
    x0, x1, z0, z1 = -6.3, 6.3, 6.6, 9.2
    g.box(x0, x1, FLOOR, 3.2, z0, z1, P.BLUE, 0.1)
    g.box(x0 - 0.02, x1 + 0.02, 2.5, 2.85, z0 - 0.06, z0 + 0.2, P.RED, 0.03)
    for x in (-4.2, 0, 4.2):                                                          # cabinet doors + handles
        g.box(x - 1.7, x + 1.7, 0.95, 2.3, z0 - 0.06, z0 + 0.1, P.BLUE, 0.05)
        g.box(x - 0.5, x + 0.5, 2.0, 2.15, z0 - 0.14, z0, P.LBG, 0.02)
    g.box(-6.6, 6.6, 3.2, 3.55, 6.2, 9.4, P.WHITE, 0.1)
    g.box(-6.0, 6.0, 3.55, 4.4, 8.4, 9.2, P.DBG, 0.08)
    for k, x in enumerate((-4.0, 0.0, 4.0)):
        g.box(x - 1.7, x + 1.7, 4.4, 6.8, 8.3, 8.9, P.INK, 0.1)
        bg = (P.GLASS, P.INK, P.BLUE)[k]
        g.box(x - 1.45, x + 1.45, 4.6, 6.6, 8.22, 8.32, bg, 0.0)
        if k == 0:     # the chart screen: islands and the call
            for dx, dy, w in ((-0.7, 0.4, 0.7), (0.5, -0.3, 0.9), (0.6, 0.6, 0.4)):
                g.box(x + dx - w / 2, x + dx + w / 2, 5.6 + dy - 0.25, 5.6 + dy + 0.25, 8.17, 8.23, P.GREEN, 0)
            g.box(x - 0.15, x + 0.15, 5.05, 5.35, 8.15, 8.23, P.RED, 0)
        elif k == 1:   # radar: a cross, a sweep, blips
            g.box(x - 1.2, x + 1.2, 5.57, 5.63, 8.18, 8.23, P.GREEN, 0)
            g.box(x - 0.03, x + 0.03, 4.75, 6.45, 8.18, 8.23, P.GREEN, 0)
            g.beam((x, 5.6, 8.19), (x + 0.75, 6.25, 8.19), 0.1, 0.04, P.GREEN)
            for dx, dy in ((0.5, 0.3), (-0.6, -0.4), (0.8, -0.5)):
                g.box(x + dx - 0.1, x + dx + 0.1, 5.6 + dy - 0.1, 5.6 + dy + 0.1, 8.16, 8.23, P.YELLOW, 0)
        else:          # the call list: white rows, status squares
            for r in range(4):
                y = 6.2 - r * 0.42
                g.box(x - 1.15, x + 0.6, y - 0.12, y + 0.12, 8.17, 8.23, P.WHITE, 0)
                g.box(x + 0.8, x + 1.1, y - 0.12, y + 0.12, 8.17, 8.23, (P.RED, P.YELLOW, P.GREEN, P.GREEN)[r], 0)
    # the radio set (left), mic, keyboards, mug, alarm button
    g.box(-6.3, -4.0, 3.55, 4.75, 6.5, 7.8, P.STONE, 0.08)
    for x in (-5.7, -4.9):
        g.cyl_z(x, 4.25, 6.4, 6.52, 0.28, P.WHITE, 10)
    for i in range(3):
        g.box(-4.75, -4.15, 3.85 + i * 0.25, 3.95 + i * 0.25, 6.44, 6.52, P.INK, 0)
    g.box(-6.15, -5.75, 4.55, 4.65, 6.42, 6.5, P.RED, 0)
    g.beam((-6.0, 4.75, 7.5), (-6.0, 6.7, 7.5), 0.1, 0.1, P.BLACK)
    g.cyl(-2.8, 7.0, 3.55, 3.72, 0.35, P.DBG, 10)
    g.beam((-2.8, 3.72, 7.0), (-2.5, 4.6, 6.6), 0.12, 0.12, P.BLACK)
    g.box(-2.7, -2.3, 4.5, 4.9, 6.35, 6.75, P.INK, 0.05)
    for x0k in (-1.6, 2.6):
        g.box(x0k, x0k + 2.6, 3.55, 3.68, 6.5, 7.4, P.DBG, 0.03)
        for k in range(3):
            g.box(x0k + 0.15, x0k + 2.45, 3.66, 3.74, 6.62 + k * 0.25, 6.8 + k * 0.25, P.LBG, 0)
    g.cyl(5.8, 6.9, 3.55, 4.15, 0.32, P.RED, 10)
    g.box(6.1, 6.32, 3.7, 4.0, 6.82, 6.98, P.RED, 0.02)
    g.cyl(-0.9, 8.0, 3.55, 3.75, 0.45, P.YELLOW, 10)
    g.cyl(-0.9, 8.0, 3.75, 3.95, 0.3, P.RED, 10)
    # two operator chairs facing the screens (backs to the door)
    for cx in (-2.4, 2.4):
        cz = 4.3
        g.box(cx - 1.0, cx + 1.0, FLOOR, 0.95, cz - 0.15, cz + 0.15, P.DBG, 0.03)
        g.box(cx - 0.15, cx + 0.15, FLOOR, 0.95, cz - 1.0, cz + 1.0, P.DBG, 0.03)
        g.cyl(cx, cz, 0.95, 1.9, 0.2, P.DBG, 8)
        g.box(cx - 1.0, cx + 1.0, 1.9, 2.35, cz - 0.9, cz + 0.9, P.RED, 0.12)
        g.box(cx - 1.0, cx + 1.0, 2.2, 4.3, cz - 1.05, cz - 0.7, P.RED, 0.12)


def window_in(g, side, u):
    """The inside of a window: blue pane, white frame + cross bar, a sill."""
    y0, y1 = WIN_Y - 2.7, WIN_Y + 2.7
    g.wall(side, u - 1.7, u + 1.7, y0 + 0.5, y1 - 0.5, -0.05, 0.12, P.GLASS, 0)
    g.wall(side, u - 2.2, u + 2.2, y1 - 0.6, y1, -0.05, 0.32, P.WHITE)
    g.wall(side, u - 2.2, u + 2.2, y0, y0 + 0.6, -0.05, 0.32, P.WHITE)
    for s in (-1, 1):
        g.wall(side, u + s * 1.9 - 0.3, u + s * 1.9 + 0.3, y0 + 0.5, y1 - 0.5, -0.05, 0.32, P.WHITE)
    g.wall(side, u - 0.12, u + 0.12, y0 + 0.5, y1 - 0.5, 0.05, 0.22, P.WHITE, 0.02)
    g.wall(side, u - 1.7, u + 1.7, WIN_Y + 0.45, WIN_Y + 0.69, 0.05, 0.22, P.WHITE, 0.02)
    g.wall(side, u - 2.6, u + 2.6, y0 - 0.35, y0 + 0.05, -0.05, 0.8, P.WHITE, 0.08)


def pinboard(g, side, u, y0):
    g.wall(side, u - 1.7, u + 1.7, y0, y0 + 3.4, -0.05, 0.22, P.BROWN, 0.06)
    g.wall(side, u - 1.45, u + 1.45, y0 + 0.25, y0 + 3.15, -0.05, 0.28, P.DTAN, 0)
    for du, dy, w, h, c in ((-0.8, 2.3, 1.0, 0.8, P.WHITE), (0.5, 2.4, 1.1, 0.7, P.YELLOW),
                            (-0.6, 1.0, 1.2, 0.9, P.GLASS), (0.7, 1.1, 0.9, 1.1, P.WHITE)):
        g.wall(side, u + du - w / 2, u + du + w / 2, y0 + dy - h / 2, y0 + dy + h / 2, 0.2, 0.33, c, 0)
        g.wall(side, u + du - 0.09, u + du + 0.09, y0 + dy + h / 2 - 0.25, y0 + dy + h / 2 - 0.07, 0.3, 0.42,
               P.RED, 0)


def walls(g):
    for side, us in WINDOWS.items():
        for u in us:
            window_in(g, side, u)
    # the clock over the back middle window: red rim, white face, hour ticks, hands at ten past ten
    cx, cy = 0.0, 12.0
    g.cyl_z(cx, cy, ID - 0.32, ID + 0.05, 1.45, P.RED, 20)
    g.cyl_z(cx, cy, ID - 0.4, ID - 0.3, 1.2, P.WHITE, 20)
    for k in range(12):
        a = math.radians(30 * k)
        L = 0.28 if k % 3 == 0 else 0.14
        p0 = (cx + (1.02 - L) * math.sin(a), cy + (1.02 - L) * math.cos(a), ID - 0.43)
        p1 = (cx + 1.02 * math.sin(a), cy + 1.02 * math.cos(a), ID - 0.43)
        g.beam(p0, p1, 0.09, 0.05, P.INK)
    g.beam((cx, cy, ID - 0.46), (cx - 0.55, cy + 0.3, ID - 0.46), 0.12, 0.05, P.INK)
    g.beam((cx, cy, ID - 0.5), (cx + 0.5, cy + 0.75, ID - 0.5), 0.08, 0.05, P.INK)
    g.cyl_z(cx, cy, ID - 0.54, ID - 0.4, 0.12, P.RED, 8)
    # pinboards between the side windows (over the Lv5 gear racks and the Lv4 fridge / sofa)
    for side in ("left", "right"):
        for u in (-4, 4):
            pinboard(g, side, u, 7.6)
    # framed sea charts behind the console, between the back windows
    for u in (-4.5, 4.5):
        g.wall("back", u - 1.9, u + 1.9, 8.2, 11.6, -0.05, 0.22, P.WHITE, 0.06)
        g.wall("back", u - 1.6, u + 1.6, 8.5, 11.3, -0.05, 0.28, P.GLASS, 0)
        for du, dy, w in ((-0.7, 0.6, 0.9), (0.6, -0.4, 1.1), (0.9, 0.9, 0.5), (-0.9, -0.8, 0.6)):
            g.wall("back", u + du - w / 2, u + du + w / 2, 9.9 + dy - w / 3, 9.9 + dy + w / 3, 0.25, 0.33,
                   P.GREEN, 0)
        for k in range(4):
            g.wall("back", u - 1.2 + k * 0.55, u - 0.95 + k * 0.55, 9.6 + k * 0.12, 9.72 + k * 0.12, 0.25, 0.34,
                   P.RED, 0)
    # potted plants in the back corners
    for x in (-23.6, 23.6):
        z = 12.6
        g.cyl(x, z, FLOOR, 2.4, 1.1, P.RED, 12)
        g.cyl(x, z, 2.3, 2.55, 1.25, P.RED, 12)
        g.cyl(x, z, 2.4, 2.6, 0.95, P.BROWN, 12)
        for y0, y1, r in ((2.55, 3.8, 1.7), (3.7, 4.9, 1.3), (4.8, 5.8, 0.8)):
            g.cyl(x, z, y0, y1, r, P.GREEN, 8)
        g.cyl(x, z, 5.7, 6.1, 0.35, P.GREEN, 8)


def ceiling(g):
    for x in (-20, -10, 0, 10, 20):
        g.box(x - 0.45, x + 0.45, 14.25, CEIL + 0.05, -ID - 0.05, ID + 0.05, P.BROWN, 0.06)
    for z in (-8, 8):
        g.box(-IW - 0.05, IW + 0.05, 14.5, CEIL + 0.05, z - 0.35, z + 0.35, P.BROWN, 0.05)
    for x, z in PENDANTS:
        g.box(x - 0.06, x + 0.06, 12.0, 14.3, z - 0.06, z + 0.06, P.BLACK, 0)
        g.cone(x, z, 11.0, 1.45, 12.05, 0.45, P.RED, 12)
        g.cyl(x, z, 10.95, 11.05, 1.5, P.WHITE, 12)          # the shade's white lip
        g.cyl(x, z, 10.55, 10.95, 0.42, P.WHITE, 8)          # the bulb


# ------------------------------------------------------------------ Lv4
LOCKER_BANKS = (-13.5, 13.5)


def lockers(g):
    cols = (P.BLUE, P.ORANGE, P.RED)
    for c in LOCKER_BANKS:
        for i in range(3):
            l0 = c - 2.4 + i * 1.6 + 0.03
            l1 = l0 + 1.54
            col = cols[i]
            g.box(l0, l1, FLOOR, 7.2, 13.0, ID + 0.05, col, 0.06)
            g.box(l0 + 0.12, l1 - 0.12, 1.0, 6.95, 12.9, 13.05, col, 0.05)       # the door
            for k in range(3):
                g.box(l0 + 0.35, l1 - 0.35, 5.9 + k * 0.3, 6.02 + k * 0.3, 12.84, 12.94, P.INK, 0)
            g.box(l1 - 0.48, l1 - 0.3, 3.4, 4.6, 12.72, 12.94, P.LBG, 0.03)       # handle
            g.box(l0 + 0.35, l1 - 0.35, 5.05, 5.45, 12.86, 12.93, P.WHITE, 0)    # name tag
        # a helmet and a kit bag on top, a bench in front, a towel on it
        g.cyl(c - 1.6, 13.8, 7.15, 7.75, 0.7, P.YELLOW, 12)
        g.cyl(c - 1.6, 13.8, 7.7, 8.05, 0.5, P.YELLOW, 12)
        g.cyl_x(c + 1.2, 7.65, 13.8, 0.48, 1.9, P.ORANGE, 10)
        g.box(c - 2.6, c + 2.6, 2.0, 2.4, 11.0, 12.2, P.BROWN, 0.08)
        for s in (-1, 1):
            g.box(c + s * 2.1 - 0.25, c + s * 2.1 + 0.25, FLOOR, 2.02, 11.2, 12.0, P.DBG, 0.04)
        g.box(c - 0.4, c + 0.8, 2.38, 2.52, 11.05, 12.15, P.WHITE, 0.03)


def coffee(g):
    # the counter on the right wall, its doors toward the room
    g.box(23.6, IW + 0.05, FLOOR, 3.3, -14.0, -6.4, P.WHITE, 0.08)
    for z0, z1 in ((-13.7, -11.4), (-11.2, -8.9), (-8.7, -6.7)):
        g.box(23.5, 23.66, 1.0, 3.0, z0, z1, P.BLUE, 0.04)
        g.box(23.38, 23.52, 2.4, 2.75, (z0 + z1) / 2 - 0.4, (z0 + z1) / 2 + 0.4, P.LBG, 0.02)
    g.box(23.3, IW + 0.05, 3.3, 3.65, -14.25, -6.2, P.BROWN, 0.06)
    # the coffee machine, carafe, mugs, kettle, sugar jar
    g.box(24.3, 25.5, 3.65, 5.9, -13.6, -12.0, P.DBG, 0.12)
    g.box(24.1, 24.4, 5.2, 5.6, -13.4, -12.2, P.INK, 0.04)
    g.box(23.9, 24.35, 3.65, 3.8, -13.3, -12.3, P.LBG, 0.03)
    g.box(24.18, 24.32, 5.65, 5.8, -12.4, -12.2, P.RED, 0)
    g.cyl(24.0, -12.8, 3.8, 4.6, 0.35, P.GLASS, 10)
    g.cyl(24.0, -12.8, 4.6, 4.75, 0.25, P.INK, 10)
    for z, c in ((-10.8, P.YELLOW), (-10.1, P.RED), (-9.4, P.BLUE), (-8.7, P.WHITE)):
        g.cyl(24.0, z, 3.65, 4.2, 0.3, c, 10)
        g.box(23.58, 23.72, 3.75, 4.05, z - 0.06, z + 0.06, c, 0.02)
    g.cyl(24.9, -7.4, 3.65, 4.5, 0.45, P.WHITE, 12)
    g.box(24.84, 24.96, 4.5, 4.75, -7.6, -7.2, P.INK, 0.02)
    g.cyl(24.9, -9.6, 3.65, 4.2, 0.3, P.GLASS, 10)
    g.cyl(24.9, -9.6, 4.2, 4.32, 0.32, P.RED, 10)
    # a shelf above, left of the window: mugs and jars
    g.box(24.4, IW + 0.05, 6.6, 6.85, -14.0, -10.6, P.BROWN, 0.04)
    for z in (-13.4, -11.4):
        g.box(25.0, IW + 0.05, 5.9, 6.6, z - 0.12, z + 0.12, P.DBG, 0.02)
    for z, c in ((-13.4, P.RED), (-12.6, P.YELLOW), (-11.8, P.GLASS), (-11.1, P.ORANGE)):
        g.cyl(25.0, z, 6.85, 7.5, 0.3, c, 10)
    # the fridge between the windows: seam, handles, magnets
    g.box(23.4, IW + 0.05, FLOOR, 6.4, -5.5, -2.9, P.WHITE, 0.12)
    g.box(23.34, 23.42, 4.2, 4.3, -5.4, -3.0, P.LBG, 0)
    for y0, y1 in ((2.4, 3.8), (4.6, 5.8)):
        g.box(23.18, 23.38, y0, y1, -3.35, -3.15, P.LBG, 0.03)
    for y, z, c in ((5.4, -4.6, P.RED), (5.0, -4.1, P.YELLOW), (2.8, -4.8, P.BLUE), (3.3, -4.3, P.GREEN)):
        g.box(23.3, 23.42, y - 0.15, y + 0.15, z - 0.15, z + 0.15, c, 0.02)


def sofa(g):
    # rug, sofa against the right wall between the windows' sills, cushions, arms, pillows; a coffee table
    g.box(17.6, 24.2, 0.77, 0.81, -0.8, 8.8, P.WHITE, 0)
    g.box(17.9, 23.9, 0.78, 0.83, -0.5, 8.5, P.BLUE, 0)
    g.box(22.0, IW + 0.05, FLOOR, 1.9, 0.4, 7.6, P.RRED, 0.12)
    g.box(24.5, IW + 0.05, 1.8, 3.9, 0.4, 7.6, P.RRED, 0.18)
    for z0, z1 in ((1.0, 3.95), (4.05, 7.0)):
        g.box(22.15, 24.6, 1.8, 2.6, z0, z1, P.RED, 0.2)
        g.box(23.95, 24.6, 2.5, 3.75, z0 + 0.1, z1 - 0.1, P.RED, 0.2)
    for z0, z1 in ((0.4, 1.0), (7.0, 7.6)):
        g.box(22.0, IW + 0.05, FLOOR, 2.85, z0, z1, P.RRED, 0.1)
        g.cyl_x(23.8, 2.85, (z0 + z1) / 2, 0.32, 3.55, P.RRED, 10)
    g.box(23.55, 24.0, 2.55, 3.65, 1.3, 2.5, P.YELLOW, 0.15)
    g.box(23.55, 24.0, 2.55, 3.65, 5.5, 6.7, P.ORANGE, 0.15)
    # coffee table: top, legs, magazines, a mug
    g.box(18.6, 20.8, 1.95, 2.3, 1.8, 6.2, P.BROWN, 0.08)
    for x in (18.9, 20.5):
        for z in (2.1, 5.9):
            g.box(x - 0.18, x + 0.18, 0.84, 1.96, z - 0.18, z + 0.18, P.DBG, 0.03)
    g.box(19.0, 20.0, 2.29, 2.36, 2.3, 3.6, P.BLUE, 0)
    g.box(19.3, 20.3, 2.34, 2.41, 2.8, 4.0, P.WHITE, 0)
    g.cyl(19.7, 5.2, 2.29, 2.85, 0.3, P.YELLOW, 10)


# ------------------------------------------------------------------ build
COLS = {
    "Lv3": [(-3.6, 3.6, FLOOR, 3.5, -5.6, 1.6), (-6.6, 6.6, FLOOR, 4.4, 6.2, 9.4)],
    "Lv4": [(c - 2.45, c + 2.45, FLOOR, 7.2, 12.85, ID + 0.05) for c in LOCKER_BANKS]
    + [(c - 2.6, c + 2.6, FLOOR, 2.4, 11.0, 12.2) for c in LOCKER_BANKS]
    + [(23.3, IW + 0.05, FLOOR, 3.65, -14.25, -6.2), (23.4, IW + 0.05, FLOOR, 6.4, -5.5, -2.9),
       (22.0, IW + 0.05, FLOOR, 2.6, 0.4, 7.6), (24.5, IW + 0.05, FLOOR, 3.9, 0.4, 7.6),
       (18.6, 20.8, FLOOR, 2.3, 1.8, 6.2)],
}


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_HQInterior_Brick", ALB)
    meshes = []

    def out(name, g):
        obj = g.b.to_object(name, mat)
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[hqint] %-18s %5d tris" % (name, g.b.tris()))

    for name, fn in (("Lv3_L01_Dispatch", dispatch), ("Lv3_L02_Walls", walls), ("Lv3_L03_Ceiling", ceiling),
                     ("Lv4_L01_Lockers", lockers), ("Lv4_L02_Coffee", coffee), ("Lv4_L03_Sofa", sofa)):
        g = G()
        fn(g)
        out(name, g)
    for lv, boxes in COLS.items():
        for k, bx in enumerate(boxes):
            g = G()
            g.box(*bx, P.DBG, 0)
            out("%s_Col%02d_COL" % (lv, k + 1), g)

    pts = []
    for e in meshes:
        if e["role"] == "visual":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[hqint] LOD0 %d tris; bbox studs %s..%s; dims_m %s" % (total, [round(v, 2) for v in lo],
                                                                   [round(v, 2) for v in hi], dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "the HQ station's inside (51.2 x 29.2 studs, ceiling 15), built in the HQ spot frame at 1x",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay level/layer names (docs/25 J): Lv3_L01_..., Lv4_L01_..., Lv3_Col01_COL..; "
                      "DockPieces.addonMesh keeps the levels up to the HQ's",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "closeups": [
            {"name": "dispatch", "target": [0, 3, 4], "dist": 20, "az": -20, "el": 18},
            {"name": "lockers", "target": [13.5, 13, 4], "dist": 14, "az": -15, "el": 12},
            {"name": "coffee", "target": [-24.5, -10, 4], "dist": 12, "az": -70, "el": 15},
            {"name": "sofa", "target": [-23, 4, 2.5], "dist": 12, "az": -80, "el": 18},
        ],
    }
