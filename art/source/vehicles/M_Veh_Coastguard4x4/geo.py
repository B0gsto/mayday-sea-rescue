"""M_Veh_Coastguard4x4 geometry: invented Gale Isles coastguard cliff-rescue 4x4 (Defender 110 / Land Cruiser class).

Model frame (studs, before the final recentre): X across (driver side -X, kerb side +X), Y length (front bumper at
Y ~ -0.35, spare wheel at Y ~ 14.95), Z up (ground 0). 5.10 x 2.02 x 2.30 m at 3 studs/m. Four separate wheels at
LandVehicleConfig.CoastguardResponse hubs (wheelbase 2.794 m, track 1.486 m, wheel 0.78 m), five seats RHD.

Invented livery, no real brand: white body, navy lower panels, high-vis yellow / navy chequer bands, an invented
cliff-and-wave crest, "GALE ISLES COASTGUARD / RESCUE" lettering. Roof rack with a stowed pneumatic floodlight mast,
blue beacons and light bar, snorkel, winch bumper, spare on the rear door, side steps, cliff rope kit (rope bags,
folded A-frame, stretcher) on the rack. Mud and salt on the lower panels.
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix

import vehgeo as V

STUDS_M = 3.0

L = 15.30                 # overall length 5.10 m including the rear spare
HW = 2.685                # body half width (1.79 m); 2.02 m over the mirrors
BODY_F = 0.30             # body nose (front panel)
BODY_R = 14.10            # rear door skin
BUMP_F = -0.35            # front bumper face
BUMP_R = 14.42
ROOF = 5.86               # 1.95 m
SILL = 3.92
GLASS_TOP = 5.56
WS_BASE, WS_TOP = 3.38, 3.98

AX_F, AX_R = 2.35, 10.732  # 2.794 m wheelbase
HUB_X = 2.229             # 1.486 m track
WHEEL_R, WHEEL_W = 1.17, 0.705
WHEEL_Z = WHEEL_R
ARCH_R = 1.46
ROCKER = 1.40
SEAT_X = 1.30
FLOOR = 2.02
SKIN = 0.16

ROOF_F, ROOF_R = WS_TOP, BODY_R - 0.06
DOOR_F0, DOOR_F1 = 3.60, 6.52
DOOR_R0, DOOR_R1 = 6.66, 8.40
PILLAR_C = 8.50
QUARTER_F = 8.62

RACK_Z = 6.38
RACK_F, RACK_R = 4.10, 13.88


def M(g, name, lo=None):
    return name if g.hi else (lo or name)


def P(x, y, z):
    return Vector((x, y, z))


# --------------------------------------------------------------------------- section helpers
def hw_body(y):
    t = 0.0
    if y < BODY_F + 0.62:
        t = max(0.0, (BODY_F + 0.62 - y) / 0.62)
    elif y > BODY_R - 0.50:
        t = max(0.0, (y - (BODY_R - 0.50)) / 0.50)
    return HW - 0.10 * t ** 1.6


def bonnet_z(y):
    t = max(0.0, min(1.0, (y - BODY_F) / (WS_BASE - BODY_F)))
    return 3.04 + 0.26 * t + 0.10 * t ** 3


def arch_z(y, base=ROCKER, radius=ARCH_R, hy=AX_F):
    z = base
    d = abs(y - hy)
    if d < radius:
        z = max(z, WHEEL_Z + math.sqrt(radius * radius - d * d))
    elif d < radius + 0.24:
        t = (d - radius) / 0.24
        z = max(z, (WHEEL_Z + 0.05) * (1 - t) + base * t)
    return z


def side_top(y):
    if y < WS_BASE:
        return bonnet_z(y) - 0.10
    return SILL


def side_stations():
    ys = [BODY_F, 0.55, 0.82, 1.20, 1.70, 2.20, 2.85, 3.30, 3.50, 3.70]
    for hy in (AX_F, AX_R):
        for k in range(11):
            ys.append(hy - ARCH_R - 0.24 + (2 * ARCH_R + 0.48) * k / 10)
    ys += [4.30, 5.00, 5.60, 6.20, 6.52, 6.66, 7.20, 7.80, 8.40, 8.62, 9.40, 10.20, 11.10, 12.00,
           12.60, 13.20, 13.70, BODY_R]
    return sorted(set(round(y, 4) for y in ys if BODY_F <= y <= BODY_R))


def ring_profile(hw, zb, zt, r=0.24, n=5, arch=0.035):
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


def side_ring(side, y):
    zb = arch_z(y)
    zt = side_top(y)
    hw = hw_body(y)
    pts = [(hw, zb), (hw, zt - 0.09), (hw - 0.09, zt), (hw - SKIN, zt), (hw - SKIN, zb)]
    ring = [P(side * x, y, z) for x, z in pts]
    if side < 0:
        ring.reverse()
    return ring


def plate(g, outline, y0, y1, mat, bev=0.0):
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


def _sheet(g, rows, mat, flip=False):
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


# --------------------------------------------------------------------------- body shell
def body_sides(g):
    for side in (1, -1):
        rings = [side_ring(side, y) for y in side_stations()]
        g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)


def nose_shell(g):
    """Bonnet and fender top, lofted from the front panel to the windscreen base."""
    stations = [BODY_F, 0.44, 0.62, 0.90, 1.30, 1.85, 2.45, 3.00, WS_BASE]
    rings = []
    for y in stations:
        hwm = max(0.3, hw_body(y) - SKIN)
        zb = 1.62 if y < 1.0 else 1.55
        rings.append([P(x, y, z) for x, z in ring_profile(hwm, zb, bonnet_z(y), r=0.30, n=6, arch=0.10)])
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    if g.hi:
        V.box(g, (0, 1.85, bonnet_z(1.85) + 0.045), (2.50, 3.0, 0.06), "PaintWhite")
        for sx in (-1, 1):
            V.box(g, (sx * 1.74, 1.85, bonnet_z(1.85) + 0.02), (0.03, 2.9, 0.03), "PaintWhite")
        for k in range(4):
            V.box(g, (0, 0.85 + 0.22 * k, bonnet_z(0.85) - 0.01), (2.0, 0.05, 0.012), "PaintWhite")
    # bonnet louvre strips (invented)
    for sx in (-1, 1):
        for k in range(3):
            V.box(g, (sx * 0.86, 1.55 + 0.24 * k, bonnet_z(1.55 + 0.24 * k) + 0.075),
                  (0.72, 0.13, 0.03), M(g, "GrilleDark"), bev=0.01)


def front_panel(g):
    # body-colour face and its shut lines
    V.box(g, (0, BODY_F + 0.08, 2.32), (5.10, 0.16, 1.44), M(g, "PaintWhite"), bev=0.06)
    V.box(g, (0, BODY_F + 0.02, 1.70), (5.24, 0.14, 0.26), M(g, "BumperPlastic"), bev=0.05)
    # grille: dark recess with horizontal slats and an invented crest on the nose
    V.box(g, (0, BODY_F - 0.015, 2.56), (2.70, 0.09, 0.72), M(g, "GrilleDark"), bev=0.04)
    for k in range(3):
        V.box(g, (0, BODY_F - 0.06, 2.34 + 0.18 * k), (2.52, 0.05, 0.055), M(g, "PaintBlue"), bev=0.012)
    crest(g, (0, BODY_F - 0.075, 2.56), (0, -1, 0), 0.34)
    # headlamps: body-colour surrounds, chrome bezels, glass lenses
    for sx in (-1, 1):
        V.box(g, (sx * 1.90, BODY_F + 0.02, 2.54), (0.94, 0.10, 0.92), M(g, "PaintWhite"), bev=0.10)
        V.lathe(g, (sx * 1.90, BODY_F - 0.03, 2.54), (0, -1, 0),
                [(0.42, 0.0), (0.42, 0.03), (0.36, 0.055), (0.32, 0.05), (0.0, 0.055)],
                22 if g.hi else 16, M(g, "Chrome"))
        V.lathe(g, (sx * 1.90, BODY_F - 0.055, 2.54), (0, -1, 0),
                [(0.32, 0.0), (0.31, 0.015), (0.22, 0.03), (0.0, 0.035)], 20 if g.hi else 14, M(g, "LensWhite"))
        V.lathe(g, (sx * 1.38, BODY_F - 0.06, 2.17), (0, -1, 0),
                [(0.10, 0.0), (0.09, 0.015), (0.0, 0.02)], 12 if g.hi else 8, M(g, "LensAmber"))
        V.box(g, (sx * 0.74, BODY_F - 0.055, 2.62), (0.26, 0.04, 0.13), M(g, "LensBlue"), bev=0.02)
        V.box(g, (sx * 2.42, BODY_F - 0.01, 2.50), (0.16, 0.10, 0.30), M(g, "PaintBlue"), bev=0.03)
    # number plate and front tow eyes
    V.box(g, (0, BODY_F - 0.03, 1.88), (1.30, 0.05, 0.30), M(g, "PlateWhite"), bev=0.015)
    for sx in (-1, 1):
        V.tube(g, [(sx * 1.20, BUMP_F - 0.06, 1.26), (sx * 1.20, BUMP_F - 0.20, 1.26)], 0.075,
               M(g, "BlackMetal"), 8 if g.hi else 6)


def bumper_front(g):
    V.box(g, (0, BUMP_F + 0.34, 1.44), (5.36, 0.66, 0.56), M(g, "BumperPlastic"), bev=0.12)
    V.box(g, (0, BUMP_F + 0.30, 1.82), (5.18, 0.54, 0.24), M(g, "BlackMetal"), bev=0.06)
    for sx in (-1, 1):
        V.box(g, (sx * 2.54, BUMP_F + 0.34, 1.44), (0.22, 0.62, 0.62), M(g, "BlackMetal"), bev=0.05)
    # winch: drum, cable, fairlead and side plates on the bumper deck
    V.box(g, (0, -0.04, 1.94), (2.10, 0.44, 0.10), M(g, "BlackMetal"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (sx * 0.86, -0.04, 1.86), (0.10, 0.46, 0.40), M(g, "BlackMetal"), bev=0.03)
    V.lathe(g, (0, -0.04, 1.96), (1, 0, 0),
            [(0.0, -0.62), (0.24, -0.60), (0.30, -0.46), (0.30, 0.46), (0.24, 0.60), (0.0, 0.62)],
            18 if g.hi else 14, M(g, "RimDark"))
    for k in range(5):
        V.lathe(g, (0, -0.16 - 0.055 * k, 1.96), (0, -1, 0),
                [(0.15, 0.0), (0.15, 0.014)], 12 if g.hi else 8, M(g, "BlackPlastic"))
    V.box(g, (0, BUMP_F + 0.10, 1.90), (0.42, 0.10, 0.26), M(g, "Chrome"), bev=0.02)
    V.lathe(g, (0, BUMP_F + 0.03, 1.70), (0, -1, 0), [(0.16, 0.0), (0.18, 0.03), (0.10, 0.16), (0.09, 0.22)],
            14 if g.hi else 10, M(g, "BlackMetal"))
    V.tube(g, [(0, BUMP_F + 0.02, 1.70), (0, BUMP_F + 0.02, 1.20)], 0.07, M(g, "BlackMetal"), 8 if g.hi else 6)
    for sx in (-1, 1):
        V.box(g, (sx * 0.62, BUMP_F + 0.02, 1.35), (0.36, 0.10, 0.36), M(g, "PlateWhite"), bev=0.02)
    # driving lamps on the bumper
    for sx in (-1, 1):
        V.lathe(g, (sx * 2.05, BUMP_F + 0.01, 1.86), (0, -1, 0),
                [(0.0, 0.0), (0.20, 0.0), (0.20, 0.04), (0.16, 0.10), (0.0, 0.12)],
                16 if g.hi else 12, M(g, "Chrome"))
        V.lathe(g, (sx * 2.05, BUMP_F - 0.02, 1.86), (0, -1, 0),
                [(0.17, 0.0), (0.17, 0.012), (0.0, 0.02)], 14 if g.hi else 10, M(g, "LensWhite"))


def roof(g):
    ys = [ROOF_F, ROOF_F + 0.20, 4.60, 6.40, 8.60, 10.80, 12.60, ROOF_R - 0.20, ROOF_R]
    rings = []
    for y in ys:
        t = (y - ROOF_F) / (ROOF_R - ROOF_F)
        zt = ROOF - 0.05 + 0.05 * min(1.0, t * 3)
        hw = HW - 0.10
        rings.append([P(-hw, y, zt - 0.18), P(-hw, y, zt - 0.10), P(-hw + 0.07, y, zt - 0.02),
                      P(-hw * 0.55, y, zt + 0.02), P(0.0, y, zt + 0.035), P(hw * 0.55, y, zt + 0.02),
                      P(hw - 0.07, y, zt - 0.02), P(hw, y, zt - 0.10), P(hw, y, zt - 0.18), P(0.0, y, zt - 0.22)])
    g.rings(rings, M(g, "PaintWhite"), closed=True, cap0=True, cap1=True)
    # gutters and roof ribs
    for sx in (-1, 1):
        V.box(g, (sx * (HW - 0.11), (ROOF_F + ROOF_R) / 2, ROOF - 0.13), (0.10, ROOF_R - ROOF_F, 0.10),
              M(g, "PaintWhite"), bev=0.03)
    if g.hi:
        for k in range(5):
            V.box(g, (-1.6 + 0.8 * k, (ROOF_F + ROOF_R) / 2, ROOF + 0.015), (0.05, ROOF_R - ROOF_F - 0.2, 0.012),
                  "PaintWhite")


def greenhouse(g):
    """Upright Defender-style cabin: A/B/C/D pillars, gutters, window frames and door shut lines."""
    for side in (1, -1):
        x0, x1 = side * (HW - 0.30), side * (HW - 0.02)
        if side < 0:
            x0, x1 = side * (HW - 0.02), side * (HW - 0.30)
        # A-pillar, raked with the windscreen
        a0, a1 = min(x0, x1), max(x0, x1)
        V.extrude_profile(g, [(WS_BASE - 0.04, SILL - 0.06), (WS_BASE + 0.30, SILL - 0.06),
                              (WS_TOP + 0.16, ROOF - 0.02), (WS_TOP - 0.14, ROOF - 0.02)], a0, a1,
                          M(g, "PaintWhite"), bev=0.04)
        # B / C / D pillars and the rear corner
        for yc, w in ((DOOR_F1 + 0.07, 0.20), (PILLAR_C, 0.20), (ROOF_R - 0.22, 0.30)):
            V.box(g, (side * (HW - 0.16), yc, (SILL + ROOF) / 2), (0.28, w, ROOF - SILL - 0.02),
                  M(g, "PaintWhite"), bev=0.03)
        # window sill rail and roof rail across the side
        V.box(g, (side * (HW - 0.12), (DOOR_F0 + ROOF_R) / 2, SILL + 0.09), (0.20, ROOF_R - DOOR_F0, 0.18),
              M(g, "PaintWhite"), bev=0.03)
        V.box(g, (side * (HW - 0.10), (ROOF_F + ROOF_R) / 2, ROOF - 0.20), (0.16, ROOF_R - ROOF_F, 0.28),
              M(g, "PaintWhite"), bev=0.04)
        # door shut lines
        for yc in (DOOR_F0, DOOR_F1, DOOR_R0, DOOR_R1):
            V.box(g, (side * (HW + 0.005), yc, 2.55), (0.02, 0.05, 2.55), M(g, "GlassSeal"))
        for yc in (DOOR_F0 + 0.02, DOOR_R1 - 0.02):
            V.box(g, (side * (HW + 0.02), yc, 2.56), (0.03, 0.03, 2.5), M(g, "GlassSeal"))
        # hinges
        for yc in (DOOR_F0 + 0.06, DOOR_R0 + 0.05):
            V.box(g, (side * (HW + 0.035), yc, 1.95), (0.06, 0.16, 0.26), M(g, "BlackPlastic"), bev=0.02)
        # fuel filler
        V.lathe(g, (side * (HW + 0.015), 11.55, 2.05), (side, 0, 0),
                [(0.0, 0.0), (0.27, 0.0), (0.27, 0.03), (0.22, 0.06), (0.0, 0.07)], 18 if g.hi else 12,
                M(g, "PaintBlue"))
    # windscreen surround
    V.box(g, (0, WS_BASE + 0.05, SILL + 0.05), (5.22, 0.16, 0.16), M(g, "GlassSeal"), bev=0.02)
    V.box(g, (0, WS_TOP + 0.02, ROOF - 0.24), (5.22, 0.18, 0.14), M(g, "GlassSeal"), bev=0.02)


def windscreen(g):
    cols = 7
    rows = []
    for r in range(4):
        t = r / 3.0
        y = WS_BASE + 0.03 + (WS_TOP - WS_BASE - 0.04) * t
        z = SILL + 0.04 + (ROOF - 0.30 - SILL - 0.04) * t
        row = []
        for c in range(cols + 1):
            u = -1 + 2 * c / cols
            row.append(P(u * (HW - 0.34), y + 0.05 * (1 - u * u), z))
        rows.append(row)
    _sheet(g, rows, M(g, "Glass"))
    back = [[P(p.x, p.y + 0.05, p.z - 0.02) for p in row] for row in rows]
    _sheet(g, back, M(g, "Glass"), flip=True)
    V.box(g, (0, WS_BASE + 0.02, ROOF - 0.22), (5.24, 0.16, 0.14), M(g, "GlassSeal"), bev=0.02)
    # wipers
    for sx in (-1, 1):
        V.box(g, (sx * 1.05, WS_BASE + 0.10, SILL + 0.10), (1.20, 0.09, 0.05), M(g, "BlackPlastic"),
              rot=Matrix.Rotation(math.radians(-12), 3, "X"), bev=0.01)
        V.box(g, (sx * 0.40, WS_BASE + 0.16, SILL + 0.08), (0.10, 0.10, 0.07), M(g, "BlackPlastic"), bev=0.01)


def side_windows(g):
    panes = ((DOOR_F0 + 0.20, DOOR_F1 - 0.12), (DOOR_R0 + 0.12, DOOR_R1 - 0.12),
             (QUARTER_F + 0.12, PILLAR_C - 0.14), (PILLAR_C + 0.14, ROOF_R - 0.42))
    for side in (1, -1):
        x = side * (HW - 0.075)
        for lo, hi in panes:
            rows = [[P(x, lo, SILL + 0.18), P(x, hi, SILL + 0.18)],
                    [P(x, lo, GLASS_TOP - 0.06), P(x, hi, GLASS_TOP - 0.06)]]
            _sheet(g, rows, M(g, "Glass"), flip=(side < 0))
            V.box(g, (side * (HW - 0.02), (lo + hi) / 2, SILL + 0.12), (0.10, hi - lo + 0.12, 0.10),
                  M(g, "GlassSeal"))
            V.box(g, (side * (HW - 0.02), (lo + hi) / 2, GLASS_TOP - 0.01), (0.10, hi - lo + 0.10, 0.12),
                  M(g, "GlassSeal"))
            for yy in (lo - 0.04, hi - 0.04):
                V.box(g, (side * (HW - 0.02), yy, (SILL + GLASS_TOP) / 2), (0.10, 0.10, GLASS_TOP - SILL),
                      M(g, "GlassSeal"))


def door_handles(g):
    for side in (1, -1):
        for yc in (DOOR_F1 - 0.30, DOOR_R1 - 0.30):
            V.box(g, (side * (HW + 0.055), yc, 3.20), (0.09, 0.48, 0.13), M(g, "BlackPlastic"), bev=0.035)
            V.box(g, (side * (HW + 0.095), yc - 0.02, 3.20), (0.03, 0.30, 0.06), M(g, "Chrome"), bev=0.01)
        # mirror: arm, housing, glass
        V.tube(g, [(side * (HW - 0.04), 3.72, 4.22), (side * (HW + 0.20), 3.66, 4.36),
                   (side * (HW + 0.32), 3.56, 4.48)], 0.065, M(g, "BlackPlastic"), 10 if g.hi else 8, fillet=0.10)
        V.box(g, (side * 3.00, 3.48, 4.64), (0.13, 0.40, 0.78), M(g, "BlackPlastic"), bev=0.06)
        V.box(g, (side * 3.07, 3.48, 4.64), (0.03, 0.34, 0.70), M(g, "Chrome"), bev=0.02)
        V.box(g, (side * 2.96, 3.70, 4.64), (0.10, 0.10, 0.74), M(g, "BlackPlastic"), bev=0.03)
        V.box(g, (side * 2.94, 3.52, 4.64), (0.08, 0.12, 0.16), M(g, "PaintBlue"), bev=0.02)
        # side step
        V.box(g, (side * (HW + 0.06), 6.55, 1.02), (0.44, 4.90, 0.16), M(g, "BlackMetal"), bev=0.05)
        V.box(g, (side * (HW + 0.06), 6.55, 1.12), (0.38, 4.70, 0.05), M(g, "Rubber"), bev=0.02)
        for yc in (4.55, 8.55):
            V.box(g, (side * (HW - 0.02), yc, 1.18), (0.30, 0.22, 0.30), M(g, "BlackMetal"), bev=0.03)


def door_mirror_markers(g):
    pass


def arch_flares(g):
    for side in (1, -1):
        for hy in (AX_F, AX_R):
            pts = []
            for k in range(10):
                a = math.radians(-104 + 208 * k / 9)
                pts.append(P(side * (HW - 0.01), hy + (ARCH_R + 0.02) * math.sin(a),
                             WHEEL_Z + (ARCH_R + 0.02) * math.cos(a)))
            prof = [(-0.03, -0.14), (0.15, -0.14), (0.15, 0.14), (-0.03, 0.14)]
            V.sweep(g, pts, prof, M(g, "ArchPlastic"), closed=True, cap0=True, cap1=True)
        for hy in (AX_F + 1.30, AX_R + 1.33):
            V.box(g, (side * 2.28, hy, 0.82), (0.98, 0.05, 0.55), M(g, "Rubber"), bev=0.03)


def rear_panel(g):
    V.box(g, (0, BODY_R + 0.02, 3.10), (5.10, 0.14, 3.60), M(g, "PaintWhite"), bev=0.06)
    # rear door, window, hinges and handle
    V.box(g, (0, BODY_R + 0.11, 3.22), (4.14, 0.10, 4.30), M(g, "PaintWhite"), bev=0.07)
    V.box(g, (0, BODY_R + 0.17, 4.68), (3.00, 0.06, 1.02), M(g, "GlassSeal"), bev=0.02)
    rows = [[P(-1.44, BODY_R + 0.205, 4.24), P(1.44, BODY_R + 0.205, 4.24)],
            [P(-1.44, BODY_R + 0.205, 5.12), P(1.44, BODY_R + 0.205, 5.12)]]
    _sheet(g, rows, M(g, "Glass"))
    for sx in (-1, 1):
        V.box(g, (sx * 1.98, BODY_R + 0.15, 4.45), (0.14, 0.10, 4.90), M(g, "GlassSeal"))
    V.box(g, (0.55, BODY_R + 0.18, 3.92), (0.46, 0.08, 0.15), M(g, "BlackPlastic"), bev=0.03)
    V.box(g, (0, BODY_R + 0.175, 3.15), (0.05, 0.05, 3.4), M(g, "GlassSeal"))
    # rear bumper, step and tow hitch
    V.box(g, (0, BODY_R + 0.28, 1.30), (5.30, 0.34, 0.38), M(g, "BumperPlastic"), bev=0.08)
    V.box(g, (0, BODY_R + 0.48, 1.02), (2.40, 0.44, 0.12), M(g, "BlackMetal"), bev=0.03)
    V.box(g, (0, BODY_R + 0.45, 1.12), (0.72, 0.26, 0.20), M(g, "BlackMetal"), bev=0.03)
    V.lathe(g, (0, BODY_R + 0.62, 1.12), (0, 1, 0), [(0.10, 0.0), (0.14, 0.03), (0.14, 0.14), (0.10, 0.17)],
            12 if g.hi else 8, M(g, "Chrome"))
    # tail lamp clusters
    for sx in (-1, 1):
        V.box(g, (sx * 2.38, BODY_R + 0.17, 3.05), (0.34, 0.10, 1.10), M(g, "GlassSeal"), bev=0.04)
        V.box(g, (sx * 2.38, BODY_R + 0.225, 3.34), (0.26, 0.05, 0.30), M(g, "LensRed"), bev=0.02)
        V.box(g, (sx * 2.38, BODY_R + 0.225, 2.97), (0.26, 0.05, 0.26), M(g, "LensAmber"), bev=0.02)
        V.box(g, (sx * 2.38, BODY_R + 0.225, 2.64), (0.26, 0.05, 0.28), M(g, "LensReverse"), bev=0.02)
    V.box(g, (0, BODY_R + 0.185, 2.02), (1.30, 0.03, 0.30), M(g, "PlateWhite"), bev=0.015)
    # high-level rear brake lamp
    V.box(g, (0, BODY_R + 0.02, ROOF - 0.18), (1.90, 0.08, 0.10), M(g, "LensRed"), bev=0.02)


def rear_chequer(g):
    for row in range(2):
        for i in range(12):
            mat = "PaintHiVis" if (i + row) % 2 == 0 else "PaintBlue"
            V.box(g, (2.36 - 4.72 / 12 * (i + 0.5), BODY_R + 0.16, 1.82 + 0.34 * row),
                  (4.72 / 12 - 0.035, 0.05, 0.30), M(g, mat))


# --------------------------------------------------------------------------- livery
def chequer(g, x, y0, y1, z0, z1, cell):
    n = max(2, int(round((y1 - y0) / cell)))
    w = (y1 - y0) / n
    for i in range(n):
        for row in (0, 1):
            mat = "PaintHiVis" if (i + row) % 2 == 0 else "PaintBlue"
            V.box(g, (x, y0 + w * (i + 0.5), z0 + (z1 - z0) * (row + 0.5) / 2),
                  (0.035, w - 0.045, (z1 - z0) / 2 - 0.045), M(g, mat), bev=0.0)


def band(g, side, y0, y1, z0, z1, mat):
    V.box(g, (side * (HW + 0.012), (y0 + y1) / 2, (z0 + z1) / 2), (0.05, y1 - y0, z1 - z0), M(g, mat), bev=0.0)


def crest(g, origin, normal, r):
    """Invented crest: white disc, navy ring, a cliff block and three high-vis waves; no real badge."""
    o = Vector(origin)
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1))
    e1 = n.cross(up).normalized()
    e2 = up
    V.lathe(g, o, n, [(0.0, 0.0), (r, 0.0), (r, 0.045), (r * 0.90, 0.055), (0.0, 0.05)],
            24 if g.hi else 18, M(g, "CrestWhite"))
    V.lathe(g, o + n * 0.052, n,
            [(r * 0.88, 0.0), (r, 0.0), (r, 0.032), (r * 0.88, 0.04)], 24 if g.hi else 18, M(g, "CrestBlue"))
    # cliff: a stepped navy block, low-left
    cx = -0.30 * r
    for k, (w, h) in enumerate(((0.55, 0.35), (0.40, 0.60), (0.24, 0.84))):
        p = [o + n * 0.085 + e1 * (cx + w * r * u) + e2 * ((-0.30 + h * q) * r)
             for u, q in ((-0.5, 0.0), (0.5, 0.0), (0.5, 1.0), (-0.5, 1.0))]
        vs = [g.bm.verts.new(q) for q in p]
        g.face(vs, M(g, "CrestBlue"))
    # three high-vis waves across the lower half
    for k in range(2):
        pts = []
        for j in range(8):
            u = -0.78 + 1.56 * j / 7
            pts.append(o + n * 0.095 + e1 * (u * r) + e2 * ((-0.38 - 0.18 * k) * r + 0.10 * r * math.sin(u * 6.0)))
        V.sweep(g, pts, V.circle_profile(0.05 * r, 5 if g.hi else 4), M(g, "CrestYellow"), closed=False)


def livery_side(g):
    for side in (1, -1):
        x = side * (HW + 0.014)
        band(g, side, 3.98, 9.10, 1.34, 2.14, "PaintBlue")
        band(g, side, 12.40, 14.02, 1.34, 2.14, "PaintBlue")
        chequer(g, x, 3.99, 9.10, 2.18, 3.16, 0.62 if not g.hi else 0.40)
        chequer(g, x, 12.40, 14.02, 2.18, 3.16, 0.62 if not g.hi else 0.40)
        # lettering reads left to right from each side
        text_panel(g, "COASTGUARD", 0.38, M(g, "LetterBlue"),
                   lambda co, s=side, xx=x: P(xx, 6.45 + co.x * s, 3.49 + co.y),
                   lambda c, s=side: P(s, 0, 0), font_scale_x=1.02, resolution=1)
        text_panel(g, "GALE ISLES", 0.16, M(g, "LetterBlue"),
                   lambda co, s=side, xx=x: P(xx, 6.45 + co.x * s, 3.82 + co.y),
                   lambda c, s=side: P(s, 0, 0), resolution=1)
        text_panel(g, "RESCUE", 0.26, M(g, "CrestYellow"),
                   lambda co, s=side, xx=x: P(xx, 13.22 + co.x * s, 1.76 + co.y),
                   lambda c, s=side: P(s, 0, 0), resolution=1)
        crest(g, (x + side * 0.02, 13.18, 3.00), (side, 0, 0), 0.40)


def livery_rear(g):
    rear_chequer(g)
    text_panel(g, "COASTGUARD", 0.34, M(g, "LetterBlue"),
               lambda co: P(-co.x, BODY_R + 0.205, 5.44 + co.y), lambda c: P(0, 1, 0), resolution=1)
    crest(g, (1.80, BODY_R + 0.205, 5.44), (0, 1, 0), 0.26)


def livery_front(g):
    text_panel(g, "RESCUE", 0.24, M(g, "LetterBlue"),
               lambda co: P(-co.x, BODY_F - 0.085, 1.99 + co.y), lambda c: P(0, -1, 0), resolution=1)


# --------------------------------------------------------------------------- roof rack and cliff kit
def roof_rack(g):
    for sx in (-1, 1):
        V.tube(g, [(sx * 2.48, RACK_F, RACK_Z), (sx * 2.48, RACK_R, RACK_Z)], 0.075, M(g, "BlackMetal"),
               10 if g.hi else 8, fillet=0.05)
        for y in (RACK_F + 0.12, RACK_R - 0.12):
            V.tube(g, [(sx * 2.48, y, RACK_Z), (sx * 2.48, y, ROOF - 0.02)], 0.075, M(g, "BlackMetal"),
                   10 if g.hi else 8)
            V.box(g, (sx * 2.48, y, ROOF - 0.04), (0.34, 0.34, 0.12), M(g, "BlackPlastic"), bev=0.02)
    for y in (RACK_F, 7.10, 9.90, RACK_R):
        V.tube(g, [(-2.48, y, RACK_Z), (2.48, y, RACK_Z)], 0.07, M(g, "BlackMetal"), 10 if g.hi else 8)
    # deck slats
    n = 12
    for k in range(n):
        y = RACK_F + 0.24 + (RACK_R - RACK_F - 0.48) * k / (n - 1)
        V.box(g, (0, y, RACK_Z + 0.03), (4.86, 0.11, 0.055), M(g, "BlackMetal"), bev=0.012)
    # low basket rail
    for sx in (-1, 1):
        V.tube(g, [(sx * 2.52, RACK_F + 0.10, RACK_Z + 0.24), (sx * 2.52, RACK_R - 0.10, RACK_Z + 0.24)],
               0.045, M(g, "BlackMetal"), 8 if g.hi else 6)
        for y in (RACK_F + 0.10, 7.10, 9.90, RACK_R - 0.10):
            V.tube(g, [(sx * 2.52, y, RACK_Z), (sx * 2.52, y, RACK_Z + 0.24)], 0.04, M(g, "BlackMetal"),
                   8 if g.hi else 6)
    for y in (RACK_F + 0.10, RACK_R - 0.10):
        V.tube(g, [(-2.52, y, RACK_Z + 0.24), (2.52, y, RACK_Z + 0.24)], 0.045, M(g, "BlackMetal"),
               8 if g.hi else 6)
    # rear ladder up the back
    for sx in (-1, 1):
        V.tube(g, [(sx * 1.55, BODY_R + 0.14, 2.10), (sx * 1.55, BODY_R + 0.14, RACK_Z - 0.05)],
               0.035, M(g, "BlackMetal"), 8 if g.hi else 6)
    for k in range(7):
        V.tube(g, [(-1.55, BODY_R + 0.14, 2.34 + 0.56 * k), (1.55, BODY_R + 0.14, 2.34 + 0.56 * k)],
               0.03, M(g, "BlackMetal"), 6)


def light_bar(g):
    V.box(g, (0, RACK_F + 0.16, RACK_Z + 0.14), (4.60, 0.26, 0.08), M(g, "BeaconMount"), bev=0.02)
    V.box(g, (0, RACK_F + 0.16, RACK_Z + 0.24), (4.44, 0.20, 0.14), M(g, "BeaconMount"), bev=0.03)
    V.box(g, (0, RACK_F + 0.16, RACK_Z + 0.32), (4.36, 0.17, 0.07), M(g, "BlackPlastic"), bev=0.02)
    for x in (-1.44, -0.48, 0.48, 1.44):
        V.lathe(g, (x, RACK_F + 0.16, RACK_Z + 0.35), (0, 0, 1),
                [(0.24, 0.0), (0.24, 0.04), (0.22, 0.10), (0.18, 0.20), (0.11, 0.28), (0.0, 0.32)],
                14 if g.hi else 10, M(g, "LensBlue"),
                matfn=(lambda i, j: "BeaconMount" if i <= 1 else "LensBlue") if g.hi else None)
    for sx in (-1, 1):
        V.box(g, (sx * 2.26, RACK_F + 0.16, RACK_Z + 0.14), (0.14, 0.24, 0.14), M(g, "BeaconMount"), bev=0.02)
    # rear corner beacons
    for sx in (-1, 1):
        beacon(g, (sx * 2.30, RACK_R - 0.32, RACK_Z + 0.02), 0.26, M(g, "LensBlue"))
    # work lamps at the rear of the rack
    for sx in (-1, 1):
        V.box(g, (sx * 1.72, RACK_R - 0.14, RACK_Z + 0.12), (0.44, 0.12, 0.24), M(g, "BeaconMount"), bev=0.03)
        V.box(g, (sx * 1.72, RACK_R - 0.075, RACK_Z + 0.12), (0.36, 0.03, 0.18), M(g, "LensWhite"), bev=0.015)


def beacon(g, pos, r, mat):
    x, y, z = pos
    V.box(g, (x, y, z + 0.02), (r * 2.0, r * 1.4, 0.10), M(g, "BeaconMount"), bev=0.03)
    V.lathe(g, (x, y, z + 0.05), (0, 0, 1),
            [(r, 0.0), (r, 0.05), (r * 0.92, 0.14), (r * 0.80, 0.24), (r * 0.62, 0.32), (r * 0.34, 0.37), (0.0, 0.39)],
            18 if g.hi else 12, mat)
    if g.hi:
        V.lathe(g, (x, y, z + 0.05), (0, 0, 1), [(r * 0.9, 0.0), (r * 0.9, 0.02)], 12, "BeaconMount")


def mast(g):
    """Pneumatic telescopic floodlight mast, stowed horizontally down the rear half of the rack."""
    x, z = -1.52, RACK_Z + 0.24
    V.box(g, (x, RACK_R - 0.50, z + 0.06), (0.62, 0.66, 0.34), M(g, "MastBlue"), bev=0.05)
    V.box(g, (x, RACK_R - 0.50, z + 0.25), (0.44, 0.44, 0.08), M(g, "BlackMetal"), bev=0.02)
    V.tube(g, [(x, RACK_R - 0.30, z + 0.15), (x, RACK_R - 0.70, z + 0.42)], 0.055, M(g, "BlackMetal"),
           8 if g.hi else 6)
    # three telescoping sections lying forward
    V.lathe(g, (x, RACK_R - 0.72, z + 0.22), (0, -1, 0),
            [(0.155, 0.0), (0.155, 1.55), (0.135, 1.62)], 16 if g.hi else 12, M(g, "MastAlloy"))
    V.lathe(g, (x, RACK_R - 2.34, z + 0.22), (0, -1, 0),
            [(0.120, 0.0), (0.120, 1.35), (0.100, 1.42)], 16 if g.hi else 12, M(g, "MastAlloy"))
    V.lathe(g, (x, RACK_R - 3.68, z + 0.22), (0, -1, 0),
            [(0.088, 0.0), (0.088, 1.05), (0.070, 1.12)], 14 if g.hi else 10, M(g, "MastAlloy"))
    for y in (RACK_R - 0.78, RACK_R - 2.40, RACK_R - 3.74):
        V.lathe(g, (x, y, z + 0.22), (0, -1, 0), [(0.17, 0.0), (0.17, 0.12)], 16 if g.hi else 12,
                M(g, "MastBlue"))
    # stowed floodlight head: crossbar and two lamp housings facing forward
    yh = RACK_R - 4.86
    V.box(g, (x, yh, z + 0.22), (1.66, 0.16, 0.14), M(g, "MastBlue"), bev=0.03)
    for sx in (-1, 1):
        V.box(g, (x + sx * 0.70, yh, z + 0.22), (0.46, 0.14, 0.34), M(g, "BeaconMount"), bev=0.03)
        V.box(g, (x + sx * 0.70, yh - 0.09, z + 0.22), (0.38, 0.03, 0.26), M(g, "LensWhite"), bev=0.015)
    # tie-down straps and cable coil
    for y in (RACK_R - 1.30, RACK_R - 3.10):
        V.box(g, (x, y, z + 0.22), (0.40, 0.08, 0.40), M(g, "Webbing"), bev=0.01)
    V.lathe(g, (x + 0.42, RACK_R - 4.20, z + 0.12), (1, 0, 0),
            [(0.0, 0.0), (0.24, 0.0), (0.24, 0.07), (0.0, 0.08)], 14 if g.hi else 10, M(g, "BlackPlastic"))


def rope_kit(g):
    # two rope bags, a rope coil, a folded four-fold stretcher and the folded A-frame tripod on the rack
    V.box(g, (0.82, 9.60, RACK_Z + 0.28), (0.74, 1.00, 0.48), M(g, "RopeBagOrange"), bev=0.16)
    V.box(g, (0.82, 9.60, RACK_Z + 0.53), (0.60, 0.86, 0.05), M(g, "Webbing"), bev=0.01)
    V.box(g, (1.78, 9.60, RACK_Z + 0.26), (0.62, 0.88, 0.44), M(g, "RopeBagBlue"), bev=0.14)
    V.box(g, (1.78, 9.60, RACK_Z + 0.49), (0.48, 0.74, 0.05), M(g, "Webbing"), bev=0.01)
    V.lathe(g, (2.10, 10.62, RACK_Z + 0.14), (0, 0, 1),
            [(0.30, 0.0), (0.42, 0.03), (0.42, 0.16), (0.30, 0.19), (0.0, 0.19)], 18 if g.hi else 12,
            M(g, "RopeCoil"))
    V.lathe(g, (2.10, 10.62, RACK_Z + 0.20), (0, 0, 1), [(0.0, 0.0), (0.19, 0.0), (0.19, 0.03), (0.0, 0.03)],
            14 if g.hi else 10, M(g, "RopeBagBlue"))
    # folded stretcher: orange canvas between two poles
    V.box(g, (1.42, 11.62, RACK_Z + 0.16), (1.16, 1.42, 0.10), M(g, "StretcherOrange"), bev=0.04)
    for sx in (-1, 1):
        V.tube(g, [(1.42 + sx * 0.58, 10.92, RACK_Z + 0.22), (1.42 + sx * 0.58, 12.32, RACK_Z + 0.22)],
               0.045, M(g, "TripodSteel"), 8 if g.hi else 6)
    V.tube(g, [(0.82, 11.02, RACK_Z + 0.24), (2.02, 11.02, RACK_Z + 0.24)], 0.045, M(g, "TripodSteel"),
           8 if g.hi else 6)
    V.tube(g, [(0.82, 12.22, RACK_Z + 0.24), (2.02, 12.22, RACK_Z + 0.24)], 0.045, M(g, "TripodSteel"),
           8 if g.hi else 6)
    for y in (11.20, 12.05):
        V.box(g, (1.42, y, RACK_Z + 0.23), (1.10, 0.10, 0.06), M(g, "Webbing"), bev=0.01)
    # folded A-frame / tripod bars strapped down the left side
    for k, dy in enumerate((-0.16, 0.0, 0.16)):
        V.tube(g, [(-0.42, 10.55 + dy, RACK_Z + 0.20), (-0.42, 13.25 + dy, RACK_Z + 0.20)],
               0.055, M(g, "TripodSteel"), 8 if g.hi else 6)
    for y in (10.75, 13.05):
        V.box(g, (-0.42, y, RACK_Z + 0.23), (0.44, 0.10, 0.24), M(g, "Webbing"), bev=0.02)
    V.box(g, (-0.42, 11.90, RACK_Z + 0.28), (0.30, 0.44, 0.20), M(g, "BlackMetal"), bev=0.04)
    # helmet and a small kit box on the rack
    V.lathe(g, (0.10, 12.20, RACK_Z + 0.16), (0, 0, 1),
            [(0.0, 0.0), (0.30, 0.0), (0.33, 0.08), (0.28, 0.20), (0.14, 0.25), (0.0, 0.26)], 18 if g.hi else 12,
            M(g, "PaintHiVis"))
    V.box(g, (0.15, 8.55, RACK_Z + 0.18), (0.72, 0.52, 0.30), M(g, "KitOrange"), bev=0.05)
    V.box(g, (0.15, 8.55, RACK_Z + 0.34), (0.62, 0.44, 0.04), M(g, "Webbing"), bev=0.01)


def snorkel(g):
    """Raised-air intake up the driver's A-pillar with a ram head."""
    x = -(HW + 0.13)
    pts = [(x, 3.05, 2.62), (x, 3.28, 3.30), (x, 3.30, 4.20), (x - 0.02, 3.26, 5.30), (x - 0.02, 3.16, 5.92)]
    V.sweep(g, [Vector(p) for p in pts], V.circle_profile(0.135, 12 if g.hi else 9), M(g, "BlackPlastic"),
            cap0=True, cap1=True)
    for z in (3.50, 3.80, 5.10):
        V.lathe(g, (x, 3.29, z), (0, 0, 1), [(0.16, 0.0), (0.16, 0.10), (0.14, 0.13)], 12 if g.hi else 9,
                M(g, "BlackPlastic"))
    V.box(g, (x - 0.02, 3.06, 6.02), (0.42, 0.56, 0.24), M(g, "BlackPlastic"), bev=0.06)
    V.box(g, (x - 0.02, 2.82, 6.04), (0.34, 0.06, 0.16), M(g, "GrilleDark"), bev=0.02)
    for k in range(3):
        V.box(g, (x - 0.13, 3.20, 3.55 + 0.30 * k), (0.10, 0.24, 0.08), M(g, "BlackMetal"), bev=0.015)


