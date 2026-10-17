"""H1 texture sets (system python3 + numpy + Pillow, no heavy slot). Procedural, tileable, no AI images.

    python3 art/source/buildings/M_Bld_Station/maketex.py

Writes (1024 px, OpenGL normals, RGH / MET greyscale, _Wet ALB / RGH) to assets/textures/M_Bld_Station/:
  T_Station_Render_*   lime render, tile 4 x 4 m: mottle, salt bloom, algae runs, 1 px hairline cracks, patch repairs
  T_Station_Slate_*    Delabole-style slate, tile 2 x 2 m: 8 courses of 0.25 m (tail of course k at v = k/8),
                       5 slates of 0.4 m per course, alternate courses offset half a slate; per-slate colour, tilt,
                       thickness and roughness, thick tails with a shadow line, chipped corners, replaced slates
  T_Station_Granite_*  coursed granite ashlar, tile 2 x 2 m: 5 courses of 0.4 m (bed joints at v = k/5), blocks
                       0.5-1.1 m with staggered perpends, rock-faced, recessed dark mortar, salt, lichen, cement repairs
  T_Station_Details_*  atlas: sign board, roller door, glass, crew door, galvanised steel, lead, housing (DETAILS rects)
The slipway steel lives in art/source/buildings/M_Bld_Slipway (its own maketex.py).
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "assets/textures/M_Bld_Station"
N = 1024
rng = np.random.default_rng(1207)

# atlas rects (u0, v0, u1, v1), shared with build.py
DETAILS = {
    "Sign": (0.0, 0.84, 1.0, 1.0),
    "RollerDoor": (0.0, 0.28, 0.5, 0.84),
    "Glass": (0.5, 0.56, 0.75, 0.84),
    "Steel": (0.5, 0.28, 0.75, 0.56),
    "CrewDoor": (0.75, 0.28, 1.0, 0.84),
    "Lead": (0.0, 0.0, 0.5, 0.28),
    "Housing": (0.5, 0.0, 1.0, 0.28),
}


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
    n = (n - n.min()) / (n.max() - n.min() + 1e-9)
    return n


def pct(x):
    """Rank-normalise to 0..1 (uniform), so thresholds read as area shares."""
    flat = x.ravel()
    out = np.empty_like(flat)
    out[np.argsort(flat)] = np.linspace(0, 1, flat.size)
    return out.reshape(x.shape)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, m):
    if np.ndim(m) == 2 and np.ndim(a) == 3 or np.ndim(m) == 2 and np.ndim(b) == 3:
        m = m[..., None]
    return a * (1 - m) + b * m


def normal_from_height(h, strength, wrap=True):
    """OpenGL tangent normal: +X right, +Y = +V (up in the image)."""
    if wrap:
        dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
        dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    else:
        dy, dx = np.gradient(h)
    nx = -dx * strength
    ny = dy * strength          # rows run down, V runs up
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def save(folder, stem, alb, nor, rgh, met, darken=0.3, gloss=0.4, rlo=0.04):
    os.makedirs(folder, exist_ok=True)
    alb = np.clip(alb, 22 / 255, 238 / 255)
    rgh = np.clip(rgh, rlo, 1.0)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, stem + "_ALB.png"))
    Image.fromarray((np.clip(nor, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, stem + "_NOR.png"))
    Image.fromarray((rgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, stem + "_RGH.png"))
    Image.fromarray((np.clip(met, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, stem + "_MET.png"))
    m = met[..., None] > 0.5
    # wet: water darkens rough dielectrics, barely touches metal; roughness drops
    dk = np.where(m, darken * 0.4, darken)
    walb = np.clip(alb * (1 - dk), 22 / 255, 238 / 255)
    wrgh = np.clip(rgh - gloss * (0.6 + 0.4 * rgh), min(0.03, rlo), 1.0)
    Image.fromarray((walb * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, stem + "_ALB_Wet.png"))
    Image.fromarray((wrgh * 255 + 0.5).astype(np.uint8)).save(os.path.join(folder, stem + "_RGH_Wet.png"))


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def hairlines(shape, count, seed, segs=(5, 14), step=(3.0, 8.0)):
    """1 px hairline cracks: short jagged paths along a main direction, varying intensity, wrapping at the tile edges."""
    r = np.random.default_rng(seed)
    h, w = shape
    img = Image.new("L", (w * 3, h * 3), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.uniform(w, 2 * w), r.uniform(h, 2 * h)
        a0 = r.uniform(0, np.pi * 2)
        for _ in range(int(r.integers(*segs))):
            a = a0 + r.normal(0, 0.75)
            nx, ny = x + np.cos(a) * r.uniform(*step), y + np.sin(a) * r.uniform(*step)
            d.line([(x, y), (nx, ny)], fill=int(r.integers(110, 256)), width=1)
            if r.random() < 0.12:       # short side branch
                b = a + r.choice([-1, 1]) * r.uniform(0.6, 1.2)
                d.line([(nx, ny), (nx + np.cos(b) * r.uniform(3, 9), ny + np.sin(b) * r.uniform(3, 9))], fill=int(r.integers(80, 160)), width=1)
            x, y = nx, ny
            a0 += r.normal(0, 0.15)
    a = np.asarray(img, dtype=np.float64) / 255.0
    out = np.zeros(shape)
    for i in range(3):
        for j in range(3):
            out = np.maximum(out, a[i * h:(i + 1) * h, j * w:(j + 1) * w])
    return out


def pdist(a, b, n):
    """Periodic signed offset a - b on a ring of n."""
    return (a - b + n / 2) % n - n / 2


def patch_masks(shape, specs, seed, edge_amp=7.0):
    """Repair patches: rectangles with noisy edges (periodic). specs: (cx, cy, w, h). Returns (mask, edge ring)."""
    hgt, wid = shape
    yy, xx = np.mgrid[0:hgt, 0:wid].astype(np.float64)
    nz = fbm(shape, 1.9, seed=seed) - 0.5
    mask = np.zeros(shape)
    ring = np.zeros(shape)
    for (cx, cy, w, h) in specs:
        q = np.maximum(np.abs(pdist(xx, cx, wid)) - w / 2, np.abs(pdist(yy, cy, hgt)) - h / 2) + nz * 2 * edge_amp
        mask = np.maximum(mask, 1 - smooth(-1.2, 1.2, q))
        ring = np.maximum(ring, np.exp(-(q / 1.6) ** 2))
    return mask, ring


def spots(shape, n, rad, seed):
    """Lichen-like round spots with noisy rims (periodic), returns list of (mask) per spot merged and a colour index map."""
    r = np.random.default_rng(seed)
    h, w = shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    nz = fbm(shape, 1.6, seed=seed + 1) - 0.5
    m = np.zeros(shape)
    idx = np.zeros(shape, dtype=np.int64)
    for i in range(n):
        cx, cy, rr = r.uniform(0, w), r.uniform(0, h), r.uniform(*rad)
        d = np.sqrt(pdist(xx, cx, w) ** 2 + pdist(yy, cy, h) ** 2) / rr + nz * 0.9
        s = 1 - smooth(0.75, 1.0, d)
        pick = s > m
        idx = np.where(pick, i, idx)
        m = np.maximum(m, s)
    return m, idx


# ---------------------------------------------------------------- render (lime render, off-white grey, weathered)
def render_set():
    s = (N, N)
    big, mid, fine = fbm(s, 3.2, seed=21), fbm(s, 2.4, seed=22), fbm(s, 1.4, seed=23)
    runs = fbm(s, 2.6, aniso=(0.15, 1.6), seed=24)          # long vertical runs (algae / water marks)
    salt = smooth(0.62, 0.8, fbm(s, 2.8, seed=25))
    base = rgb((170, 166, 154))
    alb = base[None, None, :] * (0.9 + 0.16 * big[..., None] + 0.06 * mid[..., None])
    algae = smooth(0.58, 0.85, runs)[..., None]
    alb = alb * (1 - 0.22 * algae) + rgb((104, 110, 92)) * 0.22 * algae
    alb = alb * (1 - 0.14 * salt[..., None]) + rgb((196, 194, 186)) * 0.14 * salt[..., None]
    pits = smooth(0.8, 0.92, fine)
    alb = alb * (1 - 0.06 * pits[..., None])
    h = 0.55 * mid + 0.35 * fine + 0.25 * big - 0.15 * pits
    rgh = 0.87 + 0.06 * fine - 0.05 * salt + 0.04 * algae[..., 0]
    # patch repairs: newer lime / cement render, smoother, a touch different in tone, a fine seam at the edge
    r = np.random.default_rng(31)
    specs = [(r.uniform(0, N), r.uniform(0, N), r.uniform(70, 210), r.uniform(50, 160)) for _ in range(4)]
    pm, ring = patch_masks(s, specs, 32, edge_amp=9.0)
    tones = [rgb((160, 160, 156)), rgb((176, 170, 158)), rgb((154, 156, 152)), rgb((168, 164, 152))]
    pid = np.zeros(s, dtype=np.int64)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
    best = np.full(s, 1e9)
    for i, (cx, cy, _, _) in enumerate(specs):
        d = pdist(xx, cx, N) ** 2 + pdist(yy, cy, N) ** 2
        pid = np.where(d < best, i, pid)
        best = np.minimum(best, d)
    pcol = np.stack(tones)[pid] * (0.97 + 0.05 * mid[..., None])
    pcol = pcol * (1 - 0.1 * algae * 0.5)
    alb = lerp(alb, pcol, pm * 0.92)
    alb = alb * (1 - 0.1 * ring[..., None] * (0.5 + fine[..., None]))
    h = lerp(h, 0.6 + 0.12 * big + 0.06 * fine, pm) - 0.12 * ring
    rgh = lerp(rgh, 0.8 + 0.03 * fine, pm)
    # a few hairline cracks: 1 px, low contrast, slightly recessed
    crk = hairlines(s, 9, 5)
    alb = alb * (1 - 0.13 * crk[..., None])
    h = h - 0.12 * crk
    rgh = rgh + 0.03 * crk
    nor = normal_from_height(h, 9.0)
    save(OUT, "T_Station_Render", alb, nor, rgh, np.zeros(s), darken=0.32, gloss=0.42)


# ---------------------------------------------------------------- slate (8 courses x 5 slates per 2 m tile)
def slate_set():
    s = (N, N)
    courses, per = 8, 5
    ch, sw = N / courses, N / per                    # 128 px course, 204.8 px slate
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
    c = (yy // ch).astype(np.int64)                  # course index from the top of the image (v = 1)
    ty = yy - c * ch + 0.5                           # px from the top of the course band (under the course above)
    dt = ch - ty                                     # px to this course's tail (v = k/8 at the band bottom)
    off = np.where(c % 2 == 0, 0.0, sw / 2)
    sx = (xx + 0.5 + off) % N
    k = np.minimum((sx // sw).astype(np.int64), per - 1)
    lx = sx - k * sw
    ex = np.minimum(lx, sw - lx)                     # px to the nearest butt joint
    slot = c * per + k
    ns = courses * per
    r = np.random.default_rng(11)
    pal = np.array([rgb((70, 78, 92)), rgb((80, 73, 86)), rgb((72, 81, 77)), rgb((76, 78, 84))])
    wts = r.dirichlet((0.6, 0.6, 0.6, 0.8), ns)
    col = wts @ pal
    tone = r.uniform(0.86, 1.14, ns)
    replaced = r.random(ns) < 0.08
    col[replaced] = rgb((54, 58, 66))
    tone[replaced] = r.uniform(0.92, 1.0, replaced.sum())
    tilt = r.normal(0, 1.4, ns)                      # side-to-side lift, px over the slate width
    thick = r.uniform(0.8, 1.35, ns)                 # tail thickness / course rise
    sr = r.uniform(0.56, 0.74, ns)
    sr[replaced] = 0.5
    chipL = np.where(r.random(ns) < 0.18, r.uniform(7, 18, ns), 0.0)
    chipR = np.where(r.random(ns) < 0.18, r.uniform(7, 18, ns), 0.0)
    jog = r.normal(0, 0.8, ns)                       # hand-cut joint jitter

    grain = fbm(s, 1.8, aniso=(0.25, 1.0), seed=41)  # cleavage ripples, stretched along the course
    lam = fbm(s, 2.6, aniso=(0.12, 1.0), seed=42)
    edgen = fbm(s, 1.2, seed=43)
    tailn = fbm(s, 1.5, aniso=(1.0, 0.05), seed=44)  # varies along u: ragged dressed tail
    cut = 0.6 + 2.6 * tailn + 0.25 * (edgen - 0.5) * 4
    # chips at the tail corners (diagonal nibble with a ragged edge)
    chip = np.maximum(chipL[slot] - (lx + dt * 1.1) + (edgen - 0.5) * 6, chipR[slot] - ((sw - lx) + dt * 1.1) + (edgen - 0.5) * 6)
    under = smooth(-0.6, 0.6, np.maximum(cut - dt, chip))   # beyond the tail: the course below, in shadow
    gap = 1 - smooth(1.4, 3.2, ex + jog[slot] + (edgen - 0.5) * 2.0)
    bevel = 1 - smooth(0.0, 3.5, dt - cut)           # rounded, thick tail edge
    shadow = 1 - smooth(0.0, 16.0, ty)               # shadow line cast by the tail of the course above
    weather = smooth(0.2, 1.0, ty / ch)              # exposed lower part weathers paler

    alb = col[slot] * tone[slot][..., None]
    alb = alb * (0.92 + 0.14 * grain[..., None]) * (0.96 + 0.06 * lam[..., None])
    alb = alb * (1 + 0.07 * weather[..., None] * (~replaced[slot])[..., None])
    alb = alb * (1 + 0.16 * bevel[..., None] * (1 - under[..., None]))   # fresh broken edge catches light
    dark = rgb((30, 32, 37))
    alb = lerp(alb, dark, gap * 0.85)
    alb = alb * (1 - 0.5 * shadow[..., None])
    alb = lerp(alb, dark * (0.9 + 0.2 * edgen[..., None]), under * 0.9)
    # lichen and salt, sparing: rosettes (grey-green, white crustose, a few orange Xanthoria), salt at some tails
    lm, li = spots(s, 34, (3.0, 11.0), 45)
    lm = lm * (1 - gap) * (1 - under) * np.where(replaced[slot], 0.2, 1.0)
    lcol = np.array([rgb((122, 130, 106)), rgb((176, 178, 168)), rgb((168, 126, 60)), rgb((134, 138, 112))])
    lpick = np.random.default_rng(46).choice(4, 34, p=(0.4, 0.3, 0.12, 0.18))
    alb = lerp(alb, lcol[lpick][li] * (0.9 + 0.2 * edgen[..., None]), lm * 0.85)
    tsalt = smooth(0.6, 1.0, 1 - dt / 26) * smooth(0.72, 0.9, fbm(s, 2.2, seed=47)) * (1 - under)
    alb = lerp(alb, rgb((150, 153, 152)), tsalt * 0.35)

    # height in px: course rise to a thick tail, per-slate tilt, ragged tail, recessed joints, slate below in shadow
    h = 3.6 * thick[slot] * (ty / ch) + tilt[slot] * (lx - sw / 2) / sw + 0.9 * grain + 0.4 * lam
    h = h - 2.2 * bevel ** 2
    h = lerp(h, -0.8 + 0.3 * edgen, gap)
    h = lerp(h, -1.0 + 0.3 * edgen, under)
    h = h + 0.6 * lm
    nor = normal_from_height(h, 1.6)
    rgh = sr[slot] + 0.06 * grain + 0.04 * lam
    rgh = lerp(rgh, 0.88, gap)
    rgh = lerp(rgh, 0.9, under)
    rgh = lerp(rgh, 0.92, lm)
    rgh = rgh + 0.08 * tsalt
    save(OUT, "T_Station_Slate", alb, nor, rgh, np.zeros(s), darken=0.35, gloss=0.5)


# ---------------------------------------------------------------- granite ashlar (5 courses x 0.4 m per 2 m tile)
def granite_layout(seed, courses=5, width=2.0, gapmin=0.18):
    r = np.random.default_rng(seed)
    while True:
        rows = []
        for kc in range(courses):
            for _ in range(2000):
                n = int(r.choice([2, 3, 3]))
                L = r.uniform(0.5, 1.1, n)
                L = L / L.sum() * width
                if L.min() < 0.5 or L.max() > 1.1:
                    continue
                o = r.uniform(0, width)
                p = (o + np.concatenate([[0.0], np.cumsum(L)[:-1]])) % width
                order = np.argsort(p)
                p, L = p[order], L[order]
                if rows:
                    q = rows[-1][0]
                    if np.abs(pdist(p[:, None], q[None, :], width)).min() < gapmin:
                        continue
                break
            rows.append((p, L))
        q0, q1 = rows[0][0], rows[-1][0]
        if np.abs(pdist(q0[:, None], q1[None, :], width)).min() >= gapmin:
            return rows


def granite_set():
    s = (N, N)
    nc, cm = 5, 0.4
    ppm = N / 2.0                                    # px per metre
    rows = granite_layout(77)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
    u = (xx + 0.5) / ppm                             # metres
    vm = (1 - (yy + 0.5) / N) * 2.0                  # metres, v up
    kc = np.minimum((vm // cm).astype(np.int64), nc - 1)
    dv = np.minimum(vm - kc * cm, (kc + 1) * cm - vm) * ppm
    dtop = ((kc + 1) * cm - vm) * ppm                # px below the bed joint above
    du = np.full(s, 1e9)
    bid = np.zeros(s, dtype=np.int64)
    lc = np.zeros(s)                                 # metres from the block centre along u
    blen = np.ones(s)
    for k, (p, L) in enumerate(rows):
        m = kc == k
        uu = u[m]
        d = np.abs(pdist(uu[:, None], p[None, :], 2.0)).min(1) * ppm
        du[m] = d
        rel = (uu[:, None] - p[None, :]) % 2.0       # distance past each block start
        ok = rel < L[None, :]
        j = np.argmax(ok, 1)
        bid[m] = k * 4 + j
        lc[m] = rel[np.arange(len(j)), j] - L[j] / 2
        blen[m] = L[j]
    d = np.minimum(du, dv)                           # px to the nearest joint centre
    r = np.random.default_rng(78)
    nb = nc * 4
    tone = r.uniform(0.86, 1.12, nb)
    warm = r.random(nb) < 0.3
    hue = np.where(warm[:, None], [1.05, 0.99, 0.93], [1.0, 1.0, 1.0]) * (1 + r.normal(0, 0.015, (nb, 3)))
    tu, tv = r.normal(0, 3.0, nb), r.normal(0, 3.0, nb)   # px of tilt across the face
    bump = r.uniform(0.6, 1.4, nb)
    br = r.uniform(-0.04, 0.04, nb)

    big, mid = fbm(s, 3.0, seed=81), fbm(s, 2.4, seed=82)
    rock = fbm(s, 2.1, seed=83)
    fine = fbm(s, 1.3, seed=84)
    jn = fbm(s, 1.4, seed=85)
    # crystal speckle: white feldspar, black biotite, smoky quartz; pink K-feldspar in the warm blocks
    sp1 = pct(fbm(s, 0.5, seed=86))
    sp2 = pct(fbm(s, 0.5, seed=87))
    sp3 = pct(fbm(s, 0.6, seed=88))

    hw = 3.6                                         # joint half width: 7.2 px = 14 mm
    arr = np.clip(d - hw + (jn - 0.5) * 3.0 - smooth(0.82, 0.95, mid) * 3.0, -10, None)
    jm = 1 - smooth(-0.8, 0.8, arr)                  # 1 in the mortar
    base = rgb((134, 132, 127))[None, None, :] * tone[bid][..., None] * hue[bid]
    alb = base * (0.94 + 0.1 * big[..., None] + 0.05 * mid[..., None])
    felds = smooth(0.84, 0.9, sp1)[..., None]
    alb = lerp(alb, rgb((206, 202, 194)) * tone[bid][..., None], felds * 0.55)
    bio = smooth(0.9, 0.95, sp2)[..., None]
    alb = lerp(alb, rgb((48, 46, 46)), bio * 0.6)
    quartz = (smooth(0.4, 0.5, sp3) * (1 - smooth(0.5, 0.6, sp3)))[..., None]
    alb = alb * (1 - 0.08 * quartz)
    kfs = (smooth(0.8, 0.86, sp3)[..., None] * warm[bid][..., None])
    alb = lerp(alb, rgb((168, 134, 118)), kfs * 0.45)
    # arris shading: pitched faces fall away into the joint
    ao = 1 - smooth(0.0, 9.0, arr)
    alb = alb * (1 - 0.18 * ao[..., None])
    mort = rgb((64, 58, 52)) * (0.88 + 0.22 * fine[..., None] + 0.08 * big[..., None])
    mort = mort * (0.85 + 0.15 * smooth(0, hw, hw - np.clip(d, 0, hw))[..., None])
    alb = lerp(alb, mort, jm)

    # height (px): mortar recessed, pitched arris, rock-faced face with a per-block tilt
    face = 5.0 * smooth(0.0, 5.0, arr) + 4.0 * smooth(2.0, 34.0, arr) * (0.35 + bump[bid] * (rock - 0.35))
    face = face + (tu[bid] * lc / (blen / 2) + tv[bid] * (dtop / (cm * ppm) - 0.5)) * smooth(2.0, 20.0, arr)
    face = face + 0.35 * fine + 0.25 * felds[..., 0] - 0.2 * bio[..., 0]
    h = lerp(face, -1.5 + 0.6 * fine, jm)
    rgh = 0.8 + br[bid] + 0.07 * (rock - 0.5) + 0.04 * fine - 0.04 * felds[..., 0]
    rgh = lerp(rgh, 0.94, jm)

    # cement patch repairs: flat cooler grey, smooth, slightly proud, with a fine seam
    specs = []
    for _ in range(3):
        specs.append((r.uniform(0, N), r.uniform(0, N), r.uniform(70, 170), r.uniform(50, 120)))
    pm, ring = patch_masks(s, specs, 89, edge_amp=6.0)
    pcol = rgb((146, 147, 144)) * (0.96 + 0.05 * mid[..., None] + 0.03 * fine[..., None])
    alb = lerp(alb, pcol, pm * 0.95)
    alb = alb * (1 - 0.18 * ring[..., None])
    h = lerp(h, 6.5 + 0.8 * big + 0.15 * fine, pm) - 0.8 * ring
    rgh = lerp(rgh, 0.72 + 0.03 * fine, pm)

    stone = (1 - jm) * (1 - pm)
    # hairline cracks crossing blocks: 1 px, low contrast
    crk = hairlines(s, 7, 90, segs=(8, 20), step=(4.0, 9.0)) * (1 - jm)
    alb = alb * (1 - 0.2 * crk[..., None])
    h = h - 0.9 * crk
    # efflorescence: salt leaching out of the joints, running down the face below the bed joint, blooms
    runs = fbm(s, 2.4, aniso=(0.1, 1.8), seed=91)
    leach = np.exp(-dtop / 30.0) * smooth(0.45, 0.8, runs) * (1 - jm)
    bloom = smooth(0.66, 0.86, fbm(s, 2.6, seed=92)) * (0.45 + 0.55 * np.exp(-np.clip(arr, 0, None) / 25.0))
    eff = np.clip(leach * 0.7 + bloom * 0.6, 0, 1) * (0.7 + 0.3 * fine)
    alb = lerp(alb, rgb((212, 210, 202)), eff * 0.55)
    rgh = rgh + 0.06 * eff
    # white tide salt: crisp crusty patches
    tide = smooth(0.8, 0.83, pct(fbm(s, 2.2, aniso=(0.5, 1.6), seed=93)) * 0.75 + fine * 0.3)
    alb = lerp(alb, rgb((228, 226, 220)) * (0.95 + 0.05 * fine[..., None]), tide * 0.75)
    h = h + 0.5 * tide
    rgh = lerp(rgh, 0.95, tide)
    # lichen spots, sparing
    lm, li = spots(s, 22, (3.0, 12.0), 94)
    lm = lm * (1 - jm * 0.7)
    lcol = np.array([rgb((126, 134, 108)), rgb((188, 188, 178)), rgb((172, 132, 62)), rgb((112, 120, 98))])
    lpick = np.random.default_rng(95).choice(4, 22, p=(0.4, 0.3, 0.1, 0.2))
    alb = lerp(alb, lcol[lpick][li] * (0.9 + 0.2 * fine[..., None]), lm * 0.85)
    h = h + 0.5 * lm
    rgh = lerp(rgh, 0.95, lm)
    _ = stone
    nor = normal_from_height(h, 0.9)
    save(OUT, "T_Station_Granite", alb, nor, rgh, np.zeros(s), darken=0.34, gloss=0.45)


# ---------------------------------------------------------------- details atlas helpers
def streaks(shape, seeds, seed):
    """Run-down streaks: seeds (x0, y0, length, width, strength); widen and fade downwards (rows run down)."""
    r = np.random.default_rng(seed)
    hh, ww = shape
    out = np.zeros(shape)
    for (x0, y0, L, w, st) in seeds:
        y0 = int(max(0, y0))
        y1 = int(min(hh, y0 + L))
        if y1 <= y0:
            continue
        ys = np.arange(y0, y1)
        f = (ys - y0) / L
        cx = x0 + np.cumsum(r.normal(0, 0.3, len(ys)))
        wid = w * (0.6 + 0.9 * f)
        a, b = max(0, int(x0 - 6 * w - 30)), min(ww, int(x0 + 6 * w + 30))
        if b <= a:
            continue
        X = np.arange(a, b)[None, :]
        g = np.exp(-((X - cx[:, None]) / wid[:, None]) ** 2) * (st * (1 - f) ** 1.2)[:, None]
        out[y0:y1, a:b] = np.maximum(out[y0:y1, a:b], g)
    return out


def dents(shape, n, seed, rad=(6, 22)):
    r = np.random.default_rng(seed)
    hh, ww = shape
    yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float64)
    h = np.zeros(shape)
    for _ in range(n):
        cx, cy, rr = r.uniform(0, ww), r.uniform(hh * 0.25, hh), r.uniform(*rad)
        ax = r.uniform(1.0, 1.8)
        h -= r.uniform(0.6, 1.6) * np.exp(-2.0 * (((xx - cx) / (rr * ax)) ** 2 + ((yy - cy) / rr) ** 2))
    return h


def scratches(shape, n, seed, ang=(0.0, 0.3), length=(10, 60), region=(0.0, 1.0)):
    r = np.random.default_rng(seed)
    hh, ww = shape
    img = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y = r.uniform(0, ww), r.uniform(region[0] * hh, region[1] * hh)
        a = r.normal(*ang)
        L = r.uniform(*length)
        pts = [(x, y)]
        for _ in range(4):
            a += r.normal(0, 0.05)
            x, y = x + np.cos(a) * L / 4, y + np.sin(a) * L / 4
            pts.append((x, y))
        d.line(pts, fill=int(r.integers(90, 256)), width=1)
    return np.asarray(img, dtype=np.float64) / 255.0


def edge_dist(hh, ww):
    yy, xx = np.mgrid[0:hh, 0:ww].astype(np.float64)
    return np.minimum(np.minimum(yy, hh - 1 - yy), np.minimum(xx, ww - 1 - xx))


# ---------------------------------------------------------------- details atlas
def details_set():
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    big, mid, fine = fbm((N, N), 3.0, seed=61), fbm((N, N), 2.2, seed=62), fbm((N, N), 1.2, seed=63)
    runs = fbm((N, N), 2.4, aniso=(0.12, 1.8), seed=64)
    rustc = rgb((120, 84, 62))

    def box(name):
        u0, v0, u1, v1 = DETAILS[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N)), int(round(u0 * N)), int(round(u1 * N))

    # ---- painted steel roller door: 46 slats, dents, rust from the slat joints and the bottom lip, salt crust, scuffs
    r0, r1, c0, c1 = box("RollerDoor")
    hh, ww = r1 - r0, c1 - c0
    R = lambda a: a[r0:r1, c0:c1]
    yy = np.arange(hh)[:, None] / hh * np.ones((1, ww))
    slat = (yy * 46) % 1.0
    prof = np.sin(slat * np.pi) ** 0.6
    lip = smooth(0.965, 0.975, yy)                   # heavier bottom rail
    paint = rgb((66, 82, 96))
    reg = paint[None, None, :] * (0.92 + 0.1 * R(big)[..., None]) * (0.86 + 0.14 * prof[..., None])
    reg = lerp(reg, rgb((58, 70, 82)), lip)
    grime = smooth(0.5, 1.0, yy) * (0.5 + 0.5 * R(runs))
    reg = lerp(reg, rgb((92, 90, 80)), grime * 0.25)
    rr = np.random.default_rng(65)
    joints_y = (np.arange(1, 46) / 46) * hh
    seeds = []
    for _ in range(34):
        jy = rr.choice(joints_y)
        seeds.append((rr.uniform(0, ww), jy, rr.uniform(15, 70) * (1 + jy / hh), rr.uniform(1.2, 3.5), rr.uniform(0.35, 0.85)))
    for _ in range(22):                              # from the bottom lip rail (rusting along its top edge)
        seeds.append((rr.uniform(0, ww), 0.968 * hh, rr.uniform(8, 18), rr.uniform(1.5, 4.0), rr.uniform(0.5, 1.0)))
    rs = streaks((hh, ww), seeds, 66) * (0.6 + 0.6 * R(runs))
    jointrust = (slat > 0.9) * smooth(0.7, 0.85, R(mid)) + lip * smooth(0.45, 0.7, R(mid) * 0.6 + R(fine) * 0.6)
    rust = np.clip(rs + jointrust, 0, 1)
    reg = lerp(reg, rustc * (0.85 + 0.3 * R(fine)[..., None]), rust * 0.7)
    dh = dents((hh, ww), 14, 67)
    dent = smooth(0.15, 0.8, -dh)
    reg = reg * (1 - 0.08 * dent[..., None])
    sc = scratches((hh, ww), 90, 68, ang=(0.0, 0.25), length=(12, 70), region=(0.45, 0.97))
    sc = np.maximum(sc, scratches((hh, ww), 25, 69, ang=(1.57, 0.4), length=(6, 20), region=(0.6, 0.97)) * 0.7)
    reg = lerp(reg, rgb((128, 128, 122)), sc * 0.5)     # exposed grey primer
    salt = smooth(0.9, 0.99, yy + (R(fine) - 0.5) * 0.06) * smooth(0.35, 0.65, R(fine) * 0.7 + R(mid) * 0.4)
    reg = lerp(reg, rgb((196, 196, 188)), salt * 0.7)
    alb[r0:r1, c0:c1] = reg
    hgt[r0:r1, c0:c1] = prof * 1.0 + lip * 0.6 + dh * 0.9 - sc * 0.15 + salt * 0.3 + rust * 0.15
    rgh[r0:r1, c0:c1] = 0.46 + 0.22 * grime + 0.32 * rust + 0.15 * sc + 0.35 * salt

    # ---- glass: dark and reflective, only light dirt at the edges, faint drying marks
    r0, r1, c0, c1 = box("Glass")
    hh, ww = r1 - r0, c1 - c0
    e = edge_dist(hh, ww) / min(hh, ww)
    dirt = (1 - smooth(0.0, 0.07, e)) * (0.5 + 0.5 * R(fine))
    yyg = np.arange(hh)[:, None] / hh * np.ones((1, ww))
    marks = smooth(0.82, 0.95, R(runs)) * 0.4 * smooth(0.3, 1.0, yyg)
    alb[r0:r1, c0:c1] = rgb((30, 36, 41)) * (0.97 + 0.06 * R(big)[..., None])
    alb[r0:r1, c0:c1] = lerp(alb[r0:r1, c0:c1], rgb((86, 86, 80)), dirt * 0.25 + marks * 0.08)
    rgh[r0:r1, c0:c1] = 0.035 + 0.02 * R(big) + 0.1 * dirt + 0.03 * marks
    hgt[r0:r1, c0:c1] = 0.0

    # ---- crew door: painted timber, 4 panels, edge wear, scratches, run-down grime, kick and hand wear
    r0, r1, c0, c1 = box("CrewDoor")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fy, fx = yy / hh, xx / ww
    panel = np.zeros((hh, ww))
    for (a, b) in ((0.08, 0.45), (0.52, 0.9)):
        for (p, q) in ((0.14, 0.46), (0.54, 0.86)):
            inside = smooth(a, a + 0.015, fy) * (1 - smooth(b - 0.015, b, fy)) * smooth(p, p + 0.03, fx) * (1 - smooth(q - 0.03, q, fx))
            panel = np.maximum(panel, inside)
    pe = panel * (1 - panel) * 4                     # moulding edges
    grain = fbm((hh, ww), 1.8, aniso=(0.1, 1.5), seed=3)
    dpaint = rgb((52, 68, 84)) * (0.9 + 0.15 * grain[..., None])
    ed = edge_dist(hh, ww)
    edgew = (1 - smooth(0, 7, ed)) * 0.9 + pe * 0.6
    worn = smooth(0.6, 0.85, edgew * 0.7 + R(fine) * 0.5)
    kick = smooth(0.88, 0.97, fy) * smooth(0.45, 0.7, R(fine) * 0.7 + R(mid) * 0.5)
    hand = np.exp(-(((fx - 0.88) / 0.07) ** 2 + ((fy - 0.5) / 0.05) ** 2)) * smooth(0.3, 0.6, R(fine))
    wear = np.clip(worn + kick + hand * 0.8, 0, 1)
    dpaint = lerp(dpaint, rgb((128, 112, 90)) * (0.9 + 0.2 * grain[..., None]), wear * 0.75)   # bare weathered timber
    sc = scratches((hh, ww), 70, 70, ang=(0.0, 0.5), length=(8, 40), region=(0.3, 1.0))
    dpaint = lerp(dpaint, rgb((118, 122, 122)), sc * 0.45)
    srun = streaks((hh, ww), [(x0, y0, rr.uniform(30, 120), rr.uniform(1.5, 4), rr.uniform(0.3, 0.7))
                              for x0, y0 in zip(rr.uniform(0, ww, 24), rr.choice([0.08, 0.45, 0.52, 0.9, 0.02], 24) * hh)], 71)
    srun = srun * (0.5 + 0.7 * R(runs))
    dpaint = lerp(dpaint, rgb((72, 70, 62)), srun * 0.35)
    alb[r0:r1, c0:c1] = dpaint * (1 - 0.1 * pe[..., None])
    hgt[r0:r1, c0:c1] = -panel * 0.6 + grain * 0.1 - wear * 0.15 - sc * 0.1
    rgh[r0:r1, c0:c1] = 0.42 + 0.33 * wear + 0.05 * grain + 0.15 * sc + 0.15 * srun

    # ---- galvanised steel (metal): spangle and mild streaking
    r0, r1, c0, c1 = box("Steel")
    hh, ww = r1 - r0, c1 - c0
    spang = np.floor(fbm((hh, ww), 1.2, seed=72) * 7) / 7
    reg = rgb((196, 196, 190)) * (0.96 + 0.05 * R(mid)[..., None] + 0.03 * spang[..., None])
    reg = reg * (1 - 0.04 * smooth(0.6, 0.9, R(runs))[..., None])
    alb[r0:r1, c0:c1] = np.clip(reg, 184 / 255, 1)
    met[r0:r1, c0:c1] = 1
    rgh[r0:r1, c0:c1] = 0.42 + 0.1 * R(fine) + 0.06 * spang + 0.06 * smooth(0.6, 0.9, R(runs))
    hgt[r0:r1, c0:c1] = 0.1 * R(fine)

    # ---- lead flashing: dressed creases, white carbonate run-off streaks, scratches, worn edges
    r0, r1, c0, c1 = box("Lead")
    hh, ww = r1 - r0, c1 - c0
    reg = rgb((100, 105, 108)) * (0.9 + 0.18 * R(big)[..., None])
    ox = smooth(0.6, 0.85, R(mid))[..., None]
    reg = lerp(reg, rgb((150, 152, 150)), ox * 0.3)
    crease = fbm((hh, ww), 2.8, aniso=(0.3, 1.0), seed=73)
    seeds = [(x0, y0, rr.uniform(40, 200), rr.uniform(2, 6), rr.uniform(0.3, 0.8)) for x0, y0 in zip(rr.uniform(0, ww, 26), rr.uniform(0, hh * 0.6, 26))]
    carb = streaks((hh, ww), seeds, 74) * (0.5 + 0.7 * R(runs))
    reg = lerp(reg, rgb((176, 178, 174)), carb * 0.5)
    sc = scratches((hh, ww), 60, 75, ang=(0.3, 0.8), length=(10, 50))
    reg = lerp(reg, rgb((136, 140, 144)), sc * 0.45)
    ed = edge_dist(hh, ww)
    ew = (1 - smooth(0, 10, ed + (R(fine) - 0.5) * 10)) * 0.8
    reg = lerp(reg, rgb((80, 84, 88)), ew * 0.4)       # handled, darker worn edges
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.55 + 0.15 * ox[..., 0] + 0.1 * carb - 0.12 * sc - 0.05 * ew
    hgt[r0:r1, c0:c1] = 0.4 * R(big) + 1.2 * crease - 0.1 * sc

    # ---- door housing: painted steel boxes, rust streaks from seams and fixings, edge wear, scratches
    r0, r1, c0, c1 = box("Housing")
    hh, ww = r1 - r0, c1 - c0
    reg = rgb((58, 72, 84)) * (0.9 + 0.12 * R(big)[..., None])
    st = smooth(0.6, 0.9, R(runs))[..., None]
    reg = lerp(reg, rgb((110, 100, 84)), st * 0.3)
    seeds = []
    for _ in range(40):
        seeds.append((rr.uniform(0, ww), rr.choice([0.0, 0.06, 0.5, 0.52]) * hh + rr.uniform(0, 4), rr.uniform(20, 140), rr.uniform(1.2, 4.0), rr.uniform(0.3, 0.9)))
    rs = streaks((hh, ww), seeds, 76) * (0.6 + 0.6 * R(runs))
    spotr = smooth(0.86, 0.94, R(mid) * 0.7 + R(fine) * 0.4)
    rust = np.clip(rs + spotr, 0, 1)
    reg = lerp(reg, rustc * (0.85 + 0.3 * R(fine)[..., None]), rust * 0.7)
    ed = edge_dist(hh, ww)
    ew = smooth(0.55, 0.8, (1 - smooth(0, 8, ed)) * 0.8 + R(fine) * 0.4)
    reg = lerp(reg, rgb((140, 140, 134)), ew * 0.5)
    sc = scratches((hh, ww), 60, 77, ang=(0.0, 0.6), length=(8, 45))
    reg = lerp(reg, rgb((126, 128, 124)), sc * 0.45)
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.5 + 0.18 * st[..., 0] + 0.3 * rust + 0.12 * sc + 0.1 * ew
    hgt[r0:r1, c0:c1] = 0.2 * rust - 0.1 * sc + 0.1 * R(fine)

    # ---- sign board: navy, bold cream lettering filling the board, painted border, mild weathering
    r0, r1, c0, c1 = box("Sign")
    hh, ww = r1 - r0, c1 - c0
    S = 3
    board = Image.new("L", (ww * S, hh * S), 0)
    d = ImageDraw.Draw(board)
    bi, bw = 9, 6                                    # border inset and width (px at 1x)
    d.rectangle((bi * S, bi * S, (ww - bi) * S - 1, (hh - bi) * S - 1), outline=255, width=bw * S)
    font = "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"
    inner_top, inner_bot = bi + bw, hh - bi - bw
    avail = inner_bot - inner_top

    def fit(txt, cap, maxw):
        size = 40
        while True:
            f = ImageFont.truetype(font, size * S)
            hb = d.textbbox((0, 0), "H", font=f, anchor="ls")
            capp = -hb[1] / S
            w = d.textlength(txt, font=f) / S
            if capp >= cap or w >= maxw:
                return f, capp, w
            size += 1

    l1, l2 = "PORT HAVEN LIFEBOAT STATION", "GALE ISLES COASTGUARD"
    f1, cap1, w1 = fit(l1, avail * 0.56, ww - 2 * (bi + bw) - 36)
    f2, cap2, w2 = fit(l2, avail * 0.32, w1 * 0.78)
    gapv = (avail - cap1 - cap2) / 3.0
    b1 = inner_top + gapv + cap1
    b2 = b1 + gapv + cap2
    d.text((ww * S / 2, b1 * S), l1, fill=255, font=f1, anchor="ms")
    d.text((ww * S / 2, b2 * S), l2, fill=255, font=f2, anchor="ms")
    letters = np.asarray(board.resize((ww, hh), Image.LANCZOS), dtype=np.float64) / 255.0
    letters = np.clip(letters, 0, 1)
    navy = rgb((38, 48, 65)) * (0.94 + 0.1 * R(big)[..., None])
    cream = rgb((236, 232, 216)) * (0.95 + 0.05 * R(fine)[..., None])
    reg = navy * (1 - letters[..., None]) + cream * letters[..., None]
    st = smooth(0.66, 0.92, R(runs))[..., None] * 0.5
    reg = lerp(reg, rgb((96, 94, 84)), st * 0.18)
    chips = smooth(0.9, 0.96, R(fine) * 0.6 + R(mid) * 0.5) * letters
    reg = lerp(reg, rgb((120, 118, 108)), chips * 0.35)
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.42 - 0.06 * letters + 0.12 * st[..., 0] + 0.2 * chips
    hgt[r0:r1, c0:c1] = letters * 0.25
    print("sign: line1 cap %.0f px w %.0f, line2 cap %.0f px w %.0f of %d x %d" % (cap1, w1, cap2, w2, ww, hh))

    nor = normal_from_height(hgt, 2.5, wrap=False)
    save(OUT, "T_Station_Details", alb, nor, rgh, met, darken=0.28, gloss=0.35, rlo=0.03)


if __name__ == "__main__":
    render_set()
    slate_set()
    granite_set()
    details_set()
    print("ok")
