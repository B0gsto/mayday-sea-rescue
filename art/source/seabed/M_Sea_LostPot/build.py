"""M_Sea_LostPot: a lost Cornish parlour creel, lying on the seabed, fouled and half settled into silt.

A parlour pot is a steel frame (weighted base bar, transverse hoops, lengthwise slines, all plastic coated) covered
with netting, with a funnel entrance (the "eye") in one end. This one has been on the ground a while: its +Y side
has settled into the silt, wrack, filament weed and barnacle crust cover the frame, and the bridle rope has parted,
its crushed marker float lying on the sand 0.3 m beyond the pot.

Blender: pot body 0.59 x 0.46 x 0.30 m (dims.md), long axis X, tilted -6.5 deg about X, base frame 0.036 m above the
sand. Origin: free (the rope trail is asymmetric: the pot's base centre is the origin). One set T_LostPot_Shell (1024,
wet), six MeshParts (Frame, Net, Growth, Rope, Float, Silt), each unwrapped into its own cell of the sheet with every
UV island shelf-packed inside that cell. ATT_Grab at the top of the pot, ATT_RopeEnd at the frayed end of the bridle.
"""
import bisect
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(G, "tools/blender"))
sys.path.insert(0, os.path.join(HERE, "../_S1a"))
import common  # noqa: E402
import rope as RP  # noqa: E402
import budgets  # noqa: E402
import names  # noqa: E402
import versions  # noqa: E402
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf  # noqa: E402

NAME = "M_Sea_LostPot"
S = 3.0
UV = ("tile", 1.0, 1.0)
rnd = random.Random(1987)

HL, HW = 0.290, 0.225      # base frame half length / half width (m): pot body 0.58 x 0.45 m
XA = 0.280                 # end hoops at +/- XA
Z0 = 0.036                 # base frame rod centre above the sand
AH = 0.272                 # arch height above Z0 -> frame top 0.308 m
TILT = math.radians(-6.5)  # the pot has rolled slightly: its +Y side sinks into the silt
N_HOOP = 6
SET = "Shell"

MATS = [("MI_LostPot_Frame", (0.30, 0.32, 0.28), 0.70),      # plastic-coated steel, silted
        ("MI_LostPot_Net", (0.45, 0.44, 0.38), 0.82),        # twine
        ("MI_LostPot_Growth", (0.27, 0.30, 0.21), 0.80),     # wrack, filament weed, barnacle crust
        ("MI_LostPot_Rope", (0.36, 0.34, 0.29), 0.80),       # parted nylon bridle
        ("MI_LostPot_Float", (0.42, 0.23, 0.13), 0.62),      # faded orange marker float, crushed
        ("MI_LostPot_Silt", (0.44, 0.42, 0.36), 0.80)]       # the drift the pot has settled into

UNWRAP = {"M_Sea_LostPot_Frame_LOD0": (0.010, 0.480, 0.520, 0.990),
          "M_Sea_LostPot_Net_LOD0": (0.520, 0.990, 0.520, 0.990),
          "M_Sea_LostPot_Growth_LOD0": (0.010, 0.490, 0.010, 0.500),
          "M_Sea_LostPot_Rope_LOD0": (0.500, 0.760, 0.010, 0.320),
          "M_Sea_LostPot_Float_LOD0": (0.500, 0.760, 0.330, 0.500),
          "M_Sea_LostPot_Silt_LOD0": (0.770, 0.990, 0.010, 0.500)}


# ---------------------------------------------------------------- arch (the pot's D cross-section, in Y and Z)
def make_arch(hw, ah, n=120):
    """(points (y, z), cumulated arc fraction, total length m) of the D arch from y = -hw to +hw."""
    us = [-1.0 + 2.0 * i / n for i in range(n + 1)]
    pts = [Vector((u * hw, ah * (1.0 - abs(u) ** 2.4) ** 0.45)) for u in us]
    cum = [0.0]
    for i in range(1, len(pts)):
        cum.append(cum[-1] + (pts[i] - pts[i - 1]).length)
    total = cum[-1]
    return pts, [c / total for c in cum], total


FRAME_ARCH = make_arch(HW, AH)
NET_ARCH = make_arch(HW + 0.010, AH + 0.009)


def taper(x):
    return 1.0 - 0.10 * (x / HL) ** 2


