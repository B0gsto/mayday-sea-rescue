"""M_Bld_ClinicAddons: the Clinic's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

The Lv1 clinic stays the code-built `clinic()` in src/shared/DockPieces.luau: a white tent on a 39.44 x 31.44 stud
plinth (top z 0.92, final 1.15 scale), front -Y (Roblox -Z), origin the clinic ground centre. The tent and its fence
fill that plinth, so the level add-ons sit on the lawn on each flank with their own low pads, clear of the front
walkway and of the flag at x 20.6..24.5, y -4.25..-0.35.

Lv2 (engine: bunks 2 -> 4, treatment 2 -> 4): an open-sided white pavilion on the left flank, 6 posts, a red-cross
roof sign readable from the front and above, three made-up beds with red blankets along the back, and a white medic
counter with a first-aid kit at the front.

Lv3 (engine: bunks 4 -> 8, treatment 4 -> 8): a small walk-in white-and-red hospital wing on the right flank, 6-stud
open doorway with 6.0 clear, white walls with red base and eave bands, red-cross gable and a red cross on the roof
slope, windows, four beds along the side walls with IV stands, and a reception desk under the wall cabinet. Outside,
on its own pad clear of the flag and of the door approach, a parked Lego ambulance: white body, red stripe, red side
crosses, blue roof light (flat colour, no glow).

Each level is a top-level node (Lv2, Lv3) holding construction layers (L01_* bottom up), one palette mesh per layer
(flat colours via UVs, one draw call per layer, like M_Bld_FishMarketAddons). Collision is one simple box per object,
<Node>_ColNN_COL: pads, posts, roof, beds, counter; hospital walls in six bites and the roof overhead, so the 6-stud
doorway and the interior aisle stay open; the ambulance as one body box.

    python3 art/source/buildings/M_Bld_ClinicAddons/maketex.py \
        --out build/prod/M_Bld_ClinicAddons/textures/M_Bld_ClinicAddons --name Clinic --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_ClinicAddons/build.py \
        --out-root build/prod/M_Bld_ClinicAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_ClinicAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "Clinic", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_Clinic_Brick_ALB.png")

BASE, DECK, RIM, INT = 0.95, 1.01, 1.09, 1.05   # pad base top, deck top, rim top, interior floor top (studs)
STUD_R, STUD_H = 0.32, 0.2

PAV_X0, PAV_X1 = -35.6, -20.6
PAV_Y0, PAV_Y1 = -10.6, 7.6
PAV_FX0, PAV_FY0, PAV_FX1, PAV_FY1 = -34.5, -9.5, -21.7, 6.5
PAV_POST_X = (-34.6, -21.6)
PAV_POST_Y = (-9.6, -1.5, 6.2)
PAV_POST_TOP = 8.9
PAV_ROOF_X0, PAV_ROOF_X1 = -35.7, -20.5
PAV_EAVE_Y0, PAV_EAVE_Y1 = -10.9, 7.9
PAV_RIDGE_Y, PAV_EAVE_Z, PAV_RIDGE_Z = -1.5, 8.9, 11.1
PAV_BED_X = (-32.5, -28.0, -23.5)
PAV_BED_FOOT, PAV_BED_HEAD, BED_W = 0.4, 6.6, 3.4
COUNTER_TOP = 3.3
PAV_COUNTER = (-33.6, -8.2, -27.8, -5.9)
MEDIC_SPOT = (-30.7, -5.0)

H_X0, H_X1 = 20.6, 36.2
H_Y0, H_Y1 = 1.9, 20.1
H_WX0, H_WX1 = 21.6, 35.2
H_WY0, H_WY1 = 2.9, 19.1
H_FX0, H_FY0, H_FX1, H_FY1 = 22.2, 3.5, 34.6, 18.5
WALL = 0.6
H_EAVE, H_RIDGE, H_RIDGE_X = 9.2, 12.6, 28.4
H_ROOF = (20.2, H_EAVE, 36.6, H_EAVE, H_RIDGE_X, H_RIDGE)
DOOR_X0, DOOR_X1, DOOR_TOP = 23.9, 29.9, 7.9
H_BED_X = (23.85, 33.0)
H_BED_FOOT = (4.8, 11.55)
H_BED_LEN = 6.2
H_DESK = (25.7, 16.0, 31.1, 18.2)
QUEUE = (28.4, 14.6)

A_X0, A_X1 = 28.4, 35.2
A_Y0, A_Y1 = -19.1, 1.9
VAN_X0, VAN_X1 = 29.0, 34.6
VAN_Y0, VAN_Y1 = -12.4, 0.7               # van as modelled; placed AMB_DY further south
AMB_DY = -5.5                             # rear-door tips 6.3 clear of the hospital front wall
VAN_TOP = DECK + 6.8
H_TILE = (25.7, 12.0, 31.1, 16.0)         # medic work-zone floor tile, in front of the desk
PAV_TILE = (-34.0, -8.6, -27.4, -3.6)      # same tile under the Lv2 counter and medic spot
BAND0, BAND1 = 3.0, 4.2                   # hospital mid-height red band


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


def place_rot(dst, src, cx, cy, z, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    base = len(dst.v)
    dst.v.extend((cx + x * ca - y * sa, cy + x * sa + y * ca, z + zz) for x, y, zz in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


def stud(b, x, y, z, c, r=STUD_R, h=STUD_H):
    b.cyl(x, y, z, z + h, r, c, 6, bottom=False)


def ring_studs(b, x0, x1, y0, y1, z=RIM, c=P.WHITE, inset=0.45, step=2.4, avoid=()):
    """One row of studs on a pad's rim (rim is 0.9 wide); `avoid` = (x, y) spots (posts) to leave clear."""
    def line(a, b):
        k = max(1, round((b - a) / step))
        return [a + (b - a) * i / k for i in range(k + 1)]
    pts = [(x, y0 + inset) for x in line(x0 + inset, x1 - inset)] + [(x, y1 - inset) for x in line(x0 + inset, x1 - inset)]
    ys = line(y0 + inset + step, y1 - inset - step)
    pts += [(x0 + inset, y) for y in ys] + [(x1 - inset, y) for y in ys]
    for x, y in pts:
        if all(abs(x - ax) > 1.0 or abs(y - ay) > 1.0 for ax, ay in avoid):
            stud(b, x, y, z, c, r=0.3)


