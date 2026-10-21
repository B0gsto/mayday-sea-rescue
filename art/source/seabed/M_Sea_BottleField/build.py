"""M_Sea_BottleField (S2, docs/12 2.7): a harbour-approach seabed clutter kit of six pieces.

Piece 1  a Bordeaux wine bottle, dark green glass, lying and half sunk in its sand collar.
Piece 2  a beer bottle, amber glass, lying at a slight angle, frosted lip.
Piece 3  a medicine bottle, clear glass, snapped at the neck, standing sunk to the shoulder.
Piece 4  a salt-glazed stoneware jar, ringed body, upright and tilted into the seabed.
Piece 5  a cluster of four green bottles, tipped out of a crate, two lying, one across them, a small one.
Piece 6  a scatter patch: a lobed drift of sand with five bottles half buried, a rusty can and glass shards.
Every piece has a sand collar where it meets the seabed; barnacle crust and filament weed grow at the waterline
of the glass and on the jar. One Seabed set (1024, wet) shared by the whole kit; per-slot tints give the green,
amber and clear glass, stoneware, tarnished tin, weed and sand their own albedo. Glass surfaces carry a _HP
duplicate with fine hand-blown waviness and sea-frost pitting so the NOR map reads as old glass.
Origin: base, bbox centre at x = y = 0. No attachments (docs/12 and docs/10 list the field as scenery).
"""
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
import budgets  # noqa: E402
import common  # noqa: E402
import names  # noqa: E402
import versions  # noqa: E402
import wreckgeo as W  # noqa: E402
from wreckgeo import Buf  # noqa: E402

NAME = "M_Sea_BottleField"
S = 3.0
SET = "Seabed"
rnd = random.Random(2029)

MATS = [("MI_BottleField_GreenGlass", (0.115, 0.205, 0.145), 0.22),
        ("MI_BottleField_AmberGlass", (0.285, 0.225, 0.165), 0.20),
        ("MI_BottleField_ClearGlass", (0.560, 0.610, 0.555), 0.18),
        ("MI_BottleField_Stoneware", (0.400, 0.330, 0.255), 0.60),
        ("MI_BottleField_Tin", (0.300, 0.230, 0.165), 0.55),
        ("MI_BottleField_Weed", (0.300, 0.340, 0.195), 0.78),
        ("MI_BottleField_Barnacle", (0.430, 0.420, 0.360), 0.84),
        ("MI_BottleField_Sand", (0.455, 0.425, 0.355), 0.86)]

UNWRAP = {"M_Sea_BottleField_Wine_LOD0": (0.010, 0.335, 0.510, 0.990),
          "M_Sea_BottleField_Beer_LOD0": (0.345, 0.620, 0.510, 0.990),
          "M_Sea_BottleField_Medicine_LOD0": (0.010, 0.335, 0.010, 0.260),
          "M_Sea_BottleField_Jar_LOD0": (0.345, 0.620, 0.010, 0.260),
          "M_Sea_BottleField_Cluster_LOD0": (0.630, 0.990, 0.330, 0.640),
          "M_Sea_BottleField_Scatter_LOD0": (0.630, 0.990, 0.010, 0.320),
          "M_Sea_BottleField_Can_LOD0": (0.630, 0.760, 0.650, 0.760),
          "M_Sea_BottleField_Collars_LOD0": (0.010, 0.460, 0.270, 0.500),
          "M_Sea_BottleField_Growth_LOD0": (0.470, 0.620, 0.270, 0.500),
          "M_Sea_BottleField_Barnacles_LOD0": (0.765, 0.990, 0.650, 0.760),
          "M_Sea_BottleField_Bed_LOD0": (0.010, 0.990, 0.650, 0.990)}


# ---------------------------------------------------------------- materials, UV and LOD hygiene
def make_materials():
    for name, rgb, rough in MATS:
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
            bsdf.inputs["Roughness"].default_value = rough
            bsdf.inputs["Metallic"].default_value = 0.35 if name.endswith("Tin") else 0.0
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
    """Smart project, normalise every island to its own cell and shelf-pack the cells into the part's rect."""
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
    place = {}
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
    """Collapse decimation drops a little UV area; rescale each LOD island about its centre to restore density."""
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
        for d in uvl:
            d.uv = (min(max(d.uv.x, x0 + 0.001), x1 - 0.001), min(max(d.uv.y, y0 + 0.001), y1 - 0.001))
        me.update()


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


