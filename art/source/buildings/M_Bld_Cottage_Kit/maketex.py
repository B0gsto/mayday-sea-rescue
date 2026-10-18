"""H3 Cornish cottage kit maps (system python3 + numpy + Pillow, no Blender):
    python3 art/source/buildings/M_Bld_Cottage_Kit/maketex.py
Writes assets/textures/M_Bld_Cottage_Kit/T_Cottage_<Set>_{ALB,NOR,RGH,MET}[_Wet].png, 1024 px, shared by M_Bld_Cottage_01.._06:
  Render_<Colour>  lime render, one tile = 3 m across x 9 m up (walls map v = z / 9 from the ground, so the damp /
                   green splash-back band sits at the base and rain streaks hang from the eaves zone), 5 colours
  Stone            Cornish granite rubble (coursed, lime mortar, per-stone tone); stone grain from the B02 library
                   T_Mat_Granite (Poly Haven rock_face, CC0), tile 2.5 m
  Slate            Delabole-style slate courses (Chandlery slate fields) + Xanthoria orange and grey crust lichen, tile 2 m
  Details          atlas: 6 door leaves, 8 window interiors dim + 8 lit (backplates / GlassLit), glass, lantern glass,
                   strips (tar plinth, ridge tiles, terracotta pots, lead, black iron, slate step, lime mortar, white paint)
Every map is owned procedural work (no AI images) except the granite grain (CC0 scan via the B02 library)."""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
sys.path.insert(0, G + "art/source/buildings/M_Bld_Chandlery_Ext")
import maketex as CH  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

fbm, smooth, nfh, rgb, mix = CH.fbm, CH.smooth, CH.normal_from_height, CH.rgb, CH.mix
OUT = G + "assets/textures/M_Bld_Cottage_Kit"
N = 1024

RENDER = {   # lime render / limewash colours (sRGB), saturation well under the 0.45 ceiling
    "White": (214, 210, 198), "Pink": (204, 162, 148), "Ochre": (204, 178, 128),
    "Sage": (150, 164, 140), "Blue": (148, 170, 182)}

from atlas import DOORS, DOOR_RGB, GLASS, LANTERN, WIN_DIM, WIN_LIT, STRIPS  # noqa: E402


