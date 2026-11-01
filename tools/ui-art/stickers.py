#!/usr/bin/env python3
"""The small UI-kit stickers (uia2, CLAUDE.md "UI art"): one shape each, drawn in the build arrow's layers (white
sticker rim, hard dark outline, darker lip under a bold gradient, a soft gloss stroke). Writes the SVG sources to
art/source/ui/<name>.svg and renders build/ui-art/<name>.png (2x).   usage: python3 tools/ui-art/stickers.py
Rotating sprites (the map arrow) have no lip and keep their box (--keep) so the game spins them about its centre."""
import math
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC, OUT = ROOT / "art/source/ui", ROOT / "build/ui-art"
INK = "#14121C"
# round 6 redraws (anchored AD rounds): False regenerates the shipped best PNG pixel-identical
R6 = {"pad_slow": True}
R7 = {"pad_slow": True}
R8 = {"pad_slow": False}
# r10: "c1" = the r9 snail concept (won r9; concept SVG in build/status/2026-10-31/perfect/ui/anch/r9/src); "polish" = the 3 ADs' shared fixes on it
R10 = {"c1": True, "polish": True}
# in-game r2 (build/status/2026-10-31/perfect/ui/ingame): False regenerates the r10 best pixel-identical
R11 = {"pad_slow": True}
R12 = {"pad_slow": False}  # in-game r3: False regenerates the r2 (R11) render pixel-identical

STAR = "M100,18 L122,72 L180,76 L135,113 L150,170 L100,138 L50,170 L65,113 L20,76 L78,72 Z"
HEART = "M100,176 C40,132 18,104 18,72 C18,44 40,26 64,26 C82,26 94,36 100,50 C106,36 118,26 136,26 C160,26 182,44 182,72 C182,104 160,132 100,176 Z"
ARROW = "M100,14 L170,178 Q172,184 166,181 L100,126 L34,181 Q28,184 30,178 Z"
STUD = "M100,30 A70,70 0 1,1 99.9,30 Z"
# a speech bubble, tail down-left; three chunky stud dots
CHAT_DOTS = "".join(f'<circle cx="{x}" cy="87" r="15" fill="#fff" stroke="{INK}" stroke-width="7"/>'
                    f'<path d="M{x - 8},84 A9,9 0 0,1 {x - 2},78" fill="none" stroke="#9FCBEF" stroke-width="5" stroke-linecap="round"/>'
                    for x in (56, 100, 144))
CHAT = "M40,30 L160,30 Q186,30 186,56 L186,118 Q186,144 160,144 L92,144 L56,176 Q50,181 51,173 L58,144 L40,144 Q14,144 14,118 L14,56 Q14,30 40,30 Z"


def stud_top(light, mid, dark, gloss=0.9, ring=11):
    """a Lego stud's flat top: a raised disc (bright top to its own shade) inside a dark ring, a gloss arc (its opacity)"""
    return (f'<linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{light}"/>'
            f'<stop offset="1" stop-color="{mid}"/></linearGradient>'
            f'<circle cx="100" cy="100" r="46" fill="url(#s)" stroke="{dark}" stroke-width="{ring}"/>'
            + (f'<path d="M70,90 A32,32 0 0,1 92,66" fill="none" stroke="#fff" stroke-opacity="{gloss}" stroke-width="10" '
               'stroke-linecap="round"/>' if gloss else ""))


def sticker(d, top, bottom, lip, lip_dy=12, gloss=None, extra="", rim=30, ink=12):
    """d: the shape; top/bottom: its gradient; lip: the shade under it, lip_dy units down (0: none)."""
    g = f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
    shift = [0, lip_dy] if lip_dy else [0]
    p = lambda fill, stroke="", w=0, dy=0: (f'<path d="{d}" transform="translate(0,{dy})" fill="{fill}"'
                                            + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
    layers = "".join(p("#fff", "#fff", rim, dy) for dy in shift) + "".join(p(INK, INK, ink, dy) for dy in shift)
    layers += (p(lip, dy=lip_dy) if lip_dy else "") + p("url(#g)")
    if gloss:
        layers += f'<path d="{gloss}" fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="10" stroke-linecap="round"/>'
    return g, layers + extra


def svg(name, defs_layers, box=(-22, -22, 244, 256), note=""):
    x, y, w, h = box
    defs, layers = defs_layers
    text = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" width="{w}" height="{h}">'
            f"<!-- {note} --><defs>{defs}</defs>{layers}</svg>\n")
    (SRC / f"{name}.svg").write_text(text)


