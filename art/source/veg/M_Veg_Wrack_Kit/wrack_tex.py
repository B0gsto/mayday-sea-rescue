"""M_Veg_Wrack_Kit atlas painter (PIL + numpy; system python3, like G1's atlas.py).

Paints this kit's cell of the shared marine atlas FoliageMarine / Main (art/source/materials/atlases.py): atlas UV
u 0.250..0.750, v 0.750..1.000 (2048 x 1024 px of the 4096 master, 1024 x 512 at the 2048 ship size). Every rect
of wrack_lib.RECTS is painted in metres on its own canvas (2x supersampled, LANCZOS down: antialiased edges) and
stretched to the rect's pixel size, so a circle in the paint is a circle on the mesh whatever the rect's aspect.

Content: the encrusted rock under a mat, the fringe that hangs over a rock edge, a clump of young frayed straps, a
cluster of air vesicles, the holdfast crown, and two frond cards - Fucus vesiculosus (bladder wrack: forked straps,
paired round bladders, midrib) and Ascophyllum nodosum (egg wrack: long straps, single egg-shaped pods). Painted
glossy-wet (intertidal, always damp) in the olive-to-yellow-brown wrack range of docs/05 3.1 (kelp and wrack
#4B4A26), luma inside 30..240, saturation under the 0.45 ceiling, height -> OpenGL tangent normals. The modelled
vesicles use wrack_lib.VESICLES, the same parametric spots the painter draws, so geometry and paint line up.

Other cells of the sheet are kept when an existing map is found (the kelp kit owns M_Veg_Kelp), else left flat.

usage: python3 art/source/veg/M_Veg_Wrack_Kit/wrack_tex.py [--master 4096] [--ship 2048] [--out DIR] [--preview P]
"""
import argparse
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(GAME, "tools/blender"))
import common  # noqa: E402
import wrack_lib as L  # noqa: E402

ASSET = "M_Veg_Wrack_Kit"
SET_NAME, SET_SET = "FoliageMarine", "Main"
MASTER, SHIP = 4096, 2048
SS = 2                                                        # canvas supersample (draw 2x, resize down)

# ---------------------------------------------------------------------------------------------------- palette
OLIVE = (66, 63, 35)              # #423F23 mature Fucus olive-brown (docs/05 kelp and wrack #4B4A26)
OLIVE_DEEP = (42, 41, 24)
OLIVE_PALE = (98, 92, 52)
GOLD = (118, 104, 48)             # young growth, yellow-olive
STRAW = (148, 136, 90)            # bleached, frayed tips
POD_SKIN = (96, 90, 46)
ENCRUST = (132, 128, 116)
CORALLINE = (112, 92, 88)
ROCK_WET = (64, 63, 61)           # docs/05 wet granite #4E4C49, a little darker under weed
SILT = (88, 82, 66)
REDWEED = (100, 66, 62)


