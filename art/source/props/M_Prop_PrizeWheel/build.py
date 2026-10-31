"""M_Prop_PrizeWheel: the island prize wheel as a Lego game-show wheel (replaces the flat code-built Parts; owner
2026-10-31: "use blender to redo the spinner, it looks bad").

All numbers are Roblox studs relative to the wheel's `at` (stand foot centre on the plaza, front -Z; the Blender origin
is that point, so DockService's PivotTo(at) puts every part where the old Parts stood). The hub is HUB = (0, 10, -3.6).

Layers (PrizeWheel.luau puts them under the same names the controller uses):
  L01_Stand    blue studded base plate, two studded brick columns + header brick, spine and axle, blue flapper
               housing (cheeks + chrome hinge pin)
  L02_Rotor    thick red rim with a white trim, 12 solid rarity tiles (SpinRules.SEGMENTS order, angle i = (i-1)*30 deg
               CCW from +X as WheelMath), raised shaded dividers, a big rarity gem on a white disc per tile, 12 pegs,
               chrome shoulder + polished gold hub cap (no neon; the glow stays for big wins in code)
  L03_Flapper  chunky white pointer, navy outline, red tip, hinge boss; PrizeWheel.luau sets its pivot to HINGE
  Col01_COL    the base plate only (the old Base Part was the only collider)

    python3 art/source/props/M_Prop_PrizeWheel/maketex.py --out build/prod/M_Prop_PrizeWheel/textures/M_Prop_PrizeWheel
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_PrizeWheel/build.py \
        --out-root build/prod/M_Prop_PrizeWheel --steps build,lod,validate,export,turntable
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Prop_PrizeWheel"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "PrizeWheel", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_PrizeWheel_Brick_ALB.png")

# SpinRules.SEGMENTS (mirror: change both together)
SEGMENTS = ["Common", "Uncommon", "Common", "Rare", "Common", "Uncommon", "Epic", "Common", "Uncommon", "Rare",
            "Legendary", "Mythic"]
HUB = (0.0, 10.0, -3.6)
HINGE = (0.0, 17.9, -4.82)          # the flapper's pivot (PrizeWheel.luau sets PivotOffset from this)
N_SEG = len(SEGMENTS)
R_RIM_IN, R_RIM_OUT = 6.0, 7.3
R_TILE = 6.1                         # tiles tuck under the rim's white trim
STEP = 2 * math.pi / N_SEG


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ builder (Roblox coords in, Blender out)
class RB(lego.B):
    """Vertices come in as Roblox studs (x right, y up, front -z) and leave as Blender (roblox = (-bx, bz, by))."""

    def _emit(self, verts, faces, c):
        cs = list(c) if isinstance(c, (list, tuple)) else [c] * len(faces)
        base = len(self.v)
        self.v.extend((-x, z, y) for x, y, z in verts)
        for face, col in zip(faces, cs):
            self.f.append((tuple(base + i for i in face), col))


class Fr:
    """A local frame: point(x, y, z) = o + x*u + y*v + z*w."""

    def __init__(self, o=(0, 0, 0), u=(1, 0, 0), v=(0, 1, 0), w=(0, 0, 1)):
        self.o, self.u, self.v, self.w = o, u, v, w

    def pt(self, x, y, z):
        return tuple(self.o[i] + x * self.u[i] + y * self.v[i] + z * self.w[i] for i in range(3))


WORLD = Fr()


def radial(cx, cy, cz, a):
    """Frame at (cx, cy, cz): x radial (angle a), y tangent, z the wheel axis (back)."""
    return Fr((cx, cy, cz), (math.cos(a), math.sin(a), 0), (-math.sin(a), math.cos(a), 0), (0, 0, 1))


def cbox(b, lo, hi, c, bev=0.12, fr=WORLD):
    """A box with every edge chamfered by bev."""
    bev = min(bev, 0.45 * min(hi[i] - lo[i] for i in range(3)))
    axes = ((lo[0], hi[0]), (lo[1], hi[1]), (lo[2], hi[2]))
    verts, idx = [], {}
    for s in ((a, bb, cc) for a in (0, 1) for bb in (0, 1) for cc in (0, 1)):
        for ax in range(3):
            p = [axes[i][s[i]] for i in range(3)]
            for o in range(3):
                if o != ax:
                    p[o] += bev if s[o] == 0 else -bev
            idx[s + (ax,)] = len(verts)
            verts.append(fr.pt(*p))
    faces = []
    for ax in range(3):
        o1, o2 = [i for i in range(3) if i != ax]
        for sa in (0, 1):
            quad = []
            for s1, s2 in ((0, 0), (1, 0), (1, 1), (0, 1)):
                s = [0, 0, 0]
                s[ax], s[o1], s[o2] = sa, s1, s2
                quad.append(idx[tuple(s) + (ax,)])
            faces.append(tuple(quad))
    for a1, a2 in ((0, 1), (0, 2), (1, 2)):
        e = 3 - a1 - a2
        for s1 in (0, 1):
            for s2 in (0, 1):
                quad = []
                for se in (0, 1):
                    s = [0, 0, 0]
                    s[a1], s[a2], s[e] = s1, s2, se
                    quad.append(tuple(s))
                faces.append((idx[quad[0] + (a1,)], idx[quad[1] + (a1,)], idx[quad[1] + (a2,)], idx[quad[0] + (a2,)]))
    for s in ((a, bb, cc) for a in (0, 1) for bb in (0, 1) for cc in (0, 1)):
        faces.append((idx[s + (0,)], idx[s + (1,)], idx[s + (2,)]))
    b._emit(verts, faces, c)


def lathe(b, fr, prof, n, c):
    """Revolves the closed (r, z) loop `prof` around the frame's z axis; c = one palette cell or one per profile edge."""
    verts, rings = [], []
    for r, z in prof:
        if r < 1e-6:
            rings.append([len(verts)])
            verts.append(fr.pt(0, 0, z))
        else:
            rings.append([len(verts) + i for i in range(n)])
            verts.extend(fr.pt(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n), z) for i in range(n))
    faces, cols = [], []
    m = len(prof)
    for k in range(m):
        A, B = rings[k], rings[(k + 1) % m]
        if len(A) == 1 and len(B) == 1:
            continue
        col = c[k] if isinstance(c, (list, tuple)) else c
        for i in range(n):
            j = (i + 1) % n
            if len(A) == 1:
                faces.append((A[0], B[j], B[i]))
            elif len(B) == 1:
                faces.append((A[i], A[j], B[0]))
            else:
                faces.append((A[i], A[j], B[j], B[i]))
            cols.append(col)
    b._emit(verts, faces, cols)


