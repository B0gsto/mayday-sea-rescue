"""Shared helpers for the premium Robux boats M_Veh_StormRunner (RIB frame) and M_Veh_Tidewalker (lifeboat frame).

Reuses the M_Veh_RIB generators (ribgeo.py: Geo, sweep, box, lathe, loft, materials, build_set / build_hp; build.py:
the outboards). Adds shader patterns on top of ribgeo PROC materials (baked through BAKE_BASE / BAKE_MR / the shading
normal, like _JetSkiPremium/premium.py): teak, quilt, pleat, forged, pearl. Axes as ribgeo: X beam (port +X), Y length
(bow -Y), Z up, 1 unit = 1 stud.
"""
import importlib.util
import math
import os
import sys

import bpy
from mathutils import Vector

VEH = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RIB = os.path.join(VEH, "M_Veh_RIB")
sys.path.insert(0, RIB)
import ribgeo as R  # noqa: E402
import rbxkit  # noqa: E402

# the RIB build by path (run.py may already hold a module called "build"): outboards, bolts, markers, floats
_spec = importlib.util.spec_from_file_location("rib_base_build", os.path.join(RIB, "build.py"))
RB = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(RB)


def M(g, name):
    return name if g.hi else "X"


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# =========================================================================== shader patterns
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
    """1 on lines every `period` studs along coordinate socket c (half width hw, soft edge); also the distance."""
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


def _dot(nt, co, axis):
    n = nt.nodes.new("ShaderNodeVectorMath")
    n.operation = "DOT_PRODUCT"
    nt.links.new(co, n.inputs[0])
    n.inputs[1].default_value = axis
    return n.outputs["Value"]


