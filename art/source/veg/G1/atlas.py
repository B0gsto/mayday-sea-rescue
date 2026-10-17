#!/usr/bin/env python3
"""G1 land-foliage atlas (docs/12 2.5): T_FoliageLand_Main_{ALB,NOR,RGH,MET}[_Wet], pure python3 + numpy + Pillow.

Every card is drawn procedurally from plant structure (owned, AI used: none): tapered curved blades with per-segment
colour (grass, marram, thrift leaves), spined gorse twigs with pea flowers, ling / bell heather sprays, thrift heads,
bipinnate bracken fronds (green and autumn russet), lobed hawthorn leaf sprays with haws, lichened bark.
Height is painted per element (later = higher, rounded across the width), NOR = OpenGL tangent normals from it.
Colour is push-pull padded into the transparent texels so mips never fringe dark. Master 4096 in
art/source/veg/G1/textures/, ship 2048 in assets/textures/M_Veg_FoliageLand/. Cell rects -> cells.json (UV, v up).

usage: python3 art/source/veg/G1/atlas.py [--master 4096] [--ship 2048]
"""
import argparse, json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
SHIP_DIR = os.path.join(GAME, "assets/textures/M_Veg_FoliageLand")
MASTER_DIR = os.path.join(HERE, "textures")

# cell grid 4 x 4 (col, row from the top, w, h in cells)
CELLS = {
    "Turf": (0, 0, 1, 1), "Marram": (1, 0, 1, 2), "GorseSprig": (2, 0, 2, 1), "GorseDense": (2, 1, 1, 1),
    "HawthornLeaves": (3, 1, 1, 1), "Ling": (0, 1, 1, 1), "BellHeather": (0, 2, 1, 1), "ThriftHeads": (1, 2, 1, 1),
    "BrackenGreen": (2, 2, 2, 1), "Bark": (0, 3, 1, 1), "ThriftCushion": (1, 3, 1, 1), "BrackenRusset": (2, 3, 2, 1),
}
RGH = {"Turf": 0.72, "Marram": 0.62, "GorseSprig": 0.5, "GorseDense": 0.52, "HawthornLeaves": 0.55, "Ling": 0.7,
       "BellHeather": 0.66, "ThriftHeads": 0.72, "BrackenGreen": 0.6, "Bark": 0.88, "ThriftCushion": 0.68,
       "BrackenRusset": 0.78}


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def jit(c, rng, amt=10):
    k = rng.uniform(-amt, amt)
    return tuple(int(max(0, min(255, v + k + rng.uniform(-amt, amt) * 0.4))) for v in c)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.col = Image.new("RGB", (w, h), (0, 0, 0))
        self.a = Image.new("L", (w, h), 0)
        self.ht = Image.new("L", (w, h), 0)
        self.dc, self.da, self.dh = ImageDraw.Draw(self.col), ImageDraw.Draw(self.a), ImageDraw.Draw(self.ht)
        self.layer = 0.0

    def poly(self, pts, colour, height, alpha=255):
        self.dc.polygon(pts, fill=colour)
        self.da.polygon(pts, fill=alpha)
        self.dh.polygon(pts, fill=int(max(1, min(255, height))))

    def ellipse(self, box, colour, height, alpha=255):
        self.dc.ellipse(box, fill=colour)
        self.da.ellipse(box, fill=alpha)
        self.dh.ellipse(box, fill=int(max(1, min(255, height))))

    def line(self, pts, colour, width, height):
        self.dc.line(pts, fill=colour, width=width, joint="curve")
        self.da.line(pts, fill=255, width=width, joint="curve")
        self.dh.line(pts, fill=int(max(1, min(255, height))), width=width, joint="curve")


def curve(x0, y0, ang, length, bend, n):
    """points along a bent stem: ang = start direction (radians, 0 = up), bend = total turn (radians)"""
    pts, x, y = [(x0, y0)], x0, y0
    for i in range(n):
        a = ang + bend * (i + 0.5) / n
        x += math.sin(a) * length / n
        y -= math.cos(a) * length / n
        pts.append((x, y))
    return pts


