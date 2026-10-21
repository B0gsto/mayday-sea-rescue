"""E2 M_Kit_HorizontalLift: the parbuckle recovery net and its lifting strop (docs/12 2.8, 3,000 tris).

A 2.00 x 1.20 m knotted person-recovery net laid out ready on deck (docs/09 6: the net goes over the sponson, the
casualty floats into it and the crew crank them up flat, level the whole way):

  * 0.20 m mesh of 12 mm floating polypropylene twine, knotted at every crossing, the twine lying on the deck with
    the knots proud and the whole net wandering like soft kit that has just been shaken out;
  * a 16 mm bolt rope round the edge with soft spliced corners, the mesh laced to it at every border knot and
    lashed at the four corners (where the strop's legs are shackled on);
  * the strop: 3 m of 16 mm rope, its spliced eye over the galvanised master ring (the halyard / davit hook goes
    there) and the rest flaked flat on the deck beyond the head end, its free eye lying there too -- net and strop
    as they are left on deck after a shout;
  * three SOLAS orange HDPE floats lashed along the +Y edge (the buoyant edge that has to stay at the surface),
    two 25 mm black webbing grab handles on the -Y edge, and three retroreflective tape bands on the bolt rope.

Geometry through tools/blender/rope.py (rope.tube: at this budget the tiling rope trim carries the three-strand
twist, the tube stays round; rope.knot for the knots). maketex.py writes T_HorizontalLift_Rope_* (1024 tiling
hi-vis yellow polypropylene) and T_HorizontalLift_Fittings_* (1024, four lanes: galvanised steel, orange HDPE,
black webbing, retro tape) into the out-root before validate looks for them.

Authored in metres (1 Blender unit = 1 stud), front -Y, base at Z 0, everything lying on the deck.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/kit/M_Kit_HorizontalLift/build.py \
        --out-root build/prod/M_Kit_HorizontalLift --steps build,lod,validate,export,turntable
"""
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import maketex  # noqa: E402
import rope  # noqa: E402

S = common.STUDS_PER_METRE
NAME = "M_Kit_HorizontalLift"
RNG = random.Random(20261018)

# ---------------------------------------------------------------- plan (metres, deck at Z 0, front -Y)
HX, HY = 1.00, 0.60                 # the net's 2.00 x 1.20 m rectangle (docs/12 2.8)
NX, NY = 10, 6                      # mesh cells: 0.20 x 0.20 m
CXX, CYY = 2 * HX / NX, 2 * HY / NY
TW = 0.012                          # net twine (docs/12 row: rope 0.012 to 0.016 m)
BOLT_D, LEG_D = 0.016, 0.016        # bolt rope and strop
KNOT_R = 0.0115                     # knot lump at every crossing (23 mm, resting on the deck)
RC = 0.14                           # bolt rope corner radius (a spliced net edge turns in a long bend)
SAG = 0.005                         # twine sags toward the deck between knots
FLAKE_C = (-(HX + 0.30), 0.02)      # flaked strop centre, beyond the head end
FLAKE_R0, FLAKE_R1, FLAKE_TURNS = 0.085, 0.210, 2.75
FREE_EYE = (-(HX + 0.12), -0.285)   # the strop's free eye lying on the deck
RING_C = (-(HX + 0.30), 0.02)       # master ring on deck in the middle of the flake (same centre)
RING_R, RING_T = 0.055, 0.008       # ring centreline radius and section radius (124 mm OD forging)
BAR_Z = 0.026                       # ring resting on the strop's eye
EYE_R, EYE_BOT, EYE_TOP = 0.028, 0.010, 0.052
EYE_THETA = math.radians(45.0)      # where the strop's eye sits on the ring
LIE_R = 0.038                       # the free eye lying flat on the deck
FLOAT_X = (-0.62, 0.02, 0.64)       # the three floats along the +Y edge
FLOAT_R, FLOAT_L, FLOAT_Y = 0.045, 0.075, 0.652
HANDLE_X = (-0.34, 0.38)            # the two webbing handles on the -Y edge
TAPE_AT = ((-0.86, 1), (0.16, 1), (-0.30, -1))
# triangle allocations (docs/12 row 3,000 with a little in hand)
T_NET_X, T_NET_Y, T_BOLT, T_STROP, T_EYE = 72, 48, 496, 176, 32
T_RING, T_SHACKLE, T_FLOAT, T_WEB, T_TAPE = 120, 152, 48, 80, 30
SEC_U = (0.0, 1.0, 0.90, 0.10)      # ribbon section u: bottom full width, top and sides inset
PARTS = []                          # (bucket, part, verts studs, faces, loop uvs, tris)
COUNTS = {}
PXM = maketex.PXM                   # fittings lane scale (px per metre)
LANE_UV = {"steel": (0.0, 0.5, 0.5, 1.0), "hdpe": (0.5, 0.5, 1.0, 1.0),
           "web": (0.0, 0.0, 0.5, 0.5), "retro": (0.5, 0.0, 1.0, 0.5)}
