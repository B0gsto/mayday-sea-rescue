"""Shared geometry for the two galvanised boat trailers (M_Veh_BoatTrailer_JetSki / _RIB).

Real-world layout in studs, authored from the coupling nose (Y 0) to the rear light bar (Y L), X across, Z up
(ground 0), then recentred so the origin is the centre of the base. See trailergeo.py for the Geo / material helpers.
"""
import math

from mathutils import Matrix, Vector

import trailergeo as V


def M(g, name, lo="Galvanised"):
    return name if g.hi else lo


JETSKI = dict(
    name="M_Veh_BoatTrailer_JetSki", tex="BoatTrailer", set="Galv",
    L=13.50, width=5.40, dims=(1.80, 4.58, 1.60),
    wheel_r=0.90, wheel_w=0.50, hub_x=2.32, axles=[9.20],
    rail_x=2.05, rail_y0=3.20, rail_y1=13.10, rail_z=1.35, rail_h=0.30, rail_w=0.18,
    frame_half=2.20, bed_z=2.15, bed_y=(5.30, 12.25),
    winch_y=3.95, winch_top=4.05, bow_eye_z=2.20, bow_eye_y=5.45,
    light_y=13.24, light_z=2.05, light_w=4.65,
    jockey=(2.05, 1.35), fender_r=1.04, fender_w=0.72, fender_x=2.32,
    bunks=[-0.58, 0.58], bunk_w=0.46, bunk_tilt=math.radians(9),
    wobble=[], keel=[],
    cradle=(0.0, 9.30, 2.18), twin=False, braked=False,
)

RIB = dict(
    name="M_Veh_BoatTrailer_RIB", tex="BoatTrailer", set="Galv",
    L=28.80, width=7.35, dims=(2.45, 9.60, 1.78),
    wheel_r=0.99, wheel_w=0.525, hub_x=2.85, axles=[14.775, 17.625],
    rail_x=2.55, rail_y0=4.20, rail_y1=27.90, rail_z=1.55, rail_h=0.36, rail_w=0.20,
    frame_half=2.72, bed_z=2.90, bed_y=(15.20, 27.30),
    winch_y=5.55, winch_top=4.45, bow_eye_z=2.95, bow_eye_y=7.55,
    light_y=28.55, light_z=2.42, light_w=5.75,
    jockey=(2.20, 1.60), fender_r=1.17, fender_w=1.25, fender_x=3.04,
    bunks=[], bunk_w=0.0, bunk_tilt=0.0,
    wobble=[20.5, 23.5, 26.5], keel=[7.8, 10.2, 12.6],
    cradle=(0.0, 18.6, 2.92), twin=True, braked=True,
)


def plan_beam(g, a, b, w, h, mat, z=None, bev=None):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    n = math.hypot(dx, dy)
    if n < 1e-6:
        return []
    z = (z if z is not None else 0.0)
    rot = Matrix.Rotation(math.atan2(-dx, dy), 3, "Z")
    b = (0.0 if not g.hi else 0.03) if bev is None else bev
    return V.box(g, ((ax + bx) / 2, (ay + by) / 2, z), (w, n, h), mat, rot=rot, bev=b)


def thick_beam(g, p0, p1, w, t, mat):
    a, b = Vector(p0), Vector(p1)
    d = b - a
    n = d.length
    if n < 1e-6:
        return []
    rot = d.to_track_quat("Y", "Z").to_matrix()
    return V.box(g, (a + b) / 2, (w, n, t), mat, rot=rot, bev=(min(w, t) * 0.3 if g.hi else 0.0))


def cyl(g, p0, p1, r, mat, seg=12):
    return V.sweep(g, [Vector(p0), Vector(p1)], V.circle_profile(r, seg), mat, cap0=True, cap1=True)


def collar(g, p, axis, r0, r1, length, mat, seg=12):
    a = Vector(axis).normalized()
    return V.lathe(g, Vector(p) - a * (length / 2), a, [(0.02, 0.0), (r0, 0.0), (r1, length), (0.02, length)], seg, mat)


