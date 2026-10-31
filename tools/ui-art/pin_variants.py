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
TEMPLATE = ("#FF8A7A", "#E2333A", "#A8121A", "#EA3A40", "#C4161E")  # body top, bottom, lip, disc top, bottom (red)
# UI/Waypoint's colours (RED, AMBER, GREEN home, CRAFT, QUEST, BEAM), Lego-bright and six clear hues at 1x: red,
# orange, green, blue, true yellow, hot pink; each disc is a clean lively tone of its body's hue (never maroon/mud).
PINS = {
    "Red": TEMPLATE,
    "Amber": ("#FFC266", "#FF8200", "#A84600", "#FA9C14", "#E67A00"),
    "Green": ("#B4F78A", "#2FB94A", "#16752A", "#30B84C", "#1A9434"),
    "Craft": ("#8EB8FF", "#2463E8", "#123C9E", "#3C78F0", "#1F56D6"),
    "Quest": ("#FFF59A", "#FFD000", "#A87800", "#FFC61A", "#ECA600"),
    "Beam": ("#FFA8C4", "#FF3A7C", "#A8104C", "#FF4E86", "#E0246A"),
}


def recolour(src, colours, mark=""):
    for old, new in zip(TEMPLATE, colours):
        src = src.replace(old, new)
    return re.sub(r"<!--MARK-->.*<!--/MARK-->", mark, src, flags=re.S)


def render(svg, png, *extra):
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(svg), str(png),
                    "--size", "324", "324", *extra], check=True)


src = (ROOT / "art/source/ui/waypoint_pin.svg").read_text()
assert all(c in src for c in TEMPLATE) and "<!--MARK-->" in src, "the red template colours or the mark slot moved"
OUT.mkdir(parents=True, exist_ok=True)
for name, colours in PINS.items():
    svg = OUT / f"pin_{name}.svg"
    svg.write_text(recolour(src, colours))
    render(svg, OUT / f"pin_{name}.png", "--keep")
