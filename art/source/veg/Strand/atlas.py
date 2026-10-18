#!/usr/bin/env python3
"""Strand-line debris atlas (G1 strand set): T_StrandLine_Main_{ALB,NOR,RGH,MET}[_Wet], pure python3 + numpy + Pillow.

Shared by M_Veg_Strand_Shells_01 / _Wrack_01 / _Driftwood_01 / _Pebbles_01 (strandkit.py). Every cell is drawn
procedurally from the material's structure (owned, AI used: none): dried bladderwrack and serrated wrack fronds
(alpha cut), sun-bleached driftwood side grain with checks and knots plus end grain, cockle exterior / worn interior,
mussel periostracum / nacre, granite, slate, vein quartz and sandstone beach pebbles. Height per cell -> NOR (OpenGL).
Master 2048 in art/source/veg/Strand/textures/, ship 1024 in assets/textures/M_Veg_StrandLine/. Cell rects ->
cells.json (UV, v up).

usage: python3 art/source/veg/Strand/atlas.py [--master 2048] [--ship 1024]
"""
import argparse, json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
SHIP_DIR = os.path.join(GAME, "assets/textures/M_Veg_StrandLine")
MASTER_DIR = os.path.join(HERE, "textures")
STEM = "T_StrandLine_Main"
G = 8  # grid units per side

# sub-cells on an 8 x 8 grid: (col, row from the top, w, h)
CELLS = {
    "WrackA": (0, 0, 4, 2), "WrackB": (0, 2, 4, 2),
    "DriftA": (4, 0, 4, 1), "DriftB": (4, 1, 4, 1), "DriftC": (4, 2, 4, 1),
    "DriftEnd": (4, 3, 1, 1), "DriftEnd2": (5, 3, 1, 1), "DriftStub": (6, 3, 2, 1),
    "CockleOut": (0, 4, 2, 2), "CockleIn": (2, 4, 2, 2), "MusselOut": (0, 6, 2, 2), "MusselIn": (2, 6, 2, 2),
    "Granite": (4, 4, 2, 2), "Slate": (6, 4, 2, 2), "Quartz": (4, 6, 2, 2), "Sandstone": (6, 6, 2, 2),
}


# ---------------------------------------------------------------------------------------------------- noise
def vnoise(h, w, sx, sy, seed):
    r = np.random.default_rng(seed)
    g = r.random((max(2, int(h / sy) + 2), max(2, int(w / sx) + 2))).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, np.float32) / 255.0


def fbm(h, w, sx, sy, seed, octaves=4):
    out, amp, tot = np.zeros((h, w), np.float32), 1.0, 0.0
    for i in range(octaves):
        out += vnoise(h, w, max(1.0, sx / 2 ** i), max(1.0, sy / 2 ** i), seed + 31 * i) * amp
        tot += amp
        amp *= 0.5
    return out / tot


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    a, b = np.asarray(a, np.float32), np.asarray(b, np.float32)
    return a * (1 - t[..., None]) + b * t[..., None]


def speckle(h, w, size, density, seed):
    """sparse grain mask: value noise at grain size thresholded to the given area share"""
    n = vnoise(h, w, size, size, seed) * 0.75 + vnoise(h, w, size * 0.5, size * 0.5, seed + 7) * 0.25
    t = np.quantile(n, 1 - density)
    return smooth(t, t + 0.04, n)


