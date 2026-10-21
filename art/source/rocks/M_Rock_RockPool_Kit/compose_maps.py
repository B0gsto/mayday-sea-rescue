"""M_Rock_RockPool_Kit maps (system python3, no heavy slot): the pooltex.py bakes -> T_Pool_Granite_* (+ _Wet).

Albedo is graded to the 05 granite palette (#8A8781) from the K1 CC0 granite the outcrops are skinned with (the
scan's luma normalised, its macro patches dropped, its cracks and grain kept), then the intertidal zonation of a
Haven Sands pool rock, measured from the pool's own waterline (wl per variant; the "pool" bake gives the distance to
the pool shoreline d, in studs):
  - everything at and below the tide band is dark wet rock (albedo -30%, glossier), with wrack mats on the low
    seaward rock and green weed in the wet gutters;
  - a broken barnacle crust band around the pool level, denser and clumpier seaward, with sparse limpets in it;
  - green weed along the pool shoreline (|d| small) and just above the waterline;
  - a black Verrucaria band above the barnacles, then grey granite with grey crustose lichen and occasional yellow
    Xanthoria on the high up-facing rock, and a salt bloom on the driest tops;
  - inside the pool: pink coralline crust on the submerged rock, a pink waterline ring, silted floor.
Each variant's water square is painted from its analytic UV map (pool.json water_uv) as the pool bottom seen through
still water: coralline and weed mottling, silted and tinted teal (deeper = darker), barnacle specks in the shallows,
a bright meniscus ring, low roughness and a faint ripple normal. The _Wet set is the whole rock rain / spray wet.

  python3 art/source/rocks/M_Rock_RockPool_Kit/compose_maps.py [--out-root build/prod/M_Rock_RockPool_Kit] [--atlas 4096]
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
for p in (HERE, os.path.join(REPO, "tools/blender"), os.path.join(REPO, "art/source/rocks/_kit")):
    if p not in sys.path:
        sys.path.insert(0, p)
import names  # noqa: E402
import pbrmaps  # noqa: E402
import compose as K  # noqa: E402  (the K1 rock grading: granite(), fbm(), ss(), srgb(), lowpass())

NAME = "M_Rock_RockPool_Kit"
SET = "Granite"
TEX = "Pool"
WET_RGH = (0.24, 0.90)
CELL_JSON = 2048
ss = pbrmaps.smoothstep


def load(work, name, size, mode="RGB"):
    im = Image.open(os.path.join(work, name + ".png")).convert(mode)
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def mix(a, b, m, scale=1.0):
    m = (m * scale)[..., None] if a.ndim == 3 else m * scale
    return a * (1.0 - m) + b * m


def highpass(x, cells):
    if x.ndim == 3:
        return np.stack([x[..., i] - K.lowpass(x[..., i], cells) for i in range(x.shape[2])], axis=2)
    return x - K.lowpass(x, cells)


def sphere_normal(nx, ny):
    n = np.stack([nx, ny, np.ones_like(nx)], axis=2)
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)
    return n * 0.5 + 0.5


def cell_origin(pv, size, cell):
    """The array (top-down) origin of a variant's cell: pool.json rects are in bottom-up atlas px."""
    row, col = pv["cell_row"], pv["cell_col"]
    return size - (row + 1) * cell, col * cell


