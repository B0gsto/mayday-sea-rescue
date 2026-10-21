"""Shared drawing kit for Mayday badge/emblem art.

Everything is drawn in a 512 unit design space at SS x resolution, then
downsampled with Lanczos. No text, no external assets.
"""
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4
SZ = 512
PX = SZ * SS

# ---------------------------------------------------------------- palette
NAVY_HI = (22, 57, 88)
NAVY_LO = (5, 15, 26)
FACE_HI = (24, 58, 88)
FACE_LO = (7, 20, 33)
INK = (4, 12, 20)
CREAM = (247, 239, 219)
CREAM_D = (198, 183, 152)
CORAL = (255, 112, 80)
CORAL_D = (188, 58, 40)
AMBER = (255, 186, 70)
AMBER_D = (196, 122, 28)
GOLD_L = (255, 231, 168)
GOLD = (233, 174, 66)
GOLD_D = (148, 94, 24)
BRONZE = (206, 138, 74)
TEAL = (52, 191, 176)
TEAL_D = (22, 116, 110)
RED = (226, 76, 58)
RED_D = (154, 38, 30)
STEEL = (186, 205, 220)
STEEL_D = (74, 96, 116)
WOOD = (188, 136, 86)
WOOD_D = (110, 72, 42)


def canvas(bg_center=(20, 52, 80), bg_edge=(4, 12, 22), glow=CORAL, glow_a=60):
    """Full-bleed square background: radial gradient + accent halo + grain."""
    img = Image.new("RGBA", (PX, PX))
    # radial gradient via low-res render then upscale (cheap and smooth)
    small = Image.new("RGB", (128, 128))
    px = small.load()
    cx, cy = 0.5, 0.47
    for y in range(128):
        for x in range(128):
            dx, dy = (x / 127 - cx), (y / 127 - cy) * 0.98
            d = min(1.0, math.hypot(dx, dy * 1.02) / 0.62)
            d = d ** 0.9
            px[x, y] = tuple(int(bg_center[i] + (bg_edge[i] - bg_center[i]) * d) for i in range(3))
    img.paste(small.resize((PX, PX), Image.BICUBIC).convert("RGBA"))

    # accent halo behind the coin
    halo = Image.new("RGBA", (PX, PX))
    hd = ImageDraw.Draw(halo)
    r = 210 * SS
    hd.ellipse([PX / 2 - r, PX / 2 - r, PX / 2 + r, PX / 2 + r], fill=glow + (glow_a,))
    halo = halo.filter(ImageFilter.GaussianBlur(46 * SS))
    img = Image.alpha_composite(img, halo)

    # fine grain
    rnd = random.Random(78)
    g = Image.new("L", (160, 160))
    g.putdata([rnd.randint(96, 160) for _ in range(160 * 160)])
    grain = Image.merge("RGBA", (g, g, g, Image.new("L", g.size, 16)))
    img = Image.alpha_composite(img, grain.resize((PX, PX), Image.BILINEAR))
    return img


def _rgba(c, a=255):
    return tuple(c) + (a,)


def smooth(pts, closed=True, n=14):
    """Catmull-Rom through pts, returns dense polyline."""
    p = [tuple(map(float, q)) for q in pts]
    if closed:
        p = [p[-1]] + p + [p[0], p[1]]
    else:
        p = [p[0]] + p + [p[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for s in range(n):
            t = s / n
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    if not closed:
        out.append(tuple(p[-2]))
    return [(x, y) for x, y in out]


def poly(draw, pts, fill):
    draw.polygon(pts, fill=fill)


def shape_mask(pts, closed=True):
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).polygon([(x * SS, y * SS) for x, y in smooth(pts, closed)], fill=255)
    return m


def ellipse_mask(box, blur=0):
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).ellipse([v * SS for v in box], fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * SS)) if blur else m


def rrect_mask(box, rad, blur=0):
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).rounded_rectangle([v * SS for v in box], radius=rad * SS, fill=255)
    return m.filter(ImageFilter.GaussianBlur(blur * SS)) if blur else m


def move(layer, dx=0, dy=0):
    out = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    out.paste(layer, (int(dx * SS), int(dy * SS)))
    return out


def grad_v(stops, y0=0, y1=SZ):
    """Vertical gradient image; stops = [(t,(r,g,b)), ...]."""
    col = Image.new("RGB", (1, 256))
    px = col.load()
    for i in range(256):
        t = i / 255
        c = stops[-1][1]
        for j in range(len(stops) - 1):
            a, b = stops[j], stops[j + 1]
            if a[0] <= t <= b[0]:
                f = (t - a[0]) / max(1e-6, b[0] - a[0])
                c = tuple(int(a[1][k] + (b[1][k] - a[1][k]) * f) for k in range(3))
                break
        px[0, i] = c
    h = int((y1 - y0) * SS)
    im = col.resize((PX, max(1, h)), Image.BICUBIC)
    out = Image.new("RGB", (PX, PX), stops[-1][1])
    out.paste(im, (0, int(y0 * SS)))
    return out