def offset(poly, d):
    """Convex 2D polygon moved inward by d (negative = outward), mitred."""
    n = len(poly)
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sgn = 1 if area > 0 else -1
    norms = []
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        ex, ey = x1 - x0, y1 - y0
        L = math.hypot(ex, ey)
        norms.append((-ey / L * sgn, ex / L * sgn))
    out = []
    for i in range(n):
        n1, n2 = norms[i - 1], norms[i]
        k = d / (1 + n1[0] * n2[0] + n1[1] * n2[1])
        out.append((poly[i][0] + (n1[0] + n2[0]) * k, poly[i][1] + (n1[1] + n2[1]) * k))
    return out


def ext(b, fr, poly, z0, z1, c, inset=0.0, inset0=0.0):
    """Extrudes a convex 2D outline from z0 (outline inset0) to z1 (outline inset): chamfered plates, gems, flappers."""
    bot = offset(poly, inset0) if inset0 else poly
    top = offset(poly, inset) if inset else poly
    n = len(poly)
    verts = [fr.pt(x, y, z0) for x, y in bot] + [fr.pt(x, y, z1) for x, y in top]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def arc(r, a0, a1, k):
    return [(r * math.cos(a0 + (a1 - a0) * i / k), r * math.sin(a0 + (a1 - a0) * i / k)) for i in range(k + 1)]


def prism(b, fr, x0, x1, sec, c_end, c_sides):
    """The convex (y, z) section `sec` run along the frame's x from x0 to x1; c_sides = one cell per section edge."""
    n = len(sec)
    verts = [fr.pt(x0, y, z) for y, z in sec] + [fr.pt(x1, y, z) for y, z in sec]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, [c_end, c_end] + list(c_sides))