def frame(g, s):
    z = s["rail_z"]
    h = s["rail_h"]
    w = s["rail_w"]
    for side in (-1, 1):
        plan_beam(g, (side * s["rail_x"], s["rail_y0"]), (side * s["rail_x"], s["rail_y1"]), w, h,
                  M(g, "Galvanised"), z)
        plan_beam(g, (side * (s["rail_x"] + w / 2 - 0.035), s["rail_y0"] + 0.15),
                  (side * (s["rail_x"] + w / 2 - 0.035), s["rail_y1"] - 0.15), 0.05, 0.10,
                  M(g, "GalvanisedDark"), z + h * 0.34)
    n = max(4, int(round((s["rail_y1"] - s["rail_y0"]) / 3.2)))
    for k in range(n + 1):
        y = s["rail_y0"] + (s["rail_y1"] - s["rail_y0"]) * k / n
        plan_beam(g, (-s["rail_x"], y), (s["rail_x"], y), 0.16, 0.24, M(g, "GalvanisedDark"), z - 0.02, bev=0.0)
    for side in (-1, 1):
        plan_beam(g, (0.0, 0.55), (side * s["rail_x"], s["rail_y0"]), 0.22, 0.30, M(g, "Galvanised"), z)
        thick_beam(g, (side * 0.12, 0.65, z + 0.18), (side * (s["rail_x"] - 0.1), s["rail_y0"] - 0.1, z + 0.18),
                   0.14, 0.05, M(g, "GalvanisedDark"))
    plan_beam(g, (0.0, 0.45), (0.0, s["rail_y0"] + 0.4), 0.24, 0.30, M(g, "Galvanised"), z)
    for side in (-1, 1):
        plan_beam(g, (side * (s["rail_x"] - 0.05), s["rail_y1"] - 0.2),
                  (side * s["frame_half"], s["rail_y1"] + 0.55), 0.14, 0.20, M(g, "GalvanisedDark"), z, bev=0.0)
    plan_beam(g, (-s["frame_half"], s["rail_y1"] + 0.55), (s["frame_half"], s["rail_y1"] + 0.55),
              0.16, 0.22, M(g, "GalvanisedDark"), z, bev=0.0)
    for side in (-1, 1):
        for y in (s["rail_y0"] + 0.3, s["rail_y1"] - 0.4):
            V.box(g, (side * (s["rail_x"] + 0.15), y, z + 0.02), (0.12, 0.32, 0.44), M(g, "GalvanisedDark"),
                  bev=(0.02 if g.hi else 0.0))


def coupling(g, s):
    z = s["rail_z"]
    y0 = 0.20
    V.box(g, (0.0, 0.68, z + 0.02), (0.62, 0.72, 0.40), M(g, "GalvanisedDark"), bev=0.05)
    V.lathe(g, (0.0, 0.33, z + 0.03), (0, -1, 0),
            [(0.06, 0.0), (0.30, 0.0), (0.34, 0.10), (0.30, 0.24), (0.20, 0.30), (0.06, 0.32)],
            14, M(g, "GalvanisedDark"))
    V.box(g, (0.0, 0.46, z + 0.33), (0.34, 0.34, 0.12), M(g, "GalvanisedBright"), bev=0.03)
    V.tube(g, [(0.16, 0.45, z + 0.39), (0.42, 0.48, z + 0.46), (0.52, 0.72, z + 0.48)], 0.055,
           M(g, "GalvanisedBright"), 8, fillet=0.12)
    V.tube(g, [(-0.20, 0.50, z + 0.36), (-0.34, 0.58, z + 0.27), (-0.33, 0.74, z + 0.15)], 0.035,
           M(g, "Chain"), 7, fillet=0.1)
    V.tube(g, [(0.20, 0.57, z + 0.20), (0.82, 0.55, z + 0.24), (1.15, 0.80, z + 0.42), (1.10, 1.60, z + 0.42)],
           0.030, M(g, "BrakeCable"), 7, fillet=0.22)
    for sx in (-1, 1):
        V.box(g, (sx * 0.34, 0.56, z + 0.02), (0.10, 0.34, 0.30), M(g, "GalvanisedBright"), bev=0.02)
    if s["braked"]:
        V.lathe(g, (0.0, 1.55, z + 0.02), (0, 1, 0),
                [(0.08, 0.0), (0.21, 0.0), (0.21, 1.55), (0.16, 1.65), (0.08, 1.68)],
                12, M(g, "GalvanisedDark"))
        if g.hi:
            for k in range(5):
                V.lathe(g, (0.0, 1.22 + k * 0.16, z + 0.02), (0, 1, 0),
                        [(0.05, 0.0), (0.24, 0.0), (0.24, 0.05), (0.05, 0.05)], 12, M(g, "WinchDark"))
        V.tube(g, [(-0.20, 1.0, z + 0.30), (-0.55, 1.45, z + 0.52), (-0.62, 2.0, z + 0.40)],
               0.05, M(g, "WinchRed"), 8, fillet=0.14)
        cyl(g, (-0.28, 2.02, z + 0.40), (0.28, 2.02, z + 0.40), 0.045, M(g, "BrakeCable"), 8)
    else:
        V.tube(g, [(-0.28, 0.48, z + 0.20), (-0.55, 0.85, z + 0.34), (-0.50, 1.45, z + 0.34)],
               0.032, M(g, "Chain"), 7, fillet=0.16)
    V.box(g, (0.0, 0.09, z), (0.16, 0.10, 0.16), M(g, "GalvanisedBright"), bev=0.02)