LANES = {}


# ---------------------------------------------------------------- helpers
def deck_z(x, y):
    """Height of the bolt rope and the knots lying on the deck: two soft waves, 12 to 18 mm (metres).
    The twine between the knots sags below this, so the net lies on the deck with the knots proud."""
    a = math.sin(1.35 * x + 0.55) * math.cos(2.05 * y + 1.25)
    b = math.sin(2.65 * x + 2.35) * math.cos(1.15 * y + 0.35)
    return 0.0120 + 0.0035 * (a + 1.0) + 0.0013 * (b + 1.0)


def node(i, j):
    """Net crossing (metres): border nodes sit exactly on the bolt rope, interior nodes wander."""
    x = -HX + i * CXX + (0.0 if i in (0, NX) else 0.014 * math.sin(1.7 * i + 2.3 * j + 0.4))
    y = -HY + j * CYY + (0.0 if j in (0, NY) else 0.014 * math.sin(2.9 * j + 1.3 * i + 1.7))
    return np.array([x, y, deck_z(x, y)])


def catmull(ctrl, n=6):
    """Uniform Catmull-Rom through the control points (metres), n samples per span."""
    P = [np.asarray(p, float) for p in ctrl]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    for i in range(len(P) - 3):
        p0, p1, p2, p3 = P[i:i + 4]
        for j in range(n):
            t = j / float(n)
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2])
    return np.array(out)


def emit(bucket, part, verts, faces, uvs, tris):
    PARTS.append((bucket, part, np.asarray(verts, float), [tuple(f) for f in faces], uvs, tris))
    COUNTS[part] = COUNTS.get(part, 0) + tris


def tube_part(bucket, part, points_m, diameter, sides, max_tris, caps=False, u_off=None):
    v, f, u, tris, _ = rope.tube(points_m, diameter, "plain", sides=sides, max_tris=max_tris, caps=caps)
    if u_off:
        u = [[(a + u_off, b) for a, b in poly] for poly in u]
    emit(bucket, part, v, f, u, tris)
    return tris


def knot_part(bucket, part, p_m, r=KNOT_R, u_off=None):
    v, f, u, tris = rope.knot(np.asarray(p_m, float) * S, r * S)
    if u_off:
        u = [[(a + u_off, b) for a, b in poly] for poly in u]
    emit(bucket, part, v, f, u, tris)


def place_uv(name, uvs, u_m, v_m):
    """Scale a part's 0..1 UVs to its real size at the lane scale and pack it into the lane (rows, top down)."""
    L = LANES.setdefault(name, {"cursor": [LANE_UV[name][0] + 0.015, LANE_UV[name][3] - 0.015]})
    x0, y0, x1, y1 = LANE_UV[name]
    w = max(u_m, 0.004) * PXM / maketex.SIZE
    h = max(v_m, 0.004) * PXM / maketex.SIZE
    cx, cy = L["cursor"]
    if cx + w > x1 - 0.015:
        cx, cy = x0 + 0.015, cy - h - 0.015
    L["cursor"] = [cx + w + 0.015, cy]
    return [[(cx + u * w, cy + v * h - h) for u, v in poly] for poly in uvs]


