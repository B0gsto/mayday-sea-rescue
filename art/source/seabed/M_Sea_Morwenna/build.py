"""S1a M_Sea_Morwenna: the wreck of a 1902 wooden two-masted trading schooner, broken-backed at 7 m (docs/12 2.7).

WorldConfig.POIs Morwenna: position (620, -21.5, 860), yaw 28, length 84, beam 21 studs (28 x 7 m); replaces
map/Build.luau buildSchooner. Pivot = centre of the base; bow at -Y (Roblox front). Integration: drop the greybox
roll (-0.14 rad) since the heel is modelled; sink the model so the Silt skirt meets the terrain (about 0.3 m).

Wreck story: lost in the gale of 1902, settled upright on sand, heeled to starboard (-X), back broken just aft of
midships (aft half yawed 5 deg, heeled 6 deg, dropped 0.3 m). Starboard side buried and planked to the turn of the
bilge; port side frames snapped, a planked panel of the port side lies flat outboard. Foremast fallen over the port
side. Windlass collapsed onto the bow fill, chain run out over the port bow onto the sand.

MeshParts (one material each):
  RibA / RibB / RibC   frame masters (floor + futtocks): full, port snapped, both snapped. INSTANCED: the masters sit
                       at their own stations; every other frame is a clone (M_Sea_Morwenna.instances.json: CFrame from
                       the LOD0 bbox centre + Size factor, Roblox axes). Wood set.
  HullFore / HullAft   keel, keelson, stem + apron / sternpost + inner post, starboard strakes (sprung ends), port
                       garboards, the main hatch coaming and boards (fore). Wood.
  SidePort             collapsed port side panel: planks on frame stubs, half in the silt. Wood.
  Mast                 fallen foremast, broken top. Wood.
  Windlass             barrel, bitts, pawl bitt. Wood.
  Ironwork             windlass whelps, gypsies, pawl rack, levers, mast bands, gudgeon straps. Metal (iron strip).
  Chain                stud-link chain, 25 mm. Metal (iron strip).
  Silt                 sand fill, starboard bank, bow / stern scour pits, edge skirt. Silt set.
  Kelp                 Laminaria on the high timbers (cards; DoubleSided + AlphaMode Transparency in Studio). Kelp set.
"""
import json
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(HERE, "../_S1a"))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, os.path.expanduser("~/RobloxProjects/tools/blender"))
import budgets  # noqa: E402
import rbxkit  # noqa: E402
import versions  # noqa: E402  (tools/blender puts ~/RobloxProjects/tools/blender on the path)
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf, V  # noqa: E402

NAME = "M_Sea_Morwenna"
WOOD = ("tile", 2.0, 2.0)
IRON = ("strip", 0.5, 1.0, 0.8)
LH = 13.0            # half length on the keel (stem foot -13, sternpost foot +13)
HB = 3.3             # max half breadth (frames)
D0 = 2.4             # remaining side height
YB = 1.0             # the break
RIB_SIDED, RIB_MOULD = 0.20, 0.22
rnd = random.Random(1902)


# ------------------------------------------------------------------ hull form
def hb(y):
    t = max(-1.0, min(1.0, y / LH))
    e = 1.9 if t < 0 else 2.6
    return HB * max(1 - abs(t) ** e, 0.02)


def depth(y):
    t = y / LH
    return D0 + 0.5 * t * t


def sec(s):
    """Unit section: s in [-1, 1] (-1 starboard head, +1 port head) -> (x, z) for hb = 1, D = 1."""
    th = abs(s) * math.pi / 2
    x = math.sin(th) ** (2 / 3.0)
    z = 1 - math.cos(th) ** (2 / 3.0)
    return math.copysign(x, s), z


def surf(y, s, off=0.0):
    """Outer face of the frames at station y, girth s; off = metres outward along the section normal."""
    x, z = sec(s)
    p = Vector((x * hb(y), y, z * depth(y)))
    e = 1e-3
    xa, za = sec(max(s - e, -1))
    x2, z2 = sec(min(s + e, 1))
    t = Vector(((x2 - xa) * hb(y), 0, (z2 - za) * depth(y)))
    if t.length < 1e-9:
        t = Vector((1, 0, 0))
    t.normalize()
    n = Vector((t.z, 0, -t.x))          # outward for s increasing toward port
    if n.z > 0.01 and abs(s) < 0.02:
        n = Vector((0, 0, -1))
    if (n.x * math.copysign(1, s) < -0.01) or (abs(s) < 0.02 and n.z > 0):
        n = -n
    return p + n * off, t, n


AFT = (Matrix.Translation((0.0, YB, -0.30)) @ Matrix.Rotation(math.radians(5), 4, "Z")
       @ Matrix.Rotation(math.radians(-6), 4, "Y") @ Matrix.Translation((0.0, -YB, 0.0)))


