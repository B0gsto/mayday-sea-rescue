"""Bosun LP: one 1024 swatch-atlas set (ALB / NOR / RGH / MET) for the segmented low-poly dog.

Faces are UV'd to small swatches inside shaded zones (coat top-to-under gradient, harness, webbing, tape,
eyes, nose, tongue). Form comes from the low-poly geometry; the atlas carries only colour, a subtle
top-lighter gradient, and roughness. Pure numpy, safe inside Blender.
"""
import os

import numpy as np

try:
    import pbrmaps
except ImportError:  # direct Blender runs add tools/blender to sys.path first
    pbrmaps = None

SIZE = 1024
REGIONS = {
    "coat": (0.00, 0.50, 0.00, 0.50),
    "harness": (0.52, 0.72, 0.00, 0.50),
    "webbing": (0.74, 0.82, 0.00, 0.50),
    "tape": (0.84, 1.00, 0.00, 0.50),
    "eye": (0.52, 0.60, 0.52, 0.60),
    "highlight": (0.62, 0.70, 0.52, 0.60),
    "nose": (0.72, 0.80, 0.52, 0.60),
    "tongue": (0.82, 0.90, 0.52, 0.60),
    "inner": (0.92, 1.00, 0.52, 0.60),
}
ROUGH = {"coat": 0.86, "harness": 0.55, "webbing": 0.78, "tape": 0.32, "eye": 0.16,
         "highlight": 0.22, "nose": 0.30, "tongue": 0.46, "inner": 0.74}


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def _rect(zone, w=SIZE, h=SIZE):
    u0, u1, v0, v1 = REGIONS[zone]
    return int(u0 * w), int(u1 * w), int((1.0 - v1) * h), int((1.0 - v0) * h)


def _gradient(img, zone, top, bottom, rng, noise=0.012, bands=0.0):
    x0, x1, y0, y1 = _rect(zone, img.shape[1], img.shape[0])
    t = np.linspace(0.0, 1.0, max(y1 - y0, 1), dtype=np.float32)[:, None, None]
    top, bottom = _hex(top), _hex(bottom)
    col = top[None, None, :] * (1.0 - t) + bottom[None, None, :] * t
    col = np.repeat(col, max(x1 - x0, 1), axis=1)
    if bands:
        col *= (1.0 + bands * np.sin(np.linspace(0, np.pi * 14, max(y1 - y0, 1)))[:, None, None])
    col += rng.normal(0.0, noise, col.shape).astype(np.float32)
    img[y0:y1, x0:x1] = np.clip(col, 0.0, 1.0)


def _plain(img, zone, colour, rng, noise=0.01, pattern=None):
    x0, x1, y0, y1 = _rect(zone, img.shape[1], img.shape[0])
    col = np.empty((y1 - y0, x1 - x0, 3), dtype=np.float32)
    col[:] = _hex(colour)
    col += rng.normal(0.0, noise, col.shape).astype(np.float32)
    if pattern == "weave":
        xs = np.arange(x1 - x0)[None, :, None]
        col *= np.where((xs // 3) % 2 == 0, 1.06, 0.94)
    elif pattern == "tape":
        xs, ys = np.meshgrid(np.arange(x1 - x0), np.arange(y1 - y0))
        col *= np.where(((xs + ys) // 6) % 2 == 0, 1.05, 0.96)[..., None]
    img[y0:y1, x0:x1] = np.clip(col, 0.0, 1.0)


def make(size=SIZE, seed=7):
    rng = np.random.default_rng(seed)
    alb = np.empty((size, size, 3), dtype=np.float32)
    alb[:] = _hex("#1E1C1E")
    alb += rng.normal(0.0, 0.006, alb.shape).astype(np.float32)

    _gradient(alb, "coat", "#332E32", "#1E1C1E", rng, noise=0.010, bands=0.035)
    _gradient(alb, "harness", "#FF7A1F", "#C64A00", rng, noise=0.020, bands=0.05)
    _plain(alb, "webbing", "#24272D", rng, noise=0.010, pattern="weave")
    _plain(alb, "tape", "#D9DCDF", rng, noise=0.012, pattern="tape")
    _plain(alb, "eye", "#3B2414", rng, noise=0.010)
    _plain(alb, "highlight", "#F3EFE4", rng, noise=0.008)
    _gradient(alb, "nose", "#242124", "#1B191B", rng, noise=0.006)
    _plain(alb, "tongue", "#C9707E", rng, noise=0.010)
    _plain(alb, "inner", "#3B2729", rng, noise=0.010)

    rgh = np.empty((size, size), dtype=np.float32)
    rgh[:] = 0.86
    rgh += rng.normal(0.0, 0.022, rgh.shape).astype(np.float32)
    for zone in REGIONS:
        x0, x1, y0, y1 = _rect(zone, size, size)
        rgh[y0:y1, x0:x1] = ROUGH[zone] + rng.normal(0.0, 0.015, (y1 - y0, x1 - x0)).astype(np.float32)
    rgh = np.clip(rgh, 0.0, 1.0)

    nor = np.empty((size, size, 3), dtype=np.float32)
    nor[..., 0] = 0.5 + rng.normal(0.0, 0.006, (size, size)).astype(np.float32)
    nor[..., 1] = 0.5 + rng.normal(0.0, 0.006, (size, size)).astype(np.float32)
    nor[..., 2] = 1.0
    nor = np.clip(nor, 0.0, 1.0)

    met = np.zeros((size, size), dtype=np.float32)
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


def write(out_dir, name="Bosun", set_name="Coat", size=SIZE, seed=7):
    maps = make(size, seed)
    if pbrmaps is None:
        raise RuntimeError("coattex needs tools/blender on sys.path for write_png")
    for kind, arr in maps.items():
        path = os.path.join(out_dir, "T_%s_%s_%s.png" % (name, set_name, kind))
        pbrmaps.write_png(path, arr)
    return [os.path.join(out_dir, "T_%s_%s_%s.png" % (name, set_name, k)) for k in maps]
