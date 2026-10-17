"""M_Prop_Chandlery mesh kit (Blender): primitives authored in metres in the shared Chandlery frame, written in studs.

Every face carries an atlas region (atlas.R). "tile" regions are box-projected in world metres at the region's scale,
with a per-face integer offset (the tiles are periodic, so neighbouring faces stay continuous); "fit" faces map a
given planar frame exactly onto a decal rect (tags, radio face, boards). Rope geometry lives in RopePart (rope.py tubes,
UVs remapped into the rope trim strips).
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import atlas  # noqa: E402

STUDS = 3.0
I4 = Matrix.Identity(4)


def frame(x, y, z, yaw=0.0, pitch=0.0, roll=0.0):
    """Translation then rotations in degrees: yaw about Z, pitch about X, roll about Y."""
    return (Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(yaw), 4, 'Z')
            @ Matrix.Rotation(math.radians(pitch), 4, 'X') @ Matrix.Rotation(math.radians(roll), 4, 'Y'))


def axis_frame(p0, p1):
    """Matrix taking local +Z to the segment p0 -> p1, origin at p0."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    q = d.normalized().to_track_quat('Z', 'Y' if abs(d.normalized().z) < 0.99 else 'X')
    return Matrix.Translation(p0) @ q.to_matrix().to_4x4(), d.length


BOX_FACES = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
BOX_KEYS = ["-z", "+z", "-y", "+y", "-x", "+x"]