def half(y):
    return AFT if y > YB else Matrix.Identity(4)


# ------------------------------------------------------------------ frames (instanced)
def rib_buf(s0, s1, seed):
    """One frame in local coords (keel point at origin): floor + futtocks from girth s0 to s1, jagged snapped heads."""
    b = Buf()
    n = 22
    ss = [s0 + (s1 - s0) * i / n for i in range(n + 1)]
    pts, axes, sc = [], [], []
    for s in ss:
        x, z = sec(s)
        p = Vector((x * HB, 0, z * D0))
        _, t, nrm = surf(0.0, s)
        inward = -nrm
        pts.append(p + inward * (RIB_MOULD / 2))
        axes.append((Vector((0, 1, 0)), inward))
        sc.append(1.0 - 0.25 * abs(s))
    prof = W.rect_profile(RIB_SIDED, RIB_MOULD, 0.025)
    W.sweep(b, pts, prof, WOOD, axes=axes, scale=sc, jag=(0.18 if s0 > -0.99 else 0.04, 0.18 if s1 < 0.99 else 0.04), seed=seed)
    return b


RIB_KINDS = {"RibA": (-1.0, 1.0), "RibB": (-1.0, 0.55), "RibC": (-0.72, 0.36)}
RIB_MASTER_Y = {"RibA": -4.34, "RibB": -1.86, "RibC": -6.2}


def rib_stations():
    out = []
    y = -10.4
    while y < 11.0:
        if abs(y - YB) > 0.45 and rnd.random() > 0.12:
            k = rnd.choices(["RibA", "RibB", "RibC"], [0.35, 0.45, 0.20])[0]
            out.append((round(y, 3), k))
        y += 0.62
    for k, ym in RIB_MASTER_Y.items():   # make sure each master station is present with its own kind
        out = [o for o in out if abs(o[0] - ym) > 0.3] + [(ym, k)]
    return sorted(out)


def rib_world(y, kind, master=False):
    """Blender matrix (metres) taking the local frame to its place: half transform, station, tilt, scale."""
    tilt = Matrix.Identity(4) if master else (Matrix.Rotation(math.radians(rnd.uniform(-3, 3)), 4, "X")
                                              @ Matrix.Rotation(math.radians(rnd.uniform(-2, 2)), 4, "Y"))
    sx = 1.0 if master else hb(y) / HB
    sz = 1.0 if master else depth(y) / D0
    Sm = Matrix.Diagonal((sx, 1.0, sz, 1.0))
    return half(y) @ Matrix.Translation((0, y, 0)) @ tilt @ Sm, (sx, 1.0, sz)


# ------------------------------------------------------------------ hull timbers
def plank(b, s, y0, y1, sprung=(0.0, 0.0), jag=(0.15, 0.15), w=0.22, th=0.06, seed=0):
    n = max(4, int((y1 - y0) / 0.55))
    pts, axes = [], []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        p, t, nrm = surf(y, s, th / 2 + 0.005)
        f0 = max(0.0, 1 - (y - y0) / 1.6) ** 2 * sprung[0]
        f1 = max(0.0, 1 - (y1 - y) / 1.6) ** 2 * sprung[1]
        p = p + nrm * (f0 + f1)
        pts.append(half(y) @ p)
        R = half(y).to_3x3()
        axes.append((R @ t, R @ nrm))
    W.sweep(b, pts, W.rect_profile(w, th, 0.012), WOOD, axes=axes, jag=jag, seed=seed)


