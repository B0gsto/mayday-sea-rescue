"""Badge coin art. One function per badge, shared coin + lighting kit."""
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

import iconlib as L
import shapes as S


# ------------------------------------------------------------ kit
def coin_base(glow, glow_a, coin, **kw):
    img = L.canvas(glow=glow, glow_a=glow_a)
    return coin(img, **kw) if coin else img


def face_clip(layer, r=201):
    out = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    out.paste(layer, (0, 0), L.circle_mask(256, 256, r))
    return out


def star_mask(cx, cy, ro, ri, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        a = math.radians(rot + i * 180.0 / n)
        r = ro if i % 2 == 0 else ri
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return L.shape_mask(pts, True)


def numeral_mask(text, cx, cy, px):
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", int(px * L.SS), index=1)
    m = Image.new("L", (L.PX, L.PX), 0)
    ImageDraw.Draw(m).text((cx * L.SS, cy * L.SS), text, font=font, fill=255, anchor="mm")
    return m


def rich_rim(img):
    """Wider, brighter gold rim with milled ticks: reads as a rarer medal."""
    ring = L.ring_mask(256, 256, 210, 199)
    img = L.paint(img, ring, L.grad_v([(0.0, (255, 242, 196)), (0.42, (247, 190, 82)),
                                       (0.78, (172, 104, 24)), (1.0, (230, 170, 66))]))
    img = L.spec_arc(img, 256, 256, 205, 190, 350, width=1.8, alpha=150, color=(255, 250, 224), blur=1.2)
    img = L.spec_arc(img, 256, 256, 201, 10, 170, width=2.2, alpha=120, color=(70, 40, 8), blur=1.6)
    ticks = Image.new("L", (L.PX, L.PX), 0)
    td = ImageDraw.Draw(ticks)
    for k in range(60):
        a = 2 * math.pi * k / 60
        td.line([(256 + math.cos(a) * 212) * L.SS, (256 + math.sin(a) * 212) * L.SS,
                 (256 + math.cos(a) * 221) * L.SS, (256 + math.sin(a) * 221) * L.SS],
                fill=255, width=int(1.1 * L.SS))
    ticks = ticks.filter(ImageFilter.GaussianBlur(0.5 * L.SS))
    return L.fill_mask(img, ticks, (255, 242, 204), 70)


def glyph_tile(img, x, y, s, glyph, top=(252, 244, 226), bot=(198, 182, 150), ring=L.STEEL_D):
    m = L.rrect_mask([x - s / 2, y - s / 2, x + s / 2, y + s / 2], s * 0.24)
    img = L.shadow(img, m, 2, 4, 4, 100)
    img = L.shade(img, m, top, bot, 80, 80)
    img = L.outline(img, m, 1.2, 120, ring)
    return glyph(img, x, y, s * 0.52)


# ------------------------------------------------------------ primitives
def boat_hook(img, x0=108, y0=402, x1=370, y1=178, w=18):
    shaft = L.stroke_mask(L.smooth([(x0, y0), ((x0 + x1) / 2 - 8, (y0 + y1) / 2 + 6), (x1, y1)],
                                   closed=False, n=18), w, w)
    img = L.shadow(img, shaft, 3, 5, 5, 110)
    img = L.shade(img, shaft, (250, 212, 156), (176, 124, 70), 95, 75)
    img = L.outline(img, shaft, 1.3, 130)
    # grain
    for t in (-0.28, 0.0, 0.28):
        a = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(a) * w * t, math.cos(a) * w * t
        gm = L.stroke_mask(L.smooth([(x0 + 26 + nx, y0 - 22 + ny), (x1 - 40 + nx, y1 + 34 + ny)],
                                    closed=False, n=10), 1.5, 1.5)
        img = L.fill_mask(img, gm, L.WOOD_D, 70)
    # hook
    hook = L.stroke_mask(L.smooth([(x1 - 2, y1 + 8), (x1 + 26, y1 - 14), (x1 + 32, y1 - 54),
                                   (x1 + 2, y1 - 80), (x1 - 30, y1 - 70), (x1 - 42, y1 - 44)],
                                  closed=False, n=22), 12, 7)
    img = L.shadow(img, hook, 4, 6, 5, 110)
    img = L.shade(img, hook, (250, 206, 148), (168, 112, 54), 100, 80)
    img = L.outline(img, hook, 1.4, 135)
    tip = L.stroke_mask([(x1 - 46, y1 - 42), (x1 - 54, y1 - 34)], 6, 2)
    img = L.shade(img, tip, L.BRONZE, (120, 76, 30), 80, 90)
    # collar
    col = S.emask_ellipse(x1 - 3, y1 + 5, 12, 12)
    img = L.shade(img, col, (250, 205, 140), (140, 92, 42), 90, 95)
    img = L.outline(img, col, 1.2, 120)
    return img


def wheel(img, cx=256, cy=256, rr=150, rim=26, gold=True):
    top, mid, bot = ((255, 252, 240), (240, 230, 206), (146, 126, 96)) if not gold else \
        ((255, 226, 156), L.GOLD, (150, 96, 26))
    ang0 = 22.5
    # handles first (behind rim)
    for k in range(8):
        a = math.radians(ang0 + 45 * k)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        m = L.stroke_mask([(cx + ux * (rr - 26), cy + uy * (rr - 26)),
                           (cx + ux * (rr + 34), cy + uy * (rr + 34))], 16, 12)
        img = L.shadow(img, m, 2, 4, 3, 90)
        img = L.shade(img, m, (248, 224, 174), (162, 110, 40), 95, 90)
        img = L.outline(img, m, 1.2, 120)
        hm = S.emask_ellipse(cx + ux * (rr + 36), cy + uy * (rr + 36), 9, 9)
        img = L.shade(img, hm, (255, 242, 210), (170, 118, 44), 95, 85)
        img = L.outline(img, hm, 1.1, 110)
    # spokes
    stop, sbot = ((250, 226, 168), (176, 118, 40)) if gold else ((252, 246, 230), (182, 166, 132))
    for k in range(8):
        a = math.radians(ang0 + 45 * k)
        ux, uy = math.cos(a), math.sin(a)
        m = L.stroke_mask([(cx, cy), (cx + ux * (rr - 4), cy + uy * (rr - 4))], 15, 12)
        img = L.shadow(img, m, 3, 6, 5, 110)
        img = L.shade(img, m, stop, sbot, 95, 105)
        img = L.outline(img, m, 1.8, 150)
    # rim torus
    outer = L.circle_mask(cx, cy, rr)
    inner = L.circle_mask(cx, cy, rr - rim)
    tor = ImageChops.subtract(outer, inner)
    img = L.shadow(img, outer, 3, 6, 6, 110)
    img = L.paint(img, tor, L.grad_v([(0.0, top), (0.35, mid), (0.72, bot), (0.9, (110, 92, 68)), (1.0, (190, 172, 138))]))
    img = L.spec_arc(img, cx, cy, rr - rim * .45, 185, 340, width=3.4, alpha=115,
                     color=(255, 250, 228), blur=2.2)
    img = L.spec_arc(img, cx, cy, rr - rim * .45, 15, 165, width=3.2, alpha=90,
                     color=(70, 40, 8), blur=2.2)
    img = L.outline(img, outer, 1.6, 130)
    img = L.outline(img, inner, 1.6, 120)
    # hub
    hub = L.circle_mask(cx, cy, 34)
    img = L.shadow(img, hub, 2, 4, 4, 100)
    img = L.shade(img, hub, (255, 232, 172), (158, 100, 28), 100, 95)
    img = L.outline(img, hub, 1.6, 130)
    hr = L.ring_mask(cx, cy, 22, 18)
    img = L.fill_mask(img, hr, (255, 240, 196), 120)
    hc = L.circle_mask(cx, cy, 8)
    img = L.shade(img, hc, (255, 246, 214), (176, 118, 44), 100, 80)
    img = L.outline(img, hc, 1.2, 120)
    return img


def cross(img, cx, cy, s=62, w=42, col=(L.RED, L.RED_D)):
    m = Image.new("L", (L.PX, L.PX), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([(cx - w / 2) * L.SS, (cy - s) * L.SS,
                         (cx + w / 2) * L.SS, (cy + s) * L.SS], radius=9 * L.SS, fill=255)
    d.rounded_rectangle([(cx - s) * L.SS, (cy - w / 2) * L.SS,
                         (cx + s) * L.SS, (cy + w / 2) * L.SS], radius=9 * L.SS, fill=255)
    img = L.shadow(img, m, 4, 6, 6, 140)
    img = L.shade(img, m, (255, 122, 96), (160, 34, 28), 90, 85)
    img = L.outline(img, m, 2.0, 145)
    # cream keyline so the cross pops off dark faces
    img = L.outline(img, m, 4.4, 60, (255, 246, 228)) if False else img
    return img


# ------------------------------------------------------------ badges
def first_rescue(coin=None):
    img = L.canvas(glow=L.CORAL, glow_a=55)
    img = coin(img) if coin else img
    img = boat_hook(img)
    img = S.life_ring(img, 246, 276, 144, 76, band=L.CORAL)
    return img


def cert_helm(coin=None):
    img = L.canvas(glow=L.GOLD, glow_a=48)
    img = coin(img) if coin else img
    img = wheel(img, 256, 256, 148, 25, gold=False)
    return img


def cert_casualty_care(coin=None):
    img = L.canvas(glow=L.RED, glow_a=50)
    img = coin(img) if coin else img
    img = S.life_ring(img, 256, 264, 138, 72, band=L.CORAL)
    img = cross(img, 256, 264, 74, 46)
    # small shine on the cross
    img = L.spec_arc(img, 256, 264, 24, 200, 340, width=3, alpha=60, color=(255, 230, 220), blur=3)
    return img


def cert_rescue_swimmer(coin=None):
    img = L.canvas(glow=L.TEAL, glow_a=62)
    img = coin(img) if coin else img
    # surface water streaks, low contrast
    for pts, w, a in [([(84, 404), (156, 394), (226, 402)], 7, 120),
                      ([(286, 424), (364, 414), (432, 422)], 5, 90),
                      ([(96, 168), (152, 160)], 4, 60)]:
        m = L.stroke_mask(L.smooth(pts, closed=False, n=14), w, 1.5)
        img = L.fill_mask(img, m, L.TEAL, a)
    # rescuer: diagonal body from lower left, head and arm to the right
    body = L.stroke_mask(L.smooth([(132, 402), (186, 368), (222, 344)], closed=False, n=16), 62, 48)
    img = S.paint_subject(img, body, (252, 240, 210), (170, 148, 108), 130, 95, 85, 2.0)
    for pts, w0, w1, al in [([(128, 412), (96, 404)], 11, 3, 190),
                            ([(146, 418), (116, 426)], 8, 3, 150)]:
        img = L.fill_mask(img, L.stroke_mask(L.smooth(pts, closed=False, n=8), w0, w1),
                          (232, 248, 248), al)
    head = S.emask_ellipse(244, 330, 35, 34)
    img = S.paint_subject(img, head, (252, 240, 210), (170, 148, 108), 130, 90, 80, 2.0)
    cap = ImageChops.multiply(S.emask_ellipse(243, 315, 37, 28), L.ellipse_mask([204, 286, 286, 332]))
    img = L.paint(img, cap, L.grad_v([(0, (96, 214, 198)), (1, L.TEAL_D)]))
    img = L.outline(img, cap, 1.6, 120)
    # rescue tube, bright diagonal bar
    tube = S.emask_ellipse(334, 282, 66, 24, -0.60)
    img = L.shadow(img, tube, 4, 7, 6, 120)
    img = L.paint(img, tube, L.grad_v([(0, (255, 244, 188)), (0.42, (255, 196, 82)),
                                       (1, (222, 130, 30))]))
    img = L.spec_arc(img, 334, 278, 46, 195, 330, width=5, alpha=150,
                     color=(255, 252, 232), blur=3)
    img = L.outline(img, tube, 2.4, 155)
    tb = ImageChops.multiply(tube, L.rrect_mask([340, 250, 360, 320], 6))
    img = L.fill_mask(img, tb, (255, 248, 226), 230)
    # rescuer's forward arm and hand on the tube
    arm = L.stroke_mask(L.smooth([(256, 338), (278, 326), (296, 316)], closed=False, n=10), 20, 14)
    img = S.paint_subject(img, arm, (252, 240, 210), (170, 148, 108), 125, 90, 80, 1.8)
    # casualty at the upper right, gripping the far end
    sh = S.emask_ellipse(402, 250, 42, 24, 0.55)
    img = S.paint_subject(img, sh, (250, 234, 202), (158, 134, 98), 120, 90, 80, 1.8)
    head = S.emask_ellipse(414, 210, 29, 29)
    img = S.paint_subject(img, head, (252, 238, 208), (164, 140, 102), 128, 85, 80, 1.8)
    cap = ImageChops.multiply(S.emask_ellipse(413, 198, 31, 24), L.ellipse_mask([382, 174, 446, 216]))
    img = L.paint(img, cap, L.grad_v([(0, (255, 130, 98)), (1, L.CORAL_D)]))
    img = L.outline(img, cap, 1.6, 120)
    carm = L.stroke_mask(L.smooth([(404, 238), (394, 244), (384, 250)], closed=False, n=8), 15, 13)
    img = S.paint_subject(img, carm, (250, 234, 202), (158, 134, 98), 120, 85, 80, 1.6)
    return img

def cert_coxswain(coin=None):
    img = L.canvas(glow=L.GOLD, glow_a=52)
    img = coin(img) if coin else img
    # small lifeboat in profile, below the cap
    base = img
    img = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    hull = L.shape_mask(L.smooth([(122, 366), (180, 358), (242, 352), (300, 344), (344, 330),
                                  (360, 338), (350, 362), (314, 378), (256, 386), (194, 382),
                                  (140, 376)], True))
    img = L.shadow(img, hull, 4, 7, 7, 130)
    img = L.paint(img, hull, L.grad_v([(0, (255, 152, 112)), (0.55, L.CORAL), (1, (146, 34, 26))]))
    img = L.outline(img, hull, 1.8, 140)
    sheer = L.stroke_mask(L.smooth([(122, 366), (180, 358), (242, 352), (300, 344), (344, 330)],
                                   closed=False, n=22), 10, 6)
    img = L.fill_mask(img, sheer, (250, 240, 218), 245)
    img = L.outline(img, sheer, 1.2, 110)
    # little cabin + window
    cab = L.rrect_mask([226, 320, 288, 348], 8)
    img = L.shade(img, cab, (252, 244, 226), (178, 158, 122), 95, 80)
    img = L.outline(img, cab, 1.3, 120)
    win = L.rrect_mask([236, 327, 278, 340], 4)
    img = L.paint(img, win, L.grad_v([(0, (150, 202, 220)), (1, (26, 66, 88))]))
    img = L.outline(img, win, 1.1, 120)
    th = L.rrect_mask([256, 346, 300, 356], 3)
    img = L.shade(img, th, (252, 238, 212), (170, 148, 112), 80, 70)
    img = L.outline(img, th, 1.0, 110)
    # bow rope
    rope = L.stroke_mask(L.smooth([(352, 340), (356, 356), (346, 368)], closed=False, n=10), 3, 3)
    img = L.fill_mask(img, rope, (242, 230, 206), 220)
    img = img.rotate(6, resample=Image.BICUBIC, center=(250 * L.SS, 370 * L.SS))
    img = Image.alpha_composite(base, img)
    base = img
    # sea
    for yy, w, a in [(396, 8, 170), (414, 5, 105)]:
        wm = L.stroke_mask(L.smooth([(104, yy), (200, yy - 9), (312, yy + 4), (410, yy - 8)],
                                    closed=False, n=18), w, 2)
        img = L.fill_mask(img, wm, L.TEAL, a)
    # cap on its own layer for a slight tilt
    base = img
    img = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    # crown
    crown = L.shape_mask(L.smooth([(140, 240), (146, 196), (184, 168), (232, 158), (280, 158),
                                   (328, 168), (366, 196), (372, 240), (256, 252)], True))
    img = S.paint_subject(img, crown, (254, 249, 236), (196, 180, 146), 125, 105, 85)
    cr = L.stroke_mask(L.smooth([(176, 204), (256, 196), (336, 204)], closed=False, n=16), 2.8, 1.2)
    img = L.fill_mask(img, cr, (210, 196, 166), 100)
    # band
    band = ImageChops.multiply(crown, L.rrect_mask([156, 226, 356, 254], 8))
    img = L.paint(img, band, L.grad_v([(0, (34, 74, 110)), (1, (5, 16, 28))]))
    img = L.outline(img, band, 1.7, 135)
    # gold braid + buttons
    braid = L.stroke_mask(L.smooth([(170, 233), (256, 238), (342, 233)], closed=False, n=20), 3.8, 3.8)
    img = L.fill_mask(img, braid, L.GOLD_L, 235)
    for bx in (194, 318):
        btn = S.emask_ellipse(bx, 241, 5, 5)
        img = L.shade(img, btn, L.GOLD_L, L.GOLD_D, 90, 80)
        img = L.outline(img, btn, 0.9, 110)
    # badge
    bd = S.emask_ellipse(256, 243, 13, 14)
    img = S.paint_subject(img, bd, L.GOLD_L, L.GOLD_D, 120, 95, 80, 1.1)
    # peak / visor
    vis = L.shape_mask(L.smooth([(176, 252), (256, 262), (336, 252), (320, 282), (256, 292), (192, 282)], True))
    img = S.paint_subject(img, vis, (74, 64, 60), (8, 8, 12), 150, 95, 30)
    img = L.spec_arc(img, 256, 264, 80, 212, 328, width=2.8, alpha=90, color=(146, 174, 196), blur=1.8)
    img = img.rotate(-7, resample=Image.BICUBIC, center=(256 * L.SS, 232 * L.SS))
    img = Image.alpha_composite(base, img)
    return img


def rank_lifeguard(coin=None):
    img = L.canvas(glow=L.CORAL, glow_a=52)
    img = coin(img) if coin else img
    # splayed tower legs
    for x0, y0, x1, y1 in [(190, 388, 214, 274), (232, 390, 240, 276),
                           (322, 388, 298, 274), (280, 390, 272, 276)]:
        m = L.stroke_mask([(x0, y0), (x1, y1)], 10, 7)
        img = L.shadow(img, m, 2, 4, 4, 80)
        img = L.paint(img, m, L.grad_v([(0, (246, 228, 196)), (1, (152, 126, 92))]))
        img = L.outline(img, m, 1.2, 110)
    for yy in (330, 360):
        b = L.stroke_mask([(200, yy), (240, yy + 2)], 4, 4)
        b2 = L.stroke_mask([(272, yy + 2), (312, yy)], 4, 4)
        for mm in (b, b2):
            img = L.fill_mask(img, mm, (232, 214, 184), 210)
            img = L.outline(img, mm, 0.9, 80)
    # platform
    plat = L.rrect_mask([156, 266, 356, 280], 6)
    img = L.shadow(img, plat, 3, 5, 5, 110)
    img = L.shade(img, plat, (252, 242, 218), (170, 148, 112), 90, 80)
    img = L.outline(img, plat, 1.4, 120)
    # cabin
    cab = L.rrect_mask([206, 208, 306, 268], 8)
    img = L.shadow(img, cab, 3, 5, 5, 110)
    img = L.shade(img, cab, (254, 246, 228), (184, 164, 128), 100, 80)
    img = L.outline(img, cab, 1.5, 125)
    win = L.rrect_mask([222, 220, 290, 250], 6)
    img = L.paint(img, win, L.grad_v([(0, (54, 106, 142)), (1, (8, 26, 42))]))
    img = L.outline(img, win, 1.3, 130)
    img = L.spec_arc(img, 256, 235, 26, 205, 330, width=3, alpha=100, color=(190, 230, 250), blur=2)
    # roof
    roof = L.shape_mask(L.smooth([(186, 208), (256, 176), (326, 208), (320, 216), (256, 190), (192, 216)], True))
    img = S.paint_subject(img, roof, (255, 136, 102), (168, 42, 30), 130, 95, 80)
    # flag pole + flag
    pole = L.stroke_mask([(256, 176), (256, 92)], 4.4, 4.4)
    img = L.fill_mask(img, pole, (232, 220, 196), 235)
    img = L.outline(img, pole, 1.0, 90)
    flag = L.shape_mask(L.smooth([(260, 96), (308, 104), (328, 118), (302, 130), (260, 126)], True))
    img = S.paint_subject(img, flag, (255, 132, 98), (170, 40, 28), 130, 95, 80)
    fm = L.stroke_mask(L.smooth([(264, 112), (302, 116)], closed=False, n=10), 2.2, 2.2)
    img = L.fill_mask(img, fm, (255, 234, 212), 150)
    # waves
    for yy, w, a in [(396, 8, 170), (414, 5, 110)]:
        m = L.stroke_mask(L.smooth([(94, yy), (180, yy - 9), (280, yy + 5), (420, yy - 8)],
                                   closed=False, n=18), w, 2)
        img = L.fill_mask(img, m, L.TEAL, a)
    return img


def first_wildlife(coin=None):
    img = L.canvas(glow=L.TEAL, glow_a=58)
    img = coin(img) if coin else img
    img = S.life_ring(img, 256, 256, 156, 86, band=L.CORAL)
    paw = S.paw_mask(256, 252, 82)
    img = L.shadow(img, paw, 3, 5, 5, 140)
    img = L.shade(img, paw, (252, 244, 224), (186, 170, 136), 95, 100)
    img = L.outline(img, paw, 1.7, 140)
    return img


def first_pet(coin=None):
    img = L.canvas(glow=L.CORAL, glow_a=58)
    img = coin(img) if coin else img
    heart = S.heart_mask(256, 252, 148)
    img = L.shadow(img, heart, 4, 8, 8, 140)
    img = L.shade(img, heart, (255, 140, 108), (168, 40, 32), 100, 95)
    img = L.outline(img, heart, 2.2, 150)
    # gloss
    gl = ImageChops.multiply(heart, L.ellipse_mask([150, 150, 300, 236], blur=14))
    img = L.fill_mask(img, gl, (255, 220, 200), 40)
    paw = S.paw_mask(256, 262, 78)
    img = L.shadow(img, paw, 2, 4, 4, 120)
    img = L.shade(img, paw, (252, 244, 226), (192, 174, 138), 95, 95)
    img = L.outline(img, paw, 1.6, 140)
    return img


def streak7(coin=None):
    img = L.canvas(bg_center=(36, 58, 80), bg_edge=(6, 12, 20), glow=L.AMBER, glow_a=85)
    img = coin(img) if coin else img
    wash = L.ellipse_mask([70, 170, 442, 410], blur=44)
    img = L.fill_mask(img, wash, L.AMBER, 30)
    # hanging wire
    wire = L.stroke_mask(L.smooth([(92, 178), (174, 208), (256, 216), (338, 208), (420, 178)],
                                  closed=False, n=24), 3.2, 3.2)
    img = L.fill_mask(img, wire, (232, 214, 182), 160)
    for i in range(7):
        t = i / 6.0
        x = 140 + 236 * t
        y = 246 + 52 * math.sin(math.pi * t) + (12 if i in (0, 6) else 0)
        r = 25
        img = L.glow(img, L.circle_mask(x, y, r + 12), L.AMBER, 26, 165)
        img = L.fill_mask(img, L.circle_mask(x, y, r + 8), L.AMBER, 40)
        cord = L.stroke_mask([(x, y - 50), (x, y - r + 6)], 2, 2)
        img = L.fill_mask(img, cord, (232, 214, 182), 150)
        # paper body
        body = L.circle_mask(x, y, r)
        img = L.shadow(img, body, 2, 3, 4, 110)
        img = L.paint(img, body, L.grad_radial((255, 236, 168), (226, 132, 34), cx=x, cy=y - 6, r=r))
        # ribs
        for k in (-0.62, -0.22, 0.22, 0.62):
            img = L.spec_arc(img, x, y, r - 1.2, 0, 360, width=1.2, alpha=55,
                             color=(150, 78, 18), blur=0.4, ry=r * 0.99, )
        # easier: vertical ribs as thin ellipse arcs
        for k in (-0.66, -0.22, 0.22, 0.66):
            rx = abs(k) * r
            rm = Image.new("L", (L.PX, L.PX), 0)
            ImageDraw.Draw(rm).ellipse([(x - rx) * L.SS, (y - r) * L.SS,
                                        (x + rx) * L.SS, (y + r) * L.SS],
                                       outline=255, width=int(1.2 * L.SS))
            rm = ImageChops.multiply(rm, body)
            img = L.fill_mask(img, rm, (150, 80, 20), 45)
        # flame core
        img = L.fill_mask(img, L.circle_mask(x, y + 2, r * 0.42), (255, 248, 206), 235)
        img = L.fill_mask(img, L.circle_mask(x, y + 4, r * 0.2), (255, 255, 244), 255)
        # caps + bail
        cap = L.rrect_mask([x - r * 0.5, y - r - 5, x + r * 0.5, y - r + 6], 4)
        img = L.shade(img, cap, (250, 210, 146), (140, 84, 28), 80, 80)
        img = L.outline(img, cap, 1.0, 120)
        base = L.rrect_mask([x - r * 0.5, y + r - 6, x + r * 0.5, y + r + 5], 4)
        img = L.shade(img, base, (250, 210, 146), (140, 84, 28), 80, 80)
        img = L.outline(img, base, 1.0, 120)
        img = L.outline(img, body, 1.4, 130)
    fl = L.ellipse_mask([90, 366, 422, 414], blur=20)
    img = L.fill_mask(img, fl, L.AMBER, 34)
    return img


def great_storm_rescue(coin=None):
    img = L.canvas(bg_center=(28, 44, 64), bg_edge=(3, 8, 16), glow=L.TEAL, glow_a=52)
    img = coin(img) if coin else img
    # everything below is built on one layer and clipped to the coin face, so the rim stays clean
    sc = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    face = L.circle_mask(256, 256, 201)
    # storm cloud over the top
    top = L.ellipse_mask([56, 92, 456, 300], blur=46)
    sc = L.fill_mask(sc, top, (6, 16, 28), 150)
    # rain
    rain = Image.new("L", (L.PX, L.PX), 0)
    rd = ImageDraw.Draw(rain)
    for i in range(34):
        x = 74 + (i * 73) % 360
        y = 84 + (i * 107) % 210
        rd.line([x * L.SS, y * L.SS, (x - 14) * L.SS, (y + 38) * L.SS],
                fill=255, width=int(1.3 * L.SS))
    rain = rain.filter(ImageFilter.GaussianBlur(0.6 * L.SS))
    sc = L.fill_mask(sc, ImageChops.multiply(rain, face), (186, 216, 234), 80)
    # lightning inside the rim
    bolt = L.shape_mask(L.smooth([(352, 128), (318, 190), (342, 192), (306, 252),
                                  (336, 246), (318, 292), (368, 222), (340, 220), (372, 160)], True))
    sc = L.glow(sc, bolt, L.AMBER, 14, 170)
    sc = L.paint(sc, bolt, L.grad_v([(0, (255, 246, 206)), (1, L.AMBER)]))
    sc = L.outline(sc, bolt, 1.4, 100)
    # huge wave sweeping in from the left, crest kept inside the face
    wave = L.shape_mask(L.smooth([(56, 436), (60, 362), (84, 312), (124, 274), (178, 248),
                                  (236, 234), (296, 236), (346, 252), (382, 282), (398, 330),
                                  (398, 436)], True))
    sc = L.paint(sc, wave, L.grad_v([(0, (44, 150, 158)), (0.5, (18, 100, 114)), (1, (6, 40, 56))]))
    sc = L.outline(sc, wave, 1.8, 120)
    lip = L.stroke_mask(L.smooth([(86, 316), (128, 278), (180, 252), (238, 240), (296, 242),
                                  (344, 258), (380, 288)], closed=False, n=30), 9, 5)
    sc = L.fill_mask(sc, lip, (206, 238, 236), 215)
    curl = L.stroke_mask(L.smooth([(96, 344), (118, 316), (152, 300)], closed=False, n=14), 5, 2)
    sc = L.fill_mask(sc, curl, (188, 228, 230), 140)
    # boat on the crest, heeled to the swell
    boat = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    hull = L.shape_mask(L.smooth([(196, 266), (232, 256), (270, 252), (308, 254), (346, 262),
                                  (336, 280), (306, 292), (262, 296), (222, 290), (200, 278)], True))
    boat = S.paint_subject(boat, hull, (255, 146, 104), (168, 44, 30), 160, 100, 88, 1.8)
    gun = ImageChops.multiply(hull, L.rrect_mask([194, 258, 346, 269], 5))
    boat = L.fill_mask(boat, gun, (252, 242, 220), 240)
    keel = ImageChops.multiply(hull, L.rrect_mask([200, 280, 340, 296], 10))
    boat = L.fill_mask(boat, keel, (120, 30, 22), 90)
    cab = L.shape_mask(L.smooth([(236, 224), (250, 220), (278, 220), (290, 224),
                                 (294, 252), (270, 255), (244, 255), (230, 252), (230, 228)], True))
    boat = S.paint_subject(boat, cab, (252, 244, 228), (178, 158, 122), 140, 90, 80, 1.6)
    for wx in (242, 266):
        wnd = L.rrect_mask([wx, 228, wx + 16, 242], 3)
        boat = L.paint(boat, wnd, L.grad_v([(0, (162, 220, 232)), (1, (26, 72, 92))]))
        boat = L.outline(boat, wnd, 1.2, 120)
    mast = L.stroke_mask([(262, 220), (262, 206)], 3, 3)
    boat = L.fill_mask(boat, mast, (238, 232, 214), 240)
    bar = L.stroke_mask([(250, 206), (274, 206)], 3, 3)
    boat = L.fill_mask(boat, bar, (238, 232, 214), 240)
    boat = boat.rotate(16, resample=Image.BICUBIC, center=(262 * L.SS, 294 * L.SS))
    sc = Image.alpha_composite(sc, boat)
    # spray at the hull
    for pts, w0, w1, al in [([(322, 274), (352, 256), (374, 258)], 7, 2, 210),
                            ([(334, 288), (364, 282)], 5, 1.5, 160)]:
        sp = L.stroke_mask(L.smooth(pts, closed=False, n=10), w0, w1)
        sc = L.fill_mask(sc, sp, (236, 250, 250), al)
    # foreground water over the hull so the boat sits in the sea
    fore = L.shape_mask(L.smooth([(56, 436), (60, 402), (120, 388), (196, 382), (286, 376),
                                  (360, 366), (398, 358), (398, 436)], True))
    sc = L.paint(sc, fore, L.grad_v([(0, (48, 152, 162)), (0.45, (18, 96, 110)), (1, (5, 36, 52))]))
    ff = L.stroke_mask(L.smooth([(62, 404), (124, 390), (200, 384), (288, 378), (362, 368), (394, 361)],
                                closed=False, n=28), 8, 2.5)
    sc = L.fill_mask(sc, ff, (206, 240, 238), 205)
    for pts, w, a in [([(150, 404), (240, 396), (330, 388)], 4, 120),
                      ([(206, 416), (300, 410), (368, 402)], 3, 100)]:
        m = L.stroke_mask(L.smooth(pts, closed=False, n=16), w, 1.5)
        sc = L.fill_mask(sc, m, (176, 226, 228), a)
    img = Image.alpha_composite(img, face_clip(sc))
    return img


# ------------------------------------------------------------ round 2 badges
def downwind(coin=None):
    img = coin_base(L.GOLD, 58, coin)
    wake = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    band = L.stroke_mask(L.smooth([(370, 318), (300, 338), (218, 354), (130, 368), (88, 382)],
                                  closed=False, n=26), 44, 10)
    wake = L.glow(wake, band, L.GOLD, 18, 90)
    wake = L.paint(wake, band, L.grad_v([(0, (255, 244, 190)), (0.5, L.GOLD), (1, (202, 130, 28))]))
    wake = L.outline(wake, band, 1.4, 110)
    hl = L.stroke_mask(L.smooth([(356, 304), (280, 322), (196, 338), (120, 352)],
                                closed=False, n=22), 8, 2)
    wake = L.fill_mask(wake, hl, (255, 250, 226), 200)
    img = Image.alpha_composite(img, face_clip(wake))
    # hull, bow to the right
    hull = L.shape_mask(L.smooth([(170, 304), (244, 294), (320, 282), (368, 268), (392, 282),
                                  (388, 314), (356, 336), (274, 344), (198, 338), (174, 322)], True))
    img = S.paint_subject(img, hull, (255, 150, 110), (164, 42, 30), 155, 100, 85, 2.2)
    gun = L.stroke_mask(L.smooth([(174, 306), (248, 296), (322, 284), (370, 270)], closed=False, n=24),
                        13, 9)
    img = L.fill_mask(img, gun, (250, 240, 216), 250)
    img = L.outline(img, gun, 1.1, 100)
    cab = L.shape_mask(L.smooth([(234, 248), (250, 240), (312, 232), (330, 236), (334, 268),
                                 (310, 292), (246, 296), (232, 280)], True))
    img = S.paint_subject(img, cab, (254, 248, 234), (182, 164, 132), 145, 95, 80, 1.9)
    roof = L.stroke_mask(L.smooth([(240, 250), (284, 242), (326, 236)], closed=False, n=14), 11, 8)
    img = L.fill_mask(img, roof, (255, 252, 238), 240)
    img = L.outline(img, roof, 1.0, 90)
    for wx, wy in [(250, 258), (286, 252)]:
        wnd = L.rrect_mask([wx, wy, wx + 26, wy + 22], 5)
        img = L.paint(img, wnd, L.grad_v([(0, (164, 222, 232)), (1, (22, 62, 82))]))
        img = L.outline(img, wnd, 1.2, 120)
    for pts, w0, w1, al in [([(390, 306), (418, 292), (436, 296)], 8, 2, 220),
                            ([(386, 322), (414, 320)], 6, 1.5, 180)]:
        sp = L.stroke_mask(L.smooth(pts, closed=False, n=10), w0, w1)
        img = L.fill_mask(img, sp, (255, 250, 232), al)
    wl = L.stroke_mask(L.smooth([(96, 356), (200, 352), (300, 348), (400, 340)], closed=False, n=20),
                       5, 2)
    img = L.fill_mask(img, wl, L.TEAL, 150)
    return img
def tow_truck(coin=None):
    img = coin_base(L.TEAL, 48, coin)
    # deck planks, clipped to the face
    deck = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    planks = L.shape_mask(L.smooth([(104, 392), (408, 392), (446, 456), (66, 456)], True))
    deck = L.paint(deck, planks, L.grad_v([(0, (200, 146, 94)), (1, (96, 62, 34))]))
    for yy in (406, 422, 438):
        m = L.stroke_mask([(100, yy), (412, yy - 2)], 2.4, 2.4)
        deck = L.fill_mask(deck, m, (112, 72, 40), 110)
    deck = L.outline(deck, planks, 1.6, 140)
    img = Image.alpha_composite(img, face_clip(deck))
    # taut rope leading up out of the frame
    rope = L.stroke_mask(L.smooth([(266, 314), (300, 268), (336, 218), (356, 168), (366, 132)],
                                  closed=False, n=24), 14, 11)
    img = L.shadow(img, rope, 3, 5, 5, 110)
    img = L.fill_mask(img, rope, (242, 228, 200), 255)
    img = L.outline(img, rope, 1.3, 120)
    for k in range(9):
        t = k / 8.0
        x = 266 + 100 * t - 4 * math.sin(math.pi * t)
        y = 314 - 182 * t
        m = L.stroke_mask([(x - 10, y + 4), (x + 10, y - 6)], 2.2, 2.2)
        img = L.fill_mask(img, m, (188, 168, 134), 120)
    # cleat
    base = L.rrect_mask([186, 310, 326, 336], 10)
    img = S.paint_subject(img, base, (240, 218, 178), (128, 92, 54), 130, 95, 85, 1.8)
    for s in (-1, 1):
        horn = L.stroke_mask(L.smooth([(256 + s * 8, 320), (256 + s * 52, 318), (256 + s * 64, 296),
                                       (256 + s * 54, 274), (256 + s * 36, 272)], closed=False, n=18),
                             24, 13)
        img = S.paint_subject(img, horn, (252, 230, 192), (138, 98, 56), 135, 95, 85, 1.7)
    # rope turns around the cleat
    loop = L.stroke_mask(L.arc_pts(256, 304, 34, 200, 340, n=24), 8, 6)
    img = L.fill_mask(img, loop, (240, 226, 196), 230)
    img = L.outline(img, loop, 1.0, 100)
    return img


def storm_chaser(coin=None):
    img = coin_base(L.CORAL, 55, coin)
    sc = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    wave = L.shape_mask(L.smooth([(64, 448), (64, 356), (78, 314), (112, 276), (158, 252),
                                  (212, 242), (250, 228), (278, 204), (294, 172), (312, 196),
                                  (330, 226), (350, 264), (364, 316), (370, 384), (372, 448)], True))
    sc = L.paint(sc, wave, L.grad_v([(0, (56, 176, 178)), (0.48, (20, 112, 122)), (1, (6, 42, 58))]))
    sc = L.outline(sc, wave, 1.8, 120)
    lip = L.stroke_mask(L.smooth([(84, 318), (116, 286), (162, 260), (214, 248), (252, 234),
                                  (280, 210), (294, 180)], closed=False, n=26), 10, 6)
    sc = L.fill_mask(sc, lip, (216, 244, 240), 225)
    for pts, w, a in [([(120, 340), (170, 300), (230, 280), (282, 250)], 4, 120),
                      ([(190, 360), (250, 330), (310, 292)], 3, 100)]:
        m = L.stroke_mask(L.smooth(pts, closed=False, n=16), w, 1.5)
        sc = L.fill_mask(sc, m, (176, 226, 228), a)
    img = Image.alpha_composite(img, face_clip(sc))
    # boat riding up the face, bow high
    boat = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    hull = L.shape_mask(L.smooth([(176, 314), (214, 302), (258, 296), (302, 300), (344, 312),
                                  (334, 332), (300, 346), (252, 350), (208, 342), (182, 326)], True))
    boat = S.paint_subject(boat, hull, (255, 146, 104), (168, 44, 30), 160, 100, 88, 1.8)
    gun = ImageChops.multiply(hull, L.rrect_mask([174, 304, 344, 316], 5))
    boat = L.fill_mask(boat, gun, (252, 242, 220), 240)
    cab = L.shape_mask(L.smooth([(218, 272), (232, 268), (262, 268), (274, 272),
                                 (278, 300), (254, 304), (228, 304), (214, 300), (212, 276)], True))
    boat = S.paint_subject(boat, cab, (252, 244, 228), (178, 158, 122), 140, 90, 80, 1.6)
    wnd = L.rrect_mask([226, 278, 264, 292], 4)
    boat = L.paint(boat, wnd, L.grad_v([(0, (162, 220, 232)), (1, (26, 72, 92))]))
    boat = L.outline(boat, wnd, 1.3, 120)
    mast = L.stroke_mask([(244, 268), (244, 246)], 3, 3)
    boat = L.fill_mask(boat, mast, (238, 232, 214), 240)
    boat = boat.rotate(22, resample=Image.BICUBIC, center=(258 * L.SS, 320 * L.SS))
    img = Image.alpha_composite(img, boat)
    for pts, w0, w1, al in [([(300, 188), (322, 170), (344, 176)], 7, 2, 210),
                            ([(292, 212), (312, 200)], 5, 1.5, 160),
                            ([(346, 292), (372, 286)], 6, 2, 170)]:
        sp = L.stroke_mask(L.smooth(pts, closed=False, n=10), w0, w1)
        img = L.fill_mask(img, sp, (236, 250, 250), al)
    return img
def fin(img, base, tip, w0=66, w1=40):
    axis = math.atan2(tip[1] - base[1], tip[0] - base[0])
    pts = L.smooth([base, ((base[0] + tip[0]) / 2 + 8, (base[1] + tip[1]) / 2 + 8), tip],
                   closed=False, n=20)
    blade = L.stroke_mask(pts, w0, w1)
    img = L.shadow(img, blade, 4, 6, 5, 120)
    img = L.shade(img, blade, (255, 238, 182), (206, 138, 32), 110, 90)
    img = L.outline(img, blade, 1.9, 145)
    ridge = L.stroke_mask([base, ((base[0] + tip[0]) / 2, (base[1] + tip[1]) / 2), tip], 3, 1.4)
    img = L.fill_mask(img, ridge, (255, 250, 226), 150)
    # strap across the foot pocket
    cx = base[0] + math.cos(axis) * 22
    cy = base[1] + math.sin(axis) * 22
    strap = L.stroke_mask([(cx - math.sin(axis) * 30, cy + math.cos(axis) * 30),
                           (cx + math.sin(axis) * 30, cy - math.cos(axis) * 30)], 13, 13)
    img = L.shade(img, strap, L.TEAL, L.TEAL_D, 80, 90)
    img = L.outline(img, strap, 1.2, 130)
    return img


def rank_rescue_swimmer(coin=None):
    img = coin_base(L.AMBER, 52, coin)
    img = fin(img, (196, 362), (334, 170))
    img = fin(img, (318, 362), (178, 166))
    for x, y, r in [(150, 260, 5), (140, 290, 3), (366, 250, 4), (376, 286, 3)]:
        img = L.fill_mask(img, L.ring_mask(x, y, r, max(1, r - 2.2)), L.CREAM, 120)
    return img


def ferry_hero(coin=None):
    img = coin_base(L.CORAL, 55, coin)
    img = S.life_ring(img, 256, 324, 128, 72, band=L.CORAL)
    # ferry side-on above the ring
    hull = L.shape_mask(L.smooth([(136, 198), (376, 198), (366, 232), (152, 232)], True))
    img = S.paint_subject(img, hull, (255, 250, 238), (188, 172, 140), 150, 100, 80, 1.9)
    strip = ImageChops.multiply(hull, L.rrect_mask([138, 214, 374, 226], 5))
    img = L.fill_mask(img, strip, L.CORAL, 245)
    img = L.outline(img, strip, 1.0, 90)
    house = L.shape_mask(L.smooth([(168, 152), (334, 152), (330, 200), (172, 200)], True))
    img = S.paint_subject(img, house, (254, 248, 234), (186, 168, 138), 145, 95, 80, 1.8)
    for wx in (188, 216, 244, 272):
        wnd = L.rrect_mask([wx, 164, wx + 20, 184], 4)
        img = L.paint(img, wnd, L.grad_v([(0, (150, 208, 220)), (1, (22, 64, 84))]))
        img = L.outline(img, wnd, 1.1, 120)
    funnel = L.shape_mask(L.smooth([(298, 120), (322, 120), (318, 156), (302, 156)], True))
    img = S.paint_subject(img, funnel, (255, 132, 96), (164, 42, 30), 140, 95, 85, 1.7)
    cap = L.rrect_mask([296, 116, 326, 128], 4)
    img = L.fill_mask(img, cap, (250, 236, 208), 245)
    img = L.outline(img, cap, 1.0, 100)
    return img


def air_pocket(coin=None):
    img = coin_base(L.TEAL, 62, coin)
    pocket = L.ellipse_mask([136, 92, 376, 276], blur=32)
    img = L.fill_mask(img, pocket, (150, 224, 226), 66)
    img = L.spec_arc(img, 256, 196, 96, 200, 340, width=5, alpha=90, color=(220, 250, 248), blur=6)
    # bubbles
    for x, y, r in [(150, 300, 8), (136, 258, 5), (176, 214, 4), (360, 292, 7), (344, 244, 4)]:
        img = L.fill_mask(img, L.ring_mask(x, y, r, max(1, r - 2.4)), (206, 240, 238), 150)
    # arm and hand reaching up, clipped to the face so the rim stays clean
    hand = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    arm = L.stroke_mask(L.smooth([(258, 452), (250, 386), (252, 330)], closed=False, n=16), 56, 46)
    hand = L.shadow(hand, arm, 4, 6, 6, 110)
    hand = L.shade(hand, arm, (252, 238, 208), (168, 146, 106), 115, 90)
    hand = L.outline(hand, arm, 1.8, 130)
    palm = S.emask_ellipse(256, 286, 48, 54, rot=0.06)
    hand = L.shadow(hand, palm, 3, 5, 5, 100)
    hand = L.shade(hand, palm, (252, 238, 208), (168, 146, 106), 120, 90)
    hand = L.outline(hand, palm, 1.8, 130)
    for x, y0, y1 in [(220, 262, 176), (242, 256, 162), (266, 256, 158), (288, 262, 178)]:
        f = L.stroke_mask([(x, y0), (x - 2, y1)], 20, 17)
        hand = L.shadow(hand, f, 3, 4, 4, 90)
        hand = L.shade(hand, f, (252, 238, 208), (168, 146, 106), 120, 85)
        hand = L.outline(hand, f, 1.6, 130)
    thumb = L.stroke_mask([(218, 308), (196, 288), (190, 266)], 24, 18)
    hand = L.shadow(hand, thumb, 3, 4, 4, 90)
    hand = L.shade(hand, thumb, (252, 238, 208), (168, 146, 106), 118, 85)
    hand = L.outline(hand, thumb, 1.7, 130)
    img = Image.alpha_composite(img, face_clip(hand))
    # wrist bubbles
    for x, y, r in [(306, 360, 6), (200, 344, 5), (316, 402, 4)]:
        img = L.fill_mask(img, L.circle_mask(x, y, r), (214, 244, 242), 130)
    return img


def first_wreck(coin=None):
    img = coin_base(L.TEAL, 50, coin)
    sc = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    wave = L.shape_mask(L.smooth([(48, 342), (52, 284), (72, 238), (106, 204), (152, 184),
                                  (202, 176), (252, 182), (296, 198), (326, 220), (342, 244),
                                  (338, 268), (318, 270), (306, 252), (294, 258), (304, 278),
                                  (322, 292), (342, 306), (356, 322), (356, 342)], True))
    sc = L.paint(sc, wave, L.grad_v([(0, (58, 184, 186)), (0.5, (22, 112, 122)), (1, (8, 52, 68))]))
    sc = L.outline(sc, wave, 1.8, 120)
    lip = L.stroke_mask(L.smooth([(54, 288), (74, 242), (108, 208), (154, 188), (204, 180),
                                  (254, 186), (298, 202), (328, 224), (342, 246), (338, 266),
                                  (322, 268), (312, 256)], closed=False, n=30), 11, 5)
    sc = L.fill_mask(sc, lip, (214, 244, 240), 230)
    curl = L.stroke_mask(L.smooth([(62, 316), (70, 286), (88, 264)], closed=False, n=12), 6, 3)
    sc = L.fill_mask(sc, curl, (196, 232, 232), 150)
    for pts, w0, w1, al in [([(300, 170), (322, 156), (344, 160)], 6, 2, 220),
                            ([(330, 190), (352, 182)], 5, 1.5, 170),
                            ([(150, 300), (222, 286), (296, 292)], 4, 1.5, 110)]:
        m = L.stroke_mask(L.smooth(pts, closed=False, n=12), w0, w1)
        sc = L.fill_mask(sc, m, (206, 238, 236), al)
    img = Image.alpha_composite(img, face_clip(sc))
    # sandy seabed strip
    bed = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    bm = L.ellipse_mask([86, 396, 426, 470], blur=7)
    bed = L.fill_mask(bed, bm, (150, 130, 92), 255)
    bed = L.outline(bed, L.ellipse_mask([98, 404, 412, 462]), 1.4, 80, (98, 82, 56))
    img = Image.alpha_composite(img, face_clip(bed))
    # wreck hull with ribs, broken mast and bowsprit
    wreck = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    hm = L.shape_mask(L.smooth([(110, 404), (118, 366), (148, 344), (200, 336), (258, 340),
                                (316, 352), (350, 372), (360, 400), (336, 416), (150, 416)], True))
    wreck = L.shadow(wreck, hm, 4, 7, 6, 130)
    wreck = L.paint(wreck, hm, L.grad_v([(0, (186, 136, 84)), (0.6, (128, 88, 50)), (1, (66, 44, 26))]))
    wreck = L.outline(wreck, hm, 2.0, 145)
    deckl = ImageChops.multiply(hm, L.rrect_mask([118, 338, 356, 366], 8))
    wreck = L.fill_mask(wreck, deckl, (198, 148, 94), 180)
    hole = S.emask_ellipse(262, 384, 17, 12, -0.05)
    wreck = L.fill_mask(wreck, hole, (18, 12, 8), 235)
    wreck = L.outline(wreck, hole, 1.4, 160)
    for k in range(4):
        x = 158 + k * 48
        rib = L.stroke_mask([(x, 352 + abs(k - 1.5) * 4), (x - 4, 320 + abs(k - 1.5) * 8)], 10, 6)
        wreck = L.shade(wreck, rib, (176, 126, 76), (72, 46, 26), 90, 90)
        wreck = L.outline(wreck, rib, 1.1, 130)
    bowsprit = L.stroke_mask([(126, 362), (94, 330)], 10, 5)
    wreck = L.shade(wreck, bowsprit, (180, 128, 78), (74, 48, 28), 90, 90)
    wreck = L.outline(wreck, bowsprit, 1.1, 130)
    mast = L.stroke_mask([(298, 354), (338, 264)], 14, 8)
    wreck = L.shade(wreck, mast, (184, 134, 82), (74, 48, 28), 90, 90)
    wreck = L.outline(wreck, mast, 1.2, 140)
    spar = L.stroke_mask([(318, 298), (372, 284)], 8, 5)
    wreck = L.shade(wreck, spar, (176, 126, 76), (74, 48, 28), 85, 85)
    wreck = L.outline(wreck, spar, 1.0, 130)
    # tattered sail hanging from the spar
    sail = L.shape_mask(L.smooth([(324, 292), (364, 286), (356, 336), (340, 320), (330, 340),
                                  (320, 318), (326, 302)], True))
    wreck = L.fill_mask(wreck, sail, (206, 198, 176), 215)
    wreck = L.outline(wreck, sail, 1.3, 130)
    for k in range(3):
        rip = L.stroke_mask([(322 + k * 12, 330 + k * 2), (330 + k * 12, 306 + k * 3)], 2.2, 1.4)
        wreck = L.fill_mask(wreck, rip, (120, 100, 74), 110)
    img = Image.alpha_composite(img, wreck)
    return img
def all_wildlife(coin=None):
    img = coin_base(L.TEAL, 58, coin)
    img = S.life_ring(img, 256, 262, 84, 48, band=L.CORAL)
    cx, cy = 256, 262

    def sil(m, oa=130):
        img2 = L.shadow(img, m, 2, 3, 4, 100)
        img2 = L.shade(img2, m, (252, 246, 228), (176, 162, 130), 90, 85)
        return L.outline(img2, m, 1.4, oa)

    # gull, top
    g = L.stroke_mask([(198, 132), (230, 110), (256, 118), (282, 110), (314, 132)], 8, 5)
    g = ImageChops.lighter(g, S.emask_ellipse(256, 126, 13, 10))
    img = sil(g)
    # puffin, upper right
    p = S.emask_ellipse(392, 214, 16, 24, -0.2)
    p = ImageChops.lighter(p, S.emask_ellipse(398, 188, 13, 13))
    img = sil(p)
    beak = L.shape_mask(L.smooth([(406, 184), (428, 194), (406, 200)], True))
    img = L.fill_mask(img, beak, L.AMBER, 245)
    img = L.outline(img, beak, 1.0, 110)
    # seal, lower right
    s2 = S.emask_ellipse(348, 384, 28, 14, 0.15)
    s2 = ImageChops.lighter(s2, S.emask_ellipse(372, 372, 11, 10))
    tail = L.shape_mask(L.smooth([(322, 382), (300, 370), (306, 392), (322, 394)], True))
    img = sil(ImageChops.lighter(s2, tail))
    # turtle, lower left
    t = S.emask_ellipse(176, 384, 26, 19, -0.1)
    t = ImageChops.lighter(t, S.emask_ellipse(200, 374, 9, 8))
    for dx, dy in [(-20, -12), (-8, -18), (8, -18), (20, -12), (-20, 12), (20, 12)]:
        t = ImageChops.lighter(t, S.emask_ellipse(176 + dx, 384 + dy, 9, 5, 0.4))
    img = sil(t)
    # otter, upper left
    o = S.emask_ellipse(122, 222, 17, 20)
    o = ImageChops.lighter(o, S.emask_ellipse(110, 202, 7, 7))
    o = ImageChops.lighter(o, S.emask_ellipse(134, 202, 7, 7))
    img = sil(o)
    return img


def legendary_rescue(coin=None):
    img = coin_base(L.GOLD, 66, coin, rim_top=(255, 248, 222), rim_mid=(250, 196, 86),
                    rim_bot=(126, 72, 12))
    img = rich_rim(img)
    star = star_mask(256, 208, 126, 52)
    img = L.glow(img, star, L.AMBER, 24, 80, grow=2)
    img = L.shade(img, star, (255, 248, 214), L.GOLD, 115, 90)
    img = L.outline(img, star, 2.2, 150)
    for x, y, r in [(120, 150, 10), (390, 168, 8), (382, 120, 5)]:
        img = L.fill_mask(img, star_mask(x, y, r, r * 0.38), (255, 250, 228), 220)
    # rescue boat below
    hull = L.shape_mask(L.smooth([(146, 350), (176, 338), (238, 332), (300, 336), (344, 326),
                                  (362, 338), (350, 372), (304, 388), (206, 388), (158, 370)], True))
    img = S.paint_subject(img, hull, (255, 148, 106), (164, 42, 30), 160, 100, 85, 2.0)
    sheer = L.stroke_mask(L.smooth([(152, 352), (182, 340), (240, 334), (300, 338), (342, 328)],
                                   closed=False, n=22), 11, 7)
    img = L.fill_mask(img, sheer, (252, 242, 220), 245)
    img = L.outline(img, sheer, 1.1, 100)
    cab = L.rrect_mask([218, 302, 292, 334], 7)
    img = S.paint_subject(img, cab, (254, 248, 234), (182, 162, 128), 140, 95, 80, 1.7)
    wnd = L.rrect_mask([230, 310, 280, 324], 4)
    img = L.paint(img, wnd, L.grad_v([(0, (156, 214, 226)), (1, (22, 66, 86))]))
    img = L.outline(img, wnd, 1.2, 120)
    return img


def golden_gull(coin=None):
    img = coin_base(L.AMBER, 70, coin, rim_top=(255, 250, 226), rim_mid=(252, 202, 94),
                    rim_bot=(130, 76, 14))
    img = rich_rim(img)
    halo = L.ellipse_mask([92, 104, 420, 432], blur=40)
    img = L.fill_mask(img, halo, L.AMBER, 46)
    for s in (-1, 1):
        wing = L.stroke_mask(L.smooth([(256, 302), (256 + s * 62, 262), (256 + s * 122, 226),
                                       (256 + s * 162, 202)], closed=False, n=26), 62, 16)
        img = L.shadow(img, wing, 4, 7, 6, 110)
        img = L.shade(img, wing, (255, 240, 174), (206, 136, 28), 120, 95)
        img = L.outline(img, wing, 2.0, 150)
        edge = L.stroke_mask(L.smooth([(262, 292), (256 + s * 76, 246), (256 + s * 140, 210)],
                                      closed=False, n=18), 7, 2)
        img = L.fill_mask(img, edge, (255, 250, 220), 165)
        for k in range(2):
            sx = 256 + s * (126 + k * 16)
            sy = 226 + k * 12
            slit = L.stroke_mask([(sx, sy), (sx + s * 34, sy + 18)], 4, 2)
            img = L.fill_mask(img, slit, (150, 92, 20), 150)
    body = S.emask_ellipse(256, 310, 30, 62)
    img = L.shadow(img, body, 3, 6, 5, 110)
    img = L.shade(img, body, (255, 244, 194), (208, 140, 30), 115, 90)
    img = L.outline(img, body, 2.0, 150)
    tail = L.shape_mask(L.smooth([(236, 354), (256, 398), (276, 354), (256, 366)], True))
    img = L.shade(img, tail, (250, 226, 158), (188, 118, 24), 90, 80)
    img = L.outline(img, tail, 1.6, 140)
    head = S.emask_ellipse(256, 238, 32, 31)
    img = L.shade(img, head, (255, 246, 202), (214, 148, 36), 115, 85)
    img = L.outline(img, head, 1.8, 145)
    beak = L.shape_mask(L.smooth([(282, 230), (330, 242), (284, 256)], True))
    img = S.paint_subject(img, beak, (255, 164, 96), (186, 78, 28), 125, 95, 80, 1.5)
    eye = L.circle_mask(268, 230, 4.6)
    img = L.fill_mask(img, eye, (40, 26, 10), 235)
    img = L.fill_mask(img, L.circle_mask(267, 229, 1.7), (255, 250, 230), 205)
    return img
def album_set(coin=None):
    img = coin_base(L.CORAL, 52, coin)
    page = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    pm = L.rrect_mask([160, 142, 352, 382], 16)
    page = L.shadow(page, pm, 5, 8, 8, 130)
    page = L.paint(page, pm, L.grad_v([(0, (252, 246, 230)), (1, (210, 194, 160))]))
    page = L.outline(page, pm, 2.0, 130)
    head = ImageChops.multiply(pm, L.rrect_mask([160, 142, 352, 190], 16))
    page = L.fill_mask(page, head, (255, 130, 96), 230)
    page = L.fill_mask(page, L.rrect_mask([186, 154, 260, 164], 4), (255, 240, 218), 200)
    cols = [(L.TEAL, 190), (L.AMBER, 256), (L.CORAL_D, 322)]
    for r, yy in enumerate((222, 288)):
        for c, (col, xx) in enumerate(cols):
            gold = (r == 0 and c == 2)
            tm = L.rrect_mask([xx - 26, yy - 26, xx + 26, yy + 26], 8)
            page = L.shadow(page, tm, 2, 4, 4, 90)
            if gold:
                page = L.glow(page, tm, L.AMBER, 10, 90)
                page = L.paint(page, tm, L.grad_v([(0, (255, 246, 200)), (0.5, L.GOLD),
                                                   (1, (158, 100, 26))]))
            else:
                page = L.paint(page, tm, L.grad_v([(0, (255, 255, 255)), (1, col)]))
            page = L.outline(page, tm, 1.3, 120)
            if gold:
                g = L.ring_mask(xx, yy, 36, 28)
                page = L.paint(page, g, L.grad_v([(0, (255, 250, 224)), (1, (206, 144, 42))]))
                page = L.outline(page, g, 1.4, 150)
                star = star_mask(xx, yy, 20, 9)
                page = L.paint(page, star, L.grad_v([(0, (255, 252, 230)), (1, L.GOLD)]))
                page = L.outline(page, star, 1.2, 140)
    page = page.rotate(-6, resample=Image.BICUBIC, center=(256 * L.SS, 262 * L.SS))
    img = Image.alpha_composite(img, page)
    return img
def album_complete(coin=None):
    img = coin_base(L.GOLD, 55, coin)
    book = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    pages = L.rrect_mask([286, 168, 372, 384], 10)
    book = L.shadow(book, pages, 4, 6, 6, 110)
    book = L.shade(book, pages, (252, 246, 230), (198, 182, 150), 85, 80)
    book = L.outline(book, pages, 1.5, 120)
    for yy in (210, 270, 330):
        book = L.fill_mask(book, L.stroke_mask([(298, yy), (362, yy - 2)], 2.4, 2.4), (156, 138, 106), 130)
    cover = L.rrect_mask([136, 160, 344, 392], 16)
    book = L.shadow(book, cover, 6, 9, 8, 140)
    book = L.paint(book, cover, L.grad_v([(0, (255, 140, 104)), (0.55, L.CORAL), (1, (148, 40, 30))]))
    book = L.outline(book, cover, 2.2, 150)
    inner = L.rrect_mask([150, 174, 330, 378], 11)
    book = L.outline(book, inner, 1.4, 90, (255, 214, 150))
    # gold clasp strap across the fore edge
    strap = L.rrect_mask([296, 160, 330, 392], 6)
    book = L.paint(book, strap, L.grad_v([(0, (255, 244, 196)), (0.5, L.GOLD), (1, (146, 90, 20))]))
    book = L.outline(book, strap, 1.6, 140)
    buckle = L.rrect_mask([286, 258, 340, 306], 8)
    book = L.shade(book, buckle, (255, 246, 208), L.GOLD, 100, 90)
    book = L.outline(book, buckle, 1.6, 150)
    key = L.ring_mask(313, 282, 8, 3)
    book = L.fill_mask(book, key, (120, 78, 20), 200)
    # small gull mark on the cover
    gm = L.stroke_mask([(190, 244), (216, 226), (242, 244)], 9, 4)
    book = L.fill_mask(book, gm, (255, 238, 196), 220)
    book = L.outline(book, gm, 1.0, 80)
    book = book.rotate(-4, resample=Image.BICUBIC, center=(250 * L.SS, 276 * L.SS))
    img = Image.alpha_composite(img, book)
    return img


def streak30(coin=None):
    img = coin_base(L.AMBER, 62, coin)
    wash = L.ellipse_mask([84, 168, 428, 424], blur=44)
    img = L.fill_mask(img, wash, L.AMBER, 28)
    page = L.rrect_mask([168, 146, 344, 392], 14)
    img = L.shadow(img, page, 5, 8, 8, 130)
    img = L.paint(img, page, L.grad_v([(0, (252, 246, 230)), (1, (206, 190, 156))]))
    img = L.outline(img, page, 2.0, 130)
    head = ImageChops.multiply(page, L.rrect_mask([168, 146, 344, 206], 14))
    img = L.fill_mask(img, head, (255, 128, 92), 235)
    img = L.fill_mask(img, ImageChops.multiply(head, L.ellipse_mask([168, 178, 344, 244], blur=10)),
                      (255, 172, 132), 90)
    for x in (216, 296):
        r = L.ring_mask(x, 150, 11, 5)
        img = L.paint(img, r, L.grad_v([(0, (255, 246, 210)), (1, (156, 100, 34))]))
        img = L.outline(img, r, 1.1, 130)
    dots = Image.new("L", (L.PX, L.PX), 0)
    dd = ImageDraw.Draw(dots)
    for r in range(6):
        for c in range(5):
            x, y = 200 + c * 28, 238 + r * 25
            img = L.fill_mask(img, L.circle_mask(x, y, 11), L.AMBER, 26)
            dd.ellipse([(x - 6) * L.SS, (y - 6) * L.SS, (x + 6) * L.SS, (y + 6) * L.SS], fill=255)
    img = L.glow(img, dots, L.AMBER, 8, 60)
    img = L.paint(img, dots, L.grad_v([(0, (255, 240, 170)), (1, (226, 138, 36))]))
    img = L.spec_arc(img, 256, 268, 90, 195, 310, width=3, alpha=60, color=(255, 240, 200), blur=4)
    return img


def ghost_ship(coin=None):
    img = coin_base(L.TEAL, 62, coin)
    fog = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    for y, a in [(200, 38), (292, 34)]:
        m = L.ellipse_mask([54, y, 458, y + 92], blur=26)
        fog = L.fill_mask(fog, m, (168, 220, 214), a)
    img = Image.alpha_composite(img, face_clip(fog))
    gh = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    hull = L.shape_mask(L.smooth([(128, 292), (184, 278), (250, 272), (318, 276), (372, 290),
                                  (360, 326), (316, 344), (240, 350), (164, 340), (134, 318)], True))
    gh = L.glow(gh, hull, L.TEAL, 24, 150)
    gh = L.shade(gh, hull, (222, 252, 224), (54, 176, 152), 85, 80)
    gh = L.fill_mask(gh, hull, L.TEAL_D, 55)
    gh = L.outline(gh, hull, 2.0, 120, (206, 252, 230))
    house = L.shape_mask(L.smooth([(178, 220), (244, 210), (324, 218), (338, 232),
                                   (344, 276), (300, 286), (206, 286), (172, 270)], True))
    gh = L.glow(gh, house, L.TEAL, 18, 140)
    gh = L.shade(gh, house, (230, 254, 232), (82, 192, 168), 90, 80)
    gh = L.outline(gh, house, 1.8, 120, (212, 254, 234))
    for wx in (194, 226, 258, 290):
        wnd = L.rrect_mask([wx, 240, wx + 20, 262], 4)
        gh = L.fill_mask(gh, wnd, (238, 255, 242), 250)
        gh = L.glow(gh, wnd, (140, 255, 210), 9, 150)
    funnel = L.shape_mask(L.smooth([(296, 172), (322, 172), (318, 214), (300, 214)], True))
    gh = L.shade(gh, funnel, (220, 250, 226), (64, 168, 146), 85, 80)
    gh = L.outline(gh, funnel, 1.6, 110, (202, 248, 226))
    gh = L.fill_mask(gh, L.rrect_mask([294, 166, 324, 178], 4), (238, 255, 238), 245)
    mast = L.stroke_mask([(262, 220), (262, 190)], 3.4, 3.4)
    gh = L.fill_mask(gh, mast, (210, 250, 226), 240)
    gh = L.glow(gh, L.circle_mask(262, 186, 5), (190, 255, 216), 10, 200)
    trail = L.stroke_mask(L.smooth([(174, 348), (240, 364), (320, 354)], closed=False, n=16), 22, 8)
    trail = trail.filter(ImageFilter.GaussianBlur(7 * L.SS))
    gh = L.fill_mask(gh, trail, (150, 236, 208), 80)
    img = Image.alpha_composite(img, gh)
    fog2 = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    for y, a in [(214, 24), (330, 34), (388, 30)]:
        m = L.ellipse_mask([40, y, 472, y + 80], blur=20)
        fog2 = L.fill_mask(fog2, m, (188, 230, 222), a)
    img = Image.alpha_composite(img, face_clip(fog2))
    return img
def _season(num, bronze, coin):
    rim = ((238, 194, 132), (176, 112, 60), (96, 54, 24)) if bronze else \
        ((255, 246, 208), (246, 190, 78), (130, 78, 16))
    img = coin_base(L.AMBER if not bronze else L.BRONZE, 58, coin, rim_top=rim[0], rim_mid=rim[1],
                    rim_bot=rim[2])
    img = rich_rim(img)
    r = 152
    disc = L.circle_mask(256, 262, r)
    img = L.shadow(img, disc, 4, 8, 8, 135)
    img = L.paint(img, disc, L.grad_v([(0, rim[0]), (0.42, rim[1]), (1, rim[2])]))
    face = L.circle_mask(256, 262, r - 18)
    img = L.paint(img, face, L.grad_v([(0, (116, 78, 44) if bronze else (126, 82, 26)),
                                       (0.55, (84, 50, 26) if bronze else (96, 58, 16)),
                                       (1, (48, 28, 14) if bronze else (62, 36, 10))]))
    img = L.spec_arc(img, 256, 262, r - 20, 175, 355, width=4, alpha=140, color=(30, 16, 6), blur=3)
    img = L.spec_arc(img, 256, 262, r - 20, 5, 175, width=2.4, alpha=80, color=(255, 220, 160), blur=2)
    img = L.spec_arc(img, 256, 262, r - 4, 190, 340, width=2.6, alpha=130, color=(255, 244, 210), blur=1.4)
    img = L.outline(img, disc, 1.8, 150)
    # stamped numeral
    nm = numeral_mask(str(num), 256, 264, 176)
    img = L.shadow(img, nm, 4, 5, 4, 110)
    img = L.shade(img, nm, (255, 246, 210) if not bronze else (255, 224, 178),
                  rim[1], 110, 90)
    img = L.outline(img, nm, 2.4, 140, (70, 40, 12))
    # flanking pips
    for s in (-1, 1):
        st = star_mask(256 + s * 100, 334, 16, 7)
        img = L.paint(img, st, L.grad_v([(0, (255, 248, 214)), (1, rim[1])]))
        img = L.outline(img, st, 1.2, 130)
    img = L.spec_arc(img, 232, 214, 62, 200, 300, width=5, alpha=45, color=(255, 236, 200), blur=6)
    return img


def season_tier_10(coin=None):
    return _season(10, True, coin)


def season_tier_30(coin=None):
    return _season(30, False, coin)


def _ico(img, m, col=L.CREAM):
    img = L.shadow(img, m, 1, 2, 2, 80)
    img = L.fill_mask(img, m, col, 255)
    return L.outline(img, m, 1.0, 120)


def every_call(coin=None):
    img = coin_base(L.GOLD, 50, coin)
    ring = Image.new("L", (L.PX, L.PX), 0)
    rd = ImageDraw.Draw(ring)
    rd.ellipse([(256 - 140) * L.SS, (262 - 140) * L.SS, (256 + 140) * L.SS, (262 + 140) * L.SS],
               outline=255, width=int(5 * L.SS))
    img = L.fill_mask(img, ring, (240, 222, 190), 150)
    img = L.outline(img, ring, 1.0, 60, (90, 70, 44))

    def swim(x, y, s):
        m = L.stroke_mask([(x - 0.5 * s, y + 0.28 * s), (x, y + 0.1 * s), (x + 0.45 * s, y + 0.2 * s)],
                          0.24 * s, 0.18 * s)
        m = ImageChops.lighter(m, L.circle_mask(x + 0.16 * s, y - 0.18 * s, 0.2 * s))
        m = ImageChops.lighter(m, L.stroke_mask([(x + 0.22 * s, y - 0.02 * s), (x + 0.5 * s, y - 0.28 * s)],
                                                0.15 * s, 0.11 * s))
        return m

    def tow(x, y, s):
        m = L.stroke_mask([(x - 0.15 * s, y - 0.5 * s), (x - 0.15 * s, y + 0.15 * s),
                           (x + 0.05 * s, y + 0.4 * s), (x + 0.34 * s, y + 0.3 * s)], 0.17 * s, 0.14 * s)
        m = ImageChops.lighter(m, L.circle_mask(x - 0.15 * s, y - 0.5 * s, 0.12 * s))
        return m

    def ferry(x, y, s):
        m = L.shape_mask(L.smooth([(x - 0.5 * s, y + 0.1 * s), (x + 0.5 * s, y + 0.1 * s),
                                   (x + 0.36 * s, y + 0.42 * s), (x - 0.38 * s, y + 0.42 * s)], True))
        m = ImageChops.lighter(m, L.rrect_mask([x - 0.3 * s, y - 0.32 * s, x + 0.3 * s, y + 0.1 * s],
                                               0.06 * s))
        return m

    def cliff(x, y, s):
        return L.shape_mask(L.smooth([(x - 0.5 * s, y + 0.4 * s), (x - 0.1 * s, y - 0.42 * s),
                                      (x + 0.12 * s, y - 0.1 * s), (x + 0.3 * s, y - 0.3 * s),
                                      (x + 0.5 * s, y + 0.4 * s)], True))

    def rip(x, y, s):
        m = L.stroke_mask(L.smooth([(x - 0.5 * s, y - 0.24 * s), (x, y - 0.4 * s),
                                    (x + 0.5 * s, y - 0.22 * s)], closed=False, n=12), 0.13 * s, 0.13 * s)
        m = ImageChops.lighter(m, L.stroke_mask(L.smooth([(x - 0.5 * s, y + 0.05 * s), (x, y - 0.1 * s),
                                                          (x + 0.5 * s, y + 0.06 * s)],
                                                         closed=False, n=12), 0.13 * s, 0.13 * s))
        m = ImageChops.lighter(m, L.stroke_mask(L.smooth([(x - 0.5 * s, y + 0.34 * s), (x, y + 0.2 * s),
                                                          (x + 0.5 * s, y + 0.34 * s)],
                                                         closed=False, n=12), 0.13 * s, 0.13 * s))
        return m

    def sink(x, y, s):
        m = L.stroke_mask([(x, y - 0.45 * s), (x, y + 0.22 * s)], 0.14 * s, 0.14 * s)
        m = ImageChops.lighter(m, L.shape_mask(L.smooth([(x - 0.26 * s, y + 0.1 * s),
                                                         (x, y + 0.44 * s),
                                                         (x + 0.26 * s, y + 0.1 * s)], True)))
        return m

    def fire(x, y, s):
        return L.shape_mask(L.smooth([(x, y - 0.5 * s), (x + 0.22 * s, y - 0.1 * s),
                                      (x + 0.3 * s, y + 0.18 * s), (x + 0.12 * s, y + 0.42 * s),
                                      (x - 0.12 * s, y + 0.44 * s), (x - 0.3 * s, y + 0.2 * s),
                                      (x - 0.22 * s, y - 0.06 * s), (x - 0.05 * s, y - 0.24 * s)], True))

    def paw(x, y, s):
        return S.paw_mask(x, y, 0.62 * s)

    for i, fn in enumerate((swim, tow, ferry, cliff, rip, sink, fire, paw)):
        a = math.radians(-90 + 45 * i)
        x, y = 256 + math.cos(a) * 140, 262 + math.sin(a) * 140
        img = _ico(img, fn(x, y, 62))
    return img
def lifeboat_bought(coin=None):
    img = coin_base(L.CORAL, 55, coin)
    sc = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    crest = L.shape_mask(L.smooth([(44, 456), (52, 390), (88, 346), (146, 318), (214, 310),
                                   (284, 316), (344, 338), (388, 376), (404, 428), (406, 456)], True))
    sc = L.paint(sc, crest, L.grad_v([(0, (80, 202, 200)), (0.5, (26, 124, 132)), (1, (7, 44, 60))]))
    sc = L.outline(sc, crest, 1.8, 120)
    lip = L.stroke_mask(L.smooth([(54, 392), (92, 350), (148, 324), (214, 316), (284, 322),
                                  (342, 342), (386, 380)], closed=False, n=28), 9, 4)
    sc = L.fill_mask(sc, lip, (220, 248, 244), 230)
    foam = L.stroke_mask(L.smooth([(126, 352), (162, 336), (196, 330)], closed=False, n=12), 7, 3)
    sc = L.fill_mask(sc, foam, (236, 250, 246), 190)
    foam2 = L.stroke_mask(L.smooth([(320, 332), (356, 340), (386, 354)], closed=False, n=12), 7, 3)
    sc = L.fill_mask(sc, foam2, (236, 250, 246), 190)
    img = Image.alpha_composite(img, face_clip(sc))
    # bow, seen from the front, tipped up
    bow = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    bm = L.shape_mask(L.smooth([(148, 232), (198, 206), (314, 206), (364, 232), (352, 302),
                                (316, 354), (256, 384), (196, 354), (160, 302)], True))
    bow = L.shadow(bow, bm, 4, 8, 7, 130)
    bow = L.paint(bow, bm, L.grad_v([(0, (255, 158, 116)), (0.5, L.CORAL), (1, (146, 34, 26))]))
    bow = L.outline(bow, bm, 2.2, 150)
    deckb = ImageChops.multiply(bm, L.rrect_mask([152, 216, 360, 264], 14))
    bow = L.fill_mask(bow, deckb, (252, 242, 220), 240)
    bow = L.outline(bow, deckb, 1.4, 110)
    scr = L.rrect_mask([220, 268, 292, 306], 7)
    bow = L.paint(bow, scr, L.grad_v([(0, (152, 214, 226)), (1, (18, 62, 84))]))
    bow = L.outline(bow, scr, 1.6, 130)
    bow = L.spec_arc(bow, 256, 286, 24, 205, 320, width=3, alpha=100, color=(214, 244, 250), blur=2)
    stem = L.stroke_mask([(256, 232), (256, 372)], 5, 3)
    bow = L.fill_mask(bow, stem, (255, 240, 212), 170)
    bow = bow.rotate(-6, resample=Image.BICUBIC, center=(256 * L.SS, 300 * L.SS))
    img = Image.alpha_composite(img, bow)
    for pts, w0, w1, al in [([(172, 340), (142, 326), (120, 332)], 8, 2, 210),
                            ([(340, 342), (372, 330), (394, 338)], 8, 2, 210),
                            ([(188, 372), (158, 366)], 5, 1.5, 160)]:
        sp = L.stroke_mask(L.smooth(pts, closed=False, n=10), w0, w1)
        img = L.fill_mask(img, sp, (238, 250, 250), al)
    return img
def rank_admiral(coin=None):
    img = coin_base(L.GOLD, 52, coin)
    board = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    bm = L.rrect_mask([96, 194, 416, 312], 24)
    board = L.shadow(board, bm, 5, 8, 8, 130)
    board = L.paint(board, bm, L.grad_v([(0, (52, 82, 112)), (0.5, (24, 44, 66)), (1, (8, 18, 30))]))
    board = L.outline(board, bm, 2.4, 150)
    inner = L.rrect_mask([112, 208, 400, 298], 18)
    board = L.outline(board, inner, 2.0, 120, (255, 212, 132))
    board = L.spec_arc(board, 250, 228, 150, 195, 330, width=2.6, alpha=70, color=(170, 206, 234), blur=2)
    btn = L.circle_mask(142, 252, 16)
    board = L.paint(board, btn, L.grad_v([(0, (255, 246, 206)), (1, L.GOLD_D)]))
    board = L.outline(board, btn, 1.5, 140)
    for k in range(4):
        st = star_mask(204 + k * 58, 252, 31, 13)
        board = L.shadow(board, st, 2, 3, 3, 110)
        board = L.paint(board, st, L.grad_v([(0, (255, 248, 214)), (1, L.GOLD)]))
        board = L.outline(board, st, 1.4, 140)
    board = board.rotate(-7, resample=Image.BICUBIC, center=(256 * L.SS, 252 * L.SS))
    img = Image.alpha_composite(img, board)
    return img
def friend_crew(coin=None):
    img = coin_base(L.TEAL, 55, coin)
    deck = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    planks = L.shape_mask(L.smooth([(96, 388), (416, 388), (452, 458), (60, 458)], True))
    deck = L.paint(deck, planks, L.grad_v([(0, (198, 146, 94)), (1, (92, 58, 32))]))
    for yy in (404, 422, 440):
        deck = L.fill_mask(deck, L.stroke_mask([(90, yy), (422, yy - 2)], 2.4, 2.4), (110, 70, 40), 110)
    deck = L.outline(deck, planks, 1.7, 140)
    img = Image.alpha_composite(img, face_clip(deck))
    # two forearms meeting across the deck, clipped at the coin face
    arms = Image.new("RGBA", (L.PX, L.PX), (0, 0, 0, 0))
    ls = L.stroke_mask(L.smooth([(80, 356), (156, 334), (226, 306)], closed=False, n=16), 54, 42)
    arms = S.paint_subject(arms, ls, (255, 150, 112), (160, 42, 30), 150, 95, 85, 1.9)
    rs = L.stroke_mask(L.smooth([(432, 356), (356, 334), (286, 306)], closed=False, n=16), 54, 42)
    arms = S.paint_subject(arms, rs, (86, 214, 198), (20, 106, 104), 140, 95, 85, 1.9)
    img = Image.alpha_composite(img, face_clip(arms))
    # cuff bands
    for cx, cy, rot in [(230, 302, 0.42), (282, 302, -0.42)]:
        cuff = S.emask_ellipse(cx, cy, 15, 30, rot)
        img = L.shade(img, cuff, (252, 240, 214), (190, 172, 138), 85, 80)
        img = L.outline(img, cuff, 1.2, 110)
    # clasped hands
    lh = S.emask_ellipse(248, 292, 44, 33, 0.30)
    img = S.paint_subject(img, lh, (252, 240, 214), (172, 152, 116), 130, 95, 85, 1.9)
    rh = S.emask_ellipse(276, 298, 44, 32, -0.30)
    img = S.paint_subject(img, rh, (246, 232, 204), (160, 138, 104), 130, 90, 85, 1.9)
    seam = L.stroke_mask(L.smooth([(258, 268), (264, 288), (262, 308)], closed=False, n=10), 3.4, 2.6)
    img = L.fill_mask(img, seam, (110, 84, 54), 130)
    for k in range(3):
        f = L.stroke_mask(L.smooth([(258 + k * 9, 268 + k * 7), (296 + k * 8, 288 + k * 7)],
                                   closed=False, n=8), 14, 10)
        img = L.shade(img, f, (250, 236, 208), (172, 150, 114), 95, 85)
        img = L.outline(img, f, 2.0, 140)
        g = L.stroke_mask([(256 + k * 9, 274 + k * 7), (298 + k * 8, 294 + k * 7)], 2.6, 1.8)
        img = L.fill_mask(img, g, (96, 72, 44), 160)
    thumb = L.stroke_mask([(242, 282), (256, 264), (274, 258)], 20, 14)
    img = S.paint_subject(img, thumb, (250, 236, 208), (168, 146, 110), 120, 90, 80, 1.5)
    return img
def photo_first(coin=None):
    img = coin_base(L.TEAL, 55, coin)
    aperture = L.circle_mask(256, 260, 98)
    img = L.paint(img, aperture, L.grad_v([(0, (80, 208, 200)), (0.55, (22, 124, 128)), (1, (8, 50, 66))]))
    img = L.glow(img, aperture, L.TEAL, 20, 70)
    wave = L.shape_mask(L.smooth([(164, 298), (200, 272), (238, 278), (270, 260), (304, 266),
                                  (342, 294), (354, 332), (164, 332)], True))
    img = L.paint(img, wave, L.grad_v([(0, (140, 236, 224)), (1, (16, 92, 104))]))
    crest = L.stroke_mask(L.smooth([(172, 296), (204, 274), (240, 280), (272, 262), (306, 268),
                                    (340, 292)], closed=False, n=22), 10, 3)
    img = L.fill_mask(img, crest, (248, 254, 240), 245)
    img = L.outline(img, crest, 0.9, 80)
    for k in range(6):
        a0 = math.radians(60 * k - 90)
        a1 = math.radians(60 * (k + 1) - 90)
        o0 = (256 + math.cos(a0) * 152, 260 + math.sin(a0) * 152)
        o1 = (256 + math.cos(a1) * 152, 260 + math.sin(a1) * 152)
        i1 = (256 + math.cos(a1 + 0.26) * 98, 260 + math.sin(a1 + 0.26) * 98)
        i0 = (256 + math.cos(a0 + 0.26) * 98, 260 + math.sin(a0 + 0.26) * 98)
        bl = L.shape_mask([o0, o1, i1, i0], True)
        top = (232, 238, 238) if k % 2 else (176, 188, 198)
        bot = (108, 122, 138) if k % 2 else (72, 86, 102)
        img = L.shade(img, bl, top, bot, 70, 65)
        img = L.outline(img, bl, 2.2, 155)
        seam = L.stroke_mask([o0, i0], 4.0, 1.6)
        img = L.fill_mask(img, seam, (34, 42, 52), 210)
        bev = L.stroke_mask([o1, i1], 2.4, 1.2)
        img = L.fill_mask(img, bev, (244, 248, 246), 120)
    hexa = L.shape_mask([(256 + math.cos(math.radians(60 * k - 90 + 15)) * 92,
                          260 + math.sin(math.radians(60 * k - 90 + 15)) * 92) for k in range(6)], True)
    ring = ImageChops.subtract(L.circle_mask(256, 260, 172), L.circle_mask(256, 260, 148))
    img = L.paint(img, ring, L.grad_v([(0, (250, 250, 242)), (0.5, (178, 190, 200)), (1, (80, 94, 110))]))
    img = L.outline(img, ring, 1.8, 140)
    img = L.outline(img, hexa, 2.2, 130, (24, 34, 44))
    img = L.spec_arc(img, 256, 260, 160, 190, 330, width=5, alpha=110, color=(255, 255, 248), blur=3)
    img = L.spec_arc(img, 256, 260, 94, 200, 300, width=4, alpha=95, color=(230, 255, 250), blur=3)
    return img
GROUPS = [
    ("Certifications", ["CertHelm", "CertCasualtyCare", "CertRescueSwimmer", "CertCoxswain"]),
    ("Ranks", ["RankLifeguard", "RankRescueSwimmer", "RankAdmiral"]),
    ("Firsts", ["FirstRescue", "FirstWildlife", "FirstPet", "FirstWreck"]),
    ("Rescue calls", ["Downwind", "TowTruck", "StormChaser", "FerryHero", "AirPocket",
                      "GreatStormRescue", "LifeboatBought", "EveryCall"]),
    ("Special and collection", ["LegendaryRescue", "GoldenGull", "GhostShip", "AllWildlife",
                                "PhotoFirst", "AlbumSet", "AlbumComplete"]),
    ("Streaks, season and crew", ["Streak7", "Streak30", "SeasonTier10", "SeasonTier30", "FriendCrew"]),
]

FUNCS = {
    "FirstRescue": first_rescue, "CertHelm": cert_helm, "CertCasualtyCare": cert_casualty_care,
    "CertRescueSwimmer": cert_rescue_swimmer, "CertCoxswain": cert_coxswain,
    "RankLifeguard": rank_lifeguard, "FirstWildlife": first_wildlife, "FirstPet": first_pet,
    "Streak7": streak7, "GreatStormRescue": great_storm_rescue, "Downwind": downwind,
    "TowTruck": tow_truck, "StormChaser": storm_chaser, "RankRescueSwimmer": rank_rescue_swimmer,
    "FerryHero": ferry_hero, "AirPocket": air_pocket, "FirstWreck": first_wreck,
    "AllWildlife": all_wildlife, "LegendaryRescue": legendary_rescue, "GoldenGull": golden_gull,
    "AlbumSet": album_set, "AlbumComplete": album_complete, "Streak30": streak30,
    "GhostShip": ghost_ship, "SeasonTier10": season_tier_10, "SeasonTier30": season_tier_30,
    "EveryCall": every_call, "LifeboatBought": lifeboat_bought, "RankAdmiral": rank_admiral,
    "FriendCrew": friend_crew, "PhotoFirst": photo_first,
}
BADGES = [(key, FUNCS[key]) for _g, keys in GROUPS for key in keys]
