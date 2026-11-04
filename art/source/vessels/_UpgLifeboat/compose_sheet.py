"""Contact sheet from sheet_scene's renders (system python3, Pillow): columns L21 L25 L30, rows three angles + phone view."""
import os

from PIL import Image, ImageDraw, ImageFont

GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
CELLS = os.path.join(GAME, "build/status/2026-11-04/art/lifeboat_cells")
OUT = os.path.join(GAME, "build/status/2026-11-04/art/lifeboat.png")
LEVELS = (21, 25, 30)
W, H, PW, PH = 340, 240, 340, 189     # phone cell keeps 360:200; a real phone view is about this size
sheet = Image.new("RGB", (W * 3 + 2, 22 + H * 3 + PH), (20, 28, 40))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 15)
except OSError:
    font = ImageFont.load_default()
for c, lv in enumerate(LEVELS):
    x = c * (W + 1)
    d.text((x + 6, 3), "L%d" % lv, fill=(255, 255, 255), font=font)
    for r, view in enumerate(("three", "side", "rear")):
        sheet.paste(Image.open(os.path.join(CELLS, "L%d_%s.png" % (lv, view))).convert("RGB").resize((W, H), Image.LANCZOS), (x, 22 + r * H))
    sheet.paste(Image.open(os.path.join(CELLS, "L%d_phone.png" % lv)).convert("RGB").resize((PW, PH), Image.LANCZOS), (x, 22 + 3 * H))
sheet.save(OUT)
print(OUT, sheet.size)