def lathe(profile, sides, origin_m, ax_u, ax_v, ax_w):
    """Revolve `profile` [(t along ax_w, radius)] into a closed solid (metres). Returns (verts, faces, uvs)."""
    verts, faces, uvs = [], [], []
    rings = len(profile)
    for i, (t, r) in enumerate(profile):
        centre = np.asarray(origin_m, float) + np.asarray(ax_w, float) * t
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append(centre + r * (math.cos(a) * np.asarray(ax_u, float) + math.sin(a) * np.asarray(ax_v, float)))
    for i in range(rings - 1):
        for k in range(sides):
            k1 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k1, (i + 1) * sides + k1, (i + 1) * sides + k))
            uvs.append(((k / float(sides), i / float(rings - 1)), ((k + 1) / float(sides), i / float(rings - 1)),
                        ((k + 1) / float(sides), (i + 1) / float(rings - 1)), (k / float(sides), (i + 1) / float(rings - 1))))
    for i, outward in ((0, False), (rings - 1, True)):          # cap discs (rope.tube UV convention: no slivers)
        centre = np.asarray(origin_m, float) + np.asarray(ax_w, float) * profile[i][0]
        ci = len(verts)
        verts.append(centre)
        vc = i / float(rings - 1)
        for k in range(sides):
            k1 = (k + 1) % sides
            a, b = i * sides + k, i * sides + k1
            faces.append((a, b, ci) if outward else (b, a, ci))
            ua = (0.5 + 0.24 * math.cos(2 * math.pi * k / sides), vc + 0.24 * math.sin(2 * math.pi * k / sides))
            ub = (0.5 + 0.24 * math.cos(2 * math.pi * k1 / sides), vc + 0.24 * math.sin(2 * math.pi * k1 / sides))
            uvs.append((ua, ub, (0.5, vc)) if outward else (ub, ua, (0.5, vc)))
    return np.array(verts), faces, uvs


# ---------------------------------------------------------------- the net
def net_lines(bucket="rope"):
    """Laced mesh: interior lines only (the bolt rope is the border), knotted at every crossing."""
    for j in range(1, NY):
        pts = []
        for i in range(NX):
            a, b = node(i, j), node(i + 1, j)
            m = (a + b) / 2.0
            m[2] -= SAG
            m[0] += 0.005 * math.sin(2.4 * i + 1.9 * j)
            m[1] += 0.005 * math.cos(1.8 * i + 2.6 * j)
            pts += [a, m]
        pts.append(node(NX, j))
        tube_part(bucket, "net_x", np.array(pts), TW, 3, T_NET_X, caps=False, u_off=RNG.random())
    for i in range(1, NX):
        pts = []
        for j in range(NY):
            a, b = node(i, j), node(i, j + 1)
            m = (a + b) / 2.0
            m[2] -= SAG * 0.8
            m[0] += 0.005 * math.sin(2.1 * i + 1.4 * j)
            m[1] += 0.005 * math.cos(2.7 * i + 0.9 * j)
            pts += [a, m]
        pts.append(node(i, NY))
        tube_part(bucket, "net_y", np.array(pts), TW, 3, T_NET_Y, caps=False, u_off=RNG.random())
    for i in range(NX + 1):
        for j in range(NY + 1):
            knot_part(bucket, "net_knot", node(i, j), KNOT_R, u_off=RNG.random())


def corner_pt(sx, sy, a0, k, n=6):
    cx, cy = sx * (HX - RC), sy * (HY - RC)
    a = a0 + (math.pi / 2) * k / n
    x, y = cx + RC * math.cos(a), cy + RC * math.sin(a)
    return (x, y, deck_z(x, y))


def bolt_rope(bucket="rope"):
    """Bolt rope: four straight runs through the border nodes, joined by four soft spliced corners."""
    pts = []

    def edge(axis, fixed, sign, node_axis):
        pts_ = []
        if axis == "x":
            mids = [-HX + i * CXX for i in range(NX + 1)]
            mids = [m for m in mids if abs(m) < HX - RC - 1e-9]
            coords = [(-(HX - RC), fixed)] + [(m, fixed) for m in mids] + [(HX - RC, fixed)]
        else:
            mids = [-HY + j * CYY for j in range(NY + 1)]
            mids = [m for m in mids if abs(m) < HY - RC - 1e-9]
            coords = [(fixed, -(HY - RC))] + [(fixed, m) for m in mids] + [(fixed, (HY - RC))]
        if sign < 0:
            coords = coords[::-1]
        return [(x, y, deck_z(x, y)) for x, y in coords]

    pts += edge("x", -HY, +1, NX)
    pts += [corner_pt(1, -1, -math.pi / 2, k) for k in range(1, 7)]
    pts += edge("y", HX, +1, NY)
    pts += [corner_pt(1, 1, 0.0, k) for k in range(1, 7)]
    pts += edge("x", HY, -1, NX)
    pts += [corner_pt(-1, 1, math.pi / 2, k) for k in range(1, 7)]
    pts += edge("y", -HX, -1, NY)
    pts += [corner_pt(-1, -1, math.pi, k) for k in range(1, 7)]
    tube_part(bucket, "bolt_rope", np.array(pts), BOLT_D, 4, T_BOLT, caps=False, u_off=RNG.random())
    for sx, sy, a0 in ((1, 1, 0.0), (1, -1, -math.pi / 2), (-1, 1, math.pi / 2), (-1, -1, math.pi)):
        knot_part(bucket, "corner_knot", corner_pt(sx, sy, a0, 3), 0.016, u_off=RNG.random())


