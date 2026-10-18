"""R1a shared texture helpers (system python3 + numpy + Pillow, no heavy slot). No AI images: every map is a real CC0
Poly Haven scan, graded and composited with procedural masks written here.

fetch(pid)  downloads the 2k PNG maps of a Poly Haven texture into build/roads/src/<pid>/ (one fresh dir per scan, data only)
            and returns {"diff", "nor", "rough", "arm"?} paths plus the page URL and authors (for the status CSV).
Arrays: albedo float32 sRGB 0..255 (H, W, 3); roughness / metal float32 0..1 (H, W); normal float32 -1..1 (H, W, 3),
OpenGL (+Y = image up). Row 0 is the top of the image (v = 1).
"""
import json
import os
import urllib.request

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
SRC = os.path.join(GAME, "build/roads/src")
UA = {"User-Agent": "MaydaySeaRescue-R1a/1.0"}
LICENCE = "CC0 1.0 (https://polyhaven.com/license)"
Image.MAX_IMAGE_PIXELS = None


def _get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
        return r.read()


def fetch(pid, res="2k"):
    d = os.path.join(SRC, pid)
    os.makedirs(d, exist_ok=True)
    meta_p = os.path.join(d, "meta.json")
    if os.path.exists(meta_p):
        meta = json.load(open(meta_p))
    else:
        files = json.loads(_get("https://api.polyhaven.com/files/%s" % pid))
        info = json.loads(_get("https://api.polyhaven.com/info/%s" % pid))
        meta = {"url": "https://polyhaven.com/a/%s" % pid, "authors": sorted(info.get("authors", {})),
                "dims_m": [x / 1000.0 for x in info.get("dimensions", [2000, 2000])], "maps": {}}
        for key, tag in (("Diffuse", "diff"), ("nor_gl", "nor"), ("Rough", "rough"), ("arm", "arm"), ("Displacement", "disp")):
            if key not in files:
                continue
            r = res if res in files[key] else sorted(files[key])[0]
            p = os.path.join(d, "%s_%s.png" % (tag, r))
            if not os.path.exists(p):
                open(p, "wb").write(_get(files[key][r]["png"]["url"]))
            meta["maps"][tag] = p
        json.dump(meta, open(meta_p, "w"), indent=1)
    return meta


def load(meta, size=None):
    """(alb sRGB float, rough 0..1, normal -1..1, height 0..1) of a fetched scan, resized to size (w, h) when given."""
    def im(tag, mode):
        p = meta["maps"].get(tag)
        if not p:
            return None
        i = Image.open(p)
        if i.mode in ("I;16", "I;16B", "I"):
            a = np.asarray(i, dtype=np.float32) / 65535.0
            i = Image.fromarray((a * 255).clip(0, 255).astype(np.uint8), "L")
        i = i.convert(mode)
        if size and i.size != tuple(size):
            i = i.resize(tuple(size), Image.LANCZOS)
        return np.asarray(i, dtype=np.float32)
    alb = im("diff", "RGB")
    rough = im("rough", "L")
    if rough is None and "arm" in meta["maps"]:
        rough = im("arm", "RGB")[..., 1]
    nor = im("nor", "RGB")
    disp = im("disp", "L")
    h = alb.shape[:2]
    rough = (rough / 255.0) if rough is not None else np.full(h, 0.8, np.float32)
    nor = (nor / 127.5 - 1.0) if nor is not None else np.dstack([np.zeros(h), np.zeros(h), np.ones(h)]).astype(np.float32)
    disp = (disp / 255.0) if disp is not None else luma(alb) / 255.0
    return alb, rough, nor, disp


