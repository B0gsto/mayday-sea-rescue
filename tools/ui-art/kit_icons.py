#!/usr/bin/env python3
"""UI Kit menu/button icons, first half (perfect-ui r1): house sticker style (stickers.py sticker(): white rim 30,
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

    def part(self, d, col, lip=12, gloss=None, extra=""):
        self.parts.append((d, col, lip, gloss, extra))

    def inner(self, d, col, ink=8, lip=6):
        """a small shape on top of a part (a star, a coin): its own ink line, lip and gradient, no rim"""
        g = self.grad(col)
        sh = [lip] if lip else []
        return ("".join(f'<path d="{d}" transform="translate(0,{dy})" fill="{INK}" stroke="{INK}" stroke-width="{ink}" stroke-linejoin="round"/>'
                        for dy in sh + [0])
                + (f'<path d="{d}" transform="translate(0,{lip})" fill="{C[col][2]}"/>' if lip else "")
                + f'<path d="{d}" fill="url(#{g})"/>')

    def layers(self):
        P = lambda d, fill, dy, stroke=None, w=0: (f'<path d="{d}" transform="translate(0,{dy})" fill="{fill}"'
                                                   + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
        out = "".join(P(d, "#fff", dy, "#fff", 30) for d, _, lip, _, _ in self.parts for dy in {0, lip})
        for d, col, lip, gloss, extra in self.parts:
            g = self.grad(col)
            out += "".join(P(d, INK, dy, INK, 12) for dy in sorted({0, lip}, reverse=True))
            out += (P(d, C[col][2], lip) if lip else "") + P(d, f"url(#{g})", 0)
            if gloss:
                out += f'<path d="{gloss}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>'
            out += extra
        return out

    def svg(self, box, note):
        x, y, s = box
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x:.1f} {y:.1f} {s:.1f} {s:.1f}" width="128" height="128">'
                f"<!-- {note} --><defs>{''.join(self.defs)}</defs>{self.layers()}</svg>\n")


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
def album():
    i = Icon()
    i.part(rrect(40, 22, 186, 162, 14), "cream", extra=line("M172,40 L172,148", 7, "#C9B98F"))
    star_d = poly(star(104, 92, 50, 22))
    i.part(rrect(16, 14, 162, 160, 14), "blue", gloss="M68,32 L120,32",
           extra=f'<path d="{rrect(16, 14, 50, 160, 14)}" fill="{C["navy"][2]}"/>' + line("M50,20 L50,154", 8)
           + i.inner(star_d, "gold", ink=10, lip=7) + line("M80,82 L94,64", 8, "#fff"))
    return i, "the album / sticker book: a blue Lego-bright cover, navy spine, cream page block, big gold star"


def boat_to_me():
    i = Icon()
    hull = "M12,128 L58,112 L178,112 Q188,112 188,122 L188,148 Q188,162 174,162 L70,162 Q32,162 12,128 Z"
    seat = "M70,112 L84,86 Q88,80 96,80 L154,80 Q164,80 164,90 L164,112 Z"
    i.part(seat, "slate", lip=0, gloss="M100,92 L146,92")
    i.part(hull, "orange", gloss="M44,124 L74,118", extra=line("M66,134 L176,134", 9, "#fff"))
    arrow = "M14,40 L62,4 L62,24 L170,24 Q182,24 182,36 L182,44 Q182,56 170,56 L62,56 L62,76 Z"
    i.part(arrow, "blue", gloss="M40,40 L56,28")
    return i, "boat to me: an orange jet ski (dark seat, white stripe) with a fat blue arrow over it, heading in"


def boost():
    i = Icon()
    bolt = "M106,8 L154,8 L124,72 L172,72 L72,192 L92,118 L36,118 Z"
    i.part(bolt, "boost", gloss="M100,28 L70,84")
    return i, "boost: a fat lightning bolt, saturated yellow to orange"


def build():
    i = Icon()
    # wrench: handle bottom-right -> open jaw top-left
    p0, p1, r, hw, depth = (164, 176), (66, 68), 38, 14, 30
    L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    u = ((p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L)
    n = (-u[1], u[0])
    au, ah = math.atan2(u[1], u[0]), math.asin(hw / r)
    arc = [(p1[0] + r * math.cos(au + ah + t * (2 * math.pi - 2 * ah) / 40), p1[1] + r * math.sin(au + ah + t * (2 * math.pi - 2 * ah) / 40))
           for t in range(41)]
    d0 = r - depth
    slot = [(p1[0] + u[0] * d0 - n[0] * hw, p1[1] + u[1] * d0 - n[1] * hw), (p1[0] + u[0] * d0 + n[0] * hw, p1[1] + u[1] * d0 + n[1] * hw)]
    head = ccw(arc + slot)
    i.part(poly(bar(p0, p1, 30)) + " " + poly(head), "blue")
    # hammer: yellow handle bottom-left -> red head top-right
    q0, q1 = (40, 174), (130, 66)
    i.part(poly(bar(q0, q1, 30)), "gold", gloss="M66,136 L88,110")
    L = math.hypot(q1[0] - q0[0], q1[1] - q0[1])
    v = ((q1[0] - q0[0]) / L, (q1[1] - q0[1]) / L)
    m = (-v[1], v[0])
    c = (q1[0] + v[0] * 4, q1[1] + v[1] * 4)
    hd = poly(bar((c[0] - m[0] * 56, c[1] - m[1] * 56), (c[0] + m[0] * 50, c[1] + m[1] * 50), 50))
    g0 = (c[0] + v[0] * 12 + m[0] * 44, c[1] + v[1] * 12 + m[1] * 44)
    g1 = (c[0] + v[0] * 12 + m[0] * 10, c[1] + v[1] * 12 + m[1] * 10)
    i.part(hd, "red", gloss=f"M{g0[0]:.1f},{g0[1]:.1f} L{g1[0]:.1f},{g1[1]:.1f}")
    return i, "build: a red-headed hammer with a Lego-yellow handle crossed over a blue open wrench"


def cash():
    i = Icon()
    back = poly(rot([(22, 40), (178, 40), (178, 124), (22, 124)], -12, 100, 82))
    i.part(back, "green", extra=line(poly(rot([(40, 56), (160, 56), (160, 108), (40, 108)], -12, 100, 82)), 7, "#C9FFA8"))
    i.part(rrect(12, 72, 188, 160, 14), "green", lip=20, gloss="M28,90 L60,90",
           extra=line("M24,170 L176,170", 7) + line(rrect(30, 88, 170, 144, 8), 7, "#C9FFA8") + stud(100, 116, 24, "#C9FFA8", "#1F8A33"))
    return i, "cash: two bold green bills (one tilted behind), a stack lip with a seam, a Lego stud in place of the emblem"


def close():
    i = Icon()
    a, L = 25, 82
    plus = [(-a, -L), (a, -L), (a, -a), (L, -a), (L, a), (a, a), (a, L), (-a, L), (-a, a), (-L, a), (-L, -a), (-a, -a)]
    x = rot([(100 + px, 94 + py) for px, py in plus], 45, 100, 94)
    i.part(poly(x), "red", gloss="M52,50 L80,78")
    return i, "close: the simulator-kit red X, gradient, lip, rim"


def companion():
    i = Icon()
    for cx, cy, deg in ((32, 88, -28), (74, 44, -8), (126, 44, 8), (168, 88, 28)):
        i.part(poly(ellipse(cx, cy, 21, 27, deg)), "orange", lip=10, gloss=f"M{cx - 10},{cy - 6} Q{cx - 9},{cy - 15} {cx - 2},{cy - 19}")
    pad = "M100,104 C128,104 154,128 158,150 C162,172 144,182 126,176 C114,172 86,172 74,176 C56,182 38,172 42,150 C46,128 72,104 100,104 Z"
    i.part(pad, "orange", lip=10, gloss="M64,146 C68,132 80,122 92,120")
    return i, "companion: an orange paw print, each pad die-cut in the one sticker, a darker lip under every pad"


def crew():
    i = Icon()

    def fig(ox, oy, helmet, vest):
        i.part(tf("M8,180 L14,140 Q18,126 34,126 L86,126 Q102,126 106,140 L112,180 Z", 1, ox, oy), vest,
               gloss=tf("M26,146 L30,138", 1, ox, oy))
        face = (f'<circle cx="{ox + 48}" cy="{oy + 98}" r="7" fill="{INK}"/><circle cx="{ox + 72}" cy="{oy + 98}" r="7" fill="{INK}"/>'
                + line(tf("M46,112 Q60,122 74,112", 1, ox, oy), 7))
        i.part(tf(rrect(26, 54, 94, 132, 20), 1, ox, oy), "skin", lip=8, extra=face)
        i.part(tf(rrect(44, 12, 76, 34, 6), 1, ox, oy), helmet, lip=0)
        i.part(tf("M16,80 Q16,28 60,28 Q104,28 104,80 Q104,86 98,86 L22,86 Q16,86 16,80 Z", 1, ox, oy), helmet, lip=8,
               gloss=tf("M34,54 Q40,42 54,38", 1, ox, oy))

    fig(0, -10, "blue", "orange")
    fig(76, 8, "red", "orange")
    return i, "crew: two Lego minifig rescuers, simple dot-eye faces, helmets with a stud on top"


def daily():
    i = Icon()
    i.part("M30,96 L40,22 Q42,12 52,12 L148,12 Q158,12 160,22 L170,96 Z", "orange",
           extra=f'<path d="M50,88 L56,32 L144,32 L150,88 Z" fill="#C85A12" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>')
    heap = "M28,112 Q30,74 62,70 Q76,40 100,42 Q124,40 138,70 Q170,74 172,112 Z"
    coins = "".join(i.inner(poly(ellipse(cx, cy, 15, 15)), "gold", ink=7, lip=4) for cx, cy in ((66, 86), (102, 62), (136, 88)))
    i.part(heap, "gold", lip=0, gloss="M48,92 Q54,80 66,76", extra=coins)
    bands = "".join(i.inner(rrect(x, 102, x + 20, 178, 4), "gold", ink=7, lip=0) for x in (36, 144))
    i.part(rrect(18, 100, 182, 176, 14), "orange", gloss="M30,116 L30,150",
           extra=line("M24,124 L176,124", 8) + bands + i.inner(rrect(82, 98, 118, 140, 8), "gold", ink=8, lip=0)
           + f'<circle cx="100" cy="116" r="6" fill="{INK}"/>' + line("M100,118 L100,128", 7))
    return i, "daily reward: a bright wood treasure chest, lid flung open, a big gold coin heap, gold bands and lock"


HOURGLASS = {  # 200-unit hourglass, M/L/Q only so finish_now can scale it
    "studs": [rrect(52, 2, 80, 18, 5), rrect(120, 2, 148, 18, 5)],
    "glass": "M52,36 L148,36 Q148,80 112,100 Q148,120 148,166 L52,166 Q52,120 88,100 Q52,80 52,36 Z",
    "pillars": [rrect(28, 30, 50, 172, 6), rrect(150, 30, 172, 172, 6)],
    "top": rrect(20, 12, 180, 42, 10), "bottom": rrect(20, 160, 180, 188, 10),
    "sand_top": "M66,62 L134,62 Q130,82 106,96 L94,96 Q70,82 66,62 Z",
    "sand_bot": "M60,160 Q64,128 100,120 Q136,128 140,160 Z",
}


def hourglass_parts(i, s=1, ox=0, oy=0):
    T = lambda d: tf(d, s, ox, oy)
    H = HOURGLASS
    for d in H["studs"]:
        i.part(T(d), "orange", lip=0)
    sand = i.inner(T(H["sand_top"]), "gold", ink=7, lip=0) + i.inner(T(H["sand_bot"]), "gold", ink=7, lip=0) \
        + line(T("M100,96 L100,124"), 9, "#FFAE00")
    i.part(T(H["glass"]), "glass", lip=0, gloss=T("M64,48 Q66,72 82,86"), extra=sand)
    for d in H["pillars"]:
        i.part(T(d), "orange", lip=0)
    i.part(T(H["top"]), "orange", gloss=T("M36,24 L84,24"))
    i.part(T(H["bottom"]), "orange")


def hourglass():
    i = Icon()
    hourglass_parts(i)
    return i, "timer: a chunky hourglass, bright wood brick caps with studs, thick pillars, pale glass, gold sand"


def finish_now():
    i = Icon()
    hourglass_parts(i, 0.8, 0, 0)
    disc = poly(ellipse(140, 140, 52, 52, 0, 64))
    bolt = tf("M106,8 L154,8 L124,72 L172,72 L72,192 L92,118 L36,118 Z", 0.46, 96, 96)
    i.part(disc, "red", gloss="M104,128 Q108,108 124,98", extra=i.inner(bolt, "gold", ink=9, lip=5))
    return i, "finish now: the hourglass with a big red lightning badge (gold bolt) over its corner"


def gift():
    i = Icon()
    loops = ("M100,76 C74,16 12,12 24,56 C30,80 72,82 100,76 Z", "M100,76 C126,16 188,12 176,56 C170,80 128,82 100,76 Z")
    holes = (f'<path d="M86,68 C70,40 44,34 46,54 C48,66 70,70 86,68 Z" fill="#C27400" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>'
             f'<path d="M114,68 C130,40 156,34 154,54 C152,66 130,70 114,68 Z" fill="#C27400" stroke="{INK}" stroke-width="7" stroke-linejoin="round"/>')
    i.part(" ".join(loops), "gold", lip=0, extra=holes)
    i.part(rrect(32, 98, 168, 180, 10), "red", extra=i.inner(rrect(86, 104, 114, 180, 2), "gold", ink=7, lip=0))
    i.part(rrect(18, 70, 182, 108, 10), "red", gloss="M32,82 L74,82", extra=i.inner(rrect(84, 70, 116, 108, 2), "gold", ink=7, lip=0))
    i.part(rrect(82, 56, 118, 88, 10), "gold", lip=0)
    return i, "gift: a red present, gold ribbon, a big gold bow, gloss on the lid"


ICONS = [album, boat_to_me, boost, build, cash, close, companion, crew, daily, finish_now, gift, hourglass]


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