def jockey(g, s):
    x, y = s["jockey"]
    z = s["rail_z"]
    V.box(g, (x, y, z - 0.02), (0.18, 0.26, 0.30), M(g, "GalvanisedDark"), bev=0.03)
    cyl(g, (x, y, z - 0.16), (x, y, 0.62), 0.075, M(g, "GalvanisedBright"), 10)
    collar(g, (x, y, 0.64), (0, 0, 1), 0.14, 0.14, 0.22, M(g, "GalvanisedDark"), 12)
    V.tube(g, [(x, y + 0.12, z + 0.05), (x + 0.35, y + 0.18, z + 0.10), (x + 0.48, y + 0.10, z + 0.02)],
           0.045, M(g, "GalvanisedBright"), 8, fillet=0.08)
    V.lathe(g, (x, y, 0.30), (1, 0, 0),
            [(0.05, -0.10), (0.23, -0.09), (0.28, -0.03), (0.28, 0.03), (0.23, 0.09), (0.05, 0.10)],
            14, M(g, "Tyre"))
    V.lathe(g, (x + 0.11, y, 0.30), (1, 0, 0),
            [(0.02, 0.0), (0.12, 0.0), (0.12, 0.035), (0.02, 0.035)], 12, M(g, "Rim"))
    V.box(g, (x, y + 0.02, 0.56), (0.14, 0.20, 0.10), M(g, "JockeyYellow"), bev=0.02)


