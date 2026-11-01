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
# day 7: one star size for both day-7 pips (scaled about the stud), heavy ink so it reads at 1x
def big(star: str, k: float = 1.2) -> str:
    return f'<g transform="translate(80,74) scale({k}) translate(-80,-74)">{star}</g>'

SEVEN_STAR = big(STAR.replace('stroke-width="7"', 'stroke-width="8.5"'))
# day 7 today: a larger, lighter purple star on gold, with a white rim of its own (it reads on gold and purple)
BIG_STAR = (big("".join(STAR.replace('fill="url(#gStar)" stroke="#14121C" stroke-width="7"', a) for a in (
                'fill="#fff" stroke="#fff" stroke-width="13"', 'fill="url(#gStarP)" stroke="#14121C" stroke-width="8"')), 1.4)
            + '<linearGradient id="gStarP" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#F6EDFF"/>'
            '<stop offset="0.45" stop-color="#C79BFF"/><stop offset="1" stop-color="#9152FF"/></linearGradient>')
FACE = '<circle cx="80" cy="76" r="62" fill="url(#gF)"/>'
def edge(colour: str, w: int = 7) -> dict:  # a coin-edge shade on the lower face, between the stud and the rim
    return {FACE: FACE + f'<path d="M133.1,90.2 A55,55 0 0,1 48.5,121.1" fill="none" stroke="{colour}" '
                         f'stroke-width="{w}" stroke-linecap="round"/>'}
# the day-number well: a deeper stud shadow so the stud under the number reads at 1x
WELL = {'<circle cx="80" cy="81" r="39" fill="#1F8A33" fill-opacity="0.55"/>':
        '<circle cx="80" cy="83" r="41" fill="#1F8A33" fill-opacity="0.9"/>'}
# the gold "today" pips: a stronger face and stud gloss so today pops from the row
GLOSS = {'stroke-opacity="0.55" stroke-width="9"': 'stroke-opacity="0.85" stroke-width="11"',
         'stroke-opacity="0.7" stroke-width="7"': 'stroke-opacity="0.95" stroke-width="9"'}
PIPS = {  # name: (colours, mark, extra replacements)
    "Done": (TEMPLATE, None, {}),
    "Today": (GOLD, "", {**GLOSS, **WELL, **edge("#C96200", 10)}),
    # the days ahead: a bright steel blue (ink day number on its light stud), clearly apart from PipOff
    "Next": (("#DDEBFF", "#5F86D6", "#F6FAFF", "#B4CBF2", "#2D4A93"), "", {**GLOSS, **WELL, **edge("#4669BD", 10)}),
    "Seven": (("#CDA4FF", "#8445F5", "#E4CCFF", "#9C64FA", "#5A2BB0"), SEVEN_STAR, {}),
    "SevenToday": (GOLD, BIG_STAR, {**GLOSS, **edge("#C96200", 10)}),
}

src = (ROOT / "art/source/ui/streak_pip.svg").read_text()
assert all(c in src for c in TEMPLATE) and "<!--MARK-->" in src, "the template colours or mark moved"
OUT.mkdir(parents=True, exist_ok=True)
for name, (colours, mark, extra) in PIPS.items():
    svg = src
    for old, new in extra.items():
        assert old in svg, old
        svg = svg.replace(old, new)
    for old, new in zip(TEMPLATE, colours):
        svg = svg.replace(old, new)
    if mark is not None:
        svg = re.sub(r"<!--MARK-->.*<!--/MARK-->", lambda _: mark, svg, flags=re.S)
    if mark == "":  # the day-number pips: a solid stud ring so the face reads as a Lego stud under the number
        svg = svg.replace('stroke="#14121C" stroke-opacity="0.3" stroke-width="3"', f'stroke="{colours[4]}" stroke-width="9"')
    path = OUT / f"pip_{name}.svg"
    path.write_text(svg)
    subprocess.run([sys.executable, str(ROOT / "tools/ui-art/render.py"), str(path), str(OUT / f"pip_{name}.png"),
                    "--size", "200", "200"], check=True)
