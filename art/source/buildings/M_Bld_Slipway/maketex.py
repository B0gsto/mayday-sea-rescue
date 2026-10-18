"""H1 M_Bld_Slipway own texture sets (system python3 + numpy + Pillow, no heavy slot). Procedural, no AI images.

    python3 art/source/buildings/M_Bld_Slipway/maketex.py

Writes 1024 px sets (OpenGL normals, RGH / MET greyscale, _Wet ALB / RGH) to assets/textures/M_Bld_Slipway:
  T_Slipway_Tide_*   the intertidal band of the ramp. Tiles in u (6 m across the ramp); v spans the band exactly once
                     (6 m of slope, s = -3 .. -9 m from the head). Built from the shared B02 Concrete (top edge) and
                     WeedyConcrete (bottom edge) sampled at the same world scale and phase (both tile 3 m, so 2 x 2 repeats
                     per tide tile), so both seams vanish. Between: a noisy tide line, a barnacle band, kelp / weed streaks
                     running down-slope, weed in the mid-band joint, along the rail feet and the kerb corners, rust bleed
                     under the rails, a dark wet sheen with low roughness below the line. _Wet blends the shared _Wet maps.
  T_Slipway_Steel_*  the slipway kit atlas (rails, winch, winch house), shared with build.py (KIT below):
                     rects:  Wall (block coursing, drip stains, splash algae), Door (painted steel leaf), Vent (louvre
                             backing), Plate (painted housing)
                     strips: Roof (weathered corrugated sheet), Rust (rust / mill scale), RailHead (polished running band
                             between rusted edges, the only metal), Paint (painted steel, edge rust)
"""
import os

import numpy as np
from PIL import Image

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/textures/M_Bld_Slipway"
MAT = G + "assets/textures/Materials"
N = 1024
rng = np.random.default_rng(4410)

# atlas layout (u0, v0, u1, v1), shared with build.py
KIT = {
    "Wall": (0.0, 0.5, 0.5, 1.0), "Door": (0.5, 0.5, 0.75, 1.0), "Vent": (0.75, 0.75, 1.0, 1.0),
    "Plate": (0.75, 0.5, 1.0, 0.75),
    "Roof": (0.0, 0.375, 1.0, 0.5), "Rust": (0.0, 0.25, 1.0, 0.375), "RailHead": (0.0, 0.125, 1.0, 0.25),
    "Paint": (0.0, 0.0, 1.0, 0.125),
}


# ---------------------------------------------------------------- helpers (copied from M_Bld_Station/maketex.py)
def fbm(shape, beta=2.0, aniso=(1.0, 1.0), seed=None):
    """Periodic 1/f^beta noise, 0..1 (tiles by construction). aniso stretches the spectrum (y, x)."""
    r = np.random.default_rng(seed) if seed is not None else rng
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


def normal_from_height(h, strength, wrap=True):
    """OpenGL tangent normal: +X right, +Y = +V (up in the image)."""
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        dy, dx = np.gradient(h)
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def write(folder, stem, suffix, arr, mode):
    os.makedirs(folder, exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), mode).save(os.path.join(folder, "%s_%s.png" % (stem, suffix)))