# --------------------------------------------------------------------------- cab interior
def seat(g, x, cy, cushion_z, back_top, width):
    V.box(g, (x, cy, (FLOOR + cushion_z) / 2 + 0.14), (width * 0.86, 0.78, max(0.3, cushion_z - FLOOR)),
          M(g, "InteriorDark"), bev=0.05)
    V.box(g, (x, cy, cushion_z + 0.06), (width, 0.94, 0.24), M(g, "SeatFabric"), bev=0.10)
    for sx in (-1, 1):
        V.box(g, (x + sx * (width / 2 - 0.05), cy, cushion_z + 0.13), (0.12, 0.86, 0.20), M(g, "InteriorMid"),
              bev=0.05)
    rot = Matrix.Rotation(math.radians(-16), 3, "X")
    V.box(g, (x, cy + 0.58, cushion_z + (back_top - cushion_z) / 2), (width, 0.20, back_top - cushion_z),
          M(g, "SeatFabric"), rot=rot, bev=0.10)
    V.box(g, (x, cy + 0.56, cushion_z + (back_top - cushion_z) * 0.62), (width * 0.64, 0.23,
          (back_top - cushion_z) * 0.62), M(g, "SeatAccent"), rot=rot, bev=0.06)
    V.box(g, (x, cy + 0.70, back_top + 0.16), (0.60, 0.20, 0.30), M(g, "InteriorDark"), bev=0.08)
    if cy < 7.0:
        for sx in (-0.28, 0.28):
            V.box(g, (x + sx, cy + 0.40, cushion_z + (back_top - cushion_z) * 0.55), (0.10, 0.05,
                  (back_top - cushion_z) * 0.95), M(g, "Webbing"), rot=rot, bev=0.01)
    if g.hi:
        for k in range(4):
            V.box(g, (x, cy + 0.47 - 0.15 * k, cushion_z + 0.19), (width * 0.72, 0.02, 0.012), "SeatFabric")


