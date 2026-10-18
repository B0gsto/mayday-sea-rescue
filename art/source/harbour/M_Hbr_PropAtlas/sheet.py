"""HP2a contact sheets (system python3 + Pillow), round b (HP2a-fix): every prop dry | wet under the overcast-sea HDRI
-> assets/review/HP2a/contact_b.png, and the hero-distance close-ups -> assets/review/HP2a/contact_b2.png (both <= 1600 px)."""
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
H = 40 + rows * (CELL + 18) + 6
sheet = Image.new("RGB", (W, H), (32, 33, 35))
d = ImageDraw.Draw(sheet)
d.text((10, 10), "HP2a round b (fix): harbour props on the shared prop atlas. Each prop DRY | WET, overcast-sea HDRI, Blender EEVEE",
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
os.makedirs(OUT, exist_ok=True)
sheet.save(os.path.join(OUT, "contact_b.png"), optimize=True)
print("sheet", sheet.size, os.path.join(OUT, "contact_b.png"))
closes = sorted(f for f in os.listdir(R) if f.startswith("closeup_"))
C2, CC = 4, W // 4
crow = (len(closes) + C2 - 1) // C2
s2 = Image.new("RGB", (W, 40 + crow * (CC + 18)), (32, 33, 35))
d = ImageDraw.Draw(s2)
d.text((10, 10), "HP2a round b (fix): close-ups at hero distance, dry, overcast-sea HDRI", font=FB, fill=(230, 230, 230))
for j, c in enumerate(closes):
    x, yy = (j % C2) * CC, 40 + (j // C2) * (CC + 18)
    s2.paste(Image.open(os.path.join(R, c)).convert("RGB").resize((CC, CC), Image.LANCZOS), (x, yy))
    d.text((x + 3, yy + CC + 2), c[8:-4], font=F, fill=(200, 200, 200))
s2.save(os.path.join(OUT, "contact_b2.png"), optimize=True)
print("sheet", s2.size, os.path.join(OUT, "contact_b2.png"))
