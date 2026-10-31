#!/usr/bin/env python3
"""UI Kit icons, round 3 redraws (companion, crew, finish_now, gift, hourglass; daily from r4), same spec as kit_icons.py
(helpers copied, not imported): white rim 30 round the union, ink 12, lip 12 down, top-to-bottom gradient, gloss 10 @ 0.55.
A part with rim_over=True gets its own white rim drawn over the parts behind it (a badge that must separate).
Writes art/source/ui/kit_<name>.svg (square viewBox, art fills 88%) and renders <out>/Kit.<name>.png (128x128 --keep = 256 px).
usage: python3 tools/ui-art/kit_icons3.py <out_dir>"""
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
R6 = {"daily": True, "finish_now": True}  # r6 redraws; False regenerates the r5 best pixel-identical
C = {  # top, bottom, lip
    "red": ("#FF8A7A", "#E2333A", "#A3161E"), "blue": ("#8EE0FF", "#2C8EF0", "#1A55A8"),
    "gold": ("#FFE45C", "#FFAE00", "#C27400"), "orange": ("#FFC266", "#FF7419", "#B84A08"),
    "glass": ("#F2FCFF", "#B8EAFA", "#5FA9C9"), "skin": ("#FFF39A", "#FFD21F", "#C79400"),
    "paw": ("#FFD49A", "#FF8A33", "#C2560F"), "wood": ("#FFCE80", "#F27C1E", "#A8480C"),
    "sand": ("#FFF07A", "#FFB000", "#C27400"), "glow": ("#FFF09A", "#FFC233", "#C27400"),
    "knot": ("#FFC933", "#FF9A00", "#C27400"),
    # r3: stronger lips / gradients so parts separate at 1x
    "paw3": ("#FFD49A", "#FF8A33", "#B0420A"), "cap": ("#C4F2FF", "#1C78E0", "#12439A"),
    "lid": ("#FFE39A", "#FFA42E", "#B8520A"), "chest": ("#FFB477", "#EC5E1A", "#A63A0C"),
    "lock": ("#FFD23A", "#E88A00", "#A85A00"), "bow": ("#FFE45C", "#FFAE00", "#B85E00"),
    # r4: warm caps for finish_now (unlike the blue timer), a blue badge, a deep chest band
    "warm": ("#FFD27A", "#FF7A1A", "#B8460A"), "sky": ("#A6EEFF", "#2E9BFF", "#1A55B8"),
    "band": ("#C2560F", "#A63A0C", "#7A2A08"), "coin": ("#FFF27A", "#FFB800", "#C27400"),
    # r5: a dark red-brown chest body, bright gold trim, a dark open-lid inside so the gold coins pop
    "chest5": ("#D8643A", "#9C2F14", "#5A170A"), "trim": ("#FFF59A", "#FFCC1A", "#C27400"),
    "inside": ("#8A3412", "#5A1C08", "#3A1004"),
    # r6: a brighter lid and body so the chest separates from dark navy; a white bolt
    "lid6": ("#FFF6CC", "#FFBE4D", "#C2620E"), "chest6": ("#F08452", "#B8401C", "#6A1E0A"),
    "white6": ("#FFFFFF", "#EAF4FF", "#9DB8E0"),
}


def poly(pts):
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z"


def rrect(x0, y0, x1, y1, r):
    return (f"M{x0+r},{y0} L{x1-r},{y0} Q{x1},{y0} {x1},{y0+r} L{x1},{y1-r} Q{x1},{y1} {x1-r},{y1} "
            f"L{x0+r},{y1} Q{x0},{y1} {x0},{y1-r} L{x0},{y0+r} Q{x0},{y0} {x0+r},{y0} Z")


def rot(pts, deg, cx, cy):
    a = math.radians(deg)
    return [(cx + (x - cx) * math.cos(a) - (y - cy) * math.sin(a), cy + (x - cx) * math.sin(a) + (y - cy) * math.cos(a))
            for x, y in pts]


