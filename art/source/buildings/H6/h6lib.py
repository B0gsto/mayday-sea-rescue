"""H6 (docs/12 2.2): shared pipeline for M_Bld_HarbourLight and M_Bld_LifeguardTower, after HP2b's buoylib.

Each asset is built in metres (Z up, origin at the base centre, front = -Y) as one bmesh per texture set with a face
attribute `part`. Per set (one Blender run, under tools/blender/run.py):
  1. smooth by angle, smart UVs (one UV set `UVMap`);
  2. G-buffer bake (Cycles EMIT: object position, normal, part id, pointiness, AO) cached as
     art/source/buildings/<Asset>/textures/gbuffer_<Set>_<N>.npz (H6_BAKE=1 re-bakes);
  3. h6tex.compose_set paints the PBR set from the G-buffer and CC0 Poly Haven scans (masters in textures/, shipping
     maps in assets/textures/<Asset>/, _Wet ALB / RGH, signal mask);
  4. listed parts split off into their own MeshParts (lens, glazing: same set, UVs kept);
  5. scaled to studs (x3), transforms applied, _COL, ATT_* empties.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, "art", "source", "harbour", "HP2b"))
import buoylib  # noqa: E402  (Geo, bake_gbuffer, empty, finish, preview_material)
import h6tex  # noqa: E402

import common  # noqa: E402
import rbxkit  # noqa: E402

S = common.STUDS_PER_METRE
GBUF = int(os.environ.get("H6_GBUF", "2048"))


class Geo(buoylib.Geo):
    def lathe(self, profile, seg, part, m=None, parts=None, phase=0.0, smooth=True, caps=True):
        """buoylib lathe, plus caps=False for open ends that are hidden (they would only waste UV space)."""
        if caps:
            return super().lathe(profile, seg, part, m=m, parts=parts, phase=phase, smooth=smooth)
        rings = [self.ring(r, z, seg, m, phase) for r, z in profile]
        for k, (a, b) in enumerate(zip(rings, rings[1:])):
            p = parts[k] if parts else part
            for i in range(seg):
                j = (i + 1) % seg
                if len(a) == 1 and len(b) == 1:
                    continue
                if len(a) == 1:
                    self.face((a[0], b[i], b[j]), p, smooth)
                elif len(b) == 1:
                    self.face((a[j], a[i], b[0]), p, smooth)
                else:
                    self.face((a[i], a[j], b[j], b[i]), p, smooth)

    def boxr(self, centre, size, part, yaw=0.0, pitch=0.0, roll=0.0):
        """Box rotated by yaw (about Z), then pitch (about local X) and roll (about local Y)."""
        rot = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Rotation(roll, 4, "Y")
        self.box(centre, size, part, rot)

    def beam(self, p0, p1, w, h, part, up=(0, 0, 1)):
        """Rectangular section w x h from p0 to p1 (w across, h along `up` projected)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        x = d.normalized()
        u = Vector(up)
        u = (u - x * u.dot(x))
        if u.length < 1e-6:
            u = Vector((1, 0, 0)) - x * x.x
        u.normalize()
        v = x.cross(u)
        m = Matrix((
            (x.x, v.x, u.x, 0.0), (x.y, v.y, u.y, 0.0), (x.z, v.z, u.z, 0.0), (0.0, 0.0, 0.0, 1.0)))
        c = (p0 + p1) / 2.0
        self.box(c, (L, w, h), part, m)

    def bbox(self, centre, size, part, bev=0.006, rot=None, axis=None):
        """Box with chamfered edges (bevel `bev` m). axis None: all 12 edges; 0/1/2: only the 4 edges along local
        x/y/z (planks: bevelled long edges, square ends)."""
        m = Matrix.Translation(Vector(centre)) @ (rot or Matrix())
        sx, sy, sz = (s / 2.0 for s in size)
        b = min(bev, 0.45 * min(size))
        vs = [self.bm.verts.new(m @ Vector((x, y, z))) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
        fs = [self.face([vs[i] for i in q], part, False)
              for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))]
        edges = {e for f in fs for e in f.edges}
        if axis is not None:
            ax = (m.to_3x3() @ Vector([1.0 if k == axis else 0.0 for k in range(3)])).normalized()
            edges = {e for e in edges if abs((e.verts[1].co - e.verts[0].co).normalized().dot(ax)) > 0.99}
        if b <= 1e-5:
            return
        res = bmesh.ops.bevel(self.bm, geom=list(edges) + list({v for e in edges for v in e.verts}), offset=b,
                              offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
        for f in res.get("faces", []):
            f[self.layer] = part
            f.smooth = False

    def bboxr(self, centre, size, part, yaw=0.0, pitch=0.0, roll=0.0, bev=0.006, axis=None):
        rot = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(pitch, 4, "X") @ Matrix.Rotation(roll, 4, "Y")
        self.bbox(centre, size, part, bev, rot, axis)

    def bbeam(self, p0, p1, w, h, part, up=(0, 0, 1), bev=0.008):
        """beam() with chamfered long edges."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        x = d.normalized()
        u = Vector(up)
        u = (u - x * u.dot(x))
        if u.length < 1e-6:
            u = Vector((1, 0, 0)) - x * x.x
        u.normalize()
        v = x.cross(u)
        m = Matrix(((x.x, v.x, u.x, 0.0), (x.y, v.y, u.y, 0.0), (x.z, v.z, u.z, 0.0), (0.0, 0.0, 0.0, 1.0)))
        self.bbox((p0 + p1) / 2.0, (d.length, w, h), part, bev, m, axis=0)

    def quad(self, pts, part, smooth=False):
        vs = [self.bm.verts.new(Vector(p)) for p in pts]
        self.face(vs, part, smooth)


def split_parts(obj, parts, name):
    """Moves the faces whose part is in `parts` into a new object `name` (UVs kept)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.faces.layers.int.get("part")
    other = bm.copy()
    lay2 = other.faces.layers.int.get("part")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[layer] in parts], context="FACES")
    bmesh.ops.delete(other, geom=[f for f in other.faces if f[lay2] not in parts], context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    mesh = bpy.data.meshes.new(name)
    other.to_mesh(mesh)
    other.free()
    new = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(new)
    for m in obj.data.materials:
        new.data.materials.append(m)
    return new


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def hero_uvs(obj, squeeze, heroes):
    """Squeezes the smart-UV layout into v 0..squeeze and gives each hero face (lettering) its own large rect in the
    freed band. heroes: [(part, outward normal, right vector, (u0, v0, u1, v1))]; the face's verts are projected on
    right / +Z, so the rect gets the face at its true orientation (u right, v up)."""
    mesh = obj.data
    uv = mesh.uv_layers[0].data
    part = mesh.attributes["part"].data
    hero_polys = {}
    for p in mesh.polygons:
        for k, (pid, nrm, right, rect) in enumerate(heroes):
            if part[p.index].value == pid and p.normal.dot(Vector(nrm)) > 0.9:
                hero_polys[p.index] = k
    for p in mesh.polygons:
        if p.index in hero_polys:
            continue
        for li in p.loop_indices:
            uv[li].uv = (uv[li].uv[0], uv[li].uv[1] * squeeze)
    for k, (pid, nrm, right, rect) in enumerate(heroes):
        polys = [mesh.polygons[i] for i, kk in hero_polys.items() if kk == k]
        if not polys:
            print("[H6] hero face for part %d not found" % pid)
            continue
        right = Vector(right)
        vs = [mesh.vertices[v].co for p in polys for v in p.vertices]
        us = [c.dot(right) for c in vs]
        zs = [c.z for c in vs]
        u0, u1, z0, z1 = min(us), max(us), min(zs), max(zs)
        for p in polys:
            for li in p.loop_indices:
                c = mesh.vertices[mesh.loops[li].vertex_index].co
                fu = (c.dot(right) - u0) / max(u1 - u0, 1e-6)
                fv = (c.z - z0) / max(z1 - z0, 1e-6)
                uv[li].uv = (rect[0] + fu * (rect[2] - rect[0]), rect[1] + fv * (rect[3] - rect[1]))


def make_set(asset, set_name, geo, tex, size, painter, splits=(), uv_angle=60, heroes=None, squeeze=1.0):
    """Builds one texture set: object, UVs, G-buffer, maps, preview material, split-off parts.
    Returns [mesh entries] (main first). splits: [(part ids, mesh suffix)]."""
    obj = geo.to_object("%s_%s_LOD0" % (asset, set_name))
    rbxkit.select_only(obj)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40), keep_sharp_edges=True)
    rbxkit.smart_uv(obj, angle=uv_angle, margin=0.003)
    obj.data.uv_layers[0].name = common.UV_NAME
    if heroes:
        hero_uvs(obj, squeeze, heroes)
    src = os.path.join(common.SOURCE_DIR, "buildings", asset, "textures")
    os.makedirs(src, exist_ok=True)
    gb = os.path.join(src, "gbuffer_%s_%d.npz" % (set_name, GBUF))
    if os.environ.get("H6_BAKE") == "1" or not os.path.isfile(gb):
        buoylib.bake_gbuffer(obj, gb, GBUF)
    out_dir = common.textures_dir(asset)
    stem_alb = os.path.join(out_dir, "T_%s_%s_ALB.png" % (tex, set_name))
    if os.environ.get("H6_COMPOSE", "1") == "1" or not os.path.isfile(stem_alb):
        h6tex.compose_set(gb, painter, src, out_dir, tex, set_name, size)
    mat = buoylib.preview_material("MI_%s_%s" % (tex, set_name), stem_alb)
    obj.data.materials.append(mat)
    out = [{"object": obj, "set": set_name}]
    for parts, suffix in splits:
        part_obj = split_parts(obj, set(parts), "%s_%s_LOD0" % (asset, suffix))
        out.append({"object": part_obj, "set": set_name})
    for e in out:
        buoylib.finish(e["object"])
    return out