def smooth(e0, e1, x):
    """smoothstep that takes numpy arrays (wrack_lib.smooth is scalar-only)."""
    t = np.clip((np.asarray(x, np.float32) - e0) / max(e1 - e0, 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def jit(c, rng, amt=9):
    k = rng.uniform(-amt, amt)
    return tuple(int(max(0, min(255, v + k + rng.uniform(-amt, amt) * 0.4))) for v in c)


# ---------------------------------------------------------------------------------------------------- noise
def pnoise(h, w, cy, cx, seed, octaves=4, gain=0.55):
    """Band-limited smooth noise 0..1, periodic in both axes (FFT), like kelp_tex's pnoise."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    out = np.zeros((h, w), np.float32)
    amp, tot, cyk, cxk = 1.0, 0.0, float(cy), float(cx)
    for _ in range(octaves):
        spec = np.fft.fft2(rng.standard_normal((h, w)))
        k = np.sqrt((fy / max(cyk, 0.5)) ** 2 + (fx / max(cxk, 0.5)) ** 2)
        v = np.real(np.fft.ifft2(spec * np.exp(-(k ** 2) / 2.0)))
        out += amp * (v - v.mean()) / (v.std() + 1e-6)
        tot += amp
        amp *= gain
        cyk *= 2
        cxk *= 2
    return np.clip(0.5 + 0.19 * out / tot * 4.0, 0.0, 1.0)


def normal_from_height(hgt, strength):
    """OpenGL tangent normal from a height array (row 0 = image top = v max)."""
    gy, gx = np.gradient(hgt)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(hgt)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return np.clip((n * 0.5 + 0.5) * 255.0, 0, 255).astype(np.uint8)


def mottle(col, seed, amt=0.16, fine=0.07):
    """Per-pixel organic variation on a painted rect's colour (coarse patches + fine grain)."""
    h, w = col.shape[:2]
    p = pnoise(h, w, 6, 5, seed, 3)
    q = pnoise(h, w, 40, 34, seed + 1, 2)
    k = 1.0 + amt * (p - 0.5) * 2.0 + fine * (q - 0.5) * 2.0
    return col * k[..., None]


def grain(col, seed, amt=0.10):
    """High-frequency per-pixel grain (rock, silt): the mottle noise alone is too soft at 2048+."""
    h, w = col.shape[:2]
    a = pnoise(h, w, 90, 74, seed, 2)
    b = pnoise(h, w, 150, 130, seed + 1, 1)
    return col * (1.0 + amt * (a - 0.5) * 2.0 + amt * 0.7 * (b - 0.5) * 2.0)[..., None]


def shade_along_u(col, base_ao=0.62, tip_lift=0.12):
    h, w = col.shape[:2]
    t = np.linspace(0, 1, w, dtype=np.float32)[None, :].repeat(h, 0)
    return col * ((base_ao + (1 - base_ao) * smooth(0.0, 0.45, t)) * (1 + tip_lift * smooth(0.5, 1.0, t)))[..., None]


# ---------------------------------------------------------------------------------------------------- canvas
class Rect:
    """One rect's canvases, painted in metres of the rect's own surface (origin bottom-left, x along u, y along v).
    Supersampled SS x; finish() resizes down to the rect's master pixel size."""

    def __init__(self, name, px):
        self.name = name
        self.w, self.h = px                              # master px
        self.cw, self.ch = px[0] * SS, px[1] * SS
        self.mx, self.my = 1.0, 1.0
        self.col = Image.new("RGB", (self.cw, self.ch), (26, 26, 24))
        self.alpha = Image.new("L", (self.cw, self.ch), 0)
        self.ht = Image.new("L", (self.cw, self.ch), 0)
        self.rou = Image.new("L", (self.cw, self.ch), 128)
        self.dc, self.da, self.dh, self.dr = (ImageDraw.Draw(x) for x in (self.col, self.alpha, self.ht, self.rou))
        self.grow = 0.0012                               # metres the alpha / height mask is drawn wider than colour

    def metres(self, mx, my):
        self.mx, self.my = mx, my

    def px(self, x, y):
        return (x / self.mx * self.cw, self.ch - y / self.my * self.ch)

    def poly(self, pts, colour, height, alpha=255, rough=None, wide=None):
        p = [self.px(*q) for q in pts]
        self.dc.polygon(p, fill=colour)
        if wide is not None:                             # alpha trap: a copy of the shape grown by `wide` metres
            cx = sum(q[0] for q in pts) / len(pts)
            cy = sum(q[1] for q in pts) / len(pts)
            q = []
            for x, y in pts:
                dx, dy = x - cx, y - cy
                d = math.hypot(dx, dy) or 1.0
                q.append((x + dx / d * wide, y + dy / d * wide))
            self.da.polygon([self.px(*t) for t in q], fill=alpha)
            self.dh.polygon([self.px(*t) for t in q], fill=height)
        else:
            self.da.polygon(p, fill=alpha)
            self.dh.polygon(p, fill=height)
        if rough is not None:
            self.dr.polygon(p, fill=rough)

    def ellipse(self, cx, cy, rx, ry, colour, height, alpha=255, rough=None, ang=0.0):
        n = 20
        pts = []
        for k in range(n):
            a = 2 * math.pi * k / n
            x, y = math.cos(a) * rx, math.sin(a) * ry
            pts.append((cx + x * math.cos(ang) - y * math.sin(ang), cy + x * math.sin(ang) + y * math.cos(ang)))
        self.poly(pts, colour, height, alpha, rough)

    def strip(self, pts, widths, colour, height, alpha=255, rough=None, trap=True):
        """A stroked polygon along a centreline (pts metres, widths half width per point). `trap`: draw the alpha
        mask a hair wider than the colour so thin straps stay opaque after the downscale."""
        up, dn = [], []
        for i, (x, y) in enumerate(pts):
            dx = pts[min(i + 1, len(pts) - 1)][0] - pts[max(i - 1, 0)][0]
            dy = pts[min(i + 1, len(pts) - 1)][1] - pts[max(i - 1, 0)][1]
            n = math.hypot(dx, dy) or 1.0
            nx, ny = -dy / n, dx / n
            up.append((x + nx * widths[i], y + ny * widths[i]))
            dn.append((x - nx * widths[i], y - ny * widths[i]))
        self.poly(up + dn[::-1], colour, height, alpha, rough) if not trap else \
            self._strip_trap(up, dn, widths, colour, height, alpha, rough)

    def _strip_trap(self, up, dn, widths, colour, height, alpha, rough):
        """Colour at the true width; alpha and height a hair wider (no half-alpha strap edges on screen)."""
        self.poly(up + dn[::-1], colour, height, alpha, rough)
        g = self.grow
        self.da.polygon([self.px(*q) for q in up + dn[::-1]], fill=alpha)
        up2, dn2 = [], []
        for i in range(len(up)):
            wx = up[i][0] - dn[i][0]
            wy = up[i][1] - dn[i][1]
            d = math.hypot(wx, wy) or 1.0
            up2.append((up[i][0] + wx / d * g, up[i][1] + wy / d * g))
            dn2.append((dn[i][0] - wx / d * g, dn[i][1] - wy / d * g))
        self.da.polygon([self.px(*q) for q in up2 + dn2[::-1]], fill=alpha)
        self.dh.polygon([self.px(*q) for q in up2 + dn2[::-1]], fill=height)

    def finish(self):
        col = np.asarray(self.col.resize((self.w, self.h), Image.LANCZOS), np.float32)
        al = np.asarray(self.alpha.resize((self.w, self.h), Image.LANCZOS), np.float32) / 255.0
        ht = np.asarray(self.ht.resize((self.w, self.h), Image.LANCZOS), np.float32) / 255.0
        ro = np.asarray(self.rou.resize((self.w, self.h), Image.LANCZOS), np.float32) / 255.0
        return col, np.clip(al, 0, 1), ht, ro


# ---------------------------------------------------------------------------------------------------- rect painters
def paint_mat(px, seed):
    """The rock under and around a mat: wet granite joint blocks with dark seams, coralline crust, barnacles,
    silt and weed at the rim, and the dark holdfast / root mass in the middle. World footprint 1.1 x 1.1 m
    (planar projection: a world circle is a painted circle here)."""
    rng = random.Random(seed)
    r = Rect("Mat", px)
    r.metres(*L.RECT_M["Mat"])
    mx, my = r.mx, r.my
    cx, cy, rad = mx / 2.0, my / 2.0, mx * 0.5

    def spot(rmin, rmax):
        a = rng.uniform(0, 2 * math.pi)
        rr = math.sqrt(rng.uniform(rmin ** 2, rmax ** 2)) * rad
        return cx + math.cos(a) * rr, cy + math.sin(a) * rr

    def quad(x, y, s, ang, grow=0.0):
        pts = []
        for k in range(4):
            a = ang + 2 * math.pi * k / 4 + rng.uniform(-0.16, 0.16)
            rr = s * rng.uniform(0.55, 1.0) + grow
            pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
        return pts

    r.poly([(0, 0), (mx, 0), (mx, my), (0, my)], lerp(ROCK_WET, OLIVE_DEEP, 0.16), 108, 255, rough=158)
    for k in range(58):                                  # granite joint slabs with dark seams
        x, y = spot(0, 1.02)
        s = rng.uniform(0.07, 0.24)
        ang = rng.uniform(0, math.pi)
        r.poly(quad(x, y, s, ang, 0.007), lerp(ROCK_WET, OLIVE_DEEP, 0.62), 46, 255, rough=178)
        r.poly(quad(x, y, s, ang), jit(lerp(ROCK_WET, (86, 84, 80), rng.uniform(0.0, 1.0)), rng, 11),
               rng.randint(96, 142), 255, rough=rng.randint(140, 175))
    for k in range(90):                                  # fissures
        x, y = spot(0.02, 1.0)
        ang = rng.uniform(0, math.pi)
        ln = rng.uniform(0.05, 0.28)
        r.strip([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)],
                [rng.uniform(0.003, 0.010)] * 2, lerp(ROCK_WET, (30, 30, 28), 0.62), 28, 215, rough=180)
    for k in range(190):                                 # holdfast / root mass in the middle
        x, y = spot(0, 0.50)
        s = rng.uniform(0.008, 0.032) * (1.0 - 0.35 * math.hypot(x - cx, y - cy) / rad)
        r.ellipse(x, y, s, s * rng.uniform(0.7, 1.25), jit(lerp(OLIVE_DEEP, OLIVE, rng.uniform(0.15, 0.9)), rng, 9),
                  rng.randint(120, 210), 255, rough=rng.randint(60, 112))
    for k in range(40):                                  # holdfast stubs and stolons
        x, y = spot(0, 0.58)
        a = rng.uniform(0, 2 * math.pi)
        ln = rng.uniform(0.015, 0.055)
        r.strip([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], [0.0055, 0.0022],
                lerp(OLIVE_DEEP, OLIVE, 0.4), 170, 255, rough=rng.randint(62, 105))
    for k in range(60):                                  # coralline crust, mostly at the rim
        x, y = spot(0.45, 1.0)
        s = rng.uniform(0.004, 0.015)
        r.ellipse(x, y, s, s, jit(lerp(CORALLINE, ROCK_WET, rng.uniform(0.2, 0.6)), rng, 14), rng.randint(95, 150),
                  255, rough=rng.randint(105, 145))
    for k in range(65):                                  # barnacles: pale plate, dark socket, faint rim
        x, y = spot(0.30, 1.0)
        s = rng.uniform(0.004, 0.009)
        r.ellipse(x, y, s * 1.3, s, jit(lerp(ENCRUST, ROCK_WET, rng.uniform(0.15, 0.55)), rng, 12),
                  rng.randint(140, 205), 255, rough=rng.randint(95, 135))
        r.ellipse(x, y, s * 0.85, s * 0.66, jit(lerp(ENCRUST, (44, 44, 42), 0.8), rng, 10), rng.randint(50, 100))
    for k in range(46):                                  # silt pockets in the crevices
        x, y = spot(0.2, 1.0)
        s = rng.uniform(0.012, 0.05)
        r.ellipse(x, y, s, s * rng.uniform(0.45, 0.85), jit(lerp(SILT, ROCK_WET, rng.uniform(0.1, 0.5)), rng, 12),
                  rng.randint(80, 120), 255, rough=rng.randint(150, 185))
    for k in range(24):                                  # weed tufts and red weed at the rim
        x, y = spot(0.70, 1.0)
        col = OLIVE if rng.random() < 0.6 else (REDWEED if rng.random() < 0.5 else GOLD)
        for j in range(rng.randint(2, 5)):
            ang = rng.uniform(0, math.pi)
            ln = rng.uniform(0.015, 0.05)
            r.strip([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)], [0.006, 0.0025],
                    jit(col, rng, 12), rng.randint(115, 185), 255, rough=rng.randint(70, 115))
    col, al, ht, ro = r.finish()
    col = grain(mottle(col, seed + 3, 0.13, 0.10), seed + 4, 0.14)
    ht = ht * 0.9 + 0.1 * pnoise(ht.shape[0], ht.shape[1], 60, 48, seed + 5, 2)
    return col, al, ht, ro


