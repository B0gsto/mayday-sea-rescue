"""Post-bake: AO, salt and water streaks can drag bare-metal texels (MET > 0.5) under the 180 albedo floor of
check_textures. Scale those texels up so their luma is at least FLOOR (dry only: wet albedos have no floor), hue kept.
    python3 art/source/vehicles/M_Veh_RIB/metal_floor.py <textures dir> T_RIB_Hull T_RIB_Rig ..."""
import os
import sys

import numpy as np
from PIL import Image

FLOOR = 190
d = sys.argv[1]
for stem in sys.argv[2:]:
    met = np.asarray(Image.open(os.path.join(d, stem + "_MET.png")).convert("L")) > 127
    for suf, floor in (("_ALB", FLOOR),):   # wet maps have no floor
        p = os.path.join(d, stem + suf + ".png")
        im = Image.open(p)
        mode = im.mode
        a = np.asarray(im.convert("RGBA")).astype(np.float32)
        m = met if met.shape == a.shape[:2] else np.asarray(Image.fromarray(met.astype(np.uint8) * 255).resize(a.shape[1::-1])) > 127
        luma = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
        k = np.where(m & (luma < floor), floor / np.maximum(luma, 1.0), 1.0)
        a[..., :3] = np.clip(a[..., :3] * k[..., None], 0, 248)
        Image.fromarray(a.astype(np.uint8)).convert(mode).save(p)
        print(stem + suf, "lifted %.2f%%" % (100 * (k > 1).mean()))
