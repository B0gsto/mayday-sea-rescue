"""Shared kit for the premium (Robux) land cars: M_Veh_HarbourGT (sports coupe) and M_Veh_LighthouseCruiser
(luxury SUV). Same contract as M_Veh_LifeguardPickup (its vehgeo.py: Geo, build_set, build_hp, materials): model
frame in studs, X across (driver side -X), Y length (front bumper at Y 0), Z up (ground 0); recentred in build.py.

The body is one parametric skin: a closed section ring per Y station (bottom, side, glass band, roof band), every
height and width a smooth monotone curve of Y. Wheel arches lift the bottom edge, flares widen the shoulder, the
greenhouse rises out of the bonnet / boot deck (max of the two), and a per-face material function paints glass,
pillars, roof, trim and two-tone paint. `patch` lays surface-conforming slabs (lamps, strips, handles) on the skin.
"""
import bisect
import math
import os
import sys

import bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "M_Veh_LifeguardPickup"))
import vehgeo as V  # noqa: E402

STUDS_M = 3.0

V.PALETTE.update({
    "ShutLine": ("#17181A", 0.60, 0.0),
    "TrimGloss": ("#1D1F22", 0.10, 0.0),       # piano-black DLO trim
    "Carbon": ("#26292D", 0.18, 0.0),
    "GrilleMesh": ("#1E2022", 0.45, 0.0),
    "LED": ("#ECEEEC", 0.06, 0.0),
    "LensClear": ("#B9BFC3", 0.04, 0.0),
    "LampInner": ("#2C3034", 0.30, 0.0),
    "LensRed": ("#B3222B", 0.08, 0.0),
    "LensRedHi": ("#D8494B", 0.06, 0.0),       # lit-looking LED element line inside the red lens
    "LensSmoke": ("#4A2428", 0.06, 0.0),
    "LensWarm": ("#E7C98E", 0.08, 0.0),         # warm-white roof lamps (no amber signal)
    "Titanium": ("#C4BCB0", 0.28, 1.0),
    "RimPolished": ("#E3E6E8", 0.12, 1.0),
    "BrakeDisc": ("#9DA1A4", 0.42, 0.0),
    "TyreWall": ("#252729", 0.82, 0.0),
    "Screen": ("#1F2A33", 0.10, 0.0),
    "Stitch": ("#C9C2B2", 0.70, 0.0),
    "Badge": ("#E9EBEC", 0.14, 1.0),
    "Chrome": ("#EDEFF0", 0.08, 1.0),
    "LampChrome": ("#CDD1D4", 0.18, 1.0),      # headlamp reflector bowl under the clear lens
})
V.PROC.update({
    "Carbon": dict(mottle=(6.0, 0.03), rough_var=0.03, bump=("weave", 0.06, 40)),
    "GrilleMesh": dict(mottle=(4.0, 0.03), rough_var=0.05, bump=("diamond", 0.30, 14)),
    "TyreWall": dict(mottle=(4.0, 0.05), grime=("#3A3630", 0.18), rough_var=0.06, bump=("grain", 0.10, 30)),
})


def paint(name, hexc, rough=0.16):
    """Premium car paint: clean clear-coat, only a whisper of mottle (05 5.4: well kept, little cause for wear)."""
    V.PALETTE[name] = (hexc, rough, 0.0)
    V.PROC[name] = dict(mottle=(2.5, 0.012), rough_var=0.025)


def leather(name, hexc, rough=0.52):
    V.PALETTE[name] = (hexc, rough, 0.0)
    V.PROC[name] = dict(mottle=(7.0, 0.05), rough_var=0.05, bump=("grain", 0.06, 46))


def M(g, name):
    return name if g.hi else "X"


def P(x, y, z):
    return Vector((x, y, z))


# --------------------------------------------------------------------------- smooth curves
def curve(pts):
    """Monotone cubic (PCHIP) through (x, y) control points, clamped outside: no overshoot between keys."""
    xs = [float(p[0]) for p in pts]
    ys = [float(p[1]) for p in pts]
    n = len(xs)
    if n == 1:
        return lambda x: ys[0]
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0:
            m[i] = 0.0
        else:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = min(bisect.bisect_right(xs, x) - 1, n - 2)
        t = (x - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
                + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])
    return f


