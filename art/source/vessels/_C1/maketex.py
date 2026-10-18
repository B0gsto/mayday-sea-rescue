"""C1 texture sets (system python3 + numpy + Pillow, no heavy slot): The Optimist, the sit-on-top kayak and the SUP.
CC0 Poly Haven scans (blue_metal_plate, concrete_floor_painted, rusty_painted_metal, rust_coarse_01, rusty_metal_02,
teak_veneer, fabric_leather_01, denim_fabric, rubberized_track) used as micro detail and colour sources, graded and
zoned procedurally (faded gelcoat, chalking, crazing, fender scuffs, fouled waterline, rust weeps, corroded outboard leg,
sun-faded and scratched polyethylene / PVC, EVA pad grooves, lettering). No AI images. Dry + _Wet (ALB / RGH / NOR_Wet).
Masters 2048 in build/c1/masters, shipped at 1024 to assets/textures/<Asset>/. Reuses the C2 / S1a helper library.

    python3 art/source/vessels/_C1/maketex.py [hull deck fittings kayak sup]

UV conventions (the build files follow them):
  T_Optimist_Hull      U tiles every 3.5 m along the length; V 0 base .. 0.50 waterline (antifouling, slime, weed) ..
                       0.50-0.53 blue boot-top, 0.53-0.56 scum line, 0.56-0.95 faded white gelcoat (fender scuffs 0.62-0.78,
                       cove line 0.885-0.893; 0.80-0.94 also maps the wheelhouse walls and liner), 0.95-0.97 capping.
  T_Optimist_Deck      tiling 2.5 m: moulded diamond non-slip GRP, walk-worn.
  T_Optimist_Fittings  8 bands in V (steel, wood, rubber, fender, rope, outboard, orange, glass/name/PLN), U tiles 1 m.
  T_Kayak_Craft        bands hull, deck, pad, cord, black, shaft, blade (see the kayak build file).
  T_Paddleboard_Craft  bands rail, top, bottom, pad, fin, leash, shaft, blade (see the SUP build file).
"""
import importlib.util
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
_spec = importlib.util.spec_from_file_location("c2_maketex", G + "art/source/vessels/_C2/maketex.py")
X = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(X)
X.SRC = G + "build/c1/src"
X.MASTERS = G + "build/c1/masters"
X.UA = {"User-Agent": "MaydaySeaRescue-C1/1.0"}
M = X.M
fbm, sm, lum, normal, stamps, blur, mix, rgb, band, lines, streaks = (X.fbm, X.sm, X.lum, X.normal, X.stamps, X.Image_blur,
                                                                      X.mix, X.rgb, X.band, X.lines, X.streaks)
detail, scan = X.detail, X.scan
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FB = {"steel": (0.000, 0.125), "wood": (0.125, 0.250), "rubber": (0.250, 0.375), "fender": (0.375, 0.500),
      "rope": (0.500, 0.625), "outboard": (0.625, 0.750), "orange": (0.750, 0.875), "glass": (0.875, 1.000)}
KB = {"hull": (0.00, 0.30), "deck": (0.30, 0.55), "pad": (0.55, 0.65), "cord": (0.65, 0.72), "black": (0.72, 0.80),
      "shaft": (0.80, 0.88), "blade": (0.88, 1.00)}
PB = {"rail": (0.00, 0.18), "top": (0.18, 0.38), "bottom": (0.38, 0.56), "pad": (0.56, 0.76), "fin": (0.76, 0.82),
      "leash": (0.82, 0.88), "shaft": (0.88, 0.94), "blade": (0.94, 1.00)}


def scratches(seed, lo=0.74, hi=0.84, aniso=(0.05, 1.0), f=(4, 200)):
    return sm(lo, hi, fbm(M, f[0], f[1], 1.0, seed, aniso=aniso))


