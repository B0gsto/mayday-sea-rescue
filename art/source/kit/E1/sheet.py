"""E1 contact sheet (system python3 + Pillow): every kit item DRY | WET under the overcast-sea HDRI (Blender EEVEE,
render.py) plus the hero-distance close-ups, one image <= 1600 px -> assets/review/E1/contact.png."""
import os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
R = os.path.join(G, "build/e1/renders")
OUT = os.path.join(G, "assets/review/E1")
ASSETS = ["M_Kit_ThrowBag", "M_Kit_ThrowLine", "M_Kit_RescueTube", "M_Kit_Lifebuoy", "M_Kit_ThermalBlanket",
          "M_Kit_ThermalBlanketDraped", "M_Kit_FirstAidBag", "M_Kit_OxygenBag", "M_Kit_VHFHandset", "M_Kit_HandFlare",
          "M_Kit_ParaFlare", "M_Kit_Strobe"]
W, CELL, COLS = 1600, 200, 8
try:
    F = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 13)
    FB = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 18)
except OSError:
    F = FB = ImageFont.load_default()
sys.path.insert(0, HERE)
import render_list  # noqa: E402
closes = [f for c in render_list.CLOSEUPS for f in ("closeup_%s.png" % c[1], "closeup_%s_WET.png" % c[1]) if os.path.exists(os.path.join(R, f))]
rows = (len(ASSETS) * 2 + COLS - 1) // COLS
CC = W // 4
H = 40 + rows * (CELL + 18) + 24 + ((len(closes) + 3) // 4) * (CC + 18)
sheet = Image.new("RGB", (W, H), (32, 33, 35))
d = ImageDraw.Draw(sheet)
d.text((10, 10), "E1b hand-held rescue kit, M_Kit_Atlas (Cloth + Soft + Foil + Hard sets, 1024 ship). Each item DRY | WET, overcast-sea HDRI, EEVEE",
       font=FB, fill=(230, 230, 230))
y0 = 40
for i, a in enumerate(ASSETS):
    for k, state in enumerate(("dry", "wet")):
        n = i * 2 + k
        x, y = (n % COLS) * CELL, y0 + (n // COLS) * (CELL + 18)
        f = os.path.join(R, "%s_%s.png" % (a, state))
        if os.path.exists(f):
            sheet.paste(Image.open(f).convert("RGB").resize((CELL, CELL), Image.LANCZOS), (x, y))
        d.text((x + 3, y + CELL + 2), "%s %s" % (a.replace("M_Kit_", ""), state.upper()), font=F, fill=(200, 200, 200))
yc = y0 + rows * (CELL + 18)
d.text((10, yc + 2), "First-person close-ups, camera 0.3 to 1.0 m from the item (dry)", font=FB, fill=(230, 230, 230))
yc += 24
for j, c in enumerate(closes):
    x, yy = (j % 4) * CC, yc + (j // 4) * (CC + 18)
    sheet.paste(Image.open(os.path.join(R, c)).convert("RGB").resize((CC, CC), Image.LANCZOS), (x, yy))
    d.text((x + 3, yy + CC + 2), c[8:-4], font=F, fill=(200, 200, 200))
os.makedirs(OUT, exist_ok=True)
sheet.save(os.path.join(OUT, "contact_b.png"), optimize=True)
print("sheet", sheet.size, os.path.join(OUT, "contact_b.png"))