def rock_cell(pv, out, size, cell, passes):
    """One variant's granite and its intertidal zonation, written into the cell's slice of the atlas arrays."""
    P_NOR, P_POS, P_WN, P_SCAN, P_SNR, P_POOL, P_MASK = passes
    oy, ox = cell_origin(pv, size, cell)
    c = (slice(oy, oy + cell), slice(ox, ox + cell))
    alb, rgh, nor, met = out
    pos, wn = P_POS[c], P_WN[c]
    mask, geo, scan, snrm, pool = P_MASK[c], P_NOR[c], P_SCAN[c], P_SNR[c], P_POOL[c]
    ao, curv = mask[..., 0], mask[..., 1]
    w = np.stack([pv["lo"][i] + pos[..., i] * pv["span"][i] for i in range(3)], axis=2)
    z = w[..., 2]
    dx, dy = w[..., 0] - pv["centre"][0], w[..., 1] - pv["centre"][1]
    r = np.maximum(np.hypot(dx, dy), 1e-4)
    up = wn[..., 2]
    outf = np.clip((dx * (wn[..., 0] * 2 - 1) + dy * (wn[..., 1] * 2 - 1)) / r, -1.0, 1.0)
    d = (pool[..., 1] * 2.0 - 1.0) * 2.0                      # studs to the pool shoreline (+ outside)
    inpool = pool[..., 0] > 0.5
    wl = pv["wl"]
    seed = pv["seed"]
    covered = (geo[..., 2] > 0.05)

    # --- granite base (K1 grading) -----------------------------------------------
    L = pbrmaps.luma(scan)
    med = float(np.median(L[covered])) if covered.any() else 0.5
    Ln = np.clip(L / max(med, 1e-3), 0.35, 1.9)
    Ln = np.where(Ln > 1.0, 1.0 + 0.55 * (Ln - 1.0), Ln)
    a = K.granite(seed, Ln, covered) + 0.05 * highpass(scan - L[..., None], 24)
    a = a * (0.78 + 0.22 * ao)[..., None]
    a = a * (1.0 - 0.16 * np.clip((0.5 - curv) * 2.0, 0.0, 1.0))[..., None]
    a = np.clip(a * 1.15 + 0.02, 0.0, 1.0)                    # 05 granite #8A8781 sits at luma 0.54, not 0.42
    rl = np.clip(0.70 + 0.16 * K.fbm(seed + 5, [16, 64]) - 0.10 * (1.0 - ao), 0.56, 0.95)

    patch = K.fbm(seed + 2, [8, 16, 32, 64])
    patch2 = K.fbm(seed + 3, [12, 24, 48, 96])
    patch3 = K.fbm(seed + 8, [10, 20, 40, 80])
    speck = K.fbm(seed + 4, [384, 768], [0.4, 0.6])
    speck2 = K.fbm(seed + 7, [160, 320], [0.5, 0.5])
    zoff = 0.20 * (patch - 0.5)
    wrack, barn = K.srgb("#52502C") * 1.02, K.srgb("#B8B2A4")
    limpet, black_l, grey_l = K.srgb("#9C988C"), K.srgb("#3E3D3A"), K.srgb("#959B8C")
    xan, salt_c = K.srgb("#B27E4C"), K.srgb("#D9D6CC")
    coralline, coralline_b = K.srgb("#9A7370"), K.srgb("#A87F77")
    weed_a, weed_b, silt = K.srgb("#4E5A26"), K.srgb("#3F4A22"), K.srgb("#5C574C")

    # --- the tide band and below: dark wet rock, wrack, weed in the gutters ------
    wet = np.clip(1.0 - ss(wl + 0.10, wl + 0.55, z + zoff)
                  + 0.22 * ss(0.45, 0.85, outf) * (1.0 - ss(wl + 0.5, wl + 1.1, z)), 0.0, 1.0)
    a_w, r_w = pbrmaps.wet(a, rl, darken=0.24, gloss=0.50)
    a = mix(a, a_w, wet)
    rl = mix(rl, np.clip(r_w, *WET_RGH), wet)
    wm = ss(0.46, 0.62, patch * 0.7 + 0.3 * (1.0 - ss(0.0, wl + 0.4, z))) \
        * (1.0 - ss(wl - 0.10, wl + 0.20, z + zoff)) * ss(0.10, 0.55, d) * 0.8
    a = mix(a, wrack[None, None, :] * (0.8 + 0.4 * patch2[..., None]), wm)
    rl = mix(rl, np.full_like(rl, 0.28), wm)
    gut = ss(0.70, 0.80, patch3) * (1.0 - ss(wl + 0.1, wl + 0.5, z)) * ss(0.15, 0.60, outf) * 0.35
    a = mix(a, weed_b[None, None, :] * (0.85 + 0.3 * speck[..., None]), gut)
    rl = mix(rl, np.full_like(rl, 0.34), gut)

    # --- barnacle crust and limpets around the pool level, denser seaward --------
    band = ss(wl + 0.05, wl + 0.30, z + zoff) * (1.0 - ss(wl + 1.5, wl + 2.1, z + 0.25 * (patch2 - 0.5)))
    gate = ss(0.10, 0.60, d)
    clump = ss(0.40, 0.62, patch2 * 0.8 + 0.2 * outf)
    a = mix(a, barn[None, None, :] * 0.95, band * gate * clump, 0.26)
    rl = mix(rl, np.full_like(rl, 0.88), band * gate * clump, 0.26)
    dots = ss(0.50, 0.63, speck) * band * gate * (0.45 + 0.55 * clump)
    a = mix(a, barn[None, None, :] * (0.85 + 0.30 * speck[..., None]), dots)
    rl = mix(rl, np.full_like(rl, 0.88), dots)
    lp = ss(0.74, 0.86, speck2) * band * gate * ss(0.45, 0.70, patch2)
    a = mix(a, limpet[None, None, :] * (0.88 + 0.2 * speck2[..., None]), lp)
    rl = mix(rl, np.full_like(rl, 0.80), lp)

    # --- green weed at the pool shoreline ---------------------------------------
    wg = np.exp(-0.5 * (d / 0.38) ** 2) * ss(wl - 0.30, wl, z + zoff) * (1.0 - ss(wl + 0.7, wl + 1.1, z))
    wg = wg * (0.30 + 0.70 * ss(0.44, 0.62, patch3 * 0.8 + 0.2 * speck))
    a = mix(a, weed_a[None, None, :] * (0.85 + 0.3 * speck[..., None]), wg)
    rl = mix(rl, np.full_like(rl, 0.30), wg)

    # --- the pool: coralline crust, waterline ring, silted floor ----------------
    cr = inpool * (1.0 - ss(wl - 0.02, wl + 0.12, z)) * ss(0.40, 0.60, patch2 * 0.7 + 0.3 * up)
    a = mix(a, coralline[None, None, :] * (0.85 + 0.3 * speck[..., None]), cr, 0.45)
    rl = mix(rl, np.full_like(rl, 0.72), cr, 0.5)
    ring = np.exp(-0.5 * (d / 0.26) ** 2) * (1.0 - ss(wl + 0.05, wl + 0.40, z)) * ss(0.25, 0.55, patch2)
    a = mix(a, coralline_b[None, None, :] * (0.9 + 0.2 * speck[..., None]), ring, 0.72)
    rl = mix(rl, np.full_like(rl, 0.70), ring, 0.5)
    sil = inpool * (1.0 - ss(wl - 0.35, wl - 0.05, z)) * ss(0.40, 0.60, patch)
    a = mix(a, silt[None, None, :] * (0.9 + 0.2 * speck[..., None]), sil, 0.35)
    rl = mix(rl, np.full_like(rl, 0.55), sil, 0.4)

    # --- black band above, then lichens and a salt bloom on the high rock -------
    vb = ss(wl + 0.85, wl + 1.35, z + zoff) * (1.0 - ss(wl + 2.3, wl + 3.1, z + 0.5 * (patch - 0.5))) \
        * ss(0.34, 0.54, patch2)
    a = mix(a, black_l[None, None, :], vb, 0.75)
    rl = mix(rl, np.full_like(rl, 0.62), vb, 0.8)
    high = ss(wl + 1.8, wl + 3.0, z)
    upm = ss(0.35, 0.85, up)
    xm = 0.6 * ss(0.78, 0.84, patch * 0.6 + speck * 0.25 + upm * 0.25) * high * upm
    gm = 0.85 * ss(0.55, 0.68, patch2 * 0.6 + speck * 0.4) * high * (0.3 + 0.7 * upm) * (1.0 - xm)
    a = mix(a, xan[None, None, :] * (0.85 + 0.25 * speck[..., None]), xm)
    a = mix(a, grey_l[None, None, :] * (0.9 + 0.2 * speck[..., None]), gm, 0.8)
    rl = np.clip(mix(rl, np.full_like(rl, 0.9), xm + gm * 0.8), 0.2, 0.98)
    a = mix(a, salt_c[None, None, :] * 0.92, ss(0.60, 0.78, patch3) * ss(0.70, 0.95, upm) * high, 0.06)

    # --- normal: the geometry plus the scan's fine relief ----------------------
    g = geo * 2.0 - 1.0
    det = highpass(snrm[..., :2], 12) * 2.0
    n = np.concatenate([g[..., :2] + 0.30 * det, np.ones_like(g[..., :1])], axis=2)
    n /= np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6)

    a = pbrmaps.limit_saturation(np.clip(a, 0.0, 1.0), 0.42)[0]
    alb[c] = np.clip(a, 34 / 255, 214 / 255)
    rgh[c] = np.clip(rl, 0.2, 0.98)
    nor[c] = n * 0.5 + 0.5
    met[c] = 0.0
    return np.ones((cell, cell), bool)                         # the recipe covers the whole cell


