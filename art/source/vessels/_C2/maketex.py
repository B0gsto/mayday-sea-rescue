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


def rivulets(U, V, seed, count=60, top=(0.2, 1.0), length=0.6, width=0.0011, meander=0.004):
    """Streaming-water rivulets for the _Wet sets: thin meandering run-downs (along -V) with bead drops, 0..1."""
    wig = (fbm(M, 3, 24, 1.4, seed + 7) - 0.5) * 2 * meander
    r = streaks((U + wig) % 1.0, V, seed, count, top, length, width)
    r = np.clip(r * 1.6, 0, 1) ** 0.8
    beads = sm(0.80, 0.92, fbm(M, 60, 400, 0.6, seed + 9)) * sm(0.05, 0.3, Image_blur(r, 3.0))
    return np.clip(np.maximum(r, beads), 0, 1)


def save(asset, stem, alb, nor, rgh, met, alpha=None, signal=None, wet=(0.30, 0.30), smax=0.44, wet_mask=None,
         h=None, riv=None, nor_strength=4.0):
    """Dry + _Wet maps. Saturation limited outside `signal` (written as the check_textures signal mask).
    With `h` (height) and `riv` (rivulet mask) a NOR_Wet is written: the dry height plus raised water films, and the
    _Wet albedo / roughness darken and gloss further along the rivulets."""
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
    wa, wr = pbrmaps.wet(alb, rgh, darken=wet[0], gloss=wet[1], floor=0.09)
    if wet_mask is not None:       # parts that are always wet (below the waterline) change less
        k = np.clip(wet_mask, 0, 1)
        wa = mix(wa, alb * (1 - wet[0] * 0.55), k)
        wr = mix(wr, np.minimum(rgh, rgh - wet[1] * 0.5), k)
    extra = {}
    if riv is not None:
        k = np.clip(riv, 0, 1)
        wa = wa * (1 - 0.22 * k[..., None])
        wr = mix(wr, np.minimum(wr, 0.06), k)
        if h is not None:
            extra["NOR_Wet"] = np.clip(normal(Image_blur(h + 0.9 * Image_blur(k, 1.2), 0.7), nor_strength), 0, 1)
    l = lum(wa)[..., None]
    wa = np.where(l < 24 / 255, wa + (24 / 255 - l), wa)
    maps = {"ALB": alb, "NOR": np.clip(nor, 0, 1), "RGH": rgh, "MET": np.clip(met, 0, 1), "ALB_Wet": np.clip(wa, 0, 1),
            "RGH_Wet": np.clip(wr, 0.04, 1)}
    maps.update(extra)
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
    flow = fbm(M, 3, 90, 1.2, 14, aniso=(0.10, 1.0))           # streaks combed along the length by the water flow
    blot = fbm(M, 2, 14, 1.8, 15)                               # big patches (coats, touch-ups, slip cradles)
    # antifouling: faded and patchy, three coats of different age, roller laps along the length
    af_old = mix(rgb(132, 74, 64), rgb(116, 66, 58), n1)        # faded, leached brick red
    af_fresh = mix(rgb(118, 46, 40), rgb(104, 42, 38), n1)      # touched-up patches (darker, redder)
    af_chalk = mix(rgb(156, 112, 100), rgb(140, 100, 90), n2)   # chalky, leached to pink-grey
    af_col = mix(af_old, af_fresh, sm(0.62, 0.70, blot) * 0.85)
    af_col = mix(af_col, af_chalk, np.clip(sm(0.50, 0.80, n3) * 0.55 + sm(0.55, 0.75, flow) * 0.25, 0, 1))
    af_col = af_col * (1 + 0.10 * dpm[..., None]) * (1 + 0.06 * (flow[..., None] - 0.5))
    navy = mix(rgb(38, 50, 70), rgb(46, 58, 76), n1) * (1 + 0.12 * dpm[..., None])
    alb = af_col * af[..., None] + rgb(46, 46, 48) * boot[..., None] + navy * top[..., None] \
        + rgb(214, 214, 206) * sheer[..., None] + rgb(60, 62, 66) * cap[..., None]
    h = 0.15 * scan("blue_metal_plate")["Displacement"]
    rgh = 0.80 * af + 0.55 * boot + 0.42 * top + 0.40 * sheer + 0.55 * cap + 0.06 * n2
    met = np.zeros((M, M), np.float32)
    # plating: frames every 0.5 m (hungry horse dishing), butts every 2 m, strake seams
    fr = 0.5 / 6.0
    dish = (np.cos(((U / fr) % 1.0) * 2 * np.pi) * 0.5 + 0.5) * (V > 0.52) * (V < 0.95)
    h -= 0.25 * (1 - dish) * (0.6 + 0.4 * n1)
    seams = np.maximum(lines(U, 2.0 / 6.0, 0.0018), np.maximum(lines(V - 0.25, 1.0, 0.0018), lines(V - 0.78, 1.0, 0.0018)))
    h += 0.6 * seams
    alb = mix(alb, alb * 0.82, seams * 0.6)
    rcol = mix(rust, rgb(120, 62, 34), 0.4)
    # bottom paint damage: grey primer and black old-coat windows, slipway / grounding scrapes to rusty steel along the
    # keel and the turn of the bilge (long strokes along the length)
    primer = sm(0.74, 0.80, fbm(M, 3, 30, 1.5, 32)) * af * (V < 0.46)
    alb = mix(alb, mix(rgb(118, 116, 110), rgb(96, 96, 92), n2), primer * 0.85)
    oldcoat = sm(0.70, 0.76, fbm(M, 3, 30, 1.5, 33)) * af * (1 - primer)
    alb = mix(alb, rgb(58, 52, 50), oldcoat * 0.75)
    scrape_n = fbm(M, 4, 160, 1.0, 34, aniso=(0.05, 1.0))
    scrape_zone = np.clip((1 - sm(0.02, 0.14, V)) + band(V, 0.26, 0.36, 0.03) * 0.8, 0, 1) * af
    scr_b = sm(0.70, 0.80, scrape_n) * scrape_zone * sm(0.35, 0.6, fbm(M, 2, 20, 1.5, 35))
    alb = mix(alb, mix(rcol, rgb(96, 88, 80), 0.3), scr_b * 0.9)
    h -= 0.5 * scr_b
    rgh = mix(rgh, 0.88, scr_b)
    bare_b = scr_b * sm(0.82, 0.9, scrape_n)
    alb = mix(alb, rgb(150, 146, 140), bare_b * 0.5)
    # topsides wear: scupper streaks (every 1.5 m from the deck edge), rust weeps from the butts, chips, fender scrapes
    w = np.zeros((M, M), np.float32)
    for i in range(4):          # scuppers: 4 per 6 m tile, each a dark mouth with a long rust run
        u0 = (i + 0.5) / 4 + 0.03 * np.sin(i * 2.1)
        du = np.abs(((U - u0 + 0.5) % 1.0) - 0.5)
        run = np.clip(1 - du / (0.010 + 0.025 * np.clip(0.95 - V, 0, 1)), 0, 1) * band(V, 0.60, 0.95, 0.04)
        run *= (0.55 + 0.45 * sm(0.3, 0.7, fbm(M, 6, 80, 1.2, 36 + i, aniso=(1.0, 0.15))))
        w = np.maximum(w, run * (0.6 + 0.4 * (V - 0.6) / 0.35))
        mouth = (du < 0.012) * band(V, 0.925, 0.945, 0.003)
        alb = mix(alb, rgb(30, 30, 32), mouth)
        h -= 0.6 * mouth
    weeps = streaks(U, V, 21, 40, (0.93, 0.97), 0.35, 0.004) * top
    seam_weeps = streaks(U, V, 22, 30, (0.70, 0.80), 0.18, 0.003) * top
    w = np.clip(np.maximum(w, weeps) + seam_weeps * 0.8, 0, 1) * (top + sheer)
    alb = mix(alb, rcol * 0.85 + navy * 0.15, w * 0.8)
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
    tide = band(fbm(M, 2, 30, 1.6, 37), 0.49, 0.51, 0.006) * band(V, 0.55, 0.80, 0.03)     # dried salt tide marks
    alb = mix(alb, rgb(196, 196, 188), np.clip(salt * 0.45 + tide * 0.5, 0, 1))
    rgh = mix(rgh, 0.8, salt * 0.6)
    # fouling gradient keel -> waterline: brown diatom film low, olive-green slime higher, combed by the flow
    film = np.clip((0.30 + 0.70 * sm(0.0, wl - 0.02, V)) * (0.55 + 0.6 * fbm(M, 3, 90, 1.3, 27)) * (0.7 + 0.5 * flow), 0, 1) * af
    film_col = mix(rgb(104, 90, 62), rgb(76, 84, 50), sm(0.15, 0.45, V)[..., None] * np.ones(3, np.float32))
    alb = mix(alb, film_col, film * 0.62)
    rgh = mix(rgh, 0.50, film * 0.8)
    h += 0.15 * film * flow
    slime_wl = band(V, wl - 0.07, wl + 0.012, 0.01) * sm(0.3, 0.7, fbm(M, 6, 120, 1.2, 26))
    alb = mix(alb, rgb(62, 78, 40), slime_wl * 0.85)
    rgh = mix(rgh, 0.40, slime_wl)
    # weed: dense green filaments in the top 0.5 m under the waterline, sparse tufts lower
    weed_n = fbm(M, 60, 500, 0.9, 28, aniso=(1.0, 0.08))     # strands along V
    weed = sm(0.60, 0.76, weed_n) * af * np.clip(sm(0.36, wl - 0.02, V) + 0.35 * sm(0.62, 0.8, fbm(M, 4, 40, 1.4, 29)), 0, 1)
    weed = np.clip(weed + sm(0.66, 0.8, weed_n) * slime_wl, 0, 1)
    alb = mix(alb, mix(rgb(44, 70, 34), rgb(74, 88, 40), n2), weed * 0.9)
    h += 0.5 * weed
    rgh = mix(rgh, 0.40, weed)
    # barnacles: a dense band 0.2 .. 0.8 m under the waterline, clusters below
    bmask = af * np.clip(band(V, 0.40, 0.485, 0.012) * (0.75 + 0.25 * fbm(M, 4, 40, 1.4, 30))
                         + sm(0.62, 0.8, fbm(M, 3, 30, 1.5, 38)) * (V < 0.40) * 0.8, 0, 1)
    barn = stamps(M, 4200, 2.5, 7.5, bmask.astype(np.float32), 31)
    bm = sm(0.05, 0.3, barn)
    alb = mix(alb, mix(rgb(178, 172, 158), rgb(132, 128, 116), n2), bm)
    shell_ao = np.clip(Image_blur(bm, 3.0) - bm, 0, 1)
    alb = mix(alb, alb * 0.6, shell_ao * 1.5)
    h += 1.2 * barn
    rgh = mix(rgh, 0.85, bm)
    nor = normal(Image_blur(h, 0.7), 5.0)
    riv = rivulets(U, V, 39, 90, (0.3, 1.0), 0.7, 0.0012) * (0.5 + 0.5 * af)
    save("M_Veh_GaleQueen", "T_GaleQueen_Hull", alb, nor, rgh, met, wet=(0.46, 0.46), smax=0.40, h=Image_blur(h, 0.7), riv=riv,
         nor_strength=5.0)


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
    # C2b: varied paint wear - repainted rectangles of a slightly different white, chalked and yellowed areas, brush laps
    qx, qy = np.floor(U * 7 + 0.3 * fbm(M, 2, 8, 1.5, 49)), np.floor(V * 5)
    cell = (np.sin(qx * 12.9898 + qy * 78.233) * 43758.5453) % 1.0
    repaint = (cell > 0.72) * sm(0.3, 0.6, fbm(M, 2, 10, 1.6, 50))
    alb = mix(alb, mix(rgb(232, 232, 226), rgb(214, 210, 194), cell[..., None] * np.ones(3, np.float32)), repaint * 0.55)
    rgh = mix(rgh, 0.30, repaint * 0.5)
    chalk = sm(0.55, 0.85, fbm(M, 2, 16, 1.6, 57))
    alb = mix(alb, rgb(200, 196, 180), chalk * 0.30)
    rgh = mix(rgh, 0.62, chalk * 0.6)
    laps = sm(0.5, 0.9, fbm(M, 2, 120, 1.0, 58, aniso=(1.0, 0.06)))
    alb = alb * (1 - 0.035 * laps[..., None])
    # rust streaks from fittings (bolts, brackets, hinges, rail feet): a rust bloom at the source and a long run below
    rng = np.random.default_rng(59)
    for _ in range(26):
        u0, v0 = rng.random(), rng.uniform(0.15, 0.98)
        du = np.abs(((U - u0 + 0.5) % 1.0) - 0.5)
        ln = rng.uniform(0.15, 0.6)
        run = np.clip(1 - du / (0.0025 + 0.010 * np.clip((v0 - V) / ln, 0, 1)), 0, 1) * (V < v0) * np.clip(1 - (v0 - V) / ln, 0, 1) ** 1.2
        src = np.clip(1 - np.hypot(du, (V - v0) * 1.0) / 0.006, 0, 1)
        k = np.clip(run * rng.uniform(0.5, 0.9) + src, 0, 1)
        alb = mix(alb, mix(rcol, rgb(150, 96, 60), 0.4), k * 0.75)
        rgh = mix(rgh, 0.8, k * 0.6)
        h -= 0.3 * src
    # salt: dried spray crust in blotches and tide-mark rings where puddled spray evaporated
    tide = np.clip(band(fbm(M, 3, 40, 1.5, 60), 0.47, 0.49, 0.005) + band(fbm(M, 3, 40, 1.5, 61), 0.52, 0.535, 0.005), 0, 1)
    tide *= sm(0.4, 0.7, fbm(M, 2, 10, 1.5, 62))
    crust = sm(0.62, 0.85, fbm(M, 8, 260, 1.0, 63)) * (1 - sm(0.2, 0.6, V))
    alb = mix(alb, rgb(238, 236, 228), np.clip(tide * 0.6 + crust * 0.35, 0, 1))
    alb = mix(alb, alb * 0.86, tide * 0.25)
    rgh = mix(rgh, 0.85, np.clip(tide + crust, 0, 1) * 0.5)
    h += 0.2 * crust
    nor = normal(Image_blur(h, 0.7), 4.0)
    riv = rivulets(U, V, 64, 70, (0.4, 1.0), 0.8, 0.0011)
    save("M_Veh_GaleQueen", "T_GaleQueen_Super", alb, nor, rgh, met, wet=(0.44, 0.42), h=Image_blur(h, 0.7), riv=riv)


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
    # C2b: grime packed into the non-slip grit (cavities dark), walkway lanes, oil / diesel stains, rust from fittings
    hd = scan("concrete_floor_painted")["Displacement"]
    cav = np.clip((np.percentile(hd, 60) - hd) / max(np.ptp(hd), 1e-3) * 4.0, 0, 1)
    grime_zone = 0.45 + 0.55 * sm(0.35, 0.7, fbm(M, 2, 12, 1.6, 57))
    alb = mix(alb, rgb(46, 48, 40), cav[..., None] * 0.0 + (cav * grime_zone * 0.55)[..., None])
    lane = sm(0.45, 0.75, fbm(M, 2, 10, 1.8, 58, aniso=(0.3, 1.0)))
    alb = mix(alb, rgb(84, 86, 76), lane * 0.35)
    rgh = mix(rgh, 0.58, lane * 0.4)
    oil = sm(0.80, 0.88, fbm(M, 3, 50, 1.4, 59))
    alb = mix(alb, rgb(40, 40, 38), oil * 0.6)
    rgh = mix(rgh, 0.25, oil * 0.8)
    rng = np.random.default_rng(66)
    for _ in range(10):          # rust blooms round deck fittings, with a run toward the scuppers
        u0, v0 = rng.random(), rng.random()
        du = np.abs(((U - u0 + 0.5) % 1.0) - 0.5)
        dv = np.abs(((V - v0 + 0.5) % 1.0) - 0.5)
        r = np.hypot(du, dv * 0.6)
        k = np.clip(1 - r / rng.uniform(0.01, 0.025), 0, 1) ** 0.7 * (0.6 + 0.4 * fbm(M, 20, 200, 1.0, 67))
        alb = mix(alb, mix(rust, rgb(110, 70, 40), 0.3), k * 0.8)
        rgh = mix(rgh, 0.85, k * 0.5)
    nor = normal(Image_blur(h, 0.6), 5.0)
    riv = 0.6 * sm(0.55, 0.75, fbm(M, 3, 30, 1.4, 68))      # standing water films in the deck hollows
    save("M_Veh_GaleQueen", "T_GaleQueen_Deck", alb, nor, rgh, met, wet=(0.48, 0.50), h=Image_blur(h, 0.6), riv=riv,
         nor_strength=5.0)


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
    save("M_Veh_GaleQueen", "T_GaleQueen_Fittings", alb, nor, rgh, met, signal=sig, wet=(0.44, 0.42))


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
    save("M_Veh_GaleQueen", "T_GaleQueen_Glass", alb, nor, rgh, met, wet=(0.20, 0.10))


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
    save("M_Veh_GaleQueen", "T_GaleQueen_Decals", alb, nor, rgh, met, alpha=a, signal=signs, wet=(0.42, 0.36))