STICKERS = {
    "star_on": (sticker(STAR, "#FFE45C", "#FFAE00", "#C27400", gloss="M58,84 L84,82 L95,52"),
                "a building level earned / the weekly streak day: gold Lego star"),
    "star_off": (sticker(STAR, "#F4F6F9", "#A2AAB6", "#3E4551", lip_dy=14, ink=15,
                         extra='<path d="M58,84 L84,82 L95,52" fill="none" stroke="#fff" stroke-opacity="1" '
                               'stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/>'),
                 "a level not built yet: the same star in neutral cool grey"),
    "heart": (sticker(HEART, "#FF9AAA", "#EE3D57", "#6E0C1E", lip_dy=16, gloss="M40,66 C40,52 52,44 64,44"),
              "the companion's love hearts (a pat, a treat)"),
    "pip_on": (sticker(STUD, "#8BEA7A", "#2FA84A", "#145C24", lip_dy=18, extra=stud_top("#E4FFD2", "#6FD866", "#1A6E2E")),
               "a filled seat on your craft: a green Lego stud (flat top, raised ring, side lip)"),
    "pip_full": (sticker(STUD, "#FF9470", "#E2261A", "#560603", lip_dy=18, gloss="M45,80 A59,59 0 0,1 80,45",
                         extra=stud_top("#FFF0E6", "#FF6A4A", "#A8140C")),
                 "every seat filled: the studs turn red, glossier, a darker lip"),
    "pip_off": (sticker(STUD, "#C9CED6", "#AEB4BE", "#5A616C", lip_dy=18, extra=stud_top("#8E96A2", "#7E8692", "#535A66", gloss=0)),
                "an empty seat: the same stud in flat cool grey, a dark matte top"),
    "map_player": (sticker(ARROW, "#8EE0FF", "#1A5FD0", "#0E3A85", lip_dy=10, rim=40, gloss="M97,48 L72,108",
                           extra='<path d="M100,30 L100,120 L42,170 Z" fill="#fff" fill-opacity="0.3"/>'
                                 '<path d="M100,30 L158,170 L100,120 Z" fill="#0E3A85" fill-opacity="0.3"/>'),
                   "you on the map: a blue brick wedge, tip up (light left facet, dark right), its box centred to spin about"),
    "chat": (sticker(CHAT, "#A8E8FF", "#2C7FE8", "#15449A", lip_dy=16,
                     gloss="M34,104 L34,64 Q34,50 50,48 L70,48", extra=CHAT_DOTS),
             "idle crew chatting (WorkerController): a wordless speech bubble, three stud dots"),
}


# the touch drive pad (TouchDriveController): a round Lego button each, a white icon with the hard outline on top
DISC = "M100,14 A86,86 0 1,1 99.9,14 Z"
DISC_GLOSS = "M44,78 A60,60 0 0,1 78,40"


def icon(d, extra=""):
    """a white pad icon over the disc: the dark outline first, then the fill (reads on any sea or sky)"""
    return (f'<path d="{d}" fill="{INK}" stroke="{INK}" stroke-width="20" stroke-linejoin="round"/>'
            f'<path d="{d}" fill="#fff" stroke="#fff" stroke-width="4" stroke-linejoin="round"/>' + extra)


def pad(top, bottom, lip, d, extra="", gloss=DISC_GLOSS):
    return sticker(DISC, top, bottom, lip, lip_dy=14, gloss=gloss, extra=icon(d, extra))


ARROW_LEFT = "M38,100 L94,48 L94,78 L158,78 L158,122 L94,122 L94,152 Z"
ARROW_RIGHT = "M162,100 L106,48 L106,78 L42,78 L42,122 L106,122 L106,152 Z"
# a turtle seen side-on, facing right: a tall shell dome, a round head up front on a sloped neck, two chunky feet
TURTLE = ("M34,124 C34,70 56,50 80,50 C104,50 126,70 126,124 Z M146,65 A21,21 0 1,1 145.9,65 Z "
          "M114,104 L136,86 L150,100 L122,122 Z "
          "M44,118 L70,118 L70,138 Q70,146 62,146 L52,146 Q44,146 44,138 Z "
          "M90,118 L116,118 L116,138 Q116,146 108,146 L98,146 Q90,146 90,138 Z")


def hexagon(cx, cy, r):
    return "M" + " L".join(f"{cx + r * c:.1f},{cy + r * s:.1f}" for c, s in
                           ((1, 0), (.5, .866), (-.5, .866), (-1, 0), (-.5, -.866), (.5, -.866))) + " Z"


