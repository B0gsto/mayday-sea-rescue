"""M_Bld_UpgradeStation: the bay landmark on every island (docs/30 section 2), from the owner-cleared concept artifact
4547704c-8ab7-4a0f-8006-83fc9bd11cb9. A close port of its part list: same names, sizes, colours and positions.
Art director round 1 changes on top (marked "round 2"): matte steel, thicker tools with a big jaw; larger workshop moved forward with an open
double door and tool sign; chunky kerbs and pier heads; bright board; one spare-parts tray.

Concept axes: +X port (workshop), -X starboard (board), +Y up, +Z open sea. Blender = (x, -z, y), so the open sea is Blender -Y =
Roblox -Z (the Model's forward). Origin = concept origin: Z 0 is the baseplate top, the quay top is 0.4, the water is at -1.5.
Left out on purpose: water, seabed, sample boat, minifig, clearance ghost (scene only) and every print with numbers: the
board and the Upgrade button are blank, the live UI is a SurfaceGui (see RESULT.md).

One atlas (palette.py): flat cells plus stud patches for the big decks; other tops carry real studs at LOD0. One script makes all
LODs: LOD1 drops studs, bevels, the interior and small parts; LOD2 merges bricks into runs. _COL: one box per object.

    python3 art/source/buildings/M_Bld_UpgradeStation/palette.py build/prod/M_Bld_UpgradeStation/textures/M_Bld_UpgradeStation
    Blender MCP: run.py -- --build <this> --out-root build/prod/M_Bld_UpgradeStation --steps build,validate,export
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import palette as P  # noqa: E402

NAME, SET_NAME, SET = "M_Bld_UpgradeStation", "UpgradeStation", "Brick"
TEX = os.path.join(ROOT, "build/prod", NAME, "textures", NAME)
G, BH, PH, WATER = .04, 1.2, .4, -1.5
BOARD_SCALE = 1.3
CULL = {0: 0, 1: .9, 2: 2.6}          # parts smaller than this (largest world size) are left out of a LOD
I = Matrix.Identity(4)
DEG = math.pi / 180


class Ctx:
    lod, group = 0, "Island"
    meshes, parts, atts, cols, smooth = {}, [], [], [], {}


def T(p):
    return Matrix.Translation(Vector(p))


def R(r):
    return Matrix.Rotation(r[0] * DEG, 4, "X") @ Matrix.Rotation(r[1] * DEG, 4, "Y") @ Matrix.Rotation(r[2] * DEG, 4, "Z")


def grp(p, r=(0, 0, 0), parent=I, sc=1):
    return parent @ T(p) @ R(r) @ Matrix.Scale(sc, 4)


def emit(mat, verts, faces, c, flat=False, group=None, smooth=False):
    """One shell in local coords. Winding: outward by signed volume about the shell centroid (flat decals keep theirs)."""
    pts = [mat @ Vector(v) for v in verts]
    if not flat:
        o = sum(pts, Vector()) / len(pts)
        vol = 0.0
        for f in faces:
            idx = f[0] if isinstance(f[0], (tuple, list)) else f
            for k in range(1, len(idx) - 1):
                vol += (pts[idx[0]] - o).dot((pts[idx[k]] - o).cross(pts[idx[k + 1]] - o))
        if vol < 0:
            faces = [(tuple(reversed(f[0])), f[1]) if isinstance(f[0], (tuple, list)) else tuple(reversed(f)) for f in faces]
    m = Ctx.meshes.setdefault(group or Ctx.group, ([], []))
    base = len(m[0])
    m[0].extend(pts)
    if smooth:
        Ctx.smooth.setdefault(group or Ctx.group, []).append((base, base + len(pts)))
    for f in faces:
        idx, uv = (f[0], f[1]) if isinstance(f[0], (tuple, list)) else (f, None)   # uv: None, or explicit per-corner UVs
        m[1].append((tuple(base + i for i in idx), c, uv))


# ------------------------------------------------------------------ primitives (local coords, centred)
def rbox_geo(w, h, d, bev, bot, patch=None):
    a, b, c = max(w - G, .02) / 2, max(h - G, .02) / 2, max(d - G, .02) / 2
    bev = min(bev, min(a, b, c) * .45)
    if Ctx.lod or bev <= 0:
        v = [(s * a, -b, t * c) for s, t in ((1, 1), (1, -1), (-1, -1), (-1, 1))] + [(s * a, b, t * c) for s, t in ((1, 1), (1, -1), (-1, -1), (-1, 1))]
        f = [(i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i) for i in range(4)] + [(4, 5, 6, 7)]
        if bot:
            f.append((3, 2, 1, 0))
        return v, f
    oct_ = [(a, c - bev), (a, -c + bev), (a - bev, -c), (-a + bev, -c), (-a, -c + bev), (-a, c - bev), (-a + bev, c), (a - bev, c)]
    v = [(x, -b, z) for x, z in oct_] + [(x, b - bev, z) for x, z in oct_]
    v += [(a - bev, b, c - bev), (a - bev, b, -c + bev), (-a + bev, b, -c + bev), (-a + bev, b, c - bev)]
    m, t = 8, 16
    f = [(i, (i + 1) % 8, 8 + (i + 1) % 8, 8 + i) for i in range(8)]
    f += [(m, m + 1, t + 1, t), (m + 1, m + 2, t + 1), (m + 2, m + 3, t + 2, t + 1), (m + 3, m + 4, t + 2), (m + 4, m + 5, t + 3, t + 2),
          (m + 5, m + 6, t + 3), (m + 6, m + 7, t, t + 3), (m + 7, m, t), (t, t + 1, t + 2, t + 3)]
    if bot:
        f.append(tuple(reversed(range(8))))
    return v, f


def lathe_geo(profile, seg):
    rings, v = [], []
    for r, y in profile:
        n = 1 if r <= 1e-6 else seg
        rings.append(list(range(len(v), len(v) + n)))
        v += [(0, y, 0)] if n == 1 else [(r * math.sin(2 * math.pi * i / n), y, r * math.cos(2 * math.pi * i / n)) for i in range(n)]
    f = []
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        for i in range(seg):
            j = (i + 1) % seg
            f.append((a[0], b[j], b[i]) if len(a) == 1 else (a[i], a[j], b[0]) if len(b) == 1 else (a[i], a[j], b[j], b[i]))
    return v, f


def sweep_geo(rings, closed):
    """Quads between equal rings; open sweeps get flat end caps."""
    n = len(rings[0])
    v = [p for r in rings for p in r]
    f = []
    for s in range(len(rings) - (0 if closed else 1)):
        s2 = (s + 1) % len(rings)
        f += [(s * n + i, s * n + (i + 1) % n, s2 * n + (i + 1) % n, s2 * n + i) for i in range(n)]
    if not closed:
        f += [tuple(reversed(range(n))), tuple(range((len(rings) - 1) * n, len(rings) * n))]
    return v, f


def torus_geo(R_, tube, arc, maj, mnr):
    closed = arc >= 2 * math.pi - 1e-6
    rings = []
    for i in range(maj + (0 if closed else 1)):
        t = arc * i / maj
        e = (math.cos(t), math.sin(t))
        rings.append([((R_ + tube * math.cos(a)) * e[0], (R_ + tube * math.cos(a)) * e[1], tube * math.sin(a))
                      for a in (2 * math.pi * j / mnr for j in range(mnr))])
    return sweep_geo(rings, closed)


def offset2d(pts, d):
    """Polygon offset along the mitred vertex normals (pts counter-clockwise: d > 0 grows it)."""
    out, n = [], len(pts)
    for i, p in enumerate(pts):
        a, b = pts[i - 1], pts[(i + 1) % n]
        e1 = Vector((p[0] - a[0], p[1] - a[1])).normalized()
        e2 = Vector((b[0] - p[0], b[1] - p[1])).normalized()
        n1, n2 = Vector((e1.y, -e1.x)), Vector((e2.y, -e2.x))
        m = (n1 + n2).normalized() if (n1 + n2).length > 1e-5 else n1
        out.append((p[0] + m.x * min(d / max(m.dot(n1), .4), 2.5 * abs(d) if d > 0 else 1e9) if d > 0 else p[0] + m.x * d / max(m.dot(n1), .4),
                    p[1] + m.y * (d / max(m.dot(n1), .4))))
    return out


def area2d(p):
    return sum(p[i - 1][0] * p[i][1] - p[i][0] * p[i - 1][1] for i in range(len(p))) / 2


def extrude(mat, c, outer, d=2.0, bt=.4, bs=.4, hole=None, flat_mode=False):
    """three.js ExtrudeGeometry (depth d, bevelThickness bt, bevelSize bs), z centred; hole = same-count inner contour."""
    if Ctx.lod and Ctx.group == "Interior":
        return
    if area2d(outer) < 0:
        outer = outer[::-1]
    steps = 2 if Ctx.lod == 0 else 1
    prof = [(-d / 2 - bt * math.cos(i / steps * math.pi / 2), bs * math.sin(i / steps * math.pi / 2)) for i in range(steps + 1)]
    prof += [(-z, o) for z, o in reversed(prof)]
    n = len(outer)
    ro = [[(x, y, z) for x, y in offset2d(outer, o)] for z, o in prof]
    if hole is None:
        v, f = sweep_geo(ro, False)
    else:
        if area2d(hole) < 0:
            hole = hole[::-1]
        ri = [[(x, y, z) for x, y in offset2d(hole, -o)] for z, o in prof]
        v = [p for r in ro + ri for p in r]
        s = len(ro)
        f = []
        for k in range(s - 1):
            f += [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i) for i in range(n)]
            f += [((s + k + 1) * n + i, (s + k + 1) * n + (i + 1) % n, (s + k) * n + (i + 1) % n, (s + k) * n + i) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            f.append(((2 * s - 1) * n + i, (2 * s - 1) * n + j, (s - 1) * n + j, (s - 1) * n + i))      # front annulus
            f.append((j, i, s * n + i, s * n + j))                                                      # back annulus
    emit(mat, v, f, c)


def decal(mat, pts, c, z, group=None):
    """A flat polygon facing local +Z at depth z (colour prints as geometry, lifted so nothing is coplanar)."""
    if area2d(pts) < 0:
        pts = pts[::-1]
    emit(mat, [(x, y, z) for x, y in pts], [tuple(range(len(pts)))], c, flat=True, group=group)


def seg_for(d):
    return (16 if d >= 3 else 12 if d >= 1.4 else 8 if d >= .5 else 6)


def lodseg(seg):
    return seg if Ctx.lod == 0 else max(6, seg // 2) if Ctx.lod == 1 else max(4, min(6, seg // 2))


def part(n, c, s, p=(0, 0, 0), r=(0, 0, 0), k="box", parent=I, studs=False, top=None, seg=None, tube=None, arc=2 * math.pi,
         half=False, bev=.08, bot=None, g=None, patch=None):
    m = parent @ T(p) @ R(r)
    scale = m.to_scale()[0]
    if Ctx.lod and (max(s) * scale < CULL[Ctx.lod] or (g or Ctx.group) == "Interior"):
        return m
    group = g or Ctx.group
    if bot is None:
        bot = parent is not I or any(r)
    if k == "box":
        v, f = rbox_geo(s[0], s[1], s[2], bev, bot)
        if patch and Ctx.lod < 2:
            a, cc = (s[0] - G) / 2, (s[2] - G) / 2
            e = (0 if Ctx.lod else min(bev, min(a, (s[1] - G) / 2, cc) * .45))
            corners = [(a - e, cc - e), (a - e, -cc + e), (-a + e, -cc + e), (-a + e, cc - e)]
            top_idx = (16, 17, 18, 19) if not Ctx.lod else (4, 5, 6, 7)
            # U along +X, V along Blender +Y = concept -Z, so the normal map's tangent frame is right
            uv = [P.patch_uv(patch, x + s[0] / 2, s[2] / 2 - z) for x, z in corners]
            f = [(t, uv) if t == top_idx else t for t in f]
    elif k == "cyl":
        seg2 = lodseg(seg or seg_for(s[0] * scale))
        rb = s[0] / 2 if top is None else top
        pr = ([(0, -s[1] / 2)] if bot and rb > 1e-6 else []) + [(rb, -s[1] / 2), (s[0] / 2, s[1] / 2), (0, s[1] / 2)]
        v, f = lathe_geo(pr, seg2)
    elif k == "sphere":
        seg2 = lodseg(seg or seg_for(s[0] * scale))
        rr, nr = s[0] / 2, max(2, seg2 // 2)
        rng = [(rr * math.sin(math.pi * i / nr), -rr * math.cos(math.pi * i / nr)) for i in range(nr + 1)]
        if half:
            rng = [(0, 0)] + [(rr * math.cos(math.pi / 2 * i / (nr // 2 + 1)), rr * math.sin(math.pi / 2 * i / (nr // 2 + 1))) for i in range(nr // 2 + 2)]
        v, f = lathe_geo(rng, seg2)
    elif k == "torus":
        R_ = s[0] / 2 - tube
        big = R_ * scale
        maj = (16 if big > 2 else 12 if big > .6 else 8) if seg is None else seg
        full = arc / (2 * math.pi)
        if Ctx.lod:
            maj = max(6, maj // 2)
        maj = max(3, math.ceil(maj * full))
        v, f = torus_geo(R_, tube, arc, maj, (6 if tube * scale >= .35 else 4) if Ctx.lod == 0 else 4)
    else:
        raise ValueError(k)
    emit(m, v, f, c, group=group, smooth=k == "torus" or (k == "sphere" and not half))
    if Ctx.lod == 0:
        lo, hi = Vector((-s[0] / 2, -s[1] / 2, -s[2] / 2)), Vector((s[0] / 2, s[1] / 2, s[2] / 2))
        Ctx.parts.append({"n": n, "m": m, "inv": m.inverted(), "lo": lo, "hi": hi, "studs": bool(studs) and not patch, "cyl": k == "cyl",
                          "size": s, "c": c, "group": group, "box": k == "box", "scale": scale})
    return m


def brick(n, a, b, c, **o):
    return part(n, c, (b[0] - a[0], b[1] - a[1], b[2] - a[2]), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), **o)


def wall(n, ax, a0, a1, c0, c1, y0, courses, color, L=4, h=BH, studs=False, stagger=True, holes=(), parent=I, **o):
    """Running bond, as the concept. LOD2 merges each course's runs, and identical courses into one box."""
    col = color if callable(color) else (lambda ci, si: color)

    def put(u, v, ya, yb, cc, nm, st=False):
        brick(nm, (u, ya, c0) if ax == "x" else (c0, ya, u), (v, yb, c1) if ax == "x" else (c1, yb, v), cc, parent=parent, studs=st, **o)

    def cut(segs, ci):
        for H in holes:
            if H["c0"] <= ci <= H["c1"]:
                segs = [q for u, v in segs for q in ([(u, v)] if v <= H["a0"] or u >= H["a1"] else
                                                     [x for x in ((u, H["a0"]), (H["a1"], v)) if x[1] - x[0] > .01])]
        return segs

    if Ctx.lod == 2:
        ci = 0
        while ci < courses:
            key, end = (cut([(a0, a1)], ci), col(ci, 0)), ci + 1
            while end < courses and (cut([(a0, a1)], end), col(end, 0)) == key:
                end += 1
            for u, v in key[0]:
                put(u, v, y0 + ci * h, y0 + end * h, key[1], n)
            ci = end
        return
    for ci in range(courses):
        s, si, y = a0, 0, y0 + ci * h
        while s < a1 - 1e-6:
            e = min(s + (L if si or not ci % 2 or not stagger else L / 2), a1)
            for u, v in cut([(s, e)], ci):
                put(u, v, y, y + h, col(ci, si), "%s_c%d_%d" % (n, ci, si), st=studs and ci == courses - 1)
            s, si = e, si + 1


