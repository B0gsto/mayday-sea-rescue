"""M_Bld_TrophyHallAddons: the Trophy Hall's level add-ons, Lego style (docs/25 B; docs/05 2.2, 3, 4, 5).

The Lv1 hall stays the code-built `trophyHall()` in src/shared/DockPieces.luau: a 21-wide trophy wall on the
50 x 28 stud landmark lot at DockConfig.Buildings.TrophyHall.spot (x 0, y -122, front -Z), ground z 0, origin the
lot's ground centre. The wall has white columns, a yellow frame and a small gold ball (z 10.6, top 13.1); the
add-ons wrap it, never reshape it.

Lv2 Dome: a rotunda over the wall. Eight navy columns on sand bases carry a navy drum with a sand cornice, a ring
of eight sand-framed portholes and a navy dome with a sand equator band and eight sand ribs that run into a
sand stud-ring cap with a gold finial (top 22.7), swallowing the code gold ball. Two side wings of open display plinths: four per wing against the lot edge, each a
studded navy pedestal with a sand cap and red plaque; ATT_Plinth_01..08 sit on the studded tops. Two red banners
with gold anchors hang on the front columns.

Lv3 GoldDome: a larger saturated-gold shell (apex 22.1) covers the Lv2 dome, with a red base ring, eight deep-gold
ribs, a glazed gold lantern (top 26.4) and a gold spire with a red flag (pole top 31.15). A grand front portico: three
sand steps and a red runner, four sand columns with navy bases and gold collars, a navy architrave, and a sand-framed
navy pediment with a gold anchor crest on a medallion. A covered front gallery (two canopies on six columns) adds
six more studded plinths, ATT_Plinth_09..14, along the walk-in approach.

Each level is a top-level node (Lv2, Lv3) holding construction layers (L01_* bottom up), one palette mesh per layer
(flat colours via UVs, one draw call per layer). Collision is separate simple boxes, <Node>_ColNN_COL. The 6-stud
entrance lane, the portico lane and the ring around the rotunda stay open.

    python3 art/source/buildings/M_Bld_TrophyHallAddons/maketex.py \
        --out build/prod/M_Bld_TrophyHallAddons/textures/M_Bld_TrophyHallAddons --name TrophyHall --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py \
        --build art/source/buildings/M_Bld_TrophyHallAddons/build.py \
        --out-root build/prod/M_Bld_TrophyHallAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_TrophyHallAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "TrophyHall", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_TrophyHall_Brick_ALB.png")

BASE, WING, GAL, STYLO = 0.30, 0.55, 0.66, 0.90       # pad tops: rotunda floor, wing, Lv3 gallery, portico
RCX, RCY = 0.0, 1.5                                   # rotunda centre (y: the lot's middle, wall at y 0)
PAD_R, DRUM_R, COL_R = 12.2, 11.6, 10.85
DRUM_Z0, DRUM_Z1 = 10.75, 13.35                       # above the code lintel (10.5), swallowing the code ball (13.1)
DOME_TOP, GOLD_TOP = 21.4, 22.1
WING_X0, WING_X1, WING_Y0, WING_Y1 = 11.8, 24.5, -10.4, 13.5
PL_X, PL_Y = 22.2, (-5.4, 0.0, 5.4, 10.8)             # Lv2 plinth row (outer edge), four per wing
GAL_X0, GAL_X1, GAL_Y0, GAL_Y1 = 11.8, 24.5, -13.9, -8.0
GAL_PL_X, GAL_PL_Y = (14.1, 18.2, 22.3), -11.75        # Lv3 gallery plinth row, three per wing
GAL_COL_X, GAL_COL_Y = (12.4, 18.3, 24.0), -8.9
CANOPY_Z0, CANOPY_Z1 = 8.95, 10.55
PORT_X, PORT_COL_X, PORT_COL_Y = 9.4, (-6.4, 6.4, -9.6, 9.6), -12.2
ARCH_Z0, ARCH_Z1 = 10.30, 11.40
PED_APEX = 15.15
COL_ANGLES = tuple(22.5 + 45.0 * k for k in range(8))  # no column dead centre front (270 = the entrance)


def patch_lod_names():
    """Layer meshes use game node names (Lv2_L01_..., Lv3_L01_...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ small helpers
def stud(b, x, y, z, c, r=0.42, h=0.30, n=6):
    b.cyl(x, y, z, z + h, r, c, n, bottom=False)


def studs_grid(b, x0, x1, y0, y1, z, c, step=3.4, r=0.42, skip=None):
    nx = max(1, int(round((x1 - x0) / step)))
    ny = max(1, int(round((y1 - y0) / step)))
    for ix in range(nx):
        for iy in range(ny):
            x = x0 + (ix + 0.5) * (x1 - x0) / nx
            y = y0 + (iy + 0.5) * (y1 - y0) / ny
            if skip and skip(x, y):
                continue
            stud(b, x, y, z, c, r=r)


def disc_studs(b, cx, cy, r, z, c, step=3.4, skip=None):
    k = int(r // step)
    for ix in range(-k, k + 1):
        for iy in range(-k, k + 1):
            x, y = cx + ix * step, cy + iy * step
            if (x - cx) ** 2 + (y - cy) ** 2 > (r - 0.55) ** 2:
                continue
            if skip and skip(x, y):
                continue
            stud(b, x, y, z, c)


def seam(b, x0, y0, x1, y1, z, w=0.09, c=P.DSAND):
    b.box((min(x0, x1) - w / 2, min(y0, y1) - w / 2, z), (max(x0, x1) + w / 2, max(y0, y1) + w / 2, z + 0.035),
          c, bevel=0.0, bottom=False)


def place_rot(dst, src, cx, cy, z, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    base = len(dst.v)
    dst.v.extend((cx + x * ca - y * sa, cy + x * sa + y * ca, z + zz) for x, y, zz in src.v)
    dst.f.extend((tuple(base + i for i in f), c) for f, c in src.f)


def rot_box(b, cx, cy, z0, ang, w, d, h, c, bevel=0.02):
    t = lego.B()
    t.box((-w / 2, -d / 2, 0.0), (w / 2, d / 2, h), c, bevel=bevel)
    place_rot(b, t, cx, cy, z0, ang)


def prism_y(b, y0, y1, profile, c):
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def ring_at(rad, ang):
    a = math.radians(ang)
    return RCX + rad * math.cos(a), RCY + rad * math.sin(a)


# ------------------------------------------------------------------ shared kit
def pedestal(b, x, y, z0, top, hw=2.2):
    """Studded display plinth: sand base, navy body, gold collar, sand cap, red plaque. `top` = attachment z."""
    s = hw / 2.2
    b.box((x - hw - 0.35, y - hw - 0.35, z0), (x + hw + 0.35, y + hw + 0.35, z0 + 0.06), P.NAVY, bevel=0.0,
          bottom=False)                                                                                       # border tile
    b.box((x - hw, y - hw, z0), (x + hw, y + hw, z0 + 0.55), P.SAND, bevel=0.08, bottom=False)
    b.box((x - hw + 0.25, y - hw + 0.25, z0 + 0.55), (x + hw - 0.25, y + hw - 0.25, z0 + 0.72), P.DSAND,
          bevel=0.03, bottom=False)
    bw = 1.7 * s
    b.box((x - bw, y - bw, z0 + 0.72), (x + bw, y + bw, z0 + 2.95), P.NAVY, bevel=0.05, bottom=False)
    b.box((x - bw - 0.08, y - bw - 0.08, z0 + 2.75), (x + bw + 0.08, y + bw + 0.08, z0 + 2.95), P.GOLD,
          bevel=0.02)
    b.box((x - hw + 0.1, y - hw + 0.1, z0 + 2.95), (x + hw - 0.1, y + hw - 0.1, z0 + 3.40), P.SAND, bevel=0.07)
    b.box((x - hw + 0.3, y - hw + 0.3, z0 + 3.40), (x + hw - 0.3, y + hw - 0.3, z0 + 3.62), P.DSAND, bevel=0.03,
          bottom=False)
    for dx in (-hw + 0.85, hw - 0.85):
        for dy in (-hw + 0.85, hw - 0.85):
            stud(b, x + dx, y + dy, z0 + 3.62, P.SAND, r=0.42)
    b.box((x - 1.05 * s, y - bw - 0.05, z0 + 1.05), (x + 1.05 * s, y - bw + 0.02, z0 + 2.35), P.RED, bevel=0.02)
    return (x, y, top)


def square_column(b, x, y, z0, z1, shaft=P.NAVY, base=P.SAND, cap=P.SAND):
    b.box((x - 1.75, y - 1.75, z0), (x + 1.75, y + 1.75, z0 + 0.06), P.NAVY, bevel=0.0, bottom=False)  # border
    b.box((x - 1.1, y - 1.1, z0), (x + 1.1, y + 1.1, z0 + 0.45), base, bevel=0.06, bottom=False)
    b.box((x - 0.9, y - 0.9, z0 + 0.45), (x + 0.9, y + 0.9, z0 + 0.75), P.DSAND, bevel=0.03, bottom=False)
    b.box((x - 0.7, y - 0.7, z0 + 0.75), (x + 0.7, y + 0.7, z1 - 0.85), shaft, bevel=0.04, bottom=False)
    b.box((x - 0.75, y - 0.75, z1 - 1.55), (x + 0.75, y + 0.75, z1 - 1.22), P.GOLD, bevel=0.02)
    b.box((x - 0.9, y - 0.9, z1 - 0.85), (x + 0.9, y + 0.9, z1 - 0.25), P.SAND, bevel=0.04)
    b.box((x - 1.15, y - 1.15, z1 - 0.25), (x + 1.15, y + 1.15, z1), cap, bevel=0.05)


def round_column(b, x, y, z0, z1, shaft=P.SAND):
    b.box((x - 0.975, y - 0.975, z0), (x + 0.975, y + 0.975, z0 + 0.5), P.NAVY, bevel=0.06)
    b.cyl(x, y, z0 + 0.5, z1 - 0.65, 0.72, shaft, 8)
    b.cyl(x, y, z1 - 0.65, z1 - 0.35, 0.88, P.GOLD, 8)
    b.box((x - 1.0, y - 1.0, z1 - 0.35), (x + 1.0, y + 1.0, z1), P.SAND, bevel=0.05)


def banner(b, cx, yf, z0, z1, w=2.0):
    """A red banner hung on a column's -Y face (yf = the face): gold rod and hem, gold anchor."""
    b.box((cx - w / 2 - 0.2, yf - 0.32, z1), (cx + w / 2 + 0.2, yf, z1 + 0.22), P.GOLD, bevel=0.02)
    b.box((cx - w / 2, yf - 0.16, z0), (cx + w / 2, yf, z1), P.RED, bevel=0.02)
    b.box((cx - w / 2, yf - 0.2, z0), (cx + w / 2, yf, z0 + 0.3), P.GOLD, bevel=0.02)
    y0, y1, za, zb = yf - 0.24, yf - 0.12, z0 + 1.5, z1 - 0.8                       # gold anchor
    b.box((cx - 0.13, y0, za), (cx + 0.13, y1, zb + 0.3), P.GOLD, bevel=0.01)              # shank
    b.box((cx - 0.6, y0, zb - 0.25), (cx + 0.6, y1, zb), P.GOLD, bevel=0.01)               # stock
    b.box((cx - 0.75, y0, za), (cx + 0.75, y1, za + 0.22), P.GOLD, bevel=0.01)             # crown
    for x in (cx - 0.75, cx + 0.58):
        b.box((x, y0, za + 0.22), (x + 0.17, y1, za + 0.75), P.GOLD, bevel=0.01)          # flukes


def dome_ribs(b, profile, c, lift=0.12, width=0.55, thick=0.34, skip_top=0.0):
    top = profile[-1][1]
    for ang in COL_ANGLES:
        pts = [(RCX + (r + lift) * math.cos(math.radians(ang)), RCY + (r + lift) * math.sin(math.radians(ang)), z)
               for r, z in profile]
        for p0, p1 in zip(pts, pts[1:]):
            if p1[2] > top - skip_top:
                break
            b.beam(p0, p1, width, thick, c)


# ------------------------------------------------------------------ Lv2
def lv2_base(b):
    b.lathe(RCX, RCY, [(PAD_R, 0.0), (PAD_R, 0.20)], P.NAVY, 16, bottom=False)
    b.lathe(RCX, RCY, [(PAD_R - 0.35, 0.20), (PAD_R - 0.35, BASE)], P.SAND, 16, bottom=False)
    for sgn in (1, -1):
        x0, x1 = (WING_X0, WING_X1) if sgn > 0 else (-WING_X1, -WING_X0)
        b.box((x0, WING_Y0, 0.0), (x1, WING_Y1, 0.40), P.NAVY, bevel=0.10, bottom=False)
        b.box((x0 + 0.22, WING_Y0 + 0.18, 0.40), (x1 - 0.22, WING_Y1 - 0.18, WING), P.SAND, bevel=0.05, bottom=False)
        xx = 24.47 if sgn > 0 else -24.47
        b.box((xx - 0.06, WING_Y0 + 0.2, 0.14), (xx + 0.06, WING_Y1 - 0.2, 0.26), P.RED, bevel=0.01)
    seam(b, -10.5, 0.0, 10.5, 0.0, BASE, c=P.DSAND)
    seam(b, 0.0, -9.9, 0.0, 11.9, BASE, c=P.DSAND)
    seam(b, -10.5, 5.2, 10.5, 5.2, BASE, c=P.DSAND)
    cols = {ring_at(COL_R, a) for a in COL_ANGLES}

    def skip(x, y):
        if abs(x) < 10.9 and -1.7 < y < 1.3:                     # the code wall + shelf
            return True
        if abs(x) > 6.0 and PATH_Y0 - 0.5 < y < PATH_Y1 + 0.5:       # the red path to the wings
            return True
        return any((x - cx) ** 2 + (y - cy) ** 2 < 2.4 ** 2 for cx, cy in cols)

    disc_studs(b, RCX, RCY, PAD_R - 0.4, BASE, P.SAND, skip=skip)

    def wing_skip(x, y):
        if abs(abs(x) - (AISLE_X0 + AISLE_X1) / 2) < 2.5:
            return True
        return any(abs(x - sx) < 3.0 and abs(y - sy) < 3.0 for sx in (PL_X, -PL_X) for sy in PL_Y)

    for x0 in (WING_X0, -WING_X1):
        studs_grid(b, x0 + 0.5, x0 + (WING_X1 - WING_X0) - 0.5, WING_Y0 + 0.5, WING_Y1 - 0.5, WING, P.SAND,
                   skip=wing_skip)
    for sgn in (1, -1):                                                   # red aisle, gold edges, path to the rotunda
        def sx(x0, x1):
            return (min(sgn * x0, sgn * x1), max(sgn * x0, sgn * x1))
        a0, a1 = sx(AISLE_X0, AISLE_X1)
        b.box((a0, WING_Y0 + 0.6, WING), (a1, WING_Y1 - 0.6, WING + 0.05), P.RED, bevel=0.0, bottom=False)
        for e0, e1 in ((AISLE_X0 - 0.25, AISLE_X0), (AISLE_X1, AISLE_X1 + 0.25)):
            g0, g1 = sx(e0, e1)
            b.box((g0, WING_Y0 + 0.6, WING), (g1, WING_Y1 - 0.6, WING + 0.06), P.GOLD, bevel=0.0, bottom=False)
        p0, p1 = sx(8.0, 12.1)
        b.box((p0, PATH_Y0, BASE), (p1, PATH_Y1, BASE + 0.05), P.RED, bevel=0.0, bottom=False)
        p0, p1 = sx(12.0, AISLE_X0)
        b.box((p0, PATH_Y0, WING), (p1, PATH_Y1, WING + 0.05), P.RED, bevel=0.0, bottom=False)


def lv2_colonnade(b):
    for a in COL_ANGLES:
        x, y = ring_at(COL_R, a)
        square_column(b, x, y, BASE, DRUM_Z0 + 0.15)
    for a in (247.5, 292.5):                                      # the two front columns, on their outer (-Y) faces
        x, y = ring_at(COL_R, a)
        banner(b, x, y - 0.7, 3.7, 8.7)


def lv2_drum(b):
    b.lathe(RCX, RCY, [(DRUM_R, DRUM_Z0), (DRUM_R, DRUM_Z1)], P.SAND, 16)
    for z0, z1 in ((DRUM_Z0, DRUM_Z0 + 0.28), (DRUM_Z1 - 0.28, DRUM_Z1 + 0.10)):          # navy cornice bands
        b.lathe(RCX, RCY, [(11.90, z0), (11.90, z1)], P.NAVY, 16, bottom=False, top=False)
    for a in COL_ANGLES:                                                                   # gold-rimmed portholes
        x, y = ring_at(DRUM_R, a)
        b.cyl_radial(x, y, 12.05, math.radians(a), 1.15, 0.8, P.GOLD, 8, inner=False)
        b.cyl_radial(x, y, 12.05, math.radians(a), 0.90, 1.0, P.GLASS, 8, inner=False)


DOME = [(11.60, 13.45), (11.35, 14.60), (10.70, 15.90), (9.50, 17.30),
        (7.70, 18.70), (5.40, 19.90), (3.00, 20.90), (0.90, DOME_TOP)]
BAND = 3                                                   # the sand equator band starts at DOME[3]


def lv2_dome(b):
    b.lathe(RCX, RCY, DOME[:7], P.NAVY, 16, bottom=False, top=False)                   # the cap closes the top
    ring = [DOME[BAND], (8.60, 18.00), DOME[BAND + 1]]
    b.lathe(RCX, RCY, [(r + 0.07, z) for r, z in ring], P.SAND, 16, bottom=False, top=False)
    dome_ribs(b, DOME[:6] + [(2.7, 21.03)], P.SAND, lift=0.10, width=0.55, thick=0.38)  # ribs run into the cap
    # stud-ring cap, kept inside the Lv3 gold shell and lantern base (r 2.9 from z 21.4)
    zc = 21.30
    b.cyl(RCX, RCY, 20.75, zc, 3.1, P.SAND, 16, bottom=False)
    for a in COL_ANGLES:
        x, y = ring_at(2.05, a)
        stud(b, x, y, zc, P.SAND)
    b.lathe(RCX, RCY, [(0.75, zc), (0.75, zc + 0.45), (0.5, zc + 0.7), (0.15, zc + 1.4)], P.GOLD, 8,
            bottom=False)


def lv2_plinths(b, atts):
    for side in (-1, 1):
        for sy in PL_Y:
            x, y = side * PL_X, sy
            atts.append(pedestal(b, x, y, WING, WING + 3.62))


# ------------------------------------------------------------------ Lv3
def lv3_portico(b):
    for x0, x1, y0, y1, z0, z1 in ((-10.9, 10.9, -14.0, -9.3, 0.0, 0.33), (-10.5, 10.5, -13.7, -9.4, 0.33, 0.61),
                                   (-10.1, 10.1, -13.4, -9.5, 0.61, STYLO)):
        b.box((x0, y0, z0), (x1, y1, z1), P.SAND, bevel=0.08)
    b.box((-2.8, -13.25, STYLO - 0.02), (2.8, -9.6, STYLO + 0.06), P.RED, bevel=0.01)
    for x0, x1 in ((-3.02, -2.8), (2.8, 3.02)):
        b.box((x0, -13.25, STYLO - 0.02), (x1, -9.6, STYLO + 0.07), P.GOLD, bevel=0.0)
    for x in PORT_COL_X:
        round_column(b, x, PORT_COL_Y, STYLO, ARCH_Z0, P.SAND)
    b.box((-9.2, -13.1, ARCH_Z0), (9.2, -11.3, ARCH_Z1), P.NAVY, bevel=0.07)
    b.box((-9.2, -13.15, ARCH_Z0), (9.2, -13.05, ARCH_Z0 + 0.16), P.GOLD, bevel=0.01)
    b.box((-8.6, -13.14, ARCH_Z0 + 0.35), (8.6, -13.05, ARCH_Z1 - 0.15), P.RED, bevel=0.0)
    b.box((-9.25, -13.1, ARCH_Z1), (9.25, -11.25, ARCH_Z1 + 0.16), P.SAND, bevel=0.03)
    prof = [(-9.2, ARCH_Z1 + 0.16), (9.2, ARCH_Z1 + 0.16), (0.0, PED_APEX)]
    prism_y(b, -13.0, -11.35, prof, P.NAVY)
    b.beam((-9.2, -12.95, ARCH_Z1 + 0.16), (0.0, -12.95, PED_APEX), 0.46, 0.46, P.SAND)
    b.beam((9.2, -12.95, ARCH_Z1 + 0.16), (0.0, -12.95, PED_APEX), 0.46, 0.46, P.SAND)
    b.box((-9.2, -13.12, ARCH_Z1 + 0.10), (9.2, -12.95, ARCH_Z1 + 0.42), P.SAND, bevel=0.02)
    b.disc_y(0.0, -13.06, 13.40, 1.72, 0.14, P.SAND, 8)
    b.disc_y(0.0, -13.15, 13.40, 1.48, 0.14, P.NAVY, 8)
    yf = -13.24
    b.box((-0.17, yf, 12.10), (0.17, yf + 0.12, 14.40), P.GOLD, bevel=0.01)              # anchor shank
    b.box((-1.0, yf, 13.40), (1.0, yf + 0.12, 13.63), P.GOLD, bevel=0.01)                # stock
    b.box((-1.0, yf, 12.10), (1.0, yf + 0.12, 12.31), P.GOLD, bevel=0.01)                # crown
    for x in (-1.0, 0.84):
        b.box((x, yf, 12.31), (x + 0.16, yf + 0.12, 13.05), P.GOLD, bevel=0.01)          # flukes
    b.disc_y(0.0, yf + 0.06, 14.57, 0.32, 0.14, P.GOLD, 8)                               # ring


CAN_Y0 = -9.7
WALL_Y0 = -8.4
AISLE_X0, AISLE_X1, PATH_Y0, PATH_Y1 = 14.2, 18.0, 1.5, 4.2   # Lv2 red aisle along each wing + path to the rotunda


def lv3_gallery(b):
    for sgn in (1, -1):
        x0, x1 = (GAL_X0, GAL_X1) if sgn > 0 else (-GAL_X1, -GAL_X0)
        b.box((x0, GAL_Y0, 0.0), (x1, GAL_Y1, GAL - 0.12), P.NAVY, bevel=0.09)
        b.box((x0 + 0.2, GAL_Y0 + 0.18, GAL - 0.12), (x1 - 0.2, GAL_Y1 - 0.16, GAL), P.SAND, bevel=0.04)
        seam(b, x0 + 0.4, -9.9, x1 - 0.4, -9.9, GAL)
        b.box((x0, WALL_Y0, GAL), (x1, GAL_Y1, CANOPY_Z0), P.NAVY, bevel=0.05)          # backdrop wall behind the plinths
        for cx0, cx1 in ((GAL_COL_X[0], GAL_COL_X[1]), (GAL_COL_X[1], GAL_COL_X[2])):
            m = (cx0 + cx1) / 2 * sgn
            b.box((m - 1.7, WALL_Y0 - 0.06, GAL + 1.3), (m + 1.7, WALL_Y0 + 0.02, GAL + 6.2), P.RED, bevel=0.02)
        for cx in GAL_COL_X:
            x = cx if sgn > 0 else -cx
            b.box((x - 0.75, GAL_COL_Y - 0.75, GAL), (x + 0.75, GAL_COL_Y + 0.75, GAL + 0.42), P.NAVY,
                  bevel=0.04)
            b.cyl(x, GAL_COL_Y, GAL + 0.42, CANOPY_Z0 - 0.55, 0.50, P.SAND, 8)
            b.box((x - 0.62, GAL_COL_Y - 0.62, CANOPY_Z0 - 0.55), (x + 0.62, GAL_COL_Y + 0.62,
                  CANOPY_Z0 - 0.30), P.GOLD, bevel=0.02)
            b.box((x - 0.65, GAL_COL_Y - 0.65, CANOPY_Z0 - 0.30), (x + 0.65, GAL_COL_Y + 0.65, CANOPY_Z0),
                  P.NAVY, bevel=0.04)
        zt = CANOPY_Z0 + 1.2                                                              # solid navy entablature
        b.box((x0, CAN_Y0, CANOPY_Z0), (x1, GAL_Y1, zt), P.NAVY, bevel=0.06)
        for z0, z1 in ((CANOPY_Z0 + 0.1, CANOPY_Z0 + 0.3), (zt - 0.3, zt - 0.1)):         # gold trim lines
            b.box((x0 + 0.05, CAN_Y0 - 0.08, z0), (x1 - 0.05, CAN_Y0 + 0.02, z1), P.GOLD, bevel=0.0)
        b.box((x0 + 0.5, CAN_Y0 - 0.06, CANOPY_Z0 + 0.4), (x1 - 0.5, CAN_Y0 + 0.02, zt - 0.4), P.RED, bevel=0.0)
        b.box((x0 - 0.1, CAN_Y0 - 0.15, zt), (x1 + 0.1, GAL_Y1 + 0.1, CANOPY_Z1), P.SAND, bevel=0.05)
        studs_grid(b, x0 + 0.5, x1 - 0.5, CAN_Y0 + 0.3, GAL_Y1 - 0.3, CANOPY_Z1, P.GOLD, step=3.0, r=0.40)


def lv3_plinths(b, atts):
    for side in (-1, 1):
        for sx in GAL_PL_X:
            atts.append(pedestal(b, side * sx, GAL_PL_Y, GAL, GAL + 3.62, hw=1.9))


GOLD = [(11.95, 13.30), (11.75, 14.60), (11.10, 16.00), (9.90, 17.55),
        (8.10, 19.00), (5.70, 20.30), (3.10, 21.40), (0.90, GOLD_TOP)]


def lv3_gold_dome(b):
    b.lathe(RCX, RCY, GOLD, P.GOLD, 16)
    ring = [GOLD[3], (9.00, 18.28), GOLD[4]]                                           # deep-gold equator band
    b.lathe(RCX, RCY, [(r + 0.10, z) for r, z in ring], P.GOLD2, 16, bottom=False, top=False)
    dome_ribs(b, GOLD, P.GOLD2, lift=0.30, width=0.95, thick=0.70, skip_top=0.7)
    b.lathe(RCX, RCY, [(2.9, GOLD_TOP - 0.70), (2.9, GOLD_TOP + 0.35)], P.GOLD, 12)


def lv3_lantern(b):
    z0 = GOLD_TOP + 0.35
    b.lathe(RCX, RCY, [(2.7, z0), (2.7, z0 + 0.45)], P.GOLD, 12)
    zg0, zg1 = z0 + 0.45, z0 + 2.85
    b.cyl(RCX, RCY, zg0, zg1, 1.85, P.GLASS, 12)
    for i in range(8):
        a = 2 * math.pi * i / 8
        rot_box(b, RCX + 1.95 * math.cos(a), RCY + 1.95 * math.sin(a), zg0, a, 0.45, 0.45, zg1 - zg0, P.GOLD,
                bevel=0.03)
    b.lathe(RCX, RCY, [(2.4, zg1 - 0.1), (2.4, zg1 + 0.3)], P.RED, 12)
    b.lathe(RCX, RCY, [(2.9, zg1 + 0.3), (2.35, zg1 + 1.0), (1.5, zg1 + 1.8), (0.4, zg1 + 2.5)], P.GOLD, 12)
    b.lathe(RCX, RCY, [(0.7, zg1 + 2.4), (0.7, zg1 + 2.8), (0.25, zg1 + 3.1)], P.GOLD2, 8)
    pole_z0 = zg1 + 3.0
    b.cyl(RCX, RCY, pole_z0, pole_z0 + 3.6, 0.16, P.GOLD, 8)
    b.cyl(RCX, RCY, pole_z0 + 3.6, pole_z0 + 3.95, 0.36, P.GOLD, 8)
    fy = RCY
    b.box((0.12, fy - 0.13, pole_z0 + 1.6), (3.9, fy + 0.13, pole_z0 + 3.5), P.RED, bevel=0.06)
    b.box((0.12, fy - 0.15, pole_z0 + 1.6), (3.9, fy + 0.15, pole_z0 + 1.88), P.GOLD, bevel=0.02)
    b.box((2.6, fy - 0.16, pole_z0 + 1.6), (2.85, fy + 0.16, pole_z0 + 3.45), P.RED2, bevel=0.01)
    b.box((2.0, fy - 0.16, pole_z0 + 2.4), (2.3, fy + 0.16, pole_z0 + 2.9), P.GOLD, bevel=0.01)


# ------------------------------------------------------------------ collision
def lv2_col(c):
    c.box((RCX - PAD_R, RCY - 7.2, 0.0), (RCX + PAD_R, RCY + 7.2, BASE), P.WHITE, bevel=0.0)
    c.box((RCX - 7.2, RCY - PAD_R, 0.0), (RCX + 7.2, RCY + PAD_R, BASE), P.WHITE, bevel=0.0)
    for sgn in (1, -1):
        x0, x1 = (WING_X0, WING_X1) if sgn > 0 else (-WING_X1, -WING_X0)
        c.box((x0, WING_Y0, 0.0), (x1, WING_Y1, WING), P.WHITE, bevel=0.0)
    for a in COL_ANGLES:
        x, y = ring_at(COL_R, a)
        c.box((x - 1.12, y - 1.12, BASE), (x + 1.12, y + 1.12, DRUM_Z0), P.WHITE, bevel=0.0)
    for side in (-1, 1):
        for sy in PL_Y:
            x = side * PL_X
            c.box((x - 2.25, sy - 2.25, WING), (x + 2.25, sy + 2.25, WING + 3.65), P.WHITE, bevel=0.0)


def lv3_col(c):
    for x0, x1, y0, y1, z0, z1 in ((-10.9, 10.9, -14.0, -9.3, 0.0, 0.33), (-10.5, 10.5, -13.7, -9.4, 0.33, 0.61),
                                   (-10.1, 10.1, -13.4, -9.5, 0.61, STYLO)):
        c.box((x0, y0, z0), (x1, y1, z1), P.WHITE, bevel=0.0)
    for x in PORT_COL_X:
        c.box((x - 1.0, PORT_COL_Y - 1.0, STYLO), (x + 1.0, PORT_COL_Y + 1.0, ARCH_Z0), P.WHITE, bevel=0.0)
    for sgn in (1, -1):
        x0, x1 = (GAL_X0, GAL_X1) if sgn > 0 else (-GAL_X1, -GAL_X0)
        c.box((x0, GAL_Y0, 0.0), (x1, GAL_Y1, GAL), P.WHITE, bevel=0.0)
        c.box((x0, WALL_Y0, GAL), (x1, GAL_Y1, CANOPY_Z0), P.WHITE, bevel=0.0)
        for cx in GAL_COL_X:
            x = cx if sgn > 0 else -cx
            c.box((x - 0.8, GAL_COL_Y - 0.8, GAL), (x + 0.8, GAL_COL_Y + 0.8, CANOPY_Z0), P.WHITE, bevel=0.0)
        for sx in GAL_PL_X:
            x = sx if sgn > 0 else -sx
            c.box((x - 1.95, GAL_PL_Y - 1.95, GAL), (x + 1.95, GAL_PL_Y + 1.95, GAL + 3.65), P.WHITE, bevel=0.0)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_TrophyHall_Brick", ALB)
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
        print("[trophy] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    atts = []

    b = lego.B()
    lv2_base(b)
    out("Lv2_L01_Base", b, "Lv2")

    b = lego.B()
    lv2_colonnade(b)
    out("Lv2_L02_Colonnade", b, "Lv2")

    b = lego.B()
    lv2_drum(b)
    out("Lv2_L03_Drum", b, "Lv2")

    b = lego.B()
    lv2_dome(b)
    out("Lv2_L04_Dome", b, "Lv2")

    b = lego.B()
    lv2_plinths(b, atts)
    out("Lv2_L05_Plinths", b, "Lv2")

    c = lego.B()
    lv2_col(c)
    out_cols("Lv2", c)

    b = lego.B()
    lv3_portico(b)
    out("Lv3_L01_Portico", b, "Lv3")

    b = lego.B()
    lv3_gallery(b)
    out("Lv3_L02_Gallery", b, "Lv3")

    b = lego.B()
    lv3_plinths(b, atts)
    out("Lv3_L03_Plinths", b, "Lv3")

    b = lego.B()
    lv3_gold_dome(b)
    out("Lv3_L04_GoldDome", b, "Lv3")

    b = lego.B()
    lv3_lantern(b)
    out("Lv3_L05_Lantern", b, "Lv3")

    c = lego.B()
    lv3_col(c)
    out_cols("Lv3", c)

    attachments = [lego.attach("ATT_Plinth_%02d" % (i + 1), loc) for i, loc in enumerate(atts)]

    pts = []
    for e in meshes:
        if e["role"] == "visual":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[trophy] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[trophy] LOD0 %d tris in %d visual meshes, %d COL boxes"
          % (total, sum(e["role"] == "visual" for e in meshes), sum(e["role"] != "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only, on the code trophy wall's 50 x 28 stud landmark lot (ground z 0, wall at y 0, "
                     "front -Y); the rotunda is centred 1.5 behind the wall, the portico and gallery reach the lot "
                     "front, the plinth wings the side edges; origin the code hall's ground centre (place with no "
                     "extra scale)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25 B): Lv2_L01_..., Lv3_L01_..., Lv2_Col01_COL.., "
                      "Lv3_Col01_COL..; the FBX importer flattens empty parents, so the node name is the mesh prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": attachments,
        "closeups": [
            {"name": "rotunda", "target": [0.0, 1.5, 13.0], "dist": 44, "az": 32, "el": 16},
            {"name": "plinth_wing", "target": [21.8, 2.5, 3.0], "dist": 27, "az": 45, "el": 13},
            {"name": "portico", "target": [0.0, -12.0, 8.0], "dist": 26, "az": 18, "el": 10},
            {"name": "lantern", "target": [0.0, 1.5, 25.5], "dist": 34, "az": 34, "el": 18},
        ],
    }
