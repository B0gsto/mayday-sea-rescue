"""M_Kit_TriageTags: procedural PBR maps for T_TriageTags_Kit_* (six card faces, eyelet ring, wire tie)."""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(HERE, "../../../tools/blender"))
import dims
import font
import pbrmaps

SIZE = dims.SIZE
INSET = dims.INSET

BASE = {"Red": (0.835, 0.170, 0.180), "Yellow": (0.950, 0.760, 0.055), "Green": (0.175, 0.620, 0.255)}
INK = (0.055, 0.058, 0.062)
PAPER = (0.855, 0.850, 0.815)
STEEL = (0.600, 0.615, 0.625)
STEEL_BRIGHT = (0.790, 0.800, 0.805)
STEEL_DARK = (0.300, 0.315, 0.330)
RUST = (0.380, 0.245, 0.170)
SALT = (0.860, 0.855, 0.820)
GRIME = (0.150, 0.140, 0.120)
STOCK = (0.430, 0.455, 0.435)
EX, EY = dims.EYE[0] * 1000.0, dims.EYE[1] * 1000.0
HOLE_MM = dims.HOLE_R * 1000.0


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


class Tex:
    def __init__(self):
        n = SIZE
        self.n = n
        self.alb = np.zeros((n, n, 3), np.float32)
        self.hgt = np.zeros((n, n), np.float32)
        self.rgh = np.full((n, n), 0.55, np.float32)
        self.met = np.zeros((n, n), np.float32)
        self.sig = np.zeros((n, n), bool)
        self.cov = np.ones((n, n), bool)
        self.pu = np.full((n, n), 180.0, np.float32)
        self.pv = np.full((n, n), 180.0, np.float32)

    def lane(self, name, wu, wv):
        return Lane(self, name, float(wu), float(wv))

    def write(self, directory):
        os.makedirs(directory, exist_ok=True)
        met = (self.met >= 0.5).astype(np.float32)
        alb = pbrmaps.clamp_albedo(np.clip(self.alb, 0.0, 1.0), met)
        rgh = np.clip(self.rgh, 0.03, 1.0)
        gy, gx = np.gradient(self.hgt.astype(np.float32))
        nx, ny, nz = -gx * self.pu, gy * self.pv, np.ones_like(self.hgt)
        ln = np.sqrt(nx * nx + ny * ny + nz * nz)
        nor = np.stack([nx / ln, ny / ln, nz / ln], axis=2) * 0.5 + 0.5
        alb_w, rgh_w = pbrmaps.wet(alb, rgh, darken=0.25, gloss=0.36)
        idx = pbrmaps.dilate_index(self.cov, 4)
        maps = {("ALB", False): pbrmaps.pad(alb, idx, (0.5, 0.5, 0.5)),
                ("NOR", False): pbrmaps.pad(nor, idx, (0.5, 0.5, 1.0)),
                ("RGH", False): pbrmaps.pad(rgh, idx, 0.6),
                ("MET", False): pbrmaps.pad(met, idx, 0.0),
                ("ALB", True): pbrmaps.pad(alb_w, idx, (0.5, 0.5, 0.5)),
                ("RGH", True): pbrmaps.pad(rgh_w, idx, 0.6)}
        for (kind, wet), arr in maps.items():
            stem = "T_TriageTags_Kit_%s%s" % (kind, "_Wet" if wet else "")
            pbrmaps.write_png(os.path.join(directory, stem + ".png"), arr)
        sig = pbrmaps.pad(self.sig.astype(np.float32), idx, 0.0)
        pbrmaps.write_png(os.path.join(HERE, "signal_mask.png"), (sig > 0.5).astype(np.float32))
        return directory