def blade(cv, pts, w0, w1, c0, c1, h0, rng, tipc=None, tip_from=0.8):
    """tapered blade along pts; two half-strips (shadow side darker) give a midrib crease in the height map"""
    n = len(pts) - 1
    for i in range(n):
        (xa, ya), (xb, yb) = pts[i], pts[i + 1]
        dx, dy = xb - xa, yb - ya
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        ta, tb = i / n, (i + 1) / n
        wa, wb = w0 + (w1 - w0) * ta, w0 + (w1 - w0) * tb
        c = lerp(c0, c1, ta)
        if tipc and ta > tip_from:
            c = lerp(c, tipc, min(1.0, (ta - tip_from) / (1 - tip_from)))
        hgt = h0 + 30 * math.sin(math.pi * ta)
        lit = lerp(c, (255, 255, 255), 0.06)
        dark = lerp(c, (0, 0, 0), 0.12)
        cv.poly([(xa, ya), (xa + nx * wa, ya + ny * wa), (xb + nx * wb, yb + ny * wb), (xb, yb)], lit, hgt + 8)
        cv.poly([(xa, ya), (xa - nx * wa, ya - ny * wa), (xb - nx * wb, yb - ny * wb), (xb, yb)], dark, hgt)


# ---------------------------------------------------------------------------------------------------- cells
def grass(cv, rng, count, hmin, hmax, wbase, base, mid, tip, spread, lean, dead=0.12, seeds=0):
    W, H = cv.w, cv.h
    for k in range(count):
        x0 = W / 2 + rng.gauss(0, W * spread)
        x0 = min(W - 20, max(20, x0))
        L = rng.uniform(hmin, hmax) * H
        ang = rng.gauss(lean, 0.22) + (x0 - W / 2) / W * 0.9
        bend = rng.uniform(0.15, 0.7) * (1 if ang >= lean else -1) + lean * 0.6
        pts = curve(x0, H - 4, ang, L, bend, 9)
        pts = [(min(W - 6, max(6, x)), max(6, y)) for x, y in pts]
        is_dead = rng.random() < dead
        c0 = jit((150, 138, 98) if is_dead else base, rng, 8)
        c1 = jit((178, 165, 122) if is_dead else mid, rng, 10)
        blade(cv, pts, wbase * rng.uniform(0.7, 1.2), 0.6, c0, c1, 60 + 150 * k / count, rng, tipc=tip, tip_from=0.7)
    for k in range(seeds):  # marram panicles: long tight spikes
        x0 = W / 2 + rng.gauss(0, W * spread * 0.6)
        L = rng.uniform(0.75, 0.95) * H
        pts = curve(x0, H - 4, lean + rng.gauss(0, 0.06), L, lean * 0.4, 12)
        cv.line(pts[:9], jit((150, 142, 108), rng, 6), 6, 200)
        for (x, y) in pts[8:]:
            cv.ellipse((x - 11, y - 26, x + 11, y + 26), jit((176, 162, 124), rng, 8), 230)


def gorse_twig(cv, rng, x0, y0, ang, L, depth, flowers):
    pts = curve(x0, y0, ang, L, rng.gauss(0, 0.35), 6)
    stem = jit((84, 74, 52), rng, 6) if depth == 0 else jit((62, 80, 46), rng, 6)
    cv.line(pts, stem, max(3, int(9 - depth * 3)), 90 + depth * 40)
    for i, (x, y) in enumerate(pts[1:], 1):
        t = i / len(pts)
        for s in range(rng.randint(3, 6)):  # spines: stiff, dark, furrowed
            a = ang + rng.choice((-1, 1)) * rng.uniform(0.4, 1.3)
            sl = rng.uniform(26, 52) * (1.1 - 0.4 * t)
            sp = curve(x + rng.uniform(-6, 6), y + rng.uniform(-6, 6), a, sl, 0.05, 2)
            blade(cv, sp, 4.2, 0.5, jit((54, 70, 40), rng, 6), jit((78, 94, 54), rng, 8), 120 + depth * 40, rng)
        if depth < 2 and rng.random() < 0.45:
            gorse_twig(cv, rng, x, y, ang + rng.choice((-1, 1)) * rng.uniform(0.3, 0.8), L * 0.55, depth + 1, flowers)
        if flowers and rng.random() < flowers * (0.4 + t):
            for f in range(rng.randint(1, 3)):  # pea flowers: standard + wings, a hint of orange keel
                fx, fy = x + rng.uniform(-22, 22), y + rng.uniform(-22, 22)
                r = rng.uniform(13, 19)
                c = jit((226, 192, 104), rng, 9)
                cv.ellipse((fx - r, fy - r * 1.15, fx + r, fy + r * 0.8), lerp(c, (150, 120, 60), 0.25), 205)
                cv.ellipse((fx - r * 0.85, fy - r * 1.05, fx + r * 0.75, fy + r * 0.5), c, 222)
                cv.ellipse((fx - r * 0.3, fy - r * 0.1, fx + r * 0.35, fy + r * 0.55), jit((206, 150, 78), rng, 6), 232)


