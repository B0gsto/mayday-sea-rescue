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
def _bands(P, prof, segs, worn=(0.0, 0.0), rust_top=0.07):
    """Lathe a bollard profile in bands: rusted foot, painted body, rope-polished neck band, painted head."""
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
        pts = sub(a, b)
        P.lathe(pts, segs, reg, cap0=(a == zs[0]), cap1=(b == zs[-1]), cap_region="IronBlack")


def bollard_01():
    """Mushroom-head harbour bollard, 0.55 m, on a square cast base plate with four bolts."""
    P = HP("Bollard01")
    P.box((-0.24, -0.24, 0.0), (0.24, 0.24, 0.045), "IronRust", skip=("-z",))
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.bolt(sx * 0.18, sy * 0.18, 0.045, 0.022, 0.02, "IronRust")
    prof = [(0.185, 0.045), (0.175, 0.09), (0.16, 0.2), (0.15, 0.3), (0.148, 0.36), (0.152, 0.40),
            (0.20, 0.445), (0.215, 0.47), (0.205, 0.50), (0.17, 0.53), (0.10, 0.548), (0.0, 0.552)]
    _bands(P, prof, 24, worn=(0.30, 0.42), rust_top=0.09)
    return P, (0.48, 0.48, 0.552), [("ATT_RopeNeck", (0, 0, 0.37))], ((-0.24, -0.24, 0), (0.24, 0.24, 0.552))


def bollard_02():
    """Tee-head bollard, 0.6 m: tapered post with a horizontal cross horn through the head."""
    P = HP("Bollard02")
    P.lathe([(0.24, 0.0), (0.24, 0.05), (0.19, 0.06)], 20, "IronRust", cap0=False, cap1=False)
    prof = [(0.19, 0.06), (0.18, 0.12), (0.16, 0.3), (0.155, 0.42), (0.16, 0.5), (0.175, 0.53), (0.17, 0.57),
            (0.12, 0.595), (0.0, 0.60)]
    _bands(P, prof, 20, worn=(0.30, 0.46), rust_top=0.12)
    for sx in (-1, 1):  # horns, slightly drooped and flared at the tips
        pts = [(0.0, 0.0, 0.50), (sx * 0.20, 0, 0.495), (sx * 0.29, 0, 0.505)]
        M, L = axis_frame((sx * 0.12, 0, 0.50), (sx * 0.30, 0, 0.51))
        P.lathe([(0.055, 0.0), (0.05, L * 0.6), (0.06, L * 0.92), (0.045, L), (0.0, L + 0.005)], 10, "IronBlack", M,
                cap0=False)
    for a in range(6):
        t = a * math.pi / 3 + 0.3
        P.bolt(0.215 * math.cos(t), 0.215 * math.sin(t), 0.05, 0.02, 0.018, "IronRust")
    return P, (0.62, 0.48, 0.60), [("ATT_RopeNeck", (0, 0, 0.38))], ((-0.30, -0.24, 0), (0.30, 0.24, 0.60))


def bollard_03():
    """Old cannon reused as a bollard (Cornish harbours): muzzle up, a cannon ball in the bore, 0.58 m showing."""
    P = HP("Bollard03")
    prof = [(0.20, 0.0), (0.195, 0.08), (0.18, 0.2), (0.165, 0.34), (0.155, 0.44), (0.152, 0.48), (0.175, 0.50),
            (0.18, 0.53), (0.165, 0.545), (0.17, 0.56), (0.165, 0.575), (0.12, 0.578)]
    _bands(P, prof, 18, worn=(0.24, 0.40), rust_top=0.10)
    # bore with a cannon ball (old harbour trick against rope cutting)
    P.lathe([(0.12, 0.578), (0.105, 0.56), (0.0, 0.555)], 12, "IronRust", cap0=False, cap1=False)
    P.lathe([(0.0, 0.55), (0.06, 0.556), (0.09, 0.575), (0.092, 0.59), (0.07, 0.61), (0.0, 0.62)], 10, "IronBlack",
            cap0=False, cap1=False)
    # reinforce ring
    P.torus(0.198, 0.012, 18, 3, "IronBlack", frame(0, 0, 0.30))
    return P, (0.40, 0.40, 0.62), [("ATT_RopeNeck", (0, 0, 0.33))], ((-0.20, -0.20, 0), (0.20, 0.20, 0.62))


