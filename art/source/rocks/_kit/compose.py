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


# fix round 1 (AD): banded cream strata on these scans read sedimentary: de-band to jointed warm, rusty grey/pink granite
REGRADE = {"M_Rock_Cliff_01", "M_Rock_Cliff_02", "M_Rock_Ledge_01"}
WET_RGH = (0.24, 0.9)   # wet / below-waterline roughness clamp: no mirror rock (was floor 0.04 -> sun blow-out)


def lowpass(x, cells):
    """Smooth luma field: box-down to cells x cells then bicubic up (scale-free low-pass)."""
    m = float(x.max()) or 1.0
    im = Image.fromarray(np.clip(x / m * 65535, 0, 65535).astype(np.uint16), "I;16").convert("I").convert("F")
    return np.asarray(im.resize((cells, cells), Image.BOX).resize((N, N), Image.BICUBIC), np.float32) * m / 65535


def granite(seed, Ln, covered):
    """Ln (luma / median) -> a granite albedo: scan strata removed, scan cracks kept, coarse feldspar / biotite grain,
    pink-grey blotches, rusty iron stain patches, dark joint lines."""
    band = np.maximum(lowpass(Ln, 24), 0.2)
    hp = np.clip(Ln / band, 0.3, 2.2) ** 1.25                      # scan detail (cracks, pits) without the bands
    blot = fbm(seed + 11, [5, 10, 20, 40])                          # pink vs grey granite blotches
    rust = ss(0.62, 0.8, fbm(seed + 12, [6, 12, 24, 48]))           # iron staining
    grain = fbm(seed + 13, [300, 600], [0.5, 0.5])                   # crystal grain
    bio = ss(0.68, 0.8, fbm(seed + 14, [420, 840], [0.5, 0.5]))      # biotite / hornblende specks
    fsp = ss(0.6, 0.75, fbm(seed + 15, [200, 400], [0.5, 0.5]))      # pink K-feldspar crystals
    j1 = fbm(seed + 16, [10, 20, 40, 80]); j2 = fbm(seed + 17, [14, 28, 56])
    joint = np.maximum(1 - ss(0.0, 0.025, np.abs(j1 - 0.5)), 0.7 * (1 - ss(0.0, 0.02, np.abs(j2 - 0.5))))
    grey, pink, rusty, dark = srgb("#8C8984"), srgb("#9C8981"), srgb("#93785F"), srgb("#4C4A47")
    base = grey * (1 - blot[..., None] * 0.6) + pink * (blot[..., None] * 0.6)
    base = base * (1 - rust[..., None] * 0.55) + rusty * (rust[..., None] * 0.55)
    base = base * (1 - fsp[..., None] * 0.35) + srgb("#B39A8E") * (fsp[..., None] * 0.35)
    base = base * (1 - bio[..., None] * 0.6) + dark * (bio[..., None] * 0.6)
    base = base * (0.92 + 0.16 * grain)[..., None] * (0.88 + 0.24 * blot)[..., None]
    return base * hp[..., None] * (1 - 0.45 * joint)[..., None]


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
    Ln = np.where(Ln > 1.0, 1.0 + 0.55 * (Ln - 1.0), Ln)          # fix 1: highlight roll-off (Clear sun blew faces white)
    chroma = diff - L[..., None]
    if asset in REGRADE:
        alb = granite(seed, Ln, covered) + 0.06 * chroma
    else:
        alb = target[None, None, :] * Ln[..., None] ** 1.05 + 0.3 * chroma
        grain = fbm(seed + 1, [256, 512], [0.5, 0.5])                    # feldspar / mica sparkle variation
        alb *= (0.94 + 0.12 * grain)[..., None]
    rgh = np.clip(arm[..., 1] * 0.55 + 0.4, 0.55, 0.95)
    ao = arm[..., 0]
    alb *= (0.75 + 0.25 * ao)[..., None]
    patch = fbm(seed + 2, [8, 16, 32, 64])
    patch2 = fbm(seed + 3, [12, 24, 48, 96])
    speck = fbm(seed + 4, [384, 768], [0.4, 0.6])
    upm = ss(0.35, 0.85, up)
    xan = srgb("#B27E4C"); grey_l = srgb("#959B8C"); black_l = srgb("#3E3D3A")  # AD: sparse orange + grey-green crustose
    wrack = srgb("#4B4A26") * 1.02; barn = srgb("#A29D90")
    if p["zone"] == "shore":
        wl = float(np.clip(0.4 * H, 0.3, 1.5))
        below = 1 - ss(wl - 0.05, wl + 0.05, z)
        # wet below the waterline (always, tide): darker, glossy
        a_w, r_w = pbrmaps.wet(alb, rgh, darken=0.28, gloss=0.45)
        alb = alb * (1 - below[..., None]) + a_w * below[..., None]
        rgh = rgh * (1 - below) + np.clip(r_w, *WET_RGH) * below
        # wrack: clumps below wl - 0.2 m, more toward the base
        wm = ss(0.42, 0.55, patch * 0.7 + 0.3 * (1 - ss(0, wl, z))) * (1 - ss(wl - 0.35, wl - 0.1, z))
        wcol = wrack[None, None, :] * (0.8 + 0.4 * patch2[..., None])
        wm = wm * (0.7 if asset.startswith("M_Rock_Ledge") else 1.0)   # flat ledges: most texels sit low, keep rock showing
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
    xm = 0.6 * ss(0.78, 0.84, patch * 0.6 + speck * 0.25 + upm * 0.25) * high * upm   # occasional orange
    gm = 0.85 * ss(0.58, 0.7, patch2 * 0.6 + speck * 0.4) * high * (0.3 + 0.7 * upm) * (1 - xm)
    alb = alb * (1 - xm[..., None]) + (xan * (0.85 + 0.25 * speck[..., None])) * xm[..., None]
    alb = alb * (1 - gm[..., None] * 0.8) + (grey_l * (0.9 + 0.2 * speck[..., None])) * gm[..., None] * 0.8
    rgh = np.clip(rgh * (1 - xm - gm * 0.8) + 0.9 * (xm + gm * 0.8), 0.2, 0.98)
    alb = pbrmaps.limit_saturation(np.clip(alb, 0, 1), 0.42)[0]
    alb = np.clip(alb, 34 / 255, 214 / 255)
    met = np.zeros((N, N), np.float32)
    a_wet, r_wet = pbrmaps.wet(alb, rgh, darken=0.3, gloss=0.35)
    a_wet = np.clip(a_wet, 32 / 255, 232 / 255)      # 05 bar: albedo 20-240 sRGB
    r_wet = np.clip(r_wet, *WET_RGH)
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
