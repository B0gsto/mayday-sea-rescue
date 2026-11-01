"""M_Bld_HQAddons: the HQ's Lv3 station shell, Lv4 radio wing and Lv5 gold beacon tower, Lego style (docs/25 A/B/J; docs/05 2.2, 3, 4, 5).

Lv3 (PERF-HQ 2026-11-01): the station shell (walls, roof, entrance bay, door; see the Lv3 section below) that
replaces the code-built `station()` walls in src/shared/DockPieces.luau when the mesh loads. Lv4/Lv5 add-ons at the
station's final frame: 54 x 32 stud lot, ground at z 0, plinth top 0.5, walls x +/-26 / y +/-15, roof
eave 16 and ridge 25, front -Y, origin the HQ ground centre, 1x (place at the HQ frame with no extra scale).

Lv4 (docs/25 A: "+ radio mast wing"): a walk-in two-storey radio hall built against the station's east wall (the
parapet stays under the station eave, z 16), red and white courses on a tan stud plinth, a navy roof with a white
parapet, a red cap with studs, a door with a navy frame, big front / east / back windows on both storeys, a white
signal plaque and a yellow lifebuoy on the front. Inside (double height): a long white desk with three big dark radio
sets (glass screens, red/green buttons), a big chart board with a cyan sea, tan islands, a red route and yellow pins,
a shelf of binders and two warm ceiling lamps. A red/white lattice mast rises from a white pad on the roof. The floor
stays clear.

Lv5 (docs/25 A: "+ gold beacon tower"): a red/white beacon tower standing east of the wing on its own stud base,
joined to it by a raised bridge (a tan deck resting on the wing's parapet cap, a navy girder with knee braces, Lego
fence panels each side, a step plate on the wing roof) into a second-floor door; two stages (10 + 7 courses, red
bands every fourth course) to 38.6, a red-framed door, a 7 x 10 stud shield crest (gold anchor on navy, red border)
facing the approach, a wide studded balcony with real fence panels (posts, red top rail), and a glazed gold lantern
room: a light-blue pane in every bay up to a gold top rail, an open band above the panes where the lamp head shows,
a trimmed gold eave, a tight red stepped roof and a gold finial. The lamp is a separate mesh (Lv5_L05_Beacon, an
8-sided lens drum with a gold band) so the game can light it. Inside: a ground floor with a notice board and a
second floor (the bridge's landing); the floors stay clear.

Each level is a top-level node (Lv4, Lv5) holding 6 construction layers (L01_* bottom to L06_* top), one palette
mesh per layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). Collision is one simple box per
object, <Node>_ColNN_COL (Roblox hulls each mesh, so a merged proxy would fill the doorway): walls in bites around
the doors, the plinths, floors, roof, desk, mast, balcony, fence, lantern and crest, so the doorways and interiors
stay walkable.

    python3 art/source/buildings/M_Bld_HQAddons/maketex.py \
        --out build/prod/M_Bld_HQAddons/textures/M_Bld_HQAddons --name HQAddons --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_HQAddons/build.py \
        --out-root build/prod/M_Bld_HQAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_HQAddons"
BUDGET = "hero_building"   # the Lv3 station shell joined (PERF-HQ): 40k class, one flat palette set (waived)
TIER = "standard"
SET_NAME, SET = "HQAddons", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_HQAddons_Brick_ALB.png")

# --- Lv4 wing (two storeys, parapet cap under the station eave at z 16)
FLOOR = 0.6
FLOOR_TOP = 0.72
WALL = 0.6
WALL_TOP = 14.55
COURSES = 12
COURSE = (WALL_TOP - FLOOR) / COURSES
WEST_END = 26.4
WX0, WX1 = 26.8, 43.2
WY0, WY1 = -3.0, 9.0
PL_X0, PL_X1 = 26.4, 44.0
PL_Y0, PL_Y1 = -3.8, 9.8
DOOR_X0, DOOR_X1 = 30.4, 36.4
DOOR_TOP = FLOOR + 6 * COURSE
ROOF_X0, ROOF_X1 = 26.4, 43.7
ROOF_Y0, ROOF_Y1 = -3.3, 9.3
ROOF_TOP = 15.05
PAR_TOP = 15.5
CAP_TOP = 15.62
MAST_X, MAST_Y = 36.0, 4.2
PAD_TOP = 15.4
MAST_TOP = 44.0     # PERF-HQ r2: 1.5x taller lattice mast
RX0, RX1, RY0, RY1 = 28.8, 33.6, 0.4, 8.4   # r3: upper radio room on the wing roof (west of the mast)
R_C = 1.25
RZ1 = ROOF_TOP + 4 * R_C
# r4: walk-in front block in front of the radio wing (its back meets the wing front at y -3, the wing door is the link)
F_X0, F_XW, F_XI, F_XE, F_X1 = 26.9, 27.6, 28.4, 42.6, 43.2   # west face (low / above the hall roof corner), inner
F_Y0, F_YI, F_YB, F_YBI = -15.4, -14.8, -3.45, -4.05            # front face, inner; upper back wall
F_N, F_C = 15, 1.16
F_TOP = FLOOR + F_N * F_C                                       # 18.0: roof deck, chequer parapet to 19.65
F_DX0, F_DX1 = 32.2, 38.6
F_DTOP = FLOOR + 7 * F_C

# --- Lv5 tower (east of the wing, on the same base; walkway between the two plinths)
T_FLOOR = 0.6
T_FLOOR_TOP = 0.72
T_WALL = 0.6
TCX, TCY = 55.0, 3.0
TX0, TX1 = 50.9, 59.1
TY0, TY1 = -1.1, 7.1
QX0, QX1 = 49.0, 61.0
QY0, QY1 = -3.0, 9.0
S1_N, S1_C = 10, 2.2
S1_TOP = T_FLOOR + S1_N * S1_C
F2 = T_FLOOR + 7 * S1_C
LEDGE_TOP = S1_TOP + 0.6
UX0, UX1 = 51.5, 58.5
UY0, UY1 = -0.5, 6.5
U_N, U_C = 7, 2.2
T_TOP = LEDGE_TOP + U_N * U_C
T_DOOR_X0, T_DOOR_X1 = 52.9, 57.1
T_DOOR_TOP = T_FLOOR + 3 * S1_C
W_DY0, W_DY1 = 0.9, 5.1
BX0, BX1 = 49.3, 60.7
BY0, BY1 = -2.7, 8.7
B_Z0, B_Z1 = T_TOP, T_TOP + 0.6
FX0, FX1 = 49.5, 60.5
FY0, FY1 = -2.5, 8.5
RAIL_TOP = B_Z1 + 2.6
LAN_CX, LAN_CY = TCX, TCY
LAN_HALF = 3.5
LAN_Z0, LAN_Z1 = B_Z1 + 0.9, B_Z1 + 6.6
PANE_TOP = LAN_Z1 - 2.0
LAMP_Z0 = LAN_Z0 + 1.0
CREST_Z1, CREST_W, CREST_H = 19.6, 7.0, 10.0
BR_X0, BR_X1 = ROOF_X1 - 0.6, TX0
BR_Y0, BR_Y1 = 0.4, 5.6
BR_Z0, BR_Z1 = CAP_TOP, F2
# Lv5 outside stair to the wing roof: straight up the front of the wing / tower gap (+Y) to a landing level with
# the wing's east parapet cap, beside the bridge (the bridge and its knee braces fill the gap behind it)
ST_X0, ST_X1 = 43.8, 50.0
ST_N = 15
ST_RISE = CAP_TOP / ST_N
ST_RUN = 1.1
LAND_Y0, LAND_Y1 = ROOF_Y0, BR_Y0
ST_Y0 = LAND_Y0 - (ST_N - 1) * ST_RUN
FH = 2.2
RF_W, RF_F, RF_B, RF_E = 27.85, -3.0, 9.05, 43.45


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def patch_lod_targets():
    """LODs keep the large_prop shares (50% / 25%) the add-ons shipped with: the hero_building LOD2 ceiling (3000 for
    the asset) cannot be reached by the small Lv4/Lv5 detail meshes (session-only patch, like patch_lod_names)."""
    import budgets
    orig = getattr(budgets, "_hq_orig_lod_target", budgets.lod_target)
    budgets._hq_orig_lod_target = orig
    budgets.lod_target = lambda budget_class, lod, lod0_tris, asset_tris=None: int(
        orig("large_prop", lod, lod0_tris) * (LOD1_K[0] if lod == "LOD1" else 1.0))


LOD1_CAP = 14600     # r5: hero_building LOD1 ceiling 15k with a margin; build() scales the LOD1 share to fit
LOD1_K = [1.0]


def studs_on(b, x0, x1, y0, y1, z, c, step=2.2, r=0.5, h=0.26, skip=(), n=6):
    nx = max(1, int(round((x1 - x0) / step)))
    ny = max(1, int(round((y1 - y0) / step)))
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    for ix in range(nx):
        for iy in range(ny):
            x, y = x0 + (ix + 0.5) * dx, y0 + (iy + 0.5) * dy
            if any(sx0 - r < x < sx1 + r and sy0 - r < y < sy1 + r for sx0, sy0, sx1, sy1 in skip):
                continue
            b.cyl(x, y, z, z + h, r, c, n, bot=False)  # studs sit on a surface: no hidden bottom


def fence_x(b, x0, x1, y, z0, step, post=0.36, h=2.2):
    """Lego fence panel along X at plane y: white posts and a red top rail."""
    n = max(1, int(round((x1 - x0) / step)))
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        b.box((x - post / 2, y - post / 2, z0), (x + post / 2, y + post / 2, z0 + h), P.WHITE, bevel=0.03)
    b.box((x0 - 0.2, y - 0.3, z0 + h), (x1 + 0.2, y + 0.3, z0 + h + 0.4), P.RED, bevel=0.03)
    b.box((x0, y - 0.12, z0 + h * 0.45), (x1, y + 0.12, z0 + h * 0.45 + 0.25), P.WHITE, bevel=0.02)


def fence_y(b, y0, y1, x, z0, step, post=0.36, h=2.2):
    n = max(1, int(round((y1 - y0) / step)))
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        b.box((x - post / 2, y - post / 2, z0), (x + post / 2, y + post / 2, z0 + h), P.WHITE, bevel=0.03)
    b.box((x - 0.3, y0 - 0.2, z0 + h), (x + 0.3, y1 + 0.2, z0 + h + 0.4), P.RED, bevel=0.03)
    b.box((x - 0.12, y0, z0 + h * 0.45), (x + 0.12, y1, z0 + h * 0.45 + 0.25), P.WHITE, bevel=0.02)


def win_inset(b, along, a0, a1, z0, z1, face, d, bar=True, fw=0.35, cross=False):
    """PERF-HQ Lv4/Lv5 window on a solid wall facing d: a navy frame fw wide 0.35 proud, the glass 0.05 proud (0.3
    behind the frame), a white mullion (+ a transom when cross: the hall look), a red sill brick 0.5 proud, 2 studs."""
    ws = wall_side(along, d)
    bx(b, along, a0 + fw - 0.05, a1 - fw + 0.05, face, face + d * 0.05, z0 + fw - 0.05, z1 - fw + 0.05, P.GLASS,
       bevel=0.01, skip=(ws,))
    for za, zb in ((z0, z0 + fw), (z1 - fw, z1)):
        bx(b, along, a0, a1, face, face + d * fw, za, zb, P.INK, bevel=0.04, skip=(ws,))
    for aa, ab in ((a0, a0 + fw), (a1 - fw, a1)):
        bx(b, along, aa, ab, face, face + d * fw, z0 + fw, z1 - fw, P.INK, bevel=0.04, skip=(ws, "z0", "z1"))
    if bar:
        m = (a0 + a1) / 2
        bx(b, along, m - 0.1, m + 0.1, face, face + d * 0.15, z0 + fw, z1 - fw, P.WHITE, bevel=0.02,
           skip=(ws, "z0", "z1"))
    if cross:
        zm = (z0 + z1) / 2
        bx(b, along, a0 + fw, a1 - fw, face, face + d * 0.12, zm - 0.12, zm + 0.12, P.WHITE, bevel=0.02,
           skip=(ws, "x0", "x1") if along == "x" else (ws, "y0", "y1"))
    bx(b, along, a0 - 0.25, a1 + 0.25, face, face + d * 0.5, z0 - 0.4, z0 + 0.05, P.RED, bevel=0.04, skip=(ws,))
    n = face + d * 0.3
    for t in (0.25, 0.75):
        a = a0 + (a1 - a0) * t
        x, y = (a, n) if along == "x" else (n, a)
        b.cyl(x, y, z0 + 0.05, z0 + 0.25, 0.26 if cross else 0.2, P.RED, 6, bot=False)


def portal(b, x0, x1, y, ztop, z0, w=0.8, dep=0.45):
    """PERF-HQ: a chunky deep-red door portal on a -Y wall face y: jambs w wide, a lintel 0.9 tall, a red keystone."""
    for a, c in ((x0 - w, x0), (x1, x1 + w)):
        b.box((a, y - dep, z0), (c, y, ztop), P.DEEPRED, bevel=0.05, skip=("z0", "z1", "y1"))
    b.box((x0 - w - 0.2, y - dep - 0.1, ztop), (x1 + w + 0.2, y, ztop + 0.9), P.DEEPRED, bevel=0.06, skip=("y1",))
    m = (x0 + x1) / 2
    b.box((m - 0.5, y - dep - 0.2, ztop - 0.15), (m + 0.5, y - dep - 0.1, ztop + 0.95), P.RED, bevel=0.04)


def leaf(b, hx, hy, s, W, z0, z1, ang):
    """r4: a red Lego door leaf hinged at (hx, hy) on the s side of its opening, swung ang degrees outward (-Y): the
    inside face (white rails, Z-braces, plank seams, gold handle) turns to the path, all of it outside the opening."""
    t, T = lego.B(), 0.4
    t.box((0.0, -T, z0), (W, 0.0, z1), P.RED, bevel=0.05)
    for u in (W / 4, W / 2, 3 * W / 4):
        t.box((u - 0.05, 0.0, z0 + 0.2), (u + 0.05, 0.04, z1 - 0.2), P.INK, bevel=0.0, skip=("y0",))
    rz = (z0 + 0.45, (z0 + z1) / 2 - 0.3, z1 - 1.05)
    for z in rz:
        t.box((0.2, 0.0, z), (W - 0.2, 0.15, z + 0.6), P.WHITE, bevel=0.04, skip=("y0",))
    for za, zb in zip(rz, rz[1:]):
        t.beam((W - 0.5, 0.12, za + 0.6), (0.5, 0.12, zb), 0.22, 0.5, P.WHITE)
    t.box((W - 0.7, 0.0, (z0 + z1) / 2 + 0.4), (W - 0.4, 0.22, (z0 + z1) / 2 + 0.8), P.GOLD, bevel=0.02, skip=("y0",))
    a = math.radians(ang)
    d, n = (-s * math.cos(a), -math.sin(a)), (-s * math.sin(a), math.cos(a))
    base = len(b.v)
    b.v.extend((hx + u * d[0] + w * n[0], hy + u * d[1] + w * n[1], z) for u, w, z in t.v)
    b.f.extend((tuple(base + i for i in f), c) for f, c in t.f)


def ring_studs(b, cx, cy, h, z, c, step=1.1, r=0.2):
    """A square ring of studs at half size h (roof step ledges)."""
    n = max(1, int(round(2 * h / step)))
    pts = [(-h + 2 * h * i / n, s * h) for i in range(n + 1) for s in (-1, 1)]
    pts += [(s * h, -h + 2 * h * i / n) for i in range(1, n) for s in (-1, 1)]
    for dx, dy in pts:
        b.cyl(cx + dx, cy + dy, z, z + 0.2, r, c, 6, bot=False)


def ridge_cap(b, along, a0, a1, c, zb, wide, th=0.5, seg=2.2, stud_r=0.42, skip=(), ends=(True, True)):
    """r5: a 1-stud stepped Lego ridge cap: 2-stud white segments (a wide tier, a narrower tier on it, one red stud)
    with 0.05 seams, red end caps at the ridge ends; segments in skip ranges (a0, a1) are left out."""
    n = max(1, int(round((a1 - a0) / seg)))
    L = (a1 - a0) / n
    h, hn = wide / 2, wide / 2 - 0.35
    for i in range(n):
        s0, s1 = a0 + i * L + (0.025 if i else 0.0), a0 + (i + 1) * L - (0.025 if i + 1 < n else 0.0)
        if any(k0 < (s0 + s1) / 2 < k1 for k0, k1 in skip):
            continue
        bx(b, along, s0, s1, c - h, c + h, zb, zb + th, P.WHITE, bevel=0.06, skip=("z0",))
        bx(b, along, s0 + 0.1, s1 - 0.1, c - hn, c + hn, zb + th, zb + 2 * th, P.WHITE, bevel=0.06, skip=("z0",))
        m = (s0 + s1) / 2
        x, y = (m, c) if along == "x" else (c, m)
        b.cyl(x, y, zb + 2 * th, zb + 2 * th + 0.28, stud_r, P.RED, 6, bot=False)
    for e, (a, d) in zip(ends, ((a0, -1), (a1, 1))):
        if e:
            lo, hi = sorted((a - d * 0.3, a + d * 0.25))
            bx(b, along, lo, hi, c - h - 0.1, c + h + 0.1, zb - 0.05, zb + 2 * th + 0.1, P.RED, bevel=0.06)


def seams(b, along, a0, a1, face, d, zs, keep_out=(), head=3.0, c=P.LBG):
    """r5: brick-course seams on a white wall run: a grey mortar line 0.04 proud on every course line and staggered
    head joints every `head` studs (open strips: the front and two edge faces, 6 tris), clear of keep_out rects
    (a0, a1, z0, z1)."""
    f0, f1 = sorted((face, face + d * 0.04))
    sides = ("x0", "x1") if along == "x" else ("y0", "y1")
    keep_h = (wall_side(along, -d), "z0", "z1")      # horizontal line: front + top + bottom
    keep_v = (wall_side(along, -d),) + sides         # head joint: front + both ends
    sk_h = tuple(k for k in ("z0", "z1", "y0", "y1", "x0", "x1") if k not in keep_h)
    sk_v = tuple(k for k in ("z0", "z1", "y0", "y1", "x0", "x1") if k not in keep_v)

    def clear(p0, p1, z0, z1, mn=0.3):
        segs = [(p0, p1)]
        for k0, k1, kz0, kz1 in keep_out:
            if kz0 < z1 and kz1 > z0:
                segs = [s for q0, q1 in segs for s in ((q0, min(q1, k0)), (max(q0, k1), q1)) if s[1] - s[0] > mn]
        return segs
    for z in zs[1:-1]:
        for p0, p1 in clear(a0, a1, z - 0.04, z + 0.04):
            bx(b, along, p0, p1, f0, f1, z - 0.04, z + 0.04, c, bevel=0.0, skip=sk_h)
    for k, (z0, z1) in enumerate(zip(zs, zs[1:])):
        a = a0 + (head / 2 if k % 2 else head)
        while a < a1 - 0.5:
            if clear(a - 0.04, a + 0.04, z0 + 0.04, z1 - 0.04, 0.01) == [(a - 0.04, a + 0.04)]:
                bx(b, along, a - 0.04, a + 0.04, f0, f1, z0 + 0.04, z1 - 0.04, c, bevel=0.0, skip=sk_v)
            a += head


def lifeboat(b, cx):
    """r5 Lv3 cue: an orange Lego lifeboat (white gunwale band, navy hull stripe, small cabin) on a grey wheeled
    launch trolley in front of the hall front at x cx, bow to the path (-Y), wheels on the ground."""
    # trolley: two rails, cross beams, axles, black wheels with grey hubs, chocks, a tow bar
    for s in (-1, 1):
        b.box((cx + s * 0.85 - 0.15, -23.0, 0.65), (cx + s * 0.85 + 0.15, -17.2, 1.05), P.LBG, bevel=0.04)
    for y in (-17.6, -20.1, -22.6):
        b.box((cx - 0.7, y - 0.15, 0.8), (cx + 0.7, y + 0.15, 1.0), P.LBG, bevel=0.0, skip=("x0", "x1"))
    for y in (-18.2, -22.0):
        b.box((cx - 1.1, y - 0.12, 0.43), (cx + 1.1, y + 0.12, 0.67), P.DBG, bevel=0.0)
        for s in (-1, 1):
            b.cyl_x(cx + s * 1.25, y, 0.56, 0.55, 0.45, P.BLACK, n=10)
            b.cyl_x(cx + s * 1.25, y, 0.56, 0.28, 0.55, P.LBG, n=6)
    for y0 in (-18.9, -21.8):
        for s in (-1, 1):
            lo, hi = sorted((cx + s * 0.55, cx + s * 1.05))
            b.box((lo, y0, 1.05), (hi, y0 + 0.5, 1.26), P.LBG, bevel=0.03, skip=("z0",))
    b.beam((cx, -23.0, 0.85), (cx, -24.0, 0.55), 0.3, 0.3, P.DBG)
    b.cyl(cx, -24.05, 0.4, 0.75, 0.22, P.DBG, 6)

    # hull: plan outlines lofted up (transom at the wall end, a raked bow); bands orange / navy / orange / white
    zs = (1.3, 1.65, 1.95, 2.4, 2.75)
    ws = (0.95, 1.12, 1.22, 1.3, 1.33)
    bows = (-22.7, -23.05, -23.25, -23.4, -23.45)
    rings = []
    for z, w, yb in zip(zs, ws, bows):
        rings.append([(cx - w, -16.6, z), (cx + w, -16.6, z), (cx + w, -20.6, z), (cx + 0.72 * w, -22.3, z),
                      (cx, yb, z), (cx - 0.72 * w, -22.3, z), (cx - w, -20.6, z)])
    base, n = len(b.v), len(rings[0])
    for r in rings:
        b.v.extend(r)
    for k, c in enumerate((P.ORANGE, P.INK, P.ORANGE, P.WHITE)):
        for i in range(n):
            j = (i + 1) % n
            b.f.append(((base + k * n + i, base + k * n + j, base + (k + 1) * n + j, base + (k + 1) * n + i), c))
    b.f.append((tuple(base + i for i in reversed(range(n))), P.ORANGE))
    b.f.append((tuple(base + (len(rings) - 1) * n + i for i in range(n)), P.WHITE))
    # cabin: orange with a navy window band, white roof plate with two studs; a gold beacon light
    zd = zs[-1]
    b.box((cx - 0.8, -20.4, zd), (cx + 0.8, -17.4, zd + 1.0), P.ORANGE, bevel=0.05, skip=("z0",))
    b.box((cx - 0.84, -20.1, zd + 0.45), (cx + 0.84, -17.7, zd + 0.8), P.INK, bevel=0.0, skip=("z0", "z1"))
    b.box((cx - 0.6, -20.44, zd + 0.45), (cx + 0.6, -20.4, zd + 0.8), P.INK, bevel=0.0, skip=("y1",))
    b.box((cx - 0.95, -20.6, zd + 1.0), (cx + 0.95, -17.25, zd + 1.25), P.WHITE, bevel=0.04)
    for y in (-19.6, -18.1):
        b.cyl(cx, y, zd + 1.25, zd + 1.48, 0.3, P.WHITE, 6, bot=False)
    b.cyl(cx, -18.85, zd + 1.25, zd + 1.6, 0.18, P.GOLD, 6, bot=False)
    # white bow fender
    b.box((cx - 0.3, -23.5, 2.05), (cx + 0.3, -23.2, 2.4), P.WHITE, bevel=0.03)


# ------------------------------------------------------------------ Lv3 lifeboat station shell (PERF-HQ)
# The code station() refined (DockPieces.luau): white brick walls x +/-26, y +/-15 (0.8 thick, inner faces 25.6 /
# 14.6), red base course, grey stud plinth, white eave course 15..16, blue stepped-tile gable roof (ridge along X,
# eave 16, ridge 25) with a studded white ridge cap. New, facing the path (-Y): a projecting entrance bay with a
# crow-stepped white cross gable over the eave line (red copings, a lifebuoy roundel, a short flag mast), the big
# deep-red door portal (10 x 9 opening, leaves standing open inside the bay) and a framed plaque for the code sign.
# Nothing inside the interior volume (|x| < 25.6, |y| < 14.6) below z 16 (M_Prop_HQInterior lives there).
S_X, S_XE, S_Y = 26.4, 26.35, 15.4     # outer faces (-X / +X end: the Lv4 wing butts on at 26.4 / front-back)
S_IX, S_IY = 25.6, 14.6               # inner faces
S_ZS = (0.5, 2.1, 3.3, 4.5, 5.75, 7.0, 8.25, 9.5, 10.6, 11.7, 12.8, 13.9, 15.0)   # course lines (windows 4.5..9.5)
S_EAVE = 16.0
S_WING = (-3.8, 9.8)                  # +X end: the Lv4 wing + plinth stand here, nothing proud of the wall
WIN_FRONT, WIN_END, WIN_BACK = (-9, -15, -21), (-8, 0, 8), (-18, -9, 0, 9, 18)
WIN_FRONT_SOLID = (9, 15, 21)          # r2: mirror windows on the solid +X front half (no hole: interior wall stays)
BAY_X, BAY_IN, BAY_Y0, BAY_Y1 = 6.7, 6.1, -20.0, -19.4   # entrance bay outer / inner half width, front wall
DOOR_X = 5.0
SIGN_AT = (0.0, -20.59, 12.5)         # ATT_Sign_03: the code's 12 x 3 x 0.4 sign (r5: z 12.2 -> 12.5, bigger plaque)
R_HW, R_N, R_RISE, R_L, R_DELTA = 16.5, 6, 1.5, 1.0, 0.4    # main roof: half span, courses, rise each, ledge, lap
X_HW, X_N, X_RISE, X_L = 7.6, 4, 1.75, 0.7                  # cross gable roof
X_Y0, X_Y1 = -19.95, -3.0                                   # cross courses: inside the stepped gable .. buried


def bx(b, along, a0, a1, n0, n1, z0, z1, c, bevel=0.05, skip=()):
    """A box on a wall running along 'x' (n = y) or 'y' (n = x)."""
    if along == "x":
        b.box((a0, n0, z0), (a1, n1, z1), c, bevel=bevel, skip=skip)
    else:
        b.box((n0, a0, z0), (n1, a1, z1), c, bevel=bevel, skip=skip)


def wall_side(along, d):
    """The face name toward the wall for a piece proud of a wall facing d."""
    return ("y1" if d < 0 else "y0") if along == "x" else ("x1" if d < 0 else "x0")


def courses(b, along, a0, a1, n0, n1, holes=()):
    """Brick courses (red first course) with through-holes (h0, h1, z0, z1) on course lines; a course top is dropped
    only where the next course covers it."""
    for k in range(len(S_ZS) - 1):
        z0, z1 = S_ZS[k], S_ZS[k + 1]
        here = [(h0, h1) for h0, h1, hz0, hz1 in holes if hz0 < z1 and hz1 > z0]
        nxt = [] if k + 2 >= len(S_ZS) else [(h0, h1) for h0, h1, hz0, hz1 in holes if hz0 <= z1 < hz1]
        segs = [(a0, a1)]
        for h0, h1 in here:
            segs = [s for p0, p1 in segs for s in ((p0, min(p1, h0)), (max(p0, h1), p1)) if s[1] - s[0] > 1e-6]
        for p0, p1 in segs:
            cuts = [p0] + sorted(v for h in nxt for v in h if p0 < v < p1) + [p1]
            for q0, q1 in zip(cuts, cuts[1:]):
                m = (q0 + q1) / 2
                sk = () if any(h0 < m < h1 for h0, h1 in nxt) else ("z1",)
                bx(b, along, q0, q1, n0, n1, z0, z1, P.RED if k == 0 else P.WHITE, skip=sk + (("z0",) if k == 0 else ()))


def window(b, along, a, face, d, proud=True, solid=False):
    """A window in a 4 x 5 through-hole (centre z 7): glass recessed 0.3 behind a proud navy frame, white cross bars,
    a red studded sill. proud=False (the +X end behind the Lv4 wing): glass 0.3 inside the hole, nothing proud."""
    ws = wall_side(along, d)
    if not proud:
        bx(b, along, a - 1.95, a + 1.95, face - d * 0.35, face - d * 0.3, 4.55, 9.45, P.GLASS, bevel=0.01)
        return
    o = d * 0.1 if solid else 0.0   # solid wall: the pane sits on the face, 0.2 behind the proud frame
    bx(b, along, a - 1.95, a + 1.95, face - d * 0.1 + o, face - d * 0.05 + o, 4.55, 9.45, P.GLASS, bevel=0.01,
       skip=(ws,) if solid else ())
    bx(b, along, a - 0.12, a + 0.12, face - d * 0.02 + o, face + d * 0.08 + o, 4.9, 9.1, P.WHITE, bevel=0.02)
    bx(b, along, a - 1.6, a + 1.6, face + o, face + d * 0.12 + o, 6.88, 7.12, P.WHITE, bevel=0.02)
    for z0, z1 in ((9.1, 9.7), (4.3, 4.9)):
        bx(b, along, a - 2.2, a + 2.2, face, face + d * 0.25, z0, z1, P.INK, bevel=0.04, skip=(ws,))
    for s in (-1, 1):
        bx(b, along, a + s * 1.6, a + s * 2.2, face, face + d * 0.25, 4.9, 9.1, P.INK, bevel=0.04,
           skip=(ws, "z0", "z1"))
    bx(b, along, a - 2.25, a + 2.25, face, face + d * 0.5, 3.85, 4.25, P.RED, bevel=0.04, skip=(ws,))
    for s in (-1, 1):
        n = face + d * 0.25
        x, y = (a + s * 1.1, n) if along == "x" else (n, a + s * 1.1)
        b.cyl(x, y, 4.25, 4.45, 0.26, P.RED, 6, bot=False)


def roof_courses(b, x0, x1, hw, n, rise, ledge, top_flat, zbot0, zbot_step, col, delta=R_DELTA):
    """A stepped-tile gable along X (ridge on y = 0): per side n-1 slope courses (fascia, slope, a flat ledge for a
    stud row, lapping delta under the next course) and one top course over the ridge. Courses step 0.05 in length
    and zbot_step in their bottoms so no two faces share a plane."""
    r = hw / n
    for k in range(n):
        zb, zt = S_EAVE + k * rise, S_EAVE + (k + 1) * rise
        zbot = zbot0 + zbot_step * k
        e = 0.05 * k
        yo = hw - k * r
        if k < n - 1:
            yi = yo - r
            for s in (-1, 1):
                prof = [(s * yo, zbot), (s * yo, zb + 0.3), (s * (yi + ledge), zt), (s * (yi - delta), zt),
                        (s * (yi - delta), zbot)]
                b.prof_x(x0 + e, x1 - e, prof, col)
        else:
            b.prof_x(x0 + e, x1 - e, [(yo, zbot), (yo, zb + 0.3), (top_flat, zt), (-top_flat, zt), (-yo, zb + 0.3),
                                      (-yo, zbot)], col)


def merge_swapped(b, t):
    """Append builder t with x and y swapped (a gable along Y built with the along-X helpers)."""
    base = len(b.v)
    b.v.extend((y, x, z) for x, y, z in t.v)
    b.f.extend((tuple(base + i for i in f), c) for f, c in t.f)


def station_base(b):
    b.box((-28.0, -17.0, 0.0), (28.0, 17.0, 0.5), P.LBG, bevel=0.06, skip=("z0",))
    b.box((-8.5, -22.0, 0.0), (8.5, -17.0, 0.5), P.LBG, bevel=0.06, skip=("z0", "y1"))
    kw = dict(step=2.2, r=0.45, h=0.26)
    for x0, x1 in ((-27.4, -7.6), (7.6, 27.4)):
        studs_on(b, x0, x1, -16.6, -16.1, 0.5, P.LBG, **kw)
    studs_on(b, -27.4, 27.4, 16.1, 16.6, 0.5, P.LBG, **kw)
    studs_on(b, -27.6, -27.1, -16.4, 16.4, 0.5, P.LBG, **kw)
    for y0, y1 in ((-16.4, -4.4), (10.4, 16.4)):
        studs_on(b, 27.1, 27.6, y0, y1, 0.5, P.LBG, **kw)
    for s in (-1, 1):
        studs_on(b, min(s * 5.6, s * 8.1), max(s * 5.6, s * 8.1), -21.7, -21.2, 0.5, P.LBG, **kw)
        studs_on(b, min(s * 7.5, s * 8.0), max(s * 7.5, s * 8.0), -20.6, -17.2, 0.5, P.LBG, **kw)


def station_walls(b):
    win = lambda cs: [(c - 2.0, c + 2.0, 4.5, 9.5) for c in cs]
    courses(b, "x", -S_X, S_X, -S_Y, -S_IY, [(-BAY_IN, BAY_IN, 0.5, 9.5)] + win(WIN_FRONT))
    courses(b, "x", -S_X, S_X, S_IY, S_Y, win(WIN_BACK))
    courses(b, "y", -S_IY, S_IY, -S_X, -S_IX, win(WIN_END))
    courses(b, "y", -S_IY, S_IY, S_IX, S_XE, win(WIN_END))
    # r5: brick-course seams between the red pilasters (keep-outs: windows + sills, pilasters, the bay, the Lv4 wing)
    zs, top = S_ZS[1:], 99.0
    win = lambda cs: [(c - 2.3, c + 2.3, 3.8, 9.75) for c in cs]
    pil = lambda cs: [(c - 0.65, c + 0.65, 0.0, top) for c in cs]
    seams(b, "x", -25.15, 25.15, -S_Y, -1, zs, [(-6.75, 6.75, 0.0, top)] + win(WIN_FRONT + WIN_FRONT_SOLID)
          + pil((-18, -12, 12, 18)))
    seams(b, "x", -25.15, 25.15, S_Y, 1, zs, win(WIN_BACK) + pil((-13.5, -4.5, 4.5, 13.5)))
    seams(b, "y", -14.9, 14.9, -S_X, -1, zs, win(WIN_END) + pil((-4, 4)))
    seams(b, "y", -14.9, 14.9, S_XE, 1, zs, win(WIN_END) + pil((-11.5, 12.0)) + [(-3.85, 9.85, 0.0, top)])
    # entrance bay: front wall with the 10-wide door, two side walls back to the station front
    courses(b, "x", -BAY_X, BAY_X, BAY_Y0, BAY_Y1, [(-DOOR_X, DOOR_X, 0.5, 9.5)])
    for s in (-1, 1):
        courses(b, "y", BAY_Y1, -S_Y, min(s * BAY_IN, s * BAY_X), max(s * BAY_IN, s * BAY_X))
    # white eave course 15..16, 0.2 proud (flush on the +X end where the Lv4 wing sits)
    for s in (-1, 1):
        b.box((-26.6, min(s * 15.6, s * S_IY), 15.0), (26.6, max(s * 15.6, s * S_IY), 16.0), P.WHITE, bevel=0.05)
    b.box((-26.6, -S_IY, 15.0), (-S_IX, S_IY, 16.0), P.WHITE, bevel=0.05)
    for y0, y1, x1 in ((-S_IY, S_WING[0], 26.6), (S_WING[0], S_WING[1], S_XE), (S_WING[1], S_IY, 26.6)):
        b.box((S_IX, y0, 15.0), (x1, y1, 16.0), P.WHITE, bevel=0.05)
    b.box((-6.9, -20.2, 15.0), (6.9, BAY_Y1, 16.0), P.WHITE, bevel=0.05)
    for s in (-1, 1):
        b.box((min(s * BAY_IN, s * 6.9), BAY_Y1, 15.0), (max(s * BAY_IN, s * 6.9), -15.6, 16.0), P.WHITE, bevel=0.05)


def station_trim(b):
    # red base course strip 0.3 proud (gaps: the bay, the Lv4 wing end)
    for x0, x1 in ((-26.7, -BAY_X), (BAY_X, 26.7)):
        b.box((x0, -15.7, 0.5), (x1, -S_Y, 2.1), P.RED, bevel=0.05, skip=("z0",))
    b.box((-26.7, S_Y, 0.5), (26.7, 15.7, 2.1), P.RED, bevel=0.05, skip=("z0",))
    b.box((-26.7, -S_Y, 0.5), (-S_X, S_Y, 2.1), P.RED, bevel=0.05, skip=("z0",))
    for y0, y1 in ((-S_Y, S_WING[0]), (S_WING[1], S_Y)):
        b.box((S_XE, y0, 0.5), (S_XE + 0.3, y1, 2.1), P.RED, bevel=0.05, skip=("z0",))
    for s in (-1, 1):
        b.box((min(s * 5.6, s * 7.0), -20.3, 0.5), (max(s * 5.6, s * 7.0), BAY_Y0, 2.1), P.RED, bevel=0.05, skip=("z0",))
        b.box((min(s * BAY_X, s * 7.0), BAY_Y0, 0.5), (max(s * BAY_X, s * 7.0), -15.7, 2.1), P.RED, bevel=0.05,
              skip=("z0",))
    for x in WIN_FRONT:
        window(b, "x", x, -S_Y, -1)
    for x in WIN_FRONT_SOLID:
        window(b, "x", x, -S_Y, -1, solid=True)
    # r2: red 1x2 brick pilasters (one brick per two courses): the four corners, the front between window groups,
    # the ends between windows (+X: clear of the Lv4 wing at y -3.8..9.8)
    zs = S_ZS[:-1:2] + (14.95,)
    def pilaster(lo, hi):
        for k in range(len(zs) - 1):
            b.box((lo[0], lo[1], zs[k]), (hi[0], hi[1], zs[k + 1]), P.RED, bevel=0.05,
                  skip=(("z0",) if k == 0 else ()) + (("z1",) if k + 2 < len(zs) else ()))
    for sx in (-1, 1):
        for sy in (-1, 1):
            pilaster((sx * 25.2, sy * 14.95), (sx * 26.85, sy * 15.85))
        for x in (12, 18):
            pilaster((sx * x - 0.6, -15.85), (sx * x + 0.6, -S_Y))
        pilaster((-26.85, sx * 4 - 0.6), (-S_X, sx * 4 + 0.6))
        for x in (4.5, 13.5):   # r3: the long back wall between its windows
            pilaster((sx * x - 0.6, S_Y), (sx * x + 0.6, 15.85))
    for y in (-11.5, 12.0):
        pilaster((S_XE, y - 0.6), (26.8, y + 0.6))
    for x in WIN_BACK:
        window(b, "x", x, S_Y, 1)
    for y in WIN_END:
        window(b, "y", y, -S_X, -1)
        window(b, "y", y, S_XE, 1, proud=not (S_WING[0] - 2.5 < y < S_WING[1] + 2.5))


def station_front(b):
    y0 = BAY_Y0
    # the big door: deep red portal round the 10 x 9 opening, a grey ledge, the framed plaque for the code sign
    for s in (-1, 1):
        b.box((min(s * DOOR_X, s * 6.3), y0 - 0.45, 0.5), (max(s * DOOR_X, s * 6.3), y0, 9.0), P.DEEPRED, bevel=0.06,
              skip=("y1", "z0", "z1"))
    b.box((-6.3, y0 - 0.45, 9.0), (6.3, y0, 10.2), P.DEEPRED, bevel=0.06, skip=("y1", "z1"))
    b.box((-DOOR_X, y0, 9.0), (DOOR_X, BAY_Y1, 9.5), P.DEEPRED, bevel=0.02, skip=("y0", "z1"))
    # r5: the plaque fits the code's 12 x 3 sign (centred on ATT_Sign_03, back 0.04 off the navy board) in a chunky
    # 0.5 red rim, 0.6 proud, on a wider grey ledge
    b.box((-6.85, y0 - 0.75, 10.2), (6.85, y0, 10.45), P.LBG, bevel=0.04, skip=("y1",))
    b.box((-6.15, y0 - 0.35, 10.95), (6.15, y0, 14.05), P.INK, bevel=0.0, skip=("y1", "z0", "z1"))
    b.box((-6.65, y0 - 0.6, 10.45), (6.65, y0, 10.95), P.RED, bevel=0.05, skip=("y1", "z0"))
    b.box((-6.65, y0 - 0.6, 14.05), (6.65, y0, 14.6), P.RED, bevel=0.05, skip=("y1",))
    for s in (-1, 1):
        b.box((min(s * 6.15, s * 6.65), y0 - 0.6, 10.95), (max(s * 6.15, s * 6.65), y0, 14.05), P.RED, bevel=0.05,
              skip=("y1", "z0", "z1"))
    for x in (-4.4, 0.0, 4.4):
        b.cyl(x, y0 - 0.3, 14.6, 14.84, 0.32, P.RED, 6, bot=False)
    # r5: big red boathouse doors swung out 90 deg (square to the facade, clear of the front windows, outside the
    # 10-wide opening, no collision)
    for s in (-1, 1):
        leaf(b, s * (DOOR_X + 0.3), y0 - 0.55, s, 5.0, 0.55, 8.9, 90)
    lifeboat(b, -12.0)   # r5: the L3 lifeboat cue west of the bay, clear of the door path and the floodlights
    # crow-stepped white cross gable over the eave line, red copings, a lifebuoy roundel, a short flag mast
    r = X_HW / X_N
    w = [X_HW - j * r + 0.2 for j in range(X_N)]
    t = [S_EAVE + X_RISE * (j + 1) + 0.45 for j in range(X_N)]
    prof = [(-w[0], 15.5), (w[0], 15.5)]
    for j in range(X_N):
        prof += [(w[j], t[j])] + ([(w[j + 1], t[j])] if j + 1 < X_N else [])
    prof += [(-x, z) for x, z in reversed(prof[2:])]
    g = lego.B()
    g.prof_x(y0 - 0.05, BAY_Y1 + 0.05, [(x, z) for x, z in prof], P.WHITE)
    merge_swapped(b, g)
    for j in range(X_N):
        if j + 1 < X_N:
            for s in (-1, 1):
                lo, hi = sorted((s * (w[j + 1] + 0.05), s * (w[j] + 0.15)))
                b.box((lo, y0 - 0.2, t[j]), (hi, BAY_Y1 + 0.15, t[j] + 0.4), P.RED, bevel=0.05, skip=("z0",))
                b.cyl(s * (w[j + 1] + w[j]) / 2, (y0 + BAY_Y1) / 2, t[j] + 0.4, t[j] + 0.62, 0.3, P.RED, 6, bot=False)
        else:
            b.box((-w[j] - 0.15, y0 - 0.2, t[j]), (w[j] + 0.15, BAY_Y1 + 0.15, t[j] + 0.4), P.RED, bevel=0.05,
                  skip=("z0",))
    # r4: red kneeler corbels under the gable's overhang past the bay walls (the jagged step beside the plaque)
    for s in (-1, 1):
        lo, hi = sorted((s * 6.75, s * (w[0] + 0.15)))
        b.box((lo, y0 - 0.2, 14.9), (hi, BAY_Y1 + 0.15, 15.5), P.RED, bevel=0.05, skip=("z1",))
    cz = 19.6
    b.ring_y(0.0, y0 - 0.55, cz, 1.5, 0.45, P.RED, maj=12, mnr=4)
    for a in (45, 135, 225, 315):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        b.box((1.5 * ca - 0.32, y0 - 1.06, cz + 1.5 * sa - 0.32), (1.5 * ca + 0.32, y0 - 0.1, cz + 1.5 * sa + 0.32),
              P.WHITE, bevel=0.03)
    mz = t[-1] + 0.4
    my = (y0 + BAY_Y1) / 2
    b.box((-0.45, my - 0.45, mz), (0.45, my + 0.45, mz + 0.5), P.WHITE, bevel=0.06, skip=("z0",))
    b.cyl(0.0, my, mz + 0.5, mz + 7.0, 0.25, P.INK, 6, bot=False)
    b.cyl(0.0, my, mz + 7.0, mz + 7.5, 0.42, P.GOLD, 6)
    b.box((0.25, my - 0.08, mz + 4.4), (4.4, my + 0.08, mz + 6.9), P.RED, bevel=0.02)
    b.box((0.35, my - 0.12, mz + 5.4), (4.3, my + 0.12, mz + 5.9), P.WHITE, bevel=0.0)
    # the cross gable roof: stepped blue tiles along Y, a white ridge cap, tan.. blue stud rows on the ledges
    c = lego.B()
    roof_courses(c, X_Y0, X_Y1, X_HW, X_N, X_RISE, X_L, 0.9, 16.1, 0.1, P.BLUE, delta=0.3)
    merge_swapped(b, c)
    # r4: the cross ridge cap matches the main one (wider, red studs) and dies into the main roof's top course, so it
    # reads as a ridge, not a white rod lying on the roof
    ridge_cap(b, "y", BAY_Y1 + 0.1, -2.3, 0.0, t[-1] - 0.45, 2.0, th=0.48, stud_r=0.38, ends=(True, False))  # r5
    for k in range(X_N - 1):
        zt = S_EAVE + X_RISE * (k + 1)
        y_end = -(R_HW - (zt - S_EAVE) * R_HW / (R_N * R_RISE)) - 0.8
        xi = X_HW - r * (k + 1) + X_L / 2
        for s in (-1, 1):
            studs_on(b, s * xi - 0.3, s * xi + 0.3, -19.0, y_end, zt, P.BLUE, step=2.2, r=0.38, h=0.28)


def station_roof(b):
    roof_courses(b, -27.5, 27.5, R_HW, R_N, R_RISE, R_L, 1.4, 16.05, 0.1, P.BLUE)
    r = R_HW / R_N
    for k in range(R_N - 1):
        zt = S_EAVE + R_RISE * (k + 1)
        y = R_HW - r * (k + 1) + R_L / 2
        for s in (-1, 1):
            skip = ((-8.4, -99, 8.4, 99),) if s < 0 and k < R_N - 2 else ()
            studs_on(b, -27.2 + 0.05 * k, 27.2 - 0.05 * k, s * y - 0.3, s * y + 0.3, zt, P.BLUE, step=2.2, r=0.46,
                     h=0.3, skip=skip)   # r4: 1.3x studs
    ztop = S_EAVE + R_RISE * R_N
    # r5: stepped 2-stud ridge segments, red end caps at the gable ends and against the cupola
    for a0, a1 in ((-28.0, 5.65), (10.35, 28.0)):
        ridge_cap(b, "x", a0, a1, 0.0, ztop, 2.6, th=0.6)
    # r2: lookout cupola on the ridge (x 5.7..10.3): white base, red sill, white posts, light-blue glass, red stepped
    # roof with a stud ring, gold spike and red ball finial (r3, top 35.9, over L2's mast)
    cx, h = 8.0, 2.3
    b.box((cx - h, -h, 23.6), (cx + h, h, 26.8), P.WHITE, bevel=0.06, skip=("z0",))
    b.box((cx - h - 0.2, -h - 0.2, 26.8), (cx + h + 0.2, h + 0.2, 27.2), P.RED, bevel=0.05)
    b.box((cx - 1.9, -1.9, 27.2), (cx + 1.9, 1.9, 30.0), P.GLASS, bevel=0.0, skip=("z0", "z1"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            lo, hi = sorted((sx * (h - 0.1), sx * (h - 0.7))), sorted((sy * (h - 0.1), sy * (h - 0.7)))
            b.box((cx + lo[0], hi[0], 27.2), (cx + lo[1], hi[1], 30.0), P.WHITE, bevel=0.04, skip=("z0", "z1"))
        b.box((cx - 0.1, sx * 1.85 - 0.08, 27.2), (cx + 0.1, sx * 1.85 + 0.08, 30.0), P.WHITE, bevel=0.0, skip=("z0", "z1"))
        b.box((cx + sx * 1.85 - 0.08, -0.1, 27.2), (cx + sx * 1.85 + 0.08, 0.1, 30.0), P.WHITE, bevel=0.0, skip=("z0", "z1"))
    b.box((cx - 2.6, -2.6, 30.0), (cx + 2.6, 2.6, 30.5), P.RED, bevel=0.06)
    ring_studs(b, cx, 0.0, 2.35, 30.5, P.RED, step=1.2)
    for k, hw in enumerate((2.1, 1.6, 1.1, 0.6)):
        b.box((cx - hw, -hw, 30.5 + 0.6 * k), (cx + hw, hw, 31.1 + 0.6 * k), P.RED, bevel=0.05, skip=("z0",))
    # r3: a red ball finial on a short gold spike (the r2 weathervane read as a church cross)
    b.cyl(cx, 0.0, 32.9, 34.75, 0.16, P.GOLD, 6, bot=False)
    b.cyl(cx, 0.0, 33.0, 33.4, 0.4, P.GOLD, 8)
    b.cyl(cx, 0.0, 34.6, 34.85, 0.38, P.RED, 8, top=False)
    b.cyl(cx, 0.0, 34.85, 35.65, 0.6, P.RED, 8)
    b.cyl(cx, 0.0, 35.65, 35.9, 0.38, P.RED, 8, bot=False)
    # dark-blue eave fascia along both long sides
    b.box((-27.6, 16.3, 15.75), (27.6, 16.75, 16.45), P.INK, bevel=0.04)
    for x0, x1 in ((-27.6, -6.95), (6.95, 27.6)):
        b.box((x0, -16.75, 15.75), (x1, -16.3, 16.45), P.INK, bevel=0.04)


def station_col(c):
    for lo, hi in (((-28.0, -17.0, 0.0), (28.0, 17.0, 0.5)), ((-8.5, -22.0, 0.0), (8.5, -17.0, 0.5)),
                   ((-S_X, -S_Y, 0.5), (-BAY_IN, -S_IY, S_EAVE)), ((BAY_IN, -S_Y, 0.5), (S_X, -S_IY, S_EAVE)),
                   ((-BAY_IN, -S_Y, 9.5), (BAY_IN, -S_IY, S_EAVE)), ((-S_X, S_IY, 0.5), (S_X, S_Y, S_EAVE)),
                   ((-S_X, -S_IY, 0.5), (-S_IX, S_IY, S_EAVE)), ((S_IX, -S_IY, 0.5), (S_XE, S_IY, S_EAVE)),
                   ((-BAY_X, BAY_Y0 - 0.45, 0.5), (-DOOR_X, BAY_Y1, S_EAVE)),
                   ((DOOR_X, BAY_Y0 - 0.45, 0.5), (BAY_X, BAY_Y1, S_EAVE)),
                   ((-DOOR_X, BAY_Y0 - 0.45, 9.0), (DOOR_X, BAY_Y1, S_EAVE)),
                   ((-BAY_X, BAY_Y1, 0.5), (-BAY_IN, -S_Y, S_EAVE)), ((BAY_IN, BAY_Y1, 0.5), (BAY_X, -S_Y, S_EAVE)),
                   ((-27.5, -16.5, S_EAVE), (27.5, 16.5, 25.0)), ((-7.8, -20.2, S_EAVE), (7.8, -S_Y, 23.5)),
                   ((-13.4, -24.1, 0.0), (-10.6, -17.0, 2.75))):   # r5: the lifeboat trolley
        c.box(lo, hi, bevel=0.0)


# ------------------------------------------------------------------ Lv4 radio wing
def wing_base(b):
    b.box((PL_X0, PL_Y0, 0.0), (PL_X1, PL_Y1, FLOOR), P.TAN, bevel=0.06)
    b.box((WEST_END, -2.4, FLOOR), (WX1, 8.4, FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((DOOR_X0, WY0, FLOOR), (DOOR_X1, -2.4, FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((30.6, -4.6, 0.0), (36.2, PL_Y0, 0.3), P.TAN, bevel=0.04)
    for x in (31.8, 33.4, 35.0):
        b.cyl(x, -4.2, 0.3, 0.5, 0.4, P.TAN, 6)
    studs_on(b, 26.7, 43.7, -3.7, -3.1, FLOOR, P.TAN, step=2.6, skip=((DOOR_X0 - 0.8, -3.8, DOOR_X1 + 0.8, -3.0),))
    studs_on(b, 26.7, 43.7, 9.1, 9.7, FLOOR, P.TAN, step=2.6)
    studs_on(b, 43.35, 43.9, -2.6, 9.0, FLOOR, P.TAN, step=2.6)


def wing_walls(b):
    yf0, yf1 = WY0, WY0 + WALL
    yb0, yb1 = WY1 - WALL, WY1
    # hidden faces trimmed: every course top lies under the next course or the roof, the first course on the plinth
    for k in range(COURSES):
        z = FLOOR + k * COURSE
        col = P.RED if k in (0, 4, 8) else P.WHITE
        sk = ("z0", "z1") if k == 0 else ("z1",)
        b.box((WEST_END, yf0, z), (DOOR_X0, yf1, z + COURSE), col, bevel=0.05, skip=sk)
        b.box((DOOR_X1, yf0, z), (WX1, yf1, z + COURSE), col, bevel=0.05, skip=sk)
        if k >= 6:
            b.box((DOOR_X0, yf0, z), (DOOR_X1, yf1, z + COURSE), col, bevel=0.05, skip=("z1",))
        b.box((WEST_END, yb0, z), (WX1, yb1, z + COURSE), col, bevel=0.05, skip=sk)
        b.box((WX0, yf1, z), (WX0 + WALL, yb0, z + COURSE), col, bevel=0.05, skip=sk)
        b.box((WX1 - WALL, yf1, z), (WX1, yb0, z + COURSE), col, bevel=0.05, skip=sk)
    for x0, y0 in ((WX0 - 0.06, yf0 - 0.06), (WX0 - 0.06, yb1 - 0.49),
                   (WX1 - 0.49, yf0 - 0.06), (WX1 - 0.49, yb1 - 0.49)):
        b.box((x0, y0, FLOOR), (x0 + 0.55, y0 + 0.55, WALL_TOP), P.RED, bevel=0.03, skip=("z0", "z1"))


def wing_trim(b):
    # PERF-HQ: deep-red door portal, a framed plaque proud on a grey ledge above it (the signal icon on it)
    portal(b, DOOR_X0, DOOR_X1, WY0, DOOR_TOP, FLOOR)
    b.box((31.0, WY0 - 0.75, DOOR_TOP + 0.85), (35.8, WY0, DOOR_TOP + 1.2), P.LBG, bevel=0.04, skip=("y1",))
    pz0, pz1 = DOOR_TOP + 1.2, DOOR_TOP + 3.25   # under the upper sills (11.1)
    b.box((31.2, WY0 - 0.45, pz0), (35.6, WY0, pz1), P.RED, bevel=0.05, skip=("y1", "z0"))
    b.box((31.55, WY0 - 0.55, pz0 + 0.35), (35.25, WY0 - 0.45, pz1 - 0.35), P.WHITE, bevel=0.02)

    win_inset(b, "x", 37.8, 42.2, 3.4, 6.8, WY0, -1)
    win_inset(b, "y", 0.8, 5.2, 3.4, 6.8, WX1, 1)
    for x0, x1 in ((27.9, 31.3), (33.5, 36.9), (39.1, 42.5)):
        win_inset(b, "x", x0, x1, 11.5, 13.95, WY0, -1)
        win_inset(b, "x", x0, x1, 11.5, 13.95, WY1, 1)
    win_inset(b, "y", 1.4, 4.6, 11.5, 13.95, WX1, 1)

    for z0 in (9.62, 14.27):
        b.box((WEST_END, -3.05, z0), (WX1, -3.0, z0 + 0.28), P.INK, bevel=0.01)
        b.box((WEST_END, 9.0, z0), (WX1, 9.05, z0 + 0.28), P.INK, bevel=0.01)
        b.box((WX1, -3.05, z0), (WX1 + 0.04, 9.05, z0 + 0.28), P.INK, bevel=0.01)

    yp = WY0 - 0.55
    b.box((32.0, yp - 0.12, pz0 + 0.6), (34.8, yp, pz1 - 0.6), P.INK, bevel=0.02)
    for i, x in enumerate((32.9, 33.5, 34.1)):
        b.box((x, yp - 0.18, pz0 + 0.75), (x + 0.3, yp - 0.12, pz0 + 1.0 + 0.18 * i), P.WHITE, bevel=0.0)
    b.box((32.3, yp - 0.18, pz0 + 0.75), (32.6, yp - 0.12, pz0 + 1.0), P.YELLOW, bevel=0.0)

    # r2: bold red/white block band on the front parapet edge (0.2 proud of the roof slab, under the red cap)
    xs = [ROOF_X0 + 0.1 + i * (ROOF_X1 - 0.2 - ROOF_X0) / 9 for i in range(10)]
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        b.box((x0, ROOF_Y0 - 0.2, 14.6), (x1, ROOF_Y0, 15.45), P.RED if i % 2 == 0 else P.WHITE, bevel=0.05,
              skip=("y1",))
    lx = 40.0
    b.ring_y(lx, -3.12, 8.4, 0.7, 0.22, P.YELLOW, maj=10, mnr=4)
    for dx, z0 in ((-0.2, 8.9), (-0.2, 7.5), (-0.8, 8.2), (0.4, 8.2)):
        b.box((lx + dx, -3.36, z0), (lx + dx + 0.4, -3.3, z0 + 0.4), P.WHITE, bevel=0.0)


def wing_interior(b):
    dx0, dx1 = 40.6, 42.5
    b.box((dx0, 0.2, 3.0), (dx1, 7.9, 3.3), P.WHITE, bevel=0.03)
    for x in (40.75, 42.35):
        for y in (0.35, 7.75):
            b.box((x - 0.15, y - 0.15, FLOOR_TOP), (x + 0.15, y + 0.15, 3.0), P.DBG, bevel=0.01)
    b.box((42.25, 0.4, FLOOR_TOP), (dx1, 7.7, 2.8), P.INK, bevel=0.02)
    for y0 in (0.45, 2.95, 5.45):
        b.box((40.9, y0, 3.3), (42.4, y0 + 2.2, 5.5), P.DBG, bevel=0.03)
        b.box((40.82, y0 + 0.1, 3.4), (40.9, y0 + 2.1, 5.4), P.BLACK, bevel=0.01)
        b.box((40.77, y0 + 0.35, 4.1), (40.82, y0 + 1.5, 5.25), P.GLASS, bevel=0.01)
        b.box((40.77, y0 + 1.65, 3.5), (40.82, y0 + 1.95, 3.9), P.RED, bevel=0.0)
        b.box((40.77, y0 + 1.65, 4.05), (40.82, y0 + 1.95, 4.45), P.GREEN, bevel=0.0)
        b.box((40.77, y0 + 0.3, 3.5), (40.82, y0 + 0.8, 3.95), P.LBG, bevel=0.0)

    x0, x1, z0, z1 = 29.8, 38.6, 3.8, 9.0
    W, H = x1 - x0 - 0.24, z1 - z0 - 0.24
    u = lambda f: x0 + 0.12 + f * W
    v = lambda f: z0 + 0.12 + f * H
    yb = WY1 - WALL
    b.box((x0, yb - 0.2, z0), (x1, yb, z1), P.INK, bevel=0.03)
    for xa, za, xb, zb in ((x0, z0, x1, z0 + 0.12), (x0, z1 - 0.12, x1, z1), (x0, z0, x0 + 0.12, z1), (x1 - 0.12, z0, x1, z1)):
        b.box((xa, yb - 0.28, za), (xb, yb - 0.2, zb), P.WHITE, bevel=0.0)
    b.box((u(0), yb - 0.24, v(0)), (u(1), yb - 0.2, v(1)), P.GLASS, bevel=0.0)
    for fx0, fz0, fx1, fz1 in ((0.10, 0.12, 0.35, 0.40), (0.50, 0.45, 0.68, 0.85), (0.72, 0.12, 0.92, 0.36)):
        b.box((u(fx0), yb - 0.28, v(fz0)), (u(fx1), yb - 0.24, v(fz1)), P.TAN, bevel=0.0)
    for f in (0.25, 0.5, 0.75):
        b.box((u(f), yb - 0.3, v(0)), (u(f) + 0.03, yb - 0.28, v(1)), P.WHITE, bevel=0.0)
    for f in (0.33, 0.66):
        b.box((u(0), yb - 0.3, v(f)), (u(1), yb - 0.28, v(f) + 0.03), P.WHITE, bevel=0.0)
    for fx, fz in ((0.14, 0.84), (0.31, 0.74), (0.48, 0.61)):
        b.box((u(fx), yb - 0.32, v(fz)), (u(fx) + 0.9, yb - 0.3, v(fz) + 0.14), P.RED, bevel=0.0)
    for fx, fz in ((0.18, 0.86), (0.4, 0.7), (0.58, 0.5)):
        b.box((u(fx), yb - 0.36, v(fz)), (u(fx) + 0.26, yb - 0.32, v(fz) + 0.26), P.YELLOW, bevel=0.0)

    b.box((42.0, 1.0, 8.4), (42.6, 7.4, 8.65), P.BROWN, bevel=0.02)
    for y0, col in ((1.8, P.RED), (3.4, P.INK), (5.0, P.YELLOW)):
        b.box((42.05, y0, 8.65), (42.55, y0 + 0.8, 9.8), col, bevel=0.02)

    for cx in (31.5, 38.0):
        b.box((cx - 0.7, 2.3, WALL_TOP - 0.1), (cx + 0.7, 3.7, WALL_TOP), P.INK, bevel=0.02)
        b.box((cx - 0.5, 2.5, WALL_TOP - 0.2), (cx + 0.5, 3.5, WALL_TOP - 0.1), P.WARM, bevel=0.01)


def wing_roof(b):
    b.box((ROOF_X0, ROOF_Y0, WALL_TOP), (ROOF_X1, ROOF_Y1, ROOF_TOP), P.INK, bevel=0.05)
    b.box((ROOF_X0, ROOF_Y0, ROOF_TOP), (ROOF_X1, ROOF_Y0 + 0.5, PAR_TOP), P.WHITE, bevel=0.03)
    b.box((ROOF_X0, ROOF_Y1 - 0.5, ROOF_TOP), (ROOF_X1, ROOF_Y1, PAR_TOP), P.WHITE, bevel=0.03)
    b.box((ROOF_X1 - 0.5, ROOF_Y0 + 0.5, ROOF_TOP), (ROOF_X1, ROOF_Y1 - 0.5, PAR_TOP), P.WHITE, bevel=0.03)
    b.box((ROOF_X0, ROOF_Y0 - 0.06, PAR_TOP), (ROOF_X1 + 0.06, ROOF_Y0 + 0.56, CAP_TOP), P.RED, bevel=0.02)
    b.box((ROOF_X0, ROOF_Y1 - 0.56, PAR_TOP), (ROOF_X1 + 0.06, ROOF_Y1 + 0.06, CAP_TOP), P.RED, bevel=0.02)
    b.box((ROOF_X1 - 0.56, ROOF_Y0 + 0.56, PAR_TOP), (ROOF_X1 + 0.06, ROOF_Y1 - 0.56, CAP_TOP), P.RED, bevel=0.02)
    studs_on(b, ROOF_X0 + 0.9, ROOF_X1 - 0.9, ROOF_Y0 + 0.9, ROOF_Y1 - 0.9, ROOF_TOP, P.INK, step=3.4,
             skip=((MAST_X - 1.8, MAST_Y - 1.8, MAST_X + 1.8, MAST_Y + 1.8), (RX0 - 0.3, RY0 - 0.3, RX1 + 0.3, RY1 + 0.3)))
    # parapet studs on the red cap
    studs_on(b, ROOF_X0 + 0.6, ROOF_X1 - 0.3, ROOF_Y0 + 0.1, ROOF_Y0 + 0.5, CAP_TOP, P.RED, step=1.9, r=0.3, h=0.22, n=5)
    studs_on(b, ROOF_X0 + 0.6, ROOF_X1 - 0.3, ROOF_Y1 - 0.5, ROOF_Y1 - 0.1, CAP_TOP, P.RED, step=1.9, r=0.3, h=0.22, n=5)
    studs_on(b, ROOF_X1 - 0.5, ROOF_X1 - 0.1, ROOF_Y0 + 0.9, ROOF_Y1 - 0.9, CAP_TOP, P.RED, step=1.9, r=0.3, h=0.22, n=5)
    b.box((MAST_X - 2.0, MAST_Y - 2.0, ROOF_TOP), (MAST_X + 2.0, MAST_Y + 2.0, PAD_TOP), P.WHITE, bevel=0.04)
    radio_room(b)


def radio_room(b):
    """r3: a one-storey radio room on the wing roof (the Lv4 level step): red/white brick courses, red corner
    pilasters, a framed window band facing the path, a stepped red studded roof with a white red-studded ridge cap.
    Solid (one COL box); the roof stays walkable in front and round it, clear of the Lv5 fences and the mast."""
    for k in range(4):
        z = ROOF_TOP + k * R_C
        b.box((RX0, RY0, z), (RX1, RY1, z + R_C), P.RED if k == 0 else P.WHITE, bevel=0.05,
              skip=("z0", "z1") if k == 0 else ("z1",))
    for x0, y0 in ((RX0 - 0.06, RY0 - 0.06), (RX0 - 0.06, RY1 - 0.49), (RX1 - 0.49, RY0 - 0.06), (RX1 - 0.49, RY1 - 0.49)):
        b.box((x0, y0, ROOF_TOP), (x0 + 0.55, y0 + 0.55, RZ1), P.RED, bevel=0.03, skip=("z0", "z1"))
    for a0, a1 in ((29.3, 31.15), (31.25, 33.1)):
        win_inset(b, "x", a0, a1, 16.75, 19.45, RY0, -1)
    win_inset(b, "y", 3.7, 6.3, 16.75, 19.45, RX0, -1)  # clear of the Lv5 post at y 3
    cy = (RY0 + RY1) / 2
    b.box((RX0 - 0.4, RY0 - 0.5, RZ1), (RX1 + 0.4, RY1 + 0.5, RZ1 + 0.45), P.RED, bevel=0.06)
    hws, z = (4.5, 3.4, 2.3, 1.2), RZ1 + 0.45
    for k in range(1, 4):
        b.box((RX0 - 0.25, cy - hws[k], z), (RX1 + 0.25, cy + hws[k], z + 0.6), P.RED, bevel=0.05, skip=("z0",))
        z += 0.6
    for k in range(3):
        zt = RZ1 + 0.45 + 0.6 * k
        yl = (hws[k] + hws[k + 1]) / 2
        for s in (-1, 1):
            studs_on(b, RX0 - 0.1, RX1 + 0.1, cy + s * yl - 0.3, cy + s * yl + 0.3, zt, P.RED, step=1.3, r=0.3, h=0.22,
                     n=5)
    ridge_cap(b, "x", RX0 - 0.5, RX1 + 0.5, cy, z, 1.4, th=0.3, seg=2.0, stud_r=0.28)   # r5


def wing_mast(b):
    cx, cy = MAST_X, MAST_Y
    z0 = PAD_TOP
    n = 14   # r3: ~2-stud red/white bands, 0.6 legs (read on a phone)
    seg = (MAST_TOP - z0) / n

    def half(t):
        return 1.35 + (0.55 - 1.35) * t

    for i in range(n):
        za, zb = z0 + i * seg, z0 + (i + 1) * seg
        wa, wb = half(i / n), half((i + 1) / n)
        col = P.RED if i % 2 == 0 else P.WHITE
        rung = P.WHITE if i % 2 == 0 else P.RED
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            b.beam((cx + sx * wa, cy + sy * wa, za), (cx + sx * wb, cy + sy * wb, zb), 0.9, 0.9, col)   # r5: 1.5x legs
        zr = zb - 0.08
        b.beam((cx - wb, cy - wb, zr), (cx + wb, cy - wb, zr), 0.16, 0.16, rung)
        b.beam((cx - wb, cy + wb, zr), (cx + wb, cy + wb, zr), 0.16, 0.16, rung)
        b.beam((cx - wb, cy - wb, zr), (cx - wb, cy + wb, zr), 0.16, 0.16, rung)
        b.beam((cx + wb, cy - wb, zr), (cx + wb, cy + wb, zr), 0.16, 0.16, rung)
        b.beam((cx - wa, cy - wa, za + 0.15), (cx + wb, cy - wb, zb - 0.15), 0.14, 0.14, rung)
        b.beam((cx + wa, cy + wa, za + 0.15), (cx - wb, cy + wb, zb - 0.15), 0.14, 0.14, rung)
        b.beam((cx - wa, cy + wa, za + 0.15), (cx - wb, cy - wb, zb - 0.15), 0.14, 0.14, rung)
        b.beam((cx + wa, cy - wa, za + 0.15), (cx + wb, cy + wb, zb - 0.15), 0.14, 0.14, rung)

    t = MAST_TOP
    b.box((cx - 1.1, cy - 1.1, t), (cx + 1.1, cy + 1.1, t + 0.3), P.INK, bevel=0.03)
    b.box((cx - 0.07, cy - 0.07, t + 0.3), (cx + 0.07, cy + 0.07, t + 2.4), P.WHITE, bevel=0.01)
    b.box((cx - 3.6, cy - 0.08, t + 0.47), (cx + 3.6, cy + 0.08, t + 0.63), P.WHITE, bevel=0.01)
    b.box((cx - 0.08, cy - 2.7, t + 0.32), (cx + 0.08, cy + 2.7, t + 0.48), P.WHITE, bevel=0.01)
    for sx in (-1, 1):
        b.box((cx + sx * 3.6 - 0.15, cy - 0.17, t + 0.39), (cx + sx * 3.6 + 0.15, cy + 0.17, t + 0.71), P.RED, bevel=0.0)
    # r2: red/white aircraft warning light cap
    b.cyl(cx, cy, t + 2.4, t + 2.75, 0.5, P.WHITE, 8)
    b.cyl(cx, cy, t + 2.75, t + 3.4, 0.42, P.RED, 8, bot=False)
    b.cyl(cx, cy, t + 3.4, t + 3.55, 0.3, P.INK, 6, bot=False)

    # r4: a grey parabolic dish facing the path: dark rim, hub, feed horn on a 3-strut arm (r5: 1.5x, 6.75 across,
    # on a 2x2 grey bracket brick into the mast)
    zc, R, yf, dep = 27.0, 3.375, 0.4, 1.65
    ring = lambda r, y: [(cx + r * math.cos(2 * math.pi * i / 16), y, zc + r * math.sin(2 * math.pi * i / 16))
                         for i in range(16)]
    ys = lambda r: yf + dep * (1 - (r / R) ** 2)
    rs = (0.65, 1.65, 2.55, R)
    b.loft([ring(r, ys(r)) for r in rs] + [ring(r - 0.16, ys(r) - 0.2) for r in reversed(rs)], P.LBG)
    b.ring_y(cx, yf - 0.02, zc, R, 0.24, P.DBG, maj=16, mnr=4)
    b.box((cx - 0.7, ys(0) - 0.45, zc - 0.7), (cx + 0.7, ys(0) + 0.5, zc + 0.7), P.DBG, bevel=0.05)
    b.box((cx - 1.0, ys(0) + 0.35, zc - 1.0), (cx + 1.0, cy - 0.6, zc + 1.0), P.LBG, bevel=0.06)
    fy = yf - 2.25
    for k in range(3):
        u = math.pi / 2 + 2 * math.pi * k / 3
        b.beam((cx + (R - 0.15) * math.cos(u), yf + 0.02, zc + (R - 0.15) * math.sin(u)), (cx, fy + 0.35, zc),
               0.18, 0.18, P.DBG)
    b.beam((cx, fy + 0.6, zc), (cx, fy - 0.05, zc), 0.54, 0.54, P.DBG)
    b.beam((cx, fy - 0.05, zc), (cx, fy - 0.7, zc), 0.9, 0.9, P.RED)


def wing_col(c):
    c.box((PL_X0, PL_Y0, 0.0), (PL_X1, PL_Y1, FLOOR))
    c.box((WEST_END, WY0, FLOOR), (WX1, WY1, FLOOR_TOP))
    c.box((WEST_END, WY0, FLOOR), (DOOR_X0, WY0 + WALL, WALL_TOP))
    c.box((DOOR_X1, WY0, FLOOR), (WX1, WY0 + WALL, WALL_TOP))
    c.box((DOOR_X0, WY0, DOOR_TOP), (DOOR_X1, WY0 + WALL, WALL_TOP))
    c.box((WEST_END, WY1 - WALL, FLOOR), (WX1, WY1, WALL_TOP))
    c.box((WX0, WY0 + WALL, FLOOR), (WX0 + WALL, WY1 - WALL, WALL_TOP))
    c.box((WX1 - WALL, WY0 + WALL, FLOOR), (WX1, WY1 - WALL, WALL_TOP))
    c.box((ROOF_X0, ROOF_Y0, WALL_TOP), (ROOF_X1, ROOF_Y1, CAP_TOP))
    c.box((40.6, 0.2, FLOOR_TOP), (42.5, 7.9, 5.6))
    c.box((MAST_X - 1.35, MAST_Y - 1.35, PAD_TOP), (MAST_X + 1.35, MAST_Y + 1.35, MAST_TOP))
    c.box((RX0, RY0, CAP_TOP), (RX1, RY1, RZ1 + 2.25))
    c.box((30.6, -4.6, 0.0), (36.2, PL_Y0, 0.3))
    # r4 front block: plinth, floor, three front bites round the door, west, east, upper back, roof, step
    for lo, hi in (((F_X0, -16.4, 0.0), (43.3, PL_Y0, FLOOR)), ((F_XI, F_YI, FLOOR), (F_XE, PL_Y0, FLOOR_TOP)),
                   ((F_X0, F_Y0, FLOOR), (F_DX0, F_YI, F_TOP)), ((F_DX1, F_Y0, FLOOR), (F_X1, F_YI, F_TOP)),
                   ((F_DX0, F_Y0, F_DTOP), (F_DX1, F_YI, F_TOP)), ((F_X0, F_YI, FLOOR), (F_XI, WY0, F_TOP)),
                   ((F_XE, F_YI, FLOOR), (F_X1, WY0, F_TOP)), ((F_XI, F_YBI, 14.52), (F_XE, F_YB, F_TOP)),
                   ((F_XW, F_Y0, F_TOP), (F_X1, F_YB, 19.65)), ((31.4, -17.2, 0.0), (39.4, -16.4, 0.3))):
        c.box(lo, hi)


# ------------------------------------------------------------------ Lv4 front block (r4)
# The AD r3 read "L3 + a stub" from the path: a walk-in block in front of the radio wing, flush with the hall front
# (x 26.9..43.2, y -15.4..-3), red/white courses to 18.0, a studded navy deck with a red/white chequer parapet and a
# red cap (19.65), a deep-red portal with red leaves swung open, a framed radio-wave plaque, inset windows. Its back
# is the wing's front wall: the wing door links the two. Above the eave line the west wall steps to x 27.6, clear of
# the hall's gable overhang (27.5); the east side stays 0.5 off the Lv5 stair (43.72).
def block_base(b):
    b.box((F_X0, -16.4, 0.0), (43.3, PL_Y0, FLOOR), P.TAN, bevel=0.06, skip=("y1",))
    b.box((F_XI, F_YI, FLOOR), (F_XE, PL_Y0, FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((F_DX0, F_Y0, FLOOR), (F_DX1, F_YI, FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((31.4, -17.2, 0.0), (39.4, -16.4, 0.3), P.TAN, bevel=0.04)
    for x in (33.4, 35.4, 37.4):
        b.cyl(x, -16.8, 0.3, 0.5, 0.4, P.TAN, 6)
    studs_on(b, F_X0 + 0.3, 43.0, -16.2, -15.6, FLOOR, P.TAN, step=2.6, skip=((F_DX0 - 1.2, -17, F_DX1 + 1.2, -15),))


def block_walls(b):
    for k in range(F_N):
        z0, z1 = FLOOR + k * F_C, FLOOR + (k + 1) * F_C
        col = P.RED if k % 4 == 0 else P.WHITE
        sk = ("z0", "z1") if k in (0, 12) else ("z1",) if k != 11 else ()
        xw = F_X0 if z1 < 15.7 else F_XW
        yb, yk = (WY0, ("y1",)) if z1 < 14.53 else (F_YB, ())
        for a0, a1 in (((xw, F_DX0), (F_DX1, F_X1)) if k < 7 else ((xw, F_X1),)):
            b.box((a0, F_Y0, z0), (a1, F_YI, z1), col, bevel=0.05, skip=sk)
        b.box((xw, F_YI, z0), (F_XI, yb, z1), col, bevel=0.05, skip=sk + yk)
        b.box((F_XE, F_YI, z0), (F_X1, yb, z1), col, bevel=0.05, skip=sk + yk)
        if k >= 12:
            b.box((F_XI, F_YBI, z0), (F_XE, F_YB, z1), col, bevel=0.05, skip=("z1",))
    # r5: brick-course seams on the front and the east face (keep-outs: portal + plaque, windows, storey band)
    zs = [FLOOR + k * F_C for k in range(F_N + 1)]
    ko = [(31.2, 39.6, 0.0, 13.8), (27.0, 27.7, 15.6, 99.0), (27.6, 42.6, 9.55, 9.95)]
    ko += [(a0, a1, z0, z1) for a0, a1 in ((28.3, 31.2), (39.6, 42.5)) for z0, z1 in ((2.95, 6.85), (10.75, 14.45))]
    seams(b, "x", F_X0 + 0.1, 42.6, F_Y0, -1, zs, ko)
    seams(b, "y", -14.85, WY0 - 0.05, F_X1, 1, zs, [(F_YB - 0.05, 99.0, 14.5, 99.0)])
    # under the hall's gable overhang (bottom 16.05): a filler course so no slot shows at the corner
    b.box((F_X0, F_Y0, FLOOR + 13 * F_C), (F_XW, WY0, 16.0), P.WHITE, bevel=0.03, skip=("z0", "y1"))
    b.box((42.69, F_Y0 - 0.06, FLOOR), (43.22, F_YI - 0.13, F_TOP), P.RED, bevel=0.03, skip=("z0", "z1"))


def block_trim(b):
    portal(b, F_DX0, F_DX1, F_Y0, F_DTOP, FLOOR)
    for s, hx in ((-1, F_DX0 - 0.3), (1, F_DX1 + 0.3)):
        leaf(b, hx, F_Y0 - 0.55, s, 3.2, 0.66, F_DTOP - 0.12, 90)
    for a0, a1 in ((28.6, 30.9), (39.9, 42.2)):
        win_inset(b, "x", a0, a1, 3.4, 6.8, F_Y0, -1)
        win_inset(b, "x", a0, a1, 11.2, 14.4, F_Y0, -1)
    # plaque on a grey ledge over the portal: red frame, white board, a radio-wave icon (mast, red dot, 3 arcs a side)
    cx, y = (F_DX0 + F_DX1) / 2, F_Y0
    b.box((32.4, y - 0.75, 9.75), (38.4, y, 10.1), P.LBG, bevel=0.04, skip=("y1",))
    b.box((32.6, y - 0.45, 10.1), (38.2, y, 13.7), P.RED, bevel=0.05, skip=("y1", "z0"))
    b.box((32.95, y - 0.55, 10.45), (37.85, y - 0.45, 13.35), P.WHITE, bevel=0.02)
    yp = y - 0.55
    b.box((cx - 0.12, yp - 0.08, 10.75), (cx + 0.12, yp, 11.9), P.INK, bevel=0.0)
    b.box((cx - 0.3, yp - 0.12, 11.85), (cx + 0.3, yp, 12.45), P.RED, bevel=0.04)
    for i in (1, 2, 3):
        h = 0.25 + 0.3 * i
        for s in (-1, 1):
            xa = cx + s * (0.25 + 0.5 * i)
            b.box((xa - 0.13, yp - 0.1, 12.15 - h), (xa + 0.13, yp, 12.15 + h), P.INK if i != 2 else P.RED, bevel=0.0)
    # a navy storey band (like the wing's) between the two window rows
    for a0, a1 in ((F_XW + 0.05, F_DX0 - 1.0), (F_DX1 + 1.0, 42.6)):
        b.box((a0, F_Y0 - 0.05, 9.62), (a1, F_Y0, 9.9), P.INK, bevel=0.01)


def block_roof(b):
    b.box((F_XW, F_Y0, F_TOP), (F_X1, F_YB, F_TOP + 0.5), P.INK, bevel=0.05)
    zp = F_TOP + 0.5

    def cheq(along, a0, a1, n0, n1):
        m = max(1, int(round((a1 - a0) / 1.1)))
        for row in (0, 1):
            for i in range(m):
                c = P.RED if (i + row) % 2 == 0 else P.WHITE
                bx(b, along, a0 + (a1 - a0) * i / m, a0 + (a1 - a0) * (i + 1) / m, n0, n1, zp + 0.5 * row,
                   zp + 0.5 * (row + 1), c, bevel=0.04, skip=("z0", "z1"))
    cheq("x", F_XW, F_X1, F_Y0, F_Y0 + 0.6)
    cheq("x", F_XW, F_X1, F_YB - 0.6, F_YB)
    cheq("y", F_Y0 + 0.6, F_YB - 0.6, F_XW, F_XW + 0.6)
    cheq("y", F_Y0 + 0.6, F_YB - 0.6, F_X1 - 0.6, F_X1)
    zc = zp + 1.0
    b.box((F_XW - 0.1, F_Y0 - 0.1, zc), (F_X1 + 0.04, F_Y0 + 0.7, zc + 0.15), P.RED, bevel=0.03)
    b.box((F_XW - 0.1, F_YB - 0.7, zc), (F_X1 + 0.04, F_YB + 0.04, zc + 0.15), P.RED, bevel=0.03)
    for x0, x1 in ((F_XW - 0.1, F_XW + 0.7), (F_X1 - 0.7, F_X1 + 0.04)):
        b.box((x0, F_Y0 + 0.7, zc), (x1, F_YB - 0.7, zc + 0.15), P.RED, bevel=0.03)
    kw = dict(step=1.1, r=0.3, h=0.22, n=5)
    studs_on(b, F_XW, F_X1, F_Y0 + 0.1, F_Y0 + 0.5, zc + 0.15, P.RED, **kw)
    studs_on(b, F_XW, F_X1, F_YB - 0.5, F_YB - 0.1, zc + 0.15, P.RED, **kw)
    studs_on(b, F_XW + 0.1, F_XW + 0.5, F_Y0 + 0.7, F_YB - 0.7, zc + 0.15, P.RED, **kw)
    studs_on(b, F_X1 - 0.5, F_X1 - 0.1, F_Y0 + 0.7, F_YB - 0.7, zc + 0.15, P.RED, **kw)
    studs_on(b, F_XW + 1.0, F_X1 - 1.0, F_Y0 + 1.0, F_YB - 1.0, zp, P.INK, step=2.6)


def hall_canopy(b):
    """r4 Lv4: a red studded canopy porch over the station door on two white posts (outside the opening and the
    swung leaves), above z 9.35, so the L4 hall front differs from L3."""
    y0 = BAY_Y0 - 0.5
    b.box((-7.4, y0 - 2.1, 9.6), (7.4, y0, 10.1), P.RED, bevel=0.06)
    b.box((-7.5, y0 - 2.25, 9.35), (7.5, y0 - 1.95, 9.6), P.WHITE, bevel=0.04)
    studs_on(b, -7.0, 7.0, y0 - 1.9, y0 - 0.5, 10.1, P.RED, step=2.2, r=0.42, h=0.26)
    for s in (-1, 1):
        b.box((min(s * 6.6, s * 7.1), -21.95, 0.5), (max(s * 6.6, s * 7.1), -21.45, 9.35), P.WHITE, bevel=0.05,
              skip=("z0", "z1"))


# ------------------------------------------------------------------ Lv5 beacon tower
def tower_base(b):
    b.box((QX0, QY0, 0.0), (QX1, QY1, T_FLOOR), P.TAN, bevel=0.06)
    b.box((TX0 + T_WALL, TY0 + T_WALL, T_FLOOR), (TX1 - T_WALL, TY1 - T_WALL, T_FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((T_DOOR_X0, TY0, T_FLOOR), (T_DOOR_X1, TY0 + T_WALL, T_FLOOR_TOP), P.TAN, bevel=0.01)
    b.box((52.5, QY0 - 1.2, 0.0), (57.5, QY0, 0.3), P.TAN, bevel=0.04)
    for x in (53.6, 55.0, 56.4):
        b.cyl(x, QY0 - 0.6, 0.3, 0.5, 0.35, P.TAN, 6)
    studs_on(b, 49.4, 60.6, -2.8, -1.7, T_FLOOR, P.TAN, step=2.9)
    studs_on(b, 49.4, 60.6, 7.7, 8.8, T_FLOOR, P.TAN, step=2.9)
    studs_on(b, 49.2, 50.3, -0.8, 6.8, T_FLOOR, P.TAN, step=2.9)
    studs_on(b, 59.7, 60.8, -0.8, 6.8, T_FLOOR, P.TAN, step=2.9)


def tower_walls(b):
    yf0, yf1 = TY0, TY0 + T_WALL
    yb0, yb1 = TY1 - T_WALL, TY1
    # hidden faces trimmed as in the wing (the west course under the bridge door keeps its top: the threshold)
    for k in range(S1_N):
        z = T_FLOOR + k * S1_C
        col = P.RED if k % 4 == 0 else P.WHITE
        sk = ("z0", "z1") if k == 0 else ("z1",)
        if k < 3:
            b.box((TX0, yf0, z), (T_DOOR_X0, yf1, z + S1_C), col, bevel=0.04, skip=sk)
            b.box((T_DOOR_X1, yf0, z), (TX1, yf1, z + S1_C), col, bevel=0.04, skip=sk)
        else:
            b.box((TX0, yf0, z), (TX1, yf1, z + S1_C), col, bevel=0.04, skip=sk)
        b.box((TX0, yb0, z), (TX1, yb1, z + S1_C), col, bevel=0.04, skip=sk)
        if z > F2 - 0.01:
            b.box((TX0, yf1, z), (TX0 + T_WALL, W_DY0, z + S1_C), col, bevel=0.04, skip=sk)
            b.box((TX0, W_DY1, z), (TX0 + T_WALL, yb0, z + S1_C), col, bevel=0.04, skip=sk)
        else:
            b.box((TX0, yf1, z), (TX0 + T_WALL, yb0, z + S1_C), col, bevel=0.04,
                  skip=sk if z + S1_C < F2 - 0.01 else ())
        b.box((TX1 - T_WALL, yf1, z), (TX1, yb0, z + S1_C), col, bevel=0.04, skip=sk)
    b.box((TX0 + T_WALL, yf1, F2 - 0.6), (TX1 - T_WALL, yb0, F2), P.TAN, bevel=0.02)
    for j in range(U_N):
        z = LEDGE_TOP + j * U_C
        col = P.RED if (S1_N + j) % 4 == 0 else P.WHITE
        b.box((UX0, UY0, z), (UX1, UY1, z + U_C), col, bevel=0.04, skip=("z1",))


def shield(b, cx, y0, y1, ztop, W, H, col, inset=0.0):
    """A stepped heater shield (full width on top, narrowing to a point), one box per band; `inset` shrinks the
    same outline on every side, so the navy field keeps the red border's steps."""
    z = ztop
    for fh, fw in ((0.55, 1.0), (0.1, 0.88), (0.1, 0.72), (0.1, 0.54), (0.1, 0.36), (0.05, 0.18)):
        zt, zb = z, z - H * fh
        w = W * fw - 2 * inset
        if w > 0.3:
            b.box((cx - w / 2, y0, zb), (cx + w / 2, y1, zt - (inset if zt == ztop else 0.0)), col, bevel=0.0)
        z = zb


