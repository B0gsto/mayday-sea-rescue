"""Shared atlas of the pirate boat and its crew: 16 x 16 flat colour cells in the bottom rows, printed tiles above.

Cell index = list order, row 0 is the bottom of UV space (v = 0). Printed tiles are pixel rects (image origin top left).
Hexes come from the owner-cleared concepts (Pirate Rescue Boat, Pirate Crew Concept).
"""
GRID, SIZE = 16, 1024

_HEX = """582A12 352100 E4CD9E 958A73 AA7D55 C91A09 F3E6C4 6C6E68 A0A5A9 720E0F F4F4F4 1B1E22 D4A040 FFD84A B79F72 8E4F24
F1C29A EBA27E 7A1F2B 5A1520 F2B632 F4E9D0 26242B EFE6D2 18181C 3A3A40 2E221D D7262E E84850 2FB54A 2F7DE1 EFE2C4
B5763A 6A4127 C68A5E B87A50 F7F5F0 1E3F7A 1F5FD0 1A4FB0 C8283A 3B4556 D9A86C 8A5A3C 7C4E33 E0A526 5E6B2E 2F3B52
BFE6FF 2B2228""".split()
(HULL, DARK, TAN, DTAN, NOUGAT, RED, CREAM, SHARK, BELLY, DRED, WHITE, BLACK, GOLD, LIT, ROPE, TILE3,
 CSKIN, CNOSE, COAT, LAPEL, TRIM, CUFF, FELT, BREECH, BOOT, SOLE, BEARD, PARROT, PBELLY, WING, WTIP, BEAK,
 WHEEL, POST, ASKIN, ANOSE, ASHIRT, ASTRIPE, BANDANA, BFOLD, SASH, APANTS, OAR, BSKIN, BNOSE, BSHIRT, VEST, BPANTS,
 LENS, LEATHER) = range(50)
GLOSS = {GOLD: (0.25, 0.9), LIT: (0.3, 0.0), SHARK: (0.45, 0.0), FELT: (0.75, 0.0), RED: (0.7, 0.0), CREAM: (0.8, 0.0),
         ROPE: (0.8, 0.0), LENS: (0.15, 0.0)}

FLAG = (0, 0, 512, 334)
FACE = {"captain": (0, 340, 384, 468), "crewA": (384, 340, 768, 468), "crewB": (0, 470, 384, 598)}
TORSO = {"captain": ((512, 0, 768, 256), (768, 0, 1024, 256)),
         "crewA": ((512, 256, 768, 512), (512, 256, 768, 512)),
         "crewB": ((768, 256, 1024, 512), (384, 470, 512, 598))}
BADGE = (768, 512, 896, 640)


# one cell per (colour, material) of the boat spec (concept_spec.json, crew and jet ski excluded)
_SPEC = {}
_MAT = {"gold": (0.3, 0.75), "metal": (0.38, 0.6), "glow": (0.3, 0.0), "glass": (0.08, 0.1), "trans": (0.1, 0.0), "rope": (0.9, 0.0),
        "cloth": (0.8, 0.0), "rubber": (0.6, 0.0)}


def _load_spec():
    import json
    import os
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "concept_spec.json")) as f:
        for p in json.load(f)["parts"]:
            if p["group"] not in ("crew", "jetski"):
                key = (p["color"].upper(), p["material"])
                if key not in _SPEC:
                    _SPEC[key] = len(_HEX)
                    _HEX.append(p["color"].lstrip("#").upper())
                    GLOSS[_SPEC[key]] = _MAT.get(p["material"], (0.42, 0.0))


# round 2 (art director): darker shark, bright mouth, pure red and yellow macaw
# round 3: steel-grey head with a white belly, darker sail cells at the leeches for volume
STEEL, STEEL_DARK, BELLY_W, MOUTH, THROAT, PALATE, TONGUE, MACAW_R, MACAW_Y, DAIS, RED_DARK, CREAM_DARK = (
    "#8493A3", "#2B3440", "#F2F5F7", "#F01A1E", "#8A0A14", "#FF4A5A", "#FF8CA0", "#F0141E", "#FFD21E", "#C99C6A", "#A00C24", "#D5C8A6")


def _extra():
    for hexv, mat in ((STEEL, "abs"), (STEEL_DARK, "abs"), (BELLY_W, "abs"), (MOUTH, "abs"), (THROAT, "abs"), (PALATE, "abs"), (TONGUE, "abs"),
                      (MACAW_R, "abs"), (MACAW_Y, "abs"), (DAIS, "abs"), (RED_DARK, "cloth"), (CREAM_DARK, "cloth")):
        key = (hexv.upper(), mat)
        if key not in _SPEC:
            _SPEC[key] = len(_HEX)
            _HEX.append(hexv.lstrip("#").upper())