# ---------------------------------------------------------------- the strop: eye, flake, free eye
def ring_pt(theta, r=RING_R):
    return np.array([RING_C[0] + r * math.cos(theta), RING_C[1] + r * math.sin(theta), BAR_Z])


def eye_over_ring(bucket, theta):
    """The strop's spliced eye round the ring's bar: up over the bar, back along the deck under it (closed loop)."""
    c = ring_pt(theta)
    rad = np.array([math.cos(theta), math.sin(theta), 0.0])
    pts = []
    n = 6
    for k in range(n + 1):
        a = math.pi * k / n
        pts.append(c + EYE_R * math.cos(a) * rad + np.array([0.0, 0.0, EYE_BOT + (EYE_TOP - EYE_BOT) * math.sin(a)]))
    for k in range(1, n):
        pts.append(c + EYE_R * (1.0 - 2.0 * k / float(n)) * rad + np.array([0.0, 0.0, EYE_BOT]))
    tube_part(bucket, "eye", np.array(pts), LEG_D, 4, T_EYE, caps=False, u_off=RNG.random())
    knot_part(bucket, "throat_knot", pts[0], 0.013, u_off=RNG.random())
    return pts[0]


def strop(bucket="rope"):
    """The eye over the ring, 2.75 turns of flat flake on the deck, then the run out to the free eye."""
    throat = eye_over_ring(bucket, EYE_THETA)
    pts = [tuple(throat)]
    n = int(FLAKE_TURNS * 24)
    for k in range(n + 1):                                  # spiral out from the ring over the deck
        t = k / float(n)
        a = EYE_THETA + 2 * math.pi * FLAKE_TURNS * t
        r = FLAKE_R0 + (FLAKE_R1 - FLAKE_R0) * t
        pts.append((FLAKE_C[0] + r * math.cos(a), FLAKE_C[1] + r * math.sin(a),
                    LEG_D / 2 + 0.0012 * math.sin(2.5 * a) + 0.0010 * t))
    a_end = EYE_THETA + 2 * math.pi * FLAKE_TURNS
    heel = (FLAKE_C[0] + FLAKE_R1 * math.cos(a_end), FLAKE_C[1] + FLAKE_R1 * math.sin(a_end), LEG_D / 2 + 0.001)
    pts += list(catmull([heel, (heel[0] + 0.03, heel[1] - 0.075, LEG_D / 2 + 0.002),
                         (FREE_EYE[0] + 0.055, FREE_EYE[1] + 0.085, LEG_D / 2 + 0.002),
                         (FREE_EYE[0] + LIE_R, FREE_EYE[1] + 0.004, LEG_D / 2 + 0.002)], 5)[1:])
    tube_part(bucket, "strop", np.array(pts), LEG_D, 4, T_STROP, caps=False, u_off=RNG.random())
    for k in range(8):                                      # free eye lying flat on the deck
        a = 2 * math.pi * k / 7
        pts.append((FREE_EYE[0] + LIE_R * math.cos(a), FREE_EYE[1] + LIE_R * math.sin(a), LEG_D / 2 + 0.001))
    pts = pts[-8:]
    tube_part(bucket, "eye", np.array(pts), LEG_D, 4, T_EYE, caps=False, u_off=RNG.random())
    knot_part(bucket, "throat_knot", pts[0], 0.013, u_off=RNG.random())


