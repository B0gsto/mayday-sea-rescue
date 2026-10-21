"""M_Kit_ChartTablet: atlas lanes, plan maths (metres) and detail positions shared by build.py and maketex.py.

The device is a 10-inch rugged tablet in a waterproof case, authored as it lies: screen +Z, its top edge at +Y,
base at Z 0, centred on the origin. The case plan is a rounded rectangle, W x D, whose bumper overmould stands
BUMP proud, so the bounding box is exactly 0.270 x 0.180 x 0.020 m (docs/12 2.8 row, art/reference/dims.md).

Every ring of the solid is a rounded-rect loop inset `t` metres from the base outline (t > 0 inward, t < 0 outward:
for a rounded rectangle an inset of t is the normal offset, so the wall rings use it directly). `t` never exceeds
half the depth, so no loop degenerates. The paint needs the same numbers as the geometry: lane pixel rects, the
outline, the plan -> lane projection, the nearest-arc query for the unrolled wall lane, the back surface height at
a plan point, and the millimetre positions of every moulding (hatch, grip pad, label, cameras, buttons, ports,
lanyard anchor, dock contacts).
"""
import math

import numpy as np

# ---------------------------------------------------------------- texture set
SIZE = 1024                       # ship size of T_ChartTablet_Kit_* (one set, dry + _Wet)
PAD = 6                           # gutter between lanes, px (bake bleed + mip safety)

# lane -> (x0, y0, x1, y1) in atlas pixels, y counted from the bottom (v up)
LANES = {
    "wall":   (0, 0, 1024, 192),          # the case edge unrolled: u = arc fraction round the rim, v = z / TH
    "back":   (0, 200, 512, 540),         # back cap, plan projection
    "screen": (518, 200, 1024, 514),      # glass, plan projection
    "bezel":  (0, 548, 512, 878),         # front bezel ring, plan projection
    "metal":  (518, 522, 764, 690),       # stainless: screws, lanyard ring, dock contacts
    "rubber": (768, 522, 1018, 690),      # black rubber: button pads, port flap, lanyard boss, gasket
    "label":  (518, 694, 764, 862),       # the moulded brand plate on the back
    "grip":   (768, 694, 1018, 862),      # the TPE grip pad
}

# lane -> real-world size of one full lane (metres, along U and V)
WORLD = {
    "wall":   None,                       # perimeter x TH, filled in below (needs the outline)
    "back":   (0.266, 0.176),             # the base plan
    "bezel":  (0.266, 0.176),
    "screen": (0.2328, 0.1428),           # the glass
    "metal":  (0.012, 0.008),
    "rubber": (0.026, 0.018),
    "label":  (0.088, 0.032),
    "grip":   (0.112, 0.104),
}

# ---------------------------------------------------------------- the plan
W, D, RC = 0.266, 0.176, 0.013    # case plan before the bumper bulge
BUMP = 0.0020                     # bumper stands this far proud of the base outline
TH = 0.020                        # case thickness, base at Z 0 (bbox Z)
SEG_LONG, SEG_CORNER = 3, 5       # perimeter segments per straight run / per corner (4x3 + 4x5 = 32 around)

# profile stations (inset t from the base outline, z): the back centre fan runs inward at the top of this list
TZ = [
    (0.0062, 0.0000),      # 0  brim rim edge: the case rests on this ring (lo z = 0)
    (0.0018, 0.0003),      # 1  brim underside
    (-0.0003, 0.0012),     # 2  lower chamfer
    (-0.0012, 0.0034),     # 3  shell lower wall (the overmould seam)
    (-0.0020, 0.0090),     # 4  bumper bulge (bbox 0.270 x 0.180)
    (-0.0012, 0.0142),     # 5  bumper upper wall (the second overmould seam)
    (0.0009, 0.0170),      # 6  shell upper bevel
    (0.0021, 0.0196),      # 7  bezel outer wall
    (0.0021, 0.0200),      # 8  bezel rim (top face edge)
    (0.0120, 0.0200),      # 9  bezel face, inner edge of the flat ring
    (0.0140, 0.0180),      # 10 bezel inner chamfer down into the recess
    (0.0166, 0.0176),      # 11 gasket floor, inner edge (the glass edge sits at 0.0158 below)
]
# back cap rings, from the brim inward: (inset t, z)
BACK_RINGS = [(0.024, 0.0007), (0.062, 0.0014), (0.100, 0.0018)]
GLASS_T = 0.0166                  # glass edge inset
GLASS_Z = 0.0182                  # glass top surface
GLASS_IN = 0.030                  # glass inner ring (then the centre fan)
BUMP_V0, BUMP_V1 = 0.0034 / TH, 0.0142 / TH     # the TPE overmould band of the wall lane, in v