def pattern(name, kind, thread="#B8924E", groove="#A99070", plank=0.3, cell=0.5, axis="X"):
    """Adds a pattern on top of a PROC material (needs a ribgeo.PROC entry: BAKE_BASE colour, BAKE_MR roughness)."""
    mat = R.material(name)
    nt = mat.node_tree
    L = nt.links.new
    base, mr = nt.nodes["BAKE_BASE"], nt.nodes["BAKE_MR"]
    bsdf = nt.nodes["Principled BSDF"]
    col = base.inputs["Color"].links[0].from_socket
    rgh = mr.inputs["Y"].links[0].from_socket
    nrm = bsdf.inputs["Normal"].links[0].from_socket if bsdf.inputs["Normal"].links else None
    tc = nt.nodes.new("ShaderNodeTexCoord")
    co = tc.outputs["Object"]
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(co, sep.inputs[0])
    if kind == "teak":
        # planks `plank` studs wide along Y (caulk lines at constant `axis`), black caulking, per-plank tone, long grain
        c = sep.outputs[axis]
        caulk, _ = _line(nt, c, plank, 0.014)
        cx = nt.nodes.new("ShaderNodeCombineXYZ")
        fl = _math(nt, "FLOOR", _math(nt, "DIVIDE", c, plank))
        L(fl, cx.inputs["X"])
        L(_math(nt, "MULTIPLY", fl, 1.7), cx.inputs["Y"])
        tone = _noise(nt, cx.outputs[0], 1.3)
        col = _mixc(nt, col, "#6E4E33", _maprange(nt, tone, 0.35, 0.65, 0.0, 0.55))
        st = (14.0, 0.6, 14.0) if axis == "X" else (0.6, 14.0, 14.0)
        grain = _noise(nt, co, 3.0, 8.0, stretch=st)
        col = _mixc(nt, col, "#A9845E", _maprange(nt, grain, 0.45, 0.7, 0.0, 0.45))
        # butt joints every 2 m, staggered per plank
        bj = _math(nt, "ADD", sep.outputs["Y"], _math(nt, "MULTIPLY", fl, 2.3))
        butt, _ = _line(nt, bj, 6.0, 0.012)
        caulk = _math(nt, "MAXIMUM", caulk, butt)
        col = _mixc(nt, col, "#2B2622", caulk)
        rgh = _math(nt, "MULTIPLY_ADD", caulk, 0.15, rgh)
        h = _math(nt, "SUBTRACT", _math(nt, "MULTIPLY", grain, 0.15), caulk)
        nrm = _bump(nt, h, 0.5, nrm)
    elif kind in ("quilt", "pleat"):
        # quilt: diamond cells (45 deg in XY), lock-stitch dashes in the grooves, puffed cushions
        # pleat: horizontal channels every `cell` studs along Z (seat backs), stitched
        if kind == "quilt":
            u, v = _dot(nt, co, (0.7071, 0.7071, 0.0)), _dot(nt, co, (0.7071, -0.7071, 0.0))
        else:
            u, v = sep.outputs["Z"], None
        lu, du = _line(nt, u, cell, 0.018)
        tu, _ = _line(nt, u, cell, 0.009)
        along = v if v is not None else _math(nt, "ADD", sep.outputs["X"], sep.outputs["Y"])
        dash_u = _maprange(nt, _math(nt, "FRACT", _math(nt, "DIVIDE", along, 0.07)), 0.5, 0.6, 1.0, 0.0)
        thread_f = _math(nt, "MULTIPLY", tu, dash_u)
        groove_f = lu
        dmin = du
        if v is not None:
            lv, dv = _line(nt, v, cell, 0.018)
            tv, _ = _line(nt, v, cell, 0.009)
            dash_v = _maprange(nt, _math(nt, "FRACT", _math(nt, "DIVIDE", u, 0.07)), 0.5, 0.6, 1.0, 0.0)
            thread_f = _math(nt, "MAXIMUM", thread_f, _math(nt, "MULTIPLY", tv, dash_v))
            groove_f = _math(nt, "MAXIMUM", lu, lv)
            dmin = _math(nt, "MINIMUM", du, dv)
        # quilting only on up-facing cushion tops, pleats only on upright backs (else the pattern smears along walls)
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        gs = nt.nodes.new("ShaderNodeSeparateXYZ")
        L(geo.outputs["Normal"], gs.inputs[0])
        nz = _math(nt, "ABSOLUTE", gs.outputs["Z"])
        mask = _maprange(nt, nz, 0.6, 0.85) if kind == "quilt" else _maprange(nt, nz, 0.5, 0.25)
        groove_f = _math(nt, "MULTIPLY", groove_f, mask)
        thread_f = _math(nt, "MULTIPLY", thread_f, mask)
        dmin = _math(nt, "ADD", _math(nt, "MULTIPLY", dmin, mask), _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", 1.0, mask), cell * 0.32))
        col = _mixc(nt, col, groove, _math(nt, "MULTIPLY", groove_f, 0.6))
        col = _mixc(nt, col, thread, thread_f)
        rgh = _math(nt, "MULTIPLY_ADD", thread_f, -0.1, rgh)
        puff = _maprange(nt, dmin, 0.0, cell * 0.32)
        h = _math(nt, "ADD", _math(nt, "POWER", puff, 0.5), _math(nt, "MULTIPLY", thread_f, 0.35))
        nrm = _bump(nt, h, 0.55, nrm)
    elif kind == "forged":
        a = _maprange(nt, _noise(nt, co, 20.0, 1.0), 0.49, 0.52)
        sh = nt.nodes.new("ShaderNodeVectorMath")
        sh.operation = "ADD"
        L(co, sh.inputs[0])
        sh.inputs[1].default_value = (3.1, -3.1, 1.55)
        b = _maprange(nt, _noise(nt, sh.outputs[0], 38.0, 1.0), 0.50, 0.53)
        col = _mixc(nt, col, "#3A3F45", _math(nt, "MULTIPLY", a, 0.55))
        col = _mixc(nt, col, "#1A1C1F", _math(nt, "MULTIPLY", b, 0.5))
        rgh = _math(nt, "MULTIPLY_ADD", a, -0.06, rgh)
    elif kind == "pearl":
        p = _noise(nt, co, 0.35, 1.0)
        col = _mixc(nt, col, "#E9DFD6", _maprange(nt, p, 0.4, 0.65, 0.0, 0.5))
        col = _mixc(nt, col, "#DDE1E0", _maprange(nt, p, 0.35, 0.15, 0.0, 0.45))
    base.inputs["Color"].default_value = (1, 1, 1, 1)
    L(col, base.inputs["Color"])
    L(rgh, mr.inputs["Y"])
    if nrm is not None:
        L(nrm, bsdf.inputs["Normal"])


# =========================================================================== geometry helpers
def ring_loft(g, rings, mat, matfn=None, closed=False, cap0=False, cap1=False, out=None):
    """g.rings + orientation away from `out(centre)` (default: away from the ring's own axis)."""
    fs = g.rings([[Vector(p) for p in r] for r in rings], mat, closed=closed, cap0=cap0, cap1=cap1, matfn=matfn,
                 recalc=out is None)
    if out is not None:
        g.orient(fs, out)
    return fs


def patch(g, fn, nu, nv, mat, out):
    """Surface patch: fn(a, b) -> Vector for a, b in 0..1; faces turned toward out(centre)."""
    rows = [[fn(i / nu, j / nv) for j in range(nv + 1)] for i in range(nu + 1)]
    fs = g.rings(rows, mat, closed=False, recalc=False)
    g.orient(fs, out)
    return fs


def text_on(g, body, size, mapfn, mat, out, scale_x=1.0, shear=0.0):
    """Flat text mesh (centred, X along the line, Y up) mapped through mapfn(u, v) -> Vector."""
    me = R.text_mesh(body, size, font_scale_x=scale_x)
    fs = g.add_mesh(me, mat, lambda co: mapfn(co.x + shear * co.y, co.y))
    g.orient(fs, out)
    bpy.data.meshes.remove(me)
    return fs


def aerofoil(chord, thick, n=10):
    """Closed symmetric aerofoil (side = chord axis, up = thickness), leading edge at -chord / 2."""
    pts = []
    for k in range(n):
        t = math.pi * k / (n - 1)
        x = 0.5 * (1 - math.cos(t))
        y = 5 * thick * (0.2969 * math.sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x ** 3 - 0.1036 * x ** 4)
        pts.append((chord * (x - 0.5), y))
    return pts + [(x, -y) for x, y in reversed(pts[1:-1])]


def wheel(g, centre, axis, r, tube_r, mat_rim, mat_spoke, mat_hub, seg=24):
    """Sport steering wheel: rim torus, three spokes, hub, round axis `axis`."""
    ax = Vector(axis).normalized()
    ref = Vector((1, 0, 0)) if abs(ax.x) < 0.9 else Vector((0, 1, 0))
    u = ax.cross(ref).normalized()
    w = ax.cross(u).normalized()
    c = Vector(centre)
    rim = [c + (u * math.cos(2 * math.pi * k / seg) + w * math.sin(2 * math.pi * k / seg)) * r for k in range(seg)]
    R.sweep(g, rim + [rim[0]], R.circle_profile(tube_r, 14 if g.hi else 10), mat_rim)
    for k in range(3):
        a = math.pi / 2 + 2 * math.pi * k / 3
        d = u * math.cos(a) + w * math.sin(a)
        R.sweep(g, [c + d * 0.08, c + d * (r - tube_r * 0.6)], [(-0.06, -0.018), (0.06, -0.018), (0.06, 0.018),
                                                                (-0.06, 0.018)], mat_spoke, cap0=True, cap1=True)
    R.lathe(g, tuple(c - ax * 0.05), tuple(ax), [(0.0, 0.0), (0.13, 0.0), (0.14, 0.06), (0.1, 0.12), (0.0, 0.13)],
            28 if g.hi else 18, mat_hub)


def empties(atts):
    out = []
    for name, p in atts.items():
        e = bpy.data.objects.new(name, None)
        e.location = Vector(p)
        bpy.context.scene.collection.objects.link(e)
        out.append(e)
    return out


def convex_col(name, pts):
    import bmesh
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = [v for v in set(res.get("geom_interior", []) + res.get("geom_unused", [])) if isinstance(v, bmesh.types.BMVert)]
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tight_uv(ob, angle=55, margin=0.004):
    """smart_uv with tighter island margins (rbxkit packs at 0.01, which leaves big boats under the texel tier)."""
    rbxkit.select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.002, correct_aspect=True)
    bpy.ops.uv.pack_islands(margin=0.003, rotate=True, shape_method="CONCAVE")
    bpy.ops.object.mode_set(mode="OBJECT")


