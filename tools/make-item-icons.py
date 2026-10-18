#!/usr/bin/env python3
"""Photoreal 512x512 store icons for every MonetizationConfig item (RP-M4).

usage: tools/make-item-icons.py [--only Key,Key] [--size 1024] [--samples 96] [--skip-render]
  -> marketing/items/<Key>.png (what ~/RobloxProjects/tools/deploy.py --steps monetize uploads)
  -> assets/review/monetization/icons.png (contact sheet for the art review)

Replaces the shared emoji generator (~/RobloxProjects/tools/make-item-icons.py) for this game: every icon is a
Cycles render (tools/item_icons_blender.py, run through tools/blender-run.sh so it takes a heavy-job slot) of the
real in-game assets where one exists, or a clean modelled product shot. This script paints the small procedural
textures (banknote, band, dials, crew card, radio grille), renders, then adds a restrained label to the few items
whose value is a number (2x, +50%, 3,000) and downsamples to 512 px.
"""
import argparse, json, math, os, random, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
WORK = os.path.join(GAME, "build", "item-icons")
TEX, RAW = os.path.join(WORK, "tex"), os.path.join(WORK, "raw")
OUT = os.path.join(GAME, "marketing", "items")
SHEET = os.path.join(GAME, "assets", "review", "monetization", "icons.png")
COND = "/System/Library/Fonts/Avenir Next Condensed.ttc"  # index 0 Bold, 2 Demi Bold, 8 Heavy
SERIF = "/System/Library/Fonts/Supplemental/Didot.ttc"

LABELS = {"DoubleCash": "2x", "CashBoost": "2x", "CrewBoost": "+50%", "StarterKit": "3,000"}


def items():
    out = subprocess.run(["lune", "run", os.path.join(TOOLS, "dump-monetization.luau"), GAME],
                         capture_output=True, text=True, check=True)
    data = json.loads(out.stdout)
    return [(kind, k, v) for kind in ("Products", "GamePasses")
            for k, v in sorted(data[kind].items(), key=lambda kv: kv[1].get("order", 0))]


def font(path, size, index=0):
    return ImageFont.truetype(path, size, index=index)


# ------------------------------------------------------------------ procedural textures
def guilloche(d, box, color, rng, n=26, amp=14, width=1):
    x0, y0, x1, y1 = box
    for i in range(n):
        ph, fr = rng.uniform(0, 6.28), rng.uniform(0.010, 0.022)
        yc = y0 + (y1 - y0) * (i + 0.5) / n
        pts = [(x, yc + amp * math.sin(x * fr + ph) * math.sin(x * fr * 0.37 + i)) for x in range(int(x0), int(x1), 3)]
        d.line(pts, fill=color, width=width)


def rosette(d, c, r, color, k=7, lines=60, width=1):
    for j in range(lines):
        a0 = j / lines * math.tau
        pts = []
        for t in range(0, 361, 3):
            th = math.radians(t)
            rr = r * (0.62 + 0.38 * math.cos(k * th + a0))
            pts.append((c[0] + rr * math.cos(th + a0 / k), c[1] + rr * math.sin(th + a0 / k)))
        d.line(pts, fill=color, width=width)


