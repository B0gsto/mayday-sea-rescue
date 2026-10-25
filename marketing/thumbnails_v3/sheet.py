#!/usr/bin/env python3
"""sheet.py: hero_sheet.png, a 2x4 grid of hero_<n>_*.png (1600 px wide), each tile labelled with its number."""
import glob, os
from PIL import Image, ImageDraw
D = os.path.dirname(os.path.abspath(__file__))
files = sorted(glob.glob(os.path.join(D, "hero_[0-9]_*.png")))
W, cols = 1600, 2
tw = W // cols
th = tw * 9 // 16
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (W, th * rows), "black")
for i, f in enumerate(files):
    im = Image.open(f).convert("RGB").resize((tw, th), Image.LANCZOS)
    ImageDraw.Draw(im).text((10, 8), os.path.basename(f)[:-4], fill="white")
    sheet.paste(im, ((i % cols) * tw, (i // cols) * th))
sheet.save(os.path.join(D, "hero_sheet.png"))
print("sheet", len(files), sheet.size)