# ---------------------------------------------------------------- bottle profiles (radius m, height m)
WINE = [(0.0010, 0.020), (0.0140, 0.014), (0.0300, 0.003), (0.0360, 0.000), (0.0374, 0.012), (0.0376, 0.190),
        (0.0345, 0.218), (0.0270, 0.237), (0.0180, 0.252), (0.0128, 0.266), (0.0124, 0.292), (0.0142, 0.298),
        (0.0150, 0.303), (0.0140, 0.306), (0.0115, 0.303), (0.0100, 0.294), (0.0100, 0.270), (0.0080, 0.252),
        (0.0010, 0.248)]
BEER = [(0.0010, 0.012), (0.0140, 0.008), (0.0270, 0.002), (0.0310, 0.000), (0.0318, 0.012), (0.0318, 0.155),
        (0.0305, 0.175), (0.0268, 0.192), (0.0205, 0.207), (0.0150, 0.218), (0.0120, 0.228), (0.0118, 0.240),
        (0.0135, 0.244), (0.0150, 0.248), (0.0132, 0.251), (0.0108, 0.248), (0.0098, 0.240), (0.0098, 0.225),
        (0.0010, 0.222)]
MEDICINE = [(0.0010, 0.004), (0.0120, 0.003), (0.0220, 0.000), (0.0240, 0.008), (0.0240, 0.062), (0.0225, 0.078),
            (0.0200, 0.090), (0.0180, 0.094), (0.0160, 0.090), (0.0155, 0.075), (0.0140, 0.055), (0.0010, 0.052)]
JAR = [(0.0010, 0.006), (0.0160, 0.005), (0.0320, 0.002), (0.0430, 0.000), (0.0460, 0.006), (0.0475, 0.030),
       (0.0460, 0.036), (0.0475, 0.042), (0.0470, 0.050), (0.0478, 0.080), (0.0472, 0.140), (0.0445, 0.163),
       (0.0380, 0.182), (0.0300, 0.196), (0.0270, 0.202), (0.0285, 0.208), (0.0250, 0.210), (0.0210, 0.206),
       (0.0160, 0.198), (0.0010, 0.196)]
SIMPLE = [(0.0010, 0.016), (0.0180, 0.010), (0.0320, 0.002), (0.0370, 0.000), (0.0378, 0.020), (0.0375, 0.185),
          (0.0325, 0.218), (0.0195, 0.245), (0.0128, 0.258), (0.0124, 0.292), (0.0142, 0.300), (0.0100, 0.299),
          (0.0010, 0.297)]
CAN = [(0.0010, 0.002), (0.0300, 0.001), (0.0330, 0.004), (0.0330, 0.100), (0.0300, 0.106), (0.0180, 0.104),
       (0.0010, 0.102)]


def glass_wobble(b, start, amp=0.010):
    """Hand-blown waviness: gentle radial ripple plus a whisper of lean, before placement."""
    for i in range(start, len(b.v)):
        p = b.v[i]
        r = math.hypot(p.x, p.y)
        if r > 1e-5:
            f = 1.0 + amp * (math.sin(p.z * 41.0 + p.x * 27.0) + 0.5 * math.sin(p.z * 97.0 - p.y * 33.0))
            b.v[i] = Vector((p.x * f, p.y * f, p.z + 0.0005 * math.sin(p.x * 61.0 + p.y * 19.0)))


def jag_rim(b, rows, n, amp):
    """Break the mouth: a per-segment height offset on the outer and inner rim rows (seam duplicated)."""
    offs = [amp * (0.55 * math.sin(i * 2.4 + 0.7) + 0.45 * math.sin(i * 5.1 - 1.9)) for i in range(n)]
    for row in rows:
        for i, vi in enumerate(row):
            b.v[vi] = b.v[vi] + Vector((0, 0, offs[i % n]))


def place_lying(loc, yaw, roll, scale, length, rad):
    M = (Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
         @ Matrix.Rotation(math.radians(roll), 4, "X") @ Matrix.Rotation(math.pi / 2.0, 4, "Y")
         @ Matrix.Translation(Vector((0.0, 0.0, -length * scale / 2.0))) @ Matrix.Diagonal((scale, scale, scale, 1.0)))
    return M