def plates(n, x0, x1, z0, z1, y, c, step=8, patch=None, **o):
    if Ctx.lod == 2:
        return brick(n, (x0, y, z0), (x1, y + PH, z1), c, **o)
    x = x0
    i = 0
    while x < x1 - 1e-6:
        z = z0
        while z < z1 - 1e-6:
            brick("%s_%d" % (n, i), (x, y, z), (min(x + step, x1), y + PH, min(z + step, z1)), c, patch=patch, **o)
            i, z = i + 1, z + step
        x += step


def attach(name, pos, yaw=0.0):
    """pos in concept coords; yaw 0 = looking at the open sea (Blender -Y), 90 = +X (port)."""
    if Ctx.lod == 0:
        Ctx.atts.append((name, pos, yaw))


def col(a, b, m=I):
    if Ctx.lod == 0:
        Ctx.cols.append((a, b, m))


# ------------------------------------------------------------------ the station (the concept's order)
def island():
    Ctx.group = "Island"
    def band(n, ax, a0, a1, c0, c1, top="wall"):
        wall(n, ax, a0, a1, c0, c1, -4, 2, "deep", L=8, bev=0)                  # under the water: plain
        wall(n, ax, a0, a1, c0, c1, -1.6, 1, top, L=8)
    band("isl_back", "x", -32, 32, -30, -28)
    band("isl_side_S", "z", -28, 8, -32, -30)
    band("isl_side_P", "z", -28, 8, 30, 32)
    band("isl_front_S", "x", -30, -12, 6, 8, top="white")
    band("isl_front_P", "x", 12, 30, 6, 8, top="white")
    band("bay_wall_S", "z", -22, 6, -14, -12, top="white")
    band("bay_wall_P", "z", -22, 6, 12, 14, top="white")
    band("bay_back", "x", -14, 14, -24, -22, top="white")
    brick("isl_core_S", (-30, -4, -28), (-14, -.4, 6), "deep")
    brick("isl_core_P", (14, -4, -28), (30, -.4, 6), "deep")
    brick("isl_core_back", (-14, -4, -28), (14, -.4, -24), "deep")
    Ctx.group = "Deck"
    plates("baseplate_S", -32, -12, -30, 8, -.4, "green", patch="green")
    plates("baseplate_P", 12, 32, -30, 8, -.4, "green", patch="green")
    plates("baseplate_back", -12, 12, -30, -22, -.4, "green", patch="green")
    plates("quay_S", -30, -12, -26, 8, 0, "quay", patch="quay")
    plates("quay_P", 12, 30, -26, 8, 0, "quay", patch="quay")
    plates("quay_back", -12, 12, -26, -22, 0, "quay", patch="quay")
    col((-32, -4, -30), (-12, PH, 8))
    col((12, -4, -30), (32, PH, 8))
    col((-12, -4, -30), (12, PH, -22))

    def pier(n, x0, x1, c):                # round 2: chunky pier heads, port red, starboard green, frame the mouth from the sea
        brick(n + "_foot", (x0, -4, 8), (x1, -1.6, 11), "deep", bev=0)
        brick(n + "_c0", (x0, -1.6, 8), (x1, -.4, 11), c, bev=.12)
        brick(n + "_c1", (x0, -.4, 8), (x1, .8, 11), "white", bev=.12)
        brick(n + "_c2", (x0, .8, 8), (x1, 2, 11), c, bev=.12, studs=True)
        col((x0, -4, 8), (x1, 2, 11))
    pier("pier_P", 12, 15, "red")
    pier("pier_S", -15, -12, "btn")
    attach("ATT_BoatLanding", (0, WATER, -12))
    attach("ATT_BayMouth", (0, WATER, 5))


