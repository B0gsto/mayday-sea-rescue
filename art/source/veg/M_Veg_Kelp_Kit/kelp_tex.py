"""M_Veg_Kelp_Kit atlas cell painter (pure numpy; runs inside Blender and under system python3).

Shared atlas FoliageMarine / set Main (art/source/materials/atlases.py): this kit owns the `M_Veg_Kelp` cell,
u 0.00..0.25, v 0.50..1.00 (1024 x 2048 px of the 4096 master, 512 x 1024 at the 2048 ship size). Everything this
kit ships lives in that cell; the other three cells stay flat until the wrack and eelgrass batches repaint them.

Inside the cell (cell-local s right, t up; geometry UVs come from `uv()` so painter and mesh always agree):
  BladeA   s 0.00..0.50, t 0.50..1.00   Laminaria digitata fan: 5 fingers, deep splits in the outer half,
                                        tattered tip edges, midrib fan and radiating finger ribs
  BladeB   s 0.50..1.00, t 0.50..1.00   L. hyperborea strap: long, ruffled, 3 shallow tip splits
  BladeC   s 0.00..0.50, t 0.25..0.50   young blade: short, rounded, wavy edge, brighter olive
  Holdfast s 0.50..0.75, t 0.25..0.50   haptera root mass: knobbly dark brown, pale encrustation
  Stipe    s 0.75..1.00, t 0.25..0.50   stipe skin: mottled olive-brown, vertical fibres, epibiont tufts
                                        (periodic across u, so the stipe's wrap seam matches)
  Rock     s 0.00..1.00, t 0.00..0.25   granite with coralline crust, barnacles, silt and a little weed

Maps are written wet-only (kelp never dries): olive-brown translucent fronds (docs/05 3.1 palette kelp #4B4A26),
luma kept 24..236, saturation under the 0.45 ceiling, roughness 0.28..0.60 waxy. Everything outside this cell is
flat neutral (0.35 grey albedo, alpha 0, flat normal).
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(GAME, "tools/blender"))
import common  # noqa: E402
from pbrmaps import downsize, write_png  # noqa: E402

ASSET = "M_Veg_Kelp_Kit"
SET_NAME, SET_SET = "FoliageMarine", "Main"
MASTER, SHIP = 4096, 2048

CELL = (0.0, 0.5, 0.25, 1.0)                     # M_Veg_Kelp cell in atlas UV (atlases.py)
RECTS = {
    "BladeA": (0.00, 0.50, 0.50, 1.00),
    "BladeB": (0.50, 0.50, 1.00, 1.00),
    "BladeC": (0.00, 0.25, 0.50, 0.50),
    "Holdfast": (0.50, 0.25, 0.75, 0.50),
    "Stipe": (0.75, 0.25, 1.00, 0.50),
    "Rock": (0.00, 0.00, 1.00, 0.25),
}


def uv(rect, s, t, m=0.004):
    """Rect-local s across (0 left, 1 right), t up the blade (0 base, 1 tip) -> atlas UV (v up)."""
    s0, t0, s1, t1 = RECTS[rect]
    u0, v0, u1, v1 = CELL
    s = min(1.0 - m, max(m, s))
    t = min(1.0 - m, max(m, t))
    return (u0 + (s0 + s * (s1 - s0)) * (u1 - u0),
            v0 + (t0 + t * (t1 - t0)) * (v1 - v0))


def uv_wrap(rect, s, t):
    """Same, but s wraps 0..1 exactly (a periodic strip: the stipe tube's seam)."""
    s0, t0, s1, t1 = RECTS[rect]
    u0, v0, u1, v1 = CELL
    return (u0 + (s0 + min(1.0, max(0.0, s)) * (s1 - s0)) * (u1 - u0),
            v0 + (t0 + min(1.0, max(0.0, t)) * (t1 - t0)) * (v1 - v0))


# ---------------------------------------------------------------------------------------------------- noise
def sm(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-12), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def pnoise(h, w, cy, cx, seed, octaves=4, gain=0.55):
    """Band-limited smooth noise 0..1, periodic in both axes (FFT). cy / cx: cycles across the tile."""
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
    out /= tot
    return np.clip(0.5 + 0.19 * out, 0.0, 1.0)


def normal_from_height(h, strength):
    """OpenGL tangent-space normal (green = +V) from a height array whose row 0 is the image top (v max)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return np.clip(n * 0.5 + 0.5, 0.0, 1.0)


def specks(h, w, n, seed, rmin, rmax, clump=0.0, ring=0.0):
    """Sparse round blobs 0..1: n stamps of radius rmin..rmax as a share of the tile's shorter side (wrapped, so
    edges are not special). clump: 0..1, how much the stamps gather into patches. ring: dark rim weight (barnacles)."""
    rng = np.random.default_rng(seed)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    out = np.zeros((h, w), np.float32)
    rim = np.zeros((h, w), np.float32)
    pat = pnoise(h, w, 4, 4, seed + 91, 3) if clump else None
    base = float(min(h, w))
    for _ in range(n):
        cy, cx = rng.uniform(0, h), rng.uniform(0, w)
        if pat is not None and pat[int(cy) % h, int(cx) % w] < rng.uniform(0.35, 0.75) * (1 - clump) + 0.05:
            continue
        r = max(1.0, rng.uniform(rmin, rmax) * base * rng.uniform(0.7, 1.3))
        dy = np.abs(ys - cy)
        dy = np.minimum(dy, h - dy)
        dx = np.abs(xs - cx)
        dx = np.minimum(dx, w - dx)
        ecc = rng.uniform(0.5, 1.0)
        d = np.sqrt((dx / r) ** 2 + (dy / (r * ecc)) ** 2)
        out = np.maximum(out, sm(1.0, 0.35, d))
        if ring:
            rim = np.maximum(rim, sm(1.30, 1.05, d) * sm(0.75, 1.02, d))
    return (out, rim) if ring else out


# ---------------------------------------------------------------------------------------------------- blades
OLIVE = np.array([0.402, 0.336, 0.176])       # olive-brown to golden-brown, sat 0.56 in the darkest spots only below
OLIVE_DEEP = np.array([0.230, 0.194, 0.106])
OLIVE_PALE = np.array([0.486, 0.428, 0.262])
GOLD = np.array([0.505, 0.420, 0.196])
TATTER = np.array([0.498, 0.436, 0.296])
BACKLIT = np.array([0.520, 0.472, 0.282])
ENCRUST = np.array([0.640, 0.630, 0.573])
BRYOZOAN = np.array([0.692, 0.690, 0.652])
CORALLINE = np.array([0.596, 0.492, 0.470])
REDWEED = np.array([0.470, 0.300, 0.280])


def blade(w, h, kind, seed, tone):
    """One blade swatch: sRGB colour (h, w, 3), height 0..1, alpha 1 everywhere. The frond's outline is built in
    geometry (kelpkit.py cuts its lobes as thin ribbons), so this swatch is the surface only: a rib up the middle,
    darker seam bands at the two edges (each lobe's rim), a pale nibbled margin, the dark base and pale tip of the
    real frond, mottling, fibres, epiphyte crusts and grazing nicks. Row 0 is the image top = the blade tip, s runs
    across the lobe (its rim at s 0 and 1), v up it."""
    S = ((np.arange(w) + 0.5) / w)[None, :]                               # across, 0.5 = the lobe's rib
    T = (1.0 - (np.arange(h) + 0.5) / h)[:, None]                         # 0 = base, 1 = tip
    ss = np.broadcast_to(S, (h, w))
    tt = np.broadcast_to(T, (h, w))

    rib = np.exp(-((ss - 0.5) / 0.055) ** 2) * (1.0 - 0.55 * sm(0.20, 0.55, tt))
    veins = np.zeros((h, w), np.float32)
    for p in (0.26, 0.74):
        veins = np.maximum(veins, np.exp(-((ss - p) / 0.030) ** 2))
    rim = sm(0.0, 0.10, ss) * sm(1.0, 0.90, ss)                            # 0 at the lobe's rim, 1 inside
    older = {"hyperborea": 1.0, "digitata": 0.75, "young": 0.25}[kind]
    nib = pnoise(h, w, 40, 26, seed + 2, 4)
    rag = sm(0.45, 0.85, nib) * (1.0 - rim) * sm(0.25, 0.75, tt)           # nibbled outer edge
    silk = pnoise(h, w, 26, 26, seed + 1, 4)
    fine = pnoise(h, w, 30, 30, seed + 6, 3)
    fibres = pnoise(h, w, 2, 11, seed + 12, 3)                             # streaks running up the lobe
    shade = pnoise(h, w, 4, 6, seed + 5, 4)
    lit = pnoise(h, w, 3, 5, seed + 13, 3)                                 # broad backlit patches (translucency)

    col = np.array(tone)[None, None, :] * 0.90 * (0.68 + 0.50 * shade[..., None])
    col = col * (0.94 + 0.12 * sm(0.20, 0.55, rim))[..., None]             # the rim band sits slightly darker
    col = col * (1.0 - 0.34 * (1.0 - rim)[..., None])
    col = col * (1.0 - 0.30 * rag[..., None])
    col = col * (0.96 + 0.09 * (fibres - 0.5))[..., None]
    col = col * (1.0 - 0.46 * sm(0.34, 0.02, tt)[..., None])               # dark at the stipe junction
    col = col + (OLIVE_DEEP[None, None, :] - col) * (0.24 * sm(0.45, 0.0, rim)[..., None])
    tip_lift = sm(0.42, 1.0, tt) * 0.22 + sm(0.55, 1.0, rag) * 0.16 + sm(0.86, 1.0, tt) * 0.14
    col = col + (TATTER[None, None, :] - col) * np.clip(tip_lift, 0, 1)[..., None]
    lamp = sm(0.62, 0.92, lit) * sm(0.10, 0.45, tt) * (1.0 - sm(0.55, 0.85, rag))
    col = col + (BACKLIT[None, None, :] - col) * (0.18 * lamp)[..., None]  # sun through the wet blade
    col = col * (0.96 + 0.08 * (fine - 0.5))[..., None]
    col = col + (np.array(tone)[None, None, :] * 1.55 - col) * (0.38 * rib[..., None])
    col = col + (np.array(tone)[None, None, :] * 1.25 - col) * (0.16 * veins[..., None] * sm(0.15, 0.6, tt)[..., None])
    col = col * (1.0 - 0.24 * (np.exp(-((np.abs(ss - 0.5) - 0.024) / 0.006) ** 2) * (1.0 - sm(0.25, 0.45, tt)))[..., None])
    margin = sm(0.09, 0.15, ss) * sm(0.91, 0.85, ss) * sm(0.20, 0.75, tt)
    col = col + (TATTER[None, None, :] - col) * (0.30 * margin * (0.4 + 0.6 * rag))[..., None]
    enc, enc_rim = specks(h, w, 14, seed + 8, 0.008, 0.022, clump=0.6, ring=0.5)
    enc = enc * sm(0.15, 0.50, tt)
    col = col + (ENCRUST[None, None, :] - col) * (0.62 * enc)[..., None]
    col = col * (1.0 - 0.18 * (enc_rim * sm(0.35, 0.85, rim))[..., None])
    bryo = specks(h, w, int(4 + 10 * older), seed + 14, 0.012, 0.034, clump=0.72)
    bryo = bryo * sm(0.28, 0.72, tt) * (0.45 + 0.55 * older)
    col = col + (BRYOZOAN[None, None, :] - col) * (0.72 * bryo)[..., None]  # white bryozoan crusts on old blades
    cor = specks(h, w, 7, seed + 9, 0.005, 0.014, clump=0.7) * sm(0.30, 0.85, tt)
    col = col + (CORALLINE[None, None, :] - col) * (0.40 * cor)[..., None]
    red = specks(h, w, 5, seed + 10, 0.004, 0.009, clump=0.5)
    col = col + (REDWEED[None, None, :] - col) * (0.45 * red)[..., None]
    nick = sm(0.80, 0.92, silk) * sm(0.10, 0.35, tt) * rim
    col = col * (1.0 - 0.40 * nick[..., None])
    silt = sm(0.50, 0.95, pnoise(h, w, 9, 9, seed + 11, 3)) * (0.55 + 0.45 * sm(0.30, 0.0, tt))
    col = col + (ENCRUST[None, None, :] - col) * (0.30 * silt)[..., None]
    dust = sm(0.62, 0.94, pnoise(h, w, 60, 44, seed + 15, 2))
    col = col + (ENCRUST[None, None, :] - col) * (0.16 * dust)[..., None]   # fine silt dusting

    height = 0.30 * rim + 0.52 * rib + 0.22 * veins + 0.14 * (pnoise(h, w, 7, 4, seed + 3, 3) - 0.5)
    height += 0.16 * rag
    height += 0.12 * (pnoise(h, w, 30, 26, seed + 4, 3) - 0.5)
    height += 0.22 * bryo
    height = np.clip(height, 0, 1)
    rgh = 0.34 + 0.05 * (fine - 0.5) + 0.10 * enc + 0.08 * cor + 0.10 * silt + 0.12 * rag + 0.10 * nick
    rgh = rgh + 0.16 * bryo + 0.05 * dust
    alpha = np.ones((h, w), np.float32)
    return np.clip(col, 0, 1).astype(np.float32), height, alpha, np.clip(rgh, 0.28, 0.60)


# ---------------------------------------------------------------------------------------------------- holdfast etc
def holdfast_tex(w, h, seed):
    knots = pnoise(h, w, 7, 5, seed, 4)
    lumps = pnoise(h, w, 20, 14, seed + 1, 3)
    ridges = np.abs(pnoise(h, w, 3, 9, seed + 5, 2) - 0.5) * 2.0        # the haptera's ridges and folds
    height = np.clip(0.42 + 0.42 * (knots - 0.5) + 0.26 * (lumps - 0.5) + 0.18 * ridges, 0, 1)
    shade = 0.55 + 0.85 * (height - height.min()) / (height.max() - height.min() + 1e-6)
    col = OLIVE_DEEP[None, None, :] * (0.44 + 0.62 * shade[..., None])
    col = col + (OLIVE[None, None, :] - col) * (0.35 * pnoise(h, w, 3, 3, seed + 2, 3))[..., None]
    col = col * (1.0 - 0.30 * sm(0.30, 0.0, height)[..., None])          # the creases go nearly black-brown
    enc, enc_rim = specks(h, w, 18, seed + 3, 0.004, 0.011, clump=0.7, ring=0.4)
    col = col + (ENCRUST[None, None, :] - col) * (0.45 * enc)[..., None]
    col = col * (1.0 - 0.20 * enc_rim[..., None])
    cor = specks(h, w, 8, seed + 4, 0.003, 0.009, clump=0.7)
    col = col + (CORALLINE[None, None, :] - col) * (0.35 * cor)[..., None]
    col = np.clip(col, 0, 1)
    rgh = np.clip(0.42 + 0.16 * (1 - height) + 0.12 * enc, 0.30, 0.66)
    return col, height, np.clip(rgh, 0.30, 0.66)


def stipe_tex(w, h, seed):
    """Periodic across u (the tube wrap seam must match); one span up v."""
    fibres = pnoise(h, w, 4, 5, seed, 4)
    streak = pnoise(h, w, 20, 6, seed + 1, 3)
    fleck = pnoise(h, w, 40, 26, seed + 2, 3)
    col = OLIVE[None, None, :] * (0.72 + 0.45 * fibres[..., None]) * (0.90 + 0.16 * streak[..., None])
    col = col * (1.0 - 0.22 * sm(0.58, 0.95, fleck)[..., None])
    vg = np.linspace(0.0, 1.0, h)[:, None, None]                        # more growth at the top of the stipe
    col = col * (0.84 + 0.32 * vg)
    enc, enc_rim = specks(h, w, 22, seed + 3, 0.005, 0.015, clump=0.7, ring=0.35)
    enc = enc * sm(0.30, 0.75, vg[..., 0])
    col = col + (ENCRUST[None, None, :] - col) * (0.58 * enc)[..., None]
    col = col * (1.0 - 0.20 * (enc_rim * sm(0.3, 0.8, vg[..., 0]))[..., None])
    red = specks(h, w, 5, seed + 4, 0.004, 0.008, clump=0.5)
    col = col + (REDWEED[None, None, :] - col) * (0.42 * red)[..., None]
    height = (0.5 + 0.5 * fibres) * 0.6 + 0.25 * streak
    return np.clip(col, 0, 1), np.clip(height, 0, 1), 0.38 + 0.10 * (fleck - 0.5) + 0.08 * enc


def rock_tex(w, h, seed):
    """Granite under water: joint blocks, dark fissures, coralline crust, barnacle rings, silt, a little weed."""
    grain = pnoise(h, w, 55, 38, seed, 4)
    blocks = pnoise(h, w, 5, 4, seed + 1, 3)
    fis = np.abs(pnoise(h, w, 6, 5, seed + 9, 3) - 0.5) * 2.0            # joint lines: thin dark seams
    crev = sm(0.55, 0.95, fis)
    base = np.array([0.262, 0.258, 0.238])
    col = base[None, None, :] * (0.78 + 0.42 * blocks[..., None]) * (0.90 + 0.22 * grain[..., None])
    col = col * (1.0 - 0.48 * crev[..., None])
    col = col + (OLIVE_DEEP[None, None, :] - col) * (0.40 * sm(0.48, 0.88, pnoise(h, w, 7, 6, seed + 3, 3)))[..., None]
    cor = specks(h, w, 26, seed + 4, 0.007, 0.024, clump=0.7)
    col = col + (CORALLINE[None, None, :] - col) * (0.55 * cor)[..., None]
    bar, bar_rim = specks(h, w, 34, seed + 5, 0.006, 0.016, clump=0.5, ring=0.6)
    col = col + (ENCRUST[None, None, :] - col) * (0.72 * bar)[..., None]
    col = col * (1.0 - 0.34 * bar_rim[..., None])
    enc = specks(h, w, 22, seed + 7, 0.005, 0.014, clump=0.7)
    col = col + (ENCRUST[None, None, :] - col) * (0.42 * enc)[..., None]
    weed = sm(0.66, 0.94, pnoise(h, w, 15, 12, seed + 8, 3))
    col = col + (OLIVE[None, None, :] - col) * (0.50 * weed)[..., None]
    height = np.clip(0.40 + 0.20 * grain + 0.40 * bar + 0.30 * blocks + 0.25 * cor - 0.50 * crev + 0.20 * weed, 0, 1)
    rgh = np.clip(0.46 + 0.10 * (grain - 0.5) + 0.12 * bar - 0.06 * weed + 0.10 * crev, 0.30, 0.68)
    return np.clip(col, 0, 1), height, rgh


# ---------------------------------------------------------------------------------------------------- assemble
def _place(dst, rect, arr, size):
    u0, v0, u1, v1 = CELL
    s0, t0, s1, t1 = RECTS[rect]
    x0 = int(round((u0 + s0 * (u1 - u0)) * size))
    x1 = int(round((u0 + s1 * (u1 - u0)) * size))
    y0 = int(round((v0 + t0 * (v1 - v0)) * size))               # v up: the rect's top edge is at v1
    y1 = int(round((v0 + t1 * (v1 - v0)) * size))
    dst[size - y1:size - y0, x0:x1] = arr


def clamp_sat(rgb, cap=0.44):
    """Pull every pixel's saturation down to `cap` (smoothly: only pixels over it move), so the albedo keeps its
    olive-brown look inside the check_textures ceiling (0.45 at the 95th percentile)."""
    mx = rgb.max(-1, keepdims=True)
    mn = rgb.min(-1, keepdims=True)
    mid = (mx + mn) * 0.5
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    f = np.minimum(1.0, cap / np.maximum(sat, 1e-6))
    return mid + (rgb - mid) * f


def sheets(size):
    """(alb RGB, alpha, height, rgh) at `size` for the whole sheet, this kit's cell painted, the rest flat."""
    a = np.zeros((size, size, 3), np.float32)
    al = np.zeros((size, size), np.float32)
    hh = np.zeros((size, size), np.float32)
    rr = np.full((size, size), 0.35, np.float32)
    a[:] = np.array([0.35, 0.35, 0.34])

    def cell_px(rect):
        s0, t0, s1, t1 = RECTS[rect]
        return (int(round((s1 - s0) * (CELL[2] - CELL[0]) * size)), int(round((t1 - t0) * (CELL[3] - CELL[1]) * size)))

    for rect, kind, seed, tone in (("BladeA", "digitata", 11, OLIVE),
                                   ("BladeB", "hyperborea", 23, GOLD),
                                   ("BladeC", "young", 37, OLIVE_PALE)):
        w, h = cell_px(rect)
        col, height, alpha, rgh = blade(w, h, kind, seed, tone)
        _place(a, rect, col, size)
        _place(al, rect, alpha, size)
        _place(hh, rect, height, size)
        _place(rr, rect, rgh, size)
    w, h = cell_px("Holdfast")
    col, height, rgh = holdfast_tex(w, h, 51)
    _place(a, rect="Holdfast", arr=col, size=size)
    _place(al, "Holdfast", np.ones((h, w), np.float32), size)
    _place(hh, "Holdfast", height, size)
    _place(rr, "Holdfast", rgh, size)
    w, h = cell_px("Stipe")
    col, height, rgh = stipe_tex(w, h, 63)
    _place(a, "Stipe", col, size)
    _place(al, "Stipe", np.ones((h, w), np.float32), size)
    _place(hh, "Stipe", height, size)
    _place(rr, "Stipe", rgh, size)
    a *= 0.84                                            # wet blades sit darker than dry ones (docs/05 3.3)
    a[:] = clamp_sat(a)
    w, h = cell_px("Rock")
    col, height, rgh = rock_tex(w, h, 77)
    _place(a, "Rock", col, size)
    _place(al, "Rock", np.ones((h, w), np.float32), size)
    _place(hh, "Rock", height, size)
    _place(rr, "Rock", rgh, size)
    return a, al, hh, rr


def maps(size=MASTER):
    """(alb RGBA, nor RGB, rgh L, met L) at `size`."""
    alb, alpha, height, rgh = sheets(size)
    nor = normal_from_height(height, 5.0 / (size / 2048.0))
    rgba = np.concatenate([alb, alpha[..., None]], -1)
    return rgba, nor.astype(np.float32), rgh, np.zeros((size, size), np.float32)


def read_features(path, size):
    """Decode an 8-bit PNG written by pbrmaps.write_png (Sub filter) to float RGBA at `size`; None on mismatch."""
    import struct
    import zlib
    try:
        data = open(path, "rb").read()
    except OSError:
        return None
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    pos, idat, w, h, ct = 8, b"", 0, 0, 0
    while pos + 8 <= len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if tag == b"IHDR":
            w, h, _bd, ct, _c, _f, inter = struct.unpack(">IIBBBBB", chunk)
            if inter:
                return None
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    if (w, h) != (size, size) or ct not in (0, 2, 6):
        return None
    ch = {0: 1, 2: 3, 6: 4}[ct]
    raw = zlib.decompress(idat)
    stride = w * ch
    out = np.zeros((h, stride), np.uint8)
    prev = np.zeros(stride, np.uint8)
    for y in range(h):
        f = raw[y * (stride + 1)]
        row = np.frombuffer(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)], np.uint8).copy()
        if f == 1:
            row = np.cumsum(row.reshape(w, ch), axis=0, dtype=np.uint8).reshape(-1)
        elif f == 2:
            row = (row.astype(np.uint16) + prev).astype(np.uint8)
        elif f != 0:
            return None
        out[y] = row
        prev = row
    arr = out.reshape(h, w, ch).astype(np.float32) / 255.0
    if ch == 1:
        arr = np.repeat(arr, 3, axis=2)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1), np.float32)], axis=2)
    return arr