def place_upright(loc, yaw, tilt, scale):
    return (Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
            @ Matrix.Rotation(math.radians(tilt), 4, "X") @ Matrix.Diagonal((scale, scale, scale, 1.0)))


def add_bottle(b, prof, n, M, jag=None):
    start = len(b.v)
    rows = W.lathe(b, prof, n, lambda k, a: (a, k / float(len(prof) - 1)))
    if jag:
        jag_rim(b, [rows[-5], rows[-4]], n, jag)
    else:
        glass_wobble(b, start, 0.010)
    b.transform(M, start)
    return rows


def add_barnacles(g, M, rad, z0, z1, count, size=0.0060):
    """A cluster of volcano barnacles on the exposed upper face, aligned to the local surface normal."""
    up_local = M.inverted().to_3x3() @ Vector((0.0, 0.0, 1.0))
    a0 = math.atan2(up_local.y, up_local.x)
    zc = rnd.uniform(z0 + 0.15 * (z1 - z0), z1 - 0.20 * (z1 - z0))
    for k in range(count):
        a = a0 + rnd.uniform(-0.55, 0.55)
        z = zc + rnd.uniform(-0.022, 0.020)
        rb = size * rnd.uniform(0.55, 1.15)
        p = Vector((rad * 1.002 * math.cos(a), rad * 1.002 * math.sin(a), z))
        N = M @ Matrix.Translation(p) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(math.pi / 2.0, 4, "Y")
        sub = Buf()
        W.lathe(sub, [(rb, 0.0), (rb * 0.62, rb * 0.48), (rb * 0.26, rb * 0.85)], 5, lambda kk, aa: (aa, kk / 2.0))
        g.extend(sub, N)


def add_weed_tuft(g, base, up, side, length, width):
    up = Vector(up).normalized()
    side = Vector(side).normalized()
    bend = (up * 0.85 - side * 0.30 + Vector((0, 0, 0.10))).normalized()
    W.card(g, base + Vector((0, 0, -0.004)), up, side, length, width, 2, bend, (0.0, 1.0), droop=0.0)


# ---------------------------------------------------------------- sand
BED_C = (-0.35, -0.38)
BED_RX, BED_RY = 0.72, 0.48


def bed_h(x, y):
    u, v = (x - BED_C[0]) / BED_RX, (y - BED_C[1]) / BED_RY
    a = math.atan2(v, u)
    wob = 1.0 + 0.13 * math.sin(2.0 * a + 1.1) + 0.07 * math.sin(5.0 * a - 0.6)
    t = min(1.0, math.hypot(u, v) / wob)
    ripple = 0.0055 * math.sin(x * 23.0 + y * 9.0) * math.sin(y * 17.0 - x * 5.0)
    ripple += 0.0025 * math.sin(x * 41.0 - 0.8) * math.sin(y * 31.0 + 1.4)
    low = 0.004 * math.sin(x * 4.1 + 0.7) * math.sin(y * 5.3 - 1.2)
    return (0.017 * (1.0 - t * t) ** 1.05) + (ripple + low) * (1.0 - t) ** 0.5


def add_mound(b, cx, cy, rx, ry, h, yaw, rings=3, seg=10, seed=0.0, z0=0.0, drift=0.22):
    ca, sa = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    idx = []
    for k in range(rings):
        t = (k + 1) / float(rings)
        row = []
        for i in range(seg):
            a = 2.0 * math.pi * i / seg
            wob = (1.0 + 0.16 * math.sin(3.0 * a + seed) + 0.09 * math.sin(5.0 * a - seed)
                   + 0.04 * math.sin(9.0 * a + seed * 3.0))
            lx, ly = rx * t * wob * math.cos(a), ry * t * wob * math.sin(a)
            z = h * (1.0 - t * t) ** 1.05 * (1.0 + drift * math.cos(a - seed * 2.0)) \
                * (0.92 + 0.08 * math.sin(4.0 * a + seed * 2.0))
            row.append(b.add_vert((cx + lx * ca - ly * sa, cy + lx * sa + ly * ca, z0 + z)))
        idx.append(row)
    c = b.add_vert((cx, cy, z0 + h))
    for i in range(seg):
        b.face([c, idx[0][(i + 1) % seg], idx[0][i]], [(0.5, 0.5)] * 3, True)
    for k in range(rings - 1):
        for i in range(seg):
            j = (i + 1) % seg
            b.face([idx[k][i], idx[k][j], idx[k + 1][j], idx[k + 1][i]], [(0.0, 0.0)] * 4, True)


