"""H3 Cornish fishing-village cottage kit (Blender), H3b geometry round. Modules: pierced walls (0.5 m reveals), gables,
stepped 3D slate courses (6 cm slab + 1.5 cm course tails, 25 cm gauge aligned to the Slate texture), 22 cm eaves with
fascia, 25 cm verges with bargeboards, a raised half-round ridge on a mortar bed, corbelled gable / ridge stacks with a
stepped corbel course, an oversailing cap slab, flaunching, lathed open-flue pots of irregular height, lead aprons and
stepped side flashing, hollow half-round gutters on iron brackets, cast-iron downpipes (swan neck, sockets, ears, shoe,
gully), stepped plinths (tar-painted render / granite), granite quoins on render walls, granite sill bands on granite
fronts, projecting granite lintels, drip-grooved sills, sash and casement windows recessed 9 cm in their reveals (some
sashes open, roller blinds, lace nets, curtains), panelled doors with surrounds, thresholds and two-course slate steps,
wall lanterns, slate hanging, a slate porch; Grime decals (RGBA, AlphaMode Transparency): damp / salt tide on the lower
1.15 m, rust and damp streaks under sills and lanterns, soot under the stack caps, moss on the north (+Y, back) slope.

Parts (one material / texture set each): Walls (T_Cottage_Render_<Colour>), Stone (T_Cottage_Stone), Roof
(T_Cottage_Slate), Trim (T_BldTrim_Sheet), Details / Glass / GlassLit (T_Cottage_Details), Grime (T_Cottage_Grime).
GlassLit = the lit window panes and lantern cores for night (off by day: integration sets Transparency 1 by day, warm
Neon at night). Window layers, outside in: sill / frame / sashes and bars, glass (-0.145 m), GlassLit (-0.165 m), blind /
nets (-0.21 / -0.22 m), curtain cards (-0.29 m), room backplate at the wall's inner face (-0.5 m).
LOD0 everything; LOD1 drops bars, brackets, collars, curtains, pot rims, flashing steps, joints; LOD2 = solid walls with
flush cards, a flat roof slab, solid gutters, simple pots.
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
FR = 0.09            # frame recess behind the wall face (H3b: 9 cm)
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


def lathe(part, cx, cy, rings, segs, mode_v, zb, h, inner=None, cap_mode=None):
    """H3b: a turned pot / collar. rings: outer profile [(r, z)] bottom to top; mode_v = (v0, v1) strip range mapped
    by height (zb .. zb + h); inner = (r_in, depth): an open flue (inner wall + dark floor) with a rim annulus."""
    part.prim += 1
    v0, v1 = mode_v
    ang = [2 * math.pi * j / segs for j in range(segs + 1)]

    def P(r, a, z):
        return Vector((cx + r * math.cos(a), cy + r * math.sin(a), z))

    def vz(z):
        return v0 + min(1.0, max(0.0, (z - zb) / h)) * (v1 - v0)
    rm = sum(r for r, _ in rings) / len(rings)
    for (r0, z0), (r1, z1) in zip(rings, rings[1:]):
        for j in range(segs):
            a, b = ang[j], ang[j + 1]
            pts = [P(r0, a, z0), P(r0, b, z0), P(r1, b, z1), P(r1, a, z1)]
            ua, ub = j / segs * 2 * math.pi * rm / 0.7, (j + 1) / segs * 2 * math.pi * rm / 0.7
            m = (a + b) / 2
            part.face(pts, ("uv", [(ua, vz(z0)), (ub, vz(z0)), (ub, vz(z1)), (ua, vz(z1))]),
                      outward=(math.cos(m), math.sin(m), 0.0))
    rt, zt = rings[-1]
    if inner is None:
        part.face([P(rt, a, zt) for a in ang[:-1]], cap_mode or ("tile", 0.5), outward=(0, 0, 1))
        return
    ri, dep = inner
    for j in range(segs):
        a, b = ang[j], ang[j + 1]
        m = (a + b) / 2
        ua, ub = j / segs * 2 * math.pi * ri / 0.7, (j + 1) / segs * 2 * math.pi * ri / 0.7
        part.face([P(ri, a, zt - dep), P(ri, b, zt - dep), P(ri, b, zt), P(ri, a, zt)],
                  ("uv", [(ua, v1 - 0.002), (ub, v1 - 0.002), (ub, v1 - 0.001), (ua, v1 - 0.001)]),
                  outward=(-math.cos(m), -math.sin(m), 0.0))
        part.face([P(ri, a, zt), P(ri, b, zt), P(rt, b, zt), P(rt, a, zt)],
                  ("uv", [(ua, v1 - 0.003), (ub, v1 - 0.003), (ub, v1 - 0.001), (ua, v1 - 0.001)]), outward=(0, 0, 1))
    part.face([P(ri, a, zt - dep) for a in ang[:-1]], cap_mode or ("tile", 0.5), outward=(0, 0, 1))


def build(i):
    v = VR.V[i]
    W, E = VR.W_of(i), VR.E_of(i)
    R = VR.ridge(E)
    name = "M_Bld_Cottage_%02d" % i
    parts = {k: Part(k) for k in ("Walls", "Stone", "Roof", "Trim", "Details", "Glass", "GlassLit", "Grime")}
    pw, ps, pr, pt, pd, pg, pl, pk = (parts[k] for k in ("Walls", "Stone", "Roof", "Trim", "Details", "Glass", "GlassLit", "Grime"))
    atts = {}
    counters = {"lampw": 0, "lampd": 0, "smoke": 0, "door": 0, "win": 0}
    geo.LEVEL = ALL
    SQ = math.sqrt(1 + P * P)
    RUN = D / 2 + OVH
    ze = E - P * OVH
    S_MAX = RUN * SQ
    C, STEP = VR.COURSE, VR.STEP
    zs = R + SLAB + VR.STACK_UP          # top of the stack cap slab
    sh = v.get("slate_hung")

    def y_of(sg, s):
        return sg * (RUN - s / SQ)

    def ztop(s):
        return ze + SLAB + P * s / SQ

    def s_of(p):
        return (RUN - abs(p.y)) * SQ

    def wall_of(x):     # unit (index, kind) for an x position
        for k, (x0, x1, kind) in enumerate(v["units"]):
            if x0 - 1e-6 <= x <= x1 + 1e-6:
                return k, kind
        return 0, v["units"][0][2]

    def surf(kind, du, dv=0.0):
        if kind == "Stone":
            return ps, stone_mode(du, dv)
        return pw, render_mode(du, dv)

    def gband(name, z_lo, height, along, metres):
        """Grime u-tiling band UV: u = world `along` coordinate / metres, v = band v0 + (z - z_lo) / height."""
        b0, b1 = MT.GRIME_BANDS[name]
        b0, b1 = b0 + 0.003, b1 - 0.003
        ax = {"x": 0, "y": 1}[along]
        return ("fn", lambda p: (p[ax] / metres, b0 + min(1.0, max(0.0, (p.z - z_lo) / height)) * (b1 - b0)))

    front, back = Wall((0, -1, 0), -D / 2), Wall((0, 1, 0), D / 2)
    gables = {-1: Wall((-1, 0, 0), -W / 2), 1: Wall((1, 0, 0), W / 2)}
    holes = {"front": [], "back": []}
    for (x, sill, w, h, kind, ii, lit) in v["front"]:
        holes["front"].append((x - w / 2, x + w / 2, sill, sill + h))
    for (x, sill, w, h, kind, ii, lit) in v["back"]:
        holes["back"].append((x - w / 2, x + w / 2, sill, sill + h))
    for (x, col, fan) in v["doors"]:
        holes["front"].append((x - 0.48, x + 0.48, 0.0, 2.5 if fan else 2.15))

    def spans(x0, x1, cuts):
        out, x = [], x0
        for a, b in sorted(cuts):
            if b <= x0 or a >= x1:
                continue
            if a > x:
                out.append((x, a))
            x = max(x, b)
        if x1 > x:
            out.append((x, x1))
        return [(a, b) for a, b in out if b - a > 0.02]

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
    geo.LEVEL = ALL
    ps.box((-W / 2, -D / 2, -VR.SKIRT), (W / 2, D / 2, 0.0), stone_mode(0.3), skip=("+z", "-z"))

    # ================================================= stepped plinths (render: tar-painted, 4 cm; granite: 5 cm)
    def plinth(wall, s0, s1, kind):
        if kind == "Stone":
            wall.prism(ps, s0, s1, [(0.0, 0.0), (0.05, 0.0), (0.05, 0.34), (0.0, 0.40)], stone_mode(0.17, 0.05))
            return 0.05, 0.34
        wall.prism(pd, s0, s1, [(0.0, 0.0), (0.04, 0.0), (0.04, 0.42), (0.0, 0.46)], strip("Tar", 2.0))
        return 0.04, 0.42

    def damp(wall, s0, s1, hs, kind, along):
        """Grime damp / salt tide: on the wall face above the plinth and on the plinth face, split around openings."""
        proj, ptop = (0.05, 0.34) if kind == "Stone" else (0.04, 0.42)
        mode = gband("Damp", 0.0, MT.DAMP_H, along, MT.DAMP_U)
        cuts = [(a, b) for a, b, z0, z1 in hs if z0 < 0.05]
        for a, b in spans(s0, s1, cuts):
            wall.quad(pk, a, b, proj + 0.003, 0.0, ptop, mode)
            for c, d in spans(a, b, [(p, q) for p, q, z0, z1 in hs if z0 < MT.DAMP_H]):
                wall.quad(pk, c, d, 0.003, ptop, MT.DAMP_H, mode)
            for p, q, z0, z1 in hs:
                lo, hi = max(a, p), min(b, q)
                if 0.05 <= z0 < MT.DAMP_H and hi - lo > 0.02 and z0 > ptop:
                    wall.quad(pk, lo, hi, 0.003, ptop, z0 - 0.065, mode)

    for k, (x0, x1, kind) in enumerate(v["units"]):
        e0 = 0.05 if abs(x0 + W / 2) < 1e-6 else 0.0
        e1 = 0.05 if abs(x1 - W / 2) < 1e-6 else 0.0
        geo.LEVEL = L01
        for a, b in spans(x0 - e0, x1 + e1, [(p, q) for p, q, z0, z1 in holes["front"] if z0 < 0.45]):
            plinth(front, a, b, kind)
        plinth(back, -x1 - e1, -x0 + e0, kind)
        geo.LEVEL = L01
        fh = [(p, q, z0, z1) for p, q, z0, z1 in holes["front"]]
        damp(front, x0, x1, fh, kind, "x")
        damp(back, -x1, -x0, [(-q, -p, z0, z1) for p, q, z0, z1 in holes["back"]], kind, "x")
    for sg in (-1, 1):
        _, kind = wall_of(sg * W / 2)
        geo.LEVEL = L01
        plinth(gables[sg], -D / 2, D / 2, kind)
        damp(gables[sg], -D / 2, D / 2, [], kind, "y")

    # ================================================= granite quoins on the render corners
    for ex in (-1, 1):
        _, kind = wall_of(ex * W / 2)
        if kind == "Stone":
            continue
        xe = ex * W / 2
        geo.LEVEL = L01
        for sy in (-1, 1):
            ztop_q = E - 0.03 if not (sh and sy < 0) else sh - 0.08
            z, kq = 0.46, 0
            while z + 0.2 < ztop_q:
                zq = min(z + 0.28, ztop_q)
                la, lb = (0.4, 0.22) if kq % 2 == 0 else (0.22, 0.4)
                q = trim("Sill", 1.0)
                ylo, yhi = sorted((sy * D / 2, sy * (D / 2 + 0.025)))
                xlo, xhi = sorted((xe - ex * la, xe + ex * 0.025))
                pt.box((xlo, ylo, z), (xhi, yhi, zq), q, skip=("+y" if sy < 0 else "-y",))
                ylo, yhi = sorted((sy * (D / 2 - lb), sy * D / 2))
                xlo, xhi = sorted((xe, xe + ex * 0.025))
                pt.box((xlo, ylo, z), (xhi, yhi, zq), q, skip=("+x" if ex < 0 else "-x", "+y" if sy > 0 else "-y"))
                z, kq = z + 0.3, kq + 1

    # ================================================= granite sill bands (upper floors of granite fronts / backs)
    for k, (x0, x1, kind) in enumerate(v["units"]):
        if kind != "Stone":
            continue
        for side, wall, wl in (("front", front, v["front"]), ("back", back, v["back"])):
            levels = sorted(set(sl for (x, sl, w, h, kd, ii, lit) in wl if sl > 1.5 and x0 <= (x if side == "front" else x) <= x1))
            for z0 in levels:
                zb0, zb1 = z0 - 0.11, z0 - 0.045
                hs = [(p, q) for p, q, a, b in holes[side] if a < zb1 and b > zb0]
                s0, s1 = (x0, x1) if side == "front" else (-x1, -x0)
                hs = hs if side == "front" else [(-q, -p) for p, q in hs]
                for a, b in spans(s0, s1, hs):
                    geo.LEVEL = L01
                    wall.prism(pt, a, b, [(0.0, zb0), (0.035, zb0), (0.035, zb1 - 0.012), (0.0, zb1)], trim("Sill", 1.0))
                    geo.LEVEL = L2
                    wall.box(pt, a, b, 0.0, 0.035, zb0, zb1, trim("Sill", 1.0))
    geo.LEVEL = ALL

    # ================================================= slate hanging (upper storey)
    if sh:
        up = [hh for hh in holes["front"] if hh[3] > sh]
        geo.LEVEL = L01
        pr.pierced([(-W / 2, sh), (W / 2, sh), (W / 2, E), (-W / 2, E)], "y", -D / 2 - 0.045, -D / 2, up, ("tile", 1.0))
        geo.LEVEL = L2
        pr.box((-W / 2, -D / 2 - 0.045, sh), (W / 2, -D / 2, E), ("tile", 1.0), skip=("+y",))
        geo.LEVEL = ALL
        pd.box((-W / 2, -D / 2 - 0.07, sh - 0.06), (W / 2, -D / 2, sh + 0.015), strip("Lead", 2.0), skip=("+y",))

    # ================================================= windows
    def floor_below(side, x, w, z0):
        c = [z1 + 0.22 for p, q, a, z1 in holes[side] if z1 < z0 - 0.05 and p < x + w / 2 and q > x - w / 2]
        return max([0.46] + c)

    def window(wall, side, x, s, sill, w, h, kind, ii, lit, stone):
        s0, s1, z0, z1 = s - w / 2, s + w / 2, sill, sill + h
        po = 0.045 if (sh and side == "front" and z0 > sh) else 0.0      # stands proud of the slate hanging
        fw = 0.065
        PAINT = strip("Paint", 1.0)
        counters["win"] += 1
        style = (counters["win"] + i) % 4          # 0 curtains, 1 roller blind, 2 lace nets, 3 open sash (or blind)
        lift = 0.14 if (style == 3 and kind == "sash") else 0.0
        geo.LEVEL = L01
        for a, b, c, d in ((s0, s0 + fw, z0, z1), (s1 - fw, s1, z0, z1), (s0, s1, z0, z0 + fw * 1.3), (s0, s1, z1 - fw, z1)):
            wall.box(pd, a, b, -FR - 0.1, -FR, c, d, PAINT, skip_back=False)
        i0, i1, j0, j1 = s0 + fw, s1 - fw, z0 + fw * 1.3, z1 - fw
        if kind == "sash":
            zm = (j0 + j1) / 2
            for (oa, ob, za, zb) in ((-FR - 0.085, -FR - 0.035, j0 + lift, zm + 0.02 + lift), (-FR - 0.05, -FR - 0.0, zm - 0.02, j1)):
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
                if za > zm:      # horns at the upper sash's bottom ends
                    for a in (i0, i1 - sw):
                        wall.box(pd, a + 0.008, a + sw - 0.008, oa + 0.005, ob - 0.005, za - 0.05, za, PAINT, skip_back=False)
                geo.LEVEL = L01
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
        # glass (an open sash leaves the bottom gap unglazed), lit pane, blind / nets, curtains, room backplate
        wall.quad(pg, i0, i1, -FR - 0.055, j0 + lift, j1, rect(MT.GLASS, i1 - i0, j1 - j0 - lift))
        if lit:
            wall.quad(pl, i0, i1, -FR - 0.075, j0 + lift, j1, rect(MT.WIN_LIT[ii], i1 - i0, j1 - j0 - lift))
            counters["lampw"] += 1
            atts["ATT_Lamp_Window_%02d" % counters["lampw"]] = wall.world(s, -T + 0.15, (z0 + z1) / 2 + 0.1)
        if style == 1 or (style == 3 and kind != "sash"):
            fr = 0.28 + 0.18 * ((ii + i) % 3) / 2
            wall.quad(pk, i0, i1, -FR - 0.12, j1 - fr * (j1 - j0), j1, rect(MT.BLIND, i1 - i0, fr * (j1 - j0)))
        if style == 2:
            wall.quad(pk, i0, i1, -FR - 0.13, j0, j0 + 0.58 * (j1 - j0), rect(MT.LACE, i1 - i0, 0.58 * (j1 - j0)))
        geo.LEVEL = L0
        if style != 2:
            cwid = (i1 - i0) * (0.2 if style != 3 else 0.26)
            wall.quad(pd, i0, i0 + cwid, -FR - 0.2, j0, j1, rect(MT.WIN_DIM[ii], cwid, j1 - j0, sub=(0.0, 0.2)))
            wall.quad(pd, i1 - cwid, i1, -FR - 0.2, j0, j1, rect(MT.WIN_DIM[ii], cwid, j1 - j0, sub=(0.8, 1.0)))
        geo.LEVEL = L01
        wall.quad(pd, s0, s1, -T + 0.002, z0, z1, rect(MT.WIN_DIM[ii], s1 - s0, z1 - z0))
        # drip-grooved granite sill (weathered top), projecting granite lintel, a streak under the sill
        wall.prism(pt, s0 - 0.09, s1 + 0.09, [(-FR - 0.02, z0 + 0.02), (po + 0.07, z0 - 0.01), (po + 0.07, z0 - 0.065),
                                              (po + 0.045, z0 - 0.065), (po + 0.045, z0 - 0.05), (po + 0.03, z0 - 0.05),
                                              (po + 0.03, z0 - 0.065), (-FR - 0.02, z0 - 0.065)], trim("Sill", 1.0))
        fl = floor_below(side, x, w, z0)
        ln = min(0.95 if z0 > 1.5 else 0.6, z0 - 0.065 - fl)
        if ln > 0.15:
            wall.quad(pk, s0 - 0.05, s1 + 0.05, po + 0.004, z0 - 0.065 - ln, z0 - 0.065,
                      rect(MT.STREAKS[(ii + i + (0 if stone else 2)) % 4], s1 - s0 + 0.1, ln))
        geo.LEVEL = ALL
        wall.box(pt, s0 - 0.15, s1 + 0.15, po, po + 0.04, z1, z1 + 0.2, trim("Sill", 1.0), skip_back=True)
        # LOD2 flush card
        geo.LEVEL = L2
        far = 6 if kind == "sash" else 7
        wall.quad(pd, s0, s1, 0.006, z0, z1, rect(MT.WIN_DIM[far], s1 - s0, z1 - z0))
        wall.quad(pg, s0, s1, 0.009, z0, z1, rect(MT.GLASS, s1 - s0, z1 - z0))
        if lit:
            wall.quad(pl, s0, s1, 0.012, z0, z1, rect(MT.WIN_LIT[far], s1 - s0, z1 - z0))
        wall.box(pt, s0 - 0.09, s1 + 0.09, 0.0, po + 0.07, z0 - 0.065, z0, trim("Sill", 1.0), skip_back=True)
        geo.LEVEL = ALL

    for (x, sill, w, h, kind, ii, lit) in v["front"]:
        window(front, "front", x, x, sill, w, h, kind, ii, lit, wall_of(x)[1] == "Stone")
    for (x, sill, w, h, kind, ii, lit) in v["back"]:
        window(back, "back", x, -x, sill, w, h, kind, ii, lit, wall_of(x)[1] == "Stone")

    # ================================================= doors: frames, leaves, surrounds, lintels, thresholds, steps
    porch_d = 1.0 if v.get("porch") else 0.0
    for (x, col, fan) in v["doors"]:
        top = 2.5 if fan else 2.15
        PAINT = strip("Paint", 1.0)
        stone = wall_of(x)[1] == "Stone"
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
        front.box(pd, x - 0.41, x + 0.41, -0.16, -0.11, 0.15, 2.08, rect(MT.DOORS[col], 0.82, 1.96), skip_back=False)
        front.box(pd, x - 0.41, x + 0.41, -0.17, -0.02, 0.10, 0.15, strip("Step", 1.0), skip_back=False)   # threshold
        if not porch_d:
            if stone:      # dressed granite block jambs, alternating long / short
                z, kq = 0.12, 0
                while z < top - 0.05:
                    zq = min(z + 0.42, top)
                    wb = 0.3 if kq % 2 == 0 else 0.2
                    for a, b in ((x - 0.48 - wb, x - 0.48), (x + 0.48, x + 0.48 + wb)):
                        front.box(pt, a, b, 0.0, 0.035, z, zq - 0.015, trim("Sill", 1.0))
                    z, kq = z + 0.43, kq + 1
            else:          # raised plain render surround
                part, mode = surf(wall_of(x)[1], 0.37, 0.0)
                for a, b in ((x - 0.63, x - 0.48), (x + 0.48, x + 0.63)):
                    front.box(part, a, b, 0.0, 0.022, 0.12, top, mode)
        geo.LEVEL = L2
        front.quad(pd, x - 0.48, x + 0.48, 0.006, 0.12, top, rect(MT.DOORS[col], 0.96, top - 0.12))
        geo.LEVEL = ALL
        front.box(pt, x - 0.68, x + 0.68, 0.0, 0.045, top, top + 0.22, trim("Sill", 1.0), skip_back=True)
        if porch_d:
            front.box(pd, x - 0.6, x + 0.6, -0.13, 0.32 + porch_d, 0.0, 0.12, strip("Step", 1.2), skip_back=False)
        else:
            front.box(pd, x - 0.7, x + 0.7, -0.02, 0.5, 0.0, 0.06, strip("Step", 1.4), skip_back=False)
            front.box(pd, x - 0.6, x + 0.6, -0.13, 0.27, 0.06, 0.12, strip("Step", 1.2), skip_back=False)
        counters["door"] += 1
        atts["ATT_Door" if counters["door"] == 1 else "ATT_Door_%02d" % counters["door"]] = front.world(x, 0.45 + porch_d, 0.12)
    if v.get("porch"):
        x = v["doors"][0][0]
        _, kind = wall_of(x)
        part, mode = surf(kind, 0.52)
        geo.LEVEL = ALL
        for sg in (-1, 1):
            xa, xb = sorted((x + sg * 0.76, x + sg * 0.54))
            part.box((xa, -D / 2 - 1.0, 0.0), (xb, -D / 2, 2.3), mode)
        pd.box((x - 0.78, -D / 2 - 1.02, 2.12), (x + 0.78, -D / 2 - 0.86, 2.32), strip("Paint", 1.0))
        pr.prism([(-D / 2 - 1.15, 2.32), (-D / 2, 2.78), (-D / 2, 2.84), (-D / 2 - 1.15, 2.38)], "x", x - 0.9, x + 0.9, ("tile", 2.0))
        pd.box((x - 0.9, -D / 2 - 0.02, 2.78), (x + 0.9, -D / 2 + 0.0, 2.98), strip("Lead", 2.0), skip=("+y",))

    # ================================================= lanterns (+ rust weep below the bracket)
    for (x, z) in v["lamps"]:
        IRON = strip("Iron", 0.5)
        geo.LEVEL = L0
        front.box(pd, x - 0.02, x + 0.02, 0.0, 0.2, z + 0.16, z + 0.2, IRON, skip_back=False)
        front.box(pd, x - 0.05, x + 0.05, 0.0, 0.015, z + 0.08, z + 0.26, IRON, skip_back=False)
        for a in (-0.09, 0.07):
            for b in (0.15, 0.31):
                front.box(pd, x + a, x + a + 0.02, b, b + 0.02, z - 0.13, z + 0.14, IRON, skip_back=False)
        geo.LEVEL = L01
        front.quad(pk, x - 0.07, x + 0.07, 0.004, z - 0.4, z + 0.08, rect(MT.STREAKS[0], 0.14, 0.48))
        front.box(pd, x - 0.11, x + 0.11, 0.13, 0.35, z + 0.14, z + 0.2, IRON, skip_back=False)
        front.box(pd, x - 0.05, x + 0.05, 0.19, 0.29, z + 0.2, z + 0.25, IRON, skip_back=False)
        front.box(pd, x - 0.1, x + 0.1, 0.14, 0.34, z - 0.18, z - 0.13, IRON, skip_back=False)
        front.box(pg, x - 0.085, x + 0.085, 0.155, 0.325, z - 0.13, z + 0.14, rect(MT.GLASS, 0.17, 0.27), skip_back=False)
        front.box(pl, x - 0.055, x + 0.055, 0.185, 0.295, z - 0.1, z + 0.1, rect(MT.LANTERN, 0.11, 0.2), skip_back=False)
        counters["lampd"] += 1
        atts["ATT_Lamp_Door_%02d" % counters["lampd"]] = front.world(x, 0.24, z)
        geo.LEVEL = ALL

    # ================================================= roof: stepped slate courses, eaves, verges, ridge
    slope_uv = ("fn", lambda p: (p.x / 2.0, s_of(p) / 2.0))
    riser_uv = ("fn", lambda p: (p.x / 2.0, s_of(p) / 2.0 - 0.012 + 0.01 * min(1.0, max(0.0, (p.z - ztop(s_of(p))) / STEP))))
    xr0, xr1 = -W / 2 - VERGE, W / 2 + VERGE
    for sg in (-1, 1):
        ye = y_of(sg, 0.0)
        top = [(ye, ztop(0.0) + STEP)]
        kk = 1
        while kk * C < S_MAX - 0.03:
            s = kk * C
            top += [(y_of(sg, s), ztop(s)), (y_of(sg, s), ztop(s) + STEP)]
            kk += 1
        top.append((0.0, R + SLAB))
        poly = top + [(0.0, R), (ye, ze)]
        modes = [riser_uv if abs(a[0] - b[0]) < 1e-9 else slope_uv for a, b in zip(top, top[1:])]
        modes += [("tile", 2.0), ("tile", 2.0), ("tile", 0.5)]
        geo.LEVEL = L01
        pr.extrude(poly, "x", xr0, xr1, modes, caps=True, cap_mode=("tile", 0.5))
        geo.LEVEL = L2
        pr.prism([(ye, ze), (0.0, R), (0.0, R + SLAB), (ye, ze + SLAB + STEP)], "x", xr0, xr1, ("tile", 2.0))
        # fascia board under the eaves slates
        geo.LEVEL = ALL
        yf0, yf1 = sorted((sg * (RUN - 0.065), sg * (RUN - 0.04)))
        zf = ze + P * 0.04
        pt.box((xr0 + 0.035, yf0, zf - 0.17), (xr1 - 0.035, yf1, zf + 0.01), trim("Fascia", 2.0))
        # bargeboards under the verges (both ends), running from the fascia up to the apex
        ya = sg * (RUN - 0.04)
        for ex in (-1, 1):
            xa, xb = sorted((ex * (W / 2 + VERGE - 0.035), ex * (W / 2 + VERGE - 0.01)))
            pt.prism([(ya, R - P * abs(ya) + 0.01), (0.0, R + 0.01), (0.0, R - 0.21), (ya, R - P * abs(ya) - 0.21)],
                     "x", xa, xb, trim("Fascia", 2.0))
        # moss on the north (+Y, back) slope: Grime decals on the lowest six courses and the two under the ridge
        if sg > 0:
            geo.LEVEL = ALL
            kmax = int(S_MAX / C)
            b0, b1 = MT.GRIME_BANDS["Moss"]
            for kset, base in ((range(0, 6), 0), (range(kmax - 2, kmax), kmax - 2)):
                for kc in kset:
                    sa, sb = kc * C, min((kc + 1) * C, S_MAX - 0.15)
                    if sb <= sa:
                        continue
                    mode = ("fn", lambda p, base=base: (p.x / MT.MOSS_U, b0 + 0.003 + min(1.0, max(0.0, (s_of(p) - base * C) / MT.MOSS_S)) * (b1 - b0 - 0.006)))
                    pk.face([(xr0, y_of(sg, sa), ztop(sa) + STEP + 0.004), (xr1, y_of(sg, sa), ztop(sa) + STEP + 0.004),
                             (xr1, y_of(sg, sb), ztop(sb) + 0.004 + STEP * (1 - (sb - sa) / C)),
                             (xr0, y_of(sg, sb), ztop(sb) + 0.004 + STEP * (1 - (sb - sa) / C))], mode, outward=(0, 0, 1))
    geo.LEVEL = ALL
    rr = 0.135
    zc = R + SLAB - P * rr + 0.035
    zb_ = R + SLAB - P * (rr + 0.03)
    pd.prism([(-rr - 0.03, zb_), (rr + 0.03, zb_), (rr, zc + 0.005), (-rr, zc + 0.005)], "x", xr0 + 0.01, xr1 - 0.01, strip("Mortar", 1.0))
    prof = [(rr * math.cos(math.pi * k / 6), zc + rr * math.sin(math.pi * k / 6)) for k in range(7)]
    pd.prism(prof, "x", xr0 + 0.01, xr1 - 0.01, strip("Ridge", 0.9))
    geo.LEVEL = L0
    xk = xr0 + 0.01
    while xk + 0.47 < xr1:
        prof2 = [(0.148 * math.cos(math.pi * k / 4), zc + 0.148 * math.sin(math.pi * k / 4)) for k in range(5)]
        pd.prism(prof2, "x", xk + 0.43, xk + 0.46, strip("Mortar", 0.5))
        xk += 0.45
    geo.LEVEL = ALL

    # ================================================= hollow half-round gutters on brackets, cast-iron downpipes
    r = 0.065
    gx0, gx1 = xr0 + 0.04, xr1 - 0.04
    for sg in (-1, 1):
        yc = sg * (RUN + 0.035)
        zg = ze - 0.025
        outer = [(yc + r * math.cos(math.pi + math.pi * k / 8), zg + r * math.sin(math.pi + math.pi * k / 8)) for k in range(9)]
        inner = [(yc + (r - 0.006) * math.cos(math.pi + math.pi * k / 8), zg + (r - 0.006) * math.sin(math.pi + math.pi * k / 8)) for k in range(9)]
        geo.LEVEL = L01
        pt.extrude(outer + inner[::-1], "x", gx0, gx1, trim("Gutter", 2.0))
        half = [(yc + r * math.cos(math.pi + math.pi * k / 6), zg + r * math.sin(math.pi + math.pi * k / 6)) for k in range(7)]
        for a, b in ((gx0, gx0 + 0.008), (gx1 - 0.008, gx1)):
            pt.prism(half, "x", a, b, trim("Gutter", 2.0))
        geo.LEVEL = L2
        pt.prism(half, "x", gx0, gx1, trim("Gutter", 2.0))
        geo.LEVEL = L0
        pt.tube((gx0, yc + sg * (r - 0.002), zg + 0.004), (gx1, yc + sg * (r - 0.002), zg + 0.004), 0.009, 6, trim("Gutter", 2.0))
        yfo = sg * (RUN - 0.04)
        xb = -W / 2 + 0.2
        while xb < W / 2:
            arc_o = [(yc + (r + 0.009) * math.cos(math.pi + math.pi * k / 8), zg + (r + 0.009) * math.sin(math.pi + math.pi * k / 8)) for k in range(9)]
            arc_i = [(yc + (r + 0.001) * math.cos(math.pi + math.pi * k / 8), zg + (r + 0.001) * math.sin(math.pi + math.pi * k / 8)) for k in range(9)]
            pd.extrude(arc_o + arc_i[::-1], "x", xb - 0.0125, xb + 0.0125, strip("Iron", 0.5))
            ylo, yhi = sorted((yfo, yfo + sg * 0.008))
            pd.box((xb - 0.02, ylo, zg - 0.06), (xb + 0.02, yhi, zg + 0.02), strip("Iron", 0.5))
            xb += 0.85
        geo.LEVEL = ALL
    pipes = [(W / 2 - 0.25, -1), (-W / 2 + 0.25, 1)]
    if len(v["units"]) > 1:
        pipes.append((0.0, -1) if i != 5 else (-W / 2 + 0.25, -1))
    for (x, sg) in pipes:
        yw = sg * (D / 2 + 0.095)
        yc = sg * (RUN + 0.035)
        zg = ze - 0.025
        z1, z2 = zg - r - 0.1, zg - r - 0.42
        DP = trim("Downpipe", 1.0)
        geo.LEVEL = L01
        pt.tube((x, yc, zg - r + 0.02), (x, yc, z1), 0.04, 10, DP)
        pt.tube((x, yc, z1), (x, yw, z2), 0.04, 10, DP)
        pt.tube((x, yw, z2), (x, yw, 0.28), 0.04, 10, DP)
        pt.tube((x, yw, 0.28), (x, yw + sg * 0.12, 0.1), 0.042, 10, DP)
        pd.box((x - 0.15, yw + sg * 0.04 - 0.15, 0.0), (x + 0.15, yw + sg * 0.04 + 0.15, 0.025), strip("Iron", 0.5))   # gully grate
        geo.LEVEL = L0
        socks = [z1, z2]
        zq = z2 - 0.05
        while zq > 0.6:
            socks.append(zq)
            zq -= 1.8
        socks.append(0.28)
        for zq in socks:
            yq = yc if zq == z1 else yw
            pt.tube((x, yq, zq - 0.035), (x, yq, zq + 0.035), 0.049, 10, DP)
            if yq == yw and zq not in (z2, 0.28):      # ears + spacer bobbins to the wall
                ylo, yhi = sorted((yw - sg * 0.045, yw - sg * 0.033))
                pd.box((x - 0.085, ylo, zq - 0.03), (x + 0.085, yhi, zq + 0.03), strip("Iron", 0.5))
                for a in (-0.065, 0.065):
                    ylo, yhi = sorted((sg * D / 2, yw - sg * 0.045))
                    pd.box((x + a - 0.012, ylo, zq - 0.012), (x + a + 0.012, yhi, zq + 0.012), strip("Iron", 0.5))
        geo.LEVEL = ALL

    # ================================================= chimneys: corbelled stacks, cap slab, flaunching, open pots, lead
    hy = 0.38
    zr = R + SLAB - P * hy            # roof top line where the stack's front / back faces meet the slates
    stacks = []
    for cidx, (xc, kind, wk) in enumerate(v["chimneys"]):
        part, mode = surf(wk, 0.27, -0.12)
        if kind == "gable":
            ex = 1 if xc > 0 else -1
            xa, xb = sorted((ex * (W / 2 - 0.65), ex * (W / 2 + VERGE + VR.STACK_OUT)))
            zb0 = R - P * hy - 0.26
        else:
            ex = 0
            xa, xb = xc - 0.4, xc + 0.4
            zb0 = E
        stacks.append((xa, xb))
        geo.LEVEL = ALL
        part.box((xa, -hy, zb0), (xb, hy, zs - 0.22), mode)
        if ex:      # stepped corbel carrying the stack out over the verge
            ov = VERGE + VR.STACK_OUT
            for kq, (za, zb) in enumerate(((zb0 - 0.09, zb0), (zb0 - 0.18, zb0 - 0.09))):
                xo = ex * (W / 2 + ov * (2 - kq) / 3)
                lo, hi = sorted((ex * W / 2, xo))
                part.box((lo, -hy + 0.02 * kq, za), (hi, hy - 0.02 * kq, zb), mode, skip=("+x" if ex < 0 else "-x",))
        for kq, (za, zb, o) in enumerate(((zs - 0.22, zs - 0.14, 0.04), (zs - 0.14, zs - 0.06, 0.08))):   # corbel course
            part.box((xa - o, -hy - o, za), (xb + o, hy + o, zb), mode)
        pd.box((xa - VR.CAP_OVER, -hy - VR.CAP_OVER, zs - 0.06), (xb + VR.CAP_OVER, hy + VR.CAP_OVER, zs), strip("Step", 1.2))  # cap slab
        pd.box((xa + 0.06, -hy + 0.06, zs), (xb - 0.06, hy - 0.06, zs + 0.05), strip("Mortar", 1.0))                         # flaunching
        # soot under the corbel course
        geo.LEVEL = L01
        zt0 = zs - 0.22 - MT.SOOT_H
        for wl, s0, s1, along in ((Wall((0, -1, 0), -hy), xa, xb, "x"), (Wall((0, 1, 0), hy), -xb, -xa, "x"),
                                  (Wall((-1, 0, 0), xa), -hy, hy, "y"), (Wall((1, 0, 0), xb), -hy, hy, "y")):
            wl.quad(pk, s0, s1, 0.003, zt0, zs - 0.22, gband("Soot", zt0, MT.SOOT_H, along, MT.SOOT_U))
        # lead: aprons + upstands on the front / back faces, stepped flashing + soakers on the faces the slopes climb
        LEAD = strip("Lead", 1.0)
        la, lb = max(xa - 0.03, xr0), min(xb + 0.03, xr1)
        for sg in (-1, 1):
            ylo, yhi = sorted((sg * hy, sg * (hy + 0.012)))
            pd.box((la, ylo, zr - 0.01), (lb, yhi, zr + STEP + 0.15), LEAD)
            pd.prism([(sg * hy, zr + STEP + 0.012), (sg * (hy + 0.17), zr + STEP + 0.012 - P * 0.17),
                      (sg * (hy + 0.17), zr + STEP - P * 0.17 + 0.002), (sg * hy, zr + STEP + 0.002)], "x", la, lb, LEAD)
        faces = [(xa, -1), (xb, 1)] if not ex else [((xa, -1) if ex > 0 else (xb, 1))]
        for xf, dx in faces:
            for sg in (-1, 1):
                xlo, xhi = sorted((xf, xf + dx * 0.12))
                pd.prism([(0.0, R + SLAB + STEP + 0.012), (sg * hy, zr + STEP + 0.012), (sg * hy, zr + STEP + 0.002),
                          (0.0, R + SLAB + STEP + 0.002)], "x", xlo, xhi, LEAD)
            geo.LEVEL = L0
            nst = 8
            for q in range(nst):
                ya_, yb_ = -hy + 2 * hy * q / nst, -hy + 2 * hy * (q + 1) / nst
                zsurf = R + SLAB + STEP - P * (0.0 if ya_ < 0 < yb_ else min(abs(ya_), abs(yb_)))
                xlo, xhi = sorted((xf, xf + dx * 0.012))
                pd.box((xlo, ya_, zsurf - 0.02), (xhi, yb_, zsurf + 0.13), LEAD)
            geo.LEVEL = L01
        geo.LEVEL = ALL
        # pots: lathed, open flue, irregular heights
        n = 2 if kind == "gable" else 3
        xm = (xa + xb) / 2
        PV = MT.STRIPS["Pot"]
        for q in range(n):
            px_ = xm + (q - (n - 1) / 2) * 0.3
            hgt = VR.pot_h(i, cidx, q)
            zb = zs + 0.02
            rb = 0.15 + 0.01 * ((q + cidx) % 2)
            rings = [(rb, zb), (rb, zb + 0.06), (rb - 0.015, zb + hgt * 0.45), (rb - 0.03, zb + hgt - 0.1),
                     (rb - 0.01, zb + hgt - 0.085), (rb - 0.01, zb + hgt - 0.02), (rb - 0.022, zb + hgt)]
            geo.LEVEL = L01
            lathe(pd, px_, 0.0, rings, 12, (PV[0] + 0.004, PV[1] - 0.004), zb, hgt, inner=(rb - 0.06, 0.3),
                  cap_mode=strip("Tar", 0.5))
            lathe(pd, px_, 0.0, [(rb + 0.05, zs + 0.05), (rb + 0.005, zs + 0.13)], 12, (MT.STRIPS["Mortar"][0] + 0.004, MT.STRIPS["Mortar"][1] - 0.004),
                  zs, 0.2, cap_mode=strip("Mortar", 0.5))
            geo.LEVEL = L2
            pd.tube((px_, 0.0, zb), (px_, 0.0, zb + hgt), rb - 0.02, 6, strip("Pot", 0.7))
            geo.LEVEL = ALL
            counters["smoke"] += 1
            atts["ATT_Smoke_%02d" % counters["smoke"]] = Vector((px_, 0.0, zb + hgt))

    # ================================================= objects
    mats = {"Walls": geo.material("MI_Cottage_Walls", (0.6, 0.5, 0.45), 0.9), "Stone": geo.material("MI_Cottage_Stone", (0.2, 0.18, 0.15), 0.85),
            "Roof": geo.material("MI_Cottage_Slate", (0.07, 0.08, 0.09), 0.6), "Trim": geo.material("MI_Cottage_Trim", (0.3, 0.3, 0.3), 0.6),
            "Details": geo.material("MI_Cottage_Details", (0.3, 0.3, 0.3), 0.6), "Glass": geo.material("MI_Cottage_Glass", (0.05, 0.06, 0.07), 0.05),
            "GlassLit": geo.material("MI_Cottage_GlassLit", (0.9, 0.7, 0.45), 0.3),
            "Grime": geo.material("MI_Cottage_Grime", (0.3, 0.3, 0.26), 0.8)}
    render_set = next((kd for _, _, kd in v["units"] if kd != "Stone"), None)
    if render_set is None:
        render_set = next((wk for _, _, wk in v["chimneys"] if wk != "Stone"), None)
    sets_of = {"Walls": render_set, "Stone": "Stone", "Roof": "Slate", "Trim": "Sheet", "Details": "Details", "Glass": "Details", "GlassLit": "Details", "Grime": "Grime"}
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
    for (xa, xb) in stacks:
        col.box((xa, -hy, E), (xb, hy, zs), ("tile", 1.0))
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
                    "texture sets": "shared H3 kit sets (Render colour, Stone, Slate, Details, H3b Grime RGBA decals) + the shared building trim "
                                    "sheet: resident once for the whole street, not per house"},
        "sets": sets,
        "meshes": meshes + [{"object": colobj}],
        "attachments": att_objs,
        "closeups": [
            {"name": "door_lantern", "target": st(dx, -D / 2, 1.4), "dist": 9, "az": 18, "el": 6},
            {"name": "window_parallax", "target": st(v["front"][0][0], -D / 2, v["front"][0][1] + 0.6), "dist": 7, "az": 30, "el": 4},
            {"name": "eaves_gutter", "target": st(W / 2 - 0.4, -D / 2 - 0.2, E - 0.2), "dist": 8, "az": 35, "el": 12},
            {"name": "chimney_ridge", "target": st(sum(stacks[0]) / 2, 0.0, zs), "dist": 10, "az": -30, "el": 25},
            {"name": "base_damp", "target": st(-W / 2 + 0.8, -D / 2, 0.5), "dist": 6, "az": -20, "el": 8},
        ],
    }