_load_spec()
_extra()


def cell(color, material):
    return _SPEC[(color.upper(), material)]


def rgb(i):
    h = _HEX[i]
    return tuple(int(h[k:k + 2], 16) for k in (0, 2, 4))


def uv_rect(rect):
    x0, y0, x1, y1 = rect
    return x0 / SIZE, 1 - y1 / SIZE, x1 / SIZE, 1 - y0 / SIZE


def _layer(rect):
    from PIL import Image, ImageDraw
    w, h = rect[2] - rect[0], rect[3] - rect[1]
    img = Image.new("RGBA", (w * 4, h * 4))
    return img, ImageDraw.Draw(img), w * 4, h * 4


def _skull(d, cx, cy, s, bone, hole):
    d.ellipse((cx - s, cy - s * 1.0, cx + s, cy + s * 0.75), fill=bone)
    d.rounded_rectangle((cx - s * 0.58, cy + s * 0.4, cx + s * 0.58, cy + s * 1.08), s * 0.14, fill=bone)
    for k in (-1, 1):
        d.ellipse((cx + k * s * 0.42 - s * 0.26, cy - s * 0.24, cx + k * s * 0.42 + s * 0.26, cy + s * 0.3), fill=hole)
    d.polygon([(cx, cy + s * 0.28), (cx - s * 0.13, cy + s * 0.55), (cx + s * 0.13, cy + s * 0.55)], fill=hole)
    for k in (-0.26, 0, 0.26):
        d.rectangle((cx + k * s - s * 0.035, cy + s * 0.72, cx + k * s + s * 0.035, cy + s * 1.08), fill=hole)


def _flag(rect):
    import math
    img, d, w, h = _layer(rect)
    bone = rgb(WHITE)
    d.rectangle((0, 0, w, h), fill=rgb(BLACK))
    cx, cy = w / 2, h * 0.47
    L = h * 0.62
    for a in (32, -32):                      # crossed oars behind the skull
        c, s = math.cos(math.radians(a)), math.sin(math.radians(a))
        rot = lambda u, v: (cx + u * c - v * s, cy + u * s + v * c)
        t = h * 0.03
        d.polygon([rot(-L, -t), rot(L * 0.72, -t), rot(L * 0.72, t), rot(-L, t)], fill=bone)
        d.polygon([rot(L * 0.68, -t), rot(L * 0.8, -h * 0.085), rot(L * 1.12, -h * 0.085), rot(L * 1.18, 0),
                   rot(L * 1.12, h * 0.085), rot(L * 0.8, h * 0.085), rot(L * 0.68, t)], fill=bone)
    d.ellipse((cx - h * 0.31, cy - h * 0.31, cx + h * 0.31, cy + h * 0.27), fill=rgb(BLACK))
    sk = h * 0.25
    _skull(d, cx, cy - h * 0.04, sk, bone, rgb(BLACK))
    ex, ey = cx + sk * 0.42, cy - h * 0.04 + sk * 0.03     # the wink
    d.ellipse((ex - sk * 0.28, ey - sk * 0.3, ex + sk * 0.28, ey + sk * 0.3), fill=bone)
    d.arc((ex - sk * 0.26, ey - sk * 0.12, ex + sk * 0.26, ey + sk * 0.3), 195, 345, fill=rgb(BLACK), width=int(sk * 0.13))
    return img


def _eye(d, x, y, w, h, ink):
    d.ellipse((x - w, y - h, x + w, y + h), fill=(255, 255, 255), outline=ink, width=max(4, int(w * 0.16)))
    d.ellipse((x - w * 0.55, y - h * 0.62, x + w * 0.55, y + h * 0.62), fill=ink)
    d.ellipse((x - w * 0.3, y - h * 0.5, x - w * 0.02, y - h * 0.14), fill=(255, 255, 255))


