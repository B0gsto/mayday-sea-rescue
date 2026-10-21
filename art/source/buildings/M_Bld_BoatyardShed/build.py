"""H4 M_Bld_BoatyardShed: Port Haven boatyard (docs/12 row, 10 section 1.2, 05).

A 30 x 15 m portal-frame steel boat shed with 9 m eaves: weathered grey-green box-profile cladding, low-pitch
roof with standing seams and translucent roof-light strips, a partly open 7.8 x 6.4 m roller door showing the
dark interior (frames, purlins, a hull under repair), a personnel door, gutters/downpipes, rust streaks and a
faded painted PORT HAVEN BOATYARD sign. The 80 x 50 m yard carries the kit: a steel keel cradle with timber
bunks, a pair of adjustable prop stands, a diesel + petrol pump pair on a kerbed island with hoses and nozzles,
a price board, yard lamps, bollards and markings. The travel hoist is a separate asset (M_Hbr_TravelHoist).

Frame: metres x 3 = studs. Yard floor is z 0; the shed sits at x -20..10, y -7.5..7.5, the open yard at +X.
Origin is the yard centre, base on the floor.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/buildings/M_Bld_BoatyardShed/build.py \
      --out-root build/prod/M_Bld_BoatyardShed --steps build,validate,export,turntable
    python3 art/source/buildings/M_Bld_BoatyardShed/maketex.py
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geo  # noqa: E402
from geo import Part, trim  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_BoatyardShed"
TEX = G + "build/prod/M_Bld_BoatyardShed/textures/M_Bld_BoatyardShed/"
SHARED = G + "assets/textures/"

D = {  # T_Yard_Details atlas (maketex.D)
    "Clad": (0.000, 0.560, 0.500, 1.000), "Inner": (0.500, 0.820, 0.720, 1.000),
    "Roof": (0.720, 0.760, 1.000, 1.000), "Light": (0.720, 0.680, 1.000, 0.760),
    "Sign": (0.000, 0.400, 0.500, 0.480), "Roller": (0.500, 0.360, 0.720, 0.560),
    "Door": (0.720, 0.360, 0.820, 0.560), "Glass": (0.820, 0.360, 1.000, 0.560),
    "Price": (0.000, 0.180, 0.260, 0.400), "Diesel": (0.260, 0.180, 0.380, 0.400),
    "Petrol": (0.380, 0.180, 0.500, 0.400), "Lit": (0.500, 0.180, 0.640, 0.360),
    "Conc": (0.000, 0.000, 0.300, 0.180), "Tarmac": (0.300, 0.000, 0.600, 0.180),
    "Mark": (0.600, 0.000, 0.750, 0.090), "Rust": (0.750, 0.000, 0.875, 0.180),
    "Dark": (0.875, 0.000, 1.000, 0.180),
    "Timber": (0.640, 0.180, 0.750, 0.360),
}


def rect(name, w, h, pad=0.0025):
    u0, v0, u1, v1 = D[name]
    return ("rect", u0 + pad, v0 + pad, u1 - pad, v1 - pad, w, h)


def flat(name, k=0.0005):
    u0, v0, u1, v1 = D[name]
    cu, cv = (u0 + u1) / 2, (v0 + v1) / 2

    def f(p):
        return (cu + (p.x + p.y) * k, cv + (p.y + p.z) * k)
    return ("fn", f)


CLAD_X = ("tile", 2.0)
CLAD_Y = ("tile", 2.0)
INNER = flat("Inner")
ROOFT = ("tile", 2.0)
LIGHT = rect("Light", 24.0, 0.94)
CONC = ("tile", 5.0)
TARMAC = ("tile", 7.0)
ROLLER = rect("Roller", 7.8, 2.1)
MARK = flat("Mark")
RUST = rect("Rust", 0.4, 2.5)
TIMBER = rect("Timber", 1.0, 0.5)

GUTTER = ("tile", 1.0)
DOWNPIPE = ("tile", 1.0)
FASCIA = ("tile", 1.0)
FLASH = ("tile", 1.0)

# ------------------------------------------------------------------ layout (m)
X0, X1, Y0, Y1 = -20.0, 10.0, -7.5, 7.5
EAVE = 8.90
PITCH = 0.14
RIDGE = EAVE + 7.5 * PITCH + 0.16            # outer ridge 10.11
UNDER_RIDGE = EAVE + 7.5 * PITCH             # 9.95
ROOF_OVH = 0.40
GABLE_OVH = 0.35
THICK = 0.16
RD_Y0, RD_Y1, RD_H, RD_OPEN = -5.4, 2.4, 6.4, 4.3
PD_Y0, PD_Y1, PD_H = 4.2, 5.2, 2.1
YX, YY = 40.0, 25.0


def rz(y, up=0.0):
    return UNDER_RIDGE - abs(y) * PITCH + up


def roof_face(part, side, zoff, mode):
    """One roof slope quad (side -1 near, +1 far) extending to the overhangs."""
    ey = side * (Y1 + ROOF_OVH)
    ry = 0.0
    pts = [(X0 - GABLE_OVH, ry, rz(ry, zoff)), (X1 + GABLE_OVH, ry, rz(ry, zoff)),
           (X1 + GABLE_OVH, ey, rz(ey, zoff)), (X0 - GABLE_OVH, ey, rz(ey, zoff))]
    if side < 0:
        pts.reverse()
    part.face(pts, mode, outward=(0, 0, 1))


def build():
    clad, roof, light, inner, doors, signs, glass = (Part("Clad"), Part("Roof"), Part("RoofLight"), Part("Inner"),
                                                     Part("Doors"), Part("Signs"), Part("Glass"))
    steel, trim_p, ground, mark, timber, lit = (Part("Steel"), Part("Trim"), Part("Ground"), Part("Markings"),
                                                Part("Timber"), Part("Lit"))
    atts = {}

    # ================================================================ yard floor
    geo.LEVEL = 3
    ground.face([(-YX, -YY, 0.0), (YX, -YY, 0.0), (YX, YY, 0.0), (-YX, YY, 0.0)], TARMAC, outward=(0, 0, 1))
    ground.face([(-21.0, -9.4, 0.015), (14.0, -9.4, 0.015), (14.0, 9.4, 0.015), (-21.0, 9.4, 0.015)],
                CONC, outward=(0, 0, 1))
    ground.box((22.0, 13.0, 0.0), (26.0, 15.0, 0.20), CONC)
    ground.box((26.0, 13.0, 0.0), (26.4, 15.0, 0.30), CONC)
    ground.box((-YX, -YY, 0.0), (YX, -YY + 0.34, 0.24), CONC)          # seaward kerb
    for x in (-30.0, -18.0, -6.0, 6.0, 18.0, 30.0):
        ground.box((x - 0.18, -YY, 0.24), (x + 0.18, -YY + 0.34, 0.30), CONC)

    # markings: apron hatch, two bays, fuel island outline
    geo.LEVEL = 2
    for i in range(8):
        x = 11.2 + i * 1.35
        mark.face([(x, -4.7, 0.018), (x + 0.28, -4.7, 0.018), (x + 0.28, 2.0, 0.018), (x, 2.0, 0.018)],
                  MARK, outward=(0, 0, 1))
    for i in range(6):
        y = -17.5 + i * 1.9
        mark.face([(14.0, y, 0.018), (20.0, y, 0.018), (20.0, y + 0.16, 0.018), (14.0, y + 0.16, 0.018)],
                  MARK, outward=(0, 0, 1))
        mark.face([(20.3, y, 0.018), (27.5, y, 0.018), (27.5, y + 0.16, 0.018), (20.3, y + 0.16, 0.018)],
                  MARK, outward=(0, 0, 1))
    mark.face([(22.0, 12.8, 0.205), (26.0, 12.8, 0.205), (26.0, 12.9, 0.205), (22.0, 12.9, 0.205)], MARK, outward=(0, 0, 1))
    mark.face([(22.0, 15.1, 0.205), (26.0, 15.1, 0.205), (26.0, 15.2, 0.205), (22.0, 15.2, 0.205)], MARK, outward=(0, 0, 1))
    mark.face([(21.8, 13.0, 0.205), (21.9, 13.0, 0.205), (21.9, 15.0, 0.205), (21.8, 15.0, 0.205)], MARK, outward=(0, 0, 1))
    mark.face([(26.1, 13.0, 0.205), (26.2, 13.0, 0.205), (26.2, 15.0, 0.205), (26.1, 15.0, 0.205)], MARK, outward=(0, 0, 1))

    # bollards along the seaward edge (LOD0 only)
    geo.LEVEL = 1
    for x in (-26.0, -14.0, -2.0, 10.0, 22.0, 34.0):
        steel.tube((x, -23.6, 0.24), (x, -23.6, 0.92), 0.10, 10, ("tile", 0.7))
        steel.tube((x, -23.6, 0.92), (x, -23.6, 1.00), 0.14, 10, ("tile", 0.7))
        steel.box((x - 0.14, -23.74, 0.24), (x + 0.14, -23.46, 0.30), ("tile", 0.7))

    # ================================================================ shed shell
    # front gable (+X): roller door and personnel door, real openings
    prof_f = [(Y0, 0.0), (Y1, 0.0), (Y1, EAVE), (0.0, UNDER_RIDGE), (Y0, EAVE)]
    holes_f = [(RD_Y0, RD_Y1, -0.5, RD_H), (PD_Y0, PD_Y1, -0.5, PD_H)]
    geo.LEVEL = 3
    clad.pierced(prof_f, "x", X1 - THICK, X1, holes_f, CLAD_Y)
    prof_b = [(Y0, 0.0), (Y1, 0.0), (Y1, EAVE), (0.0, UNDER_RIDGE), (Y0, EAVE)]
    clad.pierced(prof_b, "x", X0, X0 + THICK, [], CLAD_Y)
    # side walls
    for sy in (-1, 1):
        y_out, y_in = (Y0, Y0 + THICK) if sy < 0 else (Y1, Y1 - THICK)
        clad.box((X0, min(y_out, y_in), 0.0), (X1, max(y_out, y_in), EAVE), CLAD_X)
    # concrete plinth upstand round the shed
    for sy in (-1, 1):
        y0, y1 = (Y0 - 0.07, Y0) if sy < 0 else (Y1, Y1 + 0.07)
        ground.box((X0 - 0.07, y0, 0.0), (X1 + 0.07, y1, 0.34), CONC)
    ground.box((X0 - 0.07, Y0, 0.0), (X0, Y1, 0.34), CONC)
    ground.box((X1, Y0, 0.0), (X1 + 0.07, Y1, 0.34), CONC)

    # ------------------------------------------------ roof
    geo.LEVEL = 3
    for sy in (-1, 1):
        roof_face(roof, sy, 0.16, ROOFT)
        roof_face(inner, sy, 0.0, INNER)
    # eaves fascia and gable bargeboards
    for sy in (-1, 1):
        y = sy * (Y1 + ROOF_OVH)
        trim_p.box((X0 - GABLE_OVH, y - 0.04, rz(y, 0.0)), (X1 + GABLE_OVH, y + 0.04, rz(y, 0.20)), FASCIA)
    for sx in (-1, 1):
        x = X1 + GABLE_OVH if sx > 0 else X0 - GABLE_OVH
        for sy in (-1, 1):
            p0 = (x, 0.0, rz(0.0, 0.10))
            p1 = (x, sy * (Y1 + ROOF_OVH), rz(sy * (Y1 + ROOF_OVH), 0.10))
            trim_p.prism([(p0[1], p0[2] - 0.15), (p1[1], p1[2] - 0.15), (p1[1], p1[2] + 0.03),
                          (p0[1], p0[2] + 0.03)], "x", x - 0.035, x + 0.035, FASCIA)
    # ridge capping
    trim_p.prism([(-0.16, RIDGE - 0.06), (0.16, RIDGE - 0.06), (0.0, RIDGE + 0.10)], "x",
                 X0 - GABLE_OVH - 0.1, X1 + GABLE_OVH + 0.1, FLASH)

    # standing seams: one per 0.65 m, along the slope (LOD0 only)
    geo.LEVEL = 1
    x = X0 - GABLE_OVH + 0.3
    while x < X1 + GABLE_OVH:
        for sy in (-1, 1):
            y0, y1 = sy * (Y1 + ROOF_OVH), 0.0
            z0, z1 = rz(y0, 0.19), rz(y1, 0.19)
            roof.prism([(y0, z0), (y1, z1), (y1, z1 + 0.035), (y0, z0 + 0.035)], "x",
                       x - 0.025, x + 0.025, ("tile", 1.0))
        x += 0.65
    # translucent roof-light strips: 3 per slope
    geo.LEVEL = 2
    for ay in (3.1, 5.6):
        for sy in (-1, 1):
            y = sy * ay
            hy = 0.32
            for xa, xb in ((-15.0, 9.0),):
                pts = [(xa, y - hy, rz(y - hy, 0.205)), (xb, y - hy, rz(y - hy, 0.205)),
                       (xb, y + hy, rz(y + hy, 0.205)), (xa, y + hy, rz(y + hy, 0.205))]
                if sy < 0:
                    pts.reverse()
                light.face(pts, LIGHT, outward=(0, 0, 1))
                for yy in (y - hy, y + hy):
                    roof.box((xa, yy - 0.035, rz(yy, 0.16)), (xb, yy + 0.035, rz(yy, 0.24)), ("tile", 1.0))
            for xa, xb in ((-15.0, -14.9), (8.9, 9.0)):
                roof.box((xa, y - hy, rz(y, 0.16)), (xb, y + hy, rz(y, 0.26)), ("tile", 1.0))

    # ------------------------------------------------ gutters and downpipes (LOD0 only)
    geo.LEVEL = 1
    for sy in (-1, 1):
        cy = sy * (Y1 + ROOF_OVH + 0.02)
        zg = rz(cy, 0.0)
        prof = [(cy - 0.09, zg - 0.12), (cy - 0.09, zg + 0.02), (cy - 0.05, zg + 0.05),
                (cy + 0.05, zg + 0.05), (cy + 0.09, zg + 0.02), (cy + 0.09, zg - 0.12),
                (cy + 0.06, zg - 0.12), (cy + 0.06, zg - 0.01), (cy - 0.06, zg - 0.01), (cy - 0.06, zg - 0.12)]
        trim_p.extrude(prof, "x", X0 - 0.2, X1 + 0.2, GUTTER, caps=False)
        for xb in [X0 + 1.0 + i * 2.0 for i in range(15)]:
            trim_p.box((xb - 0.03, cy - 0.10, zg - 0.14), (xb + 0.03, cy + 0.10, zg - 0.10), FLASH)
        for xd in (X0 + 0.5, X1 - 0.5):
            px, py = xd, sy * (Y1 + 0.26)
            trim_p.tube((px, py, 0.24), (px, py, zg - 0.32), 0.062, 8, DOWNPIPE)
            trim_p.box((px - 0.11, py - 0.11, zg - 0.40), (px + 0.11, py + 0.11, zg - 0.22), FLASH)
            trim_p.tube((px, py, zg - 0.22), (px, py, zg - 0.03), 0.075, 8, DOWNPIPE)
            trim_p.tube((px, py - sy * 0.14, 0.06), (px, py, 0.26), 0.075, 8, DOWNPIPE)
            for zz in (1.4, 3.0, 4.6, 6.2, 7.8):
                trim_p.box((px - 0.085, py - 0.085, zz), (px + 0.085, py + 0.085, zz + 0.05), FLASH)

    # ------------------------------------------------ interior lining + floor
    geo.LEVEL = 3
    inner.face([(X0 + THICK + 0.015, Y0, 0.05), (X0 + THICK + 0.015, Y1, 0.05),
                (X0 + THICK + 0.015, Y1, EAVE), (X0 + THICK + 0.015, 0.0, UNDER_RIDGE),
                (X0 + THICK + 0.015, Y0, EAVE)], INNER, outward=(1, 0, 0))
    for sy in (-1, 1):
        y = (Y1 - THICK - 0.015) if sy > 0 else (Y0 + THICK + 0.015)
        inner.face([(X0, y, 0.04), (X1, y, 0.04), (X1, y, EAVE), (X0, y, EAVE)], INNER, outward=(0, -sy, 0))
    ground.face([(X0 + 0.05, Y0 + 0.05, 0.03), (X1 - 0.05, Y0 + 0.05, 0.03),
                 (X1 - 0.05, Y1 - 0.05, 0.03), (X0 + 0.05, Y1 - 0.05, 0.03)], ("tile", 3.0), outward=(0, 0, 1))

    # ------------------------------------------------ portal frames and purlins (LOD0 only)
    geo.LEVEL = 1
    for fx in (-17.5, -12.5, -7.5, -2.5, 2.5, 7.5):
        for sy in (-1, 1):
            cy = sy * 7.15
            for yy in (cy - 0.13, cy + 0.13):
                steel.box((fx - 0.18, yy - 0.016, 0.05), (fx + 0.18, yy + 0.016, 8.92), ("tile", 1.0))
            steel.box((fx - 0.03, cy - 0.13, 0.05), (fx + 0.03, cy + 0.13, 8.92), ("tile", 1.0))
        for sy in (-1, 1):
            y0, z0 = sy * 7.15, 8.82
            y1, z1 = 0.0, UNDER_RIDGE - 0.12
            dy, dz = y1 - y0, z1 - z0
            ln = math.hypot(dy, dz)
            ny, nz = -dz / ln, dy / ln
            hw, hh = 0.15, 0.11
            prof = [(y0 + ny * hw, z0 + nz * hw), (y1 + ny * hw, z1 + nz * hw),
                    (y1 - ny * hw, z1 - nz * hw), (y0 - ny * hw, z0 - nz * hw)]
            steel.prism(prof, "x", fx - 0.09, fx + 0.09, ("tile", 1.0))
    for ay in (2.6, 5.1):
        for sy in (-1, 1):
            y = sy * ay
            z = rz(y, -0.10)
            steel.box((X0 + 0.1, y - 0.055, z - 0.10), (X1 - 0.1, y + 0.055, z), ("tile", 1.0))
    for fx in (-17.5, -12.5, -7.5, -2.5, 2.5, 7.5):
        steel.box((fx - 0.045, Y0 + 0.16, 0.05), (fx + 0.045, Y1 - 0.16, 0.18), ("tile", 1.0))

    # a hull under repair inside, on trestles
    geo.LEVEL = 2
    sections = [(0.7, 0.05, 1.45), (1.7, 0.85, 1.55), (3.0, 1.18, 1.55), (4.3, 1.20, 1.52),
                (5.6, 0.95, 1.42), (6.7, 0.42, 1.24), (7.3, 0.04, 1.06)]
    sec = []
    for hx, hw, sheer in sections:
        sec.append([(hx, 0.0, 0.62), (hx, -hw * 0.62, 0.76), (hx, -hw, sheer),
                    (hx, hw, sheer), (hx, hw * 0.62, 0.76)])
    for i in range(len(sec) - 1):
        A, B = sec[i], sec[i + 1]
        for k in range(4):
            quad = [A[k], A[k + 1], B[k + 1], B[k]]
            inner.face(quad, INNER, outward=(0, -1, 0) if k < 2 else (0, 1, 0))
    inner.face([sec[0][0], sec[0][2], sec[0][3]], INNER, outward=(-1, 0, 0))
    geo.LEVEL = 1
    for hx, hw, sheer in (sections[1], sections[3], sections[5]):
        steel.tube((hx, -hw * 0.9, 0.45), (hx, 0.0, 0.20), 0.035, 5, ("tile", 1.0))
        steel.tube((hx, hw * 0.9, 0.45), (hx, 0.0, 0.20), 0.035, 5, ("tile", 1.0))
    for hx in (2.1, 5.2):
        for sy in (-1, 1):
            steel.tube((hx, sy * 0.95, 0.10), (hx, sy * 0.95, 0.68), 0.045, 6, ("tile", 1.0))
            timber.box((hx - 0.09, sy * 0.95 - 0.09, 0.62), (hx + 0.09, sy * 0.95 + 0.09, 0.74), TIMBER)

    # ------------------------------------------------ big roller door (partly open)
    geo.LEVEL = 2
    for y in (RD_Y0 - 0.10, RD_Y1 + 0.10):
        steel.box((X1 - 0.30, y - 0.055, 0.0), (X1 - 0.16, y + 0.055, RD_H + 0.22), ("tile", 1.0))
        for zz in (0.3, 1.2, 2.4, 3.6, 4.8, 6.0):
            steel.box((X1 - 0.31, y - 0.075, zz), (X1 - 0.15, y + 0.075, zz + 0.05), ("tile", 1.0))
    steel.box((X1 - 0.34, RD_Y0 - 0.22, RD_H), (X1 - 0.10, RD_Y1 + 0.22, RD_H + 0.36), ("tile", 1.0))
    steel.box((X1 - 0.28, RD_Y0 - 0.12, RD_H + 0.36), (X1 - 0.12, RD_Y0 + 0.55, RD_H + 0.62), ("tile", 1.0))
    steel.box((X1 - 0.10, RD_Y1 + 0.02, RD_H + 0.02), (X1 + 0.02, RD_Y1 + 0.24, RD_H + 0.42), ("tile", 1.0))
    # curtain hangs from the top to 4.3 m
    geo.LEVEL = 3
    ty = (RD_Y0 + RD_Y1) / 2
    doors.face([(X1 - 0.22, RD_Y0 + 0.06, RD_OPEN), (X1 - 0.22, RD_Y1 - 0.06, RD_OPEN),
                (X1 - 0.22, RD_Y1 - 0.06, RD_H - 0.08), (X1 - 0.22, RD_Y0 + 0.06, RD_H - 0.08)],
               ROLLER, outward=(-1, 0, 0))
    doors.face([(X1 - 0.20, RD_Y0 + 0.06, RD_OPEN), (X1 - 0.20, RD_Y1 - 0.06, RD_OPEN),
                (X1 - 0.20, RD_Y1 - 0.06, RD_H - 0.08), (X1 - 0.20, RD_Y0 + 0.06, RD_H - 0.08)],
               ROLLER, outward=(1, 0, 0))
    steel.box((X1 - 0.26, RD_Y0 + 0.02, RD_OPEN - 0.08), (X1 - 0.14, RD_Y1 - 0.02, RD_OPEN + 0.02), ("tile", 1.0))
    steel.tube((X1 - 0.20, RD_Y0 + 0.05, RD_H - 0.12), (X1 - 0.20, RD_Y1 - 0.05, RD_H - 0.12), 0.17, 12,
               ("tile", 1.0))
    # warning stripes on the guide rails
    for y in (RD_Y0 - 0.10, RD_Y1 + 0.10):
        for i in range(5):
            z = 0.25 + i * 0.33
            mark.box((X1 - 0.315, y - 0.057, z), (X1 - 0.305, y + 0.057, z + 0.19), MARK)
    atts["ATT_RollerDoor"] = Vector((X1 + 0.15, ty, 0.06))
    atts["ATT_HoistBay"] = Vector((16.0, 0.0, 0.02))

    # ------------------------------------------------ personnel door
    geo.LEVEL = 3
    py0, py1 = PD_Y0 + 0.06, PD_Y1 - 0.06
    for y, z0, z1 in ((PD_Y0 - 0.06, 0.0, PD_H + 0.08), (PD_Y1 + 0.06, 0.0, PD_H + 0.08)):
        trim_p.box((X1 - 0.26, y - 0.04, z0), (X1 - 0.10, y + 0.04, z1), FASCIA)
    trim_p.box((X1 - 0.26, PD_Y0 - 0.06, PD_H), (X1 - 0.10, PD_Y1 + 0.06, PD_H + 0.10), FASCIA)
    doors.box((X1 - 0.23, py0, 0.03), (X1 - 0.18, py1, PD_H - 0.05), rect("Door", 1.0, 2.05))
    glass.face([(X1 - 0.175, PD_Y0 + 0.22, 1.42), (X1 - 0.175, PD_Y1 - 0.16, 1.42),
                (X1 - 0.175, PD_Y1 - 0.16, 1.82), (X1 - 0.175, PD_Y0 + 0.22, 1.82)],
               rect("Glass", 0.56, 0.40), outward=(1, 0, 0))
    steel.box((X1 - 0.18, PD_Y0 + 0.10, 1.00), (X1 - 0.15, PD_Y0 + 0.17, 1.06), ("tile", 1.0))
    trim_p.box((X1 - 0.40, PD_Y0 + 0.02, PD_H + 0.35), (X1 - 0.24, PD_Y1 - 0.02, PD_H + 0.42), FASCIA)
    lit.box((X1 - 0.27, (PD_Y0 + PD_Y1) / 2 - 0.16, PD_H + 0.54),
            (X1 - 0.10, (PD_Y0 + PD_Y1) / 2 + 0.16, PD_H + 0.66), rect("Lit", 0.32, 0.12))
    steel.box((X1 - 0.11, (PD_Y0 + PD_Y1) / 2 - 0.20, PD_H + 0.44),
              (X1 - 0.03, (PD_Y0 + PD_Y1) / 2 + 0.20, PD_H + 0.55), ("tile", 1.0))
    atts["ATT_PersonnelDoor"] = Vector((X1 + 0.15, (PD_Y0 + PD_Y1) / 2, 0.05))
    atts["ATT_Lamp_Door"] = Vector((X1 - 0.03, (PD_Y0 + PD_Y1) / 2, PD_H + 0.52))

    # ------------------------------------------------ painted gable sign + floodlights
    geo.LEVEL = 3
    sy0, sy1 = -6.3, 3.5
    trim_p.box((X1 + 0.005, sy0, 7.30), (X1 + 0.045, sy1, 8.55), FLASH)
    signs.face([(X1 + 0.047, sy0 + 0.05, 7.34), (X1 + 0.047, sy1 - 0.05, 7.34),
                (X1 + 0.047, sy1 - 0.05, 8.51), (X1 + 0.047, sy0 + 0.05, 8.51)],
               rect("Sign", 9.6, 1.18), outward=(1, 0, 0))
    for a, b, z0, z1 in ((sy0, sy1, 8.55, 8.60), (sy0, sy1, 7.25, 7.30)):
        trim_p.box((X1 + 0.002, a, z0), (X1 + 0.055, b, z1), FASCIA)
    atts["ATT_Sign"] = Vector((X1 + 0.12, (sy0 + sy1) / 2, 7.92))
    for i, yl in enumerate((-4.4, 0.9)):
        steel.box((X1 + 0.02, yl - 0.22, 8.66), (X1 + 0.30, yl + 0.22, 8.78), ("tile", 1.0))
        lit.box((X1 + 0.28, yl - 0.18, 8.60), (X1 + 0.31, yl + 0.18, 8.68), rect("Lit", 0.36, 0.08))
        atts["ATT_Lamp_Sign_%02d" % (i + 1)] = Vector((X1 + 0.34, yl, 8.64))

    # rust streaks on the gable and side walls (thin textured strips, LOD0/1)
    geo.LEVEL = 1
    for y, w, z0, z1 in ((-6.8, 0.30, 4.2, 8.2), (-3.7, 0.20, 5.7, 8.7), (1.1, 0.26, 3.9, 8.5),
                         (6.4, 0.34, 2.8, 8.4)):
        signs.face([(X1 + 0.012, y - w / 2, z0), (X1 + 0.012, y + w / 2, z0),
                    (X1 + 0.012, y + w / 2, z1), (X1 + 0.012, y - w / 2, z1)],
                   rect("Rust", w, z1 - z0), outward=(1, 0, 0))
    for sy in (-1, 1):
        y = sy * (Y1 + 0.008)
        for x, w, z0, z1 in ((-16.5, 0.40, 2.2, 8.4), (-8.0, 0.26, 4.8, 8.6), (2.5, 0.30, 3.6, 8.5)):
            signs.face([(x - w / 2, y, z0), (x + w / 2, y, z0), (x + w / 2, y, z1), (x - w / 2, y, z1)],
                       rect("Rust", w, z1 - z0), outward=(0, sy, 0))

    # yard lamp post
    geo.LEVEL = 2
    lx, ly = 12.5, -10.6
    steel.tube((lx, ly, 0.0), (lx, ly, 5.6), 0.075, 10, ("tile", 1.0))
    steel.tube((lx, ly, 5.6), (lx, ly, 5.78), 0.14, 10, ("tile", 1.0))
    steel.box((lx - 0.10, ly - 0.10, 0.0), (lx + 0.10, ly + 0.10, 0.30), ("tile", 1.0))
    steel.box((lx - 0.12, ly - 0.38, 5.55), (lx + 0.12, ly + 0.10, 5.66), ("tile", 1.0))
    lit.box((lx - 0.10, ly - 0.36, 5.50), (lx + 0.10, ly + 0.08, 5.55), rect("Lit", 0.4, 0.16))
    atts["ATT_Lamp_Yard"] = Vector((lx, ly, 5.4))

    # ------------------------------------------------ road side: sign, ribbon glazing, side door (LOD0 only)
    geo.LEVEL = 1
    sy = Y0 - 0.012
    signs.box((-8.1, sy, 7.84), (0.1, sy + 0.012, 8.82), flat("Dark"))
    signs.face([(-8.0, sy - 0.004, 7.90), (0.0, sy - 0.004, 7.90),
                (0.0, sy - 0.004, 8.76), (-8.0, sy - 0.004, 8.76)], rect("Sign", 8.0, 0.86), outward=(0, -1, 0))
    trim_p.box((-8.15, sy + 0.005, 8.82), (0.15, sy + 0.03, 8.88), ("tile", 1.0))
    trim_p.box((-8.15, sy + 0.005, 7.80), (0.15, sy + 0.03, 7.86), ("tile", 1.0))
    for xw in (-17.0, -11.0, 2.0):
        trim_p.box((xw - 1.28, sy - 0.045, 6.94), (xw + 1.28, sy + 0.02, 7.02), ("tile", 1.0))
        trim_p.box((xw - 1.28, sy - 0.045, 7.76), (xw + 1.28, sy + 0.02, 7.84), ("tile", 1.0))
        for xf in (xw - 1.22, xw - 0.03, xw + 1.16):
            trim_p.box((xf, sy - 0.045, 7.0), (xf + 0.06, sy + 0.02, 7.80), ("tile", 1.0))
        glass.face([(xw - 1.21, sy - 0.052, 7.03), (xw + 1.21, sy - 0.052, 7.03),
                    (xw + 1.21, sy - 0.052, 7.77), (xw - 1.21, sy - 0.052, 7.77)],
                   rect("Light", 2.42, 0.74), outward=(0, -1, 0))
    # side personnel door
    sx0 = 7.2
    for xf in (sx0 - 0.62, sx0 + 0.54):
        trim_p.box((xf, sy - 0.05, 0.0), (xf + 0.08, sy + 0.02, 2.18), ("tile", 1.0))
    trim_p.box((sx0 - 0.62, sy - 0.05, 2.10), (sx0 + 0.62, sy + 0.02, 2.18), ("tile", 1.0))
    doors.box((sx0 - 0.54, sy - 0.055, 0.04), (sx0 + 0.54, sy - 0.03, 2.06), rect("Door", 1.08, 2.02))
    glass.face([(sx0 - 0.24, sy - 0.058, 1.38), (sx0 + 0.24, sy - 0.058, 1.38),
                (sx0 + 0.24, sy - 0.058, 1.78), (sx0 - 0.24, sy - 0.058, 1.78)],
               rect("Glass", 0.48, 0.40), outward=(0, -1, 0))
    steel.box((sx0 - 0.48, sy - 0.06, 1.02), (sx0 - 0.40, sy - 0.03, 1.08), ("tile", 1.0))
    lit.box((sx0 - 0.16, sy - 0.20, 2.30), (sx0 + 0.16, sy - 0.10, 2.36), rect("Lit", 0.32, 0.06))
    steel.box((sx0 - 0.20, sy - 0.16, 2.28), (sx0 + 0.20, sy - 0.12, 2.40), ("tile", 1.0))
    atts["ATT_SideDoor"] = Vector((sx0, Y0 - 0.2, 0.05))
    atts["ATT_Lamp_Side"] = Vector((sx0, Y0 - 0.18, 2.33))
    # two more downpipes mid-wall, both elevations (LOD0 only)
    for sy2 in (-1, 1):
        py = sy2 * (Y1 + 0.26)
        for xd in (-10.0, 0.0):
            trim_p.tube((xd, py, 0.22), (xd, py, 8.50), 0.060, 8, ("tile", 1.0))
            trim_p.box((xd - 0.10, py - 0.10, 8.34), (xd + 0.10, py + 0.10, 8.52), ("tile", 1.0))
            trim_p.tube((xd, py, 8.52), (xd, py, 8.70), 0.072, 8, ("tile", 1.0))
            for zz in (1.5, 3.2, 4.9, 6.6, 8.1):
                trim_p.box((xd - 0.08, py - 0.08, zz), (xd + 0.08, py + 0.08, zz + 0.05), ("tile", 1.0))

    # hanging lamps inside the shed (so the open door reads; LOD0 only)
    geo.LEVEL = 1
    for i, xl in enumerate((-10.0, -3.0, 4.0)):
        steel.tube((xl, 0.0, 9.20), (xl, 0.0, 8.44), 0.018, 5, ("tile", 1.0))
        steel.box((xl - 0.42, -0.14, 8.36), (xl + 0.42, 0.14, 8.46), ("tile", 1.0))
        lit.box((xl - 0.38, -0.10, 8.34), (xl + 0.38, 0.10, 8.37), rect("Lit", 0.76, 0.2))
        atts["ATT_Light_Bay_%02d" % (i + 1)] = Vector((xl, 0.0, 8.3))

    # ------------------------------------------------ yard clutter: timber stack, drums, fenders, gate
    geo.LEVEL = 2
    for i in range(3):
        for k in range(3):
            timber.box((12.2, -6.7 + k * 0.26, 0.08 + i * 0.15), (15.6, -6.48 + k * 0.26, 0.20 + i * 0.15), TIMBER)
    geo.LEVEL = 1
    for dx, dy in ((12.3, 8.6), (13.1, 9.2), (13.8, 8.4)):
        steel.tube((dx, dy, 0.0), (dx, dy, 0.88), 0.28, 10, ("tile", 1.0))
        for zz in (0.12, 0.45, 0.76):
            steel.tube((dx, dy, zz), (dx, dy, zz + 0.04), 0.295, 10, ("tile", 1.0))
    geo.LEVEL = 2
    for xf in (8.6, 9.4):
        timber.tube((xf, Y0 - 0.13, 1.65), (xf, Y0 - 0.13, 0.65), 0.13, 8, flat("Dark"))
        timber.tube((xf, Y0 - 0.13, 1.65), (xf, Y0 + 0.06, 1.80), 0.018, 5, flat("Dark"))
    for i in range(4):
        timber.box((14.0 + i * 2.4, -20.2, 0.0), (14.5 + i * 2.4, -19.9, 0.16), TIMBER)
    # entrance gate (LOD0 only)
    geo.LEVEL = 1
    for gy in (-3.4, 3.4):
        steel.box((39.20, gy - 0.07, 0.0), (39.34, gy + 0.07, 2.45), ("tile", 1.0))
        steel.tube((39.27, gy, 2.45), (39.27, gy, 2.55), 0.09, 8, ("tile", 1.0))
    for zz in (0.45, 1.25, 2.05):
        steel.box((39.22, -3.4, zz), (39.32, 3.4, zz + 0.08), ("tile", 1.0))
    steel.tube((39.27, -3.4, 0.4), (39.27, 3.4, 2.1), 0.04, 6, ("tile", 1.0))
    atts["ATT_YardGate"] = Vector((39.3, 0.0, 0.05))

    # ================================================================ kit: steel keel cradle
    CX, CY = 16.6, 4.9
    geo.LEVEL = 2
    for dy in (-0.85, 0.85):
        steel.box((CX - 2.0, CY + dy - 0.08, 0.10), (CX + 2.0, CY + dy + 0.08, 0.26), ("tile", 1.0))
    for dx in (-1.85, -0.55, 0.75, 1.95):
        steel.box((CX + dx - 0.07, CY - 0.93, 0.14), (CX + dx + 0.07, CY + 0.93, 0.26), ("tile", 1.0))
    for dx in (-1.82, 1.82):
        for dy in (-0.82, 0.82):
            steel.box((CX + dx - 0.06, CY + dy - 0.06, 0.24), (CX + dx + 0.06, CY + dy + 0.06, 0.92), ("tile", 1.0))
            steel.tube((CX + dx, CY + dy, 0.35), (CX + dx, CY + dy, 1.10), 0.025, 8, ("tile", 1.0))
            steel.box((CX + dx - 0.10, CY + dy - 0.10, 1.02), (CX + dx + 0.10, CY + dy + 0.10, 1.07), ("tile", 1.0))
            steel.tube((CX + dx - 0.22, CY + dy, 1.05), (CX + dx + 0.22, CY + dy, 1.05), 0.018, 6, ("tile", 1.0))
            timber.box((CX + dx - 0.14, CY + dy - 0.14, 1.07), (CX + dx + 0.14, CY + dy + 0.14, 1.12), TIMBER)
    # diagonal bracing
    for dy in (-0.85, 0.85):
        steel.tube((CX - 1.80, CY + dy, 0.30), (CX - 0.60, CY + dy, 1.18), 0.028, 6, ("tile", 1.0))
        steel.tube((CX + 1.80, CY + dy, 0.30), (CX + 0.60, CY + dy, 1.18), 0.028, 6, ("tile", 1.0))
    # keel beam and V blocks
    steel.box((CX - 1.7, CY - 0.10, 0.86), (CX + 1.7, CY + 0.10, 1.00), ("tile", 1.0))
    for dx in (-0.9, 0.9):
        for dy in (-1, 1):
            timber.box((CX + dx - 0.20, CY + dy * 0.08 - 0.04, 1.00),
                       (CX + dx + 0.20, CY + dy * 0.22 + 0.04, 1.28), TIMBER)
    steel.tube((CX - 1.0, CY, 0.55), (CX - 1.0, CY + 0.85, 0.95), 0.03, 6, ("tile", 1.0))
    steel.tube((CX + 1.0, CY, 0.55), (CX + 1.0, CY - 0.85, 0.95), 0.03, 6, ("tile", 1.0))
    atts["ATT_Cradle_01"] = Vector((CX, CY, 0.28))
    atts["ATT_DryBerth_01"] = Vector((CX, CY, 0.02))

    # ================================================================ kit: adjustable prop stands (pair)
    for i, sx in enumerate((24.4, 27.0)):
        sx0, sy0 = sx, -5.4
        geo.LEVEL = 2
        for k in range(3):
            a = math.pi / 2 + k * 2 * math.pi / 3
            bx, by = sx0 + math.cos(a) * 0.52, sy0 + math.sin(a) * 0.52
            steel.tube((bx, by, 0.03), (sx0, sy0, 1.02), 0.032, 6, ("tile", 1.0))
            steel.box((bx - 0.10, by - 0.10, 0.03), (bx + 0.10, by + 0.10, 0.07), ("tile", 1.0))
        steel.tube((sx0, sy0, 0.95), (sx0, sy0, 1.18), 0.045, 8, ("tile", 1.0))
        steel.tube((sx0, sy0, 1.15), (sx0, sy0, 1.29), 0.07, 8, ("tile", 1.0))
        for k in range(4):
            a0 = k * math.pi / 2
            steel.tube((sx0 + math.cos(a0) * 0.16, sy0 + math.sin(a0) * 0.16, 1.04),
                       (sx0 + math.cos(a0) * 0.30, sy0 + math.sin(a0) * 0.30, 1.04), 0.018, 5, ("tile", 1.0))
        timber.box((sx0 - 0.24, sy0 - 0.20, 1.22), (sx0 + 0.24, sy0 + 0.20, 1.28), TIMBER)
        timber.face([(sx0 - 0.22, sy0 - 0.18, 1.28), (sx0 - 0.22, sy0 + 0.18, 1.28),
                     (sx0 + 0.02, sy0 + 0.06, 1.52), (sx0 + 0.02, sy0 - 0.06, 1.52)],
                    TIMBER, outward=(0, 0, 1))
        timber.face([(sx0 + 0.22, sy0 - 0.18, 1.28), (sx0 + 0.22, sy0 + 0.18, 1.28),
                     (sx0 + 0.02, sy0 + 0.06, 1.52), (sx0 + 0.02, sy0 - 0.06, 1.52)],
                    TIMBER, outward=(0, 0, 1))
        atts["ATT_PropStand_%02d" % (i + 1)] = Vector((sx0, sy0, 0.02))

    # ================================================================ kit: fuel dock pumps
    IX0, IX1, IY0, IY1 = 22.0, 26.0, 13.0, 15.0
    geo.LEVEL = 2
    ix0, ix1, iy0, iy1 = 22.2, 25.8, 13.15, 14.85
    for px, label in ((23.1, "Diesel"), (24.7, "Petrol")):
        # cabinet with a moulded top cap
        steel.box((px - 0.29, 14.18, 0.22), (px + 0.29, 14.76, 1.95), ("tile", 1.0))
        steel.box((px - 0.33, 14.14, 1.95), (px + 0.33, 14.80, 2.06), ("tile", 1.0))
        steel.box((px - 0.26, 14.73, 0.30), (px + 0.26, 14.77, 1.88), ("tile", 1.0))
        signs.face([(px - 0.25, 14.172, 0.52), (px + 0.25, 14.172, 0.52),
                    (px + 0.25, 14.172, 1.42), (px - 0.25, 14.172, 1.42)],
                   rect(label, 0.5, 0.9), outward=(0, -1, 0))
        glass.face([(px - 0.21, 14.171, 1.55), (px + 0.21, 14.171, 1.55),
                    (px + 0.21, 14.171, 1.81), (px - 0.21, 14.171, 1.81)],
                   rect("Glass", 0.42, 0.26), outward=(0, -1, 0))
        lit.box((px - 0.16, 14.174, 1.60), (px + 0.16, 14.178, 1.76), rect("Lit", 0.32, 0.16))
        # nozzle holster and hose on the side
        side = -1 if label == "Diesel" else 1
        hx = px + side * 0.32
        steel.box((hx - 0.07, 14.32, 1.10), (hx + 0.07, 14.46, 1.38), ("tile", 1.0))
        steel.tube((hx, 14.45, 1.26), (hx + side * 0.10, 14.58, 1.26), 0.035, 8, ("tile", 1.0))
        pts = [(px + side * 0.29, 14.50, 1.85), (px + side * 0.48, 14.54, 1.62),
               (px + side * 0.52, 14.46, 1.36), (px + side * 0.44, 14.38, 1.24)]
        for j in range(len(pts) - 1):
            steel.tube(pts[j], pts[j + 1], 0.030, 8, ("tile", 1.0))
        steel.tube((hx + side * 0.02, 14.44, 1.22), (hx + side * 0.02, 14.30, 1.12), 0.028, 8, ("tile", 1.0))
        steel.box((hx - 0.04, 14.27, 1.06), (hx + 0.04, 14.33, 1.14), ("tile", 1.0))
        # base plinth
        steel.box((px - 0.32, 14.15, 0.22), (px + 0.32, 14.79, 0.28), ("tile", 1.0))
    # island kerbs and bollards
    for x0, x1 in ((IX0, IX0 + 0.14), (IX1 - 0.14, IX1)):
        mark.box((x0, IY0, 0.20), (x1, IY1, 0.225), MARK)
    for y0, y1 in ((IY0, IY0 + 0.14), (IY1 - 0.14, IY1)):
        mark.box((IX0, y0, 0.20), (IX1, y1, 0.225), MARK)
    for bx, by in ((21.9, 13.0), (26.1, 13.0), (21.9, 15.0), (26.1, 15.0)):
        steel.tube((bx, by, 0.20), (bx, by, 0.94), 0.09, 8, ("tile", 1.0))
        steel.tube((bx, by, 0.94), (bx, by, 1.00), 0.12, 8, ("tile", 1.0))
    atts["ATT_FuelDiesel"] = Vector((22.78, 14.40, 1.14))
    atts["ATT_FuelPetrol"] = Vector((25.02, 14.40, 1.14))
    atts["ATT_FuelIsland"] = Vector((24.0, 14.0, 0.23))

    # ================================================================ kit: price board
    PX0, PX1 = 13.0, 15.4
    PY = -19.6
    geo.LEVEL = 2
    for x in (PX0 + 0.15, PX1 - 0.15):
        steel.box((x - 0.05, PY - 0.07, 0.0), (x + 0.05, PY + 0.05, 2.34), ("tile", 1.0))
        steel.box((x - 0.12, PY - 0.12, 0.0), (x + 0.12, PY + 0.10, 0.10), ("tile", 1.0))
    trim_p.box((PX0, PY - 0.10, 0.62), (PX1, PY - 0.04, 2.14), FASCIA)
    signs.face([(PX0 + 0.08, PY - 0.105, 0.70), (PX1 - 0.08, PY - 0.105, 0.70),
                (PX1 - 0.08, PY - 0.105, 2.06), (PX0 + 0.08, PY - 0.105, 2.06)],
               rect("Price", 2.24, 1.36), outward=(0, -1, 0))
    trim_p.box((PX0 - 0.04, PY - 0.14, 2.14), (PX1 + 0.04, PY - 0.01, 2.24), FASCIA)
    trim_p.box((PX0 - 0.06, PY - 0.16, 2.24), (PX1 + 0.06, PY + 0.00, 2.30), FLASH)
    trim_p.box((PX0 + 0.12, PY - 0.155, 0.58), (PX1 - 0.12, PY - 0.09, 0.64), FASCIA)
    atts["ATT_PriceBoard"] = Vector(((PX0 + PX1) / 2, PY - 0.2, 1.15))

    # ------------------------------------------------ LOD2 kit proxies (simple forms)
    geo.LEVEL = (2,)
    steel.box((CX - 2.0, CY - 1.0, 0.05), (CX + 2.0, CY - 0.55, 0.9), ("tile", 1.0))
    steel.box((CX - 2.0, CY + 0.55, 0.05), (CX + 2.0, CY + 1.0, 0.9), ("tile", 1.0))
    steel.box((CX - 0.8, CY - 0.2, 0.05), (CX + 0.8, CY + 0.2, 1.15), ("tile", 1.0))
    for sx in (24.4, 27.0):
        steel.box((sx - 0.26, -5.66, 0.0), (sx + 0.26, -5.14, 0.10), ("tile", 1.0))
        steel.box((sx - 0.06, -5.46, 0.10), (sx + 0.06, -5.34, 1.35), ("tile", 1.0))
        timber.box((sx - 0.24, -5.64, 1.30), (sx + 0.24, -5.16, 1.38), TIMBER)
    for px in (23.1, 24.7):
        steel.box((px - 0.30, 14.16, 0.22), (px + 0.30, 14.78, 2.05), ("tile", 1.0))
    steel.box((PX0 + 0.10, PY - 0.12, 0.0), (PX0 + 0.26, PY + 0.02, 2.34), ("tile", 1.0))
    steel.box((PX1 - 0.26, PY - 0.12, 0.0), (PX1 - 0.10, PY + 0.02, 2.34), ("tile", 1.0))
    signs.face([(PX0 + 0.08, PY - 0.115, 0.66), (PX1 - 0.08, PY - 0.115, 0.66),
                (PX1 - 0.08, PY - 0.115, 2.10), (PX0 + 0.08, PY - 0.115, 2.10)],
               rect("Price", 2.24, 1.4), outward=(0, -1, 0))
    for px, label in ((23.1, "Diesel"), (24.7, "Petrol")):
        signs.face([(px - 0.24, 14.174, 0.55), (px + 0.24, 14.174, 0.55),
                    (px + 0.24, 14.174, 1.40), (px - 0.24, 14.174, 1.40)],
                   rect(label, 0.48, 0.85), outward=(0, -1, 0))
    for sy in (-1, 1):
        trim_p.box((X0 - 0.2, sy * 7.95 - 0.1, 8.68), (X1 + 0.2, sy * 7.95 + 0.1, 8.92), FASCIA)
        for xd in (X0 + 0.5, X1 - 0.5):
            trim_p.box((xd - 0.08, sy * 7.76 - 0.08, 0.2), (xd + 0.08, sy * 7.76 + 0.08, 8.7), DOWNPIPE)
    for sy in (-1, 1):
        y = sy * 4.4
        light.face([(-15.0, y - 0.47, rz(y - 0.47, 0.205)), (9.0, y - 0.47, rz(y - 0.47, 0.205)),
                    (9.0, y + 0.47, rz(y + 0.47, 0.205)), (-15.0, y + 0.47, rz(y + 0.47, 0.205))],
                   LIGHT, outward=(0, 0, 1))
    steel.box((X1 - 0.35, RD_Y0 - 0.2, RD_H), (X1 - 0.1, RD_Y1 + 0.2, RD_H + 0.35), ("tile", 1.0))
    lit.box((lx - 0.10, ly - 0.36, 5.50), (lx + 0.10, ly + 0.08, 5.55), rect("Lit", 0.4, 0.16))
    mark.box((X1 - 0.315, RD_Y0 - 0.16, 0.25), (X1 - 0.305, RD_Y0 - 0.04, 1.9), MARK)
    mark.box((X1 - 0.315, RD_Y1 + 0.04, 0.25), (X1 - 0.305, RD_Y1 + 0.16, 1.9), MARK)

    # ================================================================ objects, sets, LODs
    parts = [clad, roof, light, inner, doors, signs, glass, steel, trim_p, ground, mark, timber, lit]
    mats = {
        "Clad": ("Clad", geo.material("MI_Boatyard_Clad", (0.34, 0.39, 0.35), 0.62, 0.25)),
        "Roof": ("Clad", geo.material("MI_Boatyard_Roof", (0.22, 0.26, 0.23), 0.55, 0.3)),
        "RoofLight": ("Details", geo.material("MI_Boatyard_Light", (0.72, 0.76, 0.74), 0.3)),
        "Inner": ("Details", geo.material("MI_Boatyard_Inner", (0.16, 0.19, 0.17), 0.8, 0.15)),
        "Doors": ("Details", geo.material("MI_Boatyard_Doors", (0.4, 0.43, 0.4), 0.5, 0.25)),
        "Signs": ("Details", geo.material("MI_Boatyard_Signs", (0.28, 0.3, 0.27), 0.55)),
        "Glass": ("Details", geo.material("MI_Boatyard_Glass", (0.05, 0.07, 0.07), 0.08)),
        "Steel": ("Metal", geo.material("MI_Boatyard_Steel", (0.34, 0.35, 0.34), 0.45, 0.7)),
        "Trim": ("Metal", geo.material("MI_Boatyard_Trim", (0.3, 0.3, 0.3), 0.6)),
        "Ground": ("Ground", geo.material("MI_Boatyard_Ground", (0.36, 0.35, 0.33), 0.9)),
        "Markings": ("Details", geo.material("MI_Boatyard_Markings", (0.55, 0.48, 0.18), 0.75)),
        "Timber": ("Details", geo.material("MI_Boatyard_Timber", (0.35, 0.28, 0.2), 0.8)),
        "Lit": ("Details", geo.material("MI_Boatyard_Lit", (0.9, 0.78, 0.55), 0.3)),
    }
    meshes = []
    off = Vector((0, 0, 0))
    for p in parts:
        s, mat = mats[p.name]
        obj = p.to_object("%s_%s_LOD0" % (NAME, p.name), mat, off)
        meshes.append({"object": obj, "set": s})
        for li, lod in ((1, "LOD1"), (2, "LOD2")):
            o = p.to_object("%s_%s_%s" % (NAME, p.name, lod), mat, off, lod=li)
            meshes.append({"object": o, "set": s})
        print("[H4] %s tris %d / %d / %d" % (p.name, p.tris(0), p.tris(1), p.tris(2)))
    print("[H4] totals %d / %d / %d" % tuple(sum(p.tris(i) for p in parts) for i in range(3)))

    # collision: shed shell, floor, kit islands and boards
    geo.LEVEL = 3
    col = Part("COL")
    col.box((X0 - 0.1, Y0 - 0.1, 0.0), (X1 + 0.1, Y1 + 0.1, EAVE), CLAD_X)
    col.prism([(Y0, EAVE), (Y1, EAVE), (0.0, UNDER_RIDGE)], "x", X0 - 0.1, X1 + 0.1, CLAD_X)
    col.box((-40.0, -25.0, -0.2), (40.0, 25.0, 0.0), CLAD_X)
    col.box((IX0, IY0, 0.2), (IX1, IY1, 0.3), CLAD_X)
    col.box((CX - 2.1, CY - 1.0, 0.0), (CX + 2.1, CY + 1.0, 1.3), CLAD_X)
    for sx in (24.4, 27.0):
        col.box((sx - 0.4, -5.8, 0.0), (sx + 0.4, -5.0, 1.5), CLAD_X)
    col.box((PX0, PY - 0.2, 0.0), (PX1, PY + 0.1, 2.3), CLAD_X)
    colobj = col.to_object(NAME + "_COL", None, off, weld=False)

    att_objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = ((p.x + off.x) * 3, (p.y + off.y) * 3, (p.z + off.z) * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)

    rows = [p for p in parts]
    lo = Vector((min(p.bbox()[0].x for p in rows), min(p.bbox()[0].y for p in rows), min(p.bbox()[0].z for p in rows)))
    hi = Vector((max(p.bbox()[1].x for p in rows), max(p.bbox()[1].y for p in rows), max(p.bbox()[1].z for p in rows)))
    sz = hi - lo
    print("[H4] bbox m %.2f x %.2f x %.2f" % (sz.x, sz.y, sz.z))
    st = lambda x, y, z: [x * 3, y * 3, z * 3]
    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 30000,
        "tier": "hero",
        "dims_m": (round(sz.x, 2), round(sz.y, 2), round(sz.z, 2)),
        "size_note": "80 x 50 m yard with the 30 x 15 m shed at its west side; height is the shed ridge (10.1 m) "
                     "plus the standing seam, and the yard lamp head",
        "origin": "base",
        "tiling": True,
        "waivers": {"LOD UV layout": "hand-made LOD1/LOD2 from geo levels; world-scale tiling UVs change the "
                                     "bounds and area as small parts drop, as on the Station, Hospital and Chandlery"},
        "sets": [
            {"name": "Yard", "set": "Details", "size": 2048, "wet": True, "dir": TEX},
            {"name": "Boatyard", "set": "Clad", "size": 1024, "wet": True, "dir": TEX},
            {"name": "Boatyard", "set": "Ground", "size": 1024, "wet": True, "dir": TEX},
            {"name": "Boatyard", "set": "Metal", "size": 1024, "wet": True, "dir": TEX},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "roller_door_interior", "target": st(6.4, -1.5, 1.9), "dist": 17, "az": 94, "el": 2},
            {"name": "gable_sign", "target": st(10.1, -1.4, 7.9), "dist": 26, "az": 72, "el": 4},
            {"name": "fuel_pumps", "target": st(23.9, 14.2, 1.1), "dist": 9, "az": 0, "el": 4},
            {"name": "keel_cradle", "target": st(16.6, 4.9, 0.7), "dist": 13, "az": 30, "el": 12},
            {"name": "prop_stands", "target": st(25.7, -5.4, 0.8), "dist": 11, "az": 25, "el": 8},
            {"name": "price_board", "target": st(14.2, -19.6, 1.35), "dist": 8, "az": 0, "el": 3},
        ],
    }
