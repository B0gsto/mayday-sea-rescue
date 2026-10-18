"""Strand-line debris builder (Blender; G1 veg pipeline): tiny flat scatter assets for the high-tide wrack line.
art/source/veg/<Asset>/build.py calls strandkit.build("<Asset>"). All four share the T_StrandLine_Main atlas
(atlas.py, cells.json; Appearances folder M_Veg_StrandLine via AssetLoader.SHARED_SETS).
Shells and pebbles are solid low-poly shells with top-projected UVs, driftwood a lumpy tube with abraded end caps,
wrack overlapping alpha strips lying flat (front + back face, up-leaning normals like vegkit's cards).
LODs are rebuilt from the same random shape functions at lower resolution (fewer rim / ring vertices, small pieces
dropped), not decimated. Authored in metres at real size, then 1 Blender unit = 1 stud (3 per metre), origin at the
centre of the base."""
import json, math, os, random
import bpy, bmesh
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
CELLS = json.load(open(os.path.join(HERE, "cells.json")))["cells"]
TEX_DIR = os.path.join(GAME, "assets/textures/M_Veg_StrandLine")
M = 3.0  # studs per metre
ROW_TRIS = 400

# asset -> (kind, seed, note)
VARIANTS = {
    "M_Veg_Strand_Shells_01": ("shells", 81, "broken cockle and mussel shells, strand line"),
    "M_Veg_Strand_Wrack_01": ("wrack", 82, "dried bladderwrack / serrated wrack clump lying flat"),
    "M_Veg_Strand_Driftwood_01": ("drift", 83, "sun-bleached driftwood stick"),
    "M_Veg_Strand_Pebbles_01": ("pebbles", 84, "cluster of flat rounded beach pebbles"),
}


def uv(cell, s, t, m=0.01):
    """s across the cell image left -> right, t top -> bottom (0..1) -> atlas UV (v up)"""
    u0, v0, u1, v1 = CELLS[cell]
    s, t = min(1 - m, max(m, s)), min(1 - m, max(m, t))
    return (u0 + (u1 - u0) * s, v1 - (v1 - v0) * t)


class Part:
    """verts (metres), faces (index tuples), per-vertex uvs, kind 'solid' | 'card', flat face indices"""
    def __init__(self, kind="solid"):
        self.v, self.f, self.uv, self.kind, self.flat = [], [], [], kind, set()

    def add(self, p, st):
        self.v.append(Vector(p))
        self.uv.append(st)
        return len(self.v) - 1


def harmonics(rng, n=3, amp=0.08):
    hs = [(k + 2, rng.uniform(0, 2 * math.pi), amp * rng.uniform(0.3, 1.0) / (k + 1)) for k in range(n)]
    return lambda a: 1 + sum(h * math.cos(k * a + ph) for k, ph, h in hs)


def place(part, yaw, tilt, at):
    rot = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(tilt[0], 3, "X") @ Matrix.Rotation(tilt[1], 3, "Y")
    part.v = [rot @ p for p in part.v]
    zmin = min(p.z for p in part.v)
    part.v = [p + Vector((at[0], at[1], at[2] - zmin)) for p in part.v]
    return part


# ---------------------------------------------------------------------------------------------------- shells
def shell_spec(rng, R, elong, concave, top, side):
    rim = harmonics(rng, 3, 0.1)
    brk = rng.uniform(0, 2 * math.pi)
    depth = rng.uniform(0.25, 0.45) if rng.random() < 0.8 else 0.0  # broken-off sector
    width = rng.uniform(0.5, 0.9)

    def radius(a):
        d = abs(math.atan2(math.sin(a - brk), math.cos(a - brk)))
        return rim(a) * (1 - depth * max(0.0, 1 - d / width) ** 1.5)
    return dict(R=R, elong=elong, concave=concave, top=top, side=side, radius=radius,
                h=R * rng.uniform(0.38, 0.5), yaw=rng.uniform(0, 2 * math.pi),
                tilt=(rng.gauss(0, 0.12), rng.gauss(0, 0.12)), a0=rng.uniform(0, 2 * math.pi))


