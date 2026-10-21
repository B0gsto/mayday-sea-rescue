"""M_Ani_HerringGull texture set T_Gull_Feather (pure numpy, system python3 too; no bpy).

One 1024 atlas painted in sRGB by region, exactly where build.py's UV islands put the geometry:

  BODY  u along the spine (tail base 0 -> bill base 1), v around the section (0 back, .25 right, .5 belly, .75 left)
  WING  u across the span (root 0 -> tip 1), v around the section (0 leading edge, .25 under mid chord, .5 trailing
        edge, .75 top mid chord, 1 leading edge again); left and right wings share the layout
  BILL  u base -> tip, v around (0 top, .5 bottom)     LEG  u along the folded leg, v around
  TAIL  u base -> tip, v around                        EYE  the eyeball seen from outside

Adult herring gull (Larus argentatus): white head and body, medium grey mantle and wing coverts, black outer
primaries with a white mirror on the outermost, white secondary tips, white tail, yellow bill with a red gonys spot,
pale yellow eye, pink legs. Feather relief (scalloped coverts, primary shafts, primary separations) lives in the
normal map; the albedo keeps the markings. Saturation over the bill, legs and eye needs art/source signal mask
T_Gull_Feather_signal.png for check_textures (written by paint()).
"""
import math
import os
import struct
import zlib

import numpy as np

SIZE = 1024

# u0, v0, u1, v1 (v0 is the bottom of the image: Blender UV convention)
REGIONS = {
    "BODY": (0.008, 0.512, 0.508, 0.992),
    "WING": (0.516, 0.512, 0.992, 0.992),
    "BILL": (0.008, 0.020, 0.104, 0.140),
    "LEG": (0.112, 0.020, 0.240, 0.220),
    "TAIL": (0.248, 0.020, 0.464, 0.180),
    "EYE": (0.472, 0.020, 0.520, 0.068),
}

WHITE = (0.930, 0.936, 0.945)
WHITE_WARM = (0.905, 0.900, 0.888)          # underparts / undertail, a hair warmer
MANTLE = (0.600, 0.628, 0.658)              # herring gull mantle: medium blue-grey
MANTLE_D = (0.470, 0.500, 0.535)
BLACK = (0.070, 0.070, 0.078)
GREY_TIP = (0.300, 0.315, 0.340)
BILL_Y = (0.960, 0.760, 0.215)
BILL_TIP = (0.980, 0.930, 0.760)
GONYS = (0.800, 0.170, 0.120)
LEG_PINK = (0.905, 0.640, 0.600)
LEG_PINK_D = (0.760, 0.500, 0.470)
EYE_Y = (0.930, 0.880, 0.560)
PUPIL = (0.040, 0.040, 0.048)


