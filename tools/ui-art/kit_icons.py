#!/usr/bin/env python3
"""UI Kit menu/button icons, first half (perfect-ui r2; companion/crew/daily/finish_now/gift/hourglass live in kit_icons3.py): house sticker style (stickers.py sticker(): white rim 30,
ink 12, lip 12 down, top-to-bottom gradient, gloss 10 @ 0.55), multi-part icons die-cut as one sticker (every part's
rim first, then each part's ink + lip + fill back to front). Writes art/source/ui/kit_<name>.svg with a square viewBox
fitted so the art fills 88% of it, then renders <out>/Kit.<name>.png (128x128 page, --keep = 256 px).
usage: python3 tools/ui-art/kit_icons.py <out_dir>"""
import math
import pathlib
import re
import subprocess
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "art/source/ui"
RENDER = ROOT / "tools/ui-art/render.py"
INK = "#14121C"
FILL = 0.88
C = {  # top, bottom, lip
    "red": ("#FF8A7A", "#E2333A", "#A3161E"), "blue": ("#8EE0FF", "#2C8EF0", "#1A55A8"),
    "green": ("#A4F57A", "#33BE4D", "#1F8A33"), "gold": ("#FFE45C", "#FFAE00", "#C27400"),
    "teal": ("#8FF5E2", "#1DB59B", "#13776E"), "orange": ("#FFC266", "#FF7419", "#B84A08"),
    "boost": ("#FFE45C", "#FF8A00", "#B84A08"), "cream": ("#FFFFFF", "#E6DCC2", "#B3A27E"),
    "navy": ("#5FA8F0", "#1A55A8", "#123C7A"), "glass": ("#F2FCFF", "#A6E2F7", "#5FA9C9"),
    "slate": ("#6E7890", "#3A4150", "#232836"), "skin": ("#FFE45C", "#FFC21A", "#C27400"),
    # r2 Lego-bright set: brighter tops, saturated (never brown/maroon) lips
    "sky": ("#A6EEFF", "#2E9BFF", "#1A66D1"), "red2": ("#FF9A86", "#F2343C", "#C21F2A"),
    "bolt": ("#FFF27A", "#FFA412", "#E86A00"), "orange2": ("#FFD27A", "#FF7A1A", "#DB560A"),
    "green2": ("#CBFF8F", "#3CCB52", "#23992F"), "paper": ("#FFFFFF", "#E8F1FF", "#9DB8E0"),
    # r3: deeper back card, darker hull/head/bolt lips (still saturated, never brown/maroon)
    "deep": ("#6CC8FF", "#1E74E6", "#1450B8"), "hull": ("#FFD27A", "#FF7A1A", "#B8460A"),
    "bolt2": ("#FFF27A", "#FFA412", "#C85500"), "red3": ("#FF9A86", "#F2343C", "#B3121C"),
}


# --- geometry helpers (paths use only M/L/Q/C/Z so tf() can scale them) ---
def poly(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def rrect(x0, y0, x1, y1, r):
    return (f"M{x0+r},{y0} L{x1-r},{y0} Q{x1},{y0} {x1},{y0+r} L{x1},{y1-r} Q{x1},{y1} {x1-r},{y1} "
            f"L{x0+r},{y1} Q{x0},{y1} {x0},{y1-r} L{x0},{y0+r} Q{x0},{y0} {x0+r},{y0} Z")


def rot(pts, deg, cx, cy):
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a))
            for x, y in pts]


def ccw(pts):
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
    return pts if area > 0 else pts[::-1]  # one winding for every subpath: overlaps stay filled (nonzero)


def ellipse(cx, cy, rx, ry, deg=0, n=48):
    return rot([(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)], deg, cx, cy)


def bar(p0, p1, w, ext=0):
    (x0, y0), (x1, y1) = p0, p1
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    nx, ny, h = -uy, ux, w / 2
    a, b = (x0 - ux * ext, y0 - uy * ext), (x1 + ux * ext, y1 + uy * ext)
    return ccw([(a[0] + nx * h, a[1] + ny * h), (b[0] + nx * h, b[1] + ny * h), (b[0] - nx * h, b[1] - ny * h), (a[0] - nx * h, a[1] - ny * h)])


def star(cx, cy, ro, ri, n=5):
    return [(cx + (ro if i % 2 == 0 else ri) * math.sin(math.pi * i / n), cy - (ro if i % 2 == 0 else ri) * math.cos(math.pi * i / n))
            for i in range(2 * n)]


