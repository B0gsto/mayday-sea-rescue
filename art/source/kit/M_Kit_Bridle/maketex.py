"""M_Kit_Bridle textures (pure numpy; written by build.py under the run's out-root; no AI images).

  T_Bridle_Rope_ALB/NOR/RGH/MET (+_Wet)      1024 px tiling rope trim: sun-bleached cream 3-strand polyester tow
      bridle line with a red tracer pair in one strand and a navy marker in the next, deck sediment in the strand
      valleys, dried salt bloom, chafe polish on the crests. rope.trim_height("three_strand") drives the strands,
      the yarns and the normal map, so the trim twist matches the tube's UV tiling (one turn = one tile).
  T_Bridle_Hardware_ALB/NOR/RGH/MET (+_Wet)  1024 px hot-dip galvanised steel for the apex thimble and the bow
      shackle: zinc spangle, brushed marks and workshop scratches, sparse rust freckles, salt, crevice grime near
      the ends of every part (all hardware parts share this square: V runs along a part, U round it, so "V near 0
      or 1" is always an end, where water sits).

Both sets tile in U (round the rope) and V (along it) for the rope; the hardware set is flat (each part's UVs are
remapped into the square). check_textures.py passes both.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import names  # noqa: E402
import rope  # noqa: E402

ASSET = "M_Kit_Bridle"
SET = "Bridle"
ROPE_SIZE = 1024
HW_SIZE = 1024


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
    """OpenGL normal map from a height field (tileable: the gradients wrap)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return np.round((n * 0.5 + 0.5) * 255).astype(np.uint8)


def _grey(a):
    return np.clip(a * 255.0, 0, 255).astype(np.uint8)


def rope_maps(size=ROPE_SIZE):
    """Bleached cream 3-strand polyester tow line: red tracer pair, navy marker, sediment, salt, chafe polish."""
    h = rope.trim_height("three_strand", size, seed=17)                # 0..1 strand + yarn relief
    u, v = _uv(size)
    ph = (3.0 * (u - v)) % 1.0                                         # strand phase (matches the trim height)
    strand = np.floor(3.0 * (u - v)) % 3                               # 0, 1, 2 round the rope
    crest = np.exp(-((ph - 0.5) / 0.10) ** 2)                          # strand crest lines
    valley = 1.0 - crest
    blotch = noise(size, 5, 31)                                        # where the line has lived
    fine = noise(size, 20, 32)                                         # fibre fuzz
    fade = noise(size, 3, 33)                                          # sun bleach, one side of an old coil
    grime = np.clip(noise(size, 4, 34) - 0.40, 0.0, 1.0) * 0.7         # sediment carried into the lay
    soil = np.clip(noise(size, 2, 35) - 0.55, 0.0, 1.0) * 1.8          # one dirty patch round the coil
    salt = np.clip(noise(size, 40, 36) - 0.80, 0.0, 1.0) * 3.2         # sparse dried-salt speckle
    salt = np.clip(salt * (0.45 + 0.75 * valley), 0.0, 1.0)            # salt dries in the valleys

    # yarns: one strand carries a red tracer pair, the next a navy marker; both fade with the rope
    fade_f = 0.55 + 0.75 * fade
    tracer = (np.exp(-((ph - 0.61) / 0.020) ** 2) + 0.85 * np.exp(-((ph - 0.675) / 0.020) ** 2)) * (strand == 0)
    marker = np.exp(-((ph - 0.57) / 0.026) ** 2) * (strand == 1)

    base = np.array([190.0, 183.0, 168.0])
    shade = ((0.70 + 0.34 * h) * (0.90 + 0.14 * blotch) * (0.94 + 0.10 * fade) * (0.97 + 0.06 * (fine - 0.5))
             * (1.0 - 0.30 * grime) * (1.0 - 0.22 * soil))
    mud = np.array([150.0, 138.0, 116.0])[None, None, :]
    alb = base[None, None, :] * shade[..., None]
    alb = alb + (mud - alb) * (0.40 * grime * (0.55 + 0.45 * valley))[..., None]
    alb = alb + (np.array([236.0, 232.0, 220.0])[None, None, :] - alb) * (0.70 * salt)[..., None]
    red = np.array([158.0, 62.0, 54.0])[None, None, :]
    navy = np.array([74.0, 86.0, 108.0])[None, None, :]
    alb = alb + (red - alb) * (tracer * fade_f)[..., None]
    alb = alb + (navy - alb) * (marker * (0.55 + 0.6 * fade))[..., None]
    alb = np.clip(alb, 0, 238).astype(np.uint8)

    # chafe polish: the crests that ride on cleats, fairleads and hands are rubbed smooth and slightly shiny
    rough = (0.62 + 0.10 * (1.0 - h) + 0.05 * (blotch - 0.5) + 0.10 * salt + 0.07 * grime + 0.05 * soil
             - 0.09 * crest * (1.0 - grime))
    rgh = _grey(np.clip(rough, 0.30, 0.92))
    met = np.zeros((size, size), np.uint8)
    return {"ALB": alb, "NOR": _normal(h + 0.17 * fine, 9.0), "RGH": rgh, "MET": met}


