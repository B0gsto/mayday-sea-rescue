"""Lego geometry for M_Bld_Bunkhouse (copied from M_Bld_RescueHQ/hqgeo.py, plus slab / pstud / beam): bevelled bricks, studs, slope slabs and the shared flat colour materials.

One Group is one mesh (one colour, one construction layer). Geometry is written straight into a bmesh in world
studs; the object stays at identity so validate's transforms-applied / origin rules hold. UVs are a box projection
(each mesh has no PBR set; the projection keeps the LOD UV layout within the pipeline's 15% area tolerance).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

STUD_R = 0.62


def srgb(hex_colour):
    """'#RRGGBB' -> linear RGB (Blender node values are scene-linear)."""
    h = hex_colour.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


_MATS = {}


def material(key, hex_colour, rough=0.5, metal=0.0, alpha=1.0):
    if key in _MATS:
        return _MATS[key]
    mat = bpy.data.materials.new("MI_" + key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*srgb(hex_colour), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attr, value in (("blend_method", "BLEND"), ("surface_render_method", "BLENDED")):
            try:
                setattr(mat, attr, value)
            except (AttributeError, TypeError):
                pass
    _MATS[key] = mat
    return mat


class Group:
    def __init__(self, name, mat):
        self.name = name
        self.mat = mat
        self.bm = bmesh.new()

    # ---------------------------------------------------------------- primitives
    def _bevel(self, verts, offset):
        if offset <= 0.0:
            return
        vs = set(verts)
        edges = {e for v in verts for e in v.link_edges if e.other_vert(v) in vs}
        if edges:
            bmesh.ops.bevel(self.bm, geom=list(edges), offset=offset, offset_type='OFFSET',
                            segments=1, affect='EDGES', clamp_overlap=True)

    def box(self, centre, size, bevel=0.06, rot=None, drop=""):
        """drop: hidden faces to leave out (unbevelled axis boxes): b/t = -Z/+Z, x/X = -X/+X, y/Y = -Y/+Y."""
        m = Matrix.Translation(Vector(centre))
        if rot is not None:
            m = m @ rot
        m = m @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._bevel(res["verts"], bevel)
        if drop:
            dirs = [{"b": (2, -1), "t": (2, 1), "x": (0, -1), "X": (0, 1), "y": (1, -1), "Y": (1, 1)}[d] for d in drop]
            faces = {f for v in res["verts"] for f in v.link_faces}
            for f in faces:
                f.normal_update()
            kill = [f for f in faces if any(f.normal[ax] * sg > 0.99 for ax, sg in dirs)]
            bmesh.ops.delete(self.bm, geom=kill, context='FACES')

    def cyl(self, centre, radius, height, segs=8, axis='Z', radius_top=None):
        rot = Matrix.Identity(4)
        if axis == 'X':
            rot = Matrix.Rotation(math.radians(90.0), 4, 'Y')
        elif axis == 'Y':
            rot = Matrix.Rotation(math.radians(90.0), 4, 'X')
        m = Matrix.Translation(Vector(centre)) @ rot
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs,
                              radius1=radius, radius2=radius if radius_top is None else radius_top,
                              depth=height, matrix=m)

    def prism(self, pts, thick, axis='X', at=0.0):
        """Triangular prism: pts = [(a, b), ...] in the plane normal to `axis`, extruded +-thick/2 about `at`."""
        lo, hi = at - thick / 2.0, at + thick / 2.0
        rings = []
        for x in (lo, hi):
            ring = []
            for a, b in pts:
                co = (x, a, b) if axis == 'X' else (a, x, b) if axis == 'Y' else (a, b, x)
                ring.append(self.bm.verts.new(co))
            rings.append(ring)
        self.bm.faces.new(rings[0])
        self.bm.faces.new(list(reversed(rings[1])))
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))

    def torus(self, centre, major, minor, segs=12, minor_segs=5, axis='Y'):
        c = Vector(centre)
        grid = []
        for i in range(segs):
            t = 2.0 * math.pi * i / segs
            row = []
            for j in range(minor_segs):
                p = 2.0 * math.pi * j / minor_segs
                rr = major + minor * math.cos(p)
                if axis == 'Y':
                    co = (rr * math.cos(t), minor * math.sin(p), rr * math.sin(t))
                elif axis == 'X':
                    co = (minor * math.sin(p), rr * math.cos(t), rr * math.sin(t))
                else:
                    co = (rr * math.cos(t), rr * math.sin(t), minor * math.sin(p))
                row.append(self.bm.verts.new(c + Vector(co)))
            grid.append(row)
        for i in range(segs):
            for j in range(minor_segs):
                a = grid[i][j]
                b = grid[(i + 1) % segs][j]
                cc = grid[(i + 1) % segs][(j + 1) % minor_segs]
                d = grid[i][(j + 1) % minor_segs]
                self.bm.faces.new((a, b, cc, d))

    def stud(self, x, y, z, radius=STUD_R, height=0.4, segs=8):
        self.cyl((x, y, z + height / 2.0), radius, height, segs=segs)

    def slab(self, centre, size, ch=0.12):
        """Box with the top edges chamfered (12 tris): the top face is inset by ch, so the rim catches light."""
        cx, cy, cz = centre
        sx, sy, sz = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
        ch = min(ch, sx * 0.5, sy * 0.5)
        bot = [self.bm.verts.new((cx + sx * a, cy + sy * b, cz - sz)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        top = [self.bm.verts.new((cx + (sx - ch) * a, cy + (sy - ch) * b, cz + sz)) for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        self.bm.faces.new(list(reversed(bot)))
        self.bm.faces.new(top)
        for i in range(4):
            j = (i + 1) % 4
            self.bm.faces.new((bot[i], bot[j], top[j], top[i]))

    def pstud(self, x, y, z, r=0.9, h=0.5, segs=6):
        """A Lego stud with no hidden bottom: 2 * segs triangles + the top face."""
        ring0 = [self.bm.verts.new((x + r * math.cos(2 * math.pi * i / segs), y + r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)]
        ring1 = [self.bm.verts.new((v.co.x, v.co.y, z + h)) for v in ring0]
        for i in range(segs):
            j = (i + 1) % segs
            self.bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        self.bm.faces.new(ring1)

    def beam(self, p0, p1, w, h):
        """A box between two points (w across, h up), for rails, ropes and the sloping handrails."""
        a, b = Vector(p0), Vector(p1)
        d = b - a
        rot = Vector((1.0, 0.0, 0.0)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        self.box((a + b) / 2.0, (d.length, w, h), 0.0, rot=rot)

    # ---------------------------------------------------------------- finish
    def done(self):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        lo = [min(v.co[i] for v in bm.verts) for i in range(3)]
        hi = [max(v.co[i] for v in bm.verts) for i in range(3)]
        span = [(hi[i] - lo[i]) or 1.0 for i in range(3)]
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            n = f.normal
            axis = max(range(3), key=lambda i: abs(n[i]))
            a, b = [i for i in range(3) if i != axis]
            for loop in f.loops:
                co = loop.vert.co
                loop[uv].uv = ((co[a] - lo[a]) / span[a], (co[b] - lo[b]) / span[b])
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(self.mat)
        ob = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def face_run(g, a0, a1, z0, z1, fixed, axis, thick, holes=(), gap=0.09, brick=3.0, bevel=0.07, phase=0.0):
    """A course of flat panels from a0..a1 at `fixed`, skipping holes [(a0, a1, z0, z1), ...].

    Panel joints sit on the global grid `phase + k * brick`, so alternate courses offset by half a brick read as
    running bond. `gap` leaves a groove at each joint; `bevel=0` keeps the panels flat (12 tris each)."""
    segments = [(a0, a1)]
    for h0, h1, hz0, hz1 in holes:
        if hz1 <= z0 or hz0 >= z1:
            continue
        nxt = []
        for s0, s1 in segments:
            if h1 <= s0 or h0 >= s1:
                nxt.append((s0, s1))
                continue
            if h0 > s0:
                nxt.append((s0, h0))
            if h1 < s1:
                nxt.append((h1, s1))
        segments = nxt
    for s0, s1 in segments:
        if s1 - s0 <= gap:
            continue
        k = int(math.floor((s0 - phase) / brick))
        while True:
            a, b = phase + k * brick, phase + (k + 1) * brick
            if a >= s1:
                break
            ca = max(a, s0) + (gap / 2.0 if a > s0 + 1e-6 else 0.0)
            cb = min(b, s1) - (gap / 2.0 if b < s1 - 1e-6 else 0.0)
            if cb - ca > 0.05:
                c = (ca + cb) / 2.0
                if axis == 'x':
                    g.box((c, fixed, (z0 + z1) / 2.0), (cb - ca, thick, z1 - z0), bevel)
                else:
                    g.box((fixed, c, (z0 + z1) / 2.0), (thick, cb - ca, z1 - z0), bevel)
            if b >= s1:
                break
            k += 1


def wall_ring(g, x0, x1, y0, y1, z0, z1, thick, holes_front=(), holes_back=(), holes_left=(),
              holes_right=(), gap=0.09, brick=3.0, bevel=0.07, phase=0.0):
    """One course of panels round a rectangular footprint. Front is -Y; holes are in wall-length coordinates."""
    face_run(g, x0, x1, z0, z1, y0 + thick / 2.0, 'x', thick, holes_front, gap, brick, bevel, phase)
    face_run(g, x0, x1, z0, z1, y1 - thick / 2.0, 'x', thick, holes_back, gap, brick, bevel, phase)
    face_run(g, y0 + thick, y1 - thick, z0, z1, x0 + thick / 2.0, 'y', thick, holes_left, gap, brick, bevel, phase)
    face_run(g, y0 + thick, y1 - thick, z0, z1, x1 - thick / 2.0, 'y', thick, holes_right, gap, brick, bevel, phase)


def solid_wall(g, a0, a1, z0, z1, fixed, axis, thick, holes=()):
    """One flat slab a0..a1 x z0..z1 at `fixed`, cut by holes [(a0, a1, z0, z1)] into the fewest boxes."""
    cuts = sorted({a0, a1} | {min(max(v, a0), a1) for h in holes for v in h[:2]})
    for p, q in zip(cuts, cuts[1:]):
        if q - p < 0.05:
            continue
        mid = (p + q) / 2.0
        spans = [(z0, z1)]
        for h0, h1, hz0, hz1 in holes:
            if h0 < mid < h1:
                spans = [s for lo, hi in spans for s in ((lo, min(hi, hz0)), (max(lo, hz1), hi)) if s[1] - s[0] > 0.01]
        for lo, hi in spans:
            c = ((p + q) / 2.0, fixed, (lo + hi) / 2.0) if axis == 'x' else (fixed, (p + q) / 2.0, (lo + hi) / 2.0)
            size = (q - p, thick, hi - lo) if axis == 'x' else (thick, q - p, hi - lo)
            g.box(c, size, 0.0)


def courses(z0, z1, n, gap=0.1):
    h = (z1 - z0) / n
    return [(z0 + i * h, z0 + (i + 1) * h - gap) for i in range(n)]
