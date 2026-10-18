"""E1 hand-held rescue kit (docs/12 2.8): geometry for every kit item on the shared kit atlas (atlas.py).

Runs inside Blender (tools/blender/run.py via art/source/kit/<Asset>/build.py, or run_all.py). Authored in metres, front
-Y, base at Z 0, with the HP2a harbour prop primitives (art/source/harbour/M_Hbr_PropAtlas/props.py HP: lathe_uv,
torus_uv, tube2, grid_uv on shared verts with explicit atlas UVs), imported read-only with this folder's atlas cached
first. Every MeshPart uses one set (Soft or Hard); emissive heads (flare heads, strobe dome, buoy light) are their own
`_Lens` MeshParts on the Hard set, so the game can make them Neon / add a light at ATT_Lens.
"""
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import atlas  # noqa: E402  (this kit atlas, cached as `atlas` before the HP2a modules import theirs)
sys.path.insert(1, os.path.join(G, "art/source/harbour/M_Hbr_PropAtlas"))
sys.path.insert(2, os.path.join(G, "tools/blender"))
import props as hp  # noqa: E402
from kit import frame, axis_frame, fit_frame  # noqa: E402

assert hp.atlas is atlas, "HP2a props must resolve atlas to the kit atlas"
HP = hp.HP
STUDS = 3.0
TEX_DIR = os.path.join(G, "assets/textures", atlas.ATLAS_ASSET)
T = atlas.T


def ntile(L, s=T):
    return max(1, int(round(L / s)))


# ---------------------------------------------------------------- shared shapes
def sq(t, n=4.0):
    """Superellipse point (cos, sin) at angle t (n=2 ellipse, larger = boxier)."""
    c, s = math.cos(t), math.sin(t)
    return math.copysign(abs(c) ** (2.0 / n), c), math.copysign(abs(s) ** (2.0 / n), s)


def soft_wall(P, region, a, b, z0, z1, n=4.0, bulge=0.0, nu=32, nv=6, seed=0, cx=0.0, cy=0.0, wob=0.004):
    """Side wall of a soft bag: superellipse section a x b (half sizes), bulging out at mid-height, light puckers."""
    rng = random.Random(seed)
    ph = [rng.uniform(0, 6.28) for _ in range(4)]
    per = 2 * (a + b) * 1.9

    def fn(u, v):
        t = 2 * math.pi * u
        x, y = sq(t, n)
        k = 1.0 + bulge * math.sin(math.pi * v) + wob * (math.sin(5 * t + ph[0]) * math.sin(3 * math.pi * v + ph[1]))
        z = z0 + (z1 - z0) * v + wob * 0.6 * math.sin(7 * t + ph[2]) * math.sin(math.pi * v)
        return (cx + a * k * x, cy + b * k * y, z)
    P.grid_uv(fn, nu, nv, region, ntile(per), ntile(z1 - z0), closed_u=True)


def soft_cap(P, region, a, b, z, n=4.0, dome=0.0, nu=32, nr=4, top=True, cx=0.0, cy=0.0):
    """Top / bottom of a soft bag as rings from the wall edge to the centre (nr rings), slightly domed."""
    def fn(u, v):
        t = 2 * math.pi * u
        x, y = sq(t, n)
        r = 1.0 - v * 0.999
        return (cx + a * r * x, cy + b * r * y, z + (dome * (1 - r * r) if top else -dome * (1 - r * r)))
    f0 = len(P.f)
    P.grid_uv(fn, nu, nr, region, ntile(2 * (a + b) * 1.9), ntile(max(a, b)), closed_u=True)
    if not top:      # flip the bottom so it faces down
        P.f[f0:] = [(list(reversed(i)), r, ("uv", list(reversed(fit[1])))) for i, r, fit in P.f[f0:]]


def ring_pts(a, b, z, n=4.0, k=1.0, segs=48, cx=0.0, cy=0.0):
    return [(cx + a * k * sq(2 * math.pi * i / segs, n)[0], cy + b * k * sq(2 * math.pi * i / segs, n)[1], z) for i in range(segs)]


def ribbon(P, pts, width, region, up=None, lift=0.0015, seg_len=None):
    """Flat strap (webbing, tape, zip) along a polyline, `width` across, its face normal along `up` (a function
    p -> outward normal, or a fixed vector). UVs: whole tiles along the length, the tile width across."""
    Pv = [Vector(p) for p in pts]
    L = sum((b - a).length for a, b in zip(Pv[:-1], Pv[1:]))
    n = len(Pv) - 1
    nrm = []
    for i, p in enumerate(Pv):
        t = (Pv[min(i + 1, n)] - Pv[max(i - 1, 0)]).normalized()
        o = Vector(up(p)) if callable(up) else Vector(up or (0, 0, 1))
        o = (o - t * o.dot(t)).normalized()
        nrm.append((t, o))

    def fn(u, v):
        i = min(int(u * n + 1e-9), n - 1)
        f = u * n - i
        p = Pv[i].lerp(Pv[i + 1], f)
        t, o = nrm[i] if f < 0.5 else nrm[i + 1]
        side = t.cross(o).normalized()
        q = p + o * lift + side * (v - 0.5) * width
        return tuple(q)
    tiles = ntile(L, atlas.scale(region) or T)
    nu = tiles * max(1, int(math.ceil(n / tiles)))
    # resample the polyline to nu segments by arc length so the grid matches it
    cum = [0.0]
    for a, b in zip(Pv[:-1], Pv[1:]):
        cum.append(cum[-1] + (b - a).length)
    Q = []
    for i in range(nu + 1):
        s = L * i / nu
        j = min(int(np.searchsorted(cum, s, side="right")) - 1, n - 1)
        t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-12)
        Q.append(Pv[j].lerp(Pv[j + 1], t))
    Pv, n = Q, nu
    nrm = []
    for i, p in enumerate(Pv):
        t = (Pv[min(i + 1, n)] - Pv[max(i - 1, 0)]).normalized()
        o = Vector(up(p)) if callable(up) else Vector(up or (0, 0, 1))
        o = (o - t * o.dot(t)).normalized()
        nrm.append((t, o))
    P.grid_uv(fn, nu, 1, region, tiles, 1)