def add_bed(b):
    rings, seg = 8, 24
    idx = []
    for k in range(rings):
        t = (k + 1) / float(rings)
        row = []
        for i in range(seg):
            a = 2.0 * math.pi * i / seg
            wob = 1.0 + 0.09 * math.sin(2.0 * a + 1.1) + 0.05 * math.sin(5.0 * a - 0.6)
            x = BED_C[0] + BED_RX * t * wob * math.cos(a)
            y = BED_C[1] + BED_RY * t * wob * math.sin(a)
            row.append(b.add_vert((x, y, bed_h(x, y))))
        idx.append(row)
    c = b.add_vert((BED_C[0], BED_C[1], bed_h(*BED_C)))
    for i in range(seg):
        b.face([c, idx[0][(i + 1) % seg], idx[0][i]], [(0.5, 0.5)] * 3, True)
    for k in range(rings - 1):
        for i in range(seg):
            j = (i + 1) % seg
            b.face([idx[k][i], idx[k][j], idx[k + 1][j], idx[k + 1][i]], [(0.0, 0.0)] * 4, True)


# ---------------------------------------------------------------- high poly (bake source)
def make_hp(ob, fine=0.0010, low=0.0012, pits=True):
    hp = versions.copy_object(ob, names.mesh_base(ob.name) + "_HP")
    sub = hp.modifiers.new("Sub", "SUBSURF")
    sub.subdivision_type, sub.levels, sub.render_levels = "SIMPLE", 1, 1
    tx = bpy.data.textures.new("BFWa_%s" % ob.name[-8:], "CLOUDS")
    tx.noise_scale, tx.noise_depth = 0.060, 2
    d = hp.modifiers.new("Wa", "DISPLACE")
    d.texture, d.strength, d.mid_level, d.direction = tx, low, 0.5, "NORMAL"
    d.texture_coords = "GLOBAL"
    if pits:
        tp = bpy.data.textures.new("BFPit%s" % ob.name[-8:], "VORONOI")
        tp.noise_scale, tp.noise_intensity = 0.017, 1.0
        dp = hp.modifiers.new("Pits", "DISPLACE")
        dp.texture, dp.strength, dp.mid_level, dp.direction = tp, -fine, 0.5, "NORMAL"
        dp.texture_coords = "GLOBAL"
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(hp.evaluated_get(dg))
    hp.modifiers.clear()
    old = hp.data
    hp.data = me
    bpy.data.meshes.remove(old)
    me.name = hp.name
    for p in me.polygons:
        p.use_smooth = True
    return hp


# ---------------------------------------------------------------- pieces
def build_wine(b, g):
    """Bordeaux bottle, 0.30 m, dark green, lying with its neck toward the light."""
    loc = (-0.95, 0.55, 0.0376 * 0.97)
    M = place_lying(loc, 15.0, 4.0, 0.97, 0.306, 0.0376)
    add_bottle(b, WINE, 16, M)
    add_barnacles(g, M, 0.0376 * 0.97, 0.025, 0.150, 4, 0.0065)
    return [dict(c=(loc[0], loc[1]), rx=0.205, ry=0.060, yaw=15.0, h=0.021, seed=1.1, z0=0.0)]


def build_beer(b, g):
    """Amber beer bottle, 0.25 m, lying at a slight angle, its crown lip frosted."""
    loc = (-0.58, 0.66, 0.0318 * 0.98)
    M = place_lying(loc, -12.0, -8.0, 0.98, 0.251, 0.0318)
    add_bottle(b, BEER, 16, M)
    add_barnacles(g, M, 0.0318 * 0.98, 0.020, 0.130, 2, 0.0060)
    return [dict(c=(loc[0], loc[1]), rx=0.172, ry=0.054, yaw=-12.0, h=0.018, seed=2.4, z0=0.0)]


def build_medicine(b, g):
    """Clear medicine bottle, snapped at the neck, upright and sunk to the shoulder."""
    loc = (-0.28, 0.43, 0.0)
    M = place_upright(loc, 35.0, 6.0, 1.0)
    add_bottle(b, MEDICINE, 12, M, jag=0.0035)
    add_barnacles(g, M, 0.0240, 0.012, 0.055, 3, 0.0048)
    return [dict(c=(loc[0], loc[1]), rx=0.052, ry=0.052, yaw=0.0, h=0.019, seed=3.7, z0=0.0)]


