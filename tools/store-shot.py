#!/usr/bin/env python3
"""Store-art capture: save the current Studio play viewport as 1920x1080, or build the contact sheet.

usage: python3 tools/store-shot.py shot <name> [--out DIR]     raw capture -> DIR/thumbnails/NN_name.png
       python3 tools/store-shot.py contact [--out DIR]         DIR/thumbnails/contact.png (480 px cells)

Reads the Studio id of $MAYDAY_STUDIO_TAG (default mayday-store) from build/smoke/.sid-<tag>.
Holds the machine-wide Studio lock only for the capture call.
"""
import base64
import os
import re
import sys

TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
from studio import StudioSession, studio_lock  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAG = os.environ.get("MAYDAY_STUDIO_TAG", "mayday-store")
OUT = os.path.join(REPO, "marketing")


def sid():
    with open(os.path.join(REPO, "build", "smoke", ".sid-" + TAG)) as f:
        return f.read().strip()


def capture(name, out_dir):
    with studio_lock(owner="store-art", game="MaydaySeaRescue"):
        with StudioSession() as s:
            ok, texts, images = s.call(
                "screen_capture", {"studio_id": sid(), "capture_id": name}, 90
            )
    if not images:
        sys.exit("capture failed: " + " ".join(texts)[:300])
    raw = os.path.join(REPO, "build", "store", name + ".png")
    os.makedirs(os.path.dirname(raw), exist_ok=True)
    with open(raw, "wb") as f:
        f.write(base64.b64decode(images[0]))
    im = Image.open(raw).convert("RGB")
    w, h = im.size
    if w / h > 16 / 9:
        cw = int(h * 16 / 9)
        im = im.crop(((w - cw) // 2, 0, (w + cw) // 2, h))
    elif w / h < 16 / 9:
        ch = int(w * 9 / 16)
        im = im.crop((0, (h - ch) // 2, w, (h + ch) // 2))
    im = im.resize((1920, 1080), Image.LANCZOS)
    dest = os.path.join(out_dir, "thumbnails", name + ".png")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    im.save(dest)
    print("saved", dest, im.size)


def contact(out_dir):
    folder = os.path.join(out_dir, "thumbnails")
    names = sorted(n for n in os.listdir(folder) if re.match(r"^\d\d_.*\.png$", n))
    if not names:
        sys.exit("no numbered thumbnails in " + folder)
    cell, gap, strip = 480, 8, 24
    ims = [Image.open(os.path.join(folder, n)).convert("RGB") for n in names]
    ch = int(cell * 9 / 16)
    cols = 3 if len(ims) > 4 else 2
    rows = (len(ims) + cols - 1) // cols
    sheet = Image.new("RGB", (gap + cols * (cell + gap), gap + rows * (ch + strip + gap)), (22, 24, 26))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    for i, (im, n) in enumerate(zip(ims, names)):
        r, c = divmod(i, cols)
        x, y = gap + c * (cell + gap), gap + r * (ch + strip + gap)
        sheet.paste(im.resize((cell, ch), Image.LANCZOS), (x, y))
        d.text((x + 3, y + ch + 4), n[:-4], fill=(232, 232, 232), font=font)
    dest = os.path.join(folder, "contact.png")
    sheet.save(dest)
    print("saved", dest, sheet.size)


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    out_dir = args[args.index("--out") + 1] if "--out" in args else OUT
    if args[0] == "contact":
        contact(out_dir)
    elif args[0] == "shot" and len(args) > 1:
        capture(args[1], out_dir)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