def paint_fringe(px, seed):
    """The wrack hanging over a rock edge: encrusted mat edge along the top (opaque), a tangled fringe of straps
    with bladders hanging below it (alpha). 1.6 x 0.2 m band, u tiles along the rim."""
    rng = random.Random(seed)
    r = Rect("Fringe", px)
    r.metres(*L.RECT_M["Fringe"])
    mx, my = r.mx, r.my
    r.poly([(0, my * 0.62), (mx, my * 0.62), (mx, my), (0, my)], lerp(ROCK_WET, OLIVE_DEEP, 0.30), 112, 255, rough=162)
    for k in range(150):                                 # granite slabs along the top
        x, y = rng.uniform(0, mx), rng.uniform(my * 0.62, my)
        s = rng.uniform(0.02, 0.06)
        r.ellipse(x, y, s, s * rng.uniform(0.4, 0.7), jit(lerp(ROCK_WET, OLIVE_DEEP, rng.uniform(0.2, 0.6)), rng, 12),
                  rng.randint(85, 135), 255, rough=rng.randint(145, 180))
    for k in range(48):                                  # encrustation, small and dull
        x, y = rng.uniform(0, mx), rng.uniform(my * 0.62, my)
        s = rng.uniform(0.0035, 0.010)
        r.ellipse(x, y, s, s * rng.uniform(0.6, 1.0), jit(lerp(ROCK_WET, ENCRUST, rng.uniform(0.1, 0.5)), rng, 12),
                  rng.randint(95, 165), 255, rough=rng.randint(100, 165))
    for k in range(60):                                  # dark weed / holdfast along the junction
        x, y = rng.uniform(0, mx), rng.uniform(my * 0.58, my * 0.80)
        s = rng.uniform(0.008, 0.028)
        r.ellipse(x, y, s, s * rng.uniform(0.5, 0.9), jit(lerp(OLIVE_DEEP, OLIVE, rng.uniform(0.15, 0.8)), rng, 11),
                  rng.randint(115, 185), 255, rough=rng.randint(70, 115))
    n = 54
    starts = []
    for k in range(n):
        x0 = mx * (k + rng.uniform(0.05, 0.95)) / n
        starts.append((x0, rng.uniform(0, 2 * math.pi)))
    for back in (True, False):                           # back layer darker/thinner, front lighter: depth
        for k, (x0, ph) in enumerate(starts):
            if (k % 3 == 0) == back:
                continue
            ln = rng.uniform(0.055, my * (0.80 if back else 0.95))
            yaw = rng.uniform(-0.55, 0.55)
            col = jit(rng.choice((OLIVE, OLIVE, OLIVE_PALE)), rng, 11)
            if back:
                col = lerp(col, OLIVE_DEEP, 0.45)
            pts, ws, segs = [], [], 6
            for i in range(segs + 1):
                t = i / segs
                x = x0 + math.sin(t * 2.6 + ph) * ln * 0.30 + yaw * t * ln
                pts.append((x, my * 0.655 - ln * t))
                ws.append(max(0.0012, (0.0095 if back else 0.0115) * (1 - 0.6 * t ** 1.5) * rng.uniform(0.8, 1.2)))
            r.strip(pts, ws, col, 112 if back else 122, 255, rough=rng.randint(78, 112))
            if not back and rng.random() < 0.4:
                r.strip(pts, [max(0.0007, w * 0.20) for w in ws], lerp(col, OLIVE_DEEP, 0.35), 148, 255, rough=98)
            if rng.random() < 0.45:                      # forked / frayed tip
                bx, by = pts[-1]
                for j in (-1, 1):
                    a = math.pi / 2 + j * rng.uniform(0.25, 0.85)
                    r.strip([(bx, by), (bx + math.cos(a) * ln * 0.22, by + math.sin(a) * ln * 0.22)],
                            [0.0045, 0.0016], lerp(col, STRAW, rng.uniform(0.1, 0.5)), 118, 255, rough=95)
            for f in (0.45, 0.72, 0.9):                  # bladders / pods down the strap
                if rng.random() < 0.3:
                    i = int(f * segs)
                    s = rng.uniform(0.0035, 0.0065)
                    sd = rng.choice((-1, 1))
                    r.ellipse(pts[i][0], pts[i][1] + sd * ws[i] * 0.5, s, s * rng.uniform(0.9, 1.4),
                              jit(OLIVE_DEEP, rng, 9), 165, 255, rough=rng.randint(55, 88))
    col, al, ht, ro = r.finish()
    col = grain(col, seed + 6, 0.13)
    col = col * (1.0 + 0.10 * (pnoise(col.shape[0], col.shape[1], 3, 3, seed + 7, 3) - 0.5)[..., None] * 2.0)
    h, w = al.shape
    v = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    u = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    al = al * (1.0 - smooth(0.97, 1.0, v)) * (0.45 + 0.55 * smooth(0.0, 0.02, u) * smooth(0.0, 0.02, 1 - u))
    return col, np.clip(al, 0, 1), ht, ro


