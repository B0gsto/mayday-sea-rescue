"""M_Bld_Hospital own texture set (system python3 + numpy + Pillow).

    python3 art/source/buildings/M_Bld_Hospital/maketex.py

Writes build/prod/M_Bld_Hospital/textures/M_Bld_Hospital/T_Hospital_Details_*
(ALB/NOR/RGH/MET + _Wet ALB/RGH, 1024 px). Everything else is shared: BldTrim Sheet,
Cottage Render_White, Cottage Slate, Pontoon Kit.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
import importlib.util


def _load(mod, path):
    sp = importlib.util.spec_from_file_location(mod, path)
    m = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(m)
    return m


CH = _load("ch_maketex", G + "art/source/buildings/M_Bld_Chandlery_Ext/maketex.py")
ST = _load("st_maketex", G + "art/source/buildings/M_Bld_Station/maketex.py")

OUT = G + "build/prod/M_Bld_Hospital/textures/M_Bld_Hospital"
N = 2048
fbm, smooth, nfh, rgb, mix = CH.fbm, CH.smooth, CH.normal_from_height, CH.rgb, CH.mix
streaks, scratches, dents = ST.streaks, ST.scratches, ST.dents

# atlas rects (u0, v0, u1, v1), shared with build.py
D = {
    "Sign": (0.00, 0.80, 1.00, 1.00),
    "BaySign": (0.00, 0.60, 0.20, 0.80),
    "Roundel": (0.20, 0.60, 0.40, 0.80),
    "PontSign": (0.42, 0.60, 0.80, 0.80),
    "Date": (0.82, 0.60, 1.00, 0.70),
    "WindowCard": (0.80, 0.40, 1.00, 0.60),
    "Glass": (0.00, 0.40, 0.20, 0.60),
    "Lit": (0.21, 0.40, 0.41, 0.60),
    "DoorE": (0.42, 0.40, 0.60, 0.60),
    "DoorA": (0.61, 0.40, 0.79, 0.60),
    "Granite": (0.00, 0.20, 0.20, 0.40),
    "Conc": (0.21, 0.20, 0.41, 0.40),
    "White": (0.42, 0.20, 0.62, 0.40),
    "Steel": (0.63, 0.20, 0.79, 0.40),
    "Lead": (0.80, 0.20, 0.90, 0.40),
    "Ridge": (0.91, 0.20, 1.00, 0.40),
    "Terra": (0.00, 0.00, 0.20, 0.20),
    "Green": (0.21, 0.00, 0.41, 0.20),
    "Blue": (0.42, 0.00, 0.62, 0.20),
    "Black": (0.63, 0.00, 0.79, 0.20),
    "Rubber": (0.80, 0.00, 1.00, 0.20),
}

WHITE = rgb((216, 212, 200))
GREEN = rgb((58, 90, 76))
BLUE = rgb((68, 92, 116))
CREAM = rgb((238, 234, 220))


def save(stem, alb, nor, rgh, met, darken=0.3, gloss=0.4):
    os.makedirs(OUT, exist_ok=True)
    alb = np.clip(alb, 30 / 255, 238 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray((np.clip(nor, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray((rgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray((np.clip(met, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_MET.png"))
    m = met[..., None] > 0.5
    dk = np.where(m, darken * 0.5, min(darken * 1.4, 0.6))
    lum = alb.mean(-1, keepdims=True)
    walb = np.clip((lum + (alb - lum) * 1.04) * (1 - dk), 30 / 255, 238 / 255)
    wrgh = np.clip(rgh - min(gloss * 1.3, 0.7) * (0.55 + 0.45 * rgh), 0.04, 1.0)
    Image.fromarray((walb * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_ALB_Wet.png"))
    Image.fromarray((wrgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(OUT, stem + "_RGH_Wet.png"))
    print("[hospital] %s alb mean %s" % (stem, (alb.reshape(-1, 3).mean(0) * 255).round()))


def sl(name):
    u0, v0, u1, v1 = D[name]
    return (slice(int(round((1 - v1) * N)), int(round((1 - v0) * N))),
            slice(int(round(u0 * N)), int(round(u1 * N))))


def inset(name, px=2):
    u0, v0, u1, v1 = D[name]
    du, dv = u1 - u0, v1 - v0
    return (u0 + du * px / N, v0 + dv * px / N, u1 - du * px / N, v1 - dv * px / N, du * N, dv * N)


def mark(d, cx, cy, rr):
    """Invented heart-over-waves mark, drawn white on the mask (no cross)."""
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=255, width=max(2, int(rr * 0.14)))
    hs = rr * 0.95
    hx0, hy0 = cx - hs * 0.5, cy - hs * 0.62
    d.pieslice((hx0, hy0, hx0 + hs, hy0 + hs), 180, 360, fill=255)
    d.pieslice((hx0 + hs * 0.5, hy0, hx0 + hs * 1.5, hy0 + hs), 180, 360, fill=255)
    d.polygon([(hx0, hy0 + hs * 0.42), (hx0 + hs, hy0 + hs * 1.0), (hx0 + hs * 1.5, hy0 + hs * 0.42)], fill=255)
    for yy in (cy + hs * 0.30, cy + hs * 0.58):
        d.arc((cx - rr * 0.85, yy - 5, cx, yy + 5), 0, 180, fill=255, width=max(2, int(rr * 0.12)))
        d.arc((cx - 2, yy - 5, cx + rr * 0.85, yy + 5), 0, 180, fill=255, width=max(2, int(rr * 0.12)))


def board(w, h, emblem, lines, border=10):
    """White mask of a sign: rounded border, optional mark, fitted lettering (pixel coordinates)."""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((border, border, w - 1 - border, h - 1 - border), radius=7, outline=255, width=3)
    if emblem:
        rr = min(h * 0.30, 120)
        cx, cy = h * 0.62, h / 2
        mark(d, cx, cy, rr)
        tx0 = cx + rr * 1.25
    else:
        tx0 = border + h * 0.18
    avail = w - border - tx0 - h * 0.12
    fonts = ["/System/Library/Fonts/Supplemental/GillSans.ttc",
             "/System/Library/Fonts/Supplemental/Baskerville.ttc",
             "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"]

    def font(sz):
        for f in fonts:
            try:
                return ImageFont.truetype(f, sz, index=1) if f.endswith(".ttc") else ImageFont.truetype(f, sz)
            except Exception:
                continue
        return ImageFont.load_default()

    def fit(txt):
        sz = 10
        while sz < 120:
            f = font(sz)
            if d.textlength(txt, font=f) >= avail:
                return f, sz
            sz += 1
        return font(110), 110
    frags = [(txt, *fit(txt)) for txt in lines]
    tot = sum(sz for _t, _f, sz in frags)
    gaps = (h - tot) / (len(frags) + 1)
    y = gaps
    for txt, f, sz in frags:
        d.text((tx0 + avail / 2, y + sz * 0.78), txt, fill=255, font=f, anchor="ms")
        y += sz + gaps
    return m


def details_set():
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    big, mid, fine = fbm((N, N), 3.0, seed=161), fbm((N, N), 2.2, seed=162), fbm((N, N), 1.2, seed=163)
    runs = fbm((N, N), 2.4, aniso=(0.12, 1.8), seed=164)
    ed = np.minimum(np.minimum(np.arange(N)[:, None], N - 1 - np.arange(N)[:, None]),
                    np.minimum(np.arange(N)[None, :], N - 1 - np.arange(N)[None, :])).astype(np.float64)
    rr = np.random.default_rng(169)

    # ================================================================ timber strip: white painted, brush grain, wear
    def painted_strip(name, base, seed, grime=0.25):
        reg = sl(name)
        hh = reg[0].stop - reg[0].start
        ww = reg[1].stop - reg[1].start
        g = fbm((hh, ww), 1.8, fmax=30, aniso=(0.08, 1.7), seed=seed)
        fine2 = fbm((hh, ww), 1.4, seed=seed + 1)
        edge = np.minimum(np.arange(hh)[:, None], hh - 1 - np.arange(hh)[:, None]).astype(np.float64)
        edge = 1 - smooth(0, 3, edge)
        col = base[None, None, :] * (0.95 + 0.06 * g[..., None] + 0.04 * fine2[..., None])
        wor = smooth(0.72, 0.9, g * 0.6 + fine2 * 0.6) * (1 - smooth(0.0, 0.02, g)) * 0.25
        col = mix(col, base * 0.7 + rgb((120, 118, 108)) * 0.3, wor)
        dirt = smooth(0.5, 0.9, fbm((hh, ww), 2.2, aniso=(0.2, 1.4), seed=seed + 2)) * 0.25
        col = mix(col, rgb((96, 94, 84)), dirt)
        alb[reg] = col
        rgh[reg] = 0.5 + 0.12 * fine2 + 0.15 * dirt + 0.2 * edge
        hgt[reg] = 0.6 * g + 0.3 * fine2 - 0.4 * wor

    painted_strip("White", WHITE, 171, 0.2)
    painted_strip("Blue", BLUE, 173, 0.28)
    painted_strip("Green", GREEN, 175, 0.25)
    painted_strip("Black", rgb((48, 52, 52)), 177, 0.3)

    # ================================================================ galvanised steel (metal), spangle + streaks
    reg = sl("Steel")
    hh = reg[0].stop - reg[0].start
    ww = reg[1].stop - reg[1].start
    sp = np.floor(fbm((hh, ww), 1.1, seed=181) * 6) / 6
    col = rgb((198, 198, 192)) * (0.96 + 0.04 * fine[reg][..., None] + 0.03 * sp[..., None])
    col = col * (1 - 0.05 * smooth(0.62, 0.92, runs[reg])[..., None])
    alb[reg] = np.clip(col, 186 / 255, 1)
    met[reg] = 1
    rgh[reg] = 0.4 + 0.1 * fine[reg] + 0.05 * sp + 0.08 * smooth(0.6, 0.9, runs[reg])
    hgt[reg] = 0.4 * sp + 0.1 * fine[reg]

    # ================================================================ concrete apron / terrace
    reg = sl("Conc")
    hh = reg[0].stop - reg[0].start
    ww = reg[1].stop - reg[1].start
    c = rgb((150, 150, 142)) * (0.92 + 0.12 * big[reg][..., None] + 0.06 * fine[reg][..., None])
    jt = np.exp(-((np.arange(hh)[:, None] % 48 - 24) / 3.0) ** 2) * 0.12
    c = c * (1 - jt[..., None])
    c = mix(c, rgb((108, 110, 100)), smooth(0.55, 0.85, runs[reg])[..., None] * 0.25)
    alb[reg] = c
    rgh[reg] = 0.86 + 0.06 * fine[reg] - 0.05 * jt
    hgt[reg] = 0.3 * big[reg] + 0.2 * fine[reg] - jt

    # ================================================================ granite ashlar (plinth, sills, quoins, quay)
    reg = sl("Granite")
    hh = reg[0].stop - reg[0].start
    ww = reg[1].stop - reg[1].start
    yy = np.arange(hh)[:, None]
    course = (yy / 42.0).astype(int)
    blocks = []
    gcol = rgb((112, 110, 104))
    g = gcol[None, None, :] * (0.82 + 0.3 * big[reg][..., None] + 0.12 * fine[reg][..., None])
    bed = np.exp(-(((yy % 42) - 0.5) / 1.6) ** 2) * 0.5
    off = (course * 71) % 130
    perp = np.exp(-((((np.arange(ww)[None, :] + off) % 130) - 0.5) / 1.4) ** 2) * 0.45
    g = g * (1 - np.clip(bed + perp, 0, 0.6)[..., None])
    g = mix(g, rgb((126, 126, 114)), smooth(0.62, 0.78, mid[reg])[..., None] * 0.2)
    alb[reg] = g
    rgh[reg] = 0.82 + 0.1 * fine[reg] - 0.06 * bed - 0.04 * perp
    hgt[reg] = 0.55 * big[reg] + 0.4 * fine[reg] - bed * 2.0 - perp * 1.4

    # ================================================================ lead
    reg = sl("Lead")
    c = rgb((102, 107, 110)) * (0.9 + 0.18 * big[reg][..., None])
    c = mix(c, rgb((150, 152, 148)), smooth(0.6, 0.85, mid[reg])[..., None] * 0.25)
    cr = fbm((reg[0].stop - reg[0].start, reg[1].stop - reg[1].start), 2.6, aniso=(0.3, 1.0), seed=185)
    alb[reg] = c
    rgh[reg] = 0.55 + 0.1 * cr
    hgt[reg] = 0.8 * cr + 0.3 * big[reg]

    # ================================================================ ridge tile (slate, moss)
    reg = sl("Ridge")
    c = rgb((70, 76, 74)) * (0.86 + 0.22 * big[reg][..., None])
    mo = smooth(0.62, 0.76, mid[reg] * 0.7 + fine[reg] * 0.5)
    c = mix(c, rgb((78, 92, 52)), mo[..., None] * 0.55)
    alb[reg] = c
    rgh[reg] = 0.74 + 0.12 * mo + 0.06 * fine[reg]
    hgt[reg] = 0.5 * mid[reg] + 0.3 * fine[reg] + mo * 0.5

    # ================================================================ terracotta chimney pots
    reg = sl("Terra")
    c = rgb((146, 98, 74)) * (0.9 + 0.14 * big[reg][..., None])
    salt = smooth(0.72, 0.86, fine[reg]) * 0.5
    c = mix(c, rgb((172, 164, 142)), salt[..., None] * 0.4)
    alb[reg] = c
    rgh[reg] = 0.8 + 0.1 * fine[reg]
    hgt[reg] = 0.4 * fine[reg] + 0.2 * big[reg]

    # ================================================================ rubber fender / mat
    reg = sl("Rubber")
    c = rgb((52, 54, 50)) * (0.88 + 0.16 * fine[reg][..., None])
    alb[reg] = c
    rgh[reg] = 0.72 + 0.08 * fine[reg]
    hgt[reg] = 0.3 * fine[reg]

    # ================================================================ glass (dark, reflections, curtains)
    def glass(name, lit=False):
        reg = sl(name)
        hh = reg[0].stop - reg[0].start
        ww = reg[1].stop - reg[1].start
        yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float64)
        fy, fx = yy / hh, xx / ww
        edg = np.minimum(np.minimum(yy, hh - 1 - yy), np.minimum(xx, ww - 1 - xx)) / min(hh, ww)
        if lit:
            c = rgb((206, 196, 172)) * (0.88 + 0.14 * big[reg][..., None])
            c = mix(c, rgb((156, 138, 104)), smooth(0.5, 0.98, fy)[..., None] * 0.35)
            cur = smooth(0.32, 0.55, np.abs(fx - 0.13)) * smooth(0.32, 0.55, np.abs(fx - 0.87))
            c = mix(c, rgb((126, 108, 82)), (1 - cur[..., None]) * 0.45)
            # a faint sky reflection at the top of the panes
            c = mix(c, rgb((176, 184, 176)), smooth(0.25, 0.0, fy)[..., None] * 0.18)
            rgh[reg] = 0.32 + 0.1 * fine[reg]
            hgt[reg] = 0.1 * fine[reg]
        else:
            c = rgb((34, 44, 46)) * (0.94 + 0.1 * big[reg][..., None])
            refl = smooth(0.55, 0.82, fbm((hh, ww), 2.0, aniso=(0.25, 1.0), seed=191)) * 0.5
            refl *= smooth(0.0, 0.5, 1 - np.abs(fx - 0.35 - 0.15 * fy))
            c = mix(c, rgb((104, 118, 114)), refl[..., None] * 0.45)
            cur = smooth(0.28, 0.42, np.abs(fx - 0.15)) * smooth(0.28, 0.42, np.abs(fx - 0.85))
            c = mix(c, rgb((120, 108, 88)), (1 - cur[..., None]) * 0.22)
            dirt = (1 - smooth(0.0, 0.09, edg)) * 0.5 + smooth(0.82, 0.96, fy) * 0.2
            c = mix(c, rgb((112, 112, 100)), dirt[..., None] * 0.3)
            rgh[reg] = 0.05 + 0.03 * big[reg] + 0.12 * dirt
            hgt[reg] = 0.02 * fine[reg]
        alb[reg] = c

    glass("Glass")
    glass("Lit", lit=True)

    # ================================================================ doors (one rect over both leaves)
    def door(name, base, glassfrac, kick=None, brass=True):
        reg = sl(name)
        hh = reg[0].stop - reg[0].start
        ww = reg[1].stop - reg[1].start
        yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float64)
        fy, fx = yy / hh, xx / ww
        g = fbm((hh, ww), 1.8, aniso=(0.08, 1.5), seed=201)
        c = base[None, None, :] * (0.93 + 0.08 * g[..., None] + 0.04 * fine[reg][..., None])
        # meeting stile down the middle + shadow
        mid_st = np.exp(-((fx - 0.5) / 0.012) ** 2)
        c = c * (1 - 0.25 * mid_st[..., None])
        # glazed upper part with slim glazing bars
        gl = smooth(glassfrac - 0.01, glassfrac + 0.01, 1 - fy) * smooth(0.13, 0.15, fx) * (1 - smooth(0.85, 0.87, fx))
        gc = rgb((38, 50, 52)) * (0.92 + 0.12 * big[reg][..., None])
        gc = mix(gc, rgb((110, 124, 118)), smooth(0.6, 0.84, fbm((hh, ww), 2.0, aniso=(0.3, 1.0), seed=202))[..., None] * 0.4)
        c = mix(c, gc, gl[..., None])
        bar = np.zeros((hh, ww))
        for q in (0.32, 0.66):
            bar = np.maximum(bar, np.exp(-((fx - q) / 0.008) ** 2))
        bar = np.maximum(bar, np.exp(-((1 - fy - (1 - glassfrac) * 0.45) / 0.01) ** 2))
        c = mix(c, base * 1.06 + 0.03, (bar * gl)[..., None])
        if kick is not None:
            kb = smooth(0.82, 0.86, fy)
            c = mix(c, kick[None, None, :] * (0.9 + 0.1 * g[..., None]), kb[..., None])
        # panel mouldings (lower two per leaf)
        for px in (0.14, 0.60):
            for py in (0.55, 0.30):
                inside = smooth(px, px + 0.02, fx) * (1 - smooth(px + 0.24, px + 0.26, fx)) * \
                    smooth(py, py + 0.02, fy) * (1 - smooth(py + 0.18, py + 0.20, fy))
                c = c * (1 - 0.06 * inside[..., None])
        # scuffs at the foot, rain streaks, edge dirt
        sc = scratches((hh, ww), 40, 203, ang=(0.0, 0.5), length=(6, 34), region=(0.55, 1.0))
        c = mix(c, base * 0.7 + rgb((120, 116, 104)) * 0.3, sc[..., None] * 0.4)
        dirt = smooth(0.78, 1.0, fy) * (0.4 + 0.6 * fine[reg])
        c = mix(c, rgb((92, 90, 78)), dirt[..., None] * 0.4)
        if brass:
            for hx, hy in ((0.44, 0.50), (0.56, 0.50)):
                d2 = ((fx - hx) / 0.012) ** 2 + ((fy - hy) / 0.02) ** 2
                c = mix(c, rgb((180, 150, 92)), np.exp(-d2 * 2)[..., None])
        alb[reg] = c
        hgt[reg] = 0.25 * g + 0.15 * fine[reg] + 0.2 * bar * gl
        rgh[reg] = 0.45 + 0.15 * sc + 0.12 * dirt + 0.05 * fine[reg] - 0.35 * gl

    door("DoorE", GREEN, 0.66)
    door("DoorA", WHITE, 0.72, kick=BLUE)

    # ================================================================ signs
    # main board: deep green, cream lettering, invented heart/wave mark
    for name, lines, emblem in (("Sign", [("GALE ISLES", 0.20), ("COTTAGE HOSPITAL", 0.40)], True),
                                ("PontSign", [("HOSPITAL PONTOON", 0.34)], False)):
        reg = sl(name)
        hh = reg[0].stop - reg[0].start
        ww = reg[1].stop - reg[1].start
        mask = board(ww, hh, emblem, [t for t, _s in lines], border=10)
        letters = np.asarray(mask, dtype=np.float64) / 255.0
        base = GREEN * (0.92 + 0.1 * big[reg][..., None]) * (0.96 + 0.05 * fine[reg][..., None])
        base = mix(base, GREEN * 0.72, smooth(0.55, 0.9, runs[reg])[..., None] * 0.35)
        c = mix(base, CREAM * (0.96 + 0.04 * fine[reg][..., None]), letters[..., None])
        chips = smooth(0.9, 0.97, fine[reg] * 0.6 + mid[reg] * 0.5) * letters * 0.4
        c = mix(c, rgb((150, 150, 132)), chips[..., None])
        alb[reg] = c
        rgh[reg] = 0.48 - 0.08 * letters + 0.14 * smooth(0.6, 0.9, runs[reg])
        hgt[reg] = 0.25 * letters + 0.1 * fine[reg]

    for name, txt in (("BaySign", "H"),):
        reg = sl(name)
        hh = reg[0].stop - reg[0].start
        ww = reg[1].stop - reg[1].start
        m = Image.new("L", (ww, hh), 0)
        d = ImageDraw.Draw(m)
        d.rounded_rectangle((5, 5, ww - 5, hh - 5), radius=6, outline=255, width=3)
        f = ImageFont.truetype("/System/Library/Fonts/Supplemental/GillSans.ttc", 68, index=1)
        d.text((ww / 2, hh / 2 + 2), txt, fill=255, font=f, anchor="mm")
        letters = np.asarray(m, dtype=np.float64) / 255.0
        c = mix(BLUE * (0.92 + 0.1 * big[reg][..., None]), CREAM, letters[..., None])
        alb[reg] = c
        rgh[reg] = 0.5 + 0.1 * fine[reg] - 0.06 * letters
        hgt[reg] = 0.2 * letters

    # datestone: 1926 carved into a granite plaque
    reg = sl("Date")
    hh = reg[0].stop - reg[0].start
    ww = reg[1].stop - reg[1].start
    m = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(m)
    d.rectangle((5, 5, ww - 6, hh - 6), outline=255, width=3)
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/GillSans.ttc", int(hh * 0.55), index=1)
    d.text((ww / 2, hh / 2 + 2), "1926", fill=255, font=f, anchor="mm")
    eng = np.asarray(m, dtype=np.float64) / 255.0
    gc = rgb((128, 126, 118)) * (0.9 + 0.18 * big[reg][..., None] + 0.06 * fine[reg][..., None])
    alb[reg] = mix(gc, rgb((58, 60, 56)), eng[..., None] * 0.9)
    rgh[reg] = 0.78 + 0.1 * fine[reg] - 0.25 * eng
    hgt[reg] = -0.5 * eng + 0.3 * big[reg] + 0.2 * fine[reg]

    # LOD2 window card: a complete 6-over-6 white sash on dark glass (no wall surround)
    reg = sl("WindowCard")
    hh = reg[0].stop - reg[0].start
    ww = reg[1].stop - reg[1].start
    m = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(m)
    b = int(ww * 0.085)
    d.rectangle((0, 0, ww - 1, hh - 1), fill=255)
    d.rectangle((b, b, ww - 1 - b, hh - 1 - b), fill=0)
    mid = hh // 2
    d.rectangle((b, mid - 5, ww - 1 - b, mid + 5), fill=255)
    d.rectangle((ww // 2 - 5, b, ww // 2 + 5, hh - 1 - b), fill=255)
    for yy in (hh // 4, 3 * hh // 4):
        d.rectangle((b, yy - 4, ww - 1 - b, yy + 4), fill=255)
    fr = np.asarray(m, dtype=np.float64) / 255.0
    gl = rgb((38, 50, 52)) * (0.9 + 0.15 * big[reg][..., None])
    gl = mix(gl, rgb((105, 118, 112)), smooth(0.6, 0.85, fbm((hh, ww), 2.0, aniso=(0.3, 1.0), seed=211))[..., None] * 0.4)
    c = mix(gl, WHITE * (0.95 + 0.05 * fine[reg][..., None]), fr[..., None])
    alb[reg] = c
    rgh[reg] = 0.08 + 0.25 * fr + 0.05 * fine[reg]
    hgt[reg] = 0.3 * fr + 0.05 * fine[reg]

    # roundel: white disc, green heart/wave mark
    reg = sl("Roundel")
    hh = reg[0].stop - reg[0].start
    ww = reg[1].stop - reg[1].start
    m = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((4, 4, ww - 5, hh - 5), fill=255)
    d.ellipse((10, 10, ww - 11, hh - 11), fill=0)
    mark(d, ww / 2, hh / 2, min(ww, hh) * 0.30)
    em = np.asarray(m, dtype=np.float64) / 255.0
    c = mix(GREEN, WHITE, em[..., None])
    alb[reg] = c
    rgh[reg] = 0.5 + 0.08 * fine[reg]
    hgt[reg] = 0.3 * em

    # ground: if any region still unset, give it neutral paint
    empty = alb.sum(-1) < 1e-6
    alb[empty] = rgb((96, 96, 90))
    rgh[empty] = 0.85
    nor = nfh(hgt, 2.2, wrap=False)
    save("T_Hospital_Details", alb, nor, rgh, met, darken=0.3, gloss=0.42)


if __name__ == "__main__":
    details_set()
    print("ok")
