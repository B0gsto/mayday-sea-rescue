"""HP2b contact sheet (system python3 + Pillow): assets/review/HP2b/renders/*.png -> assets/review/HP2b/contact.png
(1600 px wide: every buoy dry | wet under the overcast-sea HDRI, then the close-ups)."""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
import marks  # noqa: E402

R = os.path.join(REPO, "assets", "review", "HP2b", os.environ.get("HP2B_RENDERS", "renders_b"))
W, CW, CH = 1600, 200, 300
cells = []
for k in marks.ALL:
    for state in ("dry", "wet"):
        cells.append(("%s %s" % (k, state), os.path.join(R, "%s_%s.png" % (k, state)), (CW, CH)))
closes = sorted(f for f in os.listdir(R) if f.startswith("close_"))
rows = (len(cells) + 7) // 8
PER = 4
cw = W // PER
ch_close = cw * 2 // 3
crow = (len(closes) + PER - 1) // PER
sheet = Image.new("RGB", (W, rows * CH + crow * ch_close + 40), (40, 42, 44))
d = ImageDraw.Draw(sheet)
for i, (label, path, size) in enumerate(cells):
    x, y = (i % 8) * CW, (i // 8) * CH
    if os.path.isfile(path):
        sheet.paste(Image.open(path).convert("RGB").resize(size, Image.LANCZOS), (x, y))
    d.text((x + 4, y + 4), label, fill=(255, 255, 255))
for i, f in enumerate(closes):
    im = Image.open(os.path.join(R, f)).convert("RGB").resize((cw, ch_close), Image.LANCZOS)
    x, y = (i % PER) * cw, rows * CH + (i // PER) * ch_close
    sheet.paste(im, (x, y))
    d.text((x + 4, y + 4), f[6:-4], fill=(255, 255, 255))
ch_close = crow * ch_close
d.text((6, rows * CH + ch_close + 12), "HP2b buoys: IALA Region A nav marks + mooring / pick-up buoys. Overcast-sea HDRI, "
       "EEVEE, LOD0 with shipping maps (dry, then _Wet ALB/RGH). Fix round b: 1.5x topmarks, solid banded pillar, graded fouling, joint rust.", fill=(230, 230, 230))
out = os.path.join(REPO, "assets", "review", "HP2b", os.environ.get("HP2B_SHEET", "contact_b.png"))
sheet.save(out)
print(out, sheet.size)