def gorse_sprig(cv, rng, flowers=0.42, n=9):
    W, H = cv.w, cv.h
    for k in range(n):
        x0 = W / 2 + rng.gauss(0, W * 0.05)
        ang = rng.uniform(-1.25, 1.25)
        gorse_twig(cv, rng, x0, H - 10, ang, H * rng.uniform(0.55, 0.85), 0, flowers)


def gorse_dense(cv, rng):
    W, H = cv.w, cv.h
    for k in range(70):
        x0, y0 = rng.uniform(60, W - 60), rng.uniform(H * 0.25, H - 40)
        gorse_twig(cv, rng, x0, y0, rng.uniform(-0.9, 0.9), rng.uniform(140, 300), 1, 0.35)


def heather(cv, rng, bell):
    W, H = cv.w, cv.h
    for k in range(26):
        x0 = W / 2 + rng.gauss(0, W * 0.12)
        ang = rng.gauss(0, 0.45)
        L = H * rng.uniform(0.5, 0.92)
        pts = curve(x0, H - 6, ang, L, rng.gauss(0, 0.25), 10)
        cv.line(pts, jit((92, 72, 54), rng, 6), 7, 80 + k * 4)
        for i, (x, y) in enumerate(pts[1:], 1):
            t = i / len(pts)
            for s in range(4):  # side shoots clad in tiny scale leaves
                a = ang + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1)
                sl = rng.uniform(30, 70) * (1.1 - 0.5 * t)
                sp = curve(x, y, a, sl, 0.1, 3)
                cv.line(sp, jit((74, 86, 56), rng, 6), 4, 120 + k * 4)
                for (sx, sy) in sp[1:]:
                    for q in range(3):
                        lx, ly = sx + rng.uniform(-8, 8), sy + rng.uniform(-8, 8)
                        cv.ellipse((lx - 6, ly - 8, lx + 6, ly + 8), jit((70, 88, 52), rng, 9), 140 + k * 4)
            if t > 0.45:  # flower spike: ling = small pale mauve bells all round; bell heather = fat crimson-purple
                for q in range(3 if bell else 5):
                    fx, fy = x + rng.uniform(-18, 18), y + rng.uniform(-10, 10)
                    r = rng.uniform(9, 13) if bell else rng.uniform(6, 9)
                    c = jit((158, 92, 132) if bell else (168, 128, 154), rng, 9)
                    cv.ellipse((fx - r, fy - r * 1.25, fx + r, fy + r), c, 190 + k * 2)
                    cv.ellipse((fx - r * 0.5, fy + r * 0.2, fx + r * 0.5, fy + r * 0.9), lerp(c, (60, 40, 50), 0.35), 196 + k * 2)


def thrift_heads(cv, rng):
    W, H = cv.w, cv.h
    for k in range(9):
        x0 = W / 2 + rng.gauss(0, W * 0.16)
        ang = rng.gauss(0, 0.28)
        L = H * rng.uniform(0.45, 0.82)
        pts = curve(x0, H - 4, ang, L, rng.gauss(0, 0.15), 8)
        cv.line(pts, jit((112, 118, 82), rng, 6), 8, 90 + k * 12)
        hx, hy = pts[-1]
        R = rng.uniform(52, 70)
        cv.ellipse((hx - R * 0.8, hy + R * 0.3, hx + R * 0.8, hy + R * 0.85), jit((150, 126, 96), rng, 6), 120 + k * 12)
        base = jit((206, 150, 172), rng, 10)
        for q in range(60):  # globe of small five-lobed florets, paler towards the light
            a, rr = rng.uniform(0, 2 * math.pi), R * math.sqrt(rng.random())
            fx, fy = hx + math.cos(a) * rr, hy + math.sin(a) * rr * 0.92
            r = rng.uniform(9, 14)
            shade = 0.15 * (fy - hy) / R
            cv.ellipse((fx - r, fy - r, fx + r, fy + r), lerp(base, (90, 50, 70), max(0, shade) + 0.05), 160 + k * 12 + 30 * (1 - rr / R))
            cv.ellipse((fx - r * 0.3, fy - r * 0.3, fx + r * 0.3, fy + r * 0.3), lerp(base, (250, 236, 240), 0.35), 170 + k * 12 + 30 * (1 - rr / R))