def winch_post(g, s):
    y = s["winch_y"]
    top = s["winch_top"]
    z0 = s["rail_z"] + s["rail_h"] / 2
    V.box(g, (0.0, y, (z0 + top) / 2), (0.22, 0.22, top - z0), M(g, "Galvanised"), bev=0.025)
    V.box(g, (0.0, y + 0.20, z0 + 0.55), (0.08, 0.48, 0.80), M(g, "GalvanisedDark"), bev=0.02)
    V.box(g, (0.0, y, top), (0.50, 0.42, 0.08), M(g, "GalvanisedBright"), bev=0.02)
    dz = top + 0.16
    for sx in (-1, 1):
        V.box(g, (sx * 0.30, y, dz), (0.06, 0.38, 0.36), M(g, "GalvanisedDark"), bev=0.015)
    V.lathe(g, (-0.32, y, dz), (1, 0, 0),
            [(0.06, 0.0), (0.24, 0.0), (0.24, 0.12), (0.30, 0.14), (0.30, 0.52), (0.24, 0.55), (0.06, 0.55)],
            16, M(g, "WinchDark"))
    for k in range(7):
        V.lathe(g, (-0.20 + k * 0.075, y, dz), (1, 0, 0),
                [(0.18, 0.0), (0.26, 0.0), (0.26, 0.022), (0.18, 0.022)], 12, M(g, "WinchDark"))
    cyl(g, (0.05, y, dz), (0.72, y, dz), 0.035, M(g, "GalvanisedBright"), 8)
    V.tube(g, [(0.68, y, dz), (0.72, y, dz + 0.38), (0.88, y - 0.10, dz + 0.42)], 0.045,
           M(g, "WinchRed"), 8, fillet=0.09)
    V.lathe(g, (0.90, y - 0.10, dz + 0.44), (0.2, 0.1, 0.3), [(0.04, 0.0), (0.10, 0.0), (0.10, 0.10), (0.04, 0.10)],
            10, M(g, "BlackPlastic"))
    V.box(g, (0.0, y + 0.62, s["bed_z"] + 0.12), (0.20, 0.18, 0.46), M(g, "BowStop"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 0.22, y + 0.58, s["bed_z"] + 0.24), (0.16, 0.16, 0.58), M(g, "BowStop"),
              rot=Matrix.Rotation(math.radians(28) * sx, 3, "Y"), bev=0.03)
    strap_top = Vector((0.0, y + 0.05, dz - 0.06))
    strap_bot = Vector((0.0, s["bow_eye_y"], s["bow_eye_z"] + 0.10))
    thick_beam(g, strap_top, strap_bot, 0.13, 0.025, M(g, "StrapGrey"))
    V.box(g, (0.0, s["bow_eye_y"], s["bow_eye_z"] + 0.02), (0.16, 0.12, 0.22), M(g, "StrapGrey"), bev=0.02)


def fender(g, s, side, yc):
    r = s["fender_r"]
    w = s["fender_w"]
    t = 0.055
    th = 0.055
    prof = ([(-w / 2, t), (w / 2, t), (w / 2, -0.17), (w / 2 - th, -0.17),
             (w / 2 - th, 0.0), (-w / 2 + th, 0.0), (-w / 2 + th, -0.17), (-w / 2, -0.17)] if g.hi else
            [(-w / 2, t), (w / 2, t), (w / 2, -0.16), (-w / 2, -0.16)])
    z0 = s["wheel_r"]
    rings = []
    n = 18 if g.hi else 7
    for k in range(n + 1):
        a = -1.32 + (2.32) * k / n
        cy = yc + r * math.sin(a)
        cz = z0 + r * math.cos(a)
        rad = Vector((0.0, math.sin(a), math.cos(a)))
        rings.append([Vector((side * s.get("fender_x", s["hub_x"]) + px, cy, cz)) + rad * pr for px, pr in prof])
    faces = g.rings(rings, M(g, "Galvanised"), cap0=True, cap1=True)
    g.bevel_sharp(faces, 0.012 if not g.hi else 0.008, angle=35)
    for k in (0.22, 0.78):
        a = -1.32 + 2.32 * k
        y = yc + r * math.sin(a)
        z = z0 + r * math.cos(a)
        thick_beam(g, (side * s["rail_x"], y, s["rail_z"]), (side * s.get("fender_x", s["hub_x"]), y, z - r + 0.16),
                   0.10, 0.05, M(g, "GalvanisedDark"))