# ---------------------------------------------------------------- hardware, floats, webbing, tape
def ring_mesh():
    """Galvanised master ring: a torus lying flat on the deck."""
    nmaj, nmin = 12, 5
    verts, faces, uvs = [], [], []
    for a in range(nmaj):
        ta = 2 * math.pi * a / nmaj
        rad = np.array([math.cos(ta), math.sin(ta), 0.0])
        for b in range(nmin):
            tb = 2 * math.pi * b / nmin
            verts.append(ring_pt(ta) + RING_T * (math.cos(tb) * rad + np.array([0.0, 0.0, math.sin(tb)])))
            uvs.append((a / float(nmaj), b / float(nmin)))
    for a in range(nmaj):
        for b in range(nmin):
            a1, b1 = (a + 1) % nmaj, (b + 1) % nmin
            faces.append((a * nmin + b, a1 * nmin + b, a1 * nmin + b1, a * nmin + b1))
    uv_q = [[uvs[i] for i in f] for f in faces]
    return np.array(verts), faces, uv_q, 2 * nmaj * nmin


def shackle_parts():
    """16 mm galvanised bow shackle standing on its crown, the ring's bar sitting in the bow's opening."""
    out = []
    cx, cy = RING_C[0] - RING_R, RING_C[1]
    w, top, crown, rt = 0.020, 0.078, 0.031, 0.009
    arc = [(cx + w * math.cos(a), cy, crown - w * math.sin(a)) for a in np.linspace(math.pi, 0.0, 9)]
    pbow = [(cx - w, cy, top), (cx - w, cy, crown)] + arc + [(cx + w, cy, crown), (cx + w, cy, top)]
    v, f, u, tris, _ = rope.tube(pbow, 2 * rt, "plain", sides=4, max_tris=88, caps=False)
    out.append(("bow", v, f, u, tris, 0.06, 0.20))
    for sx in (-1, 1):                                              # lugs round the pin
        p = [(cx + sx * w - sx * 0.010, cy, top), (cx + sx * w + sx * 0.010, cy, top)]
        v, f, u, tris, _ = rope.tube(p, 0.026, "plain", sides=4, max_tris=16, caps=True)
        out.append(("lug", v, f, u, tris, 0.082, 0.020))
    p = [(cx - w - 0.021, cy, top), (cx + w + 0.021, cy, top)]      # screw pin
    v, f, u, tris, _ = rope.tube(p, 0.012, "plain", sides=4, max_tris=16, caps=True)
    out.append(("pin", v, f, u, tris, 0.038, 0.082))
    p = [(cx + w + 0.021, cy, top), (cx + w + 0.032, cy, top)]      # hex head on the pin
    v, f, u, tris, _ = rope.tube(p, 0.017, "plain", sides=4, max_tris=16, caps=True)
    out.append(("head", v, f, u, tris, 0.054, 0.011))
    return out


def floats(bucket="fit"):
    """Three SOLAS orange HDPE floats lashed to the buoyant (+Y) edge, each with a twine lashing."""
    axis = np.array([1.0, 0.0, 0.0])
    for x in FLOAT_X:
        c = np.array([x, FLOAT_Y, FLOAT_R])
        prof = [(0.0, FLOAT_R * 0.70), (0.009, FLOAT_R), (FLOAT_L - 0.009, FLOAT_R), (FLOAT_L, FLOAT_R * 0.70)]
        v, f, u = lathe(prof, 8, c - axis * (FLOAT_L / 2.0), np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 1.0]), axis)
        uvs = place_uv("hdpe", u, 2 * math.pi * FLOAT_R, FLOAT_L)
        emit(bucket, "float", v * S, f, uvs, 8 * (len(prof) - 1) * 2 + 2 * 8)
        lash = []
        for k in range(7):                                          # one twine lashing round float and edge rope
            a = 2 * math.pi * k / 6.0
            lash.append(c + (FLOAT_R + 0.007) * (math.cos(a) * np.array([0.0, 1.0, 0.0])
                                                 + math.sin(a) * np.array([0.0, 0.0, 1.0])))
        tube_part(bucket, "lashing", np.array(lash), 0.005, 3, 18, caps=False, u_off=RNG.random())