def cab_interior(g):
    V.box(g, (0, 8.30, FLOOR - 0.06), (5.26, 10.60, 0.12), M(g, "Carpet"), bev=0.02)
    V.box(g, (0, 6.00, FLOOR + 0.10), (1.20, 4.20, 0.20), M(g, "Carpet"), bev=0.05)
    # dashboard (RHD: driver on Blender -X)
    V.box(g, (0, 4.36, 3.72), (5.30, 0.66, 0.86), M(g, "InteriorDark"), bev=0.08)
    V.box(g, (0, 4.30, 4.20), (5.26, 0.72, 0.14), M(g, "InteriorDark"), bev=0.04)
    V.box(g, (0, 4.08, 3.02), (5.20, 0.20, 0.80), M(g, "InteriorDark"), bev=0.05)
    V.box(g, (0, 4.58, 4.25), (5.20, 0.12, 0.06), M(g, "InteriorMid"), bev=0.01)
    V.box(g, (-SEAT_X, 4.60, 4.12), (1.10, 0.24, 0.32), M(g, "InteriorDark"), bev=0.05)
    V.box(g, (-SEAT_X, 4.49, 4.08), (0.98, 0.05, 0.25), M(g, "Screen"), bev=0.02)
    V.box(g, (0.05, 4.58, 3.90), (0.94, 0.09, 0.50), M(g, "InteriorDark"), bev=0.03)
    V.box(g, (0.05, 4.52, 3.92), (0.82, 0.03, 0.40), M(g, "Screen"), bev=0.02)
    # steering wheel and column
    V.tube(g, [(-SEAT_X, 4.60, 3.98), (-SEAT_X, 4.84, 3.80)], 0.05, M(g, "InteriorDark"), 8 if g.hi else 6)
    V.lathe(g, (-SEAT_X, 4.88, 3.78), (0, -1, 0.22),
            [(0.36, 0.0), (0.36, 0.05), (0.30, 0.07), (0.24, 0.06), (0.24, 0.0)], 20 if g.hi else 14,
            M(g, "BlackPlastic"))
    V.lathe(g, (-SEAT_X, 4.87, 3.78), (0, -1, 0.22), [(0.0, 0.0), (0.10, 0.02), (0.10, 0.05), (0.0, 0.06)],
            12 if g.hi else 8, M(g, "InteriorMid"))
    V.box(g, (0, 5.30, 2.86), (0.98, 1.70, 0.82), M(g, "InteriorDark"), bev=0.07)
    V.box(g, (0, 5.30, 3.28), (0.70, 1.10, 0.08), M(g, "InteriorMid"), bev=0.03)
    # front seats and the rear bench
    seat(g, -SEAT_X, 6.15, 2.44, 4.10, 0.94)
    seat(g, SEAT_X, 6.15, 2.44, 4.10, 0.94)
    for x in (1.55, 0.0, -1.55):
        seat(g, x, 8.62, 2.52, 4.02, 0.92)
    # rear load bay: rope bags, kit, a spare helmet, fire extinguisher
    V.box(g, (0, 12.90, 2.56), (3.20, 1.60, 0.70), M(g, "RopeBagOrange"), bev=0.14)
    V.box(g, (0, 12.90, 2.90), (2.94, 1.36, 0.05), M(g, "Webbing"), bev=0.01)
    V.box(g, (1.55, 11.60, 2.55), (1.10, 1.20, 0.62), M(g, "RopeBagBlue"), bev=0.10)
    V.box(g, (0, 9.95, 2.45), (2.30, 0.16, 1.20), M(g, "InteriorMid"), bev=0.05)
    V.box(g, (0.55, 9.86, 2.60), (0.90, 0.10, 0.46), M(g, "KitOrange"), bev=0.03)
    V.lathe(g, (-1.55, 11.40, 2.35), (0, 0, 1),
            [(0.0, 0.0), (0.22, 0.0), (0.24, 0.06), (0.20, 0.14), (0.10, 0.18), (0.0, 0.19)], 14 if g.hi else 10,
            M(g, "PaintHiVis"))
    V.box(g, (-0.62, 12.94, 2.98), (0.26, 0.26, 0.34), M(g, "LensRed"), bev=0.04)
    # roof lining and cage bars
    V.box(g, (0, 8.90, ROOF - 0.30), (5.00, 9.40, 0.10), M(g, "Headliner"), bev=0.02)
    V.tube(g, [(-2.44, 6.10, SILL + 0.20), (-2.44, 6.10, ROOF - 0.34), (-2.44, 9.20, ROOF - 0.34),
               (-2.44, 9.20, SILL + 0.20)], 0.05, M(g, "BlackMetal"), 8 if g.hi else 6, fillet=0.25)
    V.tube(g, [(2.44, 6.10, SILL + 0.20), (2.44, 6.10, ROOF - 0.34), (2.44, 9.20, ROOF - 0.34),
               (2.44, 9.20, SILL + 0.20)], 0.05, M(g, "BlackMetal"), 8 if g.hi else 6, fillet=0.25)


