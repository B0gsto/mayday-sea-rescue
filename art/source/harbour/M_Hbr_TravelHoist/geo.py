"""H1 geometry kit (Blender): convex primitives authored in metres, gathered per MeshPart, UV'd per face, written in studs.

UV modes (every face gets its own planar frame: u = Z x n, horizontal and reading left to right from outside;
v = n x u, up the wall / up the roof slope, so slate courses and lettering never mirror):
  ("tile", metres)                       world-scale tiling (MaterialVariant-style sets, the B02 library, own tiling sets)
  ("trim", v0, v1, metres)               a trim-sheet strip: u along the face's long side (tiling), v across inside [v0, v1]
  ("rect", u0, v0, u1, v1, w_m, h_m)     an atlas rect: the face anchored at its own min, w_m x h_m fills the rect
  ("fn", f)                              explicit: f(Vector world point, metres) -> (u, v), e.g. one rect over many faces
LEVEL may also be a tuple of LOD indices (e.g. (2,) = LOD2 only, (0, 1) = LOD0 and LOD1 only).
"""
import math

import bmesh
import bpy
from mathutils import Vector

STUDS = 3.0
LEVEL = 3          # faces added now survive in LOD0..LOD(LEVEL-1): 3 all LODs, 2 LOD0+LOD1, 1 LOD0 only
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

    def tris(self, lod=None):
        return sum(len(f[0]) - 2 for f in self.faces if lod is None or _keep(f[2], lod))

    # ------------------------------------------------------------ faces
    def _tile_quad(self, pts, mode, n, u, v, a, b):
        """Split a quad into worldreg cells, each mapped inside the atlas region at the requested tile size."""
        u0, v0, u1, v1, su, sv, du, dv = mode[1:9]
        wa, wb = max(a) - min(a), max(b) - min(b)
        if wa < 1e-9 or wb < 1e-9:
            return
        m = max(1, int(math.ceil(wa / su)))
        k = max(1, int(math.ceil(wb / sv)))
        p00, p10, p11, p01 = pts

        def Q(s, t):
            return (p00 * ((1 - s) * (1 - t)) + p10 * (s * (1 - t)) + p11 * (s * t) + p01 * ((1 - s) * t))
        cw, ch = wa / m, wb / k
        # each cell gets the WHOLE tileable region: the cell edges then match (the texture is seamless)
        ru, rv = u1 - u0, v1 - v0
        for i in range(m):
            for j in range(k):
                s0, s1, t0, t1 = i / m, (i + 1) / m, j / k, (j + 1) / k
                cell = [Q(s0, t0), Q(s1, t0), Q(s1, t1), Q(s0, t1)]
                self.face(cell, ("rect", u0, v0, min(u0 + ru, u1), min(v0 + rv, v1), cw, ch),
                          outward=n)

    def face(self, pts, mode, centre=None, outward=None):
        pts = [Vector(p) for p in pts]
        n = newell(pts)
        if n.length < 1e-10:
            return
        flipped = False
        if outward is not None and n.dot(Vector(outward)) < 0:
            pts.reverse()
            n = -n
            flipped = True
        if centre is not None:
            c = sum(pts, Vector()) / len(pts)
            if n.dot(c - Vector(centre)) < 0:
                pts.reverse()
                n = -n
                flipped = True
        u, v = frame_of(n)
        a = [p.dot(u) for p in pts]
        b = [p.dot(v) for p in pts]
        kind = mode[0]
        if kind == "worldreg" and len(pts) == 4:
            self._tile_quad(pts, mode, n, u, v, a, b)
            return
        if kind == "fn":
            uvs = [tuple(mode[1](p)) for p in pts]
        elif kind == "tile":
            s = mode[1]
            uvs = [(x / s, y / s) for x, y in zip(a, b)]
        elif kind == "tileo":      # H2: tile with a per-wall offset / rotation / scale (breaks visible repeats)
            s, du, dv, rot = mode[1:5]
            cr, sr = math.cos(rot), math.sin(rot)
            uvs = [((x * cr - y * sr) / s + du, (x * sr + y * cr) / s + dv) for x, y in zip(a, b)]
        elif kind == "world":
            su, sv, du, dv = mode[1:5]
            nl = max(n.length, 1e-9)
            if abs(n.z) > 0.72 * nl:
                uvs = [(p.x / su + du, p.y / sv + dv) for p in pts]
            elif abs(n.x) > abs(n.y):
                uvs = [(p.y / su + du, p.z / sv + dv) for p in pts]
            else:
                uvs = [(p.x / su + du, p.z / sv + dv) for p in pts]
        elif kind == "worldreg":
            u0, v0, u1, v1, su, sv, du, dv = mode[1:9]
            nl = max(n.length, 1e-9)
            if abs(n.z) > 0.72 * nl:
                uvs = [(u0 + ((p.x / su + du) % 1.0) * (u1 - u0),
                        v0 + ((p.y / sv + dv) % 1.0) * (v1 - v0)) for p in pts]
            elif abs(n.x) > abs(n.y):
                uvs = [(u0 + ((p.y / su + du) % 1.0) * (u1 - u0),
                        v0 + ((p.z / sv + dv) % 1.0) * (v1 - v0)) for p in pts]
            else:
                uvs = [(u0 + ((p.x / su + du) % 1.0) * (u1 - u0),
                        v0 + ((p.z / sv + dv) % 1.0) * (v1 - v0)) for p in pts]
        elif kind == "trimreg":
            u0, u1, v0, v1, s = mode[1], mode[2], mode[3], mode[4], mode[5]
            ea, eb = max(a) - min(a), max(b) - min(b)
            if ea >= eb:
                uvs = [(u0 + ((x / s) % 1.0) * (u1 - u0),
                        v0 + (y - min(b)) / max(eb, 1e-6) * (v1 - v0)) for x, y in zip(a, b)]
            else:
                uvs = [(u0 + ((y / s) % 1.0) * (u1 - u0),
                        v0 + (x - min(a)) / max(ea, 1e-6) * (v1 - v0)) for x, y in zip(a, b)]
        elif kind == "trim":
            v0, v1, s = mode[1], mode[2], mode[3]
            ea, eb = max(a) - min(a), max(b) - min(b)
            if ea >= eb:
                uvs = [(x / s, v0 + (y - min(b)) / max(eb, 1e-6) * (v1 - v0)) for x, y in zip(a, b)]
            else:
                uvs = [(y / s, v0 + (x - min(a)) / max(ea, 1e-6) * (v1 - v0)) for x, y in zip(a, b)]
        elif kind == "uv":
            uvs = [tuple(uv) for uv in mode[1]]
            if flipped:
                uvs.reverse()
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

    def box_modes(self, lo, hi, modes, skip=()):
        """box() with a per-face UV mode: modes keys "-x","+x","-y","+y","-z","+z", plus "any"."""
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
                self.face(q, modes.get(k, modes["any"]), centre=c)

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

    def extrude(self, profile, axis, a0, a1, mode, caps=True, cap_mode=None):
        """Extrude any simple 2D profile (convex or not, either winding) along axis 'x' | 'y' | 'z' from a0 to a1.
        mode: a UV mode, a list of modes (one per profile edge i -> i+1) or a callable(i) -> mode. Faces are oriented
        by the edge's outward normal, so concave profiles (sawtooth, channels, gutters) come out right."""
        self.prim += 1

        def P(s, t, a):
            return {"x": (a, s, t), "y": (s, a, t), "z": (s, t, a)}[axis]
        prof = [tuple(p) for p in profile]
        sg = 1.0 if area2d(prof) > 0 else -1.0
        n = len(prof)
        for i in range(n):
            p, q = prof[i], prof[(i + 1) % n]
            ds, dt = q[0] - p[0], q[1] - p[1]
            if abs(ds) + abs(dt) < 1e-9:
                continue
            m = mode(i) if callable(mode) else (mode[i] if isinstance(mode, list) else mode)
            self.face([P(p[0], p[1], a0), P(q[0], q[1], a0), P(q[0], q[1], a1), P(p[0], p[1], a1)], m,
                      outward=P(dt * sg, -ds * sg, 0.0))
        if caps:
            for a, sa in ((a0, -1.0 if a1 > a0 else 1.0), (a1, 1.0 if a1 > a0 else -1.0)):
                self.face([P(p[0], p[1], a) for p in prof], cap_mode or (mode if isinstance(mode, tuple) else ("tile", 1.0)),
                          outward=P(0.0, 0.0, sa))

    def pierced(self, poly, axis, a0, a1, holes, mode, eps=1e-4):
        """A wall slab: convex profile `poly` (in the two non-axis coords, second = up) extruded along `axis` from a0 to
        a1, with rectangular holes (h0, h1, z0, z1) through it, split into convex prisms (vertical strips)."""
        hmin, hmax = min(p[0] for p in poly), max(p[0] for p in poly)
        hs = sorted(set([hmin, hmax] + [min(max(h, hmin), hmax) for hole in holes for h in hole[:2]]))
        for ha, hb in zip(hs, hs[1:]):
            if hb - ha < eps:
                continue
            hm = (ha + hb) / 2
            cut = sorted((hole[2], hole[3]) for hole in holes if hole[0] < hm < hole[1])
            bands, z = [], -1e9
            for z0, z1 in cut:
                bands.append((z, z0))
                z = max(z, z1)
            bands.append((z, 1e9))
            for za, zb in bands:
                if zb - za < eps:
                    continue
                pc = poly
                for k, val, ge in ((0, ha, True), (0, hb, False), (1, za, True), (1, zb, False)):
                    pc = clip2d(pc, k, val, ge)
                pc = dedupe2d(pc)
                if len(pc) >= 3 and abs(area2d(pc)) > 1e-6:
                    self.prism(pc, axis, a0, a1, mode)

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
            if not _keep(lv, lod):
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


