"""Contact sheet for the spin-cinematic flipbooks (spincine.py): row 1 the raw sheets on navy, row 2 in-use mockups
(tinted per rarity, LightEmission-1 style additive over a dark sky; the gold bricks assembled into a halo ring).

  python3 art/source/fx/spincine_contact.py [--out DIR]   -> <out>/spincine_contact.png (+ copies of the sheets)
"""
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), "build", "prod", "spincine")
NAMES = ["FX_SpinFlare", "FX_SpinRays", "FX_SpinBolt", "FX_SpinHaloBrick", "FX_SpinHaloRing"]
GRID = {"FX_SpinFlare": 4, "FX_SpinRays": 4, "FX_SpinBolt": 2, "FX_SpinHaloBrick": 4, "FX_SpinHaloRing": 1}
RARITY = [(0x5A, 0xB4, 0xFF), (0xB0, 0x6A, 0xFF), (0xFF, 0xC2, 0x3A), (0xFF, 0xFF, 0xFF)]  # rare, epic, legendary, mythic
NAVY = (22, 30, 48)
T = 360


def load(n):
    return np.asarray(Image.open(os.path.join(SRC, n + ".png")).convert("RGBA"), np.float32) / 255


def frame(sheet, grid, i):
    c = sheet.shape[0] // grid
    r, k = divmod(i, grid)
    return sheet[r * c:(r + 1) * c, k * c:(k + 1) * c]


def over(bg, spr, x, y):
    """Alpha-over a straight-alpha sprite onto a float RGB canvas."""
    h, w = spr.shape[:2]
    a = spr[..., 3:4]
    bg[y:y + h, x:x + w] = spr[..., :3] * a + bg[y:y + h, x:x + w] * (1 - a)


def add(bg, spr, x, y, tint, k=1.0):
    """LightEmission-1 look: tinted sprite added onto the canvas."""
    h, w = spr.shape[:2]
    bg[y:y + h, x:x + w] += spr[..., :3] * np.array(tint, np.float32) / 255 * spr[..., 3:4] * k


def resize(spr, s):
    im = Image.fromarray((np.clip(spr, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.resize((s, s), Image.LANCZOS), np.float32) / 255


def sky():
    y = np.linspace(0, 1, T)[:, None, None]
    return np.broadcast_to(np.array((12, 16, 34), np.float32) / 255 * (1 - y) + np.array((30, 22, 58), np.float32) / 255 * y,
                           (T, T, 3)).copy()


def main(out):
    sheets = {n: load(n) for n in NAMES}
    row1 = []
    for n in NAMES:
        bg = np.broadcast_to(np.array(NAVY, np.float32) / 255, (T, T, 3)).copy()
        over(bg, resize(sheets[n], T), 0, 0)
        row1.append(bg)
    row2 = []
    # flare burst frame in the four rarity tints, a 2x2
    bg = sky()
    for j, tint in enumerate(RARITY):
        add(bg, resize(frame(sheets["FX_SpinFlare"], 4, 10), T // 2), (j % 2) * T // 2, (j // 2) * T // 2, tint)
    row2.append(bg)
    # epic: rays + flare charge stacked
    bg = sky()
    add(bg, resize(frame(sheets["FX_SpinRays"], 4, 5), T), 0, 0, RARITY[1], 0.8)
    add(bg, resize(frame(sheets["FX_SpinFlare"], 4, 8), T // 2), T // 4, T // 4, RARITY[1])
    row2.append(bg)
    # legendary bolt strike onto a flare
    bg = sky()
    add(bg, resize(frame(sheets["FX_SpinBolt"], 2, 0), T), 0, 0, (150, 200, 255))
    add(bg, resize(frame(sheets["FX_SpinFlare"], 4, 11), T // 3), T // 3, 2 * T // 3 - 10, RARITY[2])
    row2.append(bg)
    # mythic halo: ring glow + 12 bricks at different tumble frames
    bg = sky()
    add(bg, resize(sheets["FX_SpinHaloRing"], T), 0, 0, RARITY[2], 0.9)
    for k in range(12):
        a = math.tau * k / 12
        s = T // 6
        x, y = int(T / 2 + T * 0.31 * math.cos(a) - s / 2), int(T / 2 + T * 0.31 * math.sin(a) - s / 2)
        over(bg, resize(frame(sheets["FX_SpinHaloBrick"], 4, k), s), x, y)
    row2.append(bg)
    # flare charge strip (frames 0, 4, 8, 10, 13) in legendary gold
    bg = sky()
    for j, f in enumerate((0, 3, 6, 9, 10, 12, 13, 15)):
        add(bg, resize(frame(sheets["FX_SpinFlare"], 4, f), T // 4), (j % 4) * T // 4, T // 4 + (j // 4) * T // 4, RARITY[2])
    row2.append(bg)
    canvas = np.ones((2 * T + 3 * 28, 5 * T + 6 * 8, 3), np.float32) * 0.93
    labels = []
    for r, row in enumerate((row1, row2)):
        for c, tile in enumerate(row):
            x, y = 8 + c * (T + 8), 28 + r * (T + 28)
            canvas[y:y + T, x:x + T] = np.clip(tile, 0, 1)
            labels.append((x, y - 22))
    im = Image.fromarray((canvas * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    text = NAMES + ["Flare burst x4 rarities", "Epic: rays + charge", "Bolt strike + flare", "Halo: bricks + ring",
                    "Flare timeline (gold)"]
    for (x, y), t in zip(labels, text):
        d.text((x, y), t, fill=(20, 20, 30))
    os.makedirs(out, exist_ok=True)
    im.save(os.path.join(out, "spincine_contact.png"))
    for n in NAMES:
        shutil.copy(os.path.join(SRC, n + ".png"), out)
    print(os.path.join(out, "spincine_contact.png"), im.size)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else SRC)
