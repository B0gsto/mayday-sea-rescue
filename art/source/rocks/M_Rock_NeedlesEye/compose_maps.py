"""M_Rock_NeedlesEye maps (system python3, no heavy slot): the archtex.py bakes -> T_Arch_Granite_* (+ _Wet).

Albedo: the 05 granite grey (#8A8781) toned by the CC0 scan detail archtex box-projected in world space, pink / grey
blotches and iron stains from world-space noise (the baked position pass), then the coastal zonation at the tide line
(WL = 10 m above the base): silted subtidal rock with coralline crusts, wrack and the barnacle band at the tide line,
weed and black Verrucaria in the splash band, runoff stains and bird-lime streaks down the faces, Xanthoria and grey
lichen on up-facing ledges near the crest. The tide band and everything under it is wet in the dry set; the _Wet set
is the whole rock rain / spray wet (pbrmaps.wet). Normal = the _HP's baked normal (geometry + scan relief).

  python3 art/source/rocks/M_Rock_NeedlesEye/compose_maps.py [--out-root build/prod/M_Rock_NeedlesEye] [--size 4096]
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
for p in (HERE, os.path.join(REPO, "tools/blender"), os.path.join(REPO, "art/source/rocks/_kit")):
    if p not in sys.path:
        sys.path.insert(0, p)
import arch as A  # noqa: E402
import names  # noqa: E402
import pbrmaps  # noqa: E402
import compose as K  # noqa: E402  (the K1 rock grading: granite(), fbm(), ss(), srgb(), lowpass())

NAME = "M_Rock_NeedlesEye"
SET = "Granite"
TEX = "Arch"
WET_RGH = (0.24, 0.9)          # compose.py's clamp: no mirror rock


def load(work, name, size, mode="RGB"):
    im = Image.open(os.path.join(work, name + ".png")).convert(mode)
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def wnoise(pos, cells, seed, size, res=640):
    """3D value noise sampled in world space (the baked position pass): the atlas UVs cannot stretch it into a
    stripe. Evaluated on a coarse grid then bicubic to the bake size."""
    small = np.stack([np.asarray(Image.fromarray(pos[..., i].astype(np.float32), "F").resize((res, res), Image.BILINEAR),
                                   np.float32) for i in range(3)], axis=2)
    rng = np.random.default_rng(seed)
    g = rng.random((cells + 1, cells + 1, cells + 1)).astype(np.float32)
    f = small * cells
    i0 = np.clip(np.floor(f).astype(np.int32), 0, cells - 1)
    t = f - i0
    t = t * t * (3.0 - 2.0 * t)
    x, y, zc = i0[..., 0], i0[..., 1], i0[..., 2]
    tx, ty, tz = t[..., 0], t[..., 1], t[..., 2]
    def lerp(a, b, u):
        return a + (b - a) * u
    c00 = lerp(g[x, y, zc], g[x + 1, y, zc], tx)
    c10 = lerp(g[x, y + 1, zc], g[x + 1, y + 1, zc], tx)
    c01 = lerp(g[x, y, zc + 1], g[x + 1, y, zc + 1], tx)
    c11 = lerp(g[x, y + 1, zc + 1], g[x + 1, y + 1, zc + 1], tx)
    out = lerp(lerp(c00, c10, ty), lerp(c01, c11, ty), tz)
    return np.asarray(Image.fromarray(out.astype(np.float32), "F").resize((size, size), Image.BICUBIC), np.float32)


def main():
    ap = argparse.ArgumentParser(prog="compose_maps.py")
    ap.add_argument("--out-root", default=os.path.join(REPO, "build/prod", NAME))
    ap.add_argument("--size", type=int, default=4096)
    args = ap.parse_args()
    out_root = os.path.abspath(args.out_root)
    work = os.path.join(out_root, "work")
    size = args.size
    K.N = size                                  # compose.py's noise fields are cell-based, so they scale with N
    H = A.TOP / 3.0                             # the rock's height in metres
    wl = A.WL / 3.0                             # the tide line above the base, in metres
    seed = sum(map(ord, NAME))

    mask = load(work, "mask", size, "RGBA")
    pos = load(work, "pos", size)
    wn = load(work, "wn", size)
    nor_geo = load(work, "nor", size)
    det = load(work, "detail", size)
    ao, curv = mask[..., 0], mask[..., 1]
    z = pos[..., 2] * H
    up = wn[..., 2] * 2.0 - 1.0

    # 1. granite albedo: the scans' tone (box-projected in world space, archtex) on the 05 granite grey, with
    # world-space pink / grey blotches and iron staining (UV-space noise would break at every island seam)
    def norm(x):
        lo, hi = np.percentile(x, (2.0, 98.0))
        return np.clip((x - lo) / max(hi - lo, 1e-3), 0.0, 1.0)
    Ln = 0.5 * norm(det[..., 0]) + 0.3 * norm(det[..., 1]) + 0.2 * norm(det[..., 2])
    grain = K.fbm(seed + 21, [256, 512, 1024], [0.45, 0.35, 0.2])     # the granite's crystal speckle
    blot = wnoise(pos, 7, seed + 11, size)                          # ~3 m pink vs grey granite
    rust = pbrmaps.smoothstep(0.64, 0.82, wnoise(pos, 12, seed + 12, size) * 0.7 + 0.3 * Ln)
    grey, pink, rusty = K.srgb("#8A8781"), K.srgb("#9A8A82"), K.srgb("#8E765E")
    base = grey * (1 - 0.6 * blot[..., None]) + pink * (0.6 * blot[..., None])
    base = base * (1 - 0.45 * rust[..., None]) + rusty * (0.45 * rust[..., None])
    alb = base * (0.58 + 0.62 * Ln)[..., None] * (0.92 + 0.16 * grain)[..., None]
    alb *= (0.80 + 0.20 * ao)[..., None]
    alb *= (1.0 - 0.22 * np.clip((0.5 - curv) * 2.0, 0.0, 1.0))[..., None]     # joints and cracks sink dark
    rgh = np.clip(0.80 + 0.10 * K.fbm(seed + 5, [16, 64]) - 0.08 * (1.0 - ao), 0.62, 0.97)   # dry granite: matte

    # 2. the tide line and the depth zonation. The rock's lower 10 m is subtidal (the gully floor sits 30 studs
    # under the water): dark silted rock with coralline crusts, then the barnacle band at the tide line, the
    # splash band of wrack and black Verrucaria, then grey granite with Xanthoria and grey lichen on up faces.
    ss = pbrmaps.smoothstep
    upm = ss(0.35, 0.85, up)
    high = ss(wl + 1.5, wl + 5.0, z)
    patch = wnoise(pos, 4, seed + 2, size)          # ~5 m macro weathering / weed patches
    patch2 = wnoise(pos, 9, seed + 3, size)         # ~2 m
    speck = wnoise(pos, 40, seed + 4, size)         # ~0.5 m barnacle / crystal clusters
    wrack, barn = K.srgb("#53521F") * 1.02, K.srgb("#A29D90")
    weed = K.srgb("#3E5325")
    xan, grey_l, black_l = K.srgb("#A9825A"), K.srgb("#8E9488"), K.srgb("#3E3D3A")
    coralline = K.srgb("#9A7370")
    deep = 1.0 - ss(wl - 4.0, wl - 1.0, z + 0.8 * (patch - 0.5))   # 1 below 6 m, 0 above 9 m
    zoff = 1.15 * (patch - 0.5) + 0.38 * (patch2 - 0.5)            # the tide edge wanders with the world noise
    below = 1.0 - ss(wl - 0.55, wl + 0.55, z + zoff)
    a_w, r_w = pbrmaps.wet(alb, rgh, darken=0.26, gloss=0.45)
    alb = alb * (1 - below[..., None]) + a_w * below[..., None]
    rgh = rgh * (1 - below) + np.clip(r_w, *WET_RGH) * below
    alb *= (1.0 - 0.24 * deep)[..., None]                          # silted and dark down the gully
    rgh = np.clip(rgh * (1 - 0.25 * deep) + 0.14 * deep, 0.32, 0.98)
    cr = ss(0.62, 0.76, patch2 * 0.7 + speck * 0.3) * (1.0 - ss(wl - 1.4, wl + 0.2, z + 0.5 * (patch - 0.5)))
    alb = alb * (1 - 0.35 * cr[..., None]) + (coralline * (0.85 + 0.3 * speck[..., None])) * 0.35 * cr[..., None]
    band = ss(wl - 1.1, wl - 0.5, z + zoff) * (1 - ss(wl + 0.25, wl + 0.75, z + zoff))
    bdots = ss(0.48, 0.62, speck * 0.7 + patch2 * 0.3) * band * (0.45 + 0.55 * (1 - ao)) * 0.85
    alb = alb * (1 - band[..., None] * 0.22)
    alb = alb * (1 - bdots[..., None]) + (barn * (0.85 + 0.25 * speck[..., None])) * bdots[..., None]
    rgh = rgh * (1 - bdots) + 0.88 * bdots
    wm = ss(0.52, 0.66, patch2 * 0.7 + speck * 0.3) * ss(wl - 0.9, wl - 0.1, z + zoff) \
         * (1 - ss(wl + 0.3, wl + 0.9, z + zoff)) * (0.35 + 0.65 * (1 - ao))
    alb = alb * (1 - wm[..., None]) + (wrack[None, None, :] * (0.8 + 0.4 * patch[..., None])) * wm[..., None]
    rgh = rgh * (1 - wm) + 0.30 * wm
    gwm = ss(0.62, 0.74, patch * 0.55 + patch2 * 0.3 + speck * 0.15) * ss(wl - 0.2, wl + 0.6, z + zoff) \
          * (1 - ss(wl + 1.4, wl + 2.4, z + 0.8 * (patch2 - 0.5))) * (0.25 + 0.75 * (1 - ao))   # weed clumps
    alb = alb * (1 - 0.40 * gwm[..., None]) + (weed * (0.8 + 0.4 * speck[..., None])) * 0.40 * gwm[..., None]
    rgh = rgh * (1 - gwm) + 0.42 * gwm
    vb = ss(wl + 0.2, wl + 0.8, z + zoff) * (1 - ss(wl + 2.0, wl + 3.6, z + 0.9 * (patch - 0.5))) \
         * ss(0.2, 0.45, patch2 * 0.6 + patch * 0.4)              # the black tide band, near continuous
    alb = alb * (1 - 0.75 * vb[..., None]) + black_l * 0.75 * vb[..., None]
    rgh = rgh * (1 - vb) + 0.62 * vb
    streak = ss(0.55, 0.75, patch2) * (1 - ao) * ss(wl + 0.4, wl + 2.0, z) * (1 - ss(wl + 5.0, wl + 8.0, z))
    alb *= (1.0 - 0.13 * streak)[..., None]                        # rain / spray streaks above the tide line
    vert = pos * np.array([1.0, 1.0, 0.07], np.float32)               # world noise stretched 14x down the face
    run = wnoise(vert, 40, seed + 6, size)
    dark = ss(0.6, 0.78, run) * (1 - upm) * ss(wl + 1.0, wl + 4.0, z)
    alb *= (1.0 - 0.10 * dark)[..., None]                          # runoff stains down the faces
    lime = ss(0.62, 0.8, wnoise(vert, 55, seed + 7, size)) * (1 - upm) * ss(wl + 5.0, wl + 9.0, z) \
        * ss(0.35, 0.6, patch)
    lime = np.maximum(lime, 0.8 * ss(0.74, 0.84, speck) * upm * ss(wl + 12.0, wl + 15.0, z))   # ledge splashes
    alb = alb * (1 - 0.55 * lime[..., None]) + K.srgb("#D6D2C6") * 0.55 * lime[..., None]
    rgh = rgh * (1 - 0.5 * lime) + 0.9 * 0.5 * lime
    xm = 0.34 * ss(0.78, 0.86, patch * 0.6 + speck * 0.25 + upm * 0.25) * high * upm
    gm = 0.24 * ss(0.70, 0.84, patch2 * 0.55 + patch * 0.45) * high * (0.3 + 0.7 * upm) * (1 - xm)
    alb = alb * (1 - xm[..., None]) + (xan * (0.85 + 0.25 * speck[..., None])) * xm[..., None]
    alb = alb * (1 - gm[..., None] * 0.45) + (grey_l * (0.92 + 0.12 * grain[..., None])) * gm[..., None] * 0.45
    rgh = np.clip(rgh * (1 - xm - gm * 0.8) + 0.9 * (xm + gm * 0.8), 0.2, 0.98)
    sig = np.clip(np.maximum(wm, gwm) + 0.9 * xm + 0.6 * gm + 0.5 * bdots, 0.0, 1.0)
    alb, _ = pbrmaps.limit_saturation(np.clip(alb, 0, 1), 0.32)
    loose = pbrmaps.limit_saturation(np.clip(alb, 0, 1), 0.55)[0]
    w = np.clip(sig * 2.0, 0.0, 1.0)[..., None]
    alb = alb * (1 - w) + loose * w
    alb = np.clip(alb * 0.92, 34 / 255, 200 / 255)
    Image.fromarray((np.clip(sig, 0, 1) * 255).astype(np.uint8)).resize((size, size), Image.NEAREST).save(
        os.path.join(HERE, "T_Arch_Granite_signal.png"))

    # 3. normal: the _HP's geometry + scan relief as baked; no back-facing texels (ray misses on thin edges)
    n = nor_geo * 2.0 - 1.0
    n[..., 2] = np.maximum(n[..., 2], 0.35)
    nor = n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-6) * 0.5 + 0.5

    met = np.zeros(z.shape, np.float32)
    a_wet, r_wet = pbrmaps.wet(alb, rgh, darken=0.3, gloss=0.35)
    a_wet = np.clip(a_wet, 32 / 255, 232 / 255)
    r_wet = np.clip(r_wet, *WET_RGH)

    stem = "T_%s_%s_" % (TEX, SET)
    edir = os.path.join(out_root, "textures", NAME)
    mdir = os.path.join(out_root, "masters", NAME)
    maps = {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met, "ALB_Wet": a_wet, "RGH_Wet": r_wet}
    for k, a in maps.items():
        for d in (mdir, edir):
            pbrmaps.write_png(os.path.join(d, stem + k + ".png"), a)
    print("[compose] %d maps at %d px -> %s" % (len(maps), size, os.path.relpath(edir, REPO)))
    for k in ("ALB", "NOR", "RGH", "MET"):
        a = maps[k].reshape(-1, 1) if maps[k].ndim == 2 else maps[k].reshape(-1, maps[k].shape[2])
        print("[compose]   %-8s mean %s" % (k, a.mean(0).round(3)))
    assert names.texture_name_problem(stem + "ALB") is None


if __name__ == "__main__":
    main()