def water_cell(pv, out, size, cell):
    """The pool water square: the bottom seen through still water; exact pattern from pool.json water_uv."""
    alb, rgh, nor, met = out
    oy, ox = cell_origin(pv, size, cell)
    wr = [v * (cell / float(CELL_JSON)) for v in pv["water_rect"]]   # cell-local px (json rects are in CELL_JSON px)
    x0, y0, x1, y1 = [int(round(v)) for v in wr]              # cell-local px, y up
    ya, yb = oy + cell - y1, oy + cell - y0
    xa, xb = ox + x0, ox + x1
    h, w = yb - ya, xb - xa
    j0, j1 = cell - y1, cell - y0                             # the square's rows/cols inside the cell
    seed = pv["seed"]
    uu = (x0 + np.arange(w)[None, :] + 0.5) / cell            # cell uv of each texel in the square
    vv = (y1 - np.arange(h)[:, None] - 0.5) / cell
    cu, cv = pv["water_uv"]["centre"]
    k = pv["water_uv"]["per_stud"]                            # cell uv per pre-transform stud
    xy_u = (uu - cu) / k
    xy_v = (vv - cv) / k
    r = np.maximum(np.hypot(xy_u, xy_v), 1e-4)
    th = np.arctan2(xy_v, xy_u)
    tbl = np.array(pv["water_uv"]["r"], np.float64)
    th_t = np.linspace(-np.pi, np.pi, len(tbl), endpoint=False)
    r_edge = np.interp(th, np.concatenate([th_t - 2 * np.pi, th_t, th_t + 2 * np.pi]),
                       np.concatenate([tbl, tbl, tbl]))
    rr = r / np.maximum(r_edge, 1e-4)
    inside = rr <= 1.0
    speck = K.fbm(seed + 31, [384, 768], [0.4, 0.6])[j0:j1, x0:x1]
    speck2 = K.fbm(seed + 32, [140, 280], [0.5, 0.5])[j0:j1, x0:x1]
    pat = K.fbm(seed + 33, [10, 20, 40, 80])[j0:j1, x0:x1]
    pat2 = K.fbm(seed + 34, [24, 48, 96])[j0:j1, x0:x1]
    coralline, weed, dark = K.srgb("#9A7370"), K.srgb("#3E4A2C"), K.srgb("#4A4741")
    bottom = np.zeros((h, w, 3), np.float32) + dark[None, None, :]
    soft = K.fbm(seed + 36, [24, 48, 96], [0.5, 0.3, 0.2])[j0:j1, x0:x1]
    bottom = mix(bottom, coralline[None, None, :] * (0.9 + 0.2 * soft[..., None]),
                 ss(0.40, 0.60, pat * 0.6 + soft * 0.4), 0.70)
    bottom = mix(bottom, weed[None, None, :] * (0.9 + 0.2 * soft[..., None]),
                 ss(0.55, 0.74, pat2 * 0.7 + soft * 0.3), 0.55)
    depth = 0.55 + 0.45 * (1.0 - np.clip(rr, 0.0, 1.0) ** 2)
    a = mix(bottom, K.srgb("#24463E")[None, None, :], np.clip(0.44 + 0.20 * depth, 0.0, 1.0))
    a = mix(a, K.srgb("#3E6A5E")[None, None, :], ss(0.70, 1.0, rr), 0.26)
    a = mix(a, K.srgb("#A29D90")[None, None, :] * (0.8 + 0.3 * speck[..., None]),
            ss(0.70, 0.84, speck2) * ss(0.72, 1.0, rr), 0.30)
    ring = np.exp(-0.5 * ((rr - 0.94) / 0.055) ** 2)
    a = mix(a, K.srgb("#7C9A94")[None, None, :], ring, 0.30)
    lip = (~inside).astype(np.float32)
    a = mix(a, K.srgb("#4E4C49")[None, None, :] * (0.8 + 0.3 * speck[..., None]), lip)
    r = 0.10 + 0.05 * pat + 0.06 * ss(0.6, 1.0, rr)
    r = mix(r, np.full_like(r, 0.30), lip)
    r = mix(r, np.full_like(r, 0.20), ring, 0.5)
    a = pbrmaps.limit_saturation(np.clip(a, 0.0, 1.0), 0.42)[0]
    alb[ya:yb, xa:xb] = np.clip(a, 34 / 255, 214 / 255)
    rgh[ya:yb, xa:xb] = np.clip(r, 0.2, 0.95)
    hf = K.fbm(seed + 35, [90, 180, 360], [0.5, 0.3, 0.2])[j0:j1, x0:x1]
    gy, gx = np.gradient(hf)
    n = sphere_normal(-gx * 46.0, -gy * 46.0)
    curl = ss(0.86, 1.0, rr) * (1.0 - ss(1.0, 1.04, rr))
    n = mix(n, sphere_normal((xy_u) * curl * 1.2, (xy_v) * curl * 1.2), curl, 0.7)
    flat = np.zeros((h, w, 3), np.float32) + 0.5
    flat[..., 2] = 1.0
    n = mix(n, flat, lip, 0.85)
    nor[ya:yb, xa:xb] = n
    met[ya:yb, xa:xb] = 0.0