class Lane:
    def __init__(self, tex, name, wu, wv):
        self.t = tex
        self.name = name
        u0, v0, u1, v1 = dims.LANES[name]
        self.r0 = int(round((1.0 - v1) * tex.n))
        self.r1 = int(round((1.0 - v0) * tex.n))
        self.c0 = int(round(u0 * tex.n))
        self.c1 = int(round(u1 * tex.n))
        self.h = self.r1 - self.r0
        self.w = self.c1 - self.c0
        self.wu, self.wv = max(wu, 1e-3), max(wv, 1e-3)
        self.pu = self.w / self.wu
        self.pv = self.h / self.wv
        sl = (slice(self.r0, self.r1), slice(self.c0, self.c1))
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

    def noise(self, feat, seed, octaves=4, sv=1.0):
        return fbm(self.h, self.w, max(1, int(feat * self.wu / 10.0)), max(1, int(feat * self.wv * sv / 10.0)),
                   seed, octaves)

    def rect(self, u0, u1, v0, v1):
        uu, vv = self.grid()
        return ((uu >= u0) & (uu <= u1) & (vv >= v0) & (vv <= v1)).astype(np.float32)

    def disc(self, u, v, r, soft=0.45):
        uu, vv = self.grid()
        d = np.sqrt(((uu - u) * self.wu) ** 2 + ((vv - v) * self.wv) ** 2)
        return 1.0 - sstep(r * (1.0 - soft), r * (1.0 + soft), d)

    def ellipse(self, u, v, ru, rv, soft=0.45):
        uu, vv = self.grid()
        d = np.sqrt(((uu - u) * self.wu / ru) ** 2 + ((vv - v) * self.wv / rv) ** 2)
        return 1.0 - sstep(1.0 - soft, 1.0 + soft, d)

    def streak(self, u0, v0, u1, v1, w, seed, soft=0.6):
        uu, vv = self.grid()
        out = np.zeros((self.h, self.w), np.float32)
        n = max(3, int(math.hypot((u1 - u0) * self.wu, (v1 - v0) * self.wv) / 2.0))
        rng = np.random.default_rng(seed)
        for i in range(n):
            t = i / float(n - 1)
            du = (uu - (u0 + (u1 - u0) * t + rng.normal(0, 0.002))) * self.wu
            dv = (vv - (v0 + (v1 - v0) * t + rng.normal(0, 0.002))) * self.wv
            out = np.maximum(out, 1.0 - sstep(w * (1 - soft), w * (1 + soft), np.sqrt(du * du + dv * dv)))
        return out

    def fill(self, col):
        self.A[:] = col
        return self

    def mix(self, m, col, k=1.0):
        mm = m[..., None] if m.ndim == 2 else m
        self.A[:] = self.A * (1.0 - mm * k) + np.asarray(col, np.float32) * (mm * k)
        return self

    def shade(self, m, k):
        self.A[:] *= (1.0 + (m[..., None] if m.ndim == 2 else m) * k)
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

    def px(self, x_mm, y_mm):
        c = INSET + ((x_mm / 200.0) + 0.5) * (self.w - 2 * INSET)
        r = INSET + (1.0 - ((y_mm / 120.0) + 0.5)) * (self.h - 2 * INSET)
        return int(round(r)), int(round(c))

    def text(self, s, x_mm, y_top_mm, scale, col, track=0):
        r, c = self.px(x_mm, y_top_mm)
        font.draw(self.A, r, c, s, scale, np.asarray(col, np.float32), track)


