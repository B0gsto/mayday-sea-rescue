#!/usr/bin/env python3
"""Kit menu icons, part 4 (shop, wave; redraw round 3), in the same house style and spec as
kit_icons2.py (helpers copied, not imported): one die-cut sticker per icon (white rim 30 and hard outline 12 round the
UNION of its parts, a lip 12 under each part, bold top-down gradients, a soft gloss), drawn in a 200-unit box; the
square viewBox is fitted so the art fills 88% of it, centred. Writes art/source/ui/kit_<name>.svg and renders each at a
128x128 page --keep (256 px).   usage: python3 tools/ui-art/kit_icons4.py <out_dir> [--manifest file.json]"""
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
        out += [extra.get(z, "")] if isinstance(extra, dict) else []
    out += [f'<path d="{g}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round"/>'
            for g in gloss]
    return "<defs>" + "".join(defs) + "</defs>" + "".join(out) + (extra if isinstance(extra, str) else "")


def ring_sector(cx, cy, r0, r1, a0, a1):
    p = lambda r, a: f"{cx + r * math.cos(math.radians(a)):.1f},{cy + r * math.sin(math.radians(a)):.1f}"
    return f"M{p(r0, a0)} L{p(r1, a0)} A{r1},{r1} 0 0,1 {p(r1, a1)} L{p(r0, a1)} A{r0},{r0} 0 0,0 {p(r0, a0)} Z"


def polar(cx, cy, r, a):
    return cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))


# ---- the icons -------------------------------------------------------------------------------------------------------
def shop():
    """the shop: a market stall, three wide red-white awning stripes, a big gold coin-stud on the door"""
    n, top, bot = 3, (26, 174), (12, 188)
    stripes, seams = [], ""
    for i in range(n):
        tl, tr = top[0] + (top[1] - top[0]) * i / n, top[0] + (top[1] - top[0]) * (i + 1) / n
        bl, br = bot[0] + (bot[1] - bot[0]) * i / n, bot[0] + (bot[1] - bot[0]) * (i + 1) / n
        rx = (br - bl) / 2
        stripes.append(part(f"M{tl:.1f},26 L{tr:.1f},26 L{br:.1f},84 A{rx:.1f},22 0 0,1 {bl:.1f},84 Z",
                            RED if i % 2 == 0 else WHITE, z=1))
        if i:
            seams += ink(tl, 26, bl, 84, 7)
    body = "M34,80 L166,80 L166,172 Q166,184 154,184 L46,184 Q34,184 34,172 Z"
    return build([part(body, BLUE), *stripes, part(circ(100, 142, 36), GOLD, z=2, sep=True)],
                 gloss=["M30,38 L24,72", "M134,38 L142,72", "M46,116 L46,152"],
                 extra=seams + stud(100, 142, 21, "#FFF3A8", "#C27400"))


def wave():
    """the wake trail prize: a teal curling crest with a white foam tip (dark inner shadow) over a blue swell"""
    crest = ("M14,176 L14,140 C14,84 58,38 112,34 C154,32 188,58 188,92 C188,118 168,130 150,126 "
             "C134,122 128,106 138,96 C124,84 102,90 96,110 C90,130 106,150 132,152 L188,152 L188,176 Z")
    foam = circ(156, 116, 19) + " " + circ(178, 100, 15) + " " + circ(140, 104, 13)
    swell = "M12,156 Q34,138 56,156 T100,156 T144,156 T188,156 L188,180 Q188,186 182,186 L18,186 Q12,186 12,180 Z"
    shadow = (f'<clipPath id="cc"><path d="{crest}"/></clipPath><g clip-path="url(#cc)">'  # the curl's shade under the foam
              f'<path d="{foam}" fill="#0A5750" stroke="#0A5750" stroke-width="40" transform="translate(-6,9)"/></g>')
    return build([part(crest, TEAL), part(foam, WHITE, z=1, sep=True, dy=8, lip="#9FB0CC"),
                  part(swell, BLUE, z=2, sep=True, dy=16, lip="#123F96")],
                 gloss=["M34,120 C40,86 64,60 96,52", "M126,52 C148,50 164,58 172,72", "M148,108 A10,10 0 0,1 158,102"],
                 extra={0: shadow})


def band(x0, x1, y, h, n, yb):
    """a wave band: n rounded crests (gentle rise, steep front) along the top at baseline y, flat bottom at yb"""
    w, d = (x1 - x0) / n, f"M{x0},{yb} L{x0},{y}"
    for i in range(n):
        xa = x0 + i * w
        d += (f" C{xa + 0.4 * w:.1f},{y} {xa + 0.5 * w:.1f},{y - h} {xa + 0.74 * w:.1f},{y - h}"
              f" C{xa + 0.95 * w:.1f},{y - h} {xa + 0.96 * w:.1f},{y - 0.3 * h:.1f} {xa + w:.1f},{y}")
    return d + f" L{x1},{yb} Z"


# kit_waves.svg is kept as hand SVG: its round-1 art scored best (8.6 vs 7.6 for the round-3 redraw)
ICONS = {"shop": shop, "wave": wave}


def write(name, body, x0, y0, box=BOX):
    (SRC / f"kit_{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x0:.1f} {y0:.1f} {box:.1f} {box:.1f}" width="128" height="128">'
        f"<!-- Kit.{name}: {ICONS[name].__doc__} (tools/ui-art/kit_icons4.py) -->{body}</svg>\n")


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