def shell_part(sp, lod):
    n = (8, 6, 5)[lod]
    rings = (0.55, 1.0) if lod == 0 else (1.0,)
    skirt = lod < 2
    R, el, h = sp["R"], sp["elong"], sp["h"]
    thick = 0.0015
    p = Part()

    def z(t):
        return (h * 0.6 * t * t + 0.002) if sp["concave"] else (h * (1 - t * t) + thick)

    def xy(a, t):
        r = sp["radius"](a) * t
        return (math.cos(a) * r * R * el, math.sin(a) * r * R)

    def st(x, y, cell):
        return uv(cell, 0.5 + 0.45 * x / (R * el * 1.12), 0.5 + 0.45 * y / (R * 1.12))
    apex = p.add((0, 0, z(0)), st(0, 0, sp["top"]))
    angs = [sp["a0"] + 2 * math.pi * k / n for k in range(n)]
    ringidx = []
    for t in rings:
        row = []
        for a in angs:
            x, y = xy(a, t)
            row.append(p.add((x, y, z(t)), st(x, y, sp["top"])))
        ringidx.append(row)
    for k in range(n):
        p.f.append((apex, ringidx[0][k], ringidx[0][(k + 1) % n]))
    for r0, r1 in zip(ringidx, ringidx[1:]):
        for k in range(n):
            k1 = (k + 1) % n
            p.f.append((r0[k], r1[k], r1[k1], r0[k1]))
    if skirt:  # the broken edge / outer wall down to the sand (own verts: a hard edge at the rim)
        top_row, bot_row = [], []
        for a in angs:
            x, y = xy(a, 1.0)
            top_row.append(p.add((x, y, z(1.0)), st(x, y, sp["side"])))
            k = 0.82 if sp["concave"] else 1.03
            bot_row.append(p.add((x * k, y * k, 0.0), st(x * k, y * k, sp["side"])))
        for k in range(n):
            k1 = (k + 1) % n
            p.f.append((top_row[k], bot_row[k], bot_row[k1], top_row[k1]))
    return place(p, sp["yaw"], sp["tilt"], (0, 0, 0))


def shells(rng, lod):
    plan = [  # (half-width m, elongation, concave-up, top cell, side cell)
        (0.016, 1.0, False, "CockleOut", "CockleOut"), (0.013, 1.05, False, "CockleOut", "CockleOut"),
        (0.014, 1.0, True, "CockleIn", "CockleOut"),
        (0.009, 2.1, False, "MusselOut", "MusselOut"), (0.008, 2.0, False, "MusselOut", "MusselOut"),
        (0.0085, 2.0, True, "MusselIn", "MusselOut"),
        (0.006, 1.2, False, "CockleOut", "CockleOut"), (0.005, 1.6, False, "MusselOut", "MusselOut"),
    ]
    specs, spots = [], []
    for R, el, cc, top, side in plan:
        sp = shell_spec(rng, R, el, cc, top, side)
        for tries in range(200):
            x, y = rng.gauss(0, 0.022), rng.gauss(0, 0.02)
            if all(math.hypot(x - qx, y - qy) > 0.75 * (R * el + qr) for qx, qy, qr in spots):
                break
        spots.append((x, y, R * el))
        sp["at"] = (x, y)
        specs.append(sp)
    keep = specs if lod < 2 else sorted(specs, key=lambda s: -s["R"] * s["elong"])[:5]
    parts = []
    for sp in keep:
        pt = shell_part(sp, lod)
        pt.v = [v + Vector((sp["at"][0], sp["at"][1], 0)) for v in pt.v]
        parts.append(pt)
    return parts