def paint_card(L, tag, back=False):
    base = BASE[tag]
    if back:
        base = C(base, 0.82)
    L.fill(base)
    mott = L.noise(0.10, 10 + len(tag), octaves=3)
    L.shade(mott - 0.5, 0.17)
    fleck = L.noise(1.30, 20 + len(tag), octaves=3)
    L.mix(np.clip(fleck - 0.70, 0, 1) * 1.6, C(base, 1.16), 0.55)
    fine = L.noise(5.0, 30 + len(tag), octaves=3)
    L.add_h(fine - 0.5, 0.0009)
    L.rg(np.clip(0.45 + mott * 0.4, 0, 1), 0.50, 0.5)

    uu, vv = L.grid()
    wet = sstep(0.58, 0.80, L.noise(0.16, 40 + len(tag), octaves=3))
    wet *= 0.55 + 0.45 * sstep(0.4, 0.7, L.noise(0.55, 41 + len(tag), octaves=2))
    L.mix(wet * 0.55, C(base, 0.55), 0.75)
    L.rg(wet, 0.22, 0.75)
    salt = np.clip(L.noise(0.9, 50 + len(tag), octaves=3) - 0.63, 0, 1) * 2.2
    L.mix(salt * 0.35, SALT, 0.55)
    L.rg(salt, 0.72, 0.35)
    rng = np.random.default_rng(60 + len(tag) + (9 if back else 0))
    for i in range(16):
        u0, v0 = rng.random(), rng.random()
        ang = rng.normal(0, 0.30)
        m = L.streak(u0, v0, u0 + math.cos(ang) * (0.04 + 0.10 * rng.random()),
                     v0 + math.sin(ang) * (0.04 + 0.10 * rng.random()),
                     0.20 + 0.7 * rng.random(), 300 + i + (40 if back else 0))
        L.mix(m * (0.16 + 0.18 * rng.random()), C(base, 1.35 if i % 3 else 0.55), 0.8)
        L.rg(m, 0.62, 0.4)
        L.add_h(m, -0.00035)

    def mmrect(x0, x1, y0, y1):
        return L.rect((x0 + 100.0) / 200.0, (x1 + 100.0) / 200.0, (y0 + 60.0) / 120.0, (y1 + 60.0) / 120.0)

    if back:
        panel = mmrect(16.0, 60.0, -42.0, 34.0)
        L.mix(panel, PAPER, 0.95)
        L.shade(panel * (L.noise(0.8, 70, octaves=2) - 0.5), 0.10)
        L.rg(panel, 0.42, 0.55)
        L.mix(panel * (L.noise(2.0, 71, octaves=2) - 0.5), C(PAPER, 0.96), 0.4)
    else:
        L.mix(mmrect(EX - 16.0, EX + 16.0, EY - 12.0, EY + 12.0), C(base, 0.70), 0.20)

    e_u = (EX / 200.0) + 0.5
    e_v = (EY / 120.0) + 0.5
    L.mix(L.ellipse(e_u, e_v, 11.5, 11.5, soft=0.7) * 0.30, C(base, 0.45), 0.7)
    L.mix(L.ellipse(e_u, e_v, HOLE_MM + 0.7, HOLE_MM + 0.7, soft=0.25), (0.045, 0.040, 0.038), 1.0)
    L.add_h(L.ellipse(e_u, e_v, HOLE_MM, HOLE_MM, soft=0.2), -0.0015)

    tear_u = 70.0 / 200.0 + 0.5
    strip = L.rect(tear_u, 1.0, 0.0, 1.0)
    L.mix(strip * 0.18, C(base, 0.72), 1.0)
    for k in range(22):
        v = 3.0 / 120.0 + k * (114.0 / 120.0) / 21.0
        L.mix(L.disc(tear_u, v, 0.85, soft=0.2), INK, 0.65)
    L.mix(L.rect(tear_u - 0.0015, tear_u + 0.0015, 0.0, 1.0) * 0.35, C(base, 0.55), 0.5)
    L.text("TEAR" if back else "", 72.0, 47.0, 2, C(INK, 1.0), 0)

    code = dims.CODE[tag]
    if back:
        L.text(code, -49.0, 40.0, 8, INK, 1)
        rows = (22.0, 4.0, -14.0)
        for i, (label, yy) in enumerate(zip(("P1", "P2", "P3"), rows)):
            box = L.rect((-44.0 + 100.0) / 200.0, (-26.0 + 100.0) / 200.0,
                         (yy - 13.0 + 60.0) / 120.0, (yy - 5.0 + 60.0) / 120.0)
            edge = box - L.rect((-43.0 + 100.0) / 200.0, (-27.0 + 100.0) / 200.0,
                                (yy - 12.0 + 60.0) / 120.0, (yy - 6.0 + 60.0) / 120.0)
            L.mix(edge, INK, 0.70)
            L.text(label, -42.0, yy - 5.5, 2, INK, 0)
            if dims.HAND_TICKS[tag][i]:
                for sgn in (-1, 1):
                    L.mix(L.streak((-38.0 + 100.0) / 200.0 + 0.006 * sgn, (yy - 12.0 + 60.0) / 120.0,
                                   (-38.0 + 100.0) / 200.0 - 0.006 * sgn, (yy - 6.0 + 60.0) / 120.0,
                                   0.55, 500 + i * 2 + (1 if sgn > 0 else 0)), INK, 0.95)
        L.text("S/N " + dims.SERIAL[tag], -44.0, -39.0, 2, INK, 0)
    else:
        L.text(code, -53.0, 47.0, 11, INK, 0)
        L.text(dims.WORD[tag], -58.0, -5.0, 4, INK, 0)
        L.text(dims.SERIAL[tag], 20.0, -54.0, 3, INK, 0)
        for i, on in enumerate(dims.TICKS[tag]):
            x0 = -92.0 + i * 7.0
            L.mix(L.rect((x0 + 100.0) / 200.0, (x0 + 4.6 + 100.0) / 200.0,
                         (-49.0 + 60.0) / 120.0, (-44.4 + 60.0) / 120.0) * 0.75, INK, 0.75)
            if on:
                for sg in (-1, 1):
                    L.mix(L.streak((x0 + 0.8 + 100.0) / 200.0, (-48.4 + 60.0) / 120.0,
                                   (x0 + 3.8 + 100.0) / 200.0, (-45.0 + 60.0) / 120.0,
                                   0.45, 700 + i * 2 + (1 if sg > 0 else 0)), INK, 0.95)
    edge = np.minimum(np.minimum(uu * 200.0, (1.0 - uu) * 200.0),
                      np.minimum(vv * 120.0, (1.0 - vv) * 120.0))
    rim = 1.0 - sstep(0.0, 3.2, edge)
    rimn = L.noise(2.6, 610 + len(tag) + (9 if back else 0), octaves=3)
    L.mix(rim * 0.45, C(base, 0.52), 0.75)
    L.mix(rim * np.clip(rimn - 0.46, 0, 1) * 1.8, SALT, 0.55)
    L.rg(rim, 0.80, 0.35)
    L.add_h(rim, -0.0007)
    rng2 = np.random.default_rng(810 + len(tag) + (9 if back else 0))
    for i in range(12):
        u0, v0 = rng2.random(), rng2.random()
        a = rng2.normal(0, 0.55)
        m = L.streak(u0, v0, u0 + math.cos(a) * (0.03 + 0.12 * rng2.random()),
                     v0 + math.sin(a) * (0.03 + 0.12 * rng2.random()),
                     0.35 + 0.9 * rng2.random(), 900 + i)
        L.mix(m * (0.12 + 0.20 * rng2.random()), C(base, 1.45) if i % 3 else GRIME, 0.7)
        L.rg(m, 0.55, 0.3)
    L.signal(L.rect(0.0, 1.0, 0.0, 1.0))


