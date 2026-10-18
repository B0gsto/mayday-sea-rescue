"""M_Bld_LifeguardTower (docs/12 2.2, batch H6, fix round H6b): the beach lifeguard hut on Haven Sands.

A raised timber hut: six salt-bleached timber posts with X-bracing, bolts and galvanised plates, sand scour collars and
barnacles at the feet, bearers, joists and a boarded deck 3.0 m up, a 3.0 x 3.0 m cabin in bevelled weatherboards
painted red over yellow (flaking at board edges and ends to grey timber), white trims, a lookout window, side windows, a
boarded red door in a lined frame with shadow gaps, T-hinges, hasp, staple and padlock, a mono-pitch box-profile steel
roof with deep overhangs, fascias, soffits, knee brackets, gutter and downpipe, a weathered "LIFEGUARDS" sign (generic,
no RNLI marks), a balustered guard rail round the lookout deck, steep timber steps to the sand, a red-over-yellow patrol
flag on a white pole (ATT_Flag), and a galvanised rack holding a yellow / red rescue board. Shared pipeline:
../H6/h6lib.py.
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_LifeguardTower --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "H6"))
import h6lib  # noqa: E402
from h6lib import Geo  # noqa: E402
from h6tex import col, fbm, hash3, luma, mask_img, mix, scan, ss, text_sample, tone, tri, HERE as H6DIR  # noqa: E402

NAME = "M_Bld_LifeguardTower"
TEX = "LifeguardTower"
H_CLAD, H_TRIM, H_ROOF, H_DOOR, H_FRAME, H_SIGN, H_GLASS, H_METAL, H_INTERIOR, H_IRON, H_BRASS = range(11)
(F_POST, F_DECK, F_RAIL, F_STAIR, F_POLE, F_FLAG, F_BOARD, F_RACK, F_ROPE, F_STRAP,
 F_JOIST, F_BEARER, F_BRACE, F_STEEL, F_SAND) = range(15)

DECK = 3.0
BH = 0.15                                     # weatherboard pitch
CAB = (-1.5, 1.5, -1.4, 1.6)                  # cabin x0, x1, y0, y1
DECK_XY = (-1.7, 1.7, -2.3, 1.75)
WALL_TOP = DECK + 18 * BH                     # 5.70
ROOF_FRONT, ROOF_BACK = 5.95, 5.79            # top of the sheet at the front / back drip edges
ROOF_Y = (CAB[2] - 0.55, CAB[3] + 0.30)       # overhangs: 0.55 front, 0.30 back
ROOF_X = 1.80                                 # 0.30 side overhangs
YELLOW_ROWS = 7                               # boards 0..6 yellow (below the sills), 7.. red
STAIR_X = (0.55, 1.45)
STAIR_FOOT_Y = -4.45
POLE = (-1.80, -2.36)
POLE_TOP = 8.0
FLAG = (7.30, 7.90, 0.90)                     # hoist bottom, top, fly length
SIGN = {"x": -0.10, "z": 5.385, "w": 2.50, "h": 0.30, "y": -1.455, "t": 0.03}
BOARD = {"x": -1.99, "y0": -1.85, "L": 2.90, "z": 3.52}
WIN_FRONT = (-1.30, 0.10, DECK + 7 * BH, DECK + 14 * BH)
WIN_L = (-0.60, 0.60, DECK + 7 * BH, DECK + 13 * BH)
WIN_R = (-0.10, 0.80, DECK + 7 * BH, DECK + 13 * BH)
DOOR = (0.47, 1.28, DECK, DECK + 14 * BH)
LINE = 0.024                                  # door lining thickness
LEAF = (DOOR[0] + LINE + 0.008, DOOR[1] - LINE - 0.008, DECK + 0.012, DOOR[3] - LINE - 0.008)
HASP_Z = 4.12


def roof_z(y):
    """Top of the roof sheet at y (mono-pitch, high at the front)."""
    return ROOF_FRONT + (y - ROOF_Y[0]) * (ROOF_BACK - ROOF_FRONT) / (ROOF_Y[1] - ROOF_Y[0])


# the four walls: (name, outward normal, plane coordinate, along-axis 'x' / 'y', span, holes)
WALLS = [("front", (0, -1, 0), CAB[2], "x", (CAB[0] - 0.03, CAB[1] + 0.03), [WIN_FRONT, DOOR]),
         ("back", (0, 1, 0), CAB[3], "x", (CAB[0] - 0.03, CAB[1] + 0.03), []),
         ("left", (-1, 0, 0), CAB[0], "y", (CAB[2], CAB[3]), [WIN_L]),
         ("right", (1, 0, 0), CAB[1], "y", (CAB[2], CAB[3]), [WIN_R])]


def weatherboards(g, out, c, axis, span, holes, rows):
    """Bevelled weatherboards (150 mm pitch, 22 mm thick, tilted so each bottom edge laps 12 mm proud of the board
    below), cut round the holes; each segment is one plank with chamfered long edges and square ends."""
    O = Vector(out)
    Z = Vector((0, 0, 1))
    A = O.cross(Z)
    th = math.atan2(0.012, BH)
    Zt = Z * math.cos(th) - O * math.sin(th)
    Ot = O * math.cos(th) + Z * math.sin(th)
    rot = Matrix(((A.x, Ot.x, Zt.x, 0), (A.y, Ot.y, Zt.y, 0), (A.z, Ot.z, Zt.z, 0), (0, 0, 0, 1)))
    for k in range(rows):
        z0 = DECK + k * BH
        zc = z0 + BH / 2
        cuts = [span[0], span[1]]
        segs = [(span[0], span[1])]
        for h in holes:
            if h[2] < zc < h[3]:
                new = []
                for s0, s1 in segs:
                    if h[1] <= s0 or h[0] >= s1:
                        new.append((s0, s1))
                        continue
                    if h[0] > s0:
                        new.append((s0, h[0]))
                    if h[1] < s1:
                        new.append((h[1], s1))
                segs = new
        _ = cuts
        for s0, s1 in segs:
            if s1 - s0 < 0.02:
                continue
            m = (s0 + s1) / 2
            p = Vector((m, c, zc)) if axis == "x" else Vector((c, m, zc))
            p += O * 0.017
            g.bbox(p, (s1 - s0, 0.022, BH + 0.004), H_CLAD, 0.006, rot, axis=0)


def window(g, axis, c, out, a0, a1, z0, z1):
    """Frame, mullion, glass and interior panel in a hole of a wall at `c`; out = -1 / +1 outward direction; white
    bevelled architrave, sill and head."""
    def b(ca, off, cz, sa, sd, sz, part, bev=0.0):
        cen = (ca, c + out * off, cz) if axis == "y" else (c + out * off, ca, cz)
        size = (sa, sd, sz) if axis == "y" else (sd, sa, sz)
        if bev > 0:
            g.bbox(cen, size, part, bev)
        else:
            g.box(cen, size, part)
    am, zm = (a0 + a1) / 2, (z0 + z1) / 2
    fw = 0.06
    for a in (a0 + fw / 2, a1 - fw / 2):
        b(a, 0.0, zm, fw, 0.07, z1 - z0, H_FRAME)
    for z in (z0 + fw / 2, z1 - fw / 2):
        b(am, 0.0, z, a1 - a0, 0.07, fw, H_FRAME)
    if a1 - a0 > 0.9:
        b(am, 0.0, zm, 0.05, 0.06, z1 - z0, H_FRAME)
    b(am, -0.005, zm, a1 - a0 - 0.02, 0.01, z1 - z0 - 0.02, H_GLASS)
    b(am, -0.06, zm, a1 - a0, 0.01, z1 - z0, H_INTERIOR)
    for a in (a0 - 0.035, a1 + 0.035):                      # architrave
        b(a, 0.045, zm, 0.07, 0.022, z1 - z0 + 0.02, H_TRIM, 0.006)
    b(am, 0.07, z0 - 0.03, a1 - a0 + 0.20, 0.11, 0.05, H_TRIM, 0.008)      # sill
    b(am, 0.05, z1 + 0.04, a1 - a0 + 0.18, 0.04, 0.08, H_TRIM, 0.008)      # head


def hut_geo():
    g = Geo()
    x0, x1, y0, y1 = CAB
    for _, out, c, axis, span, holes in WALLS:
        weatherboards(g, out, c, axis, span, holes, 18)
    window(g, "y", y0, -1, *WIN_FRONT)
    window(g, "x", x0, -1, *WIN_L)
    window(g, "x", x1, 1, *WIN_R)
    # white corner boards, skirting, friezes (bevelled)
    for cx in (x0, x1):
        for cy in (y0, y1):
            g.bbox((cx + 0.035 * np.sign(cx), cy + 0.035 * np.sign(cy), (DECK + WALL_TOP) / 2), (0.11, 0.11, WALL_TOP - DECK + 0.02),
                   H_TRIM, 0.01, axis=2)
    g.bbox((0.0, y1 + 0.05, DECK + 0.07), (x1 - x0, 0.03, 0.14), H_TRIM, 0.008, axis=0)
    for sx, xx in ((-1, x0), (1, x1)):
        g.bbox((xx + sx * 0.05, (y0 + y1) / 2, DECK + 0.07), (0.03, y1 - y0, 0.14), H_TRIM, 0.008, axis=1)
    g.bbox(((x0 + DOOR[0]) / 2, y0 - 0.05, DECK + 0.07), (DOOR[0] - x0 - 0.07, 0.03, 0.14), H_TRIM, 0.008, axis=0)
    zf = roof_z(y0) - 0.07
    g.bbox((0.0, y0 - 0.045, (WALL_TOP - 0.10 + zf) / 2), (x1 - x0 + 0.10, 0.03, zf - WALL_TOP + 0.10), H_TRIM, 0.008, axis=0)
    zb = roof_z(y1) - 0.07
    g.bbox((0.0, y1 + 0.045, (WALL_TOP - 0.12 + zb) / 2), (x1 - x0 + 0.10, 0.03, zb - WALL_TOP + 0.12), H_TRIM, 0.008, axis=0)
    for sx, xx in ((-1, x0), (1, x1)):         # side friezes follow the pitch
        g.bbeam((xx + sx * 0.045, y0 - 0.02, roof_z(y0) - 0.17), (xx + sx * 0.045, y1 + 0.02, roof_z(y1) - 0.17), 0.03, 0.22,
                H_TRIM, up=(0, 0, 1), bev=0.008)
    # door: lining (jambs, head), architrave, boarded leaf in 6 V-jointed planks with shadow gaps, dark void behind
    dx0, dx1, dz0, dz1 = DOOR
    for a in (dx0 + LINE / 2, dx1 - LINE / 2):
        g.box((a, y0 - 0.005, (dz0 + dz1) / 2), (LINE, 0.07, dz1 - dz0), H_TRIM)
    g.box(((dx0 + dx1) / 2, y0 - 0.005, dz1 - LINE / 2), (dx1 - dx0, 0.07, LINE), H_TRIM)
    for a in (dx0 - 0.035, dx1 + 0.035):
        g.bbox((a, y0 - 0.05, (dz0 + dz1) / 2 + 0.035), (0.07, 0.025, dz1 - dz0 + 0.07), H_TRIM, 0.006, axis=2)
    g.bbox(((dx0 + dx1) / 2, y0 - 0.05, dz1 + 0.035), (dx1 - dx0 + 0.14, 0.025, 0.07), H_TRIM, 0.006, axis=0)
    g.box(((dx0 + dx1) / 2, y0 + 0.05, (dz0 + dz1) / 2), (dx1 - dx0, 0.01, dz1 - dz0), H_INTERIOR)
    lx0, lx1, lz0, lz1 = LEAF
    pw = (lx1 - lx0) / 6
    for i in range(6):
        g.bbox((lx0 + pw * (i + 0.5), y0 + 0.0, (lz0 + lz1) / 2), (pw - 0.002, 0.028, lz1 - lz0), H_DOOR, 0.006, axis=2)
    # black iron T-hinges (strap on the leaf, butterfly on the lining, knuckle), hasp and staple, D pull, brass padlock
    yf = y0 - 0.016
    for zh in (3.32, 4.82):
        g.bbox((lx0 + 0.22, yf - 0.003, zh), (0.42, 0.006, 0.045), H_IRON, 0.002, axis=0)
        g.bbox((lx0 + 0.44, yf - 0.003, zh), (0.04, 0.006, 0.06), H_IRON, 0.002)
        g.bbox((dx0 - 0.02, y0 - 0.066, zh), (0.05, 0.006, 0.16), H_IRON, 0.002)
        g.tube((lx0 - 0.004, yf - 0.012, zh - 0.06), (lx0 - 0.004, yf - 0.012, zh + 0.06), 0.011, 8, H_IRON)
    g.bbox((lx1 - 0.06, yf - 0.004, HASP_Z), (0.12, 0.007, 0.05), H_IRON, 0.002, axis=0)          # hasp, cranked over
    g.box((lx1 + 0.003, (yf - 0.004 + y0 - 0.069) / 2, HASP_Z), (0.007, abs(y0 - 0.069 - yf + 0.004), 0.05), H_IRON)
    g.bbox((dx1 + 0.03, y0 - 0.069, HASP_Z), (0.07, 0.006, 0.05), H_IRON, 0.002, axis=0)
    g.tube((lx1 - 0.12, yf - 0.012, HASP_Z - 0.026), (lx1 - 0.12, yf - 0.012, HASP_Z + 0.026), 0.008, 6, H_IRON)
    g.sweep([(dx1 + 0.03, y0 - 0.066, HASP_Z - 0.016), (dx1 + 0.03, y0 - 0.09, HASP_Z - 0.012),           # staple
             (dx1 + 0.03, y0 - 0.09, HASP_Z + 0.012), (dx1 + 0.03, y0 - 0.066, HASP_Z + 0.016)], 0.0045, 5, H_IRON)
    px, py = dx1 + 0.03, y0 - 0.078
    g.sweep([(px - 0.014, py, HASP_Z - 0.05)] + [(px - 0.014 * math.cos(t), py, HASP_Z - 0.03 + 0.03 * math.sin(t))
                                                 for t in np.linspace(0, math.pi, 7)] + [(px + 0.014, py, HASP_Z - 0.05)],
            0.0035, 5, H_METAL)
    g.bbox((px, py, HASP_Z - 0.075), (0.042, 0.018, 0.048), H_BRASS, 0.005)
    g.sweep([(lx1 - 0.09, yf, 3.80), (lx1 - 0.09, yf - 0.05, 3.81), (lx1 - 0.09, yf - 0.05, 3.95), (lx1 - 0.09, yf, 3.96)],
            0.008, 6, H_IRON)
    # sign board with chamfered edges and four screws
    s = SIGN
    g.bbox((s["x"], s["y"], s["z"]), (s["w"], s["t"], s["h"]), H_SIGN, 0.008)
    for sx in (-1, 1):
        for sz in (-1, 1):
            g.lathe([(0.012, 0.0), (0.009, 0.005), (0.0, 0.006)], 6, H_METAL,
                    m=Matrix.Translation((s["x"] + sx * (s["w"] / 2 - 0.05), s["y"] - s["t"] / 2, s["z"] + sz * (s["h"] / 2 - 0.06)))
                    @ Matrix.Rotation(math.pi / 2, 4, "X"))
    # mono-pitch box-profile roof: sheet, ribs, fascias, bargeboards, soffits, knee brackets, gutter and downpipe
    ry0, ry1 = ROOF_Y
    pitch = math.atan2(ROOF_FRONT - ROOF_BACK, ry1 - ry0)
    g.boxr((0.0, (ry0 + ry1) / 2, (ROOF_FRONT + ROOF_BACK) / 2 - 0.02), (2 * ROOF_X, (ry1 - ry0) / math.cos(pitch), 0.04), H_ROOF, 0.0,
           pitch=-pitch)
    for x in np.linspace(-ROOF_X + 0.06, ROOF_X - 0.06, 18):
        g.beam((x, ry0 - 0.005, ROOF_FRONT + 0.015), (x, ry1 + 0.005, ROOF_BACK + 0.015), 0.035, 0.03, H_ROOF)
    g.bbox((0.0, ry0 - 0.017, ROOF_FRONT - 0.10), (2 * ROOF_X + 0.07, 0.035, 0.24), H_TRIM, 0.008, axis=0)
    g.bbox((0.0, ry1 + 0.017, ROOF_BACK - 0.09), (2 * ROOF_X + 0.07, 0.035, 0.20), H_TRIM, 0.008, axis=0)
    for sx in (-1, 1):
        g.bbeam((sx * (ROOF_X + 0.017), ry0, ROOF_FRONT - 0.08), (sx * (ROOF_X + 0.017), ry1, ROOF_BACK - 0.08), 0.035, 0.20, H_TRIM,
                up=(0, 0, 1), bev=0.008)
        g.bbeam((sx * (ROOF_X + x1) / 2, ry0, ROOF_FRONT - 0.07), (sx * (ROOF_X + x1) / 2, ry1, ROOF_BACK - 0.07),
                ROOF_X - x1, 0.015, H_TRIM, up=(0, 0, 1), bev=0.0)
    g.boxr((0.0, (ry0 + y0) / 2, roof_z((ry0 + y0) / 2) - 0.07), (2 * ROOF_X, y0 - ry0, 0.015), H_TRIM, 0.0, pitch=-pitch)
    g.boxr((0.0, (ry1 + y1) / 2, roof_z((ry1 + y1) / 2) - 0.07), (2 * ROOF_X, ry1 - y1, 0.015), H_TRIM, 0.0, pitch=-pitch)
    for x in (-1.42, 1.42):
        g.bbeam((x, y0 - 0.05, WALL_TOP - 0.42), (x, ry0 + 0.10, roof_z(ry0 + 0.10) - 0.09), 0.07, 0.07, H_TRIM, up=(1, 0, 0), bev=0.008)
    g.lathe([(0.0, 0.0), (0.06, 0.0), (0.06, 2 * ROOF_X), (0.0, 2 * ROOF_X)], 8, H_ROOF,
            m=Matrix.Translation((-ROOF_X, ry1 + 0.08, ROOF_BACK - 0.12)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    g.tube((1.60, ry1 + 0.08, ROOF_BACK - 0.14), (1.60, y1 + 0.08, ROOF_BACK - 0.32), 0.035, 8, H_ROOF)
    g.tube((1.60, y1 + 0.08, ROOF_BACK - 0.32), (1.60, y1 + 0.08, DECK + 0.10), 0.035, 8, H_ROOF)
    return g


def flag(g, x0, y0, zb, zt, L, part, nu=14, nv=6, th=0.006):
    def p(u, v, side):
        x = x0 - L * u
        z = zb + (zt - zb) * v - 0.06 * u * u
        y = y0 + 0.07 * u * math.sin(2 * math.pi * 1.5 * u + 0.8 * v) + side * th / 2
        return Vector((x, y, z))
    F = [[g.bm.verts.new(p(i / nu, j / nv, 1)) for j in range(nv + 1)] for i in range(nu + 1)]
    B = [[g.bm.verts.new(p(i / nu, j / nv, -1)) for j in range(nv + 1)] for i in range(nu + 1)]
    for i in range(nu):
        for j in range(nv):
            g.face((F[i][j], F[i + 1][j], F[i + 1][j + 1], F[i][j + 1]), part)
            g.face((B[i][j + 1], B[i + 1][j + 1], B[i + 1][j], B[i][j]), part)
    for i in range(nu):
        g.face((F[i][0], B[i][0], B[i + 1][0], F[i + 1][0]), part)
        g.face((F[i + 1][nv], B[i + 1][nv], B[i][nv], F[i][nv]), part)
    for j in range(nv):
        g.face((F[0][j + 1], B[0][j + 1], B[0][j], F[0][j]), part)
        g.face((F[nu][j], B[nu][j], B[nu][j + 1], F[nu][j + 1]), part)


def board(g, xc, yb, L, zb, part, n=16):
    """Soft rescue board along +Y: plan outline with a round nose, rounded rails, nose rocker."""
    rings = []
    for k in range(n + 1):
        t = k / n
        w = 0.275 * math.sqrt(max(0.0, 1.0 - ((t - 0.45) / 0.55) ** 4))
        w = max(w, 0.012)
        rock = 0.10 * t ** 3
        y = yb + L * t
        sec = [(-0.80, 0.00), (-1.00, 0.045), (-0.88, 0.11), (0.88, 0.11), (1.00, 0.045), (0.80, 0.00)]
        rings.append([g.bm.verts.new((xc + w * a, y, zb + rock + b * (1.0 - 0.35 * t))) for a, b in sec])
    m = len(rings[0])
    for k in range(n):
        for i in range(m):
            j = (i + 1) % m
            g.face((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]), part)
    g.face(list(reversed(rings[0])), part, False)
    g.face(rings[-1], part, False)


BOLTS = []                                    # bolt / screw heads on the frame (m), for the rust bleed in paint_frame
DECK_N = 23                                   # deck boards across the 3.4 m width


def bolt(g, p, n, simple=False):
    """Galvanised hex bolt head with a washer (or a plain cup head) on a face with outward normal n."""
    n = Vector(n).normalized()
    m = Matrix.Translation(Vector(p)) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4()
    prof = [(0.020, 0.0), (0.020, 0.010), (0.0, 0.012)] if simple else [(0.026, 0.0), (0.021, 0.006), (0.019, 0.016), (0.0, 0.017)]
    g.lathe(prof, 6, F_STEEL, m=m, caps=False)
    BOLTS.append(tuple(p))


def frame_geo():
    BOLTS.clear()
    g = Geo()
    dx0, dx1, dy0, dy1 = DECK_XY
    posts_y = (-2.20, -0.30, 1.65)
    for sx in (-1, 1):
        for y in posts_y:
            g.bbox((sx * 1.60, y, (DECK - 0.04) / 2), (0.15, 0.15, DECK - 0.04), F_POST, 0.014, axis=2)
            # sand scour collar round the foot
            g.lathe([(0.30, 0.0), (0.12, 0.07), (0.0, 0.08)], 10, F_SAND, m=Matrix.Translation((sx * 1.60, y, 0.0)), caps=False)
            # galvanised fixing plate at the post head (bearer bolted through), two bolts
            xp = sx * (1.675 + 0.003)
            g.box((xp, y, 2.78), (0.006, 0.13, 0.30), F_STEEL)
            for zb in (2.68, 2.88):
                bolt(g, (xp + sx * 0.003, y, zb), (sx, 0, 0), simple=True)
        # X bracing on the outer faces of the side frames, bolted at the ends and the crossing
        xo, xo2 = sx * 1.6925, sx * 1.7275
        for ya, yb in ((posts_y[0], posts_y[1]), (posts_y[1], posts_y[2])):
            for xx, p0, p1 in ((xo, (ya, 0.30), (yb, 2.50)), (xo2, (ya, 2.50), (yb, 0.30))):
                a, b = Vector((xx, p0[0], p0[1])), Vector((xx, p1[0], p1[1]))
                g.bbeam(a, b, 0.14, 0.035, F_BRACE, up=(1, 0, 0), bev=0.007)
                dvec = (b - a).normalized()
                for e in (a + dvec * 0.07, b - dvec * 0.07):
                    bolt(g, (xx + sx * 0.0175, e.y, e.z), (sx, 0, 0))
            bolt(g, (xo2 + sx * 0.0175, (ya + yb) / 2, 1.40), (sx, 0, 0))
        g.bbox((sx * 1.49, (dy0 + dy1) / 2, DECK - 0.14), (0.07, dy1 - dy0, 0.20), F_BEARER, 0.01, axis=1)
    for yb, sy in ((-2.2925, -1), (1.7425, 1)):
        a, b = Vector((-1.60, yb, 0.35)), Vector((1.60, yb, 2.50))
        g.bbeam(a, b, 0.14, 0.035, F_BRACE, up=(0, 1, 0), bev=0.007)
        dvec = (b - a).normalized()
        for e in (a + dvec * 0.07, b - dvec * 0.07):
            bolt(g, (e.x, yb + sy * 0.0175, e.z), (0, sy, 0))
    for y in np.arange(dy0 + 0.05, dy1, 0.45):
        g.bbox((0.0, float(y), DECK - 0.115), (3.10, 0.05, 0.15), F_JOIST, 0.008, axis=0)
    bw = (dx1 - dx0) / DECK_N
    for i in range(DECK_N):
        g.bbox((dx0 + bw * (i + 0.5), (dy0 + dy1) / 2, DECK - 0.0175), (bw - 0.006, dy1 - dy0, 0.035), F_DECK, 0.005, axis=1)
    for yb in (dy0 - 0.013, dy1 + 0.013):
        g.bbox((0.0, yb, DECK - 0.10), (dx1 - dx0 + 0.05, 0.025, 0.18), F_JOIST, 0.006, axis=0)
    for xb in (dx0 - 0.013, dx1 + 0.013):
        g.bbox((xb, (dy0 + dy1) / 2, DECK - 0.10), (0.025, dy1 - dy0, 0.18), F_BEARER, 0.006, axis=1)
    # guard rail round the lookout deck: posts, handrail, bottom rail, balusters at 120 mm
    rx, ry0, ry1 = 1.66, -2.26, 1.71
    sxa, sxb = STAIR_X[0] - 0.04, STAIR_X[1] + 0.04
    posts = [(-rx, y) for y in (ry0, -1.35, -0.30, 0.70, ry1)] + [(rx, y) for y in (ry0, -1.35, -0.30, 0.70, ry1)]
    posts += [(-0.55, ry0), (sxa, ry0), (sxb, ry0), (0.0, ry1)]
    for x, y in posts:
        g.bbox((x, y, DECK + 0.52), (0.08, 0.08, 1.04), F_RAIL, 0.01, axis=2)
    runs = [((-rx, ry0), (-rx, ry1)), ((rx, ry0), (rx, ry1)), ((-rx, ry1), (rx, ry1)), ((-rx, ry0), (sxa, ry0)), ((sxb, ry0), (rx, ry0))]
    for (ax, ay), (bx, by) in runs:
        g.bbeam((ax, ay, DECK + 1.02), (bx, by, DECK + 1.02), 0.10, 0.045, F_RAIL, bev=0.012)
        g.bbeam((ax, ay, DECK + 0.10), (bx, by, DECK + 0.10), 0.07, 0.035, F_RAIL, bev=0.006)
        L = math.hypot(bx - ax, by - ay)
        n = int(L / 0.12)
        for k in range(1, n):
            t = k / n
            px, py = ax + (bx - ax) * t, ay + (by - ay) * t
            if min(math.hypot(px - qx, py - qy) for qx, qy in posts) < 0.07:
                continue
            g.box((px, py, DECK + 0.56), (0.032, 0.032, 0.88), F_RAIL)
    # steps to the sand: stringers, 14 treads, handrails, newels, sole plate
    sx0, sx1 = STAIR_X
    rise = DECK / 15.0
    run = (dy0 - STAIR_FOOT_Y) / 15.0
    for x in (sx0 + 0.03, sx1 - 0.03):
        g.bbeam((x, dy0 + 0.02, DECK - 0.05), (x, STAIR_FOOT_Y + 0.10, 0.13), 0.24, 0.05, F_BEARER, up=(1, 0, 0), bev=0.008)
    for i in range(1, 15):
        g.bbox(((sx0 + sx1) / 2, dy0 - run * i, DECK - rise * i - 0.02), (sx1 - sx0 - 0.02, 0.22, 0.035), F_STAIR, 0.007, axis=0)
    for x in (sx0 - 0.01, sx1 + 0.01):
        g.bbeam((x, dy0, DECK + 1.0), (x, STAIR_FOOT_Y + 0.08, 1.0), 0.07, 0.045, F_RAIL, bev=0.01)
        g.bbox((x, STAIR_FOOT_Y + 0.08, 0.5), (0.08, 0.08, 1.0), F_RAIL, 0.01, axis=2)
    g.bbox(((sx0 + sx1) / 2, STAIR_FOOT_Y + 0.05, 0.03), (sx1 - sx0 + 0.20, 0.30, 0.06), F_BEARER, 0.008, axis=0)
    # flagpole on the front-left corner post, clamps, finial, halyard and cleat, red-over-yellow flag
    px, py = POLE
    g.lathe([(0.0, 0.30), (0.04, 0.30), (0.035, POLE_TOP), (0.0, POLE_TOP)], 12, F_POLE, m=Matrix.Translation((px, py, 0.0)))
    g.lathe([(0.0, POLE_TOP - 0.01)] + [(0.06 * math.sin(t), POLE_TOP + 0.06 - 0.06 * math.cos(t)) for t in np.linspace(0.2, math.pi, 7)],
            12, F_POLE, m=Matrix.Translation((px, py, 0.0)))
    for z in (1.0, 2.4, 3.6):
        g.beam((px, py, z), (-1.60, -2.20, z), 0.05, 0.05, F_RACK)
        g.lathe([(0.046, -0.04), (0.046, 0.04)], 12, F_RACK, m=Matrix.Translation((px, py, z)))
    g.box((px + 0.05, py, 1.25), (0.03, 0.03, 0.16), F_RACK)
    for off in (0.012, -0.012):
        g.tube((px - 0.05, py + off, POLE_TOP - 0.05), (px + 0.065, py + off, 1.30), 0.004, 3, F_ROPE, caps=False)
    flag(g, px - 0.05, py, FLAG[0], FLAG[1], FLAG[2], F_FLAG)
    # rescue board rack on the left side rail, the board, its handles and a webbing strap
    b = BOARD
    for y in (-1.35, 0.70):
        g.box((-1.86, y, b["z"] - 0.03), (0.42, 0.05, 0.04), F_RACK)
        g.beam((-1.70, y, b["z"] - 0.30), (-2.02, y, b["z"] - 0.05), 0.04, 0.03, F_RACK, up=(0, 1, 0))
        g.box((-2.08, y, b["z"] + 0.04), (0.03, 0.05, 0.16), F_RACK)
    board(g, b["x"], b["y0"], b["L"], b["z"], F_BOARD)
    for t in (0.25, 0.42, 0.60):
        for sx in (-1, 1):
            g.box((b["x"] + sx * 0.27, b["y0"] + b["L"] * t, b["z"] + 0.05), (0.03, 0.16, 0.035), F_STRAP)
    g.box((b["x"], -0.30, b["z"] + 0.115), (0.56, 0.05, 0.006), F_STRAP)
    return g


# ------------------------------------------------------------------ maps

def grain(c, stretch, seed):
    """Wood grain streaks along the member axis (stretch small on that axis): 0..1 dark lines, plus checks (cracks)."""
    w = fbm(c.pos, 1.6, seed, 3, stretch=stretch)
    lines = 0.5 + 0.5 * np.sin(70.0 * w + 4.0 * fbm(c.pos, 9.0, seed + 1, 2, stretch=stretch))
    dark = ss(0.55, 0.95, lines)
    check = ss(0.012, 0.0, np.abs(fbm(c.pos, 3.0, seed + 2, 3, stretch=stretch) - 0.5)) * ss(0.45, 0.7, fbm(c.pos, 2.0, seed + 3, 2))
    return dark, check


def grey_timber(c, stretch, seed, shade=1.0):
    """Salt-bleached silver-grey timber, browner where sheltered (undersides, low AO), grain streaks and checks."""
    n = c.n
    wood = tri(scan("wood_peeling_paint_weathered", "rough"), c.pos, c.nrm, 0.9)[:, 0]
    dark, check = grain(c, stretch, seed)
    silver = col((0.60, 0.59, 0.55), n)
    brown = col((0.42, 0.37, 0.30), n)
    shelter = np.clip(0.6 * ss(0.0, -0.8, c.nrm[:, 2]) + 0.6 * ss(0.85, 0.45, c.ao), 0, 1)
    a = mix(silver, brown, 0.75 * shelter)
    a = a * (0.86 + 0.16 * (wood - 0.5) + 0.12 * fbm(c.pos, 2.0, seed + 5, 2))[:, None]
    a = mix(a, a * np.array([0.62, 0.60, 0.57], np.float32), 0.55 * dark)
    a = mix(a, col((0.12, 0.11, 0.10), n), 0.85 * check)
    a = a * shade
    rgh = 0.80 + 0.08 * dark + 0.1 * check
    hgt = -0.0006 * dark - 0.002 * check + 0.0008 * (wood - 0.5)
    return a, rgh, hgt


def flaking(c, f, base, under, seed):
    """Paint `base` over `under` (grey timber) by the loss field f: crisp flakes with a dark lifted rim. Returns
    albedo, painted mask (1 = paint), rim."""
    loss = ss(0.735, 0.75, f)
    rim = ss(0.715, 0.735, f) * (1.0 - loss)
    a = mix(base, under, loss)
    a = mix(a, a * 0.62, 0.55 * rim)
    return a, 1.0 - loss, rim


def wall_coords(c):
    """Per texel on the cladding: wall index (WALLS order), along-wall coordinate and distance to the board end (m)."""
    x0, x1, y0, y1 = CAB
    d = np.stack([np.abs(c.y - y0), np.abs(c.y - y1), np.abs(c.x - x0), np.abs(c.x - x1)], 1)
    w = np.argmin(d, 1)
    a = np.where(w < 2, c.x, c.y)
    row_c = DECK + (np.floor((c.z - DECK) / BH) + 0.5) * BH
    end = np.full(c.n, 9.0, np.float32)
    for wi, (_, out, cc, axis, span, holes) in enumerate(WALLS):
        e = np.minimum(np.abs(a - span[0]), np.abs(a - span[1]))
        for h in holes:
            inrow = (row_c > h[2]) & (row_c < h[3])
            e = np.where(inrow, np.minimum(e, np.minimum(np.abs(a - h[0]), np.abs(a - h[1]))), e)
        end = np.where(w == wi, e, end)
    return w, a, end


def droppings(c, mask, seed, dens=0.76):
    return ss(dens, dens + 0.03, fbm(c.pos, 11.0, seed, 2)) * mask


def paint_hut(c):
    n = c.n
    z, x, y = c.z, c.x, c.y
    alb = col((0.5, 0.5, 0.5), n)
    rgh = np.full(n, 0.6, np.float32)
    met = np.zeros(n, np.float32)
    hgt = np.zeros(n, np.float32)
    sig = np.zeros(n, np.float32)
    up = ss(0.55, 0.8, c.nrm[:, 2])
    wood = tri(scan("wood_peeling_paint_weathered"), c.pos, c.nrm, 1.1)
    streak = fbm(c.pos, 4.0, 101, 3, stretch=(5.0, 5.0, 0.2))
    weather = fbm(c.pos, 0.9, 102, 2)
    blast = ss(3.6, DECK, z)                                       # sand-blast and splash at the foot of the walls
    w, a_al, end = wall_coords(c)
    along_x = (w < 2)
    st_x, st_y = (0.10, 3.0, 3.0), (3.0, 0.10, 3.0)
    tim_x = grey_timber(c, st_x, 105)
    tim_y = grey_timber(c, st_y, 105)
    timber = [np.where(along_x[:, None], tim_x[0], tim_y[0]), np.where(along_x, tim_x[1], tim_y[1]),
              np.where(along_x, tim_x[2], tim_y[2])]
    fl_x = fbm(c.pos, 6.0, 107, 4, stretch=(0.35, 1.6, 1.6))
    fl_y = fbm(c.pos, 6.0, 107, 4, stretch=(1.6, 0.35, 1.6))
    flk = np.where(along_x, fl_x, fl_y)

    # ---- weatherboards: red over yellow gloss, flaking at the lap edges and the board ends to grey timber
    clad = c.is_(H_CLAD)
    k = np.floor((z - DECK) / BH)
    q = np.clip(((z - DECK) / BH) - k, 0, 1)
    seg = np.floor((a_al + 3.0) / 0.95)
    ph = hash3(np.stack([k, w.astype(np.float32), seg], 1), 5)
    yellow = k < YELLOW_ROWS
    paint = np.where(yellow[:, None], tone(wood, (0.86, 0.66, 0.13), 0.22), tone(wood, (0.60, 0.115, 0.09), 0.22))
    paint = paint * (0.93 + 0.12 * ph)[:, None]
    fade = ss(0.45, 0.8, weather) * 0.5 + 0.25 * ph * (ph > 0.75)
    paint = mix(paint, paint * 0.8 + 0.2 * luma(paint)[:, None] + 0.04, 0.5 * fade)
    edgep = np.maximum(ss(0.035, 0.0, q * BH), 0.6 * ss(0.02, 0.0, (1 - q) * BH))
    endp = ss(0.12, 0.0, end)
    f = flk + 0.28 * endp + 0.16 * edgep + 0.10 * c.edge + 0.08 * (weather - 0.5) + 0.07 * blast + 0.05 * (ph - 0.5)
    a, painted, rim = flaking(c, f, paint, timber[0], 107)
    lap = ss(0.0, 0.10, q)                                        # shadow line under each lap
    a = mix(a, a * 0.70, 0.6 * (1 - lap))
    grime = ss(0.55, 0.80, streak) * (0.3 + 0.7 * ss(5.0, WALL_TOP, z)) + 0.5 * blast * fbm(c.pos, 3.0, 109, 2)
    for wx0, wx1, wz, wi in ((WIN_FRONT[0], WIN_FRONT[1], WIN_FRONT[2], 0), (WIN_L[0], WIN_L[1], WIN_L[2], 2),
                              (WIN_R[0], WIN_R[1], WIN_R[2], 3)):
        under = ss(0.15, 0.0, np.maximum(wx0 - a_al, a_al - wx1)) * ss(wz - 0.9, wz - 0.05, z) * (z < wz) * (w == wi)
        grime = np.maximum(grime, under * (0.4 + 0.6 * streak))
    a = mix(a, a * np.array([0.62, 0.60, 0.55], np.float32), 0.45 * np.clip(grime, 0, 1))
    salt = ss(0.5, 0.8, fbm(c.pos, 8.0, 111, 2)) * blast
    a = mix(a, col((0.80, 0.79, 0.75), n), 0.25 * salt)
    alb = np.where(clad[:, None], a, alb)
    rgh = np.where(clad, mix(timber[1], 0.46 + 0.22 * fade + 0.1 * grime, painted), rgh)
    hgt = np.where(clad, timber[2] * (1 - painted) + 0.0007 * painted + 0.0004 * rim, hgt)
    sig = np.where(clad & (painted > 0.5) & (grime < 0.5), 1.0, sig)

    # ---- white trims (corner boards, architraves, sills, friezes, fascias, brackets): flaking at the arrises
    trim = c.is_(H_TRIM)
    white = tone(wood, (0.84, 0.83, 0.79), 0.25)
    ft = fbm(c.pos, 7.0, 113, 4) + 0.30 * c.edge + 0.10 * (weather - 0.5) + 0.12 * ss(3.4, DECK, z)
    tim_iso = grey_timber(c, (1.0, 1.0, 0.25), 115)
    a, painted_t, rim = flaking(c, ft, white, tim_iso[0], 113)
    a = mix(a, a * np.array([0.66, 0.65, 0.60], np.float32), 0.4 * ss(0.55, 0.85, streak) + 0.3 * c.cavity)
    alb = np.where(trim[:, None], a, alb)
    rgh = np.where(trim, mix(tim_iso[1], 0.5 + 0.1 * c.cavity, painted_t), rgh)
    hgt = np.where(trim, tim_iso[2] * (1 - painted_t) + 0.0007 * painted_t, hgt)

    # ---- door: red planks (vertical grain), worn at the foot, the edges and round the hasp and pull
    door = c.is_(H_DOOR)
    tim_z = grey_timber(c, (3.0, 3.0, 0.10), 117)
    dpaint = tone(wood, (0.58, 0.11, 0.09), 0.22)
    hand = np.exp(-((x - (LEAF[1] - 0.09)) ** 2 + (z - 3.95) ** 2) / 0.02) + np.exp(-((x - (LEAF[1] - 0.06)) ** 2 + (z - HASP_Z) ** 2) / 0.01)
    fd = fbm(c.pos, 6.0, 119, 4, stretch=(1.6, 1.6, 0.35)) + 0.25 * c.edge + 0.22 * ss(3.45, DECK, z) + 0.18 * hand
    a, painted_d, rim = flaking(c, fd, dpaint, tim_z[0], 119)
    a = mix(a, a * np.array([0.68, 0.64, 0.60], np.float32), 0.5 * np.clip(hand, 0, 1) + 0.3 * ss(0.6, 0.85, streak))
    alb = np.where(door[:, None], a, alb)
    rgh = np.where(door, mix(tim_z[1], 0.46, painted_d), rgh)
    hgt = np.where(door, tim_z[2] * (1 - painted_d) + 0.0007 * painted_d, hgt)
    sig = np.where(door & (painted_d > 0.5), 1.0, sig)

    # ---- roof: grey box-profile steel, rusting fixings, droppings, sand in the troughs
    roof = c.is_(H_ROOF)
    rr = ss(0.70, 0.74, fbm(c.pos, 10.0, 121, 3) + 0.3 * c.edge)
    fix = ((x + ROOF_X) / 0.20) % 1.0
    fixing = (np.abs(fix - 0.5) > 0.42) & (((y + 2.0) / 0.6) % 1.0 < 0.03)
    a = tone(tri(scan("metal_plate_02"), c.pos, c.nrm, 1.0), (0.48, 0.50, 0.50), 0.4)
    a = mix(a, col((0.44, 0.27, 0.15), n), np.maximum(rr * 0.8, fixing * 0.9))
    a = mix(a, col((0.66, 0.60, 0.48), n), 0.5 * up * ss(0.4, 0.7, fbm(c.pos, 6.0, 123, 2)))
    drop = droppings(c, up, 125)
    a = mix(a, col((0.86, 0.85, 0.80), n), 0.9 * drop)
    alb = np.where(roof[:, None], a, alb)
    rgh = np.where(roof, 0.48 + 0.3 * rr, rgh)
    hgt = np.where(roof, 0.0015 * drop - 0.0008 * rr, hgt)

    # ---- window frames (white uPVC), glass, the dim interior behind it (also the void behind the door gaps)
    fr = c.is_(H_FRAME)
    a = mix(col((0.88, 0.88, 0.86), n), col((0.55, 0.53, 0.48), n), 0.5 * c.cavity + 0.3 * ss(0.6, 0.85, streak))
    alb = np.where(fr[:, None], a, alb)
    rgh = np.where(fr, 0.36, rgh)
    gl = c.is_(H_GLASS)
    haze = ss(0.35, 0.8, fbm(c.pos, 9.0, 131, 3)) * 0.6 + 0.4 * ss(4.4, 4.0, z)
    alb = np.where(gl[:, None], mix(col((0.30, 0.33, 0.34), n), col((0.70, 0.70, 0.67), n), 0.45 * haze), alb)
    rgh = np.where(gl, 0.05 + 0.3 * haze, rgh)
    it = c.is_(H_INTERIOR)
    shelf = ss(0.05, 0.0, np.abs(((z - 4.0) / 0.35) % 1.0 - 0.5) - 0.42)
    a = col((0.15, 0.145, 0.135), n) * (0.85 + 0.3 * fbm(c.pos, 3.0, 133, 2))[:, None]
    a = mix(a, col((0.30, 0.28, 0.25), n), 0.6 * shelf)
    a = mix(a, col((0.55, 0.16, 0.12), n), 0.7 * ss(0.68, 0.72, fbm(c.pos, 2.0, 135, 2)))   # kit on the shelves
    alb = np.where(it[:, None], a, alb)
    rgh = np.where(it, 0.8, rgh)

    # ---- sign: yellow board, red letters; sun-faded, chipped to grey timber at the edges, letters flaking, a split,
    # rust weeping from the four screws
    sg = c.is_(H_SIGN)
    s = SIGN
    face = c.nrm[:, 1] < -0.7
    u = (x - (s["x"] - s["w"] / 2)) / s["w"]
    vv = ((s["z"] + s["h"] / 2) - z) / s["h"]
    letters = text_sample(mask_img(os.path.join(H6DIR, "text_sign.png")), u, vv) * face
    sfade = ss(0.4, 0.8, fbm(c.pos, 3.0, 141, 3)) * 0.6 + 0.4 * ss(0.6, 0.0, vv)
    yel = mix(col((0.92, 0.75, 0.15), n), col((0.90, 0.82, 0.52), n), 0.45 * sfade)
    redl = mix(col((0.72, 0.11, 0.08), n), col((0.74, 0.36, 0.30), n), 0.35 * sfade)
    lloss = ss(0.70, 0.715, fbm(c.pos, 16.0, 143, 3, stretch=(0.5, 1.5, 1.5)))
    a = mix(yel, redl, letters * (1 - lloss))
    a = mix(a, mix(yel, redl, 0.25) * 0.92, letters * lloss)                 # ghost of the lost letter paint
    de = np.minimum(np.minimum(u, 1 - u) * s["w"], np.minimum(vv, 1 - vv) * s["h"])
    de = np.where(face, de, 0.0)
    fs = fbm(c.pos, 8.0, 145, 4, stretch=(0.35, 1.6, 1.6)) + 0.30 * ss(0.05, 0.0, de) + 0.12 * c.edge
    a, painted_s, rim = flaking(c, fs, a, tim_x[0], 145)
    split = ss(0.004, 0.0, np.abs(z - (s["z"] - 0.035 + 0.012 * fbm(c.pos, 3.0, 147, 2)))) * ss(0.25, 0.4, u) * ss(0.8, 0.62, u)
    a = mix(a, col((0.10, 0.09, 0.08), n), 0.85 * split)
    rust = np.zeros(n, np.float32)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx, cz = s["x"] + sx * (s["w"] / 2 - 0.05), s["z"] + sz * (s["h"] / 2 - 0.06)
            wdt = 0.006 + 0.012 * np.clip(cz - z, 0, 0.3)
            rust = np.maximum(rust, np.exp(-((x - cx) / wdt) ** 2) * ss(0.0, 0.02, cz - z) * ss(0.32, 0.0, cz - z)
                              * ss(0.3, 0.6, fbm(c.pos, 6.0, 149, 2, stretch=(4, 4, 0.3))))
    a = mix(a, col((0.42, 0.22, 0.11), n), 0.75 * rust)
    a = mix(a, a * 0.72, 0.35 * ss(0.6, 0.85, streak))
    alb = np.where(sg[:, None], a, alb)
    rgh = np.where(sg, mix(tim_x[1], 0.42 + 0.18 * sfade, painted_s), rgh)
    hgt = np.where(sg, 0.0004 * letters * (1 - lloss) + tim_x[2] * (1 - painted_s) + 0.0007 * painted_s - 0.002 * split, hgt)
    sig = np.where(sg & (painted_s > 0.5) & (rust < 0.4), 1.0, sig)

    # ---- stainless screws and the padlock shackle (tea staining); black iron hinges, hasp, staple, pull (rust at
    # the edges and bleeding); brass padlock body
    mt = c.is_(H_METAL)
    tea = ss(0.6, 0.75, fbm(c.pos, 25.0, 151, 2))
    alb = np.where(mt[:, None], mix(col((0.78, 0.78, 0.76), n), col((0.55, 0.40, 0.28), n), 0.8 * tea), alb)
    rgh = np.where(mt, 0.3 + 0.4 * tea, rgh)
    ir = c.is_(H_IRON)
    irust = ss(0.62, 0.70, fbm(c.pos, 30.0, 153, 3) + 0.35 * c.edge)
    a = mix(col((0.10, 0.10, 0.10), n), col((0.40, 0.22, 0.11), n), irust)
    alb = np.where(ir[:, None], a, alb)
    rgh = np.where(ir, 0.5 + 0.35 * irust, rgh)
    hgt = np.where(ir, 0.0005 * irust, hgt)
    brs = c.is_(H_BRASS)
    tarn = ss(0.45, 0.75, fbm(c.pos, 40.0, 155, 2)) * (1 - 0.6 * c.edge)
    alb = np.where(brs[:, None], mix(col((0.80, 0.64, 0.38), n), col((0.42, 0.40, 0.28), n), 0.7 * tarn), alb)
    rgh = np.where(brs, 0.3 + 0.35 * tarn, rgh)
    # padlock left dielectric like the other small fittings: a few texels of metal fail the metal albedo range
    return alb, rgh, met, hgt, sig


def barnacles(c, mask, seed, cell=0.028):
    """Acorn barnacles: one per occupied 28 mm cell, jittered cones with a dark operculum. Returns (cover, shell, hole,
    height)."""
    p = c.pos / cell
    ci = np.floor(p)
    occ = hash3(ci, seed) < mask
    ctr = ci + 0.5 + (np.stack([hash3(ci, seed + 1), hash3(ci, seed + 2), hash3(ci, seed + 3)], 1) - 0.5) * 0.3
    rr = 0.20 + 0.15 * hash3(ci, seed + 4)
    d = np.linalg.norm(p - ctr, axis=1) / rr
    cov = (d < 1.0) & occ
    hole = cov & (d < 0.32)
    h = np.where(cov, np.clip(1.0 - d, 0, 1) * (1 - 0.6 * hole), 0.0)
    return cov.astype(np.float32), h, hole.astype(np.float32), h * cell * 0.25


def paint_frame(c):
    n = c.n
    z, x, y = c.z, c.x, c.y
    alb = col((0.5, 0.5, 0.5), n)
    rgh = np.full(n, 0.7, np.float32)
    met = np.zeros(n, np.float32)
    hgt = np.zeros(n, np.float32)
    sig = np.zeros(n, np.float32)
    up = ss(0.55, 0.8, c.nrm[:, 2])
    sandc = tone(tri(scan("damp_beach_sand"), c.pos, c.nrm, 0.8), (0.70, 0.63, 0.50), 0.6)

    # ---- salt-bleached structural timber: grain along each member, rust bleed under bolts and plates, tide mark,
    # sand and barnacles at the feet
    tim = c.is_(F_POST, F_JOIST, F_BEARER, F_BRACE)
    st = np.where(c.is_(F_POST)[:, None], np.array([[3.0, 3.0, 0.10]], np.float32),
                  np.where(c.is_(F_JOIST)[:, None], np.array([[0.10, 3.0, 3.0]], np.float32),
                           np.where(c.is_(F_BEARER)[:, None], np.array([[3.0, 0.10, 3.0]], np.float32),
                                    np.array([[3.0, 0.8, 0.8]], np.float32))))
    a = np.zeros((n, 3), np.float32)
    r = np.zeros(n, np.float32)
    h = np.zeros(n, np.float32)
    for sv in np.unique(st, axis=0):
        m = np.all(st == sv, axis=1)
        if not (m & tim).any():
            continue
        ta, tr, th = grey_timber(c, tuple(float(v) for v in sv), 211)
        a = np.where(m[:, None], ta, a)
        r = np.where(m, tr, r)
        h = np.where(m, th, h)
    bleed = np.zeros(n, np.float32)
    vf = fbm(c.pos, 3.0, 213, 2, stretch=(4, 4, 0.3))
    for bx, by, bz in BOLTS:
        dz = bz - z
        if bz < 0.2:
            continue
        lat = np.sqrt((x - bx) ** 2 + (y - by) ** 2)
        wdt = 0.012 + 0.03 * np.clip(dz, 0, 0.5)
        bleed = np.maximum(bleed, np.exp(-(lat / wdt) ** 2) * ss(-0.02, 0.03, dz) * ss(0.45, 0.05, dz) * ss(0.3, 0.6, vf))
    a = mix(a, col((0.40, 0.22, 0.11), n), 0.7 * bleed)
    tide = ss(0.75, 0.35, z) * (0.6 + 0.4 * fbm(c.pos, 4.0, 215, 2))
    a = mix(a, a * np.array([0.58, 0.60, 0.50], np.float32), 0.65 * tide)
    alg = ss(0.55, 0.15, z) * ss(0.45, 0.7, fbm(c.pos, 5.0, 217, 3))
    a = mix(a, col((0.30, 0.34, 0.22), n), 0.45 * alg)
    sandm = ss(0.5, 0.75, ss(0.28, 0.0, z) * 0.8 + 0.5 * fbm(c.pos, 7.0, 219, 3) * ss(0.4, 0.0, z) + 0.3 * up * ss(1.0, 0.0, z))
    a = mix(a, sandc, sandm)
    bmask = 0.75 * ss(0.48, 0.18, z) * ss(0.35, 0.6, fbm(c.pos, 5.0, 221, 3)) * (1 - sandm)
    cov, shell, hole, bh = barnacles(c, bmask * c.is_(F_POST, F_BRACE), 223)
    bcol = mix(col((0.52, 0.51, 0.47), n), col((0.70, 0.69, 0.64), n), shell)
    bcol = mix(bcol, col((0.16, 0.15, 0.14), n), hole)
    a = np.where((cov > 0.5)[:, None], bcol, a)
    alb = np.where(tim[:, None], a, alb)
    rgh = np.where(tim, np.where(cov > 0.5, 0.75, r + 0.05 * sandm), rgh)
    hgt = np.where(tim, h + bh - 0.0004 * bleed + 0.0008 * sandm, hgt)

    # ---- sand scour collars round the feet
    sd = c.is_(F_SAND)
    ripple = fbm(c.pos, 14.0, 225, 2)
    alb = np.where(sd[:, None], sandc * (0.92 + 0.12 * ripple)[:, None], alb)
    rgh = np.where(sd, 0.85, rgh)
    hgt = np.where(sd, 0.001 * ripple, hgt)

    # ---- galvanised plates and bolt heads: zinc spangle, white rust, red rust at the arrises
    stl = c.is_(F_STEEL)
    zinc = ss(0.5, 0.75, fbm(c.pos, 40.0, 227, 2))
    rs = ss(0.66, 0.72, fbm(c.pos, 35.0, 229, 3) + 0.3 * c.edge)
    a = mix(col((0.62, 0.63, 0.62), n), col((0.80, 0.80, 0.77), n), 0.6 * zinc)
    a = mix(a, col((0.40, 0.22, 0.11), n), 0.85 * rs)
    alb = np.where(stl[:, None], a, alb)
    rgh = np.where(stl, 0.5 + 0.2 * zinc + 0.25 * rs, rgh)

    # ---- deck boards along Y, screw pairs at every joist, sand in the corners, wear path from the steps; treads
    dk = c.is_(F_DECK, F_STAIR)
    bw = (DECK_XY[1] - DECK_XY[0]) / DECK_N
    bpos = (x - DECK_XY[0]) / bw
    bt = hash3(np.stack([np.floor(bpos), np.zeros(n), np.zeros(n)], 1), 7)
    stretch = np.where(c.is_(F_DECK)[:, None], np.array([[3.0, 0.10, 3.0]], np.float32), np.array([[0.10, 3.0, 3.0]], np.float32))
    ta, tr, th = grey_timber(c, (3.0, 0.10, 3.0), 231)
    tb, trb, thb = grey_timber(c, (0.10, 3.0, 3.0), 231)
    isd = stretch[:, 1] < 1.0
    a = np.where(isd[:, None], ta, tb) * (0.92 + 0.14 * bt)[:, None]
    r = np.where(isd, tr, trb)
    h = np.where(isd, th, thb)
    jy = ((y - (DECK_XY[2] + 0.05)) / 0.45) % 1.0
    jd = np.minimum(jy, 1 - jy) * 0.45
    sdist = np.minimum(np.abs((bpos % 1.0) - 0.25), np.abs((bpos % 1.0) - 0.75)) * bw
    screw = ss(0.007, 0.004, np.sqrt(jd ** 2 + sdist ** 2)) * up * c.is_(F_DECK)
    halo = ss(0.02, 0.006, np.sqrt(jd ** 2 + sdist ** 2)) * up * c.is_(F_DECK)
    a = mix(a, col((0.44, 0.30, 0.20), n), 0.4 * halo)
    a = mix(a, col((0.30, 0.30, 0.30), n), screw)
    path = ss(0.6, 0.0, np.abs(x - 0.9) - 0.3) * ss(-0.8, -2.3, y) * up
    a = mix(a, a * 1.10, 0.5 * path)
    corner = (ss(1.2, 1.66, np.abs(x)) + ss(1.2, 1.7, np.abs(y + 0.3))) * up
    a = mix(a, sandc, 0.6 * ss(0.4, 0.8, corner * fbm(c.pos, 5.0, 233, 2) * 1.4 + 0.3 * path))
    tr_ = c.is_(F_STAIR) & (c.nrm[:, 2] > 0.7)
    nose = ((y - DECK_XY[2]) / ((DECK_XY[2] - STAIR_FOOT_Y) / 15.0)) % 1.0
    grit = tr_ & (nose > 0.55) & (nose < 0.85) & (x > STAIR_X[0] + 0.06) & (x < STAIR_X[1] - 0.06)
    a = np.where(grit[:, None], col((0.20, 0.20, 0.19), n) * (0.8 + 0.4 * fbm(c.pos, 40.0, 235, 1))[:, None], a)
    alb = np.where(dk[:, None], a, alb)
    rgh = np.where(dk, np.where(grit, 0.95, r), rgh)
    hgt = np.where(dk, h + 0.0008 * screw + 0.0015 * grit, hgt)

    # ---- white painted rails and balusters, flaking to grey timber on the arrises and where hands go
    rl = c.is_(F_RAIL)
    ta, tr, th_ = grey_timber(c, (1.0, 1.0, 0.3), 237)
    fr_ = fbm(c.pos, 7.0, 239, 4) + 0.28 * c.edge + 0.18 * up * ss(DECK + 0.9, DECK + 1.05, z)
    a, painted_r, rim = flaking(c, fr_, tone(tri(scan("wood_peeling_paint_weathered"), c.pos, c.nrm, 1.1), (0.85, 0.85, 0.81), 0.2), ta, 239)
    a = mix(a, a * 0.72, 0.4 * ss(0.6, 0.85, fbm(c.pos, 4.0, 241, 3, stretch=(4, 4, 0.25))))
    alb = np.where(rl[:, None], a, alb)
    rgh = np.where(rl, mix(tr, 0.52, painted_r), rgh)
    hgt = np.where(rl, th_ * (1 - painted_r) + 0.0007 * painted_r, hgt)

    # ---- pole: white powder-coated aluminium; galvanised rack and clamps
    po = c.is_(F_POLE)
    sc = ss(0.7, 0.75, fbm(c.pos, 16.0, 241, 2))
    alb = np.where(po[:, None], mix(col((0.85, 0.86, 0.85), n), col((0.55, 0.56, 0.56), n), 0.6 * sc + 0.3 * ss(1.2, 0.3, z)), alb)
    rgh = np.where(po, 0.35 + 0.2 * sc, rgh)
    rk = c.is_(F_RACK)
    zinc = ss(0.55, 0.75, fbm(c.pos, 18.0, 243, 3))
    rust = ss(0.74, 0.78, fbm(c.pos, 22.0, 245, 2) + 0.2 * c.edge)
    a = mix(col((0.73, 0.74, 0.73), n), col((0.86, 0.86, 0.84), n), 0.6 * zinc)
    a = mix(a, col((0.46, 0.28, 0.15), n), rust)
    alb = np.where(rk[:, None], a, alb)
    rgh = np.where(rk, 0.42 + 0.3 * zinc + 0.3 * rust, rgh)

    # ---- flag: red over yellow nylon, weave, fraying edge darkening; signal
    fg = c.is_(F_FLAG)
    mid = (FLAG[0] + FLAG[1]) / 2 - 0.06 * ((POLE[0] - x) / FLAG[2]) ** 2
    weave = 0.95 + 0.06 * fbm(c.pos, 120.0, 251, 1)
    a = np.where((z > mid)[:, None], col((0.80, 0.13, 0.10), n), col((0.95, 0.78, 0.12), n)) * weave[:, None]
    fray = ss(0.70, 0.88, (POLE[0] - x) / FLAG[2])
    a = mix(a, a * 0.78, 0.5 * fray * fbm(c.pos, 30.0, 253, 2))
    alb = np.where(fg[:, None], a, alb)
    rgh = np.where(fg, 0.85, rgh)
    sig = np.where(fg, 1.0, sig)

    # ---- rescue board: yellow soft deck, red rails, scuffs and sand; signal
    bd = c.is_(F_BOARD)
    rail = np.abs(c.nrm[:, 2]) < 0.55
    foam = fbm(c.pos, 30.0, 261, 2)
    a = np.where(rail[:, None], col((0.80, 0.15, 0.11), n), col((0.95, 0.78, 0.14), n)) * (0.95 + 0.07 * foam)[:, None]
    sc = ss(0.68, 0.74, fbm(c.pos, 14.0, 263, 3))
    a = mix(a, a * np.array([0.75, 0.72, 0.66], np.float32), 0.6 * sc)
    a = mix(a, sandc, 0.4 * up * ss(0.6, 0.8, fbm(c.pos, 9.0, 265, 2)))
    alb = np.where(bd[:, None], a, alb)
    rgh = np.where(bd, 0.6 + 0.15 * sc, rgh)
    hgt = np.where(bd, 0.0006 * foam - 0.0008 * sc, hgt)
    sig = np.where(bd & (sc < 0.5), 1.0, sig)

    # ---- halyard (white braid), handles and strap (black webbing)
    rp = c.is_(F_ROPE)
    alb = np.where(rp[:, None], col((0.80, 0.80, 0.76), n) * (0.85 + 0.2 * fbm(c.pos, 60.0, 271, 1))[:, None], alb)
    rgh = np.where(rp, 0.85, rgh)
    stp = c.is_(F_STRAP)
    alb = np.where(stp[:, None], col((0.15, 0.15, 0.155), n) * (0.9 + 0.2 * fbm(c.pos, 80.0, 273, 1))[:, None], alb)
    rgh = np.where(stp, 0.8, rgh)
    return alb, rgh, met, hgt, sig


# ------------------------------------------------------------------ spec

def build():
    S = h6lib.S
    hero = [(H_SIGN, (0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.004, 0.942, 0.874, 0.998))]
    meshes = h6lib.make_set(NAME, "Hut", hut_geo(), TEX, 2048, paint_hut, splits=[([H_GLASS], "Glass")],
                            heroes=hero, squeeze=0.94)
    meshes += h6lib.make_set(NAME, "Frame", frame_geo(), TEX, 2048, paint_frame)
    dx0, dx1, dy0, dy1 = DECK_XY
    stair_len = math.hypot(dy0 - STAIR_FOOT_Y, DECK)
    col_ = h6lib.col_boxes(NAME + "_COL", [
        ((0.0, (dy0 + dy1) / 2, DECK - 0.12), (dx1 - dx0, dy1 - dy0, 0.24), 0.0, 0.0),
        ((0.0, 0.1, (DECK + ROOF_FRONT) / 2), (3.1, 3.1, ROOF_FRONT - DECK + 0.1), 0.0, 0.0),
        ((sum(STAIR_X) / 2, (dy0 + STAIR_FOOT_Y) / 2, DECK / 2), (STAIR_X[1] - STAIR_X[0], stair_len, 0.12), 0.0,
         math.atan2(DECK, dy0 - STAIR_FOOT_Y)),
        ((-1.66, (dy0 + dy1) / 2, DECK + 0.55), (0.1, dy1 - dy0, 1.1), 0.0, 0.0),
        ((1.66, (dy0 + dy1) / 2, DECK + 0.55), (0.1, dy1 - dy0, 1.1), 0.0, 0.0),
        ((-0.55, dy0 + 0.04, DECK + 0.55), (2.2, 0.1, 1.1), 0.0, 0.0),
    ] + [((sx * 1.6, y, DECK / 2), (0.16, 0.16, DECK), 0.0, 0.0) for sx in (-1, 1) for y in (-2.2, -0.3, 1.65)]
      + [((POLE[0], POLE[1], POLE_TOP / 2), (0.08, 0.08, POLE_TOP), 0.0, 0.0)])
    h6lib.make_lods({"budget": "hero_building", "tris": 12000, "meshes": meshes})
    meshes.append({"object": col_})
    atts = [h6lib.empty("ATT_Door", ((DOOR[0] + DOOR[1]) / 2, CAB[2] - 0.45, DECK)),
            h6lib.empty("ATT_Flag", (POLE[0] - 0.05, POLE[1], FLAG[1])),
            h6lib.empty("ATT_FlagHoist", (POLE[0] + 0.05, POLE[1], 1.25)),
            h6lib.empty("ATT_BoardRack", (BOARD["x"], BOARD["y0"] + BOARD["L"] / 2, BOARD["z"] + 0.12)),
            h6lib.empty("ATT_Lookout", (-0.6, -1.95, DECK)),
            h6lib.empty("ATT_StairsFoot", (sum(STAIR_X) / 2, STAIR_FOOT_Y - 0.4, 0.0)),
            h6lib.empty("ATT_Sign", (SIGN["x"], SIGN["y"] - 0.02, SIGN["z"]))]
    lo, hi = h6lib.bbox_m(meshes[:-1])
    print("[H6] %s bbox m %s..%s tris %s" % (NAME, [round(v, 2) for v in lo], [round(v, 2) for v in hi],
                                              [(e["object"].name, h6lib.tris(e["object"])) for e in meshes]))
    return {
        "name": NAME, "budget": "hero_building", "tris": 12000, "tier": "standard",
        "dims_m": (4.54, 6.64, 8.12), "origin": "free",
        "sets": [{"name": TEX, "set": "Hut", "size": 2048, "wet": True},
                 {"name": TEX, "set": "Frame", "size": 2048, "wet": True}],
        "meshes": meshes, "attachments": atts,
        "closeups": [{"name": "sign_door", "target": [0.3 * S, -1.5 * S, 4.6 * S], "dist": 10.0, "az": 15, "el": 5},
                     {"name": "door_hardware", "target": [1.15 * S, -1.45 * S, 4.1 * S], "dist": 3.0, "az": 20, "el": 5},
                     {"name": "feet", "target": [1.6 * S, -2.2 * S, 0.5 * S], "dist": 5.0, "az": 60, "el": 10},
                     {"name": "board_rack", "target": [-1.9 * S, -0.3 * S, 3.6 * S], "dist": 7.0, "az": 280, "el": 15},
                     {"name": "flag", "target": [-2.2 * S, -2.36 * S, 7.6 * S], "dist": 7.0, "az": 10, "el": 0},
                     {"name": "steps", "target": [1.0 * S, -3.3 * S, 1.6 * S], "dist": 9.0, "az": 40, "el": 10},
                     {"name": "deck", "target": [0.6 * S, -1.9 * S, 3.1 * S], "dist": 6.0, "az": 20, "el": 40}],
        "waivers": {"texel density": "2 sets per the docs/12 2.2 row at 2048 (EXPORT_CAP shipping size until Spike 1): Hut 28, Frame 30, glass 25 px/stud; standard 51 needs 4096 or more sets. Lettering faces (LIFEGUARDS sign) get their own UV rect at about 150 px/stud; wear reads at 2 m (contact sheet)",
                    "texture sets": "docs/12 2.2 row: 2 sets (Hut, Frame; glazing is a MeshPart on Hut); "
                                    "hero_building class asks 4-5",
                    "LOD UV layout": "collapse decimation of rails, treads, halyard and fittings drops small UV islands "
                                     "at LOD1/LOD2 (UV bounds unchanged); kept faces keep the LOD0 UVs and set"},
    }