def handles(bucket="fit"):
    """Two 25 mm black webbing grab handles, lying flat on the deck at the -Y edge."""
    for x in HANDLE_X:
        ctrl = [(x - 0.014, -HY + 0.002, 0.020), (x - 0.020, -0.665, 0.006), (x - 0.014, -0.735, 0.004),
                (x + 0.014, -0.735, 0.004), (x + 0.020, -0.665, 0.006), (x + 0.014, -HY + 0.002, 0.020)]
        path = catmull(ctrl, 2)
        along = np.gradient(path, axis=0)
        along /= np.maximum(np.linalg.norm(along, axis=1, keepdims=True), 1e-9)
        wide = np.cross(along, np.array([0.0, 0.0, 1.0]))
        wide /= np.maximum(np.linalg.norm(wide, axis=1, keepdims=True), 1e-9)
        up = np.array([0.0, 0.0, 0.0013])
        verts, faces, uvs = [], [], []
        for p, w in zip(path, wide):
            verts += [p - w * 0.0125 - up, p + w * 0.0125 - up, p + w * 0.0125 + up, p - w * 0.0125 + up]
        segs = len(path) - 1
        for i in range(segs):
            for k in range(4):
                k1 = (k + 1) % 4
                faces.append((i * 4 + k, i * 4 + k1, (i + 1) * 4 + k1, (i + 1) * 4 + k))
                uvs.append([(SEC_U[k], i / float(segs)), (SEC_U[k1], i / float(segs)),
                            (SEC_U[k1], (i + 1) / float(segs)), (SEC_U[k], (i + 1) / float(segs))])
        out = place_uv("web", uvs, 0.025, 0.42)
        emit(bucket, "handle", np.array(verts) * S, faces, out, 2 * 4 * segs)


def tapes(bucket="fit"):
    """Retroreflective tape bands sewn round the bolt rope (a SOLAS casualty item carries them)."""
    for x, sy in TAPE_AT:
        NA, NW = 4, 6                                               # along the rope, across the wrap
        pts, uvs = [], []
        for k in range(NA):
            row, urow = [], []
            for m in range(NW):                                     # 180 degrees over the rope's outer half
                a = math.pi * (m / float(NW - 1) - 0.5)
                t = x - 0.032 + 0.064 * k / float(NA - 1)
                row.append(np.array([t, sy * (HY + 0.0085 * math.cos(a)), deck_z(t, sy * HY) + 0.0085 * math.sin(a)]))
                urow.append((k / float(NA - 1), m / float(NW - 1)))
            pts.append(np.array(row))
            uvs.append(urow)
        verts, faces, fuv = [], [], []
        for k in range(NA):
            for m in range(NW):
                verts.append(pts[k][m])
        for k in range(NA - 1):
            for m in range(NW - 1):
                i = k * NW + m
                faces.append((i, i + 1, i + NW + 1, i + NW))
                fuv.append([uvs[k][m], uvs[k][m + 1], uvs[k + 1][m + 1], uvs[k + 1][m]])
        out = place_uv("retro", fuv, 0.064, 0.05)
        emit(bucket, "tape", np.array(verts) * S, faces, out, 2 * (NA - 1) * (NW - 1))


# ---------------------------------------------------------------- scene assembly
def material(name, rgb, rough, metal):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


def assemble(name, parts, mat, offset):
    verts, faces, uvs, off = [], [], [], 0
    for _bucket, _part, v, f, u, _tris in parts:
        verts.extend(tuple(float(c) for c in p + offset) for p in v)
        faces.extend(tuple(int(i) + off for i in face) for face in f)
        uvs.extend(u)
        off += len(v)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    uvl = me.uv_layers.new(name=common.UV_NAME)
    flat = [c for poly in uvs for c in poly]
    uvl.data.foreach_set("uv", [x for c in flat for x in c])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.update()
    return ob


