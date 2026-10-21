"""M_Kit_StretcherBasket: shared design table (build.py and maketex.py both import this).

Real size 2.13 x 0.61 x 0.20 m (docs/12), long axis Y, head at -Y, base at Z 0. Metres everywhere; build.py converts
to studs (1 m = 3 studs) when it writes the mesh.

Texture layout: one 1024 ft atlas of horizontal LANES (rects), each painted by maketex.py at its own texel density.
`uv(lane, u, v)` maps a position inside a lane to the atlas. A lane's (u, v) axes are its own local axes; the world
extents below are what make the paint isotropic (px per stud in each axis).
"""
import math

# ---------------------------------------------------------------- geometry (metres)
B = 1.050          # half length of the rim rail path (tube centre); +0.015 tube = 1.065 -> 2.13 m
A = 0.290          # half width of the rim rail path; +0.015 tube = 0.305 -> 0.61 m
RR = 0.015         # rim tube radius (30 mm OD)
NEXP = 3.4         # superellipse exponent of the plan outline (rounded-rectangle look)
HEADTAP = 0.085    # head end (-Y) narrowing as a share of the half width
ZF, ZH = 0.168, 0.184   # rim tube centre z at the foot / the head (the raised head section)
RAISE = (0.12, 1.0)     # smoothstep over -y/B where the head raise starts / is full

SHELL_A = 0.262    # shell half width at the wall base (inside the rim tube)
SHELL_B = 1.030    # shell half length at the wall base
WALL = 0.006       # shell wall thickness
FILW = 0.032       # fillet radius where the tub bottom turns up into the wall
ZB_OUT, ZB_IN = 0.0355, 0.0415   # tub outer / inner bottom z (the tub rests on the cross ribs)
LIP_DROP = 0.004   # the shell lip sits this far below the rim tube centre

NRIB = 4           # cross ribs under the tub
RIB_Y = (-0.78, -0.26, 0.26, 0.78)      # rib y positions
RIB_R = 0.0085     # cross rib tube radius
RUN_X = (-0.170, 0.170)                 # longitudinal runners (skids)
RUN_R = 0.0100     # skid tube radius
RUN_Y = 0.93                            # runner half length
NSH = 24           # shell columns around the plan
NRIM = 38          # rim rail stations around the loop
TUBE_S = 6         # sides of the under-frame tubes (ribs, runners, handles, sleeves)

SLING_X = 0.250    # lifting eye pad centre (x) at the head/foot corners
SLING_Y = 0.905    # lifting eye pad y
STRAP_Y = (-0.70, -0.22, 0.30, 0.80)    # patient strap positions along the bed
STRAP_W = 0.050    # webbing width
STRAP_T = 0.0035   # webbing thickness
RING_R, RING_r = 0.032, 0.0062          # lifting eye ring
FOOT_Y = 0.975     # foot plate (a plate across the foot end, standing on the tub)

# Sub-rects of the fittings lane (u0, u1, v0, v1): lifting eyes, join sleeves, bolts, strap tabs and buckles,
# grab handles and the foot plate. build.py maps each part's UVs inside its rect; maketex.py paints them.
FIT = {                                        # sub-rects of the fittings lane: (u0, u1, v0, v1)
    "ring": (0.000, 0.230, 0.00, 0.56),
    "ringb": (0.230, 0.460, 0.00, 0.56),
    "sleeve": (0.460, 0.700, 0.00, 0.28),
    "bolt": (0.700, 0.790, 0.00, 0.22),
    "tab": (0.790, 0.880, 0.00, 0.22),
    "buckle": (0.880, 1.000, 0.00, 0.22),
    "plate": (0.000, 0.560, 0.62, 1.00),
    "handle": (0.560, 1.000, 0.34, 0.62),
    "grip": (0.560, 1.000, 0.62, 1.00),
}

# ---------------------------------------------------------------- atlas lanes (v0, v1), u 0..1
LANES = {
    "shellout":  (0.0000, 0.2500),
    "shellin":   (0.2500, 0.5000),
    "fittings":  (0.5000, 0.6094),
    "rim":       (0.6094, 0.6719),
    "ribs":      (0.6719, 0.7344),
    "runners":   (0.7344, 0.7969),
    "shellwall": (0.7969, 0.8594),
    "webbing":   (0.8594, 0.9219),
    "plastic":   (0.9219, 1.0000),
}
# World size of each lane's two axes in studs (1 m = 3 studs): the paint scale per lane.
LANE_WORLD = {
    #                             u studs              v studs
    "shellout":  (3 * 2 * SHELL_B, 3 * 2 * SHELL_A),        # plan box projection, along Y / across X
    "shellin":   (3 * 2 * SHELL_B, 3 * 2 * SHELL_A),
    "fittings":  (26.0, 2.0),
    "rim":       (None, 3 * 2 * math.pi * RR),              # u = rim arc (filled by build.py), v = 40 mm around
    "ribs":      (7.0, 3 * 2 * math.pi * RIB_R),
    "runners":   (12.0, 3 * 2 * math.pi * RUN_R),
    "shellwall": (None, 0.85),                              # u = perimeter x 2 (filled), v = profile arc
    "webbing":   (10.8, 0.321),
    "plastic":   (8.0, 1.0),
}


INSET = 3.0        # texels kept free at every lane edge (collapse decimation moves UVs a little)


def uv(lane, u, v):
    """Lane-local (u, v) in 0..1 -> atlas UV, inset INSET texels from the lane's edges."""
    import dims as _d
    v0, v1 = LANES[lane]
    h = (v1 - v0) * 1024.0
    k_u, k_v = INSET / 1024.0, INSET / max(h, 1.0)
    return (k_u + u * (1.0 - 2.0 * k_u), v0 + (v1 - v0) * (k_v + v * (1.0 - 2.0 * k_v)))
