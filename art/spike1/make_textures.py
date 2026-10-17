#!/usr/bin/env python3
"""Spike 1 texture test sets (system python3 + Pillow + numpy, no Blender).

Writes assets/textures/Spike1/T_Spike1_<Size>_<ALB|NOR|RGH|MET>.png for Size in 1024, 2048, 4096.
ALB reveals downsampling: zones of 1-px / 2-px / 4-px / 8-px checkers and 1-px line gratings (labelled), a big size label,
and a 32x32 single-pixel checker in each corner (red/cyan) inside a 1-px alternating border.
NOR: OpenGL tangent-space (green = +V up), flat-ish with a fine dot pattern. RGH / MET: single-channel L PNGs.
usage: python3 art/spike1/make_textures.py"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "textures", "Spike1")
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
LO, HI = 40, 220          # albedo kept inside the 30..240 sRGB rule


def font(px):
    return ImageFont.truetype(FONT, max(8, int(px)))


def checker(h, w, cell):
    y, x = np.mgrid[0:h, 0:w]
    return (((x // cell) + (y // cell)) % 2).astype(bool)


def albedo(S):
    img = np.full((S, S, 3), 128, np.uint8)
    top = S // 4
    # zones: 2 rows x 3 columns under the label band
    zw, zh = S // 3, (S - top) // 2
    zones = [("1px checker", lambda h, w: checker(h, w, 1)), ("2px checker", lambda h, w: checker(h, w, 2)),
             ("4px checker", lambda h, w: checker(h, w, 4)), ("1px vert lines", lambda h, w: (np.mgrid[0:h, 0:w][1] % 2).astype(bool)),
             ("1px horiz lines", lambda h, w: (np.mgrid[0:h, 0:w][0] % 2).astype(bool)), ("8px checker", lambda h, w: checker(h, w, 8))]
    pad = max(4, S // 128)
    rects = []
    for i, (label, fn) in enumerate(zones):
        r, c = divmod(i, 3)
        x0, y0 = c * zw + pad, top + r * zh + pad
        w, h = zw - 2 * pad, zh - 2 * pad
        m = fn(h, w)
        img[y0:y0 + h, x0:x0 + w] = np.where(m[..., None], HI, LO)
        rects.append((label, x0, y0, w))
    # corner pixel grids (red / cyan single pixels) and a 1-px alternating border
    g = 32
    cg = checker(g, g, 1)
    corner = np.where(cg[..., None], np.array([220, 40, 40], np.uint8), np.array([40, 220, 220], np.uint8))
    for (y, x) in ((0, 0), (0, S - g), (S - g, 0), (S - g, S - g)):
        img[y:y + g, x:x + g] = corner
    edge = (np.arange(S) % 2).astype(bool)
    for sl in (np.s_[0, :], np.s_[S - 1, :], np.s_[:, 0], np.s_[:, S - 1]):
        img[sl] = np.where(edge[:, None], np.array([220, 220, 40], np.uint8), np.array([40, 40, 200], np.uint8))
    im = Image.fromarray(img, "RGB")
    d = ImageDraw.Draw(im)
    # label band
    d.rectangle([g + pad, pad, S - g - pad, top - pad], fill=(30 + 10, 60, 110))
    f = font(top * 0.62)
    txt = str(S)
    bb = d.textbbox((0, 0), txt, font=f)
    d.text(((S - (bb[2] - bb[0])) / 2 - bb[0], (top - (bb[3] - bb[1])) / 2 - bb[1]), txt, font=f, fill=(235, 220, 60))
    fs = font(S / 36)
    for label, x0, y0, w in rects:
        bb = d.textbbox((0, 0), label, font=fs)
        d.rectangle([x0, y0, x0 + bb[2] - bb[0] + 2 * pad, y0 + bb[3] - bb[1] + 2 * pad], fill=(200, 60, 40))
        d.text((x0 + pad - bb[0], y0 + pad - bb[1]), label, font=fs, fill=(235, 235, 235))
    return im


def normal(S):
    # fine dot field: height = sum of small gaussian bumps every 16 px, OpenGL (green = up)
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    p = 16.0
    fx, fy = (x % p) - p / 2 + 0.5, (y % p) - p / 2 + 0.5
    h = np.exp(-(fx ** 2 + fy ** 2) / (2 * 2.5 ** 2))
    dhdx = np.gradient(h, axis=1)
    dhdrow = np.gradient(h, axis=0)
    k = 1.5
    nx, ny, nz = -dhdx * k, dhdrow * k, np.ones_like(h)   # v points up = -row, so -dh/dv = +dh/drow
    n = np.stack([nx, ny, nz], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(np.clip((n * 0.5 + 0.5) * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")


def rough(S):
    y, x = np.mgrid[0:S, 0:S]
    base = 60 + (x / (S - 1)) * 160                      # left glossy -> right rough
    base = base + np.where(checker(S, S, 4), 12, -12)    # fine pattern (reveals downsampling)
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "L")


def metal(S):
    y, x = np.mgrid[0:S, 0:S]
    m = np.where((y // (S // 8)) % 2 == 1, 255, 0)       # 8 horizontal bands, alternating metal / dielectric
    m = np.where(checker(S, S, 2) & (x < S // 16), 255 - m, m)   # 2-px checker strip at the left edge
    return Image.fromarray(m.astype(np.uint8), "L")


def main():
    os.makedirs(OUT, exist_ok=True)
    for S in (1024, 2048, 4096):
        for kind, fn in (("ALB", albedo), ("NOR", normal), ("RGH", rough), ("MET", metal)):
            p = os.path.join(OUT, f"T_Spike1_{S}_{kind}.png")
            im = fn(S)
            im.save(p, optimize=False)
            print(p, im.mode, im.size, os.path.getsize(p))


if __name__ == "__main__":
    main()
