"""M_Kit_StretcherBasket: procedural PBR maps for the asset's own kit set (T_StretcherBasket_Kit_*).

Called by build.py (inside Blender, numpy only) with the textures directory. Reads features.json - drain holes,
weld collars, strap rows and the foot plate, all computed from the real geometry - plus the exact world size in studs
of every atlas lane, and paints the nine lanes of dims.py:

  shellin / shellout   HDPE tub bottom, inside and out: moulded ribs, drain holes, mud, salt, scuffs
  shellwall            tub profile (fillet, inner wall, lip crest, outer wall): dirt in the fillet, wall holes,
                       handling wear on the lip, mud on the outside
  rim / ribs / runners galvanised tube: spangle grain, brush marks, weld collars, ground polish on the skids
  fittings             lifting eyes, join sleeves, bolts, strap tabs, buckles, grab handles, foot plate
  webbing              black nylon patient straps: basket weave, sun fade, dust, stitched ends
  plastic              drain hole drums (dark voids)

Each lane knows its two axes in studs, so every spot, streak and noise octave is painted at a real-world scale.
ALB luma is fitted to the non-metal / metal ranges, the hi-vis orange goes into signal_mask.png (check_textures),
and _Wet albedo / roughness are derived from the dry maps (darker, glossier).
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(HERE, "../../../tools/blender"))
import dims  # noqa: E402
import pbrmaps  # noqa: E402

SIZE = 1024
S = 3.0

ORANGE = (0.86, 0.31, 0.06)
ORANGE_LIT = (0.94, 0.45, 0.16)
ORANGE_FADE = (0.93, 0.62, 0.42)
ORANGE_DIRT = (0.46, 0.24, 0.11)
ORANGE_GRIME = (0.24, 0.15, 0.10)
STEEL = (0.60, 0.62, 0.63)
STEEL_BRIGHT = (0.82, 0.83, 0.82)
STEEL_DARK = (0.35, 0.36, 0.38)
RUST = (0.42, 0.30, 0.24)
SALT = (0.86, 0.86, 0.83)
GRIME = (0.19, 0.17, 0.14)
MUD = (0.31, 0.26, 0.19)
WEB = (0.115, 0.113, 0.120)
WEB_FADE = (0.30, 0.30, 0.31)
DUST = (0.44, 0.41, 0.35)
VOID = (0.09, 0.085, 0.08)
PAINT = (0.16, 0.165, 0.175)          # black-painted steel (tabs, buckles): non-metal in PBR
PLATE = (0.34, 0.35, 0.36)            # dull painted foot plate
DARK_STEEL = (0.26, 0.27, 0.29)
RIPLE = ((0.137, 0.172), (0.328, 0.363), (0.637, 0.672), (0.828, 0.863))   # moulded ribs: lane v bands


# ---------------------------------------------------------------- noise
def _vn(h, w, fu, fv, seed):
    rng = np.random.default_rng(seed)
    fu, fv = max(1, int(fu)), max(1, int(fv))
    g = rng.random((fv, fu)).astype(np.float32)
    u = (np.arange(w) + 0.5) * fu / w
    v = (np.arange(h) + 0.5) * fv / h
    u0 = np.floor(u).astype(np.int64) % fu
    v0 = np.floor(v).astype(np.int64) % fv
    tu = (u - np.floor(u)).astype(np.float32)
    tv = (v - np.floor(v)).astype(np.float32)
    tu = tu * tu * (3 - 2 * tu)
    tv = tv * tv * (3 - 2 * tv)
    top = g[np.ix_(v0, u0)] + (g[np.ix_(v0, (u0 + 1) % fu)] - g[np.ix_(v0, u0)]) * tu[None, :]
    bot = g[np.ix_((v0 + 1) % fv, u0)] + (g[np.ix_((v0 + 1) % fv, (u0 + 1) % fu)] - g[np.ix_((v0 + 1) % fv, u0)]) * tu[None, :]
    return top + (bot - top) * tv[:, None]


def fbm(h, w, fu, fv, seed, octaves=4, gain=0.55):
    acc = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        acc += amp * _vn(h, w, fu * (2 ** o), fv * (2 ** o), seed + 31 * o)
        tot += amp
        amp *= gain
    return acc / max(tot, 1e-6)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / max(e1 - e0, 1e-6), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def C(col, k=1.0):
    return tuple(min(1.0, c * k) for c in col)


# ---------------------------------------------------------------- tex + lane
class Tex:
    def __init__(self):
        n = SIZE
        self.n = n
        self.alb = np.zeros((n, n, 3), np.float32)
        self.hgt = np.zeros((n, n), np.float32)
        self.rgh = np.full((n, n), 0.55, np.float32)
        self.met = np.zeros((n, n), np.float32)
        self.sig = np.zeros((n, n), bool)
        self.cov = np.zeros((n, n), bool)
        self.pu = np.full((n, n), 180.0, np.float32)
        self.pv = np.full((n, n), 180.0, np.float32)

    def lane(self, name, wu, wv, mirror=False):
        return Lane(self, name, float(wu), float(wv), mirror)

    def write(self, directory):
        os.makedirs(directory, exist_ok=True)
        met = (self.met >= 0.5).astype(np.float32)
        alb = pbrmaps.clamp_albedo(np.clip(self.alb, 0.0, 1.0), met)
        rgh = np.clip(self.rgh, 0.03, 1.0)
        gy, gx = np.gradient(self.hgt.astype(np.float32))
        nx, ny, nz = -gx * self.pu, gy * self.pv, np.ones_like(self.hgt)
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        nor = np.stack([nx / ln, ny / ln, nz / ln], axis=2) * 0.5 + 0.5
        alb_w, rgh_w = pbrmaps.wet(alb, rgh, darken=0.24, gloss=0.34)
        idx = pbrmaps.dilate_index(self.cov, 4)
        maps = {("ALB", False): pbrmaps.pad(alb, idx, (0.5, 0.5, 0.5)),
                ("NOR", False): pbrmaps.pad(nor, idx, (0.5, 0.5, 1.0)),
                ("RGH", False): pbrmaps.pad(rgh, idx, 0.6),
                ("MET", False): pbrmaps.pad(met, idx, 0.0),
                ("ALB", True): pbrmaps.pad(alb_w, idx, (0.5, 0.5, 0.5)),
                ("RGH", True): pbrmaps.pad(rgh_w, idx, 0.6)}
        for (kind, wet), arr in maps.items():
            stem = "T_StretcherBasket_Kit_%s%s" % (kind, "_Wet" if wet else "")
            pbrmaps.write_png(os.path.join(directory, stem + ".png"), arr)
        sig = pbrmaps.pad(self.sig.astype(np.float32), idx, 0.0)
        pbrmaps.write_png(os.path.join(HERE, "signal_mask.png"), (sig > 0.5).astype(np.float32))
        return directory


class Lane:
    """One lane's view of the maps: local (u, v) in 0..1, local px (u * n, (1 - v) * h)."""

    def __init__(self, tex, name, wu, wv, mirror=False):
        self.t = tex
        self.name = name
        self.mirror = mirror
        v0, v1 = dims.LANES[name]
        self.r0 = int(round((1.0 - v1) * tex.n))
        self.r1 = int(round((1.0 - v0) * tex.n))
        self.h = self.r1 - self.r0
        self.w = tex.n
        self.wu, self.wv = max(wu, 1e-3), max(wv, 1e-3)
        self.pu = self.w / self.wu
        self.pv = self.h / self.wv
        sl = slice(self.r0, self.r1)
        self.A, self.H, self.R, self.M, self.G, self.C = (tex.alb[sl], tex.hgt[sl], tex.rgh[sl],
                                                          tex.met[sl], tex.sig[sl], tex.cov[sl])
        tex.pu[sl] = self.pu
        tex.pv[sl] = self.pv
        self.C[:] = True
        self._g = None

    def grid(self):
        if self._g is None:
            u = (np.arange(self.w) + 0.5) / self.w
            v = 1.0 - (np.arange(self.h) + 0.5) / self.h
            self._g = np.meshgrid(u, v)
        return self._g

    # ---- masks
    def noise(self, feat, seed, octaves=4, scale_v=1.0):
        fu = max(1, int(round(feat * self.wu)))
        fv = max(1, int(round(feat * self.wv * scale_v)))
        if self.mirror:
            fu = max(2, 2 * int(round(fu / 2.0)))
        return fbm(self.h, self.w, fu, fv, seed, octaves)

    def _dups(self, u):
        return [(u % 0.5), (u % 0.5) + 0.5] if self.mirror else [u % 1.0]

    def disc(self, u, v, r, soft=0.4, pu=None, pv=None):
        pu = pu or self.pu
        pv = pv or self.pv
        uu, vv = self.grid()
        out = np.zeros((self.h, self.w), np.float32)
        for u0 in self._dups(u):
            for k in (-1, 0, 1):
                du = (uu - (u0 + k)) * pu
                dv = (vv - v) * pv
                out = np.maximum(out, 1.0 - sstep(r * (1.0 - soft), r * (1.0 + soft), np.sqrt(du * du + dv * dv)))
        return out

    def ellipse(self, u, v, ru, rv, soft=0.4):
        uu, vv = self.grid()
        out = np.zeros((self.h, self.w), np.float32)
        for u0 in self._dups(u):
            for k in (-1, 0, 1):
                d = np.sqrt(((uu - (u0 + k)) * self.pu / ru) ** 2 + ((vv - v) * self.pv / rv) ** 2)
                out = np.maximum(out, 1.0 - sstep(1.0 - soft, 1.0 + soft, d))
        return out

    def band(self, axis, a, b, soft=0.4):
        uu, vv = self.grid()
        x = vv if axis == "v" else uu
        w = max((b - a), 1e-4) * 0.5 * soft
        return sstep(a - w, a + w, x) * (1.0 - sstep(b - w, b + w, x))

    def streak(self, u0, v0, u1, v1, w, seed, soft=0.5):
        uu, vv = self.grid()
        out = np.zeros((self.h, self.w), np.float32)
        n = max(3, int(np.hypot((u1 - u0) * self.wu, (v1 - v0) * self.wv) / 0.05))
        rng = np.random.default_rng(seed)
        for i in range(n):
            t = i / float(n - 1)
            du = (uu - (u0 + (u1 - u0) * t + rng.normal(0, 0.004))) * self.pu
            dv = (vv - (v0 + (v1 - v0) * t + rng.normal(0, 0.004))) * self.pv
            out = np.maximum(out, 1.0 - sstep(w * (1 - soft), w * (1 + soft), np.sqrt(du * du + dv * dv)))
        return out

    # ---- writes
    def fill(self, col):
        self.A[:] = col
        return self

    def mix(self, m, col, k=1.0):
        if m.ndim == 2:
            m = m[..., None]
        self.A[:] = self.A * (1.0 - m * k) + np.asarray(col, np.float32) * (m * k)
        return self

    def shade(self, m, k):
        self.A[:] = self.A * (1.0 + (m[..., None] if m.ndim == 2 else m) * k)
        return self

    def add_h(self, m, amt):
        self.H[:] += m * amt
        return self

    def rg(self, m, val, k=1.0):
        self.R[:] = self.R * (1.0 - m * k) + val * (m * k)
        return self

    def mt(self, m, val, k=1.0):
        self.M[:] = self.M * (1.0 - m * k) + val * (m * k)
        return self

    def signal(self, m):
        self.G[:] |= (m > 0.4)
        return self

    def all(self):
        return np.ones((self.h, self.w), np.float32)