def col_boxes(name, boxes):
    """_COL from [(centre, size, yaw, pitch)] boxes in metres."""
    g = Geo()
    for c, s, yaw, pitch in boxes:
        g.boxr(c, s, 0, yaw, pitch)
    obj = g.to_object(name)
    buoylib.finish(obj)
    return obj


def col_lathe(name, profile, seg=10):
    g = Geo()
    g.lathe(profile, seg, 0, smooth=False)
    obj = g.to_object(name)
    buoylib.finish(obj)
    return obj


def empty(name, loc):
    return buoylib.empty(name, loc)


def bbox_m(meshes):
    pts = [e["object"].matrix_world @ Vector(c) for e in meshes for c in e["object"].bound_box]
    lo = [min(p[i] for p in pts) / S for i in range(3)]
    hi = [max(p[i] for p in pts) / S for i in range(3)]
    return lo, hi


def keep_islands(obj, budget):
    """Keeps the largest connected pieces (by bounding-box diagonal) whose triangles fit in `budget`."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    seen, islands = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, isl = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            isl.append(g)
            for v in g.verts:
                for h in v.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        co = [v.co for g in isl for v in g.verts]
        lo = Vector([min(c[i] for c in co) for i in range(3)])
        hi = Vector([max(c[i] for c in co) for i in range(3)])
        islands.append(((hi - lo).length, sum(len(g.verts) - 2 for g in isl), isl))
    islands.sort(key=lambda t: -t[0])
    used, drop = 0, []
    for diag, n, isl in islands:
        if used + n <= budget:
            used += n
        else:
            drop.extend(isl)
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()


def make_lods(spec):
    """LOD1 / LOD2 per LOD0 visual mesh (UVs and set kept): collapse decimation to the class share; where boxes cannot
    collapse that far, the largest pieces that fit this mesh's share of the LOD ceiling, then decimation again."""
    import budgets
    import names
    import versions
    bc, at = spec["budget"], spec.get("tris")
    lod0 = [e for e in spec["meshes"] if e["object"].name.endswith("_LOD0")]
    total = sum(tris(e["object"]) for e in lod0)
    for lod in budgets.lods_made(bc):
        ceil = budgets.lod_ceiling(bc, lod, at)
        for e in lod0:
            src = e["object"]
            n0 = tris(src)
            obj = versions.copy_object(src, names.with_suffix(src.name, lod))
            target = budgets.lod_target(bc, lod, n0, at)
            mesh_budget = max(int(ceil * n0 / float(total)), 12)
            try:
                versions.decimate(obj, target)
            except RuntimeError:
                keep_islands(obj, mesh_budget)
                if tris(obj) > target:
                    try:
                        versions.decimate(obj, max(target, int(tris(obj) * 0.8)))
                    except RuntimeError:
                        pass
            lo0 = [min((src.matrix_world @ Vector(c))[i] for c in src.bound_box) for i in range(3)]
            hi0 = [max((src.matrix_world @ Vector(c))[i] for c in src.bound_box) for i in range(3)]
            lo1 = [min((obj.matrix_world @ Vector(c))[i] for c in obj.bound_box) for i in range(3)]
            hi1 = [max((obj.matrix_world @ Vector(c))[i] for c in obj.bound_box) for i in range(3)]
            tol = 0.02 * max(h - l for h, l in zip(hi0, lo0))
            if any(a < b - tol for a, b in zip(lo1, lo0)) or any(a > b + tol for a, b in zip(hi1, hi0)):
                # H6b: collapse on bevelled boxes can throw vertices outside the hull; then drop the small pieces
                # first (bolts, hardware, balusters) and decimate what is left
                print("[H6] %s left the LOD0 bounds (%s..%s vs %s..%s); islands first" % (
                    obj.name, [round(v, 2) for v in lo1], [round(v, 2) for v in hi1], [round(v, 2) for v in lo0],
                    [round(v, 2) for v in hi0]))
                lname = names.with_suffix(src.name, lod)
                old_mesh = obj.data
                bpy.data.objects.remove(obj)
                bpy.data.meshes.remove(old_mesh)
                obj = versions.copy_object(src, lname)
                keep_islands(obj, int(max(target, 12) * 1.8))
                if tris(obj) == 0:                     # one piece bigger than the share (glazing): keep it whole
                    old_mesh = obj.data
                    bpy.data.objects.remove(obj)
                    bpy.data.meshes.remove(old_mesh)
                    obj = versions.copy_object(src, lname)
                elif tris(obj) > target:
                    try:
                        versions.decimate(obj, max(target, 12))
                    except RuntimeError:
                        keep_islands(obj, max(target, 12))
                obj.data.name = obj.name
            versions.weighted_normals(obj)
            spec["meshes"].append({"object": obj, "role": "visual", "lod": lod, "of": src.name, "set": e["set"]})
            print("[H6] %s %d tris (target %d, mesh budget %d, LOD0 %d)" % (obj.name, tris(obj), target, mesh_budget, n0))
