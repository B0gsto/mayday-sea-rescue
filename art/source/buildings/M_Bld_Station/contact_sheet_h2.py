# H2 contact sheet: 6 Blender renders (render_h2.py), 3 x 2 cells of 533 x 300 px (1599 px wide).
from PIL import Image, ImageDraw, ImageStat
D = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/assets/review/M_Bld_Station/"
cells = [("Day 3/4 front", "day_front3q"), ("Slipway toe at the waterline", "slip_toe_waterline"),
         ("Slipway side wall close-up", "slip_side_wall"), ("Night, lights on", "night_front3q"),
         ("Roof: ridge, chimney flashing, valley", "roof_closeup"), ("Rear gable", "rear_gable")]
cw, ch, cols = 533, 300, 3
sheet = Image.new("RGB", (cw * cols, ch * 2), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (label, f) in enumerate(cells):
    im = Image.open(D + "h2/" + f + ".png").convert("RGB")
    st = ImageStat.Stat(im)
    print(f, "mean %.0f std %.0f" % (sum(st.mean) / 3, sum(st.stddev) / 3))
    im = im.resize((cw, round(im.height * cw / im.width)), Image.LANCZOS)
    y0 = (im.height - ch) // 2
    im = im.crop((0, y0, cw, y0 + ch))
    x, y = (i % cols) * cw, (i // cols) * ch
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + 8 + 6 * len(label), y + 15), fill=(0, 0, 0))
    d.text((x + 4, y + 2), label, fill=(255, 230, 0))
sheet.save(D + "h2_contact.png", optimize=True)
print("h2_contact.png", sheet.size)
