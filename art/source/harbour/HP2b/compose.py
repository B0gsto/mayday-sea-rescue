"""HP2b map composer (pure numpy; runs inside Blender's Python or system python3).

Input: the G-buffer npz from buoylib.bake_gbuffer (object-space position in metres, normal, part id, Cycles pointiness,
AO; rows bottom-up as Blender stores them). Output: T_<Tex>_Buoy_ALB / NOR / RGH / MET + ALB_Wet / RGH_Wet,
2048 masters in art/source/harbour/<Asset>/textures/, EXPORT size maps in assets/textures/<Asset>/, and
signal_mask.png (IALA paint + lens) next to build.py for check_textures.py.

CC0 detail (Poly Haven, build/materials/src/<id>/, 2k, triplanar from object position):
  rusty_painted_metal  paint grain, flaking and roughness     https://polyhaven.com/a/rusty_painted_metal
  rust_coarse_01       rust streak / chip / chain colour       https://polyhaven.com/a/rust_coarse_01
  metal_plate_02       galvanised steel grain                  https://polyhaven.com/a/metal_plate_02
  low_tide_rocks       wrack and weed colour for the fouling   https://polyhaven.com/a/low_tide_rocks
Weathering: faded / chalked enamel, edge chips to primer and rust, rust streaks under every seam and weld line, gull
droppings on up-facing tops with drips, rust bleeding from every cage joint, salt film above the waterline, a graded fouling zone (slime film, patchy algae, wrack mat)
and barnacles + fouling below it.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import marks  # noqa: E402
import pbrmaps  # noqa: E402

SCANS = os.path.join(REPO, "build", "materials", "src")
SHIP = int(os.environ.get("HP2B_SHIP", "1024"))
P_BODY, P_FENDER, P_CAGE, P_LENS, P_LAMP, P_SOLAR, P_GALV, P_BELL, P_TOP, P_CHAIN, P_ROPE = range(11)


def load_img(path):
    try:
        from PIL import Image
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    except ImportError:
        import bpy
        img = bpy.data.images.load(path, check_existing=True)
        w, h = img.size
        a = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        bpy.data.images.remove(img)
        return a.reshape(h, w, 4)[..., :3]


_scan_cache = {}


def scan(pid, kind="diff"):
    key = (pid, kind)
    if key not in _scan_cache:
        _scan_cache[key] = load_img(os.path.join(SCANS, pid, "%s_2k.png" % kind))
    return _scan_cache[key]


def tri(img, pos, nrm, tile):
    """Triplanar nearest sample of a tiling scan (tile = metres per repeat)."""
    h, w = img.shape[:2]
    wts = np.abs(nrm) ** 4
    wts /= np.maximum(wts.sum(axis=1, keepdims=True), 1e-6)
    out = 0.0
    for k, (a, b) in enumerate(((1, 2), (0, 2), (0, 1))):
        u = ((pos[:, a] / tile) % 1.0 * w).astype(np.int32) % w
        v = ((pos[:, b] / tile + 0.37 * k) % 1.0 * h).astype(np.int32) % h
        out = out + img[v, u] * wts[:, k:k + 1]
    return out


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = h & 0xFFFFFFFF
    h = h ^ (h >> 13)
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h = h ^ (h >> 15)
    return (h & 0xFFFFFF).astype(np.float32) / float(0xFFFFFF)


def vnoise(q, seed):
    i = np.floor(q).astype(np.int64)
    f = (q - i).astype(np.float32)
    f = f * f * (3.0 - 2.0 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wgt = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + wgt * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(pos, freq, seed, octaves=4, stretch=(1.0, 1.0, 1.0)):
    q = pos * np.asarray(stretch, dtype=np.float32) * freq
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * vnoise(q * (2.0 ** o) + 17.3 * o, seed + 31 * o)
        norm += amp
        amp *= 0.5
    return total / norm


def ss(e0, e1, x):
    t = np.clip((x - e0) / np.maximum(np.asarray(e1, np.float32) - e0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = np.asarray(t, dtype=np.float32)
    if t.ndim == 1 and (np.shape(a)[-1:] == (3,) or np.shape(b)[-1:] == (3,)) and len(t) != 3:
        t = t[:, None]
    return a * (1.0 - t) + b * t


def luma(c):
    return c[:, 0] * 0.2126 + c[:, 1] * 0.7152 + c[:, 2] * 0.0722


def paint_colour(kind, z, ang, n):
    if kind in marks.MOORINGS:
        return np.tile(np.asarray(marks.MOORINGS[kind]["colour"], np.float32), (n, 1))
    bands = marks.NAVMARKS[kind]["bands"]
    if bands == "stripes":
        idx = np.floor((ang / (2 * np.pi) + 0.5) * marks.STRIPES + 0.5).astype(np.int32) % 2
        return np.where(idx[:, None] == 0, np.asarray(marks.RED, np.float32), np.asarray(marks.WHITE, np.float32))
    out = np.zeros((n, 3), np.float32)
    for lo, hi, col in bands:
        sel = (z >= lo) & (z < hi)
        out[sel] = col
    return out


def compose(kind, info, gb_path, src_dir, out_dir, tex, ship=SHIP):
    g = np.load(gb_path)
    cov = g["covered"] & ~np.all(np.abs(g["pos"].astype(np.float32) + 5.0) < 1e-3, axis=2)   # bake alpha is 1 everywhere
    H, W = cov.shape
    sel = cov.ravel()
    pos = g["pos"].reshape(-1, 3)[sel].astype(np.float32)
    nrm = g["nrm"].reshape(-1, 3)[sel].astype(np.float32)
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-6)
    part = g["part"].ravel()[sel]
    curv = g["curv"].ravel()[sel].astype(np.float32)
    ao = np.clip(g["ao"].ravel()[sel].astype(np.float32), 0, 1)
    n = len(pos)
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    nz = nrm[:, 2]
    ang = np.arctan2(y, x)
    navmark = kind in marks.NAVMARKS
    cfg = marks.NAVMARKS.get(kind, {})
    is_ = lambda *ps: np.isin(part, ps)

    # --- noise fields
    n_fade = fbm(pos, 2.5, 1)
    n_chip = fbm(pos, 14.0, 2, 3)
    n_streak = fbm(pos, 9.0, 3, 3, stretch=(1.6, 1.6, 0.07))
    n_blob = fbm(pos, 6.0, 4, 4)
    n_fine = fbm(pos, 40.0, 5, 2)
    n_edge = fbm(pos, 3.5, 6, 3)
    n_barn = fbm(pos, 34.0, 7, 2)

    paint_scan = tri(scan("rusty_painted_metal"), pos, nrm, 1.1)
    paint_l = luma(paint_scan)
    paint_r = paint_l / max(float(np.median(paint_l)), 1e-3)
    rust_col = tri(scan("rust_coarse_01"), pos, nrm, 0.9)
    rust_col = mix(rust_col, rust_col.mean(axis=1, keepdims=True), 0.25) * 0.95
    weed_col = tri(scan("low_tide_rocks"), pos, nrm, 1.4)
    plate_l = luma(tri(scan("metal_plate_02"), pos, nrm, 0.8))

    alb = np.zeros((n, 3), np.float32)
    rgh = np.full(n, 0.6, np.float32)
    met = np.zeros(n, np.float32)
    hgt = np.zeros(n, np.float32)

    # --- base materials
    painted = is_(P_BODY, P_CAGE, P_TOP)
    pc = paint_colour(kind, z, ang, n)
    if navmark:
        # topmarks a step lighter than the bands (fresh repaint, and they sit against the sky) so black reads as paint
        pc[part == P_TOP] = np.asarray(cfg["top_col"], np.float32) * 1.18
    alb[:] = pc
    # faded, chalked enamel: sun side (up-facing) more, scan grain
    chalk = np.clip(0.18 + 0.30 * n_fade + 0.18 * np.clip(nz, 0, 1), 0, 0.7)
    alb = mix(alb, alb * 0.82 + 0.16 * np.array([0.80, 0.79, 0.76], np.float32), chalk)
    alb *= (0.86 + 0.14 * np.clip(paint_r, 0.4, 1.6))[:, None]
    rgh[:] = 0.48 + 0.25 * chalk + 0.08 * (paint_r - 1.0)
    hgt += 0.0004 * (paint_l - paint_l.mean())

    fender = part == P_FENDER
    alb[fender] = mix(np.array([0.17, 0.17, 0.165]), np.array([0.32, 0.31, 0.30]), ss(0.55, 0.8, n_chip[fender]))
    rgh[fender] = 0.82

    lamp = part == P_LAMP
    alb[lamp] = np.array([0.21, 0.22, 0.23]) * (0.9 + 0.2 * n_fine[lamp, None])
    rgh[lamp] = 0.45

    solar = part == P_SOLAR
    grid = ((np.abs(((x + y) * 25.0) % 1.0 - 0.5) < 0.06) | (np.abs((z * 25.0) % 1.0 - 0.5) < 0.06))
    alb[solar] = np.where(grid[solar, None], np.array([0.42, 0.43, 0.45]), np.array([0.13, 0.15, 0.20]))
    rgh[solar] = 0.14

    lens = part == P_LENS
    if navmark:
        lc = np.asarray(marks.LENS[cfg["lens"]], np.float32)
        alb[lens] = lc * (0.92 + 0.08 * np.cos(z[lens] * 2 * np.pi / 0.033))[:, None]
        rgh[lens] = 0.10

    galv = is_(P_GALV)
    alb[galv] = np.array([0.74, 0.745, 0.73]) * (0.92 + 0.10 * plate_l[galv, None])
    rgh[galv] = 0.42 + 0.2 * n_fine[galv]
    met[galv] = 1.0
    white_rust = galv & (n_blob > 0.58)
    alb[white_rust] = np.array([0.80, 0.80, 0.77])
    met[white_rust] = 0.0
    rgh[white_rust] = 0.88

    bell = part == P_BELL
    alb[bell] = np.array([0.75, 0.60, 0.42])
    met[bell] = 1.0
    rgh[bell] = 0.35
    verd = bell & (n_blob > 0.52)
    alb[verd] = mix(np.array([0.42, 0.55, 0.48]), np.array([0.50, 0.58, 0.52]), n_fine[verd])
    met[verd] = 0.0
    rgh[verd] = 0.85

    chain = part == P_CHAIN
    alb[chain] = rust_col[chain] * 0.9
    rgh[chain] = 0.86
    bright = chain & (n_chip > 0.62) & (curv > 0.5)
    alb[bright] = np.array([0.72, 0.71, 0.69])
    met[bright] = 1.0
    rgh[bright] = 0.5
    hgt[chain] += 0.0008 * n_fine[chain]

    rope = part == P_ROPE
    strand = 0.5 + 0.5 * np.sin((z + ang * 0.02) * 2 * np.pi / 0.02)
    alb[rope] = np.array([0.72, 0.70, 0.62]) * (0.85 + 0.15 * strand[rope, None])
    rgh[rope] = 0.9
    hgt[rope] += 0.0006 * strand[rope]

    # --- paint wear: edge chips to primer / rust, flake patches
    chip = painted & (ss(0.52, 0.60, curv) * ss(0.42, 0.62, n_chip) > 0.35)
    flake = painted & (ss(0.66, 0.72, n_blob * 0.6 + n_chip * 0.4) > 0.5)
    worn = chip | flake
    alb[worn] = mix(rust_col[worn], np.array([0.42, 0.40, 0.37]), 0.25 * (n_fine[worn] > 0.5))
    rgh[worn] = 0.85
    hgt[worn] -= 0.0004

    # --- rust streaks under seams (sources: deck edge, hoops, platform underside, lantern base, fender top)
    rust = np.zeros(n, np.float32)
    vertical = 1.0 - ss(0.55, 0.85, np.abs(nz))
    for hs in info["rust_heights"]:
        below = hs - z
        m = np.where(below > 0, np.exp(-below / 0.42) * ss(0.0, 0.03, below), 0.0)
        rust = np.maximum(rust, m)
    rust = rust * ss(0.52, 0.72, n_streak) * vertical
    # HP2b-fix: point-source streaks under every cage joint (hoop / brace / platform welds down the legs; foot welds
    # and lifting lugs across the deck and down the float), widening and breaking up as they run
    rxy = np.sqrt(x * x + y * y)
    for j, jt in enumerate(info.get("joints", [])):
        below = jt["z"] - z
        L = 0.30 + 0.35 * ((j * 0.6180339) % 1.0)
        if jt["mode"] == "leg":
            p0, p1 = np.asarray(jt["p0"], np.float32), np.asarray(jt["p1"], np.float32)
            t = np.clip((z - p0[2]) / (p1[2] - p0[2]), 0.0, 1.0)
            lx, ly = p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t
            d = np.sqrt((x - lx) ** 2 + (y - ly) ** 2)
            w = 0.05 + 0.04 * np.clip(below, 0, 1)
            near = (d < 0.09) & (z > p0[2] - 0.02)
            vert = np.ones(n, np.float32)
        else:
            da = np.abs((ang - jt["a"] + np.pi) % (2 * np.pi) - np.pi)
            d = da * rxy
            w = 0.025 + 0.06 * np.clip(below, 0, 1)
            near = rxy > jt["r0"]
            vert = 0.6 + 0.4 * vertical
        m = np.where((below > -0.01) & near, np.exp(-np.clip(below, 0, None) / L) * np.exp(-(d / w) ** 2), 0.0)
        m = m * (0.45 + 0.55 * ss(0.38, 0.70, n_streak)) * vert
        rust = np.maximum(rust, m * 1.15)
    rust = np.where(is_(P_BODY, P_CAGE, P_TOP, P_GALV, P_FENDER), rust, 0.0)
    rust = rust * ss(marks.WEED_TOP - 0.02, marks.WEED_TOP + 0.20, z)
    rust = np.clip(rust * 1.4, 0, 0.85)
    alb = mix(alb, rust_col, rust)
    rgh = mix(rgh, np.full(n, 0.82, np.float32), rust)
    met = np.where(rust > 0.4, 0.0, met)
    hgt += 0.0003 * rust

    # --- gull droppings on up-facing tops (heavier high up), with drips over the edges
    up = ss(0.45, 0.85, nz) * (z > 0.35)
    height_w = np.clip(0.55 + 0.45 * (z - 0.4) / max(info["top_z"] - 0.4, 0.5), 0.4, 1.0)
    blobs = ss(0.47, 0.60, n_blob) + 0.6 * ss(0.68, 0.74, n_fine)
    drop = np.clip(up * blobs * height_w, 0, 1)
    drip = np.zeros(n, np.float32)
    for ht in info["drop_tops"]:
        below = ht - z
        drip = np.maximum(drip, np.where((below > 0) & (below < 0.35), (1 - below / 0.35), 0.0) * ss(0.70, 0.80, n_streak))
    drip *= vertical * (z > 0.2)
    drop = np.clip(drop + 0.8 * drip, 0, 1)
    drop = np.where(is_(P_SOLAR), drop * 0.5, drop)
    gull = mix(np.array([0.86, 0.85, 0.80], np.float32), np.array([0.55, 0.56, 0.50], np.float32), ss(0.4, 0.8, n_fine)[:, None] * 0.35)
    alb = mix(alb, gull, drop)
    rgh = mix(rgh, np.full(n, 0.92, np.float32), drop)
    met = np.where(drop > 0.5, 0.0, met)
    hgt += 0.0006 * drop

    # --- salt film and the green slime fringe above the waterline
    salt = np.where((z > 0) & (z < 0.45), (1 - z / 0.45) * (0.25 + 0.4 * n_edge), 0.0) * (part != P_LENS)
    alb = mix(alb, np.array([0.74, 0.75, 0.70], np.float32), np.clip(salt, 0, 0.6))
    rgh = mix(rgh, np.full(n, 0.85, np.float32), np.clip(salt, 0, 0.6))

    # HP2b-fix: graded fouling zone instead of one hard weed line. From the top down: a thin translucent slime film in
    # the splash zone, patchy bright-green algae tufts that thicken towards the waterline, a solid olive-brown wrack
    # mat below it, then dark fouling with barnacles whose density ramps up with depth. Every boundary is noise-broken.
    edge = marks.WEED_TOP + 0.07 * (n_edge - 0.5) * 2.0 + 0.03 * (n_fine - 0.5)
    patch = 0.6 * n_blob + 0.4 * n_chip
    notlens = (part != P_LENS).astype(np.float32)
    film = (1.0 - ss(edge - 0.02, edge + 0.22 + 0.06 * n_edge, z)) * (0.25 + 0.35 * n_fade) * notlens
    alb = mix(alb, np.array([0.30, 0.36, 0.20], np.float32), np.clip(film, 0, 0.45))
    rgh = mix(rgh, np.full(n, 0.50, np.float32), np.clip(film, 0, 0.45))
    depth = (edge + 0.06 - z) / 0.42
    weed = ss(0.10, 0.75, depth + 0.9 * (patch - 0.5)) * notlens
    wc = weed_col * np.array([0.80, 0.92, 0.70], np.float32) * 0.85
    wc = mix(wc, np.array([0.16, 0.20, 0.11], np.float32), 0.35 * ss(0.3, 0.7, n_blob))
    young = np.array([0.24, 0.38, 0.13], np.float32) * (0.85 + 0.3 * n_fine[:, None])
    wcz = mix(young, wc, ss(0.1, 0.9, depth + 0.3 * (n_edge - 0.5)))
    wcz = mix(wcz, wcz * 0.72, ss(0.9, 1.6, depth))
    alb = mix(alb, wcz, weed)
    rgh = mix(rgh, np.full(n, 0.42, np.float32), weed)
    met = np.where(weed > 0.5, 0.0, met)
    hgt += weed * (0.0018 * n_fine + 0.0012 * n_blob)

    deep = (1.0 - ss(marks.WEED_BOTTOM - 0.30, marks.WEED_BOTTOM + 0.25 + 0.15 * n_edge, z)) * notlens
    dens = np.clip((edge - 0.05 - z) / 0.6, 0.0, 1.0)
    thr = 0.73 - 0.12 * dens
    barn = np.where(dens > 0, ss(thr, thr + 0.06, n_barn), 0.0) * notlens
    fouled = mix(wc * 0.8, np.array([0.30, 0.29, 0.24], np.float32), 0.4 * ss(0.4, 0.7, n_blob)[:, None])
    alb = mix(alb, fouled, deep * 0.85)
    barnc = mix(np.array([0.70, 0.69, 0.63], np.float32), np.array([0.52, 0.50, 0.45], np.float32), n_fine)
    alb = mix(alb, barnc, barn)
    rgh = mix(rgh, np.full(n, 0.85, np.float32), barn)
    hgt += 0.004 * barn + 0.0015 * deep * n_blob

    # --- AO, albedo range (05 / 12 1.4a: 20 to 240 sRGB, metal 180 to 250), saturation outside the signal mask
    alb *= np.where(part == P_TOP, 0.80 + 0.20 * ao, 0.62 + 0.38 * ao)[:, None]
    metal = met > 0.5
    y_ = luma(alb)
    lo = np.where(metal, 0.735, 0.135)
    hi = np.where(metal, 0.96, 0.92)
    alb *= (np.clip(y_, lo, hi) / np.maximum(y_, 1e-4))[:, None]
    alb = np.clip(alb, 0.0, 1.0)
    mx = alb.max(axis=1)
    sat = (mx - alb.min(axis=1)) / np.maximum(mx, 1e-6)
    signal = ((painted & (sat > 0.25) & (weed < 0.5) & (rust < 0.4) & (drop < 0.5)) | lens)
    lim, _ = pbrmaps.limit_saturation(alb[None], 0.40)
    alb = np.where(signal[:, None], alb, lim[0])

    # --- scatter back to the full map; the bake margin is in `covered`, the rest gets neutral fill
    def full(vals, fill):
        shape = (H * W,) + vals.shape[1:]
        out = np.empty(shape, np.float32)
        out[:] = fill
        out[sel] = vals
        return out.reshape((H, W) + vals.shape[1:])

    A = full(alb, np.array([0.45, 0.45, 0.44], np.float32))
    R = full(np.clip(rgh, 0.05, 1.0), 0.6)
    M = full(met, 0.0)
    Hm = full(hgt, 0.0)
    SIG = full(signal.astype(np.float32), 0.0)
    P = g["pos"].astype(np.float32)
    # tangent-space normal from the UV-space height gradient (tangent = +U, bitangent = +V; rows are bottom-up = +V)
    tex_m = np.linalg.norm(np.gradient(P, axis=1), axis=2)
    tex_m = np.where(cov, tex_m, np.nan)
    med = np.nanmedian(tex_m)
    tex_m = np.where(np.isfinite(tex_m) & (tex_m < 3 * med) & (tex_m > 0.05 * med), tex_m, med)
    dhdu = np.gradient(Hm, axis=1) / tex_m
    dhdv = np.gradient(Hm, axis=0) / tex_m
    seam = ~cov | (np.linalg.norm(np.gradient(P, axis=0), axis=2) > 4 * med) | (np.linalg.norm(np.gradient(P, axis=1), axis=2) > 4 * med)
    dhdu[seam] = 0.0
    dhdv[seam] = 0.0
    Nn = np.dstack([-np.clip(dhdu, -1.5, 1.5), -np.clip(dhdv, -1.5, 1.5), np.ones_like(dhdu)])
    Nn /= np.linalg.norm(Nn, axis=2, keepdims=True)
    NOR = Nn * 0.5 + 0.5
    Aw, Rw = pbrmaps.wet(A, R, darken=0.30, gloss=0.38, floor=0.18)

    flip = np.flipud
    maps = {"ALB": A, "NOR": NOR, "RGH": R, "MET": M, "ALB_Wet": Aw, "RGH_Wet": Rw}
    master_dir = os.path.join(src_dir, "textures")
    os.makedirs(master_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    for k, arr in maps.items():
        stem = "T_%s_Buoy_%s.png" % (tex, k)
        a = flip(arr)
        pbrmaps.write_png(os.path.join(master_dir, stem), a)
        small = pbrmaps.downsize(a, ship)
        if k == "NOR":
            small = small * 2.0 - 1.0
            small /= np.maximum(np.linalg.norm(small, axis=2, keepdims=True), 1e-6)
            small = small * 0.5 + 0.5
        if k == "MET":
            small = (small > 0.5).astype(np.float32)
        pbrmaps.write_png(os.path.join(out_dir, stem), small)
    pbrmaps.write_png(os.path.join(src_dir, "signal_mask.png"), (pbrmaps.downsize(flip(SIG), ship) > 0.5).astype(np.float32))
    print("[HP2b] composed %s: %d texels, signal %.1f%%, droppings %.1f%%, weed %.1f%%, rust %.1f%%"
          % (tex, n, 100 * signal.mean(), 100 * (drop > 0.5).mean(), 100 * (weed > 0.5).mean(), 100 * (rust > 0.3).mean()))


if __name__ == "__main__":
    import json
    kind = sys.argv[1]
    name = marks.asset_name(kind)
    src = os.path.join(REPO, "art", "source", "harbour", name)
    info = json.load(open(os.path.join(src, "textures", "info.json")))
    compose(kind, info, os.path.join(src, "textures", "gbuffer_2048.npz"), src,
            os.path.join(REPO, "assets", "textures", name), marks.tex_name(kind), 2048 if kind in marks.NAVMARKS else 1024)
