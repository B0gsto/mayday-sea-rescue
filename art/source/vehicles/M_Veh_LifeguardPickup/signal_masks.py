"""Signal masks for check_textures.py: the service livery is saturated by design - lifeguard red (#CC2A2E) and
yellow (#ECCB22) battenburg, red lettering and the amber light-bar lenses (05 3.2: real safety colours). Mask =
pixels whose hue sits in the red / amber / yellow band and whose saturation is above 0.45 in the dry ALB, dilated.

    python3 art/source/vehicles/M_Veh_LifeguardPickup/signal_masks.py <textures dir> <out dir> \
        T_LifeguardPickup_Body T_LifeguardPickup_Cab ...
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
    m = ((hue < 72) | (hue > 340)) & (sat > 0.45)
    img = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
    img.save(os.path.join(out, stem + "_signal.png"))
    print(stem, "signal share %.1f%%" % (100 * np.asarray(img).mean() / 255))
