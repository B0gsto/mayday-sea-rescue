#!/usr/bin/env python3
"""Brightwake Games group emblem concepts (512, full bleed)."""
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import iconlib as L

OUT = "../../group/"


def bg(warm=True):
    img = L.canvas(bg_center=(22, 56, 88), bg_edge=(4, 10, 18),
                   glow=L.AMBER if warm else L.TEAL, glow_a=54)
    # horizon glow
    g = Image.new("L", (L.PX, L.PX), 0)
    ImageDraw.Draw(g).rectangle([0, int(300 * L.SS), L.PX, L.PX], fill=255)
    g = g.filter(ImageFilter.GaussianBlur(50 * L.SS))
    img = L.fill_mask(img, g, L.AMBER, 12)
    return img


def spark(img, cx, cy, r, col=(255, 240, 190), glow_a=150):
    m = Image.new("L", (L.PX, L.PX), 0)
    d = ImageDraw.Draw(m)
    pts = []
    for i in range(8):
        a = math.pi * 2 * i / 8 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.26
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon([(x * L.SS, y * L.SS) for x, y in pts], fill=255)
    img = L.glow(img, m, L.AMBER, r * 0.5, glow_a)
    img = L.paint(img, m, L.grad_v([(0, (255, 252, 232)), (1, L.GOLD)]))
    return img


def streak(img, pts, w0, w1, c_in=(255, 236, 170), c_out=(250, 124, 74), a=255):
    m = L.stroke_mask(L.smooth(pts, closed=False, n=18), w0, w1)
    grad = L.grad_radial(c_in, c_out, cx=196, cy=318, r=300)
    return L.paint(img, m, grad, a)


def wake(img, cx, cy, r, a0, a1, w0, w1, ry=1.0, cols=None, alpha=255, blur=0):
    m = Image.new("L", (L.PX, L.PX), 0)
    pts = []
    n = 120
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * ry))
    w = w0
    for i, (x, y) in enumerate(pts):
        t = i / max(1, len(pts) - 1)
        ww = (w0 + (w1 - w0) * t) * L.SS
        d = ImageDraw.Draw(m)
        d.ellipse([x * L.SS - ww / 2, y * L.SS - ww / 2, x * L.SS + ww / 2, y * L.SS + ww / 2], fill=255)
        if i:
            px, py = pts[i - 1]
            d.line([px * L.SS, py * L.SS, x * L.SS, y * L.SS], fill=255, width=int(max(1, ww)))
    if blur:
        m = m.filter(ImageFilter.GaussianBlur(blur * L.SS))
    if cols is None:
        cols = L.grad_radial((255, 236, 168), L.CORAL, cx=cx, cy=cy, r=r + w0)
    img = L.paint(img, m, cols, alpha)
    return img


def ribbon(img, pts, wmax, c_in=(255, 228, 152), c_out=(236, 94, 64), power=0.8):
    path = L.smooth(pts, closed=False, n=26)
    m = Image.new("L", (L.PX, L.PX), 0)
    d = ImageDraw.Draw(m)
    n = len(path)
    for i, (x, y) in enumerate(path):
        t = i / max(1, n - 1)
        w = max(1.6, wmax * math.sin(math.pi * t) ** power) * L.SS
        d.ellipse([x * L.SS - w / 2, y * L.SS - w / 2, x * L.SS + w / 2, y * L.SS + w / 2], fill=255)
        if i:
            px, py = path[i - 1]
            d.line([px * L.SS, py * L.SS, x * L.SS, y * L.SS], fill=255, width=int(max(1, w)))
    img = L.glow(img, m, c_out, 28, 90)
    img = L.paint(img, m, L.grad_radial(c_in, c_out, cx=214, cy=284, r=340))
    return img, m