def ellipse(cx, cy, rx, ry, deg=0, n=48):
    return rot([(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)], deg, cx, cy)


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


def line(d, w=7, col=INK, cap="round"):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round"/>'


def stud(cx, cy, r, light, dark):
    """a Lego stud top: lighter disc in a dark ring, a gloss arc (copied from kit_icons.py)"""
    a0, a1 = math.radians(200), math.radians(260)
    rr = r * 0.62
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{light}" stroke="{dark}" stroke-width="7"/>'
            f'<path d="M{cx + rr * math.cos(a0):.1f},{cy + rr * math.sin(a0):.1f} Q{cx - rr * 0.95:.1f},{cy - rr * 0.95:.1f} '
            f'{cx + rr * math.cos(a1):.1f},{cy + rr * math.sin(a1):.1f}" fill="none" stroke="#fff" stroke-opacity="0.8" stroke-width="7" stroke-linecap="round"/>')


class Icon:
    def __init__(self, sep=8):
        self.parts, self.defs, self.backs, self.sep = [], [], [], sep  # backs: white-only fillers inside the shared rim

    def grad(self, col):
        gid = f"g{len(self.defs)}"
        top, bottom = C[col][:2]
        self.defs.append(f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
                         f'<stop offset="1" stop-color="{bottom}"/></linearGradient>')
        return gid

    def part(self, d, col, lip=12, gloss=None, extra="", rim_over=False, sep=None):
        self.parts.append((d, col, lip, gloss, extra, rim_over, sep))

    def inner(self, d, col, ink=8, lip=6):
        """a shape on top of a part: its own ink line, lip and gradient, no rim"""
        g = self.grad(col)
        sh = [lip] if lip else []
        return ("".join(f'<path d="{d}" transform="translate(0,{dy})" fill="{INK}" stroke="{INK}" stroke-width="{ink}" stroke-linejoin="round"/>'
                        for dy in sh + [0])
                + (f'<path d="{d}" transform="translate(0,{lip})" fill="{C[col][2]}"/>' if lip else "")
                + f'<path d="{d}" fill="url(#{g})"/>')

    def layers(self):
        P = lambda d, fill, dy, stroke=None, w=0: (f'<path d="{d}" transform="translate(0,{dy})" fill="{fill}"'
                                                   + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
        rim = lambda d, lip: "".join(P(d, "#fff", dy, "#fff", 30) for dy in sorted({0, lip}))
        ink = lambda d, lip, w: "".join(P(d, INK, dy, INK, w) for dy in sorted({0, lip}, reverse=True))
        out = "".join(rim(d, 0) for d in self.backs)
        out += "".join(rim(d, lip) for d, _, lip, *_ in self.parts)
        out += "".join(ink(d, lip, 12) for d, _, lip, *_ in self.parts)  # the union outline
        for d, col, lip, gloss, extra, rim_over, sep in self.parts:
            g = self.grad(col)
            # inside the union, parts separate with a lighter 8 line (12 everywhere read as dark blobs at 1x)
            out += (rim(d, lip) + ink(d, lip, 12) if rim_over else ink(d, lip, sep or self.sep))
            out += (P(d, C[col][2], lip) if lip else "") + P(d, f"url(#{g})", 0)
            if gloss:
                out += f'<path d="{gloss}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>'
            out += extra
        return out

    def svg(self, box, note):
        x, y, s = box
        body = self.layers()  # first: layers() adds the part gradients to defs (kit_icons.py emits defs first and loses them)
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x:.1f} {y:.1f} {s:.1f} {s:.1f}" width="128" height="128">'
                f"<!-- {note} (tools/ui-art/kit_icons3.py r3) --><defs>{''.join(self.defs)}</defs>{body}</svg>\n")


