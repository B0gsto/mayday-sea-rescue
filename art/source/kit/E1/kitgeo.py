"""E1b hand-held rescue kit (docs/12 2.8): geometry for every kit item on the kit atlas M_Kit_Atlas (atlas.py).

Runs inside Blender (tools/blender/run.py via art/source/kit/<Asset>/build.py, or run_all.py). Authored in metres, front
-Y, base at Z 0, with the HP2a harbour prop primitives (art/source/harbour/M_Hbr_PropAtlas/props.py HP: lathe_uv,
torus_uv, tube2, grid_uv on shared verts with explicit atlas UVs), imported read-only with this folder's atlas cached
first. Every MeshPart uses one set (Cloth, Soft, Foil or Hard); emissive heads (flare heads, strobe dome, buoy light)
are their own `_Lens` MeshParts on the Hard set, so the game can make them Neon / add a light at ATT_Lens.

E1b (first-person fix round): soft walls run arc-length UVs on whole tiles and lids / bases use a square-to-superellipse
grid with whole tiles (the E1 radial caps pinched the weave to a point: the smeared texel noise); strips (webbing,
seams, zips, retro tape) run STRIP_K widths per tile; piping, stitched seams, sewn retro tape, zips with sliders and
pulls, side-release and ladder-lock buckles, D rings, strap tabs; the draped foil blanket is a Blender cloth sim over a
supine body proxy, baked, two-layered (gold up, silver under).
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
SET_COL = {"Cloth": (0.5, 0.3, 0.1), "Soft": (0.6, 0.3, 0.1), "Foil": (0.7, 0.6, 0.3), "Hard": (0.15, 0.15, 0.16)}


def ntile(L, s=T):
    return max(1, int(round(L / s)))


def mult(n, k):
    return k * max(1, int(math.ceil(n / k)))


# ---------------------------------------------------------------- shared shapes
def sq(t, n=4.0):
    """Superellipse point (cos, sin) at angle t (n=2 ellipse, larger = boxier)."""
    c, s = math.cos(t), math.sin(t)
    return math.copysign(abs(c) ** (2.0 / n), c), math.copysign(abs(s) ** (2.0 / n), s)


def soft_wall(P, region, a, b, z0, z1, n=4.0, bulge=0.0, nu=32, nv=6, seed=0, cx=0.0, cy=0.0, wob=0.004):
    """(E1, VHF only) side wall: superellipse section a x b."""
    rng = random.Random(seed)
    ph = [rng.uniform(0, 6.28) for _ in range(4)]
    per = 2 * (a + b) * 1.9

    def fn(u, v):
        t = 2 * math.pi * u
        x, y = sq(t, n)
        k = 1.0 + bulge * math.sin(math.pi * v) + wob * (math.sin(5 * t + ph[0]) * math.sin(3 * math.pi * v + ph[1]))
        z = z0 + (z1 - z0) * v
        return (cx + a * k * x, cy + b * k * y, z)
    tu = ntile(per, atlas.scale(region) or T)
    P.grid_uv(fn, mult(nu, tu), nv, region, tu, ntile(z1 - z0, atlas.scale(region) or T), closed_u=True)


def soft_cap(P, region, a, b, z, n=4.0, dome=0.0, nu=32, nr=4, top=True, cx=0.0, cy=0.0):
    """(E1, VHF only) radial cap."""
    def fn(u, v):
        t = 2 * math.pi * u
        x, y = sq(t, n)
        r = 1.0 - v * 0.999
        return (cx + a * r * x, cy + b * r * y, z + (dome * (1 - r * r) if top else -dome * (1 - r * r)))
    f0 = len(P.f)
    P.grid_uv(fn, nu, nr, region, 1, 1, closed_u=True)
    if not top:
        flip(P, f0)


def flip(P, f0):
    P.f[f0:] = [(list(reversed(i)), r, ("uv", list(reversed(fit[1])))) for i, r, fit in P.f[f0:]]


def se_loop(a, b, n, N, k=1.0):
    """N points on the superellipse a x b spaced by ARC LENGTH, with outward normals (x, y, nx, ny), and its length."""
    M = 2048
    dense = [sq(2 * math.pi * i / M, n) for i in range(M + 1)]
    dense = [(a * k * x, b * k * y) for x, y in dense]
    cum = [0.0]
    for p, q in zip(dense[:-1], dense[1:]):
        cum.append(cum[-1] + math.hypot(q[0] - p[0], q[1] - p[1]))
    L = cum[-1]
    out = []
    j = 0
    for i in range(N):
        s = L * i / N
        while cum[j + 1] < s:
            j += 1
        f = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-12)
        x = dense[j][0] + (dense[j + 1][0] - dense[j][0]) * f
        y = dense[j][1] + (dense[j + 1][1] - dense[j][1]) * f
        tx, ty = dense[j + 1][0] - dense[j][0], dense[j + 1][1] - dense[j][1]
        tl = math.hypot(tx, ty) or 1.0
        out.append((x, y, ty / tl, -tx / tl))
    return out, L


class Wall:
    """Soft bag wall: superellipse section a x b, arc-length U, bulging at mid height, puckers; pt(s, z) is the
    surface point (s = arc fraction 0..1 from +X counter-clockwise) so straps, seams and decals can sit on it."""

    def __init__(self, a, b, z0, z1, n=4.0, bulge=0.0, wob=0.0, seed=0, cx=0.0, cy=0.0):
        self.a, self.b, self.z0, self.z1, self.n, self.bulge, self.wob = a, b, z0, z1, n, bulge, wob
        self.cx, self.cy = cx, cy
        rng = random.Random(seed)
        self.ph = [rng.uniform(0, 6.28) for _ in range(8)]
        self.loop, self.L = se_loop(a, b, n, 720)

    def k(self, s, z):
        v = (z - self.z0) / max(self.z1 - self.z0, 1e-9)
        t = 2 * math.pi * s
        ph = self.ph
        w = self.wob * (math.sin(5 * t + ph[0]) * math.sin(3 * math.pi * v + ph[1]) + 0.6 * math.sin(11 * t + ph[2]) * math.sin(5 * math.pi * v + ph[3])
                        + 0.4 * math.sin(17 * t + ph[4]) * math.sin(2 * math.pi * v + ph[5]))
        return 1.0 + self.bulge * math.sin(math.pi * min(max(v, 0.0), 1.0)), w

    def pt(self, s, z, lift=0.0):
        i = (s % 1.0) * len(self.loop)
        i0 = int(i) % len(self.loop)
        i1 = (i0 + 1) % len(self.loop)
        f = i - int(i)
        x = self.loop[i0][0] * (1 - f) + self.loop[i1][0] * f
        y = self.loop[i0][1] * (1 - f) + self.loop[i1][1] * f
        nx = self.loop[i0][2] * (1 - f) + self.loop[i1][2] * f
        ny = self.loop[i0][3] * (1 - f) + self.loop[i1][3] * f
        k, w = self.k(s, z)
        return (self.cx + x * k + nx * (w + lift), self.cy + y * k + ny * (w + lift), z)

    def nrm(self, s):
        i = int((s % 1.0) * len(self.loop)) % len(self.loop)
        return (self.loop[i][2], self.loop[i][3], 0.0)

    def build(self, P, region, nu=64, nv=12, z0=None, z1=None):
        z0 = self.z0 if z0 is None else z0
        z1 = self.z1 if z1 is None else z1
        S = atlas.scale(region) or T
        tu = ntile(self.L * (1 + self.bulge * 0.6), S)
        tv = ntile(z1 - z0, S)
        P.grid_uv(lambda u, v: self.pt(u, z0 + (z1 - z0) * v), mult(nu, tu), mult(nv, tv), region, tu, tv, closed_u=True)

    def ring(self, z, segs=96, lift=0.0, closed=True):
        pts = [self.pt(i / segs, z, lift) for i in range(segs)]
        return pts + [pts[0]] if closed else pts


def cap(P, region, a, b, z, n=4.0, dome=0.0, res=12, top=True, cx=0.0, cy=0.0, k=1.0, wob=0.0, seed=0):
    """Lid / base: square grid mapped to the superellipse (disc mapping then radial push), whole tiles in U and V, so
    the weave runs straight with no pinch."""
    S = atlas.scale(region) or T
    tu, tv = ntile(2 * a * k, S), ntile(2 * b * k, S)
    nu, nv = mult(res, tu), mult(max(4, int(res * b / a)), tv)
    rng = random.Random(seed)
    ph = [rng.uniform(0, 6.28) for _ in range(4)]

    def fn(u, v):
        s, t = 2 * u - 1, 2 * v - 1
        x, y = s * math.sqrt(max(1 - t * t / 2, 0)), t * math.sqrt(max(1 - s * s / 2, 0))
        r = math.hypot(x, y)
        if r > 1e-9:
            th = math.atan2(y, x)
            Rse = (abs(math.cos(th)) ** n + abs(math.sin(th)) ** n) ** (-1.0 / n)
            x, y = x * Rse, y * Rse
        w = wob * math.sin(7 * s + ph[0]) * math.sin(5 * t + ph[1]) * (1 - r * r)
        dz = (dome * (1 - min(r, 1) ** 2) + w) * (1 if top else -1)
        return (cx + a * k * x, cy + b * k * y, z + dz)
    f0 = len(P.f)
    P.grid_uv(fn, nu, nv, region, tu, tv)
    if not top:
        flip(P, f0)


def ring_pts(a, b, z, n=4.0, k=1.0, segs=48, cx=0.0, cy=0.0):
    return [(cx + a * k * sq(2 * math.pi * i / segs, n)[0], cy + b * k * sq(2 * math.pi * i / segs, n)[1], z) for i in range(segs)]


def ribbon(P, pts, width, region, up=None, lift=0.0015, both=False, nseg=None):
    """Flat strap (webbing, tape, seam, zip) along a polyline, `width` across, its face normal along `up` (a function
    p -> outward normal, or a fixed vector). strip regions: one tile per STRIP_K widths along; tile regions: scale."""
    Pv = [Vector(p) for p in pts]
    cum = [0.0]
    for a_, b_ in zip(Pv[:-1], Pv[1:]):
        cum.append(cum[-1] + (b_ - a_).length)
    L = cum[-1]
    if atlas.kind(region) == "strip":
        tiles = max(1, int(round(L / (width * atlas.STRIP_K))))
    else:
        tiles = ntile(L, atlas.scale(region) or T)
    nu = mult(nseg or max(len(Pv) - 1, int(L / max(width * 0.6, 0.004))), tiles)
    Q = []
    for i in range(nu + 1):
        s = L * i / nu
        j = min(int(np.searchsorted(cum, s, side="right")) - 1, len(Pv) - 2)
        t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-12)
        Q.append(Pv[j].lerp(Pv[j + 1], t))
    fr = []
    for i, p in enumerate(Q):
        t = (Q[min(i + 1, nu)] - Q[max(i - 1, 0)]).normalized()
        o = Vector(up(tuple(p))) if callable(up) else Vector(up or (0, 0, 1))
        o = (o - t * o.dot(t)).normalized()
        fr.append((t, o, t.cross(o).normalized()))

    def fn(u, v):
        i = min(int(round(u * nu)), nu)
        t, o, side = fr[i]
        return tuple(Q[i] + o * lift + side * (v - 0.5) * width)
    f0 = len(P.f)
    P.grid_uv(fn, nu, 1, region, tiles, 1)
    if both:
        P.double(f0, eps=0.0012)
    return Q


def rod(P, p0, p1, r, region, segs=8, r1=None):
    """Small solid rod / pin / bar on a tile region (lathe along p0 -> p1, capped)."""
    M, L = axis_frame(p0, p1)
    r1 = r if r1 is None else r1
    P.lathe_uv([(0.0, 0.0), (r, 0.0), (r1, L), (0.0, L)], segs, region, M=M)


def solid_box(P, c, size, region, n=6.0, segs=12, M=None):
    """Rounded moulded box (plastic body) centred on c (x, y) from z c[2] up, optional matrix."""
    Q = HP("_tmp")
    a, b, h = size[0] / 2, size[1] / 2, size[2]
    Wl = Wall(a, b, 0.0, h, n=n)
    Wl.build(Q, region, nu=segs, nv=1)
    cap(Q, region, a, b, h, n=n, res=3)
    cap(Q, region, a, b, 0.0, n=n, res=3, top=False)
    M = (Matrix.Translation((c[0], c[1], c[2])) if M is None else M @ Matrix.Translation((c[0], c[1], c[2])))
    b0 = len(P.v)
    P.v.extend(M @ Vector(v) for v in Q.v)
    P.f.extend(([i + b0 for i in idx], r, fit) for idx, r, fit in Q.f)


def decal(P, region, o, ua, va, w, h):
    o, ua, va = Vector(o), Vector(ua).normalized(), Vector(va).normalized()
    pts = [o, o + ua * w, o + ua * w + va * h, o + va * h]
    P.mesh([tuple(p) for p in pts], [(0, 1, 2, 3)], region, fit=fit_frame(o, ua, va, w, h, atlas.rect(region)))


def wall_decal(P, Wl, region, s0, s1, z0, z1, lift=0.0025, nu=8, nv=4):
    """Fit decal (patch, label) following the wall surface between arc fractions s0..s1 (s1 < s0 is fine)."""
    P.grid_uv(lambda u, v: Wl.pt(s0 + (s1 - s0) * u, z0 + (z1 - z0) * v, lift), nu, nv, region, 1, 1)


def snap_hook(P, p, axis=(1, 0, 0), L=0.08, r=0.0042, up=(0, 0, 1)):
    """Stainless snap hook: swivel eye, body with nose, spring gate and its pivot pin, along `axis` from p."""
    ax = Vector(axis).normalized()
    upv = Vector(up)
    side = ax.cross(upv).normalized()
    upv = side.cross(ax).normalized()

    def W(x, y):
        return tuple(Vector(p) + ax * x + upv * y)
    body = [W(0.010, 0.0), W(0.02, 0.012), W(L * 0.55, 0.015), W(L * 0.85, 0.012), W(L, 0.0), W(L * 0.92, -0.012), W(L * 0.80, -0.008)]
    for a_, b_ in zip(body[:-1], body[1:]):
        rod(P, a_, b_, r, "Stainless", 8)
    rod(P, W(0.02, -0.006), W(L * 0.78, -0.009), r * 0.75, "Stainless", 6)       # gate
    rod(P, W(0.016, -0.012), W(0.016, 0.014), r * 0.5, "Stainless", 6)             # pivot pin across
    d_ring(P, tuple(Vector(p) - ax * 0.003), side, R=0.009, r=r * 0.9)


def d_ring(P, c, normal, R=0.014, r=0.003, rot=0.0):
    """Stainless D ring: torus flattened on one side (straight bar)."""
    nrm = Vector(normal).normalized()
    M = Matrix.Translation(Vector(c)) @ nrm.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ Matrix.Rotation(rot, 4, 'Z')
    P.torus_uv(R, r, 14, 5, "Stainless", M=M)


def side_release(P, c, ax, up, w=0.032, L=0.06):
    """Side-release buckle: female housing, male tongue with two prongs and a centre bar, webbing slots."""
    ax, up = Vector(ax).normalized(), Vector(up).normalized()
    side = ax.cross(up).normalized()
    R = Matrix((list(side) + [0], list(ax) + [0], list(up) + [0], [0, 0, 0, 1])).transposed()
    R = R.to_3x3().to_4x4()
    c = Vector(c)
    solid_box(P, (0, 0, 0), (w, L * 0.5, 0.011), "BlackABS", n=8, segs=12, M=Matrix.Translation(c - ax * L * 0.22) @ R)
    solid_box(P, (0, 0, 0), (w * 0.9, L * 0.4, 0.008), "BlackABS", n=6, segs=12, M=Matrix.Translation(c + ax * L * 0.22) @ R)
    for sx in (-1, 1):
        solid_box(P, (0, 0, 0), (0.006, 0.016, 0.006), "BlackABS", n=4, segs=12, M=Matrix.Translation(c + side * sx * w * 0.42 - ax * L * 0.06 + up * 0.002) @ R)
    rod(P, c + ax * L * 0.4 - side * w * 0.42 + up * 0.004, c + ax * L * 0.4 + side * w * 0.42 + up * 0.004, 0.0022, "BlackABS", 6)


def ladder_lock(P, c, ax, up, w=0.03):
    ax, up = Vector(ax).normalized(), Vector(up).normalized()
    side = ax.cross(up).normalized()
    c = Vector(c)
    for k in (-1, 0, 1):
        rod(P, c + ax * k * 0.009 - side * w / 2, c + ax * k * 0.009 + side * w / 2, 0.0025, "BlackABS", 6)
    for sx in (-1, 1):
        rod(P, c + side * sx * w / 2 - ax * 0.012, c + side * sx * w / 2 + ax * 0.012, 0.003, "BlackABS", 6)


def zip_slider(P, p, ax, up, pull_len=0.03):
    """Zip slider body with a moulded pull tab (Hard)."""
    ax, up = Vector(ax).normalized(), Vector(up).normalized()
    side = ax.cross(up).normalized()
    R = Matrix((list(side) + [0], list(ax) + [0], list(up) + [0], [0, 0, 0, 1])).transposed().to_3x3().to_4x4()
    p = Vector(p)
    solid_box(P, (0, 0, 0), (0.012, 0.018, 0.006), "BlackABS", n=4, segs=12, M=Matrix.Translation(p) @ R)
    solid_box(P, (0, 0, 0), (0.008, pull_len, 0.003), "Rubber", n=6, segs=12,
              M=Matrix.Translation(p + up * 0.006 - ax * pull_len * 0.45) @ R)


# ================================================================ throw bag (SOLAS orange, line out of the mouth)
def throw_bag():
    B, D = HP("Bag"), HP("Toggle")
    r, H, zb = 0.075, 0.30, 0.045
    base = Wall(r, r, 0.0, zb, n=2.0, bulge=0.0, wob=0.0015, seed=2)
    body = Wall(r, r, zb, H, n=2.0, bulge=0.035, wob=0.0035, seed=3)
    cap(B, "NavyNylon", r, r, 0.0, n=2.0, res=12, top=False)
    base.build(B, "NavyNylon", nu=64, nv=3)
    body.build(B, "SolasNylon", nu=72, nv=20)

    # gathered mouth: the cloth pleats in towards the drawcord channel
    def collar(u, v):
        t = 2 * math.pi * u
        p0 = body.pt(u, H)
        rr = math.hypot(p0[0], p0[1]) * (1 - 0.58 * v) * (1 + 0.09 * v * math.sin(14 * t)) + 0.004 * v * math.sin(23 * t)
        return (rr * math.cos(t), rr * math.sin(t), H + 0.038 * math.sin(0.5 * math.pi * v) + 0.004 * v * math.cos(14 * t))
    B.grid_uv(collar, 72, 6, "SolasNylon", 3, 1, closed_u=True)
    rm = r * 0.42
    B.torus_uv(rm, 0.0085, 48, 8, "SolasNylon", M=frame(0, 0, H + 0.040), sr=0.8, rep_u=1)          # drawcord channel hem
    cap(B, "NavyNylon", rm * 0.85, rm * 0.85, H + 0.036, n=2.0, res=6, dome=-0.006)                  # dark throat
    # coiled line visible in the throat
    for k in range(3):
        rr_ = rm * (0.68 - 0.17 * k)
        B.tube2([(rr_ * math.cos(2 * math.pi * j / 16 + k), rr_ * math.sin(2 * math.pi * j / 16 + k), H + 0.034 - 0.002 * k) for j in range(16)],
                0.005, 6, "CordYellow", closed=True, k=1)
    # piping at the base seam and the bottom edge
    B.tube2(base.ring(zb, 64, 0.001), 0.0042, 6, "CordBlack", closed=False, k=2)
    B.tube2(base.ring(0.003, 64, 0.0), 0.0042, 6, "CordBlack", closed=False, k=2)
    # vertical side seam at the back (-X), worn sewn retro band, webbing handle up the +X side with a top loop
    ribbon(B, [body.pt(0.5, z, 0.0012) for z in np.linspace(zb + 0.002, H - 0.002, 16)], 0.016, "SeamSolas", up=lambda p: (p[0], p[1], 0))
    ribbon(B, [body.pt(i / 96, 0.205, 0.0016) for i in range(97)], 0.05, "RetroSewn", up=lambda p: (p[0], p[1], 0))
    hz = [z for z in np.linspace(0.06, H - 0.01, 14)]
    ribbon(B, [body.pt(0.0, z, 0.0018) for z in hz], 0.025, "Webbing", up=(1, 0, 0))
    top = body.pt(0.0, H - 0.01, 0.0018)
    loop = [top, (top[0] + 0.02, 0, H + 0.02), (top[0] + 0.028, 0, H + 0.055), (top[0] + 0.012, 0, H + 0.075),
            (top[0] - 0.012, 0, H + 0.06), (top[0] - 0.016, 0, H + 0.036)]
    ribbon(B, loop, 0.025, "Webbing", up=lambda p: (p[0] - top[0] + 0.002, 0, p[2] - H - 0.04), both=True)
    # black drawcord: two strands out of the channel at the front, through the toggle, knotted ends
    ex = Vector((0.0, -rm - 0.006, H + 0.040))
    tg = Vector((0.004, -rm - 0.03, H + 0.005))
    for sx in (-1, 1):
        B.tube2([tuple(ex + Vector((sx * 0.004, 0, 0))), tuple(ex + Vector((sx * 0.003, -0.012, -0.01))), tuple(tg + Vector((sx * 0.0018, 0, 0.012))),
                 tuple(tg + Vector((sx * 0.0018, 0, -0.012))), tuple(tg + Vector((sx * 0.003 + 0.002, -0.004, -0.03))),
                 tuple(tg + Vector((sx * 0.006 + 0.002, -0.006, -0.045)))], 0.0026, 6, "CordBlack", caps=True, k=2)
        B.torus_uv(0.0035, 0.0026, 8, 6, "CordBlack", M=frame(tg.x + sx * 0.006 + 0.002, tg.y - 0.006, tg.z - 0.048, pitch=90))
    # cord lock toggle: barrel with a spring button and cord hole rims
    Mt = frame(tg.x, tg.y, tg.z - 0.012)
    D.lathe_uv([(0.0, 0.0), (0.008, 0.0), (0.0095, 0.004), (0.0095, 0.018), (0.008, 0.022), (0.0, 0.022)], 16, "BlackABS", M=Mt)
    D.lathe_uv([(0.0, 0.0), (0.0055, 0.0), (0.0055, 0.006), (0.004, 0.0075), (0.0, 0.0078)], 12, "Rubber", M=Mt @ frame(0, 0, 0.022))
    D.torus_uv(0.0045, 0.0012, 12, 4, "Rubber", M=Mt @ frame(0, -0.0094, 0.011, pitch=90))
    # brass drain eyelets round the navy base
    for k in range(4):
        s = 0.125 + 0.25 * k
        p = base.pt(s, 0.022, 0.0012)
        d_ring(D, p, base.nrm(s), R=0.0045, r=0.0012)
    # 10 mm floating line out of the mouth to the thrower's spliced hand loop
    line = [(0.0, 0.0, H + 0.02), (0.0, 0.0, H + 0.06), (0.012, -0.012, H + 0.09), (0.045, -0.03, H + 0.105), (0.085, -0.04, H + 0.095),
            (0.115, -0.04, H + 0.07), (0.13, -0.035, H + 0.045)]
    B.tube2(line, 0.005, 8, "CordYellow", caps=True, k=3)
    le = Vector((0.155, -0.03, H + 0.03))
    B.torus_uv(0.026, 0.005, 24, 8, "CordYellow", M=frame(le.x, le.y, le.z, yaw=-10, pitch=80))
    B.tube2([line[-1], (0.14, -0.033, H + 0.035)], 0.0065, 8, "CordYellow", caps=True, k=2)       # splice taper
    atts = [("ATT_Grip", (0.0, 0.0, 0.15)), ("ATT_Throw", (0.0, 0.0, 0.14)), ("ATT_LineEnd", tuple(le)),
            ("ATT_LineExit", (0.0, 0.0, H + 0.06))]
    return [("Bag", "Cloth", B), ("Toggle", "Hard", D)], atts


def throw_line():
    """15 m of 11 mm yellow floating braid, loosely coiled on deck after a recovery, spliced eye on the free end."""
    P = HP("Line")
    rng = random.Random(7)
    d = 0.011
    pts = []
    turns = 13
    for t in range(turns):
        R = 0.17 + 0.035 * rng.random()
        ox, oy = 0.025 * rng.uniform(-1, 1), 0.025 * rng.uniform(-1, 1)
        squash = 0.82 + 0.18 * rng.random()
        rot = rng.uniform(0, 6.28)
        for j in range(24):
            a = 2 * math.pi * (j / 24)
            x, y = R * math.cos(a), R * squash * math.sin(a)
            x, y = x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)
            z = d / 2 + d * 0.85 * ((t + j / 24) * 0.33 % 3) + 0.003 * math.sin(3 * a + t)
            pts.append((ox + x, oy + y, z))
    end = pts[-1]
    tail = [(end[0] + 0.05, end[1] - 0.04, d * 0.8), (end[0] + 0.15, end[1] - 0.12, d / 2), (end[0] + 0.30, end[1] - 0.15, d / 2),
            (end[0] + 0.40, end[1] - 0.12, d / 2)]
    P.tube2(pts + tail, d / 2, 8, "RopeThrow", caps=True, k=2)
    M = frame(tail[-1][0] + 0.045, tail[-1][1] + 0.01, d / 2)
    P.torus_uv(0.04, d / 2, 28, 8, "RopeThrow", M=M, sr=0.8)
    P.tube2([tail[-2], tail[-1], (tail[-1][0] + 0.01, tail[-1][1] + 0.004, d / 2)], d / 2 * 1.3, 8, "RopeThrow", caps=True, k=2)
    atts = [("ATT_Grip", (0.0, 0.0, 0.01)), ("ATT_LineEnd", (tail[-1][0] + 0.085, tail[-1][1] + 0.01, d / 2))]
    return [("Line", "Soft", P)], atts


# ================================================================ rescue tube (lifeguard foam tube)
def rescue_tube():
    P, H = HP("Tube"), HP("Hardware")
    L, w, th = 1.0, 0.15, 0.08

    def fn(u, v):
        t = 2 * math.pi * u
        x = -L / 2 + L * v
        e = abs(x) - (L / 2 - 0.075)
        k = math.sqrt(max(1 - (e / 0.075) ** 2, 0.0)) if e > 0 else 1.0
        k = max(k, 0.03)
        cy, cz = sq(t, 3.2)
        g = 1.0 - 0.07 * math.exp(-((((x + L / 2) % 0.18) - 0.09) / 0.007) ** 2) * (abs(x) < 0.4)
        return (x, (w / 2) * k * cy * g, th / 2 + (th / 2) * k * cz * (g if abs(cz) > 0.5 else 1))
    P.grid_uv(fn, 32, 80, "FoamSolas", 2, 4, closed_u=True)
    # heat-welded seam beads along both side edges
    for sy in (-1, 1):
        ribbon(P, [(x, sy * (w / 2 + 0.0008) * (math.sqrt(max(1 - ((abs(x) - (L / 2 - 0.075)) / 0.075) ** 2, 0)) if abs(x) > L / 2 - 0.075 else 1), th / 2)
                   for x in np.linspace(-L / 2 + 0.01, L / 2 - 0.01, 60)], 0.012, "FoamSeam", up=(0, sy, 0), lift=0.0)
    # sewn webbing loops through each end
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.03)
        pts = [(x - sx * 0.05, 0.0, th + 0.0015), (x, 0.0, th + 0.002), (x + sx * 0.04, 0.0, th / 2 + 0.035), (x + sx * 0.06, 0.0, th / 2),
               (x + sx * 0.04, 0.0, th / 2 - 0.035), (x, 0.0, -0.002), (x - sx * 0.05, 0.0, -0.0015)]
        ribbon(P, pts, 0.025, "Webbing", up=lambda p, sx=sx: (sx * (p[0] - x + sx * 0.0) * 0 + sx * 0.3, 0, (p[2] - th / 2)), lift=0.0, both=True)
    # stainless ring in the +X loop, snap hook on a short tab off the -X loop, leash to the shoulder strap
    d_ring(H, (L / 2 + 0.035, 0.0, th / 2), (0, 1, 0), R=0.018, r=0.0038)
    ribbon(P, [(-L / 2 - 0.03, 0.0, th / 2), (-L / 2 - 0.07, -0.01, th / 2 - 0.02), (-L / 2 - 0.10, -0.02, 0.01)], 0.025, "Webbing", up=(0, 0, 1),
           lift=0.0, both=True)
    snap_hook(H, (-L / 2 - 0.10, -0.02, 0.01), axis=(-1, -0.25, 0), L=0.085)
    lp = [(-L / 2 - 0.03, 0.03, th / 2 - 0.02), (-L / 2 - 0.08, 0.10, 0.006)]
    for j in range(1, 25):
        a = math.pi / 2 + 2 * math.pi * j / 24
        lp.append((-L / 2 + 0.05 + 0.13 * math.cos(a) * 1.2, 0.24 + 0.10 * math.sin(a), 0.004 + 0.002 * (j > 12)))
    lp += [(-0.1, 0.30, 0.006), (0.15, 0.30, 0.006)]
    ribbon(P, lp, 0.022, "Webbing", up=(0, 0, 1), lift=0.0, both=True)
    # shoulder strap: wide padded loop with a ladder-lock where the leash joins
    sc = Vector((0.36, 0.30, 0.0))
    sl = [tuple(sc + Vector((0.20 * math.cos(2 * math.pi * j / 32), 0.075 * math.sin(2 * math.pi * j / 32), 0.006 + 0.002 * math.sin(4 * math.pi * j / 32))))
          for j in range(33)]
    ribbon(P, sl, 0.05, "NavyNylon", up=(0, 0, 1), lift=0.0, both=True)
    ribbon(P, [(0.12, 0.30, 0.0105), (0.20, 0.27, 0.0105)], 0.05, "SeamNavy", up=(0, 0, 1), lift=0.0)
    ladder_lock(H, (0.15, 0.30, 0.012), (1, 0, 0), (0, 0, 1), w=0.032)
    atts = [("ATT_Grip", (0.0, 0.0, th / 2)), ("ATT_Clip", (-L / 2 - 0.185, -0.04, 0.01)), ("ATT_Ring", (L / 2 + 0.035, 0.0, th / 2)),
            ("ATT_Leash", (0.36 + 0.20, 0.30, 0.01)), ("ATT_Throw", (0.0, 0.0, th / 2))]
    return [("Tube", "Cloth", P), ("Hardware", "Hard", H)], atts


# ================================================================ lifebuoy 0.75 m with clips, light and line
def lifebuoy():
    R, Lb, Ln = HP("Ring"), HP("Light"), HP("Lens")
    R.smooth = 70.0
    Rc, rt, sr = 0.30, 0.075, 0.90
    zc = rt * sr
    R.torus_uv(Rc, rt, 96, 18, "RingFit", M=frame(0, 0, zc), sr=sr)
    ro = Rc + rt
    # grab line: through 4 moulded clips at the outer equator, festoons sagging onto the deck between them
    pts = []
    N = 160
    for k in range(N):
        th = 2 * math.pi * k / N
        c = abs(math.sin(2 * th))                       # 0 at the clips (0, 90, 180, 270 deg), 1 midway
        rr = ro + 0.009 + 0.075 * c ** 1.3
        z = zc - (zc - 0.0062) * min(1.0, c * 1.6) ** 0.8
        pts.append((rr * math.cos(th), rr * math.sin(th), z))
    R.tube2(pts, 0.0062, 8, "RopeGrab", closed=True, k=2)
    for k in range(4):
        th = math.pi / 2 * k
        ca, sa = math.cos(th), math.sin(th)
        t = Vector((-sa, ca, 0))

        def band(u, v, ca=ca, sa=sa, t=t):
            ph = 2 * math.pi * u
            rad = Rc + (rt + 0.0035) * math.cos(ph)
            p = Vector((rad * ca, rad * sa, zc + (rt * sr + 0.0035) * math.sin(ph)))
            return tuple(p + t * (v - 0.5) * 0.032)
        R.grid_uv(band, 24, 2, "ClipWhite", 1, 1, closed_u=True)
        # bridge over the rope at the outer equator
        Mb = Matrix.Translation(((ro + 0.009) * ca, (ro + 0.009) * sa, zc)) @ Matrix.Rotation(th, 4, 'Z') @ Matrix.Rotation(math.pi / 2, 4, 'Y')
        R.torus_uv(0.0105, 0.0035, 16, 6, "ClipWhite", M=Mb, sr=1.0)
    # self-igniting buoy light lying beside the ring, its lanyard tied neatly to the grab line
    lx, ly = ro + 0.12, -0.20
    Ml = frame(lx, ly, 0.036, yaw=-70, pitch=-90)
    prof = [(0.0, 0.0), (0.030, 0.0), (0.036, 0.008)]
    for j in range(6):
        z = 0.02 + j * 0.022
        prof += [(0.036, z), (0.0385, z + 0.005), (0.0385, z + 0.013), (0.036, z + 0.018)]
    prof += [(0.036, 0.16), (0.031, 0.168), (0.026, 0.172)]
    Lb.lathe_uv(prof, 16, "SolasABS", M=Ml)
    Lb.lathe_uv([(0.026, 0.172), (0.027, 0.178), (0.024, 0.18)], 20, "BlackABS", M=Ml)
    Lb.torus_uv(0.012, 0.0032, 14, 6, "BlackABS", M=Ml @ frame(0, 0, -0.009, pitch=90))
    for k in range(3):
        a = 2 * math.pi * k / 3
        Lb.lathe_uv([(0.0, 0.0), (0.0032, 0.0), (0.003, 0.0012), (0.0, 0.0016)], 10, "ScrewHead",
                    M=Ml @ frame(0.033 * math.cos(a), 0.033 * math.sin(a), 0.0, pitch=180))
    Ln.lathe_uv([(0.024, 0.18), (0.024, 0.205), (0.019, 0.222), (0.010, 0.229), (0.0, 0.230)], 20, "LensStrobe", M=Ml)
    p_lens = Ml @ Vector((0, 0, 0.21))
    eye = Ml @ Vector((0, 0, -0.015))
    tie_th = -0.30
    tie = ((ro + 0.009 + 0.075 * abs(math.sin(2 * tie_th)) ** 1.3) * math.cos(tie_th),
           (ro + 0.009 + 0.075 * abs(math.sin(2 * tie_th)) ** 1.3) * math.sin(tie_th), 0.012)
    R.tube2([tuple(eye), (eye.x - 0.04, eye.y + 0.03, 0.005), ((eye.x + tie[0]) / 2, (eye.y + tie[1]) / 2 + 0.02, 0.0045), tie],
            0.0035, 6, "RopeOrange", caps=True, k=2)
    R.torus_uv(0.009, 0.0035, 10, 6, "RopeOrange", M=frame(tie[0], tie[1], tie[2] + 0.002, yaw=math.degrees(tie_th), pitch=90))
    # heaving line bent onto the grab line at 180 deg with a bowline, led off neatly
    bx = -(ro + 0.009)
    R.torus_uv(0.016, 0.005, 14, 6, "RopeThrow", M=frame(bx - 0.006, 0.0, zc - 0.004, yaw=90, pitch=90))
    R.torus_uv(0.010, 0.005, 12, 6, "RopeThrow", M=frame(bx - 0.03, 0.004, 0.012, pitch=20))
    hl = [(bx - 0.02, 0.0, 0.03), (bx - 0.04, 0.006, 0.012), (bx - 0.10, 0.02, 0.005), (bx - 0.25, 0.05, 0.005), (bx - 0.42, 0.04, 0.005)]
    R.tube2(hl, 0.005, 8, "RopeThrow", caps=True, k=2)
    atts = [("ATT_Grip", (ro + 0.05, 0.0, zc)), ("ATT_Throw", (0.0, 0.0, zc)), ("ATT_Light", tuple(p_lens)),
            ("ATT_Lens", tuple(p_lens)), ("ATT_LineEnd", hl[-1])]
    return [("Ring", "Soft", R), ("Light", "Hard", Lb), ("Lens", "Hard", Ln)], atts


# ================================================================ thermal blankets (metallised PET foil)
def _crumple(x, y, seed, amp):
    return amp * (math.sin(61 * x + 3.1 * seed) * math.sin(53 * y + seed) + 0.6 * math.sin(127 * x - 97 * y + seed)
                  + 0.4 * math.sin(211 * x + 173 * y + 2 * seed) + 0.3 * math.sin(331 * x - 289 * y + 5 * seed))


def blanket_folded():
    """Folded foil blanket out of its sleeve: accordion layers (gold out on top, silver under), crumpled fold edges."""
    P = HP("Folded")
    a, b = 0.075, 0.05
    layers, th = 8, 0.0055
    reg = lambda k, gold: ("FoilGold" if gold else "FoilSilver") + ("A" if k % 2 else "B")

    def top(u, v):
        x, y = -a + 2 * a * u, -b + 2 * b * v
        e = min(1.0, (1 - abs(2 * u - 1)) * 8, (1 - abs(2 * v - 1)) * 8)
        crease = 0.0018 * math.exp(-((x - 0.03) / 0.004) ** 2) - 0.0012 * math.exp(-((y + 0.035) / 0.004) ** 2)
        return (x, y, layers * th + e * (0.0015 + _crumple(x, y, 3, 0.0011) + crease))
    P.grid_uv(top, 40, 28, "FoilSilverA", 1, 1)
    P.grid_uv(lambda u, v: (-a + 2 * a * (1 - u), -b + 2 * b * v, _crumple(u, v, 9, 0.0006)), 12, 8, "FoilGoldA", 1, 1)
    # accordion folds along the X ends: half-round bends alternating sides, each layer pair joined
    for k in range(layers):
        sx = 1 if k % 2 else -1
        zc = (k + 0.5) * th

        def fold(u, v, k=k, sx=sx, zc=zc):
            ph = math.pi * (u - 0.5)
            y = -b + 2 * b * v
            rr = th * 0.5 * (1 + 0.25 * math.sin(40 * y + k))
            return (sx * (a + rr * math.cos(ph) + _crumple(y, k, k, 0.0008)), y, zc + rr * math.sin(ph) * sx)
        f0 = len(P.f)
        P.grid_uv(fold, 6, 24, reg(k, k % 2 == 0), 1, 1)
        if sx < 0:
            flip(P, f0)
        # open layer edges on the opposite X side and both Y ends (cut edges stacked)
    for sy in (-1, 1):
        def end(u, v, sy=sy):
            x = -a + 2 * a * u
            return (x, sy * (b + 0.0008 + _crumple(x, v, 4 + sy, 0.0006)), layers * th * v)
        f0 = len(P.f)
        P.grid_uv(end, 24, layers, "FoilSilverB", 1, 1)
        if sy > 0:
            flip(P, f0)
    atts = [("ATT_Grip", (0.0, 0.0, layers * th))]
    return [("Folded", "Foil", P)], atts


BODY = [  # supine casualty proxy (1.75 m, head at +Y): ellipsoids (cx, cy, rx, ry, rz)
    (0, 0.38, 0.21, 0.24, 0.22), (0, 0.10, 0.19, 0.20, 0.20), (0, -0.15, 0.20, 0.16, 0.19),
    (-0.09, -0.55, 0.085, 0.36, 0.13), (0.09, -0.55, 0.085, 0.36, 0.13), (-0.10, -0.95, 0.06, 0.10, 0.18), (0.10, -0.95, 0.06, 0.10, 0.18),
    (-0.27, 0.20, 0.06, 0.30, 0.11), (0.27, 0.20, 0.06, 0.30, 0.11), (-0.26, -0.15, 0.06, 0.08, 0.10), (0.26, -0.15, 0.06, 0.08, 0.10),
    (0, 0.66, 0.09, 0.11, 0.13), (0, 0.80, 0.10, 0.12, 0.12)]


def cloth_drape(W, L, d, y_top, z0, frames=70):
    """Blender cloth sim of a W x L sheet (grid d) dropped over the supine body proxy onto the deck; returns the baked
    vertex positions (row-major, (nx+1) x (ny+1)) and the grid size."""
    import bmesh
    scene = bpy.context.scene
    nx, ny = int(round(W / d)), int(round(L / d))
    rng = random.Random(5)
    ph = [rng.uniform(0, 6.28) for _ in range(6)]
    verts = [(-W / 2 + i * d, y_top - L + j * d,
              z0 + 0.035 * math.sin(2 * math.pi * (i * d) / 0.31 + ph[0]) * math.sin(2 * math.pi * (j * d) / 0.47 + ph[1])
              + 0.02 * math.sin(2 * math.pi * (i * d + 0.6 * j * d) / 0.19 + ph[2]) + 0.004 * rng.random())
             for j in range(ny + 1) for i in range(nx + 1)]
    faces = [(j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i) for j in range(ny) for i in range(nx)]
    tmp = []
    me = bpy.data.meshes.new("E1_ClothSim")
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new("E1_ClothSim", me)
    scene.collection.objects.link(ob)
    tmp.append(ob)
    for k, e in enumerate(BODY + [None]):
        bm = bmesh.new()
        if e is None:
            bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=3.0)
        else:
            cx, cy, rx, ry, rz = e
            bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
            for v in bm.verts:
                v.co = Vector((cx + v.co.x * rx, cy + v.co.y * ry, max(v.co.z * rz, -0.01)))
        m2 = bpy.data.meshes.new("E1_Col%d" % k)
        bm.to_mesh(m2)
        bm.free()
        o2 = bpy.data.objects.new("E1_Col%d" % k, m2)
        scene.collection.objects.link(o2)
        o2.modifiers.new("Collision", 'COLLISION')
        o2.collision.thickness_outer = 0.006
        o2.collision.cloth_friction = 12.0
        tmp.append(o2)
    cl = ob.modifiers.new("Cloth", 'CLOTH')
    s = cl.settings
    s.quality = 7
    s.mass = 0.08
    s.air_damping = 1.5
    s.tension_stiffness = s.compression_stiffness = 25.0
    s.shear_stiffness = 6.0
    s.bending_stiffness = 0.005
    cs = cl.collision_settings
    cs.distance_min = 0.004
    cs.use_self_collision = False
    cl.point_cache.frame_start = 1
    cl.point_cache.frame_end = frames
    scene.frame_start, scene.frame_end = 1, frames
    for f in range(1, frames + 1):
        scene.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    pos = [ev.matrix_world @ v.co for v in ev.data.vertices]
    scene.frame_set(1)
    for o in tmp:
        m_ = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.meshes.remove(m_)
    return [Vector(p) for p in pos], nx, ny


def blanket_draped():
    """2.1 x 1.32 m foil blanket over a supine casualty: baked Blender cloth sim, gold layer up, silver under."""
    P = HP("Draped")
    W, Lb, d = 1.302, 2.10, 0.042
    y_top = 0.92
    pos, nx, ny = cloth_drape(W, Lb, d, y_top, 0.36)
    # foil crinkle in the silhouette: small high-frequency offsets along the vertex normal (mm)
    rng = random.Random(3)
    tile = int(round(atlas.TF / d))   # 11 cells = 0.462 m per foil tile
    cols = nx + 1
    vn = [Vector((0, 0, 0)) for _ in pos]
    quads = [(j * cols + i, j * cols + i + 1, (j + 1) * cols + i + 1, (j + 1) * cols + i) for j in range(ny) for i in range(nx)]
    for q in quads:
        a_, b_, c_ = pos[q[0]], pos[q[1]], pos[q[2]]
        nn = (b_ - a_).cross(c_ - a_)
        for i in q:
            vn[i] += nn
    vn = [v.normalized() if v.length > 1e-12 else Vector((0, 0, 1)) for v in vn]
    if sum(v.z for v in vn) < 0:
        vn = [-v for v in vn]
        quads = [tuple(reversed(q)) for q in quads]
    pos = [p + n * (0.0016 * (rng.random() - 0.5)) for p, n in zip(pos, vn)]
    pos = [Vector((p.x, p.y, max(p.z, 0.003))) for p in pos]
    under = [p - n * 0.0012 for p, n in zip(pos, vn)]
    for layer, verts, gold in ((0, pos, True), (1, under, False)):
        faces, uvs, regs = [], [], []
        for idx, q in enumerate(quads):
            j, i = divmod(idx, nx)
            ti, tj = i // tile, j // tile
            reg = ("FoilGold" if gold else "FoilSilver") + ("A" if (ti + tj) % 2 == 0 else "B")
            u0, v0, u1, v1 = atlas.rect(reg)
            loc = []
            for vid in q:
                jj, ii = divmod(vid, cols)
                fu = (ii - ti * tile) / tile
                fv = (jj - tj * tile) / tile
                loc.append((u0 + (u1 - u0) * fu, v0 + (v1 - v0) * fv))
            faces.append(q if gold else tuple(reversed(q)))
            uvs.append(loc if gold else list(reversed(loc)))
            regs.append(reg)
        b0 = len(P.v)
        P.v.extend(Vector(v) for v in verts)
        for f, uv, rg in zip(faces, uvs, regs):
            P.f.append(([b0 + i for i in f], rg, ("uv", uv)))
    atts = [("ATT_Head", (0.0, 0.70, 0.12)), ("ATT_Casualty", (0.0, 0.0, 0.0)), ("ATT_Grip", (W / 2 - 0.05, 0.0, 0.02))]
    return [("Draped", "Foil", P)], atts


# ================================================================ crew bags (hi-vis yellow over navy)
def _bag(P, Hd, a, b, h, seed, patch, front_free=True):
    n = 5.0
    zb = 0.07
    base = Wall(a, b, 0.0, zb, n=n, bulge=0.0, wob=0.0015, seed=seed)
    body = Wall(a, b, zb, h, n=n, bulge=0.035, wob=0.004, seed=seed + 1)
    base.build(P, "NavyNylon", nu=72, nv=2)
    body.build(P, "HiVisNylon", nu=84, nv=10)
    cap(P, "HiVisNylon", a, b, h, n=n, dome=0.022, res=18, wob=0.004, seed=seed + 2)
    cap(P, "NavyNylon", a, b, 0.0, n=n, res=12, top=False)
    # piping on the lid seam, the base seam and the bottom edge
    for z, Wl in ((h, body), (zb, base), (0.004, base)):
        P.tube2(Wl.ring(z, 84, 0.001), 0.0048, 5, "CordBlack", closed=False, k=1)
    # stitched corner seams and the sewn retro band
    for s in (0.125, 0.375, 0.625, 0.875):
        ribbon(P, [body.pt(s, z, 0.0012) for z in np.linspace(zb + 0.004, h - 0.004, 14)], 0.016, "SeamHiVis",
               up=lambda p: (p[0] / a ** 2, p[1] / b ** 2, 0))
    zr = zb + (h - zb) * 0.55
    ribbon(P, [body.pt(i / 84, zr, 0.0018) for i in range(85)], 0.05, "RetroSewn", up=lambda p: (p[0] / a ** 2, p[1] / b ** 2, 0))
    # lid zip round three sides (U), two sliders with pulls
    ins = 0.84
    zl = h + 0.004
    zp = [(-a * ins, b * 0.6, zl + 0.004), (-a * ins, -b * 0.55, zl + 0.008), (-a * ins * 0.85, -b * 0.72, zl + 0.012),
          (a * ins * 0.85, -b * 0.72, zl + 0.012), (a * ins, -b * 0.55, zl + 0.008), (a * ins, b * 0.6, zl + 0.004)]
    ribbon(P, zp, 0.014, "ZipBlack", up=(0, 0, 1), lift=0.010)
    for x in (a * 0.5, a * 0.62):
        zip_slider(Hd, (x, -b * 0.72, zl + 0.026), (-1, 0, 0) if x < a * 0.55 else (1, 0, 0), (0, 0, 1))
    # carry handles over the lid with a navy grip wrap
    for yh in (-b * 0.16, b * 0.16):
        pts = [(-a * 0.36 + a * 0.72 * i / 16, yh, h + 0.03 + 0.10 * math.sin(math.pi * i / 16)) for i in range(17)]
        ribbon(P, pts, 0.025, "Webbing", up=(0, -1 if yh < 0 else 1, 0), lift=0.0, both=True)
        for x in (-a * 0.36, a * 0.36):
            ribbon(P, [(x - 0.03, yh, h + 0.028), (x + 0.03, yh, h + 0.028)], 0.028, "Webbing", up=(0, 0, 1), lift=0.0)
    P.lathe_uv([(0.0, 0.0), (0.016, 0.0), (0.018, 0.006), (0.018, 0.11), (0.016, 0.116), (0.0, 0.116)], 16, "NavyNylon",
               M=frame(-0.058, 0.0, h + 0.128, roll=90))
    # D rings on webbing tabs at the ends, shoulder strap draped behind with a ladder lock and a pad
    tabs = []
    for sx in (-1, 1):
        s = 0.0 if sx > 0 else 0.5
        p = body.pt(s, h - 0.035, 0.002)
        ribbon(P, [body.pt(s, h - 0.07, 0.0018), body.pt(s, h - 0.01, 0.0018)], 0.025, "Webbing", up=(sx, 0, 0), lift=0.0)
        rp = (p[0] + sx * 0.012, p[1], h - 0.01)
        d_ring(Hd, rp, (0, 1, 0), R=0.013, r=0.003)
        tabs.append(rp)
    sp = [tabs[0], (tabs[0][0] - 0.03, 0.03, h - 0.05), (tabs[0][0] - 0.02, b + 0.06, 0.12), (-a * 0.6, b + 0.14, 0.006),
          (0.0, b + 0.18, 0.006), (a * 0.6, b + 0.14, 0.006), (tabs[1][0] + 0.02, b + 0.06, 0.12), (tabs[1][0] + 0.03, 0.03, h - 0.05), tabs[1]]
    Q = ribbon(P, sp, 0.025, "Webbing", up=lambda p: (0, 0.3, 1) if p[2] < 0.02 else (p[0] * 2, 1, 0.3), lift=0.0, both=True, nseg=60)
    ribbon(P, [(-0.12, b + 0.165, 0.011), (0.12, b + 0.165, 0.011)], 0.055, "NavyNylon", up=(0, 0, 1), lift=0.0, both=True)
    ladder_lock(Hd, (-a * 0.62, b + 0.14, 0.012), (1, 0.3, 0), (0, 0, 1), w=0.03)
    # front compression straps with side-release buckles
    for s in ((0.70, 0.80) if front_free else ()):
        zz = list(np.linspace(zb + 0.01, h - 0.005, 12))
        ribbon(P, [body.pt(s, z, 0.0035) for z in zz], 0.02, "Webbing", up=lambda p: (p[0] / a ** 2, p[1] / b ** 2, 0), lift=0.0)
        pb = Vector(body.pt(s, zb + (h - zb) * 0.3, 0.0085))
        side_release(Hd, tuple(pb), (0, 0, 1), body.nrm(s), w=0.026, L=0.05)
    # front patch on the wall surface
    pw, ph_ = patch[1], patch[2]
    s0, s1 = 0.75 - pw / 2 / body.L, 0.75 + pw / 2 / body.L
    zc_ = zr + 0.025 + 0.006
    wall_decal(P, body, patch[0], s0, s1, zc_, zc_ + ph_, lift=0.0032, nu=10, nv=6)
    return body, zr


def first_aid_bag():
    P, Hd = HP("Bag"), HP("Hardware")
    a, b, h = 0.25, 0.15, 0.29
    _bag(P, Hd, a, b, h, 21, ("CrossPatch", 0.10, 0.10))
    atts = [("ATT_Grip", (0.0, 0.0, h + 0.13)), ("ATT_Open", (a * 0.5, -b * 0.72, h + 0.03)), ("ATT_Strap_L", (-a - 0.012, 0, h - 0.01)),
            ("ATT_Strap_R", (a + 0.012, 0, h - 0.01))]
    return [("Bag", "Cloth", P), ("Hardware", "Hard", Hd)], atts


def oxygen_bag():
    P, Hd = HP("Bag"), HP("Hardware")
    a, b, h = 0.26, 0.11, 0.26
    body, zr = _bag(P, Hd, a, b, h, 31, ("OxyPatch", 0.17, 0.085), front_free=False)
    # CD-size cylinder strapped along the front (white, label band, valve and grey guard)
    C = HP("Cylinder")
    rc = 0.05
    cy, cz = -b * 1.04 - rc - 0.006, rc
    Mc = frame(-0.27, cy, cz, roll=90)
    C.lathe_uv([(0.0, 0.0), (0.035, 0.0), (rc - 0.004, 0.004), (rc, 0.012), (rc, 0.10)], 24, "CylWhite", M=Mc)
    C.lathe_uv([(rc, 0.10), (rc + 0.0005, 0.30)], 28, "CylLabel", M=Mc)
    C.lathe_uv([(rc, 0.30), (rc, 0.40), (rc - 0.008, 0.425), (0.022, 0.445), (0.014, 0.45)], 24, "CylWhite", M=Mc)
    C.lathe_uv([(0.014, 0.45), (0.016, 0.47), (0.013, 0.50), (0.0, 0.505)], 14, "Brass", M=Mc)
    C.lathe_uv([(0.0, 0.0), (0.044, 0.0), (0.046, 0.02), (0.044, 0.085), (0.034, 0.10), (0.0, 0.102)], 20, "GreyABS", M=Mc @ frame(0, 0, 0.44))
    C.lathe_uv([(0.0, 0.0), (0.016, 0.0), (0.016, 0.008), (0.0, 0.009)], 16, "BlackABS", M=Mc @ frame(0.0, -0.046, 0.50, pitch=90))
    C.lathe_uv([(0.0, 0.0), (0.012, 0.0), (0.012, 0.002), (0.0, 0.0022)], 16, "LensClear", M=Mc @ frame(0.0, -0.0545, 0.50, pitch=90))
    C.lathe_uv([(0.0, 0.0), (0.006, 0.0), (0.005, 0.03), (0.0, 0.032)], 10, "Brass", M=Mc @ frame(0.046, 0.0, 0.48, roll=90))
    for x in (-0.15, 0.08):
        sp = [(x, -b * 1.02, cz + rc * 1.4)] + [(x, cy + (rc + 0.003) * math.sin(t), cz + (rc + 0.003) * math.cos(t))
                                               for t in np.linspace(-0.4, math.pi + 0.3, 14)] + [(x, -b * 1.02, 0.004)]
        ribbon(P, sp, 0.025, "Webbing", up=lambda p: (0, p[1] - cy, p[2] - cz) if p[1] < -b * 1.05 else (0, -1, 0), lift=0.0, both=True)
        side_release(Hd, (x, cy - 0.003, cz + rc + 0.012), (0, 1, 0), (0, 0, 1), w=0.03, L=0.05)
    # non-rebreather mask and reservoir bag on the lid, green tubing to the outlet
    Mk = HP("Mask")
    Mm = frame(0.12, 0.0, h + 0.035, pitch=-80)

    def shell(u, v):
        t = 2 * math.pi * u
        x, y = math.cos(t) * 0.055, math.sin(t) * 0.065
        return tuple(Mm @ Vector((x * math.sqrt(max(1 - v * v, 0.0)), y * math.sqrt(max(1 - v * v, 0.0)), 0.045 * v)))
    Mk.grid_uv(shell, 20, 6, "MaskPVC", 1, 1, closed_u=True)
    Mk.torus_uv(0.06, 0.004, 20, 4, "MaskPVC", M=Mm, sr=1.0)

    def res(u, v):
        t = 2 * math.pi * u
        s = math.sin(math.pi * v)
        return (-0.10 + 0.09 * math.cos(t) * s * (1 + 0.08 * math.sin(3 * t)), 0.0 + 0.06 * math.sin(t) * s, h + 0.03 + 0.018 * (1 - math.cos(math.pi * v)) + 0.025 * s)
    Mk.grid_uv(res, 16, 8, "MaskPVC", 1, 1, closed_u=True)
    ribbon(Mk, [tuple(Mm @ Vector((0.06 * math.cos(t), 0.065 * math.sin(t), 0.004))) for t in np.linspace(0.3, 2 * math.pi - 0.3, 20)], 0.008, "WebbingS",
           up=lambda p: (0, 0, 1), lift=0.0, both=True)
    out = Mc @ frame(0.046, 0.0, 0.48, roll=90) @ Vector((0, 0, 0.03))
    tp = [tuple(Mm @ Vector((0, 0.05, 0.02))), (0.02, 0.12, h + 0.04), (0.2, 0.10, h + 0.03), (0.30, 0.0, h - 0.02),
          (0.32, -0.10, h * 0.6), (out.x + 0.04, out.y + 0.02, out.z + 0.03), tuple(out)]
    Mk.tube2(tp, 0.0035, 6, "TubeGreen", caps=True, k=3)
    atts = [("ATT_Grip", (0.0, 0.0, h + 0.13)), ("ATT_Mask", tuple(Mm @ Vector((0, 0, 0.02)))), ("ATT_Valve", tuple(out)),
            ("ATT_Cylinder", (0.0, cy, cz)), ("ATT_Open", (a * 0.5, -b * 0.72, h + 0.03))]
    return [("Bag", "Cloth", P), ("Hardware", "Hard", Hd), ("Cylinder", "Hard", C), ("Mask", "Hard", Mk)], atts


# ================================================================ handheld VHF (unchanged from E1)
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
def _ribbed(r, z0, z1, n, depth, rr=None):
    out = []
    step = (z1 - z0) / n
    for k in range(n):
        z = z0 + step * k
        out += [(r, z), (r + depth, z + step * 0.25), (r + depth, z + step * 0.6), (r, z + step * 0.85)]
    return out


def _parting(P, r, z0, z1, region, w=0.0012):
    """Two moulding parting lines (thin ridges) down opposite sides."""
    for sx in (-1, 1):
        rod(P, (sx * (r + 0.0002), 0.0, z0), (sx * (r + 0.0002), 0.0, z1), w, region, 5)


def hand_flare():
    P, Ln = HP("Body"), HP("Lens")
    r = 0.019
    # bottom: knurled striker end cap with seam step, tear tab and pull ring
    P.lathe_uv([(0.0, 0.0), (0.0175, 0.0), (0.0205, 0.003), (0.0205, 0.024), (0.0195, 0.026)], 24, "Knurl")
    P.lathe_uv([(0.0195, 0.026), (0.0172, 0.027), (0.0172, 0.03)], 20, "BlackABS")
    rod(P, (0.0, -0.0205, 0.012), (0.0, -0.028, 0.004), 0.0028, "WhiteABS", 6)
    P.torus_uv(0.009, 0.0018, 14, 5, "Stainless", M=frame(0.0, 0.0, -0.004, pitch=90))
    rod(P, (0.0, 0.0, 0.0), (0.0, 0.0, -0.004), 0.0018, "Stainless", 6)
    # ribbed handle with parting lines and a crimped ferrule (two rivets) at the tube joint
    grip = [(0.0172, 0.03)] + _ribbed(0.0172, 0.032, 0.10, 6, 0.0012) + [(0.0175, 0.10), (0.0185, 0.104)]
    P.lathe_uv(grip, 24, "BlackABS")
    _parting(P, 0.0182, 0.032, 0.10, "BlackABS", 0.0008)
    P.lathe_uv([(0.0185, 0.104), (0.0198, 0.105), (0.0198, 0.108), (0.0193, 0.109), (0.0198, 0.110), (0.0198, 0.113), (r, 0.114)], 24, "Stainless")
    for sx in (-1, 1):
        P.lathe_uv([(0.0, 0.0), (0.0018, 0.0), (0.0016, 0.0008), (0.0, 0.0011)], 8, "ScrewHead", M=frame(sx * 0.0198, 0.0, 0.1085, roll=90 * sx))
    # labelled tube, red shoulder, red composition head (Lens)
    P.lathe_uv([(r, 0.114), (r, 0.225)], 32, "HandLabel")
    P.lathe_uv([(r, 0.225), (r + 0.0012, 0.228), (r + 0.0012, 0.232), (r - 0.001, 0.235)], 24, "FlareRed")
    _parting(P, r + 0.0003, 0.114, 0.225, "FlareRed", 0.0005)
    Ln.lathe_uv([(r - 0.001, 0.235), (0.0175, 0.243), (0.014, 0.25), (0.008, 0.2535), (0.0, 0.254)], 20, "LensRed")
    atts = [("ATT_Grip", (0.0, 0.0, 0.065)), ("ATT_Lens", (0.0, 0.0, 0.25)), ("ATT_Flame", (0.0, 0.0, 0.26)), ("ATT_Striker", (0.0, 0.0, -0.01))]
    return [("Body", "Hard", P), ("Lens", "Hard", Ln)], atts


def para_flare():
    P, Ln = HP("Body"), HP("Lens")
    r = 0.022
    # knurled bottom cap with seam ring
    P.lathe_uv([(0.0, 0.0), (0.020, 0.0), (r + 0.0025, 0.003), (r + 0.0025, 0.03), (r + 0.001, 0.032)], 28, "Knurl")
    P.lathe_uv([(r + 0.001, 0.032), (r, 0.033), (r, 0.036)], 24, "BlackABS")
    P.lathe_uv([(r, 0.036), (r, 0.316)], 32, "ParaLabel")
    _parting(P, r + 0.0002, 0.036, 0.316, "FlareRed", 0.0005)
    P.lathe_uv([(r, 0.316), (r, 0.319), (r + 0.001, 0.32)], 24, "BlackABS")
    # top cap: knurled, tear tab
    P.lathe_uv([(r + 0.001, 0.32), (r + 0.0025, 0.322), (r + 0.0025, 0.338), (r + 0.001, 0.341), (r - 0.002, 0.342)], 28, "Knurl")
    rod(P, (0.0, -(r + 0.0025), 0.338), (0.0, -(r + 0.009), 0.344), 0.0025, "WhiteABS", 6)
    Ln.lathe_uv([(r - 0.002, 0.342), (0.018, 0.346), (0.0, 0.348)], 20, "LensRed")
    # firing lever folded along the body on a riveted pivot, safety pin with ring through the lever
    P.lathe_uv([(0.0, 0.0), (0.006, 0.0), (0.006, 0.006), (0.0, 0.0065)], 12, "BlackABS", M=frame(r, 0.0, 0.11, roll=90))
    P.lathe_uv([(0.0, 0.0), (0.0035, 0.0), (0.003, 0.0015), (0.0, 0.002)], 10, "ScrewHead", M=frame(r + 0.006, 0.0, 0.11, roll=90))
    rod(P, (r + 0.005, 0.0, 0.105), (r + 0.007, 0.0, 0.04), 0.0042, "BlackABS", 8, r1=0.0048)
    for z in (0.05, 0.065, 0.08):
        rod(P, (r + 0.0105, -0.003, z), (r + 0.0105, 0.003, z), 0.0011, "BlackABS", 5)
    rod(P, (r - 0.004, 0.0, 0.045), (r + 0.016, 0.0, 0.045), 0.0013, "Stainless", 6)
    P.torus_uv(0.010, 0.0016, 14, 5, "Stainless", M=frame(r + 0.026, 0.0, 0.045, pitch=90))
    atts = [("ATT_Grip", (0.0, 0.0, 0.08)), ("ATT_Lens", (0.0, 0.0, 0.345)), ("ATT_Launch", (0.0, 0.0, 0.36)),
            ("ATT_Trigger", (r + 0.007, 0.0, 0.07)), ("ATT_Pin", (r + 0.026, 0.0, 0.045))]
    return [("Body", "Hard", P), ("Lens", "Hard", Ln)], atts


def strobe():
    """Lifejacket rescue strobe: tapered moulded body (two shells, parting band), front label and TEST button, side
    slide switch, screwed back plate with a sprung clip on a pivot pin, dome lens over a reflector and xenon tube."""
    P, Ln = HP("Body"), HP("Lens")
    a, b, h = 0.023, 0.0155, 0.072
    for k in range(4):
        z0, z1 = h * k / 4, h * (k + 1) / 4
        kk = 1.0 - 0.06 * (k / 4)
        Wl = Wall(a * kk, b * kk, z0, z1, n=4.5)
        Wl.build(P, "SolasABS", nu=32, nv=1)
    cap(P, "SolasABS", a, b, 0.0, n=4.5, res=6, top=False)
    cap(P, "SolasABS", a * 0.94, b * 0.94, h, n=4.5, res=6, dome=0.002)
    band = Wall(a * 0.975 + 0.0006, b * 0.975 + 0.0006, h * 0.40, h * 0.40 + 0.002, n=4.5)
    band.build(P, "BlackABS", nu=32, nv=1)
    # lens collar, reflector cup and xenon tube under the dome (Body), the dome itself (Lens)
    P.lathe_uv([(0.0175, 0.0), (0.0178, 0.003), (0.0168, 0.0055)], 24, "BlackABS", M=frame(0.0, 0.0, h + 0.001))
    P.lathe_uv([(0.0, 0.0), (0.004, 0.0), (0.0145, 0.009), (0.0155, 0.011)], 24, "Stainless", M=frame(0.0, 0.0, h + 0.002))
    rod(P, (-0.007, 0.0, h + 0.012), (0.007, 0.0, h + 0.012), 0.0018, "LensClear", 8)
    for x in (-0.0085, 0.0085):
        rod(P, (x, 0.0, h + 0.004), (x, 0.0, h + 0.012), 0.0007, "Stainless", 5)
    Ln.lathe_uv([(0.0165, 0.0), (0.0165, 0.006), (0.0145, 0.014), (0.010, 0.020), (0.005, 0.0225), (0.0, 0.023)], 24, "LensStrobe",
                M=frame(0.0, 0.0, h + 0.0055))
    # front label and TEST button
    fw = 0.034
    P.grid_uv(lambda u, v: (-fw / 2 + fw * u, -b * 0.985 - 0.0007 - 0.0012 * math.sin(math.pi * u), 0.008 + 0.054 * v), 6, 6, "StrobeLabel", 1, 1)
    P.lathe_uv([(0.0, 0.0), (0.005, 0.0), (0.0048, 0.0012), (0.003, 0.0022), (0.0, 0.0025)], 14, "Rubber", M=frame(0.0, -b - 0.0018, 0.035, pitch=90))
    # side slide switch in a recessed track
    solid_box(P, (0, 0, 0), (0.0015, 0.008, 0.02), "BlackABS", n=4, segs=12, M=frame(a + 0.0002, 0.0, 0.03))
    solid_box(P, (0, 0, 0), (0.003, 0.006, 0.007), "Rubber", n=4, segs=12, M=frame(a + 0.0012, 0.0, 0.041))
    # back plate with two screws, pivot pin, sprung clip tongue
    solid_box(P, (0, 0, 0), (0.034, 0.003, 0.05), "BlackABS", n=6, segs=12, M=frame(0.0, b * 0.98 + 0.001, 0.012))
    for x in (-0.011, 0.011):
        P.lathe_uv([(0.0, 0.0), (0.0024, 0.0), (0.0022, 0.0009), (0.0, 0.0012)], 10, "ScrewHead", M=frame(x, b + 0.0045, 0.018, pitch=-90))
    rod(P, (-0.014, b + 0.006, 0.062), (0.014, b + 0.006, 0.062), 0.0022, "Stainless", 8)
    for x in (-0.013, 0.013):
        solid_box(P, (0, 0, 0), (0.004, 0.006, 0.008), "BlackABS", n=4, segs=12, M=frame(x, b + 0.004, 0.058))
    tongue = [(0.0, b + 0.007, 0.06), (0.0, b + 0.0095, 0.045), (0.0, b + 0.0095, 0.012), (0.0, b + 0.006, 0.004)]
    for p0, p1 in zip(tongue[:-1], tongue[1:]):
        solid_box(P, (0, 0, 0), (0.018, 0.0022, (Vector(p1) - Vector(p0)).length + 0.002), "BlackABS", n=6, segs=12,
                  M=axis_frame(p1, p0)[0])
    atts = [("ATT_Lens", (0.0, 0.0, h + 0.016)), ("ATT_Clip", (0.0, b + 0.0095, h * 0.5)), ("ATT_Grip", (0.0, 0.0, h * 0.5)),
            ("ATT_Switch", (a + 0.002, 0.0, 0.041))]
    return [("Body", "Hard", P), ("Lens", "Hard", Ln)], atts


# ================================================================ registry and spec
# asset: (builder, E1b hero ceiling (docs/12 2.8 row in brackets in the CSV), real class)
KIT = {
    "M_Kit_ThrowBag": (throw_bag, 14000, "Rescue throw bag about 0.35 m x 0.15 m diameter, floating line in the bag (verify)"),
    "M_Kit_ThrowLine": (throw_line, 9000, "15 m of 11 mm floating polypropylene throw line, loosely coiled (verify)"),
    "M_Kit_RescueTube": (rescue_tube, 12000, "Foam lifeguard rescue tube about 1.0 x 0.15 x 0.08 m with clip and 2 m leash (verify)"),
    "M_Kit_Lifebuoy": (lifebuoy, 12000, "SOLAS lifebuoy 0.75 m OD (docs/05) with self-igniting light and retro tape"),
    "M_Kit_ThermalBlanket": (blanket_folded, 8000, "Foil survival blanket 2.1 x 1.3 m, folded pack (verify)"),
    "M_Kit_ThermalBlanketDraped": (blanket_draped, 14000, "Foil survival blanket 2.1 x 1.3 m draped over a supine casualty (verify)"),
    "M_Kit_FirstAidBag": (first_aid_bag, 18000, "Response bag about 0.5 x 0.3 x 0.3 m (verify; RNLI Casualty Care)"),
    "M_Kit_OxygenBag": (oxygen_bag, 20000, "Oxygen bag with CD-size cylinder about 0.55 m and non-rebreather mask (verify)"),
    "M_Kit_VHFHandset": (vhf, 3000, "Handheld marine VHF about 0.13 x 0.06 x 0.04 m body plus antenna (verify)"),
    "M_Kit_HandFlare": (hand_flare, 6000, "Red hand flare about 0.25 m (verify)"),
    "M_Kit_ParaFlare": (para_flare, 6000, "Parachute rocket flare about 0.35 m (verify)"),
    "M_Kit_Strobe": (strobe, 6000, "Lifejacket strobe light about 0.1 m (verify)"),
}


# real class size in the AUTHORED orientation (X width, Y depth, Z up); axes the accessories push past SIZE_NOTED are
# written as '-' to dims.md and left to the class text there
REAL = {"M_Kit_ThrowBag": (0.15, 0.15, 0.35), "M_Kit_ThrowLine": (None, 0.42, None), "M_Kit_RescueTube": (1.0, 0.15, 0.08),
        "M_Kit_Lifebuoy": (0.75, 0.75, 0.12), "M_Kit_ThermalBlanket": (0.15, 0.10, 0.05), "M_Kit_ThermalBlanketDraped": (1.3, 2.1, 0.246),
        "M_Kit_FirstAidBag": (0.5, 0.3, 0.3), "M_Kit_OxygenBag": (0.55, 0.30, 0.26), "M_Kit_VHFHandset": (0.06, 0.04, 0.132),
        "M_Kit_HandFlare": (0.025, 0.025, 0.25), "M_Kit_ParaFlare": (0.032, 0.032, 0.35), "M_Kit_Strobe": (0.05, 0.03, 0.1)}
SIZE_NOTE = ("E1b: the bbox includes the accessories (lines, loops, straps, buckles, light, pins); dims.md dims_m is the class "
             "size in the authored orientation, '-' where accessories set the bbox")


def sync_dims(asset, dims):
    import budgets
    import re
    real = REAL[asset]
    dm = tuple(None if (r is None or abs(d - r) / r > budgets.SIZE_NOTED - 0.005) else r for r, d in zip(real, dims))
    path = os.path.join(G, "art/reference", asset, "dims.md")
    line = "dims_m: " + " x ".join("-" if v is None else "%g" % v for v in dm)
    txt = open(path).read() if os.path.exists(path) else "# %s\n\n" % asset
    if re.search(r"^dims_m:.*$", txt, re.M):
        txt = re.sub(r"^dims_m:.*$", line, txt, count=1, flags=re.M)
    else:
        txt = txt + "\n" + line + "\n"
    if "E1b authored orientation" not in txt:
        txt += ("\nE1b (2026-10-18): dims_m above is in the authored orientation (X width, Y depth, Z up, as the item rests); "
                "authored bbox %s x %s x %s m includes accessories; '-' axes are set by them (E1b authored orientation).\n" % dims)
    open(path, "w").write(txt)
    return dm


def material(set_name):
    return hp.kit.material("MI_%s_%s" % (atlas.NAME, set_name), SET_COL[set_name])


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
    parts, atts = fn()[:2]
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
    dm = sync_dims(asset, dims)
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
        "dims_m": dm, "size_note": SIZE_NOTE, "origin": "base",
        "sets": sets, "atlas": atlas.ATLAS_ASSET, "meshes": meshes, "attachments": attachments,
        "tiling": False, "lod_symmetry": None,
        "waivers": {"LOD UV layout": "collapse decimation of small atlas-tiled kit shifts UV area (same regions sampled)",
                    "LOD0 floor": "hand-held kit item: the docs/12 2.8 row budget is below the large_prop floor",
                    "texel density": "E1b first-person kit runs ABOVE the 100-128 px/stud hero floor by design (crisp weave, "
                                     "stitching, foil crinkle within 1 m): Cloth tiles 341, Foil 379, Hard 178, lifebuoy shell "
                                     "180-190 px/stud at 1024 ship; strips and small lathes higher",
                    "tri budget": "E1b hero first-person rebuild over the docs/12 2.8 row budgets (<= 20k per MeshPart)"},
        "e1_offset": tuple(off),
        "closeups": [{"name": "detail", "target": [0, 0, dims[2] * STUDS * 0.6], "dist": max(reach * 0.9, 1.2), "az": 35, "el": 25}],
    }