# ================================================================ cleats (galvanised horn cleats)
def _cleat(P, L, H, base_w, region, bolts):
    P.box((-L * 0.36, -base_w / 2, 0.0), (L * 0.36, base_w / 2, 0.018), region, skip=("-z",))
    for sx in (-1, 1):
        # waisted post
        P.lathe([(base_w * 0.32, 0.018), (base_w * 0.26, H * 0.45), (base_w * 0.28, H * 0.7)], 10, region,
                frame(sx * L * 0.2, 0, 0), sy=0.75, cap0=False, cap1=False)
    # the horn bar: thick in the middle, tapering to rounded tips, slight upturn
    pts = [(-L / 2, 0, H * 0.86), (-L * 0.38, 0, H * 0.80), (-L * 0.2, 0, H * 0.74), (0, 0, H * 0.72),
           (L * 0.2, 0, H * 0.74), (L * 0.38, 0, H * 0.80), (L / 2, 0, H * 0.86)]
    rad = [0.35, 0.6, 0.85, 0.9, 0.85, 0.6, 0.35]
    r0 = H * 0.2
    sides = 10
    rings = []
    for (x, y, z), k in zip(pts, rad):
        rings.append([(x, y + r0 * k * math.cos(2 * math.pi * j / sides) * 0.85, z + r0 * k * math.sin(2 * math.pi * j / sides))
                      for j in range(sides)])
    vs = [p for ring in rings for p in ring]
    faces = [(i * sides + j, i * sides + (j + 1) % sides, (i + 1) * sides + (j + 1) % sides, (i + 1) * sides + j)
             for i in range(len(rings) - 1) for j in range(sides)]
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(range((len(rings) - 1) * sides, len(rings) * sides)))
    P.mesh(vs, faces, region)
    for b in bolts:
        P.bolt(b[0], b[1], 0.018, 0.012, 0.012, "Stainless")


def cleat_01():
    P = HP("Cleat01")
    _cleat(P, 0.30, 0.10, 0.075, "Galv", [(-0.09, 0, 0), (0.09, 0, 0)])
    return P, (0.30, 0.075, 0.10), [("ATT_Rope", (0, 0, 0.07))], ((-0.15, -0.04, 0), (0.15, 0.04, 0.10))


def cleat_02():
    P = HP("Cleat02")
    _cleat(P, 0.45, 0.15, 0.11, "GalvRust", [(-0.135, -0.03, 0), (-0.135, 0.03, 0), (0.135, -0.03, 0), (0.135, 0.03, 0)])
    return P, (0.45, 0.11, 0.15), [("ATT_Rope", (0, 0, 0.105))], ((-0.225, -0.055, 0), (0.225, 0.055, 0.15))


