"""M_Veg_Eelgrass_Kit atlas cell painter (pure numpy; runs inside Blender and under system python3).

Shared atlas FoliageMarine / set Main (art/source/materials/atlases.py). This kit owns the `M_Veg_Eelgrass`
cell only: atlas u 0.75..1.00, v 0.75..1.00 (512 x 512 px at the 2048 ship size, 1024 x 1024 at 4096).
Everything outside the cell is copied from the newest map another marine-veg kit wrote, so a cell merge keeps
the kelp and wrack work.

Inside the cell (cell-local s right, t up; geometry UVs come from uv()):
  LeafYoung s 0.00..0.50, t 0.50..1.00   young eelgrass blade: grass green, fine parallel veins, clean tip
  LeafOld   s 0.50..1.00, t 0.50..1.00   older blade: deep olive, diatom film, silt, pale epiphyte crusts,
                                         straw-brown dead tip
  LeafDead  s 0.00..0.50, t 0.00..0.50   spent blade: straw / tan, dark blotches, frayed edge
  Sand      s 0.50..1.00, t 0.00..0.50   wet sand and silt: grain, shell grit, dark pebbles, rhizome fibres

The blades are painted as surfaces only: the outline, bend and twist are real geometry (eelgrass.py), so the
albedo carries no alpha cut-out. Values stay inside the check_textures window (luma 20..240, saturation 0.45),
roughness 0.26..0.60 for wet leaves.
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

ASSET = "M_Veg_Eelgrass_Kit"
SET_NAME, SET_SET = "FoliageMarine", "Main"
MASTER, SHIP = 4096, 2048

CELL = (0.75, 0.75, 1.0, 1.0)
RECTS = {
    "LeafYoung": (0.00, 0.50, 0.50, 1.00),
    "LeafOld": (0.50, 0.50, 1.00, 1.00),
    "LeafDead": (0.00, 0.00, 0.50, 0.50),
    "Sand": (0.50, 0.00, 1.00, 0.50),
}


def uv(rect, s, t, m=0.012):
    """Rect-local s across (0 left, 1 right), t up the blade (0 base, 1 tip) -> atlas UV (v up)."""
    s0, t0, s1, t1 = RECTS[rect]
    u0, v0, u1, v1 = CELL
    s = min(1.0 - m, max(m, s))
    t = min(1.0 - m, max(m, t))
    return (u0 + (s0 + s * (s1 - s0)) * (u1 - u0),
            v0 + (t0 + t * (t1 - t0)) * (v1 - v0))


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
    """Sparse round blobs 0..1 (wrapped): shell grit, epiphyte crusts, pebbles."""
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
        out = np.maximum(out, sm(1.0, 0.30, d))
        if ring:
            rim = np.maximum(rim, sm(1.30, 1.02, d) * sm(0.72, 1.00, d))
    return (out, rim) if ring else out


# ---------------------------------------------------------------------------------------------------- palette
YOUNG = np.array([0.360, 0.452, 0.206])       # #5C7335 grass green
YOUNG_LIT = np.array([0.468, 0.556, 0.270])
OLD = np.array([0.276, 0.324, 0.166])         # #46542A deep olive
OLD_LIT = np.array([0.376, 0.404, 0.218])
GOLD = np.array([0.438, 0.404, 0.208])
DEAD = np.array([0.470, 0.412, 0.250])        # straw
DEAD_DARK = np.array([0.250, 0.212, 0.132])
SILT = np.array([0.500, 0.468, 0.380])
DIATOM = np.array([0.478, 0.404, 0.238])
EPI = np.array([0.620, 0.612, 0.548])
SAND = np.array([0.408, 0.382, 0.306])
SAND_DARK = np.array([0.268, 0.246, 0.190])
SHELL = np.array([0.690, 0.672, 0.600])
PEBBLE = np.array([0.264, 0.252, 0.222])


# ---------------------------------------------------------------------------------------------------- leaves
def leaf(w, h, kind, seed):
    """One blade surface, row 0 = tip. Returns colour, height, roughness (alpha is written by the sheet)."""
    S = ((np.arange(w) + 0.5) / w)[None, :]
    T = (1.0 - (np.arange(h) + 0.5) / h)[:, None]
    ss = np.broadcast_to(S, (h, w))
    tt = np.broadcast_to(T, (h, w))

    warp = pnoise(h, w, 2, 3, seed + 1, 3)
    streak = pnoise(h, w, 1.5, 34, seed + 2, 4)
    fine = pnoise(h, w, 5, 70, seed + 3, 3)
    patch = pnoise(h, w, 4, 5, seed + 4, 4)
    grime = pnoise(h, w, 8, 9, seed + 5, 4)
    edge = sm(0.0, 0.10, ss) * sm(1.0, 0.90, ss)

    vein = 0.5 + 0.5 * np.sin(2 * math.pi * (ss * 11.0 + 0.55 * (warp - 0.5)))
    vein = vein ** 3.0
    vein2 = 0.5 + 0.5 * np.sin(2 * math.pi * (ss * 23.0 + 0.30 * (streak - 0.5)))
    midrib = np.exp(-((ss - 0.5) / 0.085) ** 2)

    if kind == "young":
        col = YOUNG[None, None, :] * (0.78 + 0.40 * patch[..., None])
        col = col * (0.92 + 0.13 * streak[..., None])
        col = col + (YOUNG_LIT[None, None, :] - col) * (0.38 * vein[..., None] * sm(0.05, 0.45, tt)[..., None])
        col = col + (YOUNG_LIT[None, None, :] - col) * (0.22 * midrib[..., None] * sm(0.10, 0.55, tt)[..., None])
        col = col * (1.0 - 0.28 * sm(0.16, 0.0, tt)[..., None])
        col = col + (GOLD[None, None, :] - col) * (0.42 * sm(0.80, 1.0, tt + 0.05 * (grime - 0.5))[..., None])
        col = col + (SILT[None, None, :] - col) * (0.16 * sm(0.14, 0.0, tt) * grime)[..., None]
        col = col * (1.0 - 0.12 * sm(0.65, 0.95, fine)[..., None])
        enc = specks(h, w, 5, seed + 8, 0.004, 0.010, clump=0.7) * sm(0.42, 0.92, tt) * (1.0 - 0.55 * edge)
        col = col + (EPI[None, None, :] - col) * (0.30 * enc[..., None])
        height = (0.32 + 0.30 * midrib + 0.22 * vein + 0.10 * (fine - 0.5) + 0.08 * (streak - 0.5))
        rgh = 0.30 + 0.05 * (fine - 0.5) + 0.10 * enc + 0.05 * (1.0 - edge)
    elif kind == "old":
        col = OLD[None, None, :] * (0.74 + 0.46 * patch[..., None])
        col = col * (0.94 + 0.11 * streak[..., None])
        col = col + (OLD_LIT[None, None, :] - col) * (0.34 * vein[..., None] * sm(0.10, 0.60, tt)[..., None])
        col = col + (OLD_LIT[None, None, :] - col) * (0.16 * midrib[..., None])
        col = col + (DIATOM[None, None, :] - col) * (0.34 * sm(0.30, 0.90, tt) * sm(0.40, 0.85, grime))[..., None]
        col = col + (SILT[None, None, :] - col) * (0.26 * sm(0.42, 0.95, grime) * sm(0.20, 0.85, tt))[..., None]
        col = col * (1.0 - 0.30 * sm(0.18, 0.0, tt)[..., None])
        brown = sm(0.55, 0.90, pnoise(h, w, 5, 7, seed + 7, 3)) * sm(0.30, 0.85, tt)
        col = col + (DEAD[None, None, :] - col) * (0.42 * brown[..., None])
        tip = sm(0.82, 0.99, tt + 0.06 * (grime - 0.5))
        col = col + (DEAD[None, None, :] - col) * (0.90 * tip[..., None])
        col = col + (DEAD_DARK[None, None, :] - col) * (0.35 * tip * sm(0.55, 0.95, fine))[..., None]
        enc, rim = specks(h, w, 14, seed + 9, 0.003, 0.010, clump=0.65, ring=0.35)
        enc = enc * sm(0.25, 0.80, tt)
        col = col + (EPI[None, None, :] - col) * (0.52 * enc[..., None])
        col = col * (1.0 - 0.16 * (rim * sm(0.30, 0.85, tt))[..., None])
        col = col + (SILT[None, None, :] - col) * (0.20 * (1.0 - edge) * grime)[..., None]
        height = (0.30 + 0.26 * midrib + 0.18 * vein + 0.18 * enc + 0.10 * (fine - 0.5) + 0.10 * brown)
        rgh = 0.34 + 0.08 * (fine - 0.5) + 0.16 * enc + 0.10 * brown + 0.06 * tip
    else:
        blot = sm(0.52, 0.92, pnoise(h, w, 6, 5, seed + 6, 4))
        col = DEAD[None, None, :] * (0.70 + 0.46 * patch[..., None]) * (0.92 + 0.14 * streak[..., None])
        col = col + (DEAD_DARK[None, None, :] - col) * (0.55 * blot[..., None])
        col = col * (1.0 - 0.26 * sm(0.20, 0.0, tt)[..., None])
        col = col + (DEAD_DARK[None, None, :] - col) * (0.45 * sm(0.45, 0.95, tt) * sm(0.30, 0.75, grime))[..., None]
        col = col + (SILT[None, None, :] - col) * (0.30 * sm(0.35, 0.9, grime) * (1.0 - edge))[..., None]
        col = col + (DEAD_DARK[None, None, :] - col) * (0.30 * vein2 * (1.0 - edge))[..., None]
        height = 0.35 + 0.25 * (fine - 0.5) + 0.20 * blot + 0.12 * (streak - 0.5)
        rgh = 0.44 + 0.10 * blot + 0.06 * (fine - 0.5)

    col = np.clip(col, 0, 1)
    return col.astype(np.float32), np.clip(height, 0, 1), np.clip(rgh, 0.26, 0.62)


# ---------------------------------------------------------------------------------------------------- sand
def sand(w, h, seed):
    grain = pnoise(h, w, 90, 90, seed, 3)
    coarse = pnoise(h, w, 7, 6, seed + 1, 4)
    dark = pnoise(h, w, 3, 4, seed + 2, 3)
    silt = pnoise(h, w, 16, 14, seed + 3, 3)
    col = SAND[None, None, :] * (0.82 + 0.30 * coarse[..., None]) * (0.92 + 0.16 * grain[..., None])
    col = col + (SAND_DARK[None, None, :] - col) * (0.34 * sm(0.52, 0.90, dark) * (0.6 + 0.4 * silt))[..., None]
    col = col * (1.0 - 0.10 * sm(0.62, 0.92, grain)[..., None])
    shell, shell_rim = specks(h, w, 22, seed + 4, 0.003, 0.011, clump=0.55, ring=0.5)
    col = col + (SHELL[None, None, :] - col) * (0.72 * shell[..., None])
    col = col * (1.0 - 0.22 * shell_rim[..., None])
    peb = specks(h, w, 10, seed + 5, 0.004, 0.010, clump=0.6)
    col = col + (PEBBLE[None, None, :] - col) * (0.78 * peb[..., None])
    fibre = pnoise(h, w, 2, 44, seed + 6, 3)
    col = col * (1.0 - 0.18 * sm(0.68, 0.95, fibre))[..., None]
    S = ((np.arange(w) + 0.5) / w)[None, :]
    T = (1.0 - (np.arange(h) + 0.5) / h)[:, None]
    ss = np.broadcast_to(S, (h, w))
    tt = np.broadcast_to(T, (h, w))
    rr = np.sqrt(((ss - 0.5) / 0.24) ** 2 + ((tt - 0.5) / 0.28) ** 2)
    core = sm(1.05, 0.35, rr + 0.22 * (pnoise(h, w, 6, 5, seed + 7, 3) - 0.5))
    col = col + (np.array([0.216, 0.198, 0.150])[None, None, :] - col) * (0.52 * core)[..., None]
    roots = sm(0.72, 0.94, pnoise(h, w, 3, 20, seed + 8, 3)) * core
    col = col + (np.array([0.300, 0.248, 0.170])[None, None, :] - col) * (0.45 * roots)[..., None]
    height = np.clip(0.34 + 0.34 * grain + 0.22 * shell + 0.18 * peb + 0.12 * coarse - 0.10 * silt, 0, 1)
    rgh = np.clip(0.42 + 0.08 * (grain - 0.5) + 0.10 * shell - 0.05 * silt, 0.30, 0.62)
    return np.clip(col, 0, 1).astype(np.float32), height.astype(np.float32), rgh.astype(np.float32)


# ---------------------------------------------------------------------------------------------------- assemble
def _place(dst, rect, arr, size):
    u0, v0, u1, v1 = CELL
    s0, t0, s1, t1 = RECTS[rect]
    x0 = int(round((u0 + s0 * (u1 - u0)) * size))
    x1 = int(round((u0 + s1 * (u1 - u0)) * size))
    y0 = int(round((v0 + t0 * (v1 - v0)) * size))
    y1 = int(round((v0 + t1 * (v1 - v0)) * size))
    dst[size - y1:size - y0, x0:x1] = arr


def clamp_sat(rgb, cap=0.40):
    mx = rgb.max(-1, keepdims=True)
    mn = rgb.min(-1, keepdims=True)
    mid = (mx + mn) * 0.5
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    f = np.minimum(1.0, cap / np.maximum(sat, 1e-6))
    return mid + (rgb - mid) * f


def sheets(size):
    """(alb RGB, alpha, height, roughness) for the whole sheet: this kit's cell painted, the rest flat."""
    a = np.zeros((size, size, 3), np.float32)
    a[:] = np.array([0.35, 0.35, 0.34])
    al = np.zeros((size, size), np.float32)
    hh = np.zeros((size, size), np.float32)
    rr = np.full((size, size), 0.62, np.float32)

    cw = int(round((CELL[2] - CELL[0]) * size))
    ch = int(round((CELL[3] - CELL[1]) * size))

    def rect_px(rect):
        s0, t0, s1, t1 = RECTS[rect]
        return (max(1, int(round((s1 - s0) * cw))), max(1, int(round((t1 - t0) * ch))))

    for name, kind in (("LeafYoung", "young"), ("LeafOld", "old"), ("LeafDead", "dead")):
        w, h = rect_px(name)
        col, height, rgh = leaf(w, h, kind, 300 + sum(ord(c) * (i + 1) for i, c in enumerate(name)) % 997)
        _place(a, name, col, size)
        _place(al, name, np.ones((h, w), np.float32), size)
        _place(hh, name, height, size)
        _place(rr, name, rgh, size)

    w, h = rect_px("Sand")
    col, height, rgh = sand(w, h, 811)
    _place(a, "Sand", col, size)
    _place(al, "Sand", np.ones((h, w), np.float32), size)
    _place(hh, "Sand", height, size)
    _place(rr, "Sand", rgh, size)

    a = np.clip(a * 1.10, 0.0, 1.0)
    a[:] = clamp_sat(a, cap=0.43)
    a = np.clip(a, 30.0 / 255.0, 238.0 / 255.0)
    return a, al, hh, rr


