#!/usr/bin/env python3
"""Kit menu icons, half 2 (lifebuoy, lock, map, quests, settings, sun, vip; plus Badges.Rays; shop/spin/wave live in kit_icons4.py, waves is hand SVG), in the stickers.py
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

# round 6 redraws; False = the version that shipped as best (lifebuoy/quests/sun r5, map/rays r3)
R6 = {"lifebuoy": False, "map": False, "quests": True, "sun": True, "rays": False}
# round 7 redraws; False = the best version (rays r3)
R7 = {"rays": True}
# round 8 redraws; False = the best version (rays r7)
R8 = {"rays": True}

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
    """rescue / pickup ring: a fat red ring, four white bands as wide as the red (one with a Lego stud), a deep navy hole
    with an inner shadow under its top edge"""
    c, R, r = (100, 98), 88, 34
    bands = [part(ring_sector(*c, r, R, a - 22.5, a + 22.5), WHITE, dy=16) for a in (0, 90, 180, 270)]
    seams = "".join(ink(*polar(*c, r, a), *polar(*c, R, a), w=7) for b in (0, 90, 180, 270) for a in (b - 22.5, b + 22.5))
    hole = (f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="#040A1C"/>'  # the shadow crescent under the top edge
            f'<circle cx="{c[0]}" cy="{c[1] + 10}" r="{r - 6}" fill="#0F2656"/>'
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
    """quest board / pontoons: a light cream scroll on gold rolls, two dark brown bars, a big red seal with a white star"""
    body, seal = "M40,40 L160,40 L160,180 L40,180 Z", circ(100, 160, 42)
    roll = lambda y: f"M40,{y} L160,{y} Q178,{y} 178,{y + 17} Q178,{y + 34} 160,{y + 34} L40,{y + 34} Q22,{y + 34} 22,{y + 17} Q22,{y} 40,{y} Z"
    curls = ink(42, 41, 158, 41, 8, "#B86A00") + ink(42, 193, 158, 193, 8, "#B86A00")  # the under-curl shade of each roll
    rollc = ("#FFF08A", "#F39A00", "#A85A00")
    bars = ink(64, 74, 136, 74, 18, "#6E3812") + ink(64, 100, 112, 100, 18, "#6E3812")
    pts = " ".join("%.1f,%.1f" % polar(100, 161, 27 if k % 2 == 0 else 12, k * 36 - 90) for k in range(10))
    star = (f'<polygon points="{pts}" fill="#A3161E" stroke="#A3161E" stroke-width="6" stroke-linejoin="round" transform="translate(0,5)"/>'
            f'<polygon points="{pts}" fill="#fff" stroke="#fff" stroke-width="6" stroke-linejoin="round"/>')
    s = build([part(body, ("#FFFFF8", "#FBE6BE", "#C27400")), part(roll(14), rollc, z=1, sep=True),
               part(roll(166), rollc, z=1, sep=True, dy=16), part(seal, RED, z=2, sep=True)],
              gloss=["M36,24 L74,24"], extra=bars + star)
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
    """golden hour: a gold-to-orange sun, eight short fat triangular rays (long and short) clear of the disc"""
    c = (100, 98)
    rays = ""
    for i in range(8):
        a, tip, half = i * 45 - 90, (98 if i % 2 == 0 else 88), (17 if i % 2 == 0 else 14)
        (x0, y0), (x1, y1), (x2, y2) = polar(*c, 64, a - half), polar(*c, tip, a), polar(*c, 64, a + half)
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


def lifebuoy6():
    """rescue / pickup ring: a fat red ring, four white bands as wide as the red (one with a Lego stud), a white rope
    loop on the outer rim of each red band, a deep navy hole with an inner shadow under its top edge"""
    c, R, r = (100, 98), 88, 34
    bands = [part(ring_sector(*c, r, R, a - 22.5, a + 22.5), WHITE, dy=16) for a in (0, 90, 180, 270)]
    seams = "".join(ink(*polar(*c, r, a), *polar(*c, R, a), w=7) for b in (0, 90, 180, 270) for a in (b - 22.5, b + 22.5))
    hole = (f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="#040A1C"/>'
            f'<circle cx="{c[0]}" cy="{c[1] + 10}" r="{r - 6}" fill="#0F2656"/>'
            f'<circle cx="{c[0]}" cy="{c[1]}" r="{r}" fill="none" stroke="{INK}" stroke-width="8"/>')
    arc = lambda a0, a1, rr: "M%.1f,%.1f A%d,%d 0 0,1 %.1f,%.1f" % (*polar(*c, rr, a0), rr, rr, *polar(*c, rr, a1))
    # each rope runs band to band along the outer rim of a red band, its ends tucked onto the white bands
    rope = "".join(f'<path d="{arc(a - 27, a + 27, 75)}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>'
                   for a in (45, 135, 225, 315) for col, w in ((INK, 24), ("#FFFFFF", 12)))
    return build([part(circ(*c, R), ("#FF9584", "#C81A26", "#82101A"), dy=16)] + bands, gloss=[arc(208, 242, 51)],
                 extra=seams + hole + rope + stud(100, 37, 14, "#FFFFFF", "#8E9AB2"))


def map6():
    """the full map: a wide chart folded in three (the middle panel darker, a shade at each fold), a dotted brown trail
    to a hand-drawn red X on the paper"""
    xs, hi, lo = (8, 68, 132, 192), 40, 24
    top = [(x, hi if i % 2 == 0 else lo) for i, x in enumerate(xs)]
    light, dark = ("#FFF4B0", "#FFC93A", "#C27400"), ("#FFD447", "#E58A00", "#A85A00")
    panels = [part(f"M{top[i][0]},{top[i][1]} L{top[i + 1][0]},{top[i + 1][1]} L{top[i + 1][0]},{top[i + 1][1] + 120} "
                   f"L{top[i][0]},{top[i][1] + 120} Z", dark if i == 1 else light) for i in range(3)]
    # a darker strip on each panel where it bends into a fold
    fold = lambda x0, y0, x1, y1, col, op: (f'<path d="M{x0},{y0} L{x1},{y1} L{x1},{y1 + 120} L{x0},{y0 + 120} Z" '
                                           f'fill="{col}" fill-opacity="{op}"/>')
    k = (hi - lo) / 60
    shade = (fold(48, hi - 40 * k, 68, lo, "#C27400", 0.35) + fold(68, lo, 90, lo + 22 * k, "#7A3E00", 0.35)
             + fold(132, hi, 152, hi - 20 * k, "#7A3E00", 0.3))
    folds = ink(68, lo, 68, lo + 120, 8) + ink(132, hi, 132, hi + 120, 8)
    trail = ('<path d="M28,128 C46,90 92,146 126,98" stroke="#6E3812" stroke-width="16" stroke-linecap="round" '
             'stroke-dasharray="1 26" fill="none"/>')
    # a brushy X: two slightly bowed strokes, a dark-red edge (no rim of its own) under a red core
    xd = ["M148,76 Q162,88 176,104", "M176,74 Q160,90 150,106"]
    x = "".join(f'<path d="{d}" stroke="{col}" stroke-width="{w}" stroke-linecap="round" fill="none"/>'
                for col, w in (("#7A0E14", 28), ("#E2333A", 16)) for d in xd)
    return build(panels, gloss=["M22,58 L50,54"], extra=shade + folds + trail + x)


def quests6():
    """quest board / pontoons: a square wooden notice board, a cream paper pinned to it with three dark brown text
    bars, a big red seal with a white star on its corner"""
    board = "M30,24 L170,24 Q186,24 186,40 L186,160 Q186,176 170,176 L30,176 Q14,176 14,160 L14,40 Q14,24 30,24 Z"
    paper = "M40,44 L156,40 L160,156 L44,160 Z"
    seal = circ(146, 146, 34)
    bars = ink(62, 76, 136, 74, 18, "#6E3812") + ink(62, 102, 132, 100, 18, "#6E3812") + ink(64, 128, 104, 127, 18, "#6E3812")
    pts = " ".join("%.1f,%.1f" % polar(146, 147, 22 if k % 2 == 0 else 10, k * 36 - 90) for k in range(10))
    star = (f'<polygon points="{pts}" fill="#A3161E" stroke="#A3161E" stroke-width="6" stroke-linejoin="round" transform="translate(0,5)"/>'
            f'<polygon points="{pts}" fill="#fff" stroke="#fff" stroke-width="6" stroke-linejoin="round"/>')
    s = build([part(board, ("#E9A55A", "#B8682C", "#7A3E14"), dy=16), part(paper, ("#FFFFF8", "#FBE6BE", "#C9A070"), z=1, sep=True, dy=8),
               part(seal, RED, z=2, sep=True)], gloss=["M26,40 L26,72"], extra=bars + star)
    i = s.rindex(f'<path d="{seal}" fill="{INK}"')  # the pin goes under the seal's own outline (they never touch)
    return s[:i] + stud(98, 44, 12, "#8EE0FF", "#1A55A8") + s[i:]


def sun6():
    """a friendly sun: a big light-yellow disc (60% of the width) in eight short rounded teardrop rays with gaps"""
    c, d0, d1, rr = (100, 100), 68, 88, 11
    rays = ""
    t = math.degrees(math.acos(rr / (d1 - d0)))  # tangent from the inner tip to the round end
    for i in range(8):
        a = i * 45 - 90
        tip, cc = polar(*c, d0, a), polar(*c, d1, a)
        (x0, y0), (x1, y1) = polar(*cc, rr, a + 180 - t), polar(*cc, rr, a + 180 + t)
        rays += f"M{tip[0]:.1f},{tip[1]:.1f} L{x0:.1f},{y0:.1f} A{rr},{rr} 0 1,0 {x1:.1f},{y1:.1f} Z "
    g = "M%.1f,%.1f A40,40 0 0,1 %.1f,%.1f" % (*polar(*c, 40, 196), *polar(*c, 40, 250))
    return build([part(rays, ("#FFD24A", "#FF9A14", "#C25E00")), part(circ(*c, 58), ("#FFF7B0", "#FFD21F", "#D08A00"), z=1, sep=True)],
                 gloss=[g])


ICONS = {"lifebuoy": lifebuoy6 if R6["lifebuoy"] else lifebuoy, "lock": lock, "map": map6 if R6["map"] else map_,
         "quests": quests6 if R6["quests"] else quests, "settings": settings, "sun": sun6 if R6["sun"] else sun, "vip": vip}


def rays():
    """Badges.Rays, the burst behind a reward (medal flip, skill unlock) that spins slowly: 12 equal hard wedges (gaps between) in two
    golds (light | deep) on a deep orange edge, a flat warm hub under the prize. R7: long light | short deep rays, a thinner
    edge, a pale glowing hub. R6: a thinner edge and the wedge ends
    fading out so the burst sits behind the badge. A 400 page centred on 200,200 (rendered whole, kept, so it spins about
    its centre); writes art/source/ui/rays.svg"""
    if R8["rays"]:
        return rays8()
    c, r6, r7 = (200, 200), R6["rays"], R7["rays"]
    # R7: long | short rays (1.0 / 0.75) so the edge is a jagged star that shows the spin, a 30% thinner edge, a pale hub
    R = lambda i: 186 if not r7 or i % 2 == 0 else 140
    h = lambda i: 10.5 if not r7 else (12 if i % 2 == 0 else 9.5)
    angles = [i * 30 - 90 for i in range(12)]
    wedge = lambda i: "M200,200 L%.1f,%.1f A%d,%d 0 0,1 %.1f,%.1f Z" % (
        *polar(*c, R(i), angles[i] - h(i)), R(i), R(i), *polar(*c, R(i), angles[i] + h(i)))
    fade = lambda c1: f'<stop offset="0.62" stop-color="{c1}"/><stop offset="1" stop-color="{c1}" stop-opacity="0"/>' if r6 else ""
    defs = "".join(f'<radialGradient id="{k}" cx="200" cy="200" r="186" gradientUnits="userSpaceOnUse"><stop offset="0.3" '
                   f'stop-color="{a}"/>' + (f'<stop offset="0.62" stop-color="{b}"/>' if r6 else f'<stop offset="1" stop-color="{b}"/>')
                   + (f'<stop offset="1" stop-color="{b}" stop-opacity="0"/>' if r6 else "") + "</radialGradient>"
                   for k, a, b in (("a", "#FFF09A", "#FFCC1F"), ("c", "#FFC531", "#FF9500")))
    edge = "#E25F00"
    if r6:
        defs += f'<radialGradient id="e" cx="200" cy="200" r="190" gradientUnits="userSpaceOnUse">{fade(edge)}</radialGradient>'
        edge = "url(#e)"
    w = 6 if r6 else 8 if r7 else 12
    out = [f'<path d="{wedge(i)}" fill="{edge}" stroke="{edge}" stroke-width="{w}" stroke-linejoin="round"/>' for i in range(12)]
    out.append(f'<circle cx="200" cy="200" r="62" fill="#E25F00" stroke="#E25F00" stroke-width="{w}"/>')
    out += [f'<path d="{wedge(i)}" fill="url(#{"ac"[i % 2]})"/>' for i in range(12)]
    out += ['<path d="M%.1f,%.1f L%.1f,%.1f" stroke="#fff" stroke-opacity="0.5" stroke-width="8" stroke-linecap="round"/>'
            % (*polar(*c, 93, a - 4), *polar(*c, 140 if r6 else 164, a - 4)) for a in angles[::2]]
    if r7:  # a pale glowing hub (the prize sits on it), a light gold ring
        defs += ('<radialGradient id="hub" cx="200" cy="200" r="62" gradientUnits="userSpaceOnUse"><stop offset="0" '
                 'stop-color="#FFFDEA"/><stop offset="0.7" stop-color="#FFF4B0"/><stop offset="1" stop-color="#FFE47A"/></radialGradient>')
        out.append('<circle cx="200" cy="200" r="62" fill="url(#hub)"/><circle cx="200" cy="200" r="62" fill="none" stroke="#F5AE10" stroke-width="6"/>')
    else:
        out.append('<circle cx="200" cy="200" r="62" fill="#FFD23F"/><circle cx="200" cy="200" r="62" fill="none" stroke="#F08A00" stroke-width="8"/>')
    (SRC / "rays.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">'
                                  f"<!-- {' '.join(rays.__doc__.split())} (tools/ui-art/kit_icons2.py) --><defs>{defs}</defs>"
                                  + "".join(out) + "</svg>\n")


def rays8():
    """Badges.Rays R8: the R7 burst (12 long | short rays, a pale glowing hub) as a die-cut sticker: a white rim and a deep
    amber outline round the whole star, each ray pale gold to rich orange with a darker lip at its tip (radial, so it holds
    while spinning); rays a touch narrower so the notches stay open (not a gear)"""
    c, ink, rim, out = (200, 200), "#A8460A", 6, 6  # rim / outline: units outside the fill (1 unit = 0.3 pt at 120 pt)
    R = lambda i: 182 if i % 2 == 0 else 140
    h = lambda i: 10.5 if i % 2 == 0 else 8
    angles = [i * 30 - 90 for i in range(12)]
    wedge = lambda i, r: "M200,200 L%.1f,%.1f A%d,%d 0 0,1 %.1f,%.1f Z" % (
        *polar(*c, r, angles[i] - h(i)), r, r, *polar(*c, r, angles[i] + h(i)))
    grad = lambda k, r, stops: (f'<radialGradient id="{k}" cx="200" cy="200" r="{r}" gradientUnits="userSpaceOnUse">'
                                + "".join(f'<stop offset="{o}" stop-color="{col}"/>' for o, col in stops) + "</radialGradient>")
    defs = (grad("a", 173, ((0.35, "#FFF4A8"), (0.7, "#FFC21A"), (1, "#F59200")))
            + grad("c", 131, ((0.45, "#FFC531"), (1, "#FF8400")))
            + grad("hub", 62, ((0, "#FFFDEA"), (0.7, "#FFF4B0"), (1, "#FFE47A"))))
    lip = lambda i: "#D86A00" if i % 2 == 0 else "#C25200"
    out_ = []
    for col, w in (("#FFFFFF", 2 * (rim + out)), (ink, 2 * out)):  # white rim, then the hard outline, round the union
        out_ += [f'<path d="{wedge(i, R(i))}" fill="{col}" stroke="{col}" stroke-width="{w}" stroke-linejoin="round"/>' for i in range(12)]
        out_.append(f'<circle cx="200" cy="200" r="62" fill="{col}" stroke="{col}" stroke-width="{w}"/>')
    out_ += [f'<path d="{wedge(i, R(i))}" fill="{lip(i)}"/>' for i in range(12)]  # the lip: a darker band at each tip
    out_ += [f'<path d="{wedge(i, R(i) - 9)}" fill="url(#{"ac"[i % 2]})"/>' for i in range(12)]
    out_ += ['<path d="M%.1f,%.1f L%.1f,%.1f" stroke="#fff" stroke-opacity="0.5" stroke-width="8" stroke-linecap="round"/>'
             % (*polar(*c, 93, a - 3), *polar(*c, 150, a - 3)) for a in angles[::2]]
    out_.append('<circle cx="200" cy="200" r="62" fill="url(#hub)"/><circle cx="200" cy="200" r="62" fill="none" stroke="#F5AE10" stroke-width="6"/>')
    (SRC / "rays.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="400" height="400">'
                                  f"<!-- {' '.join(rays8.__doc__.split())} (tools/ui-art/kit_icons2.py) --><defs>{defs}</defs>"
                                  + "".join(out_) + "</svg>\n")


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
    rays()
    cmd = ["python3", "tools/ui-art/render.py", "art/source/ui/rays.svg", str(out_dir / "Badges.Rays.png"), "--size", "400", "400", "--keep"]
    subprocess.run(cmd, cwd=ROOT, check=True, capture_output=True)
    im = Image.open(out_dir / "Badges.Rays.png")
    l, t, r, b = im.getbbox()
    assert im.size == (800, 800) and min(l, t) > 0 and max(r, b) < 800, (l, t, r, b)  # whole burst on the page
    manifest["Badges.Rays"] = {"svg": "art/source/ui/rays.svg", "cmd": " ".join(cmd)}
    if "--manifest" in sys.argv:
        pathlib.Path(sys.argv[sys.argv.index("--manifest") + 1]).write_text(json.dumps(manifest, indent=1) + "\n")
