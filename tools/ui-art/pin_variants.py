#!/usr/bin/env python3
"""The waypoint pin in each of its colours (UI/Waypoint: one pin colour per goal kind): swaps the red variant's
three colours in art/source/ui/waypoint_pin.svg and renders build/ui-art/pin_<Name>.png (2x, untrimmed: the game
spins the pin about the box centre).   usage: python3 tools/ui-art/pin_variants.py"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "ui-art"
# UI/Waypoint's colours: RED, AMBER, GREEN (home), CRAFT, QUEST, BEAM
PINS = {"Red": "E8332A", "Amber": "FFB020", "Green": "2FA866", "Craft": "2C8EF0", "Quest": "FFC428", "Beam": "FF6A3D"}


def mix(hex_, k, toward=0):  # k of the way toward white (toward=255) or a plain scale (toward=0)
    c = [int(hex_[i:i + 2], 16) for i in (0, 2, 4)]
    return "".join("%02X" % round(v + (toward - v) * k if toward else v * k) for v in c)


src = (ROOT / "art/source/ui/waypoint_pin.svg").read_text()
assert all(c in src for c in ("#FF7A6B", "#D9202A", "#A3161E")), "the red template colours moved"
OUT.mkdir(parents=True, exist_ok=True)
for name, base in PINS.items():
    svg = OUT / f"pin_{name}.svg"
    svg.write_text(src.replace("#FF7A6B", "#" + mix(base, 0.4, 255)).replace("#D9202A", "#" + mix(base, 0.93))
                   .replace("#A3161E", "#" + mix(base, 0.7)))
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(svg), str(OUT / f"pin_{name}.png"),
                    "--size", "324", "324", "--keep"], check=True)