def tower_trim(b):
    portal(b, T_DOOR_X0, T_DOOR_X1, TY0, T_DOOR_TOP, T_FLOOR)

    b.box((TX0 - 0.35, TY0 - 0.35, S1_TOP), (TX1 + 0.35, TY1 + 0.35, LEDGE_TOP), P.INK, bevel=0.04)

    # crest: red border shield, navy field, gold anchor
    cx = TCX
    shield(b, cx, TY0 - 0.3, TY0, CREST_Z1, CREST_W, CREST_H, P.RED)
    shield(b, cx, TY0 - 0.55, TY0 - 0.3, CREST_Z1, CREST_W, CREST_H, P.INK, inset=0.6)
    ya, yb_ = TY0 - 0.8, TY0 - 0.55
    ym = (ya + yb_) / 2
    b.ring_y(cx, ym, 17.6, 0.55, 0.14, P.GOLD, maj=8, mnr=4)
    b.box((cx - 0.25, ya, 11.3), (cx + 0.25, yb_, 17.0), P.GOLD, bevel=0.0)
    b.box((cx - 1.5, ya, 15.4), (cx + 1.5, yb_, 15.85), P.GOLD, bevel=0.0)
    for s in (-1, 1):
        b.beam((cx, ym, 11.55), (cx + s * 2.0, ym, 13.1), 0.25, 0.5, P.GOLD)
        b.box((cx + s * 2.0 - 0.25, ya, 12.9), (cx + s * 2.0 + 0.25, yb_, 14.0), P.GOLD, bevel=0.0)

    hall = dict(fw=0.5, cross=True)   # r5: the hall's navy frames, white cross bars and studded red sills
    for z0 in (LEDGE_TOP + 3.0, LEDGE_TOP + 9.0):
        win_inset(b, "x", TCX - 1.2, TCX + 1.2, z0, z0 + 3.4, UY0, -1, **hall)
        win_inset(b, "x", TCX - 1.2, TCX + 1.2, z0, z0 + 3.4, UY1, 1, **hall)
        win_inset(b, "y", TCY - 1.2, TCY + 1.2, z0, z0 + 3.4, UX0, -1, **hall)
        win_inset(b, "y", TCY - 1.2, TCY + 1.2, z0, z0 + 3.4, UX1, 1, **hall)

    yb = TY1 - T_WALL
    b.box((52.4, yb - 0.18, 2.8), (57.6, yb, 6.2), P.INK, bevel=0.02)
    b.box((52.9, yb - 0.24, 3.2), (54.3, yb - 0.18, 5.8), P.WHITE, bevel=0.0)
    b.box((54.9, yb - 0.24, 3.4), (55.2, yb - 0.18, 5.4), P.YELLOW, bevel=0.0)
    b.box((55.9, yb - 0.24, 4.4), (56.9, yb - 0.18, 5.0), P.RED, bevel=0.0)
    for zc in (S1_TOP, F2 - 0.6):
        b.box((TCX - 0.6, TCY - 0.6, zc - 0.1), (TCX + 0.6, TCY + 0.6, zc), P.INK, bevel=0.02)
        b.box((TCX - 0.4, TCY - 0.4, zc - 0.2), (TCX + 0.4, TCY + 0.4, zc - 0.1), P.WARM, bevel=0.01)
    win_inset(b, "x", TCX - 1.2, TCX + 1.2, F2 + 2.0, F2 + 5.4, TY1, 1, **hall)
    win_inset(b, "y", TCY - 1.2, TCY + 1.2, F2 + 2.0, F2 + 5.4, TX1, 1, **hall)

    # second-floor door on the west face, red frame under the navy ledge
    for y0, y1 in ((W_DY0 - 0.2, W_DY0 + 0.2), (W_DY1 - 0.2, W_DY1 + 0.2)):
        b.box((TX0 - 0.2, y0, F2), (TX0, y1, S1_TOP), P.RED, bevel=0.02)

    # raised bridge from the wing roof to the second floor: a tan deck resting on the wing's parapet cap (its studs
    # sit in the deck, Lego style), a navy girder under it, Lego fence panels each side, a step plate on the roof
    b.box((BR_X0, BR_Y0, BR_Z0), (BR_X1, BR_Y1, BR_Z1), P.TAN, bevel=0.04)
    b.box((ROOF_X1 + 0.06, BR_Y0 + 0.3, BR_Z0 - 0.9), (BR_X1, BR_Y1 - 0.3, BR_Z0), P.INK, bevel=0.04)
    for y in (BR_Y0 + 0.5, BR_Y1 - 0.5):
        b.beam((TX0, y, BR_Z0 - 4.5), (ROOF_X1 + 3.0, y, BR_Z0 - 0.9), 0.4, 0.4, P.INK)
    b.box((ROOF_X1 - 2.2, BR_Y0 + 0.2, ROOF_TOP), (BR_X0, BR_Y1 - 0.2, ROOF_TOP + 0.5), P.TAN, bevel=0.03)
    fence_x(b, ROOF_X1 + 0.4, BR_X1 - 0.4, BR_Y0 + 0.2, BR_Z1, 1.1)
    fence_x(b, ROOF_X1 + 0.4, BR_X1 - 0.4, BR_Y1 - 0.2, BR_Z1, 1.1)
    stair(b)
    station_crest(b)
    tower_bands(b)