def wing_base(b, x0, x1, y0, y1, deck=P.LBG, avoid=()):
    b.box((x0, y0, 0.0), (x1, y1, BASE), P.LBG, bevel=0.08)
    b.box((x0 + 0.12, y0 + 0.12, BASE), (x1 - 0.12, y1 - 0.12, DECK), deck, bevel=0.02)
    t = 0.9
    b.box((x0, y0, DECK), (x1, y0 + t, RIM), P.WHITE, bevel=0.02)
    b.box((x0, y1 - t, DECK), (x1, y1, RIM), P.WHITE, bevel=0.02)
    b.box((x0, y0 + t, DECK), (x0 + t, y1 - t, RIM), P.WHITE, bevel=0.02)
    b.box((x1 - t, y0 + t, DECK), (x1, y1 - t, RIM), P.WHITE, bevel=0.02)
    ring_studs(b, x0, x1, y0, y1, avoid=avoid)


def ridge_sign(b, cx, y, leg_z, z0, w=6.0, h=2.6, rim=P.RED):
    """A stand-up double-faced sign on a roof ridge: red frame, white board, red cross on both faces, studded top."""
    t, y0, y1 = 0.3, y - 0.3, y + 0.3
    for lx in (cx - w / 2 + 0.9, cx + w / 2 - 0.9):
        b.box((lx - 0.3, y0 + 0.05, leg_z), (lx + 0.3, y1 - 0.05, z0 + 0.1), P.WHITE, bevel=0.03)
    b.box((cx - w / 2, y0, z0), (cx + w / 2, y1, z0 + h), rim, bevel=0.05)
    b.box((cx - w / 2 + t, y0 - 0.04, z0 + t), (cx + w / 2 - t, y1 + 0.04, z0 + h - t), P.WHITE, bevel=0.03)
    zm = z0 + h / 2
    for ya, yb in ((y0 - 0.04, y0 - 0.1), (y1 + 0.04, y1 + 0.1)):
        b.box((cx - 0.38, ya, zm - 0.95), (cx + 0.38, yb, zm + 0.95), P.RED, bevel=0.02)
        b.box((cx - 1.05, ya, zm - 0.38), (cx + 1.05, yb, zm + 0.38), P.RED, bevel=0.02)
    b.stud_row(cx - w / 2 + 0.7, y, cx + w / 2 - 0.7, y, z0 + h, rim, spacing=1.2, r=0.26, h=0.2, n=6)


# ------------------------------------------------------------------ beds, counters, medical kit
def bed(b, cx, foot_y, head_y, blanket=P.RED):
    z = INT
    w = BED_W
    b.box((cx - w / 2, foot_y - 0.3, z), (cx + w / 2, head_y + 0.3, z + 0.55), P.LBG, bevel=0.05)
    b.box((cx - w / 2 + 0.12, foot_y, z + 0.55), (cx + w / 2 - 0.12, head_y, z + 1.05), P.WHITE, bevel=0.06)
    b.box((cx - w / 2 - 0.02, foot_y + 0.35, z + 0.78), (cx + w / 2 + 0.02, head_y - 1.45, z + 1.25),
          blanket, bevel=0.05)
    b.box((cx - 1.1, head_y - 1.4, z + 1.05), (cx + 1.1, head_y - 0.25, z + 1.4), P.WHITE, bevel=0.12)
    b.box((cx - w / 2 - 0.05, head_y + 0.3, z), (cx + w / 2 + 0.05, head_y + 0.65, z + 2.4), P.WHITE, bevel=0.06)
    b.box((cx - w / 2 - 0.05, foot_y - 0.65, z), (cx + w / 2 + 0.05, foot_y - 0.3, z + 1.1), P.WHITE,
          bevel=0.06)


