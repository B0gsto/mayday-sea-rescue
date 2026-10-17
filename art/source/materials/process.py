"""B02: download the CC0 Poly Haven scans in library.py and write Roblox MaterialVariant maps at SHIP_SIZE.

python3 art/source/materials/process.py [--only SandDry,...]
Downloads go to build/materials/src/<polyhavenId>/ (one fresh dir each, data only). Outputs:
  assets/textures/Materials/T_Mat_<Name>_{ALB,NOR,RGH,MET}.png + _ALB_Wet / _RGH_Wet   (variants)
  assets/textures/M_Bld_TrimSheet/T_BldTrim_Sheet_{ALB,NOR,RGH,MET}[_Wet].png          (building trim sheet)
  build/materials/process.json (seam scores, adjustments)
Wet twin: albedo value x0.74 (05 5.4: -20 to 30%), slight saturation lift, roughness -0.30 (floor 0.06); normal and metalness shared.
"""
import io, json, os, sys, urllib.request
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(GAME, "tools/blender"))
import common  # noqa: E402  (SHIP_SIZE)
from library import LIBRARY, TRIM  # noqa: E402

CAP = common.SHIP_SIZE  # shipped size (EXPORT_CAP is only the maximum)
RES = {512: "1k", 1024: "1k", 2048: "2k", 4096: "4k"}[CAP] if CAP <= 4096 else "4k"
SRC = os.path.join(GAME, "build/materials/src")
OUT = os.path.join(GAME, "assets/textures/Materials")
TRIM_OUT = os.path.join(GAME, "assets/textures/M_Bld_TrimSheet")
UA = {"User-Agent": "MaydaySeaRescue-B02/1.0"}
LO, HI, SAT = 34, 234, 0.42


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
        return r.read()


def fetch(pid):
    d = os.path.join(SRC, pid)
    os.makedirs(d, exist_ok=True)
    files = json.loads(get("https://api.polyhaven.com/files/%s" % pid))
    out = {}
    for key, tag in (("Diffuse", "diff"), ("nor_gl", "nor"), ("Rough", "rough"), ("arm", "arm")):
        if key not in files:
            continue
        res = RES if RES in files[key] else sorted(files[key])[0]
        url = files[key][res]["png"]["url"]
        p = os.path.join(d, "%s_%s.png" % (tag, res))
        if not os.path.exists(p):
            open(p, "wb").write(get(url))
        out[tag] = p
    return out, "https://polyhaven.com/a/%s" % pid


def fit(img):
    if img.size != (CAP, CAP):      # wrap-pad, resize, crop so the tile edges stay seamless
        w, h = img.size
        big = Image.new(img.mode, (w * 3, h * 3))
        for i in range(3):
            for j in range(3):
                big.paste(img, (i * w, j * h))
        big = big.resize((CAP * 3, CAP * 3), Image.LANCZOS)
        img = big.crop((CAP, CAP, 2 * CAP, 2 * CAP))
    return img


def seam_score(a):
    a = a.astype(np.float32)
    inner_x = np.abs(np.diff(a, axis=1)).mean()
    inner_y = np.abs(np.diff(a, axis=0)).mean()
    edge_x = np.abs(a[:, 0] - a[:, -1]).mean()
    edge_y = np.abs(a[0] - a[-1]).mean()
    return float(max(edge_x / max(inner_x, 1e-3), edge_y / max(inner_y, 1e-3)))


def heal(a):
    """Offset blend: edges come from the half-rolled copy, so the wrap is continuous."""
    n = a.shape[0]
    t = np.abs(np.linspace(-1, 1, n))
    w1 = np.clip((1 - t) / 0.35, 0, 1)
    w = np.minimum.outer(w1, w1)[..., None] if a.ndim == 3 else np.minimum.outer(w1, w1)
    r = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    return a * w + r * (1 - w)


