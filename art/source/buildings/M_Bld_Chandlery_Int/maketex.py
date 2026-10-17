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
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/textures/M_Bld_Chandlery_Int"
STEM = "T_ChandleryInt"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
rng = np.random.default_rng(2207)

from atlas import DETAILS, JOINERY, LINING, LINING_WALL_Z, PINE_ZONES, POSTER_M  # noqa: E402  (shared with build.py)

L_SILL = (3.34, 4.0, 3.35)   # under-sash lining: z0 (U0), z1 (sill 4.0), loft floor (layout LOFT_WIN_Z / LOFT)

LABELS = ["SHACKLES 6", "SHACKLES 8", "SNAP HOOKS", "THIMBLES", "CLEVIS PINS", "SPLIT RINGS", "SWIVELS", "EYE BOLTS",
          "PAD EYES", "BULLDOG GRIPS", "SAIL NEEDLES", "WHIPPING TWINE", "HOSE CLIPS", "SPLIT PINS", "CABLE TIES", "FUSES"]
CARDS = [("2x CASH", "Double Cash", "on every operation", "coins"),
         ("VIP CREW CARD", "Crew perks", "berth, boost, badge", "anchor"),
         ("QUICK LAUNCH", "Skip the slip", "launch from any berth", "bow"),
         ("STARTER KIT", "Gear, livery", "and a head start", "kit")]
PACKS = [("S/S SHACKLE", "6 mm  x2", (150, 54, 44), "shackle"), ("SNAP SHACKLE", "swivel eye", (176, 132, 40), "snap"),
         ("NYLON CLEAT", "150 mm", (62, 100, 66), "cleat"), ("THIMBLES", "8 mm  x4", (186, 96, 40), "thimble")]

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


# ------------------------------------------------------------------ Pine floorboards: 4 wear-zone strips (atlas PINE_ZONES)
def pine_set():
    """Each strip: 4 boards (0.6 m) across x 2.4 m along U (427 px/m, 142 px/stud). The same boards (joints, grain,
    per-plank tone, knots, nails) in all four strips; the zone layers share one noise field with zone thresholds, so a
    zone change along a board only shifts wear, never the board."""
    N, H = 1024, 256
    fc = 8 / 142.0               # 8 cycles per stud
    s = (H, N)
    boards, bh = 4, 64
    yy, xx = np.mgrid[0:H, 0:N]
    t = (yy % bh) / bh
    r = np.random.default_rng(31)
    seg = np.zeros(s, int)
    joint = np.zeros(s)
    for b in range(boards):                       # 1 or 2 butt joints a board (board lengths 1.2 .. 2.4 m), wrapped
        n = 1 + int(r.random() < 0.6)
        cuts = np.sort(r.uniform(0, N, n)).astype(int)
        rr = slice(b * bh, (b + 1) * bh)
        idx = np.zeros(N, int)
        for k, c in enumerate(cuts):
            idx[(np.arange(N) - c) % N < ((cuts[(k + 1) % n] - c) % N or N)] = b * 4 + k
            d = np.minimum((np.arange(N) - c) % N, (c - np.arange(N)) % N)
            joint[rr] = np.maximum(joint[rr], (1 - smooth(0, 3.5, d))[None, :])
        seg[rr] = idx[None, :]
    nseg = boards * 4 + 4
    tone = r.uniform(0.80, 1.16, nseg)            # per-plank tone (reclaimed boards, some replaced)
    warm = r.normal(0, 0.05, nseg)
    grey = (r.random(nseg) < 0.2) * r.uniform(0.1, 0.25, nseg)   # a few weathered greyer planks
    grain = wood_grain(s, fc, 5)
    big = fbm(s, 3.0, fc * 0.3, seed=7)
    mid = fbm(s, 2.4, fc * 0.6, seed=8)
    blot = fbm(s, 2.6, fc * 0.45, seed=10)
    base = rgb((150, 116, 86))
    alb0 = base[None, None, :] * tone[seg][..., None] * (0.86 + 0.24 * grain[..., None])
    alb0[..., 0] *= 1 + warm[seg]
    alb0[..., 2] *= 1 - warm[seg]
    g = grey[seg][..., None]
    alb0 = alb0 * (1 - g) + alb0.mean(-1, keepdims=True) * g
    knot = np.zeros(s)
    for _ in range(4):
        cx, cy, rx, ry = r.uniform(0, N), r.uniform(8, H - 8), r.uniform(8, 16), r.uniform(5, 9)
        dx = (xx - cx + N / 2) % N - N / 2
        knot = np.maximum(knot, 1 - smooth(0.4, 1.0, np.sqrt((dx / rx) ** 2 + ((yy - cy) / ry) ** 2)))
    alb0 = alb0 * (1 - 0.45 * knot[..., None]) + rgb((86, 58, 40)) * 0.45 * knot[..., None]
    edge = np.minimum(t, 1 - t) * bh
    gap = np.maximum(1 - smooth(0.0, 4.0, edge), joint)
    nails = np.zeros(s)
    halo = np.zeros(s)
    for jx in range(6):                           # joists every 0.4 m, 2 nails a board
        cx = (jx + 0.5) * N / 6 + 9
        for b in range(boards):
            for f in (0.27, 0.73):
                cy = (b + f) * bh
                d = np.sqrt(((xx - cx + N / 2) % N - N / 2) ** 2 + (yy - cy) ** 2)
                nails = np.maximum(nails, 1 - smooth(2.5, 4.5, d))
                halo = np.maximum(halo, 1 - smooth(3.0, 9.0, d))
    wearf = big * 0.65 + mid * 0.35               # shared wear field
    scuf = fbm(s, 2.2, fc * 0.8, seed=9)
    # zone: (varnish wear lo/hi, ground-in dirt, gap grime, scuff threshold, edge dust/grime)
    Z = {"Clean": (0.66, 0.84, 0.0, 0.35, 0.80, 0.0), "Traffic": (0.44, 0.66, 0.28, 0.45, 0.70, 0.0),
         "Path": (0.22, 0.48, 0.55, 0.7, 0.60, 0.0), "Edge": (0.70, 0.88, 0.04, 0.6, 0.86, 1.0)}
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    hgt = np.zeros((N, N))
    for zone, (w0, w1, dirt, gg, sc0, dust) in Z.items():
        v0, v1 = PINE_ZONES[zone]
        r0, r1 = int(round((1 - v1) * N)), int(round((1 - v0) * N))
        worn = smooth(w0, w1, wearf)
        a = alb0 * (1 - 0.2 * worn[..., None]) + rgb((172, 152, 126)) * 0.2 * worn[..., None]   # varnish gone, pale
        # ground-in work-wear: dark grey-brown dirt in the worn grain, blotchy
        dd = dirt * (0.55 + 0.45 * smooth(0.3, 0.7, blot)) * (0.5 + 0.5 * worn)
        a = a * (1 - dd[..., None]) + rgb((70, 60, 50)) * dd[..., None]
        scuff = smooth(sc0, sc0 + 0.14, scuf) * (0.5 + 0.6 * dirt)
        a = a * (1 - 0.25 * scuff[..., None]) + rgb((60, 54, 48)) * 0.25 * scuff[..., None]
        grime = (1 - smooth(0.0, 10.0, edge)) * (0.5 + 0.5 * mid) * (1 + gg)
        # wall edge: dust grey in the gaps, dark blotches of old spills and mop water
        eg = dust * smooth(0.45, 0.75, blot) * 0.3
        a = a * (1 - eg[..., None]) + rgb((64, 54, 44)) * eg[..., None]
        dg = dust * (1 - smooth(0.0, 7.0, edge)) * 0.35
        a = a * (1 - dg[..., None]) + rgb((128, 120, 106)) * dg[..., None]
        a = a * (1 - np.clip(0.33 * grime, 0, 0.6)[..., None]) * (1 - (0.6 - 0.25 * dust * 0) * gap[..., None])
        a = a * (1 - 0.18 * halo[..., None]) + rgb((96, 70, 50)) * 0.18 * halo[..., None]
        a = a * (1 - nails[..., None]) + rgb((58, 54, 50)) * nails[..., None]
        alb[r0:r1] = a
        hgt[r0:r1] = 0.6 * (1 - gap) + 0.08 * grain + 0.15 * mid - 0.08 * worn - 0.2 * nails + 0.1 * np.sin(np.pi * t) \
            - 0.08 * scuff
        polish = dirt * smooth(0.55, 0.8, mid) * worn          # foot-polished patches inside the paths
        rgh[r0:r1] = 0.46 + 0.26 * worn + 0.12 * scuff + 0.2 * gap + 0.05 * grain + 0.14 * dd - 0.2 * polish + 0.1 * eg
        rgh[r0:r1] = np.where(nails > 0.5, 0.55, rgh[r0:r1])
    hgt = blur(hgt, 1)
    nor = normal_from_height(hgt * 3.0, 3.0)
    save(STEM + "_Pine", alb, nor, rgh, np.zeros((N, N)))


