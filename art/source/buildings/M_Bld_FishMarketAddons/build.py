"""M_Bld_FishMarketAddons: the Fish Market's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

Lv1 (PERF-BL9, 2026-11-01) refines the code-built `fishMarket()` (src/shared/DockPieces.luau; its Parts stay the
fallback): two open-front booths (blue counter + white studded top + fish sticker, ice tray of brick fish, side cheeks,
white posts, a 7-stripe mono-pitch roof with a stepped valance, stud rows and a studded ridge cap), crates of brick
fish, the big orange fish sticker on the left booth's roof, a blue board for the code name sign (ATT_Sign_01) on the
right one, ice crates, a dial scale, the centre fish crate + barrel, the drying rack, the flag mast and the island canopy (Lv1_L06_Rack, dropped at Lv3)
and stud-topped white brick yard walls with blue gate / rope posts. Lv2 adds a gate arch with a fish board. All at
the market's final frame: 40 x 34 stud lot, ground at z 0, plinth top z 0.92 (the code plinth is 0.8
studs at 1x, scaled 1.15), front -Y (Roblox -Z), origin the market's ground centre. Place at the market frame with no
extra scale.

Lv2 (engine: 2 -> 4 fish slots): two more market stalls in the front corners (r3), facing the path behind the low front wall. Each has a
blue counter with a white top, two blue posts, a seven-stripe blue/white studded awning with a stepped front edge and
an orange fish plaque on top (reads from above), an inset light-blue ice tray with a dark rim holding one row of four
big Lego fish (silver, orange, yellow; body, wedge tail, stud eye). Behind the counter the vendor stands on a smooth
white 3-stud tile between two brown slatted crate stacks. The tan pads carry a 1-stud grid of studs.

Lv3 (engine: 4 -> 8 fish slots): a walk-in smokehouse at the back centre on a 0.8 blue-trim plinth with a doorstep, built at
9 x 8 studs then scaled 1.45 wide/tall x 1.25 deep (r4, sh_xf: ridge ~25, door ~9.6 wide; a red/white studded door awning, red fish
plaque, studded white eaves, red brick chimney; a 4-fish smoke rack + brazier and two barrels out front, unscaled), brown plank walls on a
blue base course, a blue gable roof with a studded dark ridge cap and brown gables carrying a gold fish glyph, and a
red brick chimney with a studded cap. The doorway is 6.6 studs wide. Inside: two brown/tan fish racks along the side
walls with smoked orange/gold fish, a central rail with five hanging smoked fish; outside, two open plank door leaves on the porch and
a smoke rack with a brazier. The floor is clear.

Each level is a top-level node (Lv2, Lv3) holding 5-6 construction layers (L01_* bottom to L06_* top), one palette
mesh per layer (flat colours via UVs, one draw call per layer, like M_Bld_Depot). Collision is one simple box per
object, <Node>_ColNN_COL (Roblox hulls each mesh, so a merged proxy would fill the doorway): counters, crates, upper
posts and awnings; smokehouse walls in six bites, the roof and chimney overhead, the side racks, bench and firewood, so the door and the interior walkway stay open.

    python3 art/source/buildings/M_Bld_FishMarketAddons/maketex.py \
        --out build/prod/M_Bld_FishMarketAddons/textures/M_Bld_FishMarketAddons --name FishMarket --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_FishMarketAddons/build.py \
        --out-root build/prod/M_Bld_FishMarketAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_FishMarketAddons"
BUDGET = "hero_building"   # Lv1 joined (PERF-BL9): 40k class, one flat palette set (waived)
TIER = "standard"
SET_NAME, SET = "FishMarket", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_FishMarket_Brick_ALB.png")

FLOOR = 0.92
PAD = 1.03                                          # r3: above the Lv1 plaza tiles (top FLOOR + 0.06)
COUNTER_TOP, POST_TOP, AWNING_Z = 2.76, 11.3, 11.2   # r6: Lv2 corner stall awnings +1.5 bricks (peak above the booths)
AW_DY = -1.0                                        # r6: the Lv2 awnings 1 stud forward over the front wall
AW_OUT = 1.4                                        # r6b: the +X stall's awnings slid outward, clear of the name sign
CS_X, CS_Y, CS_HW = 17.7, -16.45, 2.9                # r3: Lv2 stall counter centre (front corners) + half width
TIER_DY, TIER_DZ, TIER_HW, TIER_HS = 1.35, 1.35, 3.0, 1.2  # raised second awning tier (centre offset, half sizes)
AWNING_TILT = math.radians(12.0)
AW_HALF_W, AW_HALF_S, AW_T = 3.9525, 2.53, 0.23     # awning half width, half length along the slope, half thickness
AW_STRIPES = 7
STUD_R, STUD_H = 0.32, 0.2                          # Lego stud on a 1-stud grid

SH_X0, SH_X1 = -3.0, 6.0
SH_Y0, SH_Y1 = 8.0, 16.0
WALL = 0.6
COURSE = (9.8 - PAD) / 9.0                          # plank course height (r1: 9 courses to a 9.8 eave)
N_COURSE = 14                                       # r2: two storeys, roof + stack clear the Lv2 gate from the path
EAVE = PAD + N_COURSE * COURSE
RIDGE = EAVE + 2.2
DZ = EAVE - 9.8                                     # lift of everything that sat at the r1 eave
ROOF_X0, ROOF_X1 = -3.6, 6.6
ROOF_Y0, ROOF_Y1 = 7.4, 16.6
DOOR_X0, DOOR_X1 = -1.8, 4.8                        # 6.0 clear between the 0.3 frames' inner edges is 5.4; 6.6 outer
DOOR_TOP = PAD + 6 * COURSE
WIN_Y0, WIN_Y1 = 10.6, 13.0
WIN_Z0, WIN_Z1 = PAD + 4 * COURSE, PAD + 6 * COURSE
CH_X0, CH_X1 = 0.7, 2.3
CH_Y0, CH_Y1 = 13.7, 15.2
CH_TOP = RIDGE + 2.75                                # r5: +1 brick in world (r4 1.9)
CAP_TOP = CH_TOP + 0.3
WIN2_Z0, WIN2_Z1 = PAD + 10 * COURSE, PAD + 12 * COURSE   # upper-storey windows (sides + front)
FRONT_WINS = ((-2.2, -0.4), (3.4, 5.2))
SH_DX, SH_LIFT = -2.25, 0.8                          # r3: the smokehouse (built at x -3..6) slides left onto a plinth so
                                                    # its gable + upper storey stand clear between the two roof signs
SH_S = (1.45, 1.25, 1.45)                            # r4: 1.45x wider + taller (1.25 deep: the porch must clear the island)
SH_XC, SH_YB = 0.0, 17.1                             # r4: centred on the gate axis, plinth back just inside the back wall


def sh_xf(b, lift=SH_LIFT):
    """r4: the smokehouse's build frame (x -3..6, plinth back y 16.3, plaza z) -> centred, scaled, lifted."""
    sx, sy, sz = SH_S
    b.v = [(SH_XC + (x - 1.5) * sx, SH_YB + (y - 16.3) * sy, FLOOR + (z + lift - FLOOR) * sz) for x, y, z in b.v]
    return b


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def patch_lod_targets():
    """LODs keep the large_prop shares (50% / 25%) the add-ons shipped with: the hero_building LOD2 ceiling (3000 for
    the asset) collapses the small Lego detail meshes (session-only patch, like M_Bld_HQAddons)."""
    import budgets
    orig = getattr(budgets, "_fm_orig_lod_target", budgets.lod_target)
    budgets._fm_orig_lod_target = orig
    budgets.lod_target = lambda budget_class, lod, lod0_tris, asset_tris=None: orig("large_prop", lod, lod0_tris)