def note_face(path):
    W, H = 2048, 892
    rng = random.Random(3)
    im = Image.new("RGB", (W, H), (200, 184, 196))
    d = ImageDraw.Draw(im)
    for y in range(H):  # tone shift across the note
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(206 - 18 * t), int(186 - 6 * t), int(194 - 14 * t)))
    guilloche(d, (0, 0, W, H), (170, 146, 166), rng, n=70, amp=22)
    guilloche(d, (0, 0, W, H), (184, 160, 128), rng, n=24, amp=40)
    d.rectangle([28, 28, W - 28, H - 28], outline=(84, 52, 80), width=10)
    d.rectangle([52, 52, W - 52, H - 52], outline=(120, 90, 112), width=3)
    rosette(d, (W * 0.70, H * 0.5), 300, (110, 76, 104), k=9, lines=90, width=2)
    rosette(d, (W * 0.70, H * 0.5), 170, (150, 110, 80), k=5, lines=50, width=2)
    # lighthouse vignette in an oval (simple engraving: tower, lamp, rays)
    ox, oy = W * 0.26, H * 0.52
    d.ellipse([ox - 230, oy - 300, ox + 230, oy + 300], fill=(214, 200, 206), outline=(70, 40, 66), width=6)
    for i in range(0, 600, 9):
        d.line([(ox - 230, oy - 300 + i), (ox + 230, oy - 300 + i)], fill=(200, 184, 194), width=2)
    d.polygon([(ox - 60, oy + 220), (ox + 60, oy + 220), (ox + 34, oy - 120), (ox - 34, oy - 120)], fill=(76, 46, 70))
    for k in range(4):
        y = oy + 180 - k * 85
        d.rectangle([ox - 52 + k * 7, y - 22, ox + 52 - k * 7, y], fill=(212, 198, 204))
    d.rectangle([ox - 46, oy - 175, ox + 46, oy - 120], fill=(232, 216, 150), outline=(76, 46, 70), width=6)
    d.polygon([(ox - 56, oy - 175), (ox + 56, oy - 175), (ox, oy - 230)], fill=(76, 46, 70))
    for a in (-0.35, -0.18, 0.18, 0.35):
        d.line([(ox, oy - 150), (ox + 260 * math.copysign(1, a), oy - 150 - 260 * a * 2)], fill=(170, 150, 150), width=5)
    d.rectangle([ox - 230, oy + 220, ox + 230, oy + 300], fill=(92, 70, 96))
    t1, t2, t3 = font(SERIF, 86, 2), font(SERIF, 64, 0), font(SERIF, 260, 2)
    d.text((W * 0.47, 100), "BANK OF THE GALE ISLES", font=t1, fill=(64, 34, 60))
    d.text((W * 0.50, H - 190), "ONE HUNDRED", font=t2, fill=(64, 34, 60))
    for (x, y) in ((W - 470, H - 330), (90, 70)):
        d.text((x, y), "100", font=t3 if x > 100 else font(SERIF, 150, 2), fill=(70, 38, 64))
    d.text((W * 0.47, 210), "GI 0471862", font=font(COND, 54, 2), fill=(150, 40, 36))
    im = im.filter(ImageFilter.GaussianBlur(1.1))
    im.save(path)


def band(path):
    W, H = 1024, 256
    im = Image.new("RGB", (W, H), (214, 196, 150))
    d = ImageDraw.Draw(im)
    rng = random.Random(9)
    for _ in range(2500):
        x, y = rng.randrange(W), rng.randrange(H)
        c = rng.randint(196, 226)
        d.point((x, y), fill=(c, c - 18, c - 64))
    d.rectangle([0, 18, W, 30], fill=(120, 40, 34))
    d.rectangle([0, H - 30, W, H - 18], fill=(120, 40, 34))
    f = font(COND, 92, 0)
    d.text((W / 2, H / 2), "GALE ISLES  10,000", font=f, fill=(70, 34, 28), anchor="mm")
    im.save(path)


def dial(path):
    S = 1024
    im = Image.new("RGB", (S, S), (222, 214, 194))
    d = ImageDraw.Draw(im)
    c = S / 2
    for i in range(300):
        a = math.radians(i * 1.2 - 90)
        r1 = c * (0.80 if i % 25 == 0 else 0.86 if i % 5 == 0 else 0.90)
        d.line([(c + r1 * math.cos(a), c + r1 * math.sin(a)), (c + c * 0.95 * math.cos(a), c + c * 0.95 * math.sin(a))],
               fill=(20, 20, 20), width=6 if i % 25 == 0 else 3 if i % 5 == 0 else 2)
    f = font(SERIF, 86, 2)
    for i in range(12):
        a = math.radians(i * 30 - 90)
        d.text((c + c * 0.66 * math.cos(a), c + c * 0.66 * math.sin(a)), str(60 if i == 0 else i * 5), font=f, fill=(20, 20, 20), anchor="mm")
    d.ellipse([c - 150, c + 120, c + 150, c + 420], outline=(40, 40, 40), width=4)
    d.text((c, c - 190), "HARBOUR", font=font(COND, 54, 2), fill=(120, 30, 26), anchor="mm")
    im.save(path)


