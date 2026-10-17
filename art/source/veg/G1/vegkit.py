"""G1 land vegetation builder (Blender; docs/12 2.5). One module, every variant; art/source/veg/<Asset>/build.py calls
vegkit.build("<Asset>"). Plants are alpha cards on the T_FoliageLand_Main atlas (atlas.py, cells.json) plus bark tubes.
Wind: the Gale Isles prevailing wind is south-westerly; every plant leans / is clipped towards Blender +X (leeward),
so the placer yaws it to the local wind. LODs are built from the same card list (rank cut + fewer segments), not by
decimation: LOD1 keeps about half the cards (wider), LOD2 about a quarter. Custom normals: clumps use a dome normal
(soft foliage shading on both faces, DoubleSided in Roblox), grass and fronds lean the normal towards up.
1 Blender unit = 1 stud (3 per metre)."""
import json, math, os, random
import bpy, bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
CELLS = json.load(open(os.path.join(HERE, "cells.json")))["cells"]
TEX_DIR = os.path.join(GAME, "assets/textures/M_Veg_FoliageLand")
M = 3.0  # studs per metre
WIND = Vector((1, 0, 0))

# asset -> (species, seed, target size metres x, y, z, docs/12 row ceiling, note)
VARIANTS = {
    "M_Veg_Grass_Turf_01": ("turf", 11, (0.45, 0.42, 0.22), 1500, "cliff-top turf tuft (red fescue / thrift turf)"),
    "M_Veg_Grass_Turf_02": ("turf", 12, (0.6, 0.55, 0.3), 1500, "taller tussock (cocksfoot / Yorkshire fog)"),
    "M_Veg_Grass_Marram_01": ("marram", 21, (0.9, 0.8, 0.8), 1500, "marram clump, back dune"),
    "M_Veg_Grass_Marram_02": ("marram", 22, (1.2, 1.0, 1.0), 1500, "big marram clump, dune crest, wind-combed"),
    "M_Veg_Gorse_01": ("gorse", 31, (1.6, 1.4, 1.2), 6000, "European gorse, wind-clipped cushion, flowering"),
    "M_Veg_Gorse_02": ("gorse", 32, (2.0, 1.7, 1.6), 6000, "big gorse bush, leeward streamer"),
    "M_Veg_Gorse_03": ("gorse", 33, (1.0, 0.9, 0.7), 6000, "low cliff-edge gorse, sparse flowers"),
    "M_Veg_Heather_01": ("ling", 41, (0.7, 0.6, 0.35), 2000, "ling (Calluna vulgaris) mound in flower"),
    "M_Veg_Heather_02": ("bell", 42, (0.55, 0.5, 0.3), 2000, "bell heather (Erica cinerea) clump"),
    "M_Veg_Heather_03": ("heathmix", 43, (0.9, 0.75, 0.4), 2000, "mixed ling + bell heather, wind-pruned"),
    "M_Veg_SeaThrift_01": ("thrift", 51, (0.3, 0.28, 0.24), 800, "sea thrift cushion with pink heads"),
    "M_Veg_SeaThrift_02": ("thrift", 52, (0.22, 0.2, 0.2), 800, "small thrift cushion on rock"),
    "M_Veg_Bracken_01": ("bracken", 61, (1.3, 1.2, 1.0), 6000, "bracken (Pteridium aquilinum), summer green"),
    "M_Veg_Bracken_02": ("bracken_russet", 62, (1.2, 1.1, 0.8), 6000, "bracken turning, autumn russet"),
    "M_Veg_Hawthorn_01": ("hawthorn", 71, (3.6, 2.6, 2.4), 6000, "wind-bent hawthorn, cliff hedge"),
    "M_Veg_Hawthorn_02": ("hawthorn", 72, (2.6, 2.0, 1.9), 6000, "small windswept hawthorn"),
}


def cell(name):
    return CELLS[name]


# ---------------------------------------------------------------------------------------------------- prims
class Card:
    """a bent quad strip: base point, up axis, side axis, size, wind bend, atlas cell; rank decides the LOD cut"""
    def __init__(self, base, up, side, w, h, cellname, segs=2, bend=0.0, bend_dir=None, rank=None, normal="dome",
                 horizontal=False, fold=0.0, rng=None):
        self.base, self.up, self.side = Vector(base), Vector(up).normalized(), Vector(side).normalized()
        self.w, self.h, self.cell, self.segs, self.bend = w, h, cellname, segs, bend
        self.bend_dir = Vector(bend_dir).normalized() if bend_dir is not None else WIND.copy()
        self.rank = rng.random() if rank is None else rank
        self.normal, self.horizontal, self.fold = normal, horizontal, fold


