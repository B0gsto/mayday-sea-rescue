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
GOLD = ("#FFE45C", "#FFAE00", "#FFF4A8", "#FFC72E", "#A85600")  # a clear gold, deep orange lip
# day 7, still ahead/today: a bigger star with a white rim of its own (its rim reads on gold and purple)
BIG_STAR = ('<g transform="translate(80,74) scale(1.3) translate(-80,-73)">'
            + "".join(STAR.replace('fill="url(#gStar)" stroke="#14121C" stroke-width="7"', a) for a in (
                'fill="#fff" stroke="#fff" stroke-width="14"', 'fill="url(#gStarP)" stroke="#14121C" stroke-width="7"'))
            + '</g><linearGradient id="gStarP" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#EBD8FF"/>'
            '<stop offset="1" stop-color="#8445F5"/></linearGradient>')
PIPS = {
    "Done": (TEMPLATE, None),
    "Today": (GOLD, ""),
    "Next": (("#A3AEC6", "#56617C", "#C4CCDD", "#76819C", "#2C3246"), ""),  # darker steel, strong lip
    "Seven": (("#CDA4FF", "#8445F5", "#E4CCFF", "#9C64FA", "#5A2BB0"), STAR.replace('stroke-width="7"', 'stroke-width="9"')),
    "SevenToday": (GOLD, BIG_STAR),
}

src = (ROOT / "art/source/ui/streak_pip.svg").read_text()
assert all(c in src for c in TEMPLATE) and "<!--MARK-->" in src, "the template colours or mark moved"
OUT.mkdir(parents=True, exist_ok=True)
for name, (colours, mark) in PIPS.items():
    svg = src
    for old, new in zip(TEMPLATE, colours):
        svg = svg.replace(old, new)
    if mark is not None:
        svg = re.sub(r"<!--MARK-->.*<!--/MARK-->", lambda _: mark, svg, flags=re.S)
    if mark == "":  # the day-number pips: a solid stud ring so the face reads as a Lego stud under the number
        svg = svg.replace('stroke="#14121C" stroke-opacity="0.3" stroke-width="3"', f'stroke="{colours[4]}" stroke-width="6"')
    path = OUT / f"pip_{name}.svg"
    path.write_text(svg)
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(path), str(OUT / f"pip_{name}.png"),
                    "--size", "200", "200"], check=True)
