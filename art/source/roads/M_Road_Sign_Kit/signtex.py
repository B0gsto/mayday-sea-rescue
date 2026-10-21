"""M_Road_Sign_Kit sign atlas T_Sign_Main_* (docs/12 2.4; system python3 + numpy + Pillow, no heavy slot).

    python3 art/source/roads/M_Road_Sign_Kit/signtex.py [--out DIR]

Writes build/prod/M_Road_Sign_Kit/textures/M_Road_Sign_Kit/ (ship 1024) and masters 2048 to
art/source/roads/M_Road_Sign_Kit/textures/, plus T_Sign_Main_signal.png (the red and blue signal cells, for
check_textures.py). One shared atlas for all five signs (sign_layout.py holds the rects):

  trim column   galvanised post steel (zinc spangle, rain wash, dried salt, rust specks), its splash band at the post
                feet (road grit, salt bloom, rust at the base), the fingerpost's white painted timber and its own
                splash and lichen band, milled aluminium for plate backs and folded rims, dull oiled steel for bolts,
                and the band clip drawn once with rust at its folded ends.
  face column   one rect per printed face, painted as vector art at 3x and downsampled (docs/05 5.5), each in its own
                true aspect ratio: four fingerpost blades (PORT HAVEN 1, HAVEN SANDS 1/2, HAVEN HEAD 3/4, GALE ISLES 3),
                the Port Haven tide table board, the lifeboat launch sign, the car park sign, and the cliff warning
                triangle with its CLIFF EDGE plate. Lettering is DIN (a UK signage-flavoured grotesque, the same family
                M_Bld_Station's fascia uses), never a copy of a real sign. Every name and number is invented
                (docs/01: Port Haven, Haven Sands, Haven Head, Gale Isles).

Wear follows real causes (docs/05 5.4): sun and rain bleach the paint from the top down, spray dries as salt bloom
along the bottom edges and in the sheltered corners, rain carries rust down from the fixings, chips show bare metal,
and lichen crusts colonise the painted timber low down.
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import texlib as T  # noqa: E402
import sign_layout as L  # noqa: E402

F32 = np.float32
M = L.M
SHIP = L.SHIP
MASTERS = os.path.join(HERE, "textures")
DEFAULT_OUT = os.path.join(T.GAME, "build/prod/M_Road_Sign_Kit/textures/M_Road_Sign_Kit")
STEM = "T_Sign_Main"
SUPP = "/System/Library/Fonts/Supplemental/"
FONT_NAMES = ("DIN Alternate Bold.ttf", "DIN Condensed Bold.ttf", "Arial Bold.ttf", "Arial Black.ttf")

# ---- palette (docs/05 3.1 reference palette; signal colours are real signage, kept inside the signal mask)
WHITE = (236, 233, 226)          # sign face paint, chalky off-white
BLACK = (38, 38, 40)             # printed black
GREY = (96, 97, 99)              # printed grey (notes, rules)
RED = (196, 30, 42)              # BS 381C 537 signal red (approximation, verify)
BLUE = (0, 62, 140)              # BS 381C 108 aircraft blue (approximation, verify)
ZINC = 190.0                     # clean hot-dip galvanising
ALU = (194, 196, 193)            # milled aluminium (bright: metals keep sRGB 180 to 250)
STEEL = 104.0                    # dull oiled steel
RUST = (139, 74, 37)             # docs/05: rust
SALT = (217, 214, 204)           # docs/05: salt crust
LICHEN = (201, 180, 88)          # docs/05: lichen (yellow)
LICHEN2 = (156, 166, 112)        # grey-green lichen
MOSS = (94, 110, 58)

_fonts = {}


def font(px):
    """The DIN-flavoured face of the kit, at `px` (canvas pixels)."""
    px = max(6, int(px))
    if px not in _fonts:
        for n in FONT_NAMES:
            p = os.path.join(SUPP, n)
            if os.path.isfile(p):
                _fonts[px] = ImageFont.truetype(p, px)
                break
        else:
            _fonts[px] = ImageFont.load_default()
    return _fonts[px]


def cap_px(d, f):
    b = d.textbbox((0, 0), "H", font=f, anchor="ls")
    return -b[1]


def fit_cap(d, text, cap, max_w):
    """The font whose cap height is closest under `cap` canvas px and whose line fits `max_w`."""
    size = max(6, int(cap * 1.25))
    while size > 6:
        f = font(size)
        if cap_px(d, f) <= cap and d.textlength(text, font=f) <= max_w:
            return f
        size -= 1
    return font(6)


def rgb(c):
    return np.array(c, F32)


def smear_down(mask, steps, decay):
    """Run-off: the mask repeated downward with decaying strength (image rows run down the part)."""
    out = mask.copy()
    for i in range(1, steps + 1):
        out = np.maximum(out, np.roll(mask, i, 0) * (decay ** i))
    return out


def streams(hw, seed, length, thin=0.085):
    """A field of thin vertical streams (rain wash, rust runs), periodic both ways."""
    cols = T.noise((hw[0], max(8, hw[1] // 8)), 12, seed + 1, 3)
    cols = np.asarray(Image.fromarray(cols, "F").resize((hw[1], hw[0]), Image.BILINEAR), F32)
    line = (1 - T.sstep(0.0, thin, np.abs(T.noise(hw, 30, seed + 2, 2, aniso=(0.10, 1.0)) - 0.5)))
    return smear_down(line * T.sstep(0.40, 0.72, cols), max(1, int(length)), 0.985)


# ---------------------------------------------------------------------------------------------------- vector art
class Face:
    """Supersampled art canvas for one face rect. Work in millimetres from the face's top-left corner."""

    def __init__(self, w, h, w_m, h_m, ss=3, bg=WHITE):
        self.w, self.h, self.ss = w, h, ss
        self.k = (w / w_m) / 1000.0 * ss              # canvas pixels per millimetre
        self.im = Image.new("RGB", (w * ss, h * ss), tuple(int(v) for v in bg))
        self.d = ImageDraw.Draw(self.im)
        self.bg = bg

    def p(self, mm):
        return mm * self.k

    def line(self, p0, p1, fill, width_mm=2.0):
        self.d.line((self.p(p0[0]), self.p(p0[1]), self.p(p1[0]), self.p(p1[1])), fill=fill, width=max(1, int(round(self.p(width_mm)))))

    def poly(self, pts, fill, outline=None, width_mm=0.0):
        q = [(self.p(x), self.p(y)) for x, y in pts]
        self.d.polygon(q, fill=fill, outline=outline, width=int(round(self.p(width_mm))) if width_mm else 0)

    def text(self, x_mm, base_mm, s, cap_mm, fill, max_w_mm=None, anchor="ls", track=0.0):
        """Draw `s` with a cap height of `cap_mm`, baseline at `base_mm`, left edge at `x_mm` (anchor 'ms' centres)."""
        cap = self.p(cap_mm)
        f = fit_cap(self.d, s, cap, self.p(max_w_mm) if max_w_mm else self.w * self.ss)
        if track:                                     # letterspacing (a few signs set the small lines open)
            total = sum(self.d.textlength(ch, font=f) for ch in s) + self.p(track) * max(0, len(s) - 1)
            x = self.p(x_mm) - (total / 2.0 if anchor[0] == "m" else total if anchor[0] == "r" else 0.0)
            for ch in s:
                b = self.d.textbbox((0, 0), ch, font=f, anchor="ls")
                self.d.text((x - b[0], self.p(base_mm)), ch, font=f, fill=fill)
                x += self.d.textlength(ch, font=f) + self.p(track)
            return x
        self.d.text((self.p(x_mm), self.p(base_mm)), s, font=f, fill=fill, anchor=anchor)
        return 0.0

    def tw(self, s, cap_mm):
        f = fit_cap(self.d, s, self.p(cap_mm), self.w * self.ss)
        return self.d.textlength(s, font=f) / self.k

    def arr(self):
        if self.ss > 1:
            return np.asarray(self.im.resize((self.w, self.h), Image.LANCZOS), F32)
        return np.asarray(self.im, F32)


