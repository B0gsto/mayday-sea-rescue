"""M_Road_DryStoneWall trim set T_DryStoneWall_Granite_* (docs/12 2.4; system python3 + numpy + Pillow, no heavy slot).

    python3 art/source/roads/M_Road_DryStoneWall/walltex.py [--out DIR]

Writes build/prod/M_Road_DryStoneWall/textures/M_Road_DryStoneWall/ (ship 1024) and masters 2048 to
art/source/roads/M_Road_DryStoneWall/textures/. One set for the whole asset (docs/12: trim + MaterialVariant), six
cells (layout.py), all of them the same Cornish granite in a different weather:

  wall    the split face of the wall's stones. Base: the granite_tile scan (Poly Haven CC0, Charlotte Baglioni) at its
          own scale (the scan is seamless), graded to the 05 granite #8A8781, then the coastal stack by height above
          ground: mud splash, grit and a damp capillary line in the bottom 0.3 m, moss and soil at the foot, rain wash
          running down from under the coping, dried salt spray and a sparse lichen dusting higher up.
  cope    the coping stones' bed: the most weathered granite on the wall - bleached, scoured, and carrying a dense
          crustose lichen community.
  lichen  a stone whose whole face carries a lichen community (grey-white, sage, orange Xanthoria, black
          Verrucaria) - overlapping colonies at three scales, growing in patches, granite showing between them.
  moss    dense moss: clumped, fine-leaved, dark at the roots, some dried brown, a little soil and grit.
  joint   the inside of a joint: gritty and mossy at the mouth, darker and damper further in (U = depth from the
          face), soil and sand at the bottom of the wall.
  grass   the grass tufts at the foot: dark at the roots, bleached and dry at the tips, blades running up the V axis.

CC0 scans only; the granite is the same scan the R1a kerbs and cobbles use, so the wall matches the kerb stones.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import texlib as T  # noqa: E402
import layout as L  # noqa: E402

F32 = np.float32
M = 2048                 # masters
SHIP = 1024              # shipping size
MASTERS = os.path.join(HERE, "textures")
DEFAULT_OUT = os.path.join(T.GAME, "build/prod/M_Road_DryStoneWall/textures/M_Road_DryStoneWall")
STEM = "T_DryStoneWall_Granite"
SCAN_PERIOD_M = 2.30     # the granite_tile scan is 2.30 m across and seamless: one period of it, at its own scale
GRASS_V_M = L.GRASS_V_M

_src = None


# ---------------------------------------------------------------------------------------------------- helpers
def renorm(n):
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def limit_sat(rgb, k=0.42):
    """Saturation above k squeezed toward luma (docs/12 1.4a: at most 0.45 outside a signal mask)."""
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    over = np.clip(sat / k - 1.0, 0, 1)
    y = T.luma(rgb)[..., None]
    return y + (rgb - y) * (1.0 - over)[..., None]


def smear_down(mask, steps, decay):
    """Run-off: the mask repeated downward (down the image = down the wall) with decaying strength."""
    out = mask.copy()
    for i in range(1, steps + 1):
        out = np.maximum(out, np.roll(mask, i, 0) * (decay ** i))
    return out


def streaks(hw, seed, length, thin=0.05):
    """A soft field of thin vertical streams (rain wash), periodic both ways."""
    h, w = hw
    cols = T.noise((h, max(8, w // 6)), 12, seed + 1, 3)
    cols = np.asarray(Image.fromarray(cols, mode="F").resize((w, h), Image.BILINEAR), F32)
    f = T.noise(hw, 34, seed + 2, 2, aniso=(0.10, 1.0))
    line = (1 - T.sstep(0.0, thin, np.abs(f - 0.5))) * T.sstep(0.42, 0.72, cols)
    return smear_down(line, max(1, int(length)), 0.985)


def blur(x, cells):
    """Low-pass of a 2D float field: box-down to cells x cells, bicubic back up."""
    im = Image.fromarray(x.astype(F32), mode="F")
    return np.asarray(im.resize((cells, cells), Image.BOX).resize(im.size, Image.BICUBIC), F32)


def _line_runs(prof, sd, max_w=120, edge=150, thr=0.8):
    """Bands of a profile clearly below the sheet's own baseline: the tile scan's grout lines and their chamfered
    bevels. The flagstone pattern is irregular, so the bands are found, not assumed periodic."""
    p = np.convolve(prof, np.ones(5) / 5, mode="same")
    low = p < np.median(p) - thr * sd
    runs, s = [], None
    for i, v in enumerate(low):
        if v and s is None:
            s = i
        if (not v or i == len(low) - 1) and s is not None:
            if 3 <= i - s <= max_w and s > edge and i < len(low) - edge:
                runs.append((s, i))
            s = None
    return runs


def delines(arr, runs, axis, half=18):
    """Take the tile scan's grout lines out. A thin line (the grout itself) is refilled from the median of the granite
    just either side of it, column by column: the scan's veins run along the axis, so a vein crossing the line is
    carried through. A wide band (a grout plus the chamfered tile edges) is refilled from the clean granite just
    before it, matched in tone to the granite each side, which keeps the grain at the cost of one vein join.
    Runs: (start, end) bands along the axis."""
    n = arr.shape[axis]
    out = arr
    for s, e in runs:
        box = lambda i0, i1: tuple(slice(i0, i1) if a == axis else slice(None) for a in range(out.ndim))
        shape = tuple((e - s) if a == axis else out.shape[a] for a in range(out.ndim))
        out = out.copy()
        if e - s <= 14:
            lo, hi = max(0, s - half), min(n, e + half)
            nb = np.concatenate([out[box(lo, s)], out[box(e, hi)]], axis=axis)
            med = np.expand_dims(np.median(np.moveaxis(nb, axis, 0), axis=0), axis)
            out[box(s, e)] = np.broadcast_to(med, shape)
        else:
            near = np.concatenate([out[box(max(0, s - 40), s)], out[box(e, min(n, e + 40))]], axis=axis)
            src = np.roll(out, (e - s) + 60, axis=axis)
            k = float(T.luma(np.moveaxis(near, axis, 0)).mean()) / \
                max(float(T.luma(np.moveaxis(src[box(s, e)], axis, 0)).mean()), 1e-3)
            m = np.zeros(n, F32)
            m[s:e] = 1.0
            r = min(20, (e - s) // 3)
            if r:
                m[s:s + r] = np.linspace(0.0, 1.0, r, dtype=F32)
                m[e - r:e] = np.linspace(1.0, 0.0, r, dtype=F32)
            shp = [1] * out.ndim
            shp[axis] = n
            out = out * (1 - m.reshape(shp)) + src * k * m.reshape(shp)
    return out


def scan_src():
    """(alb, rgh, nor, disp, px_per_m) of the granite_tile scan: 2.30 m of quarried granite, its tile grout lines
    patched out and its lighting flat-fielded, so it tiles anywhere without a grid or a vignette."""
    global _src
    if _src is None:
        meta = T.fetch("granite_tile")
        a, r, n, d = T.load(meta)
        y = T.luma(a)
        flat = np.maximum(blur(y, 24), 1e-3)
        gain = (float(np.median(y)) / flat)[..., None]
        a = np.clip(a * gain, 0, 255)
        xr = _line_runs(y.mean(0), y.mean(0).std())
        yr = _line_runs(y.mean(1), y.mean(1).std())
        a = delines(delines(a, xr, 1), yr, 0)
        r = delines(delines(r, xr, 1), yr, 0)
        n = delines(delines(n, xr, 1), yr, 0)
        d = delines(delines(d, xr, 1), yr, 0)
        _src = (a, r, n, d, 2048 / meta["dims_m"][0])
    return _src


def base(w, h, ppm_u, ppm_v, seed=0, period_m=SCAN_PERIOD_M, offset=None):
    """The granite of one cell: the flat-fielded scan at its own scale, tiled, no grid. `seed` picks the crop phase."""
    a, r, n, d, _ = scan_src()
    if offset is None:
        rng = np.random.default_rng(seed)
        offset = (int(rng.integers(0, 2048)), int(rng.integers(0, 2048)))
    tp = (period_m * ppm_u, period_m * ppm_v)
    return (T.tile_to(a, tp, (h, w), offset), T.tile_to(r, tp, (h, w), offset),
            renorm(T.tile_to(n, tp, (h, w), offset)), T.tile_to(d, tp, (h, w), offset))


def height_grid(h, ppm_v, v_m):
    """World height above ground (m) per row: row 0 is the top of the cell."""
    return (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None] * v_m


def grade_granite(a, r, hgt, seed, ppm_u, mean=132, std=26, grain=0.35):
    """Grade the scan to the 05 granite, keep its pits in the normal, add a little feldspar / mica grain."""
    hw = a.shape[:2]
    a = T.grade(a, mean, std, tint=(1.0, 1.0, 1.01), desat=0.62)
    hgt = (hgt - hgt.mean()) * 0.009                                   # the scan's pits and cracks, in metres
    if grain:
        g = T.noise(hw, max(24, int(ppm_u / 0.005)), seed + 1, 3)      # feldspar / quartz crystals, ~5 mm
        b = T.noise(hw, max(16, int(ppm_u / 0.022)), seed + 2, 2)      # biotite mottling, ~2 cm
        a = a * (1 - grain * 0.9 * (g - 0.5))[..., None] * (1 - grain * 0.5 * (b - 0.5))[..., None]
        hgt = hgt + (g - 0.5) * 0.00045 * grain + (b - 0.5) * 0.00025 * grain
    r = np.clip(0.60 + (r - r.mean()) * 0.45, 0.46, 0.88)
    return a, r, hgt


# ---------------------------------------------------------------------------------------------------- lichen community
SPECIES = (  # (cumulative share, albedo, speckle, relief mm, roughness, extra patch mask)
    (0.34, (152, 149, 138), 26, 0.7, 0.92, None),      # grey-white crustose (Pertusaria / Diplotomma)
    (0.58, (124, 128, 108), 22, 0.6, 0.90, None),      # sage-green (Lecanora)
    (0.66, (150, 122, 86), 18, 0.5, 0.86, "orange"),   # orange Xanthoria parietina, in patches only
    (0.78, (76, 74, 68), 12, 0.4, 0.88, "low"),        # black Verrucaria, low and in the crevices
    (1.00, None, 0, 0.0, 0.0, None),                   # bare granite
)


def lichen_community(a, r, hgt, seed, ppm_u, ppm_v, v_m, x_m, patch_lo, patch_hi, relief=1.0, orange=0.5):
    """Crustose lichen over granite. Colonies are the union of three jittered Voronoi scales (2, 5 and 10 cm), each
    colony one species and its own coverage, so the growth is a field of overlapping irregular blobs; colonies only
    appear where the patch field allows, with crisp edges and a pale growing rim."""
    hw = a.shape[:2]
    z = height_grid(hw[0], ppm_v, v_m)
    X = x_m + np.zeros_like(z)
    Z = z + np.zeros_like(X)
    x_max = float(x_m.max())
    patch = (0.6 * T.noise(hw, 7, seed + 1, 3) + 0.4 * T.noise(hw, 17, seed + 2, 2))
    patch = (patch - patch.min()) / max(float(patch.max() - patch.min()), 1e-6)
    present = T.sstep(patch_lo, patch_hi, patch)
    best = np.zeros(hw, F32)
    sp = np.zeros(hw, F32)
    tone = np.zeros(hw, F32)
    edge = np.zeros(hw, F32)
    for k, (cells, ph) in enumerate(((0.018, 0.0), (0.042, 0.7), (0.085, 1.4))):
        f1, f2, cid = T.voronoi(X + ph, Z + ph * 0.6, cells, x_max + 1e-6, v_m, seed + 11 * k)
        rad = cells * (0.45 + 0.80 * T.hash01(cid, 3))
        inside = (1.0 - T.sstep(rad, rad + cells * 0.13, f1)) * T.sstep(0.30, 0.62, T.hash01(cid, 11))
        win = inside > best
        best = np.where(win, inside, best)
        sp = np.where(win, T.hash01(cid, 7), sp)
        tone = np.where(win, T.hash01(cid, 5), tone)
        edge = np.where(win, T.sstep(rad * 0.72, rad * 0.94, f1) * (1 - T.sstep(rad, rad + cells * 0.16, f1)), edge)
    lic = best * present
    fine = T.noise(hw, max(90, int(ppm_u / 0.015)), seed + 3, 2)
    speck = T.sstep(0.80, 0.93, T.noise(hw, max(120, int(ppm_u / 0.008)), seed + 4, 1))   # tiny colonies
    orange_patch = T.sstep(0.55, 0.80, T.noise(hw, 6, seed + 6, 3)) * orange
    low = T.sstep(0.35, 0.05, z + 0.10 * (fine - 0.5))                                   # damp bottom of the wall
    a_out = a.copy()
    rough_of = np.zeros(hw, F32)
    relief_of = np.zeros(hw, F32)
    acc = 0.0
    for share, col, spec, mm, rough, extra in SPECIES:
        m = lic * T.sstep(acc - 0.03, acc + 0.03, sp) * (1.0 - T.sstep(share - 0.03, share + 0.03, sp))
        acc = share
        if extra == "orange":
            m = m * orange_patch
        elif extra == "low":
            m = m * low
        if col is None:
            continue
        c = np.array(col, F32)[None, None, :] * (0.86 + 0.28 * tone[..., None])
        c = c * (0.92 + 0.16 * fine[..., None])
        a_out = T.blend(a_out, c, m * 0.80)
        rough_of = np.maximum(rough_of, m * rough)
        relief_of = np.maximum(relief_of, m * mm * relief)
    # the pale growing rim, and the darker line where two colonies meet
    a_out = T.blend(a_out, np.dstack([np.full(hw, c, F32) for c in (188, 186, 172)]), edge * lic * 0.26)
    a_out = T.blend(a_out, np.dstack([np.full(hw, c, F32) for c in (92, 90, 84)]), speck * 0.25)
    r = np.clip(r * (1 - rough_of) + rough_of * 0.93, 0.40, 0.95)
    hgt = hgt + relief_of * 0.0010 + lic * (fine - 0.5) * 0.0007 + speck * 0.0004
    return a_out, r, hgt


# ---------------------------------------------------------------------------------------------------- cells
def wall(w, h, seed):
    """Split granite wall face: mud splash, damp line and salt bloom at their real heights, rain wash, moss at the
    foot, a sparse lichen dusting higher up."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.WALL_U_M, h / L.CELL_V_M
    z = height_grid(h, ppm_v, L.CELL_V_M)
    a, r, nor, d = base(w, h, ppm_u, ppm_v, seed + 1)
    a, r, hgt = grade_granite(a, r, d, seed, ppm_u, mean=121, std=26)
    x = (np.arange(w, dtype=F32) + 0.5)[None, :] / ppm_u
    nz = T.noise(hw, 9, seed + 5, 3)
    grit = T.noise(hw, max(60, int(ppm_u / 0.0035)), seed + 6, 1)
    # ---- rain wash: thin streams running down from under the coping, thinning as they fall
    wash = streaks(hw, seed + 20, 320, 0.05) * (0.30 + 0.70 * T.sstep(0.25, 0.90, z + 0.10 * (nz - 0.5)))
    wash = wash * (0.35 + 0.65 * T.sstep(0.35, 0.70, T.noise(hw, 7, seed + 21, 3)))
    a = T.blend(a, np.dstack([104 + 14 * nz, 99 + 12 * nz, 90 + 10 * nz]).astype(F32), wash * 0.45)
    r = r + 0.08 * wash
    hgt = hgt - wash * (0.00020 + (grit - 0.5) * 0.00030)
    # ---- mud splash and grit in the bottom 0.35 m, a darker buried line right at the ground
    splash = np.clip(np.exp(-np.maximum(z - 0.05, 0.0) / 0.17) * (0.80 + 0.50 * nz) - 0.06, 0, 1)
    splash = np.clip(splash * (0.72 + 0.55 * grit), 0, 1)
    a = T.blend(a, np.dstack([96 + 26 * nz, 84 + 20 * nz, 68 + 15 * nz]).astype(F32), splash * 0.86)
    r = r * (1 - splash) + splash * 0.92
    hgt = hgt * (1 - splash) + splash * ((grit - 0.5) * 0.0009)
    damp = T.sstep(0.09, 0.0, z) * (0.5 + 0.5 * nz)                    # capillary damp at the base
    a = a * (1 - 0.26 * damp[..., None])
    r = r * (1 - 0.35 * damp) + 0.35 * damp * 0.55
    # ---- moss at the foot, in patches, heavier where the stone is shaded
    moss_patch = T.sstep(0.30, 0.62, T.noise(hw, 8, seed + 7, 3) * 0.7 + 0.3 * nz)
    moss_m = np.clip(T.sstep(0.26, 0.02, z + 0.06 * (nz - 0.5)) * moss_patch, 0, 1)
    moss_col = np.dstack([60 + 22 * nz, 78 + 26 * nz, 46 + 16 * nz]).astype(F32)
    a = T.blend(a, moss_col, moss_m * 0.62)
    r = r * (1 - moss_m) + moss_m * 0.90
    hgt = hgt + moss_m * (T.noise(hw, max(80, int(ppm_u / 0.012)), seed + 8, 2) - 0.5) * 0.0020
    # ---- dried salt spray and a pale bloom higher up (rain shadow under the coping, sun-bleached stone)
    salt = T.sstep(0.62, 0.86, T.noise(hw, 26, seed + 9, 3, aniso=(0.85, 1.0))) * (0.30 + 0.70 * T.sstep(0.30, 0.85, z))
    a = T.blend(a, np.dstack([200 + 5 * nz] * 2 + [194 + 4 * nz]).astype(F32), salt * 0.22)
    r = r + 0.10 * salt
    # ---- a sparse lichen dusting (the whole-stone communities live in the lichen cell)
    a, r, hgt = lichen_community(a, r, hgt, seed + 30, ppm_u, ppm_v, L.CELL_V_M, x, 0.70, 0.88, orange=0.35)
    # ---- large-scale tonal drift so a 2.5 m run never reads as one tile
    a = a * (1 + 0.09 * (T.noise(hw, 3, seed + 10, 2)[..., None] - 0.5))
    r = np.clip(r + 0.06 * (T.noise(hw, 11, seed + 11, 3) - 0.5), 0.42, 0.95)
    n = T.combine_normals(nor, T.height_normal_uv(hgt, ppm_u, ppm_v, 1.7))
    return np.clip(a, 28, 240), r, n, np.zeros(hw, F32)