# ---------------------------------------------------------------------------------------------------- wrack
class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.col = Image.new("RGB", (w, h), (0, 0, 0))
        self.a = Image.new("L", (w, h), 0)
        self.ht = Image.new("L", (w, h), 0)
        self.rg = Image.new("L", (w, h), 180)
        self.dc, self.da, self.dh, self.dr = (ImageDraw.Draw(self.col), ImageDraw.Draw(self.a), ImageDraw.Draw(self.ht),
                                              ImageDraw.Draw(self.rg))

    def poly(self, pts, colour, height, rough=180):
        self.dc.polygon(pts, fill=colour)
        self.da.polygon(pts, fill=255)
        self.dh.polygon(pts, fill=int(max(1, min(255, height))))
        self.dr.polygon(pts, fill=rough)

    def ellipse(self, box, colour, height, rough=180):
        self.dc.ellipse(box, fill=colour)
        self.da.ellipse(box, fill=255)
        self.dh.ellipse(box, fill=int(max(1, min(255, height))))
        self.dr.ellipse(box, fill=rough)

    def line(self, pts, colour, width, height, rough=180):
        self.dc.line(pts, fill=colour, width=width, joint="curve")
        self.da.line(pts, fill=255, width=width, joint="curve")
        self.dh.line(pts, fill=int(height), width=width, joint="curve")
        self.dr.line(pts, fill=rough, width=width, joint="curve")


def jit(c, rng, amt=8):
    k = rng.uniform(-amt, amt)
    return tuple(int(max(0, min(255, v + k + rng.uniform(-amt, amt) * 0.4))) for v in c)


def thallus(cv, rng, x, y, ang, length, width, depth, maxd, pal, serrated, bladders):
    """one dichotomous Fucus branch: flat strap with a raised midrib, paired air bladders, split or swollen tip"""
    n = 9
    pts = [(x, y)]
    a = ang
    for i in range(n):
        a += rng.gauss(0, 0.07)
        x += math.cos(a) * length / n
        y += math.sin(a) * length / n
        pts.append((x, y))
    left, right = [], []
    for i, (px, py) in enumerate(pts):
        j0, j1 = max(0, i - 1), min(n, i + 1)
        dx, dy = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
        L = math.hypot(dx, dy) or 1
        nx, ny = -dy / L, dx / L
        t = i / n
        hw = width * 0.5 * (1.0 - 0.12 * t) * (1 + rng.gauss(0, 0.04))
        if serrated:  # Fucus serratus: saw-toothed margin
            hl = hw * (1.0 + (0.22 if i % 2 else -0.05))
            hr = hw * (1.0 + (0.22 if (i + 1) % 2 else -0.05))
        else:
            hl = hr = hw
        left.append((px + nx * hl, py + ny * hl))
        right.append((px - nx * hr, py - ny * hr))
    base = jit(pal["base"], rng, 7)
    cv.poly(left + right[::-1], base, 120 + 10 * depth, 175)
    # edge darkening: the dried margin curls under
    cv.line(left, tuple(int(v * 0.72) for v in base), max(2, int(width * 0.09)), 90, 190)
    cv.line(right, tuple(int(v * 0.72) for v in base), max(2, int(width * 0.09)), 90, 190)
    # midrib
    cv.line(pts, tuple(int(v * 0.78) for v in base), max(2, int(width * 0.16)), 190 + 10 * depth, 160)
    if bladders and depth >= 1:
        for i in range(1, n - 1, 3):
            if rng.random() < 0.7:
                px, py = pts[i]
                dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
                L = math.hypot(dx, dy) or 1
                nx, ny = -dy / L, dx / L
                for s in (-1, 1):
                    cx, cy = px + nx * s * width * 0.26, py + ny * s * width * 0.26
                    r = width * rng.uniform(0.26, 0.34)
                    c = jit(pal["bladder"], rng, 8)
                    cv.ellipse((cx - r, cy - r, cx + r, cy + r), c, 245, 130)
                    rr = r * 0.45  # wrinkled, collapsed top of a dried bladder
                    cv.ellipse((cx - rr + r * 0.15, cy - rr - r * 0.15, cx + rr + r * 0.15, cy + rr - r * 0.15),
                               tuple(int(v * 1.12) for v in c), 255, 120)
    if depth < maxd:
        spread = rng.uniform(0.28, 0.5)
        for s in (-1, 1):
            thallus(cv, rng, x, y, a + s * spread + rng.gauss(0, 0.06), length * rng.uniform(0.68, 0.82),
                    width * 0.88, depth + 1, maxd, pal, serrated, bladders)
    else:
        if rng.random() < 0.5:  # swollen warty receptacle tip
            r = width * 0.75
            ex, ey = x + math.cos(a) * r * 0.6, y + math.sin(a) * r * 0.6
            cv.ellipse((ex - r * 1.3, ey - r, ex + r * 1.3, ey + r), jit(pal["tip"], rng, 8), 220, 165)
            for k in range(10):
                dx, dy = rng.gauss(0, r * 0.5), rng.gauss(0, r * 0.4)
                d = r * 0.12
                cv.ellipse((ex + dx - d, ey + dy - d, ex + dx + d, ey + dy + d), tuple(int(v * 0.78) for v in pal["tip"]), 250, 170)
        else:
            r = width * 0.45
            cv.ellipse((x - r, y - r, x + r, y + r), base, 120, 175)