def station_crest(b):
    """r4 Lv5: a gold crest roundel with a red rim and a red anchor over the entrance bay's lifebuoy roundel."""
    cz, y = 19.6, BAY_Y0 - 1.12
    ring = lambda r, yy: [(r * math.cos(2 * math.pi * i / 16), yy, cz + r * math.sin(2 * math.pi * i / 16))
                          for i in range(16)]
    b.loft([ring(2.05, y), ring(2.05, y - 0.18)], P.GOLD)
    b.ring_y(0.0, y - 0.1, cz, 2.05, 0.24, P.RED, maj=16, mnr=4)
    ya, yb = y - 0.3, y - 0.18
    for lo, hi in (((-0.16, 18.25), (0.16, 20.9)), ((-0.85, 20.35), (0.85, 20.6)), ((-1.1, 18.2), (1.1, 18.45)),
                   ((-1.1, 18.45), (-0.85, 19.0)), ((0.85, 18.45), (1.1, 19.0))):
        b.box((lo[0], ya, lo[1]), (hi[0], yb, hi[1]), P.RED, bevel=0.0, skip=("y1",))
    b.box((-0.4, ya, 20.9), (0.4, yb, 21.3), P.RED, bevel=0.0, skip=("y1",))


def tower_bands(b):
    """r4 Lv5: a 1-stud red/white band under the gallery and a red cap band round the tower base (0.3 proud)."""
    z0, z1 = 36.95, 37.9
    for along, a0, a1, n0, n1 in (("x", UX0 - 0.25, UX1 + 0.25, UY0 - 0.25, UY0), ("x", UX0 - 0.25, UX1 + 0.25, UY1, UY1 + 0.25),
                                  ("y", UY0, UY1, UX0 - 0.25, UX0), ("y", UY0, UY1, UX1, UX1 + 0.25)):
        m = int(round((a1 - a0) / 1.1))
        for i in range(m):
            bx(b, along, a0 + (a1 - a0) * i / m, a0 + (a1 - a0) * (i + 1) / m, n0, n1, z0, z1,
               P.RED if i % 2 == 0 else P.WHITE, bevel=0.04)
    zb0, zb1 = T_FLOOR + S1_C, T_FLOOR + S1_C + 0.5
    for lo, hi in (((TX0 - 0.3, TY0 - 0.3), (T_DOOR_X0 - 0.85, TY0)), ((T_DOOR_X1 + 0.85, TY0 - 0.3), (TX1 + 0.3, TY0)),
                   ((TX0 - 0.3, TY1), (TX1 + 0.3, TY1 + 0.3)), ((TX0 - 0.3, TY0), (TX0, TY1)), ((TX1, TY0), (TX1 + 0.3, TY1))):
        b.box((lo[0], lo[1], zb0), (hi[0], hi[1], zb1), P.RED, bevel=0.05)


