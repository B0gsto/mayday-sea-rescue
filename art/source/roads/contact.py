"""R1a contact sheet: build/roads/renders/*.png -> assets/review/R1a/contact.png (1600 px wide, dry | wet pairs, labels).

    python3 art/source/roads/contact.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../.."))
R = os.path.join(GAME, "build/roads/renders")
OUT = os.path.join(GAME, "assets/review/R1a/contact.png")
ORDER = ["road_asphalt", "road_asphalt_Wet", "cobbles", "cobbles_Wet", "gravel", "gravel_Wet", "closeup_road_kerb",
         "closeup_M_Road_Bench", "M_Road_StreetLamp", "M_Road_StreetLamp_Wet", "M_Road_Bench", "M_Road_Bench_Wet",
         "M_Road_Bin", "M_Road_Bin_Wet", "M_Road_Bollard", "M_Road_Bollard_Wet"]
W, COLS = 400, 4
H = 300
f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 15)
rows = (len(ORDER) + COLS - 1) // COLS
sheet = Image.new("RGB", (W * COLS, 34 + rows * H), (24, 24, 26))
d = ImageDraw.Draw(sheet)
d.text((10, 8), "R1a roads + street furniture (overcast HDRI gray_pier, EEVEE): dry | wet pairs; close-ups 2 m kerb + bench",
       fill=(230, 230, 230), font=f)
for i, n in enumerate(ORDER):
    im = Image.open(os.path.join(R, n + ".png")).convert("RGB").resize((W, H), Image.LANCZOS)
    x, y = (i % COLS) * W, 34 + (i // COLS) * H
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + W - 1, y + 20), fill=(0, 0, 0))
    d.text((x + 6, y + 2), n.replace("_Wet", "  WET"), fill=(255, 255, 255), font=f)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT)
print(OUT, sheet.size)
