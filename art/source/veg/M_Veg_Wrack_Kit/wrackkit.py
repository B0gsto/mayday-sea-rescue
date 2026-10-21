"""M_Veg_Wrack_Kit geometry (Blender; docs/12 2.5, batch S2). Four intertidal wrack mats that drape over rock and
cliff tops in the splash zone: two bladder wrack mats (Fucus vesiculosus: forked straps, paired round air
bladders), an egg wrack mat (Ascophyllum nodosum: long straps with single egg-shaped pods) and a flat decal mat
for ledges and pool rims. Each variant is its own mesh on the kit's display line (RESULT.md has the Roblox
offsets) and lies on its own rock-hugging shell: a low, lobed, tilted dome with an encrusted skirt, a crown of
holdfast cards, wrack fronds draped over the dome and past its rim, a fringe of straps hanging over the edge, and
modelled vesicles (paired bladders / egg pods) placed where wrack_tex.py paints them (wrack_lib.VESICLES via
wrack_lib.strap_hw, so paint and geometry line up).

Cards are thin bent strips (a front and a reversed back face sharing one up-leaning normal: vegkit's convention,
so Roblox never shows flipped-back-face shading), textured by the painted alpha and the cell's normal map. Authored
in metres, 1 Blender unit = 1 stud (3 per metre); LOD1 / LOD2 come from the `lod` step's decimation.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "../../../tools/blender"))
import common  # noqa: E402
import wrack_lib as L  # noqa: E402

M = L.M                                   # studs per metre
ROW_TRIS = 6000                           # docs/12 2.5: 500..2000 per mat, four mats in the kit (class cap 6000)

VARIANTS = {
    "M_Veg_Wrack_Bladder_01": dict(kind="Bladder", seed=201, R=0.45, H=0.16, fronds=(14, 9, 2), fringe=12,
                                   crown=8, sectors=20,
                                   note="bladder wrack mat for a rock boss or ledge top, 0.85 m across"),
    "M_Veg_Wrack_Bladder_02": dict(kind="Bladder", seed=202, R=0.58, H=0.19, fronds=(16, 10, 2), fringe=13,
                                   crown=10, sectors=20,
                                   note="large bladder wrack mat draped over a boulder, 1.15 m across"),
    "M_Veg_Wrack_Egg_01": dict(kind="Egg", seed=203, R=0.50, H=0.18, fronds=(14, 9, 2), fringe=12,
                               crown=9, sectors=20,
                               note="egg wrack (knotted wrack) mat with podded fronds, 1.0 m across"),
    "M_Veg_Wrack_Decal_01": dict(kind="Strap", seed=204, R=0.52, H=0.05, fronds=(8, 5, 2), fringe=9,
                                 crown=6, sectors=16,
                                 note="thin decal mat for ledges, pool rims and boulder tops, 1.1 m across"),
}
GRID = 2.05                               # display line spacing (m): R 0.42..0.56 plus hanging fronds
CELL_OF = {"Bladder": "BladderFrond", "Egg": "EggFrond", "Strap": "Strap"}


# ---------------------------------------------------------------------------------------------------- prims
class Part:
    """verts (metres), faces (index tuples), per-vertex UVs, kind 'solid' | 'card', flat face indices"""

    def __init__(self, kind="solid"):
        self.v, self.f, self.uv, self.kind, self.flat = [], [], [], kind, set()

    def add(self, p, st):
        self.v.append(Vector(p))
        self.uv.append(st)
        return len(self.v) - 1


class Dome:
    """The rock-hugging shell a mat is draped on: a low, lobed, tilted dome; z 0 at and beyond the rim."""

    def __init__(self, rng, R, H):
        self.R, self.H = R, H
        self.ph = [rng.uniform(0, 2 * math.pi) for _ in range(4)]
        self.lo = rng.uniform(0.10, 0.20)
        self.lo2 = rng.uniform(0.05, 0.11)
        self.tilt = rng.uniform(0, 2 * math.pi)
        self.lean = rng.uniform(0.08, 0.16)

    def z(self, r, th):
        rn = min(1.15, max(0.0, r) / self.R)
        k = 1.0 + self.lo * math.sin(3 * th + self.ph[0]) + self.lo2 * math.sin(5 * th + self.ph[1])
        t = min(1.0, rn * k)
        h = self.H * (1.0 - t ** 1.55) * (1.0 + 0.12 * math.sin(2 * th + self.ph[2]))
        h += self.lean * self.R * math.cos(th - self.tilt) * max(0.0, 1.0 - t) * 0.5
        return max(0.0, h)


def shell(part, dome, n_sectors=20, rings=(0.26, 0.52, 0.76, 1.0), inset=0.48):
    """The shell: a radial grid over the dome plus a flared skirt ring down to z 0, planar UVs on the Mat cell."""
    R = dome.R
    rows = []
    for t in rings:
        row = []
        for k in range(n_sectors):
            th = 2 * math.pi * k / n_sectors
            r = t * R
            x, y = math.cos(th) * r, math.sin(th) * r
            row.append(part.add((x, y, dome.z(r, th)),
                                L.rect_uv("Mat", 0.5 + x / (2 * R) * inset, 0.5 + y / (2 * R) * inset, m=0.01)))
        rows.append(row)
    apex = part.add((0, 0, dome.z(0.0, 0.0)), L.rect_uv("Mat", 0.5, 0.5, m=0.01))
    for k in range(n_sectors):
        part.f.append((apex, rows[0][k], rows[0][(k + 1) % n_sectors]))
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(n_sectors):
            k1 = (k + 1) % n_sectors
            part.f.append((r0[k], r1[k], r1[k1], r0[k1]))
    rim = rows[-1]
    skirt = []
    for k in range(n_sectors):
        th = 2 * math.pi * k / n_sectors
        r = R * (1.03 + 0.05 * math.sin(3 * th + dome.ph[3]))
        x, y = math.cos(th) * r, math.sin(th) * r
        skirt.append(part.add((x, y, 0.0), L.rect_uv("Mat", 0.5 + x / (2 * R) * inset, 0.5 + y / (2 * R) * inset, m=0.01)))
    for k in range(n_sectors):
        k1 = (k + 1) % n_sectors
        part.f.append((rim[k], skirt[k], skirt[k1], rim[k1]))
    part.flat.update(range(len(part.f)))                 # hard-edged: crisp shell ribs and rim
    return part


def card(part, pts, hws, cell, u0=0.0, u1=1.0, v0=0.0, v1=1.0, side_hint=None, along_v=False):
    """One draped card from a centreline (pts, hws). Default: u runs along the frond, v across. along_v swaps
    them (a hanging fringe card: u spans the band, v runs down the frond)."""
    n = len(pts)
    rows = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        d = d.normalized() if d.length > 1e-9 else Vector((1, 0, 0))
        if side_hint is not None:
            side = side_hint - d * side_hint.dot(d)
        else:
            side = d.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-6 else Vector((0, 1, 0))
        t = i / (n - 1)
        row = []
        for s in (-1, 1):
            if along_v:
                uv = L.rect_uv(cell, u0 + (u1 - u0) * (0.5 + 0.5 * s), v0 + (v1 - v0) * t, m=0.006)
            else:
                uv = L.rect_uv(cell, u0 + (u1 - u0) * t, v0 + (v1 - v0) * (0.5 + 0.5 * s), m=0.006)
            row.append(part.add(p + side * (hws[i] * s), uv))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        part.f.append((r0[0], r0[1], r1[1], r1[0]))
    return rows


def vesicle(part, centre, rad, along, up, el=1.0, lat=1.0, sides=6):
    """A modelled air bladder / pod: two poles on `up`, a hexagonal ring. `lat` squashes it sideways so it sits
    exactly under the painted (squashed) blob; `el` stretches it along the frond (egg pods)."""
    ring = []
    for k in range(sides):
        a = 2 * math.pi * k / sides
        p = (centre + (along * math.cos(a) * rad * el + up.cross(along) * math.sin(a) * rad * 0.82 * lat))
        ring.append(part.add(p, L.rect_uv("Pod", 0.5 + 0.42 * math.cos(a), 0.5 + 0.42 * math.sin(a), m=0.012)))
    top = part.add(centre + up * rad * (0.95 if el < 1.5 else 0.72), L.rect_uv("Pod", 0.5, 0.5, m=0.012))
    bot = part.add(centre - up * rad * 0.55, L.rect_uv("Pod", 0.5, 0.5, m=0.012))
    for k in range(sides):
        k1 = (k + 1) % sides
        part.f.append((top, ring[k], ring[k1]))
        part.f.append((bot, ring[k1], ring[k]))
        part.flat.add(len(part.f) - 2)
        part.flat.add(len(part.f) - 1)


def frond_path(dome, rng, th, r0, wall, over, curl, kind, segs, wander, lift=None, ripple=None):
    """A frond draped over the dome and past its rim: (pts, hws). `lift` stacks fronds into layers, `ripple`
    undulates them over the rock, `wander` curves them sideways as they drape."""
    R = dome.R
    span = R * (1.0 + over) - r0
    drift = wander * rng.uniform(-1.0, 1.0)
    lift = rng.uniform(0.006, 0.018) if lift is None else lift
    ripple = rng.uniform(-1.0, 1.0) if ripple is None else ripple
    ph = rng.uniform(0, 2 * math.pi)
    pts, hws = [], []
    W = L.FROND_M[kind][1]
    for i in range(segs + 1):
        u = i / segs
        th_u = th + drift * u ** 1.4
        r = r0 + span * u
        if r <= R:
            z = dome.z(r, th_u) + lift + 0.014 * u + ripple * math.sin(3.1 * u + ph) * 0.010
        else:
            z = dome.z(R, th_u) + lift + 0.018 - (r - R) ** 2 / max(over * R, 1e-6) ** 2 * 0.58 * R
            z += curl * max(0.0, (u - 0.62) / 0.38) ** 2 * 0.09
        z = max(z, 0.012)
        pts.append(Vector((math.cos(th_u) * r, math.sin(th_u) * r, z)))
        hws.append(L.frond_env(kind, u) * W * 0.5 * wall)
    return pts, hws


def frond(dome, rng, th, r0, kind, segs, over=None, wall=None, curl=None, wander=0.22, ves_n=0, ves_p=1.0,
          lift=None, ripple=None):
    """A draped frond card (card part) plus its modelled vesicles (their own solid part, placed with
    wrack_lib's painted spots)."""
    over = rng.uniform(0.16, 0.46) if over is None else over
    wall = rng.uniform(0.85, 1.15) if wall is None else wall
    curl = rng.uniform(-0.6, 1.0) if curl is None else curl
    pts, hws = frond_path(dome, rng, th, r0, wall, over, curl, kind, segs, wander, lift=lift, ripple=ripple)
    pa = Part("card")
    card(pa, pts, hws, CELL_OF[kind])
    n = len(pts)
    vs = [] if ves_n <= 0 else L.VESICLES[kind]
    if ves_n and ves_n < len(vs):                        # keep bladders spread along the frond, not just at the base
        idx = sorted({int(round(k * (len(vs) - 1) / max(1, ves_n - 1))) for k in range(ves_n)})
        vs = [vs[i] for i in idx]
    pv = None
    for v in vs:
        t, share, rad = v[0], v[1], v[2]
        el = v[3] if len(v) > 3 else 1.0
        if rng.random() > ves_p:
            continue
        if pv is None:
            pv = Part("solid")
        i = min(n - 2, max(0, int(round(t * (n - 1)))))
        f = t * (n - 1) - i
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)])
        d = d.normalized() if d.length > 1e-9 else Vector((1, 0, 0))
        side = d.cross(Vector((0, 0, 1)))
        side = side.normalized() if side.length > 1e-6 else Vector((0, 1, 0))
        up = side.cross(d).normalized()
        p = pts[i] * (1 - f) + pts[i + 1] * f
        lat_scale = L.frond_env(kind, t)                  # the paint is squashed by the envelope: match it
        c = p + side * (share * L.strap_hw(kind, t) * lat_scale) + up * rad * 0.45
        vesicle(pv, c, rad * rng.uniform(0.92, 1.12), d, up, el=el, lat=max(0.55, lat_scale))
    return ([pa, pv] if pv is not None else [pa])