def iv_stand(b, x, y):
    z = INT
    b.cyl(x, y, z, z + 0.14, 0.55, P.DBG, 8)
    b.cyl(x, y, z + 0.14, z + 4.3, 0.09, P.LBG, 6)
    b.box((x - 0.05, y - 0.05, z + 4.05), (x + 0.05, y + 0.05, z + 4.35), P.DBG, bevel=0.01)
    b.box((x - 0.4, y - 0.18, z + 3.35), (x - 0.08, y + 0.18, z + 4.1), P.CYAN, bevel=0.06)
    b.box((x - 0.42, y - 0.2, z + 3.25), (x - 0.06, y + 0.2, z + 3.4), P.LBG, bevel=0.02)


def counter(b, x0, y0, x1, y1, top=COUNTER_TOP, body=P.WHITE, accent=P.RED):
    b.box((x0, y0, INT), (x1, y1, top - 0.25), body, bevel=0.05)
    b.box((x0 - 0.12, y0 - 0.12, top - 0.25), (x1 + 0.12, y1 + 0.12, top), P.TAN, bevel=0.05)
    b.box((x0 + 0.4, y0 - 0.07, INT + 0.45), (x1 - 0.4, y0, top - 0.75), accent, bevel=0.03)       # coloured front panel


def cross_plate(b, cx, cy, z0, z1, arm, thick, depth, colour=P.RED):
    """A plus sign on a wall/plate plane facing -Y: bar width `thick`, overall width `arm`."""
    zm = (z0 + z1) / 2
    b.box((cx - thick / 2, cy - depth, z0), (cx + thick / 2, cy, z1), colour, bevel=0.02)
    b.box((cx - arm / 2, cy - depth, zm - thick / 2), (cx + arm / 2, cy, zm + thick / 2), colour, bevel=0.02)


def medic_tile(b, x0, y0, x1, y1, cx, cy, skip=None):
    """Light-blue studded floor tile with a flat red cross at (cx, cy); no studs on the cross or under `skip`."""
    z = INT + 0.08
    b.box((x0, y0, INT), (x1, y1, z), P.GLASS, bevel=0.02)
    b.box((cx - 0.4, cy - 1.3, z), (cx + 0.4, cy + 1.3, z + 0.03), P.RED, bevel=0.0)
    b.box((cx - 1.3, cy - 0.4, z), (cx + 1.3, cy + 0.4, z + 0.03), P.RED, bevel=0.0)
    step = 1.8
    nx, ny = max(1, round((x1 - x0 - 0.6) / step)), max(1, round((y1 - y0 - 0.6) / step))
    for ix in range(nx):
        for iy in range(ny):
            x = x0 + 0.3 + (ix + 0.5) * (x1 - x0 - 0.6) / nx
            y = y0 + 0.3 + (iy + 0.5) * (y1 - y0 - 0.6) / ny
            if abs(x - cx) < 1.7 and abs(y - cy) < 1.7:
                continue
            if skip and skip[0] - 0.4 < x < skip[2] + 0.4 and skip[1] - 0.4 < y < skip[3] + 0.4:
                continue
            stud(b, x, y, z, P.GLASS, r=0.3)


# ------------------------------------------------------------------ Lv2 pavilion
def pavilion_base(b):
    wing_base(b, PAV_X0, PAV_X1, PAV_Y0, PAV_Y1, deck=P.LBG, avoid=[(x, y) for x in PAV_POST_X for y in PAV_POST_Y])
    b.box((PAV_FX0, PAV_FY0, DECK), (PAV_FX1, PAV_FY1, INT), P.WHITE, bevel=0.03)
    medic_tile(b, *PAV_TILE, MEDIC_SPOT[0], MEDIC_SPOT[1] + 0.2, skip=PAV_COUNTER)


def pavilion_frames(b):
    for x in PAV_POST_X:
        for y in PAV_POST_Y:
            b.box((x - 0.4, y - 0.4, DECK), (x + 0.4, y + 0.4, PAV_POST_TOP), P.WHITE, bevel=0.06)
            b.box((x - 0.58, y - 0.58, DECK), (x + 0.58, y + 0.58, DECK + 1.3), P.RED, bevel=0.06)       # red base
            b.cyl(x, y, PAV_POST_TOP - 0.32, PAV_POST_TOP, 0.72, P.LBG, 10)                              # round-plate cap