def _strap(r, rng, mx, y0, y1, hw0, u1=0.97, bow=0.35, ph=None, col=None, height=118, rib=True, jitter=True):
    """One frond strap: a curve from the base (x ~ 0) to u1 with a bow, widening then tapering."""
    ph = rng.uniform(0, 6.28) if ph is None else ph
    col = jit(col or OLIVE, rng, 9)
    pts, ws, segs = [], [], 12
    for i in range(segs + 1):
        t = i / segs
        x = mx * (0.012 + 0.975 * u1 * t)
        y = y0 + (y1 - y0) * t + bow * math.sin(math.pi * t) * 0.35 * (y1 - y0) + 0.003 * math.sin(6.4 * t + ph)
        pts.append((x, y))
        j = rng.uniform(0.94, 1.06) if jitter else 1.0
        ws.append(hw0 * j)
    r.strip(pts, [w + 0.0013 for w in ws], lerp(OLIVE_DEEP, (26, 28, 22), 0.45), min(100, height), 255, rough=108)
    r.strip(pts, ws, col, height, 255, rough=rng.randint(80, 118))
    if rib:
        r.strip(pts, [max(0.0009, w * 0.24) for w in ws], lerp(col, OLIVE_DEEP, 0.30), height + 26, 255, rough=96)
    if rng.random() < 0.75:                              # forked tip: 2-3 apiculate lobes
        bx, by = pts[-1]
        for j in range(2 if rng.random() < 0.5 else 3):
            a = (j - 1) * rng.uniform(0.35, 0.55) + ph * 0.05
            ln = mx * rng.uniform(0.09, 0.17)
            r.strip([(bx, by), (bx + ln * math.cos(a), by + ln * math.sin(a))], [hw0 * 0.5, 0.0016],
                    lerp(col, OLIVE_PALE if rng.random() < 0.6 else GOLD, rng.uniform(0.2, 0.7)), height, 255, rough=92)
    return pts, ws


