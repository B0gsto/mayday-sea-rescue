"""Mesh builder for M_Upg_JetSki: closed shells with explicit vertex normals, so one-segment chamfers shade round for few tris.

Authored in the concept frame: X starboard, Y up (keel 0), Z aft (bow at -Z). lod 0 / 1 / 2 thins segments, studs and bevels.
"""
import math

from mathutils import Matrix, Vector

import palette as PAL

STUD_P, STUD_R, STUD_H = 0.8, 0.27, 0.2     # AD round 2: chunkier than the concept's 0.5 / 0.17 / 0.15, so studs read on a phone
Y_UP = Vector((0, 1, 0))


def orient(at, direction):
    """Matrix taking local +Y to `direction`, local origin to `at`."""
    q = Y_UP.rotation_difference(Vector(direction).normalized())
    return Matrix.Translation(at) @ q.to_matrix().to_4x4()


class B:
    def __init__(self, lod=0):
        self.lod = lod
        self.v, self.n, self.f, self.want, self.vuv = [], [], [], {}, {}

    def seg(self, n):
        return n if self.lod == 0 else max(6, int(n * 0.5)) if self.lod == 1 else max(4, n // 3)

    def emit(self, verts, normals, faces, cell, T=None):
        base = len(self.v)
        T = T or Matrix.Identity(4)
        R = T.to_3x3()
        self.v += [T @ Vector(p) for p in verts]
        self.n += [(R @ Vector(q)).normalized() for q in normals]
        c = PAL.CELL[cell] if isinstance(cell, str) else cell
        for i, fc in enumerate(faces):
            self.f.append((tuple(base + j for j in fc), c[i] if isinstance(c, list) else c))
        return base

    def tris(self):
        return sum(len(f) - 2 for f, _ in self.f)

    # ------------------------------------------------------------ bricks
    def rbox(self, c, size, cell, r=0.12, T=None, soft=False):
        """Rounded box at c (in T's frame): one chamfer with main-face normals, or cube-sphere grid when soft."""
        hx, hy, hz = (s / 2 for s in size)
        L = Matrix.Translation(c)
        T2 = (T @ L) if T else L
        r = min(r, 0.45 * min(size))
        if self.lod == 2:
            r = 0
        if soft and self.lod < 2:
            return self._soft(hx, hy, hz, r, 3 if self.lod == 0 else 2, cell, T2)
        if r <= 0:
            vs = [(sx * hx, sy * hy, sz * hz) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
            fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
            # shortcut: LOD2 boxes share corners, so they shade soft; only seen far away
            return self.emit(vs, [Vector(p).normalized() for p in vs], fs, cell, T2)
        vs, ns, ix = [], [], {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    for a, p, q in ((0, (sx * hx, sy * (hy - r), sz * (hz - r)), (sx, 0, 0)),
                                    (1, (sx * (hx - r), sy * hy, sz * (hz - r)), (0, sy, 0)),
                                    (2, (sx * (hx - r), sy * (hy - r), sz * hz), (0, 0, sz))):
                        ix[(sx, sy, sz, a)] = len(vs)
                        vs.append(p)
                        ns.append(q)
        fs = []
        for s in (-1, 1):
            fs.append(tuple(ix[(s, a, b, 0)] for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))))
            fs.append(tuple(ix[(a, s, b, 1)] for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))))
            fs.append(tuple(ix[(a, b, s, 2)] for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))))
        for a in (-1, 1):
            for b in (-1, 1):
                fs.append((ix[(-1, a, b, 1)], ix[(1, a, b, 1)], ix[(1, a, b, 2)], ix[(-1, a, b, 2)]))
                fs.append((ix[(a, -1, b, 0)], ix[(a, 1, b, 0)], ix[(a, 1, b, 2)], ix[(a, -1, b, 2)]))
                fs.append((ix[(a, b, -1, 0)], ix[(a, b, 1, 0)], ix[(a, b, 1, 1)], ix[(a, b, -1, 1)]))
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    fs.append((ix[(sx, sy, sz, 0)], ix[(sx, sy, sz, 1)], ix[(sx, sy, sz, 2)]))
        return self.emit(vs, ns, fs, cell, T2)

    def _soft(self, hx, hy, hz, r, seg, cell, T):
        h = (hx, hy, hz)
        steps = [lambda a, i=i: -a + r * i / seg for i in range(seg + 1)] + [lambda a, i=i: a - r + r * i / seg for i in range(seg + 1)]
        ix, vs, ns, fs = {}, [], [], []

        def vert(q):
            inner = [max(-(h[k] - r), min(h[k] - r, q[k])) for k in range(3)]
            d = Vector(q) - Vector(inner)
            nrm = d.normalized()
            p = Vector(inner) + nrm * r
            key = tuple(round(x, 5) for x in p)
            if key not in ix:
                ix[key] = len(vs)
                vs.append(p)
                ns.append(nrm)
            return ix[key]
        for axis in range(3):
            a, b = (axis + 1) % 3, (axis + 2) % 3
            for s in (-1, 1):
                grid = []
                for fu in steps:
                    row = []
                    for fv in steps:
                        q = [0, 0, 0]
                        q[axis], q[a], q[b] = s * h[axis], fu(h[a]), fv(h[b])
                        row.append(vert(q))
                    grid.append(row)
                for i in range(len(steps) - 1):
                    for j in range(len(steps) - 1):
                        fs.append((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
        return self.emit(vs, ns, fs, cell, T)

    def studs(self, c, size, cell, T=None, xs=None, mask=None):
        """Studs at 0.5 pitch on the +Y face of a box at c, like the concept's brick()."""
        if self.lod == 2:
            return
        w, h, d = size
        nx, nz = max(1, int(w / STUD_P + 1e-6)), max(1, int(d / STUD_P + 1e-6))
        xs = xs or [(i - (nx - 1) / 2) * STUD_P for i in range(nx)]
        for lx in xs:
            for j in range(nz):
                lz = (j - (nz - 1) / 2) * STUD_P
                if not mask or mask(lx, lz):
                    self.stud((c[0] + lx, c[1] + h / 2, c[2] + lz), cell, T)

    def stud(self, at, cell, T=None):
        if self.lod == 2:
            return
        L = Matrix.Translation(at)
        prof = [(0, STUD_H), (STUD_R - 0.04, STUD_H), (STUD_R, STUD_H - 0.04), (STUD_R, -0.02)] if self.lod == 0 else [(0, STUD_H), (STUD_R, STUD_H), (STUD_R, -0.02)]
        self.revolve(prof, cell, 10 if self.lod == 0 else 6, (T @ L) if T else L, open_end=True)

    # ------------------------------------------------------------ round parts
    def revolve(self, prof, cell, n, T=None, open_end=False):
        """Lathe about local +Y; prof = (radius, y). r = 0 ends close flat (same y as the next point) or to a pole. Corners over 40 degrees stay hard."""
        if self.lod == 2 and len(prof) > 4:
            prof = [prof[0]] + list(prof[1:-1:2]) + [prof[-1]]
        pts = [(max(r, 0.0), y) for r, y in prof]
        segn = []
        for (r0, y0), (r1, y1) in zip(pts, pts[1:]):
            a = Vector((y1 - y0, r0 - r1))         # outward for a profile walked bottom to top, flipped by recalc anyway
            segn.append(a.normalized() if a.length else Vector((1, 0)))
        vs, ns, fs = [], [], []

        def ring(p, nrm):
            base = len(vs)
            for k in range(n):
                t = 2 * math.pi * k / n
                vs.append((p[0] * math.sin(t), p[1], p[0] * math.cos(t)))
                ns.append((nrm[0] * math.sin(t), nrm[1], nrm[0] * math.cos(t)))
            return base
        sign = 1 if pts[0][1] <= pts[-1][1] else -1
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            m = segn[i] * sign

            def nrm_at(j, other):
                if other is None:
                    return m
                o = segn[other] * sign
                return (m + o).normalized() if m.dot(o) > 0.766 else m
            n0, n1 = nrm_at(i, i - 1 if i > 0 else None), nrm_at(i + 1, i + 1 if i + 1 < len(segn) else None)
            if p0[0] < 1e-5 and p1[0] < 1e-5:
                continue
            if p0[0] < 1e-5 or p1[0] < 1e-5:
                tip, rim, nr = (p0, p1, n1) if p0[0] < 1e-5 else (p1, p0, n0)
                r = ring(rim, nr)
                if abs(tip[1] - rim[1]) < 1e-5:
                    fs.append(tuple(r + k for k in range(n)))
                else:
                    pole = len(vs)
                    vs.append((0, tip[1], 0))
                    ns.append((0, 1 if tip[1] > rim[1] else -1, 0))
                    fs += [(r + k, r + (k + 1) % n, pole) for k in range(n)]
                continue
            a, b = ring(p0, n0), ring(p1, n1)
            fs += [(a + k, a + (k + 1) % n, b + (k + 1) % n, b + k) for k in range(n)]
        if not open_end and pts[0][0] > 1e-5:
            fs.append(tuple(k for k in range(n)))
        return self.emit(vs, ns, fs, cell, T)

    def lathe(self, base, direction, prof, cell, n=12, T=None):
        M = orient(base, direction)
        return self.revolve(prof, cell, self.seg(n), (T @ M) if T else M)

    def sphere(self, c, r, cell, n=10, scale=(1, 1, 1), T=None):
        k = max(3, self.seg(n) // 2)
        prof = [(r * math.sin(math.pi * i / k), -r * math.cos(math.pi * i / k)) for i in range(k + 1)]
        L = Matrix.Translation(c) @ Matrix.Diagonal((*scale, 1))
        return self.revolve(prof, cell, self.seg(n), (T @ L) if T else L)

    def torus(self, c, R, r, cell, maj=20, mnr=7, T=None, cells=None):
        """Ring round local Y. cells(k) colours per major segment."""
        maj, mnr = self.seg(maj), max(4, self.seg(mnr))
        if cells:           # keep whole colour runs
            maj = max(16, maj // 8 * 8)
        vs, ns, fs, cs = [], [], [], []
        for i in range(maj):
            a = 2 * math.pi * i / maj
            for j in range(mnr):
                b = 2 * math.pi * j / mnr
                vs.append((math.sin(a) * (R + r * math.cos(b)), r * math.sin(b), math.cos(a) * (R + r * math.cos(b))))
                ns.append((math.sin(a) * math.cos(b), math.sin(b), math.cos(a) * math.cos(b)))
        for i in range(maj):
            for j in range(mnr):
                i2, j2 = (i + 1) % maj, (j + 1) % mnr
                fs.append((i * mnr + j, i2 * mnr + j, i2 * mnr + j2, i * mnr + j2))
                if cells:
                    cs.append(PAL.CELL[cells(i * 8 // maj)])
        L = Matrix.Translation(c)
        return self.emit(vs, ns, fs, cs if cells else cell, (T @ L) if T else L)

    def tube(self, pts, r, cell, rs=8, f=0.15, fseg=4, T=None):
        """Round tube through pts with quadratic fillets (the concept's pathOf) and flat caps."""
        pts = [Vector(p) for p in pts]
        path = [pts[0]]
        for k in range(1, len(pts) - 1):
            a, p, b = pts[k - 1], pts[k], pts[k + 1]
            p1 = p - (p - a).normalized() * min(f, (p - a).length / 2)
            p2 = p + (b - p).normalized() * min(f, (b - p).length / 2)
            fs_ = max(2, self.seg(fseg) if self.lod else fseg)
            path += [(1 - t) ** 2 * p1 + 2 * (1 - t) * t * p + t * t * p2 for t in (i / fs_ for i in range(fs_ + 1))]
        path.append(pts[-1])
        return self.sweep(path, [r] * len(path), cell, self.seg(rs), T)

    def sweep(self, path, radii, cell, rs, T=None, cells=None):
        """Rings along a path by parallel transport, flat caps. cells: list of cell names per segment."""
        tangents = []
        for i in range(len(path)):
            a, b = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
            tangents.append((b - a).normalized())
        up = Vector((1, 0, 0)) if abs(tangents[0].x) < 0.9 else Vector((0, 1, 0))
        ex = tangents[0].cross(up).normalized()
        vs, ns, fs, cs = [], [], [], []
        for i, (p, t) in enumerate(zip(path, tangents)):
            ex = (ex - t * ex.dot(t)).normalized()
            ey = t.cross(ex)
            for j in range(rs):
                a = 2 * math.pi * j / rs
                d = ex * math.cos(a) + ey * math.sin(a)
                vs.append(p + d * radii[i])
                ns.append(d)
        for i in range(len(path) - 1):
            for j in range(rs):
                j2 = (j + 1) % rs
                fs.append((i * rs + j, (i + 1) * rs + j, (i + 1) * rs + j2, i * rs + j2))
                if cells:
                    cs.append(PAL.CELL[cells[i]])
        for i, t in ((0, -tangents[0]), (len(path) - 1, tangents[-1])):
            base = len(vs)
            for j in range(rs):
                vs.append(vs[i * rs + j])
                ns.append(t)
            fs.append(tuple(base + j for j in range(rs)))
            if cells:
                cs.append(PAL.CELL[cells[0 if i == 0 else -1]])
        return self.emit(vs, ns, fs, cs if cells else cell, T)

    # ------------------------------------------------------------ flat shapes
    def extrude(self, poly, half, bevel_t, bevel_s, cell, T=None):
        """2D outline (shape x -> Z, shape y -> Y) with thickness along X, chamfered like the concept's ExtrudeGeometry."""
        n = len(poly)
        P = [Vector(p) for p in poly]
        area = sum(P[i].x * P[(i + 1) % n].y - P[(i + 1) % n].x * P[i].y for i in range(n))
        out = []
        for i in range(n):
            e0, e1 = (P[i] - P[i - 1]).normalized(), (P[(i + 1) % n] - P[i]).normalized()
            m = Vector((e0.y + e1.y, -e0.x - e1.x))
            m = m.normalized() if m.length > 1e-4 else Vector((e1.y, -e1.x))
            out.append(m if area > 0 else -m)
        vs, ns = [], []

        def ring(t, grow, nrm):
            for p, o in zip(P, out):
                q = p + o * grow
                vs.append((-t, q.y, q.x))
                ns.append((-nrm[0], nrm[1] if nrm[1] else o.y, nrm[2] if nrm[2] else o.x))
        ring(half + bevel_t, 0, (1, 0, 0))
        ring(half, bevel_s, (0, 0, 0))
        ring(-half, bevel_s, (0, 0, 0))
        ring(-half - bevel_t, 0, (-1, 0, 0))
        fs = [tuple(range(n)), tuple(3 * n + k for k in range(n))]
        for r in range(3):
            for k in range(n):
                k2 = (k + 1) % n
                fs.append((r * n + k, r * n + k2, (r + 1) * n + k2, (r + 1) * n + k))
        return self.emit(vs, ns, fs, cell, T)

    def prism(self, tri, z0, z1, cell, T):
        """Flat-shaded triangular prism in T's XY plane, extruded along +Z; the base face is left off."""
        vs, ns = [], []
        fs = []
        a, b, c = (Vector((*p, 0)) for p in tri)
        for p in (a, b, c):
            vs.append((p.x, p.y, z1))
            ns.append((0, 0, 1))
        fs.append((0, 1, 2))
        for p, q in ((a, b), (b, c), (c, a)):
            e = q - p
            nrm = Vector((e.y, -e.x, 0)).normalized()
            if nrm.dot((a + b + c) / 3 - p) > 0:
                nrm = -nrm
            base = len(vs)
            vs += [(p.x, p.y, z0), (q.x, q.y, z0), (q.x, q.y, z1), (p.x, p.y, z1)]
            ns += [nrm] * 4
            fs.append((base, base + 1, base + 2, base + 3))
        return self.emit(vs, ns, fs, cell, T)

    def patch(self, rows, uvs, normals):
        """One open surface from a vertex grid with its own atlas UVs (the printed sticker and text)."""
        ni, nj = len(rows), len(rows[0])
        base = len(self.v)
        for i in range(ni):
            for j in range(nj):
                self.v.append(Vector(rows[i][j]))
                self.n.append(Vector(normals[i][j]))
                self.vuv[base + i * nj + j] = uvs[i][j]
        for i in range(ni - 1):
            for j in range(nj - 1):
                a = base + i * nj + j
                self.want[len(self.f)] = (normals[i][j][0], normals[i][j][1], normals[i][j][2])
                self.f.append(((a, a + nj, a + nj + 1, a + 1), 0))

    # ------------------------------------------------------------ to Blender
    def to_mesh(self, name, material, off):
        """Concept frame -> pipeline frame: bx = -X, by = Z + off (the shipped hull's recentre), bz = Y."""
        import bmesh
        import bpy
        conv = lambda p, o=0.0: (-p[0], p[2] + o, p[1])
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([conv(p, off) for p in self.v], [], [fc for fc, _ in self.f])
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.faces.ensure_lookup_table()
        for fi, n in self.want.items():
            f = bm.faces[fi]
            if f.normal.dot(Vector(conv(n))) < 0:
                f.normal_flip()
        bm.to_mesh(mesh)
        bm.free()
        uv = mesh.uv_layers.new(name="UVMap")
        G = PAL.GRID
        for poly, (_, c) in zip(mesh.polygons, self.f):
            col, row = c % G, c // G
            u0, u1 = (col + 0.1) / G, (col + 0.9) / G
            v0, v1 = (row + 0.1) / G, (row + 0.9) / G
            k = len(poly.loop_indices)
            for m, li in enumerate(poly.loop_indices):
                vi = mesh.loops[li].vertex_index
                if vi in self.vuv:
                    uv.data[li].uv = self.vuv[vi]
                else:
                    a = 2 * math.pi * m / k
                    uv.data[li].uv = ((u0 + u1) / 2 + (u1 - u0) / 2 * math.cos(a), (v0 + v1) / 2 + (v1 - v0) / 2 * math.sin(a))
        mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
        mesh.normals_split_custom_set_from_vertices([conv(n) for n in self.n])
        mesh.update()
        mesh.materials.append(material)
        return mesh

    def to_object(self, name, material, off):
        import bpy
        obj = bpy.data.objects.new(name, self.to_mesh(name, material, off))
        bpy.context.scene.collection.objects.link(obj)
        return obj


def material(name, stem):
    """One palette material: ALB / RGH / MET cells from T_<stem>_{ALB,RGH,MET}.png."""
    import bpy
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    for kind, sock, cs in (("ALB", "Base Color", "sRGB"), ("RGH", "Roughness", "Non-Color"), ("MET", "Metallic", "Non-Color")):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(stem + kind + ".png", check_existing=True)
        tex.image.colorspace_settings.name = cs
        tex.interpolation = "Closest" if kind != "ALB" else "Linear"
        nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        nt.links.new(tex.outputs["Color"], bsdf.inputs[sock])
    return mat