# three orange hex plates on the shell, a big eye
SHELL = (f'<path d="{hexagon(80, 82, 18)} {hexagon(59, 106, 13)} {hexagon(101, 106, 13)}" fill="#FFA41C" '
         f'stroke="{INK}" stroke-width="7" stroke-linejoin="round"/><circle cx="152" cy="81" r="8" fill="{INK}"/>')
if R6["pad_slow"]:
    # r6: a taller dome filling ~65% of the disc, a low head on its own neck, two feet with a clear gap, and a
    # 3-cell honeycomb (pointy-top hexes sharing edges) of big orange plates on thick dark lines
    DOME = "M30,120 C30,56 52,36 78,36 C104,36 126,56 126,120 Z"
    TURTLE = (DOME + " M152,74 A16,16 0 1,1 151.9,74 Z M114,98 L144,80 L156,100 L122,116 Z "
              "M40,112 L64,112 L64,138 Q64,148 54,148 L50,148 Q40,148 40,138 Z "
              "M94,112 L118,112 L118,138 Q118,148 108,148 L104,148 Q94,148 94,138 Z")
    HR = 18
    hexp = lambda cx, cy: "M" + " L".join(f"{cx + HR * math.cos(math.radians(30 + 60 * i)):.1f},"
                                          f"{cy + HR * math.sin(math.radians(30 + 60 * i)):.1f}" for i in range(6)) + " Z"
    SHELL = (f'<path d="{hexp(78, 65)} {hexp(78 - HR * 0.866, 65 + HR * 1.5)} {hexp(78 + HR * 0.866, 65 + HR * 1.5)}" fill="#FFA41C" stroke="{INK}" stroke-width="9" '
             f'stroke-linejoin="round"/><circle cx="157" cy="86" r="7" fill="{INK}"/>')
if R7["pad_slow"]:
    # r7 (3 ADs: bigger, simpler, chunkier): the turtle spans the disc's width on its centre line: a tall dome, a
    # fat head clear of the shell on a short thick neck, two stubby feet with a wide gap, three big hex plates
    # (pointy-top honeycomb, r20) on thick dark seams with an even white margin
    TURTLE = ("M36,126 Q28,126 28,116 C28,64 46,36 75,36 C104,36 122,64 122,116 Q122,126 114,126 Z "
              "M153,81 A21,21 0 1,1 152.9,81 Z M112,106 L136,96 L144,118 L116,124 Z "
              "M44,116 L70,116 L70,142 Q70,152 60,152 L54,152 Q44,152 44,142 Z "
              "M88,116 L114,116 L114,142 Q114,152 104,152 L98,152 Q88,152 88,142 Z")
    HR = 20
    hexp = lambda cx, cy: "M" + " L".join(f"{cx + HR * math.cos(math.radians(30 + 60 * i)):.1f},"
                                          f"{cy + HR * math.sin(math.radians(30 + 60 * i)):.1f}" for i in range(6)) + " Z"
    SHELL = (f'<path d="{hexp(75, 66)} {hexp(75 - HR * 0.866, 66 + HR * 1.5)} {hexp(75 + HR * 0.866, 66 + HR * 1.5)}" '
             f'fill="#FFA41C" stroke="{INK}" stroke-width="12" stroke-linejoin="round"/>'
             f'<circle cx="160" cy="96" r="8" fill="{INK}"/>')
if R8["pad_slow"]:
    # r8 (3 ADs on r7): the whole turtle sits inside the disc with an even orange gap (r7 crowded the rim upper-left),
    # a bigger head (r24) clear of a rounder shell by a wider dark notch, a wider gap between the feet, the eye inside the head
    TURTLE = ("M42,120 Q34,120 34,110 C34,78 44,46 70,46 C96,46 106,78 106,110 Q106,120 98,120 Z "
              "M144,70 A24,24 0 1,1 143.9,70 Z M98,100 L130,98 L132,114 L100,118 Z "
              "M44,112 L62,112 L62,134 Q62,142 55,142 L51,142 Q44,142 44,134 Z "
              "M88,112 L106,112 L106,134 Q106,142 99,142 L95,142 Q88,142 88,134 Z")
    HR = 15
    hexp = lambda cx, cy: "M" + " L".join(f"{cx + HR * math.cos(math.radians(30 + 60 * i)):.1f},"
                                          f"{cy + HR * math.sin(math.radians(30 + 60 * i)):.1f}" for i in range(6)) + " Z"
    SHELL = (f'<path d="{hexp(70, 72)} {hexp(70 - HR * 0.866, 72 + HR * 1.5)} {hexp(70 + HR * 0.866, 72 + HR * 1.5)}" '
             f'fill="#FFA41C" stroke="{INK}" stroke-width="10" stroke-linejoin="round"/>'
             f'<circle cx="151" cy="88" r="7" fill="{INK}"/>')