def arc(c, r, a0, a1, n, plane="xz", z=0.0):
    out = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        if plane == "xz":
            out.append((c[0] + r * math.cos(a), c[1], c[2] + r * math.sin(a)))
        elif plane == "yz":
            out.append((c[0], c[1] + r * math.cos(a), c[2] + r * math.sin(a)))
        else:
            out.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a), c[2]))
    return out


def handle(P, x0, x1, y, ztop, rise, width=0.025, region="Webbing", grip=None):
    """Carry handle: a webbing arc between two stitched tabs, with an optional wrapped grip."""
    pts = [(x0 + (x1 - x0) * i / 12, y, ztop + rise * math.sin(math.pi * i / 12)) for i in range(13)]
    ribbon(P, pts, width, region, up=(0, -1, 0), lift=0.0)
    for x in (x0, x1):
        ribbon(P, [(x - 0.02, y, ztop + 0.002), (x + 0.02, y, ztop + 0.002)], width * 1.15, region, up=(0, 0, 1), lift=0.0008)
    if grip:
        g = [p for p in pts[4:9]]
        P.tube2(g, 0.011, 8, grip, caps=True)


def solid_box(P, c, size, region, n=6.0, segs=24, nv=2):
    """Rounded moulded box (plastic body): superellipse wall + capped ends; tile region."""
    a, b, h = size[0] / 2, size[1] / 2, size[2]
    soft_wall(P, region, a, b, c[2], c[2] + h, n=n, nu=segs, nv=nv, cx=c[0], cy=c[1], wob=0.0)
    soft_cap(P, region, a, b, c[2] + h, n=n, nu=segs, nr=2, cx=c[0], cy=c[1])
    soft_cap(P, region, a, b, c[2], n=n, nu=segs, nr=2, top=False, cx=c[0], cy=c[1])


def decal(P, region, o, ua, va, w, h):
    o, ua, va = Vector(o), Vector(ua).normalized(), Vector(va).normalized()
    pts = [o, o + ua * w, o + ua * w + va * h, o + va * h]
    P.mesh([tuple(p) for p in pts], [(0, 1, 2, 3)], region, fit=fit_frame(o, ua, va, w, h, atlas.rect(region)))


def snap_hook(P, p, axis=(0, 0, 1), L=0.07, r=0.004):
    """Stainless snap hook: body loop and gate as two rods along `axis` from p."""
    M, _ = axis_frame(p, tuple(Vector(p) + Vector(axis) * L))
    pts = [(0.0, 0.0, 0.0), (0.012, 0, 0.01), (0.013, 0, L * 0.7), (0.0, 0, L), (-0.012, 0, L * 0.7), (-0.012, 0, L * 0.25)]
    P.tube2([tuple(M @ Vector(q)) for q in pts], r, 6, "Stainless", caps=True)
    P.tube2([tuple(M @ Vector(q)) for q in [(-0.012, 0, L * 0.25), (0.0, 0, L * 0.08)]], r * 0.7, 5, "Stainless", caps=True)
    P.torus_uv(0.009, r * 0.9, 10, 5, "Stainless", M=M @ frame(0, 0, -0.006, pitch=90))


# ================================================================ throw bag (SOLAS orange, line out of the mouth)
def throw_bag():
    B = HP("Bag")
    r, H = 0.075, 0.30
    B.lathe_uv([(0.0, 0.0), (0.05, 0.0), (0.07, 0.004), (r, 0.018), (r + 0.001, 0.05)], 24, "NavyNylon")
    soft_wall(B, "SolasNylon", r + 0.001, r + 0.001, 0.05, H, n=2.0, bulge=0.035, nu=24, nv=8, seed=3, wob=0.006)
    # gathered collar: pleats in towards the drawcord
    pl = []
    for i in range(24):
        t = 2 * math.pi * i / 24
        pl.append(t)

    def collar(u, v):
        t = 2 * math.pi * u
        rr = (r + 0.001) * (1 - 0.62 * v) * (1 + 0.10 * v * math.sin(12 * t))
        return (rr * math.cos(t), rr * math.sin(t), H + 0.045 * math.sin(0.5 * math.pi * v))
    B.grid_uv(collar, 24, 3, "SolasNylon", 1, 1, closed_u=True)
    B.lathe_uv([(0.031, H + 0.045), (0.024, H + 0.05), (0.0, H + 0.052)], 12, "ZipBlack")
    # piping at the base seam, retro band, side strap and top carry loop
    B.tube2(ring_pts(r + 0.001, r + 0.001, 0.05, n=2.0, segs=24), 0.004, 5, "ZipBlack", closed=True, k=1)
    B.lathe_uv([(r * 1.032 + 0.002, 0.185), (r * 1.034 + 0.002, 0.21)], 24, "Retro")
    side = [(r * (1 + 0.035 * math.sin(math.pi * (z - 0.05) / (H - 0.05))) + 0.0015, 0.0, z) for z in np.linspace(0.055, H - 0.005, 8)]
    ribbon(B, side, 0.025, "Webbing", up=(1, 0, 0), lift=0.002)
    ribbon(B, [(r + 0.002, 0.0, H - 0.005), (r + 0.03, 0.0, H + 0.04), (r + 0.01, 0.0, H + 0.08), (0.03, 0.0, H + 0.055)],
           0.025, "Webbing", up=(0.6, 0, 0.8), lift=0.0)
    # yellow floating line out of the mouth, ending in a loop (the thrower holds this end)
    line = [(0.0, 0.0, H + 0.05), (0.005, -0.01, H + 0.09), (0.03, -0.03, H + 0.12), (0.07, -0.04, H + 0.115), (0.10, -0.035, H + 0.09)]
    B.tube2(line, 0.004, 6, "RopeThrow", caps=True)
    M = frame(0.122, -0.03, H + 0.075, yaw=-15, pitch=90)
    B.torus_uv(0.022, 0.0042, 18, 6, "RopeThrow", M=M)
    D = HP("Toggle")       # cord lock on the drawcord
    D.lathe_uv([(0.0, 0.0), (0.009, 0.0), (0.011, 0.012), (0.009, 0.024), (0.0, 0.024)], 10, "BlackABS",
               M=frame(-0.012, -0.025, H + 0.03, pitch=-60))
    atts = [("ATT_Grip", (0.0, 0.0, 0.15)), ("ATT_Throw", (0.0, 0.0, 0.14)), ("ATT_LineEnd", (0.122, -0.03, H + 0.075)),
            ("ATT_LineExit", (0.0, 0.0, H + 0.052))]
    return [("Bag", "Soft", B), ("Toggle", "Hard", D)], atts, ((-0.08, -0.08, 0), (0.15, 0.08, 0.40))


