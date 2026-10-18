"""C2 M_Veh_GaleQueen: the *Gale Queen*, a small island passenger ferry (generic design, not a replica), the casualty
vessel of the Capsized Ferry operation (docs/09 section 7, docs/12 2.1). Replaces RescueService.buildFerry's part-built
greybox (Hull 16 x 7 x 60 studs + Keel, Deckhouse, Bridge, Funnel, 5 LifeRaft cylinders); one model serves upright and
capsized: the op rolls it 72 deg (f.tilt) onto the Roblox -X side, so the bottom, bilge keels, running gear and the
Roblox +X (Blender -X) bilge carry the read: faded red antifouling, slime, weed, barnacles, grab lines.

Steel monohull 21.0 m LOA, 6.0 m moulded beam (6.24 m over the D-fenders), design draught 1.75 m (keel bar to the
waterline), white superstructure: passenger saloon on the main deck with windows, wheelhouse on the saloon roof (upper
deck), mast + radar, small funnel, four 12-person liferaft canisters on cradles, lifebuoys, railings, bulwarks with
boarding gates, external stair, windlass, bitts, twin screws and rudders, bow thruster.

Pivot = centre of the base (keel bar bottom); waterline 1.75 m = 5.25 studs above (ATT_Waterline). Bow at -Y.
MeshParts (one material each, all <= 10k tris): Hull (shell + transom; its bbox length = the knock axis) and
HullGear (keel bar, bilge keels, rudders, A-brackets, thruster) on T_GaleQueen_Hull; Props + Anodes on Fittings;
Bulwark, Saloon, Wheelhouse, Funnel on Super; Decks on Deck; Windows on Glass; Rails, Rafts, Mast, DeckGear, Fenders,
GrabLines on Fittings; Decals on Decals (AlphaMode Transparency).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../_C2"))
import c2geo as C  # noqa: E402
from c2geo import Buf, V, W  # noqa: E402

NAME = "M_Veh_GaleQueen"
BUDGET, BUDGET_TRIS = "big_ship", 90000
L, BMAX, WL = 21.0, 3.0, 1.75
KEEL = 0.30                      # bar keel depth below the canoe body
HULL_UV = 6.0                    # T_GaleQueen_Hull U tile (m)
SUP = ("tile", 4.0, 2.5)
DECK = ("tile", 4.0, 4.0)
rnd = random.Random(1975)


def band(name, tu=1.0):
    import importlib.util
    v0, v1 = FIT_BANDS[name]
    return ("strip", v0 + 0.004, v1 - 0.004, tu)


FIT_BANDS = {"rail_white": (0.000, 0.125), "galv": (0.125, 0.250), "rubber": (0.250, 0.375), "grp": (0.375, 0.500),
             "bronze": (0.500, 0.625), "orange": (0.625, 0.750), "rope": (0.750, 0.875), "machinery": (0.875, 1.000)}
DECALS = {"name": (0.02, 0.80, 0.98, 0.98), "port": (0.02, 0.62, 0.98, 0.78), "draught": (0.02, 0.02, 0.22, 0.60),
          "muster": (0.26, 0.40, 0.60, 0.60), "raft": (0.64, 0.40, 0.98, 0.60), "crew": (0.26, 0.22, 0.60, 0.38),
          "pax": (0.64, 0.22, 0.98, 0.38), "imo": (0.26, 0.04, 0.98, 0.18)}


# ------------------------------------------------------------------ hull form (metres, keel-bar bottom z = 0)
def U_(y):
    return (y + L / 2) / L


def zb(u):        # canoe-body bottom at the centreline
    return KEEL + 1.65 * max(0.0, 1 - u / 0.22) ** 2 + 0.85 * max(0.0, (u - 0.72) / 0.28) ** 2


def zs(u):        # sheer (main deck edge)
    return 3.30 + 1.0 * max(0.0, 1 - u / 0.30) ** 2


def bd(u):        # deck half-breadth
    if u < 0.5:
        return max(0.03, BMAX * (1 - (1 - u / 0.5) ** 2.0) ** 0.55)
    if u > 0.6:
        return BMAX * (1 - 0.10 * ((u - 0.6) / 0.4) ** 2)
    return BMAX


def bh(u):        # half-breadth at the top of the bilge (flare forward)
    return bd(u) * (1 - 0.24 * max(0.0, 1 - u / 0.42))


def zk(u):
    return max(zb(u) + 0.25, min(zb(u) + 1.25, zs(u) - 0.6))


def nexp(u):
    return 1.35 + 1.45 * min(1.0, u / 0.36) + 0.5 * max(0.0, (u - 0.7) / 0.3)


def stem_shift(u, z):
    """Raked stem + cut-away forefoot: points low at the bow move aft."""
    if u >= 0.2:
        return 0.0
    return 1.5 * max(0.0, (zs(u) - z) / zs(u)) * (1 - u / 0.2) ** 1.5


NB, NT = 22, 8


def half_section(u):
    """Points (x >= 0, z) from the keel centreline to the sheer, with girth s."""
    pts = []
    n = nexp(u)
    b, z0, z1 = bh(u), zb(u), zk(u)
    for j in range(NB + 1):
        ph = (math.pi / 2) * j / NB
        x = b * math.sin(ph) ** (2 / n)
        z = z0 + (z1 - z0) * (1 - math.cos(ph) ** (2 / n))
        pts.append((x, z))
    for j in range(1, NT + 1):
        t = j / NT
        pts.append((b + (bd(u) - b) * t ** 1.4, z1 + (zs(u) - z1) * t))
    return pts


def hull_v(pts, u):
    s = [0.0]
    for a, b in zip(pts, pts[1:]):
        s.append(s[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    swl = None
    for k in range(1, len(pts)):
        if pts[k - 1][1] < WL <= pts[k][1]:
            t = (WL - pts[k - 1][1]) / (pts[k][1] - pts[k - 1][1])
            swl = s[k - 1] + t * (s[k] - s[k - 1])
            break
    out = []
    for (x, z), sk in zip(pts, s):
        if z < WL and swl:
            out.append(0.5 * min(sk, swl) / swl)
        else:
            out.append(min(0.5 + 0.5 * (z - WL) / max(zs(u) - WL, 0.3), 0.97))
    return out


def surface_x(u, z):
    """Hull half-breadth at height z (topside or bilge), for decals and lines on the shell."""
    pts = half_section(u)
    for a, b in zip(pts, pts[1:]):
        if a[1] <= z <= b[1]:
            t = (z - a[1]) / max(b[1] - a[1], 1e-6)
            return a[0] + t * (b[0] - a[0])
    return pts[-1][0]


def stations(n):
    out = []
    for i in range(n):
        t = i / (n - 1)
        out.append(0.004 + 0.996 * (t ** 1.35))      # denser at the bow
    return out


def build_hull():
    b = Buf()
    us = stations(52)
    rows, uvs = [], []
    for u in us:
        hs = half_section(u)
        vs = hull_v(hs, u)
        full = [(x, z, v) for (x, z), v in zip(hs[::-1], vs[::-1])] + [(-x, z, v) for (x, z), v in zip(hs[1:], vs[1:])]
        y0 = -L / 2 + u * L
        rows.append([V(x, y0 + stem_shift(u, z), z) for x, z, _ in full])
        uvs.append([(y0 / HULL_UV, v) for _, _, v in full])
    C.grid(b, rows, uvs, smooth=True)
    # stem: close the bow (u = 0.004) with a thin strip to the centreline
    first = rows[0]
    ci = [b.add_vert(V(0, p.y - 0.02, p.z)) for p in first]
    k = len(first)
    base_idx = 0
    for j in range(k - 1):
        jj = k - 1 - j
        pass
    # transom (flat, last station): fan from its centre
    last = rows[-1]
    u = us[-1]
    zc = (zb(u) + zs(u)) / 2
    c = b.add_vert(V(0, last[0].y, zc))
    start = len(b.v) - 1 - len(ci) - 1
    li = [len(b.v) - 1 - len(ci) - 1 - (len(last) - 1 - j) for j in range(len(last))]
    # indices of the last grid row: grid() added rows sequentially -> row r starts at r * len(row)
    rlen = len(last)
    li = [(len(rows) - 1) * rlen + j for j in range(rlen)]
    for j in range(rlen - 1):
        p0, p1 = b.v[li[j]], b.v[li[j + 1]]
        vz = lambda p: 0.5 * max(0.0, p.z - zb(u)) / max(WL - zb(u), 0.1) if p.z < WL else 0.5 + 0.5 * (p.z - WL) / (zs(u) - WL)
        b.face([li[j + 1], li[j], c], [(p1.x / HULL_UV, vz(p1)), (p0.x / HULL_UV, vz(p0)), (0, vz(b.v[c]))], False)
    # top of the transom: close across at the sheer
    b.face([li[0], li[-1], c], [(0, 0.97), (0.5, 0.97), (0.25, 0.8)], False)
    # bow: centreline seam strip (the two sides meet at x = 0 near the stem; close the small gap)
    f0 = list(range(0, rlen))
    stem_c = [b.add_vert(V(0, rows[0][j].y - 0.03, rows[0][j].z)) for j in range(rlen // 2 + 1)]
    for j in range(rlen // 2):
        a1, a2 = f0[j], f0[j + 1]               # port half, top -> keel
        s1, s2 = stem_c[j], stem_c[j + 1]
        b.face([a1, s1, s2, a2], [(0, 0.97), (0.01, 0.97), (0.01, 0.5), (0, 0.5)], True)
        m1, m2 = f0[rlen - 1 - j], f0[rlen - 2 - j]   # starboard half
        b.face([m2, s2, s1, m1], [(0, 0.5), (0.01, 0.5), (0.01, 0.97), (0, 0.97)], True)
    for p in ci:
        pass
    # unused stem verts (ci) are dropped by the loose-vertex cleanup below
    return b


def build_hullgear():
    b = Buf()
    AF = ("strip", 0.004, 0.06, HULL_UV)
    AF2 = ("strip", 0.30, 0.45, 2.0)
    # bar keel along the centreline
    pts = []
    for i in range(30):
        u = 0.10 + 0.74 * i / 29
        pts.append(V(0, -L / 2 + u * L + stem_shift(u, zb(u)), (zb(u) + (KEEL * 0.5 if u > 0.18 else 0)) - KEEL * 0.5 + 0.02))
    W.sweep(b, pts, W.rect_profile(0.14, KEEL), AF, up_hint=(0, 0, 1))
    # skeg rising into the stern between the shafts
    W.sweep(b, [V(0, 5.0, zb(0.74) - 0.05), V(0, 8.6, zb(0.91) - 0.15), V(0, 9.4, zb(0.95))], W.rect_profile(0.10, 0.36), AF)
    # bilge keels: 0.28 m plates normal to the bilge, both sides, u 0.34..0.70
    for sx in (1, -1):
        pts, axes = [], []
        for i in range(16):
            u = 0.34 + 0.36 * i / 15
            hs = half_section(u)
            k = int(NB * 0.55)
            p, q = Vector((hs[k][0], 0, hs[k][1])), Vector((hs[k + 1][0], 0, hs[k + 1][1]))
            tang = (q - p).normalized()
            out = Vector((tang.z, 0, -tang.x))       # outward normal of the section curve (x >= 0 side)
            y = -L / 2 + u * L
            depth = 0.28 * math.sin(math.pi * min(1.0, (i + 0.5) / 15.5)) ** 0.4
            c = Vector((p.x * sx, y, p.z)) + Vector((out.x * sx, 0, out.z)) * (depth / 2)
            pts.append(c)
            axes.append(((out.z * sx * 0 + Vector((-out.z * sx, 0, out.x)).x * 0 + 0, 0, 0), (0, 0, 0)))
            axes[-1] = (Vector((tang.x * sx, 0, tang.z)), Vector((out.x * sx, 0, out.z)))
        W.sweep(b, pts, W.rect_profile(0.025, 0.26), AF2, axes=[(a, u_) for a, u_ in axes])
    # rudders (behind the props) and shaft A-brackets
    for sx in (1.15, -1.15):
        top = zb(0.965) + 0.05
        W.obox(b, (sx, 9.75, top - 0.55), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.36, 0.05, 0.55), AF2)
        W.obox(b, (sx, 9.75, top + 0.02), ((0, 0, 1), (1, 0, 0), (0, 1, 0)), (0.05, 0.05, 0.05), AF2)
        # A-bracket legs from the hull to the shaft boss
        boss = Vector((sx, 8.35, 0.62))
        for lx in (sx * 0.55, sx * 1.45):
            hx = max(0.05, min(abs(lx), surface_x(U_(8.35), 1.0))) * (1 if lx > 0 else -1)
            hz = zb(U_(8.35)) + 0.1 if abs(lx) < 1.0 else 1.0
            C.tube(b, [V(hx, 8.35, hz), boss], 0.05, AF2, sides=6)
    # bow thruster tunnel mouths (dark ring + grille)
    for sx in (1, -1):
        y, z = -7.6, 1.0
        x = surface_x(U_(y), z) * sx
        W.ring(b, (x + 0.01 * sx, y + stem_shift(U_(y), z), z), (0, 1, 0), (0, 0, 1), 0.26, 0.035, 16, 5, AF2)
    return b


def build_props_anodes():
    b = Buf()
    BR = band("bronze", 0.5)
    GV = band("galv", 0.5)
    for sx in (1.15, -1.15):
        # shaft from the hull to the boss and through to the prop
        C.tube(b, [V(sx, 5.6, zb(U_(5.6)) + 0.05), V(sx, 8.9, 0.58)], 0.055, BR, sides=8)
        hub = V(sx, 9.0, 0.57)
        C.tube(b, [hub - V(0, 0.18, 0), hub + V(0, 0.16, 0)], 0.10, BR, sides=10)
        for k in range(4):
            a = k * math.pi / 2 + (0.3 if sx > 0 else -0.3)
            blade = Buf()
            prof = [(-0.16, -0.012), (0.0, -0.02), (0.16, -0.012), (0.16, 0.012), (0.0, 0.02), (-0.16, 0.012)]
            pts = [V(0, 0, 0.08), V(0, 0.01, 0.25), V(0, 0.02, 0.40)]
            sc = [0.85, 1.0, 0.45]
            W.sweep(blade, pts, prof, BR, axes=[((1, 0.25, 0), (0, -1, 0.0))] * 3, scale=sc)
            from mathutils import Matrix
            Mx = Matrix.Translation(hub) @ Matrix.Rotation(a, 4, "Y")
            b.extend(blade, Mx)
    # sacrificial anodes: bottom plates near the stern, the rudders and the bilge
    for (x, y) in ((0.7, 6.5), (-0.7, 6.5), (1.6, 3.0), (-1.6, 3.0), (1.6, -2.0), (-1.6, -2.0), (0.9, 8.0), (-0.9, 8.0)):
        u = U_(y)
        z = zb(u) if abs(x) < 1.0 else None
        if z is None:
            hs = half_section(u)
            k = min(range(len(hs)), key=lambda i: abs(hs[i][0] - abs(x)))
            z = hs[k][1]
            x = hs[k][0] * (1 if x > 0 else -1)
        W.obox(b, (x, y, z - 0.02), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.16, 0.06, 0.035), GV)
    return b


def deck_edge(u, side):
    return V(bd(u) * side, -L / 2 + u * L, zs(u))


def build_bulwark():
    b = Buf()
    H = 1.0
    gate_u = U_(7.6), U_(8.6)
    # forward run: starboard gate -> bow -> port gate (profile above the deck edge, 6 cm plate + capping)
    fw = [i / 40 for i in range(40, -1, -1)]
    us_s = [gate_u[0] * t for t in fw]           # starboard gate .. bow
    pts = [deck_edge(u, -1) + V(0.03, 0, H / 2) for u in us_s] + [deck_edge(u, 1) + V(-0.03, 0, H / 2) for u in us_s[::-1][1:]]
    W.sweep(b, pts, W.rect_profile(0.06, H), SUP, up_hint=(0, 0, 1))
    cap = [p + V(0, 0, H / 2 + 0.03) for p in pts]
    W.sweep(b, cap, W.rect_profile(0.14, 0.06), SUP)
    # aft run: port gate .. transom .. starboard gate
    us_a = [gate_u[1] + (0.999 - gate_u[1]) * i / 8 for i in range(9)]
    pts = [deck_edge(u, 1) + V(-0.03, 0, H / 2) for u in us_a]
    yT = -L / 2 + 0.999 * L
    xt = bd(0.999) - 0.03
    pts += [V(xt * (1 - 2 * i / 6), yT - 0.03, zs(0.999) + H / 2) for i in range(1, 6)]
    pts += [deck_edge(u, -1) + V(0.03, 0, H / 2) for u in us_a[::-1]]
    W.sweep(b, pts, W.rect_profile(0.06, H), SUP)
    W.sweep(b, [p + V(0, 0, H / 2 + 0.03) for p in pts], W.rect_profile(0.14, 0.06), SUP)
    # bulwark stays (brackets) inside every 1.2 m
    for side in (1, -1):
        for y in [-8.4 + 1.2 * i for i in range(14)]:
            u = U_(y)
            if gate_u[0] - 0.01 < u < gate_u[1] + 0.01 or -4.9 < y < 6.3:
                continue
            e = deck_edge(u, side)
            W.obox(b, e + V(-0.18 * side, 0, 0.45), ((0, 0, 1), (1, 0, 0), (0, 1, 0)), (0.45, 0.15, 0.015), SUP)
    return b


def build_decks():
    b = Buf()
    us = [0.012 + 0.985 * i / 44 for i in range(45)]
    rows, uvs = [], []
    for u in us:
        y = -L / 2 + u * L
        w = bd(u) - 0.05
        row, uvr = [], []
        for j in range(9):
            x = -w + 2 * w * j / 8
            z = zs(u) + 0.08 * (1 - (x / max(BMAX, 1e-3)) ** 2) - 0.02
            row.append(V(x, y + stem_shift(u, zs(u)), z))
            uvr.append((x / 4.0, y / 4.0))
        rows.append(row)
        uvs.append(uvr)
    C.grid(b, rows, uvs, smooth=True, flip=True)
    # upper deck (saloon roof) and wheelhouse roof plates: flat slabs
    return b


SAL = dict(y0=-4.8, y1=6.2, hw=2.55, h=2.35, z=3.30 + 0.08, rake=0.55)
WH = dict(y0=-4.1, y1=-1.5, hw=1.75, h=2.15, rake=0.45)


def cabin_plan(y0, y1, hw, r, n=6):
    """Closed plan polyline (x, y), clockwise from the aft port corner, rounded front corners (radius r)."""
    pts = [(hw, y1), (hw, y0 + r)]
    for k in range(1, n):
        a = (math.pi / 2) * k / n
        pts.append((hw - r + r * math.cos(a), y0 + r - r * math.sin(a)))
    pts += [(hw - r, y0), (-hw + r, y0)]
    for k in range(1, n):
        a = math.pi / 2 + (math.pi / 2) * k / n
        pts.append((-hw + r + r * math.cos(a), y0 + r - r * math.sin(a)))
    pts += [(-hw, y0 + r), (-hw, y1)]
    return pts


def walls(b, plan, z0, h, rake_front, y_front, uv_h=2.5, closed=True, levels=3):
    """Vertical walls on a closed plan; points near the front lean aft by `rake_front` at the top."""
    n = len(plan)
    arc = [0.0]
    for i in range(1, n + 1):
        a, c = plan[i - 1], plan[i % n]
        arc.append(arc[-1] + math.hypot(c[0] - a[0], c[1] - a[1]))
    rows, uvs = [], []
    for k in range(levels):
        t = k / (levels - 1)
        row, uvr = [], []
        for i in range(n + 1):
            x, y = plan[i % n]
            lean = rake_front * t * max(0.0, 1 - (y - y_front) / 1.2)
            row.append(V(x * (1 - 0.02 * t), y + lean, z0 + h * t))
            uvr.append((arc[i] / 4.0, min(0.98, h * t / uv_h)))
        rows.append(row)
        uvs.append(uvr)
    C.grid(b, rows, uvs, smooth=False, flip=True)
    return rows


def roof(b, plan, z, over, thick, uv_top):
    """Roof slab: plan grown by `over`, top face (Deck set coords in uv_top) + edge band; returns the top points."""
    cx = 0.0
    cy = sum(p[1] for p in plan) / len(plan)
    grown = []
    for x, y in plan:
        d = Vector((x - cx, (y - cy) * 0.6, 0)).normalized()
        grown.append((x + d.x * over, y + d.y * over / 0.6 * 0.6))
    top = [b.add_vert(V(x, y, z + thick)) for x, y in grown]
    centre = b.add_vert(V(cx, cy, z + thick))
    for i in range(len(grown)):
        j = (i + 1) % len(grown)
        b.face([top[j], top[i], centre], [uv_top(grown[j]), uv_top(grown[i]), uv_top((cx, cy))], False)
    edge = [V(x, y, z + thick) for x, y in grown] + [V(grown[0][0], grown[0][1], z + thick)]
    return grown, edge


def build_saloon():
    b = Buf()
    s = SAL
    plan = cabin_plan(s["y0"], s["y1"], s["hw"], 0.9)
    walls(b, plan, s["z"], s["h"], s["rake"], s["y0"], levels=4)
    # roof edge band (fascia) and the slab underside lip
    grown = [(x * 1.04, y + (-0.08 if y < 0 else 0.08)) for x, y in plan]
    zt = s["z"] + s["h"]
    rows = [[V(x, y + (s["rake"] if y < s["y0"] + 1.2 else 0) * max(0, 1 - (y - s["y0"]) / 1.2), zt + dz) for x, y in grown + [grown[0]]]
            for dz in (-0.02, 0.16)]
    arc = [0.0]
    for p, q in zip(grown + [grown[0]], (grown + [grown[0]])[1:]):
        arc.append(arc[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
    C.grid(b, rows, [[(a / 4, 0.90) for a in arc], [(a / 4, 0.98) for a in arc]], smooth=False, flip=True)
    # doors: side doors aft (both sides) and the aft centre door, plus the stair landing coaming
    for sx in (1, -1):
        W.obox(b, (sx * (s["hw"] + 0.03), 5.0, s["z"] + 0.98), ((0, 1, 0), (0, 0, 1), (1, 0, 0)), (0.42, 0.98, 0.03), SUP)
    W.obox(b, (0, s["y1"] + 0.03, s["z"] + 0.98), ((1, 0, 0), (0, 0, 1), (0, 1, 0)), (0.45, 0.98, 0.03), SUP)
    # window surrounds: raised steel frames (3 cm lip) round every pane, drip rail above the side windows
    for c, r, up, hw, hh in window_rects():
        if c.z > s["z"] + s["h"]:
            continue
        n = r.cross(up)
        for (d, a, half) in ((up * (hh + 0.03), r, hw + 0.06), (-up * (hh + 0.03), r, hw + 0.06), (r * (hw + 0.03), up, hh), (-r * (hw + 0.03), up, hh)):
            W.obox(b, c + d - n * 0.004, (a, n, a.cross(n)), (half, 0.022, 0.03), SUP)
    for sx in (1, -1):
        W.obox(b, (sx * (s["hw"] + 0.03), 0.0, s["z"] + 1.95), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (3.9, 0.03, 0.02), SUP)
    return b


def window_rects():
    """(centre, right, up, half_w, half_h) of every saloon / wheelhouse pane, metres, right/up unit vectors."""
    s, w = SAL, WH
    out = []
    zc = s["z"] + 1.38
    for sx in (1, -1):
        n = Vector((sx, 0, 0))
        right = Vector((0, 0, 1)).cross(n)
        for y in (-3.05, -1.4, 0.25, 1.9, 3.55):
            out.append((Vector((sx * (s["hw"] * (1 - 0.02 * 1.38 / s["h"]) + 0.008), y, zc)), right, Vector((0, 0, 1)), 0.72, 0.50))
        out.append((Vector((sx * (s["hw"] + 0.035), 5.0, s["z"] + 1.45)), right, Vector((0, 0, 1)), 0.18, 0.24))   # door lights
    # saloon front: three raked panes
    lean = Vector((0, s["rake"], s["h"])).normalized()
    nf = Vector((1, 0, 0)).cross(lean).normalized() * -1
    for x in (-1.1, 0.0, 1.1):
        c = Vector((x, s["y0"] - 0.012, s["z"] + 1.38)) + Vector((0, s["rake"] * 1.38 / s["h"], 0))
        out.append((c, Vector((1, 0, 0)) * (1 if nf.y < 0 else -1) * -1, lean, 0.5, 0.50))
    # wheelhouse: wrap-round front and sides
    zw = s["z"] + s["h"] + 0.16 + 1.35
    leanw = Vector((0, w["rake"], w["h"])).normalized()
    for x in (-0.76, 0.0, 0.76):
        c = Vector((x, w["y0"] - 0.012 + w["rake"] * 1.35 / w["h"], zw))
        out.append((c, Vector((-1, 0, 0)) * -1, leanw, 0.36, 0.5))
    for sx in (1, -1):
        n = Vector((sx, 0, 0))
        right = Vector((0, 0, 1)).cross(n)
        for y in (-3.0, -2.05):
            out.append((Vector((sx * (w["hw"] * (1 - 0.02 * 1.35 / w["h"]) + 0.008), y, zw)), right, Vector((0, 0, 1)), 0.4, 0.45))
    return out


def build_windows():
    b = Buf()
    for c, r, up, hw, hh in window_rects():
        n = r.cross(up)
        pts = [c - r * hw - up * hh, c + r * hw - up * hh, c + r * hw + up * hh, c - r * hw + up * hh]
        idx = [b.add_vert(p) for p in pts]
        b.face(idx, [(0, 0), (1, 0), (1, 1), (0, 1)], False)
    return b


def build_wheelhouse():
    b = Buf()
    s, w = SAL, WH
    z0 = s["z"] + s["h"] + 0.16
    plan = cabin_plan(w["y0"], w["y1"], w["hw"], 0.6)
    walls(b, plan, z0, w["h"], w["rake"], w["y0"], levels=3)
    zt = z0 + w["h"]
    # roof + front visor
    grown = [(x * 1.08, y + (-0.32 if y < w["y0"] + 0.7 else 0.1)) for x, y in plan]
    rows = [[V(x, y + w["rake"] * max(0, 1 - (y - w["y0"]) / 1.2), zt + dz) for x, y in grown + [grown[0]]] for dz in (0.0, 0.14)]
    arc = [0.0]
    for p, q in zip(grown + [grown[0]], (grown + [grown[0]])[1:]):
        arc.append(arc[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
    C.grid(b, rows, [[(a / 4, 0.90) for a in arc], [(a / 4, 0.98) for a in arc]], smooth=False, flip=True)
    # wheelhouse aft door
    W.obox(b, (0.9, w["y1"] + 0.03, z0 + 0.98), ((1, 0, 0), (0, 0, 1), (0, 1, 0)), (0.40, 0.98, 0.03), SUP)
    return b


def build_roofs():
    """Upper deck (saloon roof) and wheelhouse roof tops on the Deck set (part of Decks)."""
    b = Buf()
    s, w = SAL, WH
    for plan, z, rake, y0 in ((cabin_plan(s["y0"], s["y1"], s["hw"] * 1.04, 0.95), s["z"] + s["h"] + 0.16, s["rake"], s["y0"]),
                              (cabin_plan(w["y0"] - 0.3, w["y1"] + 0.1, w["hw"] * 1.08, 0.65), s["z"] + s["h"] + 0.16 + w["h"] + 0.14, w["rake"], w["y0"])):
        pts = [(x, y + rake * max(0, 1 - (y - y0) / 1.2)) for x, y in plan]
        cy = sum(p[1] for p in pts) / len(pts)
        ci = b.add_vert(V(0, cy, z))
        idx = [b.add_vert(V(x, y, z)) for x, y in pts]
        for i in range(len(pts)):
            j = (i + 1) % len(pts)
            b.face([idx[i], idx[j], ci], [(pts[i][0] / 4, pts[i][1] / 4), (pts[j][0] / 4, pts[j][1] / 4), (0, cy / 4)], False)
    return b


def build_funnel():
    b = Buf()
    s = SAL
    z0 = s["z"] + s["h"] + 0.16
    prof = []
    for k in range(5):
        t = k / 4
        prof.append((t, 1.0 - 0.06 * t))
    n = 16
    rows, uvs = [], []
    for k, (t, sc) in enumerate(prof):
        row, uvr = [], []
        for i in range(n + 1):
            a = 2 * math.pi * i / n
            x, y = 0.45 * math.cos(a) * sc, 0.75 * math.sin(a) * sc
            row.append(V(x, 1.1 + y + 0.25 * t, z0 + 1.7 * t))
            uvr.append((i / n * 3.9 / 4 * 4 / 4, min(0.97, 1.7 * t / 2.5 + 0.02)))
        rows.append(row)
        uvs.append(uvr)
    C.grid(b, rows, uvs, smooth=True, flip=True)
    return b


def rail_run(b, pts, h=1.0, spacing=1.3, mids=(0.35, 0.68), top_r=0.025):
    """Stanchions + top rail + mid rails along a polyline (deck points)."""
    WHT = band("rail_white", 1.0)
    pts = [Vector(p) for p in pts]
    length = sum((q - p).length for p, q in zip(pts, pts[1:]))
    nst = max(2, int(length / spacing) + 1)
    acc = [0.0]
    for p, q in zip(pts, pts[1:]):
        acc.append(acc[-1] + (q - p).length)

    def at(d):
        for i in range(len(pts) - 1):
            if acc[i + 1] >= d:
                t = (d - acc[i]) / max(acc[i + 1] - acc[i], 1e-6)
                return pts[i].lerp(pts[i + 1], t)
        return pts[-1]
    for k in range(nst):
        p = at(length * k / (nst - 1))
        C.tube(b, [p, p + V(0, 0, h)], 0.02, WHT, sides=5, caps=(False, False))
    C.tube(b, [p + V(0, 0, h) for p in pts], top_r, WHT, sides=6)
    for m in mids:
        C.tube(b, [p + V(0, 0, h * m) for p in pts], 0.011, WHT, sides=4)


def build_rails():
    b = Buf()
    s, w = SAL, WH
    zu = s["z"] + s["h"] + 0.16
    # upper deck perimeter (aft of the wheelhouse front), open at the stair head (starboard aft)
    hw = s["hw"] * 1.04 - 0.06
    run = [V(hw, w["y0"] + 0.2, zu), V(hw, s["y1"] + 0.02, zu), V(-hw + 0.9, s["y1"] + 0.02, zu)]
    rail_run(b, run)
    rail_run(b, [V(-hw, s["y1"] - 0.95, zu), V(-hw, w["y0"] + 0.2, zu)])
    # wheelhouse roof guard rail (low) and the external stair handrails
    zr = zu + w["h"] + 0.14
    rail_run(b, [V(w["hw"] - 0.1, w["y1"] - 0.1, zr), V(-w["hw"] + 0.1, w["y1"] - 0.1, zr)], h=0.6, mids=(0.5,))
    # stair: aft deck (starboard, -X) up to the upper deck at the saloon aft end
    z0 = s["z"]
    sx = -(s["hw"] - 0.45)
    a, c = V(sx, s["y1"] + 2.3, z0), V(sx, s["y1"] + 0.05, zu)
    GV = band("galv", 1.0)
    for off in (-0.33, 0.33):
        C.tube(b, [a + V(off, 0, 0), c + V(off, 0, 0)], 0.035, GV, sides=4)
        C.tube(b, [a + V(off, 0, 0.95), c + V(off, 0, 0.95)], 0.022, band("rail_white"), sides=6)
        C.tube(b, [a + V(off, 0, 0), a + V(off, 0, 0.95)], 0.02, band("rail_white"), sides=5)
    for k in range(1, 11):
        p = a.lerp(c, k / 11)
        W.obox(b, p, ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.32, 0.11, 0.018), GV)
    # grab rails along the saloon sides on stand-offs, wipers on the wheelhouse front
    for sx in (1, -1):
        x = sx * (s["hw"] + 0.09)
        C.tube(b, [V(x, -3.8, s["z"] + 1.0), V(x, 4.4, s["z"] + 1.0)], 0.02, GV, sides=6)
        for y in (-3.6, -1.9, -0.2, 1.7, 3.6):
            C.tube(b, [V(sx * s["hw"], y, s["z"] + 1.0), V(x, y, s["z"] + 1.0)], 0.012, GV, sides=4, caps=(False, False))
    zw = zu + 1.35
    for x in (-0.76, 0.0, 0.76):
        p = V(x, w["y0"] - 0.03 + w["rake"] * 0.9 / w["h"], zu + 0.9)
        C.tube(b, [p, p + V(0.16, 0.12, 0.6)], 0.008, band("machinery"), sides=4)
    # boarding gates: hinged rail gates in the bulwark openings
    for side in (1, -1):
        e0, e1 = deck_edge(U_(7.62), side), deck_edge(U_(8.58), side)
        rail_run(b, [e0 - V(0.03 * side, 0, 0), e1 - V(0.03 * side, 0, 0)], h=1.0, spacing=0.95, mids=(0.5,))
    return b


def build_rafts():
    """Four 12-person liferaft canisters on tilted cradles at the upper deck edges, plus 6 lifebuoys."""
    b = Buf()
    s = SAL
    zu = s["z"] + s["h"] + 0.16
    GRP, GV, OR = band("grp", 1.6), band("galv", 1.0), band("orange", 0.47)
    rafts = []
    for side in (1, -1):
        for y in (1.9, 3.7):
            x = side * (s["hw"] * 1.04 - 0.55)
            c = Vector((x, y, zu + 0.48))
            tilt = Vector((side * math.sin(math.radians(15)), 0, math.cos(math.radians(15))))
            pts = [c + Vector((0, d, 0)) for d in (-0.62, -0.56, -0.45, 0.0, 0.45, 0.56, 0.62)]
            sc = [0.50, 0.86, 1.0, 1.0, 1.0, 0.86, 0.50]
            W.sweep(b, pts, W.round_profile(0.29, 16), GRP, up_hint=tuple(tilt), scale=sc, smooth=True)
            rafts.append((x, y, zu + 0.48))
            # cradle: two saddles + feet
            for d in (-0.32, 0.32):
                W.obox(b, (x, y + d, zu + 0.14), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.36, 0.04, 0.14), GV)
            C.tube(b, [V(x - 0.36, y - 0.4, zu + 0.03), V(x - 0.36, y + 0.4, zu + 0.03)], 0.025, GV, sides=4)
            C.tube(b, [V(x + 0.36, y - 0.4, zu + 0.03), V(x + 0.36, y + 0.4, zu + 0.03)], 0.025, GV, sides=4)
            # lashing strap over the top + hydrostatic release unit
            W.ring(b, (x, y, zu + 0.48), (1, 0, 0), (0, 0, 1), 0.31, 0.012, 14, 3, GV)
            W.obox(b, (x - side * 0.05, y, zu + 0.06), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.08, 0.05, 0.05), OR)
    # lifebuoys on the rails / bulwark
    for (x, y, z, ax) in ((s["hw"] * 1.04 - 0.05, -0.6, zu + 0.62, (0, 1, 0)), (-(s["hw"] * 1.04 - 0.05), -0.6, zu + 0.62, (0, 1, 0)),
                          (bd(U_(-6.4)) - 0.16, -6.4, zs(U_(-6.4)) + 0.62, (0, 1, 0)), (-(bd(U_(-6.4)) - 0.16), -6.4, zs(U_(-6.4)) + 0.62, (0, 1, 0)),
                          (0.9, 10.30, zs(0.99) + 0.62, (1, 0, 0)), (-0.9, 10.30, zs(0.99) + 0.62, (1, 0, 0))):
        W.ring(b, (x, y, z), ax, (0, 0, 1), 0.30, 0.055, 18, 6, OR)
    return b, rafts


def build_mast():
    b = Buf()
    s, w = SAL, WH
    zr = s["z"] + s["h"] + 0.16 + w["h"] + 0.14
    WHT, MC, GV = band("rail_white"), band("machinery"), band("galv")
    base = V(0, -2.6, zr)
    C.tube(b, [base, base + V(0, 0.15, 2.4)], 0.07, WHT, sides=8)
    for sx in (0.5, -0.5):
        C.tube(b, [base + V(sx, 0.45, 0), base + V(0, 0.08, 1.4)], 0.035, WHT, sides=6)
    # radar: pedestal + 1.2 m open array
    C.tube(b, [base + V(0, -0.5, 0), base + V(0, -0.5, 0.35)], 0.13, MC, sides=10)
    W.obox(b, base + V(0, -0.5, 0.45), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.62, 0.07, 0.06), MC)
    # yard + lights + horn + whips + GPS dome
    top = base + V(0, 0.15, 2.4)
    C.tube(b, [top + V(-0.55, 0, -0.5), top + V(0.55, 0, -0.5)], 0.03, WHT, sides=6)
    for p in (top + V(0, 0, 0.08), top + V(0, 0, -0.38), top + V(0.5, 0, -0.42), top + V(-0.5, 0, -0.42)):
        C.tube(b, [p, p + V(0, 0, 0.14)], 0.05, MC, sides=8)
    C.tube(b, [base + V(0.5, 0.3, 0.02), base + V(0.5, 0.3, 2.2)], 0.012, GV, sides=4)
    C.tube(b, [base + V(-0.5, 0.3, 0.02), base + V(-0.5, 0.3, 2.0)], 0.012, GV, sides=4)
    C.tube(b, [base + V(0.3, 0.6, 0.0), base + V(0.3, 0.6, 0.12)], 0.11, WHT, sides=10)
    C.tube(b, [top + V(0, -0.1, -0.9), top + V(0, -0.5, -0.8)], 0.06, MC, sides=8)     # horn
    # side lights on the wheelhouse sides, searchlight on the visor
    for sx in (1, -1):
        W.obox(b, (sx * (w["hw"] + 0.1), w["y0"] + 0.9, zr - 0.35), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.16, 0.08, 0.12), MC)
    C.tube(b, [V(0.6, w["y0"] - 0.1, zr), V(0.6, w["y0"] - 0.1, zr + 0.22)], 0.1, MC, sides=10)
    # funnel cap (soot) and vents on the upper deck
    zu = s["z"] + s["h"] + 0.16
    rows = []
    for dz in (0.0, 0.18):
        rows.append([V(0.45 * 0.94 * math.cos(2 * math.pi * i / 16) * 1.02, 1.1 + 0.25 + 0.75 * 0.94 * math.sin(2 * math.pi * i / 16) * 1.02, zu + 1.7 + dz) for i in range(17)])
    C.grid(b, rows, [[(i / 16, FIT_BANDS["machinery"][0] + 0.01 + 0.1 * k) for i in range(17)] for k in (0, 1)], flip=True)
    for (x, y) in ((1.6, 0.0), (-1.6, 0.0), (1.4, 5.4)):
        C.tube(b, [V(x, y, zu), V(x, y, zu + 0.7)], 0.13, WHT, sides=10)
        C.tube(b, [V(x, y, zu + 0.7), V(x, y + 0.28, zu + 0.85)], 0.13, WHT, sides=10)
    return b


def build_deckgear():
    b = Buf()
    MC, GV = band("machinery", 1.0), band("galv", 0.6)
    # windlass on the foredeck
    y, u = -7.2, U_(-7.2)
    z = zs(u) + 0.07
    W.obox(b, (0, y, z + 0.12), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.55, 0.35, 0.12), MC)
    C.tube(b, [V(-0.6, y, z + 0.42), V(0.6, y, z + 0.42)], 0.16, MC, sides=12)
    for sx in (-0.45, 0.45):
        W.ring(b, (sx, y, z + 0.42), (0, 1, 0), (0, 0, 1), 0.2, 0.04, 14, 5, MC)
    # chain from the gypsies to the hawse pipes, and the hawse rings
    for sx in (1, -1):
        hy = -9.0
        hz = zs(U_(hy)) - 0.05
        hx = bd(U_(hy)) * sx * 0.82
        C.tube(b, [V(sx * 0.45, y + 0.1, z + 0.3), V(sx * 0.48, -8.0, zs(U_(-8.0)) + 0.1), V(hx, hy, hz + 0.1)], 0.04, GV, sides=4)
        W.ring(b, (hx, hy, hz + 0.08), (1, 0, 0), (0, 1, 0), 0.14, 0.035, 12, 4, GV)
    # double bitts: two forward, two aft, plus fairleads
    for (x, yy) in ((1.7, -5.6), (-1.7, -5.6), (1.9, 9.6), (-1.9, 9.6), (2.2, 7.0), (-2.2, 7.0)):
        zz = zs(U_(yy)) + 0.05
        W.obox(b, (x, yy, zz + 0.03), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.35, 0.14, 0.03), GV)
        for d in (-0.2, 0.2):
            C.tube(b, [V(x, yy + d, zz), V(x, yy + d, zz + 0.42)], 0.09, GV, sides=10)
            C.tube(b, [V(x, yy + d, zz + 0.42), V(x, yy + d, zz + 0.47)], 0.12, GV, sides=10)
    # aft deck: mooring capstan and two passenger benches (slatted, Super-white frames)
    zz = zs(U_(9.0)) + 0.06
    C.tube(b, [V(0, 9.2, zz), V(0, 9.2, zz + 0.45)], 0.18, MC, sides=12)
    for sx in (1, -1):
        for k in range(4):
            W.obox(b, (sx * 2.25, 7.0 + 0.0, zz + 0.42 + 0.0), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.9, 0.05 + 0.0, 0.02), GV) if k == 0 else None
            W.obox(b, (sx * (2.15 + 0.12 * k * 0 ), 7.0, zz + 0.44 + 0.0), ((0, 1, 0), (1, 0, 0), (0, 0, 1)), (0.9, 0.21, 0.02), MC) if k == 1 else None
        W.obox(b, (sx * 2.38, 7.0, zz + 0.7), ((0, 1, 0), (0, 0, 1), (1, 0, 0)), (0.9, 0.2, 0.02), MC)
        for d in (-0.8, 0.8):
            C.tube(b, [V(sx * 2.2, 7.0 + d, zz), V(sx * 2.2, 7.0 + d, zz + 0.42)], 0.025, GV, sides=4)
    return b


def build_fenders():
    b = Buf()
    RB = band("rubber", 1.0)
    for side in (1, -1):
        pts, axes = [], []
        for i in range(36):
            u = 0.02 + 0.975 * i / 35
            z = zs(u) - 0.35
            x = surface_x(u, z) * side
            pts.append(V(x, -L / 2 + u * L + stem_shift(u, z), z))
        prof = [(-0.13, 0.0), (-0.09, 0.08), (0.0, 0.12), (0.09, 0.08), (0.13, 0.0)]
        prof = [(y, x) for x, y in prof]
        prof = [(p[1] * side, p[0]) for p in [(-0.13, 0.0), (-0.09, 0.08), (0.0, 0.12), (0.09, 0.08), (0.13, 0.0)]]
        W.sweep(b, pts, prof if side > 0 else prof[::-1], RB, up_hint=(0, 0, 1), caps=(True, True))
    # transom corner fenders (vertical)
    for sx in (1, -1):
        x = bd(0.99) * sx
        C.tube(b, [V(x, L / 2 - 0.12, zs(0.99) - 1.3), V(x, L / 2 - 0.12, zs(0.99) - 0.1)], 0.11, RB, sides=8)
    return b


def build_grablines():
    """Lines over the bottom at the 5 HullKnock compartments + a jackstay along the Blender -X (Roblox +X) bilge,
    the side that is up when she lies over (the hull team's hand-holds; docs/09 section 7 step 5)."""
    b = Buf()
    RP = band("rope", 0.6)
    ys = [-L / 2 + (i - 0.5) * L / 5 for i in range(1, 6)]
    jack = []
    for y in ys:
        u = U_(y)
        hs = half_section(u)
        pts = []
        for x, z in hs[::-1][2:]:
            pts.append(V(x * 1.0 + 0.04, y + stem_shift(u, z), z - 0.03))
        for x, z in hs[1:-2]:
            pts.append(V(-x - 0.04, y + stem_shift(u, z), z - 0.03))
        for p in pts:
            if p.z < zb(u) + 0.02:
                p.z = zb(u) - 0.04
        C.tube(b, pts, 0.016, RP, sides=5, smooth=True)
        k = int(NB * 0.62)
        jack.append(V(-hs[k][0] - 0.06, y + stem_shift(u, hs[k][1]), hs[k][1] - 0.02))
    path = []
    for a, c in zip(jack, jack[1:]):
        path += C.catenary(a, c, 0.10, 6)[:-1]
    path.append(jack[-1])
    C.tube(b, path, 0.016, RP, sides=5)
    return b, ys


def decal_patch(b, key, centre, right, up, w, h, segs=1, conform=None):
    u0, v0, u1, v1 = DECALS[key]
    rows, uvs = [], []
    for j in range(2):
        row, uvr = [], []
        for i in range(segs + 1):
            t = i / segs
            p = centre + right * (w * (t - 0.5)) + up * (h * (j - 0.5))
            if conform:
                p = conform(p)
            row.append(p)
            uvr.append((u0 + (u1 - u0) * t, v0 + (v1 - v0) * j))
        rows.append(row)
        uvs.append(uvr)
    C.grid(b, rows, uvs, smooth=False)


def build_decals():
    b = Buf()

    def on_hull(side):
        def f(p):
            u = U_(p.y)
            x = surface_x(u, p.z) + 0.012
            return Vector((x * side, p.y + stem_shift(u, p.z), p.z))
        return f
    for side in (1, -1):
        n = Vector((side, 0, 0))
        right = Vector((0, 0, 1)).cross(n)
        zc = zs(U_(-6.8)) - 0.78
        decal_patch(b, "name", Vector((0, -6.8, zc)), right, Vector((0, 0, 1)), 3.4, 0.62, segs=8, conform=on_hull(side))
        for y in (-9.35, 9.9):
            decal_patch(b, "draught", Vector((0, y, 1.62)), right, Vector((0, 0, 1)), 0.38, 1.15, segs=1, conform=on_hull(side))
    # transom: name + port of registry
    yT = L / 2 - 0.0
    t_n = Vector((0, 1, 0))
    t_r = Vector((0, 0, 1)).cross(t_n)
    decal_patch(b, "name", Vector((0, yT + 0.012, zs(0.99) - 0.62)), t_r, Vector((0, 0, 1)), 3.2, 0.58)
    decal_patch(b, "port", Vector((0, yT + 0.012, zs(0.99) - 1.12)), t_r, Vector((0, 0, 1)), 2.6, 0.42)
    # signs on the saloon aft wall / sides and the wheelhouse
    s, w = SAL, WH
    a_n = Vector((0, 1, 0))
    a_r = Vector((0, 0, 1)).cross(a_n)
    decal_patch(b, "muster", Vector((-1.4, s["y1"] + 0.012, s["z"] + 1.55)), a_r, Vector((0, 0, 1)), 0.9, 0.53)
    decal_patch(b, "imo", Vector((1.5, s["y1"] + 0.012, s["z"] + 2.1)), a_r, Vector((0, 0, 1)), 1.5, 0.15)
    for side in (1, -1):
        n = Vector((side, 0, 0))
        r = Vector((0, 0, 1)).cross(n)
        decal_patch(b, "pax", Vector((side * (s["hw"] + 0.012), 4.2, s["z"] + 1.55)), r, Vector((0, 0, 1)), 0.62, 0.29)
        decal_patch(b, "raft", Vector((side * (w["hw"] + 0.012), -1.75, s["z"] + s["h"] + 0.16 + 0.75)), r, Vector((0, 0, 1)), 0.62, 0.36)
    decal_patch(b, "crew", Vector((0.9, w["y1"] + 0.045, s["z"] + s["h"] + 0.16 + 1.55)), a_r, Vector((0, 0, 1)), 0.5, 0.23)
    return b


def make_cols():
    X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
    s, w = SAL, WH
    boxes = [((0, 0.5, (zb(0.5) + zs(0.5)) / 2), (X, Y, Z), (BMAX, 8.0, (zs(0.5) - zb(0.5)) / 2 + 0.05)),
             ((0, -7.6, 2.2), (X, Y, Z), (1.6, 2.6, 1.7)), ((0, 9.5, 2.3), (X, Y, Z), (2.7, 1.0, 1.0)),
             ((0, 0, KEEL / 2 + 0.1), (X, Y, Z), (0.1, 7.5, KEEL / 2 + 0.1)),
             ((0, (s["y0"] + s["y1"]) / 2, s["z"] + s["h"] / 2), (X, Y, Z), (s["hw"], (s["y1"] - s["y0"]) / 2, s["h"] / 2 + 0.1)),
             ((0, (w["y0"] + w["y1"]) / 2, s["z"] + s["h"] + 0.16 + w["h"] / 2), (X, Y, Z), (w["hw"], (w["y1"] - w["y0"]) / 2, w["h"] / 2 + 0.1))]
    return W.col_boxes(boxes, NAME + "_COL")


def build():
    C.clear_scene()
    parts = {}
    mats = {"Hull": "Hull", "HullGear": "Hull", "Props": "Fittings", "Bulwark": "Super", "Decks": "Deck", "Saloon": "Super",
            "Wheelhouse": "Super", "Funnel": "Super", "Windows": "Glass", "Rails": "Fittings", "Rafts": "Fittings",
            "Mast": "Fittings", "DeckGear": "Fittings", "Fenders": "Fittings", "GrabLines": "Fittings", "Decals": "Decals"}
    bufs = {"Hull": build_hull(), "HullGear": build_hullgear(), "Props": build_props_anodes(), "Bulwark": build_bulwark(),
            "Saloon": build_saloon(), "Wheelhouse": build_wheelhouse(), "Funnel": build_funnel(), "Windows": build_windows(),
            "Rails": build_rails(), "Mast": build_mast(), "DeckGear": build_deckgear(), "Fenders": build_fenders(),
            "Decals": build_decals()}
    dk = build_decks()
    dk.extend(build_roofs())
    bufs["Decks"] = dk
    rafts_b, rafts = build_rafts()
    bufs["Rafts"] = rafts_b
    gl, comp_ys = build_grablines()
    bufs["GrabLines"] = gl
    import bmesh
    for k, buf in bufs.items():
        o = buf.to_object("%s_%s_LOD0" % (NAME, k), "MI_%s_GaleQueen_%s" % (NAME, mats[k]))
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
        if k not in ("Windows", "Decals"):
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(o.data)
        bm.free()
        parts[k] = o
    # hull normals sanity: the bottom faces must point down
    hull = parts["Hull"]
    low = min(hull.data.polygons, key=lambda p: p.center.z)
    if low.normal.z > 0:
        for k in ("Hull",):
            parts[k].data.flip_normals()
        print("[C2] hull normals flipped to outward")
    S = W.S
    atts = [W.empty("ATT_Waterline", (0, 0, WL)), W.empty("ATT_Bow", (0, -L / 2, zs(0.0))), W.empty("ATT_Stern", (0, L / 2, zs(1.0))),
            W.empty("ATT_Masthead", (0, -2.45, SAL["z"] + SAL["h"] + 0.16 + WH["h"] + 0.14 + 2.4)),
            W.empty("ATT_AirPocket", (0.0, comp_ys[3], 1.2)),
            W.empty("ATT_BoardingGate_Port", (bd(U_(8.1)), 8.1, zs(U_(8.1))), look=(1, 0, 0)),
            W.empty("ATT_BoardingGate_Stbd", (-bd(U_(8.1)), 8.1, zs(U_(8.1))), look=(-1, 0, 0))]
    for i, (x, y, z) in enumerate(rafts, 1):
        atts.append(W.empty("ATT_Liferaft_%02d" % i, (x, y, z), look=(1 if x > 0 else -1, 0, 0)))
    for i, y in enumerate(comp_ys, 1):
        u = U_(y)
        hs = half_section(u)
        k = int(NB * 0.62)
        atts.append(W.empty("ATT_Knock_%02d" % i, (-hs[k][0] - 0.06, y, hs[k][1]), look=(-1, 0, 0)))
    col = make_cols()
    lods = C.make_lods(parts, BUDGET, BUDGET_TRIS, keep=("Decals", "Windows"))
    vis = list(parts.values())
    off = W.shift_to_base(vis + [col], empties=atts, others=[o for o, _, _ in lods])
    lo, hi = W.bbox(vis)
    hlo, hhi = W.bbox([parts["Hull"]])
    tri = {k: C.tri_count(o) for k, o in parts.items()}
    print("[C2] tris per part", tri, "LOD0 total", sum(tri.values()))
    print("[C2] bbox m %.2f x %.2f x %.2f; Hull part %.2f x %.2f x %.2f m (studs %.1f x %.1f x %.1f), Hull bbox centre z %.2f m"
          % (tuple((hi - lo) / S) + tuple((hhi - hlo) / S) + tuple(hhi - hlo) + (((hlo + hhi) / 2).z / S,)))
    print("[C2] offset", tuple(off), "compartments y", [round(y, 2) for y in comp_ys])
    meshes = [{"object": o, "set": mats[k]} for k, o in parts.items()] + [{"object": col}]
    meshes += [{"object": o, "role": "visual", "lod": lod, "of": src.name, "set": next(m["set"] for m in meshes if m["object"] is src)}
               for o, lod, src in lods]
    return {
        "name": NAME, "budget": BUDGET, "tris": BUDGET_TRIS, "tier": "standard",
        "dims_m": (6.2, 21.0, None), "size_note": None, "origin": "base", "tiling": True,
        "sets": [{"name": "GaleQueen", "set": st, "size": 1024, "wet": True} for st in ("Hull", "Super", "Deck", "Fittings", "Glass", "Decals")],
        "meshes": meshes, "attachments": atts,
        "waivers": {"LOD UV layout": "rails, rope and decal strips decimate into fewer islands; every LOD samples the same trim / tiling sets"},
    }
