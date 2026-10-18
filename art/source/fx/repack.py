#!/usr/bin/env python3
"""Re-pack FX sheets from the cell PNGs a build_fx.py run left in its temp folder, without re-rendering.

    python3 art/source/fx/repack.py FX_Spray_Mist [...]      (default: every assets/textures/FX/*.json)

For each asset the newest temp folder (fx_*) holding exactly grid*grid cells whose last cell was written before the
asset's sheet is used. Cells are Blender's straight-alpha sRGB PNGs; packing is fxpack.pack (same as build_fx).
"""
import glob
import json
import os
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fxpack  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
FX = os.path.join(ROOT, "assets", "textures", "FX")


def load(path):
    im = Image.open(path)
    a = np.asarray(im)
    if a.dtype == np.uint16 or a.max() > 255:
        return a.astype(np.float32) / 65535.0
    return np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0


def main():
    names = sys.argv[1:] or sorted(n[:-5] for n in os.listdir(FX) if n.endswith(".json"))
    dirs = glob.glob(os.path.join(tempfile.gettempdir(), "fx_*"))
    for name in names:
        jp = os.path.join(FX, name + ".json")
        with open(jp) as f:
            info = json.load(f)
        n = info["grid"] ** 2
        sheet_t = os.path.getmtime(os.path.join(FX, name + ".png"))
        best = None
        for d in dirs:
            cells = sorted(glob.glob(os.path.join(d, "cell_*.png")))
            if len(cells) != n:
                continue
            t = os.path.getmtime(cells[-1])
            if t <= sheet_t + 1 and (best is None or t > best[0]):
                best = (t, cells)
        if not best or sheet_t - best[0] > 120:
            print("REPACK skip", name, "(no matching cells)")
            continue
        cells = [load(c) for c in best[1]]
        sheet = fxpack.pack(cells, info["grid"], info["kind"])
        Image.fromarray(sheet).save(os.path.join(FX, name + ".png"), optimize=True)
        info.update(fxpack.stats(sheet, info["grid"]))
        with open(jp, "w") as f:
            json.dump(info, f, indent=1)
        vis = sheet[..., 3] > 40
        print("REPACK %s from %s rgb(a>40) %s" % (name, os.path.basename(os.path.dirname(best[1][0])),
                                                 sheet[vis][:, :3].mean(0).round() if vis.any() else "-"))


if __name__ == "__main__":
    main()
