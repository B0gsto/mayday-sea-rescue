"""Contact-sheet grid (system python3 + Pillow): grid.py OUT COLS CELL img [img ...]; labels from file names.

    python3 art/source/vehicles/_CarPremium/grid.py build/x/sheet.png 3 384 a.png b.png ...
"""
import os
import sys

from PIL import Image, ImageDraw

out, cols, cell = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
paths = sys.argv[4:]
rows = (len(paths) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell, rows * cell), (30, 30, 32))
d = ImageDraw.Draw(sheet)
for i, p in enumerate(paths):
    im = Image.open(p).convert("RGB")
    im.thumbnail((cell, cell))
    x, y = (i % cols) * cell, (i // cols) * cell
    sheet.paste(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
    parts = os.path.abspath(p).split(os.sep)
    owner = next((q for q in reversed(parts[:-1]) if q.startswith("M_")), parts[-2])
    label = owner.replace("M_Veh_", "") + " " + os.path.splitext(parts[-1])[0].replace("closeup_", "")
    d.rectangle((x, y, x + 7 * len(label) + 6, y + 14), fill=(0, 0, 0))
    d.text((x + 3, y + 2), label, fill=(235, 235, 235))
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
sheet.save(out)
print("wrote", out, sheet.size)
