"""M_Kit_TowLine textures (pure numpy, writes under the run's out-root textures dir; no AI images).

  T_TowLine_Rope_ALB/NOR/RGH/MET (+_Wet)  1024 px tiling rope trim: cream 3-strand polyester with one red marker
      yarn, deck grime, salt bloom, strand-crest sheen (rope.trim_height drives strands, yarns and the normal map).
  T_TowLine_Hardware_ALB/NOR/RGH/MET (+_Wet)  512 px galvanised steel: zinc spangle, fine scratches, cold-worked
      marks; metal albedo kept above 180 sRGB as check_textures requires.

Both sets tile in U (round the rope) and V (along it) / are flat for the shackle; maps are written by
build.py at build time, before validate looks for them.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import names  # noqa: E402
import rope  # noqa: E402

ASSET = "M_Kit_TowLine"
SET_NAME = "TowLine"
ROPE_SIZE = 1024
HW_SIZE = 512


def noise(n, cycles, seed, aniso=(1.0, 1.0)):
    """Periodic band-limited noise 0..1 on an n x n tile (tileable in both axes)."""
    r = np.random.default_rng(seed)
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[0]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[1]
    k = np.sqrt(fx ** 2 + fy ** 2)
    spec = np.fft.fft2(r.standard_normal((n, n))) * np.exp(-(k / cycles) ** 2)
    spec[0, 0] = 0
    v = np.real(np.fft.ifft2(spec))
    return ((v - v.min()) / (v.max() - v.min() + 1e-9)).astype(np.float32)


def _uv(n):
    u = (np.arange(n) + 0.5)[None, :] / n
    v = 1.0 - (np.arange(n) + 0.5)[:, None] / n
    return u + 0 * v, v + 0 * u


def _normal(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return np.round((n * 0.5 + 0.5) * 255).astype(np.uint8)


def _grey(a):
    return np.clip(a * 255.0, 0, 255).astype(np.uint8)


def rope_maps(size=ROPE_SIZE):
    """Cream 3-strand polyester tow line, one red marker yarn, grime + salt, OpenGL normal."""
    h = rope.trim_height("three_strand", size, seed=11)               # 0..1 strand + yarn relief
    u, v = _uv(size)
    ph = (3.0 * (u - v)) % 1.0                                        # strand phase, matches the trim height
    strand = np.floor(3.0 * (u - v)) % 3                              # 0..2 round the rope
    blotch = noise(size, 4, 21)
    fine = noise(size, 18, 22)
    grime = np.clip(noise(size, 2, 24) - 0.34, 0.0, 1.0) * 0.85       # deck dirt, broad patches
    salt = np.clip(noise(size, 44, 25) - 0.78, 0.0, 1.0) * 3.4        # sparse dried-salt speckle
    salt = np.clip(salt * (0.5 + 0.5 * h), 0.0, 1.0)
    crest = np.exp(-((ph - 0.5) / 0.10) ** 2)

    base = np.array([197.0, 191.0, 177.0])
    shade = (0.80 + 0.22 * h) * (0.90 + 0.14 * blotch) * (1.0 - 0.34 * grime) * (0.97 + 0.06 * (fine - 0.5))
    alb = base[None, None, :] * shade[..., None]

    tracer = np.exp(-((ph - 0.5) / 0.040) ** 2) * (strand == 0) * np.clip(h * 1.3 - 0.25, 0.0, 1.0)
    alb = alb * (1.0 - tracer[..., None]) + np.array([152.0, 61.0, 54.0])[None, None, :] * tracer[..., None]
    salt_rgb = np.array([236.0, 233.0, 226.0])[None, None, :]
    alb = alb + (salt_rgb - alb) * (0.62 * salt)[..., None]
    alb = np.clip(alb, 0, 238).astype(np.uint8)

    rough = 0.63 + 0.10 * (1.0 - h) + 0.05 * (blotch - 0.5) + 0.10 * salt - 0.07 * crest * (1.0 - grime) + 0.06 * grime
    rgh = _grey(np.clip(rough, 0.30, 0.92))

    met = np.zeros((size, size), np.uint8)
    return {"ALB": alb, "NOR": _normal(h + 0.15 * fine, 6.0), "RGH": rgh, "MET": met}


def hardware_maps(size=HW_SIZE):
    """Hot-dip galvanised steel: zinc spangle, brush marks and scratches, cold grey-blue."""
    spangle = noise(size, 7, 31)
    fine = noise(size, 26, 32)
    grime = np.clip(noise(size, 4, 34) - 0.45, 0.0, 1.0) * 0.7
    scratch = np.clip(noise(size, 40, 33, (1.0, 0.10)) - 0.70, 0.0, 1.0) * 2.6
    scratch += np.clip(noise(size, 34, 35, (0.10, 1.0)) - 0.78, 0.0, 1.0) * 1.6
    luma = 196.0 + 11.0 * (spangle - 0.5) * 2.0 + 4.0 * (fine - 0.5) - 12.0 * scratch - 7.0 * grime
    luma = np.clip(luma, 183.0, 216.0)
    alb = np.stack([luma * 0.975, luma * 1.0, luma * 1.025], -1)
    alb = np.clip(alb, 0, 250).astype(np.uint8)

    rough = 0.58 + 0.08 * (fine - 0.5) + 0.16 * scratch - 0.04 * (spangle - 0.5) + 0.08 * grime
    rgh = _grey(np.clip(rough, 0.42, 0.85))
    met = np.full((size, size), 255, np.uint8)
    return {"ALB": alb, "NOR": _normal(0.55 * fine + 0.45 * spangle - 0.25 * scratch, 2.6), "RGH": rgh, "MET": met}


def wet_maps(maps):
    alb = np.clip(maps["ALB"].astype(np.float32) * 0.80, 0, 238).astype(np.uint8)
    rgh = np.clip(maps["RGH"].astype(np.float32) * 0.80, 0, 255).astype(np.uint8)
    return {"ALB": alb, "RGH": rgh}


def write_maps(directory, name, set_name, maps, wet=True):
    os.makedirs(directory, exist_ok=True)
    out = []
    for kind, arr in maps.items():
        stem = names.texture_stem(name, set_name, kind)
        assert names.texture_name_problem(stem) is None, stem
        p = os.path.join(directory, stem + ".png")
        rope.write_png(p, arr)
        out.append(p)
    if wet:
        for kind, arr in wet_maps(maps).items():
            stem = names.texture_stem(name, set_name, kind, wet=True)
            assert names.texture_name_problem(stem) is None, stem
            p = os.path.join(directory, stem + ".png")
            rope.write_png(p, arr)
            out.append(p)
    return out


def write_all(asset=ASSET, out_dir=None):
    directory = out_dir or common.textures_dir(asset)
    out = write_maps(directory, SET_NAME, "Rope", rope_maps())
    out += write_maps(directory, SET_NAME, "Hardware", hardware_maps())
    print("[M_Kit_TowLine] wrote %d maps in %s" % (len(out), os.path.relpath(directory, common.REPO_DIR)))
    return out


if __name__ == "__main__":
    write_all(out_dir=sys.argv[1] if len(sys.argv) > 1 else None)