def post(b, x, y, z0):
    b.box((x - 0.3, y - 0.3, z0), (x + 0.3, y + 0.3, z0 + FH + 0.8), P.RED, bevel=0.03, skip=("z0",))
    b.cyl(x, y, z0 + FH + 0.8, z0 + FH + 1.05, 0.22, P.RED, 5, bot=False)


def panel(b, lo, hi, z_rail):
    """A solid white Lego fence panel with a red top rail (rail z_rail .. +0.4, 0.08 proud each side)."""
    b.box(lo, (hi[0], hi[1], z_rail), P.WHITE, bevel=0.02, skip=("z0", "z1"))
    ax = 0.08 if hi[0] - lo[0] < 1.0 else 0.0
    ay = 0.08 if hi[1] - lo[1] < 1.0 else 0.0
    b.box((lo[0] - ax, lo[1] - ay, z_rail), (hi[0] + ax, hi[1] + ay, z_rail + 0.4), P.RED, bevel=0.03)


def stair(b):
    """Lv5: a tan Lego stair (15 risers of 1.04, 1.1 treads, 2 studs a tread) up to a landing at the wing's east
    cap, solid white fence panels with red rails both sides, and a fence round the wing roof's edge."""
    for k in range(1, ST_N):
        y = ST_Y0 + (k - 1) * ST_RUN
        z = k * ST_RISE
        b.box((ST_X0, y, 0.0), (ST_X1, y + ST_RUN, z), P.TAN, bevel=0.0, skip=("z0", "y1"))
        for x in (45.9, 47.9):
            b.cyl(x, y + ST_RUN / 2, z, z + 0.2, 0.32, P.TAN, 5, bot=False)
        # r3: a brown riser plate (0.05 proud) under a tan nosing, so the flight reads as steps
        b.box((ST_X0 + 0.45, y - 0.05, z - ST_RISE), (ST_X1 - 0.45, y, z - 0.18), P.BROWN, bevel=0.0,
              skip=("z0", "y1"))
    b.box((ST_X0, LAND_Y0, 0.0), (ST_X1, LAND_Y1, CAP_TOP), P.TAN, bevel=0.0, skip=("z0",))
    # r4: red stepped brick stringers both sides (2-rise bricks, one column a tread, 0.08 proud) so no tan slab shows;
    # the landing's open east side gets the same bricks (its west side faces the wing wall)
    def brick_col(x0, x1, y0, y1, top, back=True):
        z, m = 0.0, 0
        while z < top - 1e-6:
            zt = min(top, z + 2 * ST_RISE)
            sk = (("z0",) if m == 0 else ()) + (("z1",) if zt < top - 1e-6 else ()) + (() if back else ("y1",))
            b.box((x0, y0, z), (x1, y1, zt), P.RED, bevel=0.05, skip=sk)
            z, m = zt, m + 1
    for k in range(1, ST_N):
        y = ST_Y0 + (k - 1) * ST_RUN - 0.05
        for x0, x1 in ((ST_X0 - 0.08, ST_X0 + 0.25), (ST_X1 - 0.25, ST_X1 + 0.08)):
            brick_col(x0, x1, y, y + ST_RUN, k * ST_RISE + 0.06, back=False)
    ym = (LAND_Y0 + LAND_Y1) / 2
    brick_col(ST_X1 - 0.25, ST_X1 + 0.08, LAND_Y0 - 0.05, ym, CAP_TOP + 0.06, back=False)
    brick_col(ST_X1 - 0.25, ST_X1 + 0.08, ym, LAND_Y1 + 0.05, CAP_TOP + 0.06)
    # sloped side panels: bottom edge through the treads' inner corners, top FH over the nosings
    for x0 in (ST_X0 + 0.08, ST_X1 - 0.38):
        b.prof_x(x0, x0 + 0.3, [(ST_Y0, 0.0), (LAND_Y0, CAP_TOP - ST_RISE), (LAND_Y0, CAP_TOP + FH),
                                (ST_Y0, ST_RISE + FH)], P.WHITE)
        b.prof_x(x0 - 0.08, x0 + 0.38, [(ST_Y0, ST_RISE + FH), (LAND_Y0, CAP_TOP + FH),
                                        (LAND_Y0, CAP_TOP + FH + 0.4), (ST_Y0, ST_RISE + FH + 0.4)], P.RED)
    # r3: red handrail posts every 2 treads, through the rail, stud-capped
    for k in range(3, ST_N - 1, 2):
        y = ST_Y0 + (k - 1) * ST_RUN + ST_RUN / 2
        zr = ST_RISE + FH + (y - ST_Y0) / (LAND_Y0 - ST_Y0) * (CAP_TOP - ST_RISE) + 0.4
        for x0, x1 in ((ST_X0 - 0.05, ST_X0 + 0.55), (ST_X1 - 0.55, ST_X1 + 0.05)):
            b.box((x0, y - 0.25, k * ST_RISE), (x1, y + 0.25, zr + 0.35), P.RED, bevel=0.03, skip=("z0",))
            b.cyl((x0 + x1) / 2, y, zr + 0.35, zr + 0.57, 0.2, P.RED, 5, bot=False)
    for x in (ST_X0 + 0.3, ST_X1 - 0.3):
        post(b, x, ST_Y0 + 0.3, ST_RISE)
        post(b, x, LAND_Y0 + 0.3, CAP_TOP)
    panel(b, (ST_X1 - 0.38, LAND_Y0 + 0.6, CAP_TOP), (ST_X1 - 0.08, LAND_Y1, CAP_TOP + FH), CAP_TOP + FH)
    # roof edge: front and back caps, the station end (clear of its gable overhang at 27.5) and the east cap
    # behind the bridge; the landing and the bridge step plate are the two openings
    panel(b, (RF_W, RF_F - 0.15, CAP_TOP), (ST_X0 + 0.3, RF_F + 0.15, CAP_TOP + FH), CAP_TOP + FH)
    panel(b, (RF_W, RF_B - 0.15, CAP_TOP), (RF_E, RF_B + 0.15, CAP_TOP + FH), CAP_TOP + FH)
    panel(b, (RF_W - 0.15, RF_F, ROOF_TOP), (RF_W + 0.15, RF_B, CAP_TOP + FH), CAP_TOP + FH)
    panel(b, (RF_E - 0.15, BR_Y1 + 0.3, CAP_TOP), (RF_E + 0.15, RF_B, CAP_TOP + FH), CAP_TOP + FH)
    for x, y in ((RF_W, RF_F), (RF_W, RF_B), (RF_E, RF_B), (RF_E, BR_Y1 + 0.3), (35.6, RF_F), (35.6, RF_B)):
        post(b, x, y, CAP_TOP)
    post(b, RF_W, 3.0, ROOF_TOP)  # no parapet at the station end


