"""Generate the TravelHoist yard atlas (system python3 + Pillow + numpy).

The bake step provides a first pass, but the hoist is a TILING asset: repeated bake AO/curvature
patches across the large beams read as a grid. This script overwrites the six maps with seam-free
procedural paint / galvanised steel / rubber / glass / hazard / webbing, then draws the 35 T plates.
It also writes the saturation signal mask.

    python3 art/source/harbour/M_Hbr_TravelHoist/maketex.py
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
TEX = os.path.join(ROOT, "build/prod/M_Hbr_TravelHoist/textures/M_Hbr_TravelHoist")
SIZE = 2048
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
INK = (34, 34, 32)

ALB = np.zeros((SIZE, SIZE, 3), np.float32)
RGH = np.zeros((SIZE, SIZE), np.float32)
MET = np.zeros((SIZE, SIZE), np.float32)
NOR = np.full((SIZE, SIZE, 3), 128, np.uint8)
NOR[..., 2] = 255


def full_box(region):
    u0, v0, u1, v1 = layout.REG[region]
    return int(u0 * SIZE), int((1 - v1) * SIZE), int(u1 * SIZE), int((1 - v0) * SIZE)


def noise(n, beta=2.0, seed=0, sx=1.0, sy=1.0):
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((n, n)))
    fx = np.fft.fftfreq(n)[:, None] * sx
    fy = np.fft.fftfreq(n)[None, :] * sy
    r = np.sqrt(fx * fx + fy * fy)
    filt = 1.0 / (r ** beta + 0.004)
    filt[0, 0] = 0.0
    out = np.real(np.fft.ifft2(f * filt))
    out -= out.mean()
    out /= out.std() + 1e-9
    return out


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def streaks(n, seed, sigma=38.0, beta=1.2):
    """Periodic vertical streaks: low-pass noise in Y only, then contrast."""
    a = noise(n, beta=beta, seed=seed)
    spec = np.fft.fft2(a)
    fy = np.fft.fftfreq(n)[:, None]
    spec *= np.exp(-2.0 * (np.pi * sigma * fy) ** 2)
    a = np.real(np.fft.ifft2(spec))
    a -= a.min()
    a /= a.max() + 1e-9
    return a


def normal(h, strength=2.5):
    h = h.astype(np.float32)
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    v = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    v /= np.linalg.norm(v, axis=-1, keepdims=True)
    return ((v * 0.5 + 0.5) * 255).astype(np.uint8)


def region_mask(region):
    l, t, r, b = full_box(region)
    m = np.zeros((SIZE, SIZE), dtype=bool)
    m[t:b, l:r] = True
    return m


def paint(n, seed=1):
    base = np.array((44, 88, 117), np.float32) / 255
    low = noise(n, 2.3, seed)
    mid = noise(n, 1.1, seed + 1)
    fine = noise(n, 0.35, seed + 2)
    alb = base[None, None, :] * (0.94 + 0.05 * low[..., None] + 0.035 * mid[..., None])
    st = streaks(n, seed + 3)
    rust = smoothstep(0.58, 0.86, st) * 0.62
    alb = alb * (1 - rust[..., None]) + (np.array((82, 55, 40), np.float32) / 255) * rust[..., None]
    chips = smoothstep(0.60, 0.80, fine) * 0.65
    alb = alb * (1 - chips[..., None]) + (np.array((66, 70, 71), np.float32) / 255) * chips[..., None]
    r = 0.55 + 0.07 * low + 0.20 * rust + 0.14 * chips
    h = 0.22 * fine + 0.30 * rust + 0.12 * mid
    return alb, r, np.zeros_like(r), h


def steel(n, seed=11):
    base = np.array((150, 154, 157), np.float32) / 255
    mott = noise(n, 1.8, seed)
    spang = noise(n, 0.55, seed + 1)
    fine = noise(n, 0.30, seed + 2)
    alb = base[None, None, :] * (0.975 + 0.030 * mott[..., None] + 0.015 * spang[..., None])
    st = streaks(n, seed + 3)
    rust = smoothstep(0.63, 0.90, st)
    alb = alb * (1 - rust[..., None] * 0.9) + (np.array((118, 92, 72), np.float32) / 255) * rust[..., None] * 0.9
    dirt = smoothstep(0.72, 0.95, mott) * 0.35
    alb = alb * (1 - dirt[..., None]) + (np.array((116, 114, 108), np.float32) / 255) * dirt[..., None]
    metal = (rust < 0.05) & (dirt < 0.04)
    r = np.where(metal, 0.44 + 0.12 * mott, 0.82)
    met = np.zeros((n, n), np.float32)
    h = 0.22 * spang + 0.18 * fine + 0.35 * rust + 0.1 * mott
    return alb, r, met, h


def white(n, seed=21):
    base = np.array((215, 212, 200), np.float32) / 255
    low = noise(n, 2.0, seed)
    fine = noise(n, 0.4, seed + 1)
    alb = base[None, None, :] * (0.95 + 0.04 * low[..., None])
    st = streaks(n, seed + 2)
    grime = smoothstep(0.60, 0.88, st) * 0.45
    alb = alb * (1 - grime[..., None]) + (np.array((140, 134, 118), np.float32) / 255) * grime[..., None]
    rust = smoothstep(0.80, 0.96, st) * 0.55
    alb = alb * (1 - rust[..., None]) + (np.array((142, 108, 82), np.float32) / 255) * rust[..., None]
    r = 0.60 + 0.06 * low + 0.25 * grime
    h = 0.2 * fine + 0.25 * grime
    return alb, r, np.zeros_like(r), h


def rubber(n, seed=31):
    base = np.array((42, 44, 45), np.float32) / 255
    fine = noise(n, 0.35, seed)
    low = noise(n, 2.0, seed + 1)
    alb = base[None, None, :] * (1.0 + 0.09 * fine[..., None] + 0.03 * low[..., None])
    scuff = smoothstep(0.82, 0.98, fine) * 0.28
    alb = alb * (1 - scuff[..., None]) + (np.array((83, 83, 80), np.float32) / 255) * scuff[..., None]
    r = 0.84 + 0.05 * fine
    h = 0.35 * fine
    return alb, r, np.zeros_like(r), h


def glass(n, seed=41):
    base = np.array((45, 58, 64), np.float32) / 255
    smudge = noise(n, 2.6, seed)
    fine = noise(n, 0.4, seed + 1)
    alb = base[None, None, :] * (0.98 + 0.03 * smudge[..., None] + 0.015 * fine[..., None])
    r = 0.07 + 0.035 * smudge + 0.015 * fine
    h = 0.05 * fine + 0.03 * smudge
    return alb, np.clip(r, 0.03, 0.18), np.zeros((n, n), np.float32), h


def hazard(n, seed=51):
    yy, xx = np.mgrid[0:n, 0:n]
    stripe = (((xx + yy) // 64) % 2) == 0
    alb = np.zeros((n, n, 3), np.float32)
    alb[:] = (np.array((196, 154, 30), np.float32) / 255)
    alb[stripe] = np.array((36, 36, 34), np.float32) / 255
    grime = noise(n, 1.4, seed) * 0.03
    alb = np.clip(alb + grime[..., None], 0, 1)
    r = np.where(stripe, 0.52, 0.58) + 0.03 * noise(n, 0.5, seed + 1)
    h = 0.08 * noise(n, 0.5, seed + 2)
    return alb, r, np.zeros((n, n), np.float32), h


def fabric(n, seed, base_rgb):
    base = np.array(base_rgb, np.float32) / 255
    yy, xx = np.mgrid[0:n, 0:n]
    weave = ((xx % 4 == 0) | (yy % 4 == 0)).astype(np.float32)
    twill = (((xx + yy) % 6) == 0).astype(np.float32)
    alb = base[None, None, :] * (1.0 + 0.05 * noise(n, 0.5, seed)[..., None])
    alb *= (1.0 - 0.045 * weave[..., None]) * (1.0 - 0.025 * twill[..., None])
    for fx in (0.07, 0.93):
        x = int(fx * n)
        for y in range(4, n - 4, 22):
            alb[y:y + 11, max(0, x - 2):min(n, x + 2), :] *= 0.72
    r = np.full((n, n), 0.90, np.float32) + 0.02 * noise(n, 1.0, seed + 1)
    h = 0.25 * weave + 0.15 * twill
    return alb, r, np.zeros((n, n), np.float32), h


def sign_base(w, h, seed=61):
    base = np.array((226, 222, 210), np.float32) / 255
    a = noise(max(w, h), 2.0, seed)[:h, :w]
    alb = base[None, None, :] * (0.98 + 0.02 * np.resize(a, (h, w))[..., None])
    r = np.full((h, w), 0.45, np.float32)
    hgt = 0.04 * np.resize(a, (h, w))
    return alb, r, np.zeros((h, w), np.float32), hgt


def put(region, alb, rgh, met, nor):
    l, t, r, b = full_box(region)
    ALB[t:b, l:r] = alb
    RGH[t:b, l:r] = rgh
    MET[t:b, l:r] = met
    NOR[t:b, l:r] = nor


def build_atlas():
    for region, fn, size in (
            ("paint", paint, 1024), ("steel", steel, 1024), ("rubber", rubber, 512),
            ("white", white, 512), ("glass", glass, 512), ("hazard", hazard, 512),
            ("blue", lambda n: fabric(n, 71, (46, 92, 136)), 512),
            ("orange", lambda n: fabric(n, 81, (192, 96, 30)), 512)):
        alb, r, m, h = fn(size)
        put(region, alb, r, m, normal(h))
    l, t, r, b = full_box("sign")
    w, h = r - l, b - t
    alb, r, m, hgt = sign_base(w, h)
    put("sign", alb, r, m, normal(hgt))


def draw_sign(im, wet=False):
    d = ImageDraw.Draw(im)
    l, t, r, b = layout.pixel_box("sign", SIZE)
    w, h = r - l, b - t
    ink = tuple(int(c * (0.78 if wet else 1.0)) for c in INK)
    d.rectangle([l + 10, t + 10, r - 10, b - 10], outline=ink, width=7)
    for cx, cy in ((l + 34, t + 34), (r - 34, t + 34), (l + 34, b - 34), (r - 34, b - 34)):
        d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=ink)

    def centered(text, size, y):
        f = ImageFont.truetype(FONT, size)
        bb = d.textbbox((0, 0), text, font=f)
        d.text((l + (w - (bb[2] - bb[0])) / 2 - bb[0], y), text, font=f, fill=ink)

    centered("CAPACITY", 44, t + 26)
    centered("35 T", 214, t + 88)
    centered("SAFE WORKING LOAD", 36, b - 66)


def main():
    build_atlas()
    alb = Image.fromarray(np.clip(ALB * 255, 0, 255).astype(np.uint8))
    rgh = Image.fromarray(np.clip(RGH * 255, 0, 255).astype(np.uint8), "L")
    met = Image.fromarray(np.clip(MET * 255, 0, 255).astype(np.uint8), "L")
    alb_w = Image.fromarray(np.clip(ALB * 255 * 0.76, 0, 255).astype(np.uint8))
    rgh_w = Image.fromarray(np.clip(RGH * 255 * 0.52, 0, 255).astype(np.uint8), "L")
    for im, wet in ((alb, False), (alb_w, True)):
        draw_sign(im, wet)
    os.makedirs(TEX, exist_ok=True)
    alb.save(os.path.join(TEX, "T_TravelHoist_Yard_ALB.png"))
    alb_w.save(os.path.join(TEX, "T_TravelHoist_Yard_ALB_Wet.png"))
    rgh.save(os.path.join(TEX, "T_TravelHoist_Yard_RGH.png"))
    rgh_w.save(os.path.join(TEX, "T_TravelHoist_Yard_RGH_Wet.png"))
    met.save(os.path.join(TEX, "T_TravelHoist_Yard_MET.png"))
    Image.fromarray(NOR, "RGB").save(os.path.join(TEX, "T_TravelHoist_Yard_NOR.png"))
    mask = np.zeros((SIZE, SIZE), np.uint8)
    for region in ("paint", "blue", "orange", "hazard"):
        mask[region_mask(region)] = 255
    Image.fromarray(mask).save(os.path.join(HERE, "signal_mask.png"))
    print("wrote atlas", os.path.relpath(TEX, ROOT))


if __name__ == "__main__":
    main()
