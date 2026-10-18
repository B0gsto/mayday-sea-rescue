"""H6 contact sheet (system python3 + Pillow): assets/review/H6/renders/*.png -> assets/review/H6/contact.png
(1600 px wide: Harbour Light dry | wet, Lifeguard Tower dry | wet under the overcast-sea HDRI, then the close-ups)."""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
TAG = os.environ.get("H6_REVIEW", "b")
R = os.path.join(REPO, "assets", "review", "H6", "renders_" + TAG if TAG else "renders")
W, CW, CH = 1600, 400, 600
cells = [("%s %s" % (a.replace("M_Bld_", ""), s), os.path.join(R, "%s_%s.png" % (a, s)))
         for a in ("M_Bld_HarbourLight", "M_Bld_LifeguardTower") for s in ("dry", "wet")]
closes = sorted(f for f in os.listdir(R) if f.startswith("close_"))
cw, chh = 400, 300
crow = (len(closes) + 3) // 4
sheet = Image.new("RGB", (W, CH + crow * chh + 36), (40, 42, 44))
d = ImageDraw.Draw(sheet)
for i, (label, path) in enumerate(cells):
    if os.path.isfile(path):
        sheet.paste(Image.open(path).convert("RGB").resize((CW, CH), Image.LANCZOS), (i * CW, 0))
    d.text((i * CW + 6, 6), label, fill=(255, 255, 255))
for i, f in enumerate(closes):
    im = Image.open(os.path.join(R, f)).convert("RGB").resize((cw, chh), Image.LANCZOS)
    x, y = (i % 4) * cw, CH + (i // 4) * chh
    sheet.paste(im, (x, y))
    d.text((x + 6, y + 6), f[6:-4].replace("M_Bld_", ""), fill=(255, 255, 255))
d.text((8, CH + crow * chh + 12), "H6b: Harbour Light (12 m pier-head light, Fl(2) W 10s) and Haven Sands lifeguard tower. Overcast-sea HDRI, "
       "EEVEE, LOD0 with shipping maps (dry, then _Wet ALB/RGH), 5.5-stud mannequin for scale.", fill=(230, 230, 230))
out = os.path.join(REPO, "assets", "review", "H6", "contact_%s.png" % TAG if TAG else "contact.png")
sheet.save(out)
print(out, sheet.size)