# --- the icons ---
def companion():
    i = Icon()
    for cx, cy, deg in ((20, 84, -30), (64, 18, -10), (136, 18, 10), (180, 84, 30)):  # r4: taller toes spread up (spare height) so white shows between
        i.part(poly(ellipse(cx, cy, 24, 33, deg)), "paw3", lip=12, gloss=f"M{cx - 13},{cy - 4} Q{cx - 12},{cy - 17} {cx - 3},{cy - 23}")
    i.backs.append(poly([(30, 92), (58, 36), (142, 36), (170, 92), (150, 140), (50, 140)]))  # white between toes and pad: one die-cut sticker
    pad = "M100,104 C130,104 158,130 162,154 C166,178 146,188 126,182 C114,178 86,178 74,182 C54,188 34,178 38,154 C42,130 70,104 100,104 Z"
    i.part(pad, "paw3", lip=14, gloss="M56,154 C58,140 66,130 76,124", extra=stud(100, 148, 22, "#FFF4E2", "#A63A0C"))
    return i, "companion: a bright caramel-orange paw print, big spread toes, a high-contrast Lego stud on the big pad, strong dark lips"


def crew():
    i = Icon()

    def fig(ox, helmet):
        T = lambda d: tf(d, 1, ox, 0)
        H = lambda d: tf(d, 1.12, ox - 7.2, -18)  # r4: head + helmet 12% bigger about (60, 150)
        i.part(T("M4,192 L12,154 Q16,138 34,138 L86,138 Q104,138 108,154 L116,192 Z"), "orange", gloss=T("M26,162 L30,152"))
        eyes = "".join(f'<circle cx="{ox + x}" cy="108" r="12.5" fill="{INK}"/>' for x in (42, 78))
        i.part(H(rrect(20, 64, 100, 150, 20)), "skin", lip=8, extra=eyes + line(T("M40,130 Q60,148 80,130"), 11))
        i.part(H(rrect(46, 12, 74, 34, 6)), helmet, lip=0)
        i.part(H("M10,82 Q10,28 60,28 Q110,28 110,82 Q110,88 104,88 L16,88 Q10,88 10,82 Z"), helmet, lip=8,
               gloss=H("M28,60 Q32,46 48,40"))

    i.backs.append(rrect(80, 40, 150, 160, 10))  # fills the rim gap between the heads: one shared sticker
    fig(112, "red")  # behind, spaced so each 12%-bigger head keeps its own dark outline
    fig(0, "blue")
    return i, "crew: two wide Lego minifig rescuers shoulder to shoulder under one white rim, big yellow heads, big dot eyes and a wide smile"


HOURGLASS = {  # 200-unit hourglass, M/L/Q only so finish_now can scale it
    "studs": [rrect(54, -6, 82, 12, 5), rrect(118, -6, 146, 12, 5)],
    "glass": "M50,36 L150,36 Q150,80 124,100 Q150,120 150,164 L50,164 Q50,120 76,100 Q50,80 50,36 Z",
    "top": rrect(20, 6, 180, 40, 12), "bottom": rrect(20, 160, 180, 192, 12),
    "sand_top": "M62,52 L138,52 Q136,78 116,94 L84,94 Q64,78 62,52 Z",
    "sand_bot": "M54,164 Q56,118 100,110 Q144,118 146,164 Z",
}


def hourglass_parts(i, s=1, ox=0, oy=0, cap="cap"):
    T = lambda d: tf(d, s, ox, oy)
    H = HOURGLASS
    for d in H["studs"]:
        i.part(T(d), cap, lip=0)
    sand = i.inner(T(H["sand_top"]), "sand", ink=8, lip=0) + i.inner(T(H["sand_bot"]), "sand", ink=8, lip=0) \
        + line(T("M100,92 L100,114"), 16 * s, "#FFB000")
    i.part(T(H["glass"]), "glass", lip=0, gloss=T("M62,112 Q58,130 60,146"), extra=sand)
    i.part(T(H["top"]), cap, gloss=T("M36,20 L84,20"))
    i.part(T(H["bottom"]), cap, gloss=T("M36,174 L60,174"))


def hourglass():
    i = Icon()
    hourglass_parts(i)
    return i, "timer: a chunky hourglass, two strong-gradient Lego-blue studded caps, pale glass with a wide waist, big gold sand"


