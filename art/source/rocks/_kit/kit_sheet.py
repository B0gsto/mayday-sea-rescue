"""K1 kit sheet -> assets/review/K1/kit_sheet.png: every piece's Front3Q overcast turntable cell (name, tris, size),
a close-up row (waterline / top), and the reference cell (Land's End granite, art/reference/M_Rock_Kit)."""
import json, os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import KIT, ROOT, WORK  # noqa: E402
cw = 300; cols = 5
cells = []
for a, *_ in KIT:
    t = ROOT + "assets/review/%s/turntable/" % a
    info = json.load(open(WORK + a + ".json"))
    cells.append((Image.open(t + "Front3Q_overcast.png").convert("RGB"),
                  "%s  %d tris  %.1fx%.1fx%.1f m" % (a.replace("M_Rock_", ""), info["lp_tris"], *info["size_m"])))
for a in ("M_Rock_Ledge_01", "M_Rock_Ledge_03", "M_Rock_Boulder_04", "M_Rock_Cliff_05"):
    cells.append((Image.open(ROOT + "assets/review/%s/turntable/closeup_waterline.png" % a).convert("RGB"), a.replace("M_Rock_", "") + " waterline"))
for a in ("M_Rock_Boulder_01", "M_Rock_Cliff_01", "M_Rock_Cliff_03"):
    cells.append((Image.open(ROOT + "assets/review/%s/turntable/closeup_top.png" % a).convert("RGB"), a.replace("M_Rock_", "") + " top (lichen)"))
cells.append((Image.open(ROOT + "art/reference/M_Rock_Kit/ref_08_cornish_cliffs.jpg").convert("RGB"), "REF Land's End granite (CC BY-SA 2.0 Roger D Kidd)"))
cells.append((Image.open(ROOT + "art/reference/M_Rock_Kit/ref_12_barnacle_intertidal.jpg").convert("RGB"), "REF coastal outcrops (CC BY-SA 2.0 J Wilkins)"))
rows = (len(cells) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, cw * rows), (24, 24, 24)); dr = ImageDraw.Draw(sheet)
for i, (im, label) in enumerate(cells):
    s = cw / max(im.size); im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    x, y = (i % cols) * cw, (i // cols) * cw
    sheet.paste(im, (x + (cw - im.width) // 2, y + (cw - im.height) // 2))
    dr.rectangle((x, y, x + cw, y + 14), fill=(0, 0, 0)); dr.text((x + 4, y + 2), label, fill=(255, 230, 80))
os.makedirs(ROOT + "assets/review/K1", exist_ok=True)
sheet.save(ROOT + "assets/review/K1/kit_sheet.png"); print("kit sheet", len(cells), "cells", sheet.size)
