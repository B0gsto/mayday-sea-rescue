"""Post-bake cleanup for selected-to-active ray misses: texels whose baked tangent normal points into the surface
(blue < 0.5, a hit on a back face of an intersecting _HP component) are replaced by the flat normal, then blended
with a 1-px box blur at the seam. Run on every exported _NOR (and master) after a bake.
    python3 art/source/vehicles/M_Veh_RIB/fix_normals.py <png> [...]"""
import sys

import numpy as np
from PIL import Image, ImageFilter

for p in sys.argv[1:]:
    im = Image.open(p).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    bad = a[..., 2] < 140
    if not bad.any():
        print(p, "clean")
        continue
    a[bad] = (128, 128, 255)
    soft = np.asarray(Image.fromarray(a.astype(np.uint8)).filter(ImageFilter.BoxBlur(1))).astype(np.float32)
    edge = np.asarray(Image.fromarray((bad * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    a[edge] = soft[edge]
    Image.fromarray(a.astype(np.uint8)).save(p)
    print(p, "fixed %.2f%%" % (100 * bad.mean()))
