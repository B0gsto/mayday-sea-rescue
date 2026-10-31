#!/usr/bin/env python3
"""Kit menu icons, half 2 (lifebuoy, lock, map, quests, settings, sun, shop, vip, spin, wave, waves), in the stickers.py
house style: one die-cut sticker per icon (white rim and hard outline round the UNION of its parts, a darker lip under
each part, bold top-down gradients, a soft gloss). Drawn in a 200-unit box (rim 30, outline 12, lip 12 like every
Kit sticker); the square viewBox is fitted so the art fills 88% of it, centred. Writes art/source/ui/kit_<name>.svg and renders each
at a 128x128 page --keep (256 px).   usage: python3 tools/ui-art/kit_icons2.py <out_dir> [--manifest file.json]"""
import json
import math
import pathlib
import subprocess
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "art/source/ui"
INK, BOX, FILL = "#14121C", 275.0, 0.88
RED, BLUE, GREEN = ("#FF8A7A", "#E2333A", "#A3161E"), ("#8EE0FF", "#2C8EF0", "#1A55A8"), ("#A4F57A", "#33BE4D", "#1F8A33")
GOLD, TEAL, ORANGE = ("#FFE45C", "#FFAE00", "#C27400"), ("#8FF5E2", "#1DB59B", "#13776E"), ("#FFC266", "#FF7419", "#B84A08")
WHITE = ("#FFFFFF", "#D6DEEA", "#8E9AB2")


def circ(cx, cy, r):
    return f"M{cx - r},{cy} A{r},{r} 0 1,0 {cx + r},{cy} A{r},{r} 0 1,0 {cx - r},{cy} Z"


def part(d, col, z=0, sep=False, dy=12, lip=None):
    """col: (top, bottom, lip); sep: its own ink outline over the parts behind it (a front piece)"""
    return dict(d=d, top=col[0], bot=col[1], lip=lip or col[2], z=z, sep=sep, dy=dy)


def ink(x1, y1, x2, y2, w=8, c=INK):
    return f'<path d="M{x1},{y1} L{x2},{y2}" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>'


def stud(cx, cy, r, light, dark):
    """a Lego stud top: a lighter disc in a dark ring and a gloss arc"""
    a = r * 0.62
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{light}" stroke="{dark}" stroke-width="7"/>'
            f'<path d="M{cx - a},{cy + r * 0.05} A{a},{a} 0 0,1 {cx - r * 0.05},{cy - a}" fill="none" stroke="#fff" '
            'stroke-opacity="0.75" stroke-width="7" stroke-linecap="round"/>')


def build(parts, gloss=(), extra=""):
    path = lambda d, fill, dy=0, stroke=None, w=0: (
        f'<path d="{d}" fill="{fill}"' + (f' transform="translate(0,{dy})"' if dy else "")
        + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
    defs, out = [], []
    for i, p in enumerate(parts):
        defs.append(f'<linearGradient id="g{i}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{p["top"]}"/>'
                    f'<stop offset="1" stop-color="{p["bot"]}"/></linearGradient>')
    for colour, w in (("#fff", 30), (INK, 12)):  # the union rim, then the union outline, lip copies included
        out += [path(p["d"], colour, dy, colour, w) for p in parts for dy in (0, p["dy"])]
    for z in sorted({p["z"] for p in parts}):
        group = [(i, p) for i, p in enumerate(parts) if p["z"] == z]
        out += [path(p["d"], INK, dy, INK, 12) for _, p in group if p["sep"] for dy in (0, p["dy"])]
        out += [path(p["d"], p["lip"], p["dy"]) for _, p in group if p["dy"]]
        out += [path(p["d"], f"url(#g{i})") for i, p in group]
    out += [f'<path d="{g}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round"/>'
            for g in gloss]
    return "<defs>" + "".join(defs) + "</defs>" + "".join(out) + extra


def ring_sector(cx, cy, r0, r1, a0, a1):
    p = lambda r, a: f"{cx + r * math.cos(math.radians(a)):.1f},{cy + r * math.sin(math.radians(a)):.1f}"
    return f"M{p(r0, a0)} L{p(r1, a0)} A{r1},{r1} 0 0,1 {p(r1, a1)} L{p(r0, a1)} A{r0},{r0} 0 0,0 {p(r0, a0)} Z"


def polar(cx, cy, r, a):
    return cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))