# ================================================================ fenders (PVC cylinder x3, ball, tyre)
def _cyl_fender(name, D, L, region):
    P = HP(name)
    r = D / 2
    eye_h = 0.05 * L / 0.6
    body0, body1 = eye_h, eye_h + L - 2 * eye_h
    prof = [(0.03, body0 - 0.002)]
    for k in range(6):           # rounded shoulder at each end
        t = k / 5 * math.pi / 2
        prof.append((0.03 + (r - 0.03) * math.sin(t), body0 + r * 0.55 * (1 - math.cos(t))))
    ribs = 4
    zA, zB = body0 + r * 0.55, body1 - r * 0.55
    for k in range(1, ribs):
        z = zA + (zB - zA) * k / ribs
        prof += [(r, z - 0.012), (r * 0.975, z), (r, z + 0.012)]
    for k in range(5, -1, -1):
        t = k / 5 * math.pi / 2
        prof.append((0.03 + (r - 0.03) * math.sin(t), body1 - r * 0.55 * (1 - math.cos(t))))
    prof.append((0.03, body1 + 0.002))
    prof = sorted(prof, key=lambda p: p[1])
    P.lathe(prof, 16, region)
    for z0, s in ((0.0, 1), (body1, -1)):   # moulded eyes at both ends
        P.lathe([(0.03, body0 if s > 0 else body1), (0.028, z0 + eye_h * 0.5), (0.02, z0 + (0 if s > 0 else eye_h))][::s],
                10, region, cap0=False, cap1=False)
        P.torus(0.022, 0.009, 10, 5, region, frame(0, 0, z0 + eye_h * (0.3 if s > 0 else 0.7), pitch=90))
    # fender line tied to the top eye, a short tail with an overhand knot
    top = body1 + eye_h * 0.7
    pts = [(0, -0.022, top), (0, 0, top + 0.03), (0, 0.01, top + 0.12), (0.01, 0.02, top + 0.22)]
    P.tube(pts, 0.006, 6, "RopeBlue")
    return P, (D, D, top + 0.22), [("ATT_Line", (0.01, 0.02, top + 0.22))], ((-r, -r, 0), (r, r, top))


def fender_cyl_01():
    return _cyl_fender("FenderCyl01", 0.20, 0.60, "PVCWhite")


def fender_cyl_02():
    return _cyl_fender("FenderCyl02", 0.25, 0.80, "PVCNavy")


def fender_cyl_03():
    return _cyl_fender("FenderCyl03", 0.30, 1.00, "PVCWhite")


def fender_ball():
    P = HP("FenderBall")
    r = 0.30
    prof = [(r * math.sin(math.pi * k / 16), r - r * math.cos(math.pi * k / 16)) for k in range(17)]
    prof[0] = (0.0, 0.0)
    prof[-1] = (0.0, 2 * r)
    P.lathe(prof, 24, "BallOrange", cap0=False, cap1=False)
    # moulded rope eye on top + reinforcing collar
    P.lathe([(0.045, 2 * r - 0.004), (0.04, 2 * r + 0.02), (0.03, 2 * r + 0.025)], 12, "BallOrange", cap0=False)
    P.torus(0.035, 0.012, 12, 6, "BallOrange", frame(0, 0, 2 * r + 0.05, pitch=90))
    P.tube([(0, -0.035, 2 * r + 0.06), (0, 0, 2 * r + 0.1), (0.01, 0.01, 2 * r + 0.3)], 0.007, 6, "RopeBlue")
    return P, (0.60, 0.60, 2 * r + 0.3), [("ATT_Line", (0.01, 0.01, 2 * r + 0.3))], ((-r, -r, 0), (r, r, 2 * r))


