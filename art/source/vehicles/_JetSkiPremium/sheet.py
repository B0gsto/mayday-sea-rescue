"""Premium jet ski contact sheet: one row per ski (Front3Q, Side, Rear3Q overcast + the 1 m close-up), 384 px cells.
    python3 art/source/vehicles/_JetSkiPremium/sheet.py <out.png> <turntable dir>:<closeup name> [...] [--extra]
--extra adds a second row per ski with the other close-ups (working sheet only)."""
import os
import sys

from PIL import Image, ImageDraw

C = 384
args = [a for a in sys.argv[2:] if not a.startswith("--")]
extra = "--extra" in sys.argv
rows = []
for a in args:
    d, close = a.rsplit(":", 1)
    name = d.rstrip("/").split("/")[-2] if d.rstrip("/").endswith("turntable") else os.path.basename(d)
    cells = [os.path.join(d, f) for f in ("Front3Q_overcast.png", "Side_overcast.png", "Rear3Q_overcast.png",
                                          "closeup_%s.png" % close)]
    rows.append((name, cells))
    if extra:
        others = sorted(f for f in os.listdir(d) if f.startswith("closeup_") and f != "closeup_%s.png" % close)
        rows.append((name + " close-ups", [os.path.join(d, f) for f in others[:4]]))
sheet = Image.new("RGB", (4 * C, len(rows) * (C + 22)), (28, 30, 32))
dr = ImageDraw.Draw(sheet)
for r, (name, cells) in enumerate(rows):
    y = r * (C + 22)
    dr.text((8, y + 5), name + "   (Front3Q, Side, Rear3Q, 1 m close-up)" if "close-ups" not in name else name,
            fill=(230, 230, 230))
    for c, f in enumerate(cells):
        if os.path.exists(f):
            im = Image.open(f).convert("RGB")
            w, h = im.size
            s = min(w, h)
            im = im.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2)).resize((C, C), Image.LANCZOS)
            sheet.paste(im, (c * C, y + 22))
sheet.save(sys.argv[1])
print(sys.argv[1], sheet.size)
