"""S1a geometry kit (runs inside Blender): swept timbers and bars, lathes, rings, oriented boxes, kelp cards.

Author in METRES, Blender axes (X beam, Y length with the bow / front at -Y, Z up); Buf.to_object converts to studs
(x 3) and writes one UV set `UVMap` and one material named after the texture set.

UV modes (u along the sweep = wood grain / bar length):
  ("tile", tu, tv)        u = length / tu, v = perimeter / tv (metres per repeat; tiling sets)
  ("strip", v0, v1, tu)   v = v0 + perimeter fraction * (v1 - v0), u = length / tu (trim strips that tile in u)
"""
import math
import random

import bpy
from mathutils import Matrix, Vector

S = 3.0  # studs per metre


def V(*a):
    return Vector(a[0] if len(a) == 1 else a)


class Buf:
    def __init__(self):
        self.v, self.f, self.uv, self.smooth = [], [], [], []

    def add_vert(self, p):
        self.v.append(Vector(p))
        return len(self.v) - 1

    def face(self, idx, uvs, smooth=False):
        self.f.append(list(idx))
        self.uv.append([tuple(u) for u in uvs])
        self.smooth.append(smooth)

    def extend(self, other, M=None):
        o = len(self.v)
        for p in other.v:
            self.v.append(M @ p if M is not None else p.copy())
        for f, uv, sm in zip(other.f, other.uv, other.smooth):
            self.f.append([i + o for i in f])
            self.uv.append(uv)
            self.smooth.append(sm)

    def transform(self, M, start=0):
        for i in range(start, len(self.v)):
            self.v[i] = M @ self.v[i]

    def tris(self):
        return sum(len(f) - 2 for f in self.f)

    def to_object(self, name, mat_name, collection=None):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p * S) for p in self.v], [], self.f)
        uvl = me.uv_layers.new(name="UVMap")
        k = 0
        for poly, uvs, sm in zip(me.polygons, self.uv, self.smooth):
            poly.use_smooth = sm
            for li, uv in zip(poly.loop_indices, uvs):
                uvl.data[li].uv = uv
            k += 1
        me.validate(clean_customdata=False)
        me.update()
        mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        (collection or bpy.context.scene.collection).objects.link(ob)
        return ob


def rect_profile(w, h, chamfer=0.0):
    a, b = w / 2, h / 2
    if chamfer <= 0:
        return [(-a, -b), (a, -b), (a, b), (-a, b)]
    c = min(chamfer, a * 0.45, b * 0.45)
    return [(-a + c, -b), (a - c, -b), (a, -b + c), (a, b - c), (a - c, b), (-a + c, b), (-a, b - c), (-a, -b + c)]


