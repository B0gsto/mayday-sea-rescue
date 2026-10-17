"""H2 M_Bld_Chandlery_Int texture sets (system python3 + numpy + Pillow, no heavy slot). Procedural, no AI images.

    python3 art/source/buildings/M_Bld_Chandlery_Int/maketex.py

Writes assets/textures/M_Bld_Chandlery_Int/T_ChandleryInt_<Set>_ALB/NOR/RGH/MET (OpenGL normals, greyscale RGH/MET,
no _Wet: an interior):
  Pine     1024, tiles 2.4 x 2.4 m: 16 worn pine floorboards along U (0.15 m), staggered butt joints, nail pairs on 0.4 m
           joist lines, varnish worn through in low-frequency traffic patches, grime in the gaps, knots
  Lining   1024, tiles 1.2 x 1.2 m: painted tongue-and-groove, 10 vertical 0.12 m boards with V-joints, ivory eggshell,
           brush drag, slight yellowing, filled nail punches
  Joinery  1024 trim sheet, strips along U (tiling): Beam (aged oak, checks, adze), Plank (stained pine), Panel (raised
           and fielded counter panel, one per U), Rail (polished mahogany), Painted (dark green eggshell, chipped)
  Details  2048 atlas (rects in DETAILS, shared with build.py): brass, enamel, iron, lamp glass (emissive-ready), flex,
           rope, mirror, galvanised hooks, counter top, chart, service cards, drawer labels, logbook, till keys and
           sign, slatwall, blister packs, curtain canvas, coir mat, paper, book cloth, rubber
Noise is band-limited to at most 8 cycles per stud at the set's texel density (V2 lesson: finer bump aliases at 1024);
albedo kept 32..236 sRGB (metal 184..244), saturation clamped to 0.43.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/textures/M_Bld_Chandlery_Int"
STEM = "T_ChandleryInt"
rng = np.random.default_rng(2207)

JOINERY = {"Beam": (0.0, 0.25), "Plank": (0.25, 0.45), "Panel": (0.45, 0.75), "Rail": (0.75, 0.875), "Painted": (0.875, 1.0)}

DETAILS = {
    "Brass": (0.0, 0.875, 0.125, 1.0), "EnamelOut": (0.125, 0.875, 0.25, 1.0), "EnamelIn": (0.25, 0.875, 0.375, 1.0),
    "Iron": (0.375, 0.875, 0.5, 1.0), "Glow": (0.5, 0.875, 0.625, 1.0), "Flex": (0.625, 0.875, 0.6875, 1.0),
    "Rope": (0.6875, 0.875, 0.75, 1.0), "Mirror": (0.75, 0.875, 0.875, 1.0), "Hook": (0.875, 0.875, 1.0, 1.0),
    "CounterTop": (0.0, 0.75, 1.0, 0.875),
    "Chart": (0.0, 0.5, 0.5, 0.75),
    "Card0": (0.5, 0.5, 0.625, 0.75), "Card1": (0.625, 0.5, 0.75, 0.75), "Card2": (0.75, 0.5, 0.875, 0.75),
    "Card3": (0.875, 0.5, 1.0, 0.75),
    "Logbook": (0.5, 0.375, 0.75, 0.5), "TillKeys": (0.75, 0.375, 0.875, 0.5), "TillSign": (0.875, 0.375, 1.0, 0.5),
    "Slatwall": (0.5, 0.25, 0.75, 0.375),
    "Pack0": (0.75, 0.25, 0.8125, 0.375), "Pack1": (0.8125, 0.25, 0.875, 0.375), "Pack2": (0.875, 0.25, 0.9375, 0.375),
    "Pack3": (0.9375, 0.25, 1.0, 0.375),
    "Curtain": (0.0, 0.0, 0.25, 0.25), "Mat": (0.25, 0.0, 0.5, 0.25), "Paper": (0.5, 0.125, 0.625, 0.25),
    "Cloth": (0.625, 0.125, 0.75, 0.25), "Rubber": (0.75, 0.125, 0.875, 0.25),
}
for i in range(16):   # drawer label fronts, 4 x 4 grid in (0, 0.25) .. (0.5, 0.5)
    c, r = i % 4, i // 4
    DETAILS["Drawer%d" % i] = (c * 0.125, 0.25 + r * 0.0625, (c + 1) * 0.125, 0.25 + (r + 1) * 0.0625)

LABELS = ["SHACKLES 6", "SHACKLES 8", "SNAP HOOKS", "THIMBLES", "CLEVIS PINS", "SPLIT RINGS", "SWIVELS", "EYE BOLTS",
          "PAD EYES", "BULLDOG GRIPS", "SAIL NEEDLES", "WHIPPING TWINE", "HOSE CLIPS", "SPLIT PINS", "CABLE TIES", "FUSES"]
CARDS = [("2x CASH", "Double Cash", "on every operation", "coins"),
         ("VIP CREW CARD", "Crew perks", "berth, boost, badge", "anchor"),
         ("QUICK LAUNCH", "Skip the slip", "launch from any berth", "bow"),
         ("STARTER KIT", "Gear, livery", "and a head start", "kit")]
PACKS = [("S/S SHACKLE", "6 mm  x2", (52, 62, 84)), ("SNAP SHACKLE", "swivel eye", (98, 52, 50)),
         ("NYLON CLEAT", "150 mm", (78, 86, 58)), ("THIMBLES", "8 mm  x4", (136, 106, 52))]

FONT_B = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_R = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_S = "/System/Library/Fonts/Supplemental/Georgia.ttf"
FONT_H = "/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf"


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype(FONT_R, size)


def fbm(shape, beta=2.0, fc=0.06, aniso=(1.0, 1.0), seed=None):
    """Periodic 1/f^beta noise 0..1, band-limited: no energy above fc cycles per pixel (anti-alias rule)."""
    r = np.random.default_rng(seed) if seed is not None else rng
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt((fx * aniso[1]) ** 2 + (fy * aniso[0]) ** 2)
    f[0, 0] = 1.0
    spec = np.fft.fft2(r.standard_normal(shape)) / f ** (beta / 2.0)
    raw = np.sqrt(fx * fx + fy * fy)
    spec *= np.exp(-(raw / fc) ** 4)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def blur(a, px):
    """Separable box-ish blur (wrap), keeps hard features below the frequency cap."""
    k = max(1, int(px))
    out = a.copy()
    for ax in (0, 1):
        acc = np.zeros_like(out)
        for d in range(-k, k + 1):
            acc += np.roll(out, d, ax)
        out = acc / (2 * k + 1)
    return out


def normal_from_height(h, strength, wrap=True):
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


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def clamp_sat(alb, smax=0.43):
    mx = alb.max(-1, keepdims=True)
    mn = alb.min(-1, keepdims=True)
    s = (mx - mn) / np.maximum(mx, 1e-6)
    y = (alb * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    t = np.clip((s - smax) / np.maximum(s, 1e-6), 0, 1)
    return alb * (1 - t) + y * t


def save(stem, alb, nor, rgh, met):
    os.makedirs(OUT, exist_ok=True)
    alb = clamp_sat(alb)
    m = met[..., None] > 0.5
    y = (alb * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True)
    lo = np.where(m, 186 / 255, 34 / 255)
    hi = np.where(m, 242 / 255, 234 / 255)
    scale = np.where(y < lo, lo / np.maximum(y, 1e-4), np.where(y > hi, hi / np.maximum(y, 1e-4), 1.0))
    alb = np.clip(alb * scale, 0, 1)
    rgh = np.clip(rgh, 0.04, 1.0)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray((np.clip(nor, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray((rgh * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray((np.clip(met, 0, 1) * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(OUT, stem + "_MET.png"))
    print("[tex]", stem, alb.shape[:2])


def wood_grain(shape, fc, seed, stretch=0.08):
    """Long grain along U (image x): stretched noise plus a slow ring sine."""
    g = fbm(shape, 1.8, fc, aniso=(1.0, stretch), seed=seed)
    g2 = fbm(shape, 2.6, fc * 0.5, aniso=(1.0, 0.2), seed=seed + 1)
    rings = 0.5 + 0.5 * np.sin(g2 * 26.0)
    return 0.6 * g + 0.4 * rings


# ------------------------------------------------------------------ Pine floorboards (2.4 m tile, 142 px/stud)
def pine_set():
    N = 1024
    fc = 8 * 7.2 / N           # 8 cycles per stud
    s = (N, N)
    boards = 16
    bh = N // boards
    yy, xx = np.mgrid[0:N, 0:N]
    row = yy // bh
    t = (yy % bh) / bh
    r = np.random.default_rng(31)
    seg = np.zeros(s, int)
    joint = np.zeros(s)
    for b in range(boards):                       # 1 or 2 butt joints a row (board lengths 1.2 .. 2.4 m), wrapped
        n = 1 + int(r.random() < 0.6)
        cuts = np.sort(r.uniform(0, N, n)).astype(int)
        rr = slice(b * bh, (b + 1) * bh)
        idx = np.zeros(N, int)
        for k, c in enumerate(cuts):
            idx[(np.arange(N) - c) % N < ((cuts[(k + 1) % n] - c) % N or N)] = b * 4 + k
            d = np.minimum((np.arange(N) - c) % N, (c - np.arange(N)) % N)
            joint[rr] = np.maximum(joint[rr], (1 - smooth(0, 3.5, d))[None, :])
        seg[rr] = idx[None, :]
    tone = r.uniform(0.84, 1.12, boards * 4 + 4)
    warm = r.normal(0, 0.035, boards * 4 + 4)
    grain = wood_grain(s, fc, 5)
    big = fbm(s, 3.0, fc * 0.3, seed=7)
    mid = fbm(s, 2.4, fc * 0.6, seed=8)
    base = rgb((150, 116, 86))
    alb = base[None, None, :] * tone[seg][..., None] * (0.86 + 0.24 * grain[..., None])
    alb[..., 0] *= 1 + warm[seg]
    alb[..., 2] *= 1 - warm[seg]
    # knots
    knot = np.zeros(s)
    for _ in range(9):
        cx, cy, rx, ry = r.uniform(0, N), r.uniform(0, N), r.uniform(8, 16), r.uniform(5, 9)
        dx = (xx - cx + N / 2) % N - N / 2
        dy = (yy - cy + N / 2) % N - N / 2
        knot = np.maximum(knot, 1 - smooth(0.4, 1.0, np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)))
    alb = alb * (1 - 0.45 * knot[..., None]) + rgb((86, 58, 40)) * 0.45 * knot[..., None]
    # gaps and edge grime (soft, 4 px), worn varnish (traffic), scuffs
    edge = np.minimum(t, 1 - t) * bh
    gap = 1 - smooth(0.0, 4.0, edge)
    gap = np.maximum(gap, joint)
    grime = (1 - smooth(0.0, 10.0, edge)) * (0.5 + 0.5 * mid)
    worn = smooth(0.48, 0.72, big * 0.7 + mid * 0.3)
    alb = alb * (1 - 0.18 * worn[..., None]) + rgb((168, 150, 126)) * 0.18 * worn[..., None]
    scuff = smooth(0.7, 0.85, fbm(s, 2.2, fc * 0.8, seed=9)) * 0.6
    alb = alb * (1 - 0.2 * scuff[..., None]) + rgb((92, 80, 66)) * 0.2 * scuff[..., None]
    alb = alb * (1 - 0.35 * grime[..., None]) * (1 - 0.6 * gap[..., None])
    # nail pairs on joist lines every 0.4 m (6 a tile), 2 a board, dark iron heads with a rust halo
    nails = np.zeros(s)
    halo = np.zeros(s)
    for jx in range(6):
        cx = (jx + 0.5) * N / 6 + 9
        for b in range(boards):
            for f in (0.27, 0.73):
                cy = (b + f) * bh
                d = np.sqrt(((xx - cx + N / 2) % N - N / 2) ** 2 + ((yy - cy + N / 2) % N - N / 2) ** 2)
                nails = np.maximum(nails, 1 - smooth(2.5, 4.5, d))
                halo = np.maximum(halo, 1 - smooth(3.0, 9.0, d))
    alb = alb * (1 - 0.18 * halo[..., None]) + rgb((96, 70, 50)) * 0.18 * halo[..., None]
    alb = alb * (1 - nails[..., None]) + rgb((58, 54, 50)) * nails[..., None]
    h = 0.6 * (1 - gap) + 0.08 * grain + 0.15 * mid - 0.25 * worn * 0.3 - 0.2 * nails + 0.1 * np.sin(np.pi * t)
    h = blur(h, 1)
    nor = normal_from_height(h * 3.0, 3.0)
    rgh = 0.46 + 0.28 * worn + 0.12 * scuff + 0.2 * gap + 0.05 * grain
    rgh = np.where(nails > 0.5, 0.55, rgh)
    save(STEM + "_Pine", alb, nor, rgh, np.zeros(s))


# ------------------------------------------------------------------ painted tongue-and-groove (1.2 m tile, 284 px/stud)
def lining_set():
    N = 1024
    fc = 8 * 3.6 / N
    s = (N, N)
    boards = 10
    bw = N / boards
    yy, xx = np.mgrid[0:N, 0:N]
    col = (xx // bw).astype(int)
    t = (xx % bw) / bw
    r = np.random.default_rng(41)
    tone = r.uniform(0.96, 1.04, boards)
    brush = fbm(s, 2.0, fc, aniso=(0.08, 1.0), seed=12)        # vertical drag
    big = fbm(s, 3.2, fc * 0.25, seed=13)
    paint = rgb((190, 180, 156))
    alb = paint[None, None, :] * tone[col][..., None] * (0.95 + 0.07 * brush[..., None])
    yellow = smooth(0.5, 0.85, big)[..., None]
    alb = alb * (1 - 0.1 * yellow) + rgb((176, 160, 122)) * 0.1 * yellow
    edge = np.minimum(t, 1 - t) * bw
    vj = 1 - smooth(0.0, 6.0, edge)
    alb = alb * (1 - 0.42 * vj[..., None])
    alb = alb * (1 - 0.1 * (1 - smooth(0, 14, edge))[..., None])
    # filled nail punches (secret-nailed through the tongue: shallow dimples near one edge every 0.6 m)
    punch = np.zeros(s)
    for b in range(boards):
        for k in range(2):
            cx, cy = (b + 0.86) * bw, (k + 0.3 + 0.2 * r.random()) * N / 2
            d = np.sqrt(((xx - cx + N / 2) % N - N / 2) ** 2 + ((yy - cy + N / 2) % N - N / 2) ** 2)
            punch = np.maximum(punch, 1 - smooth(2.0, 5.0, d))
    alb = alb * (1 - 0.12 * punch[..., None])
    stains = smooth(0.72, 0.9, fbm(s, 2.6, fc * 0.4, seed=14))
    alb = alb * (1 - 0.1 * stains[..., None]) + rgb((140, 126, 100)) * 0.1 * stains[..., None]
    h = -vj * 1.0 + 0.04 * brush - 0.3 * punch
    nor = normal_from_height(blur(h, 1) * 3.0, 3.0)
    rgh = 0.56 + 0.06 * brush + 0.2 * vj + 0.06 * stains
    save(STEM + "_Lining", alb, nor, rgh, np.zeros(s))


# ------------------------------------------------------------------ joinery trim sheet (strips along U)
def joinery_set():
    N = 1024
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    hgt = np.zeros((N, N))
    fc = 8 * 6.0 / N

    def rows(name):
        v0, v1 = JOINERY[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N))

    # Beam: aged oak, 2 m a U
    r0, r1 = rows("Beam")
    sh = (r1 - r0, N)
    g = wood_grain(sh, fc, 51, 0.05)
    big = fbm(sh, 3.0, fc * 0.3, seed=52)
    chk = smooth(0.80, 0.92, fbm(sh, 1.6, fc, aniso=(1.0, 0.03), seed=53))     # drying checks along the grain
    adze = fbm(sh, 2.6, fc * 0.45, aniso=(1.0, 0.6), seed=54)
    a = rgb((98, 78, 60)) * (0.82 + 0.3 * g[..., None]) * (0.9 + 0.18 * big[..., None])
    a = a * (1 - 0.55 * chk[..., None])
    soot = smooth(0.6, 0.9, big)[..., None]
    a = a * (1 - 0.12 * soot)
    alb[r0:r1] = a
    hgt[r0:r1] = 0.5 * adze + 0.1 * g - 0.8 * chk
    rgh[r0:r1] = 0.72 + 0.08 * g + 0.1 * chk
    # Plank: stained pine
    r0, r1 = rows("Plank")
    sh = (r1 - r0, N)
    g = wood_grain(sh, fc, 61, 0.07)
    big = fbm(sh, 3.0, fc * 0.3, seed=62)
    worn = smooth(0.55, 0.8, big)
    a = rgb((128, 100, 74)) * (0.85 + 0.26 * g[..., None])
    a = a * (1 - 0.15 * worn[..., None]) + rgb((156, 134, 104)) * 0.15 * worn[..., None]
    yy = np.arange(r1 - r0)[:, None] / (r1 - r0)
    a = a * (1 - 0.15 * (1 - smooth(0.0, 0.06, np.minimum(yy, 1 - yy))))[..., None]
    alb[r0:r1] = a
    hgt[r0:r1] = 0.1 * g
    rgh[r0:r1] = 0.52 + 0.18 * worn + 0.05 * g
    # Panel: raised-and-fielded panel, one a U, varnished pine, kick wear at the bottom
    r0, r1 = rows("Panel")
    hh = r1 - r0
    sh = (hh, N)
    yy, xx = np.mgrid[0:hh, 0:N]
    fy = yy / hh                  # 0 = top of the strip (the counter's top rail)
    fx = xx / N
    dxs = np.minimum(fx, 1 - fx)  # stile centred on U 0 (wraps)
    rail_t, rail_b, stile, bev = 0.16, 0.22, 0.075, 0.035
    inx = smooth(stile, stile + 0.004, dxs)
    iny = smooth(rail_t, rail_t + 0.01, fy) * (1 - smooth(1 - rail_b - 0.01, 1 - rail_b, fy))
    field = inx * iny
    dpx = np.minimum(dxs - stile, 9)
    ex = np.clip((dxs - stile) / bev, 0, 1)
    ey = np.clip(np.minimum((fy - rail_t) / (bev * 3.1), (1 - rail_b - fy) / (bev * 3.1)), 0, 1)
    raise_ = np.minimum(ex, ey) * field
    g = wood_grain(sh, fc, 71, 0.07)
    gv = wood_grain((N, hh), fc, 72, 0.07).T          # stiles: grain runs vertically
    a_rail = rgb((136, 106, 78)) * (0.86 + 0.24 * g[..., None])
    a_stile = rgb((132, 102, 74)) * (0.86 + 0.24 * gv[..., None])
    is_stile = (dxs < stile) & (fy > 0.02) & (fy < 0.98)
    a = np.where(is_stile[..., None], a_stile, a_rail)
    a = np.where((field > 0.5)[..., None], rgb((142, 110, 80)) * (0.86 + 0.24 * g[..., None]), a)
    groove = (1 - smooth(0.0, 0.006, np.abs(dxs - stile))) * iny + (1 - smooth(0.0, 0.012, np.minimum(np.abs(fy - rail_t), np.abs(fy - (1 - rail_b))))) * inx
    a = a * (1 - 0.35 * np.clip(groove, 0, 1)[..., None])
    kick = smooth(0.8, 1.0, fy) * (0.4 + 0.6 * fbm(sh, 2.2, fc * 0.6, seed=73))
    a = a * (1 - 0.25 * kick[..., None]) + rgb((84, 70, 58)) * 0.25 * kick[..., None]
    alb[r0:r1] = a
    hgt[r0:r1] = 0.9 * raise_ + 0.25 * field - 0.6 * np.clip(groove, 0, 1) + 0.05 * g
    rgh[r0:r1] = 0.38 + 0.25 * kick + 0.05 * g
    # Rail: polished mahogany
    r0, r1 = rows("Rail")
    sh = (r1 - r0, N)
    g = wood_grain(sh, fc, 81, 0.06)
    a = rgb((108, 74, 60)) * (0.84 + 0.26 * g[..., None])
    hand = smooth(0.6, 0.85, fbm(sh, 2.8, fc * 0.3, seed=82))
    a = a * (1 + 0.12 * hand[..., None])
    alb[r0:r1] = a
    hgt[r0:r1] = 0.05 * g
    rgh[r0:r1] = 0.3 + 0.06 * g - 0.08 * hand
    # Painted: dark green eggshell over timber, chips show wood
    r0, r1 = rows("Painted")
    sh = (r1 - r0, N)
    br = fbm(sh, 2.0, fc, aniso=(1.0, 0.1), seed=91)
    chip = smooth(0.78, 0.84, fbm(sh, 2.0, fc * 0.8, seed=92)) * smooth(0.4, 0.7, fbm(sh, 3.0, fc * 0.3, seed=93))
    a = rgb((58, 78, 66)) * (0.94 + 0.1 * br[..., None])
    a = a * (1 - chip[..., None]) + rgb((132, 108, 82)) * chip[..., None]
    alb[r0:r1] = a
    hgt[r0:r1] = 0.04 * br - 0.4 * chip
    rgh[r0:r1] = 0.44 + 0.05 * br + 0.3 * chip
    nor = normal_from_height(blur(hgt, 1) * 3.0, 3.0)
    save(STEM + "_Joinery", alb, nor, rgh, np.zeros((N, N)))


# ------------------------------------------------------------------ details atlas (2048)
def details_set():
    N = 2048
    alb = np.full((N, N, 3), 0.42)
    rgh = np.full((N, N), 0.7)
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    fc = 0.05
    big = fbm((N, N), 3.0, fc * 0.25, seed=101)
    mid = fbm((N, N), 2.3, fc * 0.6, seed=102)
    fine = fbm((N, N), 1.6, fc, seed=103)

    def box(name):
        u0, v0, u1, v1 = DETAILS[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N)), int(round(u0 * N)), int(round(u1 * N))

    def put(name, a, r, m=0.0, h=None):
        r0, r1, c0, c1 = box(name)
        alb[r0:r1, c0:c1] = a
        rgh[r0:r1, c0:c1] = r
        met[r0:r1, c0:c1] = m
        if h is not None:
            hgt[r0:r1, c0:c1] = h

    def reg(name, arr):
        r0, r1, c0, c1 = box(name)
        return arr[r0:r1, c0:c1]

    def text_img(w, h, draw_fn, ss=2):
        img = Image.new("RGB", (w * ss, h * ss), (0, 0, 0))
        d = ImageDraw.Draw(img)
        draw_fn(d, ss)
        return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255.0

    # metals
    tarn = smooth(0.55, 0.85, reg("Brass", big))
    put("Brass", rgb((224, 194, 132)) * (0.96 + 0.06 * reg("Brass", mid)[..., None]) * (1 - 0.06 * tarn[..., None]),
        0.26 + 0.2 * tarn + 0.05 * reg("Brass", fine), 1.0, 0.1 * reg("Brass", mid))
    put("Mirror", rgb((212, 214, 212)) * (1 - 0.03 * reg("Mirror", big)[..., None]), 0.04 + 0.05 * smooth(0.7, 0.9, reg("Mirror", big)), 1.0)
    put("Hook", rgb((192, 192, 188)) * (0.97 + 0.05 * reg("Hook", mid)[..., None]), 0.42 + 0.1 * reg("Hook", fine), 1.0)
    # enamel shade: green outer with chips to black iron, cream inner
    ch = smooth(0.8, 0.86, reg("EnamelOut", fine)) * smooth(0.5, 0.7, reg("EnamelOut", big))
    put("EnamelOut", rgb((48, 80, 64)) * (1 - ch[..., None]) + rgb((44, 42, 40)) * ch[..., None], 0.22 + 0.5 * ch, 0.0, -0.3 * ch)
    put("EnamelIn", rgb((214, 208, 190)) * (0.97 + 0.04 * reg("EnamelIn", mid)[..., None]), 0.18 + 0.05 * reg("EnamelIn", mid))
    put("Iron", rgb((48, 48, 46)) * (0.92 + 0.15 * reg("Iron", mid)[..., None]), 0.58 + 0.1 * reg("Iron", fine), 0.0, 0.3 * reg("Iron", fine))
    put("Glow", rgb((236, 224, 196)) * (0.97 + 0.03 * reg("Glow", big)[..., None]), 0.14)
    # cloth flex: diagonal braid in low frequency
    r0, r1, c0, c1 = box("Flex")
    yy, xx = np.mgrid[0:r1 - r0, 0:c1 - c0]
    br = 0.5 + 0.5 * np.sin((xx + yy) * 2 * np.pi / 32)
    put("Flex", rgb((92, 72, 56)) * (0.88 + 0.16 * br[..., None]), 0.85, 0.0, 0.3 * br)
    # rope: three-strand lay as diagonal bands (low frequency), manila
    r0, r1, c0, c1 = box("Rope")
    yy, xx = np.mgrid[0:r1 - r0, 0:c1 - c0]
    lay = 0.5 + 0.5 * np.cos((xx * 0.7 + yy) * 2 * np.pi / 48)
    put("Rope", rgb((150, 128, 94)) * (0.78 + 0.28 * lay[..., None]) * (0.95 + 0.08 * reg("Rope", mid)[..., None]), 0.9, 0.0, lay)
    put("Rubber", rgb((46, 46, 45)) * (0.95 + 0.08 * reg("Rubber", mid)[..., None]), 0.88)
    put("Paper", rgb((208, 200, 180)) * (0.96 + 0.05 * reg("Paper", mid)[..., None]), 0.85)
    put("Cloth", rgb((46, 58, 78)) * (0.92 + 0.12 * reg("Cloth", mid)[..., None]), 0.82, 0.0, 0.1 * reg("Cloth", fine))

    # counter top: worn varnished pine, u along the counter (6.7 m), v front (0) to back (1); hand wear at the front edge,
    # heavy wear in front of the till (u ~0.73) and the logbook (u ~0.23), mug rings, scored marks
    r0, r1, c0, c1 = box("CounterTop")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fu, fv = xx / ww, 1 - yy / hh
    gr = wood_grain((hh, ww), 0.06, 111, 0.03)
    plank = (np.floor(fv * 5) % 2)
    a = rgb((140, 104, 72)) * (0.84 + 0.22 * gr[..., None]) * (0.97 + 0.05 * plank[..., None])
    seams = 1 - smooth(0.0, 0.012, np.abs(((fv * 5) % 1) - 0.5) * 0 + np.minimum((fv * 5) % 1, 1 - (fv * 5) % 1))
    front = 1 - smooth(0.0, 0.35, fv)
    hot = np.exp(-((fu - 0.73) / 0.06) ** 2) + np.exp(-((fu - 0.23) / 0.05) ** 2) * 0.7
    wear = np.clip(front * (0.45 + 0.55 * hot) * (0.6 + 0.4 * reg("CounterTop", mid)), 0, 1)
    a = a * (1 - 0.3 * wear[..., None]) + rgb((176, 150, 118)) * 0.3 * wear[..., None]
    rings = np.zeros((hh, ww))
    rr = np.random.default_rng(5)
    for _ in range(5):
        cx, cy, rad = rr.uniform(0.05, 0.95) * ww, rr.uniform(0.3, 0.9) * hh, rr.uniform(16, 22)
        d = np.sqrt((xx - cx) ** 2 + ((yy - cy) * 1.0) ** 2)
        rings = np.maximum(rings, np.exp(-((d - rad) / 2.5) ** 2) * rr.uniform(0.4, 0.8))
    a = a * (1 - 0.25 * rings[..., None])
    a = a * (1 - 0.4 * seams[..., None])
    alb[r0:r1, c0:c1] = a
    rgh[r0:r1, c0:c1] = 0.34 + 0.32 * wear + 0.1 * rings + 0.1 * seams
    hgt[r0:r1, c0:c1] = -0.4 * seams + 0.05 * gr

    # chart: an Admiralty-style chart of Port Haven approaches (paper, land tint, depth contours, compass rose, soundings)
    r0, r1, c0, c1 = box("Chart")
    hh, ww = r1 - r0, c1 - c0
    cy_, cx_ = np.mgrid[0:hh, 0:ww]
    land_f = fbm((hh, ww), 3.4, 0.02, seed=121)
    coast = cx_ / ww * 0.9 + (land_f - 0.5) * 0.7
    land = coast > 0.62
    depth = np.clip((0.62 - coast) / 0.62, 0, 1)
    a = np.where(land[..., None], rgb((196, 182, 148)), rgb((216, 216, 204)))
    shallow = (depth < 0.18) & ~land
    a = np.where(shallow[..., None], rgb((178, 194, 196)), a)
    cont = np.zeros((hh, ww))
    for lev in (0.18, 0.36, 0.6):
        cont = np.maximum(cont, 1 - smooth(0.0, 0.006, np.abs(depth - lev)))
    a = a * (1 - 0.35 * cont[..., None]) + rgb((96, 112, 128)) * 0.35 * cont[..., None]
    coastline = 1 - smooth(0.0, 0.006, np.abs(coast - 0.62))
    a = a * (1 - 0.8 * coastline[..., None]) + rgb((58, 54, 46)) * 0.8 * coastline[..., None]

    def chart_ink(d, ss):
        f = font(FONT_S, 13 * ss)
        fb = font(FONT_S, 26 * ss)
        rr2 = np.random.default_rng(9)
        for _ in range(140):
            x, y = rr2.uniform(10, ww * 0.6), rr2.uniform(10, hh - 10)
            d.text((x * ss, y * ss), str(int(rr2.integers(2, 40))), fill=(255, 255, 255), font=f)
        d.text((ww * 0.68 * ss, hh * 0.08 * ss), "PORT HAVEN", fill=(255, 255, 255), font=fb)
        d.text((ww * 0.68 * ss, hh * 0.16 * ss), "and approaches", fill=(255, 255, 255), font=f)
        for k in range(0, ww, 128):
            d.line((k * ss, 0, k * ss, hh * ss), fill=(150, 150, 150), width=ss)
        for k in range(0, hh, 128):
            d.line((0, k * ss, ww * ss, k * ss), fill=(150, 150, 150), width=ss)
        cx, cy, R = 0.3 * ww * ss, 0.6 * hh * ss, 90 * ss
        for rad in (R, R * 0.8):
            d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), outline=(255, 255, 255), width=2 * ss)
        for k in range(32):
            ang = k * np.pi / 16
            l = R * (0.62 if k % 4 else 0.0)
            d.line((cx + np.cos(ang) * l, cy + np.sin(ang) * l, cx + np.cos(ang) * R, cy + np.sin(ang) * R), fill=(255, 255, 255), width=ss)
        for k in range(4):
            ang = k * np.pi / 2
            p = [(cx + np.cos(ang) * R * 0.95, cy + np.sin(ang) * R * 0.95),
                 (cx + np.cos(ang + 0.25) * R * 0.18, cy + np.sin(ang + 0.25) * R * 0.18), (cx, cy),
                 (cx + np.cos(ang - 0.25) * R * 0.18, cy + np.sin(ang - 0.25) * R * 0.18)]
            d.polygon(p, outline=(255, 255, 255), fill=(200, 200, 200))
        d.rectangle((6 * ss, 6 * ss, (ww - 7) * ss, (hh - 7) * ss), outline=(255, 255, 255), width=3 * ss)

    ink = text_img(ww, hh, chart_ink)[..., 0]
    rose = np.zeros((hh, ww))
    rose_c = np.sqrt((cx_ - 0.3 * ww) ** 2 + (cy_ - 0.6 * hh) ** 2) < 92
    a = a * (1 - 0.75 * ink[..., None]) + np.where(rose_c[..., None], rgb((128, 86, 104)), rgb((52, 52, 56))) * 0.75 * ink[..., None]
    fold = (1 - smooth(0, 3, np.abs(cx_ - ww / 2))) * 0.5 + (1 - smooth(0, 3, np.abs(cy_ - hh / 2))) * 0.5
    age = smooth(0.5, 0.9, fbm((hh, ww), 3.0, 0.02, seed=122))
    a = a * (1 - 0.1 * fold[..., None]) * (1 - 0.08 * age[..., None])
    alb[r0:r1, c0:c1] = a
    rgh[r0:r1, c0:c1] = 0.82
    hgt[r0:r1, c0:c1] = -0.3 * fold

    # service cards: framed passes behind the counter (card 0.32 x 0.64 m = 256 x 512 px)
    def card_fn(i):
        title, l1, l2, icon = CARDS[i]

        def fn(d, ss):
            w, h = 256 * ss, 512 * ss
            d.rectangle((0, 0, w, h), fill=(214, 204, 178))
            d.rectangle((10 * ss, 10 * ss, w - 10 * ss, h - 10 * ss), outline=(44, 56, 82), width=5 * ss)
            d.rectangle((20 * ss, 20 * ss, w - 20 * ss, h - 20 * ss), outline=(150, 120, 60), width=2 * ss)
            fs = font(FONT_S, 15 * ss)
            ft = font(FONT_B, (30 if len(title) < 10 else 22) * ss)
            fr = font(FONT_R, 17 * ss)
            for txt, f, y, col in (("PORT HAVEN CHANDLERY", fs, 38, (44, 56, 82)), (title, ft, 290, (44, 56, 82)),
                                   (l1, fr, 345, (60, 56, 50)), (l2, fr, 370, (60, 56, 50)),
                                   ("ask at the counter", fs, 450, (110, 80, 46))):
                tw = d.textlength(txt, font=f)
                d.text(((w - tw) / 2, y * ss), txt, fill=col, font=f)
            cx, cy = w / 2, 170 * ss
            ink = (44, 56, 82)
            if icon == "coins":
                for k in range(4):
                    d.ellipse((cx - 50 * ss, cy + (30 - k * 18) * ss, cx + 50 * ss, cy + (58 - k * 18) * ss), fill=(176, 146, 80), outline=ink, width=2 * ss)
                d.text((cx + 40 * ss, cy - 70 * ss), "x2", fill=(110, 46, 40), font=font(FONT_B, 40 * ss))
            elif icon == "anchor":
                d.ellipse((cx - 14 * ss, cy - 82 * ss, cx + 14 * ss, cy - 54 * ss), outline=ink, width=6 * ss)
                d.line((cx, cy - 54 * ss, cx, cy + 60 * ss), fill=ink, width=9 * ss)
                d.line((cx - 40 * ss, cy - 34 * ss, cx + 40 * ss, cy - 34 * ss), fill=ink, width=8 * ss)
                d.arc((cx - 66 * ss, cy - 20 * ss, cx + 66 * ss, cy + 74 * ss), 20, 160, fill=ink, width=9 * ss)
            elif icon == "bow":
                d.polygon([(cx - 80 * ss, cy + 40 * ss), (cx + 80 * ss, cy + 40 * ss), (cx + 50 * ss, cy + 70 * ss), (cx - 70 * ss, cy + 70 * ss)], fill=(110, 46, 40))
                d.polygon([(cx - 60 * ss, cy + 40 * ss), (cx - 20 * ss, cy - 60 * ss), (cx - 20 * ss, cy + 40 * ss)], fill=ink)
                for k in range(3):
                    d.arc((cx - 100 * ss, cy + (74 + k * 12) * ss, cx + 100 * ss, cy + (110 + k * 12) * ss), 200, 340, fill=ink, width=3 * ss)
            else:
                d.rounded_rectangle((cx - 70 * ss, cy - 40 * ss, cx + 70 * ss, cy + 60 * ss), radius=14 * ss, fill=(150, 72, 50), outline=ink, width=3 * ss)
                d.arc((cx - 34 * ss, cy - 80 * ss, cx + 34 * ss, cy - 10 * ss), 180, 360, fill=ink, width=7 * ss)
                d.rectangle((cx - 70 * ss, cy - 2 * ss, cx + 70 * ss, cy + 8 * ss), fill=(176, 146, 80))
        return fn

    for i in range(4):
        r0, r1, c0, c1 = box("Card%d" % i)
        img = text_img(c1 - c0, r1 - r0, card_fn(i))
        aged = smooth(0.4, 0.9, reg("Card%d" % i, big))[..., None]
        alb[r0:r1, c0:c1] = img * (1 - 0.08 * aged) + rgb((170, 150, 110)) * 0.08 * aged
        rgh[r0:r1, c0:c1] = 0.78

    # drawer fronts: varnished pine with a brass card frame and a hand-lettered label
    for i in range(16):
        r0, r1, c0, c1 = box("Drawer%d" % i)
        hh, ww = r1 - r0, c1 - c0
        gr = wood_grain((hh, ww), 0.06, 130 + i, 0.08)
        tone = 0.9 + 0.2 * np.random.default_rng(i).random()
        a = rgb((126, 98, 74)) * tone * (0.86 + 0.22 * gr[..., None])
        yy, xx = np.mgrid[0:hh, 0:ww]
        e = np.minimum(np.minimum(yy, hh - 1 - yy), np.minimum(xx, ww - 1 - xx))
        a = a * (1 - 0.3 * (1 - smooth(0, 6, e)))[..., None]
        fx0, fx1, fy0, fy1 = int(ww * 0.22), int(ww * 0.78), int(hh * 0.22), int(hh * 0.62)
        frame = np.zeros((hh, ww))
        frame[fy0:fy1, fx0:fx1] = 1
        card = np.zeros((hh, ww))
        card[fy0 + 6:fy1 - 6, fx0 + 7:fx1 - 7] = 1
        rim = frame * (1 - card)
        lbl = LABELS[i]

        def lab(d, ss, lbl=lbl, fx0=fx0, fx1=fx1, fy0=fy0, fy1=fy1):
            f = font(FONT_H, 15 * ss)
            tw = d.textlength(lbl, font=f)
            while tw > (fx1 - fx0 - 18) * ss:
                f = font(FONT_H, int(f.size * 0.9))
                tw = d.textlength(lbl, font=f)
            d.text(((fx0 + fx1) / 2 * ss - tw / 2, ((fy0 + fy1) / 2 - 9) * ss), lbl, fill=(255, 255, 255), font=f)

        ink = text_img(ww, hh, lab)[..., 0] * card
        a = np.where(card[..., None] > 0.5, rgb((214, 206, 184)) * (1 - 0.8 * ink[..., None]) + rgb((40, 38, 36)) * 0.8 * ink[..., None], a)
        a = np.where(rim[..., None] > 0.5, rgb((220, 190, 130)), a)
        alb[r0:r1, c0:c1] = a
        rgh[r0:r1, c0:c1] = np.where(rim > 0.5, 0.32, np.where(card > 0.5, 0.82, 0.42 + 0.06 * gr))
        met[r0:r1, c0:c1] = rim
        hgt[r0:r1, c0:c1] = 0.6 * rim - 0.2 * card - 0.5 * (1 - smooth(0, 4, e))

    # logbook: open spread, two tracks (free / crew), ruled, hand-filled entries
    r0, r1, c0, c1 = box("Logbook")
    hh, ww = r1 - r0, c1 - c0

    def logfn(d, ss):
        w, h = ww * ss, hh * ss
        d.rectangle((0, 0, w, h), fill=(210, 200, 176))
        for y in range(40, hh, 12):
            d.line((14 * ss, y * ss, w / 2 - 14 * ss, y * ss), fill=(160, 170, 180), width=ss)
            d.line((w / 2 + 14 * ss, y * ss, w - 14 * ss, y * ss), fill=(160, 170, 180), width=ss)
        d.line((w / 2, 0, w / 2, h), fill=(120, 104, 80), width=3 * ss)
        fb = font(FONT_B, 14 * ss)
        fh = font(FONT_H, 11 * ss)
        d.text((22 * ss, 12 * ss), "SEASON LOGBOOK  -  DECK TRACK", fill=(44, 56, 82), font=fb)
        d.text((w / 2 + 22 * ss, 12 * ss), "CREW TRACK", fill=(110, 46, 40), font=fb)
        rr2 = np.random.default_rng(3)
        for k in range(16):
            y = (29 + k * 12) * ss
            for side in (0, 1):
                x0 = (22 + side * ww / 2) * ss
                d.text((x0, y), "%d." % (k + 1), fill=(60, 60, 70), font=fh)
                d.text((x0 + 24 * ss, y), rr2.choice(["Tow", "Rescue", "Patrol", "Flare", "Search", "Medevac"]) + " - " +
                       rr2.choice(["Gull Rock", "the Narrows", "North Pier", "Seal Bay", "the Bar"]), fill=(40, 44, 70), font=fh)
                if k < 9:
                    d.text((x0 + (ww / 2 - 52) * ss, y), "v", fill=(110, 46, 40), font=fh)

    img = text_img(ww, hh, logfn)
    yy, xx = np.mgrid[0:hh, 0:ww]
    gutter = np.exp(-((xx - ww / 2) / 14.0) ** 2)
    alb[r0:r1, c0:c1] = img * (1 - 0.22 * gutter[..., None])
    rgh[r0:r1, c0:c1] = 0.86
    hgt[r0:r1, c0:c1] = -gutter

    # till keys (brass plate with cream key caps) and the amount sign
    r0, r1, c0, c1 = box("TillKeys")
    hh, ww = r1 - r0, c1 - c0
    a = np.ones((hh, ww, 3)) * rgb((222, 192, 130))
    m = np.ones((hh, ww))
    h = np.zeros((hh, ww))
    yy, xx = np.mgrid[0:hh, 0:ww]
    keys = np.zeros((hh, ww))
    for i in range(6):
        for j in range(7):
            cx, cy = 22 + j * 35, 26 + i * 40
            d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
            keys = np.maximum(keys, 1 - smooth(11, 13, d))
    def keyfn(d, ss):
        f = font(FONT_B, 11 * ss)
        for i in range(6):
            for j in range(7):
                d.text(((22 + j * 35 - 4) * ss, (26 + i * 40 - 7) * ss), str((i * 7 + j) % 10), fill=(255, 255, 255), font=f)
    ink = text_img(ww, hh, keyfn)[..., 0] * keys
    a = np.where(keys[..., None] > 0.5, rgb((212, 204, 182)) * (1 - 0.8 * ink[..., None]) + rgb((40, 38, 36)) * 0.8 * ink[..., None], a)
    m = np.where(keys > 0.5, 0.0, 1.0)
    alb[r0:r1, c0:c1] = a
    met[r0:r1, c0:c1] = m
    rgh[r0:r1, c0:c1] = np.where(keys > 0.5, 0.4, 0.3)
    hgt[r0:r1, c0:c1] = keys
    r0, r1, c0, c1 = box("TillSign")
    hh, ww = r1 - r0, c1 - c0

    def signfn(d, ss):
        w, h = ww * ss, hh * ss
        d.rectangle((0, 0, w, h), fill=(222, 192, 130))
        d.rectangle((24 * ss, 70 * ss, w - 24 * ss, 190 * ss), fill=(30, 30, 30))
        f = font(FONT_S, 18 * ss)
        txt = "AMOUNT PURCHASED"
        d.text(((w - d.textlength(txt, font=f)) / 2, 26 * ss), txt, fill=(90, 70, 40), font=f)
        fb = font(FONT_B, 54 * ss)
        for k, ch in enumerate("0.00"):
            x = (40 + k * 46) * ss
            d.rectangle((x, 90 * ss, x + 38 * ss, 170 * ss), fill=(214, 206, 186))
            d.text((x + 5 * ss, 98 * ss), ch, fill=(30, 30, 30), font=fb)
    img = text_img(ww, hh, signfn)
    win = np.zeros((hh, ww))
    win[70:190, 24:ww - 24] = 1
    alb[r0:r1, c0:c1] = img
    met[r0:r1, c0:c1] = 1 - win
    rgh[r0:r1, c0:c1] = np.where(win > 0.5, 0.3, 0.28)
    hgt[r0:r1, c0:c1] = -0.5 * win

    # slatwall: painted panel with grooves every 0.1 m (21 over the 2.1 m panel height)
    r0, r1, c0, c1 = box("Slatwall")
    hh, ww = r1 - r0, c1 - c0
    yy = np.arange(hh)[:, None] * np.ones((1, ww))
    per = hh / 21.0
    gt = (yy % per) / per
    slot = smooth(0.0, 0.08, gt) * (1 - smooth(0.2, 0.28, gt))
    a = rgb((74, 84, 78)) * (0.95 + 0.08 * reg("Slatwall", mid)[..., None])
    a = a * (1 - 0.6 * slot[..., None])
    alb[r0:r1, c0:c1] = a
    rgh[r0:r1, c0:c1] = 0.55 + 0.2 * slot
    hgt[r0:r1, c0:c1] = -slot

    # blister packs (0.1 x 0.2 m backing cards)
    for i, (t1, t2, col) in enumerate(PACKS):
        r0, r1, c0, c1 = box("Pack%d" % i)
        hh, ww = r1 - r0, c1 - c0

        def pfn(d, ss, t1=t1, t2=t2, col=col):
            w, h = ww * ss, hh * ss
            d.rectangle((0, 0, w, h), fill=(208, 202, 188))
            d.rectangle((0, 0, w, 54 * ss), fill=col)
            d.ellipse((w / 2 - 8 * ss, 12 * ss, w / 2 + 8 * ss, 28 * ss), fill=(30, 30, 30))
            f = font(FONT_B, 12 * ss)
            d.text(((w - d.textlength(t1, font=f)) / 2, 34 * ss), t1, fill=(226, 220, 204), font=f)
            d.rounded_rectangle((14 * ss, 70 * ss, w - 14 * ss, 200 * ss), radius=12 * ss, fill=(170, 172, 170), outline=(120, 120, 120), width=2 * ss)
            f2 = font(FONT_R, 12 * ss)
            d.text(((w - d.textlength(t2, font=f2)) / 2, 216 * ss), t2, fill=(50, 50, 50), font=f2)
        img = text_img(ww, hh, pfn)
        yy, xx = np.mgrid[0:hh, 0:ww]
        bl = ((xx > 14) & (xx < ww - 14) & (yy > 70) & (yy < 200)).astype(float)
        alb[r0:r1, c0:c1] = img
        rgh[r0:r1, c0:c1] = np.where(bl > 0.5, 0.12, 0.7)
        hgt[r0:r1, c0:c1] = 0.8 * blur(bl, 3)

    # curtain: heavy cotton canvas (no weave bump), teal-grey, slight sun fade at the top, hem darker
    r0, r1, c0, c1 = box("Curtain")
    hh, ww = r1 - r0, c1 - c0
    yy = np.arange(hh)[:, None] / hh * np.ones((1, ww))
    a = rgb((62, 86, 90)) * (0.92 + 0.12 * reg("Curtain", mid)[..., None])
    a = a * (1 + 0.08 * (1 - smooth(0, 0.3, yy)))[..., None]
    a = a * (1 - 0.12 * smooth(0.9, 1.0, yy))[..., None]
    alb[r0:r1, c0:c1] = a
    rgh[r0:r1, c0:c1] = 0.9
    hgt[r0:r1, c0:c1] = 0.15 * reg("Curtain", mid)
    # coir mat
    r0, r1, c0, c1 = box("Mat")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    e = np.minimum(np.minimum(yy, hh - 1 - yy), np.minimum(xx, ww - 1 - xx))
    border = 1 - smooth(18, 26, e)
    fib = fbm((hh, ww), 1.6, 0.05, aniso=(1.0, 0.5), seed=141)
    a = rgb((124, 100, 72)) * (0.82 + 0.3 * fib[..., None])
    a = a * (1 - 0.45 * border[..., None])
    dirt = smooth(0.4, 0.8, reg("Mat", big))
    a = a * (1 - 0.15 * dirt[..., None])
    alb[r0:r1, c0:c1] = a
    rgh[r0:r1, c0:c1] = 0.95
    hgt[r0:r1, c0:c1] = 0.6 * fib

    nor = normal_from_height(blur(hgt, 1) * 2.0, 2.5, wrap=False)
    save(STEM + "_Details", alb, nor, rgh, met)


if __name__ == "__main__":
    pine_set()
    lining_set()
    joinery_set()
    details_set()
    print("ok")
