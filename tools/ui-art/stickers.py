#!/usr/bin/env python3
"""The small UI-kit stickers (uia2, CLAUDE.md "UI art"): one shape each, drawn in the build arrow's layers (white
sticker rim, hard dark outline, darker lip under a bold gradient, a soft gloss stroke). Writes the SVG sources to
art/source/ui/<name>.svg and renders build/ui-art/<name>.png (2x).   usage: python3 tools/ui-art/stickers.py
Rotating sprites (the map arrow) have no lip and keep their box (--keep) so the game spins them about its centre."""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC, OUT = ROOT / "art/source/ui", ROOT / "build/ui-art"
INK = "#14121C"

STAR = "M100,18 L122,72 L180,76 L135,113 L150,170 L100,138 L50,170 L65,113 L20,76 L78,72 Z"
HEART = "M100,176 C40,132 18,104 18,72 C18,44 40,26 64,26 C82,26 94,36 100,50 C106,36 118,26 136,26 C160,26 182,44 182,72 C182,104 160,132 100,176 Z"
ARROW = "M100,14 L170,178 Q172,184 166,181 L100,142 L34,181 Q28,184 30,178 Z"
STUD = "M100,30 A70,70 0 1,1 99.9,30 Z"
# a crosshair: a thick ring and four fat arms round an open centre (the map arrow shows through it when they stack);
# the two ring circles wind opposite ways so the middle stays hollow
CROSS = ("M86,8 L114,8 L114,58 L86,58 Z M86,142 L114,142 L114,192 L86,192 Z M8,86 L58,86 L58,114 L8,114 Z "
         "M142,86 L192,86 L192,114 L142,114 Z M100,26 A74,74 0 1,1 99.9,26 Z M99.9,48 A52,52 0 1,0 100,48 Z")
CROSS_GLOSS = ('<path d="M40,72 A64,64 0 0,1 72,40 M94,16 L94,40" fill="none" stroke="#fff" stroke-opacity="0.7" '
               'stroke-width="9" stroke-linecap="round"/>')
# a speech bubble, tail down-left; three chunky stud dots
CHAT_DOTS = "".join(f'<circle cx="{x}" cy="87" r="15" fill="#fff" stroke="{INK}" stroke-width="7"/>'
                    f'<path d="M{x - 8},84 A9,9 0 0,1 {x - 2},78" fill="none" stroke="#9FCBEF" stroke-width="5" stroke-linecap="round"/>'
                    for x in (56, 100, 144))
CHAT = "M40,30 L160,30 Q186,30 186,56 L186,118 Q186,144 160,144 L92,144 L56,176 Q50,181 51,173 L58,144 L40,144 Q14,144 14,118 L14,56 Q14,30 40,30 Z"


def stud_top(light, mid, dark):
    """a Lego stud's flat top: a raised disc (bright top to its own shade) inside a dark ring, a bright gloss arc"""
    return (f'<linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{light}"/>'
            f'<stop offset="1" stop-color="{mid}"/></linearGradient>'
            f'<circle cx="100" cy="100" r="46" fill="url(#s)" stroke="{dark}" stroke-width="8"/>'
            '<path d="M70,90 A32,32 0 0,1 92,66" fill="none" stroke="#fff" stroke-opacity="0.9" stroke-width="10" stroke-linecap="round"/>')


BODY_GLOSS = "M44,82 A58,58 0 0,1 80,44"
# the empty socket: a sunken hole (dark top, lighter floor) in a pale ring, so it reads hollow on any panel
SOCKET = ('<linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3F475A"/>'
          '<stop offset="1" stop-color="#7C879C"/></linearGradient>'
          f'<circle cx="100" cy="100" r="44" fill="#E4EAF3" stroke="{INK}" stroke-width="8"/>'
          f'<circle cx="100" cy="100" r="30" fill="url(#s)" stroke="{INK}" stroke-width="7"/>')