def _selfcheck():
    f = curve([(0, 0), (1, 1), (2, 1), (3, 0)])
    assert abs(f(1) - 1) < 1e-9 and abs(f(1.5) - 1) < 1e-9 and max(f(x / 50) for x in range(150)) <= 1 + 1e-9


_selfcheck()


# --------------------------------------------------------------------------- the parametric body skin
SIDE = (0.0, 0.07, 0.17, 0.30, 0.43, 0.55, 0.65, 0.75, 0.80, 0.85, 0.92, 1.0)
BANDS = ("bottom", "side", "glass", "roof")


class Body:
    """c: dict of curves (functions of y) and numbers:
      L, axles (ys), wheel_z, arch_r, arch_blend, flare (studs), flare_sig
      zb bottom, hw shoulder half width, tuck (rocker inset), fsh shoulder height fraction, zbelt, hwb belt half
      width, zdeck deck centre height, zr roof centre, zre roof edge (glass top), hwroof roof edge half width,
      crown (deck crown exponent), KG glass-band points, KR roof-band points, ds station step, extra (ys)
      matfn(body, band, k, x, y, z) -> material; trim (material for faces touching glass) and no_trim (mats kept)
    """

    def __init__(self, c):
        self.c = c
        self.KG = c.get("KG", 4)
        self.KR = c.get("KR", 8)
        self.NH = 3 + len(SIDE) + self.KG + self.KR
        self.band_of = (["bottom"] * 3 + ["side"] * len(SIDE) + ["glass"] * self.KG + ["roof"] * self.KR)
        self.kin = list(range(3)) + list(range(len(SIDE))) + list(range(1, self.KG + 1)) + list(range(1, self.KR + 1))
        self._cache = {}

    def arch(self, y, zb0):
        c = self.c
        R, bl, wz = c["arch_r"], c["arch_blend"], c["wheel_z"]
        best = zb0
        for hy in c["axles"]:
            d = abs(y - hy)
            if d < R:
                best = max(best, wz + math.sqrt(R * R - d * d))
            elif d < R + bl:
                t = (d - R) / bl
                t = t * t * (3 - 2 * t)
                best = max(best, wz * (1 - t) + zb0 * t)
        return best

    def flare(self, y):
        c = self.c
        f = c.get("flare", 0.0)
        if not f:
            return 0.0
        fl = f if not isinstance(f, (list, tuple)) else None
        out = 0.0
        for i, hy in enumerate(c["axles"]):
            amt = fl if fl is not None else f[i]
            out += amt * math.exp(-((y - hy) / c["flare_sig"]) ** 2)
        return out

    def half(self, y):
        key = round(y, 5)
        if key in self._cache:
            return self._cache[key]
        c = self.c
        zb0 = c["zb"](y)
        zbelt = c["zbelt"](y)
        zbot = min(self.arch(y, zb0), zbelt - 0.14)
        lift = max(0.0, min(1.0, (zbot - zb0) / 0.45))
        fl = self.flare(y)
        hw = c["hw"](y) + fl
        hwb = min(c["hwb"](y) + 0.35 * fl, hw - 0.02)
        hwr = hw - c["tuck"](y)
        hwr = hwr + (hw - 0.025 - hwr) * lift
        pts = [(0.0, zbot), (hwr * 0.5, zbot), (hwr * 0.88, zbot)]
        fsh = c["fsh"](y)
        cr = c.get("crease")      # (s, outward studs, width): a shoulder character line
        for s in SIDE:
            z = zbot + (zbelt - zbot) * s
            if s <= fsh:
                u = s / fsh
                x = hwr + (hw - hwr) * math.sin(u * math.pi / 2)
            else:
                u = (s - fsh) / (1 - fsh)
                x = hw - (hw - hwb) * (1 - math.cos(u * math.pi / 2))
            if cr:
                x += cr[1] * math.exp(-((s - cr[0]) / cr[2]) ** 2)
            pts.append((x, z))
        zdk = c["zdeck"](y)
        zr, zre = c["zr"](y), c["zre"](y)
        hro = min(c["hwroof"](y), hwb - 0.06)
        ce = c.get("crown", 0.6)

        def deck(x):
            u = max(0.0, 1.0 - (x / hwb) ** 2)
            return zbelt + (zdk - zbelt) * u ** ce

        for k in range(1, self.KG + 1):
            f = k / self.KG
            x = hwb + (hro - hwb) * f
            zg = zbelt + (zre - zbelt) * f
            pts.append((x, max(deck(x), zg)))
        for k in range(1, self.KR + 1):
            f = k / self.KR
            x = hro * (1 - f) if k < self.KR else 0.0
            zg = zre + (zr - zre) * (1 - (1 - f) ** 2.2)
            pts.append((x, max(deck(x), zg)))
        self._cache[key] = pts
        return pts

    def stations(self):
        c = self.c
        L, ds = c["L"], c.get("ds", 0.22)
        ys = [L * k / max(1, round(L / ds)) for k in range(round(L / ds) + 1)]
        R, bl = c["arch_r"], c["arch_blend"]
        for hy in c["axles"]:
            for k in range(23):
                ys.append(hy - R - bl + (2 * R + 2 * bl) * k / 22)
        ys += [v for v in c.get("extra", ())]
        for e in (0.0, L):     # dense ends: the nose and tail wrap
            for d in (0.04, 0.1, 0.18, 0.28, 0.4):
                ys.append(abs(e - d) if e == 0 else e - d)
        out = []
        for y in sorted(ys):
            if 0.0 <= y <= L and (not out or y - out[-1] > 0.035):
                out.append(y)
        if out[-1] < L - 1e-6:
            out[-1] = L
        return out

    def ring(self, y):
        h = self.half(y)
        full = [P(x, y, z) for x, z in h] + [P(-h[j][0], y, h[j][1]) for j in range(self.NH - 2, 0, -1)]
        return full

    def jmap(self, J):
        """full-ring index -> (half index, side)."""
        if J < self.NH:
            return J, 1
        return 2 * self.NH - 2 - J, -1

    def grid(self):
        ys = self.stations()
        return ys, [self.ring(y) for y in ys]

    def materials(self, ys, rings):
        """mats[i][J] for the face between stations i, i+1 and ring points J, J+1."""
        c = self.c
        n = len(rings[0])
        mats = []
        for i in range(len(ys) - 1):
            row = []
            for J in range(n):
                j, side = self.jmap(J)
                j2, _ = self.jmap((J + 1) % n)
                jj = max(j, j2)       # band of the upper point
                ctr = (rings[i][J] + rings[i][(J + 1) % n] + rings[i + 1][J] + rings[i + 1][(J + 1) % n]) / 4
                row.append(c["matfn"](self, self.band_of[jj], self.kin[jj], ctr.x, ctr.y, ctr.z))
            mats.append(row)
        trim = c.get("trim")
        if trim:
            keep = set(c.get("no_trim", ())) | {"Glass", trim}
            out = [r[:] for r in mats]
            for i in range(len(mats)):
                for J in range(n):
                    if mats[i][J] in keep:
                        continue
                    nb = []
                    for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        a = i + di
                        if 0 <= a < len(mats):
                            nb.append(mats[a][(J + dj) % n])
                    if "Glass" in nb:
                        out[i][J] = trim
            mats = out
        return mats

    def build(self, g, want, inset=0.0):
        """Adds the skin faces whose material passes want(mat); glass (inset > 0) sinks along the vertex normal."""
        ys, rings = self.grid()
        mats = self.materials(ys, rings)
        n = len(rings[0])
        nrm = None
        if inset:
            nrm = [[self._gnormal(rings, i, J) for J in range(n)] for i in range(len(ys))]
        verts = {}

        def vert(i, J):
            k = (i, J)
            if k not in verts:
                p = rings[i][J]
                if nrm:
                    p = p - nrm[i][J] * inset
                verts[k] = g.bm.verts.new(p)
            return verts[k]
        faces = []
        for i in range(len(ys) - 1):
            for J in range(n):
                m = mats[i][J]
                if not want(m):
                    continue
                K = (J + 1) % n
                f = g.face((vert(i, J), vert(i + 1, J), vert(i + 1, K), vert(i, K)), M(g, m))
                if f:
                    faces.append(f)
        cm = self.c.get("cap_mat", "Paint")
        for i, sgn in ((0, -1), (len(ys) - 1, 1)):
            if not want(cm):
                continue
            ring = [vert(i, J) for J in range(n)]
            cfs = g.cap(ring, M(g, cm))
            g.orient(cfs, lambda p, s=sgn: Vector((0, s, 0)))
            faces += cfs
        return faces

    def _gnormal(self, rings, i, J):
        n = len(rings[0])
        a = rings[min(i + 1, len(rings) - 1)][J] - rings[max(i - 1, 0)][J]
        b = rings[i][(J + 1) % n] - rings[i][(J - 1) % n]
        v = a.cross(b)
        return v.normalized() if v.length > 1e-9 else Vector((0, 0, 1))

    def inner(self, g, y0, y1, matfn, off=0.07, caps=(True, True)):
        """Cabin lining: the skin between y0 and y1 offset inward, facing in (door cards, headliner, floor). Faces
        behind glass are left out, so the single-sided glass reads see-through from the cockpit."""
        ys = [y for y in self.stations() if y0 <= y <= y1]
        ys = ys[::2] + ([ys[-1]] if len(ys) % 2 == 0 else [])    # half the skin's stations: lining is seen up close only
        rings = [self.ring(y) for y in ys]
        mats = self.materials(ys, rings)
        n = len(rings[0])
        faces = []
        vs = []
        for i in range(len(ys)):
            row = []
            for J in range(n):
                nv = self._gnormal(rings, i, J)
                row.append(g.bm.verts.new(rings[i][J] - nv * off))
            vs.append(row)
        for i in range(len(ys) - 1):
            for J in range(n):
                if mats[i][J] == "Glass":
                    continue
                j, _ = self.jmap(J)
                band = self.band_of[max(j, self.jmap((J + 1) % n)[0])]
                K = (J + 1) % n
                f = g.face((vs[i][J], vs[i][K], vs[i + 1][K], vs[i + 1][J]), M(g, matfn(band)))
                if f:
                    faces.append(f)
        for (i, sgn), on in zip(((0, 1), (len(ys) - 1, -1)), caps):
            if on:
                cfs = g.cap(vs[i], M(g, matfn("cap")))
                g.orient(cfs, lambda p, s=sgn: Vector((0, s, 0)))
        return faces

    # ---- surface queries
    def surf(self, y, t, side=1):
        h = self.half(y)
        j = max(0, min(int(math.floor(t)), self.NH - 2))
        f = t - j
        x = h[j][0] * (1 - f) + h[j + 1][0] * f
        z = h[j][1] * (1 - f) + h[j + 1][1] * f
        return P(side * x, y, z)

    def snormal(self, y, t, side=1):
        a = self.surf(y + 0.03, t, side) - self.surf(y - 0.03, t, side)
        b = self.surf(y, t + 0.04, side) - self.surf(y, t - 0.04, side)
        v = a.cross(b) * side
        return v.normalized() if v.length > 1e-9 else Vector((side, 0, 0))

    def tband(self, band, k=0.0):
        """Half-ring parameter t of a band position (k fractional index within the band)."""
        base = {"bottom": 0, "side": 3, "glass": 3 + len(SIDE) - 1, "roof": 3 + len(SIDE) - 1 + self.KG}[band]
        return base + k

    def t_at_z(self, y, z, lo=None, hi=None):
        """t on the side (bottom..glass top) where the skin crosses height z."""
        h = self.half(y)
        lo = 2 if lo is None else lo
        hi = 3 + len(SIDE) + self.KG - 1 if hi is None else hi
        if z <= h[lo][1]:
            return float(lo)
        for j in range(lo, hi):
            z0, z1 = h[j][1], h[j + 1][1]
            if (z0 - z) * (z1 - z) <= 0 and abs(z1 - z0) > 1e-6:
                return j + (z - z0) / (z1 - z0)
        return float(hi)

    def patch(self, g, ys, ts, side, mat, off=0.02, depth=0.03, tfn=None):
        """Surface-conforming slab: ys / ts lists (or tfn(y) -> (t0, t1)), lifted `off` along the skin normal."""
        rings = []
        spans = [tfn(y) if tfn else ts for y in ys]
        nt = max(2, int(max(abs(b - a) for a, b in spans) / 0.5) + 2)
        for y, (t0, t1) in zip(ys, spans):
            tt = [t0 + (t1 - t0) * k / (nt - 1) for k in range(nt)]
            top = [self.surf(y, t, side) + self.snormal(y, t, side) * off for t in tt]
            bot = [self.surf(y, t, side) - self.snormal(y, t, side) * depth for t in reversed(tt)]
            rings.append(top + bot)
        return g.rings(rings, mat, closed=True, cap0=True, cap1=True)

    def strip_z(self, g, y0, y1, z0, z1, side, mat, off=0.02, n=None, depth=0.03):
        """Patch between heights z0 (y) and z1 (y) (numbers or functions of y) on the side skin."""
        n = n or max(3, int((y1 - y0) / 0.3) + 2)
        ys = [y0 + (y1 - y0) * k / (n - 1) for k in range(n)]
        za = z0 if callable(z0) else (lambda y: z0)
        zc = z1 if callable(z1) else (lambda y: z1)
        return self.patch(g, ys, None, side, mat, off=off, depth=depth,
                          tfn=lambda y: (self.t_at_z(y, za(y)), self.t_at_z(y, zc(y))))

    def points(self, step=1.0):
        """Coarse skin points for the collision hull."""
        out = []
        for y in self.stations()[::max(1, int(step / 0.22))] + [self.c["L"]]:
            r = self.ring(y)
            out += r[::2]
        return out


