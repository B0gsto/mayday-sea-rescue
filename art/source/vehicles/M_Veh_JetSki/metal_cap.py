"""Post-bake: stainless / aluminium texels brighter than CAP luma (edge wear on metal baked to near white) are scaled
down to CAP, hue kept, so polished metal reads as steel, not white (V2 review: no near-white streaks).
    python3 art/source/vehicles/M_Veh_JetSki/metal_cap.py <textures dir> T_JetSki_Sled ..."""
import os
import sys

import numpy as np
from PIL import Image

CAP = 222
d = sys.argv[1]
for stem in sys.argv[2:]:
    met = np.asarray(Image.open(os.path.join(d, stem + "_MET.png")).convert("L")) > 127
    for suf in ("_ALB", "_ALB_Wet"):
        p = os.path.join(d, stem + suf + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p)
        mode = im.mode
        a = np.asarray(im.convert("RGBA")).astype(np.float32)
        luma = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
        k = np.where(met & (luma > CAP), CAP / np.maximum(luma, 1.0), 1.0)
        a[..., :3] *= k[..., None]
        Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert(mode).save(p)
        print(stem + suf, "capped %.2f%%" % (100 * (k < 1).mean()))
