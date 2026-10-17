"""Printed lifejacket label (system python3 + Pillow) -> textures/label_solas.png, read by swimmer.compose (planar-projected
onto the lower front panel). White coated label, black print: SOLAS / ISO 12402-3 150 N / pictograms. No brand names."""
import os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 560, 400
F = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
im = Image.new("L", (W, H), 232)
d = ImageDraw.Draw(im)
d.rectangle((6, 6, W - 7, H - 7), outline=30, width=8)
d.rectangle((6, 6, W - 7, 118), fill=30)
d.text((W // 2, 64), "SOLAS", fill=232, font=ImageFont.truetype(F, 92), anchor="mm")
d.text((W // 2, 170), "ISO 12402-3   150 N", fill=30, font=ImageFont.truetype(F, 46), anchor="mm")
d.text((W // 2, 222), "LIFEJACKET  ADULT  > 40 kg", fill=30, font=ImageFont.truetype(F, 32), anchor="mm")
for i, x in enumerate((70, 210, 350, 490)):         # pictogram boxes (inflate, light, whistle, crotch strap)
    d.rectangle((x - 50, 255, x + 50, 355), outline=30, width=6)
    if i == 0: d.polygon([(x, 270), (x - 30, 340), (x + 30, 340)], fill=30)
    if i == 1: d.ellipse((x - 26, 280, x + 26, 332), fill=30)
    if i == 2: d.rectangle((x - 32, 295, x + 32, 318), fill=30)
    if i == 3: d.line([(x - 30, 275), (x, 335), (x + 30, 275)], fill=30, width=10)
d.text((W // 2, 378), "CHECK BEFORE USE  -  SERVICE ANNUALLY", fill=30, font=ImageFont.truetype(F, 20), anchor="mm")
im.save(os.path.join(HERE, "textures", "label_solas.png"))
print("label", im.size)
