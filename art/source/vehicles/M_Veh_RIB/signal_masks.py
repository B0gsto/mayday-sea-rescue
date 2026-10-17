"""Signal masks for check_textures.py: the Hull Orange livery (05 3.2 reserved colour #FF6600) is saturated by design.
Mask = pixels whose hue is within the orange band and whose saturation is above 0.45 in the dry ALB, dilated 3 px.
    python3 art/source/vehicles/M_Veh_RIB/signal_masks.py <textures dir> <out dir> T_RIB_Hull T_RIB_Deck ...
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for stem in sys.argv[3:]:
    rgb = np.asarray(Image.open(os.path.join(src, stem + "_ALB.png")).convert("RGB")).astype(np.float32) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = (np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) + 360) % 360
    m = ((hue < 72) | (hue > 345)) & (sat > 0.45) | ((hue > 190) & (hue < 260) & (sat > 0.45))   # orange livery, yellow retro chevrons, blue lenses
    img = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
    img.save(os.path.join(out, stem + "_signal.png"))
    print(stem, "signal share %.1f%%" % (100 * np.asarray(img).mean() / 255))