def emblem_main():
    img = bg()
    # sun sitting on a sweeping wake ribbon
    sun = L.circle_mask(196, 276, 96)
    img = L.glow(img, sun, L.AMBER, 44, 100)
    img = L.paint(img, sun, L.grad_v([(0, (255, 242, 188)), (0.48, (255, 192, 90)), (1, (238, 102, 64))]))
    gl = ImageChops.multiply(sun, L.ellipse_mask([122, 194, 278, 284], blur=18))
    img = L.fill_mask(img, gl, (255, 252, 232), 60)
    # one continuous ribbon, thickest mid-sweep
    img, m = ribbon(img, [(84, 302), (104, 364), (168, 404), (252, 410), (330, 388), (410, 336), (474, 244)], 38)
    # highlight along the crest
    hl = L.stroke_mask(L.smooth([(120, 356), (176, 388), (256, 392), (330, 372)],
                                closed=False, n=20), 4, 7)
    hl = ImageChops.multiply(hl, m)
    img = L.fill_mask(img, hl, (255, 250, 224), 140)
    img = L.spec_arc(img, 196, 276, 62, 200, 300, width=4, alpha=70, color=(255, 255, 245), blur=3)
    img = spark(img, 420, 180, 28)
    img = spark(img, 112, 188, 14, glow_a=100)
    return img


def emblem_alt1():
    """Monogram tile: a bold B in warm light."""
    from PIL import ImageFont
    img = bg()
    tile = L.rrect_mask([64, 64, 448, 448], 96)
    img = L.shadow(img, tile, 0, 10, 16, 130)
    img = L.paint(img, tile, L.grad_v([(0, (20, 52, 82)), (1, (6, 16, 28))]))
    img = L.outline(img, tile, 2.4, 90)
    inner = L.rrect_mask([80, 80, 432, 432], 82)
    img = L.outline(img, inner, 1.6, 80, (255, 210, 140))
    # B from a heavy grotesque, filled with the warm gradient
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 300 * L.SS)
    m = Image.new("L", (L.PX, L.PX), 0)
    d = ImageDraw.Draw(m)
    bbox = d.textbbox((0, 0), "B", font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((L.PX - w) / 2 - bbox[0], (L.PX - h) / 2 - bbox[1] - 6 * L.SS),
           "B", font=font, fill=255)
    img = L.glow(img, m, L.AMBER, 26, 110)
    img = L.paint(img, m, L.grad_v([(0, (255, 240, 182)), (0.45, (255, 190, 96)), (1, (232, 96, 62))]))
    # top gloss inside the letter
    gl = ImageChops.multiply(m, L.rrect_mask([90, 90, 424, 250], 70, blur=30))
    img = L.fill_mask(img, gl, (255, 252, 236), 50)
    img = spark(img, 360, 128, 24)
    return img


def emblem_alt2():
    """Wave ribbon: a tapered wake curling under a small sun."""
    img = bg()
    halo = L.ellipse_mask([90, 140, 430, 440], blur=44)
    img = L.fill_mask(img, halo, L.CORAL, 26)
    left = L.stroke_mask(L.smooth([(62, 322), (128, 258), (206, 228), (262, 238)],
                                  closed=False, n=20), 2, 38)
    right = L.stroke_mask(L.smooth([(262, 238), (322, 268), (374, 326), (420, 344), (462, 330)],
                                   closed=False, n=20), 38, 2)
    m = ImageChops.lighter(left, right)
    img = L.glow(img, m, L.CORAL, 28, 90)
    img = L.paint(img, m, L.grad_radial((255, 228, 154), (236, 96, 66), cx=210, cy=248, r=330))
    # light along the ridge
    hl = L.stroke_mask(L.smooth([(72, 306), (128, 246), (204, 216), (258, 226)],
                                closed=False, n=18), 7, 12)
    img = L.fill_mask(img, hl, (255, 248, 220), 140)
    hl2 = L.stroke_mask(L.smooth([(264, 232), (306, 256), (348, 296)], closed=False, n=14), 10, 5)
    img = L.fill_mask(img, hl2, (255, 244, 210), 110)
    # sun in the curl
    sun = L.circle_mask(300, 206, 34)
    img = L.glow(img, sun, L.AMBER, 20, 130)
    img = L.paint(img, sun, L.grad_v([(0, (255, 246, 204)), (1, L.AMBER)]))
    img = spark(img, 410, 168, 26)
    img = spark(img, 132, 380, 14, glow_a=100)
    return img


def main():
    for name, fn in [("emblem_512", emblem_main), ("emblem_alt1", emblem_alt1),
                     ("emblem_alt2", emblem_alt2)]:
        img = fn()
        path = OUT + name + ".png"
        L.finalize(img, path)
        print("wrote", path)


if __name__ == "__main__":
    main()