# --------------------------------------------------------------------------- generic parts
def loft_x(g, sections, mat, seg=12, p=2.6, cap=True):
    """Superellipse sections across Y/Z stepped along X: [(x, cy, cz, hy, hz)]."""
    rings = []
    for x, cy, cz, hy, hz in sections:
        r = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ca, sa = math.cos(a), math.sin(a)
            r.append(P(x, cy + hy * math.copysign(abs(ca) ** (2 / p), ca), cz + hz * math.copysign(abs(sa) ** (2 / p), sa)))
        rings.append(r)
    return g.rings(rings, mat, cap0=cap, cap1=cap)


def loft_y(g, sections, mat, seg=12, p=2.6, cap=True):
    """Superellipse sections across X/Z stepped along Y: [(y, cx, cz, hx, hz)]."""
    rings = []
    for y, cx, cz, hx, hz in sections:
        r = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ca, sa = math.cos(a), math.sin(a)
            r.append(P(cx + hx * math.copysign(abs(ca) ** (2 / p), ca), y, cz + hz * math.copysign(abs(sa) ** (2 / p), sa)))
        rings.append(r)
    return g.rings(rings, mat, cap0=cap, cap1=cap)


def loft_z(g, sections, mat, seg=12, p=2.6, cap=True):
    """Superellipse sections across X/Y stepped along Z: [(z, cx, cy, hx, hy)]."""
    rings = []
    for z, cx, cy, hx, hy in sections:
        r = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ca, sa = math.cos(a), math.sin(a)
            r.append(P(cx + hx * math.copysign(abs(ca) ** (2 / p), ca), cy + hy * math.copysign(abs(sa) ** (2 / p), sa), z))
        rings.append(r)
    return g.rings(rings, mat, cap0=cap, cap1=cap)