def build_jar(b, g):
    """Salt-glazed stoneware jar, 0.21 m, upright and tilted 9 degrees into the sand."""
    loc = (0.02, 0.60, 0.0)
    M = place_upright(loc, -20.0, 9.0, 1.0)
    add_bottle(b, JAR, 14, M)
    add_barnacles(g, M, 0.0478, 0.016, 0.065, 3, 0.0065)
    return [dict(c=(loc[0], loc[1]), rx=0.076, ry=0.076, yaw=0.0, h=0.023, seed=4.2, z0=0.0)]


def build_cluster(b, g):
    """Four green bottles tipped out of a crate: two lying, one across them, a small one."""
    cx, cy = 0.58, 0.28
    entries = [((-0.09, 0.08), 8.0, 5.0, 0.97, 0.0376 * 0.97),
               ((0.10, 0.01), -7.0, -12.0, 0.86, 0.0376 * 0.86),
               ((-0.01, -0.05), 38.0, 0.0, 0.70, 0.075),
               ((0.17, 0.10), -24.0, 9.0, 0.52, 0.0376 * 0.52)]
    for (dx, dy), yaw, roll, sc, z in entries:
        loc = (cx + dx, cy + dy, z)
        M = place_lying(loc, yaw, roll, sc, 0.300, 0.0376)
        add_bottle(b, SIMPLE, 10, M)
        add_barnacles(g, M, 0.0378 * sc, 0.020, 0.150 * sc, 2, 0.0055)
    return [dict(c=(cx - 0.06, cy + 0.06), rx=0.155, ry=0.072, yaw=10.0, h=0.019, seed=5.1, z0=0.0),
            dict(c=(cx + 0.13, cy + 0.02), rx=0.105, ry=0.062, yaw=-12.0, h=0.016, seed=5.4, z0=0.0),
            dict(c=(cx - 0.02, cy - 0.04), rx=0.135, ry=0.078, yaw=28.0, h=0.014, seed=5.7, z0=0.0)]


def build_scatter(b, g):
    """Smash patch: five bottles half sunk in the drift, a rusty can and a few glass shards."""
    items = [((-0.63, -0.30), 58.0, 6.0, 0.82),
             ((-0.28, -0.22), -18.0, -10.0, 0.95),
             ((-0.10, -0.49), 104.0, 14.0, 0.72),
             ((-0.72, -0.53), 11.0, -5.0, 0.60),
             ((-0.46, -0.56), -62.0, 22.0, 0.66)]
    out = [dict(c=BED_C, rx=BED_RX, ry=BED_RY, yaw=0.0, h=0.0, seed=6.0, z0=0.0, is_bed=True, no_mound=True)]
    for (x, y), yaw, roll, sc in items:
        z = bed_h(x, y) + 0.0376 * sc
        M = place_lying((x, y, z), yaw, roll, sc, 0.300, 0.0376)
        add_bottle(b, SIMPLE, 10, M)
        add_barnacles(g, M, 0.0378 * sc, 0.020, 0.140 * sc, 1, 0.0052)
        out.append(dict(c=(x, y), rx=0.085 + 0.035 * sc, ry=0.040 + 0.018 * sc, yaw=yaw,
                        h=0.014, seed=6.2 + x, z0=bed_h(x, y) - 0.001, small=True))
    for (x, y, ln, wd, rot) in ((-0.52, -0.14, 0.05, 0.030, 0.4), (-0.18, -0.62, 0.038, 0.022, 2.1),
                                (-0.66, -0.20, 0.030, 0.018, 4.0)):
        z = bed_h(x, y) + 0.0015
        p0 = Vector((x, y, z))
        p1 = p0 + Vector((math.cos(rot) * ln, math.sin(rot) * ln, 0.0015))
        p2 = p0 + Vector((math.cos(rot + 1.9) * wd, math.sin(rot + 1.9) * wd, 0.001))
        i0 = b.add_vert(p0)
        i1 = b.add_vert(p1)
        i2 = b.add_vert(p2)
        b.face([i0, i1, i2], [(0, 0), (1, 0), (0, 1)], True)
    return out