def frond_card(px, seed, kind):
    """A clump of wrack fronds on one card, base at u 0, tip at u 1: wrack_lib.FROND_M real size (a narrow card:
    the straps fill it), vesicles at wrack_lib.VESICLES (the modelled ones sit at the same spots)."""
    rng = random.Random(seed)
    r = Rect(kind, px)
    r.metres(*L.FROND_M[kind])
    mx, my = r.mx, r.my
    W = my
    bladders = kind == "Bladder"
    env = lambda t: L.frond_env(kind, t) * W * 0.5 * 0.98

    plan = [(1.0, {"Bladder": 0.001, "Egg": 0.003, "Strap": 0.000}[kind],
                  {"Bladder": 0.006, "Egg": -0.002, "Strap": 0.003}[kind], 1.0,
                  {"Bladder": 0.35, "Egg": 0.30, "Strap": 0.35}[kind])]
    if kind == "Bladder":
        plan += [(0.82, -0.004, -0.030, 0.0115, 0.30), (0.74, 0.005, 0.038, 0.0115, 0.30),
                 (0.60, 0.002, -0.020, 0.0105, 0.35), (0.52, -0.007, 0.024, 0.0100, 0.40),
                 (0.68, 0.010, 0.044, 0.0090, 0.30)]
    elif kind == "Egg":
        plan += [(0.85, -0.006, 0.034, 0.0140, 0.30), (0.76, 0.008, -0.030, 0.0130, 0.35),
                 (0.58, 0.001, 0.016, 0.0110, 0.40)]
    else:
        plan += [(0.88, -0.005, -0.024, 0.0070, 0.30), (0.78, 0.004, 0.026, 0.0068, 0.35),
                 (0.64, 0.001, -0.016, 0.0064, 0.40), (0.52, -0.006, 0.014, 0.0060, 0.45)]
    main = None
    for k, (u1, y0, y1, hw0, bow) in enumerate(plan):
        lim = env(u1) - 0.002
        y1 = max(-lim, min(lim, y1))
        col = lerp(OLIVE, OLIVE_PALE, 0.06 + 0.24 * (k > 0) + rng.uniform(-0.05, 0.05))
        if kind == "Egg":
            col = lerp(OLIVE_DEEP, OLIVE, rng.uniform(0.30, 0.85))
        if kind == "Strap":
            col = lerp(OLIVE_PALE, GOLD, rng.uniform(0.0, 0.55))
        pts, ws = _strap(r, rng, mx, y0, y1, hw0, u1=u1, bow=bow, col=col, height=120 if k == 0 else 112,
                         rib=(k == 0), jitter=(k != 0))
        if k == 0:
            main = (pts, ws)
    pts, ws = main
    # vesicles painted exactly where wrack_lib.VESICLES puts the modelled ones (on the main strap)
    segs = len(pts) - 1
    for v in L.VESICLES[kind]:
        t, share, rad = v[0], v[1], v[2]
        el = v[3] if len(v) > 3 else 1.0
        i = int(round(t * segs))
        x, y = pts[i]
        y += share * ws[i]
        ang = 0.0 if el > 1 else math.pi / 2
        r.ellipse(x, y, rad * 0.58, rad * 0.58 * el, lerp(OLIVE_DEEP, OLIVE, 0.35), 168, 255,
                  rough=rng.randint(52, 84), ang=ang)
        r.ellipse(x - rad * 0.16, y + rad * 0.18, rad * 0.16, rad * 0.13 * el, lerp(POD_SKIN, OLIVE, 0.45), 198, 255,
                  rough=64)
    col, al, ht, ro = r.finish()
    col = grain(shade_along_u(mottle(col, seed + 17, 0.10, 0.07), 0.64 if bladders else 0.60,
                              0.10 if bladders else 0.08), seed + 18, 0.05)
    h, w = al.shape
    u = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    vv = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    al = al * (0.25 + 0.75 * smooth(0, 0.03, u) * smooth(0, 0.02, np.minimum(vv, 1 - vv)))
    tatter = smooth(0.84, 1.0, u) * pnoise(h, w, 22, 20, seed + 19, 2)      # frayed, thinned tips
    al = al * (1.0 - 0.28 * tatter)
    ht = ht * np.minimum(smooth(0, 0.02, u), smooth(0, 0.02, 1 - u)) * np.minimum(smooth(0, 0.03, vv),
                                                                                smooth(0, 0.03, 1 - vv))
    return col, np.clip(al, 0, 1), ht, ro