def torus(g, centre, axis, R, r, seg, rseg, mat):
    axis = Vector(axis).normalized()
    ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u).normalized()
    c = Vector(centre)
    rings = []
    for i in range(seg + 1):
        a = 2 * math.pi * i / seg
        d = u * math.cos(a) + w * math.sin(a)
        rings.append([c + d * (R + r * math.cos(2 * math.pi * j / rseg)) + axis * (r * math.sin(2 * math.pi * j / rseg))
                      for j in range(rseg)])
    return g.rings(rings, mat)


def mark(g):
    return set(g.bm.verts)


def move_new(g, before, fn):
    """Moves every vert added since `before` (a mark()); index-based V.deform breaks when a bevel deletes verts."""
    for v in g.bm.verts:
        if v not in before:
            v.co = fn(v.co.copy())


def seat(g, x, y, z, w, mat, bolster, sport=True, recline=14.0, side_mat=None):
    """Bucket / lounge seat at the cushion-top point (x, y, z), facing -Y."""
    sm = side_mat or mat
    cush_h = 0.42 if sport else 0.50
    # cushion
    loft_y(g, [(y - 0.80, x, z - cush_h * 0.55, w * 0.46, cush_h * 0.45), (y - 0.70, x, z - cush_h * 0.45, w * 0.5, cush_h * 0.55),
               (y + 0.15, x, z - cush_h * 0.5, w * 0.5, cush_h * 0.5), (y + 0.42, x, z - cush_h * 0.55, w * 0.46, cush_h * 0.42)],
           mat, seg=12, p=3.2)
    # backrest, reclined about X at its hinge
    hinge = P(x, y + 0.36, z - 0.08)
    rot = Matrix.Rotation(math.radians(-recline), 4, "X")
    start = mark(g)
    bh = 2.15 if sport else 2.05
    loft_z(g, [(0.0, 0.0, 0.0, w * 0.48, 0.26), (bh * 0.55, 0.0, 0.0, w * 0.46, 0.22),
               (bh * 0.82, 0.0, -0.02, w * (0.33 if sport else 0.44), 0.20), (bh, 0.0, -0.02, w * (0.30 if sport else 0.40), 0.18)],
           mat, seg=12, p=3.0)
    if sport:   # wing bolsters and the harness slots read as a bucket
        for sx in (-1, 1):
            loft_z(g, [(0.08, sx * w * 0.47, -0.10, 0.11, 0.30), (bh * 0.62, sx * w * 0.45, -0.12, 0.10, 0.26),
                       (bh * 0.70, sx * w * 0.40, -0.10, 0.08, 0.2)], sm, seg=8, p=2.4)
            V.box(g, (sx * w * 0.20, -0.20, bh * 0.86), (0.20, 0.06, 0.08), "TrimGloss" if g.hi else "X", bev=0.02)
    else:      # separate lounge headrest
        V.box(g, (0, 0.02, bh + 0.30), (w * 0.62, 0.30, 0.42), mat, bev=0.10)
        for sx in (-1, 1):
            V.box(g, (sx * w * 0.16, 0.02, bh + 0.05), (0.04, 0.04, 0.2), "Chrome" if g.hi else "X", bev=0.0)
    move_new(g, start, lambda co: (Matrix.Translation(hinge) @ rot @ co.to_4d()).to_3d())
    if g.hi:   # stitched panels baked into the cushion / backrest
        for k in (-1, 1):
            V.box(g, (x + k * w * 0.18, y - 0.2, z + 0.005), (0.025, 1.0, 0.02), "Stitch")


