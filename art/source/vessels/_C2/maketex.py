"""C2 texture sets (system python3 + numpy + Pillow, no heavy slot): the Gale Queen ferry and the SOLAS liferaft.
CC0 Poly Haven scans (blue_metal_plate, rusty_painted_metal, rust_coarse_01, concrete_floor_painted, denim_fabric,
fabric_leather_01) graded and zoned procedurally (paint, rust weeps, salt, antifouling, slime, weed, barnacles, seams,
retro tape, lettering). No AI images. Every set ships dry + _Wet (ALB / RGH). Masters 2048 in build/c2/masters,
shipped at 1024 (common.SHIP_SIZE) to assets/textures/<Asset>/.

    python3 art/source/vessels/_C2/maketex.py [hull super deck fittings glass decals canopy tubes]

UV conventions (the build files follow them):
  T_GaleQueen_Hull      U tiles every 6 m along the length; V = hull zones: 0 keel centreline .. 0.50 design
                        waterline (girth) .. 1.0 sheer (height). 0..0.50 faded red antifouling with slime, weed and
                        barnacles; 0.50..0.545 black boot-top; 0.545..0.955 navy topsides; 0.955..0.985 white sheer line.
  T_GaleQueen_Super     U tiles every 4 m along a wall; V = 0..2.5 m up from the deck (white painted steel).
  T_GaleQueen_Deck      tiling 4 m both ways (green anti-slip deck paint, walk-worn).
  T_GaleQueen_Fittings  trim strips, U tiles every 1 m, 8 bands in V (see BANDS).
  T_GaleQueen_Glass     one window per 0..1 square (glass, black frit, aluminium edge).
  T_GaleQueen_Decals    RGBA atlas, alpha cut-out (see DECALS rects).
  T_Liferaft_Canopy     U tiles 4x round the canopy, V hem (0) .. apex (1): SOLAS orange, retro tape, seams.
  T_Liferaft_Tubes      trim strips, U tiles every 1 m (see RAFT_BANDS).
"""
import json
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
sys.path.insert(0, G + "tools/blender")
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location("s1a_maketex", G + "art/source/seabed/_S1a/maketex.py")
_s1a = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_s1a)
fbm, sm, lum, normal, stamps, Image_blur, desat = (_s1a.fbm, _s1a.sm, _s1a.lum, _s1a.normal, _s1a.stamps, _s1a.Image_blur,
                                                   _s1a.desat)  # S1a helpers, pure numpy
import pbrmaps  # noqa: E402

SRC = G + "build/c2/src"
MASTERS = G + "build/c2/masters"
VES = G + "art/source/vessels/"
SHIP, M = 1024, 2048
UA = {"User-Agent": "MaydaySeaRescue-C2/1.0"}
SCANS = ["blue_metal_plate", "rusty_painted_metal", "rust_coarse_01", "concrete_floor_painted", "denim_fabric", "fabric_leather_01"]
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_N = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"

BANDS = {  # T_GaleQueen_Fittings: name -> (v0, v1)
    "rail_white": (0.000, 0.125), "galv": (0.125, 0.250), "rubber": (0.250, 0.375), "grp": (0.375, 0.500),
    "bronze": (0.500, 0.625), "orange": (0.625, 0.750), "rope": (0.750, 0.875), "machinery": (0.875, 1.000)}
RAFT_BANDS = {"tube": (0.00, 0.40), "floor": (0.40, 0.55), "ramp": (0.55, 0.70), "webbing": (0.70, 0.80),
              "lifeline": (0.80, 0.90), "ballast": (0.90, 1.00)}
DECALS = {  # T_GaleQueen_Decals rects (u0, v0, u1, v1), UV space (v up)
    "name": (0.02, 0.80, 0.98, 0.98), "port": (0.02, 0.62, 0.98, 0.78), "draught": (0.02, 0.02, 0.22, 0.60),
    "muster": (0.26, 0.40, 0.60, 0.60), "raft": (0.64, 0.40, 0.98, 0.60), "crew": (0.26, 0.22, 0.60, 0.38),
    "pax": (0.64, 0.22, 0.98, 0.38), "imo": (0.26, 0.04, 0.98, 0.18)}


def fetch(pid):
    d = os.path.join(SRC, pid)
    os.makedirs(d, exist_ok=True)
    out, files = {}, None
    for key in ("Diffuse", "Rough", "Displacement"):
        p = os.path.join(d, key + ".png")
        if not os.path.exists(p):
            if files is None:
                with urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + pid, headers=UA), timeout=60) as r:
                    files = json.loads(r.read())
            if key not in files:
                continue
            with urllib.request.urlopen(urllib.request.Request(files[key]["2k"]["png"]["url"], headers=UA), timeout=300) as r:
                open(p, "wb").write(r.read())
        img = Image.open(p)
        if key == "Diffuse":
            a = np.asarray(img.convert("RGB").resize((M, M), Image.LANCZOS), np.float32) / 255.0
        else:
            a = np.asarray(img.convert("I;16") if img.mode.startswith("I") else img.convert("L"), np.float32)
            a = np.asarray(Image.fromarray((a / max(a.max(), 1) * 65535).astype(np.uint16)).resize((M, M), Image.BILINEAR), np.float32) / 65535.0
        out[key] = a
    out.setdefault("Displacement", lum(out["Diffuse"]))
    out.setdefault("Rough", np.full((M, M), 0.6, np.float32))
    return out


