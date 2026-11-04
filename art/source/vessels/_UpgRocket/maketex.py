"""Writes the flat palette set T_UpgRocket_Palette_{ALB,NOR,RGH,MET} (system python3, Pillow): python3 maketex.py"""
import ast
import os
import re

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "../../../../build/prod/_UpgRocket/textures"))
src = open(os.path.join(HERE, "kit.py")).read()
PALETTE = ast.literal_eval(re.search(r"^PALETTE = (\[.*?^\])", src, re.S | re.M).group(1))
SIZE, GRID = 256, 4
cell = SIZE // GRID
os.makedirs(OUT, exist_ok=True)
maps = {k: Image.new("RGB", (SIZE, SIZE)) for k in ("ALB", "RGH", "MET")}
for i, (hexc, rough, metal) in enumerate(PALETTE):
    col, row = i % GRID, GRID - 1 - i // GRID      # image row 0 is the top; cell 0 is bottom-left in UV
    box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
    maps["ALB"].paste(tuple(int(hexc[k:k + 2], 16) for k in (0, 2, 4)), box)
    maps["RGH"].paste((round(rough * 255),) * 3, box)
    maps["MET"].paste((round(metal * 255),) * 3, box)
maps["NOR"] = Image.new("RGB", (SIZE, SIZE), (128, 128, 255))
for k, im in maps.items():
    im.save(os.path.join(OUT, "T_UpgRocket_Palette_%s.png" % k))
print(OUT)