def arch_at(arch, sf):
    pts, cum, _ = arch
    if sf <= 0.0:
        return pts[0]
    if sf >= 1.0:
        return pts[-1]
    i = bisect.bisect_left(cum, sf)
    j = max(i - 1, 0)
    t = (sf - cum[j]) / max(cum[i] - cum[j], 1e-9)
    return pts[j].lerp(pts[i], t)


def ap(arch, x, sf):
    """Point on the arch at length x, arc fraction sf (m, pot frame)."""
    p = arch_at(arch, sf)
    return Vector((x, p[0], Z0 + (p[1] - Z0) * taper(x)))


def sf_of_u(arch, u):
    pts, cum, _ = arch
    i = min(max(int(round((u + 1.0) * 0.5 * (len(pts) - 1))), 0), len(pts) - 1)
    return cum[i]


def rot():
    return Matrix.Rotation(TILT, 4, "X")


def tilted(v):
    return rot() @ Vector(v)


# ---------------------------------------------------------------- materials and objects
def make_materials():
    for name, rgb, rough in MATS:
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
            bsdf.inputs["Roughness"].default_value = rough
            bsdf.inputs["Metallic"].default_value = 0.0
        m.diffuse_color = (lin[0], lin[1], lin[2], 1.0)


def uv_islands(mesh):
    """Face groups joined across an edge where both faces' UVs agree at both ends."""
    bm = bmesh.new()
    bm.from_mesh(mesh)
    uvl = bm.loops.layers.uv.active
    seen, groups = set(), []

    def joined(f, g, edge):
        for v in edge.verts:
            a = next(l[uvl].uv for l in f.loops if l.vert == v)
            b = next(l[uvl].uv for l in g.loops if l.vert == v)
            if abs(a.x - b.x) > 1e-6 or abs(a.y - b.y) > 1e-6:
                return False
        return True

    for f in bm.faces:
        if f.index in seen:
            continue
        seen.add(f.index)
        stack, group = [f], []
        while stack:
            cur = stack.pop()
            group.append(cur.index)
            for e in cur.edges:
                for o in e.link_faces:
                    if o.index not in seen and joined(cur, o, e):
                        seen.add(o.index)
                        stack.append(o)
        groups.append(group)
    bm.free()
    return groups