def axle(g, s, y):
    z = s["wheel_r"]
    cyl(g, (-s["hub_x"] + 0.12, y, z), (s["hub_x"] - 0.12, y, z), 0.105, M(g, "GalvanisedDark"), 12)
    cyl(g, (-s["rail_x"] + 0.25, y, z), (s["rail_x"] - 0.25, y, z), 0.18, M(g, "GalvanisedDark"), 12)
    for side in (-1, 1):
        thick_beam(g, (side * (s["rail_x"] - 0.45), y - 0.15, z - 0.10),
                   (side * (s["hub_x"] - 0.16), y, z), 0.13, 0.10, M(g, "GalvanisedDark"))
        V.lathe(g, (side * (s["hub_x"] - 0.14), y, z), (side, 0, 0),
                [(0.05, 0.0), (0.33, 0.0), (0.35, 0.06), (0.33, 0.12), (0.05, 0.12)], 14,
                M(g, "Hub"))
        if s["braked"]:
            V.tube(g, [(side * (s["rail_x"] - 0.30), y + 0.10, z + 0.05),
                       (side * (s["rail_x"] - 0.10), y + 0.55, s["rail_z"] - 0.02),
                       (side * 0.15, y + 1.2, s["rail_z"] - 0.02)], 0.028, M(g, "BrakeCable"), 7,
                   fillet=0.25)
    for side in (-1, 1):
        V.box(g, (side * (s["rail_x"] - 0.15), y, z + 0.22), (0.12, 0.46, 0.18), M(g, "GalvanisedDark"), bev=0.02)


def wheel(g, s, side, y):
    z = s["wheel_r"]
    r = s["wheel_r"]
    w = s["wheel_w"]
    x = side * s["hub_x"]
    seg = 24 if g.hi else 18
    if g.hi:
        prof = [(0.54 * r, -w / 2), (0.66 * r, -w / 2), (0.90 * r, -w * 0.38), (r, -w * 0.24),
                (r, w * 0.24), (0.90 * r, w * 0.38), (0.66 * r, w / 2), (0.54 * r, w / 2)]
        V.lathe(g, (x, y, z), (1, 0, 0), prof, seg, M(g, "Tyre"))
    else:
        rings = []
        for rad, xx in [(0.05, -w / 2), (0.68 * r, -w / 2), (r, -w * 0.20), (r, w * 0.20),
                        (0.68 * r, w / 2), (0.50 * r, w / 2 - 0.01), (0.16 * r, w / 2 - 0.01), (0.05, w / 2)]:
            rings.append([Vector((x + xx, y + math.cos(2 * math.pi * k / seg) * rad,
                                  z + math.sin(2 * math.pi * k / seg) * rad)) for k in range(seg)])
        g.rings(rings, M(g, "Tyre"), cap0=True, cap1=True)
    if g.hi:
        for k in range(5):
            rr = r * 0.955
            V.lathe(g, (x, y, z), (1, 0, 0),
                    [(rr - 0.035, -w * 0.44 + k * w * 0.22), (rr, -w * 0.44 + k * w * 0.22),
                     (rr, -w * 0.40 + k * w * 0.22), (rr - 0.035, -w * 0.40 + k * w * 0.22)],
                    seg, M(g, "Tyre"))
    face = x + side * (w / 2 - 0.03)
    if g.hi:
        V.lathe(g, (face, y, z), (-side, 0, 0),
                [(0.055 * r, 0.0), (0.32 * r, 0.0), (0.49 * r, 0.045), (0.56 * r, 0.01), (0.56 * r, -0.045),
                 (0.50 * r, -0.07), (0.055 * r, -0.07)],
                seg, M(g, "Rim"))
        V.lathe(g, (face + side * 0.055, y, z), (-side, 0, 0),
                [(0.03 * r, 0.0), (0.15 * r, 0.0), (0.15 * r, 0.055), (0.03 * r, 0.055)], 12, M(g, "Hub"))
    if g.hi:
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.25
            V.lathe(g, (face + side * 0.002, y + math.sin(a) * r * 0.34, z + math.cos(a) * r * 0.34),
                    (side, 0, 0), [(0.02, 0.0), (r * 0.075, 0.0), (r * 0.075, 0.015), (0.02, 0.015)], 8,
                    M(g, "BlackPlastic"))
        for k in range(10):
            a = 2 * math.pi * k / 10
            c = Vector((side * (s["hub_x"] + w * 0.20), y + math.sin(a) * r * 0.86, z + math.cos(a) * r * 0.86))
            V.box(g, c, (w * 0.50, 0.14, 0.055), M(g, "Tyre"), rot=Matrix.Rotation(a, 3, "X"), bev=0.01)
        for k in range(5):
            a = 2 * math.pi * k / 5 + 0.3
            V.lathe(g, (face + side * 0.06, y + math.sin(a) * 0.12, z + math.cos(a) * 0.12),
                    (side, 0, 0), [(0.02, 0.0), (0.045, 0.0), (0.045, 0.035), (0.02, 0.035)], 6,
                    M(g, "GalvanisedBright"))


