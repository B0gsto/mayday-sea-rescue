"""M_Bld_LookoutAddons: the Lookout Tower's level add-ons, Lego style (docs/25 B and J; docs/05 2.2, 3, 4, 5).

The Lv1 tower stays the code-built `lookout()` in src/shared/DockPieces.luau. This asset adds only what the two levels
add, at the tower's final frame: 24 x 24 stud lot, ground at z 0, plinth top 0.9 (the code plinth is 0.6 studs at 1x,
scaled 1.5), front -Y (Roblox -Z), origin the tower's ground centre. Place at the tower frame with no extra scale.

Lv2 (engine: call pins from farther -> golden calls x1.5): a walk-on viewing gallery round the code cabin deck (the
existing truss ladder lands at its open back), with a railing of solid white Lego fence panels on red studded caps, a
brass telescope on a tripod at the front-left and a gold bell under a red gallows at the front-right (golden calls).
On the roof, a lantern room on the front half of the ridge, clear of the code flag mast: a square stud plate saddled
on the gable, a straight white drum, open panes round a round warm lens, a solid red cap with one white band, gold finial.

Lv3 (golden calls x2): a searchlight pedestal on the roof with a red yoke and a big white drum (its own mesh,
Lv3_L04_Searchlight, so the game can turn it; long barrel, domed pale warm lens, no glow), and a radar dish (deep bowl, thick red rim, feed horn) on a thick red mast and stud-plate block on
the opposite roof slope. The Lv2 gallery is the lower viewing deck, reached by the existing ladder; no other stair
exists, so Lv3 adds roof gear only.

Each level is a top-level node (Lv2, Lv3) holding four construction layers (L01_* bottom to L04_* top), one palette
mesh per layer (flat colours via UVs, one draw call per layer). Collision is one simple box per object,
<Node>_ColNN_COL: the gallery deck, the railing runs, the lantern room, the telescope and bell, the searchlight and
its yoke, the radar. Roblox hulls each mesh, so the boxes stay separate and the ladder entry, the deck walkway and the
cabin stay open.

    python3 art/source/buildings/M_Bld_LookoutAddons/maketex.py \
        --out build/prod/M_Bld_LookoutAddons/textures/M_Bld_LookoutAddons --name LookoutAddons --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_LookoutAddons/build.py --out-root build/prod/M_Bld_LookoutAddons \
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

NAME = "M_Bld_LookoutAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "LookoutAddons", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_LookoutAddons_Brick_ALB.png")

# the code tower in its final 1.5x frame (lookout() in DockPieces.luau: 24 x 24 lot, ground z 0)
DECK = 31.2                     # platform top (code 20.4 x 1.5)
GAL, PLAT = 10.8, 8.25          # gallery outer edge / code platform edge
CAB = 7.2                       # cabin wall plane
RAIL_Z0 = 31.32                 # our deck plate top (0.12 over the code platform)
RAIL_TOP = 35.15
EAVE, RIDGE = 37.8, 43.8
LANT = (0.0, -4.7)              # lantern room centre (front half of the ridge, clear of the flag mast at y 0)
BASE, BASE_Z0, PLATE_TOP = 4.3, 40.0, 45.3    # square saddle block bedded in the gable, stud plate on top
DRUM_R, DRUM_TOP = 4.0, 47.1                  # straight-sided drum standing on the plate
ROOF_TOP = 54.4                 # lantern cap apex
TEL = (-8.9, -9.2)              # front-left gallery corner (sea side)
BELL = (8.9, -9.7)              # front-right gallery corner
SL = (6.6, 5.2)                 # Lv3 searchlight (back-right roof slope, clear of the lantern's silhouette)
SL_DRUM_Z, SL_R = 44.0, 1.75
RADAR = (-8.0, -7.7)            # Lv3 radar mast (front-left roof corner, so the dish clears the lantern in the 3/4 view)
RADAR_Z = 47.0


def patch_lod_names():
    """Layer meshes use game node names (Lv2_L01_..., Lv3_L01_...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ geometry helpers
def cyl_y(b, y0, y1, r, c, n=12, cx=0.0, cz=0.0):
    """A closed cylinder along Y (lantern panes, searchlight drum, telescope tube)."""
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def frustum_z(b, cx, cy, z0, z1, r0, r1, c, n=12):
    """A closed vertical frustum (the bell body)."""
    ring = lambda r: [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y, z0) for x, y in ring(r0)]
    d = [(x, y, z1) for x, y in ring(r1)]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def frustum_y(b, y0, y1, r0, r1, c, n=12):
    """A closed frustum along Y (the radar dish bowl, rim at y0, throat at y1)."""
    ring = lambda r: [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring(r0)]
    d = [(x, y1, z) for x, z in ring(r1)]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def ring_y(b, y0, y1, r_out, r_in, c, n=14):
    """A closed flat washer along Y (a rim with an open centre, so it does not cap the dish)."""
    def circle(r):
        return [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]

    verts = []
    for y in (y0, y1):
        for r in (r_out, r_in):
            verts += [(x, y, z) for x, z in circle(r)]
    of, inn, ob, ib = 0, n, 2 * n, 3 * n
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((of + i, of + j, ob + j, ob + i))
        faces.append((inn + i, ib + i, ib + j, inn + j))
        faces.append((of + i, inn + i, inn + j, of + j))
        faces.append((ob + i, ob + j, ib + j, ib + i))
    b._emit(verts, faces, c)


