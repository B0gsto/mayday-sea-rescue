"""H2 Chandlery exterior texture sets (system python3 + numpy + Pillow, no heavy slot). Procedural, no AI images.

    python3 art/source/buildings/M_Bld_Chandlery_Ext/maketex.py

Writes (1024 px, OpenGL normals, RGH / MET greyscale, _Wet ALB / RGH) to assets/textures/M_Bld_Chandlery_Ext/:
  T_Chandlery_Slate_*    Delabole-style blue-grey slate, tile 2 x 2 m (6 studs): 8 courses x 5 slates, lichen, faint salt
  T_Chandlery_Details_*  atlas: fascia lettering (two rows, one string split in half), shopfront paint / iron / lead strips
                         (u-tiling, trim mode), door panels, hanging sign, chalk board, glass, brass, chimney pots, sill stains
Shared sets used as they are: BldTrim Sheet (B02 trim), Mat QuayStone / Granite (B02 library).
Lessons from the V2 RIB reviews: no near-white salt, every bump / noise band-limited to <= 10 cycles per stud,
albedo 30..240, saturation <= 0.42, own roughness per material, wet darken 0.35 + gloss.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/textures/M_Bld_Chandlery_Ext"
N = 1024
FONT = "/System/Library/Fonts/Supplemental/"

# atlas rects (u0, v0, u1, v1), shared with build.py. Strips are full width and tile in u (trim mode).
DETAILS = {
    "FasciaL": (0.0, 0.90, 1.0, 1.0),
    "FasciaR": (0.0, 0.80, 1.0, 0.90),
    "Paint": (0.0, 0.74, 1.0, 0.80),       # strip: shopfront green paint, worn edges
    "Iron": (0.0, 0.68, 1.0, 0.74),        # strip: black-painted wrought / cast iron
    "Lead": (0.0, 0.62, 1.0, 0.68),        # strip: lead flashing
    "Door": (0.0, 0.36, 0.30, 0.62),       # lower door panels 1.2 x 0.98 m
    "Sign": (0.30, 0.36, 0.70, 0.62),      # hanging sign 0.9 x 0.6 m
    "Chalk": (0.70, 0.22, 1.0, 0.62),      # A-board 0.56 x 0.8 m
    "Glass": (0.0, 0.22, 0.30, 0.36),
    "Brass": (0.30, 0.22, 0.45, 0.36),
    "Pots": (0.45, 0.22, 0.70, 0.36),
    "Stain": (0.0, 0.0, 0.25, 0.22),       # drip streak, dark at the top (under the sill), fading down and to the sides
    "Cloth": (0.25, 0.0, 0.45, 0.22),      # loft curtains: faded madder linen, sun-bleached at the folds' faces
    "Glow": (0.45, 0.0, 0.55, 0.22),       # lamp bulbs / shade undersides (the Glow MeshPart, Neon in Studio at Night)
    "Spare": (0.55, 0.0, 1.0, 0.22),
}

# T_Chandlery_Bands: full-width strips (u tiles every 2 m like the Stone tile), v regions = world-height bands (build.py
# "band" UV mode: v = v0 + (b - b0) / h * (v1 - v0), b = height up the face). Rows are cut from the same ashlar / slate
# fields as the tiles, so the seams to the tiling faces are invisible.
BANDS = {   # name: (v0, v1, b0 m, height m)
    "Plinth": (0.0, 0.1875, 0.0, 0.5),          # granite plinth 0 .. 0.46 m + weathering top: damp, salt, algae
    "Base": (0.1875, 0.5625, 0.0, 1.0),         # ashlar 0 .. 1.0 m: rising-damp tide line ~0.6 m, salt bloom
    "Eaves": (0.5625, 0.78125, 5.4, 0.6),       # ashlar 5.4 .. 6.0 m under the eaves: soot, sheltered algae, lichen
    "SlateEaves": (0.78125, 1.0, None, 0.55),   # lowest 0.55 m of slate up-slope from the eaves edge: moss cushions
}
COURSES = [0.36, 0.30, 0.34, 0.28, 0.38, 0.34]   # ashlar course heights, repeating every 2 m (sum 2.0)


def slate_eaves_b0():
    """Up-slope coordinate b of the slate top surface at the eaves edge (same formula as geo.frame_of on the slope)."""
    import importlib.util
    sp = importlib.util.spec_from_file_location("chand_layout", os.path.join(os.path.dirname(os.path.abspath(__file__)), "layout.py"))
    L = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(L)
    S = (L.RIDGE - L.EAVES) / L.Y1
    y = L.Y0 - 0.28                                  # build.OVH
    z = L.EAVES + (L.Y1 - abs(y)) * S + 0.16         # build.SLAB
    return (y + S * z) / np.sqrt(1 + S * S)


def fbm(shape, beta=2.0, fmax=60.0, aniso=(1.0, 1.0), seed=0):
    """Periodic 1/f^beta noise 0..1, band-limited to fmax cycles across the image (<= 10 cycles per stud)."""
    r = np.random.default_rng(seed)
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    fa = np.sqrt((fx * aniso[1]) ** 2 + (fy * aniso[0]) ** 2)
    f = np.sqrt(fx * fx + fy * fy)
    fa[0, 0] = 1.0
    spec = np.fft.fft2(r.standard_normal(shape)) / fa ** (beta / 2.0)
    spec *= np.exp(-(f / fmax) ** 4)
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


def save(stem, alb, nor, rgh, met, darken=0.35, gloss=0.45):
    os.makedirs(OUT, exist_ok=True)
    alb = np.clip(alb, 32 / 255, 236 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    w8 = lambda a: (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(w8(alb), "RGB").save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray(w8(nor), "RGB").save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray(w8(rgh), "L").save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray(w8(met), "L").save(os.path.join(OUT, stem + "_MET.png"))
    m = met[..., None] > 0.5
    dk = np.where(m, darken * 0.3, darken)
    walb = np.clip(alb * (1 - dk), 30 / 255, 236 / 255)
    wrgh = np.clip(rgh - gloss * (0.6 + 0.4 * rgh), 0.05, 1.0)
    Image.fromarray(w8(walb), "RGB").save(os.path.join(OUT, stem + "_ALB_Wet.png"))
    Image.fromarray(w8(wrgh), "L").save(os.path.join(OUT, stem + "_RGH_Wet.png"))


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


# ---------------------------------------------------------------- slate (8 courses x 5 slates per 2 m tile = 6 studs)
def slate_fields():
    """Slate tile arrays (alb, height, rough): per-slate tone and tint, ~8 % replaced slates (newer blue-grey or
    weathered rusty-grey), faint lichen, salt at the tails, a few small moss tufts in the laps."""
    s = (N, N)
    courses, per = 8, 5
    ch = N // courses
    yy, xx = np.mgrid[0:N, 0:N]
    c = yy // ch
    t = (yy % ch) / ch                              # 0 top of the exposed course (under the tail above) .. 1 tail
    off = np.where(c % 2 == 0, 0, N // (2 * per))
    sx = (xx + off) % N
    k = np.minimum(sx * per // N, per - 1)
    slot = c * per + k
    r = np.random.default_rng(11)
    ns = courses * per
    tone = np.clip(r.normal(1.0, 0.085, ns), 0.8, 1.2)
    tint = r.normal(0, 0.014, (ns, 3))
    tint[:, 2] += r.normal(0, 0.01, ns)              # some slates bluer, some greyer
    tilt = r.normal(0, 0.1, ns)
    kind = r.uniform(0, 1, ns)
    newer = kind < 0.05                              # replaced: crisp, darker blue-grey
    rusty = (kind > 0.95)                            # replaced from salvage: lighter, iron-stained grey
    tone = np.where(newer, 0.82, np.where(rusty, 1.18, tone))
    big, mid = fbm(s, 3.0, 12, seed=1), fbm(s, 2.2, 40, seed=2)
    grain = fbm(s, 1.8, 50, aniso=(0.35, 1.0), seed=3)
    base = np.zeros((ns, 3)) + rgb((76, 82, 90))
    base[newer] = rgb((70, 78, 92))
    base[rusty] = rgb((92, 88, 84))
    alb = base[slot] * tone[slot][..., None] + tint[slot]
    wx = np.where(newer[slot], 0.3, 1.0)[..., None]  # replaced slates carry less weathering
    alb = alb * (0.92 + 0.1 * grain[..., None] + 0.06 * big[..., None] * wx)
    edgex = np.minimum((sx * per) % N, N - (sx * per) % N) / per        # px to the butt joint
    gap = 1 - smooth(0, 4.0, edgex)
    shade = 1 - smooth(0.0, 0.16, t)
    lich = smooth(0.72, 0.86, fbm(s, 2.4, 30, seed=4)) * smooth(0.35, 0.6, big) * (1 - 0.8 * newer[slot])
    alb = alb * (1 - 0.4 * gap[..., None]) * (1 - 0.3 * shade[..., None])
    alb = mix(alb, rgb((128, 128, 108)), 0.55 * lich)
    tailsalt = smooth(0.86, 1.0, t) * smooth(0.55, 0.8, mid)
    alb = mix(alb, rgb((128, 132, 134)), 0.12 * tailsalt)                # faint grey salt, never white
    tufts = smooth(0.8, 0.9, fbm(s, 2.0, 60, seed=5)) * gap.clip(0.3, 1) * smooth(0.6, 0.85, big)
    alb = mix(alb, rgb((74, 84, 52)), 0.8 * tufts)
    tail = smooth(0.0, 0.05, t) * (1 - smooth(0.96, 1.0, t))
    h = 0.5 * t * tail + tilt[slot] * ((sx * per) % N) / N * 0.3 - gap * 0.3 + 0.05 * grain + 0.06 * lich + 0.2 * tufts
    h = np.where(t < 0.03, h - 0.3 * (1 - t / 0.03), h)
    rgh = 0.6 + 0.08 * grain + 0.22 * lich + 0.08 * gap - 0.04 * big + 0.25 * tufts - 0.06 * newer[slot]
    return alb, h, rgh


def slate_set():
    alb, h, rgh = slate_fields()
    nor = normal_from_height(h * 6.0, 3.0)
    save("T_Chandlery_Slate", alb, nor, rgh, np.zeros((N, N)), darken=0.35, gloss=0.5)
    return alb, h, rgh


# ---------------------------------------------------------------- ashlar (Chandlery's own QuayStone): 2 m tile + bands
STONE = (135, 122, 107)       # matches Mat QuayStone's mean so the street still reads as one quay
MORTAR = (156, 150, 136)      # lime mortar, a touch lighter and greyer than the stone
_ASH = {}


def ashlar_tile():
    """Field arrays on the 2 m x 2 m tile (1024 px, row 0 = top = z 2 m): course / stone ids, joint distance (m)."""
    if _ASH:
        return _ASH
    yy, xx = np.mgrid[0:N, 0:N]
    zm = (N - 0.5 - yy) / N * 2.0                     # 0 .. 2 m up
    xm = (xx + 0.5) / N * 2.0
    cb = np.concatenate([[0.0], np.cumsum(COURSES)])
    c = np.clip(np.searchsorted(cb, zm, side="right") - 1, 0, len(COURSES) - 1)
    dz = np.minimum(zm - cb[c], cb[c + 1] - zm)
    r = np.random.default_rng(41)
    sid = np.zeros((N, N), int)
    dx = np.full((N, N), 9.0)
    for ci in range(len(COURSES)):
        lens = []
        while sum(lens) < 2.0:
            lens.append(r.uniform(0.42, 0.95))
        lens = np.array(lens) * 2.0 / sum(lens)
        cuts = (np.concatenate([[0.0], np.cumsum(lens)]) + r.uniform(0, 2.0)) % 2.0
        cuts = np.sort(cuts[:-1])
        m = c == ci
        x = xm[m]
        d = np.abs(x[:, None] - cuts[None, :])
        d = np.minimum(d, 2.0 - d)
        dx[m] = d.min(1)
        k = np.searchsorted(cuts, x, side="right") % len(cuts)
        sid[m] = ci * 16 + k
    s = (N, N)
    _ASH.update(sid=sid, d=np.minimum(dx, dz), dz=dz, c=c,
                big=fbm(s, 3.0, 8, seed=42), mid=fbm(s, 2.2, 30, seed=43), fine=fbm(s, 1.7, 60, seed=44),
                runs=fbm(s, 2.4, 40, aniso=(0.12, 1.6), seed=45), lich=fbm(s, 2.4, 24, seed=46))
    r2 = np.random.default_rng(47)
    tone = np.clip(r2.normal(1.0, 0.075, 16 * len(COURSES)), 0.84, 1.18)
    odd = r2.uniform(0, 1, tone.size)
    tint = r2.normal(0, 0.012, (tone.size, 3))
    tint[odd < 0.08] += rgb((-8, -6, -2))            # a few cooler grey blocks (granite rubble re-used in repairs)
    tint[odd > 0.92] += rgb((8, 4, -4))              # a few warmer, iron-stained blocks
    _ASH.update(tone=tone, tint=tint)
    return _ASH


def ashlar(rows):
    """Ashlar albedo / height / roughness for the given tile rows (int array, any length; each row -> 1024 px wide)."""
    A = ashlar_tile()
    g = lambda k: A[k][rows]
    sid, d = g("sid"), g("d")
    big, mid, fine, lich_n = g("big"), g("mid"), g("fine"), g("lich")
    alb = rgb(STONE) * A["tone"][sid][..., None] + A["tint"][sid]
    alb = alb * (0.9 + 0.12 * mid[..., None] + 0.07 * fine[..., None] + 0.05 * big[..., None])
    joint = 1 - smooth(0.006, 0.014, d + 0.004 * (fine - 0.5))   # 1 in the mortar
    arris = 1 - smooth(0.012, 0.045, d)                           # pitched, slightly rounded arrises
    mort = rgb(MORTAR) * (0.9 + 0.15 * fine[..., None] + 0.05 * big[..., None])
    mort = mix(mort, rgb((96, 92, 84)), 0.35 * smooth(0.4, 0.9, mid))   # dirt in the recess
    alb = alb * (1 - 0.1 * arris[..., None])
    alb = mix(alb, mort, joint)
    lich = smooth(0.78, 0.9, lich_n) * smooth(0.45, 0.7, big)
    alb = mix(alb, rgb((128, 130, 110)), 0.3 * lich)
    h = 0.6 * (1 - arris) ** 0.6 + 0.35 * (1 - joint) - 0.35 * joint + 0.12 * mid + 0.05 * fine + 0.04 * lich
    rgh = 0.8 + 0.05 * fine - 0.04 * mid + 0.06 * joint + 0.06 * lich
    return alb, h, rgh, joint


def stone_set():
    alb, h, rgh, _ = ashlar(np.arange(N))
    save("T_Chandlery_Stone", alb, normal_from_height(h * 3.0, 2.5), rgh, np.zeros((N, N)), darken=0.34, gloss=0.4)


def band_rows(name, n_tile=N, tile_m=2.0):
    """Region pixel rows (top .. bottom) and their world b (m) and tile rows for a BANDS strip."""
    v0, v1, b0, hm = BANDS[name]
    r0, r1 = int(round((1 - v1) * N)), int(round((1 - v0) * N))
    n = r1 - r0
    b = b0 + hm * (n - 0.5 - np.arange(n)) / n               # top row = b0 + h
    trow = ((1 - (b / tile_m) % 1.0) * n_tile).astype(int) % n_tile
    return r0, r1, b, trow


def bands_set(slate):
    alb = np.zeros((N, N, 3))
    hgt = np.zeros((N, N))
    rgh = np.zeros((N, N))
    full = lambda a: a[:, None] * np.ones((1, N))
    xs = np.arange(N)

    # ---- Base: ashlar 0 .. 1 m with a rising-damp tide line (0.5 .. 0.72 m), salt bloom at and just under it
    r0, r1, b, tr = band_rows("Base")
    a, h, rg, joint = ashlar(tr)
    z = full(b)
    w1 = fbm((r1 - r0, N), 2.2, 14, aniso=(4.0, 1.0), seed=51)
    w2 = fbm((r1 - r0, N), 2.0, 50, seed=52)
    tide = 0.52 + 0.2 * w1[0:1, :]                                # irregular tide line along the wall
    damp = 1 - smooth(tide - 0.16, tide + 0.02, z + 0.05 * (w2 - 0.5))
    salt = np.exp(-((z - tide + 0.02) / 0.07) ** 2) * smooth(0.35, 0.75, w2) * (0.6 + 0.4 * joint)
    salt += 0.5 * joint * damp * smooth(0.5, 0.8, w2)            # efflorescence in the damp joints
    salt = np.clip(salt, 0, 1)
    green = (1 - smooth(0.05, 0.35, z)) * smooth(0.4, 0.8, w1)
    a = a * (1 - 0.3 * damp[..., None])
    a = mix(a, rgb((84, 88, 70)), 0.35 * green)
    a = mix(a, rgb((184, 182, 174)), 0.55 * salt)
    alb[r0:r1], hgt[r0:r1] = a, h + 0.1 * salt
    rgh[r0:r1] = rg - 0.12 * damp + 0.1 * salt

    # ---- Eaves: ashlar 5.4 .. 6.0 m: soot / sheltered algae darkening toward the wall plate, drip runs, lichen
    r0, r1, b, tr = band_rows("Eaves")
    a, h, rg, joint = ashlar(tr)
    z = full(b)
    w1 = fbm((r1 - r0, N), 2.2, 16, aniso=(3.0, 1.0), seed=53)
    runs = fbm((r1 - r0, N), 2.4, 40, aniso=(0.12, 1.6), seed=54)
    k = smooth(5.4, 6.0, z + 0.25 * (w1 - 0.5)) * (0.55 + 0.45 * smooth(0.4, 0.8, runs))
    lich = smooth(0.7, 0.85, fbm((r1 - r0, N), 2.4, 30, seed=55)) * smooth(5.45, 5.7, z) * (1 - smooth(5.85, 6.0, z))
    a = mix(a, rgb((58, 60, 54)), 0.6 * k)
    a = mix(a, rgb((142, 136, 100)), 0.45 * lich)
    alb[r0:r1], hgt[r0:r1] = a, h + 0.05 * lich
    rgh[r0:r1] = rg + 0.05 * k + 0.08 * lich

    # ---- Plinth: weathered granite 0 .. 0.5 m, block joints, damp all over, salt at the top, algae at the foot
    r0, r1, b, tr = band_rows("Plinth")
    n = r1 - r0
    z = full(b)
    big = fbm((n, N), 3.0, 10, seed=56)
    speck = fbm((n, N), 1.2, 60, seed=57)
    w2 = fbm((n, N), 2.0, 50, seed=58)
    r = np.random.default_rng(59)
    cuts = np.sort(r.uniform(0, 2.0, 2))
    xm = (xs + 0.5) / N * 2.0
    dj = np.min(np.minimum(np.abs(xm[:, None] - cuts), 2.0 - np.abs(xm[:, None] - cuts)), 1)
    blk = np.searchsorted(cuts, xm) % 2
    tone = np.where(blk == 0, 1.0, 0.93)
    joint = full(np.zeros(n)) + (1 - smooth(0.005, 0.012, dj))[None, :]
    a = rgb((90, 71, 57)) * (tone[None, :, None] * (0.86 + 0.18 * big[..., None] + 0.16 * (speck[..., None] - 0.5)))
    a = mix(a, rgb((150, 140, 128)), 0.35 * smooth(0.7, 0.85, speck))          # quartz / feldspar flecks
    a = mix(a, rgb(MORTAR) * 0.9, joint)
    damp = 1 - smooth(0.25, 0.48, z + 0.06 * (big - 0.5))
    salt = smooth(0.32, 0.46, z) * smooth(0.45, 0.8, w2) * 0.7
    green = (1 - smooth(0.0, 0.18, z)) * smooth(0.35, 0.75, big)
    a = a * (1 - 0.22 * damp[..., None])
    a = mix(a, rgb((80, 86, 66)), 0.4 * green)
    a = mix(a, rgb((176, 174, 166)), 0.5 * salt)
    alb[r0:r1] = a
    hgt[r0:r1] = 0.3 * big + 0.08 * speck - 0.4 * joint + 0.08 * salt
    rgh[r0:r1] = 0.82 + 0.05 * speck - 0.1 * damp + 0.08 * salt

    # ---- SlateEaves: the slate tile's own rows (absolute up-slope phase), moss cushions thickest at the eaves
    v0, v1, _, hm = BANDS["SlateEaves"]
    BANDS["SlateEaves"] = (v0, v1, slate_eaves_b0(), hm)
    r0, r1, b, tr = band_rows("SlateEaves")
    sa, sh, sr = slate
    a, h, rg = sa[tr], sh[tr], sr[tr]
    s_up = full(b - b[-1])                                        # 0 at the eaves edge
    m1 = fbm((r1 - r0, N), 2.2, 40, seed=60)
    m2 = fbm((r1 - r0, N), 1.8, 60, seed=61)
    moss = smooth(0.45, 0.6, m1 + 0.35 * (1 - smooth(0.0, 0.45, s_up))) * (1 - smooth(0.3, 0.52, s_up))
    a = mix(a, rgb((70, 80, 46)) * (0.85 + 0.3 * m2[..., None]), 0.85 * moss)
    a = mix(a, rgb((96, 92, 62)), 0.25 * moss * smooth(0.6, 0.9, m2))          # dry, browner tips
    alb[r0:r1], hgt[r0:r1] = a, h + 0.35 * moss * (0.6 + 0.4 * m2)
    rgh[r0:r1] = np.clip(rg + 0.3 * moss, 0, 0.97)

    nor = np.zeros((N, N, 3))
    for name, st in (("Plinth", 2.0), ("Base", 2.5), ("Eaves", 2.5), ("SlateEaves", 3.0)):
        r0, r1, _, _ = band_rows(name)
        sc = 6.0 if name == "SlateEaves" else 3.0
        nor[r0:r1] = normal_from_height(np.pad(hgt[r0:r1] * sc, ((1, 1), (0, 0)), mode="edge"), st)[1:-1]
    save("T_Chandlery_Bands", alb, nor, rgh, np.zeros((N, N)), darken=0.34, gloss=0.42)


# ---------------------------------------------------------------- details atlas
GREEN = (42, 68, 56)          # Brunswick-style shopfront green, saturation 0.38
CREAM = (198, 180, 132)       # sign-writer's cream / old gold, saturation 0.33


def letters_mask(w, h, text, font, size, cap_frac, tracking_to=None, y_off=0):
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(font, size)
    widths = [d.textlength(ch, font=f) for ch in text]
    total = sum(widths)
    track = 0.0
    if tracking_to and total < tracking_to:
        track = (tracking_to - total) / max(1, len(text) - 1)
    x = (w - (total + track * (len(text) - 1))) / 2
    bb = d.textbbox((0, 0), "H", font=f)
    y = (h - (bb[3] - bb[1])) / 2 - bb[1] + y_off
    for ch, cw in zip(text, widths):
        d.text((x, y), ch, fill=255, font=f)
        x += cw + track
    return np.asarray(img, dtype=np.float64) / 255.0


def details_set():
    alb = np.zeros((N, N, 3)) + rgb(GREEN)
    rgh = np.full((N, N), 0.5)
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    big, mid = fbm((N, N), 3.0, 10, seed=21), fbm((N, N), 2.2, 40, seed=22)
    fine = fbm((N, N), 1.6, 60, seed=23)
    runs = fbm((N, N), 2.4, 40, aniso=(0.12, 1.6), seed=24)       # vertical grime runs
    grainu = fbm((N, N), 1.8, 60, aniso=(1.0, 0.08), seed=25)     # wood grain along u

    def box(name):
        u0, v0, u1, v1 = DETAILS[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N)), int(round(u0 * N)), int(round(u1 * N))

    def sl(name):
        r0, r1, c0, c1 = box(name)
        return np.s_[r0:r1, c0:c1]

    def paint(region, base=GREEN, wear=0.0, edge=None):
        a = rgb(base) * (0.9 + 0.1 * big[region][..., None] + 0.06 * grainu[region][..., None])
        g = smooth(0.6, 0.9, runs[region]) * 0.5
        a = mix(a, rgb((70, 74, 64)), 0.25 * g)
        if edge is not None:
            chip = smooth(0.55, 0.75, edge * 0.7 + mid[region] * 0.5) * wear
            under = mix(np.zeros_like(a) + rgb((132, 126, 108)), np.zeros_like(a) + rgb((112, 92, 70)),
                        smooth(0.6, 0.8, fine[region]))
            a = mix(a, under, chip)
            return a, chip, g
        return a, np.zeros(a.shape[:2]), g

    # ---- fascia: one string on a 2048 px board, split into the two rows
    r0, r1, hh = 0, 104, 104
    full_w = 2 * N
    m = letters_mask(full_w, hh, "PORT HAVEN CHANDLERY", FONT + "Georgia Bold.ttf", 84, 0.7, tracking_to=1720)
    shadow = np.roll(np.roll(m, 4, 0), 4, 1)
    shadow = np.clip(shadow - m, 0, 1)
    yy = np.arange(hh)[:, None] / hh * np.ones((1, full_w))
    border = ((np.abs(yy - 0.07) < 0.018) | (np.abs(yy - 0.93) < 0.018)).astype(float)
    boardnoise = np.concatenate([big[r0:r1], big[r0 + 200:r1 + 200]], 1)
    runs2 = np.concatenate([runs[r0:r1], runs[r0 + 300:r1 + 300]], 1)
    mid2 = np.concatenate([mid[r0:r1], mid[r0 + 300:r1 + 300]], 1)
    board = rgb(GREEN) * (0.9 + 0.12 * boardnoise[..., None])
    board = mix(board, rgb((30, 44, 38)), 0.85 * shadow)
    board = mix(board, rgb(CREAM) * 0.92, 0.85 * border)
    board = mix(board, rgb(CREAM) * (0.95 + 0.05 * boardnoise[..., None]), m)
    fade = smooth(0.0, 0.25, 1 - yy) * 0.12                                   # sun fade along the top
    board = mix(board, rgb((96, 108, 98)), fade)
    grime = smooth(0.62, 0.9, runs2) * smooth(0.3, 1.0, yy) * 0.35
    board = mix(board, rgb((66, 66, 56)), grime)
    chips = smooth(0.78, 0.86, mid2) * (smooth(0.8, 0.98, yy) + smooth(0.2, 0.02, yy))
    board = mix(board, rgb((128, 120, 100)), 0.7 * chips)
    for half, name in ((0, "FasciaL"), (1, "FasciaR")):
        q0, q1, p0, p1 = box(name)
        alb[q0:q1, p0:p1] = board[:q1 - q0, half * N:(half + 1) * N]
        rgh[q0:q1, p0:p1] = (0.42 - 0.06 * m + 0.2 * grime + 0.2 * chips)[:q1 - q0, half * N:(half + 1) * N]
        hgt[q0:q1, p0:p1] = (0.35 * m + 0.25 * border - 0.2 * chips)[:q1 - q0, half * N:(half + 1) * N]

    # ---- strips (u-tiling): paint, iron, lead. v across the strip = across the member: wear at both edges
    for name, base, wear, rg in (("Paint", GREEN, 1.0, 0.44), ("Iron", (40, 40, 40), 0.6, 0.52), ("Lead", (102, 106, 108), 0.0, 0.58)):
        reg = sl(name)
        r0, r1, c0, c1 = box(name)
        vv = (np.arange(r1 - r0)[:, None] + 0.5) / (r1 - r0) * np.ones((1, c1 - c0))
        edge = 1 - np.minimum(vv, 1 - vv) * 2                       # 1 at the strip edges (member arrises)
        a, chip, g = paint(reg, base, wear, edge ** 3)
        if name == "Iron":
            rust = smooth(0.8, 0.9, mid[reg]) * smooth(0.5, 0.9, edge)
            a = mix(a, rgb((104, 80, 62)), 0.8 * rust)
            chip = np.maximum(chip, rust)
        if name == "Lead":
            ox = smooth(0.55, 0.85, mid[reg])
            a = rgb(base) * (0.88 + 0.16 * big[reg][..., None])
            a = mix(a, rgb((140, 144, 142)), 0.25 * ox)
            a = mix(a, rgb((84, 86, 84)), 0.3 * smooth(0.6, 0.9, runs[reg]))
            chip = ox * 0.3
        alb[reg] = a
        rgh[reg] = rg + 0.25 * chip + 0.1 * g + 0.04 * fine[reg]
        hgt[reg] = 0.3 * np.sin(np.clip(vv, 0, 1) * np.pi) ** 0.5 - 0.3 * chip + 0.06 * grainu[reg]

    # ---- door: lower panels of the half-glazed door (1.2 x 0.98 m): stiles, bottom rail, two fielded panels
    r0, r1, c0, c1 = box("Door")
    reg = sl("Door")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fx, fy = (xx + 0.5) / ww, 1 - (yy + 0.5) / hh                       # fy up
    panel = np.zeros((hh, ww))
    field = np.zeros((hh, ww))
    for p, q in ((0.11, 0.47), (0.53, 0.89)):
        a0, a1 = 0.24, 0.88
        dxp = np.minimum(fx - p, q - fx) * 1.2
        dyp = np.minimum(fy - a0, a1 - fy) * 0.98
        dd = np.minimum(dxp, dyp)
        panel = np.maximum(panel, (dd > 0).astype(float))
        field = np.maximum(field, smooth(0.0, 0.05, dd))
    a, chip, g = paint(reg, GREEN, 0.0)
    kick = smooth(0.2, 0.0, fy) * smooth(0.45, 0.75, fine[reg] * 0.6 + mid[reg] * 0.5)
    a = mix(a, rgb((118, 106, 86)), 0.7 * kick)
    groove = np.zeros((hh, ww))
    for p, q in ((0.11, 0.47), (0.53, 0.89)):
        inside = (fx > p) & (fx < q) & (fy > 0.24) & (fy < 0.88)
        ed = np.minimum(np.minimum(fx - p, q - fx) * 1.2, np.minimum(fy - 0.24, 0.88 - fy) * 0.98)
        groove = np.maximum(groove, inside * (ed < 0.006))
    a = a * (1 - 0.35 * groove[..., None])
    a = mix(a, rgb((66, 68, 58)), 0.3 * smooth(0.6, 0.9, runs[reg]) * smooth(0.6, 0.0, fy))
    alb[reg] = a
    rgh[reg] = 0.42 + 0.3 * kick + 0.1 * groove + 0.04 * fine[reg]
    hgt[reg] = 0.5 * field * panel - 0.3 * groove - 0.1 * kick

    # ---- hanging sign (0.9 x 0.6 m): green board, cream double border, PORT HAVEN / anchor / CHANDLERY
    r0, r1, c0, c1 = box("Sign")
    reg = sl("Sign")
    hh, ww = r1 - r0, c1 - c0
    img = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(img)
    d.rectangle((10, 10, ww - 11, hh - 11), outline=255, width=4)
    d.rectangle((20, 20, ww - 21, hh - 21), outline=255, width=2)
    f1 = ImageFont.truetype(FONT + "Georgia Bold.ttf", 44)
    f2 = ImageFont.truetype(FONT + "Georgia Bold.ttf", 50)
    for txt, f, y in (("PORT HAVEN", f1, 34), ("CHANDLERY", f2, hh - 92)):
        w = d.textlength(txt, font=f)
        d.text(((ww - w) / 2, y), txt, fill=255, font=f)
    cx, cy = ww / 2, hh / 2 + 2
    d.ellipse((cx - 9, cy - 34, cx + 9, cy - 16), outline=255, width=4)       # anchor ring
    d.line((cx, cy - 16, cx, cy + 28), fill=255, width=6)                     # shank
    d.line((cx - 26, cy - 8, cx + 26, cy - 8), fill=255, width=5)             # stock
    d.arc((cx - 30, cy - 6, cx + 30, cy + 34), 20, 160, fill=255, width=5)    # arms
    d.polygon([(cx - 31, cy + 12), (cx - 22, cy + 24), (cx - 36, cy + 24)], fill=255)
    d.polygon([(cx + 31, cy + 12), (cx + 22, cy + 24), (cx + 36, cy + 24)], fill=255)
    d.line((70, cy, cx - 44, cy), fill=255, width=2)
    d.line((cx + 44, cy, ww - 70, cy), fill=255, width=2)
    lm = np.asarray(img.filter(ImageFilter.GaussianBlur(0.7)), dtype=np.float64) / 255.0
    sh = np.clip(np.roll(np.roll(lm, 3, 0), 3, 1) - lm, 0, 1)
    a = rgb(GREEN) * (0.9 + 0.12 * big[reg][..., None])
    a = mix(a, rgb((30, 44, 38)), 0.8 * sh)
    a = mix(a, rgb(CREAM) * (0.95 + 0.05 * fine[reg][..., None]), lm)
    fy = 1 - (np.mgrid[0:hh, 0:ww][0] + 0.5) / hh
    grime = smooth(0.6, 0.9, runs[reg]) * smooth(0.6, 0.0, fy) * 0.35
    a = mix(a, rgb((70, 70, 58)), grime)
    chips = smooth(0.8, 0.88, mid[reg]) * 0.6
    a = mix(a, rgb((128, 120, 100)), chips)
    alb[reg] = a
    rgh[reg] = 0.4 - 0.05 * lm + 0.2 * grime + 0.2 * chips
    hgt[reg] = 0.3 * lm - 0.2 * chips

    # ---- chalk board (0.56 x 0.8 m): slate-black board, chalk lettering, erased haze
    r0, r1, c0, c1 = box("Chalk")
    reg = sl("Chalk")
    hh, ww = r1 - r0, c1 - c0
    img = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(img)
    fc = ImageFont.truetype(FONT + "Chalkduster.ttf", 30)
    fs = ImageFont.truetype(FONT + "Chalkduster.ttf", 21)
    lines = [("CHANDLERY", fc, 20), ("- open today -", fs, 66), ("ROPE  CUT TO", fs, 116), ("LENGTH", fs, 146),
             ("SHACKLES", fs, 192), ("FENDERS", fs, 222), ("FOUL WEATHER", fs, 268), ("GEAR", fs, 298),
             ("LIFEJACKETS", fs, 344), ("SERVICED", fs, 374)]
    for txt, f, y in lines:
        w = d.textlength(txt, font=f)
        d.text(((ww - w) / 2, y), txt, fill=255, font=f)
    d.line((40, 104, ww - 40, 104), fill=200, width=2)
    cm = np.asarray(img.filter(ImageFilter.GaussianBlur(0.6)), dtype=np.float64) / 255.0
    haze = smooth(0.45, 0.8, fbm((hh, ww), 2.6, 12, seed=31)) * 0.18
    a = rgb((40, 44, 44)) * (0.94 + 0.1 * big[reg][..., None])
    a = mix(a, rgb((96, 98, 96)), haze)
    a = mix(a, rgb((190, 190, 182)), cm * (0.75 + 0.25 * fine[reg]))
    alb[reg] = a
    rgh[reg] = 0.86 + 0.06 * cm
    hgt[reg] = 0.05 * cm

    # ---- glass: dark, glossy, dirty corners
    r0, r1, c0, c1 = box("Glass")
    reg = sl("Glass")
    yy, xx = np.mgrid[0:r1 - r0, 0:c1 - c0]
    e = np.minimum(np.minimum(yy, r1 - r0 - 1 - yy), np.minimum(xx, c1 - c0 - 1 - xx)) / (r1 - r0)
    dirt = (1 - smooth(0.0, 0.22, e)) * (0.5 + 0.5 * mid[reg])
    alb[reg] = mix(np.zeros((r1 - r0, c1 - c0, 3)) + rgb((44, 52, 58)), np.zeros((r1 - r0, c1 - c0, 3)) + rgb((92, 92, 84)), 0.25 * dirt)
    rgh[reg] = 0.05 + 0.3 * dirt
    hgt[reg] = 0

    # ---- brass (door knob, letter plate, kick plate): metal, tarnish kept above the metal albedo floor
    reg = sl("Brass")
    tarn = smooth(0.5, 0.8, mid[reg])
    alb[reg] = rgb((228, 204, 144)) * (0.98 - 0.04 * tarn[..., None]) + 0.03 * (big[reg][..., None] - 0.5)
    met[reg] = 1.0
    rgh[reg] = 0.3 + 0.2 * tarn
    hgt[reg] = 0.05 * fine[reg]

    # ---- chimney pots: weathered terracotta, sooted towards the top
    r0, r1, c0, c1 = box("Pots")
    reg = sl("Pots")
    fy = 1 - (np.mgrid[0:r1 - r0, 0:c1 - c0][0] + 0.5) / (r1 - r0)
    a = rgb((146, 106, 86)) * (0.88 + 0.16 * big[reg][..., None])
    a = mix(a, rgb((62, 56, 52)), 0.75 * smooth(0.55, 1.0, fy) * (0.6 + 0.4 * runs[reg]))
    lichen = smooth(0.75, 0.9, mid[reg]) * smooth(0.5, 0.0, fy)
    a = mix(a, rgb((120, 118, 96)), 0.4 * lichen)
    alb[reg] = a
    rgh[reg] = 0.86 + 0.06 * fine[reg]
    hgt[reg] = 0.2 * big[reg]

    # ---- sill stain: drip streak on QuayStone; centre dark at the top, fading to the stone's mean tone
    r0, r1, c0, c1 = box("Stain")
    reg = sl("Stain")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fx, fy = (xx + 0.5) / ww, 1 - (yy + 0.5) / hh
    across = 1 - smooth(0.0, 0.5, np.abs(fx - 0.5) * 2) * 0.55
    down = smooth(0.0, 0.85, fy)                                      # strong at the top (fy 1), gone at the tip
    k = np.clip(across * down * (0.75 + 0.35 * runs[reg]), 0, 1)
    stone = rgb((128, 117, 103)) * (0.95 + 0.08 * big[reg][..., None])
    alb[reg] = mix(stone, rgb((70, 74, 64)), 0.75 * k)
    rgh[reg] = 0.82 - 0.1 * k
    hgt[reg] = 0.05 * big[reg]

    # ---- cloth (curtains, 0.3 x 1.5 m per fold face): faded madder linen, weave, sun-bleached toward the glass side
    r0, r1, c0, c1 = box("Cloth")
    reg = sl("Cloth")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    weave = 0.5 + 0.25 * np.sin(xx * 2 * np.pi / 6.0) * np.sin(yy * 2 * np.pi / 6.0)
    fy = 1 - (yy + 0.5) / hh
    bleach = smooth(0.3, 1.0, fy) * 0.25 + 0.15 * smooth(0.5, 0.9, big[reg])
    a = rgb((128, 78, 70)) * (0.88 + 0.12 * weave[..., None] + 0.1 * mid[reg][..., None])
    a = mix(a, rgb((150, 124, 112)), bleach)
    a = a * (1 - 0.18 * smooth(0.15, 0.0, fy)[..., None])         # hem shadow / dust at the sill
    alb[reg] = a
    rgh[reg] = 0.9 + 0.05 * weave
    hgt[reg] = 0.12 * weave + 0.1 * fine[reg]

    # ---- glow (bulbs, shade undersides): warm opal glass / lit enamel, stays light and plain so Neon reads clean
    reg = sl("Glow")
    alb[reg] = rgb((238, 214, 172)) * (0.97 + 0.03 * big[reg][..., None])
    rgh[reg] = 0.3
    hgt[reg] = 0

    # ---- spare: plain worn green paint
    reg = sl("Spare")
    a, _, g = paint(reg, GREEN, 0.0)
    alb[reg] = a
    rgh[reg] = 0.45 + 0.1 * g

    nor = normal_from_height(hgt, 2.0, wrap=False)
    save("T_Chandlery_Details", alb, nor, rgh, met, darken=0.33, gloss=0.42)


if __name__ == "__main__":
    sl_ = slate_set()
    stone_set()
    bands_set(sl_)
    details_set()
    print("ok")
