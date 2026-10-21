"""Reusable subject shapes for the badge set (512 design space)."""
import math

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import iconlib as L


def ellipse_pts(cx, cy, rx, ry, rot=0.0, n=36):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        c, s = math.cos(rot), math.sin(rot)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def emask_ellipse(cx, cy, rx, ry, rot=0.0):
    return L.shape_mask(ellipse_pts(cx, cy, rx, ry, rot), True)


def heart_mask(cx, cy, s):
    pts = []
    for i in range(72):
        t = 2 * math.pi * i / 72
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s / 17.0, cy - y * s / 17.0))
    return L.shape_mask(pts, True)


def paw_mask(cx, cy, s, toes=True):
    m = emask_ellipse(cx, cy + 0.34 * s, 0.44 * s, 0.37 * s)
    if not toes:
        return m
    specs = [(-0.56, -0.18, 0.065, -0.55), (-0.21, -0.46, 0.05, -0.18),
             (0.21, -0.46, 0.05, 0.18), (0.56, -0.18, 0.065, 0.55)]
    for dx, dy, sway, rot in specs:
        m = ImageChops.lighter(m, emask_ellipse(cx + dx * s, cy + dy * s, 0.19 * s, 0.25 * s, rot))
    return m


def paint_subject(img, mask, top, bot, outline_a=120, hi=95, lo=105, ow=1.6):
    """Standard rounded, shaded sticker-style solid."""
    img = L.shadow(img, mask, 3, 5, 5, 120)
    img = L.shade(img, mask, top, bot, hi, lo)
    return L.outline(img, mask, ow, outline_a)


def life_ring(img, cx, cy, ro, ri, ry_k=0.97, a_off=-90, band=None,
              band2=None, shadowed=True):
    band = L.CORAL if band is None else band
    band2 = L.CREAM if band2 is None else band2
    outer = L.ellipse_mask([cx - ro, cy - ro * ry_k, cx + ro, cy + ro * ry_k])
    inner = L.ellipse_mask([cx - ri, cy - ri * ry_k, cx + ri, cy + ri * ry_k])
    ring = ImageChops.subtract(outer, inner)
    if shadowed:
        img = L.shadow(img, outer, 4, 7, 7, 130)
    # body
    img = L.paint(img, ring, L.grad_v([(0, band2), (0.42, (252, 246, 231)), (1, L.CREAM_D)]))
    # bands: four quadrants of the band colour
    for k in range(4):
        if k % 2:
            continue
        a0, a1 = a_off + 90 * k, a_off + 90 * (k + 1)
        wm = Image.new("L", (L.PX, L.PX), 0)
        ImageDraw.Draw(wm).pieslice(
            [(cx - ro) * L.SS, (cy - ro * ry_k) * L.SS,
             (cx + ro) * L.SS, (cy + ro * ry_k) * L.SS], a0, a1, fill=255)
        wm = ImageChops.subtract(wm, inner)
        img = L.paint(img, wm, L.grad_v([(0, (255, 138, 104)), (0.5, band), (1, L.CORAL_D)]))
    # torus shading: darken near outer + inner edges, light top-left
    edge = ImageChops.subtract(outer, L.ellipse_mask([cx - ro * .90, cy - ro * ry_k * .90,
                                                      cx + ro * .90, cy + ro * ry_k * .90]))
    img = L.fill_mask(img, edge, L.INK, 40)
    edge2 = ImageChops.subtract(L.ellipse_mask([cx - ri * 1.13, cy - ri * ry_k * 1.13,
                                                cx + ri * 1.13, cy + ri * ry_k * 1.13]), inner)
    img = L.fill_mask(img, ImageChops.multiply(edge2, ring), L.INK, 75)
    img = L.spec_arc(img, cx, cy, ro - 7, 188, 322, width=3.2, alpha=110,
                     color=(255, 252, 240), blur=2.5, ry=None)
    # highlight along top of inner wall
    img = L.spec_arc(img, cx, cy, ri + 7, 195, 330, width=2.4, alpha=95,
                     color=(255, 248, 232), blur=2.2, ry=None)
    # inner shadow under top of hole
    img = L.spec_arc(img, cx, cy, ri + 2, 15, 150, width=3.0, alpha=85,
                     color=(60, 34, 18), blur=2.6, ry=None)
    # crisp edges
    img = L.outline(img, outer, 1.5, 130)
    img = L.outline(img, inner, 1.4, 140)
    return img