def _face(rect, who):
    img, d, w, h = _layer(rect)
    ink = (32, 26, 30)
    skin = rgb({"captain": CSKIN, "crewA": ASKIN, "crewB": BSKIN}[who])
    d.rectangle((0, 0, w, h), fill=skin)
    cx, ey, ex = w / 2, h * 0.38, w * 0.125
    if who == "captain":
        d.pieslice((cx - w * 0.3, h * 0.1, cx + w * 0.3, h * 1.24), 0, 180, fill=rgb(BEARD))    # full beard
        d.rectangle((cx - w * 0.3, h * 0.66, cx + w * 0.3, h), fill=rgb(BEARD))
        for k in (-1, 1):
            _eye(d, cx + k * ex, ey, h * 0.13, h * 0.17, ink)
            d.polygon([(cx + k * ex * 0.32, ey - h * 0.14), (cx + k * ex * 1.9, ey - h * 0.26),
                       (cx + k * ex * 1.9, ey - h * 0.4), (cx + k * ex * 0.32, ey - h * 0.3)], fill=(42, 34, 36))
            d.ellipse((cx + k * w * 0.13 - w * 0.075, h * 0.6, cx + k * w * 0.13 + w * 0.075, h * 0.76), fill=(28, 26, 30))
            d.ellipse((cx + k * w * 0.205 - h * 0.09, h * 0.54, cx + k * w * 0.205 + h * 0.09, h * 0.7), fill=(28, 26, 30))
        d.pieslice((cx - w * 0.06, h * 0.68, cx + w * 0.06, h * 0.94), 0, 180, fill=(240, 240, 235))
    elif who == "crewA":
        _eye(d, cx - ex, ey, h * 0.13, h * 0.17, ink)
        d.polygon([(cx - ex * 1.85, ey - h * 0.26), (cx - ex * 0.3, ey - h * 0.34), (cx - ex * 0.3, ey - h * 0.22),
                   (cx - ex * 1.85, ey - h * 0.14)], fill=ink)
        d.line((cx + ex * 0.2, ey - h * 0.42, cx + w * 0.34, ey + h * 0.2), fill=rgb(BLACK), width=int(h * 0.06))
        d.ellipse((cx + ex - h * 0.2, ey - h * 0.2, cx + ex + h * 0.2, ey + h * 0.22), fill=rgb(BLACK))
        d.polygon([(cx + ex * 0.3, ey - h * 0.36), (cx + ex * 1.85, ey - h * 0.28), (cx + ex * 1.85, ey - h * 0.18),
                   (cx + ex * 0.3, ey - h * 0.24)], fill=ink)
        for k in range(14):                   # stubble
            x = cx + (k - 6.5) * w * 0.028
            d.ellipse((x - 5, h * (0.8 + 0.05 * (k % 2)) - 5, x + 5, h * (0.8 + 0.05 * (k % 2)) + 5), fill=(120, 80, 54))
        d.arc((cx - w * 0.15, h * 0.34, cx + w * 0.15, h * 0.78), 25, 155, fill=ink, width=int(h * 0.05))
    else:
        for k in (-1, 1):
            _eye(d, cx + k * ex, ey, h * 0.13, h * 0.17, ink)
            d.arc((cx + k * ex - h * 0.19, ey - h * 0.42, cx + k * ex + h * 0.19, ey - h * 0.02), 200, 340, fill=ink,
                  width=int(h * 0.05))
            for j in range(3):                # freckles
                x = cx + k * (ex * 1.05 + j * w * 0.018)
                d.ellipse((x - 5, h * 0.62 + j * 8 - 5, x + 5, h * 0.62 + j * 8 + 5), fill=(90, 56, 36))
        d.pieslice((cx - w * 0.11, h * 0.5, cx + w * 0.11, h * 0.92), 0, 180, fill=ink)
        d.rectangle((cx - w * 0.09, h * 0.71, cx + w * 0.09, h * 0.77), fill=(255, 255, 255))
        d.rectangle((cx + w * 0.02, h * 0.71, cx + w * 0.055, h * 0.77), fill=rgb(TRIM))     # the gold tooth
    return img