# ---------------------------------------------------------------------------------------------------- wear layers
def chalky(a, hw, seed, top=0.35, bottom=0.10):
    """Paint bleaching: sun and rain wash the print from the top down; greyer and flatter low down (docs/05 5.4).
    Kept smooth (a gentle large-scale drift only): faded sign paint goes patchy at the scale of the whole plate, it
    does not mottle."""
    h = hw[0]
    yo = (np.arange(h, dtype=F32) / h)[:, None] * np.ones((1, hw[1]), F32)      # 0 at the top of the face
    fade = top * (1.0 - yo) ** 1.6 + bottom * yo
    fade = fade * (0.75 + 0.45 * T.noise(hw, 3, seed, 2))
    return T.blend(a, np.dstack([(t + 16) * 0.99 for t in (T.luma(a),) * 3]).astype(F32), np.clip(fade, 0, 0.45))


def salt_bloom(a, rgh, hw, seed, k=1.0, bottom=0.30):
    """Spray dries as salt: fine bloom patches, gathered along the bottom edge and the sheltered corners."""
    h = hw[0]
    yo = (np.arange(h, dtype=F32) / h)[:, None] * np.ones((1, hw[1]), F32)
    edge = np.clip((yo - (1.0 - bottom)) / max(bottom, 1e-3), 0, 1) ** 1.2
    core = T.sstep(0.70, 0.89, T.noise(hw, 34, seed, 3, aniso=(0.85, 1.0)))
    salt = np.clip(core * (0.12 + 0.95 * np.exp(-np.maximum(1.0 - yo - 0.10, 0) / 0.26)) + edge * core * 1.3, 0, 1) * k
    a = T.blend(a, np.broadcast_to(rgb(SALT), a.shape).copy(), salt * 0.22)
    rgh = rgh + 0.16 * salt
    return a, rgh, salt


def rust_runs(a, rgh, hw, seed, pts, k=1.0):
    """Rain carries rust down from fixing points: `pts` are (x_px, y_px, strength) seed points."""
    h, w = hw
    src = np.zeros(hw, F32)
    for (px, py, s) in pts:
        blob = np.exp(-(((np.arange(w)[None, :] - px) / (0.006 * w + 2.0)) ** 2)) * np.exp(-((np.arange(h)[:, None] - py) / 6.0) ** 2)
        src = np.maximum(src, blob * s)
    run = smear_down(src, min(h - 1, int(0.32 * h)), 0.988) * (0.45 + 0.65 * T.noise(hw, 24, seed, 2, aniso=(0.35, 1.4)))
    run = np.clip(run, 0, 1) * k
    a = T.blend(a, np.dstack([rgb(RUST)[..., 0] * (0.8 + 0.4 * T.noise(hw, 60, seed + 1, 2)),
                              rgb(RUST)[..., 1] * (0.8 + 0.4 * T.noise(hw, 60, seed + 1, 2)),
                              rgb(RUST)[..., 2] * (0.8 + 0.4 * T.noise(hw, 60, seed + 1, 2))]).astype(F32),
                T.sstep(0.15, 0.75, run) * 0.72)
    rgh = rgh + 0.22 * T.sstep(0.2, 0.8, run)
    return a, rgh, run


def grime(a, rgh, hw, seed, film=0.16, gutter=0.35):
    """A coastal film over everything and a dirt gutter along the bottom edge and in the inside corners."""
    h = hw[0]
    yo = (np.arange(h, dtype=F32) / h)[:, None] * np.ones((1, hw[1]), F32)
    n = T.noise(hw, 9, seed, 3)
    f = film * (0.55 + 0.8 * n)
    g = gutter * np.clip((yo - 0.88) / 0.12, 0, 1) ** 1.5 * (0.5 + 0.9 * T.noise(hw, 20, seed + 1, 2))
    a = T.blend(a, np.dstack([104 + 14 * n, 100 + 12 * n, 92 + 10 * n]).astype(F32), np.clip(f + g, 0, 0.62))
    rgh = rgh + 0.14 * f + 0.2 * g
    return a, rgh


def chips(a, rgh, hw, seed, k=1.0, colour=(150, 150, 146)):
    """Paint chips and scuffs through to the primer: small, mostly on edges and high points."""
    h, w = hw
    n = T.noise(hw, 90, seed, 2)
    e = T.noise(hw, 24, seed + 1, 3, aniso=(0.5, 1.0))
    m = T.sstep(0.86, 0.93, n * 0.65 + e * 0.55) * k
    a = T.blend(a, np.broadcast_to(rgb(colour), a.shape).copy(), m * 0.85)
    rgh = rgh + 0.25 * m
    return a, rgh, m