# r9 c1: a snail facing right: a low foot rising into a neck, a big round white shell, a dark spiral, one eye
SNAIL_FOOT = "M44,122 L136,122 L136,92 A16,16 0 0,1 168,92 L168,138 Q168,152 154,152 L50,152 Q36,152 36,138 Q36,122 44,122 Z"
SNAIL = ('<g transform="translate(100,100) scale(0.92) translate(-100.5,-98.5)">' + icon(SNAIL_FOOT) + icon("M84,46 A44,44 0 1,1 83.9,46 Z")
         + f'<path d="M84,92 A9,9 0 1,1 102,92 A18,18 0 1,1 66,92 A27,27 0 1,1 120,92" fill="none" stroke="{INK}" '
         'stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/>' f'<circle cx="153" cy="96" r="7" fill="{INK}"/></g>')
if R10["polish"]:
    # r10 (3 ADs on c1): unscaled and bigger (shell r44), centred; a 1-turn spiral 1.5x thicker that runs into the
    # shell's outline; two long dark eye stalks with round ball tips on a lower head (all inside the disc's even gap)
    SNAIL = ('<g transform="translate(2,0)">' + icon("M60,126 L128,126 L128,100 A15,15 0 0,1 158,100 L158,132 Q158,154 136,154 L60,154 A14,14 0 0,1 60,126 Z")
             + icon("M80,44 A44,44 0 1,1 79.9,44 Z")
             + f'<path d="M76,84 A15,15 0 1,1 106,84 A31.5,31.5 0 1,1 43,84" fill="none" stroke="{INK}" stroke-width="18" '
             'stroke-linecap="round"/>'
             + f'<path d="M146,86 L147,48 M155,92 L164,71" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="10" fill="{INK}"/>' for x, y in ((147, 48), (164, 71))) + "</g>")
SLOW_DISC = ("#FFD84A", "#FF8C00", "#BF5A00")
if R11["pad_slow"]:
    # in-game r2 (judges on the phone HUD): a deeper amber disc so the white snail pops; a bigger shell, a simpler
    # 1.5-turn spiral as thick as the outline, short ball horns, all inside an even gap (max reach = Pad.brake's)
    SLOW_DISC = ("#FFC93A", "#FF7A00", "#B34A00")
    sx, sy, sr, a = 86, 90, 46, 8.5  # the shell circle; a = the spiral's step
    SNAIL = (icon("M68,128 L134,128 L134,106 A13,13 0 0,1 160,106 L160,118 Q152,145 120,152 L68,152 A12,12 0 0,1 68,128 Z")
             + icon(f"M{sx},{sy - sr} A{sr},{sr} 0 1,1 {sx - 0.1},{sy - sr} Z")
             + f'<path d="M{sx},{sy} A{a},{a} 0 0,1 {sx + 2 * a},{sy} A{2 * a},{2 * a} 0 0,1 {sx - 2 * a},{sy} '
             f'A{3 * a},{3 * a} 0 0,1 {sx + 4 * a},{sy}" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round"/>'
             + f'<path d="M146,98 L150,62 M157,100 L163,82" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="8" fill="{INK}"/>' for x, y in ((150, 62), (163, 82))))
if R12["pad_slow"]:
    # in-game r3: a yellow-amber disc (apart from the orange wildlife pin); the snail ~75% of the disc and centred, a
    # bigger head on a taller neck, longer thicker eye stalks with big ball tips, a thicker 1.5-turn spiral that runs
    # into the shell's outline (every point inside Pad.brake's reach)
    SLOW_DISC = ("#FFDC4A", "#FFA000", "#B86400")
    sx, sy, sr, a = 82, 98, 42, 12  # the shell circle; a = the spiral's step
    SNAIL = (icon("M48,126 L122,126 L122,100 A21,21 0 0,1 164,100 L164,118 Q158,150 128,154 L48,154 A14,14 0 0,1 48,126 Z")
             + icon(f"M{sx},{sy - sr} A{sr},{sr} 0 1,1 {sx - 0.1},{sy - sr} Z")
             + f'<path d="M{sx - a},{sy} A{a},{a} 0 0,1 {sx + a},{sy} A{2 * a},{2 * a} 0 0,1 {sx - 3 * a},{sy} '
             f'A{3 * a},{3 * a} 0 0,1 {sx + 3 * a},{sy}" fill="none" stroke="{INK}" stroke-width="16" stroke-linecap="round"/>'
             + f'<path d="M132,84 L118,50 M150,82 L148,58" stroke="{INK}" stroke-width="13" stroke-linecap="round"/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="12" fill="{INK}"/>' for x, y in ((118, 50), (148, 58))))