def maps(size=MASTER):
    alb, alpha, height, rgh = sheets(size)
    nor = normal_from_height(height, 7.0 / max(size / 2048.0, 0.5))
    rgba = np.concatenate([alb, alpha[..., None]], -1)
    return rgba.astype(np.float32), nor.astype(np.float32), rgh, np.zeros((size, size), np.float32)


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
    """Copy every pixel outside this kit's cell from an existing marine atlas map, so the kelp and wrack cells
    survive a merge. Returns True when a map was found."""
    x0 = int(round(CELL[0] * size))
    y0 = int(round((1.0 - CELL[3]) * size))
    x1 = int(round(CELL[2] * size))
    y1 = int(round((1.0 - CELL[1]) * size))
    keep = np.ones((size, size), bool)
    keep[y0:y1, x0:x1] = False
    if size > SHIP:
        folders = [os.path.join(GAME, "build/prod/M_Veg_Wrack_Kit/masters"),
                   os.path.join(GAME, "build/prod/M_Veg_Kelp_Kit/masters"),
                   os.path.join(GAME, "assets/textures/M_Veg_FoliageMarine")]
    else:
        folders = [os.path.join(GAME, "build/prod/M_Veg_Wrack_Kit/textures/M_Veg_Wrack_Kit"),
                   os.path.join(GAME, "build/prod/M_Veg_Kelp_Kit/textures/M_Veg_Kelp_Kit"),
                   os.path.join(GAME, "assets/textures/M_Veg_FoliageMarine"),
                   os.path.join(GAME, "assets/textures/M_Veg_Kelp_Kit"),
                   os.path.join(GAME, "assets/textures/M_Veg_Wrack_Kit"),
                   common.textures_dir("M_Veg_Wrack_Kit"),
                   common.textures_dir("M_Veg_Kelp_Kit")]
    for folder in folders:
        alb_p = common.map_file(folder, "T_%s_%s_ALB" % (SET_NAME, SET_SET))
        if not alb_p:
            continue
        old = read_features(alb_p, size)
        if old is None or not (old[..., 3][keep] > 0).any():
            continue
        alb[keep] = old[keep]
        nor_p = common.map_file(folder, "T_%s_%s_NOR" % (SET_NAME, SET_SET))
        if nor_p:
            n = read_features(nor_p, size)
            if n is not None:
                nor[keep] = n[..., :3][keep]
        rgh_p = common.map_file(folder, "T_%s_%s_RGH" % (SET_NAME, SET_SET))
        if rgh_p:
            r = read_features(rgh_p, size)
            if r is not None:
                rgh[keep] = r[..., 0][keep]
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
    for target, arrs in ((masters, big), (directory, small)):
        keep_other_cells(arrs[0], arrs[1], arrs[2], arrs[0].shape[0])
        for tag, arr in zip(("ALB", "NOR", "RGH", "MET"), arrs):
            stem = "T_%s_%s_%s" % (SET_NAME, SET_SET, tag)
            write_png(os.path.join(target, stem + ".png"), np.clip(arr, 0, 1).astype(np.float32))
    print("[%s] wrote 4 maps at %d (%d masters in %s)" % (ASSET, size, 4, os.path.relpath(masters, GAME)))
    return directory


if __name__ == "__main__":
    d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/eelgrass_preview"
    os.makedirs(d, exist_ok=True)
    write_all(out_dir=os.path.join(d, "textures", ASSET), masters_dir=os.path.join(d, "masters"))
    print("wrote", d)
