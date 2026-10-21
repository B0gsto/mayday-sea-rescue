"""POL1 contact sheet: merges assets/review/POL1/shots_A (HP1 quay kit) and shots_B (R1a road textures), every shot
as a dry | wet pair, into assets/review/POL1/contact.png (1600 px wide).
    python3 art/source/_pol1/sheet.py"""
import glob
import os
from PIL import Image, ImageDraw, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
R = G + "assets/review/POL1/"
OUT = R + "contact.png"
W, COLS, H, BAR = 400, 4, 300, 22
f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 14)

cells = []
for kit, tag in (("shots_A", "HP1"), ("shots_B", "R1a")):
    labels = sorted({os.path.basename(p)[:-8] for p in glob.glob(R + kit + "/*_dry.png")})
    for lab in labels:
        for st in ("dry", "wet"):
            cells.append(("%s %s  %s" % (tag, lab, st.upper()), R + "%s/%s_%s.png" % (kit, lab, st)))

rows = (len(cells) + COLS - 1) // COLS
sheet = Image.new("RGB", (W * COLS, 30 + rows * H), (24, 24, 26))
d = ImageDraw.Draw(sheet)
d.text((10, 7), "POL1 polish: HP1 quay barnacles + rock armour | R1a granite setts + gravel (overcast HDRI), dry | wet pairs",
       fill=(230, 230, 230), font=f)
for i, (lab, p) in enumerate(cells):
    x, y = (i % COLS) * W, 30 + (i // COLS) * H
    if os.path.isfile(p):
        im = Image.open(p).convert("RGB")
        s = max(W / im.width, H / im.height)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        l, t = (im.width - W) // 2, (im.height - H) // 2
        sheet.paste(im.crop((l, t, l + W, t + H)), (x, y))
    else:
        d.text((x + 10, y + H // 2), "missing", fill=(255, 80, 80), font=f)
    d.rectangle((x, y, x + W - 1, y + BAR), fill=(0, 0, 0))
    d.text((x + 6, y + 3), lab, fill=(255, 255, 255), font=f)
sheet.save(OUT)
print(OUT, sheet.size, len(cells), "cells")