def wrack(w, h, rng, kind):
    cv = Canvas(w, h)
    if kind == "A":  # bladderwrack, dried on the strand line: dark olive-brown, bladders a shade lighter
        pal = {"base": (74, 63, 36), "bladder": (88, 74, 40), "tip": (118, 100, 52)}
        for k in range(4):
            y = h * (0.22 + 0.19 * k) + rng.gauss(0, h * 0.03)
            thallus(cv, rng, -w * 0.02, y, rng.gauss(0, 0.12), w * 0.27, h * 0.1, 0, 3, pal, False, True)
    else:  # serrated wrack + dried thongweed / eelgrass strings lying across it
        pal = {"base": (88, 66, 36), "bladder": (88, 66, 36), "tip": (104, 84, 46)}
        for k in range(2):
            y = h * (0.36 + 0.28 * k) + rng.gauss(0, h * 0.03)
            thallus(cv, rng, -w * 0.02, y, rng.gauss(0, 0.1), w * 0.3, h * 0.15, 0, 2, pal, True, False)
        for k in range(5):
            y = rng.uniform(h * 0.15, h * 0.85)
            pts, a, x = [], rng.gauss(0, 0.1), 0.0
            yy = y
            while x < w * rng.uniform(0.7, 1.0):
                pts.append((x, yy))
                a += rng.gauss(0, 0.05)
                a = max(-0.4, min(0.4, a))
                x += 18
                yy += math.sin(a) * 18
            cv.line(pts, jit((50, 44, 30), rng, 6), rng.randint(5, 9), 230, 150)
    m = 4
    for im in (cv.col, cv.a, cv.ht):
        ImageDraw.Draw(im).rectangle((0, 0, cv.w - 1, cv.h - 1), outline=0, width=m)
    rgb = np.asarray(cv.col, np.float32)
    al = np.asarray(cv.a.filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255.0
    ht = np.asarray(cv.ht.filter(ImageFilter.GaussianBlur(2.0)), np.float32) / 255.0
    rg = np.asarray(cv.rg, np.float32) / 255.0
    # mottling, sun-bleach and salt crust
    mot = fbm(h, w, 90, 90, rng.randint(0, 9999))
    rgb = rgb * (0.82 + 0.36 * mot[..., None])
    salt = smooth(0.72, 0.8, fbm(h, w, 40, 40, rng.randint(0, 9999))) * 0.35
    rgb = mix(rgb, (128, 122, 104), salt)
    grit = speckle(h, w, 4, 0.025, rng.randint(0, 9999))  # sand grains stuck to the frond
    rgb = mix(rgb, (170, 156, 128), grit * 0.8)
    rg = rg + salt * 0.12
    return rgb, al, ht + grit * 0.25, rg


# ---------------------------------------------------------------------------------------------------- driftwood
def drift_grain(w, h, seed):
    """sun-bleached, sand-scoured side grain running along x: raised late wood, checks, a few knots"""
    rng = random.Random(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = fbm(h, w, 260, 70, seed + 1) * 18 + fbm(h, w, 60, 20, seed + 2) * 4
    yy = y + warp * 3.0
    # knots: pull the grain lines round an eye
    knots = []
    for k in range(5):
        kx, ky, kr = rng.uniform(0.05, 0.95) * w, rng.uniform(0.1, 0.9) * h, rng.uniform(10, 22)
        knots.append((kx, ky, kr))
        d = np.sqrt(((x - kx) / 2.6) ** 2 + (y - ky) ** 2)
        yy = yy + np.exp(-(d / (kr * 2.2)) ** 2) * (y - ky) * 1.6
    period = 9.0
    g = 0.5 + 0.5 * np.sin(2 * math.pi * yy / period)
    g = g ** 1.6
    fine = fbm(h, w, 120, 3, seed + 3)
    tone = fbm(h, w, 300, 120, seed + 4)
    light, dark = np.array([188, 184, 174], np.float32), np.array([128, 122, 112], np.float32)
    t = np.clip(0.25 + 0.45 * g + 0.4 * (fine - 0.5) + 0.5 * (tone - 0.5), 0, 1)
    rgb = mix(dark, light, t)
    warm = smooth(0.58, 0.75, fbm(h, w, 220, 90, seed + 5)) * 0.5
    rgb = mix(rgb, (160, 144, 118), warm)
    # checks (drying cracks along the grain)
    cm = Image.new("L", (w, h), 0)
    dc = ImageDraw.Draw(cm)
    for k in range(int(w * h / 9000)):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        L = rng.uniform(60, 420)
        pts, px, py = [], cx, cy
        for s in range(14):
            pts.append((px, py))
            px += L / 14
            py += rng.gauss(0, 1.2)
        dc.line(pts, fill=255, width=rng.choice((1, 2, 2, 3)))
    crack = np.asarray(cm.filter(ImageFilter.GaussianBlur(0.9)), np.float32) / 255.0
    for kx, ky, kr in knots:
        d = np.sqrt(((x - kx) / 1.4) ** 2 + (y - ky) ** 2)
        ring = np.exp(-((d - kr * 0.55) / 2.5) ** 2) * 0.7 + np.exp(-(d / (kr * 0.45)) ** 2) * 0.5
        rgb = rgb * (1 - 0.45 * ring[..., None])
    rgb = rgb * (1 - 0.58 * crack[..., None])
    grit = speckle(h, w, 2.5, 0.012, seed + 6)
    rgb = mix(rgb, (92, 86, 78), grit * 0.6)
    hgt = 0.45 * g + 0.3 * fine + 0.25 * tone - 0.7 * crack
    rough = 0.86 + 0.08 * crack - 0.05 * g
    return rgb, np.ones((h, w), np.float32), np.clip(hgt, 0, 1), rough


def drift_end(w, h, seed):
    """abraded end grain of a broken branch: growth rings, radial checks, grey weathered rim"""
    rng = random.Random(seed)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    cx, cy = w * rng.uniform(0.45, 0.55), h * rng.uniform(0.45, 0.55)
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / (w * 0.5)
    th = np.arctan2(y - cy, x - cx)
    rr = r + (fbm(h, w, 30, 30, seed) - 0.5) * 0.06
    rings = 0.5 + 0.5 * np.sin(rr * 2 * math.pi * 9)
    rgb = mix(np.array([136, 124, 106], np.float32), np.array([176, 166, 146], np.float32), rings * 0.7 + 0.15)
    radial = np.zeros((h, w), np.float32)
    for k in range(rng.randint(4, 7)):
        a = rng.uniform(-math.pi, math.pi)
        dth = np.abs(np.angle(np.exp(1j * (th - a))))
        radial = np.maximum(radial, np.exp(-(dth * r * w * 0.5 / 1.6) ** 2) * smooth(0.1, 0.3, r) * (r < rng.uniform(0.6, 0.95)))
    rgb = rgb * (1 - 0.6 * radial[..., None])
    rim = smooth(0.78, 0.92, r)
    rgb = mix(rgb, (150, 146, 138), rim)
    pith = np.exp(-(r / 0.05) ** 2)
    rgb = rgb * (1 - 0.5 * pith[..., None])
    hgt = 0.5 + 0.2 * rings - 0.6 * radial - 0.3 * rim * 0
    return rgb, np.ones((h, w), np.float32), np.clip(hgt, 0, 1), 0.88 + 0.06 * radial


# ---------------------------------------------------------------------------------------------------- shells
def polar(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
    return np.sqrt(dx * dx + dy * dy), np.arctan2(dy, dx)


def cockle_out(w, h, seed):
    r, th = polar(w, h)
    wob = (fbm(h, w, 40, 40, seed) - 0.5) * 0.25
    ribs = 0.5 + 0.5 * np.cos(th * 24 + wob * 3)
    ribs = smooth(0.25, 0.9, ribs)
    growth = 0.5 + 0.5 * np.sin(r * 2 * math.pi * 7 + wob * 8)
    band = smooth(0.45, 0.7, fbm(h, w, 120, 120, seed + 1) * 0.5 + (0.5 + 0.5 * np.sin(r * 2 * math.pi * 2.2)) * 0.5)
    cream, tan = np.array([208, 198, 174], np.float32), np.array([150, 124, 94], np.float32)
    rgb = mix(cream, tan, band * 0.75)
    rgb = rgb * (0.78 + 0.22 * ribs[..., None]) * (0.94 + 0.06 * growth[..., None])
    worn = np.exp(-(r / 0.28) ** 2)  # sand-worn umbo: greyer, chalky
    rgb = mix(rgb, (184, 180, 170), worn * 0.7)
    grit = speckle(h, w, 3, 0.02, seed + 2)
    rgb = mix(rgb, (120, 112, 100), grit * 0.5)
    hgt = 0.55 * ribs + 0.15 * growth + 0.2 * fbm(h, w, 20, 20, seed + 3)
    return rgb, np.ones((h, w), np.float32), hgt, 0.62 - 0.08 * ribs + 0.1 * worn


def cockle_in(w, h, seed):
    r, th = polar(w, h)
    rgb = np.zeros((h, w, 3), np.float32) + np.array([214, 208, 196], np.float32)
    mot = fbm(h, w, 60, 60, seed)
    rgb = rgb * (0.9 + 0.12 * mot[..., None])
    stain = smooth(0.5, 0.75, fbm(h, w, 140, 140, seed + 1)) * np.exp(-(((r - 0.2) / 0.35) ** 2))
    rgb = mix(rgb, (150, 128, 128), stain * 0.55)  # faint purple-brown hinge stain
    marg = smooth(0.7, 0.9, r)
    cren = 0.5 + 0.5 * np.cos(th * 24)
    rgb = rgb * (1 - 0.18 * (marg * cren)[..., None])
    grit = speckle(h, w, 3, 0.03, seed + 2)
    rgb = mix(rgb, (168, 154, 126), grit * 0.6)  # sand left in the bowl
    hgt = 0.3 * mot + 0.3 * marg * cren + 0.3 * grit
    return rgb, np.ones((h, w), np.float32), hgt, 0.42 + 0.1 * grit + 0.06 * marg


def mussel_out(w, h, seed):
    r, th = polar(w, h)
    wob = (fbm(h, w, 50, 50, seed) - 0.5) * 0.12
    growth = 0.5 + 0.5 * np.sin((r + wob) * 2 * math.pi * 11)
    bands = smooth(0.4, 0.65, 0.5 + 0.5 * np.sin((r + wob) * 2 * math.pi * 3.1 + 1.0))
    black, blue = np.array([34, 37, 48], np.float32), np.array([62, 70, 92], np.float32)
    rgb = mix(black, blue, bands * 0.6 + growth * 0.15)
    worn = smooth(0.55, 0.75, fbm(h, w, 70, 70, seed + 1)) * smooth(0.55, 0.0, r)  # periostracum rubbed off near the umbo
    rgb = mix(rgb, (124, 122, 140), worn * 0.8)
    grit = speckle(h, w, 3, 0.015, seed + 2)
    rgb = mix(rgb, (150, 140, 118), grit * 0.6)
    hgt = 0.35 * growth + 0.3 * bands + 0.2 * grit
    return rgb, np.ones((h, w), np.float32), hgt, 0.5 - 0.1 * bands + 0.15 * worn


def mussel_in(w, h, seed):
    r, th = polar(w, h)
    nac = fbm(h, w, 50, 50, seed)
    rgb = mix(np.array([196, 198, 208], np.float32), np.array([176, 170, 194], np.float32), smooth(0.4, 0.7, nac))
    rgb = mix(rgb, (204, 208, 206), smooth(0.6, 0.8, fbm(h, w, 25, 25, seed + 1)) * 0.5)
    lip = smooth(0.74, 0.86, r)
    rgb = mix(rgb, (44, 48, 62), lip)  # the blue-black prismatic margin
    pall = np.exp(-((r - 0.66) / 0.02) ** 2) * 0.25
    rgb = rgb * (1 - pall[..., None])
    hgt = 0.15 * nac + 0.5 * lip
    return rgb, np.ones((h, w), np.float32), hgt, 0.3 + 0.25 * lip


# ---------------------------------------------------------------------------------------------------- pebbles
def granite(w, h, seed):
    base = np.zeros((h, w, 3), np.float32) + np.array([150, 147, 142], np.float32)
    base = base * (0.9 + 0.16 * fbm(h, w, 90, 90, seed)[..., None])
    rgb = mix(base, (210, 206, 198), speckle(h, w, 6, 0.26, seed + 1))
    rgb = mix(rgb, (178, 152, 140), speckle(h, w, 7, 0.08, seed + 2))
    bio = speckle(h, w, 3.5, 0.11, seed + 3)
    rgb = mix(rgb, (40, 40, 42), bio)
    hgt = 0.6 * fbm(h, w, 160, 160, seed + 4) + 0.15 * bio
    return rgb, np.ones((h, w), np.float32), hgt, 0.66 + 0.06 * bio


def slate(w, h, seed):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = fbm(h, w, 200, 200, seed) * 40
    lam = 0.5 + 0.5 * np.sin((y * 0.8 + x * 0.3 + warp) * 2 * math.pi / 22)
    rgb = mix(np.array([72, 76, 82], np.float32), np.array([98, 102, 108], np.float32), lam * 0.5 + fbm(h, w, 60, 60, seed + 1) * 0.5)
    vm = Image.new("L", (w, h), 0)
    dv = ImageDraw.Draw(vm)
    rng = random.Random(seed)
    for k in range(2):
        pts, px, py, a = [], rng.uniform(0, w * 0.2), rng.uniform(0, h), rng.uniform(-0.6, 0.6)
        for s in range(30):
            pts.append((px, py))
            a += rng.gauss(0, 0.12)
            px += math.cos(a) * w / 24
            py += math.sin(a) * w / 24
        dv.line(pts, fill=255, width=rng.randint(3, 7))
    vein = np.asarray(vm.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    rgb = mix(rgb, (196, 196, 190), vein)
    hgt = 0.5 * fbm(h, w, 160, 160, seed + 2) + 0.1 * lam + 0.2 * vein
    return rgb, np.ones((h, w), np.float32), hgt, 0.56 - 0.05 * vein


def quartz(w, h, seed):
    mot = fbm(h, w, 70, 70, seed)
    rgb = mix(np.array([208, 204, 194], np.float32), np.array([170, 168, 164], np.float32), smooth(0.45, 0.75, mot))
    rust = smooth(0.66, 0.8, fbm(h, w, 40, 120, seed + 1))
    rgb = mix(rgb, (168, 130, 98), rust * 0.6)
    pits = speckle(h, w, 3, 0.02, seed + 2)
    rgb = mix(rgb, (120, 112, 104), pits * 0.6)
    hgt = 0.5 * fbm(h, w, 180, 180, seed + 3) - 0.2 * pits
    return rgb, np.ones((h, w), np.float32), np.clip(hgt + 0.2, 0, 1), 0.46 + 0.1 * rust


def sandstone(w, h, seed):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    bed = 0.5 + 0.5 * np.sin((y + fbm(h, w, 220, 60, seed) * 50) * 2 * math.pi / 40)
    rgb = mix(np.array([138, 116, 90], np.float32), np.array([170, 146, 112], np.float32), bed * 0.5 + fbm(h, w, 50, 50, seed + 1) * 0.5)
    grain = vnoise(h, w, 1.5, 1.5, seed + 2)
    rgb = rgb * (0.9 + 0.18 * grain[..., None])
    rgb = mix(rgb, (96, 82, 66), speckle(h, w, 3, 0.03, seed + 3) * 0.6)
    hgt = 0.5 * fbm(h, w, 160, 160, seed + 4) + 0.15 * grain + 0.1 * bed
    return rgb, np.ones((h, w), np.float32), hgt, 0.84 + 0.04 * grain


# ---------------------------------------------------------------------------------------------------- maps
def wetify(rgb):
    lin = (np.clip(rgb, 0, 255) / 255.0) ** 2.2 * 0.6
    out = lin ** (1 / 2.2) * 255.0
    grey = out.mean(2, keepdims=True)
    out = grey + (out - grey) * 1.02
    return np.clip(out, 20, 240)


def pad_colour(rgb, a):
    levels = []
    c, w = rgb * a[..., None], a.copy()
    while min(w.shape) > 4:
        levels.append((c, w))
        H2, W2 = w.shape[0] // 2, w.shape[1] // 2
        c = c[:H2 * 2, :W2 * 2].reshape(H2, 2, W2, 2, 3).sum((1, 3))
        w = w[:H2 * 2, :W2 * 2].reshape(H2, 2, W2, 2).sum((1, 3))
    fill = c / np.maximum(w, 1e-6)[..., None]
    for c, w in reversed(levels):
        up = np.repeat(np.repeat(fill, 2, 0), 2, 1)[:w.shape[0], :w.shape[1]]
        mine = c / np.maximum(w, 1e-6)[..., None]
        t = np.clip(w, 0, 1)[..., None]
        fill = mine * t + up * (1 - t)
    return fill


def normal_from_height(hgt, strength):
    gy, gx = np.gradient(hgt)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(hgt)])  # OpenGL: +Y up (image rows go down)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


# per-cell height amplitude (normal strength) and painter
PAINT = {
    "WrackA": (1.0, lambda w, h, s: wrack(w, h, random.Random(s), "A")),
    "WrackB": (1.0, lambda w, h, s: wrack(w, h, random.Random(s), "B")),
    "DriftEnd": (0.8, drift_end), "DriftEnd2": (0.8, drift_end),
    "CockleOut": (0.9, cockle_out), "CockleIn": (0.5, cockle_in), "MusselOut": (0.5, mussel_out), "MusselIn": (0.4, mussel_in),
    "Granite": (0.35, granite), "Slate": (0.3, slate), "Quartz": (0.3, quartz), "Sandstone": (0.4, sandstone),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--master", type=int, default=2048)
    ap.add_argument("--ship", type=int, default=1024)
    args = ap.parse_args()
    S = args.master
    U = S // G
    rgb = np.zeros((S, S, 3), np.float32)
    alpha = np.ones((S, S), np.float32)
    hgt = np.zeros((S, S), np.float32)
    rough = np.zeros((S, S), np.float32)
    cells_uv = {}
    # one continuous side-grain block for DriftA..C and DriftStub (rows 0-3 of the right half)
    grain = drift_grain(4 * U, 4 * U, 401)
    for name, (cx, cy, cw, ch) in CELLS.items():
        w, h, x0, y0 = cw * U, ch * U, cx * U, cy * U
        cells_uv[name] = [cx / G, 1 - (cy + ch) / G, (cx + cw) / G, 1 - cy / G]
        seed = sum(ord(c) * (i + 1) for i, c in enumerate(name)) + 23
        if name.startswith("Drift") and not name.startswith("DriftEnd"):
            gy, gx = (cy - 0) * U, (cx - 4) * U
            c, a, hh, r = (m[gy:gy + h, gx:gx + w] for m in grain)
            amp = 0.6
        else:
            amp, fn = PAINT[name]
            c, a, hh, r = fn(w, h, seed)
        rgb[y0:y0 + h, x0:x0 + w] = c
        alpha[y0:y0 + h, x0:x0 + w] = a
        hgt[y0:y0 + h, x0:x0 + w] = np.clip(hh, 0, 1) * amp
        rough[y0:y0 + h, x0:x0 + w] = r
    rgb = np.clip(rgb, 0, 255)
    fill = pad_colour(rgb / 255.0, (alpha > 0.5).astype(np.float32)) * 255
    rgb = np.where((alpha > 0.5)[..., None], rgb, fill)
    # saturation soft knee under the 05 ceiling (0.45)
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    knee = np.where(sat > 0.34, 0.34 + (sat - 0.34) * 0.35, sat)
    grey = mx[..., None]
    rgb = grey - (grey - rgb) * (knee / np.maximum(sat, 1e-3))[..., None]
    rgb = np.clip(rgb, 34, 238)
    nor = normal_from_height(hgt, 26.0 * S / 4096.0)
    nor[alpha < 0.02] = (128, 128, 255)
    rough = np.clip(np.where(alpha > 0.02, rough, 0.7), 0.05, 1)
    out = {"ALB": np.dstack([rgb, alpha * 255]).astype(np.uint8), "NOR": nor, "RGH": (rough * 255).astype(np.uint8),
           "MET": np.zeros((S, S), np.uint8)}
    out["RGH_Wet"] = (np.clip(rough * 0.45, 0.05, 1) * 255).astype(np.uint8)
    os.makedirs(MASTER_DIR, exist_ok=True)
    os.makedirs(SHIP_DIR, exist_ok=True)

    def save(arrs, d, size):
        for k, arr in arrs.items():
            mode = "RGBA" if arr.ndim == 3 and arr.shape[2] == 4 else ("RGB" if arr.ndim == 3 else "L")
            im = Image.fromarray(arr)
            if size != im.width:
                im = im.resize((size, size), Image.LANCZOS)
            a = np.asarray(im)
            if k == "ALB":
                a = a.copy(); a[..., :3] = np.clip(a[..., :3], 34, 238)
                wet = a.copy(); wet[..., :3] = wetify(a[..., :3].astype(np.float32)).astype(np.uint8)
                Image.fromarray(wet).save(os.path.join(d, STEM + "_ALB_Wet.png"))
            Image.fromarray(a).save(os.path.join(d, "%s_%s.png" % (STEM, k)))
            if k in ("NOR", "MET"):
                Image.fromarray(a).save(os.path.join(d, "%s_%s_Wet.png" % (STEM, k)))
    save(out, MASTER_DIR, S)
    save(out, SHIP_DIR, args.ship)
    json.dump({"master": S, "ship": args.ship, "uv": "u0, v0, u1, v1 (v up)", "cells": cells_uv},
              open(os.path.join(HERE, "cells.json"), "w"), indent=1)
    print("atlas ok", S, "->", args.ship, SHIP_DIR)


if __name__ == "__main__":
    main()