def text_rect(alb, h, rect, text, fill, size_frac=0.62, bg=None, font=FONT):
    """Paint `text` centred in UV rect (u0, v0, u1, v1); raises it a touch in h."""
    u0, v0, u1, v1 = rect
    x0, x1 = int(u0 * M), int(u1 * M)
    y0, y1 = int((1 - v1) * M), int((1 - v0) * M)
    w, hh = x1 - x0, y1 - y0
    im = Image.new("L", (w, hh), 0)
    d = ImageDraw.Draw(im)
    fs = int(hh * size_frac)
    f = ImageFont.truetype(font, fs)
    while d.textlength(text, font=f) > w * 0.92 and fs > 8:
        fs -= 2
        f = ImageFont.truetype(font, fs)
    tw = d.textlength(text, font=f)
    d.text(((w - tw) / 2, (hh - fs) / 2 - fs * 0.08), text, fill=255, font=f)
    m = np.asarray(im, np.float32) / 255.0
    if bg is not None:
        alb[y0:y1, x0:x1] = bg
    alb[y0:y1, x0:x1] = mix(alb[y0:y1, x0:x1], np.asarray(fill, np.float32), m)
    h[y0:y1, x0:x1] += 0.25 * m
    return m


# ------------------------------------------------------------------ The Optimist: hull (faded GRP gelcoat)
def hull_set():
    U, V = X.coords()
    dp = detail("blue_metal_plate")
    dc = detail("concrete_floor_painted")
    n1, n2 = fbm(M, 2, 40, 1.6, 101), fbm(M, 20, 300, 1.2, 102)
    flow = fbm(M, 3, 90, 1.2, 103, aniso=(0.10, 1.0))
    wl = 0.50
    af = 1 - sm(wl - 0.002, wl + 0.002, V)
    boot = band(V, 0.50, 0.53)
    top = sm(0.528, 0.532, V) * (1 - sm(0.948, 0.952, V))
    cap = sm(0.948, 0.952, V)
    # gelcoat: off-white, yellowed and chalky with age, sun-faded more higher up
    gel = mix(rgb(214, 210, 196), rgb(224, 220, 206), n1) * (1 + 0.035 * dc[..., None])
    gel = mix(gel, rgb(206, 198, 172), np.clip(sm(0.45, 0.85, fbm(M, 2, 18, 1.6, 104)) * 0.5, 0, 1))      # yellowing
    gel = mix(gel, rgb(232, 230, 222), np.clip(sm(0.55, 0.9, fbm(M, 6, 120, 1.2, 105)) * 0.35 * sm(0.6, 0.9, V), 0, 1))  # chalk
    af_c = mix(rgb(64, 74, 92), rgb(78, 88, 102), n1) * (1 + 0.10 * dp[..., None])                        # faded navy antifouling
    af_c = mix(af_c, rgb(112, 118, 124), np.clip(sm(0.55, 0.8, fbm(M, 4, 60, 1.4, 106, aniso=(1.0, 0.35))) * 0.45, 0, 1))
    bt = mix(rgb(50, 82, 124), rgb(62, 92, 128), n1)
    alb = af_c * af[..., None] + bt * boot[..., None] + gel * top[..., None] + mix(gel, rgb(170, 166, 154), 0.35) * cap[..., None]
    cove = band(V, 0.885, 0.893, 0.001)
    alb = mix(alb, rgb(52, 80, 118), cove * 0.9)
    h = 0.06 * fbm(M, 40, 400, 1.0, 107) + 0.03 * dc            # orange peel
    rgh = 0.86 * af + 0.45 * boot + 0.52 * top + 0.6 * cap + 0.06 * n2
    met = np.zeros((M, M), np.float32)
    # moulding seam at the sheer, gelcoat crazing (star cracks), repairs, chips to the grey laminate
    craze_mask = np.clip(sm(0.70, 0.85, fbm(M, 3, 30, 1.5, 108)) * top, 0, 1)
    craze = stamps(M, 900, 3.0, 9.0, craze_mask.astype(np.float32), 109)
    cr = np.clip(blur(craze, 0.6) - blur(craze, 2.5), 0, 1) * 3
    alb = mix(alb, rgb(150, 144, 128), np.clip(cr, 0, 1) * 0.6)
    h -= 0.25 * np.clip(cr, 0, 1)
    rep = sm(0.80, 0.84, fbm(M, 3, 24, 1.6, 110)) * top * (V < 0.88)
    alb = mix(alb, rgb(236, 234, 228), rep * 0.65)
    rgh = mix(rgh, 0.35, rep * 0.7)
    chip = sm(0.80, 0.90, fbm(M, 8, 160, 1.3, 111)) * sm(0.6, 0.8, fbm(M, 3, 40, 1.5, 112)) * top
    alb = mix(alb, rgb(128, 128, 118), chip * 0.85)
    h -= 0.4 * chip
    # fender / quay scuffs: black rubber marks and grey scratches along the length at fender height
    sc_zone = band(V, 0.60, 0.79, 0.02) * top
    rub = scratches(113, 0.70, 0.80, (0.04, 1.0)) * sc_zone * sm(0.4, 0.7, fbm(M, 2, 16, 1.5, 114))
    alb = mix(alb, rgb(58, 56, 54), rub * 0.75)
    grey = scratches(115, 0.76, 0.84, (0.03, 1.0), (6, 300)) * np.clip(sc_zone + 0.4 * top, 0, 1)
    alb = mix(alb, rgb(160, 156, 146), grey * 0.6)
    h -= 0.3 * grey
    rgh = mix(rgh, 0.7, np.clip(rub + grey, 0, 1))
    # rust weeps from the fittings above, grime streaks under the rubbing strake
    weeps = streaks(U, V, 116, 26, (0.93, 0.95), 0.30, 0.0035) * top
    alb = mix(alb, mix(rgb(150, 92, 52), rgb(120, 78, 50), n2), weeps * 0.75)
    grime = streaks(U, V, 117, 70, (0.94, 0.95), 0.18, 0.006) * top
    alb = mix(alb, rgb(150, 144, 128), grime * 0.55)
    under = band(V, 0.90, 0.95, 0.02) * sm(0.3, 0.8, fbm(M, 4, 60, 1.3, 118))
    alb = mix(alb, rgb(160, 152, 134), under * 0.45)
    salt = sm(0.5, 0.9, fbm(M, 6, 200, 1.1, 119)) * band(V, 0.55, 0.72, 0.03)
    alb = mix(alb, rgb(232, 230, 222), salt * 0.3)
    # fouled waterline: brown-yellow scum line above the boot-top, green slime and weed at and below it, sparse barnacles
    scum = band(V, 0.528, 0.565, 0.006) * (0.55 + 0.45 * sm(0.3, 0.7, fbm(M, 6, 120, 1.2, 120)))
    alb = mix(alb, mix(rgb(150, 128, 82), rgb(112, 108, 64), n2), scum * 0.75)
    rgh = mix(rgh, 0.62, scum)
    slime = band(V, 0.40, 0.535, 0.012) * sm(0.25, 0.65, fbm(M, 6, 140, 1.2, 121))
    alb = mix(alb, rgb(64, 82, 44), slime * 0.85)
    rgh = mix(rgh, 0.38, slime)
    film = af * (0.35 + 0.65 * sm(0.0, wl, V)) * (0.5 + 0.6 * fbm(M, 3, 90, 1.3, 122)) * (0.7 + 0.5 * flow)
    alb = mix(alb, mix(rgb(96, 88, 62), rgb(72, 82, 50), V[..., None] * 2 * np.ones(3, np.float32)), np.clip(film, 0, 1) * 0.55)
    weed_n = fbm(M, 60, 500, 0.9, 123, aniso=(1.0, 0.08))
    weed = sm(0.62, 0.78, weed_n) * band(V, 0.36, 0.505, 0.02)
    alb = mix(alb, mix(rgb(46, 72, 34), rgb(76, 90, 42), n2), weed * 0.9)
    h += 0.5 * weed
    rgh = mix(rgh, 0.4, weed)
    bmask = (af * sm(0.66, 0.82, fbm(M, 3, 30, 1.5, 124)) * (V < 0.46) * 0.8).astype(np.float32)
    barn = stamps(M, 1600, 2.0, 6.0, bmask, 125)
    bm = sm(0.05, 0.3, barn)
    alb = mix(alb, mix(rgb(176, 170, 156), rgb(132, 128, 116), n2), bm)
    h += 1.0 * barn
    rgh = mix(rgh, 0.85, bm)
    nor = normal(blur(h, 0.7), 4.5)
    riv = X.rivulets(U, V, 126, 80, (0.4, 0.95), 0.4, 0.0012) * top
    X.save("M_Veh_Optimist", "T_Optimist_Hull", alb, nor, rgh, met, wet=(0.40, 0.42), smax=0.36, wet_mask=af,
           h=blur(h, 0.7), riv=riv, nor_strength=4.5)