def basis(n):
    n = Vector(n).normalized()
    ref = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
    u = n.cross(ref).normalized()
    return u, n.cross(u).normalized(), n


def gauge(g, p, n, r, face="GaugeFace", bezel="Chrome", ticks="LetterWhite"):
    """Round gauge on a panel: chrome bezel, black face; _HP adds 11 printed ticks, a needle and a centre cap."""
    u, w, n = basis(n)
    p = Vector(p)
    R.lathe(g, tuple(p), tuple(n), [(r * 0.86, 0.0), (r, 0.0), (r, 0.035), (r * 0.92, 0.05), (r * 0.86, 0.03)],
            24 if g.hi else 14, M(g, bezel))
    R.lathe(g, tuple(p), tuple(n), [(0.0, 0.012), (r * 0.87, 0.012)], 24 if g.hi else 14, M(g, face))
    if not g.hi:
        return
    for k in range(11):
        a = math.radians(225 - 27 * k)
        d = u * math.cos(a) + w * math.sin(a)
        c = p + d * r * 0.7 + n * 0.016
        rot = __import__("mathutils").Matrix((d, d.cross(n).normalized(), n)).transposed()
        R.box(g, tuple(c), (r * (0.18 if k % 5 == 0 else 0.11), r * 0.035, 0.004), ticks, rot=rot, bev=0.0)
    a = math.radians(150)
    d = u * math.cos(a) + w * math.sin(a)
    rot = __import__("mathutils").Matrix((d, d.cross(n).normalized(), n)).transposed()
    R.box(g, tuple(p + d * r * 0.3 + n * 0.02), (r * 0.62, r * 0.04, 0.004), "LensWhite", rot=rot, bev=0.0)
    R.lathe(g, tuple(p + n * 0.02), tuple(n), [(0.0, 0.0), (r * 0.1, 0.0), (r * 0.08, 0.012), (0.0, 0.014)], 10, bezel)


