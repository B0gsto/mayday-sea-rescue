"""Shared build for the premium Robux jet skis M_Veh_JetSki_RiptideX and M_Veh_JetSki_GildedGull (2026-10-22).

Both reuse the M_Veh_JetSki generators (pwc.py / pwcgeo.py) and its frame: same scale, base origin, forward (-Y here,
-Z in Roblox), frame offset and every ATT_ marker (Boat/Builder buildJetSkiAsset places seat, lamps, survivor slot,
tow hitch and bow point from the base's markers, so the premium meshes must sit on them). A style dict re-skins the
palette and swaps the hull section, seat, decals, foredeck and fittings:
  RiptideX: sharp sport hull (deep V, hard topside crease, faceted ridge hood, spray strakes), graphite and forged
            carbon, neon cyan rail band / slashes / pinstripes / piping, sculpted bolstered seat, chrome hood scoop grille.
  GildedGull: pearl-white gelcoat, polished gold rail, underbody and fittings, gold pinstripes and gull emblem, cream
            quilted leather seat with gold stitching and piping, teak decking, swept gold gull-wing fins.
"""
import importlib.util
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

VEH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(VEH, "M_Veh_JetSki")
sys.path.insert(0, BASE)
import pwcgeo as R  # noqa: E402
import pwc as P  # noqa: E402
import rbxkit  # noqa: E402

# base build (by path: run.py may already hold a module called "build"): markers, floats, collision, UV boost,
# all evaluated here, before any style patches the hull
_spec = importlib.util.spec_from_file_location("jetski_base_build", os.path.join(BASE, "build.py"))
B = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(B)
BASE_OFF = Vector(json.load(open(os.path.join(BASE, "frame_offset.json")))["offset"])
M, smooth = P.M, P.smooth


# =========================================================================== custom shader patterns
def _sep(nt):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    s = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], s.inputs[0])
    return tc.outputs["Object"], s


