#!/usr/bin/env python3
"""The waypoint pin in each of its colours (UI/Waypoint: one pin colour per goal kind): swaps the red variant's
three colours in art/source/ui/waypoint_pin.svg and renders build/ui-art/pin_<Name>.png (2x, untrimmed: the game
spins the pin about the box centre). The pins carry no mark (the game draws the call icon live on the disc).
(The drop-off pad's art/source/ui/transport_pin.svg stays hand SVG: its pre-pass art scored best.)   usage: python3 tools/ui-art/pin_variants.py"""
import math
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "ui-art"
TEMPLATE = ("#FF8A7A", "#E2333A", "#A8121A", "#EA3A40", "#B8121C", "#C5222A")  # body top, bottom, lip, disc top,
# bottom, tail tip (red); the tail tip is computed: halfway from body bottom to lip, so the point reads darker at 1x
# UI/Waypoint's colours (RED, AMBER, GREEN home, CRAFT, QUEST, BEAM), Lego-bright and six clear hues at 1x: red,
# true orange, green, blue, lemon yellow, coral; each disc is a clean tone of its body's hue, deep at the bottom
# so the game's white call icon keeps contrast (Quest's disc goes gold-to-amber under its lemon body).
PINS = {
    "Red": (*TEMPLATE[:4], "#C4161E"),  # r3's disc bottom
    "Amber": ("#FFA868", "#F06A10", "#9E3A00", "#D85A06", "#B84400"),  # red-orange, never next to Quest's gold
    "Green": ("#B4F78A", "#2FB94A", "#16752A", "#30B84C", "#15842C"),
    "Craft": ("#9AB0FF", "#2A52E6", "#18309E", "#4468F0", "#1C3AC0"),  # cobalt, apart from the sea and MapPlayer
    "Quest": ("#FFF59A", "#FFD000", "#A87800", "#E6A200", "#C88200"),  # deep-gold disc under the white call icon
    "Beam": ("#FFB8A0", "#FF6A3D", "#A8341A", "#FF7048", "#D4441C"),  # the game's BEAM coral FF6A3D
}
# r10: c2 = round 9's winning concept (wildlife: true orange with three paw toes over the head; Beam: violet),
# polish = the judges' fixes on c2 (bigger, thicker-outlined toes off the rim; Beam warmer/lighter; orange a hair redder)
# c2 False = the old Amber/Beam; polish False = c2 exactly
R10 = {"c2": True, "polish": False}
if R10["c2"]:
    PINS["Amber"] = ("#FFBB7A", "#FF7200", "#A04000", "#EC6200", "#BC4500") if R10["polish"] else \
        ("#FFC27A", "#FF7F00", "#A04800", "#EC6E00", "#BC4E00")  # polish: c2 hue -3 deg
    PINS["Beam"] = ("#E3C5FF", "#B058F3", "#6522A9", "#A450EE", "#7A2AC8") if R10["polish"] else \
        ("#D6B8FF", "#9A4CF2", "#52209E", "#9450EE", "#6A2AC8")  # polish: c2 hue +6 deg, body lightness +0.025


def toes(r, d, deg=40):
    """three paw toes of radius r on a ring of radius d about the head centre (100,88): top and deg either side"""
    sn, cs = round(math.sin(math.radians(deg)), 4), round(math.cos(math.radians(deg)), 4)
    pts = ((100 + d * s, 88 - d * c) for s, c in ((0, 1), (-sn, cs), (sn, cs)))
    return " ".join(f"M{x - r:.1f},{y:g} A{r:g},{r:g} 0 1,1 {x + r:.1f},{y:g} A{r:g},{r:g} 0 1,1 {x - r:.1f},{y:g} Z"
                    for x, y in ((round(x, 1), round(y, 1)) for x, y in pts))


# per pin: an extra silhouette drawn in every pin layer (path d, its lip drop, its dark outline width)
EXTRA = {"Amber": (toes(18.4, 120), 4, 22) if R10["polish"] else (toes(16, 100), 4, 18)} if R10["c2"] else {}
# r11 in-game judges (Pin.Amber 8.5): the toes read as ears and the live white paw is small. paw: bigger toes with a
# thicker outline and ~5 units of white between them and the head (lip 3), the orange inner disc r 42 -> 46 so the
# bigger paw glyph (Waypoint icon 0.64) clears the white ring. False = r10 pixel-identical
R11 = {"paw": True}
if R11["paw"] and R10["c2"]:
    EXTRA["Amber"] = (toes(19, 120, 38), 3, 24)
DISC = {"Amber": 46} if R11["paw"] else {}
# in-game r3 (judges: toes float like an ellipsis, the dark disc doubles the paw): toes: the 3 toes pulled in so their
# outlines touch the head (one silhouette, one shared white rim, a dark seam between); disc: a plain flat bright
# orange inner disc (no dark gradient; the game's white paw needs some contrast, so not cream). False = r2 pixel-identical
R12 = {"toes": True, "disc": True}
if R12["toes"] and R10["c2"]:
    EXTRA["Amber"] = (toes(20, 98, 40), 3, 24)
if R12["disc"] and R10["c2"]:
    PINS["Amber"] = (*PINS["Amber"][:3], "#FF8C1A", "#FF8C1A")