def thrift_cushion(cv, rng):
    grass(cv, rng, 420, 0.25, 0.6, 6.5, (62, 78, 48), (86, 104, 64), (124, 120, 86), 0.26, 0.0, dead=0.18)


def frond(cv, rng, green):
    """bipinnate bracken frond lying along +x (stipe at the left edge); pinnae alternate, shrink to the tip"""
    W, H = cv.w, cv.h
    cy = H * 0.5
    L = W * 0.95
    rach = [(12 + L * t, cy + math.sin(t * 3.0) * H * 0.03 - t * t * H * 0.06) for t in np.linspace(0, 1, 30)]
    stem = jit((112, 104, 66) if green else (128, 92, 62), rng, 6)
    base = (88, 110, 58) if green else (140, 104, 74)
    tipc = (110, 128, 70) if green else (158, 122, 88)
    for i in range(3, len(rach) - 1):
        t = i / len(rach)
        x, y = rach[i]
        for side in (-1, 1):
            if (i + (side > 0)) % 2:
                continue
            plen = H * 0.46 * math.sin(math.pi * min(1, t * 1.15)) ** 0.7 * (1.05 - 0.55 * t)
            a = math.pi / 2 + side * (math.pi / 2 - 0.55) if side > 0 else -math.pi / 2 + (math.pi / 2 - 0.55)
            ang = (math.pi / 2 - 0.95) if side < 0 else (math.pi / 2 + 0.95)
            pp = curve(x, y, ang, plen, -side * 0.25, 10)
            cv.line(pp, stem, 4, 110)
            for j, (px, py) in enumerate(pp[1:], 1):
                u = j / len(pp)
                pl = (H * 0.07) * (1.1 - 0.75 * u) * (1.0 - 0.3 * t)
                c = jit(lerp(base, tipc, u * 0.6 + 0.3 * t), rng, 7)
                if not green and rng.random() < 0.25:
                    c = jit((120, 96, 72), rng, 6)
                for s in (-1, 1):  # pinnules: little rounded blades either side
                    sa = ang + s * 1.25
                    sp = curve(px, py, sa, pl, -s * 0.3, 3)
                    blade(cv, sp, pl * 0.36, pl * 0.12, c, lerp(c, (255, 255, 255), 0.05), 130 + 60 * u, rng)
    cv.line(rach, stem, 11, 150)


def hawthorn_leaves(cv, rng):
    W, H = cv.w, cv.h
    twig = [(W * 0.5, H - 4)]
    for k in range(8):
        x0, y0 = W / 2 + rng.gauss(0, 60), H - 4
        pts = curve(x0, y0, rng.uniform(-1.0, 1.0), H * rng.uniform(0.55, 0.85), rng.gauss(0, 0.5), 8)
        cv.line(pts, jit((96, 82, 66), rng, 6), 9, 80)
        for i, (x, y) in enumerate(pts[1:], 1):
            for q in range(rng.randint(3, 6)):
                a = rng.uniform(0, 2 * math.pi)
                r = rng.uniform(34, 52)
                lx, ly = x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.8
                c = jit((78, 98, 58), rng, 9)
                # a deeply lobed leaf: three to five overlapping lobes from the petiole
                for lobe in range(rng.randint(3, 5)):
                    la = a + (lobe - 2) * 0.55
                    ex, ey = lx + math.cos(la) * r * 0.45, ly + math.sin(la) * r * 0.45
                    rr = r * rng.uniform(0.32, 0.45)
                    cv.ellipse((ex - rr, ey - rr * 0.75, ex + rr, ey + rr * 0.75), lerp(c, (255, 255, 255), 0.04 * lobe), 140 + 10 * lobe)
                cv.ellipse((lx - r * 0.3, ly - r * 0.3, lx + r * 0.3, ly + r * 0.3), lerp(c, (0, 0, 0), 0.08), 190)
            if rng.random() < 0.22:  # haws (late summer / autumn)
                for q in range(rng.randint(2, 5)):
                    hx, hy, r = x + rng.uniform(-30, 30), y + rng.uniform(-30, 30), rng.uniform(9, 13)
                    cv.ellipse((hx - r, hy - r, hx + r, hy + r), jit((142, 64, 54), rng, 6), 220)
                    cv.ellipse((hx - r * 0.35, hy - r * 0.6, hx + r * 0.1, hy - r * 0.2), (188, 120, 108), 230)