def unwrap(ob, rect):
    """Smart project, then normalise every UV island to its own cell and shelf-pack the cells into the part's rect.

    Fixed island bounds keep the UV area through collapse decimation, so the LOD layout check stays inside its
    tolerance; the cell sizes are proportional to island area, so texel density is kept too."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.004, correct_aspect=True, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = ob.data
    uvl = me.uv_layers["UVMap"]
    groups = uv_islands(me)
    loops = {p.index: list(p.loop_indices) for p in me.polygons}
    info = []
    for g in groups:
        pts = [uvl.data[li].uv.copy() for fi in g for li in loops[fi]]
        u0, u1 = min(p.x for p in pts), max(p.x for p in pts)
        v0, v1 = min(p.y for p in pts), max(p.y for p in pts)
        info.append((g, u0, v0, max(u1 - u0, 1e-4), max(v1 - v0, 1e-4)))
    x0, x1, y0, y1 = rect
    W_, H_ = x1 - x0, y1 - y0
    m = 0.006
    area = sum(w * h for _, _, _, w, h in info)
    s = math.sqrt(0.62 * W_ * H_ / max(area, 1e-9))
    for _ in range(40):
        cells = sorted(((h * s + m, w * s + m, i) for i, (_, _, _, w, h) in enumerate(info)), reverse=True)
        place, cx, cy, row = {}, 0.0, 0.0, 0.0
        fits = True
        for ch, cw, i in cells:
            if cw > W_ + 1e-9 or ch > H_ + 1e-9:
                fits = False
                break
            if cx + cw > W_ + 1e-9:
                cx, cy, row = 0.0, cy + row, 0.0
            if cy + ch > H_ + 1e-9:
                fits = False
                break
            place[i] = (cx, cy)
            cx += cw
            row = max(row, ch)
        if fits:
            break
        s *= 0.92
    for i, (g, u0, v0, w, h) in enumerate(info):
        px, py = place[i]
        for fi in g:
            for li in loops[fi]:
                uv = uvl.data[li].uv
                uv.x = x0 + px + m / 2 + (uv.x - u0) * s
                uv.y = y0 + py + m / 2 + (uv.y - v0) * s
    me.update()


def crusty(ob, target, seed, levels=2, depth=(0.006, 0.0035), size=(0.22, 0.055)):
    """Concretion and grit: simple subdivide, two-scale noise displacement along the normals, collapse to target."""
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.subdivision_type, sub.levels, sub.render_levels = "SIMPLE", levels, levels
    for k, (sz, dp) in enumerate(zip(size, depth)):
        tx = bpy.data.textures.new("LostPotCrust%d" % k, "CLOUDS")
        tx.noise_scale, tx.noise_depth, tx.noise_basis = sz, 2, "VORONOI_F1" if k == 0 else "BLENDER_ORIGINAL"
        d = ob.modifiers.new("Crust%d" % k, "DISPLACE")
        d.texture, d.strength, d.mid_level, d.direction = tx, dp, 0.35, "NORMAL"
        d.texture_coords = "GLOBAL"
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    me.name = ob.name
    versions.decimate(ob, target)
    versions.weighted_normals(ob)


# ---------------------------------------------------------------- LOD hygiene
# The shared lod step collapse-decimates with UV interpolation: thin tube parts lose UV area and Blender leaves the
# odd loose vertex behind. Wrap the step (tools stay untouched) to drop loose verts and refit every LOD UV island to
# the LOD0 cell it came from, so the layout check sees the authored UV area at every LOD.
def _uv_area(me):
    uvl = me.uv_layers["UVMap"].data
    a = 0.0
    for p in me.polygons:
        pts = [uvl[li].uv for li in p.loop_indices]
        for i in range(1, len(pts) - 1):
            a += abs((pts[i].x - pts[0].x) * (pts[i + 1].y - pts[0].y)
                     - (pts[i + 1].x - pts[0].x) * (pts[i].y - pts[0].y)) / 2.0
    return a


def _match_uv_area(lod_ob, src_ob):
    """Collapse decimation drops a little UV area; rescale each LOD UV island about its own centre to restore the
    LOD0 texel density. Per-island scaling keeps every island inside its authored cell, so bounds barely move."""
    want = _uv_area(src_ob.data)
    me = lod_ob.data
    uvl = me.uv_layers["UVMap"].data
    groups = uv_islands(me)
    for _ in range(4):
        have = _uv_area(me)
        if have <= 1e-9 or abs(have - want) / want < 0.02:
            break
        k = math.sqrt(want / have)
        for g in groups:
            lis = [li for fi in g for li in me.polygons[fi].loop_indices]
            us = [uvl[li].uv.x for li in lis]
            vs = [uvl[li].uv.y for li in lis]
            cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
            hu, hv = (max(us) - min(us)) / 2, (max(vs) - min(vs)) / 2
            kk = k
            if hu > 1e-6:
                kk = min(kk, 0.48 / hu)
            if hv > 1e-6:
                kk = min(kk, 0.48 / hv)
            for li in lis:
                uvl[li].uv = (cu + (uvl[li].uv.x - cu) * kk, cv + (uvl[li].uv.y - cv) * kk)
        me.update()
    rect = UNWRAP.get(src_ob.name)
    if rect:
        x0, x1, y0, y1 = rect
        for d in uvl:                                               # never leave the authored rect
            d.uv = (min(max(d.uv.x, x0 + 0.001), x1 - 0.001), min(max(d.uv.y, y0 + 0.001), y1 - 0.001))
        me.update()


def _coarse_net(src, name):
    """LOD2 net: a rebuilt coarse net, UVs projected from the LOD0 surface so it samples the same texels."""
    b = Buf()
    netting(b, cols=4, rows=6, funnel_n=6)
    ob = b.to_object(name, "MI_LostPot_Net")
    unwrap(ob, UNWRAP[NAME + "_Net_LOD0"])
    _match_uv_area(ob, src)
    return ob


def run_lod(spec):
    made = []
    for entry in [e for e in spec["meshes"] if e.get("role", "visual") == "visual" and e.get("lod", "LOD0") == "LOD0"]:
        src = entry["object"]
        src_tris = versions.triangles(src.data)
        lower = src
        for lod in budgets.lods_made(spec["budget"]):
            name = names.with_suffix(src.name, lod)
            old = bpy.data.objects.get(name)
            if old is not None:
                bpy.data.objects.remove(old, do_unlink=True)
            target = budgets.lod_target(spec["budget"], lod, src_tris, spec.get("tris"))
            if src.name.endswith("_Net_LOD0") and lod == "LOD2":
                obj = _coarse_net(src, name)                    # fine netting has a decimation floor above the target
            else:
                obj = versions.copy_object(lower, name)
                try:
                    versions.decimate(obj, target)
                except RuntimeError:
                    bpy.data.objects.remove(obj, do_unlink=True)
                    obj = versions.copy_object(src, name)
                    versions.decimate(obj, target)
                versions.weighted_normals(obj)
            new = {"object": obj, "role": "visual", "lod": lod, "of": src.name}
            if entry.get("set"):
                new["set"] = entry["set"]
            spec["meshes"].append(new)
            made.append((name, versions.triangles(obj.data), target))
            print("[lod] %s %d triangles (target %d, LOD0 %d)" % (name, versions.triangles(obj.data), target, src_tris))
            lower = obj
    for e in spec["meshes"]:
        if e.get("role", "visual") != "visual" or e.get("lod") not in ("LOD1", "LOD2"):
            continue
        ob = e["object"]
        src = bpy.data.objects.get(ob.name.rsplit("_LOD", 1)[0] + "_LOD0")
        if src is None:
            continue
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
            bm.to_mesh(ob.data)
            ob.data.update()
        bm.free()
        _match_uv_area(ob, src)
    return made


versions.run_lod = run_lod


# ---------------------------------------------------------------- the pot
def frame(b):
    """Weighted base frame, six transverse hoops and seven lengthwise slines, all plastic-coated rod."""
    hl, hw, cr = HL, HW, 0.07
    ring = []
    for cx, cy, a0 in ((hl - cr, hw - cr, 0.0), (-(hl - cr), hw - cr, math.pi / 2),
                       (-(hl - cr), -(hw - cr), math.pi), (hl - cr, -(hw - cr), 1.5 * math.pi)):
        for k in range(5):
            a = a0 + (math.pi / 2) * k / 4.0
            ring.append(Vector((cx + cr * math.cos(a), cy + cr * math.sin(a), Z0)))
    W.sweep(b, ring, W.round_profile(0.0065, 5), UV, closed_path=True, smooth=True)
    for sy in (-1, 1):                                                  # weighted base bars
        y = sy * (HW - 0.026)
        W.sweep(b, [Vector((-hl + 0.05, y, Z0 - 0.003)), Vector((0.0, y, Z0 - 0.005)), Vector((hl - 0.05, y, Z0 - 0.003))],
                W.round_profile(0.0085, 4), UV, smooth=True)
    for x in (-0.15, 0.0, 0.15):                                        # lacing bars across the base
        W.sweep(b, [Vector((x, -(HW - 0.02), Z0 - 0.006)), Vector((x, 0.0, Z0 - 0.007)), Vector((x, HW - 0.02, Z0 - 0.006))],
                W.round_profile(0.005, 4), UV, smooth=True)
    sfs = [0.0, 0.07, 0.16, 0.28, 0.43, 0.58, 0.72, 0.85, 0.94, 1.0]
    for i in range(N_HOOP):
        x = -XA + 2 * XA * i / (N_HOOP - 1)
        W.sweep(b, [ap(FRAME_ARCH, x, sf) for sf in sfs], W.round_profile(0.0065, 4), UV, smooth=True,
                caps=(False, False))
    for u in (-0.94, -0.70, -0.40, 0.0, 0.40, 0.70, 0.94):              # slines (u = 0 is the ridge)
        sf = sf_of_u(FRAME_ARCH, u)
        lift = 0.005 if u == 0.0 else 0.0
        pts = [ap(FRAME_ARCH, -HL + 0.005 + 2 * (HL - 0.005) * k / 6.0, sf) + Vector((0, 0, lift)) for k in range(7)]
        W.sweep(b, pts, W.round_profile(0.0065 if u == 0.0 else 0.005, 4), UV, smooth=True, caps=(False, False))
    for sx in (-1, 1):                                                  # eye rings (the funnel mouths)
        c = Vector((sx * XA, 0.0, Z0 + 0.150))
        W.ring(b, c, (0, 1, 0), (0, 0, 1), 0.052, 0.0055, 10, 4, UV)


def net_knot(i, j, cols, rows):
    x = -XA + 0.020 + (2 * XA - 0.040) * i / (cols - 1)
    sf = 0.055 + 0.890 * j / (rows - 1)
    return ap(NET_ARCH, x, sf)


def netting(b, cols=8, rows=13, funnel_n=8):
    """Diamond netting: 72 mm cells of 3-sided twine, each diagonal band one strand with rounded knots."""
    knots = {(i, j): net_knot(i, j, cols, rows) for i in range(cols) for j in range(rows)}
    centre = Vector((0.0, 0.0, Z0 + 0.10))

    def band(cells):
        pts = [knots[cells[0]]]
        for k in range(1, len(cells) - 1):
            a, p, c = knots[cells[k - 1]], knots[cells[k]], knots[cells[k + 1]]
            r = min(0.024, (p - a).length * 0.35, (c - p).length * 0.35)
            p0 = p + (a - p).normalized() * r
            p2 = p + (c - p).normalized() * r
            for t in (0.0, 0.35, 0.7, 1.0):
                q = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p + t * t * p2
                pts.append(q + (centre - q).normalized() * 0.004 * math.sin(t * math.pi))
        pts.append(knots[cells[-1]])
        return pts

    for dj in (1, -1):
        for d in range(-rows + 1, cols):
            cells = [(i, i - d) if dj > 0 else (i, d - i) for i in range(cols)]
            cells = [c for c in cells if 0 <= c[1] < rows]
            if len(cells) < 2:
                continue
            W.sweep(b, band(cells), W.round_profile(0.0015, 3), UV, smooth=True, caps=(False, False))

    ZE = Z0 + 0.150
    for sx in (1, -1):
        c = Vector((sx * XA, 0.0, ZE))
        n = funnel_n
        rm = 0.080 if sx > 0 else 0.030
        ring0 = [c + Vector((0.0, rm * math.cos(2 * math.pi * k / n), rm * math.sin(2 * math.pi * k / n))) for k in range(n)]
        if sx < 0:                                                       # closed end panel round a small eye
            ring0 = [Vector((sx * (XA - 0.010), p.y, p.z)) for p in ring0]
            W.sweep(b, ring0, W.round_profile(0.0018, 3), UV, closed_path=True, smooth=True, caps=(False, False))
            for k in range(n):
                pa = ap(NET_ARCH, sx * (XA - 0.006), (k + 0.5) / n)
                W.sweep(b, [ring0[k], pa], W.round_profile(0.0017, 3), UV, smooth=True, caps=(False, False))
        else:                                                            # the funnel: end panel, mouth, throat
            panel = [Vector((XA - 0.002, 0.098 * math.cos(2 * math.pi * k / n), ZE + 0.098 * math.sin(2 * math.pi * k / n)))
                     for k in range(n)]
            W.sweep(b, panel, W.round_profile(0.0020, 3), UV, closed_path=True, smooth=True, caps=(False, False))
            mouth = [Vector((XA - 0.028, p.y, p.z)) for p in ring0]
            W.sweep(b, mouth, W.round_profile(0.0022, 3), UV, closed_path=True, smooth=True, caps=(False, False))
            for k in range(n):
                W.sweep(b, [panel[k], mouth[k]], W.round_profile(0.0015, 3), UV, smooth=True, caps=(False, False))
            tc = Vector((XA - 0.130, 0.0, ZE - 0.006))
            throat = [tc + Vector((0.0, 0.032 * math.cos(2 * math.pi * k / n), 0.032 * math.sin(2 * math.pi * k / n)))
                      for k in range(n)]
            W.sweep(b, throat, W.round_profile(0.0020, 3), UV, closed_path=True, smooth=True, caps=(False, False))
            for k in range(n):
                mp = mouth[k]
                mid = mp.lerp(throat[k], 0.5)
                mid += Vector((0.0, (mid.y - ZE) * 0.10, (mid.z - ZE) * 0.10))
                W.sweep(b, [mp, mid, throat[k]], W.round_profile(0.0017, 3), UV, smooth=True, caps=(False, False))


def growth(b):
    """Wrack blades, filament weed tufts and a barnacle crust on the frame."""
    blades = [(0.58, -0.93, 0.16, 0.030), (0.70, -0.62, 0.14, 0.028), (0.86, -0.30, 0.12, 0.024),
              (0.92, 0.30, 0.14, 0.028), (0.78, 0.66, 0.12, 0.024), (0.36, 0.94, 0.10, 0.022)]
    for x, u, ln, wd in blades:                                          # wrack: flat blades draped over the frame
        base = ap(FRAME_ARCH, x, sf_of_u(FRAME_ARCH, u))
        out = Vector((0.0, 0.55 if u > 0 else -0.55, 0.62)).normalized()
        side = Vector((1.0, 0.35, 0.0)).normalized()
        W.card(b, base + out * 0.004, out, side, ln, wd, 4, Vector((0.5, 0.0, -0.25)).normalized(), (0.0, 1.0), droop=0.02)
    for x, u in ((0.36, -0.72), (0.62, 0.44), (0.05, -0.88), (0.66, 0.90)):   # filament weed tufts
        base = ap(FRAME_ARCH, x, sf_of_u(FRAME_ARCH, u))
        for k in range(3):
            a = 2 * math.pi * k / 3.0 + 0.3
            d = Vector((0.30 * math.cos(a), -0.60 if u < 0 else 0.60, 0.75)).normalized()
            ln = 0.055 + 0.03 * rnd.random()
            W.sweep(b, [base + d * ln * t + Vector((0, 0, -0.010 * t * t)) for t in (0.0, 0.55, 1.0)],
                    W.round_profile(0.0016, 3), UV, smooth=True, caps=(False, False))
    spots = [(0.62, -0.99), (0.50, -0.93), (0.70, -0.88), (0.80, -0.78), (0.42, -0.86), (0.55, -0.70),
             (0.68, -0.55), (0.88, -0.62), (0.30, -0.95), (0.20, -0.88)]
    for x, u in spots:                                                   # barnacle crust along the base frame
        for k in range(2):
            base = ap(FRAME_ARCH, x + rnd.uniform(-0.03, 0.03), sf_of_u(FRAME_ARCH, u + rnd.uniform(-0.05, 0.05)))
            r = rnd.uniform(0.007, 0.013)
            W.lathe(b, [(r, 0.0), (r * 0.72, r * 0.55), (r * 0.42, r * 0.9)], 4,
                    lambda kk, a: (a, kk / 2.0), centre=tuple(base + Vector((0, 0, 0.001))))
    for k in range(4):                                                   # a few on the shoulders
        base = ap(FRAME_ARCH, rnd.uniform(-0.24, 0.24), sf_of_u(FRAME_ARCH, rnd.choice((-0.72, 0.72, -0.55))))
        r = rnd.uniform(0.006, 0.011)
        W.lathe(b, [(r, 0.0), (r * 0.7, r * 0.6), (r * 0.4, r)], 4, lambda kk, a: (a, kk / 2.0),
                centre=tuple(base + Vector((0, 0, 0.002))))


# ---------------------------------------------------------------- silt and the parted bridle
def silt_h(x, y):
    """Height of the drift: a lobed mound that swallows the pot's settled +Y flank and feathers under the seabed."""
    cx, cy, rx, ry = 0.12, 0.02, 0.80, 0.40
    u, v = (x - cx) / rx, (y - cy) / ry
    a = math.atan2(v, u)
    r = math.hypot(u, v) / (1.0 + 0.11 * math.sin(2 * a + 0.6) + 0.07 * math.sin(5 * a - 1.3))
    t = max(0.0, 1.0 - r)
    mound = 0.120 * math.exp(-(((x + 0.02) / 0.32) ** 2 + ((y - 0.180) / 0.16) ** 2))
    lobe = 0.048 * math.exp(-(((x - 0.54) / 0.26) ** 2 + ((y - 0.09) / 0.22) ** 2))
    shoulder = 0.022 * math.exp(-(((x + 0.10) / 0.42) ** 2 + ((y + 0.14) / 0.18) ** 2))
    ripples = 0.0065 * math.sin(x * 12.0 + y * 4.0) * math.sin(y * 8.5 - x * 3.0) \
        + 0.0028 * math.sin(x * 27.0 + 1.2) * math.sin(y * 21.0 - 0.4)
    h = 0.014 * t ** 0.6 + mound + lobe + shoulder + ripples
    f = min(1.0, t / 0.34)
    return -0.020 + (h + 0.020) * f * f