def steering_wheel(g, centre, r, tilt, rim_mat, hub_mat):
    """Wheel in the plane facing the driver (-Y toward the dash), tilted `tilt` degrees back from vertical."""
    start = mark(g)
    torus(g, (0, 0, 0), (0, 1, 0), r, 0.07, 28 if g.hi else 18, 8 if g.hi else 6, rim_mat)
    V.lathe(g, (0, 0.02, 0), (0, 1, 0), [(0.0, -0.06), (0.20, -0.06), (0.24, 0.0), (0.18, 0.08), (0.0, 0.09)],
            16 if g.hi else 10, hub_mat)
    for a in (180, 0, 270):
        t = math.radians(a)
        V.box(g, (0.5 * r * math.cos(t), 0.0, 0.5 * r * math.sin(t)), (r if a != 270 else 0.12, 0.05, 0.12 if a != 270 else r),
              hub_mat, bev=0.02)
    rot = Matrix.Rotation(math.radians(tilt), 4, "X")
    c = Vector(centre)
    move_new(g, start, lambda co: (Matrix.Translation(c) @ rot @ co.to_4d()).to_3d())


# --------------------------------------------------------------------------- wheels
def tyre_profile(R, RR, W, hi):
    """(radius, axial) from the inboard bead round the tread to the outboard bead; grooves only on the _HP."""
    pr = [(RR + 0.02, -W * 0.44), (RR + 0.12, -W * 0.49), (R - 0.12, -W * 0.50), (R - 0.04, -W * 0.47),
          (R, -W * 0.40)]
    if hi:
        for gx in (-0.22, 0.0, 0.22):
            pr += [(R, W * gx - 0.06), (R - 0.04, W * gx - 0.045), (R - 0.04, W * gx + 0.045), (R, W * gx + 0.06)]
    pr += [(R, W * 0.40), (R - 0.04, W * 0.47), (R - 0.12, W * 0.50), (R - 0.18, W * 0.505), (RR + 0.12, W * 0.49),
           (RR + 0.02, W * 0.44)]
    return pr