def throw_line():
    """15 m of 8 mm yellow floating line, loosely coiled as it lies on deck after a recovery, free end led off."""
    P = HP("Line")
    rng = random.Random(7)
    d = 0.008
    pts = []
    turns = 12
    k = 0
    for t in range(turns):
        R = 0.17 + 0.03 * rng.random() + 0.004 * (t % 4)
        ox, oy = 0.02 * rng.uniform(-1, 1), 0.02 * rng.uniform(-1, 1)
        squash = 0.85 + 0.15 * rng.random()
        for j in range(16):
            a = 2 * math.pi * (j / 16) + 0.4 * t
            z = d / 2 + d * 0.9 * (t % 3) * 0.5 + 0.003 * math.sin(3 * a + t)
            pts.append((ox + R * math.cos(a), oy + R * squash * math.sin(a), z))
            k += 1
    end = pts[-1]
    tail = [(end[0] + 0.05, end[1] - 0.04, d / 2), (end[0] + 0.15, end[1] - 0.12, d / 2), (end[0] + 0.30, end[1] - 0.15, d / 2)]
    P.tube2(pts + tail, d / 2, 5, "RopeThrow", caps=True, k=1)
    M = frame(tail[-1][0] + 0.03, tail[-1][1], d / 2)
    P.torus_uv(0.03, d / 2, 14, 5, "RopeThrow", M=M, sr=0.8)
    atts = [("ATT_Grip", (0.0, 0.0, 0.01)), ("ATT_LineEnd", (tail[-1][0] + 0.06, tail[-1][1], d / 2))]
    return [("Line", "Soft", P)], atts, ((-0.22, -0.3, 0), (0.6, 0.22, 0.03))


# ================================================================ rescue tube (lifeguard foam tube)
def rescue_tube():
    P = HP("Tube")
    L, w, th = 1.0, 0.15, 0.08

    def fn(u, v):
        t = 2 * math.pi * u
        x = -L / 2 + L * v
        e = abs(x) - (L / 2 - 0.075)
        k = math.sqrt(max(1 - (e / 0.075) ** 2, 0.0)) if e > 0 else 1.0
        k = max(k, 0.02)
        cy, cz = sq(t, 3.2)
        # moulded strap grooves every 0.18 m on the top and bottom
        g = 1.0 - 0.06 * math.exp(-((((x + L / 2) % 0.18) - 0.09) / 0.008) ** 2) * (abs(x) < 0.4)
        return (x, (w / 2) * k * cy * g, th / 2 + (th / 2) * k * cz * (g if abs(cz) > 0.5 else 1))
    P.grid_uv(fn, 16, 30, "FoamSolas", 1, 3, closed_u=True)
    # webbing loop through each end, stainless D ring and snap hook on +X, leash on -X
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.035)
        pts = [(x, -w / 2 * 0.6, th / 2 + 0.041), (x + sx * 0.04, 0.0, th / 2 + 0.045), (x + sx * 0.07, 0.0, th / 2 + 0.01),
               (x + sx * 0.04, 0.0, th / 2 - 0.045), (x, -w / 2 * 0.6, th / 2 - 0.041)]
        ribbon(P, pts, 0.025, "Webbing", up=(sx, 0, 0), lift=0.0)
    H = HP("Hardware")
    H.torus_uv(0.016, 0.0035, 14, 5, "Stainless", M=frame(L / 2 + 0.045, 0.0, th / 2, pitch=90))
    snap_hook(H, (L / 2 + 0.06, 0.0, th / 2), axis=(1, 0, 0), L=0.075)
    # 2 m leash: webbing from the -X end, a few loose flat loops beside the tube, ending in the shoulder strap
    lp = [(-L / 2 - 0.06, 0.0, th / 2 - 0.02), (-L / 2 - 0.12, -0.04, 0.008)]
    for k in range(int(2.0 / (2 * math.pi * 0.11)) + 1):
        for j in range(1, 17):
            a = math.pi + 2 * math.pi * j / 16
            lp.append((-L / 2 - 0.12 + 0.11 * math.cos(a) + 0.11 + 0.03 * k, -0.18 + 0.11 * math.sin(a) * 0.8 - 0.01 * k, 0.003 + 0.003 * k))
    ribbon(P, lp, 0.022, "Webbing", up=(0, 0, 1), lift=0.0)
    atts = [("ATT_Grip", (0.0, 0.0, th / 2)), ("ATT_Clip", (L / 2 + 0.13, 0.0, th / 2)), ("ATT_Ring", (L / 2 + 0.045, 0.0, th / 2)),
            ("ATT_Leash", (lp[-1][0], lp[-1][1], 0.01)), ("ATT_Throw", (0.0, 0.0, th / 2))]
    return [("Tube", "Soft", P), ("Hardware", "Hard", H)], atts, ((-L / 2 - 0.06, -w / 2, 0), (L / 2 + 0.14, w / 2, th))