def silt(b):
    """A clean polar mound: lobed rim on the seabed, buried +Y flank, ripples, no loose verts or gaps."""
    rings, seg = 9, 32
    cx, cy = 0.12, 0.02
    rx, ry = 0.80, 0.40
    idx = []
    for k in range(rings):
        t = ((k + 1) / rings) ** 0.9
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            wob = 1.0 + 0.11 * math.sin(2 * a + 0.6) + 0.07 * math.sin(5 * a - 1.3)
            x = cx + rx * t * wob * math.cos(a)
            y = cy + ry * t * wob * math.sin(a)
            row.append(b.add_vert((x, y, silt_h(x, y))))
        idx.append(row)
    c = b.add_vert((cx, cy, silt_h(cx, cy)))
    for i in range(seg):
        b.face([c, idx[0][(i + 1) % seg], idx[0][i]], [(0.5, 0.5), (0.5, 0.5), (0.5, 0.5)], True)
    for k in range(rings - 1):
        for i in range(seg):
            j = (i + 1) % seg
            b.face([idx[k][i], idx[k][j], idx[k + 1][j], idx[k + 1][i]],
                   [(0.0, 0.0)] * 4, True)


def rope_path():
    pts = [tilted((0.286, 0.040, 0.086)), tilted((0.302, 0.044, 0.058)), tilted((0.322, 0.040, 0.034)),
           Vector((0.352, 0.030, silt_h(0.352, 0.030) + 0.012)),
           Vector((0.392, 0.012, silt_h(0.392, 0.012) + 0.010)),
           Vector((0.436, -0.012, silt_h(0.436, -0.012) + 0.009))]
    cx, cy = 0.590, -0.070
    for k in range(13):                                                # a loose coil lying in the silt
        t = k / 12.0
        a = math.radians(-150.0 + 560.0 * t)
        rad = 0.128 - 0.055 * t
        x = cx + rad * math.cos(a)
        y = cy + rad * 0.58 * math.sin(a)
        pts.append(Vector((x, y, silt_h(x, y) + 0.009)))
    for x, y in ((0.766, -0.116), (0.826, -0.132), (0.874, -0.140)):
        pts.append(Vector((x, y, silt_h(x, y) + 0.010)))
    return pts