def variant(cfg, x0):
    """All parts of one mat, built at the origin then moved to x0 on the display line."""
    rng = random.Random(cfg["seed"])
    dome = Dome(rng, cfg["R"], cfg["H"])
    kind = cfg["kind"]
    parts = [shell(Part(), dome, n_sectors=cfg["sectors"])]
    for k in range(cfg["crown"]):                        # holdfast cards on the crown, breaking the frond bases
        th = rng.uniform(0, 2 * math.pi)
        r = dome.R * rng.uniform(0.05, 0.45)
        d = Vector((math.cos(th), math.sin(th), 0))
        p = Vector((d.x * r, d.y * r, dome.z(r, th) + 0.004))
        s = rng.uniform(0.10, 0.17)
        pts = [p - d * s * 0.5, p - d * s * 0.17, p + d * s * 0.17, p + d * s * 0.5]
        pa = Part("card")
        u0 = rng.uniform(0.0, 0.25)
        card(pa, pts, [s * 0.30, s * 0.44, s * 0.44, s * 0.30], "Holdfast", u0=u0, u1=u0 + rng.uniform(0.6, 0.9),
             v0=rng.uniform(0.05, 0.30), v1=rng.uniform(0.75, 0.95))
        parts.append(pa)
    n_top, n_side, n_ves = cfg["fronds"]
    for k in range(n_top):                               # crown layer: the fronds that cover the shell's top
        th = rng.uniform(0, 2 * math.pi)
        r0 = dome.R * rng.uniform(0.02, 0.16)
        parts += frond(dome, rng, th, r0, kind, 5, over=rng.uniform(0.04, 0.14), wall=rng.uniform(0.9, 1.2),
                       wander=0.5, ves_n=n_ves, ves_p=1.0 if k % 3 else 0.6, lift=rng.uniform(0.010, 0.020))
    for k in range(n_side):                              # flank layer: draped down the sides at all angles
        th = rng.uniform(0, 2 * math.pi)
        r0 = dome.R * rng.uniform(0.22, 0.58)
        parts += frond(dome, rng, th, r0, kind, 4 if k % 2 else 5, over=rng.uniform(0.08, 0.24),
                       wall=rng.uniform(0.8, 1.15), wander=0.4, ves_n=n_ves, ves_p=1.0 if k % 3 else 0.5,
                       lift=rng.uniform(0.006, 0.016))
    for k in range(n_ves * 2 + 2):                       # rim layer: short straps at the foot, small and pale
        th = rng.uniform(0, 2 * math.pi)
        r0 = dome.R * rng.uniform(0.55, 0.92)
        kk = "Strap" if (kind in ("Egg", "Strap") and k % 3 == 0) else kind
        parts += frond(dome, rng, th, r0, kk, 3, over=rng.uniform(0.05, 0.18),
                       wall=rng.uniform(0.5, 0.8), curl=rng.uniform(-0.8, 1.4), wander=0.3, ves_n=0,
                       lift=rng.uniform(0.004, 0.014))
    for k in range(cfg["fringe"]):                       # straps draped down the flank, a window of the Fringe band
        th = 2 * math.pi * k / cfg["fringe"] + rng.uniform(-0.18, 0.18)
        r = dome.R * rng.uniform(0.70, 0.94)
        out = Vector((math.cos(th), math.sin(th), 0))
        tan = Vector((-out.y, out.x, 0))
        drop = rng.uniform(0.08, 0.17)
        wide = rng.uniform(0.26, 0.46)
        reach = dome.R * rng.uniform(1.02, 1.16)
        pts, hws, segs = [], [], 4
        for i in range(segs + 1):
            t = i / segs
            rr = r + (reach - r) * t
            z = dome.z(min(rr, dome.R), th) * (1.0 - t) + 0.012 * (1 - t) + 0.004
            q = Vector((math.cos(th) * rr, math.sin(th) * rr, max(z - drop * t * 0.6, 0.008)))
            pts.append(q)
            hws.append(wide * 0.5 * (1.0 - 0.15 * t))
        u0 = (k * 0.618) % 1.0 * 0.60
        pa = Part("card")
        card(pa, pts, hws, "Fringe", u0=u0, u1=min(1.0, u0 + 0.36), v0=0.02, v1=0.76,
             side_hint=tan, along_v=True)
        parts.append(pa)
    for pa in parts:
        pa.v = [p + Vector((x0, 0.0, 0.0)) for p in pa.v]
    return parts, dome


