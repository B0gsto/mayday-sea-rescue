"""H3 contact sheet (system python3 + Pillow): assets/review/H3/renders/*.png -> assets/review/H3/contact.png (1600 px wide)."""
import os
from PIL import Image, ImageDraw, ImageStat

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
R = G + "assets/review/H3/renders/"
order = []
for i in range(1, 7):
    order += ["%02d_dry.png" % i, "%02d_wet.png" % i]
order += ["01_night.png", "05_night.png"] + sorted(f for f in os.listdir(R) if f.startswith("close_"))
order = [f for f in order if os.path.exists(R + f)]
cw, ch, cols = 400, 300, 4
rows = (len(order) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, ch * rows + 28), (24, 24, 24))
d = ImageDraw.Draw(sheet)
d.text((8, 8), "H3 Cornish cottages M_Bld_Cottage_01..06 (LOD0, overcast HDRI gray_pier, EEVEE): dry / wet, night GlassLit, kit close-ups", fill=(230, 230, 230))
for k, f in enumerate(order):
    im = Image.open(R + f).convert("RGB")
    im.thumbnail((cw, ch))
    x, y = (k % cols) * cw, 28 + (k // cols) * ch
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + 150, y + 16), fill=(0, 0, 0))
    d.text((x + 4, y + 2), "M_Bld_Cottage_" + f[:-4] if not f.startswith("close") else f[:-4], fill=(255, 255, 255))
    print(f, [round(v) for v in ImageStat.Stat(im).mean])
sheet.save(G + "assets/review/H3/contact.png")
print("sheet", sheet.size)