def cope(w, h, seed):
    """The coping stones' bed: bleached, rain-scoured granite under a dense crustose lichen community."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.CELL_M["cope"][0], h / L.CELL_M["cope"][1]
    z = height_grid(h, ppm_v, L.CELL_M["cope"][1])
    a, r, nor, d = base(w, h, ppm_u, ppm_v, seed + 2)
    a, r, hgt = grade_granite(a, r, d, seed, ppm_u, mean=146, std=24)
    x = (np.arange(w, dtype=F32) + 0.5)[None, :] / ppm_u
    nz = T.noise(hw, 9, seed + 5, 3)
    bleach = 0.35 + 0.65 * T.sstep(0.35, 0.75, T.noise(hw, 6, seed + 2, 3))   # sun-bleached, wind-scoured stone
    a = T.blend(a, T.desat(T.grade(a, 172, 20), 0.80, tint=(1.0, 1.0, 0.99)), bleach * 0.45)
    r = r + 0.06 * bleach
    a, r, hgt = lichen_community(a, r, hgt, seed + 40, ppm_u, ppm_v, L.CELL_M["cope"][1], x, 0.26, 0.70,
                                 relief=1.15, orange=0.8)
    wash = streaks(hw, seed + 22, 200, 0.04) * (0.30 + 0.70 * T.sstep(0.4, 0.95, T.noise(hw, 7, seed + 23, 3)))
    a = T.blend(a, np.dstack([112 + 14 * nz, 108 + 12 * nz, 100 + 10 * nz]).astype(F32), wash * 0.22)
    grit = T.noise(hw, max(60, int(ppm_u / 0.004)), seed + 6, 1)
    a = a * (1 - 0.10 * (T.sstep(0.72, 0.9, grit) * (1 - bleach))[..., None])
    a = a * (1 + 0.04 * (T.noise(hw, 3, seed + 10, 2)[..., None] - 0.5))
    n = T.combine_normals(nor, T.height_normal_uv(hgt, ppm_u, ppm_v, 1.6))
    return np.clip(a, 30, 240), np.clip(r, 0.42, 0.95), n, np.zeros(hw, F32)


def lichen(w, h, seed):
    """A stone carrying a dense crustose lichen community over granite."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.CELL_M["lichen"][0], h / L.CELL_M["lichen"][1]
    a, r, nor, d = base(w, h, ppm_u, ppm_v, seed + 3)
    a, r, hgt = grade_granite(a, r, d, seed, ppm_u, mean=126, std=24)
    x = (np.arange(w, dtype=F32) + 0.5)[None, :] / ppm_u
    a, r, hgt = lichen_community(a, r, hgt, seed + 50, ppm_u, ppm_v, L.CELL_M["lichen"][1], x, 0.16, 0.60,
                                 relief=1.1, orange=0.65)
    n = T.combine_normals(nor, T.height_normal_uv(hgt, ppm_u, ppm_v, 1.6))
    return np.clip(a, 30, 240), np.clip(r, 0.42, 0.95), n, np.zeros(hw, F32)