RING = {"Quest": '<circle cx="100" cy="88" r="39.5" fill="none" stroke="#9C5E00" stroke-width="5"/>'}
# Beam's r4 render scored 9.1 on the older template (narrower tip, thinner outline, gloss stroke): keep it pixel-identical
OLD_TEMPLATE = {
    "M54.8,144.04 A72,72 0 1,1 145.2,144.04 L111.5,200 Q100,217 88.5,200 Z":
        "M58.9,147.1 A72,72 0 1,1 141.1,147.1 L110,200 Q100,216 90,200 Z",
    'stroke-width="36"': 'stroke-width="30"',
    'stroke-width="18"': 'stroke-width="12"',
    '<path d="M34.75,93.71 A55.53,55.53 0 0,1 83.05,24.73 A83.94,83.94 0 0,0 34.75,93.71 Z" fill="#fff" fill-opacity="0.95"'
    ' stroke="#fff" stroke-opacity="0.95" stroke-width="2" stroke-linejoin="round"/>':
        '<path d="M34.75,93.71 A65.5,65.5 0 0,1 83.05,24.73" fill="none" stroke="#fff" stroke-opacity="0.95"'
        ' stroke-width="11" stroke-linecap="round"/>',
}
# Red's r3 render scored 9.1 on the oldest template (one-stop body gradient, wider white disc, thin gloss, no sparkle):
# applied on top of OLD_TEMPLATE, keeps it pixel-identical
R3_TEMPLATE = {
    '<stop offset="0.72" stop-color="#E2333A"/><stop offset="1" stop-color="#C5222A"/>': '<stop offset="1" stop-color="#E2333A"/>',
    'r="56" fill="url(#gW)"': 'r="57" fill="url(#gW)"',
    '<path d="M34.75,93.71 A65.5,65.5 0 0,1 83.05,24.73" fill="none" stroke="#fff" stroke-opacity="0.95"'
    ' stroke-width="11" stroke-linecap="round"/><circle cx="104.57" cy="22.66" r="5.5" fill="#fff" fill-opacity="0.95"/>':
        '<path d="M35.25,93.67 A65,65 0 0,1 83.18,25.21" fill="none" stroke="#fff" stroke-opacity="0.85"'
        ' stroke-width="9" stroke-linecap="round"/>',
}
OLD_PINS = {"Beam", "Red"}
R3_PINS = {"Red"}


def tail(bottom, lip):
    return "#" + "".join(f"{(int(bottom[i:i + 2], 16) + int(lip[i:i + 2], 16)) // 2:02X}" for i in (1, 3, 5))


assert tail(TEMPLATE[1], TEMPLATE[2]) == TEMPLATE[5]


def recolour(src, colours, mark=""):
    for old, new in zip(TEMPLATE, (*colours, tail(colours[1], colours[2]))):
        src = src.replace(old, new)
    return re.sub(r"<!--MARK-->.*<!--/MARK-->", mark, src, flags=re.S)


def add_extra(svg, d, dy, outline):
    """draw silhouette d right after each of the body's layers: white rim, dark outline, lip, gradient body"""
    body = re.escape(re.search(r'<path d="([^"]+)"', svg)[1])
    for fill, w in (("#fff", outline + 18), ("#14121C", outline)):  # the rim stays 9 wide around the outline
        m = re.search(f'<path d="{body}" transform="translate\\(0,14\\)" fill="{fill}" [^>]*/>', svg)
        attrs = f'fill="{fill}" stroke="{fill}" stroke-width="{w}" stroke-linejoin="round"'
        svg = svg[:m.end()] + f'<path d="{d}" {attrs}/><path d="{d}" transform="translate(0,{dy})" {attrs}/>' + svg[m.end():]
    m = re.search(f'<path d="{body}" transform="translate\\(0,14\\)" fill="(#[0-9A-F]{{6}})"/>', svg)
    svg = svg[:m.end()] + f'<path d="{d}" transform="translate(0,{dy})" fill="{m[1]}"/>' + svg[m.end():]
    m = re.search(f'<path d="{body}" fill="url\\(#gP\\)"/>', svg)
    return svg[:m.end()] + f'<path d="{d}" fill="url(#gP)"/>' + svg[m.end():]


def render(svg, png, *extra):
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(svg), str(png),
                    "--size", "324", "324", *extra], check=True)


src = (ROOT / "art/source/ui/waypoint_pin.svg").read_text()
assert all(c in src for c in TEMPLATE) and "<!--MARK-->" in src, "the red template colours or the mark slot moved"
OUT.mkdir(parents=True, exist_ok=True)
assert all(k in src for k in OLD_TEMPLATE) and "<!--RING-->" in src, "the template's switchable parts moved"
for name, colours in PINS.items():
    pin = src
    if name in OLD_PINS:
        for new, old in OLD_TEMPLATE.items():
            pin = pin.replace(new, old)
    if name in R3_PINS:
        for new, old in R3_TEMPLATE.items():
            assert new in pin, new
            pin = pin.replace(new, old)
    if name in DISC:
        pin = pin.replace('r="42" fill="url(#gI)"', f'r="{DISC[name]}" fill="url(#gI)"')
    svg = OUT / f"pin_{name}.svg"
    pin = recolour(pin, colours).replace("<!--RING-->", RING.get(name, ""))
    svg.write_text(add_extra(pin, *EXTRA[name]) if name in EXTRA else pin)
    render(svg, OUT / f"pin_{name}.png", "--keep")
