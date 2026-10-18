"""HP2a harbour props (docs/12 2.3): geometry for every prop on the shared harbour prop atlas (atlas.py).

Runs inside Blender (tools/blender/run.py via each art/source/harbour/<Asset>/build.py, or run_all.py). Geometry is
authored in metres with the props kit Part (art/source/props/M_Prop_Chandlery/kit.py, imported read-only; this
folder's atlas.py is cached first so kit resolves `atlas` to it), front -Y, base at Z 0; Part.to_object writes studs.
Every MeshPart uses one set: Metal (T_HbrProps_Metal_*) or Rope (T_HbrProps_Rope_*), both with _Wet.
"""
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import atlas  # noqa: E402
sys.path.insert(1, os.path.join(G, "art/source/props/M_Prop_Chandlery"))
sys.path.insert(2, os.path.join(G, "tools/blender"))
import kit  # noqa: E402
from kit import Part, frame, fit_frame, axis_frame  # noqa: E402

assert kit.atlas is atlas, "kit.py must resolve atlas to the harbour prop atlas"
TEX_DIR = os.path.join(G, "assets/textures", atlas.ATLAS_ASSET)
STUDS = 3.0
_base_uvs = kit.face_uvs


def _face_uvs(pts, region, fit):
    if isinstance(fit, tuple) and fit and fit[0] == "uv":
        return list(fit[1]), 0
    return _base_uvs(pts, region, fit)


kit.face_uvs = _face_uvs


