"""H5 M_Bld_Hospital: Gale Isles Cottage Hospital (docs/12 row, 05, 10).

Two-storey Cornish cottage hospital, 30 x 15 m: whitewashed render over a granite plinth, grey slate hipped roof with
two chimney stacks, 33 white sash windows and a central entrance porch. East ambulance bay: a lean-to slate canopy on
galvanised steel posts over a concrete apron, with a double door, push bars and a parked stretcher trolley. Rear: a
granite quay wall, ramp with handrails and a 10 m floating pontoon (fenders, cleats, lifebuoy, lamp) at water level.
Signage is invented: a green/white "GALE ISLES / COTTAGE HOSPITAL" board with a heart/wave roundel, a blue H at the
ambulance bay, HOSPITAL PONTOON at the berth. No red cross anywhere.

Frame: metres x 3 = studs. The block floor is z 0; the pontoon floats sit on the waterline at z -2.35, and the spec
origin is base on that waterline (offset +2.35), so placement at sea level puts the quay wall and pontoon right.
Front (entrance) faces -Y, the water and pontoon +Y, the ambulance bay +X.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/buildings/M_Bld_Hospital/build.py \
      --out-root build/prod/M_Bld_Hospital --steps build,lod,validate,export,turntable
    python3 art/source/buildings/M_Bld_Hospital/maketex.py     # own Hospital Details set (2048)
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import geo  # noqa: E402
from geo import Part, Wall, trim  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
NAME = "M_Bld_Hospital"
TEX = G + "assets/textures/"

D = {  # T_Hospital_Details atlas (maketex.D) - own set
    "Sign": (0.00, 0.80, 1.00, 1.00), "BaySign": (0.00, 0.60, 0.20, 0.80),
    "Roundel": (0.20, 0.60, 0.40, 0.80), "PontSign": (0.42, 0.60, 0.80, 0.80),
    "Date": (0.82, 0.60, 1.00, 0.70), "WindowCard": (0.80, 0.40, 1.00, 0.60),
    "Glass": (0.00, 0.40, 0.20, 0.60), "Lit": (0.21, 0.40, 0.41, 0.60),
    "DoorE": (0.42, 0.40, 0.60, 0.60), "DoorA": (0.61, 0.40, 0.79, 0.60),
    "Granite": (0.00, 0.20, 0.20, 0.40), "Conc": (0.21, 0.20, 0.41, 0.40),
    "White": (0.42, 0.20, 0.62, 0.40), "Steel": (0.63, 0.20, 0.79, 0.40),
    "Lead": (0.80, 0.20, 0.90, 0.40), "Ridge": (0.91, 0.20, 1.00, 0.40),
    "Terra": (0.00, 0.00, 0.20, 0.20), "Green": (0.21, 0.00, 0.41, 0.20),
    "Blue": (0.42, 0.00, 0.62, 0.20), "Black": (0.63, 0.00, 0.79, 0.20),
    "Rubber": (0.80, 0.00, 1.00, 0.20),
}


def rect(name, w, h, pad=0.002):
    u0, v0, u1, v1 = D[name]
    return ("rect", u0 + pad, v0 + pad, u1 - pad, v1 - pad, w, h)


def strip(name, metres=1.13, pad=0.003):
    u0, v0, u1, v1 = D[name]
    return ("trimreg", u0 + pad, u1 - pad, v0 + pad, v1 - pad, metres)


def region(name, pad=0.004):
    u0, v0, u1, v1 = D[name]
    return (u0 + pad, v0 + pad, u1 - pad, v1 - pad)


def tile_region(name, metres, axis="x"):
    u0, v0, u1, v1 = D[name]
    du, dv = u1 - u0, v1 - v0

    def f(p):
        a = p.x if axis == "x" else p.y
        return (u0 + (a / metres % 1.0) * du, v0 + (p.z / metres % 1.0) * dv)
    return ("fn", f)


def tile_top(name, metres):
    u0, v0, u1, v1 = D[name]
    du, dv = u1 - u0, v1 - v0

    def f(p):
        return (u0 + (p.x / metres % 1.0) * du, v0 + (p.y / metres % 1.0) * dv)
    return ("fn", f)


GRAN = ("worldreg", *region("Granite"), 2.13, 2.13, 0.0, 0.0)
CONC = ("worldreg", *region("Conc"), 2.13, 2.13, 0.13, 0.29)
WHITE = strip("White", 1.13)
GREEN = strip("Green", 1.13)
BLUE = strip("Blue", 1.13)
BLACK = strip("Black", 0.83)
STEEL = strip("Steel", 1.13)
LEAD = strip("Lead", 1.13)
RIDGESTRIP = strip("Ridge", 1.13)
TERRA = strip("Terra", 0.73)
RUBBER = strip("Rubber", 0.67)
SLATE = ("tile", 2.0)
PD = [("trim", 0.504, 0.621, 2.0), ("trim", 0.629, 0.746, 2.0),
      ("trim", 0.754, 0.871, 2.0), ("trim", 0.879, 0.996, 2.0)]
PF = ("trim", 0.004, 0.121, 2.0)
PTREAD = ("trim", 0.129, 0.146, 1.0)
PRUB = ("trim", 0.254, 0.371, 1.0)

# local frame (metres): block floor at 0, waterline -2.35
XL, XR = -15.0, 15.0
YF, YB = -7.5, 7.5
T = 0.5
EAV = 7.3
RIDGE = 11.55
RX = 9.8
OVH = 0.35
SLAB = 0.16
EX, EY = XR + OVH, YB + OVH
ZE = EAV - OVH * (RIDGE - EAV) / 7.5
ZD = ZE + SLAB
RD = RIDGE + SLAB
WATER = -2.35
DECK = -1.85
ZOFF = -WATER

CAN_X1 = 20.2
CAN_Y = 3.2
PORCH_X = 2.1
PORCH_Y = -10.05
GARDEN_Y = -11.4


def flat(name, k=0.0006):
    """LOD2: map every face to a tiny patch in one atlas region (non-zero UV area, flat colour)."""
    u0, v0, u1, v1 = D[name]
    cu, cv = (u0 + u1) / 2, (v0 + v1) / 2

    def f(p):
        return (cu + (p.x + p.y) * k, cv + (p.y + p.z) * k)
    return ("fn", f)


def soft_decimate(obj, ratio):
    """Decimate in place, keeping whatever the collapse can reach (never raising)."""
    mod = obj.modifiers.new("Decimate", 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    deps = bpy.context.evaluated_depsgraph_get()
    new = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    obj.modifiers.remove(mod)
    if len(new.polygons) == 0:
        bpy.data.meshes.remove(new)
        return
    old = obj.data
    obj.data = new
    bpy.data.meshes.remove(old)
    new.name = obj.name
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(new)
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(new)
    bm.free()
    for poly in obj.data.polygons:
        poly.use_smooth = True


REN_F = ("world", 3.0, 9.0, 0.00, -0.08)
REN_B = ("world", 3.0, 9.0, 0.37, -0.08)
REN_S = ("world", 3.0, 9.0, 0.63, -0.08)
REN_W = ("world", 3.0, 9.0, 0.19, -0.08)


def plane_uv(A, B, C, Dd):
    """UV mode for a slate plane: u along the eave, v up the slope from the eave (2 m tile)."""
    A, B, C, Dd = Vector(A), Vector(B), Vector(C), Vector(Dd)
    em, rm = (A + B) / 2, (C + Dd) / 2
    eu = (B - A).normalized() if (B - A).length > 1e-6 else Vector((1, 0, 0))
    es = (rm - em).normalized() if (rm - em).length > 1e-6 else Vector((0, 1, 0))

    def f(p):
        return ((p - A).dot(eu) / 2.0, (p - em).dot(es) / 2.0)
    return ("fn", f)


def build():
    render, stone, roof, trim_p, sash, glass, lit, doors = (Part("Walls"), Part("Stone"), Part("Roof"),
                                                            Part("Trim"), Part("Sashes"), Part("Glass"),
                                                            Part("LitGlass"), Part("Doors"))
    metal, paint, rubber, conc, signs, furn, pont = (Part("Metal"), Part("Paint"), Part("Rubber"),
                                                    Part("Concrete"), Part("Signs"), Part("Furniture"),
                                                    Part("Pontoon"))
    atts = {}
    front, back = Wall((0, -1, 0), YF), Wall((0, 1, 0), YB)
    west, east = Wall((-1, 0, 0), XL), Wall((1, 0, 0), XR)

    # ------------------------------------------------ openings
    WIN = []       # (wall key, s, sill, w, h, lit)
    # front: s = x
    for x in (-12.2, -8.6, -5.0, 5.0, 8.6, 12.2):
        WIN.append(("front", x, 0.95, 1.15, 1.75, False))
    for x in (-12.2, -8.6, -5.0, 0.0, 5.0, 8.6, 12.2):
        WIN.append(("front", x, 4.55, 1.15, 1.55, x in (-8.6, 5.0)))
    # back: s = -x, y = -s
    for s in (-11.0, -7.0, -3.0, 3.4, 7.0, 11.0):
        WIN.append(("back", s, 0.95, 1.15, 1.75, False))
    for s in (-11.5, -7.0, -2.6, 2.6, 7.0, 11.5):
        WIN.append(("back", s, 4.55, 1.15, 1.55, s in (-7.0, 7.0)))
    # west: s = -y
    for s in (-4.6, 0.0, 4.6):
        WIN.append(("west", s, 0.95, 1.15, 1.75, False))
    for s in (-4.6, 0.0, 4.6):
        WIN.append(("west", s, 4.55, 1.15, 1.55, s == 0.0))
    # east: s = y
    for s in (-5.2, 5.2):
        WIN.append(("east", s, 0.95, 1.15, 1.75, False))
    for s in (-5.0, 0.0, 5.0):
        WIN.append(("east", s, 4.55, 1.15, 1.55, s == 5.0))

    DOORS = [("front", 0.0, 2.6, 3.2, "DoorE"), ("back", 0.0, 2.2, 2.8, "DoorA"),
             ("east", 0.0, 3.4, 3.0, "DoorA")]

    def world_span(key, s0, s1):
        if key == "front":
            return "front", (s0, s1)
        if key == "back":
            return "back", (-s1, -s0)
        if key == "west":
            return "west", (-s1, -s0)
        return "east", (s0, s1)

    def holes_for(key):
        out = []
        for k, s, sill, w, h, _l in WIN:
            if k == key:
                out.append((s - w / 2, s + w / 2, sill, sill + h))
        for k, s, w, h, _n in DOORS:
            if k == key:
                out.append((s - w / 2, s + w / 2, -0.3, h))
        return out

    # ------------------------------------------------ walls (render, real reveals)
    geo.LEVEL = 3
    render.pierced([(XL, 0), (XR, 0), (XR, EAV), (XL, EAV)], "y", YF, YF + T, holes_for("front"), REN_F)
    render.pierced([(XL, 0), (XR, 0), (XR, EAV), (XL, EAV)], "y", YB - T, YB, holes_for("back"), REN_B)
    render.pierced([(YF, 0), (YB, 0), (YB, EAV), (YF, EAV)], "x", XL, XL + T, holes_for("west"), REN_W)
    render.pierced([(YF, 0), (YB, 0), (YB, EAV), (YF, EAV)], "x", XR - T, XR, holes_for("east"), REN_S)

    # ------------------------------------------------ granite plinth (sloped, door gaps)
    PL = [(0.0, 0.0), (0.10, 0.0), (0.10, 0.62), (0.0, 0.8), (-0.015, 0.8), (-0.015, 0.0)]
    front.prism(stone, XL - 0.05, -1.42, PL, GRAN)
    front.prism(stone, 1.42, XR + 0.05, PL, GRAN)
    back.prism(stone, -XR - 0.05, -1.22, PL, GRAN)
    back.prism(stone, 1.22, XR + 0.05, PL, GRAN)
    west.prism(stone, -YB - 0.05, YB + 0.05, PL, GRAN)
    east.prism(stone, -YB - 0.05, -1.82, PL, GRAN)
    east.prism(stone, 1.82, YB + 0.05, PL, GRAN)

    # quoin blocks at the four corners (long/short alternating, 1.5 cm proud)
    for cx, cy, sx, sy in ((XL, YF, 1, -1), (XR, YF, -1, -1), (XL, YB, 1, 1), (XR, YB, -1, 1)):
        z, k = 0.8, 0
        while z + 0.38 <= 3.4:
            lf, ls = (0.55, 0.30) if k % 2 == 0 else (0.30, 0.55)
            # one face along y (front/back) and one along x (side)
            x0, x1 = sorted((cx, cx + sx * lf))
            y0, y1 = sorted((cy, cy + sy * 0.03))
            stone.box((x0, y0, z + 0.008), (x1, y1, z + 0.388), GRAN)
            x0, x1 = sorted((cx, cx + sx * 0.03))
            y0, y1 = sorted((cy, cy + sy * ls))
            stone.box((x0, y0, z + 0.008), (x1, y1, z + 0.388), GRAN)
            z += 0.4
            k += 1

    # ------------------------------------------------ windows
    WALL = {"front": (front, REN_F), "back": (back, REN_B), "west": (west, REN_W), "east": (east, REN_S)}

    def window(key, s, sill, w, h, lit_):
        wall, _m = WALL[key]
        s0, s1 = s - w / 2, s + w / 2
        t0, t1 = sill, sill + h
        f = 0.055
        gmode = GRAN if key in ("front", "back") else GRAN
        geo.LEVEL = 3
        wall.box(stone, s0 - 0.10, s1 + 0.10, -0.02, 0.10, t0 - 0.11, t0, gmode)
        wall.box(stone, s0 - 0.10, s1 + 0.10, 0.10, 0.135, t0 - 0.11, t0 - 0.065, gmode)
        wall.box(stone, s0 - 0.10, s1 + 0.10, -0.01, 0.035, t1, t1 + 0.19, gmode)
        wall.plate(stone, [(s - 0.13, t1 + 0.015), (s + 0.13, t1 + 0.015), (s + 0.10, t1 + 0.185),
                           (s - 0.10, t1 + 0.185)], -0.004, 0.045, gmode)
        o0, o1 = -0.165, -0.075
        for a, b, z0, z1 in ((s0, s0 + f, t0, t1), (s1 - f, s1, t0, t1), (s0 + f, s1 - f, t1 - f, t1),
                             (s0 + f, s1 - f, t0, t0 + 0.055)):
            wall.box(sash, a, b, o0, o1, z0, z1, WHITE)
        zc = t0 + h / 2
        wall.box(sash, s0 + f, s1 - f, o0, o1, zc - 0.032, zc + 0.032, WHITE)
        wall.box(sash, s - 0.014, s + 0.014, -0.155, -0.125, t0 + f, t1 - f, WHITE)
        for zz in (t0 + h * 0.25, t0 + h * 0.75):
            wall.box(sash, s0 + f, s1 - f, -0.155, -0.125, zz - 0.012, zz + 0.012, WHITE)
        if lit_:
            wall.quad(lit, s0 + f, s1 - f, -0.185, t0 + f, t1 - f, rect("Lit", w - 2 * f, h - 2 * f))
        else:
            wall.quad(glass, s0 + f, s1 - f, -0.185, t0 + f, t1 - f, rect("Glass", w - 2 * f, h - 2 * f))
        # white painted reveal lining (thin, keeps the deep reveal bright)
        wall.box(sash, s0 - 0.012, s0 + 0.004, -0.22, -0.02, t0, t1 + 0.004, WHITE)
        wall.box(sash, s1 - 0.004, s1 + 0.012, -0.22, -0.02, t0, t1 + 0.004, WHITE)

    for w in WIN:
        window(*w)

    # ------------------------------------------------ doors
    def door(key, s, w, h, tex):
        wall = WALL[key][0]
        s0, s1 = s - w / 2, s + w / 2
        leaf_h = h - 0.55 if key == "front" else h
        geo.LEVEL = 3
        wall.box(stone, s0 - 0.22, s1 + 0.22, -0.32, 0.08, -0.02, 0.13, GRAN)
        for a, b, z0, z1 in ((s0 - 0.11, s0, 0.10, h + 0.08), (s1, s1 + 0.11, 0.10, h + 0.08),
                             (s0 - 0.11, s1 + 0.11, h, h + 0.12)):
            wall.box(sash, a, b, 0.0, 0.045, z0, z1, WHITE)
        f = 0.075
        for a, b, z0, z1 in ((s0, s0 + f, 0.13, leaf_h), (s1 - f, s1, 0.13, leaf_h),
                             (s0 + f, s1 - f, leaf_h - f, leaf_h), (s0 + f, s1 - f, 0.13, 0.13 + f)):
            wall.box(sash, a, b, -0.22, -0.12, z0, z1, WHITE)
        wall.box(doors, s0 + f, s1 - f, -0.31, -0.23, 0.13 + f, leaf_h - f,
                 rect(tex, w - 2 * f, leaf_h - 0.13 - 2 * f))
        for a, b in ((s0 - 0.004, s0 + 0.012), (s1 - 0.012, s1 + 0.004)):
            wall.box(sash, a, b, -0.30, -0.02, 0.13, h + 0.004, WHITE)
        if key == "front":
            zt0, zt1 = leaf_h + 0.04, h - 0.08
            wall.quad(glass, s0 + f, s1 - f, -0.20, zt0, zt1, rect("Glass", w - 2 * f, zt1 - zt0))
            for xb in (s - w / 4, s, s + w / 4):
                wall.box(sash, xb - 0.012, xb + 0.012, -0.19, -0.165, zt0, zt1, WHITE)
        for xb in (s - 0.10, s + 0.10):
            p0 = wall.world(xb, -0.05, 1.02)
            p1 = wall.world(xb, 0.03, 1.02)
            metal.tube((p0.x, p0.y, p0.z), (p1.x, p1.y, p1.z), 0.032, 8, TERRA)
        if key == "east" and w > 3.0:
            for z0 in (0.95, 1.35):
                p0 = wall.world(s0 + 0.2, 0.06, z0)
                p1 = wall.world(s1 - 0.2, 0.06, z0)
                metal.tube((p0.x, p0.y, p0.z), (p1.x, p1.y, p1.z), 0.028, 8, STEEL)
                for xb in (s0 + 0.28, s1 - 0.28):
                    p2 = wall.world(xb, 0.0, z0)
                    p3 = wall.world(xb, 0.06, z0)
                    metal.tube((p2.x, p2.y, p2.z), (p3.x, p3.y, p3.z), 0.025, 6, STEEL)
            wall.box(rubber, s0 + f, s1 - f, -0.315, -0.30, 0.13, 0.30, strip("Rubber", 0.53))
        atts["ATT_StretcherDoor" if key == "back" else ("ATT_AmbulanceDoor" if key == "east" else "ATT_Entrance")] = \
            wall.world(s, 0.25, 0.12)

    for d in DOORS:
        door(*d)

    # ------------------------------------------------ porch
    PX, PY = PORCH_X, PORCH_Y
    geo.LEVEL = 3
    for side in (-1, 1):
        xa, xb = sorted((side * (PX - 0.30), side * PX))
        render.box_modes((xa, PY, 0.0), (xb, YF, 2.98), {"any": REN_S, "-y": REN_F, "+y": REN_F, "-z": REN_F, "+z": REN_F})
        stone.box((xa - 0.01, PY - 0.02, 0.0), (xb + 0.01, PY + 0.10, 0.35), GRAN)    # plinth return
    render.box_modes((-PX, PY, 2.96), (PX, PY + 0.28, 3.96), {"any": REN_S, "-y": REN_F, "+y": REN_F, "-z": REN_F, "+z": REN_F})                            # lintel / sign head
    # porch floor + steps
    conc.box((-PX + 0.3, PY + 0.05, 0.0), (PX - 0.3, YF, 0.115), CONC)
    stone.box((-1.25, PY - 0.40, 0.0), (1.25, PY + 0.06, 0.115), GRAN)
    stone.box((-1.25, PY - 0.70, 0.0), (1.25, PY - 0.40, 0.075), GRAN)
    # porch ceiling and white soffit
    sash.box((-PX + 0.02, PY + 0.02, 3.89), (PX - 0.02, YF, 3.945), WHITE)
    # porch roof (small hipped slate)
    pa, pb = (-PX - 0.22, PY - 0.24, 4.02), (PX + 0.22, PY - 0.24, 4.02)
    pr, pz = 0.75, 4.62

    def small_roof():
        e1, e2 = Vector((pa[0], pa[1], pa[2])), Vector((pb[0], pb[1], pb[2]))
        r1, r2 = Vector((-pr, (PY + YF) / 2, pz)), Vector((pr, (PY + YF) / 2, pz))
        # front slope
        mode = plane_uv(e1, e2, r1, r2)
        roof.face([e1, e2, r2, r1], mode, outward=(0, 0, 1))
        # back slope
        b1, b2 = Vector((pa[0], YF - 0.02, pa[2] - 0.05)), Vector((pb[0], YF - 0.02, pb[2] - 0.05))
        mode = plane_uv(b1, b2, r1, r2)
        roof.face([b1, b2, r2, r1], mode, outward=(0, 0, 1))
        # hips
        for sg in (-1, 1):
            a = e1 if sg < 0 else e2
            apex = r1 if sg < 0 else r2
            b = b1 if sg < 0 else b2
            mode = plane_uv(a, b, apex, apex)
            roof.face([a, b, apex], mode, outward=(sg, 0, 0))
        # ridge + lead apron
        stone.tube((float(r1.x), float(r1.y), float(r1.z) + 0.04), (float(r2.x), float(r2.y), float(r2.z) + 0.04),
                   0.10, 6, RIDGESTRIP)
        signs.box((-pr, (PY + YF) / 2 - 0.10, pz + 0.02), (pr, YF + 0.03, pz + 0.10), LEAD)
        # fascia
        sash.box((pa[0], pa[1] - 0.02, pa[2] - 0.16), (pb[0], pb[1], pa[2] + 0.02), WHITE)
        for sg in (-1, 1):
            x = pa[0] if sg < 0 else pb[0]
            sash.box((x - 0.02, pa[1] - 0.02, pa[2] - 0.16), (x + 0.02, YF + 0.06, pa[2] + 0.02), WHITE)
    small_roof()
    # main red cross-free sign on the porch head, framed in white
    sy = PY - 0.012
    signs.box((-1.92, sy - 0.035, 3.03), (1.92, sy, 3.83), GREEN)
    signs.face([(-1.86, sy - 0.04, 3.07), (1.86, sy - 0.04, 3.07), (1.86, sy - 0.04, 3.79), (-1.86, sy - 0.04, 3.79)],
               rect("Sign", 3.72, 0.72), outward=(0, -1, 0))
    for a, b, z0, z1 in ((-1.95, -1.88, 3.0, 3.86), (1.88, 1.95, 3.0, 3.86), (-1.95, 1.95, 3.86, 3.93),
                         (-1.95, 1.95, 2.96, 3.03)):
        signs.box((a, PY - 0.05, z0), (b, PY - 0.01, z1), WHITE)
    atts["ATT_HospitalSign"] = Vector((0.0, PY - 0.10, 3.45))
    # trough lamp over the sign
    metal.box((-0.42, PY - 0.30, 3.94), (0.42, PY - 0.10, 4.02), STEEL)
    lit.box((-0.38, PY - 0.285, 3.925), (0.38, PY - 0.19, 3.945), rect("Lit", 0.7, 0.1))
    atts["ATT_Lamp_Sign"] = Vector((0.0, PY - 0.26, 3.9))
    # porch wall lamps
    for i, xl in enumerate((-1.42, 1.42)):
        metal.box((xl - 0.055, YF - 0.02, 2.25), (xl + 0.055, YF, 2.45), STEEL)
        metal.box((xl - 0.018, YF - 0.25, 2.40), (xl + 0.018, YF - 0.02, 2.43), STEEL)
        metal.box((xl - 0.15, YF - 0.30, 2.46), (xl + 0.15, YF - 0.20, 2.52), STEEL)
        metal.box((xl - 0.09, YF - 0.28, 2.30), (xl + 0.09, YF - 0.22, 2.46), STEEL)
        lit.box((xl - 0.075, YF - 0.285, 2.32), (xl + 0.075, YF - 0.245, 2.45), rect("Lit", 0.14, 0.12))
        atts["ATT_Lamp_Porch_%02d" % (i + 1)] = Vector((xl, YF - 0.28, 2.33))

    # ------------------------------------------------ hip roof
    fx0, fx1, fy = -EX, EX, -EY
    bx0, bx1, by = -EX, EX, EY
    zt, zr = ZD, RD
    quads = [
        (((fx0, fy, zt), (fx1, fy, zt), (-RX, 0, zr), (RX, 0, zr)), (0, -1, 0)),
        (((bx0, by, zt), (bx1, by, zt), (-RX, 0, zr), (RX, 0, zr)), (0, 1, 0)),
        (((fx0, fy, zt), (bx0, by, zt), (-RX, 0, zr), (-RX, 0, zr)), (-1, 0, 0)),
        (((fx1, fy, zt), (bx1, by, zt), (RX, 0, zr), (RX, 0, zr)), (1, 0, 0)),
    ]
    for (A, B, C, Dd), out in quads:
        mode = plane_uv(A, B, C, Dd)
        roof.face([A, B, Dd, C] if C != Dd else [A, B, C], mode, outward=(0, 0, 1))
        # sarking underside (white), 16 cm below
        low = [Vector((p[0], p[1], p[2] - 0.16)) for p in (A, B, Dd, C)] if C != Dd else \
            [Vector((p[0], p[1], p[2] - 0.16)) for p in (A, B, C)]
        sash.face(low, WHITE, outward=(0, 0, -1))
    # slate course tails (raised lips every 0.25 m, following each hip plane)
    def courses(A, B, C, Dd):
        A, B, C, Dd = Vector(A), Vector(B), Vector(C), Vector(Dd)
        em, rm = (A + B) / 2, (C + Dd) / 2
        L = (rm - em).length
        n = max(4, int(L / 0.25))
        mode = plane_uv(A, B, C, Dd)
        for k in range(1, n):
            t = k / n
            dt = 0.045 / L

            def P(tt, u):
                return A.lerp(B, u).lerp(C.lerp(Dd, u), tt)
            p0, p1, p2, p3 = P(t - dt, 0), P(t - dt, 1), P(t, 1), P(t, 0)
            q0, q1, q2, q3 = [Vector((p.x, p.y, p.z + 0.012)) for p in (p0, p1, p2, p3)]
            roof.face([q0, q1, q2, q3], mode, outward=(0, 0, 1))
            roof.face([p2, p3, q3, q2], SLATE, outward=(0, 0, 1))

    for (A, B, C, Dd), out in quads:
        courses(A, B, C, Dd)

    # white string course between the storeys and a moulded eaves cornice
    sash.box((XL, YF - 0.05, 3.50), (-PX, YF, 3.66), WHITE)
    sash.box((PX, YF - 0.05, 3.50), (XR, YF, 3.66), WHITE)
    sash.box((XL, YB, 3.50), (XR, YB + 0.05, 3.66), WHITE)
    sash.box((XL - 0.05, YF, 3.50), (XL, YB, 3.66), WHITE)
    sash.box((XR, YF, 3.50), (XR + 0.05, YB, 3.66), WHITE)
    for y, out in ((YF, -1), (YB, 1)):
        sash.box((XL, y + out * 0.0, 6.96), (XR, y + out * 0.07, 7.16), WHITE)
        sash.box((XL, min(y, y + out * 0.075), 6.90), (XR, max(y, y + out * 0.075), 6.96), WHITE)
    for x, out in ((XL, -1), (XR, 1)):
        sash.box((x + out * 0.0, YF, 6.96), (x + out * 0.07, YB, 7.16), WHITE)
        sash.box((min(x, x + out * 0.075), YF, 6.90), (max(x, x + out * 0.075), YB, 6.96), WHITE)
    for i in range(24):
        xd = XL + 0.7 + i * 1.22
        sash.box((xd - 0.07, YF - 0.10, 6.82), (xd + 0.07, YF, 6.94), WHITE)

    # ridge and hip rolls with joint collars
    stone.tube((-RX, 0, RD + 0.03), (RX, 0, RD + 0.03), 0.135, 6, RIDGESTRIP)
    for x in [-RX + 0.9 * i for i in range(1, 22)]:
        stone.tube((x - 0.018, 0, RD + 0.02), (x + 0.018, 0, RD + 0.02), 0.16, 6, RIDGESTRIP)
    for A, B, C in (((fx0, fy, zt), (-RX, 0, zr), (-RX, 0, zr)), ((bx0, by, zt), (-RX, 0, zr), (-RX, 0, zr)),
                    ((fx1, fy, zt), (RX, 0, zr), (RX, 0, zr)), ((bx1, by, zt), (RX, 0, zr), (RX, 0, zr))):
        p0, p1 = Vector((A[0], A[1], A[2] + 0.02)), Vector((C[0], C[1], C[2] + 0.02))
        stone.tube(tuple(p0), tuple(p1), 0.13, 6, RIDGESTRIP)
        for t in (0.25, 0.5, 0.75):
            q = p0.lerp(p1, t)
            stone.tube((q.x - 0.012, q.y, q.z), (q.x + 0.012, q.y, q.z), 0.15, 6, RIDGESTRIP)
    # chimney stacks on the ridge
    for xc in (-7.8, 7.8):
        stone.box((xc - 0.58, -0.44, RIDGE - 0.75), (xc + 0.58, 0.44, 13.15), GRAN)
        stone.box((xc - 0.62, -0.48, 12.55), (xc + 0.62, 0.48, 12.72), GRAN)
        stone.box((xc - 0.66, -0.52, 13.13), (xc + 0.66, 0.52, 13.27), GRAN)
        trim_p.box((xc - 0.70, -0.56, 13.27), (xc + 0.70, 0.56, 13.35), trim("Coping"))
        # lead apron round the base
        for sg in (-1, 1):
            y0, y1 = sorted((sg * 0.44, sg * 0.68))
            signs.box((xc - 0.62, y0, RIDGE - 0.02), (xc + 0.62, y1, RIDGE + 0.24), LEAD)
        for i, dx in enumerate((-0.30, 0.0, 0.30)):
            xp = xc + dx
            stone.tube((xp, 0, 13.35), (xp, 0, 13.56), 0.13, 8, TERRA)
            stone.tube((xp, 0, 13.56), (xp, 0, 13.62), 0.155, 8, TERRA)
            lit_ = None
    # eaves fascia, soffit and boxed gutters + downpipes
    zg = ZD - 0.02
    for y, out in ((YF, -1), (YB, 1)):
        sash.box((-EX, y + out * 0.0, zg - 0.22), (EX, y + out * 0.055, zg), WHITE)          # fascia
        sash.box((-EX, min(y, y + out * 0.02), zg - 0.24), (EX, max(y, y + out * 0.02), zg - 0.20), WHITE)
        sash.box((-EX, y + out * 0.02, zg - 0.22), (EX, y + out * 0.34, zg - 0.18), WHITE)  # soffit
    for x, out in ((XL, -1), (XR, 1)):
        sash.box((x + out * 0.0, -EY, zg - 0.22), (x + out * 0.055, EY, zg), WHITE)
        sash.box((x + out * 0.02, -EY, zg - 0.22), (x + out * 0.34, EY, zg - 0.18), WHITE)
    # gutters just outside the fascia
    for y, out in ((YF, -1), (YB, 1)):
        cy = y + out * 0.34
        profile = [(cy - 0.085, zg - 0.20), (cy - 0.085, zg - 0.04), (cy + 0.085, zg - 0.04), (cy + 0.085, zg - 0.20)]
        trim_p.extrude(profile, "x", -EX, EX, trim("Gutter"), caps=False)
    for x, out in ((XL, -1), (XR, 1)):
        cx = x + out * 0.34
        profile = [(cx - 0.085, zg - 0.20), (cx - 0.085, zg - 0.04), (cx + 0.085, zg - 0.04), (cx + 0.085, zg - 0.20)]
        trim_p.extrude(profile, "y", -EY, EY, trim("Gutter"), caps=False)
    # gutter bead + brackets (front / back)
    for y, out in ((YF, -1), (YB, 1)):
        cy = y + out * 0.50
        trim_p.tube((-EX, cy, ZD - 0.02), (EX, cy, ZD - 0.02), 0.012, 5, trim("Gutter"))
        for xb in [(-EX + 0.9 + i * 1.6) for i in range(19)]:
            trim_p.box((xb - 0.03, cy - 0.02, ZD - 0.11), (xb + 0.03, cy + 0.02, ZD - 0.03), trim("Flashing"))
    for x, out in ((XL, -1), (XR, 1)):
        cx = x + out * 0.50
        trim_p.tube((cx, -EY, ZD - 0.02), (cx, EY, ZD - 0.02), 0.012, 5, trim("Gutter"))
        for yb in [(-EY + 0.9 + i * 1.8) for i in range(8)]:
            trim_p.box((cx - 0.02, yb - 0.03, ZD - 0.11), (cx + 0.02, yb + 0.03, ZD - 0.03), trim("Flashing"))
    # downpipes at the four corners, with hopper and shoe
    for x, y, outx, outy in ((XL + 0.5, YF - 0.5, -1, -1), (XR - 0.5, YF - 0.5, 1, -1),
                             (XL + 0.5, YB + 0.5, -1, 1), (XR - 0.5, YB + 0.5, 1, 1)):
        px = x + outx * 0.16
        py = y + outy * 0.16
        trim_p.tube((px, py, 0.20), (px, py, ZD - 0.35), 0.058, 8, trim("Downpipe"))
        trim_p.box((px - 0.10, py - 0.10, ZD - 0.42), (px + 0.10, py + 0.10, ZD - 0.22), trim("Downpipe"))
        trim_p.tube((px, py, ZD - 0.22), (px, py, ZD - 0.08), 0.07, 8, trim("Downpipe"))
        trim_p.tube((px + outx * 0.12, py + outy * 0.12, 0.04), (px, py, 0.22), 0.07, 8, trim("Downpipe"))
        for zz in (1.5, 3.1, 4.7, 6.3):
            trim_p.box((px - 0.08, py - 0.08, zz), (px + 0.08, py + 0.08, zz + 0.055), trim("Flashing"))

    # ------------------------------------------------ ambulance bay: apron, posts, roof, doors
    conc.box((XR - 0.05, -3.6, 0.0), (CAN_X1 + 0.2, 3.6, 0.09), CONC)
    conc.box((XR - 0.05, -3.6, 0.0), (CAN_X1 + 0.2, -3.32, 0.16), CONC)     # kerb
    conc.box((XR - 0.05, 3.32, 0.0), (CAN_X1 + 0.2, 3.6, 0.16), CONC)
    for sy in (-CAN_Y + 0.15, CAN_Y - 0.15):
        metal.box((CAN_X1 - 0.20, sy - 0.11, 0.09), (CAN_X1 - 0.02, sy + 0.11, 4.28), STEEL)
        metal.box((CAN_X1 - 0.30, sy - 0.22, 0.09), (CAN_X1 + 0.08, sy + 0.22, 0.15), STEEL)
        metal.box((CAN_X1 - 0.19, sy - 0.10, 4.16), (CAN_X1 - 0.08, sy + 0.10, 4.30), STEEL)
    # steel ledger on the wall, outer beam, soffit, side boards
    metal.box((XR + 0.01, -CAN_Y, 4.08), (XR + 0.18, CAN_Y, 4.24), STEEL)
    metal.box((CAN_X1 - 0.23, -CAN_Y, 4.22), (CAN_X1 - 0.05, CAN_Y, 4.34), STEEL)
    sash.box((XR + 0.05, -CAN_Y + 0.1, 4.25), (CAN_X1 - 0.12, CAN_Y - 0.1, 4.29), WHITE)
    for sy in (-CAN_Y - 0.02, CAN_Y - 0.02):
        sash.extrude([(XR, 4.25), (CAN_X1 + 0.1, 4.25), (CAN_X1 + 0.1, 4.36), (XR, 4.60)], "y",
                     sy, sy + 0.08, WHITE)
    # lean-to slate roof (slopes down to the outer edge)
    rq = [(XR, -CAN_Y - 0.35, 4.60), (XR, CAN_Y + 0.35, 4.60), (CAN_X1 + 0.35, CAN_Y + 0.35, 4.36),
          (CAN_X1 + 0.35, -CAN_Y - 0.35, 4.36)]
    def lean_uv(p):
        return (p.y / 2.0, (CAN_X1 + 0.35 - p.x) / 2.0)
    roof.face([rq[0], rq[3], rq[2], rq[1]], ("fn", lean_uv), outward=(0, 0, 1))
    signs.box((XR - 0.02, -CAN_Y - 0.37, 4.56), (XR + 0.14, CAN_Y + 0.37, 4.80), LEAD)  # wall flashing
    sash.box((CAN_X1 + 0.34, -CAN_Y - 0.37, 4.18), (CAN_X1 + 0.47, CAN_Y + 0.37, 4.40), WHITE)  # fascia
    trim_p.extrude([(CAN_X1 + 0.44, 4.22), (CAN_X1 + 0.44, 4.32), (CAN_X1 + 0.62, 4.32), (CAN_X1 + 0.62, 4.22)],
                   "y", -CAN_Y - 0.3, CAN_Y + 0.3, trim("Gutter"), caps=False)
    trim_p.tube((CAN_X1 + 0.60, 3.05, 4.24), (CAN_X1 + 0.60, 3.05, 4.32), 0.055, 8, trim("Downpipe"))
    trim_p.tube((CAN_X1 + 0.60, 3.05, 0.2), (CAN_X1 + 0.60, 3.05, 4.32), 0.05, 8, trim("Downpipe"))
    # blue H sign hanging under the outer beam
    signs.box((CAN_X1 - 0.16, -0.52, 3.94), (CAN_X1 + 0.02, 0.52, 4.10), STEEL)
    signs.box((CAN_X1 - 0.07, -0.48, 3.02), (CAN_X1 + 0.07, 0.48, 3.98), BLUE)
    for sg in (-1, 1):
        signs.face([(CAN_X1 + 0.071 * sg, -0.44, 3.06), (CAN_X1 + 0.071 * sg, 0.44, 3.06),
                    (CAN_X1 + 0.071 * sg, 0.44, 3.94), (CAN_X1 + 0.071 * sg, -0.44, 3.94)],
                   rect("BaySign", 0.88, 0.88), outward=(sg, 0, 0))
    atts["ATT_AmbulanceBay"] = Vector((17.2, 0.0, 0.11))
    atts["ATT_AmbulanceSign"] = Vector((CAN_X1 + 0.1, 0.0, 3.5))
    # datestone 1926 above the ambulance door
    signs.box((XR + 0.005, -0.52, 3.06), (XR + 0.055, 0.52, 3.48), strip("Granite", 1.0))
    signs.face([(XR + 0.056, -0.48, 3.10), (XR + 0.056, 0.48, 3.10), (XR + 0.056, 0.48, 3.44),
                (XR + 0.056, -0.48, 3.44)], rect("Date", 0.96, 0.34), outward=(1, 0, 0))
    atts["ATT_DateStone"] = Vector((XR + 0.06, 0.0, 3.27))
    # bulkhead lamp over the ambulance door
    metal.box((XR - 0.02, -0.24, 3.10), (XR + 0.02, 0.24, 3.42), STEEL)
    metal.box((XR - 0.03, -0.19, 3.14), (XR + 0.10, 0.19, 3.38), STEEL)
    lit.box((XR - 0.035, -0.16, 3.16), (XR - 0.025, 0.16, 3.36), rect("Lit", 0.3, 0.2))
    atts["ATT_Lamp_Bay"] = Vector((XR - 0.1, 0.0, 3.25))
    # oxygen cylinders by the door
    for i, yy in enumerate((1.8, 2.15)):
        paint.tube((XR - 0.38, yy, 0.10), (XR - 0.38, yy, 1.25), 0.13, 8, GREEN)
        metal.tube((XR - 0.38, yy, 1.25), (XR - 0.38, yy, 1.33), 0.06, 8, STEEL)
        metal.box((XR - 0.50, yy - 0.16, 0.48), (XR - 0.26, yy + 0.16, 0.54), STEEL)
    # folded stretcher leaning against the wall
    for sx in (-0.18, 0.18):
        metal.tube((XR - 0.85, 2.55 + sx * 0.2, 0.10), (XR - 0.55, 2.55 + sx, 1.85), 0.025, 6, STEEL)
    furn.box((XR - 0.82, 2.42, 0.55), (XR - 0.60, 2.72, 1.55), WHITE)
    furn.box((XR - 0.84, 2.40, 1.30), (XR - 0.58, 2.74, 1.42), BLUE)
    # stretcher trolley under the canopy
    tx, ty = 16.35, -2.25
    for sx in (-0.85, 0.85):
        metal.tube((tx + sx, ty - 0.32, 0.74), (tx + sx, ty + 0.32, 0.74), 0.026, 8, STEEL)
        for sy in (-0.28, 0.28):
            metal.tube((tx + sx, ty + sy, 0.18), (tx + sx, ty + sy, 0.76), 0.026, 8, STEEL)
            metal.tube((tx + sx - 0.02, ty + sy, 0.19), (tx + sx + 0.02, ty + sy, 0.19), 0.075, 8, RUBBER)
    furn.box((tx - 0.88, ty - 0.34, 0.74), (tx + 0.88, ty + 0.34, 0.86), BLUE)
    furn.box((tx - 0.80, ty - 0.30, 0.86), (tx + 0.80, ty + 0.30, 0.92), WHITE)
    furn.box((tx - 0.55, ty - 0.28, 0.92), (tx + 0.45, ty + 0.28, 0.96), GREEN)          # folded blanket
    for sx in (-0.85, 0.85):
        metal.tube((tx + sx, ty - 0.32, 0.74), (tx + sx, ty - 0.32, 1.05), 0.022, 6, STEEL)
        metal.tube((tx + sx, ty - 0.32, 1.05), (tx + sx, ty + 0.32, 1.05), 0.022, 6, STEEL)

    # ------------------------------------------------ rear terrace, quay wall, ramp
    conc.box((-7.0, YB, 0.0), (7.0, 9.5, 0.08), CONC)
    # parapet (gap at the ramp)
    for x0, x1 in ((-7.0, -1.3), (1.3, 7.0)):
        stone.box((x0, 9.38, 0.08), (x1, 9.62, 0.92), GRAN)
        stone.box((x0 - 0.03, 9.35, 0.92), (x1 + 0.03, 9.65, 1.00), GRAN)
    stone.box((-8.2, 9.55, WATER - 0.05), (8.2, 9.9, 0.10), GRAN)                       # quay wall
    stone.box((-8.2, 9.52, 0.10), (8.2, 9.93, 0.18), GRAN)                             # coping
    # ramp: 1.85 m fall over 4.0 m, with landings
    pont.face([( -1.1, 9.30, 0.05), (1.1, 9.30, 0.05), (1.1, 12.55, DECK + 0.05), (-1.1, 12.55, DECK + 0.05)],
              PTREAD, outward=(0, 0, 1))
    pont.face([(-1.1, 9.30, -0.15), (1.1, 9.30, -0.15), (1.1, 12.55, DECK - 0.15), (-1.1, 12.55, DECK - 0.15)],
              PD[0], outward=(0, 0, -1))
    for x0, x1 in ((-1.12, -1.06), (1.06, 1.12)):
        pont.face([(x0, 9.30, 0.05), (x0, 12.55, DECK + 0.05), (x0, 12.55, DECK - 0.15), (x0, 9.30, -0.15)],
                  PD[0], outward=(-1 if x0 < 0 else 1, 0, 0))
    for i in range(0, 14):
        t = i / 13.0
        y = 9.55 + t * 2.7
        z = 0.06 - (y - 9.30) / 3.25 * 1.90
        rubber.face([(-1.05, y - 0.035, z + 0.012), (1.05, y - 0.035, z + 0.012),
                     (1.05, y + 0.035, z + 0.012), (-1.05, y + 0.035, z + 0.012)], RUBBER, outward=(0, 0, 1))
    for sx in (-1.16, 1.16):
        for i in range(4):
            yy = 9.55 + i * 0.92
            zz = 0.05 - (yy - 9.30) / 3.25 * 1.90
            metal.tube((sx, yy, zz), (sx, yy, zz + 1.0), 0.022, 6, STEEL)
        metal.tube((sx, 9.55, 1.06), (sx, 12.4, DECK + 1.06), 0.024, 6, STEEL)
        metal.tube((sx, 9.55, 0.62), (sx, 12.4, DECK + 0.62), 0.022, 6, STEEL)
        metal.tube((sx, 9.55, 0.18), (sx, 12.4, DECK + 0.18), 0.022, 6, STEEL)
    # pontoon: deck on twin stringers and floats
    for i in range(12):
        y0 = 12.62 + i * 0.195
        pont.box((-5.0, y0, DECK - 0.13), (5.0, y0 + 0.175, DECK), PD[i % 4])
    for sy in (-0.9, 0.0, 0.9):
        pont.box((-4.9, 13.75 + sy - 0.10, DECK - 0.35), (4.9, 13.75 + sy + 0.10, DECK - 0.14), PD[0])
    for xf in (-4.2, -2.5, -0.8, 0.9, 2.6, 4.3):
        for yf in (13.05, 14.45):
            pont.box((xf - 0.55, yf - 0.35, WATER), (xf + 0.55, yf + 0.35, DECK - 0.33), PF)
    # cleats
    for xc in (-4.55, -1.55, 1.55, 4.55):
        metal.box((xc - 0.13, 14.55, DECK), (xc + 0.13, 14.85, DECK + 0.05), STEEL)
        metal.tube((xc - 0.18, 14.70, DECK + 0.10), (xc + 0.18, 14.70, DECK + 0.10), 0.032, 6, STEEL)
        metal.tube((xc - 0.16, 14.70, DECK + 0.04), (xc - 0.16, 14.70, DECK + 0.12), 0.026, 5, STEEL)
        metal.tube((xc + 0.16, 14.70, DECK + 0.04), (xc + 0.16, 14.70, DECK + 0.12), 0.026, 5, STEEL)
    # D-fenders on the outer face
    for xf in (-4.4, -2.6, -0.9, 0.9, 2.6, 4.4):
        pont.tube((xf, 14.98, DECK - 0.55), (xf, 14.98, DECK + 0.10), 0.135, 8, PRUB)
        metal.tube((xf, 14.94, DECK - 0.55), (xf, 14.94, DECK - 0.50), 0.05, 5, STEEL)
        metal.tube((xf, 14.94, DECK + 0.05), (xf, 14.94, DECK + 0.10), 0.05, 5, STEEL)
    # hemp mooring line coiled on the deck
    for k in range(3):
        for i in range(12):
            a0 = 2 * math.pi * i / 12 + k * 0.4
            a1 = a0 + 2 * math.pi / 12
            rr = 0.23 - k * 0.045
            paint.tube((-3.55 + rr * math.cos(a0), 14.15 + 0.18 + rr * math.sin(a0), DECK + 0.035 + k * 0.045),
                       (-3.55 + rr * math.cos(a1), 14.15 + 0.18 + rr * math.sin(a1), DECK + 0.035 + k * 0.045),
                       0.025, 6, TERRA)
    # lifebuoy + lamp post at the head of the pontoon
    metal.tube((-4.6, 14.45, DECK), (-4.6, 14.45, DECK + 1.55), 0.035, 6, STEEL)
    nseg = 14
    for i in range(nseg):
        a0, a1 = 2 * math.pi * i / nseg, 2 * math.pi * (i + 1) / nseg
        ro, ri = 0.34, 0.20
        p = [(-4.6 + ro * math.cos(a0), 14.54, DECK + 1.20 + ro * math.sin(a0)),
             (-4.6 + ro * math.cos(a1), 14.54, DECK + 1.20 + ro * math.sin(a1)),
             (-4.6 + ri * math.cos(a1), 14.54, DECK + 1.20 + ri * math.sin(a1)),
             (-4.6 + ri * math.cos(a0), 14.54, DECK + 1.20 + ri * math.sin(a0))]
        q = [(x, 14.66, z) for x, _y, z in p]
        col = BLUE if i % 4 == 0 else WHITE
        furn.face(p, col, outward=(0, -1, 0))
        furn.face(q, col, outward=(0, 1, 0))
        for e0, e1 in ((0, 1), (1, 2), (2, 3), (3, 0)):
            furn.face([p[e0], p[e1], q[e1], q[e0]], col, outward=(p[e0][0] - (-4.6), 0, p[e0][2] - (DECK + 1.2)))
    metal.tube((4.35, 14.55, DECK), (4.35, 14.55, DECK + 2.15), 0.045, 6, STEEL)
    metal.box((4.20, 14.40, DECK + 2.12), (4.50, 14.70, DECK + 2.18), STEEL)
    metal.box((4.24, 14.44, DECK + 2.18), (4.46, 14.66, DECK + 2.45), STEEL)
    lit.box((4.25, 14.45, DECK + 2.20), (4.45, 14.65, DECK + 2.43), rect("Lit", 0.2, 0.2))
    atts["ATT_Lamp_Pontoon"] = Vector((4.35, 14.55, DECK + 2.3))
    # pontoon sign on the quay wall, clear of the ramp
    signs.box((-4.7, 9.92, -1.32), (-2.9, 9.99, -0.50), GREEN)
    signs.face([(-4.66, 10.0, -1.28), (-2.94, 10.0, -1.28), (-2.94, 10.0, -0.54), (-4.66, 10.0, -0.54)],
               rect("PontSign", 1.72, 0.72), outward=(0, 1, 0))
    # quay ladder
    for xl in (2.05, 2.65):
        metal.tube((xl, 9.96, WATER + 0.05), (xl, 9.96, 0.95), 0.035, 6, STEEL)
        metal.tube((xl, 9.96, 0.95), (xl, 9.30, 1.02), 0.035, 6, STEEL)
    for i in range(5):
        metal.tube((2.05, 9.96, WATER + 0.25 + i * 0.45), (2.65, 9.96, WATER + 0.25 + i * 0.45), 0.022, 5, STEEL)
    # bench on the terrace
    bx, by = -4.4, 8.55
    for sx in (-0.82, 0.82):
        furn.box((bx + sx - 0.03, by - 0.28, 0.08), (bx + sx + 0.03, by + 0.30, 0.46), BLACK)
        furn.box((bx + sx - 0.03, by - 0.28, 0.46), (bx + sx + 0.03, by - 0.20, 0.95), BLACK)
        furn.box((bx + sx - 0.03, by + 0.20, 0.46), (bx + sx + 0.03, by + 0.28, 0.95), BLACK)
    for i in range(3):
        furn.box((bx - 0.88, by - 0.26 + i * 0.18, 0.46), (bx + 0.88, by - 0.14 + i * 0.18, 0.50), GREEN)
    for i in range(3):
        furn.box((bx - 0.88, by + 0.22, 0.58 + i * 0.14), (bx + 0.88, by + 0.26, 0.68 + i * 0.14), GREEN)

    # ------------------------------------------------ front garden: path, low wall, piers, railings
    conc.box((-1.35, GARDEN_Y, 0.0), (1.35, PY - 0.6, 0.06), CONC)
    conc.box((-6.0, GARDEN_Y + 0.35, 0.0), (6.0, PY - 0.6, 0.04), CONC)
    for x0, x1 in ((-12.0, -2.35), (2.35, 12.0)):
        stone.box((x0, GARDEN_Y - 0.16, 0.0), (x1, GARDEN_Y + 0.16, 0.72), GRAN)
        stone.box((x0 - 0.04, GARDEN_Y - 0.20, 0.72), (x1 + 0.04, GARDEN_Y + 0.20, 0.80), GRAN)
        for xb in [x0 + 0.5 + i * 1.35 for i in range(int((x1 - x0 - 0.6) / 1.35) + 1)]:
            paint.box((xb - 0.018, GARDEN_Y - 0.01, 0.80), (xb + 0.018, GARDEN_Y + 0.01, 1.85), BLACK)
        paint.tube((x0, GARDEN_Y, 1.82), (x1, GARDEN_Y, 1.82), 0.022, 5, BLACK)
        paint.tube((x0, GARDEN_Y, 1.40), (x1, GARDEN_Y, 1.40), 0.018, 5, BLACK)
    for xp, hh in ((-2.35, 1.05), (2.35, 1.05), (-12.0, 0.95), (12.0, 0.95)):
        stone.box((xp - 0.24, GARDEN_Y - 0.24, 0.0), (xp + 0.24, GARDEN_Y + 0.24, hh), GRAN)
        stone.box((xp - 0.29, GARDEN_Y - 0.29, hh), (xp + 0.29, GARDEN_Y + 0.29, hh + 0.10), GRAN)
        stone.box((xp - 0.15, GARDEN_Y - 0.15, hh + 0.10), (xp + 0.15, GARDEN_Y + 0.15, hh + 0.24), GRAN)
    # roundel sign at the gate
    metal.tube((-2.72, GARDEN_Y + 0.2, 0.0), (-2.72, GARDEN_Y + 0.2, 1.95), 0.035, 6, STEEL)
    signs.box((-3.16, GARDEN_Y + 0.13, 1.33), (-2.28, GARDEN_Y + 0.21, 2.21), GREEN)
    signs.face([(-3.12, GARDEN_Y + 0.11, 1.37), (-2.32, GARDEN_Y + 0.11, 1.37), (-2.32, GARDEN_Y + 0.11, 2.17),
                (-3.12, GARDEN_Y + 0.11, 2.17)], rect("Roundel", 0.8, 0.8), outward=(0, -1, 0))
    atts["ATT_RoundelSign"] = Vector((-2.72, GARDEN_Y + 0.1, 1.75))
    # gravel strip behind the wall
    conc.box((-12.0, GARDEN_Y + 0.2, 0.0), (-2.5, PY - 0.05, 0.03), CONC)
    conc.box((2.5, GARDEN_Y + 0.2, 0.0), (12.0, PY - 0.05, 0.03), CONC)

    # ------------------------------------------------ attachment points
    atts["ATT_DropOff"] = Vector((0.0, 13.7, DECK + 0.02))
    atts["ATT_PontoonBerth_01"] = Vector((-2.4, 14.95, DECK + 0.05))
    atts["ATT_PontoonBerth_02"] = Vector((2.4, 14.95, DECK + 0.05))
    atts["ATT_RampFoot"] = Vector((0.0, 12.55, DECK + 0.05))
    atts["ATT_WaterLine"] = Vector((0.0, 14.0, WATER))
    atts["ATT_QuayTop"] = Vector((0.0, 9.55, 0.10))

    # ------------------------------------------------ objects, sets, collision, attachments
    parts = [render, stone, roof, trim_p, sash, glass, lit, doors, metal, paint, rubber, conc, signs, furn, pont]
    lo = Vector((min(p.bbox()[0].x for p in parts), min(p.bbox()[0].y for p in parts),
                 min(p.bbox()[0].z for p in parts)))
    hi = Vector((max(p.bbox()[1].x for p in parts), max(p.bbox()[1].y for p in parts),
                 max(p.bbox()[1].z for p in parts)))
    off = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    mats = {
        "Walls": ("Render_White", geo.material("MI_Hospital_Render", (0.62, 0.61, 0.57), 0.9)),
        "Stone": ("Details", geo.material("MI_Hospital_Stone", (0.34, 0.33, 0.31), 0.85)),
        "Roof": ("Slate", geo.material("MI_Hospital_Slate", (0.07, 0.08, 0.09), 0.6)),
        "Trim": ("Sheet", geo.material("MI_Hospital_Trim", (0.3, 0.3, 0.3), 0.6)),
        "Sashes": ("Details", geo.material("MI_Hospital_Sash", (0.72, 0.71, 0.67), 0.55)),
        "Glass": ("Details", geo.material("MI_Hospital_Glass", (0.05, 0.06, 0.06), 0.08)),
        "LitGlass": ("Details", geo.material("MI_Hospital_Lit", (1.0, 0.8, 0.5), 0.3)),
        "Doors": ("Details", geo.material("MI_Hospital_Doors", (0.3, 0.36, 0.32), 0.5)),
        "Metal": ("Details", geo.material("MI_Hospital_Metal", (0.55, 0.55, 0.53), 0.45, 0.6)),
        "Paint": ("Details", geo.material("MI_Hospital_Paint", (0.12, 0.13, 0.12), 0.5)),
        "Rubber": ("Details", geo.material("MI_Hospital_Rubber", (0.06, 0.06, 0.06), 0.8)),
        "Concrete": ("Details", geo.material("MI_Hospital_Concrete", (0.5, 0.5, 0.47), 0.9)),
        "Signs": ("Details", geo.material("MI_Hospital_Signs", (0.16, 0.25, 0.2), 0.5)),
        "Furniture": ("Details", geo.material("MI_Hospital_Furniture", (0.35, 0.4, 0.36), 0.5)),
        "Pontoon": ("Kit", geo.material("MI_Hospital_Pontoon", (0.45, 0.45, 0.42), 0.7)),
    }
    meshes = []
    for p in parts:
        s, mat = mats[p.name]
        obj = p.to_object("%s_%s_LOD0" % (NAME, p.name), mat, off)
        meshes.append({"object": obj, "set": s})
        print("[H5] %s tris %d" % (p.name, p.tris(0)))
    print("[H5] total tris %d" % sum(p.tris(0) for p in parts))

    # ------------------------------------------------ hand-made LOD1 (decimated) and LOD2 (simplified forms)
    def tri_of(o):
        o.data.calc_loop_triangles()
        return len(o.data.loop_triangles)

    for e in list(meshes):
        src = e["object"]
        base = src.name[:-5]
        dup = src.copy()
        dup.data = src.data.copy()
        dup.name = base + "_LOD1"
        dup.data.name = dup.name
        bpy.context.scene.collection.objects.link(dup)
        if tri_of(dup) > 240:
            soft_decimate(dup, 0.42)
        meshes.append({"object": dup, "set": e["set"]})

    # LOD1 / LOD2 of the parts above are soft-decimated; replace the LOD2 of the big simple parts
    # with purpose-built cards and boxes below (the rest keep the decimated form).
    l2 = {}
    for nm in ("Walls", "Stone", "Roof", "Trim", "Sashes", "Doors", "Metal", "Paint", "Rubber",
               "Concrete", "Signs", "Furniture", "Pontoon"):
        l2[nm] = Part(nm + "2")
    R = l2["Walls"]
    R.box((XL, YF, 0.0), (XR, YB, EAV), ("tile", 3.0))
    for side in (-1, 1):
        xa, xb = sorted((side * (PX - 0.30), side * PX))
        R.box((xa, PY, 0.0), (xb, YF, 3.96), ("tile", 3.0))
    R.box((-PX, PY, 2.96), (PX, PY + 0.28, 3.96), ("tile", 3.0))
    S = l2["Stone"]
    S.box((XL - 0.1, YF - 0.1, 0.0), (XR + 0.1, YF, 0.8), flat("Granite"))
    S.box((XL - 0.1, YB, 0.0), (XR + 0.1, YB + 0.1, 0.8), flat("Granite"))
    S.box((XL - 0.1, YF, 0.0), (XL, YB, 0.8), flat("Granite"))
    S.box((XR, YF, 0.0), (XR + 0.1, YB, 0.8), flat("Granite"))
    S.box((-8.2, 9.55, WATER - 0.05), (8.2, 9.9, 0.18), flat("Granite"))
    for x0, x1 in ((-12.0, -2.35), (2.35, 12.0)):
        S.box((x0, GARDEN_Y - 0.16, 0.0), (x1, GARDEN_Y + 0.16, 0.8), flat("Granite"))
    for xc in (-7.8, 7.8):
        S.box((xc - 0.58, -0.44, RIDGE - 0.75), (xc + 0.58, 0.44, 13.35), flat("Granite"))
    RO = l2["Roof"]
    for (A, B, C, Dd), out in quads:
        mode = plane_uv(A, B, C, Dd)
        RO.face([A, B, Dd, C] if C != Dd else [A, B, C], mode, outward=(0, 0, 1))
    RO.face([rq[0], rq[3], rq[2], rq[1]], ("tile", 2.0), outward=(0, 0, 1))
    RO.tube((-RX, 0, RD + 0.03), (RX, 0, RD + 0.03), 0.135, 5, ("tile", 2.0))
    for A, C in (((fx0, fy, zt), (-RX, 0, zr)), ((bx0, by, zt), (-RX, 0, zr)),
                 ((fx1, fy, zt), (RX, 0, zr)), ((bx1, by, zt), (RX, 0, zr))):
        RO.tube(A, (C[0], C[1], C[2] + 0.02), 0.13, 5, ("tile", 2.0))
    TR2 = l2["Trim"]
    for y, out in ((YF, -1), (YB, 1)):
        TR2.box((-EX, y + out * 0.30, ZD - 0.20), (EX, y + out * 0.42, ZD - 0.02), trim("Gutter"))
    for x, out in ((XL, -1), (XR, 1)):
        TR2.box((x + out * 0.30, -EY, ZD - 0.20), (x + out * 0.42, EY, ZD - 0.02), trim("Gutter"))
    for x, y in ((XL + 0.5, YF - 0.6), (XR - 0.5, YF - 0.6), (XL + 0.5, YB + 0.6), (XR - 0.5, YB + 0.6)):
        TR2.box((x - 0.07, y - 0.07, 0.2), (x + 0.07, y + 0.07, ZD - 0.1), trim("Downpipe"))
    SA = l2["Sashes"]

    def card(part, key, s, z0, z1, w, mode):
        if key == "front":
            fc, out = YF - 0.02, (0, -1, 0)
            pts = [(s - w / 2, fc, z0), (s + w / 2, fc, z0), (s + w / 2, fc, z1), (s - w / 2, fc, z1)]
        elif key == "back":
            fc, out = YB + 0.02, (0, 1, 0)
            pts = [(s - w / 2, fc, z0), (s + w / 2, fc, z0), (s + w / 2, fc, z1), (s - w / 2, fc, z1)]
        elif key == "west":
            fc, out = XL - 0.02, (-1, 0, 0)
            pts = [(fc, s - w / 2, z0), (fc, s + w / 2, z0), (fc, s + w / 2, z1), (fc, s - w / 2, z1)]
        else:
            fc, out = XR + 0.02, (1, 0, 0)
            pts = [(fc, s - w / 2, z0), (fc, s + w / 2, z0), (fc, s + w / 2, z1), (fc, s - w / 2, z1)]
        part.face(pts, mode, outward=out)

    for key, s, sill, w, h, _l in WIN:
        card(SA, key, s, sill - 0.16, sill + h + 0.16, w + 0.24, rect("WindowCard", 1.25, 2.0))
    DO = l2["Doors"]
    for key, s, w, h, tex in DOORS:
        card(DO, key, s, 0.10, h + 0.06, w + 0.12, rect(tex, w, h))
    SI = l2["Signs"]
    SI.face([(-1.86, PY - 0.05, 3.07), (1.86, PY - 0.05, 3.07), (1.86, PY - 0.05, 3.79), (-1.86, PY - 0.05, 3.79)],
            rect("Sign", 3.72, 0.72), outward=(0, -1, 0))
    SI.face([(CAN_X1 + 0.08, -0.44, 3.06), (CAN_X1 + 0.08, 0.44, 3.06), (CAN_X1 + 0.08, 0.44, 3.94),
             (CAN_X1 + 0.08, -0.44, 3.94)], rect("BaySign", 0.88, 0.88), outward=(1, 0, 0))
    SI.face([(-4.66, 10.0, -1.28), (-2.94, 10.0, -1.28), (-2.94, 10.0, -0.54), (-4.66, 10.0, -0.54)],
            rect("PontSign", 1.72, 0.72), outward=(0, 1, 0))
    SI.face([(-3.12, GARDEN_Y + 0.1, 1.37), (-2.32, GARDEN_Y + 0.1, 1.37), (-2.32, GARDEN_Y + 0.1, 2.17),
             (-3.12, GARDEN_Y + 0.1, 2.17)], rect("Roundel", 0.8, 0.8), outward=(0, -1, 0))
    SI.face([(XR + 0.06, -0.48, 3.10), (XR + 0.06, 0.48, 3.10), (XR + 0.06, 0.48, 3.44),
             (XR + 0.06, -0.48, 3.44)], rect("Date", 0.96, 0.34), outward=(1, 0, 0))
    M = l2["Metal"]
    for sy in (-CAN_Y + 0.15, CAN_Y - 0.15):
        M.box((CAN_X1 - 0.20, sy - 0.11, 0.0), (CAN_X1 - 0.02, sy + 0.11, 4.3), flat("Steel"))
    M.box((XR, -CAN_Y, 4.1), (CAN_X1, CAN_Y, 4.3), flat("Steel"))
    M.box((CAN_X1 + 0.4, 3.0, 0.2), (CAN_X1 + 0.55, 3.1, 4.3), flat("Steel"))
    for xl in (2.05, 2.65):
        M.box((xl - 0.05, 9.9, WATER), (xl + 0.05, 10.02, 0.95), flat("Steel"))
    P2 = l2["Paint"]
    for x0, x1 in ((-12.0, -2.35), (2.35, 12.0)):
        P2.box((x0, GARDEN_Y - 0.02, 0.8), (x1, GARDEN_Y + 0.02, 1.85), flat("Black"))
    P2.box((XR - 0.45, 2.3, 0.1), (XR - 0.2, 2.85, 1.8), flat("Green"))
    P2.tube((-3.8, 14.2, DECK), (-3.8, 14.6, DECK + 0.15), 0.12, 5, flat("Terra"))
    RB = l2["Rubber"]
    for xf in (-4.4, -2.6, -0.9, 0.9, 2.6, 4.4):
        RB.box((xf - 0.12, 14.85, DECK - 0.55), (xf + 0.12, 15.02, DECK + 0.1), flat("Rubber"))
    C2 = l2["Concrete"]
    C2.box((XR - 0.05, -3.6, 0.0), (CAN_X1 + 0.2, 3.6, 0.1), flat("Conc"))
    C2.box((-7.0, YB, 0.0), (7.0, 9.5, 0.08), flat("Conc"))
    C2.box((-1.35, GARDEN_Y, 0.0), (1.35, PY - 0.6, 0.06), flat("Conc"))
    F2 = l2["Furniture"]
    F2.box((-5.3, 8.25, 0.4), (-3.5, 8.45, 1.0), flat("Green"))
    F2.box((tx - 0.9, ty - 0.35, 0.7), (tx + 0.9, ty + 0.35, 0.95), flat("Blue"))
    F2.box((-4.95, 14.5, DECK + 0.8), (-4.25, 14.7, DECK + 1.55), flat("Blue"))
    PO = l2["Pontoon"]
    PO.box((-5.0, 12.6, DECK - 0.14), (5.0, 15.0, DECK), PD[0])
    for xf in (-4.3, -2.6, -0.9, 0.9, 2.6, 4.3):
        PO.box((xf - 0.55, 12.75, WATER), (xf + 0.55, 14.95, DECK - 0.32), PF)
    PO.face([(-1.1, 9.30, 0.05), (1.1, 9.30, 0.05), (1.1, 12.55, DECK + 0.05), (-1.1, 12.55, DECK + 0.05)],
            PTREAD, outward=(0, 0, 1))

    # swap the soft-decimated LOD2 objects for the purpose-built ones
    for nm, p in l2.items():
        base = NAME + "_" + nm
        name2 = base + "_LOD2"
        meshes[:] = [e for e in meshes if not (e["object"].name == name2)]
        old = bpy.data.objects.get(name2)
        if old is not None:
            bpy.data.objects.remove(old, do_unlink=True)
        o = p.to_object(base + "_LOD2", mats[nm][1], off)
        meshes.append({"object": o, "set": mats[nm][0]})
        print("[H5] %s LOD2 %d tris" % (nm, p.tris(0)))
    tot = {"LOD0": 0, "LOD1": 0, "LOD2": 0}
    for e in meshes:
        for k in tot:
            if e["object"].name.endswith("_" + k):
                tot[k] += tri_of(e["object"])
    print("[H5] LOD totals %d / %d / %d" % (tot["LOD0"], tot["LOD1"], tot["LOD2"]))

    col = Part("COL")
    col.box((XL, YF, 0.0), (XR, YB, EAV), GRAN)
    col.box((XL, YF, EAV - 0.2), (XR, YB, RIDGE), GRAN)
    col.box((-PX, PY, 0.0), (PX, YF, 4.4), GRAN)
    for sy in (-CAN_Y + 0.15, CAN_Y - 0.15):
        col.box((CAN_X1 - 0.3, sy - 0.22, 0.0), (CAN_X1 + 0.1, sy + 0.22, 4.35), GRAN)
    col.box((XR, -CAN_Y - 0.4, 4.3), (CAN_X1 + 0.4, CAN_Y + 0.4, 4.95), GRAN)
    col.box((-8.2, 9.5, WATER - 0.2), (8.2, 9.95, 0.2), GRAN)
    col.box((-7.0, YB, 0.0), (7.0, 9.5, 0.1), GRAN)
    col.box((-5.0, 12.6, DECK - 0.35), (5.0, 15.0, DECK), GRAN)
    col.prism([(9.3, 0.0), (12.55, DECK), (12.55, DECK - 0.3), (9.3, -0.2)], "x", -1.15, 1.15, GRAN)
    col.box((-12.0, GARDEN_Y - 0.2, 0.0), (-2.35, GARDEN_Y + 0.2, 0.85), GRAN)
    col.box((2.35, GARDEN_Y - 0.2, 0.0), (12.0, GARDEN_Y + 0.2, 0.85), GRAN)
    colobj = col.to_object(NAME + "_COL", None, off, weld=False)

    att_objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = ((p.x + off.x) * 3, (p.y + off.y) * 3, (p.z + off.z) * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)

    sz = hi - lo
    print("[H5] bbox m %.2f x %.2f x %.2f" % (sz.x, sz.y, sz.z))
    st = lambda x, y, z: [(x + off.x) * 3, (y + off.y) * 3, (z + off.z) * 3]
    return {
        "name": NAME,
        "budget": "hero_building",
        "tris": 35000,
        "tier": "hero",
        "dims_m": (round(sz.x, 2), round(sz.y, 2), round(sz.z, 2)),
        "size_note": "30 x 15 m main block; the bbox adds the entrance porch, the east ambulance canopy and the rear "
                     "ramp + 10 m pontoon (reported whole per the docs/12 row)",
        "origin": "base",
        "tiling": True,
        "waivers": {"LOD UV layout": "hand-made LOD1 (decimated tiling meshes) and purpose-built LOD2 cards/boxes: "
                                     "world-scale tiling UVs and simplified forms change the UV bounds, as on the H1 "
                                     "Station and H3 kit buildings"},
        "sets": [
            {"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": True, "dir": TEX + "M_Bld_TrimSheet"},
            {"name": "Cottage", "set": "Render_White", "size": 1024, "wet": True, "dir": TEX + "M_Bld_Cottage_Kit"},
            {"name": "Cottage", "set": "Slate", "size": 1024, "wet": True, "dir": TEX + "M_Bld_Cottage_Kit"},
            {"name": "Hospital", "set": "Details", "size": 2048, "wet": True},
            {"name": "Pontoon", "set": "Kit", "size": 1024, "wet": True, "dir": TEX + "M_Hbr_Pontoon"},
        ],
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "entrance_sign", "target": st(0.0, PY - 0.05, 3.45), "dist": 18, "az": 12, "el": 3},
            {"name": "porch_doors", "target": st(0.0, YF - 0.2, 1.5), "dist": 8, "az": 8, "el": 3},
            {"name": "sash_window", "target": st(-8.6, YF, 5.3), "dist": 7, "az": -25, "el": 5},
            {"name": "ambulance_bay", "target": st(16.9, -1.7, 1.4), "dist": 10, "az": 58, "el": 5},
            {"name": "pontoon", "target": st(0.0, 13.8, DECK), "dist": 17, "az": 150, "el": 16},
            {"name": "quay_ramp", "target": st(0.0, 10.8, 0.2), "dist": 12, "az": 165, "el": 12},
            {"name": "roof_chimney", "target": st(7.8, 0.0, 12.8), "dist": 17, "az": 35, "el": 22},
            {"name": "trolley", "target": st(16.4, -2.2, 0.6), "dist": 7, "az": 40, "el": 8},
        ],
    }