def fender_tyre():
    """Car tyre hung against the quay wall on a rope through its top, 0.62 m x 0.2 m (wall face is +Y)."""
    P = HP("FenderTyre")
    Ro, Ri, W = 0.31, 0.19, 0.20
    M = frame(0, 0.0, Ro, pitch=90)       # tyre axis along Y, centre at Ro height
    segs = 28
    tread = [(Ro - 0.01, -W / 2), (Ro, -W * 0.4), (Ro, W * 0.4), (Ro - 0.01, W / 2)]
    side_o = [(Ro - 0.01, W / 2), (Ro - 0.045, W * 0.52), (Ri + 0.04, W * 0.47), (Ri + 0.012, W * 0.42), (Ri, W * 0.38)]
    bead = [(Ri, W * 0.38), (Ri - 0.004, 0.0), (Ri, -W * 0.38)]
    side_i = [(Ri, -W * 0.38), (Ri + 0.012, -W * 0.42), (Ri + 0.04, -W * 0.47), (Ro - 0.045, -W * 0.52), (Ro - 0.01, -W / 2)]
    P.lathe(tread, segs, "Tread", M, cap0=False, cap1=False)
    P.lathe(side_o, segs, "Rubber", M, cap0=False, cap1=False)
    P.lathe(bead, segs, "Rubber", M, cap0=False, cap1=False)
    P.lathe(side_i, segs, "Rubber", M, cap0=False, cap1=False)
    # hanging rope: through the tyre top, both legs up to a hitch point 0.7 m above
    top = 2 * Ro
    pts = [(0.0, 0.0, top + 0.70), (-0.05, 0.02, top + 0.4), (-0.08, 0.04, top + 0.06), (-0.06, 0.04, top - 0.07),
           (0.0, 0.0, top - 0.12), (0.06, -0.04, top - 0.07), (0.08, -0.04, top + 0.06), (0.05, -0.02, top + 0.4),
           (0.0, 0.0, top + 0.70)]
    P.tube(pts, 0.012, 6, "RopeBlack")
    return P, (0.62, 0.21, top + 0.70), [("ATT_Hang", (0, 0, top + 0.70))], ((-Ro, -W / 2, 0), (Ro, W / 2, top))


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
    # ring body in arcs: SOLAS orange with 4 retro tape bands (each 50 mm) at 45 / 135 / 225 / 315 degrees
    tape = 0.05 / Rc
    a = 0.0
    marks = sorted([math.radians(d) for d in (45, 135, 225, 315)])
    spans = []
    prev = 0.0
    for m in marks:
        spans.append(("SOLAS", prev, m - tape / 2))
        spans.append(("Retro", m - tape / 2, m + tape / 2))
        prev = m + tape / 2
    spans.append(("SOLAS", prev, 2 * math.pi))
    for reg, a0, a1 in spans:
        n = max(1, int(round((a1 - a0) / (2 * math.pi) * 24)))
        R.torus(Rc, rt, n, 8, reg, Mr, arc=a1 - a0, a0=a0, sr=0.92)
    # grab line festooned in 4 loops round the ring, seized at the tape bands
    pts = []
    for k in range(33):
        th = 2 * math.pi * k / 32
        sag = abs(math.sin(2 * th))
        rr = Rc + rt * 0.95 + 0.03 * sag
        pts.append((rr * math.cos(th), cy - 0.02 * sag, cz + rr * math.sin(th)))
    R.tube(pts, 0.006, 4, "RopeThrow", closed=False, caps=False, k=1)
    # throw line: a coiled 30 m floating line hung on the lower hook
    for k in range(3):
        rr = 0.12 + 0.008 * k
        cpts = [(rr * 0.8 * math.sin(2 * math.pi * j / 12), y0 + 0.07 + 0.006 * k,
                 z0 + 0.17 - rr + rr * math.cos(2 * math.pi * j / 12)) for j in range(12)]
        R.tube(cpts, 0.006, 4, "RopeThrow", closed=True, k=1)
    atts = [("ATT_Ring", (0, cy, cz)), ("ATT_ThrowLine", (0, y0 + 0.07, z0 + 0.05))]
    return [("Housing", "Metal", H), ("Ring", "Rope", R)], (0.94, 0.30, z1 + 0.03), atts, \
        ((-cw / 2 - 0.02, -0.2, 0), (cw / 2 + 0.02, 0.2, z1 + 0.03))