# one door slab with a knob, a fat arrow stepping out of it over its edge
DOOR = "M44,54 L100,54 L100,146 L44,146 Z"
DOOR_ARROW = "M82,82 L120,82 L120,54 L166,100 L120,146 L120,118 L82,118 Z"
KNOB = f'<circle cx="58" cy="102" r="8" fill="{INK}"/>'
# throttle: two fat forward chevrons stacked (go faster); brake: a stop octagon with a bar
GO = "M56,90 L100,46 L144,90 L144,120 L100,76 L56,120 Z M56,132 L100,88 L144,132 L144,162 L100,118 L56,162 Z"
GO_GLOSS = "M36,96 A64,64 0 0,1 50,62"
OCTAGON = "M123.7,42.7 L157.3,76.3 L157.3,123.7 L123.7,157.3 L76.3,157.3 L42.7,123.7 L42.7,76.3 L76.3,42.7 Z"
OCT_GLOSS = "M33.8,64.8 A75,75 0 0,1 64.8,33.8"
# rise: one fat up arrow, a wide short head (a base under it read as "upload")
LIFT_UP = "M100,36 L166,96 L126,96 L126,164 L74,164 L74,96 L34,96 Z"
TICK = (f'<path d="M54,104 L86,136 L148,70" fill="none" stroke="{INK}" stroke-width="54" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M54,104 L86,136 L148,70" fill="none" stroke="#fff" stroke-width="33" stroke-linecap="round" stroke-linejoin="round"/>')
LIFT_DOWN = "M100,128 L150,76 L122,76 L122,34 L78,34 L78,76 L50,76 Z M54,144 L146,144 L146,166 L54,166 Z"
STICKERS.update({
    "pad_left": (pad("#86CEFF", "#2A86E8", "#1A55A8", ARROW_LEFT), "touch drive pad: steer left (held = full lock)"),
    "pad_right": (pad("#86CEFF", "#2A86E8", "#1A55A8", ARROW_RIGHT), "touch drive pad: steer right"),
    "pad_go": (pad("#A4F57A", "#33BE4D", "#1F8A33", GO, gloss=GO_GLOSS), "touch drive pad: throttle, two fat forward chevrons"),
    "pad_brake": (pad("#FF8A7D", "#E0303A", "#A3161E", OCTAGON, gloss=OCT_GLOSS),
                  "touch drive pad: brake / reverse, one big white stop octagon"),
    "pad_slow": ((sticker(DISC, *SLOW_DISC, lip_dy=14, gloss=DISC_GLOSS, extra=SNAIL),
                  "touch drive pad: approach (slow helm), a snail: the slow animal, one fat spiral") if R10["c1"] else
                 (pad("#FFD84A", "#FF8C00", "#BF5A00", TURTLE, SHELL), "touch drive pad: approach (slow helm), a turtle")),
    "pad_exit": (sticker(DISC, "#DCD0FF", "#8A66F0", "#4E36A8", lip_dy=14, gloss=DISC_GLOSS,
                         extra=icon(DOOR, KNOB) + icon(DOOR_ARROW)),
                 "touch drive pad: step off, a door and a big arrow out"),
    "pad_up": (pad("#7FF0E2", "#1FB3A6", "#13776E", LIFT_UP), "touch drive pad: climb / rise (heli, sub), off a Lego brick"),
    "check": (sticker(DISC, "#A4F57A", "#33BE4D", "#156B26", lip_dy=14, gloss=DISC_GLOSS, extra=TICK),
              "the kit's tick (owned, maxed, preset on): a green round sticker, fat white tick"),
    "pad_down": (pad("#7FF0E2", "#1FB3A6", "#13776E", LIFT_DOWN), "touch drive pad: descend / dive (heli, sub)"),
})


def render(name, w, h, keep=False):
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(SRC / f"{name}.svg"),
                    str(OUT / f"{name}.png"), "--size", str(w), str(h)] + (["--keep"] if keep else []), check=True)


# square slots: a square box round the art's centre, rendered whole
SQUARE = {"chat": (-22, -9, 244, 244), "check": (-22, -15, 244, 244)}
OUT.mkdir(parents=True, exist_ok=True)
for name, (layers, note) in STICKERS.items():
    box = SQUARE.get(name, (-22, -22, 244, 256))
    svg(name, layers, box=box, note=note)
    render(name, box[2], box[3], keep=name == "map_player" or name in SQUARE)
# beacon_mark.svg, tap.svg are hand-authored; transport_pin.svg comes from pin_variants.py