def wheel(g, hub, side, w):
    """One road wheel about +X at `hub` (outboard face +X * side). w: R, RR, W, spokes, twin, style mats."""
    R, RR, W = w["R"], w["RR"], w["W"]
    seg = 40     # _HP matches LOD0 so the baked normals never ripple the chrome lip highlight
    cx, cy, cz = hub
    o = P(cx, cy, cz)
    ax = Vector((side, 0, 0))
    V.lathe(g, o, ax, tyre_profile(R, RR, W, g.hi), seg, M(g, "TyreWall"))
    if g.hi:   # sidewall rim protector rib and lettering band
        V.lathe(g, o, ax, [(RR + 0.20, W * 0.51), (RR + 0.215, W * 0.525), (RR + 0.23, W * 0.51)], seg, "Tyre")
    # barrel (dark) and the polished outer lip
    V.lathe(g, o, ax, [(RR - 0.02, -W * 0.44), (RR - 0.05, -W * 0.40), (RR - 0.05, W * 0.30), (RR - 0.03, W * 0.36)],
            seg, M(g, "RimDark"))
    lip = w.get("lip", "RimPolished")
    V.lathe(g, o, ax, [(RR - 0.035, W * 0.36), (RR + 0.035, W * 0.43), (RR + 0.04, W * 0.47), (RR - 0.01, W * 0.48),
                       (RR - 0.08, W * 0.44), (RR - 0.09, W * 0.40)], seg, M(g, lip))
    # spokes: dished from the hub face to the lip
    face = w["face"]
    n = w["spokes"]
    twin = w.get("twin", 0.0)
    r0, r1 = 0.24, RR - 0.035
    hface, hlip = W * w.get("dish0", 0.30), W * w.get("dish1", 0.40)
    for k in range(n):
        for tw in ((-twin, twin) if twin else (0.0,)):
            a = 2 * math.pi * k / n + tw
            rings = []
            steps = 3
            for s in range(steps + 1):
                f = s / steps
                r = r0 + (r1 - r0) * f
                h = hface + (hlip - hface) * f ** 1.6
                half_w = (w["w0"] + (w["w1"] - w["w0"]) * f) / 2
                th = w.get("depth", 0.10)
                rad = Vector((0, math.cos(a), math.sin(a)))
                tan = Vector((0, -math.sin(a), math.cos(a)))
                c = o + rad * r + ax * h
                rings.append([c + tan * half_w, c + tan * (half_w * 0.6) - ax * th, c - tan * (half_w * 0.6) - ax * th,
                              c - tan * half_w])
            g.rings(rings, M(g, face), cap0=True, cap1=True)
            if g.hi and w.get("machined"):   # diamond-cut spoke tops
                c0 = o + Vector((0, math.cos(a), math.sin(a))) * (r0 + 0.08) + ax * (hface + 0.012)
                c1 = o + Vector((0, math.cos(a), math.sin(a))) * (r1 - 0.04) + ax * (hlip + 0.012)
                V.tube(g, [c0, c1], 0.022, w["machined"], 6)
    # hub boss, lug nuts, centre cap
    V.lathe(g, o, ax, [(0.0, hface - 0.10), (0.30, hface - 0.10), (0.30, hface - 0.02), (0.26, hface + 0.02),
                       (0.0, hface + 0.02)], 24 if g.hi else 14, M(g, face))
    for k in range(5 if g.hi else 0):   # lug nuts: baked into the hub on LOD0
        a = 2 * math.pi * k / 5 + math.pi / 2
        c = o + Vector((0, 0.17 * math.cos(a), 0.17 * math.sin(a))) + ax * (hface + 0.02)
        V.lathe(g, c, ax, [(0.045, 0.0), (0.045, 0.035), (0.03, 0.05), (0.0, 0.05)], 6, M(g, "Chrome"))
    V.lathe(g, o + ax * (hface + 0.02), ax, [(0.11, 0.0), (0.11, 0.025), (0.08, 0.045), (0.0, 0.05)],
            16 if g.hi else 10, M(g, w.get("cap", "TrimGloss")))
    if g.hi:
        V.lathe(g, o + ax * (hface + 0.07), ax, [(0.06, 0.0), (0.06, 0.006), (0.0, 0.008)], 16, "Badge")