def quay():
    Ctx.group = "QuayProps"
    kerb = lambda ci, si: "white" if si % 2 else "yellow"
    wall("kerb_S", "z", -22, 2, -14, -12, PH, 1, kerb, studs=True, bev=.12, holes=[dict(a0=-17, a1=-13, c0=0, c1=0)])     # gap: ladder + board console
    wall("kerb_P", "z", -22, 2, 12, 14, PH, 1, kerb, studs=True, bev=.12)
    wall("kerb_back", "x", -14, 14, -24, -22, PH, 1, kerb, studs=True, bev=.12)
    wall("kerb_front_S", "x", -30, -18, 6, 8, PH, 1, kerb, studs=True, bev=.12)
    wall("kerb_front_P", "x", 18, 25.6, 6, 8, PH, 1, kerb, studs=True, bev=.12)
    for a_, b_ in (((-14, PH, -22), (-12, 1.6, -17)), ((-14, PH, -13), (-12, 1.6, 2)), ((12, PH, -22), (14, 1.6, 2)), ((-14, PH, -24), (14, 1.6, -22)),
                   ((-30, PH, 6), (-18, 1.6, 8)), ((18, PH, 6), (25.6, 1.6, 8))):
        col(a_, b_)
    for i, (x, z) in enumerate(((-13, -23), (-13, -11), (13, -20), (13, -12), (13, -5))):      # on the kerb: the walkway behind stays clear
        part("bollard_%d" % i, "black", (.9, 1.05, .9), (x, 1.6 + .48, z), k="cyl", seg=10)
        part("bollard_cap_%d" % i, "black", (1.15, .3, 1.15), (x, 1.6 + 1.12, z), k="cyl", seg=10, studs=True, bot=True)
        col((x - .6, 1.6, z - .6), (x + .6, 2.9, z + .6))
    for i, z in enumerate((-18, -12, -6, 0)):
        for sx in (-1, 1):
            part("fender_%d_%d" % (sx, i), "rubber", (1.7, 1.7, .64), (sx * 11.66, -.6, z), (0, 90, 0), k="torus", tube=.32, seg=12)
    for i, x in enumerate((-26, -19, 19, 26)):
        part("fender_front_%d" % i, "rubber", (1.7, 1.7, .64), (x, -.6, 8.34), k="torus", tube=.32, seg=12)
    for i, z in enumerate((-14.6, -13.4)):
        part("ladder_rail_%d" % i, "yellow", (.2, 4.6, .2), (-11.75, -.9, z), k="cyl", seg=6, bot=True)
    for i in range(6):
        part("ladder_rung_%d" % i, "yellow", (.14, 1.2, .14), (-11.75, -2.8 + i * .6, -14), (90, 0, 0), k="cyl", seg=6)
    attach("ATT_QuayLadderTop", (-11.75, PH, -14))
    wall("lifebuoy_post", "z", -.5, .5, -16, -15, PH, 3, lambda ci, si: "white" if ci % 2 else "red", L=1, studs=True, stagger=False)
    col((-16, PH, -.5), (-15, PH + 3.6, .5))
    ring = grp((-14.6, 3.2, 0), (0, 90, 0))
    for k_ in range(4):
        part("lifebuoy_%d" % k_, "orange" if k_ % 2 == 0 else "white", (1.8, 1.8, .6), r=(0, 0, k_ * 90), k="torus", tube=.3, arc=math.pi / 2, parent=ring)

    def lamp(n, x, z, y0=PH):
        part(n + "_base", "black", (1.2, .5, 1.2), (x, y0 + .2, z), k="cyl", seg=10)
        part(n + "_post", "navy", (.4, 6, .4), (x, y0 + 3.4, z), k="cyl", seg=8)
        part(n + "_arm", "navy", (1.6, .3, .3), (x, y0 + 6.2, z), bev=.04, bot=True)
        part(n + "_cap", "navy", (1.2, .6, 1.2), (x, y0 + 6.75, z), k="cyl", top=.25, seg=10, bot=True)
        part(n + "_lantern", "bulb", (.9, .9, .9), (x, y0 + 6.1, z), k="sphere", seg=8, g="GlowBulb")
        col((x - .6, y0, z - .6), (x + .6, y0 + 7, z + .6))
    lamp("lamp_S", -24, -20)
    lamp("lamp_P", 13, -8.5, 1.6)      # round 2: on the kerb, clear of the way round the workshop corner