def save(stem, alb, nor, rgh, met, darken=0.33, gloss=0.42, wet_mask=None):
    os.makedirs(OUT, exist_ok=True)
    alb = np.clip(alb, 34 / 255, 236 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    w8 = lambda a: (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(w8(alb)).save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray(w8(nor)).save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray(w8(rgh)).save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray(w8(met)).save(os.path.join(OUT, stem + "_MET.png"))
    wm = np.ones(rgh.shape) if wet_mask is None else wet_mask
    m = met > 0.5
    dk = np.where(m, darken * 0.3, darken) * wm
    walb = np.clip(alb * (1 - dk[..., None]), 30 / 255, 236 / 255)
    wrgh = np.clip(rgh - gloss * wm * (0.6 + 0.4 * rgh), 0.05, 1.0)
    Image.fromarray(w8(walb)).save(os.path.join(OUT, stem + "_ALB_Wet.png"))
    Image.fromarray(w8(wrgh)).save(os.path.join(OUT, stem + "_RGH_Wet.png"))
    print("[maketex] %s  alb mean %s" % (stem, (alb.reshape(-1, 3).mean(0) * 255).round()))


def zero():
    return np.zeros((N, N))


# ---------------------------------------------------------------- lime render (3 m x 9 m tile, row 0 = top = 9 m)
def render_fields():
    """Shared colour-independent fields: brightness multiplier, height, roughness, green / salt / streak masks."""
    s = (N, N)
    zz = (1 - (np.arange(N)[:, None] + 0.5) / N) * 9.0 * np.ones((1, N))     # metres above the ground
    big = fbm(s, 3.0, 8, aniso=(3.0, 1.0), seed=21)            # aniso compensates the 3:1 vertical stretch
    mid = fbm(s, 2.3, 40, aniso=(3.0, 1.0), seed=22)
    fine = fbm(s, 1.6, 300, aniso=(3.0, 1.0), seed=23)
    trowel = fbm(s, 2.6, 18, aniso=(3.0, 1.0), seed=24)
    streak_n = fbm(s, 1.9, 90, aniso=(0.12, 1.0), seed=25)     # long vertical streaks
    streak = smooth(0.55, 0.85, streak_n) * (0.35 + 0.65 * smooth(1.2, 4.8, zz)) * smooth(0.25, 0.65, big)
    damp = 1 - smooth(0.3, 0.95 + 0.3 * mid, zz)                # H3b: heavier rising damp / splash-back to ~1 m, ragged top
    algae = damp * smooth(0.45, 0.7, mid) + 0.4 * (1 - smooth(0.0, 0.25, zz))
    salt = smooth(0.62, 0.8, fbm(s, 2.0, 30, aniso=(3.0, 1.0), seed=26)) * smooth(0.4, 1.0, zz) * (1 - smooth(2.5, 3.6, zz))
    tide = np.abs(zz - (0.9 + 0.25 * (mid - 0.5))) < 0.05 + 0.04 * fine                 # H3b: salt tide line atop the damp
    salt = np.clip(salt + 0.8 * tide * smooth(0.35, 0.6, big) + 0.5 * smooth(0.55, 0.75, fine) * (1 - smooth(0.6, 1.0, zz)), 0, 1)
    cr = fbm(s, 1.2, 200, aniso=(3.0, 1.0), seed=27)
    crack = (np.abs(cr - 0.5) < 0.004) * smooth(0.6, 0.8, big)   # hairline cracks in patches
    patch = smooth(0.78, 0.86, fbm(s, 2.4, 14, aniso=(3.0, 1.0), seed=28))   # newer limewash patches (cleaner)
    bright = (0.93 + 0.08 * big + 0.05 * (mid - 0.5) + 0.04 * (fine - 0.5)) * (1 - 0.18 * streak) * (1 + 0.04 * patch)
    h = 0.5 * trowel + 0.12 * fine + 0.1 * mid - 0.3 * crack - 0.04 * streak
    rgh = 0.86 + 0.06 * (fine - 0.5) - 0.06 * streak + 0.04 * algae - 0.05 * patch
    return dict(bright=bright, h=h, rgh=rgh, streak=streak, damp=damp, algae=algae, salt=salt, crack=crack, zz=zz)


def render_set(colour, F):
    base = rgb(RENDER[colour])
    alb = base[None, None, :] * F["bright"][..., None]
    alb = mix(alb, alb * rgb((150, 150, 140)) / 0.72, 0.5 * F["streak"])      # grey-brown rain dirt
    alb = mix(alb, rgb((96, 104, 78)), 0.55 * np.clip(F["algae"], 0, 1))     # green algae at the base
    alb = mix(alb, alb * 0.74, 0.75 * F["damp"])
    alb = mix(alb, rgb((222, 220, 212)), 0.5 * F["salt"])                    # salt bloom (efflorescence)
    alb = alb * (1 - 0.35 * F["crack"][..., None])
    save("T_Cottage_Render_%s" % colour, alb, nfh(F["h"], 3.0), F["rgh"], zero(), darken=0.3, gloss=0.4)


# ---------------------------------------------------------------- granite rubble (2.5 m tile)
def stone_set():
    s = (N, N)
    r = np.random.default_rng(31)
    scan = np.asarray(Image.open(G + "assets/textures/Materials/T_Mat_Granite_ALB.png").convert("RGB"), dtype=np.float64) / 255
    scan_n = np.asarray(Image.open(G + "assets/textures/Materials/T_Mat_Granite_NOR.png").convert("RGB"), dtype=np.float64) / 255
    lum_scan = scan.mean(-1)
    lum_scan = (lum_scan - lum_scan.mean()) / (lum_scan.std() + 1e-6)
    # coursed rubble: courses of varying height, stones of varying length, rounded corners (distance field)
    yy, xx = np.mgrid[0:N, 0:N]
    cell = np.zeros(s, dtype=np.int32)
    dist = np.zeros(s)
    y = 0
    k = 0
    tone, tint = [], []
    while y < N:
        ch = int(r.integers(70, 150)) if N - y > 160 else N - y
        x = int(r.integers(0, 60))
        xs = [x - N]
        while x < N + 200:
            xs.append(x)
            x += int(r.integers(110, 290))
        for a, b in zip(xs, xs[1:]):
            m = (yy >= y) & (yy < y + ch) & (((xx - a) % N) < (b - a)) & (((xx - a) % N) >= 0)
            m &= ((xx - a) % N) < (b - a)
            if not m.any():
                continue
            k += 1
            cell[m] = k
            lx = ((xx[m] - a) % N).astype(float)
            ly = (yy[m] - y).astype(float)
            dist[m] = np.minimum(np.minimum(lx, (b - a) - lx), np.minimum(ly, ch - ly))
            tone.append(np.clip(r.normal(1.0, 0.11), 0.75, 1.25))
            tint.append(r.normal(0, 0.018, 3) + (np.array([0.02, 0.0, -0.02]) if r.uniform() < 0.25 else 0))
        y += ch
    tone, tint = np.array([1.0] + tone), np.array([[0, 0, 0]] + tint)
    warp = fbm(s, 2.2, 30, seed=32)
    d = dist + 14 * (warp - 0.5)
    joint = 1 - smooth(4, 13, d)                         # mortar joints (recessed, ~1.5 cm)
    face = smooth(4, 40, d)                              # pillowed stone faces
    big = fbm(s, 3.0, 10, seed=33)
    stone = rgb((128, 118, 106)) * tone[cell][..., None] + tint[cell] + 0.07 * lum_scan[..., None]
    stone = stone * (0.94 + 0.06 * scan.mean(-1, keepdims=True) / scan.mean())
    mortar = rgb((150, 146, 134)) * (0.92 + 0.12 * fbm(s, 1.8, 120, seed=34))[..., None]
    alb = mix(stone, mortar, joint)
    lich = smooth(0.74, 0.86, fbm(s, 2.3, 45, seed=35)) * smooth(0.4, 0.7, big)
    alb = mix(alb, rgb((150, 150, 128)), 0.45 * lich)                          # grey crust lichen
    orange = smooth(0.84, 0.92, fbm(s, 2.1, 70, seed=36)) * smooth(0.5, 0.75, big)
    alb = mix(alb, rgb((176, 140, 74)), 0.55 * orange)                         # Xanthoria (muted)
    alb = alb * (0.9 + 0.1 * big[..., None])
    h = 0.55 * face - 0.6 * joint + 0.15 * lum_scan * 0.1 + 0.06 * warp
    nor = nfh(h, 4.0)
    nor = np.clip(nor + (scan_n - 0.5) * 0.35 * face[..., None], 0, 1)
    rgh = 0.78 + 0.08 * joint + 0.06 * lich - 0.05 * face + 0.04 * (big - 0.5)
    save("T_Cottage_Stone", alb, nor, rgh, zero(), darken=0.36, gloss=0.42)


# ---------------------------------------------------------------- slate (2 m tile) with Cornish lichen
def slate_set():
    alb, h, rgh = CH.slate_fields()
    s = (N, N)
    # H3b: stronger per-slate tint (same slot grid as CH.slate_fields: 8 courses x 5 slates, alternate courses offset)
    courses, per = 8, 5
    yy, xx = np.mgrid[0:N, 0:N]
    c = yy // (N // courses)
    k = np.minimum(((xx + np.where(c % 2 == 0, 0, N // (2 * per))) % N) * per // N, per - 1)
    slot = c * per + k
    r = np.random.default_rng(141)
    ns = courses * per
    tone = np.clip(r.normal(1.0, 0.09, ns), 0.8, 1.22)
    hue = np.zeros((ns, 3))
    kind = r.uniform(0, 1, ns)
    hue[kind < 0.18] = (0.018, -0.006, 0.02)            # purple-grey Delabole
    hue[(kind >= 0.18) & (kind < 0.36)] = (-0.012, 0.012, -0.004)   # green-grey
    hue[(kind >= 0.36) & (kind < 0.44)] = (0.03, 0.012, -0.022)     # iron-stained
    hue[(kind >= 0.44) & (kind < 0.56)] = (-0.012, -0.004, 0.022)   # blue-black
    alb = np.clip(alb * tone[slot][..., None] + hue[slot], 0, 1)
    rgh = rgh + 0.06 * (r.uniform(-1, 1, ns))[slot]
    big = fbm(s, 3.0, 9, seed=41)
    xan = smooth(0.80, 0.9, fbm(s, 2.2, 55, seed=42)) * smooth(0.45, 0.75, big)     # orange Xanthoria rosettes
    crust = smooth(0.7, 0.82, fbm(s, 2.4, 35, seed=43)) * smooth(0.3, 0.6, big)     # grey-green crusts
    alb = mix(alb, rgb((168, 132, 72)), 0.6 * xan)
    alb = mix(alb, rgb((132, 136, 116)), 0.45 * crust)
    h = h + 0.08 * xan + 0.05 * crust
    rgh = rgh + 0.15 * xan + 0.1 * crust
    save("T_Cottage_Slate", alb, nfh(h, 5.0), rgh, zero(), darken=0.3, gloss=0.5)


# ---------------------------------------------------------------- details atlas
def px(rect):
    u0, v0, u1, v1 = rect
    return int(round(u0 * N)), int(round((1 - v1) * N)), int(round(u1 * N)), int(round((1 - v0) * N))   # x0, y0, x1, y1


def door_leaf(w, h, col, seed):
    """4-panel ledged door: stiles, rails, raised panels, letterbox, knocker, scuffed bottom rail."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, 1 - yy / h                          # v up, 0 at the threshold
    hgt = np.zeros((h, w))
    panel = np.zeros((h, w), bool)
    for (a, b) in ((0.14, 0.47), (0.53, 0.86)):
        for (c, d) in ((0.08, 0.36), (0.42, 0.62), (0.70, 0.93)):
            m = (u > a) & (u < b) & (v > c) & (v < d)
            if (c, d) == (0.42, 0.62):
                continue
            panel |= m
            e = np.minimum(np.minimum(u - a, b - u) * w, np.minimum(v - c, d - v) * h)
            hgt = np.where(m, -0.6 + 0.6 * smooth(2, 9, e), hgt)
    grain = fbm((h, w), 1.6, 80, aniso=(0.2, 1.0), seed=seed)
    base = rgb(col)
    alb = base * (0.92 + 0.12 * grain)[..., None] * (1 - 0.15 * (hgt < -0.3))[..., None]
    chip = smooth(0.82, 0.9, fbm((h, w), 1.8, 120, seed=seed + 1)) * (1 - smooth(0.0, 0.2, v) * 0.5)
    alb = mix(alb, rgb((128, 112, 92)), 0.6 * chip)                       # flaked paint shows timber
    grime = (1 - smooth(0.0, 0.14, v)) * 0.5 + 0.25 * smooth(0.3, 0.6, fbm((h, w), 2.5, 10, seed=seed + 2))
    alb = alb * (1 - 0.25 * grime)[..., None]
    lb = (u > 0.36) & (u < 0.64) & (v > 0.49) & (v < 0.545)                # brass-dark letterbox
    alb[lb] = rgb((120, 100, 62))
    hgt[lb] = 0.4
    kn = ((u - 0.5) ** 2 * w * w + (v - 0.68) ** 2 * h * h) < (0.05 * w) ** 2
    alb[kn] = rgb((60, 56, 50))
    hgt[kn] = 0.6
    rg = 0.45 + 0.2 * chip + 0.1 * grime
    rg[lb] = 0.35
    return alb, hgt, rg, np.zeros((h, w))


def interior(w, h, seed, lit):
    """A dim room seen through the glass: back wall, ceiling shadow, curtains at the sides, a lamp, a picture,
    furniture silhouette below the sill; lit = warm interior light for the GlassLit night mesh."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, 1 - yy / h
    wall = rgb(r.choice([(150, 132, 108), (120, 128, 118), (140, 120, 110), (126, 120, 132)]))
    lamp_u = r.uniform(0.3, 0.7)
    glow = np.exp(-(((u - lamp_u) / 0.35) ** 2 + ((v - 0.6) / 0.45) ** 2))
    if lit:
        alb = wall * 0.7 + rgb((230, 196, 150)) * (0.35 + 0.55 * glow)[..., None]
    else:
        alb = wall * (0.26 + 0.18 * glow)[..., None]
    alb = alb * (1 - 0.45 * smooth(0.75, 1.0, v))[..., None]                # ceiling falls off
    pic = (np.abs(u - r.uniform(0.35, 0.65)) < 0.13) & (np.abs(v - 0.66) < 0.09)
    alb[pic] = alb[pic] * 0.55 + (rgb((180, 160, 120)) if lit else rgb((60, 56, 50))) * 0.3
    furn = v < 0.32 + 0.06 * np.sin(u * r.uniform(5, 11))                  # sideboard / sofa back
    alb[furn] = alb[furn] * 0.45
    shade = ((u - lamp_u) ** 2 / 0.012 + (v - 0.42) ** 2 / 0.004) < 1
    alb[shade] = rgb((236, 208, 160)) if lit else rgb((92, 84, 70))
    ccol = rgb(r.choice([(140, 98, 88), (96, 110, 126), (164, 148, 116), (110, 120, 96)]))
    folds = 0.8 + 0.2 * np.sin(u * 90 + r.uniform(0, 6))
    for side in (0, 1):
        cw = r.uniform(0.14, 0.24)
        m = (u < cw) if side == 0 else (u > 1 - cw)
        tone = (0.95 if lit else 0.42)
        alb[m] = (ccol * tone * folds[m][..., None]) * (0.85 + 0.15 * v[m][..., None])
    nets = (v > 0.0) & (v < 0.45) & (r.uniform() < 0.5)
    alb = np.where(nets[..., None], mix(alb, rgb((200, 198, 190)) * (0.9 if lit else 0.45), 0.35), alb)
    return np.clip(alb, 0, 1)


def far_window(w, h, kind, lit, seed):
    """LOD2 card: painted frame + glazing bars over a dark (or lit) pane."""
    yy, xx = np.mgrid[0:h, 0:w]
    u, v = xx / w, 1 - yy / h
    alb = interior(w, h, seed, lit) * (1.0 if lit else 0.8)
    refl = smooth(0.2, 0.9, (u + v) * 0.6 % 1.0) * 0.12
    alb = alb + (0 if lit else refl[..., None] * rgb((170, 180, 190)))
    fr = 0.07
    bars = (u < fr) | (u > 1 - fr) | (v < fr * 1.3) | (v > 1 - fr)
    if kind == "sash":
        bars |= np.abs(v - 0.5) < 0.03
        bars |= (np.abs(u - 0.5) < 0.015)
    else:
        bars |= np.abs(u - 0.5) < 0.03
        bars |= np.abs(v - 0.55) < 0.015
    alb[bars] = rgb((206, 204, 196))
    return alb, bars


def strip_tex(name, w, h):
    """u-tiling strips (u wraps across the full 1024)."""
    s = (h, w)
    yy, xx = np.mgrid[0:h, 0:w]
    v = 1 - yy / max(h - 1, 1)
    g1, g2 = fbm(s, 1.8, 120, aniso=(0.3, 1.0), seed=hash(name) % 1000), fbm(s, 2.6, 12, seed=hash(name) % 1000 + 1)
    met = np.zeros(s)
    if name == "Tar":
        alb = rgb((46, 46, 44)) * (0.9 + 0.2 * g1)[..., None]
        alb = mix(alb, rgb((110, 112, 100)), 0.35 * smooth(0.6, 0.85, g2) * (1 - v))   # splash / salt
        h_ = 0.2 * g1
        rg = 0.55 + 0.2 * g2
    elif name == "Ridge":                    # half-round ridge tiles, 0.45 m each -> 1024 px = 0.9 m, 2 tiles
        joint = (np.abs(((xx / w) * 2) % 1.0 - 0.5) > 0.47)
        alb = rgb((112, 104, 98)) * (0.9 + 0.15 * g1)[..., None]
        alb = mix(alb, rgb((160, 138, 98)), 0.6 * smooth(0.8, 0.9, fbm(s, 2.2, 60, seed=7)))
        alb = mix(alb, rgb((150, 146, 134)), joint.astype(float))
        h_ = 0.3 * g1 - 0.6 * joint
        rg = 0.7 + 0.15 * g2
    elif name == "Pot":
        alb = rgb((150, 106, 86)) * (0.85 + 0.2 * g1)[..., None]
        soot = smooth(0.6, 1.0, v)
        alb = mix(alb, rgb((48, 42, 38)), 0.7 * soot)
        h_ = 0.2 * g1
        rg = 0.75 + 0.1 * g2 - 0.1 * soot
    elif name == "Lead":
        alb = rgb((112, 118, 122)) * (0.9 + 0.15 * g1)[..., None]
        alb = mix(alb, rgb((176, 180, 176)), 0.3 * smooth(0.55, 0.85, g2))         # white lead oxide bloom
        h_ = 0.3 * g2
        rg = 0.55 + 0.15 * g1
    elif name == "Iron":
        alb = rgb((40, 40, 40)) * (0.9 + 0.2 * g1)[..., None]
        alb = mix(alb, rgb((110, 72, 46)), 0.5 * smooth(0.7, 0.9, g2))             # rust weeping
        h_ = 0.2 * g1
        rg = 0.5 + 0.25 * g2
        met = np.zeros(s)
    elif name == "Step":
        alb = rgb((84, 88, 92)) * (0.85 + 0.25 * g1)[..., None]
        wear = smooth(0.3, 0.7, v) * smooth(0.3, 0.6, g2)
        alb = mix(alb, rgb((108, 110, 112)), 0.4 * wear)
        h_ = 0.3 * g1
        rg = 0.6 - 0.15 * wear
    elif name == "Mortar":
        alb = rgb((156, 150, 138)) * (0.9 + 0.15 * g1)[..., None]
        alb = mix(alb, rgb((110, 116, 90)), 0.3 * smooth(0.6, 0.85, g2))
        h_ = 0.4 * g1
        rg = 0.88
    else:   # Paint: white painted timber, grimy, flaking at the bottom of the strip
        alb = rgb((212, 210, 202)) * (0.94 + 0.08 * g1)[..., None]
        flake = smooth(0.82, 0.9, fbm(s, 1.8, 140, seed=9))
        alb = mix(alb, rgb((130, 118, 100)), 0.5 * flake)
        alb = mix(alb, rgb((150, 148, 138)), 0.35 * smooth(0.5, 0.9, g2))
        h_ = 0.15 * g1 - 0.3 * flake
        rg = 0.42 + 0.25 * flake + 0.1 * g2
    return alb, h_, rg, met


def details_set():
    alb = np.zeros((N, N, 3)) + rgb((90, 90, 90))
    hh, rg, met = np.zeros((N, N)), np.full((N, N), 0.7), np.zeros((N, N))
    wet = np.ones((N, N))

    def put(rect, a, h_, r_, m_=None, wm=1.0):
        x0, y0, x1, y1 = px(rect)
        alb[y0:y1, x0:x1] = a
        hh[y0:y1, x0:x1] = h_
        rg[y0:y1, x0:x1] = r_
        met[y0:y1, x0:x1] = 0 if m_ is None else m_
        wet[y0:y1, x0:x1] = wm

    for i, (k, rect) in enumerate(DOORS.items()):
        x0, y0, x1, y1 = px(rect)
        a, h_, r_, m_ = door_leaf(x1 - x0, y1 - y0, DOOR_RGB[k], 50 + i)
        put(rect, a, h_, r_, m_)
    for rect, lit in ((GLASS, False), (LANTERN, True)):
        x0, y0, x1, y1 = px(rect)
        w, h = x1 - x0, y1 - y0
        g = fbm((h, w), 2.4, 20, seed=61 + lit)
        yy, xx = np.mgrid[0:h, 0:w]
        edge = 1 - smooth(0, 0.18, np.minimum(np.minimum(xx / w, 1 - xx / w), np.minimum(yy / h, 1 - yy / h)))
        if lit:
            a = rgb((236, 204, 150)) * (0.85 + 0.15 * g)[..., None]
        else:   # glass: cool grey-blue sky reflection, salt haze toward the edges and the bottom
            a = rgb((118, 128, 136)) * (0.85 + 0.2 * g)[..., None]
            a = mix(a, rgb((168, 168, 160)), 0.4 * edge + 0.2 * (yy / h))
        put(rect, a, 0.05 * g, 0.06 + 0.25 * edge + 0.05 * g, wm=0.4)
    for i in range(8):
        for lit, rects in ((False, WIN_DIM), (True, WIN_LIT)):
            x0, y0, x1, y1 = px(rects[i])
            w, h = x1 - x0, y1 - y0
            if i < 6:
                a = interior(w, h, 70 + i, lit)
                put(rects[i], a, 0.0, 0.8, wm=0.0)
            else:
                a, bars = far_window(w, h, "sash" if i == 6 else "casement", lit, 80 + i)
                put(rects[i], a, bars * 0.5, np.where(bars, 0.5, 0.1), wm=0.5)
    for name, (v0, v1) in STRIPS.items():
        y0, y1 = int(round((1 - v1) * N)), int(round((1 - v0) * N))
        a, h_, r_, m_ = strip_tex(name, N, y1 - y0)
        alb[y0:y1] = a
        hh[y0:y1] = h_
        rg[y0:y1] = r_
        met[y0:y1] = m_
    save("T_Cottage_Details", alb, nfh(hh, 3.0, wrap=False), rg, met, darken=0.3, gloss=0.4, wet_mask=wet)


# ---------------------------------------------------------------- H3b grime decals (RGBA, AlphaMode Transparency)
def grime_set():
    from atlas import GRIME_BANDS, STREAKS, LACE, BLIND
    alb = np.zeros((N, N, 3)) + rgb((90, 88, 80))
    a, hg, rg = np.zeros((N, N)), np.zeros((N, N)), np.full((N, N), 0.85)

    def band(name):
        v0, v1 = GRIME_BANDS[name]
        y0, y1 = int(round((1 - v1) * N)), int(round((1 - v0) * N))
        h = y1 - y0
        t = 1 - (np.arange(h)[:, None] + 0.5) / h * np.ones((1, N))      # 0 bottom .. 1 top of the band
        return slice(y0, y1), (h, N), t

    sl, sh, t = band("Damp")        # rising damp tide, salt line, algae splash: v 0 = ground, 1 = 1.15 m
    big, mid, fine = fbm(sh, 3.0, 8, seed=201), fbm(sh, 2.2, 40, seed=202), fbm(sh, 1.7, 220, seed=203)
    top = 0.62 + 0.22 * big + 0.08 * (mid - 0.5)
    dmp = 1 - smooth(top - 0.18, top, t)
    tide = np.exp(-((t - top + 0.02) / 0.025) ** 2) * smooth(0.35, 0.65, mid)
    alg = (1 - smooth(0.05, 0.3 + 0.1 * mid, t)) * smooth(0.3, 0.6, big + 0.2 * fine)
    col = mix(np.zeros(sh + (3,)) + rgb((70, 66, 56)), rgb((78, 90, 58)), np.clip(alg * 1.2, 0, 1))
    col = mix(col, rgb((222, 220, 210)), np.clip(tide * 1.4 + 0.5 * smooth(0.7, 0.85, fine) * dmp, 0, 1))
    alb[sl] = col * (0.85 + 0.3 * fine[..., None])
    a[sl] = np.clip(0.55 * dmp * (0.75 + 0.5 * mid) + 0.7 * tide + 0.35 * alg, 0, 0.92) * smooth(0, 0.02, 1 - t)
    rg[sl] = 0.7 + 0.2 * tide
    hg[sl] = 0.3 * tide + 0.2 * alg * fine

    sl, sh, t = band("Moss")        # roof moss cushions on the laps: band covers 6 slate courses (tails at t = k / 6)
    big, mid, fine = fbm(sh, 3.0, 10, seed=211), fbm(sh, 2.2, 50, seed=212), fbm(sh, 1.6, 300, seed=213)
    lap = (t * 6) % 1.0
    near_tail = 1 - smooth(0.0, 0.45, lap)
    dens = (1 - smooth(0.1, 1.0, t) * 0.7) * smooth(0.35, 0.7, big)
    cush = smooth(0.5, 0.62, mid * 0.7 + fine * 0.3 + 0.25 * near_tail * dens)
    mo = cush * dens * (0.6 + 0.4 * near_tail)
    li = smooth(0.8, 0.86, fbm(sh, 2.3, 70, seed=214)) * 0.8
    mcol = mix(np.zeros(sh + (3,)) + rgb((66, 82, 36)), rgb((112, 116, 54)), smooth(0.4, 0.7, fine))
    alb[sl] = mix(mcol, rgb((172, 136, 64)), li * (1 - mo)) * (0.8 + 0.4 * fine[..., None])
    a[sl] = np.clip(np.maximum(smooth(0.25, 0.5, mo) * 0.95, li * 0.85), 0, 0.95)
    rg[sl] = 0.95
    hg[sl] = mo * (0.5 + 0.5 * fine)

    sl, sh, t = band("Soot")        # chimney soot, v 1 = under the cap, streaking down
    st = fbm(sh, 1.9, 60, aniso=(0.1, 1.0), seed=221)
    fine = fbm(sh, 1.7, 200, seed=222)
    so = smooth(0.0, 0.9, t) ** 1.4 * (0.6 + 0.6 * st) + 0.25 * smooth(0.55, 0.8, st) * t
    alb[sl] = (np.zeros(sh + (3,)) + rgb((40, 36, 32))) * (0.8 + 0.4 * fine[..., None])
    a[sl] = np.clip(so, 0, 0.9) * smooth(0, 0.03, 1 - t)
    rg[sl] = 0.9

    for k, rect in enumerate(STREAKS):   # streaks hanging from a sill: v 1 = sill, fading down with drip fingers
        x0, y0, x1, y1 = px(rect)
        w, h = x1 - x0, y1 - y0
        yy, xx = np.mgrid[0:h, 0:w]
        u, t = (xx + 0.5) / w, 1 - (yy + 0.5) / h
        fing = fbm((h, w), 1.8, 40, aniso=(0.06, 1.0), seed=231 + k)
        reach = 0.25 + 0.75 * smooth(0.3, 0.8, fing)
        env = smooth(0.0, 0.18, u) * smooth(0.0, 0.18, 1 - u)
        s_ = env * smooth(1 - reach, 1 - reach + 0.35, t) * (0.55 + 0.45 * smooth(0.4, 0.7, fing))
        cc = rgb((118, 76, 44)) if k < 2 else rgb((66, 74, 58))
        alb[y0:y1, x0:x1] = cc * (0.85 + 0.3 * fbm((h, w), 1.7, 120, seed=241 + k))[..., None]
        a[y0:y1, x0:x1] = np.clip(s_ * (0.85 if k < 2 else 0.7), 0, 0.9)
        rg[y0:y1, x0:x1] = 0.75

    x0, y0, x1, y1 = px(LACE)            # net curtain: lace grid + scalloped hem
    w, h = x1 - x0, y1 - y0
    yy, xx = np.mgrid[0:h, 0:w]
    u, t = xx / w, 1 - yy / h
    lace = 0.5 + 0.25 * np.cos(u * 2 * np.pi * 22) * np.cos(t * 2 * np.pi * 14) + 0.25 * np.cos((u + t) * 2 * np.pi * 30)
    hem = t > 0.06 + 0.04 * np.abs(np.sin(u * np.pi * 9))
    alb[y0:y1, x0:x1] = rgb((222, 220, 210)) * (0.9 + 0.1 * lace[..., None])
    a[y0:y1, x0:x1] = np.where(hem, 0.35 + 0.45 * smooth(0.5, 0.8, lace), 0.0) * smooth(0, 0.01, 1 - t)
    rg[y0:y1, x0:x1] = 0.9

    x0, y0, x1, y1 = px(BLIND)           # roller blind: cream linen, bottom bar, pull ring
    w, h = x1 - x0, y1 - y0
    yy, xx = np.mgrid[0:h, 0:w]
    u, t = xx / w, 1 - yy / h
    fab = fbm((h, w), 1.6, 150, aniso=(1.0, 0.15), seed=251)
    bc = rgb((196, 184, 156)) * (0.9 + 0.12 * fab)[..., None] * (0.85 + 0.15 * t)[..., None]
    bc[t < 0.05] = rgb((120, 100, 72))
    ring = np.abs(np.hypot((u - 0.5) * w, (t - 0.02) * h * 0.5) - 6) < 1.5
    bc[ring] = rgb((150, 128, 80))
    alb[y0:y1, x0:x1] = bc
    a[y0:y1, x0:x1] = np.where((t < 0.02) & ~ring, 0.0, 1.0)
    rg[y0:y1, x0:x1] = 0.85

    alb = np.clip(alb, 26 / 255, 236 / 255)
    stem = OUT + "/T_Cottage_Grime"
    w8 = lambda x: (np.clip(x, 0, 1) * 255 + 0.5).astype(np.uint8)
    rgba = lambda c: Image.fromarray(np.dstack([w8(c), w8(a)]), "RGBA")
    rgba(alb).save(stem + "_ALB.png")
    lum = alb.mean(-1, keepdims=True)
    rgba(np.clip((lum + (alb - lum) * 1.1) * 0.62, 22 / 255, 236 / 255)).save(stem + "_ALB_Wet.png")
    Image.fromarray(w8(nfh(hg, 3.0, wrap=False))).save(stem + "_NOR.png")
    Image.fromarray(w8(np.clip(rg, 0.04, 1))).save(stem + "_RGH.png")
    Image.fromarray(w8(np.clip(rg - 0.45, 0.06, 1))).save(stem + "_RGH_Wet.png")
    Image.fromarray(w8(np.zeros((N, N)))).save(stem + "_MET.png")
    print("[maketex] T_Cottage_Grime alpha cover %.3f" % (a > 0.05).mean())


if __name__ == "__main__":
    want = sys.argv[1:] or ["render", "stone", "slate", "details", "grime"]
    if "render" in want:
        F = render_fields()
        for c in RENDER:
            render_set(c, F)
    if "stone" in want:
        stone_set()
    if "slate" in want:
        slate_set()
    if "details" in want:
        details_set()
    if "grime" in want:
        grime_set()