# ------------------------------------------------------------------ The Optimist: deck (moulded non-slip GRP)
def deck_set():
    U, V = X.coords()
    dc = detail("concrete_floor_painted")
    n1, n2 = fbm(M, 2, 30, 1.6, 201), fbm(M, 20, 300, 1.2, 202)
    base = mix(rgb(196, 194, 182), rgb(208, 204, 192), n1) * (1 + 0.05 * dc[..., None])
    # diamond non-slip pattern: 2 cm pitch (2.5 m tile), raised diamonds between smooth margins
    pitch = 2.5 / 0.02
    a = np.abs(((U + V) * pitch / 2) % 1.0 - 0.5) + np.abs(((U - V) * pitch / 2) % 1.0 - 0.5)
    dia = 1 - sm(0.30, 0.42, a)
    h = 0.35 * dia + 0.05 * dc
    alb = base * (1 - 0.05 * dia[..., None])
    rgh = 0.62 + 0.14 * dia + 0.05 * n2
    # walk-worn paths (dirt in the pattern, polished crests), oil / fish-hold stains, rust spots, green algae, dust
    walk = sm(0.45, 0.8, fbm(M, 2, 10, 1.6, 203))
    alb = mix(alb, rgb(150, 146, 132), walk * (1 - dia) * 0.55)
    alb = mix(alb, rgb(176, 172, 160), walk * dia * 0.3)
    rgh = mix(rgh, 0.5, walk * dia * 0.6)
    stain = sm(0.74, 0.86, fbm(M, 3, 40, 1.5, 204))
    alb = mix(alb, rgb(112, 104, 90), stain * 0.55)
    rgh = mix(rgh, 0.35, stain * 0.6)
    rust = sm(0.86, 0.92, fbm(M, 10, 200, 1.2, 205))
    alb = mix(alb, rgb(140, 84, 48), rust * 0.8)
    algae = sm(0.70, 0.85, fbm(M, 3, 60, 1.4, 206)) * (1 - dia)
    alb = mix(alb, rgb(110, 118, 82), algae * 0.5)
    scr = scratches(207, 0.78, 0.86, (0.2, 1.0), (6, 250))
    alb = mix(alb, rgb(150, 146, 136), scr * 0.35)
    h -= 0.2 * scr
    nor = normal(blur(h, 0.6), 4.0)
    riv = X.rivulets(U, V, 208, 40, (0.0, 1.0), 0.5, 0.0012) * 0.5
    X.save("M_Veh_Optimist", "T_Optimist_Deck", alb, nor, rgh, np.zeros((M, M), np.float32), wet=(0.38, 0.40), smax=0.30,
           h=blur(h, 0.6), riv=riv, nor_strength=4.0)


