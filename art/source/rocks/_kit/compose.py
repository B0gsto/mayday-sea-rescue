"""K1 maps (system python3, no heavy slot): scan diffuse / ARM + the baked NOR / MASK -> T_<Tex>_Granite_* (+ _Wet).
Albedo graded to the 05 palette (granite #8A8781), then coastal zonation from the MASK height / up-facing:
  shore pieces: wrack (below the waterline) -> barnacle band -> black Verrucaria band -> grey rock with yellow
  Xanthoria and grey crustose lichen on top faces; below the waterline the dry set is already wet (dark, glossy).
  lichen pieces: lichen patches on up-facing faces, denser near the top.
The _Wet set is the whole surface rain / spray wet (pbrmaps.wet). Masters 2048 in art/source/rocks/<Asset>/textures/,
exports 1024 in assets/textures/<Asset>/.   python3 compose.py [Asset ...]"""
import json, os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "../../../../tools/blender"))
import pbrmaps  # noqa: E402
from kit import KIT, ROOT, SRC, WORK, SET, piece, size  # noqa: E402

N = 2048


def load(path, mode="RGB"):
    im = Image.open(path).convert(mode)
    if im.size != (N, N):
        im = im.resize((N, N), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def fbm(seed, scales, weights=None):
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N), np.float32)
    weights = weights or [1.0 / (i + 1) for i in range(len(scales))]
    for s, w in zip(scales, weights):
        g = rng.random((s, s)).astype(np.float32)
        out += w * np.asarray(Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)).astype(np.float32) / 255.0
    out -= out.min(); out /= max(out.max(), 1e-6)
    return out


def ss(e0, e1, x):
    return pbrmaps.smoothstep(e0, e1, x)


def srgb(c):
    return np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)], np.float32) / 255.0


