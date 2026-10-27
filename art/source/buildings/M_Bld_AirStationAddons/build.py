"""M_Bld_AirStationAddons: the Air Station's level add-ons, Lego style (docs/25 B; docs/05 2.2, 3, 4, 5).

The Lv1 station stays the code-built `airStation()` in src/shared/DockPieces.luau: the hangar at the 42 x 28 stud spot
(plinth top 0.4, arched red roof, open front -Y) and the 36 x 36 helipad 38 right / 27 fwd of it (Roblox +X / -Z, so
Blender x -38, y -27; pad top 0.6). This asset adds only what the two levels add, in the hangar's frame: ground z 0,
front -Y (Roblox -Z), origin the hangar's ground centre, built at 1x (the AirStation row has no scale). The add-ons sit
on the hangar's other flanks: the Lv2 refuel pad on the +X side, the Lv3 patrol hut on the -X side, each with a clear
lane to the hangar walls and the code pad's rim, clear of the hangar mouth and the helicopter spot.

Lv2 (config piece RefuelPad, effect Refuel): a second, smaller 24 x 24 pad beside the hangar: light grey rim with studs,
dark grey deck, a yellow perimeter line and a big yellow H; a chunky coastguard-red fuel bowser (cab, ribbed tank with
white bands, yellow bumpers and hazard plate, black wheels with stud hubs) parked on the east half, a hose reel with a
black hose coil and yellow nozzle on a studded hazard plate at the north-west corner, and a red/white windsock on a
striped pole on its own studded base at the north-east corner.

Lv3 (config piece PatrolHut, effect Patrol): a walk-in red crew hut on a studded pad west of the hangar: navy base
course, white eave trim, brick course seams and staggered joints, a 6-stud doorway (6.0 clear) with a navy frame and a
yellow canopy, navy-framed windows, a navy pitched roof with a white ribbon, white ridge cap with studs and white barge
boards, and a small control-tower cab on the roof (navy saddle drum, red body, navy glazing band, white studded cap,
plain yellow beacon housing). Inside: a light floor, a flight-plan board with red/yellow strips on the back wall,
three navy lockers against the west wall, a plotting table; outside, a red bench under the front wall, left of the
door.

Each level is a top-level node (Lv2, Lv3) holding four/six construction layers (L01_* bottom up), one palette mesh per
layer (flat colours via UVs, one draw call per layer, like M_Bld_ClinicAddons). Collision is one simple box per object,
<Node>_ColNN_COL: pads, truck, reel, windsock, hut walls in bites round the doorway, roof, cab, bench, lockers, table;
the lanes, the doorway and the hangar mouth stay open.

    python3 art/source/buildings/M_Bld_AirStationAddons/maketex.py \
        --out build/prod/M_Bld_AirStationAddons/textures/M_Bld_AirStationAddons --name AirStationAddons --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_AirStationAddons/build.py \
        --out-root build/prod/M_Bld_AirStationAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_AirStationAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "AirStationAddons", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_AirStationAddons_Brick_ALB.png")

STUD_R, STUD_H = 0.30, 0.20
PB, PD, PR = 0.35, 0.60, 0.68          # pad base top, deck top, rim top (studs)

# ------------------------------------------------------------------ Lv2 refuel pad (east of the hangar)
PX0, PX1, PY0, PY1 = 25.0, 49.0, -3.0, 21.0
RIM = 0.9
HCX, HCY = 34.6, 9.0                   # H centre (west of the parked bowser)
T_WHEEL_Z = PD + 1.35                  # wheel centre: tyre bottom on the deck
APX0, APX1, APY0, APY1 = 49.0, 69.0, -0.5, 19.9   # striped apron east of the pad: the bowser parks here
TRUCK_X0, TRUCK_X1 = 59.6, 66.0
TRUCK_Y0, TRUCK_Y1 = 3.0, 16.4
REEL = (50.6, 7.5, 56.6, 12.0)         # hose reel hazard plate x0, y0, x1, y1
WSX, WSY = 45.6, 18.7                  # windsock pole, on the pad's NE corner
WS_TOP = 16.2

# ------------------------------------------------------------------ Lv3 patrol hut (north-west of the hangar)
# Each node is authored at its old spot and moved by SHIFT on output (island fit, 2026-10-27): the hut pad lands at
# x 36..56, y -30..-9, in front of the refuel pad with a 6-stud lane (the old spot was off the plate); Lv2 moves 6
# toward the hangar (pad 0.5 off the plinth) to pull the apron out of the Trophy Hall lot.
SHIFT = {"Lv2": (-6.0, 0.0), "Lv3": (81.5, -27.0)}
HUT_SHIFT = SHIFT["Lv3"]
HX0, HX1, HY0, HY1 = -43.5, -27.5, 0.0, 15.0
HPX0, HPX1, HPY0, HPY1 = -45.5, -25.5, -3.0, 18.0
FLOOR = PD                              # hut floor = pad deck top
DOOR_X0, DOOR_X1, DOOR_TOP = -38.5, -32.5, 7.4
WALL = 0.6
EAVE, RIDGE, RIDGE_X = 8.8, 12.4, -35.5
ROOF_X0, ROOF_X1, ROOF_Y0, ROOF_Y1 = -44.4, -26.6, -0.9, 15.9
SAD_X0, SAD_X1, SAD_Y0, SAD_Y1 = -39.7, -31.3, 3.3, 11.7
SAD_Z0, SAD_Z1 = 9.2, 12.8
CABX0, CABX1, CABY0, CABY1 = -39.5, -31.5, 3.5, 11.5
CAB_Z0, CAB_Z1, GLZ_Z0, GLZ_Z1 = 12.8, 16.8, 13.9, 16.2
CAPX0, CAPX1, CAPY0, CAPY1, CAP_Z1 = -40.2, -30.8, 2.8, 12.2, 17.3
BEA_Z1 = 19.6
BENCH = (-43.0, -1.9, -39.5, 0.0)       # seat/back footprint x0, y0, x1, y1
LOCKERS = (-42.9, 3.0, -41.3, 11.2)
TABLE = (-38.2, 12.7, -33.2, 14.2)
BOARD = (-39.0, -32.0)                  # flight-plan board x span


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


def cyl_y(b, cx, y0, y1, cz, r, c, n=8):
    """A closed cylinder along Y (the bowser tank)."""
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def stud(b, x, y, z, c, r=STUD_R, h=STUD_H):
    b.cyl(x, y, z, z + h, r, c, 6, bottom=False)


def ring_studs(b, x0, x1, y0, y1, z=PR, c=P.LBG, inset=0.45, step=2.4, avoid=()):
    def line(a, b):
        k = max(1, round((b - a) / step))
        return [a + (b - a) * i / k for i in range(k + 1)]
    pts = [(x, y0 + inset) for x in line(x0 + inset, x1 - inset)]
    pts += [(x, y1 - inset) for x in line(x0 + inset, x1 - inset)]
    ys = line(y0 + inset + step, y1 - inset - step)
    pts += [(x0 + inset, y) for y in ys] + [(x1 - inset, y) for y in ys]
    for x, y in pts:
        if all(abs(x - ax) > 1.0 or abs(y - ay) > 1.0 for ax, ay in avoid):
            stud(b, x, y, z, c)


def pad(b, x0, x1, y0, y1, rim_c=P.LBG, deck_c=P.DBG, avoid=()):
    b.box((x0, y0, 0.0), (x1, y1, PB), P.LBG, bevel=0.08)
    b.box((x0 + RIM, y0 + RIM, PB), (x1 - RIM, y1 - RIM, PD), deck_c, bevel=0.02)
    b.box((x0, y0, PB), (x1, y0 + RIM, PR), rim_c, bevel=0.02)
    b.box((x0, y1 - RIM, PB), (x1, y1, PR), rim_c, bevel=0.02)
    b.box((x0, y0 + RIM, PB), (x0 + RIM, y1 - RIM, PR), rim_c, bevel=0.02)
    b.box((x1 - RIM, y0 + RIM, PB), (x1, y1 - RIM, PR), rim_c, bevel=0.02)
    ring_studs(b, x0, x1, y0, y1, avoid=avoid)


def window(b, cx, cy, w, z0, z1, axis, sign, frame=P.INK, glass=P.GLASS):
    """A navy frame + glass pane 0.1 proud of a wall face (axis 'y' front/back, 'x' sides)."""
    t, d = 0.3, 0.1
    if axis == "y":
        lo, hi = sorted((cy, cy + sign * d))
        parts = ((cx - w / 2, lo, z0 - t, cx + w / 2, hi, z0), (cx - w / 2, lo, z1, cx + w / 2, hi, z1 + t),
                 (cx - w / 2, lo, z0, cx - w / 2 + t, hi, z1), (cx + w / 2 - t, lo, z0, cx + w / 2, hi, z1))
        pane = (cx - w / 2 + t, lo, z0, cx + w / 2 - t, hi, z1)
    else:
        lo, hi = sorted((cx, cx + sign * d))
        parts = ((lo, cy - w / 2, z0 - t, hi, cy + w / 2, z0), (lo, cy - w / 2, z1, hi, cy + w / 2, z1 + t),
                 (lo, cy - w / 2, z0, hi, cy - w / 2 + t, z1), (lo, cy + w / 2 - t, z0, hi, cy + w / 2, z1))
        pane = (lo, cy - w / 2 + t, z0, hi, cy + w / 2 - t, z1)
    for p in parts:
        b.box(p[:3], p[3:], frame, bevel=0.02)
    b.box(pane[:3], pane[3:], glass, bevel=0.01)


# ------------------------------------------------------------------ Lv2: refuel pad
def apron(b):
    """A striped service apron on the pad's east flank: dark deck, yellow / navy hazard blocks round the edge."""
    b.box((APX0, APY0, 0.0), (APX1, APY1, PB), P.LBG, bevel=0.08)
    b.box((APX0, APY0, PB), (APX1, APY1, PD), P.DBG, bevel=0.02)
    w, seg = 1.2, 1.8
    for y0, y1 in ((APY0, APY0 + w), (APY1 - w, APY1)):
        n = round((APX1 - APX0) / seg)
        for i in range(n):
            b.box((APX0 + i * (APX1 - APX0) / n, y0, PD), (APX0 + (i + 1) * (APX1 - APX0) / n, y1, PD + 0.07),
                  P.YELLOW if i % 2 == 0 else P.INK, bevel=0.0)
    for x0, x1 in ((APX0, APX0 + w), (APX1 - w, APX1)):
        n = round((APY1 - APY0 - 2 * w) / seg)
        for i in range(n):
            ya = APY0 + w + i * (APY1 - APY0 - 2 * w) / n
            b.box((x0, ya, PD), (x1, ya + (APY1 - APY0 - 2 * w) / n, PD + 0.07),
                  P.INK if i % 2 == 0 else P.YELLOW, bevel=0.0)


