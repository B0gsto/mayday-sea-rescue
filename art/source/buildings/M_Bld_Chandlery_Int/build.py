"""H2 M_Bld_Chandlery_Int: the Port Haven Chandlery interior (docs/12 H2 row, 05 section 4.3, 04 section 1.1).

Everything inside the granite shell of M_Bld_Chandlery_Ext: worn pine floorboards (ground floor to the inner wall face and
the loft), painted tongue-and-groove linings 3 cm in from the shell's inner faces with lined reveals at the door, the bay
and the three loft sashes, skirting and architraves (building trim sheet), the bressummer over the bay, seven chamfered
ceiling beams with corbels and coach bolts, joists and the boarded ceiling, the loft floor with the stairwell, its trimmers
and a balustrade, the boarded underside of the roof with common rafters, purlins, seven collar trusses, wall plates, ridge
board and the lined skylight well, the 17-riser stair to the loft (treads with brass nosings, painted risers, closed
strings, T&G spandrel, mahogany newels and handrail, rope wall rail), the long panelled counter (worn top, brass foot rail,
brass till, a chart held flat with weights, the season's logbook open), the back-wall range behind the counter (cupboards,
open gear shelving, the radio shelf bay, the four framed service cards), the hardware wall on the east wall (2 m labelled
drawer unit of 96 drawers, slatwall with hooks and blister packs), the chart table (plan chest, chart, dividers, rule),
the loft fitting room (T&G booth, curtain on a brass rail, full-length framed mirror, bench, hooks), a coir door mat and
21 practical lamps (enamel and holophane pendants from the beams, swan-neck wall lamps in the loft, ship's bulkhead lamps)
with their glass in a separate Glow MeshPart so Studio can make it emissive. ATT_Light_01..21 sit at the bulbs.

Frame: the shared H2 frame of art/source/buildings/M_Bld_Chandlery_Ext/layout.py (metres x 3 = studs, front -Y, Z up,
origin = centre of the main wall footprint at quay level). Origin is "free" on purpose: the interior must drop in at the
exterior's pivot, so it is NOT recentred (its own bbox centre is off the origin).

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Bld_Chandlery_Int --steps build,validate,export,turntable

LODs are hand-made (geo.LEVEL, as H1 M_Bld_Station): the `lod` step's collapse decimation cannot take hundreds of small
closed shells (balusters, drawers, bolts) down to the class's 7.5% LOD2 share, and would replace these meshes.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
for _m in ("geo", "atlas"):           # never pick up a sibling asset's module of the same name
    if _m in sys.modules and not getattr(sys.modules[_m], "__file__", "").startswith(HERE):
        del sys.modules[_m]
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("chandlery_layout", os.path.join(os.path.dirname(HERE), "M_Bld_Chandlery_Ext", "layout.py"))
L = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(L)
import geo  # noqa: E402
from geo import Part, trim  # noqa: E402
from atlas import DETAILS, JOINERY  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Chandlery_Int"

PINE = ("tile", 2.4)
PINE90 = ("tile90", 2.4)
TG = ("tile", 1.2)


def J(strip, metres=1.0):
    v0, v1 = JOINERY[strip]
    return ("trim", v0 + 0.004, v1 - 0.004, metres)


def D(name, w=0.3, h=0.3):
    u0, v0, u1, v1 = DETAILS[name]
    pad = 0.002
    return ("rect", u0 + pad, v0 + pad, u1 - pad, v1 - pad, w, h)


BEAM, PLANK, PANEL, RAIL, PAINT = J("Beam", 2.0), J("Plank", 1.2), J("Panel", 1.1), J("Rail", 0.8), J("Painted", 1.0)
BRASS, IRON, GLOW, FLEX, HOOK = D("Brass"), D("Iron"), D("Glow"), D("Flex", 0.05, 0.3), D("Hook")
EN_OUT, EN_IN = D("EnamelOut"), D("EnamelIn")

# lining room faces (3 cm in from the shell's inner faces)
LX0, LX1 = L.IX0 + 0.03, L.IX1 - 0.03
LY0, LY1 = L.IY0 + 0.03, L.IY1 - 0.03
K = (L.RIDGE - L.EAVES) / (L.Y1)            # roof pitch (rise per metre of Y), ridge along X
ZR = L.RIDGE - 0.32                          # boarding room face at the ridge


def zb(y):
    """Room face of the roof boarding."""
    return ZR - abs(y) * K


# stair (layout.STAIR): 17 risers from y 4.9 (floor) to the loft edge at y -1.4
NR = 17
RISE = (L.LOFT - L.FLOOR) / NR
GO = (L.STAIR[2] - L.STAIR[3]) / (NR - 1)
SX0, SX1 = L.STAIR[0] + 0.02, L.IX1 - 0.04   # 8.32 .. 9.41


def nose(y):
    """Pitch line through the tread nosings."""
    return L.FLOOR + RISE + (L.STAIR[2] - y) * RISE / GO


def qx(part, x, y0, y1, z0, z1, mode, sign):
    part.face([(x, y0, z0), (x, y1, z0), (x, y1, z1), (x, y0, z1)], mode, centre=(x - sign, (y0 + y1) / 2, (z0 + z1) / 2))


def qy(part, y, x0, x1, z0, z1, mode, sign):
    part.face([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], mode, centre=((x0 + x1) / 2, y - sign, (z0 + z1) / 2))


def qz(part, z, x0, x1, y0, y1, mode, sign):
    part.face([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)], mode, centre=((x0 + x1) / 2, (y0 + y1) / 2, z - sign))


def build():
    floor, lining, struct, furn = Part("Floor"), Part("Lining"), Part("Structure"), Part("Joinery")
    trimp, det, glow, hw = Part("Trim"), Part("Details"), Part("Glow"), Part("Hardware")
    atts = {}
    lights = []
    geo.LEVEL = 3

    # ================================================================ floors
    F = L.FLOOR
    # the floor stops at the inner wall face (IY0): Ext owns the bay display bed and the door threshold (layout.BAY_FLOOR)
    MX0, MX1, MY0, MY1 = -7.95, -6.85, L.IY0 + 0.05, L.IY0 + 0.65         # flush coir mat in a mat well inside the door
    for x0, x1, y0, y1 in ((L.IX0, L.IX1, MY1, L.IY1), (L.IX0, L.IX1, L.IY0, MY0), (L.IX0, MX0, MY0, MY1), (MX1, L.IX1, MY0, MY1)):
        qz(floor, F, x0, x1, y0, y1, PINE, 1)
    # loft floor: slab A (all but the stair strip), B (east strip in front of the stairwell), trimmers
    TX0, TX1, HY0, HY1 = 8.16, 8.32, -1.56, L.STAIR[3]
    ZL, ZC = L.LOFT, 3.20
    for x0, x1, y0, y1 in ((LX0 - 0.01, TX0, LY0 - 0.01, LY1 + 0.01), (TX0, LX1 + 0.01, LY0 - 0.01, HY0)):
        qz(floor, ZL, x0, x1, y0, y1, PINE90, 1)
        qz(lining, ZC, x0, x1, y0, y1, TG, -1)
    struct.box((TX0, HY0, 2.95), (TX1, LY1 + 0.01, ZL), PLANK, skip=("+y",))
    struct.box((TX1, HY0, 2.95), (LX1 + 0.01, HY1, ZL), PLANK, skip=("+x",))
    det.box((SX0 + 0.06, HY1 - 0.01, ZL - 0.03), (SX1 - 0.07, HY1 + 0.025, ZL + 0.004), BRASS, skip=("-x", "+x", "-z"))
    # coir mat inside the door
    geo.LEVEL = 2
    det.box((MX0, MY0, F - 0.03), (MX1, MY1, F), D("Mat", MX1 - MX0, MY1 - MY0), skip=("-z",))     # flush: the door leaf swings over it

    # ================================================================ wall linings (room faces) and reveals
    geo.LEVEL = 3
    G0, G1 = F - 0.01, ZC + 0.01          # ground-floor lining z range (into floor and ceiling)
    U0 = ZL - 0.01
    dx0, dx1, dz1 = L.DOOR[0], L.DOOR[1], L.DOOR[3]
    bx0, bx1, bz1 = L.BAY[0], L.BAY[1], L.BAY[3]
    # front, ground
    for x0, x1, z0, z1 in ((LX0, dx0, G0, G1), (dx0, dx1, dz1, G1), (dx1, bx0, G0, G1), (bx0, bx1, bz1, G1), (bx1, LX1, G0, G1)):
        qy(lining, LY0, x0, x1, z0, z1, TG, 1)
    # front, loft: strips between the sashes
    wz0, wz1 = L.LOFT_WIN_Z
    top_f = zb(LY0) + 0.02
    xs = [LX0] + [v for w in L.LOFT_WINDOWS for v in w] + [LX1]
    for i in range(0, len(xs), 2):
        qy(lining, LY0, xs[i], xs[i + 1], U0, top_f, TG, 1)
    for w0, w1 in L.LOFT_WINDOWS:
        qy(lining, LY0, w0, w1, U0, wz0, TG, 1)
        qy(lining, LY0, w0, w1, wz1, top_f, TG, 1)
    # back wall (the stairwell strip runs on up past the loft floor)
    qy(lining, LY1, LX0, TX0, G0, G1, TG, -1)
    qy(lining, LY1, TX0, LX1, G0, ZL + 0.01, TG, -1)
    qy(lining, LY1, LX0, LX1, U0, zb(LY1) + 0.02, TG, -1)
    # gables: ground (east: up to the loft over the stairwell) and loft pentagons up the roof line
    qx(lining, LX0, LY0, LY1, G0, G1, TG, 1)
    qx(lining, LX1, LY0, HY1, G0, G1, TG, -1)
    qx(lining, LX1, HY1, LY1, G0, ZL + 0.01, TG, -1)
    for x, sign in ((LX0, 1), (LX1, -1)):
        pts = [(x, LY0, U0), (x, LY1, U0), (x, LY1, zb(LY1) + 0.02), (x, 0.0, zb(0) + 0.02), (x, LY0, zb(LY0) + 0.02)]
        lining.face(pts, TG, centre=(x - sign, 0, 5.0))

    def reveal(x0, x1, z0, z1, depth, sill=True, head=True, part=lining):
        y0, y1 = LY0 - depth, LY0
        qx(part, x0 + 0.02, y0, y1, z0, z1, TG, 1)
        qx(part, x1 - 0.02, y0, y1, z0, z1, TG, -1)
        if head:
            qz(part, z1 - 0.02, x0 + 0.02, x1 - 0.02, y0, y1, TG, -1)
        if sill:
            qz(part, z0 + 0.02, x0 + 0.02, x1 - 0.02, y0, y1, TG, 1)

    # door reveal: Ext lines it (0.05 m timber linings through the wall, layout.DOOR_STONE_OPENING); no Int reveal
    reveal(bx0, bx1, F, bz1, L.WALL + 0.03, sill=False, head=False)
    qz(lining, bz1 - 0.02, bx0 + 0.02, bx1 - 0.02, L.Y0, LY0, TG, -1)
    FRAME_IN = L.Y0 + 0.20                 # inner face of Ext's sash frames (yA + 0.12)
    for w0, w1 in L.LOFT_WINDOWS:
        reveal(w0, w1, wz0, wz1, LY0 - FRAME_IN, sill=False)

    # architraves (trim sheet WindowFrame), granite window boards (Sill), skirting (Fascia)
    geo.LEVEL = 2
    AR, AW = trim("WindowFrame", 1.0), 0.07

    def architrave(x0, x1, z0, z1, bottom=False, y0=LY0):
        y1 = LY0 + 0.022
        trimp.box((x0 - AW + 0.02, y0, z0), (x0 + 0.02, y1, z1), AR, skip=("-y",))
        trimp.box((x1 - 0.02, y0, z0), (x1 + AW - 0.02, y1, z1), AR, skip=("-y",))
        trimp.box((x0 - AW + 0.02, y0, z1), (x1 + AW - 0.02, y1, z1 + AW), AR, skip=("-y",))
        if bottom:
            trimp.box((x0 - AW + 0.02, y0, z0 - AW), (x1 + AW - 0.02, y1, z0), AR, skip=("-y",))

    architrave(dx0, dx1, F, dz1, y0=L.IY0)
    for w0, w1 in L.LOFT_WINDOWS:
        architrave(w0, w1, wz0 + 0.0, wz1)
        trimp.box((w0 - 0.08, L.Y0 + 0.15, wz0 - 0.06), (w1 + 0.08, LY0 + 0.07, wz0 + 0.02), trim("Sill", 1.0))
    geo.LEVEL = 3
    SK, SKH = trim("Fascia", 1.2), 0.18

    def skirt_x(y, x0, x1, z, sign):
        y0, y1 = (y, y + 0.022) if sign > 0 else (y - 0.022, y)
        trimp.box((x0, y0, z), (x1, y1, z + SKH), SK, skip=("-y" if sign > 0 else "+y", "-z"))

    def skirt_y(x, y0, y1, z, sign):
        x0, x1 = (x, x + 0.022) if sign > 0 else (x - 0.022, x)
        trimp.box((x0, y0, z), (x1, y1, z + SKH), SK, skip=("-x" if sign > 0 else "+x", "-z"))

    for x0, x1 in ((LX0, dx0 - AW + 0.02), (dx1 + AW - 0.02, bx0 - 0.12), (bx1 + 0.12, LX1)):
        skirt_x(LY0, x0, x1, F, 1)
    skirt_x(LY1, LX0, LX1, F, -1)
    skirt_y(LX0, LY0 + 0.022, LY1 - 0.022, F, 1)
    skirt_y(LX1, LY0 + 0.022, LY1 - 0.022, F, -1)
    skirt_x(LY0, LX0, LX1, ZL, 1)
    skirt_x(LY1, LX0, TX0, ZL, -1)
    skirt_y(LX0, LY0 + 0.022, LY1 - 0.022, ZL, 1)
    skirt_y(LX1, LY0 + 0.022, HY0, ZL, -1)

    # ================================================================ ground-floor structure: bressummer, beams, joists
    geo.LEVEL = 3
    struct.box((bx0 - 0.35, LY0 - 0.01, 2.93), (bx1 + 0.35, LY0 + 0.24, ZC + 0.005), BEAM, skip=("-y", "+z"))
    for xb, cas in ((bx0 - 0.12, 0), (bx1 + 0.02, 1)):            # bay casings
        struct.box((xb, LY0 - 0.01, F), (xb + 0.1, LY0 + 0.05, 2.93), PLANK, skip=("-y", "-z", "+z"))
    for xb in L.BEAM_XS:
        prof = [(xb - 0.12, ZC), (xb - 0.12, 2.99), (xb - 0.08, 2.95), (xb + 0.08, 2.95), (xb + 0.12, 2.99), (xb + 0.12, ZC)]
        y_front = LY0 + 0.24 if bx0 - 0.3 < xb < bx1 + 0.3 else LY0
        struct.prism([(p[0], p[1]) for p in prof], "y", y_front, LY1, BEAM, caps=False)
        geo.LEVEL = 2
        for y_end, sgn in ((y_front, 1), (LY1, -1)):
            if y_front > LY0 and sgn > 0:
                pass
            else:                                              # corbel under the beam end
                struct.prism([(y_end, 2.95), (y_end + sgn * 0.45, 2.95), (y_end, 2.62)] if sgn > 0 else
                             [(y_end + sgn * 0.45, 2.95), (y_end, 2.95), (y_end, 2.62)], "x", xb - 0.1, xb + 0.1, BEAM)
            geo.LEVEL = 1
            for side in (-1, 1):                                # coach bolt heads and square washers, both sides
                for dz in (3.03, 3.13):
                    yb = y_end + sgn * 0.22
                    xf = xb + side * 0.12
                    det.box((min(xf, xf + side * 0.008), yb - 0.035, dz - 0.035), (max(xf, xf + side * 0.008), yb + 0.035, dz + 0.035), IRON, skip=("-x" if side > 0 else "+x",))
                    det.box((min(xf, xf + side * 0.022), yb - 0.015, dz - 0.015), (max(xf, xf + side * 0.022), yb + 0.015, dz + 0.015), IRON, skip=("-x" if side > 0 else "+x",))
            geo.LEVEL = 2
        geo.LEVEL = 3
    y = LY0 + 0.32
    geo.LEVEL = 2
    while y < LY1 - 0.1:
        x1 = LX1 if y < HY0 - 0.05 else TX0
        struct.box((LX0, y - 0.0375, 3.05), (x1, y + 0.0375, ZC), BEAM, skip=("+z", "-x", "+x"))
        y += 0.6
    geo.LEVEL = 3

    # ================================================================ roof underside: boarding, rafters, purlins, trusses
    def at(y, depth):
        """Point under the boarding at |y| on a slope, 'depth' below its room face (perpendicular)."""
        s = 1 if y > 0 else -1
        nrm = Vector((0, s * K, 1)).normalized()            # outward normal of that slope
        return Vector((0, y, zb(y))) - nrm * depth, nrm

    sk_x0, sk_x1 = L.SKYLIGHT[0] + 0.02, L.SKYLIGHT[1] - 0.02           # Ext roof hole, well lining 2 cm inside it
    sk_y0 = L.SKYLIGHT_YZ[1][0] + 0.02                                   # upper edge (nearer the ridge)
    sk_y1 = L.SKYLIGHT_YZ[0][0] - 0.02                                   # lower edge

    def zu(y):
        """Ext roof slab underside (plane through the wall plate)."""
        return L.RIDGE - abs(y) * L.ROOF_SLOPE
    for s in (-1, 1):
        ye = s * (abs(LY0) + 0.01)
        if s < 0:
            pieces = [(LX0 - 0.01, LX1 + 0.01, ye, 0.0)]
        else:
            pieces = [(LX0 - 0.01, sk_x0, 0.0, ye), (sk_x1, LX1 + 0.01, 0.0, ye), (sk_x0, sk_x1, 0.0, sk_y0), (sk_x0, sk_x1, sk_y1, ye)]
        for x0, x1, ya, yb_ in pieces:
            lining.face([(x0, ya, zb(ya)), (x1, ya, zb(ya)), (x1, yb_, zb(yb_)), (x0, yb_, zb(yb_))], TG, centre=((x0 + x1) / 2, (ya + yb_) / 2, 20))
    # skylight well (lined, 0.3 m up to the outer roof), timber edge
    c_up = Vector(((sk_x0 + sk_x1) / 2, (sk_y0 + sk_y1) / 2, zb((sk_y0 + sk_y1) / 2) + 0.15))
    _, n_back = at(1.0, 0)
    for x, sgn in ((sk_x0, 1), (sk_x1, -1)):           # plumb well walls from the boarding up 3 cm past Ext's slab underside
        lining.face([(x, sk_y0, zb(sk_y0)), (x, sk_y1, zb(sk_y1)), (x, sk_y1, zu(sk_y1) + 0.03), (x, sk_y0, zu(sk_y0) + 0.03)],
                    TG, centre=(x - sgn, c_up.y, c_up.z))
    for yy, sgn in ((sk_y0, 1), (sk_y1, -1)):
        lining.face([(sk_x0, yy, zb(yy)), (sk_x1, yy, zb(yy)), (sk_x1, yy, zu(yy) + 0.03), (sk_x0, yy, zu(yy) + 0.03)], TG,
                    centre=(c_up.x, yy - sgn, c_up.z))
    geo.LEVEL = 2
    for x0, x1, ya, yb_ in ((sk_x0 - 0.05, sk_x0 + 0.005, sk_y0 - 0.05, sk_y1 + 0.05), (sk_x1 - 0.005, sk_x1 + 0.05, sk_y0 - 0.05, sk_y1 + 0.05)):
        pa, _ = at(ya, 0.015)
        pb, _ = at(yb_, 0.015)
        struct.obox(((x0 + x1) / 2, pa.y, pa.z), ((x0 + x1) / 2, pb.y, pb.z), x1 - x0, 0.03, n_back, PLANK)
    for yy in (sk_y0 - 0.015, sk_y1 + 0.015):
        p, _ = at(yy, 0.015)
        struct.obox((sk_x0 - 0.05, p.y, p.z), (sk_x1 + 0.05, p.y, p.z), 0.03, 0.03, n_back, PLANK)
    geo.LEVEL = 3
    # common rafters every 0.6 m (trimmed round the skylight)
    geo.LEVEL = 2
    for i in range(31):
        x = -9.0 + 0.6 * i
        for s in (-1, 1):
            spans = [(s * (abs(LY0) - 0.02), s * 0.05)]
            if s > 0 and sk_x0 + 0.05 < x < sk_x1 - 0.05:
                spans = [(sk_y0 - 0.06, 0.05), (LY1 - 0.02, sk_y1 + 0.06)]
            elif s > 0 and sk_x0 - 0.1 < x < sk_x1 + 0.1:
                spans = []          # replaced by the trimmer rafter
            for ya, yb_ in spans:
                pa, n = at(ya, 0.075)
                pb, _ = at(yb_, 0.075)
                struct.obox((x, pa.y, pa.z), (x, pb.y, pb.z), 0.05, 0.15, n, BEAM, skip_ends=True, skip=("top",))
    for xx in (sk_x0 - 0.055, sk_x1 + 0.055):      # trimmer rafters either side of the skylight (back slope)
        pa, n = at(0.05, 0.075)
        pb, _ = at(LY1 - 0.02, 0.075)
        struct.obox((xx, pa.y, pa.z), (xx, pb.y, pb.z), 0.06, 0.15, n, BEAM, skip_ends=True, skip=("top",))
    geo.LEVEL = 3
    # ridge board, purlins, wall plates
    struct.box((LX0, -0.04, zb(0) - 0.26), (LX1, 0.04, zb(0) + 0.01), BEAM, skip=("+z", "-x", "+x"))
    for s in (-1, 1):
        p, n = at(s * 2.7, 0.15 + 0.085)
        struct.obox((LX0, p.y, p.z), (LX1, p.y, p.z), 0.20, 0.17, n, BEAM, skip_ends=True)
        y0, y1 = (LY0, LY0 + 0.18) if s < 0 else (LY1 - 0.18, LY1)
        struct.box((LX0, y0, 5.78), (LX1, y1, zb(LY0) + 0.01), BEAM, skip=("-x", "+x", "-y" if s < 0 else "+y"))
    # collar trusses on the beam lines (LOD0 and LOD1)
    geo.LEVEL = 2
    zcol = 7.55
    for xb in L.BEAM_XS:
        for s in (-1, 1):
            pa, n = at(s * (abs(LY0) - 0.18), 0.15 + 0.11)
            pb, _ = at(s * 0.06, 0.15 + 0.11)
            struct.obox((xb, pa.y, pa.z), (xb, pb.y, pb.z), 0.12, 0.22, n, BEAM)
        ycol = (ZR - 0.15 - 0.22 - zcol) / K
        struct.box((xb - 0.06, -ycol, zcol - 0.1), (xb + 0.06, ycol, zcol + 0.1), BEAM)
        struct.box((xb - 0.06, -0.06, zcol + 0.1), (xb + 0.06, 0.06, zb(0) - 0.26), BEAM, skip=("+z",))
        geo.LEVEL = 1
        for yy in (-ycol + 0.12, ycol - 0.12, 0.0):
            for side in (-1, 1):
                xf = xb + side * 0.06
                det.box((min(xf, xf + side * 0.02), yy - 0.015, zcol - 0.015), (max(xf, xf + side * 0.02), yy + 0.015, zcol + 0.015), IRON, skip=("-x" if side > 0 else "+x",))
        geo.LEVEL = 2
    geo.LEVEL = 3

    # ================================================================ stair
    stair_x = (SX0 + 0.06, SX1 - 0.07)      # between the strings
    for i in range(1, NR):
        yi = L.STAIR[2] - (i - 1) * GO
        zi = F + i * RISE
        struct.box((stair_x[0], yi - GO, zi - 0.035), (stair_x[1], yi + 0.03, zi), PLANK, skip=("-x", "+x"))
        qy(lining, yi, stair_x[0], stair_x[1], zi - RISE, zi - 0.035, TG, 1)
        geo.LEVEL = 1
        det.box((stair_x[0] + 0.05, yi + 0.005, zi - 0.012), (stair_x[1] - 0.05, yi + 0.035, zi + 0.004), BRASS, skip=("-z",))
        geo.LEVEL = 3
    # strings (closed), soffit and T&G spandrel under the open side
    yb_bot = L.STAIR[2] - (0.43 - nose(L.STAIR[2])) * GO / RISE if False else L.STAIR[2] + (nose(L.STAIR[2]) - 0.28 - F) * GO / RISE
    prof = [(5.0, F), (5.0, nose(5.0) + 0.08), (HY1, nose(HY1) + 0.08), (HY1, nose(HY1) - 0.28), (yb_bot, F)]
    for x0, x1 in ((SX0, SX0 + 0.06), (SX1 - 0.07, SX1)):
        struct.prism(prof, "x", x0, x1, PAINT)
    lining.face([(stair_x[0], yb_bot, F + 0.002), (stair_x[1], yb_bot, F + 0.002), (stair_x[1], HY1, nose(HY1) - 0.28),
                 (stair_x[0], HY1, nose(HY1) - 0.28)], TG, centre=(9.0, 2.0, 9.0))
    lining.face([(SX0 - 0.004, yb_bot, F), (SX0 - 0.004, HY1 + 0.0, F), (SX0 - 0.004, HY1, nose(HY1) - 0.28)], TG, centre=(9.5, 1.0, 1.0))
    qy(lining, HY1 - 0.004, SX0, LX1, F, nose(HY1) - 0.28, TG, -1)
    # newels, handrail, balusters
    struct.box((SX0 - 0.04, 4.98, F), (SX0 + 0.10, 5.12, 1.28), RAIL)
    struct.box((SX0 - 0.055, 4.965, 1.28), (SX0 + 0.115, 5.135, 1.33), RAIL)
    struct.box((TX0 + 0.01, HY0 + 0.01, 2.88), (TX1 - 0.01, HY0 + 0.15, ZL + 1.1), RAIL)
    struct.box((TX0 - 0.005, HY0 - 0.005, ZL + 1.1), (TX1 + 0.005, HY0 + 0.165, ZL + 1.15), RAIL)
    xr = SX0 + 0.03
    p0 = Vector((xr, 5.05, nose(5.05) + 0.9))
    p1 = Vector((xr, HY0 + 0.08, nose(HY0 + 0.08) + 0.9))
    struct.obox(p0, p1, 0.07, 0.06, (0, 0, 1), RAIL)
    geo.LEVEL = 2
    yv = 4.85
    while yv > HY1 + 0.05:
        struct.box((xr - 0.017, yv - 0.017, nose(yv) + 0.06), (xr + 0.017, yv + 0.017, nose(yv) + 0.87), PAINT, skip=("-z", "+z"))
        yv -= 0.13
    # loft balustrade along the stairwell edge
    geo.LEVEL = 3
    xl = (TX0 + TX1) / 2
    struct.box((xl - 0.035, HY0 + 0.15, ZL + 0.95), (xl + 0.035, LY1, ZL + 1.01), RAIL, skip=("+y",))
    struct.box((xl - 0.04, HY0 + 0.15, ZL), (xl + 0.04, LY1, ZL + 0.06), PAINT, skip=("+y", "-z"))
    geo.LEVEL = 2
    yv = HY0 + 0.27
    while yv < LY1 - 0.05:
        struct.box((xl - 0.017, yv - 0.017, ZL + 0.06), (xl + 0.017, yv + 0.017, ZL + 0.95), PAINT, skip=("-z", "+z"))
        yv += 0.12
    # rope wall rail on brass brackets (east wall)
    geo.LEVEL = 2
    xw = LX1 - 0.07
    ra = Vector((xw, 4.9, nose(4.9) + 0.86))
    rb = Vector((xw, HY1 + 0.15, nose(HY1 + 0.15) + 0.86))
    det.tube(ra, rb, 0.016, 8, D("Rope", 0.1, 0.1))
    geo.LEVEL = 1
    for f in (0.05, 0.35, 0.65, 0.95):
        p = ra.lerp(rb, f)
        det.box((p.x - 0.005, p.y - 0.03, p.z - 0.05), (LX1, p.y + 0.03, p.z - 0.012), BRASS, skip=("+x",))
        det.box((LX1 - 0.008, p.y - 0.04, p.z - 0.09), (LX1, p.y + 0.04, p.z + 0.0), BRASS, skip=("+x",))
    geo.LEVEL = 3

    # ================================================================ the counter
    cx0, cx1, cyf, cyb, ch = L.COUNTER
    furn.box((cx0 + 0.02, cyf + 0.02, F + 0.10), (cx1 - 0.02, cyb - 0.03, ch - 0.04), PANEL, skip=("+y", "+z", "-z", "-x", "+x"))
    for xe in (cx0 + 0.02, cx1 - 0.02):
        sgn = -1 if xe < 0 + cx0 + 0.1 else 1
        qx(furn, xe, cyf + 0.02, cyb - 0.03, F + 0.10, ch - 0.04, PLANK, sgn)
    furn.box((cx0 + 0.06, cyf + 0.06, F), (cx1 - 0.06, cyb - 0.06, F + 0.10), PAINT, skip=("-z", "+z", "+y"))
    # shopkeeper side: open shelving, back panel, uprights
    qy(furn, cyf + 0.05, cx0 + 0.04, cx1 - 0.04, F, ch - 0.04, PAINT, 1)
    for zs in (F + 0.10, 0.58):
        furn.box((cx0 + 0.04, cyf + 0.05, zs), (cx1 - 0.04, cyb - 0.03, zs + 0.025), PLANK, skip=("-y",))
    n_up = 7
    for k in range(n_up):
        xu = cx0 + 0.02 + k * (cx1 - cx0 - 0.04 - 0.04) / (n_up - 1)
        furn.box((xu, cyf + 0.05, F), (xu + 0.04, cyb - 0.03, ch - 0.04), PAINT, skip=("-y", "-z", "+z"))
    # worn top with a rounded front edge (details atlas: hand wear in front of the till and the logbook)
    TOP = D("CounterTop", cx1 - cx0 + 0.1, cyb - cyf + 0.1)
    yt0, yt1 = cyf - 0.05, cyb + 0.05
    furn.prism([(yt0 + 0.015, ch - 0.04), (yt1, ch - 0.04), (yt1, ch), (yt0 + 0.015, ch), (yt0 + 0.004, ch - 0.007),
                (yt0, ch - 0.02), (yt0 + 0.004, ch - 0.033)], "x", cx0 - 0.05, cx1 + 0.05, TOP)
    # brass foot rail on brackets
    geo.LEVEL = 2
    det.tube((cx0 + 0.1, cyf - 0.16, 0.30), (cx1 - 0.1, cyf - 0.16, 0.30), 0.024, 10, BRASS)
    geo.LEVEL = 1
    for xb_ in (cx0 + 0.25, (cx0 + cx1) / 2 - 1.1, (cx0 + cx1) / 2 + 1.1, cx1 - 0.25):
        det.box((xb_ - 0.015, cyf - 0.16, 0.27), (xb_ + 0.015, cyf + 0.02, 0.33), BRASS, skip=("+y",))
        det.box((xb_ - 0.04, cyf + 0.015, 0.25), (xb_ + 0.04, cyf + 0.025, 0.35), BRASS, skip=("+y",))
    geo.LEVEL = 3

    # brass till at ATT_Till (keys face the shopkeeper, +Y; the amount sign faces both ways)
    tx, ty = L.ATT["ATT_Till"][0], L.ATT["ATT_Till"][1]
    geo.LEVEL = 2
    det.box((tx - 0.22, ty - 0.17, ch), (tx + 0.22, ty + 0.25, ch + 0.13), BRASS, skip=("-z",))
    det.prism([(ty - 0.13, ch + 0.13), (ty + 0.23, ch + 0.13), (ty + 0.23, ch + 0.17), (ty + 0.04, ch + 0.36), (ty - 0.13, ch + 0.36)],
              "x", tx - 0.2, tx + 0.2, BRASS)
    a_, b_ = Vector((0, ty + 0.23, ch + 0.17)), Vector((0, ty + 0.04, ch + 0.36))
    nk = Vector((0, b_.z - a_.z, -(b_.y - a_.y))).normalized()
    if nk.z < 0:
        nk = -nk
    m0, m1 = a_ + nk * 0.004, b_ + nk * 0.004
    det.face([(tx - 0.18, m0.y, m0.z), (tx + 0.18, m0.y, m0.z), (tx + 0.18, m1.y, m1.z), (tx - 0.18, m1.y, m1.z)], D("TillKeys", 0.36, 0.27),
             centre=(tx, ty, ch))
    det.box((tx - 0.15, ty - 0.08, ch + 0.36), (tx + 0.15, ty + 0.04, ch + 0.52), BRASS)
    for yy, sg in ((ty - 0.084, -1), (ty + 0.044, 1)):
        qy(det, yy, tx - 0.14, tx + 0.14, ch + 0.37, ch + 0.51, D("TillSign", 0.28, 0.14), sg)
    det.box((tx - 0.2, ty + 0.25, ch + 0.015), (tx + 0.2, ty + 0.27, ch + 0.115), BRASS, skip=("-y",))
    det.box((tx - 0.05, ty + 0.27, ch + 0.05), (tx + 0.05, ty + 0.29, ch + 0.08), RAIL, skip=("-y",))
    det.tube((tx + 0.22, ty + 0.02, ch + 0.22), (tx + 0.3, ty + 0.02, ch + 0.22), 0.012, 6, BRASS)
    det.tube((tx + 0.3, ty + 0.02, ch + 0.22), (tx + 0.3, ty + 0.11, ch + 0.14), 0.01, 6, BRASS)
    det.tube((tx + 0.3, ty + 0.11, ch + 0.14), (tx + 0.36, ty + 0.11, ch + 0.14), 0.016, 6, RAIL)
    # chart on the counter, held flat by lead weights and a brass rule
    c0x, c0y = 2.85, cyf + 0.02
    det.box((c0x, c0y, ch + 0.003), (c0x + 1.2, c0y + 0.6, ch + 0.007), D("Chart", 1.2, 0.6), skip=("-z",))
    geo.LEVEL = 1
    for wx, wy in ((c0x + 0.04, c0y + 0.52), (c0x + 1.12, c0y + 0.05)):
        det.box((wx, wy, ch + 0.007), (wx + 0.06, wy + 0.04, ch + 0.04), IRON, skip=("-z",))
    det.box((c0x + 0.3, c0y + 0.18, ch + 0.004), (c0x + 0.9, c0y + 0.24, ch + 0.016), RAIL, skip=("-z",))
    det.box((c0x + 0.3, c0y + 0.20, ch + 0.016), (c0x + 0.9, c0y + 0.22, ch + 0.019), BRASS, skip=("-z",))
    geo.LEVEL = 3
    # the season's logbook, open (both tracks), on the counter at ATT_Logbook
    lx, ly = L.ATT["ATT_Logbook"][0], L.ATT["ATT_Logbook"][1] - 0.05
    geo.LEVEL = 2
    det.box((lx - 0.27, ly - 0.18, ch), (lx + 0.27, ly + 0.18, ch + 0.006), D("Cloth", 0.54, 0.36), skip=("-z",))
    u0, v0, u1, v1 = DETAILS["Logbook"]
    um = (u0 + u1) / 2
    for xa, xb_, (ua, ub) in ((lx - 0.25, lx - 0.004, (u0, um)), (lx + 0.004, lx + 0.25, (um, u1))):
        det.box((xa, ly - 0.165, ch + 0.006), (xb_, ly + 0.165, ch + 0.024), D("Paper", 0.3, 0.05), skip=("-z", "+z"))
        qz(det, ch + 0.024, xa, xb_, ly - 0.165, ly + 0.165, ("rect", ua + 0.002, v0 + 0.002, ub - 0.002, v1 - 0.002, xb_ - xa, 0.33), 1)
    geo.LEVEL = 1
    det.tube((lx + 0.3, ly - 0.1, ch + 0.006), (lx + 0.34, ly + 0.08, ch + 0.006), 0.005, 6, D("Cloth"))
    geo.LEVEL = 3

    # ================================================================ back-wall range behind the counter
    wy = LY1
    # cupboards x 0.1 .. 5.2 (panelled doors), worktop, plinth
    furn.box((0.1, wy - 0.5, F + 0.1), (5.2, wy, 0.92), J("Panel", 0.85), skip=("+y", "-z", "+z", "-x", "+x"))
    qx(furn, 0.1, wy - 0.5, wy, F + 0.1, 0.92, PLANK, -1)
    qx(furn, 5.2, wy - 0.5, wy, F + 0.1, 0.92, PLANK, 1)
    furn.box((0.14, wy - 0.46, F), (5.16, wy, F + 0.1), PAINT, skip=("+y", "-z", "+z"))
    furn.box((0.07, wy - 0.54, 0.92), (5.23, wy, 0.96), PLANK, skip=("+y",))
    geo.LEVEL = 1
    for k in range(6):
        xk = 0.1 + (k + 0.5) * 5.1 / 6
        for dx in (-0.06, 0.06):
            det.box((xk + dx - 0.008, wy - 0.52, 0.76), (xk + dx + 0.008, wy - 0.5, 0.84), BRASS, skip=("+y",))
    geo.LEVEL = 3
    # open shelves over the worktop (west end) and the long stock shelf over the cards, on iron brackets
    for x0, x1, zs, dep in ((0.1, 2.7, 1.40, 0.3), (0.1, 2.7, 1.90, 0.3), (0.1, 5.2, 2.62, 0.32)):
        furn.box((x0, wy - dep, zs - 0.03), (x1, wy, zs), PLANK, skip=("+y",))
        geo.LEVEL = 1
        nb = 3 if x1 - x0 < 3 else 5
        for k in range(nb):
            xk = x0 + 0.15 + k * (x1 - x0 - 0.3) / (nb - 1)
            det.prism([(wy, zs - 0.03), (wy - dep + 0.05, zs - 0.03), (wy, zs - 0.25)], "x", xk - 0.012, xk + 0.012, IRON)
        geo.LEVEL = 3
    # framed service cards (centred on ATT_ServiceCards)
    sx, sz = L.ATT["ATT_ServiceCards"][0], L.ATT["ATT_ServiceCards"][2]
    for i in range(4):
        cx = sx + (i - 1.5) * 0.46
        w, h, fw = 0.32, 0.64, 0.045
        x0, x1, z0, z1 = cx - w / 2, cx + w / 2, sz - h / 2, sz + h / 2
        for lo, hi in (((x0 - fw, wy - 0.03, z0 - fw), (x0, wy, z1 + fw)), ((x1, wy - 0.03, z0 - fw), (x1 + fw, wy, z1 + fw)),
                       ((x0, wy - 0.03, z1), (x1, wy, z1 + fw)), ((x0, wy - 0.03, z0 - fw), (x1, wy, z0))):
            furn.box(lo, hi, RAIL, skip=("+y",))
        qy(det, wy - 0.012, x0, x1, z0, z1, D("Card%d" % i, w, h), -1)
    # tall open gear shelving x 5.3 .. 8.2 (the radio shelf bay at 7.6)
    ups = [5.3, 6.27, 7.23, 8.16]
    for xu in ups:
        furn.box((xu - 0.02, wy - 0.42, F), (xu + 0.02, wy, 2.72), PAINT, skip=("+y",))
    for a_, b_ in zip(ups, ups[1:]):
        geo.LEVEL = 2
        for zs in (0.30, 0.75, 1.2, 1.6, 2.05, 2.5):
            furn.box((a_ + 0.02, wy - 0.40, zs - 0.03), (b_ - 0.02, wy, zs), PLANK, skip=("+y",))
        geo.LEVEL = 3
    furn.box((ups[0] - 0.04, wy - 0.46, 2.72), (ups[-1] + 0.04, wy, 2.80), PAINT, skip=("+y",))

    # ================================================================ hardware wall (east wall, in front of the stair)
    ex = LX1
    dy0, dy1, dz0, dz1_ = -5.15, -3.35, F + 0.1, F + 2.0
    furn.box((ex - 0.45, dy0, F), (ex, dy1, F + 2.06), PAINT, skip=("+x",))
    furn.box((ex - 0.48, dy0 - 0.03, F + 2.06), (ex, dy1 + 0.03, F + 2.12), PAINT, skip=("+x",))
    cols, rws = 8, 12
    cw, rh = (dy1 - dy0 - 0.06) / cols, (dz1_ - dz0) / rws
    rr = __import__("random").Random(7)
    for c in range(cols):
        for r in range(rws):
            ya, yb_ = dy0 + 0.03 + c * cw + 0.006, dy0 + 0.03 + (c + 1) * cw - 0.006
            za, zb_ = dz0 + r * rh + 0.006, dz0 + (r + 1) * rh - 0.006
            geo.LEVEL = 2
            hw.box((ex - 0.47, ya, za), (ex - 0.445, yb_, zb_), D("Drawer%d" % rr.randrange(16), yb_ - ya, zb_ - za), skip=("+x",))
            geo.LEVEL = 1
            ym, zm = (ya + yb_) / 2, za + (zb_ - za) * 0.18
            hw.box((ex - 0.49, ym - 0.03, zm - 0.012), (ex - 0.47, ym + 0.03, zm + 0.012), BRASS, skip=("+x",))
            geo.LEVEL = 3
    # slatwall with hooks and blister packs
    sy0, sy1, sz0, sz1 = -3.2, -1.7, 0.55, 2.65
    hw.box((ex - 0.022, sy0, sz0), (ex, sy1, sz1), D("Slatwall", sy1 - sy0, sz1 - sz0), skip=("+x",))
    furn.box((ex - 0.04, sy0 - 0.03, sz0 - 0.04), (ex, sy1 + 0.03, sz0), RAIL, skip=("+x",))
    furn.box((ex - 0.04, sy0 - 0.03, sz1), (ex, sy1 + 0.03, sz1 + 0.04), RAIL, skip=("+x",))
    furn.box((ex - 0.42, sy0, F), (ex, sy1, 0.5), PAINT, skip=("+x",))
    furn.box((ex - 0.44, sy0 - 0.02, 0.5), (ex, sy1 + 0.02, 0.53), PLANK, skip=("+x",))
    geo.LEVEL = 2
    k = 0
    for zr in (0.95, 1.35, 1.75, 2.15):
        for c in range(5):
            yh = sy0 + 0.15 + c * (sy1 - sy0 - 0.3) / 4
            hw.obox((ex - 0.02, yh, zr), (ex - 0.2, yh, zr + 0.02), 0.008, 0.008, (0, 0, 1), HOOK, skip_ends=False)
            if (k * 7) % 10 < 7:
                pk = "Pack%d" % (k % 4)
                for j in range(2):
                    xo = ex - 0.05 - j * 0.05
                    hw.box((xo - 0.004, yh - 0.05, zr - 0.20), (xo, yh + 0.05, zr + 0.0), D(pk, 0.1, 0.2), skip=("-z", "+z"))
            k += 1
    geo.LEVEL = 3

    # ================================================================ chart table (plan chest) at layout.CHART_TABLE
    tx0, tx1, ty0, ty1, th = L.CHART_TABLE
    furn.box((tx0 + 0.05, ty0 + 0.05, F), (tx1 - 0.05, ty1 - 0.05, F + 0.1), PAINT, skip=("-z",))
    furn.box((tx0 + 0.02, ty0 + 0.02, F + 0.1), (tx1 - 0.02, ty1 - 0.02, th - 0.05), RAIL, skip=("-z", "+z"))
    geo.LEVEL = 2
    for k in range(4):
        z0 = F + 0.13 + k * 0.145
        furn.box((tx0 + 0.06, ty0 + 0.005, z0), (tx1 - 0.06, ty0 + 0.02, z0 + 0.13), J("Rail", 0.8), skip=("+y",))
        geo.LEVEL = 1
        for xp in (tx0 + 0.4, tx1 - 0.4):
            det.box((xp - 0.05, ty0 - 0.01, z0 + 0.05), (xp + 0.05, ty0 + 0.005, z0 + 0.08), BRASS, skip=("+y",))
        geo.LEVEL = 2
    geo.LEVEL = 3
    furn.box((tx0, ty0, th - 0.05), (tx1, ty1, th), RAIL)
    for lo, hi in (((tx0, ty1 - 0.03, th), (tx1, ty1, th + 0.03)), ((tx0, ty0, th), (tx0 + 0.03, ty1 - 0.03, th + 0.03)),
                   ((tx1 - 0.03, ty0, th), (tx1, ty1 - 0.03, th + 0.03))):
        furn.box(lo, hi, RAIL, skip=("-z",))
    det.box((tx0 + 0.15, ty0 + 0.1, th + 0.003), (tx0 + 1.65, ty0 + 0.88, th + 0.007), D("Chart", 1.5, 0.78), skip=("-z",))
    geo.LEVEL = 1
    det.box((tx0 + 0.5, ty0 + 0.25, th + 0.004), (tx0 + 1.1, ty0 + 0.33, th + 0.016), RAIL, skip=("-z",))
    det.box((tx0 + 0.5, ty0 + 0.28, th + 0.016), (tx0 + 1.1, ty0 + 0.30, th + 0.019), BRASS, skip=("-z",))
    hinge = Vector((tx0 + 1.3, ty0 + 0.55, th + 0.08))
    for dx_, dy_ in ((0.06, -0.12), (-0.05, -0.13)):
        det.obox(hinge, hinge + Vector((dx_, dy_, -0.075)), 0.006, 0.006, (0, 0, 1), BRASS)
    for wx_, wy_ in ((tx0 + 0.2, ty0 + 0.8), (tx0 + 1.55, ty0 + 0.15)):
        det.box((wx_, wy_, th + 0.004), (wx_ + 0.06, wy_ + 0.04, th + 0.04), IRON, skip=("-z",))
    geo.LEVEL = 3

    # ================================================================ loft fitting room (west end)
    fx0, fx1, fy0, fy1 = L.FITTING_ROOM
    fx0 = LX0
    ztop = ZL + 2.2
    for yp in (fy0, fy1):
        lining.box((fx0, yp - 0.03, ZL), (fx1, yp + 0.03, ztop), TG, skip=("-z", "-x", "+z"))
        furn.box((fx0, yp - 0.04, ztop), (fx1 + 0.02, yp + 0.04, ztop + 0.04), RAIL, skip=("-x",))
    rail_z = ztop - 0.05
    det.tube((fx1 - 0.02, fy0 + 0.03, rail_z), (fx1 - 0.02, fy1 - 0.03, rail_z), 0.014, 8, BRASS)
    # curtain: pleated canvas, gathered at both ends, open in the middle so the mirror shows
    CUR = D("Curtain", 1.0, 2.2)
    geo.LEVEL = 2
    for ya, yb_, nf in ((fy0 + 0.04, -0.25, 9), (0.85, fy1 - 0.04, 4)):
        pts = []
        for k in range(nf * 2 + 1):
            yy = ya + (yb_ - ya) * k / (nf * 2)
            pts.append((fx1 - 0.02 + (0.05 if k % 2 else -0.05), yy))
        for (xa, ya_), (xb2, yb2) in zip(pts, pts[1:]):
            det.panel2([(xa, ya_, ZL + 0.03), (xb2, yb2, ZL + 0.03), (xb2, yb2, rail_z - 0.03), (xa, ya_, rail_z - 0.03)], CUR)
    geo.LEVEL = 1
    for k in range(14):
        yy = fy0 + 0.06 + k * (fy1 - fy0 - 0.12) / 13
        det.box((fx1 - 0.034, yy - 0.004, rail_z - 0.026), (fx1 - 0.006, yy + 0.004, rail_z + 0.026), BRASS)
    geo.LEVEL = 3
    # full-length mirror in a mahogany frame on the west wall
    mz, my = L.ATT["ATT_Mirror"][2], 0.0
    mw, mh, fw = 0.62, 1.7, 0.07
    m0, m1, n0, n1 = my - mw / 2, my + mw / 2, mz - mh / 2, mz + mh / 2
    for lo, hi in (((LX0, m0 - fw, n0 - fw), (LX0 + 0.05, m0, n1 + fw)), ((LX0, m1, n0 - fw), (LX0 + 0.05, m1 + fw, n1 + fw)),
                   ((LX0, m0, n1), (LX0 + 0.05, m1, n1 + fw)), ((LX0, m0, n0 - fw), (LX0 + 0.05, m1, n0))):
        furn.box(lo, hi, RAIL, skip=("-x",))
    qx(det, LX0 + 0.035, m0, m1, n0, n1, D("Mirror", mw, mh), 1)
    # bench and hooks in the booth
    furn.box((LX0 + 0.05, 0.55, ZL + 0.42), (LX0 + 0.42, 1.1, ZL + 0.46), PLANK)
    for yb_ in (0.6, 1.05):
        furn.box((LX0 + 0.08, yb_ - 0.02, ZL), (LX0 + 0.38, yb_ + 0.02, ZL + 0.42), PLANK, skip=("-z",))
    geo.LEVEL = 1
    for xh in (-9.1, -8.7, -8.3):
        det.box((xh - 0.015, fy1 - 0.03 - 0.06, ZL + 1.72), (xh + 0.015, fy1 - 0.03, ZL + 1.75), BRASS, skip=("+y",))
        det.box((xh - 0.025, fy1 - 0.035, ZL + 1.66), (xh + 0.025, fy1 - 0.03, ZL + 1.78), BRASS, skip=("+y",))
    geo.LEVEL = 3

    # ================================================================ practical lamps (geometry + ATT_Light_NN at the bulb)
    def add_light(p, kind):
        lights.append((Vector(p), kind))
        geo.LEVEL = 3

    def pendant_enamel(x, y, drop=0.62):
        geo.LEVEL = 2
        ztop_ = 2.95
        det.lathe([(0.055, 0.0), (0.055, -0.03)], (x, y, ztop_), 12, BRASS, cap_bottom=True)
        zs = ztop_ - drop
        det.tube((x, y, ztop_ - 0.03), (x, y, zs + 0.09), 0.006, 5, FLEX, caps=False)
        det.lathe([(0.03, 0.09), (0.03, 0.02)], (x, y, zs), 10, BRASS, cap_top=True)
        prof = [(0.03, 0.02), (0.07, -0.005), (0.15, -0.07), (0.21, -0.13), (0.225, -0.15)]
        det.lathe(prof, (x, y, zs), 16, EN_OUT)
        det.lathe([(p_[0] - 0.006, p_[1] - 0.004) for p_ in prof], (x, y, zs), 16, EN_IN, inside=True)
        det.lathe([(0.225, -0.15), (0.231, -0.153), (0.219, -0.153)], (x, y, zs), 16, EN_OUT)
        glow.lathe([(0.0, 0.0), (0.03, -0.01), (0.045, -0.045), (0.035, -0.08), (0.0, -0.095)], (x, y, zs), 10, GLOW)
        add_light((x, y, zs - 0.05), "pendant")

    def pendant_holophane(x, y, drop=0.7):
        geo.LEVEL = 2
        ztop_ = 2.95
        det.lathe([(0.055, 0.0), (0.055, -0.03)], (x, y, ztop_), 12, BRASS, cap_bottom=True)
        zs = ztop_ - drop
        det.tube((x, y, ztop_ - 0.03), (x, y, zs + 0.06), 0.006, 5, FLEX, caps=False)
        det.lathe([(0.02, 0.10), (0.05, 0.06), (0.075, 0.03), (0.075, 0.0)], (x, y, zs), 14, BRASS, cap_top=True)
        glow.lathe([(0.07, 0.0), (0.12, -0.06), (0.15, -0.16), (0.13, -0.24), (0.06, -0.28), (0.0, -0.285)], (x, y, zs), 16, GLOW)
        det.lathe([(0.152, -0.15), (0.152, -0.17)], (x, y, zs), 16, BRASS)
        add_light((x, y, zs - 0.14), "holophane")

    def wall_lamp(x, y, z, ny):
        """Swan-neck brass arm off a back plate, enamel shade facing down; ny = wall normal (+1 / -1) in Y."""
        geo.LEVEL = 2
        det.box((x - 0.05, min(y, y + ny * 0.02), z - 0.08), (x + 0.05, max(y, y + ny * 0.02), z + 0.08), BRASS, skip=("+y" if ny < 0 else "-y",))
        p_wall = Vector((x, y, z))
        p_mid = Vector((x, y + ny * 0.22, z + 0.12))
        p_end = Vector((x, y + ny * 0.34, z + 0.02))
        det.tube(p_wall, p_mid, 0.011, 6, BRASS, caps=False)
        det.tube(p_mid, p_end, 0.011, 6, BRASS, caps=False)
        zs = z - 0.0
        prof = [(0.025, 0.0), (0.06, -0.02), (0.12, -0.08), (0.14, -0.11)]
        det.lathe(prof, (p_end.x, p_end.y, zs), 14, EN_OUT, cap_top=True)
        det.lathe([(p_[0] - 0.005, p_[1] - 0.004) for p_ in prof], (p_end.x, p_end.y, zs), 14, EN_IN, inside=True)
        glow.lathe([(0.0, -0.01), (0.03, -0.02), (0.04, -0.05), (0.028, -0.08), (0.0, -0.09)], (p_end.x, p_end.y, zs), 10, GLOW)
        add_light((p_end.x, p_end.y, zs - 0.06), "wall")

    def bulkhead(p, n):
        """Ship's bulkhead lamp on a wall: brass base, milk-glass dome, cast cage. n = wall normal (unit, X or Y)."""
        geo.LEVEL = 2
        n = Vector(n)
        c = Vector(p)
        e1 = Vector((0, 0, 1))
        e2 = n.cross(e1).normalized()

        def ring(r, d, segs=14):
            return [c + n * d + e1 * (r * math.cos(2 * math.pi * j / segs)) + e2 * (r * math.sin(2 * math.pi * j / segs)) for j in range(segs)]

        def band(part, r0, d0, r1, d1, mode, segs=14):
            a_, b_ = ring(r0, d0, segs), ring(r1, d1, segs)
            mid = c + n * ((d0 + d1) / 2)
            for j in range(segs):
                k = (j + 1) % segs
                part.face([a_[j], a_[k], b_[k], b_[j]], mode, centre=mid)
            return b_

        det.prim += 1
        band(det, 0.12, 0.0, 0.12, 0.04, BRASS)
        det.face(list(reversed(ring(0.12, 0.04))), BRASS, centre=c)
        glow.prim += 1
        band(glow, 0.085, 0.04, 0.085, 0.09, GLOW)
        band(glow, 0.085, 0.09, 0.06, 0.13, GLOW)
        glow.face(ring(0.06, 0.13), GLOW, centre=c)
        geo.LEVEL = 1
        for ang in (0.0, math.pi / 2):
            d1 = e1 * math.cos(ang) + e2 * math.sin(ang)
            det.obox(c + n * 0.04 + d1 * 0.1, c + n * 0.145, 0.012, 0.012, n.cross(d1), IRON)
            det.obox(c + n * 0.04 - d1 * 0.1, c + n * 0.145, 0.012, 0.012, n.cross(d1), IRON)
        geo.LEVEL = 2
        add_light(c + n * 0.09, "bulkhead")

    for (x, y) in ((-7.2, -2.6), (-4.8, 1.3), (-2.4, -2.9), (-2.4, 4.1), (0.0, -1.0), (0.0, 3.0), (7.2, -2.6)):
        pendant_enamel(x, y, 0.62 if y != 4.1 else 0.85)
    for x in (2.4, 4.8):
        pendant_holophane(x, (cyf + cyb) / 2)
    for x in L.SKY_LOFT_LIGHT_XS:
        wall_lamp(x, LY1, ZL + 1.95, -1)
    for x in (-3.3, 2.3, 6.6):
        wall_lamp(x, LY0, ZL + 1.95, 1)
    wall_lamp(-8.5, fy1 - 0.03, ZL + 1.95, -1)                     # in the fitting booth, on the partition
    for p, n in (((LX0, -4.6, 2.45), (1, 0, 0)), ((LX0, 1.0, 2.45), (1, 0, 0)), ((LX1, -2.45, 2.82), (-1, 0, 0)),
                 ((-1.2, LY1, 2.5), (0, -1, 0)), ((LX1, -3.0, ZL + 1.9), (-1, 0, 0))):
        bulkhead(p, n)

    # ================================================================ objects
    mats = {
        "Floor": ("Pine", geo.material("MI_ChandInt_Pine", (0.30, 0.20, 0.12), 0.55)),
        "Lining": ("Lining", geo.material("MI_ChandInt_Lining", (0.52, 0.48, 0.40), 0.6)),
        "Structure": ("Joinery", geo.material("MI_ChandInt_Structure", (0.16, 0.11, 0.07), 0.7)),
        "Joinery": ("Joinery", geo.material("MI_ChandInt_Joinery", (0.2, 0.13, 0.08), 0.5)),
        "Trim": ("Sheet", geo.material("MI_ChandInt_Trim", (0.4, 0.4, 0.38), 0.6)),
        "Details": ("Details", geo.material("MI_ChandInt_Details", (0.5, 0.42, 0.25), 0.4, 0.5)),
        "Glow": ("Details", geo.material("MI_ChandInt_Glow", (0.9, 0.85, 0.75), 0.15)),
        "Hardware": ("Details", geo.material("MI_ChandInt_Hardware", (0.3, 0.25, 0.2), 0.5)),
    }
    meshes, totals = [], [0, 0, 0]
    glow.faces = [(f[0], f[1], 3, f[3]) for f in glow.faces]     # lamp glass stays in every LOD (lights read from afar)
    for p in (floor, lining, struct, furn, trimp, det, glow, hw):
        s, mat = mats[p.name]
        counts = []
        for li in (0, 1, 2):
            obj = p.to_object("%s_%s_LOD%d" % (NAME, p.name, li), mat, lod=li)
            meshes.append({"object": obj, "set": s})
            counts.append(sum(len(f.vertices) - 2 for f in obj.data.polygons))
            totals[li] += counts[-1]
        print("[H2] %-10s LOD0 %5d  LOD1 %5d  LOD2 %5d" % (p.name, counts[0], counts[1], counts[2]))
    print("[H2] totals LOD0 %d  LOD1 %d  LOD2 %d tris, %d lamps" % (totals[0], totals[1], totals[2], len(lights)))

    # ================================================================ collision: floors, loft, stair ramp, counter, walls
    col = Part("COL")
    CM = ("tile", 4.0)
    col.box((L.IX0, L.IY0, -0.2), (L.IX1, L.IY1, F), CM)
    col.box((L.IX0, L.IY0, 2.95), (TX1, L.IY1, ZL), CM)
    col.box((TX1, L.IY0, 2.95), (L.IX1, HY1, ZL), CM)
    col.prism([(5.15, F), (HY1, ZL), (HY1, F)], "x", SX0, L.IX1, CM)
    col.box((cx0 - 0.05, cyf - 0.05, F), (cx1 + 0.05, cyb + 0.05, ch), CM)
    col.box((TX0, HY0 + 0.15, ZL), (TX1, L.IY1, ZL + 1.05), CM)
    WT, ZT = 0.12, L.RIDGE
    col.box((L.IX0 - WT, L.IY0, F), (L.IX0, L.IY1, ZT), CM)
    col.box((L.IX1, L.IY0, F), (L.IX1 + WT, L.IY1, ZT), CM)
    col.box((L.IX0, L.IY1, F), (L.IX1, L.IY1 + WT, ZT), CM)
    col.box((L.IX0, L.IY0 - WT, F), (dx0, L.IY0, ZT), CM)
    col.box((dx0, L.IY0 - WT, dz1), (dx1, L.IY0, ZT), CM)
    col.box((dx1, L.IY0 - WT, F), (L.IX1, L.IY0, ZT), CM)
    col.box((L.FITTING_ROOM[0], fy0 - 0.03, ZL), (fx1, fy0 + 0.03, ztop), CM)
    col.box((L.FITTING_ROOM[0], fy1 - 0.03, ZL), (fx1, fy1 + 0.03, ztop), CM)
    colobj = col.to_object(NAME + "_COL", None, weld=False)

    # ================================================================ attachments
    att_objs = []
    own = ["ATT_DoorInside", "ATT_Counter", "ATT_Till", "ATT_Logbook", "ATT_ServiceCards", "ATT_ChartTable",
           "ATT_StairBottom", "ATT_StairTop", "ATT_Mirror", "ATT_FittingRoom"]
    pts = [(n, Vector(L.ATT[n])) for n in own]
    pts += [("ATT_Light_%02d" % (i + 1), p) for i, (p, kind) in enumerate(lights)]
    for n, p in pts:
        e = bpy.data.objects.new(n, None)
        e.location = (p.x * 3, p.y * 3, p.z * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)
    # render-only practical lights for the turntable / close-ups (not exported: export sees the spec's meshes only)
    for i, (p, kind) in enumerate(lights):
        ld = bpy.data.lights.new("LGT_ChandInt_%02d" % (i + 1), "POINT")
        ld.energy = {"pendant": 220.0, "holophane": 260.0, "wall": 140.0, "bulkhead": 120.0}[kind]
        ld.color = (1.0, 0.80, 0.58)
        ld.shadow_soft_size = 0.15
        lo_ = bpy.data.objects.new("LGT_ChandInt_%02d" % (i + 1), ld)
        lo_.location = (p.x * 3, p.y * 3, p.z * 3 - (0.25 if kind in ("pendant", "holophane", "wall") else 0.0))
        bpy.context.scene.collection.objects.link(lo_)
    sky = bpy.data.lights.new("LGT_ChandInt_Skylight", "AREA")
    sky.energy, sky.size, sky.color = 900.0, 3.0, (0.82, 0.9, 1.0)
    so = bpy.data.objects.new("LGT_ChandInt_Skylight", sky)
    so.location = ((sk_x0 + sk_x1) / 2 * 3, (sk_y0 + sk_y1) / 2 * 3, zb((sk_y0 + sk_y1) / 2) * 3 - 0.3)
    bpy.context.scene.collection.objects.link(so)

    tex = G + "assets/textures/"
    S = 3.0
    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 40000,
        "tier": "hero",
        "dims_m": (L.IX1 - L.IX0, L.IY1 - L.Y0, None),   # inner faces in X; Y from the bay reveals at the outer wall plane to the back wall
        "size_note": None,
        "origin": "free",
        "origin_note": "shared H2 frame (layout.py): the interior drops in at the exterior's pivot, so it is not recentred",
        "tiling": True,
        "waivers": {"LOD UV layout": "world-scale tiling UVs (pine, T&G, joinery and building trim sheets): the decimated LODs drop small parts, so the UV bounds change; no baked layout to keep"},
        "sets": [
            {"name": "ChandleryInt", "set": "Pine", "size": 1024, "wet": False},
            {"name": "ChandleryInt", "set": "Lining", "size": 1024, "wet": False},
            {"name": "ChandleryInt", "set": "Joinery", "size": 1024, "wet": False},
            {"name": "ChandleryInt", "set": "Details", "size": 2048, "wet": False},
            {"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": False, "dir": tex + "M_Bld_TrimSheet"},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "counter_till_chart", "target": [4.4 * S, 0.9 * S, 1.1 * S], "dist": 10, "az": -15, "el": 28},
            {"name": "loft_stairs", "target": [8.85 * S, 1.6 * S, 1.9 * S], "dist": 16, "az": -70, "el": 12},
            {"name": "hardware_wall_drawers", "target": [9.2 * S, -3.3 * S, 1.4 * S], "dist": 11, "az": -95, "el": 6},
            {"name": "fitting_room_mirror", "target": [-9.2 * S, 0.3 * S, 4.5 * S], "dist": 9, "az": 90, "el": 3},
            {"name": "pendant_lamp", "target": [-2.4 * S, -2.9 * S, 2.25 * S], "dist": 3.5, "az": 25, "el": -12},
            {"name": "floorboard_wear", "target": [-4.0 * S, -3.6 * S, F * S], "dist": 6, "az": 30, "el": 48},
        ],
    }
