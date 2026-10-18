# H1 contact sheet: Blender turntables + Studio Edit look-dev + play-mode ocean shots, 4 x 400 px wide (1600 px).
import os
from PIL import Image, ImageDraw
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/assets/review/"
ST, SL = G + "M_Bld_Station/", G + "M_Bld_Slipway/"
cells = [
    ("BL Station Front3Q", ST + "turntable/Front3Q_overcast.png"),
    ("BL Station Rear3Q", ST + "turntable/Rear3Q_overcast.png"),
    ("BL Slipway Front3Q", SL + "turntable/Front3Q_overcast.png"),
    ("BL Slipway tide line", SL + "turntable/closeup_tide_line.png"),
    ("ST Harbour Clear dry", ST + "studio/M_Bld_Station_Harbour_Clear_dry.png"),
    ("ST Harbour Overcast wet", ST + "studio/M_Bld_Station_Harbour_Overcast_wet.png"),
    ("ST Harbour Storm wet", ST + "studio/M_Bld_Station_Harbour_Storm_wet.png"),
    ("ST Harbour Night dry", ST + "studio/M_Bld_Station_Harbour_Night_dry.png"),
    ("ST Slipway Hero Overcast dry", SL + "studio/M_Bld_Slipway_Hero_Overcast_dry.png"),
    ("ST Slipway Hero Storm wet", SL + "studio/M_Bld_Slipway_Hero_Storm_wet.png"),
    ("ST Slipway Closeup dry", SL + "studio/M_Bld_Slipway_Closeup_Overcast_dry.png"),
    ("ST Slipway Closeup wet", SL + "studio/M_Bld_Slipway_Closeup_Overcast_wet.png"),
    ("ST Bay door dry", ST + "studio/M_Bld_Station_DoorDetail_Overcast_dry.png"),
    ("ST Wing wall wet", ST + "studio/M_Bld_Station_WallDetail_Overcast_wet.png"),
    ("PLAY Ocean Overcast dry", ST + "studio/M_Bld_Station_Ocean_Overcast_dry.png"),
    ("PLAY Slipway Ocean Storm wet", SL + "studio/M_Bld_Slipway_Ocean_Storm_wet.png"),
]
cw, ch, cols = 400, 225, 4
have = [(n, p) for n, p in cells if os.path.exists(p)]
miss = [n for n, p in cells if not os.path.exists(p)]
rows = (len(have) + cols - 1) // cols
sheet = Image.new("RGB", (cw * cols, ch * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, p) in enumerate(have):
    im = Image.open(p).convert("RGB")
    s = max(cw / im.width, ch / im.height)
    im = im.resize((max(cw, round(im.width * s)), max(ch, round(im.height * s))), Image.LANCZOS)
    x0, y0 = (im.width - cw) // 2, (im.height - ch) // 2
    im = im.crop((x0, y0, x0 + cw, y0 + ch))
    x, y = (i % cols) * cw, (i // cols) * ch
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + 8 + 6 * len(n), y + 15), fill=(0, 0, 0))
    d.text((x + 4, y + 2), n, fill=(255, 230, 0))
sheet.save(ST + "h1_contact.png", optimize=True)
print("h1_contact.png", sheet.size, "cells", len(have), "missing", miss)