# ------------------------------------------------------------------ liferaft
def _label_patch(w, h):
    """A printed white manufacturer / SOLAS label (RGB 0..1 and its mask), w x h px."""
    im = Image.new("RGB", (w, h), (226, 224, 214))
    d = ImageDraw.Draw(im)
    d.rectangle((6, 6, w - 7, h - 7), outline=(40, 40, 44), width=5)
    rows = [("LIFERAFT", 0.30), ("SOLAS A PACK  12 PERSONS", 0.20), ("DO NOT STEP ON CANOPY", 0.15)]
    y = h * 0.10
    for s, k in rows:
        f = ImageFont.truetype(FONT, int(h * k))
        while d.textlength(s, font=f) > w * 0.88:
            f = ImageFont.truetype(FONT, f.size - 2)
        bb = d.textbbox((0, 0), s, font=f)
        d.text(((w - (bb[2] - bb[0])) / 2 - bb[0], y - bb[1]), s, font=f, fill=(34, 34, 38))
        y += h * k * 1.38
    return np.asarray(im, np.float32) / 255.0


def canopy_set():
    U, V = coords()
    fab = detail("denim_fabric")
    n1 = fbm(M, 3, 40, 1.5, 91)
    n2 = fbm(M, 30, 300, 1.1, 92)
    orange = mix(rgb(230, 98, 32), rgb(212, 86, 28), n1) * (1 + 0.05 * fab[..., None])
    alb = orange
    h = 0.15 * fab
    # welded panel seams (overlap tape) with twin lock-stitch rows either side
    seams = np.maximum(lines(U, 0.25, 0.006), lines(V - 0.45, 1.0, 0.006))
    h += 0.8 * seams
    alb = mix(alb, alb * 0.80, seams * 0.6)
    dash_v = ((V * M / 7.0) % 1.0) < 0.55
    dash_u = ((U * M / 7.0) % 1.0) < 0.55
    st = np.clip((lines(U - 0.0075, 0.25, 0.0012, 1.0) + lines(U + 0.0075, 0.25, 0.0012, 1.0)) * dash_v
                 + (lines(V - 0.45 - 0.0075, 1.0, 0.0012, 1.0) + lines(V - 0.45 + 0.0075, 1.0, 0.0012, 1.0)) * dash_u, 0, 1)
    alb = mix(alb, rgb(150, 66, 26), st * 0.8)
    h += 0.5 * st
    # SOLAS retro-reflective tape: big cross per tile on the shoulder + a ring near the apex, micro-prism cells
    du = np.abs(((U + 0.5) % 1.0) - 0.5)
    cross = np.clip(band(V, 0.50, 0.60, 0.003) * (du < 0.16) + band(V, 0.40, 0.72, 0.003) * (du < 0.045), 0, 1)
    strip = band(V, 0.835, 0.885, 0.003)
    tape = np.clip(cross + strip, 0, 1)
    cells = np.maximum(lines(U * 1.0, 0.006, 0.0007, 1.0), lines(V + U * 0.5, 0.006, 0.0007, 1.0))
    beads = fbm(M, 200, 800, 0.5, 93)
    tcol = mix(mix(rgb(204, 208, 208), rgb(184, 188, 190), beads), rgb(150, 154, 156), cells * 0.6)
    tcol = mix(tcol, rgb(150, 140, 120), sm(0.6, 0.85, n2)[..., None] * 0.35)      # grubby tape
    alb = mix(alb, tcol, tape)
    h += 0.35 * tape - 0.1 * cells * tape
    # printed label on the shoulder between the crosses (one per quarter)
    lw, lh = int(0.24 * M), int(0.10 * M)
    lab = _label_patch(lw, lh)
    x0, y0 = int(0.5 * M - lw / 2), int((1 - 0.36) * M)
    lab_m = np.zeros((M, M), np.float32)
    lab_m[y0:y0 + lh, x0:x0 + lw] = 1.0
    full = np.zeros((M, M, 3), np.float32)
    full[y0:y0 + lh, x0:x0 + lw] = lab
    lab_wear = 1 - 0.5 * sm(0.62, 0.8, fbm(M, 20, 300, 1.0, 96))
    alb = mix(alb, full, lab_m * lab_wear)
    h += 0.2 * lab_m
    # valve hardware cap round the apex (V >= 0.955): dark grey moulding
    hw = sm(0.952, 0.958, V)
    alb = mix(alb, mix(rgb(62, 64, 66), rgb(52, 54, 56), n2), hw)
    # dirt: grimy hem, handling smudges, mildew speckle low, dried salt water tide marks, run-down stains
    hem = 1 - sm(0.0, 0.16, V)
    alb = mix(alb, rgb(120, 70, 40), hem * (0.5 + 0.5 * n2) * 0.65)
    smudge = sm(0.62, 0.82, fbm(M, 3, 50, 1.4, 97)) * (1 - sm(0.3, 0.8, V))
    alb = mix(alb, rgb(110, 86, 64), smudge * 0.55)
    mildew = sm(0.78, 0.86, fbm(M, 80, 600, 0.6, 98)) * (1 - sm(0.05, 0.3, V))
    alb = mix(alb, rgb(60, 58, 46), mildew * 0.7)
    stains = streaks(U, V, 94, 26, (0.3, 0.95), 0.45, 0.004)
    alb = mix(alb, alb * 0.80, stains * 0.6)
    tide = band(fbm(M, 3, 40, 1.5, 99), 0.48, 0.50, 0.005) * sm(0.3, 0.7, fbm(M, 2, 10, 1.5, 100))
    salt = sm(0.55, 0.9, fbm(M, 8, 200, 1.1, 95))
    alb = mix(alb, rgb(222, 180, 150), np.clip(salt * 0.22 + tide * 0.5, 0, 1))
    rgh = mix(0.55 + 0.08 * n2, 0.25, tape)
    rgh = mix(rgh, 0.45, lab_m)
    rgh = mix(rgh, 0.4, hw)
    rgh = mix(rgh, 0.78, np.clip(smudge * 0.5 + mildew + hem * 0.3, 0, 1))
    met = np.zeros((M, M), np.float32)
    nor = normal(Image_blur(h, 0.6), 4.0)
    riv = rivulets(U, V, 105, 60, (0.4, 1.0), 0.7, 0.0012)
    save("M_Sea_Liferaft", "T_Liferaft_Canopy", alb, nor, rgh, met, signal=(1 - tape) * (1 - lab_m) * (1 - hw),
         wet=(0.44, 0.42), h=Image_blur(h, 0.6), riv=riv)


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
    grime = sm(0.55, 0.8, fbm(M, 3, 40, 1.4, 104))
    b, r = rel["tube"]
    c = mix(rgb(50, 50, 52), rgb(60, 60, 62), n1) * (1 + 0.08 * lea[..., None])
    seam = lines(r - 0.5, 1.0, 0.006)
    du = np.abs(((U + 0.5) % 1.0) - 0.5)
    tape = band(r, 0.22, 0.78, 0.01) * (du < 0.07)
    tcol = mix(rgb(200, 204, 204), rgb(170, 172, 172), fbm(M, 200, 800, 0.5, 106))
    c = mix(c, tcol, tape)
    c = mix(c, rgb(150, 150, 140), sm(0.6, 0.9, fbm(M, 8, 200, 1.0, 103)) * 0.25)   # salt bloom
    c = mix(c, rgb(84, 78, 62), grime * 0.35)                                         # scuff / grime
    c = mix(c, c * 0.8, seam)
    alb += c * b[..., None]; rgh += b * mix(0.55, 0.28, tape); h += b * (0.15 * lea + 0.6 * seam)
    b, r = rel["floor"]
    c = mix(rgb(70, 76, 82), rgb(60, 64, 70), n1) * (1 + 0.06 * fab[..., None])
    alb += c * b[..., None]; rgh += b * 0.6; h += b * 0.2 * fab
    # boarding ramp: coated yellow fabric, glued seam tapes with twin stitch rows, wrinkles, grip bars, dirt
    b, r = rel["ramp"]
    c = mix(rgb(222, 178, 44), rgb(196, 156, 40), n1) * (1 + 0.05 * fab[..., None])
    wr1 = 1 - np.abs(2 * fbm(M, 3, 40, 1.3, 107, aniso=(1.0, 0.25)) - 1)
    wr2 = 1 - np.abs(2 * fbm(M, 4, 60, 1.3, 108, aniso=(0.25, 1.0)) - 1)
    wrink = np.clip(sm(0.75, 0.97, wr1) + 0.7 * sm(0.78, 0.97, wr2), 0, 1) * (0.5 + 0.5 * sm(0.3, 0.7, fbm(M, 2, 10, 1.6, 109)))
    c = c * (1 - 0.18 * Image_blur(wrink, 2.0)[..., None]) + 0.05 * wrink[..., None]
    h += b * (0.9 * wrink)
    tapes_r = np.zeros((M, M), np.float32)
    for rc in (0.07, 0.50, 0.93):
        tapes_r = np.maximum(tapes_r, band(r, rc - 0.03, rc + 0.03, 0.004))
    tapes_u = lines(U, 0.4, 0.010, 1.5)
    seamt = np.clip(tapes_r + tapes_u, 0, 1)
    c = mix(c, c * 0.84, seamt)
    h += b * 0.5 * seamt
    dash_u = ((U * M / 9.0) % 1.0) < 0.6
    dash_r = ((V * M / 9.0) % 1.0) < 0.6
    st = np.zeros((M, M), np.float32)
    for rc in (0.07, 0.50, 0.93):
        for off in (-0.042, 0.042):
            st = np.maximum(st, band(r, rc + off - 0.004, rc + off + 0.004, 0.002) * dash_u)
    for off in (-0.0085, 0.0085):
        st = np.maximum(st, lines(U + off, 0.4, 0.0012, 1.0) * dash_r)
    c = mix(c, rgb(120, 92, 30), st * 0.85)
    h += b * 0.4 * st
    grip = lines(U, 0.05, 0.008) * band(r, 0.14, 0.86, 0.01) * 0.7
    c = mix(c, c * 0.72, grip)
    dirt = np.clip(sm(0.5, 0.8, fbm(M, 3, 50, 1.4, 110)) * 0.6 + sm(0.65, 0.85, fbm(M, 10, 200, 1.0, 111)) * 0.5, 0, 1)
    c = mix(c, rgb(118, 104, 70), dirt * 0.55)
    c = mix(c, rgb(84, 92, 48), (1 - sm(0.0, 0.22, r)) * sm(0.4, 0.7, n2) * 0.6)     # green water line slime
    c = mix(c, rgb(90, 80, 60), Image_blur(wrink, 1.0)[..., None] * 0.0 + (wrink * dirt * 0.4)[..., None])
    alb += c * b[..., None]; rgh += b * mix(0.6, 0.78, dirt); h += b * (0.2 * fab + 0.6 * grip); sig += b
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
    riv = rivulets(U, V, 112, 80, (0.0, 1.0), 0.5, 0.0012)
    save("M_Sea_Liferaft", "T_Liferaft_Tubes", alb, nor, rgh, np.zeros((M, M), np.float32), signal=sig, wet=(0.48, 0.50),
         h=Image_blur(h, 0.6), riv=riv)


SETS = {"hull": hull_set, "super": super_set, "deck": deck_set, "fittings": fittings_set, "glass": glass_set,
        "decals": decals_set, "canopy": canopy_set, "tubes": tubes_set}

if __name__ == "__main__":
    for a in ("M_Veh_GaleQueen", "M_Sea_Liferaft"):
        os.makedirs(VES + a, exist_ok=True)
    for k in (sys.argv[1:] or SETS):
        SETS[k]()