# ---------------------------------------------------------------------------------------------------- pebbles
def pebbles(rng, lod):
    stones = ["Granite"] * 7 + ["Slate"] * 6 + ["Quartz"] * 3 + ["Sandstone"] * 4
    sizes = [0.03, 0.026, 0.022, 0.019, 0.016, 0.014, 0.012]
    specs, spots = [], []
    for a in sizes:
        b = a * rng.uniform(0.62, 0.88)
        c = b * rng.uniform(0.38, 0.58)
        for tries in range(300):
            x, y = rng.uniform(-0.075, 0.075), rng.uniform(-0.06, 0.06)
            if all(math.hypot(x - qx, y - qy) > 0.92 * (a + qa) for qx, qy, qa in spots):
                break
        spots.append((x, y, a))
        sc = rng.uniform(0.3, 0.42)
        specs.append(dict(a=a, b=b, c=c, at=(x, y), yaw=rng.uniform(0, math.pi * 2), cell=rng.choice(stones),
                          rim=harmonics(rng, 3, 0.06), p=rng.uniform(2.2, 2.8), uvrot=rng.uniform(0, 2 * math.pi),
                          uvs=sc, uvo=(rng.uniform(-1, 1) * (0.47 - sc), rng.uniform(-1, 1) * (0.47 - sc)),
                          a0=rng.uniform(0, 2 * math.pi)))
    keep = specs if lod < 2 else specs[:5]
    parts = []
    for i, sp in enumerate(keep):
        n = (10 if i < 3 else 8) if lod == 0 else (7 if lod == 1 else 5)
        rings = (0.55, 0.88, 1.0) if lod == 0 else ((0.6, 1.0) if lod == 1 else (0.7, 1.0))
        pt = Part()
        cr, sr = math.cos(sp["uvrot"]), math.sin(sp["uvrot"])

        def st(nx, ny):
            rx, ry = nx * cr - ny * sr, nx * sr + ny * cr
            return uv(sp["cell"], 0.5 + sp["uvo"][0] + rx * sp["uvs"], 0.5 + sp["uvo"][1] + ry * sp["uvs"])

        def z(t):
            return sp["c"] * max(0.0, 1 - t ** sp["p"]) ** (1 / sp["p"])
        apex = pt.add((0, 0, z(0)), st(0, 0))
        angs = [sp["a0"] + 2 * math.pi * k / n for k in range(n)]
        rows = []
        for t in rings:
            row = []
            for ang in angs:
                r = sp["rim"](ang) * t
                nx, ny = math.cos(ang) * r, math.sin(ang) * r
                row.append(pt.add((nx * sp["a"], ny * sp["b"], z(t)), st(nx, ny)))
            rows.append(row)
        for k in range(n):
            pt.f.append((apex, rows[0][k], rows[0][(k + 1) % n]))
        for r0, r1 in zip(rows, rows[1:]):
            for k in range(n):
                k1 = (k + 1) % n
                pt.f.append((r0[k], r1[k], r1[k1], r0[k1]))
        place(pt, sp["yaw"], (0, 0), (sp["at"][0], sp["at"][1], 0))
        parts.append(pt)
    return parts


# ---------------------------------------------------------------------------------------------------- driftwood
def tube(pt, pts, radii, sides, cell, cap_cells, a0=-math.pi / 2, oval=None, s_len=1.0):
    """lumpy tube along pts; UV s along the length (cell image x), t around (image y); caps fan to a domed centre"""
    n = len(pts)
    total = sum((pts[i + 1] - pts[i]).length for i in range(n - 1)) or 1
    acc, rows = 0.0, []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = d.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-6 else Vector((0, 1, 0))
        up = side.cross(d).normalized()
        if i > 0:
            acc += (pts[i] - pts[i - 1]).length
        row = []
        for k in range(sides + 1):
            ang = a0 + 2 * math.pi * k / sides
            r = radii[i] * (oval(ang) if oval else 1.0)
            row.append(pt.add(p + (side * math.cos(ang) + up * math.sin(ang)) * r, uv(cell, acc / total * s_len, k / sides)))
        rows.append((row, d))
    for (r0, _), (r1, _) in zip(rows, rows[1:]):
        for k in range(sides):
            pt.f.append((r0[k], r0[k + 1], r1[k + 1], r1[k]))
    for end, (row, d), cc in ((0, rows[0], cap_cells[0]), (n - 1, rows[-1], cap_cells[1])):
        if cc is None:
            continue
        sgn = -1 if end == 0 else 1
        centre = pt.add(pts[end] + d * sgn * radii[end] * 0.35, uv(cc, 0.5, 0.5))
        ring = []
        for k in range(sides):
            ang = 2 * math.pi * k / sides
            ring.append(pt.add(pt.v[row[k]].copy(), uv(cc, 0.5 + 0.44 * math.cos(ang), 0.5 + 0.44 * math.sin(ang))))
        for k in range(sides):
            f = (centre, ring[k], ring[(k + 1) % sides]) if end == 0 else (centre, ring[(k + 1) % sides], ring[k])
            pt.f.append(f)
            pt.flat.add(len(pt.f) - 1)