# ---------------------------------------------------------------------------------------------------- mesh
def make_mesh(name, parts):
    """One mesh from the parts; cards go in twice (front + reversed) with the same up-leaning normal."""
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
                nn = None
                if pt.kind == "card":
                    a, b, c = (pt.v[i] for i in f[:3])
                    gn = (b - a).cross(c - a)
                    gn = gn.normalized() if gn.length > 1e-12 else Vector((0, 0, 1))
                    if gn.z < 0:
                        gn = -gn
                    nn = tuple((gn * 0.45 + Vector((0, 0, 1)) * 0.55).normalized())
                for lp, vi in zip(face.loops, f2):
                    lp[uvl].uv = pt.uv[vi]
                    loop_n.append(nn)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for poly, fl in zip(me.polygons, flat):
        poly.use_smooth = not fl
    me.update()
    me.normals_split_custom_set([n if n is not None else (0.0, 0.0, 1.0) for n in loop_n])
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material():
    mat = bpy.data.materials.get("MAT_FoliageMarine") or bpy.data.materials.new("MAT_FoliageMarine")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    stem = "T_FoliageMarine_Main"
    for d in (common.textures_dir("M_Veg_Wrack_Kit"),
              os.path.join(common.REPO_DIR, "build/prod/M_Veg_Wrack_Kit/textures/M_Veg_Wrack_Kit")):
        alb = os.path.join(d, stem + "_ALB.png")
        if bsdf and os.path.exists(alb) and not any(n.type == "TEX_IMAGE" for n in nt.nodes):
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(alb, check_existing=True)
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            for tag, inp in (("RGH", "Roughness"), ("NOR", "Normal")):
                p = os.path.join(d, "%s_%s.png" % (stem, tag))
                if not os.path.exists(p):
                    continue
                n = nt.nodes.new("ShaderNodeTexImage")
                n.image = bpy.data.images.load(p, check_existing=True)
                n.image.colorspace_settings.name = "Non-Color"
                if tag == "RGH":
                    nt.links.new(n.outputs["Color"], bsdf.inputs[inp])
                else:
                    nm = nt.nodes.new("ShaderNodeNormalMap")
                    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
                    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
            break
    return mat


