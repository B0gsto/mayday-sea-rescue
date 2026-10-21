"""M_Veh_Ambulance geometry: invented UK box-body paramedic ambulance (Sprinter / Ducato class).

Model frame (studs, before the final recentre): X across (driver side -X, kerb side +X), Y length (front bumper at
Y ~0, rear step at Y ~20.7), Z up (ground 0). Real size 6.8 x 2.3 x 2.9 m at 3 studs/m: cab half width 2.88 (1.92 m,
Wheels and beacons sit where LandVehicleConfig / Builder.luau puts them for the greybox ambulance (wheelbase 4.33 m,
track 1.71 m, wheel 0.72 m, seats RHD) so the mesh can replace the code-built body: separate wheel meshes at the
physics hubs, ATT_DriverSeat / ATT_EyePoint, blue beacons on the light bar, and the rear-door handover point.

Livery (invented, no cross of any kind): white base, high-vis yellow / green chequer bands, the hospital's
heart-over-waves roundel, "AMBULANCE" mirrored on the front for the mirror of the car ahead. Each part is generated
twice: LOD0 (g.hi False, chamfer bevels, low segments) and _HP (g.hi True, named materials, finer bevels, fasteners
and stamped detail that only the bake sees).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix

import vehgeo as V

STUDS_M = 3.0

# --------------------------------------------------------------------------- layout (studs)
L = 20.40                 # overall length 6.8 m
HW_BOX = 3.30             # box body half width (2.2 m); the 2.3 m row width is over the mirrors
HW_CAB = 2.88             # cab half width (1.92 m, Sprinter class)
NOSE = 0.62               # front face of the cab shell
CAB_R = 9.16              # box front wall (cab roof runs under it)
BOX_R = 20.20             # box rear skin
ROOF_BOX = 8.70           # 2.90 m
ROOF_CAB = 7.50           # 2.50 m
SKIN = 0.17               # panel thickness
Z_ROCKER = 1.28           # cab side bottom edge (0.43 m)
BOX_BOT = 1.60            # box skirt bottom (0.53 m)
BOX_UNDER = 1.30          # box underside (hidden)
WS_BASE, WS_TOP = 5.50, 7.26
SILL = 3.96               # cab window sill (1.32 m)
GLASS_TOP = 6.86          # cab window top (2.29 m)
WIN_LO, WIN_HI = 5.90, 7.24   # box windows, high up (1.97 to 2.41 m)
AX_F, AX_R = 3.00, 15.99
HUB_X = 2.565             # track 1.71 m
WHEEL_R, WHEEL_W = 1.08, 0.645
WHEEL_Z = WHEEL_R
ARCH_R = 1.42
ARCH_F = 1.30            # front arch cut (tighter than the box skirt cut)
SEAT_X = 1.512            # Builder: W * 0.24
FLOOR = 2.10
DOOR_F0, DOOR_F1 = 5.62, 8.44      # cab door
BOX_F = 9.16


def M(g, name, lo=None):
    return name if g.hi else (lo or name)


def P(x, y, z):
    return Vector((x, y, z))


# --------------------------------------------------------------------------- section helpers
def hw_cab(y):
    """Plan half width of the cab: tapers in toward the nose so the front is curved, not a slab."""
    if y >= 3.60:
        return HW_CAB
    t = max(0.0, min(1.0, (3.60 - y) / (3.60 - NOSE)))
    return HW_CAB - 0.40 * t ** 1.4


def bonnet_z(y):
    """Crown of the bonnet / shoulder line: 2.92 hand-high nose rising to the windscreen base."""
    t = max(0.0, min(1.0, (y - NOSE) / (WS_BASE - NOSE)))
    return 2.72 + 0.52 * t + 0.44 * t ** 3.4


def arch_z(y, base=Z_ROCKER, radius=ARCH_R, hy=AX_F):
    z = base
    d = abs(y - hy)
    if d < radius:
        z = max(z, WHEEL_Z + math.sqrt(radius * radius - d * d))
    elif d < radius + 0.22:
        t = (d - radius) / 0.22
        z = max(z, (WHEEL_Z + 0.06) * (1 - t) + base * t)
    return z


def side_top(y):
    """Top line of the side slab: bonnet shoulder, then the door window sill."""
    if y < WS_BASE:
        return bonnet_z(y) - 0.14
    return SILL


def side_stations():
    ys = [0.98, 1.35, 1.80, 2.30, 3.60, 4.40, 5.00, 5.44, 5.58, 6.40, 7.40, 8.40, 8.86, 9.10]
    for hy in (AX_F,):
        for k in range(13):
            ys.append(hy - ARCH_F - 0.22 + (2 * ARCH_F + 0.44) * k / 12)
    ys += [DOOR_F0, DOOR_F1]
    return sorted(set(round(y, 4) for y in ys if 0.95 <= y <= 9.12))


def cab_side_ring(side, y):
    """Closed XZ profile of the cab side slab at one station."""
    zb = arch_z(y, radius=ARCH_F)
    zt = side_top(y)
    hw = hw_cab(y)
    pts = [(hw, zb), (hw, zt - 0.06), (hw - 0.06, zt), (hw - SKIN, zt), (hw - SKIN, zb)]
    ring = [P(side * x, y, z) for x, z in pts]
    if side < 0:
        ring.reverse()
    return ring


def ring_profile(hw, zb, zt, r=0.26, n=5, arch=0.03):
    """Closed XZ profile with rounded top corners: (x, z) list, same count for every station."""
    out = [(-hw, zb)]
    for k in range(1, 4):
        a = math.pi * (1.0 - 0.5 * k / 3)
        out.append((-hw + r - r * math.cos(a), zt - r + r * math.sin(a)))
    for k in range(n):
        u = -1 + 2 * (k + 0.5) / n
        out.append((u * (hw - r), zt + arch * (1 - u * u)))
    for k in range(1, 4):
        a = math.pi * 0.5 * (1 - k / 3)
        out.append((hw - r + r * math.cos(a), zt - r + r * math.sin(a)))
    out.append((hw, zb))
    return out


def box_section(hw, y, top=ROOF_BOX):
    """Closed XZ profile of the box body at one station. The skirt edge arcs over the rear wheels while the
    underside stays flat, and the Y taper of `box_hw` rounds the vertical corners."""
    sb = arch_z(y, base=BOX_BOT, radius=ARCH_R + 0.14, hy=AX_R)
    return ring_profile(hw, sb, top, r=0.34, n=5, arch=0.05) + \
        [(hw - 0.42, BOX_UNDER), (hw * 0.45, BOX_UNDER), (0.0, BOX_UNDER), (-hw * 0.45, BOX_UNDER),
         (-hw + 0.42, BOX_UNDER)]


def box_stations():
    ys = [BOX_F, BOX_F + 0.20, BOX_F + 0.50, 10.9, 13.1]
    for k in range(9):
        ys.append(AX_R - ARCH_R - 0.28 + (2 * ARCH_R + 0.56) * k / 8)
    ys += [18.6, 19.5, 19.86, 20.06, BOX_R]
    return sorted(set(round(y, 4) for y in ys if BOX_F - 0.01 <= y <= BOX_R + 0.01))


def box_hw(y):
    if y < BOX_F + 0.46:
        return HW_BOX - 0.16 * ((BOX_F + 0.46 - y) / 0.46) ** 1.4
    if y > BOX_R - 0.34:
        return HW_BOX - 0.16 * ((y - (BOX_R - 0.34)) / 0.34) ** 1.4
    return HW_BOX


def plate(g, outline, y0, y1, mat, bev=0.0):
    """XZ outline extruded along Y (a door leaf, a rear panel)."""
    rings = [[P(x, y, z) for x, z in outline] for y in (y0, y1)]
    faces = g.rings(rings, mat, closed=True, cap0=True, cap1=True)
    g.bevel_sharp(faces, bev)
    return faces


def text_panel(g, body, size, mat, mapfn, orient, font_scale_x=1.0, resolution=2):
    me = V.text_mesh(body, size, font_scale_x=font_scale_x, resolution=resolution)
    fs = g.add_mesh(me, mat, mapfn)
    g.orient(fs, orient)
    bpy.data.meshes.remove(me)
    return fs


# --------------------------------------------------------------------------- cab exterior
def cab_sides(g):
    for side in (1, -1):
        rings = [cab_side_ring(side, y) for y in side_stations()]
        g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)


def nose_shell(g):
    stations = [(NOSE, 1.15), (0.70, 1.10), (0.86, 1.06), (1.10, 1.02), (1.50, 0.98),
                (2.10, 0.96), (2.80, 0.95), (3.60, 0.95), (4.40, 0.98), (5.10, 1.05), (WS_BASE, 1.15)]
    rings = []
    for y, zb in stations:
        hwm = max(0.3, hw_cab(y) - SKIN)
        rings.append([P(x, y, z) for x, z in ring_profile(hwm, zb, bonnet_z(y), r=0.34, n=5, arch=0.11)])
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    # bonnet crown bulge and shut lines
    if g.hi:
        V.box(g, (0, 3.30, bonnet_z(3.30) + 0.035), (2.30, 3.7, 0.06), "PaintWhite")
        for sx in (-1, 1):
            V.box(g, (sx * 1.86, 3.10, bonnet_z(3.10)), (0.02, 3.9, 0.02), "PaintWhite")
        V.box(g, (0, 1.10, bonnet_z(1.10) + 0.012), (2.10, 0.02, 0.02), "PaintWhite")


def front_panel(g):
    """Bowed front panel over the nose cap, with windows cut for the grille and the lamps, so the dark inserts
    sit genuinely behind the body surface (recessed headlights)."""
    xs = [-2.42, -2.34, -1.90, -1.44, -1.30, -0.66, 0.0, 0.66, 1.30, 1.44, 1.90, 2.34, 2.42]
    zs = [1.32, 1.72, 2.05, 2.18, 2.52, 2.84, 2.96]

    def surf(x, z):
        return 0.545 + 0.055 * (abs(x) / 2.42) ** 1.7 + 0.02 * max(0.0, (z - 1.32) / 1.64)

    def hole(x0, x1, z0, z1):
        return (abs((x0 + x1) / 2) <= 1.30 and z0 >= 2.05 - 1e-6) or                (1.30 < abs((x0 + x1) / 2) < 2.40 and z0 >= 2.14 - 1e-6)

    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            x0, x1, z0, z1 = xs[i], xs[i + 1], zs[j], zs[j + 1]
            if hole(x0, x1, z0, z1):
                continue
            vs = [g.bm.verts.new(P(x0, surf(x0, z0), z0)), g.bm.verts.new(P(x1, surf(x1, z0), z0)),
                  g.bm.verts.new(P(x1, surf(x1, z1), z1)), g.bm.verts.new(P(x0, surf(x0, z1), z1))]
            g.face(vs, M(g, "PaintWhite"))
    # bonnet leading edge over the front panel, and the panel's bottom rail
    V.box(g, (0, 0.575, 2.98), (4.86, 0.14, 0.16), M(g, "PaintWhite"), bev=0.05)
    V.box(g, (0, 0.60, 1.58), (4.90, 0.12, 0.14), M(g, "BumperPlastic"), bev=0.03)


def cab_grille(g):
    """Grille and lamps sit in proud surrounds, so the dark inserts read as recessed into the curved face."""
    V.box(g, (0, 0.575, 2.45), (2.86, 0.14, 0.80), M(g, "PaintWhite"), bev=0.10)
    V.box(g, (0, 0.645, 2.45), (2.50, 0.07, 0.78), M(g, "GrilleDark"), bev=0.04)
    for k in range(3):
        V.box(g, (0, 0.640, 2.20 + 0.24 * k), (2.40, 0.03, 0.09), M(g, "PaintWhite"), bev=0.02)
    # invented heart-over-waves badge on the grille (hospital mark, no cross)
    V.lathe(g, (0, 0.625, 2.45), (0, -1, 0), [(0.28, 0.0), (0.28, 0.03), (0.23, 0.05), (0.19, 0.04), (0.0, 0.045)],
            24 if g.hi else 16, M(g, "RoundelWhite"))
    heart_mark(g, (0, 0.575, 2.45), (0, -1, 0), 0.28, M(g, "LetterGreen"))
    for sx in (-1, 1):
        V.box(g, (sx * 1.76, 0.56, 2.50), (1.42, 0.16, 0.78), M(g, "PaintWhite"), bev=0.10)
        V.box(g, (sx * 1.76, 0.645, 2.50), (1.22, 0.07, 0.66), M(g, "GrilleDark"), bev=0.04)
        V.box(g, (sx * 1.76, 0.600, 2.52), (1.08, 0.05, 0.46), M(g, "LensWhite"), bev=0.04)
        V.lathe(g, (sx * 2.02, 0.595, 2.52), (0, -1, 0),
                [(0.18, 0.0), (0.18, 0.02), (0.15, 0.035), (0.0, 0.04)], 18 if g.hi else 14, M(g, "Chrome"))
        V.lathe(g, (sx * 2.02, 0.572, 2.52), (0, -1, 0), [(0.12, 0.0), (0.12, 0.012), (0.0, 0.02)],
                16 if g.hi else 12, M(g, "LensWhite"))
        V.box(g, (sx * 2.28, 0.600, 2.52), (0.26, 0.05, 0.40), M(g, "LensAmber"), bev=0.03)
        # blue grille strobes
        V.box(g, (sx * 0.84, 0.600, 2.62), (0.28, 0.05, 0.14), M(g, "LensBlue"), bev=0.02)
    if g.hi:
        for k in range(4):
            V.box(g, (0, 0.585, 2.30 + 0.28 * k), (2.40, 0.01, 0.015), "Chrome")


def bumper_front(g):
    V.box(g, (0, 0.66, 1.38), (5.42, 0.62, 0.48), M(g, "BumperPlastic"), bev=0.12)
    V.box(g, (0, 0.62, 1.80), (5.24, 0.40, 0.40), M(g, "PaintHiVis"), bev=0.10)
    V.box(g, (0, 0.62, 1.00), (4.60, 0.40, 0.30), M(g, "BumperPlastic"), bev=0.09)
    for sx in (-1, 1):
        V.lathe(g, (sx * 1.90, 0.52, 1.32), (0, -1, 0),
                [(0.22, 0.0), (0.22, 0.03), (0.18, 0.06), (0.15, 0.10), (0.0, 0.11)], 16, M(g, "Chrome"))
        V.lathe(g, (sx * 1.90, 0.44, 1.32), (0, -1, 0), [(0.15, 0.0), (0.15, 0.01), (0.0, 0.03)],
                14 if g.hi else 12, M(g, "LensWhite"))
        # chequer square ends and a tow eye
        V.box(g, (sx * 2.42, 0.66, 1.80), (0.62, 0.40, 0.40), M(g, "PaintGreen"), bev=0.10)
        V.box(g, (sx * 1.02, 0.44, 1.30), (0.28, 0.18, 0.22), M(g, "BlackMetal"), bev=0.05)
        V.tube(g, [(sx * 1.02 - 0.10, 0.52, 1.30), (sx * 1.02, 0.64, 1.30), (sx * 1.02 + 0.10, 0.52, 1.30)],
               0.055, M(g, "Chrome"), 8 if g.hi else 6, fillet=0.06)
    V.box(g, (0, 0.44, 1.52), (1.20, 0.03, 0.26), M(g, "PlateWhite"), bev=0.012)
    if g.hi:
        for sx in (-1, 1):
            for k in range(4):
                V.lathe(g, (sx * 0.44, 0.70, 1.30 + 0.10 * k), (0, -1, 0), [(0.02, 0.0), (0.02, 0.01)],
                        6, "BlackPlastic")


def cab_roof(g):
    ys = [7.00, 7.34, 7.90, 8.60, 9.02, 9.30]
    rings = []
    for y in ys:
        t = (y - 7.00) / (9.30 - 7.00)
        zt = ROOF_CAB - 0.20 + 0.20 * t
        hw = HW_CAB - 0.06
        rings.append([P(-hw, y, zt - 0.17), P(-hw, y, zt - 0.09), P(-hw + 0.06, y, zt - 0.02),
                      P(-hw * 0.55, y, zt + 0.02), P(0.0, y, zt + 0.03), P(hw * 0.55, y, zt + 0.02),
                      P(hw - 0.06, y, zt - 0.02), P(hw, y, zt - 0.09), P(hw, y, zt - 0.17), P(0.0, y, zt - 0.20)])
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    if g.hi:
        for k in range(3):
            V.box(g, (-1.30 + 1.30 * k, 8.20, ROOF_CAB - 0.02), (0.60, 1.90, 0.012), "PaintWhite")


def windscreen(g):
    cols = 6
    rows = []
    for r in range(4):
        t = r / 3
        y = WS_BASE + 0.04 + (WS_TOP - WS_BASE - 0.06) * t
        z = 3.60 + (GLASS_TOP + 0.44 - 3.60) * t
        row = []
        for c in range(cols + 1):
            u = -1 + 2 * c / cols
            row.append(P(u * 2.62, y + 0.10 * (1 - u * u), z))
        rows.append(row)
    faces = _sheet(g, rows, M(g, "Glass"))
    back = [[P(p.x, p.y + 0.05, p.z - 0.03) for p in row] for row in rows]
    _sheet(g, back, M(g, "Glass"), flip=True)
    # black surround, cowl and wipers
    V.box(g, (0, WS_BASE + 0.02, 3.52), (5.20, 0.16, 0.14), M(g, "GlassSeal"), bev=0.02)
    V.box(g, (0, WS_BASE - 0.10, 3.44), (5.30, 0.34, 0.10), M(g, "BlackPlastic"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 2.72, 6.36, 5.44), (0.10, 2.04, 3.90), M(g, "GlassSeal"),
              rot=Matrix.Rotation(math.radians(-21), 3, "X"), bev=0.02)
    V.box(g, (0, WS_TOP + 0.02, GLASS_TOP + 0.34), (5.36, 0.14, 0.14), M(g, "GlassSeal"), bev=0.02)
    V.box(g, (0, WS_BASE - 0.02, 3.40), (3.20, 0.09, 0.05), M(g, "BlackPlastic"), bev=0.01)


def wipers(g):
    for sx in (-1, 1):
        V.box(g, (sx * 1.10, WS_BASE + 0.06, 3.58), (1.16, 0.10, 0.06), M(g, "BlackPlastic"),
              rot=Matrix.Rotation(math.radians(7), 3, "X"), bev=0.01)
        V.box(g, (sx * 0.44, WS_BASE + 0.12, 3.58), (0.11, 0.11, 0.08), M(g, "BlackPlastic"), bev=0.01)


def cab_pillars(g):
    for side in (1, -1):
        x0, x1 = side * (HW_CAB - 0.24), side * HW_CAB
        if side < 0:
            x0, x1 = side * HW_CAB, side * (HW_CAB - 0.24)
        # A-pillar, raked with the windscreen
        V.extrude_profile(g, [(WS_BASE - 0.12, 3.52), (WS_BASE + 0.38, 3.52), (7.24, 7.22), (6.86, 7.26)],
                          min(x0, x1), max(x0, x1), M(g, "PaintWhite"), bev=0.04)
        # door window frame: sill rail, upper rail, B-pillar and the rear quarter
        V.box(g, (side * 2.80, 5.90, 3.60), (0.20, 0.80, 0.30), M(g, "PaintWhite"), bev=0.04)
        V.box(g, (side * 2.82, 7.20, SILL + 0.02), (0.16, 2.60, 0.24), M(g, "PaintWhite"), bev=0.03)
        V.box(g, (side * 2.80, 5.94, GLASS_TOP - 0.20), (0.20, 0.10, 0.62), M(g, "PaintWhite"), bev=0.03)
        V.box(g, (side * 2.82, 7.30, GLASS_TOP + 0.16), (0.16, 2.62, 0.56), M(g, "PaintWhite"), bev=0.05)
        V.box(g, (side * 2.64, 8.52, 5.60), (0.24, 0.32, 3.90), M(g, "BlackPlastic"), bev=0.03)
        V.box(g, (side * 2.82, 8.86, 5.40), (0.14, 0.42, 4.30), M(g, "PaintWhite"), bev=0.04)
        if g.hi:
            V.box(g, (side * 2.90, 7.30, GLASS_TOP + 0.16), (0.02, 2.60, 0.50), "PaintWhite")
            V.box(g, (side * 2.86, 8.60, 5.60), (0.02, 0.26, 3.80), "BlackPlastic")


def cab_door(g):
    for side in (1, -1):
        hw = HW_CAB + 0.015
        V.box(g, (side * (HW_CAB - 0.03), (DOOR_F0 + DOOR_F1) / 2, 2.62), (0.14, DOOR_F1 - DOOR_F0, 2.30),
              M(g, "PaintWhite"), bev=0.06)
        # shut lines and the window seal
        V.box(g, (side * hw, (DOOR_F0 + DOOR_F1) / 2, SILL - 0.06), (0.02, DOOR_F1 - DOOR_F0, 0.06), M(g, "GlassSeal"))
        V.box(g, (side * hw, DOOR_F0 + 0.02, 2.60), (0.02, 0.05, 2.30), M(g, "GlassSeal"))
        V.box(g, (side * hw, DOOR_F1 - 0.02, 2.60), (0.02, 0.05, 2.30), M(g, "GlassSeal"))
        V.box(g, (side * 2.80, 6.10, SILL + 0.06), (0.20, 0.34, 0.10), M(g, "GlassSeal"), bev=0.02)
        # handle, lock, hinge shadows
        V.box(g, (side * (HW_CAB + 0.03), 7.86, 3.42), (0.10, 0.56, 0.15), M(g, "BlackPlastic"), bev=0.04)
        V.box(g, (side * (HW_CAB + 0.05), 7.80, 3.42), (0.03, 0.34, 0.07), M(g, "Chrome"), bev=0.01)
        V.lathe(g, (side * (HW_CAB + 0.02), 8.10, 3.42), (side, 0, 0), [(0.07, 0.0), (0.07, 0.02), (0.0, 0.03)],
                12 if g.hi else 8, M(g, "Chrome"))
        # mirror: arm, housing, glass
        V.tube(g, [(side * (HW_CAB - 0.06), 6.30, 4.20), (side * (HW_CAB + 0.24), 6.22, 4.34),
                   (side * (HW_CAB + 0.38), 6.08, 4.46)], 0.065, M(g, "BlackPlastic"), 10 if g.hi else 8, fillet=0.12)
        V.box(g, (side * 3.06, 6.00, 4.60), (0.13, 0.40, 0.74), M(g, "BlackPlastic"), bev=0.06)
        V.box(g, (side * 3.14, 6.00, 4.60), (0.03, 0.34, 0.66), M(g, "Chrome"), bev=0.02)
        V.box(g, (side * 3.02, 6.26, 4.60), (0.10, 0.10, 0.70), M(g, "BlackPlastic"), bev=0.03)
        # step under the door
        V.box(g, (side * 2.62, 7.00, 1.24), (0.44, 2.30, 0.20), M(g, "BlackPlastic"), bev=0.06)
        V.box(g, (side * 2.62, 7.00, 1.36), (0.38, 2.10, 0.04), M(g, "Rubber"), bev=0.02)
        if g.hi:
            V.box(g, (side * 3.04, 5.96, 4.86), (0.02, 0.04, 0.06), "LensAmber")


def cab_body(g):
    cab_sides(g)
    nose_shell(g)
    cab_roof(g)
    cab_pillars(g)
    cab_door(g)


# --------------------------------------------------------------------------- shared bits
def _sheet(g, rows, mat, flip=False):
    """Quad grid from rows of points, single sided, wound to the grid normal."""
    vs = [[g.bm.verts.new(p) for p in row] for row in rows]
    faces = []
    for r in range(len(rows) - 1):
        for c in range(len(rows[0]) - 1):
            quad = (vs[r][c], vs[r][c + 1], vs[r + 1][c + 1], vs[r + 1][c])
            if flip:
                quad = tuple(reversed(quad))
            f = g.face(quad, mat)
            if f:
                faces.append(f)
    bmesh.ops.recalc_face_normals(g.bm, faces=faces)
    return faces


def _plane_axes(n):
    n = Vector(n).normalized()
    up = Vector((0, 0, 1))
    e1 = n.cross(up)
    if e1.length < 1e-5:
        e1 = Vector((1, 0, 0))
    return e1.normalized(), up


def heart_mark(g, origin, normal, size, mat, thick=0.035):
    """Invented heart-over-waves mark (matches the Cottage Hospital roundel; no cross)."""
    o = Vector(origin)
    n = Vector(normal).normalized()
    e1, e2 = _plane_axes(n)
    base = o + n * 0.02
    pts = []
    for k in range(23):
        t = 2 * math.pi * k / 22
        hx = 16 * math.sin(t) ** 3 / 17.0
        hy = (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17.0
        pts.append(base + e1 * (hx * size * 0.62) + e2 * ((hy + 0.42) * size * 0.62))
    V.sweep(g, pts, V.circle_profile(thick * size * 3.0, 8 if g.hi else 6), mat, closed=True)
    for row, dz in ((0, -0.52), (1, -0.86)):
        for k in range(2):
            cx = (-0.62 if k == 0 else 0.02) * size + 0.30 * size * row
            arc = []
            for j in range(7):
                a = math.pi * (1 - j / 6)
                arc.append(base + e1 * ((cx + 0.60 * size * math.cos(a))) + e2 * (dz * size + 0.34 * size * math.sin(a)))
            V.sweep(g, arc, V.circle_profile(thick * size * 2.4, 8 if g.hi else 6), mat, closed=False)
    if g.hi:
        V.box(g, tuple(base + n * 0.004), (size * 1.9, size * 1.9, 0.004), mat)


def cabin_glass(g):
    for side in (1, -1):
        for lo, hi in ((DOOR_F0 + 0.12, DOOR_F1 - 0.12),):
            rows = [[P(side * 2.78, lo, SILL + 0.10), P(side * 2.78, hi, SILL + 0.10)],
                    [P(side * 2.78, lo, GLASS_TOP - 0.08), P(side * 2.78, hi, GLASS_TOP - 0.08)]]
            _sheet(g, rows, M(g, "Glass"), flip=(side < 0))
            V.box(g, (side * 2.82, (lo + hi) / 2, SILL + 0.04), (0.10, hi - lo, 0.12), M(g, "GlassSeal"))
            V.box(g, (side * 2.82, (lo + hi) / 2, GLASS_TOP - 0.01), (0.10, hi - lo, 0.12), M(g, "GlassSeal"))
            V.box(g, (side * 2.82, lo + 0.02, (SILL + GLASS_TOP) / 2), (0.10, 0.11, GLASS_TOP - SILL),
                  M(g, "GlassSeal"))
            V.box(g, (side * 2.82, hi - 0.02, (SILL + GLASS_TOP) / 2), (0.10, 0.11, GLASS_TOP - SILL),
                  M(g, "GlassSeal"))
            V.box(g, (side * 2.80, (lo + hi) / 2, 4.92), (0.03, 0.05, GLASS_TOP - SILL), M(g, "BlackPlastic"))


# --------------------------------------------------------------------------- cab interior
def seat(g, x, cy, cushion_z, back_top, width):
    V.box(g, (x, cy, (FLOOR + cushion_z) / 2 + 0.15), (width * 0.86, 0.80, max(0.3, cushion_z - FLOOR)),
          M(g, "InteriorDark"), bev=0.05)
    V.box(g, (x, cy, cushion_z + 0.06), (width, 0.96, 0.24), M(g, "InteriorMid"), bev=0.10)
    for sx in (-1, 1):
        V.box(g, (x + sx * (width / 2 - 0.05), cy, cushion_z + 0.13), (0.13, 0.90, 0.20), M(g, "InteriorMid"), bev=0.05)
    rot = Matrix.Rotation(math.radians(-18), 3, "X")
    V.box(g, (x, cy + 0.60, cushion_z + (back_top - cushion_z) / 2), (width, 0.22, back_top - cushion_z),
          M(g, "InteriorMid"), rot=rot, bev=0.10)
    V.box(g, (x, cy + 0.58, cushion_z + (back_top - cushion_z) * 0.60), (width * 0.66, 0.25,
          (back_top - cushion_z) * 0.66), M(g, "SeatFabric"), rot=rot, bev=0.06)
    V.box(g, (x, cy + 0.72, back_top + 0.18), (0.64, 0.22, 0.32), M(g, "InteriorMid"), bev=0.09)
    if g.hi:
        for k in range(4):
            V.box(g, (x, cy + 0.49 - 0.15 * k, cushion_z + 0.19), (width * 0.74, 0.02, 0.012), "SeatFabric")


def cab_interior(g):
    V.box(g, (0, 6.30, FLOOR - 0.06), (5.30, 8.30, 0.12), M(g, "Carpet"), bev=0.02)
    V.box(g, (0, 6.70, FLOOR + 0.10), (1.10, 4.60, 0.24), M(g, "Carpet"), bev=0.06)
    # dashboard (RHD: driver sits on Blender -X)
    V.box(g, (0, 5.10, 3.86), (5.34, 0.72, 0.96), M(g, "InteriorDark"), bev=0.08)
    V.box(g, (0, 5.04, 4.36), (5.30, 0.78, 0.16), M(g, "InteriorDark"), bev=0.04)
    V.box(g, (0, 4.80, 3.06), (5.24, 0.22, 0.90), M(g, "InteriorDark"), bev=0.05)
    V.box(g, (0, 5.36, 4.42), (5.26, 0.14, 0.06), M(g, "InteriorMid"), bev=0.01)
    V.box(g, (-SEAT_X, 5.34, 4.24), (1.16, 0.26, 0.36), M(g, "InteriorDark"), bev=0.06)
    V.box(g, (-SEAT_X, 5.22, 4.20), (1.04, 0.05, 0.28), M(g, "Screen"), bev=0.02)
    V.box(g, (0.06, 5.36, 4.02), (0.94, 0.10, 0.54), M(g, "InteriorDark"), bev=0.03)
    V.box(g, (0.06, 5.30, 4.04), (0.82, 0.03, 0.44), M(g, "Screen"), bev=0.02)
    for k in range(3):
        V.box(g, (-0.80 + 0.16 * k, 5.32, 3.52), (0.13, 0.06, 0.42), M(g, "InteriorMid"), bev=0.02)
    V.box(g, (0, 6.00, 2.92), (0.96, 1.90, 0.90), M(g, "InteriorDark"), bev=0.07)
    V.box(g, (0, 5.90, 3.40), (0.86, 1.50, 0.06), M(g, "InteriorMid"), bev=0.02)
    V.tube(g, [(0, 6.40, 3.38), (0, 6.34, 3.74)], 0.05, M(g, "Chrome"), 8 if g.hi else 6)
    # steering wheel, raked
    c = P(-SEAT_X, 5.66, 4.24)
    u = P(0, math.sin(math.radians(-23)), math.cos(math.radians(-23)))
    v = P(1, 0, 0)
    path = [c + u * (0.64 * math.cos(2 * math.pi * k / 22)) + v * (0.64 * math.sin(2 * math.pi * k / 22))
            for k in range(22)]
    path.append(path[0])
    V.sweep(g, path, V.circle_profile(0.08, 8 if g.hi else 6), M(g, "BlackPlastic"), closed=True)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        V.tube(g, [tuple(c + u * 0.10), tuple(c + u * (0.62 * math.cos(a)) + v * (0.62 * math.sin(a)))],
               0.06, M(g, "InteriorMid"), 8 if g.hi else 6)
    V.lathe(g, tuple(c), (0, -u.y, -u.z), [(0.21, 0.0), (0.21, 0.06), (0.15, 0.11), (0.0, 0.12)],
            16 if g.hi else 12, M(g, "InteriorDark"))
    V.tube(g, [tuple(c - u * 0.06), (-SEAT_X, 5.30, 3.96)], 0.10, M(g, "InteriorDark"), 10 if g.hi else 8)
    # seats: RHD pair at the front, the stretcher bay is walled off behind the bulkhead
    seat(g, -SEAT_X, 6.62, 2.62, 4.40, 1.16)
    seat(g, SEAT_X, 6.62, 2.62, 4.40, 1.16)
    # bulkhead to the closed box (no interior until P1): a panel with a small sleeping window
    V.box(g, (0, 9.02, 4.80), (5.34, 0.16, 3.60), M(g, "InteriorMid"), bev=0.05)
    V.box(g, (0, 9.02, 6.72), (5.34, 0.16, 0.30), M(g, "InteriorDark"), bev=0.03)
    V.box(g, (0, 8.98, 6.72), (1.50, 0.06, 0.60), M(g, "Glass"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 1.10, 8.98, 6.72), (0.20, 0.08, 0.66), M(g, "InteriorDark"), bev=0.03)
    V.box(g, (0, 9.02, 3.20), (5.34, 0.10, 0.60), M(g, "InteriorDark"), bev=0.03)
    # headliner and trim
    V.box(g, (0, 7.60, ROOF_CAB - 0.36), (5.30, 5.20, 0.06), M(g, "Headliner"), bev=0.02)
    for sx in (-1, 1):
        V.box(g, (sx * 2.50, 7.20, 4.90), (0.14, 5.60, 4.10), M(g, "InteriorMid"), bev=0.03)
        V.box(g, (sx * 2.44, 7.20, 3.60), (0.16, 5.60, 0.24), M(g, "InteriorDark"), bev=0.03)
        V.box(g, (sx * 2.44, 7.20, 4.86), (0.16, 5.20, 0.12), M(g, "InteriorDark"), bev=0.02)
    V.box(g, (0, 5.40, 6.90), (4.30, 0.12, 0.90), M(g, "Headliner"), bev=0.04)
    if g.hi:
        for k in range(3):
            V.box(g, (-1.20 + 1.20 * k, 7.20, 3.42), (0.60, 5.00, 0.02), "InteriorMid")


# --------------------------------------------------------------------------- box body
SLIDE = (12.40, 15.40)          # kerb-side sliding door
BOX_WIN = {1: [(9.90, 12.20), (12.72, 15.08), (16.30, 19.50)],
           -1: [(9.90, 12.20), (13.40, 16.20), (17.00, 19.60)]}


def box_shell(g):
    rings = [[P(x, y, z) for x, z in box_section(box_hw(y), y)] for y in box_stations()]
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    if g.hi:
        for y in (10.4, 13.0, 15.6, 18.2):
            V.box(g, (0, y, ROOF_BOX + 0.03), (6.20, 0.06, 0.02), "PaintWhite")
        for side in (1, -1):     # stamped side ribs
            for y in (9.7, 11.4, 13.2, 15.0, 16.8, 18.6):
                V.box(g, (side * (HW_BOX + 0.005), y, 4.60), (0.02, 0.10, 3.60), "PaintWhite")


def box_front(g):
    """Pod face over the cab: mirrored AMBULANCE (reads in the mirror of the car ahead), strobes, vents."""
    V.box(g, (0, BOX_F - 0.06, 7.10), (5.30, 0.14, 0.70), M(g, "PaintWhite"), bev=0.05)
    text_panel(g, "AMBULANCE", 0.62, M(g, "LetterGreen"),
               lambda co: P(-co.x, BOX_F - 0.10, 8.14 + co.y), lambda c: P(0, -1, 0))
    for sx in (-1, 1):
        V.box(g, (sx * 2.42, BOX_F - 0.06, 8.06), (0.44, 0.12, 0.36), M(g, "GrilleDark"), bev=0.04)
        V.box(g, (sx * 2.42, BOX_F - 0.10, 8.06), (0.34, 0.06, 0.26), M(g, "LensBlue"), bev=0.03)
    V.box(g, (0, BOX_F - 0.02, 8.62), (6.10, 0.16, 0.16), M(g, "PaintWhite"), bev=0.04)


def box_side_windows(g):
    for side in (1, -1):
        for lo, hi in BOX_WIN[side]:
            rows = [[P(side * (HW_BOX + 0.01), lo, WIN_LO), P(side * (HW_BOX + 0.01), hi, WIN_LO)],
                    [P(side * (HW_BOX + 0.01), lo, WIN_HI), P(side * (HW_BOX + 0.01), hi, WIN_HI)]]
            _sheet(g, rows, M(g, "Glass"), flip=(side < 0))
            x = side * (HW_BOX + 0.03)
            V.box(g, (x, (lo + hi) / 2, WIN_LO - 0.07), (0.10, hi - lo + 0.30, 0.16), M(g, "PaintWhite"), bev=0.03)
            V.box(g, (x, (lo + hi) / 2, WIN_HI + 0.07), (0.10, hi - lo + 0.30, 0.16), M(g, "PaintWhite"), bev=0.03)
            for y in (lo - 0.07, hi + 0.07):
                V.box(g, (x, y, (WIN_LO + WIN_HI) / 2), (0.10, 0.16, WIN_HI - WIN_LO + 0.14), M(g, "PaintWhite"),
                      bev=0.03)


def sliding_door(g):
    side = 1        # nearside (kerb)
    y0, y1 = SLIDE
    x = side * (HW_BOX - 0.07)
    V.box(g, (side * (HW_BOX - 0.03), (y0 + y1) / 2, 4.95), (0.16, y1 - y0, 5.30), M(g, "PaintWhite"), bev=0.07)
    # tracks, handle and shut lines
    V.box(g, (side * (HW_BOX - 0.01), (y0 + y1) / 2, 7.70), (0.20, y1 - y0 - 1.10, 0.14), M(g, "BlackPlastic"), bev=0.02)
    V.box(g, (side * (HW_BOX - 0.01), (y0 + y1) / 2, 2.22), (0.20, y1 - y0 - 1.10, 0.14), M(g, "BlackPlastic"), bev=0.02)
    V.box(g, (x, y1 - 0.06, 5.00), (0.02, 0.10, 5.30), M(g, "GlassSeal"))
    V.box(g, (x, y0 + 0.06, 5.00), (0.02, 0.10, 5.30), M(g, "GlassSeal"))
    V.box(g, (side * (HW_BOX - 0.10), y1 + 0.22, 4.60), (0.14, 0.50, 0.18), M(g, "BlackPlastic"), bev=0.05)
    V.box(g, (side * (HW_BOX - 0.16), y1 + 0.18, 4.60), (0.05, 0.34, 0.09), M(g, "Chrome"), bev=0.015)
    V.box(g, (side * (HW_BOX - 0.07), y1 + 0.16, 2.70), (0.12, 0.26, 0.40), M(g, "BlackPlastic"), bev=0.04)
    if g.hi:
        V.box(g, (x, (y0 + y1) / 2, 5.00), (0.01, 0.02, 5.20), "PaintWhite")


def arch_trims(g, front=True):
    rows = ((AX_F, ARCH_F),) if front else ((AX_R + 0.05, ARCH_R + 0.14),)
    for side in (1, -1):
        for hy, r in rows:
            hw = HW_CAB + 0.02 if hy == AX_F else HW_BOX + 0.03
            pts = []
            for k in range(13):
                a = math.radians(-100 + 200 * k / 12)
                pts.append(P(side * hw, hy + (r + 0.03) * math.sin(a), WHEEL_Z + (r + 0.03) * math.cos(a)))
            prof = [(0.0, -0.20), (0.055 * side, -0.24), (0.085 * side, -0.16), (0.085 * side, 0.13),
                    (0.055 * side, 0.22), (0.0, 0.24)]
            V.sweep(g, pts, prof, M(g, "ArchPlastic"), closed=True, cap0=True, cap1=True)
            if g.hi:
                for k in range(5):
                    a = math.radians(-70 + 140 * k / 4)
                    V.lathe(g, (side * (hw + 0.07), hy + (r + 0.03) * math.sin(a),
                                WHEEL_Z + (r + 0.03) * math.cos(a)), (side, 0, 0),
                            [(0.035, 0.0), (0.035, 0.012), (0.0, 0.016)], 8, "BlackPlastic")


def box_roof(g):
    for side in (1, -1):
        V.box(g, (side * 2.98, 14.90, ROOF_BOX + 0.05), (0.24, 10.40, 0.14), M(g, "PaintWhite"), bev=0.04)
    V.box(g, (0, 14.90, ROOF_BOX + 0.00), (1.20, 10.40, 0.10), M(g, "PaintWhite"), bev=0.03)
    # ventilation and air-conditioning unit
    V.box(g, (0.90, 11.30, ROOF_BOX + 0.15), (1.60, 1.30, 0.30), M(g, "PaintWhite"), bev=0.08)
    V.box(g, (0.90, 11.30, ROOF_BOX + 0.31), (1.20, 1.00, 0.06), M(g, "GrilleDark"), bev=0.02)
    V.lathe(g, (-1.10, 18.30, ROOF_BOX + 0.00), (0, 0, 1),
            [(0.42, 0.0), (0.42, 0.05), (0.34, 0.08), (0.30, 0.26), (0.24, 0.33), (0.0, 0.35)],
            16 if g.hi else 12, M(g, "PaintWhite"))
    V.lathe(g, (-1.10, 18.30, ROOF_BOX + 0.36), (0, 0, 1), [(0.30, 0.0), (0.30, 0.03), (0.0, 0.04)],
            14 if g.hi else 10, M(g, "Chrome"))
    V.tube(g, [(-2.90, 19.60, ROOF_BOX + 0.02), (-2.90, 19.60, ROOF_BOX + 0.40)], 0.035, M(g, "BlackPlastic"), 6)
    # roof corner beacons (blue) and the flat rear light bar
    for sx in (-1, 1):
        beacon(g, (sx * 2.34, 9.62, ROOF_BOX - 0.06), 0.32, M(g, "LensBlue"))
        beacon(g, (sx * 2.34, 19.86, ROOF_BOX - 0.06), 0.28, M(g, "LensBlue"))
    V.box(g, (0, 20.02, ROOF_BOX + 0.10), (3.30, 0.16, 0.16), M(g, "BlackPlastic"), bev=0.03)


def beacon(g, pos, r, mat):
    x, y, z = pos
    V.box(g, (x, y, z + 0.02), (r * 2.0, r * 1.4, 0.10), M(g, "BeaconMount"), bev=0.03)
    V.lathe(g, (x, y, z + 0.05), (0, 0, 1),
            [(r, 0.0), (r, 0.05), (r * 0.92, 0.14), (r * 0.80, 0.24), (r * 0.62, 0.32), (r * 0.34, 0.37), (0.0, 0.39)],
            18 if g.hi else 12, mat)
    if g.hi:
        V.lathe(g, (x, y, z + 0.05), (0, 0, 1), [(r * 0.9, 0.0), (r * 0.9, 0.02)], 12, "BeaconMount")


def light_bar(g):
    """Cab roof light bar with four blue beacons (LandVehicleConfig. Ambulance lightBar QuadFlash)."""
    V.box(g, (0, 7.30, ROOF_CAB + 0.10), (4.60, 0.34, 0.10), M(g, "BeaconMount"), bev=0.03)
    V.box(g, (0, 7.30, ROOF_CAB + 0.22), (4.44, 0.28, 0.18), M(g, "BeaconMount"), bev=0.04)
    V.box(g, (0, 7.30, ROOF_CAB + 0.32), (4.36, 0.24, 0.08), M(g, "BlackPlastic"), bev=0.03)
    for x in (-1.62, -0.54, 0.54, 1.62):
        V.lathe(g, (x, 7.30, ROOF_CAB + 0.35), (0, 0, 1),
                [(0.28, 0.0), (0.28, 0.04), (0.26, 0.10), (0.22, 0.22), (0.14, 0.32), (0.0, 0.35)],
                18 if g.hi else 14, M(g, "LensBlue"),
                matfn=(lambda i, j: "BeaconMount" if i <= 1 else "LensBlue") if g.hi else None)
    for sx in (-1, 1):
        V.box(g, (sx * 2.32, 7.30, ROOF_CAB + 0.14), (0.14, 0.30, 0.16), M(g, "BeaconMount"), bev=0.03)
    if g.hi:
        for x in (-1.08, 0.0, 1.08):
            V.box(g, (x, 7.30, ROOF_CAB + 0.24), (0.06, 0.26, 0.10), "BeaconMount")


def rear_doors(g):
    yr = BOX_R
    for side in (1, -1):
        x_in, x_out = side * 0.10, side * 3.14
        lo, hi = min(x_in, x_out), max(x_in, x_out)
        outline = [(lo, 1.88), (lo, 8.20), (lo + 0.30 * (1 if side > 0 else 1), 8.42),
                   (hi - 0.40, 8.44), (hi, 8.14), (hi, 1.88)]
        if side < 0:
            outline = [(lo, 8.14), (lo + 0.40, 8.44), (hi - 0.30, 8.42), (hi, 8.20), (hi, 1.88), (lo, 1.88)]
        plate(g, outline, yr + 0.02, yr + 0.16, M(g, "PaintWhite"), bev=0.06)
        # window
        wl, wh = side * 0.62, side * 2.72
        l, h = min(wl, wh), max(wl, wh)
        rows = [[P(l, yr + 0.17, 5.34), P(h, yr + 0.17, 5.34)], [P(l, yr + 0.17, 7.16), P(h, yr + 0.17, 7.16)]]
        _sheet(g, rows, M(g, "Glass"), flip=(side < 0))
        V.box(g, ((l + h) / 2, yr + 0.12, 5.28), (h - l + 0.30, 0.14, 0.20), M(g, "PaintWhite"), bev=0.03)
        V.box(g, ((l + h) / 2, yr + 0.12, 7.22), (h - l + 0.30, 0.14, 0.20), M(g, "PaintWhite"), bev=0.03)
        for x in (l - 0.07, h + 0.07):
            V.box(g, (x, yr + 0.12, 6.25), (0.16, 0.14, 2.06), M(g, "PaintWhite"), bev=0.03)
        V.box(g, ((l + h) / 2, yr + 0.06, 6.25), (h - l, 0.10, 1.86), M(g, "GrilleDark"))
        # hinges, latch bar and handle
        for z in (2.20, 4.60, 7.30):
            V.box(g, (side * 3.10, yr + 0.19, z), (0.24, 0.20, 0.30), M(g, "Chrome"), bev=0.05)
        V.box(g, (side * 0.30, yr + 0.22, 4.10), (0.16, 0.16, 1.10), M(g, "BlackPlastic"), bev=0.04)
        V.box(g, (side * 0.30, yr + 0.30, 3.90), (0.10, 0.12, 0.40), M(g, "Chrome"), bev=0.03)
        V.lathe(g, (side * 0.30, yr + 0.24, 3.28), (0, 1, 0), [(0.13, 0.0), (0.13, 0.05), (0.09, 0.09), (0.0, 0.10)],
                12 if g.hi else 9, M(g, "Chrome"))
        V.box(g, ((l + h) / 2, yr + 0.19, 2.02), (h - l, 0.06, 0.24), M(g, "PaintGreen"), bev=0.02)
        # reflective chevrons below the windows
        n = 4 if not g.hi else 5
        span = (l + 0.20, h - 0.20)
        for k in range(n):
            col = "ReflRed" if (k + (0 if side > 0 else 1)) % 2 == 0 else "ReflYellow"
            xc = span[0] + (span[1] - span[0]) * (k + 0.5) / n
            V.box(g, (xc, yr + 0.18, 3.18), ((span[1] - span[0]) / n + 0.10, 0.03, 2.20), M(g, col),
                  rot=Matrix.Rotation(math.radians(-34 * side), 3, "Y"))


def rear_assembly(g):
    # step, bumper, lamps, grab handles
    V.box(g, (0, BOX_R + 0.42, 1.02), (3.20, 0.30, 0.18), M(g, "BlackMetal"), bev=0.04)
    V.box(g, (0, BOX_R + 0.42, 1.12), (3.00, 0.26, 0.04), M(g, "Rubber"), bev=0.02)
    for sx in (-1, 1):
        V.tube(g, [(sx * 1.30, BOX_R + 0.16, 1.02), (sx * 1.30, BOX_R + 0.46, 1.02)], 0.07, M(g, "BlackMetal"),
               8 if g.hi else 6)
    V.box(g, (0, BOX_R + 0.30, 1.58), (6.20, 0.44, 0.44), M(g, "BumperPlastic"), bev=0.10)
    V.box(g, (0, BOX_R + 0.36, 1.34), (5.40, 0.32, 0.12), M(g, "PaintHiVis"), bev=0.04)
    for sx in (-1, 1):
        V.box(g, (sx * 2.86, BOX_R + 0.34, 2.32), (0.62, 0.24, 0.66), M(g, "BlackPlastic"), bev=0.06)
        V.box(g, (sx * 2.86, BOX_R + 0.46, 2.50), (0.50, 0.05, 0.30), M(g, "LensRed"), bev=0.02)
        V.box(g, (sx * 2.86, BOX_R + 0.46, 2.14), (0.50, 0.05, 0.26), M(g, "LensRed"), bev=0.02)
        V.box(g, (sx * 2.86, BOX_R + 0.46, 1.86), (0.44, 0.05, 0.20), M(g, "LensAmber"), bev=0.02)
        V.box(g, (sx * 2.58, BOX_R + 0.46, 1.86), (0.14, 0.05, 0.20), M(g, "LensReverse"), bev=0.015)
        V.box(g, (sx * 1.86, BOX_R + 0.30, 2.32), (1.30, 0.20, 0.30), M(g, "BumperPlastic"), bev=0.05)
    if g.hi:
        for sx in (-1, 1):
            for k in range(3):
                V.lathe(g, (sx * 2.86, BOX_R + 0.50, 2.86 + 0.0 * k), (0, 1, 0),
                        [(0.03, 0.0), (0.03, 0.01)], 6, "BlackPlastic")


# --------------------------------------------------------------------------- livery (invented, no cross)
def chequer(g, x, y0, y1, z0, z1, cell):
    """High-vis yellow / green chequer band: two rows of alternating squares (invented battenburg)."""
    n = max(2, int(round((y1 - y0) / cell)))
    w = (y1 - y0) / n
    for i in range(n):
        for row in (0, 1):
            mat = "PaintGreen" if (i + row) % 2 == 0 else "PaintHiVis"
            V.box(g, (x, y0 + w * (i + 0.5), z0 + (z1 - z0) * (row + 0.5) / 2),
                  (0.03, w - 0.055, (z1 - z0) / 2 - 0.055), M(g, mat), bev=0.0)


def livery_cab(g):
    for side in (1, -1):
        chequer(g, side * (HW_CAB + 0.035), 5.72, 8.36, 2.32, 3.30, 0.44)


def livery_box(g):
    for side in (1, -1):
        x = side * (HW_BOX + 0.035)
        cell = 0.80 if not g.hi else 0.48
        chequer(g, x, 9.60, 16.10, 2.55, 3.45, cell)
        chequer(g, x, 16.70, 20.10, 2.55, 3.45, cell)
        text_panel(g, "AMBULANCE", 0.80, M(g, "LetterGreen"),
                   lambda co, s=side, xx=x: P(xx, 17.90 + co.x, 4.55 + co.y),
                   lambda c, s=side: P(s, 0, 0))
        text_panel(g, "GALE ISLES AMBULANCE", 0.34, M(g, "LetterDark"),
                   lambda co, s=side, xx=x: P(xx, 17.60 + co.x, 5.35 + co.y),
                   lambda c, s=side: P(s, 0, 0), resolution=1)
        # heart-over-waves roundel (the Cottage Hospital mark)
        V.lathe(g, (x, 11.60, 4.95), (side, 0, 0),
                [(0.0, 0.0), (0.62, 0.0), (0.62, 0.045), (0.54, 0.075), (0.50, 0.055), (0.0, 0.055)],
                26 if g.hi else 20, M(g, "RoundelWhite"))
        heart_mark(g, (x + side * 0.045, 11.60, 4.95), (side, 0, 0), 0.50, M(g, "LetterGreen"))
    text_panel(g, "AMBULANCE", 0.62, M(g, "LetterGreen"),
               lambda co: P(-co.x, BOX_R + 0.20, 4.72 + co.y), lambda c: P(0, 1, 0))
    for side in (1, -1):
        V.lathe(g, (side * 2.46, BOX_R + 0.19, 4.70), (0, 1, 0),
                [(0.0, 0.0), (0.38, 0.0), (0.38, 0.03), (0.32, 0.05), (0.29, 0.04), (0.0, 0.04)],
                22 if g.hi else 16, M(g, "RoundelWhite"))
        heart_mark(g, (side * 2.46, BOX_R + 0.22, 4.70), (0, 1, 0), 0.32, M(g, "LetterGreen"))


# --------------------------------------------------------------------------- wheels / underbody
def tyre(g, cx, side):
    profile = [(0.60, 0.29), (0.74, 0.32), (0.90, 0.355), (1.00, 0.365), (1.06, 0.33), (1.08, 0.25),
               (1.08, -0.25), (1.06, -0.33), (1.00, -0.365), (0.90, -0.355), (0.74, -0.32), (0.60, -0.29)]
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0), [(r, h * side) for r, h in profile], 20 if g.hi else 18, M(g, "Tyre"))
    n = 16 if g.hi else 13
    for row, xo in ((0, -0.17), (1, 0.17)):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * row) / n
            V.box(g, (cx + xo * side, 1.045 * math.sin(a), WHEEL_Z + 1.045 * math.cos(a)),
                  (0.28, 0.26, 0.06), M(g, "Tyre"), rot=Matrix.Rotation(-a, 3, "X"), bev=0.0)
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0),
            [(0.0, 0.28 * side), (0.30, 0.28 * side), (0.34, 0.23 * side), (0.64, 0.20 * side),
             (0.70, 0.10 * side), (0.70, -0.20 * side), (0.64, -0.32 * side)],
            18 if g.hi else 14, M(g, "RimSilver"))
    face = cx + side * 0.21
    for k in range(6):
        a = math.radians(60 * k + 30)
        V.lathe(g, (face, 0.40 * math.sin(a), WHEEL_Z + 0.40 * math.cos(a)), (side, 0, 0),
                [(0.13, -0.02), (0.13, 0.02), (0.10, 0.035), (0.0, 0.035)], 10 if g.hi else 8, M(g, "RimDark"))
    V.lathe(g, (face, 0, WHEEL_Z), (side, 0, 0),
            [(0.0, 0.0), (0.21, 0.0), (0.21, 0.04), (0.17, 0.07), (0.0, 0.08)], 16 if g.hi else 12, M(g, "RimSilver"))
    for k in range(5):
        a = math.radians(72 * k)
        V.lathe(g, (face, 0.135 * math.sin(a), WHEEL_Z + 0.135 * math.cos(a)), (side, 0, 0),
                [(0.05, 0.04), (0.05, 0.07), (0.0, 0.075)], 6, M(g, "Chrome"))
    V.tube(g, [(face, 0.10, WHEEL_Z + 0.28), (face, 0.12, WHEEL_Z + 0.40)], 0.03, M(g, "BlackPlastic"), 6)
    if g.hi:
        V.box(g, (face - side * 0.02, 0.0, WHEEL_Z - 0.40), (0.02, 0.28, 0.05), "RimSilver")


def wheel(g, side, front):
    start = len(g.bm.verts)
    tyre(g, 0.0, side)
    g.bm.verts.ensure_lookup_table()
    cy = AX_F if front else AX_R
    for v in g.bm.verts[start:]:
        v.co = P(v.co.x + side * HUB_X, v.co.y + cy, v.co.z)


def underbody(g):
    for sx in (-1, 1):
        V.box(g, (sx * 0.92, 11.0, 1.22), (0.28, 19.0, 0.34), M(g, "BlackMetal"), bev=0.03)
    for y in (2.2, 5.6, 8.8, 11.6, 14.6, 17.6, 19.6):
        V.box(g, (0, y, 1.20), (2.10, 0.22, 0.24), M(g, "BlackMetal"), bev=0.02)
    # front axle, springs, dampers, brakes
    V.tube(g, [(-HUB_X + 0.10, AX_F, WHEEL_Z), (HUB_X - 0.10, AX_F, WHEEL_Z)], 0.13, M(g, "BlackMetal"),
           12 if g.hi else 10)
    V.lathe(g, (0.14, AX_F, WHEEL_Z), (1, 0, 0),
            [(0.0, -0.34), (0.26, -0.30), (0.36, -0.14), (0.36, 0.14), (0.24, 0.30), (0.0, 0.32)],
            14 if g.hi else 10, M(g, "BrakeSteel"))
    for sx in (-1, 1):
        V.box(g, (sx * 1.60, AX_F + 0.10, 1.10), (1.60, 0.26, 0.16), M(g, "BlackMetal"), bev=0.0)
        V.lathe(g, (sx * 1.66, AX_F, 1.86), (0, 0, 1),
                [(0.36, 0.0), (0.36, 0.07), (0.30, 0.10), (0.0, 0.11)], 12 if g.hi else 8, M(g, "BlackMetal"))
        V.box(g, (sx * 1.66, AX_F + 0.22, 1.52), (0.22, 0.22, 1.30), M(g, "BrakeSteel"), bev=0.0)
        V.lathe(g, (sx * (HUB_X - 0.12), AX_F, WHEEL_Z), (1, 0, 0),
                [(0.0, 0.0), (0.52, 0.0), (0.52, 0.05), (0.0, 0.05)], 12 if g.hi else 9, M(g, "BrakeSteel"))
        V.box(g, (sx * (HUB_X - 0.10), AX_F + 0.42, WHEEL_Z + 0.10), (0.12, 0.24, 0.32), M(g, "BlackPlastic"), bev=0.03)
    V.tube(g, [(-2.10, AX_F + 0.48, 1.14), (2.10, AX_F + 0.48, 1.14)], 0.06, M(g, "BlackMetal"), 8 if g.hi else 6)
    # engine, gearbox, prop shaft
    V.box(g, (0, 1.60, 1.36), (2.30, 1.60, 0.70), M(g, "BlackMetal"), bev=0.06)
    V.box(g, (0, 0.90, 1.02), (2.90, 1.10, 0.14), M(g, "Aluminium"), bev=0.04)
    V.box(g, (0, 4.60, 1.20), (0.90, 1.40, 0.60), M(g, "BlackMetal"), bev=0.05)
    V.tube(g, [(0, 5.30, 1.16), (0, 10.60, 1.16)], 0.11, M(g, "BrakeSteel"), 10 if g.hi else 8)
    V.box(g, (0, 5.30, 1.16), (0.30, 0.26, 0.30), M(g, "BlackMetal"), bev=0.02)
    V.box(g, (0, 10.60, 1.16), (0.30, 0.26, 0.30), M(g, "BlackMetal"), bev=0.02)
    # rear axle, leaf springs, dampers, brakes
    V.tube(g, [(-HUB_X, AX_R, WHEEL_Z), (HUB_X, AX_R, WHEEL_Z)], 0.13, M(g, "BlackMetal"), 12 if g.hi else 10)
    V.lathe(g, (0.16, AX_R, WHEEL_Z), (1, 0, 0),
            [(0.0, -0.32), (0.28, -0.28), (0.38, -0.12), (0.38, 0.12), (0.26, 0.28), (0.0, 0.30)],
            14 if g.hi else 10, M(g, "BrakeSteel"))
    for sx in (-1, 1):
        for k in range(2):
            V.box(g, (sx * 1.62, AX_R + 0.05, 1.16 - 0.11 * k), (0.26, 3.40 + 0.70 * k, 0.10), M(g, "BlackMetal"),
                  rot=Matrix.Rotation(math.radians(1.6), 3, "X"), bev=0.02)
        for y in (AX_R + 1.60, AX_R - 1.50):
            V.box(g, (sx * 1.62, y, 1.38), (0.24, 0.22, 0.46), M(g, "BlackMetal"), bev=0.03)
        V.box(g, (sx * 1.98, AX_R + 0.70, 1.50), (0.18, 0.18, 0.90), M(g, "BrakeSteel"),
              rot=Matrix.Rotation(math.radians(12 * sx), 3, "X"), bev=0.03)
        V.box(g, (sx * 1.98, AX_R + 0.80, 1.90), (0.26, 0.26, 0.28), M(g, "BlackMetal"), bev=0.03)
        V.lathe(g, (sx * (HUB_X - 0.12), AX_R, WHEEL_Z), (1, 0, 0),
                [(0.0, 0.0), (0.48, 0.0), (0.48, 0.05), (0.0, 0.05)], 12 if g.hi else 9, M(g, "BrakeSteel"))
        V.box(g, (sx * (HUB_X - 0.10), AX_R + 0.42, WHEEL_Z + 0.10), (0.12, 0.24, 0.32), M(g, "BlackPlastic"), bev=0.03)
        # mud flaps behind both axles
        for hy in (AX_F + 1.52, AX_R + 1.72):
            V.box(g, (sx * 2.30, hy, 0.86), (1.00, 0.06, 0.56), M(g, "Rubber"), bev=0.03)
    # fuel tank, exhaust, spare
    V.box(g, (1.10, 12.60, 1.34), (1.30, 1.70, 0.60), M(g, "BlackPlastic"), bev=0.10)
    V.tube(g, [(-1.10, 5.90, 1.10), (-1.30, 8.40, 1.02), (-1.30, 10.40, 1.02)], 0.09, M(g, "Exhaust"),
           10 if g.hi else 8, fillet=0.3)
    V.lathe(g, (-1.30, 10.55, 1.02), (0, 1, 0),
            [(0.0, 0.0), (0.16, 0.03), (0.24, 0.22), (0.24, 0.80), (0.16, 0.98), (0.10, 1.02)],
            12 if g.hi else 9, M(g, "Exhaust"))
    V.tube(g, [(-1.30, 11.60, 1.02), (-1.40, 15.60, 1.02), (-1.60, 18.80, 1.06), (-1.75, 19.90, 1.10)],
           0.09, M(g, "Exhaust"), 10 if g.hi else 8, fillet=0.25)
    V.lathe(g, (-1.75, 19.95, 1.10), (0, 1, 0), [(0.09, 0.0), (0.11, 0.02), (0.11, 0.10), (0.09, 0.12)],
            10 if g.hi else 8, M(g, "Chrome"))
    V.lathe(g, (0.0, 19.30, 1.16), (0, 0, 1),
            [(0.20, 0.0), (0.54, 0.02), (0.60, 0.10), (0.60, 0.36), (0.54, 0.42), (0.20, 0.44)],
            14 if g.hi else 10, M(g, "Tyre"))
    V.box(g, (0.0, 19.30, 1.06), (0.52, 1.10, 0.08), M(g, "BlackMetal"), bev=0.02)
    # arch liners
    for side in (-1, 1):
        for hy, r in ((AX_F, 1.56), (AX_R, 1.66)):
            pts = []
            for k in range(7):
                a = math.radians(-98 + 196 * k / 6)
                pts.append(P(side * 1.42, hy + r * math.sin(a), WHEEL_Z + r * math.cos(a)))
            V.sweep(g, pts, [(0.0, -0.62), (r * 0.92 * side, -0.62), (r * 0.92 * side, 0.62), (0.0, 0.62)],
                    M(g, "WheelWell"), closed=True, cap0=True, cap1=True)


# --------------------------------------------------------------------------- assembled parts (build.py calls these)
def cab_shell(g):
    cab_body(g)


def cab_detail(g):
    front_panel(g)
    cab_grille(g)
    bumper_front(g)
    arch_trims(g, front=True)
    wipers(g)


def box_body(g):
    box_shell(g)
    box_front(g)
    box_side_windows(g)
    sliding_door(g)
    rear_doors(g)
    rear_assembly(g)
    arch_trims(g, front=False)


def box_detail(g):
    box_roof(g)
    light_bar(g)