def stair_col(c):
    for k in range(1, ST_N):
        y = ST_Y0 + (k - 1) * ST_RUN
        c.box((ST_X0, y, 0.0), (ST_X1, y + ST_RUN, k * ST_RISE))
    c.box((ST_X0, LAND_Y0, 0.0), (ST_X1, LAND_Y1, CAP_TOP))
    top = CAP_TOP + FH + 0.4
    c.box((ST_X0, ST_Y0, 0.0), (ST_X0 + 0.6, LAND_Y0 + 0.6, top))
    c.box((ST_X1 - 0.6, ST_Y0, 0.0), (ST_X1, LAND_Y1, top))
    c.box((RF_W - 0.3, RF_F - 0.3, CAP_TOP), (ST_X0 + 0.3, RF_F + 0.3, top))
    c.box((RF_W - 0.3, RF_B - 0.3, CAP_TOP), (RF_E + 0.3, RF_B + 0.3, top))
    c.box((RF_W - 0.3, RF_F + 0.3, CAP_TOP), (RF_W + 0.3, RF_B - 0.3, top))
    c.box((RF_E - 0.3, BR_Y1, CAP_TOP), (RF_E + 0.3, RF_B - 0.3, top))


def tower_balcony(b):
    b.box((BX0 + 0.6, BY0 + 0.6, B_Z0 - 0.6), (BX1 - 0.6, BY1 - 0.6, B_Z0), P.INK, bevel=0.04)
    b.box((BX0, BY0, B_Z0), (BX1, BY1, B_Z1), P.INK, bevel=0.04)
    fence_x(b, FX0 + 0.5, FX1 - 0.5, FY0, B_Z1, 1.25)
    fence_x(b, FX0 + 0.5, FX1 - 0.5, FY1, B_Z1, 1.25)
    fence_y(b, FY0 + 0.5, FY1 - 0.5, FX0, B_Z1, 1.25)
    fence_y(b, FY0 + 0.5, FY1 - 0.5, FX1, B_Z1, 1.25)
    for x, y in ((FX0, FY0), (FX0, FY1), (FX1, FY0), (FX1, FY1)):
        b.box((x - 0.3, y - 0.3, B_Z1), (x + 0.3, y + 0.3, RAIL_TOP + 0.4), P.RED, bevel=0.03)
        b.cyl(x, y, RAIL_TOP + 0.4, RAIL_TOP + 0.65, 0.22, P.RED, 5)