def refuel_pad(b):
    pad(b, PX0, PX1, PY0, PY1)
    apron(b)
    for p in ((26.5, -1.5, 47.5, -1.05), (26.5, 19.05, 47.5, 19.5),
              (26.5, -1.05, 26.95, 19.05), (47.05, -1.05, 47.5, 19.05)):
        b.box((p[0], p[1], PD), (p[2], p[3], PD + 0.04), P.YELLOW, bevel=0.0)     # yellow edge line
    for p in ((HCX - 3.4, HCY - 4.2, HCX - 1.8, HCY + 4.2),                       # the H, 6.8 x 8.4
              (HCX + 1.8, HCY - 4.2, HCX + 3.4, HCY + 4.2),
              (HCX - 3.4, HCY - 0.8, HCX + 3.4, HCY + 0.8)):
        b.box((p[0], p[1], PD), (p[2], p[3], PD + 0.06), P.YELLOW, bevel=0.0)


def bowser(b):
    z = PD
    x0, x1 = TRUCK_X0, TRUCK_X1
    y0, y1 = TRUCK_Y0, TRUCK_Y1
    cx = (x0 + x1) / 2
    b.box((x0, y0 + 0.2, z + 1.15), (x1, y1, z + 1.75), P.INK, bevel=0.04)         # chassis
    b.box((x0 + 0.1, y0, z + 1.75), (x1 - 0.1, y0 + 4.4, z + 5.8), P.RED, bevel=0.18)   # cab
    b.box((x0, y0 - 0.1, z + 5.8), (x1, y0 + 4.5, z + 6.02), P.WHITE, bevel=0.04)  # white roof cap
    b.studs(x0 + 0.6, x1 - 0.6, y0 + 0.7, y0 + 3.9, z + 6.02, P.WHITE, step=1.8, r=0.34, n=6)
    b.box((x0 + 0.45, y0 - 0.06, z + 3.8), (x1 - 0.45, y0, z + 5.4), P.INK, bevel=0.03)  # windscreen
    for xa, xb in ((x0 + 0.04, x0 + 0.1), (x1 - 0.1, x1 - 0.04)):
        b.box((xa, y0 + 1.3, z + 3.8), (xb, y0 + 3.4, z + 5.3), P.INK, bevel=0.03)  # cab side windows
    b.box((x0 - 0.2, y0 - 0.3, z + 0.85), (x1 + 0.2, y0 + 0.2, z + 1.7), P.YELLOW, bevel=0.04)   # front bumper
    b.box((x0 + 1.9, y0 - 0.05, z + 2.4), (x1 - 1.9, y0, z + 3.4), P.INK, bevel=0.02)            # grille
    for hx in (x0 + 0.55, x1 - 1.55):
        b.box((hx, y0 - 0.07, z + 2.05), (hx + 1.0, y0, z + 2.75), P.YELLOW, bevel=0.02)         # headlights
    b.box((x0 - 0.2, y1 - 0.2, z + 0.85), (x1 + 0.2, y1 + 0.25, z + 1.7), P.INK, bevel=0.04)    # rear bumper
    b.box((x0, y1 + 0.05, z + 1.85), (x1, y1 + 0.2, z + 3.9), P.RED, bevel=0.03)                 # rear panel
    b.box((x0 + 0.25, y1 + 0.2, z + 2.1), (x1 - 0.25, y1 + 0.27, z + 2.5), P.YELLOW, bevel=0.0)  # hazard plate
    # the tank: a big red drum along Y with two white bands, a light hatch on top and side markers on the chassis
    tank_y0, tank_y1, tank_z, tank_r = y0 + 4.6, y1 - 0.2, z + 4.1, 2.5
    cyl_y(b, cx, tank_y0, tank_y1, tank_z, tank_r, P.RED, 10)
    for by in (tank_y0 + 2.6, tank_y1 - 3.1):
        cyl_y(b, cx, by, by + 0.5, tank_z, tank_r + 0.06, P.WHITE, 10)
    for yy in (tank_y0 + 0.03, tank_y1 - 0.09):
        cyl_y(b, cx, yy, yy + 0.06, tank_z, tank_r + 0.02, P.INK, 10)          # dark end rims
    b.box((cx - 1.0, 7.9, tank_z + tank_r - 0.06), (cx + 1.0, 9.7, tank_z + tank_r + 0.45), P.LBG, bevel=0.05)
    b.studs(cx - 0.65, cx + 0.65, 8.3, 9.3, tank_z + tank_r + 0.45, P.LBG, step=1.2, r=0.3, n=6)
    for xa, xb in ((x0 - 0.06, x0), (x1, x1 + 0.06)):
        b.box((xa, 9.0, z + 1.85), (xb, 10.4, z + 2.2), P.YELLOW, bevel=0.02)         # chassis side markers
    b.box((x0 - 0.4, 9.3, z + 1.9), (x0, 10.5, z + 2.7), P.YELLOW, bevel=0.04)    # hose coupling, west flank
    b.box((x0 - 0.55, 9.6, z + 2.1), (x0 - 0.4, 10.2, z + 2.5), P.BLACK, bevel=0.02)
    for s_, wx in ((-1, x0 - 0.1), (1, x1 + 0.1)):                                # chunky wheels, stud hubs
        for wy in (y0 + 2.4, y1 - 2.0):
            b.cyl_x(wx, wy, T_WHEEL_Z, 1.35, 1.1, P.BLACK, 12)
            b.cyl_x(wx + s_ * 0.63, wy, T_WHEEL_Z, 0.78, 0.16, P.LBG, 10)
            b.cyl_x(wx + s_ * 0.82, wy, T_WHEEL_Z, 0.36, 0.24, P.LBG, 6)