def moss(w, h, seed):
    """Dense moss: clumped, fine-leaved, dark at the roots, some dried brown, soil showing through."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.CELL_M["moss"][0], h / L.CELL_M["moss"][1]
    z = height_grid(h, ppm_v, L.CELL_M["moss"][1])
    a, r, nor, d = base(w, h, ppm_u, ppm_v, seed + 4)
    a = T.grade(a, 74, 16, desat=0.7)                                  # dark soil / stone under the moss
    nz = T.noise(hw, 9, seed + 5, 3)
    clump = T.noise(hw, max(40, int(ppm_u / 0.06)), seed + 1, 4)        # 6 cm clumps
    leaf = T.noise(hw, max(120, int(ppm_u / 0.011)), seed + 2, 3)       # 1 cm leaf detail
    frond = T.noise(hw, max(90, int(ppm_u / 0.02)), seed + 3, 2, aniso=(1.0, 0.30))
    cover = np.clip(T.sstep(0.26, 0.72, clump) * (0.55 + 0.55 * leaf), 0, 1)
    dry = T.sstep(0.55, 0.85, T.noise(hw, 7, seed + 4, 3)) * (0.4 + 0.6 * T.sstep(0.35, 0.9, z))
    green = np.dstack([40 + 18 * leaf + 8 * nz, 52 + 26 * leaf + 10 * nz, 32 + 12 * leaf + 5 * nz]).astype(F32)
    dry_c = np.dstack([86 + 24 * leaf, 78 + 20 * leaf, 48 + 14 * leaf]).astype(F32)
    col = green * (1 - dry[..., None] * 0.7) + dry_c * (dry[..., None] * 0.7)
    col = col * (0.62 + 0.62 * (0.6 * clump + 0.4 * frond))[..., None]
    a = T.blend(a, col, cover * 0.80)
    soil = T.sstep(0.30, 0.0, cover) * (0.4 + 0.6 * nz)
    a = T.blend(a, np.dstack([64 + 20 * nz, 58 + 18 * nz, 44 + 12 * nz]).astype(F32), soil * 0.5)
    r = np.clip(r * (1 - cover) + cover * 0.94 + 0.04 * (frond - 0.5), 0.5, 0.97)
    hgt = ((clump - 0.5) * 0.0055 + (leaf - 0.5) * 0.0022 + (frond - 0.5) * 0.0016) * (0.25 + 0.75 * cover)
    n = T.combine_normals(nor, T.height_normal_uv(hgt, ppm_u, ppm_v, 1.0))
    return np.clip(a, 30, 240), r, n, np.zeros(hw, F32)


def joint(w, h, seed):
    """The inside of a joint: gritty and mossy at the mouth, darker and damper further back."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.CELL_M["joint"][0], h / L.CELL_M["joint"][1]
    z = height_grid(h, ppm_v, L.CELL_M["joint"][1])
    depth = (np.arange(w, dtype=F32) + 0.5)[None, :] / w               # 0 at the wall face, 1 = 0.9 m in
    a, r, nor, d = base(w, h, ppm_u, ppm_v, seed + 5)
    a, r, hgt = grade_granite(a, r, d, seed, ppm_u, mean=114, std=20)
    nz = T.noise(hw, 9, seed + 5, 3)
    grit = T.noise(hw, max(60, int(ppm_u / 0.003)), seed + 6, 1)
    # the cavity: light falls off fast behind the arris
    cavity = T.sstep(0.02, 0.26, depth + 0.05 * (nz - 0.5))
    a = a * (1 - 0.38 * cavity[..., None])
    r = r * (1 - cavity * 0.15) + cavity * 0.15 * 0.80
    hgt = hgt - cavity * 0.0008
    # grit and sand washed into the mouth of the joint, more of it low down
    mouth = T.sstep(0.16, 0.02, depth) * (0.35 + 0.65 * grit) * (0.45 + 0.55 * T.sstep(0.45, 0.05, z))
    a = T.blend(a, np.dstack([126 + 30 * grit, 116 + 26 * grit, 96 + 20 * grit]).astype(F32), np.clip(mouth, 0, 1) * 0.65)
    r = r * (1 - mouth * 0.5) + mouth * 0.5 * 0.94
    # moss in the shaded joints low down, and a little higher on the shaded side
    moss_m = np.clip(T.sstep(0.30, 0.02, z + 0.08 * (nz - 0.5)) * T.sstep(0.34, 0.06, depth) * (0.35 + 0.65 * nz), 0, 1)
    a = T.blend(a, np.dstack([54 + 18 * nz, 72 + 22 * nz, 42 + 14 * nz]).astype(F32), moss_m * 0.8)
    r = r * (1 - moss_m) + moss_m * 0.92
    hgt = hgt + moss_m * (grit - 0.5) * 0.0018
    # dried soil at the very bottom of the joint, and a soft dark top (the joint closes under the course above)
    a = T.blend(a, np.dstack([74 + 22 * nz, 64 + 18 * nz, 50 + 14 * nz]).astype(F32), T.sstep(0.06, 0.0, z) * 0.5)
    a = a * (1 - 0.22 * T.sstep(0.80, 0.95, z)[..., None])
    a = a * (1 + 0.05 * (T.noise(hw, 3, seed + 10, 2)[..., None] - 0.5))
    n = T.combine_normals(nor, T.height_normal_uv(hgt, ppm_u, ppm_v, 1.5))
    return np.clip(a, 30, 236), np.clip(r, 0.45, 0.96), n, np.zeros(hw, F32)