def tf(d, s=1, ox=0, oy=0):
    assert not re.search(r"[AaHhVv]", d), "tf() only maps absolute M/L/Q/C paths"
    out, i = [], 0
    for t in re.findall(r"[MLQCZ]|-?\d+(?:\.\d+)?", d):
        if t.isalpha():
            out.append(t)
        else:
            out.append(f"{float(t) * s + (ox if i % 2 == 0 else oy):.1f}")
            i += 1
    return " ".join(out).replace("M ", "M").replace("L ", "L").replace("Q ", "Q").replace("C ", "C")


# --- sticker builder ---
class Icon:
    def __init__(self):
        self.parts, self.defs = [], []

    def grad(self, col):
        gid = f"g{len(self.defs)}"
        top, bottom = C[col][:2]
        self.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
                         f'<stop offset="1" stop-color="{bottom}"/></linearGradient>')
        return gid

    def part(self, d, col, lip=12, gloss=None, extra="", ink=12):
        self.parts.append((d, col, lip if isinstance(lip, tuple) else (0, lip), gloss, extra, ink))

    def inner(self, d, col, ink=8, lip=6):
        """a small shape on top of a part (a star, a coin): its own ink line, lip and gradient, no rim"""
        g = self.grad(col)
        sh = [lip] if lip else []
        return ("".join(f'<path d="{d}" transform="translate(0,{dy})" fill="{INK}" stroke="{INK}" stroke-width="{ink}" stroke-linejoin="round"/>'
                        for dy in sh + [0])
                + (f'<path d="{d}" transform="translate(0,{lip})" fill="{C[col][2]}"/>' if lip else "")
                + f'<path d="{d}" fill="url(#{g})"/>')

    def layers(self):
        P = lambda d, fill, o, stroke=None, w=0: (f'<path d="{d}" transform="translate({o[0]},{o[1]})" fill="{fill}"'
                                                   + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
        out = "".join(P(d, "#fff", dy, "#fff", 30) for d, _, lip, _, _, _ in self.parts for dy in dict.fromkeys([(0, 0), lip]))
        for d, col, lip, gloss, extra, ink in self.parts:
            g = self.grad(col)
            out += "".join(P(d, INK, dy, INK, ink) for dy in sorted({(0, 0), lip}, reverse=True))
            out += (P(d, C[col][2], lip) if lip != (0, 0) else "") + P(d, f"url(#{g})", (0, 0))
            if gloss:
                out += f'<path d="{gloss}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>'
            out += extra
        return out

    def svg(self, box, note):
        x, y, s = box
        body = self.layers()  # first: layers() adds the part gradients to defs
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x:.1f} {y:.1f} {s:.1f} {s:.1f}" width="128" height="128">'
                f"<!-- {note} --><defs>{''.join(self.defs)}</defs>{body}</svg>\n")


def line(d, w=7, col=INK, cap="round"):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round"/>'


def stud(cx, cy, r, light, dark):
    """a Lego stud top: lighter disc in a dark ring, a gloss arc"""
    a0, a1 = math.radians(200), math.radians(260)
    rr = r * 0.62
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{light}" stroke="{dark}" stroke-width="7"/>'
            f'<path d="M{cx + rr * math.cos(a0):.1f},{cy + rr * math.sin(a0):.1f} Q{cx - rr * 0.95:.1f},{cy - rr * 0.95:.1f} '
            f'{cx + rr * math.cos(a1):.1f},{cy + rr * math.sin(a1):.1f}" fill="none" stroke="#fff" stroke-opacity="0.8" stroke-width="7" stroke-linecap="round"/>')


# --- the icons ---
def rotd(d, deg, cx=100, cy=100):
    """rotate an absolute M/L/Q/C path about (cx, cy)"""
    nums = [float(t) for t in re.findall(r"-?\d+(?:\.\d+)?", d)]
    pts = rot(list(zip(nums[::2], nums[1::2])), deg, cx, cy)
    it = iter(f"{x:.1f},{y:.1f}" for x, y in pts)
    return re.sub(r"-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?", lambda m: next(it), d)


def album():
    i = Icon()
    back = rrect(58, 4, 192, 150, 16) + " " + " ".join(rrect(x, -18, x + 36, 12, 7) for x in (78, 140))  # 2 Lego studs on top
    i.part(back, "deep", lip=14)
    i.part(rrect(8, 34, 154, 182, 18), "sky", lip=14, gloss="M32,56 L62,56",
           extra=i.inner(poly(star(81, 112, 56, 26)), "gold", ink=12, lip=8))
    return i, "the album / sticker book: a bright blue cover with one huge gold star over a deeper blue back card with 2 Lego studs"


