"""H2 Chandlery interior geometry kit (copied from H1 M_Bld_Station/geo.py and extended: tile90, obox, lathe, panel2)

H1 geometry kit (Blender): convex primitives authored in metres, gathered per MeshPart, UV'd per face, written in studs.

UV modes (every face gets its own planar frame: u = Z x n, horizontal and reading left to right from outside;
v = n x u, up the wall / up the roof slope, so slate courses and lettering never mirror):
  ("tile90", metres)                     as tile, rotated 90 degrees (floorboards along Y with an along-u texture)
  ("tile", metres)                       world-scale tiling (MaterialVariant-style sets, the B02 library, own tiling sets)
  ("trim", v0, v1, metres)               a trim-sheet strip: u along the face's long side (tiling), v across inside [v0, v1]
  ("rect", u0, v0, u1, v1, w_m, h_m)     an atlas rect: the face anchored at its own min, w_m x h_m fills the rect
  ("fn", f)                              explicit UVs, f(point m, frame u, frame v) -> (u, v) (zoned floor / wall strips)
"""
import math

import bmesh
import bpy
from mathutils import Vector

STUDS = 3.0
LEVEL = 3          # faces added now survive in LOD0..LOD(LEVEL-1): 3 all LODs, 2 LOD0+LOD1, 1 LOD0 only; -3 LOD2 only
Z = Vector((0, 0, 1))

TRIM = {   # M_Bld_TrimSheet layout.json strips (v0, v1)
    "WindowFrame": (0.0, 0.125), "GlazingBar": (0.125, 0.1875), "Sill": (0.1875, 0.3125), "Gutter": (0.3125, 0.4375),
    "Downpipe": (0.4375, 0.5), "RenderBand": (0.5, 0.625), "Flashing": (0.625, 0.6875), "Fascia": (0.6875, 0.8125),
    "DoorPanel": (0.8125, 0.9375), "Coping": (0.9375, 1.0)}


def trim(strip, metres=1.0):
    v0, v1 = TRIM[strip]
    return ("trim", v0 + 0.004, v1 - 0.004, metres)


def frame_of(n):
    n = Vector(n).normalized()
    u = Z.cross(n)
    if u.length < 1e-4:
        u = Vector((1, 0, 0)) if n.z > 0 else Vector((1, 0, 0))
    u.normalize()
    v = n.cross(u).normalized()
    return u, v


def newell(pts):
    n = Vector((0, 0, 0))
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        n.x += (p.y - q.y) * (p.z + q.z)
        n.y += (p.z - q.z) * (p.x + q.x)
        n.z += (p.x - q.x) * (p.y + q.y)
    return n


