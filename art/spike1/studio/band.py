#!/usr/bin/env python3
"""Checker-band amplitude: spectral magnitude at the diagonal checker fundamental for cell sizes of the
1/2048-, 1/1024- and 1/512-plane pitch (2.3 / 4.6 / 9.2 px here... computed from the shot geometry), relative
to the median spectrum. >~10 = checker present."""
import json, math, os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
R = json.load(open(os.path.join(HERE, os.environ.get("SPIKE_RESULTS", "results.json"))))
out = {}
for name, c in sorted(R["captures"].items()):
    if not name.startswith("tex"):
        continue
    L = np.asarray(Image.open(c["path"]).convert("L"), np.float64)
    h, w = L.shape
    n = 512
    crop = L[h // 2 - n // 2:h // 2 + n // 2, w // 2 - n // 2:w // 2 + n // 2]
    crop = crop - crop.mean()
    F = np.abs(np.fft.fft2(crop * np.outer(np.hanning(n), np.hanning(n))))
    med = np.median(F)
    spx = 2 * c["dist"] * math.tan(math.radians(c["fov"]) / 2) / h  # studs per px
    row = {}
    for res in (4096, 2048, 1024, 512):
        cell = 12 / res / spx  # px
        f = 1 / (2 * cell)     # cycles/px per axis (checker diagonal fundamental)
        if f >= 0.5:
            row[res] = None
            continue
        k = int(round(f * n))
        win = F[max(k - 3, 0):k + 4, max(k - 3, 0):k + 4].max()
        win2 = F[max(k - 3, 0):k + 4, max(n - k - 3, 0):n - k + 4].max()
        row[res] = round(float(max(win, win2) / med), 1)
    out[name] = row
    print(name, "cell px @4096=%.2f" % (12 / 4096 / spx), row)
json.dump(out, open(os.path.join(HERE, "band.json"), "w"), indent=1)