def paint_strap(px, seed):
    """A clump of young frayed straps: bright olive, small bladders low down, tattered tips. 0.30 x 0.08 m."""
    return frond_card(px, seed, "Strap")


def paint_pod(px, seed):
    """Air vesicles for the modelled bladders and pods: damp olive skin, a pale translucent crown, epibiont
    specks. A field of overlapping eggs so every modelled vesicle finds a plain patch. 0.06 x 0.06 m."""
    rng = random.Random(seed)
    r = Rect("Pod", px)
    r.metres(*L.RECT_M["Pod"])
    mx, my = r.mx, r.my
    r.poly([(0, 0), (mx, 0), (mx, my), (0, my)], lerp(OLIVE_DEEP, OLIVE, 0.25), 96, 255, rough=62)
    for k in range(30):
        cx, cy = rng.uniform(0, mx), rng.uniform(0, my)
        rx = rng.uniform(0.008, 0.026)
        r.ellipse(cx, cy, rx, rx * rng.uniform(1.1, 1.9), jit(lerp(OLIVE, POD_SKIN, rng.uniform(0.0, 0.7)), rng, 9),
                  rng.randint(140, 210), 255, rough=rng.randint(48, 78), ang=rng.uniform(-1.5, 1.5))
    for k in range(10):                                  # epibionts, small and dull
        cx, cy = rng.uniform(0, mx), rng.uniform(0, my)
        s = rng.uniform(0.0010, 0.0022)
        r.ellipse(cx, cy, s * 1.3, s, jit(lerp(ENCRUST, ROCK_WET, rng.uniform(0.3, 0.7)), rng, 9), 170, 255,
                  rough=rng.randint(105, 145))
    col, al, ht, ro = r.finish()
    return grain(mottle(col, seed + 11, 0.10, 0.08), seed + 12, 0.07), al, ht, ro


