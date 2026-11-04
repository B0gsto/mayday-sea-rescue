#!/usr/bin/env python3
"""Render the Deep Spin sprites (art/source/ui/spin/sprites.html) to build/spinart/*.png with headless Chrome, as
tools/ui-art/render.py does. The PNGs stay local; upload with ~/RobloxProjects/tools/assets.py upload . <png> --type Image."""
import pathlib
import subprocess

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parents[3] / "build" / "spinart"
OUT.mkdir(parents=True, exist_ok=True)
SIZES = {"rotor": 1024, "blur": 512, "housing": 1024, "flapper": 256, "vortex": 1024, "rays": 1024, "strata": (256, 64)}
SIZES.update({f"wedge{i}": 1024 for i in range(1, 13)})
for name, size in SIZES.items():
    w, h = size if isinstance(size, tuple) else (size, size)
    out = OUT / f"T_DeepSpin_{name}.png"
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={w},{h}", "--default-background-color=00000000", f"--screenshot={out}",
                    f"{(HERE / 'sprites.html').as_uri()}?s={name}"], capture_output=True, timeout=60, check=True)
    print(out.name, Image.open(out).size)