def grad_radial(inner, outer, cx=256, cy=256, r=220):
    small = Image.new("RGB", (160, 160))
    px = small.load()
    for y in range(160):
        for x in range(160):
            d = min(1.0, math.hypot(x - 80, y - 80) / 80)
            d = d ** 0.85
            px[x, y] = tuple(int(inner[i] + (outer[i] - inner[i]) * d) for i in range(3))
    im = small.resize((PX, PX), Image.BICUBIC)
    # reposition gradient centre
    off = Image.new("RGB", (PX, PX), outer)
    off.paste(im, (int((cx - 256) * SS), int((cy - 256) * SS)))
    return off


def fill_mask(img, mask, rgb, alpha=255):
    layer = Image.new("RGBA", (PX, PX), _rgba(rgb, 0))
    layer.putalpha(mask.point(lambda v: v * alpha // 255))
    return Image.alpha_composite(img, layer)


def paint(img, mask, grad, alpha=255):
    layer = grad.convert("RGBA")
    a = mask if alpha == 255 else mask.point(lambda v: v * alpha // 255)
    layer.putalpha(a)
    return Image.alpha_composite(img, layer)


def shadow(img, mask, dx=6, dy=9, blur=8, alpha=150, color=INK):
    m = Image.new("L", (PX, PX), 0)
    m.paste(mask, (int(dx * SS), int(dy * SS)))
    m = m.filter(ImageFilter.GaussianBlur(blur * SS))
    if alpha != 255:
        m = m.point(lambda v: v * alpha // 255)
    return fill_mask(img, m, color)


def outline(img, mask, width=2, alpha=110, color=INK):
    w = max(1, int(width * SS))
    er = mask.filter(ImageFilter.MinFilter(w * 2 + 1))
    ring = ImageChops.subtract(mask, er)
    return fill_mask(img, ring, color, alpha)


def shade(img, mask, top, bot, hi=90, lo=110):
    """Base gradient + top light + bottom shade inside a shape mask."""
    img = paint(img, mask, grad_v([(0.0, top), (1.0, bot)]))
    # top highlight
    g = Image.new("L", (PX, PX), 0)
    gd = ImageDraw.Draw(g)
    gd.rectangle([0, 0, PX, int(PX * 0.52)], fill=255)
    g = g.filter(ImageFilter.GaussianBlur(18 * SS))
    img = fill_mask(img, ImageChops.multiply(mask, g), (255, 250, 235), hi)
    # bottom shade
    g2 = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(g2).rectangle([0, int(PX * 0.58), PX, PX], fill=255)
    g2 = g2.filter(ImageFilter.GaussianBlur(22 * SS))
    img = fill_mask(img, ImageChops.multiply(mask, g2), INK, lo)
    return img


def glow(img, mask, color=CORAL, blur=14, alpha=120, grow=0):
    m = mask
    if grow:
        m = m.filter(ImageFilter.MaxFilter(int(grow * SS) * 2 + 1))
    m = m.filter(ImageFilter.GaussianBlur(blur * SS))
    m = m.point(lambda v: v * alpha // 255)
    return fill_mask(img, m, color)


def stroke(draw, pts, w0, w1=None, color=(0, 0, 0, 255), close=False):
    """Tapered round stroke along dense points."""
    w1 = w0 if w1 is None else w1
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        t = i / max(1, n - 1)
        w = (w0 + (w1 - w0) * t) * SS
        draw.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=color)
        if i:
            px, py = pts[i - 1]
            draw.line([px, py, x, y], fill=color, width=max(1, int(w)))


def stroke_mask(pts, w0, w1=None, close=False):
    m = Image.new("L", (PX, PX), 0)
    stroke(ImageDraw.Draw(m), [(x * SS, y * SS) for x, y in pts], w0, w1, 255, close)
    return m


def arc_pts(cx, cy, r, a0, a1, n=90, ry=None):
    ry = r if ry is None else ry
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append((cx + math.cos(a) * r, cy + math.sin(a) * ry))
    return [(x, y) for x, y in out]


def ring_mask(cx, cy, r_out, r_in):
    m = Image.new("L", (PX, PX), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([(cx - r_out) * SS, (cy - r_out) * SS, (cx + r_out) * SS, (cy + r_out) * SS], fill=255)
    d.ellipse([(cx - r_in) * SS, (cy - r_in) * SS, (cx + r_in) * SS, (cy + r_in) * SS], fill=0)
    return m


def circle_mask(cx, cy, r):
    return ellipse_mask([cx - r, cy - r, cx + r, cy + r])


def spec_arc(img, cx, cy, r, a0, a1, width=7, alpha=130, color=(255, 246, 224), blur=3, ry=None):
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).line([(x * SS, y * SS) for x, y in arc_pts(cx, cy, r, a0, a1, ry=r if ry is None else ry)], fill=255, width=int(max(1, width * SS)), joint="curve")
    m = m.filter(ImageFilter.GaussianBlur(blur * SS))
    return fill_mask(img, m, color, alpha)


# ---------------------------------------------------------------- coin
def coin(img, rim_top=GOLD_L, rim_mid=GOLD, rim_bot=GOLD_D,
         face_top=FACE_HI, face_lo=FACE_LO, r=224.0):
    R = r
    # ambient drop shadow
    m = ellipse_mask([256 - R, 256 - R, 256 + R, 256 + R], blur=1)
    mo = Image.new("L", (PX, PX), 0)
    mo.paste(m, (int(5 * SS), int(9 * SS)))
    m = mo.filter(ImageFilter.GaussianBlur(16 * SS))
    m = m.point(lambda v: v * 120 // 255)
    img = fill_mask(img, m, (0, 4, 8))

    rim = ring_mask(256, 256, R, R - 21)
    # rim body: gradient top-left light to bottom-right dark
    g = grad_v([(0.0, (255, 243, 208)), (0.20, (252, 216, 140)), (0.45, rim_mid),
                (0.72, rim_bot), (0.90, (156, 99, 32)), (1.0, (206, 148, 70))])
    img = paint(img, rim, g)
    # rim bevel: bright inner edge top, dark inner edge bottom
    img = spec_arc(img, 256, 256, R - 22, 190, 350, width=2.4, alpha=150, color=(255, 244, 214), blur=1)
    img = spec_arc(img, 256, 256, R - 22, 15, 165, width=3, alpha=110, color=(46, 28, 8), blur=2)
    # outer bevel
    img = spec_arc(img, 256, 256, R - 1.5, 185, 345, width=2.2, alpha=150, color=(255, 242, 206), blur=1)
    img = spec_arc(img, 256, 256, R - 1.5, 10, 168, width=2.6, alpha=140, color=(38, 22, 6), blur=2)
    # glossy sweep on rim (upper-left only)
    m = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(m).line([(x * SS, y * SS) for x, y in arc_pts(256, 256, R - 9, 208, 268)],
                           fill=255, width=int(4 * SS), joint="curve")
    m = m.filter(ImageFilter.GaussianBlur(4 * SS))
    img = fill_mask(img, m, (255, 253, 244), 105)

    # inner face
    face = circle_mask(256, 256, R - 21)
    img = paint(img, face, grad_v([(0.0, face_top), (0.55, (face_top[0] - 6, face_top[1] - 12, face_top[2] - 16)), (1.0, face_lo)]))
    # recess lip: dark top, light bottom
    img = spec_arc(img, 256, 256, R - 24, 175, 355, width=3.4, alpha=150, color=(0, 8, 16), blur=2.4)
    img = spec_arc(img, 256, 256, R - 24, 5, 175, width=2.2, alpha=70, color=(180, 214, 236), blur=2)
    # wide soft top light on face
    g2 = Image.new("L", (PX, PX), 0)
    ImageDraw.Draw(g2).ellipse([60 * SS, 34 * SS, 452 * SS, 268 * SS], fill=255)
    g2 = g2.filter(ImageFilter.GaussianBlur(40 * SS))
    img = fill_mask(img, ImageChops.multiply(face, g2), (150, 200, 230), 26)
    # engraved inner ring
    img = spec_arc(img, 256, 256, R - 44, 0, 360, width=1.4, alpha=60, color=(255, 240, 210), blur=0.8)
    img = spec_arc(img, 256, 256, R - 45.8, 0, 360, width=1.6, alpha=60, color=(0, 6, 12), blur=0.8)
    # subtle radial rays on the face (very low alpha)
    rays = Image.new("L", (PX, PX), 0)
    rd = ImageDraw.Draw(rays)
    for k in range(16):
        a = 2 * math.pi * k / 16 + 0.1
        x0, y0 = 256 + math.cos(a) * 60, 256 + math.sin(a) * 60
        x1, y1 = 256 + math.cos(a) * 172, 256 + math.sin(a) * 172
        rd.line([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=255, width=int(1.6 * SS))
    rays = rays.filter(ImageFilter.GaussianBlur(2 * SS))
    img = fill_mask(img, ImageChops.multiply(face, rays), (140, 190, 220), 16)
    # face gloss
    gloss = ellipse_mask([72, 40, 440, 250], blur=26)
    img = fill_mask(img, ImageChops.multiply(face, gloss), (200, 230, 250), 16)
    return img


def finalize(img, path):
    out = img.convert("RGBA").resize((SZ, SZ), Image.LANCZOS)
    out.save(path)
    return out
