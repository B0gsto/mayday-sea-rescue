"""Composes the LookoutAddons level contact sheet from views.py renders (system python3 + Pillow).

    python3 art/source/buildings/M_Bld_LookoutAddons/views_sheet.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
SRC = os.path.join(G, "build/prod/M_Bld_LookoutAddons/review/M_Bld_LookoutAddons/levels")
OUT = os.path.join(SRC, "levels_sheet.png")
COPY = os.path.join(HERE, "sheet_levels.png")
ROWS = (
    ("Lv2", ("gallery,", "lantern room"),
     (("Lv2_Front", "front 3/4"), ("Lv2_Side", "side"), ("Lv2_Top", "top"))),
    ("Lv2+Lv3", ("searchlight,", "radar"),
     (("Lv2Lv3_Front", "front 3/4"), ("Lv2Lv3_Side", "side"), ("Lv2Lv3_Top", "top"))),
    ("details", ("close reads",),
     (("Deck", "deck, telescope + bell"), ("Lantern", "lantern room"), ("Searchlight", "searchlight"))),
)
LABEL, TITLE, CELL, HEAD = 90, 46, 400, 30
BG, INK, DIM = (24, 27, 29), (232, 234, 235), (150, 155, 160)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


w = LABEL + 3 * CELL
h = TITLE + len(ROWS) * (HEAD + CELL)
sheet = Image.new("RGB", (w, h), BG)
d = ImageDraw.Draw(sheet)
d.text((16, 12), "M_Bld_LookoutAddons - levels (grey code tower proxy, neutral HDRI)", font=font(20), fill=INK)
for r, (key, label, cells) in enumerate(ROWS):
    y = TITLE + r * (HEAD + CELL)
    d.text((12, y + 6), key, font=font(17), fill=INK)
    for k, line in enumerate(label):
        d.text((12, y + 25 + 12 * k), line, font=font(10), fill=DIM)
    for c, (stem, caption) in enumerate(cells):
        path = os.path.join(SRC, "view_%s.png" % stem)
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGB").resize((CELL, CELL), Image.LANCZOS)
        x = LABEL + c * CELL
        sheet.paste(img, (x, y + HEAD))
        d.text((x + 6, y + HEAD + 4), caption, font=font(12), fill=INK)
sheet.save(OUT)
sheet.save(COPY)
print(OUT)
print(COPY)