def towers():
    Ctx.group = "Towers"

    def tower(n, x0, z0):
        if Ctx.lod == 2:
            runs = ((0, 3, "red"), (3, 4, "white"), (4, 7, "red"), (7, 8, "white"), (8, 11, "red"), (11, 12, "white"), (12, 13, "red"))
            for a, b, c in runs:
                brick("%s_%d" % (n, a), (x0, PH + a * BH, z0), (x0 + 6, PH + b * BH, z0 + 6), c)
            return
        for ci in range(13):
            y, c = PH + ci * BH, "white" if ci in (3, 7, 11) else "red"
            for k_ in range(3):
                a, b = ((x0 + 2 * k_, y, z0), (x0 + 2 * k_ + 2, y + BH, z0 + 6)) if ci % 2 else ((x0, y, z0 + 2 * k_), (x0 + 6, y + BH, z0 + 2 * k_ + 2))
                brick("%s_c%d_%d" % (n, ci, k_), a, b, c, studs=ci == 12, bev=.1)
    tower("tower_P", 12, 2)
    tower("tower_S", -18, 2)
    col((12, PH, 2), (18, 16, 8))
    col((-18, PH, 2), (-12, 16, 8))
    Ctx.group = "Beam"
    wall("beam", "x", -18, 18, 3, 7, 16, 3, "yellow", L=6, studs=True, bot=True, bev=.1)
    col((-18, 16, 3), (18, 19.6, 7))
    for sx in (-1, 1):
        s = "P" if sx > 0 else "S"
        brick("beam_corbel_%s1" % s, (9 if sx > 0 else -12, 14.8, 3), (12 if sx > 0 else -9, 16, 7), "yellow", bot=True)
        brick("beam_corbel_%s2" % s, (11 if sx > 0 else -12, 13.6, 3), (12 if sx > 0 else -11, 14.8, 7), "yellow", bot=True)
        col((9 if sx > 0 else -12, 13.6, 3), (12 if sx > 0 else -9, 16, 7))
    brick("beam_badge", (-2.1, 16.2, 7), (2.1, 18.8, 7.3), "white", bot=True)
    if Ctx.lod < 2:
        badge()
    for sx, cc, s, gl, nm in ((1, "portLt", "P", "GlowPort", "Port"), (-1, "stbdLt", "S", "GlowStbd", "Stbd")):
        part("nav_light_base_" + s, "black", (1.3, .5, 1.3), (sx * 15, 19.8, 5), k="cyl", seg=10)
        part("nav_light_" + s, cc, (1.1, .55, 1.1), (sx * 15, 20.03, 5), k="sphere", half=True, seg=10, g=gl)
        attach("ATT_NavLight_" + nm, (sx * 15, 20.6, 5))


def badge():
    """Up-arrow badge: canvas 512 x 260 mapped to 3.9 x 2.3 at z 7.325 (print on the white brick)."""
    def pts(raw):
        return [((x - 256) / 512 * 3.9, 17.5 + (130 - y) / 260 * 2.3) for x, y in raw]
    big = pts(((256, 22), (400, 150), (316, 150), (316, 240), (196, 240), (196, 150), (112, 150)))
    decal(I, offset2d(big if area2d(big) > 0 else big[::-1], .07), "ink", 7.33)
    decal(I, big, "red", 7.38)
    for x in (60, 452):
        sm = pts(((x, 70), (x + 40, 110), (x + 20, 110), (x + 20, 200), (x - 20, 200), (x - 20, 110), (x - 40, 110)))
        decal(I, offset2d(sm if area2d(sm) > 0 else sm[::-1], .05), "ink", 7.33)
        decal(I, sm, "yellow", 7.38)