def fuel_reel(b):
    """A big yellow-flanged red drum with a black hose coil on a hazard plate; the hose runs over the apron to the bowser."""
    x0, y0, x1, y1 = REEL
    b.box((x0, y0, PD), (x1, y1, PD + 0.4), P.YELLOW, bevel=0.04)                  # hazard plate
    for sx in (x0 + 0.5, x1 - 0.5):
        for sy in (y0 + 0.5, y1 - 0.5):
            stud(b, sx, sy, PD + 0.4, P.YELLOW, r=0.3)
    rcx, rcy, rcz = (x0 + x1) / 2, (y0 + y1) / 2, PD + 3.6
    for xa, xb in ((x0 + 0.7, x0 + 1.5), (x1 - 1.5, x1 - 0.7)):                    # two stands
        b.box((xa, y0 + 0.5, PD + 0.4), (xb, y1 - 0.5, PD + 4.2), P.INK, bevel=0.06)
        b.box((xa - 0.2, y0 + 0.3, PD + 4.2), (xb + 0.2, y1 - 0.3, PD + 4.5), P.LBG, bevel=0.04)
        stud(b, (xa + xb) / 2, rcy, PD + 4.5, P.LBG, r=0.3)
    b.cyl_x(rcx, rcy, rcz, 1.9, 2.4, P.RED, 12)                                    # drum
    for s_ in (-1, 1):
        b.cyl_x(rcx + s_ * 1.35, rcy, rcz, 2.3, 0.3, P.YELLOW, 12)                  # flanges
    for xo in (-0.7, 0.0, 0.7):
        b.torus(rcx + xo, rcy, rcz, 2.0, 0.3, P.BLACK, maj=12, mnr=4)             # hose coil
    b.beam((x1 - 0.5, rcy, rcz), (x1 - 0.5, rcy, rcz + 1.5), 0.35, 0.35, P.YELLOW)   # crank arm + knob
    b.box((x1 - 0.8, rcy - 0.35, rcz + 1.4), (x1 + 0.2, rcy + 0.35, rcz + 1.9), P.YELLOW, bevel=0.04)
    pts = [(rcx + 0.4, rcy, rcz - 1.9), (rcx + 0.5, y0 + 0.6, PD + 0.6), (rcx + 0.5, y0 - 0.6, PD + 0.22),
           (TRUCK_X0 - 2.2, y0 - 0.9, PD + 0.22), (TRUCK_X0 - 1.3, 8.6, PD + 0.22),
           (TRUCK_X0 - 1.2, 9.9, PD + 0.22), (TRUCK_X0 - 0.5, 9.9, PD + 2.3)]
    for p, q in zip(pts, pts[1:]):                                                 # black hose, reel -> coupling
        b.beam(p, q, 0.42, 0.34, P.BLACK)


