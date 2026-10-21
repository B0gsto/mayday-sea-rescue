"""M_Veh_LifeguardPickup geometry: invented, unbranded double-cab 4x4 lifeguard pickup (Hilux / Ranger class).

Model frame (studs, before the final recentre): X across (driver side -X, kerb side +X), Y length (front bumper at
Y 0, rear bumper at Y 15.99), Z up (ground at 0). The gameplay frame (LandVehicleConfig / Builder.luau) has the
chassis origin at Y 6.74, Z 2.40 (see build.py FRAME).

Real figures (dims.md): 5.33 m L, 1.855 m W, 1.815 m H at 3 studs/m; wheelbase 3.085 m, track 1.54 m, tyre 0.78 m
diameter x 0.265 m, ground clearance 0.29 m. Wheels and seats sit where the code-built car puts them (Builder.luau:
AX_F 2.76, AX_R 12.015, track x 2.31, seats x +-1.335 / Y 7.05 and 9.90).

Each function builds into a Geo: LOD0 (g.hi False, chamfer bevels, low segments) and _HP (g.hi True, named materials,
finer bevels, bolts, seams and stamped detail that only the bake sees).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix

import vehgeo as V

STUDS_M = 3.0

# --------------------------------------------------------------------------- layout (studs)
L = 15.99                 # overall length (5.33 m)
HX = 2.70                 # body side outer face
SKIN = 2.56               # body panel inner face
FLARE = 2.7825            # widest point (arch flares)
BELT = 3.32               # bonnet / door sill line
BED_RAIL = 4.40
BED_TOP = 4.52
ROOF = 5.42
ROOF_HX = 2.60
Z_BOT = 0.98              # body bottom edge
FLOOR = 2.04              # cab interior floor
BED_FLOOR = 2.60
AX_F = 2.76
AX_R = 12.015
HUB_X = 2.31
TRACK = 4.62
WHEEL_R = 1.17
WHEEL_W = 0.795
WHEEL_Z = WHEEL_R
ARCH_R = 1.44
CAB_F = 4.90
CAB_R = 10.90
DOOR_F0, DOOR_F1 = 4.93, 8.16      # front door
DOOR_R0, DOOR_R1 = 8.44, 10.82     # rear door
SILL = 3.96                        # bottom of the side glass
GLASS_TOP = 5.14
WS_F, WS_R = 4.92, 5.94            # windscreen base / roof front
ROOF_R = 10.74                     # roof rear edge
SEAT_X = 1.335
EYE_Z = 2.60


def M(g, name, lo="X"):
    return name if g.hi else lo


def P(x, y, z):
    return Vector((x, y, z))


# --------------------------------------------------------------------------- body shell
def arch_z(y):
    """Bottom edge of the side skin: rocker height, lifted over both wheel arches."""
    z = Z_BOT
    for hy in (AX_F, AX_R):
        d = abs(y - hy)
        if d < ARCH_R:
            z = max(z, WHEEL_Z + math.sqrt(ARCH_R * ARCH_R - d * d))
        elif d < ARCH_R + 0.24:
            t = (d - ARCH_R) / 0.24
            z = max(z, WHEEL_Z * (1 - t) + Z_BOT * t)
    return z


def side_stations():
    ys = [0.55, 0.80, 1.10, 1.30]
    for hy in (AX_F, AX_R):
        for k in range(19):
            ys.append(hy - ARCH_R - 0.24 + (2 * ARCH_R + 0.48) * k / 18)
    ys += [4.30, 4.62, 4.90, 5.40, 6.20, 7.20, 8.20, 9.20, 10.10, 10.44, 10.70, 10.86, 10.92,
           12.20, 13.20, 14.20, 15.10, 15.60, 15.90]
    out = []
    for y in sorted(set(round(v, 4) for v in ys)):
        if 0.5 <= y <= 15.92:
            out.append(y)
    return out


def side_top(y):
    return 4.40 if y >= 10.93 else BELT


def side_ring(side, y):
    zb = arch_z(y)
    zt = side_top(y)
    pts = [(HX, zb), (HX, zt - 0.05), (HX - 0.05, zt), (SKIN, zt), (SKIN, zb)]
    ring = []
    for x, z in pts:
        ring.append(P(side * x, y, z))
    if side < 0:
        ring.reverse()
    return ring


def side_panels(g):
    for side in (1, -1):
        ys = side_stations()
        rings = [side_ring(side, y) for y in ys]
        faces = g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)


def front_face(g):
    V.box(g, (0, 0.55, 2.14), (5.18, 0.22, 2.30), M(g, "PaintWhite"), bev=0.12)
    # grille surround and the panel below the bonnet's leading edge
    V.box(g, (0, 0.47, 2.86), (5.02, 0.14, 0.62), M(g, "PaintWhite"), bev=0.06)
    if g.hi:
        V.box(g, (0, 0.70, 3.30), (4.9, 0.05, 0.04), "PaintWhite")


def bonnet(g):
    ys = [0.58, 0.9, 1.4, 2.2, 3.0, 3.7, 4.3, 4.62, 4.90]
    rings = []
    for y in ys:
        t = (y - 0.58) / (4.90 - 0.58)
        top = 3.28 + 0.10 * t
        hw = 2.62
        ring = [P(-hw, y, top - 0.11), P(-hw + 0.06, y, top - 0.02), P(-1.7, y, top + 0.015),
                P(1.7, y, top + 0.015), P(hw - 0.06, y, top - 0.02), P(hw, y, top - 0.11),
                P(hw, y, top - 0.19), P(-hw, y, top - 0.19)]
        rings.append(ring)
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    # power bulge and the wiper cowl
    V.box(g, (0, 2.55, 3.365), (1.55, 3.1, 0.10), M(g, "PaintWhite"), bev=0.06)
    V.box(g, (0, 4.76, 3.30), (4.62, 0.28, 0.09), M(g, "BlackPlastic"), bev=0.03)
    if g.hi:
        for k in range(9):
            V.box(g, (-1.9 + 0.475 * k, 4.76, 3.345), (0.16, 0.22, 0.02), "BlackPlastic")
        for sx in (-1, 1):   # bonnet shut line
            V.box(g, (sx * 2.55, 2.6, 3.245), (0.015, 4.1, 0.02), "PaintWhite")
        V.box(g, (0, 0.64, 3.32), (2.0, 0.02, 0.03), "PaintWhite")


def door_and_cab_band(g):
    for side in (1, -1):
        x0, x1 = 2.52, HX
        if side < 0:
            x0, x1 = -HX, -2.52
        for y0, y1 in ((DOOR_F0, DOOR_F1), (DOOR_R0, DOOR_R1)):
            V.box(g, (side * 2.63, (y0 + y1) / 2, 2.575), (0.14, y1 - y0, 1.45), M(g, "PaintWhite"), bev=0.05)
            V.box(g, (side * 2.62, (y0 + y1) / 2, 3.62), (0.12, y1 - y0, 0.68), M(g, "PaintWhite"), bev=0.04)
            # window sill seal
            V.box(g, (side * 2.60, (y0 + y1) / 2, 3.955), (0.24, y1 - y0 - 0.04, 0.04), M(g, "GlassSeal"), bev=0.01)
            if g.hi:
                for yy in (y0 + 0.10, y1 - 0.10):
                    for zz in (2.0, 3.2):
                        V.lathe(g, (side * 2.702, yy, zz), (side, 0, 0), [(0.035, 0.0), (0.035, 0.02), (0.0, 0.025)],
                                8, "PaintWhite")
        # front quarter / cowl side, rear quarter
        V.box(g, (side * 2.59, 5.45, 3.62), (0.18, 1.22, 0.68), M(g, "PaintWhite"), bev=0.05)
        V.box(g, (side * 2.59, 10.69, 3.62), (0.18, 0.38, 0.68), M(g, "PaintWhite"), bev=0.05)
        # rocker cladding below the doors
        V.box(g, (side * 2.685, 8.2, 1.45), (0.10, 6.3, 0.82), M(g, "BlackPlastic"), bev=0.03)


def pillars(g):
    for side in (1, -1):
        x0, x1 = side * 2.44, side * 2.68
        if side < 0:
            x0, x1 = side * 2.68, side * 2.44
        # A-pillar, raked 26 deg
        V.extrude_profile(g, [(CAB_F - 0.02, BELT - 0.04), (CAB_F + 0.20, BELT - 0.04),
                              (WS_R + 0.10, 5.34), (WS_R - 0.12, 5.34)], min(x0, x1), max(x0, x1),
                          M(g, "PaintWhite"), bev=0.04)
        # B-pillar (blacked out)
        V.box(g, (side * 2.60, 8.30, 4.66), (0.17, 0.30, 1.42), M(g, "BlackPlastic"), bev=0.02)
        # C-pillar
        V.extrude_profile(g, [(10.44, SILL - 0.02), (10.90, SILL - 0.02), (10.90, 5.34), (10.56, 5.34)],
                          min(x0, x1), max(x0, x1), M(g, "PaintWhite"), bev=0.04)


def roof(g):
    ys = [5.88, 6.30, 7.30, 8.20, 9.10, 9.90, 10.50, 10.70, 10.76]
    rings = []
    for y in ys:
        rings.append([P(-2.60, y, 5.21), P(-2.60, y, 5.33), P(-2.46, y, 5.395), P(-1.30, y, 5.415),
                      P(0.0, y, 5.42), P(1.30, y, 5.415), P(2.46, y, 5.395), P(2.60, y, 5.33),
                      P(2.60, y, 5.21), P(0.0, y, 5.19)])
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    for side in (1, -1):
        V.box(g, (side * 2.535, 8.30, 5.225), (0.10, 4.80, 0.05), M(g, "BlackPlastic"), bev=0.015)
        V.box(g, (side * 2.575, 8.30, 5.17), (0.07, 4.70, 0.10), M(g, "GlassSeal"), bev=0.015)
    if g.hi:
        for k in range(3):
            V.box(g, (-1.35 + 1.35 * k, 8.3, 5.425), (0.62, 4.0, 0.012), "PaintWhite")
        for sx in (-1, 1):
            V.box(g, (sx * 2.44, 8.30, 5.428), (0.03, 4.7, 0.012), "PaintWhite")


def bed(g):
    # floor, inner walls, rail caps, front wall, tailgate
    V.box(g, (0, 13.42, BED_FLOOR - 0.04), (4.60, 4.96, 0.10), M(g, "PaintWhite"), bev=0.02)
    V.box(g, (0, 13.42, BED_FLOOR + 0.025), (4.42, 4.84, 0.05), M(g, "Rubber"), bev=0.01)
    for side in (1, -1):
        V.box(g, (side * 2.32, 13.38, 3.51), (0.14, 4.82, 1.78), M(g, "PaintWhite"), bev=0.04)
        V.box(g, (side * 2.49, 13.38, BED_RAIL + 0.06), (0.44, 4.94, 0.13), M(g, "PaintWhite"), bev=0.055)
        V.box(g, (side * 2.49, 13.38, BED_RAIL + 0.13), (0.40, 4.90, 0.03), M(g, "BlackPlastic"), bev=0.01)
    V.box(g, (0, 11.02, 3.50), (4.36, 0.16, 1.82), M(g, "PaintWhite"), bev=0.04)
    V.box(g, (0, 15.87, 3.50), (5.30, 0.18, 1.86), M(g, "PaintWhite"), bev=0.10)
    V.box(g, (0, 15.87, BED_RAIL + 0.06), (5.30, 0.24, 0.12), M(g, "PaintWhite"), bev=0.05)
    V.box(g, (0, 15.87, BED_RAIL + 0.13), (5.26, 0.22, 0.03), M(g, "BlackPlastic"), bev=0.01)
    V.box(g, (0, 15.76, 3.50), (4.40, 0.05, 1.60), M(g, "PaintWhite"), bev=0.03)
    if g.hi:
        for side in (1, -1):   # stamped bed-side ribs
            for k in range(3):
                V.box(g, (side * 2.60, 11.90 + 1.35 * k, 3.55), (0.02, 0.55, 1.2), "PaintWhite")
        for k in range(6):     # floor corrugations
            V.box(g, (0, 11.40 + 0.72 * k, BED_FLOOR + 0.01), (4.40, 0.10, 0.03), "PaintWhite")
        V.box(g, (0, 15.755, 3.62), (3.1, 0.02, 1.0), "PaintWhite")   # tailgate pressing


def flares(g):
    for side in (1, -1):
        for hy in (AX_F, AX_R):
            pts = []
            for k in range(15):
                a = math.radians(-103 + 206 * k / 14)
                pts.append(P(side * 2.695, hy + (ARCH_R + 0.02) * math.sin(a),
                             WHEEL_Z + (ARCH_R + 0.02) * math.cos(a)))
            prof = [(0.0, -0.20), (0.050 * side, -0.225), (0.0825 * side, -0.14),
                    (0.0825 * side, 0.12), (0.050 * side, 0.205), (0.0, 0.22)]
            V.sweep(g, pts, prof, M(g, "ArchPlastic"), closed=True, cap0=True, cap1=True)
            if g.hi:
                for k in range(5):
                    a = math.radians(-75 + 150 * k / 4)
                    c = (side * 2.775, hy + (ARCH_R + 0.02) * math.sin(a),
                         WHEEL_Z + (ARCH_R + 0.02) * math.cos(a))
                    V.lathe(g, c, (side, 0, 0), [(0.035, 0.0), (0.035, 0.012), (0.0, 0.016)], 8, "BlackPlastic")


def wheel_wells(g):
    for side in (1, -1):
        for hy in (AX_F, AX_R):
            pts = []
            for k in range(11):
                a = math.radians(-98 + 196 * k / 10)
                pts.append(P(side * 1.55, hy + 1.40 * math.sin(a), WHEEL_Z + 1.40 * math.cos(a)))
            V.sweep(g, pts, [(0.0, -0.55), (0.95 * side, -0.55), (0.95 * side, 0.55), (0.0, 0.55)],
                    M(g, "WheelWell"), closed=True, cap0=True, cap1=True)


def body(g):
    side_panels(g)
    for side in (1, -1):
        V.box(g, (side * 2.698, 9.9, 2.46), (0.022, 11.4, 0.055), M(g, "PaintWhite"), bev=0.015)
    front_face(g)
    bonnet(g)
    door_and_cab_band(g)
    pillars(g)
    roof(g)
    bed(g)
    flares(g)


# --------------------------------------------------------------------------- body detail (bumpers, lamps, trim)
def bumper_front(g):
    V.box(g, (0, 0.22, 1.53), (5.34, 0.46, 1.10), M(g, "BumperPlastic"), bev=0.10)
    V.box(g, (0, 0.28, 1.04), (4.30, 0.38, 0.26), M(g, "BumperPlastic"), bev=0.06)
    V.box(g, (0, 0.36, 1.02), (2.30, 0.34, 0.10), M(g, "Aluminium"), bev=0.03)
    # lower grille insert and fog lamps
    V.box(g, (0, 0.465, 1.62), (2.9, 0.04, 0.42), M(g, "GrilleDark"), bev=0.02)
    V.box(g, (0, 0.10, 1.22), (2.2, 0.10, 0.18), M(g, "Aluminium"), bev=0.02)
    for sx in (-1, 1):
        V.lathe(g, (sx * 1.72, 0.50, 1.58), (0, -1, 0),
                [(0.20, 0.0), (0.20, 0.02), (0.17, 0.03), (0.15, 0.05), (0.0, 0.055)], 16, M(g, "Chrome"))
        V.lathe(g, (sx * 1.72, 0.53, 1.58), (0, -1, 0),
                [(0.13, 0.0), (0.13, 0.01), (0.0, 0.03)], 16, M(g, "LensWhite"))
        # red recovery hooks
        V.box(g, (sx * 1.02, 0.50, 1.22), (0.24, 0.16, 0.20), M(g, "PaintRed"), bev=0.04)
        V.tube(g, [(sx * 1.02 - 0.10, 0.56, 1.22), (sx * 1.02, 0.66, 1.22), (sx * 1.02 + 0.10, 0.56, 1.22)],
               0.05, M(g, "PaintRed"), 8 if g.hi else 6, fillet=0.06)
    # plate
    V.box(g, (0, 0.485, 1.90), (1.10, 0.03, 0.24), M(g, "PlateWhite"), bev=0.01)
    if g.hi:
        for sx in (-1, 1):
            for k in range(4):
                V.lathe(g, (sx * 1.6 + 0.0, 0.47, 1.14 + 0.22 * k), (0, -1, 0),
                        [(0.025, 0.0), (0.025, 0.012), (0.0, 0.014)], 8, "BlackPlastic")


def bumper_rear(g):
    V.box(g, (0, 15.86, 1.42), (5.40, 0.26, 0.78), M(g, "BumperPlastic"), bev=0.08)
    V.box(g, (0, 15.70, 1.82), (4.10, 0.34, 0.10), M(g, "Rubber"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 1.95, 15.985, 1.05), (0.22, 0.03, 0.12), M(g, "LensRed"), bev=0.01)
    # receiver hitch and tow ball
    V.box(g, (0, 15.70, 1.10), (0.30, 0.80, 0.26), M(g, "BlackMetal"), bev=0.03)
    V.box(g, (0, 16.04, 1.12), (0.34, 0.22, 0.34), M(g, "BlackMetal"), bev=0.03)
    V.lathe(g, (0, 16.12, 1.34), (0, 0, 1), [(0.0, 0.0), (0.10, 0.02), (0.17, 0.14), (0.17, 0.20), (0.0, 0.21)],
            14, M(g, "Chrome"))
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.42, 15.86, 1.18), (sx * 0.42, 16.02, 1.18)], 0.045, M(g, "BlackMetal"), 8 if g.hi else 6)
    if g.hi:
        for sx in (-1, 1):
            for zz in (1.10, 1.36):
                V.lathe(g, (sx * 0.22, 15.99, zz), (0, 1, 0), [(0.045, 0.0), (0.045, 0.02), (0.0, 0.025)], 8, "BlackMetal")


def grille(g):
    V.box(g, (0, 0.49, 2.66), (2.12, 0.10, 0.92), M(g, "GrilleDark"), bev=0.03)
    for k in range(3):
        V.box(g, (0, 0.452, 2.34 + 0.28 * k), (2.00, 0.04, 0.12), M(g, "PaintWhite"), bev=0.015)
    V.box(g, (0, 0.44, 2.66), (2.38, 0.06, 1.10), M(g, "PaintWhite"), bev=0.045)
    V.box(g, (0, 0.452, 3.10), (4.55, 0.05, 0.10), M(g, "Chrome"), bev=0.02)
    # invented roundel: stainless ring with a wave bar
    V.lathe(g, (0, 0.435, 2.72), (0, -1, 0), [(0.26, 0.0), (0.26, 0.035), (0.21, 0.045), (0.17, 0.03), (0.0, 0.03)],
            24 if g.hi else 18, M(g, "Stainless"))
    V.tube(g, [(-0.14, 0.405, 2.74), (-0.04, 0.405, 2.66), (0.06, 0.405, 2.74), (0.14, 0.405, 2.68)],
           0.032, M(g, "PaintRed"), 8 if g.hi else 6, fillet=0.05)
    # headlamp clusters
    for sx in (-1, 1):
        V.box(g, (sx * 1.86, 0.46, 2.82), (1.50, 0.16, 0.72), M(g, "BlackPlastic"), bev=0.06)
        V.box(g, (sx * 1.86, 0.418, 2.82), (1.34, 0.05, 0.56), M(g, "LensWhite"), bev=0.05)
        V.box(g, (sx * 2.42, 0.418, 2.80), (0.32, 0.055, 0.48), M(g, "LensAmber"), bev=0.035)
        V.box(g, (sx * 1.86, 0.392, 2.84), (1.18, 0.02, 0.14), M(g, "BlackPlastic"), bev=0.02)
        if g.hi:
            for k in range(4):
                V.box(g, (sx * 1.86, 0.395, 2.61 + 0.14 * k), (1.12, 0.008, 0.02), "Chrome")
            for k in range(4):
                V.box(g, (sx * 1.86, 0.395, 2.61 + 0.14 * k), (1.12, 0.008, 0.02), "LensWhite")


def tail_lamps(g):
    for sx in (-1, 1):
        V.box(g, (sx * 2.48, 15.90, 3.16), (0.42, 0.18, 1.34), M(g, "BlackPlastic"), bev=0.04)
        V.box(g, (sx * 2.48, 15.99, 3.42), (0.32, 0.04, 0.38), M(g, "LensRed"), bev=0.02)
        V.box(g, (sx * 2.48, 15.99, 3.02), (0.32, 0.04, 0.28), M(g, "LensRed"), bev=0.02)
        V.box(g, (sx * 2.48, 15.99, 2.80), (0.32, 0.04, 0.14), M(g, "LensAmber"), bev=0.015)
        V.box(g, (sx * 2.48, 15.99, 2.64), (0.24, 0.04, 0.13), M(g, "LensReverse"), bev=0.015)
    # tailgate band and lettering plate
    V.box(g, (0, 15.965, 3.02), (4.30, 0.02, 0.34), M(g, "PaintRed"), bev=0.01)
    if g.hi:
        V.box(g, (0, 15.955, 4.10), (1.2, 0.03, 0.22), "PaintWhite")


def mirrors(g):
    for side in (1, -1):
        base = P(side * 2.62, 5.62, 3.72)
        V.tube(g, [base, P(side * 2.76, 5.58, 3.80), P(side * 2.84, 5.50, 3.88)], 0.06, M(g, "BlackPlastic"),
               10 if g.hi else 8, fillet=0.10)
        V.box(g, (side * 2.80, 5.44, 3.98), (0.22, 0.40, 0.60), M(g, "BlackPlastic"), bev=0.08)
        V.box(g, (side * 2.902, 5.44, 3.98), (0.02, 0.34, 0.52), M(g, "Chrome"), bev=0.015)
        V.box(g, (side * 2.86, 5.64, 3.98), (0.06, 0.06, 0.50), M(g, "BlackPlastic"), bev=0.01)
        if g.hi:
            V.box(g, (side * 2.88, 5.28, 4.14), (0.03, 0.08, 0.12), "LensAmber")


def door_handles(g):
    for side in (1, -1):
        for y in (6.95, 10.05):
            V.box(g, (side * HX + side * 0.02, y, 3.03), (0.10, 0.44, 0.13), M(g, "Chrome"), bev=0.03)
            if g.hi:
                V.box(g, (side * HX + side * 0.035, y - 0.02, 3.09), (0.05, 0.34, 0.04), "Chrome")


def steps(g):
    for side in (1, -1):
        V.box(g, (side * 2.62, 8.18, 0.98), (0.34, 6.10, 0.14), M(g, "Aluminium"), bev=0.04)
        V.box(g, (side * 2.62, 8.18, 1.06), (0.30, 5.70, 0.03), M(g, "Rubber"), bev=0.02)
        for y in (5.4, 8.2, 11.0):
            V.box(g, (side * 2.50, y, 0.90), (0.26, 0.16, 0.18), M(g, "BlackMetal"), bev=0.03)
        if g.hi:
            for y in (5.4, 8.2, 11.0):
                for k in range(3):
                    V.box(g, (side * 2.60, y - 0.06 + 0.06 * k, 1.075), (0.26, 0.02, 0.012), "Aluminium")


def fuel_filler(g):
    V.lathe(g, (2.70, 14.20, 3.75), (1, 0, 0), [(0.32, 0.0), (0.32, 0.015), (0.26, 0.02), (0.0, 0.02)],
            20 if g.hi else 14, M(g, "PaintWhite"))
    V.lathe(g, (2.72, 14.20, 3.75), (1, 0, 0), [(0.19, 0.0), (0.19, 0.02), (0.15, 0.03), (0.0, 0.03)],
            16 if g.hi else 12, M(g, "Chrome"))


def wipers(g):
    for sx in (-1, 1):
        V.box(g, (sx * 1.05, 4.93, 3.46), (1.30, 0.09, 0.06), M(g, "BlackPlastic"),
              rot=Matrix.Rotation(math.radians(6), 3, "X"), bev=0.01)
        V.box(g, (sx * 0.42, 4.98, 3.46), (0.10, 0.10, 0.08), M(g, "BlackPlastic"), bev=0.01)
    V.box(g, (0, 4.90, 3.44), (4.00, 0.06, 0.05), M(g, "BlackPlastic"), bev=0.01)


def livery(g):
    # battenburg along the doors (two rows) and the bed sides, plus chevrons on the tailgate
    n = 6
    span = (DOOR_F0 + 0.15, DOOR_R1 - 0.15)
    seg = (span[1] - span[0]) / n
    for side in (1, -1):
        for i in range(n):
            y = span[0] + seg * (i + 0.5)
            for row in (0, 1):
                mat = "PaintRed" if (i + row) % 2 == 0 else "PaintYellow"
                V.box(g, (side * 2.705, y, 2.02 + 0.34 * row), (0.02, seg - 0.05, 0.32), M(g, mat), bev=0.0)
        n2 = 4
        span2 = (11.10, 15.55)
        seg2 = (span2[1] - span2[0]) / n2
        for i in range(n2):
            y = span2[0] + seg2 * (i + 0.5)
            mat = "PaintRed" if i % 2 == 0 else "PaintYellow"
            V.box(g, (side * 2.705, y, 2.92), (0.02, seg2 - 0.05, 0.46), M(g, mat), bev=0.0)
    # tailgate chevrons
    for i in range(3):
        for sx in (-1, 1):
            mat = "PaintRed" if i % 2 == 0 else "PaintYellow"
            V.box(g, (sx * 1.55, 15.945, 3.20 + 0.34 * i), (1.0, 0.02, 0.30), M(g, mat),
                  rot=Matrix.Rotation(math.radians(sx * 18), 3, "X"), bev=0.0)


def texts(g):
    def panel(side, body, size, yc, zc, mat):
        me = V.text_mesh(body, size)
        x = side * 2.706
        if side > 0:
            def mp(co, x=x, yc=yc, zc=zc):
                return P(x, yc + co.x, zc + co.y)
        else:
            def mp(co, x=x, yc=yc, zc=zc):
                return P(x, yc - co.x, zc + co.y)
        fs = g.add_mesh(me, mat, mp)
        g.orient(fs, lambda c, side=side: P(side, 0, 0))
        bpy.data.meshes.remove(me)
    for side in (1, -1):
        panel(side, "LIFEGUARD", 0.34, 6.55, 2.80, M(g, "LetterRed"))
        panel(side, "LIFEGUARD", 0.28, 13.45, 3.68, M(g, "LetterRed"))
        if g.hi:
            panel(side, "BEACH 1", 0.13, 9.95, 3.56, "LetterRed")
    # tailgate text
    me = V.text_mesh("RESCUE", 0.26)
    def mp(co):
        return P(co.x, 15.972, 3.02 + co.y)
    fs = g.add_mesh(me, M(g, "LetterWhite"), mp)
    g.orient(fs, lambda c: P(0, 1, 0))
    bpy.data.meshes.remove(me)


def body_detail(g):
    bumper_front(g)
    bumper_rear(g)
    grille(g)
    tail_lamps(g)
    mirrors(g)
    door_handles(g)
    steps(g)
    fuel_filler(g)
    wipers(g)
    livery(g)
    texts(g)


# --------------------------------------------------------------------------- glass
def _sheet(g, rows, mat, flip=False):
    """Quad grid from rows of points (row 0 = bottom / front), single-sided, wound to face the grid normal."""
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


def glass(g):
    # windscreen: shallow bow, raked 26 degrees, two sheets 0.04 apart
    cols = 5
    t0, t1 = 3.44, 5.20
    front, back = [], []
    for r in range(2):
        z = t0 + (t1 - t0) * r
        y = WS_F + 0.03 + (WS_R - WS_F - 0.06) * r
        fr, bk = [], []
        for c in range(cols + 1):
            u = -1 + 2 * c / cols
            x = u * 2.34
            bow = 0.10 * (1 - u * u)
            fr.append(P(x, y + bow, z))
            bk.append(P(x, y + bow + 0.045, z - 0.02))
        front.append(fr)
        back.append(bk)
    _sheet(g, front, M(g, "Glass"))
    _sheet(g, back, M(g, "Glass"), flip=True)
    # cowl seal under the windscreen
    V.box(g, (0, WS_F + 0.04, 3.40), (4.70, 0.10, 0.10), M(g, "GlassSeal"), bev=0.02)
    # side glass: front door windows rolled down (patrol truck), rear door panes closed
    for side in (1, -1):
        V.extrude_profile(g, [(6.16, SILL + 0.02), (8.14, SILL + 0.02), (8.14, SILL + 0.11), (6.16, SILL + 0.11)],
                          side * 2.56, side * 2.60, M(g, "Glass"))
        V.extrude_profile(g, [(8.47, SILL + 0.02), (10.58, SILL + 0.02), (10.58, GLASS_TOP), (8.47, GLASS_TOP)],
                          side * 2.56, side * 2.60, M(g, "Glass"))
        # rubber seals around the openings and the door frames
        V.box(g, (side * 2.58, 7.15, SILL + 0.03), (0.06, 2.22, 0.07), M(g, "GlassSeal"))
        V.box(g, (side * 2.58, 6.14, 4.54), (0.06, 0.08, 1.30), M(g, "GlassSeal"))
        V.box(g, (side * 2.58, 8.16, 4.54), (0.06, 0.08, 1.30), M(g, "GlassSeal"))
        V.box(g, (side * 2.58, 9.78, SILL + 0.03), (0.06, 2.72, 0.07), M(g, "GlassSeal"))
        V.box(g, (side * 2.58, 8.45, 4.54), (0.06, 0.08, 1.30), M(g, "GlassSeal"))
        V.box(g, (side * 2.58, 10.60, 4.54), (0.06, 0.08, 1.30), M(g, "GlassSeal"))
        V.box(g, (side * 2.58, 9.77, GLASS_TOP - 0.045), (0.06, 2.74, 0.07), M(g, "GlassSeal"))
        V.box(g, (side * 2.585, 7.14, 5.135), (0.06, 2.20, 0.07), M(g, "GlassSeal"))
    # black windscreen surround and the door waist moulding
    V.box(g, (0, 5.955, 5.31), (4.70, 0.10, 0.10), M(g, "GlassSeal"), bev=0.02)
    for sx in (-1, 1):
        V.box(g, (sx * 2.375, 5.44, 4.36), (0.09, 1.24, 1.86), M(g, "GlassSeal"),
              rot=Matrix.Rotation(math.radians(-8), 3, "X"), bev=0.02)
        V.box(g, (sx * 2.706, 8.20, 3.315), (0.02, 6.44, 0.055), M(g, "BlackPlastic"))
        # rear window (raked back at the top) and its wiper
    V.box(g, (0, 10.70, 4.57), (4.06, 0.05, 1.10), M(g, "Glass"), bev=0.02)
    V.box(g, (0, 10.75, 4.86), (0.10, 0.10, 0.72), M(g, "BlackPlastic"), bev=0.01)


# --------------------------------------------------------------------------- interior
def seat(g, x, cy, cushion_z, back_top, width, head=True):
    # pedestal
    V.box(g, (x, cy, (FLOOR + cushion_z) / 2), (width * 0.9, 0.85, cushion_z - FLOOR), M(g, "InteriorDark"), bev=0.04)
    # cushion with side bolsters
    V.box(g, (x, cy, cushion_z + 0.06), (width, 0.98, 0.22), M(g, "SeatFabric"), bev=0.09)
    for sx in (-1, 1):
        V.box(g, (x + sx * (width / 2 - 0.05), cy, cushion_z + 0.12), (0.12, 0.92, 0.20), M(g, "SeatFabric"), bev=0.05)
    # backrest, raked 20 degrees
    rot = Matrix.Rotation(math.radians(-20), 3, "X")
    V.box(g, (x, cy + 0.62, cushion_z + (back_top - cushion_z) / 2), (width, 0.20, back_top - cushion_z),
          M(g, "SeatFabric"), rot=rot, bev=0.10)
    V.box(g, (x, cy + 0.60, cushion_z + (back_top - cushion_z) * 0.52), (width * 0.62, 0.23, (back_top - cushion_z) * 0.72),
          M(g, "SeatAccent"), rot=rot, bev=0.05)
    for sx in (-1, 1):
        V.box(g, (x + sx * (width / 2 - 0.06), cy + 0.60, cushion_z + (back_top - cushion_z) * 0.55),
              (0.12, 0.26, (back_top - cushion_z) * 0.8), M(g, "SeatFabric"), rot=rot, bev=0.05)
    if head:
        V.box(g, (x, cy + 0.72, back_top + 0.16), (0.62, 0.20, 0.30), M(g, "SeatFabric"), bev=0.08)
        for sx in (-1, 1):
            V.tube(g, [(x + sx * 0.16, cy + 0.74, back_top - 0.06), (x + sx * 0.16, cy + 0.72, back_top + 0.05)],
                   0.035, M(g, "Chrome"), 8)
    if g.hi:
        for k in range(5):
            V.box(g, (x, cy + 0.50 - 0.16 * k + 0.0, cushion_z + 0.185), (width * 0.78, 0.02, 0.012), "SeatFabric")


def bench(g):
    V.box(g, (0, 9.98, (FLOOR + 2.54) / 2), (3.9, 0.85, 2.54 - FLOOR), M(g, "InteriorDark"), bev=0.04)
    V.box(g, (0, 9.98, 2.49), (4.30, 0.92, 0.22), M(g, "SeatFabric"), bev=0.09)
    rot = Matrix.Rotation(math.radians(-18), 3, "X")
    V.box(g, (0, 10.40, 3.48), (4.30, 0.20, 1.55), M(g, "SeatFabric"), rot=rot, bev=0.10)
    V.box(g, (0, 10.38, 3.55), (2.7, 0.23, 1.15), M(g, "SeatAccent"), rot=rot, bev=0.05)
    for x in (-1.55, 0.0, 1.55):
        V.box(g, (x, 10.54, 4.36), (0.58, 0.20, 0.30), M(g, "SeatFabric"), bev=0.08)


def dashboard(g):
    # main dash body, sloping top pad, knee panel
    V.box(g, (0, 5.36, 3.68), (4.72, 0.66, 0.96), M(g, "InteriorDark"), bev=0.08)
    V.box(g, (0, 5.30, 4.20), (4.66, 0.72, 0.14), M(g, "InteriorDark"), bev=0.04)
    V.box(g, (0, 5.10, 2.90), (4.60, 0.18, 0.90), M(g, "InteriorDark"), bev=0.05)
    V.box(g, (0, 5.62, 4.255), (4.62, 0.12, 0.05), M(g, "InteriorMid"), bev=0.01)
    # driver binnacle (RHD: driver on the right, Blender -X)
    V.box(g, (-SEAT_X, 5.62, 4.10), (1.06, 0.24, 0.34), M(g, "InteriorDark"), bev=0.06)
    V.box(g, (-SEAT_X, 5.50, 4.06), (0.96, 0.05, 0.26), M(g, "Screen"), bev=0.02)
    V.lathe(g, (-SEAT_X - 0.24, 5.47, 4.06), (0, -1, 0), [(0.10, 0.0), (0.10, 0.01), (0.085, 0.02), (0.0, 0.022)],
            18 if g.hi else 14, M(g, "PlateLetter"))
    V.lathe(g, (-SEAT_X + 0.16, 5.47, 4.06), (0, -1, 0), [(0.08, 0.0), (0.08, 0.01), (0.0, 0.02)],
            16 if g.hi else 12, M(g, "Screen"))
    # centre stack screen and vents
    V.box(g, (0.05, 5.66, 3.92), (0.86, 0.08, 0.50), M(g, "InteriorDark"), bev=0.03)
    V.box(g, (0.05, 5.61, 3.94), (0.74, 0.03, 0.40), M(g, "Screen"), bev=0.02)
    for k in range(2):
        V.box(g, (-0.62 + 0.10 * k, 5.62, 3.52), (0.34, 0.06, 0.20), M(g, "BlackPlastic"), bev=0.02)
    # passenger grab handle
    V.tube(g, [(0.85, 5.56, 4.02), (0.85, 5.46, 4.06), (1.55, 5.46, 4.06), (1.55, 5.56, 4.02)],
           0.05, M(g, "InteriorMid"), 10 if g.hi else 8, fillet=0.08)
    # steering wheel (RHD), tilted 24 degrees
    c = P(-SEAT_X, 6.02, 4.02)
    u = P(0, math.sin(math.radians(-24)), math.cos(math.radians(-24)))
    v = P(1, 0, 0)
    path = [c + u * (0.62 * math.cos(2 * math.pi * k / 24)) + v * (0.62 * math.sin(2 * math.pi * k / 24))
            for k in range(24)]
    path.append(path[0])
    V.sweep(g, path, V.circle_profile(0.075, 8 if g.hi else 6), M(g, "BlackPlastic"), closed=True)
    for k in range(3):
        a = math.radians(90 + 120 * k)
        tip = c + u * (0.60 * math.cos(a)) + v * (0.60 * math.sin(a))
        V.tube(g, [tuple(c + u * 0.10), tuple(tip)], 0.055, M(g, "InteriorMid"), 8 if g.hi else 6)
    V.lathe(g, tuple(c), (0, -math.sin(math.radians(-24)), -math.cos(math.radians(-24))),
            [(0.20, 0.0), (0.20, 0.06), (0.14, 0.10), (0.0, 0.11)], 18 if g.hi else 14, M(g, "InteriorDark"))
    V.tube(g, [tuple(c - u * 0.05), (-SEAT_X, 5.66, 3.80)], 0.10, M(g, "InteriorDark"), 10 if g.hi else 8)
    # centre console, levers, cup holders
    V.box(g, (0, 6.55, 2.52), (0.86, 1.70, 0.92), M(g, "InteriorDark"), bev=0.06)
    V.box(g, (0, 6.45, 3.02), (0.78, 1.40, 0.06), M(g, "InteriorMid"), bev=0.02)
    V.tube(g, [(0, 6.85, 3.00), (0, 6.80, 3.42)], 0.05, M(g, "Chrome"), 8)
    V.lathe(g, (0, 6.80, 3.44), (0, 0, 1), [(0.0, 0.0), (0.11, 0.02), (0.12, 0.10), (0.06, 0.14), (0.0, 0.15)],
            14 if g.hi else 10, M(g, "BlackPlastic"))
    V.tube(g, [(0.36, 6.30, 3.00), (0.36, 6.26, 3.30)], 0.04, M(g, "BlackMetal"), 8)
    for sx in (-1, 1):
        V.lathe(g, (sx * 0.20, 5.92, 3.04), (0, 0, 1), [(0.13, 0.0), (0.13, 0.02), (0.11, 0.03), (0.0, 0.03)],
                14 if g.hi else 10, M(g, "BlackPlastic"))
    if g.hi:
        for k in range(4):
            V.box(g, (0, 7.10 - 0.10 * k, 3.06), (0.30, 0.02, 0.012), "InteriorMid")


def cab_interior(g):
    # floor, tunnel, firewall, rear bulkhead
    V.box(g, (0, 8.20, FLOOR - 0.04), (4.56, 6.60, 0.10), M(g, "Carpet"), bev=0.02)
    V.box(g, (0, 7.60, FLOOR + 0.10), (0.94, 4.10, 0.22), M(g, "Carpet"), bev=0.06)
    V.box(g, (0, 5.02, 2.98), (4.60, 0.10, 1.92), M(g, "InteriorDark"), bev=0.03)
    V.box(g, (0, 10.68, 2.90), (4.60, 0.10, 1.76), M(g, "InteriorDark"), bev=0.03)
    # rear window frame and interior trim
    V.box(g, (0, 10.64, 3.86), (4.60, 0.12, 0.20), M(g, "InteriorDark"), bev=0.02)
    V.box(g, (0, 10.64, 5.16), (4.60, 0.12, 0.18), M(g, "InteriorDark"), bev=0.02)
    for sx in (-1, 1):
        V.box(g, (sx * 2.16, 10.64, 4.56), (0.22, 0.12, 1.20), M(g, "InteriorDark"), bev=0.02)
    # door cards + armrests + sill trim
    for side in (1, -1):
        for y0, y1 in ((DOOR_F0 + 0.04, DOOR_F1 - 0.04), (DOOR_R0 + 0.04, DOOR_R1 - 0.04)):
            V.box(g, (side * 2.44, (y0 + y1) / 2, 2.98), (0.10, y1 - y0, 1.72), M(g, "InteriorMid"), bev=0.03)
            V.box(g, (side * 2.38, (y0 + y1) / 2, 2.86), (0.16, 1.10, 0.16), M(g, "InteriorDark"), bev=0.05)
            V.box(g, (side * 2.43, (y0 + y1) / 2, 3.86), (0.10, y1 - y0, 0.10), M(g, "GlassSeal"), bev=0.01)
            if g.hi:
                V.box(g, (side * 2.40, (y0 + y1) / 2, 3.42), (0.03, 0.9, 0.05), "SeatAccent")
                V.lathe(g, (side * 2.38, y0 + 0.5, 2.98), (side, 0, 0),
                        [(0.16, 0.0), (0.16, 0.02), (0.10, 0.03), (0.0, 0.03)], 12, "BlackPlastic")
    # headliner, sun visors, interior mirror
    V.box(g, (0, 8.20, 5.17), (4.62, 5.10, 0.05), M(g, "Headliner"), bev=0.02)
    for sx in (-1, 1):
        V.box(g, (sx * 0.95, 5.52, 5.10), (1.22, 0.10, 0.32), M(g, "Headliner"), bev=0.04)
    V.tube(g, [(0, 5.52, 5.14), (0, 5.60, 5.02)], 0.04, M(g, "InteriorDark"), 8)
    V.box(g, (0, 5.62, 4.98), (0.62, 0.10, 0.22), M(g, "InteriorDark"), bev=0.03)
    # seats and belts
    seat(g, -SEAT_X, 7.06, 2.41, 4.28, 1.06)
    seat(g, SEAT_X, 7.06, 2.41, 4.28, 1.06)
    bench(g)
    for sx in (-1, 1):
        V.box(g, (sx * SEAT_X + 0.28, 7.28, 3.72), (0.16, 0.06, 2.0), M(g, "Webbing"),
              rot=Matrix.Rotation(math.radians(-20), 3, "X"), bev=0.01)
        V.box(g, (sx * SEAT_X + 0.28, 6.86, 2.62), (0.14, 0.10, 0.12), M(g, "Chrome"), bev=0.01)
    # pedals
    for k in range(3):
        V.box(g, (-SEAT_X - 0.34 + 0.22 * k, 5.20, 2.32), (0.16, 0.10, 0.30), M(g, "BlackPlastic"),
              rot=Matrix.Rotation(math.radians(20), 3, "X"), bev=0.02)
    # kit bag on the rear bench
    V.box(g, (0.20, 10.02, 2.86), (1.30, 0.62, 0.48), M(g, "KitOrange"), bev=0.10)
    V.box(g, (0.20, 10.02, 3.09), (1.32, 0.64, 0.06), M(g, "KitOrange"), bev=0.02)
    V.box(g, (0.20, 9.73, 2.92), (0.24, 0.04, 0.36), M(g, "Webbing"), bev=0.0)
    if g.hi:
        V.box(g, (0.20, 10.34, 2.92), (0.42, 0.03, 0.20), "PlateWhite")


# --------------------------------------------------------------------------- wheels and underbody
def tyre(g, cx, side):
    profile = [(0.66, 0.34), (0.80, 0.36), (0.95, 0.395), (1.06, 0.40), (1.14, 0.35), (1.155, 0.26),
               (1.155, -0.26), (1.14, -0.35), (1.06, -0.40), (0.95, -0.395), (0.80, -0.36), (0.66, -0.34)]
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0), [(r, h * side) for r, h in profile],
            20 if g.hi else 18, M(g, "Tyre"))
    # all-terrain tread blocks: two staggered rows
    n = 16 if g.hi else 13
    for row, xoff in ((0, -0.21), (1, 0.21)):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * row) / n
            rot = Matrix.Rotation(-a, 3, "X")
            c = (cx + xoff * side, (1.125) * math.sin(a), WHEEL_Z + (1.125) * math.cos(a))
            V.box(g, c, (0.32, 0.30, 0.07), M(g, "Tyre"), rot=rot, bev=0.0)
    # rim: alloy-style dished face, five round holes, centre cap, lug nuts
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0),
            [(0.0, 0.220 * side), (0.20, 0.220 * side), (0.22, 0.245 * side), (0.50, 0.245 * side),
             (0.60, 0.220 * side), (0.64, 0.170 * side), (0.64, 0.080 * side), (0.70, 0.010 * side),
             (0.70, -0.22 * side), (0.66, -0.34 * side)],
            18 if g.hi else 14, M(g, "RimSilver"))
    face = cx + side * 0.205
    for k in range(5):
        a = math.radians(72 * k + 90)
        c = (face, 0.365 * math.sin(a), WHEEL_Z + 0.365 * math.cos(a))
        V.lathe(g, c, (side, 0, 0), [(0.155, -0.005), (0.155, 0.012), (0.125, 0.018), (0.0, 0.018)],
                12 if g.hi else 9, M(g, "RimDark"))
    V.lathe(g, (face, 0, WHEEL_Z), (side, 0, 0),
            [(0.0, 0.0), (0.21, 0.0), (0.21, 0.035), (0.17, 0.06), (0.0, 0.065)],
            16 if g.hi else 12, M(g, "RimSilver"))
    for k in range(5):
        a = math.radians(72 * k)
        V.lathe(g, (face, 0.135 * math.sin(a), WHEEL_Z + 0.135 * math.cos(a)), (side, 0, 0),
                [(0.052, 0.035), (0.052, 0.06), (0.0, 0.065)], 6, M(g, "Chrome"))
    V.tube(g, [(face, 0.05, WHEEL_Z + 0.23), (face, 0.05, WHEEL_Z + 0.33)], 0.025, M(g, "BlackPlastic"), 6)
    if g.hi:
        V.box(g, (face, 0.0, WHEEL_Z - 0.40), (0.02, 0.30, 0.05), "RimSilver")


def wheel(g, side, front):
    cx = side * HUB_X
    cy = AX_F if front else AX_R
    start = len(g.bm.verts)
    # built at the origin about +X (outboard face mirrored by `side`), then moved to its hub
    tyre(g, 0.0, side)
    g.bm.verts.ensure_lookup_table()
    for v in g.bm.verts[start:]:
        v.co = P(v.co.x + cx, v.co.y + cy, v.co.z)


def underbody(g):
    # chassis rails, cross members, skid plate
    for sx in (-1, 1):
        V.box(g, (sx * 0.86, 8.2, 1.12), (0.26, 15.0, 0.36), M(g, "BlackMetal"), bev=0.03)
    for y in (1.6, 5.2, 8.6, 11.4, 14.4):
        V.box(g, (0, y, 1.10), (1.96, 0.20, 0.26), M(g, "BlackMetal"), bev=0.02)
    V.box(g, (0, 1.10, 0.94), (2.6, 1.20, 0.08), M(g, "Aluminium"), bev=0.03)
    # front axle: diff, half shafts, arms, coil-overs, anti-roll bar
    V.lathe(g, (-0.18, AX_F, 1.16), (1, 0, 0), [(0.0, -0.34), (0.24, -0.30), (0.34, -0.16), (0.34, 0.16),
                                                (0.20, 0.30), (0.0, 0.32)], 14 if g.hi else 10, M(g, "BrakeSteel"))
    for sx in (-1, 1):
        V.tube(g, [(sx * 0.20, AX_F, 1.16), (sx * (HUB_X - 0.16), AX_F, WHEEL_Z)], 0.10, M(g, "BlackMetal"),
               10 if g.hi else 8)
        V.box(g, (sx * 1.45, AX_F + 0.15, 1.02), (1.50, 0.24, 0.14), M(g, "BlackMetal"), bev=0.0)
        V.box(g, (sx * 1.55, AX_F - 0.20, 1.46), (0.20, 0.20, 1.10), M(g, "BrakeSteel"), bev=0.0)
        V.box(g, (sx * 1.55, AX_F - 0.20, 1.94), (0.30, 0.30, 0.24), M(g, "BlackMetal"), bev=0.02)
        V.box(g, (sx * HUB_X, AX_F + 0.22, WHEEL_Z), (0.16, 0.30, 0.42), M(g, "BlackMetal"), bev=0.02)
        # front coil spring (three rings) and damper
        for k in range(2):
            V.lathe(g, (sx * 1.55, AX_F - 0.16, 1.36 + 0.22 * k), (0, 0, 1),
                    [(0.30, 0.0), (0.30, 0.05), (0.26, 0.06), (0.0, 0.06)], 12 if g.hi else 9, M(g, "BlackMetal"))
        # brake disc + caliper
        V.lathe(g, (sx * (HUB_X - 0.10), AX_F, WHEEL_Z), (1, 0, 0),
                [(0.0, 0.0), (0.52, 0.0), (0.52, 0.05), (0.0, 0.05)], 14 if g.hi else 10, M(g, "BrakeSteel"))
        V.box(g, (sx * (HUB_X - 0.10), AX_F + 0.40, WHEEL_Z + 0.10), (0.10, 0.22, 0.30), M(g, "BlackPlastic"), bev=0.02)
    V.tube(g, [(-2.0, AX_F + 0.42, 1.06), (2.0, AX_F + 0.42, 1.06)], 0.06, M(g, "BlackMetal"), 8 if g.hi else 6)
    # transfer case, gearbox, prop shafts
    V.box(g, (0, 7.55, 1.12), (1.10, 1.10, 0.62), M(g, "BlackMetal"), bev=0.05)
    V.box(g, (0, 6.20, 1.18), (0.80, 1.80, 0.60), M(g, "BlackMetal"), bev=0.05)
    V.tube(g, [(0, 7.95, 1.14), (0, 11.35, 1.14)], 0.10, M(g, "BrakeSteel"), 10 if g.hi else 8)
    V.box(g, (0, 7.95, 1.14), (0.26, 0.24, 0.26), M(g, "BlackMetal"), bev=0.02)
    V.box(g, (0, 11.35, 1.14), (0.26, 0.24, 0.26), M(g, "BlackMetal"), bev=0.02)
    # rear axle, diff, leaf springs, dampers
    V.tube(g, [(-HUB_X, AX_R, WHEEL_Z), (HUB_X, AX_R, WHEEL_Z)], 0.12, M(g, "BlackMetal"), 12 if g.hi else 10)
    V.lathe(g, (0.10, AX_R, WHEEL_Z), (1, 0, 0), [(0.0, -0.30), (0.26, -0.26), (0.36, -0.10), (0.36, 0.10),
                                                  (0.24, 0.26), (0.0, 0.28)], 14 if g.hi else 10, M(g, "BrakeSteel"))
    for sx in (-1, 1):
        for k in range(2):
            V.box(g, (sx * 1.55, AX_R + 0.05, 1.06 - 0.10 * k), (0.24, 2.90 + 0.6 * k, 0.09), M(g, "BlackMetal"),
                  rot=Matrix.Rotation(math.radians(1.5), 3, "X"), bev=0.02)
        V.box(g, (sx * 1.55, AX_R + 1.42, 1.28), (0.22, 0.20, 0.42), M(g, "BlackMetal"), bev=0.02)
        V.box(g, (sx * 1.55, AX_R - 1.30, 1.28), (0.22, 0.20, 0.42), M(g, "BlackMetal"), bev=0.02)
        V.box(g, (sx * (HUB_X - 0.10), AX_R, WHEEL_Z), (0.14, 0.30, 0.44), M(g, "BlackMetal"), bev=0.03)
        V.lathe(g, (sx * (HUB_X - 0.10), AX_R, WHEEL_Z), (1, 0, 0),
                [(0.0, 0.0), (0.48, 0.0), (0.48, 0.05), (0.0, 0.05)], 12 if g.hi else 9, M(g, "BrakeSteel"))
        # rear damper, angled
        V.box(g, (sx * 1.92, AX_R + 0.62, 1.42), (0.16, 0.16, 0.86), M(g, "BrakeSteel"),
              rot=Matrix.Rotation(math.radians(12 * sx), 3, "X"), bev=0.03)
        V.box(g, (sx * 1.92, AX_R + 0.72, 1.78), (0.24, 0.24, 0.26), M(g, "BlackMetal"), bev=0.03)
    # fuel tank, straps, skid, filler neck
    V.box(g, (1.05, 9.85, 1.28), (1.30, 1.60, 0.62), M(g, "BlackPlastic"), bev=0.10)
    for y in (9.30, 10.40):
        V.box(g, (1.05, y, 1.28), (1.36, 0.08, 0.66), M(g, "BlackMetal"), bev=0.01)
    V.tube(g, [(1.35, 9.60, 1.55), (1.95, 9.90, 1.72), (2.35, 11.10, 2.10)], 0.07, M(g, "Rubber"), 8)
    # exhaust: downpipe, muffler, tailpipe with a chrome tip
    V.tube(g, [(-1.05, 5.60, 1.10), (-1.25, 8.20, 1.02), (-1.25, 9.90, 1.02)], 0.09, M(g, "Exhaust"),
           10 if g.hi else 8, fillet=0.3)
    V.lathe(g, (-1.25, 10.05, 1.02), (0, 1, 0), [(0.0, 0.0), (0.15, 0.03), (0.22, 0.20), (0.22, 0.75),
                                                 (0.15, 0.92), (0.10, 0.96)], 12 if g.hi else 9, M(g, "Exhaust"))
    V.tube(g, [(-1.25, 10.98, 1.02), (-1.25, 12.20, 1.02), (-1.70, 13.90, 1.02), (-1.95, 14.55, 1.06)],
           0.09, M(g, "Exhaust"), 10 if g.hi else 8, fillet=0.25)
    V.lathe(g, (-1.95, 14.60, 1.06), (0, 1, 0), [(0.09, 0.0), (0.11, 0.02), (0.11, 0.10), (0.09, 0.12)],
            10 if g.hi else 8, M(g, "Chrome"))
    # space-saver spare under the bed, between the rails
    V.lathe(g, (0.0, 14.30, 1.00), (0, 0, 1), [(0.20, 0.0), (0.54, 0.02), (0.60, 0.10), (0.60, 0.38),
                                               (0.54, 0.44), (0.20, 0.46)], 14 if g.hi else 10, M(g, "Tyre"))
    V.box(g, (0.0, 14.30, 0.90), (0.50, 1.10, 0.08), M(g, "BlackMetal"), bev=0.02)
    V.box(g, (0.0, 14.90, 1.00), (0.24, 0.14, 0.60), M(g, "BlackMetal"), bev=0.02)
    # mud flaps
    for side in (-1, 1):
        for hy in (AX_F + 1.42, AX_R + 1.42):
            V.box(g, (side * 2.05, hy, 0.82), (0.86, 0.06, 0.62), M(g, "Rubber"), bev=0.03)
    # arch liners
    for side in (-1, 1):
        for hy in (AX_F, AX_R):
            pts = []
            for k in range(11):
                a = math.radians(-98 + 196 * k / 10)
                pts.append(P(side * 1.30, hy + 1.36 * math.sin(a), WHEEL_Z + 1.36 * math.cos(a)))
            V.sweep(g, pts, [(0.0, -0.60), (1.24 * side, -0.60), (1.24 * side, 0.60), (0.0, 0.60)],
                    M(g, "WheelWell"), closed=True, cap0=True, cap1=True)
            # brake line clips
            if g.hi:
                for k in range(3):
                    V.lathe(g, (side * 2.10, hy - 0.6 + 0.6 * k, 1.4), (side, 0, 0),
                            [(0.03, 0.0), (0.03, 0.02), (0.0, 0.025)], 6, "BlackPlastic")


# --------------------------------------------------------------------------- rack, board, lockers, light bar
def light_bar(g):
    V.box(g, (0, 6.24, 5.445), (4.20, 0.50, 0.10), M(g, "Stainless"), bev=0.03)
    V.box(g, (0, 6.24, 5.525), (4.06, 0.44, 0.14), M(g, "BlackPlastic"), bev=0.03)
    V.box(g, (0, 6.24, 5.63), (4.02, 0.40, 0.10), M(g, "Stainless"), bev=0.025)
    for x in (-1.62, -0.54, 0.54, 1.62):
        V.lathe(g, (x, 6.24, 5.60), (0, 0, 1),
                [(0.27, 0.0), (0.27, 0.03), (0.25, 0.07), (0.23, 0.18), (0.19, 0.26), (0.12, 0.30), (0.0, 0.31)],
                20 if g.hi else 14, M(g, "LensAmber"),
                matfn=(lambda i, j: "BlackPlastic" if i <= 1 else "LensAmber") if g.hi else None)
        V.lathe(g, (x, 6.24, 5.58), (0, 0, 1), [(0.30, 0.0), (0.30, 0.04), (0.26, 0.06)],
                20 if g.hi else 14, M(g, "BlackPlastic"))
    for sx in (-1, 1):
        V.box(g, (sx * 2.10, 6.24, 5.47), (0.12, 0.40, 0.16), M(g, "BlackPlastic"), bev=0.02)
        V.tube(g, [(sx * 2.10, 6.30, 5.40), (sx * 2.10, 6.36, 5.34)], 0.035, M(g, "BlackPlastic"), 6)
    if g.hi:
        for x in (-1.08, 0.0, 1.08):
            V.box(g, (x, 6.24, 5.575), (0.06, 0.36, 0.09), "BlackPlastic")
        for sx in (-1, 1):
            V.lathe(g, (sx * 2.10, 6.24, 5.40), (0, 0, 1), [(0.03, 0.0), (0.03, 0.03)], 6, "BlackPlastic")


def rack(g):
    light_bar(g)
    # roll hoop with rear stays
    for sx in (-1, 1):
        V.tube(g, [(sx * 2.24, 11.20, 2.66), (sx * 2.24, 11.20, 4.30), (sx * 2.24, 11.28, 5.36),
                   (sx * 2.24, 11.32, 5.44)], 0.09, M(g, "BlackMetal"), 12 if g.hi else 10, fillet=0.35)
        V.tube(g, [(sx * 2.24, 11.30, 5.42), (sx * 2.24, 13.20, 4.44)], 0.07, M(g, "BlackMetal"),
               10 if g.hi else 8, fillet=0.2)
        V.box(g, (sx * 2.24, 11.24, 2.66), (0.28, 0.34, 0.10), M(g, "BlackMetal"), bev=0.03)
    V.tube(g, [(-2.24, 11.32, 5.42), (2.24, 11.32, 5.42)], 0.09, M(g, "BlackMetal"), 12 if g.hi else 10)
    # bed rack rails and posts
    for sx in (-1, 1):
        V.tube(g, [(sx * 2.24, 11.30, 5.40), (sx * 2.24, 15.58, 5.40)], 0.075, M(g, "Aluminium"),
               10 if g.hi else 8)
        for y in (11.44, 15.40):
            V.tube(g, [(sx * 2.24, y, 4.48), (sx * 2.24, y, 5.40)], 0.06, M(g, "Aluminium"), 8 if g.hi else 6)
            V.box(g, (sx * 2.24, y, 4.46), (0.24, 0.28, 0.08), M(g, "Aluminium"), bev=0.02)
    for y in (11.40, 15.44):
        V.tube(g, [(-2.28, y, 5.40), (2.28, y, 5.40)], 0.075, M(g, "Aluminium"), 10 if g.hi else 8)
    # rescue board on the cross bars, straps and leash
    V.box(g, (0, 13.70, 5.525), (1.64, 5.7, 0.15), M(g, "KitYellow"), bev=0.32)
    V.box(g, (0, 13.70, 5.605), (0.95, 5.0, 0.02), M(g, "KitYellow"), bev=0.18)
    for y in (12.55, 14.90):
        V.box(g, (0, y, 5.605), (1.70, 0.16, 0.03), M(g, "Webbing"), bev=0.0)
        V.box(g, (0.62, y, 5.58), (0.16, 0.10, 0.10), M(g, "BlackPlastic"), bev=0.01)
    V.tube(g, [(0.82, 15.60, 5.55), (1.25, 15.85, 5.30), (1.62, 15.90, 4.55)], 0.035, M(g, "Webbing"),
           8 if g.hi else 6, fillet=0.25)
    if g.hi:
        for k in range(3):
            V.box(g, (0, 12.30 + 1.05 * k, 5.585), (1.42, 0.05, 0.012), "KitYellow")
    # work lamps on the hoop
    for x in (-1.30, 1.30):
        V.box(g, (x, 11.28, 5.30), (0.34, 0.16, 0.26), M(g, "BlackPlastic"), bev=0.04)
        V.lathe(g, (x, 11.37, 5.30), (0, 1, 0), [(0.13, 0.0), (0.13, 0.02), (0.0, 0.03)],
                14 if g.hi else 12, M(g, "LensWhite"))
        V.tube(g, [(x, 11.28, 5.18), (x, 11.28, 5.40), (x + (0.12 if x > 0 else -0.12), 11.26, 5.44)],
               0.025, M(g, "BlackPlastic"), 6)
    # GPS puck on the hoop corner
    V.lathe(g, (-2.08, 11.40, 5.46), (0, 0, 1), [(0.16, 0.0), (0.16, 0.05), (0.12, 0.09), (0.0, 0.10)],
            14 if g.hi else 10, M(g, "BlackPlastic"))


def kit(g):
    # headboard grille behind the cab
    for sx in (-1, 1):
        V.tube(g, [(sx * 2.20, 11.10, 2.64), (sx * 2.20, 11.10, 4.86)], 0.06, M(g, "Aluminium"), 8 if g.hi else 6)
    for z in (2.70, 4.80):
        V.tube(g, [(-2.22, 11.10, z), (2.22, 11.10, z)], 0.06, M(g, "Aluminium"), 8 if g.hi else 6)
    for k in range(5):
        V.tube(g, [(-1.60 + 0.80 * k, 11.10, 2.70), (-1.60 + 0.80 * k, 11.10, 4.80)], 0.045,
               M(g, "Aluminium"), 6)
    # two kit lockers on the bed floor
    for side in (1, -1):
        x = side * 1.55
        V.box(g, (x, 12.55, 2.98), (1.42, 1.30, 0.70), M(g, "Aluminium"), bev=0.06)
        V.box(g, (x, 12.55, 3.36), (1.48, 1.36, 0.07), M(g, "Aluminium"), bev=0.02)
        V.box(g, (x, 13.14, 3.25), (0.34, 0.08, 0.16), M(g, "Chrome"), bev=0.02)
        for dx in (-0.44, 0.44):
            V.box(g, (x + dx, 13.22, 3.20), (0.16, 0.06, 0.12), M(g, "Chrome"), bev=0.015)
        V.box(g, (x, 12.55, 3.07), (0.60, 0.03, 0.18), M(g, "KitYellow"), bev=0.0)
        if g.hi:
            for k in range(4):
                V.box(g, (x - 0.5 + 0.33 * k, 13.20, 2.98), (0.02, 0.02, 0.60), "Aluminium")
            V.box(g, (x, 12.55, 3.395), (1.30, 0.10, 0.02), "Aluminium")
    # rope coil and rescue tube on the bed floor
    for k in range(3):
        V.lathe(g, (-0.10, 14.10, 2.70 + 0.10 * k), (0, 0, 1),
                [(0.46, 0.0), (0.56, 0.02), (0.58, 0.05), (0.48, 0.07)], 18 if g.hi else 14, M(g, "Webbing"))
    V.lathe(g, (1.35, 14.05, 2.76), (0, 1, 0), [(0.0, 0.0), (0.17, 0.05), (0.20, 0.30), (0.20, 1.10), (0.17, 1.35),
                                                (0.0, 1.40)], 14 if g.hi else 10, M(g, "KitOrange"))
    V.tube(g, [(1.35, 13.55, 2.70), (1.05, 13.20, 2.66), (0.75, 12.86, 2.68)], 0.022, M(g, "Webbing"),
           6, fillet=0.15)