def sig3(x):
    return float("%.3g" % x)


def build():
    mat = material()
    meshes, att_objs, names = [], [], []
    for k, (name, cfg) in enumerate(VARIANTS.items()):
        x0 = k * GRID
        parts, dome = variant(cfg, x0)
        ob = make_mesh("%s_LOD0" % name, parts)
        ob.data.transform(Matrix.Diagonal((M, M, M, 1.0)))   # metres -> studs (1 unit = 1 stud)
        ob.data.update()
        meshes.append({"object": ob, "set": "Main"})
        short = name.replace("M_Veg_Wrack_", "")
        att = bpy.data.objects.new("ATT_Base_%s" % short, None)
        att.empty_display_type = 'ARROWS'
        att.location = (x0 * M, 0.0, 0.0)
        bpy.context.scene.collection.objects.link(att)
        att_objs.append(att)
        names.append(name)
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for e in meshes:
        for v in e["object"].data.vertices:
            for i in range(3):
                lo[i] = min(lo[i], v.co[i])
                hi[i] = max(hi[i], v.co[i])
    dims = tuple(sig3((h - l) / M) for l, h in zip(lo, hi))   # real size in metres
    for e in meshes:
        e["object"].data.materials.clear()
        e["object"].data.materials.append(mat)
        e["object"].data.update()
    set_entry = {"name": "FoliageMarine", "set": "Main", "size": 2048, "wet": False,
                 "dir": common.textures_dir("M_Veg_Wrack_Kit")}
    closeups = []
    for k, (name, cfg) in enumerate(VARIANTS.items()):
        closeups.append({"name": name.replace("M_Veg_Wrack_", "").lower(),
                         "target": [k * GRID * M, 0.0, cfg["H"] * M * 0.85],
                         "dist": max(3.6, cfg["R"] * M * 5.0), "az": 32, "el": 20})
    return {
        "name": "M_Veg_Wrack_Kit",
        "budget": "vegetation",
        "tris": ROW_TRIS,
        "tier": "standard",
        "dims_m": dims,
        "size_note": "dims_m is the kit's display line: four mats spaced %.2f m apart on +X, each 0.85 to 1.15 m "
                     "across and 0.15 to 0.6 m tall; the placer lays one mat per rock boss (RESULT.md offsets)"
                     % GRID,
        "origin": "free",
        "sets": [set_entry],
        "atlas": "FoliageMarine",
        "meshes": meshes,
        "attachments": att_objs,
        "waivers": {"LOD UV layout": "LOD1 / LOD2 are collapse decimation of the LOD0 card shells: the same atlas "
                                     "cells and UV bounds, coarser straps (docs/12 2.5 cards reduce at distance)",
                    "geometry": "at LOD2 (25% of LOD0) collapse decimation can orphan 4 to 8 vertices of the ~1800: "
                                "empty vertices of a card whose faces all collapsed, nothing renders; cleaning them "
                                "needs a post-decimation hook in versions.py (tools/), out of an asset's scope"},
        "note": "intertidal wrack mats: %s" % ", ".join(names),
        "closeups": closeups,
    }
