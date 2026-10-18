"""HP1 contact sheet: every asset dry | wet (overcast HDRI) + one close-up per kit, <= 1600 px wide.
    python3 art/source/harbour/_hp1/sheet.py"""
import os
from PIL import Image, ImageDraw

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
S = G + "assets/review/HP1/shots"
OUT = G + "assets/review/HP1/contact.png"
A = ["M_Hbr_QuayKit_Straight", "M_Hbr_QuayKit_Corner", "M_Hbr_QuayKit_Steps", "M_Hbr_QuayKit_Head",
     "M_Hbr_QuayKit_Armour", "M_Hbr_QuayKit_LadderBay", "M_Hbr_Pontoon_Straight6", "M_Hbr_Pontoon_Straight12",
     "M_Hbr_Pontoon_Corner", "M_Hbr_Pontoon_Finger", "M_Hbr_Pontoon_Gangway", "M_Hbr_Ladder"]
cells = []
for a in A:
    for st in ("dry", "wet"):
        cells.append(("%s %s" % (a[6:], st), os.path.join(S, "%s_%s.png" % (a, st))))
for a in ("M_Hbr_QuayKit_Straight", "M_Hbr_Pontoon_Straight6", "M_Hbr_Ladder"):
    for st in ("dry", "wet"):
        cells.append(("%s close-up %s" % (a[6:], st), os.path.join(S, "%s_close_%s.png" % (a, st))))
C, W = 6, 264
rows = (len(cells) + C - 1) // C
sheet = Image.new("RGB", (C * W, rows * (W + 18)), (30, 30, 30))
dr = ImageDraw.Draw(sheet)
for i, (label, p) in enumerate(cells):
    x, y = (i % C) * W, (i // C) * (W + 18)
    if os.path.isfile(p):
        sheet.paste(Image.open(p).convert("RGB").resize((W, W), Image.LANCZOS), (x, y + 18))
    else:
        dr.text((x + 8, y + 120), "missing", fill=(255, 80, 80))
    dr.text((x + 4, y + 3), label, fill=(230, 230, 230))
sheet.save(OUT)
print(OUT, sheet.size)