def jaw_shape(N):
    R_, w = 4.6, 1.8                                     # round 2: open jaw much bigger (was 3, 1.15)
    y = math.sqrt(R_ * R_ - w * w)
    a = math.atan2(y, w)
    span = (a - (math.pi - a)) % (2 * math.pi)          # clockwise, round the bottom
    pts = [(R_ * math.cos(a - span * i / N), R_ * math.sin(a - span * i / N)) for i in range(N + 1)]
    pts.append((-w, 0))
    k = max(3, N // 4)
    pts += [(w * math.cos(math.pi + math.pi * i / k), w * math.sin(math.pi + math.pi * i / k)) for i in range(1, k)]
    pts.append((w, 0))
    return pts


def wrench(p, pre, c="steel", full=True):
    part(pre + "_handle", c, (3.3, 13, 3.5), parent=p, bev=.32 if full else .05)     # round 2: thicker, matte light steel
    N = 22 if Ctx.lod == 0 else 12 if Ctx.lod == 1 else 8
    extrude(p @ T((0, 9.0, 0)), c, jaw_shape(N), d=3.0)
    n = 24 if Ctx.lod == 0 else 12 if Ctx.lod == 1 else 6
    R_, H = 3.4, 1.6
    outer = [(R_ * math.cos(2 * math.pi * i / n), R_ * math.sin(2 * math.pi * i / n)) for i in range(n)]
    hexv = [(H * math.cos(i * math.pi / 3 + math.pi / 6), H * math.sin(i * math.pi / 3 + math.pi / 6)) for i in range(6)]
    per = n // 6
    inner = []
    for i in range(6):
        a, b = hexv[i], hexv[(i + 1) % 6]
        inner += [(a[0] + (b[0] - a[0]) * j / per, a[1] + (b[1] - a[1]) * j / per) for j in range(per)]
    # match the hole's start angle to the outer ring so the annulus quads do not twist
    shift = -round(30 / (360 / n))
    inner = inner[shift:] + inner[:shift]
    extrude(p @ T((0, -8.2, 0)), c, outer, d=3.0, hole=inner)


def hammer(p, pre):
    part(pre + "_handle", "handle", (3.5, 16, 3.5), (0, -1, 0), k="cyl", seg=16, parent=p)     # round 2: 35% thicker
    part(pre + "_grip", "rubber", (4, 4.6, 4), (0, -6.8, 0), k="cyl", seg=16, parent=p)
    part(pre + "_knob", "rubber", (4.6, .9, 4.6), (0, -9.4, 0), k="cyl", seg=16, parent=p, bot=True)
    part(pre + "_collar", "red", (4, .7, 4), (0, 5.9, 0), k="cyl", seg=16, parent=p, bot=True)
    part(pre + "_head", "iron", (9.4, 5.1, 5.1), (0, 9, 0), parent=p, bev=.35, bot=True)
    for sx in (-1, 1):
        part(pre + "_face_%d" % sx, "ironLt", (5.6, .8, 5.6), (sx * 5.1, 9, 0), (0, 0, 90), k="cyl", seg=16, parent=p, bot=True)


def landmark():
    Ctx.group = "Tools"
    X = grp((0, 22.5, 7.4), (-45, 0, 0))
    wrench(grp((0, 0, -2.2), (0, 0, -45), X), "wrench")
    hammer(grp((0, 0, 2.4), (0, 0, 45), X), "hammer")
    part("tools_hub", "red", (4.6, 10, 4.6), r=(90, 0, 0), k="cyl", seg=16, parent=X, bot=True)
    for s in (-1, 1):
        part("tools_hub_cap_%d" % s, "yellow", (3.2, .5, 3.2), (0, 0, s * 5.2), (90, 0, 0), k="cyl", seg=6, parent=X, bot=True)
    attach("ATT_ToolsHub", tuple(X.translation))


def hoist():
    Ctx.group = "Hoist"
    brick("hoist_rail", (-9, 15.4, 6.4), (9, 16, 7.6), "iron", bot=True)
    for s in (-1, 1):
        brick("hoist_stop_%d" % s, (-9 if s < 0 else 8.6, 14.9, 6.2), (-8.6 if s < 0 else 9, 15.4, 7.8), "red", bot=True)
    brick("hoist_trolley", (5.3, 14.6, 5.4), (7.9, 15.36, 8.2), "yellow", bot=True)
    for i, (a, b) in enumerate(((5.4, 5.7), (7.9, 8.2))):
        brick("hoist_trolley_plate_%d" % i, (5.5, 15.36, a), (7.7, 15.94, b), "yellow")
    for i, x in enumerate((5.9, 7.3)):
        for j, z in enumerate((6.15, 7.85)):
            part("hoist_wheel_%d%d" % (i, j), "black", (.5, .26, .5), (x, 15.65, z), (90, 0, 0), k="cyl", seg=8, bot=True)
    part("hoist_chain_0", "iron", (.5, .5, .18), (6.6, 14.38, 6.8), (0, 0, 90), k="torus", tube=.09, seg=8)
    brick("hoist_hook_block", (5.7, 13.2, 6), (7.5, 14.14, 7.6), "orange", bot=True)
    part("hoist_sheave", "yellow", (1, .2, 1), (6.6, 13.67, 7.66), (90, 0, 0), k="cyl", seg=10, bot=True)
    part("hoist_hook_shank", "chrome", (.36, .5, .36), (6.6, 13, 6.8), k="cyl", seg=8, bot=True)
    part("hoist_hook", "chrome", (1.3, 1.3, .44), (6.6, 12.3, 6.8), (0, 0, 129), k="torus", tube=.22, arc=math.pi * 1.45, seg=12)
    attach("ATT_HoistHook", (6.6, 11.7, 6.8))


def workshop():
    """Round 2: bigger (12 x 15, was 10 x 10), forward and out from behind the port pillar, wide open double door to the sea."""
    Ctx.group = "Workshop"
    wall("ws_wall_bay", "z", -17, -2, 18, 19, PH, 9, "blue", holes=[dict(a0=-11, a1=-6, c0=1, c1=3)])
    wall("ws_wall_back", "x", 19, 29, -17, -16, PH, 9, "blue")
    wall("ws_wall_front", "x", 19, 29, -3, -2, PH, 9, "blue", holes=[dict(a0=21.5, a1=27.5, c0=0, c1=6)])
    wall("ws_wall_out", "z", -17, -2, 29, 30, PH, 9, "blue")
    brick("ws_door_frame_L", (21, PH, -2), (21.5, 8.8, -1.6), "white")
    brick("ws_door_frame_R", (27.5, PH, -2), (28, 8.8, -1.6), "white")
    brick("ws_door_frame_top", (21, 8.8, -2), (28, 9.6, -1.6), "white", bot=True)
    for nm, x, yaw in (("L", 21.05, -12), ("R", 27.95, 12)):                    # the leaves stand wide open
        m = part("ws_door_" + nm, "red", (.4, 8.2, 3), (x, PH + 4.1, -.45), (0, yaw, 0), bev=.06, bot=True)
        part("ws_door_glass_" + nm, "glass", (.5, 2.4, 1.8), (0, 2, 0), parent=m, bev=0, g="Glass")
    for nm, a, b in (("top", (-11.4, 5.2), (-5.6, 5.6)), ("sill", (-11.4, 1.2), (-5.6, 1.6)), ("l", (-11.4, 1.6), (-11, 5.2)), ("r", (-6, 1.6), (-5.6, 5.2))):
        brick("ws_win_" + nm, (17.6, a[1], a[0]), (18, b[1], b[0]), "white", bot=True)
    brick("ws_win_glass", (18.3, 1.6, -11), (18.7, 5.2, -6), "glass", g="Glass", bot=True)
    brick("ws_win_bar_h", (18.25, 3.2, -10.9), (18.75, 3.6, -6.1), "white", bot=True)
    brick("ws_win_bar_v", (18.2, 1.7, -8.7), (18.8, 5.1, -8.3), "white")
    for k_ in range(6):
        brick("ws_roof_step_%d" % k_, (17 + k_, 11.2 + k_ * .8, -18), (31 - k_, 12 + k_ * .8, -1), "yellow", studs=True, bot=True, bev=.1)
    part("ws_roof_ridge", "red", (.9, 17, .9), (24, 16.45, -9.5), (90, 0, 0), k="cyl", seg=10, bot=True)
    brick("ws_sign", (19.2, 11.6, -1), (28.8, 14.4, -.7), "white", bot=True)
    if Ctx.lod < 2:
        sign()
    attach("ATT_WorkshopDoor", (24.5, PH, -2))
    attach("ATT_WorkbenchTop", (24, 3.2, -15))
    col((18, PH, -17), (19, 11.2, -2))
    col((19, PH, -17), (29, 11.2, -16))
    col((29, PH, -17), (30, 11.2, -2))
    col((19, PH, -3), (21.5, 11.2, -2))
    col((27.5, PH, -3), (29, 11.2, -2))
    col((21.5, 8.8, -3), (27.5, 11.2, -2))
    col((20.8, PH, -2), (21.4, 8.6, 1))
    col((27.6, PH, -2), (28.2, 8.6, 1))
    col((17, 11.2, -18), (31, 12.8, -1))
    col((19, 12.8, -18), (29, 14.4, -1))
    col((21, 14.4, -18), (27, 16, -1))
    Ctx.group = "Interior"
    W = T((2, 0, 1))                        # the concept's fit-out, moved with the back and side walls
    brick("ws_bench_top", (19.5, 2.8, -17), (24.5, 3.2, -15), "brown", studs=True, bot=True, parent=W)
    for i, (x, z) in enumerate(((19.5, -16), (23.5, -16))):
        brick("ws_bench_leg_%d" % i, (x, PH, z), (x + 1, 2.8, z + 1), "iron", bev=.04, parent=W)
    brick("ws_vise", (19.9, 3.2, -16.6), (21.3, 4, -15.6), "iron", bev=.05, parent=W)
    brick("ws_vise_jaw_a", (19.9, 4, -16.6), (20.3, 4.6, -15.6), "ironLt", bev=.03, parent=W)
    brick("ws_vise_jaw_b", (20.9, 4, -16.6), (21.3, 4.6, -15.6), "ironLt", bev=.03, parent=W)
    part("ws_vise_bar", "chrome", (.16, 1.8, .16), (20.6, 3.6, -15.3), (0, 0, 90), k="cyl", seg=6, bot=True, parent=W)
    brick("ws_toolbox", (22.4, 3.2, -16.7), (24.2, 4.4, -15.5), "red", studs=True, parent=W)
    brick("ws_pegboard", (19.5, 3.6, -17), (24.8, 7, -16.8), "wood", bev=.04, parent=W)
    wrench(grp((20.4, 5.4, -16.5), (0, 0, 12), W, .17), "ws_peg_wrench", full=False)
    hm = grp((22, 5.4, -16.3), (0, 0, -10), W, .15)
    part("ws_peg_hammer_handle", "handle", (2.6, 16, 2.6), (0, -1, 0), k="cyl", seg=6, parent=hm, bot=True)
    part("ws_peg_hammer_head", "iron", (7.8, 3.8, 3.8), (0, 8.6, 0), parent=hm, bev=.1, bot=True)
    part("ws_peg_driver_grip", "red", (.5, 1.1, .5), (23.3, 6, -16.5), k="cyl", seg=8, bot=True, parent=W)
    part("ws_peg_driver_shaft", "chrome", (.16, 1.6, .16), (23.3, 4.7, -16.5), k="cyl", seg=6, parent=W)
    part("ws_peg_saw", "chrome", (1.6, .8, .12), (24, 6.4, -16.6), (0, 0, -8), bev=0, parent=W)
    brick("ws_shelf", (17, 4.8, -13), (18, 5, -9), "white", bot=True, bev=.03, parent=W)
    for i, (c, z) in enumerate((("red", -12.3), ("blue", -11.1), ("yellow", -9.9))):
        part("ws_paint_%d" % i, c, (.7, .9, .7), (17.5, 5.45, z), k="cyl", seg=8, studs=True, parent=W)
    brick("ws_tool_chest", (17, PH, -17), (19.2, 3.2, -14.6), "red", studs=True, parent=W)
    for i, y in enumerate((1.2, 2.1)):
        brick("ws_tool_chest_drawer_%d" % i, (19.2, y, -16.8), (19.4, y + .25, -14.8), "white", bev=0, parent=W)
    part("ws_lamp_cord", "black", (.1, 3.4, .1), (24, 9.5, -8), k="cyl", seg=6)
    part("ws_lamp_shade", "yellow", (1.6, .8, 1.6), (24, 7.45, -8), k="cyl", top=.25, seg=12, bot=True)
    part("ws_lamp_bulb", "bulb", (.5, .5, .5), (24, 7.05, -8), k="sphere", seg=8, g="GlowBulb")
    col((21.5, PH, -16), (26.5, 3.2, -14))
    col((19, PH, -16), (21.2, 3.2, -13.6))


def sign():
    """The tool sign over the door: navy plate, yellow gear, white wrench (the concept's print, enlarged, as geometry)."""
    k, ic = 9.6 / 768, 1.7

    def at(px, py):
        return (24 + (px - 384) * k, 13 + (85 - py) * k)
    decal(I, [(19.4, 11.8), (28.6, 11.8), (28.6, 14.2), (19.4, 14.2)], "navy", -.68)
    gear = [at(270 + math.cos(i * math.pi / 8) * (36 if i % 2 else 48) * ic, 85 + math.sin(i * math.pi / 8) * (36 if i % 2 else 48) * ic) for i in range(16)]
    decal(I, gear, "yellow", -.63)
    decal(I, [at(270 + 15 * ic * math.cos(i * math.pi / 5), 85 + 15 * ic * math.sin(i * math.pi / 5)) for i in range(10)], "navy", -.58)
    r, cx, cy = -.7, 500, 85

    def rot(x, y):
        return at(cx + ic * (x * math.cos(r) - y * math.sin(r)), cy + ic * (x * math.sin(r) + y * math.cos(r)))
    decal(I, [rot(-11, -38), rot(11, -38), rot(11, 44), rot(-11, 44)], "white", -.63)
    decal(I, [rot(24 * math.cos(i * math.pi / 5), -40 + 24 * math.sin(i * math.pi / 5)) for i in range(10)], "white", -.62)
    decal(I, [rot(-9, -66), rot(9, -66), rot(9, -38), rot(-9, -38)], "navy", -.58)


def tyre(n, p, r, d=4.4):
    t = grp(p, r)
    part(n, "rubber", (d, d, 1.5), k="torus", tube=.75, parent=t)
    part(n + "_hub", "ironLt", (d * .45, 1.1, d * .45), r=(90, 0, 0), k="cyl", seg=10, parent=t, bot=True)


def crate(n, p, a, ry):
    m = part(n, "crate", (a, a, a), p, (0, ry, 0), bev=.03, bot=False)
    if Ctx.lod:
        return
    h, t = a / 2 - .02, a * .1                     # frames proud of the sides, the concept's crate print as geometry
    for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
        part(n + "_post", "crateDk", (t, a - .02, t), (sx * (h - t / 2 + .05), 0, sz * (h - t / 2 + .05)), parent=m, bev=0)
    for s in (-1, 1):
        for y in (-h + t / 2, h - t / 2 + .05):
            part(n + "_railx", "crateDk", (a - 2 * t, t, t * .6), (0, y, s * (h - t * .3 + .04)), parent=m, bev=0)
            part(n + "_railz", "crateDk", (t * .6, t, a - 2 * t), (s * (h - t * .3 + .04), y, 0), parent=m, bev=0)
    d = h - t
    decal(m @ T((0, 0, h + .03)), [(-d, -d + t), (-d + t, -d), (d, d - t), (d - t, d)], "crateDk", 0, group="Spares")
    decal(m @ R((0, 90, 0)) @ T((0, 0, h + .03)), [(-d, -d + t), (-d + t, -d), (d, d - t), (d - t, d)], "crateDk", 0, group="Spares")


def prop_(n, p, r, sc=1):
    g = grp(p, r, I, sc)
    part(n + "_hub", "brass", (1, 1.1, 1), r=(90, 0, 0), k="cyl", seg=12, parent=g, bot=True)
    part(n + "_cone", "brass", (1, .8, 1), (0, 0, .95), (90, 0, 0), k="cyl", top=.1, seg=12, parent=g, bot=True)
    for k_ in range(3):
        b = g @ R((0, 0, k_ * 120))
        part("%s_blade_%d" % (n, k_), "brass", (1.3, 2.2, .32), (0, 1.5, 0), (0, 28, 0), parent=b, bev=.04)


def spares():
    """Round 2: everything on one wooden tray in the outer front corner, clear of the door: tyres, prop, crate + spring, engine, anchor."""
    Ctx.group = "Spares"
    PT = .8
    brick("spare_tray", (25.6, 0, 1.2), (31.8, PT, 8), "wood", studs=True, bev=.1)
    for i in range(3):
        tyre("spare_tyre_stack_%d" % i, (28.2 + (.2 if i % 2 else -.15), PT + .75 + i * 1.5, 3.4), (90, i * 25, 0))
    prop_("spare_prop_big", (28.2, PT + 5.1, 3.4), (78, 0, 10), 1.6)
    crate("spare_crate_a", (29.7, PT + 1.2, 6.7), 2.4, 8)
    e = grp((27.25, PT, 6.6), (0, -8, 0))
    brick("spare_engine_block", (-1.6, 0, -1.2), (1.6, 2, 1.2), "iron", parent=e, bev=.08)
    brick("spare_engine_head", (-1.5, 2, -1), (1.5, 2.4, 1), "red", parent=e, studs=True)
    for i, x in enumerate((-1, 0, 1)):
        part("spare_engine_piston_%d" % i, "chrome", (.8, .9, .8), (x, 2.82, 0), k="cyl", seg=8, parent=e)
    part("spare_engine_exhaust", "ironLt", (.5, 2.2, .5), (0, 1.1, 1.45), (0, 0, 90), k="cyl", seg=8, parent=e, bot=True)
    a = grp((31.1, PT, 3.4), (0, 90, 0))
    part("spare_anchor_shank", "navy", (1, 6.4, 1), (0, 4.2, 0), k="cyl", seg=10, parent=a, bot=True)
    part("spare_anchor_ring", "navy", (1.8, 1.8, .6), (0, 8.1, 0), k="torus", tube=.3, parent=a)
    part("spare_anchor_stock", "navy", (.7, 2.4, .7), (0, 6.8, 0), (90, 0, 0), k="cyl", seg=8, parent=a, bot=True)
    for s_ in (-1, 1):
        part("spare_anchor_ball_%d" % s_, "navy", (1.1, 1.1, 1.1), (0, 6.8, s_ * 1.2), k="sphere", seg=8, parent=a)
    part("spare_anchor_arms", "navy", (6, 6, 1), (0, 3.5, 0), (0, 0, 180), k="torus", tube=.5, arc=math.pi, parent=a)
    part("spare_anchor_crown", "navy", (1.4, 1.4, 1.4), (0, 1.1, 0), k="sphere", seg=10, parent=a)
    for s_ in (-1, 1):
        part("spare_anchor_fluke_%d" % s_, "navy", (1.6, 1.8, 1.6), (s_ * 2.5, 4.2, 0), (0, 0, -s_ * 20), k="cyl", top=0, seg=4, parent=a)
    if Ctx.lod < 2:                                # chrome spring on the crate; the concept's 260 x 10 tube is cut to 96 x 6
        turns, per, rad = 6, 16 if Ctx.lod == 0 else 8, 6 if Ctx.lod == 0 else 4
        m = T((29.7, PT + 2.4 - .3, 6.7))
        rings = []
        for i in range(turns * per + 1):
            t = i / (turns * per)
            aa = t * turns * 2 * math.pi
            c = Vector((1.1 * math.cos(aa), .35 + t * 4.2, 1.1 * math.sin(aa)))
            n1 = Vector((math.cos(aa), 0, math.sin(aa)))
            n2 = Vector((0, 1, 0))
            rings.append([tuple(c + .28 * (math.cos(2 * math.pi * j / rad) * n1 + math.sin(2 * math.pi * j / rad) * n2)) for j in range(rad)])
        v, f = sweep_geo(rings, False)
        emit(m, v, f, "chrome", smooth=True)
    col((25.6, PH, 1.2), (31.8, 6, 8))
    attach("ATT_SparePile", (28.5, PH, 4.5))


def board():
    Ctx.group = "Board"
    BG = grp((-21, PH, -13), (0, 60, 0), I, BOARD_SCALE)
    for i, x0 in enumerate((-5.5, 3.5)):
        wall("board_leg_%d" % i, "x", x0, x0 + 2, -1, 1, 0, 9, lambda ci, si: "white" if ci % 3 == 2 else "red", L=2, studs=True, stagger=False, parent=BG, bot=False)
        col((x0, 0, -1), (x0 + 2, 10.8, 1), BG)
    brick("board_panel", (-6.5, 2.8, 1), (6.5, 11.6, 1.8), "blue", parent=BG, studs=True, bot=True)
    brick("board_backplate", (-3.5, 0, 1), (3.5, 2.8, 1.8), "blue", parent=BG)
    # round 2: a chunky bright frame and a red crest; the panel is bright blue with a big arrow on its back, no dead navy
    for nm, a, b in (("top", (-7.1, 10.8), (7.1, 12.2)), ("bottom", (-7.1, 2.8), (7.1, 3.6)), ("left", (-7.1, 3.6), (-5.7, 10.8)), ("right", (5.7, 3.6), (7.1, 10.8))):
        brick("board_frame_" + nm, (a[0], a[1], 1.8), (b[0], b[1], 2.6), "yellow", parent=BG, bot=True, bev=.12, studs=nm == "top")
    brick("board_crest", (-3.2, 12.2, 1.8), (3.2, 13.6, 2.6), "red", parent=BG, bev=.12, studs=True)
    arrow = [(0, 13.35), (1.1, 12.85), (.45, 12.85), (.45, 12.4), (-.45, 12.4), (-.45, 12.85), (-1.1, 12.85)]
    decal(BG, arrow, "white", 2.62)
    back = BG @ R((0, 180, 0))
    rear = [(0, 10.8), (3.1, 7.6), (1.5, 7.6), (1.5, 3.4), (-1.5, 3.4), (-1.5, 7.6), (-3.1, 7.6)]
    decal(back, offset2d(rear if area2d(rear) > 0 else rear[::-1], .14), "ink", -.94)
    decal(back, rear, "yellow", -.9)
    # the blank screen: lit by the game's SurfaceGui, one flat quad 11.4 x 7.2 (x 1.3) inside the frame
    decal(BG, [(-5.7, 3.6), (5.7, 3.6), (5.7, 10.8), (-5.7, 10.8)], "screen", 1.85, group="Screen")
    # the console's sea corner pokes into a gap in the starboard kerb; x * .5 + z * .866 under 6.85 keeps it off the bay (x +-12)
    brick("board_console_foot", (-4.4, 0, 1.8), (4.4, .8, 4), "yellow", parent=BG, bev=.1)
    brick("board_console", (-5, .8, 1.8), (5, 1.8, 4.4), "white", parent=BG, bot=True, bev=.12)
    brick("board_button_collar", (-4.6, 1.8, 2.65), (4.6, 2.1, 4.3), "ink", parent=BG, g="Button", bev=.04)
    brick("board_upgrade_button", (-4.3, 2.1, 2.75), (4.3, 3.4, 4.2), "btn", parent=BG, studs=True, g="Button", bev=.14)
    col((-7.1, 2.8, 1), (7.1, 13.6, 2.6), BG)
    col((-5, 0, 1), (5, 3.4, 4.4), BG)
    attach("ATT_BoardScreen", tuple(BG @ Vector((0, 7.2, 1.85))), 60)
    attach("ATT_BoardButton", tuple(BG @ Vector((0, 2.8, 3))), 60)
    attach("ATT_PlayerSpawn", (-14.3, PH, -20.6), 60)


def greens():
    Ctx.group = "Greens"

    def trunk(n, x, z):
        wall(n + "_trunk", "x", x - 1, x + 1, z - 1, z + 1, 0, 2, "brown", L=2, stagger=False)
        col((x - 1, 0, z - 1), (x + 1, 2.4, z + 1))

    def round_tree(n, x, z):
        trunk(n, x, z)
        for i, (d, y) in enumerate(((5, 3), (4, 4.2), (2.6, 5.4), (1, 6.6))):
            part("%s_leaf_%d" % (n, i), "green" if i % 2 else "leaf", (d, 1.2, d), (x, y, z), k="cyl", studs=True, seg=14 if d > 2 else 10, bot=i == 0)

    def cone_tree(n, x, z):
        trunk(n, x, z)
        for i, d in enumerate((4.6, 4, 3.4, 2.8, 2.2, 1.6, 1)):
            part("%s_leaf_%d" % (n, i), "fir1" if i % 2 else "fir2", (d, 1.2, d), (x, 3 + i * 1.2, z), k="cyl", studs=True, seg=14 if d > 2 else 10, bot=i == 0)

    def palm(n, x, z, lean):
        for i in range(6):
            part("%s_trunk_%d" % (n, i), "palm" if i % 2 else "brown", (1, 1.2, 1), (x + lean * i * i * .05, .6 + i * 1.2, z), k="cyl", seg=8, studs=i == 5)
        col((x - .6, 0, z - .6), (x + .6, 7, z + .6))
        cr = T((x + lean * 1.25, 7.4, z))
        part(n + "_crown", "leaf", (1.3, 1.3, 1.3), k="sphere", seg=8, parent=cr)
        for k_ in range(7):
            part("%s_frond_%d" % (n, k_), "green" if k_ % 2 else "leaf", (1.3, .3, 4.2), (0, -.5, 2.2), (22, 0, 0), parent=cr @ R((0, k_ * 360 / 7, 0)), bev=.05)
        for i, a in enumerate((0, 120, 240)):
            part("%s_coconut_%d" % (n, i), "brown", (.6, .6, .6), (math.cos(a * DEG) * .6, -.7, math.sin(a * DEG) * .6), k="sphere", seg=6, parent=cr)
    round_tree("tree_round_a", -24, -28)
    cone_tree("tree_cone_a", -8, -28)
    round_tree("tree_round_b", 8, -28)
    cone_tree("tree_cone_b", 24, -28)
    palm("tree_palm_a", -31, 5, 1)
    palm("tree_palm_b", 31, -21, -1)
    for i, (x, z, c) in enumerate(((-30.5, -12.5, "red"), (-31.5, -20.5, "yellow"), (-30.5, -2.5, "white"), (30.5, -4.5, "red"), (31.5, -14.5, "yellow"), (30.5, -9.5, "white"),
                                   (-3.5, -28.5, "red"), (3.5, -27.5, "yellow"), (-12.5, -28.5, "white"), (12.5, -29.5, "red"), (-19.5, -29.5, "yellow"), (19.5, -27.5, "white"))):
        part("flower_%d" % i, c, (.9, .4, .9), (x, .2, z), k="cyl", seg=8, studs=True)
    for i, (x, z) in enumerate(((-16, -28), (16, -28), (-31, -25))):
        part("bush_%d" % i, "leaf", (2, 1.2, 2), (x, .6, z), k="cyl", seg=12, studs=True)


def studs():
    """Real studs on the small tops (decks use the atlas patches): 1-stud pitch on scaled groups, none under other parts."""
    W = []
    for p in Ctx.parts:
        cs = [p["m"] @ Vector((sx * p["hi"].x, sy * p["hi"].y, sz * p["hi"].z)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        W.append((tuple(min(c[i] for c in cs) - .005 for i in range(3)), tuple(max(c[i] for c in cs) + .005 for i in range(3))))
    count = 0
    for idx, p in enumerate(Ctx.parts):
        if not p["studs"]:
            continue
        sx, sy, sz = p["size"]
        k0 = p["scale"]
        nx, nz = max(1, round(sx * k0)), max(1, round(sz * k0))
        top = sy / 2 - (0 if p["cyl"] else G / 2) - .02 / k0
        rot = p["m"].to_quaternion().to_matrix().to_4x4()
        for i in range(nx):
            for j in range(nz):
                x, z = (i - (nx - 1) / 2) / k0, (j - (nz - 1) / 2) / k0
                if p["cyl"] and nx > 1 and math.hypot(x, z) > sx / 2 - .32 / k0:
                    continue
                t = p["m"] @ Vector((x, top + .15 / k0, z))
                covered = False
                for jdx, (lo, hi) in enumerate(W):
                    if jdx != idx and all(lo[a] <= t[a] <= hi[a] for a in range(3)):
                        q = Ctx.parts[jdx]
                        l = q["inv"] @ t
                        if all(q["lo"][a] - .005 <= l[a] <= q["hi"][a] + .005 for a in range(3)):
                            covered = True
                            break
                if covered:
                    continue
                at = p["m"] @ Vector((x, top, z))
                v, f = lathe_geo([(.3, 0), (.3, .2), (0, .2)], 6 if at.y > 8 or p["n"].startswith("kerb") else 8)      # hexagons never read here
                emit(T(at) @ rot, v, f, p["c"], group=p["group"])
                count += 1
    print("[station] studs (geometry)", count)


def geometry():
    island()
    quay()
    towers()
    landmark()
    hoist()
    workshop()
    spares()
    board()
    greens()
    if Ctx.lod == 0:
        studs()


# ------------------------------------------------------------------ Blender objects
def to_blender(p):
    return (p[0], -p[2], p[1])


def material():
    mat = bpy.data.materials.get("MI_UpgradeStation_Brick") or bpy.data.materials.new("MI_UpgradeStation_Brick")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bs.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs[0])
    for kind, sock, srgb in (("ALB", "Base Color", True), ("RGH", "Roughness", False), ("MET", "Metallic", False), ("NOR", None, False)):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(os.path.join(TEX, "T_UpgradeStation_Brick_%s.png" % kind), check_existing=True)
        tex.image.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
        if sock:
            nt.links.new(tex.outputs["Color"], bs.inputs[sock])
        else:
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs[0], bs.inputs["Normal"])
    return mat


def to_object(name, verts, faces, mat, smooth=()):
    me = bpy.data.meshes.new(name)
    me.from_pydata([to_blender(v) for v in verts], [], [f[0] for f in faces])
    uv = me.uv_layers.new(name="UVMap")
    me.update()
    for poly, (idx, c, explicit) in zip(me.polygons, faces):
        lv = poly.loop_indices
        if explicit:
            cs = explicit
        else:
            u0, v0, u1, v1 = P.cell_uv(P.CELL[c])
            n = len(lv)
            cs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)] if n == 4 else [(u0, v0), (u1, v0), ((u0 + u1) / 2, v1)] if n == 3 else \
                [((u0 + u1) / 2 + (u1 - u0) / 2 * math.cos(2 * math.pi * k / n), (v0 + v1) / 2 + (v1 - v0) / 2 * math.sin(2 * math.pi * k / n)) for k in range(n)]
        for li, q in zip(lv, cs):
            uv.data[li].uv = q
        poly.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(40))
    if smooth:
        sharp = me.attributes["sharp_edge"].data
        for e in me.edges:
            if any(a <= e.vertices[0] < b for a, b in smooth):
                sharp[e.index].value = False
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def collider_faces(i):
    return [((3, 2, 1, 0), "wall", None), ((4, 5, 6, 7), "wall", None), ((0, 1, 5, 4), "wall", None), ((1, 2, 6, 5), "wall", None), ((2, 3, 7, 6), "wall", None), ((3, 0, 4, 7), "wall", None)]