def drift(rng, lod):
    L = 0.68
    bow, kink_ph, kink = rng.uniform(0.025, 0.04), rng.uniform(0, 6.28), rng.uniform(0.006, 0.012)
    lumps = [(rng.uniform(3, 9), rng.uniform(0, 6.28), rng.uniform(0.03, 0.08)) for _ in range(3)]
    oval = harmonics(rng, 2, 0.07)

    def radius(t):
        return 0.021 * (1 - 0.32 * t) * (1 + sum(a * math.sin(f * t + ph) for f, ph, a in lumps))

    def centre(t):
        x = (t - 0.5) * L
        y = bow * math.sin(math.pi * t) + kink * math.sin(2 * math.pi * 2.3 * t + kink_ph)
        lift = 0.005 * math.sin(math.pi * t) ** 2
        return Vector((x, y, radius(t) + lift))
    sides, nr = ((10, 10), (7, 6), (5, 3))[lod]
    ts = [i / (nr - 1) for i in range(nr)]
    pt = Part()
    tube(pt, [centre(t) for t in ts], [radius(t) for t in ts], sides, "DriftA", ("DriftEnd", "DriftEnd2"), oval=oval)
    if lod < 2:  # broken side branch, lying almost flat, rooted inside the stick
        t0 = 0.3
        base = centre(t0)
        d = Vector((0.45, 0.88, 0.0)).normalized()
        ln = 0.085
        k = (3, 2)[lod]
        pts = [base + d * (ln * i / (k - 1)) + Vector((0, 0, -0.004 * i)) for i in range(k)]
        tube(pt, pts, [0.011, 0.0095, 0.008][:k] if k == 3 else [0.011, 0.008], (6, 5)[lod], "DriftStub", (None, "DriftEnd2"),
             s_len=0.6)
    if lod == 0:  # knot stub near the thin end
        base = centre(0.78)
        d = Vector((-0.2, -0.95, 0.25)).normalized()
        tube(pt, [base, base + d * 0.03], [0.008, 0.0065], 5, "DriftStub", (None, "DriftEnd"), s_len=0.25)
    return [pt]


# ---------------------------------------------------------------------------------------------------- wrack
def wrack(rng, lod):
    specs = []
    for k in range(7):
        Lf = rng.uniform(0.24, 0.4) if k else 0.42
        specs.append(dict(L=Lf, W=Lf * 0.5, at=(rng.gauss(0, 0.07), rng.gauss(0, 0.05)),
                          yaw=rng.gauss(0, 0.55) + (math.pi if rng.random() < 0.5 else 0), z0=0.003 + 0.0035 * k,
                          cell="WrackA" if k % 3 != 2 else "WrackB", mirror=rng.random() < 0.5,
                          bump=(rng.uniform(-0.3, 0.3), rng.uniform(0.006, 0.014), rng.uniform(0.06, 0.12)),
                          curl=rng.uniform(0.004, 0.012), cross=rng.uniform(-0.005, 0.006), ph=rng.uniform(0, 6.28)))
    keep = specs if lod < 2 else sorted(specs, key=lambda s: -s["L"])[:4]
    segs, cols = ((5, 2), (3, 1), (2, 1))[lod]
    parts = []
    for sp in keep:
        pt = Part("card")
        Lf, W = sp["L"], sp["W"]
        bx, bh, bw = sp["bump"]

        def z(s, t):
            x = (s - 0.5) * Lf
            return (sp["z0"] + bh * math.exp(-((x - bx * Lf) / (bw * Lf * 2)) ** 2)
                    + sp["curl"] * abs(2 * s - 1) ** 3 + sp["cross"] * (2 * t - 1) ** 2
                    + 0.002 * math.sin(6 * s + sp["ph"]))
        idx = {}
        for i in range(segs + 1):
            for j in range(cols + 1):
                s, t = i / segs, j / cols
                idx[i, j] = pt.add(((s - 0.5) * Lf, (t - 0.5) * W, z(s, t)),
                                   uv(sp["cell"], s, (1 - t) if sp["mirror"] else t, 0.004))
        for i in range(segs):
            for j in range(cols):
                pt.f.append((idx[i, j], idx[i + 1, j], idx[i + 1, j + 1], idx[i, j + 1]))
        rot = Matrix.Rotation(sp["yaw"], 3, "Z")
        pt.v = [rot @ p + Vector((sp["at"][0], sp["at"][1], 0)) for p in pt.v]
        parts.append(pt)
    return parts