def bunk(g, s, x):
    y0, y1 = s["bed_y"]
    top = s["bed_z"]
    w = s["bunk_w"]
    tilt = s["bunk_tilt"]
    rot = Matrix.Rotation(-math.copysign(tilt, x), 3, "Y")
    c = Vector((x, (y0 + y1) / 2, top))
    V.box(g, c, (w, y1 - y0, 0.11), M(g, "CarpetBack"), rot=rot, bev=0.02)
    V.box(g, c + Vector((0.0, 0.0, 0.075)), (w + 0.04, y1 - y0 - 0.05, 0.06), M(g, "Carpet"), rot=rot, bev=0.018)
    for yy in (y0 + 0.55, y1 - 0.55):
        thick_beam(g, (x, yy, s["rail_z"] + s["rail_h"] / 2), (x, yy, top - 0.12), 0.10, 0.09,
                   M(g, "GalvanisedDark"))
        thick_beam(g, (x + math.copysign(0.35, -x), yy, s["rail_z"] + 0.05), (x, yy, top - 0.16),
                   0.07, 0.05, M(g, "GalvanisedDark"))


def roller(g, s, pos, axis, r, width, bracket_to):
    p = Vector(pos)
    a = Vector(axis).normalized()
    if g.hi:
        V.lathe(g, p - a * (width / 2), a,
                [(0.02, 0.0), (r * 0.72, 0.0), (r, 0.035), (r, width * 0.22), (r * 0.96, width * 0.32),
                 (r * 0.96, width - width * 0.32), (r, width - width * 0.22), (r, width - 0.035),
                 (r * 0.72, width), (0.02, width)],
                14, M(g, "RollerBlue"))
    else:
        cyl(g, p - a * (width / 2), p + a * (width / 2), r, M(g, "RollerBlue"), 10)
    if g.hi:
        cyl(g, p - a * (width / 2 + 0.06), p + a * (width / 2 + 0.06), 0.035, M(g, "GalvanisedBright"), 8)
        for sx in (-1, 1):
            end = p + a * (sx * (width / 2 + 0.055))
            V.box(g, end + Vector((0, 0, -0.16)), (0.10, 0.10, 0.34), M(g, "GalvanisedDark"), bev=0.015)
    if bracket_to is not None:
        for sx in (-1, 1):
            thick_beam(g, (p.x * sx if p.x else sx * bracket_to[0], p.y, s["rail_z"] + 0.16),
                       (p.x + sx * 0.12, p.y, p.z - r - 0.08), 0.08, 0.06, M(g, "GalvanisedDark"))


def keel_and_wobble(g, s):
    if s["keel"]:
        plan_beam(g, (0.0, s["keel"][0] - 0.3), (0.0, s["keel"][-1] + 0.3), 0.28, 0.22,
                  M(g, "GalvanisedDark"), s["rail_z"] + 0.14)
        for y in s["keel"]:
            p = Vector((0.0, y, s["bed_z"] - 0.24))
            roller(g, s, p, (1, 0, 0), 0.30, 0.72, None)
            for sx in (-1, 1):
                thick_beam(g, (sx * 0.12, y, s["rail_z"] + 0.18), (sx * 0.12, y, p.z - 0.18),
                           0.09, 0.07, M(g, "GalvanisedDark"))
    for y in s["wobble"]:
        for side in (-1, 1):
            p = Vector((side * 1.95, y, 3.16))
            roller(g, s, p, (side * 0.94, 0.0, 0.34), 0.21, 0.52, None)
            thick_beam(g, (side * (s["rail_x"] - 0.05), y, s["rail_z"] + 0.18),
                       (p.x - side * 0.10, y, p.z - 0.10), 0.09, 0.08, M(g, "GalvanisedDark"))