# ------------------------------------------------------------------ The Optimist: fittings trim sheet
def fittings_set():
    U, V = X.coords()
    n1, n2 = fbm(M, 2, 30, 1.6, 301), fbm(M, 20, 300, 1.2, 302)
    alb = np.zeros((M, M, 3), np.float32)
    h = np.zeros((M, M), np.float32)
    rgh = np.zeros((M, M), np.float32)
    met = np.zeros((M, M), np.float32)
    sig = np.zeros((M, M), np.float32)
    rust = X.rust_colour(3)

    def put(key, col, r, m=0.0, hh=None, s=False):
        k = band(V, *FB[key])
        nonlocal alb, rgh, met, h, sig
        alb = alb + col * k[..., None]
        rgh = rgh + r * k
        met = met + m * k
        if hh is not None:
            h = h + hh * k
        if s:
            sig = np.maximum(sig, k)
    # steel: dull galvanised / stainless, white zinc bloom, rust spots and runs
    st = mix(rgb(184, 186, 184), rgb(204, 206, 204), n1) * (1 + 0.04 * detail("blue_metal_plate")[..., None])
    rsp = sm(0.74, 0.86, fbm(M, 6, 120, 1.3, 303))
    st_m = 0.9 - 0.85 * rsp
    st = mix(st, mix(rust, rgb(120, 70, 40), 0.3), rsp)
    put("steel", st, 0.45 + 0.4 * rsp + 0.05 * n2, st_m, 0.3 * rsp)
    # wood: weathered silver-grey teak, open grain
    tk = scan("teak_veneer")["Diffuse"]
    tk = np.rot90(tk, 1).copy() if tk.shape[0] == M else tk
    grey = lum(tk)[..., None] * np.array([1.0, 0.97, 0.90], np.float32)
    wd = mix(tk, grey * 0.9 + 0.12, 0.65)
    grain = detail("teak_veneer")
    put("wood", wd * (1 + 0.15 * grain[..., None]), 0.82, 0.0, 0.4 * grain)
    # rubber: black, scuffed grey, chalky
    rb = mix(rgb(40, 40, 42), rgb(52, 52, 54), n1)
    rb = mix(rb, rgb(96, 96, 94), scratches(304, 0.76, 0.86) * 0.6)
    put("rubber", rb, 0.86, 0.0, 0.2 * detail("rubberized_track"))
    # fender: faded navy PVC, black scuffs, green grime low
    fv = (V - FB["fender"][0]) / 0.125
    fe = mix(rgb(54, 72, 104), rgb(76, 94, 120), sm(0.3, 0.9, n1))
    fe = mix(fe, rgb(110, 122, 136), sm(0.5, 0.9, fbm(M, 4, 60, 1.4, 305)) * 0.45)
    fe = mix(fe, rgb(46, 44, 44), scratches(306, 0.72, 0.84, (0.3, 1.0)) * 0.7)
    fe = mix(fe, rgb(76, 86, 56), (1 - sm(0.0, 0.4, fv)) * sm(0.3, 0.7, fbm(M, 4, 60, 1.3, 307)) * 0.6)
    put("fender", fe, 0.48 + 0.15 * n2, 0.0, 0.1 * n2, s=True)
    # rope: 3-strand polypropylene, faded blue, twist lay
    lay = (np.sin((U * 40 + (V - FB["rope"][0]) / 0.125 * 3) * 2 * np.pi) * 0.5 + 0.5)
    rp = mix(rgb(72, 94, 128), rgb(102, 118, 140), sm(0.3, 0.8, n1)) * (0.75 + 0.35 * lay[..., None])
    rp = mix(rp, rgb(170, 168, 160), sm(0.78, 0.9, fbm(M, 30, 400, 1.0, 308)) * 0.5)
    put("rope", rp, 0.88, 0.0, 0.6 * lay + 0.2 * detail("denim_fabric"))
    # outboard: upper half cowl (chalky charcoal paint, scratches), lower half leg / bracket (paint lost, white
    # aluminium corrosion bloom, bare metal, heavy rust from the steel clamp and bolts)
    ov = (V - FB["outboard"][0]) / 0.125
    cowl = sm(0.48, 0.52, ov)
    cw = mix(rgb(56, 58, 60), rgb(80, 82, 84), sm(0.4, 0.9, fbm(M, 4, 60, 1.4, 309)))
    cw = mix(cw, rgb(140, 140, 138), scratches(310, 0.80, 0.88, (0.2, 1.0)) * 0.6)
    leg = mix(rgb(70, 72, 74), rgb(96, 98, 98), n1)
    bare = sm(0.45, 0.65, fbm(M, 4, 50, 1.5, 311))
    leg = mix(leg, rgb(186, 186, 182), bare * 0.8)
    bloom = sm(0.62, 0.78, fbm(M, 10, 160, 1.3, 312))
    leg = mix(leg, rgb(206, 204, 194), bloom * 0.75)
    rr = np.clip(sm(0.55, 0.75, fbm(M, 4, 50, 1.4, 313)) + streaks(U, V, 314, 40, (0.68, 0.70), 0.05, 0.004), 0, 1)
    leg = mix(leg, mix(rust, rgb(110, 60, 34), 0.4), rr * 0.9)
    ob = mix(leg, cw, cowl)
    ob_m = (1 - cowl) * bare * (1 - rr) * (1 - bloom) * 0.85
    put("outboard", ob, mix(0.5 + 0.35 * rr + 0.2 * bloom, 0.55, cowl), ob_m, 0.5 * rr * (1 - cowl) + 0.3 * bloom)
    # orange plastic (fish box, fuel tank): faded, dirty, scratched
    orv = (V - FB["orange"][0]) / 0.125
    og = mix(rgb(196, 104, 46), rgb(206, 128, 72), sm(0.3, 0.9, n1))
    og = mix(og, rgb(150, 112, 80), (1 - sm(0.0, 0.3, orv)) * 0.5)
    og = mix(og, rgb(214, 170, 130), scratches(315, 0.76, 0.86, (0.2, 1.0)) * 0.5)
    put("orange", og, 0.62 + 0.1 * n2, 0.0, 0.1 * n2, s=True)
    # glass / name board / PLN strip
    gk = band(V, *FB["glass"])
    gl = (U < 0.30)
    nm = (U >= 0.30) & (U < 0.78)
    pl = U >= 0.78
    gv = (V - FB["glass"][0]) / 0.125
    frame = np.clip((1 - sm(0.03, 0.06, gv)) + sm(0.94, 0.97, gv) + (1 - sm(0.012, 0.025, U)) + sm(0.275, 0.288, U), 0, 1)
    glass = mix(rgb(40, 46, 50), rgb(150, 156, 156), sm(0.5, 0.9, fbm(M, 6, 120, 1.2, 316)) * 0.30)   # salt haze
    glass = mix(glass, rgb(36, 36, 38), frame)
    alb = alb + glass * (gk * gl)[..., None]
    rgh = rgh + mix(0.06 + 0.25 * sm(0.5, 0.9, fbm(M, 6, 120, 1.2, 316)), 0.8, frame) * gk * gl
    navy = mix(rgb(38, 54, 86), rgb(50, 64, 90), n1)
    alb = alb + navy * (gk * nm)[..., None]
    gelc = mix(rgb(214, 210, 196), rgb(222, 218, 204), n1)
    alb = alb + gelc * (gk * pl)[..., None]
    rgh = rgh + 0.5 * gk * nm + 0.52 * gk * pl
    v0, v1 = FB["glass"][0] + 0.012, FB["glass"][1] - 0.012
    m1 = text_rect(alb, h, (0.31, v0, 0.77, v1), "THE OPTIMIST", (0.86, 0.82, 0.68))
    m2 = text_rect(alb, h, (0.785, v0, 0.995, v1), "HV 27", (0.16, 0.16, 0.17), size_frac=0.74)
    sig = np.maximum(sig, gk * nm)
    # weathering over the name board: peeling, salt
    peel = sm(0.80, 0.88, fbm(M, 6, 120, 1.3, 317)) * gk * (nm | pl)
    alb = mix(alb, rgb(170, 166, 156), peel * 0.5)
    nor = normal(blur(h, 0.6), 4.0)
    riv = X.rivulets(U, V, 318, 60, (0.0, 1.0), 0.5, 0.0012) * 0.6
    X.save("M_Veh_Optimist", "T_Optimist_Fittings", alb, nor, np.clip(rgh, 0.04, 1), np.clip(met, 0, 1), signal=sig,
           wet=(0.40, 0.42), smax=0.40, h=blur(h, 0.6), riv=riv)