def finish_now():
    if not R6["finish_now"]:
        return finish_now_r5()
    i = Icon(sep=10)
    hourglass_parts(i)
    s, cx, cy, r = 0.5, 162, 158, 60  # r6: a bigger gold disc (same outer bbox as r5), a white bolt
    bolt = tf("M106,8 L154,8 L124,72 L172,72 L72,192 L92,118 L36,118 Z", s, cx - 104 * s, cy - 100 * s)
    i.part(poly(ellipse(cx, cy, r, r, 0, 64)), "gold", lip=10, gloss=f"M{cx - 38},{cy - 6} Q{cx - 36},{cy - 32} {cx - 16},{cy - 42}",
           extra=i.inner(bolt, "white6", ink=10, lip=5), rim_over=True)
    return i, "finish now (r6): a blue-capped hourglass with a big gold lightning badge (white bolt) on its own white rim over the corner"


def finish_now_r5():
    i = Icon(sep=10)
    hourglass_parts(i)  # r5: the peer hourglass family (blue caps, gold sand); the bolt badge sets it apart
    s = 0.44  # bolt box centre (104, 100) -> disc centre (172, 168)
    disc = poly(ellipse(172, 168, 50, 50, 0, 64))
    bolt = tf("M106,8 L154,8 L124,72 L172,72 L72,192 L92,118 L36,118 Z", s, 172 - 104 * s, 168 - 100 * s)
    i.part(disc, "sky", lip=10, gloss="M140,160 Q142,140 156,132", extra=i.inner(bolt, "gold", ink=9, lip=5), rim_over=True)
    return i, "finish now: a blue-capped hourglass with a big blue lightning badge (gold bolt) on its own white rim over the corner"


def daily():
    if not R6["daily"]:
        return daily_r5()
    i = Icon()
    lid = "M16,100 L32,22 Q34,8 48,8 L152,8 Q166,8 168,22 L184,100 Z"
    for x in (56, 112):
        i.part(rrect(x, -10, x + 32, 14, 7), "lid6", lip=0)
    i.part(lid, "lid6", lip=0, gloss="M30,84 L42,30", extra=i.inner("M42,96 L54,34 L146,34 L158,96 Z", "inside", ink=8, lip=0))
    for cx, cy, r in ((54, 88, 40), (146, 88, 40), (100, 70, 46)):  # r6: three bigger coins, the middle one in front
        i.part(poly(ellipse(cx, cy, r, r)), "coin", lip=0, sep=12,
               gloss=f"M{cx - r * 0.55:.0f},{cy - 2} Q{cx - r * 0.5:.0f},{cy - r * 0.5:.0f} {cx - 2},{cy - r * 0.62:.0f}")
    body = rrect(0, 112, 200, 190, 14)
    i.part(body, "chest6", lip=14, gloss="M30,150 L30,170",
           extra=i.inner(rrect(0, 112, 200, 130, 6), "trim", ink=8, lip=0)
           + "".join(i.inner(rrect(x, 112, x + 22, 190, 4), "trim", ink=7, lip=0) for x in (28, 150)))
    i.part(rrect(78, 104, 122, 150, 10), "trim", lip=8, gloss="M88,116 L88,128",
           extra=f'<rect x="95" y="122" width="10" height="16" rx="5" fill="{INK}"/>')
    return i, "daily reward (r6): a Lego treasure chest flung open, a bright studded lid with a gloss and a dark inside, three big gold coins, a red-brown body with bright gold trim and latch"


