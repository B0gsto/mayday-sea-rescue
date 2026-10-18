"""S1a seabed wreck texture sets (system python3 + numpy + Pillow, no heavy slot). CC0 Poly Haven scans, graded and
zoned procedurally (algae, barnacles / tube-worm encrustation, silt, verdigris, concretion). No AI images.

    python3 art/source/seabed/_S1a/maketex.py

Underwater-only assets (docs/12 2.7): every set is the WET look (no dry twin): darker albedo, low and narrow roughness
(0.38 to 0.62) so the wood never reads as a dry plank or a mirror. Masters at 2048 in build/s1a/masters (the scans are 2k),
shipped at 1024 (common.SHIP_SIZE) to assets/textures/<Asset>/.

  T_Morwenna_Wood_*    tiling (tile = 2 m = 6 studs, grain along U): waterlogged oak, olive algae film, silt in the grain,
                       barnacle and serpulid-tube clusters. Ribs, keel, stem, sternpost, strakes, mast, windlass barrel.
  T_Morwenna_Metal_*   trim atlas, strips tile in U: v 0.50..1.00 concreted wrought iron (windlass, chain, mast bands),
                       v 0.25..0.50 verdigris bronze, v 0.00..0.25 bell waist band with raised "MORWENNA 1902" (text in
                       u 0.25..0.75, so u 0.5 is the bell's front). Shared by M_Sea_Bell.
  T_Morwenna_Silt_*    tiling (4 m = 12 studs): silty sand with shell grit (scour, hull fill, silt banks).
  T_Morwenna_Kelp_*    RGBA: four Laminaria blade cards (u quarters, stipe at v 0, alpha cut-out), Kelp MeshPart.
  T_AdmiraltyAnchor_Iron_*  tiling (1 m = 3 studs): wrought iron under concretion, rust bloom, encrusting growth.
"""
import io
import json
import os
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
SRC = G + "build/s1a/src"
MASTERS = G + "build/s1a/masters"
SHIP, M = 1024, 2048
UA = {"User-Agent": "MaydaySeaRescue-S1a/1.0"}
SCANS = {"wood": "rough_wood", "rust": "rust_coarse_01", "verd": "green_metal_rust", "sand": "damp_beach_sand_02"}
FONT = "/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf"


def fetch(pid):
    d = os.path.join(SRC, pid)
    os.makedirs(d, exist_ok=True)
    out = {}
    files = None
    for key in ("Diffuse", "Rough", "Displacement"):
        p = os.path.join(d, key + ".png")
        if not os.path.exists(p):
            if files is None:
                with urllib.request.urlopen(urllib.request.Request("https://api.polyhaven.com/files/" + pid, headers=UA), timeout=60) as r:
                    files = json.loads(r.read())
            url = files[key]["2k"]["png"]["url"]
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r:
                open(p, "wb").write(r.read())
        img = Image.open(p)
        if key == "Diffuse":
            a = np.asarray(img.convert("RGB").resize((M, M), Image.LANCZOS), np.float32) / 255.0
        else:
            a = np.asarray(img.convert("I;16") if img.mode.startswith("I") else img.convert("L"), np.float32)
            a = np.asarray(Image.fromarray((a / max(a.max(), 1) * 65535).astype(np.uint16)).resize((M, M), Image.BILINEAR), np.float32) / 65535.0
        out[key] = a
    return out


def fbm(n, fmin, fmax, beta=1.8, seed=0, aniso=(1.0, 1.0)):
    """Tileable band-limited noise 0..1 (frequencies in cycles per tile)."""
    rng = np.random.default_rng(seed)
    fy = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fx = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    f = np.sqrt(fx * fx + fy * fy)
    amp = np.where((f >= fmin) & (f <= fmax), 1.0 / np.maximum(f, 1e-3) ** beta, 0.0)
    spec = amp * np.exp(2j * np.pi * rng.random((n, n)))
    a = np.real(np.fft.ifft2(spec))
    a -= a.min()
    return a / max(a.max(), 1e-9)


def sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lum(c):
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def normal(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.dstack([-dx, dy, np.ones_like(h)])     # OpenGL: +Y up (image rows grow downward)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def grain_horizontal(maps):
    """Rotate so the scan's grain runs along U (rows): grain = the axis with the smaller luma gradient."""
    l = lum(maps["Diffuse"])
    gx = np.abs(np.diff(l, axis=1)).mean()
    gy = np.abs(np.diff(l, axis=0)).mean()
    if gx < gy:   # grain vertical -> rotate
        maps = {k: np.ascontiguousarray(np.rot90(v)) for k, v in maps.items()}
    return maps


def stamps(n, count, rmin, rmax, mask, seed, kind="barnacle"):
    """Height field of barnacle cones (ring + hole) or serpulid tubes (short curls), wrapped, placed where mask is high."""
    rng = np.random.default_rng(seed)
    h = np.zeros((n, n), np.float32)
    placed = 0
    tries = 0
    while placed < count and tries < count * 20:
        tries += 1
        y, x = rng.integers(0, n, 2)
        if rng.random() > mask[y, x]:
            continue
        r = rng.uniform(rmin, rmax)
        R = int(np.ceil(r)) + 2
        yy, xx = np.mgrid[-R:R + 1, -R:R + 1].astype(np.float32)
        if kind == "barnacle":
            d = np.sqrt(xx * xx + yy * yy) / r
            cone = np.clip(1 - d, 0, 1) ** 0.6
            hole = sm(0.38, 0.22, d)
            k = cone * (1 - 0.8 * hole)
        else:   # tube: a short arc of a thick line
            a0 = rng.uniform(0, 6.28)
            k = np.zeros_like(xx)
            for t in np.linspace(0, 1.6, 12):
                cx, cy = np.cos(a0 + t) * r * 0.7, np.sin(a0 + t) * r * 0.7
                k = np.maximum(k, np.clip(1 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (r * 0.28), 0, 1) ** 0.5)
        iy = (np.arange(y - R, y + R + 1) % n)[:, None]
        ix = (np.arange(x - R, x + R + 1) % n)[None, :]
        h[iy, ix] = np.maximum(h[iy, ix], k * rng.uniform(0.7, 1.0))
        placed += 1
    return h


def clamp_alb(c, lo=34, hi=228):
    l = lum(c)[..., None]
    lo_, hi_ = lo / 255.0, hi / 255.0
    c = np.where(l < lo_, c + (lo_ - l), c)
    l = lum(c)[..., None]
    c = np.where(l > hi_, c * hi_ / np.maximum(l, 1e-4), c)
    return np.clip(c, 0, 1)


def desat(c, smax=0.42):
    mx, mn = c.max(axis=2, keepdims=True), c.min(axis=2, keepdims=True)
    s = (mx - mn) / np.maximum(mx, 1e-4)
    k = np.where(s > smax, smax / np.maximum(s, 1e-4), 1.0)
    l = c.mean(axis=2, keepdims=True)
    return l + (c - l) * k


def save(asset, stem, alb, nor, rgh, met, alpha=None):
    out = G + "assets/textures/" + asset
    os.makedirs(out, exist_ok=True)
    os.makedirs(MASTERS, exist_ok=True)
    alb = desat(clamp_alb(desat(alb, 0.38)), 0.40)
    imgs = {
        "ALB": Image.fromarray((alb * 255 + 0.5).astype(np.uint8), "RGB"),
        "NOR": Image.fromarray((np.clip(nor, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB"),
        "RGH": Image.fromarray((np.clip(rgh, 0, 1) * 255 + 0.5).astype(np.uint8), "L"),
        "MET": Image.fromarray((np.clip(met, 0, 1) * 255 + 0.5).astype(np.uint8), "L"),
    }
    if alpha is not None:
        rgba = imgs["ALB"].convert("RGBA")
        rgba.putalpha(Image.fromarray((np.clip(alpha, 0, 1) * 255 + 0.5).astype(np.uint8), "L"))
        imgs["ALB"] = rgba
    for k, im in imgs.items():
        im.save(os.path.join(MASTERS, "%s_%s.png" % (stem, k)))
        im.resize((SHIP, SHIP), Image.LANCZOS).save(os.path.join(out, "%s_%s.png" % (stem, k)))
    print("wrote", stem, "albedo luma %.0f..%.0f" % (lum(alb).min() * 255, lum(alb).max() * 255))


# ------------------------------------------------------------------ wood
def wood_set():
    s = grain_horizontal(fetch(SCANS["wood"]))
    base = s["Diffuse"]
    l = lum(base)
    l = (l - l.mean()) / (l.std() + 1e-6)
    oak = np.array([0.24, 0.20, 0.15])                 # waterlogged oak, grey-brown
    alb = oak[None, None, :] * (1 + 0.22 * l[..., None])
    hgt = s["Displacement"]
    crev = sm(0.55, 0.15, hgt)                          # low = grain crevices
    silt = np.array([0.36, 0.33, 0.27])
    alb = alb * (1 - 0.45 * crev[..., None]) + silt * 0.45 * crev[..., None]
    algae_m = sm(0.35, 0.75, fbm(M, 2, 24, 1.6, 11))
    algae = np.array([0.20, 0.23, 0.12])
    alb = alb * (1 - 0.55 * algae_m[..., None]) + algae * 0.55 * algae_m[..., None]
    patch = sm(0.58, 0.78, fbm(M, 2, 16, 1.7, 12))
    barn = stamps(M, 900, 3.0, 9.0, 0.08 + 0.92 * patch, 13, "barnacle")
    tube = stamps(M, 500, 4.0, 8.0, 0.15 + 0.85 * sm(0.45, 0.7, fbm(M, 2, 16, 1.7, 14)), 15, "tube")
    enc = np.maximum(barn, tube * 0.9)
    shell = np.array([0.56, 0.54, 0.47]) * (0.85 + 0.15 * fbm(M, 40, 200, 1.0, 16))[..., None]
    alb = alb * (1 - enc[..., None]) + shell * enc[..., None]
    h = hgt * 0.8 + enc * 2.2
    nor = normal(Image_blur(h, 0.8), 6.0)
    rgh = 0.48 + 0.08 * (s["Rough"] - s["Rough"].mean()) + 0.10 * enc - 0.04 * algae_m
    save("M_Sea_Morwenna", "T_Morwenna_Wood", alb, nor, np.clip(rgh, 0.38, 0.62), np.zeros((M, M)))


def Image_blur(a, r):
    """Wrapped (tile-safe) Gaussian blur via FFT, sigma r px."""
    if r <= 0:
        return a
    n0, n1 = a.shape
    fy = np.fft.fftfreq(n0)[:, None]
    fx = np.fft.fftfreq(n1)[None, :]
    k = np.exp(-2 * (np.pi * r) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * k)).astype(np.float32)


# ------------------------------------------------------------------ iron / bronze
def iron_fields(seed, growth):
    s = fetch(SCANS["rust"])
    base = s["Diffuse"]
    l = lum(base)
    l = (l - l.mean()) / (l.std() + 1e-6)
    conc = np.array([0.28, 0.20, 0.15])                 # concretion: dark rust-brown
    alb = conc[None, None, :] * (1 + 0.25 * l[..., None])
    bloom = sm(0.6, 0.85, fbm(M, 3, 30, 1.5, seed))
    alb = alb * (1 - 0.5 * bloom[..., None]) + np.array([0.42, 0.24, 0.13]) * 0.5 * bloom[..., None]
    g = sm(0.5 - growth * 0.3, 0.8 - growth * 0.3, fbm(M, 2, 20, 1.6, seed + 1))
    alb = alb * (1 - 0.6 * g[..., None]) + np.array([0.27, 0.29, 0.20]) * 0.6 * g[..., None]
    barn = stamps(M, int(500 * growth + 200), 3.0, 8.0, 0.1 + 0.9 * g, seed + 2, "barnacle")
    alb = alb * (1 - barn[..., None]) + np.array([0.55, 0.53, 0.47]) * barn[..., None]
    h = s["Displacement"] * 1.2 + barn * 2.0 + fbm(M, 4, 60, 1.4, seed + 3) * 0.8
    rgh = 0.52 + 0.06 * (s["Rough"] - s["Rough"].mean()) + 0.06 * barn - 0.03 * bloom
    return alb, h, np.clip(rgh, 0.42, 0.66)


def metal_set():
    alb = np.zeros((M, M, 3), np.float32)
    h = np.zeros((M, M), np.float32)
    rgh = np.zeros((M, M), np.float32)
    met = np.zeros((M, M), np.float32)
    # rows: image row 0 = v 1.0
    ia, ih, ir = iron_fields(21, 0.6)
    r_iron = slice(0, M // 2)
    alb[r_iron], h[r_iron], rgh[r_iron] = ia[: M // 2], ih[: M // 2], ir[: M // 2]
    v = fetch(SCANS["verd"])
    vl = lum(v["Diffuse"])
    vl = (vl - vl.mean()) / (vl.std() + 1e-6)
    verd = np.array([0.30, 0.44, 0.38])
    bronze = np.array([0.40, 0.29, 0.17])
    show = sm(0.62, 0.8, fbm(M, 3, 24, 1.6, 31))            # bronze showing through the patina
    b_alb = verd * (1 + 0.18 * vl[..., None])
    b_alb = b_alb * (1 - show[..., None]) + bronze * (1 + 0.15 * vl[..., None]) * show[..., None]
    dark = sm(0.55, 0.85, fbm(M, 2, 12, 1.7, 32))           # silt / dark sulphide film
    b_alb = b_alb * (1 - 0.35 * dark[..., None])
    b_h = v["Displacement"] * 0.6 + fbm(M, 8, 80, 1.2, 33) * 0.4
    b_rgh = 0.50 + 0.06 * (v["Rough"] - v["Rough"].mean()) - 0.08 * show
    b_met = 0.35 * show
    r_b = slice(M // 2, 3 * M // 4)
    alb[r_b], h[r_b], rgh[r_b], met[r_b] = b_alb[: M // 4], b_h[: M // 4], b_rgh[: M // 4], b_met[: M // 4]
    # lettering band (v 0..0.25): same patina, raised serif capitals, tops rubbed to bronze
    r_t = slice(3 * M // 4, M)
    H = M // 4
    txt = Image.new("L", (M, H), 0)
    d = ImageDraw.Draw(txt)
    font = ImageFont.truetype(FONT, int(H * 0.42))
    msg = "MORWENNA   1902"
    w = d.textlength(msg, font=font)
    track = (M * 0.5 - w) / (len(msg) - 1)
    x = M * 0.25
    for ch in msg:
        d.text((x, H * 0.27), ch, fill=255, font=font)
        x += d.textlength(ch, font=font) + track
    t = np.asarray(txt.filter(ImageFilter.GaussianBlur(1.6)), np.float32) / 255.0
    rim = np.zeros((H, M), np.float32)
    rim[int(H * 0.08):int(H * 0.14)] = 1
    rim[int(H * 0.86):int(H * 0.92)] = 1                   # two cast fillet lines around the band
    rim = np.asarray(Image.fromarray((rim * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2)), np.float32) / 255.0
    raised = np.maximum(t, rim)
    t_alb = b_alb[M // 4: M // 2].copy()
    rub = sm(0.6, 0.95, t)[..., None] * (0.35 + 0.65 * fbm(M, 4, 30, 1.5, 34)[: H, :, None])
    t_alb = t_alb * (1 - rub) + bronze * 1.15 * rub
    alb[r_t] = t_alb
    h[r_t] = b_h[M // 4: M // 2] * 0.5 + raised * 3.0
    rgh[r_t] = b_rgh[M // 4: M // 2] - 0.08 * rub[..., 0]
    met[r_t] = b_met[M // 4: M // 2] * 0.5 + 0.4 * rub[..., 0]
    nor = normal(Image_blur(h, 0.7), 5.0)
    save("M_Sea_Morwenna", "T_Morwenna_Metal", alb, nor, np.clip(rgh, 0.38, 0.66), np.clip(met, 0, 0.42))


# ------------------------------------------------------------------ sand + kelp
def seabed_set():
    s = fetch(SCANS["sand"])
    l = lum(s["Diffuse"])
    l = (l - l.mean()) / (l.std() + 1e-6)
    sand = np.array([0.42, 0.39, 0.32])
    alb = sand * (1 + 0.16 * l[..., None])
    silt = sm(0.4, 0.8, fbm(M, 2, 10, 1.8, 41))
    alb = alb * (1 - 0.3 * silt[..., None]) + np.array([0.33, 0.32, 0.27]) * 0.3 * silt[..., None]
    grit = stamps(M, 1200, 1.5, 4.0, np.full((M, M), 0.6), 42, "barnacle")
    alb = alb * (1 - 0.6 * grit[..., None]) + np.array([0.58, 0.55, 0.48]) * 0.6 * grit[..., None]
    h = s["Displacement"] + grit * 0.6
    rgh = 0.55 + 0.05 * (s["Rough"] - s["Rough"].mean())
    nor = normal(Image_blur(h, 0.8), 4.0)
    save("M_Sea_Morwenna", "T_Morwenna_Silt", alb, nor, np.clip(rgh, 0.45, 0.62), np.zeros((M, M)))
    # kelp cards: 4 blades (u quarters), holdfast / stipe at the bottom (v 0), tips at v 1
    alb = np.zeros((M, M, 3), np.float32)
    h = np.zeros((M, M), np.float32)
    rgh = np.zeros((M, M), np.float32)
    alpha = np.ones((M, M), np.float32)
    K0 = 0
    kh = M - K0
    kelp_a = np.zeros((kh, M), np.float32)
    kelp_c = np.zeros((kh, M, 3), np.float32)
    kelp_h = np.zeros((kh, M), np.float32)
    rng = np.random.default_rng(43)
    yy = np.arange(kh)[:, None] / kh                         # 0 top (tip) .. 1 bottom (stipe)
    xs = np.arange(M // 4)[None, :] / (M // 4)
    for i in range(4):
        width = (0.30 + 0.10 * rng.random()) * np.clip(np.sin(np.clip(1.0 - yy, 0, 1) * np.pi * 0.95 + 0.15), 0, 1) ** 0.7
        width = np.where(yy > 0.85, 0.035, width)            # stipe
        wav = 0.03 * np.sin(yy * 23 + i) + 0.015 * np.sin(yy * 61 + 2 * i)
        edge = 0.5 + wav
        dist = np.abs(xs - edge) / np.maximum(width / 2, 1e-3)
        a = sm(1.0, 0.92, dist)
        tear = fbm(256, 4, 40, 1.4, 44 + i)
        tear = np.asarray(Image.fromarray((tear * 255).astype(np.uint8)).resize((M // 4, kh)), np.float32) / 255.0
        a = a * (1 - sm(0.70, 0.8, tear) * sm(0.6, 1.0, dist) * (yy < 0.85))
        a = a * (yy > 0.02)
        col = np.array([0.36, 0.30, 0.15]) * (0.8 + 0.25 * (1 - yy))[..., None] * (0.9 + 0.2 * tear[..., None])
        col = col * (1 - 0.25 * sm(0.3, 0.0, dist))[..., None] + np.array([0.25, 0.22, 0.12]) * 0.25 * sm(0.3, 0.0, dist)[..., None]
        sl = slice(i * M // 4, (i + 1) * M // 4)
        kelp_a[:, sl] = a
        kelp_c[:, sl] = col
        kelp_h[:, sl] = (1 - dist).clip(0, 1) * 0.5 + sm(0.06, 0.0, np.abs(xs - edge)) * 0.4
    bg = np.array([0.28, 0.25, 0.14])
    alb[K0:] = np.where(kelp_a[..., None] > 0.01, kelp_c, bg)
    alpha[K0:] = kelp_a
    h[K0:] = kelp_h
    rgh[K0:] = 0.40 + 0.04 * kelp_h
    nor = normal(Image_blur(h, 0.8), 4.0)
    save("M_Sea_Morwenna", "T_Morwenna_Kelp", alb, nor, np.clip(rgh, 0.38, 0.62), np.zeros((M, M)), alpha)


def anchor_set():
    alb, h, rgh = iron_fields(51, 1.0)
    pink = sm(0.7, 0.85, fbm(M, 3, 20, 1.6, 55))           # sparse encrusting coralline red algae
    alb = alb * (1 - 0.4 * pink[..., None]) + np.array([0.46, 0.32, 0.33]) * 0.4 * pink[..., None]
    nor = normal(Image_blur(h, 0.8), 6.0)
    save("M_Sea_AdmiraltyAnchor", "T_AdmiraltyAnchor_Iron", alb, nor, rgh, np.zeros((M, M)))


if __name__ == "__main__":
    for f in (wood_set, metal_set, seabed_set, anchor_set):
        f()