class Part:
    def __init__(self, name, smooth_angle=35.0):
        self.name = name
        self.faces = []        # (pts [Vector m], uvs [(u, v)])
        self.smooth_angle = smooth_angle
        self.prim = 0

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.faces)

    # ------------------------------------------------------------ faces
    def face(self, pts, mode, centre=None):
        pts = [Vector(p) for p in pts]
        n = newell(pts)
        if n.length < 1e-10:
            return
        if centre is not None:
            c = sum(pts, Vector()) / len(pts)
            if n.dot(c - Vector(centre)) < 0:
                pts.reverse()
                n = -n
        u, v = frame_of(n)
        a = [p.dot(u) for p in pts]
        b = [p.dot(v) for p in pts]
        kind = mode[0]
        if kind == "tile":
            s = mode[1]
            uvs = [(x / s, y / s) for x, y in zip(a, b)]
        elif kind == "tile90":
            s = mode[1]
            uvs = [(y / s, -x / s) for x, y in zip(a, b)]
        elif kind == "fn":                     # explicit per-vertex UVs: mode[1](point m, frame u, frame v) -> (u, v)
            uvs = [tuple(mode[1](p, u, v)) for p in pts]
        elif kind == "trim":
            v0, v1, s = mode[1], mode[2], mode[3]
            ea, eb = max(a) - min(a), max(b) - min(b)
            if ea >= eb:
                uvs = [(x / s, v0 + (y - min(b)) / max(eb, 1e-6) * (v1 - v0)) for x, y in zip(a, b)]
            else:
                uvs = [(y / s, v0 + (x - min(a)) / max(ea, 1e-6) * (v1 - v0)) for x, y in zip(a, b)]
        else:
            u0, v0, u1, v1, w, h = mode[1:]
            uvs = [(u0 + min(1.0, (x - min(a)) / w) * (u1 - u0), v0 + min(1.0, (y - min(b)) / h) * (v1 - v0))
                   for x, y in zip(a, b)]
        self.faces.append((pts, uvs, LEVEL, self.prim))

    def box(self, lo, hi, mode, skip=()):
        self.prim += 1
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        quads = {
            "-x": [(x0, y0, z0), (x0, y1, z0), (x0, y1, z1), (x0, y0, z1)],
            "+x": [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
            "-y": [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
            "+y": [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
            "-z": [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
            "+z": [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
        }
        for k, q in quads.items():
            if k not in skip:
                self.face(q, mode, centre=c)

    def prism(self, profile, axis, a0, a1, mode, caps=True, cap_mode=None):
        self.prim += 1
        """Extrude a convex 2D profile along axis 'x' | 'y' | 'z' from a0 to a1 (profile in the other two axes, in order)."""
        def P(s, t, a):
            return {"x": (a, s, t), "y": (s, a, t), "z": (s, t, a)}[axis]
        cs = sum(p[0] for p in profile) / len(profile)
        ct = sum(p[1] for p in profile) / len(profile)
        centre = P(cs, ct, (a0 + a1) / 2)
        for i, p in enumerate(profile):
            q = profile[(i + 1) % len(profile)]
            self.face([P(p[0], p[1], a0), P(q[0], q[1], a0), P(q[0], q[1], a1), P(p[0], p[1], a1)], mode, centre=centre)
        if caps:
            for a in (a0, a1):
                self.face([P(p[0], p[1], a) for p in profile], cap_mode or mode, centre=centre)

    def tube(self, p0, p1, r, segs, mode, caps=True):
        self.prim += 1
        p0, p1 = Vector(p0), Vector(p1)
        ax = (p1 - p0).normalized()
        ref = Vector((1, 0, 0)) if abs(ax.x) < 0.9 else Vector((0, 1, 0))
        e1 = ax.cross(ref).normalized()
        e2 = ax.cross(e1).normalized()
        ring = [e1 * (r * math.cos(2 * math.pi * i / segs)) + e2 * (r * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
        # sides: v around via the trim strip, u along (frame picks the long side automatically)
        for i in range(segs):
            j = (i + 1) % segs
            c = (p0 + p1) / 2
            self.face([p0 + ring[i], p0 + ring[j], p1 + ring[j], p1 + ring[i]], mode, centre=c)
        if caps:
            c = (p0 + p1) / 2
            for p in (p0, p1):
                self.face([p + q for q in ring], mode, centre=c)

    def obox(self, p0, p1, w, h, up, mode, skip_ends=False, skip=()):
        """Oriented box along p0 -> p1: width w across (up x axis), height h along 'up' (made perpendicular), centred."""
        self.prim += 1
        p0, p1 = Vector(p0), Vector(p1)
        ax = (p1 - p0).normalized()
        upv = Vector(up)
        upv = (upv - ax * upv.dot(ax)).normalized()
        side = ax.cross(upv).normalized()
        c = (p0 + p1) / 2
        def corner(p, i, j):
            return p + side * (w / 2 * i) + upv * (h / 2 * j)
        quads = {
            "bottom": [corner(p0, -1, -1), corner(p0, 1, -1), corner(p1, 1, -1), corner(p1, -1, -1)],
            "top": [corner(p0, -1, 1), corner(p0, 1, 1), corner(p1, 1, 1), corner(p1, -1, 1)],
            "left": [corner(p0, -1, -1), corner(p0, -1, 1), corner(p1, -1, 1), corner(p1, -1, -1)],
            "right": [corner(p0, 1, -1), corner(p0, 1, 1), corner(p1, 1, 1), corner(p1, 1, -1)],
        }
        if not skip_ends:
            quads["end0"] = [corner(p0, -1, -1), corner(p0, 1, -1), corner(p0, 1, 1), corner(p0, -1, 1)]
            quads["end1"] = [corner(p1, -1, -1), corner(p1, 1, -1), corner(p1, 1, 1), corner(p1, -1, 1)]
        for k, q in quads.items():
            if k not in skip:
                self.face(q, mode, centre=c)

    def lathe(self, prof, centre, segs, mode, inside=False, cap_top=False, cap_bottom=False, cap_mode=None):
        """Revolve a profile [(r, z_offset), ...] listed top to bottom about the vertical axis through centre.
        Faces point away from the axis (inside=True: towards it, for the inner face of a shade)."""
        self.prim += 1
        c = Vector(centre)
        def P(r, z, j):
            a = 2 * math.pi * j / segs
            return Vector((c.x + r * math.cos(a), c.y + r * math.sin(a), c.z + z))
        for i in range(len(prof) - 1):
            (r0, z0), (r1, z1) = prof[i], prof[i + 1]
            out2 = (-(z1 - z0), (r1 - r0))       # outward 2D normal (r, z) for a top-to-bottom profile
            for j in range(segs):
                if r0 < 1e-6 and r1 < 1e-6:
                    continue
                pts = [P(r0, z0, j), P(r0, z0, j + 1), P(r1, z1, j + 1), P(r1, z1, j)]
                if r0 < 1e-6:
                    pts = [pts[0], pts[2], pts[3]]
                elif r1 < 1e-6:
                    pts = [pts[0], pts[1], pts[2]]
                am = 2 * math.pi * (j + 0.5) / segs
                want = Vector((math.cos(am) * out2[0], math.sin(am) * out2[0], out2[1]))
                n = newell(pts)
                if (n.dot(want) < 0) != inside:
                    pts.reverse()
                self.face(pts, mode)
        for flag, (r, z), sgn in ((cap_top, prof[0], 1), (cap_bottom, prof[-1], -1)):
            if flag and r > 1e-6:
                pts = [P(r, z, j) for j in range(segs)]
                if newell(pts).z * sgn < 0:
                    pts.reverse()
                self.face(pts, cap_mode or mode)

    def panel2(self, pts, mode, mode_back=None):
        """A thin sheet seen from both sides (curtain, chart sheet edge): the face and its reverse."""
        self.prim += 1
        pts = [Vector(p) for p in pts]
        n = newell(pts).normalized()
        self.face(pts, mode)
        self.prim += 1          # own shell: the back face must not weld onto the front one
        self.face([p - n * 0.002 for p in reversed(pts)], mode_back or mode)

    # ------------------------------------------------------------ output
    def bbox(self):
        pts = [p for f in self.faces for p in f[0]]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return lo, hi

    def to_object(self, obj_name, material, offset=Vector(), lod=0, weld=True):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        groups = {}
        for pts, uvs, lv, pid in self.faces:
            if (lv > 0 and lv <= lod) or (lv < 0 and lod != -lv - 1):     # LEVEL -3: LOD2 only (stand-in)
                continue
            vs = [bm.verts.new(((p.x + offset.x) * STUDS, (p.y + offset.y) * STUDS, (p.z + offset.z) * STUDS)) for p in pts]
            groups.setdefault(pid, []).extend(vs)
            f = bm.faces.new(vs)
            for loop, uv in zip(f.loops, uvs):
                loop[uvl].uv = uv
        for vs in groups.values():      # weld each primitive into a closed shell; shells stay separate
            bmesh.ops.remove_doubles(bm, verts=list(set(vs)), dist=1e-4)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        for p in mesh.polygons:
            p.use_smooth = True
        try:
            mesh.set_sharp_from_angle(angle=math.radians(self.smooth_angle))
        except Exception:
            pass
        if material is not None:
            mesh.materials.append(material)
        obj = bpy.data.objects.new(obj_name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def material(name, rgb, rough=0.8, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return mat


class Wall:
    """A frame on a wall face: s along the wall (right as seen from outside), o outward, t up. axis-aligned walls only."""

    def __init__(self, normal, face_coord, along_origin=0.0):
        self.n = Vector(normal)
        self.a = Z.cross(self.n).normalized()
        self.f = face_coord
        self.o0 = along_origin

    def world(self, s, o, t):
        base = Vector((0, 0, 0))
        if abs(self.n.x) > 0.5:
            base.x = self.f
        else:
            base.y = self.f
        return base + self.a * s + self.n * o + Z * t

    def box(self, part, s0, s1, o0, o1, t0, t1, mode, skip_back=True):
        p, q = self.world(s0, o0, t0), self.world(s1, o1, t1)
        lo = (min(p.x, q.x), min(p.y, q.y), min(p.z, q.z))
        hi = (max(p.x, q.x), max(p.y, q.y), max(p.z, q.z))
        skip = ()
        if skip_back:
            k = ("-" if self.n.x > 0.5 else "+") + "x" if abs(self.n.x) > 0.5 else ("-" if self.n.y > 0.5 else "+") + "y"
            skip = (k,)
        part.box(lo, hi, mode, skip=skip)

    def quad(self, part, s0, s1, o, t0, t1, mode):
        pts = [self.world(s0, o, t0), self.world(s1, o, t0), self.world(s1, o, t1), self.world(s0, o, t1)]
        part.face(pts, mode, centre=self.world((s0 + s1) / 2, o - 1.0, (t0 + t1) / 2))