class HP(Part):
    def quad(self, pts, uvs, region):
        b = len(self.v)
        self.v.extend(Vector(p) for p in pts)
        self.f.append((list(range(b, b + len(pts))), region, ("uv", uvs)))

    def tube(self, pts, r, sides, region, closed=False, caps=True, k=2, rz=None):
        """Rope along a polyline in a periodic rope tile (whole tiles over the length; from M_Prop_Chandlery_Stock)."""
        P = [Vector(p) for p in pts]
        if closed:
            P = P + [P[0]]
        seg = [(P[i + 1] - P[i]).length for i in range(len(P) - 1)]
        Ltot = sum(seg)
        kind, per = atlas.R[region][4], atlas.R[region][5]
        period = per * 2 * r if kind == "rope" else per
        n = k * max(1, int(round(Ltot / period)))
        n = max(n, 2)
        cum = np.concatenate([[0.0], np.cumsum(seg)])
        Q = []
        for i in range(n + 1):
            s = Ltot * i / n
            j = min(int(np.searchsorted(cum, s, side="right")) - 1, len(seg) - 1)
            t = (s - cum[j]) / max(seg[j], 1e-9)
            Q.append(P[j].lerp(P[j + 1], t))
        if closed:
            Q = Q[:-1]
        m = len(Q)
        T = []
        for i in range(m):
            a, b = (Q[(i - 1) % m], Q[(i + 1) % m]) if closed else (Q[max(0, i - 1)], Q[min(m - 1, i + 1)])
            T.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = T[0].cross(ref).normalized()
        rings = []
        rzz = r if rz is None else rz
        for i in range(m):
            if i:
                nrm = (nrm - T[i] * nrm.dot(T[i])).normalized()
            bn = T[i].cross(nrm)
            rings.append([Q[i] + nrm * (r * math.cos(2 * math.pi * j / sides)) + bn * (rzz * math.sin(2 * math.pi * j / sides))
                          for j in range(sides)])
        u0, v0, u1, v1 = atlas.rect(region)
        du, dv = u1 - u0, v1 - v0
        nseg = m if closed else m - 1
        for i in range(nseg):
            A, B = rings[i], rings[(i + 1) % m]
            va, vb = v0 + dv * (i % k) / k, v0 + dv * (i % k + 1) / k
            for j in range(sides):
                j1 = (j + 1) % sides
                ua, ub = u0 + du * j / sides, u0 + du * (j + 1) / sides
                self.quad([A[j], B[j], B[j1], A[j1]], [(ua, va), (ua, vb), (ub, vb), (ub, va)], region)
        if caps and not closed:
            cu = [(u0 + du * (0.5 + 0.3 * math.cos(2 * math.pi * j / sides)), v0 + dv * (0.5 + 0.3 * math.sin(2 * math.pi * j / sides)))
                  for j in range(sides)]
            self.quad(list(reversed(rings[0])), list(reversed(cu)), region)
            self.quad(rings[-1], cu, region)

    def grid(self, fn, nu, nv, region, closed_u=False):
        """Surface from fn(u, v) -> (x, y, z) metres on an nu x nv quad grid (box-projected in the region)."""
        cols = nu if closed_u else nu + 1
        vs = [fn(i / nu, j / nv) for j in range(nv + 1) for i in range(cols)]
        faces = []
        for j in range(nv):
            for i in range(nu):
                i1 = (i + 1) % cols if closed_u else i + 1
                faces.append((j * cols + i, j * cols + i1, (j + 1) * cols + i1, (j + 1) * cols + i))
        self.mesh(vs, faces, region)

    def bolt(self, x, y, z, r, h, region, segs=6):
        self.cyl((x, y, z), (x, y, z + h), r, segs, region, split=1)

    # ------------------------------------------------------------ HP2a-fix primitives: shared verts + explicit UVs
    smooth = 40.0

    def uvmesh(self, verts, faces, uvs, region, M=None):
        """Faces with explicit per-loop UVs (atlas space) on SHARED vertices (smooth shading across UV seams)."""
        self.mesh(verts, faces, region, M, regions=[(region, ("uv", list(u))) for u in uvs])

    def hexbolt(self, x, y, z, s, region, washer=None, M=None):
        """Hex nut (across corners 2 s) on a round washer with the threaded stud end proud of the nut."""
        wr = s * 1.45 if washer is None else washer
        self.lathe([(wr, 0.0), (wr, 0.006), (wr * 0.9, 0.0075)], 10, region, (M or Matrix()) @ frame(x, y, z), cap0=False)
        h = s * 0.85
        self.lathe([(s, 0.0075), (s, 0.0075 + h * 0.8), (s * 0.86, 0.0075 + h)], 6, region,
                   (M or Matrix()) @ frame(x, y, z, yaw=15), cap0=False)
        self.lathe([(s * 0.5, 0.0075 + h), (s * 0.42, 0.0075 + h + 0.013), (0.0, 0.0075 + h + 0.016)],
                   6, region, (M or Matrix()) @ frame(x, y, z), cap0=False, cap1=False)

    def _span(self, region):
        k = atlas.kind(region)
        return (None if k == "fit" else (atlas.scale(region) or 1.0)), atlas.rect(region)

    def lathe_uv(self, profile, segs, region, M=None, rep_u=None, cap0=False, cap1=False, cap_region=None, v_tile=None):
        """Lathe with continuous UVs. fit regions: U once round, V = profile arc fraction. tile / net regions: U repeats
        rep_u whole tiles round, V runs in whole tiles of v_tile (default the region scale) along the profile arc, with
        a profile point inserted at every tile boundary so no quad straddles a tile edge (seamless periodic maps)."""
        S, (u0, v0, u1, v1) = self._span(region)
        du, dv = u1 - u0, v1 - v0
        prof = [tuple(p) for p in profile]
        cum = [0.0]
        for a, b in zip(prof[:-1], prof[1:]):
            cum.append(cum[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
        L = max(cum[-1], 1e-9)
        if S is None:
            rep_u = 1
            vs_ = [c / L for c in cum]
        else:
            Sv = v_tile or S
            pts, ss_ = [prof[0]], [0.0]
            for i in range(len(prof) - 1):
                a, b = prof[i], prof[i + 1]
                k0 = math.floor(cum[i] / Sv + 1e-6) + 1
                while k0 * Sv < cum[i + 1] - 1e-6:
                    t = (k0 * Sv - cum[i]) / max(cum[i + 1] - cum[i], 1e-12)
                    pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
                    ss_.append(k0 * Sv)
                    k0 += 1
                pts.append(b)
                ss_.append(cum[i + 1])
            prof = pts
            vs_ = [s / Sv for s in ss_]
            if rep_u is None:
                rep_u = max(1, int(round(2 * math.pi * max(r for r, _ in prof) / S)))
            segs = rep_u * max(1, int(math.ceil(segs / rep_u)))
        n = segs
        verts = [(r * math.cos(2 * math.pi * j / segs), r * math.sin(2 * math.pi * j / segs), z) for r, z in prof for j in range(n)]
        faces, uvs = [], []
        for k in range(len(prof) - 1):
            if S is None:
                va, vb = vs_[k], vs_[k + 1]
            else:
                base = math.floor(vs_[k] + 1e-6)
                va, vb = vs_[k] - base, min(vs_[k + 1] - base, 1.0)
            for j in range(segs):
                j1 = (j + 1) % n
                ua = ((j * rep_u) % segs) / segs
                ub = ua + rep_u / segs
                faces.append((k * n + j, k * n + j1, (k + 1) * n + j1, (k + 1) * n + j))
                uvs.append([(u0 + du * ua, v0 + dv * va), (u0 + du * ub, v0 + dv * va), (u0 + du * ub, v0 + dv * vb),
                            (u0 + du * ua, v0 + dv * vb)])
        b0 = len(self.v)
        self.uvmesh(verts, faces, uvs, region, M)
        cr = cap_region or region
        if cap0 and prof[0][0] > 1e-6:
            self.mesh(verts[:n], [tuple(reversed(range(n)))], cr, M)
        if cap1 and prof[-1][0] > 1e-6:
            last = (len(prof) - 1) * n
            self.mesh(verts[last:last + n], [tuple(range(n))], cr, M)
        return b0

    def torus_uv(self, R, r, segs, rsegs, region, M=None, sr=1.0, rep_u=1, rep_v=1):
        """Closed torus with continuous UVs: U round the big circle (rep_u tiles), V round the tube (rep_v tiles)."""
        _, (u0, v0, u1, v1) = self._span(region)
        du, dv = u1 - u0, v1 - v0
        verts = []
        for i in range(segs):
            t = 2 * math.pi * i / segs
            for j in range(rsegs):
                p = 2 * math.pi * j / rsegs
                rr = R + r * math.cos(p)
                verts.append((rr * math.cos(t), rr * math.sin(t), r * sr * math.sin(p)))
        faces, uvs = [], []
        for i in range(segs):
            i1 = (i + 1) % segs
            ua = ((i * rep_u) % segs) / segs
            ub = ua + rep_u / segs
            for j in range(rsegs):
                j1 = (j + 1) % rsegs
                va = ((j * rep_v) % rsegs) / rsegs
                vb = va + rep_v / rsegs
                faces.append((i * rsegs + j, i1 * rsegs + j, i1 * rsegs + j1, i * rsegs + j1))
                uvs.append([(u0 + du * ua, v0 + dv * va), (u0 + du * ub, v0 + dv * va), (u0 + du * ub, v0 + dv * vb),
                            (u0 + du * ua, v0 + dv * vb)])
        self.uvmesh(verts, faces, uvs, region, M)

    def tube2(self, pts, r, sides, region, closed=False, caps=True, max_step=None, rz=None, k=None):
        """Rope / rod along a polyline on shared vertices. Rings at every authored point (dense where the path bends),
        at every tile boundary along the length and wherever a gap exceeds max_step; V runs continuously in whole
        tiles (closed loops snap the period so the loop holds a whole number of tiles), U once round."""
        P = [Vector(p) for p in pts]
        if closed:
            P = P + [P[0]]
        cum = [0.0]
        for a, b in zip(P[:-1], P[1:]):
            cum.append(cum[-1] + (b - a).length)
        L = cum[-1]
        kind, per = atlas.R[region][4], atlas.R[region][5]
        period = per * 2 * r if kind == "rope" else per
        if closed or k:
            period = L / max(1, int(round(L / period)))
        step = max_step or period / 2
        S = []
        if k:   # uniform: k rings per tile (sparser than authored points; for gently curving thin lines)
            N = k * max(1, int(round(L / period)))
            S = [L * i / N for i in range(N)]
        for i in range(len(P) - 1):
            s0, s1 = cum[i], cum[i + 1]
            marks = [s0]
            k0 = math.floor(s0 / period + 1e-6) + 1
            while k0 * period < s1 - 1e-6:
                marks.append(k0 * period)
                k0 += 1
            marks.append(s1)
            if k:
                break
            for a, b in zip(marks[:-1], marks[1:]):
                m = max(1, int(math.ceil((b - a) / step - 1e-6)))
                S.extend(a + (b - a) * q / m for q in range(m))
        S.append(L)
        S = [s for k, s in enumerate(S) if k == 0 or s - S[k - 1] > 1e-6]

        def at(s):
            j = min(max(int(np.searchsorted(cum, s, side="right")) - 1, 0), len(P) - 2)
            t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-12)
            return P[j].lerp(P[j + 1], t)
        Q = [at(s) for s in S]
        if closed:
            Q, S = Q[:-1], S
        m = len(Q)
        T = []
        for i in range(m):
            a, b = (Q[(i - 1) % m], Q[(i + 1) % m]) if closed else (Q[max(0, i - 1)], Q[min(m - 1, i + 1)])
            T.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = T[0].cross(ref).normalized()
        rzz = r if rz is None else rz
        verts = []
        for i in range(m):
            if i:
                nrm = (nrm - T[i] * nrm.dot(T[i])).normalized()
            bn = T[i].cross(nrm)
            verts += [tuple(Q[i] + nrm * (r * math.cos(2 * math.pi * j / sides)) + bn * (rzz * math.sin(2 * math.pi * j / sides)))
                      for j in range(sides)]
        u0, v0, u1, v1 = atlas.rect(region)
        du, dv = u1 - u0, v1 - v0
        faces, uvs = [], []
        nseg = m if closed else m - 1
        for i in range(nseg):
            i1 = (i + 1) % m
            sa, sb = S[i], S[i + 1]
            base = math.floor(sa / period + 1e-6)
            va, vb = sa / period - base, min(sb / period - base, 1.0)
            for j in range(sides):
                j1 = (j + 1) % sides
                ua, ub = j / sides, (j + 1) / sides
                faces.append((i * sides + j, i1 * sides + j, i1 * sides + j1, i * sides + j1))
                uvs.append([(u0 + du * ua, v0 + dv * va), (u0 + du * ua, v0 + dv * vb), (u0 + du * ub, v0 + dv * vb),
                            (u0 + du * ub, v0 + dv * va)])
        self.uvmesh(verts, faces, uvs, region)
        if caps and not closed:
            cu = [(u0 + du * (0.5 + 0.3 * math.cos(2 * math.pi * j / sides)), v0 + dv * (0.5 + 0.3 * math.sin(2 * math.pi * j / sides)))
                  for j in range(sides)]
            last = (m - 1) * sides
            self.uvmesh([verts[j] for j in range(sides)], [tuple(reversed(range(sides)))], [list(reversed(cu))], region)
            self.uvmesh([verts[last + j] for j in range(sides)], [tuple(range(sides))], [cu], region)

    def grid_uv(self, fn, nu, nv, region, tiles_u, tiles_v, closed_u=False, keep=None):
        """fn(u, v) surface on an nu x nv grid; UVs run tiles_u x tiles_v whole tiles (nu, nv multiples of them).
        keep(i, j) -> bool drops quads (ragged edges)."""
        _, (u0, v0, u1, v1) = self._span(region)
        du, dv = u1 - u0, v1 - v0
        cols = nu if closed_u else nu + 1
        verts = [fn(i / nu, j / nv) for j in range(nv + 1) for i in range(cols)]
        faces, uvs = [], []
        pu, pv = nu / tiles_u, nv / tiles_v
        for j in range(nv):
            for i in range(nu):
                if keep is not None and not keep(i, j):
                    continue
                i1 = (i + 1) % cols if closed_u else i + 1
                ua, ub = (i % pu) / pu, (i % pu + 1) / pu
                va, vb = (j % pv) / pv, (j % pv + 1) / pv
                faces.append((j * cols + i, j * cols + i1, (j + 1) * cols + i1, (j + 1) * cols + i))
                uvs.append([(u0 + du * ua, v0 + dv * va), (u0 + du * ub, v0 + dv * va), (u0 + du * ub, v0 + dv * vb),
                            (u0 + du * ua, v0 + dv * vb)])
        self.uvmesh(verts, faces, uvs, region)

    def double(self, f0, eps=0.0008):
        """DoubleSided cards: copy faces f0.. with reversed winding on their own verts, pushed eps behind the front
        (never welded onto it), so the alpha nets read from both sides whatever the MeshPart DoubleSided flag."""
        src = self.f[f0:]
        used = sorted({i for idx, _, _ in src for i in idx})
        acc = {i: Vector((0, 0, 0)) for i in used}
        for idx, _, _ in src:
            nn = kit.newell([self.v[i] for i in idx])
            for i in idx:
                acc[i] += nn
        remap = {}
        for i in used:
            nv = acc[i].normalized() if acc[i].length > 1e-12 else Vector((0, 0, 1))
            remap[i] = len(self.v)
            self.v.append(self.v[i] - nv * eps)
        for idx, region, fit in src:
            nidx = [remap[i] for i in reversed(idx)]
            if isinstance(fit, tuple) and fit and fit[0] == "uv":
                fit = ("uv", list(reversed(fit[1])))
            self.f.append((nidx, region, fit))

    def to_object(self, obj_name, material, smooth_angle=None):
        """Part.to_object, then weld coincident verts (per-loop UVs kept) and re-mark sharp edges by angle."""
        import bmesh
        obj = Part.to_object(self, obj_name, material, self.smooth if smooth_angle is None else smooth_angle)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(obj.data)
        bm.free()
        for p in obj.data.polygons:
            p.use_smooth = True
        try:
            obj.data.set_sharp_from_angle(angle=math.radians(self.smooth if smooth_angle is None else smooth_angle))
        except Exception:
            pass
        obj.data.update()
        return obj


def material(name, set_name):
    rgb = (0.12, 0.11, 0.1) if set_name == "Metal" else (0.3, 0.32, 0.35)
    return kit.material("MI_%s_%s" % (atlas.NAME, name), rgb)


def box_col(asset, lo, hi):
    import bmesh
    bm = bmesh.new()
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    vs = [bm.verts.new((x * STUDS, y * STUDS, z * STUDS)) for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
    for f in [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(asset + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(asset + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def clean(obj):
    """Drop zero-area faces and loose verts (lathe poles, decimation collapses)."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    uvl = bm.loops.layers.uv.active

    def uv_area(f):
        if uvl is None:
            return 1.0
        p = [l[uvl].uv for l in f.loops]
        return abs(sum(p[i].x * p[(i + 1) % len(p)].y - p[(i + 1) % len(p)].x * p[i].y for i in range(len(p)))) / 2
    bad = [f for f in bm.faces if f.calc_area() <= 1e-8 or uv_area(f) <= 1e-10]
    if uvl is not None:
        for f in bm.faces:
            for l in f.loops:
                l[uvl].uv = (min(max(l[uvl].uv.x, 0.0), 1.0), min(max(l[uvl].uv.y, 0.0), 1.0))
    if bad:
        bmesh.ops.delete(bm, geom=bad, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def lod1(obj):
    import versions
    o = versions.copy_object(obj, obj.name.replace("_LOD0", "_LOD1"))
    versions.decimate(o, versions.triangles(obj.data) // 2)
    versions.weighted_normals(o)
    return clean(o)


def att(name, p_m):
    e = bpy.data.objects.new(name, None)
    e.location = tuple(c * STUDS for c in p_m)
    bpy.context.scene.collection.objects.link(e)
    return e


# ================================================================ bollards (cast iron, chipped black paint over rust)
def _grooves(prof, z0, z1, r, zs, depth=0.007, w=0.011):
    """Neck profile between z0 and z1 at radius r with rope-wear grooves (polished hollows) centred on zs."""
    out = [(r, z0)]
    for zc in zs:
        out += [(r, zc - w * 1.3), (r - depth * 0.55, zc - w * 0.6), (r - depth, zc), (r - depth * 0.55, zc + w * 0.6),
                (r, zc + w * 1.3)]
    out.append((r, z1))
    return prof + out


def _bands(P, prof, segs, worn=(0.0, 0.0), rust_top=0.07):
    """Lathe a bollard profile in bands with continuous UVs: rusted foot, painted body, polished neck, painted head."""
    cuts = sorted({rust_top, worn[0], worn[1]} - {0.0})
    zs = [z for _, z in prof]

    def sub(z0, z1):
        pts = [(r, z) for r, z in prof if z0 - 1e-9 <= z <= z1 + 1e-9]
        for zc in (z0, z1):
            if not any(abs(z - zc) < 1e-9 for _, z in pts):
                r = float(np.interp(zc, zs, [r for r, _ in prof]))
                pts.append((r, zc))
        return sorted(pts, key=lambda p: p[1])
    edges = [zs[0]] + [c for c in cuts if zs[0] < c < zs[-1]] + [zs[-1]]
    for a, b in zip(edges[:-1], edges[1:]):
        reg = "IronRust" if b <= rust_top + 1e-9 else ("IronWorn" if worn[0] - 1e-9 <= a and b <= worn[1] + 1e-9 else "IronBlack")
        P.lathe_uv(sub(a, b), segs, reg)


def bollard_01():
    """Mushroom-head harbour bollard, 0.55 m, on a square cast base plate held by four hex nuts on washers."""
    P = HP("Bollard01")
    P.box((-0.24, -0.24, 0.0), (0.24, 0.24, 0.035), "IronRust", skip=("-z",))
    P.box((-0.225, -0.225, 0.035), (0.225, 0.225, 0.045), "IronRust", skip=("-z",))
    P.lathe_uv([(0.215, 0.045), (0.212, 0.05), (0.196, 0.058), (0.186, 0.066)], 24, "IronRust")
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.hexbolt(sx * 0.178, sy * 0.178, 0.045, 0.03, "IronBlack")
    prof = [(0.186, 0.066), (0.178, 0.09), (0.168, 0.16), (0.158, 0.24), (0.151, 0.29)]
    prof = _grooves(prof, 0.30, 0.415, 0.148, (0.327, 0.36, 0.392))
    prof += [(0.153, 0.42), (0.168, 0.43), (0.198, 0.444), (0.213, 0.458), (0.218, 0.472), (0.214, 0.487), (0.204, 0.50),
             (0.184, 0.517), (0.15, 0.534), (0.10, 0.546), (0.05, 0.551), (0.0, 0.553)]
    _bands(P, prof, 24, worn=(0.295, 0.42), rust_top=0.09)
    return P, (0.48, 0.48, 0.553), [("ATT_RopeNeck", (0, 0, 0.37))], ((-0.24, -0.24, 0), (0.24, 0.24, 0.553))


def bollard_02():
    """Tee-head bollard, 0.6 m: tapered post with a horizontal cross horn through the head, bolted round flange."""
    P = HP("Bollard02")
    P.lathe_uv([(0.245, 0.0), (0.245, 0.04), (0.238, 0.05), (0.205, 0.056), (0.19, 0.07)], 24, "IronRust", cap0=False)
    prof = [(0.19, 0.07), (0.18, 0.12), (0.168, 0.22), (0.158, 0.31)]
    prof = _grooves(prof, 0.32, 0.455, 0.155, (0.35, 0.388, 0.425))
    prof += [(0.158, 0.47), (0.163, 0.5), (0.175, 0.525), (0.178, 0.55), (0.172, 0.57), (0.15, 0.588), (0.1, 0.597), (0.0, 0.601)]
    _bands(P, prof, 24, worn=(0.315, 0.46), rust_top=0.12)
    for sx in (-1, 1):  # horns, flared at the tips
        M, L = axis_frame((sx * 0.13, 0, 0.505), (sx * 0.30, 0, 0.515))
        P.lathe_uv([(0.058, 0.0), (0.052, L * 0.5), (0.054, L * 0.78), (0.064, L * 0.9), (0.06, L * 0.97), (0.045, L),
                    (0.0, L + 0.006)], 14, "IronBlack", M)
    for a in range(6):
        t = a * math.pi / 3 + 0.3
        P.hexbolt(0.218 * math.cos(t), 0.218 * math.sin(t), 0.04, 0.024, "IronBlack")
    return P, (0.62, 0.49, 0.601), [("ATT_RopeNeck", (0, 0, 0.38))], ((-0.30, -0.245, 0), (0.30, 0.245, 0.601))


def bollard_03():
    """Old cannon reused as a bollard (Cornish harbours): muzzle up, a cannon ball in the bore, set in a bolted iron
    ground collar, 0.58 m showing."""
    P = HP("Bollard03")
    P.lathe_uv([(0.27, 0.0), (0.27, 0.022), (0.255, 0.03), (0.22, 0.036), (0.198, 0.04)], 24, "IronRust", cap0=False)
    for a in range(4):
        t = a * math.pi / 2 + math.pi / 4
        P.hexbolt(0.238 * math.cos(t), 0.238 * math.sin(t), 0.022, 0.022, "IronBlack")
    prof = [(0.198, 0.04), (0.192, 0.09), (0.181, 0.18), (0.17, 0.23)]
    prof = _grooves(prof, 0.24, 0.395, 0.166, (0.28, 0.32, 0.36), depth=0.006)
    prof += [(0.158, 0.44), (0.155, 0.478), (0.172, 0.492), (0.18, 0.51), (0.181, 0.53), (0.168, 0.545), (0.171, 0.56),
             (0.166, 0.575), (0.12, 0.578)]
    _bands(P, prof, 24, worn=(0.235, 0.40), rust_top=0.10)
    # bore with a cannon ball (old harbour trick against rope cutting)
    P.lathe_uv([(0.12, 0.578), (0.106, 0.565), (0.0, 0.556)], 16, "IronRust")
    P.lathe_uv([(0.0, 0.55), (0.06, 0.556), (0.088, 0.572), (0.094, 0.59), (0.084, 0.606), (0.055, 0.617), (0.0, 0.621)], 16,
               "IronBlack")
    # reinforce rings
    P.torus_uv(0.177, 0.011, 24, 6, "IronBlack", frame(0, 0, 0.20))
    P.torus_uv(0.157, 0.009, 24, 6, "IronBlack", frame(0, 0, 0.455))
    return P, (0.54, 0.54, 0.621), [("ATT_RopeNeck", (0, 0, 0.33))], ((-0.27, -0.27, 0), (0.27, 0.27, 0.621))


# ================================================================ cleats (galvanised horn cleats)
def _cleat(P, L, H, base_w, region, bolts):
    P.box((-L * 0.36, -base_w / 2, 0.0), (L * 0.36, base_w / 2, 0.014), region, skip=("-z",))
    P.box((-L * 0.34, -base_w / 2 + 0.004, 0.014), (L * 0.34, base_w / 2 - 0.004, 0.018), region, skip=("-z",))
    for sx in (-1, 1):
        # waisted post (elliptic section), continuous UVs
        P.lathe_uv([(base_w * 0.34, 0.016), (base_w * 0.3, 0.03), (base_w * 0.26, H * 0.45), (base_w * 0.28, H * 0.68)], 16,
                   region, frame(sx * L * 0.2, 0, 0) @ Matrix.Diagonal((1.0, 0.75, 1.0, 1.0)))
    # the horn bar: thick in the middle, tapering to rounded tips, slight upturn; U round the bar, V along it
    xs = [-0.5, -0.47, -0.42, -0.34, -0.22, -0.1, 0.0, 0.1, 0.22, 0.34, 0.42, 0.47, 0.5]
    rad = [0.12, 0.3, 0.45, 0.62, 0.8, 0.88, 0.9, 0.88, 0.8, 0.62, 0.45, 0.3, 0.12]
    r0 = H * 0.2
    sides = 14
    verts = []
    for x, k in zip(xs, rad):
        z = H * (0.72 + 0.56 * x * x)
        verts += [(x * L, r0 * k * math.cos(2 * math.pi * j / sides) * 0.85, z + r0 * k * math.sin(2 * math.pi * j / sides))
                  for j in range(sides)]
    S = atlas.scale(region)
    u0, v0, u1, v1 = atlas.rect(region)
    faces, uvs = [], []
    for i in range(len(xs) - 1):
        va, vb = (xs[i] + 0.5) * L / max(S, L), (xs[i + 1] + 0.5) * L / max(S, L)
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((i * sides + j, i * sides + j1, (i + 1) * sides + j1, (i + 1) * sides + j))
            uvs.append([(u0 + (u1 - u0) * j / sides, v0 + (v1 - v0) * va), (u0 + (u1 - u0) * (j + 1) / sides, v0 + (v1 - v0) * va),
                        (u0 + (u1 - u0) * (j + 1) / sides, v0 + (v1 - v0) * vb), (u0 + (u1 - u0) * j / sides, v0 + (v1 - v0) * vb)])
    P.uvmesh(verts, faces, uvs, region)
    nl = (len(xs) - 1) * sides
    P.mesh(verts, [tuple(reversed(range(sides))), tuple(range(nl, nl + sides))], region)
    for b in bolts:
        P.hexbolt(b[0], b[1], 0.018, 0.009, region, washer=0.012)


def cleat_01():
    P = HP("Cleat01")
    _cleat(P, 0.30, 0.10, 0.075, "Galv", [(-0.09, 0, 0), (0.09, 0, 0)])
    return P, (0.30, 0.075, 0.10), [("ATT_Rope", (0, 0, 0.07))], ((-0.15, -0.04, 0), (0.15, 0.04, 0.10))


def cleat_02():
    P = HP("Cleat02")
    _cleat(P, 0.45, 0.15, 0.11, "GalvRust", [(-0.135, -0.03, 0), (-0.135, 0.03, 0), (0.135, -0.03, 0), (0.135, 0.03, 0)])
    return P, (0.45, 0.11, 0.15), [("ATT_Rope", (0, 0, 0.105))], ((-0.225, -0.055, 0), (0.225, 0.055, 0.15))


# ================================================================ fenders (PVC cylinder x3, ball, tyre)
def _eye_line(P, zb, rl, end, region="RopeBlue", r=0.0065):
    """Fender line: a hitch round the top bar of a moulded eye (bar along X at height zb) and the standing part up."""
    P.tube2([(0.004 * math.sin(4 * math.pi * k / 10), rl * math.cos(2 * math.pi * k / 10), zb + rl * math.sin(2 * math.pi * k / 10))
             for k in range(10)], r, 6, region, closed=True)
    P.tube2([(0.0, 0.0, zb + rl), (0.004, 0.0, zb + rl + 0.03), (end[0] * 0.5, end[1] * 0.5, (zb + rl + end[2]) / 2),
             tuple(end)], r, 6, region)


def _cyl_fender(name, D, L, region, eye_region):
    """PVC cylinder fender: one lathe (smooth shoulders, 28 sides) mapped once round the body onto its own decal
    (mould seams, scuffs, waterline stain), moulded eyes at both ends, the fender line hitched to the top eye."""
    P = HP(name)
    P.smooth = 70.0
    r = D / 2
    eye_h = 0.05 * L / 0.6
    body0, body1 = eye_h, L - eye_h
    sh = r * 0.62
    prof = [(0.0, body0 - 0.004), (0.032, body0 - 0.002)]
    for k in range(1, 11):           # rounded shoulder (quarter ellipse)
        t = k / 10 * math.pi / 2
        prof.append((0.032 + (r - 0.032) * math.sin(t), body0 + sh * (1 - math.cos(t))))
    zA, zB = body0 + sh, body1 - sh
    for k in range(1, 4):            # three shallow moulded rings
        z = zA + (zB - zA) * k / 4
        prof += [(r, z - 0.014), (r * 0.982, z - 0.004), (r * 0.982, z + 0.004), (r, z + 0.014)]
    for k in range(10, 0, -1):
        t = k / 10 * math.pi / 2
        prof.append((0.032 + (r - 0.032) * math.sin(t), body1 - sh * (1 - math.cos(t))))
    prof += [(0.032, body1 + 0.002), (0.0, body1 + 0.004)]
    prof = sorted(prof, key=lambda p: p[1])
    P.lathe_uv(prof, 28, region)
    for z0, s in ((0.0, 1), (body1, -1)):   # moulded eyes at both ends
        stem = [(0.032, body0 if s > 0 else body1), (0.027, z0 + eye_h * 0.5), (0.02, z0 + (0 if s > 0 else eye_h))]
        P.lathe_uv(sorted(stem, key=lambda p: p[1]), 12, eye_region)
        P.torus_uv(0.023, 0.0095, 14, 6, eye_region, frame(0, 0, z0 + eye_h * (0.3 if s > 0 else 0.7), pitch=90))
    zc = body1 + eye_h * 0.7
    top = zc + 0.023
    end = (0.01, 0.02, top + 0.2)
    _eye_line(P, zc + 0.023, 0.0095 + 0.0075, end)
    return P, (D, D, end[2]), [("ATT_Line", end)], ((-r, -r, 0), (r, r, top))


def fender_cyl_01():
    return _cyl_fender("FenderCyl01", 0.20, 0.60, "FenderWhite", "PVCWhite")


def fender_cyl_02():
    return _cyl_fender("FenderCyl02", 0.25, 0.80, "FenderNavy", "PVCNavy")


def fender_cyl_03():
    return _cyl_fender("FenderCyl03", 0.30, 1.00, "FenderWhite", "PVCWhite")


def fender_ball():
    """A-series ball fender: 40-sided sphere on its own decal (grime, waterline, scuffs), moulded neck and rope eye,
    the line hitched through the eye."""
    P = HP("FenderBall")
    P.smooth = 70.0
    r = 0.30
    prof = [(r * math.sin(math.pi * k / 24), r - r * math.cos(math.pi * k / 24)) for k in range(25)]
    prof[0], prof[-1] = (0.0, 0.0), (0.0, 2 * r)
    P.lathe_uv(prof, 40, "BallFit")
    # moulded neck with the rope eye through it
    P.lathe_uv([(0.06, 2 * r - 0.006), (0.052, 2 * r + 0.012), (0.04, 2 * r + 0.026), (0.03, 2 * r + 0.034)], 20, "BallOrange")
    P.lathe_uv([(0.026, 2 * r + 0.03), (0.022, 2 * r + 0.045)], 12, "BallOrange", cap1=True)
    zc = 2 * r + 0.072
    P.torus_uv(0.034, 0.015, 20, 8, "BallOrange", frame(0, 0, zc, pitch=90))
    end = (0.01, 0.01, 2 * r + 0.3)
    _eye_line(P, zc + 0.034, 0.015 + 0.0085, end, r=0.0075)
    return P, (0.60, 0.60, end[2]), [("ATT_Line", end)], ((-r, -r, 0), (r, r, 2 * r))


def fender_tyre():
    """Car tyre hung against the quay wall on a rope through its top, lashed with two rope ties (wall face is +Y)."""
    P = HP("FenderTyre")
    P.smooth = 60.0
    Ro, Ri, W = 0.31, 0.19, 0.20
    M = frame(0, 0.0, Ro, pitch=90)       # tyre axis along Y, centre at Ro height
    segs = 40
    tread = [(Ro - 0.012, -W / 2), (Ro - 0.002, -W * 0.44), (Ro, -W * 0.3), (Ro, W * 0.3), (Ro - 0.002, W * 0.44), (Ro - 0.012, W / 2)]
    side_o = [(Ro - 0.012, W / 2), (Ro - 0.03, W * 0.515), (Ro - 0.06, W * 0.52), (Ri + 0.04, W * 0.47), (Ri + 0.012, W * 0.42),
              (Ri, W * 0.38)]
    bead = [(Ri, W * 0.38), (Ri - 0.004, 0.0), (Ri, -W * 0.38)]
    side_i = [(Ri, -W * 0.38), (Ri + 0.012, -W * 0.42), (Ri + 0.04, -W * 0.47), (Ro - 0.06, -W * 0.52), (Ro - 0.03, -W * 0.515),
              (Ro - 0.012, -W / 2)]
    srt = lambda p: sorted(p, key=lambda q: q[1])
    P.lathe_uv(tread, segs, "Tread", M, rep_u=5)
    # the lathe wants z rising: sidewalls run r inward at nearly constant z, so lathe them in (r, z) order as given
    P.lathe_uv(side_o, segs, "Rubber", M, rep_u=5)
    P.lathe_uv(bead, segs, "Rubber", M, rep_u=5)
    P.lathe_uv(side_i, segs, "Rubber", M, rep_u=5)
    # hanging rope: through the tyre top, both legs up to a hitch point 0.7 m above
    top = 2 * Ro
    pts = [(0.0, 0.0, top + 0.70), (-0.03, 0.01, top + 0.55), (-0.05, 0.02, top + 0.4), (-0.075, 0.035, top + 0.15),
           (-0.08, 0.04, top + 0.06), (-0.075, 0.04, top - 0.02), (-0.06, 0.04, top - 0.07), (-0.035, 0.02, top - 0.105),
           (0.0, 0.0, top - 0.12), (0.035, -0.02, top - 0.105), (0.06, -0.04, top - 0.07), (0.075, -0.04, top - 0.02),
           (0.08, -0.04, top + 0.06), (0.075, -0.035, top + 0.15), (0.05, -0.02, top + 0.4), (0.03, -0.01, top + 0.55),
           (0.0, 0.0, top + 0.70)]
    P.tube2(pts, 0.012, 6, "RopeBlack")
    # seizing where the legs meet, and two rope ties lashed round the casing
    P.tube2([(0.022 * math.cos(2 * math.pi * k / 10), 0.022 * math.sin(2 * math.pi * k / 10), top + 0.6) for k in range(10)],
            0.006, 5, "RopeBuff", closed=True)
    Rm, a, b = (Ro + Ri) / 2, (Ro - Ri) / 2 + 0.013, W / 2 + 0.012
    for phi in (math.radians(-125), math.radians(125)):
        er = Vector((math.sin(phi), 0, math.cos(phi)))
        c = Vector((0, 0, Ro)) + er * Rm
        loop = [tuple(c + er * (a * math.cos(2 * math.pi * k / 14)) + Vector((0, 1, 0)) * (b * math.sin(2 * math.pi * k / 14)))
                for k in range(14)]
        P.tube2(loop, 0.008, 6, "RopeBuff", closed=True)
    return P, (0.62, 0.226, top + 0.70), [("ATT_Hang", (0, 0, top + 0.70))], ((-Ro, -W / 2, 0), (Ro, W / 2, top))


# ================================================================ lifebuoy station (housing on Metal, ring on Rope)
def lifebuoy_station():
    H = HP("Housing")
    # concrete footing, black post, red GRP cabinet with a sloped hood and the sign above the ring
    H.box((-0.2, -0.2, 0.0), (0.2, 0.2, 0.08), "Concrete", skip=("-z",))
    H.box((-0.05, -0.05 + 0.05, 0.08), (0.05, 0.05 + 0.05, 1.05), "BlackPaint", skip=("-z", "+z"))
    cw, cd, z0, z1 = 0.90, 0.20, 1.00, 1.86
    y0 = -0.06
    t = 0.02
    H.box((-cw / 2, y0 + cd - t, z0), (cw / 2, y0 + cd, z1), "HousingRed")             # back
    for sx in (-1, 1):
        H.box((sx * cw / 2 - (t if sx > 0 else 0), y0, z0), (sx * cw / 2 + (0 if sx > 0 else t), y0 + cd, z1), "HousingRed")
        # sides drawn as boxes clamped to inside of cabinet width
    H.box((-cw / 2, y0, z0), (cw / 2, y0 + cd, z0 + 0.03), "HousingRed")             # floor lip
    H.box((-cw / 2 - 0.02, y0 - 0.04, z1), (cw / 2 + 0.02, y0 + cd + 0.01, z1 + 0.03), "HousingRed")  # hood
    # sign plate on the front of a header panel
    sz0, sz1 = z1 - 0.20, z1 - 0.005
    H.box((-cw / 2, y0, sz0), (cw / 2, y0 + 0.02, sz1), "HousingRed")
    sw = 0.40 * 2
    sh = sz1 - sz0 - 0.02
    o = (-sw / 2, y0 - 0.003, sz0 + 0.01)
    H.mesh([(o[0], o[1], o[2]), (o[0] + sw, o[1], o[2]), (o[0] + sw, o[1], o[2] + sh), (o[0], o[1], o[2] + sh)],
           [(0, 1, 2, 3)], "Sign", fit=fit_frame(o, (1, 0, 0), (0, 0, 1), sw, sh, atlas.rect("Sign")))
    # stainless hooks the ring hangs on, and the line hook
    for sx in (-0.18, 0.18):
        H.cyl((sx, y0 + cd - t, z1 - 0.28), (sx, y0 + 0.07, z1 - 0.26), 0.008, 6, "Stainless", split=1)
    H.cyl((0.0, y0 + cd - t, z0 + 0.17), (0.0, y0 + 0.05, z0 + 0.18), 0.008, 6, "Stainless", split=1)
    for sx in (-1, 1):
        H.bolt(sx * 0.03, 0.04, 0.08, 0.01, 0.01, "Stainless")

    R = HP("Ring")
    Rc = 0.2975
    rt = 0.0775
    cz = z1 - 0.22 - Rc
    cy = y0 + 0.10
    Mr = frame(0, cy, cz, pitch=90)
    # ring body: one 56 x 10 torus on its own decal, the four 50 mm retro bands (45 / 135 / 225 / 315 degrees) painted
    # into the decal wrapping right round the section, so tape and shell share one smooth surface
    R.smooth = 70.0
    R.torus_uv(Rc, rt, 56, 10, "RingFit", Mr, sr=0.92)
    # grab line festooned in 4 loops round the ring, seized at the quarter points
    pts = []
    for k in range(48):
        th = 2 * math.pi * k / 48
        sag = abs(math.sin(2 * th))
        rr = Rc + rt * 0.93 + 0.03 * sag
        pts.append((rr * math.cos(th), cy - 0.018 * sag, cz + rr * math.sin(th)))
    R.tube2(pts, 0.006, 5, "RopeThrow", closed=True, k=1)
    for k in range(4):
        th = math.pi / 2 * k
        M = Matrix.Translation((0, cy, cz)) @ Matrix.Rotation(-th, 4, 'Y') @ frame(Rc, 0, 0)
        R.tube2([tuple(M @ Vector((rt * 1.06 * math.cos(2 * math.pi * j / 10), rt * 0.99 * math.sin(2 * math.pi * j / 10), 0)))
                 for j in range(10)], 0.004, 4, "RopeThrow", closed=True, k=1)
    # throw line: a coiled 30 m floating line hung on the lower hook
    for k in range(3):
        rr = 0.12 + 0.008 * k
        cpts = [(rr * 0.8 * math.sin(2 * math.pi * j / 14), y0 + 0.07 + 0.006 * k,
                 z0 + 0.17 - rr + rr * math.cos(2 * math.pi * j / 14)) for j in range(14)]
        R.tube2(cpts, 0.006, 5, "RopeThrow", closed=True, k=1)
    atts = [("ATT_Ring", (0, cy, cz)), ("ATT_ThrowLine", (0, y0 + 0.07, z0 + 0.05))]
    return [("Housing", "Metal", H), ("Ring", "Rope", R)], (0.94, 0.30, z1 + 0.03), atts, \
        ((-cw / 2 - 0.02, -0.2, 0), (cw / 2 + 0.02, 0.2, z1 + 0.03))


# ================================================================ lobster pots
def lobster_pot_01():
    """Inkwell pot: moulded rubber ballast base, a creel frame of plastic-coated bent rod (base hoop, mid hoop, six bows,
    neck ring), black mesh netting laced over it (DoubleSided cards, continuous UVs) and the entrance funnel of blue
    netting hanging from the neck to a hard orange eye ring inside the pot."""
    P = HP("LobsterPot01")
    P.smooth = 70.0
    Rb, Hd = 0.30, 0.40
    P.lathe_uv([(0.0, 0.0), (Rb - 0.02, 0.0), (Rb, 0.012), (Rb + 0.006, 0.035), (Rb, 0.062), (Rb - 0.025, 0.078), (0.0, 0.082)],
               24, "PotBase")
    neck_r = 0.105
    z0 = 0.085

    def dome(k=1.0):
        prof = []
        for i in range(8):
            t = i / 7
            rr = (Rb - 0.03) * (1 - t) ** 0.75 + neck_r * t
            prof.append((rr * k, z0 + (Hd - z0) * math.sin(t * math.pi / 2)))
        return prof
    f0 = len(P.f)
    P.lathe_uv(dome(0.985), 28, "NetBlack", rep_u=4)
    # entrance funnel: from the neck ring down into the pot to the eye ring
    eye_r, eye_z = 0.065, Hd - 0.17
    P.lathe_uv([(eye_r, eye_z), (0.072, Hd - 0.12), (0.088, Hd - 0.05), (neck_r * 0.98, Hd)], 24, "NetBlue", rep_u=2)
    P.double(f0)
    # frame: bent-rod bows following the dome, hoops and the neck ring (coated steel)
    for i in range(6):
        th = i * math.pi / 3 + math.pi / 6
        P.tube2([(p[0] * math.cos(th), p[0] * math.sin(th), p[1]) for p in dome(1.0)], 0.0075, 5, "PotCoat", caps=False,
                max_step=0.08)
    P.torus_uv(Rb - 0.03, 0.009, 20, 4, "PotCoat", frame(0, 0, z0 + 0.004))
    zm = dome()[3]
    P.torus_uv(zm[0] * 1.0, 0.0075, 20, 4, "PotCoat", frame(0, 0, zm[1]))
    P.torus_uv(neck_r, 0.013, 20, 5, "PotCoat", frame(0, 0, Hd))
    P.torus_uv(eye_r, 0.009, 16, 5, "Float", frame(0, 0, eye_z))
    # bridle rope with a loop for the back line
    P.tube2([(-0.13, 0, Hd - 0.02), (-0.1, 0, Hd + 0.06), (-0.05, 0, Hd + 0.115), (0.0, 0, Hd + 0.125), (0.05, 0, Hd + 0.115),
             (0.1, 0, Hd + 0.06), (0.13, 0, Hd - 0.02)], 0.006, 5, "RopeOrange")
    return P, (0.62, 0.62, Hd + 0.13), [("ATT_Bridle", (0, 0, Hd + 0.12))], ((-Rb, -Rb, 0), (Rb, Rb, Hd))


def lobster_pot_02():
    """Parlour creel: rectangular coated frame, 3 arched hoops, blue netting, two side eyes, rubber ballast bars."""
    P = HP("LobsterPot02")
    L, W, H = 0.80, 0.50, 0.40
    rb = 0.009
    # base frame and ballast bars
    for y in (-W / 2, W / 2):
        P.sweep([(-L / 2, y, 0.012), (L / 2, y, 0.012)], rb * 1.2, 5, "PotCoat")
    for x in (-L / 2, 0.0, L / 2):
        P.sweep([(x, -W / 2, 0.012), (x, W / 2, 0.012)], rb * 1.2, 5, "PotCoat")
    for y in (-0.12, 0.12):
        P.box((-L / 2 + 0.03, y - 0.025, 0.0), (L / 2 - 0.03, y + 0.025, 0.035), "PotBase")
    # three D hoops along X
    def hoop(x, k=1.0):
        return [(x, (W / 2) * math.cos(math.pi * j / 12) * k, 0.012 + (H - 0.012) * math.sin(math.pi * j / 12) * k)
                for j in range(13)]
    for x in (-L / 2, 0.0, L / 2):
        P.sweep(hoop(x), rb, 5, "PotCoat", caps=False)
    P.sweep([(-L / 2, 0, H), (L / 2, 0, H)], rb, 5, "PotCoat", caps=False)

    # netting (DoubleSided cards, continuous whole-tile UVs): arched top, two ends + parlour partition, floor
    f0 = len(P.f)

    def top(u, v):
        x = -L / 2 + L * u
        a = math.pi * v
        return (x, (W / 2 - 0.004) * math.cos(a), 0.012 + (H - 0.016) * math.sin(a))
    P.grid_uv(top, 4, 9, "NetBlue", 2, 3)
    u0, v0, u1, v1 = atlas.rect("NetBlue")
    for x in (-L / 2, 0.0, L / 2):
        vs = [(x, 0, 0.012)] + [(x, (W / 2) * math.cos(math.pi * j / 10), 0.012 + (H - 0.012) * math.sin(math.pi * j / 10))
                                for j in range(11)]
        uv = [(u0 + (u1 - u0) * (0.5 + p[1] / W), v0 + (v1 - v0) * (p[2] - 0.012) / (H - 0.012)) for p in vs]
        P.uvmesh(vs, [(0, j + 1, j + 2) for j in range(10)], [[uv[0], uv[j + 1], uv[j + 2]] for j in range(10)], "NetBlue")
    P.grid_uv(lambda u, v: (-L / 2 + L * u, -W / 2 + W * v, 0.014), 4, 1, "NetBlue", 2, 1)
    # side entrance eyes (soft funnels with a plastic ring) on -Y, one per chamber end
    for x in (-L / 4, L / 4):
        P.lathe_uv([(0.10, 0.0), (0.085, 0.06), (0.07, 0.12), (0.06, 0.2)], 16, "NetBlue",
                   frame(x, -W / 2 + 0.05, 0.17, pitch=-90) @ Matrix.Diagonal((1.0, 0.8, 1.0, 1.0)), rep_u=1)
    P.double(f0)
    for x in (-L / 4, L / 4):
        P.torus_uv(0.06, 0.008, 14, 5, "PotCoat", frame(x, -W / 2 + 0.05 + 0.2, 0.17, pitch=90))
    # door bungee + bait bag string on top
    P.tube([(-0.2, -0.05, H + 0.005), (0.0, -0.08, H + 0.01), (0.2, -0.05, H + 0.005)], 0.005, 5, "RopeBlack")
    P.tube([(0.35, 0, H), (0.42, 0, H + 0.1), (0.5, 0.02, H + 0.12)], 0.006, 5, "RopeOrange")
    return P, (0.80, 0.50, H + 0.02), [("ATT_Bridle", (0.5, 0.02, H + 0.12))], ((-L / 2, -W / 2, 0), (L / 2, W / 2, H))


# ================================================================ fish boxes (stackable HDPE, 2 colours)
def _fish_box(name, region):
    P = HP(name)
    L, W, H = 0.80, 0.42, 0.21
    tp = 0.025           # taper per side (nesting)
    t = 0.012
    xo1, yo1, xo0, yo0 = L / 2, W / 2, L / 2 - tp, W / 2 - tp
    lip = 0.02
    # outer shell (walls taper inward to the foot), rim, inner shell, inner floor, foot ribs
    def ring(x, y, z):
        return [(-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    o0, o1 = ring(xo0, yo0, 0.02), ring(xo1, yo1, H - lip)
    r1 = ring(xo1 + 0.012, yo1 + 0.012, H - lip)
    r2 = ring(xo1 + 0.012, yo1 + 0.012, H)
    i1 = ring(xo1 - t, yo1 - t, H)
    i0 = ring(xo0 - t, yo0 - t, 0.035)
    loops = [o0, o1, r1, r2, i1, i0]
    vs = [p for lp in loops for p in lp]
    faces = []
    for a in range(len(loops) - 1):
        for j in range(4):
            j1 = (j + 1) % 4
            faces.append((a * 4 + j, a * 4 + j1, (a + 1) * 4 + j1, (a + 1) * 4 + j))
    faces.append((20, 21, 22, 23)[::-1])   # inner floor (faces up)
    faces.append((0, 1, 2, 3)[::-1][::-1])  # placeholder replaced below
    faces[-1] = (3, 2, 1, 0)
    faces[-2] = (20, 21, 22, 23)
    # split long faces into tiles happens in face_uvs (squash) -> subdivide walls by building them as a grid instead
    P.mesh(vs, faces, region)
    # foot: four skids under the box
    for x in (-0.3, 0.3):
        P.box((x - 0.03, -yo0 + 0.02, 0.0), (x + 0.03, yo0 - 0.02, 0.02), region, skip=("+z",))
    for y in (-yo0 + 0.04, yo0 - 0.04):
        P.box((-xo0 + 0.02, y - 0.015, 0.0), (xo0 - 0.02, y + 0.015, 0.02), region, skip=("+z",))
    # moulded vertical ribs on the long sides and hand-hold bosses on the ends
    for sy in (-1, 1):
        for k in range(-3, 4):
            x = k * 0.1
            P.box((x - 0.008, sy * (yo1 - 0.005) - 0.006, 0.04), (x + 0.008, sy * (yo1 - 0.005) + 0.006, H - lip - 0.01),
                  region, skip=("-z",))
    for sx in (-1, 1):
        P.box((sx * (xo1 + 0.002) - 0.012, -0.08, H - 0.075), (sx * (xo1 + 0.002) + 0.012, 0.08, H - lip), region)
    return P, (L + 0.024, W + 0.024, H), [("ATT_Stack", (0, 0, H))], ((-L / 2 - 0.012, -W / 2 - 0.012, 0), (L / 2 + 0.012, W / 2 + 0.012, H))


def fish_box_01():
    return _fish_box("FishBox01", "FishBlue")


def fish_box_02():
    return _fish_box("FishBox02", "FishRed")


# ================================================================ net pile (heaped trawl net, alpha cards over a dense core)
def net_pile():
    """Heaped trawl net: a lumpy, folded heap of crossing alpha-card layers (green PE trawl over an opaque dense core,
    orange patches through it) on continuous whole-tile UVs, flaps of net dragged off the heap onto the quay
    (DoubleSided), loose twine strands, the float headline and the black groundrope."""
    P = HP("NetPile")
    P.smooth = 75.0
    rng = random.Random(5)
    Rx, Ry, Hh = 1.0, 0.75, 0.5

    def lumps(n, amp, rad, seed):
        r = random.Random(seed)
        return [(r.uniform(-0.75, 0.75), r.uniform(-0.55, 0.55), r.uniform(*rad), r.uniform(*amp)) for _ in range(n)]

    def ridges(n, seed):
        r = random.Random(seed)
        out = []
        for _ in range(n):
            a = r.uniform(0, math.pi)
            out.append((r.uniform(-0.6, 0.6), r.uniform(-0.45, 0.45), math.cos(a), math.sin(a), r.uniform(0.03, 0.06),
                        r.uniform(0.05, 0.09), r.uniform(0.3, 0.7)))
        return out
    base_l = lumps(10, (0.05, 0.14), (0.15, 0.32), 11)

    def heightf(lp, rd):
        def h(x, y):
            d = (x / Rx) ** 2 + (y / Ry) ** 2
            z = Hh * max(0.0, 1 - d) ** 0.65
            inside = max(0.0, 1 - d) ** 0.4
            for bx, by, br, bh in base_l + lp:
                z += bh * math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (br * br)) * inside
            for px, py, cx, cy, amp, w, ln in rd:     # folds: ridges of gathered net
                t = (x - px) * cx + (y - py) * cy
                dist = -(x - px) * cy + (y - py) * cx
                z += amp * math.exp(-(dist / w) ** 2) * math.exp(-(t / ln) ** 2) * inside
            return z
        return h

    def footprint(x, y):
        return (x / Rx) ** 2 + (y / Ry) ** 2

    def sheet(region, step, lift, lp, rd, keep_extra=None, dmax=1.22):
        S = atlas.scale(region)
        per = int(round(S / step))
        nx, ny = int(round(2.4 / step)), int(round(1.9 / step))
        h = heightf(lp, rd)

        def fn(u, v):
            x, y = -1.2 + 2.4 * u, -0.95 + 1.9 * v
            d = footprint(x, y)
            z = h(x, y) + lift * max(0.0, 1 - d)
            if d > 0.92:                            # the skirt lies on the quay, slightly rucked
                z = min(z, 0.012 + 0.02 * max(0.0, 1.1 - d) + 0.008 * math.sin(9 * x + 5 * y))
            return (x, y, max(z, 0.006 + 0.004 * math.sin(7 * x - 4 * y)))

        def keep(i, j):
            x, y = -1.2 + 2.4 * (i + 0.5) / nx, -0.95 + 1.9 * (j + 0.5) / ny
            ok = footprint(x, y) < dmax + 0.08 * math.sin(5 * math.atan2(y, x) + lift * 40)
            return ok and (keep_extra is None or keep_extra(x, y))
        P.grid_uv(fn, nx, ny, region, nx / per, ny / per, keep=keep)
    # opaque core, green trawl, orange cod-end patches
    sheet("NetDense", 0.2, -0.05, lumps(4, (0.03, 0.08), (0.2, 0.3), 21), ridges(3, 22), dmax=0.9)
    sheet("NetGreen", 0.12, 0.0, lumps(8, (0.04, 0.1), (0.1, 0.22), 31), ridges(6, 32), dmax=1.25)
    pr = random.Random(41)
    blobs = [(pr.uniform(-0.6, 0.6), pr.uniform(-0.45, 0.45), pr.uniform(0.22, 0.4)) for _ in range(4)]
    sheet("NetOrange", 0.17, 0.035, lumps(8, (0.04, 0.1), (0.1, 0.2), 51), ridges(5, 52),
          keep_extra=lambda x, y: any((x - bx) ** 2 + (y - by) ** 2 < br * br for bx, by, br in blobs), dmax=1.1)
    hgt = heightf(base_l[:0], [])
    # flaps of net dragged off the heap onto the quay (DoubleSided)
    f0 = len(P.f)
    for k, (a0, reg) in enumerate(((0.3, "NetGreen"), (2.2, "NetGreen"), (3.6, "NetOrange"), (5.1, "NetGreen"))):
        S = atlas.scale(reg)
        ln = 0.6 if reg == "NetGreen" else 0.48

        def flap(u, v, a0=a0, ln=ln):
            a = a0 + (u - 0.5) * 0.55
            ex, ey = Rx * 0.8 * math.cos(a), Ry * 0.8 * math.sin(a)
            dx, dy = math.cos(a), math.sin(a) * Ry / Rx
            out = 0.12 + ln * v
            x, y = ex + dx * out * (0.8 + 0.2 * math.sin(3 * u + a0)), ey + dy * out
            zt = hgt(ex, ey) * 0.6 * (1 - v) ** 2
            z = zt + 0.05 * math.sin(math.pi * u * 2 + a0) * math.sin(math.pi * v) + 0.02
            return (x, y, max(z, 0.006))
        P.grid_uv(flap, 5, 3, reg, 1, 1)
    P.double(f0)
    # loose twine strands trailing off the heap
    for k in range(8):
        a = rng.uniform(0, 2 * math.pi)
        r0 = rng.uniform(0.55, 0.85)
        x0, y0 = Rx * r0 * math.cos(a), Ry * r0 * math.sin(a)
        L = rng.uniform(0.25, 0.5)
        pts = []
        for q in range(7):
            t = q / 6
            rr = r0 + t * L
            aa = a + 0.25 * math.sin(3 * t + k)
            x, y = Rx * rr * math.cos(aa), Ry * rr * math.sin(aa)
            pts.append((x, y, max(0.004, hgt(x0, y0) * 0.8 * (1 - t) ** 2 + 0.006 + 0.01 * math.sin(7 * t + k))))
        P.tube2(pts, 0.0035, 3, "RopeBlue" if k % 3 else "RopeOrange", max_step=0.1)
    # headline with floats, and a groundrope coil
    hl = heightf(lumps(8, (0.04, 0.1), (0.1, 0.22), 31), ridges(6, 32))
    pts = []
    for k in range(30):
        a = 2 * math.pi * k / 29 * 1.5 + 0.4
        rr = 0.3 + 0.5 * k / 29
        x, y = Rx * rr * math.cos(a), Ry * rr * math.sin(a)
        pts.append((x, y, hl(x, y) + 0.035))
    P.tube2(pts, 0.009, 5, "RopeBlue", k=1)
    for k in range(4, 30, 7):
        x, y, z = pts[k]
        P.lathe_uv([(0.0, -0.06), (0.045, -0.045), (0.064, 0.0), (0.045, 0.045), (0.0, 0.06)], 8,
                   "Float", frame(x, y, z + 0.02, pitch=70, yaw=k * 40))
    gp = [(Rx * 0.98 * math.cos(a), Ry * 0.98 * math.sin(a), 0.026) for a in np.linspace(-0.6, 2.2, 14)]
    P.tube2(gp, 0.024, 6, "RopeBlack", k=1)
    return P, (2.1, 1.6, 0.7), [], ((-Rx, -Ry, 0), (Rx, Ry, 0.6))


# ================================================================ rope: stacked coil, flaked line, chain
def rope_coil():
    """Stacked coil of 16 mm blue polypropylene: 3 layers of turns, the end led off along the quay."""
    P = HP("RopeCoil")
    d = 0.016
    pts = []
    turns_per = [6, 5, 4]
    z = d / 2
    for layer, nt in enumerate(turns_per):
        r0 = 0.12 + layer * 0.01
        for k in range(nt * 12 + (1 if layer == len(turns_per) - 1 else 0)):
            t = k / 12
            rr = r0 + (t / nt) * nt * d * 0.98 if layer % 2 == 0 else r0 + (nt - t) * d * 0.98
            a = 2 * math.pi * t
            pts.append((rr * math.cos(a), rr * math.sin(a), z + 0.002 * math.sin(3 * a)))
        z += d * 0.92
    a = 2 * math.pi * (pts and 0)
    tail = [(pts[-1][0] + 0.05, pts[-1][1] - 0.05, z - d), (0.35, -0.2, d / 2), (0.6, -0.25, d / 2), (0.8, -0.2, d / 2)]
    P.tube(pts + tail, d / 2, 5, "RopeBlue", k=1)
    return P, (0.25 * 2 + 0.6, 0.55, z + 0.01), [("ATT_End", (0.8, -0.2, d / 2))], ((-0.25, -0.25, 0), (0.25, 0.25, z))


def rope_flaked():
    """Mooring line (40 mm three-strand polyester) flaked down on the quay in long S-flakes, the spliced eye on top."""
    P = HP("RopeFlaked")
    P.smooth = 75.0
    d = 0.040
    gap = d * 1.08
    n = 6
    half = 0.52
    pts = []
    for i in range(n):
        y = -0.5 * (n - 1) * gap + i * gap
        xs = (-half, half) if i % 2 == 0 else (half, -half)
        z = d / 2 + 0.12 * d * (i % 2)
        for k in range(11):
            t = k / 10
            x = xs[0] + (xs[1] - xs[0]) * t
            pts.append((x, y + 0.006 * math.sin(math.pi * t * 3 + i), z + 0.003 * math.sin(math.pi * t * 5 + i)))
        if i < n - 1:   # bight round to the next flake
            sx = 1 if xs[1] > 0 else -1
            for k in range(1, 8):
                a = math.pi * k / 8
                pts.append((xs[1] + sx * (gap / 2 + 0.01) * math.sin(a), y + gap / 2 - gap / 2 * math.cos(a), z + 0.25 * d * math.sin(a)))
    # the end climbs onto the flakes and finishes in a spliced eye
    ex, ey, ez = pts[-1]
    sx = -1 if ex < 0 else 1
    lead = [(ex - sx * 0.08, ey - 0.03, d * 0.9), (ex - sx * 0.18, ey - 0.08, d * 1.45), (ex - sx * 0.28, ey - 0.12, d * 1.55)]
    cx, cy = ex - sx * 0.48, ey - 0.12
    eye = []
    for k in range(1, 15):
        a = 2 * math.pi * k / 14
        eye.append((cx + sx * 0.2 * math.cos(a), cy - 0.1 * math.sin(a) * 1.1, d * 1.55 + 0.004 * math.sin(2 * a)))
    P.tube2(pts + lead + eye, d / 2, 7, "RopeBuff", max_step=0.09)
    # splice: the tucked tail thickens the line where the eye closes
    P.tube2([lead[1], lead[2], eye[0]], d / 2 * 1.22, 7, "RopeBuff")
    return P, (1.25, 0.8, 0.09), [("ATT_Eye", eye[6])], ((-0.6, -0.4, 0), (0.6, 0.35, 0.08))


def rope_chain():
    """16 mm short-link mooring chain dumped in a heap with a 1 m tail: stadium links (10 x 6 swept wire, continuous
    UVs, smooth shading) on a 0.083 m pitch, alternate links turned 90 degrees so they interlock."""
    P = HP("RopeChain")
    P.smooth = 75.0
    rng = random.Random(3)
    link_l, link_w, wire = 0.10, 0.064, 0.0085
    pitch = link_l - 2 * wire
    # dense guide curve: a rising heap spiral then the tail across the quay; links walk it at a fixed pitch
    guide = []
    for k in range(400):
        t = k / 399
        a = t * 2.0 * 2 * math.pi
        rr = 0.05 + 0.12 * t
        guide.append(Vector((rr * math.cos(a), rr * math.sin(a), wire + 0.075 * (1 - t) ** 1.5)))
    last = guide[-1]
    tdir = Vector((0.15, 1.0, 0)).normalized()
    for k in range(1, 46):
        guide.append(last + tdir * (0.018 * k) + Vector((0.25 * (0.018 * k) ** 2, 0, 0)))
    for k in range(400, len(guide)):
        guide[k].z = wire
    path = [guide[-1]]
    i = len(guide) - 1
    while i > 0 and len(path) < 25:
        j = i
        while j > 0 and (guide[j] - path[-1]).length < pitch:
            j -= 1
        path.append(guide[j].copy())
        i = j
    path = path[::-1]
    path = [p + Vector((0, 0, rng.uniform(0, 0.006) if p.z > wire * 1.5 else 0)) for p in path]
    rc = link_w / 2 - wire
    straight = link_l - 2 * wire - 2 * rc
    loop = []
    for side in (1, -1):
        cxl = side * straight / 2
        for k in range(5):
            a = -math.pi / 2 + math.pi * k / 4
            loop.append((cxl + side * rc * math.cos(a), side * rc * math.sin(a), 0.0))
    for i in range(len(path) - 1):
        p0, p1 = path[i], path[i + 1]
        c = (p0 + p1) / 2
        dv = (p1 - p0).normalized()
        yaw = math.atan2(dv.y, dv.x)
        pt = math.asin(max(-1, min(1, dv.z)))
        roll = (math.pi / 2 if i % 2 else 0.0) + rng.uniform(-0.25, 0.25)
        M = (Matrix.Translation(c) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(-pt, 4, 'Y') @ Matrix.Rotation(roll, 4, 'X'))
        P.tube2([tuple(M @ Vector(q)) for q in loop], wire, 6, "Chain", closed=True)
    arr = np.array([tuple(p) for p in path])
    lo, hi = arr.min(0), arr.max(0)
    return P, (float(hi[0] - lo[0]) + 0.1, float(hi[1] - lo[1]) + 0.1, None), [("ATT_End", tuple(path[-1]))], \
        ((lo[0] - 0.05, lo[1] - 0.05, 0), (hi[0] + 0.05, hi[1] + 0.05, 0.14))


# ================================================================ table + spec
# asset: (builder, set (single-part assets), docs/12 row ceiling, collision box?, note)
PROPS = {
    "M_Hbr_Bollard_01": (bollard_01, "Metal", 2800, True),
    "M_Hbr_Bollard_02": (bollard_02, "Metal", 2800, True),
    "M_Hbr_Bollard_03": (bollard_03, "Metal", 3000, True),
    "M_Hbr_Cleat_01": (cleat_01, "Metal", 1200, False),
    "M_Hbr_Cleat_02": (cleat_02, "Metal", 1200, False),
    "M_Hbr_Fender_Cyl_01": (fender_cyl_01, "Rope", 3000, False),
    "M_Hbr_Fender_Cyl_02": (fender_cyl_02, "Rope", 3000, False),
    "M_Hbr_Fender_Cyl_03": (fender_cyl_03, "Rope", 3000, False),
    "M_Hbr_Fender_Ball": (fender_ball, "Rope", 3000, False),
    "M_Hbr_Fender_Tyre": (fender_tyre, "Rope", 3000, False),
    "M_Hbr_LifebuoyStation": (lifebuoy_station, None, 3000, True),
    "M_Hbr_LobsterPot_01": (lobster_pot_01, "Rope", 3000, True),
    "M_Hbr_LobsterPot_02": (lobster_pot_02, "Rope", 3000, True),
    "M_Hbr_FishBox_01": (fish_box_01, "Rope", 1500, True),
    "M_Hbr_FishBox_02": (fish_box_02, "Rope", 1500, True),
    "M_Hbr_NetPile": (net_pile, "Rope", 3000, False),
    "M_Hbr_Rope_Coil": (rope_coil, "Rope", 2500, False),
    "M_Hbr_Rope_Flaked": (rope_flaked, "Rope", 3000, False),
    "M_Hbr_Rope_Chain": (rope_chain, "Metal", 3000, False),
}


def build_prop(asset):
    fn, set_name, ceiling, col = PROPS[asset]
    out = fn()
    parts, dims, atts, colbox = out
    if not isinstance(parts, list):
        parts = [(None, set_name, parts)]
    allv = [v for _, _, P in parts for v in P.v]
    lo0 = Vector([min(v[i] for v in allv) for i in range(3)])
    hi0 = Vector([max(v[i] for v in allv) for i in range(3)])
    off = Vector((-(lo0.x + hi0.x) / 2, -(lo0.y + hi0.y) / 2, -lo0.z))
    for _, _, P in parts:
        P.v = [v + off for v in P.v]
    atts = [(n, tuple(Vector(p) + off)) for n, p in atts]
    colbox = (tuple(Vector(colbox[0]) + off), tuple(Vector(colbox[1]) + off))
    colbox = ((colbox[0][0], colbox[0][1], max(colbox[0][2], 0.0)), colbox[1])
    meshes, total, used, lods = [], 0, [], []
    for sub, sname, P in parts:
        obj_name = "%s_%s_LOD0" % (asset, sub) if sub else asset + "_LOD0"
        obj = P.to_object(obj_name, material(sname, sname))
        meshes.append({"object": obj, "set": sname})
        lods.append((obj, sname))
        total += P.tris()
        used.append(sname)
    lo = [min(v.co[i] for m in meshes for v in m["object"].data.vertices) / STUDS for i in range(3)]
    hi = [max(v.co[i] for m in meshes for v in m["object"].data.vertices) / STUDS for i in range(3)]
    dims = tuple(round(hi[i] - lo[i], 3) for i in range(3))     # authored to the REF class sizes (dims.md)
    from refs import REFS
    ref_dir = os.path.join(G, "art/reference", asset)
    os.makedirs(ref_dir, exist_ok=True)
    with open(os.path.join(ref_dir, "dims.md"), "w") as fh:
        fh.write("# %s\n\nReal class: %s\n\ndims_m: %s x %s x %s\n\n(X, Y, Z metres, front -Y, base at Z 0; the authored size "
                 "of the HP2a build, art/source/harbour/M_Hbr_PropAtlas/props.py. Reference photo board: pending, see art/status/HP2a.csv.)\n"
                 % (asset, REFS[asset], dims[0], dims[1], dims[2]))
    for obj, sname in lods:
        meshes.append({"object": lod1(obj), "set": sname})
    if col:
        meshes.append({"object": box_col(asset, *colbox)})
    attachments = [att(n, p) for n, p in atts]
    sets = [{"name": atlas.NAME, "set": s, "size": atlas.EXPORT, "wet": True, "dir": TEX_DIR} for s in sorted(set(used))]
    z = dims[2] if dims[2] is not None else colbox[1][2]
    h = (z or 0.3) * STUDS
    reach = max(dims[0] or 0.4, dims[1] or 0.4, z or 0.3) * STUDS
    print("[HP2a] %s LOD0 %d tris (row ceiling %d)" % (asset, total, ceiling))
    return {
        "name": asset, "budget": "small_prop", "tris": max(ceiling, 500), "tier": "standard",
        "dims_m": tuple(None if v is None else round(v, 3) for v in dims), "size_note": None, "origin": "base",
        "sets": sets, "atlas": atlas.ATLAS_ASSET, "meshes": meshes, "attachments": attachments,
        "tiling": False, "lod_symmetry": None,
        "waivers": dict({"LOD UV layout": "collapse decimation of small atlas-tiled props shifts UV area (same regions sampled)"},
                        **({"texture sets": "shared harbour prop atlas (2 sets, docs/12 2.3)"} if len(sets) > 1 else {})),
        "closeups": [{"name": "detail", "target": [0, 0, h * 0.7], "dist": max(reach * 0.9, 2.5), "az": 35, "el": 25}],
    }
