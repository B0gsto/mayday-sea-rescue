"""M_Kit_HeavingLine: the rope trim T_Rope_Poly_* (dry + _Wet) for the asset's one set, painted in numpy.

tools/blender/rope.py's braid trim is the base (a floating polypropylene heaving line is a plaited line, and the
budget cannot resolve the twist geometrically, so the trim carries the strand look: rope.py's documented fallback).
This adds the wear a working deck line shows: sun fade on the exposed loops, salt bloom, handling grime in the
hollows and a little slack dust. Every octave is a tileable Fourier noise (rope.tile_noise), so the trim stays
seamless in U (round the rope) and V (along it); normals stay rope.py's OpenGL tile, and the albedo stays inside
check_textures' luma 20..240 and saturation 0.45.

Called by build.py (inside Blender, numpy only) with the textures directory, like the other E1/E2 kit assets; the
maps land in the out-root before validate looks for them.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "../../../tools/blender"))
import rope  # noqa: E402

SIZE = 512

TINT = (1.00, 0.945, 0.760)          # pale, sun-bleached yellow over rope.py's Nylon braid (sRGB multipliers)
FADE = (236, 231, 208)               # sun-bleached line
GRIME = (128, 117, 94)               # deck dirt in the hollows
SALT = (228, 226, 214)               # dried salt bloom
ROUGH_BASE = 0.66                    # plaited polypropylene, a little glossier than rope.py's Nylon
WET_DARK = (0.76, 0.785, 0.80)       # wet line: darker and deeper, blue-shifted
WET_ROUGH = 0.55


def _mix(a, b, k):
    return a + (np.asarray(b, np.float32)[None, None, :] - a) * k[..., None]


def maps(size=SIZE, seed=11):
    """{'ALB' (H, W, 3) uint8, 'NOR' (H, W, 3), 'RGH' (H, W) , 'MET' (H, W)} dry, and their _Wet twins."""
    base = rope.trim_maps("Nylon", "braid", size, seed=seed)
    alb = base["ALB"].astype(np.float32) / 255.0 * np.asarray(TINT, np.float32)[None, None, :]
    fade = np.clip((rope.tile_noise(size, 5, seed + 3) - 0.52) * 1.9, 0.0, 1.0) * 0.55
    grime = np.clip((rope.tile_noise(size, 9, seed + 4) - 0.60) * 2.4, 0.0, 1.0) * 0.38
    salt = np.clip((rope.tile_noise(size, 34, seed + 5) - 0.70) * 3.2, 0.0, 1.0) * 0.55
    alb = _mix(alb, tuple(c / 255.0 for c in FADE), fade)
    alb = _mix(alb, tuple(c / 255.0 for c in GRIME), grime)
    alb = _mix(alb, tuple(c / 255.0 for c in SALT), salt)
    alb = np.clip(alb, 32.0 / 255.0, 238.0 / 255.0)

    rgh = np.full((size, size), ROUGH_BASE, np.float32)
    rgh += 0.10 * grime + 0.05 * (1.0 - fade) + 0.05 * salt
    rgh += 0.05 * (rope.tile_noise(size, 44, seed + 6) - 0.5)
    rgh = np.clip(rgh, 0.42, 0.94)

    met = np.zeros((size, size), np.uint8)
    out = {"ALB": np.round(alb * 255.0).astype(np.uint8), "NOR": base["NOR"].copy(),
           "RGH": np.round(rgh * 255.0).astype(np.uint8), "MET": met}
    wet_alb = np.round(np.clip(alb * np.asarray(WET_DARK, np.float32)[None, None, :], 0.0, 1.0) * 255.0).astype(np.uint8)
    out_wet = {"ALB": wet_alb, "NOR": base["NOR"].copy(),
               "RGH": np.round(rgh * WET_ROUGH * 255.0).astype(np.uint8), "MET": met}
    return out, out_wet


def build(directory, size=SIZE):
    """Write T_Rope_Poly_{ALB,NOR,RGH,MET}.png and their _Wet twins into `directory` (the out-root's textures)."""
    dry, wet = maps(size)
    os.makedirs(directory, exist_ok=True)
    written = []
    for kind, arr in dry.items():
        p = os.path.join(directory, "T_Rope_Poly_%s.png" % kind)
        rope.write_png(p, arr)
        written.append(p)
    for kind, arr in wet.items():
        p = os.path.join(directory, "T_Rope_Poly_%s_Wet.png" % kind)
        rope.write_png(p, arr)
        written.append(p)
    print("[maketex] %d maps at %d px in %s" % (len(written), size, os.path.relpath(directory)))
    return written


if __name__ == "__main__":
    build(sys.argv[1])