def projector(g, p, n, r, mat_ring="Chrome"):
    """Round projector module: chrome barrel, dark reflector throat and a clear convex lens, facing n."""
    n = Vector(n).normalized()
    V.lathe(g, p, n, [(r, -0.01), (r, 0.025), (r * 0.82, 0.03), (r * 0.78, 0.0)], 20 if g.hi else 14, M(g, mat_ring))
    V.lathe(g, p, n, [(r * 0.78, 0.0), (r * 0.70, 0.012), (r * 0.45, 0.03), (0.0, 0.036)], 20 if g.hi else 14,
            M(g, "LensClear"))


def brakes(g, hub, side, w, front):
    """Static disc + caliper (Underbody, so the caliper does not spin with the art wheel), inboard of the spokes."""
    R = w["disc"] * (1.0 if front else 0.92)
    cx, cy, cz = hub
    x0 = cx + side * w["W"] * 0.05
    V.lathe(g, (x0, cy, cz), (side, 0, 0), [(0.18, -0.05), (R, -0.05), (R, 0.05), (0.18, 0.05)],
            40 if g.hi else 24, M(g, "BrakeDisc"))
    if g.hi:   # cross-drilled ring + vent slots
        for k in range(24):
            a = 2 * math.pi * k / 24
            rr = R * (0.62 + 0.18 * (k % 2))
            V.lathe(g, (x0 + side * 0.051, cy + rr * math.cos(a), cz + rr * math.sin(a)), (side, 0, 0),
                    [(0.022, -0.004), (0.022, 0.0), (0.0, 0.0)], 8, "LampInner")
    V.lathe(g, (x0, cy, cz), (side, 0, 0), [(0.03, 0.05), (0.2, 0.05), (0.2, 0.09), (0.03, 0.10)], 14 if g.hi else 10,
            M(g, "RimDark"))
    # caliper: an arc block over the rear-top of the disc
    pts = []
    for k in range(7):
        a = math.radians(25 + 50 * k / 6)
        pts.append(P(x0 + side * 0.01, cy + (R - 0.08) * math.cos(a), cz + (R - 0.08) * math.sin(a)))
    V.sweep(g, pts, [(-0.13, -0.12), (0.13, -0.12), (0.13, 0.12), (-0.13, 0.12)], M(g, w["caliper"]),
            cap0=True, cap1=True)
    if g.hi:
        V.box(g, (x0 + side * 0.14, cy + (R - 0.08) * math.cos(math.radians(50)), cz + (R - 0.08) * math.sin(math.radians(50))),
              (0.02, 0.18, 0.06), "LED")