def keel_parts(fore, aft):
    prof_k = W.rect_profile(0.30, 0.42, 0.03)
    for b, y0, y1, j in ((fore, -LH, YB - 0.12, (0.0, 0.3)), (aft, YB + 0.28, LH, (0.3, 0.0))):
        pts = [half(y0 + 0.1) @ Vector((0, y0 + (y1 - y0) * i / 8, -0.21)) for i in range(9)]
        W.sweep(b, pts, prof_k, WOOD, up_hint=(0, 0, 1), jag=j, seed=int(y0 * 10))
    prof_ks = W.rect_profile(0.28, 0.30, 0.03)
    for b, y0, y1, j in ((fore, -10.6, YB - 0.4, (0.1, 0.35)), (aft, YB + 0.6, 10.8, (0.35, 0.1))):
        pts = [half(y0 + 0.1) @ Vector((0, y0 + (y1 - y0) * i / 8, RIB_MOULD + 0.15)) for i in range(9)]
        W.sweep(b, pts, prof_ks, WOOD, up_hint=(0, 0, 1), jag=j, seed=int(y1 * 10))
    # stem (curved, raked forward) + apron
    st = [Vector((0, -LH - 1.15 * (u ** 2.0), -0.42 + 3.9 * u)) for u in [i / 10 for i in range(11)]]
    W.sweep(fore, st, W.rect_profile(0.30, 0.42, 0.03), WOOD, up_hint=(0, 1, 0), jag=(0.0, 0.3), seed=3)
    ap = [Vector((0, -LH + 0.4 - 0.9 * (u ** 2.0), 0.0 + 2.6 * u)) for u in [i / 8 for i in range(9)]]
    W.sweep(fore, ap, W.rect_profile(0.26, 0.30, 0.03), WOOD, up_hint=(0, 1, 0), jag=(0.0, 0.25), seed=4)
    # sternpost + inner post, deadwood block
    sp = [AFT @ Vector((0, LH + 0.55 * u, -0.42 + 3.5 * u)) for u in [i / 6 for i in range(7)]]
    W.sweep(aft, sp, W.rect_profile(0.30, 0.40, 0.03), WOOD, up_hint=(0, -1, 0), jag=(0.0, 0.3), seed=5)
    ip = [AFT @ Vector((0, LH - 0.38 + 0.5 * u, 0.0 + 2.7 * u)) for u in [i / 6 for i in range(7)]]
    W.sweep(aft, ip, W.rect_profile(0.24, 0.26, 0.03), WOOD, up_hint=(0, -1, 0), jag=(0.0, 0.2), seed=6)
    dw = [AFT @ Vector((0, 11.0 + 1.9 * i / 4, 0.25 + 0.25 * i / 4)) for i in range(5)]
    W.sweep(aft, dw, W.rect_profile(0.30, 0.55, 0.03), WOOD, up_hint=(0, 0, 1), seed=7)
    return st, sp


def strakes(fore, aft):
    k = 0
    # starboard (buried side): planked to the turn of the bilge, a few missing, sprung ends
    for i, s in enumerate([-0.05 - 0.052 * j for j in range(13)]):
        if i in (5, 9, 11):
            continue
        reach = 12.4 if abs(s) < 0.35 else 11.0 - 6 * (abs(s) - 0.35)
        y0 = -reach + rnd.uniform(0, 1.2)
        y1 = reach - rnd.uniform(0, 1.6)
        for b, a0, a1, jg in ((fore, y0, YB - 0.1 - rnd.uniform(0, 0.4), (0.12, 0.25)),
                              (aft, YB + 0.25 + rnd.uniform(0, 0.4), y1, (0.25, 0.12))):
            if a1 - a0 < 1.0:
                continue
            spr = (rnd.choice([0, 0, 0.18, 0.32]), rnd.choice([0, 0, 0.22, 0.38]))
            plank(b, s, a0, a1, sprung=spr, jag=jg, seed=k)
            k += 1
    # port garboards and one broken strake
    for s, y0, y1 in ((0.05, -12.2, 9.5), (0.10, -11.0, -2.0), (0.10, 3.5, 11.5), (0.155, -9.0, -3.2), (0.21, 5.0, 9.8)):
        for b, a0, a1 in ((fore, y0, min(y1, YB - 0.2)), (aft, max(y0, YB + 0.3), y1)):
            if a1 - a0 < 1.0:
                continue
            plank(b, s, a0, a1, sprung=(rnd.choice([0, 0.25]), rnd.choice([0, 0.3])), seed=k)
            k += 1


def side_port():
    """The collapsed port side: 6 planks on 7 frame stubs, lying 18 deg off flat, outboard of the port bilge."""
    b = Buf()
    M = (Matrix.Translation((3.55, -2.2, 0.15)) @ Matrix.Rotation(math.radians(4), 4, "Z")
         @ Matrix.Rotation(math.radians(18), 4, "Y"))
    for i in range(6):
        if i == 4:
            continue
        x = 0.25 + i * 0.235
        y0, y1 = -4.6 + rnd.uniform(0, 1.0), 4.8 - rnd.uniform(0, 1.4) - i * 0.25
        pts = [M @ Vector((x, y0 + (y1 - y0) * j / 10, 0.07 + 0.04 * math.sin(j * 0.9 + i))) for j in range(11)]
        W.sweep(b, pts, W.rect_profile(0.22, 0.06, 0.012), WOOD, axes=[(M.to_3x3() @ Vector((1, 0, 0)), M.to_3x3() @ Vector((0, 0, 1)))] * 11,
                jag=(0.2, 0.25), seed=40 + i)
    for j in range(7):
        y = -3.9 + j * 1.24
        L = 0.9 + rnd.uniform(0, 0.8)
        pts = [M @ Vector((0.05 + L * u, y, -0.04 - 0.05 * u)) for u in (0, 0.33, 0.66, 1.0)]
        W.sweep(b, pts, W.rect_profile(0.20, 0.18, 0.02), WOOD, up_hint=M.to_3x3() @ Vector((0, 0, 1)), jag=(0.2, 0.2), seed=50 + j)
    return b


