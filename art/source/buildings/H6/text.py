"""H6 lettering masks (system python3 + Pillow): the Harbour Light plaque and the LIFEGUARDS sign.
Writes greyscale masks (white = letter) next to this file; h6tex.py samples them by object position, so the text lands
on the plaque / sign face at its true size whatever the UV layout.
    python3 art/source/buildings/H6/text.py
All text is invented (no RNLI or other real marks).
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SUPP = "/System/Library/Fonts/Supplemental/"


def font(names, size):
    for n in names:
        p = os.path.join(SUPP, n)
        if os.path.isfile(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def centred(d, w, y, text, f, fill=255):
    box = d.textbbox((0, 0), text, font=f)
    d.text(((w - (box[2] - box[0])) / 2 - box[0], y - box[1]), text, font=f, fill=fill)
    return box[3] - box[1]


def plaque():
    # 0.70 x 0.50 m cast bronze plaque: raised border, four bolt heads, three lines of raised serif capitals
    W, H = 1400, 1000
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    d.rectangle((28, 28, W - 29, H - 29), outline=255, width=26)
    for x, y in ((90, 90), (W - 90, 90), (90, H - 90), (W - 90, H - 90)):
        d.ellipse((x - 26, y - 26, x + 26, y + 26), fill=255)
    serif = ["Times New Roman Bold.ttf", "Georgia Bold.ttf", "Baskerville.ttc"]
    centred(d, W, 170, "HARBOUR LIGHT", font(serif, 170))
    d.line((300, 420, W - 300, 420), fill=255, width=14)
    centred(d, W, 480, "ERECTED 1868", font(serif, 130))
    centred(d, W, 700, "KEPT BY ONE FAMILY", font(serif, 74))
    centred(d, W, 810, "FOR THREE GENERATIONS", font(serif, 74))
    im.save(os.path.join(HERE, "text_plaque.png"))


def sign():
    # 2.60 x 0.36 m fascia board: one line of bold sans capitals, red on yellow (h6tex paints the colours)
    W, H = 2600, 360
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    f = font(["Arial Black.ttf", "Arial Bold.ttf"], 250)
    centred(d, W, 52, "LIFEGUARDS", f)
    im.save(os.path.join(HERE, "text_sign.png"))


if __name__ == "__main__":
    plaque()
    sign()
    print("wrote", os.path.join(HERE, "text_plaque.png"), os.path.join(HERE, "text_sign.png"))
