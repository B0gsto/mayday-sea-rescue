#!/usr/bin/env python3
"""Inline src/*.html into self-contained pages, screenshot them, and tile a contact sheet.
usage: python3 art/source/concepts/sea-zones/make.py <sheet.png>"""
import pathlib, re, subprocess, sys
from PIL import Image
here = pathlib.Path(__file__).resolve().parent
sheet = pathlib.Path(sys.argv[1]).resolve()
render = here.parents[3] / "tools/ui-art/render.py"
pages = ["pirate-boat", "zone-buoy", "zone-board", "hud-banner-chip"]
shots = []
for p in pages:
    src = (here / "src" / f"{p}.html").read_text()
    html = re.sub(r'<script src="(\w+\.js)"></script>', lambda m: "<script>\n" + (here / "src" / m[1]).read_text() + "</script>", src)
    (here / f"{p}.html").write_text(html)
    out = sheet.parent / f"{p}.png"
    subprocess.run([sys.executable, str(render), str(here / f"{p}.html"), str(out), "--size", "1000", "1000", "--scale", "1", "--keep"], check=True, stdout=subprocess.DEVNULL)
    shots.append(out)
cell, gap = 508, 4
im = Image.new("RGB", (cell * 2 + gap, cell * 2 + gap), "#000")
for i, s in enumerate(shots):
    im.paste(Image.open(s).convert("RGB").resize((cell, cell), Image.LANCZOS), ((i % 2) * (cell + gap), (i // 2) * (cell + gap)))
im.save(sheet)
print(sheet, im.size)