def mast():
    b, iron = Buf(), Buf()
    heel = Vector((0.4, -7.6, 1.05))
    top = Vector((5.2, 3.0, 0.15))
    n = 20
    pts = []
    for i in range(n + 1):
        u = i / n
        p = heel.lerp(top, u)
        p.z += 0.12 * math.sin(u * math.pi)     # slight sag over the hull rail
        pts.append(p)
    sc = [1.0 - 0.32 * (i / n) for i in range(n + 1)]
    W.sweep(b, pts, W.round_profile(0.18, 14), WOOD, scale=sc, smooth=True, jag=(0.05, 0.45), seed=60)
    d = (top - heel).normalized()
    for k, u in enumerate((0.18, 0.36, 0.52, 0.68, 0.80)):
        c = heel.lerp(top, u)
        c.z += 0.12 * math.sin(u * math.pi)
        r = 0.18 * (1 - 0.32 * u) + 0.012
        q = [c - d * 0.04, c + d * 0.04]
        W.sweep(iron, q, W.round_profile(r, 14), IRON, smooth=True, seed=61 + k)
    return b, iron, (heel, top)


def windlass(iron):
    """Barrel windlass (patent-pattern), collapsed onto the bow fill: 8 deg yaw, 5 deg list, ahead of the foremast."""
    b = Buf()
    M = (Matrix.Translation((0.05, -10.1, 0.62)) @ Matrix.Rotation(math.radians(8), 4, "Z")
         @ Matrix.Rotation(math.radians(5), 4, "Y"))
    R = M.to_3x3()
    barrel = [M @ Vector((x, 0, 0.45)) for x in (-0.95, -0.6, -0.2, 0.2, 0.6, 0.95)]
    W.sweep(b, barrel, W.round_profile(0.22, 8), WOOD, up_hint=R @ Vector((0, 0, 1)), scale=[0.86, 1, 0.92, 0.92, 1, 0.86], seed=70)
    for sx in (-1.12, 1.12):        # bitts
        W.obox(b, M @ Vector((sx, 0, 0.32)), (R @ Vector((0, 0, 1)), R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0))), (0.58, 0.15, 0.17), WOOD)
    W.obox(b, M @ Vector((0, -0.05, 0.62)), (R @ Vector((0, 0, 1)), R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0))), (0.62, 0.13, 0.15), WOOD)   # pawl bitt
    W.obox(b, M @ Vector((0, 0.3, 0.06)), (R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, 1))), (1.3, 0.22, 0.08), WOOD)    # sole
    for k in range(8):              # iron whelps along the barrel
        a = 2 * math.pi * k / 8 + math.pi / 8
        off = Vector((0, math.cos(a), math.sin(a))) * 0.215
        nrm = Vector((0, math.cos(a), math.sin(a)))
        for seg in ((-0.85, -0.25), (0.25, 0.85)):
            W.obox(iron, M @ (Vector((sum(seg) / 2, 0, 0.45)) + off), (R @ Vector((1, 0, 0)), R @ nrm.cross(Vector((1, 0, 0))), R @ nrm), ((seg[1] - seg[0]) / 2, 0.025, 0.02), IRON)
    gyps = []
    for sx in (-0.72, 0.72):
        c = M @ Vector((sx, 0, 0.45))
        ax = R @ Vector((1, 0, 0))
        W.sweep(iron, [c - ax * 0.07, c + ax * 0.07], W.round_profile(0.30, 16), IRON, smooth=False, seed=71)
        gyps.append(c)
        for k in range(6):
            a = 2 * math.pi * k / 6
            nrm = R @ Vector((0, math.cos(a), math.sin(a)))
            W.obox(iron, c + nrm * 0.31, (ax, nrm.cross(ax), nrm), (0.075, 0.04, 0.035), IRON)
    c = M @ Vector((0, 0, 0.45))
    W.sweep(iron, [c - R @ Vector((0.08, 0, 0)), c + R @ Vector((0.08, 0, 0))], W.round_profile(0.27, 16), IRON, seed=72)
    for sx in (-0.4, 0.4):          # purchase levers lying across the barrel
        p0 = M @ Vector((sx, -0.1, 0.72))
        p1 = M @ Vector((sx + 0.3, -1.3, 0.25))
        W.sweep(iron, [p0, p1], W.round_profile(0.035, 6), IRON, seed=73)
    return b, M, gyps