class Tube:
    def __init__(self, pts, radii, level, sides=6):
        self.pts, self.radii, self.level, self.sides = [Vector(p) for p in pts], radii, level, sides


def card_geo(c, lod):
    """vertices, faces, uvs for one card at a LOD"""
    segs = c.segs if lod == 0 else (max(1, c.segs - 1) if lod == 1 else max(1, c.segs // 2))
    widen = (1.0, 1.3, 1.6)[lod]
    u0, v0, u1, v1 = cell(c.cell)
    verts, uvs = [], []
    p, d = c.base.copy(), c.up.copy()
    step = c.h / segs
    pts = [p.copy()]
    dirs = [d.copy()]
    for i in range(segs):
        t = (i + 0.5) / segs
        d = (c.up + c.bend_dir * (c.bend * t * 1.6)).normalized()
        p = p + d * step
        pts.append(p.copy())
        dirs.append(d)
    hw = c.w * 0.5 * widen
    for i, q in enumerate(pts):
        t = i / segs
        fold = c.side.cross(dirs[i]).normalized() * (c.fold * hw)
        for s in (-1, 1):
            verts.append(q + c.side * (hw * s) + fold * (1 - 0) * (0 if c.fold == 0 else 1))
            if c.horizontal:  # frond cells run along u
                uvs.append((u0 + (u1 - u0) * t, v0 + (v1 - v0) * (0.5 + 0.5 * s)))
            else:
                uvs.append((u0 + (u1 - u0) * (0.5 + 0.5 * s), v0 + (v1 - v0) * t))
        if c.fold:  # V cross-section: the rachis line in the middle, lifted
            pass
    faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(segs)]
    return verts, faces, uvs


def tube_geo(t, lod):
    sides = max(3, t.sides - 2 * lod)
    u0, v0, u1, v1 = cell("Bark")
    verts, uvs, faces = [], [], []
    n = len(t.pts)
    total = sum((t.pts[i + 1] - t.pts[i]).length for i in range(n - 1)) or 1
    acc = 0.0
    for i, p in enumerate(t.pts):
        d = (t.pts[min(i + 1, n - 1)] - t.pts[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.95 else Vector((1, 0, 0))
        a = d.cross(ref).normalized()
        b = d.cross(a).normalized()
        if i > 0:
            acc += (t.pts[i] - t.pts[i - 1]).length
        for s in range(sides + 1):
            ang = 2 * math.pi * s / sides
            verts.append(p + (a * math.cos(ang) + b * math.sin(ang)) * t.radii[i])
            uvs.append((u0 + 0.004 + (u1 - u0 - 0.008) * s / sides, v0 + 0.004 + (v1 - v0 - 0.008) * min(1, acc / total)))
    for i in range(n - 1):
        for s in range(sides):
            a0 = i * (sides + 1) + s
            faces.append((a0, a0 + 1, a0 + sides + 2, a0 + sides + 1))
    return verts, faces, uvs


def make_mesh(name, prims, lod, centre, up_blend):
    """cards are emitted twice (front + reversed back face, separate verts) with the SAME hemisphere normal, so they
    light like one volume from either side (DoubleSided off in Roblox: no flipped back-face normals, no dark windward
    cards). Hemisphere ("foliage normal" transfer): normal = direction from a point below the plant's base centre,
    measured in the plant's own extents, blended towards +Z by up_blend; tubes keep smooth normals."""
    geo = []
    keep = (1.0, 0.5, 0.25)[lod]
    for pr in prims:
        if isinstance(pr, Card):
            if pr.rank > keep:
                continue
            geo.append((card_geo(pr, lod), pr.normal))
        else:
            if lod == 2 and pr.level > 1 or lod == 1 and pr.level > 2:
                continue
            geo.append((tube_geo(pr, lod), "tube"))
    allv = [v for (vs, fs, uvs), k in geo if k != "tube" for v in vs] or [Vector((0, 0, 0)), Vector((1, 1, 1))]
    lo = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
    hi = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
    ext = Vector((max(hi.x - lo.x, 1e-3) / 2, max(hi.y - lo.y, 1e-3) / 2, max(hi.z - lo.z, 1e-3)))
    hc = Vector((centre.x, centre.y, lo.z - 0.35 * ext.z))  # hemisphere centre: below the base

    def hemi(v, kind):
        d = v - hc
        d = Vector((d.x / ext.x, d.y / ext.y, d.z / (ext.z * 1.35)))
        d = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
        ub = up_blend if kind == "dome" else max(up_blend, 0.7)
        return (d * (1 - ub) + Vector((0, 0, 1)) * ub).normalized()

    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    loop_normals = []
    for (vs, fs, uvs), kind in geo:
        for back in ((False,) if kind == "tube" else (False, True)):
            bv = [bm.verts.new(v) for v in vs]
            for f in fs:
                f = tuple(reversed(f)) if back else f
                face = bm.faces.new([bv[i] for i in f])
                for lp, vi in zip(face.loops, f):
                    lp[uvl].uv = uvs[vi]
                    loop_normals.append(None if kind == "tube" else hemi(vs[vi], kind))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    final = []
    for poly in me.polygons:
        poly.use_smooth = True
    for i, lp in enumerate(me.loops):
        n = loop_normals[i] if i < len(loop_normals) else None
        final.append(tuple(n) if n is not None else tuple(me.vertex_normals[lp.vertex_index].vector))
    me.normals_split_custom_set(final)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------------------------------------------- species
def rand_dir_xy(rng):
    a = rng.uniform(0, 2 * math.pi)
    return Vector((math.cos(a), math.sin(a), 0))


def tuft(prims, rng, centre, n, radius, hmin, hmax, wcard, cellname, lean, splay, segs, bend, normal="up"):
    for k in range(n):
        d = rand_dir_xy(rng)
        r = radius * math.sqrt(rng.random())
        base = centre + d * r
        out = (d * (splay * (0.4 + r / max(radius, 1e-6))) + WIND * lean + Vector((0, 0, 1))).normalized()
        out = (out + Vector((rng.gauss(0, 0.12), rng.gauss(0, 0.12), 0))).normalized()
        q = rng.random()
        side = Vector((0, 0, 1)).cross(d).normalized() if q < 0.4 else (d.copy() if q < 0.75 else rand_dir_xy(rng))
        side = (side - out * side.dot(out)).normalized()
        h = rng.uniform(hmin, hmax)
        prims.append(Card(base, out, side, wcard * rng.uniform(0.8, 1.2), h, cellname, segs=segs,
                          bend=bend * rng.uniform(0.6, 1.3), rng=rng, normal=normal))


def dome_cards(prims, rng, centre, rx, ry, rz, n, size, cellname, segs=1, out_tilt=0.55, clip=0.0, shear=0.0,
               normal="dome", top_only=False, wmul=1.0, jitter=0.0):
    """cards on a wind-shaped ellipsoid: windward side clipped flat (clip), crown streamed leeward (shear)"""
    for k in range(n):
        while True:
            v = Vector((rng.gauss(0, 1), rng.gauss(0, 1), abs(rng.gauss(0, 1))))
            v.normalize()
            if not top_only or v.z > 0.25:
                break
        p = Vector((v.x * rx, v.y * ry, v.z * rz))
        if v.x < 0:
            p.x *= (1 - clip)          # windward face cut back by the salt wind
        p.x += shear * p.z / max(rz, 1e-6) * rx  # crown streams leeward
        n_out = Vector((v.x / rx, v.y / ry, v.z / rz)).normalized()
        up = (n_out * out_tilt + Vector((0, 0, 1)) * (1 - out_tilt) + WIND * 0.15).normalized()
        if jitter:
            up = (up + Vector((rng.gauss(0, jitter), rng.gauss(0, jitter), rng.gauss(0, jitter * 0.5)))).normalized()
        side = up.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.2))).normalized()
        if side.length < 0.1:
            side = Vector((1, 0, 0))
        base = centre + p - up * size * 0.45
        prims.append(Card(base, up, side, size * rng.uniform(0.8, 1.2) * wmul, size * rng.uniform(0.8, 1.15),
                          cellname, segs=segs, bend=0.15, rng=rng, normal=normal))


