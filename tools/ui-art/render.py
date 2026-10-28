#!/usr/bin/env python3
"""Render a hand-authored SVG or HTML UI sprite to a transparent, trimmed PNG with headless Google Chrome
(the UI art rule in CLAUDE.md: screen UI sprites are Claude-designed vector art, des1 test 2026-10-28).

usage: python3 tools/ui-art/render.py <in.svg|in.html> <out.png> [--size W H] [--scale 2]
  --size   the page window in CSS px (default 256 256): make it larger than the drawing
  --scale  device scale factor (default 2): render at 2x the size it shows on screen, then upload
The transparent margin is trimmed. Sources live in art/source/ui/ (text, committed); PNGs stay local
(no binaries on GitHub) and go up with ~/RobloxProjects/tools/assets.py upload . <png> --type Image."""
import argparse
import pathlib
import subprocess

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--size", nargs=2, type=int, default=[256, 256])
ap.add_argument("--scale", type=float, default=2)
a = ap.parse_args()
src, out = pathlib.Path(a.src).resolve(), pathlib.Path(a.out).resolve()
out.parent.mkdir(parents=True, exist_ok=True)
subprocess.run(
    [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
     f"--force-device-scale-factor={a.scale}", f"--window-size={a.size[0]},{a.size[1]}",
     "--default-background-color=00000000", f"--screenshot={out}", src.as_uri()],
    capture_output=True, timeout=60, check=True)
im = Image.open(out)
box = im.getbbox()
if box:
    im.crop(box).save(out)
print(out, Image.open(out).size)