def compose(asset):
    p = piece(asset)
    info = json.load(open(WORK + asset + ".json"))
    H = info["size_m"][2]
    seed = sum(map(ord, asset))
    tdir = SRC + p["pid"] + "/textures/"
    diff = load(tdir + [f for f in os.listdir(tdir) if "_diff_" in f][0])
    arm = load(tdir + [f for f in os.listdir(tdir) if "_arm_" in f][0])
    nor = load(WORK + asset + "_NOR.png")
    mask = load(WORK + asset + "_MASK.png")
    z = mask[..., 0] * H              # metres above the base
    up = mask[..., 1] * 2 - 1         # normal Z
    covered = (nor[..., 2] > 0.05)
    v = nor * 2 - 1
    v[~covered] = (0, 0, 1)
    v[..., 2] = np.maximum(v[..., 2], 0.35)                     # no back-facing texels (ray misses on thin edges)
    v /= np.linalg.norm(v, axis=2, keepdims=True)
    nor = v * 0.5 + 0.5
    # 1. grade to granite
    tones = ["#8A8781", "#8E8984", "#85847F", "#8C8680"]
    target = srgb(tones[seed % len(tones)])
    L = pbrmaps.luma(diff)
    med = np.median(L[covered]) if covered.any() else 0.5
    Ln = np.clip(L / max(med, 1e-3), 0.35, 1.9)
    chroma = diff - L[..., None]
    alb = target[None, None, :] * Ln[..., None] ** 1.05 + 0.3 * chroma
    grain = fbm(seed + 1, [256, 512], [0.5, 0.5])                        # feldspar / mica sparkle variation
    alb *= (0.94 + 0.12 * grain)[..., None]
    rgh = np.clip(arm[..., 1] * 0.55 + 0.4, 0.55, 0.95)
    ao = arm[..., 0]
    alb *= (0.75 + 0.25 * ao)[..., None]
    patch = fbm(seed + 2, [8, 16, 32, 64])
    patch2 = fbm(seed + 3, [12, 24, 48, 96])
    speck = fbm(seed + 4, [384, 768], [0.4, 0.6])
    upm = ss(0.35, 0.85, up)
    xan = srgb("#BCA867"); grey_l = srgb("#A9AAA2"); black_l = srgb("#3E3D3A")
    wrack = srgb("#4B4A26") * 1.02; barn = srgb("#A29D90")
    if p["zone"] == "shore":
        wl = float(np.clip(0.4 * H, 0.3, 1.5))
        below = 1 - ss(wl - 0.05, wl + 0.05, z)
        # wet below the waterline (always, tide): darker, glossy
        a_w, r_w = pbrmaps.wet(alb, rgh, darken=0.4, gloss=0.5)
        alb = alb * (1 - below[..., None]) + a_w * below[..., None]
        rgh = rgh * (1 - below) + r_w * below
        # wrack: clumps below wl - 0.2 m, more toward the base
        wm = ss(0.42, 0.55, patch * 0.7 + 0.3 * (1 - ss(0, wl, z))) * (1 - ss(wl - 0.35, wl - 0.1, z))
        wcol = wrack[None, None, :] * (0.8 + 0.4 * patch2[..., None])
        alb = alb * (1 - wm[..., None]) + wcol * wm[..., None]
        rgh = rgh * (1 - wm) + 0.28 * wm
        # barnacle band: wl - 0.35 .. wl + 0.25, broken edge
        band = ss(wl - 0.3, wl - 0.18, z + 0.12 * (patch2 - 0.5)) * (1 - ss(wl + 0.06, wl + 0.18, z + 0.12 * (patch - 0.5)))
        bdots = ss(0.56, 0.68, speck) * band * (1 - wm * 0.7) * 0.85
        alb = alb * (1 - band[..., None] * 0.25)
        alb = alb * (1 - bdots[..., None]) + (barn * (0.85 + 0.25 * speck[..., None])) * bdots[..., None]
        rgh = rgh * (1 - bdots) + 0.88 * bdots
        # black lichen band above
        vb = ss(wl + 0.1, wl + 0.3, z) * (1 - ss(wl + 0.8, wl + 1.3, z + 0.4 * (patch - 0.5))) * ss(0.3, 0.5, patch2)
        alb = alb * (1 - 0.75 * vb[..., None]) + black_l * 0.75 * vb[..., None]
        rgh = rgh * (1 - vb) + 0.62 * vb
        high = ss(wl + 0.9, wl + 1.6, z)
    else:
        high = 0.4 + 0.6 * ss(0.0, H, z)
    # lichens on top faces above the splash zone
    xm = 0.85 * ss(0.66, 0.76, patch * 0.6 + speck * 0.25 + upm * 0.25) * high * upm
    gm = ss(0.55, 0.68, patch2 * 0.7 + speck * 0.3) * high * (0.3 + 0.7 * upm) * (1 - xm)
    alb = alb * (1 - xm[..., None]) + (xan * (0.85 + 0.25 * speck[..., None])) * xm[..., None]
    alb = alb * (1 - gm[..., None] * 0.8) + (grey_l * (0.9 + 0.2 * speck[..., None])) * gm[..., None] * 0.8
    rgh = np.clip(rgh * (1 - xm - gm * 0.8) + 0.9 * (xm + gm * 0.8), 0.2, 0.98)
    alb = pbrmaps.limit_saturation(np.clip(alb, 0, 1), 0.42)[0]
    alb = np.clip(alb, 34 / 255, 232 / 255)
    met = np.zeros((N, N), np.float32)
    a_wet, r_wet = pbrmaps.wet(alb, rgh, darken=0.3, gloss=0.35)
    a_wet = np.clip(a_wet, 32 / 255, 1)
    stem = "T_%s_%s_" % (p["tex"], SET)
    mdir = ROOT + "art/source/rocks/%s/textures/" % asset
    edir = ROOT + "assets/textures/%s/" % asset
    os.makedirs(mdir, exist_ok=True); os.makedirs(edir, exist_ok=True)
    maps = {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met, "ALB_Wet": a_wet, "RGH_Wet": r_wet}
    for k, a in maps.items():
        pbrmaps.write_png(mdir + stem + k + ".png", a)
        pbrmaps.write_png(edir + stem + k + ".png", (a if size(asset) >= N else pbrmaps.downsize(a, size(asset))))
    print(asset, "ok", "H %.2f m" % H, p["zone"])


if __name__ == "__main__":
    for a in (sys.argv[1:] or [r[0] for r in KIT]):
        compose(a)
