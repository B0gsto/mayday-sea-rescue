"""Writes a placeholder PBR set for the pipeline self-test and the check_textures tests (system python3, Pillow, numpy).
Not shipping art: a painted cast-iron look from a height field, so every map rule has something real to measure.

    python3 tools/blender/selftest/placeholder_pbr.py <out_dir> <Name> <Set> [size] [--wet]
"""
import os
import sys

import numpy as np
from PIL import Image


def height_field(size, seed=7):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    h = np.zeros((size, size), np.float32)
    for _ in range(24):                     # casting pits and bumps (smooth, so the normal map is integrable)
        cx, cy, r, amp = rng.random(), rng.random(), 0.02 + 0.06 * rng.random(), rng.choice([-1.0, 1.0]) * (0.3 + rng.random())
        h += amp * np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * r * r))
    h += 0.15 * np.sin(x * 40) * np.cos(y * 23)
    return h


def normal_from_height(h, strength=4.0, opengl=True):
    """Tangent-space normal map: n = normalise(-dh/dx, -dh/dy_up, 1); OpenGL puts +V (up the image) in green."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) / 2.0 * strength
    dy_up = (np.roll(h, 1, axis=0) - np.roll(h, -1, axis=0)) / 2.0 * strength      # rows run down
    n = np.stack([-dx, -dy_up if opengl else dy_up, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return ((n + 1.0) * 127.5).clip(0, 255).astype(np.uint8)


def write_set(out_dir, name, set_name, size=1024, wet=False, opengl=True, albedo_rgb=(52, 56, 58), rough=170, metal_share=0.0,
              alb_mode="RGB", rgh_mode="L", saturated=False):
    os.makedirs(out_dir, exist_ok=True)
    h = height_field(size)
    shade = (h - h.min()) / max(float(h.max() - h.min()), 1e-6)
    base = np.array(albedo_rgb, np.float32)
    if saturated:
        base = np.array((230, 40, 30), np.float32)
    alb = (base[None, None, :] * (0.85 + 0.3 * shade[..., None])).clip(0, 255).astype(np.uint8)
    met = np.zeros((size, size), np.uint8)
    if metal_share > 0:
        rows = int(size * metal_share)
        met[:rows] = 255
        alb[:rows] = np.array((200, 200, 205), np.uint8)
    rgh = (rough - 30 * shade).clip(0, 255).astype(np.uint8)
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    Image.fromarray(alb).convert(alb_mode).save(stem + "ALB.png")
    Image.fromarray(normal_from_height(h, opengl=opengl)).save(stem + "NOR.png")
    Image.fromarray(rgh).convert(rgh_mode).save(stem + "RGH.png")
    Image.fromarray(met).save(stem + "MET.png")
    if wet:
        Image.fromarray((alb * 0.75).astype(np.uint8)).save(stem + "ALB_Wet.png")
        Image.fromarray((rgh.astype(np.float32) - 75).clip(0, 255).astype(np.uint8)).save(stem + "RGH_Wet.png")
    return stem


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    out, name, set_name = args[:3]
    size = int(args[3]) if len(args) > 3 else 1024
    print(write_set(out, name, set_name, size, wet="--wet" in sys.argv) + "{ALB,NOR,RGH,MET}.png")
