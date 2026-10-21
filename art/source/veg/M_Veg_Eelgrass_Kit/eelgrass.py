"""S2 M_Veg_Eelgrass_Kit: Zostera marina tufts for Calm Bay (WorldConfig `Eelgrass`).

Five pieces on the kit's display line (1.35 m apart, +X): three tuft sizes, one broad low clump and one small
patch of young shoots with a rhizome runner. Each piece is a low sand collar with curved, twisted, drooping
blade strips growing from it; pivots/base points are at Z 0 (ATT_Base_01..05).

Blades are real thin geometry, not crossed planes: a centreline is bent by the current (+X), rolled along its
length, rippled sideways and drooped at the tip, and two 0.45 mm offset surfaces give true front/back normals
(no DoubleSided, no alpha sorting). Every vertex carries the Sway colour (R weight, G phase, B stiffness).
Textures come from the kit's FoliageMarine / Main cell (eelgrass_tex.py), written by build().

1 Blender unit = 1 stud (3 per metre).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(GAME, "tools/blender"))
sys.path.insert(0, HERE)
import common  # noqa: E402
import eelgrass_tex as T  # noqa: E402

M = common.STUDS_PER_METRE
CURRENT = Vector((1.0, 0.0, 0.0))
GRID = 1.35 * M
THICK = 0.00045
KIT_TRIS = 1500

# name, seed, bed R m, bed H m, long blades, short shoots, long L m, half width m, segs, old/dead odds
VARIANTS = (
    ("M_Veg_Eelgrass_01", 301, 0.11, 0.018, 8, 1, (0.30, 0.52), (0.0030, 0.0044), 4, (0.18, 0.03)),
    ("M_Veg_Eelgrass_02", 302, 0.14, 0.022, 10, 2, (0.45, 0.75), (0.0032, 0.0048), 5, (0.26, 0.05)),
    ("M_Veg_Eelgrass_03", 303, 0.17, 0.026, 12, 2, (0.62, 1.02), (0.0034, 0.0050), 5, (0.26, 0.06)),
    ("M_Veg_Eelgrass_04", 304, 0.19, 0.028, 11, 2, (0.38, 0.70), (0.0036, 0.0052), 5, (0.34, 0.10)),
    ("M_Veg_Eelgrass_Patch_01", 305, 0.085, 0.015, 6, 2, (0.16, 0.32), (0.0026, 0.0036), 4, (0.16, 0.04)),
)


def sstep(x, a, b):
    t = min(1.0, max(0.0, (x - a) / (b - a + 1e-9)))
    return t * t * (3 - 2 * t)


class Prim:
    """verts (metres), faces, per-vertex UV, normal (cards) and sway (r weight, g phase, b stiffness)."""

    def __init__(self, kind="solid"):
        self.kind = kind
        self.v, self.f, self.uv, self.n, self.sway = [], [], [], [], []

    def add(self, p, uv, n, sway):
        self.v.append(Vector(p))
        self.uv.append(uv)
        self.n.append(n)
        self.sway.append(sway)
        return len(self.v) - 1


def bed_h(R, H, r):
    return H * (1.0 - min(1.0, max(0.0, r / R)) ** 1.55)


def mound_prim(rng, R, H, sectors, spin):
    """Low irregular sand collar: apex, a mid ring and an outer ring at Z 0."""
    prim = Prim("solid")
    ph = rng.uniform(0, 2 * math.pi)
    apex = prim.add((rng.uniform(-0.01, 0.01) * R, rng.uniform(-0.01, 0.01) * R, H * rng.uniform(0.92, 1.08)),
                    T.uv("Sand", 0.5, 0.5, m=0.05), None, (0.0, 0.0, 1.0))
    rings = []
    for rn, raise_ in ((0.52, 0.0), (1.0, 0.0)):
        row = []
        for k in range(sectors):
            a = 2 * math.pi * k / sectors + spin
            wob = 1.0 + 0.10 * math.sin(3 * a + ph) + 0.05 * math.sin(5 * a + 2 * ph)
            r = R * rn * wob
            z = bed_h(R, H, r) * (1.0 + 0.08 * math.sin(2 * a + ph)) if rn < 1.0 else 0.0
            if rn >= 1.0:
                r = R * wob
            x, y = math.cos(a) * r, math.sin(a) * r
            u = 0.5 + (x * math.cos(spin) - y * math.sin(spin)) / (2.1 * R)
            v = 0.5 + (x * math.sin(spin) + y * math.cos(spin)) / (2.1 * R)
            row.append(prim.add((x, y, z), T.uv("Sand", u, v, m=0.04), None, (0.0, 0.0, 1.0)))
        rings.append(row)
    for k in range(sectors):
        k1 = (k + 1) % sectors
        prim.f.append((apex, rings[0][k], rings[0][k1]))
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(sectors):
            k1 = (k + 1) % sectors
            prim.f.append((r0[k], r1[k], r1[k1], r0[k1]))
    return prim


def blade_prim(rng, base, heading, length, hw, segs, el, lean, bend, droop, rect, root_phase, broken=False):
    """One eelgrass blade: bent by the current, rolled, rippled and drooped; real front and back surfaces."""
    d = Vector((math.cos(heading) * math.cos(el), math.sin(heading) * math.cos(el), math.sin(el)))
    p = Vector(base)
    step = length / segs
    pts = [p.copy()]
    for i in range(segs):
        t = i / max(segs - 1, 1)
        pull = CURRENT * (lean * 0.24 + bend * (0.04 + 0.62 * t ** 1.3))
        pull += Vector((0.0, 0.0, -1.0)) * (droop * max(0.0, t - 0.42) ** 1.7 * 1.35)
        d = (d + pull * 0.55).normalized()
        p = p + d * step
        pts.append(p.copy())

    lat = Vector((-math.sin(heading), math.cos(heading), 0.0))
    if lat.length < 1e-6:
        lat = Vector((0.0, 1.0, 0.0))
    ph = rng.uniform(0, 2 * math.pi)
    amp = rng.uniform(0.010, 0.032) * min(1.15, length / 0.7)
    freq = rng.uniform(0.85, 1.65)
    for i in range(1, segs + 1):
        t = i / segs
        pts[i] += lat * (amp * math.sin(2 * math.pi * freq * t + ph) * sstep(t, 0.10, 0.55))
        pts[i].z = max(0.006, pts[i].z)

    twist0 = rng.uniform(-0.55, 0.55)
    twist = rng.uniform(-1.30, 1.30)
    twv = rng.uniform(0.14, 0.40)
    tph = rng.uniform(0, 2 * math.pi)
    prim = Prim("card")
    for i, p in enumerate(pts):
        t = i / segs
        tang = (pts[min(i + 1, segs)] - pts[max(i - 1, 0)]).normalized()
        side = lat - tang * lat.dot(tang)
        if side.length < 1e-5:
            side = Vector((0.0, 1.0, 0.0)) - tang * tang.y
        side.normalize()
        phi = twist0 + twist * t + twv * math.sin(2 * math.pi * (1.1 * t + tph))
        side = (side * math.cos(phi) + tang.cross(side) * math.sin(phi)).normalized()
        n = tang.cross(side).normalized()

        wf = 0.56 + 0.44 * sstep(t, 0.0, 0.12)
        wf *= 1.0 - 0.88 * sstep(t, 0.74, 1.0)
        wf *= 1.0 + 0.06 * math.sin(2 * math.pi * (1.7 * t + ph * 0.7))
        if broken and t > 0.86:
            wf *= 0.72 + 0.22 * math.sin(2 * math.pi * (4.3 * t + ph))
        w = hw * max(0.10, wf)
        lift = n * (0.22 * w * math.sin(2 * math.pi * (2.1 * t + ph)))
        vl = p + side * w + lift
        vr = p - side * w - lift
        nl = (n + side * 0.34).normalized()
        nr = (n - side * 0.34).normalized()
        sway = (min(1.0, 0.06 + 0.94 * t ** 1.15), root_phase, 0.16)
        prim.add(vl, T.uv(rect, 0.02, t), nl, sway)
        prim.add(vr, T.uv(rect, 0.98, t), nr, sway)
    for i in range(segs):
        a = 2 * i
        prim.f.append((a, a + 1, a + 3, a + 2))
    return prim


def piece(variant):
    name, seed, R, H, n_long, n_short, lspan, hspan, segs, (old_odds, dead_odds) = variant
    rng = random.Random(seed)
    spin = rng.uniform(0, 2 * math.pi)
    prims = [mound_prim(rng, R, H, 12 if R > 0.13 else 8, spin)]
    phase0 = rng.random()
    k = 0

    def add_blade(long_blade, i):
        nonlocal k
        a = rng.uniform(0, 2 * math.pi)
        rn = rng.uniform(0.03, 0.58) ** 0.9
        base = Vector((math.cos(a) * R * rn, math.sin(a) * R * rn, bed_h(R, H, R * rn) * 0.96 + 0.003))
        if long_blade:
            heading = rng.gauss(0.0, 0.55) if rng.random() > 0.08 else math.pi + rng.gauss(0.0, 0.5)
            length = rng.uniform(*lspan) * rng.uniform(0.88, 1.12)
            hw = rng.uniform(*hspan)
            el = rng.uniform(0.96, 1.34)
            lean = rng.uniform(0.22, 0.58)
            bend = rng.uniform(0.45, 1.45)
            droop = rng.uniform(0.22, 0.88)
            nsegs = segs
            roll = rng.random()
            rect = "LeafOld" if roll < old_odds else ("LeafDead" if roll < old_odds + dead_odds else "LeafYoung")
            broken = rect == "LeafDead"
        else:
            heading = rng.gauss(0.0, 0.7)
            length = rng.uniform(0.12, 0.26) * (1.0 if R < 0.2 else 1.15)
            hw = rng.uniform(*hspan) * 0.72
            el = rng.uniform(1.20, 1.50)
            lean = rng.uniform(0.05, 0.18)
            bend = rng.uniform(0.10, 0.35)
            droop = rng.uniform(0.02, 0.18)
            nsegs = 3
            rect = "LeafOld" if rng.random() < old_odds else "LeafYoung"
            broken = False
        prims.append(blade_prim(rng, base, heading, length, hw, nsegs, el, lean, bend, droop,
                                rect, (phase0 + 0.37 * k) % 1.0, broken))
        k += 1

    for i in range(n_long):
        add_blade(True, i)
    for i in range(n_short):
        add_blade(False, i)

    if name.endswith("Patch_01"):
        for j in range(2):
            a = spin + math.pi * j + rng.uniform(-0.4, 0.4)
            base = Vector((math.cos(a) * R * 0.45, math.sin(a) * R * 0.45, bed_h(R, H, R * 0.45) * 0.8 + 0.002))
            prims.append(blade_prim(rng, base, a, rng.uniform(0.12, 0.20), rng.uniform(0.0016, 0.0022), 3,
                                    0.06, 0.0, 0.02, 0.0, "LeafDead", (phase0 + 0.61 * j) % 1.0, True))
    return prims


def make_mesh(name, prims):
    """Cards become two real offset surfaces with true normals; the sand collar is one smooth surface."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    loop_normals, sway_seq = [], []
    for prim in prims:
        if prim.kind == "card":
            for back in (False, True):
                bv = [bm.verts.new(v + prim.n[i] * (-THICK if back else THICK)) for i, v in enumerate(prim.v)]
                for f in prim.f:
                    f2 = tuple(reversed(f)) if back else f
                    face = bm.faces.new([bv[i] for i in f2])
                    for lp, vi in zip(face.loops, f2):
                        lp[uvl].uv = prim.uv[vi]
                        loop_normals.append(tuple(-prim.n[vi] if back else prim.n[vi]))
                sway_seq.extend(prim.sway)
        else:
            bv = [bm.verts.new(v) for v in prim.v]
            for f in prim.f:
                face = bm.faces.new([bv[i] for i in f])
                for lp, vi in zip(face.loops, f):
                    lp[uvl].uv = prim.uv[vi]
                    loop_normals.append(None)
            sway_seq.extend(prim.sway)
    bm.normal_update()
    smooth_normals = [tuple(v.normal) for v in bm.verts]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly in me.polygons:
        poly.use_smooth = True
    final = [tuple(n) if n is not None else smooth_normals[lp.vertex_index]
             for lp, n in zip(me.loops, loop_normals)]
    me.normals_split_custom_set(final)
    sway = me.color_attributes.new(name="Sway", type='FLOAT_COLOR', domain='POINT')
    for i, c in enumerate(sway_seq):
        sway.data[i].color = (c[0], c[1], c[2], 1.0)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material():
    mat = bpy.data.materials.get("MAT_FoliageMarine") or bpy.data.materials.new("MAT_FoliageMarine")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (420, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (120, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    directory = common.textures_dir("M_Veg_Eelgrass_Kit")
    alb = common.map_file(directory, "T_FoliageMarine_Main_ALB")
    if alb:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.location = (-260, 80)
        tex.image = bpy.data.images.load(alb, check_existing=True)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    rgh = common.map_file(directory, "T_FoliageMarine_Main_RGH")
    if rgh:
        tr = nt.nodes.new("ShaderNodeTexImage")
        tr.location = (-260, -180)
        tr.image = bpy.data.images.load(rgh, check_existing=True)
        tr.image.colorspace_settings.name = "Non-Color"
        nt.links.new(tr.outputs["Color"], bsdf.inputs["Roughness"])
    if hasattr(mat, "blend_method"):
        mat.blend_method = 'CLIP'
    return mat


def empty(name, location):
    e = bpy.data.objects.new(name, None)
    e.location = Vector(location)
    bpy.context.scene.collection.objects.link(e)
    return e


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def build():
    T.write_all()
    mat = material()
    meshes, atts, heights = [], [], []
    for k, variant in enumerate(VARIANTS):
        name = variant[0]
        prims = piece(variant)
        ob = make_mesh(name + "_LOD0", prims)
        ob.data.transform(Matrix.Diagonal((M, M, M, 1.0)))
        off = Vector((k * GRID, 0.0, 0.0))
        ob.data.transform(Matrix.Translation(off))
        ob.data.materials.append(mat)
        ob.data.update()
        meshes.append({"object": ob, "set": "Main", "lod": "LOD0"})
        hi = max(v.co.z for v in ob.data.vertices)
        heights.append(hi / M)
        lo = min(v.co.z for v in ob.data.vertices)
        assert abs(lo) < 1e-6, "%s dips below the sand: %.4f" % (name, lo)
        atts.append(empty("ATT_Base_%02d" % (k + 1), (k * GRID, 0.0, 0.0)))
        print("[M_Veg_Eelgrass_Kit] %s: %d tris, %.2f m tall" % (name, tris(ob), hi / M))
    total = sum(tris(m["object"]) for m in meshes)
    print("[M_Veg_Eelgrass_Kit] LOD0 total %d tris (kit ceiling %d)" % (total, KIT_TRIS))
    if total > KIT_TRIS:
        raise RuntimeError("kit over its own ceiling: %d > %d tris" % (total, KIT_TRIS))
    for m, v in zip(meshes, VARIANTS):
        if tris(m["object"]) > 300:
            raise RuntimeError("%s over 300 tris: %d" % (v[0], tris(m["object"])))

    height = round(max(heights), 2)
    return {
        "name": "M_Veg_Eelgrass_Kit",
        "budget": "vegetation",
        "tris": KIT_TRIS,
        "tier": "standard",
        "dims_m": (None, None, height),
        "origin": "free",
        "sets": [{"name": "FoliageMarine", "set": "Main", "size": T.SHIP, "wet": False}],
        "atlas": "FoliageMarine",
        "meshes": meshes,
        "attachments": atts,
        "waivers": {
            "LOD UV layout": "blade LODs collapse segments by design, so a LOD's UV layout differs from LOD0's; "
                             "every LOD samples the same eelgrass cell of the FoliageMarine atlas",
            "geometry": "collapse decimation orphans a few vertices at LOD1/LOD2 (they render nothing); "
                        "the LOD0 meshes have none",
        },
        "note": ("meadow kit, shallow water: five pieces on a 1.35 m display line, each base its own ground point. "
                 "Solid blades (two offset surfaces, true normals), no DoubleSided. Sway vertex colours on every "
                 "mesh: R weight, G phase, B stiffness. Atlas FoliageMarine cell u0.75..1.0 v0.75..1.0 (ours only)."),
        "closeups": [
            {"name": "eelgrass01_young", "target": [0.0, 0.0, 0.10 * M], "dist": 5.6, "az": 38, "el": 16},
            {"name": "eelgrass02_tuft", "target": [GRID, 0.0, 0.14 * M], "dist": 5.9, "az": 32, "el": 15},
            {"name": "eelgrass03_tall", "target": [2 * GRID, 0.0, 0.22 * M], "dist": 6.2, "az": 34, "el": 18},
            {"name": "eelgrass04_clump", "target": [3 * GRID, 0.0, 0.13 * M], "dist": 5.9, "az": 28, "el": 13},
            {"name": "eelgrass_patch", "target": [4 * GRID, 0.0, 0.06 * M], "dist": 4.6, "az": 40, "el": 20},
            {"name": "blade_tips", "target": [2 * GRID + 0.22 * M, 0.0, 0.52 * M], "dist": 3.0, "az": 14, "el": 22},
        ],
    }