def lichen(hw, seed, cover=0.5, cell=0.055, per_u=1.0, per_v=None):
    """Lichen crusts: small Voronoi colonies, each a little rosette with a paler rim, and the whole growth held inside
    big patches (lichen colonises a corner or a sheltered face, never the whole post evenly). Colours stay close to the
    paint's own value: a grey-green crust with the odd fleck of the yellow thallus (docs/05: lichen #C9B458)."""
    h, w = hw
    x = (np.arange(w, dtype=F32)[None, :] / w) * per_u
    y = (np.arange(h, dtype=F32)[:, None] / h) * (per_v if per_v else 1.0)
    wob = 0.80 + 0.45 * T.noise(hw, 22, seed + 14, 2)                             # the colony edge is never a clean arc
    f1, f2, cid = T.voronoi(np.broadcast_to(x, hw).copy(), np.broadcast_to(y, hw).copy(), cell, per_u, per_v, seed)
    rosette = 1.0 - (f1 * wob) / max(cell * 1.15, 1e-6)
    rim = np.clip((f2 - f1) / max(cell * 0.45, 1e-6), 0, 1) ** 0.7
    inside = T.sstep(0.05, 0.55, rosette) * (0.35 + 0.75 * T.noise(hw, 42, seed + 15, 2))
    keep = T.sstep(1.0 - cover, 1.0 - cover + 0.34, T.hash01(cid, seed))
    patch = T.sstep(0.46, 0.80, T.noise(hw, 5, seed + 11, 3)) * (0.35 + 0.85 * T.noise(hw, 15, seed + 12, 3))
    m = np.clip(inside * keep * patch, 0, 1)
    tint = np.clip(T.hash01(cid, seed + 7), 0, 1)
    yellow = T.sstep(0.62, 0.86, T.noise(hw, 26, seed + 16, 3))                    # only some colonies carry thallus
    col = (rgb(LICHEN2)[None, None, :] * (0.85 + 0.25 * rim[..., None]) * (1.0 - yellow[..., None])
           + rgb(LICHEN)[None, None, :] * (0.32 + 0.42 * tint[..., None]) * yellow[..., None])
    col = col * (0.85 + 0.30 * T.noise(hw, 34, seed + 13, 2)[..., None])
    return m, rim, col.astype(F32)


# ---------------------------------------------------------------------------------------------------- trim materials
def zinc_base(hw, seed, ppm):
    """The hot-dip galvanised surface itself: flat mid-grey, zinc spangle, rolling smudge, fine grain, faint scuffs."""
    spang = T.noise(hw, max(8, int(ppm * 0.055)), seed, 3)                     # ~5 cm spangle
    fine = T.noise(hw, max(20, int(ppm * 0.012)), seed + 1, 2)                 # ~1 cm grain
    roll = T.noise(hw, 4, seed + 2, 3, aniso=(2.6, 1.0))                       # rolling / rub smudge along the part
    v = 190.0 + 3.0 * (spang - 0.5) * 2 + 2.0 * (fine - 0.5) * 2 + 4.5 * (roll - 0.5) * 2
    a = np.dstack([v, v, v * 1.004]).astype(F32)
    rgh = 0.34 + 0.08 * (spang - 0.5) * 2 + 0.05 * (fine - 0.5) * 2
    hgt = (fine - 0.5) * 5e-5 + (spang - 0.5) * 6e-5
    met = np.ones(hw, F32)
    return a, rgh, hgt, met


def metal_finish(a, rgh, hgt, met, hw):
    """Metalness drops to a dielectric wherever paint, dirt or rust covers the steel; the boundary stays sharp so the
    ALB check never sees a dark pixel wearing a metal mask (barriertex does the same)."""
    met = np.clip(met, 0, 1) * T.sstep(186.0, 195.0, T.luma(a))
    return a, np.clip(rgh, 0.22, 0.95), hgt, met


def galv(w, h, seed, tile):
    """Galvanised post steel above the splash line: zinc, rain wash down it, dried salt, a few rust spots and scuffs."""
    hw = (h, w)
    ppm = w / tile[0]
    a, rgh, hgt, met = zinc_base(hw, seed, ppm)
    patina = T.sstep(0.42, 0.70, T.noise(hw, 4, seed + 20, 3)) * (0.6 + 0.4 * T.noise(hw, 15, seed + 21, 3))
    a = T.blend(a, np.dstack([169 + 9 * patina] * 2 + [163 + 8 * patina]).astype(F32), patina * 0.60)
    rgh = rgh + 0.13 * patina
    met = met * (1 - 0.9 * T.sstep(0.35, 0.75, patina))
    hgt = hgt - patina * 1e-4
    wash = streams(hw, seed + 3, 260) * (0.5 + 0.5 * patina)                   # rain carries grime down the post
    a = T.blend(a, np.dstack([132 + 12 * wash] * 2 + [124 + 10 * wash]).astype(F32), np.clip(wash, 0, 1) * 0.30)
    rgh = rgh + 0.16 * wash
    met = met * (1 - 0.55 * np.clip(wash * 1.4, 0, 1))
    salt = T.sstep(0.70, 0.86, T.noise(hw, 30, seed + 4, 3, aniso=(0.9, 1.2))) * 0.45
    a = T.blend(a, np.broadcast_to(rgb(SALT), a.shape).copy(), salt * 0.20)
    rgh = rgh + 0.14 * salt
    # the post's foot: the splash band layers (road grit, dried salt, moss, rust at the base) over the bottom GROUND_M
    z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * tile[1] * np.ones((1, w), F32)
    gmask = (1.0 - T.sstep(L.GROUND_M * 0.75, L.GROUND_M * 1.25, z)) * 0.95
    gb, gr, gh, gm = galv_ground(w, h, seed + 31, tile)
    a = a * (1 - gmask[..., None]) + gb * gmask[..., None]
    rgh = rgh * (1 - gmask) + gr * gmask
    hgt = hgt * (1 - gmask) + gh * gmask
    met = met * (1 - gmask) + gm * gmask
    spot = T.sstep(0.855, 0.925, T.noise(hw, 22, seed + 5, 3))
    run = smear_down(spot, max(4, int(0.10 * h)), 0.975)
    a = T.blend(a, np.dstack([rgb(RUST)[..., 0] * (0.85 + 0.3 * spot), rgb(RUST)[..., 1] * (0.85 + 0.3 * spot),
                              rgb(RUST)[..., 2] * (0.85 + 0.3 * spot)]).astype(F32), T.sstep(0.25, 0.85, run) * 0.6)
    rgh = rgh + 0.22 * T.sstep(0.3, 0.9, run)
    met = met * (1 - 0.9 * T.sstep(0.15, 0.5, run))
    sc = T.noise(hw, 40, seed + 6, 2, aniso=(0.14, 1.0))                       # bright scuffs and grazes
    scuff = (1 - T.sstep(0.0, 0.030, np.abs(sc - 0.5))) * T.sstep(0.55, 0.80, T.noise(hw, 5, seed + 7, 3))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (216, 216, 210)]), scuff * 0.30)
    met = np.maximum(met, T.sstep(0.4, 0.8, scuff))
    rgh = rgh * (1 - scuff * 0.5) + scuff * 0.5 * 0.26
    hgt = hgt - T.sstep(0.3, 0.9, run) * 3e-4
    a = a * (1 + 0.035 * (T.noise(hw, 3, seed + 8, 2)[..., None] - 0.5))
    return metal_finish(np.clip(a, 30, 246), rgh, hgt, met, hw)