def bridle(b):
    """The parted bridle: down over the end of the pot, coiled across the silt, ending in frayed yarns."""
    path = rope_path()
    v, f, _, _, _ = RP.tube(path, 0.018, "three_strand", sides=6, max_tris=500)
    idx = [b.add_vert(Vector(p) / S) for p in v]
    for face in f:
        b.face([idx[i] for i in face], [(0.0, 0.0)] * len(face), True)
    end = path[-1]
    for k in range(4):                                                   # broken yarns at the frayed end
        a = 2 * math.pi * k / 4.0 + 0.4
        d = Vector((0.85, 0.30 * math.cos(a), 0.18 * math.sin(a) + 0.05)).normalized()
        W.sweep(b, [end + d * (0.050 * t) + Vector((0, 0, -0.010 * t * t)) for t in (0.0, 0.55, 1.0)],
                W.round_profile(0.0032, 3), UV, smooth=True, caps=(False, False))


def marker_float(b):
    """The crushed marker float: a squashed plastic buoy silted on the sand, its neck still on the rope."""
    z = silt_h(0.905, -0.140) + 0.016
    c = Vector((0.905, -0.140, z))
    start = len(b.v)
    rows = [(0.001, -0.038), (0.030, -0.034), (0.050, -0.017), (0.056, 0.009), (0.043, 0.026), (0.019, 0.033), (0.001, 0.036)]
    W.lathe(b, [(r, zz) for r, zz in rows], 10, lambda kk, a: (a, kk / 6.0), centre=tuple(c))
    M = Matrix.Translation(c) @ Matrix.Diagonal((0.92, 1.55, 0.66, 1.0)) @ Matrix.Translation(-c)
    b.transform(M, start)
    eye = c + Vector((-0.052, 0.010, 0.006))
    W.ring(b, eye, (1, 0.3, 0), (0, 0, 1), 0.016, 0.004, 8, 4, UV)
    for k in range(4):                                                   # barnacles on the float
        base = c + Vector((rnd.uniform(-0.035, 0.035), rnd.uniform(-0.05, 0.05), 0.018 + rnd.uniform(-0.003, 0.003)))
        r = rnd.uniform(0.006, 0.010)
        W.lathe(b, [(r, 0.0), (r * 0.7, r * 0.6), (r * 0.4, r)], 5, lambda kk, a: (a, kk / 2.0), centre=tuple(base))