def luma(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def grade_albedo(rgb, desat=None, tint=None):
    rgb = rgb.astype(np.float32)
    notes = []
    if tint is not None:
        rgb = rgb * np.array(tint, np.float32)
    y = luma(rgb)[..., None]
    if desat is not None:
        rgb = y + (rgb - y) * desat
        notes.append("desat x%.2f" % desat)
    for _ in range(3):              # saturation ceiling and luma range interact (clipping): iterate
        mx, mn = rgb.max(2), rgb.min(2)
        s95 = np.percentile(np.where(mx > 20, (mx - mn) / np.maximum(mx, 1e-6), 0), 95)
        if s95 > SAT:
            k = SAT / s95
            y = luma(rgb)[..., None]
            rgb = y + (rgb - y) * k
            notes.append("sat x%.2f" % k)
        y = luma(rgb)
        p1, p99 = np.percentile(y, 1), np.percentile(y, 99)
        if p1 < LO or p99 > HI:
            lo, hi = max(p1, 0), p99
            nlo, nhi = max(p1, LO), min(p99, HI)
            scale = (nhi - nlo) / max(hi - lo, 1e-3)
            ny = nlo + (y - lo) * scale
            rgb = rgb * (np.clip(ny, 1, 255) / np.maximum(y, 1))[..., None]
            notes.append("luma %.0f-%.0f -> %.0f-%.0f" % (p1, p99, nlo, nhi))
        rgb = np.clip(rgb, 0, 255)
    return np.clip(rgb, 0, 255), notes


# per-variant luma re-map: (target median, target p1, target p99, warm tint): dark but readable rock, contrast kept
LIFT = {"SplashRock": (74, 46, 122, (1.04, 1.0, 0.95))}


def lift_albedo(rgb, med, p1t, p99t, tint):
    y = luma(rgb)
    p1, p50, p99 = np.percentile(y, [1, 50, 99])
    lo = (med - p1t) / max(p50 - p1, 1e-3); hi = (p99t - med) / max(p99 - p50, 1e-3)
    ny = np.where(y < p50, med + (y - p50) * lo, med + (y - p50) * hi)
    out = rgb * (np.clip(ny, 1, 255) / np.maximum(y, 1))[..., None] * np.array(tint, np.float32)
    return np.clip(out, LO, HI), ["lift luma p1/p50/p99 %.0f/%.0f/%.0f -> %d/%d/%d" % (p1, p50, p99, p1t, med, p99t)]


def band_noise(shape, f0, f1, seed):
    """Tileable noise: white noise band-passed to f0..f1 cycles per tile in the Fourier domain (periodic by
    construction, so the map still tiles), normalised to unit std."""
    rng = np.random.default_rng(seed)
    F = np.fft.fft2(rng.standard_normal(shape))
    fy = np.fft.fftfreq(shape[0]) * shape[0]
    fx = np.fft.fftfreq(shape[1]) * shape[1]
    r = np.hypot(fy[:, None], fx[None, :])
    n = np.real(np.fft.ifft2(F * ((r >= f0) & (r <= f1))))
    return (n / max(n.std(), 1e-6)).astype(np.float32)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# Terrain look-dev (round 2): colour variation baked into the big terrain variants. Mid-frequency only (3-20
# cycles per tile, several blobs per tile, never one distinctive blob per repeat, which would show the tiling);
# the island-scale variation comes from gen_terrain.py dithering Grass / LeafyGrass / Ground. Per name:
# (base tint, clump darkening, straw amount, straw tint, seed, overall gain)
MACRO = {
    "Turf": ((0.80, 1.0, 0.70), 0.22, 0.34, (1.22, 1.06, 0.78), 11, 0.94),   # olive turf, dark clumps, dead-grass straw
    "Moor": ((0.97, 0.96, 0.93), 0.20, 0.0, (1, 1, 1), 12, 0.88),           # withered grass / heath: darker tussocks
    "Earth": ((1.0, 0.98, 0.95), 0.20, 0.18, (0.82, 0.86, 0.70), 13, 1.0),  # dirt: damp dark organic patches, moss tinge
}


def macro_albedo(rgb, name):
    tint, dark, straw, stint, seed, gain = MACRO[name]
    y0 = luma(rgb)
    med0 = np.percentile(y0, 50)
    out = rgb * np.array(tint, np.float32)
    out *= gain * (med0 / max(np.percentile(luma(out), 50), 1e-3))
    big = band_noise(y0.shape, 2.5, 5, seed)
    clump = band_noise(y0.shape, 9, 22, seed + 1)
    out *= (1 - dark * sstep(0.2, 1.6, clump) * (0.6 + 0.4 * sstep(-1, 1, -big)))[..., None]
    w = (straw * sstep(0.1, 1.4, big) * (0.55 + 0.45 * sstep(-0.5, 1, -clump)))[..., None]
    out = out * (1 - w) + out * np.array(stint, np.float32) * w
    out = np.clip(out, LO, HI)
    return out, ["macro %s: tint %s, clumps -%d%%, straw %d%%, luma p50 %.0f -> %.0f"
                 % (name, tint, dark * 100, straw * 100, med0, np.percentile(luma(out), 50))]


def wet_albedo(rgb):
    rgb = rgb.astype(np.float32) * 0.74
    y = luma(rgb)[..., None]
    rgb = y + (rgb - y) * 1.08
    mx, mn = rgb.max(2), rgb.min(2)
    s95 = np.percentile(np.where(mx > 20, (mx - mn) / np.maximum(mx, 1e-6), 0), 95)
    if s95 > SAT:
        y = luma(rgb)[..., None]
        rgb = y + (rgb - y) * (SAT / s95)
    return np.clip(rgb, 0, 255)


def wet_rough(r):
    return np.clip(r.astype(np.float32) - 0.30 * 255, 0.06 * 255, 255)


def save(arr, mode, path):
    Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8)).convert(mode).save(path, optimize=True)