def tent(b, cx, cy, hx, hy, z0, z1, cols):
    """A rectangular pyramid with each face split into two stripes (the lantern cap)."""
    corners = [(cx - hx, cy - hy), (cx + hx, cy - hy), (cx + hx, cy + hy), (cx - hx, cy + hy)]
    ring = []
    for i in range(4):
        (x0, y0), (x1, y1) = corners[i], corners[(i + 1) % 4]
        ring += [corners[i], ((x0 + x1) / 2, (y0 + y1) / 2)]
    verts = [(x, y, z0) for x, y in ring] + [(cx, cy, z1)]
    base = len(b.v)
    b.v.extend(verts)
    for i in range(8):
        b.f.append(((base + i, base + (i + 1) % 8, base + 8), cols[i % 2]))
    b.f.append((tuple(base + i for i in reversed(range(8))), P.WHITE))


def place_xf(dst, src, M):
    from mathutils import Vector
    base = len(dst.v)
    dst.v.extend(tuple(M @ Vector(p)) for p in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


# ------------------------------------------------------------------ Lv2: viewing gallery
def gallery_deck(b):
    z0, z1 = 30.72, RAIL_Z0
    b.box((-GAL, -GAL, z0), (GAL, -PLAT, z1), P.TAN, bevel=0.08)                  # front band
    b.box((-GAL, -PLAT, z0), (-PLAT, PLAT, z1), P.TAN, bevel=0.08)                # left band
    b.box((PLAT, -PLAT, z0), (GAL, PLAT, z1), P.TAN, bevel=0.08)                  # right band
    rim = 0.55
    for lo, hi in (((-GAL, -GAL), (GAL, -GAL + rim)), ((-GAL, -GAL + rim), (-GAL + rim, PLAT)),
                   ((GAL - rim, -GAL + rim), (GAL, PLAT))):
        b.box((lo[0], lo[1], RAIL_Z0), (hi[0], hi[1], RAIL_Z0 + 0.5), P.RED, bevel=0.04)
    for s in (-1, 1):                                                              # back return rims, entry stays open
        b.box((s * PLAT, PLAT - rim, RAIL_Z0), (s * GAL, PLAT, RAIL_Z0 + 0.5), P.RED, bevel=0.04)
    b.stud_row(-GAL + 0.65, -GAL + rim / 2, GAL - 0.65, -GAL + rim / 2, RAIL_Z0 + 0.5, P.RED, 1.7, 0.28, 0.22)
    for s in (-1, 1):
        b.stud_row(s * (GAL - rim / 2), -GAL + 0.65, s * (GAL - rim / 2), PLAT - 0.35, RAIL_Z0 + 0.5, P.RED, 1.7, 0.28, 0.22)
        b.stud_row(s * (PLAT + 0.35), PLAT - rim / 2, s * (GAL - 0.35), PLAT - rim / 2, RAIL_Z0 + 0.5, P.RED, 1.7, 0.28, 0.22)
    for x in (-8.0, 0.0, 8.0):                                                     # knee braces under the overhang
        b.beam((x, -GAL + 0.35, 30.9), (x, -PLAT - 0.05, 30.1), 0.5, 0.6, P.RED)
    for y in (-5.0, 3.0):
        for s in (-1, 1):
            b.beam((s * (GAL - 0.35), y, 30.9), (s * (PLAT + 0.05), y, 30.1), 0.5, 0.6, P.RED)


FRONT_POSTS = (-10.45, -6.35, -2.15, 2.15, 6.35, 10.45)
SIDE_POSTS = (-10.45, -5.9, -1.35, 3.2, 8.25)


def railing(b):
    for x in FRONT_POSTS:
        post(b, x, -10.45)
    for s in (-1, 1):
        for y in SIDE_POSTS[1:]:
            post(b, s * 10.45, y)
        post(b, s * PLAT, PLAT)
        b.box((s * (PLAT + 0.35), PLAT - 0.155, 31.55), (s * 10.03, PLAT + 0.155, 34.6), P.WHITE, bevel=0.03)  # return panel
        b.box((s * (PLAT - 0.05), PLAT - 0.36, 34.6), (s * (10.83), PLAT + 0.36, 35.15), P.RED, bevel=0.04)   # return cap
        b.stud_row(s * (PLAT + 0.4), PLAT, s * 10.35, PLAT, 35.15, P.RED, 1.6, 0.3, 0.22)
    for xa, xb in zip(FRONT_POSTS, FRONT_POSTS[1:]):
        b.box((xa + 0.4, -10.61, 31.55), (xb - 0.4, -10.29, 34.6), P.WHITE, bevel=0.03)
    for ya, yb in zip(SIDE_POSTS, SIDE_POSTS[1:]):
        for s in (-1, 1):
            b.box((s * 10.45 - 0.16, ya + 0.4, 31.55), (s * 10.45 + 0.16, yb - 0.4, 34.6), P.WHITE, bevel=0.03)
    b.box((-GAL + 0.05, -10.83, 34.6), (GAL - 0.05, -10.07, 35.15), P.RED, bevel=0.04)
    for s in (-1, 1):
        b.box((s * 10.45 - 0.38, -10.83, 34.6), (s * 10.45 + 0.38, PLAT, 35.15), P.RED, bevel=0.04)
    b.stud_row(-GAL + 0.55, -10.45, GAL - 0.55, -10.45, 35.15, P.RED, 2.0, 0.3, 0.22)
    for s in (-1, 1):
        b.stud_row(s * 10.45, -GAL + 0.55, s * 10.45, PLAT - 0.35, 35.15, P.RED, 2.0, 0.3, 0.22)


def post(b, x, y):
    b.box((x - 0.42, y - 0.42, RAIL_Z0), (x + 0.42, y + 0.42, RAIL_TOP), P.RED, bevel=0.05)
    b.cyl(x, y, RAIL_TOP, RAIL_TOP + 0.22, 0.33, P.WHITE, 6)


# ------------------------------------------------------------------ Lv2: roof lantern room
def lantern(b):
    from mathutils import Matrix
    cx, cy = LANT
    b.box((cx - BASE, cy - BASE, BASE_Z0), (cx + BASE, cy + BASE, PLATE_TOP - 0.4), P.LBG, bevel=0.06)  # saddle in the gable
    b.box((cx - 4.4, cy - 4.4, PLATE_TOP - 0.4), (cx + 4.4, cy + 4.4, PLATE_TOP), P.LBG, bevel=0.05)  # square stud plate
    for sx, sy in ((3.75, 3.75), (3.75, 2.4), (2.4, 3.75)):
        for mx in (-1, 1):
            for my in (-1, 1):
                b.cyl(cx + mx * sx, cy + my * sy, PLATE_TOP, PLATE_TOP + 0.4, 0.38, P.LBG, 8)
    b.cyl(cx, cy, PLATE_TOP, DRUM_TOP, DRUM_R, P.WHITE, 16)                         # straight-sided drum
    b.cyl(cx, cy, DRUM_TOP - 1.1, DRUM_TOP - 0.5, DRUM_R + 0.1, P.RED, 16)          # red band round the drum
    for a in (0, 90, 180, 270):
        b.cyl(cx + 3.6 * math.cos(math.radians(a)), cy + 3.6 * math.sin(math.radians(a)), DRUM_TOP, DRUM_TOP + 0.45, 0.38, P.WHITE, 8)
    b.box((-3.5, cy - 2.9, DRUM_TOP), (3.5, cy + 2.9, DRUM_TOP + 0.4), P.RED, bevel=0.05)  # room floor plate
    z0 = DRUM_TOP + 0.4
    zg = z0 + 3.4
    zc, r = z0 + 1.8, 1.5                                                          # round warm lens, seen through every pane
    b.cyl(cx, cy, z0, zc - 1.3, 0.7, P.DBG, 10)                                    # lens pedestal
    lens = lego.B()
    lathe_y(lens, [(r * math.sin(math.pi * k / 6), -r * math.cos(math.pi * k / 6)) for k in range(7)], [P.WARM] * 6, 12)
    place_xf(b, lens, Matrix.Translation((cx, cy, zc)) @ Matrix.Rotation(math.radians(90), 4, "X"))
    b.cyl(cx, cy, zc - 0.12, zc + 0.12, r + 0.06, P.YELLOW, 12)                    # brass ring round the lens
    for x in (-3.1, 3.1):                                                          # white corner posts
        for y in (cy - 2.5, cy + 2.5):
            b.box((x - 0.35, y - 0.35, z0), (x + 0.35, y + 0.35, zg), P.WHITE, bevel=0.04)
    for s in (-1, 1):                                                              # low sills + thin glazing bars, panes open
        b.box((-2.75, cy + s * 2.5 - 0.15, z0), (2.75, cy + s * 2.5 + 0.15, z0 + 0.45), P.WHITE)
        b.box((s * 3.1 - 0.15, cy - 2.15, z0), (s * 3.1 + 0.15, cy + 2.15, z0 + 0.45), P.WHITE)
        for t in (-1, 1):
            b.box((t * 1.0 - 0.11, cy + s * 2.5 - 0.11, z0 + 0.45), (t * 1.0 + 0.11, cy + s * 2.5 + 0.11, zg), P.WHITE)
            b.box((s * 3.1 - 0.11, cy + t * 0.75 - 0.11, z0 + 0.45), (s * 3.1 + 0.11, cy + t * 0.75 + 0.11, zg), P.WHITE)
    b.box((-3.85, cy - 3.1, zg), (3.85, cy + 3.1, zg + 0.6), P.WHITE, bevel=0.06)    # cornice: the one white trim band
    tent(b, cx, cy, 3.9, 3.2, zg + 0.6, ROOF_TOP, (P.RED, P.RED))                   # solid red cap
    b.cyl(cx, cy, ROOF_TOP, ROOF_TOP + 0.9, 0.45, P.YELLOW, 8)


# ------------------------------------------------------------------ Lv2: telescope + bell
def telescope(b):
    from mathutils import Matrix
    cx, cy = TEL
    head = RAIL_Z0 + 3.7
    for a in (90, 210, 330):
        b.beam((cx + 1.45 * math.cos(math.radians(a)), cy + 1.45 * math.sin(math.radians(a)), RAIL_Z0),
               (cx, cy, head), 0.4, 0.4, P.BROWN)
    b.box((cx - 0.85, cy - 0.85, head - 0.3), (cx + 0.85, cy + 0.85, head + 0.7), P.YELLOW, bevel=0.15)
    t = lego.B()
    cyl_y(t, -2.4, 2.4, 0.75, P.YELLOW, 12)                   # brass tube
    cyl_y(t, -1.5, -1.1, 0.9, P.WHITE, 12)                    # bands
    cyl_y(t, 1.1, 1.5, 0.9, P.WHITE, 12)
    cyl_y(t, -2.75, -2.4, 0.95, P.YELLOW, 12)                 # front hood, brass
    cyl_y(t, -2.85, -2.7, 0.7, P.INK, 12)                     # dark lens
    cyl_y(t, 2.4, 2.9, 0.45, P.YELLOW, 10)                    # eyepiece, brass
    cyl_y(t, 2.9, 3.0, 0.34, P.INK, 10)
    M = Matrix.Translation((cx, cy, head + 1.7)) @ Matrix.Rotation(math.radians(-12), 4, "X")
    place_xf(b, t, M)


def bell(b):
    cx, cy = BELL
    for x in (cx - 1.6, cx + 1.6):
        b.box((x - 0.35, cy - 0.35, RAIL_Z0), (x + 0.35, cy + 0.35, 37.85), P.RED, bevel=0.06)
    b.box((cx - 2.05, cy - 0.42, 37.75), (cx + 2.05, cy + 0.42, 38.4), P.RED, bevel=0.07)
    b.box((cx - 0.2, cy - 0.2, 37.0), (cx + 0.2, cy + 0.2, 37.8), P.YELLOW)
    frustum_z(b, cx, cy, 34.7, 35.15, 1.3, 1.2, P.YELLOW, 12)
    frustum_z(b, cx, cy, 35.15, 36.1, 1.2, 0.85, P.YELLOW, 12)
    frustum_z(b, cx, cy, 36.1, 36.7, 0.85, 0.5, P.YELLOW, 12)
    frustum_z(b, cx, cy, 36.7, 37.05, 0.5, 0.35, P.YELLOW, 8)
    b.cyl(cx, cy, 34.25, 34.8, 0.28, P.DBG, 6)                # clapper


# ------------------------------------------------------------------ Lv3: searchlight + radar
def lathe_y(b, prof, cols, n=16):
    """A solid of revolution round Y: prof is (r, y) points from axis to axis, cols one colour per segment."""
    idx, base = [], len(b.v)
    for r, y in prof:
        if r == 0:
            idx.append([base]); b.v.append((0.0, y, 0.0)); base += 1
        else:
            idx.append(list(range(base, base + n)))
            b.v.extend((r * math.cos(2 * math.pi * k / n), y, r * math.sin(2 * math.pi * k / n)) for k in range(n))
            base += n
    for i, c in enumerate(cols):
        a, d = idx[i], idx[i + 1]
        for k in range(n):
            k1 = (k + 1) % n
            if len(a) == 1:
                b.f.append(((a[0], d[k1], d[k]), c))
            elif len(d) == 1:
                b.f.append(((a[k], a[k1], d[0]), c))
            else:
                b.f.append(((a[k], a[k1], d[k1], d[k]), c))


def searchlight_base(b):
    x, y = SL
    b.box((x - 1.9, y - 1.9, 36.8), (x + 1.9, y + 1.9, 40.6), P.WHITE, bevel=0.08)  # block bedded into the slope
    b.box((x - 1.95, y - 1.95, 38.2), (x + 1.95, y + 1.95, 38.55), P.RED, bevel=0.03)  # red band
    b.box((x - 2.6, y - 2.6, 40.6), (x + 2.6, y + 2.6, 41.0), P.LBG, bevel=0.05)    # flush flat baseplate
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(x + sx * 2.0, y + sy * 2.0, 41.0, 41.4, 0.4, P.LBG, 8)           # corner studs
    b.cyl(x, y, 41.0, 41.7, 1.9, P.RED, 16)                                        # round turntable


def yoke(b):
    x, y = SL
    b.box((x - 2.8, y - 0.9, 41.7), (x + 2.8, y + 0.9, 42.2), P.RED, bevel=0.05)    # U-fork bottom bar
    for s in (-1, 1):
        b.box((x + s * 2.6 - 0.35, y - 0.7, 42.2), (x + s * 2.6 + 0.35, y + 0.7, SL_DRUM_Z), P.RED, bevel=0.05)  # arms
        b.cyl_x(x + s * 2.6, y, SL_DRUM_Z, 0.95, 0.7, P.RED, 12)                    # rounded arm tops


def searchlight_drum(b):
    from mathutils import Matrix
    d = lego.B()
    cyl_y(d, -2.8, 1.7, SL_R, P.WHITE, 14)                                         # long barrel
    cyl_y(d, -0.55, 0.55, SL_R + 0.1, P.RED, 14)                                   # red band
    cyl_y(d, -3.0, -2.8, SL_R + 0.1, P.RED, 14)                                    # front rim
    lathe_y(d, [(0, -3.4), (0.8, -3.3), (1.4, -3.12), (1.65, -2.95)], [P.WARM] * 3, 14)  # domed pale warm glass lens
    cyl_y(d, 1.7, 2.0, 1.45, P.LBG, 14)                                            # back cap
    cyl_y(d, 2.0, 2.18, 0.42, P.RED, 8)                                            # tail knob
    for s in (-1, 1):
        d.cyl_x(s * 2.1, 0.0, 0.0, 0.6, 0.45, P.YELLOW, 10)                         # hubs into the yoke
    place_xf(b, d, Matrix.Translation((SL[0], SL[1], SL_DRUM_Z)) @ Matrix.Rotation(math.radians(-12), 4, "X"))


def radar(b):
    from mathutils import Matrix
    x, y = RADAR
    b.box((x - 1.5, y - 1.5, 37.6), (x + 1.5, y + 1.5, 40.6), P.WHITE, bevel=0.08)  # block bedded in the eave corner
    b.box((x - 1.55, y - 1.55, 38.9), (x + 1.55, y + 1.55, 39.25), P.RED, bevel=0.03)  # red band
    b.box((x - 1.95, y - 1.95, 40.6), (x + 1.95, y + 1.95, 41.0), P.LBG, bevel=0.05)   # flush flat baseplate
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(x + sx * 1.45, y + sy * 1.45, 41.0, 41.4, 0.38, P.LBG, 8)           # corner studs
    b.cyl(x, y, 41.0, 41.6, 1.25, P.RED, 16)                                         # round turntable
    b.cyl(x, y, 41.6, RADAR_Z, 0.75, P.RED, 12)                                      # thick red mast
    b.cyl(x, y, RADAR_Z - 1.2, RADAR_Z - 0.8, 0.95, P.WHITE, 12)                     # white collar
    d = lego.B()
    R, D, steps = 2.8, 1.5, 5                                                        # bowl radius, depth
    inner = [(R * k / steps, -D * (k / steps) ** 2) for k in range(steps + 1)]
    back = [(R, -D + 0.2), (R * 0.6, 0.05), (0.7, 0.75), (0.0, 0.75)]              # grey back cone to the hub
    lathe_y(d, inner + back, [P.WHITE] * steps + [P.RED] + [P.LBG] * 3, 16)
    ring_y(d, -D - 0.3, -D + 0.25, R + 0.3, R - 0.3, P.RED, 16)                      # thick red rim
    cyl_y(d, -2.9, 0.0, 0.18, P.DBG, 6)                                              # feed-horn stick
    frustum_y(d, -3.5, -2.9, 0.6, 0.22, P.YELLOW, 8)                                 # feed horn
    d.cyl_x(0.0, 0.85, 0.0, 0.6, 1.7, P.YELLOW, 12)                                  # brass tilt hub on the mast top
    # back cone tip on the hub; the bowl faces out over the front-left corner (seen in profile), tilted up 35 degrees
    place_xf(b, d, Matrix.Translation((x, y, RADAR_Z)) @ Matrix.Rotation(math.radians(-45), 4, "Z")
             @ Matrix.Rotation(math.radians(-35), 4, "X") @ Matrix.Translation((0.0, -0.85, 0.0)))


# ------------------------------------------------------------------ collision
def gallery_col(c):
    z0, z1 = 30.72, RAIL_Z0
    c.box((-GAL, -GAL, z0), (GAL, -PLAT, z1), P.WHITE)
    c.box((-GAL, -PLAT, z0), (-PLAT, PLAT, z1), P.WHITE)
    c.box((PLAT, -PLAT, z0), (GAL, PLAT, z1), P.WHITE)
    c.box((-10.83, -10.83, z1), (10.83, -10.07, RAIL_TOP), P.WHITE)                # front railing
    for s in (-1, 1):
        c.box((s * 10.45 - 0.38, -10.83, z1), (s * 10.45 + 0.38, PLAT, RAIL_TOP), P.WHITE)
        c.box((s * PLAT, PLAT - 0.36, z1), (s * GAL, PLAT + 0.36, RAIL_TOP), P.WHITE)
    c.box((TEL[0] - 1.6, TEL[1] - 1.6, z1), (TEL[0] + 1.6, TEL[1] + 1.6, 37.3), P.WHITE)
    c.box((BELL[0] - 2.1, BELL[1] - 0.7, z1), (min(BELL[0] + 2.1, GAL), BELL[1] + 0.7, 38.4), P.WHITE)


def lantern_col(c):
    cx, cy = LANT
    c.box((cx - 4.4, cy - 4.4, BASE_Z0), (cx + 4.4, cy + 4.4, PLATE_TOP), P.WHITE)
    c.box((-DRUM_R, cy - DRUM_R, PLATE_TOP), (DRUM_R, cy + DRUM_R, ROOF_TOP + 0.9), P.WHITE)


def lv3_col(c):
    x, y = SL
    c.box((x - 2.6, y - 2.6, 36.8), (x + 2.6, y + 2.6, 41.0), P.WHITE)
    c.box((x - 3.0, y - 3.4, 41.0), (x + 3.0, y + 2.5, SL_DRUM_Z + 2.0), P.WHITE)
    x, y = RADAR
    c.box((x - 1.95, y - 1.95, 37.6), (x + 1.95, y + 1.95, 41.6), P.WHITE)          # block, plate, turntable
    c.box((x - 4.2, y - 4.2, RADAR_Z - 1.4), (x + 1.4, y + 1.4, RADAR_Z + 4.1), P.WHITE)  # dish
    c.box((x - 0.85, y - 0.85, 41.6), (x + 0.85, y + 0.85, RADAR_Z - 1.4), P.WHITE)  # mast


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_LookoutAddons_Brick", ALB)
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
        print("[lookout] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills the deck
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    gallery_deck(b)
    out("Lv2_L01_Gallery", b, "Lv2")

    b = lego.B()
    railing(b)
    out("Lv2_L02_Railing", b, "Lv2")

    b = lego.B()
    lantern(b)
    out("Lv2_L03_Lantern", b, "Lv2")

    b = lego.B()
    telescope(b)
    bell(b)
    out("Lv2_L04_Deck", b, "Lv2")

    c = lego.B()
    gallery_col(c)
    lantern_col(c)
    out_cols("Lv2", c)

    b = lego.B()
    searchlight_base(b)
    out("Lv3_L01_SearchlightBase", b, "Lv3")

    b = lego.B()
    yoke(b)
    out("Lv3_L02_Yoke", b, "Lv3")

    b = lego.B()
    radar(b)
    out("Lv3_L03_Radar", b, "Lv3")

    b = lego.B()
    searchlight_drum(b)
    out("Lv3_L04_Searchlight", b, "Lv3")

    c = lego.B()
    lv3_col(c)
    out_cols("Lv3", c)

    atts = [
        lego.attach("ATT_Watch_Lamp", (-5.6, -9.2, RAIL_Z0)),
        lego.attach("ATT_Watch_Spotlight", (5.6, -9.2, RAIL_Z0)),
        lego.attach("ATT_SearchlightPivot", (SL[0], SL[1], SL_DRUM_Z)),
    ]

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[lookout] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[lookout] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, on and round the code tower's cabin deck (z 31.2) and roof (z 37.8..43.8) inside "
                     "its 24 x 24 stud lot; the bbox is the viewing gallery and the roof gear, not the whole tower; "
                     "front -Y, origin the tower ground centre, built at the tower's final 1.5 scale (no extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 B/J): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., Lv3_Col01_COL..; "
                      "the FBX importer flattens empty parents, so the node name is the mesh name prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "lantern", "target": [0.0, -4.7, 50.0], "dist": 18, "az": 25, "el": 14},
            {"name": "deck", "target": [0.0, -9.0, 35.0], "dist": 16, "az": 20, "el": 12},
            {"name": "searchlight", "target": [6.6, 5.2, 43.5], "dist": 14, "az": 50, "el": 14},
            {"name": "radar", "target": [-8.5, -8.5, 46.0], "dist": 22, "az": 330, "el": 14},
        ],
    }