def paint_holdfast(px, seed):
    """The crown a mat's fronds grow from: holdfast discs, knobbly brown, stubs and young shoots radiating. 0.16 m."""
    rng = random.Random(seed)
    r = Rect("Holdfast", px)
    r.metres(*L.RECT_M["Holdfast"])
    mx, my = r.mx, r.my
    r.poly([(0, 0), (mx, 0), (mx, my), (0, my)], lerp(OLIVE_DEEP, ROCK_WET, 0.30), 100, 255, rough=95)
    for k in range(90):
        cx, cy = rng.uniform(0, mx), rng.uniform(0, my)
        s = rng.uniform(0.004, 0.013)
        r.ellipse(cx, cy, s, s * rng.uniform(0.7, 1.2), jit(lerp(OLIVE_DEEP, OLIVE, rng.uniform(0.1, 0.85)), rng, 9),
                  rng.randint(110, 200), 255, rough=rng.randint(62, 108))
    for k in range(38):                                  # stubs / young shoots
        a = rng.uniform(0, 2 * math.pi)
        cx, cy = rng.uniform(0, mx), rng.uniform(0, my)
        ln = rng.uniform(0.01, 0.05)
        r.strip([(cx, cy), (cx + math.cos(a) * ln, cy + math.sin(a) * ln)], [0.0045, 0.0020],
                jit(lerp(OLIVE, GOLD, rng.uniform(0.0, 0.6)), rng, 11), rng.randint(150, 215), 255,
                rough=rng.randint(62, 100))
    for k in range(22):
        cx, cy = rng.uniform(0, mx), rng.uniform(0, my)
        s = rng.uniform(0.0025, 0.0065)
        r.ellipse(cx, cy, s * 1.3, s, jit(lerp(ENCRUST, ROCK_WET, rng.uniform(0.1, 0.5)), rng, 11), 185, 255,
                  rough=rng.randint(95, 135))
    col, al, ht, ro = r.finish()
    return grain(mottle(col, seed + 13, 0.12, 0.08), seed + 14, 0.08), al, ht, ro


# ---------------------------------------------------------------------------------------------------- sheet
def sheet(master=MASTER, seed=101):
    """(rgb 0..255, alpha 0..1, height 0..1, rough 0..1) at `master`; this kit's cell painted, the rest flat."""
    S = master
    rgb = np.zeros((S, S, 3), np.float32)
    rgb[:] = 0.35 * 255.0
    alpha = np.zeros((S, S), np.float32)
    hgt = np.zeros((S, S), np.float32)
    rough = np.full((S, S), 0.62, np.float32)
    cw = int((L.CELL[2] - L.CELL[0]) * S)
    ch = int((L.CELL[3] - L.CELL[1]) * S)

    def paste(rect, col, al, ht, ro):
        s0, t0, s1, t1 = L.RECTS[rect]
        x0 = int(round((L.CELL[0] + s0 * (L.CELL[2] - L.CELL[0])) * S))
        y1 = int(round((1.0 - (L.CELL[1] + t0 * (L.CELL[3] - L.CELL[1]))) * S))
        w, h = int(round((s1 - s0) * cw)), int(round((t1 - t0) * ch))
        rgb[y1 - h:y1, x0:x0 + w] = np.clip(col, 0, 255)
        alpha[y1 - h:y1, x0:x0 + w] = np.clip(al, 0, 1)
        hgt[y1 - h:y1, x0:x0 + w] = np.clip(ht, 0, 1)
        rough[y1 - h:y1, x0:x0 + w] = np.clip(ro, 0.05, 1.0)
        print("  painted %-13s %4dx%-5d at %d,%d" % (rect, w, h, x0, y1 - h))

    def rect_px(name):
        s0, t0, s1, t1 = L.RECTS[name]
        return (int(round((s1 - s0) * cw)), int(round((t1 - t0) * ch)))

    for name, fn in (("Mat", paint_mat), ("Strap", paint_strap), ("Pod", paint_pod), ("Holdfast", paint_holdfast),
                     ("Fringe", paint_fringe)):
        paste(name, *fn(rect_px(name), seed + sum(ord(c) * (i + 3) for i, c in enumerate(name)) % 997))
    for name, kind in (("BladderFrond", "Bladder"), ("EggFrond", "Egg")):
        paste(name, *frond_card(rect_px(name), seed + sum(ord(c) * (i + 3) for i, c in enumerate(name)) % 997, kind))
    return rgb, alpha, hgt, rough


def pad_colour(rgb, a):
    """push-pull: fill transparent texels with the average of nearby opaque colour (no dark mip fringes)."""
    levels = []
    c, w = rgb * a[..., None], a.copy()
    while min(w.shape) > 4:
        levels.append((c, w))
        h2, w2 = w.shape[0] // 2, w.shape[1] // 2
        c = c[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2, 3).sum((1, 3))
        w = w[:h2 * 2, :w2 * 2].reshape(h2, 2, w2, 2).sum((1, 3))
    fill = c / np.maximum(w, 1e-6)[..., None]
    for c, w in reversed(levels):
        up = np.repeat(np.repeat(fill, 2, 0), 2, 1)[:w.shape[0], :w.shape[1]]
        mine = c / np.maximum(w, 1e-6)[..., None]
        t = np.clip(w, 0, 1)[..., None]
        fill = mine * t + up * (1 - t)
    return fill