# ================================================================ lobster pots
def lobster_pot_01():
    """Inkwell pot: weighted rubber base, plastic-coated bows, black netting dome, entrance neck at the top."""
    P = HP("LobsterPot01")
    Rb, Hd = 0.30, 0.40
    P.lathe([(0.0, 0.0), (Rb, 0.0), (Rb + 0.01, 0.03), (Rb, 0.07), (Rb - 0.03, 0.08), (0.0, 0.085)], 24, "PotBase",
            cap0=False, cap1=False)
    neck_r = 0.10

    def dome(r_scale, z0):
        prof = []
        for k in range(9):
            t = k / 8
            prof.append(((Rb - 0.025) * (1 - t) ** 0.8 * r_scale + neck_r * t, z0 + (Hd - z0) * math.sin(t * math.pi / 2)))
        return prof
    P.lathe(dome(1.0, 0.08), 20, "NetBlack", cap0=False, cap1=False)
    # entrance funnel hanging into the pot from the neck ring
    P.lathe([(neck_r, Hd), (0.075, Hd - 0.08), (0.06, Hd - 0.16)], 14, "NetBlack", cap0=False, cap1=False)
    # bows: 6 coated steel half-hoops base -> neck, and the neck ring
    for i in range(6):
        th = i * math.pi / 3
        pts = []
        for p in dome(1.02, 0.08):
            pts.append((p[0] * math.cos(th), p[0] * math.sin(th), p[1]))
        P.sweep(pts, 0.007, 5, "PotCoat", caps=False)
    P.torus(neck_r, 0.012, 16, 5, "PotCoat", frame(0, 0, Hd))
    P.torus(Rb - 0.025, 0.01, 24, 5, "PotCoat", frame(0, 0, 0.085))
    # bridle rope with a loop for the back line
    P.tube([(-0.12, 0, Hd - 0.03), (-0.05, 0, Hd + 0.12), (0.05, 0, Hd + 0.12), (0.12, 0, Hd - 0.03)], 0.006, 5, "RopeOrange")
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

    # netting: arched top surface + two ends + floor + middle parlour partition
    def top(u, v):
        x = -L / 2 + L * u
        a = math.pi * v
        return (x, (W / 2 - 0.004) * math.cos(a), 0.012 + (H - 0.016) * math.sin(a))
    P.grid(top, 3, 8, "NetBlue")
    for x in (-L / 2, 0.0, L / 2):
        vs = [(x, 0, 0.012)] + [(x, (W / 2) * math.cos(math.pi * j / 8), 0.012 + (H - 0.012) * math.sin(math.pi * j / 8))
                                for j in range(9)]
        P.mesh(vs, [(0, j + 1, j + 2) for j in range(8)], "NetBlue")
    P.grid(lambda u, v: (-L / 2 + L * u, -W / 2 + W * v, 0.014), 2, 1, "NetBlue")
    # side entrance eyes (soft funnels with a plastic ring) on -Y, one per chamber end
    for x in (-L / 4, L / 4):
        P.lathe([(0.10, 0.0), (0.07, 0.12), (0.06, 0.2)], 12, "NetBlue",
                frame(x, -W / 2 + 0.05, 0.17, pitch=-90), sy=0.8, cap0=False, cap1=False)
        P.torus(0.06, 0.008, 12, 5, "PotCoat", frame(x, -W / 2 + 0.05 + 0.2, 0.17, pitch=90))
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
    P = HP("NetPile")
    rng = random.Random(5)
    Rx, Ry, Hh = 1.0, 0.75, 0.55
    bumps = [(rng.uniform(-0.6, 0.6), rng.uniform(-0.45, 0.45), rng.uniform(0.15, 0.35), rng.uniform(0.04, 0.12))
             for _ in range(9)]

    def height(x, y):
        d = (x / Rx) ** 2 + (y / Ry) ** 2
        h = Hh * max(0.0, 1 - d) ** 0.7
        for bx, by, br, bh in bumps:
            h += bh * math.exp(-((x - bx) ** 2 + (y - by) ** 2) / (br * br)) * (1 if d < 1 else 0)
        return h

    def shell(scale, lift, region, nu, nv, phase):
        def fn(u, v):
            a = 2 * math.pi * u
            rr = v
            wob = 1 + 0.06 * math.sin(5 * a + phase) + 0.04 * math.sin(9 * a + 2 * phase)
            x, y = Rx * scale * rr * wob * math.cos(a), Ry * scale * rr * wob * math.sin(a)
            z = height(x / scale, y / scale) * scale + lift * (1 - rr ** 3)
            if v >= 0.999:
                z = 0.01
            return (x, y, max(z, 0.005))
        P.grid(fn, nu, nv, region, closed_u=True)
    shell(0.93, 0.0, "NetDense", 20, 5, 0.0)
    shell(1.0, 0.03, "NetGreen", 24, 6, 1.3)
    shell(1.06, 0.06, "NetOrange", 22, 5, 2.4)
    # loose folds trailing off the heap
    for k in range(3):
        a0 = rng.uniform(0, 2 * math.pi)

        def fold(u, v, a0=a0):
            a = a0 + (u - 0.5) * 0.7
            r = Rx * (0.85 + 0.45 * v) if abs(math.cos(a)) > 0.5 else Ry * (0.85 + 0.55 * v)
            return (r * math.cos(a), r * math.sin(a) * (Ry / Rx), 0.02 + 0.12 * (1 - v) * math.sin(math.pi * u))
        P.grid(fold, 4, 2, "NetGreen")
    # headline with floats, and a groundrope coil
    pts = []
    for k in range(40):
        a = 2 * math.pi * k / 39 * 1.6 + 0.4
        rr = 0.35 + 0.45 * k / 39
        x, y = Rx * rr * math.cos(a), Ry * rr * math.sin(a)
        pts.append((x, y, height(x, y) + 0.06))
    P.tube(pts, 0.008, 6, "RopeBlue", k=1)
    for k in range(4, 40, 6):
        x, y, z = pts[k]
        P.lathe([(0.0, -0.06), (0.05, -0.045), (0.065, 0.0), (0.05, 0.045), (0.0, 0.06)], 10, "Float", frame(x, y, z + 0.01))
    gp = [(Rx * 0.98 * math.cos(a), Ry * 0.98 * math.sin(a), 0.03) for a in np.linspace(-0.6, 2.2, 18)]
    P.tube(gp, 0.025, 6, "RopeBlack", k=1)
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
    """Mooring line (24 mm braid) flaked down on the quay in long S-flakes, the spliced eye on top."""
    P = HP("RopeFlaked")
    d = 0.024
    pts = []
    n = 7
    for i in range(n):
        y = -0.35 + i * 0.1
        xs = (-0.55, 0.55) if i % 2 == 0 else (0.55, -0.55)
        z = d / 2 + 0.6 * d * (i / n)
        for k in range(9):
            t = k / 8
            x = xs[0] + (xs[1] - xs[0]) * t
            pts.append((x, y + 0.012 * math.sin(math.pi * t * 3), z))
        if i < n - 1:   # bight round to the next flake
            cx = xs[1] + (0.05 if xs[1] > 0 else -0.05)
            for k in range(1, 6):
                a = math.pi * k / 6
                pts.append((cx + (0.05 if xs[1] > 0 else -0.05) * math.sin(a) - (0.05 if xs[1] > 0 else -0.05) * 0,
                            y + 0.05 - 0.05 * math.cos(a), z + 0.3 * d))
    # spliced eye on top of the flakes
    ex, ey = pts[-1][0], pts[-1][1]
    eye = [(ex + (0.0 if ex < 0 else 0), ey, d * 1.5)]
    for k in range(13):
        a = math.pi + 2 * math.pi * k / 12
        eye.append((ex - 0.18 * (1 if ex < 0 else -1) + 0.18 * math.cos(a) * (1 if ex < 0 else -1), ey - 0.1 + 0.1 * math.sin(a) * 1.2,
                    d * 1.6))
    P.tube(pts + eye, d / 2, 6, "RopeBraid", k=1)
    return P, (1.25, 0.8, 0.07), [("ATT_Eye", eye[6])], ((-0.6, -0.4, 0), (0.6, 0.35, 0.06))


