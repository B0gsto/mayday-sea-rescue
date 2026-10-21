"""M_Kit_HorizontalLift textures (pure numpy, written under the run's out-root textures dir; no AI images).

  T_HorizontalLift_Rope_ALB/NOR/RGH/MET (+_Wet)  1024 px tiling rope trim: faded hi-vis yellow polypropylene,
      3-strand laid rope with sun bleach on the crests, deck dirt packed into the hollows and dried salt bloom,
      plus wet twins for the net coming out of the water.
  T_HorizontalLift_Fittings_ALB/NOR/RGH/MET (+_Wet)  1024 px sheet, four lanes at 512 px each:
      steel (top left)   hot-dip galvanised master ring, bow shackle pin: zinc spangle, brush marks, scratches
      hdpe  (top right)  SOLAS orange HDPE net float: moulded skin, sun-bleached high faces, dock grime
      web   (bottom left)  25 mm black nylon webbing: twill weave, dust, worn selvedge, stitch lines
      retro (bottom right)  retroreflective tape: prismatic grain, scuffed patches, edge stitching
      The part UVs are packed inside their lane at a constant 700 px per metre, so every lane pattern keeps its
      real-world scale.

The hi-vis yellow rope and the SOLAS orange floats are reserved signal colours (docs/05 3.2), so their saturated
pixels go into signal_mask.png next to build.py, which check_textures.py picks up by convention.

Called by build.py (inside Blender, numpy only) with the textures directory, like the other E1/E2 kit assets; the
maps land in the out-root before validate looks for them.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import names  # noqa: E402
import pbrmaps  # noqa: E402
import rope  # noqa: E402

ASSET = "M_Kit_HorizontalLift"
STEM = "HorizontalLift"                 # texture stem: T_<Stem>_<Set>_<Map>
ROPE_SET = "Rope"
FIT_SET = "Fittings"
SIZE = 1024
Q = SIZE // 2
SAT = 0.45
PXM = 700.0                     # fittings lane scale: px per metre (233 px/stud, docs/05 5.3 hero tier)
# lane rects in UV (u0, v0, u1, v1); each holds one material, painted here and sampled by the part UVs build.py makes
LANE = {"steel": (0.02, 0.52, 0.98, 0.98), "hdpe": (0.02, 0.02, 0.98, 0.48), "web": (0.02, 0.02, 0.48, 0.48),
        "retro": (0.52, 0.02, 0.98, 0.48)}


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
    return u + 0.0 * (np.arange(n) + 0.5)[:, None] / n, 0.0 * u + 1.0 - (np.arange(n) + 0.5)[:, None] / n


def _normal(h, strength):
    """OpenGL tangent normal from a height field (tileable: wraps)."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, 1, 0) - np.roll(h, -1, 0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return np.round((n * 0.5 + 0.5) * 255).astype(np.uint8)


def _mix(a, c, k):
    return a + (np.asarray(c, np.float32)[None, None, :] - a) * k[..., None]


def _grey(a):
    return np.clip(a * 255.0, 0, 255).astype(np.uint8)


def _sat(rgb):
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    return np.where(mx > 20, (mx - mn) / np.maximum(mx, 1e-6), 0.0)


# ---------------------------------------------------------------- rope trim (hi-vis yellow polypropylene)
def rope_maps(size=SIZE, seed=17):
    """Weathered hi-vis yellow polypropylene laid rope: strand relief carried by the trim, grime in the hollows,
    sun-bleached crests, dried salt and deck dust. Hue yellow, saturation kept under the 0.45 ceiling."""
    h = rope.trim_height("three_strand", size, seed=seed)          # 0..1 strand relief, matches the mesh twist
    nor = rope.trim_maps("Nylon", "three_strand", size, seed=seed)["NOR"]
    blotch = noise(size, 5, seed + 1)
    fine = noise(size, 22, seed + 2)
    bleach = np.clip((noise(size, 3, seed + 3) - 0.42) * 1.7, 0.0, 1.0)
    grime = np.clip((noise(size, 3, seed + 4) - 0.36) * 1.7, 0.0, 1.0) * (1.15 - h)   # dirt packs in the hollows
    salt = np.clip((noise(size, 40, seed + 5) - 0.74) * 3.2, 0.0, 1.0)
    dust = np.clip((noise(size, 55, seed + 7) - 0.78) * 3.4, 0.0, 1.0)
    shade = (0.46 + 0.54 * h) * (0.92 + 0.16 * (blotch - 0.5)) * (0.96 + 0.08 * (fine - 0.5))
    alb = np.array([198.0, 181.0, 107.0], np.float32)[None, None, :] * shade[..., None] / 255.0
    alb = _mix(alb, (0.83, 0.79, 0.61), 0.50 * bleach)             # sun-bleached strands, still yellow
    alb = _mix(alb, (0.40, 0.36, 0.25), 0.50 * grime)              # deck dirt in the hollows
    alb = _mix(alb, (0.82, 0.79, 0.71), 0.40 * salt)
    alb = _mix(alb, (0.78, 0.76, 0.70), 0.35 * dust)
    lum = alb.mean(axis=2, keepdims=True)
    alb = alb * 0.93 + 0.07 * lum                                        # hold the yellow under the saturation ceiling
    alb = np.clip(alb, 20.0 / 255.0, 238.0 / 255.0)
    rough = 0.60 + 0.14 * (1.0 - h) + 0.08 * grime + 0.06 * salt + 0.05 * dust - 0.07 * bleach
    rough += 0.04 * (noise(size, 22, seed + 6) - 0.5)
    met = np.zeros((size, size), np.uint8)
    return {"ALB": np.round(alb * 255.0).astype(np.uint8), "NOR": nor.copy(),
            "RGH": _grey(np.clip(rough, 0.34, 0.92)), "MET": met}


