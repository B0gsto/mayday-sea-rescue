"""M_Sea_MailSeaplane: generic 1960s Otter-class single-engine mail floatplane, moored at the Gale Isles.

12.7 m long, 16.7 m span on twin aluminium floats, high wing, radial cowl, 3-blade prop. Invented
"GALE ISLES AIR MAIL" livery in faded red and cream, registration G-GIAM, mail-bag door. Origin at the
float waterline (z 0), nose at -Y. Two bakes: Airframe (4096) and Floats (2048).
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vehgeo as V  # noqa: E402
import rbxkit  # noqa: E402

NAME = "M_Sea_MailSeaplane"
TEX = "MailSeaplane"
WATERLINE = 0.0

FUSE = [
    (-15.0, 7.60, 1.55, 1.55), (-14.2, 7.65, 2.15, 1.85), (-12.6, 7.70, 2.48, 2.15),
    (-11.2, 7.75, 2.55, 2.35), (-10.4, 7.78, 2.58, 2.55), (-9.6, 7.80, 2.60, 2.72),
    (-7.0, 7.85, 2.60, 3.00), (-1.0, 7.82, 2.60, 3.00),
    (3.0, 7.80, 2.58, 2.98), (6.5, 7.78, 2.48, 2.86), (9.2, 7.80, 2.22, 2.50),
    (11.4, 7.90, 1.86, 1.95), (13.4, 8.02, 1.45, 1.40), (15.2, 8.16, 1.05, 0.98),
    (16.6, 8.30, 0.68, 0.64), (17.4, 8.42, 0.38, 0.38),
]
COWL_F, COWL_R, COWL_Z = -17.7, -14.7, 7.85
WING_Z = 11.0
WING_LE, WING_CH, WING_TH = -6.7, 8.1, 1.16
HALF_SPAN = 25.05


def smart_unwrap(ob, angle=70, margin=0.004):
    """Smart unwrap with a tight pack: the stock 0.01 pack margin wastes most of this 50-stud atlas on its many
    small islands."""
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.0015, correct_aspect=True)
    bpy.ops.uv.pack_islands(margin=0.0015, rotate=True, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")
    ob.select_set(False)


def M(g, name):
    return name


def fuse_halfwidth(y):
    for (y0, z0, hw0, hh0), (y1, z1, hw1, hh1) in zip(FUSE, FUSE[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return hw0 + (hw1 - hw0) * t
    return FUSE[0][2] if y < FUSE[0][0] else FUSE[-1][2]


def super_ring(y, zc, hw, hh, seg=20, p=3.3):
    pts = []
    for j in range(seg):
        t = 2 * math.pi * j / seg
        c, s = math.cos(t), math.sin(t)
        x = hw * math.copysign(abs(c) ** (2.0 / p), c)
        z = zc + hh * math.copysign(abs(s) ** (2.0 / p), s)
        pts.append(Vector((x, y, z)))
    return pts


def loft_y(g, sections, mat, seg=20, p=3.3, cap0=True, cap1=True, matfn=None):
    rings = [super_ring(*s, seg=seg, p=p) for s in sections]
    return g.rings(rings, mat, cap0=cap0, cap1=cap1, matfn=matfn)


def foil_ring(x, yle, chord, th, zc, n=18):
    pts = []
    for k in range(n):
        t = k / (n - 1)
        yy = yle + t * chord
        zt = zc + 0.5 * th * math.sin(math.pi * t) ** 0.62 * (1 - 0.10 * t)
        pts.append(Vector((x, yy, zt)))
    for k in range(n - 2, 0, -1):
        t = k / (n - 1)
        yy = yle + t * chord
        zb = zc - 0.5 * th * math.sin(math.pi * t) ** 0.78 * (1 - 0.16 * t)
        pts.append(Vector((x, yy, zb)))
    return pts


def wing_stations():
    st = []
    for x in (-25.05, -24.2, -22.0, -18.0, -13.0, -7.0, 0.0, 7.0, 13.0, 18.0, 22.0, 24.2, 25.05):
        f = abs(x) / HALF_SPAN
        st.append((x, WING_LE + 0.65 * f * f, WING_CH - 2.45 * f ** 1.6, WING_TH - 0.52 * f ** 1.2,
                   WING_Z + 0.16 * f ** 2))
    return st


# --------------------------------------------------------------------------- fuselage
def fuselage_shell(g):
    loft_y(g, FUSE, M(g, "MailCream"), seg=22, p=3.35)
    # cabin roof fairing: a slight raised panel over the wing carry-through
    V.box(g, (0, 1.7, 10.83), (5.0, 15.8, 0.30), M(g, "MailCream"), bev=0.10)
    # belly / walkway panel
    V.box(g, (0, 2.0, 4.79), (3.6, 16.0, 0.16), M(g, "MailCreamDirty"), bev=0.06)
    # nose firewall collar behind the cowl
    V.box(g, (0, -14.55, 7.85), (4.3, 0.30, 4.9), M(g, "MailCreamDirty"), bev=0.14)
    # dorsal spine fillet to the fin
    V.box(g, (0, 14.9, 9.36), (1.1, 5.0, 0.55), M(g, "MailCream"), bev=0.16)


def cheatline(g):
    for side in (1, -1):
        for (y0, y1, z, h) in ((-14.1, -8.9, 6.30, 0.62), (-8.9, -1.0, 6.25, 0.66),
                               (-1.0, 8.9, 6.24, 0.66), (9.0, 11.8, 6.35, 0.56)):
            V.box(g, (side * 2.615, (y0 + y1) / 2, z), (0.045, y1 - y0, h), M(g, "MailRed"), bev=0.012)
        # thin companion stripe
        V.box(g, (side * 2.617, 0.2, 5.82), (0.035, 18.6, 0.12), M(g, "MailRedDark"), bev=0.008)
        # wing-root red band and cowl flash
        V.box(g, (side * 2.61, -11.6, 8.0), (0.035, 2.2, 0.16), M(g, "MailRedDark"), bev=0.008)


def canopy(g):
    loft_y(g, [(-9.55, 10.70, 2.34, 0.58), (-8.60, 10.74, 2.42, 0.60),
               (-7.40, 10.72, 2.38, 0.55), (-6.25, 10.60, 2.18, 0.40)],
           M(g, "MailCream"), seg=18, p=3.0)


def window_frames(g):
    seal = M(g, "GlassSeal")
    for side in (1, -1):
        panes = [(-2.6, 2.0), (4.1, 2.0), (7.4, 1.7)]
        if side < 0:
            panes = [(-2.6, 2.0), (7.4, 1.7)]
        for yc, hw in panes:
            V.box(g, (side * 2.60, yc, 8.35), (0.10, hw + 0.14, 1.72), seal, bev=0.05)
        # cockpit door window and rear quarter light
        V.box(g, (side * 2.60, -8.35, 9.35), (0.10, 2.5, 1.80), seal, bev=0.05)
        V.box(g, (side * 2.22, 9.55, 8.55), (0.10, 0.95, 1.10), seal, bev=0.04)
        # A pillars
        V.tube(g, [(side * 2.14, -10.58, 10.26), (side * 2.14, -9.56, 11.26)], 0.07, seal, 6)
        V.tube(g, [(side * 2.14, -9.56, 11.26), (side * 2.14, -6.4, 11.28)], 0.06, seal, 6)
    # windscreen frame: base, step bar, header and centre post
    V.box(g, (0, -10.57, 10.30), (4.32, 0.11, 0.11), seal, bev=0.015)
    V.box(g, (0, -10.05, 10.81), (4.18, 0.10, 0.10), seal, bev=0.015)
    V.box(g, (0, -9.55, 11.28), (4.30, 0.11, 0.11), seal, bev=0.015)
    V.box(g, (0, -10.06, 10.79), (0.13, 0.20, 1.0), seal, rot=Matrix.Rotation(math.radians(-45), 3, "X"), bev=0.015)


def window_glass(g):
    glass = M(g, "Glass")
    for side in (1, -1):
        panes = [(-2.6, 2.0), (4.1, 2.0), (7.4, 1.7)]
        if side < 0:
            panes = [(-2.6, 2.0), (7.4, 1.7)]
        for yc, hw in panes:
            V.box(g, (side * 2.635, yc, 8.35), (0.06, hw, 1.54), glass, bev=0.035)
        V.box(g, (side * 2.635, -8.35, 9.35), (0.06, 2.36, 1.62), glass, bev=0.035)
        V.box(g, (side * 2.255, 9.55, 8.55), (0.06, 0.82, 0.97), glass, bev=0.03)
    # stepped two-pane windscreen, split by the centre post
    for side in (1, -1):
        x0, x1 = side * 0.11, side * 2.12
        for (ya, za, yb, zb) in ((-10.55, 10.31, -10.06, 10.80), (-10.04, 10.82, -9.56, 11.26)):
            rows = [[Vector((x0, ya, za)), Vector((x1, ya, za))],
                    [Vector((x0, yb, zb)), Vector((x1, yb, zb))]]
            vs = [[g.bm.verts.new(p) for p in r] for r in rows]
            f = g.face([vs[0][0], vs[0][1], vs[1][1], vs[1][0]], glass)
            if f:
                g.orient([f], lambda c: Vector((0, -1, 0.4)))


def doors(g):
    out = M(g, "MailRedDark")
    for side in (1, -1):
        x = side * 2.625
        # cockpit door seam
        for y0 in (4.10, -10.05):
            V.box(g, (x, y0, 7.0), (0.035, 0.06, 3.5), out, bev=0.006)
        for z0 in (5.25, 8.80):
            V.box(g, (x, -7.05, z0), (0.035, 6.0, 0.06), out, bev=0.006)
        V.box(g, (x, -5.15, 7.20), (0.10, 0.30, 0.30), M(g, "BareSteel"), bev=0.03)
        V.box(g, (x, -4.98, 7.60), (0.11, 0.10, 0.62), M(g, "BareSteel"), bev=0.02)
        # cargo door aft of the cabin (starboard) and mail-bag door (port)
        if side > 0:
            V.box(g, (x, 7.55, 6.70), (0.035, 3.0, 3.0), out, bev=0.008)
            V.box(g, (x + side * 0.012, 7.55, 5.32), (0.05, 2.8, 0.10), M(g, "MailRed"), bev=0.01)
            V.box(g, (x, 9.08, 6.70), (0.10, 0.22, 0.55), M(g, "BareSteel"), bev=0.02)
            for z in (5.65, 7.75):
                V.box(g, (x, 6.18, z), (0.10, 0.26, 0.16), M(g, "BareSteel"), bev=0.02)
        else:
            V.box(g, (x, 5.0, 6.55), (0.045, 3.05, 2.20), M(g, "MailCreamDirty"), bev=0.012)
            V.box(g, (x - 0.012, 5.0, 5.48), (0.055, 2.9, 0.10), M(g, "MailRed"), bev=0.01)
            V.box(g, (x - 0.02, 5.0, 7.64), (0.055, 2.9, 0.10), M(g, "MailRed"), bev=0.01)
            V.box(g, (x - 0.10, 5.0, 5.68), (0.24, 2.5, 0.16), M(g, "MailRed"), bev=0.02)
            V.box(g, (x - 0.10, 6.28, 6.10), (0.12, 0.34, 0.34), M(g, "BareSteel"), bev=0.03)
            V.box(g, (x - 0.10, 6.10, 6.45), (0.12, 0.10, 0.52), M(g, "BareSteel"), bev=0.02)
            for z in (5.65, 6.35, 7.05, 7.55):
                V.box(g, (x, 3.50, z), (0.10, 0.22, 0.13), M(g, "BareSteel"), bev=0.02)
            # small mail door window
            V.box(g, (x - 0.03, 4.55, 6.98), (0.05, 1.0, 0.68), M(g, "Glass"), bev=0.03)


def fuse_details(g):
    for side in (1, -1):
        # fuel filler caps on the nose deck
        V.box(g, (side * 2.00, -12.9, 9.78), (0.62, 0.72, 0.10), M(g, "FuelCap"), bev=0.05)
        V.box(g, (side * 1.75, -7.0, 4.95), (0.55, 0.9, 0.12), M(g, "MailCreamDirty"), bev=0.04)
        # boarding step under the cabin door
        V.box(g, (side * 1.95, -6.55, 4.70), (0.9, 1.1, 0.14), M(g, "BareSteel"), bev=0.04)
        V.box(g, (side * 1.95, -6.55, 4.60), (0.16, 0.9, 0.18), M(g, "BareSteel"), bev=0.03)
        # wing-root fairings
        V.box(g, (side * 2.35, -3.4, 10.35), (1.1, 6.4, 0.55), M(g, "MailCream"), bev=0.16)
        # navigation lamps at the wing roots where the greybox keeps them visible
        V.box(g, (side * 2.58, -11.9, 8.05), (0.08, 0.22, 0.22), M(g, "NavRed" if side > 0 else "NavGreen"), bev=0.02)
    # roof antenna mast and wire, aft of the wing
    V.box(g, (0.0, 9.75, 11.02), (0.10, 0.18, 0.62), M(g, "BareSteel"), bev=0.02)
    V.tube(g, [(0.0, 9.78, 11.30), (0.0, 12.2, 11.20), (0.0, 14.6, 12.34)], 0.022, M(g, "BareSteel"), 5)
    # pitot under the starboard wing
    V.tube(g, [(5.5, -4.2, 10.40), (6.4, -4.9, 10.38)], 0.035, M(g, "BareSteel"), 6)
    # oil breather stains seeping back behind the cowl
    for side in (1, -1):
        for (y, z, ln, h) in ((-11.0, 6.95, 2.2, 0.50), (-10.2, 6.30, 1.7, 0.35)):
            V.box(g, (side * (fuse_halfwidth(y) + 0.012), y, z), (0.035, ln, h), M(g, "OilStain"), bev=0.01)
    # exhaust soot along the starboard nose
    for (y, z, ln, h) in ((-13.7, 6.75, 1.2, 0.55), (-12.6, 6.55, 1.4, 0.62), (-11.4, 6.30, 1.3, 0.48)):
        V.box(g, (-(fuse_halfwidth(y) + 0.012), y, z), (0.035, ln, h), M(g, "SootStain"), bev=0.01)


def livery_text(g):
    def side_panel(side, body, size, yc, zc, mat, x=2.66):
        me = V.text_mesh(body, size, resolution=1)
        if side > 0:
            def mp(co):
                return Vector((x, yc + co.x, zc + co.y))
        else:
            def mp(co):
                return Vector((-x, yc - co.x, zc + co.y))
        fs = g.add_mesh(me, mat, mp)
        g.orient(fs, lambda c, side=side: Vector((side, 0, 0)))
        bpy.data.meshes.remove(me)
    for side in (1, -1):
        side_panel(side, "GALE ISLES", 0.50, -2.0, 7.25, "MailRedDark")
        side_panel(side, "AIR MAIL", 0.50, 1.95, 7.25, "MailRedDark")
        side_panel(side, "G-GIAM", 0.52, 11.1, 8.60, "MailRedDark", x=fuse_halfwidth(11.1) + 0.02)
        side_panel(side, "MAIL", 0.20, 4.95, 6.28, "MailCream", x=2.67)


def fuse_hp(g):
    # panel seams and rivet rows only worth baking into the normal map
    for side in (1, -1):
        for y in (-13.6, -11.6, -9.9, -3.6, -1.0, 3.0, 6.4, 9.0, 11.2):
            V.box(g, (side * (fuse_halfwidth(y) + 0.012), y, 7.5), (0.035, 0.055, 5.5), "MailCreamDirty", bev=0.006)
        for z in (5.05, 10.20):
            V.box(g, (side * 2.60, 1.0, z), (0.035, 26.0, 0.06), "MailCreamDirty", bev=0.006)
        for y0 in (-13.0, -5.5, 2.5):
            for k in range(14):
                z = 5.35 + k * 0.35
                V.box(g, (side * (fuse_halfwidth(y0) + 0.02), y0, z), (0.045, 0.09, 0.09), "MailCreamDirty", bev=0.0)
    # cowl fasteners
    for side in (1, -1):
        for k in range(9):
            a = -0.9 + k * 0.225
            V.box(g, (side * 2.16 * math.cos(a * 0.5), -17.55, COWL_Z + 1.9 * math.sin(a * 0.9)),
                  (0.12, 0.08, 0.12), "BareSteel", bev=0.0)


# --------------------------------------------------------------------------- wings
def wing_at(x):
    f = abs(x) / HALF_SPAN
    return (WING_LE + 0.65 * f * f, WING_CH - 2.45 * f ** 1.6, WING_TH - 0.52 * f ** 1.2, WING_Z + 0.16 * f ** 2)


def control_strip(g, side, x0, x1, chord, defl):
    rings = []
    for k in range(7):
        x = side * (x0 + (x1 - x0) * k / 6)
        yle, ch, th, zc = wing_at(x)
        te = yle + ch
        ca, sa = math.cos(defl), math.sin(defl)
        rings.append([Vector((x, te - 0.03, zc + 0.04)),
                      Vector((x, te + chord * ca, zc - chord * sa + 0.055)),
                      Vector((x, te + chord * ca, zc - chord * sa - 0.055)),
                      Vector((x, te - 0.03, zc - 0.10))])
    g.rings(rings, M(g, "MailCream"), cap0=True, cap1=True)
    # hinge gap line
    ys = []
    for k in range(7):
        x = side * (x0 + (x1 - x0) * k / 6)
        yle, ch, th, zc = wing_at(x)
        ys.append((x, yle + ch - 0.02, zc))
    for i in range(6):
        a, b = ys[i], ys[i + 1]
        V.box(g, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, a[2]), (abs(b[0] - a[0]), 0.10, 0.13),
              M(g, "GlassSeal"), bev=0.01)


def wing(g):
    rings = []
    for x, yle, ch, th, zc in wing_stations():
        rings.append(foil_ring(x, yle, ch, th, zc))
    g.rings(rings, M(g, "MailCream"), cap0=True, cap1=True,
            matfn=lambda i, j: "MailRed" if (i <= 1 or i >= 10) else "MailCream")
    for side in (1, -1):
        # nav lamps in the tip bow
        V.box(g, (side * 24.75, WING_LE + 0.75, WING_Z + 0.20), (0.55, 0.34, 0.30),
              M(g, "NavRed" if side > 0 else "NavGreen"), bev=0.08)
        control_strip(g, side, 14.5, 23.4, 0.85, math.radians(1.0))
        control_strip(g, side, 2.6, 13.6, 0.95, math.radians(4.0))
        # lift strut pair and jury strut
        for (y0, y1) in ((-2.9, -3.6), (-0.1, 0.6)):
            V.tube(g, [(side * 9.7, y0, WING_Z - 0.35), (side * 4.3, y1 - 0.2, 8.35),
                       (side * 1.45, y1, 4.92)], 0.145, M(g, "MailCream"), 8, fillet=0.12, fseg=2)
        V.tube(g, [(side * 9.7, -2.9, WING_Z - 0.32), (side * 9.7, -0.25, WING_Z - 0.30)],
               0.055, M(g, "BareSteel"), 6)
        # cabane struts under the wing root
        V.tube(g, [(side * 4.6, -5.9, WING_Z - 0.45), (side * 2.0, -7.6, 10.55)], 0.10, M(g, "MailCream"), 7)
        V.tube(g, [(side * 4.6, -3.6, WING_Z - 0.45), (side * 2.0, -2.0, 10.55)], 0.10, M(g, "MailCream"), 7)


def wing_hp(g):
    for side in (1, -1):
        for x in range(4, 23, 3):
            for y in (-5.4, -2.2, 0.9):
                V.box(g, (side * x, y, WING_Z + 0.58), (0.08, 0.10, 0.10), "MailCreamDirty", bev=0.0)
        V.box(g, (side * 16.4, 1.95, WING_Z + 0.18), (0.10, 0.9, 0.16), "MailCreamDirty", bev=0.0)


# --------------------------------------------------------------------------- tail
def tail(g):
    # fin, rudder and tailplane
    fin = [(14.45, 9.55), (14.20, 10.40), (14.15, 11.35), (14.40, 12.10), (14.90, 12.66),
           (15.55, 12.82), (16.55, 12.78), (16.90, 12.55), (17.00, 11.40), (16.95, 10.15),
           (16.55, 9.45), (15.70, 9.30)]
    V.extrude_profile(g, fin, -0.24, 0.24, M(g, "MailCream"), bev=0.05)
    rudder = [(17.06, 8.85), (17.06, 12.55), (17.45, 12.82), (18.20, 12.60), (18.55, 11.35),
              (18.45, 10.10), (17.95, 9.15), (17.35, 8.80)]
    V.extrude_profile(g, rudder, -0.16, 0.16, M(g, "MailCream"), bev=0.04)
    V.box(g, (0, 17.03, 10.8), (0.14, 0.16, 4.0), M(g, "GlassSeal"), bev=0.01)
    # red fin flash and registration
    V.box(g, (0.0, 16.2, 11.15), (0.485, 1.85, 1.65), M(g, "MailRed"), bev=0.005)
    for side in (1, -1):
        V.box(g, (side * 0.235, 15.15, 10.25), (0.05, 1.2, 0.52), M(g, "MailRedDark"), bev=0.01)
    # tailplane
    rings = []
    for x in (-6.3, -5.9, -4.0, 0.0, 4.0, 5.9, 6.3):
        f = abs(x) / 6.3
        rings.append(foil_ring(x, 13.70, 2.75 - 0.55 * f * f, 0.40 - 0.12 * f, 8.18 + 0.08 * f, n=14))
    g.rings(rings, M(g, "MailCream"), cap0=True, cap1=True)
    for side in (1, -1):
        V.box(g, (side * 4.2, 16.32, 8.22), (3.7, 0.95, 0.15), M(g, "MailCreamDirty"), bev=0.05)
        V.box(g, (side * 4.2, 15.86, 8.22), (3.7, 0.12, 0.17), M(g, "GlassSeal"), bev=0.02)
        V.box(g, (side * 6.1, 15.1, 8.28), (0.35, 0.9, 0.22), M(g, "MailRed"), bev=0.04)
    # elevator trim tab
    V.box(g, (2.6, 16.72, 8.22), (1.7, 0.30, 0.10), M(g, "MailCreamDirty"), bev=0.02)


def fin_text(g):
    def panel(side, body, size, y, z, mat):
        me = V.text_mesh(body, size, resolution=1)
        def mp(co, side=side, y=y, z=z):
            return Vector((side * 0.252, y + co.x, z + co.y))
        fs = g.add_mesh(me, mat, mp)
        g.orient(fs, lambda c, side=side: Vector((side, 0, 0)))
        bpy.data.meshes.remove(me)
    for side in (1, -1):
        panel(side, "G-GIAM", 0.40, 15.55, 11.72, M(g, "MailCream"))


# --------------------------------------------------------------------------- engine
def engine(g):
    # radial cowl shell
    prof = [(1.62, 0.02), (1.92, 0.22), (2.12, 0.55), (2.20, 1.25), (2.18, 2.05),
            (2.02, 2.70), (1.84, 2.95)]
    V.lathe(g, (0, COWL_F, COWL_Z), (0, 1, 0), prof, 24, M(g, "MailRed"))
    V.lathe(g, (0, COWL_F + 0.02, COWL_Z), (0, 1, 0),
            [(1.50, 0.02), (1.56, 0.22), (1.52, 1.6)], 24, M(g, "ExhaustSoot"))
    # crankcase and radial cylinders
    V.lathe(g, (0, COWL_F + 0.25, COWL_Z), (0, 1, 0),
            [(0.55, 0.0), (0.78, 0.15), (0.78, 1.15), (0.50, 1.35)], 18, M(g, "BareSteel"))
    for k in range(7):
        a = 2 * math.pi * k / 7 + 0.22
        cx, cz = 1.24 * math.cos(a), COWL_Z + 1.24 * math.sin(a)
        V.lathe(g, (cx, COWL_F + 0.10, cz), (0, 1, 0),
                [(0.30, 0.02), (0.42, 0.12), (0.44, 0.66), (0.36, 0.78)], 8, M(g, "BareSteel"))
        for fz in (0.22, 0.40, 0.58):
            V.lathe(g, (cx, COWL_F + fz, cz), (0, 1, 0),
                    [(0.46, -0.03), (0.50, 0.0), (0.50, 0.05), (0.46, 0.08)], 8, M(g, "BareSteel"))
    # cooling gill lips around the cowl
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.1
        c = Vector((0, -15.45, COWL_Z))
        n = Vector((math.cos(a), 0, math.sin(a)))
        V.box(g, c + n * 2.19, (0.55, 0.34, 0.14), M(g, "MailRedDark"),
              rot=Matrix.Rotation(-a, 3, "Y"), bev=0.03)
    # spinner and propeller
    V.lathe(g, (0, -18.15, COWL_Z), (0, -1, 0),
            [(0.10, -0.95), (0.30, -0.72), (0.50, -0.40), (0.58, -0.10), (0.60, 0.18)],
            20, M(g, "MailRed"))
    blade(g)
    # exhaust stacks and soot
    for side in (1, -1):
        V.tube(g, [(side * 1.45, COWL_F + 0.6, 6.35), (side * 1.95, -14.6, 6.15),
                   (side * 2.10, -12.7, 6.05)], 0.13, M(g, "ExhaustSoot"), 8, fillet=0.10, fseg=3)
        V.tube(g, [(side * 1.40, COWL_F + 0.5, 9.05), (side * 1.90, -14.7, 8.95),
                   (side * 2.05, -13.1, 8.85)], 0.10, M(g, "ExhaustSoot"), 7, fillet=0.10, fseg=2)
    # intake lip and carburettor scoop under the cowl
    V.box(g, (0.0, -16.3, 5.62), (1.15, 2.1, 0.65), M(g, "MailRedDark"), bev=0.16)
    V.box(g, (0.0, -17.32, 5.66), (0.85, 0.12, 0.38), M(g, "ExhaustSoot"), bev=0.05)


def blade(g):
    for k in range(3):
        ang = math.radians(30 + k * 120)
        ca, sa = math.cos(ang), math.sin(ang)
        rings = []
        for t, r, ch, th in ((0.0, 0.42, 0.42, 0.30), (0.18, 1.40, 0.72, 0.20), (0.45, 2.55, 0.78, 0.13),
                             (0.75, 3.45, 0.64, 0.09), (0.94, 4.02, 0.46, 0.06), (1.0, 4.14, 0.22, 0.04)):
            pitch = math.radians(28 - 14 * t)
            cp, sp = math.cos(pitch), math.sin(pitch)
            pts = []
            for j in range(8):
                a = 2 * math.pi * j / 8
                u = 0.5 * ch * math.cos(a)
                w = 0.5 * th * math.sin(a)
                x = r * ca - u * cp * sa
                z = COWL_Z + r * sa + u * cp * ca
                y = -18.05 + w + u * sp
                pts.append(Vector((x, y, z)))
            rings.append(pts)
        g.rings(rings, M(g, "PropBlack"), cap0=True, cap1=True,
                matfn=lambda i, j: "PropTip" if i >= 4 else "PropBlack")


# --------------------------------------------------------------------------- cabin
def cabin(g):
    fl = M(g, "CockpitFloor")
    V.box(g, (0, 1.0, 4.98), (4.2, 22.0, 0.14), fl, bev=0.03)
    V.box(g, (0, 1.0, 4.80), (4.4, 22.2, 0.18), M(g, "InteriorDark"), bev=0.04)
    # instrument panel and glare shield
    V.box(g, (0, -10.55, 8.60), (3.7, 0.38, 1.45), M(g, "InstrumentBlack"), bev=0.10)
    V.box(g, (0, -10.90, 9.20), (3.9, 0.60, 0.22), M(g, "CockpitFloor"), bev=0.05)
    for side in (-1, 1):
        for k in range(3):
            V.box(g, (side * (0.55 + k * 0.42), -10.77, 8.75 + (k % 2) * 0.36),
                  (0.28, 0.10, 0.28), M(g, "GaugeFace"), bev=0.06)
    # two front seats and a rear bench
    for side in (-1, 1):
        V.box(g, (side * 0.95, -7.3, 6.05), (1.05, 0.80, 0.30), M(g, "Leather"), bev=0.10)
        V.box(g, (side * 0.95, -6.88, 6.92), (1.05, 0.26, 1.55), M(g, "Leather"), bev=0.12)
        V.box(g, (side * 0.95, -6.00, 6.05), (0.24, 0.75, 0.10), M(g, "BareSteel"), bev=0.02)
    V.box(g, (0.0, 2.4, 5.95), (4.05, 0.65, 0.28), M(g, "CockpitGrey"), bev=0.10)
    V.box(g, (0.0, 2.82, 6.80), (4.05, 0.22, 1.45), M(g, "CockpitGrey"), bev=0.12)
    # yoke columns and control wheels
    for side in (-1, 1):
        V.tube(g, [(side * 0.92, -9.4, 5.55), (side * 0.92, -10.25, 6.25)], 0.08, M(g, "BareSteel"), 6)
        V.lathe(g, (side * 0.92, -10.25, 6.35), (0, 1, 0), [(0.13, 0.0), (0.34, 0.12), (0.34, 0.20)], 12,
                M(g, "InstrumentBlack"))
    # cabin side trim and rear bulkhead
    V.box(g, (0.0, 8.55, 7.4), (4.0, 0.16, 3.9), M(g, "CockpitGrey"), bev=0.04)
    # two mail sacks on the floor (visible through the doorway)
    for i, (x, y, r) in enumerate(((1.1, 6.2, 0.12), (-0.8, 6.9, -0.2))):
        V.box(g, (x, y, 5.55), (1.0, 1.2, 0.95), M(g, "CanvasBag"), rot=Matrix.Rotation(r, 3, "Z"), bev=0.22)
        V.box(g, (x, y, 6.04), (0.62, 0.72, 0.10), M(g, "CanvasBagRed"), bev=0.03)


def cabin_hp(g):
    V.box(g, (0, 1.0, 4.9), (4.2, 22.0, 0.12), "CockpitFloor", bev=0.0)
    for side in (-1, 1):
        for k in range(4):
            V.box(g, (side * 1.55, -6.5 + k * 2.1, 7.85), (0.10, 0.18, 0.18), "BareSteel", bev=0.0)


# --------------------------------------------------------------------------- floats
FLOAT_SECTIONS = [
    (-10.35, 0.38, 0.06, 0.34), (-9.65, 0.34, 0.40, 0.52), (-8.85, 0.15, 0.72, 0.72),
    (-7.60, -0.72, 1.02, 0.84), (-5.50, -1.17, 1.16, 0.86), (-2.00, -1.24, 1.20, 0.87),
    (1.95, -1.25, 1.20, 0.88), (2.30, -0.56, 1.18, 0.89), (5.00, -0.68, 1.16, 0.90),
    (9.00, -0.78, 1.10, 0.92), (12.5, -0.78, 0.98, 0.94), (15.0, -0.55, 0.76, 0.98),
    (16.6, -0.22, 0.48, 1.02), (17.55, 0.06, 0.14, 1.06),
]


def float_ring(xc, y, zbot, hw, ztop):
    dz = max(ztop - zbot, 0.02)
    pts = [(0.0, ztop + 0.035), (hw * 0.55, ztop + 0.015), (hw * 0.93, ztop - 0.10),
           (hw, ztop - 0.30), (hw * 0.97, zbot + 0.38 * dz), (hw * 0.72, zbot + 0.11 * dz),
           (hw * 0.26, zbot + 0.01), (0.0, zbot - 0.05)]
    out = [Vector((xc + x, y, z)) for x, z in pts]
    out += [Vector((xc - x, y, z)) for x, z in reversed(pts[1:-1])]
    return out


def float_body(g, xc):
    rings = [float_ring(xc, y, zb, hw, zt) for y, zb, hw, zt in FLOAT_SECTIONS]
    g.rings(rings, M(g, "FloatAlu"), cap0=True, cap1=True)
    # keel and chine strips
    V.box(g, (xc, 3.8, -1.30), (0.30, 26.0, 0.16), M(g, "FloatAluDull"), bev=0.04)
    for side in (1, -1):
        V.box(g, (xc + side * 1.00, -3.0, -0.82), (0.12, 17.0, 0.14), M(g, "FloatAluDull"), bev=0.03)
        V.box(g, (xc + side * 0.98, 8.5, -0.86), (0.12, 12.0, 0.13), M(g, "FloatAluDull"), bev=0.03)
    # deck hatches, walkway treads and cleats
    for y in (-6.8, 5.2, 11.4, 15.1):
        V.box(g, (xc, y, 0.90), (0.72, 0.95, 0.06), M(g, "FloatAluDull"), bev=0.03)
        V.box(g, (xc, y, 0.94), (0.10, 0.75, 0.04), M(g, "BareSteel"), bev=0.01)
    for y in (-2.0, 2.2, 4.2, 6.2):
        V.box(g, (xc, y, 0.905), (0.54, 0.42, 0.035), M(g, "FloatAluDull"), bev=0.01)
    for y in (-7.2, 15.7):
        V.box(g, (xc, y, 0.94), (0.16, 0.9, 0.18), M(g, "BareSteel"), bev=0.03)
        V.box(g, (xc, y, 1.05), (0.62, 0.18, 0.14), M(g, "BareSteel"), bev=0.03)
    # water rudder
    V.box(g, (xc, 17.05, -0.34), (0.10, 0.85, 0.85), M(g, "FloatAluDull"), bev=0.03)
    V.box(g, (xc, 16.55, 0.40), (0.12, 0.16, 0.85), M(g, "BareSteel"), bev=0.02)
    V.tube(g, [(xc, 16.55, 0.62), (xc, 13.6, 0.92)], 0.035, M(g, "BareSteel"), 5)
    # bow bumper / mooring eye
    V.box(g, (xc, -10.15, 0.38), (0.22, 0.30, 0.42), M(g, "Rubber"), bev=0.07)
    V.tube(g, [(xc, -9.9, 0.55), (xc, -10.25, 0.55)], 0.09, M(g, "BareSteel"), 6)


def floats_rig(g):
    # spreader bars
    for y in (-4.3, 5.4):
        V.tube(g, [(-3.1, y, 0.92), (3.1, y, 0.92)], 0.105, M(g, "FloatAluDull"), 8)
        V.box(g, (0, y, 0.95), (2.1, 0.34, 0.22), M(g, "FloatAluDull"), bev=0.06)
    # N struts from each float to the fuselage
    for side in (1, -1):
        for (y0, y1) in ((-5.4, -3.1), (6.3, 4.6)):
            V.tube(g, [(side * 3.1, y0, 0.90), (side * 1.55, (y0 + y1) / 2 - 0.1, 2.65),
                       (side * 1.32, y1, 4.72)], 0.145, M(g, "StrutMetal"), 8, fillet=0.08, fseg=2)
            V.tube(g, [(side * 3.1, y1, 0.90), (side * 1.55, (y0 + y1) / 2 + 0.1, 2.65),
                       (side * 1.32, y0, 4.72)], 0.125, M(g, "StrutMetal"), 8, fillet=0.08, fseg=2)
            V.box(g, (side * 1.52, (y0 + y1) / 2, 2.66), (0.34, 0.28, 0.34), M(g, "StrutMetal"), bev=0.05)
        # bracing wires
        V.tube(g, [(side * 3.06, -3.6, 0.98), (side * 1.40, 4.9, 4.55)], 0.022, M(g, "BareSteel"), 4)
        V.tube(g, [(side * 3.06, 4.9, 0.98), (side * 1.40, -3.6, 4.55)], 0.022, M(g, "BareSteel"), 4)
        # mooring cleat lines, sagging to the water
        for y, z0 in ((-7.4, 0.95), (15.6, 0.95)):
            V.tube(g, [(side * 3.1, y, z0), (side * 3.35, y - 1.1, 0.55), (side * 3.5, y - 2.0, 0.02),
                       (side * 3.2, y - 2.7, -0.10)], 0.060, M(g, "Rope"), 5, fillet=0.5, fseg=2)
            V.lathe(g, (side * 3.1, y, z0 + 0.12), (0, 0, 1), [(0.20, 0.0), (0.22, 0.06), (0.18, 0.1)], 10,
                    M(g, "BareSteel"))
    # coil of mooring line on the starboard float deck
    for k in range(3):
        r = 0.46 - k * 0.11
        V.tube(g, [(3.1 + r * math.cos(a), -8.6 + r * math.sin(a), 0.98 + k * 0.035)
                   for a in [2 * math.pi * i / 14 for i in range(15)]], 0.045, M(g, "Rope"), 5)
    # a mail sack waiting on the port float walkway
    V.box(g, (-3.05, 1.7, 1.22), (0.85, 1.0, 0.75), M(g, "CanvasBag"), rot=Matrix.Rotation(0.2, 3, "Z"), bev=0.20)
    V.box(g, (-3.05, 1.7, 1.60), (0.52, 0.62, 0.08), M(g, "CanvasBagRed"), bev=0.02)


def float_hp(g):
    for xc in (-3.1, 3.1):
        for y in range(-8, 16, 2):
            V.box(g, (xc, y, 0.9), (0.06, 0.10, 0.06), "BareSteel", bev=0.0)
        V.box(g, (xc, 2.05, -0.95), (2.10, 0.10, 0.20), "FloatAluDull", bev=0.0)


# --------------------------------------------------------------------------- collision / build
def collision():
    bm = bmesh.new()
    pts = []
    for y in (-19.2, -17.2, -12.0, -6.0, 0.0, 6.0, 11.0, 16.0, 18.8):
        for x in (-2.6, -1.2, 0.0, 1.2, 2.6):
            pts += [(x, y, 4.7), (x, y, 10.9)]
        pts.append((0.0, y, 13.0))
    for x in (-25.0, -20.0, -10.0, 0.0, 10.0, 20.0, 25.0):
        for y in (-6.6, -2.0, 2.0):
            pts += [(x, y, 10.2), (x, y, 11.6)]
    for xc in (-3.1, 3.1):
        for y in (-10.0, -5.0, 0.0, 2.0, 6.0, 12.0, 17.0):
            pts += [(xc - 1.0, y, -1.2), (xc + 1.0, y, -1.2), (xc, y, 0.9)]
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vj = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vj:
        bmesh.ops.delete(bm, geom=vj, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(NAME + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(NAME + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def build():
    unwrap = smart_unwrap

    def fuselage(g):
        fuselage_shell(g)
        canopy(g)
        window_frames(g)
        cheatline(g)
        doors(g)
        fuse_details(g)
        livery_text(g)

    def wings(g):
        wing(g)

    def tail_assembly(g):
        tail(g)
        fin_text(g)

    def engine_all(g):
        engine(g)

    def glass(g):
        window_glass(g)

    def cabin_all(g):
        cabin(g)

    def floats(g):
        for xc in (-3.1, 3.1):
            float_body(g, xc)

    def rig(g):
        floats_rig(g)

    af = V.build_set("Airframe", [
        (NAME + "_Fuselage_LOD0", fuselage),
        (NAME + "_Wings_LOD0", wings),
        (NAME + "_Tail_LOD0", tail_assembly),
        (NAME + "_Engine_LOD0", engine_all),
        (NAME + "_Glass_LOD0", glass),
        (NAME + "_Cabin_LOD0", cabin_all),
    ], unwrap, "MI_MailSeaplane_Airframe", angle=58)
    fl = V.build_set("Floats", [
        (NAME + "_Floats_LOD0", floats),
        (NAME + "_FloatRig_LOD0", rig),
    ], unwrap, "MI_MailSeaplane_Floats", angle=54)

    hps = [
        V.build_hp(NAME + "_Fuselage_HP", [fuselage, fuse_hp], bevel=dict(width=0.010, segments=1, angle=42)),
        V.build_hp(NAME + "_Wings_HP", [wings, wing_hp], bevel=dict(width=0.010, segments=1, angle=42)),
        V.build_hp(NAME + "_Tail_HP", [tail_assembly], bevel=dict(width=0.010, segments=1, angle=42)),
        V.build_hp(NAME + "_Engine_HP", [engine_all], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(NAME + "_Glass_HP", [glass]),
        V.build_hp(NAME + "_Cabin_HP", [cabin_all, cabin_hp], bevel=dict(width=0.008, segments=1, angle=40)),
        V.build_hp(NAME + "_Floats_HP", [floats, float_hp], bevel=dict(width=0.010, segments=1, angle=42)),
        V.build_hp(NAME + "_FloatRig_HP", [rig], bevel=dict(width=0.008, segments=1, angle=40)),
    ]
    col = collision()

    atts = {}
    for name, p in {
        "ATT_Waterline": (0.0, 0.0, 0.0),
        "ATT_Mooring_L": (-3.1, -7.4, 1.0),
        "ATT_Mooring_R": (3.1, -7.4, 1.0),
        "ATT_MailDoor": (-2.72, 5.0, 7.05),
        "ATT_Door_Cabin": (2.72, -8.35, 7.0),
        "ATT_Prop": (0.0, -18.7, COWL_Z),
        "ATT_PilotSeat": (-0.95, -7.3, 6.2),
        "ATT_Seat_02": (0.95, -7.3, 6.2),
        "ATT_Seat_03": (-1.1, 2.4, 6.05),
        "ATT_Seat_04": (1.1, 2.4, 6.05),
        "ATT_FuelCap_L": (-2.05, -12.9, 10.62),
        "ATT_FuelCap_R": (2.05, -12.9, 10.62),
        "ATT_CargoDoor": (2.72, 7.55, 6.70),
        "ATT_TieDown_L": (-24.0, -3.0, 10.3),
        "ATT_TieDown_R": (24.0, -3.0, 10.3),
    }.items():
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts[name] = e

    lod0 = af + fl
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, 0.0))
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts.values():
        e.location = e.location + off

    meshes = []
    for objs, s in ((af, "Airframe"), (fl, "Floats")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes.append({"object": col})

    wear = {"rust": 0.05, "rust_color": (0.34, 0.27, 0.20), "rust_rough": 0.82, "rust_length": 0.55,
            "rust_fingers": 5, "salt": 0.26, "salt_range": (0.30, 0.82), "salt_color": (0.70, 0.69, 0.64),
            "edge_color": (0.80, 0.80, 0.77), "edge_metal": 0.0, "ao_strength": 0.12}
    sets = [
        {"name": TEX, "set": "Airframe", "size": 4096, "wet": True, "wet_darken": 0.26, "wet_gloss": 0.30,
         "wet_streaks": 0.45, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.8,
         "wear": dict(wear, edge=0.30, salt=0.30)},
        {"name": TEX, "set": "Floats", "size": 2048, "wet": True, "wet_darken": 0.30, "wet_gloss": 0.32,
         "wet_streaks": 0.55, "cage_extrusion": 0.012, "max_ray_distance": 0.018, "ao_distance": 1.6,
         "wear": dict(wear, edge=0.34, salt=0.42, rust=0.10, edge_metal=0.15)},
    ]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]

    return {
        "name": NAME,
        "budget": "small_craft",
        "tris": 20000,
        "tier": "standard",
        "dims_m": (16.7, 12.7, 4.67),
        "size_note": "X span 16.7 m matches the WorldConfig 50-stud beam; Y 12.7 m is inside the 39-stud length. "
                     "Z is the fin top above the float waterline; origin is the waterline, not the bbox base.",
        "origin": "free",
        "sets": sets,
        "meshes": meshes,
        "attachments": list(atts.values()),
        "bake_samples": 16,
        "closeups": [
            {"name": "engine_prop", "target": at((0.0, -16.4, 8.6)), "dist": 9, "az": 24, "el": 10},
            {"name": "cockpit", "target": at((0.0, -9.9, 10.5)), "dist": 8, "az": 330, "el": 8},
            {"name": "mail_door", "target": at((-2.62, 5.0, 7.0)), "dist": 7, "az": 272, "el": 6},
            {"name": "tail_fin", "target": at((0.0, 16.2, 11.3)), "dist": 8, "az": 152, "el": 12},
            {"name": "float_strut", "target": at((2.6, -3.0, 2.9)), "dist": 8, "az": 70, "el": 8},
            {"name": "cabin_windows", "target": at((2.6, 0.8, 8.35)), "dist": 7, "az": 86, "el": 4},
        ],
        "waivers": {
            "LOD UV layout": "collapse decimation shifts small lettering, rivet and rope islands at LOD1/LOD2; they are "
                             "only seen far off and LOD0 is unchanged.",
            "geometry": "LOD2 collapse leaves a few slivers in the rope, wire and antenna tubes (not visible at LOD2 "
                        "distance); LOD0 and LOD1 are clean.",
            "texture sets": "docs/12 gives 2 sets; the 20k small_craft class ceiling is used because no aircraft class "
                            "with 2 sets exists. LOD0 stays at the row's two sets.",
        },
    }


if __name__ == "__main__":
    import rbxkit
    rbxkit.run_build(build)