# ---------------------------------------------------------------- galvanised steel
def paint_steel(L, seed, spangle=1.0, dirt_v=0.72, bright_v=0.25, plain=False):
    facet = L.noise(1.6, seed + 1, octaves=3)
    fine = L.noise(11.0, seed + 2, octaves=3)
    wash = L.noise(0.4, seed + 3, octaves=2)
    uu, vv = L.grid()
    L.fill(STEEL)
    L.mix(np.clip(0.30 + 0.9 * facet - 0.4 * wash, 0, 1) * 0.6 * spangle, C(STEEL_BRIGHT, 1.0), 1.0)
    L.mix(np.clip(0.85 - 1.1 * facet - 0.4 * wash, 0, 1) * 0.55 * spangle, C(STEEL, 0.74), 1.0)
    L.shade(fine - 0.5, 0.10)
    L.add_h((fine - 0.5) * 0.0011, 1.0)
    L.mt(L.all(), 1.0, 1.0)
    L.rg(np.clip(0.30 + 0.75 * facet + 0.35 * fine - 0.35 * wash, 0, 1), 0.48, 1.0)
    if not plain:
        g = fbm(L.h, L.w, max(1, int(round(0.5 * L.wu))), max(1, int(round(0.5 * L.wv))), seed + 11, octaves=2)
        L.add_h((g - 0.5) * 0.0016, 1.0)
        L.shade(g - 0.5, 0.07)
    # dirt / mud on the underside, washed bright on the weather side
    dirt = 1.0 - sstep(0.26, 0.40, np.abs(vv - dirt_v))
    dm = np.clip(dirt * (0.40 + 0.85 * wash), 0, 1)
    L.mix(dm * 0.6, GRIME, 1.0)
    L.mix(dm * np.clip(wash - 0.35, 0, 1) * 1.6, MUD, 1.0)
    L.rg(dm, 0.88, 0.7)
    L.mt(dm, 0.02, 0.9)
    bright = 1.0 - sstep(0.14, 0.30, np.abs(vv - bright_v))
    L.mix(bright * 0.45 * wash, C(STEEL_BRIGHT, 1.04), 1.0)
    L.rg(np.clip(bright * 0.7, 0, 1), 0.34, 0.6)
    dustf = sstep(0.34, 0.74, L.noise(1.7, seed + 21, octaves=3))
    L.mix(dustf * 0.75, DUST, 0.7)
    L.rg(dustf, 0.88, 0.6)
    L.mt(dustf, 0.03, 0.5)
    saltf = sstep(0.62, 0.92, L.noise(4.5, seed + 22, octaves=3)) * dustf
    L.mix(saltf * 0.6, SALT, 0.6)
    E = np.zeros((L.h, L.w), np.float32)
    rng = np.random.default_rng(seed + 4)
    for i in range(24):
        u0, v0 = rng.random(), rng.random()
        m = L.streak(u0, v0, u0 + rng.normal(0, 0.05), v0 + rng.normal(0, 0.02), 0.003 + 0.006 * rng.random(), seed + 400 + i)
        L.mix(m * 0.55, C(STEEL_BRIGHT, 1.05), 1.0)
        L.rg(m, 0.22, 0.6)
        E = np.maximum(E, m * 0.3)
    L.mt(E, 1.0, 1.0)


