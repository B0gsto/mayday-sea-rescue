#!/usr/bin/env python3
"""Kit menu icons, half 2 (lifebuoy, lock, map, quests, settings, sun, vip; shop/spin/wave live in kit_icons4.py, waves is hand SVG), in the stickers.py
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
    """rescue / pickup ring: a fat red ring, four white bands (one with a Lego stud), a sea-blue hole"""
    c, R, r = (100, 98), 88, 34
    bands = [part(ring_sector(*c, r, R, a - 19, a + 19), WHITE, dy=16) for a in (0, 90, 180, 270)]
    seams = "".join(ink(*polar(*c, r, a), *polar(*c, R, a), w=7) for b in (0, 90, 180, 270) for a in (b - 19, b + 19))
    hole = (f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="#0E3466"/>'
            f'<circle cx="{c[0]}" cy="{c[1] + 8}" r="{r - 4}" fill="#1F64B0"/>'
            f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="none" stroke="{INK}" stroke-width="8"/>')
    g = lambda a0, a1, rr=66: "M%.1f,%.1f A%d,%d 0 0,1 %.1f,%.1f" % (*polar(*c, rr, a0), rr, rr, *polar(*c, rr, a1))
    # bands on the axes so the gloss lands on red (it vanishes on white)
    return build([part(circ(*c, R), ("#FF9584", "#C81A26", "#82101A"), dy=16)] + bands, gloss=[g(206, 244)],
                 extra=seams + hole + stud(100, 37, 14, "#FFFFFF", "#8E9AB2"))


def lock():
    """locked: a gold padlock, front on, steel shackle with a dark inner edge"""
    shackle = "M46,98 L46,68 A54,54 0 0,1 154,68 L154,98 L120,98 L120,68 A20,20 0 0,0 80,68 L80,98 Z"
    body = "M48,88 L152,88 Q172,88 172,108 L172,166 Q172,186 152,186 L48,186 Q28,186 28,166 L28,108 Q28,88 48,88 Z"
    inner = '<path d="M75,96 L75,68 A25,25 0 0,1 125,68 L125,96" fill="none" stroke="#4A5670" stroke-width="10"/>'
    keyhole = (f'<circle cx="100" cy="124" r="21" fill="{INK}"/>'
               f'<path d="M88,130 L112,130 L118,166 Q119,172 112,172 L88,172 Q81,172 82,166 Z" fill="{INK}"/>')
    s = build([part(shackle, ("#B4C0D4", "#6E7D98", "#3E4A62")), part(body, GOLD, z=1, sep=True, dy=16, lip="#A85A00")],
              gloss=["M44,118 L44,104 Q44,100 50,100 L70,100", "M60,62 A40,40 0 0,1 84,30"], extra=keyhole)
    i = s.index(f'<path d="{body}" fill="{INK}"')  # the body's own outline: the shackle's inner edge goes under the body
    return s[:i] + inner + s[i:]


def map_():
    """the full map: a chart folded in two, a fat red route to a big red X"""
    top, bot = [(14, 44), (100, 26), (186, 44)], [(14, 172), (100, 154), (186, 172)]
    light, dark = ("#FFF4B0", "#FFC93A", "#C27400"), ("#FFD447", "#E58A00", "#A85A00")
    panels = [part(f"M{top[i][0]},{top[i][1]} L{top[i + 1][0]},{top[i + 1][1]} L{bot[i + 1][0]},{bot[i + 1][1]} "
                   f"L{bot[i][0]},{bot[i][1]} Z", dark if i else light) for i in range(2)]
    route = "M42,138 C62,92 96,158 114,116"
    line = (f'<path d="{route}" stroke="{INK}" stroke-width="38" stroke-linecap="round" fill="none"/>'
            f'<path d="{route}" stroke="#E2333A" stroke-width="22" stroke-linecap="round" fill="none"/>')
    x = lambda w, col: ink(124, 64, 164, 104, w, col) + ink(164, 64, 124, 104, w, col)
    return build(panels, gloss=["M28,62 L64,54"], extra=ink(100, 26, 100, 154, 8) + line + x(44, INK) + x(26, "#E2333A"))


def quests():
    """quest board / pontoons: a scroll, two bold lines and a big red Lego seal on the bottom roll"""
    body, seal = "M40,40 L160,40 L160,180 L40,180 Z", circ(100, 160, 42)
    roll = lambda y: f"M40,{y} L160,{y} Q178,{y} 178,{y + 17} Q178,{y + 34} 160,{y + 34} L40,{y + 34} Q22,{y + 34} 22,{y + 17} Q22,{y} 40,{y} Z"
    curls = ink(42, 41, 158, 41, 8, "#B86A00") + ink(42, 193, 158, 193, 8, "#B86A00")  # the under-curl shade of each roll
    rollc = ("#FFF08A", "#F39A00", "#A85A00")
    bars = ink(64, 74, 136, 74, 18, "#F07A10") + ink(64, 100, 112, 100, 18, "#F07A10")
    s = build([part(body, ("#FFFDF0", "#FFE89A", "#C27400")), part(roll(14), rollc, z=1, sep=True),
               part(roll(166), rollc, z=1, sep=True, dy=16), part(seal, RED, z=2, sep=True)],
              gloss=["M36,24 L74,24"], extra=bars + stud(100, 160, 25, "#FF9A8E", "#A3161E"))
    i = s.index(f'<path d="{seal}" fill="{INK}"')  # the seal's own outline: the roll shades go under the seal
    return s[:i] + curls + s[i:]


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
    """golden hour: a gold-to-orange sun, eight pointed rays (long and short) clear of the disc"""
    c = (100, 98)
    rays = ""
    for i in range(8):
        a, tip, half = i * 45 - 90, (102 if i % 2 == 0 else 90), (13 if i % 2 == 0 else 11)
        (x0, y0), (x1, y1), (x2, y2) = polar(*c, 66, a - half), polar(*c, tip, a), polar(*c, 66, a + half)
        rays += f"M{x0:.1f},{y0:.1f} L{x1:.1f},{y1:.1f} L{x2:.1f},{y2:.1f} Z "
    g = "M%.1f,%.1f A32,32 0 0,1 %.1f,%.1f" % (*polar(*c, 32, 192), *polar(*c, 32, 252))
    return build([part(rays, ORANGE), part(circ(*c, 44), ("#FFE45C", "#FF9A00", "#C25E00"), z=1, sep=True)], gloss=[g])


def vip():
    """VIP pass: a gold crown, stud-ball tips, a deep band with one big red gem"""
    crown = "M30,150 L22,62 L66,102 L100,48 L134,102 L178,62 L170,150 Z"
    tips = [part(circ(x, y, 15), GOLD) for x, y in ((22, 56), (100, 40), (178, 56))]
    band = "M34,126 L166,126 Q180,126 180,140 L180,162 Q180,176 166,176 L34,176 Q20,176 20,162 L20,140 Q20,126 34,126 Z"
    gem = (f'<path d="M100,134 L122,151 L100,168 L78,151 Z" fill="#E2333A" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
           '<path d="M100,141 L112,151 L100,151 Z" fill="#FFB3A8"/>')
    return build([part(crown, GOLD), *tips, part(band, ("#FFD84A", "#F09A00", "#9A5800"), z=1, sep=True, dy=16)],
                 gloss=["M44,98 L40,130"], extra=gem)


ICONS = {"lifebuoy": lifebuoy, "lock": lock, "map": map_, "quests": quests, "settings": settings, "sun": sun, "vip": vip}


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