def chain(start):
    """Stud-link chain (25 mm, link 0.15 x 0.09 m) from the port gypsy over the port bow onto the sand."""
    bufs = [Buf(), Buf()]
    ctrl = [start, Vector((0.9, -11.6, 1.2)), Vector((1.3, -12.5, 1.55)), Vector((1.75, -13.0, 1.1)),
            Vector((2.1, -13.25, 0.42)), Vector((3.0, -13.2, 0.38)), Vector((4.2, -12.6, 0.36)), Vector((5.0, -11.8, 0.30)),
            Vector((5.5, -11.1, 0.12)), Vector((5.7, -10.7, -0.08))]
    dense = []
    for i in range(len(ctrl) - 1):
        for k in range(12):
            dense.append(ctrl[i].lerp(ctrl[i + 1], k / 12))
    dense.append(ctrl[-1])
    pitch = 0.105
    pos, acc = [dense[0]], 0.0
    for i in range(1, len(dense)):
        seg = (dense[i] - dense[i - 1]).length
        acc += seg
        while acc >= pitch:
            acc -= pitch
            pos.append(dense[i] - (dense[i] - dense[i - 1]).normalized() * acc)
    links = []
    for i in range(len(pos) - 1):
        a, c = pos[i], pos[i + 1]
        t = (c - a).normalized()
        up = Vector((0, 0, 1))
        side = t.cross(up).normalized() if abs(t.z) < 0.95 else Vector((1, 0, 0))
        up2 = side.cross(t).normalized()
        if i % 2:
            side = up2
        links.append(((a + c) / 2, t, side))
    half_n = len(links) // 2
    global CHAIN_PATHS
    CHAIN_PATHS = []
    for buf, group in ((bufs[0], links[:half_n + 1]), (bufs[1], links[half_n:])):
        chain_tube(buf, group)
        CHAIN_PATHS.append([c for c, _, _ in group])
    return bufs, len(pos) - 1


def chain_tube(buf, links, R=0.036, r=0.0125, straight=0.06):
    """The links as ONE closed tube (so LODs can collapse it): forward along every link's A half, back along every
    B half; the short link-to-link hops sit inside the interlocks."""
    def half_pts(c, t, sd, which):
        cn, cf = c - t * (straight / 2), c + t * (straight / 2)
        if which == "A":
            arcs = [(cn, 180), (cn, 135), (cn, 90), (cf, 90), (cf, 45), (cf, 0)]
        else:
            arcs = [(cf, 0), (cf, -45), (cf, -90), (cn, -90), (cn, -135), (cn, -180)]
        return [cc + t * (R * math.cos(math.radians(a))) + sd * (R * math.sin(math.radians(a))) for cc, a in arcs]
    path = []
    for c, t, sd in links:
        path += half_pts(c, t, sd, "A")
    for k, (c, t, sd) in enumerate(reversed(links)):
        pts = half_pts(c, t, sd, "B")
        if k == 0:
            pts = pts[1:]
        path += pts
    path = path[:-1]
    W.sweep(buf, path, W.round_profile(r, 5), IRON, closed_path=True, smooth=True)


def hatch():
    b = Buf()
    M = (Matrix.Translation((0.3, -3.2, 0.62)) @ Matrix.Rotation(math.radians(-11), 4, "Z")
         @ Matrix.Rotation(math.radians(7), 4, "Y") @ Matrix.Rotation(math.radians(-4), 4, "X"))
    R = M.to_3x3()
    X, Y, Z = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, 1))
    for c, ax, h in (((0, -0.72, 0), (X, Y, Z), (0.98, 0.09, 0.17)), ((0, 0.72, 0), (X, Y, Z), (0.98, 0.09, 0.17)),
                     ((-0.89, 0, 0), (Y, X, Z), (0.63, 0.09, 0.17)), ((0.89, 0, 0.0), (Y, X, Z), (0.63, 0.09, 0.15))):
        W.obox(b, M @ Vector(c), ax, h, WOOD)
    for k, (dx, ang) in enumerate(((-0.4, 12), (0.2, -20), (1.5, 35))):       # hatch boards, two still across, one slid off
        Mb = M @ Matrix.Translation((dx, 0.05 * k, 0.2 - 0.18 * (k == 2))) @ Matrix.Rotation(math.radians(ang), 4, "Z")
        Rb = Mb.to_3x3()
        W.obox(b, Mb @ Vector((0, 0, 0)), (Rb @ Vector((0, 1, 0)), Rb @ Vector((1, 0, 0)), Rb @ Vector((0, 0, 1))), (0.75, 0.28, 0.03), WOOD)
    return b, M @ Vector((0, 0, 0.18))


