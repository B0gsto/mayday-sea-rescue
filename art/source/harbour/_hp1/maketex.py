"""HP1 own texture sets (system python3 + numpy + Pillow, no heavy slot). Real CC0 Poly Haven scans + procedural zoning.

    python3 art/source/harbour/_hp1/maketex.py

Scans (CC0 1.0, https://polyhaven.com/license), downloaded at 2k to build/hp1/src/<id>/ by fetch():
  granite_tile_02 (Charlotte Baglioni, 1.88 m)   granite of the quay blocks, copings, steps, armour
  wood_floor_deck (Dimitrios Savva, 1.8 m)       grain of the composite decking (desaturated, re-graded)
  metal_plate (Rob Tuytel, 0.5 m)                galvanised steel / zinc base, aluminium
  rusty_metal_02 (Rob Tuytel, 1.0 m)             rust on the ladder foot, the pontoon frame bolts and the cleats

Sets (1024, OpenGL normals, RGH / MET greyscale, _Wet ALB / RGH = clearly darker and glossier):
  T_QuayKit_Stone   dressed granite (copings, head ring, quoin tops): tiles 2 m, sparse lichen, salt, rope wear
  T_QuayKit_Tide    granite block faces with the shore zonation by height: u tiles 4 m along the wall, v = z, rows
                    0..N = z 0 (quay top) .. -4 m (wall foot). Sea level z = -1.333 m (map Y 0, quay top Y 4 studs):
                    black Verrucaria tar-lichen splash band, a ragged wet stain and green algae film from the waterline
                    up ~1 m, barnacle band at and just above the line, brown wrack / kelp film below it
  T_Pontoon_Kit     strip atlas (every strip spans u 0..1 and tiles in u; v bands below in PKIT)
  T_Ladder_Steel    galvanised steel by height: u tiles 1 m, v = (z + 4.2) / 5.4 (z -4.2 .. +1.2): clean dull zinc
                    and white rust at the top, rust bleed growing downwards, wet sheen, algae and barnacles below
"""
import json
import os
import urllib.request

import numpy as np
from PIL import Image

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
SRC = G + "build/hp1/src"
N = 1024
SEA = -1.333          # sea level below the quay top (m)
PKIT = {"Float": (0.0, 0.125), "Tread": (0.125, 0.1875), "Galv": (0.1875, 0.25), "Rubber": (0.25, 0.375),
        "Frame": (0.375, 0.5), "Deck0": (0.5, 0.625), "Deck1": (0.625, 0.75), "Deck2": (0.75, 0.875), "Deck3": (0.875, 1.0)}
FLOAT_Z = (-0.95, 0.0)   # float strip v range in pontoon z (deck top 0, water -0.5)
LADDER_Z = (-4.2, 1.2)


def fetch(pid):
    d = os.path.join(SRC, pid)
    if os.path.isfile(os.path.join(d, "diff_2k.png")):
        return d
    os.makedirs(d, exist_ok=True)
    ua = {"User-Agent": "MaydayHP1/1.0"}
    files = json.loads(urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + pid, headers=ua)).read())
    for key, tag in (("Diffuse", "diff"), ("nor_gl", "nor"), ("Rough", "rough")):
        url = files[key]["2k"]["png"]["url"]
        open(os.path.join(d, tag + "_2k.png"), "wb").write(urllib.request.urlopen(urllib.request.Request(url, headers=ua)).read())
    return d


def scan(pid, size=N):
    d = fetch(pid)
    out = []
    for tag in ("diff", "nor", "rough"):
        im = Image.open(os.path.join(d, tag + "_2k.png"))
        im = im.convert("RGB" if tag != "rough" else "L").resize((size, size), Image.LANCZOS)
        out.append(np.asarray(im, dtype=np.float64) / 255.0)
    return out


rng = np.random.default_rng(1710)


