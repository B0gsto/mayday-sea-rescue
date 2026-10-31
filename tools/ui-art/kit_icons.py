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
R6 = {"album": True, "boat_to_me": False, "build": True}  # r6 redraws; False regenerates the r5 best pixel-identical
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
    # r4: a darker back card, a deeper head lip, a cabin with a real lip
    "deep4": ("#4FA8F5", "#1656C8", "#0E3A8A"), "red4": ("#FF9A86", "#F2343C", "#98101A"),
    "cabin": ("#FFFFFF", "#DDE9FA", "#7F9CC8"),
    # r5: a light-blue cabin that does not merge with the white rim
    "cabin5": ("#E2F5FF", "#9AD6F5", "#3F7FB8"),
    # r6: a dark book spine
    "spine6": ("#3A7FE0", "#123C9A", "#0B2766"),
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
        self.parts, self.defs, self.backs = [], [], []  # backs: white-only fillers inside the shared rim

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
        out = "".join(P(d, "#fff", (0, 0), "#fff", 30) for d in self.backs)
        out += "".join(P(d, "#fff", dy, "#fff", 30) for d, _, lip, _, _, _ in self.parts for dy in dict.fromkeys([(0, 0), lip]))
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
    if not R6["album"]:
        return album_r5()
    i = Icon()
    sticker = rot([(80, -6), (136, -6), (136, 50), (80, 50)], -14, 108, 22)
    i.part(poly(sticker), "red2", lip=8, gloss=poly(rot([(92, 6), (110, 6)], -14, 108, 22))[:-2])
    i.part(rrect(16, 46, 228, 178, 12), "paper", lip=0)  # r6: two thick white page edges, 30 units each (18 white past the ink)
    i.part(rrect(10, 39, 198, 185, 12), "paper", lip=0)
    spine = "M18,32 L30,32 L30,192 L18,192 Q0,192 0,174 L0,50 Q0,32 18,32 Z"
    i.part(rrect(0, 32, 168, 192, 18), "sky", lip=14, gloss="M48,52 L68,52",  # star clears spine and cover ink by ~3-4 units
           extra=i.inner(spine, "spine6", ink=10, lip=0) + i.inner(poly(star(99, 114, 56, 27)), "gold", ink=14, lip=8))
    return i, "the album / sticker book (r6): a bright blue book, a dark navy spine strip on the left, two thick white page edges on the right, a big gold star, a red sticker card peeking out the top"


def album_r5():
    i = Icon()
    sticker = rot([(80, -6), (136, -6), (136, 50), (80, 50)], -14, 108, 22)  # a sticker card peeking out the top, tilted
    i.part(poly(sticker), "red2", lip=8, gloss=poly(rot([(92, 6), (110, 6)], -14, 108, 22))[:-2])
    i.part(rrect(14, 44, 200, 180, 12), "paper", lip=0)  # two white page edges stepping out on the right
    i.part(rrect(10, 38, 178, 186, 12), "paper", lip=0)
    spine = "M18,32 L28,32 L28,192 L18,192 Q0,192 0,174 L0,50 Q0,32 18,32 Z"
    i.part(rrect(0, 32, 156, 192, 18), "sky", lip=14, gloss="M44,52 L66,52",
           extra=i.inner(spine, "deep4", ink=8, lip=0) + i.inner(poly(star(91, 116, 50, 23)), "gold", ink=14, lip=8))
    return i, "the album / sticker book: a bright blue book, dark blue spine strip on the left, two white page edges on the right, a big gold star, a red sticker card peeking out the top"


def boat_to_me():
    if not R6["boat_to_me"]:
        return boat_to_me_r5()
    i = Icon()
    i.part(rrect(144, 66, 198, 124, 12), "cabin5", lip=10,  # r6: one big cabin block, one big dark window
           extra=f'<path d="{rrect(156, 80, 186, 104, 7)}" fill="{C["navy"][1]}" stroke="{INK}" stroke-width="8"/>')
    hull = "M0,120 L200,120 L190,186 Q188,200 174,200 L72,200 Q30,200 0,120 Z"  # r6: taller plain hull, pointed bow left
    i.part(hull, "hull", lip=16, gloss="M34,138 L92,138")
    arrow = "M62,46 L108,0 L108,24 L130,24 Q140,24 140,34 L140,58 Q140,68 130,68 L108,68 L108,92 Z"
    i.part(arrow, "sky", lip=8, gloss="M88,42 L102,28")
    # r6: a ~30% pin drawn over the arrow tip, so the arrow points into it (teardrop, tip 1.8 r below the centre)
    cx, cy, r = 34, 44, 34
    pin = [(cx + r * math.cos(t), cy + r * math.sin(t)) for t in [math.radians(146.3 + k * 247.4 / 30) for k in range(31)]] + [(cx, cy + 1.8 * r)]
    i.part(poly(pin), "red2", lip=8, gloss="M13,40 Q15,22 30,17",
           extra=f'<circle cx="{cx}" cy="{cy}" r="13" fill="#fff" stroke="{INK}" stroke-width="7"/>')
    i.backs.append(poly([(10, 72), (62, 46), (144, 70), (150, 120), (8, 120)]))
    return i, "boat to me (r6): a bold blue arrow pointing into a big red player pin, a big plain orange boat behind it (pointed bow, one light-blue cabin with one dark window)"