def paint_welds(L, feats, styles=("frame",)):
    """Weld collars: a raised bead with a heat-tinted halo where the frame tubes meet."""
    for f in feats:
        if f["lane"] != L.name or f.get("style") not in styles:
            continue
        bead = L.ellipse(f["u"], f["v"], f["ru"], f["rv"], soft=0.45)
        L.add_h(bead, 0.0022)
        L.mix(bead * 0.85, C(STEEL_DARK, 0.78), 1.0)
        L.rg(bead, 0.70, 0.8)
        L.mt(bead, 0.15, 0.5)
        halo = np.clip(L.ellipse(f["u"], f["v"], f["ru"] * 2.6, f["rv"] * 2.2, soft=0.9) - bead, 0, 1)
        rng = np.random.default_rng(int(abs(f["u"]) * 9973) + 7)
        rust = halo * sstep(0.5, 0.8, fbm(L.h, L.w, 70, 6, 41, octaves=2)) * (0.35 + 0.75 * rng.random())
        L.mix(rust, RUST, 0.6)
        L.rg(rust, 0.92, 0.6)
        L.mt(rust, 0.0, 0.9)
        L.add_h(rust, 0.0006)


# ---------------------------------------------------------------- HDPE
def paint_orange(L, seed, holes=(), ribs=(), mud=0.8, outer=False, wall=False, wall_v=(0.17, 0.53, 0.58, 0.90)):
    fade = L.noise(0.5, seed, octaves=3)
    blot = L.noise(2.4, seed + 1, octaves=3)
    peel = L.noise(18.0, seed + 2, octaves=2)
    uu, vv = L.grid()
    L.fill(ORANGE)
    L.mix(sstep(0.45, 0.75, fade), ORANGE_FADE, 0.5)
    L.mix(sstep(0.42, 0.82, blot) * 0.45, ORANGE_LIT, 0.5)
    L.mix(sstep(0.60, 0.28, blot) * 0.35, ORANGE_DIRT, 0.6)
    L.shade(peel - 0.5, 0.06)
    L.add_h((peel - 0.5) * 0.0014, 1.0)
    L.rg(np.clip(0.40 + peel * 0.35, 0, 1), 0.32, 1.0)
    for (a, b) in ribs:                                         # moulded stiffening ribs
        m = L.band("v", a, b, 0.5) * (1.0 - sstep(0.80, 0.99, np.abs(uu - 0.5) * 2.0))
        L.add_h(m, 0.0050)
        L.mix(m * 0.42, ORANGE_LIT, 1.0)
        L.rg(m, 0.30, 0.5)
        for edge, k in ((a, 1.0), (b, -1.0)):
            sh = L.band("v", min(a, b) - 0.012, min(a, b) + 0.012, 1.2) if k > 0 else \
                 L.band("v", max(a, b) - 0.012, max(a, b) + 0.012, 1.2)
            sh = sh * (1.0 - sstep(0.80, 0.99, np.abs(uu - 0.5) * 2.0))
            L.mix(sh * 0.35, ORANGE_DIRT, 1.0)
            L.add_h(sh * 0.4, -0.0012)
    for f in holes:                                             # drain holes: dark recess + moulded rim
        if f["lane"] != L.name:
            continue
        r = f["r"]
        hole = L.disc(f["u"], f["v"], r * 1.05, soft=0.18)
        rim = L.disc(f["u"], f["v"], r * 1.45, soft=0.6) * (1.0 - hole)
        L.mix(rim * 0.8, ORANGE_DIRT, 1.0)
        L.add_h(rim * 0.35, 0.0012)
        L.add_h(hole, -0.0055)
        L.mix(hole, VOID, 0.95)
        L.rg(hole, 0.80, 1.0)
    mudn = L.noise(1.2, seed + 5, octaves=3)
    splash = L.noise(7.0, seed + 6, octaves=2)
    if wall:
        band = sstep(wall_v[3] - 0.06, 1.0, vv) + (1.0 - sstep(0.0, wall_v[0] * 0.9, vv))
        band = np.clip(band, 0, 1)
    else:
        band = np.clip(1.0 - sstep(0.0, 0.34, np.minimum(vv, 1.0 - vv) * 2.0), 0, 1)
    m = np.clip(band * (0.4 + 0.9 * mudn) * mud * 1.7, 0, 1) * (0.45 + 0.55 * splash)
    L.mix(m, MUD, 0.62)
    L.rg(m, 0.88, 0.65)
    salt = sstep(0.60, 0.88, L.noise(3.0, seed + 7, octaves=3)) * np.clip(band + 0.30, 0, 1)
    L.mix(salt * 0.7, SALT, 0.7)
    L.rg(salt, 0.82, 0.6)
    L.add_h(salt * 0.25, 0.0012)
    if outer:
        L.mix(np.clip(0.30 + 0.6 * mudn, 0, 1) * 0.6, GRIME, 0.4)
    rng = np.random.default_rng(seed + 8)
    for i in range(30):                                         # scuffs and drag marks
        u0, v0 = rng.random(), rng.random()
        m = L.streak(u0, v0, u0 + rng.normal(0, 0.09), v0 + rng.normal(0, 0.015), 0.005 + 0.010 * rng.random(), seed + 50 + i)
        L.shade(m, 0.18)
        L.mix(m * 0.45, ORANGE_FADE, 0.6)
        L.rg(m, 0.54, 0.5)
        L.add_h(m * 0.3, -0.0009)
    for i in range(10):                                         # worn patches
        u0, v0 = rng.random(), rng.random()
        m = L.disc(u0, v0, 0.05 + 0.09 * rng.random(), soft=0.85)
        L.shade(m, 0.09)
        L.rg(m, 0.56, 0.4)
    L.signal(L.all())


