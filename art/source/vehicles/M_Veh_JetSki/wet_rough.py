"""Post-bake (V1 Studio pass 1): Clear wet turned the orange hull into a sky mirror (wet RGH hit the 0.04 floor).
Raise the _RGH_Wet by ADD (never above the dry RGH) so wet gelcoat stays glossy (~0.2-0.25) but keeps its colour.
    python3 art/source/vehicles/M_Veh_JetSki/wet_rough.py <textures dir> T_JetSki_Hull T_JetSki_Sled:0.3"""
import os
import sys

import numpy as np
from PIL import Image

ADD = 0.12   # V1 fix round: glossier wet gelcoat (was 0.2; 0.0 was a sky mirror)
d = sys.argv[1]
for arg in sys.argv[2:]:
    # V1 fix round: optional per-stem ADD (stem:add); the sled's flat wet top mirrored the Clear sky into a white
    # ghost at the stern, so the soft sled keeps a higher wet roughness than the gelcoat hull
    stem, _, add = arg.partition(":")
    add = float(add) if add else ADD
    dry = np.asarray(Image.open(os.path.join(d, stem + "_RGH.png")).convert("L")).astype(np.float32) / 255
    p = os.path.join(d, stem + "_RGH_Wet.png")
    im = Image.open(p)
    wet = np.asarray(im.convert("L")).astype(np.float32) / 255
    if dry.shape != wet.shape:
        dry = np.asarray(Image.fromarray((dry * 255).astype(np.uint8)).resize(wet.shape[::-1])).astype(np.float32) / 255
    new = np.minimum(dry, wet + add)
    Image.fromarray((new * 255 + 0.5).astype(np.uint8)).convert(im.mode).save(p)
    print(stem, "wet RGH median %.2f -> %.2f" % (np.median(wet), np.median(new)))
