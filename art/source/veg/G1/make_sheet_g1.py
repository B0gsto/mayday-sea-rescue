#!/usr/bin/env python3
"""G1 contact sheet (system python3 + Pillow): hero renders of all 16 variants, 6 close-ups, LOD rows, the reference
cell (CC photos, art/reference/*/SOURCES.md) and the Studio pass -> assets/review/G1/2026-10-17_sheet.png (1536 px)."""
import glob, json, os
from PIL import Image, ImageDraw
GAME = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
R = os.path.join(GAME, "assets/review/G1"); RD = os.path.join(R, "renders")
W = 1536
rows = []
def label(img, text):
    d = ImageDraw.Draw(img); d.rectangle((0, 0, img.width, 16), fill=(20, 20, 20)); d.text((4, 2), text, fill=(235, 235, 235)); return img
def grid(files, cols, cw, ch, names=True):
    n = len(files); out = Image.new("RGB", (W, ((n + cols - 1) // cols) * ch), (24, 24, 24))
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB"); im.thumbnail((cw, ch))
        if names: label(im, os.path.basename(f)[:-4].replace("hero_", "").replace("close_", "close ").replace("lod_", ""))
        out.paste(im, ((i % cols) * cw + (cw - im.width) // 2, (i // cols) * ch))
    return out
def tris(asset):
    f = sorted(glob.glob(os.path.join(GAME, "assets/review", asset, "*_report.json")))[-1]
    t = {m["lod"]: m["triangles"] for m in json.load(open(f))["meshes"]}
    return "%d/%d/%d" % (t["LOD0"], t["LOD1"], t["LOD2"])
heroes = sorted(glob.glob(RD + "/hero_*.png"))
rows.append(grid(heroes, 8, 192, 192))
rows.append(grid(sorted(glob.glob(RD + "/close_*.png")), 6, 256, 256))
rows.append(grid(sorted(glob.glob(RD + "/lod_*.png")), 9, 170, 170))
for extra in ("reference_cell.png", "studio.png"):
    p = os.path.join(R, extra)
    if os.path.exists(p):
        im = Image.open(p).convert("RGB"); im.thumbnail((W, 2000)); rows.append(label(im, extra[:-4]))
foot = Image.new("RGB", (W, 60), (16, 16, 16)); d = ImageDraw.Draw(foot)
names = [os.path.basename(h)[5:-4] for h in heroes]
d.text((6, 4), "G1 tris LOD0/1/2: " + "  ".join("%s %s" % (n.replace("M_Veg_", ""), tris(n)) for n in names[:8]), fill=(220, 220, 220))
d.text((6, 22), "  ".join("%s %s" % (n.replace("M_Veg_", ""), tris(n)) for n in names[8:]), fill=(220, 220, 220))
d.text((6, 40), "atlas T_FoliageLand_Main 2048 (4096 master), ALB+alpha/NOR/RGH/MET + _Wet; validate 16/16 PASS (LOD UV layout waived: card LODs)", fill=(220, 220, 220))
rows.append(foot)
sheet = Image.new("RGB", (W, sum(r.height for r in rows)), (0, 0, 0)); y = 0
for r in rows: sheet.paste(r, (0, y)); y += r.height
out = os.path.join(R, "2026-10-17_sheet.png"); sheet.save(out); print(out, sheet.size)
