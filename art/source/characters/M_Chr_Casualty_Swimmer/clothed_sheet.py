"""Composes build/ch1/clothed/*.png into assets/review/M_Chr_Casualty_Swimmer/clothed_check.png (system python3 + Pillow)."""
import os
import sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SRC = os.path.join(REPO, "build", "ch1", "clothed")
rows = [("Silhouettes (LOD0)", ["sil_front", "sil_side", "sil_back", "sil_threequarter"]),
        ("Clay, no textures (LOD0)", ["clay_front", "clay_side", "clay_back", "clay_threequarter"]),
        ("Cutaways (ORANGE = inside faces of the hollow clothing shell: no body inside) + LOD1/LOD2 clay", ["cut_side", "cut_front", "clay_lod1", "clay_lod2"])]
caps = {"sil_front": "front", "sil_side": "side", "sil_back": "back", "sil_threequarter": "3/4",
        "clay_front": "front", "clay_side": "side", "clay_back": "back", "clay_threequarter": "3/4",
        "cut_side": "cut at x = 0 (orange = inside)", "cut_front": "cut at y = 0 (orange = inside)", "clay_lod1": "LOD1 3/4", "clay_lod2": "LOD2 3/4"}
cw, ch, hdr = 420, 700, 26
W, Hh = cw * 4, (ch + hdr) * 3 + 40
sheet = Image.new("RGB", (W, Hh), (24, 24, 26))
d = ImageDraw.Draw(sheet)
d.text((8, 8), "M_Chr_Casualty_Swimmer clothed check: one merged mesh per LOD; drysuit + sea boots + lifejacket + neoprene gloves; skin only face and neck; "
       + " ".join(sys.argv[1:]), fill=(235, 235, 235))
y = 40
for title, names in rows:
    d.text((8, y + 6), title, fill=(255, 200, 120))
    for i, n in enumerate(names):
        im = Image.open(os.path.join(SRC, n + ".png")).convert("RGB").resize((cw, ch))
        sheet.paste(im, (i * cw, y + hdr))
        d.text((i * cw + 8, y + hdr + 6), caps[n], fill=(200, 30, 30) if n.startswith("sil") else (235, 235, 235))
    y += ch + hdr
out = os.path.join(REPO, "assets", "review", "M_Chr_Casualty_Swimmer", "clothed_check.png")
sheet.save(out)
print(out, sheet.size)
