"""M_Bld_Harbourmaster own texture set (system python3 + numpy + Pillow, no heavy slot).

    python3 art/source/buildings/M_Bld_Harbourmaster/maketex.py

Writes the two own sets to build/prod/M_Bld_Harbourmaster/textures/ (OpenGL normals, RGH / MET greyscale, _Wet) plus
signal_mask.png next to this file:
  T_Harbourmaster_Details_*  1024 atlas: brass nameplate, storm queue board, tide table board, glass, brass, iron,
                             white / red paint, rope, terracotta pots, dressed-granite trim strip.
  T_Harbourmaster_Granite_*  2048 coursed granite wall: 6.0 x 7.70 m (the full wall height), irregular block sizes,
                             staggered joints, recessed mortar, per-block colour, salt / lichen at the base.
Shared kit sets used as they are: BldTrim Sheet (B02 trim), Chandlery Slate (2 m tile).
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
OUT = G + "build/prod/M_Bld_Harbourmaster/textures"
N = 1024
FONT = "/System/Library/Fonts/Supplemental/"
TEX = "T_Harbourmaster_Details"

import sys
sys.path.insert(0, HERE)
from atlas import RECTS  # noqa: E402


def fbm(shape, beta, fmax, seed, aniso=(1.0, 1.0)):
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


def normal_from_height(h, strength):
    dy, dx = np.gradient(h)
    nx, ny, nz = -dx * strength, dy * strength, np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], -1) * 0.5 + 0.5


def sl(rect):
    u0, v0, u1, v1 = rect
    return np.s_[int(round((1 - v1) * N)):int(round((1 - v0) * N)), int(round(u0 * N)):int(round(u1 * N))]


def paste(reg, rgb_img):
    """rgb_img: PIL RGB / L at the region size."""
    alb[reg] = np.asarray(rgb_img.convert("RGB"), dtype=np.float64) / 255.0


def font(name, size):
    return ImageFont.truetype(FONT + name, size)


def tracked(d, xy, text, f, fill, tracking=0.0):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + tracking


def text_w(d, text, f, tracking=0.0):
    return sum(d.textlength(c, font=f) for c in text) + tracking * max(0, len(text) - 1)


alb = np.ones((N, N, 3)) * 0.46
rgh = np.ones((N, N)) * 0.8
met = np.zeros((N, N))
hgt = np.zeros((N, N))

big = fbm((N, N), 2.6, 8, 11)
mid = fbm((N, N), 2.2, 40, 12)
fine = fbm((N, N), 1.7, 70, 13)
runs = fbm((N, N), 2.3, 35, 14, aniso=(0.10, 1.8))


def paint(reg, c, var=0.07, rough=0.8, metal=0.0, height=0.0):
    base = np.array(c, dtype=np.float64) / 255.0
    a = base * (1.0 + var * (big[reg] - 0.5) * 2.0 + var * 0.5 * (mid[reg] - 0.5) * 2.0)[..., None]
    alb[reg] = a
    rgh[reg] = rough + 0.05 * (mid[reg] - 0.5)
    met[reg] = metal
    hgt[reg] = height * (mid[reg] - 0.5)


# ---- base fill: unsampled grey
alb[:] = 0.44 + 0.02 * (big[..., None] - 0.5)
rgh[:] = 0.8

# ---- brass nameplate: 1.30 x 0.36 m, 160 mm caps, near-black engraving on bright brass (reads at 15 m)
r = sl(RECTS["Nameplate"])
paint(r, (228, 203, 148), 0.04, rough=0.32, metal=1.0, height=0.0)
plate = Image.new("RGB", (alb[r].shape[1], alb[r].shape[0]), (228, 203, 148))
pd = ImageDraw.Draw(plate)
w, h = plate.size
for yy in range(h):                       # brushed brass: faint horizontal tone bands
    k = 1.0 + 0.05 * np.sin(yy * 0.21) + 0.030 * (big[r][yy].mean() - 0.5)
    pd.line((0, yy, w, yy), fill=tuple(int(min(255, c * k)) for c in (228, 203, 148)))
pd.rectangle((4, 4, w - 5, h - 5), outline=(240, 219, 168), width=3)
pd.rectangle((11, 11, w - 12, h - 12), outline=(206, 181, 127), width=1)
fs = 165
while fs > 60:
    f = font("DIN Condensed Bold.ttf", fs)
    if text_w(pd, "HARBOURMASTER", f, 1.0) <= w * 0.90 and fs * 0.62 <= h * 0.62:
        break
    fs -= 2
    f = font("DIN Condensed Bold.ttf", fs)
tw = text_w(pd, "HARBOURMASTER", f, 1.0)
tracked(pd, ((w - tw) / 2, h * 0.50 - fs * 0.36), "HARBOURMASTER", f, (30, 26, 21), 1.0)
for cx, cy in ((22, 22), (w - 23, 22), (22, h - 23), (w - 23, h - 23)):
    pd.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=(120, 96, 54))
paste(r, plate)
met[r] = 1.0
# engraving and screws: non-metal so the 1st-percentile luma rule sees the dark letters
arr = np.asarray(plate.convert("L"), dtype=np.float64)
met[r] = np.where(arr < 185, 0.0, 1.0)
hgt[r] = -0.45 * smooth(0.0, 1.0, (150 - arr) / 110.0)
rgh[r] = np.where(arr < 185, 0.66, 0.32)

# ---- storm queue board: whiteboard, navy header, queue state written up
r = sl(RECTS["StormBoard"])
paint(r, (228, 226, 216), 0.03, rough=0.42, height=0.0)
hh, ww = alb[r].shape[0], alb[r].shape[1]
board = Image.new("RGB", (ww, hh), (228, 226, 216))
bd = ImageDraw.Draw(board)
m = int(ww * 0.018)                       # white margin all round: nothing runs under the frame
hb = int(hh * 0.235)
bd.rectangle((m, m, ww - m, hb), fill=(36, 50, 60))
bd.text((m + 34, m + int(hb * 0.16)), "STORM QUEUE", font=font("Arial Bold.ttf", 50), fill=(240, 239, 231))
f2 = font("GillSans.ttc", 22)
tw = text_w(bd, "PORT HAVEN", f2, 2.0)
tracked(bd, (ww - tw - m - 34, m + int(hb * 0.36)), "PORT HAVEN", f2, (196, 205, 208), 2.0)
bd.line((m + 10, hb + 8, ww - m - 10, hb + 8), fill=(96, 130, 146), width=2)
for k in range(1, 5):
    y = hb + int((hh - hb - 24) * k / 5.0)
    bd.line((m + 12, y, ww - m - 12, y), fill=(206, 204, 193), width=1)
bd.text((m + 22, hb + int((hh - hb) * 0.40)), "NONE WAITING", font=font("Georgia Italic.ttf", 66), fill=(40, 58, 70))
bd.text((ww - 160, hh - 36), "0 / 20", font=font("Arial Bold.ttf", 21), fill=(120, 128, 130))
for cx, cy, cc in ((m + 20, m + 16, (142, 58, 48)), (ww - m - 24, m + 18, (142, 58, 48))):
    bd.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=cc)
    bd.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(210, 205, 196))
paste(r, board)
hgt[r] = 0.03 * (mid[r] - 0.5)
rgh[r] = 0.42

# ---- dark rebate behind the storm board
r = sl(RECTS["BoardBack"])
paint(r, (26, 32, 36), 0.16, rough=0.58, height=0.0)

# ---- tide table board
r = sl(RECTS["TideBoard"])
paint(r, (226, 222, 208), 0.03, rough=0.5, height=0.0)
hh, ww = alb[r].shape[0], alb[r].shape[1]
tb = Image.new("RGB", (ww, hh), (226, 222, 208))
td = ImageDraw.Draw(tb)
td.rectangle((0, 0, ww - 1, hh - 1), outline=(64, 78, 82), width=6)
td.rectangle((7, 7, ww - 8, hh - 8), outline=(170, 166, 150), width=1)
td.rectangle((7, 7, ww - 8, 48), fill=(38, 52, 60))
f3 = font("Arial Bold.ttf", 26)
td.text((14, 9), "TIDES", font=f3, fill=(236, 232, 218))
f4 = font("GillSans.ttc", 12)
tw = text_w(td, "PORT HAVEN", f4, 1.0)
tracked(td, (ww - tw - 14, 18), "PORT HAVEN", f4, (190, 202, 204), 1.0)
rows = [("HW", "05:42", "4.8"), ("LW", "11:58", "1.3"), ("HW", "18:16", "4.6"),
        ("LW", "00:21", "1.1"), ("HW", "06:39", "4.9"), ("LW", "12:47", "1.2")]
f5, f6 = font("GillSans.ttc", 19), font("Arial Bold.ttf", 13)
td.text((14, 55), "DAY      TIME      m", font=f6, fill=(96, 104, 104))
for i, (kind, t, v) in enumerate(rows):
    y = 76 + i * 30
    td.text((16, y), kind, font=f5, fill=(48, 70, 82))
    td.text((68, y), t, font=f5, fill=(38, 48, 52))
    td.text((164, y), v, font=f5, fill=(38, 48, 52))
    td.line((14, y + 26, ww - 14, y + 26), fill=(180, 176, 160), width=1)
paste(r, tb)
hgt[r] = 0.02 * (mid[r] - 0.5)
rgh[r] = 0.5

# ---- glass: faint green-grey, reflection streaks and a little salt haze
r = sl(RECTS["Glass"])
glass = np.ones((*alb[r].shape[:2], 3)) * np.array([0.22, 0.26, 0.27])
glass *= (0.9 + 0.2 * big[r])[..., None]
streak = smooth(0.62, 0.84, fine[r]) * 0.35
glass = glass * (1 - streak[..., None]) + np.array([0.62, 0.68, 0.70]) * streak[..., None]
alb[r] = glass
rgh[r] = 0.06
met[r] = 0.0
hgt[r] = 0.0

# ---- brass fittings
r = sl(RECTS["Brass"])
paint(r, (214, 188, 132), 0.06, rough=0.3, metal=1.0)
met[r] = np.where(mid[r] > 0.62, 1.0, 0.0)

# ---- black iron
r = sl(RECTS["Iron"])
paint(r, (34, 35, 36), 0.18, rough=0.66)
rust = smooth(0.66, 0.86, mid[r])
alb[r] = alb[r] * (1 - rust[..., None] * 0.5) + np.array([0.30, 0.19, 0.11]) * (rust[..., None] * 0.5)
rgh[r] += 0.12 * rust
hgt[r] = 0.10 * rust

# ---- white-painted joinery strip (u tiles every 1 m: keep it plain so the wrap does not show)
r = sl(RECTS["WhiteJoin"])
paint(r, (222, 220, 210), 0.03, rough=0.42)
grain = fbm((r[0].stop - r[0].start, r[1].stop - r[1].start), 2.0, 26, 31, aniso=(3.0, 0.05))
alb[r] *= (0.965 + 0.035 * grain)[..., None]
gr = smooth(0.66, 0.94, runs[r]) * 0.22
alb[r] = alb[r] * (1 - gr[..., None]) + np.array([0.50, 0.51, 0.46]) * gr[..., None]
rgh[r] += 0.12 * gr
# pinhole blisters and small chips in the paint
chip = smooth(0.80, 0.92, mid[r])
alb[r] = alb[r] * (1 - chip[..., None] * 0.5) + np.array([0.42, 0.40, 0.36]) * (chip[..., None] * 0.5)
hgt[r] += 0.12 * chip

# ---- dressed granite strip (u tiles every 1 m: fine sawn grain, no joints; quoins / sills / copings are separate blocks)
r = sl(RECTS["Granite"])
gy, gx = r[0].stop - r[0].start, r[1].stop - r[1].start
h = fbm((gy, gx), 2.0, 46, 32)
spk = fbm((gy, gx), 1.5, 260, 34)
alb[r] = np.array([0.515, 0.508, 0.484]) * (0.90 + 0.17 * h)[..., None] * (0.93 + 0.14 * spk)[..., None]
hgt[r] = 0.16 * h + 0.05 * spk
rgh[r] = 0.74 + 0.05 * (h - 0.5)
salt = smooth(0.84, 0.97, fbm((gy, gx), 2.2, 18, 33)) * 0.16
alb[r] = alb[r] * (1 - salt[..., None]) + np.array([0.64, 0.64, 0.60]) * salt[..., None]
rgh[r] += 0.05 * salt

# ---- white paint (lifebuoy board / small fittings)
r = sl(RECTS["WhitePaint"])
paint(r, (218, 216, 206), 0.05, rough=0.46)

# ---- signal red paint (lifebuoy, pennant): exempt via signal_mask.png
r = sl(RECTS["RedPaint"])
paint(r, (168, 52, 42), 0.10, rough=0.48)
fade = smooth(0.55, 0.95, big[r]) * 0.18
alb[r] = alb[r] * (1 - fade[..., None]) + np.array([0.58, 0.30, 0.22]) * fade[..., None]
rgh[r] += 0.08 * fade

# ---- manila rope lanyard
r = sl(RECTS["Rope"])
paint(r, (158, 141, 108), 0.13, rough=0.82)
weave = 0.5 + 0.5 * np.sin(np.linspace(0, 34 * np.pi, r[1].stop - r[1].start))[None, :]
alb[r] *= (0.86 + 0.14 * weave)[..., None] * (0.94 + 0.12 * fine[r])[..., None]
hgt[r] = 0.25 * weave * np.ones((r[0].stop - r[0].start, 1))

# ---- terracotta chimney pots
r = sl(RECTS["Pots"])
paint(r, (120, 92, 76), 0.10, rough=0.76)
soot = smooth(0.55, 0.95, runs[r]) * 0.25
alb[r] = alb[r] * (1 - soot[..., None] * 0.4) + np.array([0.18, 0.17, 0.16]) * soot[..., None] * 0.4
rgh[r] += 0.1 * soot

# ================================================================ coursed granite wall set
GW, GH = 6.0, 7.70           # metres covered by one 2048 tile: wall height plus the gable apex (band UV maps z / 7.70)
GN = 2048


def granite_wall():
    """Irregular coursed ashlar, seamless in u: varied block sizes and staggered joints, recessed mortar, per-block
    colour, fine sawn grain, salt bloom and lichen up to about 1.5 m (v = 0 at the base of the building)."""
    r = np.random.default_rng(71)
    sx, sy = GN / GW, GN / GH
    ids = np.zeros((GN, GN), np.int32)
    px, pz = np.meshgrid((np.arange(GN) + 0.5) / sx, (GN - np.arange(GN) - 0.5) / sy)
    lic = fbm((GN, GN), 2.2, 26, 72)
    licf = fbm((GN, GN), 1.8, 120, 73)
    grain = fbm((GN, GN), 1.6, 320, 74)
    spk = fbm((GN, GN), 1.4, 700, 76)
    dress = fbm((GN, GN), 2.0, 90, 75, aniso=(1.8, 0.25))
    # courses
    hs, tot = [], 0.0
    while tot < GH:
        h = float(r.uniform(0.29, 0.52))
        hs.append(h)
        tot += h
    k = GH / tot
    hs = [h * k for h in hs]
    z0 = 0.0
    tint = {}
    bid = 1
    for h in hs:
        z1 = z0 + h
        ws, t = [], 0.0
        while t < GW:
            w = float(r.uniform(0.50, 1.20))
            ws.append(w)
            t += w
        kw = GW / t
        u = float(r.uniform(0.0, 1.0)) * 0.9
        for w in ws:
            w *= kw
            for ua, ub in ((u, u + w), (u - GW, u + w - GW)):
                ia, ib = int(round((ua + 0.005) * sx)), int(round((ub - 0.005) * sx))
                ja, jb = int(round((z0 + 0.005) * sy)), int(round((z1 - 0.005) * sy))
                if ia >= ib or ja >= jb:
                    continue
                # fill each contiguous pixel run, wrapping at the u seam
                cur = []
                for c0 in range(ia, ib):
                    cc = c0 % GN
                    if cur and cc != cur[-1] + 1:
                        ids[GN - jb:GN - ja, cur[0]:cur[-1] + 1] = bid
                        cur = []
                    cur.append(cc)
                if cur:
                    ids[GN - jb:GN - ja, cur[0]:cur[-1] + 1] = bid
            v = float(r.uniform(-0.050, 0.050))
            warm = float(r.uniform(-0.012, 0.014))
            tint[bid] = (0.475 + v + warm, 0.472 + v, 0.455 + v - warm)
            bid += 1
            u += w
            if u >= GW:
                u -= GW
        z0 = z1
    # block faces: id colours, grain, sawn dressing marks
    block = ids > 0
    cols = np.zeros((GN, GN, 3))
    rgh_g = np.zeros((GN, GN))
    hgt_g = np.zeros((GN, GN))
    for i in range(1, bid):
        c = tint[i]
        m = ids == i
        cols[m] = c
        rgh_g[m] = 0.72 + 0.05 * ((i * 37) % 17) / 17.0
        hgt_g[m] = 0.80 + 0.04 * ((i * 53) % 13) / 13.0
    cols *= (0.84 + 0.32 * grain)[..., None] * (0.94 + 0.12 * dress)[..., None] * (0.93 + 0.14 * lic)[..., None]
    # recessed mortar (ids == 0) and its shadow line
    cols[~block] = np.array([0.215, 0.215, 0.205]) * (0.85 + 0.3 * grain[~block])[..., None]
    rgh_g[~block] = 0.94
    hgt_g[~block] = 0.0
    edge = np.zeros((GN, GN))
    bm = (block * 255).astype(np.uint8)
    edge = np.asarray(Image.fromarray(bm).filter(ImageFilter.GaussianBlur(2.4)), np.float64) / 255.0
    cols *= (0.64 + 0.36 * edge)[..., None]
    hgt_g *= 0.45 + 0.55 * edge
    # salt bloom / damp / lichen near the base, plus sparse lichen higher up
    zz = pz
    lowfade = 1.0 - smooth(0.10, 2.20, zz)
    saltn = smooth(0.50, 0.82, licf) * lowfade * (0.30 + 0.70 * lic)
    cols = cols * (1 - saltn[..., None] * 0.50) + np.array([0.745, 0.752, 0.725]) * (saltn[..., None] * 0.50)
    rgh_g += 0.06 * saltn
    damp = (1.0 - smooth(0.0, 0.55, zz)) * (0.55 + 0.45 * lic)
    cols *= (1.0 - 0.13 * damp)[..., None]
    base = 1.0 - smooth(0.0, 0.85, zz)
    cols = cols * (1 - 0.26 * base[..., None]) + np.array([0.335, 0.375, 0.285]) * (0.26 * base[..., None])
    lich = smooth(0.56, 0.84, lic) * (0.12 + 0.88 * lowfade)
    lich *= smooth(0.30, 0.58, licf)
    cols = cols * (1 - lich[..., None]) + np.array([0.385, 0.415, 0.325]) * lich[..., None]
    rgh_g += 0.06 * lich
    hgt_g += 0.10 * grain + 0.06 * spk
    return cols, rgh_g, np.zeros((GN, GN)), hgt_g


# ---- output
w8 = lambda a: (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)


def write_set(stem, a, hh, rr, mm, strength=9.0):
    nor = normal_from_height(hh, strength)
    Image.fromarray(w8(a)).save(os.path.join(OUT, stem + "_ALB.png"))
    Image.fromarray(w8(nor)).save(os.path.join(OUT, stem + "_NOR.png"))
    Image.fromarray(w8(rr)).save(os.path.join(OUT, stem + "_RGH.png"))
    Image.fromarray(w8(mm)).save(os.path.join(OUT, stem + "_MET.png"))
    metal = mm > 0.5
    dk = np.where(metal, 0.10, 0.36)[..., None]
    walb = np.clip(a * (1 - dk), 30 / 255, 236 / 255)
    wrgh = np.clip(rr - 0.42 * (0.6 + 0.4 * rr), 0.05, 1.0)
    Image.fromarray(w8(walb)).save(os.path.join(OUT, stem + "_ALB_Wet.png"))
    Image.fromarray(w8(wrgh)).save(os.path.join(OUT, stem + "_RGH_Wet.png"))


os.makedirs(OUT, exist_ok=True)
write_set(TEX, np.clip(alb, 24 / 255, 240 / 255), np.clip(hgt, -1, 1), np.clip(rgh, 0.04, 1.0), met)
ga, gr, gm, gh = granite_wall()
write_set("T_Harbourmaster_Granite", np.clip(ga, 24 / 255, 240 / 255), gh, np.clip(gr, 0.04, 1.0), gm, strength=9.5)

mask = np.zeros((N, N), np.uint8)
u0, v0, u1, v1 = RECTS["RedPaint"]
mask[int((1 - v1) * N) - 4:int((1 - v0) * N) + 4, int(u0 * N) - 4:int(u1 * N) + 4] = 255
Image.fromarray(mask).save(os.path.join(HERE, "signal_mask.png"))
print("wrote", OUT)