# ------------------------------------------------------------------ painted tongue-and-groove (atlas LINING strips)
def lining_set():
    """10 boards of 0.12 m across U (1.2 m, 853 px/m). Strips in V: Wall = one storey, z above that storey's floor
    LINING_WALL_Z (236 px/m in V: noise is generated stretched 3.6 x in U so marks are round in metres); Clean = the
    board pattern constant along V (ceilings, roof); Sill = under the loft sashes, drip stains from the window board."""
    N = 1024
    fc = 8 * 3.6 / N              # 8 cycles per stud along U
    boards = 10
    bw = N / boards
    r = np.random.default_rng(41)
    tone = r.uniform(0.93, 1.06, boards)                       # board-to-board: repainted, different batches
    hue = r.normal(0, 0.025, boards)
    za, zb_ = LINING_WALL_Z
    paint = rgb((190, 180, 156))
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    hgt = np.zeros((N, N))

    def rows(name):
        v0, v1 = LINING[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N))

    def boards_base(h, seed):
        yy, xx = np.mgrid[0:h, 0:N]
        col = (xx // bw).astype(int)
        t = (xx % bw) / bw
        brush = fbm((h, N), 2.0, fc, aniso=(0.08, 1.0), seed=seed)
        a = paint[None, None, :] * tone[col][..., None] * (0.95 + 0.07 * brush[..., None])
        a[..., 0] *= 1 + hue[col]
        a[..., 2] *= 1 - 1.5 * hue[col]
        e = np.minimum(t, 1 - t) * bw
        vj = 1 - smooth(0.0, 6.0, e)
        a = a * (1 - 0.42 * vj[..., None]) * (1 - 0.1 * (1 - smooth(0, 14, e))[..., None])
        return a, brush, vj, e, yy, xx

    # ---- Wall strip
    r0, r1 = rows("Wall")
    h = r1 - r0
    a, brush, vj, e, yy, xx = boards_base(h, 12)
    zr = za + (zb_ - za) * (1 - (yy + 0.5) / h)               # metres above the storey floor
    ppm_v = h / (zb_ - za)
    ani = (1.0, 853.0 / ppm_v)                                 # metric-round noise
    big = fbm((h, N), 3.2, fc * 0.25, aniso=ani, seed=13)
    mid = fbm((h, N), 2.6, fc * 0.5, aniso=ani, seed=15)
    fine = fbm((h, N), 2.0, fc * 0.9, aniso=ani, seed=16)
    yellow = smooth(0.5, 0.85, big)[..., None]
    a = a * (1 - 0.1 * yellow) + rgb((176, 160, 122)) * 0.1 * yellow
    # floor grime: dust and mop splash up from the skirting, darkest into the V-joints
    fl = (1 - smooth(0.12, 0.55, zr)) * (0.55 + 0.45 * mid)
    a = a * (1 - 0.28 * fl[..., None]) + rgb((96, 84, 66)) * 0.28 * fl[..., None]
    a = a * (1 - 0.25 * (fl * vj)[..., None])
    # boot height (0.18 .. 0.55 m): black rubber scuffs (short streaks along U) and knocks showing undercoat/wood
    boot = smooth(0.16, 0.24, zr) * (1 - smooth(0.42, 0.6, zr))
    sc = fbm((h, N), 2.0, fc * 0.8, aniso=(1.0, ani[1] * 0.35), seed=17)
    scuff = smooth(0.70, 0.80, sc) * boot
    a = a * (1 - 0.45 * scuff[..., None]) + rgb((44, 42, 40)) * 0.45 * scuff[..., None]
    kn = smooth(0.84, 0.88, fine) * smooth(0.45, 0.65, mid) * (boot + 0.5 * smooth(0.75, 0.9, zr) * (1 - smooth(1.0, 1.15, zr)))
    a = a * (1 - kn[..., None]) + rgb((150, 128, 98)) * kn[..., None]
    # hand height (0.85 .. 1.45 m): greasy smudges, a touch darker and glossier
    hand = smooth(0.8, 1.0, zr) * (1 - smooth(1.3, 1.5, zr)) * smooth(0.5, 0.8, mid)
    a = a * (1 - 0.1 * hand[..., None]) + rgb((130, 116, 92)) * 0.1 * hand[..., None]
    # ceiling corner: smoke and cobweb dust toward the top (ground ceiling 3.05 m, loft eaves 2.67 m)
    top = smooth(2.2, 3.05, zr) * 0.14 + smooth(2.8, 3.05, zr) * 0.1
    a = a * (1 - top[..., None]) + rgb((120, 108, 88)) * 0.4 * top[..., None]
    stains = smooth(0.72, 0.9, fbm((h, N), 2.6, fc * 0.4, aniso=ani, seed=14))
    a = a * (1 - 0.1 * stains[..., None]) + rgb((140, 126, 100)) * 0.1 * stains[..., None]
    punch = np.zeros((h, N))                                    # filled nail punches near one board edge
    for b in range(boards):
        for zz in (0.4, 1.0, 1.6, 2.2, 2.8):
            cx = (b + 0.86) * bw
            cy = h * (1 - (zz + 0.1 * r.random() - za) / (zb_ - za))
            d = np.sqrt((((xx - cx + N / 2) % N - N / 2) / 1.0) ** 2 + ((yy - cy) * 853.0 / ppm_v) ** 2)
            punch = np.maximum(punch, 1 - smooth(2.0, 5.0, d))
    a = a * (1 - 0.12 * punch[..., None])
    alb[r0:r1] = a
    hgt[r0:r1] = -vj + 0.04 * brush - 0.3 * punch - 0.5 * kn - 0.05 * scuff
    rgh[r0:r1] = 0.56 + 0.06 * brush + 0.2 * vj + 0.06 * stains + 0.12 * fl + 0.1 * kn - 0.12 * hand
    # ---- Clean strip: column profile only (constant along V; stretched over ceilings and roof boarding)
    r0, r1 = rows("Clean")
    h = r1 - r0
    a, brush, vj, e, yy, xx = boards_base(h, 18)
    a = np.repeat(a.mean(0, keepdims=True), h, 0)
    alb[r0:r1] = a * (1 - 0.06 * smooth(0.5, 0.9, fbm((h, N), 3.0, 0.004, aniso=(0.05, 1.0), seed=19))[..., None])
    hgt[r0:r1] = -vj
    rgh[r0:r1] = 0.58 + 0.2 * vj
    # ---- Sill strip: under the loft sashes (0.66 m: z U0 at the bottom row, the window board at the top row)
    r0, r1 = rows("Sill")
    h = r1 - r0
    a, brush, vj, e, yy, xx = boards_base(h, 20)
    zr = (L_SILL[1] - L_SILL[0]) * (1 - (yy + 0.5) / h) + L_SILL[0] - L_SILL[2]
    ppm_v = h / (L_SILL[1] - L_SILL[0])
    ani = (1.0, 853.0 / ppm_v)
    mid = fbm((h, N), 2.6, fc * 0.5, aniso=ani, seed=21)
    fl = (1 - smooth(0.12, 0.55, zr)) * (0.55 + 0.45 * mid)
    a = a * (1 - 0.28 * fl[..., None]) + rgb((96, 84, 66)) * 0.28 * fl[..., None]
    a = a * (1 - 0.25 * (fl * vj)[..., None])
    drip = np.zeros((h, N))
    tide = np.zeros((h, N))
    for _ in range(26):                                         # condensation runs from the window board
        cx, wpx = r.uniform(0, N), r.uniform(2.5, 7.0)
        ln = r.uniform(0.25, 0.95) * h
        dx = np.abs((xx - cx + N / 2) % N - N / 2)
        prof = (1 - smooth(wpx * 0.5, wpx, dx)) * (1 - smooth(ln * 0.6, ln, yy)) * r.uniform(0.5, 1.0)
        drip = np.maximum(drip, prof)
        tide = np.maximum(tide, (1 - smooth(wpx * 0.6, wpx * 1.2, dx)) * np.exp(-((yy - ln * 0.8) / 2.5) ** 2) * 0.8)
    band = (1 - smooth(0.0, 0.25 * h, yy)) * smooth(0.4, 0.7, mid)     # wet band just under the board, flaking
    a = a * (1 - 0.22 * drip[..., None]) + rgb((150, 120, 82)) * 0.22 * drip[..., None]
    a = a * (1 - 0.3 * tide[..., None]) + rgb((120, 92, 62)) * 0.3 * tide[..., None]
    a = a * (1 - 0.2 * band[..., None]) + rgb((136, 112, 84)) * 0.2 * band[..., None]
    flake = smooth(0.82, 0.88, fbm((h, N), 2.0, fc * 0.9, aniso=ani, seed=22)) * band
    a = a * (1 - flake[..., None]) + rgb((156, 132, 100)) * flake[..., None]
    alb[r0:r1] = a
    hgt[r0:r1] = -vj + 0.04 * brush - 0.4 * flake + 0.1 * drip
    rgh[r0:r1] = 0.56 + 0.2 * vj - 0.1 * drip + 0.2 * flake + 0.1 * fl
    nor = normal_from_height(blur(hgt, 1) * 3.0, 3.0)
    save(STEM + "_Lining", alb, nor, rgh, np.zeros((N, N)))


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
    bscuff = smooth(0.7, 0.8, fbm(sh, 2.0, fc * 0.8, aniso=(1.0, 0.3), seed=74)) * smooth(0.72, 0.85, fy)
    a = a * (1 - 0.4 * bscuff[..., None]) + rgb((46, 42, 38)) * 0.4 * bscuff[..., None]
    dent = smooth(0.85, 0.9, fbm(sh, 2.0, fc, seed=75)) * smooth(0.6, 0.9, fy)
    a = a * (1 - 0.5 * dent[..., None]) + rgb((168, 134, 96)) * 0.5 * dent[..., None]
    handr = (1 - smooth(0.0, 0.16, fy)) * smooth(0.5, 0.8, fbm(sh, 2.6, fc * 0.4, seed=76))
    a = a * (1 - 0.12 * handr[..., None])
    alb[r0:r1] = a
    hgt[r0:r1] = 0.9 * raise_ + 0.25 * field - 0.6 * np.clip(groove, 0, 1) + 0.05 * g - 0.5 * dent
    rgh[r0:r1] = 0.38 + 0.25 * kick + 0.05 * g + 0.15 * bscuff + 0.2 * dent - 0.06 * handr
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
    chip = smooth(0.74, 0.80, fbm(sh, 2.0, fc * 0.8, seed=92)) * smooth(0.35, 0.65, fbm(sh, 3.0, fc * 0.3, seed=93))
    yy = np.arange(r1 - r0)[:, None] / (r1 - r0)
    chip = np.maximum(chip, smooth(0.8, 0.86, fbm(sh, 2.0, fc, seed=94)) * (1 - smooth(0.0, 0.2, np.minimum(yy, 1 - yy))))  # arris knocks
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

    # blister packs (0.1 x 0.2 m printed backing cards, 128 x 256 px): colour header with the hang slot, printed panel
    # behind a clear blister (window px 16..112 x 64..196: glossy, highlight streaks, the item inside), item icon, barcode
    def metal(d, pts_or_fn, w, ss):
        for col, ww_ in (((66, 66, 68), w + 3), ((168, 170, 172), w), ((228, 228, 224), max(1, w // 3))):
            pts_or_fn(d, col, ww_ * ss)

    def item_draw(kind, d, ss, cx, cy, sc=1.0, flat=None):
        def L_(pts, col, w):
            d.line([((cx + x * sc) * ss, (cy + y * sc) * ss) for x, y in pts], fill=col, width=int(w), joint="curve")

        def A(box, a0, a1, col, w):
            x0, y0, x1, y1 = box
            d.arc(((cx + x0 * sc) * ss, (cy + y0 * sc) * ss, (cx + x1 * sc) * ss, (cy + y1 * sc) * ss), a0, a1, fill=col, width=int(w))
        styles = [((66, 66, 68), 3), ((168, 170, 172), 0), ((226, 226, 222), -3)] if flat is None else [(flat, 0)]
        for col, dw in styles:
            w = lambda base: max(2, (base + dw) * ss * sc) if flat is None else base * ss * sc
            if kind == "shackle":
                A((-26, -20, 26, 50), 0, 180, col, w(8))
                L_([(-26, 15), (-26, -30)], col, w(8))
                L_([(26, 15), (26, -30)], col, w(8))
                L_([(-36, -34), (36, -34)], col, w(7))
            elif kind == "snap":
                L_([(0, -50), (0, -30)], col, w(6))
                A((-10, -62, 10, -42), 0, 360, col, w(5))
                L_([(-12, -30), (-12, 30)], col, w(9))
                A((-12, 6, 28, 50), 0, 200, col, w(8))
                L_([(28, 28), (10, -10)], col, w(4))
            elif kind == "cleat":
                L_([(-44, 0), (44, 0)], col, w(9))
                A((-60, -22, -24, 8), 200, 340, col, w(7))
                A((24, -22, 60, 8), 200, 340, col, w(7))
                L_([(-14, 0), (-18, 22)], col, w(9))
                L_([(14, 0), (18, 22)], col, w(9))
            else:
                for ox, oy in ((-18, -26), (18, -26), (-18, 26), (18, 26)):
                    A((ox - 13, oy - 18, ox + 13, oy + 14), 0, 360, col, w(5))
                    L_([(ox, oy - 18), (ox, oy - 26)], col, w(4))

    for i, (t1, t2, col, kind) in enumerate(PACKS):
        r0, r1, c0, c1 = box("Pack%d" % i)
        hh, ww = r1 - r0, c1 - c0
        pale = tuple(int(c * 0.35 + 214 * 0.65) for c in col)

        def pfn(d, ss, t1=t1, t2=t2, col=col, kind=kind, pale=pale):
            w, h = ww * ss, hh * ss
            d.rectangle((0, 0, w, h), fill=(214, 206, 186))
            d.rectangle((0, 0, w, 56 * ss), fill=col)
            d.polygon([(0, 56 * ss), (w, 44 * ss), (w, 60 * ss), (0, 64 * ss)], fill=tuple(int(c * 0.75) for c in col))
            d.rounded_rectangle((w / 2 - 14 * ss, 8 * ss, w / 2 + 14 * ss, 18 * ss), radius=5 * ss, fill=(44, 42, 40))
            fs = font(FONT_R, 9 * ss)
            d.text(((w - d.textlength("HARBOUR LINE", font=fs)) / 2, 22 * ss), "HARBOUR LINE", fill=(226, 220, 204), font=fs)
            f = font(FONT_B, 12 * ss)
            while d.textlength(t1, font=f) > w - 10 * ss:
                f = font(FONT_B, int(f.size * 0.9))
            d.text(((w - d.textlength(t1, font=f)) / 2, 34 * ss), t1, fill=(230, 224, 210), font=f)
            d.rectangle((16 * ss, 64 * ss, 112 * ss, 196 * ss), fill=pale)
            for k in range(5):                                       # printed rays behind the item
                d.line((64 * ss, 130 * ss, (16 + k * 24) * ss, 64 * ss), fill=tuple(int(c * 0.93) for c in pale), width=6 * ss)
            item_draw(kind, d, ss, 64, 132, 0.95)
            f2 = font(FONT_B, 13 * ss)
            d.text(((w - d.textlength(t2, font=f2)) / 2, 202 * ss), t2, fill=col, font=f2)
            item_draw(kind, d, ss, 22, 236, 0.22, flat=col)          # small printed icon
            rb = np.random.default_rng(len(t1))
            x = 50
            while x < 116:                                           # barcode
                bwid = rb.choice([1, 1, 2, 3])
                d.rectangle((x * ss, 226 * ss, (x + bwid) * ss, 246 * ss), fill=(46, 44, 42))
                x += bwid + rb.choice([1, 2])
        img = np.asarray(Image.new("RGB", (1, 1)))
        img = text_img(ww, hh, pfn)
        yy, xx = np.mgrid[0:hh, 0:ww]
        bl = ((xx >= 16) & (xx < 112) & (yy >= 64) & (yy < 196)).astype(float)
        dome = blur(bl, 5) * bl
        # clear plastic: a faint milky film, two soft highlight streaks, a bright moulded rim
        streak = np.exp(-((xx - 30 - 0.15 * (yy - 64)) / 4.0) ** 2) * 0.55 + np.exp(-((xx - 44 - 0.15 * (yy - 64)) / 2.0) ** 2) * 0.3
        rim = bl * (1 - smooth(1.0, 4.0, np.minimum(np.minimum(xx - 16, 111 - xx), np.minimum(yy - 64, 195 - yy))))
        film = bl * (0.08 + 0.5 * streak * smooth(70, 120, yy) * (1 - smooth(150, 196, yy)) + 0.5 * rim)
        a = img * (1 - film[..., None]) + rgb((224, 226, 224)) * film[..., None]
        wear = smooth(0.6, 0.8, reg("Pack%d" % i, mid))[..., None] * (1 - bl[..., None])
        alb[r0:r1, c0:c1] = a * (1 - 0.06 * wear)
        rgh[r0:r1, c0:c1] = np.where(bl > 0.5, 0.07 + 0.08 * rim, 0.72 - 0.1 * (img.mean(-1) < 0.5))
        hgt[r0:r1, c0:c1] = 0.9 * dome - 0.6 * (1 - smooth(0, 1.5, np.abs(xx - 63.5) - 13)) * ((yy > 8) & (yy < 18))

    # ---- wall posters and notices: aged paper, faded ink, foxing, curled corners (height), cockling
    def paper_img(w, h, fn, ss=2):
        img = Image.new("RGB", (w * ss, h * ss), (255, 255, 255))
        fn(ImageDraw.Draw(img), ss, w * ss, h * ss)
        return np.asarray(img.resize((w, h), Image.LANCZOS), dtype=np.float64) / 255.0

    def age_poster(name, ink, seed, fade=0.8, curl=(0.9, 0.7, 1.0, 1.3)):
        r0, r1, c0, c1 = box(name)
        hh, ww = r1 - r0, c1 - c0
        rp = np.random.default_rng(seed)
        yy, xx = np.mgrid[0:hh, 0:ww]
        e = np.minimum(np.minimum(yy, hh - 1 - yy), np.minimum(xx, ww - 1 - xx)) / min(hh, ww)
        lf = fbm((hh, ww), 3.0, 0.02, seed=seed)
        mf = fbm((hh, ww), 2.2, 0.06, seed=seed + 1)
        paperc = rgb((222, 212, 186)) * (0.97 + 0.05 * mf[..., None])
        yel = (1 - smooth(0.0, 0.18, e)) * 0.5 + smooth(0.5, 0.9, lf) * 0.4
        paperc = paperc * (1 - 0.18 * yel[..., None]) + rgb((196, 170, 118)) * 0.18 * yel[..., None]
        sun = (xx / ww * 0.6 + (1 - yy / hh) * 0.4)
        ink_s = 1 - (1 - ink) * (fade - 0.15 * sun[..., None])        # faded ink, more where the light falls
        g = ink_s.mean(-1, keepdims=True)
        ink_s = ink_s * 0.8 + g * 0.2
        a = paperc * ink_s
        fox = np.zeros((hh, ww))
        for _ in range(int(ww * hh / 6000)):
            cx, cy, rr_ = rp.uniform(0, ww), rp.uniform(0, hh), rp.uniform(1.5, 4.5)
            fox = np.maximum(fox, (1 - smooth(rr_ * 0.4, rr_, np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2))) * rp.uniform(0.3, 0.8))
        fox *= smooth(0.4, 0.7, lf + 0.3 * (1 - smooth(0, 0.2, e)))
        a = a * (1 - 0.35 * fox[..., None]) + rgb((150, 112, 70)) * 0.35 * fox[..., None]
        ring_c = (rp.uniform(0.2, 0.8) * ww, rp.uniform(0.6, 0.9) * hh)
        ring = np.exp(-((np.sqrt((xx - ring_c[0]) ** 2 + (yy - ring_c[1]) ** 2) - ww * 0.07) / 1.8) ** 2) * 0.5 * (seed % 2)
        a = a * (1 - 0.3 * ring[..., None]) + rgb((150, 118, 76)) * 0.3 * ring[..., None]
        # curled corners: lift ramps over a corner triangle; a soft crease shadow at the curl line
        lift = np.zeros((hh, ww))
        crease = np.zeros((hh, ww))
        for (cxp, cyp), k in zip(((0, 0), (ww - 1, 0), (0, hh - 1), (ww - 1, hh - 1)), curl):
            dd = (np.abs(xx - cxp) + np.abs(yy - cyp)) / (0.16 * min(ww, hh) * k)
            lift = np.maximum(lift, (1 - np.clip(dd, 0, 1)) ** 2)
            crease = np.maximum(crease, np.exp(-((dd - 1.0) / 0.08) ** 2))
        a = a * (1 - 0.12 * crease[..., None]) * (1 + 0.05 * lift[..., None])
        alb[r0:r1, c0:c1] = a
        rgh[r0:r1, c0:c1] = 0.84 - 0.08 * (ink.mean(-1) < 0.6) + 0.04 * fox
        hgt[r0:r1, c0:c1] = 3.0 * lift + 0.25 * fbm((hh, ww), 3.0, 0.03, seed=seed + 2) - 0.6 * crease * 0

    NAVY, MAROON, INKC = (36, 52, 84), (120, 40, 36), (40, 38, 36)

    def ctext(d, txt, f, y, w, fill, x0=0):
        d.text((x0 + (w - x0 - d.textlength(txt, font=f)) / 2 if x0 == 0 else x0, y), txt, fill=fill, font=f)

    # tide table: a month of high and low water
    def tide_fn(d, ss, w, h):
        d.rectangle((6 * ss, 6 * ss, w - 6 * ss, h - 6 * ss), outline=NAVY, width=3 * ss)
        ctext(d, "PORT HAVEN", font(FONT_S, 16 * ss), 14 * ss, w, MAROON)
        ctext(d, "TIDE TABLES", font(FONT_B, 34 * ss), 32 * ss, w, NAVY)
        ctext(d, "OCTOBER  -  heights in metres above chart datum", font(FONT_R, 10 * ss), 72 * ss, w, INKC)
        d.line((14 * ss, 88 * ss, w - 14 * ss, 88 * ss), fill=NAVY, width=2 * ss)
        fh, fr = font(FONT_B, 10 * ss), font(FONT_R, 10 * ss)
        colx = [16, 200]
        for c, x0 in enumerate(colx):
            for j, lab in enumerate(("DAY", "HIGH", "m", "HIGH", "m")):
                d.text(((x0 + [0, 34, 82, 110, 158][j]) * ss, 94 * ss), lab, fill=MAROON, font=fh)
        for day in range(31):
            c, k = (0, day) if day < 16 else (1, day - 16)
            x0, y = colx[c], (110 + k * 22.5) * ss
            if k % 2 == 0:
                d.rectangle(((x0 - 4) * ss, y - 2 * ss, (x0 + 180) * ss, y + 18 * ss), fill=(232, 234, 240))
            m0 = (4 * 60 + 12 + day * 50) % (12 * 60 + 25)
            hgt_ = 4.3 + 0.9 * np.cos(2 * np.pi * (day - 3) / 14.8)
            dow = "MTWTFSS"[(day + 3) % 7]
            vals = ["%2d %s" % (day + 1, dow), "%02d:%02d" % (m0 // 60, m0 % 60), "%.1f" % hgt_,
                    "%02d:%02d" % ((m0 + 745) // 60 % 24, (m0 + 745) % 60), "%.1f" % (hgt_ - 0.2)]
            for j, v in enumerate(vals):
                d.text(((x0 + [0, 34, 82, 110, 158][j]) * ss, y), v, fill=INKC, font=fr)
        d.line((14 * ss, 474 * ss, w - 14 * ss, 474 * ss), fill=NAVY, width=2 * ss)
        ctext(d, "Free from Port Haven Chandlery - mind the Bar", font(FONT_S, 11 * ss), 482 * ss, w, NAVY)
        for k in range(3):
            d.arc((w - 60 * ss, (16 + k * 6) * ss, w - 20 * ss, (40 + k * 6) * ss), 200, 340, fill=NAVY, width=2 * ss)

    # knots chart: nine knots drawn as rope with over-under crossings
    def catmull(pts, n=10):
        P = np.array(pts, float)
        P = np.vstack([P[:1], P, P[-1:]])
        out = []
        for i in range(1, len(P) - 2):
            p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
            for t in np.linspace(0, 1, n, endpoint=False):
                out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
        out.append(P[-2])
        return out

    def knots_fn(d, ss, w, h):
        d.rectangle((0, 0, w, h), fill=(236, 230, 214))
        d.rectangle((8 * ss, 8 * ss, w - 8 * ss, h - 8 * ss), outline=NAVY, width=3 * ss)
        ctext(d, "KNOTS EVERY HAND SHOULD KNOW", font(FONT_B, 24 * ss), 20 * ss, w, NAVY)
        ctext(d, "practise them on the quay before you need them at sea", font(FONT_S, 12 * ss), 50 * ss, w, MAROON)
        names = ["BOWLINE", "CLOVE HITCH", "REEF KNOT", "FIGURE OF EIGHT", "SHEET BEND", "ROUND TURN & 2 HALF HITCHES",
                 "CLEAT HITCH", "ROLLING HITCH", "FISHERMAN'S BEND"]
        cw, chh, oy = (w / ss - 32) / 3, (h / ss - 90) / 3, 76
        fl = font(FONT_B, 10 * ss)

        def rope(pts, cx, cy, col=(196, 160, 104)):
            q = [((cx + x) * ss, (cy + y) * ss) for x, y in catmull(pts)]
            d.line(q, fill=(70, 52, 34), width=11 * ss, joint="curve")
            d.line(q, fill=col, width=7 * ss, joint="curve")
            d.line(q, fill=tuple(min(255, c + 40) for c in col), width=2 * ss, joint="curve")

        def spar(cx, cy, vertical=True):
            if vertical:
                d.rectangle(((cx - 9) * ss, (cy - 52) * ss, (cx + 9) * ss, (cy + 52) * ss), fill=(132, 96, 64), outline=(70, 52, 34), width=2 * ss)
            else:
                d.rectangle(((cx - 60) * ss, (cy - 36) * ss, (cx + 60) * ss, (cy - 22) * ss), fill=(132, 96, 64), outline=(70, 52, 34), width=2 * ss)
        for i, nm in enumerate(names):
            c, r_ = i % 3, i // 3
            x0, y0 = 16 + c * cw, oy + r_ * chh
            cx, cy = x0 + cw / 2, y0 + chh / 2 - 8
            d.rectangle((x0 * ss, y0 * ss, (x0 + cw - 4) * ss, (y0 + chh - 4) * ss), outline=(160, 150, 130), width=ss)
            if nm == "BOWLINE":
                rope([(-50, 50), (-20, 20), (-30, -10), (0, -30), (25, -10), (5, 10), (-20, 0)], cx, cy)
                rope([(40, 50), (30, 0), (0, -45), (-25, -20)], cx, cy)
                rope([(-30, -10), (-30, 30), (0, 48), (30, 30), (30, 0)], cx, cy)
            elif nm in ("CLOVE HITCH", "ROLLING HITCH"):
                spar(cx, cy)
                wraps = 2 if nm == "CLOVE HITCH" else 3
                rope([(-60, -40), (-12, -30), (12, -18)], cx, cy)
                for k in range(wraps):
                    rope([(-12, -22 + k * 18), (12, -10 + k * 18)], cx, cy)
                rope([(12, -10 + (wraps - 1) * 18), (40, 10 + wraps * 6), (60, 40)], cx, cy)
            elif nm == "REEF KNOT":
                rope([(-60, -12), (-10, -12), (14, -6), (14, 6), (-10, 12), (-60, 12)], cx, cy, (196, 160, 104))
                rope([(60, 12), (10, 12), (-14, 6), (-14, -6), (10, -12), (60, -12)], cx, cy, (110, 120, 140))
                rope([(-10, -12), (14, -6)], cx, cy, (196, 160, 104))
            elif nm == "FIGURE OF EIGHT":
                rope([(-60, 30), (-20, 30), (20, -20), (40, -20), (40, 10), (20, 20), (-10, -20), (-30, -20), (-30, 10), (0, 30), (60, 30)], cx, cy)
                rope([(20, -20), (40, -20)], cx, cy)
            elif nm == "SHEET BEND":
                rope([(60, -16), (0, -16), (-24, 0), (0, 16), (60, 16)], cx, cy, (110, 120, 140))
                rope([(-60, 30), (-10, 22), (14, 0), (-6, -24), (-30, -10), (-10, 10), (40, 34)], cx, cy)
            elif nm.startswith("ROUND TURN"):
                spar(cx, cy, vertical=False)
                rope([(-20, -40), (-26, -20), (-14, -18), (-6, -40), (0, -20), (6, -14)], cx, cy)
                rope([(6, -14), (10, 10), (0, 26), (16, 34), (20, 14), (30, 30), (40, 50)], cx, cy)
                rope([(-14, -18), (-20, 50)], cx, cy)
            elif nm == "CLEAT HITCH":
                d.rounded_rectangle(((cx - 58) * ss, (cy - 8) * ss, (cx + 58) * ss, (cy + 8) * ss), radius=8 * ss, fill=(150, 150, 146), outline=(70, 70, 70), width=2 * ss)
                d.rectangle(((cx - 16) * ss, (cy + 8) * ss, (cx + 16) * ss, (cy + 22) * ss), fill=(130, 130, 126), outline=(70, 70, 70), width=2 * ss)
                rope([(-60, 50), (-20, 20), (30, -14), (40, 10), (-30, -12), (-44, 10), (30, 14), (50, 40)], cx, cy)
            else:
                d.ellipse(((cx - 30) * ss, (cy - 50) * ss, (cx + 30) * ss, (cy + 10) * ss), outline=(150, 150, 146), width=7 * ss)
                rope([(-10, 50), (-8, 8), (-14, -14), (0, 16), (8, -12), (12, 10), (30, 30), (60, 40)], cx, cy)
            ctext(d, nm, fl if len(nm) < 18 else font(FONT_B, 8 * ss), (y0 + chh - 22) * ss, (x0 + cw) * ss, INKC, x0=0) \
                if False else d.text((x0 * ss + ((cw - 4) * ss - d.textlength(nm, font=fl if len(nm) < 18 else font(FONT_B, 8 * ss))) / 2,
                                      (y0 + chh - 22) * ss), nm, fill=INKC, font=fl if len(nm) < 18 else font(FONT_B, 8 * ss))
        ctext(d, "PORT HAVEN CHANDLERY  -  rope cut to length", font(FONT_S, 11 * ss), h - 26 * ss, w, NAVY)

    # lifeboat day poster
    def lifeboat_fn(d, ss, w, h):
        d.rectangle((0, 0, w, 150 * ss), fill=(200, 216, 222))
        d.line((0, 18 * ss, w, 26 * ss), fill=INKC, width=ss)
        cols = [(178, 56, 44), (36, 52, 84), (232, 226, 210), (214, 120, 40)]
        for k in range(9):
            x = k * 44 * ss
            yb = (18 + 8 * k / 9) * ss
            d.polygon([(x, yb), (x + 40 * ss, yb + ss), (x + 20 * ss, yb + 34 * ss)], fill=cols[k % 4])
        ctext(d, "PORT HAVEN", font(FONT_B, 30 * ss), 62 * ss, w, NAVY)
        ctext(d, "LIFEBOAT DAY", font(FONT_B, 40 * ss), 96 * ss, w, MAROON)
        # sea, boat, flag
        d.rectangle((0, 150 * ss, w, 300 * ss), fill=(64, 98, 120))
        for k in range(6):
            d.arc((-20 * ss + k * 70 * ss, 268 * ss, 60 * ss + k * 70 * ss, 300 * ss), 200, 340, fill=(220, 230, 232), width=3 * ss)
        cx = w / 2
        d.polygon([(cx - 130 * ss, 236 * ss), (cx + 150 * ss, 230 * ss), (cx + 120 * ss, 276 * ss), (cx - 110 * ss, 276 * ss)], fill=(36, 52, 84))
        d.rectangle((cx - 110 * ss, 254 * ss, cx + 130 * ss, 262 * ss), fill=(232, 226, 210))
        d.polygon([(cx - 70 * ss, 236 * ss), (cx - 60 * ss, 196 * ss), (cx + 50 * ss, 196 * ss), (cx + 70 * ss, 236 * ss)], fill=(214, 120, 40))
        for k in range(4):
            d.rectangle((cx + (-52 + k * 26) * ss, 204 * ss, cx + (-36 + k * 26) * ss, 218 * ss), fill=(40, 46, 54))
        d.line((cx - 10 * ss, 196 * ss, cx - 10 * ss, 160 * ss), fill=INKC, width=3 * ss)
        d.polygon([(cx - 8 * ss, 160 * ss), (cx + 40 * ss, 168 * ss), (cx - 8 * ss, 178 * ss)], fill=(232, 226, 210))
        d.line((cx - 8 * ss, 169 * ss, cx + 30 * ss, 169 * ss), fill=(178, 56, 44), width=4 * ss)
        ctext(d, "SATURDAY 15th AUGUST", font(FONT_B, 22 * ss), 312 * ss, w, NAVY)
        fr = font(FONT_R, 14 * ss)
        for k, line in enumerate(("Boathouse open from 10am", "Launch demonstration 11.30", "Raft race  -  crab-line contest",
                                  "Teas, cakes and tombola")):
            ctext(d, line, fr, (346 + k * 24) * ss, w, INKC)
        d.line((30 * ss, 452 * ss, w - 30 * ss, 452 * ss), fill=MAROON, width=2 * ss)
        ctext(d, "All proceeds to the Port Haven Sea Rescue crew", font(FONT_S, 12 * ss), 462 * ss, w, MAROON)
        ctext(d, "volunteers welcome - ask at the counter", font(FONT_S, 11 * ss), 482 * ss, w, INKC)

    def notice0_fn(d, ss, w, h):
        d.line((0, 34 * ss, w, 34 * ss), fill=(178, 56, 44), width=2 * ss)
        for k in range(1, 9):
            d.line((0, (34 + k * 24) * ss, w, (34 + k * 24) * ss), fill=(150, 170, 200), width=ss)
        fh = font(FONT_H, 22 * ss)
        ctext(d, "SEA SAFETY TALK", fh, 6 * ss, w, NAVY)
        f2 = font(FONT_H, 16 * ss)
        for k, line in enumerate(("Thursdays 7pm", "at the boathouse", "lifejackets, flares, VHF", "kettle on - all welcome", "free!")):
            ctext(d, line, f2, (40 + k * 24) * ss, w, (40, 44, 70) if k < 4 else MAROON)

    def notice1_fn(d, ss, w, h):
        d.rectangle((10 * ss, 10 * ss, w - 10 * ss, h - 10 * ss), outline=INKC, width=2 * ss)
        ctext(d, "LOFT", font(FONT_B, 48 * ss), 20 * ss, w, MAROON)
        cx = w / 2
        d.polygon([(cx - 22 * ss, 108 * ss), (cx, 80 * ss), (cx + 22 * ss, 108 * ss)], fill=MAROON)
        d.rectangle((cx - 7 * ss, 106 * ss, cx + 7 * ss, 126 * ss), fill=MAROON)
        fr = font(FONT_R, 16 * ss)
        for k, line in enumerate(("Fitting room", "Foul-weather gear", "Please mind the stairs")):
            ctext(d, line, fr if k < 2 else font(FONT_B, 14 * ss), (140 + k * 26) * ss, w, INKC)

    for k, (name, fn) in enumerate((("Tide", tide_fn), ("Lifeboat", lifeboat_fn), ("Knots", knots_fn),
                                    ("Notice0", notice0_fn), ("Notice1", notice1_fn))):
        r0, r1, c0, c1 = box(name)
        age_poster(name, paper_img(c1 - c0, r1 - r0, fn), 300 + k, fade=(0.78, 0.66, 0.85, 0.9, 0.82)[k],
                   curl=((0.8, 1.1, 1.3, 0.9), (1.0, 0.7, 1.4, 1.2), (0.4, 0.4, 0.4, 0.4), (0.9, 1.0, 1.6, 1.3), (0.8, 0.8, 1.4, 1.5))[k])

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
    border = 1 - smooth(9, 13, e)
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
