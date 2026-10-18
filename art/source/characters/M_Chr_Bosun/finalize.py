#!/usr/bin/env python3
"""Shipping maps for M_Chr_Bosun (system python3): masters in textures/ (raw bakes moved there), maps at the set size
in assets/textures/M_Chr_Bosun/ (ALB RGB, Fur ALB RGBA; RGH / MET greyscale; NOR RGB re-normalised), and the harness
signal mask (Hull Orange fabric) for check_textures.py in textures/masks/.

    python3 art/source/characters/M_Chr_Bosun/finalize.py
"""
import glob
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
MASTERS = os.path.join(HERE, "textures")
RAW = os.path.join(MASTERS, "raw")
MASKS = os.path.join(MASTERS, "masks")
OUT = os.path.join(REPO, "assets", "textures", "M_Chr_Bosun")
SIZES = {"Body": 2048, "Harness": 1024, "Fur": 2048}


def luma_clamp(rgb, lo=20.0, hi=240.0):   # round 5: albedo 20..240
    f = rgb.astype(np.float32)
    lum = 0.2126 * f[..., 0] + 0.7152 * f[..., 1] + 0.0722 * f[..., 2]
    scale = np.where(lum < lo, lo / np.maximum(lum, 1.0), np.where(lum > hi, hi / lum, 1.0))
    return (f * scale[..., None]).clip(0, 255).round().astype(np.uint8)


def dilate_fill(arr, covered, iters=96):
    """Pushes covered texels into the empty gutter (so downsizing never mixes in black), rest = covered mean."""
    a = arr.astype(np.float32).copy()
    if a.ndim == 2:
        a = a[..., None]
    cov = covered.copy()
    for _ in range(iters):
        if cov.all():
            break
        acc = np.zeros_like(a)
        cnt = np.zeros(cov.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sc = np.roll(cov, (dy, dx), (0, 1))
            acc += np.roll(a, (dy, dx), (0, 1)) * sc[..., None]
            cnt += sc
        new = (~cov) & (cnt > 0)
        a[new] = acc[new] / cnt[new][:, None]
        cov = cov | new
    a[~cov] = a[covered].mean(axis=0)
    a = a.round().clip(0, 255).astype(np.uint8)
    return a[..., 0] if arr.ndim == 2 else a


COVER = {}


def coverage(set_name):
    if set_name not in COVER:
        p = os.path.join(MASTERS, "T_Bosun_%s_ALB.png" % set_name)
        COVER[set_name] = np.asarray(Image.open(p).convert("RGB")).max(axis=-1) > 0
    return COVER[set_name]


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(MASKS, exist_ok=True)
    for p in glob.glob(os.path.join(RAW, "*.png")):
        name = os.path.basename(p)
        dst = os.path.join(MASKS if "_SIG" in name else MASTERS, name)
        shutil.move(p, dst)
    for p in sorted(glob.glob(os.path.join(MASTERS, "T_Bosun_*.png"))):
        name = os.path.basename(p)
        set_name, kind = name.split("_")[2], name.split("_")[3].split(".")[0]
        size = SIZES[set_name]
        im = Image.open(p)
        if set_name != "Fur":
            arr = np.asarray(im.convert("RGB") if kind in ("ALB", "NOR") else im.convert("L"))
            cov = coverage(set_name)
            if cov.shape == arr.shape[:2] and not cov.all():
                im = Image.fromarray(dilate_fill(arr, cov))
        if kind == "ALB":
            im = im.convert("RGBA" if set_name == "Fur" else "RGB")
            im = im.resize((size, size), Image.LANCZOS) if im.size[0] != size else im
            arr = np.asarray(im)
            rgb = luma_clamp(arr[..., :3])
            arr = np.dstack([rgb, arr[..., 3]]) if set_name == "Fur" else rgb
            im = Image.fromarray(arr, "RGBA" if set_name == "Fur" else "RGB")
        elif kind == "NOR":
            n = np.asarray(im.convert("RGB").resize((size, size), Image.LANCZOS) if im.size[0] != size else im.convert("RGB"),
                           np.float32) / 127.5 - 1.0
            n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
            # the harness shell's inner (body-side) faces bake with their tangent frame flipped (about 3% of texels,
            # never seen): flatten any texel that points into the surface
            back = n[..., 2] < 0.05
            n[back] = (0.0, 0.0, 1.0)
            im = Image.fromarray(((n + 1) * 127.5).clip(0, 255).round().astype(np.uint8), "RGB")
        else:
            im = im.convert("L")
            im = im.resize((size, size), Image.LANCZOS) if im.size[0] != size else im
        im.save(os.path.join(OUT, name), optimize=True)
        print("%-30s %d px %s" % (name, size, im.mode))
    sig = os.path.join(MASKS, "T_Bosun_Harness_SIG.png")
    if os.path.isfile(sig):
        m = Image.fromarray(dilate_fill(np.asarray(Image.open(sig).convert("L")), coverage("Harness"))).resize((SIZES["Harness"],) * 2, Image.LANCZOS)
        Image.fromarray(np.where(np.asarray(m) > 100, 255, 0).astype(np.uint8), "L").save(os.path.join(MASKS, "harness_signal.png"))
        print("signal mask", os.path.join(MASKS, "harness_signal.png"))


if __name__ == "__main__":
    main()