def write_png(path, arr):
    """arr uint8 HxW (L), HxWx3 (RGB) or HxWx4 (RGBA); row 0 is the top of the image."""
    a = np.ascontiguousarray(arr, dtype=np.uint8)
    h, w = a.shape[:2]
    ch = 1 if a.ndim == 2 else a.shape[2]
    ctype = {1: 0, 3: 2, 4: 6}[ch]
    raw = b"".join(b"\x00" + a[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def u8(x):
    return np.clip(np.round(x * 255.0), 0, 255).astype(np.uint8)


# ---------------------------------------------------------------- patterns
def ss(e0, e1, x):
    """Smoothstep from e0 to e1; e0 > e1 is a falling edge (1 below e1, 0 above e0)."""
    d = e1 - e0
    if abs(d) < 1e-12:
        return np.zeros_like(np.asarray(x, dtype=float))
    t = np.clip((np.asarray(x, dtype=float) - e0) / d, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vnoise(shape, cell, rng):
    h, w = shape
    gh, gw = int(h / cell) + 3, int(w / cell) + 3
    g = rng.random((gh, gw))
    yy, xx = np.mgrid[0:h, 0:w] / float(cell)
    y0, x0 = yy.astype(int), xx.astype(int)
    fy, fx = yy - y0, xx - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b = g[y0, x0], g[y0, x0 + 1]
    c, d = g[y0 + 1, x0], g[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(shape, cell, rng, octaves=4):
    out = np.zeros(shape)
    amp, tot = 1.0, 0.0
    for i in range(octaves):
        out += amp * vnoise(shape, max(1.0, cell / (2 ** i)), rng)
        tot += amp
        amp *= 0.5
    return out / tot


def shingle(u, v, n_u, n_v, dome=1.0):
    """Overlapping-feather relief in region local coords: n_u feathers across u (elongated along u), n_v rows in v."""
    fu = (u * n_u) % 1.0
    fv = (v * n_v) % 1.0
    r = np.sqrt(((fu - 0.5) * 2.0 * 0.85) ** 2 + ((fv - 0.5) * 2.0) ** 2)
    d = np.clip(1.0 - r, 0.0, 1.0)
    return dome * d ** 0.55 + 0.32 * (1.0 - fv) * ss(0.0, 0.25, d)


def feather_lines(x, n, sharp=0.12, width=0.055):
    """Thin darker separation lines at every 1/n of x (x is the across-feather coordinate); never fully dark."""
    f = (x * n) % 1.0
    d = np.minimum(f, 1.0 - f)
    return 1.0 - sharp * np.exp(-(d / width) ** 2)


# ---------------------------------------------------------------- region painters
def paint_body(alb, rgh, hgt, rng):
    u, v = local_grid("BODY")
    white = np.array(WHITE)
    grey = np.array(MANTLE)
    # mantle: the whole back from the shoulders to the tail base; the head and neck are white
    back = np.maximum(ss(0.22, 0.06, v) + ss(0.78, 0.94, v), 0.0)      # 1 at the top, fades at v .06 / .94
    along = ss(0.03, 0.12, u) * ss(0.62, 0.52, u)                      # nowhere near the head, nowhere past the tail
    m = np.clip(back * along, 0.0, 1.0)
    # the folded-wing area on the flanks keeps a grey wash lower down than the back line
    flank = np.clip(ss(0.30, 0.16, v) * ss(0.50, 0.30, v) * along * 0.5, 0.0, 1.0)
    m = np.maximum(m, flank)
    col = white[None, None, :] * (1 - m[..., None]) + grey[None, None, :] * m[..., None]
    # feather shingles on the mantle: soft darkening between rows and a lit tip on every feather
    sh = shingle(u, v, 7.0, 5.0)
    col *= (0.94 + 0.10 * sh)[..., None]
    col *= (0.965 + 0.07 * fbm(col.shape[:2], 40.0, rng, 4))[..., None]
    lines = feather_lines(v, 5.0, 0.10)
    col *= (0.90 + 0.10 * lines)[..., None] * (0.92 + 0.08 * m[..., None] + 0.08 * (1 - m[..., None]))
    # faint grey wash on the nape (the neck's upper back) and the head's sides
    nape = ss(0.20, 0.30, v) * ss(0.62, 0.56, u) * ss(0.70, 0.58, u) * 0.45
    col *= (1.0 - nape[..., None] * 0.35)
    # grey rump / uppertail coverts past the mantle, then white
    rump = ss(0.13, 0.05, u) * np.clip(ss(0.30, 0.10, v) + ss(0.70, 0.90, v), 0, 1)
    col = col * (1 - rump[..., None]) + np.array(MANTLE_D)[None, None, :] * (rump * 0.75)[..., None]
    hgt_region(hgt, "BODY", 0.55 * sh + 0.20 * (0.5 + 0.5 * np.sin(60.0 * v)))
    rough_region(rgh, "BODY", 0.78 + 0.10 * (1 - m) - 0.05 * m)
    alb_region(alb, "BODY", col)


def paint_wing(alb, rgh, hgt, rng):
    u, v = local_grid("WING")
    top = v > 0.5
    under = ~top
    white = np.array(WHITE)
    grey = np.array(MANTLE)
    col = np.tile(white, (u.shape[0], u.shape[1], 1))
    # top: grey coverts and secondaries, a white trailing band and a white leading edge, black outer primaries
    # (v 0.5 is the trailing edge, v 1 the leading edge, so the secondaries' white tips sit just above 0.5)
    black = ss(0.78, 0.86, u)
    le_top = ss(0.915, 0.965, v)                      # white leading edge strip
    te_white = ss(0.585, 0.535, v)                    # broad white tips of the secondaries along the trailing edge
    topgrey = grey[None, None, :] * (1 - te_white[..., None]) + white[None, None, :] * te_white[..., None]
    topcol = topgrey * (1 - le_top[..., None]) + white[None, None, :] * le_top[..., None]
    topcol = topcol * (1 - black[..., None]) + np.array(BLACK)[None, None, :] * black[..., None]
    # the mirror: white oval on the outermost primary
    mu = (u - 0.912) / 0.055
    mv = (v - 0.655) / 0.070
    mirror = np.clip(1.0 - np.sqrt(mu ** 2 + mv ** 2), 0.0, 1.0)
    topcol = topcol * (1 - mirror[..., None] * 0.95) + white[None, None, :] * (mirror * 0.95)[..., None]
    # the grey band of the inner primaries just before the black tips, and the black tip on the underside
    undercol = white[None, None, :] * np.ones_like(col)
    ublack = ss(0.88, 0.94, u)
    undercol = undercol * (1 - ublack[..., None]) + np.array(GREY_TIP)[None, None, :] * ublack[..., None]
    ushad = np.exp(-((v - 0.30) / 0.13) ** 2) * 0.13     # faint shading under the coverts
    undercol *= (1.0 - ushad[..., None])
    col = np.where(top[..., None], topcol, undercol)
    # feather relief: coverts shingled along the span, long primary shafts in the outer wing, dark separations
    sh = shingle(u, v, 3.0, 9.0) * (1.0 - ss(0.55, 0.75, u))
    prim = np.zeros_like(u)
    shaft = np.zeros_like(u)
    outer = ss(0.48, 0.62, u)
    fv = (v * 6.0) % 1.0
    prim = outer * np.clip(1.0 - np.abs(fv - 0.5) * 2.0, 0, 1) ** 0.7
    shaft = outer * (1.0 - np.clip(np.abs(fv - 0.5) * 14.0, 0, 1))
    lines = feather_lines(v, 6.0, 0.16)
    col *= (0.91 + 0.14 * sh)[..., None]
    col *= (0.955 + 0.07 * prim)[..., None] * (1.0 - outer * (1.0 - lines))[..., None]
    col = col * (1 - 0.35 * black[..., None] * prim[..., None]) + np.array(GREY_TIP)[None, None, :] * (0.35 * black * prim)[..., None]
    col *= (0.965 + 0.07 * fbm(col.shape[:2], 32.0, rng, 4))[..., None]
    h = 0.62 * sh + 0.46 * prim + 0.22 * shaft
    hgt_region(hgt, "WING", h)
    rough_region(rgh, "WING", 0.74 + 0.10 * (1 - black) - 0.16 * black - 0.05 * prim)
    alb_region(alb, "WING", col)


def paint_tail(alb, rgh, hgt, rng):
    u, v = local_grid("TAIL")
    col = np.tile(np.array(WHITE_WARM), (u.shape[0], u.shape[1], 1))
    # the outer tail feathers a touch greyer, feather shafts and a soft shading gradient
    edge = np.maximum(ss(0.30, 0.06, v), ss(0.70, 0.94, v))
    col *= (1.0 - 0.055 * edge)[..., None]
    sh = shingle(u, v, 6.0, 3.0) * 0.5 + 0.5
    col *= (0.955 + 0.075 * sh)[..., None]
    col *= (0.97 + 0.05 * fbm(col.shape[:2], 36.0, rng, 3))[..., None]
    hgt_region(hgt, "TAIL", 0.35 * sh)
    rough_region(rgh, "TAIL", 0.80)
    alb_region(alb, "TAIL", col)


def paint_bill(alb, rgh, hgt, rng):
    u, v = local_grid("BILL")
    col = np.tile(np.array(BILL_Y), (u.shape[0], u.shape[1], 1))
    lower = np.clip(ss(0.34, 0.42, v) * ss(0.66, 0.58, v), 0, 1)        # the lower mandible, v around .5
    col *= (0.95 + 0.09 * lower)[..., None]
    # gape line where the mandibles meet (v .29 / .71), pale at the base
    gape = np.clip(1.0 - np.abs(np.abs(v - 0.5) - 0.21) * 26.0, 0, 1)
    col *= (1.0 - 0.30 * gape * ss(0.10, 0.35, u))[..., None]
    # red gonys spot on the lower mandible near the tip
    gs = np.clip(1.0 - np.sqrt(((u - 0.74) / 0.13) ** 2 + ((v - 0.50) / 0.13) ** 2), 0.0, 1.0)
    col = col * (1 - gs[..., None]) + np.array(GONYS)[None, None, :] * gs[..., None]
    # the mouth line at the gape corner, so the mandibles read from the side
    gape_corner = np.clip(1.0 - np.sqrt(((u - 0.16) / 0.14) ** 2 + ((np.abs(v - 0.5) - 0.215) / 0.05) ** 2), 0, 1)
    col *= (1.0 - 0.45 * gape_corner)[..., None]
    # pale nail at the tip, faint dark line below it
    tip = ss(0.90, 0.99, u)
    col = col * (1 - tip[..., None] * 0.9) + np.array(BILL_TIP)[None, None, :] * (tip * 0.9)[..., None]
    col *= (0.97 + 0.05 * fbm(col.shape[:2], 24.0, rng, 3))[..., None]
    hgt_region(hgt, "BILL", 0.10)
    rough_region(rgh, "BILL", 0.22 + 0.16 * tip)
    alb_region(alb, "BILL", col)


def paint_leg(alb, rgh, hgt, rng):
    u, v = local_grid("LEG")
    col = np.tile(np.array(LEG_PINK), (u.shape[0], u.shape[1], 1))
    # scaled tarsus rings, paler webbing at the foot end
    rings = 0.5 + 0.5 * np.sin(u * 90.0)
    col *= (0.94 + 0.10 * rings)[..., None]
    web = ss(0.55, 0.80, u)
    col = col * (1 - web[..., None] * 0.35) + np.array(LEG_PINK_D)[None, None, :] * (web * 0.35)[..., None]
    col *= (0.96 + 0.06 * fbm(col.shape[:2], 18.0, rng, 3))[..., None]
    hgt_region(hgt, "LEG", 0.16 * rings)
    rough_region(rgh, "LEG", 0.46 + 0.10 * web)
    alb_region(alb, "LEG", col)


def paint_eye(alb, rgh, hgt, rng):
    u, v = local_grid("EYE")
    col = np.tile(np.array(EYE_Y), (u.shape[0], u.shape[1], 1))
    r = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2)
    col *= (0.78 + 0.45 * ss(0.10, 0.42, r) * ss(0.78, 0.44, r))[..., None]   # a shaded iris ring
    pupil = ss(0.34, 0.22, r)
    col = col * (1 - pupil[..., None]) + np.array(PUPIL)[None, None, :] * pupil[..., None]
    col *= (0.95 + 0.08 * fbm(col.shape[:2], 10.0, rng, 2))[..., None]
    hgt_region(hgt, "EYE", 0.05)
    rough_region(rgh, "EYE", 0.12 + 0.25 * pupil)
    alb_region(alb, "EYE", col)


# ---------------------------------------------------------------- region helpers
def region_px(name):
    u0, v0, u1, v1 = REGIONS[name]
    r0, r1 = int(round((1.0 - v1) * SIZE)), int(round((1.0 - v0) * SIZE))
    c0, c1 = int(round(u0 * SIZE)), int(round(u1 * SIZE))
    return r0, r1, c0, c1


def local_grid(name):
    r0, r1, c0, c1 = region_px(name)
    v = np.linspace(0.0, 1.0, r1 - r0, endpoint=False) + 0.5 / (r1 - r0)
    u = np.linspace(0.0, 1.0, c1 - c0, endpoint=False) + 0.5 / (c1 - c0)
    return np.meshgrid(u, v)                      # u, v (row 0 = the bottom of the region in v)


def alb_region(alb, name, col):
    r0, r1, c0, c1 = region_px(name)
    alb[r0:r1, c0:c1] = np.clip(col[::-1], 0.0, 1.0)     # grid row 0 is v 0: flip to image order


def rough_region(rgh, name, val):
    import numpy as _np
    r0, r1, c0, c1 = region_px(name)
    v = _np.broadcast_to(_np.asarray(val, float), (r1 - r0, c1 - c0))
    rgh[r0:r1, c0:c1] = _np.clip(v[::-1], 0.04, 1.0)


def hgt_region(hgt, name, val):
    import numpy as _np
    r0, r1, c0, c1 = region_px(name)
    v = _np.broadcast_to(_np.asarray(val, float), (r1 - r0, c1 - c0))
    hgt[r0:r1, c0:c1] = _np.maximum(hgt[r0:r1, c0:c1], _np.clip(v[::-1], 0.0, None))


# ---------------------------------------------------------------- the set
def paint(seed=11):
    """(ALB uint8 HxWx3, NOR, RGH, MET) at SIZE, image order (row 0 = top)."""
    rng = np.random.default_rng(seed)
    alb = np.zeros((SIZE, SIZE, 3))
    rgh = np.full((SIZE, SIZE), 0.8)
    hgt = np.zeros((SIZE, SIZE))
    for fn in (paint_body, paint_wing, paint_tail, paint_bill, paint_leg, paint_eye):
        fn(alb, rgh, hgt, rng)
    # padding / mip fill: the set's own mean, so no island bleeds a black rim
    used = np.zeros((SIZE, SIZE), bool)
    for name in REGIONS:
        r0, r1, c0, c1 = region_px(name)
        used[r0:r1, c0:c1] = True
    alb = np.clip(alb, 0.070, 240.0 / 255.0)               # 12 1.4a: albedo 20..240, so keep the whites under 240
    mean = alb[used].mean(axis=0)
    alb[~used] = mean
    rgh[~used] = float(rgh[used].mean())
    # normal from the height: OpenGL (+X red, +Y green), modest strength; a slightly blurred height keeps it clean
    hs = hgt * 4.4
    hu = (np.roll(hs, -1, 1) - np.roll(hs, 1, 1)) * 0.5
    hv = -(np.roll(hs, -1, 0) - np.roll(hs, 1, 0)) * 0.5      # v grows upward, rows run down
    n = np.stack([-hu, -hv, np.ones_like(hs)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    nor = u8(n * 0.5 + 0.5)
    nor[~used] = (128, 128, 255)
    met = np.zeros((SIZE, SIZE), np.uint8)
    return u8(alb), nor, u8(rgh), met


def signal_mask():
    """255 where the albedo may be saturated (bill, legs, eye): check_textures needs it by convention."""
    m = np.zeros((SIZE, SIZE), np.uint8)
    for name in ("BILL", "LEG", "EYE"):
        r0, r1, c0, c1 = region_px(name)
        m[r0:r1, c0:c1] = 255
    # gonys red on the bill sits inside BILL; the black wingtip / mantle stay under the saturation ceiling
    return m


def write_set(out_dir, asset_dir, name="Gull", set_name="Feather"):
    """Writes T_<name>_<set>_{ALB,NOR,RGH,MET}.png into out_dir, and the signal mask beside build.py."""
    alb, nor, rgh, met = paint()
    for kind, arr in (("ALB", alb), ("NOR", nor), ("RGH", rgh), ("MET", met)):
        write_png(os.path.join(out_dir, "T_%s_%s_%s.png" % (name, set_name, kind)), arr)
    write_png(os.path.join(asset_dir, "signal_mask.png"), signal_mask())
    return {"ALB": alb, "NOR": nor, "RGH": rgh, "MET": met}


if __name__ == "__main__":                     # standalone: python3 gulltex.py <out dir>
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    write_set(out, out)
    print("wrote T_Gull_Feather_*.png to %s" % out)
