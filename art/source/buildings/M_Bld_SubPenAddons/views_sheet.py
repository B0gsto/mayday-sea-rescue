"""Composes the SubPenAddons level contact sheet from views.py renders (system python3 + Pillow).

    python3 art/source/buildings/M_Bld_SubPenAddons/views_sheet.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
SRC = os.path.join(G, "build/prod/M_Bld_SubPenAddons/review/M_Bld_SubPenAddons/levels")
OUT = os.path.join(SRC, "levels_sheet.png")
COPY = os.path.join(HERE, "sheet_levels.png")
ROWS = (
    ("Lv2", "Lv2  gantry, hoist, hanging mini-sub, dive rack",
     (("Lv2_Front", "3/4 front"), ("Lv2_Side", "side"), ("Lv2_Top", "top"))),
    ("Lv2+Lv3", "Lv2 + Lv3  salvage wet dock, pontoon and treasure",
     (("Lv2Lv3_Front", "3/4 back"), ("Lv2Lv3_Side", "side"), ("Lv2Lv3_Top", "top"))),
    ("Details", "details  gantry + sub, dive rack, salvage entry",
     (("Detail_Gantry", "gantry + sub"), ("Detail_DiveRack", "dive rack"), ("Detail_Salvage", "salvage dock"))),
    ("Details", "details  treasure, crane, flag sign",
     (("Detail_Treasure", "treasure"), ("Detail_Crane", "crane"), ("Detail_Flag", "flag sign"))),
)
LABEL, TITLE, CELL, HEAD = 90, 58, 400, 30
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
d.text((16, 12), "M_Bld_SubPenAddons - levels (neutral HDRI, ground at the pen plinth top z 0.80)", font=font(20),
       fill=INK)
d.text((16, 36), "Lv1 (plinth, deck, pool, dome, grey gantry) is code-built in DockPieces.subPen()", font=font(13),
       fill=DIM)
for r, (key, label, cells) in enumerate(ROWS):
    y = TITLE + r * (HEAD + CELL)
    d.text((12, y + 8), key, font=font(18), fill=INK)
    d.text((12, y + 30), label.split("  ")[1], font=font(11), fill=DIM)
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