def pavilion_roof(b):
    w = (PAV_ROOF_X1 - PAV_ROOF_X0) / 11.0                                              # 4 red rows 2w, 3 white rows w
    x = PAV_ROOF_X0
    for k in range(7):                                                                   # red/white slope rows, as Lv3
        x1 = PAV_ROOF_X1 if k == 6 else x + (2 * w if k % 2 == 0 else w)
        b.prof_x(x, x1, [(PAV_EAVE_Y0, PAV_EAVE_Z), (PAV_EAVE_Y1, PAV_EAVE_Z), (PAV_RIDGE_Y, PAV_RIDGE_Z)],
                 P.RED if k % 2 == 0 else P.WHITE)
        x = x1
    b.box((PAV_ROOF_X0, PAV_RIDGE_Y - 0.5, PAV_RIDGE_Z), (PAV_ROOF_X1, PAV_RIDGE_Y + 0.5, PAV_RIDGE_Z + 0.26),
          P.WHITE, bevel=0.03)
    b.stud_row(PAV_ROOF_X0 + 0.8, PAV_RIDGE_Y, PAV_ROOF_X1 - 0.8, PAV_RIDGE_Y, PAV_RIDGE_Z + 0.26, P.WHITE,
               spacing=1.7, r=0.28, h=0.2, n=6)
    for y0, y1 in ((PAV_EAVE_Y0 - 0.2, PAV_EAVE_Y0 + 0.06), (PAV_EAVE_Y1 - 0.06, PAV_EAVE_Y1 + 0.2)):   # red eave fascias
        b.box((PAV_ROOF_X0 - 0.05, y0, PAV_EAVE_Z - 0.4), (PAV_ROOF_X1 + 0.05, y1, PAV_EAVE_Z + 0.2), P.RED, bevel=0.03)
    for x in (PAV_ROOF_X0 + 0.2, PAV_ROOF_X1 - 0.2):                                                      # red barge boards
        b.beam((x, PAV_EAVE_Y0, PAV_EAVE_Z), (x, PAV_RIDGE_Y, PAV_RIDGE_Z), 0.4, 0.5, P.RED)
        b.beam((x, PAV_RIDGE_Y, PAV_RIDGE_Z), (x, PAV_EAVE_Y1, PAV_EAVE_Z), 0.4, 0.5, P.RED)
    ridge_sign(b, -28.1, PAV_RIDGE_Y, PAV_RIDGE_Z - 0.3, PAV_RIDGE_Z + 0.26)


def pavilion_beds(b):
    for cx in PAV_BED_X:
        bed(b, cx, PAV_BED_FOOT, PAV_BED_HEAD)
        iv_stand(b, ((cx + 1.45) if cx > -29.0 else (cx - 1.45)), PAV_BED_FOOT + 0.1)


def pavilion_counter(b):
    x0, y0, x1, y1 = PAV_COUNTER
    counter(b, x0, y0, x1, y1)
    b.box((-32.8, -7.7, COUNTER_TOP), (-31.2, -6.8, COUNTER_TOP + 0.95), P.WHITE, bevel=0.05)   # first-aid kit
    cross_plate(b, -32.0, -7.7, COUNTER_TOP + 0.25, COUNTER_TOP + 0.7, 0.55, 0.16, 0.05)
    for yy in (-8.0, -6.25):
        b.stud_row(-33.2, yy, -28.2, yy, COUNTER_TOP, P.TAN, spacing=1.25, r=0.3, h=0.2, n=6)
    b.box((-29.9, -7.35, COUNTER_TOP), (-28.8, -6.85, COUNTER_TOP + 0.07), P.WHITE, bevel=0.01)   # notes
    b.box((-29.85, -7.3, COUNTER_TOP + 0.07), (-29.45, -7.05, COUNTER_TOP + 0.1), P.DBG, bevel=0.01)


def pavilion_col(c):
    c.box((PAV_X0, PAV_Y0, 0.0), (PAV_X1, PAV_Y1, RIM), P.WHITE)
    for x in PAV_POST_X:
        for y in PAV_POST_Y:
            c.box((x - 0.4, y - 0.4, DECK), (x + 0.4, y + 0.4, PAV_POST_TOP), P.WHITE)
    for cx in PAV_BED_X:
        c.box((cx - BED_W / 2 - 0.05, PAV_BED_FOOT - 0.65, INT),
              (cx + BED_W / 2 + 0.05, PAV_BED_HEAD + 0.65, INT + 2.4), P.WHITE)
    c.box((PAV_COUNTER[0], PAV_COUNTER[1], INT), (PAV_COUNTER[2], PAV_COUNTER[3], COUNTER_TOP), P.WHITE)
    c.box((PAV_ROOF_X0, PAV_EAVE_Y0, PAV_EAVE_Z), (PAV_ROOF_X1, PAV_EAVE_Y1, PAV_RIDGE_Z + 0.5), P.WHITE)


# ------------------------------------------------------------------ Lv3 hospital wing
def hospital_base(b):
    wing_base(b, H_X0, H_X1, H_Y0, H_Y1, deck=P.LBG)
    wing_base(b, A_X0, A_X1, A_Y0, A_Y1, deck=P.LBG)
    b.box((H_FX0, H_FY0, DECK), (H_FX1, H_FY1, INT), P.WHITE, bevel=0.03)
    b.box((24.3, 3.5, INT), (29.5, 5.0, INT + 0.03), P.DBG, bevel=0.01)                  # door mat
    x0, y0, x1, y1 = H_TILE                                                              # medic work-zone floor tile
    medic_tile(b, x0, y0, x1, y1, QUEUE[0], (y0 + y1) / 2)