def branchy(prims, rng, start, d, length, radius, level, max_level, leaves, leaf_size, ends):
    pts, radii = [start.copy()], [radius]
    p = start.copy()
    segs = 5 if level == 0 else 3
    for i in range(segs):
        d = (d + WIND * (0.18 if level else 0.12) + Vector((rng.gauss(0, 0.25), rng.gauss(0, 0.25), rng.gauss(0, 0.15)))).normalized()
        p = p + d * (length / segs)
        pts.append(p.copy())
        radii.append(radius * (1 - 0.65 * (i + 1) / segs))
    prims.append(Tube(pts, radii, level, sides=7 if level == 0 else 5))
    if level < max_level:
        for i in range(1, len(pts)):
            if rng.random() < (0.75 if level == 0 else 0.6):
                nd = (d + Vector((rng.gauss(0, 0.8), rng.gauss(0, 0.8), rng.uniform(-0.1, 0.6)))).normalized()
                branchy(prims, rng, pts[i], nd, length * rng.uniform(0.45, 0.7), radii[i] * 0.7, level + 1, max_level,
                        leaves, leaf_size, ends)
    else:
        ends.append(pts[-1])


def species(kind, rng):
    prims, centre, up_blend = [], Vector((0, 0, 0)), 0.35
    if kind == "turf":
        tuft(prims, rng, centre, 72, 0.55, 0.45, 1.0, 0.55, "Turf", 0.12, 0.6, 3, 0.35)
        for k in range(12):  # crossed short core cards at varied yaw fill the tuft's middle
            a = rng.uniform(0, math.pi)
            for s2 in (0, math.pi / 2):
                prims.append(Card(centre + rand_dir_xy(rng) * rng.uniform(0, 0.2), (Vector((0, 0, 1)) + WIND * 0.1).normalized(),
                                  Vector((math.cos(a + s2), math.sin(a + s2), 0)), 0.5, rng.uniform(0.35, 0.6), "Turf", segs=2,
                                  bend=0.2, rng=rng))
        up_blend = 0.55
    elif kind == "marram":
        tuft(prims, rng, centre, 46, 0.9, 1.6, 2.7, 0.75, "Marram", 0.35, 0.45, 5, 0.75)
        for k in range(8):  # spent dead blades lying over at the base
            d = rand_dir_xy(rng)
            prims.append(Card(centre + d * rng.uniform(0, 0.6), (d * 1.2 + WIND * 0.6 + Vector((0, 0, 0.5))).normalized(),
                              Vector((0, 0, 1)).cross(d), 0.6, rng.uniform(1.0, 1.6), "Marram", segs=3, bend=0.9, rng=rng, rank=rng.uniform(0.3, 1)))
        up_blend = 0.55
    elif kind == "gorse":
        for k in range(9):  # woody stems, grey-brown, from a few rootstocks
            d = (Vector((rng.gauss(0, 0.5), rng.gauss(0, 0.5), 1)) + WIND * 0.4).normalized()
            pts = [Vector((rng.gauss(0, 0.3), rng.gauss(0, 0.3), -0.05))]
            for i in range(3):
                pts.append(pts[-1] + (d + Vector((rng.gauss(0, 0.2), rng.gauss(0, 0.2), 0))).normalized() * rng.uniform(0.7, 1.1))
            prims.append(Tube(pts, [0.12, 0.09, 0.06, 0.03], 1 if k > 2 else 0, sides=5))
        rx, ry, rz = 2.4, 2.1, 3.0
        dome_cards(prims, rng, Vector((0, 0, 0.2)), rx * 0.7, ry * 0.7, rz * 0.7, 140, 1.7, "GorseDense", segs=1, clip=0.3, shear=0.2,
                   jitter=0.4)
        dome_cards(prims, rng, Vector((0, 0, 0.2)), rx, ry, rz, 320, 1.45, "GorseDense", segs=1, clip=0.35, shear=0.28, jitter=0.35)
        dome_cards(prims, rng, Vector((0, 0, 0.2)), rx * 1.05, ry * 1.05, rz * 1.05, 280, 1.5, "GorseSprig", segs=2, out_tilt=0.8,
                   clip=0.35, shear=0.3, wmul=2.0, jitter=0.25)
        dome_cards(prims, rng, Vector((0, 0, 0.2)), rx * 1.1, ry * 1.1, rz * 1.08, 220, 1.2, "GorseSprig", segs=1, out_tilt=0.5,
                   clip=0.35, shear=0.3, wmul=1.6, jitter=0.9)  # sprigs poking out at random angles break the shell
        up_blend = 0.3
    elif kind in ("ling", "bell", "heathmix"):
        cells = {"ling": ["Ling"], "bell": ["BellHeather"], "heathmix": ["Ling", "Ling", "BellHeather"]}[kind]
        for k in range(230):
            v = Vector((rng.gauss(0, 1), rng.gauss(0, 1), abs(rng.gauss(0, 0.6)))).normalized()
            base = Vector((v.x * 1.0, v.y * 0.9, 0)) * math.sqrt(rng.random())
            up = (Vector((base.x * 0.6, base.y * 0.6, 1.0)) + WIND * 0.25).normalized()
            side = Vector((0, 0, 1)).cross(rand_dir_xy(rng)).normalized()
            h = rng.uniform(0.6, 1.1) * (1.0 - 0.45 * base.length)
            prims.append(Card(base, up, side, rng.uniform(0.55, 0.8), h, rng.choice(cells), segs=2, bend=0.3, rng=rng, normal="dome"))
        up_blend = 0.45
    elif kind == "thrift":
        dome_cards(prims, rng, Vector((0, 0, -0.05)), 0.45, 0.42, 0.3, 74, 0.32, "ThriftCushion", segs=2, out_tilt=0.75, normal="dome", top_only=True,
                   jitter=0.3)
        for k in range(10):
            d = rand_dir_xy(rng) * rng.uniform(0, 0.25)
            up = (Vector((d.x, d.y, 1)) + WIND * 0.15).normalized()
            for s in range(2):  # crossed pair per head stalk card
                side = Vector((math.cos(k + s * 1.57), math.sin(k + s * 1.57), 0))
                prims.append(Card(Vector((d.x, d.y, 0)), up, side, 0.42, 0.62 * rng.uniform(0.8, 1.15), "ThriftHeads",
                                  segs=2, bend=0.1, rng=rng, rank=(k / 10.0) * 0.9, normal="dome"))
        up_blend = 0.5
    elif kind in ("bracken", "bracken_russet"):
        n = 32
        for k in range(14):  # low skirt: short stipes, fronds arching out near the ground (fills the dark cone)
            d = rand_dir_xy(rng)
            base = d * rng.uniform(0, 0.4)
            top = base + (d * 0.5 + Vector((0, 0, 1))).normalized() * rng.uniform(0.2, 0.55)
            out = (d + Vector((0, 0, rng.uniform(0.3, 0.7))) + WIND * 0.2).normalized()
            cellname = "BrackenGreen" if kind == "bracken" or rng.random() < 0.15 else "BrackenRusset"
            prims.append(Card(top, out, Vector((0, 0, 1)).cross(out).normalized(), rng.uniform(0.8, 1.05), rng.uniform(1.1, 1.6),
                              cellname, segs=4, bend=-0.5, bend_dir=Vector((0, 0, 1)), rng=rng, rank=rng.uniform(0.2, 1.0),
                              horizontal=True, normal="up"))
        for k in range(6):  # young upright fronds in the middle
            a = rng.uniform(0, 2 * math.pi)
            up = (Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 1)) + WIND * 0.15).normalized()
            cellname = "BrackenGreen" if kind == "bracken" or rng.random() < 0.3 else "BrackenRusset"
            prims.append(Card(Vector((math.cos(a), math.sin(a), 0)) * 0.15, up, Vector((-math.sin(a), math.cos(a), 0)),
                              rng.uniform(0.8, 1.0), rng.uniform(1.4, 1.9), cellname, segs=4, bend=0.3, rng=rng,
                              rank=rng.uniform(0.3, 1.0), horizontal=True, normal="up"))
        for k in range(n):
            d = rand_dir_xy(rng)
            base = d * rng.uniform(0, 0.9)
            lean = (d * 0.6 + Vector((0, 0, 1)) + WIND * 0.25).normalized()
            stipe_h = rng.uniform(0.5, 1.6)
            top = base + lean * stipe_h
            prims.append(Tube([base, base + lean * stipe_h * 0.5, top], [0.035, 0.03, 0.022], 1, sides=4))
            # the blade arches out and over, near horizontal: a horizontal-UV strip from the stipe top
            out = (d * 1.0 + Vector((0, 0, rng.uniform(0.1, 0.5))) + WIND * 0.2).normalized()
            side = Vector((0, 0, 1)).cross(out).normalized()
            cellname = "BrackenGreen" if kind == "bracken" or rng.random() < 0.2 else "BrackenRusset"
            prims.append(Card(top, out, side, rng.uniform(0.9, 1.25), rng.uniform(1.6, 2.2), cellname, segs=5,
                              bend=-0.55 if kind == "bracken" else -0.8, bend_dir=Vector((0, 0, 1)), rng=rng,
                              rank=(k / n) if k % 2 else rng.uniform(0.3, 1.0),
                              horizontal=True, normal="up"))
        up_blend = 0.6
    elif kind == "hawthorn":
        ends = []
        trunk_dir = (Vector((0, 0, 1)) + WIND * 0.9).normalized()   # bent hard leeward
        branchy(prims, rng, Vector((0, 0, -0.1)), trunk_dir, 4.5, 0.42, 0, 3, None, 1.0, ends)
        for e in ends:  # leaf clusters stream leeward, flattened on the windward side
            for k in range(rng.randint(14, 20)):
                off = Vector((rng.gauss(0.35, 0.6), rng.gauss(0, 0.6), rng.gauss(0.1, 0.35)))
                up = (Vector((rng.gauss(0, 0.5), rng.gauss(0, 0.5), 1)) + WIND * 0.4).normalized()
                side = up.cross(rand_dir_xy(rng)).normalized()
                prims.append(Card(e + off - up * 0.5, up, side, 1.15 * rng.uniform(0.8, 1.2), 1.15 * rng.uniform(0.8, 1.2),
                                  "HawthornLeaves", segs=1, bend=0.1, rng=rng, normal="dome"))
        centre = Vector((1.8, 0, 1.2))
        up_blend = 0.3
    return prims, centre, up_blend