def paint_webbing(L, seed):
    L.fill(WEB)
    uu, vv = L.grid()
    warp = 1.0 - np.abs(((vv * L.wv / 0.013) % 1.0) - 0.5) * 2.0
    weft = 1.0 - np.abs(((uu * L.wu / 0.024) % 1.0) - 0.5) * 2.0
    cell = (((uu * L.wu / 0.024).astype(np.int64) + (vv * L.wv / 0.013).astype(np.int64)) % 2).astype(np.float32)
    ridge = np.clip(warp * 1.2, 0, 1) * (0.72 + 0.40 * cell) * 0.62 + np.clip(weft * 0.8, 0, 1) * (0.55 + 0.30 * (1 - cell)) * 0.38
    L.shade(ridge - 0.45, 0.45)
    L.add_h(ridge * 0.0024, 1.0)
    L.rg(np.clip(0.55 + 0.5 * ridge, 0, 1), 0.74, 1.0)
    top = 1.0 - sstep(0.34, 0.50, vv)
    L.mix(top * (0.25 + 0.55 * L.noise(0.9, seed + 1, octaves=3)), WEB_FADE, 0.6)
    dust = sstep(0.55, 0.88, L.noise(5.0, seed + 2, octaves=3))
    L.mix(dust * 0.65, DUST, 0.5)
    L.rg(dust, 0.88, 0.5)
    L.add_h(dust * 0.2, 0.0005)
    for e in (0.455, 0.975):
        m = 1.0 - sstep(0.0, 0.03, np.abs(vv - e))
        L.mix(m * 0.55, GRIME, 0.5)
        L.rg(m, 0.88, 0.5)
    rng = np.random.default_rng(seed + 3)
    for i in range(70):                                         # frayed fibres at the edges
        e = 0.455 if i % 2 else 0.975
        u0 = rng.random()
        m = L.streak(u0, e + rng.normal(0, 0.008), u0 + rng.normal(0, 0.05), e + rng.normal(0, 0.012), 0.0016, seed + 70 + i)
        L.mix(m * 0.6, WEB_FADE, 0.6)
        L.add_h(m, 0.0008)


