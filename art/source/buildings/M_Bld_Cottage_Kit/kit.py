"""H3 Cornish fishing-village cottage kit (Blender): modules (pierced walls with 0.5 m reveals, gables, slate roof with
ridge tiles and mortar verges, gable / ridge chimney stacks with oversail, flaunching, lead flashing and clay pots,
sash and casement windows with frames, glazing bars, granite sills and a dim interior backplate behind the glass,
panelled doors with fanlights and slate steps, wall lanterns, half-round gutters with brackets, swan-neck downpipes
with shoes, tar-painted plinths, slate hanging, a slate porch) assembled per variant from variants.V.

Parts (one material / texture set each): Walls (T_Cottage_Render_<Colour>), Stone (T_Cottage_Stone), Roof
(T_Cottage_Slate), Trim (T_BldTrim_Sheet), Details / Glass / GlassLit (T_Cottage_Details). GlassLit = the lit window
panes and lantern cores for night (off by day: integration sets Transparency 1 by day, warm Neon at night).
Window layers, outside in: sill / frame / sashes and bars, glass (-0.155 m), GlassLit (-0.175 m), curtain cards
(-0.30 m), room backplate at the wall's inner face (-0.5 m): the depth gives real parallax as the player moves.
LOD0 everything; LOD1 drops bars, brackets, collars, curtains, lantern posts; LOD2 = solid walls with flush cards.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import geo  # noqa: E402
import atlas as MT  # noqa: E402  (Details atlas table)
import variants as VR  # noqa: E402
from geo import Part, Wall, trim  # noqa: E402

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
TEX = G + "assets/textures/"
D, T, P, OVH, VERGE, SLAB = VR.D, VR.T, VR.PITCH, VR.OVH, VR.VERGE, VR.SLAB
FR = 0.10            # frame recess behind the wall face
L01, L0, L2, ALL = (0, 1), 1, (2,), 3


def strip(name, metres=1.0, pad=0.004):
    v0, v1 = MT.STRIPS[name]
    return ("trim", v0 + pad, v1 - pad, metres)


def rect(r, w, h, pad=0.003, sub=(0.0, 1.0)):
    u0, v0, u1, v1 = r
    du = u1 - u0
    return ("rect", u0 + du * sub[0] + pad, v0 + pad, u0 + du * sub[1] - pad, v1 - pad, w, h)


def render_mode(du=0.0, dv=0.0):
    return ("tile2", 3.0, 9.0, du, dv)


def stone_mode(du=0.0, dv=0.0):
    return ("tileo", 2.5, du, dv, 0.0)


def build(i):
    v = VR.V[i]
    W, E = VR.W_of(i), VR.E_of(i)
    R = VR.ridge(E)
    name = "M_Bld_Cottage_%02d" % i
    parts = {k: Part(k) for k in ("Walls", "Stone", "Roof", "Trim", "Details", "Glass", "GlassLit")}
    pw, ps, pr, pt, pd, pg, pl = (parts[k] for k in ("Walls", "Stone", "Roof", "Trim", "Details", "Glass", "GlassLit"))
    atts = {}
    counters = {"lampw": 0, "lampd": 0, "smoke": 0, "door": 0}
    geo.LEVEL = ALL

    def wall_of(x):     # unit (part, mode maker, is_stone) for an x position
        for k, (x0, x1, kind) in enumerate(v["units"]):
            if x0 - 1e-6 <= x <= x1 + 1e-6:
                return k, kind
        return 0, v["units"][0][2]

    def surf(kind, du, dv=0.0):
        if kind == "Stone":
            return ps, stone_mode(du, dv)
        return pw, render_mode(du, dv)

    front, back = Wall((0, -1, 0), -D / 2), Wall((0, 1, 0), D / 2)
    holes = {"front": [], "back": []}
    for (x, sill, w, h, kind, ii, lit) in v["front"]:
        holes["front"].append((x - w / 2, x + w / 2, sill, sill + h))
    for (x, sill, w, h, kind, ii, lit) in v["back"]:
        holes["back"].append((x - w / 2, x + w / 2, sill, sill + h))
    for (x, col, fan) in v["doors"]:
        holes["front"].append((x - 0.48, x + 0.48, 0.0, 2.5 if fan else 2.15))

    # ================================================= walls
    for k, (x0, x1, kind) in enumerate(v["units"]):
        for side, a0, a1, du in (("front", -D / 2, -D / 2 + T, 0.13 * k), ("back", D / 2 - T, D / 2, 0.41 + 0.2 * k)):
            part, mode = surf(kind, du)
            geo.LEVEL = L01
            part.pierced([(x0, 0.0), (x1, 0.0), (x1, E), (x0, E)], "y", a0, a1, holes[side], mode)
            geo.LEVEL = L2
            part.box((x0, a0, 0.0), (x1, a1, E), mode)
    for sg in (-1, 1):                       # gables (one unit owns each end)
        xo = sg * W / 2
        _, kind = wall_of(xo)
        part, mode = surf(kind, 0.61 if sg < 0 else 0.18)
        xa, xb = (xo, xo + T) if sg < 0 else (xo - T, xo)
        geo.LEVEL = ALL
        part.prism([(-D / 2 + T, 0.0), (D / 2 - T, 0.0), (D / 2 - T, E), (-D / 2 + T, E)], "x", xa, xb, mode)
        part.prism([(-D / 2, E), (D / 2, E), (0.0, R)], "x", xa, xb, mode)
    # granite skirt below ground (sloping streets) and tar-painted plinth on rendered fronts
    geo.LEVEL = ALL
    ps.box((-W / 2, -D / 2, -VR.SKIRT), (W / 2, D / 2, 0.0), stone_mode(0.3), skip=("+z", "-z"))
    for k, (x0, x1, kind) in enumerate(v["units"]):
        if kind == "Stone":
            continue
        cuts = sorted([(a, b) for a, b, z0, z1 in holes["front"] if z0 < 0.45 and b > x0 and a < x1])
        xs, x = [], x0
        for a, b in cuts:
            xs.append((x, max(x, a)))
            x = max(x, b)
        xs.append((x, x1))
        geo.LEVEL = L01
        for a, b in xs:
            if b - a > 0.02:
                front.box(pd, a, b, 0.0, 0.012, 0.0, 0.45, strip("Tar", 2.0), skip_back=True)
        back.box(pd, -x1, -x0, 0.0, 0.012, 0.0, 0.45, strip("Tar", 2.0), skip_back=True)

    # ================================================= slate hanging (upper storey)
    if v.get("slate_hung"):
        sh = v["slate_hung"]
        up = [hh for hh in holes["front"] if hh[3] > sh]
        geo.LEVEL = L01
        pr.pierced([(-W / 2, sh), (W / 2, sh), (W / 2, E), (-W / 2, E)], "y", -D / 2 - 0.045, -D / 2, up, ("tile", 1.0))
        geo.LEVEL = L2
        pr.box((-W / 2, -D / 2 - 0.045, sh), (W / 2, -D / 2, E), ("tile", 1.0), skip=("+y",))
        geo.LEVEL = ALL
        pd.box((-W / 2, -D / 2 - 0.07, sh - 0.06), (W / 2, -D / 2, sh + 0.015), strip("Lead", 2.0), skip=("+y",))

    # ================================================= windows
    def window(wall, s, sill, w, h, kind, ii, lit, stone):
        s0, s1, z0, z1 = s - w / 2, s + w / 2, sill, sill + h
        fw = 0.065
        PAINT = strip("Paint", 1.0)
        geo.LEVEL = L01
        for a, b, c, d in ((s0, s0 + fw, z0, z1), (s1 - fw, s1, z0, z1), (s0, s1, z0, z0 + fw * 1.3), (s0, s1, z1 - fw, z1)):
            wall.box(pd, a, b, -FR - 0.1, -FR, c, d, PAINT, skip_back=False)
        i0, i1, j0, j1 = s0 + fw, s1 - fw, z0 + fw * 1.3, z1 - fw
        if kind == "sash":
            zm = (j0 + j1) / 2
            for (oa, ob, za, zb) in ((-FR - 0.085, -FR - 0.035, j0, zm + 0.02), (-FR - 0.05, -FR - 0.0, zm - 0.02, j1)):
                sw = 0.045
                for a, b, c, d in ((i0, i0 + sw, za, zb), (i1 - sw, i1, za, zb), (i0, i1, za, za + sw), (i0, i1, zb - sw, zb)):
                    wall.box(pd, a, b, oa, ob, c, d, PAINT, skip_back=False)
                geo.LEVEL = L0
                nb = 2 if w >= 0.95 else 1
                for q in range(1, nb + 1):
                    sc = i0 + (i1 - i0) * q / (nb + 1)
                    wall.box(pd, sc - 0.011, sc + 0.011, oa + 0.01, ob - 0.012, za, zb, PAINT, skip_back=False)
                if nb == 2:
                    zc = (za + zb) / 2
                    wall.box(pd, i0, i1, oa + 0.01, ob - 0.012, zc - 0.011, zc + 0.011, PAINT, skip_back=False)
                if za < zm:   # horns on the upper sash's bottom ends read from the street
                    pass
                geo.LEVEL = L01
            ztx = None
        else:   # two side-hung casements, mullion, transom top-lights
            sm = (i0 + i1) / 2
            ztx = j0 + (j1 - j0) * 0.72
            wall.box(pd, sm - 0.03, sm + 0.03, -FR - 0.09, -FR - 0.005, j0, j1, PAINT, skip_back=False)
            wall.box(pd, i0, i1, -FR - 0.09, -FR - 0.005, ztx - 0.03, ztx + 0.03, PAINT, skip_back=False)
            cw = 0.04
            for a, b in ((i0, sm - 0.03), (sm + 0.03, i1)):
                for c0, c1, c2, c3 in ((a, a + cw, j0, ztx - 0.03), (b - cw, b, j0, ztx - 0.03), (a, b, j0, j0 + cw)):
                    wall.box(pd, c0, c1, -FR - 0.07, -FR - 0.02, c2, c3, PAINT, skip_back=False)
                geo.LEVEL = L0
                zc = (j0 + ztx) / 2
                wall.box(pd, a, b, -FR - 0.06, -FR - 0.03, zc - 0.011, zc + 0.011, PAINT, skip_back=False)
                geo.LEVEL = L01
        # glass, lit pane, curtains, room backplate
        wall.quad(pg, i0, i1, -FR - 0.055, j0, j1, rect(MT.GLASS, i1 - i0, j1 - j0))
        if lit:
            wall.quad(pl, i0, i1, -FR - 0.075, j0, j1, rect(MT.WIN_LIT[ii], i1 - i0, j1 - j0))
            counters["lampw"] += 1
            p = wall.world(s, -T + 0.15, (z0 + z1) / 2 + 0.1)
            atts["ATT_Lamp_Window_%02d" % counters["lampw"]] = p
        geo.LEVEL = L0
        cwid = (i1 - i0) * 0.2
        wall.quad(pd, i0, i0 + cwid, -FR - 0.2, j0, j1, rect(MT.WIN_DIM[ii], cwid, j1 - j0, sub=(0.0, 0.2)))
        wall.quad(pd, i1 - cwid, i1, -FR - 0.2, j0, j1, rect(MT.WIN_DIM[ii], cwid, j1 - j0, sub=(0.8, 1.0)))
        geo.LEVEL = L01
        wall.quad(pd, s0, s1, -T + 0.002, z0, z1, rect(MT.WIN_DIM[ii], s1 - s0, z1 - z0))
        wall.box(pt, s0 - 0.09, s1 + 0.09, -FR, 0.07, z0 - 0.075, z0, trim("Sill", 1.0), skip_back=False)
        if stone:
            geo.LEVEL = ALL
            wall.box(ps, s0 - 0.16, s1 + 0.16, 0.0, 0.03, z1, z1 + 0.26, stone_mode(0.71, 0.33), skip_back=True)
        # LOD2 flush card
        geo.LEVEL = L2
        far = 6 if kind == "sash" else 7
        wall.quad(pd, s0, s1, 0.006, z0, z1, rect(MT.WIN_DIM[far], s1 - s0, z1 - z0))
        wall.quad(pg, s0, s1, 0.009, z0, z1, rect(MT.GLASS, s1 - s0, z1 - z0))
        if lit:
            wall.quad(pl, s0, s1, 0.012, z0, z1, rect(MT.WIN_LIT[far], s1 - s0, z1 - z0))
        wall.box(pt, s0 - 0.09, s1 + 0.09, 0.0, 0.07, z0 - 0.075, z0, trim("Sill", 1.0), skip_back=True)
        geo.LEVEL = ALL

    for (x, sill, w, h, kind, ii, lit) in v["front"]:
        window(front, x, sill, w, h, kind, ii, lit, wall_of(x)[1] == "Stone")
    for (x, sill, w, h, kind, ii, lit) in v["back"]:
        window(back, -x, sill, w, h, kind, ii, lit, wall_of(x)[1] == "Stone")

    # ================================================= doors, steps, porch
    porch_d = 1.0 if v.get("porch") else 0.0
    for (x, col, fan) in v["doors"]:
        top = 2.5 if fan else 2.15
        PAINT = strip("Paint", 1.0)
        geo.LEVEL = L01
        for a, b, c, d in ((x - 0.48, x - 0.41, 0.12, top), (x + 0.41, x + 0.48, 0.12, top), (x - 0.48, x + 0.48, 2.08, 2.16)):
            front.box(pd, a, b, -0.13, -0.03, c, d, PAINT, skip_back=False)
        if fan:
            front.box(pd, x - 0.48, x + 0.48, -0.13, -0.03, top - 0.07, top, PAINT, skip_back=False)
            front.quad(pg, x - 0.41, x + 0.41, -0.09, 2.16, top - 0.07, rect(MT.GLASS, 0.82, top - 2.23))
            front.quad(pd, x - 0.48, x + 0.48, -T + 0.002, 2.16, top, rect(MT.WIN_DIM[0], 0.96, 0.6, sub=(0.2, 0.8)))
            geo.LEVEL = L0
            for q in (-0.2, 0.0, 0.2):
                front.box(pd, x + q - 0.01, x + q + 0.01, -0.1, -0.07, 2.16, top - 0.07, PAINT, skip_back=False)
            geo.LEVEL = L01
        front.box(pd, x - 0.41, x + 0.41, -0.16, -0.11, 0.12, 2.08, rect(MT.DOORS[col], 0.82, 1.96), skip_back=False)
        geo.LEVEL = L2
        front.quad(pd, x - 0.48, x + 0.48, 0.006, 0.12, top, rect(MT.DOORS[col], 0.96, top - 0.12))
        geo.LEVEL = ALL
        front.box(pd, x - 0.6, x + 0.6, -0.13, 0.32 + porch_d, 0.0, 0.12, strip("Step", 1.2), skip_back=False)
        counters["door"] += 1
        atts["ATT_Door" if counters["door"] == 1 else "ATT_Door_%02d" % counters["door"]] = front.world(x, 0.45 + porch_d, 0.12)
        if wall_of(x)[1] == "Stone":
            front.box(ps, x - 0.62, x + 0.62, 0.0, 0.03, top, top + 0.28, stone_mode(0.4, 0.6), skip_back=True)
    if v.get("porch"):
        x = v["doors"][0][0]
        _, kind = wall_of(x)
        part, mode = surf(kind, 0.52)
        geo.LEVEL = ALL
        for sg in (-1, 1):
            xa, xb = sorted((x + sg * 0.76, x + sg * 0.54))
            part.box((xa, -D / 2 - 1.0, 0.0), (xb, -D / 2, 2.3), mode)
        pd.box((x - 0.78, -D / 2 - 1.02, 2.12), (x + 0.78, -D / 2 - 0.86, 2.32), strip("Paint", 1.0))
        pr.prism([(-D / 2 - 1.15, 2.32), (-D / 2, 2.78), (-D / 2, 2.88), (-D / 2 - 1.15, 2.42)], "x", x - 0.9, x + 0.9, ("tile", 2.0))
        pd.box((x - 0.9, -D / 2 - 0.02, 2.78), (x + 0.9, -D / 2 + 0.0, 2.98), strip("Lead", 2.0), skip=("+y",))

    # ================================================= lanterns
    for (x, z) in v["lamps"]:
        IRON = strip("Iron", 0.5)
        geo.LEVEL = L0
        front.box(pd, x - 0.02, x + 0.02, 0.0, 0.2, z + 0.16, z + 0.2, IRON, skip_back=False)
        front.box(pd, x - 0.05, x + 0.05, 0.0, 0.015, z + 0.08, z + 0.26, IRON, skip_back=False)
        for a in (-0.09, 0.07):
            for b in (0.15, 0.31):
                front.box(pd, x + a, x + a + 0.02, b, b + 0.02, z - 0.13, z + 0.14, IRON, skip_back=False)
        geo.LEVEL = L01
        front.box(pd, x - 0.11, x + 0.11, 0.13, 0.35, z + 0.14, z + 0.2, IRON, skip_back=False)
        front.box(pd, x - 0.05, x + 0.05, 0.19, 0.29, z + 0.2, z + 0.25, IRON, skip_back=False)
        front.box(pd, x - 0.1, x + 0.1, 0.14, 0.34, z - 0.18, z - 0.13, IRON, skip_back=False)
        front.box(pg, x - 0.085, x + 0.085, 0.155, 0.325, z - 0.13, z + 0.14, rect(MT.GLASS, 0.17, 0.27), skip_back=False)
        front.box(pl, x - 0.055, x + 0.055, 0.185, 0.295, z - 0.1, z + 0.1, rect(MT.LANTERN, 0.11, 0.2), skip_back=False)
        counters["lampd"] += 1
        atts["ATT_Lamp_Door_%02d" % counters["lampd"]] = front.world(x, 0.24, z)
        geo.LEVEL = ALL

    # ================================================= roof, ridge, verges
    ze = E - P * OVH
    geo.LEVEL = ALL
    for sg in (-1, 1):
        ye = sg * (D / 2 + OVH)
        pr.prism([(ye, ze), (0.0, R), (0.0, R + SLAB), (ye, ze + SLAB)], "x", -W / 2 - VERGE, W / 2 + VERGE, ("tile", 2.0))
        geo.LEVEL = L01
        for xo, xi in ((-W / 2 - VERGE, -W / 2 + 0.005), (W / 2 - 0.005, W / 2 + VERGE)):
            pd.prism([(ye, ze - 0.06), (0.0, R - 0.06), (0.0, R), (ye, ze)], "x", xo, xi, strip("Mortar", 1.0))
        geo.LEVEL = ALL
    rr, zc = 0.14, R + SLAB - 0.04
    prof = [(rr * math.cos(math.pi * k / 6), zc + rr * math.sin(math.pi * k / 6)) for k in range(7)]
    pd.prism(prof, "x", -W / 2 - VERGE + 0.02, W / 2 + VERGE - 0.02, strip("Ridge", 0.9))
    geo.LEVEL = L0
    xk = -W / 2
    while xk < W / 2:
        prof2 = [(0.15 * math.cos(math.pi * k / 4), zc + 0.15 * math.sin(math.pi * k / 4)) for k in range(5)]
        pd.prism(prof2, "x", xk + 0.43, xk + 0.46, strip("Mortar", 0.5))
        xk += 0.45
    geo.LEVEL = ALL

    # ================================================= gutters and downpipes
    r = 0.065
    for sg in (-1, 1):
        yc = sg * (D / 2 + OVH + 0.045)
        zg = ze - 0.02
        prof = [(yc + r * math.cos(math.pi + math.pi * k / 6), zg + r * math.sin(math.pi + math.pi * k / 6)) for k in range(7)]
        pt.prism(prof, "x", -W / 2 - VERGE, W / 2 + VERGE, trim("Gutter", 2.0))
        geo.LEVEL = L0
        xb = -W / 2 + 0.3
        while xb < W / 2:
            pd.box((xb - 0.02, min(yc, sg * (D / 2 + OVH - 0.02)), zg - 0.075), (xb + 0.02, max(yc, sg * (D / 2 + OVH - 0.02)), zg - 0.06), strip("Iron", 0.5))
            xb += 0.9
        geo.LEVEL = ALL
    pipes = [(W / 2 - 0.25, -1), (-W / 2 + 0.25, 1)]
    if len(v["units"]) > 1:
        pipes.append((0.0, -1) if i != 5 else (-W / 2 + 0.25, -1))
    for (x, sg) in pipes:
        yw = sg * (D / 2 + 0.07)
        yc = sg * (D / 2 + OVH + 0.045)
        zg = ze - 0.02
        geo.LEVEL = L01
        pt.tube((x, yc, zg - 0.05), (x, yw, zg - 0.4), 0.04, 8, trim("Downpipe", 1.0))
        pt.tube((x, yw, zg - 0.4), (x, yw, 0.2), 0.04, 8, trim("Downpipe", 1.0))
        pt.tube((x, yw, 0.2), (x, yw + sg * 0.13, 0.07), 0.045, 8, trim("Downpipe", 1.0))
        geo.LEVEL = L0
        zb = 0.8
        while zb < zg - 0.5:
            pd.box((x - 0.055, min(yw, sg * D / 2), zb - 0.025), (x + 0.055, max(yw, sg * D / 2), zb + 0.025), strip("Iron", 0.5))
            zb += 1.6
        geo.LEVEL = ALL

    # ================================================= chimneys
    zs = R + SLAB + VR.STACK_UP
    for (xc, kind, wk) in v["chimneys"]:
        hx = 0.45 if kind == "gable" else 0.4
        hy = 0.38
        part, mode = surf(wk, 0.27, -0.12)
        geo.LEVEL = ALL
        ox0 = 0.04 if (kind == "gable" and xc < 0) else 0.0      # gable stacks stand 4 cm proud of the gable face
        ox1 = 0.04 if (kind == "gable" and xc > 0) else 0.0
        part.box((xc - hx - ox0, -hy, E), (xc + hx + ox1, hy, zs - 0.22), mode)
        part.box((xc - hx - ox0 - 0.05, -hy - 0.05, zs - 0.22), (xc + hx + ox1 + 0.05, hy + 0.05, zs - 0.1), mode)
        pd.box((xc - hx - ox0 - 0.02, -hy - 0.02, zs - 0.1), (xc + hx + ox1 + 0.02, hy + 0.02, zs), strip("Mortar", 1.0))
        zr = E + P * (D / 2 - hy) + SLAB
        geo.LEVEL = L01
        pd.box((xc - hx - 0.025, -hy - 0.025, zr - 0.05), (xc + hx + 0.025, hy + 0.025, zr + 0.14), strip("Lead", 1.0), skip=("-z", "+z"))
        geo.LEVEL = ALL
        n = 2 if kind == "gable" else 3
        for q in range(n):
            px = xc + (q - (n - 1) / 2) * 0.27
            pd.tube((px, 0.0, zs - 0.02), (px, 0.0, zs + VR.POT_H - 0.07), 0.105, 8, strip("Pot", 0.7))
            geo.LEVEL = L01
            pd.tube((px, 0.0, zs + VR.POT_H - 0.07), (px, 0.0, zs + VR.POT_H), 0.125, 8, strip("Pot", 0.8))
            geo.LEVEL = ALL
            counters["smoke"] += 1
            atts["ATT_Smoke_%02d" % counters["smoke"]] = Vector((px, 0.0, zs + VR.POT_H))

    # ================================================= objects
    mats = {"Walls": geo.material("MI_Cottage_Walls", (0.6, 0.5, 0.45), 0.9), "Stone": geo.material("MI_Cottage_Stone", (0.2, 0.18, 0.15), 0.85),
            "Roof": geo.material("MI_Cottage_Slate", (0.07, 0.08, 0.09), 0.6), "Trim": geo.material("MI_Cottage_Trim", (0.3, 0.3, 0.3), 0.6),
            "Details": geo.material("MI_Cottage_Details", (0.3, 0.3, 0.3), 0.6), "Glass": geo.material("MI_Cottage_Glass", (0.05, 0.06, 0.07), 0.05),
            "GlassLit": geo.material("MI_Cottage_GlassLit", (0.9, 0.7, 0.45), 0.3)}
    render_set = next((kd for _, _, kd in v["units"] if kd != "Stone"), None)
    if render_set is None:
        render_set = next((wk for _, _, wk in v["chimneys"] if wk != "Stone"), None)
    sets_of = {"Walls": render_set, "Stone": "Stone", "Roof": "Slate", "Trim": "Sheet", "Details": "Details", "Glass": "Details", "GlassLit": "Details"}
    meshes, report = [], []
    for k, p in parts.items():
        if not p.faces:
            continue
        for li, lod in ((0, "LOD0"), (1, "LOD1"), (2, "LOD2")):
            o = p.to_object("M_Bld_Cottage_%s_%02d_%s" % (k, i, lod), mats[k], lod=li)
            meshes.append({"object": o, "set": sets_of[k]})
        report.append("%s %d/%d/%d" % (k, p.tris(0), p.tris(1), p.tris(2)))
    tot = tuple(sum(p.tris(li) for p in parts.values()) for li in range(3))
    print("[H3] %s tris LOD0/1/2: %s | totals %d / %d / %d" % ((name, ", ".join(report)) + tot))

    col = Part("COL")
    col.box((-W / 2, -D / 2, -VR.SKIRT), (W / 2, D / 2, E), ("tile", 1.0))
    col.prism([(-(D / 2 + OVH), ze), (0.0, R + SLAB), (D / 2 + OVH, ze)], "x", -W / 2 - VERGE, W / 2 + VERGE, ("tile", 1.0))
    for (xc, kind, wk) in v["chimneys"]:
        hx = 0.45 if kind == "gable" else 0.4
        col.box((xc - hx, -0.38, E), (xc + hx, 0.38, zs), ("tile", 1.0))
    for (x, col_, fan) in v["doors"]:
        col.box((x - 0.6, -D / 2 - 0.32 - porch_d, 0.0), (x + 0.6, -D / 2, 0.12), ("tile", 1.0))
    if v.get("porch"):
        x = v["doors"][0][0]
        for sg in (-1, 1):
            xa, xb = sorted((x + sg * 0.76, x + sg * 0.54))
            col.box((xa, -D / 2 - 1.0, 0.0), (xb, -D / 2, 2.3), ("tile", 1.0))
        col.box((x - 0.9, -D / 2 - 1.15, 2.3), (x + 0.9, -D / 2, 2.9), ("tile", 1.0))
    colobj = col.to_object(name + "_COL", None, weld=False)

    att_objs = []
    for n, p in atts.items():
        e = bpy.data.objects.new(n, None)
        e.location = (p.x * 3, p.y * 3, p.z * 3)
        bpy.context.scene.collection.objects.link(e)
        att_objs.append(e)

    used = sorted(set(sets_of[k] for k, p in parts.items() if p.faces))
    sets = []
    for s in used:
        if s == "Sheet":
            sets.append({"name": "BldTrim", "set": "Sheet", "size": 1024, "wet": True, "dir": TEX + "M_Bld_TrimSheet"})
        else:
            sets.append({"name": "Cottage", "set": s, "size": 1024, "wet": True, "dir": TEX + "M_Bld_Cottage_Kit"})
    st = lambda x, y, z: [x * 3, y * 3, z * 3]
    dx = v["doors"][0][0]
    return {
        "name": name,
        "budget": "hero_building",
        "tris": 40000,
        "tier": "standard",
        "dims_m": VR.dims(i),
        "size_note": None,
        "origin": "free",
        "tiling": True,
        "waivers": {"LOD UV layout": "world-scale tiling UVs (render / stone / slate sets, trim sheet strips): hand-made "
                                     "LODs drop and replace parts (LOD2 flush window cards), so the UV bounds change",
                    "texture sets": "shared H3 kit sets (Render colour, Stone, Slate, Details) + the shared building trim "
                                    "sheet: resident once for the whole street, not per house"},
        "sets": sets,
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "door_lantern", "target": st(dx, -D / 2, 1.4), "dist": 9, "az": 18, "el": 6},
            {"name": "window_parallax", "target": st(v["front"][0][0], -D / 2, v["front"][0][1] + 0.6), "dist": 7, "az": 30, "el": 4},
            {"name": "eaves_gutter", "target": st(W / 2 - 0.4, -D / 2 - 0.2, E - 0.2), "dist": 8, "az": 35, "el": 12},
            {"name": "chimney_ridge", "target": st(v["chimneys"][0][0], 0.0, zs), "dist": 10, "az": -30, "el": 25},
            {"name": "base_damp", "target": st(-W / 2 + 0.8, -D / 2, 0.5), "dist": 6, "az": -20, "el": 8},
        ],
    }
