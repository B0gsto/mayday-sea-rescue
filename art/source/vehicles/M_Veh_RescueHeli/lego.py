"""Tiny Lego mesh builder (copied from M_Prop_BoardKit; flat palette, chunky bricks, round studs).

Every primitive writes separate shells; normals are recalculated outward per shell. One mesh = one material (the
palette atlas), colours are palette cells in the UVs, so a whole construction layer is one draw call.
"""
import math

import palette as P

BEVEL = 0.14          # top-edge chamfer of a brick, studs (1 stud = 1/3 m in game units)
STUD_H = 0.5


class B:
    def __init__(self):
        self.v = []
        self.f = []        # (indices, palette cell)
        self.smooth = []   # per face: smooth (round parts) or flat (bricks: chamfers stay crisp facets)
        self.want = {}     # face index -> outward normal for single-sided quads (no shell to orient them)

    def _emit(self, verts, faces, c, smooth=False):
        """Append one closed shell: vertices are shared inside the shell (manifold), never across shells."""
        base = len(self.v)
        self.v.extend(verts)
        for face in faces:
            self.f.append((tuple(base + i for i in face), c))
            self.smooth.append(smooth)

    def quad(self, pts, c, n):
        """One single-sided face (LOD tiles), n = its outward normal."""
        self.want[len(self.f)] = n
        self._emit(pts, [(0, 1, 2, 3)], c)

    # ---------------------------------------------------------------- bricks and plates
    def box(self, lo, hi, c, bevel=None, drop=()):
        """drop: face indices left out where something hides them (0 bottom, 1 top, 2 -y, 3 +x, 4 +y, 5 -x)."""
        x0, y0, z0 = lo
        x1, y1, z1 = hi
        if x1 < x0:
            x0, x1 = x1, x0
        if y1 < y0:
            y0, y1 = y1, y0
        if z1 < z0:
            z0, z1 = z1, z0
        b = BEVEL if bevel is None else bevel
        b = min(b, 0.22 * min(x1 - x0, y1 - y0, z1 - z0))
        bot = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)]
        top = [(x0 + b, y0 + b, z1), (x1 - b, y0 + b, z1), (x1 - b, y1 - b, z1), (x0 + b, y1 - b, z1)]
        faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._emit(bot + top, [f for i, f in enumerate(faces) if i not in drop], c)

    def bbox(self, lo, hi, c, b=0.08):
        """A box with all 12 edges chamfered by b (flat-shaded, so the chamfers catch light like a moulded brick)."""
        lo, hi = [min(lo[i], hi[i]) for i in range(3)], [max(lo[i], hi[i]) for i in range(3)]
        h = [(hi[i] - lo[i]) / 2 for i in range(3)]
        cen = [(hi[i] + lo[i]) / 2 for i in range(3)]
        b = min(b, 0.45 * min(h) * 2)
        sg = [(sx, sy, sz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        verts, idx = [], {}
        for s in sg:
            for a in range(3):          # vertex of corner s lying on the face normal to axis a
                verts.append(tuple(cen[k] + s[k] * (h[k] if k == a else h[k] - b) for k in range(3)))
                idx[s, a] = len(verts) - 1
        loop = ((-1, -1), (1, -1), (1, 1), (-1, 1))
        faces = []
        for a in range(3):
            o = [k for k in range(3) if k != a]
            for sa in (-1, 1):          # main face
                fs = []
                for p, q in loop:
                    s = [0, 0, 0]
                    s[a], s[o[0]], s[o[1]] = sa, p, q
                    fs.append(idx[tuple(s), a])
                faces.append(tuple(fs))
            for p, q in loop:           # chamfer along axis a at (p, q)
                s0, s1 = [0, 0, 0], [0, 0, 0]
                s0[a], s1[a] = -1, 1
                s0[o[0]] = s1[o[0]] = p
                s0[o[1]] = s1[o[1]] = q
                s0, s1 = tuple(s0), tuple(s1)
                faces.append((idx[s0, o[0]], idx[s1, o[0]], idx[s1, o[1]], idx[s0, o[1]]))
        for s in sg:
            faces.append((idx[s, 0], idx[s, 1], idx[s, 2]))
        self._emit(verts, faces, c)

    def stud(self, cx, cy, z, r, h, c, n=8, ch=0.05):
        """One Lego stud with a chamfered top edge (no bottom: it sinks into the brick)."""
        rings = [(r, z), (r, z + h - ch), (r - ch, z + h)] if ch else [(r, z), (r, z + h)]
        verts = [(cx + rr * math.cos(2 * math.pi * i / n), cy + rr * math.sin(2 * math.pi * i / n), zz)
                 for rr, zz in rings for i in range(n)]
        faces = [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i)
                 for k in range(len(rings) - 1) for i in range(n)]
        faces += [tuple(range((len(rings) - 1) * n, len(rings) * n)), tuple(reversed(range(n)))]
        self._emit(verts, faces, c, smooth=False)

    def sphere(self, cx, cy, cz, r, c, n=10, m=5, zmin=-1.0):
        """UV sphere (or the cap above zmin * r: dome lenses); closed with a flat bottom."""
        verts, rings = [], []
        for j in range(m + 1):
            t = math.asin(zmin) + (math.pi / 2 - math.asin(zmin)) * j / m
            if j == m:
                break
            rings.append(len(verts))
            for i in range(n):
                u = 2 * math.pi * i / n
                verts.append((cx + r * math.cos(t) * math.cos(u), cy + r * math.cos(t) * math.sin(u), cz + r * math.sin(t)))
        top = len(verts)
        verts.append((cx, cy, cz + r))
        faces = [(rings[k] + i, rings[k] + (i + 1) % n, rings[k + 1] + (i + 1) % n, rings[k + 1] + i)
                 for k in range(len(rings) - 1) for i in range(n)]
        faces += [(rings[-1] + i, rings[-1] + (i + 1) % n, top) for i in range(n)]
        faces.append(tuple(reversed(range(n))))
        self._emit(verts, faces, c, smooth=True)

    def studs(self, x0, x1, y0, y1, z, c, step=2.0, r=0.72, h=STUD_H, n=8):
        """A grid of round studs centred in the given top rectangle."""
        nx = max(1, int(round((x1 - x0) / step)))
        ny = max(1, int(round((y1 - y0) / step)))
        dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
        for ix in range(nx):
            for iy in range(ny):
                self.cyl(x0 + (ix + 0.5) * dx, y0 + (iy + 0.5) * dy, z, z + h, min(r, 0.42 * min(dx, dy)), c, n)

    def stud_row(self, x0, y0, x1, y1, z, c, spacing=2.4, r=0.72, h=STUD_H, n=8):
        """A single line of studs from (x0, y0) to (x1, y1) inclusive."""
        L = math.hypot(x1 - x0, y1 - y0)
        k = max(1, int(round(L / spacing)))
        for i in range(k + 1):
            t = i / k
            self.cyl(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, z, z + h, r, c, n)

    # ---------------------------------------------------------------- round bits
    def cyl(self, cx, cy, z0, z1, r, c, n=8, top=True, bottom=True):
        ring0 = [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), z0) for i in range(n)]
        ring1 = [(x, y, z1) for x, y, _ in ring0]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        if bottom:
            faces.append(tuple(reversed(range(n))))
        if top:
            faces.append(tuple(range(n, 2 * n)))
        self._emit(ring0 + ring1, faces, c, smooth=True)

    def cyl_x(self, cx, cy, cz, r, length, c, n=8):
        """A closed cylinder lying along X (rubber roller fenders)."""
        x0, x1 = cx - length / 2, cx + length / 2
        ring = [(cx, cy + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
        a = [(x0, y, z) for _, y, z in ring]
        b = [(x1, y, z) for _, y, z in ring]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        faces.append(tuple(reversed(range(n))))
        faces.append(tuple(range(n, 2 * n)))
        self._emit(a + b, faces, c)

    def torus(self, cx, cy, cz, R, r, c, maj=8, mnr=4, axis=0):
        """Tyre ring around the X axis (axis=1: around Y) at (cx, cy, cz)."""
        verts = []
        for i in range(maj):
            u = 2 * math.pi * i / maj
            radial = (0.0, math.cos(u), math.sin(u))
            for j in range(mnr):
                v = 2 * math.pi * j / mnr
                d = (r * math.sin(v), (R + r * math.cos(v)) * radial[1], (R + r * math.cos(v)) * radial[2])
                if axis:
                    d = (d[1], d[0], d[2])
                verts.append((cx + d[0], cy + d[1], cz + d[2]))
        faces = []
        for i in range(maj):
            for j in range(mnr):
                a, b = i * mnr, ((i + 1) % maj) * mnr
                k = (j + 1) % mnr
                faces.append((a + j, b + j, b + k, a + k))
        self._emit(verts, faces, c)

    def wheel(self, cx, cy, cz, R, r, c):
        self.torus(cx, cy, cz, R, r, c)

    # ---------------------------------------------------------------- angled bits
    def prof_x(self, x0, x1, profile, c):
        """A 2D (y, z) profile extruded along X (roof courses, gable triangles, hull sections)."""
        n = len(profile)
        verts = [(x0, y, z) for y, z in profile] + [(x1, y, z) for y, z in profile]
        faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
        faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        self._emit(verts, faces, c)

    def loft(self, sections, c):
        """A closed solid through equal-length rings of points (hull stations; caps at both ends)."""
        n = len(sections[0])
        verts = [p for sec in sections for p in sec]
        faces = []
        for s in range(len(sections) - 1):
            for i in range(n):
                j = (i + 1) % n
                a = s * n
                b = (s + 1) * n
                faces.append((a + i, a + j, b + j, b + i))
        faces.append(tuple(range(n)))
        faces.append(tuple(reversed(range((len(sections) - 1) * n, len(sections) * n))))
        self._emit(verts, faces, c, smooth=True)

    def beam(self, p0, p1, w, h, c):
        """A rectangular beam between two points (w across, h up)."""
        import mathutils
        p0, p1 = mathutils.Vector(p0), mathutils.Vector(p1)
        d = (p1 - p0).normalized()
        up = mathutils.Vector((0, 0, 1)) if abs(d.z) < 0.95 else mathutils.Vector((0, 1, 0))
        side = d.cross(up).normalized()
        up = side.cross(d).normalized()
        s, u = side * (w / 2), up * (h / 2)
        corners = [tuple(p0 - s - u), tuple(p0 + s - u), tuple(p0 + s + u), tuple(p0 - s + u),
                   tuple(p1 - s - u), tuple(p1 + s - u), tuple(p1 + s + u), tuple(p1 - s + u)]
        quads = ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
        self._emit(corners, quads, c)

    # ---------------------------------------------------------------- output
    def to_object(self, name, material, s=1.0):
        import bpy
        obj = bpy.data.objects.new(name, self.to_mesh(name, material, s))
        bpy.context.scene.collection.objects.link(obj)
        return obj

    def to_mesh(self, name, material, s=1.0):
        import bmesh
        import bpy
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([(x * s, y * s, z * s) for x, y, z in self.v], [], [i for i, _ in self.f])
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.faces.ensure_lookup_table()
        for fi, n in self.want.items():
            f = bm.faces[fi]
            if f.normal.dot(n) < 0:
                f.normal_flip()
        bm.to_mesh(mesh)
        bm.free()
        uv = mesh.uv_layers.new(name="UVMap")
        mesh.update()
        for poly, (_, c) in zip(mesh.polygons, self.f):
            col, row = c % P.GRID, c // P.GRID        # palette cell; the image's bottom row is UV v = 0
            u0, u1 = (col + 0.08) / P.GRID, (col + 0.92) / P.GRID
            v0, v1 = (row + 0.08) / P.GRID, (row + 0.92) / P.GRID
            lv = poly.loop_indices
            if len(lv) == 3:
                uv_corners = [(u0, v0), (u1, v0), ((u0 + u1) / 2, v1)]
            elif len(lv) == 4:
                uv_corners = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
            else:
                cx, cy = (u0 + u1) / 2, (v0 + v1) / 2
                rx, ry = (u1 - u0) / 2, (v1 - v0) / 2
                uv_corners = [(cx + rx * math.cos(2 * math.pi * k / len(lv)),
                               cy + ry * math.sin(2 * math.pi * k / len(lv))) for k in range(len(lv))]
            for li, uvc in zip(lv, uv_corners):
                uv.data[li].uv = uvc
        try:
            mesh.set_sharp_from_angle(angle=math.radians(50))
        except Exception:
            pass
        for poly, sm in zip(mesh.polygons, self.smooth):
            poly.use_smooth = sm
        mesh.materials.append(material)
        return mesh

    def tris(self):
        return sum(len(f) - 2 for f, _ in self.f)

    def empty(self):
        return not self.f


def material(name, albedo, rough=0.55):
    """One palette material: UV -> flat ALB cell. Reused by every mesh in the asset."""
    import bpy
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(albedo, check_existing=True)
    tex.image.colorspace_settings.name = "sRGB"
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def node(name):
    """An empty parent for one level / game node (kept in the .blend; FBX exports meshes only)."""
    import bpy
    e = bpy.data.objects.get(name)
    if e is not None:
        return e
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    return e


def attach(name, loc):
    import bpy
    e = bpy.data.objects.new(name, None)
    e.location = loc
    bpy.context.scene.collection.objects.link(e)
    return e