def rope_chain():
    """16 mm short-link mooring chain dumped in a heap with a 1 m tail."""
    P = HP("RopeChain")
    rng = random.Random(3)
    link_l, link_w, wire = 0.10, 0.064, 0.0085
    path = []
    for k in range(19):    # heap spiral
        a = k * 0.62
        rr = 0.08 + 0.012 * k
        path.append((rr * math.cos(a), rr * math.sin(a), wire + 0.02 * max(0, 6 - k * 0.25) + rng.uniform(0, 0.01)))
    for k in range(1, 7):   # tail across the quay
        path.append((path[-1][0] + 0.085, path[-1][1] - 0.01 * rng.uniform(-1, 1), wire))
    for i in range(len(path) - 1):
        p0, p1 = Vector(path[i]), Vector(path[i + 1])
        c = (p0 + p1) / 2
        dv = (p1 - p0).normalized()
        yaw = math.degrees(math.atan2(dv.y, dv.x))
        pitch = math.degrees(math.asin(max(-1, min(1, dv.z))))
        roll = 0 if i % 2 == 0 else 90
        M = (Matrix.Translation(c) @ Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(-pitch), 4, 'Y')
             @ Matrix.Rotation(math.radians(roll), 4, 'X'))
        # stadium link: two straight sides + two half-torus ends, in the XY plane of M
        rr = (link_w - wire * 2) / 2 * 0.5 + wire * 0.5
        straight = link_l - link_w
        for s in (-1, 1):
            P.torus(rr, wire, 5, 4, "Chain", M @ frame(s * straight / 2, 0, 0, yaw=0 if s > 0 else 180), arc=math.pi, a0=-math.pi / 2)
            M2 = M @ Matrix.Translation((0, s * rr, 0))
            P.cyl(tuple(M2 @ Vector((-straight / 2, 0, 0))), tuple(M2 @ Vector((straight / 2, 0, 0))), wire, 4, "Chain",
                  caps=False, split=1)
    lo = np.min(np.array(path), 0)
    hi = np.max(np.array(path), 0)
    return P, (float(hi[0] - lo[0]) + 0.1, float(hi[1] - lo[1]) + 0.1, None), [("ATT_End", tuple(path[-1]))], \
        ((lo[0] - 0.05, lo[1] - 0.05, 0), (hi[0] + 0.05, hi[1] + 0.05, 0.12))