def window(b, cx, cy, w, z0, z1, axis, sign, frame=P.RED):
    """A red frame + glass pane 0.1 proud of a wall face (axis 'y' front/back, 'x' sides)."""
    t, d = 0.3, 0.1
    if axis == "y":
        lo, hi = sorted((cy, cy + sign * d))
        parts = ((cx - w / 2, lo, z0 - t, cx + w / 2, hi, z0), (cx - w / 2, lo, z1, cx + w / 2, hi, z1 + t),
                 (cx - w / 2, lo, z0, cx - w / 2 + t, hi, z1), (cx + w / 2 - t, lo, z0, cx + w / 2, hi, z1))
        glass = (cx - w / 2 + t, lo, z0, cx + w / 2 - t, hi, z1)
    else:
        lo, hi = sorted((cx, cx + sign * d))
        parts = ((lo, cy - w / 2, z0 - t, hi, cy + w / 2, z0), (lo, cy - w / 2, z1, hi, cy + w / 2, z1 + t),
                 (lo, cy - w / 2, z0, hi, cy - w / 2 + t, z1), (lo, cy + w / 2 - t, z0, hi, cy + w / 2, z1))
        glass = (lo, cy - w / 2 + t, z0, hi, cy + w / 2 - t, z1)
    for p in parts:
        b.box(p[:3], p[3:], frame, bevel=0.02)
    b.box(glass[:3], glass[3:], P.GLASS, bevel=0.01)


def wall_ring(b, za, zb, c, out=0.08):
    """A strip around the outside of the four hospital walls between z = za and zb (the front stops at the doorway)."""
    cut = za < DOOR_TOP + 0.3
    fronts = ((H_WX0 - out, DOOR_X0), (DOOR_X1, H_WX1 + out)) if cut else ((H_WX0 - out, H_WX1 + out),)
    for xa, xb in fronts:
        b.box((xa, H_WY0 - out, za), (xb, H_WY0, zb), c, bevel=0.0)
    b.box((H_WX0 - out, H_WY1, za), (H_WX1 + out, H_WY1 + out, zb), c, bevel=0.0)
    b.box((H_WX0 - out, H_WY0, za), (H_WX0, H_WY1, zb), c, bevel=0.0)
    b.box((H_WX1, H_WY0, za), (H_WX1 + out, H_WY1, zb), c, bevel=0.0)