def cabin_glass(g):
    windscreen(g)
    side_windows(g)


# --------------------------------------------------------------------------- wheels and underbody
def tyre(g, cx, side):
    profile = [(0.62, 0.30), (0.80, 0.335), (0.94, 0.348), (1.04, 0.340), (1.11, 0.300), (1.17, 0.210),
               (1.17, -0.210), (1.11, -0.300), (1.04, -0.340), (0.94, -0.348), (0.80, -0.335), (0.62, -0.30)]
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0), [(r, h * side) for r, h in profile], 16 if g.hi else 12,
            M(g, "Tyre"))
    n = 12 if g.hi else 10
    for row, xo in ((0, -0.19), (1, 0.19)):
        for k in range(n):
            a = 2 * math.pi * (k + 0.5 * row) / n
            V.box(g, (cx + xo * side, 1.105 * math.sin(a), WHEEL_Z + 1.105 * math.cos(a)),
                  (0.30, 0.24, 0.06), M(g, "Tyre"), rot=Matrix.Rotation(-a, 3, "X"), bev=0.0)
    V.lathe(g, (cx, 0, WHEEL_Z), (1, 0, 0),
            [(0.0, 0.26 * side), (0.30, 0.26 * side), (0.36, 0.23 * side), (0.70, 0.20 * side),
             (0.78, 0.12 * side), (0.78, -0.22 * side), (0.70, -0.30 * side)],
            14 if g.hi else 12, M(g, "RimDark"))
    face = cx + side * 0.225
    for k in range(5):
        a = math.radians(60 * k + 30)
        V.lathe(g, (face, 0.44 * math.sin(a), WHEEL_Z + 0.44 * math.cos(a)), (side, 0, 0),
                [(0.17, -0.02), (0.17, 0.02), (0.12, 0.035), (0.0, 0.035)], 10 if g.hi else 8, M(g, "RimDark"))
    V.lathe(g, (face, 0, WHEEL_Z), (side, 0, 0),
            [(0.0, 0.0), (0.27, 0.0), (0.27, 0.05), (0.22, 0.09), (0.0, 0.10)], 16 if g.hi else 12,
            M(g, "RimSilver"))
    for k in range(5):
        a = math.radians(72 * k)
        V.lathe(g, (face, 0.14 * math.sin(a), WHEEL_Z + 0.14 * math.cos(a)), (side, 0, 0),
                [(0.05, 0.04), (0.05, 0.07), (0.0, 0.075)], 5, M(g, "Chrome"))
    V.tube(g, [(face, 0.10, WHEEL_Z + 0.30), (face, 0.13, WHEEL_Z + 0.44)], 0.03, M(g, "BlackPlastic"),
           6)