def keep_other_cells(alb, nor, rgh, size):
    """Copy every pixel outside this kit's cell from a map that already has the wrack and eelgrass cells painted,
    so a merge leaves them pixel-identical. Returns True when a map was found."""
    x0 = int(round(CELL[0] * size))
    y0 = int(round((1.0 - CELL[3]) * size))
    x1 = int(round(CELL[2] * size))
    y1 = int(round((1.0 - CELL[1]) * size))
    keepm = np.ones((size, size), bool)
    keepm[y0:y1, x0:x1] = False
    if size > SHIP:
        folders = [os.path.join(GAME, "build/prod/M_Veg_Eelgrass_Kit/masters"),
                   os.path.join(GAME, "build/prod/M_Veg_Wrack_Kit/masters")]
    else:
        folders = [os.path.join(GAME, "build/prod/M_Veg_Eelgrass_Kit/textures/M_Veg_Eelgrass_Kit"),
                   os.path.join(GAME, "build/prod/M_Veg_Wrack_Kit/textures/M_Veg_Wrack_Kit"),
                   os.path.join(GAME, "assets/textures/M_Veg_FoliageMarine")]
    for folder in folders:
        alb_p = common.map_file(folder, "T_%s_%s_ALB" % (SET_NAME, SET_SET))
        if not alb_p:
            continue
        old = read_features(alb_p, size)
        if old is None or not (old[..., 3][keepm] > 0).any():
            continue
        alb[keepm] = old[keepm]
        nor_p = common.map_file(folder, "T_%s_%s_NOR" % (SET_NAME, SET_SET))
        if nor_p:
            n = read_features(nor_p, size)
            if n is not None:
                nor[keepm] = n[..., :3][keepm]
        rgh_p = common.map_file(folder, "T_%s_%s_RGH" % (SET_NAME, SET_SET))
        if rgh_p:
            r = read_features(rgh_p, size)
            if r is not None:
                rgh[keepm] = r[..., 0][keepm]
        print("[%s] kept the other atlas cells from %s" % (ASSET, os.path.relpath(folder, GAME)))
        return True
    return False


