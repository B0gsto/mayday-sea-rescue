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
        nrm = _bump(nt, h, 0.55, nrm)
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


SEAT_SECS = [(1.46, 0.76, 2.52), (2.02, 0.74, 2.5), (2.12, 0.76, 2.52), (2.16, 0.74, 2.5), (2.42, 0.72, 2.46),
             (2.45, 0.715, 2.455), (2.6, 0.62, 2.36), (2.69, 0.44, 2.2), (2.72, 0.18, 2.0)]


def make_seat(mats, top, p, sculpt=None, secs=SEAT_SECS):
    def seat(g):
        seg = 72 if g.hi else 48
        start = len(g.bm.verts)
        R.loft(g, [(0, P.SEAT_C, z, hx, hy) for z, hx, hy in secs], seg, M(g, top), cap0=False, cap1=True, p=p,
               matfn=(lambda i, j: mats[i]) if g.hi else None)
        R.deform(g, start, lambda c: Vector((c.x, c.y, c.z + (0.16 * smooth(1.8, 2.8, c.y) if c.z > 2.2 else 0.0))))
        if sculpt:
            R.deform(g, start, sculpt)
    return seat


def build_style(style):
    """Builds LOD0 + _HP + _COL + markers for a style and returns the run.py spec."""
    NAME, TEX = style["name"], style["tex"]
    hull_set = R.build_set("Hull", [(NAME + "_Hull_LOD0", P.hull), (NAME + "_HullSeat_LOD0", style["seat"]),
                                    (NAME + "_HullTrim_LOD0", style["trim"])],
                           B.boosted_uv(style.get("uv_boost", {1: 1.25, 2: 1.4})), "MI_%s_Hull" % TEX)
    sled_set = R.build_set("Sled", [(NAME + "_Sled_LOD0", style["sled"]), (NAME + "_SledFittings_LOD0", style["fittings"]),
                                    (NAME + "_SledCockpit_LOD0", P.base_bars)], rbxkit.smart_uv, "MI_%s_Sled" % TEX)
    hps = [
        R.build_hp(NAME + "_Hull_HP", [P.hull] + style.get("hull_hp", [])),
        R.build_hp(NAME + "_HullSeat_HP", [style["seat"]]),
        R.build_hp(NAME + "_HullTrim_HP", [style["trim"]]),
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
    sets = [dict(wet, name=TEX, set="Hull", size=2048, wear=style["wear_hull"]),
            dict(wet, name=TEX, set="Sled", size=2048, wear=style["wear_sled"])]

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
            "LOD UV layout": "LOD1 / LOD2 collapse decimation shifts the borders of small fitting, handle, bar and "
                             "trim UV islands; LOD1 is seen beyond 150 studs and LOD2 beyond 500, where the maps are "
                             "mip-mapped far below the island size (as M_Veh_JetSki).",
            "geometry": "LOD2: a few loose verts and slivers left by collapse decimation of thin bar / lanyard / trim "
                        "tubes (not rendered at LOD2 distance); LOD0 and LOD1 pass (as M_Veh_JetSki).",
        },
    }
