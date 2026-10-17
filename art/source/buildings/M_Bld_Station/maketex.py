"""H1 texture sets (system python3 + numpy + Pillow, no heavy slot). Procedural, tileable, no AI images.

    python3 art/source/buildings/M_Bld_Station/maketex.py

Writes (1024 px, OpenGL normals, RGH / MET greyscale, _Wet ALB / RGH):
  assets/textures/M_Bld_Station/T_Station_Render_*   lime render, tile 4 x 4 m (12 studs): mottle, salt bloom, algae runs, hairline cracks
  assets/textures/M_Bld_Station/T_Station_Slate_*    Delabole-style slate courses, tile 2 x 2 m (6 studs): 8 courses x 5 slates, lichen
  assets/textures/M_Bld_Station/T_Station_Details_*  atlas: sign board, roller door, glass, crew door, galvanised steel, lead, housing
  assets/textures/M_Bld_Slipway/T_Slipway_Steel_*    galvanised / rusted steel for the rails, winch, roof sheet, tile 4 studs
Shared sets used as they are (no new texture budget): BldTrim Sheet (B02 trim), Mat QuayStone / Concrete / WeedyConcrete (B02).
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
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
    ny = dy * strength          # rows run down, V runs up
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def save(folder, stem, alb, nor, rgh, met, darken=0.3, gloss=0.4):
    os.makedirs(folder, exist_ok=True)
    alb = np.clip(alb, 22 / 255, 238 / 255)
    rgh = np.clip(rgh, 0.04, 1.0)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(folder, stem + "_ALB.png"))
    Image.fromarray((np.clip(nor, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(folder, stem + "_NOR.png"))
    Image.fromarray((rgh * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(folder, stem + "_RGH.png"))
    Image.fromarray((np.clip(met, 0, 1) * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(folder, stem + "_MET.png"))
    m = met[..., None] > 0.5
    # wet: water darkens rough dielectrics (and pools in cavities), barely touches metal; roughness drops
    dk = np.where(m, darken * 0.4, darken)
    walb = np.clip(alb * (1 - dk), 22 / 255, 238 / 255)
    wrgh = np.clip(rgh - gloss * (0.6 + 0.4 * rgh), 0.05, 1.0)
    Image.fromarray((walb * 255 + 0.5).astype(np.uint8), "RGB").save(os.path.join(folder, stem + "_ALB_Wet.png"))
    Image.fromarray((wrgh * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(folder, stem + "_RGH_Wet.png"))


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def cracks(shape, count, seed):
    r = np.random.default_rng(seed)
    img = Image.new("L", (shape[1] * 3, shape[0] * 3), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = r.uniform(shape[1], 2 * shape[1]), r.uniform(shape[0], 2 * shape[0])
        a = r.uniform(0, np.pi * 2)
        pts = [(x, y)]
        for _ in range(int(r.integers(8, 30))):
            a += r.normal(0, 0.5)
            x += np.cos(a) * r.uniform(6, 18)
            y += np.sin(a) * r.uniform(6, 18)
            pts.append((x, y))
        d.line(pts, fill=255, width=int(r.integers(1, 3)))
    a = np.asarray(img, dtype=np.float64) / 255.0
    h, w = shape
    out = np.zeros(shape)
    for i in range(3):          # fold the 3x canvas back so cracks wrap at the tile edges
        for j in range(3):
            out = np.maximum(out, a[i * h:(i + 1) * h, j * w:(j + 1) * w])
    return out


# ---------------------------------------------------------------- render (lime render, off-white grey, weathered)
def render_set():
    s = (N, N)
    big, mid, fine = fbm(s, 3.2), fbm(s, 2.4), fbm(s, 1.4)
    runs = fbm(s, 2.6, aniso=(0.15, 1.6))          # long vertical runs (algae / water marks)
    salt = smooth(0.62, 0.8, fbm(s, 2.8))
    crk = cracks(s, 26, 5)
    base = rgb((170, 166, 154))
    alb = base[None, None, :] * (0.9 + 0.16 * big[..., None] + 0.06 * mid[..., None])
    algae = smooth(0.58, 0.85, runs)[..., None]
    alb = alb * (1 - 0.22 * algae) + rgb((104, 110, 92)) * 0.22 * algae
    alb = alb * (1 - 0.12 * salt[..., None]) + rgb((188, 186, 178)) * 0.12 * salt[..., None]
    alb = alb * (1 - 0.35 * crk[..., None])
    pits = smooth(0.78, 0.9, fine)
    alb = alb * (1 - 0.08 * pits[..., None])
    h = 0.55 * mid + 0.35 * fine + 0.25 * big - 0.6 * crk - 0.2 * pits
    nor = normal_from_height(h, 9.0)
    rgh = 0.86 + 0.06 * fine - 0.05 * salt + 0.04 * algae[..., 0]
    save(G + "assets/textures/M_Bld_Station", "T_Station_Render", alb, nor, rgh, np.zeros(s), darken=0.32, gloss=0.42)


# ---------------------------------------------------------------- slate (8 courses x 5 slates per 2 m tile)
def slate_set():
    s = (N, N)
    courses, per = 8, 5
    ch, sw = N // courses, N // per
    yy, xx = np.mgrid[0:N, 0:N]
    c = yy // ch
    t = (yy % ch) / ch                              # 0 at the top of a course (under the course above) .. 1 at its tail
    off = np.where(c % 2 == 0, 0, sw // 2)
    sx = (xx + off) % N
    k = np.minimum(sx * per // N, per - 1)
    sw = N / per
    slot = c * per + k
    r = np.random.default_rng(11)
    tone = r.uniform(0.82, 1.12, courses * per)
    tint = r.normal(0, 0.03, (courses * per, 3))
    tilt = r.normal(0, 0.12, courses * per)
    alb = rgb((74, 80, 88))[None, None, :] * tone[slot][..., None] + tint[slot] * 0.25
    grain = fbm(s, 1.6, aniso=(0.3, 1.0))
    alb = alb * (0.93 + 0.12 * grain[..., None])
    edgex = np.minimum((sx * per) % N, N - (sx * per) % N) / per
    gap = 1 - smooth(0, 3.5, edgex)                  # butt joints
    shade = 1 - smooth(0.0, 0.18, t)                 # shadow under the course above
    lich = smooth(0.7, 0.86, fbm(s, 2.2)) * smooth(0.2, 0.5, fbm(s, 3.0))
    alb = alb * (1 - 0.45 * gap[..., None]) * (1 - 0.35 * shade[..., None])
    alb = alb * (1 - 0.6 * lich[..., None]) + rgb((142, 142, 118)) * 0.6 * lich[..., None]
    # salt bloom along the tails
    tailsalt = smooth(0.85, 1.0, t) * smooth(0.5, 0.8, fbm(s, 2.0))
    alb = alb * (1 - 0.2 * tailsalt[..., None]) + rgb((150, 152, 150)) * 0.2 * tailsalt[..., None]
    h = t * 0.9 + tilt[slot] * ((sx * per) % N) / N - gap * 0.4 + 0.05 * grain + 0.08 * lich
    h = np.where(t < 0.02, h - 0.6, h)
    nor = normal_from_height(h * 6.0, 4.0)
    rgh = 0.62 + 0.08 * grain + 0.25 * lich + 0.1 * gap
    save(G + "assets/textures/M_Bld_Station", "T_Station_Slate", alb, nor, rgh, np.zeros(s), darken=0.35, gloss=0.5)


# ---------------------------------------------------------------- slipway steel (galvanised, rusting)
def steel_set(folder, stem):
    s = (N, N)
    big, mid, fine = fbm(s, 3.0), fbm(s, 2.2), fbm(s, 1.2)
    streak = fbm(s, 2.4, aniso=(0.12, 1.8))
    rust = np.clip(smooth(0.6, 0.75, big * 0.6 + streak * 0.5) + smooth(0.8, 0.9, mid) * 0.6, 0, 1)
    galv = rgb((186, 186, 180))[None, None, :] * (0.97 + 0.06 * mid[..., None]) + (fine[..., None] - 0.5) * 0.02
    rcol = rgb((112, 86, 68))[None, None, :] * (0.85 + 0.3 * fine[..., None])
    m = rust < 0.5
    alb = np.where(m[..., None], np.clip(galv, 182 / 255, 1), rcol)
    alb = np.where(m[..., None], alb, alb * (1 - 0.2 * smooth(0.6, 0.9, fine)[..., None]))
    met = m.astype(np.float64)
    h = 0.3 * mid + rust * 0.4 + 0.3 * fine * rust
    nor = normal_from_height(h * 3, 3.0)
    rgh = np.where(m, 0.42 + 0.1 * fine, 0.82 + 0.1 * fine)
    save(folder, stem, alb, nor, rgh, met, darken=0.3, gloss=0.35)


# ---------------------------------------------------------------- details atlas
def details_set():
    alb = np.zeros((N, N, 3))
    rgh = np.zeros((N, N))
    met = np.zeros((N, N))
    hgt = np.zeros((N, N))
    big, mid, fine = fbm((N, N), 3.0), fbm((N, N), 2.2), fbm((N, N), 1.2)
    runs = fbm((N, N), 2.4, aniso=(0.12, 1.8))

    def box(name):
        u0, v0, u1, v1 = DETAILS[name]
        return int(round((1 - v1) * N)), int(round((1 - v0) * N)), int(round(u0 * N)), int(round(u1 * N))

    # painted steel roller door: 100 mm slats (45 in a 4.6 m door), dirty lower third, salt at the bottom
    r0, r1, c0, c1 = box("RollerDoor")
    hh = r1 - r0
    yy = np.arange(hh)[:, None] / hh
    slat = (yy * 46) % 1.0
    prof = np.sin(slat * np.pi) ** 0.6
    paint = rgb((66, 82, 96))
    reg = paint[None, None, :] * (0.92 + 0.1 * big[r0:r1, c0:c1, None]) * (0.86 + 0.14 * prof[..., None])
    grime = smooth(0.55, 1.0, yy)[..., None] * (0.5 + 0.5 * runs[r0:r1, c0:c1, None])
    reg = reg * (1 - 0.25 * grime) + rgb((92, 90, 80)) * 0.25 * grime
    saltm = smooth(0.85, 1.0, yy)[..., None] * smooth(0.4, 0.7, fine[r0:r1, c0:c1, None])
    reg = reg * (1 - 0.3 * saltm) + rgb((150, 150, 144)) * 0.3 * saltm
    rustm = smooth(0.82, 0.92, mid[r0:r1, c0:c1]) * (slat > 0.85)
    reg = reg * (1 - 0.6 * rustm[..., None]) + rgb((108, 80, 62)) * 0.6 * rustm[..., None]
    alb[r0:r1, c0:c1] = reg
    hgt[r0:r1, c0:c1] = prof * 1.0
    rgh[r0:r1, c0:c1] = 0.48 + 0.25 * grime[..., 0] + 0.2 * rustm
    # glass: dark, glossy, dirty corners
    r0, r1, c0, c1 = box("Glass")
    yy, xx = np.mgrid[0:r1 - r0, 0:c1 - c0]
    e = np.minimum(np.minimum(yy, r1 - r0 - 1 - yy), np.minimum(xx, c1 - c0 - 1 - xx)) / (r1 - r0)
    dirt = (1 - smooth(0.0, 0.25, e)) * (0.5 + 0.5 * fine[r0:r1, c0:c1])
    alb[r0:r1, c0:c1] = rgb((44, 52, 58)) * (1 - 0.2 * dirt[..., None]) + rgb((96, 96, 88)) * 0.2 * dirt[..., None]
    rgh[r0:r1, c0:c1] = 0.06 + 0.3 * dirt
    # crew door: painted timber, 4 panels, kick plate wear
    r0, r1, c0, c1 = box("CrewDoor")
    hh, ww = r1 - r0, c1 - c0
    yy, xx = np.mgrid[0:hh, 0:ww]
    fy, fx = yy / hh, xx / ww
    panel = np.zeros((hh, ww))
    for (a, b) in ((0.08, 0.45), (0.52, 0.9)):
        for (p, q) in ((0.14, 0.46), (0.54, 0.86)):
            inside = smooth(a, a + 0.015, fy) * (1 - smooth(b - 0.015, b, fy)) * smooth(p, p + 0.03, fx) * (1 - smooth(q - 0.03, q, fx))
            panel = np.maximum(panel, inside)
    grain = fbm((hh, ww), 1.8, aniso=(0.1, 1.5), seed=3)
    dpaint = rgb((52, 68, 84)) * (0.9 + 0.15 * grain[..., None])
    worn = smooth(0.85, 0.95, fine[r0:r1, c0:c1] * 0.5 + (1 - fy) * 0.0 + fy * 0.55)
    dpaint = dpaint * (1 - 0.5 * worn[..., None]) + rgb((126, 112, 92)) * 0.5 * worn[..., None]
    alb[r0:r1, c0:c1] = dpaint * (1 - 0.12 * (1 - panel[..., None]) * 0)
    hgt[r0:r1, c0:c1] = -panel * 0.6 + grain * 0.1
    rgh[r0:r1, c0:c1] = 0.42 + 0.3 * worn + 0.05 * grain
    # galvanised steel
    r0, r1, c0, c1 = box("Steel")
    reg = rgb((184, 184, 178)) * (0.97 + 0.06 * mid[r0:r1, c0:c1, None])
    alb[r0:r1, c0:c1] = np.clip(reg, 182 / 255, 1)
    met[r0:r1, c0:c1] = 1
    rgh[r0:r1, c0:c1] = 0.45 + 0.12 * fine[r0:r1, c0:c1]
    hgt[r0:r1, c0:c1] = 0.1 * fine[r0:r1, c0:c1]
    # lead flashing / flat roof: soft grey with white-ish oxide kept mid-grey
    r0, r1, c0, c1 = box("Lead")
    reg = rgb((104, 108, 110)) * (0.9 + 0.18 * big[r0:r1, c0:c1, None])
    ox = smooth(0.6, 0.85, mid[r0:r1, c0:c1])[..., None]
    alb[r0:r1, c0:c1] = reg * (1 - 0.3 * ox) + rgb((150, 152, 150)) * 0.3 * ox
    rgh[r0:r1, c0:c1] = 0.55 + 0.15 * ox[..., 0]
    hgt[r0:r1, c0:c1] = 0.4 * big[r0:r1, c0:c1]
    # door housing / painted steel boxes (same paint as the door, darker, streaked)
    r0, r1, c0, c1 = box("Housing")
    reg = rgb((58, 72, 84)) * (0.9 + 0.12 * big[r0:r1, c0:c1, None])
    st = smooth(0.6, 0.9, runs[r0:r1, c0:c1])[..., None]
    alb[r0:r1, c0:c1] = reg * (1 - 0.3 * st) + rgb((110, 100, 84)) * 0.3 * st
    rgh[r0:r1, c0:c1] = 0.5 + 0.2 * st[..., 0]
    # sign board: navy board, cream lettering, raised border, weathering
    r0, r1, c0, c1 = box("Sign")
    hh, ww = r1 - r0, c1 - c0
    board = Image.new("L", (ww, hh), 0)
    d = ImageDraw.Draw(board)
    d.rectangle((8, 8, ww - 9, hh - 9), outline=255, width=5)
    f1 = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 52)
    f2 = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 46)
    for txt, f, y in (("GALE ISLES COASTGUARD", f1, 22), ("PORT HAVEN LIFEBOAT STATION", f2, 92)):
        w = d.textlength(txt, font=f)
        d.text(((ww - w) / 2, y), txt, fill=255, font=f)
    letters = np.asarray(board, dtype=np.float64) / 255.0
    navy = rgb((40, 52, 66)) * (0.92 + 0.12 * big[r0:r1, c0:c1, None])
    cream = rgb((206, 202, 186)) * (0.94 + 0.06 * fine[r0:r1, c0:c1, None])
    reg = navy * (1 - letters[..., None]) + cream * letters[..., None]
    st = smooth(0.62, 0.9, runs[r0:r1, c0:c1])[..., None] * 0.6
    reg = reg * (1 - 0.2 * st) + rgb((100, 96, 84)) * 0.2 * st
    alb[r0:r1, c0:c1] = reg
    rgh[r0:r1, c0:c1] = 0.5 - 0.1 * letters + 0.15 * st[..., 0]
    hgt[r0:r1, c0:c1] = letters * 0.5
    nor = normal_from_height(hgt, 2.5, wrap=False)
    save(G + "assets/textures/M_Bld_Station", "T_Station_Details", alb, nor, rgh, met, darken=0.28, gloss=0.35)


if __name__ == "__main__":
    render_set()
    slate_set()
    details_set()
    steel_set(G + "assets/textures/M_Bld_Slipway", "T_Slipway_Steel")
    print("ok")