def tower_lantern(b):
    cx, cy, H = LAN_CX, LAN_CY, LAN_HALF
    b.box((cx - H, cy - H, B_Z1), (cx + H, cy + H, LAN_Z0), P.GOLD, bevel=0.04)
    pc = H - 0.3
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = cx + sx * pc, cy + sy * pc
        b.box((x - 0.3, y - 0.3, LAN_Z0), (x + 0.3, y + 0.3, LAN_Z1), P.GOLD, bevel=0.03)
    # glazing: a light-blue pane in every bay (two per side, split by a gold mullion) up to PANE_TOP; the open band
    # above the panes shows the lamp head
    for s_ in (-1, 1):
        for along_x in (True, False):
            c0, c1 = (cx - pc + 0.3, cx + pc - 0.3) if along_x else (cy - pc + 0.3, cy + pc - 0.3)
            f = (cy if along_x else cx) + s_ * pc
            mid = cx if along_x else cy
            span = lambda lo, hi, z0, z1, c, t=0.25, bev=0.02: (
                b.box((lo, f - t, z0), (hi, f + t, z1), c, bevel=bev) if along_x else
                b.box((f - t, lo, z0), (f + t, hi, z1), c, bevel=bev))
            span(c0, c1, LAN_Z0, PANE_TOP, P.GLASS, 0.08, 0.0)
            span(c0, c1, LAN_Z0, LAN_Z0 + 0.3, P.GOLD)
            span(c0, c1, PANE_TOP, PANE_TOP + 0.3, P.GOLD)
            span(c0, c1, LAN_Z0 + 1.6, LAN_Z0 + 1.75, P.GOLD, 0.14, 0.0)
            span(mid - 0.18, mid + 0.18, LAN_Z0 + 0.3, PANE_TOP, P.GOLD)
    # lamp pedestal, a gold lens band around the lamp and its cap (the lamp itself is Lv5_L05_Beacon)
    b.cyl(cx, cy, LAN_Z0, LAMP_Z0, 0.8, P.DBG, 8)
    b.cyl(cx, cy, PANE_TOP + 0.85, PANE_TOP + 1.0, 1.68, P.GOLD, 8)
    b.cyl(cx, cy, LAN_Z1 - 0.3, LAN_Z1, 0.9, P.GOLD, 8)
    # trimmed eaves: a thin gold eave just past the posts and a tight red stepped roof
    b.box((cx - 3.7, cy - 3.7, LAN_Z1), (cx + 3.7, cy + 3.7, LAN_Z1 + 0.45), P.GOLD, bevel=0.04)
    z = LAN_Z1 + 0.45
    ring_studs(b, cx, cy, 3.45, z, P.GOLD)   # PERF-HQ: tile studs on the eave and each step ledge
    halves = (3.2, 2.5, 1.8, 1.1)
    for i, half in enumerate(halves):
        b.box((cx - half, cy - half, z), (cx + half, cy + half, z + 0.65), P.RED, bevel=0.04)
        z += 0.65
        if i < 3:
            ring_studs(b, cx, cy, (half + halves[i + 1]) / 2, z, P.RED)
    # finial cap: a gold plate, spike and ball
    b.box((cx - 0.75, cy - 0.75, z), (cx + 0.75, cy + 0.75, z + 0.3), P.GOLD, bevel=0.05)
    b.cyl(cx, cy, z + 0.3, z + 1.1, 0.3, P.GOLD, 6)
    b.cyl(cx, cy, z + 1.1, z + 1.7, 0.5, P.GOLD, 8)


