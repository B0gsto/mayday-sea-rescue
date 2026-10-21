"""M_Bld_BoatyardShed own yard atlas (system python3 + numpy + Pillow).

    python3 art/source/buildings/M_Bld_BoatyardShed/maketex.py

Writes build/prod/M_Bld_BoatyardShed/textures/M_Bld_BoatyardShed/T_Yard_Details_*
(ALB/NOR/RGH/MET + _Wet ALB/RGH, 2048 px). BldTrim Sheet, Slipway Steel and Pontoon Kit are shared.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "build/prod/M_Bld_BoatyardShed/textures/M_Bld_BoatyardShed"
N = 2048
rng = np.random.default_rng(4407)

D = {
    "Clad": (0.000, 0.560, 0.500, 1.000), "Inner": (0.500, 0.820, 0.720, 1.000),
    "Roof": (0.720, 0.760, 1.000, 1.000), "Light": (0.720, 0.680, 1.000, 0.760),
    "Sign": (0.000, 0.400, 0.500, 0.480), "Roller": (0.500, 0.360, 0.720, 0.560),
    "Door": (0.720, 0.360, 0.820, 0.560), "Glass": (0.820, 0.360, 1.000, 0.560),
    "Price": (0.000, 0.180, 0.260, 0.400), "Diesel": (0.260, 0.180, 0.380, 0.400),
    "Petrol": (0.380, 0.180, 0.500, 0.400), "Lit": (0.500, 0.180, 0.640, 0.360),
    "Conc": (0.000, 0.000, 0.300, 0.180), "Tarmac": (0.300, 0.000, 0.600, 0.180),
    "Mark": (0.600, 0.000, 0.750, 0.090), "Rust": (0.750, 0.000, 0.875, 0.180),
    "Dark": (0.875, 0.000, 1.000, 0.180),
    "Timber": (0.640, 0.180, 0.750, 0.360),
}


def fbm(shape, beta=2.0, aniso=(1.0, 1.0), seed=0):
    r = np.random.default_rng(seed)
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None] * aniso[0]
    fx = np.fft.fftfreq(w)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(r.standard_normal(shape)) / f ** (beta / 2.0)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def mix(a, b, m):
    if np.ndim(m) == 2:
        m = m[..., None]
    return a * (1 - m) + b * m


def normals(h, strength=2.2):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def px(name):
    u0, v0, u1, v1 = D[name]
    x0, x1 = int(round(u0 * N)), int(round(u1 * N))
    y0, y1 = int(round((1 - v1) * N)), int(round((1 - v0) * N))
    return x0, x1, y0, y1


ALB = np.zeros((N, N, 3))
RGH = np.full((N, N), 0.8)
MET = np.zeros((N, N))
HGT = np.full((N, N), 0.5)
WEAR = np.zeros((N, N))


def put(name, alb, rgh=0.8, met=0.0, hgt=0.5):
    x0, x1, y0, y1 = px(name)
    h, w = y1 - y0, x1 - x0
    if np.ndim(alb) == 3:
        ALB[y0:y1, x0:x1] = alb[:h, :w]
    else:
        ALB[y0:y1, x0:x1] = alb[:h, :w, None]
    RGH[y0:y1, x0:x1] = np.broadcast_to(rgh if np.ndim(rgh) == 2 else np.full((h, w), rgh), (h, w))[:h, :w]
    MET[y0:y1, x0:x1] = np.broadcast_to(met if np.ndim(met) == 2 else np.full((h, w), met), (h, w))[:h, :w]
    HGT[y0:y1, x0:x1] = np.broadcast_to(hgt if np.ndim(hgt) == 2 else np.full((h, w), hgt), (h, w))[:h, :w]


def text_mask(w, h, lines, pad=0.05, color=255, font_hint=None):
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    fonts = ["/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf",
             "/System/Library/Fonts/Supplemental/GillSans.ttc",
             "/System/Library/Fonts/Supplemental/Baskerville.ttc"]

    def font(sz):
        for f in fonts:
            try:
                return ImageFont.truetype(f, sz, index=1) if f.endswith(".ttc") else ImageFont.truetype(f, sz)
            except Exception:
                continue
        return ImageFont.load_default()
    for txt, fy, fh in lines:
        sz = int(h * fh)
        f = font(sz)
        while sz > 6 and d.textlength(txt, font=f) > w * (1 - 2 * pad):
            sz -= 2
            f = font(sz)
        d.text((w / 2, h * fy), txt, fill=color, font=f, anchor="mm")
    return np.asarray(img).astype(np.float64) / 255.0


def cladding(name="Clad", tint=(96, 110, 99), pitch=10.0, rust=0.55, seed=1):
    x0, x1, y0, y1 = px(name)
    h, w = y1 - y0, x1 - x0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = xx / w, 1.0 - yy / h
    rib = (u * pitch) % 1.0
    ridge = smooth(0.10, 0.20, rib) * (1 - smooth(0.80, 0.90, rib))
    groove = np.exp(-((rib - 0.0) ** 2) / (2 * 0.05 ** 2)) + np.exp(-((rib - 1.0) ** 2) / (2 * 0.05 ** 2))
    big = fbm((h, w), 3.0, seed=seed)
    fine = fbm((h, w), 1.2, seed=seed + 1)
    runs = fbm((h, w), 2.1, aniso=(0.16, 1.7), seed=seed + 2)
    base = rgb(tint)
    a = np.ones((h, w, 3)) * base
    a *= (0.86 + 0.22 * big)[..., None]
    a *= (0.94 + 0.10 * fine)[..., None]
    a *= (1.0 - 0.18 * groove)[..., None]
    a *= (1.0 + 0.05 * ridge)[..., None]
    r = 0.56 + 0.12 * big - 0.05 * ridge
    hgt = 0.45 + 0.26 * ridge - 0.22 * groove + 0.04 * fine
    # horizontal sheet lap and fixing line
    lap = smooth(0.495, 0.500, v) * (1 - smooth(0.500, 0.510, v))
    a *= (1 - 0.22 * lap)[..., None]
    r += 0.10 * lap
    hgt -= 0.12 * lap
    for vv in (0.18, 0.50, 0.82):
        bolts = np.exp(-((u - 0.20) ** 2) / (2 * 0.010 ** 2)) + np.exp(-((u - 0.70) ** 2) / (2 * 0.010 ** 2))
        b = np.exp(-((v - vv) ** 2) / (2 * 0.004 ** 2)) * bolts
        a *= (1 - 0.35 * b)[..., None]
        hgt += 0.10 * b
        r += 0.12 * b
    # rust bleeding from fixings and laps, more under the eaves (top of the tile) and at the base
    rustm = smooth(0.62, 0.88, runs) * (0.25 + 0.75 * smooth(0.55, 1.0, v))
    rustm *= 0.55 + 0.45 * smooth(0.2, 0.9, big)
    rustm = np.clip(rustm * rust, 0, 1)
    a = mix(a, rgb((88, 44, 25)), rustm * 0.85)
    r = np.where(rustm > 0.15, r + 0.18, r)
    hgt -= 0.05 * rustm
    salt = smooth(0.60, 0.95, fbm((h, w), 1.8, aniso=(2.4, 1.0), seed=seed + 3)) * smooth(0.72, 0.0, v) * 0.5
    a = mix(a, rgb((170, 172, 165)), salt * 0.30)
    a = np.clip(a, 0.10, 0.93)
    met = np.full((h, w), 0.25)
    return a, np.clip(r, 0.30, 0.92), met, np.clip(hgt, 0, 1)


def concrete(dark=False, seed=5):
    name = "Tarmac" if dark else "Conc"
    x0, x1, y0, y1 = px(name)
    h, w = y1 - y0, x1 - x0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = xx / w, 1.0 - yy / h
    big = fbm((h, w), 2.6, seed=seed)
    mid = fbm((h, w), 1.4, seed=seed + 1)
    fine = fbm((h, w), 0.6, seed=seed + 2)
    grit = fbm((h, w), 0.2, seed=seed + 3)
    base = rgb((86, 84, 80)) if dark else rgb((132, 129, 121))
    a = np.ones((h, w, 3)) * base
    a *= (0.80 + 0.34 * big)[..., None]
    a *= (0.90 + 0.18 * mid)[..., None]
    a += (grit[..., None] - 0.5) * 0.10
    crack = np.abs(fbm((h, w), 2.4, aniso=(0.25, 1.3), seed=seed + 4) - 0.5)
    crackm = (1 - smooth(0.0, 0.030, crack)) * smooth(0.45, 0.85, mid)
    a *= (1 - 0.40 * crackm)[..., None]
    r = 0.82 + 0.08 * fine - 0.10 * crackm
    # oil / damp stains
    stain = smooth(0.62, 0.92, fbm((h, w), 2.0, seed=seed + 5)) * (0.4 + 0.6 * mid)
    a = mix(a, rgb((38, 37, 34)), stain * 0.35)
    r -= 0.12 * stain
    # expansion joints at the tile edges
    edge = 1 - smooth(0.0, 0.012, np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v)))
    a *= (1 - 0.45 * edge)[..., None]
    hgt = 0.5 + 0.10 * grit - 0.30 * crackm - 0.35 * edge
    met = np.zeros((h, w))
    return np.clip(a, 0.10, 0.9), np.clip(r, 0.35, 1.0), met, np.clip(hgt, 0, 1)


# ------------------------------------------------------------------ build regions
a, r, m, hh = cladding("Clad")
put("Clad", a, r, m, hh)

a, r, m, hh = cladding("Roof", tint=(54, 64, 58), pitch=13.0, rust=0.35, seed=31)
put("Roof", a, r, m, hh)

x0, x1, y0, y1 = px("Inner")
h, w = y1 - y0, x1 - x0
big = fbm((h, w), 2.6, seed=41)
a = np.ones((h, w, 3)) * rgb((70, 79, 72))
a *= (0.84 + 0.22 * big)[..., None]
put("Inner", np.clip(a, 0.08, 0.9), 0.78 + 0.1 * big, 0.2, 0.5)

x0, x1, y0, y1 = px("Light")
h, w = y1 - y0, x1 - x0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
big = fbm((h, w), 2.2, seed=51)
a = np.ones((h, w, 3)) * rgb((138, 152, 153))
a = mix(a, rgb((101, 117, 117)), big * 0.45)
a *= (1 - 0.18 * smooth(0.45, 0.55, v) * (1 - smooth(0.55, 0.65, v)))[..., None]
put("Light", np.clip(a, 0.15, 0.92), 0.28 + 0.12 * big, 0.0, 0.5)

# painted sign: dark green board, cream lettering, worn and rusty
x0, x1, y0, y1 = px("Sign")
h, w = y1 - y0, x1 - x0
n = fbm((h, w), 2.2, seed=61)
a = np.ones((h, w, 3)) * rgb((31, 55, 46))
a *= (0.88 + 0.20 * n)[..., None]
mask = text_mask(w, h, [("PORT HAVEN BOATYARD", 0.52, 0.56)], pad=0.045)
wear = smooth(0.52, 0.80, fbm((h, w), 1.4, seed=62))
letter = mask * (1 - 0.55 * wear)
a = mix(a, rgb((213, 204, 180)), letter)
# border
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
border = np.maximum(smooth(0.0, 0.010, np.minimum(u, 1 - u)), smooth(0.0, 0.05, np.minimum(v, 1 - v)))
a = mix(a, rgb((201, 194, 174)), (1 - border) * 0.85)
# rust runs from the top edge
runs = smooth(0.66, 0.92, fbm((h, w), 2.0, aniso=(0.20, 1.6), seed=63)) * smooth(0.95, 0.25, v)
a = mix(a, rgb((86, 45, 26)), runs * 0.55)
put("Sign", np.clip(a, 0.07, 0.92), 0.62 + 0.15 * wear - 0.10 * letter, 0.0, 0.55)

# roller door curtain: horizontal slats, scuffed, rust at the bottom
x0, x1, y0, y1 = px("Roller")
h, w = y1 - y0, x1 - x0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
n = fbm((h, w), 1.8, seed=71)
slat = (v * 26.0) % 1.0
shade = 0.72 + 0.28 * smooth(0.0, 0.25, slat) * (1 - smooth(0.80, 1.0, slat))
a = np.ones((h, w, 3)) * rgb((104, 114, 106))
a *= (0.83 + 0.22 * n)[..., None] * shade[..., None]
scr = fbm((h, w), 1.0, aniso=(0.5, 2.2), seed=72)
a = mix(a, rgb((58, 61, 58)), smooth(0.74, 0.96, scr) * 0.4)
rustm = smooth(0.58, 0.88, fbm((h, w), 1.8, aniso=(1.8, 1.1), seed=73)) * smooth(0.45, 0.0, v)
a = mix(a, rgb((99, 50, 28)), rustm * 0.75)
hgt = 0.35 + 0.30 * shade
put("Roller", np.clip(a, 0.08, 0.9), 0.55 + 0.18 * scr - 0.12 * rustm, 0.25, hgt)

# personnel door: pale grey-blue steel leaf with panels and kick plate
x0, x1, y0, y1 = px("Door")
h, w = y1 - y0, x1 - x0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
n = fbm((h, w), 1.8, seed=81)
a = np.ones((h, w, 3)) * rgb((138, 144, 139))
a *= (0.88 + 0.16 * n)[..., None]
panel = smooth(0.10, 0.13, u) * smooth(0.90, 0.87, u) * smooth(0.15, 0.18, v) * smooth(0.88, 0.85, v)
a = mix(a, a * 1.08, panel)
kick = smooth(0.18, 0.21, v)
a = mix(a, rgb((54, 56, 55)), kick * 0.75)
sc = smooth(0.70, 0.95, fbm((h, w), 1.1, aniso=(0.4, 2.0), seed=82))
a = mix(a, rgb((68, 71, 68)), sc * 0.35)
scratch = 0.85 + 0.15 * smooth(0.5, 0.9, fbm((h, w), 0.8, aniso=(0.3, 2.0), seed=83))
a *= scratch[..., None]
put("Door", np.clip(a, 0.08, 0.9), 0.52 + 0.12 * n, 0.2, 0.5 + 0.12 * panel)

# dark window / door vision glass
x0, x1, y0, y1 = px("Glass")
h, w = y1 - y0, x1 - x0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
n = fbm((h, w), 2.4, seed=91)
ref = smooth(0.55, 0.95, fbm((h, w), 1.4, aniso=(0.3, 2.2), seed=92))
a = np.ones((h, w, 3)) * rgb((20, 27, 28))
a = mix(a, rgb((80, 94, 90)), ref * 0.55)
a += (n[..., None] - 0.5) * 0.03
put("Glass", np.clip(a, 0.02, 0.6), 0.12 + 0.12 * ref, 0.0, 0.5)

# price board: chalk on dark green, weathered frame
x0, x1, y0, y1 = px("Price")
h, w = y1 - y0, x1 - x0
n = fbm((h, w), 1.8, seed=101)
a = np.ones((h, w, 3)) * rgb((38, 54, 47))
a *= (0.88 + 0.15 * n)[..., None]
lines = [("BOATYARD PRICES", 0.115, 0.14), ("STORAGE  £28 / m / month", 0.33, 0.095),
         ("CRADLE HIRE  £16 / day", 0.50, 0.095), ("PRESSURE WASH  £24", 0.65, 0.095),
         ("DIESEL  £1.62 / L", 0.80, 0.095), ("PETROL  £1.68 / L", 0.92, 0.095)]
mask = text_mask(w, h, lines, pad=0.05)
wear = smooth(0.55, 0.85, fbm((h, w), 1.2, seed=102))
letter = mask * (1 - 0.45 * wear)
a = mix(a, rgb((220, 218, 201)), letter)
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
border = np.maximum(smooth(0.0, 0.018, np.minimum(u, 1 - u)), smooth(0.0, 0.035, np.minimum(v, 1 - v)))
a = mix(a, rgb((152, 146, 128)), (1 - border) * 0.8)
put("Price", np.clip(a, 0.07, 0.9), 0.55 + 0.2 * wear - 0.10 * letter, 0.0, 0.5)

for nm, word, band in (("Diesel", "DIESEL", (26, 27, 25)), ("Petrol", "PETROL", (24, 74, 48))):
    x0, x1, y0, y1 = px(nm)
    h, w = y1 - y0, x1 - x0
    n = fbm((h, w), 1.8, seed=111 if nm == "Diesel" else 121)
    a = np.ones((h, w, 3)) * rgb((184, 182, 174))
    a *= (0.88 + 0.14 * n)[..., None]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = xx / w, 1.0 - yy / h
    bandm = smooth(0.84, 0.87, v) * (1 - smooth(0.985, 1.0, v))
    a = mix(a, rgb((206, 177, 35)) if nm == "Diesel" else rgb((32, 92, 58)), bandm)
    msk = text_mask(w, h, [(word, 0.46, 0.19)], pad=0.08)
    a = mix(a, rgb(band), msk)
    grime = smooth(0.55, 0.9, fbm((h, w), 1.4, seed=113))
    a = mix(a, rgb((80, 68, 54)), grime * 0.28 * smooth(0.7, 0.0, v))
    put(nm, np.clip(a, 0.08, 0.9), 0.48 + 0.14 * n, 0.15, 0.5)

# lamp / lit lens
x0, x1, y0, y1 = px("Lit")
h, w = y1 - y0, x1 - x0
n = fbm((h, w), 1.8, seed=131)
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
a = np.ones((h, w, 3)) * rgb((244, 212, 150))
a *= (0.90 + 0.10 * n)[..., None]
rib = 0.82 + 0.18 * (0.5 + 0.5 * np.cos(u * np.pi * 14))
a *= rib[..., None]
put("Lit", np.clip(a, 0.25, 0.94), 0.25, 0.0, 0.5)

a, r, m, hh = concrete()
put("Conc", a, r, m, hh)
a, r, m, hh = concrete(dark=True, seed=17)
put("Tarmac", a, r, m, hh)

# faded yellow line paint
x0, x1, y0, y1 = px("Mark")
h, w = y1 - y0, x1 - x0
n = fbm((h, w), 1.6, seed=141)
a = np.ones((h, w, 3)) * rgb((176, 148, 52))
a *= (0.85 + 0.25 * n)[..., None]
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
wear = smooth(0.45, 0.8, fbm((h, w), 1.1, seed=142))
a = mix(a, rgb((84, 82, 77)), wear * 0.55)
put("Mark", np.clip(a, 0.10, 0.88), 0.7 + 0.15 * wear, 0.0, 0.5 + 0.04 * n)

# rust strip decal (matches the cladding base so its rectangles read as stains)
x0, x1, y0, y1 = px("Rust")
h, w = y1 - y0, x1 - x0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
core = smooth(0.54, 0.90, fbm((h, w), 2.2, aniso=(2.6, 1.0), seed=151)) * smooth(0.95, 0.10, v)
a = np.ones((h, w, 3)) * rgb((91, 100, 92))
a = mix(a, rgb((92, 47, 27)), core * 0.88)
put("Rust", np.clip(a, 0.08, 0.8), 0.62 + 0.2 * core, 0.15, 0.5 - 0.04 * core)

x0, x1, y0, y1 = px("Timber")
h, w = y1 - y0, x1 - x0
yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
u, v = xx / w, 1.0 - yy / h
grain = fbm((h, w), 1.6, aniso=(2.6, 0.30), seed=161)
knot = smooth(0.72, 0.92, fbm((h, w), 1.3, seed=162))
a = np.ones((h, w, 3)) * rgb((118, 96, 71))
a *= (0.82 + 0.30 * grain)[..., None]
a = mix(a, rgb((76, 58, 41)), knot * 0.45)
gap = np.exp(-((u - 0.0) ** 2) / (2 * 0.012 ** 2)) + np.exp(-((u - 0.5) ** 2) / (2 * 0.012 ** 2))
a *= (1 - 0.45 * gap)[..., None]
a = mix(a, rgb((66, 74, 62)), smooth(0.72, 0.95, fbm((h, w), 1.1, seed=163)) * 0.20)
put("Timber", np.clip(a, 0.08, 0.78), 0.78 + 0.12 * grain, 0.0, 0.5 + 0.12 * grain)

x0, x1, y0, y1 = px("Dark")
put("Dark", np.ones((y1 - y0, x1 - x0, 3)) * rgb((20, 24, 22)), 0.9, 0.0, 0.5)

# ------------------------------------------------------------------ maps
nor = normals(HGT, 2.0)
alb = np.clip(ALB, 30 / 255, 238 / 255)
rgh = np.clip(RGH, 0.04, 1.0)
met = np.clip(MET, 0, 1)
os.makedirs(OUT, exist_ok=True)
stem = "T_Yard_Details"
Image.fromarray((alb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_ALB.png"))
Image.fromarray((nor * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_NOR.png"))
Image.fromarray((rgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_RGH.png"))
Image.fromarray((met * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_MET.png"))
mm = met[..., None] > 0.5
dk = np.where(mm, 0.15, 0.34)
lum = alb.mean(-1, keepdims=True)
walb = np.clip((lum + (alb - lum) * 1.05) * (1 - dk), 30 / 255, 238 / 255)
wrgh = np.clip(rgh - 0.38 * (0.55 + 0.45 * rgh), 0.04, 1.0)
Image.fromarray((walb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_ALB_Wet.png"))
Image.fromarray((wrgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_RGH_Wet.png"))
print("[boatyard] albedo mean %s, %d x %d" % ((alb.reshape(-1, 3).mean(0) * 255).round(), N, N))


def save_set(stem, alb, rgh, met, hgt, strength=2.0):
    nor = normals(hgt, strength)
    alb = np.clip(alb, 30 / 255, 238 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    met = np.clip(met, 0, 1)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray((nor * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray((rgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray((met * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_MET.png"))
    mm = met[..., None] > 0.5
    dk = np.where(mm, 0.15, 0.34)
    lum = alb.mean(-1, keepdims=True)
    walb = np.clip((lum + (alb - lum) * 1.05) * (1 - dk), 30 / 255, 238 / 255)
    wrgh = np.clip(rgh - 0.38 * (0.55 + 0.45 * rgh), 0.04, 1.0)
    Image.fromarray((walb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_ALB_Wet.png"))
    Image.fromarray((wrgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_RGH_Wet.png"))
    print("[boatyard] %s %s" % (stem, "saved"))


def clad_sheet(sz=1024):
    h = w = sz
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = xx / w, 1.0 - yy / h
    pitch = 10.0
    rib = (u * pitch) % 1.0
    ridge = smooth(0.10, 0.20, rib) * (1 - smooth(0.80, 0.90, rib))
    groove = np.exp(-((rib - 0.0) ** 2) / (2 * 0.05 ** 2)) + np.exp(-((rib - 1.0) ** 2) / (2 * 0.05 ** 2))
    big = fbm((h, w), 3.0, seed=201)
    fine = fbm((h, w), 1.2, seed=202)
    runs = fbm((h, w), 2.1, aniso=(0.16, 1.7), seed=203)
    a = np.ones((h, w, 3)) * rgb((89, 102, 93))
    a *= (0.91 + 0.15 * big)[..., None]
    a *= (0.94 + 0.10 * fine)[..., None]
    a *= (1.0 - 0.18 * groove)[..., None]
    a *= (1.0 + 0.05 * ridge)[..., None]
    r = 0.56 + 0.12 * big - 0.05 * ridge
    hgt = 0.45 + 0.26 * ridge - 0.22 * groove + 0.04 * fine
    lap = smooth(0.495, 0.500, v) * (1 - smooth(0.500, 0.510, v))
    a *= (1 - 0.22 * lap)[..., None]
    r += 0.10 * lap
    hgt -= 0.12 * lap
    for vv in (0.18, 0.50, 0.82):
        bolts = np.exp(-((u - 0.20) ** 2) / (2 * 0.010 ** 2)) + np.exp(-((u - 0.70) ** 2) / (2 * 0.010 ** 2))
        b = np.exp(-((v - vv) ** 2) / (2 * 0.004 ** 2)) * bolts
        a *= (1 - 0.35 * b)[..., None]
        hgt += 0.10 * b
        r += 0.12 * b
    rustm = smooth(0.62, 0.88, runs) * (0.25 + 0.75 * smooth(0.55, 1.0, v))
    rustm = np.clip(rustm * 0.55, 0, 1)
    a = mix(a, rgb((88, 44, 25)), rustm * 0.85)
    r = np.where(rustm > 0.15, r + 0.18, r)
    hgt -= 0.05 * rustm
    salt = smooth(0.60, 0.95, fbm((h, w), 1.8, aniso=(2.4, 1.0), seed=204)) * smooth(0.72, 0.0, v) * 0.5
    a = mix(a, rgb((170, 172, 165)), salt * 0.30)
    met = np.full((h, w), 0.25)
    save_set("T_Boatyard_Clad", np.clip(a, 0.10, 0.93), np.clip(r, 0.30, 0.92), met, np.clip(hgt, 0, 1))


def ground_sheet(sz=1024):
    h = w = sz
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = xx / w, 1.0 - yy / h
    big = fbm((h, w), 2.8, seed=221)
    mid = fbm((h, w), 1.4, seed=222)
    grit = fbm((h, w), 0.2, seed=223)
    a = np.ones((h, w, 3)) * rgb((124, 121, 113))
    a *= (0.91 + 0.15 * big)[..., None]
    a *= (0.90 + 0.18 * mid)[..., None]
    a += (grit[..., None] - 0.5) * 0.11
    crack = np.abs(fbm((h, w), 2.4, aniso=(0.25, 1.3), seed=224) - 0.5)
    crackm = (1 - smooth(0.0, 0.028, crack)) * smooth(0.45, 0.85, mid)
    a *= (1 - 0.40 * crackm)[..., None]
    r = 0.82 + 0.08 * fbm((h, w), 0.9, seed=225) - 0.10 * crackm
    stain = smooth(0.58, 0.92, fbm((h, w), 2.0, seed=226)) * (0.4 + 0.6 * mid)
    a = mix(a, rgb((52, 50, 46)), stain * 0.30)
    r -= 0.14 * stain
    puddle = smooth(0.78, 0.95, fbm((h, w), 2.2, seed=227))
    a = mix(a, rgb((52, 53, 51)), puddle * 0.35)
    r -= 0.22 * puddle
    hgt = 0.5 + 0.10 * grit - 0.30 * crackm
    save_set("T_Boatyard_Ground", np.clip(a, 0.10, 0.88), np.clip(r, 0.35, 1.0), np.zeros((h, w)), np.clip(hgt, 0, 1), 1.6)


clad_sheet()
ground_sheet()


def metal_sheet(sz=1024):
    h = w = sz
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = xx / w, 1.0 - yy / h
    big = fbm((h, w), 2.6, seed=241)
    spang = fbm((h, w), 1.1, seed=242)
    fine = fbm((h, w), 0.5, seed=243)
    scr = fbm((h, w), 1.2, aniso=(0.4, 2.6), seed=244)
    runs = fbm((h, w), 2.3, aniso=(0.14, 1.9), seed=245)
    a = np.ones((h, w, 3)) * rgb((199, 203, 201))
    a *= (0.96 + 0.04 * big)[..., None]
    a *= (0.95 + 0.10 * spang)[..., None]
    a += (fine[..., None] - 0.5) * 0.05
    grime = smooth(0.56, 0.86, fbm((h, w), 2.0, aniso=(1.5, 0.7), seed=246)) * (0.4 + 0.6 * big)
    rust = smooth(0.56, 0.84, runs) * smooth(0.10, 0.95, big)
    scratch = smooth(0.74, 0.96, scr)
    gm = grime > 0.45
    rm = rust > 0.30
    a[gm] = rgb((73, 78, 73))
    a[rm] = rgb((92, 70, 56))
    a[scratch > 0.20] = mix(a[scratch > 0.20], rgb((196, 199, 197)), 0.35)
    hgt = 0.5 + 0.05 * spang + 0.03 * fine - 0.05 * scratch - 0.03 * grime
    met = np.where(gm | rm, 0.0, 0.58)
    rgh = 0.50 + 0.14 * big + 0.12 * scratch + 0.22 * rust + 0.18 * grime
    save_set("T_Boatyard_Metal", np.clip(a, 0.16, 0.94), np.clip(rgh, 0.30, 0.96), met, np.clip(hgt, 0, 1), 2.6)


metal_sheet()