def wheel_well(g, hx, hy, wz, r, depth, side):
    rings = []
    x0, x1 = side * (hx - depth), side * hx
    for k in range(13):
        a = math.radians(-100 + 200 * k / 12)
        rad = Vector((0, math.sin(a), math.cos(a)))
        c = P(0, hy, wz)
        rings.append([c + rad * r + P(x0, 0, 0), c + rad * r + P(x1, 0, 0), c + rad * (r + 0.1) + P(x1, 0, 0),
                      c + rad * (r + 0.1) + P(x0, 0, 0)])
    g.rings(rings, M(g, "WheelWell"), cap0=True, cap1=True)
    # inner wall so the arch never shows daylight
    V.extrude_profile(g, [(hy + r * math.sin(math.radians(a)), wz + r * math.cos(math.radians(a))) for a in range(-100, 101, 20)],
                      side * (hx - depth) - 0.04, side * (hx - depth) + 0.04, M(g, "WheelWell"))


def collision_hull(name, pts):
    import bpy
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vj = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vj:
        bmesh.ops.delete(bm, geom=vj, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def hull_points(body, axles, hub_x, wz, R):
    pts = body.points(1.0)
    for hy in axles:
        for sx in (-1, 1):
            for a in range(0, 360, 45):
                t = math.radians(a)
                pts.append(P(sx * hub_x, hy + R * math.cos(t), wz + R * math.sin(t)))
    return pts


def finish(name, here, sets_objs, hps, col, attachments, chassis):
    """Recentre (bbox centre in X / Y, lowest point at Z 0) like the pickup; writes frame_offset.json."""
    import bpy
    import json
    atts = []
    for nm, p in attachments.items():
        e = bpy.data.objects.new(nm, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)
    lod0 = [o for objs, _ in sets_objs for o in objs]
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    bbox = [h - l for l, h in zip(lo, hi)]
    with open(os.path.join(here, "frame_offset.json"), "w") as f:
        json.dump({"offset": [round(c, 4) for c in off], "bbox_studs": [round(c, 4) for c in bbox],
                   "chassis": [round(c, 4) for c in (Vector(chassis) + off)],
                   "note": "offset added to the authored model frame; chassis = LandVehicleConfig / Builder root, "
                           "Blender studs, equal to the ATT_DriveAttachment position"}, f, indent=1)
    print("[%s] offset %s bbox %s" % (name, tuple(round(c, 3) for c in off), [round(c, 3) for c in bbox]))
    meshes = []
    for objs, s in sets_objs:
        for o in objs:
            meshes.append({"object": o, "set": s})
    meshes += [{"object": h} for h in hps]
    meshes.append({"object": col})
    return meshes, atts, off