def galv_ground(w, h, seed, tile):
    """The foot of a galvanised post: road splash and grit, dried salt, moss at the ground line, rust from the base."""
    hw = (h, w)
    ppm = w / tile[0]
    a, rgh, hgt, met = zinc_base(hw, seed + 31, ppm)
    z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * tile[1] * np.ones((1, w), F32)     # m above ground
    grit = T.noise(hw, max(60, int(w / 0.005)), seed + 32, 1)
    splash = np.clip(np.exp(-np.maximum(z - 0.04, 0) / 0.16) * (0.75 + 0.6 * T.noise(hw, 8, seed + 33, 3)) - 0.10, 0, 1)
    splash = np.clip(splash * (0.75 + 0.5 * grit), 0, 1)
    a = T.blend(a, np.dstack([112 + 20 * grit, 102 + 16 * grit, 88 + 13 * grit]).astype(F32), splash * 0.92)
    rgh = rgh * (1 - splash) + 0.90 * splash
    met = met * (1 - 0.92 * splash)
    hgt = hgt * (1 - splash) + splash * (grit - 0.5) * 1.1e-3
    salt = T.sstep(0.62, 0.82, T.noise(hw, 34, seed + 34, 3, aniso=(0.85, 1.0))) * np.exp(-np.maximum(z - 0.06, 0) / 0.30)
    a = T.blend(a, np.broadcast_to(rgb(SALT), a.shape).copy(), salt * 0.42)
    rgh = rgh + 0.16 * salt
    moss = T.sstep(0.72, 0.92, T.noise(hw, 14, seed + 35, 3)) * np.exp(-z / 0.07)
    a = T.blend(a, np.dstack([rgb(MOSS)[..., 0] * (0.8 + 0.4 * grit)] * 3).astype(F32) * np.array([1.0, 1.05, 0.9], F32),
                moss * 0.55)
    rgh = rgh + 0.18 * moss
    met = met * (1 - 0.8 * moss)
    rust = np.clip(T.sstep(0.66, 0.86, T.noise(hw, 16, seed + 36, 3)) * (0.35 + 0.9 * np.exp(-z / 0.30)) +
                   np.exp(-z / 0.035) * 0.55, 0, 1)
    pit = T.noise(hw, max(40, int(w / 0.006)), seed + 37, 1)
    a = T.blend(a, np.dstack([130 + 24 * pit, 96 + 16 * pit, 72 + 12 * pit]).astype(F32), T.sstep(0.12, 0.6, rust) * 0.8)
    rgh = rgh + 0.22 * T.sstep(0.2, 0.7, rust)
    met = met * (1 - 0.9 * T.sstep(0.1, 0.45, rust))
    hgt = hgt - T.sstep(0.2, 0.7, rust) * (pit - 0.5) * 6e-4
    return metal_finish(np.clip(a, 30, 246), rgh, hgt, met, hw)


def paint(w, h, seed, tile):
    """The fingerpost's white painted timber: chalky paint, orange-peel, dirt streaks, thin lichen, and its foot band."""
    hw = (h, w)
    ppm = w / tile[0]
    peel = T.noise(hw, max(20, int(ppm * 0.09)), seed, 2)                      # brush / orange-peel mottle
    chalk = T.noise(hw, 6, seed + 1, 3)
    v = np.stack([WHITE[0] + 3 * (peel - 0.5) * 2 + 6 * (chalk - 0.5) * 2,
                  WHITE[1] + 3 * (peel - 0.5) * 2 + 5 * (chalk - 0.5) * 2,
                  WHITE[2] + 3 * (peel - 0.5) * 2 + 4 * (chalk - 0.5) * 2], axis=2).astype(F32)
    a = v
    rgh = 0.52 + 0.10 * (peel - 0.5) * 2 + 0.10 * (chalk - 0.5) * 2
    hgt = (peel - 0.5) * 4e-5
    wash = streams(hw, seed + 2, 240)
    a = T.blend(a, np.dstack([176 + 14 * T.noise(hw, 20, seed + 3, 2)] * 2 + [166 + 12 * T.noise(hw, 20, seed + 3, 2)]).astype(F32),
                np.clip(wash, 0, 1) * 0.34)
    rgh = rgh + 0.14 * wash
    dirt = T.sstep(0.60, 0.85, T.noise(hw, 10, seed + 4, 3))
    a = T.blend(a, np.dstack([168, 164, 152]).astype(F32), dirt * 0.16)
    rgh = rgh + 0.08 * dirt
    lich, edge, col = lichen(hw, seed + 5, cover=0.30, cell=0.032, per_u=tile[0], per_v=tile[1])
    a = T.blend(a, col, lich * 0.30)
    rgh = rgh + 0.20 * lich
    hgt = hgt + lich * 1.2e-4
    a, rgh, _ = chips(a, rgh, hw, seed + 6, k=0.55, colour=(178, 174, 166))
    # the post's foot: splash, moss and lichen crusts over the bottom GROUND_M (the painted post meets the ground)
    a, rgh, hgt = paint_ground(a, rgh, hgt, w, h, seed + 41, tile)
    a = a * (1 + 0.03 * (T.noise(hw, 3, seed + 7, 2)[..., None] - 0.5))
    return np.clip(a, 30, 240), np.clip(rgh, 0.25, 0.92), hgt, np.zeros(hw, F32)


def paint_ground(a, rgh, hgt, w, h, seed, tile):
    """The painted post's foot laid over the paint: splash and mud, moss at the ground line, lichen crusts low down."""
    hw = (h, w)
    z = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * tile[1] * np.ones((1, w), F32)
    grit = T.noise(hw, max(50, int(w / 0.005)), seed + 42, 1)
    splash = np.clip(np.exp(-np.maximum(z - 0.03, 0) / 0.14) * (0.7 + 0.6 * T.noise(hw, 7, seed + 43, 3)) - 0.08, 0, 1)
    a = T.blend(a, np.dstack([118 + 22 * grit, 106 + 18 * grit, 92 + 14 * grit]).astype(F32), splash * (0.75 + 0.5 * grit) * 0.8)
    rgh = rgh * (1 - splash) + 0.88 * splash
    lich, edge, col = lichen(hw, seed + 44, cover=0.62, cell=0.030, per_u=tile[0], per_v=tile[1])
    lich = lich * (0.45 + 0.9 * np.exp(-z / 0.32))
    a = T.blend(a, col, lich * 0.52)
    rgh = rgh + 0.22 * lich
    hgt = hgt + lich * 1.6e-4
    moss = T.sstep(0.62, 0.88, T.noise(hw, 12, seed + 45, 3)) * np.exp(-z / 0.09)
    a = T.blend(a, np.dstack([rgb(MOSS)[..., 0]] * 3).astype(F32) * np.array([1.0, 1.1, 0.85], F32), moss * 0.7)
    rgh = rgh + 0.2 * moss
    hgt = hgt + moss * 2e-4
    return a, rgh, hgt