def load_maps(paths):
    alb = np.asarray(fit(Image.open(paths["diff"]).convert("RGB")), np.float32)
    nor = np.asarray(fit(Image.open(paths["nor"]).convert("RGB")), np.float32)
    if "rough" in paths:
        im = Image.open(paths["rough"])
        if im.mode in ("I;16", "I;16B", "I;16L", "I"):     # 16-bit greyscale: scale, do not clip
            im = Image.fromarray(np.clip(np.asarray(im, np.float32) / (257.0 if np.asarray(im).max() > 255 else 1.0), 0, 255).astype(np.uint8))
        rgh = np.asarray(fit(im.convert("L")), np.float32)
    else:
        rgh = np.asarray(fit(Image.open(paths["arm"]).convert("RGB")), np.float32)[..., 1]
    return alb, nor, rgh


def build_variant(row, report):
    name, pid = row[0], row[1]
    paths, url = fetch(pid)
    alb, nor, rgh = load_maps(paths)
    seam = seam_score(luma(alb))
    healed = False
    if seam > 1.6 and row[5] == "Organic":   # regular block layouts score high on true joints; PH maps are tileable
        alb, nor, rgh = heal(alb), heal(nor), heal(rgh)
        healed, seam2 = True, seam_score(luma(alb))
    desat = 0.15 if name == "NonSlipDeck" else None
    tint = (1.1, 1.1, 1.1) if name == "NonSlipDeck" else None
    alb, notes = grade_albedo(alb, desat, tint)
    if name in LIFT:   # K1 fix: dark_rock graded to a flat near-black slab (luma p50 38, p99 51; wet 28): wet lava / oil in-engine
        alb, n2 = lift_albedo(alb, *LIFT[name])
        notes += n2
    if name in MACRO:  # terrain look-dev round 2: baked colour variation (no flat colours)
        alb, n3 = macro_albedo(alb, name)
        notes += n3
    stem = os.path.join(OUT, "T_Mat_%s_" % name)
    save(alb, "RGB", stem + "ALB.png")
    save(nor, "RGB", stem + "NOR.png")
    save(rgh, "L", stem + "RGH.png")
    save(np.zeros(rgh.shape, np.float32), "L", stem + "MET.png")
    save(wet_albedo(alb), "RGB", stem + "ALB_Wet.png")
    save(wet_rough(rgh), "L", stem + "RGH_Wet.png")
    report[name] = {"source": pid, "url": url, "seam": round(seam, 2), "healed": healed,
                    "seam_after": round(seam2, 2) if healed else None, "grade": notes,
                    "rgh_mean": round(float(rgh.mean()) / 255, 2)}


def profile(kind, h):
    """Height (0..1) across a strip of h px, plus a cavity factor (darkens grooves)."""
    v = (np.arange(h) + 0.5) / h
    if kind == "round":
        z = np.sqrt(np.clip(1 - (2 * v - 1) ** 2, 0, 1))
    elif kind == "bevel1":
        z = np.clip(np.minimum(v, 1 - v) / 0.12, 0, 1)
    elif kind == "bevel2":       # frame with an inner rebate step
        z = np.clip(np.minimum(v, 1 - v) / 0.08, 0, 1) * 0.6 + 0.4 * np.clip((np.minimum(v, 1 - v) - 0.22) / 0.06, 0, 1)
    elif kind == "sill":         # weathered top slope + drip groove
        z = np.clip(v / 0.1, 0, 1) * (1 - 0.25 * v) - 0.35 * np.exp(-((v - 0.85) / 0.03) ** 2)
        z = z * np.clip((1 - v) / 0.05, 0, 1)
    elif kind == "panel":        # raised field with chamfers
        z = 0.5 * np.clip(np.minimum(v, 1 - v) / 0.06, 0, 1) + 0.5 * np.clip((np.minimum(v, 1 - v) - 0.15) / 0.1, 0, 1)
    else:
        z = np.ones(h) * 0.98
        z[:2] = z[-2:] = 0.5
    return z.astype(np.float32)