# ---------------------------------------------------------------- build
def build(directory):
    tex = Tex()
    world = dict(dims.LANE_WORLD)
    feats, wall_v = [], (0.17, 0.53, 0.58, 0.90)
    fj = os.path.join(HERE, "features.json")
    if os.path.isfile(fj):
        with open(fj, "r", encoding="utf-8") as f:
            data = json.load(f)
        feats = data.get("features", [])
        world.update({k: tuple(v) for k, v in (data.get("world") or {}).items()})
        wall_v = tuple(data.get("wall_v") or wall_v)
    holes = [f for f in feats if f["kind"] == "hole"]

    pl = tex.lane("plastic", 2.0, 0.4)
    pl.fill(VOID)
    n = pl.noise(8.0, 991, octaves=3)
    pl.shade(n - 0.5, 0.6)
    pl.rg(np.clip(0.5 + n * 0.6, 0, 1), 0.66, 1.0)
    pl.add_h((n - 0.5) * 0.0008, 1.0)

    li = tex.lane("shellin", *world["shellin"])
    paint_orange(li, 11, holes=holes, ribs=RIPLE, mud=0.85)
    lo = tex.lane("shellout", *world["shellout"])
    paint_orange(lo, 12, holes=holes, ribs=RIPLE, mud=1.0, outer=True)
    lw = tex.lane("shellwall", world["shellwall"][0], world["shellwall"][1], mirror=True)
    paint_orange(lw, 13, holes=holes, mud=0.7, wall=True, wall_v=wall_v)
    uu, vv = lw.grid()
    a, b, c, d = wall_v
    fillet = 1.0 - sstep(a * 0.30, a, vv)
    lw.mix(fillet * 0.8, ORANGE_GRIME, 0.75)
    lw.rg(fillet, 0.88, 0.7)
    lw.mix(sstep(c, min(1.0, c + 0.12), vv) * 0.4, ORANGE_DIRT, 0.6)
    lipm = lw.band("v", b - 0.04, c, 0.4)
    lw.mix(lipm * 0.5, ORANGE_LIT, 0.6)
    lw.rg(lipm, 0.40, 0.6)
    rng = np.random.default_rng(5)
    for i in range(36):                                          # dirt sags down the walls
        u0 = rng.random()
        v0, v1 = (b * 0.96, a * 0.5) if i % 2 else (c + 0.03, 0.99)
        m = lw.streak(u0, v0, u0 + rng.normal(0, 0.006), v1, 0.008 + 0.014 * rng.random(), 300 + i)
        lw.mix(m * 0.45, ORANGE_DIRT if i % 2 else MUD, 0.5)
        lw.rg(m, 0.88, 0.5)

    rim = tex.lane("rim", world["rim"][0], world["rim"][1])
    paint_steel(rim, 21)
    paint_welds(rim, feats, styles=("frame", "eye"))
    ribs = tex.lane("ribs", *world["ribs"])
    paint_steel(ribs, 22, dirt_v=0.80)
    paint_welds(ribs, feats)
    run = tex.lane("runners", *world["runners"])
    paint_steel(run, 23, dirt_v=0.78)
    paint_welds(run, feats)
    uu, vv = run.grid()
    pol = (1.0 - sstep(0.02, 0.12, np.abs(vv - 0.75))) * np.clip(1.0 - sstep(0.5, 0.9, np.abs(uu - 0.5) * 2.0), 0, 1)
    run.mix(pol * 0.8, STEEL_BRIGHT, 1.0)
    run.rg(pol, 0.18, 0.9)
    run.mt(pol, 1.0, 1.0)
    run.add_h(pol * 0.5, -0.0010)
    for i in range(34):
        u0 = rng.random()
        m = run.streak(u0, 0.75 + rng.normal(0, 0.015), u0 + rng.normal(0, 0.02), 0.75 + rng.normal(0, 0.015), 0.0016, 500 + i)
        run.mix(m * 0.6, C(STEEL_BRIGHT, 1.05), 1.0)
    mud = sstep(0.35, 0.62, run.noise(2.2, 24, octaves=3)) * (1.0 - pol)
    run.mix(mud * 0.75, MUD, 0.6)
    run.rg(mud, 0.92, 0.6)
    run.mt(mud, 0.02, 0.85)

    fit = tex.lane("fittings", *world["fittings"])
    paint_steel(fit, 25, spangle=0.75, dirt_v=0.85, plain=True)
    def rect_mask(u0, u1, v0, v1):
        uu, vv = fit.grid()
        return ((uu > u0) & (uu < u1) & (vv > v0) & (vv < v1)).astype(np.float32)

    for key, dull in (("ring", 0.0), ("ringb", 0.0), ("sleeve", 0.0), ("bolt", 0.0)):
        u0, u1, v0, v1 = dims.FIT[key]
        m = rect_mask(u0 + 0.004, u1 - 0.004, v0 + 0.02, v1 - 0.02)
        dust = sstep(0.40, 0.78, fbm(fit.h, fit.w, 34, 7, 111, octaves=2)) * m
        fit.mix(dust * 0.8, GRIME, 0.7)
        fit.mix(dust * 0.5, MUD, 0.5)
        fit.rg(dust, 0.90, 0.7)
        fit.mt(dust, 0.02, 0.85)
        rust = np.clip(fbm(fit.h, fit.w, 80, 8, 131, octaves=2) - 0.66, 0, 1) * 3.0 * m
        fit.mix(rust, RUST, 0.65)
        fit.rg(rust, 0.92, 0.6)
        fit.mt(rust, 0.0, 0.9)
        fit.add_h(dust * 0.4, 0.0006)

    for key, col, rust in (("tab", PAINT, 0.35), ("buckle", PAINT, 0.5)):
        u0, u1, v0, v1 = dims.FIT[key]
        m = rect_mask(u0 + 0.004, u1 - 0.004, v0 + 0.02, v1 - 0.02)
        fit.mix(m, col, 1.0)
        fit.rg(m, 0.62, 1.0)
        fit.mt(m, 0.0, 1.0)
        rng2 = np.random.default_rng(97 + int(u0 * 100))
        spots = np.clip(fbm(fit.h, fit.w, 90, 6, 61, octaves=2) - 0.62, 0, 1) * 2.4 * m * rust
        fit.mix(spots, RUST, 0.7)
        fit.rg(spots, 0.9, 0.6)
        torn = (1.0 - sstep(0.0, 0.012, np.abs(vv - v0))) * 0.0
        fit.mix(spots * 0.5, C(RUST, 0.7), 0.5)
    u0, u1, v0, v1 = dims.FIT["plate"]
    plate_m = rect_mask(u0 + 0.003, u1 - 0.003, v0 + 0.01, v1 - 0.01)
    fit.mix(plate_m, PLATE, 0.9)
    fit.rg(plate_m, 0.58, 0.8)
    fit.mt(plate_m, 0.0, 0.9)
    streak_r = np.clip(fbm(fit.h, fit.w, 8, 40, 71, octaves=2) - 0.55, 0, 1) * 2.0 * plate_m
    fit.mix(streak_r, RUST, 0.45)
    fit.rg(streak_r, 0.86, 0.6)

    for f in feats:
        if f["kind"] == "plate" and f["lane"] == "fittings":
            pu, pv = f.get("pu", fit.pu), f.get("pv", fit.pv)
            u0, u1 = f["u"] - f["su"], f["u"] + f["su"]
            v0, v1 = f["v"] - f["sv"], f["v"] + f["sv"]
            uu, vv = fit.grid()
            plate = ((uu > u0) & (uu < u1) & (vv > v0) & (vv < v1)).astype(np.float32)
            fit.mix(plate * 0.35, C(STEEL, 0.94), 1.0)
            fit.rg(plate, 0.50, 0.6)
            for k in range(1, 4):                                # pressed ribs + a raised top edge
                vv0 = v0 + (v1 - v0) * k / 4.0
                m = fit.band("v", vv0 - 0.010, vv0 + 0.010, 0.5) * plate
                fit.add_h(m, 0.0018)
                fit.mix(m * 0.25, C(STEEL_BRIGHT, 0.98), 1.0)
            top = fit.band("v", v1 - 0.030, v1, 0.4) * plate
            fit.add_h(top, 0.0022)
            for uu_ in (u0 + 0.06 * (u1 - u0), u1 - 0.06 * (u1 - u0)):
                for vv_ in (v0 + 0.18 * (v1 - v0), v1 - 0.30 * (v1 - v0)):
                    m = fit.disc(uu_, vv_, 0.013, soft=0.35, pu=pu, pv=pv)
                    fit.add_h(m, 0.0016)
                    fit.mix(m * 0.6, C(STEEL_DARK, 0.8), 1.0)
                    fit.rg(m, 0.45, 0.8)
        if f["kind"] == "grip" and f["lane"] == "fittings":
            hu0, hu1, hv0, hv1 = dims.FIT["handle"]
            m = rect_mask(hu0 + 0.004, hu1 - 0.004, hv0 + 0.02, hv1 - 0.02)
            fit.mix(m, PAINT, 0.92)
            fit.rg(m, 0.55, 0.9)
            fit.mt(m, 0.0, 0.95)
            scuff = np.clip(fbm(fit.h, fit.w, 70, 5, 83, octaves=2) - 0.55, 0, 1) * 2.2 * m
            fit.mix(scuff * 0.5, C(PAINT, 2.6), 0.6)
            m = fit.ellipse(f["u"], f["v"], 0.30 * (f.get("su", 0.44)), 0.55 * (f.get("sv", 0.28)), soft=0.9)
            fit.mix(m * 0.5, STEEL_BRIGHT, 0.9)
            fit.rg(m, 0.26, 0.8)
            fit.add_h(m * 0.4, -0.0008)

    web = tex.lane("webbing", *world["webbing"])
    paint_webbing(web, 31)
    for f in feats:
        if f["kind"] != "strap":
            continue
        u0, span = f["u"], f["w"]
        for ue in (u0 + 0.011, u0 + span - 0.011):               # box-X stitching at both ends
            for row in (0.09, 0.30):
                for k in range(8):
                    m = web.disc(ue, row + k * 0.026, 0.005, soft=0.5)
                    web.mix(m * 0.7, WEB_FADE, 0.8)
                    web.add_h(m, 0.0010)
        mb = web.disc(f["buckle"], 0.20, 0.055, soft=0.85)
        web.mix(mb * 0.3, GRIME, 0.5)
        web.rg(mb, 0.86, 0.5)

    tex.write(directory)
    return directory