def save(folder, stem, alb, nor, rgh, met, darken=0.3, gloss=0.4):
    alb = np.clip(alb, 22 / 255, 238 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    write(folder, stem, "ALB", alb, "RGB")
    write(folder, stem, "NOR", nor, "RGB")
    write(folder, stem, "RGH", rgh, "L")
    write(folder, stem, "MET", met, "L")
    m = met[..., None] > 0.5
    dk = np.where(m, darken * 0.5, np.minimum(darken * 1.45, 0.6))       # H2: wet clearly darker, glossier
    lum = alb.mean(-1, keepdims=True)
    write(folder, stem, "ALB_Wet", np.clip((lum + (alb - lum) * 1.18) * (1 - dk), 22 / 255, 238 / 255), "RGB")
    write(folder, stem, "RGH_Wet", np.clip(rgh - min(gloss * 1.3, 0.75) * (0.55 + 0.45 * rgh), 0.04, 1.0), "L")


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def load(path):
    a = np.asarray(Image.open(path), dtype=np.float64) / 255.0
    return a


def half_tile(a):
    """A 3 m tile resampled into a 6 m tide tile: box-downsample 2x, repeat 2 x 2 (same world scale and phase)."""
    h, w = a.shape[:2]
    s = a.reshape(h // 2, 2, w // 2, 2, *a.shape[2:]).mean(axis=(1, 3))
    return np.tile(s, (2, 2) + (1,) * (a.ndim - 2))


def grad_of(nor):
    """Normal map (0..1 OpenGL) -> height-gradient field (gx, gy) as used by normal_from_height (strength folded in)."""
    n = nor * 2 - 1
    nz = np.maximum(n[..., 2], 0.05)
    return -n[..., 0] / nz, n[..., 1] / nz


def nor_of(gx, gy):
    nx, ny, nz = -gx, gy, np.ones_like(gx)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def mix(a, b, m):
    if np.ndim(m) == 2 and (np.ndim(a) in (1, 3) or np.ndim(b) in (1, 3)):
        m = m[..., None]
    return a * (1 - m) + b * m


# ---------------------------------------------------------------- tide band
def barnacles(shape, band, seed):
    """Stamped barnacle cones (height with an open crater) clustered by 'band' (0..1 density), wrapping in u."""
    r = np.random.default_rng(seed)
    h, w = shape
    P = 8
    hgt = np.zeros((h, w + 2 * P))
    cov = np.zeros((h, w + 2 * P))
    kern = {}
    for rad in (2, 3, 4, 5):
        yy, xx = np.mgrid[-rad - 1:rad + 2, -rad - 1:rad + 2]
        d = np.sqrt(xx * xx + yy * yy) / rad
        cone = np.clip(1 - d, 0, 1) ** 0.7
        crater = np.clip(1 - d / 0.38, 0, 1)
        kern[rad] = (cone - 0.9 * crater, (d < 1.0).astype(float), crater)
    # cluster centres where the band is dense
    cand = r.integers(0, h * w, 60000)
    keep = cand[r.random(cand.size) < band.reshape(-1)[cand] ** 1.5]
    pits = np.zeros_like(hgt)
    for k in keep[:9000]:
        y, x = divmod(int(k), w)
        rad = int(r.choice((2, 3, 3, 4, 4, 5)))
        kh, kc, kp = kern[rad]
        e = rad + 1
        y0, y1 = max(0, y - e), min(h, y + e + 1)
        ky0, ky1 = y0 - (y - e), (2 * e + 1) - ((y + e + 1) - y1)
        xs = slice(x + P - e, x + P + e + 1)
        hgt[y0:y1, xs] = np.maximum(hgt[y0:y1, xs], kh[ky0:ky1] * r.uniform(0.7, 1.1))
        cov[y0:y1, xs] = np.maximum(cov[y0:y1, xs], kc[ky0:ky1])
        pits[y0:y1, xs] = np.maximum(pits[y0:y1, xs], kp[ky0:ky1])
    def fold(a):
        o = a[:, P:P + w].copy()
        o[:, :P] = np.maximum(o[:, :P], a[:, P + w:])
        o[:, w - P:] = np.maximum(o[:, w - P:], a[:, :P])
        return o
    return fold(hgt), fold(cov), fold(pits)


def tide_set():
    s = (N, N)
    yy, xx = np.mgrid[0:N, 0:N]
    t = yy / (N - 1.0)                      # 0 = top edge (s = -3 m, dry concrete) .. 1 = bottom edge (s = -9 m, weedy)
    big, mid, fine = fbm(s, 3.0, seed=1), fbm(s, 2.3, seed=2), fbm(s, 1.3, seed=3)
    line = fbm(s, 2.8, aniso=(1.0, 0.6), seed=4)
    tp = t + 0.2 * (line - 0.5) + 0.05 * (mid - 0.5)        # noisy tide-line coordinate
    edge = smooth(0.0, 0.07, t) * (1 - smooth(0.93, 1.0, t))  # overlays fade to nothing at both seams
    m = smooth(0.5, 0.95, tp)
    m = m * smooth(0.0, 0.08, t)
    m = 1 - (1 - m) * (1 - smooth(0.9, 1.0, t))
    wet = smooth(0.36, 0.46, tp) * (1 - smooth(0.82, 0.99, t))
    algae = smooth(0.22, 0.4, tp) * (1 - smooth(0.6, 0.8, tp)) * smooth(0.45, 0.7, mid) * edge
    band = smooth(0.34, 0.42, tp) * (1 - smooth(0.58, 0.7, tp)) * smooth(0.4, 0.62, big * 0.6 + fine * 0.4) * edge
    bh, bcov, bpit = barnacles(s, band, 7)
    runs = fbm(s, 2.3, aniso=(0.1, 1.7), seed=5)            # long down-slope runs
    runs2 = fbm(s, 1.9, aniso=(0.16, 1.4), seed=6)
    kelp = smooth(0.56, 0.72, runs * 0.75 + fine * 0.25) * smooth(0.42, 0.62, tp) * edge
    kelp = np.maximum(kelp, smooth(0.62, 0.78, runs2) * smooth(0.5, 0.75, tp) * edge * 0.85)
    # weed in the mid-band joint (s = -6 m, row 512), at the rail feet (u 0.125 / 0.875), in the kerb corners
    joint = np.exp(-((yy - 511.5) / 7.0) ** 2) * smooth(0.3, 0.6, fine * 0.5 + big * 0.5)
    joint = np.maximum(joint, np.exp(-((yy - 511.5) / 2.2) ** 2) * 0.9)
    def colband(c, wpx):
        d = np.abs(((xx - c + N / 2) % N) - N / 2)
        return np.exp(-(d / wpx) ** 2)
    rails = colband(127.5, 16) + colband(895.5, 16)
    railweed = rails * smooth(0.38, 0.6, tp) * smooth(0.35, 0.6, fine * 0.6 + runs * 0.4) * edge
    rustbleed = (colband(127.5, 30) + colband(895.5, 30)) * smooth(0.2, 0.5, tp) * smooth(0.45, 0.75, runs) * edge
    kerbs = colband(455.0, 14) + colband(569.0, 14)
    kerbweed = kerbs * smooth(0.36, 0.55, tp) * smooth(0.3, 0.55, mid) * edge
    weed = np.clip(np.maximum.reduce([kelp, joint * smooth(0.3, 0.5, tp) * edge, railweed, kerbweed]), 0, 1)
    kelp_col = mix(rgb((50, 56, 36)), rgb((62, 54, 38)), smooth(0.4, 0.6, mid)) * (0.85 + 0.3 * fine[..., None])
    barn_col = rgb((160, 156, 146)) * (0.85 + 0.2 * fine[..., None])
    # height gradient: blend the two source normals, add barnacles, weed ridges, slight algae mounds
    ch = barn_h = bh * 1.0 + weed * 0.35 * runs
    bgx = (np.roll(ch, -1, 1) - np.roll(ch, 1, 1)) * 0.5 * 2.2
    bgy = (np.roll(ch, -1, 0) - np.roll(ch, 1, 0)) * 0.5 * 2.2

    out = {}
    for state, sfx in (("dry", ""), ("wet", "_Wet")):
        C = half_tile(load(MAT + "/T_Mat_Concrete_ALB%s.png" % sfx))
        W = half_tile(load(MAT + "/T_Mat_WeedyConcrete_ALB%s.png" % sfx))
        Cr = half_tile(load(MAT + "/T_Mat_Concrete_RGH%s.png" % sfx))
        Wr = half_tile(load(MAT + "/T_Mat_WeedyConcrete_RGH%s.png" % sfx))
        k = 1.0 if state == "dry" else 0.74
        alb = mix(C, W, m)
        alb = mix(alb, alb * rgb((0.86, 0.95, 0.8)) + rgb((6, 10, 2)), algae * 0.8)
        alb = alb * (1 - 0.3 * wet[..., None] * edge[..., None] * (1 if state == "dry" else 0.4))
        alb = mix(alb, rgb((96, 74, 58)) * k * (0.8 + 0.4 * fine[..., None]), rustbleed * 0.45)
        alb = mix(alb, kelp_col * k, weed * 0.92)
        alb = mix(alb, barn_col * k, bcov * 0.9)
        alb = alb * (1 - 0.6 * bpit[..., None])
        rg = Cr * (1 - m) + Wr * m
        wr = 0.3 + 0.08 * fine if state == "dry" else 0.2 + 0.05 * fine
        rg = mix(rg, wr, wet * edge)
        rg = mix(rg, (0.34 if state == "dry" else 0.22) + 0.1 * fine, weed)
        rg = mix(rg, (0.8 if state == "dry" else 0.55), bcov * 0.8)
        # H3: dark wet band, green-brown algae film and a waterline stain over the lower band (waterline at t = 1)
        film = smooth(0.6, 0.78, tp + 0.08 * (big - 0.5)) * (1 - smooth(0.95, 1.0, t))
        stain = np.exp(-((tp - 0.62) / 0.02) ** 2) * smooth(0.04, 0.1, t) * (1 - smooth(0.88, 0.96, t))
        fcol = mix(rgb((58, 66, 38)), rgb((74, 62, 40)), smooth(0.4, 0.6, big)) * (0.8 + 0.4 * fine[..., None]) * k
        alb = mix(alb, alb * 0.58, film)
        alb = mix(alb, fcol, film * 0.6 * (1 - bcov))
        alb = mix(alb, rgb((46, 40, 30)) * k, stain * 0.65)
        rg = mix(rg, (0.24 if state == "dry" else 0.14) + 0.06 * fine, film * (1 - bcov))
        out[state] = (alb, rg)
    cgx, cgy = grad_of(half_tile(load(MAT + "/T_Mat_Concrete_NOR.png")))
    wgx, wgy = grad_of(half_tile(load(MAT + "/T_Mat_WeedyConcrete_NOR.png")))
    soften = 1 - 0.6 * weed                                   # weed blankets the concrete texture
    gx = (cgx * (1 - m) + wgx * m) * soften + bgx * edge
    gy = (cgy * (1 - m) + wgy * m) * soften + bgy * edge
    nor = nor_of(gx, gy)
    stem = "T_Slipway_Tide"
    write(OUT, stem, "ALB", np.clip(out["dry"][0], 22 / 255, 238 / 255), "RGB")
    write(OUT, stem, "ALB_Wet", np.clip(np.minimum(out["wet"][0], out["dry"][0] * 0.86), 22 / 255, 238 / 255), "RGB")
    write(OUT, stem, "RGH", np.clip(out["dry"][1], 0.05, 1), "L")
    write(OUT, stem, "RGH_Wet", np.clip(np.minimum(out["wet"][1], out["dry"][1] - 0.04), 0.05, 1), "L")
    write(OUT, stem, "NOR", nor, "RGB")
    write(OUT, stem, "MET", np.zeros(s), "L")


# ---------------------------------------------------------------- kit atlas
def box(name):
    u0, v0, u1, v1 = KIT[name]
    return int(round((1 - v1) * N)), int(round((1 - v0) * N)), int(round(u0 * N)), int(round(u1 * N))


def steel_set():
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    big, mid, fine = fbm((N, N), 3.0, seed=11), fbm((N, N), 2.2, seed=12), fbm((N, N), 1.2, seed=13)
    vruns = fbm((N, N), 2.4, aniso=(0.12, 1.8), seed=14)        # vertical runs (drips on walls / door)
    hruns = fbm((N, N), 2.4, aniso=(1.8, 0.1), seed=15)         # runs along u (strips: along the part)
    r = np.random.default_rng(21)

    # --- Wall: concrete block, 440 x 215 + 10 mm joints; rect = 3 m x 3 m (z 0 .. 3 m), 170.7 px / m
    r0, r1, c0, c1 = box("Wall")
    hh, ww = r1 - r0, c1 - c0
    ppm = ww / 3.0
    yy, xx = np.mgrid[0:hh, 0:ww]
    zm = (hh - 0.5 - yy) / ppm
    xm = xx / ppm
    course = np.floor(zm / 0.225).astype(int)
    fz = (zm / 0.225) % 1.0
    off = np.where(course % 2 == 0, 0.0, 0.225)
    bx = (xm + off) / 0.45
    bi = np.floor(bx).astype(int)
    fx = bx % 1.0
    dpx = np.minimum(np.minimum(fz, 1 - fz) * 0.225 * ppm, np.minimum(fx, 1 - fx) * 0.45 * ppm)
    mortar = 1 - smooth(0.6, 1.9, dpx)
    slot = (course * 37 + bi * 11) % 997
    tone = r.uniform(0.86, 1.1, 997)[slot]
    tint = r.normal(0, 0.012, (997, 3))[slot]
    g = fine[r0:r1, c0:c1]
    blk = rgb((124, 122, 116))[None, None, :] * (tone * (0.9 + 0.18 * g) * (0.95 + 0.1 * big[r0:r1, c0:c1]))[..., None] + tint
    pits = smooth(0.8, 0.92, fbm((hh, ww), 0.9, seed=16))
    blk = blk * (1 - 0.25 * pits[..., None])
    reg = mix(blk, rgb((142, 140, 132)) * (0.92 + 0.12 * g[..., None]), mortar * 0.9)
    run = vruns[r0:r1, c0:c1]
    drip = smooth(0.52, 0.8, run) * (0.35 + 0.65 * smooth(0.8, 2.9, zm)) + smooth(2.6, 2.95, zm) * 0.6
    drip = np.clip(drip * (0.7 + 0.5 * mid[r0:r1, c0:c1]), 0, 1)
    reg = mix(reg, reg * rgb((0.62, 0.64, 0.6)), drip * 0.75)
    rustdrip = smooth(0.7, 0.85, run) * smooth(1.6, 2.9, zm) * smooth(0.5, 0.7, big[r0:r1, c0:c1])
    reg = mix(reg, rgb((98, 82, 68)), rustdrip * 0.5)
    splash = 1 - smooth(0.12, 0.5, zm + 0.18 * (mid[r0:r1, c0:c1] - 0.5))
    reg = mix(reg, reg * rgb((0.68, 0.76, 0.6)) + rgb((6, 10, 2)), splash * 0.85)
    salt = smooth(0.66, 0.8, fine[r0:r1, c0:c1] * 0.5 + big[r0:r1, c0:c1] * 0.5) * mortar * smooth(0.3, 1.2, zm)
    reg = mix(reg, rgb((176, 174, 168)), salt * 0.5)
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.88 + 0.06 * g - 0.12 * drip * 0.5 - 0.1 * splash
    hgt[r0:r1, c0:c1] = -mortar * 1.2 + 0.25 * g - 0.4 * pits + 0.15 * tone

    # --- Door: painted pressed-steel leaf 0.9 x 2.0 m, 2 x 2 panels (geometry raised panels line up)
    r0, r1, c0, c1 = box("Door")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    zd = 2.0 * (1 - (yy + 0.5) / hh)       # 0 bottom .. 2 m top of the leaf
    xd = 0.9 * (xx + 0.5) / ww
    pan = np.zeros((hh, ww))
    for (za, zb) in ((0.15, 0.9), (1.1, 1.85)):
        for (xa, xb) in ((0.07, 0.42), (0.48, 0.83)):
            d = np.minimum(np.minimum(zd - za, zb - zd), np.minimum(xd - xa, xb - xd))
            pan = np.maximum(pan, np.exp(-(d / 0.012) ** 2) * (np.abs(d) < 0.05))
    paint = rgb((54, 70, 86)) * (0.9 + 0.14 * big[r0:r1, c0:c1, None] + 0.04 * fine[r0:r1, c0:c1, None])
    reg = paint * (1 - 0.35 * pan[..., None])
    kick = (1 - smooth(0.05, 0.3, zd + 0.12 * (fine[r0:r1, c0:c1] - 0.5))) * smooth(0.3, 0.55, mid[r0:r1, c0:c1] + 0.2)
    run = vruns[r0:r1, c0:c1]
    rstreak = smooth(0.62, 0.8, run) * (1 - smooth(0.4, 1.9, zd)) + smooth(0.68, 0.82, run) * np.exp(-((xd - 0.78) / 0.06) ** 2) * (zd < 1.0) * 0.8
    rust = np.clip(np.maximum(kick, rstreak * 0.7), 0, 1)
    wear = np.exp(-(((xd - 0.78) / 0.09) ** 2 + ((zd - 1.0) / 0.16) ** 2)) * smooth(0.35, 0.6, fine[r0:r1, c0:c1])
    edgew = (1 - smooth(0.0, 0.025, np.minimum(np.minimum(xd, 0.9 - xd), np.minimum(zd, 2.0 - zd)))) * smooth(0.45, 0.7, fine[r0:r1, c0:c1])
    reg = mix(reg, rgb((112, 108, 100)), np.clip(wear + edgew, 0, 1) * 0.6)
    reg = mix(reg, rgb((92, 72, 58)) * (0.8 + 0.35 * fine[r0:r1, c0:c1, None]), rust * 0.85)
    salt = smooth(0.7, 0.85, fine[r0:r1, c0:c1]) * (1 - smooth(0.0, 0.6, zd))
    reg = mix(reg, rgb((150, 150, 144)), salt * 0.35)
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.5 + 0.08 * big[r0:r1, c0:c1] + 0.35 * rust + 0.2 * wear
    hgt[r0:r1, c0:c1] = -pan * 0.6 + rust * 0.4 * fine[r0:r1, c0:c1]

    # --- Vent backing: dark interior behind the louvres, insect mesh
    r0, r1, c0, c1 = box("Vent")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    mesh = np.maximum((yy % 6) < 1, (xx % 6) < 1).astype(float)
    reg = rgb((32, 32, 31)) * (0.9 + 0.2 * fine[r0:r1, c0:c1, None])
    reg = mix(reg, rgb((62, 58, 52)), mesh * 0.7)
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.8
    hgt[r0:r1, c0:c1] = mesh * 0.3

    # --- Plate: painted housing steel, streaked
    r0, r1, c0, c1 = box("Plate")
    reg = rgb((56, 72, 86)) * (0.9 + 0.12 * big[r0:r1, c0:c1, None])
    st = smooth(0.6, 0.85, vruns[r0:r1, c0:c1])[..., None]
    reg = mix(reg, rgb((96, 78, 64)), st[..., 0] * 0.5)
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.55 + 0.25 * st[..., 0]
    hgt[r0:r1, c0:c1] = 0.1 * fine[r0:r1, c0:c1]

    def strip(name):
        r0, r1, c0, c1 = box(name)
        ry = ((np.arange(r1 - r0) + 0.5) / (r1 - r0))[:, None] * np.ones((1, c1 - c0))
        return r0, r1, ry

    # --- Roof: weathered corrugated sheet (dull zinc, white rust, rust runs down the slope = along u)
    r0, r1, ry = strip("Roof")
    sl = slice(r0, r1)
    zinc = rgb((120, 122, 120)) * (0.88 + 0.2 * big[sl, :, None] + 0.06 * fine[sl, :, None])
    wr = smooth(0.66, 0.82, mid[sl])
    reg = mix(zinc, rgb((150, 150, 146)), wr * 0.6)
    rr = np.clip(smooth(0.58, 0.78, hruns[sl] * 0.7 + big[sl] * 0.3) + smooth(0.8, 0.92, fine[sl]) * 0.5, 0, 1)
    reg = mix(reg, rgb((90, 72, 60)) * (0.8 + 0.4 * fine[sl, :, None]), rr * 0.85)
    lich = smooth(0.78, 0.9, fbm((r1 - r0, N), 2.0, seed=17))
    reg = mix(reg, rgb((128, 130, 108)), lich * 0.5)
    alb[sl] = reg
    rgh[sl] = 0.62 + 0.1 * fine[sl] + 0.22 * rr
    hgt[sl] = 0.4 * rr * fine[sl] + 0.1 * big[sl]

    # --- Rust: heavy rust and mill scale (non-metal, dark)
    r0, r1, ry = strip("Rust")
    sl = slice(r0, r1)
    base = mix(rgb((84, 68, 56)), rgb((100, 78, 62)), smooth(0.4, 0.7, mid[sl]))
    reg = base * (0.78 + 0.4 * fine[sl, :, None])
    scale = smooth(0.55, 0.7, big[sl] * 0.6 + hruns[sl] * 0.4)
    reg = mix(reg, rgb((54, 50, 47)) * (0.9 + 0.2 * fine[sl, :, None]), scale * 0.8)
    edge = 1 - smooth(0.0, 0.12, np.minimum(ry, 1 - ry))
    reg = reg * (1 - 0.2 * edge[..., None])
    alb[sl] = reg
    rgh[sl] = 0.86 + 0.1 * fine[sl] - 0.1 * scale
    hgt[sl] = 0.6 * fine[sl] + 0.3 * mid[sl] - 0.3 * scale

    # --- RailHead: polished running band (metal) between rusted, scaled shoulders
    r0, r1, ry = strip("RailHead")
    sl = slice(r0, r1)
    wobble = 0.04 * (hruns[sl] - 0.5) + 0.03 * (mid[sl] - 0.5)
    band = np.abs(ry - 0.5 + wobble) < 0.25
    spots = smooth(0.84, 0.9, fine[sl]) > 0.5
    metal = band & ~spots
    scratch = fbm((r1 - r0, N), 1.6, aniso=(2.0, 0.05), seed=18)
    steel = rgb((196, 194, 190)) * (0.95 + 0.08 * scratch[..., None])
    rustc = mix(rgb((80, 64, 54)), rgb((58, 52, 48)), smooth(0.4, 0.7, big[sl])) * (0.85 + 0.3 * fine[sl, :, None])
    reg = np.where(metal[..., None], np.clip(steel, 186 / 255, 232 / 255), rustc)
    alb[sl] = reg
    met[sl] = metal.astype(float)
    rgh[sl] = np.where(metal, 0.3 + 0.12 * scratch, 0.85 + 0.08 * fine[sl])
    hgt[sl] = np.where(metal, 0.05 * scratch, 0.3 + 0.4 * fine[sl])

    # --- Paint: painted steel (station navy), edge rust, rust blooms, salt
    r0, r1, ry = strip("Paint")
    sl = slice(r0, r1)
    reg = rgb((52, 68, 84)) * (0.9 + 0.14 * big[sl, :, None] + 0.04 * fine[sl, :, None])
    ed = 1 - smooth(0.02, 0.16 + 0.08 * mid[sl], np.minimum(ry, 1 - ry))
    bloom = smooth(0.78, 0.9, mid[sl] * 0.5 + fine[sl] * 0.5)
    ru = np.clip(np.maximum(ed * smooth(0.3, 0.55, fine[sl]), bloom), 0, 1)
    reg = mix(reg, rgb((90, 72, 58)) * (0.8 + 0.35 * fine[sl, :, None]), ru * 0.85)
    reg = mix(reg, rgb((140, 140, 136)), smooth(0.75, 0.88, hruns[sl]) * 0.25)
    alb[sl] = reg
    rgh[sl] = 0.5 + 0.08 * big[sl] + 0.35 * ru
    hgt[sl] = 0.4 * ru * fine[sl]

    nor = normal_from_height(hgt, 2.5)
    save(OUT, "T_Slipway_Steel", alb, nor, rgh, met, darken=0.3, gloss=0.35)


def walltide_set():
    """T_Slipway_WallTide: the QuayStone tile (same 3 m phase) with the tidal zone baked in by height. On the walls
    v = z / 3, so image row r is z = -3 r / N (pivot level 0 at the top row, sea level z = -1.333 at row 455)."""
    s = (N, N)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
    zr = -3.0 * yy / N
    h = zr + 1.333                                            # height above sea level
    big, mid, fine = fbm(s, 3.0, seed=61), fbm(s, 2.3, seed=62), fbm(s, 1.3, seed=63)
    line = fbm(s, 2.6, aniso=(1.0, 0.15), seed=64)            # varies along u: ragged tide / splash line
    runs = fbm(s, 2.4, aniso=(0.12, 1.6), seed=65)            # vertical runs reaching above the line
    tl = 0.8 + 0.22 * (line - 0.5) * 2 + 0.12 * (runs - 0.5) * 2
    da = tl - h                                               # depth below the line
    keep = 1 - smooth(-0.16, -0.04, zr)                       # top rows stay pure QuayStone (seam at z = 0)
    wet = smooth(-0.03, 0.03, da) * keep
    stain = smooth(-0.025, 0.0, da) * (1 - smooth(0.03, 0.09, da)) * keep
    alg = smooth(0.12, 0.7, da + 0.3 * (mid - 0.5)) * (0.55 + 0.45 * fine) * keep
    sub = smooth(-0.1, 0.3, -h + 0.2 * (mid - 0.5)) * keep    # below sea level: dense weed film
    salt = smooth(0.0, 0.06, -da) * (1 - smooth(0.06, 0.3, -da)) * smooth(0.45, 0.7, fine * 0.6 + mid * 0.4) * keep
    band = smooth(0.3, 0.45, da) * (1 - smooth(0.8, 1.1, da)) * smooth(0.45, 0.65, big)
    bh, bcov, bpit = barnacles(s, band * keep, 67)
    gcol = mix(rgb((54, 64, 36)), rgb((72, 60, 40)), smooth(0.4, 0.6, big)) * (0.8 + 0.4 * fine[..., None])
    out = {}
    for state, sfx in (("dry", ""), ("wet", "_Wet")):
        A = load(MAT + "/T_Mat_QuayStone_ALB%s.png" % sfx)[..., :3]
        Rg = load(MAT + "/T_Mat_QuayStone_RGH%s.png" % sfx)
        Rg = Rg[..., 0] if Rg.ndim == 3 else Rg
        assert A.shape[:2] == s, A.shape
        k = 1.0 if state == "dry" else 0.74
        alb = mix(A, A * 0.55, wet * (1 if state == "dry" else 0.6))
        alb = mix(alb, gcol * k, alg * 0.7)
        alb = mix(alb, rgb((38, 46, 28)) * k * (0.85 + 0.3 * fine[..., None]), sub * 0.85)
        alb = mix(alb, rgb((44, 38, 28)) * k, stain * 0.7)
        alb = mix(alb, rgb((200, 198, 188)) * k, salt * 0.45)
        alb = mix(alb, rgb((160, 156, 146)) * k * (0.85 + 0.2 * fine[..., None]), bcov * 0.9)
        alb = alb * (1 - 0.6 * bpit[..., None])
        rg = mix(Rg, (0.26 if state == "dry" else 0.14) + 0.06 * fine, np.maximum(wet, sub))
        rg = mix(rg, 0.85, salt * 0.5)
        rg = mix(rg, 0.8 if state == "dry" else 0.55, bcov * 0.8)
        out[state] = (alb, rg)
    gx, gy = grad_of(load(MAT + "/T_Mat_QuayStone_NOR.png")[..., :3])
    soften = 1 - 0.5 * np.maximum(alg, sub)
    bgx = (np.roll(bh, -1, 1) - np.roll(bh, 1, 1)) * 1.1
    bgy = (np.roll(bh, -1, 0) - np.roll(bh, 1, 0)) * 1.1
    nor = nor_of(gx * soften + bgx, gy * soften + bgy)
    stem = "T_Slipway_WallTide"
    write(OUT, stem, "ALB", np.clip(out["dry"][0], 22 / 255, 238 / 255), "RGB")
    write(OUT, stem, "ALB_Wet", np.clip(np.minimum(out["wet"][0], out["dry"][0] * 0.86), 22 / 255, 238 / 255), "RGB")
    write(OUT, stem, "RGH", np.clip(out["dry"][1], 0.05, 1), "L")
    write(OUT, stem, "RGH_Wet", np.clip(np.minimum(out["wet"][1], out["dry"][1] - 0.04), 0.05, 1), "L")
    write(OUT, stem, "NOR", nor, "RGB")
    write(OUT, stem, "MET", np.zeros(s), "L")


if __name__ == "__main__":
    walltide_set()
    tide_set()
    steel_set()
    print("ok")
