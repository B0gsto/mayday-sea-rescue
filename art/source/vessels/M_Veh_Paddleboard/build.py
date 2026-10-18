"""C1 M_Veh_Paddleboard: a generic inflatable all-round stand-up paddleboard (SUP), 10'6" x 32" x 6" = 3.20 x 0.81 x
0.15 m (the common all-round iSUP size, not a replica), with its adjustable paddle and coiled leash. Op 1 (Person in the
Water): "Fell off a paddleboard"; the [L] two-casualty Drifting Craft variant (parent and child on a drifting board)
replaces the DriftingDinghy greybox with this board (ATT_Seat_01 / _02 at the dinghy's +-1.8 stud seats).

Drop-stitch PVC shell with a taped rail, grey EVA diamond-groove deck pad with a raised kick pad, centre carry handle,
nose bungee with 4 D-rings, valve, tail leash D-ring, US-box centre fin. Sun-faded PVC, scuffed rails and bottom.
Blender axes: X width (+X = port), Y length (nose -Y = Roblox -Z), Z up; pivot = centre of the base (fin tip).
MeshParts (one set T_Paddleboard_Craft): Board (shell, pad), Fittings (handle, D-rings, bungee, valve, fin), Leash
(coil + ankle cuff, hide or re-rig to the swimmer from ATT_Leash), Paddle (separate so it can float away).
Capsized state: rotate 180 deg about the length axis; the fin and the scuffed bottom face up.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C1"))
import c1geo as K  # noqa: E402
from c1geo import Buf, V, W, C  # noqa: E402

NAME = "M_Veh_Paddleboard"
BUDGET, BUDGET_TRIS = "small_craft", 1500
SETS = {"name": "Paddleboard", "sets": ("Craft",),
        "map": {"Board": "Craft", "Fittings": "Craft", "Leash": "Craft", "Paddle": "Craft"}}
PB = {"rail": (0.00, 0.18), "top": (0.18, 0.38), "bottom": (0.38, 0.56), "pad": (0.56, 0.76), "fin": (0.76, 0.82),
      "leash": (0.82, 0.88), "shaft": (0.88, 0.94), "blade": (0.94, 1.00)}
band = K.bandfn(PB)
L, T, RR, UT = 3.20, 0.15, 0.055, 3.4
FIN = 0.20                     # fin depth below the bottom
WL = FIN + 0.05


def Y(t):
    return -L / 2 + t * L


def hw(t):
    if t < 0.5:
        return 0.015 + 0.39 * math.sin(math.pi / 2 * (t / 0.5)) ** 0.62
    return 0.405 - 0.105 * ((t - 0.5) / 0.5) ** 2.4


def zb(t):
    return FIN + (0.11 * ((0.22 - t) / 0.22) ** 2 if t < 0.22 else 0.0)


def axis_out(c):
    return V(c.x, 0, c.z - (FIN + T / 2))


def stations(n, a=0.0, b=1.0):
    return [a + (b - a) * 0.5 * (1 - math.cos(math.pi * i / n)) for i in range(n + 1)]


def rail_pt(t, k, side):
    """Rail arc point k (0 top edge .. 6 bottom edge) on one side."""
    w, z0 = hw(t), zb(t)
    r = min(RR, w * 0.9)
    a = math.pi / 2 - math.pi * k / 6
    return V(side * (w - r + r * math.cos(a)), Y(t), z0 + T / 2 + (T / 2) * math.sin(a))


def build_board():
    b = Buf()
    ts = stations(16)
    for side in (1, -1):
        rows = [[rail_pt(t, k, side) for k in range(7)] for t in ts]
        uvs = [[((p.y + L / 2) / UT, PB["rail"][0] + 0.004 + 0.172 * k / 6) for k, p in enumerate(r)] for r in rows]
        K.ogrid(b, rows, uvs, axis_out)
    for key, k, want in (("top", 0, (0, 0, 1)), ("bottom", 6, (0, 0, -1))):
        rows, uvs = [], []
        for t in ts:
            pa, pb = rail_pt(t, k, -1), rail_pt(t, k, 1)
            r = [pa.lerp(pb, j / 3) for j in range(4)]
            rows.append(r)
            uvs.append([((p.y + L / 2) / UT, PB[key][0] + 0.004 + 0.192 * j / 3) for j, p in enumerate(r)])
        K.ogrid(b, rows, uvs, want)
    # tail cap
    ring = [rail_pt(1.0, k, 1) for k in range(7)] + [rail_pt(1.0, k, -1) for k in reversed(range(7))]
    c = sum(ring, V(0, 0, 0)) / len(ring)
    for i in range(len(ring)):
        p, q = ring[i], ring[(i + 1) % len(ring)]
        K.oface(b, [p, q, c], [((p.x + 1) / UT, PB["rail"][0] + 0.01 + 0.16 * (p.z - FIN) / T),
                               ((q.x + 1) / UT, PB["rail"][0] + 0.01 + 0.16 * (q.z - FIN) / T), (1 / UT, PB["rail"][0] + 0.09)], (0, 1, 0))
    # EVA deck pad (t 0.36 .. 0.97) and kick pad
    rows, uvs = [], []
    tp = stations(10, 0.36, 0.97)
    for t in tp:
        w = hw(t) - 0.075
        z = zb(t) + T + 0.007
        r = [V(-w + 2 * w * j / 3, Y(t), z) for j in range(4)]
        rows.append(r)
        uvs.append([((p.y + L / 2) / 1.4, PB["pad"][0] + 0.004 + 0.192 * j / 3) for j, p in enumerate(r)])
    K.ogrid(b, rows, uvs, (0, 0, 1), smooth=False)
    for side in (1, -1):    # pad edge bevel
        r0 = [V(side * (hw(t) - 0.075), Y(t), zb(t) + T + 0.007) for t in tp]
        r1 = [V(side * (hw(t) - 0.070), Y(t), zb(t) + T) for t in tp]
        K.ogrid(b, [[a, c2] for a, c2 in zip(r0, r1)], [[((a.y + L / 2) / 1.4, PB["pad"][0] + 0.004), ((a.y + L / 2) / 1.4, PB["pad"][0] + 0.012)]
                                                     for a in r0], (side, 0, 0.5), smooth=False)
    t = 0.935
    w = hw(t) - 0.09
    z = zb(t) + T + 0.007
    K.slab(b, [V(-w, Y(t) - 0.04, z + 0.035), V(w, Y(t) - 0.04, z + 0.035), V(w, Y(t) + 0.05, z + 0.035), V(-w, Y(t) + 0.05, z + 0.035)],
           0.035, lambda p: ((p.y + L / 2) / 1.4 + p.z, PB["pad"][0] + 0.004 + 0.192 * (p.x + w) / (2 * w)), out=(0, 0, 1))
    return b


def dring(b, p, along):
    W.ring(b, p + V(0, 0, 0.018), V(*along), (0, 0, 1), 0.016, 0.004, 6, 3, band("fin", 0.3))
    return
    K.slab(b, [p + V(-0.03, -0.025, 0.003), p + V(0.03, -0.025, 0.003), p + V(0.03, 0.025, 0.003), p + V(-0.03, 0.025, 0.003)], 0.003,
           lambda q: (q.x * 3, PB["fin"][0] + 0.01 + (q.y % 0.05)), out=(0, 0, 1))


def build_fittings():
    b = Buf()
    top = lambda t: zb(t) + T
    # centre carry handle (padded strap over two patches)
    tc = 0.52
    C.tube(b, [V(-0.09, Y(tc), top(tc) + 0.004), V(-0.06, Y(tc), top(tc) + 0.035), V(0.06, Y(tc), top(tc) + 0.035),
               V(0.09, Y(tc), top(tc) + 0.004)], 0.016, band("fin", 1.0), sides=6)
    # nose bungee with 4 D-rings, valve, tail leash D-ring
    ds = [V(sx * (hw(t) - 0.07), Y(t), top(t)) for t in (0.14, 0.30) for sx in (1, -1)]
    for p in ds:
        dring(b, p, (1, 0, 0))
    C.tube(b, [ds[0] + V(0, 0, 0.02), ds[3] + V(0, 0, 0.02), ds[2] + V(0, 0, 0.02), ds[1] + V(0, 0, 0.02), ds[0] + V(0, 0, 0.02)],
           0.004, band("leash", 1.0), sides=4)
    vt = 0.07
    C.tube(b, [V(0, Y(vt), top(vt) - 0.003), V(0, Y(vt), top(vt) + 0.012)], 0.03, band("fin", 0.3), sides=10)
    dring(b, V(0, Y(0.985), top(0.985)), (1, 0, 0))
    # US-box centre fin (raked, with a box) under the tail
    yf = Y(0.90)
    K.slab(b, [V(0.004, yf - 0.10, FIN), V(0.004, yf + 0.10, FIN), V(0.004, yf + 0.16, 0.0), V(0.004, yf + 0.09, 0.0)], 0.008,
           lambda p: ((p.y + 2) * 2, PB["fin"][0] + 0.006 + 0.048 * (p.z / FIN)), out=(1, 0, 0))
    K.slab(b, [V(-0.02, yf - 0.14, FIN + 0.004), V(0.02, yf - 0.14, FIN + 0.004), V(0.02, yf + 0.14, FIN + 0.004),
               V(-0.02, yf + 0.14, FIN + 0.004)], 0.01, lambda p: ((p.y + 2) * 2, PB["fin"][0] + 0.03), out=(0, 0, -1))
    return b


def build_leash():
    b = Buf()
    t0 = 0.985
    p0 = V(0, Y(t0), zb(t0) + T + 0.02)
    # coiled TPU cord (helix) lying on the pad from the tail D-ring forward, then the ankle cuff
    pts = [p0, p0 + V(0.04, -0.06, 0.01)]
    n = 30
    for i in range(n + 1):
        a = i / n * 2 * math.pi * 9
        c = p0 + V(0.10, -0.10 - 0.50 * i / n, 0.025)
        pts.append(c + V(0.022 * math.cos(a), 0, 0.022 * math.sin(a)) + V(0.03 * math.sin(i / n * 3), 0, 0))
    C.tube(b, pts, 0.004, band("leash", 1.0), sides=3, caps=(True, True))
    cuff = pts[-1] + V(0.0, -0.09, 0.0)
    W.ring(b, cuff + V(0, 0, 0.0), (1, 0, 0), (0, 1, 0), 0.055, 0.016, 10, 4, band("fin", 1.0))
    return b, p0, cuff


def build_paddle():
    b = Buf()
    x = -0.20
    z = lambda t: zb(t) + T + 0.025
    ya, yb = Y(0.33), Y(0.33) + 2.10
    C.tube(b, [V(x, ya + 0.45, z(0.4)), V(x, yb - 0.05, z(0.9))], 0.0145, band("shaft", 1.0), sides=8)
    C.tube(b, [V(x - 0.06, yb - 0.04, z(0.95) + 0.005), V(x + 0.06, yb - 0.04, z(0.95) + 0.005)], 0.017, band("fin", 0.3), sides=6)   # T-grip
    C.tube(b, [V(x, ya + 1.10, z(0.6)), V(x, ya + 1.22, z(0.6))], 0.019, band("fin", 0.3), sides=8)   # adjuster clamp
    zz = z(0.36)
    blade = [V(x - 0.085, ya, zz), V(x + 0.085, ya, zz), V(x + 0.055, ya + 0.46, zz), V(x - 0.055, ya + 0.46, zz)]
    K.slab(b, blade, 0.012, lambda p: ((p.y + 2) * 1.2, PB["blade"][0] + 0.004 + 0.052 * min(max((p.x - x + 0.09) / 0.18, 0), 1)),
           out=(0, 0, 1))
    return b


def build():
    C.clear_scene()
    parts = {}
    lb, ld, cuff = build_leash()
    for k, buf in (("Board", build_board()), ("Fittings", build_fittings()), ("Leash", lb), ("Paddle", build_paddle())):
        parts[k] = buf.to_object("%s_%s_LOD0" % (NAME, k), K.mat(NAME, SETS, k))
    K.finish(NAME, parts, recalc=("Fittings", "Leash", "Paddle"))
    top = lambda t: zb(t) + T + 0.007
    atts = [W.empty("ATT_Waterline", (0, 0, WL)),
            W.empty("ATT_Seat_01", (0, Y(0.5) - 0.60, top(0.31))),
            W.empty("ATT_Seat_02", (0, Y(0.5) + 0.60, top(0.69)), look=(0, 1, 0)),
            W.empty("ATT_Stand", (0, Y(0.52), top(0.52))),
            W.empty("ATT_Handle", (0, Y(0.52), top(0.52) + 0.03)),
            W.empty("ATT_Tow_Nose", (0, Y(0.14), top(0.14) + 0.02)),
            W.empty("ATT_Leash", tuple(ld), look=(0, 1, 0)),
            W.empty("ATT_Leash_Cuff", tuple(cuff)),
            W.empty("ATT_Paddle", (-0.20, Y(0.33) + 1.05, top(0.6) + 0.02)),
            W.empty("ATT_Boarding_Port", (hw(0.5), Y(0.5), FIN + T / 2), look=(1, 0, 0)),
            W.empty("ATT_Boarding_Stbd", (-hw(0.5), Y(0.5), FIN + T / 2), look=(-1, 0, 0)),
            W.empty("ATT_Fin", (0, Y(0.90), FIN / 2))]
    I = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    col = W.col_boxes([((0, 0, FIN + T / 2), I, (0.39, 1.56, T / 2))], NAME + "_COL")
    return K.spec(NAME, BUDGET, BUDGET_TRIS, parts, SETS, atts, col, (0.81, 3.2, None))