def paint_eyelet(L):
    L.fill(STEEL)
    uu, vv = L.grid()
    brushed = L.noise(12.0, 81, octaves=3, sv=18.0)
    L.shade(brushed - 0.5, 0.22)
    L.mix(sstep(0.68, 0.92, L.noise(0.7, 82, octaves=3)) * 0.55, C(STEEL_BRIGHT, 1.05), 1.0)
    L.mix(1.0 - sstep(0.06, 0.22, vv), STEEL_DARK, 0.75)
    L.mix(sstep(0.86, 1.0, vv) * 0.55, GRIME, 0.65)
    rust = np.clip(L.noise(1.1, 83, octaves=3, sv=3.0) - 0.62, 0, 1) * 2.0
    L.mix(rust * 0.55, RUST, 0.6)
    L.rg(rust, 0.82, 0.55)
    L.rg(np.clip(0.30 + brushed * 0.35, 0, 1), 0.34, 0.7)
    L.mt(L.rect(0.0, 1.0, 0.0, 1.0), 1.0, 1.0)
    L.add_h(brushed - 0.5, 0.0005)


def paint_wire(L):
    L.fill(STEEL)
    uu, vv = L.grid()
    core = 1.0 - np.abs(vv - 0.5) * 2.0
    L.mix(core * 0.55, C(STEEL_BRIGHT, 1.02), 1.0)
    L.mix((1.0 - sstep(0.0, 0.16, np.minimum(vv, 1.0 - vv))) * 0.8, STEEL_DARK, 0.85)
    scratch = L.noise(4.0, 91, octaves=3, sv=1.0)
    L.shade(scratch - 0.5, 0.18)
    rust = np.clip(L.noise(0.8, 92, octaves=3, sv=2.0) - 0.60, 0, 1) * 1.9
    L.mix(rust * 0.6, RUST, 0.7)
    L.rg(rust, 0.86, 0.5)
    L.rg(np.clip(0.42 + scratch * 0.2, 0, 1), 0.38, 0.8)
    L.mt(L.rect(0.0, 1.0, 0.0, 1.0), 1.0, 1.0)
    L.add_h(scratch - 0.5, 0.0003)


def build(directory):
    tex = Tex()
    stock = fbm(SIZE, SIZE, 60, 60, 5, octaves=4)
    tex.alb[:] = np.asarray(STOCK, np.float32) * (0.82 + 0.36 * stock[..., None])
    tex.rgh[:] = np.clip(0.48 + 0.22 * stock, 0.0, 1.0)
    tex.hgt[:] = (stock - 0.5) * 0.0012
    for tag in dims.TAGS:
        paint_card(tex.lane(dims.FRONT_LANE[tag], *dims.LANE_WORLD[dims.FRONT_LANE[tag]]), tag, back=False)
        paint_card(tex.lane(dims.BACK_LANE[tag], *dims.LANE_WORLD[dims.BACK_LANE[tag]]), tag, back=True)
    paint_eyelet(tex.lane("Eyelet", *dims.LANE_WORLD["Eyelet"]))
    paint_wire(tex.lane("Wire", *dims.LANE_WORLD["Wire"]))
    tex.write(directory)
    print("[maketex] T_TriageTags_Kit_* written to %s" % directory)
    return directory