def logbook_cover(path):
    W, H = 840, 1160
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    gold = (196, 158, 82, 255)
    d.rectangle([50, 50, W - 50, H - 50], outline=gold, width=6)
    d.rectangle([70, 70, W - 70, H - 70], outline=gold, width=2)
    d.text((W / 2, 300), "STATION", font=font(SERIF, 100, 2), fill=gold, anchor="mm")
    d.text((W / 2, 420), "LOGBOOK", font=font(SERIF, 100, 2), fill=gold, anchor="mm")
    c = (W / 2, 720)
    d.ellipse([c[0] - 120, c[1] - 120, c[0] + 120, c[1] + 120], outline=gold, width=8)  # lifebuoy emblem
    d.ellipse([c[0] - 62, c[1] - 62, c[0] + 62, c[1] + 62], outline=gold, width=8)
    for a in (45, 135, 225, 315):
        r = math.radians(a)
        d.line([(c[0] + 62 * math.cos(r), c[1] + 62 * math.sin(r)), (c[0] + 120 * math.cos(r), c[1] + 120 * math.sin(r))], fill=gold, width=18)
    d.text((W / 2, 960), "GALE ISLES SEA RESCUE", font=font(COND, 48, 2), fill=gold, anchor="mm")
    base = Image.new("RGBA", (W, H), (9, 14, 26, 255))
    base.alpha_composite(im)
    base.convert("RGB").save(path)


def vip_card(path):
    W, H = 1712, 1080
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    for x in range(W):  # brushed gold gradient
        t = x / W
        g = 0.5 + 0.5 * math.sin(t * 5.0 + 0.6)
        d.line([(x, 0), (x, H)], fill=(int(150 + 70 * g), int(112 + 58 * g), int(46 + 36 * g)))
    rng = random.Random(5)
    for _ in range(4000):
        y = rng.randrange(H)
        x = rng.randrange(W)
        d.line([(x, y), (x + rng.randint(30, 160), y)], fill=(rng.randint(160, 230), rng.randint(120, 180), 60), width=1)
    dark = (60, 40, 14)
    d.text((110, 120), "GALE ISLES SEA RESCUE", font=font(COND, 84, 2), fill=dark)
    d.text((110, 380), "VIP", font=font(SERIF, 330, 2), fill=dark)
    d.text((110, 760), "CREW CARD", font=font(COND, 96, 0), fill=dark)
    d.text((110, 900), "STATION 07  ·  SINCE 2026", font=font(COND, 56, 5), fill=dark)
    d.rounded_rectangle([W - 420, 380, W - 160, 590], radius=30, fill=(200, 170, 100), outline=dark, width=6)  # chip
    for i in range(1, 4):
        d.line([(W - 420, 380 + i * 52), (W - 160, 380 + i * 52)], fill=dark, width=4)
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    im.save(path)


def grille(path):
    S = 1024
    im = Image.new("RGB", (S, S), (54, 44, 34))
    d = ImageDraw.Draw(im)
    for i in range(0, S, 8):
        d.line([(i, 0), (i, S)], fill=(84, 70, 54), width=3)
        d.line([(0, i), (S, i)], fill=(70, 58, 44), width=2)
    im.save(path)


def radio_dial(path):
    W, H = 1024, 800
    im = Image.new("RGB", (W, H), (230, 214, 170))
    d = ImageDraw.Draw(im)
    for i in range(41):
        x = 80 + i * (W - 160) / 40
        d.line([(x, 260), (x, 300 if i % 5 else 340)], fill=(30, 26, 20), width=4)
    f = font(COND, 64, 2)
    for i, lab in enumerate(("530", "700", "900", "1100", "1400", "1600")):
        d.text((80 + i * (W - 160) / 5, 420), lab, font=f, fill=(30, 26, 20), anchor="mm")
    d.line([(560, 180), (560, 560)], fill=(170, 30, 20), width=8)
    d.text((W / 2, 640), "SHANTY RADIO", font=font(SERIF, 80, 2), fill=(30, 26, 20), anchor="mm")
    im.save(path)


