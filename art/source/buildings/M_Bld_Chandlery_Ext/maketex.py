"""H2 Chandlery exterior texture sets (system python3 + numpy + Pillow, no heavy slot). Procedural, no AI images.

    python3 art/source/buildings/M_Bld_Chandlery_Ext/maketex.py

Writes (1024 px, OpenGL normals, RGH / MET greyscale, _Wet ALB / RGH) to assets/textures/M_Bld_Chandlery_Ext/:
  T_Chandlery_Slate_*    Delabole-style blue-grey slate, tile 2 x 2 m (6 studs): 8 courses x 5 slates, lichen, faint salt
  T_Chandlery_Details_*  atlas: fascia lettering (two rows, one string split in half), shopfront paint / iron / lead strips
                         (u-tiling, trim mode), door panels, hanging sign, chalk board, glass, brass, chimney pots, sill stains
Shared sets used as they are: BldTrim Sheet (B02 trim), Mat QuayStone / Granite (B02 library).
Lessons from the V2 RIB reviews: no near-white salt, every bump / noise band-limited to <= 10 cycles per stud,
albedo 30..240, saturation <= 0.42, own roughness per material, wet darken 0.35 + gloss.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/textures/M_Bld_Chandlery_Ext"
N = 1024
FONT = "/System/Library/Fonts/Supplemental/"

# atlas rects (u0, v0, u1, v1), shared with build.py. Strips are full width and tile in u (trim mode).
DETAILS = {
    "FasciaL": (0.0, 0.90, 1.0, 1.0),
    "FasciaR": (0.0, 0.80, 1.0, 0.90),
    "Paint": (0.0, 0.74, 1.0, 0.80),       # strip: shopfront green paint, worn edges
    "Iron": (0.0, 0.68, 1.0, 0.74),        # strip: black-painted wrought / cast iron
    "Lead": (0.0, 0.62, 1.0, 0.68),        # strip: lead flashing
    "Door": (0.0, 0.36, 0.30, 0.62),       # lower door panels 1.2 x 0.98 m
    "Sign": (0.30, 0.36, 0.70, 0.62),      # hanging sign 0.9 x 0.6 m
    "Chalk": (0.70, 0.22, 1.0, 0.62),      # A-board 0.56 x 0.8 m
    "Glass": (0.0, 0.22, 0.30, 0.36),
    "Brass": (0.30, 0.22, 0.45, 0.36),
    "Pots": (0.45, 0.22, 0.70, 0.36),
    "Stain": (0.0, 0.0, 0.25, 0.22),       # drip streak, dark at the top (under the sill), fading down and to the sides
    "Spare": (0.25, 0.0, 1.0, 0.22),
}


def fbm(shape, beta=2.0, fmax=60.0, aniso=(1.0, 1.0), seed=0):
    """Periodic 1/f^beta noise 0..1, band-limited to fmax cycles across the image (<= 10 cycles per stud)."""
    r = np.random.default_rng(seed)
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    fa = np.sqrt((fx * aniso[1]) ** 2 + (fy * aniso[0]) ** 2)
    f = np.sqrt(fx * fx + fy * fy)
    fa[0, 0] = 1.0
    spec = np.fft.fft2(r.standard_normal(shape)) / fa ** (beta / 2.0)
    spec *= np.exp(-(f / fmax) ** 4)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def normal_from_height(h, strength, wrap=True):
    """OpenGL tangent normal: +X right, +Y = +V (up in the image)."""
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        dy, dx = np.gradient(h)
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def save(stem, alb, nor, rgh, met, darken=0.35, gloss=0.45):
    os.makedirs(OUT, exist_ok=True)
    alb = np.clip(alb, 32 / 255, 236 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    w8 = lambda a: (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(w8(alb), "RGB").save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray(w8(nor), "RGB").save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray(w8(rgh), "L").save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray(w8(met), "L").save(os.path.join(OUT, stem + "_MET.png"))
    m = met[..., None] > 0.5
    dk = np.where(m, darken * 0.3, darken)
    walb = np.clip(alb * (1 - dk), 30 / 255, 236 / 255)
    wrgh = np.clip(rgh - gloss * (0.6 + 0.4 * rgh), 0.05, 1.0)
    Image.fromarray(w8(walb), "RGB").save(os.path.join(OUT, stem + "_ALB_Wet.png"))
    Image.fromarray(w8(wrgh), "L").save(os.path.join(OUT, stem + "_RGH_Wet.png"))


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


# ---------------------------------------------------------------- slate (8 courses x 5 slates per 2 m tile = 6 studs)
def slate_set():
    s = (N, N)
    courses, per = 8, 5
    ch = N // courses
    yy, xx = np.mgrid[0:N, 0:N]
    c = yy // ch
    t = (yy % ch) / ch                              # 0 top of the exposed course (under the tail above) .. 1 tail
    off = np.where(c % 2 == 0, 0, N // (2 * per))
    sx = (xx + off) % N
    k = np.minimum(sx * per // N, per - 1)
    slot = c * per + k
    r = np.random.default_rng(11)
    tone = r.uniform(0.86, 1.1, courses * per)
    tint = r.normal(0, 0.012, (courses * per, 3))
    tilt = r.normal(0, 0.1, courses * per)
    big, mid = fbm(s, 3.0, 12, seed=1), fbm(s, 2.2, 40, seed=2)
    grain = fbm(s, 1.8, 50, aniso=(0.35, 1.0), seed=3)
    alb = rgb((76, 82, 90))[None, None, :] * tone[slot][..., None] + tint[slot]
    alb = alb * (0.92 + 0.1 * grain[..., None] + 0.06 * big[..., None])
    edgex = np.minimum((sx * per) % N, N - (sx * per) % N) / per        # px to the butt joint
    gap = 1 - smooth(0, 4.0, edgex)
    shade = 1 - smooth(0.0, 0.16, t)
    lich = smooth(0.72, 0.86, fbm(s, 2.4, 30, seed=4)) * smooth(0.35, 0.6, big)
    alb = alb * (1 - 0.4 * gap[..., None]) * (1 - 0.3 * shade[..., None])
    alb = mix(alb, rgb((128, 128, 108)), 0.55 * lich)
    tailsalt = smooth(0.86, 1.0, t) * smooth(0.55, 0.8, mid)
    alb = mix(alb, rgb((128, 132, 134)), 0.12 * tailsalt)                # faint grey salt, never white
    tail = smooth(0.0, 0.05, t) * (1 - smooth(0.96, 1.0, t))
    h = 0.5 * t * tail + tilt[slot] * ((sx * per) % N) / N * 0.3 - gap * 0.3 + 0.05 * grain + 0.06 * lich
    h = np.where(t < 0.03, h - 0.3 * (1 - t / 0.03), h)
    nor = normal_from_height(h * 6.0, 3.0)
    rgh = 0.6 + 0.08 * grain + 0.22 * lich + 0.08 * gap - 0.04 * big
    save("T_Chandlery_Slate", alb, nor, rgh, np.zeros(s), darken=0.35, gloss=0.5)


# ---------------------------------------------------------------- details atlas
GREEN = (42, 68, 56)          # Brunswick-style shopfront green, saturation 0.38
CREAM = (198, 180, 132)       # sign-writer's cream / old gold, saturation 0.33


def letters_mask(w, h, text, font, size, cap_frac, tracking_to=None, y_off=0):
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(font, size)
    widths = [d.textlength(ch, font=f) for ch in text]
    total = sum(widths)
    track = 0.0
    if tracking_to and total < tracking_to:
        track = (tracking_to - total) / max(1, len(text) - 1)
    x = (w - (total + track * (len(text) - 1))) / 2
    bb = d.textbbox((0, 0), "H", font=f)
    y = (h - (bb[3] - bb[1])) / 2 - bb[1] + y_off
    for ch, cw in zip(text, widths):
        d.text((x, y), ch, fill=255, font=f)
        x += cw + track
    return np.asarray(img, dtype=np.float64) / 255.0


def details_set():
    alb = np.zeros((N, N, 3)) + rgb(GREEN)
    rgh = np.full((N, N), 0.5)
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    big, mid = fbm((N, N), 3.0, 10, seed=21), fbm((N, N), 2.2, 40, seed=22)
    fine = fbm((N, N), 1.6, 60, seed=23)
    runs = fbm((N, N), 2.4, 40, aniso=(0.12, 1.6), seed=24)       # vertical grime runs
    grainu = fbm((N, N), 1.8, 60, aniso=(1.0, 0.08), seed=25)     # wood grain along u

    def box(name):
        u0, v0, u1, v1 = DETAILS[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N)), int(round(u0 * N)), int(round(u1 * N))

    def sl(name):
        r0, r1, c0, c1 = box(name)
        return np.s_[r0:r1, c0:c1]

    def paint(region, base=GREEN, wear=0.0, edge=None):
        a = rgb(base) * (0.9 + 0.1 * big[region][..., None] + 0.06 * grainu[region][..., None])
        g = smooth(0.6, 0.9, runs[region]) * 0.5
        a = mix(a, rgb((70, 74, 64)), 0.25 * g)
        if edge is not None:
            chip = smooth(0.55, 0.75, edge * 0.7 + mid[region] * 0.5) * wear
            under = mix(np.zeros_like(a) + rgb((132, 126, 108)), np.zeros_like(a) + rgb((112, 92, 70)),
                        smooth(0.6, 0.8, fine[region]))
            a = mix(a, under, chip)
            return a, chip, g
        return a, np.zeros(a.shape[:2]), g

    # ---- fascia: one string on a 2048 px board, split into the two rows
    r0, r1, hh = 0, 104, 104
    full_w = 2 * N
    m = letters_mask(full_w, hh, "PORT HAVEN CHANDLERY", FONT + "Georgia Bold.ttf", 84, 0.7, tracking_to=1720)
    shadow = np.roll(np.roll(m, 4, 0), 4, 1)
    shadow = np.clip(shadow - m, 0, 1)
    yy = np.arange(hh)[:, None] / hh * np.ones((1, full_w))
    border = ((np.abs(yy - 0.07) < 0.018) | (np.abs(yy - 0.93) < 0.018)).astype(float)
    boardnoise = np.concatenate([big[r0:r1], big[r0 + 200:r1 + 200]], 1)
    runs2 = np.concatenate([runs[r0:r1], runs[r0 + 300:r1 + 300]], 1)
    mid2 = np.concatenate([mid[r0:r1], mid[r0 + 300:r1 + 300]], 1)
    board = rgb(GREEN) * (0.9 + 0.12 * boardnoise[..., None])
    board = mix(board, rgb((30, 44, 38)), 0.85 * shadow)
    board = mix(board, rgb(CREAM) * 0.92, 0.85 * border)
    board = mix(board, rgb(CREAM) * (0.95 + 0.05 * boardnoise[..., None]), m)
    fade = smooth(0.0, 0.25, 1 - yy) * 0.12                                   # sun fade along the top
    board = mix(board, rgb((96, 108, 98)), fade)
    grime = smooth(0.62, 0.9, runs2) * smooth(0.3, 1.0, yy) * 0.35
    board = mix(board, rgb((66, 66, 56)), grime)
    chips = smooth(0.78, 0.86, mid2) * (smooth(0.8, 0.98, yy) + smooth(0.2, 0.02, yy))
    board = mix(board, rgb((128, 120, 100)), 0.7 * chips)
    for half, name in ((0, "FasciaL"), (1, "FasciaR")):
        q0, q1, p0, p1 = box(name)
        alb[q0:q1, p0:p1] = board[:q1 - q0, half * N:(half + 1) * N]
        rgh[q0:q1, p0:p1] = (0.42 - 0.06 * m + 0.2 * grime + 0.2 * chips)[:q1 - q0, half * N:(half + 1) * N]
        hgt[q0:q1, p0:p1] = (0.35 * m + 0.25 * border - 0.2 * chips)[:q1 - q0, half * N:(half + 1) * N]

    # ---- strips (u-tiling): paint, iron, lead. v across the strip = across the member: wear at both edges
    for name, base, wear, rg in (("Paint", GREEN, 1.0, 0.44), ("Iron", (40, 40, 40), 0.6, 0.52), ("Lead", (102, 106, 108), 0.0, 0.58)):
        reg = sl(name)
        r0, r1, c0, c1 = box(name)
        vv = (np.arange(r1 - r0)[:, None] + 0.5) / (r1 - r0) * np.ones((1, c1 - c0))
        edge = 1 - np.minimum(vv, 1 - vv) * 2                       # 1 at the strip edges (member arrises)
        a, chip, g = paint(reg, base, wear, edge ** 3)
        if name == "Iron":
            rust = smooth(0.8, 0.9, mid[reg]) * smooth(0.5, 0.9, edge)
            a = mix(a, rgb((104, 80, 62)), 0.8 * rust)
            chip = np.maximum(chip, rust)
        if name == "Lead":
            ox = smooth(0.55, 0.85, mid[reg])
            a = rgb(base) * (0.88 + 0.16 * big[reg][..., None])
            a = mix(a, rgb((140, 144, 142)), 0.25 * ox)
            a = mix(a, rgb((84, 86, 84)), 0.3 * smooth(0.6, 0.9, runs[reg]))
            chip = ox * 0.3
        alb[reg] = a
        rgh[reg] = rg + 0.25 * chip + 0.1 * g + 0.04 * fine[reg]
        hgt[reg] = 0.3 * np.sin(np.clip(vv, 0, 1) * np.pi) ** 0.5 - 0.3 * chip + 0.06 * grainu[reg]

    # ---- door: lower panels of the half-glazed door (1.2 x 0.98 m): stiles, bottom rail, two fielded panels
    r0, r1, c0, c1 = box("Door")
    reg = sl("Door")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fx, fy = (xx + 0.5) / ww, 1 - (yy + 0.5) / hh                       # fy up
    panel = np.zeros((hh, ww))
    field = np.zeros((hh, ww))
    for p, q in ((0.11, 0.47), (0.53, 0.89)):
        a0, a1 = 0.24, 0.88
        dxp = np.minimum(fx - p, q - fx) * 1.2
        dyp = np.minimum(fy - a0, a1 - fy) * 0.98
        dd = np.minimum(dxp, dyp)
        panel = np.maximum(panel, (dd > 0).astype(float))
        field = np.maximum(field, smooth(0.0, 0.05, dd))
    a, chip, g = paint(reg, GREEN, 0.0)
    kick = smooth(0.2, 0.0, fy) * smooth(0.45, 0.75, fine[reg] * 0.6 + mid[reg] * 0.5)
    a = mix(a, rgb((118, 106, 86)), 0.7 * kick)
    groove = np.zeros((hh, ww))
    for p, q in ((0.11, 0.47), (0.53, 0.89)):
        inside = (fx > p) & (fx < q) & (fy > 0.24) & (fy < 0.88)
        ed = np.minimum(np.minimum(fx - p, q - fx) * 1.2, np.minimum(fy - 0.24, 0.88 - fy) * 0.98)
        groove = np.maximum(groove, inside * (ed < 0.006))
    a = a * (1 - 0.35 * groove[..., None])
    a = mix(a, rgb((66, 68, 58)), 0.3 * smooth(0.6, 0.9, runs[reg]) * smooth(0.6, 0.0, fy))
    alb[reg] = a
    rgh[reg] = 0.42 + 0.3 * kick + 0.1 * groove + 0.04 * fine[reg]
    hgt[reg] = 0.5 * field * panel - 0.3 * groove - 0.1 * kick

    # ---- hanging sign (0.9 x 0.6 m): green board, cream double border, PORT HAVEN / anchor / CHANDLERY
    r0, r1, c0, c1 = box("Sign")
    reg = sl("Sign")
    hh, ww = r1 - r0, c1 - c0
    img = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(img)
    d.rectangle((10, 10, ww - 11, hh - 11), outline=255, width=4)
    d.rectangle((20, 20, ww - 21, hh - 21), outline=255, width=2)
    f1 = ImageFont.truetype(FONT + "Georgia Bold.ttf", 44)
    f2 = ImageFont.truetype(FONT + "Georgia Bold.ttf", 50)
    for txt, f, y in (("PORT HAVEN", f1, 34), ("CHANDLERY", f2, hh - 92)):
        w = d.textlength(txt, font=f)
        d.text(((ww - w) / 2, y), txt, fill=255, font=f)
    cx, cy = ww / 2, hh / 2 + 2
    d.ellipse((cx - 9, cy - 34, cx + 9, cy - 16), outline=255, width=4)       # anchor ring
    d.line((cx, cy - 16, cx, cy + 28), fill=255, width=6)                     # shank
    d.line((cx - 26, cy - 8, cx + 26, cy - 8), fill=255, width=5)             # stock
    d.arc((cx - 30, cy - 6, cx + 30, cy + 34), 20, 160, fill=255, width=5)    # arms
    d.polygon([(cx - 31, cy + 12), (cx - 22, cy + 24), (cx - 36, cy + 24)], fill=255)
    d.polygon([(cx + 31, cy + 12), (cx + 22, cy + 24), (cx + 36, cy + 24)], fill=255)
    d.line((70, cy, cx - 44, cy), fill=255, width=2)
    d.line((cx + 44, cy, ww - 70, cy), fill=255, width=2)
    lm = np.asarray(img.filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float64) / 255.0
    sh = np.clip(np.roll(np.roll(lm, 3, 0), 3, 1) - lm, 0, 1)
    a = rgb(GREEN) * (0.9 + 0.12 * big[reg][..., None])
    a = mix(a, rgb((30, 44, 38)), 0.8 * sh)
    a = mix(a, rgb(CREAM) * (0.95 + 0.05 * fine[reg][..., None]), lm)
    fy = 1 - (np.mgrid[0:hh, 0:ww][0] + 0.5) / hh
    grime = smooth(0.6, 0.9, runs[reg]) * smooth(0.6, 0.0, fy) * 0.35
    a = mix(a, rgb((70, 70, 58)), grime)
    chips = smooth(0.8, 0.88, mid[reg]) * 0.6
    a = mix(a, rgb((128, 120, 100)), chips)
    alb[reg] = a
    rgh[reg] = 0.4 - 0.05 * lm + 0.2 * grime + 0.2 * chips
    hgt[reg] = 0.3 * lm - 0.2 * chips

    # ---- chalk board (0.56 x 0.8 m): slate-black board, chalk lettering, erased haze
    r0, r1, c0, c1 = box("Chalk")
    reg = sl("Chalk")
    hh, ww = r1 - r0, c1 - c0
    img = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(img)
    fc = ImageFont.truetype(FONT + "Chalkduster.ttf", 30)
    fs = ImageFont.truetype(FONT + "Chalkduster.ttf", 21)
    lines = [("CHANDLERY", fc, 20), ("- open today -", fs, 66), ("ROPE  CUT TO", fs, 116), ("LENGTH", fs, 146),
             ("SHACKLES", fs, 192), ("FENDERS", fs, 222), ("FOUL WEATHER", fs, 268), ("GEAR", fs, 298),
             ("LIFEJACKETS", fs, 344), ("SERVICED", fs, 374)]
    for txt, f, y in lines:
        w = d.textlength(txt, font=f)
        d.text(((ww - w) / 2, y), txt, fill=255, font=f)
    d.line((40, 104, ww - 40, 104), fill=200, width=2)
    cm = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float64) / 255.0
    haze = smooth(0.45, 0.8, fbm((hh, ww), 2.6, 12, seed=31)) * 0.18
    a = rgb((40, 44, 44)) * (0.94 + 0.1 * big[reg][..., None])
    a = mix(a, rgb((96, 98, 96)), haze)
    a = mix(a, rgb((190, 190, 182)), cm * (0.75 + 0.25 * fine[reg]))
    alb[reg] = a
    rgh[reg] = 0.86 + 0.06 * cm
    hgt[reg] = 0.05 * cm

    # ---- glass: dark, glossy, dirty corners
    r0, r1, c0, c1 = box("Glass")
    reg = sl("Glass")
    yy, xx = np.mgrid[0:r1 - r0, 0:c1 - c0]
    e = np.minimum(np.minimum(yy, r1 - r0 - 1 - yy), np.minimum(xx, c1 - c0 - 1 - xx)) / (r1 - r0)
    dirt = (1 - smooth(0.0, 0.22, e)) * (0.5 + 0.5 * mid[reg])
    alb[reg] = mix(np.zeros((r1 - r0, c1 - c0, 3)) + rgb((44, 52, 58)), np.zeros((r1 - r0, c1 - c0, 3)) + rgb((92, 92, 84)), 0.25 * dirt)
    rgh[reg] = 0.05 + 0.3 * dirt
    hgt[reg] = 0

    # ---- brass (door knob, letter plate, kick plate): metal, tarnish kept above the metal albedo floor
    reg = sl("Brass")
    tarn = smooth(0.5, 0.8, mid[reg])
    alb[reg] = rgb((228, 204, 144)) * (0.98 - 0.04 * tarn[..., None]) + 0.03 * (big[reg][..., None] - 0.5)
    met[reg] = 1.0
    rgh[reg] = 0.3 + 0.2 * tarn
    hgt[reg] = 0.05 * fine[reg]

    # ---- chimney pots: weathered terracotta, sooted towards the top
    r0, r1, c0, c1 = box("Pots")
    reg = sl("Pots")
    fy = 1 - (np.mgrid[0:r1 - r0, 0:c1 - c0][0] + 0.5) / (r1 - r0)
    a = rgb((146, 106, 86)) * (0.88 + 0.16 * big[reg][..., None])
    a = mix(a, rgb((62, 56, 52)), 0.75 * smooth(0.55, 1.0, fy) * (0.6 + 0.4 * runs[reg]))
    lichen = smooth(0.75, 0.9, mid[reg]) * smooth(0.5, 0.0, fy)
    a = mix(a, rgb((120, 118, 96)), 0.4 * lichen)
    alb[reg] = a
    rgh[reg] = 0.86 + 0.06 * fine[reg]
    hgt[reg] = 0.2 * big[reg]

    # ---- sill stain: drip streak on QuayStone; centre dark at the top, fading to the stone's mean tone
    r0, r1, c0, c1 = box("Stain")
    reg = sl("Stain")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fx, fy = (xx + 0.5) / ww, 1 - (yy + 0.5) / hh
    across = 1 - smooth(0.0, 0.5, np.abs(fx - 0.5) * 2) * 0.55
    down = smooth(0.0, 0.85, fy)                                      # strong at the top (fy 1), gone at the tip
    k = np.clip(across * down * (0.75 + 0.35 * runs[reg]), 0, 1)
    stone = rgb((128, 117, 103)) * (0.95 + 0.08 * big[reg][..., None])
    alb[reg] = mix(stone, rgb((70, 74, 64)), 0.75 * k)
    rgh[reg] = 0.82 - 0.1 * k
    hgt[reg] = 0.05 * big[reg]

    # ---- spare: plain worn green paint
    reg = sl("Spare")
    a, _, g = paint(reg, GREEN, 0.0)
    alb[reg] = a
    rgh[reg] = 0.45 + 0.1 * g

    nor = normal_from_height(hgt, 2.0, wrap=False)
    save("T_Chandlery_Details", alb, nor, rgh, met, darken=0.33, gloss=0.42)


if __name__ == "__main__":
    slate_set()
    details_set()
    print("ok")