# ---------------------------------------------------------------------------------------------------- build
def material():
    mat = bpy.data.materials.get("MAT_FoliageLand") or bpy.data.materials.new("MAT_FoliageLand")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    alb = os.path.join(TEX_DIR, "T_FoliageLand_Main_ALB.png")
    if bsdf and os.path.exists(alb) and not any(n.type == "TEX_IMAGE" for n in nt.nodes):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(alb, check_existing=True)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    return mat


def build(asset):
    kind, seed, dims, row_tris, note = VARIANTS[asset]
    rng = random.Random(seed)
    prims, centre, up_blend = species(kind, rng)
    obs = [make_mesh("%s_LOD%d" % (asset, lod), prims, lod, centre, up_blend) for lod in range(3)]
    # fit LOD0 to the target size (metres -> studs), base-centred origin; same transform on every LOD
    xs = [v.co for v in obs[0].data.vertices]
    lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
    hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
    size = hi - lo
    sc = Vector((dims[0] * M / size.x, dims[1] * M / size.y, dims[2] * M / size.z))
    mid = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    mat = material()
    for ob in obs:
        ob.data.transform(Matrix.Translation(-mid))
        ob.data.transform(Matrix.Diagonal((sc.x, sc.y, sc.z, 1)))
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        ob.data.update()
    set_entry = {"name": "FoliageLand", "set": "Main", "size": 2048, "wet": True, "dir": TEX_DIR}
    spec = {
        "name": asset, "budget": "vegetation", "tris": row_tris, "tier": "standard",
        "dims_m": dims, "size_note": None, "origin": "base",
        "sets": [set_entry], "atlas": "FoliageLand",
        "meshes": [{"object": ob, "set": "Main"} for ob in obs],
        "waivers": {"LOD UV layout": "card LODs drop cards by design (docs/12 2.5: cards reduce at distance); same atlas cells, LOD1 ~50% / LOD2 ~25% of the cards, widened"},
        "note": note, "kind": kind,
        "closeups": [{"name": "crown", "target": [0, 0, dims[2] * M * 0.8], "dist": max(2.0, dims[2] * M * 1.2), "az": 35, "el": 20}],
    }
    return spec
