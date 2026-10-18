"""M_Bld_LifeguardTower (docs/12 2.2, batch H6): the beach lifeguard hut on Haven Sands.

A raised timber hut: six treated-timber posts with X-bracing in the sand, bearers, joists and a boarded deck 3.0 m up,
a 3.0 x 3.0 m cabin in white-painted shiplap with red trims, a lookout window, side windows, a red door, a shallow
mono-pitch box-profile steel roof with a gutter and downpipe, a fascia sign "LIFEGUARDS" (generic, no RNLI marks), a
guard rail round the deck, steep timber steps to the sand, a red-over-yellow patrol flag on a white pole (ATT_Flag), and a
galvanised rack on the side rail holding a yellow / red rescue board. Shared pipeline: ../H6/h6lib.py.
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_LifeguardTower --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "H6"))
import h6lib  # noqa: E402
from h6lib import Geo  # noqa: E402
from h6tex import col, fbm, hash3, luma, mask_img, mix, scan, ss, text_sample, tone, tri, HERE as H6DIR  # noqa: E402

NAME = "M_Bld_LifeguardTower"
TEX = "LifeguardTower"
H_CLAD, H_TRIM, H_ROOF, H_DOOR, H_FRAME, H_SIGN, H_GLASS, H_METAL, H_INTERIOR = range(9)
F_POST, F_DECK, F_RAIL, F_STAIR, F_POLE, F_FLAG, F_BOARD, F_RACK, F_ROPE, F_STRAP = range(10)

DECK = 3.0
CAB = (-1.5, 1.5, -1.4, 1.6)                  # cabin x0, x1, y0, y1
DECK_XY = (-1.7, 1.7, -2.3, 1.75)
WALL_TOP = 5.62
ROOF_FRONT, ROOF_BACK = 5.78, 5.64
STAIR_X = (0.55, 1.45)
STAIR_FOOT_Y = -4.45
POLE = (-1.80, -2.36)
POLE_TOP = 8.0
FLAG = (7.30, 7.90, 0.90)                     # hoist bottom, top, fly length
SIGN = {"x": 0.0, "z": 5.33, "w": 2.60, "h": 0.36, "y": -1.47}
BOARD = {"x": -1.99, "y0": -1.85, "L": 2.90, "z": 3.52}
WIN_FRONT = (-1.30, 0.10, 4.00, 5.05)
DOOR = (0.47, 1.28, DECK, 5.03)


def wall(g, axis, c, th, a0, a1, z0, z1, holes, part):
    """Wall slab perpendicular to `axis` ('x' or 'y') at coordinate c, spanning a0..a1 along the other horizontal axis
    and z0..z1, with rectangular holes [(a0, a1, z0, z1)], as a grid of boxes."""
    As = sorted({a0, a1} | {h[0] for h in holes} | {h[1] for h in holes})
    Zs = sorted({z0, z1} | {h[2] for h in holes} | {h[3] for h in holes})
    for i in range(len(As) - 1):
        for j in range(len(Zs) - 1):
            ca, cz = (As[i] + As[i + 1]) / 2, (Zs[j] + Zs[j + 1]) / 2
            if any(h[0] <= ca <= h[1] and h[2] <= cz <= h[3] for h in holes):
                continue
            da, dz = As[i + 1] - As[i], Zs[j + 1] - Zs[j]
            if axis == "y":
                g.box((ca, c, cz), (da, th, dz), part)
            else:
                g.box((c, ca, cz), (th, da, dz), part)


def window(g, axis, c, out, a0, a1, z0, z1):
    """Frame, mullion, glass and interior panel in a hole of a wall at `c`; out = -1 / +1 outward direction."""
    def b(ca, off, cz, sa, sd, sz, part):
        if axis == "y":
            g.box((ca, c + out * off, cz), (sa, sd, sz), part)
        else:
            g.box((c + out * off, ca, cz), (sd, sa, sz), part)
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
    # sill (red trim) and head trim
    b(am, 0.06, z0 - 0.03, a1 - a0 + 0.16, 0.10, 0.05, H_TRIM)
    b(am, 0.035, z1 + 0.035, a1 - a0 + 0.14, 0.03, 0.07, H_TRIM)


def hut_geo():
    g = Geo()
    x0, x1, y0, y1 = CAB
    th = 0.06
    # cabin walls (shiplap cladding), with the lookout window and door at the front and two side windows
    wall(g, "y", y0, th, x0, x1, DECK, WALL_TOP, [WIN_FRONT, DOOR], H_CLAD)
    wall(g, "y", y1, th, x0, x1, DECK, WALL_TOP, [], H_CLAD)
    side_l = (-0.60, 0.60, 4.10, 4.90)
    side_r = (-0.10, 0.80, 4.10, 4.90)
    wall(g, "x", x0, th, y0 + th / 2, y1 - th / 2, DECK, WALL_TOP, [side_l], H_CLAD)
    wall(g, "x", x1, th, y0 + th / 2, y1 - th / 2, DECK, WALL_TOP, [side_r], H_CLAD)
    window(g, "y", y0, -1, *WIN_FRONT)
    window(g, "x", x0, -1, *side_l)
    window(g, "x", x1, 1, *side_r)
    # corner boards, skirting and frieze in red trim
    for cx in (x0, x1):
        for cy in (y0, y1):
            g.box((cx + 0.02 * np.sign(cx), cy + 0.02 * np.sign(cy), (DECK + WALL_TOP) / 2), (0.13, 0.13, WALL_TOP - DECK), H_TRIM)
    for z, hgt in ((DECK + 0.07, 0.14), (WALL_TOP - 0.08, 0.16)):
        g.box((0.0, y1 + 0.035, z), (x1 - x0, 0.02, hgt), H_TRIM)
        g.box((x0 - 0.035, (y0 + y1) / 2, z), (0.02, y1 - y0, hgt), H_TRIM)
        g.box((x1 + 0.035, (y0 + y1) / 2, z), (0.02, y1 - y0, hgt), H_TRIM)
    g.box(((x0 + DOOR[0]) / 2 - 0.30, y0 - 0.035, DECK + 0.07), (DOOR[0] - x0 - 0.0, 0.02, 0.14), H_TRIM)
    # door leaf, architrave, lever handle, hinges, kick plate
    dx0, dx1, dz0, dz1 = DOOR
    g.box(((dx0 + dx1) / 2, y0 + 0.01, (dz0 + dz1) / 2), (dx1 - dx0, 0.045, dz1 - dz0), H_DOOR)
    for a in (dx0 - 0.035, dx1 + 0.035):
        g.box((a, y0 - 0.04, (dz0 + dz1) / 2 + 0.035), (0.07, 0.025, dz1 - dz0 + 0.07), H_TRIM)
    g.box(((dx0 + dx1) / 2, y0 - 0.04, dz1 + 0.035), (dx1 - dx0 + 0.14, 0.025, 0.07), H_TRIM)
    g.box((dx1 - 0.10, y0 - 0.035, 4.00), (0.06, 0.012, 0.16), H_METAL)
    g.box((dx1 - 0.14, y0 - 0.06, 4.03), (0.13, 0.025, 0.022), H_METAL)
    for zh in (3.25, 4.10, 4.80):
        g.box((dx0 + 0.04, y0 - 0.02, zh), (0.06, 0.012, 0.10), H_METAL)
    g.box(((dx0 + dx1) / 2, y0 - 0.017, DECK + 0.12), (dx1 - dx0 - 0.04, 0.004, 0.22), H_METAL)
    # sign board on the fascia above the window and door
    s = SIGN
    g.box((s["x"], s["y"], s["z"]), (s["w"], 0.035, s["h"]), H_SIGN)
    for sx in (-1, 1):
        for sz in (-1, 1):
            g.box((s["x"] + sx * (s["w"] / 2 - 0.05), s["y"] - 0.02, s["z"] + sz * (s["h"] / 2 - 0.05)), (0.022, 0.008, 0.022), H_METAL)
    # mono-pitch box-profile roof with overhangs, fascias, gutter and downpipe
    ry0, ry1 = y0 - 0.35, y1 + 0.35
    pitch = math.atan2(ROOF_FRONT - ROOF_BACK, ry1 - ry0)
    g.boxr((0.0, (ry0 + ry1) / 2, (ROOF_FRONT + ROOF_BACK) / 2 + 0.03), (3.52, (ry1 - ry0) / math.cos(pitch), 0.05), H_ROOF, 0.0, pitch=-pitch)
    for i in range(18):
        x = -1.70 + i * 0.20
        g.beam((x, ry0 - 0.005, ROOF_FRONT + 0.065), (x, ry1 + 0.005, ROOF_BACK + 0.065), 0.035, 0.03, H_ROOF)
    g.box((0.0, ry0 - 0.015, ROOF_FRONT - 0.04), (3.56, 0.03, 0.20), H_TRIM)
    g.box((0.0, ry1 + 0.015, ROOF_BACK - 0.04), (3.56, 0.03, 0.18), H_TRIM)
    for sx in (-1, 1):
        g.beam((sx * 1.775, ry0, ROOF_FRONT - 0.04), (sx * 1.775, ry1, ROOF_BACK - 0.04), 0.03, 0.19, H_TRIM, up=(0, 0, 1))
    # soffit under the overhangs
    g.box((0.0, (ry0 + y0) / 2, ROOF_FRONT - 0.12), (3.5, 0.35, 0.02), H_TRIM)
    g.box((0.0, (ry1 + y1) / 2, ROOF_BACK - 0.12), (3.5, 0.35, 0.02), H_TRIM)
    gut = [(x, ry1 + 0.08, ROOF_BACK - 0.06) for x in np.linspace(-1.76, 1.76, 2)]
    g.lathe([(0.0, 0.0), (0.06, 0.0), (0.06, 3.52), (0.0, 3.52)], 8, H_ROOF,
            m=__import__("mathutils").Matrix.Translation(gut[0]) @ __import__("mathutils").Matrix.Rotation(math.pi / 2, 4, "Y"))
    g.tube((1.60, ry1 + 0.08, ROOF_BACK - 0.08), (1.60, y1 + 0.06, ROOF_BACK - 0.25), 0.035, 8, H_ROOF)
    g.tube((1.60, y1 + 0.06, ROOF_BACK - 0.25), (1.60, y1 + 0.06, DECK + 0.10), 0.035, 8, H_ROOF)
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


def frame_geo():
    g = Geo()
    dx0, dx1, dy0, dy1 = DECK_XY
    posts_y = (-2.20, -0.30, 1.65)
    for sx in (-1, 1):
        for y in posts_y:
            g.box((sx * 1.60, y, (DECK - 0.04) / 2), (0.15, 0.15, DECK - 0.04), F_POST)
        # X bracing on the outer faces of the side frames
        for ya, yb in ((posts_y[0], posts_y[1]), (posts_y[1], posts_y[2])):
            xo = sx * 1.70
            g.beam((xo, ya + 0.08, 0.35), (xo, yb - 0.08, 2.65), 0.14, 0.035, F_POST, up=(1, 0, 0))
            g.beam((xo + sx * 0.035, ya + 0.08, 2.65), (xo + sx * 0.035, yb - 0.08, 0.35), 0.14, 0.035, F_POST, up=(1, 0, 0))
        g.box((sx * 1.60, (dy0 + dy1) / 2, DECK - 0.14), (0.10, dy1 - dy0, 0.20), F_POST)
    for yb in (-2.29, 1.74):
        g.beam((-1.48, yb, 0.40), (1.48, yb, 2.60), 0.14, 0.035, F_POST, up=(0, 1, 0))
    for y in np.arange(dy0 + 0.05, dy1, 0.45):
        g.box((0.0, float(y), DECK - 0.115), (3.10, 0.05, 0.15), F_POST)
    g.box((0.0, (dy0 + dy1) / 2, DECK - 0.02), (dx1 - dx0, dy1 - dy0, 0.04), F_DECK)
    for yb in (dy0 - 0.013, dy1 + 0.013):
        g.box((0.0, yb, DECK - 0.10), (dx1 - dx0 + 0.05, 0.025, 0.18), F_POST)
    for xb in (dx0 - 0.013, dx1 + 0.013):
        g.box((xb, (dy0 + dy1) / 2, DECK - 0.10), (0.025, dy1 - dy0, 0.18), F_POST)
    # guard rail
    rx, ry0, ry1 = 1.66, -2.26, 1.71
    posts = [(-rx, y) for y in (ry0, -1.35, -0.30, 0.70, ry1)] + [(rx, y) for y in (ry0, -1.35, -0.30, 0.70, ry1)]
    posts += [(-0.55, ry0), (STAIR_X[0] - 0.04, ry0), (0.0, ry1)]
    for x, y in posts:
        g.box((x, y, DECK + 0.52), (0.08, 0.08, 1.04), F_RAIL)
    runs = [((-rx, ry0), (-rx, ry1)), ((rx, ry0), (rx, ry1)), ((-rx, ry1), (rx, ry1)), ((-rx, ry0), (STAIR_X[0] - 0.04, ry0))]
    for (ax, ay), (bx, by) in runs:
        for z, w, h in ((DECK + 1.02, 0.10, 0.04), (DECK + 0.52, 0.07, 0.03)):
            g.beam((ax, ay, z), (bx, by, z), w, h, F_RAIL)
    # steps to the sand: stringers, 14 treads, handrails, sole plate
    sx0, sx1 = STAIR_X
    rise = DECK / 15.0
    run = (dy0 - STAIR_FOOT_Y) / 15.0
    for x in (sx0 + 0.03, sx1 - 0.03):
        g.beam((x, dy0 + 0.02, DECK - 0.05), (x, STAIR_FOOT_Y + 0.10, 0.13), 0.24, 0.05, F_STAIR, up=(1, 0, 0))
    for i in range(1, 15):
        g.box(((sx0 + sx1) / 2, dy0 - run * i, DECK - rise * i - 0.02), (sx1 - sx0 - 0.02, 0.22, 0.035), F_STAIR)
    for x in (sx0 - 0.01, sx1 + 0.01):
        g.beam((x, dy0, DECK + 1.0), (x, STAIR_FOOT_Y + 0.08, 1.0), 0.07, 0.045, F_RAIL)
        g.box((x, STAIR_FOOT_Y + 0.08, 0.5), (0.08, 0.08, 1.0), F_RAIL)
    g.box(((sx0 + sx1) / 2, STAIR_FOOT_Y + 0.05, 0.03), (sx1 - sx0 + 0.20, 0.30, 0.06), F_POST)
    # flagpole on the front-left corner post, clamps, finial, halyard and cleat, red-over-yellow flag
    px, py = POLE
    g.lathe([(0.0, 0.30), (0.04, 0.30), (0.035, POLE_TOP), (0.0, POLE_TOP)], 12, F_POLE,
            m=__import__("mathutils").Matrix.Translation((px, py, 0.0)))
    g.lathe([(0.0, POLE_TOP - 0.01)] + [(0.06 * math.sin(t), POLE_TOP + 0.06 - 0.06 * math.cos(t)) for t in np.linspace(0.2, math.pi, 7)],
            12, F_POLE, m=__import__("mathutils").Matrix.Translation((px, py, 0.0)))
    for z in (1.0, 2.4, 3.6):
        g.beam((px, py, z), (-1.60, -2.20, z), 0.05, 0.05, F_RACK)
        g.lathe([(0.046, -0.04), (0.046, 0.04)], 12, F_RACK, m=__import__("mathutils").Matrix.Translation((px, py, z)))
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

def timber(c, base, seed):
    wood = tri(scan("wood_peeling_paint_weathered", "rough"), c.pos, c.nrm, 0.9)[:, 0]
    grain = fbm(c.pos, 3.0, seed, 3, stretch=(6.0, 6.0, 0.4))
    a = col(base, c.n) * (0.82 + 0.25 * grain + 0.12 * (wood - 0.5))[:, None]
    crack = ss(0.72, 0.76, fbm(c.pos, 6.0, seed + 1, 2, stretch=(12.0, 12.0, 0.5)))
    a = mix(a, a * 0.55, crack)
    return a, 0.78 + 0.1 * grain, -0.002 * crack + 0.001 * (grain - 0.5)


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
    blast = ss(3.6, DECK, z)                                       # sand-blast and splash at the foot of the walls
    # shiplap: 150 mm boards, each lapping the one below (wedge + shadow line)
    clad = c.is_(H_CLAD)
    q = ((z - DECK) / 0.15) % 1.0
    lap = ss(0.0, 0.08, q)
    white = tone(wood, (0.86, 0.86, 0.83), 0.35)
    bidx = np.floor((z - DECK) / 0.15)
    white *= (0.97 + 0.05 * hash3(np.stack([bidx, np.floor(x * 0.8), np.floor(y * 0.8)], 1), 5))[:, None]
    peel = ss(0.68, 0.70, fbm(c.pos, 5.0, 103, 4) + 0.15 * blast + 0.08 * (1 - lap))
    a = mix(white, tone(wood, (0.48, 0.45, 0.40), 0.9), peel)
    a = mix(a, a * 0.62, 1 - lap)
    grime = ss(0.55, 0.78, streak) * (0.3 + 0.7 * ss(5.0, WALL_TOP, z)) + 0.5 * blast * fbm(c.pos, 3.0, 105, 2)
    for wx0, wx1, wz in ((WIN_FRONT[0], WIN_FRONT[1], WIN_FRONT[2]),):
        grime = np.maximum(grime, ss(0.2, 0.0, np.maximum(wx0 - x, x - wx1)) * ss(wz - 0.9, wz, z) * (z < wz) * (y < -1.3) * (0.4 + 0.6 * streak))
    a = mix(a, a * np.array([0.66, 0.65, 0.60], np.float32), 0.45 * np.clip(grime, 0, 1))
    salt = ss(0.5, 0.8, fbm(c.pos, 8.0, 107, 2)) * blast
    a = mix(a, col((0.80, 0.79, 0.75), n), 0.3 * salt)
    alb = np.where(clad[:, None], a, alb)
    rgh = np.where(clad, 0.62 + 0.2 * peel + 0.1 * grime, rgh)
    hgt = np.where(clad, 0.006 * q - 0.0015 * peel, hgt)

    # red trims, door: gloss red over white primer, edge wear, chalking; signal
    def red_paint(base, seed):
        chalk = ss(0.45, 0.8, fbm(c.pos, 2.5, seed, 3))
        a = tone(wood, base, 0.25)
        a = mix(a, col((0.66, 0.36, 0.32), n), 0.35 * chalk)
        wear = ss(0.66, 0.72, fbm(c.pos, 12.0, seed + 1, 3) + 0.35 * c.edge)
        a = mix(a, col((0.80, 0.78, 0.74), n), 0.8 * wear)
        a = mix(a, a * 0.7, 0.3 * ss(0.55, 0.8, streak))
        return a, 0.42 + 0.2 * chalk + 0.2 * wear, wear
    trim = c.is_(H_TRIM)
    a, r, wear = red_paint((0.62, 0.13, 0.11), 111)
    alb = np.where(trim[:, None], a, alb)
    rgh = np.where(trim, r, rgh)
    hgt = np.where(trim, -0.0008 * wear, hgt)
    sig = np.where(trim & (wear < 0.5), 1.0, sig)
    door = c.is_(H_DOOR)
    a, r, wear = red_paint((0.66, 0.12, 0.10), 113)
    tg = ((x - DOOR[0]) / 0.10) % 1.0
    v = ss(0.06, 0.0, np.minimum(tg, 1 - tg))
    hand = np.exp(-((x - (DOOR[1] - 0.12)) ** 2 + (z - 4.0) ** 2) / 0.03)
    a = mix(a, a * 0.75, v)
    a = mix(a, a * np.array([0.7, 0.68, 0.64], np.float32), 0.6 * hand)
    alb = np.where(door[:, None], a, alb)
    rgh = np.where(door, r, rgh)
    hgt = np.where(door, -0.003 * v, hgt)
    sig = np.where(door & (wear < 0.5), 1.0, sig)

    # roof: grey box-profile steel, rusting fixings, droppings, sand in the troughs
    roof = c.is_(H_ROOF)
    rr = ss(0.70, 0.74, fbm(c.pos, 10.0, 121, 3) + 0.3 * c.edge)
    fix = ((x + 1.70) / 0.20) % 1.0
    fixing = (np.abs(fix - 0.5) > 0.42) & (((y + 2.0) / 0.6) % 1.0 < 0.03)
    a = tone(tri(scan("metal_plate_02"), c.pos, c.nrm, 1.0), (0.48, 0.50, 0.50), 0.4)
    a = mix(a, col((0.44, 0.27, 0.15), n), np.maximum(rr * 0.8, fixing * 0.9))
    a = mix(a, col((0.66, 0.60, 0.48), n), 0.5 * up * ss(0.4, 0.7, fbm(c.pos, 6.0, 123, 2)))
    drop = droppings(c, up, 125)
    a = mix(a, col((0.86, 0.85, 0.80), n), 0.9 * drop)
    alb = np.where(roof[:, None], a, alb)
    rgh = np.where(roof, 0.48 + 0.3 * rr, rgh)
    hgt = np.where(roof, 0.0015 * drop - 0.0008 * rr, hgt)

    # window frames (white uPVC), glass, the dim interior behind it
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
    a = col((0.17, 0.165, 0.155), n) * (0.85 + 0.3 * fbm(c.pos, 3.0, 133, 2))[:, None]
    a = mix(a, col((0.32, 0.30, 0.27), n), 0.6 * shelf)
    a = mix(a, col((0.55, 0.16, 0.12), n), 0.7 * ss(0.68, 0.72, fbm(c.pos, 2.0, 135, 2)))   # kit on the shelves
    alb = np.where(it[:, None], a, alb)
    rgh = np.where(it, 0.8, rgh)

    # sign: yellow board, red letters, corner screws; signal
    sg = c.is_(H_SIGN)
    s = SIGN
    face = c.nrm[:, 1] < -0.7
    u = (x - (s["x"] - s["w"] / 2)) / s["w"]
    vv = ((s["z"] + s["h"] / 2) - z) / s["h"]
    letters = text_sample(mask_img(os.path.join(H6DIR, "text_sign.png")), u, vv) * face
    fade = ss(0.4, 0.8, fbm(c.pos, 3.0, 141, 3))
    yel = mix(col((0.93, 0.76, 0.13), n), col((0.90, 0.80, 0.45), n), 0.35 * fade)
    redl = mix(col((0.74, 0.11, 0.08), n), col((0.72, 0.32, 0.27), n), 0.3 * fade)
    a = mix(yel, redl, letters)
    a = mix(a, a * 0.75, 0.3 * ss(0.6, 0.85, streak))
    alb = np.where(sg[:, None], a, alb)
    rgh = np.where(sg, 0.4 + 0.15 * fade, rgh)
    hgt = np.where(sg, 0.0004 * letters, hgt)
    sig = np.where(sg, 1.0, sig)

    # stainless fittings with tea staining
    mt = c.is_(H_METAL)
    tea = ss(0.6, 0.75, fbm(c.pos, 25.0, 151, 2))
    alb = np.where(mt[:, None], mix(col((0.78, 0.78, 0.76), n), col((0.55, 0.40, 0.28), n), 0.8 * tea), alb)
    rgh = np.where(mt, 0.3 + 0.4 * tea, rgh)
    # small fittings dielectric (thinner than check_textures erosion); bright, low roughness
    return alb, rgh, met, hgt, sig


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
    sandmask = ss(0.30, 0.0, z) * (0.6 + 0.4 * fbm(c.pos, 6.0, 201, 2))

    # treated timber: posts, bracing, bearers, joists, stringers; damp and sand at the foot
    tim = c.is_(F_POST)
    a, r, h = timber(c, (0.50, 0.46, 0.37), 211)
    a = mix(a, a * np.array([0.62, 0.66, 0.58], np.float32), ss(0.9, 0.1, z) * 0.6)
    a = mix(a, sandc, ss(0.5, 0.75, sandmask))
    bolts = ss(0.012, 0.004, np.abs((z % 0.55) - 0.275)) * ss(0.02, 0.0, np.abs(((x + y) % 0.3) - 0.15)) * (z > 0.3)
    alb = np.where(tim[:, None], a, alb)
    rgh = np.where(tim, r, rgh)
    hgt = np.where(tim, h, hgt)

    # deck boards along Y (140 mm, gaps), screw pairs at every joist, sand in the corners, wear path from the steps
    dk = c.is_(F_DECK, F_STAIR)
    bpos = (x + 1.7) / 0.145
    gap = ss(0.06, 0.02, np.minimum(bpos % 1.0, 1 - bpos % 1.0))
    bt = hash3(np.stack([np.floor(bpos), np.zeros(n), np.zeros(n)], 1), 7)
    a, r, h = timber(c, (0.56, 0.54, 0.49), 221)
    a *= (0.88 + 0.2 * bt)[:, None]
    jy = ((y - (DECK_XY[2] + 0.05)) / 0.45) % 1.0
    jd = np.minimum(jy, 1 - jy) * 0.45
    sd = np.minimum(np.abs((bpos % 1.0) - 0.25), np.abs((bpos % 1.0) - 0.75)) * 0.145
    screw = ss(0.007, 0.004, np.sqrt(jd ** 2 + sd ** 2)) * up * c.is_(F_DECK)
    halo = ss(0.02, 0.006, np.sqrt(jd ** 2 + sd ** 2)) * up * c.is_(F_DECK)
    a = mix(a, a * 0.45, gap)
    a = mix(a, col((0.44, 0.30, 0.20), n), 0.4 * halo)
    a = mix(a, col((0.30, 0.30, 0.30), n), screw)
    path = ss(0.6, 0.0, np.abs(x - 0.9) - 0.3) * ss(-0.8, -2.3, y) * up
    a = mix(a, a * 1.12, 0.5 * path)
    corner = (ss(1.2, 1.66, np.abs(x)) + ss(1.2, 1.7, np.abs(y + 0.3))) * up
    a = mix(a, sandc, 0.6 * ss(0.4, 0.8, corner * fbm(c.pos, 5.0, 225, 2) * 1.4 + 0.3 * path))
    # stair treads: dark grit strip on the nosing
    tr = c.is_(F_STAIR) & (c.nrm[:, 2] > 0.7)
    nose = ((y - DECK_XY[2]) / ((DECK_XY[2] - STAIR_FOOT_Y) / 15.0)) % 1.0
    grit = tr & (nose > 0.55) & (nose < 0.85) & (x > STAIR_X[0] + 0.06) & (x < STAIR_X[1] - 0.06)
    a = np.where(grit[:, None], col((0.20, 0.20, 0.19), n) * (0.8 + 0.4 * fbm(c.pos, 40.0, 227, 1))[:, None], a)
    alb = np.where(dk[:, None], a, alb)
    rgh = np.where(dk, np.where(grit, 0.95, r), rgh)
    hgt = np.where(dk, h - 0.006 * gap * up + 0.0008 * screw + 0.0015 * grit, hgt)

    # white painted rails, worn to grey timber on the top edges and where hands go
    rl = c.is_(F_RAIL)
    ta, _, th_ = timber(c, (0.52, 0.50, 0.46), 231)
    wear = ss(0.62, 0.70, fbm(c.pos, 8.0, 233, 3) + 0.25 * c.edge + 0.2 * up * ss(DECK + 0.9, DECK + 1.05, z))
    a = mix(col((0.85, 0.85, 0.81), n) * (0.95 + 0.06 * fbm(c.pos, 20.0, 235, 2))[:, None], ta, wear)
    a = mix(a, a * 0.72, 0.4 * ss(0.6, 0.85, fbm(c.pos, 4.0, 237, 3, stretch=(4, 4, 0.25))))
    alb = np.where(rl[:, None], a, alb)
    rgh = np.where(rl, 0.55 + 0.25 * wear, rgh)
    hgt = np.where(rl, th_ * wear - 0.0006 * wear, hgt)

    # pole: white powder-coated aluminium; galvanised rack and clamps
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
    # galvanised rack dielectric for the same reason (thin bars)

    # flag: red over yellow nylon, weave, fraying edge darkening; signal
    fg = c.is_(F_FLAG)
    mid = (FLAG[0] + FLAG[1]) / 2 - 0.06 * ((POLE[0] - x) / FLAG[2]) ** 2
    weave = 0.95 + 0.06 * fbm(c.pos, 120.0, 251, 1)
    a = np.where((z > mid)[:, None], col((0.80, 0.13, 0.10), n), col((0.95, 0.78, 0.12), n)) * weave[:, None]
    fray = ss(0.70, 0.88, (POLE[0] - x) / FLAG[2])
    a = mix(a, a * 0.78, 0.5 * fray * fbm(c.pos, 30.0, 253, 2))
    alb = np.where(fg[:, None], a, alb)
    rgh = np.where(fg, 0.85, rgh)
    sig = np.where(fg, 1.0, sig)

    # rescue board: yellow soft deck, red rails, scuffs and sand; signal
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

    # halyard (white braid), handles and strap (black webbing)
    rp = c.is_(F_ROPE)
    alb = np.where(rp[:, None], col((0.80, 0.80, 0.76), n) * (0.85 + 0.2 * fbm(c.pos, 60.0, 271, 1))[:, None], alb)
    rgh = np.where(rp, 0.85, rgh)
    st = c.is_(F_STRAP)
    alb = np.where(st[:, None], col((0.15, 0.15, 0.155), n) * (0.9 + 0.2 * fbm(c.pos, 80.0, 273, 1))[:, None], alb)
    rgh = np.where(st, 0.8, rgh)
    _ = bolts
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