# ------------------------------------------------------------------ kayak (sun-faded red polyethylene)
def kayak_set():
    U, V = X.coords()
    n1, n2 = fbm(M, 2, 30, 1.6, 401), fbm(M, 20, 300, 1.2, 402)
    grain = detail("fabric_leather_01")
    alb = np.zeros((M, M, 3), np.float32)
    h = 0.05 * grain
    rgh = np.zeros((M, M), np.float32)
    met = np.zeros((M, M), np.float32)
    kh, kd = band(V, *KB["hull"]), band(V, *KB["deck"])
    hv = np.clip((V - KB["hull"][0]) / 0.30, 0, 1)            # 0 keel .. 1 deck edge
    dv = np.clip((V - KB["deck"][0]) / 0.25, 0, 1)            # 0 .. 1 across the deck
    red = mix(rgb(170, 58, 46), rgb(184, 70, 54), n1)
    faded = mix(rgb(198, 120, 104), rgb(206, 134, 116), n2)  # UV-faded salmon on the sun-facing deck
    side = mix(red, faded, (0.15 + 0.35 * hv)[..., None] * np.ones(3, np.float32))
    crown = 1 - np.abs(dv - 0.5) * 2
    deck = mix(red, faded, (0.55 + 0.35 * crown)[..., None] * np.ones(3, np.float32))
    deck = mix(deck, rgb(214, 160, 144), sm(0.55, 0.85, fbm(M, 3, 40, 1.5, 403)) * 0.35)     # chalky blotches
    plast = side * kh[..., None] + deck * kd[..., None]
    plast = plast * (1 + 0.05 * grain[..., None])
    # bottom: beach-dragged scratches along the length, whitened gouges, sand grime; deck: fine scuffs, dirt
    bot = (1 - sm(0.25, 0.45, hv)) * kh
    gs = scratches(404, 0.70, 0.80, (0.02, 1.0), (6, 300)) * (bot + 0.25 * kh + 0.2 * kd)
    plast = mix(plast, rgb(222, 178, 166), gs * 0.65)
    h -= 0.35 * gs
    gouge = scratches(405, 0.86, 0.92, (0.03, 1.0), (3, 120)) * bot
    plast = mix(plast, rgb(232, 210, 200), gouge * 0.8)
    h -= 0.6 * gouge
    sand = bot * sm(0.4, 0.8, fbm(M, 4, 80, 1.3, 406))
    plast = mix(plast, rgb(150, 132, 108), sand * 0.45)
    dirt = kd * sm(0.55, 0.85, fbm(M, 3, 50, 1.4, 407))
    plast = mix(plast, rgb(120, 96, 84), dirt * 0.4)
    alb = alb + plast * (kh + kd)[..., None]
    rgh = rgh + (0.62 + 0.18 * gs + 0.08 * n2) * (kh + kd)
    sig = (kh + kd)
    # seat pad (black EVA, cross-hatch, faded grey), bungee (black with white fleck), black plastic, aluminium shaft,
    # black blade with scuffed edges
    kp = band(V, *KB["pad"])
    hatch = np.maximum(lines(U + V, 0.012, 0.0016), lines(U - V, 0.012, 0.0016))
    pad = mix(rgb(56, 56, 60), rgb(80, 80, 84), sm(0.4, 0.9, n1)) * (1 - 0.25 * hatch[..., None])
    pad = mix(pad, rgb(180, 176, 166), sm(0.75, 0.9, fbm(M, 8, 160, 1.2, 408)) * 0.35)
    alb, rgh, h = alb + pad * kp[..., None], rgh + 0.9 * kp, h - 0.3 * hatch * kp
    kc = band(V, *KB["cord"])
    fl = sm(0.80, 0.9, fbm(M, 40, 500, 1.0, 409, aniso=(1.0, 0.2)))
    alb, rgh = alb + mix(rgb(42, 42, 44), rgb(200, 200, 196), fl * 0.7) * kc[..., None], rgh + 0.8 * kc
    kb = band(V, *KB["black"])
    bk = mix(rgb(44, 44, 46), rgb(110, 108, 104), scratches(410, 0.76, 0.86) * 0.6)
    alb, rgh = alb + bk * kb[..., None], rgh + 0.7 * kb
    ks = band(V, *KB["shaft"])
    sh = mix(rgb(188, 190, 190), rgb(206, 206, 204), n1)
    sh = mix(sh, rgb(150, 150, 146), scratches(411, 0.74, 0.84, (0.03, 1.0)) * 0.5)
    alb, rgh, met = alb + sh * ks[..., None], rgh + 0.45 * ks, met + 0.9 * ks
    kbl = band(V, *KB["blade"])
    bv = np.clip((V - KB["blade"][0]) / 0.12, 0, 1)
    edge = 1 - sm(0.0, 0.12, np.minimum(bv, 1 - bv))
    bl = mix(rgb(50, 50, 54), rgb(120, 118, 112), np.clip(edge * 0.6 + scratches(412, 0.78, 0.86) * 0.4, 0, 1))
    alb, rgh = alb + bl * kbl[..., None], rgh + 0.6 * kbl
    h += 0.1 * n2
    nor = normal(blur(h, 0.6), 4.0)
    riv = X.rivulets(U, V, 413, 60, (0.0, 1.0), 0.5, 0.0012) * (kh + kd)
    X.save("M_Veh_Kayak", "T_Kayak_Craft", alb, nor, rgh, met, signal=sig, wet=(0.36, 0.42), smax=0.42, h=blur(h, 0.6), riv=riv)


