#!/usr/bin/env python3
"""LEGACY fallback - superseded by fur_atlas.py (strands grown and rendered in Blender, then assembled):

    ~/RobloxProjects/tools/blender-run.sh art/source/characters/M_Chr_Bosun/fur_atlas.py
    python3 art/source/characters/M_Chr_Bosun/fur_atlas.py

Running this file overwrites the rendered masters with the old line-drawn atlas; keep it only as a no-Blender
fallback (same atlas layout and file names).

Fur-card atlas for M_Chr_Bosun (system python3, Pillow + numpy; no heavy slot).

    python3 art/source/characters/M_Chr_Bosun/fur_textures.py [--size 4096]

4 x 2 atlas (columns: long wavy clump, medium clump, short tuft, tail plume; rows: two variants), each cell a
clump of hand-placed tapered strands rooted at the cell bottom (V = 0 of the cell) and gathered into tips.
Black double coat: dark roots, a little brown sun-bleaching towards some tips. _Wet: the same cells with the strands
pulled into fewer, pointed, darker and glossier clumps. Writes T_Bosun_Fur_<ALB|NOR|RGH|MET>[_Wet].png masters
(ALB is RGBA: alpha = strand coverage) into textures/ next to this file; finalize.py downsizes them for shipping.
"""
import argparse
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "textures")
KINDS = [  # strands, clumps, length range (fraction of cell height), spread (fraction of width), wave
    dict(n=150, clumps=4, length=(0.72, 0.97), spread=0.62, wave=0.035, width=(3.2, 5.0)),
    dict(n=120, clumps=3, length=(0.65, 0.95), spread=0.58, wave=0.025, width=(3.0, 4.6)),
    dict(n=110, clumps=4, length=(0.45, 0.90), spread=0.80, wave=0.015, width=(2.6, 4.0)),
    dict(n=190, clumps=6, length=(0.70, 0.98), spread=0.82, wave=0.04, width=(3.0, 5.0)),
]


def lerp(a, b, t):
    return a + (b - a) * t


def draw_cell(alb, alpha, rgh, x0, y0, cw, ch, kind, seed, wet, scale):
    rng = random.Random(seed)
    k = KINDS[kind]
    clumps = max(2, k["clumps"] - (2 if wet else 0))
    tips = [(lerp(0.5 - k["spread"] / 2.4, 0.5 + k["spread"] / 2.4, (i + 0.5) / clumps) + rng.uniform(-0.05, 0.05),
             rng.uniform(*k["length"])) for i in range(clumps)]
    da, dc, dr = alpha, alb, rgh
    n = int(k["n"] * 1.8 * (0.8 if wet else 1.0))
    for s in range(n):
        ci = rng.randrange(clumps)
        tx, tl = tips[ci]
        rx = 0.5 + rng.gauss(0, k["spread"] / 4.2)
        rx = min(max(rx, 0.06), 0.94)
        stray = rng.random() < (0.04 if wet else 0.18)
        pull = (0.95 if wet else 0.62) * (0.3 if stray else 1.0)
        length = tl * rng.uniform(0.75, 1.02) * (rng.uniform(0.6, 0.95) if stray else 1.0)
        ex = lerp(rx + rng.uniform(-0.12, 0.12), tx, pull)
        w0 = rng.uniform(*k["width"]) * scale * (0.85 if wet else 1.0)
        phase = rng.uniform(0, 2 * math.pi)
        amp = k["wave"] * rng.uniform(0.4, 1.3) * (0.4 if wet else 1.0)
        base = rng.uniform(34, 46) if not wet else rng.uniform(31, 36)
        bleach = 0.0 if wet else max(0.0, rng.uniform(-0.4, 0.7))
        tipc = (74, 58, 46)
        rough = rng.uniform(0.52, 0.68) if not wet else rng.uniform(0.2, 0.3)
        segs = 14
        pts = []
        for i in range(segs + 1):
            t = i / segs
            # root to tip: gather towards the clump tip along an ease curve, with a lateral wave
            g = t ** (1.6 if wet else 1.3)
            x = lerp(rx, ex, g) + amp * math.sin(phase + t * 5.0) * t
            y = 0.015 + length * t
            pts.append((x0 + x * cw, y0 + ch - y * ch))
        for i in range(segs):
            t = i / segs
            w = max(1.0, w0 * (1.0 - t) ** (0.9 if wet else 0.7))
            a = int(255 * min(1.0, 0.35 + 3.0 * t) * (1.0 if t < 0.85 else (1 - t) / 0.15 * 0.8 + 0.2))
            v = lerp(base, base * 0.92, 1 - t)
            tb = bleach * max(0.0, t - 0.45) / 0.55
            col = tuple(int(lerp(v, c, tb)) for c in tipc)
            seg = [pts[i], pts[i + 1]]
            da.line(seg, fill=a, width=int(round(w)))
            dc.line(seg, fill=col, width=int(round(w)))
            dr.line(seg, fill=int(rough * 255), width=int(round(w)))


def make(size, wet):
    alpha = Image.new("L", (size, size), 0)
    alb = Image.new("RGB", (size, size), (38, 36, 35) if not wet else (32, 31, 31))
    rgh = Image.new("L", (size, size), int((0.6 if not wet else 0.25) * 255))
    da, dc, dr = ImageDraw.Draw(alpha), ImageDraw.Draw(alb), ImageDraw.Draw(rgh)
    cw, ch = size // 4, size // 2
    scale = size / 4096.0
    for col in range(4):
        for row in range(2):
            # UV row 0 is the bottom half of the image
            y0 = size - (row + 1) * ch
            draw_cell(dc, da, dr, col * cw, y0, cw, ch, col, 1000 + col * 10 + row, wet, scale)
    a = np.asarray(alpha, np.float32) / 255.0
    h = np.asarray(alpha.filter(ImageFilter.GaussianBlur(1.6 * scale * 2)), np.float32) / 255.0
    gy, gx = np.gradient(h)
    k = 2.2 if not wet else 3.0
    nx, ny, nz = -gx * k * 10, gy * k * 10, np.ones_like(h)        # OpenGL: +Y up the texture
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nor = np.stack([(nx / ln + 1) * 127.5, (ny / ln + 1) * 127.5, (nz / ln + 1) * 127.5], axis=-1).clip(0, 255).astype(np.uint8)
    rgba = np.dstack([np.asarray(alb, np.uint8), (a * 255).astype(np.uint8)])
    suffix = "_Wet" if wet else ""
    Image.fromarray(rgba).save(os.path.join(OUT, "T_Bosun_Fur_ALB%s.png" % suffix))
    Image.fromarray(nor).save(os.path.join(OUT, "T_Bosun_Fur_NOR%s.png" % suffix))
    rgh.save(os.path.join(OUT, "T_Bosun_Fur_RGH%s.png" % suffix))
    if not wet:
        Image.new("L", (size, size), 0).save(os.path.join(OUT, "T_Bosun_Fur_MET.png"))
    print("fur atlas %s %d px, coverage %.1f%%" % ("wet" if wet else "dry", size, 100 * a.mean()))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--size", type=int, default=4096)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    make(a.size, False)
    make(a.size, True)