def boat_to_me_r5():
    i = Icon()
    i.part(rrect(152, 86, 194, 136, 10), "cabin5", lip=10,  # light-blue cabin block on the deck, a dark window
           extra=f'<path d="{rrect(162, 98, 184, 118, 6)}" fill="{C["navy"][1]}" stroke="{INK}" stroke-width="7"/>')
    hull = "M2,132 L198,132 L188,184 Q186,196 172,196 L74,196 Q32,196 2,132 Z"  # pointed bow left
    i.part(hull, "hull", lip=16, gloss="M36,148 L92,148",
           extra=line("M64,170 L180,170", w=10, col="#fff"))  # waterline stripe
    arrow = "M72,46 L114,2 L114,24 L126,24 Q136,24 136,34 L136,58 Q136,68 126,68 L114,68 L114,90 Z"
    i.part(arrow, "sky", lip=8, gloss="M92,44 L106,30")
    # the player pin the arrow points at: a teardrop (tangent points at 33.7/146.3 deg for a tip 1.8 r below), a white dot
    pin = [(24 + 24 * math.cos(t), 40 + 24 * math.sin(t)) for t in [math.radians(146.3 + k * 247.4 / 30) for k in range(31)]] + [(24, 83)]
    i.part(poly(pin), "red2", lip=8, gloss="M9,36 Q11,23 22,19",
           extra='<circle cx="24" cy="40" r="10" fill="#fff" stroke="#14121C" stroke-width="6"/>')
    i.backs.append(poly([(6, 60), (72, 46), (146, 70), (150, 132), (6, 132)]))  # white between pin, arrow and hull: one sticker
    return i, "boat to me: a bold blue arrow pointing left at a red player pin, a bright orange boat behind it (pointed bow, light-blue cabin with a dark window, waterline stripe)"


def boost():
    i = Icon()
    bolt = "M84,4 L170,4 L138,72 L192,72 L58,198 L82,124 L18,124 Z"
    i.part(bolt, "bolt2", lip=(6, 14), gloss="M94,22 L66,88")
    return i, "boost: a fat lightning bolt with a wide middle step, bright yellow to orange, dark-orange lip down-right"


def build():
    if not R6["build"]:
        return build_r5()
    i = Icon()
    R = lambda d: rotd(d, 40, 100, 100)
    i.part(R(rrect(70, 90, 130, 189, 20)), "bolt")
    b = Icon()  # r6: the brick is its own sticker in front (own white rim), so it never merges into the handle
    b.defs = i.defs  # one gradient id sequence
    b.part(rrect(126, 148, 230, 212, 10), "sky", lip=10, extra="".join(stud(x, 180, 20, "#D6F4FF", "#1A66D1") for x in (152, 204)))
    i.part(R(rrect(6, 14, 194, 102, 16)), "red3", lip=16, gloss=R("M26,34 L26,74"),
           extra="".join(stud(*(round(v, 1) for v in rot([(x, 58)], 40, 100, 100)[0]), 22, "#FFB3A6", "#B3121C") for x in (72, 138))
           + b.layers())
    return i, "build (r6): one bold Lego-brick hammer, a big red 2-stud brick head on a short fat yellow handle, a big blue 2-stud brick sticker in front at the bottom right"


def build_r5():
    i = Icon()
    R = lambda d: rotd(d, 40, 100, 100)
    i.part(BRICK, "sky", lip=10, extra="".join(stud(x, 182, 13, "#D6F4FF", "#1A66D1") for x in BRICK_STUDS))  # a small 2-stud brick behind the head: build pieces
    i.part(R(rrect(70, 90, 130, 189, 20)), "bolt")  # r5: handle 15% shorter and thicker so the head dominates
    i.part(R(rrect(6, 14, 194, 102, 16)), "red3", lip=16, gloss=R("M26,34 L26,74"),
           extra="".join(stud(*(round(v, 1) for v in rot([(x, 58)], 40, 100, 100)[0]), 22, "#FFB3A6", "#B3121C") for x in (72, 138)))
    return i, "build: one bold Lego-brick hammer, a big red 2-stud brick head on a short fat yellow handle, a small blue 2-stud brick behind the head"


BRICK_STUDS = (151, 193)
BRICK = rrect(130, 152, 214, 202, 8)


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