def stud(b, o, w, c, n=12):
    """A Lego stud standing on the point o, pointing along the unit axis w."""
    u = (1, 0, 0) if abs(w[0]) < 0.9 else (0, 1, 0)
    v = (w[1] * u[2] - w[2] * u[1], w[2] * u[0] - w[0] * u[2], w[0] * u[1] - w[1] * u[0])
    u = (v[1] * w[2] - v[2] * w[1], v[2] * w[0] - v[0] * w[2], v[0] * w[1] - v[1] * w[0])
    lathe(b, Fr(o, u, v, w), [(0, -0.05), (0.6, -0.05), (0.6, 0.36), (0, 0.36)], n, c)   # round beats a chamfer here


# ------------------------------------------------------------------ rotor
FRONT = -0.45            # tile front, rotor-local z (front is negative)
BACK = 0.15


def tile_outline(a, r0, r1, side, d):
    """The annular-sector outline of tile angle a, every edge pulled in by `side` + d (radians per radius)."""
    half = STEP / 2
    out = arc(r1 - d, a - half + (side + d) / (r1 - d), a + half - (side + d) / (r1 - d), 6)
    inner = arc(r0 + d, a - half + (side + d) / (r0 + d), a + half - (side + d) / (r0 + d), 3)
    return out + inner[::-1]


GEM = [(-0.36, 0.56), (0.36, 0.56), (0.7, 0.14), (0.0, -0.7), (-0.7, 0.14)]
R_GEM, R_DISC = 4.9, 1.12           # disc edge stays clear of the divider bases (half chord at R_GEM is 1.27)


def gem(b, a, rarity, rank):
    """A white disc and a big faceted gem on tile angle a, tip toward the hub (upright at the pointer)."""
    cx, cy, cz = HUB
    o = (cx + R_GEM * math.cos(a), cy + R_GEM * math.sin(a), cz)
    lathe(b, Fr(o), [(0, -0.40), (R_DISC, -0.40), (R_DISC, -0.56), (R_DISC - 0.1, -0.645), (0, -0.645)], 16,
          [P.WHITE, P.LSIL, P.WHITE, P.WHITE])
    fr = Fr((o[0], o[1], cz), (-math.sin(a), math.cos(a), 0), (math.cos(a), math.sin(a), 0), (0, 0, -1))
    s = 1.27 + 0.01 * rank
    pts = [(x * s, y * s) for x, y in GEM]
    base, light, dark = P.RARITY[rank]
    table = [(x * 0.42, y * 0.42 + 0.06) for x, y in pts]
    n = len(pts)
    verts = [fr.pt(x, y, 0.6) for x, y in pts] + [fr.pt(x, y, 1.45) for x, y in table]
    faces, cols = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))], [dark, light]
    rainbow = [P.C5L, P.CYAN, P.YELLOW, P.LIME, P.C5]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
        mx, my = (pts[i][0] + pts[j][0]) / 2, (pts[i][1] + pts[j][1]) / 2
        lit = (-0.55 * mx + 0.83 * my) / max(0.01, math.hypot(mx, my - 0.05))
        cols.append(rainbow[i % 5] if rank == 5 else (light if lit > 0.35 else dark if lit < -0.35 else base))
    b._emit(verts, faces, cols)