def wheel(g, side, front):
    start = len(g.bm.verts)
    tyre(g, 0.0, side)
    g.bm.verts.ensure_lookup_table()
    cy = AX_F if front else AX_R
    for v in g.bm.verts[start:]:
        v.co = P(v.co.x + side * HUB_X, v.co.y + cy, v.co.z)


def spare_wheel(g):
    """Spare on the rear door, axis +Y, rim face aft."""
    y0 = BODY_R + 0.18
    ax = (0, 1, 0)
    V.box(g, (0, y0 - 0.06, 2.95), (1.62, 0.20, 1.62), M(g, "BlackMetal"), bev=0.05)
    prof = [(0.62, 0.30), (0.80, 0.335), (0.94, 0.348), (1.04, 0.340), (1.11, 0.300), (1.17, 0.210),
            (1.17, -0.210), (1.11, -0.300), (1.04, -0.340), (0.94, -0.348), (0.80, -0.335), (0.62, -0.30)]
    V.lathe(g, (0, y0 + 0.32, 2.95), ax, [(r, h) for r, h in prof], 18 if g.hi else 14, M(g, "Tyre"))
    V.lathe(g, (0, y0 + 0.32, 2.95), ax,
            [(0.0, -0.22), (0.30, -0.22), (0.36, -0.19), (0.70, -0.16), (0.78, -0.08), (0.78, 0.22),
             (0.70, 0.28)], 16 if g.hi else 12, M(g, "RimDark"))
    for k in range(5):
        a = math.radians(60 * k + 30)
        V.lathe(g, (0.44 * math.sin(a), y0 + 0.60, 2.95 + 0.44 * math.cos(a)), ax,
                [(0.17, -0.01), (0.17, 0.03), (0.12, 0.045), (0.0, 0.045)], 10 if g.hi else 8, M(g, "RimDark"))
    V.lathe(g, (0, y0 + 0.62, 2.95), ax,
            [(0.0, 0.0), (0.26, 0.0), (0.26, 0.05), (0.21, 0.09), (0.0, 0.10)], 16 if g.hi else 12,
            M(g, "RimSilver"))
    V.lathe(g, (0, y0 + 0.74, 2.95), ax, [(0.0, 0.0), (0.13, 0.0), (0.13, 0.04), (0.0, 0.05)],
            12 if g.hi else 8, M(g, "Chrome"))