def light_board(g, s):
    y = s["light_y"]
    z = s["light_z"]
    w = s["light_w"]
    for sx in (-1, 1):
        thick_beam(g, (sx * (s["frame_half"] - 0.18), y - 0.48, s["rail_z"]),
                   (sx * (w / 2 - 0.28), y - 0.10, z - 0.28), 0.09, 0.07, M(g, "GalvanisedDark"))
    V.box(g, (0.0, y, z), (w, 0.13, 0.50), M(g, "Galvanised"), bev=0.025)
    for sx in (-1, 1):
        x = sx * (w / 2 - 0.62)
        V.box(g, (x, y + 0.09, z), (0.62, 0.14, 0.42), M(g, "BlackPlastic"), bev=0.03)
        V.box(g, (x, y + 0.18, z + 0.10), (0.50, 0.035, 0.15), M(g, "LensRed"), bev=0.012)
        V.box(g, (x, y + 0.18, z - 0.09), (0.50, 0.035, 0.13), M(g, "LensAmber"), bev=0.012)
        V.box(g, (x - sx * 0.02, y + 0.18, z - 0.23), (0.22, 0.035, 0.09), M(g, "ReverseWhite"), bev=0.01)
        V.box(g, (x + sx * 0.42, y - 0.14, z - 0.02), (0.08, 0.10, 0.34), M(g, "MarkerAmber"), bev=0.012)
        V.box(g, (sx * (s["frame_half"] + 0.06), y - 1.05, s["rail_z"] + 0.02), (0.06, 0.16, 0.10),
              M(g, "MarkerAmber"), bev=0.012)
        V.box(g, (sx * (s["frame_half"] + 0.06), y - 2.60, s["rail_z"] + 0.02), (0.06, 0.16, 0.10),
              M(g, "ReflectorWhite"), bev=0.012)
    plate_w, plate_h = 1.02, 0.50
    V.box(g, (0.0, y + 0.185, z - 0.015), (plate_w, 0.025, plate_h), M(g, "PlateWhite"), bev=0.008)
    me = V.text_mesh("GL19 TRL", 0.31, extrude=0.006, resolution=1)
    px, pz = 0.0, z - 0.015
    g.add_mesh(me, M(g, "PlateLetter"), lambda co: Vector((px - co.x, y + 0.205 + co.z, pz + co.y)))
    for sx in (-1, 1):
        tri_reflector(g, (sx * 0.78, y + 0.21, z - 0.02), 0.14, M(g, "ReflectorRed"))


def tri_reflector(g, c, size, mat):
    x, y, z = c
    pts = [(x - size, y, z - size * 0.8), (x + size, y, z - size * 0.8), (x, y, z + size * 0.9)]
    back = [g.bm.verts.new((px, y + 0.025, pz)) for px, _, pz in pts]
    front = [g.bm.verts.new((px, y - 0.005, pz)) for px, _, pz in pts]
    f = g.face([front[1], front[0], front[2]], mat)
    b = g.face([back[0], back[1], back[2]], mat)
    faces = [f, b] if f and b else []
    for i in range(3):
        j = (i + 1) % 3
        f2 = g.face([front[i], back[i], back[j], front[j]], mat)
        if f2:
            faces.append(f2)
    return faces


def drawbar_brake_links(g, s):
    if not s["braked"]:
        return
    for side in (-1, 1):
        for y in s["axles"]:
            V.tube(g, [(side * 0.10, 1.0, s["rail_z"] - 0.08), (side * 1.55, y - 0.2, s["rail_z"] - 0.08)],
                   0.026, M(g, "BrakeCable"), 6, fillet=0.18)


def build_variant(g, s):
    frame(g, s)
    coupling(g, s)
    jockey(g, s)
    winch_post(g, s)
    for y in s["axles"]:
        axle(g, s, y)
        for side in (-1, 1):
            fender(g, s, side, y)
    if s["bunks"]:
        for x in s["bunks"]:
            bunk(g, s, x)
    keel_and_wobble(g, s)
    light_board(g, s)
    drawbar_brake_links(g, s)