def world_aabb(a, b, m):
    cs = [m @ Vector((x, y, z)) for x in (a[0], b[0]) for y in (a[1], b[1]) for z in (a[2], b[2])]
    return tuple(min(c[i] for c in cs) for i in range(3)), tuple(max(c[i] for c in cs) for i in range(3))


def walk_check():
    """Colliders against a 1-stud flood fill for a 5.5-tall, radius-1 player: quay spawn must reach the workshop's inside."""
    boxes = [(m.inverted(), a, b, m.to_scale()[0]) for a, b, m in Ctx.cols
             if world_aabb(a, b, m)[1][1] > .6 and world_aabb(a, b, m)[0][1] < 6.0]   # floors stay below .6
    free = set()
    for ix in range(-32, 33):
        for iz in range(-30, 9):
            x, z = ix + .5, iz + .5
            if -12 < x < 12 and z > -22:
                continue                                                     # the bay is water
            for inv, a, b, k in boxes:
                p = inv @ Vector((x, 0, z))
                if a[0] - 1 / k < p.x < b[0] + 1 / k and a[2] - 1 / k < p.z < b[2] + 1 / k:
                    break
            else:
                free.add((ix, iz))
    seen, todo = set(), [(-17, -21)]
    while todo:
        c = todo.pop()
        if c in free and c not in seen:
            seen.add(c)
            todo += [(c[0] + 1, c[1]), (c[0] - 1, c[1]), (c[0], c[1] + 1), (c[0], c[1] - 1)]
    inside, outside = (24, -8) in seen, (23, 2) in seen
    assert inside and outside, "walk check: outside door %s, workshop inside %s" % (outside, inside)
    print("[station] walk check OK: spawn reaches the door and the workshop inside (%d of %d cells)" % (len(seen), len(free)))