_cache = {}


def scan(pid):
    if pid not in _cache:
        _cache[pid] = fetch(pid)
    return _cache[pid]


def detail(pid, lo=-1.0, hi=1.0):
    """The scan's luma detail, zero mean, about -1..1 (scaled by its 2..98 percentile spread)."""
    l = lum(scan(pid)["Diffuse"])
    a, b = np.percentile(l, (2, 98))
    return np.clip((l - (a + b) / 2) / max((b - a) / 2, 1e-4), lo, hi)


def rgb(*c):
    return np.array(c, np.float32) / 255.0


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim == 2 and (np.shape(a)[-1:] == (3,) or np.shape(b)[-1:] == (3,)):
        t = t[..., None]
    return a * (1 - t) + b * t


def coords():
    y, x = np.mgrid[0:M, 0:M].astype(np.float32)
    return (x + 0.5) / M, 1.0 - (y + 0.5) / M      # U, V (V up)


def band(V, v0, v1, soft=0.002):
    return sm(v0 - soft, v0 + soft, V) * (1 - sm(v1 - soft, v1 + soft, V))


def lines(C, period, width, soft=1.5):
    """Thin lines every `period` (UV units) in coordinate array C: 1 on the line."""
    d = np.abs(((C / period + 0.5) % 1.0) - 0.5) * period * M
    return 1 - sm(width * M / 2, width * M / 2 + soft, d)