def vhf_face(path):
    W, H = 600, 1000
    im = Image.new("RGB", (W, H), (20, 20, 22))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([60, 60, W - 60, 380], radius=24, fill=(150, 170, 120))  # backlit LCD
    d.text((W / 2, 170), "CH 16", font=font(COND, 120, 0), fill=(24, 30, 20), anchor="mm")
    d.text((W / 2, 300), "DISTRESS · 25W", font=font(COND, 54, 2), fill=(24, 30, 20), anchor="mm")
    for r in range(4):
        for c in range(3):
            x, y = 120 + c * 180, 470 + r * 120
            d.rounded_rectangle([x - 60, y - 40, x + 60, y + 40], radius=18, fill=(46, 46, 50))
            d.text((x, y), "123456789*0#"[r * 3 + c], font=font(COND, 54, 2), fill=(210, 210, 210), anchor="mm")
    d.rounded_rectangle([W / 2 - 110, H - 80, W / 2 + 110, H - 30], radius=20, fill=(190, 30, 24))
    im.save(path)


def bandana(path, base=(150, 18, 16), ink=(236, 228, 214), dot=(20, 16, 18), check=False):
    S = 1024
    im = Image.new("RGB", (S, S), base)
    d = ImageDraw.Draw(im)
    rng = random.Random(12)
    if check:  # woven gingham: dark bands both ways, darker where they cross
        dark = tuple(int(v * 0.45) for v in base)
        for i in range(0, S, 64):
            d.rectangle([i, 0, i + 31, S], fill=dark)
        for i in range(0, S, 64):
            for j in range(0, S, 64):
                d.rectangle([j, i, j + 31, i + 31], fill=tuple(int(v * 0.25) for v in base))
                d.rectangle([j + 32, i, j + 63, i + 31], fill=dark)
    else:
        for _ in range(140):  # paisley-like teardrops
            x, y, r = rng.randrange(S), rng.randrange(S), rng.randint(14, 34)
            d.ellipse([x - r, y - r, x + r, y + r], outline=ink, width=4)
            d.ellipse([x - r // 3, y - r // 3, x + r // 3, y + r // 3], fill=dot)
    for k in (40, 70):
        d.rectangle([k, k, S - k, S - k], outline=ink, width=8)
    im.filter(ImageFilter.GaussianBlur(1.2)).save(path)


def tasking(path, title, lines, stamp=None):
    W, H = 1000, 1400
    im = Image.new("RGB", (W, H), (238, 234, 222))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, W, 170], fill=(200, 70, 20))
    d.text((60, 85), title, font=font(COND, 92, 0), fill=(250, 246, 236), anchor="lm")
    y = 250
    for lab, val in lines:
        d.text((60, y), lab, font=font(COND, 48, 2), fill=(90, 86, 80))
        d.text((380, y), val, font=font(COND, 56, 0), fill=(30, 30, 34))
        d.line([(60, y + 80), (W - 60, y + 80)], fill=(200, 196, 186), width=3)
        y += 120
    for i in range(5):
        d.rectangle([60, y + 40 + i * 90, 110, y + 90 + i * 90], outline=(60, 60, 64), width=5)
        d.line([(150, y + 75 + i * 90), (W - 120 - (i * 70) % 240, y + 75 + i * 90)], fill=(150, 146, 140), width=6)
    if stamp:
        st = Image.new("L", (W, H), 0)
        sd = ImageDraw.Draw(st)
        sd.rounded_rectangle([520, 1080, 940, 1260], radius=20, outline=255, width=12)
        sd.text((730, 1170), stamp, font=font(COND, 100, 0), fill=255, anchor="mm")
        st = st.rotate(12, center=(730, 1170))
        im.paste(Image.new("RGB", (W, H), (30, 90, 160)), (0, 0), st.point(lambda v: int(v * 0.8)))
    im.save(path)


def paint_textures():
    os.makedirs(TEX, exist_ok=True)
    for fn, f in (("note_face.png", note_face), ("band.png", band), ("dial.png", dial), ("logbook_cover.png", logbook_cover),
                  ("vip_card.png", vip_card), ("grille.png", grille), ("radio_dial.png", radio_dial),
                  ("vhf_face.png", vhf_face), ("bandana.png", bandana)):
        f(os.path.join(TEX, fn))
    bandana(os.path.join(TEX, "bandana_navy.png"), base=(22, 34, 70))
    bandana(os.path.join(TEX, "bandana_green.png"), base=(40, 92, 52), ink=(226, 220, 200), check=True)
    tasking(os.path.join(TEX, "tasking.png"), "DAILY TASKING", (("TASK", "Tow 2 boats"), ("ZONE", "Calm Bay"), ("CREW", "Any")))
    tasking(os.path.join(TEX, "tasking2.png"), "DAILY TASKING", (("TASK", "3 night calls"), ("ZONE", "Skerries"), ("CREW", "2+")), stamp="SWAPPED")


