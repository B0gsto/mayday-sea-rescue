#!/usr/bin/env python3
"""Per-shot pixel stats for an ocean capture round (no eyes needed).

usage: python3 art/ocean/shot_stats.py build/ocean/round<N>
For every shot: mean luma, % near-black pixels, a 12-bin hue histogram of saturated pixels, and the
"cyan slab" detector: % of pixels with hue 165-200 deg, saturation > 0.45 and value > 0.25 (the
art director's saturated cyan), plus where they sit (row band of the frame). Flags BLACK and CYAN.
"""
import os
import sys

from PIL import Image


def stats(path):
    im = Image.open(path).convert("RGB")
    im = im.resize((320, int(im.height * 320 / im.width)))
    w, h = im.size
    hsv = im.convert("HSV")
    px, hp = list(im.getdata()), list(hsv.getdata())
    n = len(px)
    luma = sum(0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in px) / n
    black = sum(1 for r, g, b in px if max(r, g, b) < 12) / n
    hist = [0] * 12
    cyan_rows = [0] * 4
    cyan = 0
    for i, (hh, s, v) in enumerate(hp):
        if s > 90 and v > 50:
            hist[hh * 12 // 256] += 1
        deg = hh * 360 / 255
        if 165 <= deg <= 200 and s > 115 and v > 64:
            cyan += 1
            cyan_rows[min(3, (i // w) * 4 // h)] += 1
    flags = []
    if luma < 18 or black > 0.6:
        flags.append("BLACK")
    if cyan / n > 0.03:
        flags.append("CYAN")
    return luma, black, [round(100 * x / n) for x in hist], 100 * cyan / n, [round(100 * c / n, 1) for c in cyan_rows], flags


def main():
    d = sys.argv[1]
    for f in sorted(os.listdir(d)):
        if f.endswith(".png"):
            luma, black, hist, cyan, rows, flags = stats(os.path.join(d, f))
            print(f"{f[:-4]:22s} luma {luma:5.1f} black {100*black:4.0f}% cyan {cyan:4.1f}% rows {rows} "
                  f"hue30 {hist} {' '.join(flags)}")


if __name__ == "__main__":
    main()
