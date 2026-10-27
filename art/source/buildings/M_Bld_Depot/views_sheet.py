"""Composes the Depot level contact sheet from views.py renders (system python3 + Pillow).

    python3 art/source/buildings/M_Bld_Depot/views_sheet.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
SRC = os.path.join(G, "build/prod/M_Bld_Depot/review/M_Bld_Depot/levels")
OUT = os.path.join(SRC, "levels_sheet.png")
COPY = os.path.join(HERE, "sheet_levels.png")
ROWS = (("Lv1", "Lv1  walk-in bay + yard"), ("Lv2", "Lv2  + second bay"), ("Lv3", "Lv3  + conveyor + hopper"),
        ("Quay", "FreightQuay  jetty"), ("Lv3Quay", "Lv3  + freight quay"),
        ("Moored", "Moored barge  ATT x 32.8"))
VIEWS = ("Front3Q", "Side", "High", "Interior", "CutAway")
LABEL, TITLE, CELL, HEAD = 90, 46, 400, 30
BG, INK, DIM = (24, 27, 29), (232, 234, 235), (150, 155, 160)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


w = LABEL + len(VIEWS) * CELL
h = TITLE + len(ROWS) * (HEAD + CELL)
sheet = Image.new("RGB", (w, h), BG)
d = ImageDraw.Draw(sheet)
d.text((16, 12), "M_Bld_Depot - levels (turntable neutral HDRI)", font=font(20), fill=INK)
for r, (key, label) in enumerate(ROWS):
    y = TITLE + r * (HEAD + CELL)
    d.text((12, y + 8), key, font=font(18), fill=INK)
    d.text((12, y + 30), label.split("  ")[1], font=font(11), fill=DIM)
    for c, view in enumerate(VIEWS):
        path = os.path.join(SRC, "level_%s_%s.png" % (key, view))
        if not os.path.exists(path):        # interior / cut-away only for Lv1..Lv3
            continue
        img = Image.open(path).convert("RGB")
        img = img.resize((CELL, CELL), Image.LANCZOS)
        x = LABEL + c * CELL
        sheet.paste(img, (x, y + HEAD))
        d.text((x + 6, y + HEAD + 4), view, font=font(12), fill=INK)
sheet.save(OUT)
sheet.save(COPY)
print(OUT)
print(COPY)