def windsock(b):
    b.box((WSX - 1.4, WSY - 1.4, PD), (WSX + 1.4, WSY + 1.4, PD + 0.8), P.LBG, bevel=0.06)
    for sx in (WSX - 0.8, WSX + 0.8):
        for sy in (WSY - 0.8, WSY + 0.8):
            stud(b, sx, sy, PD + 0.8, P.LBG, r=0.28)
    z = PD + 0.8
    for k in range(7):                                                            # striped pole
        z1 = z + 2.0 if k < 6 else WS_TOP
        b.box((WSX - 0.5, WSY - 0.5, z), (WSX + 0.5, WSY + 0.5, z1), P.WHITE if k % 2 == 0 else P.RED,
              bevel=0.03)
        z = z1
    b.box((WSX - 0.65, WSY - 0.65, WS_TOP), (WSX + 0.65, WSY + 0.65, WS_TOP + 0.25), P.INK, bevel=0.03)
    b.box((WSX + 0.5, WSY - 0.2, 14.9), (WSX + 1.1, WSY + 0.2, 15.2), P.INK, bevel=0.03)   # mouth arm
    mz = WS_TOP - 0.6
    b.torus(WSX + 1.0, WSY, mz, 1.75, 0.22, P.INK, maj=10, mnr=4)                  # mouth ring
    b.cyl_x(WSX + 2.45, WSY, mz, 1.7, 3.0, P.RED, 10)                              # big sock, tapering
    b.cyl_x(WSX + 5.2, WSY, mz - 0.25, 1.35, 2.6, P.WHITE, 10)
    b.cyl_x(WSX + 7.5, WSY, mz - 0.55, 1.0, 2.0, P.RED, 10)


