#!/usr/bin/env python3
"""Render the badge coin set and the review contact sheet.

usage: python3 build.py [Key ...]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import iconlib as L
import badges

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, ".."))


def render(keys=None):
    made = []
    for key, fn in badges.BADGES:
        if keys and key not in keys:
            continue
        img = fn(L.coin)
        path = os.path.join(OUT, key + ".png")
        L.finalize(img, path)
        made.append(path)
        print("wrote", path)
    return made


def sheet():
    cell, gap, pad = 128, 14, 20
    cols = 5
    label_h = 20
    group_h = 26
    row_h = cell + 8 + 64 + 8 + label_h
    w = pad * 2 + cols * cell + (cols - 1) * gap
    rows_total = sum((len(keys) + cols - 1) // cols for _g, keys in badges.GROUPS)
    h = pad * 2 + 40 + rows_total * (row_h + gap) + len(badges.GROUPS) * (group_h + 10)
    sheet = Image.new("RGBA", (w, h), (16, 22, 31, 255))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
        big = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
        grp = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11, index=1)
    except Exception:
        font = big = grp = ImageFont.load_default()
    d.text((pad, pad - 6), "Mayday badges - 31 medals, 128 px + circle-cropped 64 px",
           font=big, fill=(232, 238, 244))
    y0 = pad + 38
    for group, keys in badges.GROUPS:
        d.text((pad, y0), group.upper(), font=grp, fill=(124, 158, 186))
        y0 += group_h
        for i, key in enumerate(keys):
            c, r = i % cols, i // cols
            x = pad + c * (cell + gap)
            y = y0 + r * (row_h + gap)
            im = Image.open(os.path.join(OUT, key + ".png")).convert("RGBA")
            sheet.alpha_composite(im.resize((cell, cell), Image.LANCZOS), (x, y))
            crop = im.resize((64, 64), Image.LANCZOS)
            mask = Image.new("L", (64, 64), 0)
            ImageDraw.Draw(mask).ellipse([0, 0, 63, 63], fill=255)
            sheet.paste(crop, (x + cell // 2 - 32, y + cell + 8), mask)
            d.ellipse([x + cell // 2 - 32, y + cell + 8, x + cell // 2 + 31, y + cell + 71],
                      outline=(60, 74, 90, 255))
            d.text((x + cell // 2 - d.textlength(key, font=font) / 2, y + cell + 74),
                   key, font=font, fill=(176, 190, 204))
        y0 += ((len(keys) + cols - 1) // cols) * (row_h + gap)
    path = os.path.join(OUT, "_sheet.png")
    sheet.convert("RGB").save(path)
    print("wrote", path)


if __name__ == "__main__":
    keys = sys.argv[1:]
    render(keys or None)
    if not keys:
        sheet()