def _keep(lv, lod):
    return (lod in lv) if isinstance(lv, (tuple, list, set, frozenset)) else lv > lod


def area2d(poly):
    return 0.5 * sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(poly, poly[1:] + poly[:1]))


def clip2d(poly, k, val, keep_ge):
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        pin = p[k] >= val if keep_ge else p[k] <= val
        qin = q[k] >= val if keep_ge else q[k] <= val
        if pin:
            out.append(p)
        if pin != qin:
            t = (val - p[k]) / (q[k] - p[k])
            out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
    return out


def dedupe2d(poly, eps=1e-6):
    out = []
    for p in poly:
        if not out or abs(p[0] - out[-1][0]) + abs(p[1] - out[-1][1]) > eps:
            out.append(p)
    while len(out) > 1 and abs(out[0][0] - out[-1][0]) + abs(out[0][1] - out[-1][1]) <= eps:
        out.pop()
    return out


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

    def h(self, s):
        """World coordinate along the wall (x for walls facing +-Y, y for walls facing +-X) of frame position s."""
        return (self.a.x if abs(self.n.y) > 0.5 else self.a.y) * s

    def prism(self, part, s0, s1, prof, mode, caps=True, cap_mode=None):
        """Extrude a profile of (o, t) points along the wall from s0 to s1 (concave profiles allowed)."""
        p0, p1 = self.world(s0, 0, 0), self.world(s1, 0, 0)
        if abs(self.n.y) > 0.5:
            axis, a0, a1, w = "x", min(p0.x, p1.x), max(p0.x, p1.x), [(self.f + self.n.y * o, t) for o, t in prof]
        else:
            axis, a0, a1, w = "y", min(p0.y, p1.y), max(p0.y, p1.y), [(self.f + self.n.x * o, t) for o, t in prof]
        part.extrude(w, axis, a0, a1, mode, caps, cap_mode)

    def plate(self, part, poly, o0, o1, mode):
        """Extrude a (s, t) outline out of the wall from o0 to o1 (keystones, brackets)."""
        nn = self.n.y if abs(self.n.y) > 0.5 else self.n.x
        axis = "y" if abs(self.n.y) > 0.5 else "x"
        part.extrude([(self.h(s), t) for s, t in poly], axis, min(self.f + nn * o0, self.f + nn * o1),
                     max(self.f + nn * o0, self.f + nn * o1), mode)