# ------------------------------------------------------------------ SUP (faded PVC drop-stitch, EVA pad)
def sup_set():
    U, V = X.coords()
    n1, n2 = fbm(M, 2, 30, 1.6, 501), fbm(M, 20, 300, 1.2, 502)
    alb = np.zeros((M, M, 3), np.float32)
    h = 0.04 * detail("fabric_leather_01")
    rgh = np.zeros((M, M), np.float32)
    met = np.zeros((M, M), np.float32)
    sig = np.zeros((M, M), np.float32)
    teal = mix(rgb(62, 132, 138), rgb(96, 150, 152), sm(0.3, 0.9, n1))
    white = mix(rgb(212, 212, 206), rgb(224, 222, 216), n1)
    kr = band(V, *PB["rail"])
    rv = np.clip((V - PB["rail"][0]) / 0.18, 0, 1)          # 0 top edge .. 1 bottom edge
    stripe = band(rv, 0.40, 0.58, 0.01)
    rail = mix(white, teal, stripe)
    rail = mix(rail, rgb(150, 146, 132), sm(0.75, 1.0, rv) * 0.5)                     # waterline grime
    rail = mix(rail, rgb(120, 118, 112), scratches(503, 0.74, 0.84, (0.05, 1.0)) * 0.5)
    tape = lines(V - PB["rail"][0] - 0.03, 1.0, 0.002) + lines(V - PB["rail"][1] + 0.03, 1.0, 0.002)
    h += 0.08 * blur(tape, 1.5) * kr
    alb, rgh, sig = alb + rail * kr[..., None], rgh + (0.42 + 0.1 * n2) * kr, np.maximum(sig, stripe * kr)
    kt = band(V, *PB["top"])
    tv = np.clip((V - PB["top"][0]) / 0.20, 0, 1)
    edge = 1 - sm(0.10, 0.14, np.minimum(tv, 1 - tv))
    top = mix(mix(white, rgb(226, 222, 208), sm(0.4, 0.9, fbm(M, 2, 16, 1.6, 504)) * 0.5), teal, edge)
    top = mix(top, rgb(150, 144, 128), sm(0.65, 0.9, fbm(M, 3, 50, 1.4, 505)) * 0.35)
    alb, rgh, sig = alb + top * kt[..., None], rgh + 0.45 * kt, np.maximum(sig, edge * kt)
    kb = band(V, *PB["bottom"])
    bot = mix(rgb(168, 170, 168), rgb(184, 184, 180), n1)
    gs = scratches(506, 0.68, 0.80, (0.02, 1.0), (6, 300))
    bot = mix(bot, rgb(120, 118, 112), gs * 0.6)
    bot = mix(bot, rgb(100, 110, 72), sm(0.65, 0.85, fbm(M, 4, 60, 1.3, 507)) * 0.35)
    alb, rgh, h = alb + bot * kb[..., None], rgh + (0.5 + 0.2 * gs) * kb, h - 0.3 * gs * kb
    kp = band(V, *PB["pad"])
    pitch = 1.4 / 0.03
    a = np.abs(((U + V * 7) * pitch / 2) % 1.0 - 0.5) + np.abs(((U - V * 7) * pitch / 2) % 1.0 - 0.5)
    groove = sm(0.42, 0.48, a)
    pad = mix(rgb(118, 120, 120), rgb(136, 138, 136), sm(0.3, 0.9, n1)) * (1 - 0.35 * groove[..., None])
    pad = mix(pad, rgb(152, 140, 116), groove * sm(0.4, 0.8, fbm(M, 4, 60, 1.4, 508)) * 0.6)     # sand in the grooves
    pad = mix(pad, rgb(96, 96, 94), sm(0.5, 0.85, fbm(M, 2, 12, 1.5, 509)) * 0.35)                  # foot-worn
    alb, rgh, h = alb + pad * kp[..., None], rgh + 0.92 * kp, h - 0.10 * blur(groove, 1.0) * kp + 0.12 * fbm(M, 8, 120, 1.2, 521) * kp
    for key, col, r, m in (("fin", rgb(42, 42, 44), 0.6, 0.0), ("leash", rgb(56, 92, 128), 0.35, 0.0),
                           ("shaft", rgb(48, 48, 50), 0.4, 0.0), ("blade", rgb(54, 92, 98), 0.45, 0.0)):
        k = band(V, *PB[key])
        c = mix(col, rgb(130, 128, 124), scratches(510 + len(key), 0.78, 0.86) * 0.5)
        alb, rgh, met = alb + c * k[..., None], rgh + r * k, met + m * k
        if key in ("leash", "blade"):
            sig = np.maximum(sig, k)
    nor = normal(blur(h, 0.6), 4.0)
    riv = X.rivulets(U, V, 520, 60, (0.0, 1.0), 0.5, 0.0012) * (kr + kt + kb)
    X.save("M_Veh_Paddleboard", "T_Paddleboard_Craft", alb, nor, rgh, met, signal=sig, wet=(0.36, 0.44), smax=0.40,
           h=blur(h, 0.6), riv=riv)


SETS = {"hull": hull_set, "deck": deck_set, "fittings": fittings_set, "kayak": kayak_set, "sup": sup_set}

if __name__ == "__main__":
    for a in ("M_Veh_Optimist", "M_Veh_Kayak", "M_Veh_Paddleboard"):
        os.makedirs(X.VES + a, exist_ok=True)
    for k in (sys.argv[1:] or SETS):
        SETS[k]()
