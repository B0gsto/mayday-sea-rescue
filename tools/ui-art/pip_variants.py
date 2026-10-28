#!/usr/bin/env python3
"""The streak strip's day pips (UI/RewardPrompt): recolours the green "done" template art/source/ui/streak_pip.svg
and swaps its mark, then renders build/ui-art/pip_<Name>.png (2x, trimmed). Today and the days ahead carry no
mark: the game draws the day number on the stud.   usage: python3 tools/ui-art/pip_variants.py"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "ui-art"
TEMPLATE = ("#A4F57A", "#33BE4D", "#C8FFA6", "#4FD067", "#1F8A33")  # face top/bottom, stud top/bottom, lip
STAR = ('<g><path d="M80,44 L89.4,63 L110.4,66.1 L95.2,80.9 L98.8,101.8 L80,92 L61.2,101.8 L64.8,80.9 L49.6,66.1 '
        'L70.6,63 Z" fill="url(#gStar)" stroke="#14121C" stroke-width="7" stroke-linejoin="round"/></g>')
PIPS = {
    "Done": (TEMPLATE, None),
    "Today": (("#FFEA6B", "#FFB81E", "#FFF7B8", "#FFCF3A", "#B8730A"), ""),
    "Next": (("#C3CBE0", "#7A83A0", "#DDE2F0", "#9198B4", "#4A5068"), ""),
    "Seven": (("#CDA4FF", "#8445F5", "#E4CCFF", "#9C64FA", "#5A2BB0"), STAR),
    "SevenToday": (("#FFEA6B", "#FFB81E", "#FFF7B8", "#FFCF3A", "#B8730A"), STAR.replace("url(#gStar)", "#9C64FA")),
}

src = (ROOT / "art/source/ui/streak_pip.svg").read_text()
assert all(c in src for c in TEMPLATE) and "<!--MARK-->" in src, "the template colours or mark moved"
OUT.mkdir(parents=True, exist_ok=True)
for name, (colours, mark) in PIPS.items():
    svg = src
    for old, new in zip(TEMPLATE, colours):
        svg = svg.replace(old, new)
    if mark is not None:
        svg = re.sub(r"<!--MARK-->.*<!--/MARK-->", mark, svg, flags=re.S)
    path = OUT / f"pip_{name}.svg"
    path.write_text(svg)
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(path), str(OUT / f"pip_{name}.png"),
                    "--size", "200", "200"], check=True)