def polish(rgb, alpha, hgt, rough, size):
    """Shared finishing: colour padded under alpha, the 05 3.3 value / saturation window, flat NOR and RGH where
    the card is empty."""
    a = np.clip(alpha, 0, 1)
    fill = pad_colour(rgb / 255.0, (a > 0.5).astype(np.float32)) * 255.0
    rgb = np.where((a > 0.5)[..., None], rgb, fill)
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    knee = np.where(sat > 0.38, 0.38 + (sat - 0.38) * 0.32, sat)
    grey = mx[..., None]
    rgb = grey - (grey - rgb) * (knee / np.maximum(sat, 1e-3))[..., None]
    rgb = 255.0 * (np.clip(rgb, 0, 255) / 255.0) ** 0.97        # small lift so Night / Storm keep form
    rgb = np.clip(rgb, 32, 238)
    nor = normal_from_height(hgt, 15.0 * size / 4096.0)
    nor[a < 0.02] = (128, 128, 255)
    rough = np.clip(np.where(a > 0.02, rough, 0.62), 0.06, 1.0)
    return rgb, nor, rough


def maps(size):
    """(ALB RGBA u8, NOR u8, RGH u8, MET u8) at `size`."""
    rgb, alpha, hgt, rough = sheet(size)
    rgb, nor, rough = polish(rgb, alpha, hgt, rough, size)
    alb = np.dstack([rgb, np.clip(alpha, 0, 1) * 255.0]).astype(np.uint8)
    return alb, nor, (rough * 255).astype(np.uint8), np.zeros((size, size), np.uint8)


def keep_other_cells(alb, nor, rgh, size):
    """Keep whatever another kit already painted outside this cell (the kelp kit owns M_Veg_Kelp): read the ship
    map found in the usual folders and copy its pixels outside our cell over ours. Returns True when one was found."""
    cw = int((L.CELL[2] - L.CELL[0]) * size)
    ch = int((L.CELL[3] - L.CELL[1]) * size)
    x0 = int(L.CELL[0] * size)
    y0 = int((1.0 - L.CELL[3]) * size)
    keep = np.ones((size, size), bool)
    keep[y0:y0 + ch, x0:x0 + cw] = False
    for d in (common.textures_dir(ASSET), os.path.join(GAME, "assets/textures/M_Veg_FoliageMarine"),
              os.path.join(GAME, "assets/textures/M_Veg_Kelp_Kit"),
              os.path.join(GAME, "build/prod/M_Veg_Kelp_Kit/textures/M_Veg_Kelp_Kit")):
        p = os.path.join(d, "T_%s_%s_ALB.png" % (SET_NAME, SET_SET))
        if not os.path.isfile(p):
            continue
        im = Image.open(p).convert("RGBA")
        if im.size != (size, size):
            im = im.resize((size, size), Image.LANCZOS)
        old = np.asarray(im, np.uint8)
        if not (old[keep, 3] > 0).any():
            continue
        alb[keep, :3] = old[..., :3][keep]
        alb[keep, 3] = old[..., 3][keep]
        for tag, arr, mode in (("NOR", nor, "RGB"), ("RGH", rgh, "L")):
            q = os.path.join(d, "T_%s_%s_%s.png" % (SET_NAME, SET_SET, tag))
            if os.path.isfile(q):
                oi = Image.open(q).convert(mode)
                if oi.size != (size, size):
                    oi = oi.resize((size, size), Image.LANCZOS)
                arr[keep] = np.asarray(oi)[keep]
        print("[%s] kept the other cells' pixels from %s" % (ASSET, os.path.relpath(d, GAME)))
        return True
    return False


def write_all(out_dir, ship=SHIP, master=MASTER):
    import pbrmaps
    os.makedirs(out_dir, exist_ok=True)
    master_dir = os.path.join(common.out_root(), "masters")
    os.makedirs(master_dir, exist_ok=True)
    big = maps(master)
    small = [pbrmaps.downsize(a, ship) if a.shape[0] > ship else a for a in big]
    small = [s.astype(np.uint8) for s in small]
    keep_other_cells(small[0], small[1], small[2], ship)
    keep_other_cells(big[0], big[1], big[2], master)
    out = []
    for target, arrs in ((master_dir, big), (out_dir, small)):
        for tag, arr in zip(("ALB", "NOR", "RGH", "MET"), arrs):
            stem = "T_%s_%s_%s" % (SET_NAME, SET_SET, tag)
            out.append(pbrmaps.write_png(os.path.join(target, stem + ".png"), arr))
            print("  wrote", os.path.relpath(out[-1], GAME), arr.shape)
    return out


def preview(out_png, size=SHIP):
    alb, nor, rgh, met = maps(size)
    a = alb[..., 3:4].astype(np.float32) / 255.0
    ind = np.indices((size, size)).sum(0) // 64 % 2
    checker = (0.30 + ind[..., None] * 0.16) * 255.0
    img = alb[..., :3].astype(np.float32) * a + checker * (1 - a)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(out_png)
    print("preview", out_png)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--master", type=int, default=MASTER)
    ap.add_argument("--ship", type=int, default=SHIP)
    ap.add_argument("--out", default=None, help="ship map folder (default: <out-root>/textures/<Asset>)")
    ap.add_argument("--preview", default=None)
    args = ap.parse_args()
    write_all(args.out or common.textures_dir(ASSET), args.ship, args.master)
    if args.preview:
        preview(args.preview, min(2048, args.ship))


if __name__ == "__main__":
    main()