def build_can(b, g):
    """The odd can: a dented, rusted food tin lying in the drift."""
    x, y = (-0.33, -0.61)
    z = bed_h(x, y) + 0.033
    M = place_lying((x, y, z), -70.0, 0.0, 0.95, 0.107, 0.033)
    start = len(b.v)
    W.lathe(b, CAN, 12, lambda k, a: (a, k / float(len(CAN) - 1)))
    for i in range(start, len(b.v)):
        p = b.v[i]
        r = math.hypot(p.x, p.y)
        if r > 1e-5:
            f = 1.0 + 0.045 * math.sin(p.z * 70.0 + p.x * 3.0)
            b.v[i] = Vector((p.x * f, p.y * f, p.z))
    b.transform(M, start)
    add_barnacles(g, M, 0.0334, 0.018, 0.075, 2, 0.0052)
    return [dict(c=(x, y), rx=0.080, ry=0.046, yaw=-70.0, h=0.012, seed=7.3,
                 z0=bed_h(x, y) - 0.001, small=True)]


def build_growth(g, collars):
    """Weed tufts and barnacle crust along the collars: the pieces lay here long enough to be fouled."""
    for c in collars:
        n = 5 if c.get("is_bed") else 2
        for k in range(n):
            a = 2.0 * math.pi * (k + 0.4 * rnd.random()) / n + c["seed"]
            wob = 1.0 + 0.10 * math.sin(3.0 * a + c["seed"])
            t = 0.68
            lx = c["rx"] * t * wob * math.cos(a)
            ly = c["ry"] * t * wob * math.sin(a)
            ca, sa = math.cos(math.radians(c["yaw"])), math.sin(math.radians(c["yaw"]))
            x = c["c"][0] + lx * ca - ly * sa
            y = c["c"][1] + lx * sa + ly * ca
            if c.get("is_bed"):
                z = bed_h(x, y)
            else:
                z = c.get("z0", 0.0) + c["h"] * (1.0 - t * t) ** 1.35
            base = Vector((x, y, z))
            splay = Vector((math.cos(a), math.sin(a), 0.0)) * 0.35 + Vector((0, 0, 1.0))
            ln = rnd.uniform(0.060, 0.110) if c.get("is_bed") else rnd.uniform(0.045, 0.080)
            wd = rnd.uniform(0.012, 0.024)
            side = Vector((-math.sin(a + 0.4), math.cos(a + 0.4), 0.15))
            add_weed_tuft(g, base, splay, side, ln, wd)
            if k < 2:
                a2 = a + rnd.uniform(0.35, 0.7)
                splay2 = Vector((math.cos(a2), math.sin(a2), 0.0)) * 0.35 + Vector((0, 0, 1.0))
                side2 = Vector((-math.sin(a2 + 0.3), math.cos(a2 + 0.3), 0.2))
                add_weed_tuft(g, base, splay2, side2, ln * 0.8, wd * 0.85)


def col():
    boxes = [((-0.95, 0.55, 0.030), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.165, 0.048, 0.030)),
             ((-0.58, 0.66, 0.028), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.135, 0.042, 0.028)),
             ((-0.28, 0.43, 0.048), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.030, 0.030, 0.048)),
             ((0.02, 0.60, 0.095), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.052, 0.052, 0.095)),
             ((0.58, 0.28, 0.060), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.300, 0.160, 0.060)),
             ((BED_C[0], BED_C[1], 0.013), ((1, 0, 0), (0, 1, 0), (0, 0, 1)), (0.660, 0.430, 0.013))]
    return W.col_boxes(boxes, NAME + "_COL")