def rotor(b):
    cx, cy, cz = HUB
    fr = Fr(HUB)
    # rim: thick, chamfered, red with a white trim around the tiles (the gold Legendary tile never meets yellow)
    rim = [(R_RIM_IN + 0.3, -0.65), (R_RIM_OUT - 0.3, -0.65), (R_RIM_OUT, -0.35), (R_RIM_OUT, 0.65),
           (R_RIM_IN, 0.65), (R_RIM_IN, -0.35)]                        # the back edges are never seen: no chamfer
    lathe(b, fr, rim, 48, [P.RED, P.RED, P.RRED, P.RRED, P.WHITE, P.WHITE])
    # back plate
    lathe(b, fr, [(0, 0.1), (6.2, 0.1), (6.2, 0.5), (0, 0.5)], 32, P.INK)
    lathe(b, fr, [(0, 0.45), (1.3, 0.45), (1.3, 0.62), (1.1, 0.72), (0, 0.72)], 24, P.CHROME)
    # 12 solid tiles + dividers + gems, SpinRules order, angle (i-1)*30 deg CCW from +X
    for i, rarity in enumerate(SEGMENTS):
        a = i * STEP
        rank = P.RARITY_NAMES.index(rarity)
        bot = tile_outline(a, 1.6, R_TILE, 0.1, 0.0)
        top = tile_outline(a, 1.6, R_TILE, 0.1, 0.13)
        n = len(bot)
        verts = [fr.pt(x, y, BACK) for x, y in bot] + [fr.pt(x, y, FRONT) for x, y in top]
        faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))] + [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
        b._emit(verts, faces, P.RARITY[rank][0])
        gem(b, a, rarity, rank)
        ra = radial(cx, cy, cz, a + STEP / 2)
        # raised divider: white crest, shaded silver flanks, on a navy contact strip
        prism(b, ra, 2.2, 6.15, [(-0.17, -0.38), (0.17, -0.38), (0.08, -0.92), (-0.08, -0.92)], P.WHITE,
              [P.LSIL, P.LSIL, P.WHITE, P.LSIL])
        cbox(b, (2.2, -0.25, -0.49), (6.05, 0.25, -0.40), P.INK, bev=0.03, fr=ra)
    # pegs (yellow, white tips) at the tile boundaries, on the rim face
    for i in range(N_SEG):
        a = (i + 0.5) * STEP
        f = Fr((cx + 6.65 * math.cos(a), cy + 6.65 * math.sin(a), cz))
        lathe(b, f, [(0, -0.55), (0.4, -0.55), (0.4, -1.3), (0.28, -1.55), (0, -1.6)], 10,
              [P.YELLOW, P.YELLOW, P.WHITE, P.WHITE])
    # hub: chrome shoulder, polished gold dome, red enamel centre
    lathe(b, fr, [(1.5, -0.40), (2.25, -0.40), (2.25, -0.62), (2.05, -0.84), (1.5, -0.84)], 32, P.CHROME)
    lathe(b, fr, [(0, -0.78), (1.52, -0.78), (1.52, -0.92), (1.3, -1.12), (0.85, -1.28), (0.55, -1.325), (0, -1.34)], 32,
          [P.GOLD, P.GOLD, P.GOLD, P.GOLD, P.GOLD, P.RED, P.RED])


# ------------------------------------------------------------------ stand
def stand(b):
    cbox(b, (-8, 0, -3), (8, 1.2, 3), P.BLUE, bev=0.16)
    for x in range(-7, 8, 2):
        stud(b, (x, 1.2, 0.0), (0, 1, 0), P.BLUE)
    bricks = [P.WHITE, P.BLUE, P.WHITE, P.WHITE, P.BLUE, P.WHITE]
    h = (17.6 - 2.7) / len(bricks)
    for s in (-1, 1):
        x0, x1 = (6.0, 7.85) if s > 0 else (-7.85, -6.0)
        cbox(b, (min(s * 5.9, s * 7.95), 1.2, -2.9), (max(s * 5.9, s * 7.95), 2.7, -0.8), P.RED, bev=0.18)   # foot
        cbox(b, (x0 + 0.22, 2.6, -2.58), (x1 - 0.22, 17.7, -1.07), P.DBG, bev=0.05)                          # seam core
        for k, c in enumerate(bricks):                                                                      # brick column
            y0, y1 = 2.7 + k * h + 0.03, 2.7 + (k + 1) * h - 0.03
            cbox(b, (x0, y0, -2.8), (x1, y1, -0.85), c, bev=0.14)
            stud(b, (s * 7.85, (y0 + y1) / 2, -1.825), (s, 0, 0), c)
            if k not in (1, 2, 3):                                                                          # clear of the rim's back edge
                stud(b, ((x0 + x1) / 2, (y0 + y1) / 2, -2.8), (0, 0, -1), c)
    cbox(b, (-7.85, 17.6, -2.75), (7.85, 19.0, -0.9), P.WHITE, bev=0.14)                                       # header brick
    for x in (-6.9, -4.9, -2.9, 2.9, 4.9, 6.9):
        stud(b, (x, 19.0, -1.825), (0, 1, 0), P.WHITE)
    cbox(b, (-0.9, 2.7, -2.5), (0.9, 17.7, -1.3), P.DBG, bev=0.12)                                               # spine
    # flapper housing: blue brick off the header, cheeks either side of the flapper, chrome hinge pin
    cbox(b, (-1.9, 18.6, -5.6), (1.9, 20.4, -2.45), P.BLUE, bev=0.2)
    for x in (-0.95, 0.95):
        stud(b, (x, 20.4, -4.0), (0, 1, 0), P.BLUE)
    cbox(b, (-1.5, 19.05, -5.7), (1.5, 19.95, -5.55), P.YELLOW, bev=0.04)                                      # front tile
    for s in (-1, 1):
        cbox(b, (min(s * 1.35, s * 1.8), 17.2, -5.45), (max(s * 1.35, s * 1.8), 18.75, -4.33), P.BLUE, bev=0.15)
    lathe(b, Fr(HINGE, (0, 1, 0), (0, 0, 1), (1, 0, 0)),
          [(0, -1.96), (0.36, -1.96), (0.36, -1.76), (0.2, -1.76), (0.2, 1.76), (0.36, 1.76), (0.36, 1.96), (0, 1.96)],
          10, P.CHROME)
    ax = Fr((HUB[0], HUB[1], 0), (1, 0, 0), (0, 1, 0), (0, 0, 1))
    lathe(b, ax, [(0, -2.95), (0.55, -2.95), (0.55, -2.4), (0, -2.4)], 16, P.CHROME)                          # axle
    lathe(b, ax, [(0, -2.8), (0.95, -2.8), (0.95, -2.45), (0, -2.45)], 16, P.YELLOW)                          # bearing collar


# ------------------------------------------------------------------ flapper (local frame at HINGE)
def flapper(b):
    """A chunky white arrow with a navy outline and a red tip, hung on a boss round the hinge pin; its tip sits just
    inside the peg ring so the pegs knock it."""
    fr = Fr(HINGE)
    body = [(-1.0, 0.25), (-1.0, -0.75), (0.0, -1.75), (1.0, -0.75), (1.0, 0.25)]
    ext(b, fr, offset(body, -0.13), 0.37, -0.31, P.INK, inset=0.05)
    ext(b, fr, body, 0.25, -0.43, P.WHITE, inset=0.1)
    ext(b, fr, offset([(-1.0, -0.5), (1.0, -0.5), (1.0, -0.75), (0.0, -1.75), (-1.0, -0.75)], 0.13), -0.38, -0.5, P.RED,
        inset=0.03)                                                                                        # red arrowhead
    lathe(b, Fr(HINGE, (0, 1, 0), (0, 0, 1), (1, 0, 0)),
          [(0, -1.08), (0.42, -1.08), (0.52, -0.98), (0.52, 0.98), (0.42, 1.08), (0, 1.08)], 12, P.WHITE)


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_PrizeWheel_Brick", ALB)
    meshes = []

    def out(name, fn):
        b = RB()
        fn(b)
        obj = b.to_object(name, mat)
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[wheel] %-12s %5d tris" % (name, b.tris()))

    for name, fn in (("L01_Stand", stand), ("L02_Rotor", rotor), ("L03_Flapper", flapper)):
        out(name, fn)
    out("Col01_COL", lambda c: c.box((-8, 0, -3), (8, 1.2, 3), P.DBG, bevel=0))
    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[wheel] bbox studs %s..%s dims_m %s" % ([round(v, 2) for v in lo], [round(v, 2) for v in hi], dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "stylised Lego prize wheel: same 14.6-stud wheel, 16 x 6 base and hub height as the old Parts",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Stand, L02_Rotor, L03_Flapper: PrizeWheel.luau rebuilds the Rotor / Flapper hierarchy",
            "UV faces": "at LOD1 / LOD2 the collapse decimator merges the palette-cell UVs of the smallest bevel and gem faces "
                        "(1 to 2% of faces); every face is still one flat colour",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "closeups": [
            {"name": "hub", "target": [0, -3.6, 10], "dist": 16, "az": -10, "el": 6},
            {"name": "pointer", "target": [0, -4.8, 18], "dist": 12, "az": -25, "el": 12},
            {"name": "base", "target": [0, -1, 2], "dist": 22, "az": -35, "el": 18},
        ],
    }