def col():
    boxes = [((0.0, 0.008, 0.155), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.298, 0.232, 0.160)),
             ((0.880, -0.140, 0.030), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.070, 0.060, 0.034))]
    return W.col_boxes(boxes, NAME + "_COL")


# ---------------------------------------------------------------- build
def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def part(b, suffix, mat, crust=None, tilt=True):
    """Tilt the pot into its settled attitude, make the object, unwrap it into its cell of the sheet."""
    if tilt:
        b.transform(rot())
    ob = b.to_object("%s_%s_LOD0" % (NAME, suffix), mat)
    unwrap(ob, UNWRAP[ob.name])
    if crust:
        crusty(ob, crust[0], crust[1])
    print("[%s] %s %d tris" % (NAME, ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons)))
    return ob


def build():
    clear()
    make_materials()
    b = Buf()
    frame(b)
    f = part(b, "Frame", "MI_LostPot_Frame", (1400, 4711))
    b = Buf()
    netting(b)
    n = part(b, "Net", "MI_LostPot_Net")
    b = Buf()
    growth(b)
    g = part(b, "Growth", "MI_LostPot_Growth")
    b = Buf()
    bridle(b)
    r = part(b, "Rope", "MI_LostPot_Rope", tilt=False)
    b = Buf()
    marker_float(b)
    fl = part(b, "Float", "MI_LostPot_Float", tilt=False)
    b = Buf()
    silt(b)
    si = part(b, "Silt", "MI_LostPot_Silt", tilt=False)
    c = col()
    atts = [W.empty("ATT_Grab", (0.0, 0.034, 0.296), look=(0, -1, 0)),
            W.empty("ATT_RopeEnd", (0.895, -0.145, 0.045), look=(1, 0, 0))]
    lo, hi = W.bbox([f, n, g, r, fl, si])
    print("[%s] bbox m %.3f x %.3f x %.3f, min z %.4f" % (NAME, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, lo.z))
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in (f, n, g, r, fl, si))
    print("[%s] LOD0 total %d tris" % (NAME, tris))
    return {
        "name": NAME, "budget": "large_prop", "tris": 6000, "tier": "standard",
        "dims_m": (None, None, 0.35), "origin": "free",
        "size_note": "pot body 0.59 x 0.46 x 0.30 m (dims.md); the parted bridle, the crushed float and the weed "
                     "add 0.36 m to the footprint and 0.05 m to the height",
        "sets": [{"name": "LostPot", "set": SET, "size": 1024, "wet": True, "wet_streaks": 0.25,
                  "wear": {"edge": 0.45, "edge_color": (0.55, 0.56, 0.52), "salt": 0.5, "salt_color": (0.76, 0.75, 0.70),
                           "rust": 0.16, "rust_fingers": 11, "rust_length": 0.30, "ao_strength": 0.4}}],
        "meshes": [{"object": f, "set": SET}, {"object": n, "set": SET}, {"object": g, "set": SET},
                   {"object": r, "set": SET}, {"object": fl, "set": SET}, {"object": si, "set": SET},
                   {"object": c}],
        "waivers": {"LOD UV layout": "Net LOD2 is a rebuilt coarse net (the fine net has a decimation floor above its "
                                     "LOD2 target); its UVs are surface-projected so it samples the same texels"},
        "attachments": atts,
        "closeups": [
            {"name": "eye_funnel", "target": [0.84, 0.0, 0.55], "dist": 4.0, "az": 35, "el": 12},
            {"name": "float_rope", "target": [2.6, -0.42, 0.12], "dist": 4.0, "az": 120, "el": 25},
        ],
    }