def silt():
    b = Buf()
    x0, x1, y0, y1, st = -6.0, 6.9, -14.45, 14.45, 0.5
    nx, ny = int(round((x1 - x0) / st)), int(round((y1 - y0) / st))
    idx = {}

    def height(x, y):
        h = 0.30 + 0.03 * math.sin(y * 12.6 + 0.6 * math.sin(x * 2.0)) + 0.04 * math.sin(x * 1.3 + y * 0.7)
        w = hb(max(min(y, LH), -LH)) if abs(y) < LH else 0.0
        if abs(x) < w * 0.9 and abs(y) < LH - 0.4:
            h = 0.48 + 0.06 * math.sin(y * 0.9) + 0.04 * math.cos(x * 2.3 + y)   # hull fill
        if x < -w and abs(y) < LH - 1.0:                                        # starboard bank
            d = -x - w
            h = max(h, 0.95 - 0.22 * d)
        for (cx, cy, r, dpt) in ((0.0, -13.6, 2.0, 0.55), (0.0, 13.3, 1.8, 0.45)):
            d = math.hypot(x - cx, (y - cy) * 1.2)
            if d < r:
                h -= dpt * (0.5 + 0.5 * math.cos(math.pi * d / r))
        ex = min(x - x0, x1 - x, y - y0, y1 - y)
        if ex < 0.7:
            h = h - (0.7 - ex) * 1.1
        return h
    for j in range(ny + 1):
        for i in range(nx + 1):
            x, y = x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny
            x += rnd.uniform(-0.08, 0.08) * (0 < i < nx)
            y += rnd.uniform(-0.08, 0.08) * (0 < j < ny)
            idx[i, j] = b.add_vert((x, y, height(x, y)))
    for j in range(ny):
        for i in range(nx):
            q = [idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]]
            b.face(q, [(b.v[k].x / 4.0, b.v[k].y / 4.0) for k in q], True)
    return b, height


def kelp(spots):
    b = Buf()
    for k, (p, n) in enumerate(spots):
        for j in range(n):
            a = rnd.uniform(0, 2 * math.pi)
            up = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1.0))
            side = Vector((-math.sin(a), math.cos(a), 0))
            q = rnd.randrange(4)
            W.card(b, Vector(p) + Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), 0)), up, side,
                   rnd.uniform(1.0, 1.9), rnd.uniform(0.26, 0.40), 8, Vector((0.35, 0.15, 0.0)),
                   (q * 0.25 + 0.004, (q + 1) * 0.25 - 0.004), droop=0.25)
    return b


def self_union(ob):
    """Fuse the interlocking links into one closed mesh (exact boolean, self intersection) so LODs can collapse it."""
    empty_col = bpy.data.collections.get("S1a_Empty") or bpy.data.collections.new("S1a_Empty")
    mod = ob.modifiers.new("Union", "BOOLEAN")
    mod.operation, mod.solver, mod.use_self = "UNION", "EXACT", True
    mod.operand_type, mod.collection = "COLLECTION", empty_col
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    me.name = ob.name


def make_lods(objs):
    """LOD1 / LOD2 made here instead of the run.py lod step: collapse decimation (versions.decimate, the step's own
    code and targets) for every part except the chain, whose welded-free links cannot collapse to 10%: its LOD1 is
    decimated links, its LOD2 a flat strap swept along the link centres (at 500 studs a chain reads as a dark line)."""
    out = []
    for k, src in objs.items():
        n = sum(len(p.vertices) - 2 for p in src.data.polygons)
        for lod in ("LOD1", "LOD2"):
            name = src.name.replace("_LOD0", "_" + lod)
            old = bpy.data.objects.get(name)
            if old is not None:
                bpy.data.objects.remove(old, do_unlink=True)
            target = budgets.lod_target("rib", lod, n, 30000)
            if k.startswith("Chain") and lod == "LOD2":
                b = Buf()
                path = CHAIN_PATHS[0 if k == "ChainBow" else 1][::3]
                W.sweep(b, path, W.rect_profile(0.10, 0.035), IRON, up_hint=(0, 0, 1))
                obj = b.to_object(name, src.data.materials[0].name)
            else:
                obj = versions.copy_object(src, name)
                try:
                    versions.decimate(obj, target)
                except RuntimeError as e:
                    print("[S1a] %s: %s (kept the closest)" % (name, e))
            versions.weighted_normals(obj)
            print("[lod] %s %d triangles (target %d, LOD0 %d)" % (name, versions.triangles(obj.data), target, n))
            out.append((obj, lod, src))
    return out


