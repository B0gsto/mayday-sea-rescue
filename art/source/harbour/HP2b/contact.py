"""HP2b contact sheet (system python3 + Pillow): assets/review/HP2b/renders/*.png -> assets/review/HP2b/contact.png
(1600 px wide: every buoy dry | wet under the overcast-sea HDRI, then the close-ups)."""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
import marks  # noqa: E402

R = os.path.join(REPO, "assets", "review", "HP2b", "renders")
W, CW, CH = 1600, 200, 300
cells = []
for k in marks.ALL:
    for state in ("dry", "wet"):
        cells.append(("%s %s" % (k, state), os.path.join(R, "%s_%s.png" % (k, state)), (CW, CH)))
closes = sorted(f for f in os.listdir(R) if f.startswith("close_"))
rows = (len(cells) + 7) // 8
ch_close = 260
sheet = Image.new("RGB", (W, rows * CH + ch_close + 40), (40, 42, 44))
d = ImageDraw.Draw(sheet)
for i, (label, path, size) in enumerate(cells):
    x, y = (i % 8) * CW, (i // 8) * CH
    if os.path.isfile(path):
        sheet.paste(Image.open(path).convert("RGB").resize(size, Image.LANCZOS), (x, y))
    d.text((x + 4, y + 4), label, fill=(255, 255, 255))
cw = W // max(1, len(closes))
for i, f in enumerate(closes):
    im = Image.open(os.path.join(R, f)).convert("RGB")
    im = im.resize((cw, int(cw * im.height / im.width)), Image.LANCZOS).crop((0, 0, cw, ch_close))
    sheet.paste(im, (i * cw, rows * CH))
    d.text((i * cw + 4, rows * CH + 4), f[6:-4], fill=(255, 255, 255))
d.text((6, rows * CH + ch_close + 12), "HP2b buoys: IALA Region A nav marks + mooring / pick-up buoys. Overcast-sea HDRI, "
       "EEVEE, LOD0 with shipping maps (dry, then _Wet ALB/RGH). Waterline = z 0; weed and barnacles below.", fill=(230, 230, 230))
out = os.path.join(REPO, "assets", "review", "HP2b", "contact.png")
sheet.save(out)
print(out, sheet.size)