def round_profile(r, n):
    return [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def frames(pts, up_hint=(0, 0, 1)):
    """Per-point (tangent, side, up) by parallel transport from an up hint."""
    n = len(pts)
    T = []
    for i in range(n):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        T.append((b - a).normalized())
    up = Vector(up_hint)
    if abs(up.dot(T[0])) > 0.95:
        up = Vector((1, 0, 0)) if abs(T[0].x) < 0.9 else Vector((0, 1, 0))
    out = []
    for t in T:
        side = t.cross(up).normalized()
        up = side.cross(t).normalized()
        out.append((t, side, up))
    return out


def sweep(buf, pts, profile, uv, axes=None, up_hint=(0, 0, 1), scale=None, closed_path=False, caps=(True, True),
          smooth=False, jag=(0.0, 0.0), seed=0):
    """Sweep a closed 2D profile (x along side, y along up) along pts. axes: optional per-point (side, up) lists.
    scale: per-point profile scale. jag: (start, end) splinter length in metres for broken ends."""
    rnd = random.Random(seed)
    pts = [Vector(p) for p in pts]
    n, m = len(pts), len(profile)
    fr = frames(pts, up_hint)
    if axes is not None:
        fr = [(fr[i][0], Vector(axes[i][0]).normalized(), Vector(axes[i][1]).normalized()) for i in range(n)]
    perim = [0.0]
    for j in range(m):
        a, b = profile[j], profile[(j + 1) % m]
        perim.append(perim[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    length = [0.0]
    for i in range(1, n):
        length.append(length[-1] + (pts[i] - pts[i - 1]).length)
    rings = []
    for i, p in enumerate(pts):
        t, sd, up = fr[i]
        k = scale[i] if scale else 1.0
        ring = []
        for j, (x, y) in enumerate(profile):
            q = p + sd * (x * k) + up * (y * k)
            if i == 0 and jag[0] > 0 and not closed_path:
                q = q - t * rnd.uniform(0, jag[0])
            if i == n - 1 and jag[1] > 0 and not closed_path:
                q = q + t * rnd.uniform(0, jag[1])
            ring.append(buf.add_vert(q))
        rings.append(ring)

    if closed_path:
        length.append(length[-1] + (pts[0] - pts[-1]).length)

    def uvof(i, j):
        if uv[0] == "tile":
            return (length[i] / uv[1], perim[j] / uv[2])
        v0, v1, tu = uv[1], uv[2], uv[3]
        return (length[i] / tu, v0 + (v1 - v0) * (0.0005 + 0.999 * perim[j] / perim[-1]))
    segs = n if closed_path else n - 1
    for i in range(segs):
        i2 = (i + 1) % n
        for j in range(m):
            j2 = j + 1
            a, b, c, d = rings[i][j], rings[i][j2 % m], rings[i2][j2 % m], rings[i2][j]
            buf.face([a, b, c, d], [uvof(i, j), uvof(i, j2), uvof(i + 1, j2), uvof(i + 1, j)], smooth)
    if not closed_path:
        for end, idx in ((0, 0), (1, n - 1)):
            if not caps[end]:
                continue
            t, sd, up = fr[idx]
            k = scale[idx] if scale else 1.0
            c = pts[idx] + (t * (jag[end] * 1.4 * (1 if end else -1)) if jag[end] > 0 else Vector())
            ci = buf.add_vert(c)
            ring = rings[idx]
            tu = uv[1] if uv[0] == "tile" else uv[3]
            for j in range(m):
                x0, y0 = profile[j]
                x1, y1 = profile[(j + 1) % m]
                if uv[0] == "tile":
                    uvs = [(0.5 + x0 * k / tu, 0.5 + y0 * k / uv[2]), (0.5 + x1 * k / tu, 0.5 + y1 * k / uv[2]), (0.5, 0.5)]
                else:
                    mid = (uv[1] + uv[2]) / 2
                    hh = (uv[2] - uv[1]) * 0.45
                    sz = max(max(abs(p[0]), abs(p[1])) for p in profile) * k + 1e-6
                    uvs = [(0.5 + x0 * k / tu, mid + y0 * k / sz * hh), (0.5 + x1 * k / tu, mid + y1 * k / sz * hh), (0.5, mid)]
                if end == 0:
                    buf.face([ring[(j + 1) % m], ring[j], ci], [uvs[1], uvs[0], uvs[2]], False)
                else:
                    buf.face([ring[j], ring[(j + 1) % m], ci], uvs, False)
    return buf


def obox(buf, centre, axes, half, uv):
    """Oriented box (axes: 3 unit vectors, half: half sizes), swept along axes[0]."""
    c = Vector(centre)
    ax = [Vector(a).normalized() for a in axes]
    pts = [c - ax[0] * half[0], c + ax[0] * half[0]]
    return sweep(buf, pts, rect_profile(half[1] * 2, half[2] * 2), uv, axes=[(ax[1], ax[2])] * 2)


def ring(buf, centre, axis_u, axis_v, R, r, n_major, n_minor, uv, stretch=0.0):
    """Torus / stadium ring in the plane (axis_u, axis_v): stretch = straight length added along axis_u."""
    c, au, av = Vector(centre), Vector(axis_u).normalized(), Vector(axis_v).normalized()
    pts = []
    for i in range(n_major):
        a = 2 * math.pi * i / n_major
        x, y = R * math.cos(a), R * math.sin(a)
        x += math.copysign(stretch / 2, x) if abs(x) > 1e-6 else 0.0
        pts.append(c + au * x + av * y)
    normal = au.cross(av)
    axes = []
    for i in range(n_major):
        t = (pts[(i + 1) % n_major] - pts[i - 1]).normalized()
        out = t.cross(normal).normalized()
        axes.append((out, normal))
    return sweep(buf, pts, round_profile(r, n_minor), uv, axes=axes, closed_path=True, smooth=True)


def lathe(buf, profile, n, uvfn, centre=(0, 0, 0), smooth=True):
    """Revolve a (radius, z) polyline about +Z. uvfn(seg_index, angle_frac) -> (u, v). Seam duplicated."""
    c = Vector(centre)
    rows = []
    for k, (r, z) in enumerate(profile):
        row = []
        for i in range(n + 1):
            a = 2 * math.pi * i / n - math.pi / 2       # i = 0 at the back (+Y side is a=+90), u=0.5 at the front (-Y)
            row.append(buf.add_vert(c + Vector((r * math.cos(a + math.pi), r * math.sin(a + math.pi), z))))
        rows.append(row)
    for k in range(len(profile) - 1):
        for i in range(n):
            a, b, cc, d = rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i]
            buf.face([a, b, cc, d], [uvfn(k, i / n), uvfn(k, (i + 1) / n), uvfn(k + 1, (i + 1) / n), uvfn(k + 1, i / n)], smooth)
    return rows


def card(buf, base, up, side, length, width, segs, bend, uv_rect, droop=0.0):
    """Kelp blade: a strip from base along `up`, bending toward `bend` with height, uv_rect (u0, u1) quarter."""
    base, up, side, bend = Vector(base), Vector(up).normalized(), Vector(side).normalized(), Vector(bend)
    left, right = [], []
    p = base.copy()
    d = up.copy()
    for i in range(segs + 1):
        t = i / segs
        if i:
            d = (d + bend * (1.0 / segs) - Vector((0, 0, droop / segs))).normalized()
            p = p + d * (length / segs)
        w = width * (0.25 + 0.75 * math.sin(min(t * 1.25, 1.0) * math.pi / 2))
        left.append(buf.add_vert(p - side * w / 2))
        right.append(buf.add_vert(p + side * w / 2))
    u0, u1 = uv_rect
    for i in range(segs):
        v0, v1 = i / segs, (i + 1) / segs
        buf.face([left[i], right[i], right[i + 1], left[i + 1]], [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], True)


def col_boxes(boxes, name):
    """_COL mesh (studs): list of (centre, axes, half) in metres, each a closed 12-tri box."""
    b = Buf()
    for c, ax, h in boxes:
        c, ax = Vector(c), [Vector(a).normalized() for a in ax]
        idx = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    idx.append(b.add_vert(c + ax[0] * h[0] * sx + ax[1] * h[1] * sy + ax[2] * h[2] * sz))
        quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        for q in quads:
            b.face([idx[i] for i in q], [(0, 0), (1, 0), (1, 1), (0, 1)])
    ob = b.to_object(name, "MI_COL")
    return ob


def empty(name, loc_m, look=(0, -1, 0), up=(0, 0, 1)):
    """ATT_* empty at loc (metres), local -Y = look, +Z = up."""
    e = bpy.data.objects.new(name, None)
    f = -Vector(look).normalized()
    z = Vector(up).normalized()
    x = f.cross(z).normalized()
    z = x.cross(f).normalized()
    M = Matrix((x, f, z)).transposed().to_4x4()
    M.translation = Vector(loc_m) * S
    e.matrix_world = M
    bpy.context.scene.collection.objects.link(e)
    return e


def bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def shift_to_base(objs, empties=(), extra_mats=(), others=()):
    """Translate mesh data so the bbox centre is at x = y = 0 and the lowest point at z = 0. Returns the offset."""
    lo, hi = bbox(objs)
    off = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    T = Matrix.Translation(off)
    for o in list(objs) + list(others):
        o.data.transform(T)
        o.data.update()
    for e in empties:
        e.matrix_world = T @ e.matrix_world
    for o in extra_mats:
        o.matrix_world = T @ o.matrix_world
    return off