def _streaks(n, count, seed, angle=0.0, width=(0.0012, 0.006), length=(0.35, 1.1), soft=2.2):
    """Drawn scratches / flow lines: `count` line segments, tileable by wrapping, 0..1 coverage-ish."""
    r = np.random.default_rng(seed)
    u, v = _uv(n)
    out = np.zeros((n, n), np.float32)
    ca, sa = math.cos(angle), math.sin(angle)
    for _ in range(count):
        x0, y0 = r.random(2)
        ln, wd = r.uniform(*length), r.uniform(*width)
        x1, y1 = x0 + ln * ca, y0 + ln * sa
        dx, dy = x1 - x0, y1 - y0
        for ox in (-1.0, 0.0, 1.0):                       # draw the wrapped copies so the tile stays seamless
            for oy in (-1.0, 0.0, 1.0):
                ax, ay = x0 + ox, y0 + oy
                t = np.clip(((u - ax) * dx + (v - ay) * dy) / max(dx * dx + dy * dy, 1e-9), 0.0, 1.0)
                d = np.sqrt((u - (ax + t * dx)) ** 2 + (v - (ay + t * dy)) ** 2)
                out = np.maximum(out, np.exp(-(d / (wd * soft)) ** 2))
    return out


def hardware_maps(size=HW_SIZE):
    """Hot-dip galvanised steel: zinc spangle, flow lines, workshop scratches, rust freckles, salt at the ends."""
    u, v = _uv(size)
    spangle = noise(size, 20, 41)                                      # zinc crystal spangle
    spangle += 0.6 * noise(size, 64, 49)
    fine = noise(size, 40, 42)
    grime = np.clip(noise(size, 5, 44) - 0.45, 0.0, 1.0) * 0.7
    handle = noise(size, 2, 50)                                        # dull zones vs rubbed-bright zones
    scratch = _streaks(size, 26, 43, angle=math.radians(9.0), width=(0.0009, 0.0035), length=(0.12, 0.55), soft=1.9)
    scratch = np.clip(scratch * 1.35 + np.clip(noise(size, 50, 45, (1.0, 0.12)) - 0.72, 0.0, 1.0) * 1.8, 0.0, 1.4)
    flow = np.clip(noise(size, 9, 51, (0.35, 1.0)) - 0.40, 0.0, 1.0)   # hot-dip flow lines down the part
    # crevice dirt and salt collect at a part's ends (V 0 and 1: holes, threads, the crown of the bow)
    ends = np.exp(-(v / 0.11) ** 2) + np.exp(-((1.0 - v) / 0.11) ** 2)
    ends = np.clip(ends, 0.0, 1.0)
    crev = ends * (0.45 + 0.55 * noise(size, 12, 46))
    salt = np.clip(noise(size, 46, 47) - 0.82, 0.0, 1.0) * 3.0
    spike = np.clip((noise(size, 60, 60) - 0.58) * 4.0, 0.0, 1.0) ** 3.0          # sparse zinc failures
    freck = spike * (0.30 + ends)                                                # worst at a part's ends
    rust = np.clip((freck - 0.30) / 0.70, 0.0, 1.0)                              # the dark freckles themselves
    stain = np.clip(freck * 1.6, 0.0, 1.0) * (1.0 - rust)                        # pale bloom round them

    luma = (193.0 + 13.0 * (spangle - 0.5) * 2.0 + 4.0 * (fine - 0.5) - 15.0 * scratch
            - 10.0 * grime - 9.0 * crev + 6.0 * salt + 7.0 * (handle - 0.5) - 6.0 * flow)
    luma = np.clip(luma, 183.0, 222.0)
    alb = np.stack([luma * 0.972, luma * 1.0, luma * 1.028], -1)       # cool galvanised cast
    alb = alb + (np.array([186.0, 134.0, 104.0])[None, None, :] - alb) * (0.72 * rust)[..., None]
    alb = alb + (np.array([206.0, 184.0, 164.0])[None, None, :] - alb) * (0.45 * stain)[..., None]
    alb = np.clip(alb, 0, 250).astype(np.uint8)

    rough = (0.38 + 0.10 * (fine - 0.5) + 0.22 * scratch - 0.05 * (spangle - 0.5) + 0.10 * grime + 0.13 * crev
             + 0.05 * flow - 0.06 * (handle - 0.5) + 0.24 * np.clip(freck, 0.0, 1.0))
    rgh = _grey(np.clip(rough, 0.22, 0.82))
    met = np.full((size, size), 255, np.uint8)
    return {"ALB": alb,
            "NOR": _normal(0.5 * fine + 0.5 * spangle - 0.30 * scratch + 0.5 * freck + 0.25 * flow, 3.0),
            "RGH": rgh, "MET": met}


def wet_maps(maps):
    """A wet twin: darker albedo, lower roughness (05 5.4); generated from the dry maps."""
    alb = np.clip(maps["ALB"].astype(np.float32) * 0.80, 0, 238).astype(np.uint8)
    rgh = np.clip(maps["RGH"].astype(np.float32) * 0.80, 0, 255).astype(np.uint8)
    return {"ALB": alb, "RGH": rgh}


def write_maps(directory, set_name, maps, wet=True):
    os.makedirs(directory, exist_ok=True)
    out = []
    for kind, arr in maps.items():
        stem = names.texture_stem(SET, set_name, kind)
        assert names.texture_name_problem(stem) is None, stem
        p = os.path.join(directory, stem + ".png")
        rope.write_png(p, arr)
        out.append(p)
    if wet:
        for kind, arr in wet_maps(maps).items():
            stem = names.texture_stem(SET, set_name, kind, wet=True)
            assert names.texture_name_problem(stem) is None, stem
            p = os.path.join(directory, stem + ".png")
            rope.write_png(p, arr)
            out.append(p)
    return out


def write_all(asset=ASSET, out_dir=None):
    directory = out_dir or common.textures_dir(asset)
    out = write_maps(directory, "Rope", rope_maps())
    out += write_maps(directory, "Hardware", hardware_maps())
    print("[%s] wrote %d maps in %s" % (ASSET, len(out), os.path.relpath(directory, common.REPO_DIR)))
    return out


if __name__ == "__main__":
    write_all(out_dir=sys.argv[1] if len(sys.argv) > 1 else None)