class Part:
    def __init__(self, name):
        self.name = name
        self.v = []
        self.f = []        # (indices, region, fit)

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.f)

    def mesh(self, verts, faces, region, M=None, fit=None, regions=None):
        M = M or I4
        b = len(self.v)
        self.v.extend(M @ Vector(p) for p in verts)
        flip = M.to_3x3().determinant() < 0
        for k, f in enumerate(faces):
            idx = [b + i for i in (reversed(f) if flip else f)]
            r = regions[k] if regions else region
            self.f.append((idx, r if isinstance(r, str) else r[0], fit if isinstance(r, str) else r[1]))
        return b

    # ---------------------------------------------------------------- primitives (local metres, then M)
    def box(self, lo, hi, region, M=None, skip=(), fits=None):
        (x0, y0, z0), (x1, y1, z1) = lo, hi
        vs = [(x, y, z) for z in (z0, z1) for y in (y0, y1) for x in (x0, x1)]
        faces, regs = [], []
        for k, f in zip(BOX_KEYS, BOX_FACES):
            if k in skip:
                continue
            faces.append(f)
            regs.append((fits or {}).get(k, region))
        self.mesh(vs, faces, region, M, regions=regs)

    def lathe(self, profile, segs, region, M=None, sx=1.0, sy=1.0, cap0=True, cap1=True, a0=0.0, a1=2 * math.pi,
              cap_region=None, offset=(0.0, 0.0)):
        closed = abs((a1 - a0) - 2 * math.pi) < 1e-6
        n = segs if closed else segs + 1
        vs = []
        for r, z in profile:
            for j in range(n):
                t = a0 + (a1 - a0) * j / segs
                vs.append((offset[0] + r * math.cos(t) * sx, offset[1] + r * math.sin(t) * sy, z))
        faces = []
        for k in range(len(profile) - 1):
            for j in range(segs):
                j1 = (j + 1) % n
                faces.append((k * n + j, k * n + j1, (k + 1) * n + j1, (k + 1) * n + j))
        regs = [region] * len(faces)
        if closed and cap0 and profile[0][0] > 1e-6:
            faces.append(tuple(reversed(range(n))))
            regs.append(cap_region or region)
        if closed and cap1 and profile[-1][0] > 1e-6:
            last = (len(profile) - 1) * n
            faces.append(tuple(last + j for j in range(n)))
            regs.append(cap_region or region)
        self.mesh(vs, faces, region, M, regions=regs)

    def cyl(self, p0, p1, r, segs, region, r1=None, caps=True, split=None, cap_region=None, sx=1.0, sy=1.0):
        M, L = axis_frame(p0, p1)
        r1 = r if r1 is None else r1
        if split is None:
            s = atlas.R[region][5] or 1.0
            split = max(1, int(math.ceil(L / s)))
        prof = [(r + (r1 - r) * i / split, L * i / split) for i in range(split + 1)]
        self.lathe(prof, segs, region, M, sx, sy, caps, caps, cap_region=cap_region)

    def torus(self, R, r, segs, rsegs, region, M=None, arc=2 * math.pi, a0=0.0, sr=1.0):
        closed = abs(arc - 2 * math.pi) < 1e-6
        n = segs if closed else segs + 1
        vs = []
        for i in range(n):
            t = a0 + arc * i / segs
            for j in range(rsegs):
                p = 2 * math.pi * j / rsegs
                rr = R + r * math.cos(p)
                vs.append((rr * math.cos(t), rr * math.sin(t), r * sr * math.sin(p)))
        faces = []
        for i in range(segs):
            i1 = (i + 1) % n
            for j in range(rsegs):
                j1 = (j + 1) % rsegs
                faces.append((i * rsegs + j, i1 * rsegs + j, i1 * rsegs + j1, i * rsegs + j1))
        self.mesh(vs, faces, region, M)

    def sweep(self, pts, r, sides, region, caps=True, rx=None):
        """Tube along a polyline (parallel transport). rx: second radius (flat straps)."""
        P = [Vector(p) for p in pts]
        rx = r if rx is None else rx
        T = []
        for i in range(len(P)):
            a, b = P[max(0, i - 1)], P[min(len(P) - 1, i + 1)]
            T.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = T[0].cross(ref).normalized()
        vs = []
        for i, p in enumerate(P):
            if i:
                nrm = (nrm - T[i] * nrm.dot(T[i])).normalized()
            bn = T[i].cross(nrm)
            for j in range(sides):
                t = 2 * math.pi * (j + 0.5) / sides
                vs.append(p + nrm * (rx * math.cos(t)) + bn * (r * math.sin(t)))
        faces = []
        n = sides
        for i in range(len(P) - 1):
            for j in range(n):
                j1 = (j + 1) % n
                faces.append((i * n + j, (i + 1) * n + j, (i + 1) * n + j1, i * n + j1))
        if caps:
            faces.append(tuple(range(n)))
            faces.append(tuple(reversed(range((len(P) - 1) * n, len(P) * n))))
        self.mesh(vs, faces, region)

    # ---------------------------------------------------------------- output
    def to_object(self, obj_name, material, smooth_angle=40.0):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new("UVMap")
        bv = [bm.verts.new(tuple(c * STUDS for c in p)) for p in self.v]
        squashed = 0
        for idx, region, fit in self.f:
            if len(set(idx)) < 3:
                continue
            try:
                f = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            pts = [self.v[i] for i in idx]
            uvs, sq = face_uvs(pts, region, fit)
            squashed += sq
            for loop, uv in zip(f.loops, uvs):
                loop[uvl].uv = uv
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        for p in mesh.polygons:
            p.use_smooth = True
        try:
            mesh.set_sharp_from_angle(angle=math.radians(smooth_angle))
        except Exception:
            pass
        if material is not None:
            mesh.materials.append(material)
        obj = bpy.data.objects.new(obj_name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if squashed:
            print("[H2props] %s: %d faces wider than their tile (squashed)" % (obj_name, squashed))
        return obj


def newell(pts):
    n = Vector((0, 0, 0))
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        n.x += (p.y - q.y) * (p.z + q.z)
        n.y += (p.z - q.z) * (p.x + q.x)
        n.z += (p.x - q.x) * (p.y + q.y)
    return n


def face_uvs(pts, region, fit):
    if fit is not None:
        o, ua, va, w, h, rc = fit
        u0, v0, u1, v1 = rc
        out = []
        for p in pts:
            s = min(1.0, max(0.0, (p - o).dot(ua) / w))
            t = min(1.0, max(0.0, (p - o).dot(va) / h))
            out.append((u0 + s * (u1 - u0), v0 + t * (v1 - v0)))
        return out, 0
    u0, v0, u1, v1 = atlas.rect(region)
    S = atlas.R[region][5] or 1.0
    n = newell(pts)
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 0:
        ab = [(p.y * (1 if n.x > 0 else -1), p.z) for p in pts]
    elif ax == 1:
        ab = [(p.x * (-1 if n.y > 0 else 1), p.z) for p in pts]
    else:
        ab = [(p.x, p.y) for p in pts]
    a = [x / S for x, _ in ab]
    b = [y / S for _, y in ab]
    oa, ob = math.floor(min(a)), math.floor(min(b))
    span = max(max(a) - oa, max(b) - ob, 1e-9)
    k = 1.0 if span <= 1.0 else 1.0 / span
    if span > 1.0:      # re-anchor at the face minimum so it fits the tile
        oa, ob = min(a), min(b)
        span = max(max(a) - oa, max(b) - ob)
        k = 1.0 if span <= 1.0 else 1.0 / span
    out = [(u0 + (x - oa) * k * (u1 - u0), v0 + (y - ob) * k * (v1 - v0)) for x, y in zip(a, b)]
    return out, int(span > 1.0)


def fit_frame(origin, u_axis, v_axis, w, h, rc):
    return (Vector(origin), Vector(u_axis).normalized(), Vector(v_axis).normalized(), w, h, rc)


# ---------------------------------------------------------------- rope (rope.py tubes in the rope trim strips)
class RopePart:
    def __init__(self, name):
        self.name = name
        self.parts = []
        self.tri = 0

    def _remap(self, uvs, strip, vscale):
        s0, s1 = atlas.strip(atlas.strip_index(strip))
        return [tuple((s0 + u * (s1 - s0), v * vscale / 8.0) for u, v in poly) for poly in uvs]

    def tube(self, rope_mod, pts_m, d, strip, profile="plain", sides=6, max_tris=200, caps=True):
        v, f, u, tris, _ = rope_mod.tube(np.asarray(pts_m, float), d, profile, sides=sides, max_tris=max_tris, caps=caps)
        self.parts.append((v, f, self._remap(u, strip, 1.0)))
        self.tri += tris

    def hank(self, centre, R, r, strip, segs=16, rsegs=8, M=None, binds=3, rope_mod=None, tail=True):
        """A coiled hank: a torus bundle textured with the hank strip, whipped in `binds` places, one tail end."""
        M = M or Matrix.Translation(centre)
        verts, faces, uvs = [], [], []
        s0, s1 = atlas.strip(atlas.strip_index(strip))
        circ = 2 * math.pi * r
        for i in range(segs):
            for j in range(rsegs):
                t, p = 2 * math.pi * i / segs, 2 * math.pi * j / rsegs
                rr = R + r * math.cos(p)
                verts.append(tuple(c * STUDS for c in (M @ Vector((rr * math.cos(t), rr * math.sin(t), r * math.sin(p))))))
        for i in range(segs):
            for j in range(rsegs):
                i1, j1 = (i + 1) % segs, (j + 1) % rsegs
                faces.append((i * rsegs + j, i1 * rsegs + j, i1 * rsegs + j1, i * rsegs + j1))
                va = (2 * math.pi * R * i / segs) / circ / 8.0
                vb = (2 * math.pi * R * (i + 1) / segs) / circ / 8.0
                ua, ub = s0 + (s1 - s0) * j / rsegs, s0 + (s1 - s0) * (j + 1) / rsegs
                uvs.append(((ua, va), (ua, vb), (ub, vb), (ub, va)))
        self.parts.append((np.array(verts), faces, uvs))
        self.tri += 2 * segs * rsegs
        single = strip.replace("Hank", "") if strip.replace("Hank", "") in [s[0] for s in atlas.ROPE_STRIPS] else "Manila"
        if strip == "NavyHank":
            single = "NavyBraid"
        if strip == "GreenHank":
            single = "NavyBraid"
        for k in range(binds):
            t = 2 * math.pi * (k + 0.3) / binds
            c = Vector((R * math.cos(t), R * math.sin(t), 0))
            radial = Vector((math.cos(t), math.sin(t), 0))
            ring = [M @ (c + (radial * math.cos(a) + Vector((0, 0, 1)) * math.sin(a)) * (r + 0.004))
                    for a in np.linspace(0, 2 * math.pi, 9)]
            self.tube(rope_mod, [tuple(p) for p in ring], 0.007, single, "plain", sides=4, max_tris=48, caps=False)
        if tail:
            t = 2 * math.pi * 0.62
            a = Vector(((R + r * 0.6) * math.cos(t), (R + r * 0.6) * math.sin(t), r * 0.5))
            out = Vector((math.cos(t), math.sin(t), 0))
            side = Vector((-math.sin(t), math.cos(t), 0))
            pts = [M @ (a + out * (0.05 * k) + side * (0.03 * math.sin(k)) - Vector((0, 0, min(k, 2) * r * 0.45)))
                   for k in range(5)]
            self.tube(rope_mod, [tuple(p) for p in pts], 2 * r / 3.2, single, "plain", sides=6, max_tris=60)

    def to_object(self, rope_mod, obj_name):
        return rope_mod._object(obj_name, self.parts, "ChandleryProps")


def material(name, rgb, rough=0.7, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return mat