# ================================================================ lifebuoy 0.75 m with light and retro tape
def lifebuoy():
    R = HP("Ring")
    R.smooth = 70.0
    Rc, rt, sr = 0.30, 0.075, 0.90
    zc = rt * sr
    R.torus_uv(Rc, rt, 40, 9, "RingFit", M=frame(0, 0, zc), sr=sr)
    pts = []
    for k in range(48):
        th = 2 * math.pi * k / 48
        sag = abs(math.sin(2 * th))
        rr = Rc + rt * 0.96 + 0.035 * sag
        pts.append((rr * math.cos(th), rr * math.sin(th), zc - 0.025 * sag))
    R.tube2(pts, 0.0055, 4, "RopeGrab", closed=True, k=1)
    for k in range(4):
        th = math.pi / 2 * k + math.pi / 4
        M = Matrix.Rotation(th, 4, 'Z') @ frame(Rc, 0, zc, pitch=90)
        R.tube2([tuple(M @ Vector((rt * 1.06 * math.cos(2 * math.pi * j / 8), rt * sr * 1.05 * math.sin(2 * math.pi * j / 8), 0)))
                 for j in range(8)], 0.004, 4, "RopeGrab", closed=True, k=1)
    # self-igniting buoy light lying on deck beside the ring on a short lanyard
    Lb = HP("Light")
    lx, ly = Rc + rt + 0.06, -0.14
    Ml = frame(lx, ly, 0.032, yaw=-20, pitch=-90)
    Lb.lathe_uv([(0.0, 0.0), (0.026, 0.0), (0.032, 0.01), (0.032, 0.15), (0.028, 0.16), (0.022, 0.165)], 12, "SolasABS", M=Ml)
    Lb.torus_uv(0.012, 0.003, 10, 4, "BlackABS", M=Ml @ frame(0, 0, -0.008, pitch=90))
    Ln = HP("Lens")
    Ln.lathe_uv([(0.022, 0.165), (0.022, 0.19), (0.016, 0.205), (0.0, 0.21)], 14, "LensClear", M=Ml)
    p_lens = Ml @ Vector((0, 0, 0.19))
    a0 = Ml @ Vector((0, 0, -0.02))
    R.tube2([(Rc * math.cos(-0.5) + rt, Rc * math.sin(-0.5), 0.01), (lx + 0.03, ly + 0.12, 0.004), tuple(a0)], 0.003, 4, "RopeGrab", k=1)
    atts = [("ATT_Grip", (Rc + rt + 0.02, 0.0, zc)), ("ATT_Throw", (0.0, 0.0, zc)), ("ATT_Light", tuple(p_lens)),
            ("ATT_Lens", tuple(p_lens)), ("ATT_LineEnd", (-(Rc + rt + 0.02), 0.0, zc))]
    return [("Ring", "Soft", R), ("Light", "Hard", Lb), ("Lens", "Hard", Ln)], atts, ((-0.4, -0.4, 0), (0.4, 0.4, 2 * zc))


# ================================================================ thermal blankets (metallised PET foil)
def _crinkle(x, y, seed, amp):
    return amp * (math.sin(41 * x + 3.1 * seed) * math.sin(37 * y + seed) + 0.6 * math.sin(83 * x - 61 * y + seed)
                  + 0.4 * math.sin(127 * x + 113 * y + 2 * seed))


def blanket_folded():
    P = HP("Folded")
    a, b = 0.14, 0.10
    layers = 6
    th = 0.006
    for k in range(layers):
        z0, z1 = k * th, (k + 1) * th
        reg = "FoilGold" if k % 2 else "FoilSilver"
        sh = 0.004 * math.sin(k * 1.7)

        def wall(u, v, z0=z0, z1=z1, sh=sh, k=k):
            t = 2 * math.pi * u
            x, y = sq(t, 7.0)
            bulge = 1.0 + 0.03 * math.sin(math.pi * v)
            return (sh + a * bulge * x + _crinkle(x, y + k, k, 0.0015), b * bulge * y + _crinkle(y, x, k, 0.0015), z0 + (z1 - z0) * v)
        P.grid_uv(wall, 40, 2, reg, 2, 1, closed_u=True)

    def top(u, v):
        x, y = -a + 2 * a * u, -b + 2 * b * v
        e = min(1.0, (1 - abs(2 * u - 1)) * 6, (1 - abs(2 * v - 1)) * 6)
        crease = 0.0015 * math.exp(-((x - 0.02) / 0.006) ** 2) - 0.001 * math.exp(-((y + 0.03) / 0.005) ** 2)
        return (x + 0.004 * math.sin(layers * 1.7) * 0, y, layers * th + e * (0.002 + _crinkle(x, y, 3, 0.0012) + crease))
    P.grid_uv(top, 16, 12, "FoilGold", 1, 1)

    def bot(u, v):
        return (-a + 2 * a * (1 - u), -b + 2 * b * v, 0.0)
    P.grid_uv(bot, 4, 3, "FoilSilver", 1, 1)
    atts = [("ATT_Grip", (0.0, 0.0, layers * th))]
    return [("Folded", "Soft", P)], atts, ((-a, -b, 0), (a, b, layers * th + 0.004))


def _body_height(x, y):
    """Supine casualty proxy (1.75 m, head at +Y, chin at y = +0.62): chest, belly, hips, legs, feet, arms at sides."""
    def ell(cx, cy, rx, ry, h):
        q = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
        return h * math.sqrt(max(1 - q, 0.0))
    hs = [ell(0, 0.38, 0.21, 0.24, 0.24), ell(0, 0.10, 0.19, 0.20, 0.21), ell(0, -0.15, 0.20, 0.16, 0.20),
          ell(-0.09, -0.55, 0.085, 0.36, 0.15), ell(0.09, -0.55, 0.085, 0.36, 0.15),
          ell(-0.10, -0.95, 0.07, 0.10, 0.20), ell(0.10, -0.95, 0.07, 0.10, 0.20),
          ell(-0.27, 0.20, 0.06, 0.30, 0.12), ell(0.27, 0.20, 0.06, 0.30, 0.12),
          ell(-0.26, -0.15, 0.06, 0.08, 0.11), ell(0.26, -0.15, 0.06, 0.08, 0.11), ell(0, 0.62, 0.08, 0.05, 0.16)]
    return max(hs)


