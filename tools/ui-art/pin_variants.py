#!/usr/bin/env python3
"""The waypoint pin in each of its colours (UI/Waypoint: one pin colour per goal kind): swaps the red variant's
three colours in art/source/ui/waypoint_pin.svg and renders build/ui-art/pin_<Name>.png (2x, untrimmed: the game
spins the pin about the box centre). The pins carry no mark (the game draws the call icon live on the disc);
the drop-off pad's pin (transport.luau) is the same pin in rescue blue with a white cross, written to
art/source/ui/transport_pin.svg and rendered 3x, trimmed.   usage: python3 tools/ui-art/pin_variants.py"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "ui-art"
TEMPLATE = ("#FF8A7A", "#E2333A", "#A3161E")  # gradient top, bottom, lip (the red pin)
# UI/Waypoint's colours (RED, AMBER, GREEN home, CRAFT, QUEST, BEAM), Lego-bright: top, bottom, lip
PINS = {
    "Red": TEMPLATE,
    "Amber": ("#FFCB52", "#FF9A00", "#B05A00"),
    "Green": ("#A4F57A", "#33BE4D", "#1F8A33"),
    "Craft": ("#7CC8FF", "#1F7FE6", "#134A9C"),
    "Quest": ("#FFE45C", "#FFAE00", "#C27400"),
    "Beam": ("#FFA27A", "#FF5A26", "#B33A0E"),
}
CROSS = ('<path d="M87,54 L113,54 L113,75 L134,75 L134,101 L113,101 L113,122 L87,122 L87,101 L66,101 L66,75 L87,75 Z"'
         ' fill="#fff" stroke="#14121C" stroke-width="8" stroke-linejoin="round"/>')


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
transport = ROOT / "art/source/ui/transport_pin.svg"
transport.write_text(recolour(src, ("#7CC2FF", "#2A7FE6", "#1A55A8"), CROSS)
                     .replace("so the pins carry no mark", "this one carries a white cross (the drop-off pad)"))
render(transport, OUT / "transport_pin.png", "--scale", "3")