# ------------------------------------------------------------------ post
def finish(key, src, dst):
    im = Image.open(src).convert("RGB")
    S = im.width
    vig = Image.new("L", (S, S), 0)
    ImageDraw.Draw(vig).ellipse([-S * 0.25, -S * 0.25, S * 1.25, S * 1.25], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(S * 0.12)).point(lambda v: int(255 - (255 - v) * 0.45))
    im = Image.composite(im, Image.new("RGB", (S, S), (0, 0, 0)), vig)
    label = LABELS.get(key)
    if label:
        grad = Image.new("L", (S, S), 0)
        gd = ImageDraw.Draw(grad)
        for y in range(int(S * 0.42)):
            gd.line([(0, y), (S, y)], fill=int(150 * (1 - y / (S * 0.42)) ** 1.8))
        im.paste(Image.new("RGB", (S, S), (6, 8, 10)), (0, 0), grad)
        f = font(COND, int(S * (0.34 if len(label) <= 3 else 0.27 if len(label) <= 4 else 0.22)), 0)
        x, y = int(S * 0.94), int(S * 0.035)
        sh = Image.new("L", (S, S), 0)
        ImageDraw.Draw(sh).text((x + S * 0.006, y + S * 0.01), label, font=f, fill=230, anchor="ra")
        im.paste(Image.new("RGB", (S, S), (0, 0, 0)), (0, 0), sh.filter(ImageFilter.GaussianBlur(S * 0.01)))
        ImageDraw.Draw(im).text((x, y), label, font=f, fill=(248, 244, 234), anchor="ra")
    im.resize((512, 512), Image.LANCZOS).save(dst, optimize=True)


def contact_sheet(rows):
    cell, cap, cols = 300, 34, 6
    n = len(rows)
    sheet = Image.new("RGB", (cols * cell, math.ceil(n / cols) * (cell + cap)), (18, 18, 20))
    d = ImageDraw.Draw(sheet)
    f = font(COND, 22, 2)
    for i, (kind, key, item) in enumerate(rows):
        p = os.path.join(OUT, key + ".png")
        x, y = (i % cols) * cell, (i // cols) * (cell + cap)
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert("RGB").resize((cell - 8, cell - 8), Image.LANCZOS), (x + 4, y + 4))
        tag = "" if item.get("ready", True) else "  (later)"
        d.text((x + 8, y + cell + 4), f"{item['name']}{tag}", font=f, fill=(225, 225, 225))
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    sheet.save(SHEET, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--samples", type=int, default=96)
    ap.add_argument("--skip-render", action="store_true")
    a = ap.parse_args()
    rows = items()
    keys = [k for _, k, _ in rows]
    todo = [k for k in a.only.split(",") if k] or keys
    unknown = [k for k in todo if k not in keys]
    if unknown:
        sys.exit(f"unknown item keys: {unknown}")
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(RAW, exist_ok=True)
    if not a.skip_render:
        paint_textures()
        cmd = [os.path.join(TOOLS, "blender-run.sh"), os.path.join(GAME, "tools", "item_icons_blender.py"), "--",
               TEX, RAW, str(a.size), str(a.samples), ",".join(todo)]
        log = os.path.join(WORK, "blender.log")
        with open(log, "w") as fh:
            subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT)
        failed = [l for l in open(log) if l.startswith("[icons] FAILED") or "Error" in l or "Traceback" in l]
        print("".join(failed[-12:]) or "blender: no errors", end="")
    missing = []
    for k in todo:
        src = os.path.join(RAW, k + ".png")
        if not os.path.exists(src):
            missing.append(k)
            continue
        finish(k, src, os.path.join(OUT, k + ".png"))
    contact_sheet(rows)
    print(f"icons: {len(todo) - len(missing)} written to {OUT}; sheet {SHEET}" + (f"; MISSING {missing}" if missing else ""))
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