def box_col(name, lo, hi, offset):
    bm = bmesh.new()
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    vs = [bm.verts.new(((x + offset[0]) * S, (y + offset[1]) * S, (z + offset[2]) * S))
          for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
    for f in [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def att(name, p_m, offset_studs):
    """An empty at `p_m` metres, shifted by the bbox offset (already in studs)."""
    e = bpy.data.objects.new(name, None)
    e.location = tuple(c * S + o for c, o in zip(p_m, offset_studs))
    bpy.context.scene.collection.objects.link(e)
    return e


def tri_count(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


# ---------------------------------------------------------------- build
def build():
    maketex.write_all(NAME)

    ring_v, ring_f, ring_u, ring_t = ring_mesh()
    emit("fit", "ring", ring_v * S, ring_f, place_uv("steel", ring_u, 2 * math.pi * RING_R, 2 * math.pi * RING_T),
         ring_t)
    for name, v, f, u, tris, u_m, v_m in shackle_parts():
        emit("fit", "shackle", v, f, place_uv("steel", u, u_m, v_m), tris)

    net_lines("rope")
    bolt_rope("rope")
    strop("rope")
    floats("fit")
    handles("fit")
    tapes("fit")

    rope_parts = [p for p in PARTS if p[0] == "rope"]
    fit_parts = [p for p in PARTS if p[0] == "fit"]
    pts = np.concatenate([p[2] for p in PARTS])
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    off = np.array([-(lo[0] + hi[0]) / 2.0, -(lo[1] + hi[1]) / 2.0, -lo[2]], float)

    rope_ob = assemble(NAME + "_LOD0", rope_parts, material("MI_HorizontalLift_Rope", (0.72, 0.62, 0.30), 0.62, 0.0), off)
    fit_ob = assemble(NAME + "_Fittings_LOD0", fit_parts,
                      material("MI_HorizontalLift_Fittings", (0.45, 0.42, 0.38), 0.55, 0.0), off)
    col = box_col(NAME + "_COL", (-HX - 0.010, -HY - 0.055, 0.0), (HX + 0.010, HY + 0.080, 0.046), off)

    tr = sum(tri_count(o) for o in (rope_ob, fit_ob))
    print("[%s] parts: %s" % (NAME, ", ".join("%s %d" % kv for kv in sorted(COUNTS.items()))))
    print("[%s] LOD0 %d tris (rope %d, fittings %d), ceiling 3000" % (NAME, tr, tri_count(rope_ob), tri_count(fit_ob)))
    if tr > 3000:
        print("[%s] OVER BUDGET by %d" % (NAME, tr - 3000))

    atts = [att("ATT_Grip", (0.0, 0.0, 0.030), off),
            att("ATT_Corner_01", (HX, HY, 0.030), off), att("ATT_Corner_02", (HX, -HY, 0.030), off),
            att("ATT_Corner_03", (-HX, -HY, 0.030), off), att("ATT_Corner_04", (-HX, HY, 0.030), off),
            att("ATT_Lift", (RING_C[0], RING_C[1], BAR_Z), off),
            att("ATT_StropEnd", (FREE_EYE[0], FREE_EYE[1], 0.010), off),
            att("ATT_BuoyantEdge", (0.0, HY, 0.030), off)]
    dims = tuple(round(float(v), 3) for v in (hi - lo) / S)
    print("[%s] dims m %s" % (NAME, dims))

    def T(p):
        """Metres -> studs in the shifted build frame (off is in studs)."""
        return [float(p[0] * S + off[0]), float(p[1] * S + off[1]), float(p[2] * S + off[2])]

    return {
        "name": NAME,
        "budget": "large_prop",
        "tris": 3000,
        "tier": "hero",
        "dims_m": dims,
        "size_note": ("docs/12 gives the net itself as 2.0 x 1.2 m: dims_m is the net plus the strop laid out with "
                      "it, flaked on the deck 0.30 m beyond the head end, and the grab handles on the other edge"),
        "origin": "base",
        "sets": [{"name": "HorizontalLift", "set": "Rope", "size": maketex.SIZE, "wet": True},
                 {"name": "HorizontalLift", "set": "Fittings", "size": maketex.SIZE, "wet": True}],
        "atlas": None,
        "meshes": [{"object": rope_ob, "set": "Rope"}, {"object": fit_ob, "set": "Fittings"}, {"object": col}],
        "attachments": atts,
        "tiling": True,
        "lod_symmetry": None,
        "waivers": {"LOD UV layout": ("collapse decimation of thin rope tubes and the flaked strop moves UVs a "
                                      "little; every LOD samples the same tiling rope trim and fittings lanes")},
        "closeups": [
            {"name": "ring_strop", "target": T((RING_C[0], RING_C[1], 0.034)), "dist": 2.9, "az": 200.0, "el": 24.0},
            {"name": "net_knots", "target": T((0.18, -0.10, 0.020)), "dist": 2.2, "az": 35.0, "el": 26.0},
            {"name": "float_edge", "target": T((-0.62, FLOAT_Y, 0.045)), "dist": 2.0, "az": 20.0, "el": 28.0},
            {"name": "handles", "target": T((0.38, -0.70, 0.010)), "dist": 2.0, "az": 330.0, "el": 30.0},
            {"name": "tape_corner", "target": T((0.16, 0.60, 0.020)), "dist": 1.8, "az": 20.0, "el": 22.0},
        ],
    }