# ---------------------------------------------------------------- fittings sheet: four lanes
def steel_lane(n=Q, seed=31):
    spangle = noise(n, 7, seed)
    fine = noise(n, 26, seed + 1)
    grime = np.clip(noise(n, 4, seed + 2) - 0.46, 0.0, 1.0) * 0.8
    scratch = np.clip(noise(n, 40, seed + 3, (1.0, 0.10)) - 0.70, 0.0, 1.0) * 2.6
    scratch += np.clip(noise(n, 34, seed + 4, (0.10, 1.0)) - 0.78, 0.0, 1.0) * 1.6
    luma = 197.0 + 10.0 * (spangle - 0.5) * 2.0 + 4.0 * (fine - 0.5) - 11.0 * scratch - 7.0 * grime
    luma = np.clip(luma, 184.0, 214.0)
    alb = np.clip(np.stack([luma * 0.975, luma, luma * 1.025], -1), 0, 250).astype(np.uint8)
    rough = _grey(np.clip(0.55 + 0.08 * (fine - 0.5) + 0.18 * scratch + 0.08 * grime, 0.38, 0.86))
    return alb, rough, _normal(0.55 * fine + 0.45 * spangle - 0.25 * scratch, 2.6)


def hdpe_lane(n=Q, seed=41):
    """SOLAS orange HDPE float: moulding skin, sun-bleached crown, dock grime in the grain."""
    u, v = _uv(n)
    grain = 0.5 + 0.5 * np.cos(2 * np.pi * (24 * u + 24 * v)) * np.cos(2 * np.pi * (10 * u - 10 * v))
    fine = noise(n, 30, seed)
    bleach = np.clip((noise(n, 6, seed + 1) - 0.42) * 1.6, 0.0, 1.0)
    grime = np.clip((noise(n, 4, seed + 2) - 0.46) * 1.9, 0.0, 1.0)
    scuff = np.clip(noise(n, 55, seed + 3, (1.0, 0.25)) - 0.72, 0.0, 1.0) * 2.2
    alb = np.array([0.74, 0.29, 0.10], np.float32)[None, None, :] * (0.80 + 0.20 * grain)[..., None]
    alb = _mix(alb, (0.90, 0.62, 0.42), 0.55 * bleach)                    # sun on the exposed faces
    alb = _mix(alb, (0.30, 0.19, 0.10), 0.45 * grime)
    alb = _mix(alb, (0.58, 0.41, 0.26), 0.5 * scuff)                      # rubbed to the faded skin
    alb = np.clip(alb, 0.12, 0.94)
    rough = _grey(np.clip(0.42 + 0.10 * (fine - 0.5) + 0.16 * grime + 0.10 * scuff - 0.05 * bleach, 0.30, 0.86))
    h = 0.55 * grain + 0.30 * fine + 0.10 * (bleach - 0.5) - 0.35 * scuff
    return (np.round(alb * 255.0).astype(np.uint8), rough, _normal(h, 1.9))


def web_lane(n=Q, seed=51):
    """25 mm black nylon webbing: twill weave running along U, dust, worn and lightened selvedge."""
    u, v = _uv(n)
    weft = 0.5 + 0.5 * np.cos(2 * np.pi * 26 * v)
    twill = ((np.floor(u * 38) + np.floor(v * 26)) % 3 == 0).astype(np.float32)
    fine = noise(n, 34, seed)
    dust = np.clip((noise(n, 7, seed + 1) - 0.44) * 1.7, 0.0, 1.0)
    wear = np.clip((noise(n, 5, seed + 2) - 0.50) * 1.9, 0.0, 1.0)
    alb = np.full((n, n, 3), 0.150, np.float32) * (0.80 + 0.30 * weft)[..., None]
    alb *= (0.88 + 0.16 * twill)[..., None]
    alb = _mix(alb, (0.34, 0.33, 0.30), 0.55 * dust + 0.35 * wear)        # deck dust and sun-bleached rub
    alb = _mix(alb, (0.09, 0.09, 0.10), 0.35 * (1.0 - dust) * (1.0 - wear))
    alb = np.clip(alb, 0.105, 0.70)
    rough = _grey(np.clip(0.84 + 0.06 * (fine - 0.5) - 0.06 * wear, 0.66, 0.95))
    h = 0.55 * weft + 0.35 * twill + 0.10 * fine
    return (np.round(alb * 255.0).astype(np.uint8), rough, _normal(h, 2.2))