def bark(w, h, rng):
    """lichened hawthorn / gorse bark, tiles along v; returns (rgb float, height float)"""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    def noise(scale_x, scale_y, seed):
        r = np.random.default_rng(seed)
        g = r.random((int(h / scale_y) + 2, int(w / scale_x) + 2)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        return np.asarray(img, np.float32) / 255.0
    fiss = noise(18, 140, 3) * 0.6 + noise(6, 40, 4) * 0.4
    fiss = np.abs(fiss - 0.5) * 2
    lich = noise(60, 60, 5) * 0.6 + noise(15, 15, 6) * 0.4
    lmask = np.clip((lich - 0.6) * 6, 0, 1)
    base = np.array([104, 96, 86], np.float32) * (0.55 + 0.6 * fiss[..., None])
    lichc = np.array([164, 170, 150], np.float32) * (0.85 + 0.2 * noise(4, 4, 7)[..., None])
    rgb = base * (1 - lmask[..., None]) + lichc * lmask[..., None]
    return rgb, fiss * 0.7 + lmask * 0.4


# ---------------------------------------------------------------------------------------------------- maps
def pad_colour(rgb, a):
    """push-pull: fill transparent texels with the average of nearby opaque colour"""
    levels = []
    c, w = rgb * a[..., None], a.copy()
    while min(w.shape) > 4:
        levels.append((c, w))
        H2, W2 = w.shape[0] // 2, w.shape[1] // 2
        c = c[:H2 * 2, :W2 * 2].reshape(H2, 2, W2, 2, 3).sum((1, 3))
        w = w[:H2 * 2, :W2 * 2].reshape(H2, 2, W2, 2).sum((1, 3))
    fill = c / np.maximum(w, 1e-6)[..., None]
    for c, w in reversed(levels):
        up = np.repeat(np.repeat(fill, 2, 0), 2, 1)[:w.shape[0], :w.shape[1]]
        mine = c / np.maximum(w, 1e-6)[..., None]
        t = np.clip(w, 0, 1)[..., None]
        fill = mine * t + up * (1 - t)
    return fill


def normal_from_height(hgt, strength):
    gy, gx = np.gradient(hgt)
    n = np.dstack([-gx * strength, gy * strength, np.ones_like(hgt)])  # OpenGL: +Y up (image rows go down)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--master", type=int, default=4096)
    ap.add_argument("--ship", type=int, default=2048)
    args = ap.parse_args()
    S, K = args.master, args.master // 4
    rgb = np.zeros((S, S, 3), np.float32)
    alpha = np.zeros((S, S), np.float32)
    hgt = np.zeros((S, S), np.float32)
    rough = np.zeros((S, S), np.float32)
    cells_uv = {}
    for name, (cx, cy, cw, ch) in CELLS.items():
        rng = random.Random(sum(ord(ch) * (i + 1) for i, ch in enumerate(name)) + 17)
        w, h = cw * K, ch * K
        x0, y0 = cx * K, cy * K
        cells_uv[name] = [cx / 4, 1 - (cy + ch) / 4, (cx + cw) / 4, 1 - cy / 4]
        if name == "Bark":
            c, hh = bark(w, h, rng)
            rgb[y0:y0 + h, x0:x0 + w] = c
            alpha[y0:y0 + h, x0:x0 + w] = 1
            hgt[y0:y0 + h, x0:x0 + w] = hh * 120
            rough[y0:y0 + h, x0:x0 + w] = RGH[name]
            continue
        sc = K / 1024.0
        cv = Canvas(int(w / sc), int(h / sc))  # drawn in 1024-per-cell units, resized to the master
        if name == "Turf":
            grass(cv, rng, 380, 0.3, 0.92, 9, (64, 78, 44), (96, 112, 64), (156, 146, 104), 0.2, 0.0, dead=0.16)
        elif name == "Marram":
            grass(cv, rng, 150, 0.45, 0.97, 9, (96, 108, 78), (132, 142, 108), (176, 164, 124), 0.17, 0.12, dead=0.2, seeds=5)
        elif name == "GorseSprig":
            gorse_sprig(cv, rng)
        elif name == "GorseDense":
            gorse_dense(cv, rng)
        elif name == "Ling":
            heather(cv, rng, False)
        elif name == "BellHeather":
            heather(cv, rng, True)
        elif name == "ThriftHeads":
            thrift_heads(cv, rng)
        elif name == "ThriftCushion":
            thrift_cushion(cv, rng)
        elif name == "BrackenGreen":
            frond(cv, rng, True)
        elif name == "BrackenRusset":
            frond(cv, rng, False)
        elif name == "HawthornLeaves":
            hawthorn_leaves(cv, rng)
        m = 6  # keep a clear gutter around every cell
        for im in (cv.col, cv.a, cv.ht):
            ImageDraw.Draw(im).rectangle((0, 0, cv.w - 1, cv.h - 1), outline=0, width=m)
        col = cv.col.resize((w, h), Image.LANCZOS)
        a = cv.a.resize((w, h), Image.LANCZOS)
        ht = cv.ht.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.6 * sc))
        rgb[y0:y0 + h, x0:x0 + w] = np.asarray(col, np.float32)
        alpha[y0:y0 + h, x0:x0 + w] = np.asarray(a, np.float32) / 255.0
        hgt[y0:y0 + h, x0:x0 + w] = np.asarray(ht, np.float32)
        r = RGH[name] + (np.asarray(ht, np.float32) / 255.0 - 0.5) * -0.12
        rough[y0:y0 + h, x0:x0 + w] = r
    # albedo in the 1.4a window; colour padded under alpha
    a_soft = np.clip(alpha, 0, 1)
    rgb = np.clip(rgb, 0, 255)
    fill = pad_colour(rgb / 255.0, (a_soft > 0.5).astype(np.float32)) * 255
    rgb = np.where((a_soft > 0.5)[..., None], rgb, fill)
    # saturation soft knee under the 05 ceiling (0.45): flowers keep their hue, lose a little chroma
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    knee = np.where(sat > 0.38, 0.38 + (sat - 0.38) * 0.35, sat)
    grey = mx[..., None]
    rgb = grey - (grey - rgb) * (knee / np.maximum(sat, 1e-3))[..., None]
    rgb = np.clip(rgb, 34, 238)
    nor = normal_from_height(hgt / 255.0, 18.0 * S / 4096.0)
    nor[alpha < 0.02] = (128, 128, 255)
    rough = np.clip(np.where(alpha > 0.02, rough, 0.7), 0.05, 1)
    out = {
        "ALB": np.dstack([rgb, alpha * 255]).astype(np.uint8),
        "NOR": nor,
        "RGH": (rough * 255).astype(np.uint8),
        "MET": np.zeros((S, S), np.uint8),
    }
    wet_rgb = rgb * 0.8  # wet: darker, glossier (05 wet look); luma kept above the floor
    wet_rgb = np.maximum(wet_rgb, 28)
    out["ALB_Wet"] = np.dstack([wet_rgb, alpha * 255]).astype(np.uint8)
    out["RGH_Wet"] = (np.clip(rough * 0.55, 0.05, 1) * 255).astype(np.uint8)
    out["NOR_Wet"] = nor
    out["MET_Wet"] = out["MET"]
    os.makedirs(MASTER_DIR, exist_ok=True)
    os.makedirs(SHIP_DIR, exist_ok=True)
    for k, arr in out.items():
        kind, wet = (k.split("_") + [""])[:2]
        fn = "T_FoliageLand_Main_%s%s.png" % (kind, "_Wet" if wet else "")
        mode = "RGBA" if arr.ndim == 3 and arr.shape[2] == 4 else ("RGB" if arr.ndim == 3 else "L")
        im = Image.fromarray(arr, mode)
        im.save(os.path.join(MASTER_DIR, fn))
        im.resize((args.ship, args.ship), Image.LANCZOS).save(os.path.join(SHIP_DIR, fn))
    json.dump({"master": S, "ship": args.ship, "uv": "u0, v0, u1, v1 (v up)", "cells": cells_uv},
              open(os.path.join(HERE, "cells.json"), "w"), indent=1)
    print("atlas ok", S, "->", args.ship, SHIP_DIR)


if __name__ == "__main__":
    main()