# ---------------------------------------------------------------- build
def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def build():
    clear()
    make_materials()
    hps = []
    meshes = []

    def part(suffix, mat, fill, hp=None):
        b = Buf()
        info = fill(b)
        ob = b.to_object("%s_%s_LOD0" % (NAME, suffix), mat)
        unwrap(ob, UNWRAP[ob.name])
        versions.weighted_normals(ob)
        print("[%s] %s %d tris" % (NAME, ob.name, versions.triangles(ob.data)))
        meshes.append(ob)
        if hp:
            hps.append((ob, hp))
        return info

    collars = []
    gbuf = Buf()
    bbuf = Buf()

    def piece(suffix, mat, maker, hp, growth=True):
        b = Buf()
        collars.extend(maker(b, bbuf if growth else gbuf))
        ob = b.to_object("%s_%s_LOD0" % (NAME, suffix), mat)
        unwrap(ob, UNWRAP[ob.name])
        versions.weighted_normals(ob)
        print("[%s] %s %d tris" % (NAME, ob.name, versions.triangles(ob.data)))
        meshes.append(ob)
        hps.append((ob, hp))
        return ob

    piece("Wine", "MI_BottleField_GreenGlass", build_wine, dict(fine=0.0011, low=0.0014))
    piece("Beer", "MI_BottleField_AmberGlass", build_beer, dict(fine=0.0010, low=0.0012))
    piece("Medicine", "MI_BottleField_ClearGlass", build_medicine, dict(fine=0.0012, low=0.0010))
    piece("Jar", "MI_BottleField_Stoneware", build_jar, dict(fine=0.0014, low=0.0016))
    piece("Cluster", "MI_BottleField_GreenGlass", build_cluster, dict(fine=0.0011, low=0.0013))
    piece("Scatter", "MI_BottleField_GreenGlass", build_scatter, dict(fine=0.0011, low=0.0013))
    piece("Can", "MI_BottleField_Tin", build_can, dict(fine=0.0012, low=0.0016))

    build_growth(gbuf, collars)
    part("Growth", "MI_BottleField_Weed", lambda b: (b.extend(gbuf), b)[1])
    part("Barnacles", "MI_BottleField_Barnacle", lambda b: (b.extend(bbuf), b)[1])

    def collars_fill(b):
        for c in collars:
            if c.get("no_mound"):
                continue
            cheap = c.get("is_bed") or c.get("small")
            add_mound(b, c["c"][0], c["c"][1], c["rx"], c["ry"], c["h"], c["yaw"],
                      rings=(2 if cheap else 3), seg=(8 if cheap else 10),
                      seed=c["seed"], z0=c.get("z0", 0.0))
        return b
    part("Collars", "MI_BottleField_Sand", collars_fill, hp=dict(fine=0.0016, low=0.0012, pits=False))

    part("Bed", "MI_BottleField_Sand", lambda b: (add_bed(b), b)[1],
         hp=dict(fine=0.0018, low=0.0010, pits=False))

    off = W.shift_to_base(meshes)
    c = col()
    c.data.transform(Matrix.Translation(off))
    c.data.update()
    meshes.append(c)
    for ob, hp in hps:
        make_hp(ob, **hp)

    lo, hi = W.bbox([o for o in meshes if not o.name.endswith("_COL")])
    print("[%s] bbox m %.3f x %.3f x %.3f, min z %.4f" % (NAME, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, lo.z))
    tris = sum(versions.triangles(o.data) for o in meshes if o.name.endswith("_LOD0"))
    print("[%s] LOD0 total %d tris" % (NAME, tris))

    entries = [{"object": o, "set": SET} for o in meshes if not o.name.endswith("_COL")]
    entries.append({"object": c})
    return {
        "name": NAME, "budget": "large_prop", "tris": 6000, "tier": "standard",
        "dims_m": (1.97, 1.56, 0.22), "origin": "base",
        "size_note": "six-piece seabed clutter kit laid out as one scatter plot, not a single object",
        "sets": [{"name": "BottleField", "set": SET, "size": 1024, "wet": True, "wet_streaks": 0.18,
                  "wet_darken": 0.13, "wet_gloss": 0.12,
                  "wear": {"edge": 0.40, "edge_color": (0.62, 0.65, 0.57), "salt": 0.65,
                           "salt_color": (0.72, 0.73, 0.65), "rust": 0.0, "ao_strength": 0.55}}],
        "bake_size": 2048,
        "meshes": entries,
        "closeups": [{"name": n, "target": [round(p[0] * S + off[0], 3), round(p[1] * S + off[1], 3),
                                             round(p[2] * S + off[2], 3)], "dist": d, "az": az, "el": el}
                     for n, p, d, az, el in (
                         ("wine", (-0.95, 0.55, 0.075), 2.6, 35, 28),
                         ("cluster", (0.58, 0.28, 0.070), 3.2, 120, 34),
                         ("scatter", (-0.35, -0.38, 0.030), 3.6, 205, 38))],
    }