KINDS = {"shells": shells, "pebbles": pebbles, "drift": drift, "wrack": wrack}


# ---------------------------------------------------------------------------------------------------- build
def make_mesh(name, parts):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    loop_n, flat = [], []
    for pt in parts:
        for back in ((False, True) if pt.kind == "card" else (False,)):
            bv = [bm.verts.new(v) for v in pt.v]
            for fi, f in enumerate(pt.f):
                f2 = tuple(reversed(f)) if back else f
                face = bm.faces.new([bv[i] for i in f2])
                flat.append(fi in pt.flat)
                if pt.kind == "card":  # front-face normal turned up, the same on both faces (vegkit cards)
                    a, b, c = (pt.v[i] for i in f[:3])
                    gn = (b - a).cross(c - a).normalized()
                    if gn.z < 0:
                        gn = -gn
                    nn = (gn * 0.35 + Vector((0, 0, 1)) * 0.65).normalized()
                for lp, vi in zip(face.loops, f2):
                    lp[uvl].uv = pt.uv[vi]
                    loop_n.append(tuple(nn) if pt.kind == "card" else None)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly, fl in zip(me.polygons, flat):
        poly.use_smooth = not fl
    me.update()
    if any(n is not None for n in loop_n):
        me.normals_split_custom_set([n if n is not None else (0, 0, 1) for n in loop_n])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material():
    mat = bpy.data.materials.get("MAT_StrandLine") or bpy.data.materials.new("MAT_StrandLine")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    alb = os.path.join(TEX_DIR, "T_StrandLine_Main_ALB.png")
    if bsdf and os.path.exists(alb) and not any(n.type == "TEX_IMAGE" for n in nt.nodes):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(alb, check_existing=True)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    return mat


def sig3(x):
    return float("%.3g" % x)


def build(asset):
    kind, seed, note = VARIANTS[asset]
    obs = []
    for lod in range(3):
        parts = KINDS[kind](random.Random(seed), lod)  # same seed per LOD: the same pieces, coarser
        obs.append(make_mesh("%s_LOD%d" % (asset, lod), parts))
    xs = [v.co for v in obs[0].data.vertices]
    lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
    hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
    dims = tuple(sig3(d) for d in (hi - lo))  # real size in metres, measured from the built LOD0
    mid = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    mat = material()
    for ob in obs:
        ob.data.transform(Matrix.Diagonal((M, M, M, 1)) @ Matrix.Translation(-mid))
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        ob.data.update()
    set_entry = {"name": "StrandLine", "set": "Main", "size": 1024, "wet": True, "dir": TEX_DIR}
    return {
        "name": asset, "budget": "vegetation", "tris": ROW_TRIS, "tier": "standard",
        "dims_m": dims, "size_note": None, "origin": "base",
        "sets": [set_entry], "atlas": "StrandLine",
        "meshes": [{"object": ob, "set": "Main"} for ob in obs],
        "waivers": {"LOD UV layout": "LODs are rebuilt from the same shape functions at lower resolution (pieces dropped), same atlas cells"},
        "note": note, "kind": kind,
        "closeups": [{"name": "top", "target": [0, 0, dims[2] * M * 0.5], "dist": max(1.0, max(dims) * M * 1.5), "az": 35, "el": 45}],
    }
