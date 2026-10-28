"""Soft light sprites for the FX1 spectacle moments (docs/26 "Satisfaction bar"): light is light, not a toy piece,
so these are generated 2D (Pillow) next to the Blender flipbooks in render.py. White on transparent, tinted in game.

  python3 art/source/vfx/glow.py      -> build/prod/vfx/{light_ray,light_beam,core_flash}.png

light_ray   a long tapered ray along +Y (a VelocityParallel particle flies along it): the fan of god rays
light_beam  a Beam texture: soft top/bottom edges, flat along U (the beam's length): the light pillar
core_flash  a round flash: crisp white disc, soft warm falloff (Size curve does the timing)
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(HERE))), "build", "prod", "vfx")


def save(name, alpha):
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    rgba = np.dstack([np.full_like(a, 255)] * 3 + [a])
    Image.fromarray(rgba).save(os.path.join(OUT, name + ".png"))


def light_ray(n=512):
    y, x = np.mgrid[0:n, 0:n] / (n - 1)
    along = 1 - y  # 0 at the base (bottom), 1 at the tip
    half = 0.11 * (1 - along) ** 0.7 + 0.004  # wide at the base, a needle at the tip
    d = np.abs(x - 0.5) / half
    core = np.clip(1 - d, 0, 1) ** 1.6
    fade = np.clip(along / 0.06, 0, 1) * np.clip((1 - along) / 0.5, 0, 1) ** 0.8
    return core * fade


def light_beam(n=256):
    y = np.linspace(-1, 1, n)
    edge = np.clip(1 - np.abs(y), 0, 1)
    prof = np.clip(edge ** 0.55 * 1.15, 0, 1) * (0.55 + 0.45 * np.exp(-(y / 0.22) ** 2))
    return np.tile(prof[:, None], (1, n))


def core_flash(n=512):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.hypot(x, y)
    disc = np.clip((0.34 - r) / 0.03, 0, 1)  # the crisp core
    halo = np.exp(-((r / 0.5) ** 2) * 2.2) * np.clip((0.98 - r) / 0.2, 0, 1)
    return np.maximum(disc, halo * 0.85)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("light_ray", light_ray), ("light_beam", light_beam), ("core_flash", core_flash)):
        a = fn()
        assert a.max() > 0.9 and a[0, 0] < 0.02, name  # bright core, clear corners
        save(name, a)
        print("wrote", name)