def alu(w, h, seed, tile):
    """Sign plate backs, folded rims and stiffeners: milled aluminium, tool marks, grime, dried salt, water stains."""
    hw = (h, w)
    ppm = w / tile[0]
    tool = T.noise(hw, 5, seed, 2, aniso=(3.2, 0.5))                           # faint linear mill marks
    fine = T.noise(hw, max(24, int(ppm * 0.01)), seed + 1, 2)
    v = np.stack([ALU[0] + 4 * (tool - 0.5) * 2 + 3 * (fine - 0.5) * 2,
                  ALU[1] + 4 * (tool - 0.5) * 2 + 3 * (fine - 0.5) * 2,
                  ALU[2] + 4 * (tool - 0.5) * 2 + 3 * (fine - 0.5) * 2], axis=2).astype(F32)
    a = v
    rgh = 0.40 + 0.10 * (tool - 0.5) * 2 + 0.06 * (fine - 0.5) * 2
    hgt = (fine - 0.5) * 4e-5
    met = np.full(hw, 0.85, F32)
    stain = T.sstep(0.55, 0.80, T.noise(hw, 5, seed + 2, 3))
    a = T.blend(a, np.dstack([136 + 10 * stain] * 2 + [128 + 9 * stain]).astype(F32), stain * 0.45)
    rgh = rgh + 0.22 * stain
    met = met * (1 - 0.85 * T.sstep(0.4, 0.8, stain))
    dust = T.sstep(0.50, 0.80, T.noise(hw, 12, seed + 3, 3))
    a = T.blend(a, np.dstack([150, 146, 134]).astype(F32), dust * 0.30)
    rgh = rgh + 0.16 * dust
    salt = T.sstep(0.74, 0.90, T.noise(hw, 28, seed + 4, 3)) * 0.5
    a = T.blend(a, np.broadcast_to(rgb(SALT), a.shape).copy(), salt * 0.35)
    rgh = rgh + 0.16 * salt
    a, rgh, _ = chips(a, rgh, hw, seed + 5, k=0.5, colour=(206, 208, 205))
    a = a * (1 + 0.03 * (T.noise(hw, 3, seed + 6, 2)[..., None] - 0.5))
    return metal_finish(np.clip(a, 30, 246), rgh, hgt, met, hw)


def dark(w, h, seed, tile):
    """Bolt heads, nuts and clip studs: dull oiled steel, pitted, dusty, with rust in the threads."""
    hw = (h, w)
    nz = T.noise(hw, 12, seed, 3)
    pits = T.noise(hw, 60, seed + 1, 2)
    v = STEEL + 20 * (nz - 0.5) * 2 + 6 * (T.noise(hw, 7, seed + 2, 2) - 0.5) * 2
    a = np.dstack([v * 1.02, v * 0.99, v * 0.94]).astype(F32)
    a = a * (1 - 0.12 * T.sstep(0.62, 0.82, pits)[..., None])
    dust = T.sstep(0.55, 0.85, T.noise(hw, 9, seed + 3, 3))
    a = T.blend(a, np.dstack([132, 122, 104]).astype(F32), dust * 0.28)
    rust = T.sstep(0.78, 0.90, T.noise(hw, 18, seed + 4, 3))
    a = T.blend(a, np.dstack([rgb(RUST)[..., 0]] * 3).astype(F32), rust * 0.5)
    rgh = 0.50 + 0.14 * (nz - 0.5) * 2 + 0.15 * dust + 0.14 * rust
    met = np.full(hw, 0.35, F32) * T.sstep(96.0, 112.0, T.luma(a))
    hgt = (pits - 0.5) * 3e-4 - rust * 2e-4
    return np.clip(a, 30, 236), np.clip(rgh, 0.3, 0.9), hgt, met


def clip(w, h, seed, tile):
    """The galvanised band clip, drawn once and whole: U runs along the strap (0 and 1 at the folded ends, where the
    water sits and the rust blooms), V runs across its 30 mm width (the edges darken)."""
    hw = (h, w)
    ppm = w / L.TILES["clip"][0]
    a, rgh, hgt, met = zinc_base(hw, seed + 61, 600.0)
    u = (np.arange(w, dtype=F32) + 0.5) / w
    x = np.broadcast_to(u[None, :], hw)
    edge_v = np.minimum(np.arange(h, dtype=F32), (h - 1 - np.arange(h, dtype=F32)))[:, None] / h
    ends = np.exp(-x / 0.10) + np.exp(-(1.0 - x) / 0.10)
    rust = np.clip(ends * (0.45 + 0.8 * T.noise(hw, 16, seed + 62, 3)) + T.sstep(0.86, 0.94, T.noise(hw, 26, seed + 63, 2)) * 0.5, 0, 1)
    pit = T.noise(hw, 70, seed + 64, 2)
    a = T.blend(a, np.dstack([132 + 22 * pit, 98 + 16 * pit, 74 + 12 * pit]).astype(F32), T.sstep(0.15, 0.65, rust) * 0.85)
    rgh = rgh + 0.24 * T.sstep(0.2, 0.75, rust)
    met = met * (1 - 0.9 * T.sstep(0.12, 0.5, rust))
    polish = T.sstep(0.35, 0.75, T.noise(hw, 8, seed + 65, 3)) * (1 - np.clip(ends * 1.4, 0, 1))
    a = T.blend(a, np.dstack([np.full(hw, c, F32) for c in (214, 214, 208)]), polish * 0.18)
    met = np.maximum(met, polish)
    rgh = rgh * (1 - polish * 0.55) + polish * 0.55 * 0.24
    dark_edge = np.clip(1.0 - edge_v * 5.0, 0, 1) * 0.35
    a = a * (1 - dark_edge[..., None] * 0.12)
    return metal_finish(np.clip(a, 30, 246), rgh, hgt, met, hw)