def grass(w, h, seed):
    """Grass blades: dark at the roots, bleached dry at the tips, blades running up the V axis, soil at the base."""
    hw = (h, w)
    ppm_u, ppm_v = w / L.CELL_M["grass"][0], h / L.CELL_M["grass"][1]
    v = (1.0 - (np.arange(h, dtype=F32) + 0.5) / h)[:, None]           # 0 at the ground, 1 at the blade tips
    nz = T.noise(hw, 9, seed + 5, 3)
    blade = T.noise(hw, max(120, int(ppm_u / 0.02)), seed + 1, 2, aniso=(1.0, 0.12))    # features along V
    blade2 = T.noise(hw, max(60, int(ppm_u / 0.008)), seed + 2, 2, aniso=(1.0, 0.20))
    dry = np.clip(T.sstep(0.45, 0.95, T.noise(hw, 8, seed + 3, 3)) * (0.25 + 0.75 * T.sstep(0.35, 0.95, v)), 0, 1)
    shade = 0.55 + 0.45 * T.sstep(0.02, 0.55, v)                        # dark at the roots, lighter up the blade
    green = np.dstack([46 + 26 * blade + 10 * nz, 68 + 40 * blade + 12 * nz, 34 + 18 * blade + 6 * nz]).astype(F32)
    palec = np.dstack([124 + 40 * blade2, 118 + 34 * blade2, 72 + 22 * blade2]).astype(F32)
    col = green * (1 - dry[..., None] * 0.85) + palec * (dry[..., None] * 0.85)
    col = col * shade[..., None] * (0.86 + 0.24 * blade[..., None])
    a = np.clip(col, 0, 255)
    soil = T.sstep(0.14, 0.0, v) * (0.45 + 0.55 * nz)
    a = T.blend(a, np.dstack([62 + 22 * nz, 56 + 18 * nz, 42 + 14 * nz]).astype(F32), soil * 0.75)
    r = np.clip(0.90 - 0.10 * T.sstep(0.3, 1.0, v) + 0.05 * (nz - 0.5), 0.55, 0.97)
    hgt = (blade - 0.5) * 0.0011 + (blade2 - 0.5) * 0.0008 + (nz - 0.5) * 0.0004
    n = T.height_normal_uv(hgt, ppm_u, ppm_v, 1.0)
    return np.clip(a, 30, 240), r, n, np.zeros(hw, F32)