# ---- the icons -------------------------------------------------------------------------------------------------------
def lifebuoy():
    """rescue / pickup ring: a fat red ring, four white bands, a small dark hole"""
    c, R, r = (100, 98), 88, 34
    bands = [part(ring_sector(*c, r, R, a - 19, a + 19), WHITE) for a in (45, 135, 225, 315)]
    seams = "".join(ink(*polar(*c, r, a), *polar(*c, R, a), w=7) for b in (45, 135, 225, 315) for a in (b - 19, b + 19))
    hole = (f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="#7A0F16"/>'
            f'<circle cx="{c[0]}" cy="{c[1] + 7}" r="{r - 3}" fill="{INK}"/>'
            f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="none" stroke="{INK}" stroke-width="8"/>')
    return build([part(circ(*c, R), RED)] + bands, gloss=["M28,82 A72,72 0 0,1 58,36"], extra=seams + hole)


def lock():
    """locked: a gold padlock, front on, silver shackle"""
    shackle = "M50,98 L50,66 A50,50 0 0,1 150,66 L150,98 L122,98 L122,66 A22,22 0 0,0 78,66 L78,98 Z"
    body = "M48,88 L152,88 Q172,88 172,108 L172,166 Q172,186 152,186 L48,186 Q28,186 28,166 L28,108 Q28,88 48,88 Z"
    keyhole = (f'<circle cx="100" cy="126" r="17" fill="{INK}"/>'
               f'<path d="M90,130 L110,130 L115,162 Q116,168 110,168 L90,168 Q84,168 85,162 Z" fill="{INK}"/>')
    return build([part(shackle, ("#FFFFFF", "#A9B6CC", "#6B7891")), part(body, GOLD, z=1, sep=True)],
                 gloss=["M44,118 L44,104 Q44,100 50,100 L70,100", "M62,62 A38,38 0 0,1 86,32"], extra=keyhole)


def map_():
    """the full map: a chart folded in three, a bold dashed route to a red X"""
    pts = [(14, 46), (72, 28), (128, 46), (186, 28)]
    bot = [(14, 172), (72, 154), (128, 172), (186, 154)]
    light, dark = ("#FFF6BF", "#FFD54A", "#C27400"), ("#FFD447", "#EE9A00", "#A86400")
    panels = [part(f"M{pts[i][0]},{pts[i][1]} L{pts[i + 1][0]},{pts[i + 1][1]} L{bot[i + 1][0]},{bot[i + 1][1]} "
                   f"L{bot[i][0]},{bot[i][1]} Z", dark if i == 1 else light) for i in range(3)]
    folds = ink(72, 28, 72, 154, 8) + ink(128, 46, 128, 172, 8)
    route = "M38,146 C58,104 92,150 112,112 S140,72 146,74"
    dash = 'stroke-dasharray="15 15" stroke-linecap="round" fill="none"'
    line = (f'<path d="{route}" stroke="{INK}" stroke-width="22" {dash}/>'
            f'<path d="{route}" stroke="#E2333A" stroke-width="11" {dash}/>')
    x = lambda w, c: ink(140, 54, 172, 86, w, c) + ink(172, 54, 140, 86, w, c)
    start = f'<circle cx="38" cy="146" r="11" fill="#2C8EF0" stroke="{INK}" stroke-width="7"/>'
    return build(panels, gloss=["M26,66 L58,56"], extra=folds + line + x(28, INK) + x(14, "#E2333A") + start)


def quests():
    """quest board / pontoons: a scroll with a big red Lego seal"""
    body = "M40,40 L160,40 L160,160 L40,160 Z"
    roll = lambda y: f"M40,{y} L160,{y} Q178,{y} 178,{y + 17} Q178,{y + 34} 160,{y + 34} L40,{y + 34} Q22,{y + 34} 22,{y + 17} Q22,{y} 40,{y} Z"
    seal = circ(134, 132, 34)
    lines = ink(60, 80, 140, 80, 11, "#D1962A") + ink(60, 106, 112, 106, 11, "#D1962A")
    return build([part(body, ("#FFF9DC", "#FFE07A", "#C27400")), part(roll(18), GOLD, z=1, sep=True),
                  part(roll(144), GOLD, z=1, sep=True), part(seal, RED, z=2, sep=True)],
                 gloss=["M36,28 L74,28"], extra=lines + stud(134, 132, 19, "#FF9A8E", "#A3161E"))


def settings():
    """settings: a chunky orange gear round a Lego stud hub"""
    c, ro, rr, teeth = (100, 98), 90, 70, 8
    d = ""
    for i in range(teeth):
        a = i * 360 / teeth
        p = [polar(*c, rr, a - 17), polar(*c, ro, a - 10), polar(*c, ro, a + 10), polar(*c, rr, a + 17)]
        nxt = polar(*c, rr, a + 360 / teeth - 17)
        d += ("M" if i == 0 else "L") + f"{p[0][0]:.1f},{p[0][1]:.1f} " + " ".join(f"L{x:.1f},{y:.1f}" for x, y in p[1:])
        d += f" A{rr},{rr} 0 0,1 {nxt[0]:.1f},{nxt[1]:.1f} "
    hub = (f'<circle cx="{c[0]}" cy="{c[1]}" r="38" fill="{INK}"/>' + stud(c[0], c[1], 27, "#FFF0C8", "#B84A08"))
    return build([part(d + "Z", ORANGE)], gloss=["M38,86 A62,62 0 0,1 70,42"], extra=hub)


def sun():
    """golden hour: a gold sun, eight fat orange rays"""
    c = (100, 96)
    rays = ""
    for i in range(8):
        a = i * 45 - 90
        (x0, y0), (x1, y1), (x2, y2) = polar(*c, 50, a - 17), polar(*c, 92, a), polar(*c, 50, a + 17)
        rays += f"M{x0:.1f},{y0:.1f} L{x1:.1f},{y1:.1f} L{x2:.1f},{y2:.1f} Z "
    return build([part(rays, ORANGE), part(circ(*c, 54), GOLD, z=1, sep=True)], gloss=["M66,92 A36,36 0 0,1 92,62"])


def shop():
    """the shop: a market stall, four bold awning stripes, a gold coin-stud on the counter"""
    stripes = []
    for i in range(4):
        tl, tr, bl, br = 26 + 37 * i, 63 + 37 * i, 12 + 44 * i, 56 + 44 * i
        stripes.append(part(f"M{tl},28 L{tr},28 L{br},84 A22,20 0 0,1 {bl},84 Z", RED if i % 2 == 0 else WHITE, z=1))
    body = "M34,80 L166,80 L166,170 Q166,182 154,182 L46,182 Q34,182 34,170 Z"
    seams = "".join(ink(26 + 37 * i, 28, 12 + 44 * i, 84, 7) for i in (1, 2, 3)) + ink(26, 28, 174, 28, 7)
    return build([part(body, BLUE), *stripes, part(circ(100, 138, 30), GOLD, z=2, sep=True)],
                 gloss=["M40,40 L36,62"], extra=seams + stud(100, 138, 17, "#FFF3A8", "#C27400"))


def vip():
    """VIP pass: a gold crown, stud-ball tips, a deep band with one big red gem"""
    crown = "M30,150 L22,62 L66,102 L100,48 L134,102 L178,62 L170,150 Z"
    tips = [part(circ(x, y, 15), GOLD) for x, y in ((22, 56), (100, 40), (178, 56))]
    band = "M34,126 L166,126 Q180,126 180,140 L180,162 Q180,176 166,176 L34,176 Q20,176 20,162 L20,140 Q20,126 34,126 Z"
    gem = (f'<path d="M100,134 L122,151 L100,168 L78,151 Z" fill="#E2333A" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
           '<path d="M100,141 L112,151 L100,151 Z" fill="#FFB3A8"/>')
    return build([part(crown, GOLD), *tips, part(band, ("#FFD84A", "#F09A00", "#9A5800"), z=1, sep=True, dy=16)],
                 gloss=["M44,98 L40,130"], extra=gem)


def spin():
    """the prize wheel: a gold rim, six bold wedges, a chunky red pointer, a stud hub"""
    c, R, r = (100, 110), 84, 64
    cols = ["#F2333E", "#FFFFFF", "#2C8EF0", "#F2333E", "#FFFFFF", "#2C8EF0"]
    wedges = "".join(f'<path d="{ring_sector(*c, 0.01, r, -90 + 60 * i, -30 + 60 * i)}" fill="{col}"/>'
                     for i, col in enumerate(cols))
    seams = "".join(ink(*c, *polar(*c, r, -90 + 60 * i), 7) for i in range(6))
    face = (wedges + seams + f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="none" stroke="{INK}" stroke-width="8"/>'
            f'<circle cx="{c[0]}" cy="{c[1]}" r="23" fill="{INK}"/>' + stud(c[0], c[1], 15, "#FFF3A8", "#C27400"))
    pointer = "M72,6 L128,6 Q138,6 132,16 L106,52 Q100,60 94,52 L68,16 Q62,6 72,6 Z"
    return build([part(circ(*c, R), GOLD), part(pointer, RED, z=1, sep=True, dy=8)],
                 gloss=["M30,96 A72,72 0 0,1 50,56", "M78,16 L112,16"], extra=face)


def wave():
    """the wake trail prize: a teal curling crest over a blue swell"""
    crest = ("M14,176 L14,140 C14,84 58,38 112,34 C154,32 188,58 188,92 C188,118 168,130 150,126 "
             "C134,122 128,106 138,96 C124,84 102,90 96,110 C90,130 106,150 132,152 L188,152 L188,176 Z")
    swell = "M12,156 Q34,138 56,156 T100,156 T144,156 T188,156 L188,180 Q188,186 182,186 L18,186 Q12,186 12,180 Z"
    return build([part(crest, TEAL), part(swell, BLUE, z=1, sep=True)],
                 gloss=["M34,120 C40,86 64,60 96,52"])


def waves():
    """spin-wheel wake prizes: two thick blue swells"""
    band = lambda y: (f"M14,{y} Q35.5,{y - 20} 57,{y} T100,{y} T143,{y} T186,{y} L186,{y + 40} "
                      f"Q164.5,{y + 60} 143,{y + 40} T100,{y + 40} T57,{y + 40} T14,{y + 40} Z")
    return build([part(band(36), BLUE), part(band(112), BLUE)],
                 gloss=["M26,46 Q36,34 50,38", "M26,122 Q36,110 50,114"])


ICONS = {"lifebuoy": lifebuoy, "lock": lock, "map": map_, "quests": quests, "settings": settings, "sun": sun,
         "shop": shop, "vip": vip, "spin": spin, "wave": wave, "waves": waves}


def write(name, body, x0, y0, box=BOX):
    (SRC / f"kit_{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {box:.1f} {box:.1f}" width="128" height="128">'
        f"<!-- Kit.{name}: {ICONS[name].__doc__} (tools/ui-art/kit_icons2.py) -->{body}</svg>\n")


def render(name, out):
    cmd = ["python3", "tools/ui-art/render.py", f"art/source/ui/kit_{name}.svg", str(out), "--size", "128", "128", "--keep"]
    subprocess.run(cmd, cwd=ROOT, check=True, capture_output=True)
    return " ".join(cmd)


if __name__ == "__main__":
    out_dir, manifest = pathlib.Path(sys.argv[1]), {}
    for name, fn in ICONS.items():
        body, png = fn(), out_dir / f"Kit.{name}.png"
        write(name, body, -37.5, -37.5)  # measure the art (rim included) in a roomy box,
        render(name, png)
        l, t, r, b = Image.open(png).getbbox()
        k = BOX / 256
        box = max(r - l, b - t) * k / FILL  # then fit a square box round it: the art fills FILL of the sprite
        write(name, body, -37.5 + (l + r) / 2 * k - box / 2, -37.5 + (t + b) / 2 * k - box / 2, box)
        cmd = render(name, png)
        im = Image.open(png)
        l, t, r, b = im.getbbox()
        assert im.size[0] == im.size[1] and l > 0 and t > 0, (name, im.size, (l, t, r, b))  # square, rim not clipped
        print(f"Kit.{name}", im.size, "fill %.2f" % (max(r - l, b - t) / im.size[0]))
        manifest[f"Kit.{name}"] = {"svg": f"art/source/ui/kit_{name}.svg", "cmd": cmd}
    if "--manifest" in sys.argv:
        pathlib.Path(sys.argv[sys.argv.index("--manifest") + 1]).write_text(json.dumps(manifest, indent=1) + "\n")
