"""M_Bld_HarbourLight (docs/12 2.2, batch H6): the red-and-white pier-head light on the east breakwater head (1868).

A 12 m round masonry tower (white-painted ashlar over granite, two red daymark bands, granite plinth, dressings,
corbelled gallery), a cast-iron gallery rail, a 12-sided lantern with astragals, a red domed roof with a ventilator ball
and vane, and a 2-panel-pair rotating dioptric optic (own MeshPart `_Lens`, Neon in game) giving Fl(2) W 10s
(art/reference/M_Bld_HarbourLight/dims.md). Door with a granite surround, three windows, copper lightning conductor, a
cast bronze plaque (HARBOUR LIGHT / ERECTED 1868) for the logbook "Harbour Light history" POI. Shared pipeline:
../H6/h6lib.py (geometry -> G-buffer -> h6tex maps).
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_HarbourLight --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "H6"))
import h6lib  # noqa: E402
from h6lib import Geo  # noqa: E402
from h6tex import col, fbm, hash3, luma, mix, scan, ss, text_sample, tone, tri, mask_img, HERE as H6DIR  # noqa: E402

NAME = "M_Bld_HarbourLight"
TEX = "HarbourLight"
SEG = 64
# Tower set parts
P_WALL, P_PLINTH, P_DRESS, P_DOOR, P_PLAQUE, P_WINGLASS, P_WINFRAME, P_COPPER, P_IRON = range(9)
# Lantern set parts
L_RAIL, L_RED, L_WHITE, L_BLACK, L_LENS, L_GLASS, L_BRASS, L_GALV = range(8)

WALL_Z0, WALL_Z1 = 0.50, 8.00
BANDS = ((3.0, 4.1), (5.9, 7.0))
GALLERY_Z = 8.58
RAIL_R, RAIL_TOP, N_STAN = 1.90, 9.62, 16
LENS_Z = 9.95
PLAQUE = {"az": math.radians(40), "z": 1.70, "w": 0.70, "h": 0.50, "r": 1.775, "t": 0.08}
CONDUCTOR_AZ = math.radians(-110)


def wall_r(z):
    t = min(max((z - WALL_Z0) / (WALL_Z1 - WALL_Z0), 0.0), 1.0)
    return 1.80 - 0.30 * t ** 1.15


def radial(az, r, z):
    return (r * math.sin(az), -r * math.cos(az), z)


def opening(g, az, z0, z1, w, door=False):
    """Granite surround (jambs, lintel, sill) on the curved wall at azimuth az; returns the face depth."""
    rz = wall_r((z0 + z1) / 2)
    yaw = az
    rot = lambda v: Matrix.Rotation(yaw, 4, "Z") @ Vector(v)
    jw, dep = 0.22 if door else 0.16, 0.30
    half = w / 2.0
    sag = rz - math.sqrt(max(rz * rz - (half + jw) ** 2, 0.01))
    cy = -(rz - sag / 2.0 + (0.02 if door else -0.02))   # depth centre: from inside the wall to 12-17 cm proud
    for sx in (-1, 1):
        g.boxr(tuple(rot((sx * (half + jw / 2), cy, (z0 + z1) / 2))), (jw, dep, z1 - z0), P_DRESS, yaw)
    g.boxr(tuple(rot((0.0, cy - 0.02, z1 + 0.17))), (w + 2 * jw + 0.12, dep + 0.04, 0.34), P_DRESS, yaw)
    if not door:
        g.boxr(tuple(rot((0.0, cy - 0.05, z0 - 0.06))), (w + 2 * jw + 0.10, dep + 0.10, 0.12), P_DRESS, yaw)
    return cy - dep / 2.0


def window(g, az, z0, z1, w):
    face = opening(g, az, z0, z1, w)
    rz = wall_r((z0 + z1) / 2)
    yaw = az
    rot = lambda v: tuple(Matrix.Rotation(yaw, 4, "Z") @ Vector(v))
    # pane set 5 cm back from the surround face, with a painted timber frame and one glazing bar
    py = face + 0.07
    g.boxr(rot((0.0, py + 0.03, (z0 + z1) / 2)), (w + 0.02, 0.06, z1 - z0 + 0.02), P_WINGLASS, yaw)
    fy = py - 0.005
    for sx in (-1, 1):
        g.boxr(rot((sx * (w / 2 - 0.03), fy, (z0 + z1) / 2)), (0.06, 0.05, z1 - z0), P_WINFRAME, yaw)
    for zz in (z0 + 0.03, z1 - 0.03, (z0 + z1) / 2):
        g.boxr(rot((0.0, fy, zz)), (w, 0.05, 0.05 if zz in (z0 + 0.03, z1 - 0.03) else 0.035), P_WINFRAME, yaw)
    g.boxr(rot((0.0, fy, (z0 + z1) / 2)), (0.035, 0.05, z1 - z0), P_WINFRAME, yaw)
    _ = rz


def tower_geo():
    g = Geo()
    # granite plinth: two courses on the breakwater head, chamfered top
    g.lathe([(2.00, 0.0), (2.00, 0.25), (1.99, 0.27), (1.99, 0.40), (1.95, 0.45), (1.79, 0.50)], SEG, P_PLINTH, caps=False)
    # battered wall, rings at the band edges so the paint lines are crisp
    zs = sorted({WALL_Z0, 1.5, 2.5, 3.0, 4.1, 5.0, 5.9, 7.0, 7.5, WALL_Z1})
    prof = [(wall_r(z), z) for z in zs]
    g.lathe(prof, SEG, P_WALL, caps=False)
    # corbelled cornice and the granite gallery slab
    g.lathe([(1.49, 7.99), (1.52, 8.04), (1.58, 8.06), (1.62, 8.16), (1.76, 8.30), (1.82, 8.34),
             (1.82, 8.40), (1.99, 8.42), (2.00, 8.50), (1.99, GALLERY_Z), (0.96, GALLERY_Z)], SEG, P_DRESS, caps=False)
    for i in range(N_STAN):
        a = (i + 0.5) * 2 * math.pi / N_STAN
        g.boxr(radial(a, 1.70, 8.20), (0.13, 0.42, 0.30), P_DRESS, a, pitch=math.radians(-28))
    # door: granite surround, threshold, boarded leaf, strap hinges, ring handle, escutcheon
    opening(g, 0.0, 0.50, 2.50, 0.92, door=True)
    g.box((0.0, -1.86, 0.525), (1.30, 0.26, 0.05), P_DRESS)
    # H6b: lined timber frame (jambs, head) and a leaf of five V-jointed planks with shadow gaps, dark lobby behind
    for sx in (-1, 1):
        g.bbox((sx * 0.425, -1.80, 1.50), (0.07, 0.10, 2.00), P_DOOR, 0.008, axis=2)
    g.bbox((0.0, -1.80, 2.465), (0.92, 0.10, 0.07), P_DOOR, 0.008, axis=0)
    g.box((0.0, -1.72, 1.50), (0.92, 0.02, 2.00), P_IRON)
    for i in range(5):
        g.bbox((-0.384 + 0.1536 * (i + 0.5), -1.79, 1.475), (0.1516, 0.05, 1.89), P_DOOR, 0.007, axis=2)
    for zh in (0.80, 2.18):
        g.bbox((-0.15, -1.822, zh), (0.48, 0.014, 0.055), P_IRON, 0.003, axis=0)
        g.lathe([(0.0, -0.02), (0.035, -0.02), (0.035, 0.02), (0.0, 0.02)], 8, P_IRON,
                m=Matrix.Translation((0.09, -1.822, zh)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        g.tube((-0.39, -1.83, zh - 0.07), (-0.39, -1.83, zh + 0.07), 0.016, 8, P_IRON)
        for xn in (-0.30, -0.12, 0.04):
            g.lathe([(0.009, 0.0), (0.0, 0.006)], 6, P_IRON, m=Matrix.Translation((xn, -1.829, zh)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        g.lathe([(0.0, 1.80), (0.022, 1.80), (0.022, 1.835), (0.0, 1.835)], 8, P_IRON,
                m=Matrix.Translation((-0.45, 0.0, zh)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    g.torus((0.30, -1.835, 1.40), 0.055, 0.010, 12, 4, P_IRON, normal=(0, 1, 0))
    g.box((0.30, -1.828, 1.46), (0.05, 0.012, 0.05), P_IRON)
    g.box((0.30, -1.828, 1.25), (0.045, 0.012, 0.11), P_IRON)
    # windows: front above the door, side, rear near the top (stair lights)
    window(g, 0.0, 4.35, 5.25, 0.46)
    window(g, math.radians(100), 1.90, 2.65, 0.40)
    window(g, math.radians(190), 7.10, 7.62, 0.40)
    # cast bronze plaque beside the door (ATT_Plaque)
    p = PLAQUE
    g.boxr(radial(p["az"], p["r"], p["z"]), (p["w"], p["t"], p["h"]), P_PLAQUE, p["az"])
    # copper lightning conductor tape with fixings, from the gallery to an earth clamp on the plinth
    zz = np.linspace(0.30, 8.30, 17)
    pts = []
    for z in zz:
        if z < WALL_Z0:
            r = 2.01 if z < 0.25 else 2.00
        elif z > WALL_Z1:
            r = 1.50 + (z - WALL_Z1) * 1.0 + 0.012
        else:
            r = wall_r(z) + 0.012
        pts.append(radial(CONDUCTOR_AZ, r, float(z)))
    for a, b in zip(pts, pts[1:]):
        nrm = Vector((math.sin(CONDUCTOR_AZ), -math.cos(CONDUCTOR_AZ), 0.0))
        g.beam(a, b, 0.026, 0.005, P_COPPER, up=tuple(nrm))
    for z in np.arange(1.0, 8.0, 1.0):
        g.boxr(radial(CONDUCTOR_AZ, wall_r(z) + 0.016, float(z)), (0.05, 0.012, 0.03), P_IRON, CONDUCTOR_AZ)
    g.boxr(radial(CONDUCTOR_AZ, 2.012, 0.20), (0.12, 0.02, 0.14), P_COPPER, CONDUCTOR_AZ)
    return g


def prism(g, r, z0, z1, seg, part):
    a = [g.bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z0)) for i in range(seg)]
    b = [g.bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z1)) for i in range(seg)]
    for i in range(seg):
        j = (i + 1) % seg
        g.face((a[i], a[j], b[j], b[i]), part, False)


def lantern_geo():
    g = Geo()
    # gallery rail: 16 stanchions with feet, top rail and two rails
    for i in range(N_STAN):
        a = i * 2 * math.pi / N_STAN
        x, y = RAIL_R * math.cos(a), RAIL_R * math.sin(a)
        g.tube((x, y, GALLERY_Z), (x, y, RAIL_TOP), 0.020, 6, L_RAIL, caps=False)
        g.lathe([(0.045, GALLERY_Z), (0.035, GALLERY_Z + 0.05), (0.020, GALLERY_Z + 0.08)], 8, L_RAIL,
                m=Matrix.Translation((x, y, 0.0)), caps=False)
    g.torus((0, 0, RAIL_TOP), RAIL_R, 0.026, 64, 6, L_RAIL)
    for z in (8.95, 9.28):
        g.torus((0, 0, z), RAIL_R, 0.013, 64, 4, L_RAIL)
    # lantern pedestal (red) with the gallery hatch, lantern floor
    g.lathe([(0.98, GALLERY_Z), (0.98, 9.22), (1.01, 9.25), (1.01, 9.30), (0.95, 9.32),
             (0.0, 9.32)], SEG, L_RED)
    g.box((0.0, -0.985, 8.93), (0.56, 0.05, 0.58), L_RED)
    g.box((0.20, -1.015, 8.93), (0.03, 0.03, 0.10), L_BLACK)
    for zh in (8.72, 9.14):
        g.box((-0.26, -1.012, zh), (0.06, 0.03, 0.06), L_BLACK)
    # glazing (own MeshPart), astragals, sill, horizontal bar, cornice
    prism(g, 0.92, 9.32, 10.60, 12, L_GLASS)
    for i in range(12):
        a = 2 * math.pi * i / 12
        g.boxr((0.93 * math.cos(a), 0.93 * math.sin(a), 9.96), (0.07, 0.05, 1.30), L_WHITE, a)
    g.torus((0, 0, 9.96), 0.93, 0.018, 12, 4, L_WHITE)
    for zb in (9.64, 10.28):                                  # H6b: glazing bars, four tiers of panes
        g.torus((0, 0, zb), 0.925, 0.011, 12, 4, L_WHITE)
    g.lathe([(0.90, 9.30), (0.97, 9.30), (0.97, 9.37), (0.90, 9.37)], 12, L_WHITE)
    g.lathe([(0.90, 10.58), (1.05, 10.62), (1.05, 10.72), (0.98, 10.75), (0.90, 10.75)], SEG, L_WHITE)
    # domed roof (red), ventilator ball (black), vane and finial (galvanised)
    dome = [(0.99 * math.cos(t), 10.75 + 0.66 * math.sin(t)) for t in np.linspace(0, math.pi / 2, 10)]
    dome[-1] = (0.0, dome[-1][1])
    g.lathe(dome, SEG, L_RED)
    g.lathe([(0.08, 11.38), (0.08, 11.52)], 12, L_BLACK, caps=False)
    ball = [(0.17 * math.sin(t), 11.68 - 0.17 * math.cos(t)) for t in np.linspace(0, math.pi, 10)]
    g.lathe(ball, 16, L_BLACK)
    g.tube((0, 0, 11.84), (0, 0, 12.00), 0.012, 6, L_GALV)
    g.box((0.04, 0.0, 11.93), (0.34, 0.008, 0.07), L_GALV)
    g.boxr((0.24, 0.0, 11.93), (0.08, 0.008, 0.08), L_GALV, 0.0, roll=math.radians(45))
    g.boxr((-0.15, 0.0, 11.93), (0.10, 0.008, 0.14), L_GALV)
    # the optic: brass pedestal, drum lens with dioptric prism rings, 2 + 2 bullseye panels (Fl(2) at 3 rpm)
    g.lathe([(0.20, 9.32), (0.16, 9.46), (0.43, 9.50), (0.43, 9.55), (0.0, 9.55)], 24, L_BRASS)
    ribs = [(0.0, 9.55)] + [(0.37 if k % 2 == 0 else 0.395, 9.55 + 0.80 * k / 10.0) for k in range(11)] + [(0.0, 10.35)]
    g.lathe(ribs, 24, L_LENS)
    g.lathe([(0.0, 10.35), (0.42, 10.35), (0.42, 10.40), (0.10, 10.46), (0.0, 10.47)], 24, L_BRASS)
    for a in (0.0, math.radians(30), math.pi, math.pi + math.radians(30)):
        m = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((0.0, -0.38, LENS_Z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        g.lathe([(0.20, 0.0), (0.16, 0.03), (0.09, 0.055), (0.0, 0.065)], 16, L_LENS, m=m)
    return g


# ------------------------------------------------------------------ maps

def granite(c, base=(0.56, 0.545, 0.51), seed=3):
    n = c.n
    t = fbm(c.pos, 2.2, seed, 3)
    a = col(base, n) * (0.84 + 0.30 * t)[:, None]
    blob = ss(0.62, 0.70, fbm(c.pos, 9.0, seed + 5, 2))
    a = mix(a, col((0.63, 0.57, 0.53), n), 0.35 * blob)              # pinkish feldspar patches
    h = hash3(np.floor(c.pos / 0.011), seed + 9)
    a = mix(a, col((0.20, 0.20, 0.21), n), ss(0.90, 0.94, h) * 0.8)    # biotite specks
    a = mix(a, col((0.80, 0.79, 0.76), n), ss(0.10, 0.05, h) * 0.6)    # feldspar specks
    g = tri(scan("granite_tile", "rough"), c.pos, c.nrm, 1.7)[:, 0]
    a *= (0.92 + 0.16 * g)[:, None]
    return a, 0.70 + 0.15 * t


def lichen(c, a, rgh, amount, seed=21):
    f = fbm(c.pos, 5.0, seed, 3)
    m = ss(0.66, 0.70, f) * amount
    spot = ss(0.75, 0.78, fbm(c.pos, 14.0, seed + 3, 2)) * amount
    a = mix(a, col((0.72, 0.66, 0.38), c.n), 0.8 * m)
    a = mix(a, col((0.58, 0.60, 0.55), c.n), 0.7 * spot)               # grey crustose lichen
    return a, rgh + 0.1 * m, 0.0015 * (m + spot)


def droppings(c, up_mask, seed=41, dens=0.75):
    f = fbm(c.pos, 11.0, seed, 2)
    return ss(dens, dens + 0.03, f) * up_mask


def paint_tower(c):
    n = c.n
    alb = col((0.5, 0.5, 0.5), n)
    rgh = np.full(n, 0.7, np.float32)
    met = np.zeros(n, np.float32)
    hgt = np.zeros(n, np.float32)
    sig = np.zeros(n, np.float32)
    z, ang = c.z, c.ang
    up = ss(0.55, 0.8, c.nrm[:, 2])
    weather = 0.5 + 0.5 * np.cos(ang - math.radians(225))         # south-west, the prevailing weather side

    # ---- granite (plinth, dressings, gallery)
    ga, gr = granite(c)
    gran = c.is_(P_PLINTH, P_DRESS)
    a = ga.copy()
    r_ = gr.copy()
    # plinth courses and blocks with raked mortar joints
    s = ang * np.maximum(c.r, 0.3)
    course = np.floor(z / 0.25)
    off = (course % 2) * 0.47
    u = (s + off) / 0.95
    bj = np.minimum(u % 1.0, 1 - u % 1.0) * 0.95
    vj = np.minimum((z / 0.25) % 1.0, 1 - (z / 0.25) % 1.0) * 0.25
    pl = c.is_(P_PLINTH) & (c.nrm[:, 2] < 0.6)
    joint = np.maximum(ss(0.014, 0.004, bj), ss(0.014, 0.004, vj)) * pl
    blk = hash3(np.stack([course, np.floor(u), np.zeros(n)], 1), 7)
    a *= (0.90 + 0.18 * blk)[:, None]
    a = mix(a, col((0.50, 0.48, 0.44), n), joint)
    hgt += -0.008 * joint
    a, r_, hl = lichen(c, a, r_, ss(0.5, 0.0, z) * 0.6 + up * 0.5 + 0.15)
    hgt += hl
    # damp, algae and the salt tide-line on the plinth
    damp = ss(0.35, 0.0, z) * (0.6 + 0.4 * fbm(c.pos, 4.0, 13, 2))
    a = mix(a, a * np.array([0.62, 0.68, 0.58], np.float32), damp)
    salt = ss(0.25, 0.0, np.abs(z - 0.42)) * ss(0.45, 0.6, fbm(c.pos, 7.0, 17, 2)) * c.is_(P_PLINTH)
    a = mix(a, col((0.80, 0.79, 0.75), n), 0.5 * salt)
    # gallery: rust bleeding from the stanchion feet, droppings on top
    stan = (np.round((ang / (2 * math.pi)) * N_STAN - 0.0) / N_STAN) * 2 * math.pi
    d_st = np.abs(np.angle(np.exp(1j * (ang - stan)))) * c.r
    gal_rust = np.exp(-(d_st / 0.06) ** 2) * ss(8.0, 8.55, z) * (0.5 + 0.5 * fbm(c.pos, 8.0, 19, 2))
    rusty = col((0.46, 0.26, 0.14), n)
    a = mix(a, rusty, 0.75 * gal_rust * gran)
    drop = droppings(c, up * gran * ss(7.9, 8.5, z) + up * gran * 0.4)
    a = mix(a, col((0.86, 0.85, 0.80), n), 0.9 * drop)
    hgt += 0.002 * drop
    alb = np.where(gran[:, None], a, alb)
    rgh = np.where(gran, r_, rgh)

    # ---- painted ashlar wall
    wall = c.is_(P_WALL)
    ch, bl = 0.40, 0.85
    course = np.floor((z - WALL_Z0) / ch)
    off = (course % 2) * 0.41 + hash3(np.stack([course, course, course], 1), 3) * 0.2
    u = (s + off) / bl
    bj = np.minimum(u % 1.0, 1 - u % 1.0) * bl
    vq = ((z - WALL_Z0) / ch) % 1.0
    vj = np.minimum(vq, 1 - vq) * ch
    joint = np.maximum(ss(0.02, 0.004, bj), ss(0.02, 0.004, vj))
    blk = hash3(np.stack([course, np.floor(u), np.ones(n)], 1), 11)
    # H6b: two samplings of the plaster scan at unrelated scales and offsets, blended by low-frequency noise, so the
    # 1.3 m tile no longer repeats eight times round the tower (it read as a repeating chip pattern on the red bands)
    pl_a = tri(scan("white_plaster_rough_01"), c.pos, c.nrm, 1.3)
    pl_b = tri(scan("white_plaster_rough_01"), c.pos + np.array([3.1, 1.7, 0.9], np.float32), c.nrm, 0.77)
    plaster = mix(pl_a, pl_b, ss(0.35, 0.65, fbm(c.pos, 0.7, 25, 3)))
    white = tone(plaster, (0.87, 0.865, 0.83), 0.6) * (0.97 + 0.05 * blk)[:, None]
    in_band = np.zeros(n, bool)
    for z0, z1 in BANDS:
        in_band |= (z >= z0) & (z < z1)
    red = tone(plaster, (0.60, 0.135, 0.115), 0.28) * (0.96 + 0.06 * blk)[:, None]
    chalk = ss(0.45, 0.75, fbm(c.pos, 2.0, 23, 3)) * (0.35 + 0.4 * weather)
    red = mix(red, col((0.66, 0.36, 0.33), n), 0.45 * chalk)
    a = np.where(in_band[:, None], red, white)
    a = mix(a, a * 0.86, joint)
    hgt += -0.0035 * joint + 0.0008 * (plaster[:, 0] - 0.5)
    r_ = np.where(in_band, 0.55, 0.62) + 0.12 * chalk * in_band + 0.06 * (fbm(c.pos, 6.0, 29, 2) - 0.5)
    # paint flaking to the granite, worst low down and on the weather side
    warp = np.stack([fbm(c.pos, 1.3, 33, 2), fbm(c.pos, 1.3, 35, 2), fbm(c.pos, 1.3, 37, 2)], 1) - 0.5
    fl = fbm(c.pos + 0.6 * warp, 3.0, 31, 4) + 0.10 * ss(2.0, 0.5, z) + 0.06 * weather + 0.05 * joint
    # red bands: their own finer, domain-warped chipping (red over the white coat) at the band edges and arrises
    bandedge = np.zeros(n, np.float32)
    for z0, z1 in BANDS:
        bandedge = np.maximum(bandedge, ss(0.06, 0.0, np.minimum(np.abs(z - z0), np.abs(z - z1))))
    rchip = ss(0.74, 0.75, fbm(c.pos + 0.4 * warp, 9.0, 61, 4) + 0.18 * bandedge + 0.08 * joint) * in_band
    a = mix(a, white * 0.95, rchip)
    flake = ss(0.70, 0.715, fl)
    rim = ss(0.66, 0.70, fl) * (1 - flake)
    a = mix(a, ga * 0.92, flake)
    a = mix(a, a * 0.82, 0.5 * rim)
    hgt += -0.0018 * flake + 0.0006 * rim
    r_ = mix(r_, gr, flake)
    # rain-washed grime: vertical streaks, heavier under the cornice, the windows and on the lee side
    streak = fbm(c.pos * np.array([1.0, 1.0, 0.0], np.float32) + np.array([0, 0, 1], np.float32) * 0.0, 5.0, 37, 3)
    vfade = fbm(c.pos, 1.0, 39, 2, stretch=(4.0, 4.0, 0.15))
    grime = ss(0.50, 0.75, streak * 0.6 + vfade * 0.6) * (0.35 + 0.65 * ss(5.5, 7.9, z))
    for az, zt, w in ((0.0, 4.29, 0.30), (math.radians(100), 1.84, 0.26), (math.radians(190), 7.09, 0.26),
                      (0.0, 2.84, 0.80), (PLAQUE["az"], PLAQUE["z"] - 0.25, 0.35)):
        da = np.abs(np.angle(np.exp(1j * (ang - az)))) * c.r
        grime = np.maximum(grime, ss(w, w * 0.6, da) * ss(zt - 1.6, zt, z) * (z < zt) * (0.4 + 0.6 * vfade))
    a = mix(a, a * np.array([0.62, 0.62, 0.58], np.float32), 0.45 * grime)
    # verdigris run-off under the bronze plaque and the copper conductor
    for az, w, zt in ((PLAQUE["az"], 0.32, PLAQUE["z"] - 0.25), (CONDUCTOR_AZ, 0.07, 8.3)):
        da = np.abs(np.angle(np.exp(1j * (ang - az)))) * c.r
        vg = ss(w, w * 0.3, da) * ss(zt - 1.4, zt, z) * (z < zt) * ss(0.35, 0.6, vfade)
        a = mix(a, col((0.45, 0.58, 0.52), n), 0.55 * vg)
    # rust streaks from the gallery stanchions and slab fixings down the upper wall
    rust = np.exp(-(d_st / (0.035 + 0.03 * vfade)) ** 2) * ss(5.6, 7.95, z) * ss(0.3, 0.7, fbm(c.pos, 3.0, 43, 2, stretch=(3, 3, 0.4)))
    a = mix(a, rusty, 0.65 * rust)
    # H6b: rust drips from the gallery slab fixings and corbels, irregular lengths and widths
    ncol = 40
    fi = (ang / (2 * math.pi)) * ncol
    idx = np.floor(fi)
    hid = np.stack([idx, np.zeros(n), np.ones(n)], 1)
    centre = idx + 0.5 + (hash3(hid, 63) - 0.5) * 0.7
    da = np.abs(fi - centre) * 2 * math.pi / ncol * c.r
    L = 0.3 + 2.4 * hash3(hid, 65) ** 2
    below = np.clip(7.99 - z, 0, None)
    wd = (0.010 + 0.018 * hash3(hid, 67)) * (1.0 + 0.8 * below)
    wob = 0.02 * (fbm(c.pos, 2.5, 69, 2) - 0.5)
    drip = np.exp(-((da + wob) / wd) ** 2) * ss(7.99 - L, 7.99 - 0.35 * L, z) * (z < 7.99) * (hash3(hid, 71) < 0.7)
    drip *= ss(0.25, 0.55, fbm(c.pos, 4.0, 73, 3, stretch=(4, 4, 0.25)))
    a = mix(a, col((0.48, 0.27, 0.13), n), 0.7 * drip * ss(0.0, 0.25, 1.0 - below / np.maximum(L, 0.3) + 0.2))
    rust = np.maximum(rust, drip)
    # salt bloom and green algae low on the wall, more on the north (+Y) side
    north = 0.5 + 0.5 * np.cos(ang - math.pi)
    alg = ss(1.8, 0.5, z) * (0.4 + 0.6 * north) * ss(0.35, 0.65, fbm(c.pos, 3.0, 47, 3))
    a = mix(a, col((0.40, 0.44, 0.30), n), 0.55 * alg)
    r_ = r_ + 0.08 * alg + 0.06 * grime
    sig = np.where(wall & in_band & (flake < 0.5) & (rust < 0.4), 1.0, sig)
    alb = np.where(wall[:, None], a, alb)
    rgh = np.where(wall, r_, rgh)

    # ---- door: boarded leaf, green gloss paint worn to timber
    door = c.is_(P_DOOR)
    plank = ((c.x + 0.384) / 0.1536) % 1.0
    groove = ss(0.05, 0.0, np.minimum(plank, 1 - plank))
    wood = tri(scan("wood_peeling_paint_weathered"), c.pos, c.nrm, 1.0)
    dpaint = tone(wood, (0.17, 0.29, 0.25), 0.35)
    worn = ss(0.62, 0.70, fbm(c.pos, 6.0, 51, 3) + 0.25 * ss(1.0, 0.55, z) + 0.2 * c.edge
              + 0.2 * np.exp(-((c.x - 0.30) ** 2 + (z - 1.40) ** 2) / 0.02))
    a = mix(dpaint, tone(wood, (0.42, 0.36, 0.29), 0.8), worn)
    for zh in (0.80, 2.18):
        hr = ss(0.08, 0.0, np.abs(c.x + 0.2) - 0.20) * ss(zh - 0.6, zh, z) * (z < zh) * ss(0.4, 0.7, vfade)
        a = mix(a, rusty, 0.5 * hr)
    a = mix(a, a * 0.7, groove)
    alb = np.where(door[:, None], a, alb)
    rgh = np.where(door, 0.42 + 0.35 * worn, rgh)
    hgt = np.where(door, -0.004 * groove + 0.001 * (wood[:, 0] - 0.5) - 0.0008 * worn, hgt)

    # ---- iron fittings: black paint, rust at edges
    iron = c.is_(P_IRON)
    ir = ss(0.55, 0.70, fbm(c.pos, 20.0, 53, 2) + 0.3 * c.edge)
    a = mix(col((0.14, 0.14, 0.135), n), col((0.40, 0.24, 0.13), n), ir)
    alb = np.where(iron[:, None], a, alb)
    rgh = np.where(iron, 0.5 + 0.3 * ir, rgh)

    # ---- bronze plaque: patinated ground, polished raised letters and border
    pq = c.is_(P_PLAQUE)
    p = PLAQUE
    t = np.array([math.cos(p["az"]), math.sin(p["az"]), 0.0], np.float32)
    nout = np.array([math.sin(p["az"]), -math.cos(p["az"]), 0.0], np.float32)
    ctr = np.array(radial(p["az"], p["r"], p["z"]), np.float32)
    rel = c.pos - ctr
    pu = rel @ t / p["w"] + 0.5
    pv = 0.5 - rel[:, 2] / p["h"]
    face = (c.nrm @ nout) > 0.7
    letters = text_sample(mask_img(os.path.join(H6DIR, "text_plaque.png")), pu, pv) * face
    pat = fbm(c.pos, 18.0, 57, 3)
    ground = mix(col((0.27, 0.22, 0.15), n), col((0.38, 0.50, 0.44), n), ss(0.45, 0.70, pat))
    bronze = col((0.74, 0.58, 0.38), n) * (0.94 + 0.08 * pat)[:, None]
    lt = letters > 0.5
    alb = np.where((pq & lt)[:, None], bronze, np.where(pq[:, None], ground, alb))
    rgh = np.where(pq, np.where(lt, 0.33, 0.62), rgh)
    # letters stay dielectric: thinner than the analysis erosion, metal letters blend with the dark ground (check_textures)
    hgt = np.where(pq, 0.004 * letters, hgt)

    # ---- windows
    wg = c.is_(P_WINGLASS)
    haze = ss(0.35, 0.75, fbm(c.pos, 10.0, 61, 2))
    alb = np.where(wg[:, None], mix(col((0.13, 0.145, 0.155), n), col((0.40, 0.41, 0.40), n), 0.35 * haze), alb)
    rgh = np.where(wg, 0.06 + 0.25 * haze, rgh)
    wf = c.is_(P_WINFRAME)
    a = mix(col((0.84, 0.84, 0.81), n), col((0.52, 0.50, 0.46), n), 0.45 * ss(0.5, 0.8, fbm(c.pos, 12.0, 63, 2)) + 0.3 * c.cavity)
    alb = np.where(wf[:, None], a, alb)
    rgh = np.where(wf, 0.40, rgh)

    # ---- copper conductor tape and earth plate
    cu = c.is_(P_COPPER)
    a = mix(col((0.44, 0.31, 0.22), n), col((0.42, 0.56, 0.48), n), ss(0.35, 0.65, fbm(c.pos, 9.0, 67, 3)))
    alb = np.where(cu[:, None], a, alb)
    rgh = np.where(cu, 0.6, rgh)
    return alb, rgh, met, hgt, sig


def paint_lantern(c):
    n = c.n
    z = c.z
    alb = col((0.5, 0.5, 0.5), n)
    rgh = np.full(n, 0.5, np.float32)
    met = np.zeros(n, np.float32)
    hgt = np.zeros(n, np.float32)
    sig = np.zeros(n, np.float32)
    up = ss(0.5, 0.8, c.nrm[:, 2])
    rp = tri(scan("rusty_painted_metal"), c.pos, c.nrm, 0.8)
    rpr = tri(scan("rusty_painted_metal", "rough"), c.pos, c.nrm, 0.8)[:, 0]
    rustc = tone(tri(scan("rust_coarse_01"), c.pos, c.nrm, 0.6), (0.43, 0.25, 0.14), 0.8)
    chip = fbm(c.pos, 14.0, 71, 3)
    streak = fbm(c.pos, 3.0, 73, 3, stretch=(4.0, 4.0, 0.25))
    drop = droppings(c, up, 77, 0.72)

    def painted(base, gloss, rust_amt, seed):
        a = tone(rp, base, 0.25)
        rr = ss(0.70 - 0.25 * rust_amt, 0.74 - 0.25 * rust_amt, chip + 0.25 * c.edge * rust_amt)
        a = mix(a, rustc, rr)
        a = mix(a, a * 0.7, 0.35 * ss(0.55, 0.8, streak))
        a = mix(a, col((0.86, 0.85, 0.80), n), 0.9 * drop)
        r = gloss + 0.15 * (rpr - 0.5) + 0.4 * rr
        return a, r, -0.0008 * rr + 0.0015 * drop

    for part, base, gloss, ramt in ((L_RAIL, (0.15, 0.15, 0.15), 0.45, 0.8), (L_RED, (0.58, 0.13, 0.11), 0.32, 0.5),
                                    (L_WHITE, (0.86, 0.86, 0.83), 0.35, 0.4), (L_BLACK, (0.15, 0.15, 0.145), 0.45, 0.6)):
        m = c.is_(part)
        a, r, h = painted(base, gloss, ramt + (0.5 * ss(8.8, GALLERY_Z, z) if part == L_RAIL else 0.0), part)
        if part == L_RED:
            chalk = ss(0.4, 0.75, fbm(c.pos, 2.0, 79, 3))
            a = mix(a, col((0.64, 0.34, 0.31), n), 0.35 * chalk)
            sig = np.where(m & (luma(a) < 0.5) & (drop < 0.5), 1.0, sig)
        alb = np.where(m[:, None], a, alb)
        rgh = np.where(m, r, rgh)
        hgt = np.where(m, h, hgt)
    lens = c.is_(L_LENS)
    prism_ = ((z - 9.55) / 0.08) % 1.0
    alb = np.where(lens[:, None], col((0.80, 0.84, 0.82), n) * (0.95 + 0.08 * prism_)[:, None], alb)
    rgh = np.where(lens, 0.06, rgh)
    hgt = np.where(lens, 0.003 * prism_, hgt)
    sig = np.where(lens, 1.0, sig)
    gl = c.is_(L_GLASS)
    salt = ss(10.0, 9.32, z) * 0.5 + ss(0.45, 0.75, fbm(c.pos, 8.0, 83, 3)) * 0.5
    runs = ss(0.55, 0.75, fbm(c.pos, 6.0, 85, 2, stretch=(8.0, 8.0, 0.3)))
    alb = np.where(gl[:, None], mix(col((0.42, 0.47, 0.47), n), col((0.74, 0.74, 0.71), n), 0.5 * salt + 0.2 * runs), alb)
    rgh = np.where(gl, 0.05 + 0.35 * salt, rgh)
    br = c.is_(L_BRASS)
    alb = np.where(br[:, None], col((0.83, 0.67, 0.43), n) * (0.95 + 0.08 * chip)[:, None], alb)
    rgh = np.where(br, 0.28 + 0.15 * chip, rgh)
    met = np.where(br, 1.0, met)
    gv = c.is_(L_GALV)
    alb = np.where(gv[:, None], mix(col((0.74, 0.75, 0.74), n), col((0.86, 0.86, 0.84), n), ss(0.5, 0.8, chip)), alb)
    rgh = np.where(gv, 0.45, rgh)
    met = np.where(gv, 1.0, met)
    return alb, rgh, met, hgt, sig


# ------------------------------------------------------------------ spec

def build():
    S = h6lib.S
    p = PLAQUE
    hero = [(P_PLAQUE, (math.sin(p["az"]), -math.cos(p["az"]), 0.0), (math.cos(p["az"]), math.sin(p["az"]), 0.0),
             (0.002, 0.902, 0.162, 0.998))]
    meshes = h6lib.make_set(NAME, "Tower", tower_geo(), TEX, 2048, paint_tower, heroes=hero, squeeze=0.9)
    meshes += h6lib.make_set(NAME, "Lantern", lantern_geo(), TEX, 2048, paint_lantern,
                             splits=[([L_LENS], "Lens"), ([L_GLASS], "Glass")])
    col_ = h6lib.col_lathe(NAME + "_COL", [(0.0, 0.0), (2.0, 0.0), (2.0, 0.5), (1.8, 0.5), (1.5, 8.0), (2.0, 8.42),
                                           (2.0, GALLERY_Z), (1.0, GALLERY_Z), (1.0, 11.4), (0.0, 11.7)], seg=12)
    h6lib.make_lods({"budget": "hero_building", "tris": 20000, "meshes": meshes})
    meshes.append({"object": col_})
    atts = [h6lib.empty("ATT_Light", (0.0, 0.0, LENS_Z)),
            h6lib.empty("ATT_Door", (0.0, -2.05, 0.55)),
            h6lib.empty("ATT_Plaque", radial(p["az"], p["r"] + 0.05, p["z"])),
            h6lib.empty("ATT_Gallery", (0.0, -1.45, GALLERY_Z)),
            h6lib.empty("ATT_Top", (0.0, 0.0, 12.0))]
    lo, hi = h6lib.bbox_m(meshes[:-1])
    print("[H6] %s bbox m %s..%s tris %s" % (NAME, [round(v, 2) for v in lo], [round(v, 2) for v in hi],
                                              [(e["object"].name, h6lib.tris(e["object"])) for e in meshes]))
    return {
        "name": NAME, "budget": "hero_building", "tris": 20000, "tier": "standard",
        "dims_m": (4.0, 4.0, 12.0), "origin": "base",
        "sets": [{"name": TEX, "set": "Tower", "size": 2048, "wet": True},
                 {"name": TEX, "set": "Lantern", "size": 2048, "wet": True}],
        "meshes": meshes, "attachments": atts,
        "closeups": [{"name": "door_plaque", "target": [1.3 * S * 0.5, -1.9 * S, 1.5 * S], "dist": 9.0, "az": 20, "el": 5},
                     {"name": "plaque", "target": list(Vector(radial(p["az"], p["r"], p["z"])) * S), "dist": 5.0, "az": 40, "el": 3},
                     {"name": "lantern", "target": [0.0, 0.0, 10.0 * S], "dist": 14.0, "az": 30, "el": 12},
                     {"name": "gallery", "target": [0.0, -1.9 * S, 8.6 * S], "dist": 7.0, "az": 15, "el": 20},
                     {"name": "plinth", "target": [radial(math.radians(200), 2.0, 0.4)[0] * S, radial(math.radians(200), 2.0, 0.4)[1] * S, 0.6 * S], "dist": 7.0, "az": 200, "el": 15}],
        "waivers": {"texel density": "2 sets per the docs/12 2.2 row at 2048 (EXPORT_CAP shipping size until Spike 1): Tower 33, Lantern / lens / glass 45 px/stud; standard 51 needs 4096 or more sets. Lettering faces (plaque) get their own UV rect at about 150 px/stud; wear reads at 2 m (contact sheet)",
                    "texture sets": "docs/12 2.2 row: 2 sets + emissive lens (Tower 2048 + Lantern 1024; the lens and "
                                    "glazing are MeshParts on the Lantern set); hero_building class asks 4-5",
                    "LOD UV layout": "collapse decimation of the rails, astragals and fittings drops small UV islands at "
                                     "LOD1/LOD2 (UV bounds unchanged); kept faces keep the LOD0 UVs and set"},
    }