def _math(nt, op, a, b=None, c=None):
    n = nt.nodes.new("ShaderNodeMath")
    n.operation = op
    for i, v in enumerate((a, b, c)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            n.inputs[i].default_value = v
        else:
            nt.links.new(v, n.inputs[i])
    return n.outputs[0]


def _maprange(nt, v, f0, f1, t0=0.0, t1=1.0):
    n = nt.nodes.new("ShaderNodeMapRange")
    n.clamp = True
    n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = f0, f1
    n.inputs["To Min"].default_value, n.inputs["To Max"].default_value = t0, t1
    nt.links.new(v, n.inputs["Value"])
    return n.outputs[0]


def _line(nt, c, period, hw):
    """1 on lines every `period` studs along coordinate socket c (half width hw, soft edge), else 0."""
    f = _math(nt, "FRACT", _math(nt, "DIVIDE", c, period))
    d = _math(nt, "MULTIPLY", _math(nt, "MINIMUM", f, _math(nt, "SUBTRACT", 1.0, f)), period)
    return _maprange(nt, d, hw, hw * 1.7, 1.0, 0.0), d


def _noise(nt, vec, scale, detail=2.0, stretch=None):
    if stretch:
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = stretch
        nt.links.new(vec, mp.inputs["Vector"])
        vec = mp.outputs[0]
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    nt.links.new(vec, n.inputs["Vector"])
    return n.outputs["Fac"]


def _mixc(nt, a, hexc, fac):
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(fac, mx.inputs["Factor"])
    nt.links.new(a, R._ci(mx, 0))
    R._ci(mx, 1).default_value = R._hex_srgb(hexc) + (1.0,)
    return R._co(mx)


def _bump(nt, height, strength, normal=None):
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = strength
    b.inputs["Distance"].default_value = 0.02
    nt.links.new(height, b.inputs["Height"])
    if normal is not None:
        nt.links.new(normal, b.inputs["Normal"])
    return b.outputs["Normal"]


def pattern(name, kind):
    """Adds a pattern on top of a PROC material (BAKE_BASE colour, BAKE_MR roughness, shading-normal bump)."""
    mat = R.material(name)
    nt = mat.node_tree
    L = nt.links.new
    base, mr = nt.nodes["BAKE_BASE"], nt.nodes["BAKE_MR"]
    bsdf = nt.nodes["Principled BSDF"]
    col = base.inputs["Color"].links[0].from_socket
    rgh = mr.inputs["Y"].links[0].from_socket
    nrm = bsdf.inputs["Normal"].links[0].from_socket if bsdf.inputs["Normal"].links else None
    co, s = _sep(nt)
    if kind == "teak":
        # 0.3-stud (10 cm) planks fore and aft, black caulking, per-plank tone, long grain
        caulk, _ = _line(nt, s.outputs["X"], 0.3, 0.014)
        cx = nt.nodes.new("ShaderNodeCombineXYZ")
        fl = _math(nt, "FLOOR", _math(nt, "DIVIDE", s.outputs["X"], 0.3))
        L(fl, cx.inputs["X"])
        L(_math(nt, "MULTIPLY", fl, 1.7), cx.inputs["Y"])
        tone = _noise(nt, cx.outputs[0], 1.3)
        col = _mixc(nt, col, "#6E4E33", _maprange(nt, tone, 0.35, 0.65, 0.0, 0.55))
        grain = _noise(nt, co, 3.0, 8.0, stretch=(14.0, 0.6, 14.0))
        col = _mixc(nt, col, "#A9845E", _maprange(nt, grain, 0.45, 0.7, 0.0, 0.45))
        col = _mixc(nt, col, "#2B2622", caulk)
        rgh = _math(nt, "MULTIPLY_ADD", caulk, 0.15, rgh)
        h = _math(nt, "SUBTRACT", _math(nt, "MULTIPLY", grain, 0.15), caulk)
        nrm = _bump(nt, h, 0.5, nrm)
    elif kind == "quilt":
        # diamond quilting (0.5-stud cells, 45 deg) with gold lock-stitch dashes in the grooves, puffed cushions
        cu = nt.nodes.new("ShaderNodeVectorMath")
        cu.operation = "DOT_PRODUCT"
        L(co, cu.inputs[0])
        cu.inputs[1].default_value = (0.7071, 0.7071, 0.0)
        cv = nt.nodes.new("ShaderNodeVectorMath")
        cv.operation = "DOT_PRODUCT"
        L(co, cv.inputs[0])
        cv.inputs[1].default_value = (0.7071, -0.7071, 0.0)
        u, v = cu.outputs["Value"], cv.outputs["Value"]
        lu, du = _line(nt, u, 0.5, 0.018)
        lv, dv = _line(nt, v, 0.5, 0.018)
        tu, _ = _line(nt, u, 0.5, 0.009)
        tv, _ = _line(nt, v, 0.5, 0.009)
        dash_u = _maprange(nt, _math(nt, "FRACT", _math(nt, "DIVIDE", v, 0.07)), 0.5, 0.6, 1.0, 0.0)
        dash_v = _maprange(nt, _math(nt, "FRACT", _math(nt, "DIVIDE", u, 0.07)), 0.5, 0.6, 1.0, 0.0)
        thread = _math(nt, "MAXIMUM", _math(nt, "MULTIPLY", tu, dash_u), _math(nt, "MULTIPLY", tv, dash_v))
        groove = _math(nt, "MAXIMUM", lu, lv)
        col = _mixc(nt, col, "#A99070", _math(nt, "MULTIPLY", groove, 0.6))
        col = _mixc(nt, col, "#B8924E", thread)
        rgh = _math(nt, "MULTIPLY_ADD", thread, -0.1, rgh)
        puff = _maprange(nt, _math(nt, "MINIMUM", du, dv), 0.0, 0.16)
        h = _math(nt, "ADD", _math(nt, "POWER", puff, 0.5), _math(nt, "MULTIPLY", thread, 0.35))
        nrm = _bump(nt, h, 0.95, nrm)
    elif kind == "forged":
        # forged carbon: black resin with pressed chopped-tow flakes (scale-free, holds at any texel density)
        a = _maprange(nt, _noise(nt, co, 20.0, 1.0), 0.49, 0.52)
        b = _maprange(nt, _noise(nt, _math_vec(nt, co, 3.1), 38.0, 1.0), 0.50, 0.53)
        col = _mixc(nt, col, "#3A3F45", _math(nt, "MULTIPLY", a, 0.55))
        col = _mixc(nt, col, "#1A1C1F", _math(nt, "MULTIPLY", b, 0.5))
        rgh = _math(nt, "MULTIPLY_ADD", a, -0.06, rgh)
    elif kind == "pearl":
        # pearlescent gelcoat: faint warm / cool drift (low frequency), no pattern
        p = _noise(nt, co, 0.35, 1.0)
        col = _mixc(nt, col, "#E9DCD3", _maprange(nt, p, 0.4, 0.65, 0.0, 0.6))
        col = _mixc(nt, col, "#DCE0DE", _maprange(nt, p, 0.35, 0.15, 0.0, 0.5))
    base.inputs["Color"].default_value = (1, 1, 1, 1)
    L(col, base.inputs["Color"])
    L(rgh, mr.inputs["Y"])
    if nrm is not None:
        L(nrm, bsdf.inputs["Normal"])


def _math_vec(nt, co, k):
    n = nt.nodes.new("ShaderNodeVectorMath")
    n.operation = "ADD"
    L = nt.links.new
    L(co, n.inputs[0])
    n.inputs[1].default_value = (k, -k, 0.5 * k)
    return n.outputs[0]


# =========================================================================== surface helpers
def topside_quad(g, sx, corners, mat, off, nu, nv):
    """Bilinear patch on the lower topside: corners (y, t) bow-low, bow-high, aft-high, aft-low (t: 0 chine crease,
    1 rub rail)."""
    (y00, t00), (y01, t01), (y11, t11), (y10, t10) = corners
    pts = []
    for i in range(nu + 1):
        a = i / nu
        row = []
        for j in range(nv + 1):
            b = j / nv
            y = (1 - a) * ((1 - b) * y00 + b * y01) + a * ((1 - b) * y10 + b * y11)
            t = (1 - a) * ((1 - b) * t00 + b * t01) + a * ((1 - b) * t10 + b * t11)
            row.append(P.side_point(sx, y, t, off))
        pts.append(row)
    fs = g.rings(pts, mat, closed=False, recalc=False)
    g.orient(fs, lambda c, sx=sx: Vector((sx, 0, 0.2)))


def topside_text(g, sx, yc, tc, body, size, mat, off, scale_x=1.0, shear=0.0):
    me = R.text_mesh(body, size, font_scale_x=scale_x)
    sd = 1.0 if sx > 0 else -1.0

    def mapfn(co):
        y = yc + sd * (co.x + shear * co.y)
        return P.side_point(sx, y, tc + co.y / P.side_len(y), off)
    fs = g.add_mesh(me, mat, mapfn)
    g.orient(fs, lambda c, sx=sx: Vector((sx, 0, 0.2)))
    bpy.data.meshes.remove(me)


def topside_stroke(g, sx, yc, tc, pts, mat, off):
    """Ribbon along (dy, dz, half width) points in studs about (yc, tc) on the topside (emblems)."""
    L = P.side_len(yc)
    vs = []
    for i, (dy, dz, w) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        n = math.hypot(ty, tz) or 1.0
        ny, nz = -tz / n, ty / n
        vs.append([P.side_point(sx, yc + dy + ny * w * k, tc + (dz + nz * w * k) / L, off) for k in (-1, 1)])
    fs = g.rings(vs, mat, closed=False, recalc=False)
    g.orient(fs, lambda c, sx=sx: Vector((sx, 0, 0.2)))


def deck_strip(g, f0, f1, y0, y1, mat, h=0.012, nu=30, nv=2):
    """Strip on the deck between beam fractions f0..f1 (x = f * half beam), y0..y1."""
    grid = []
    for i in range(nu + 1):
        y = y0 + (y1 - y0) * i / nu
        b = P.half_beam(y)
        grid.append([Vector((x, y, P.top_z(x, y) + h)) for x in
                     [(f0 + (f1 - f0) * j / nv) * b for j in range(nv + 1)]])
    fs = g.rings(grid, mat, closed=False, recalc=False)
    g.orient(fs, lambda c: Vector((0, 0, 1)))


def sled_pinline(g, mat, inset, width, z=None):
    sc, hy, hx = (P.SLED_Y0 + P.SLED_Y1) / 2, (P.SLED_Y1 - P.SLED_Y0) / 2, P.SLED_HX
    z = (z or P.SLED_Z1) + 0.006
    n = 64 if g.hi else 40
    a = R.superellipse_ring(0, sc, z, hx - inset, hy - inset, n, p=4.0)
    b = R.superellipse_ring(0, sc, z, hx - inset - width, hy - inset - width, n, p=4.0)
    fs = g.rings([a, b], mat, closed=True, recalc=False)
    g.orient(fs, lambda c: Vector((0, 0, 1)))


def rescue_text(mat):
    def fn(g):
        if not g.hi:
            return
        me = R.text_mesh("RESCUE", 0.5, font_scale_x=1.0)
        fs = g.add_mesh(me, mat, lambda c: Vector((-c.x, P.SLED_Y1 - 0.85 - c.y, P.SLED_Z1 + 0.004)))
        g.orient(fs, lambda c: Vector((0, 0, 1)))
        bpy.data.meshes.remove(me)
    return fn


# =========================================================================== sport hull (AD rounds 1-2: "reads as a tub")
# Deep-V bottom to a hard chine flat and step, short topsides leaning in (tumblehome) to a rub rail that sweeps up to
# the bow, a sloped deck shoulder (gunwale step), deep footwells (floor FOOT_Z) ending at a raised stern platform (the
# base's ZF, where the grab handle and mast stand), a raked stem (sheared aft below the bow eye), rounded stern
# quarters. Nose tip, bow eye, deck heights forward and every marker stay the base's.
HULL = dict(t_aft=0.42, t_bow=0.45, keel_nose=1.0, zg_aft=1.66, zg_rise=0.55, rail_drop=0.46, step=0.2,
            crown=3.1, rake=0.6)
FOOT_Z = 1.25
H = dict(HULL)
_half_beam = P.half_beam


def floor_z(y):
    """Footwell floor: deep along the seat, up to the stern platform (ZF) aft."""
    return FOOT_Z + (P.ZF - FOOT_Z) * smooth(3.85, 4.2, y)


def rake(co):
    """Raked stem: sheared aft below the bow eye (z 1.62), most at the forefoot, fading out 2 studs aft."""
    w = max(0.0, 1 - (co.y - P.NOSE) / 2.0)
    k = min(max((1.6 - co.z) / 0.6, 0.0), 1.0) ** 1.3
    return Vector((co.x, co.y + H["rake"] * k * w, co.z))


def raked(fn):
    def f(g):
        start = len(g.bm.verts)
        out = fn(g)
        R.deform(g, start, rake)
        return out
    return f


def use_sport_hull(**kw):
    H.update(kw)

    def half_beam(y):
        return _half_beam(y) - 0.32 * smooth(P.TRANSOM - 0.9, P.TRANSOM, y) ** 2   # rounded stern quarters

    def keel_z(y):
        return H["keel_nose"] * max(0.0, (0.4 - P._u(y)) / 0.4) ** 1.9

    def deadrise(y):
        return H["t_aft"] + H["t_bow"] * max(0.0, (0.5 - P._u(y)) / 0.5) ** 1.5

    def gunwale_z(y):
        return H["zg_aft"] + H["zg_rise"] * max(0.0, (0.5 - P._u(y)) / 0.5) ** 1.1

    def top_z(x, y):
        b, zg = P.half_beam(y), P.gunwale_z(y)
        crown = (H["crown"] - zg - 0.06) * (0.25 + 0.75 * smooth(P.NOSE, -1.5, y) ** 0.8)   # tall cowl
        hood = zg + 0.06 + crown * max(0.0, 1 - (abs(x) / b) ** 1.6) ** 0.6                   # peaked ridge
        return hood + (floor_z(y) - hood) * P.footwell(y)

    def profile(y):
        b, zk, t, zg = P.half_beam(y), P.keel_z(y), P.deadrise(y), P.gunwale_z(y)
        z2 = zk + 0.84 * b * t
        zr = max(zg - H["rail_drop"], z2 + 0.2)
        s = min(H["step"], 0.12 * b)
        x10, x11 = b - s - min(0.08, 0.05 * b), b - s - min(0.16, 0.1 * b)
        f = P.footwell(y)
        pts = [(0.0, zk), (0.45 * b, zk + 0.45 * b * t), (0.84 * b, z2), (b + 0.02, z2 + 0.01), (b + 0.03, z2 + 0.07),
               (b - 0.03, zr), (b + 0.06, zr + 0.04), (b + 0.06, zr + 0.13), (b - 0.02, zr + 0.17), (b - s, zg),
               (x10, zg + 0.03)]
        hood11 = P.top_z(x11, y)
        pts.append((x11, hood11 + (floor_z(y) - hood11) * f))
        for x in (0.35 * b, 0.17 * b, 0.0):
            pts.append((x, P.top_z(x, y)))
        return pts

    P.half_beam, P.keel_z, P.deadrise, P.gunwale_z, P.top_z, P.profile = \
        half_beam, keel_z, deadrise, gunwale_z, top_z, profile
    P.footwell = lambda y: smooth(-1.2, -0.45, y)     # console flank runs back to the (shorter) seat
    # nav housings exactly where the base put them (Builder lights them at M_Veh_JetSki's ATT_Nav markers)
    P.nav_light_pos = lambda sx: Vector(B.ATTACHMENTS["ATT_NavPort" if sx > 0 else "ATT_NavStarboard"]) - \
        Vector((sx * 0.1, -0.03, 0.0))
    # gunwale cleats onto the (stepped-in) gunwale top
    _cleat = P.cleat
    P.cleat = lambda g, c: _cleat(g, c - Vector((math.copysign(0.12, c.x), 0, 0.0)) if abs(c.x) > 0.3 else c)


def nav_pedestals(g):
    """Moulded pods carrying the nav housings down to the (now lower) gunwale."""
    for sx in (1, -1):
        p = P.nav_light_pos(sx)
        z0 = P.profile(p.y)[8][1] - 0.04          # from the rail top, over the sloped shoulder
        top = p.z - 0.07
        if top - z0 > 0.02:
            R.box(g, (p.x, p.y, (z0 + top) / 2), (0.18, 0.36, top - z0), M(g, "PWCOrangeDark"), bev=0.02 if g.hi else None)


def fittings(g):
    P.fittings(g)
    nav_pedestals(g)


def sponsons(g, mat):
    """Sponsons: wedge ledges off the chine on the aft quarters (the base's little boxes end up buried in the hull)."""
    n = 16 if g.hi else 8
    y0, y1 = 2.0, P.TRANSOM - 0.02
    for sx in (1, -1):
        rings = []
        for i in range(n + 1):
            y = y0 + (y1 - y0) * i / n
            e = smooth(y0, y0 + 1.0, y)
            pr = P.profile(y)
            (x3, z3), (x4, z4), (x5, z5) = pr[3], pr[4], pr[5]
            a = Vector((sx * (x3 - 0.04), y, z3 - 0.01))
            tip = Vector((sx * (x4 + 0.02 + 0.1 * e), y, z3 - 0.02 + 0.02 * e))
            c = Vector((sx * (x4 + 0.45 * (x5 - x4)), y, z4 + 0.45 * (z5 - z4)))
            rings.append([a, tip, c])
        g.rings(rings, M(g, mat), closed=True, cap0=True, cap1=True)


SEAT_C = 2.05                # shorter than the base's (starts 0.45 further aft), rider still on ATT_DriverSeat
SEAT_SECS = [(1.2, 0.64, 2.3), (2.02, 0.62, 2.28), (2.12, 0.64, 2.3), (2.16, 0.62, 2.28), (2.42, 0.6, 2.24),
             (2.45, 0.595, 2.235), (2.6, 0.5, 2.16), (2.68, 0.34, 2.02), (2.72, 0.12, 1.84)]


def make_seat(mats, top, p, sculpt=None, secs=SEAT_SECS, step=lambda y: 0.16 * smooth(1.8, 2.8, y), taper=0.8):
    """Narrow raised saddle: tapers to `taper` of its width at the nose (rider's knees), stepped by step(y)."""
    def seat(g):
        seg = 72 if g.hi else 48
        start = len(g.bm.verts)
        R.loft(g, [(0, SEAT_C, z, hx, hy) for z, hx, hy in secs], seg, M(g, top), cap0=False, cap1=True, p=p,
               matfn=(lambda i, j: mats[i]) if g.hi else None)
        R.deform(g, start, lambda c: Vector((c.x * (taper + (1 - taper) * smooth(-0.2, 1.3, c.y)), c.y,
                                             c.z + (step(c.y) if c.z > 2.2 else 0.0))))
        if sculpt:
            R.deform(g, start, sculpt)
    return seat


def build_style(style):
    """Builds LOD0 + _HP + _COL + markers for a style and returns the run.py spec."""
    NAME, TEX = style["name"], style["tex"]
    hull, trim = raked(P.hull), raked(style["trim"])
    hull_set = R.build_set("Hull", [(NAME + "_Hull_LOD0", hull), (NAME + "_HullSeat_LOD0", style["seat"]),
                                    (NAME + "_HullTrim_LOD0", trim)],
                           B.boosted_uv(style.get("uv_boost", {1: 1.25, 2: 1.4})), "MI_%s_Hull" % TEX)
    sled_set = R.build_set("Sled", [(NAME + "_Sled_LOD0", style["sled"]), (NAME + "_SledFittings_LOD0", style["fittings"]),
                                    (NAME + "_SledCockpit_LOD0", P.base_bars)], rbxkit.smart_uv, "MI_%s_Sled" % TEX)
    hps = [
        R.build_hp(NAME + "_Hull_HP", [hull] + [raked(f) for f in style.get("hull_hp", [])]),
        R.build_hp(NAME + "_HullSeat_HP", [style["seat"]]),
        R.build_hp(NAME + "_HullTrim_HP", [trim]),
        R.build_hp(NAME + "_Sled_HP", [style["sled"], style["sled_text"]], bevel=dict(width=0.012, segments=2, angle=40)),
        R.build_hp(NAME + "_SledFittings_HP", [style["fittings"]], bevel=dict(width=0.01, segments=2, angle=40)),
        R.build_hp(NAME + "_SledCockpit_HP", [P.base_bars, P.display_screen], bevel=dict(width=0.006, segments=2, angle=40)),
    ]
    if style.get("hull_sharp"):     # faceted hull: hard edges between the angular panels
        for o in hull_set[:1] + hps[:1]:
            o.data.set_sharp_from_angle(angle=math.radians(style["hull_sharp"]))
    col = B.collision()
    col.name = col.data.name = NAME + "_COL"
    atts = []
    for name, p in list(B.ATTACHMENTS.items()) + [("ATT_Float%d" % (i + 1), B.gb(x, -1.05, z)) for i, (x, z) in enumerate(B.FLOATS)]:
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    lod0 = hull_set + sled_set
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    own = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    assert (own - BASE_OFF).length < 0.02, "frame moved off the base jet ski: %s vs %s" % (own, BASE_OFF)
    off = BASE_OFF                  # the base frame exactly: markers identical to M_Veh_JetSki's
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    bbox = [h - l for l, h in zip(lo, hi)]
    print("[%s] offset %s bbox %s" % (NAME, tuple(round(c, 3) for c in off), [round(b, 3) for b in bbox]))

    meshes = [{"object": o, "set": "Hull"} for o in hull_set] + [{"object": o, "set": "Sled"} for o in sled_set]
    meshes += [{"object": h} for h in hps] + [{"object": col}]
    wet = {"wet": True, "wet_darken": 0.45, "wet_gloss": 0.2, "wet_streaks": 0.45, "cage_extrusion": 0.05,
           "max_ray_distance": 0.12}
    sets = [dict(wet, name=TEX, set="Hull", size=1024, wear=style["wear_hull"]),
            dict(wet, name=TEX, set="Sled", size=1024, wear=style["wear_sled"])]

    def at(p):
        return [round(c, 3) for c in Vector(p) + off]
    return {
        "name": NAME,
        "budget": "jetski",
        "tier": "hero",
        "dims_m": tuple(round(b / 3.0, 3) for b in bbox),
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "closeups": [dict(c, target=at(c["target"])) for c in style["closeups"]],
        "waivers": {
            "texel density": "ship maps are 1024 (Roblox downsamples to 1024 at run time); 2 sets (Hull, Sled) per the "
                             "jet ski frame, as the other premium vehicles.",
            "LOD UV layout": "LOD1 / LOD2 collapse decimation shifts the borders of small fitting, handle, bar and "
                             "trim UV islands; LOD1 is seen beyond 150 studs and LOD2 beyond 500, where the maps are "
                             "mip-mapped far below the island size (as M_Veh_JetSki).",
            "geometry": "LOD2: a few loose verts and slivers left by collapse decimation of thin bar / lanyard / trim "
                        "tubes (not rendered at LOD2 distance); LOD0 and LOD1 pass (as M_Veh_JetSki).",
        },
    }