# ================================================================ table + spec
# asset: (builder, set (single-part assets), docs/12 row ceiling, collision box?, note)
PROPS = {
    "M_Hbr_Bollard_01": (bollard_01, "Metal", 800, True),
    "M_Hbr_Bollard_02": (bollard_02, "Metal", 800, True),
    "M_Hbr_Bollard_03": (bollard_03, "Metal", 800, True),
    "M_Hbr_Cleat_01": (cleat_01, "Metal", 400, False),
    "M_Hbr_Cleat_02": (cleat_02, "Metal", 400, False),
    "M_Hbr_Fender_Cyl_01": (fender_cyl_01, "Rope", 1200, False),
    "M_Hbr_Fender_Cyl_02": (fender_cyl_02, "Rope", 1200, False),
    "M_Hbr_Fender_Cyl_03": (fender_cyl_03, "Rope", 1200, False),
    "M_Hbr_Fender_Ball": (fender_ball, "Rope", 1200, False),
    "M_Hbr_Fender_Tyre": (fender_tyre, "Rope", 1200, False),
    "M_Hbr_LifebuoyStation": (lifebuoy_station, None, 1500, True),
    "M_Hbr_LobsterPot_01": (lobster_pot_01, "Rope", 3000, True),
    "M_Hbr_LobsterPot_02": (lobster_pot_02, "Rope", 3000, True),
    "M_Hbr_FishBox_01": (fish_box_01, "Rope", 1500, True),
    "M_Hbr_FishBox_02": (fish_box_02, "Rope", 1500, True),
    "M_Hbr_NetPile": (net_pile, "Rope", 3000, False),
    "M_Hbr_Rope_Coil": (rope_coil, "Rope", 2500, False),
    "M_Hbr_Rope_Flaked": (rope_flaked, "Rope", 2500, False),
    "M_Hbr_Rope_Chain": (rope_chain, "Metal", 2500, False),
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