def streaks(U, V, seed, count, top, length, width, wrap_u=True):
    """Vertical run-down streaks (rust weeps, drips) starting at V=top[i] going down `length` (UV)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((M, M), np.float32)
    n = fbm(M, 30, 200, 1.0, seed + 1, aniso=(1.0, 0.15))
    for _ in range(count):
        u0 = rng.random()
        t0 = top if np.isscalar(top) else rng.uniform(*top)
        ln = rng.uniform(0.4, 1.0) * length
        w = rng.uniform(0.5, 1.5) * width
        du = np.abs(((U - u0 + 0.5) % 1.0) - 0.5) if wrap_u else np.abs(U - u0)
        prof = np.clip(1 - du / (w * (1 + 0.8 * (t0 - V) / max(ln, 1e-3))), 0, 1)
        along = np.clip((t0 - V) / ln, 0, 1)
        fade = (V <= t0) * (1 - along) ** 1.3 * sm(0.0, 0.03, t0 - V + 0.03)
        out = np.maximum(out, prof * fade * rng.uniform(0.5, 1.0))
    return np.clip(out * (0.6 + 0.6 * n), 0, 1)


def save(asset, stem, alb, nor, rgh, met, alpha=None, signal=None, wet=(0.30, 0.30), smax=0.44, wet_mask=None):
    """Dry + _Wet maps. Saturation limited outside `signal` (written as the check_textures signal mask)."""
    out = G + "assets/textures/" + asset
    os.makedirs(out, exist_ok=True)
    os.makedirs(MASTERS, exist_ok=True)
    alb = np.clip(alb, 0, 1)
    if signal is None:
        alb = desat(alb, smax)
    else:
        hard = np.asarray(Image.fromarray((np.clip(signal, 0, 1) * 255 + 0.5).astype(np.uint8)).filter(ImageFilter.MinFilter(5)),
                          np.float32) / 255.0 > 0.6
        keep = np.asarray(Image.fromarray((hard * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(9)), np.float32) > 127
        alb = np.where(keep[..., None], alb, desat(alb, smax))     # saturated only well inside the written mask
        sig = Image.fromarray((hard * 255).astype(np.uint8)).resize((SHIP, SHIP), Image.BILINEAR)
        sig = sig.point(lambda p: 255 if p > 127 else 0)
        sig.save(os.path.join(VES, asset, stem + "_signal.png"))
    alb = pbrmaps.clamp_albedo(alb, met) if hasattr(pbrmaps, "clamp_albedo") else alb
    l = lum(alb)[..., None]
    alb = np.where(l < 32 / 255, alb + (32 / 255 - l), alb)
    l = lum(alb)[..., None]
    alb = np.where(l > 236 / 255, alb * (236 / 255) / np.maximum(l, 1e-4), alb)
    alb = np.clip(alb, 0, 1)
    rgh = np.clip(rgh, 0.04, 1)
    wa, wr = pbrmaps.wet(alb, rgh, darken=wet[0], gloss=wet[1], floor=0.05)
    if wet_mask is not None:       # parts that are always wet (below the waterline) change less
        k = np.clip(wet_mask, 0, 1)
        wa = mix(wa, alb * (1 - wet[0] * 0.55), k)
        wr = mix(wr, np.minimum(rgh, rgh - wet[1] * 0.5), k)
    l = lum(wa)[..., None]
    wa = np.where(l < 30 / 255, wa + (30 / 255 - l), wa)
    maps = {"ALB": alb, "NOR": np.clip(nor, 0, 1), "RGH": rgh, "MET": np.clip(met, 0, 1), "ALB_Wet": np.clip(wa, 0, 1),
            "RGH_Wet": np.clip(wr, 0.04, 1)}
    for k, a in maps.items():
        a8 = (a * 255 + 0.5).astype(np.uint8)
        im = Image.fromarray(a8, "RGB" if a8.ndim == 3 else "L")
        if alpha is not None and k.startswith("ALB"):
            im = im.convert("RGBA")
            im.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8), "L"))
        im.save(os.path.join(MASTERS, "%s_%s.png" % (stem, k)))
        im.resize((SHIP, SHIP), Image.LANCZOS).save(os.path.join(out, "%s_%s.png" % (stem, k)))
    print("wrote", stem, "albedo luma %.0f..%.0f" % (lum(alb).min() * 255, lum(alb).max() * 255))


def rust_colour(seed=0):
    r = scan("rust_coarse_01")["Diffuse"]
    return np.roll(r, seed * 397, axis=1)


# ------------------------------------------------------------------ hull
def hull_set():
    U, V = coords()
    pm = scan("blue_metal_plate")
    dpm = detail("blue_metal_plate")
    drp = detail("rusty_painted_metal")
    rust = rust_colour(1)
    n1 = fbm(M, 2, 40, 1.6, 11)
    n2 = fbm(M, 20, 300, 1.2, 12)
    n3 = fbm(M, 4, 60, 1.4, 13, aniso=(1.0, 0.35))
    wl = 0.50
    af = 1 - sm(wl - 0.002, wl + 0.002, V)
    boot = band(V, wl, 0.545)
    top = band(V, 0.545, 0.955)
    sheer = band(V, 0.955, 0.985)
    cap = sm(0.983, 0.987, V)
    # base paints
    af_col = mix(rgb(150, 66, 54), rgb(122, 58, 50), n1) * (1 + 0.10 * dpm[..., None])
    af_col = mix(af_col, rgb(168, 92, 76), sm(0.55, 0.85, n3) * 0.5)            # chalky, leached antifouling
    navy = mix(rgb(38, 50, 70), rgb(46, 58, 76), n1) * (1 + 0.12 * dpm[..., None])
    alb = af_col * af[..., None] + rgb(46, 46, 48) * boot[..., None] + navy * top[..., None] \
        + rgb(214, 214, 206) * sheer[..., None] + rgb(60, 62, 66) * cap[..., None]
    h = 0.15 * scan("blue_metal_plate")["Displacement"]
    rgh = 0.78 * af + 0.55 * boot + 0.42 * top + 0.40 * sheer + 0.55 * cap + 0.06 * n2
    met = np.zeros((M, M), np.float32)
    # plating: frames every 0.5 m (hungry horse dishing), butts every 2 m, strake seams
    fr = 0.5 / 6.0
    dish = (np.cos(((U / fr) % 1.0) * 2 * np.pi) * 0.5 + 0.5) * (V > 0.52) * (V < 0.95)
    h -= 0.25 * (1 - dish) * (0.6 + 0.4 * n1)
    seams = np.maximum(lines(U, 2.0 / 6.0, 0.0018), np.maximum(lines(V - 0.25, 1.0, 0.0018), lines(V - 0.78, 1.0, 0.0018)))
    h += 0.6 * seams
    alb = mix(alb, alb * 0.82, seams * 0.6)
    # topsides wear: rust weeps from the sheer and the butts, chips, fender scrapes, salt
    weeps = streaks(U, V, 21, 40, (0.93, 0.97), 0.35, 0.004) * top
    seam_weeps = streaks(U, V, 22, 30, (0.70, 0.80), 0.18, 0.003) * top
    w = np.clip(weeps + seam_weeps * 0.8, 0, 1)
    rcol = mix(rust, rgb(120, 62, 34), 0.4)
    alb = mix(alb, rcol * 0.85 + navy * 0.15, w * 0.75)
    chips = sm(0.74, 0.88, drp * 0.5 + 0.5) * sm(0.65, 0.85, fbm(M, 4, 60, 1.5, 23)) * (top + sheer)
    alb = mix(alb, rcol, chips * 0.9)
    h -= 0.4 * chips
    rgh = mix(rgh, 0.85, np.clip(w + chips, 0, 1))
    scr = sm(0.72, 0.9, fbm(M, 3, 80, 1.2, 24, aniso=(0.12, 1.0))) * band(V, 0.60, 0.88, 0.03)
    alb = mix(alb, rgb(120, 124, 126), scr * 0.55)
    bare = scr * sm(0.6, 0.8, n2)
    met = np.maximum(met, bare * 0.55)
    alb = mix(alb, rgb(150, 150, 148), bare * 0.6)
    salt = sm(0.45, 0.9, fbm(M, 6, 200, 1.1, 25)) * (1 - sm(0.55, 0.75, V)) * (V > wl + 0.01)
    alb = mix(alb, rgb(196, 196, 188), salt * 0.45)
    rgh = mix(rgh, 0.8, salt * 0.6)
    # boot-top: green slime fringe at its lower edge and a scum line at the waterline
    slime_wl = band(V, wl - 0.07, wl + 0.012, 0.01) * sm(0.3, 0.7, fbm(M, 6, 120, 1.2, 26))
    # antifouling: slime film up toward the waterline, weed filaments, barnacles, scrubbed patches
    zone = sm(0.25, wl - 0.01, V) * af
    slime = np.clip(zone * (0.4 + 0.8 * fbm(M, 3, 90, 1.3, 27)), 0, 1)
    alb = mix(alb, rgb(84, 86, 52), np.clip(slime * 0.7 + slime_wl * 0.8, 0, 1))
    rgh = mix(rgh, 0.48, np.clip(slime + slime_wl, 0, 1))
    weed_n = fbm(M, 60, 500, 0.9, 28, aniso=(1.0, 0.08))     # strands along V
    weed = sm(0.62, 0.78, weed_n) * sm(0.32, wl, V) * af * sm(0.35, 0.65, fbm(M, 4, 40, 1.4, 29))
    weed = np.clip(weed + sm(0.66, 0.8, weed_n) * slime_wl, 0, 1)
    alb = mix(alb, mix(rgb(48, 74, 38), rgb(70, 86, 40), n2), weed * 0.9)
    h += 0.5 * weed
    rgh = mix(rgh, 0.42, weed)
    bmask = (af * (1 - sm(0.40, 0.48, V)) * sm(0.45, 0.75, fbm(M, 3, 30, 1.5, 30))).astype(np.float32)
    barn = stamps(M, 2600, 2.5, 7.0, bmask, 31)
    alb = mix(alb, mix(rgb(176, 170, 156), rgb(140, 136, 124), n2), sm(0.05, 0.3, barn))
    h += 1.2 * barn
    rgh = mix(rgh, 0.85, sm(0.05, 0.3, barn))
    scrub = sm(0.72, 0.85, fbm(M, 3, 30, 1.5, 32)) * af * (V < 0.42)
    alb = mix(alb, rgb(112, 108, 104), scrub * 0.6)           # grey primer where the antifouling has scrubbed off
    nor = normal(Image_blur(h, 0.7), 5.0)
    save("M_Veh_GaleQueen", "T_GaleQueen_Hull", alb, nor, rgh, met, signal=1 - sm(wl - 0.012, wl - 0.004, V),
         wet_mask=af, wet=(0.38, 0.32))


# ------------------------------------------------------------------ superstructure (white)
def super_set():
    U, V = coords()
    dpm = detail("rusty_painted_metal")
    rust = rust_colour(2)
    n1 = fbm(M, 2, 40, 1.6, 41)
    n2 = fbm(M, 20, 300, 1.2, 42)
    white = mix(rgb(222, 222, 214), rgb(206, 207, 200), n1) * (1 + 0.04 * dpm[..., None])
    alb = white.copy()
    h = 0.1 * scan("rusty_painted_metal")["Displacement"]
    rgh = 0.40 + 0.08 * n2
    met = np.zeros((M, M), np.float32)
    seams = np.maximum(lines(U, 0.25, 0.0016), lines(V - 0.42, 1.0, 0.0016))
    stiff = (np.cos(((U / 0.15) % 1.0) * 2 * np.pi) * 0.5 + 0.5)
    h += 0.5 * seams - 0.15 * stiff
    alb = mix(alb, alb * 0.86, seams * 0.5)
    # rust weeps from the roof edge and from fittings, rust round seams, grime at the foot, salt
    weeps = np.clip(streaks(U, V, 43, 12, (0.92, 1.0), 0.55, 0.0025) + streaks(U, V, 44, 8, (0.45, 0.75), 0.3, 0.002), 0, 1) * 0.8
    rcol = mix(rust, rgb(132, 72, 40), 0.35)
    alb = mix(alb, mix(rcol, white, 0.35), weeps * 0.8)
    patch = sm(0.70, 0.85, fbm(M, 3, 30, 1.6, 45))
    chips = sm(0.80, 0.92, dpm * 0.5 + 0.5) * patch + seams * sm(0.72, 0.85, n2) * 0.6
    chips = np.clip(chips, 0, 1)
    alb = mix(alb, rcol * 0.9, chips * 0.85)
    h -= 0.4 * chips
    rgh = mix(rgh, 0.86, np.clip(weeps * 0.5 + chips, 0, 1))
    foot = (1 - sm(0.0, 0.10, V)) * (0.6 + 0.4 * fbm(M, 8, 80, 1.2, 46))
    alb = mix(alb, rgb(104, 98, 86), foot * 0.6)
    rgh = mix(rgh, 0.7, foot)
    salt = sm(0.5, 0.9, fbm(M, 6, 200, 1.1, 47))
    alb = mix(alb, rgb(232, 230, 222), salt * 0.25)
    soot = sm(0.6, 0.9, fbm(M, 2, 20, 1.6, 48)) * sm(0.6, 1.0, V)
    alb = mix(alb, rgb(150, 148, 140), soot * 0.35)        # exhaust soot film high on the walls
    nor = normal(Image_blur(h, 0.7), 4.0)
    save("M_Veh_GaleQueen", "T_GaleQueen_Super", alb, nor, rgh, met, wet=(0.36, 0.30))


# ------------------------------------------------------------------ deck
def deck_set():
    U, V = coords()
    grit = detail("concrete_floor_painted")
    rust = rust_colour(3)
    n1 = fbm(M, 2, 30, 1.6, 51)
    n2 = fbm(M, 30, 400, 1.0, 52)
    green = mix(rgb(78, 98, 80), rgb(70, 86, 72), n1) * (1 + 0.10 * grit[..., None])
    alb = green
    h = 0.35 * scan("concrete_floor_painted")["Displacement"] + 0.25 * n2
    rgh = 0.70 + 0.08 * n2
    met = np.zeros((M, M), np.float32)
    wear = sm(0.55, 0.78, fbm(M, 2, 24, 1.7, 53)) * (0.7 + 0.3 * n2)
    alb = mix(alb, rgb(112, 112, 106), wear * 0.75)
    deep = sm(0.80, 0.92, fbm(M, 2, 24, 1.7, 53) + 0.25 * n2)
    alb = mix(alb, rust, deep * 0.8)
    rgh = mix(rgh, 0.6, wear * 0.5)
    seams = np.maximum(lines(U, 0.5, 0.0016), lines(V, 0.5, 0.0016))
    h += 0.7 * seams
    seam_rust = seams * sm(0.4, 0.7, fbm(M, 10, 120, 1.2, 54))
    bleed = Image_blur(seam_rust, 6.0) * 1.6
    alb = mix(alb, mix(rust, green, 0.5), np.clip(bleed, 0, 0.7))
    alb = mix(alb, alb * 0.8, seams * 0.5)
    stains = sm(0.7, 0.9, fbm(M, 3, 40, 1.4, 55))
    alb = mix(alb, rgb(70, 72, 64), stains * 0.35)
    salt = sm(0.6, 0.95, fbm(M, 6, 200, 1.1, 56))
    alb = mix(alb, rgb(186, 186, 178), salt * 0.3)
    nor = normal(Image_blur(h, 0.6), 5.0)
    save("M_Veh_GaleQueen", "T_GaleQueen_Deck", alb, nor, rgh, met, wet=(0.40, 0.42))


# ------------------------------------------------------------------ fittings trim
def fittings_set():
    U, V = coords()
    rust = rust_colour(4)
    n1 = fbm(M, 3, 40, 1.5, 61)
    n2 = fbm(M, 30, 300, 1.1, 62)
    dpm = detail("rusty_painted_metal")
    alb = np.zeros((M, M, 3), np.float32)
    rgh = np.zeros((M, M), np.float32)
    met = np.zeros((M, M), np.float32)
    h = np.zeros((M, M), np.float32)
    sig = np.zeros((M, M), np.float32)
    rel = {}
    for k, (v0, v1) in BANDS.items():
        b = band(V, v0, v1, 0.0005)
        rel[k] = (b, (V - v0) / (v1 - v0))
    spots = sm(0.68, 0.8, dpm * 0.5 + 0.5) * sm(0.5, 0.75, fbm(M, 10, 150, 1.3, 63))
    weeps = streaks(U, np.clip(V, 0, 1), 64, 30, (0.0, 1.0), 0.06, 0.004)
    b, r = rel["rail_white"]
    c = mix(rgb(220, 220, 212), rgb(200, 200, 192), n1)
    c = mix(c, rust, np.clip(spots + weeps * 0.6, 0, 1) * 0.85)
    alb += c * b[..., None]; rgh += b * mix(0.38, 0.85, spots); h += b * (-0.4 * spots)
    b, r = rel["galv"]
    c = mix(rgb(204, 206, 202), rgb(186, 188, 184), fbm(M, 20, 300, 0.9, 65))      # spangled galvanising
    c = mix(c, rgb(214, 214, 206), sm(0.5, 0.8, n1) * 0.5)                           # white rust bloom
    c = mix(c, rust, spots * 0.5)
    alb += c * b[..., None]; rgh += b * (0.5 + 0.15 * n2); met += b * np.where(spots > 0.3, 0.0, 0.9)
    b, r = rel["rubber"]
    c = mix(rgb(44, 44, 46), rgb(58, 58, 58), n2)
    c = mix(c, rgb(120, 118, 110), sm(0.6, 0.85, fbm(M, 3, 60, 1.2, 66, aniso=(0.15, 1.0))) * 0.45)   # quay scuffs
    alb += c * b[..., None]; rgh += b * 0.82; h += b * (0.4 * fbm(M, 60, 400, 0.8, 67))
    b, r = rel["grp"]
    c = mix(rgb(214, 212, 200), rgb(190, 188, 176), n1)
    straps = lines(U, 0.25, 0.012) * 1.0
    c = mix(c, rgb(60, 62, 64), straps)                                                # black canister bands
    c = mix(c, rgb(150, 140, 110), (1 - sm(0.0, 0.2, r)) * 0.5 + weeps * 0.3)         # grime at the seam / drain
    seam = lines(r - 0.5, 1.0, 0.004)
    h += b * (0.5 * seam + 0.3 * straps)
    c = mix(c, rgb(120, 118, 110), seam * 0.6)
    alb += c * b[..., None]; rgh += b * mix(0.35, 0.7, straps)
    b, r = rel["bronze"]
    c = mix(rgb(214, 180, 128), rgb(198, 162, 112), n1)
    slm = sm(0.5, 0.8, n2) > 0.5
    c = np.where(slm[..., None], mix(rgb(84, 92, 60), rgb(96, 100, 66), n1), c)        # verdigris / slime
    alb += c * b[..., None]; rgh += b * (0.35 + 0.3 * n2); met += b * np.where(slm, 0.0, 0.92)
    b, r = rel["orange"]
    c = mix(rgb(222, 92, 34), rgb(198, 80, 30), n1)
    tape = band(r, 0.35, 0.65, 0.01) * lines(U, 0.25, 0.06, 2.0)
    c = mix(c, rgb(196, 198, 196), tape)
    c = mix(c, rgb(150, 140, 120), sm(0.6, 0.9, n2) * 0.25)
    alb += c * b[..., None]; rgh += b * mix(0.55, 0.3, tape); sig += b * (1 - tape)
    b, r = rel["rope"]
    strand = (np.sin((U * 120 + r * 3.0) * 2 * np.pi) * 0.5 + 0.5)
    c = mix(rgb(210, 160, 40), rgb(170, 128, 34), strand)                             # yellow polypropylene line
    c = mix(c, rgb(120, 110, 80), sm(0.6, 0.9, n1) * 0.4)
    alb += c * b[..., None]; rgh += b * 0.7; h += b * strand; sig += b
    b, r = rel["machinery"]
    c = mix(rgb(70, 74, 78), rgb(56, 58, 62), n1)
    c = mix(c, rust, spots * 0.8)
    c = mix(c, rgb(46, 44, 42), sm(0.55, 0.9, r) * sm(0.4, 0.7, n2) * 0.7)            # soot at the top
    alb += c * b[..., None]; rgh += b * mix(0.45, 0.85, spots)
    l = lum(alb)
    alb = np.where((met > 0.3)[..., None], alb * np.maximum(1.0, (190 / 255) / np.maximum(l, 1e-3))[..., None], alb)
    met = np.where(Image_blur((met > 0.5).astype(np.float32), 2.0) > 0.98, met, 0.0)    # metal only well inside its bands
    nor = normal(Image_blur(h, 0.6), 4.0)
    save("M_Veh_GaleQueen", "T_GaleQueen_Fittings", alb, nor, rgh, met, signal=sig, wet=(0.36, 0.32))


# ------------------------------------------------------------------ glass
def glass_set():
    U, V = coords()
    e = np.minimum(np.minimum(U, 1 - U), np.minimum(V, 1 - V))
    frame = 1 - sm(0.025, 0.03, e)
    frit = (1 - sm(0.10, 0.11, e)) * (1 - frame)
    glass = 1 - frame - frit
    n1 = fbm(M, 3, 40, 1.4, 71)
    alb = rgb(40, 48, 54) * glass[..., None] + rgb(34, 34, 36) * frit[..., None] + rgb(198, 200, 198) * frame[..., None]
    haze = sm(0.45, 0.85, fbm(M, 20, 400, 0.9, 72)) * 0.6 + streaks(U, V, 73, 40, (0.6, 1.0), 0.7, 0.002) * 0.6
    haze = np.clip(haze * glass, 0, 1)
    alb = mix(alb, rgb(120, 124, 124), haze * 0.35)
    rgh = 0.06 * glass + 0.5 * frit + 0.4 * frame + 0.3 * haze
    met = 0.85 * frame
    h = frame * 0.6 + 0.2 * frit
    nor = normal(Image_blur(h, 1.0), 3.0)
    save("M_Veh_GaleQueen", "T_GaleQueen_Glass", alb, nor, rgh, met, wet=(0.12, 0.05))


# ------------------------------------------------------------------ decals
def decals_set():
    im = Image.new("L", (M, M), 0)        # alpha
    col = Image.new("RGB", (M, M), (226, 226, 220))
    d, dc = ImageDraw.Draw(im), ImageDraw.Draw(col)

    def rect(key):
        u0, v0, u1, v1 = DECALS[key]
        return int(u0 * M), int((1 - v1) * M), int(u1 * M), int((1 - v0) * M)

    def text(key, s, font, fill_rgb=(226, 226, 220)):
        x0, y0, x1, y1 = rect(key)
        size = int((y1 - y0) * 0.9)
        f = ImageFont.truetype(font, size)
        while d.textlength(s, font=f) > (x1 - x0) * 0.96:
            size -= 4
            f = ImageFont.truetype(font, size)
        bb = d.textbbox((0, 0), s, font=f)
        x = x0 + ((x1 - x0) - (bb[2] - bb[0])) / 2 - bb[0]
        y = y0 + ((y1 - y0) - (bb[3] - bb[1])) / 2 - bb[1]
        d.text((x, y), s, font=f, fill=255)
        dc.text((x, y), s, font=f, fill=fill_rgb)
    text("name", "GALE QUEEN", FONT)
    text("port", "PORT HAVEN", FONT)
    # draught marks (metres): 1M .. 2M with 0.2 m marks in 0.1 m numerals
    x0, y0, x1, y1 = rect("draught")
    hh = (y1 - y0) / 6.0
    f = ImageFont.truetype(FONT, int(hh * 0.8))
    for i, s in enumerate(["2M", "8", "6", "4", "2", "1M"]):
        y = y0 + i * hh
        d.text((x0 + 10, y), s, font=f, fill=255)
        dc.text((x0 + 10, y), s, font=f, fill=(226, 226, 220))

    def sign(key, s, bg, fg, s2=None):
        x0, y0, x1, y1 = rect(key)
        d.rounded_rectangle((x0, y0, x1, y1), radius=18, fill=255)
        dc.rounded_rectangle((x0, y0, x1, y1), radius=18, fill=bg)
        dc.rounded_rectangle((x0 + 10, y0 + 10, x1 - 10, y1 - 10), radius=12, outline=fg, width=6)
        f = ImageFont.truetype(FONT, int((y1 - y0) * (0.34 if s2 else 0.5)))
        while dc.textlength(s, font=f) > (x1 - x0) * 0.86:
            f = ImageFont.truetype(FONT, f.size - 4)
        bb = dc.textbbox((0, 0), s, font=f)
        yy = y0 + (y1 - y0) * (0.30 if s2 else 0.5) - (bb[3] - bb[1]) / 2 - bb[1]
        dc.text((x0 + ((x1 - x0) - (bb[2] - bb[0])) / 2 - bb[0], yy), s, font=f, fill=fg)
        if s2:
            f2 = ImageFont.truetype(FONT, int((y1 - y0) * 0.24))
            bb = dc.textbbox((0, 0), s2, font=f2)
            dc.text((x0 + ((x1 - x0) - (bb[2] - bb[0])) / 2 - bb[0], y0 + (y1 - y0) * 0.70 - (bb[3] - bb[1]) / 2 - bb[1]), s2, font=f2, fill=fg)
    sign("muster", "MUSTER STATION", (20, 120, 70), (236, 236, 230), "A")
    sign("raft", "LIFERAFT", (20, 120, 70), (236, 236, 230), "12 PERSONS")
    sign("crew", "CREW ONLY", (230, 230, 224), (40, 40, 44))
    sign("pax", "MAX 96 PASSENGERS", (230, 230, 224), (40, 40, 44), "4 CREW")
    text("imo", "GALE QUEEN  PORT HAVEN  ON 72041", FONT_N if os.path.exists(FONT_N) else FONT, (40, 40, 44))
    a = np.asarray(im, np.float32) / 255.0
    alb = np.asarray(col, np.float32) / 255.0
    # paint wear on the lettering: chips, salt, rust spots show the hull through
    n = fbm(M, 20, 400, 1.0, 81)
    wear = sm(0.70, 0.82, n)
    a = a * (1 - wear * 0.9)
    alb = mix(alb, alb * 0.85, sm(0.4, 0.7, fbm(M, 3, 60, 1.3, 82)) * 0.5)
    h = a * 0.5
    nor = normal(Image_blur(h, 1.0), 3.0)
    rgh = np.full((M, M), 0.45, np.float32)
    met = np.zeros((M, M), np.float32)
    signs = np.zeros((M, M), np.float32)
    for k in ("muster", "raft"):
        x0, y0, x1, y1 = rect(k)
        signs[y0:y1, x0:x1] = 1
    save("M_Veh_GaleQueen", "T_GaleQueen_Decals", alb, nor, rgh, met, alpha=a, signal=signs)


# ------------------------------------------------------------------ liferaft
def canopy_set():
    U, V = coords()
    fab = detail("denim_fabric")
    n1 = fbm(M, 3, 40, 1.5, 91)
    n2 = fbm(M, 30, 300, 1.1, 92)
    orange = mix(rgb(230, 98, 32), rgb(212, 86, 28), n1) * (1 + 0.05 * fab[..., None])
    alb = orange
    h = 0.15 * fab
    seams = np.maximum(lines(U, 0.25, 0.004), lines(V - 0.45, 1.0, 0.004))
    h += 0.8 * seams
    alb = mix(alb, alb * 0.82, seams * 0.6)
    # SOLAS retro-reflective tape: one cross patch per tile on the shoulder, a strip near the apex
    du = np.abs(((U + 0.5) % 1.0) - 0.5)
    cross = (band(V, 0.52, 0.60, 0.003) * (du < 0.12)) + (band(V, 0.44, 0.68, 0.003) * (du < 0.035))
    strip = band(V, 0.86, 0.90, 0.003) * (du < 0.2)
    tape = np.clip(cross + strip, 0, 1)
    beads = fbm(M, 200, 800, 0.5, 93)
    alb = mix(alb, mix(rgb(186, 190, 190), rgb(170, 172, 172), beads), tape)
    h += 0.3 * tape
    hem = 1 - sm(0.0, 0.14, V)
    alb = mix(alb, rgb(150, 70, 34), hem * (0.5 + 0.5 * n2) * 0.6)                  # wet / grimy hem
    stains = streaks(U * 4 % 1.0, V, 94, 20, (0.3, 0.9), 0.4, 0.004)
    alb = mix(alb, alb * 0.85, stains * 0.6)
    salt = sm(0.55, 0.9, fbm(M, 8, 200, 1.1, 95))
    alb = mix(alb, rgb(220, 170, 140), salt * 0.25)
    rgh = mix(0.55 + 0.08 * n2, 0.28, tape)
    met = np.zeros((M, M), np.float32)
    nor = normal(Image_blur(h, 0.6), 4.0)
    save("M_Sea_Liferaft", "T_Liferaft_Canopy", alb, nor, rgh, met, signal=1 - tape, wet=(0.36, 0.34))


def tubes_set():
    U, V = coords()
    lea = detail("fabric_leather_01")
    fab = detail("denim_fabric")
    n1 = fbm(M, 3, 40, 1.5, 101)
    n2 = fbm(M, 30, 300, 1.1, 102)
    alb = np.zeros((M, M, 3), np.float32)
    rgh = np.zeros((M, M), np.float32)
    h = np.zeros((M, M), np.float32)
    sig = np.zeros((M, M), np.float32)
    rel = {k: (band(V, a, b, 0.0005), (V - a) / (b - a)) for k, (a, b) in RAFT_BANDS.items()}
    b, r = rel["tube"]
    c = mix(rgb(50, 50, 52), rgb(60, 60, 62), n1) * (1 + 0.08 * lea[..., None])
    seam = lines(r - 0.5, 1.0, 0.006)
    du = np.abs(((U + 0.5) % 1.0) - 0.5)
    tape = band(r, 0.25, 0.75, 0.01) * (du < 0.05)
    c = mix(c, rgb(186, 190, 190), tape)
    c = mix(c, rgb(30 + 120, 150, 140), sm(0.6, 0.9, fbm(M, 8, 200, 1.0, 103)) * 0.25)   # salt bloom
    c = mix(c, c * 0.8, seam)
    alb += c * b[..., None]; rgh += b * mix(0.55, 0.28, tape); h += b * (0.15 * lea + 0.6 * seam)
    b, r = rel["floor"]
    c = mix(rgb(70, 76, 82), rgb(60, 64, 70), n1) * (1 + 0.06 * fab[..., None])
    alb += c * b[..., None]; rgh += b * 0.6; h += b * 0.2 * fab
    b, r = rel["ramp"]
    c = mix(rgb(222, 178, 44), rgb(196, 156, 40), n1) * (1 + 0.05 * fab[..., None])
    grip = lines(U, 0.05, 0.01) * 0.6
    c = mix(c, c * 0.75, grip)
    alb += c * b[..., None]; rgh += b * 0.6; h += b * (0.2 * fab + 0.6 * grip); sig += b
    b, r = rel["webbing"]
    weave = np.sin(U * M / 3.0) * 0.5 + 0.5
    c = mix(rgb(120, 120, 114), rgb(96, 96, 92), weave * 0.6 + n1 * 0.4)
    alb += c * b[..., None]; rgh += b * 0.75; h += b * weave * 0.6
    b, r = rel["lifeline"]
    strand = np.sin((U * 80 + r * 3.0) * 2 * np.pi) * 0.5 + 0.5
    c = mix(rgb(214, 206, 170), rgb(176, 168, 136), strand)
    alb += c * b[..., None]; rgh += b * 0.7; h += b * strand
    b, r = rel["ballast"]
    c = mix(rgb(214, 92, 34), rgb(190, 80, 30), n1) * (1 + 0.05 * fab[..., None])
    c = mix(c, rgb(110, 90, 50), sm(0.5, 0.85, n2) * 0.35)        # slime on the pockets
    alb += c * b[..., None]; rgh += b * 0.5; h += b * 0.2 * fab; sig += b
    nor = normal(Image_blur(h, 0.6), 4.0)
    save("M_Sea_Liferaft", "T_Liferaft_Tubes", alb, nor, rgh, np.zeros((M, M), np.float32), signal=sig, wet=(0.36, 0.34))


SETS = {"hull": hull_set, "super": super_set, "deck": deck_set, "fittings": fittings_set, "glass": glass_set,
        "decals": decals_set, "canopy": canopy_set, "tubes": tubes_set}

if __name__ == "__main__":
    for a in ("M_Veh_GaleQueen", "M_Sea_Liferaft"):
        os.makedirs(VES + a, exist_ok=True)
    for k in (sys.argv[1:] or SETS):
        SETS[k]()