# ------------------------------------------------------------------ Lv3: patrol hut
def hut_base(b):
    pad(b, HPX0, HPX1, HPY0, HPY1)
    b.box((HX0 + WALL, HY0 + WALL, PD), (HX1 - WALL, HY1 - WALL, PD + 0.10), P.LBG, bevel=0.02)   # floor
    b.box((DOOR_X0 + 0.3, HY0 + WALL, PD + 0.10), (DOOR_X1 - 0.3, HY0 + 2.2, PD + 0.13), P.INK, bevel=0.02)


def wall_ring(b, za, zb, c, out=0.05):
    cut = za < DOOR_TOP
    fronts = ((HX0 - out, DOOR_X0), (DOOR_X1, HX1 + out)) if cut else ((HX0 - out, HX1 + out),)
    for xa, xb in fronts:
        b.box((xa, HY0 - out, za), (xb, HY0, zb), c, bevel=0.0)
    b.box((HX0 - out, HY1, za), (HX1 + out, HY1 + out, zb), c, bevel=0.0)
    b.box((HX0 - out, HY0, za), (HX0, HY1, zb), c, bevel=0.0)
    b.box((HX1, HY0, za), (HX1 + out, HY1, zb), c, bevel=0.0)


def wall_joints(b, za, zb, off, step=3.2, c=P.DBG, out=0.04):
    n = int((HY1 - HY0) // step)
    for i in range(n + 1):
        y = HY0 + off + i * step
        if HY0 + 0.3 < y < HY1 - 0.3:
            b.box((HX0 - out, y - 0.05, za), (HX0, y + 0.05, zb), c, bevel=0.0)
            b.box((HX1, y - 0.05, za), (HX1 + out, y + 0.05, zb), c, bevel=0.0)
    for i in range(int((HX1 - HX0) // step) + 1):
        x = HX0 + off + i * step
        if HX0 + 0.3 < x < HX1 - 0.3:
            b.box((x - 0.05, HY1, za), (x + 0.05, HY1 + out, zb), c, bevel=0.0)
            if not DOOR_X0 - 0.4 < x < DOOR_X1 + 0.4 or za > DOOR_TOP:
                b.box((x - 0.05, HY0 - out, za), (x + 0.05, HY0, zb), c, bevel=0.0)


def hut_walls(b):
    z0, z1 = FLOOR, EAVE
    b.box((HX0, HY0, z0), (DOOR_X0, HY0 + WALL, z1), P.RED, bevel=0.05)
    b.box((DOOR_X1, HY0, z0), (HX1, HY0 + WALL, z1), P.RED, bevel=0.05)
    b.box((DOOR_X0, HY0, DOOR_TOP), (DOOR_X1, HY0 + WALL, z1), P.RED, bevel=0.05)
    b.box((HX0, HY1 - WALL, z0), (HX1, HY1, z1), P.RED, bevel=0.05)
    b.box((HX0, HY0 + WALL, z0), (HX0 + WALL, HY1 - WALL, z1), P.RED, bevel=0.05)
    b.box((HX1 - WALL, HY0 + WALL, z0), (HX1, HY1 - WALL, z1), P.RED, bevel=0.05)
    prism_y(b, HY0, HY0 + WALL, [(HX0, EAVE), (HX1, EAVE), (RIDGE_X, RIDGE)], P.RED)     # gable ends
    prism_y(b, HY1 - WALL, HY1, [(HX0, EAVE), (HX1, EAVE), (RIDGE_X, RIDGE)], P.RED)
    wall_ring(b, z0, 2.0, P.INK, out=0.08)                                               # navy base course
    for za in (3.4, 6.5):
        wall_ring(b, za, za + 0.08, P.DBG)                                               # plate course lines
    wall_ring(b, 8.0, z1, P.WHITE, out=0.08)                                             # white eave trim
    wall_joints(b, 2.0, 3.4, 1.6)
    wall_joints(b, 3.4, 6.5, 0.0)
    wall_joints(b, 6.5, 8.0, 1.6)
    b.box((DOOR_X0 - 0.35, -0.1, z0), (DOOR_X0, 0.0, DOOR_TOP + 0.35), P.INK, bevel=0.03)  # door frame
    b.box((DOOR_X1, -0.1, z0), (DOOR_X1 + 0.35, 0.0, DOOR_TOP + 0.35), P.INK, bevel=0.03)
    b.box((DOOR_X0 - 0.35, -0.1, DOOR_TOP), (DOOR_X1 + 0.35, 0.0, DOOR_TOP + 0.35), P.INK, bevel=0.03)
    b.box((DOOR_X0, -0.45, z0), (DOOR_X1, 0.66, z0 + 0.10), P.YELLOW, bevel=0.02)           # threshold
    b.box((DOOR_X0 - 0.8, -1.9, 7.6), (DOOR_X1 + 0.8, 0.0, 8.2), P.YELLOW, bevel=0.06)     # canopy
    for x in (DOOR_X0 - 0.5, DOOR_X1 + 0.5):
        b.beam((x, -0.15, 6.2), (x, -1.65, 7.6), 0.28, 0.28, P.INK)
    b.stud_row(DOOR_X0 + 0.4, -0.95, DOOR_X1 - 0.4, -0.95, 8.2, P.YELLOW, spacing=2.2, r=0.28, n=6)
    wz0, wz1 = 3.2, 5.8
    window(b, -30.0, HY0, 2.4, wz0, wz1, "y", -1)
    window(b, -41.0, HY1, 2.4, wz0, wz1, "y", 1)
    window(b, -30.0, HY1, 2.4, wz0, wz1, "y", 1)
    for wy in (4.5, 10.5):
        window(b, HX1, wy, 2.8, wz0, wz1, "x", 1)
    window(b, HX0, 12.5, 2.8, wz0, wz1, "x", -1)


def hut_roof(b):
    profile = [(ROOF_X0, EAVE), (ROOF_X1, EAVE), (RIDGE_X, RIDGE)]
    prism_y(b, ROOF_Y0, 4.2, profile, P.INK)                                     # navy roof
    prism_y(b, 4.2, 5.4, profile, P.WHITE)                                       # white ribbon
    prism_y(b, 5.4, ROOF_Y1, profile, P.INK)
    b.box((RIDGE_X - 0.45, ROOF_Y0, RIDGE), (RIDGE_X + 0.45, ROOF_Y1, RIDGE + 0.3), P.WHITE, bevel=0.03)
    for ya, yb in ((ROOF_Y0 + 0.2, 3.0), (12.0, ROOF_Y1 - 0.2)):                # ridge studs, clear of the cab
        b.stud_row(RIDGE_X, ya, RIDGE_X, yb, RIDGE + 0.3, P.WHITE, spacing=1.6, r=0.28, n=6)
    for y in (ROOF_Y0 + 0.2, ROOF_Y1 - 0.2):                                    # white barge boards
        b.beam((ROOF_X0, y, EAVE + 0.12), (RIDGE_X, y, RIDGE + 0.12), 0.5, 0.35, P.WHITE)
        b.beam((RIDGE_X, y, RIDGE + 0.12), (ROOF_X1, y, EAVE + 0.12), 0.5, 0.35, P.WHITE)
    for y0, y1 in ((ROOF_Y0, ROOF_Y0 + 0.4), (ROOF_Y1 - 0.4, ROOF_Y1)):         # white eave fascia
        b.box((ROOF_X0, y0, EAVE - 0.12), (ROOF_X1, y1, EAVE + 0.1), P.WHITE, bevel=0.02)


def hut_tower(b):
    cx, cy = (CABX0 + CABX1) / 2, (CABY0 + CABY1) / 2
    b.box((SAD_X0, SAD_Y0, SAD_Z0), (SAD_X1, SAD_Y1, SAD_Z1), P.RED, bevel=0.08)           # saddle drum
    b.box((CABX0, CABY0, CAB_Z0), (CABX1, CABY1, CAB_Z1), P.RED, bevel=0.12)               # cab body
    for dx in (-1.9, 1.9):                                                                  # glass on all four sides
        window(b, cx + dx, CABY0, 3.0, GLZ_Z0, GLZ_Z1, "y", -1)
        window(b, cx + dx, CABY1, 3.0, GLZ_Z0, GLZ_Z1, "y", 1)
        window(b, CABX0, cy + dx, 3.0, GLZ_Z0, GLZ_Z1, "x", -1)
        window(b, CABX1, cy + dx, 3.0, GLZ_Z0, GLZ_Z1, "x", 1)
    for xa, xb in ((CABX0 - 0.1, CABX0 + 0.5), (CABX1 - 0.5, CABX1 + 0.1)):
        for ya, yb in ((CABY0 - 0.1, CABY0 + 0.5), (CABY1 - 0.5, CABY1 + 0.1)):
            b.box((xa, ya, CAB_Z0), (xb, yb, CAB_Z1 + 0.1), P.RED, bevel=0.03)             # corner posts
    b.box((CAPX0, CAPY0, CAB_Z1), (CAPX1, CAPY1, CAP_Z1), P.INK, bevel=0.08)               # navy roof slab
    rz = CAP_Z1 + 0.85                                                                      # small railing round the roof
    for x in (CAPX0 + 0.3, (CAPX0 + CAPX1) / 2, CAPX1 - 0.3):
        for y in (CAPY0 + 0.3, CAPY1 - 0.3):
            b.box((x - 0.15, y - 0.15, CAP_Z1), (x + 0.15, y + 0.15, rz), P.YELLOW, bevel=0.02)
    for y in (CAPY0 + 1.7, cy, CAPY1 - 1.7):
        for x in (CAPX0 + 0.3, CAPX1 - 0.3):
            b.box((x - 0.15, y - 0.15, CAP_Z1), (x + 0.15, y + 0.15, rz), P.YELLOW, bevel=0.02)
    for y in (CAPY0 + 0.3, CAPY1 - 0.3):
        b.box((CAPX0 + 0.15, y - 0.12, rz - 0.2), (CAPX1 - 0.15, y + 0.12, rz), P.YELLOW, bevel=0.02)
    for x in (CAPX0 + 0.3, CAPX1 - 0.3):
        b.box((x - 0.12, CAPY0 + 0.15, rz - 0.2), (x + 0.12, CAPY1 - 0.15, rz), P.YELLOW, bevel=0.02)
    b.cyl(cx, cy, CAP_Z1, CAP_Z1 + 0.35, 1.3, P.INK, 8)
    b.cyl(cx, cy, CAP_Z1 + 0.35, BEA_Z1 - 0.15, 0.9, P.YELLOW, 8)                          # beacon housing
    b.cyl(cx, cy, BEA_Z1 - 0.15, BEA_Z1, 0.95, P.INK, 8)


def hut_inside(b):
    b.box((BOARD[0], 14.22, 3.0), (BOARD[1], HY1 - WALL, 6.6), P.INK, bevel=0.03)         # board frame
    b.box((BOARD[0] + 0.35, 14.16, 3.35), (BOARD[1] - 0.35, 14.22, 6.25), P.WHITE, bevel=0.01)
    for x0, z0, x1, z1, c in ((-38.2, 4.35, -35.2, 4.65, P.RED),
                              (-38.2, 4.95, -35.2, 5.25, P.YELLOW),
                              (-38.2, 5.55, -34.4, 5.85, P.RED),
                              (-33.9, 4.45, -32.6, 5.35, P.YELLOW)):
        b.box((x0, 14.10, z0), (x1, 14.16, z1), c, bevel=0.0)
    x0, y0, x1, y1 = LOCKERS
    for k in range(3):
        ya = y0 + k * 2.8
        b.box((x0, ya, PD + 0.1), (x1, ya + 2.6, PD + 5.2), P.INK, bevel=0.04)
        b.box((x1, ya + 0.15, PD + 0.35), (x1 + 0.08, ya + 2.45, PD + 5.0), P.RED, bevel=0.01)
        b.box((x1 + 0.08, ya + 1.9, PD + 2.8), (x1 + 0.16, ya + 2.2, PD + 3.15), P.LBG, bevel=0.01)
        stud(b, (x0 + x1) / 2, ya + 1.3, PD + 5.2, P.INK, r=0.28)
    tx0, ty0, tx1, ty1 = TABLE
    b.box((tx0, ty0, 2.8), (tx1, ty1, 3.1), P.LBG, bevel=0.04)                             # plotting table
    for xa, xb in ((tx0, tx0 + 0.4), (tx1 - 0.4, tx1)):
        b.box((xa, ty0 + 0.2, PD + 0.1), (xb, ty1 - 0.2, 2.8), P.INK, bevel=0.03)
    for x in (tx0 + 1.1, tx1 - 1.1):
        stud(b, x, (ty0 + ty1) / 2, 3.1, P.LBG, r=0.26)
    b.box((tx0 + 1.4, ty0 + 0.25, 3.1), (tx1 - 1.4, ty1 - 0.25, 3.16), P.YELLOW, bevel=0.0)


def hut_bench(b):
    """A Lego park bench against the front wall: navy legs and side frames, a yellow studded seat, a red-railed back."""
    x0, y0, x1, y1 = BENCH
    zs = 2.45                                                                               # seat underside
    b.box((x0, y0, zs), (x1, y1, zs + 0.5), P.YELLOW, bevel=0.05)                         # seat plank
    b.studs(x0 + 0.3, x1 - 0.3, y0 + 0.3, y1 - 0.5, zs + 0.5, P.YELLOW, step=1.1, r=0.3, n=6)
    for xa in (x0 + 0.1, x1 - 0.6):
        for ya in (y0 + 0.1, y1 - 0.65):
            b.box((xa, ya, PD), (xa + 0.5, ya + 0.5, zs), P.INK, bevel=0.03)              # four navy legs
        b.box((xa, y0 + 0.1, zs - 0.4), (xa + 0.5, y1 - 0.1, zs), P.INK, bevel=0.03)        # side rail under the seat
    for xa in (x0 + 0.1, x1 - 0.6):
        b.box((xa, y1 - 0.65, zs + 0.5), (xa + 0.5, y1 - 0.15, zs + 2.9), P.INK, bevel=0.03)   # back posts
    b.box((x0 + 0.1, y1 - 0.45, zs + 1.0), (x1 - 0.1, y1 - 0.15, zs + 1.6), P.RED, bevel=0.03)  # back slat
    b.box((x0, y1 - 0.5, zs + 2.9), (x1, y1 - 0.1, zs + 3.3), P.RED, bevel=0.04)           # red top rail


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_AirStationAddons_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv2", "Lv3")}

    def out(name, b, node):
        if b.empty():
            return
        dx, dy = SHIFT[node]
        b.v = [(x + dx, y + dy, z) for x, y, z in b.v]
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[airstation] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    refuel_pad(b)
    out("Lv2_L01_RefuelPad", b, "Lv2")

    b = lego.B()
    bowser(b)
    out("Lv2_L02_Bowser", b, "Lv2")

    b = lego.B()
    fuel_reel(b)
    out("Lv2_L03_FuelReel", b, "Lv2")

    b = lego.B()
    windsock(b)
    out("Lv2_L04_Windsock", b, "Lv2")

    c = lego.B()
    c.box((PX0, PY0, 0.0), (PX1, PY1, PR), P.LBG)                                      # pad
    c.box((APX0, APY0, 0.0), (APX1, APY1, PD), P.LBG)                                  # apron
    c.box((TRUCK_X0 - 0.8, TRUCK_Y0 - 0.3, PD), (TRUCK_X1 + 0.8, TRUCK_Y1 + 0.3, PD + 7.4), P.RED)   # bowser
    c.box((REEL[0], REEL[1], PD), (REEL[2], REEL[3], PD + 4.5), P.INK)                 # reel
    c.box((WSX - 1.4, WSY - 1.4, PD), (WSX + 1.4, WSY + 1.4, WS_TOP), P.LBG)          # windsock
    out_cols("Lv2", c)

    b = lego.B()
    hut_base(b)
    out("Lv3_L01_Base", b, "Lv3")

    b = lego.B()
    hut_walls(b)
    out("Lv3_L02_Walls", b, "Lv3")

    b = lego.B()
    hut_roof(b)
    out("Lv3_L03_Roof", b, "Lv3")

    b = lego.B()
    hut_tower(b)
    out("Lv3_L04_Tower", b, "Lv3")

    b = lego.B()
    hut_inside(b)
    out("Lv3_L05_Crew", b, "Lv3")

    b = lego.B()
    hut_bench(b)
    out("Lv3_L06_Bench", b, "Lv3")

    c = lego.B()
    c.box((HPX0, HPY0, 0.0), (HPX1, HPY1, PR), P.LBG)                                  # pad
    c.box((HX0, HY0, FLOOR), (DOOR_X0, HY0 + WALL, EAVE), P.RED)                       # walls round the doorway
    c.box((DOOR_X1, HY0, FLOOR), (HX1, HY0 + WALL, EAVE), P.RED)
    c.box((DOOR_X0, HY0, DOOR_TOP), (DOOR_X1, HY0 + WALL, EAVE), P.RED)
    c.box((HX0, HY1 - WALL, FLOOR), (HX1, HY1, EAVE), P.RED)
    c.box((HX0, HY0 + WALL, FLOOR), (HX0 + WALL, HY1 - WALL, EAVE), P.RED)
    c.box((HX1 - WALL, HY0 + WALL, FLOOR), (HX1, HY1 - WALL, EAVE), P.RED)
    c.box((ROOF_X0, ROOF_Y0, EAVE), (ROOF_X1, ROOF_Y1, RIDGE + 0.4), P.INK)             # roof
    c.box((CAPX0, CAPY0, SAD_Z0), (CAPX1, CAPY1, BEA_Z1), P.INK)                       # saddle, cab, cap, beacon
    c.box((BENCH[0], BENCH[1], FLOOR), (BENCH[2], BENCH[3], 5.8), P.RED)               # bench
    c.box((LOCKERS[0], LOCKERS[1], FLOOR), (LOCKERS[2], LOCKERS[3], PD + 5.2), P.INK)  # lockers
    c.box((TABLE[0], TABLE[1], FLOOR), (TABLE[2], TABLE[3], 3.1), P.INK)               # table
    out_cols("Lv3", c)

    atts = [
        lego.attach("ATT_Work_RefuelPad", (HCX + SHIFT["Lv2"][0], HCY, PR)),
        lego.attach("ATT_Park_Bowser", ((TRUCK_X0 + TRUCK_X1) / 2 + SHIFT["Lv2"][0], 8.0, PD)),
        lego.attach("ATT_Work_FuelReel", ((REEL[0] + REEL[2]) / 2 + SHIFT["Lv2"][0], REEL[1] - 2.0, PD)),
        lego.attach("ATT_Work_PatrolHut", (-35.5 + HUT_SHIFT[0], -1.5 + HUT_SHIFT[1], PD)),
        lego.attach("ATT_Work_FlightBoard", (-35.5 + HUT_SHIFT[0], 13.0 + HUT_SHIFT[1], FLOOR + 0.1)),
    ]

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[airstation] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[airstation] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, on the code air station's ground beside the Lv1 hangar (37 x 31 stud plinth, top "
                     "0.4) and its 36 x 36 helipad at Blender (-38, -27): Lv2 pad x 19..43, y -3..21 on the +X side of the "
                     "hangar (0.5 off the plinth) plus a striped apron to x 63, Lv3 hut pad x 36..56, y -30..-9 in front of the "
                     "refuel pad (6-stud lane), 17.5 clear of the plinth; front "
                     "-Y, origin the hangar's ground centre, built at 1x (the AirStation row has no scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 B): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., "
                      "Lv3_Col01_COL..; the FBX importer flattens empty parents, so the node name is the mesh prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "refuel_pad", "target": [43.0, 9.0, 4.0], "dist": 46, "az": -50, "el": 22},
            {"name": "bowser", "target": [56.8, 9.0, 4.5], "dist": 24, "az": -60, "el": 12},
            {"name": "fuel_reel", "target": [49.0, 9.5, 3.5], "dist": 15, "az": -30, "el": 16},
            {"name": "hut", "target": [46.0, -20.0, 9.0], "dist": 34, "az": -28, "el": 14},
            {"name": "hut_door", "target": [43.5, -26.0, 3.5], "dist": 15, "az": -28, "el": 10},
            {"name": "tower", "target": [46.0, -19.5, 15.5], "dist": 20, "az": 22, "el": 10},
        ],
    }