def write_all(asset=ASSET, out_dir=None, masters_dir=None, size=SHIP):
    directory = out_dir or common.textures_dir(asset)
    masters = masters_dir or os.path.join(common.out_root(), "masters")
    os.makedirs(directory, exist_ok=True)
    os.makedirs(masters, exist_ok=True)
    big = list(maps(MASTER))
    small = [downsize(x, size) if x.shape[0] > size else x for x in big]
    out = []
    for target, arrs in ((masters, big), (directory, small)):
        keep_other_cells(arrs[0], arrs[1], arrs[2], arrs[0].shape[0])
        for tag, mp in zip(("ALB", "NOR", "RGH", "MET"), arrs):
            stem = "T_%s_%s_%s.png" % (SET_NAME, SET_SET, tag)
            out.append(write_png(os.path.join(target, stem), mp))
    print("[%s] wrote 4 maps at %d (%d masters in %s)" % (ASSET, size, 4,
          os.path.relpath(masters, common.REPO_DIR)))
    return out


def preview(out_png, size=1024):
    """A readable preview of the kit's cell only (for looking at the silhouette): ALB over a chequer."""
    alb, alpha, height, rgh = sheets(size)
    cell = alb.copy()
    cell[..., :] = alb
    return write_png(out_png, cell)


if __name__ == "__main__":
    d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/kelp_preview"
    os.makedirs(d, exist_ok=True)
    write_all(out_dir=os.path.join(d, "textures", ASSET), masters_dir=os.path.join(d, "masters"))
    print("wrote", d)