def main():
    ap = argparse.ArgumentParser(prog="compose_maps.py")
    ap.add_argument("--out-root", default=os.path.join(REPO, "build/prod", NAME))
    ap.add_argument("--atlas", type=int, default=4096)
    args = ap.parse_args()
    out_root = os.path.abspath(args.out_root)
    work = os.path.join(out_root, "work")
    size = args.atlas
    cell = size // 2
    pools = json.load(open(os.path.join(HERE, "pool.json")))
    global CELL_JSON
    CELL_JSON = pools["cell"]
    s = cell / float(CELL_JSON)                               # pool.json cell px -> this run's cell px
    K.N = cell

    P_NOR = load(work, "nor", size)
    P_MASK = load(work, "mask", size, "RGBA")
    P_POS = load(work, "pos", size)
    P_WN = load(work, "wn", size)
    P_SCAN = load(work, "scan_alb", size)
    P_SNR = load(work, "scan_nrm", size)
    P_POOL = load(work, "pool", size, "RGBA")
    passes = (P_NOR, P_POS, P_WN, P_SCAN, P_SNR, P_POOL, P_MASK)

    alb = np.zeros((size, size, 3), np.float32)
    rgh = np.zeros((size, size), np.float32)
    nor = np.zeros((size, size, 3), np.float32)
    met = np.zeros((size, size), np.float32)
    out = (alb, rgh, nor, met)
    mapped = np.zeros((size, size), bool)
    for pv in pools["variants"]:
        oy, ox = cell_origin(pv, size, cell)
        wr = [int(round(v * s)) for v in pv["water_rect"]]
        rock = rock_cell(pv, out, size, cell, passes)
        mapped[oy:oy + cell, ox:ox + cell] |= rock
        water_cell(pv, out, size, cell)
        ya, yb = oy + cell - wr[3], oy + cell - wr[1]
        mapped[ya:yb, ox + wr[0]:ox + wr[2]] = True

    # any texel the recipe did not reach (normally none: the cells tile the atlas): flat granite
    if not mapped.all():
        mid = np.zeros((size, size, 3), np.float32) + K.srgb("#8A8781")[None, None, :] * 0.92
        alb[...] = np.where(mapped[..., None], alb, mid)
        rgh[...] = np.where(mapped, rgh, np.full_like(rgh, 0.80))
        flat = np.zeros_like(nor) + 0.5
        flat[..., 2] = 1.0
        nor[...] = np.where(mapped[..., None], nor, flat)
        print("[compose] %d texels had no recipe (filled flat)" % int((~mapped).sum()))

    a_wet, r_wet = pbrmaps.wet(alb, rgh, darken=0.30, gloss=0.35)
    a_wet = np.clip(a_wet, 32 / 255, 232 / 255)
    r_wet = np.clip(r_wet, *WET_RGH)
    for pv in pools["variants"]:                              # the water stays glassy in the wet set
        oy, ox = cell_origin(pv, size, cell)
        wr = [int(round(v * s)) for v in pv["water_rect"]]
        ya, yb = oy + cell - wr[3], oy + cell - wr[1]
        r_wet[ya:yb, ox + wr[0]:ox + wr[2]] = np.clip(rgh[ya:yb, ox + wr[0]:ox + wr[2]] - 0.02, 0.07, 0.22)

    stem = "T_%s_%s_" % (TEX, SET)
    edir = os.path.join(out_root, "textures", NAME)
    mdir = os.path.join(out_root, "masters", NAME)
    os.makedirs(edir, exist_ok=True)
    os.makedirs(mdir, exist_ok=True)
    maps = {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met, "ALB_Wet": a_wet, "RGH_Wet": r_wet}
    for k, arr in maps.items():
        for d in (mdir, edir):
            pbrmaps.write_png(os.path.join(d, stem + k + ".png"), arr)
    print("[compose] %d maps at %d px -> %s" % (len(maps), size, os.path.relpath(edir, REPO)))
    for k in ("ALB", "NOR", "RGH", "MET"):
        arr = maps[k].reshape(-1, 1) if maps[k].ndim == 2 else maps[k].reshape(-1, maps[k].shape[2])
        print("[compose]   %-8s mean %s min %.3f max %.3f" % (k, arr.mean(0).round(3), maps[k].min(), maps[k].max()))
    assert names.texture_name_problem(stem + "ALB") is None


if __name__ == "__main__":
    main()