def rect(lane):
    """(u0, u1, v0, v1) of a lane inside the atlas, padded."""
    x0, y0, x1, y1 = LANES[lane]
    return ((x0 + PAD) / SIZE, (x1 - PAD) / SIZE, (y0 + PAD) / SIZE, (y1 - PAD) / SIZE)


UVM = 1.0 / SIZE              # 1 px margin: LOD decimation interpolation must not leave 0..1


def uv(lane, u, v):
    u0, u1, v0, v1 = rect(lane)
    return (min(max(u0 + (u1 - u0) * u, UVM), 1.0 - UVM), min(max(v0 + (v1 - v0) * v, UVM), 1.0 - UVM))


def lane_px(lane):
    x0, y0, x1, y1 = LANES[lane]
    return (x0 + PAD, y0 + PAD, x1 - PAD, y1 - PAD)      # painting frame, px


def lane_ppm(lane):
    """Pixels per metre along U and V inside a lane (physical painting scale)."""
    x0, y0, x1, y1 = lane_px(lane)
    wu, wv = WORLD[lane]
    return ((x1 - x0) / wu, (y1 - y0) / wv)


def _loop(hw, hd, rc, n_long, n_corner):
    """Rounded-rect loop, counter-clockwise seen from +Z, from the +X edge's lower end: (x, y, nx, ny)."""
    out = []
    for i in range(n_long):                                     # right edge, +Y
        y = (-hd + rc) + (2 * (hd - rc)) * i / n_long
        out.append((hw, y, 1.0, 0.0))
    for cx, cy, a0 in ((hw - rc, hd - rc, 0.0), (-hw + rc, hd - rc, 90.0),
                       (-hw + rc, -hd + rc, 180.0), (hw - rc, -hd + rc, 270.0)):
        for i in range(n_corner):
            a = math.radians(a0 + 90.0 * i / n_corner)
            out.append((cx + rc * math.cos(a), cy + rc * math.sin(a), math.cos(a), math.sin(a)))
        if a0 == 0.0:                                           # top edge, -X
            for i in range(n_long):
                x = (hw - rc) - 2 * (hw - rc) * i / n_long
                out.append((x, hd, 0.0, 1.0))
        elif a0 == 90.0:                                        # left edge, -Y
            for i in range(n_long):
                y = (hd - rc) - 2 * (hd - rc) * i / n_long
                out.append((-hw, y, -1.0, 0.0))
        elif a0 == 180.0:                                       # bottom edge, +X
            for i in range(n_long):
                x = (-hw + rc) + 2 * (hw - rc) * i / n_long
                out.append((x, -hd, 0.0, -1.0))
    return out


def ring(t, z, n_long=SEG_LONG, n_corner=SEG_CORNER):
    """[(x, y, nx, ny, z)] of the rounded-rect loop inset t metres (t < 0 outward).

    For |t| inside the corner radius the inset is the true normal offset. Deeper in, the offset of a rounded
    rectangle degenerates to a rectangle: the radius flattens to a small positive value instead of inverting
    (an inverted radius makes the loop self-intersect and leaves zero-area faces)."""
    hw, hd = W / 2 - t, D / 2 - t
    rc = min(max(RC - t, 0.0035), 0.9 * min(hw, hd))
    return [(x, y, nx, ny, z) for x, y, nx, ny in _loop(hw, hd, rc, n_long, n_corner)]


def inset_loop(t, z, n_long=SEG_LONG, n_corner=SEG_CORNER):
    """[(x, y, z)] of the rounded-rect loop inset t metres (t < 0 outward)."""
    return [(x, y, zz) for x, y, _, _, zz in ring(t, z, n_long, n_corner)]


# dense tables: the same loop finely sampled, for arc length and the nearest-point query
_DENSE = _loop(W / 2, D / 2, RC, 240, 400)
_CUM = [0.0]
for _a, _b in zip(_DENSE[:-1], _DENSE[1:]):
    _CUM.append(_CUM[-1] + math.hypot(_b[0] - _a[0], _b[1] - _a[1]))