def part_names(s):
    names = [(s["name"] + "_Frame_LOD0", lambda g: build_variant(g, s))]
    for i, y in enumerate(s["axles"]):
        for side, tag in ((1, "L"), (-1, "R")):
            if s["twin"] or i == 0:
                names.append((s["name"] + "_Wheel_%s%d_LOD0" % (tag, i + 1),
                              lambda g, side=side, y=y: wheel(g, s, side, y)))
    return names


def hp_names(s):
    names = [(s["name"] + "_Frame_HP", [lambda g: build_variant(g, s)])]
    for i, y in enumerate(s["axles"]):
        for side, tag in ((1, "L"), (-1, "R")):
            if s["twin"] or i == 0:
                names.append((s["name"] + "_Wheel_%s%d_HP" % (tag, i + 1),
                              [lambda g, side=side, y=y: wheel(g, s, side, y)]))
    return names


def collision(s):
    import bmesh
    import bpy
    bm = bmesh.new()
    pts = []
    for k in range(15):
        t = k / 14
        y = 0.0 + (s["L"] - 0.0) * t
        if y < s["rail_y0"]:
            hw = s["rail_x"] * (y / s["rail_y0"]) * 0.96
            zh = 0.55 + (s["rail_z"] - 0.4) * min(1.0, y / 1.0)
        else:
            hw = s["frame_half"]
            zh = s["rail_z"]
        pts += [(-hw, y, 0.05), (hw, y, 0.05), (-hw, y, zh + 0.35), (hw, y, zh + 0.35)]
    pts += [(0.0, 0.1, 1.4), (0.0, s["winch_y"], s["winch_top"] + 0.4),
            (0.0, s["light_y"], s["light_z"] + 0.3)]
    for y in s["axles"]:
        for sx in (-1, 1):
            for a in range(0, 360, 60):
                t = math.radians(a)
                pts.append((sx * s["hub_x"], y + s["wheel_r"] * math.cos(t),
                            s["wheel_r"] + s["wheel_r"] * math.sin(t)))
            pts.append((sx * (s.get("fender_x", s["hub_x"]) + s["fender_w"] / 2), y, s["wheel_r"] + s["fender_r"]))
    if s["bunks"]:
        for x in s["bunks"]:
            pts += [(x, s["bed_y"][0], s["bed_z"]), (x, s["bed_y"][1], s["bed_z"])]
    for y in s["wobble"]:
        pts += [(-2.1, y, 3.4), (2.1, y, 3.4)]
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(s["name"] + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(s["name"] + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def attachments(s):
    a = {
        "ATT_Coupler": (0.0, 0.34, s["rail_z"] + 0.03),
        "ATT_Cradle": s["cradle"],
        "ATT_Winch": (0.0, s["winch_y"], s["winch_top"] + 0.16),
        "ATT_BowEye": (0.0, s["bow_eye_y"], s["bow_eye_z"]),
        "ATT_LightBoard": (0.0, s["light_y"], s["light_z"]),
        "ATT_TailLamp_L": (s["light_w"] / 2 - 0.62, s["light_y"] + 0.18, s["light_z"] + 0.10),
        "ATT_TailLamp_R": (-(s["light_w"] / 2 - 0.62), s["light_y"] + 0.18, s["light_z"] + 0.10),
        "ATT_SideMarker_L": (s["frame_half"] + 0.06, s["light_y"] - 1.05, s["rail_z"] + 0.02),
        "ATT_SideMarker_R": (-(s["frame_half"] + 0.06), s["light_y"] - 1.05, s["rail_z"] + 0.02),
    }
    if s["twin"]:
        for y, front in zip(s["axles"], (True, False)):
            p = "F" if front else "R"
            a["ATT_Wheel_%sL" % p] = (s["hub_x"], y, s["wheel_r"])
            a["ATT_Wheel_%sR" % p] = (-s["hub_x"], y, s["wheel_r"])
    else:
        a["ATT_Wheel_FL"] = (s["hub_x"], s["axles"][0], s["wheel_r"])
        a["ATT_Wheel_FR"] = (-s["hub_x"], s["axles"][0], s["wheel_r"])
    return a
