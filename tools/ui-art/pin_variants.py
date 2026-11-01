#!/usr/bin/env python3
"""The waypoint pin in each of its colours (UI/Waypoint: one pin colour per goal kind): swaps the red variant's
three colours in art/source/ui/waypoint_pin.svg and renders build/ui-art/pin_<Name>.png (2x, untrimmed: the game
spins the pin about the box centre). The pins carry no mark (the game draws the call icon live on the disc).
(The drop-off pad's art/source/ui/transport_pin.svg stays hand SVG: its pre-pass art scored best.)   usage: python3 tools/ui-art/pin_variants.py"""
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
    svg = OUT / f"pin_{name}.svg"
    svg.write_text(recolour(pin, colours).replace("<!--RING-->", RING.get(name, "")))
    render(svg, OUT / f"pin_{name}.png", "--keep")