def tower_beacon(b):
    b.cyl(LAN_CX, LAN_CY, LAMP_Z0, LAN_Z1 - 0.3, 1.55, P.WARM, 8)


def tower_col(c):
    c.box((QX0, QY0, 0.0), (QX1, QY1, T_FLOOR))
    c.box((TX0 + T_WALL, TY0 + T_WALL, T_FLOOR), (TX1 - T_WALL, TY1 - T_WALL, T_FLOOR_TOP))
    c.box((T_DOOR_X0, TY0, T_FLOOR), (T_DOOR_X1, TY0 + T_WALL, T_FLOOR_TOP))
    c.box((TX0, TY0, T_FLOOR), (T_DOOR_X0, TY0 + T_WALL, S1_TOP))
    c.box((T_DOOR_X1, TY0, T_FLOOR), (TX1, TY0 + T_WALL, S1_TOP))
    c.box((T_DOOR_X0, TY0, T_DOOR_TOP), (T_DOOR_X1, TY0 + T_WALL, S1_TOP))
    c.box((TX0, TY1 - T_WALL, T_FLOOR), (TX1, TY1, S1_TOP))
    c.box((TX0, TY0 + T_WALL, T_FLOOR), (TX0 + T_WALL, TY1 - T_WALL, F2))
    c.box((TX0, TY0 + T_WALL, F2), (TX0 + T_WALL, W_DY0, S1_TOP))
    c.box((TX0, W_DY1, F2), (TX0 + T_WALL, TY1 - T_WALL, S1_TOP))
    c.box((TX0 + T_WALL, TY0 + T_WALL, F2 - 0.6), (TX1 - T_WALL, TY1 - T_WALL, F2))
    c.box((TX1 - T_WALL, TY0 + T_WALL, T_FLOOR), (TX1, TY1 - T_WALL, S1_TOP))
    c.box((TX0 - 0.35, TY0 - 0.35, S1_TOP), (TX1 + 0.35, TY1 + 0.35, LEDGE_TOP))
    c.box((UX0, UY0, LEDGE_TOP), (UX1, UY1, T_TOP))
    c.box((BX0, BY0, B_Z0), (BX1, BY1, B_Z1))
    c.box((FX0 - 0.3, FY0 - 0.3, B_Z1), (FX1 + 0.3, FY0 + 0.3, RAIL_TOP))
    c.box((FX0 - 0.3, FY1 - 0.3, B_Z1), (FX1 + 0.3, FY1 + 0.3, RAIL_TOP))
    c.box((FX0 - 0.3, FY0 + 0.3, B_Z1), (FX0 + 0.3, FY1 - 0.3, RAIL_TOP))
    c.box((FX1 - 0.3, FY0 + 0.3, B_Z1), (FX1 + 0.3, FY1 - 0.3, RAIL_TOP))
    c.box((LAN_CX - 3.5, LAN_CY - 3.5, B_Z1), (LAN_CX + 3.5, LAN_CY + 3.5, LAN_Z1))
    c.box((LAN_CX - 3.7, LAN_CY - 3.7, LAN_Z1), (LAN_CX + 3.7, LAN_CY + 3.7, LAN_Z1 + 3.05))
    c.box((TCX - CREST_W / 2, TY0 - 0.8, CREST_Z1 - CREST_H * 0.55), (TCX + CREST_W / 2, TY0, CREST_Z1))
    c.box((BR_X0, BR_Y0, BR_Z0 - 0.9), (BR_X1, BR_Y1, BR_Z1))
    c.box((ROOF_X1, BR_Y0, BR_Z1), (BR_X1, BR_Y0 + 0.5, BR_Z1 + 2.6))
    c.box((ROOF_X1, BR_Y1 - 0.5, BR_Z1), (BR_X1, BR_Y1, BR_Z1 + 2.6))
    c.box((ROOF_X1 - 2.2, BR_Y0 + 0.2, ROOF_TOP), (BR_X0, BR_Y1 - 0.2, ROOF_TOP + 0.5))
    c.box((52.5, QY0 - 1.2, 0.0), (57.5, QY0, 0.3))
    stair_col(c)