def wall_joints(b, za, zb, off, step, c=P.LBG, out=0.04):
    """Vertical brick joints between za and zb on the outer faces, staggered by `off` (windows and frames hide some)."""
    n = int((H_WY1 - H_WY0) // step)
    for i in range(n + 1):
        y = H_WY0 + off + i * step
        if H_WY0 + 0.3 < y < H_WY1 - 0.3:
            b.box((H_WX0 - out, y - 0.05, za), (H_WX0, y + 0.05, zb), c, bevel=0.0)
            b.box((H_WX1, y - 0.05, za), (H_WX1 + out, y + 0.05, zb), c, bevel=0.0)
    for i in range(int((H_WX1 - H_WX0) // step) + 1):
        x = H_WX0 + off + i * step
        if H_WX0 + 0.3 < x < H_WX1 - 0.3:
            b.box((x - 0.05, H_WY1, za), (x + 0.05, H_WY1 + out, zb), c, bevel=0.0)
            if not DOOR_X0 - 0.4 < x < DOOR_X1 + 0.4 or za > DOOR_TOP:
                b.box((x - 0.05, H_WY0 - out, za), (x + 0.05, H_WY0, zb), c, bevel=0.0)


def hospital_walls(b):
    z0, z1 = INT, H_EAVE
    b.box((H_WX0, H_WY0, z0), (DOOR_X0, H_WY0 + WALL, z1), P.WHITE, bevel=0.05)
    b.box((DOOR_X1, H_WY0, z0), (H_WX1, H_WY0 + WALL, z1), P.WHITE, bevel=0.05)
    b.box((DOOR_X0, H_WY0, DOOR_TOP), (DOOR_X1, H_WY0 + WALL, z1), P.WHITE, bevel=0.05)
    b.box((H_WX0, H_WY1 - WALL, z0), (H_WX1, H_WY1, z1), P.WHITE, bevel=0.05)
    b.box((H_WX0, H_WY0 + WALL, z0), (H_WX0 + WALL, H_WY1 - WALL, z1), P.WHITE, bevel=0.05)
    b.box((H_WX1 - WALL, H_WY0 + WALL, z0), (H_WX1, H_WY1 - WALL, z1), P.WHITE, bevel=0.05)
    for za in (2.0, 5.4, 6.6, 7.8):                                                      # plate / brick course seams
        wall_ring(b, za, za + 0.1, P.LBG, out=0.04)
    wall_joints(b, z0, 2.0, 0.0, 3.4)
    wall_joints(b, BAND1, 5.4, 1.7, 3.4)
    wall_joints(b, 5.4, 6.6, 0.0, 3.4)
    wall_joints(b, 6.6, 7.8, 1.7, 3.4)
    wall_joints(b, 7.8, 8.55, 0.0, 3.4)
    wall_ring(b, BAND0, BAND1, P.RED)                                                    # mid-height red band
    wall_ring(b, 8.55, z1, P.RED)                                                        # red eave band
    b.box((23.6, H_WY0 - 0.08, z0), (DOOR_X0, H_WY0, DOOR_TOP), P.RED, bevel=0.03)       # door frame
    b.box((DOOR_X1, H_WY0 - 0.08, z0), (30.2, H_WY0, DOOR_TOP), P.RED, bevel=0.03)
    b.box((23.6, H_WY0 - 0.08, DOOR_TOP), (30.2, H_WY0, DOOR_TOP + 0.3), P.RED, bevel=0.03)
    wz0, wz1 = 4.9, 7.4
    window(b, 22.75, H_WY0, 1.5, wz0, wz1, "y", -1)
    window(b, 32.55, H_WY0, 3.2, wz0, wz1, "y", -1)
    window(b, 28.4, H_WY1, 3.2, wz0, wz1, "y", 1)
    for wy in (7.3, 14.2):
        window(b, H_WX0, wy, 3.2, wz0, wz1, "x", -1)
        window(b, H_WX1, wy, 3.2, wz0, wz1, "x", 1)


def hospital_roof(b):
    x0, z0, x1, z1, xr, zr = H_ROOF
    y, k = 1.4, 0
    while y < 20.6 - 1e-6:                                                               # red roof with white stripes
        y1 = min(20.6, y + (3.2 if k % 2 == 0 else 1.6))
        prism_y(b, y, y1, [(x0, z0), (x1, z1), (xr, zr)], P.RED if k % 2 == 0 else P.WHITE)
        y, k = y1, k + 1
    prism_y(b, 1.3, 1.4, [(x0 + 0.5, z0 + 0.25), (x1 - 0.5, z0 + 0.25), (xr, zr - 0.35)], P.WHITE)   # white gable plate
    for xs in ((x0 - 0.3, x0 + 0.3), (x1 - 0.3, x1 + 0.3)):
        b.box((xs[0], 1.4, H_EAVE - 0.25), (xs[1], 20.6, H_EAVE + 0.15), P.WHITE, bevel=0.02)
    b.box((H_RIDGE_X - 0.5, 1.4, H_RIDGE), (H_RIDGE_X + 0.5, 20.6, H_RIDGE + 0.25), P.WHITE, bevel=0.03)
    b.stud_row(H_RIDGE_X, 2.2, H_RIDGE_X, 19.8, H_RIDGE + 0.25, P.WHITE, spacing=1.7, r=0.28, h=0.2, n=6)
    b.box((27.4, 1.2, 9.5), (29.4, 1.3, 12.0), P.RED, bevel=0.02)                       # facade cross, facing the approach
    b.box((26.6, 1.2, 10.15), (30.2, 1.3, 11.25), P.RED, bevel=0.02)
    ridge_sign(b, H_RIDGE_X, 10.0, H_RIDGE - 0.6, H_RIDGE + 0.25)


def hospital_beds(b):
    for cx in H_BED_X:
        for foot in H_BED_FOOT:
            bed(b, cx, foot, foot + H_BED_LEN)
            iv_stand(b, cx + 1.45 if cx < 28.0 else cx - 1.45, foot + 0.1)


def hospital_desk(b):
    x0, y0, x1, y1 = H_DESK
    counter(b, x0, y0, x1, y1, top=3.4, accent=P.GREEN)
    b.studs(x0 + 0.4, 29.0, y0 + 0.2, y0 + 1.0, 3.4, P.TAN, step=1.0, r=0.3, h=0.2, n=6)
    b.box((26.0, y1 - 0.5, 5.0), (30.8, y1 + 0.1, 7.0), P.WHITE, bevel=0.05)             # wall cabinet
    cross_plate(b, 28.4, y1 - 0.5, 5.35, 6.65, 1.5, 0.42, 0.06)
    b.box((27.8, y1 - 1.3, 3.4), (29.0, y1 - 0.8, 3.9), P.DBG, bevel=0.03)               # monitor foot
    b.box((26.9, y1 - 1.1, 3.9), (29.9, y1 - 0.75, 5.5), P.DBG, bevel=0.04)              # monitor frame
    b.box((27.1, y1 - 1.16, 4.1), (29.7, y1 - 1.1, 5.3), P.CYAN, bevel=0.01)             # screen
    b.box((27.3, y1 - 1.18, 4.25), (28.7, y1 - 1.16, 4.45), P.GREEN, bevel=0.0)          # screen bar
    b.box((27.3, y0 + 0.9, 3.4), (29.3, y0 + 1.4, 3.5), P.DBG, bevel=0.01)               # keyboard
    b.box((29.7, y0 + 0.25, 3.4), (30.8, y0 + 0.9, 3.5), P.DBG, bevel=0.01)              # instrument tray
    b.box((29.9, y0 + 0.4, 3.5), (30.3, y0 + 0.75, 3.75), P.WHITE, bevel=0.03)
    b.box((30.4, y0 + 0.4, 3.5), (30.65, y0 + 0.75, 3.7), P.CYAN, bevel=0.02)


def hospital_col(c):
    c.box((H_X0, H_Y0, 0.0), (H_X1, H_Y1, RIM), P.LBG)
    c.box((A_X0, A_Y0, 0.0), (A_X1, A_Y1, RIM), P.LBG)
    c.box((H_WX0, H_WY0, INT), (DOOR_X0, H_WY0 + WALL, H_EAVE), P.WHITE)
    c.box((DOOR_X1, H_WY0, INT), (H_WX1, H_WY0 + WALL, H_EAVE), P.WHITE)
    c.box((DOOR_X0, H_WY0, DOOR_TOP), (DOOR_X1, H_WY0 + WALL, H_EAVE), P.WHITE)
    c.box((H_WX0, H_WY1 - WALL, INT), (H_WX1, H_WY1, H_EAVE), P.WHITE)
    c.box((H_WX0, H_WY0 + WALL, INT), (H_WX0 + WALL, H_WY1 - WALL, H_EAVE), P.WHITE)
    c.box((H_WX1 - WALL, H_WY0 + WALL, INT), (H_WX1, H_WY1 - WALL, H_EAVE), P.WHITE)
    c.box((20.2, 1.4, H_EAVE), (36.6, 20.6, H_RIDGE + 0.5), P.WHITE)
    for cx in H_BED_X:
        for foot in H_BED_FOOT:
            c.box((cx - BED_W / 2 - 0.05, foot - 0.65, INT),
                  (cx + BED_W / 2 + 0.05, foot + H_BED_LEN + 0.65, INT + 2.4), P.WHITE)
    c.box((H_DESK[0], H_DESK[1], INT), (H_DESK[2], H_DESK[3], 3.4), P.WHITE)
    c.box((VAN_X0, VAN_Y0 + AMB_DY, 1.8), (VAN_X1, VAN_Y1 + AMB_DY, VAN_TOP), P.WHITE)


# ------------------------------------------------------------------ Lv3 ambulance
def ambulance(b):
    z = DECK
    x0, x1, y0, y1 = VAN_X0, VAN_X1, VAN_Y0, VAN_Y1
    cx, hood_y, cab_y = (x0 + x1) / 2, -10.2, -8.4
    b.box((x0 + 0.3, y0 + 0.2, z + 0.8), (x1 - 0.3, y1 - 0.2, z + 1.5), P.DBG, bevel=0.04)
    b.box((x0, y0, z + 1.5), (x1, hood_y, z + 3.4), P.WHITE, bevel=0.2)                  # hood, cab, box: three chunky bricks
    b.box((x0, hood_y, z + 1.5), (x1, cab_y, z + 5.4), P.WHITE, bevel=0.2)
    b.box((x0, cab_y, z + 1.5), (x1, y1, z + 6.8), P.WHITE, bevel=0.2)
    b.box((x0 + 0.5, hood_y - 0.07, z + 3.6), (x1 - 0.5, hood_y, z + 5.1), P.GLASS, bevel=0.04)   # windscreen
    b.box((x0 - 0.12, y0 - 0.15, z + 0.85), (x1 + 0.12, y0 + 0.1, z + 1.5), P.DBG, bevel=0.04)     # bumpers
    b.box((x0 - 0.12, y1 - 0.1, z + 0.85), (x1 + 0.12, y1 + 0.15, z + 1.5), P.DBG, bevel=0.04)
    for hx in (x0 + 0.5, x1 - 1.4):
        b.box((hx, y0 - 0.09, z + 1.7), (hx + 0.9, y0 + 0.02, z + 2.3), P.YELLOW, bevel=0.03)      # headlights
    b.box((x0, y0 - 0.09, z + 2.6), (x1, y0 + 0.02, z + 3.1), P.RED, bevel=0.02)                   # nose stripe
    for xa, xb in ((x0 - 0.1, x0), (x1, x1 + 0.1)):
        b.box((xa, y0 + 0.15, z + 2.2), (xb, y1 - 0.2, z + 2.9), P.RED, bevel=0.02)                # side stripe
        b.box((xa, -5.8, z + 4.45), (xb, -2.8, z + 5.35), P.RED, bevel=0.02)                       # side cross
        b.box((xa, -4.75, z + 3.5), (xb, -3.85, z + 6.3), P.RED, bevel=0.02)
        b.box((xa - 0.04 if xa < cx else xa, -9.9, z + 3.6), (xb if xa < cx else xb + 0.04, -8.7, z + 5.1), P.GLASS,
              bevel=0.03)                                                                          # cab side window
    # open rear: dark bay, red stretcher half out, two doors swung open towards the hospital doorway
    b.box((x0 + 0.4, y1, z + 1.9), (x1 - 0.4, y1 + 0.06, z + 6.2), P.DBG, bevel=0.02)
    b.box((cx - 1.2, y1 + 0.06, z + 2.1), (cx + 1.2, y1 + 0.8, z + 2.35), P.LBG, bevel=0.02)
    b.box((cx - 1.1, y1 + 0.06, z + 2.35), (cx + 1.1, y1 + 0.8, z + 2.75), P.RED, bevel=0.04)
    door = lego.B()
    door.box((0.0, -0.15, z + 1.9), (2.8, 0.15, z + 6.2), P.WHITE, bevel=0.04)
    door.box((0.4, -0.18, z + 3.8), (2.4, 0.18, z + 5.6), P.GLASS, bevel=0.02)
    door.box((0.0, -0.18, z + 2.2), (2.8, 0.18, z + 2.9), P.RED, bevel=0.02)
    place_rot(b, door, x0, y1, 0.0, math.radians(150))
    mirror = lego.B()
    mirror.v = [(-x, y, zz) for x, y, zz in door.v]
    mirror.f = [(tuple(reversed(f)), c) for f, c in door.f]
    place_rot(b, mirror, x1, y1, 0.0, math.radians(-150))
    # roof: light bar (flat red + blue), studs on every flat roof
    b.box((cx - 1.9, -6.7, z + 6.8), (cx + 1.9, -5.3, z + 7.1), P.DBG, bevel=0.03)
    b.box((cx - 1.8, -6.6, z + 7.1), (cx - 0.05, -5.4, z + 7.7), P.RED, bevel=0.05)
    b.box((cx + 0.05, -6.6, z + 7.1), (cx + 1.8, -5.4, z + 7.7), P.BLUE, bevel=0.05)
    b.studs(x0 + 0.5, x1 - 0.5, -4.6, y1 - 0.4, z + 6.8, P.WHITE, step=1.6, r=0.4, h=0.2, n=6)
    b.studs(x0 + 0.7, x1 - 0.7, -10.0, -8.6, z + 5.4, P.WHITE, step=1.6, r=0.4, h=0.2, n=6)
    b.studs(x0 + 0.6, x1 - 0.6, -12.0, -10.4, z + 3.4, P.WHITE, step=1.6, r=0.4, h=0.2, n=6)
    for s_, wx in ((-1, x0 + 0.35), (1, x1 - 0.35)):                                       # big wheels, studded hubs
        for wy in (-10.6, -3.2):
            out = wx + s_ * 0.55
            b.cyl_x(wx, wy, z + 1.7, 1.7, 1.1, P.BLACK, 12)
            b.cyl_x(out + s_ * 0.07, wy, z + 1.7, 1.0, 0.14, P.LBG, 12)
            b.cyl_x(out + s_ * 0.2, wy, z + 1.7, 0.45, 0.32, P.LBG, 8)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_Clinic_Brick", ALB)
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
        print("[clinic] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    pavilion_base(b)
    out("Lv2_L01_Base", b, "Lv2")

    b = lego.B()
    pavilion_frames(b)
    out("Lv2_L02_Frames", b, "Lv2")

    b = lego.B()
    pavilion_roof(b)
    out("Lv2_L03_Roof", b, "Lv2")

    b = lego.B()
    pavilion_beds(b)
    out("Lv2_L04_Beds", b, "Lv2")

    b = lego.B()
    pavilion_counter(b)
    out("Lv2_L05_Counter", b, "Lv2")

    c = lego.B()
    pavilion_col(c)
    out_cols("Lv2", c)

    b = lego.B()
    hospital_base(b)
    out("Lv3_L01_Base", b, "Lv3")

    b = lego.B()
    hospital_walls(b)
    out("Lv3_L02_Walls", b, "Lv3")

    b = lego.B()
    hospital_roof(b)
    out("Lv3_L03_Roof", b, "Lv3")

    b = lego.B()
    hospital_beds(b)
    out("Lv3_L04_Beds", b, "Lv3")

    b = lego.B()
    hospital_desk(b)
    out("Lv3_L05_Desk", b, "Lv3")

    a = lego.B()
    ambulance(a)
    b = lego.B()
    place_rot(b, a, 0.0, AMB_DY, 0.0, 0.0)
    out("Lv3_L06_Ambulance", b, "Lv3")

    c = lego.B()
    hospital_col(c)
    out_cols("Lv3", c)

    atts = [lego.attach("ATT_Work_Bed%d" % (i + 1), (PAV_BED_X[i], PAV_BED_FOOT - 1.0, INT)) for i in range(3)]
    atts.append(lego.attach("ATT_Work_MedicCounter", (MEDIC_SPOT[0], MEDIC_SPOT[1], INT)))
    n = 4
    for cx in H_BED_X:
        for foot in H_BED_FOOT:
            atts.append(lego.attach("ATT_Work_Bed%d" % n, (cx, foot - 1.0, INT)))
            n += 1
    atts.append(lego.attach("ATT_Work_Desk", (QUEUE[0], QUEUE[1], INT)))
    atts.append(lego.attach("ATT_Park_Ambulance", ((VAN_X0 + VAN_X1) / 2, -5.9 + AMB_DY, DECK)))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[clinic] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[clinic] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, on the lawn each side of the code clinic's 39.44 x 31.44 stud plinth (top z 0.92); "
                     "the Lv2 pavilion pad is x -35.6..-20.6, the Lv3 hospital and ambulance bay x 20.6..36.2 / "
                     "28.4..35.2, y -19.1..20.1; front -Y, origin the clinic ground centre, built at the clinic's final "
                     "1.15 scale (place with no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 B/J): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., Lv3_Col01_COL..; the FBX "
                      "importer flattens empty parents, so the node name is the mesh name prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "pavilion", "target": [-28.1, -1.5, 5.5], "dist": 30, "az": 25, "el": 14},
            {"name": "hospital", "target": [28.2, 9.5, 5.0], "dist": 35, "az": 30, "el": 14},
            {"name": "hospital_door", "target": [26.9, 4.0, 4.0], "dist": 17, "az": -35, "el": 8},
            {"name": "ambulance", "target": [31.8, -11.4, 4.0], "dist": 26, "az": 50, "el": 12},
        ],
    }