# ---------------------------------------------------------------------------------------------------- printed faces
def round_poly(pts, r, n=4):
    """A closed 2D polygon with its corners rounded (n points per corner, quadratic through the vertex)."""
    out = []
    m = len(pts)
    for i in range(m):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % m]
        v1 = (p0[0] - p1[0], p0[1] - p1[1])
        v2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*v1), math.hypot(*v2)
        u1, u2 = (v1[0] / l1, v1[1] / l1), (v2[0] / l2, v2[1] / l2)
        ang = math.acos(max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1])))
        if ang < 1e-3:
            out.append(p1)
            continue
        tan = min(r / math.tan(ang / 2.0), l1 * 0.49, l2 * 0.49)
        t1 = (p1[0] + u1[0] * tan, p1[1] + u1[1] * tan)
        t2 = (p1[0] + u2[0] * tan, p1[1] + u2[1] * tan)
        for k in range(n + 1):
            t = k / float(n)
            out.append(((1 - t) ** 2 * t1[0] + 2 * t * (1 - t) * p1[0] + t * t * t2[0],
                        (1 - t) ** 2 * t1[1] + 2 * t * (1 - t) * p1[1] + t * t * t2[1]))
    return out


def shrink(pts, centre, k):
    """The polygon scaled about `centre` (insetting an equilateral triangle by d is a scale of (side - 3.464 d)/side)."""
    return [(centre[0] + (x - centre[0]) * k, centre[1] + (y - centre[1]) * k) for x, y in pts]


def rock(cx, cy, rx, ry, rot, seed, n=7, jag=0.22):
    """A tumbling rock: an irregular polygon, never a circle."""
    rng = np.random.default_rng(seed)
    pts = []
    for i in range(n):
        a = rot + 2 * math.pi * i / n
        k = 1.0 - jag * rng.random()
        pts.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
    return pts


def wear_face(a, rgh, hw, seed, name, top=0.32, salt=1.0, rust=1.0):
    """The shared wear stack of a printed face: fade, salt, rust runs from the fixings, grime gutter, chips."""
    w_m, h_m, _ppm, _x, _y = L.FACE_SPEC[name]
    a = chalky(a, hw, seed, top=top, bottom=0.05)
    a, rgh, sb = salt_bloom(a, rgh, hw, seed + 1, k=salt)
    pts = [(x_mm / (w_m * 1000.0) * hw[1], y_mm / (h_m * 1000.0) * hw[0], 0.85) for x_mm, y_mm in L.fixings_mm(name)]
    a, rgh, run = rust_runs(a, rgh, hw, seed + 2, pts, k=rust)
    a, rgh = grime(a, rgh, hw, seed + 3, film=0.07, gutter=0.10)
    a, rgh, ch = chips(a, rgh, hw, seed + 4, k=0.40)
    return a, rgh, sb * 0.6 + run * 0.3 + ch * 0.2