def prism_y(b, y0, y1, profile, c):
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def prism_z(b, z0, z1, profile, c):
    """A plan-view (x, y) polygon extruded up from z0 to z1 (fish tails)."""
    n = len(profile)
    verts = [(x, y, z0) for x, y in profile] + [(x, y, z1) for x, y in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def place(dst, src, cx, cy, left):
    base = len(dst.v)
    if left:
        dst.v.extend((cx - y, cy + x, z) for x, y, z in src.v)
    else:
        dst.v.extend((cx + y, cy - x, z) for x, y, z in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


def place_rot(dst, src, cx, cy, z, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    base = len(dst.v)
    dst.v.extend((cx + x * ca - y * sa, cy + x * sa + y * ca, z + zz) for x, y, zz in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


def stud(b, x, y, z, c, r=STUD_R, h=STUD_H):
    b.cyl(x, y, z, z + h, r, c, 6)
    del b.f[-2]                                         # r5: the bottom cap sits on the brick (hidden, 4 tris)


def grid_studs(b, xs, ys, z, c, skip=()):
    for x in xs:
        for y in ys:
            if not any(x0 - STUD_R < x < x1 + STUD_R and y0 - STUD_R < y < y1 + STUD_R for x0, y0, x1, y1 in skip):
                stud(b, x, y, z, c)


def pad(b, x0, x1, y0, y1):
    b.box((x0, y0, FLOOR), (x1, y1, PAD), P.TAN, bevel=0.01)
    t, h = 0.12, PAD + 0.12
    b.box((x0, y0, FLOOR), (x1, y0 + t, h), P.BLUE, bevel=0.02)
    b.box((x0, y1 - t, FLOOR), (x1, y1, h), P.BLUE, bevel=0.02)
    b.box((x0, y0 + t, FLOOR), (x0 + t, y1 - t, h), P.BLUE, bevel=0.02)
    b.box((x1 - t, y0 + t, FLOOR), (x1, y1 - t, h), P.BLUE, bevel=0.02)


# ------------------------------------------------------------------ stall (local frame: x along the counter, -y customer side)
CS_HD = 1.1                                         # Lv2 corner stall counter half depth
SPOT = (-1.0, 1.4, 1.0, 3.2)                        # smooth white standing tile behind the counter (ATT_Work_Stall*)
TRAY = (-2.85, -1.5, 2.85, 1.5)                     # ice tray between the posts, dark rim
FISH_SETS = ((P.ORANGE, P.YELLOW), (P.LBG, P.DBG), (P.YELLOW, P.ORANGE), (P.LBG, P.DBG))


def fish(b, cx, cy, z, L, body, accent, ang=0.0, eye=P.WHITE):
    """A Lego fish ~L studs long, head +x before rotation: body brick, wedge tail, accent dorsal plate, stud eye."""
    f = lego.B()
    h, w = 0.3 * L, 0.17 * L
    f.box((-0.22 * L, -w, 0), (0.5 * L, w, h), body, bevel=0.08)
    prism_z(f, 0.06 * L, h - 0.04 * L, [(-0.2 * L, 0), (-0.5 * L, -0.27 * L), (-0.5 * L, 0.27 * L)], accent)
    f.box((-0.12 * L, -0.06 * L, h), (0.22 * L, 0.06 * L, h + 0.06 * L), accent, bevel=0.02)
    f.cyl(0.36 * L, 0.0, h, h + 0.08 * L, 0.075 * L, eye, 6)
    place_rot(b, f, cx, cy, z, ang)


def flat_fish(b, cx, cy, z, L, body, accent, ang):
    """A fish lying on its side on the ice, head +x before rotation: pointed body plate, V tail, ink eye."""
    f = lego.B()
    w = 0.19 * L
    prism_z(f, 0.0, 0.35, [(0.5 * L, 0), (0.3 * L, -w), (-0.25 * L, -0.7 * w), (-0.32 * L, 0),
                           (-0.25 * L, 0.7 * w), (0.3 * L, w)], body)
    prism_z(f, 0.05, 0.27, [(-0.28 * L, 0), (-0.5 * L, -0.21 * L), (-0.5 * L, 0.21 * L)], accent)
    f.box((0.12 * L, -0.8 * w, 0.35), (0.17 * L, 0.8 * w, 0.4), accent, bevel=0.01)            # gill line
    f.cyl(0.34 * L, 0.0, 0.35, 0.42, 0.11, P.INK, 6)
    place_rot(b, f, cx, cy, z, ang)


def slat_crate(b, x0, y0, x1, y1, z0, h):
    """Brown crate, tan slats on the front and both sides, studs on the top."""
    b.box((x0, y0, z0), (x1, y1, z0 + h), P.BROWN, bevel=0.05)
    n = 2 if h < 1.3 else 3
    for k in range(n):
        z = z0 + 0.12 + k * (h - 0.12) / n
        sh = (h - 0.12) / n - 0.14
        b.box((x0 + 0.1, y0 - 0.05, z), (x1 - 0.1, y0 + 0.02, z + sh), P.TAN, bevel=0.02)
        for xs in (x0 - 0.05, x1 - 0.02):
            b.box((xs, y0 + 0.1, z), (xs + 0.07, y1 - 0.1, z + sh), P.TAN, bevel=0.02)




def ice_stack(b, x0, y0, x1, y1, z0, hs):
    """r6: a stack of 1.5x ice-blue crates (white band + rim, each tier inset), ice and two big orange fish on top."""
    z = z0
    for i, h in enumerate(hs):
        d = 0.18 * i
        a0, a1, c0, c1 = x0 + d, x1 - d, y0 + d, y1 - d
        b.box((a0, c0, z), (a1, c1, z + h), P.GLASS, bevel=0.05)
        b.box((a0 - 0.05, c0 - 0.05, z + 0.3 * h), (a1 + 0.05, c1 + 0.05, z + 0.5 * h), P.WHITE, bevel=0.02)
        b.box((a0 - 0.07, c0 - 0.07, z + h - 0.22), (a1 + 0.07, c1 + 0.07, z + h), P.WHITE, bevel=0.03)
        z += h - 0.04
    top = z + 0.04
    b.box((a0 + 0.2, c0 + 0.2, top - 0.05), (a1 - 0.2, c1 - 0.2, top + 0.08), P.GLASS, bevel=0.02)
    L = 0.72 * (a1 - a0)
    for k, (fy, ang) in enumerate(((0.3, 0.12), (0.7, math.pi - 0.12))):
        fish(b, (a0 + a1) / 2, c0 + fy * (c1 - c0), top + 0.08, L, P.ORANGE, (P.YELLOW, P.RED)[k], ang)


def stall_counter(b):
    """Lv2 corner stall (local frame, -y = the path): blue counter, white kick course and studded top, the tan pad."""
    pad(b, -CS_HW - 0.05, CS_HW + 0.05, -CS_HD - 0.1, 3.5)
    b.box((-CS_HW, -CS_HD, PAD), (CS_HW, CS_HD, 2.5), P.BLUE)
    b.box((-CS_HW - 0.05, -CS_HD - 0.05, PAD), (CS_HW + 0.05, CS_HD + 0.05, 1.5), P.WHITE, bevel=0.04)
    b.box((-CS_HW - 0.1, -CS_HD - 0.1, 2.5), (CS_HW + 0.1, CS_HD + 0.1, COUNTER_TOP), P.WHITE, bevel=0.06)
    for x in (-CS_HW + 0.3, CS_HW - 0.3):
        for y in (-0.6, 0.6):
            stud(b, x, y, COUNTER_TOP, P.WHITE)
    b.box((SPOT[0], SPOT[1], PAD), (SPOT[2], SPOT[3], PAD + 0.1), P.WHITE, bevel=0.03)


def stall_frames(b):
    """r4: 1x1 white brick posts on red base plates, red bands; tan crate fronts on the counter (a crate counter)."""
    for x in (-CS_HW + 0.35, CS_HW - 0.35):
        b.box((x - 0.5, -0.5, COUNTER_TOP), (x + 0.5, 0.5, COUNTER_TOP + 0.22), P.RED, bevel=0.03)
        z = COUNTER_TOP + 0.22
        while z < POST_TOP - 0.05:
            ze = min(z + 1.2, POST_TOP)
            b.box((x - 0.3, -0.3, z), (x + 0.3, 0.3, ze), P.WHITE, bevel=0.05)
            z = ze
        for z in (4.6, 6.6):
            b.box((x - 0.36, -0.36, z + 0.1), (x + 0.36, 0.36, z + 0.5), P.RED, bevel=0.03)
    for x0 in (-CS_HW + 0.15, 0.1):                          # two crate faces on the path side of the counter
        x1 = x0 + CS_HW - 0.25
        y = -CS_HD - 0.05
        b.box((x0, y - 0.12, PAD + 0.05), (x1, y + 0.02, 2.45), P.BROWN, bevel=0.04)
        for za in (PAD + 0.2, PAD + 0.75):
            b.box((x0 + 0.12, y - 0.18, za), (x1 - 0.12, y - 0.1, za + 0.42), P.TAN, bevel=0.02)


STEP = 0.2                                          # r4: every other awning stripe stands 0.2 proud (reads as bricks)


def up(front_top, sa, ca, i):
    """The front top edge of stripe i (odd stripes are STEP thicker along the slope normal)."""
    d = STEP if i % 2 else 0.0
    return (front_top[0] - d * sa, front_top[1] + d * ca)


def scallop(b, x0, x1, y0, y1, z_t, z_b, c):
    """r4: a valance tab with a round bottom (front view), y0..y1 deep."""
    hw, xc = (x1 - x0) / 2, (x0 + x1) / 2
    ry = min(hw, z_t - z_b - 0.1)
    arc = [(xc + hw * math.cos(math.pi + a * math.pi / 6), z_b + ry + ry * math.sin(math.pi + a * math.pi / 6))
           for a in range(7)]
    prism_y_ccw(b, y0, y1, [(x1, z_t), (x0, z_t)] + arc, c)


def awning_slab(b, k, yc, zc, hw, hs, drops=(0.5, 0.25), cols=None):
    """Seven red/white stripes tilted 12 deg up to the back, every other one stepped up, a scalloped valance; returns
    the front top edge (y, z)."""
    ca, sa = math.cos(AWNING_TILT), math.sin(AWNING_TILT)
    dy, dz = hs * ca, hs * sa
    ty, tz = -AW_T * sa, AW_T * ca
    profile = [(yc + dy + ty, zc + dz + tz), (yc + dy - ty, zc + dz - tz),
               (yc - dy - ty, zc - dz - tz), (yc - dy + ty, zc - dz + tz)]
    front_top = (yc - dy + ty, zc - dz + tz)
    front_bot_z = zc - dz - tz
    sw = 2 * hw / AW_STRIPES
    for i in range(AW_STRIPES):
        c = (cols or (P.WHITE, P.RED))[(i + k) % 2]
        x0 = -hw + i * sw
        d = STEP if i % 2 else 0.0
        b.prof_x(x0, x0 + sw, [(profile[0][0] - d * sa, profile[0][1] + d * ca), profile[1], profile[2],
                               (profile[3][0] - d * sa, profile[3][1] + d * ca)], c)
        scallop(b, x0 + 0.02, x0 + sw - 0.02, front_top[0] - 0.06, front_top[0] + 0.14, front_bot_z + 0.2,
                front_bot_z - drops[i % 2] - 0.15, c)
    return front_top, ca, sa, sw


def stall_awnings(b, k):
    front_top, ca, sa, sw = awning_slab(b, k, AW_DY, AWNING_Z, AW_HALF_W, AW_HALF_S)
    for i in range(AW_STRIPES):
        x0 = -AW_HALF_W + i * sw
        c = (P.WHITE, P.RED)[(i + k) % 2]
        for u in (0.88, 1.98, 3.08, 4.18):                      # studs along the slope, one per stripe per row
            if not (u in (0.88, 1.98) and abs(x0 + sw / 2) < 2.75) and not (u > 2.5 and abs(x0 + sw / 2) < TIER_HW):
                _tilted_stud(b, x0 + sw / 2, up(front_top, sa, ca, i), u, ca, sa, c)
    plaque = lambda pts, o0, o1, col: _tilted_poly(b, pts, front_top, ca, sa, o0, o1, col)
    du = -1.2                                                   # fish plaque, read from above, in front of the tier
    plaque([(-2.4, 1.45 + du), (2.4, 1.45 + du), (2.4, 3.65 + du), (-2.4, 3.65 + du)], -0.05, 0.32, P.DBG)
    plaque([(-1.1, 1.85 + du), (1.4, 1.85 + du), (1.4, 3.25 + du), (-1.1, 3.25 + du)], 0.32, 0.44, P.ORANGE)
    plaque([(-0.8, 2.55 + du), (-2.0, 1.7 + du), (-2.0, 3.4 + du)], 0.32, 0.44, P.YELLOW)
    plaque([(-0.4, 3.25 + du), (0.6, 3.25 + du), (0.6, 3.45 + du), (-0.4, 3.45 + du)], 0.32, 0.44, P.YELLOW)
    plaque([(0.75, 2.6 + du), (1.1, 2.6 + du), (1.1, 2.95 + du), (0.75, 2.95 + du)], 0.44, 0.5, P.WHITE)
    ty = TIER_DY + AW_DY
    zc = AWNING_Z + TIER_DY * math.tan(AWNING_TILT) + TIER_DZ    # raised second tier over the back half
    tf, _, _, tsw = awning_slab(b, k + 1, ty, zc, TIER_HW, TIER_HS, drops=(0.35, 0.18))
    for x in (-TIER_HW + 0.5, TIER_HW - 0.5):                   # two white posts from the main awning
        z0 = AWNING_Z + TIER_DY * math.tan(AWNING_TILT)
        b.box((x - 0.25, ty - 0.25, z0), (x + 0.25, ty + 0.25, zc), P.WHITE, bevel=0.03)
    for i in range(AW_STRIPES):                                 # a stud row along the tier's back
        _tilted_stud(b, -TIER_HW + (i + 0.5) * tsw, up(tf, sa, ca, i), 2 * TIER_HS - 0.45, ca, sa,
                     (P.WHITE, P.RED)[(i + k + 1) % 2])
    if k == 1:                                                  # k 1 = the +X stall (stalls()), under the ATT_Sign_01 sign
        b.v[:] = [(x + AW_OUT, y, z) for x, y, z in b.v]


def _tilted_poly(b, pts, front_top, ca, sa, o0, o1, c):
    """A plan polygon (x, u along the slope) on the awning top, extruded along its normal from o0 to o1."""
    if sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1])) > 0:
        pts = pts[::-1]                                         # clockwise, like prism_z
    p = lambda x, u, o: (x, front_top[0] + u * ca - o * sa, front_top[1] + u * sa + o * ca)
    n = len(pts)
    verts = [p(x, u, o0) for x, u in pts] + [p(x, u, o1) for x, u in pts]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def _tilted_stud(b, x, front_top, u, ca, sa, c):
    y0, z0 = front_top[0] + u * ca, front_top[1] + u * sa
    n = (0.0, -sa, ca)
    ring = [(STUD_R * math.cos(2 * math.pi * i / 6), STUD_R * math.sin(2 * math.pi * i / 6)) for i in range(6)]
    base = [(x + dx, y0 + dt * ca - 0.05 * n[1], z0 + dt * sa - 0.05 * n[2]) for dx, dt in ring]
    top = [(vx, vy + (STUD_H + 0.05) * n[1], vz + (STUD_H + 0.05) * n[2]) for vx, vy, vz in base]
    faces = [(i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i) for i in range(6)]
    faces += [tuple(range(6, 12))]                          # r5: no bottom cap (sunk 0.05 into the surface)
    b._emit(base + top, faces, c)


def stall_stock(b):
    x0, y0, x1, y1 = -2.2, -0.95, 2.2, 0.95
    r, rim_top, ice_top = 0.22, COUNTER_TOP + 0.3, COUNTER_TOP + 0.16
    for lo, hi in (((x0, y0), (x1, y0 + r)), ((x0, y1 - r), (x1, y1)),
                   ((x0, y0 + r), (x0 + r, y1 - r)), ((x1 - r, y0 + r), (x1, y1 - r))):
        b.box((*lo, COUNTER_TOP), (*hi, rim_top), P.DBG, bevel=0.04)
    b.box((x0 + r, y0 + r, COUNTER_TOP), (x1 - r, y1 - r, ice_top), P.GLASS, bevel=0.02)
    for i, cx in enumerate((-1.5, -0.5, 0.5, 1.5)):
        body, accent = FISH_SETS[i]
        flat_fish(b, cx, 0.0, ice_top, 1.6, body, accent, -math.pi / 2)
    ice_stack(b, 1.15, 1.3, 3.25, 3.4, PAD, (1.3, 1.0))


def stall_col(c, cx, mirror):
    local = lego.B()
    local.box((-CS_HW - 0.1, -CS_HD - 0.1, PAD), (CS_HW + 0.1, CS_HD + 0.1, COUNTER_TOP), P.WHITE)
    ox = 0.0 if mirror else AW_OUT                          # r6b: follows the +X stall's slid awning
    local.box((ox - AW_HALF_W, AW_DY - AW_HALF_S, AWNING_Z - 0.76), (ox + AW_HALF_W, AW_DY + AW_HALF_S, AWNING_Z + 0.74),
              P.WHITE)
    for x in (-CS_HW + 0.35, CS_HW - 0.35):
        local.box((x - 0.3, -0.3, COUNTER_TOP), (x + 0.3, 0.3, POST_TOP), P.WHITE)
    local.box((1.15, 1.3, PAD), (3.25, 3.4, PAD + 2.3), P.WHITE)
    place_m(c, local, cx, CS_Y, mirror)
def planks(b, x0, y0, x1, y1, k, seam=True):
    z = PAD + k * COURSE
    if not seam:                                            # the back wall (never seen up close) stays solid
        b.box((x0, y0, z), (x1, y1, z + COURSE), P.BROWN, bevel=0.07)
        return
    e = 0.08 * (k % 2)                                      # r6: every other course stands proud (~0.1 in world)
    side = x1 - x0 < y1 - y0
    b.box((x0 - e * side, y0 - e * (not side), z + 0.035), (x1 + e * side, y1 + e * (not side), z + COURSE - 0.035),
          P.BROWN, bevel=0.07)
    ins, end = 0.12 + 0.03 * (k % 2), 0.05 + 0.03 * (k % 2)   # dark core behind the seams (alternate so no face is shared)
    if side:
        b.box((x0 + ins, y0 + end, z - 0.03), (x1 - ins, y1 - end, z + COURSE + 0.03), P.BLACK, bevel=0.0)
    else:
        b.box((x0 + end, y0 + ins, z - 0.03), (x1 - end, y1 - ins, z + COURSE + 0.03), P.BLACK, bevel=0.0)


def smokehouse_walls(b):
    yf0, yf1 = SH_Y0, SH_Y0 + WALL
    yb0, yb1 = SH_Y1 - WALL, SH_Y1
    for k in range(N_COURSE):
        if k in (10, 11):                                   # upper front windows
            xs = [SH_X0] + [x for w in FRONT_WINS for x in w] + [SH_X1]
            for x0, x1 in zip(xs[::2], xs[1::2]):
                planks(b, x0, yf0, x1, yf1, k)
        else:
            planks(b, SH_X0, yf0, DOOR_X0, yf1, k)
            planks(b, DOOR_X1, yf0, SH_X1, yf1, k)
            if k >= 6:
                planks(b, DOOR_X0, yf0, DOOR_X1, yf1, k)
        planks(b, SH_X0, yb0, SH_X1, yb1, k, seam=False)
        for x0, x1 in ((SH_X0, SH_X0 + WALL), (SH_X1 - WALL, SH_X1)):
            if k in (4, 5, 10, 11):
                planks(b, x0, yf1, x1, WIN_Y0, k)
                planks(b, x0, WIN_Y1, x1, yb0, k)
            else:
                planks(b, x0, yf1, x1, yb0, k)
    for face in (SH_X0, SH_X1):
        o0, o1 = (face - 0.25, face + 0.04) if face == SH_X0 else (face - 0.04, face + 0.25)   # proud outside
        for z0, z1 in ((WIN_Z0, WIN_Z1), (WIN2_Z0, WIN2_Z1)):
            b.box((o0, WIN_Y0 - 0.2, z0 - 0.2), (o1, WIN_Y1 + 0.2, z0 + 0.1), P.WHITE, bevel=0.02)   # r5: white frames
            b.box((o0, WIN_Y0 - 0.2, z1 - 0.1), (o1, WIN_Y1 + 0.2, z1 + 0.2), P.WHITE, bevel=0.02)
            b.box((o0, WIN_Y0 - 0.2, z0 + 0.1), (o1, WIN_Y0 + 0.1, z1 - 0.1), P.WHITE, bevel=0.02)
            b.box((o0, WIN_Y1 - 0.1, z0 + 0.1), (o1, WIN_Y1 + 0.2, z1 - 0.1), P.WHITE, bevel=0.02)
            sg = -1 if face == SH_X0 else 1
            s0, s1 = sorted((face + sg * 0.15, face - sg * 0.05))
            for ya, yb in ((WIN_Y0 - 0.85, WIN_Y0 - 0.25), (WIN_Y1 + 0.25, WIN_Y1 + 0.85)):     # r5: blue shutters
                b.box((s0, ya, z0 + 0.05), (s1, yb, z1 - 0.05), P.BLUE, bevel=0.03)
            g = 0.2 if face == SH_X0 else -0.4
            b.box((face + g, WIN_Y0 + 0.1, z0 + 0.1), (face + g + 0.2, WIN_Y1 - 0.1, z1 - 0.1), P.GLASS, bevel=0.01)
    y = SH_Y0                                               # upper front windows: proud dark frame, inset glass
    for w, (x0, x1) in enumerate(FRONT_WINS):
        z0, z1 = WIN2_Z0, WIN2_Z1
        b.box((x0 - 0.2, y - 0.25, z0 - 0.2), (x1 + 0.2, y + 0.04, z0 + 0.1), P.WHITE, bevel=0.02)
        b.box((x0 - 0.2, y - 0.25, z1 - 0.1), (x1 + 0.2, y + 0.04, z1 + 0.2), P.WHITE, bevel=0.02)
        b.box((x0 - 0.2, y - 0.25, z0 + 0.1), (x0 + 0.1, y + 0.04, z1 - 0.1), P.WHITE, bevel=0.02)
        b.box((x1 - 0.1, y - 0.25, z0 + 0.1), (x1 + 0.2, y + 0.04, z1 - 0.1), P.WHITE, bevel=0.02)
        if w:
            b.box((x0 + 0.1, y + 0.2, z0 + 0.1), (x1 - 0.1, y + 0.4, z1 - 0.1), P.GLASS, bevel=0.01)
            continue
        b.box((x0, y + 0.75, z0), (x1, y + 0.85, z1), P.BLACK, bevel=0.0)    # r5: smoke-rack window: open, a smoky back,
        b.box((x0 - 0.05, y + 0.2, z1 - 0.35), (x1 + 0.05, y + 0.32, z1 - 0.23), P.BROWN, bevel=0.01)   # rail + fish
        for i in range(3):
            fish_hang(b, x0 + 0.42 + i * 0.48, y + 0.26, z1 - 0.29, 0.5, (P.ORANGE, P.YELLOW, P.ORANGE)[i])
        b.box((x0 - 0.3, y - 0.4, z0 - 0.4), (x1 + 0.3, y + 0.05, z0 - 0.12), P.WHITE, bevel=0.03)
    b.box((SH_X0, SH_Y0 - 0.06, PAD), (DOOR_X0, SH_Y0, 1.65), P.BLUE, bevel=0.02)
    b.box((DOOR_X1, SH_Y0 - 0.06, PAD), (SH_X1, SH_Y0, 1.65), P.BLUE, bevel=0.02)
    b.box((SH_X0 - 0.06, SH_Y0, PAD), (SH_X0, SH_Y1, 1.65), P.BLUE, bevel=0.02)
    b.box((SH_X1, SH_Y0, PAD), (SH_X1 + 0.06, SH_Y1, 1.65), P.BLUE, bevel=0.02)
    b.box((SH_X0, SH_Y1, PAD), (SH_X1, SH_Y1 + 0.06, 1.65), P.BLUE, bevel=0.02)


def smokehouse_roof(b):
    prism_y(b, SH_Y0, SH_Y0 + 0.4, [(SH_X0, EAVE), (SH_X1, EAVE), (1.5, RIDGE)], P.BROWN)
    prism_y(b, SH_Y1 - 0.4, SH_Y1, [(SH_X0, EAVE), (SH_X1, EAVE), (1.5, RIDGE)], P.BROWN)
    prism_y(b, ROOF_Y0, ROOF_Y1, [(ROOF_X0, EAVE), (ROOF_X0, EAVE + 0.35), (1.5, RIDGE + 0.35), (1.5, RIDGE)], P.BLUE)
    prism_y(b, ROOF_Y0, ROOF_Y1, [(1.5, RIDGE), (1.5, RIDGE + 0.35), (ROOF_X1, EAVE + 0.35), (ROOF_X1, EAVE)], P.BLUE)
    n = 9                                                   # r5: a ridge-cap tile row (0.05 seams), a stud each
    for i in range(n):
        ya = ROOF_Y0 - 0.1 + i * (ROOF_Y1 - ROOF_Y0 + 0.2) / n
        yb = ya + (ROOF_Y1 - ROOF_Y0 + 0.2) / n
        b.box((1.15, ya + 0.025, RIDGE + 0.3), (1.85, yb - 0.025, RIDGE + 0.65), P.WHITE, bevel=0.05)
        stud(b, 1.5, (ya + yb) / 2, RIDGE + 0.65, P.WHITE, r=0.24)
    for k in (1, 2, 3):                                     # gable plank seams (clear of the gold fish glyph)
        z = EAVE + k * (RIDGE - EAVE) / 4.0
        hw = (SH_X1 - SH_X0) / 2.0 * (1.0 - (z - EAVE) / (RIDGE - EAVE)) - 0.15
        for ya, yb in ((SH_Y0 - 0.05, SH_Y0 + 0.01), (SH_Y1 - 0.01, SH_Y1 + 0.05)):
            spans = [(1.5 - hw, 1.5 + hw)]
            if ya < SH_Y0 and EAVE + 0.2 < z < EAVE + 1.4:
                spans = [(1.5 - hw, 0.35), (2.95, 1.5 + hw)]
            for xa, xb in spans:
                if xb - xa > 0.2:
                    b.box((xa, ya, z - 0.03), (xb, yb, z + 0.03), P.BLACK, bevel=0.0)
    b.box((ROOF_X0, ROOF_Y0 - 0.05, EAVE - 0.15), (ROOF_X1, ROOF_Y0 + 0.15, EAVE + 0.15), P.WHITE, bevel=0.03)
    b.box((ROOF_X0, ROOF_Y1 - 0.15, EAVE - 0.15), (ROOF_X1, ROOF_Y1 + 0.05, EAVE + 0.15), P.WHITE, bevel=0.03)
    b.box((0.5, SH_Y0 - 0.06, 10.25 + DZ), (2.1, SH_Y0, 10.85 + DZ), P.YELLOW, bevel=0.02)     # gold fish glyph on the gable
    b.box((2.1, SH_Y0 - 0.06, 10.15 + DZ), (2.8, SH_Y0, 10.95 + DZ), P.YELLOW, bevel=0.02)
    b.box((1.1, SH_Y0 - 0.06, 10.85 + DZ), (1.6, SH_Y0, 11.05 + DZ), P.YELLOW, bevel=0.02)
    b.box((0.7, SH_Y0 - 0.07, 10.55 + DZ), (0.85, SH_Y0 - 0.06, 10.7 + DZ), P.INK, bevel=0.01)


def side_rack(b, x0, x1, y0, y1):
    for x in (x0 + 0.09, x1 - 0.09):
        for y in (y0 + 0.09, y1 - 0.09):
            b.box((x - 0.09, y - 0.09, PAD), (x + 0.09, y + 0.09, 7.6), P.BROWN)
    for z in (2.2, 4.3, 6.4, 7.6):
        b.box((x0, y0, z - 0.12), (x1, y1, z), P.TAN, bevel=0.02)


def smokehouse_racks(b):
    side_rack(b, -2.4, -1.6, 9.4, 14.6)
    side_rack(b, 4.6, 5.4, 9.4, 14.6)
    b.box((-1.6, 12.73, 8.53), (4.6, 12.87, 8.67), P.BROWN)


def fish_hang(b, cx, cy, rail_z, s=1.0, body=P.ORANGE):
    """A smoked fish hung tail-up in the xz plane (readable from the door): wedge tail, orange body, gold band."""
    top = rail_z - 0.3 * s
    b.box((cx - 0.03 * s, cy - 0.03 * s, top), (cx + 0.03 * s, cy + 0.03 * s, rail_z), P.BROWN)
    prism_y(b, cy - 0.2 * s, cy + 0.2 * s, [(cx - 0.45 * s, top), (cx + 0.45 * s, top), (cx, top - 0.55 * s)], P.YELLOW)
    b.box((cx - 0.38 * s, cy - 0.21 * s, top - 2.1 * s), (cx + 0.38 * s, cy + 0.21 * s, top - 0.55 * s), body, bevel=0.1 * s)
    b.box((cx - 0.3 * s, cy - 0.24 * s, top - 1.55 * s), (cx + 0.3 * s, cy - 0.2 * s, top - 1.0 * s), P.YELLOW, bevel=0.01)
    b.box((cx - 0.2 * s, cy - 0.24 * s, top - 1.95 * s), (cx - 0.06 * s, cy - 0.2 * s, top - 1.8 * s), P.INK, bevel=0.01)


def smokehouse_fish(b):
    b.box((1.0, CH_Y0 + 0.13, 1.3), (2.0, CH_Y0 + 0.17, 2.2), P.WARM, bevel=0.02)
    b.box((1.1, CH_Y0 + 0.11, 1.05), (1.4, CH_Y0 + 0.15, 1.25), P.ORANGE, bevel=0.02)
    b.box((1.6, CH_Y0 + 0.11, 1.05), (1.9, CH_Y0 + 0.15, 1.25), P.ORANGE, bevel=0.02)
    for x in (-2.0, 5.0):
        for y0, z in ((9.8, 2.2), (11.35, 4.3), (12.9, 6.4)):
            fish(b, x, y0 + 0.7, z, 1.45, P.ORANGE, P.YELLOW, ang=math.pi / 2)
    for x in (-1.0, 0.25, 1.5, 2.75, 4.0):
        fish_hang(b, x, 12.8, 8.6)


def smokehouse_chimney(b):
    b.box((0.75, 13.85, PAD), (2.25, 15.15, 2.6), P.DBG, bevel=0.04)
    b.box((CH_X0, CH_Y0, 2.6), (CH_X1, CH_Y1, CH_TOP), P.RED)          # r4: red brick stack, dark courses
    z = 3.2
    while z < CH_TOP - 0.8:
        b.box((CH_X0 - 0.05, CH_Y0 - 0.05, z), (CH_X1 + 0.05, CH_Y1 + 0.05, z + 0.3), P.DBG, bevel=0.02)
        z += 1.6
    b.box((CH_X0 - 0.08, CH_Y0 - 0.08, CH_TOP - 0.35), (CH_X1 + 0.08, CH_Y1 + 0.08, CH_TOP), P.WHITE, bevel=0.03)
    b.box((CH_X0 - 0.15, CH_Y0 - 0.15, CH_TOP), (CH_X1 + 0.15, CH_Y1 + 0.15, CAP_TOP), P.RED, bevel=0.04)   # r5: red cap
    grid_studs(b, (1, 2), (14, 15), CAP_TOP, P.RED)
    z = CAP_TOP + 0.12                                      # smoke-puff cap: three stacked round grey plates
    for dx, r, h, col in ((0.0, 0.75, 0.42, P.LBG), (0.3, 0.95, 0.48, P.LBG), (0.65, 0.68, 0.4, P.WHITE)):
        b.cyl(1.5 + dx, 14.45, z, z + h, r, col, 12)
        z += h - 0.1


def smokehouse_col(c):
    c.box((SH_X0, SH_Y0, PAD), (DOOR_X0 + 0.3, SH_Y0 + WALL, EAVE), P.WHITE)
    c.box((DOOR_X1 - 0.3, SH_Y0, PAD), (SH_X1, SH_Y0 + WALL, EAVE), P.WHITE)
    c.box((DOOR_X0 + 0.3, SH_Y0, DOOR_TOP), (DOOR_X1 - 0.3, SH_Y0 + WALL, EAVE), P.WHITE)
    c.box((SH_X0, SH_Y1 - WALL, PAD), (SH_X1, SH_Y1, EAVE), P.WHITE)
    c.box((SH_X0, SH_Y0 + WALL, PAD), (SH_X0 + WALL, SH_Y1 - WALL, EAVE), P.WHITE)
    c.box((SH_X1 - WALL, SH_Y0 + WALL, PAD), (SH_X1, SH_Y1 - WALL, EAVE), P.WHITE)
    c.box((ROOF_X0, ROOF_Y0, EAVE), (ROOF_X1, ROOF_Y1, RIDGE + 0.6), P.BLUE)
    c.box((CH_X0, CH_Y0, PAD), (CH_X1, CH_Y1, CAP_TOP), P.RED)
    c.box((-2.4, 9.4, PAD), (-1.6, 14.6, 7.6), P.BROWN)
    c.box((4.6, 9.4, PAD), (5.4, 14.6, 7.6), P.BROWN)
    c.box((SH_X0 - 0.5, SH_Y0 - 2.9, FLOOR - SH_LIFT), (SH_X1 + 0.5, SH_Y1 + 0.3, PAD), P.TAN)      # plinth
    c.box((DOOR_X0, SH_Y0 - 3.9, FLOOR - SH_LIFT), (DOOR_X1, SH_Y0 - 2.9, PAD - SH_LIFT / 2), P.TAN)  # doorstep


# ------------------------------------------------------------------ Lv1 market (refines the code `fishMarket()` at 1.15)
# Code spots x 1.15, Blender x = -Roblox x: booths (+-11.15, -11.25), ice crates (+-17.24, -7.57), scale (-16.55, -4.12),
# drying rack (10, 13.5), centre crate (0, -10.1) + barrel, yard walls at |x| 21.15 / y -18.15, rope edge y 18.15.
BOOTH_X, BOOTH_Y = 11.15, -11.25
R_Y0, R_Y1, R_Z0, R_Z1, R_T = -2.7, 4.6, 7.6, 9.0, 0.5    # booth roof: front/back edge (local y), underside z, thickness
R_HW = 4.6
R_ANG = math.atan2(R_Z1 - R_Z0, R_Y1 - R_Y0)
SIGN_Y = BOOTH_Y + 3.5                                     # roof sign boards' front plane (world y)
NAME_SIGN = (11.15, SIGN_Y - 0.25, 13.0)                   # code name sign centre (12.08 x 4.49 x 0.4), ATT_Sign_01
NS_HW, NS_HH = 6.04, 2.245                                 # its half size (r2: 1.5x the r1 8.05 x 2.99)
WALL_X, WALL_T, WALL_Y = 21.15, 0.8, 18.15
GATE_X = 5.75
SCALE_XY = (-6.0, -12.4)                                  # r2: at the left booth's front corner, by the walkway
GATE_TOP, LINTEL_TOP = 7.6, 8.5                            # Lv1 doorway: gate posts + studded lintel
ISLAND = (-4.0, -2.6, 4.0, 0.4)                            # centre ice-and-fish counter island
AISLE = (-2.0, 0.0, 2.0, 17.7)                             # r5: dark tile aisle behind the island
WALK = (-4.6, -18.85, 4.6, ISLAND[1])                      # stud-tile walkway gate -> island
BACK_TOP = 5.16                                            # back wall: 4 brick courses
RACK_X, RACK_Y = 10.0, 13.5


def prof_x_cw(b, x0, x1, profile, c):
    """prof_x with the (y, z) profile ordered clockwise, so the caps face out."""
    area = sum(y0 * z1 - y1 * z0 for (y0, z0), (y1, z1) in zip(profile, profile[1:] + profile[:1]))
    b.prof_x(x0, x1, profile[::-1] if area > 0 else profile, c)


def prism_y_ccw(b, y0, y1, profile, c):
    area = sum(x0 * z1 - x1 * z0 for (x0, z0), (x1, z1) in zip(profile, profile[1:] + profile[:1]))
    prism_y(b, y0, y1, profile if area > 0 else profile[::-1], c)


def place_m(dst, src, cx, cy, mirror):
    base = len(dst.v)
    s = -1.0 if mirror else 1.0
    dst.v.extend((cx + s * x, cy + y, z) for x, y, z in src.v)
    dst.f.extend((tuple(base + i for i in (f[::-1] if mirror else f)), c) for f, c in src.f)


def stud_n(b, cx, cy, cz, n, c, r=STUD_R, h=STUD_H):
    """A stud standing on a plane with unit normal n = (nx, 0, nz) (smokehouse roof slopes)."""
    e1, e2 = (n[2], 0.0, -n[0]), (0.0, 1.0, 0.0)
    ring = [tuple(p - 0.05 * q for p, q in zip((cx + r * (math.cos(a) * e1[0]), cy + r * math.sin(a),
                                                cz + r * math.cos(a) * e1[2]), n))
            for a in (2 * math.pi * i / 6 for i in range(6))]
    top = [tuple(p + (h + 0.05) * q for p, q in zip(v, n)) for v in ring]
    faces = [(i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i) for i in range(6)]
    faces += [tuple(range(6, 12))]                          # r5: no bottom cap (sunk 0.05 into the surface)
    b._emit(ring + top, faces, c)


def fish_side(b, y0, y1, cx, cz, s, body, tail):
    """A side-on fish in the xz plane (stickers and signs): hexagon body, V tail touching it at one point."""
    prism_y_ccw(b, y0, y1, [(cx + 1.25 * s, cz), (cx + 0.7 * s, cz + 0.36 * s), (cx - 0.55 * s, cz + 0.32 * s),
                            (cx - 0.85 * s, cz), (cx - 0.55 * s, cz - 0.32 * s), (cx + 0.7 * s, cz - 0.36 * s)], body)
    prism_y_ccw(b, y0, y1, [(cx - 0.85 * s, cz), (cx - 1.45 * s, cz + 0.42 * s), (cx - 1.45 * s, cz - 0.42 * s)], tail)


def fish_eye(b, y_face, cx, cz, s):
    b.box((cx + 0.62 * s, y_face - 0.05, cz + 0.02 * s), (cx + 0.86 * s, y_face, cz + 0.22 * s), P.WHITE, bevel=0.01)
    b.box((cx + 0.7 * s, y_face - 0.1, cz + 0.07 * s), (cx + 0.8 * s, y_face - 0.05, cz + 0.17 * s), P.INK, bevel=0.005)


def lv1_brick_run(b, x0, y0, x1, y1, z0, z1, c, along_x, stagger):
    """One course of 4-stud bricks with 0.1 joints over a grey mortar core (the seams read as Lego joints)."""
    a0, a1 = (x0, x1) if along_x else (y0, y1)
    p = a0 - (2.0 if stagger else 0.0)
    while p < a1 - 0.01:
        q = min(p + 4.0, a1)
        lo, hi = max(p, a0), q - (0.1 if q < a1 - 0.01 else 0.0)
        if hi - lo > 0.3:
            if along_x:
                b.box((lo, y0, z0), (hi, y1, z1), c, bevel=0.06)
            else:
                b.box((x0, lo, z0), (x1, hi, z1), c, bevel=0.06)
        p = q


def brick_wall(b, x0, y0, x1, y1, zs, along_x, cap_c=P.BLUE):
    """Brick courses between the zs levels (0.08 bed joints), an inset mortar core, a blue stud-topped cap."""
    top = zs[-1]
    b.box((x0 + 0.05, y0 + 0.05, FLOOR - 0.05), (x1 - 0.05, y1 - 0.05, top), P.LBG)
    for k in range(len(zs) - 1):
        lv1_brick_run(b, x0, y0, x1, y1, zs[k] + (0.04 if k else 0.0), zs[k + 1] - 0.04, P.WHITE, along_x, k % 2 == 1)
    a0, a1 = (x0, x1) if along_x else (y0, y1)
    p, k = a0 - 0.05, 0
    while p < a1 + 0.05 - 0.3:                              # r5: 1x4 cap tiles, blue/white alternating, 0.05 seams
        q = min(p + 4.0, a1 + 0.05)
        lo, hi = p + (0.025 if p > a0 else 0.0), q - (0.025 if q < a1 + 0.04 else 0.0)
        col = (cap_c, P.RED)[k % 2]                        # r6: red tie-in on the caps
        if along_x:
            b.box((lo, y0 - 0.05, top), (hi, y1 + 0.05, top + 0.3), col, bevel=0.04)
        else:
            b.box((x0 - 0.05, lo, top), (x1 + 0.05, hi, top + 0.3), col, bevel=0.04)
        for t in (p + 0.5, p + 1.5, p + 2.5, p + 3.5):
            if t < q - 0.35:
                stud(b, t, (y0 + y1) / 2, top + 0.3, col) if along_x else stud(b, (x0 + x1) / 2, t, top + 0.3, col)
        p, k = q, k + 1


def pillar(b, x, y, top, hw=0.65):
    """Blue brick pillar sunk 0.05 into the plinth: white band, white stud cap."""
    b.box((x - hw, y - hw, FLOOR - 0.05), (x + hw, y + hw, top), P.BLUE, bevel=0.06)
    b.box((x - hw - 0.05, y - hw - 0.05, top - 1.5), (x + hw + 0.05, y + hw + 0.05, top - 1.15), P.RED, bevel=0.03)
    b.cyl(x, y, top, top + 0.3, hw + 0.12, P.WHITE, 10)        # r5: round cap plate + a round 2x2 stud
    del b.f[-2]
    stud(b, x, y, top + 0.3, P.BLUE, r=0.5)


SIDE_PILLARS = (-10.0, -2.0, 6.0, 14.0)
FRONT_PILLARS = (13.5,)
BACK_PILLARS = (-16.0, -8.0, 0.0, 8.0, 16.0)          # r5: every 8 studs


def lv1_walls(b):
    """Stud-topped low walls (white brick, mortar joints, blue cap) with pillars every ~8 studs, a taller back wall
    on the sea side, and the gate doorway: two blue posts and a studded lintel."""
    zc, zf = (FLOOR, 2.06, 3.2), (FLOOR, 2.06)              # r3: the front run one brick lower
    for x0, y0, x1, y1, ax, z in ((-WALL_X - WALL_T / 2, -WALL_Y - 0.4, -WALL_X + WALL_T / 2, WALL_Y - 0.45, False, zc),
                                  (WALL_X - WALL_T / 2, -WALL_Y - 0.4, WALL_X + WALL_T / 2, WALL_Y - 0.45, False, zc),
                                  (-WALL_X + WALL_T / 2 + 0.05, -WALL_Y - 0.4, -GATE_X - 0.6, -WALL_Y + 0.4, True, zf),
                                  (GATE_X + 0.6, -WALL_Y - 0.4, WALL_X - WALL_T / 2 - 0.05, -WALL_Y + 0.4, True, zf)):
        brick_wall(b, x0, y0, x1, y1, z, ax)
    brick_wall(b, -WALL_X - 0.4, WALL_Y - 0.4, WALL_X + 0.4, WALL_Y + 0.4, (FLOOR, 1.98, 3.04, 4.1, BACK_TOP), True)
    for s in (-1, 1):
        for y in SIDE_PILLARS:
            pillar(b, s * WALL_X, y, 4.1)
        for x in FRONT_PILLARS:
            pillar(b, s * x, -WALL_Y, 3.0)
        pillar(b, s * WALL_X, -WALL_Y, 4.1, hw=0.55)        # r5: corner posts (inside the plinth edge)
        pillar(b, s * WALL_X, WALL_Y, 6.3, hw=0.55)
    for x in BACK_PILLARS:
        pillar(b, x, WALL_Y, 6.3)
    for s in (-1, 1):                                       # gate posts: blue, white band
        x = s * GATE_X
        b.box((x - 0.69, -WALL_Y - 0.69, FLOOR), (x + 0.69, -WALL_Y + 0.69, GATE_TOP), P.BLUE, bevel=0.06)
        b.box((x - 0.74, -WALL_Y - 0.74, 3.5), (x + 0.74, -WALL_Y + 0.74, 3.9), P.RED, bevel=0.04)
    lv1_arch(b)


def lv1_arch(b):
    """r6: the entrance arch on the gate posts (the Lv2 gate grows out of it): a blue header under a studded white
    plate, a 6 x 2 blue-framed fish plaque on top, a short blue/white scalloped valance under the front."""
    yh = -WALL_Y
    b.box((-GATE_X - 0.74, yh - 0.6, GATE_TOP), (GATE_X + 0.74, yh + 0.55, LINTEL_TOP - 0.1), P.BLUE, bevel=0.06)
    b.box((-GATE_X - 0.8, yh - 0.66, LINTEL_TOP - 0.1), (GATE_X + 0.8, yh + 0.6, LINTEL_TOP + 0.1), P.WHITE, bevel=0.04)
    for x in range(-6, 7):
        if abs(x) > 3:
            for y in (-0.3, 0.25):
                stud(b, x + 0.0, yh + y, LINTEL_TOP + 0.1, P.WHITE)
    z0, z1 = LINTEL_TOP + 0.1, LINTEL_TOP + 1.9                 # plaque: blue frame, white face, orange fish
    b.box((-3.1, yh - 0.05, z0 - 0.05), (3.1, yh + 0.45, z1), P.BLUE, bevel=0.08)
    b.box((-2.75, yh - 0.12, z0 + 0.3), (2.75, yh - 0.05, z1 - 0.3), P.WHITE, bevel=0.02)
    fish_side(b, yh - 0.18, yh - 0.12, 0.15, (z0 + z1) / 2, 0.85, P.ORANGE, P.YELLOW)
    fish_eye(b, yh - 0.18, 0.15, (z0 + z1) / 2, 0.85)
    for x in (-2.5, -1.5, -0.5, 0.5, 1.5, 2.5):
        stud(b, x, yh + 0.2, z1, P.BLUE)
    for i in range(4):                                       # valance under the header front
        x0 = -2.0 + i
        scallop(b, x0 + 0.02, x0 + 0.98, yh - 0.68, yh - 0.5, GATE_TOP + 0.05, GATE_TOP - 0.6 - 0.15 * (i % 2),
                (P.BLUE, P.WHITE)[i % 2])


def lv1_walkway(b):
    """Grey 2x2 tiles (0.06 joints) from the gate to the island, a studded dark kerb either side."""
    x0, y0, x1, y1 = WALK
    y = y0
    while y < y1 - 0.3:
        ye = min(y + 2.0, y1)
        for xa, xb in ((x0 + 0.3, -2.0), (-2.0, 0.0), (0.0, 2.0), (2.0, x1 - 0.3)):   # r5: dark 4-stud centre aisle
            b.box((xa + 0.03, y + 0.03, FLOOR), (xb - 0.03, ye - 0.03, FLOOR + 0.12),
                  P.DBG if abs(xa + xb) < 2.1 else P.LBG, bevel=0.03)
        y = ye
    y = AISLE[1]
    while y < AISLE[3] - 0.3:                               # r5: the aisle runs on behind the island to the back wall
        ye = min(y + 2.0, AISLE[3])
        for xa, xb in ((-2.0, 0.0), (0.0, 2.0)):
            b.box((xa + 0.03, y + 0.03, FLOOR), (xb - 0.03, ye - 0.03, FLOOR + 0.12), P.DBG, bevel=0.03)
        y = ye
    for xa, xb in ((x0 - 0.7, x0 + 0.3), (x1 - 0.3, x1 + 0.7)):   # r6: a 1-stud blue tile border along the path edge
        y = y0 + 0.4
        while y < y1 - 0.5:
            ye = min(y + 2.0, y1)
            b.box((xa, y + 0.025, FLOOR), (xb, ye - 0.025, FLOOR + 0.17), P.BLUE, bevel=0.04)
            stud(b, (xa + xb) / 2, (y + ye) / 2, FLOOR + 0.17, P.BLUE)
            y = ye
    y = y0 + 0.4                                            # r6: a black grille drain line down the walkway centre
    while y < y1 - 0.5:
        ye = min(y + 2.0, y1)
        b.box((-0.3, y + 0.03, FLOOR + 0.06), (0.3, ye - 0.03, FLOOR + 0.15), P.BLACK, bevel=0.02)
        y = ye


def booth_counter(b):
    b.box((-3.68, -1.5, FLOOR), (3.68, 1.5, 2.5), P.BLUE)
    b.box((-3.73, -1.55, FLOOR), (3.73, 1.55, 1.25), P.WHITE, bevel=0.04)        # white kick course
    b.box((-3.78, -1.6, 2.5), (3.78, 1.6, COUNTER_TOP), P.WHITE, bevel=0.06)
    for x in (-3.3, 3.3):
        for y in (-0.8, 0.8):
            stud(b, x, y, COUNTER_TOP, P.WHITE)
    b.box((-1.7, -1.56, 1.38), (1.7, -1.5, 2.42), P.WHITE, bevel=0.03)          # fish sticker on the counter front
    fish_side(b, -1.62, -1.56, 0.1, 1.9, 1.05, P.ORANGE, P.YELLOW)
    fish_eye(b, -1.62, 0.1, 1.9, 1.05)
    for x in (-3.85, 3.85):                                                       # side cheeks, blue stud cap
        b.box((x - 0.25, -1.0, FLOOR), (x + 0.25, 3.7, 2.3), P.WHITE, bevel=0.04)
        b.box((x - 0.3, -1.0, 2.3), (x + 0.3, 3.7, 2.55), P.BLUE, bevel=0.03)


BRIGHT = ((P.ORANGE, P.YELLOW), (P.YELLOW, P.ORANGE))


def fish_crate(b, x0, y0, x1, y1, z0, h, fishes, L=1.6):
    slat_crate(b, x0, y0, x1, y1, z0, h)
    top = z0 + h
    b.box((x0 + 0.2, y0 + 0.2, top), (x1 - 0.2, y1 - 0.2, top + 0.12), P.GLASS, bevel=0.02)
    for k, (fx, fy, ang) in enumerate(fishes):
        body, acc = BRIGHT[k % 2]
        fish(b, fx, fy, top + 0.12, L, body, acc, ang)


def booth_stock(b):
    x0, y0, x1, y1 = TRAY
    r, rim_top, ice_top = 0.25, COUNTER_TOP + 0.3, COUNTER_TOP + 0.16
    for lo, hi in (((x0, y0), (x1, y0 + r)), ((x0, y1 - r), (x1, y1)),
                   ((x0, y0 + r), (x0 + r, y1 - r)), ((x1 - r, y0 + r), (x1, y1 - r))):
        b.box((*lo, COUNTER_TOP), (*hi, rim_top), P.DBG, bevel=0.04)
    b.box((x0 + r, y0 + r, COUNTER_TOP), (x1 - r, y1 - r, ice_top), P.GLASS, bevel=0.02)
    for i, cx in enumerate((-1.95, -0.65, 0.65, 1.95)):
        body, accent = FISH_SETS[(i + 1) % 4]
        flat_fish(b, cx, 0.0, ice_top, 2.3, body, accent, -math.pi / 2)
    fish_crate(b, -3.45, 2.0, -1.45, 3.7, FLOOR, 1.5, [(-2.45, 2.85, 0.5)])
    fish_crate(b, 1.45, 2.0, 3.35, 3.6, FLOOR, 1.3, [(2.4, 2.8, 2.6)])


PANEL_TOP, BACK_PANEL_TOP = 7.55, 8.7
SWIN = (0.3, 2.5, 4.0, 6.0)                                 # side window opening: y0, y1, z0, z1 (local)
BWIN = (-1.3, 1.3, 4.4, 6.6)                                # back window opening: x0, x1, z0, z1


def win_frame_x(b, xf, s, y0, y1, z0, z1):
    """Proud dark frame + white sill on a side panel's outer face xf (s = outward sign), glass set back 0.17."""
    a = lambda d0, d1: sorted((xf + s * d0, xf + s * d1))
    fa, fb = a(-0.02, 0.2)                                  # r4: white frame 0.2 proud, glass 0.34 behind its face
    for lo, hi in (((y0 - 0.25, z0 - 0.25), (y1 + 0.25, z0 + 0.08)), ((y0 - 0.25, z1 - 0.08), (y1 + 0.25, z1 + 0.25)),
                   ((y0 - 0.25, z0 + 0.08), (y0 + 0.08, z1 - 0.08)), ((y1 - 0.08, z0 + 0.08), (y1 + 0.25, z1 - 0.08))):
        b.box((fa, lo[0], lo[1]), (fb, hi[0], hi[1]), P.WHITE, bevel=0.03)
    ga, gb = a(-0.2, -0.14)
    b.box((ga, y0 + 0.05, z0 + 0.05), (gb, y1 - 0.05, z1 - 0.05), P.GLASS, bevel=0.01)
    sa, sb = a(-0.02, 1.0)                                  # 1-stud sill brick, studded
    b.box((sa, y0 - 0.4, z0 - 0.6), (sb, y1 + 0.4, z0 - 0.25), P.WHITE, bevel=0.04)
    for yy in (y0 + 0.2, (y0 + y1) / 2, y1 - 0.2):
        stud(b, (sa + sb) / 2, yy, z0 - 0.25, P.WHITE)


def win_frame_y(b, yf, s, x0, x1, z0, z1, sill=True):
    a = lambda d0, d1: sorted((yf + s * d0, yf + s * d1))
    fa, fb = a(-0.02, 0.2)
    for lo, hi in (((x0 - 0.25, z0 - 0.25), (x1 + 0.25, z0 + 0.08)), ((x0 - 0.25, z1 - 0.08), (x1 + 0.25, z1 + 0.25)),
                   ((x0 - 0.25, z0 + 0.08), (x0 + 0.08, z1 - 0.08)), ((x1 - 0.08, z0 + 0.08), (x1 + 0.25, z1 - 0.08))):
        b.box((lo[0], fa, lo[1]), (hi[0], fb, hi[1]), P.WHITE, bevel=0.03)
    if sill:
        sa, sb = a(-0.02, 0.6)
        b.box((x0 - 0.4, sa, z0 - 0.6), (x1 + 0.4, sb, z0 - 0.25), P.WHITE, bevel=0.04)
        for xx in (x0 + 0.2, (x0 + x1) / 2, x1 - 0.2):
            stud(b, xx, (sa + sb) / 2, z0 - 0.25, P.WHITE)


def boards(b, along_y, t0, t1, edges, z0, z1, hole=None):
    """Vertical blue boards between the edges (0.08 seams over a dark core strip), split around the window hole."""
    def bx(a0, a1, za, zb, c, inset, bev):
        if along_y:
            b.box((t0 + inset, a0, za), (t1 - inset, a1, zb), c, bevel=bev)
        else:
            b.box((a0, t0 + inset, za), (a1, t1 - inset, zb), c, bevel=bev)

    def spans(a0, a1):
        inside = hole and a0 >= hole[0] - 1e-6 and a1 <= hole[1] + 1e-6
        return [(z0, hole[2]), (hole[3], z1)] if inside else [(z0, z1)]
    n = len(edges) - 1
    for i in range(n):
        a0, a1 = edges[i], edges[i + 1]
        for za, zb in spans(a0, a1):
            bx(a0 + (0.04 if i else 0.0), a1 - (0.04 if i < n - 1 else 0.0), za, zb, P.BLUE, 0.0, 0.03)
        if i:
            sp = spans(a0, a1) if len(spans(a0, a1)) > 1 else spans(edges[i - 1], a0)
            for za, zb in sp:
                bx(a0 - 0.1, a0 + 0.1, za + 0.05, zb - 0.05, P.DBG, 0.05, 0.0)


def booth_frames(b):
    for x in (-4.1, 4.1):
        for y, top in ((-1.2, 7.95), (3.9, 8.93)):
            b.box((x - 0.345, y - 0.345, FLOOR), (x + 0.345, y + 0.345, top), P.WHITE, bevel=0.12)
            b.box((x - 0.4, y - 0.4, 5.6), (x + 0.4, y + 0.4, 6.0), P.RED, bevel=0.03)
    b.box((-3.75, -1.5, 7.3), (3.75, -1.0, 7.8), P.WHITE, bevel=0.04)       # r4: 0.5 trim band under the roof front
    b.box((-3.7, -1.56, 7.42), (3.7, -1.46, 7.68), P.RED, bevel=0.01)
    y0, y1, z0, z1 = SWIN                                   # side panels: blue boards, on the cheeks, framed window
    for x in (-4.1, 4.1):
        s = 1 if x > 0 else -1
        xa, xb = x - 0.15, x + 0.15
        boards(b, True, xa, xb, (-0.9, y0, 1.4, y1, 3.6), 2.55, PANEL_TOP, (y0, y1, z0, z1))
        b.box((xa - 0.05, -0.9, PANEL_TOP), (xb + 0.05, 3.6, PANEL_TOP + 0.25), P.WHITE, bevel=0.03)
        win_frame_x(b, x + s * 0.15, s, y0, y1, z0, z1)
    bx0, bx1, bz0, bz1 = BWIN                               # back panel: white brick base, blue upper, framed window
    ya, yb = 3.75, 4.05
    b.box((-3.8, ya, FLOOR), (3.8, yb, 2.6), P.WHITE, bevel=0.03)
    boards(b, False, ya, yb, (-3.8, -2.55, bx0, 0.0, bx1, 2.55, 3.8), 2.6, BACK_PANEL_TOP, (bx0, bx1, bz0, bz1))
    b.box((-3.8, ya - 0.14, 7.95), (3.8, ya + 0.02, 8.3), P.WHITE, bevel=0.03)          # top trim course
    b.box((-3.85, ya - 0.1, 2.6), (3.85, ya + 0.02, 2.85), P.WHITE, bevel=0.03)        # base trim course
    for xs in ((-3.55, -1.65), (1.65, 3.55)):               # back shelves with fish trays
        for zs in (3.45, 5.05):
            b.box((xs[0], 3.1, zs), (xs[1], ya + 0.05, zs + 0.18), P.WHITE, bevel=0.03)
            b.box((xs[0] + 0.15, 3.2, zs + 0.18), (xs[1] - 0.15, 3.65, zs + 0.34), P.DBG, bevel=0.03)
            for k, fx in enumerate((xs[0] + 0.55, xs[1] - 0.55)):
                body, acc = BRIGHT[k]
                fish(b, fx, 3.42, zs + 0.34, 0.75, body, acc, 0.0)
    for x in (2.2, 3.4):                                    # hanging price board under the trim band
        b.box((x - 0.04, -1.04, 6.95), (x + 0.04, -0.96, 7.36), P.BLACK, bevel=0.0)
    b.box((1.95, -1.08, 5.9), (3.65, -0.92, 7.0), P.RED, bevel=0.04)
    b.box((2.1, -1.13, 6.05), (3.5, -1.08, 6.85), P.WHITE, bevel=0.02)
    prism_y_ccw(b, -1.18, -1.13, [(2.48 + 0.26 * math.cos(i * math.pi / 5), 6.45 + 0.26 * math.sin(i * math.pi / 5))
                                  for i in range(10)], P.YELLOW)
    fish_side(b, -1.18, -1.13, 3.1, 6.45, 0.27, P.ORANGE, P.ORANGE)
    b.box((bx0 + 0.05, 3.85, bz0 + 0.05), (bx1 - 0.05, 3.95, bz1 - 0.05), P.GLASS, bevel=0.01)
    win_frame_y(b, ya, -1, bx0, bx1, bz0, bz1)
    win_frame_y(b, yb, 1, bx0, bx1, bz0, bz1, sill=False)


def booth_roof(b):
    """Mono-pitch striped roof: 7 blue/white stripes, stepped valance, stud rows, studded white ridge cap at the back."""
    ca, sa = math.cos(R_ANG), math.sin(R_ANG)
    prof = [(R_Y0, R_Z0), (R_Y1, R_Z1), (R_Y1, R_Z1 + R_T), (R_Y0, R_Z0 + R_T)]
    front_top = (R_Y0, R_Z0 + R_T)
    sw = 2 * R_HW / AW_STRIPES
    for i in range(AW_STRIPES):
        c = (P.BLUE, P.WHITE)[i % 2]
        x0 = -R_HW + i * sw
        d = STEP if i % 2 else 0.0
        prof_x_cw(b, x0, x0 + sw, prof[:2] + [(R_Y1 - d * sa, R_Z1 + R_T + d * ca), (R_Y0 - d * sa, R_Z0 + R_T + d * ca)], c)
        scallop(b, x0 + 0.02, x0 + sw - 0.02, R_Y0 - 0.08, R_Y0 + 0.2, R_Z0 + 0.25, R_Z0 - (0.7 if i % 2 == 0 else 0.45), c)
        for u in (0.9, 2.3, 3.7, 5.1):
            _tilted_stud(b, x0 + sw / 2, up(front_top, sa, ca, i), u, ca, sa, c)
    b.box((-R_HW - 0.1, 3.95, 9.2), (R_HW + 0.1, 4.8, 9.85), P.WHITE, bevel=0.05)
    for x in range(-4, 5):
        stud(b, x + 0.0, 4.375, 9.85, P.WHITE)


def lv1_signs(b):
    """The big fish sticker on the left booth's roof; a blue board for the code name sign on the right one."""
    cx, cz, s = -BOOTH_X, 13.8, 4.3                        # r2: 1.35x on a blue bracket (r6: +0.8, clear of the Lv2 awning)
    y0 = SIGN_Y
    k = 1.0 + 1.0 / s                                       # r5: wider white sticker rim (was 0.45)
    prism_y_ccw(b, y0, y0 + 0.4, [(cx + (px - cx) * k, cz + (pz - cz) * k) for px, pz in
                                  [(cx + 1.25 * s, cz), (cx + 0.7 * s, cz + 0.36 * s), (cx - 0.55 * s, cz + 0.32 * s),
                                   (cx - 0.85 * s, cz), (cx - 0.55 * s, cz - 0.32 * s), (cx + 0.7 * s, cz - 0.36 * s)]],
                P.WHITE)
    prism_y_ccw(b, y0 + 0.05, y0 + 0.4, [(cx - 0.7 * s, cz), (cx - 1.7 * s, cz + 0.64 * s),
                                         (cx - 1.7 * s, cz - 0.64 * s)], P.WHITE)
    fish_side(b, y0 - 0.22, y0, cx, cz, s, P.ORANGE, P.YELLOW)          # r4: second layer, 0.22 proud of the rim
    prism_y_ccw(b, y0 - 0.27, y0 - 0.22, [(cx - 0.4 * s, cz + 0.2 * s), (cx + 0.35 * s, cz + 0.22 * s),
                                          (cx + 0.1 * s, cz + 0.55 * s), (cx - 0.5 * s, cz + 0.5 * s)], P.YELLOW)
    b.box((cx + 0.38 * s, y0 - 0.27, cz - 0.2 * s), (cx + 0.46 * s, y0 - 0.22, cz + 0.2 * s), P.YELLOW, bevel=0.01)
    fish_eye(b, y0 - 0.22, cx, cz, s)
    x0 = -BOOTH_X                                           # sticker bracket: chunky blue brick legs, stud caps, a bar
    for dx in (-3.2, 3.2):
        b.box((x0 + dx - 0.5, y0 + 0.4, 8.9), (x0 + dx + 0.5, y0 + 1.4, 13.2), P.BLUE, bevel=0.06)
        grid_studs(b, (x0 + dx - 0.25, x0 + dx + 0.25), (y0 + 0.65, y0 + 1.15), 13.2, P.BLUE)
    b.box((x0 - 3.9, y0 - 0.65, 11.15), (x0 + 3.9, y0 + 1.3, 11.65), P.BLUE, bevel=0.06)   # r6: stud-edged plinth
    b.box((x0 - 3.95, y0 - 0.7, 10.9), (x0 + 3.95, y0 + 1.35, 11.18), P.WHITE, bevel=0.04)
    for x in range(-3, 4):
        stud(b, x0 + x, y0 - 0.35, 11.65, P.BLUE)
    nx, nz = NAME_SIGN[0], NAME_SIGN[2]
    b.box((nx - NS_HW - 0.5, y0, nz - NS_HH - 0.45), (nx + NS_HW + 0.5, y0 + 0.3, nz + NS_HH + 0.45), P.BLUE, bevel=0.06)
    zb, zt = nz - NS_HH - 0.45, nz + NS_HH + 0.45
    fw = NS_HW + 0.5                                        # r4: white brick frame (sill course + side columns)
    b.box((nx - fw - 0.4, y0 - 0.25, zb - 0.45), (nx + fw + 0.4, y0 + 0.4, zb + 0.04), P.WHITE, bevel=0.05)
    for sx in (-1, 1):
        a, c = sorted((nx + sx * fw, nx + sx * (fw + 0.4)))
        z = zb + 0.04
        while z < zt:
            ze = min(z + 1.15, zt + 0.05)
            b.box((a, y0 - 0.25, z), (c, y0 + 0.4, ze), P.WHITE, bevel=0.04)
            z = ze
        px = nx + sx * 3.2                                  # two chunky blue brick posts behind the board, stud caps
        b.box((px - 0.6, y0 + 0.38, 8.9), (px + 0.6, y0 + 1.55, zt + 0.3), P.BLUE, bevel=0.06)
        grid_studs(b, (px - 0.3, px + 0.3), (y0 + 0.65, y0 + 1.25), zt + 0.3, P.BLUE)
    hw, hh, t = NS_HW + 0.03, NS_HH + 0.03, 0.9               # r6: a 1-stud blue bevelled rim, 0.5 proud of the sign
    rt = nz + hh + t
    for zz in ((nz - hh - t, nz - hh), (nz + hh, rt)):
        b.box((nx - hw - t, y0 - 0.95, zz[0]), (nx + hw + t, y0 + 0.02, zz[1]), P.BLUE, bevel=0.2)
    for sx in (-1, 1):
        a, c = sorted((nx + sx * hw, nx + sx * (hw + t)))
        b.box((a, y0 - 0.92, nz - hh - 0.05), (c, y0 - 0.01, nz + hh + 0.05), P.BLUE, bevel=0.2)
        px = nx + sx * (hw + 0.45)                           # r6: chunky stud-topped posts on the rim corners
        b.box((px - 0.45, y0 - 0.88, rt - 0.05), (px + 0.45, y0 - 0.02, rt + 1.3), P.BLUE, bevel=0.06)
        b.cyl(px, y0 - 0.45, rt + 1.3, rt + 1.55, 0.6, P.WHITE, 10)
        del b.f[-2]
        stud(b, px, y0 - 0.45, rt + 1.55, P.WHITE, r=0.42)
    for x in range(-5, 6):                                   # stud row along the rim top
        stud(b, nx + x, y0 - 0.45, rt, P.BLUE)


def lv1_scale(b):
    """A clean market scale at the left booth's front corner: studded base, blue post, 2-stud red dial with a yellow
    face and ink needle, an arm with a hook and a dished pan holding a fish."""
    sx, sy = SCALE_XY
    b.box((sx - 0.8, sy - 0.8, FLOOR), (sx + 0.8, sy + 0.8, 1.15), P.DBG, bevel=0.04)
    grid_studs(b, (sx - 0.4, sx + 0.4), (sy - 0.4, sy + 0.4), 1.15, P.DBG)
    b.box((sx - 0.3, sy - 0.3, 1.15), (sx + 0.3, sy + 0.3, 4.7), P.BLUE, bevel=0.04)
    poly = lambda r, z, n=12: [(sx + r * math.cos(math.pi / n + i * 2 * math.pi / n),
                                z + r * math.sin(math.pi / n + i * 2 * math.pi / n)) for i in range(n)]
    dz = 5.5
    prism_y_ccw(b, sy - 0.35, sy + 0.35, poly(1.0, dz), P.RED)                     # dial housing
    prism_y_ccw(b, sy - 0.4, sy - 0.35, poly(0.8, dz), P.YELLOW)                  # face
    prism_y_ccw(b, sy - 0.45, sy - 0.4, [(sx - 0.05, dz), (sx + 0.05, dz), (sx + 0.42, dz + 0.5), (sx + 0.34, dz + 0.56)],
                P.INK)                                                            # needle
    for a in (-0.6, 0.0, 0.6):                                                    # ticks
        tx, tz = sx + 0.62 * math.sin(a), dz + 0.62 * math.cos(a)
        b.box((tx - 0.05, sy - 0.45, tz - 0.08), (tx + 0.05, sy - 0.4, tz + 0.08), P.INK, bevel=0.005)
    b.box((sx - 0.12, sy - 0.47, dz - 0.12), (sx + 0.12, sy - 0.4, dz + 0.12), P.INK, bevel=0.01)
    b.box((sx - 0.35, sy - 0.25, dz + 0.95), (sx + 0.35, sy + 0.25, dz + 1.25), P.RED, bevel=0.03)
    stud(b, sx, sy, dz + 1.25, P.RED)
    py = sy - 1.25
    b.box((sx - 0.12, py - 0.12, 4.0), (sx + 0.12, sy - 0.2, 4.24), P.DBG, bevel=0.02)  # arm out of the post
    b.box((sx - 0.06, py - 0.06, 3.35), (sx + 0.06, py + 0.06, 4.0), P.DBG)            # hook
    b.cyl(sx, py, 3.05, 3.2, 0.85, P.LBG, 10)                                     # pan, dished rim
    b.cyl(sx, py, 3.2, 3.4, 0.85, P.DBG, 10, top=False)
    fish(b, sx, py, 3.2, 1.3, P.ORANGE, P.YELLOW, 0.4)


def lv1_island(b):
    """The centre ice-and-fish counter: blue body, white kick course and studded top, an ice tray of chunky fish,
    a fish sticker on the front, two orange crates of fish at its ends."""
    x0, y0, x1, y1 = ISLAND
    b.box((x0, y0, FLOOR), (x1, y1, 2.3), P.BLUE)
    b.box((x0 - 0.05, y0 - 0.05, FLOOR), (x1 + 0.05, y1 + 0.05, 1.2), P.WHITE, bevel=0.04)
    b.box((x0 - 0.1, y0 - 0.1, 2.3), (x1 + 0.1, y1 + 0.1, 2.56), P.WHITE, bevel=0.06)
    tx0, tx1, ty0, ty1, r = x0 + 0.85, x1 - 0.85, y0 + 0.25, y1 - 0.25, 0.22
    for lo, hi in (((tx0, ty0), (tx1, ty0 + r)), ((tx0, ty1 - r), (tx1, ty1)),
                   ((tx0, ty0 + r), (tx0 + r, ty1 - r)), ((tx1 - r, ty0 + r), (tx1, ty1 - r))):
        b.box((*lo, 2.56), (*hi, 2.86), P.DBG, bevel=0.04)
    b.box((tx0 + r, ty0 + r, 2.56), (tx1 - r, ty1 - r, 2.7), P.GLASS, bevel=0.02)
    for k, fx in enumerate((-2.2, -1.1, 0.0, 1.1, 2.2)):
        body, acc = ((P.ORANGE, P.YELLOW), (P.YELLOW, P.ORANGE), (P.LBG, P.DBG))[k % 3]
        fish(b, fx, (y0 + y1) / 2, 2.7, 1.7, body, acc, -math.pi / 2 + (0.15 if k % 2 else -0.15))
    b.box((-1.8, y0 - 0.06, 1.3), (1.8, y0, 2.22), P.WHITE, bevel=0.03)          # fish sticker on the front
    fish_side(b, y0 - 0.12, y0 - 0.06, 0.1, 1.76, 1.0, P.ORANGE, P.YELLOW)
    fish_eye(b, y0 - 0.12, 0.1, 1.76, 1.0)
    for k, tx in enumerate((-3.35, -2.45, 2.45, 3.35)):    # r5: fish tiles either side of the sticker
        b.box((tx - 0.4, y0 - 0.08, 1.38), (tx + 0.4, y0, 2.18), (P.WHITE, P.YELLOW)[k % 2], bevel=0.03)
        fish_side(b, y0 - 0.13, y0 - 0.08, tx + 0.04, 1.78, 0.24, (P.ORANGE, P.BLUE)[k % 2], P.ORANGE if k % 2 else P.YELLOW)
    for cx in (x0 - 1.2, x1 + 1.2):
        b.box((cx - 0.95, y0 + 0.3, FLOOR), (cx + 0.95, y0 + 2.2, 2.0), P.ORANGE, bevel=0.06)
        b.box((cx - 0.85, y0 + 0.25, 1.2), (cx + 0.85, y0 + 0.32, 1.6), P.YELLOW, bevel=0.02)
        b.box((cx - 0.8, y0 + 0.45, 2.0), (cx + 0.8, y0 + 2.05, 2.1), P.GLASS, bevel=0.02)
        fish(b, cx, y0 + 1.25, 2.1, 1.6, P.YELLOW, P.ORANGE, 0.3 if cx < 0 else 2.8)


def lv1_props(b):
    """The scale, chunky fish on the ice crates at both outer counter ends, the centre island."""
    lv1_scale(b)
    for s in (-1, 1):
        cx, cy = s * 17.24, -7.57
        b.box((cx - 1.95, cy - 1.95, FLOOR), (cx + 1.95, cy + 1.95, 2.3), P.WHITE, bevel=0.06)
        for z in (1.2, 1.85):
            b.box((cx - 1.85, cy - 2.0, z), (cx + 1.85, cy + 2.0, z + 0.25), P.BLUE, bevel=0.03)
        b.box((cx - 1.7, cy - 1.7, 2.3), (cx + 1.7, cy + 1.7, 2.5), P.GLASS, bevel=0.03)
        for k, (fx, fy, ang) in enumerate(((-0.25, -0.8, 0.35), (0.25, 0.8, math.pi + 0.35))):
            body, acc = BRIGHT[k]
            fish(b, cx + fx, cy + fy, 2.5, 2.3, body, acc, ang)
    lv1_island(b)


def lv1_rack(b):
    """The drying rack at the back (gives way to the Lv3 smokehouse): white posts, blue bar, five hanging fish."""
    for dx in (-5.29, 5.29):
        b.box((RACK_X + dx - 0.46, RACK_Y - 0.46, FLOOR), (RACK_X + dx + 0.46, RACK_Y + 0.46, 8.97), P.WHITE, bevel=0.05)
        stud(b, RACK_X + dx, RACK_Y, 8.97, P.WHITE)
    b.box((RACK_X - 5.75, RACK_Y - 0.3, 8.1), (RACK_X + 5.75, RACK_Y + 0.3, 8.6),
          P.BLUE, bevel=0.04)
    for i in range(-2, 3):
        fish_hang(b, RACK_X + i * 2.0, RACK_Y, 8.1, 1.4, P.ORANGE if i % 2 == 0 else P.LBG)


MAST = (2.8, 17.15)                                       # r3: the Lv1 focal point, back centre


def lv1_mast(b):
    """A ~20-stud flag mast: blue studded foot, white pole with blue bands, gold top, a blue flag with the orange fish
    on both faces and an orange fish windsock below it."""
    mx, my = MAST
    b.box((mx - 0.8, my - 0.8, FLOOR - 0.05), (mx + 0.8, my + 0.5, 2.2), P.BLUE, bevel=0.06)
    grid_studs(b, (mx - 0.4, mx + 0.4), (my - 0.4,), 2.2, P.BLUE)
    b.cyl(mx, my, 2.15, 20.4, 0.3, P.WHITE, 8)
    for z in (6.0, 11.0, 16.0):
        b.cyl(mx, my, z, z + 0.4, 0.36, P.BLUE, 8)
    b.cyl(mx, my, 20.4, 20.75, 0.5, P.YELLOW, 8)
    stud(b, mx, my, 20.75, P.YELLOW)
    y0, y1 = my - 0.08, my + 0.08
    b.box((mx + 0.25, y0, 17.2), (mx + 4.4, y1, 19.95), P.BLUE, bevel=0.03)
    for za, zb in ((16.95, 17.25), (19.9, 20.2)):           # r4: red hem top and bottom
        b.box((mx + 0.25, y0 - 0.03, za), (mx + 4.4, y1 + 0.03, zb), P.RED, bevel=0.02)
    for ya, yb in ((y0 - 0.06, y0), (y1, y1 + 0.06)):
        fish_side(b, ya, yb, mx + 2.45, 18.57, 1.05, P.ORANGE, P.YELLOW)
    fish_eye(b, y0 - 0.06, mx + 2.45, 18.57, 1.05)
    fish_side(b, my - 0.18, my + 0.18, mx + 0.25 + 1.45 * 1.1, 15.4, 1.1, P.ORANGE, P.YELLOW)


def lv1_floor(b):
    """2-tone 2x2 plaza tiles (0.05 seams) over the code plinth, around the tiled walkway."""
    wx0, wy0, wx1, wy1 = WALK
    for i in range(21):
        for j in range(18):
            x0, x1 = max(-21.0 + 2 * i, -20.7), min(-19.0 + 2 * i, 20.7)
            y0, y1 = max(-18.0 + 2 * j, -17.7), min(-16.0 + 2 * j, 17.7)
            if x1 > wx0 and x0 < wx1 and y0 < wy1:                  # clip to the walkway's edge
                if x0 >= wx0 and x1 <= wx1:
                    y0 = wy1 + 0.05
                elif x0 < wx0:
                    x1 = wx0 - 0.05
                else:
                    x0 = wx1 + 0.05
            ax0, ay0, ax1, _ = AISLE
            if y1 > ay0 and x1 > ax0 and x0 < ax1:                  # r5: clip to the centre aisle
                if x0 >= ax0 and x1 <= ax1:
                    y1 = ay0 - 0.05
                elif x0 < ax0:
                    x1 = ax0 - 0.05
                else:
                    x0 = ax1 + 0.05
            if x1 - x0 > 0.3 and y1 - y0 > 0.3:
                odd = (i * 7 + j * 3) % 17                  # r6: a few tan / grey tiles, inset 0.04
                c, top = {0: (P.TAN, FLOOR + 0.02), 9: (P.LBG, FLOOR + 0.02)}.get(odd, ((P.WHITE, P.PALE)[(i + j) % 2], FLOOR + 0.06))
                b.box((x0 + 0.025, y0 + 0.025, FLOOR - 0.02), (x1 - 0.025, y1 - 0.025, top), c, bevel=0.02)


BARRELS = ((-18.6, 6.2), (-18.6, 8.4), (-16.6, 7.3))
CART = (14.6, 3.2)
TUB = (8.6, 6.6)


def barrel(b, x, y):
    b.cyl(x, y, FLOOR, FLOOR + 2.0, 0.85, P.BROWN, 10)
    for z in (FLOOR + 0.35, FLOOR + 1.45):
        b.cyl(x, y, z, z + 0.2, 0.9, P.DBG, 10)
    b.cyl(x, y, FLOOR + 2.0, FLOOR + 2.1, 0.7, P.TAN, 10)
    stud(b, x, y, FLOOR + 2.1, P.TAN)


def lv1_yard(b):
    """r3: the courtyard gets stock: a crate stack of brick fish, barrels, a fish cart and an ice tub."""
    slat_crate(b, -17.0, 1.6, -15.0, 3.4, FLOOR, 1.5)
    fish_crate(b, -16.75, 1.8, -15.25, 3.2, FLOOR + 1.45, 1.0, [(-16.0, 2.5, 0.3)], L=1.3)
    fish_crate(b, -14.8, 1.8, -13.0, 3.4, FLOOR, 1.2, [(-13.9, 2.6, 2.7)], L=1.4)
    fish_crate(b, 16.0, 9.4, 17.8, 11.0, FLOOR, 1.4, [(16.9, 10.2, 0.9)], L=1.4)
    for x, y in BARRELS:
        barrel(b, x, y)
    cx, cy = CART                                           # fish cart: blue tub on two wheels, a red handle
    b.box((cx - 1.6, cy - 1.0, 1.55), (cx + 1.6, cy + 1.0, 2.75), P.BLUE, bevel=0.05)
    b.box((cx - 1.7, cy - 1.1, 2.75), (cx + 1.7, cy + 1.1, 2.95), P.WHITE, bevel=0.04)
    b.box((cx - 1.45, cy - 0.85, 2.75), (cx + 1.45, cy + 0.85, 3.03), P.GLASS, bevel=0.02)
    for k, fx in enumerate((-0.9, 0.0, 0.9)):
        body, acc = ((P.ORANGE, P.YELLOW), (P.LBG, P.DBG), (P.YELLOW, P.ORANGE))[k]
        flat_fish(b, cx + fx, cy, 3.03, 1.5, body, acc, -math.pi / 2)
    wheel = lambda r: [(cx + r * math.cos(i * math.pi / 6), FLOOR + 0.78 + r * math.sin(i * math.pi / 6)) for i in range(12)]
    for ya, yb in ((cy - 1.37, cy - 1.02), (cy + 1.02, cy + 1.37)):
        prism_y_ccw(b, ya, yb, wheel(0.78), P.BLACK)
        prism_y_ccw(b, ya - 0.05 if ya < cy else yb, yb + 0.05 if ya > cy else ya, wheel(0.3), P.YELLOW)
    b.box((cx - 1.45, cy - 0.2, FLOOR), (cx - 1.05, cy + 0.2, 1.6), P.DBG, bevel=0.03)          # front leg
    for y in (cy - 0.7, cy + 0.7):
        b.box((cx + 1.6, y - 0.1, 2.35), (cx + 2.9, y + 0.1, 2.55), P.RED, bevel=0.03)
    b.box((cx + 2.7, cy - 0.85, 2.3), (cx + 2.95, cy + 0.85, 2.6), P.RED, bevel=0.03)
    tx, ty = TUB                                            # ice tub of fish
    b.cyl(tx, ty, FLOOR, FLOOR + 1.15, 1.2, P.LBG, 12)
    b.cyl(tx, ty, FLOOR + 0.85, FLOOR + 1.05, 1.27, P.DBG, 12)
    b.cyl(tx, ty, FLOOR + 1.15, FLOOR + 1.22, 1.0, P.GLASS, 12)
    for k, ang in enumerate((0.3, 2.4, 4.4)):
        body, acc = BRIGHT[k % 2]
        fish(b, tx + 0.45 * math.cos(ang), ty + 0.45 * math.sin(ang), FLOOR + 1.22, 1.1, body, acc, ang + 1.2)


def lv1_col(c):
    for x0, y0, x1, y1 in ((-WALL_X - 0.4, -WALL_Y - 0.4, -WALL_X + 0.4, WALL_Y - 0.4),
                           (WALL_X - 0.4, -WALL_Y - 0.4, WALL_X + 0.4, WALL_Y - 0.4),
                           (-WALL_X + 0.4, -WALL_Y - 0.4, -GATE_X - 0.69, -WALL_Y + 0.4),
                           (GATE_X + 0.69, -WALL_Y - 0.4, WALL_X - 0.4, -WALL_Y + 0.4)):
        c.box((x0, y0, FLOOR), (x1, y1, 3.5 if x1 - x0 < 2 else 2.36), P.WHITE)
    c.box((-WALL_X - 0.4, WALL_Y - 0.4, FLOOR), (WALL_X + 0.4, WALL_Y + 0.4, BACK_TOP + 0.3), P.WHITE)
    pts = [(s * WALL_X, y, 4.4) for s in (-1, 1) for y in SIDE_PILLARS] + \
          [(s * x, -WALL_Y, 3.3) for s in (-1, 1) for x in FRONT_PILLARS] + [(x, WALL_Y, 6.6) for x in BACK_PILLARS] + \
          [(s * WALL_X, y, t) for s in (-1, 1) for y, t in ((-WALL_Y, 4.4), (WALL_Y, 6.6))]
    for x, y, top in pts:
        c.box((x - 0.65, y - 0.65, FLOOR), (x + 0.65, y + 0.65, top), P.WHITE)
    for s in (-1, 1):
        c.box((s * GATE_X - 0.69, -WALL_Y - 0.69, FLOOR), (s * GATE_X + 0.69, -WALL_Y + 0.69, GATE_TOP), P.WHITE)
    c.box((-GATE_X - 0.74, -WALL_Y - 0.55, GATE_TOP), (GATE_X + 0.74, -WALL_Y + 0.55, LINTEL_TOP), P.WHITE)
    for cx in (-BOOTH_X, BOOTH_X):                          # the counters stay the code `Counter` parts (the shop act)
        for x in (-4.1, 4.1):
            c.box((cx + x - 0.345, BOOTH_Y - 1.545, FLOOR), (cx + x + 0.345, BOOTH_Y - 0.855, 7.95), P.WHITE)
            c.box((cx + x - 0.3, BOOTH_Y - 0.855, FLOOR), (cx + x + 0.3, BOOTH_Y + 3.555, 2.55), P.WHITE)
            c.box((cx + x - 0.15, BOOTH_Y - 0.855, 2.55), (cx + x + 0.15, BOOTH_Y + 3.555, PANEL_TOP), P.WHITE)
            c.box((cx + x - 0.345, BOOTH_Y + 3.555, FLOOR), (cx + x + 0.345, BOOTH_Y + 4.245, 8.93), P.WHITE)
        c.box((cx - 3.755, BOOTH_Y + 3.75, FLOOR), (cx + 3.755, BOOTH_Y + 4.05, BACK_PANEL_TOP), P.WHITE)
        c.box((cx - R_HW, BOOTH_Y + R_Y0, R_Z0), (cx + R_HW, BOOTH_Y + R_Y1, 9.85), P.WHITE)
        for x0, x1 in ((-3.45, -1.45), (1.45, 3.35)):
            a, bb = sorted((cx + x0 * (1 if cx > 0 else -1), cx + x1 * (1 if cx > 0 else -1)))
            c.box((a, BOOTH_Y + 2.0, FLOOR), (bb, BOOTH_Y + 3.7, FLOOR + 1.5), P.WHITE)
    sx, sy = SCALE_XY
    c.box((sx - 0.8, sy - 0.8, FLOOR), (sx + 0.8, sy + 0.8, 6.75), P.WHITE)
    for s in (-1, 1):
        c.box((s * 17.24 - 1.95, -9.52, FLOOR), (s * 17.24 + 1.95, -5.62, 2.5), P.WHITE)
    x0, y0, x1, y1 = ISLAND
    c.box((x0 - 0.1, y0 - 0.1, FLOOR), (x1 + 0.1, y1 + 0.1, 2.56), P.WHITE)
    for x0_, y0_, x1_, y1_, h in PATH_CRATES + BACK_COLS:
        c.box((x0_, y0_, FLOOR), (x1_, y1_, FLOOR + h), P.WHITE)
    for lo, hi in (((-17.0, 1.6), (-15.0, 3.4)), ((-14.8, 1.8), (-13.0, 3.4)), ((16.0, 9.4), (17.8, 11.0)),
                   ((CART[0] - 1.7, CART[1] - 1.35), (CART[0] + 2.95, CART[1] + 1.35)),
                   ((TUB[0] - 1.27, TUB[1] - 1.27), (TUB[0] + 1.27, TUB[1] + 1.27))):
        c.box((lo[0], lo[1], FLOOR), (hi[0], hi[1], 2.5), P.WHITE)
    for x, y in BARRELS + BARRELS2:
        c.box((x - 0.85, y - 0.85, FLOOR), (x + 0.85, y + 0.85, FLOOR + 2.1), P.WHITE)
    for sx0, sy0, sx1, sy1, n in STACKS:                     # r5: back-half stock
        c.box((sx0, sy0, FLOOR), (sx1, sy1, FLOOR + n * 1.15 + 0.05), P.WHITE)
    c.box((ICE_TABLE[0], ICE_TABLE[1], FLOOR), (ICE_TABLE[2], ICE_TABLE[3], 2.92), P.WHITE)
    for fx in (FISH_RACK[0] + 0.2, FISH_RACK[1] - 0.2):
        c.box((fx - 0.3, FISH_RACK[2] - 0.3, FLOOR), (fx + 0.3, FISH_RACK[2] + 0.3, 4.9), P.WHITE)
    for s in (-1, 1):
        c.box((s * LANTERN_X - 0.55, LANTERN_Y - 0.55, 0.0), (s * LANTERN_X + 0.55, LANTERN_Y + 0.55, 4.85), P.WHITE)
    for cx in (x0 - 1.2, x1 + 1.2):
        c.box((cx - 0.95, y0 + 0.3, FLOOR), (cx + 0.95, y0 + 2.2, 2.0), P.WHITE)


def lv1_rack_col(c):
    for dx in (-5.29, 5.29):
        c.box((RACK_X + dx - 0.46, RACK_Y - 0.46, FLOOR), (RACK_X + dx + 0.46, RACK_Y + 0.46, 8.97), P.WHITE)
    mx, my = MAST
    c.box((mx - 0.8, my - 0.8, FLOOR), (mx + 0.8, my + 0.5, 20.4), P.WHITE)
    for s in (-1, 1):                                       # r5: centre stall pillars on the island
        for y in (CANOPY_YF, CANOPY_YB):
            c.box((s * CANOPY_PX - 0.4, y - 0.4, 2.56), (s * CANOPY_PX + 0.4, y + 0.4, canopy_underside(y)), P.WHITE)


# r5: Lv1 centre: a real stall front on the island (fills the gate view): blue brick pillars front and back, a
# blue/white scalloped awning with studs and the fish plaque (Lv1_L06: gives way to the Lv3 smokehouse)
CANOPY_PX, CANOPY_Z = 3.6, 5.0                              # pillar centre x, front pillar top (under the Lv1 lintel from the path)
CANOPY_YF, CANOPY_YB = ISLAND[1] + 0.5, ISLAND[3] - 0.5     # front / back pillar centre y
CANOPY_HW = 4.4


def canopy_underside(y):
    return CANOPY_Z + (y - CANOPY_YF) * math.tan(AWNING_TILT)


def lv1_canopy(b):
    for s in (-1, 1):
        x = s * CANOPY_PX
        for y in (CANOPY_YF, CANOPY_YB):
            top = canopy_underside(y) + 0.1
            b.box((x - 0.5, y - 0.5, 2.56), (x + 0.5, y + 0.5, 2.82), P.WHITE, bevel=0.03)   # base plate
            z, k = 2.82, 0
            while z < top - 0.1:                                                         # 1x1 bricks, white band
                zt = min(z + 1.2, top)
                b.box((x - 0.4, y - 0.4, z), (x + 0.4, y + 0.4, zt), (P.BLUE, P.BLUE, P.WHITE)[k % 3], bevel=0.04)
                z, k = zt, k + 1
    local = lego.B()
    yf, yb = ISLAND[1] - 0.45, ISLAND[3] + 0.1                 # awning front / back edge
    hs = (yb - yf) / 2 / math.cos(AWNING_TILT)
    ft, ca, sa, sw = awning_slab(local, 0, 0.0, 0.0, CANOPY_HW, hs, drops=(0.55, 0.3), cols=(P.BLUE, P.WHITE))
    for i in range(AW_STRIPES):
        for u in (0.45, 2 * hs - 0.45):
            if not (i in (2, 3, 4) and u < 1.0):
                _tilted_stud(local, -CANOPY_HW + (i + 0.5) * sw, up(ft, sa, ca, i), u, ca, sa, (P.BLUE, P.WHITE)[i % 2])
    plaque = lambda pts, o0, o1, col: _tilted_poly(local, pts, ft, ca, sa, o0, o1, col)
    plaque([(-1.8, 0.25), (1.8, 0.25), (1.8, 2.25), (-1.8, 2.25)], -0.05, 0.36, P.RED)
    plaque([(-1.55, 0.5), (1.55, 0.5), (1.55, 2.0), (-1.55, 2.0)], 0.36, 0.44, P.WHITE)
    plaque([(-0.9, 0.8), (1.0, 0.8), (1.0, 1.7), (-0.9, 1.7)], 0.44, 0.54, P.ORANGE)
    plaque([(-0.75, 1.25), (-1.4, 0.75), (-1.4, 1.75)], 0.44, 0.54, P.YELLOW)
    plaque([(0.55, 1.3), (0.8, 1.3), (0.8, 1.55), (0.55, 1.55)], 0.54, 0.58, P.INK)
    yc = (yf + yb) / 2                                      # slab centre: its underside meets the front pillar top
    zc = canopy_underside(yc + AW_T * math.sin(AWNING_TILT)) + AW_T * math.cos(AWNING_TILT)
    place_rot(b, local, 0.0, yc, zc, 0.0)


# r4: fish crates (1.5x) lined along the path front, inside the low wall either side of the gate
PATH_CRATES = tuple((s * a, -17.6, s * c, -15.0, h) if s > 0 else (s * c, -17.6, s * a, -15.0, h)
                    for s in (-1, 1) for a, c, h in ((6.9, 9.9, 2.5), (10.3, 13.3, 1.5)))   # r6: 2 big stacks a side
# r4: back-half clutter: a net rack (left) and a bench with a lobster pot (right)
NET = (-16.8, -11.6, 15.6)
BENCH = (13.2, 17.0, 16.3)
BACK_COLS = ((NET[0] - 0.3, NET[2] - 0.3, NET[1] + 0.3, NET[2] + 0.3, 5.0),
             (BENCH[0], BENCH[2] - 0.55, BENCH[1], BENCH[2] + 0.55, 1.5))


def lv1_path_crates(b):
    for x0, y0, x1, y1, h in PATH_CRATES:
        ice_stack(b, x0, y0, x1, y1, FLOOR, (1.4, 1.14) if h > 2 else (h,))


def lv1_back_clutter(b):
    x0, x1, y = NET                                         # net rack: two posts, a bar, a dark net with floats
    for x in (x0, x1):
        b.box((x - 0.3, y - 0.3, FLOOR), (x + 0.3, y + 0.3, 5.0), P.BROWN, bevel=0.04)
        stud(b, x, y, 5.0, P.BROWN)
    b.box((x0, y - 0.2, 4.4), (x1, y + 0.2, 4.75), P.TAN, bevel=0.03)
    for i in range(1, 9):
        xx = x0 + i * (x1 - x0) / 9
        b.box((xx - 0.04, y - 0.06, 1.6), (xx + 0.04, y + 0.06, 4.4), P.DBG, bevel=0.0)
    for z in (1.6, 2.3, 3.0, 3.7):
        b.box((x0 + 0.3, y - 0.05, z - 0.04), (x1 - 0.3, y + 0.05, z + 0.04), P.DBG, bevel=0.0)
    for k, xx in enumerate((x0 + 1.4, x0 + 2.9, x0 + 4.0)):
        b.cyl(xx, y - 0.12, 3.85 - k * 0.7, 4.3 - k * 0.7, 0.32, (P.ORANGE, P.YELLOW, P.RED)[k], 8)
    x0, x1, y = BENCH                                       # bench: blue seat, white legs, a lobster pot on top
    for x in (x0 + 0.4, x1 - 0.4):
        b.box((x - 0.25, y - 0.45, FLOOR), (x + 0.25, y + 0.45, 1.6), P.WHITE, bevel=0.03)
    b.box((x0, y - 0.55, 1.6), (x1, y + 0.55, 1.9), P.BLUE, bevel=0.04)
    for x in (x0 + 0.5, x0 + 1.5, x0 + 2.5):
        stud(b, x, y, 1.9, P.BLUE)
    px = x1 - 0.9                                           # lobster pot: tan frame, dark slats
    b.box((px - 0.6, y - 0.45, 1.9), (px + 0.6, y + 0.45, 2.0), P.TAN, bevel=0.02)
    for xx in (px - 0.5, px, px + 0.5):
        b.box((xx - 0.05, y - 0.4, 2.0), (xx + 0.05, y + 0.4, 2.8), P.DBG, bevel=0.0)
    b.box((px - 0.6, y - 0.45, 2.8), (px + 0.6, y + 0.45, 2.92), P.TAN, bevel=0.02)


# r5: a blue/tan 1-stud tile border round each booth (0.05 over the plaza tiles; stops short of the Lv2 stall pads)
def lv1_border(b):
    z0, z1 = FLOOR + 0.02, FLOOR + 0.11
    for s in (-1, 1):
        runs = (((5.6, -13.9), (14.6, -12.9), True), ((5.6, -12.9), (6.6, -6.9), False),
                ((5.6, -6.9), (16.7, -5.9), True), ((15.7, -12.9), (16.7, -6.9), False))
        k = 0
        for (ax, ay), (bx, by), along_x in runs:
            a0, a1 = (ax, bx) if along_x else (ay, by)
            p = a0
            while p < a1 - 0.3:
                q = min(p + 2.0, a1)
                lo, hi = p + 0.025, q - 0.025
                x0_, x1_, y0_, y1_ = (lo, hi, ay, by) if along_x else (ax, bx, lo, hi)
                x0_, x1_ = sorted((s * x0_, s * x1_))
                b.box((x0_, y0_ + (0.025 if along_x else 0.0), z0), (x1_, y1_ - (0.025 if along_x else 0.0), z1),
                      (P.BLUE, P.TAN)[k % 2], bevel=0.02)
                p, k = q, k + 1


# r5: back-half stock: stud-topped crate stacks, an ice-bin table, a barrel cluster, a hanging-fish rack
STACKS = ((-20.4, 11.0, -18.6, 12.8, 3), (-20.4, 13.2, -18.6, 15.0, 2), (18.6, 8.8, 20.4, 10.6, 3))
ICE_TABLE = (-15.5, 10.6, -11.5, 12.4)
BARRELS2 = ((-8.6, 16.0), (-10.4, 16.0), (-9.45, 14.35))
FISH_RACK = (16.6, 20.4, 13.8)


def lv1_back_stock(b):
    for x0, y0, x1, y1, n in STACKS:
        for i in range(n):                                  # each crate sits 0.05 into the one below
            slat_crate(b, x0 + 0.06 * (i % 2), y0 + 0.06 * (i % 2), x1 - 0.06 * (i % 2), y1, FLOOR + i * 1.15, 1.2)
        grid_studs(b, (x0 + 0.45, x1 - 0.45), (y0 + 0.45, y1 - 0.45), FLOOR + n * 1.15 + 0.05, P.BROWN)
    x0, y0, x1, y1 = ICE_TABLE                              # ice-bin table: white legs, blue bin, ice, brick fish
    for x in (x0 + 0.3, x1 - 0.3):
        for y in (y0 + 0.3, y1 - 0.3):
            b.box((x - 0.2, y - 0.2, FLOOR), (x + 0.2, y + 0.2, 1.9), P.WHITE, bevel=0.03)
    b.box((x0, y0, 1.9), (x1, y1, 2.7), P.BLUE, bevel=0.05)
    b.box((x0 - 0.08, y0 - 0.08, 2.7), (x1 + 0.08, y1 + 0.08, 2.92), P.WHITE, bevel=0.04)
    b.box((x0 + 0.3, y0 + 0.3, 2.7), (x1 - 0.3, y1 - 0.3, 2.98), P.GLASS, bevel=0.02)
    for k, fx in enumerate((-1.35, -0.45, 0.45, 1.35)):
        body, acc = FISH_SETS[k]
        flat_fish(b, (x0 + x1) / 2 + fx, (y0 + y1) / 2, 2.98, 1.35, body, acc, -math.pi / 2 + (0.2 if k % 2 else -0.2))
    for x, y in BARRELS2:
        barrel(b, x, y)
    x0, x1, y = FISH_RACK                                   # hanging-fish rack: brown posts, tan bar, four fish
    for x in (x0 + 0.2, x1 - 0.2):
        b.box((x - 0.5, y - 0.5, FLOOR - 0.02), (x + 0.5, y + 0.5, FLOOR + 0.25), P.TAN, bevel=0.03)
        b.box((x - 0.2, y - 0.2, FLOOR + 0.25), (x + 0.2, y + 0.2, 4.9), P.BROWN, bevel=0.03)
        stud(b, x, y, 4.9, P.BROWN, r=0.15)
    b.box((x0, y - 0.15, 4.4), (x1, y + 0.15, 4.7), P.TAN, bevel=0.03)
    for i in range(4):
        fish_hang(b, (x0 + x1) / 2 + (i - 1.5) * 0.85, y, 4.4, 0.85, (P.ORANGE, P.LBG, P.YELLOW, P.ORANGE)[i])


LANTERN_X, LANTERN_Y = 7.3, -19.35                          # r5: path gateposts outside the front wall


def lv1_lanterns(b):
    """Two blue gateposts where the path meets the wall, each topped with a glowing fish lantern."""
    for s in (-1, 1):
        x, y = s * LANTERN_X, LANTERN_Y
        b.box((x - 0.55, y - 0.55, -0.05), (x + 0.55, y + 0.55, 1.3), P.WHITE, bevel=0.05)   # on the ground, off the plinth
        b.box((x - 0.4, y - 0.4, 1.3), (x + 0.4, y + 0.4, 4.6), P.BLUE, bevel=0.05)
        b.box((x - 0.45, y - 0.45, 3.0), (x + 0.45, y + 0.45, 3.3), P.WHITE, bevel=0.03)
        b.box((x - 0.5, y - 0.5, 4.6), (x + 0.5, y + 0.5, 4.85), P.BLACK, bevel=0.03)
        fx, fz, k = x - s * 0.05, 5.0, 0.55
        fish_side(b, y - 0.35, y + 0.35, fx, fz, k, P.WARM, P.ORANGE)        # glowing body, orange tail
        b.box((fx - 0.3 * k, y - 0.4, fz - 0.33 * k), (fx - 0.22 * k, y + 0.4, fz + 0.3 * k), P.ORANGE, bevel=0.01)
        b.box((fx + 0.2 * k, y - 0.4, fz - 0.36 * k), (fx + 0.28 * k, y + 0.4, fz + 0.36 * k), P.ORANGE, bevel=0.01)
        fish_eye(b, y - 0.35, fx, fz, k)
        b.box((fx - 0.15, y - 0.15, fz + 0.3 * k), (fx + 0.15, y + 0.15, fz + 0.3 * k + 0.3), P.BLACK, bevel=0.02)
        stud(b, fx, y, fz + 0.3 * k + 0.3, P.BLACK, r=0.18)


# ------------------------------------------------------------------ Lv2 market gate (reads from the path)
G2_HW, G2_BEAM0, G2_BEAM1, G2_TOP = 0.85, 12.4, 13.6, 14.0   # r5: +2 (own peak): pillar half width, crown beam z, top


def lv2_gate(b):
    """A solid arch over the Lv1 doorway: chunky blue brick pillars with white bands and stud caps, a blue frame with
    stepped arch corners around a white panel set 1 stud back (the Lv1 arch plaque stands on it), a round fish plaque,
    a blue studded cornice with a two-step gable."""
    yf = -WALL_Y - 0.75                                       # frame front face
    for s in (-1, 1):
        x = s * GATE_X
        b.box((x - G2_HW, -WALL_Y - G2_HW, 3.4), (x + G2_HW, -WALL_Y + G2_HW, G2_TOP), P.BLUE, bevel=0.06)
        for z in (3.4, 6.6, 9.4, 11.95):
            b.box((x - G2_HW - 0.05, -WALL_Y - G2_HW - 0.05, z), (x + G2_HW + 0.05, -WALL_Y + G2_HW + 0.05, z + 0.4),
                  P.WHITE, bevel=0.03)
        b.box((x - 1.0, -WALL_Y - 1.0, G2_TOP), (x + 1.0, -WALL_Y + 1.0, G2_TOP + 0.4), P.WHITE, bevel=0.05)
        grid_studs(b, (x - 0.5, x + 0.5), (-WALL_Y - 0.5, -WALL_Y + 0.5), G2_TOP + 0.4, P.WHITE)
        xi = s * (GATE_X - G2_HW)                               # frame jamb + stepped arch corners
        b.box((xi, yf, LINTEL_TOP - 0.05), (xi - s * 0.55, -WALL_Y + 0.3, G2_BEAM0 + 0.02), P.BLUE, bevel=0.03)
        for k, (w, z0) in enumerate(((1.0, G2_BEAM0 - 1.25), (0.5, G2_BEAM0 - 1.75))):
            b.box((xi - s * 0.55, yf + 0.1, z0), (xi - s * (0.55 + w), -WALL_Y + 0.3, z0 + 0.5 if k else G2_BEAM0 - 0.25),
                  P.BLUE, bevel=0.03)
    b.box((-GATE_X + G2_HW - 0.1, yf, G2_BEAM0 - 0.3), (GATE_X - G2_HW + 0.1, -WALL_Y + 0.3, G2_BEAM0 + 0.02),
          P.BLUE, bevel=0.03)                                 # frame head
    b.box((-GATE_X + G2_HW - 0.1, -WALL_Y + 0.25, LINTEL_TOP - 0.05), (GATE_X - G2_HW + 0.1, -WALL_Y + 0.75, G2_BEAM0 + 0.05),
          P.WHITE, bevel=0.03)                                # the white panel, 1 stud behind the frame face
    b.box((-GATE_X - 0.6, -WALL_Y - 0.85, G2_BEAM0), (GATE_X + 0.6, -WALL_Y + 0.85, G2_BEAM1), P.BLUE, bevel=0.05)
    b.box((-GATE_X - 0.7, -WALL_Y - 1.0, G2_BEAM1), (GATE_X + 0.7, -WALL_Y + 1.0, G2_BEAM1 + 0.3), P.BLUE, bevel=0.04)
    b.box((-GATE_X - 0.65, -WALL_Y - 0.95, G2_BEAM0 + 0.45), (GATE_X + 0.65, -WALL_Y + 0.95, G2_BEAM0 + 0.7), P.WHITE,
          bevel=0.03)                                         # white band along the cornice
    zc = G2_BEAM1 + 0.3                                       # r5: stepped gable on the cornice (the gate's own peak)
    for x in range(-6, 7):
        for y in (-0.45, 0.45):
            if abs(x) > 3.4:
                stud(b, x + 0.0, -WALL_Y + y, zc, P.BLUE)
    for hw, h in ((3.4, 1.2), (2.2, 1.2)):                 # r6: two steps (the smokehouse front keeps its sky)
        b.box((-hw, -WALL_Y - 0.6, zc), (hw, -WALL_Y + 0.6, zc + h), P.BLUE, bevel=0.05)
        b.box((-hw - 0.08, -WALL_Y - 0.68, zc + h), (hw + 0.08, -WALL_Y + 0.68, zc + h + 0.25), P.WHITE, bevel=0.04)
        zc += h + 0.25
        for x in (-hw + 0.6, hw - 0.6):                     # studs on the ledge the next step leaves free
            for y in (-0.3, 0.3):
                stud(b, x, -WALL_Y + y, zc, P.WHITE)
    circ = lambda r, cz, n=16: [(r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    cz, yg = G2_BEAM1 + 1.65, -WALL_Y - 0.6                   # r6: round fish plaque inside the gable outline
    prism_y_ccw(b, yg - 0.25, yg + 0.05, circ(1.45, cz), P.WHITE)
    prism_y_ccw(b, yg - 0.4, yg - 0.25, circ(1.18, cz), P.RED)
    fish_side(b, yg - 0.46, yg - 0.4, 0.15, cz, 0.66, P.ORANGE, P.YELLOW)
    fish_eye(b, yg - 0.46, 0.15, cz, 0.66)
    xs, n = GATE_X - G2_HW - 1.55, 6                          # red/white scalloped valance between the arch corners
    for i in range(n):
        x0 = -xs + i * 2 * xs / n
        scallop(b, x0 + 0.02, x0 + 2 * xs / n - 0.02, yf - 0.06, yf + 0.14, G2_BEAM0 - 0.25, G2_BEAM0 - 1.25 - 0.2 * (i % 2),
                (P.RED, P.WHITE)[i % 2])


def lv2_gate_col(c):
    for s in (-1, 1):
        c.box((s * GATE_X - G2_HW, -WALL_Y - G2_HW, 3.4), (s * GATE_X + G2_HW, -WALL_Y + G2_HW, G2_TOP + 0.4), P.WHITE)
    c.box((-GATE_X + G2_HW, -WALL_Y - 0.75, LINTEL_TOP), (GATE_X - G2_HW, -WALL_Y + 0.75, G2_BEAM1 + 0.3), P.WHITE)
    c.box((-3.4, -WALL_Y - 0.6, G2_BEAM1 + 0.3), (3.4, -WALL_Y + 0.6, G2_BEAM1 + 1.75), P.WHITE)   # r5: gable


# ------------------------------------------------------------------ Lv3 smokehouse refinements
def smokehouse_front(b):
    """Red door portal, a framed fish plaque on a tan ledge above it, white window sills."""
    y = SH_Y0
    b.box((DOOR_X0 - 0.2, y - 0.25, PAD), (DOOR_X0 + 0.3, y + 0.06, DOOR_TOP + 0.3), P.RED, bevel=0.04)
    b.box((DOOR_X1 - 0.3, y - 0.25, PAD), (DOOR_X1 + 0.2, y + 0.06, DOOR_TOP + 0.3), P.RED, bevel=0.04)
    b.box((DOOR_X0 - 0.3, y - 0.3, DOOR_TOP - 0.3), (DOOR_X1 + 0.3, y + 0.06, DOOR_TOP + 0.35), P.RED, bevel=0.04)
    b.box((-0.7, y - 0.5, 8.5), (3.7, y + 0.05, 8.7), P.TAN, bevel=0.03)          # r4: plaque up over the awning
    b.box((-0.6, y - 0.3, 8.7), (3.6, y + 0.05, 10.2), P.RED, bevel=0.04)
    b.box((-0.4, y - 0.35, 8.85), (3.4, y - 0.3, 10.05), P.WHITE, bevel=0.02)
    fish_side(b, y - 0.4, y - 0.35, 1.6, 9.45, 0.95, P.ORANGE, P.YELLOW)
    fish_eye(b, y - 0.4, 1.6, 9.45, 0.95)
    hs = 0.9                                                # r4: red/white striped awning over the door, studded
    local = lego.B()
    ft, ca, sa, sw = awning_slab(local, 0, 0.0, 0.0, (DOOR_X1 - DOOR_X0) / 2 + 0.6, hs, drops=(0.3, 0.15))
    for i in range(AW_STRIPES):
        _tilted_stud(local, -((DOOR_X1 - DOOR_X0) / 2 + 0.6) + (i + 0.5) * sw, up(ft, sa, ca, i), 1.25, ca, sa,
                     (P.WHITE, P.RED)[i % 2])
    place_rot(b, local, (DOOR_X0 + DOOR_X1) / 2, y - hs * math.cos(AWNING_TILT) - 0.03, 7.85, 0.0)
    bands = [(z0 - 0.45, z0 - 0.15) for z0 in (WIN_Z0, WIN2_Z0)] + [(z1 + 0.12, z1 + 0.42) for z1 in (WIN_Z1, WIN2_Z1)]
    for k, (za, zb) in enumerate(bands):                    # r6: white sill + lintel bands round each storey
        spans = ((SH_X0, DOOR_X0 - 0.1), (DOOR_X1 + 0.1, SH_X1)) if k == 0 else ((SH_X0, SH_X1),)
        for xa, xb in spans:
            b.box((xa, y - 0.18, za), (xb, y + 0.02, zb), P.WHITE, bevel=0.03)
        for face, s in ((SH_X0, -1), (SH_X1, 1)):
            a, bb = sorted((face - s * 0.02, face + s * 0.18))
            b.box((a, SH_Y0, za), (bb, SH_Y1, zb), P.WHITE, bevel=0.03)
    for face, s in ((SH_X0, -1), (SH_X1, 1)):
        a, bb = sorted((face - s * 0.05, face + s * 0.4))
        for z in (WIN_Z0, WIN2_Z0):                         # r5: sills on both storeys
            b.box((a, WIN_Y0 - 0.3, z - 0.4), (bb, WIN_Y1 + 0.3, z - 0.12), P.WHITE, bevel=0.03)


def smokehouse_plinth(b):
    """Blue-trim plinth with a porch and a doorstep, blue corner posts up to the eaves (local frame, lifted later)."""
    x0, x1, y0, y1, z0 = SH_X0 - 0.5, SH_X1 + 0.5, SH_Y0 - 2.9, SH_Y1 + 0.3, FLOOR - SH_LIFT
    b.box((x0, y0, z0), (x1, y1, PAD - 0.12), P.WHITE, bevel=0.04)
    b.box((x0, y0, PAD - 0.12), (x1, y1, PAD), P.TAN, bevel=0.02)
    b.box((x0 - 0.05, y0 - 0.05, PAD - 0.45), (x1 + 0.05, y1 + 0.05, PAD - 0.17), P.BLUE, bevel=0.03)
    b.box((DOOR_X0, y0 - 1.0, z0), (DOOR_X1, y0, PAD - SH_LIFT / 2), P.TAN, bevel=0.03)
    b.box((DOOR_X0 - 0.05, y0 - 1.05, PAD - SH_LIFT / 2 - 0.25), (DOOR_X1 + 0.05, y0 - 0.2, PAD - SH_LIFT / 2 - 0.05),
          P.BLUE, bevel=0.02)
    for xa, xb in ((SH_X0 - 0.2, SH_X0 + 0.45), (SH_X1 - 0.45, SH_X1 + 0.2)):
        for ya, yb in ((SH_Y0 - 0.2, SH_Y0 + 0.45), (SH_Y1 - 0.45, SH_Y1 + 0.2)):
            b.box((xa, ya, PAD - 0.05), (xb, yb, EAVE - 0.15), P.BLUE, bevel=0.05)
            b.box((xa - 0.05, ya - 0.05, 1.65), (xb + 0.05, yb + 0.05, 1.95), P.WHITE, bevel=0.03)
            for k in range(2, N_COURSE - 1, 2):             # r5: white corner quoins every other course
                z = PAD + k * COURSE
                b.box((xa - 0.06, ya - 0.06, z + 0.04), (xb + 0.06, yb + 0.06, z + COURSE - 0.04), P.WHITE, bevel=0.03)


def smokehouse_doors(b):
    """Two plank door leaves standing open on the porch, tan braces, black hinges; a lit lamp inside the door."""
    for xh, s in ((DOOR_X0, -1), (DOOR_X1, 1)):
        xa, xb = sorted((xh + s * 0.05, xh - s * 0.2))
        ya, yb, za, zb = SH_Y0 - 2.75, SH_Y0 - 0.3, PAD + 0.15, DOOR_TOP - 0.45
        w = (yb - ya - 0.12) / 3
        for k in range(3):
            b.box((xa, ya + k * (w + 0.06), za), (xb, ya + k * (w + 0.06) + w, zb), P.BROWN, bevel=0.04)
        ba, bb = sorted((xh + s * 0.02, xh + s * 0.12))
        for z in (za + 0.6, zb - 1.0):
            b.box((ba, ya + 0.15, z), (bb, yb - 0.15, z + 0.35), P.TAN, bevel=0.03)
            b.box((ba - s * 0.03, yb - 0.4, z + 0.05), (bb + s * 0.03, yb - 0.05, z + 0.3), P.BLACK, bevel=0.01)
    b.box((SH_X0 + WALL, 9.0, 8.3), (SH_X1 - WALL, 9.2, 8.5), P.BROWN, bevel=0.02)
    b.box((1.46, 9.06, 6.9), (1.54, 9.14, 8.3), P.BLACK, bevel=0.0)
    b.box((1.2, 8.8, 6.75), (1.8, 9.4, 6.9), P.BLACK, bevel=0.02)
    b.box((1.25, 8.85, 6.05), (1.75, 9.35, 6.75), P.WARM, bevel=0.02)
    b.box((1.2, 8.8, 5.9), (1.8, 9.4, 6.05), P.BLACK, bevel=0.02)


RACK3 = (-10.8, -6.0, 2.2)                                  # r4: smoke rack out front-left on the plaza (world x span, y)
SH_BARRELS = ((6.4, 2.3), (8.2, 2.0))                       # r4: two barrels out front-right


def smokehouse_yard_rack(b):
    x0, x1, y = RACK3
    for x in (x0 + 0.2, x1 - 0.2):
        b.box((x - 0.5, y - 0.5, FLOOR - 0.02), (x + 0.5, y + 0.5, FLOOR + 0.25), P.TAN, bevel=0.03)
        b.box((x - 0.15, y - 0.15, FLOOR + 0.25), (x + 0.15, y + 0.15, 5.45), P.BROWN, bevel=0.03)
    b.box((x0, y - 0.15, 5.2), (x1, y + 0.15, 5.45), P.TAN, bevel=0.03)
    for i in range(4):
        fish_hang(b, (x0 + x1) / 2 + (i - 1.5), y, 5.2, 0.95, (P.ORANGE, P.YELLOW, P.ORANGE, P.YELLOW)[i])
    m = (x0 + x1) / 2
    b.box((m - 0.6, y - 0.5, FLOOR - 0.02), (m + 0.6, y + 0.5, 1.5), P.DBG, bevel=0.04)  # brazier under the fish
    b.box((m - 0.5, y - 0.4, 1.5), (m + 0.5, y + 0.4, 1.62), P.ORANGE, bevel=0.02)
    for bx, by in SH_BARRELS:
        barrel(b, bx, by)


def sh_pt(x, y, z):
    t = lego.B()
    t.v = [(x, y, z)]
    return tuple(round(c, 3) for c in sh_xf(t).v[0])


def smokehouse_roof_studs(b):
    L = math.hypot(1.5 - ROOF_X0, RIDGE - EAVE)
    for x_e, sgn in ((ROOF_X0, 1), (ROOF_X1, -1)):
        n = (-sgn * (RIDGE - EAVE) / L, 0.0, (1.5 - ROOF_X0) / L)
        for t in (0.3, 0.65):
            x = x_e + sgn * t * (1.5 - ROOF_X0)
            z = EAVE + 0.35 + t * (RIDGE - EAVE)
            for yy in range(8, 17):
                stud_n(b, x, yy + 0.0, z, n, P.BLUE)
    b.box((SH_X0 - 0.25, SH_Y0 - 0.75, EAVE - 0.75), (SH_X1 + 0.25, SH_Y0 + 0.05, EAVE - 0.45), P.WHITE, bevel=0.04)
    for i in range(9):                                      # r6: a studded white eave ledge under the front gable
        stud(b, -2.5 + i, SH_Y0 - 0.45, EAVE - 0.45, P.WHITE)
    for xa, xb, xs in ((ROOF_X0 - 0.12, ROOF_X0 + 0.5, ROOF_X0 + 0.2), (ROOF_X1 - 0.5, ROOF_X1 + 0.12, ROOF_X1 - 0.2)):
        b.box((xa, ROOF_Y0 - 0.12, EAVE - 0.25), (xb, ROOF_Y1 + 0.12, EAVE + 0.47), P.WHITE, bevel=0.04)   # r4 eave course
        for yy in range(8, 17):
            stud(b, xs, yy + 0.0, EAVE + 0.47, P.WHITE)


def build():
    import bpy  # noqa: F401
    patch_lod_names()
    patch_lod_targets()
    mat = lego.material("MI_FishMarket_Brick", ALB)
    meshes = []
    nodes = {k: lego.node(k) for k in ("Lv1", "Lv2", "Lv3")}

    def out(name, b, node):
        if b.empty():
            return
        if not name.endswith("_COL"):                       # r5: drop the bottoms resting on the plinth (hidden)
            b.f = [(f, c) for f, c in b.f if not all(b.v[i][2] <= FLOOR + 0.001 for i in f)]
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[fishmarket] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills doorways
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    lv1_walls(b)
    lv1_walkway(b)
    lv1_lanterns(b)
    out("Lv1_L01_Walls", b, "Lv1")

    b = lego.B()
    for cx, mirror in ((BOOTH_X, False), (-BOOTH_X, True)):
        local = lego.B()
        booth_counter(local)
        booth_stock(local)
        place_m(b, local, cx, BOOTH_Y, mirror)
    out("Lv1_L02_Counters", b, "Lv1")

    b = lego.B()
    for cx, mirror in ((BOOTH_X, False), (-BOOTH_X, True)):
        local = lego.B()
        booth_frames(local)
        place_m(b, local, cx, BOOTH_Y, mirror)
    out("Lv1_L03_Frames", b, "Lv1")

    b = lego.B()
    for cx, mirror in ((BOOTH_X, False), (-BOOTH_X, True)):
        local = lego.B()
        booth_roof(local)
        place_m(b, local, cx, BOOTH_Y, mirror)
    lv1_signs(b)
    out("Lv1_L04_Roofs", b, "Lv1")

    b = lego.B()
    lv1_props(b)
    lv1_yard(b)
    lv1_path_crates(b)
    lv1_back_clutter(b)
    lv1_back_stock(b)
    out("Lv1_L05_Props", b, "Lv1")

    b = lego.B()                                            # r4: everything the Lv3 smokehouse replaces (dropped at Lv3)
    lv1_rack(b)
    lv1_mast(b)
    lv1_canopy(b)
    out("Lv1_L06_Rack", b, "Lv1")

    b = lego.B()
    lv1_floor(b)
    lv1_border(b)
    out("Lv1_L07_Floor", b, "Lv1")

    c = lego.B()
    lv1_col(c)
    out_cols("Lv1", c)
    c = lego.B()
    lv1_rack_col(c)
    for k in range(len(c.f) // 6):                          # Lv1_RackColNN_COL: DockPieces drops them with the rack at Lv3
        box = lego.B()
        box.v = c.v[8 * k:8 * k + 8]
        box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
        out("Lv1_RackCol%02d_COL" % (k + 1), box, "Lv1")

    def stalls(fn, *extra):
        b = lego.B()
        for cx, mirror, k in ((CS_X, False, 1), (-CS_X, True, 0)):
            local = lego.B()
            fn(local, *([k] if extra else []))
            place_m(b, local, cx, CS_Y, mirror)
        return b

    out("Lv2_L02_Counters", stalls(stall_counter), "Lv2")
    out("Lv2_L03_Frames", stalls(stall_frames), "Lv2")
    out("Lv2_L04_Awnings", stalls(stall_awnings, True), "Lv2")
    out("Lv2_L05_Stock", stalls(stall_stock), "Lv2")

    b = lego.B()
    lv2_gate(b)
    out("Lv2_L06_Gate", b, "Lv2")

    c = lego.B()
    stall_col(c, CS_X, False)
    stall_col(c, -CS_X, True)
    lv2_gate_col(c)
    out_cols("Lv2", c)

    b = lego.B()                                            # Lv3: built at x -3..6 on the plaza, then slid + lifted
    smokehouse_plinth(b)
    sh_xf(b)
    smokehouse_yard_rack(b)                                 # r4: out front on the plaza, world frame, not scaled
    out("Lv3_L01_Base", b, "Lv3")

    b = lego.B()
    smokehouse_walls(b)
    smokehouse_front(b)
    smokehouse_doors(b)
    out("Lv3_L02_Walls", sh_xf(b), "Lv3")

    b = lego.B()
    smokehouse_roof(b)
    smokehouse_roof_studs(b)
    out("Lv3_L03_Roof", sh_xf(b), "Lv3")

    b = lego.B()
    smokehouse_racks(b)
    out("Lv3_L04_Racks", sh_xf(b), "Lv3")

    b = lego.B()
    smokehouse_fish(b)
    out("Lv3_L05_Fish", sh_xf(b), "Lv3")

    b = lego.B()
    smokehouse_chimney(b)
    out("Lv3_L06_Chimney", sh_xf(b), "Lv3")

    c = lego.B()
    smokehouse_col(c)
    sh_xf(c)
    x0, x1, y = RACK3
    c.box((x0, y - 0.5, FLOOR), (x1, y + 0.5, 5.45), P.WHITE)
    for x, y in SH_BARRELS:
        c.box((x - 0.85, y - 0.85, FLOOR), (x + 0.85, y + 0.85, FLOOR + 2.1), P.WHITE)
    out_cols("Lv3", c)

    atts = []
    for name, loc in (("ATT_Work_Stall3", (CS_X, CS_Y + 2.3, PAD)),     # the white tile behind each counter
                      ("ATT_Work_Stall4", (-CS_X, CS_Y + 2.3, PAD)),
                      ("ATT_Work_RackLeft", sh_pt(-1.2, 11.5, PAD)),
                      ("ATT_Work_RackRight", sh_pt(4.2, 11.5, PAD)),
                      ("ATT_Sign_01", NAME_SIGN)):                # the code name sign's centre (DockPieces fishMarket)
        atts.append(lego.attach(name, loc))

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[fishmarket] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[fishmarket] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, sitting on the code market's plinth (z 0.92) inside its 40 x 34 stud lot; the "
                     "bbox is the two flank stall pads and the back-centre smokehouse, not the whole lot; front -Y, "
                     "origin the market ground centre, built at the market's final 1.15 scale (place with no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "LOD1 triangles": "LOD1 keeps the add-ons' 50% share (patch_lod_targets): r3's Lv1 plaza tiles, 1x2 wall caps and "
                              "booth boards put LOD0 at ~32k (hero 40k), so the half share lands just over the 15k ceiling",
            "LOD2 triangles": "LOD2 keeps the add-ons' 25% share (patch_lod_targets): the 3000 hero ceiling would "
                              "collapse the small Lego detail meshes",
            "texture sets": "Lego rule docs/05 5: one flat palette set (like M_Bld_HQAddons / M_Bld_Depot), no PBR scans",
            "naming": "gameplay node/layer names (docs/25 B/J): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., Lv3_Col01_COL..; the FBX "
                      "importer flattens empty parents, so the node name is the mesh name prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "stalls", "target": [0.0, 2.0, 4.5], "dist": 55, "az": 15, "el": 12},
            {"name": "stall_detail", "target": [14.0, 3.0, 4.0], "dist": 15, "az": 325, "el": 10},
            {"name": "smokehouse", "target": [1.5, 11.5, 5.5], "dist": 23, "az": 15, "el": 10},
            {"name": "chimney", "target": [1.5, 14.5, 10.5], "dist": 19, "az": 35, "el": 20},
            {"name": "interior", "target": [1.5, 11.5, 4.0], "dist": 14, "az": 0, "el": 2},
        ],
    }