CELLS = (("wall", wall), ("cope", cope), ("lichen", lichen), ("moss", moss), ("joint", joint), ("grass", grass))
SEEDS = {"wall": 100, "cope": 140, "lichen": 180, "moss": 220, "joint": 260, "grass": 300}


# ---------------------------------------------------------------------------------------------------- sheet
def build():
    alb = np.full((M, M, 3), 128.0, F32)
    rgh = np.full((M, M), 0.80, F32)
    nor = np.dstack([np.zeros((M, M), F32), np.zeros((M, M), F32), np.ones((M, M), F32)])
    met = np.zeros((M, M), F32)
    for cell, fn in CELLS:
        x0, y0, x1, y1 = L.region_px(cell, M)
        a, r, n, m = fn(x1 - x0, y1 - y0, SEEDS[cell])
        alb[y0:y1, x0:x1] = a
        rgh[y0:y1, x0:x1] = r
        nor[y0:y1, x0:x1] = n
        met[y0:y1, x0:x1] = m
        print("  %-7s %4d x %4d px  %.2f m x %.2f m  %.0f px/m" % (cell, x1 - x0, y1 - y0, L.CELL_M[cell][0],
                                                                  L.CELL_M[cell][1], (x1 - x0) / L.CELL_M[cell][0]))
    alb = np.clip(limit_sat(alb), 30, 238)
    rgh = np.clip(rgh, 0.40, 0.97)
    wa, wr = T.wet(alb, rgh, darken=0.34, gloss=0.34)                  # wet granite is much darker (05 4.2: #4E4C49)
    wa = np.clip(wa, 28, 232)
    wr = np.clip(wr, 0.16, 0.90)
    return alb, rgh, nor, met, wa, wr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT, help="shipping map folder")
    args = ap.parse_args()
    alb, rgh, nor, met, wa, wr = build()
    T.save_set(args.out, STEM, alb, rgh, nor, met=met, size=SHIP, wet_maps=(wa, wr), master_dir=MASTERS)
    print("wrote", STEM, "->", os.path.relpath(args.out, T.GAME), "masters", os.path.relpath(MASTERS, T.GAME))


if __name__ == "__main__":
    main()
