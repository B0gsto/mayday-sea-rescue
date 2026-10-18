"""H6 map composer (pure numpy; inside Blender's Python or system python3).

Input: a G-buffer npz from buoylib.bake_gbuffer (object-space position in metres, shading normal, part id, pointiness,
AO; rows bottom-up as Blender stores them). A painter (harbourlight.py / lifeguard.py) turns it into albedo (sRGB 0..1),
roughness, metalness, a height field (metres) and a signal mask; this module adds the shared finish: AO, albedo range
(12 1.4a: 20 to 240 sRGB, metal 180 to 250), saturation cap 0.42 outside the signal mask, tangent-space OpenGL normal from
the height field, _Wet ALB / RGH, masters at the bake size in art/source/buildings/<Asset>/textures/ and shipping maps in
assets/textures/<Asset>/, plus textures/masks/T_<Tex>_<Set>_signal.png (check_textures.py picks it up).

CC0 Poly Haven scans (build/materials/src/<id>/, 1k or 2k, triplanar from object position):
  white_plaster_rough_01        https://polyhaven.com/a/white_plaster_rough_01        painted render grain
  granite_tile                  https://polyhaven.com/a/granite_tile                  granite dressings, plinth
  seaworn_stone_tiles           https://polyhaven.com/a/seaworn_stone_tiles           sea-worn stone tone break-up
  rusty_painted_metal           https://polyhaven.com/a/rusty_painted_metal           painted iron, rust, chips
  rust_coarse_01                https://polyhaven.com/a/rust_coarse_01                rust colour
  wood_peeling_paint_weathered  https://polyhaven.com/a/wood_peeling_paint_weathered  painted cladding, peeling
  metal_plate_02                https://polyhaven.com/a/metal_plate_02                galvanised / stainless grain
  damp_beach_sand               https://polyhaven.com/a/damp_beach_sand               blown sand on decks and legs
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender"))
import pbrmaps  # noqa: E402

SCANS = os.path.join(REPO, "build", "materials", "src")


def load_img(path):
    """RGB float 0..1, rows top-down."""
    try:
        from PIL import Image
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    except ImportError:
        import bpy
        img = bpy.data.images.load(path, check_existing=False)
        img.colorspace_settings.name = "Non-Color"
        w, h = img.size
        a = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(a)
        bpy.data.images.remove(img)
        return np.flipud(a.reshape(h, w, 4)[..., :3]).copy()


_cache = {}


def scan(pid, kind="diff"):
    key = (pid, kind)
    if key not in _cache:
        for res in ("2k", "1k"):
            p = os.path.join(SCANS, pid, "%s_%s.png" % (kind, res))
            if os.path.isfile(p):
                _cache[key] = load_img(p)
                break
        else:
            raise FileNotFoundError("scan %s %s" % (pid, kind))
    return _cache[key]


def mask_img(path):
    if path not in _cache:
        _cache[path] = load_img(path)[..., 0]
    return _cache[path]


def tri(img, pos, nrm, tile):
    """Triplanar nearest sample of a tiling scan (tile = metres per repeat)."""
    h, w = img.shape[:2]
    wts = np.abs(nrm) ** 4
    wts /= np.maximum(wts.sum(axis=1, keepdims=True), 1e-6)
    out = 0.0
    for k, (a, b) in enumerate(((1, 2), (0, 2), (0, 1))):
        u = ((pos[:, a] / tile) % 1.0 * w).astype(np.int32) % w
        v = ((-pos[:, b] / tile + 0.37 * k) % 1.0 * h).astype(np.int32) % h
        out = out + img[v, u] * (wts[:, k:k + 1] if img.ndim == 3 else wts[:, k])
    return out


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = h & 0xFFFFFFFF
    h = h ^ (h >> 13)
    h = (h * 0x5BD1E995) & 0xFFFFFFFF
    h = h ^ (h >> 15)
    return (h & 0xFFFFFF).astype(np.float32) / float(0xFFFFFF)


def hash3(i, seed):
    i = i.astype(np.int64)
    return _hash(i[:, 0], i[:, 1], i[:, 2], seed)


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
    # H6b: the old denominator np.maximum(e1 - e0, 1e-6) made every reversed ramp (e1 < e0) a hard step the wrong way
    d = np.asarray(e1, np.float32) - np.asarray(e0, np.float32)
    d = np.where(np.abs(d) < 1e-6, np.float32(1e-6), d)
    t = np.clip((x - e0) / d, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
    t = np.asarray(t, dtype=np.float32)
    if t.ndim == 1 and (np.ndim(a) == 2 or np.ndim(b) == 2):
        t = t[:, None]
    return a * (1.0 - t) + b * t


def luma(c):
    return c[:, 0] * 0.2126 + c[:, 1] * 0.7152 + c[:, 2] * 0.0722


def col(rgb, n):
    return np.tile(np.asarray(rgb, np.float32), (n, 1))


def tone(scan_rgb, base, amount=1.0):
    """Recolour a scan to `base` keeping its luma variation (amount 0 = flat base)."""
    y = luma(scan_rgb)
    m = max(float(np.mean(y)), 1e-3)
    k = 1.0 + (y / m - 1.0) * amount
    return np.asarray(base, np.float32)[None, :] * k[:, None]


def text_sample(mask, u, v):
    """Sample a top-down mask at u (0 left .. 1 right), v (0 top .. 1 bottom); 0 outside."""
    h, w = mask.shape
    inside = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    uu = np.clip((u * w).astype(np.int32), 0, w - 1)
    vv = np.clip((v * h).astype(np.int32), 0, h - 1)
    out = mask[vv, uu]
    return np.where(inside, out, 0.0)


class Ctx:
    """Per-texel G-buffer arrays (only covered texels) handed to the painter."""

    def __init__(self, g):
        cov = g["covered"] & ~np.all(np.abs(g["pos"].astype(np.float32) + 5.0) < 1e-3, axis=2)
        self.cov = cov
        self.sel = cov.ravel()
        self.pos = g["pos"].reshape(-1, 3)[self.sel].astype(np.float32)
        nrm = g["nrm"].reshape(-1, 3)[self.sel].astype(np.float32)
        self.nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-6)
        self.part = g["part"].ravel()[self.sel].astype(np.int32)
        self.curv = g["curv"].ravel()[self.sel].astype(np.float32)
        self.ao = np.clip(g["ao"].ravel()[self.sel].astype(np.float32), 0.0, 1.0)
        self.n = len(self.pos)
        self.x, self.y, self.z = self.pos[:, 0], self.pos[:, 1], self.pos[:, 2]
        self.r = np.sqrt(self.x ** 2 + self.y ** 2)
        self.ang = np.arctan2(self.x, -self.y)            # 0 = front (-Y), positive towards +X
        # edge: pointiness above the flat value (0.5) = convex edge
        self.edge = ss(0.52, 0.62, self.curv)
        self.cavity = ss(0.48, 0.40, self.curv)

    def is_(self, *parts):
        return np.isin(self.part, parts)


def compose_set(gb_path, painter, master_dir, out_dir, tex, set_name, ship):
    g = np.load(gb_path)
    c = Ctx(g)
    H, W = c.cov.shape
    alb, rgh, met, hgt, signal = painter(c)
    alb = np.clip(alb, 0.0, 1.0)
    # AO into the albedo (soft), then the albedo range and saturation rules
    alb = alb * (0.70 + 0.30 * c.ao)[:, None]
    metal = met > 0.5
    y_ = luma(alb)
    lo = np.where(metal, 0.735, 0.125)
    hi = np.where(metal, 0.96, 0.92)
    alb *= (np.clip(y_, lo, hi) / np.maximum(y_, 1e-4))[:, None]
    alb = np.clip(alb, 0.0, 1.0)
    lim, _ = pbrmaps.limit_saturation(alb[None], 0.42)
    alb = np.where(signal[:, None] > 0.5, alb, lim[0])

    def full(vals, fill):
        shape = (H * W,) + vals.shape[1:]
        out = np.empty(shape, np.float32)
        out[:] = fill
        out[c.sel] = vals
        return out.reshape((H, W) + vals.shape[1:])

    A = full(alb, np.array([0.45, 0.45, 0.44], np.float32))
    R = full(np.clip(rgh, 0.04, 1.0), 0.6)
    M = full(met.astype(np.float32), 0.0)
    Hm = full(hgt.astype(np.float32), 0.0)
    SIG = full(signal.astype(np.float32), 0.0)
    P = g["pos"].astype(np.float32)
    tex_m = np.linalg.norm(np.gradient(P, axis=1), axis=2)
    tex_m = np.where(c.cov, tex_m, np.nan)
    med = np.nanmedian(tex_m)
    tex_m = np.where(np.isfinite(tex_m) & (tex_m < 3 * med) & (tex_m > 0.05 * med), tex_m, med)
    dhdu = np.gradient(Hm, axis=1) / tex_m
    dhdv = np.gradient(Hm, axis=0) / tex_m
    seam = ~c.cov | (np.linalg.norm(np.gradient(P, axis=0), axis=2) > 4 * med) | \
        (np.linalg.norm(np.gradient(P, axis=1), axis=2) > 4 * med)
    dhdu[seam] = 0.0
    dhdv[seam] = 0.0
    Nn = np.dstack([-np.clip(dhdu, -1.5, 1.5), -np.clip(dhdv, -1.5, 1.5), np.ones_like(dhdu)])
    Nn /= np.linalg.norm(Nn, axis=2, keepdims=True)
    NOR = Nn * 0.5 + 0.5
    Aw, Rw = pbrmaps.wet(A, R, darken=0.30, gloss=0.38, floor=0.12)
    # metal darkens less when wet (water film over a reflective surface)
    Aw = np.where(M[..., None] > 0.5, A * 0.88, Aw)

    flip = np.flipud
    maps = {"ALB": A, "NOR": NOR, "RGH": R, "MET": M, "ALB_Wet": Aw, "RGH_Wet": Rw}
    os.makedirs(master_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    for k, arr in maps.items():
        stem = "T_%s_%s_%s.png" % (tex, set_name, k)
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
    sig = (pbrmaps.downsize(flip(SIG), ship) > 0.5).astype(np.float32)
    pbrmaps.write_png(os.path.join(master_dir, "masks", "T_%s_%s_signal.png" % (tex, set_name)), sig)
    print("[H6] composed T_%s_%s: %d texels (%.0f%% cover), signal %.1f%%, metal %.1f%%"
          % (tex, set_name, c.n, 100.0 * c.n / (H * W), 100 * signal.mean(), 100 * metal.mean()))