def fbm(shape, beta=2.0, aniso=(1.0, 1.0), seed=None):
    r = np.random.default_rng(seed)
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None] * aniso[0]
    fx = np.fft.fftfreq(w)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(r.standard_normal(shape)) / f ** (beta / 2.0)
    spec[0, 0] = 0
    n = np.real(np.fft.ifft2(spec))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, m):
    if np.ndim(m) == 2 and (np.ndim(a) in (1, 3) or np.ndim(b) in (1, 3)):
        m = m[..., None]
    return a * (1 - m) + b * m


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def grad_of(nor):
    n = nor * 2 - 1
    nz = np.maximum(n[..., 2], 0.05)
    return -n[..., 0] / nz, n[..., 1] / nz


def nor_of(gx, gy):
    nx, ny, nz = -gx, gy, np.ones_like(gx)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def hgrad(h, k=1.0):
    return (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * k, (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * k


def tile2(a):
    """box-downsample 2x and repeat 2 x 2 (a 2 m scan on a 4 m tile, seamless)."""
    h, w = a.shape[:2]
    s = a.reshape(h // 2, 2, w // 2, 2, *a.shape[2:]).mean(axis=(1, 3))
    return np.tile(s, (2, 2) + (1,) * (a.ndim - 2))


def regrade(alb, mean_rgb, contrast=1.0, sat=1.0):
    lum = alb.mean(-1, keepdims=True)
    m = lum.mean()
    lum2 = (lum - m) * contrast
    chroma = (alb - lum) * sat
    return np.clip(rgb(mean_rgb) + lum2 * 1.6 + chroma, 0, 1)


def barnacles(shape, dens, seed, count=9000, rads=(2, 3, 3, 4, 4, 5)):
    r = np.random.default_rng(seed)
    h, w = shape
    hgt, cov, pit = np.zeros(shape), np.zeros(shape), np.zeros(shape)
    kern = {}
    for rad in set(rads):
        yy, xx = np.mgrid[-rad - 1:rad + 2, -rad - 1:rad + 2]
        d = np.sqrt(xx * xx + yy * yy) / rad
        cone = np.clip(1 - d, 0, 1) ** 0.7
        crater = np.clip(1 - d / 0.38, 0, 1)
        kern[rad] = (cone - 0.9 * crater, (d < 1.0).astype(float), crater)
    cand = r.integers(0, h * w, count * 8)
    keep = cand[r.random(cand.size) < dens.reshape(-1)[cand] ** 1.5][:count]
    for k in keep:
        y, x = divmod(int(k), w)
        rad = int(r.choice(rads))
        kh, kc, kp = kern[rad]
        e = rad + 1
        ys = np.arange(y - e, y + e + 1) % h
        xs = np.arange(x - e, x + e + 1) % w
        ix = np.ix_(ys, xs)
        s = r.uniform(0.7, 1.1)
        hgt[ix] = np.maximum(hgt[ix], kh * s)
        cov[ix] = np.maximum(cov[ix], kc)
        pit[ix] = np.maximum(pit[ix], kp)
    return hgt, cov, pit


def write(stem, suffix, arr, mode, folder):
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), mode).save(os.path.join(folder, "%s_%s.png" % (stem, suffix)))


def satcap(a, cap=0.4):
    """HSV saturation <= cap (check_textures ceiling 0.45 at the 95th percentile)."""
    for _ in range(2):
        mx, mn = a.max(-1), a.min(-1)
        sat = (mx - mn) / np.maximum(mx, 1e-4)
        lum = a.mean(-1, keepdims=True)
        k = np.where(sat > cap, cap / np.maximum(sat, 1e-4), 1.0)[..., None]
        a = lum + (a - lum) * k
    return a


def save(folder, stem, alb, nor, rgh, met, alb_w=None, rgh_w=None, darken=0.32, gloss=0.42):
    """Dry + wet. Without explicit wet maps: wet albedo darker and a little more saturated, roughness pulled down.
    Albedo is kept inside 24..236 sRGB (fidelity bar), roughness >= 0.06 (no mirrors)."""
    lo, hi = 24 / 255, 236 / 255
    m = met > 0.5
    if m.any():     # PBR metals: albedo luma 180..236 sRGB (check_textures "metal albedo")
        lum = alb.mean(-1)
        p1, p99 = np.percentile(lum[m], 1), np.percentile(lum[m], 99)
        tgt = (184 + np.clip((lum - p1) / max(p99 - p1, 1e-3), 0, 1) * 46) / 255
        k = np.where(m, tgt / np.maximum(lum, 1e-3), 1.0)[..., None]
        alb = alb * k
        if alb_w is not None:
            alb_w = alb_w * np.where(m, (tgt * 0.82) / np.maximum(alb_w.mean(-1), 1e-3), 1.0)[..., None]
    alb = satcap(np.clip(alb, lo, hi))
    if alb_w is not None:
        alb_w = satcap(alb_w)
    write(stem, "ALB", alb, "RGB", folder)
    write(stem, "NOR", nor, "RGB", folder)
    write(stem, "RGH", np.clip(rgh, 0.06, 1), "L", folder)
    write(stem, "MET", met, "L", folder)
    if alb_w is None:
        m = met[..., None] > 0.5
        dk = np.where(m, darken * 0.45, darken)
        lum = alb.mean(-1, keepdims=True)
        alb_w = (lum + (alb - lum) * 1.15) * (1 - dk)
    if rgh_w is None:
        rgh_w = rgh - gloss * (0.5 + 0.5 * rgh)
    write(stem, "ALB_Wet", np.clip(np.minimum(alb_w, alb * 0.9), lo, hi), "RGB", folder)
    write(stem, "RGH_Wet", np.clip(np.minimum(rgh_w, rgh - 0.06), 0.06, 1), "L", folder)


# ---------------------------------------------------------------- quay kit
def quay_sets():
    out = G + "assets/textures/M_Hbr_QuayKit"
    A, Nn, R = scan("granite_tile_02")
    R = (R - R.mean()) / (R.std() + 1e-6)          # scan roughness as relative variation only
    s = (N, N)
    fine, mid, big = fbm(s, 1.2, seed=1), fbm(s, 2.2, seed=2), fbm(s, 3.0, seed=3)
    gx, gy = grad_of(Nn)
    # ---- Stone: dressed Cornish granite (grey with a warm buff cast, feldspar sparkle), lichen, salt, rope polish
    alb = regrade(A, (128, 124, 116), contrast=1.05, sat=0.7)
    alb = alb * (0.9 + 0.2 * big[..., None])
    lich_g = smooth(0.62, 0.72, mid * 0.6 + fine * 0.4) * smooth(0.45, 0.6, big)
    lich_o = smooth(0.8, 0.86, fbm(s, 1.6, seed=4)) * smooth(0.5, 0.7, big)
    alb = mix(alb, rgb((150, 152, 138)) * (0.85 + 0.3 * fine[..., None]), lich_g * 0.55)
    alb = mix(alb, rgb((186, 132, 52)) * (0.8 + 0.3 * fine[..., None]), lich_o * 0.75)
    stain = smooth(0.55, 0.8, fbm(s, 2.6, aniso=(0.2, 1.4), seed=5)) * 0.25
    alb = alb * (1 - stain[..., None] * 0.5)
    rg = np.clip(0.7 + 0.07 * R + 0.08 * (fine - 0.5), 0.5, 0.92)
    rg = mix(rg, 0.95, lich_g * 0.6 + lich_o * 0.6)
    lh = lich_g * 0.6 + lich_o * 0.8
    lgx, lgy = hgrad(lh, 1.5)
    nor = nor_of(gx * 1.2 + lgx, gy * 1.2 + lgy)
    save(out, "T_QuayKit_Stone", alb, nor, rg, np.zeros(s), darken=0.34, gloss=0.45)

    # ---- Tide: block faces by height (v = z, 4 m), shore zonation
    A4, N4, R4 = tile2(A), tile2(Nn), tile2(R)
    gx4, gy4 = grad_of(N4)
    yy = np.mgrid[0:N, 0:N][0].astype(np.float64)
    z = -4.0 * yy / N                                         # row 0 = quay top
    hs = z - SEA                                              # height above sea level
    line = fbm(s, 2.6, aniso=(1.0, 0.12), seed=11)            # ragged along u
    runs = fbm(s, 2.4, aniso=(0.1, 1.8), seed=12)             # streaks running down the face
    fine4, mid4, big4 = fbm(s, 1.2, seed=13), fbm(s, 2.2, seed=14), fbm(s, 3.0, seed=15)
    tl = 1.0 + 0.2 * (line - 0.5) * 2 + 0.18 * (runs - 0.5) * 2   # top of the wet/algae band, ~1 m above the water
    d = tl - hs                                                # depth below the band top
    base = regrade(A4, (120, 117, 110), contrast=1.0, sat=0.65) * (0.88 + 0.22 * big4[..., None])
    # splash zone: black tar lichen (Verrucaria maura) band above the algae, patchy
    tar = smooth(-0.55, -0.15, d) * (1 - smooth(-0.02, 0.1, d)) * smooth(0.35, 0.6, mid4 * 0.7 + fine4 * 0.3)
    wetb = smooth(-0.04, 0.04, d)                               # wet stain below the line
    rimstain = smooth(-0.03, 0.0, d) * (1 - smooth(0.02, 0.07, d))
    alg = smooth(0.0, 0.6, d + 0.3 * (mid4 - 0.5)) * (0.5 + 0.5 * fine4) * (1 - smooth(-0.1, 0.3, -hs))
    sub = smooth(-0.15, 0.25, -hs + 0.25 * (mid4 - 0.5))         # below sea level: brown wrack / kelp film
    salt = smooth(0.0, 0.08, -d) * (1 - smooth(0.08, 0.35, -d)) * smooth(0.5, 0.7, fine4 * 0.6 + mid4 * 0.4)
    bband = smooth(0.25, 0.45, d) * (1 - smooth(1.0, 1.35, d)) * smooth(0.4, 0.62, big4)
    bh, bcov, bpit = barnacles(s, bband, 17, count=11000)
    weedstreak = smooth(0.55, 0.75, runs) * smooth(0.3, 0.6, d) * (1 - sub)
    green = mix(rgb((62, 82, 40)), rgb((88, 96, 52)), fine4)
    brown = mix(rgb((58, 50, 30)), rgb((80, 66, 36)), smooth(0.4, 0.6, big4))
    outs = {}
    for state in ("dry", "wet"):
        k = 1.0 if state == "dry" else 0.72
        a = base * (1.0 if state == "dry" else 0.68)
        a = mix(a, a * 0.52, wetb * (1.0 if state == "dry" else 0.5))
        a = mix(a, rgb((34, 34, 32)) * (0.85 + 0.3 * fine4[..., None]), tar * 0.85)
        a = mix(a, green * k * (0.75 + 0.45 * fine4[..., None]), alg * 0.72)
        a = mix(a, green * k * 0.8, weedstreak * 0.5)
        a = mix(a, brown * k * (0.8 + 0.35 * fine4[..., None]), sub * 0.88)
        a = mix(a, rgb((48, 42, 30)) * k, rimstain * 0.6)
        a = mix(a, rgb((196, 194, 184)) * k, salt * 0.4)
        a = mix(a, rgb((168, 162, 150)) * k * (0.85 + 0.2 * fine4[..., None]), bcov * 0.9)
        a = a * (1 - 0.55 * bpit[..., None])
        r0 = np.clip(0.74 + 0.07 * R4, 0.5, 0.92) if state == "dry" else np.clip(0.4 + 0.06 * R4, 0.25, 0.6)
        r = mix(r0, (0.3 if state == "dry" else 0.14) + 0.08 * fine4, np.maximum(wetb, sub))
        r = mix(r, 0.9 if state == "dry" else 0.5, tar * 0.4)
        r = mix(r, 0.85, salt * 0.5)
        r = mix(r, 0.75 if state == "dry" else 0.45, bcov * 0.8)
        outs[state] = (a, r)
    soften = 1 - 0.55 * np.maximum(alg, sub)
    bgx, bgy = hgrad(bh, 2.2)
    agx, agy = hgrad(sub * fine4 + alg * fine4 * 0.6, 3.0)
    nor = nor_of(gx4 * soften * 1.2 + bgx + agx, gy4 * soften * 1.2 + bgy + agy)
    save(out, "T_QuayKit_Tide", outs["dry"][0], nor, outs["dry"][1], np.zeros(s), alb_w=outs["wet"][0], rgh_w=outs["wet"][1])


# ---------------------------------------------------------------- pontoon atlas
def band(v0, v1):
    return int(round((1 - v1) * N)), int(round((1 - v0) * N))


def pontoon_set():
    out = G + "assets/textures/M_Hbr_Pontoon"
    s = (N, N)
    alb = np.zeros(s + (3,))
    rg = np.ones(s) * 0.8
    met = np.zeros(s)
    hgt = np.zeros(s)
    gxa, gya = np.zeros(s), np.zeros(s)
    W, Wn, Wr = scan("wood_floor_deck")
    M, Mn, Mr = scan("metal_plate")
    Ru, Run, Rur = scan("rusty_metal_02")
    fine, mid, big = fbm(s, 1.2, seed=21), fbm(s, 2.2, seed=22), fbm(s, 3.0, seed=23)
    xx = np.mgrid[0:N, 0:N][1].astype(np.float64) / N
    # deck boards: composite (wood-plastic) boards, grey-brown, embossed grain, 5 grooves on top, dirt and wear
    wl = W.mean(-1)
    for i, key in enumerate(("Deck0", "Deck1", "Deck2", "Deck3")):
        r0, r1 = band(*PKIT[key])
        h = r1 - r0
        t = (np.arange(h)[:, None] + 0.5) / h * np.ones((1, N))
        src = np.roll(wl, i * 237, axis=1)[r0:r1] if i % 2 == 0 else np.roll(wl, i * 311, axis=0)[r0:r1]
        tone = [(118, 108, 96), (126, 116, 102), (110, 104, 96), (122, 112, 100)][i]
        g = (src - src.mean()) * 0.9
        col = rgb(tone) + g[..., None] * np.array([1.0, 0.95, 0.88]) * 0.55
        groove = 0.5 + 0.5 * np.cos(t * 2 * np.pi * 5)              # 5 ribs across the board
        gr = smooth(0.82, 0.97, groove)
        edge = smooth(0.0, 0.06, t) * smooth(0.0, 0.06, 1 - t)
        dirt = smooth(0.55, 0.85, mid[r0:r1]) * 0.35 + (1 - edge) * 0.4
        col = col * (1 - 0.22 * gr[..., None]) * (1 - 0.3 * dirt[..., None])
        algae = (1 - edge) * smooth(0.5, 0.8, fine[r0:r1]) * 0.5
        col = mix(col, rgb((70, 80, 52)), algae * 0.5)
        spots = smooth(0.93, 0.96, fbm((h, N), 0.6, seed=30 + i))       # gull droppings / paint flecks
        col = mix(col, rgb((206, 204, 196)), spots * 0.7)
        alb[r0:r1] = col
        rg[r0:r1] = np.clip(0.62 + 0.15 * (src - 0.5) + 0.1 * gr - 0.15 * algae + 0.15 * spots, 0.3, 0.95)
        hgt[r0:r1] = (src - 0.5) * 0.25 - gr * 0.8 - (1 - edge) * 0.6
    # galvanised frame channel + fittings: zinc grey, spangle, white rust, rust bleed along bolt lines
    ml = M.mean(-1)
    for key, tone, rust_k in (("Frame", (150, 152, 150), 1.0), ("Galv", (160, 162, 160), 0.6)):
        r0, r1 = band(*PKIT[key])
        h = r1 - r0
        t = (np.arange(h)[:, None] + 0.5) / h * np.ones((1, N))
        src = ml[r0:r1]
        spang = fbm((h, N), 0.8, seed=40)
        col = rgb(tone) + (src - src.mean())[..., None] * 0.5 + (spang - 0.5)[..., None] * 0.08
        white = smooth(0.6, 0.8, mid[r0:r1]) * 0.6
        col = mix(col, rgb((196, 198, 192)), white * 0.5)
        bolts = np.zeros((h, N))
        if key == "Frame":
            bx = np.abs(((xx[r0:r1] * 4) % 1) - 0.5)
            bolts = smooth(0.02, 0.0, np.hypot(bx * 0.25 * N / h, t - 0.5) - 0.06)
        rust = np.clip(smooth(0.72, 0.9, fbm((h, N), 2.0, aniso=(1.0, 0.3), seed=41) + 0.3 * bolts) * rust_k
                       + smooth(0.0, 0.25, 1 - t) * 0.25 * rust_k, 0, 1)
        col = mix(col, Ru[r0:r1] * 0.8 + rgb((20, 8, 0)), rust * 0.8)
        alb[r0:r1] = col
        met[r0:r1] = 1.0 - rust * 0.9 - white * 0.6
        rg[r0:r1] = np.clip(0.42 + 0.2 * Mr[r0:r1] + white * 0.3 + rust * 0.4, 0.25, 0.95)
        hgt[r0:r1] = (src - 0.5) * 0.2 + bolts * 1.2 + rust * 0.3
    met = (met > 0.5).astype(np.float64)
    # rubber D-fender strip: black-brown rubber, scuffs, salt bloom
    r0, r1 = band(*PKIT["Rubber"])
    h = r1 - r0
    scuff = smooth(0.6, 0.9, fbm((h, N), 1.5, aniso=(1.0, 0.1), seed=50))
    col = rgb((40, 38, 36)) * (0.9 + 0.2 * fine[r0:r1, :, None])
    col = mix(col, rgb((92, 88, 82)), scuff * 0.5)
    col = mix(col, rgb((170, 168, 160)), smooth(0.75, 0.9, mid[r0:r1]) * 0.25)
    alb[r0:r1] = col
    rg[r0:r1] = 0.78 - scuff * 0.15
    hgt[r0:r1] = fine[r0:r1] * 0.2 - scuff * 0.2
    # aluminium gangway tread: mill finish, transverse non-slip ribs (every ~0.1 m), oxidised, grime
    r0, r1 = band(*PKIT["Tread"])
    h = r1 - r0
    ribs = smooth(0.75, 0.95, 0.5 + 0.5 * np.cos(xx[r0:r1] * 2 * np.pi * 20))
    col = rgb((168, 170, 168)) + (ml[r0:r1] - ml.mean())[..., None] * 0.4
    col = col * (1 - 0.15 * ribs[..., None]) * (1 - 0.25 * smooth(0.6, 0.9, mid[r0:r1])[..., None])
    alb[r0:r1] = col
    met[r0:r1] = 1.0
    rg[r0:r1] = np.clip(0.48 + 0.2 * smooth(0.6, 0.9, mid[r0:r1]) + 0.1 * Mr[r0:r1], 0.3, 0.9)
    hgt[r0:r1] = ribs * 1.0
    # floats: grey HDPE float tanks, v = height (FLOAT_Z), waterline at -0.5: weed, barnacles, slime, dark wet below
    r0, r1 = band(*PKIT["Float"])
    h = r1 - r0
    t = 1 - (np.arange(h)[:, None] + 0.5) / h * np.ones((1, N))          # 0 bottom .. 1 top
    zf = FLOAT_Z[0] + t * (FLOAT_Z[1] - FLOAT_Z[0])
    hs = zf + 0.5
    line = fbm((h, N), 2.5, aniso=(1.0, 0.1), seed=60)
    d = 0.08 + 0.06 * (line - 0.5) * 2 - hs
    wet = smooth(-0.02, 0.02, d)
    weed = smooth(0.0, 0.25, d) * (0.5 + 0.5 * fine[r0:r1])
    bcov = barnacles((h, N), smooth(0.02, 0.15, d) * smooth(0.4, 0.6, mid[r0:r1]), 61, count=2500)[1]
    col = rgb((92, 94, 92)) * (0.9 + 0.15 * big[r0:r1, :, None])
    col = mix(col, col * 0.6, wet)
    col = mix(col, rgb((60, 72, 38)) * (0.8 + 0.4 * fine[r0:r1, :, None]), weed * 0.8)
    col = mix(col, rgb((70, 58, 34)), smooth(0.3, 0.45, d) * 0.7)
    col = mix(col, rgb((160, 156, 146)), bcov * 0.8)
    alb[r0:r1] = col
    rg[r0:r1] = np.clip(0.6 - 0.35 * wet + 0.2 * bcov, 0.2, 0.9)
    hgt[r0:r1] = weed * fine[r0:r1] * 0.8 + bcov * 0.6
    gx, gy = hgrad(hgt, 3.0)
    nor = nor_of(gx, gy)
    save(out, "T_Pontoon_Kit", alb, nor, rg, met, darken=0.3, gloss=0.4)


# ---------------------------------------------------------------- ladder
def ladder_set():
    out = G + "assets/textures/M_Hbr_Ladder"
    s = (N, N)
    M, Mn, Mr = scan("metal_plate")
    Ru, Run, Rur = scan("rusty_metal_02")
    fine, mid, big = fbm(s, 1.2, seed=71), fbm(s, 2.2, seed=72), fbm(s, 3.0, seed=73)
    yy = np.mgrid[0:N, 0:N][0].astype(np.float64)
    z = LADDER_Z[1] - (LADDER_Z[1] - LADDER_Z[0]) * yy / N
    hs = z - SEA
    runs = fbm(s, 2.2, aniso=(0.1, 1.6), seed=74)
    rust = np.clip(smooth(0.9, -1.2, hs) * 0.75 + smooth(0.62, 0.8, runs * 0.6 + mid * 0.4) * 0.5
                   + smooth(0.8, 0.9, fine * 0.5 + big * 0.5) * 0.4, 0, 1)
    white = smooth(0.55, 0.75, mid) * (1 - rust) * 0.6
    d = 0.6 + 0.15 * (fbm(s, 2.5, aniso=(1.0, 0.1), seed=75) - 0.5) * 2 - hs
    wet = smooth(-0.03, 0.03, d)
    alg = smooth(0.0, 0.5, d) * (0.5 + 0.5 * fine) * (1 - smooth(0.0, 0.4, -hs))
    sub = smooth(-0.1, 0.3, -hs + 0.2 * (mid - 0.5))
    bh, bcov, bpit = barnacles(s, smooth(0.2, 0.5, d) * (1 - smooth(1.2, 1.8, d)) * smooth(0.45, 0.6, big), 76, count=5000)
    ml = M.mean(-1)
    zinc = rgb((146, 148, 146)) + (ml - ml.mean())[..., None] * 0.45 + (fbm(s, 0.8, seed=77) - 0.5)[..., None] * 0.1
    outs = {}
    for state in ("dry", "wet"):
        k = 1.0 if state == "dry" else 0.7
        a = mix(zinc * (1 if state == "dry" else 0.8), rgb((200, 200, 194)) * k, white * 0.5)
        a = mix(a, (Ru * 0.85 + rgb((18, 6, 0))) * k, rust * 0.9)
        a = mix(a, a * 0.6, wet * (1 if state == "dry" else 0.4))
        a = mix(a, rgb((64, 80, 42)) * k * (0.8 + 0.4 * fine[..., None]), alg * 0.75)
        a = mix(a, rgb((66, 56, 32)) * k * (0.8 + 0.35 * fine[..., None]), sub * 0.85)
        a = mix(a, rgb((162, 158, 148)) * k, bcov * 0.9)
        a = a * (1 - 0.5 * bpit[..., None])
        r = np.clip(0.42 + 0.18 * Mr + white * 0.3 + rust * 0.42, 0.25, 0.95)
        if state == "wet":
            r = r * 0.55
        r = mix(r, 0.18 if state == "dry" else 0.12, np.maximum(wet * 0.6, sub))
        r = mix(r, 0.7, bcov * 0.7)
        outs[state] = (a, r)
    met = ((1 - np.maximum(rust, np.maximum(alg, sub)) - bcov) > 0.5).astype(np.float64)
    gx, gy = grad_of(Run)
    rgx, rgy = hgrad(bh * 1.5 + alg * fine * 0.8 + sub * fine, 2.5)
    nor = nor_of(gx * rust * 1.2 + rgx, gy * rust * 1.2 + rgy)
    save(out, "T_Ladder_Steel", outs["dry"][0], nor, outs["dry"][1], met, alb_w=outs["wet"][0], rgh_w=outs["wet"][1])


if __name__ == "__main__":
    quay_sets()
    pontoon_set()
    ladder_set()
    print("ok")
