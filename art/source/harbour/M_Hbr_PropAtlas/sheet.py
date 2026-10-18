"""HP2a contact sheet (system python3 + Pillow): every prop dry | wet under the overcast-sea HDRI, then one close-up
per kit -> assets/review/HP2a/contact.png (<= 1600 px wide)."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
from refs import REFS  # noqa: E402
R = os.path.join(G, "build/hp2a/renders")
OUT = os.path.join(G, "assets/review/HP2a")
W, CELL, COLS = 1600, 200, 8
try:
    F = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 13)
    FB = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 18)
except OSError:
    F = FB = ImageFont.load_default()
tris = {}
p = os.path.join(G, "build/hp2a/tris.json")
if os.path.exists(p):
    tris = json.load(open(p))
assets = list(REFS)
rows = (len(assets) * 2 + COLS - 1) // COLS
closes = sorted(f for f in os.listdir(R) if f.startswith("closeup_"))
cw = W // 3
crow = (len(closes) + 2) // 3
H = 40 + rows * (CELL + 18) + 30 + crow * (cw + 18) + 10
sheet = Image.new("RGB", (W, H), (32, 33, 35))
d = ImageDraw.Draw(sheet)
d.text((10, 10), "HP2a harbour props (shared prop atlas: Metal + Rope/plastic sets). Each prop: DRY | WET, overcast-sea HDRI, Blender EEVEE",
       font=FB, fill=(230, 230, 230))
y0 = 40
for i, a in enumerate(assets):
    for k, state in enumerate(("dry", "wet")):
        n = i * 2 + k
        x, y = (n % COLS) * CELL, y0 + (n // COLS) * (CELL + 18)
        f = os.path.join(R, "%s_%s.png" % (a, state))
        if os.path.exists(f):
            sheet.paste(Image.open(f).convert("RGB").resize((CELL, CELL), Image.LANCZOS), (x, y))
        label = "%s %s%s" % (a.replace("M_Hbr_", ""), state.upper(), (" %s tris" % tris[a]) if a in tris and k == 0 else "")
        d.text((x + 3, y + CELL + 2), label, font=F, fill=(200, 200, 200))
y = y0 + rows * (CELL + 18) + 4
d.text((10, y), "Close-ups (hero distance, dry): one per kit", font=FB, fill=(230, 230, 230))
y += 26
for j, c in enumerate(closes):
    x, yy = (j % 3) * cw, y + (j // 3) * (cw + 18)
    sheet.paste(Image.open(os.path.join(R, c)).convert("RGB").resize((cw, cw), Image.LANCZOS), (x, yy))
    d.text((x + 3, yy + cw + 2), c[8:-4], font=F, fill=(200, 200, 200))
os.makedirs(OUT, exist_ok=True)
sheet.save(os.path.join(OUT, "contact.png"), optimize=True)
print("sheet", sheet.size, os.path.join(OUT, "contact.png"))