def blanket_draped():
    """2.1 x 1.3 m foil blanket over a supine casualty (cone-dilated height field: hangs off the body edge, pools)."""
    P = HP("Draped")
    W, Lb = 1.30, 2.10
    nu, nv = 26, 36
    y_top = 0.64
    fine = 0.02
    xs = np.arange(-W / 2 - 0.1, W / 2 + 0.1, fine)
    ys = np.arange(y_top - Lb - 0.1, y_top + 0.1, fine)
    Hh = np.array([[_body_height(x, y) for x in xs] for y in ys])
    slope = 1.6

    def zf(x, y):
        ix, iy = int((x - xs[0]) / fine), int((y - ys[0]) / fine)
        r = 14
        y0, y1, x0, x1 = max(iy - r, 0), min(iy + r + 1, len(ys)), max(ix - r, 0), min(ix + r + 1, len(xs))
        sub = Hh[y0:y1, x0:x1]
        gy, gx = np.mgrid[y0:y1, x0:x1]
        d = np.hypot((gx - ix) * fine, (gy - iy) * fine)
        return float(max((sub - slope * d).max(), 0.0))
    rng = random.Random(11)
    ph = [rng.uniform(0, 6.28) for _ in range(6)]

    def fn(u, v):
        # the far hem tucks over the shoulders; the near rows hang down over the feet
        x = -W / 2 + W * u
        y = y_top - Lb * (1 - v)
        z = zf(x, y)
        ground = 1.0 - min(z / 0.05, 1.0)
        z = z + 0.012 + 0.010 * math.sin(9 * x + ph[0]) * math.sin(5 * y + ph[1]) + ground * (0.018 * max(0.0, math.sin(23 * x + 7 * y + ph[2])))
        # pull the hem in where it hangs (cloth has a fixed length; the drop eats width)
        pull = 0.06 * (1 - ground) * 0 + 0.05 * (abs(2 * u - 1) ** 3) * min(zf(0.0, y) / 0.2, 1.0)
        x = x - math.copysign(pull, x)
        return (x, y, max(z, 0.004))
    P.grid_uv(fn, nu, nv, "FoilGold", ntile(W, 0.36) // 2 or 1, ntile(Lb, 0.36) // 2 or 1)
    atts = [("ATT_Head", (0.0, y_top + 0.12, 0.10)), ("ATT_Casualty", (0.0, 0.0, 0.0)), ("ATT_Grip", (W / 2 - 0.05, 0.0, 0.02))]
    return [("Draped", "Soft", P)], atts, ((-W / 2, y_top - Lb, 0), (W / 2, y_top, 0.3))


# ================================================================ crew bags (hi-vis yellow over navy)
def _bag(P, Hd, a, b, h, seed, patch):
    soft_wall(P, "NavyNylon", a, b, 0.0, 0.06, n=5.0, bulge=0.0, nu=32, nv=1, seed=seed, wob=0.002)
    soft_wall(P, "HiVisNylon", a, b, 0.06, h, n=5.0, bulge=0.04, nu=32, nv=4, seed=seed + 1, wob=0.004)
    soft_cap(P, "HiVisNylon", a, b, h, n=5.0, dome=0.02, nu=32, nr=3)
    soft_cap(P, "NavyNylon", a, b, 0.0, n=5.0, nu=32, nr=2, top=False)
    for z, k in ((0.06, 1.0), (h, 1.0)):
        P.tube2(ring_pts(a, b, z, n=5.0, segs=32), 0.005, 5, "ZipBlack", closed=True, k=1)
    # retro band round the body
    pts = ring_pts(a, b, h * 0.62, n=5.0, k=1.0 + 0.04 * math.sin(math.pi * (h * 0.62 - 0.06) / (h - 0.06)) + 0.003, segs=32)
    ribbon(P, pts + [pts[0]], 0.025, "Retro", up=lambda p: (p[0] / a ** 2, p[1] / b ** 2, 0), lift=0.0)
    # U-shaped zip on the lid
    zp = [(-a * 0.8, -b * 0.75, h + 0.012)] + [(a * 0.8 * math.cos(math.pi - t), -b * 0.75 + 0.0, h + 0.012) for t in np.linspace(0, math.pi, 2)][1:]
    zp = [(-a * 0.82, b * 0.7, h + 0.010), (-a * 0.82, -b * 0.72, h + 0.012), (a * 0.82, -b * 0.72, h + 0.012), (a * 0.82, b * 0.7, h + 0.010)]
    ribbon(P, zp, 0.012, "ZipBlack", up=(0, 0, 1), lift=0.004)
    handle(P, -a * 0.35, a * 0.35, -b * 0.15, h + 0.016, 0.10, grip="Webbing")
    handle(P, -a * 0.35, a * 0.35, b * 0.15, h + 0.016, 0.10)
    # zip pullers and the front patch
    for x in (a * 0.82, a * 0.6):
        Hd.lathe_uv([(0.0, 0.0), (0.006, 0.0), (0.006, 0.03), (0.0, 0.03)], 6, "BlackABS",
                    M=frame(x, -b * 0.72 - 0.004, h + 0.018, pitch=-100), cap0=True)
    pw, ph_ = patch[1], patch[2]
    o = (-pw / 2, -b * 1.04 - 0.0035, h * 0.5 - ph_ / 2 + 0.035)
    decal(P, patch[0], o, (1, 0, 0), (0, 0, 1), pw, ph_)
    for sx in (-1, 1):
        Hd.torus_uv(0.014, 0.003, 12, 5, "Stainless", M=frame(sx * a * 1.0, 0.0, h - 0.03, yaw=90, pitch=90))


def first_aid_bag():
    P, Hd = HP("Bag"), HP("Hardware")
    a, b, h = 0.25, 0.15, 0.29
    _bag(P, Hd, a, b, h, 21, ("CrossPatch", 0.12, 0.12))
    atts = [("ATT_Grip", (0.0, 0.0, h + 0.11)), ("ATT_Open", (0.0, -b * 0.72, h + 0.012)), ("ATT_Strap_L", (-a, 0, h - 0.03)),
            ("ATT_Strap_R", (a, 0, h - 0.03))]
    return [("Bag", "Soft", P), ("Hardware", "Hard", Hd)], atts, ((-a, -b, 0), (a, b, h + 0.12))


def oxygen_bag():
    P, Hd = HP("Bag"), HP("Hardware")
    a, b, h = 0.26, 0.11, 0.24
    _bag(P, Hd, a, b, h, 31, ("OxyPatch", 0.20, 0.08))
    # CD-size cylinder strapped along the front (white, label band, valve and grey guard)
    C = HP("Cylinder")
    rc = 0.05
    cy, cz = -b * 1.06 - rc, rc
    Mc = frame(-0.27, cy, cz, roll=90)
    C.lathe_uv([(0.0, 0.0), (0.035, 0.0), (rc - 0.004, 0.004), (rc, 0.012), (rc, 0.10)], 16, "CylWhite", M=Mc)
    C.lathe_uv([(rc, 0.10), (rc + 0.0005, 0.30)], 16, "CylLabel", M=Mc)
    C.lathe_uv([(rc, 0.30), (rc, 0.40), (rc - 0.008, 0.425), (0.022, 0.445), (0.014, 0.45)], 16, "CylWhite", M=Mc)
    C.lathe_uv([(0.014, 0.45), (0.016, 0.47), (0.013, 0.50), (0.0, 0.505)], 10, "Brass", M=Mc)
    # valve guard: grey moulded cage with a carry slot, contents gauge and outlet
    C.lathe_uv([(0.0, 0.0), (0.044, 0.0), (0.046, 0.02), (0.044, 0.085), (0.034, 0.10), (0.0, 0.102)], 14, "GreyABS",
               M=Mc @ frame(0, 0, 0.44))
    C.lathe_uv([(0.0, 0.0), (0.016, 0.0), (0.016, 0.008), (0.0, 0.009)], 12, "BlackABS", M=Mc @ frame(0.0, -0.046, 0.50, pitch=90))
    C.lathe_uv([(0.0, 0.0), (0.006, 0.0), (0.005, 0.03), (0.0, 0.032)], 8, "Brass", M=Mc @ frame(0.046, 0.0, 0.48, roll=90))
    for x in (-0.15, 0.08):
        ribbon(P, [(x, -b * 1.02, cz + rc * 1.3)] + [(x, cy + (rc + 0.003) * math.sin(t), cz + (rc + 0.003) * math.cos(t)) for t in np.linspace(-0.3, math.pi + 0.3, 10)]
               + [(x, -b * 1.02, 0.004)], 0.025, "Webbing", up=lambda p: (0, p[1] - cy, p[2] - cz), lift=0.0)
    # non-rebreather mask and reservoir bag on the lid, green tubing to the outlet
    Mk = HP("Mask")
    Mm = frame(0.08, 0.0, h + 0.03, pitch=-80)

    def shell(u, v):
        t = 2 * math.pi * u
        x, y = math.cos(t) * 0.055, math.sin(t) * 0.065
        k = 1 - v
        return tuple(Mm @ Vector((x * math.sqrt(max(1 - v * v, 0.0)) * (0.3 + 0.7 * k) / max(0.3 + 0.7 * k, 1e-3), y * math.sqrt(max(1 - v * v, 0.0)), 0.045 * v)))
    Mk.grid_uv(shell, 14, 4, "MaskPVC", 1, 1, closed_u=True)
    Mk.torus_uv(0.06, 0.004, 14, 3, "MaskPVC", M=Mm, sr=1.0)

    def res(u, v):
        t = 2 * math.pi * u
        s = math.sin(math.pi * v)
        return (-0.08 + 0.09 * math.cos(t) * s * (1 + 0.08 * math.sin(3 * t)), 0.0 + 0.06 * math.sin(t) * s, h + 0.02 + 0.10 * (1 - math.cos(math.pi * v)) * 0.18 + 0.025 * s)
    Mk.grid_uv(res, 12, 5, "MaskPVC", 1, 1, closed_u=True)
    ribbon(Mk, [tuple(Mm @ Vector((0.06 * math.cos(t), 0.065 * math.sin(t), 0.004))) for t in np.linspace(0.3, 2 * math.pi - 0.3, 16)], 0.006, "Webbing",
           up=lambda p: (0, 0, 1), lift=0.0)
    out = Mc @ frame(0.046, 0.0, 0.48, roll=90) @ Vector((0, 0, 0.03))
    tp = [tuple(Mm @ Vector((0, 0.05, 0.02))), (0.0, 0.12, h + 0.03), (0.2, 0.10, h + 0.02), (0.30, 0.0, h - 0.02),
          (0.32, -0.10, h * 0.6), (out.x + 0.04, out.y + 0.02, out.z + 0.03), tuple(out)]
    Mk.tube2(tp, 0.0035, 4, "TubeGreen", caps=True)
    atts = [("ATT_Grip", (0.0, 0.0, h + 0.11)), ("ATT_Mask", tuple(Mm @ Vector((0, 0, 0.02)))), ("ATT_Valve", tuple(out)),
            ("ATT_Cylinder", (0.0, cy, cz)), ("ATT_Open", (0.0, -b * 0.72, h + 0.012))]
    return [("Bag", "Soft", P), ("Hardware", "Hard", Hd), ("Cylinder", "Hard", C), ("Mask", "Soft", Mk)], atts, \
        ((-0.30, cy - rc, 0), (0.30, b, h + 0.12))


# ================================================================ handheld VHF
def vhf():
    P = HP("Body")
    a, b, h = 0.030, 0.019, 0.13
    z0 = 0.0
    soft_wall(P, "VHFBody", a, b, z0, 0.045, n=5.0, nu=28, nv=2, wob=0.0)
    soft_wall(P, "HiVisABS", a * 1.03, b * 1.03, 0.045, 0.095, n=5.0, nu=28, nv=2, wob=0.0)
    soft_wall(P, "VHFBody", a, b, 0.095, h, n=5.0, nu=28, nv=2, wob=0.0)
    soft_cap(P, "VHFBody", a, b, h, n=5.0, dome=0.003, nu=28, nr=2)
    soft_cap(P, "VHFBody", a, b, z0, n=5.0, nu=28, nr=2, top=False)
    # front face: LCD and keypad decal on a slightly proud panel
    fw, fh = 0.048, 0.112
    o = (-fw / 2, -b - 0.0012, 0.009)
    P.grid_uv(lambda u, v: (o[0] + fw * u, o[1] - 0.0008 * math.sin(math.pi * u), o[2] + fh * v), 4, 6, "VHFFace", 1, 1)
    # knobs, antenna, PTT, belt clip, lanyard
    for x, r, hh in ((-0.012, 0.0085, 0.014), (0.012, 0.007, 0.011)):
        P.lathe_uv([(r, 0.0), (r, hh * 0.85), (r * 0.85, hh), (0.0, hh)], 12, "Rubber", M=frame(x, 0.0, h))
    P.lathe_uv([(0.0075, 0.0), (0.0068, 0.04), (0.0052, 0.11), (0.0045, 0.118), (0.0, 0.12)], 10, "Rubber", M=frame(0.0, 0.006, h))
    P.tube2([(-a - 0.001, 0.0, 0.07), (-a - 0.001, 0.0, 0.10)], 0.0045, 6, "Rubber", caps=True, rz=0.0075)
    P.lathe_uv([(0.0, 0.0), (0.016, 0.0), (0.016, 0.004), (0.0, 0.0045)], 4, "BlackABS", M=frame(0.0, b + 0.002, 0.07, pitch=-90, yaw=45))
    P.tube2([(0.0, b + 0.004, 0.11), (0.0, b + 0.012, 0.09), (0.0, b + 0.012, 0.04), (0.0, b + 0.006, 0.03)], 0.0035, 4, "BlackABS",
            caps=True, rz=0.012)
    P.torus_uv(0.008, 0.0025, 10, 4, "BlackABS", M=frame(a * 0.7, 0.0, -0.006, pitch=90))
    atts = [("ATT_Grip", (0.0, 0.0, 0.06)), ("ATT_PTT", (-a - 0.004, 0.0, 0.085)), ("ATT_Antenna", (0.0, 0.006, h + 0.12)),
            ("ATT_Speaker", (0.0, -b - 0.003, 0.03)), ("ATT_Screen", (0.0, -b - 0.003, 0.10))]
    return [("Body", "Hard", P)], atts, ((-a, -b, 0), (a, b + 0.012, h + 0.12))


# ================================================================ pyrotechnics and strobe
def hand_flare():
    P, Ln = HP("Body"), HP("Lens")
    r = 0.019
    grip = [(0.0, 0.0), (0.016, 0.0), (0.017, 0.004)]
    for k in range(6):
        z = 0.008 + 0.0165 * k
        grip += [(0.0165, z), (0.0175, z + 0.005), (0.0175, z + 0.011), (0.0165, z + 0.0165)]
    grip += [(r + 0.0015, 0.105), (r, 0.11)]
    P.lathe_uv(grip, 14, "BlackABS")
    P.lathe_uv([(r, 0.11), (r, 0.225)], 16, "HandLabel")
    P.lathe_uv([(r, 0.225), (r + 0.001, 0.232), (r - 0.001, 0.235)], 16, "FlareRed")
    Ln.lathe_uv([(r - 0.001, 0.235), (0.017, 0.245), (0.012, 0.252), (0.0, 0.254)], 16, "LensRed")
    P.torus_uv(0.009, 0.002, 10, 4, "Stainless", M=frame(0.0, 0.0, -0.008, pitch=90))
    atts = [("ATT_Grip", (0.0, 0.0, 0.055)), ("ATT_Lens", (0.0, 0.0, 0.25)), ("ATT_Flame", (0.0, 0.0, 0.26)), ("ATT_Striker", (0.0, 0.0, -0.01))]
    return [("Body", "Hard", P), ("Lens", "Hard", Ln)], atts, ((-r, -r, 0), (r, r, 0.254))


def para_flare():
    P, Ln = HP("Body"), HP("Lens")
    r = 0.022
    P.lathe_uv([(0.0, 0.0), (0.020, 0.0), (r + 0.002, 0.004), (r + 0.002, 0.03), (r, 0.034)], 16, "BlackABS")
    P.lathe_uv([(r, 0.034), (r, 0.32)], 16, "ParaLabel")
    P.lathe_uv([(r, 0.32), (r + 0.002, 0.325), (r + 0.002, 0.338), (r - 0.002, 0.34)], 16, "BlackABS")
    Ln.lathe_uv([(r - 0.002, 0.34), (0.018, 0.346), (0.0, 0.348)], 16, "LensRed")
    # firing lever folded along the base, safety pin with ring
    P.tube2([(r + 0.004, 0.0, 0.035), (r + 0.007, 0.0, 0.10)], 0.004, 6, "BlackABS", caps=True, rz=0.008)
    P.tube2([(r - 0.003, 0.0, 0.03), (r + 0.012, 0.0, 0.03)], 0.0015, 4, "Stainless", caps=True)
    P.torus_uv(0.010, 0.002, 10, 4, "Stainless", M=frame(r + 0.021, 0.0, 0.03, pitch=90))
    atts = [("ATT_Grip", (0.0, 0.0, 0.08)), ("ATT_Lens", (0.0, 0.0, 0.345)), ("ATT_Launch", (0.0, 0.0, 0.36)),
            ("ATT_Trigger", (r + 0.007, 0.0, 0.06)), ("ATT_Pin", (r + 0.021, 0.0, 0.03))]
    return [("Body", "Hard", P), ("Lens", "Hard", Ln)], atts, ((-r, -r, 0), (r + 0.031, r, 0.348))


def strobe():
    P, Ln = HP("Body"), HP("Lens")
    a, b, h = 0.022, 0.014, 0.07
    soft_wall(P, "SolasABS", a, b, 0.0, h, n=4.0, nu=24, nv=3, wob=0.0)
    soft_cap(P, "SolasABS", a, b, 0.0, n=4.0, nu=24, nr=2, top=False)
    soft_cap(P, "SolasABS", a, b, h, n=4.0, nu=24, nr=2)
    P.lathe_uv([(0.0165, 0.0), (0.0165, 0.004)], 16, "BlackABS", M=frame(0.0, 0.0, h))
    Ln.lathe_uv([(0.016, 0.0), (0.016, 0.006), (0.013, 0.016), (0.008, 0.021), (0.0, 0.023)], 16, "LensClear", M=frame(0.0, 0.0, h + 0.004))
    # lifejacket clip on the back, water-sense contacts / switch on the front
    P.tube2([(0.0, b + 0.001, h * 0.85), (0.0, b + 0.006, h * 0.75), (0.0, b + 0.006, h * 0.2), (0.0, b + 0.003, h * 0.12)],
            0.0025, 4, "BlackABS", caps=True, rz=0.010)
    P.lathe_uv([(0.0, 0.0), (0.006, 0.0), (0.006, 0.002), (0.0, 0.0025)], 10, "Rubber", M=frame(0.0, -b, h * 0.45, pitch=90))
    for x in (-0.009, 0.009):
        P.lathe_uv([(0.0, 0.0), (0.0018, 0.0), (0.0018, 0.0012), (0.0, 0.0014)], 6, "Stainless", M=frame(x, -b, h * 0.15, pitch=90))
    atts = [("ATT_Lens", (0.0, 0.0, h + 0.016)), ("ATT_Clip", (0.0, b + 0.006, h * 0.5)), ("ATT_Grip", (0.0, 0.0, h * 0.5)),
            ("ATT_Switch", (0.0, -b - 0.002, h * 0.45))]
    return [("Body", "Hard", P), ("Lens", "Hard", Ln)], atts, ((-a, -b, 0), (a, b + 0.006, h + 0.027))


# ================================================================ registry and spec
# asset: (builder, docs/12 row ceiling, real class)
KIT = {
    "M_Kit_ThrowBag": (throw_bag, 2500, "Rescue throw bag about 0.35 m x 0.15 m diameter, floating line in the bag (verify)"),
    "M_Kit_ThrowLine": (throw_line, 2500, "15 m of 8 mm floating polypropylene throw line, loosely coiled (verify)"),
    "M_Kit_RescueTube": (rescue_tube, 1500, "Foam lifeguard rescue tube about 1.0 x 0.15 x 0.08 m with clip and 2 m leash (verify)"),
    "M_Kit_Lifebuoy": (lifebuoy, 1500, "SOLAS lifebuoy 0.75 m OD (docs/05) with self-igniting light and retro tape"),
    "M_Kit_ThermalBlanket": (blanket_folded, 2000, "Foil survival blanket 2.1 x 1.3 m, folded pack (verify)"),
    "M_Kit_ThermalBlanketDraped": (blanket_draped, 2000, "Foil survival blanket 2.1 x 1.3 m draped over a supine casualty (verify)"),
    "M_Kit_FirstAidBag": (first_aid_bag, 2500, "Response bag about 0.5 x 0.3 x 0.3 m (verify; RNLI Casualty Care)"),
    "M_Kit_OxygenBag": (oxygen_bag, 2500, "Oxygen bag with CD-size cylinder about 0.55 m and non-rebreather mask (verify)"),
    "M_Kit_VHFHandset": (vhf, 3000, "Handheld marine VHF about 0.13 x 0.06 x 0.04 m body plus antenna (verify)"),
    "M_Kit_HandFlare": (hand_flare, 1200, "Red hand flare about 0.25 m (verify)"),
    "M_Kit_ParaFlare": (para_flare, 1200, "Parachute rocket flare about 0.35 m (verify)"),
    "M_Kit_Strobe": (strobe, 1200, "Lifejacket strobe light about 0.1 m (verify)"),
}


def material(set_name):
    return hp.kit.material("MI_%s_%s" % (atlas.NAME, set_name), (0.4, 0.3, 0.1) if set_name == "Soft" else (0.15, 0.15, 0.16))


def lods(obj):
    import versions
    out = []
    n0 = versions.triangles(obj.data)
    for lod, share in (("LOD1", 0.5), ("LOD2", 0.25)):
        o = versions.copy_object(obj, obj.name.replace("_LOD0", "_" + lod))
        try:
            versions.decimate(o, max(int(n0 * share), 8))
        except RuntimeError:
            pass
        versions.weighted_normals(o)
        out.append(hp.clean(o))
    return out


def build_kit(asset):
    fn, ceiling, real = KIT[asset]
    parts, atts, colbox = fn()
    allv = [v for _, _, P in parts for v in P.v]
    lo0 = Vector([min(v[i] for v in allv) for i in range(3)])
    hi0 = Vector([max(v[i] for v in allv) for i in range(3)])
    off = Vector((-(lo0.x + hi0.x) / 2, -(lo0.y + hi0.y) / 2, -lo0.z))
    for _, _, P in parts:
        P.v = [Vector(v) + off for v in P.v]
    atts = [(n, tuple(Vector(p) + off)) for n, p in atts]
    meshes, lod_meshes, total, used, per = [], [], 0, set(), []
    for sub, sname, P in parts:
        name = "%s_LOD0" % asset if sub == parts[0][0] else "%s_%s_LOD0" % (asset, sub)
        obj = P.to_object(name, material(sname))
        hp.clean(obj)
        meshes.append({"object": obj, "set": sname})
        n = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        per.append((name, n))
        total += n
        used.add(sname)
    for e in list(meshes):
        for o in lods(e["object"]):
            meshes.append({"object": o, "set": e["set"]})
    lo = [min(v.co[i] for m in meshes[:len(parts)] for v in m["object"].data.vertices) / STUDS for i in range(3)]
    hi = [max(v.co[i] for m in meshes[:len(parts)] for v in m["object"].data.vertices) / STUDS for i in range(3)]
    dims = tuple(round(hi[i] - lo[i], 3) for i in range(3))
    meshes.append({"object": hp.box_col(asset, tuple(lo), tuple(hi))})
    ref_dir = os.path.join(G, "art/reference", asset)
    os.makedirs(ref_dir, exist_ok=True)
    dims_path = os.path.join(ref_dir, "dims.md")
    if os.path.exists(dims_path):   # keep the researched class sizes and sources (R0); E1 notes are appended by hand
        pass
    else:
      with open(dims_path, "w") as fh:
        fh.write("# %s\n\nReal class: %s (docs/12 2.8 row; general knowledge, verify against a manufacturer class page).\n\n"
                 "dims_m: %s x %s x %s\n\n(X, Y, Z metres, front -Y, base at Z 0: the authored size of the E1 build, "
                 "art/source/kit/E1/kitgeo.py. Reference photo board: pending, see art/status/E1.csv.)\n"
                 % (asset, real, dims[0], dims[1], dims[2]))
    attachments = [hp.att(n, p) for n, p in atts]
    sets = [{"name": atlas.NAME, "set": s, "size": atlas.EXPORT, "wet": True, "dir": TEX_DIR} for s in sorted(used)]
    reach = max(dims) * STUDS
    print("[E1] %s LOD0 %d tris (row ceiling %d) %s dims %s" % (asset, total, ceiling, per, dims))
    return {
        "name": asset, "budget": "large_prop", "tris": max(ceiling, 1000), "tier": "hero",
        "dims_m": dims, "size_note": None, "origin": "base",
        "sets": sets, "atlas": atlas.ATLAS_ASSET, "meshes": meshes, "attachments": attachments,
        "tiling": False, "lod_symmetry": None,
        "waivers": {"LOD UV layout": "collapse decimation of small atlas-tiled kit shifts UV area (same regions sampled)",
                    "LOD0 floor": "hand-held kit item: the docs/12 2.8 row budget is below the large_prop floor",
                    "texel density": "atlas tiles are 118 px/stud at 1024 (hero 100-128); fit decals and small lathes run higher, "
                                     "the draped blanket's single foil tile per 0.7 m runs lower (seen at 2 m, not in hand)"},
        "closeups": [{"name": "detail", "target": [0, 0, dims[2] * STUDS * 0.6], "dist": max(reach * 0.9, 1.2), "az": 35, "el": 25}],
    }