def prop_blades(g, centre, axis=(0, 1, 0), n=4, r0=0.1, r1=0.47, chord=0.17, pitch=0.75, skew=0.5, mat="Stainless"):
    """Thin cupped propeller blades with real thickness (reads as a prop, not a disc, from astern)."""
    c0 = Vector(centre)
    u, w, ax = basis(axis)
    nk = 9 if g.hi else 5
    for b in range(n):
        a0 = 2 * math.pi * b / n
        rows = []
        for k in range(nk + 1):
            t = k / nk
            rr = r0 + (r1 - r0) * t
            ang = a0 + skew * t * t
            ch = chord * math.sin(math.pi * (0.18 + 0.72 * t)) * (1.0 - 0.25 * t)
            th = 0.022 * (1 - 0.7 * t)
            radial = u * math.cos(ang) + w * math.sin(ang)
            tang = ax.cross(radial).normalized()
            c = c0 + radial * rr
            d = (tang * math.cos(pitch) + ax * math.sin(pitch)) * ch
            nrm = d.cross(radial).normalized() * th
            rows.append([c - d, c + nrm, c + d * 1.0, c - nrm])
        g.rings(rows, M(g, mat), closed=True, cap0=False, cap1=True)


def cushion(g, c, size, mat, pipe=None, p=6.0):
    """Rounded upholstered cushion (squarish superellipse loft, domed top) with optional piping round the top edge."""
    x, y, z = c
    hx, hy, h = size[0] / 2, size[1] / 2, size[2]
    z0 = z - h / 2
    r = min(0.14, h * 0.4, hx * 0.5, hy * 0.5)
    seg = 32 if g.hi else 16
    secs = [(x, y, z0, hx - r * 0.4, hy - r * 0.4), (x, y, z0 + r * 0.4, hx, hy), (x, y, z0 + h - r, hx, hy),
            (x, y, z0 + h - r * 0.3, hx - r * 0.45, hy - r * 0.45), (x, y, z0 + h, hx - r, hy - r)]
    R.loft(g, secs, seg, M(g, mat), cap0=True, cap1=True, p=p)
    if pipe:
        ring = R.superellipse_ring(x, y, z0 + h - r * 0.62, hx + 0.005, hy + 0.005, seg, p)
        R.sweep(g, ring + [ring[0]], R.circle_profile(0.028, 8 if g.hi else 5), M(g, pipe))