def face_wear_maps(a, rgh, crust, hw, seed):
    """A calm painted surface with a little paint texture; dried salt crusts lift it very slightly."""
    hgt = (T.noise(hw, max(16, hw[1] // 9), seed, 2) - 0.5) * 3.0e-5 + crust * 5.0e-5
    return np.clip(a, 30, 240), np.clip(rgh, 0.24, 0.90), hgt, np.zeros(hw, F32)


def blade(w, h, w_m, h_m, seed, dest, dist):
    """A fingerpost blade: white paint, a thin black edge rule that follows the spear point, black DIN lettering and
    the distance at the point. U 0 is the end at the post."""
    hw = (h, w)
    W, H = w_m * 1000.0, h_m * 1000.0
    F = Face(w, h, w_m, h_m, ss=3, bg=WHITE)
    tip, e = 100.0, 4.5
    F.line((e, e), (W - tip, e), BLACK, 1.6)
    F.line((W - tip, e), (W - e, H / 2.0), BLACK, 1.6)
    F.line((W - e, H / 2.0), (W - tip, H - e), BLACK, 1.6)
    F.line((W - tip, H - e), (e, H - e), BLACK, 1.6)
    F.line((e, e), (e, H - e), BLACK, 1.6)
    F.text(62.0, (H + 55.0) / 2.0, dest, 55.0, BLACK, max_w_mm=W - tip - 140.0)
    F.text(W - tip - 16.0, (H + 50.0) / 2.0, dist, 50.0, BLACK, anchor="rs")
    a = F.arr()
    rgh = np.full(hw, 0.46, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "blade_a", top=0.38, salt=0.75, rust=0.5)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


DAYS = ("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN", "MON")


def tideboard(w, h, w_m, h_m, seed):
    """The Port Haven tide table board: printed header, a four-event table for eight days, datum note and a red
    warning band, all on a white card that has faded from the top and salted up from the bottom."""
    hw = (h, w)
    F = Face(w, h, w_m, h_m, ss=2, bg=WHITE)
    W = w_m * 1000.0
    F.text(W / 2.0, 130.0, "PORT HAVEN", 72.0, BLACK, anchor="ms")
    F.text(W / 2.0, 203.0, "TIDE TABLE", 34.0, GREY, anchor="ms", track=3.0)
    F.line((40.0, 232.0), (W - 40.0, 232.0), BLACK, 2.6)
    pairs = (170.0, 335.0, 500.0, 665.0)
    F.text(40.0, 277.0, "DAY", 28.0, BLACK)
    for k, lab in enumerate(("HW", "LW", "HW", "LW")):
        F.text((pairs[k] + 158.0) / 2.0, 277.0, lab, 28.0, BLACK, anchor="ms")
    F.line((40.0, 296.0), (W - 40.0, 296.0), BLACK, 1.6)
    t = 4 * 60 + 12
    for d in range(8):
        base = 350.0 + d * 58.0
        if d % 2 == 1:
            F.d.rectangle((F.p(36.0), F.p(base - 42.0), F.p(W - 36.0), F.p(base + 8.0)), fill=(228, 226, 219))
        F.text(40.0, base, DAYS[d], 26.0, BLACK)
        for ev in range(4):
            mins = (t + ev * (6 * 60 + 12)) % (24 * 60)
            hgt = (4.1 if ev % 2 == 0 else 1.2) + 0.1 * ((d + ev) % 3) - 0.05 * (ev % 2)
            F.text(pairs[ev] + 6.0, base, "%02d:%02d" % (mins // 60, mins % 60), 26.0, BLACK)
            F.text(pairs[ev] + 158.0, base, "%.1f" % hgt, 26.0, BLACK, anchor="rs")
        t = (t + 50) % (24 * 60)
    F.line((40.0, 800.0), (W - 40.0, 800.0), BLACK, 1.6)
    F.text(W / 2.0, 838.0, "HEIGHTS IN METRES ABOVE CHART DATUM", 19.0, GREY, anchor="ms", track=1.0)
    F.text(W / 2.0, 868.0, "TIMES ARE LOCAL", 19.0, GREY, anchor="ms", track=1.0)
    F.d.rectangle((F.p(40.0), F.p(1010.0), F.p(W - 40.0), F.p(1120.0)), fill=RED)
    F.text(W / 2.0, 1085.0, "SLIPWAY KEEP CLEAR", 58.0, WHITE, anchor="ms", max_w_mm=W - 130.0)
    a = F.arr()
    rgh = np.full(hw, 0.50, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "tideboard", top=0.30, salt=1.2, rust=0.7)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


def launch(w, h, w_m, h_m, seed):
    """The slipway launch sign: blue panel, white keyline, a white slipway-and-boat pictogram, LIFEBOAT / LAUNCH."""
    hw = (h, w)
    F = Face(w, h, w_m, h_m, ss=3, bg=BLUE)
    F.poly(round_poly([(14, 14), (736, 14), (736, 536), (14, 536)], 18.0, 4), None, outline=WHITE, width_mm=11.0)
    # slipway: rails, cross ties and the hull of the lifeboat sitting nose-up on the cradle
    F.line((58.0, 424.0), (206.0, 258.0), WHITE, 13.0)
    F.line((86.0, 452.0), (232.0, 288.0), WHITE, 13.0)
    for k in range(4):
        t = 0.16 + 0.22 * k
        ax, ay = 58.0 + (206.0 - 58.0) * t, 424.0 + (258.0 - 424.0) * t
        bx, by = 86.0 + (232.0 - 86.0) * t, 452.0 + (288.0 - 452.0) * t
        F.line((ax, ay), (bx, by), WHITE, 9.0)
    F.poly([(96.0, 350.0), (196.0, 250.0), (224.0, 268.0), (232.0, 292.0), (118.0, 392.0)], WHITE)
    F.line((196.0, 250.0), (250.0, 196.0), WHITE, 4.0)                 # the winch cable up the slipway
    for k in range(3):                                                  # the waterline
        y = 470.0 + 12.0 * k
        F.line((40.0 - 6.0 * k, y), (250.0 + 8.0 * k, y), WHITE, 7.0 - 1.4 * k)
    F.text(262.0, 250.0, "LIFEBOAT", 78.0, WHITE, max_w_mm=460.0)
    F.text(262.0, 356.0, "LAUNCH", 78.0, WHITE, max_w_mm=460.0)
    a = F.arr()
    rgh = np.full(hw, 0.44, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "launch", top=0.26, salt=1.0, rust=0.6)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


def carpark(w, h, w_m, h_m, seed):
    """The car park sign: blue plate, white keyline and the big white P (the international parking place sign)."""
    hw = (h, w)
    F = Face(w, h, w_m, h_m, ss=3, bg=BLUE)
    F.poly(round_poly([(14, 14), (586, 14), (586, 586), (14, 586)], 20.0, 4), None, outline=WHITE, width_mm=11.0)
    F.text(300.0, 435.0, "P", 290.0, WHITE, anchor="ms")
    a = F.arr()
    rgh = np.full(hw, 0.44, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "carpark", top=0.24, salt=1.0, rust=0.55)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


def carpark_plate(w, h, w_m, h_m, seed):
    """The white supplementary plate under the P: HARBOUR CAR PARK and an arrow pointing along the quay."""
    hw = (h, w)
    F = Face(w, h, w_m, h_m, ss=3, bg=WHITE)
    F.poly(round_poly([(8, 8), (592, 8), (592, 192), (8, 192)], 8.0, 3), None, outline=BLACK, width_mm=4.5)
    F.text(26.0, 126.0, "HARBOUR CAR PARK", 46.0, BLACK, max_w_mm=452.0)
    F.line((486.0, 110.0), (548.0, 110.0), BLACK, 9.0)
    F.poly([(548.0, 84.0), (572.0, 110.0), (548.0, 136.0)], BLACK)
    a = F.arr()
    rgh = np.full(hw, 0.48, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "carparkPlate", top=0.30, salt=1.1, rust=0.5)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


def keeper_plate(w, h, w_m, h_m, seed):
    """The small KEEP CLEAR plate under the launch sign: black caps in a red keyline."""
    hw = (h, w)
    F = Face(w, h, w_m, h_m, ss=3, bg=WHITE)
    F.poly(round_poly([(7, 7), (443, 7), (443, 143), (7, 143)], 8.0, 3), None, outline=RED, width_mm=9.0)
    F.text(225.0, 101.0, "KEEP CLEAR", 50.0, BLACK, anchor="ms", max_w_mm=392.0)
    a = F.arr()
    rgh = np.full(hw, 0.48, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "launchKeeper", top=0.30, salt=1.1, rust=0.5)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


def cliff(w, h, w_m, h_m, seed):
    """The cliff warning triangle: 900 mm side, a 12 mm unpainted rim, a 90 mm red border, white field and the black
    rockfall pictogram. The bbox corners outside the plate stay unpainted aluminium."""
    hw = (h, w)
    W, H = w_m * 1000.0, h_m * 1000.0
    F = Face(w, h, w_m, h_m, ss=2, bg=ALU)
    tri = ((W / 2.0, 0.0), (0.0, H), (W, H))
    centre = ((tri[0][0] + tri[1][0] + tri[2][0]) / 3.0, (tri[0][1] + tri[1][1] + tri[2][1]) / 3.0)
    side = W
    F.poly(round_poly(tri, 22.0, 4), RED)                                          # the plate's face, keyed red
    F.poly(round_poly(shrink(tri, centre, (side - 3.464 * 12.0) / side), 18.0, 4), None,
           outline=WHITE, width_mm=7.0)                                            # the white rim line
    field = shrink(tri, centre, (side - 3.464 * 102.0) / side)                     # 90 mm red border inside the rim
    F.poly(round_poly(field, 12.0, 3), WHITE)
    # the rockfall pictogram (diagram of "falling rocks"): a rock face climbing the left of the field, rock breaking
    # away from its jagged edge and tumbling away to the right, a few pieces come to rest at the foot
    top_edge = [(214.0, 664.0), (238.0, 604.0), (256.0, 546.0), (278.0, 488.0), (300.0, 434.0), (326.0, 386.0),
                (352.0, 340.0), (380.0, 298.0), (406.0, 260.0), (430.0, 230.0)]
    face_edge = [(444.0, 250.0), (426.0, 288.0), (446.0, 322.0), (428.0, 362.0), (450.0, 400.0), (430.0, 442.0),
                 (448.0, 482.0), (426.0, 524.0), (444.0, 566.0), (422.0, 608.0), (434.0, 640.0), (418.0, 664.0)]
    F.poly(top_edge + face_edge, BLACK)
    for i, (rx, ry, r, ang) in enumerate(((478.0, 462.0, 22.0, 12.0), (520.0, 512.0, 18.0, -18.0),
                                          (560.0, 556.0, 14.0, 30.0), (600.0, 592.0, 10.0, -8.0),
                                          (634.0, 620.0, 7.0, 22.0))):
        F.poly(rock(rx, ry, r, r * 0.86, math.radians(ang), seed + i), BLACK)
    for i, (rx, ry, r) in enumerate(((456.0, 646.0, 16.0), (596.0, 656.0, 11.0), (520.0, 662.0, 7.0))):
        F.poly(rock(rx, ry, r, r * 0.8, math.radians(40 + 40 * i), seed + 20 + i), BLACK)   # broken away, at rest
    a = F.arr()
    # mask of the painted plate, so the bbox corners outside the triangle stay clean aluminium (no wear, and metalness)
    im = Image.new("L", (w, h), 0)
    d2 = ImageDraw.Draw(im)
    d2.polygon([(x * w / W, y * h / H) for x, y in round_poly(tri, 22.0, 4)], fill=255)
    plate = np.asarray(im, F32) / 255.0
    rgh = np.full(hw, 0.44, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "cliff", top=0.22, salt=1.3, rust=0.6)
    a, rgh, hgt, met = face_wear_maps(a, rgh, crust, hw, seed + 9)
    base = np.broadcast_to(rgb(ALU), a.shape).copy()
    a = a * plate[..., None] + base * (1 - plate[..., None])
    rgh = rgh * plate + (1 - plate) * 0.45
    met = (1 - plate) * 0.55
    return a, rgh, hgt, met


def cliff_plate(w, h, w_m, h_m, seed):
    """The CLIFF EDGE supplementary plate under the triangle."""
    hw = (h, w)
    F = Face(w, h, w_m, h_m, ss=3, bg=WHITE)
    F.poly(round_poly([(8, 8), (592, 8), (592, 292), (8, 292)], 8.0, 3), None, outline=BLACK, width_mm=4.5)
    F.text(300.0, 186.0, "CLIFF EDGE", 86.0, BLACK, anchor="ms", max_w_mm=520.0)
    a = F.arr()
    rgh = np.full(hw, 0.48, F32)
    a, rgh, crust = wear_face(a, rgh, hw, seed, "cliffPlate", top=0.30, salt=1.2, rust=0.5)
    return face_wear_maps(a, rgh, crust, hw, seed + 9)


FACES = (
    ("blade_a", lambda w, h, wm, hm, s: blade(w, h, wm, hm, s, "PORT HAVEN", "1")),
    ("blade_b", lambda w, h, wm, hm, s: blade(w, h, wm, hm, s, "HAVEN SANDS", "\u00bd")),
    ("blade_c", lambda w, h, wm, hm, s: blade(w, h, wm, hm, s, "HAVEN HEAD", "\u00be")),
    ("blade_d", lambda w, h, wm, hm, s: blade(w, h, wm, hm, s, "GALE ISLES", "3")),
    ("tideboard", tideboard),
    ("cliff", cliff),
    ("launch", launch),
    ("carpark", carpark),
    ("cliffPlate", cliff_plate),
    ("carparkPlate", carpark_plate),
    ("launchKeeper", keeper_plate),
)


# ---------------------------------------------------------------------------------------------------- sheet
def build():
    alb = np.full((M, M, 3), 150.0, F32)                     # the sheet's spare cells read as plate metal, never raw
    rgh = np.full((M, M), 0.55, F32)
    nor = np.dstack([np.zeros((M, M)), np.zeros((M, M)), np.ones((M, M))]).astype(F32)
    met = np.full((M, M), 0.25, F32)                         # spare: dielectric so the ALB range check stays happy
    sig = np.zeros((M, M), F32)
    seed = 700
    for region, fn in (("galv", galv), ("paint", paint),
                       ("alu", alu), ("dark", dark), ("clip", clip)):
        x0, y0, w, h = L.region_px(region)
        a, r, hg, m = fn(w, h, seed, L.TILES[region])
        ppm_u = w / L.TILES[region][0]
        ppm_v = h / L.TILES[region][1]
        y1, x1 = y0 + h, x0 + w
        alb[y0:y1, x0:x1] = a
        rgh[y0:y1, x0:x1] = r
        nor[y0:y1, x0:x1] = T.height_normal_uv(hg, ppm_u, ppm_v, 1.0)
        met[y0:y1, x0:x1] = m
        seed += 17
    for name, fn in FACES:
        x0, y0, w, h = L.face_px(name)
        w_m, h_m, ppm, _x, _y = L.FACE_SPEC[name]
        a, r, hg, m = fn(w, h, w_m, h_m, seed)
        y1, x1 = y0 + h, x0 + w
        alb[y0:y1, x0:x1] = a
        rgh[y0:y1, x0:x1] = r
        nor[y0:y1, x0:x1] = T.height_normal_uv(hg, ppm, ppm, 1.0)
        met[y0:y1, x0:x1] = m
        if name in L.signal_faces():
            sig[y0:y1, x0:x1] = 1.0
        seed += 23
    wa, wr = T.wet(alb, rgh, darken=0.24, gloss=0.28)
    wa = T.desat(wa, 0.14)                                   # wet() lifts saturation: keep under the 0.45 ceiling
    wa = np.where(met[..., None] > 0.5, alb * 0.80, wa)       # wet zinc and aluminium dull, they do not darken
    alb = np.where(met[..., None] > 0.5, alb, np.clip(alb, 22, 240))
    wa = np.where(met[..., None] > 0.5, wa, np.clip(wa, 20, 240))
    return alb, rgh, nor, met, wa, wr, sig


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT, help="shipping map folder (default build/prod/M_Road_Sign_Kit/...)")
    args = ap.parse_args()
    problems = L.check()
    for p in problems:
        print("LAYOUT PROBLEM", p)
    if problems:
        raise SystemExit(1)
    alb, rgh, nor, met, wa, wr, sig = build()
    T.save_set(args.out, STEM, alb, rgh, nor, met=met, size=SHIP, wet_maps=(wa, wr), master_dir=MASTERS)
    sig_i = Image.fromarray((np.clip(sig, 0, 1) * 255).astype(np.uint8)).resize((SHIP, SHIP), Image.NEAREST)
    sig_i.point(lambda v: 255 if v > 0 else 0).save(os.path.join(HERE, "%s_signal.png" % STEM))
    print("wrote", STEM, "->", os.path.relpath(args.out, T.GAME), "masters", os.path.relpath(MASTERS, T.GAME))


if __name__ == "__main__":
    main()