def underbody(g):
    for sx in (-1, 1):
        V.box(g, (sx * 0.96, 7.40, 1.14), (0.26, 13.6, 0.34), M(g, "BlackMetal"), bev=0.03)
    for y in (2.0, 4.8, 7.6, 10.4, 13.0):
        V.box(g, (0, y, 1.14), (2.05, 0.20, 0.22), M(g, "BlackMetal"), bev=0.02)
    # front axle, radius arms, springs, dampers, brakes
    V.tube(g, [(-HUB_X + 0.10, AX_F, WHEEL_Z), (HUB_X - 0.10, AX_F, WHEEL_Z)], 0.13, M(g, "BlackMetal"),
           12 if g.hi else 10)
    V.lathe(g, (0.12, AX_F, WHEEL_Z), (1, 0, 0),
            [(0.0, -0.34), (0.26, -0.30), (0.36, -0.14), (0.36, 0.14), (0.24, 0.30), (0.0, 0.32)],
            14 if g.hi else 10, M(g, "BrakeSteel"))
    for sx in (-1, 1):
        V.box(g, (sx * 1.55, AX_F + 0.12, 1.02), (1.55, 0.24, 0.15), M(g, "BlackMetal"), bev=0.0)
        V.lathe(g, (sx * 1.55, AX_F + 0.12, 1.30), (0, 0, 1),
                [(0.30, 0.0), (0.30, 0.28), (0.22, 0.36), (0.30, 0.44), (0.22, 0.52), (0.0, 0.56)],
                12 if g.hi else 8, M(g, "BlackMetal"))
        V.box(g, (sx * 1.70, AX_F + 0.26, 1.58), (0.20, 0.20, 1.05), M(g, "BrakeSteel"), bev=0.02)
        V.lathe(g, (sx * (HUB_X - 0.12), AX_F, WHEEL_Z), (1, 0, 0),
                [(0.0, 0.0), (0.52, 0.0), (0.52, 0.05), (0.0, 0.05)], 12 if g.hi else 9, M(g, "BrakeSteel"))
        V.box(g, (sx * (HUB_X - 0.10), AX_F + 0.40, WHEEL_Z + 0.10), (0.12, 0.24, 0.32),
              M(g, "BlackPlastic"), bev=0.03)
    V.tube(g, [(-1.95, AX_F + 0.46, 1.08), (1.95, AX_F + 0.46, 1.08)], 0.06, M(g, "BlackMetal"),
           8 if g.hi else 6)
    # engine, gearbox, transfer box, prop shafts
    V.box(g, (0, 1.55, 1.30), (2.20, 1.55, 0.62), M(g, "BlackMetal"), bev=0.06)
    V.box(g, (0, 0.92, 1.00), (2.80, 1.05, 0.14), M(g, "Aluminium"), bev=0.04)
    V.box(g, (0, 3.90, 1.14), (0.86, 1.20, 0.56), M(g, "BlackMetal"), bev=0.05)
    V.box(g, (0, 4.75, 1.10), (0.62, 0.55, 0.48), M(g, "BlackMetal"), bev=0.04)
    V.tube(g, [(0, 4.20, 1.08), (0, AX_F + 0.10, 1.08)], 0.10, M(g, "BrakeSteel"), 10 if g.hi else 8)
    V.tube(g, [(0, 5.10, 1.06), (0, AX_R - 0.10, 1.06)], 0.10, M(g, "BrakeSteel"), 10 if g.hi else 8)
    # rear axle, coils, dampers, brakes, diff
    V.tube(g, [(-HUB_X, AX_R, WHEEL_Z), (HUB_X, AX_R, WHEEL_Z)], 0.13, M(g, "BlackMetal"), 12 if g.hi else 10)
    V.lathe(g, (0.15, AX_R, WHEEL_Z), (1, 0, 0),
            [(0.0, -0.32), (0.28, -0.28), (0.38, -0.12), (0.38, 0.12), (0.26, 0.28), (0.0, 0.30)],
            14 if g.hi else 10, M(g, "BrakeSteel"))
    for sx in (-1, 1):
        V.lathe(g, (sx * 1.55, AX_R + 0.05, 1.30), (0, 0, 1),
                [(0.30, 0.0), (0.30, 0.30), (0.22, 0.38), (0.30, 0.46), (0.22, 0.54), (0.0, 0.58)],
                12 if g.hi else 8, M(g, "BlackMetal"))
        V.box(g, (sx * 1.92, AX_R + 0.18, 1.55), (0.18, 0.18, 0.92), M(g, "BrakeSteel"), bev=0.02)
        V.lathe(g, (sx * (HUB_X - 0.12), AX_R, WHEEL_Z), (1, 0, 0),
                [(0.0, 0.0), (0.48, 0.0), (0.48, 0.05), (0.0, 0.05)], 12 if g.hi else 9, M(g, "BrakeSteel"))
        V.box(g, (sx * (HUB_X - 0.10), AX_R + 0.40, WHEEL_Z + 0.10), (0.12, 0.24, 0.32),
              M(g, "BlackPlastic"), bev=0.03)
    # fuel tank, exhaust, sill rails, mud
    V.box(g, (-1.05, 7.60, 1.28), (1.20, 1.60, 0.52), M(g, "BlackPlastic"), bev=0.10)
    V.box(g, (1.12, 8.60, 1.26), (0.86, 1.20, 0.48), M(g, "BlackMetal"), bev=0.06)
    V.tube(g, [(-1.10, 5.70, 1.02), (-1.30, 8.20, 0.98), (-1.30, 10.20, 0.98)], 0.085, M(g, "Exhaust"),
           10 if g.hi else 8, fillet=0.3)
    V.lathe(g, (-1.30, 10.35, 0.98), (0, 1, 0),
            [(0.0, 0.0), (0.15, 0.03), (0.22, 0.20), (0.22, 0.70), (0.15, 0.86), (0.09, 0.90)],
            12 if g.hi else 9, M(g, "Exhaust"))
    V.tube(g, [(-1.30, 11.30, 0.98), (-1.45, 13.60, 1.00), (-1.60, 14.05, 1.04)], 0.085, M(g, "Exhaust"),
           10 if g.hi else 8, fillet=0.25)
    V.lathe(g, (-1.60, 14.08, 1.04), (0, 1, 0), [(0.085, 0.0), (0.10, 0.02), (0.10, 0.10), (0.085, 0.12)],
            10 if g.hi else 8, M(g, "Chrome"))
    # mud sprayed on the underside and behind the arches
    for side in (-1, 1):
        for hy in (AX_F, AX_R):
            pts = []
            for k in range(7):
                a = math.radians(-98 + 196 * k / 6)
                pts.append(P(side * 1.44, hy + 1.50 * math.sin(a), WHEEL_Z + 1.50 * math.cos(a)))
            V.sweep(g, pts, [(0.0, -0.62), (1.52 * side, -0.62), (1.52 * side, 0.62), (0.0, 0.62)],
                    M(g, "WheelWell"), closed=True, cap0=True, cap1=True)
            V.box(g, (side * 1.95, hy + 1.72, 0.72), (1.20, 0.10, 0.28), M(g, "Mud"), bev=0.03)


# --------------------------------------------------------------------------- assembled parts
def body_shell(g):
    body_sides(g)
    nose_shell(g)
    roof(g)
    greenhouse(g)
    livery_side(g)


def body_detail(g):
    front_panel(g)
    bumper_front(g)
    arch_flares(g)
    door_handles(g)
    rear_panel(g)
    livery_rear(g)


def rack(g):
    roof_rack(g)
    light_bar(g)
    mast(g)
    rope_kit(g)
    snorkel(g)


def cab(g):
    cab_interior(g)


def glass(g):
    cabin_glass(g)


def wheels_underbody(g):
    underbody(g)
