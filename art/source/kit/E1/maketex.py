"""E1 rescue kit atlas maps (system python3 + numpy + Pillow, no Blender).

    python3 art/source/kit/E1/fetch.py       # Poly Haven CC0 scans -> build/e1/src
    python3 art/source/kit/E1/maketex.py

Pack cloth takes the weave (normal, luma, roughness) of the Poly Haven CC0 scan stretch_poplin, webbing the twill of
denim_fabric, rubber the grain of rubberized_track; stainless / chrome reuse the HP2a brushed-metal recipe. Plastics,
foam, foil, rope (tools/blender/rope.py trim heights), retro tape and the labels (generic text, no brands) are
procedural numpy. Every set gets a _Wet twin (porous cloth and rope darker and glossier, plastics a water film, metal
barely). Masters 2048 in masters/, exports 1024 in assets/textures/M_Kit_Atlas/, signal masks next to this file.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import atlas  # noqa: E402  (cached first: the HP2a maketex helpers below then see this atlas)
sys.path.insert(1, os.path.join(ROOT, "tools/blender"))
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("hp2a_maketex", os.path.join(ROOT, "art/source/harbour/M_Hbr_PropAtlas/maketex.py"))
hm = importlib.util.module_from_spec(_spec)
sys.modules["hp2a_maketex"] = hm
_spec.loader.exec_module(hm)
from hp2a_maketex import (blur, clamp_sat, fbm, flat, font, lerp, lum, nor_from_h, nor_vec, noise, periodic, r_plastic,  # noqa: E402
                     r_retro, r_rope, ss, tint, to_images, downsize)

SRC = os.path.join(ROOT, "build/e1/src")
SCAN_M = {"stretch_poplin": 0.29, "denim_fabric": 0.10, "rubberized_track": 2.0}
MASTERS = os.path.join(HERE, "masters")
OUT = os.path.join(ROOT, "assets/textures", atlas.ATLAS_ASSET)
C = atlas.MASTER // atlas.GRID
_c = {}


def scan(pid, short):
    k = (pid, short)
    if k not in _c:
        im = Image.open(os.path.join(SRC, pid, short + ".png"))
        im = im.convert("RGB") if short in ("diff", "nor") else im.convert("L")
        _c[k] = np.asarray(im, np.float32) / 255.0
    return _c[k]


def crop(pid, short, scale_m, n, seed):
    img = scan(pid, short)
    H = img.shape[0]
    px = min(max(16, int(H * scale_m / SCAN_M[pid])), H)
    rng = np.random.default_rng(seed)
    y, x = rng.integers(0, H - px + 1), rng.integers(0, H - px + 1)
    win = img[y:y + px, x:x + px]
    if px < H or True:
        reps = max(1, int(round(scale_m / SCAN_M[pid]))) if px >= H else 1
        if reps > 1:
            win = np.tile(win, (reps, reps, 1) if win.ndim == 3 else (reps, reps))
    if win.ndim == 3:
        out = np.asarray(Image.fromarray((np.clip(win, 0, 1) * 255).astype(np.uint8), "RGB").resize((n, n), Image.LANCZOS), np.float32) / 255.0
    else:
        out = np.asarray(Image.fromarray(win.astype(np.float32), "F").resize((n, n), Image.LANCZOS), np.float32)
    return periodic(out)


def mat(alb, nor, rgh, met=None):
    n = alb.shape[0]
    return {"ALB": alb, "NOR": nor, "RGH": np.clip(rgh, 0.04, 1), "MET": np.zeros(alb.shape[:2], np.float32) if met is None else met}


# ---------------------------------------------------------------- soft goods
def fabric(n, seed, rgb, rough=0.72, pid="stretch_poplin", scale=atlas.T, grime=0.3, stitch=False):
    d = crop(pid, "diff", scale, n, seed)
    nr = crop(pid, "nor", scale, n, seed)
    rr = crop(pid, "rough", scale, n, seed)
    y = lum(d)
    shade = 0.86 + 0.28 * (y - y.mean()) / max(y.std() * 3, 1e-3) + 0.06 * fbm(n, seed + 1, 3)
    alb = tint(rgb, shade)
    g = ss(0.55, 0.9, fbm(n, seed + 2, 4)) * grime                     # grime, salt bloom
    alb = lerp(alb, alb * 0.68 + 14, g)
    salt = ss(0.78, 0.92, fbm(n, seed + 3, 6)) * 0.25
    alb = lerp(alb, np.minimum(alb * 1.15 + 30, 235), salt)
    scuff = ss(0.9, 0.97, noise(n, 40, seed + 4)) * 0.3
    alb = lerp(alb, alb * 0.75 + 22, scuff)
    nor = nor_vec(nr)
    nor = hm.nmix(nor, flat(n), 0.15)
    rgh = rough + 0.15 * (rr - rr.mean()) + 0.1 * g - 0.08 * salt
    return mat(alb, nor, rgh)


def zip_tile(n, seed):
    x = np.arange(n)[None, :].repeat(n, 0) / n
    yv = np.arange(n)[:, None].repeat(n, 1) / n
    teeth = 0.5 + 0.5 * np.cos(2 * np.pi * 48 * x)                  # coil teeth across the length (U)
    band = ss(0.42, 0.38, np.abs(yv - 0.5))
    h = teeth * band * 0.8 + (1 - band) * 0.25 * crop("denim_fabric", "rough", 0.10, n, seed)
    alb = tint((38, 38, 40), 0.9 + 0.2 * h)
    return mat(alb, nor_from_h(h, 4.0), 0.55 + 0.25 * (1 - band))


def foam(n, seed, rgb):
    peel = fbm(n, seed, 24, 3)
    dent = ss(0.62, 0.8, fbm(n, seed + 1, 3))
    crease = ss(0.97, 0.995, np.asarray(Image.fromarray(noise(n, 64, seed + 2)).resize((n, n // 12)).resize((n, n)), np.float32))
    h = peel * 0.25 - dent * 0.6 - crease * 0.5
    alb = tint(rgb, 0.95 + 0.08 * peel - 0.1 * dent)
    gr = ss(0.6, 0.9, fbm(n, seed + 3, 5)) * 0.3
    alb = lerp(alb, alb * 0.7 + 16, gr)
    sc = ss(0.92, 0.98, noise(n, 50, seed + 4)) * 0.5               # black rub marks
    alb = lerp(alb, tint((60, 50, 46), np.ones((n, n), np.float32)), sc)
    return mat(alb, nor_from_h(h, 3.0), 0.5 + 0.15 * gr + 0.15 * sc + 0.1 * dent)


def foil(n, seed, rgb):
    h = np.zeros((n, n), np.float32)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:n, 0:n] / n
    for k in range(40):                                              # crumple: sharp ridges at random angles
        a = rng.uniform(0, np.pi)
        f = rng.uniform(2, 9)
        ph = rng.uniform(0, 1)
        s = (np.cos(a) * xx + np.sin(a) * yy) * f + ph
        tri = np.abs((s % 1.0) - 0.5) * 2
        h += (tri - 0.5) * rng.uniform(0.2, 1.0) / f
    h = (h - h.min()) / (h.max() - h.min())
    h = h * 0.8 + 0.2 * fbm(n, seed, 16, 2)
    nor = nor_from_h(h, 14.0)
    alb = tint(rgb, 0.94 + 0.1 * fbm(n, seed + 1, 6))
    rgh = 0.16 + 0.12 * ss(0.5, 0.9, fbm(n, seed + 2, 5))
    return mat(alb, nor, rgh, np.ones((n, n), np.float32))


def clear_pvc(n, seed, rgb, rough):
    v = fbm(n, seed, 6)
    alb = tint(rgb, 0.95 + 0.08 * v)
    return mat(alb, nor_from_h(v * 0.3, 2.0), rough + 0.1 * ss(0.6, 0.9, v))


def cross_patch(w, h, seed):
    im = Image.new("RGB", (w, h), (0, 118, 62))
    d = ImageDraw.Draw(im)
    s = min(w, h)
    t = s * 0.2
    cx, cy = w / 2, h / 2
    d.rectangle([cx - t / 2, cy - s * 0.34, cx + t / 2, cy + s * 0.34], fill=(236, 236, 230))
    d.rectangle([cx - s * 0.34, cy - t / 2, cx + s * 0.34, cy + t / 2], fill=(236, 236, 230))
    d.rectangle([2, 2, w - 3, h - 3], outline=(230, 230, 224), width=max(2, s // 40))
    return _patch(im, seed)


def oxy_patch(w, h, seed):
    im = Image.new("RGB", (w, h), (32, 40, 66))
    d = ImageDraw.Draw(im)
    d.rectangle([3, 3, w - 4, h - 4], outline=(0, 128, 70), width=max(3, h // 18))
    f = font(int(h * 0.55))
    tw = d.textlength("OXYGEN", font=f)
    d.text(((w - tw) / 2, h * 0.17), "OXYGEN", font=f, fill=(236, 236, 232))
    return _patch(im, seed)


def _patch(im, seed):
    w, h = im.size
    a = np.asarray(im, np.float32)
    n = max(w, h)
    weave = np.asarray(Image.fromarray(crop("stretch_poplin", "rough", 0.12, n, seed)).resize((w, h)), np.float32)
    a = a * (0.92 + 0.16 * weave[..., None])
    g = np.asarray(Image.fromarray(fbm(n, seed + 1, 4)).resize((w, h)), np.float32)
    a = lerp(a, a * 0.75 + 12, ss(0.6, 0.9, g) * 0.35)
    return mat(a, nor_from_h(weave * 0.5, 2.0), 0.7 + 0.1 * weave)


def ring_fit(w, h, seed):
    return hm.f_ring(w, h, seed)


# ---------------------------------------------------------------- hard goods
def plastic(n, seed, rgb, rough, scuff=0.25, grain=0.5):
    return r_plastic(n, seed, rgb, rough, scuff=scuff, grain=grain)


def rubber(n, seed):
    nr = crop("rubberized_track", "nor", 0.6, n, seed)
    rr = crop("rubberized_track", "rough", 0.6, n, seed)
    v = fbm(n, seed, 6)
    alb = tint((38, 38, 39), 0.92 + 0.12 * v)
    dust = ss(0.65, 0.9, fbm(n, seed + 1, 5)) * 0.35
    alb = lerp(alb, tint((120, 116, 108), np.ones((n, n), np.float32)), dust * 0.3)
    return mat(alb, hm.nmix(nor_vec(nr), flat(n), 0.5), 0.78 + 0.1 * (rr - rr.mean()) + 0.1 * dust)


def chrome(n, seed, rgb):
    m = hm.m_stainless(n, seed)
    a = m["ALB"] * (np.array(rgb, np.float32) / 200.0)[None, None, :]
    return dict(m, ALB=np.clip(a, 180, 250), RGH=np.clip(m["RGH"] * 0.6, 0.08, 1))


def painted_cyl(n, seed):
    m = r_plastic(n, seed, (226, 226, 220), 0.38, scuff=0.15, grain=0.2)
    chip = ss(0.9, 0.96, noise(n, 30, seed + 7))
    m["ALB"] = lerp(m["ALB"], tint((150, 152, 155), np.ones((n, n), np.float32)), chip * 0.8)
    m["RGH"] = np.clip(m["RGH"] + chip * 0.1, 0, 1)
    return m


def lens(n, seed, rgb, rough, ribs=True):
    x = np.arange(n)[None, :].repeat(n, 0) / n
    h = (0.5 + 0.5 * np.cos(2 * np.pi * 24 * x)) * (0.6 if ribs else 0.0) + 0.3 * fbm(n, seed, 12, 2)
    alb = tint(rgb, 0.95 + 0.06 * h)
    return mat(alb, nor_from_h(h, 2.5), rough + 0.1 * fbm(n, seed + 1, 8))


def composition(n, seed):
    g = noise(n, n / 3, seed)
    alb = tint((196, 48, 44), 0.85 + 0.25 * g)
    return mat(alb, nor_from_h(g * 0.6, 3.0), 0.82 + 0.1 * g)


def _label(w, h, seed, bg, draw_fn, rough=0.42, vertical=False):
    """Printed plastic / paper label: drawn at the surface aspect, stretched to the region, scuffed."""
    if vertical:
        im = Image.new("RGB", (h * 2, w), bg)
    else:
        im = Image.new("RGB", (w, h), bg)
    draw_fn(ImageDraw.Draw(im), im.size)
    if vertical:
        im = im.rotate(90, expand=True)
    im = im.resize((w, h), Image.LANCZOS)
    a = np.asarray(im, np.float32)
    n = max(w, h)
    sc = np.asarray(Image.fromarray(ss(0.9, 0.97, noise(n, 60, seed))).resize((w, h)), np.float32)
    g = np.asarray(Image.fromarray(fbm(n, seed + 1, 4)).resize((w, h)), np.float32)
    a = lerp(a, a * 0.8 + 30, sc * 0.5)
    a = lerp(a, a * 0.78 + 10, ss(0.6, 0.9, g) * 0.3)
    hh = 0.2 * g - 0.4 * sc
    return mat(a, nor_from_h(hh, 2.0), rough + 0.2 * sc)


def _lines(d, x, y, w, rows, gap, fill):
    for k in range(rows):
        L = w * (0.55 + 0.45 * ((k * 37) % 11) / 10.0)
        d.rectangle([x, y + k * gap, x + L, y + k * gap + max(1, gap * 0.35)], fill=fill)


def hand_label(w, h, seed):
    def draw(d, size):
        W, H = size
        # U round the body (W), V along it (H): the text band faces the user on one side
        d.rectangle([0, 0, W, H], fill=(186, 32, 26))
        f1, f2 = font(int(H * 0.13)), font(int(H * 0.07))
        x0 = W * 0.08
        d.text((x0, H * 0.06), "RED HAND FLARE", font=f1, fill=(240, 236, 228))
        d.text((x0, H * 0.24), "SOLAS  DISTRESS SIGNAL", font=f2, fill=(240, 236, 228))
        d.rectangle([x0, H * 0.36, W * 0.46, H * 0.62], fill=(236, 232, 222))
        _lines(d, x0 + 6, H * 0.39, W * 0.36, 5, H * 0.045, (40, 30, 28))
        d.polygon([(W * 0.62, H * 0.62), (W * 0.70, H * 0.36), (W * 0.78, H * 0.62)], fill=(240, 236, 228))
        d.text((W * 0.58, H * 0.66), "THIS END UP", font=f2, fill=(240, 236, 228))
        _lines(d, x0, H * 0.78, W * 0.8, 3, H * 0.06, (232, 210, 200))
    return _label(w, h, seed, (186, 32, 26), draw, vertical=False)


def para_label(w, h, seed):
    def draw(d, size):
        W, H = size        # drawn with the length along W, then rotated so it runs along V
        d.rectangle([0, 0, W, H], fill=(182, 30, 24))
        f1, f2 = font(int(H * 0.16)), font(int(H * 0.08))
        d.text((W * 0.05, H * 0.08), "PARACHUTE ROCKET  RED", font=f1, fill=(240, 236, 228))
        d.rectangle([W * 0.05, H * 0.34, W * 0.60, H * 0.70], fill=(236, 232, 222))
        _lines(d, W * 0.07, H * 0.38, W * 0.5, 6, H * 0.05, (40, 30, 28))
        d.polygon([(W * 0.70, H * 0.38), (W * 0.92, H * 0.52), (W * 0.70, H * 0.66)], fill=(240, 236, 228))
        d.text((W * 0.65, H * 0.74), "FIRE UPWARDS", font=f2, fill=(240, 236, 228))
    return _label(w, h, seed, (182, 30, 24), draw, vertical=True)


def cyl_label(w, h, seed):
    def draw(d, size):
        W, H = size
        d.rectangle([0, 0, W, H], fill=(230, 230, 224))
        d.rectangle([0, 0, W, H * 0.08], fill=(0, 118, 62))
        d.rectangle([0, H * 0.92, W, H], fill=(0, 118, 62))
        f1, f2 = font(int(H * 0.16)), font(int(H * 0.07))
        d.text((W * 0.06, H * 0.16), "MEDICAL OXYGEN", font=f1, fill=(30, 34, 36))
        d.text((W * 0.06, H * 0.40), "O2  CD  460 L   200 bar", font=f2, fill=(30, 34, 36))
        _lines(d, W * 0.06, H * 0.56, W * 0.42, 6, H * 0.055, (70, 74, 76))
        cx, cy, r = W * 0.72, H * 0.52, H * 0.26
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=(0, 118, 62), outline=(240, 240, 236))
        d.text((cx - H * 0.04, cy - H * 0.02), "2", font=f2, fill=(240, 240, 236))
        cx2 = W * 0.90
        d.polygon([(cx2, cy - r * 0.8), (cx2 + r * 0.8, cy), (cx2, cy + r * 0.8), (cx2 - r * 0.8, cy)], fill=(232, 200, 30), outline=(30, 30, 30))
    return _label(w, h, seed, (230, 230, 224), draw, rough=0.38)


def vhf_face(w, h, seed):
    def draw(d, size):
        W, H = size
        d.rectangle([0, 0, W, H], fill=(48, 50, 53))
        # speaker grille
        for j in range(5):
            for i in range(9):
                x, y = W * (0.12 + 0.095 * i), H * (0.05 + 0.03 * j)
                d.ellipse([x, y, x + W * 0.05, y + W * 0.05], fill=(24, 24, 26))
        # LCD
        d.rectangle([W * 0.08, H * 0.24, W * 0.92, H * 0.46], fill=(120, 132, 110), outline=(30, 30, 32), width=4)
        f1, f2, f3 = font(int(H * 0.13)), font(int(H * 0.035)), font(int(H * 0.03))
        d.text((W * 0.40, H * 0.26), "16", font=f1, fill=(34, 40, 34))
        d.text((W * 0.12, H * 0.28), "CH", font=f2, fill=(34, 40, 34))
        d.text((W * 0.12, H * 0.38), "HI  1W", font=f2, fill=(34, 40, 34))
        for k in range(5):
            d.rectangle([W * (0.12 + 0.07 * k), H * 0.34, W * (0.17 + 0.07 * k), H * 0.36], fill=(34, 40, 34))
        # keypad
        keys = [["16/9", "SCAN", "H/L"], ["UP", "DW", "DN"], ["MENU", "WX", "LOCK"], ["CALL", "MOB", "ENT"]]
        for r_, row in enumerate(keys):
            for c_, k in enumerate(row):
                x0, y0 = W * (0.08 + 0.29 * c_), H * (0.52 + 0.11 * r_)
                fill = (196, 40, 32) if k == "16/9" else (70, 72, 76)
                d.rounded_rectangle([x0, y0, x0 + W * 0.26, y0 + H * 0.085], radius=int(W * 0.04), fill=fill, outline=(28, 28, 30), width=3)
                tw = d.textlength(k, font=f3)
                d.text((x0 + W * 0.13 - tw / 2, y0 + H * 0.022), k, font=f3, fill=(226, 226, 222))
        f4 = font(int(H * 0.028))
        d.text((W * 0.24, H * 0.965), "MARINE VHF", font=f4, fill=(160, 162, 164))
    m = _label(w, h, seed, (48, 50, 53), draw, rough=0.55)
    # keys proud (height from the drawn key colour), LCD glossy
    a = m["ALB"]
    key = (np.abs(a[..., 0] - 70) < 30) & (np.abs(a[..., 2] - 76) < 30) | (a[..., 0] > 170) & (a[..., 1] < 80)
    lcd = (a[..., 1] > 100) & (a[..., 1] < 150) & (a[..., 0] < 140) & (a[..., 2] < 125)
    hgt = blur(key.astype(np.float32), 3) - 0.3 * blur(lcd.astype(np.float32), 2)
    m["NOR"] = nor_from_h(hgt, 6.0)
    m["RGH"] = np.where(lcd, 0.12, np.where(key, 0.65, m["RGH"]))
    return m


SOLAS = (232, 86, 36)
HIVIS = (214, 238, 22)
RECIPES = {
    "SolasNylon": lambda n, s: fabric(n, s, SOLAS, 0.70),
    "NavyNylon": lambda n, s: fabric(n, s, (34, 42, 66), 0.74),
    "HiVisNylon": lambda n, s: fabric(n, s, HIVIS, 0.66),
    "Webbing": lambda n, s: fabric(n, s, (36, 36, 38), 0.78, pid="denim_fabric", scale=0.14, grime=0.2),
    "Retro": lambda n, s: r_retro(n, s),
    "ZipBlack": zip_tile,
    "FoamSolas": lambda n, s: foam(n, s, SOLAS),
    "FoilGold": lambda n, s: foil(n, s, (226, 186, 108)),
    "FoilSilver": lambda n, s: foil(n, s, (216, 218, 222)),
    "MaskPVC": lambda n, s: clear_pvc(n, s, (196, 214, 204), 0.12),
    "TubeGreen": lambda n, s: clear_pvc(n, s, (126, 186, 150), 0.22),
    "RopeThrow": lambda n, s: r_rope(n, s, (232, 212, 44), "braid", 0.62, dirt=0.2),
    "RopeGrab": lambda n, s: r_rope(n, s, (212, 208, 198), "braid", 0.66, dirt=0.35),
    "VHFBody": lambda n, s: plastic(n, s, (56, 58, 62), 0.6, scuff=0.2, grain=0.8),
    "HiVisABS": lambda n, s: plastic(n, s, HIVIS, 0.42),
    "BlackABS": lambda n, s: plastic(n, s, (40, 40, 42), 0.46),
    "Rubber": rubber,
    "Stainless": lambda n, s: hm.m_stainless(n, s),
    "Brass": lambda n, s: chrome(n, s, (214, 214, 216)),
    "CylWhite": painted_cyl,
    "GreyABS": lambda n, s: plastic(n, s, (118, 122, 126), 0.5),
    "FlareRed": lambda n, s: plastic(n, s, (186, 32, 26), 0.45, scuff=0.15),
    "SolasABS": lambda n, s: plastic(n, s, SOLAS, 0.4),
    "LensClear": lambda n, s: lens(n, s, (222, 224, 224), 0.18),
    "LensRed": composition,
}
FITS = {"CrossPatch": cross_patch, "OxyPatch": oxy_patch, "RingFit": ring_fit, "VHFFace": vhf_face, "CylLabel": cyl_label,
        "HandLabel": hand_label, "ParaLabel": para_label}
POROUS = ("SolasNylon", "NavyNylon", "HiVisNylon", "Webbing", "ZipBlack", "RopeThrow", "RopeGrab", "CrossPatch", "OxyPatch",
          "LensRed")


def wet(m, key):
    met = m["MET"]
    if key in POROUS:
        dk, gloss = 0.62, 0.5
    elif met.mean() > 0.5:
        dk, gloss = 0.92, 0.3
    else:
        dk, gloss = 0.82, None
    alb = np.maximum(m["ALB"] * dk, 26)
    if gloss is None:   # water film on plastic, foam, labels, foil
        rgh = np.clip(m["RGH"] * 0.35 + 0.04, 0.06, 1)
    else:
        rgh = np.clip(m["RGH"] * (1 - gloss) + 0.04, 0.08, 1)
    return dict(m, ALB=alb, RGH=rgh)


def build_set(set_name, size):
    maps = {"ALB": np.full((size, size, 3), 128, np.float32), "NOR": flat(size), "RGH": np.full((size, size), 0.7, np.float32),
            "MET": np.zeros((size, size), np.float32), "A": np.ones((size, size), np.float32)}
    wmaps = {k: v.copy() for k, v in maps.items()}
    wmaps["ALB"][:] = 92
    wmaps["RGH"][:] = 0.4
    sig = np.zeros((size, size), np.uint8)
    for i, (key, r) in enumerate(sorted(atlas.R.items())):
        if r[6] != set_name:
            continue
        cx, cy, cw, ch = r[:4]
        w, h = cw * C, ch * C
        seed = 401 + 37 * i
        m = FITS[key](w, h, seed) if key in FITS else RECIPES[key](w, seed)
        mw = wet(m, key)
        y0, x0 = size - (cy + ch) * C, cx * C
        for dst, src in ((maps, m), (wmaps, mw)):
            for k in ("ALB", "NOR", "RGH", "MET"):
                dst[k][y0:y0 + h, x0:x0 + w] = src[k]
        if r[7]:
            sig[y0:y0 + h, x0:x0 + w] = 255
        print("  %s %s %dx%d" % (set_name, key, w, h), flush=True)
    return maps, wmaps, sig


def main():
    os.makedirs(MASTERS, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for set_name in atlas.SETS:
        maps, wmaps, sig = build_set(set_name, atlas.MASTER)
        for suffix, m in (("", maps), ("_Wet", wmaps)):
            for k, im in to_images(m, False).items():
                if suffix and k in ("NOR", "MET"):
                    continue
                fn = "T_%s_%s_%s%s.png" % (atlas.NAME, set_name, k, suffix)
                im.save(os.path.join(MASTERS, fn), optimize=True)
                downsize(im, atlas.EXPORT, k).save(os.path.join(OUT, fn), optimize=True)
        Image.fromarray(sig, "L").resize((atlas.EXPORT, atlas.EXPORT), Image.NEAREST).save(
            os.path.join(HERE, "T_%s_%s_signal.png" % (atlas.NAME, set_name)))
        print("wrote set", set_name, flush=True)


if __name__ == "__main__":
    main()