def clearance():
    """Lowest geometry over the bay water, boat lane x +-5 and full mouth x +-12, measured on LOD0 (studs above the water)."""
    out = {}
    for name, half in (("lane10", 5.0), ("mouth24", 11.9)):
        low = 1e9
        for verts, faces in Ctx.meshes.values():
            for idx, _c, _uv in faces:                                                # faces: a long box has no vertex over the lane
                ps = [verts[i] for i in idx]
                y = min(p.y for p in ps)
                if y < low and y > PH + 1.5 and min(p.x for p in ps) < half and max(p.x for p in ps) > -half and min(p.z for p in ps) < 8 and max(p.z for p in ps) > -22:
                    low = y
        out[name] = round(low - WATER, 2)
    print("[station] clearance above water", out)
    assert out["lane10"] >= 13.0, out
    for a, b, m in Ctx.cols:
        lo, hi = world_aabb(a, b, m)
        assert not (hi[0] > -12 + .01 and lo[0] < 12 - .01 and hi[2] > -22 + .01 and lo[2] < 8 - .01 and lo[1] < 13.5 and hi[1] > WATER + .01), ("collider in the bay", a, b)
    return out


def build():
    mat = material()
    meshes, spec_atts, lodtris = [], [], {}
    for lod in (0, 1, 2):
        Ctx.lod, Ctx.meshes, Ctx.smooth = lod, {}, {}
        if lod == 0:
            Ctx.parts, Ctx.atts, Ctx.cols = [], [], []
        geometry()
        if lod == 0:
            clear = clearance()
            walk_check()
        for group, (verts, faces) in Ctx.meshes.items():
            ob = to_object("%s_%s_LOD%d" % (NAME, group, lod), verts, faces, mat, Ctx.smooth.get(group, ()))
            e = {"object": ob, "set": SET, "role": "visual", "lod": "LOD%d" % lod}
            if lod:
                e["of"] = "%s_%s_LOD0" % (NAME, group)
            meshes.append(e)
            t = sum(len(f[0]) - 2 for f in faces)
            lodtris.setdefault(lod, {})[group] = t
            assert t <= 10000, (group, t)
        print("[station] LOD%d tris %d %s" % (lod, sum(lodtris[lod].values()), lodtris[lod]))
    for i, (a, b, m) in enumerate(Ctx.cols):
        corners = [m @ Vector(p) for p in ((a[0], a[1], a[2]), (b[0], a[1], a[2]), (b[0], a[1], b[2]), (a[0], a[1], b[2]),
                                           (a[0], b[1], a[2]), (b[0], b[1], a[2]), (b[0], b[1], b[2]), (a[0], b[1], b[2]))]
        f = collider_faces(i)
        # outward winding: concept space is right handed, these go counter-clockwise seen from outside after the check below
        o = sum(corners, Vector()) / 8
        n0 = (corners[f[0][0][1]] - corners[f[0][0][0]]).cross(corners[f[0][0][2]] - corners[f[0][0][1]])
        if n0.dot(corners[f[0][0][0]] - o) < 0:
            f = [(tuple(reversed(x[0])), x[1], x[2]) for x in f]
        meshes.append({"object": to_object("%s_Col%02d_COL" % (NAME, i + 1), corners, f, mat)})
    atts = []
    for name, pos, yaw in Ctx.atts:
        e = bpy.data.objects.new(name, None)
        e.location = to_blender(pos)
        e.rotation_euler = (0, 0, yaw * DEG)
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)
    bpy.context.view_layer.update()
    pts = [e["object"].matrix_world @ v.co for e in meshes if e.get("lod") == "LOD0" for v in e["object"].data.vertices]
    lo, hi = [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 3) for i in range(3))
    print("[station] bbox studs", [round(v, 2) for v in lo], [round(v, 2) for v in hi], "colliders", len(Ctx.cols))
    return {
        "name": NAME, "budget": "hero_building", "tier": "standard", "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "toy-brick landmark sized from the concept, not a real building",
        "sets": [{"name": SET_NAME, "set": SET, "size": P.SIZE, "wet": False}],
        "waivers": {"texture sets": "one flat palette atlas with stud patches: toy-brick style, far fewer textures on a phone",
                    "LOD UV layout": "flat palette cells: LODs are rebuilt from the same parts, not an unwrap",
                    "UV faces": "flat palette cells"},
        "meshes": meshes, "attachments": atts,
    }