def boat_to_me():
    i = Icon()
    i.part(rrect(130, 76, 180, 126, 10), "paper", lip=0)  # cabin block on the deck
    hull = "M6,112 L190,112 L182,170 Q180,184 166,184 L74,184 Q34,184 6,112 Z"  # pointed bow left
    i.part(hull, "hull", lip=16, gloss="M40,128 L96,128",
           extra=line("M58,154 L176,154", w=10, col="#fff"))  # waterline stripe
    arrow = "M8,48 L60,4 L60,26 L106,26 Q118,26 118,38 L118,58 Q118,70 106,70 L60,70 L60,92 Z"
    i.part(arrow, "sky", lip=10, gloss="M30,46 L50,30")
    return i, "boat to me: a short fat blue arrow pointing left over a bright orange boat (pointed bow, white cabin, waterline stripe)"


def boost():
    i = Icon()
    bolt = "M84,4 L170,4 L138,72 L192,72 L58,198 L82,124 L18,124 Z"
    i.part(bolt, "bolt2", lip=(6, 14), gloss="M94,22 L66,88")
    return i, "boost: a fat lightning bolt with a wide middle step, bright yellow to orange, dark-orange lip down-right"


def build():
    i = Icon()
    R = lambda d: rotd(d, 40, 100, 100)
    i.part(R(rrect(74, 90, 126, 204, 18)), "bolt")
    i.part(R(rrect(6, 14, 194, 102, 16)), "red3", lip=16, gloss=R("M26,34 L26,74"),
           extra="".join(stud(*(round(v, 1) for v in rot([(x, 58)], 40, 100, 100)[0]), 22, "#FFB3A6", "#B3121C") for x in (72, 138)))
    return i, "build: one bold Lego-brick hammer, a big red 2-stud brick head on a fat yellow handle"


def cash():
    i = Icon()
    back = poly(rot([(22, 36), (178, 36), (178, 118), (22, 118)], -12, 100, 78))
    i.part(back, "green2", ink=14)
    i.part(rrect(10, 72, 190, 168, 16), "green2", lip=14, ink=14, gloss="M30,92 L64,92",
           extra=stud(100, 120, 30, "#D8FFB0", "#23992F"))
    return i, "cash: two bold green bills (one tilted behind), a Lego stud in place of the emblem"


def close():
    i = Icon()
    a, L = 30, 86
    plus = [(-a, -L), (a, -L), (a, -a), (L, -a), (L, a), (a, a), (a, L), (-a, L), (-a, a), (-L, a), (-L, -a), (-a, -a)]
    x = rot([(100 + px, 94 + py) for px, py in plus], 45, 100, 94)
    i.part(poly(x), "red2", lip=14, gloss="M48,52 L76,80")
    return i, "close: the simulator-kit red X, bright gradient, lip, gloss, rim"


ICONS = [album, boat_to_me, boost, build, cash, close]


def render(svg_path, png):
    subprocess.run([sys.executable, str(RENDER), str(svg_path), str(png), "--size", "128", "128", "--keep"],
                   check=True, capture_output=True)


if __name__ == "__main__":
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for fn in ICONS:
        name = fn.__name__
        icon, note = fn()
        path, png = SRC / f"kit_{name}.svg", out / f"Kit.{name}.png"
        probe = (-60, -60, 320)  # pass 1: wide box, measure the drawn art
        path.write_text(icon.svg(probe, note))
        render(path, png)
        x0, y0, x1, y1 = Image.open(png).getbbox()
        k = probe[2] / 256
        bx0, by0, bx1, by1 = probe[0] + x0 * k, probe[1] + y0 * k, probe[0] + x1 * k, probe[1] + y1 * k
        assert x0 > 0 and y0 > 0 and x1 < 256 and y1 < 256, f"{name} clipped in the probe box"
        side = max(bx1 - bx0, by1 - by0) / FILL
        cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
        icon2, _ = fn()  # fresh gradient ids
        path.write_text(icon2.svg((cx - side / 2, cy - side / 2, side), note))
        render(path, png)
        im = Image.open(png)
        bb = im.getbbox()
        assert im.size == (256, 256), im.size
        print(name, im.size, "bbox", bb, "fill %.2f" % (max(bb[2] - bb[0], bb[3] - bb[1]) / 256))