_CUM.append(_CUM[-1] + math.hypot(_DENSE[0][0] - _DENSE[-1][0], _DENSE[0][1] - _DENSE[-1][1]))
PERIM = _CUM[-1]
U_AT = [c / PERIM for c in _CUM[:-1]]                 # arc fraction of each dense point
_COARSE = _loop(W / 2, D / 2, RC, SEG_LONG, SEG_CORNER)
COARSE_U = []
for _p in _COARSE:
    _best = min(range(len(_DENSE)), key=lambda i: (_DENSE[i][0] - _p[0]) ** 2 + (_DENSE[i][1] - _p[1]) ** 2)
    COARSE_U.append(U_AT[_best])
WORLD["wall"] = (PERIM, TH)


def u_at(x, y):
    """Arc fraction (0..1 round the perimeter) of the outline point nearest a plan point."""
    i = int(np.argmin([(_DENSE[k][0] - x) ** 2 + (_DENSE[k][1] - y) ** 2 for k in range(len(_DENSE))]))
    return U_AT[i]


def plan_pt(u):
    """Plan point (x, y) and outward normal at an arc fraction."""
    i = int(round(u * len(_DENSE))) % len(_DENSE)
    return _DENSE[i][:2]


def sdf(x, y, t=0.0):
    """Rounded-rect signed distance at a plan point for the outline inset t (negative inside)."""
    hw, hd, rc = W / 2 - t, D / 2 - t, RC - t
    qx, qy = abs(x) - (hw - rc), abs(y) - (hd - rc)
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - rc


def inset_of(x, y):
    """Metres inside the base outline at a plan point (0 on the outline)."""
    return -sdf(x, y)


def plan_uv(lane, x, y):
    """Lane-local (u, v) of a plan point, for lanes that are plan projections (back, bezel, screen)."""
    wu, wv = WORLD[lane]
    return (x / wu + 0.5, y / wv + 0.5)


def back_z(x, y):
    """Back surface height at a plan point (the cap rises from the rim ring to the centre)."""
    t = inset_of(x, y)
    pts = [(TZ[0][0], TZ[0][1])] + BACK_RINGS
    for (t0, z0), (t1, z1) in zip(pts[:-1], pts[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0)
            return z0 + (z1 - z0) * max(0.0, min(1.0, f))
    return BACK_RINGS[-1][1]


# ---------------------------------------------------------------- mouldings (plan metres, y +ve = the top edge)
CAM_BACK = (0.0855, 0.0500)       # rear camera collar centre
CAM_BACK_R = 0.0058
HATCH_C = (-0.0615, 0.0455)       # battery / comms hatch centre
HATCH_SZ = (0.0720, 0.0500)
HATCH_R = 0.008
SCREW_C = [(-0.0615 - 0.0255, 0.0455 + 0.0135), (-0.0615 + 0.0255, 0.0455 + 0.0135)]
SCREW_R = 0.0026
PAD_C = (0.0, -0.0080)            # TPE grip pad centre
PAD_SZ = (0.1100, 0.0980)
PAD_R = 0.011
PAD_TIP = (0.0, -0.0080 - 0.0980 / 2 - 0.0)   # the pad's lower tip (small moulded ridge)
LABEL_C = (0.0, -0.0660)          # brand plate centre
LABEL_SZ = (0.0880, 0.0205)
LABEL_R = 0.0035
LANYARD_C = (-0.0990, -0.0575)    # lanyard anchor boss centre (back, bottom-left)
LANYARD_R = 0.0075
CONTACTS = [(-0.0300, -0.0790), (-0.0100, -0.0790), (0.0100, -0.0790), (0.0300, -0.0790)]   # dock contacts, back
CAM_FRONT = (0.0, 0.0745)         # front camera in the top bezel strip
CAM_FRONT_R = 0.0034
SENSOR = (-0.0250, 0.0745)        # ambient light sensor pinhole
MIC = (0.0250, 0.0745)            # mic pinhole
SLOTS = []                        # speaker slots, painted on the bottom bezel strip: 2 groups of 4 (plan x, y)
for _sx in (-1, 1):
    for _k in range(4):
        SLOTS.append((_sx * (0.0490 + 0.0130 * _k), -0.0755))
SLOT_SZ = (0.0022, 0.0078)        # one slot, metres

VOL_Y = (0.0265, 0.0455)          # volume rocker pads, y range on the +X edge (two slabs)
PWR_X = (0.0840, 0.1010)          # power button, x range on the +Y edge
PORT_X = (-0.0300, 0.0180)        # port flap, x range on the +Y edge (charge, USB, HDMI under one flap)
BTN_Z = (0.0150, 0.0172)          # buttons sit in the shell band just above the bumper
BTN_OUT = 0.0018                  # how far a button stands past the base outline (< BUMP: still inside the bbox)
