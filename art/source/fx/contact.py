#!/usr/bin/env python3
"""FX1 / FX2 contact sheet: every flipbook / foam map from assets/textures/FX composited over an overcast sky
(top half) and a dark sea (bottom half), so alpha edges, density and colour read against both. Emissive sheets
are composited additively over a night sky / sea. Writes assets/review/FX/contact.png (<= 1600 px wide).

    python3 art/source/fx/contact.py
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SRC = os.path.join(ROOT, "assets", "textures", "FX")
OUT = os.path.join(ROOT, "assets", "review", "FX", "contact.png")
TILE, COLS, PAD, LABEL = 384, 4, 8, 22
SKY, SEA = (150, 162, 168), (44, 58, 62)
NIGHT_SKY, NIGHT_SEA = (22, 26, 34), (10, 14, 18)


def backdrop(emissive):
    bg = Image.new("RGB", (TILE, TILE), NIGHT_SKY if emissive else SKY)
    ImageDraw.Draw(bg).rectangle([0, TILE // 2, TILE, TILE], fill=NIGHT_SEA if emissive else SEA)
    return bg


def tile(name):
    with open(os.path.join(SRC, name + ".json")) as f:
        info = json.load(f)
    im = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA").resize((TILE, TILE), Image.LANCZOS)
    bg = backdrop(info["kind"] == "emissive")
    if info["kind"] == "emissive":  # additive (LightEmission 1): colour * alpha added to the backdrop
        r, g, b, a = im.split()
        add = Image.merge("RGB", (r, g, b))
        add = Image.composite(add, Image.new("RGB", add.size), a)
        from PIL import ImageChops
        bg = ImageChops.add(bg, add)
    else:
        bg.paste(im, (0, 0), im)
    label = "%s  %s %s" % (name, info["layout"], info["kind"])
    return bg, label


def main():
    names = sorted(n[:-5] for n in os.listdir(SRC) if n.endswith(".json"))
    order = ["FX_Spray_", "FX_Foam_", "FX_Rain_", "FX_Smoke_", "FX_Flare_", "FX_Under_"]
    names.sort(key=lambda n: (next((i for i, p in enumerate(order) if n.startswith(p)), 9), n))
    rows = (len(names) + COLS - 1) // COLS
    W = COLS * TILE + (COLS + 1) * PAD
    H = rows * (TILE + LABEL + PAD) + PAD + 30
    sheet = Image.new("RGB", (W, H), (28, 30, 32))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 15)
        big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 18)
    except OSError:
        font = big = ImageFont.load_default()
    d.text((PAD, 6), "FX1 / FX2 flipbooks and foam maps (Blender Mantaflow + particle sims, Cycles). Top: overcast sky,"
                     " bottom: sea; emissive sheets added over night", fill=(230, 230, 230), font=big)
    for i, n in enumerate(names):
        r, c = divmod(i, COLS)
        x = PAD + c * (TILE + PAD)
        y = 30 + PAD + r * (TILE + LABEL + PAD)
        im, label = tile(n)
        sheet.paste(im, (x, y))
        d.text((x + 2, y + TILE + 3), label, fill=(220, 220, 220), font=font)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, optimize=True)
    print("contact", OUT, sheet.size, len(names), "sheets")


if __name__ == "__main__":
    main()
