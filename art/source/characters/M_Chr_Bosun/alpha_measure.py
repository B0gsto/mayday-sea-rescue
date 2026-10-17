"""CH6: AlphaMode decision by measurement. Compares the two Overcast fur close-ups (Transparency vs Overlay).
Fur region = pixels that differ between the two captures (the cards are the only thing that changes) dilated a little,
plus a centre crop fallback. Reports mean luminance, luminance variance, edge density (Sobel > thr) and the fraction of
straight, high-contrast edges (quad outlines) inside the region."""
import json, sys
import numpy as np
from PIL import Image, ImageFilter
D = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/assets/review/M_Chr_Bosun/studio/"
A = "M_Chr_Bosun_Overcast_dry_Alpha_"
im = {m: np.asarray(Image.open(D + A + m + ".png").convert("RGB"), dtype=np.float32) / 255 for m in ("Transparency", "Overlay")}
lum = {m: v @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32) for m, v in im.items()}
diff = np.abs(lum["Transparency"] - lum["Overlay"])
mask = diff > 0.04
mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
h, w = diff.shape
if mask.mean() < 0.002:
    mask = np.zeros_like(mask); mask[h // 4: 3 * h // 4, w // 4: 3 * w // 4] = True
out = {"size": [w, h], "changed_px_frac": round(float((diff > 0.04).mean()), 4), "region_frac": round(float(mask.mean()), 4)}
for m, L in lum.items():
    gx = np.zeros_like(L); gy = np.zeros_like(L)
    gx[:, 1:-1] = L[:, 2:] - L[:, :-2]; gy[1:-1, :] = L[2:, :] - L[:-2, :]
    g = np.hypot(gx, gy)
    e = (g > 0.15) & mask
    # straight hard edges: strong gradient whose neighbours along the edge share the same direction (quad outlines)
    ang = np.arctan2(gy, gx)
    same = np.zeros_like(e)
    same[1:-1, 1:-1] = (np.abs(np.sin(ang[1:-1, 1:-1] - ang[:-2, :-2])) < 0.1) & (np.abs(np.sin(ang[1:-1, 1:-1] - ang[2:, 2:])) < 0.1)
    v = L[mask]
    out[m] = {"mean_lum": round(float(v.mean()), 4), "var_lum": round(float(v.var()), 5),
              "edge_frac": round(float(e.sum() / max(mask.sum(), 1)), 4),
              "straight_edge_frac": round(float((e & same).sum() / max(e.sum(), 1)), 4)}
t, o = out["Transparency"], out["Overlay"]
out["choice"] = "Transparency" if t["straight_edge_frac"] <= o["straight_edge_frac"] else "Overlay"
print(json.dumps(out, indent=1))
json.dump(out, open(D + "../alpha_decision.json", "w"), indent=1)
