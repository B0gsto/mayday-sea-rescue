"""E1b rescue kit atlas maps (system python3 + numpy + Pillow, no Blender).

    python3 art/source/kit/E1/maketex.py

Four sets (atlas.py): Cloth, Soft, Foil, Hard, 2048 masters in masters/, 1024 ship in assets/textures/M_Kit_Atlas/,
each with _Wet ALB, RGH and NOR (droplet beads and a water film: darker, glossier, beaded, not just darker).
Everything here is procedural numpy authored at real-world scale (px per mm known per region): 2x2 basket-weave
ballistic nylon, twill webbing, lock-stitch seams, coil zips, sewn bead retroreflective tape with abrasion and
cracks, vinyl foam with a pebble skin, braided rope (tools/blender/rope.py braid via the HP2a recipe), crumpled
metallised PET foil (multi-octave Voronoi facets with sharp creases), the moulded PE lifebuoy shell (orange peel,
parting lines, worn retro bands, salt crust, UV chalking), plastics, knurl, lenses and printed labels with generic
invented text (no brands). The Poly Haven CC0 scans of E1 (stretch_poplin etc.) are no longer sampled: their weave
was below the ship texel size and read as smeared noise.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import atlas  # noqa: E402
sys.path.insert(1, os.path.join(ROOT, "tools/blender"))
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("hp2a_maketex", os.path.join(ROOT, "art/source/harbour/M_Hbr_PropAtlas/maketex.py"))
hm = importlib.util.module_from_spec(_spec)
sys.modules["hp2a_maketex"] = hm
_spec.loader.exec_module(hm)
from hp2a_maketex import blur, fbm, flat, font, lerp, lum, nor_from_h, noise, ss, tint, r_plastic, r_rope  # noqa: E402

MASTERS = os.path.join(HERE, "masters")
OUT = os.path.join(ROOT, "assets/textures", atlas.ATLAS_ASSET)
K = atlas.STRIP_K
STRIP_W = {"Webbing": 25.0, "RetroSewn": 50.0, "ZipBlack": 14.0, "SeamSolas": 16.0, "SeamHiVis": 16.0, "SeamNavy": 16.0,
           "FoamSeam": 12.0, "WebbingS": 12.0}
SOLAS = (232, 86, 36)
HIVIS = (206, 232, 30)
NAVY = (34, 42, 66)


# ---------------------------------------------------------------- small helpers
def rsz(a, w, h):
    if a.ndim == 3:
        return np.stack([rsz(a[..., i], w, h) for i in range(a.shape[2])], -1)
    return np.asarray(Image.fromarray(a.astype(np.float32), "F").resize((w, h), Image.LANCZOS), np.float32)


def nz(w, h, cycles_w, seed):
    """Noise on a w x h canvas, periodic along w (built square at w, top h rows)."""
    a = noise(w, cycles_w, seed)
    return a[:h] if h <= w else rsz(a, w, h)


def fb(w, h, cycles_w, seed, oct_=4):
    out, amp, tot = np.zeros((h, w), np.float32), 1.0, 0.0
    for o in range(oct_):
        out += amp * nz(w, h, cycles_w * 2 ** o, seed + 17 * o)
        tot += amp
        amp *= 0.5
    return out / tot


def mat(alb, nor, rgh, met=None):
    return {"ALB": alb, "NOR": nor, "RGH": np.clip(rgh, 0.03, 1), "MET": np.zeros(alb.shape[:2], np.float32) if met is None else met}


def nvec(h, strength):
    return nor_from_h(h, strength)


def ncombine(a, b, k=1.0):
    """Detail normal b on base a (add slopes, renormalise)."""
    v = np.stack([a[..., 0] / np.maximum(a[..., 2], 0.2) + k * b[..., 0] / np.maximum(b[..., 2], 0.2),
                  a[..., 1] / np.maximum(a[..., 2], 0.2) + k * b[..., 1] / np.maximum(b[..., 2], 0.2), np.ones(a.shape[:2])], -1)
    return (v / np.linalg.norm(v, axis=-1, keepdims=True)).astype(np.float32)


def tri(x):
    return np.abs((x % 1.0) - 0.5) * 2.0


def grids(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return x, y


def stitch_line(w, h, yc, px_mm, stitch_mm, gap_mm, along_mm, width_mm=0.7):
    """Lock-stitch dashes along U at row yc: returns (height, mask). along_mm = canvas length (periodic)."""
    x, y = grids(w, h)
    per = stitch_mm + gap_mm
    nper = max(1, int(round(along_mm / per)))
    s = (x / w * nper) % 1.0
    on = ss(0.0, 0.08, s) * ss(stitch_mm / per, stitch_mm / per - 0.08, s)
    prof = np.clip(1 - (np.abs(y - yc) / (width_mm * px_mm * 0.5)) ** 2, 0, 1)
    hole = np.exp(-(((s - stitch_mm / per - gap_mm / per * 0.5) * along_mm / nper) ** 2 + ((y - yc) / px_mm) ** 2) / 0.12)
    return on * np.sqrt(prof), hole * (1 - on)


# ---------------------------------------------------------------- weave
def weave_h(w, h, pu, pv):
    """2x2 basket weave height (0..1): pu / pv basket periods (4 threads each) across w / h. Supersampled 2x."""
    W2, H2 = w * 2, h * 2
    x, y = grids(W2, H2)
    s = x / W2 * pu * 4
    t = y / H2 * pv * 4
    top = ((np.floor(s / 2) + np.floor(t / 2)) % 2) == 0
    across_s = np.sin(np.pi * (s % 1.0)) ** 0.6
    across_t = np.sin(np.pi * (t % 1.0)) ** 0.6
    edge_t = 1 - 0.35 * tri(t / 2 + 0.5) ** 6
    edge_s = 1 - 0.35 * tri(s / 2 + 0.5) ** 6
    hh = np.where(top, 0.55 + 0.45 * across_s * edge_t, 0.55 + 0.45 * across_t * edge_s)
    return rsz(hh, w, h), rsz(top.astype(np.float32), w, h)


def fabric(n, seed, rgb, rough=0.5, period_mm=4.4, grime=0.25, wrinkle=0.6):
    tile_mm = atlas.T * 1000
    P = max(1, int(round(tile_mm / period_mm)))
    h, top = weave_h(n, n, P, P)
    lo = fbm(n, seed, 3)
    alb = tint(rgb, 0.86 + 0.16 * h + 0.03 * (top - 0.5) + 0.05 * (lo - 0.5))
    g = ss(0.55, 0.85, fbm(n, seed + 2, 3)) * grime                    # grime in big soft blooms
    alb = lerp(alb, alb * 0.66 + 10, g * (0.6 + 0.4 * (1 - h)))
    salt = ss(0.72, 0.9, fbm(n, seed + 3, 4)) * 0.18 * (1 - h)         # salt dried into the weave valleys
    alb = lerp(alb, np.minimum(alb * 1.1 + 40, 232), salt)
    wr = fbm(n, seed + 5, 2, 3)                                        # soft wrinkles (cm scale)
    nor = ncombine(nvec(wr, 18.0 * wrinkle), nvec(h, 2.2))
    rgh = rough + 0.14 * (1 - h) + 0.1 * g - 0.04 * (top - 0.5)
    return mat(alb, nor, rgh)


def fabric_canvas(w, h, px_mm, rgb, seed, period_mm=4.4):
    """Weave on a strip canvas (periodic along w)."""
    pu = max(1, int(round(w / px_mm / period_mm)))
    hh, top = weave_h(w, h, pu, h / px_mm / period_mm)
    alb = tint(rgb, 0.86 + 0.16 * hh + 0.03 * (top - 0.5))
    return alb, hh


def to_strip(m, n):
    return {k: (rsz(v, n, n) if k != "NOR" else _renorm(rsz(v, n, n))) for k, v in m.items()}


def _renorm(v):
    return (v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)).astype(np.float32)


# ---------------------------------------------------------------- strips (canvas 4n along x 1n across)
def seam_strip(n, seed, rgb, thread, W):
    w, h = int(n * K), n
    px = h / W
    alb, wv = fabric_canvas(w, h, px, rgb, seed)
    x, y = grids(w, h)
    yy = y / h
    fold = np.exp(-((yy - 0.5) / 0.26) ** 2)                           # seam allowance folded under: raised ridge
    hs, hole = stitch_line(w, h, h * 0.5, px, 3.2, 0.9, w / px, 0.8)
    hgt = 1.6 * fold + 0.35 * wv + 0.9 * hs
    alb = alb * (0.92 + 0.08 * fold)[..., None]
    alb = lerp(alb, tint(thread, 0.9 + 0.2 * hs), hs)
    alb = lerp(alb, alb * 0.55, hole * 0.6)
    g = ss(0.5, 0.85, fb(w, h, 6, seed + 1)) * 0.3
    alb = lerp(alb, alb * 0.7 + 8, g)
    rgh = 0.5 + 0.14 * (1 - wv) + 0.12 * hs + 0.1 * g
    return to_strip(mat(alb, nvec(hgt, 6.0), rgh), n)


def webbing_strip(n, seed, W):
    w, h = int(n * K), n
    px = h / W
    x, y = grids(w, h)
    pu = int(round(w / px / 1.1))
    tw = tri(x / w * pu + y / px / 1.1 * 0.5)                          # 2/2 twill ribs on the diagonal
    weft = tri(y / px / 0.6)
    yy = y / h
    edge = ss(0.0, 0.08, yy) * ss(1.0, 0.92, yy)                        # rounded selvedges
    fuzz = nz(w, h, w / px / 0.5, seed)
    hgt = (0.6 * tw + 0.2 * weft + 0.15 * fuzz) * edge + 0.6 * edge
    alb = tint((40, 40, 43), 0.82 + 0.25 * tw + 0.08 * fuzz) * (0.75 + 0.25 * edge)[..., None]
    g = ss(0.5, 0.85, fb(w, h, 8, seed + 1)) * 0.35                    # salt and dust caught in the twill
    alb = lerp(alb, alb * 1.3 + 30, g * (1 - tw) * 0.6)
    rgh = 0.62 + 0.16 * (1 - tw) + 0.1 * g
    return to_strip(mat(alb, nvec(hgt, 5.0), rgh), n)


def retro_strip(n, seed, W, carrier=(150, 150, 150), thread=(120, 122, 124), worn=0.5):
    """Sewn silver bead-type retroreflective tape: glitter, micro-grid, abrasion to the grey carrier, cracks, stitched
    edges 3 mm in. MET 0.45 (dielectric for the checks, reads silver under the HDRI)."""
    w, h = int(n * K), n
    px = h / W
    x, y = grids(w, h)
    yy = y / h
    glitter = nz(w, h, w / px / 0.35, seed)
    grid_ = 0.5 * tri(x / px / 1.6) + 0.5 * tri(y / px / 1.6)
    wear = ss(0.58, 0.72, fb(w, h, 5, seed + 1) + 0.25 * ss(0.12, 0.0, np.minimum(yy, 1 - yy))) * worn
    cr_ = nz(w, h, 9, seed + 2)
    crack = ss(0.04, 0.0, np.abs(np.sin((x / w * 9 + 0.15 * cr_) * np.pi * 2))) * ss(0.4, 0.7, fb(w, h, 3, seed + 3))
    alb = tint((198, 200, 203), 0.92 + 0.14 * glitter + 0.04 * grid_)
    alb = lerp(alb, tint(carrier, 0.9 + 0.2 * glitter), wear)
    alb = lerp(alb, alb * 0.5, crack * 0.8)
    dirt = ss(0.5, 0.85, fb(w, h, 7, seed + 4)) * 0.35
    alb = lerp(alb, alb * 0.62 + 12, dirt)
    st = np.zeros((h, w), np.float32)
    holes = np.zeros((h, w), np.float32)
    for yc in (h * 3.0 / W, h * (1 - 3.0 / W)):
        s_, ho = stitch_line(w, h, yc, px, 3.5, 1.0, w / px, 0.8)
        st, holes = np.maximum(st, s_), np.maximum(holes, ho)
    alb = lerp(alb, tint(thread, 0.9 + 0.2 * st), st)
    alb = lerp(alb, alb * 0.6, holes * 0.5)
    edge = ss(0.0, 0.03, yy) * ss(1.0, 0.97, yy)
    hgt = 0.15 * glitter + 0.2 * grid_ - 0.5 * crack + 0.9 * st + 0.8 * edge - 0.2 * wear
    rgh = 0.3 + 0.06 * glitter + 0.38 * wear + 0.25 * crack + 0.3 * st + 0.15 * dirt
    met = 0.45 * (1 - wear) * (1 - st) * (1 - crack)
    return to_strip(mat(alb, nvec(hgt, 4.0), rgh, met), n)


def zip_strip(n, seed, W):
    w, h = int(n * K), n
    px = h / W
    alb, wv = fabric_canvas(w, h, px, (34, 34, 37), seed, period_mm=1.6)
    x, y = grids(w, h)
    yy = y / h
    nt = int(round(w / px / 1.7))
    teeth = (0.5 + 0.5 * np.cos(2 * np.pi * x / w * nt)) ** 0.7
    band = ss(0.20, 0.15, np.abs(yy - 0.5))
    interlock = 0.5 + 0.5 * np.cos(2 * np.pi * (x / w * nt + 0.5 * (yy > 0.5)))
    hgt = band * (0.8 + 0.6 * teeth * interlock) + (1 - band) * 0.3 * wv
    st = np.zeros((h, w), np.float32)
    for yc in (h * 0.12, h * 0.88):
        st = np.maximum(st, stitch_line(w, h, yc, px, 2.5, 0.8, w / px, 0.5)[0])
    hgt = hgt + 0.4 * st
    alb = lerp(alb, tint((28, 28, 30), 0.9 + 0.3 * teeth), band)
    alb = lerp(alb, tint((58, 58, 60), np.ones_like(st)), st)
    rgh = np.where(band > 0.5, 0.32 + 0.1 * (1 - teeth), 0.66 + 0.1 * (1 - wv))
    return to_strip(mat(alb, nvec(hgt, 5.0), rgh), n)


def foam_seam_strip(n, seed, W):
    w, h = int(n * K), n
    px = h / W
    x, y = grids(w, h)
    yy = y / h
    wob = 0.05 * (fb(w, h, 10, seed) - 0.5)
    bead = np.exp(-((yy - 0.5 - wob) / 0.16) ** 2)
    flash = np.exp(-((yy - 0.5 - wob) / 0.32) ** 2) * (0.6 + 0.4 * nz(w, h, w / px / 2, seed + 1))
    groove = np.exp(-((np.abs(yy - 0.5 - wob) - 0.3) / 0.05) ** 2)
    pebble = nz(w, h, w / px / 0.9, seed + 2)
    hgt = 1.2 * bead + 0.3 * flash - 0.6 * groove + 0.12 * pebble
    alb = tint(SOLAS, 0.95 + 0.05 * pebble - 0.12 * groove + 0.04 * bead)
    g = ss(0.5, 0.9, fb(w, h, 6, seed + 3)) * 0.35
    alb = lerp(alb, alb * 0.6 + 10, np.maximum(g, groove * 0.5))
    rgh = 0.42 + 0.08 * pebble + 0.1 * groove - 0.06 * bead
    return to_strip(mat(alb, nvec(hgt, 5.0), rgh), n)


# ---------------------------------------------------------------- tiles
def cells(n, k, seed, jitter=0.9):
    """Periodic jittered-grid Voronoi on an n x n tile with k x k cells: (cell id, F1, F2) in cell units."""
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0.5 - jitter / 2, 0.5 + jitter / 2, (k, k, 2))
    x, y = grids(n, n)
    gx, gy = x / n * k, y / n * k
    ix, iy = np.floor(gx).astype(int), np.floor(gy).astype(int)
    best = np.full((n, n), 9.0, np.float32)
    second = np.full((n, n), 9.0, np.float32)
    bid = np.zeros((n, n), np.int64)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cy = (ix + dx) % k, (iy + dy) % k
            px_ = ix + dx + pts[cy, cx, 0]
            py_ = iy + dy + pts[cy, cx, 1]
            d = np.hypot(gx - px_, gy - py_)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            bid = np.where(closer, cy * k + cx, bid)
            best = np.where(closer, d, best)
    return bid, best, second


def foil(n, seed, rgb):
    """Crumpled metallised PET: three octaves of flat facets (random tilts) meeting in sharp creases."""
    rng = np.random.default_rng(seed)
    tile_mm = atlas.TF * 1000
    sx = np.zeros((n, n), np.float32)
    sy = np.zeros((n, n), np.float32)
    crease = np.zeros((n, n), np.float32)
    shade = np.zeros((n, n), np.float32)
    for size_mm, amp, w_ in ((40.0, 0.08, 0.7), (15.0, 0.13, 1.0), (6.0, 0.13, 0.9), (2.4, 0.08, 0.6)):
        k = max(2, int(round(tile_mm / size_mm)))
        bid, f1, f2 = cells(n, k, seed + int(size_mm * 7))
        tx = rng.normal(0, amp, k * k).astype(np.float32)
        ty = rng.normal(0, amp, k * k).astype(np.float32)
        sx += tx[bid]
        sy += ty[bid]
        shade += rng.normal(0, 0.004, k * k).astype(np.float32)[bid] * w_
        crease = np.maximum(crease, ss(0.05, 0.0, f2 - f1) * w_)
    v = np.stack([-sx, -sy, np.ones_like(sx)], -1)
    nor = _renorm(blur_n(v, 1))
    alb = tint(rgb, 1.0 + shade - 0.05 * crease)
    rgh = 0.06 + 0.06 * crease + 0.02 * ss(0.6, 0.9, fbm(n, seed + 3, 4))
    return mat(alb, nor, rgh, np.ones((n, n), np.float32))


def blur_n(v, k):
    """1-px box blur so the facet edges anti-alias (keeps creases sharp at ship size)."""
    out = v.copy()
    for ax in (0, 1):
        out = (np.roll(out, 1, ax) + out * 2 + np.roll(out, -1, ax)) / 4
    return out


def foam(n, seed, rgb):
    px = n / (atlas.T * 1000)
    bid, f1, f2 = cells(n, int(round(atlas.T * 1000 / 1.1)), seed)
    pebble = 1 - np.clip(f1 * 1.4, 0, 1)
    dent = ss(0.6, 0.85, fbm(n, seed + 1, 2))
    wr = fbm(n, seed + 2, 3, 3)
    hgt = 0.25 * pebble - 1.5 * dent + 2.0 * wr
    alb = tint(rgb, 0.96 + 0.05 * pebble - 0.08 * dent)
    gr = ss(0.55, 0.85, fbm(n, seed + 3, 4)) * 0.3
    alb = lerp(alb, alb * 0.64 + 12, gr)
    sc = ss(0.86, 0.95, fbm(n, seed + 4, 6)) * 0.45                  # black rub marks off the hull
    alb = lerp(alb, tint((66, 54, 48), np.ones((n, n), np.float32)), sc)
    return mat(alb, nvec(hgt, 3.0), 0.4 + 0.1 * pebble + 0.15 * gr + 0.15 * sc + 0.08 * dent)


def knurl(n, seed):
    P = int(round(atlas.scale("Knurl") * 1000 / 1.0))
    x, y = grids(n, n)
    a, b = tri((x + y) / n * P), tri((x - y) / n * P)
    hgt = np.minimum(a, b)
    wear = ss(0.6, 0.95, hgt) * 0.25
    alb = tint((40, 40, 42), 0.9 + 0.2 * hgt) + wear[..., None] * 40
    return mat(alb, nvec(hgt, 10.0), 0.5 - 0.15 * wear)


def lens(n, seed, rgb, rough):
    x, y = grids(n, n)
    h = 0.5 + 0.5 * np.cos(2 * np.pi * y / n * 20)
    alb = tint(rgb, 0.95 + 0.05 * h)
    return mat(alb, nvec(h, 2.0), rough + 0.08 * fbm(n, seed, 6))


def composition(n, seed):
    g = noise(n, n / 4, seed)
    alb = tint((196, 48, 44), 0.85 + 0.25 * g)
    return mat(alb, nvec(g * 0.6, 3.0), 0.82 + 0.1 * g)


def chrome(n, seed):
    m = hm.m_stainless(n, seed)
    return dict(m, ALB=np.clip(m["ALB"] * 1.05, 186, 250), RGH=np.clip(m["RGH"] * 0.5, 0.06, 1), MET=np.ones((n, n), np.float32))


def painted_cyl(n, seed):
    m = r_plastic(n, seed, (226, 226, 220), 0.38, scuff=0.15, grain=0.2)
    chip = ss(0.9, 0.96, noise(n, 30, seed + 7))
    m["ALB"] = lerp(m["ALB"], tint((150, 152, 155), np.ones((n, n), np.float32)), chip * 0.8)
    m["RGH"] = np.clip(m["RGH"] + chip * 0.1, 0, 1)
    return m


def rubber(n, seed):
    v = fbm(n, seed, 6)
    g = noise(n, n / 3, seed + 5)
    alb = tint((38, 38, 39), 0.92 + 0.12 * v)
    dust = ss(0.65, 0.9, fbm(n, seed + 1, 5)) * 0.35
    alb = lerp(alb, tint((120, 116, 108), np.ones((n, n), np.float32)), dust * 0.3)
    return mat(alb, nvec(0.3 * g + v, 2.0), 0.78 + 0.08 * g + 0.1 * dust)


def clear_pvc(n, seed, rgb, rough):
    v = fbm(n, seed, 6)
    alb = tint(rgb, 0.95 + 0.08 * v)
    return mat(alb, nvec(v * 0.3, 2.0), rough + 0.1 * ss(0.6, 0.9, v))


def clip_white(n, seed):
    m = r_plastic(n, seed, (226, 224, 216), 0.42, scuff=0.2, grain=0.5)
    salt = ss(0.6, 0.85, fbm(n, seed + 9, 4)) * 0.4
    m["ALB"] = lerp(m["ALB"], m["ALB"] * 0.8 + 10, salt)
    return m


# ---------------------------------------------------------------- fits
def _canvas_mat(im, seed, rough, hgt=None, strength=2.0):
    a = np.asarray(im, np.float32)
    h, w = a.shape[:2]
    g = rsz(fbm(max(w, h), seed + 1, 4), w, h)
    sc = rsz(ss(0.88, 0.96, noise(max(w, h), 50, seed)), w, h)
    a = lerp(a, a * 0.82 + 22, sc * 0.45)
    a = lerp(a, a * 0.8 + 8, ss(0.6, 0.9, g) * 0.3)
    hh = (0.2 * g - 0.4 * sc) if hgt is None else hgt
    return mat(a, nvec(hh, strength), rough + 0.15 * sc)


def patch(w, h, seed, bg, draw, px_mm):
    im = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(im)
    draw(d, w, h)
    a = np.asarray(im, np.float32)
    P = max(1, int(round(w / px_mm / 4.4)))
    wv, _ = weave_h(w, h, P, h / px_mm / 4.4)
    a = a * (0.9 + 0.14 * wv[..., None])
    # stitched border 4 mm in
    x, y = grids(w, h)
    m = 4 * px_mm
    ring = np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y))
    perim = ((x + y) / px_mm / 4.1) % 1.0
    st = (np.abs(ring - m) < 0.45 * px_mm) * (perim < 0.78)
    a = lerp(a, tint((236, 236, 230), np.ones((h, w), np.float32)), st.astype(np.float32))
    edge = ss(0, 2.5 * px_mm, ring)
    hgt = 0.35 * wv + 0.8 * st + 1.0 * edge
    g = rsz(fbm(max(w, h), seed + 1, 4), w, h)
    a = lerp(a, a * 0.74 + 10, ss(0.6, 0.9, g) * 0.3)
    return mat(a, nvec(hgt, 3.0), 0.6 + 0.12 * (1 - wv) - 0.1 * st)


def cross_patch(w, h, seed, px_mm):
    def draw(d, W, H):
        s = min(W, H)
        t = s * 0.2
        cx, cy = W / 2, H / 2
        d.rectangle([cx - t / 2, cy - s * 0.32, cx + t / 2, cy + s * 0.32], fill=(238, 238, 232))
        d.rectangle([cx - s * 0.32, cy - t / 2, cx + s * 0.32, cy + t / 2], fill=(238, 238, 232))
    return patch(w, h, seed, (0, 118, 62), draw, px_mm)


def oxy_patch(w, h, seed, px_mm):
    def draw(d, W, H):
        b = int(H * 0.09)
        d.rectangle([b, b, W - 1 - b, H - 1 - b], outline=(0, 128, 70), width=max(4, int(H * 0.05)))
        size = int(H * 0.5)
        while size > 8:                                  # fit OXYGEN inside the border with margins (no clipping)
            f = font(size)
            l, t, r, bt = d.textbbox((0, 0), "OXYGEN", font=f)
            if r - l <= W * 0.74 and bt - t <= H * 0.48:
                break
            size -= 2
        d.text(((W - (r - l)) / 2 - l, (H - (bt - t)) / 2 - t), "OXYGEN", font=f, fill=(238, 238, 234))
    return patch(w, h, seed, NAVY, draw, px_mm)


def ring_fit(w, h, seed):
    """Lifebuoy shell. U round the ring (1.88 m at the tube centre), V round the section from the outer equator
    (V 0) over the top (0.25), inner equator (0.5) and bottom (0.75)."""
    U_mm = 2 * math.pi * 300.0
    px = w / U_mm
    x, y = grids(w, h)
    u, v = x / w, 1 - (y + 0.5) / h
    top = np.cos(2 * np.pi * (v - 0.25)) * 0.5 + 0.5                   # 1 on the sunny top face
    bottom = np.cos(2 * np.pi * (v - 0.75)) * 0.5 + 0.5
    pe = 1 - np.clip(cells(h, int(round(h / px / 1.6)), seed)[1] * 1.3, 0, 1)
    pe = np.tile(pe, (1, w // h + 1))[:, :w]
    part = np.exp(-(np.minimum(np.abs(v - 0.0), np.abs(v - 1.0)) * h / (0.8 * px)) ** 2) + np.exp(-(np.abs(v - 0.5) * h / (0.8 * px)) ** 2)
    base = tint(SOLAS, 0.97 + 0.04 * pe)
    chalk = top * ss(0.4, 0.8, fb(w, h, 12, seed + 1)) * 0.35            # UV chalking on the top
    base = lerp(base, np.minimum(base * 1.05 + 38, 236), chalk)
    # 4 retro bands, 50 mm, wrapped round the section, worn, edges lifting
    band = np.zeros((h, w), np.float32)
    bw = 50.0 / U_mm
    for c in (0.125, 0.375, 0.625, 0.875):
        du = np.abs(((u - c + 0.5) % 1.0) - 0.5)
        band = np.maximum(band, ss(bw / 2 + 0.6 / U_mm * 3, bw / 2, du))
    glitter = nz(w, h, w / px / 0.35, seed + 2)
    wear = ss(0.55, 0.72, fb(w, h, 40, seed + 3) + 0.35 * ss(0.25, 0.9, band) * 0 + 0.25 * np.maximum(bottom - 0.5, 0) + 0.25 * part)
    crack = ss(0.05, 0.0, np.abs(np.sin((v * 5 + 0.1 * nz(w, h, 30, seed + 4)) * np.pi * 2))) * ss(0.45, 0.7, fb(w, h, 20, seed + 5))
    retro = tint((200, 202, 205), 0.92 + 0.14 * glitter)
    retro = lerp(retro, tint((150, 150, 148), 0.95 + 0.1 * glitter), wear * 0.85)
    retro = lerp(retro, retro * 0.5, crack * 0.7)
    alb = lerp(base, retro, band)
    # grime, salt crust (bottom and in the parting lines, round the clips), black rub scuffs on the outer equator
    grime = ss(0.5, 0.85, fb(w, h, 16, seed + 6)) * (0.25 + 0.35 * bottom)
    alb = lerp(alb, alb * 0.6 + 10, grime)
    clips = np.zeros((h, w), np.float32)
    for c in (0.0, 0.25, 0.5, 0.75):
        du = np.abs(((u - c + 0.5) % 1.0) - 0.5) * U_mm
        clips = np.maximum(clips, np.exp(-(du / 60.0) ** 2))
    salt_f = fb(w, h, 60, seed + 7)
    salt = ss(0.55, 0.75, salt_f + 0.25 * bottom + 0.3 * clips * np.exp(-(np.minimum(v, 1 - v) / 0.12) ** 2) + 0.3 * part) * 0.7
    tide = ss(0.02, 0.0, np.abs(v - 0.62 - 0.02 * nz(w, h, 25, seed + 8))) * 0.6
    salt = np.maximum(salt, tide)
    salt = salt * (0.55 + 0.45 * pe) * ss(0.3, 0.7, fb(w, h, 90, seed + 11))
    alb = lerp(alb, tint((232, 226, 212), 0.9 + 0.1 * pe), salt * 0.5)
    scuff = ss(0.8, 0.92, fb(w, h, 30, seed + 9)) * np.exp(-(np.minimum(v, 1 - v) / 0.09) ** 2) * 0.7
    alb = lerp(alb, tint((58, 52, 48), np.ones((h, w), np.float32)), scuff * (1 - band * 0.5))
    hgt = 0.18 * pe * (1 - band) + 0.8 * part + 0.6 * band + 0.25 * salt - 0.4 * crack * band
    rgh = (0.44 + 0.08 * pe + 0.2 * chalk) * (1 - band) + band * (0.3 + 0.35 * wear + 0.2 * crack) + 0.3 * salt + 0.1 * grime
    met = band * 0.45 * (1 - wear) * (1 - salt)
    return mat(alb, nvec(hgt, 3.0), rgh, met)


def _label(w, h, seed, bg, draw, rough=0.4, rotate=False, phys=None):
    """Printed label drawn on a physically isotropic canvas (phys = (U mm, V mm)), then fitted to the region.
    rotate: drawn with the length horizontal, then turned so it runs along V (text along the tube)."""
    k = 2.0 * max(w, h) / max(phys) if phys else 1.0
    cw, ch = (int(phys[0] * k), int(phys[1] * k)) if phys else (w, h)
    if rotate:
        im = Image.new("RGB", (ch, cw), bg)
    else:
        im = Image.new("RGB", (cw, ch), bg)
    draw(ImageDraw.Draw(im), im.size)
    if rotate:
        im = im.rotate(90, expand=True)
    return _canvas_mat(im.resize((w, h), Image.LANCZOS), seed, rough)


def _fit_text(d, txt, maxw, maxh, bold=True):
    s = int(maxh)
    while s > 6:
        f = font(s, bold)
        l, t, r, b = d.textbbox((0, 0), txt, font=f)
        if r - l <= maxw and b - t <= maxh:
            return f
        s -= 1
    return font(6, bold)


def _txt(d, xy, txt, maxw, maxh, fill, bold=True):
    f = _fit_text(d, txt, maxw, maxh, bold)
    l, t, _, _ = d.textbbox((0, 0), txt, font=f)
    d.text((xy[0] - l, xy[1] - t), txt, font=f, fill=fill)


def _steps(d, x, y, w, h, steps, ink, panel):
    """Numbered pictogram steps (simple drawn icons) with captions."""
    n = len(steps)
    cw = w / n
    for i, (icon, cap) in enumerate(steps):
        x0 = x + i * cw + cw * 0.06
        d.rectangle([x0, y, x0 + cw * 0.88, y + h * 0.62], fill=panel, outline=ink, width=max(1, int(h * 0.02)))
        cx, cy, s = x0 + cw * 0.44, y + h * 0.31, h * 0.22
        if icon == "cap":
            d.rectangle([cx - s * 0.5, cy - s * 0.2, cx + s * 0.5, cy + s], fill=ink)
            d.rectangle([cx - s * 0.6, cy - s * 0.9, cx + s * 0.6, cy - s * 0.45], fill=ink)
            d.polygon([(cx + s * 0.8, cy - s * 0.7), (cx + s * 1.2, cy - s * 0.95), (cx + s * 1.2, cy - s * 0.45)], fill=ink)
        elif icon == "pull":
            d.rectangle([cx - s * 0.25, cy - s, cx + s * 0.25, cy + s], fill=ink)
            d.line([cx, cy - s, cx, cy - s * 1.3], fill=ink, width=max(1, int(s * 0.2)))
            d.ellipse([cx - s * 0.3, cy - s * 1.6, cx + s * 0.3, cy - s * 1.0], outline=ink, width=max(1, int(s * 0.12)))
        elif icon == "hold":
            d.line([cx - s, cy + s, cx + s * 0.6, cy - s * 0.6], fill=ink, width=max(2, int(s * 0.35)))
            d.polygon([(cx + s * 0.5, cy - s * 0.5), (cx + s * 1.1, cy - s * 1.2), (cx + s * 0.85, cy - s * 0.4)], fill=(200, 40, 30))
        elif icon == "wind":
            for k in range(3):
                d.line([cx - s, cy - s * 0.6 + k * s * 0.6, cx + s, cy - s * 0.6 + k * s * 0.6], fill=ink, width=max(1, int(s * 0.15)))
            d.polygon([(cx + s, cy - s * 0.3), (cx + s * 1.3, cy), (cx + s, cy + s * 0.3)], fill=ink)
        elif icon == "up":
            d.polygon([(cx, cy - s * 1.2), (cx + s * 0.7, cy - s * 0.2), (cx - s * 0.7, cy - s * 0.2)], fill=ink)
            d.rectangle([cx - s * 0.25, cy - s * 0.2, cx + s * 0.25, cy + s], fill=ink)
        d.ellipse([x0 + cw * 0.03, y + h * 0.02, x0 + cw * 0.03 + h * 0.13, y + h * 0.15], fill=ink)
        _txt(d, (x0 + cw * 0.05, y + h * 0.035), str(i + 1), h * 0.09, h * 0.09, panel)
        _txt(d, (x0, y + h * 0.67), cap[0], cw * 0.88, h * 0.12, ink)
        if len(cap) > 1:
            _txt(d, (x0, y + h * 0.82), cap[1], cw * 0.88, h * 0.12, ink, bold=False)


def hand_label(w, h, seed):
    def draw(d, size):
        W, H = size                      # W along the tube (V after rotation), H round it
        red, wht, ink = (188, 32, 26), (238, 234, 226), (30, 26, 24)
        d.rectangle([0, 0, W, H], fill=red)
        d.rectangle([W * 0.03, H * 0.06, W * 0.97, H * 0.94], fill=wht)
        d.rectangle([W * 0.03, H * 0.06, W * 0.97, H * 0.22], fill=red)
        _txt(d, (W * 0.05, H * 0.08), "RED HAND FLARE  -  DISTRESS SIGNAL", W * 0.9, H * 0.12, wht)
        _steps(d, W * 0.04, H * 0.26, W * 0.6, H * 0.42, [("cap", ("REMOVE CAP", "twist off")), ("pull", ("PULL TAB", "sharply")),
                                                           ("hold", ("HOLD OUT", "downwind"))], ink, wht)
        _txt(d, (W * 0.66, H * 0.27), "TRELAWN SIGNALS", W * 0.3, H * 0.07, red)
        _txt(d, (W * 0.66, H * 0.36), "Burns 60 s, 15 000 cd", W * 0.3, H * 0.055, ink, bold=False)
        _txt(d, (W * 0.66, H * 0.43), "Do not look into flame", W * 0.3, H * 0.055, ink, bold=False)
        _txt(d, (W * 0.66, H * 0.50), "Hold at arm's length", W * 0.3, H * 0.055, ink, bold=False)
        _txt(d, (W * 0.66, H * 0.57), "Keep dry. Class 1.4G", W * 0.3, H * 0.055, ink, bold=False)
        d.rectangle([W * 0.04, H * 0.74, W * 0.96, H * 0.76], fill=ink)
        _txt(d, (W * 0.05, H * 0.79), "EXP 06/2031   LOT 2647-B   USE ONLY IN DISTRESS", W * 0.62, H * 0.06, ink)
        for k in range(18):           # barcode
            x0 = W * 0.74 + k * W * 0.012
            d.rectangle([x0, H * 0.78, x0 + W * (0.003 + 0.004 * ((k * 7) % 3)), H * 0.9], fill=ink)
    return _label(w, h, seed, (188, 32, 26), draw, rough=0.38, rotate=True, phys=(119.4, 111.0))


def para_label(w, h, seed):
    def draw(d, size):
        W, H = size
        red, wht, ink = (182, 30, 24), (238, 234, 226), (30, 26, 24)
        d.rectangle([0, 0, W, H], fill=red)
        d.rectangle([W * 0.02, H * 0.1, W * 0.98, H * 0.9], fill=wht)
        d.rectangle([W * 0.02, H * 0.1, W * 0.98, H * 0.26], fill=red)
        _txt(d, (W * 0.04, H * 0.13), "PARACHUTE DISTRESS ROCKET  -  RED", W * 0.6, H * 0.1, wht)
        d.polygon([(W * 0.86, H * 0.12), (W * 0.97, H * 0.18), (W * 0.86, H * 0.24)], fill=wht)
        _txt(d, (W * 0.68, H * 0.14), "THIS END UP", W * 0.16, H * 0.07, wht)
        _steps(d, W * 0.03, H * 0.3, W * 0.62, H * 0.42, [("cap", ("REMOVE CAPS", "both ends")), ("up", ("POINT UP", "downwind")),
                                                          ("pull", ("PULL PIN", "squeeze lever"))], ink, wht)
        _txt(d, (W * 0.68, H * 0.31), "TRELAWN SIGNALS", W * 0.28, H * 0.07, red)
        for k, line in enumerate(("Rises 300 m, burns 40 s", "Never fire at aircraft", "Hold firmly, arm extended",
                                  "Misfire: hold 30 s, then", "drop downwind overboard")):
            _txt(d, (W * 0.68, H * (0.40 + 0.065 * k)), line, W * 0.28, H * 0.05, ink, bold=False)
        _txt(d, (W * 0.04, H * 0.78), "EXP 11/2030   LOT 0915-R   CLASS 1.3G", W * 0.6, H * 0.07, ink)
    return _label(w, h, seed, (182, 30, 24), draw, rough=0.38, rotate=True, phys=(138.2, 280.0))


def cyl_label(w, h, seed):
    def draw(d, size):
        W, H = size
        ink = (30, 34, 36)
        d.rectangle([0, 0, W, H], fill=(232, 232, 226))
        d.rectangle([0, 0, W, H * 0.08], fill=(0, 118, 62))
        d.rectangle([0, H * 0.92, W, H], fill=(0, 118, 62))
        _txt(d, (W * 0.05, H * 0.14), "MEDICAL OXYGEN", W * 0.5, H * 0.14, ink)
        _txt(d, (W * 0.05, H * 0.33), "O2   SIZE CD   460 L   200 bar", W * 0.5, H * 0.07, ink, bold=False)
        for k, line in enumerate(("Use no oil or grease", "Open valve slowly", "Keep away from naked flame",
                                  "Secure cylinder upright or flat", "Store in a ventilated place")):
            _txt(d, (W * 0.05, H * (0.46 + 0.075 * k)), line, W * 0.42, H * 0.055, ink, bold=False)
        cx, cy, r = W * 0.68, H * 0.5, H * 0.24
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=(0, 118, 62), outline=(240, 240, 236))
        _txt(d, (cx - r * 0.2, cy - r * 0.25), "2", r * 0.5, r * 0.5, (240, 240, 236))
        cx2 = W * 0.86
        d.polygon([(cx2, cy - r), (cx2 + r, cy), (cx2, cy + r), (cx2 - r, cy)], fill=(232, 200, 30), outline=ink)
        _txt(d, (cx2 - r * 0.2, cy - r * 0.3), "5.1", r * 0.45, r * 0.5, ink)
    return _label(w, h, seed, (232, 232, 226), draw, rough=0.36, phys=(314.0, 200.0))


def strobe_label(w, h, seed):
    def draw(d, size):
        W, H = size
        ink, wht = (24, 24, 26), (238, 236, 230)
        d.rectangle([0, 0, W, H], fill=(36, 36, 38))
        d.rounded_rectangle([W * 0.06, H * 0.05, W * 0.94, H * 0.95], radius=int(W * 0.08), fill=(210, 212, 208))
        _txt(d, (W * 0.12, H * 0.09), "RESCUE STROBE", W * 0.76, H * 0.1, ink)
        _txt(d, (W * 0.12, H * 0.22), "Water activated  -  SOLAS orange", W * 0.76, H * 0.06, ink, bold=False)
        d.ellipse([W * 0.3, H * 0.33, W * 0.7, H * 0.63], fill=(200, 40, 30), outline=ink, width=3)
        _txt(d, (W * 0.39, H * 0.43), "TEST", W * 0.22, H * 0.1, wht)
        for k, line in enumerate(("Press TEST: 1 flash", "ON: slide switch up", "Flashes 50 / min, 8 h",
                                  "Replace battery by 05/2031")):
            _txt(d, (W * 0.12, H * (0.68 + 0.065 * k)), line, W * 0.76, H * 0.05, ink, bold=False)
    m = _label(w, h, seed, (36, 36, 38), draw, rough=0.45, phys=(34.0, 54.0))
    return m


def lens_strobe(w, h, seed):
    """Dome lens fit (lathe: U round, V rim -> apex): fresnel ribs, frosted, xenon tube and reflector glimpsed below."""
    x, y = grids(w, h)
    v = 1 - (y + 0.5) / h
    u = x / w
    ribs = 0.5 + 0.5 * np.cos(2 * np.pi * v * 14)
    tube = np.exp(-((v - 0.82) / 0.05) ** 2) * (0.6 + 0.4 * np.cos(4 * np.pi * u) ** 2)
    refl = ss(0.4, 0.7, v) * (0.5 + 0.5 * np.cos(2 * np.pi * u * 6))
    alb = tint((228, 230, 232), 0.9 + 0.06 * ribs)
    alb = lerp(alb, tint((246, 244, 236), np.ones_like(v)), tube * 0.8)
    alb = lerp(alb, alb * 0.82, refl * 0.3)
    return mat(alb, nvec(ribs * (1 - ss(0.7, 0.9, v)), 3.0), 0.12 + 0.06 * (1 - ribs))


def screw_head(w, h, seed):
    x, y = grids(w, h)
    v = 1 - (y + 0.5) / h
    u = x / w
    slot = (np.minimum.reduce([np.abs(((u - c + 0.5) % 1.0) - 0.5) for c in (0.0, 0.25, 0.5, 0.75)]) < 0.035) & (v > 0.45)
    m = chrome(w, seed)
    m["ALB"] = lerp(m["ALB"], np.full_like(m["ALB"], 186), slot.astype(np.float32))
    m["NOR"] = nvec(-1.0 * blur(slot.astype(np.float32), 2), 6.0)
    m["RGH"] = np.where(slot, 0.5, m["RGH"])
    return m


def vhf_face(w, h, seed):
    def draw(d, size):
        W, H = size
        d.rectangle([0, 0, W, H], fill=(48, 50, 53))
        for j in range(5):
            for i in range(9):
                x, y = W * (0.12 + 0.095 * i), H * (0.05 + 0.03 * j)
                d.ellipse([x, y, x + W * 0.05, y + W * 0.05], fill=(24, 24, 26))
        d.rectangle([W * 0.08, H * 0.24, W * 0.92, H * 0.46], fill=(120, 132, 110), outline=(30, 30, 32), width=4)
        _txt(d, (W * 0.40, H * 0.26), "16", W * 0.3, H * 0.13, (34, 40, 34))
        _txt(d, (W * 0.12, H * 0.28), "CH", W * 0.1, H * 0.035, (34, 40, 34))
        _txt(d, (W * 0.12, H * 0.38), "HI  1W", W * 0.2, H * 0.035, (34, 40, 34))
        keys = [["16/9", "SCAN", "H/L"], ["UP", "DW", "DN"], ["MENU", "WX", "LOCK"], ["CALL", "MOB", "ENT"]]
        for r_, row in enumerate(keys):
            for c_, k in enumerate(row):
                x0, y0 = W * (0.08 + 0.29 * c_), H * (0.52 + 0.11 * r_)
                fill = (196, 40, 32) if k == "16/9" else (70, 72, 76)
                d.rounded_rectangle([x0, y0, x0 + W * 0.26, y0 + H * 0.085], radius=int(W * 0.04), fill=fill, outline=(28, 28, 30), width=3)
                f = _fit_text(d, k, W * 0.2, H * 0.03)
                tw = d.textlength(k, font=f)
                d.text((x0 + W * 0.13 - tw / 2, y0 + H * 0.025), k, font=f, fill=(226, 226, 222))
        _txt(d, (W * 0.3, H * 0.965), "MARINE VHF", W * 0.4, H * 0.026, (160, 162, 164))
    im = Image.new("RGB", (w, h), (48, 50, 53))
    draw(ImageDraw.Draw(im), (w, h))
    a = np.asarray(im, np.float32)
    key = (np.abs(a[..., 0] - 70) < 30) & (np.abs(a[..., 2] - 76) < 30) | (a[..., 0] > 170) & (a[..., 1] < 80)
    lcd = (a[..., 1] > 100) & (a[..., 1] < 150) & (a[..., 0] < 140) & (a[..., 2] < 125)
    hgt = blur(key.astype(np.float32), 3) - 0.3 * blur(lcd.astype(np.float32), 2)
    m = _canvas_mat(im, seed, 0.55, hgt, 6.0)
    m["RGH"] = np.where(lcd, 0.12, np.where(key, 0.65, m["RGH"]))
    return m


RECIPES = {
    "SolasNylon": lambda n, s: fabric(n, s, SOLAS, 0.46),
    "HiVisNylon": lambda n, s: fabric(n, s, HIVIS, 0.44),
    "NavyNylon": lambda n, s: fabric(n, s, NAVY, 0.5),
    "Webbing": lambda n, s: webbing_strip(n, s, STRIP_W["Webbing"]),
    "WebbingS": lambda n, s: webbing_strip(n, s, STRIP_W["WebbingS"]),
    "RetroSewn": lambda n, s: retro_strip(n, s, STRIP_W["RetroSewn"]),
    "ZipBlack": lambda n, s: zip_strip(n, s, STRIP_W["ZipBlack"]),
    "SeamSolas": lambda n, s: seam_strip(n, s, SOLAS, (150, 50, 24), STRIP_W["SeamSolas"]),
    "SeamHiVis": lambda n, s: seam_strip(n, s, HIVIS, (60, 64, 70), STRIP_W["SeamHiVis"]),
    "SeamNavy": lambda n, s: seam_strip(n, s, NAVY, (150, 152, 156), STRIP_W["SeamNavy"]),
    "FoamSolas": lambda n, s: foam(n, s, SOLAS),
    "FoamSeam": lambda n, s: foam_seam_strip(n, s, STRIP_W["FoamSeam"]),
    "CordYellow": lambda n, s: r_rope(n, s, (234, 206, 40), "braid", 0.55, dirt=0.15, contrast=0.6, strength=9.0),
    "CordBlack": lambda n, s: r_rope(n, s, (44, 44, 46), "braid", 0.6, dirt=0.1, contrast=0.6, strength=9.0),
    "RopeGrab": lambda n, s: r_rope(n, s, (186, 180, 164), "braid", 0.66, dirt=0.55, contrast=0.6, strength=9.0),
    "RopeThrow": lambda n, s: r_rope(n, s, (234, 206, 40), "braid", 0.52, dirt=0.18, contrast=0.65, strength=10.0),
    "RopeOrange": lambda n, s: r_rope(n, s, (226, 98, 40), "braid", 0.58, dirt=0.2, contrast=0.6, strength=9.0),
    "ClipWhite": clip_white,
    "SolasPE": lambda n, s: r_plastic(n, s, SOLAS, 0.45, scuff=0.2, grain=0.5),
    "MaskPVC": lambda n, s: clear_pvc(n, s, (196, 214, 204), 0.12),
    "TubeGreen": lambda n, s: clear_pvc(n, s, (126, 186, 150), 0.22),
    "FoilGoldA": lambda n, s: foil(n, s, (250, 212, 120)),
    "FoilGoldB": lambda n, s: foil(n, s + 5, (248, 210, 116)),
    "FoilSilverA": lambda n, s: foil(n, s + 11, (222, 224, 228)),
    "FoilSilverB": lambda n, s: foil(n, s + 17, (220, 222, 226)),
    "VHFBody": lambda n, s: r_plastic(n, s, (56, 58, 62), 0.6, scuff=0.2, grain=0.8),
    "HiVisABS": lambda n, s: r_plastic(n, s, HIVIS, 0.42),
    "BlackABS": lambda n, s: r_plastic(n, s, (40, 40, 42), 0.46),
    "WhiteABS": lambda n, s: r_plastic(n, s, (226, 226, 220), 0.42, scuff=0.15),
    "Rubber": rubber,
    "Stainless": lambda n, s: hm.m_stainless(n, s),
    "Brass": chrome,
    "CylWhite": painted_cyl,
    "GreyABS": lambda n, s: r_plastic(n, s, (118, 122, 126), 0.5),
    "FlareRed": lambda n, s: r_plastic(n, s, (186, 32, 26), 0.45, scuff=0.15),
    "SolasABS": lambda n, s: r_plastic(n, s, SOLAS, 0.4),
    "LensClear": lambda n, s: lens(n, s, (222, 224, 224), 0.16),
    "LensRed": composition,
    "Knurl": knurl,
}
FITS = {"CrossPatch": lambda w, h, s: cross_patch(w, h, s, w / 120.0), "OxyPatch": lambda w, h, s: oxy_patch(w, h, s, w / 200.0),
        "RingFit": ring_fit, "VHFFace": vhf_face, "CylLabel": cyl_label, "HandLabel": hand_label, "ParaLabel": para_label,
        "StrobeLabel": strobe_label, "LensStrobe": lens_strobe, "ScrewHead": screw_head}
POROUS = ("SolasNylon", "NavyNylon", "HiVisNylon", "Webbing", "WebbingS", "ZipBlack", "SeamSolas", "SeamHiVis", "SeamNavy",
          "CordYellow", "CordBlack", "RopeGrab", "RopeThrow", "RopeOrange", "CrossPatch", "OxyPatch", "LensRed")


def px_mm(key, w):
    k, s = atlas.kind(key), atlas.scale(key)
    if k == "tile":
        return w / (s * 1000)
    if k == "strip":
        return w / STRIP_W[key]
    if k == "rope":
        return w / (math.pi * 10.0)
    return {"RingFit": w / 1885.0, "CrossPatch": w / 120.0, "OxyPatch": w / 200.0, "VHFFace": w / 48.0, "CylLabel": w / 314.0,
            "HandLabel": w / 119.0, "ParaLabel": w / 138.0, "StrobeLabel": w / 40.0, "LensStrobe": w / 100.0,
            "ScrewHead": w / 15.0}.get(key, w / 100.0)


def droplets(w, h, pxmm, density, seed, rmin=0.4, rmax=2.6):
    """Bead water: dome heights and a mask; periodic wrap. density = drops per cm^2."""
    rng = np.random.default_rng(seed)
    area_cm2 = (w / pxmm) * (h / pxmm) / 100.0
    n = int(min(area_cm2 * density, 9000))
    hgt = np.zeros((h, w), np.float32)
    for _ in range(n):
        r = rng.uniform(rmin, rmax) ** 1.0 * pxmm * (rng.uniform(0.6, 1.0) if rng.random() < 0.7 else 1.0)
        if r < 0.9:
            continue
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        R = int(math.ceil(r)) + 1
        ys = np.arange(int(cy) - R, int(cy) + R + 1)
        xs = np.arange(int(cx) - R, int(cx) + R + 1)
        dy = (ys[:, None] - cy)
        dx = (xs[None, :] - cx) * rng.uniform(0.85, 1.15)
        d2 = 1 - (dx * dx + dy * dy) / (r * r)
        dome = np.sqrt(np.clip(d2, 0, 1)) * r / pxmm
        hgt[np.ix_(ys % h, xs % w)] = np.maximum(hgt[np.ix_(ys % h, xs % w)], dome)
    return hgt, (hgt > 0).astype(np.float32)


def wet(m, key, seed):
    met = m["MET"]
    h, w = met.shape
    pm = px_mm(key, w)
    if key in POROUS:
        dk, gk, dens, film = 0.64, 0.36, 1.6, 0.04
    elif met.mean() > 0.5:
        dk, gk, dens, film = 0.87, 0.5, 4.0, 0.02
    else:
        dk, gk, dens, film = 0.82, 0.25, 3.0, 0.03
    alb = np.maximum(m["ALB"] * dk, 22)
    rgh = np.clip(m["RGH"] * gk + film, 0.04, 1)
    dh, dm = droplets(w, h, pm, dens, seed, rmin=0.5, rmax=3.6)
    keep = ss(0.42, 0.55, fb(w, h, 3, seed + 1)) if w == h else 1.0      # beads cluster, dry patches between
    dh, dm = dh * keep, dm * (keep > 0.5)
    if dm.any():
        strength = 0.9 * pm                       # slope per px of dome height in mm
        nd = nvec(dh, strength)
        nor = ncombine(m["NOR"], nd, 1.0)
        nor = np.where(dm[..., None] > 0, _renorm(nor * 0.2 + nd * 0.8), nor)
        rgh = np.where(dm > 0, 0.04, rgh)
        alb = lerp(alb, alb * 0.94, dm * (0.0 if met.mean() > 0.5 else 1.0))
    else:
        nor = m["NOR"]
    return dict(m, ALB=alb, RGH=rgh, NOR=nor.astype(np.float32))


def images(m):
    alb = np.clip(m["ALB"], 0, 255)
    met = np.clip(m["MET"], 0, 1)
    y = lum(alb)
    metal = met > 0.5
    lo = np.where(metal, 182.0, 24.0)
    hi = np.where(metal, 248.0, 238.0)
    k = np.clip(y, lo, hi) / np.maximum(y, 1e-3)              # clamp luma, keep hue (gold stays gold)
    alb = np.clip(alb * k[..., None], 0, 255)
    return {"ALB": Image.fromarray(alb.round().astype(np.uint8), "RGB"),
            "NOR": Image.fromarray(np.clip((m["NOR"] * 0.5 + 0.5) * 255, 0, 255).round().astype(np.uint8), "RGB"),
            "RGH": Image.fromarray(np.clip(m["RGH"] * 255, 0, 255).round().astype(np.uint8), "L"),
            "MET": Image.fromarray(np.clip(met * 255, 0, 255).round().astype(np.uint8), "L")}


def downsize(im, size, kind):
    out = im.resize((size, size), Image.LANCZOS)
    if kind == "NOR":
        v = np.asarray(out, np.float32) / 127.5 - 1
        v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-6)
        out = Image.fromarray(np.clip((v * 0.5 + 0.5) * 255, 0, 255).round().astype(np.uint8), "RGB")
    return out


def build_set(set_name, size):
    g = atlas.GRIDS[set_name]
    C = size // g
    maps = {"ALB": np.full((size, size, 3), 128, np.float32), "NOR": flat(size), "RGH": np.full((size, size), 0.7, np.float32),
            "MET": np.zeros((size, size), np.float32)}
    wmaps = {k: v.copy() for k, v in maps.items()}
    wmaps["ALB"][:] = 92
    wmaps["RGH"][:] = 0.4
    sig = np.zeros((size, size), np.uint8)
    for i, (key, r) in enumerate(sorted(atlas.R.items())):
        if r[6] != set_name:
            continue
        cx, cy, cw, ch = r[:4]
        w, h = cw * C, ch * C
        seed = 401 + 37 * i
        m = FITS[key](w, h, seed) if key in FITS else RECIPES[key](w, seed)
        m = {k: (v if v.shape[:2] == (h, w) else rsz(v, w, h)) for k, v in m.items()}
        mw = wet(m, key, seed + 999)
        y0, x0 = size - (cy + ch) * C, cx * C
        for dst, src in ((maps, m), (wmaps, mw)):
            for k in ("ALB", "NOR", "RGH", "MET"):
                dst[k][y0:y0 + h, x0:x0 + w] = src[k]
        if r[7]:
            sig[y0:y0 + h, x0:x0 + w] = 255
        print("  %s %s %dx%d" % (set_name, key, w, h), flush=True)
    return maps, wmaps, sig


def main():
    only = sys.argv[1:]
    os.makedirs(MASTERS, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for set_name in atlas.SETS:
        if only and set_name not in only:
            continue
        maps, wmaps, sig = build_set(set_name, atlas.MASTER)
        for suffix, m in (("", maps), ("_Wet", wmaps)):
            for k, im in images(m).items():
                if suffix and k == "MET":
                    continue
                fn = "T_%s_%s_%s%s.png" % (atlas.NAME, set_name, k, suffix)
                im.save(os.path.join(MASTERS, fn), optimize=True)
                downsize(im, atlas.EXPORT, k).save(os.path.join(OUT, fn), optimize=True)
        Image.fromarray(sig, "L").resize((atlas.EXPORT, atlas.EXPORT), Image.NEAREST).save(
            os.path.join(HERE, "T_%s_%s_signal.png" % (atlas.NAME, set_name)))
        print("wrote set", set_name, flush=True)


if __name__ == "__main__":
    main()