def build_trim(report):
    os.makedirs(TRIM_OUT, exist_ok=True)
    W = CAP
    scale = CAP / 1024.0
    alb = np.zeros((W, W, 3), np.float32)
    nor = np.zeros((W, W, 3), np.float32)
    rgh = np.zeros((W, W), np.float32)
    met = np.zeros((W, W), np.float32)
    y0, layout = 0, []
    cache = {}
    for name, pid, hpx, prof, metal, tint in TRIM:
        h = int(round(hpx * scale))
        if pid not in cache:
            paths, url = fetch(pid)
            cache[pid] = (load_maps(paths), url)
        (a, n, r), url = cache[pid]
        off = (hash(name) % 7) * W // 7
        a, n, r = a[off:off + h] if off + h <= W else a[:h], n[off:off + h] if off + h <= W else n[:h], r[off:off + h] if off + h <= W else r[:h]
        a = a.copy()
        if tint is not None:
            a = a * np.array(tint, np.float32)
        z = profile(prof, h)
        dz = np.gradient(z) * h / 6.0          # profile slope -> normal tilt (green, OpenGL: +Y is up the sheet)
        tilt = np.stack([np.zeros_like(dz), dz, np.ones_like(dz)], -1)
        tilt /= np.linalg.norm(tilt, axis=-1, keepdims=True)
        dn = n / 127.5 - 1
        comb = np.empty_like(dn)               # whiteout blend of the detail normal on the profile normal
        comb[..., 0] = dn[..., 0] + tilt[None, :, 0].T
        comb[..., 1] = dn[..., 1] + tilt[:, None, 1]
        comb[..., 2] = dn[..., 2] * tilt[:, None, 2]
        comb /= np.linalg.norm(comb, axis=-1, keepdims=True)
        cav = (0.75 + 0.25 * np.clip(z, 0, 1))[:, None, None]
        a = a * cav
        if metal:
            y = luma(a)[..., None]
            a = 212 + (y - y.mean()) * 0.3 + 0 * a
        alb[y0:y0 + h], nor[y0:y0 + h], rgh[y0:y0 + h] = a, (comb + 1) * 127.5, r
        met[y0 + 8:y0 + h - 8] = 255 if metal else 0     # 8 px non-metal fold at the strip edges (mip bleed)
        layout.append({"strip": name, "v0": y0 / W, "v1": (y0 + h) / W, "source": pid, "url": url, "profile": prof, "metal": metal})
        y0 += h
    assert y0 == W, y0
    alb_metal = met > 127
    g, notes = grade_albedo(np.where(alb_metal[..., None], 120, alb))
    alb = np.where(alb_metal[..., None], np.clip(alb, 192, 245), g)
    stem = os.path.join(TRIM_OUT, "T_BldTrim_Sheet_")
    save(alb, "RGB", stem + "ALB.png")
    save(nor, "RGB", stem + "NOR.png")
    save(rgh, "L", stem + "RGH.png")
    save(met, "L", stem + "MET.png")
    wa = np.where(alb_metal[..., None], alb * 0.88, wet_albedo(alb))
    save(wa, "RGB", stem + "ALB_Wet.png")
    save(wet_rough(rgh), "L", stem + "RGH_Wet.png")
    json.dump({"size": W, "strips": layout}, open(os.path.join(TRIM_OUT, "layout.json"), "w"), indent=1)
    report["_trim"] = {"strips": len(layout), "grade": notes}


def main():
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    os.makedirs(OUT, exist_ok=True)
    rp = os.path.join(GAME, "build/materials/process.json")
    report = json.load(open(rp)) if os.path.exists(rp) else {}
    for row in LIBRARY:
        if only and row[0] not in only:
            continue
        build_variant(row, report)
        print(row[0], report[row[0]], flush=True)
    if not only or "Trim" in only:
        build_trim(report)
        print("trim", report["_trim"])
    json.dump(report, open(rp, "w"), indent=1)


if __name__ == "__main__":
    main()