def build():
    import bpy  # noqa: F401
    patch_lod_names()
    patch_lod_targets()
    mat = lego.material("MI_HQAddons_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv3", "Lv4", "Lv5")}

    def out(name, b, node):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[hqaddons] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    for layer, fn in (("L01_Base", station_base), ("L02_Walls", station_walls), ("L03_Trim", station_trim),
                      ("L04_Front", station_front), ("L05_Roof", station_roof)):
        b = lego.B()
        fn(b)
        out("Lv3_" + layer, b, "Lv3")
    c = lego.B()
    station_col(c)
    out_cols("Lv3", c)

    b = lego.B()
    wing_base(b)
    block_base(b)
    out("Lv4_L01_Base", b, "Lv4")

    b = lego.B()
    wing_walls(b)
    block_walls(b)
    out("Lv4_L02_Walls", b, "Lv4")

    b = lego.B()
    wing_trim(b)
    block_trim(b)
    hall_canopy(b)
    out("Lv4_L03_Trim", b, "Lv4")

    b = lego.B()
    wing_interior(b)
    out("Lv4_L04_Interior", b, "Lv4")

    b = lego.B()
    wing_roof(b)
    block_roof(b)
    out("Lv4_L05_Roof", b, "Lv4")

    b = lego.B()
    wing_mast(b)
    out("Lv4_L06_Mast", b, "Lv4")

    c = lego.B()
    wing_col(c)
    out_cols("Lv4", c)

    b = lego.B()
    tower_base(b)
    out("Lv5_L01_Base", b, "Lv5")

    b = lego.B()
    tower_walls(b)
    out("Lv5_L02_Tower", b, "Lv5")

    b = lego.B()
    tower_trim(b)
    out("Lv5_L03_Trim", b, "Lv5")

    b = lego.B()
    tower_balcony(b)
    out("Lv5_L04_Balcony", b, "Lv5")

    b = lego.B()
    tower_lantern(b)
    out("Lv5_L05_Lantern", b, "Lv5")

    b = lego.B()
    tower_beacon(b)
    out("Lv5_L05_Beacon", b, "Lv5")

    c = lego.B()
    tower_col(c)
    out_cols("Lv5", c)

    atts = []
    for name, loc in (("ATT_Sign_03", SIGN_AT), ("ATT_Work_Radio", (39.6, 4.0, FLOOR_TOP)),
                      ("ATT_RadioMast", (MAST_X, MAST_Y, PAD_TOP)),
                      ("ATT_Beacon", (LAN_CX, LAN_CY, LAMP_Z0)),
                      ("ATT_Balcony", (LAN_CX, FY0 - 0.5, B_Z1))):
        atts.append(lego.attach(name, loc))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[hqaddons] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    LOD1_K[0] = min(1.0, LOD1_CAP / (0.5 * total))
    print("[hqaddons] LOD0 %d tris in %d meshes; LOD1 share x%.3f" % (total, sum(e["role"] == "visual" for e in meshes),
                                                                     LOD1_K[0]))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "the Lv3 station shell (56 x 39 incl. the entrance bay), the Lv4 two-storey radio wing against its east wall and the Lv5 "
                     "beacon tower beside it, joined by a walkway on one base, on the station's 54 x 32 stud lot "
                     "(isle 0,-12); front -Y, origin the HQ ground "
                     "centre, built at 1x (place at the HQ frame with no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "LOD2 triangles": "LOD2 keeps the add-ons' 25% share (patch_lod_targets): the 3000 hero ceiling would "
                              "collapse the small Lv4/Lv5 Lego detail meshes",
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_RescueHQ / M_Bld_Depot), no PBR "
                            "scans",
            "naming": "gameplay node/layer names (docs/25 A/B/J): Lv4_L01_..., Lv5_L01_..., Lv4_Col01_COL.., "
                      "Lv5_Col01_COL..; the FBX importer flattens empty parents, so the node name is the mesh name "
                      "prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "station_front", "target": [0.0, -18.0, 12.0], "dist": 50, "az": 0, "el": 12},
            {"name": "station_door", "target": [0.0, -20.0, 8.0], "dist": 24, "az": 15, "el": 6},
            {"name": "radio_wing", "target": [35.0, 3.0, 8.0], "dist": 40, "az": 30, "el": 10},
            {"name": "radio_room", "target": [35.0, 3.0, 5.5], "dist": 18, "az": 0, "el": 2},
            {"name": "beacon_tower", "target": [55.0, 3.0, 24.0], "dist": 78, "az": 25, "el": 12},
            {"name": "lantern", "target": [55.0, 3.0, 43.5], "dist": 20, "az": 15, "el": 8},
            {"name": "bridge", "target": [46.9, -5.0, 11.0], "dist": 46, "az": -30, "el": 20},
            {"name": "crest", "target": [55.0, -1.5, 14.6], "dist": 20, "az": 0, "el": 0},
        ],
    }