def daily_r5():
    i = Icon()
    lid = "M16,100 L32,22 Q34,8 48,8 L152,8 Q166,8 168,22 L184,100 Z"  # the lid flung open behind, its dark inside showing
    for x in (56, 112):  # 2 Lego studs on the lid's top edge
        i.part(rrect(x, -10, x + 32, 14, 7), "lid", lip=0)
    i.part(lid, "lid", lip=0, extra=i.inner("M42,96 L54,34 L146,34 L158,96 Z", "inside", ink=8, lip=0))
    for cx, cy, r in ((50, 92, 32), (150, 92, 32), (100, 74, 38)):  # r5: three big plain coins, each a full 12 outline
        i.part(poly(ellipse(cx, cy, r, r)), "coin", lip=0, sep=12,
               gloss=f"M{cx - r * 0.55:.0f},{cy - 2} Q{cx - r * 0.5:.0f},{cy - r * 0.5:.0f} {cx - 2},{cy - r * 0.62:.0f}")
    body = rrect(0, 112, 200, 190, 14)
    i.part(body, "chest5", lip=14, gloss="M30,150 L30,170",
           extra=i.inner(rrect(0, 112, 200, 130, 6), "trim", ink=8, lip=0)  # a bright gold rim band: lid and body read as two parts
           + "".join(i.inner(rrect(x, 112, x + 22, 190, 4), "trim", ink=7, lip=0) for x in (28, 150)))
    i.part(rrect(78, 104, 122, 150, 10), "trim", lip=8, gloss="M88,116 L88,128",
           extra=f'<rect x="95" y="122" width="10" height="16" rx="5" fill="{INK}"/>')  # a small keyhole slot, not a mushy dot
    return i, "daily reward: a Lego treasure chest flung open, studded light lid with a dark inside, three big gold coins, a dark red-brown body with bright gold trim and latch"


def gift():
    i = Icon()
    B = lambda d: tf(d, 1.15, 100 - 115, 76 - 87.4)  # bow 15% bigger about the knot (100,76)
    loops = ("M100,76 C74,16 12,12 24,56 C30,80 72,82 100,76 Z", "M100,76 C126,16 188,12 176,56 C170,80 128,82 100,76 Z")
    holes = "".join(i.inner(B(d), "knot", ink=8, lip=0) for d in (
        "M84,68 C70,42 46,36 48,54 C50,66 70,70 84,68 Z", "M116,68 C130,42 154,36 152,54 C150,66 130,70 116,68 Z"))
    i.part(" ".join(B(d) for d in loops), "bow", lip=12, gloss=B("M30,48 Q32,30 50,28"), extra=holes)
    i.part(rrect(32, 108, 168, 190, 10), "red", gloss="M46,128 L46,158", extra=i.inner(rrect(82, 110, 118, 190, 2), "gold", ink=7, lip=0))
    lid_studs = stud(48, 101, 12, "#FFB8AC", "#C21F2A") + stud(152, 101, 12, "#FFB8AC", "#C21F2A")
    i.part(rrect(16, 70, 184, 120, 10), "red", gloss="M30,82 L40,82",
           extra=i.inner(rrect(82, 70, 118, 120, 2), "gold", ink=7, lip=0) + lid_studs)
    i.part(rrect(78, 54, 122, 92, 12), "bow", lip=0, gloss="M90,66 L96,64")
    return i, "gift: a red present with two Lego studs on the lid, a thick gold ribbon cross, a big gold bow with a dark lip"


ICONS = [companion, crew, daily, finish_now, gift, hourglass]


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
        assert x0 > 0 and y0 > 0 and x1 < 256 and y1 < 256, f"{name} clipped in the probe box"
        bx0, by0, bx1, by1 = probe[0] + x0 * k, probe[1] + y0 * k, probe[0] + x1 * k, probe[1] + y1 * k
        side = max(bx1 - bx0, by1 - by0) / FILL
        cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
        icon2, _ = fn()  # fresh gradient ids
        path.write_text(icon2.svg((cx - side / 2, cy - side / 2, side), note))
        render(path, png)
        im = Image.open(png)
        bb = im.getbbox()
        assert im.size == (256, 256) and bb[0] > 0 and bb[1] > 0 and bb[2] < 256 and bb[3] < 256, (name, im.size, bb)
        print(name, im.size, "bbox", bb, "fill %.2f" % (max(bb[2] - bb[0], bb[3] - bb[1]) / 256))