def build():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME):
            bpy.data.objects.remove(o, do_unlink=True)
    fore, aft, ironb = Buf(), Buf(), Buf()
    stem, sternpost = keel_parts(fore, aft)
    strakes(fore, aft)
    hb_, hatch_top = hatch()
    fore.extend(hb_)
    mast_b, mast_iron, (heel, top) = mast()
    ironb.extend(mast_iron)
    wl_b, WM, gyps = windlass(ironb)
    for zz in (0.9, 1.6, 2.3):      # gudgeon straps on the sternpost
        c = AFT @ Vector((0, LH + 0.55 * (zz + 0.42) / 3.5, zz))
        W.obox(ironb, c, (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))), (0.19, 0.24, 0.05), IRON)
    chain_b, nlinks = chain(gyps[1] + Vector((0.0, -0.25, -0.1)))
    silt_b, sand_h = silt()
    spots = [(stem[-1] + Vector((0, 0.1, -0.05)), 6), (stem[6], 3), (sternpost[-1] + Vector((0, -0.1, -0.05)), 5),
             (heel.lerp(top, 0.25) + Vector((0, 0, 0.18)), 4), (heel.lerp(top, 0.5) + Vector((0, 0, 0.16)), 3),
             (WM @ Vector((-1.12, 0, 0.9)), 4), (WM @ Vector((1.12, 0, 0.9)), 3)]
    for y in (-8.0, -5.5, -2.0, 3.0, 6.5, 9.0):         # starboard rib heads
        p, _, _ = surf(y, -0.95)
        spots.append((half(y) @ p, rnd.randint(2, 4)))
    kelp_b = kelp(spots)

    parts = {
        "HullFore": (fore, "Wood"), "HullAft": (aft, "Wood"), "SidePort": (side_port(), "Wood"), "Mast": (mast_b, "Wood"),
        "Windlass": (wl_b, "Wood"), "Ironwork": (ironb, "Metal"), "ChainBow": (chain_b[0], "Metal"), "ChainRun": (chain_b[1], "Metal"), "Silt": (silt_b, "Silt"),
        "Kelp": (kelp_b, "Kelp"),
    }
    objs = {}
    for k, (buf, st) in parts.items():
        objs[k] = buf.to_object("%s_%s_LOD0" % (NAME, k), "MI_Morwenna_" + st)
    # frame masters + instances (LODs are made below, after the masters exist)
    stations = rib_stations()
    inst_col = bpy.data.collections.get("S1a_RibInstances") or bpy.data.collections.new("S1a_RibInstances")
    if inst_col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(inst_col)
    for o in list(inst_col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    masters, inst = {}, []
    for k, (s0, s1) in RIB_KINDS.items():
        b = rib_buf(s0, s1, seed={"RibA": 11, "RibB": 12, "RibC": 13}[k])
        Mw, _ = rib_world(RIB_MASTER_Y[k], k, master=True)
        b.transform(Mw)
        masters[k] = (b.to_object("%s_%s_LOD0" % (NAME, k), "MI_Morwenna_Wood"), Mw)
        objs[k] = masters[k][0]
    for y, k in stations:
        if abs(y - RIB_MASTER_Y[k]) < 1e-6:
            inst.append({"mesh": k, "y": y, "master": True, "M": Matrix.Identity(4), "size": (1, 1, 1)})
            continue
        Mi, sz = rib_world(y, k)
        rel = Mi @ masters[k][1].inverted()        # applied to the master's (world) data
        o = bpy.data.objects.new("S1aInst_%s_%.2f" % (k, y), masters[k][0].data)
        Ms = Matrix.Diagonal((W.S, W.S, W.S, 1.0)) @ rel @ Matrix.Diagonal((1 / W.S, 1 / W.S, 1 / W.S, 1.0))
        o.matrix_world = Ms
        inst_col.objects.link(o)
        inst.append({"mesh": k, "y": y, "master": False, "obj": o, "size": sz})
    # attachments (metres)
    bell_at = WM @ Vector((-1.45, -0.55, 0.0))
    bell_at.z = sand_h(bell_at.x, bell_at.y) + 0.05
    atts = [W.empty("ATT_Bell", bell_at, look=(0, -1, 0)),
            W.empty("ATT_Hatch", hatch_top, look=(1, 0, 0)),
            W.empty("ATT_Windlass", WM @ Vector((0, -0.6, 0.6)), look=(0, -1, 0)),
            W.empty("ATT_ChainEnd", Vector((5.6, -10.9, sand_h(5.6, -10.9))), look=(0, 1, 0)),
            W.empty("ATT_Stem", stem[5] + Vector((0, -0.4, 0)), look=(0, 1, 0)),
            W.empty("ATT_Anchor", Vector((5.6, -11.0, sand_h(5.6, -11.0))), look=(1, 0, 0))]
    # _COL boxes (metres), before the base shift
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    md = (top - heel).normalized()
    boxes = [((0, -6.0, 0.15), (X, Y, Z), (0.4, 7.0, 0.45)),
             (tuple(AFT @ Vector((0, 7.0, 0.15))), (AFT.to_3x3() @ X, AFT.to_3x3() @ Y, AFT.to_3x3() @ Z), (0.4, 6.0, 0.45)),
             ((0, -13.6, 1.5), (X, Y, Z), (0.2, 0.6, 1.9)), (tuple(AFT @ Vector((0, 13.2, 1.3))), (X, Y, Z), (0.2, 0.4, 1.7)),
             (tuple(heel.lerp(top, 0.5)), (md, md.cross(Z).normalized(), md.cross(md.cross(Z)).normalized() * -1), ((top - heel).length / 2, 0.2, 0.2)),
             (tuple(WM @ Vector((0, 0, 0.45))), (WM.to_3x3() @ X, WM.to_3x3() @ Y, WM.to_3x3() @ Z), (1.3, 0.35, 0.45)),
             ((-hb(0) + 0.3, 0, 0.7), (X, Y, Z), (0.35, 9.5, 0.7)),
             ((4.4, -2.0, 0.3), (X, Y, Z), (1.1, 4.2, 0.3))]
    col = W.col_boxes(boxes, NAME + "_COL")
    lods = make_lods(objs)
    vis = list(objs.values())
    off = W.shift_to_base(vis + [col], empties=atts, others=[o for o, _, _ in lods], extra_mats=[i["obj"] for i in inst if not i["master"]])
    # the shift moved master data; instance matrices were pre-multiplied by T in studs: rebase them (T M T^-1)
    T = Matrix.Translation(off)
    for i in inst:
        if not i["master"]:
            i["obj"].matrix_world = i["obj"].matrix_world @ T.inverted()
    lo, hi = W.bbox(vis)
    centre = (lo + hi) / 2
    rows = []
    for i in inst:
        mo = objs[i["mesh"]]
        mlo, mhi = W.bbox([mo])
        mc = (mlo + mhi) / 2
        Mw = Matrix.Identity(4) if i["master"] else i["obj"].matrix_world
        c = Mw @ mc
        Rb = Mw.to_3x3().normalized()
        cols = [rbxkit.rbx_from_blender(tuple(Rb @ Vector(a))) for a in ((-1, 0, 0), (0, 0, 1), (0, 1, 0))]
        rows.append({"mesh": "%s_%s" % (NAME, i["mesh"]), "master": i["master"], "station_m": i["y"],
                     "roblox_from_bbox_centre": [round(v, 4) for v in rbxkit.rbx_from_blender(tuple(c - centre))],
                     "right": [round(v, 5) for v in cols[0]], "up": [round(v, 5) for v in cols[1]],
                     "back": [round(v, 5) for v in cols[2]],
                     "size_factor": [round(i["size"][0], 4), round(i["size"][2], 4), round(i["size"][1], 4)]})
    out = os.path.join(G, "assets/fbx", NAME)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, NAME + ".instances.json"), "w") as f:
        json.dump({"asset": NAME, "units": "studs", "mapping": "roblox = (-bx, bz, by)",
                   "use": "clone <mesh> per row (masters already placed): part.CFrame = model pivot (LOD0 bbox centre) * "
                          "CFrame.fromMatrix(roblox_from_bbox_centre, right, up, back); part.Size = master Size * size_factor",
                   "instances": rows}, f, indent=1)
    tri = {k: sum(len(p.vertices) - 2 for p in o.data.polygons) for k, o in objs.items()}
    rib_inst = sum(tri[r["mesh"].split("_")[-1]] for r in rows if not r["master"])
    print("[S1a] tris per part", tri, "LOD0 total", sum(tri.values()), "+ instanced ribs", rib_inst, "links", nlinks,
          "frames", len(rows))
    print("[S1a] bbox m %.2f x %.2f x %.2f" % tuple((hi - lo) / W.S))
    meshes = [{"object": o, "set": {"Silt": "Silt", "Kelp": "Kelp", "Ironwork": "Metal", "ChainBow": "Metal", "ChainRun": "Metal"}.get(k, "Wood")}
              for k, o in objs.items()] + [{"object": col}]
    meshes += [{"object": o, "role": "visual", "lod": lod, "of": src.name, "set": next(m["set"] for m in meshes if m["object"] is src)}
               for o, lod, src in lods]
    S = W.S
    return {
        "name": NAME, "budget": "rib", "tris": 30000, "tier": "standard",
        "dims_m": (None, 28.0, None), "size_note": None, "origin": "base", "tiling": True,
        "sets": [{"name": "Morwenna", "set": s, "size": 1024, "wet": False} for s in ("Wood", "Metal", "Silt", "Kelp")],
        "meshes": meshes, "attachments": atts,
        "waivers": {"LOD UV layout": "kelp cards and chain links decimate into fewer islands; every LOD samples the same tiling sets"},
        "closeups": [
            {"name": "bow_windlass_chain", "target": [a * S for a in (0.4 + off.x / S, -10.6 + off.y / S, 0.9 + off.z / S)], "dist": 14, "az": 35, "el": 22},
            {"name": "broken_back_ribs", "target": [a * S for a in (0.0 + off.x / S, 1.0 + off.y / S, 0.9 + off.z / S)], "dist": 16, "az": 70, "el": 30},
            {"name": "stern_kelp", "target": [a * S for a in (0.0 + off.x / S, 12.8 + off.y / S, 1.6 + off.z / S)], "dist": 14, "az": 150, "el": 15},
        ],
    }