def _torso(rect, who, side):
    img, d, w, h = _layer(rect)
    if who == "crewA":
        d.rectangle((0, 0, w, h), fill=rgb(ASHIRT))
        a = h * 0.78 / 10
        for k in range(5):                    # exactly 5 navy stripes above the sash
            d.rectangle((0, a * (2 * k + 1), w, a * (2 * k + 2)), fill=rgb(ASTRIPE))
        return img
    if who == "captain":
        d.rectangle((0, 0, w, h), fill=rgb(COAT))
        if side == 0:
            d.polygon([(w * 0.31, 0), (w * 0.69, 0), (w * 0.5, h * 0.64)], fill=rgb(CUFF))
            for k in range(4):
                y = h * (0.08 + 0.13 * k)
                d.arc((w / 2 - w * (0.14 - 0.02 * k), y - h * 0.04, w / 2 + w * (0.14 - 0.02 * k), y + h * 0.05), 0, 180,
                      fill=(170, 145, 110), width=8)
            for k in (-1, 1):
                r = lambda t: w / 2 + k * w * t
                d.polygon([(r(0.19), 0), (r(0.03), h * 0.6), (r(0.2), h * 0.44), (r(0.34), h * 0.16), (r(0.36), 0)],
                          fill=rgb(LAPEL), outline=rgb(TRIM), width=12)
                for j in range(3):
                    d.ellipse((r(0.3) - w * 0.035, h * (0.56 + j * 0.15), r(0.3) + w * 0.035, h * (0.63 + j * 0.15)), fill=rgb(TRIM))
            d.line((w / 2, h * 0.62, w / 2, h), fill=rgb(TRIM), width=12)
        else:
            d.line((w / 2, h * 0.45, w / 2, h), fill=(70, 18, 26), width=14)
            for t in (0.42, 0.58):
                d.ellipse((w * t - w * 0.035, h * 0.47, w * t + w * 0.035, h * 0.54), fill=rgb(TRIM))
            d.arc((w * 0.12, -h * 0.1, w * 0.88, h * 0.2), 0, 180, fill=rgb(TRIM), width=16)
        return img
    if side == 0:                             # crew B front: mustard shirt, open patched vest
        d.rectangle((0, 0, w, h), fill=rgb(BSHIRT))
        for k in (0, 1):
            x0, x1, x2 = (0, w * 0.34, w * 0.42) if k == 0 else (w, w * 0.66, w * 0.58)
            d.polygon([(x0, 0), (x1, 0), (x2, h), (x0, h)], fill=rgb(VEST))
            d.line((x1, 0, x2, h), fill=rgb(CUFF), width=10)
        d.rectangle((w * 0.06, h * 0.42, w * 0.26, h * 0.62), fill=(46, 140, 134), outline=rgb(CUFF), width=5)
        d.rectangle((w * 0.72, h * 0.18, w * 0.9, h * 0.34), fill=(200, 164, 106), outline=rgb(CUFF), width=5)
        for k in (-1, 1):
            d.polygon([(w / 2, h * 0.03), (w / 2 + k * w * 0.16, 0), (w / 2 + k * w * 0.07, h * 0.17)], fill=(255, 255, 255))
    else:
        d.rectangle((0, 0, w, h), fill=rgb(VEST))
        d.rectangle((w * 0.18, h * 0.3, w * 0.44, h * 0.52), fill=(200, 164, 106), outline=rgb(CUFF), width=5)
        d.rectangle((w * 0.58, h * 0.55, w * 0.8, h * 0.75), fill=(46, 140, 134), outline=rgb(CUFF), width=5)
    return img


def _badge(rect):
    img, d, w, h = _layer(rect)
    d.rectangle((0, 0, w, h), fill=rgb(FELT))
    _skull(d, w / 2, h * 0.46, h * 0.36, (241, 230, 207), rgb(FELT))
    return img


def write_maps(out_dir, name, set_name):
    """Writes T_<name>_<set>_{ALB,NOR,RGH,MET}.png into out_dir; returns the ALB path."""
    import os
    from PIL import Image, ImageDraw

    os.makedirs(out_dir, exist_ok=True)
    cell = SIZE // GRID
    alb = Image.new("RGB", (SIZE, SIZE), rgb(CUFF))
    rgh = Image.new("L", (SIZE, SIZE), 128)
    met = Image.new("L", (SIZE, SIZE), 0)
    for tgt, draw in ((alb, ImageDraw.Draw(alb)),):
        for i in range(len(_HEX)):
            col, row = i % GRID, GRID - 1 - i // GRID
            box = (col * cell, row * cell, (col + 1) * cell - 1, (row + 1) * cell - 1)
            draw.rectangle(box, fill=rgb(i))
            r, m = GLOSS.get(i, (0.42, 0.0))
            ImageDraw.Draw(rgh).rectangle(box, fill=int(r * 255))
            ImageDraw.Draw(met).rectangle(box, fill=int(m * 255))
    tiles = [(FLAG, _flag(FLAG)), (BADGE, _badge(BADGE))]
    tiles += [(r, _face(r, w)) for w, r in FACE.items()]
    for w, pair in TORSO.items():
        tiles += [(r, _torso(r, w, s)) for s, r in enumerate(pair)]
    for r, img in tiles:
        alb.paste(img.convert("RGB").resize((r[2] - r[0], r[3] - r[1]), Image.LANCZOS), r[:2])
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    alb.save(stem + "ALB.png")
    rgh.convert("RGB").save(stem + "RGH.png")
    met.convert("RGB").save(stem + "MET.png")
    Image.new("RGB", (SIZE, SIZE), (128, 128, 255)).save(stem + "NOR.png")
    return stem + "ALB.png"