def retro_lane(n=Q, seed=61):
    """Retroreflective tape: prismatic grain, scuffed and grubby at the edges, bright grey-silver."""
    u, v = _uv(n)
    prism = 0.5 + 0.5 * np.cos(2 * np.pi * 46 * (u + v)) * np.cos(2 * np.pi * 46 * (u - v))
    fine = noise(n, 40, seed)
    grub = np.clip((noise(n, 5, seed + 1) - 0.48) * 2.1, 0.0, 1.0)
    scuff = np.clip((noise(n, 60, seed + 2, (1.0, 0.2)) - 0.70) * 3.0, 0.0, 1.0)
    alb = 0.72 + 0.16 * prism
    alb = np.clip(alb * (1.0 - 0.30 * grub - 0.22 * scuff), 0.28, 0.92)
    rgb = np.stack([alb * 0.985, alb * 0.99, alb], -1).astype(np.float32)
    rough = _grey(np.clip(0.30 + 0.10 * fine + 0.22 * grub + 0.18 * scuff, 0.22, 0.80))
    h = 0.6 * prism + 0.4 * fine
    return (np.round(rgb * 255.0).astype(np.uint8), rough, _normal(h, 1.6))


def fittings_maps(size=SIZE):
    """The four lanes pasted into one sheet: steel, HDPE (floats), webbing, retro tape."""
    q = size // 2
    alb = np.zeros((size, size, 3), np.uint8)
    rgh = np.zeros((size, size), np.uint8)
    nor = np.zeros((size, size, 3), np.uint8)
    met = np.zeros((size, size), np.uint8)
    lanes = {"steel": steel_lane(q), "hdpe": hdpe_lane(q), "web": web_lane(q), "retro": retro_lane(q)}
    rects = {"steel": (0, 1), "hdpe": (1, 1), "web": (0, 0), "retro": (1, 0)}   # (u, v) quadrant, v counted up
    for key in ("steel", "hdpe", "web", "retro"):
        a, r, n = lanes[key]
        cu, cv = rects[key]
        x0, y0 = cu * q, (1 - cv) * q
        alb[y0:y0 + q, x0:x0 + q] = a
        rgh[y0:y0 + q, x0:x0 + q] = r
        nor[y0:y0 + q, x0:x0 + q] = n
        if key == "steel":
            met[y0:y0 + q, x0:x0 + q] = 255
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


# ---------------------------------------------------------------- assembly
def wet_maps(maps, dark=0.78, gloss=0.75):
    alb = np.clip(maps["ALB"].astype(np.float32) * dark, 0, 238).astype(np.uint8)
    rgh = np.clip(maps["RGH"].astype(np.float32) * gloss, 0, 255).astype(np.uint8)
    return {"ALB": alb, "RGH": rgh}


def write_maps(directory, set_name, maps, wet=False):
    os.makedirs(directory, exist_ok=True)
    out = []
    for kind in ("ALB", "NOR", "RGH", "MET"):
        stem = names.texture_stem(STEM, set_name, kind)
        assert names.texture_name_problem(stem) is None, stem
        p = os.path.join(directory, stem + ".png")
        pbrmaps.write_png(p, maps[kind])
        out.append(p)
    if wet:
        for kind, arr in wet_maps(maps).items():
            stem = names.texture_stem(STEM, set_name, kind, wet=True)
            assert names.texture_name_problem(stem) is None, stem
            p = os.path.join(directory, stem + ".png")
            pbrmaps.write_png(p, arr)
            out.append(p)
    return out


def write_all(asset=ASSET, out_dir=None):
    directory = out_dir or common.textures_dir(asset)
    rope_t, fit_t = rope_maps(SIZE), fittings_maps(SIZE)
    out = write_maps(directory, ROPE_SET, rope_t, wet=True)
    out += write_maps(directory, FIT_SET, fit_t, wet=True)
    for set_name, maps in ((ROPE_SET, rope_t), (FIT_SET, fit_t)):
        sig = np.zeros((SIZE, SIZE), np.float32)
        for t in (maps, wet_maps(maps)):
            sig = np.maximum(sig, (_sat(t["ALB"].astype(np.float32)) > SAT).astype(np.float32))
        pbrmaps.write_png(os.path.join(HERE, "T_%s_%s_signal.png" % (STEM, set_name)), (sig * 255.0).astype(np.uint8))
        print("[%s] %s saturated %.1f%% of the tile is signal colour" % (asset, set_name, 100.0 * sig.mean()))
    print("[%s] maketex: %d maps at %d px in %s"
          % (asset, len(out), SIZE, os.path.relpath(directory, common.REPO_DIR)))
    return out


if __name__ == "__main__":
    write_all(out_dir=sys.argv[1] if len(sys.argv) > 1 else None)