def luma(rgb):
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def tile_to(arr, tile_px, out_hw, offset=(0, 0)):
    """Resample one period of a seamless scan to tile_px (w, h) pixels and wrap-tile it to out_hw (h, w)."""
    a = arr
    two = a.ndim == 2
    if two:
        a = a[..., None]
    chans = []
    for c in range(a.shape[2]):
        img = Image.fromarray(a[..., c].astype(np.float32), "F").resize((max(1, int(tile_px[0])), max(1, int(tile_px[1]))), Image.BICUBIC)
        chans.append(np.asarray(img, dtype=np.float32))
    t = np.dstack(chans)
    reps = (out_hw[0] // t.shape[0] + 2, out_hw[1] // t.shape[1] + 2, 1)
    big = np.tile(t, reps)
    oy, ox = int(offset[1]) % t.shape[0], int(offset[0]) % t.shape[1]
    out = big[oy:oy + out_hw[0], ox:ox + out_hw[1]]
    return out[..., 0] if two else out


def noise(hw, cycles, seed, octaves=4, aniso=(1.0, 1.0)):
    """Periodic value-ish noise 0..1 (FFT-filtered white noise, so it tiles exactly at the image size)."""
    rng = np.random.default_rng(seed)
    h, w = hw
    fy = np.fft.fftfreq(h)[:, None] * h / aniso[1]
    fx = np.fft.fftfreq(w)[None, :] * w / aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    out = np.zeros(hw, np.float32)
    amp = 1.0
    for o in range(octaves):
        c = cycles * (2 ** o)
        spec = np.fft.fft2(rng.standard_normal(hw)) * np.exp(-(f / c) ** 2)
        n = np.real(np.fft.ifft2(spec))
        n = (n - n.mean()) / (n.std() + 1e-6)
        out += amp * n
        amp *= 0.5
    out = (out - out.min()) / (out.max() - out.min() + 1e-6)
    return out.astype(np.float32)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def grade(rgb, target_mean, target_std=None, tint=(1, 1, 1), desat=None):
    """Re-centres a scan's luma on target_mean (sRGB) with an optional contrast target, tint and desaturation."""
    y = luma(rgb)[..., None]
    if desat is not None:
        rgb = y + (rgb - y) * (1.0 - desat)
    m, s = float(y.mean()), float(y.std()) + 1e-6
    k = (target_std / s) if target_std else 1.0
    out = (rgb - m) * k + target_mean
    return out * np.array(tint, np.float32)


def blend(a, b, m):
    m = m[..., None] if (a.ndim == 3 and m.ndim == 2) else m
    return a * (1 - m) + b * m


def height_normal(h, strength, px_per_m):
    """OpenGL tangent normal from a height field in metres (row 0 = top): green = +V (up the image)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * px_per_m
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5 * px_per_m   # up the image
    n = np.dstack([-dx * strength, -dy * strength, np.ones_like(h)])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def combine_normals(a, b):
    """Whiteout blend of two tangent normals."""
    n = np.dstack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]])
    return n / np.linalg.norm(n, axis=2, keepdims=True)


def flatten_normal(n, k):
    """k 0 = keep, 1 = flat."""
    out = n * (1 - k)[..., None] + np.array([0, 0, 1], np.float32) * k[..., None]
    return out / np.linalg.norm(out, axis=2, keepdims=True)


def wet(alb, rgh, darken=0.26, gloss=0.32, pool=None):
    """Wet twin: value down about 26%, a little saturation lift, roughness down; pool (0..1) = standing water."""
    y = luma(alb)[..., None]
    w = (y + (alb - y) * 1.12) * (1 - darken)
    r = np.clip(rgh - gloss, 0.08, 1)
    if pool is not None:
        w = blend(w, w * 0.82, pool * 0.8)
        r = r * (1 - pool) + 0.05 * pool
    return w, r


def save_set(out_dir, stem, alb, rgh, nor, met=None, alpha=None, size=1024, wet_maps=None, master_dir=None):
    """Writes <stem>_ALB/NOR/RGH/MET[_Wet].png at size (and the full-res masters to master_dir)."""
    os.makedirs(out_dir, exist_ok=True)
    h, w = rgh.shape
    met = np.zeros((h, w), np.float32) if met is None else met
    out = {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}
    if wet_maps:
        out["ALB_Wet"], out["RGH_Wet"] = wet_maps
    for k, a in out.items():
        if k.startswith("ALB"):
            arr = np.clip(a, 0, 255)
            if alpha is not None:
                arr = np.dstack([arr, np.clip(alpha, 0, 1) * 255])
            img = Image.fromarray(arr.round().astype(np.uint8), "RGBA" if alpha is not None else "RGB")
        elif k == "NOR":
            img = Image.fromarray(((a * 0.5 + 0.5) * 255).clip(0, 255).round().astype(np.uint8), "RGB")
        else:
            img = Image.fromarray((np.clip(a, 0, 1) * 255).round().astype(np.uint8), "L")
        if master_dir:
            os.makedirs(master_dir, exist_ok=True)
            img.save(os.path.join(master_dir, "%s_%s.png" % (stem, k)))
        sz = (size, size) if isinstance(size, int) else size
        if img.size != tuple(sz):
            img = img.resize(tuple(sz), Image.LANCZOS)
        img.save(os.path.join(out_dir, "%s_%s.png" % (stem, k)), optimize=True)


# ---------------------------------------------------------------------------------------------------- R1a-fix helpers
def hash01(ids, salt):
    """Deterministic 0..1 per integer id (vectorised integer hash)."""
    h = (np.asarray(ids, np.uint64) * np.uint64(2654435761) + np.uint64(salt * 40503 + 977)) & np.uint64(0xFFFFFFFF)
    h ^= h >> np.uint64(15)
    h = (h * np.uint64(2246822519)) & np.uint64(0xFFFFFFFF)
    h ^= h >> np.uint64(13)
    return (h.astype(np.float64) / 4294967296.0).astype(np.float32)


def voronoi(x, y, cell, per_u, per_v, seed):
    """Jittered-grid Voronoi on metric coords x, y (m): (F1, F2, cell id). Periodic in U (per_u m) and in V when per_v."""
    nu = max(1, int(round(per_u / cell)))
    cu = per_u / nu
    nv = max(1, int(round(per_v / cell))) if per_v else 0
    cv = per_v / nv if per_v else cell
    ix, iy = np.floor(x / cu).astype(np.int64), np.floor(y / cv).astype(np.int64)
    f1 = np.full(x.shape, 1e9, np.float32)
    f2 = np.full(x.shape, 1e9, np.float32)
    best = np.zeros(x.shape, np.int64)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            cx, cy = ix + dx, iy + dy
            wx = np.mod(cx, nu)
            wy = np.mod(cy, nv) if per_v else cy + 100000
            cid = wx * 1000003 + wy * 7919 + seed * 104729
            px = (cx + 0.1 + 0.8 * hash01(cid, 1)) * cu
            py = (cy + 0.1 + 0.8 * hash01(cid, 2)) * cv
            d = np.hypot(x - px, y - py).astype(np.float32)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            best = np.where(closer, cid, best)
            f1 = np.where(closer, d, f1)
    return f1, f2, best


def stone_ids(core, grow=8, iters=600):
    """Connected-component labels (flat index of a member pixel) of a boolean mask, periodic both ways, then grown
    `grow` px into the background so stone edges keep their stone's id. Background (never reached) = -1."""
    h, w = core.shape
    big = h * w
    lab = np.where(core, np.arange(big, dtype=np.int64).reshape(h, w), big)
    for _ in range(iters):
        prev = lab
        m = lab
        for ax in (0, 1):
            for sh in (1, -1):
                m = np.minimum(m, np.roll(lab, sh, ax))
        lab = np.where(core, m, big)
        f = lab.ravel()
        ok = f < big
        g = f.copy()
        g[ok] = f[f[ok]]
        lab = g.reshape(h, w)
        if np.array_equal(lab, prev):
            break
    for _ in range(grow):
        m = lab
        for ax in (0, 1):
            for sh in (1, -1):
                m = np.minimum(m, np.roll(lab, sh, ax))
        lab = np.where(lab < big, lab, m)
    return np.where(lab < big, lab, -1)


def height_normal_uv(hgt, ppm_u, ppm_v, strength=1.0):
    """height_normal with separate pixels-per-metre along U (x) and V (y)."""
    dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5 * ppm_u
    dy = (np.roll(hgt, 1, 0) - np.roll(hgt, -1, 0)) * 0.5 * ppm_v
    n = np.dstack([-dx * strength, -dy * strength, np.ones_like(hgt)])
    return (n / np.linalg.norm(n, axis=2, keepdims=True)).astype(np.float32)


def boost_normal(n, k):
    out = np.dstack([n[..., 0] * k, n[..., 1] * k, n[..., 2]])
    return out / np.linalg.norm(out, axis=2, keepdims=True)


def desat(rgb, k, tint=(1, 1, 1)):
    """Saturation scaled by (1 - k) about luma, after any contrast grade (grade()'s contrast gain also scales chroma)."""
    y = luma(rgb)[..., None]
    return (y + (rgb - y) * (1.0 - k)) * np.array(tint, np.float32)
