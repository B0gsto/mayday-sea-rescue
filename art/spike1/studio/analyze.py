#!/usr/bin/env python3
"""Numeric analysis of the Spike 1 captures (no viewing): texture close-ups (contrast, dominant period ->
effective texels per 12-stud plane), tentacle bend diffs. Prints a table and writes analysis.json."""
import glob, json, math, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CAP = os.path.join(sys.argv[1] if len(sys.argv) > 1 else HERE, "captures")
R = json.load(open(os.path.join(HERE, os.environ.get("SPIKE_RESULTS", "results.json"))))
out = {}


def lum(path):
    a = np.asarray(Image.open(path).convert("RGB"), np.float64)
    return a, a @ [0.2126, 0.7152, 0.0722]


def period(L):
    """Dominant spatial period (px) of a crop along x and y, from the 2-D FFT peak (ignoring DC)."""
    L = L - L.mean()
    F = np.abs(np.fft.rfft2(L * np.outer(np.hanning(L.shape[0]), np.hanning(L.shape[1]))))
    F[0, 0] = 0
    F[:2, :2] = 0
    iy, ix = np.unravel_index(np.argmax(F), F.shape)
    fy = iy if iy <= L.shape[0] // 2 else iy - L.shape[0]
    f = math.hypot(fy / L.shape[0], ix / L.shape[1])
    return (1 / f if f else float("inf")), float(F.max() / (F.sum() + 1e-9))


for name, c in sorted(R.get("captures", {}).items()):
    if not c.get("path") or not os.path.exists(c["path"]):
        continue
    rgb, L = lum(c["path"])
    h, w = L.shape
    crop = L[int(h * .3):int(h * .7), int(w * .3):int(w * .7)]
    p, peak = period(crop)
    vis = 2 * c["dist"] * math.tan(math.radians(c["fov"]) / 2)  # studs across the image height
    studs_per_px = vis / h
    cell_studs = p / 2 * studs_per_px  # a checker period is two cells
    out[name] = {"size": [w, h], "mean": round(float(crop.mean()), 1), "std": round(float(crop.std()), 2),
                 "p2p": round(float(np.percentile(crop, 98) - np.percentile(crop, 2)), 1),
                 "period_px": round(p, 2), "peak": round(peak, 4),
                 "eff_texels_per_12studs": round(12 / cell_studs) if cell_studs > 0 and math.isfinite(cell_studs) else None}

for path in sorted(glob.glob(os.path.join(CAP, "play_*.png"))):
    rgb, L = lum(path)
    h, w = L.shape
    c = rgb[int(h * .3):int(h * .7), int(w * .3):int(w * .7)].reshape(-1, 3).mean(0)
    out[os.path.basename(path)] = {"meanRGB": [round(float(x), 1) for x in c], "r_over_g": round(float(c[0] / max(c[1], 1)), 3)}
for path in sorted(glob.glob(os.path.join(CAP, "over*.png"))):
    rgb, L = lum(path)
    h, w = L.shape
    c = rgb[int(h * .3):int(h * .7), int(w * .3):int(w * .7)].reshape(-1, 3).mean(0)
    out.setdefault(os.path.basename(path)[:-4], {})["meanRGB"] = [round(float(x), 1) for x in c]

for t in ("Tentacle20", "Tentacle40"):
    rest = os.path.join(CAP, t + "_rest.png")
    if not os.path.exists(rest):
        continue
    _, L0 = lum(rest)
    for b in ("Bone_10", "Bone_30"):
        p = os.path.join(CAP, "%s_%s.png" % (t, b))
        if not os.path.exists(p):
            continue
        _, L1 = lum(p)
        d = np.abs(L1 - L0) > 12
        rows = np.where(d.any(1))[0]
        cols = np.where(d.any(0))[0]
        out["%s_%s" % (t, b)] = {"changed_frac": round(float(d.mean()), 4),
                                 "rows": [int(rows.min()), int(rows.max())] if len(rows) else None,
                                 "cols": [int(cols.min()), int(cols.max())] if len(cols) else None,
                                 "img": list(L0.shape)}
    # object extent in the rest shot: pixels differing from the median sky column
    bg = np.median(L0, axis=1, keepdims=True)
    obj = np.abs(L0 - bg) > 15
    rows = np.where(obj.any(1))[0]
    cols = np.where(obj.any(0))[0]
    out[t + "_rest_extent"] = {"rows": [int(rows.min()), int(rows.max())] if len(rows) else None,
                               "cols": [int(cols.min()), int(cols.max())] if len(cols) else None}

json.dump(out, open(os.path.join(HERE, "analysis.json"), "w"), indent=1)
for k, v in out.items():
    print(k, json.dumps(v))
