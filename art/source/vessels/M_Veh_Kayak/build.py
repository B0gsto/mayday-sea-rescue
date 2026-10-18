"""C1 M_Veh_Kayak: a generic rotomoulded polyethylene sit-on-top recreational kayak, 3.47 x 0.79 m (Old Town Ocean
Malibu 11.5 class, not a replica), sun-faded red, with its double paddle. Op 1 (Person in the Water) casualty context:
"fell off a kayak" / drifting craft beside the swimmer; the jet ski tows kayaks [L].

Moulded seat well with scupper holes, padded seat and backrest strap, footwell with foot-rest steps, bow hatch, rear tank
well with bungee criss-cross, bow / stern toggle handles (tow points), side carry handles, paddle keeper. Blender axes:
X width (+X = port), Y length (bow -Y = Roblox -Z), Z up; pivot = centre of the base. MeshParts (one set T_Kayak_Craft):
Hull (shell + deck), Fittings (seat pad, backrest, bungee, handles, hatch, scuppers), Paddle (separate so it can float
away from the kayak). Capsized state: rotate 180 deg about the length axis about ATT_Waterline; the scuffed keel and
tracking channels read from above.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C1"))
import c1geo as K  # noqa: E402
from c1geo import Buf, V, W, C  # noqa: E402

NAME = "M_Veh_Kayak"
BUDGET, BUDGET_TRIS = "small_craft", 3000
SETS = {"name": "Kayak", "sets": ("Craft",), "map": {"Hull": "Craft", "Fittings": "Craft", "Paddle": "Craft"}}
KB = {"hull": (0.00, 0.30), "deck": (0.30, 0.55), "pad": (0.55, 0.65), "cord": (0.65, 0.72), "black": (0.72, 0.80),
      "shaft": (0.80, 0.88), "blade": (0.88, 1.00)}
band = K.bandfn(KB)
L, WL, UT = 3.25, 0.10, 3.4      # hull 3.25 m; 3.47 m over the toggle handles


def Y(t):
    return -L / 2 + t * L


def hw(t):
    return 0.012 + 0.353 * (4 * t * (1 - t)) ** 0.45


def zb(t):
    return 0.14 * abs(2 * t - 1) ** 2.6


def ze(t):
    return 0.27 + 0.07 * abs(2 * t - 1) ** 2.2


def well(x, t):
    """Depth of the moulded wells below the crowned deck at (x, t)."""
    def win(a, b, e):
        if t <= a - e or t >= b + e:
            return 0.0
        if t < a + e:
            return (t - a + e) / (2 * e)
        if t > b - e:
            return (b + e - t) / (2 * e)
        return 1.0
    sx = lambda wd: max(0.0, min(1.0, (wd - abs(x)) / 0.05))
    seat = win(0.47, 0.74, 0.04) * sx(0.25)
    foot = win(0.27, 0.47, 0.04) * sx(0.21)
    tank = win(0.79, 0.93, 0.03) * sx(0.22)
    steps = 0.02 * (math.sin(t * 160) > 0.6) * foot
    return max(seat * 0.20, foot * (0.15 - steps), tank * 0.09)


def hull_pt(t, s, side):
    w, b, e = hw(t), zb(t), ze(t)
    if s <= 0.35:
        u = s / 0.35
        x, z = 0.72 * w * u, b + 0.006 * u - (0.012 * (1 - u / 0.25) if u < 0.25 else 0.0)
    elif s <= 0.65:
        ph = (s - 0.35) / 0.30 * math.pi / 2
        x, z = 0.72 * w + 0.28 * w * math.sin(ph), b + 0.006 + 0.07 * (1 - math.cos(ph))
    else:
        u = (s - 0.65) / 0.35
        x, z = w * (1 - 0.05 * u), b + 0.076 + (e - b - 0.076) * u
    return V(side * x, Y(t), z)


def axis_out(c):
    return V(c.x, 0, c.z - 0.16)


def stations(n, a=0.0, b=1.0):
    return [a + (b - a) * 0.5 * (1 - math.cos(math.pi * i / n)) for i in range(n + 1)]


def deck_z(x, t):
    w = hw(t)
    return ze(t) + 0.055 * (1 - min(abs(x) / w, 1) ** 2) - well(x, t)


def build_hull():
    b = Buf()
    ts = stations(22)
    ss = [j / 9 for j in range(10)]
    for side in (1, -1):
        rows = [[hull_pt(t, s, side) for s in ss] for t in ts]
        uvs = [[((p.y + L / 2) / UT, KB["hull"][0] + 0.004 + 0.292 * s) for p, s in zip(r, ss)] for r in rows]
        K.ogrid(b, rows, uvs, axis_out)
    ts = sorted(set(round(t, 4) for t in stations(16) + [0.27, 0.47, 0.74, 0.79, 0.93] + [k / 34 for k in range(8, 33)]))
    rows, uvs = [], []
    for t in ts:
        w = hw(t) * 0.95
        r = [V(-w + 2 * w * j / 9, Y(t), 0) for j in range(10)]
        r[0] = V(-hw(t) * 0.95, Y(t), ze(t))
        r[-1] = V(hw(t) * 0.95, Y(t), ze(t))
        r = [V(p.x, p.y, deck_z(p.x, t)) if 0 < j < 9 else p for j, p in enumerate(r)]
        rows.append(r)
        uvs.append([((p.y + L / 2) / UT, KB["deck"][0] + 0.004 + 0.242 * j / 9) for j, p in enumerate(r)])
    K.ogrid(b, rows, uvs, (0, 0, 1))
    return b


def build_fittings():
    b = Buf()
    # seat pad and backrest
    yA, yB = Y(0.52), Y(0.70)
    pz = deck_z(0, 0.60)
    pad = lambda p: ((p.y + 2) * 1.6, KB["pad"][0] + 0.006 + 0.088 * min(max((p.x + 0.22) / 0.44, 0), 1))
    K.slab(b, [V(-0.21, yA, pz + 0.025), V(0.21, yA, pz + 0.025), V(0.21, yB, pz + 0.025), V(-0.21, yB, pz + 0.025)], 0.025, pad,
           out=(0, 0, 1))
    K.slab(b, [V(-0.20, Y(0.715), pz + 0.04), V(0.20, Y(0.715), pz + 0.04), V(0.19, Y(0.745), pz + 0.32), V(-0.19, Y(0.745), pz + 0.32)],
           0.03, lambda p: (p.x * 1.5, KB["pad"][0] + 0.006 + 0.088 * min(max((p.z - pz) / 0.32, 0), 1)), out=(0, -1, 0.2))
    for sx in (1, -1):   # backrest straps to the side clips
        C.tube(b, [V(sx * 0.19, Y(0.74), pz + 0.28), V(sx * 0.27, Y(0.70), deck_z(0.27, 0.70) + 0.03),
                   V(sx * 0.30, Y(0.66), deck_z(0.30, 0.66) + 0.01)], 0.008, band("cord", 0.5), sides=4)
    # scupper holes (dark plugs) in the seat and foot wells
    for (x, t) in ((-0.10, 0.50), (0.10, 0.50), (-0.12, 0.66), (0.12, 0.66), (0, 0.32)):
        z = deck_z(x, t) + 0.003
        pts = [V(x + 0.022 * math.cos(a), Y(t) + 0.022 * math.sin(a), z) for a in [2 * math.pi * k / 8 for k in range(8)]]
        K.oface(b, pts, [(0.5 + 0.02 * math.cos(2 * math.pi * k / 8), KB["black"][0] + 0.04 + 0.03 * math.sin(2 * math.pi * k / 8))
                         for k in range(8)], (0, 0, 1))
    # rear tank-well bungee criss-cross with deck loops
    zt = lambda x, t: deck_z(x, t) + 0.035
    pts = []
    for k, t in enumerate([0.78, 0.82, 0.86, 0.90, 0.94]):
        x = 0.22 * (1 if k % 2 == 0 else -1)
        pts.append(V(x, Y(t), zt(x, t)))
    C.tube(b, pts, 0.005, band("cord", 1.0), sides=4)
    C.tube(b, [V(-p.x, p.y, p.z) for p in pts], 0.005, band("cord", 1.0), sides=4)
    for p in pts:
        for sx in (1, -1):
            C.tube(b, [V(sx * abs(p.x), p.y, p.z - 0.03), V(sx * abs(p.x), p.y, p.z + 0.005)], 0.012, band("black", 0.3), sides=4)
    # bow hatch (round, 25 cm) with a rim
    hc = V(0, Y(0.17), deck_z(0, 0.17))
    W.ring(b, hc + V(0, 0, 0.012), (1, 0, 0), (0, 1, 0), 0.13, 0.016, 16, 4, band("black", 1.0))
    pts = [hc + V(0.125 * math.cos(2 * math.pi * k / 16), 0.125 * math.sin(2 * math.pi * k / 16), 0.024) for k in range(16)]
    K.oface(b, pts, [(0.5 + 0.06 * math.cos(2 * math.pi * k / 16), KB["black"][0] + 0.04 + 0.035 * math.sin(2 * math.pi * k / 16))
                     for k in range(16)], (0, 0, 1))
    # bow / stern toggle handles on cord loops, side carry handles, paddle keeper
    for t, dy in ((0.0, -1), (1.0, 1)):
        end = V(0, Y(t) + dy * 0.01, ze(t) - 0.02)
        loop = [end + V(-0.02, -dy * 0.03, 0.01), end + V(-0.03, dy * 0.05, -0.04), end + V(0, dy * 0.09, -0.08),
                end + V(0.03, dy * 0.05, -0.04), end + V(0.02, -dy * 0.03, 0.01)]
        C.tube(b, loop, 0.005, band("cord", 0.5), sides=4)
        C.tube(b, [end + V(-0.06, dy * 0.09, -0.08), end + V(0.06, dy * 0.09, -0.08)], 0.014, band("black", 0.4), sides=6)
    for sx in (1, -1):
        t = 0.60
        x = sx * (hw(t) * 0.99)
        z = ze(t) - 0.08
        C.tube(b, [V(x, Y(t) - 0.09, z + 0.03), V(x + sx * 0.02, Y(t) - 0.06, z - 0.01), V(x + sx * 0.02, Y(t) + 0.06, z - 0.01),
                   V(x, Y(t) + 0.09, z + 0.03)], 0.012, band("black", 0.6), sides=6)
    C.tube(b, [V(0.26, Y(0.44), deck_z(0.26, 0.44) + 0.01), V(0.30, Y(0.44), deck_z(0.30, 0.44) + 0.05),
               V(0.34, Y(0.44), deck_z(0.34, 0.44) + 0.01)], 0.007, band("cord", 0.3), sides=4)
    return b


def build_paddle():
    b = Buf()
    x, z = 0.30, deck_z(0.30, 0.45) + 0.03
    ya, yb = Y(0.20), Y(0.84)
    C.tube(b, [V(x, ya + 0.40, z), V(x, yb - 0.40, z)], 0.0155, band("shaft", 1.0), sides=8)
    C.tube(b, [V(x, -0.16, z), V(x, 0.16, z)], 0.0185, band("black", 1.0), sides=8)       # ferrule / drip rings
    for yc, fe in ((ya + 0.22, 1), (yb - 0.22, -1)):
        ang = math.radians(60) * fe
        sd = V(math.cos(ang), 0, math.sin(ang)) * 0.09
        tip = V(x, yc + fe * 0.0, z)
        quad = [tip - sd + V(0, -0.22, 0), tip + sd * 0.8 + V(0, -0.22, 0), tip + sd + V(0, 0.22, 0), tip - sd * 0.85 + V(0, 0.22, 0)]
        nrm = V(-math.sin(ang), 0, math.cos(ang))
        K.slab(b, [q + nrm * 0.005 for q in quad], 0.010,
               lambda p: ((p.y + 2) * 1.8, KB["blade"][0] + 0.006 + 0.108 * min(max((p - tip).dot(sd.normalized()) / 0.18 + 0.5, 0), 1)),
               out=nrm)
    return b


def build():
    C.clear_scene()
    parts = {}
    for k, buf in (("Hull", build_hull()), ("Fittings", build_fittings()), ("Paddle", build_paddle())):
        parts[k] = buf.to_object("%s_%s_LOD0" % (NAME, k), K.mat(NAME, SETS, k))
    K.finish(NAME, parts, recalc=("Paddle",))
    pz = deck_z(0, 0.60)
    atts = [W.empty("ATT_Waterline", (0, 0, WL)),
            W.empty("ATT_Seat", (0, Y(0.62), pz + 0.05)),
            W.empty("ATT_Tow_Bow", (0, Y(0.0) - 0.08, ze(0.0) - 0.10)),
            W.empty("ATT_Tow_Stern", (0, Y(1.0) + 0.08, ze(1.0) - 0.10), look=(0, 1, 0)),
            W.empty("ATT_Grab_Port", (hw(0.6) + 0.02, Y(0.60), ze(0.6) - 0.09), look=(1, 0, 0)),
            W.empty("ATT_Grab_Stbd", (-(hw(0.6) + 0.02), Y(0.60), ze(0.6) - 0.09), look=(-1, 0, 0)),
            W.empty("ATT_Boarding_Port", (hw(0.58), Y(0.58), ze(0.58)), look=(1, 0, 0)),
            W.empty("ATT_Boarding_Stbd", (-hw(0.58), Y(0.58), ze(0.58)), look=(-1, 0, 0)),
            W.empty("ATT_Paddle", (0.30, Y(0.52), deck_z(0.30, 0.45) + 0.03))]
    I = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    col = W.col_boxes([((0, 0, 0.17), I, (0.38, 1.62, 0.16))], NAME + "_COL")
    return K.spec(NAME, BUDGET, BUDGET_TRIS, parts, SETS, atts, col, (0.79, 3.47, None))
