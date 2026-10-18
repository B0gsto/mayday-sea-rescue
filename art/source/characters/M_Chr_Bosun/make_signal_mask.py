"""Signal mask for check_textures.py (Bosun harness): the Hull Orange webbing (05 3.2 reserved colour #FF6600) is saturated
by design. Mask = pixels in the orange hue band (345..50 deg) with saturation above 0.45 and value above 0.12, in the dry
ALB or the _Wet ALB (union), dilated 2 px (5x5 max filter) so the downsample-blended webbing edges count too.
Same approach as art/source/vehicles/M_Veh_RIB/signal_masks.py. System python3 + Pillow/numpy:
    python3 art/source/characters/M_Chr_Bosun/make_signal_mask.py
    python3 tools/blender/check_textures.py assets/textures/M_Chr_Bosun/ --alpha --wet \\
        --signal-mask T_Bosun_Harness=assets/review/M_Chr_Bosun/masks/T_Bosun_Harness_signal.png
"""
import os

import numpy as np
from PIL import Image, ImageFilter

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
SRC = G + "assets/textures/M_Chr_Bosun/"
OUT = G + "assets/review/M_Chr_Bosun/masks/"
STEM = "T_Bosun_Harness"


def orange(path):
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = (np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) + 360) % 360
    return ((hue < 50) | (hue > 345)) & (sat > 0.45) & (mx > 0.12)


m = orange(SRC + STEM + "_ALB.png")
wet = SRC + STEM + "_ALB_Wet.png"
if os.path.exists(wet):
    w = orange(wet)
    if w.shape == m.shape:
        m |= w
os.makedirs(OUT, exist_ok=True)
img = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
img.save(OUT + STEM + "_signal.png")
print(STEM, "%dx%d" % img.size, "orange %.1f%%, mask after dilation %.1f%%" % (100 * m.mean(), 100 * np.asarray(img).mean() / 255),
      "->", OUT + STEM + "_signal.png")
