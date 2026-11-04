"""System python3: pirates_src/*.png -> build/status/2026-11-04/art/pirates.png (3 angles, crew, ram, phone-size view)."""
import os

from PIL import Image

G = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
SRC = os.path.join(G, "build/status/2026-11-04/art/pirates_src")
cell = 341
sheet = Image.new("RGB", (cell * 3 + 1, cell * 2), (24, 26, 30))
for i, n in enumerate(("front34", "side", "rear34", "crew", "ram")):
    sheet.paste(Image.open(os.path.join(SRC, n + ".png")).convert("RGB").resize((cell, cell), Image.LANCZOS), (i % 3 * cell, i // 3 * cell))
sheet.paste(Image.open(os.path.join(SRC, "phone.png")).convert("RGB").resize((330, 183), Image.LANCZOS), (2 * cell + 6, cell + 79))
out = os.path.join(G, "build/status/2026-11-04/art/pirates.png")
sheet.save(out)
print(out)