def sticker(d, top, bottom, lip, lip_dy=12, gloss=None, extra=""):
    """d: the shape; top/bottom: its gradient; lip: the shade under it, lip_dy units down (0: none)."""
    g = f'<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>'
    shift = [0, lip_dy] if lip_dy else [0]
    p = lambda fill, stroke="", w=0, dy=0: (f'<path d="{d}" transform="translate(0,{dy})" fill="{fill}"'
                                            + (f' stroke="{stroke}" stroke-width="{w}" stroke-linejoin="round"' if w else "") + "/>")
    layers = "".join(p("#fff", "#fff", 30, dy) for dy in shift) + "".join(p(INK, INK, 12, dy) for dy in shift)
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
    "star_off": (sticker(STAR, "#D6E0EE", "#8696B4", "#4A5872", lip_dy=14,
                         extra='<path d="M58,84 L84,82 L95,52" fill="none" stroke="#fff" stroke-opacity="0.95" '
                               'stroke-width="11" stroke-linecap="round" stroke-linejoin="round"/>'),
                 "a level not built yet: the same star in cool pale slate"),
    "heart": (sticker(HEART, "#FF9AAA", "#EE3D57", "#8E1428", lip_dy=16, gloss="M40,66 C40,52 52,44 64,44"),
              "the companion's love hearts (a pat, a treat)"),
    "pip_on": (sticker(STUD, "#8BEA7A", "#2FA84A", "#145C24", lip_dy=16, extra=stud_top("#E4FFD2", "#6FD866", "#1A6E2E")),
               "a filled seat on your craft: a green Lego stud (flat top, raised ring, side lip)"),
    "pip_full": (sticker(STUD, "#FF8A7A", "#E2333A", "#6E0C12", lip_dy=16, extra=stud_top("#FFE2DC", "#FF7D70", "#A3161E")),
                 "every seat filled: the studs turn red"),
    "pip_off": (sticker(STUD, "#C9D2E0", "#8D99AF", "#55607A", lip_dy=16, gloss=BODY_GLOSS, extra=SOCKET),
                "an empty seat: a hollow slate socket"),
    "map_cross": (sticker(CROSS, "#FFE45C", "#FFAE00", "#C27400", lip_dy=10, extra=CROSS_GLOSS),
                  "the full map's gamepad crosshair: one ring-and-arms piece, open centre"),
    "map_player": (sticker(ARROW, "#8EE0FF", "#1450B8", None, lip_dy=0,
                           extra='<path d="M100,30 L100,136 L42,170 Z" fill="#fff" fill-opacity="0.35"/>'
                                 '<path d="M100,30 L158,170 L100,136 Z" fill="#0E3A85" fill-opacity="0.45"/>'),
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


def pad(top, bottom, lip, d, extra=""):
    return sticker(DISC, top, bottom, lip, lip_dy=14, gloss=DISC_GLOSS, extra=icon(d, extra))


ARROW_LEFT = "M38,100 L94,48 L94,78 L158,78 L158,122 L94,122 L94,152 Z"
ARROW_RIGHT = "M162,100 L106,48 L106,78 L42,78 L42,122 L106,122 L106,152 Z"
# a turtle seen side-on, facing right: shell dome, a big round head, two feet
TURTLE = ("M32,124 Q34,54 84,52 Q134,54 136,124 Z M154,74 A22,22 0 1,1 153.9,74 Z M130,104 L150,104 L150,124 L130,124 Z "
          "M46,120 L72,120 L72,146 Q72,152 66,152 L52,152 Q46,152 46,146 Z "
          "M96,120 L122,120 L122,146 Q122,152 116,152 L102,152 Q96,152 96,146 Z")
# three bold shell segments over a rim line, and a big eye
SHELL = (f'<path d="M40,112 L128,112 M64,112 L68,70 M102,112 L100,64" fill="none" stroke="{INK}" stroke-width="10" '
         f'stroke-linecap="round"/><circle cx="160" cy="91" r="7.5" fill="{INK}"/>')
# a door with a fat arrow stepping out of it
DOOR = "M50,40 L112,40 L112,160 L50,160 Z"
DOOR_ARROW = "M88,80 L126,80 L126,50 L176,100 L126,150 L126,120 L88,120 Z"
DOORWAY = f'<path d="M58,52 L98,52 L98,150 L58,150 Z" fill="#3B2680" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
# throttle: two fat forward chevrons stacked (go faster); brake: a stop octagon with a bar
GO = ("M54,86 L100,40 L146,86 L146,114 L100,68 L54,114 Z M54,132 L100,86 L146,132 L146,160 L100,114 L54,160 Z")
OCTAGON = "M124.6,40.4 L159.6,75.4 L159.6,124.6 L124.6,159.6 L75.4,159.6 L40.4,124.6 L40.4,75.4 L75.4,40.4 Z"
STOP_BAR = f'<path d="M62,86 L138,86 L138,114 L62,114 Z" fill="#E0303A" stroke="{INK}" stroke-width="8" stroke-linejoin="round"/>'
LIFT_UP_BOLD = "M100,26 L162,92 L126,92 L126,170 L74,170 L74,92 L38,92 Z"
TICK = (f'<path d="M54,104 L86,136 L148,70" fill="none" stroke="{INK}" stroke-width="48" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M54,104 L86,136 L148,70" fill="none" stroke="#fff" stroke-width="27" stroke-linecap="round" stroke-linejoin="round"/>')
LIFT_DOWN = "M100,128 L150,76 L122,76 L122,34 L78,34 L78,76 L50,76 Z M54,144 L146,144 L146,166 L54,166 Z"
STICKERS.update({
    "pad_left": (pad("#86CEFF", "#2A86E8", "#1A55A8", ARROW_LEFT), "touch drive pad: steer left (held = full lock)"),
    "pad_right": (pad("#86CEFF", "#2A86E8", "#1A55A8", ARROW_RIGHT), "touch drive pad: steer right"),
    "pad_go": (pad("#A4F57A", "#33BE4D", "#1F8A33", GO), "touch drive pad: throttle, two fat forward chevrons"),
    "pad_brake": (pad("#FF8A7D", "#E0303A", "#A3161E", OCTAGON, STOP_BAR),
                  "touch drive pad: brake / reverse, a stop octagon with a bar"),
    "pad_slow": (pad("#FFE873", "#FFB000", "#C27400", TURTLE, SHELL), "touch drive pad: approach (slow helm), a turtle"),
    "pad_exit": (sticker(DISC, "#C3B1FF", "#7A5CE0", "#4E36A8", lip_dy=14, gloss=DISC_GLOSS,
                         extra=icon(DOOR) + DOORWAY + icon(DOOR_ARROW)),
                 "touch drive pad: step off, an open doorway and an arrow out"),
    "pad_up": (pad("#7FF0E2", "#1FB3A6", "#13776E", LIFT_UP_BOLD), "touch drive pad: climb / rise (heli, sub)"),
    "check": (sticker(DISC, "#A4F57A", "#33BE4D", "#1F8A33", lip_dy=14, gloss=DISC_GLOSS, extra=TICK),
              "the kit's tick (owned, maxed, preset on): a green round sticker, fat white tick"),
    "pad_down": (pad("#7FF0E2", "#1FB3A6", "#13776E", LIFT_DOWN), "touch drive pad: descend / dive (heli, sub)"),
})


def render(name, w, h, keep=False):
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(SRC / f"{name}.svg"),
                    str(OUT / f"{name}.png"), "--size", str(w), str(h)] + (["--keep"] if keep else []), check=True)


# square slots: a square box round the art's centre, rendered whole (map_cross: centred on its open middle)
SQUARE = {"chat": (-22, -9, 244, 244), "map_cross": (-22, -22, 244, 244), "check": (-22, -15, 244, 244)}
OUT.mkdir(parents=True, exist_ok=True)
for name, (layers, note) in STICKERS.items():
    box = SQUARE.get(name, (-22, -22, 244, 256))
    svg(name, layers, box=box, note=note)
    render(name, box[2], box[3], keep=name == "map_player" or name in SQUARE)
# beacon_mark.svg, tap.svg are hand-authored; transport_pin.svg comes from pin_variants.py
