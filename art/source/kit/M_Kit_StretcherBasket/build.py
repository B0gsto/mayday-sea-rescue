"""M_Kit_StretcherBasket: Stokes/Ferno-style rescue basket stretcher (docs/12 2.8, 3,000 tris, kit set).

2.13 x 0.61 x 0.20 m, long axis Y, head at -Y (the rim rail is raised there: the "head guard"), base at Z 0.
Galvanised tube frame: closed rim rail, 4 cross ribs over two longitudinal runners with turned-up tips, a two-piece
join with bolted sleeves at the middle of each side, 4 welded lifting eyes at the head/foot corners, 4 grab handles.
Orange HDPE tub inside the frame: moulded ribs, drain holes in the bottom and the walls, a bolted foot plate at the
foot end and 4 black webbing patient straps with steel ladder-lock buckles.

Geometry is authored in metres from dims.py and written in studs (1 m = 3 studs), so no transform is ever applied.
UVs are cut to the atlas lanes of dims.py; positions that the paint needs (drain holes, welds, strap rows, plate) are
dumped to features.json and painted by maketex.py, which writes the asset's own set T_StretcherBasket_Kit_* (with
_Wet) under the out-root before validate looks for the maps.
"""
import json
import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import dims  # noqa: E402
import maketex  # noqa: E402
from dims import (A, B, FILW, FOOT_Y, HEADTAP, LIP_DROP, NEXP, NRIB, NRIM, NSH, RIB_R, RIB_Y, RING_R, RING_r,
                  RUN_R, RUN_X, RUN_Y, SHELL_A, SHELL_B, SLING_Y, STRAP_T, STRAP_W, STRAP_Y, TUBE_S, ZB_IN,
                  ZB_OUT, ZF, ZH, RAISE)  # noqa: E402

S = common.STUDS_PER_METRE
RUN_Z = RUN_R * math.cos(math.pi / 6.0)    # 6-sided skid tube: its flat face sits on Z 0
NAME = "M_Kit_StretcherBasket"
MI = "MI_StretcherBasket_Kit"
FEATURES = []


# ---------------------------------------------------------------- plan maths
def sgn(v):
    return -1.0 if v < 0.0 else 1.0


def cl(v, a=0.0, b=1.0):
    return a if v < a else b if v > b else v


def smoothstep(e0, e1, x):
    t = cl((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def outline(th, a=A, b=B):
    """Plan outline (x, y) in metres at angle th (CCW); the head end (-Y) is narrowed."""
    c, s = math.cos(th), math.sin(th)
    x = sgn(c) * abs(c) ** (2.0 / NEXP)
    y = sgn(s) * abs(s) ** (2.0 / NEXP) * b
    t = cl((abs(y) / b - 0.45) / 0.55)
    return x * a * (1.0 - HEADTAP * t ** 2.5), y


def x_at_y(y, a=A, b=B):
    """Half width of the outline at y (the plan is monotone in y)."""
    sy = min(1.0, abs(y) / b)
    s = sy ** (NEXP / 2.0)
    c = max(0.0, 1.0 - s * s) ** 0.5
    x = a * c ** (2.0 / NEXP)
    t = cl((abs(y) / b - 0.45) / 0.55)
    return x * (1.0 - HEADTAP * t ** 2.5)


def th_at_y(y):
    """Angle of the outline at y on the +X side."""
    sy = min(1.0, abs(y) / B)
    s = sy ** (NEXP / 2.0)
    c = max(0.0, 1.0 - s * s) ** 0.5
    th = math.atan2(s, c)
    return th if y >= 0 else -th


def onrm(th, a=A, b=B):
    """Outward unit normal of the outline at th."""
    d = 0.003
    p0, p1 = outline(th - d, a, b), outline(th + d, a, b)
    tx, ty = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(tx, ty) or 1.0
    return (ty / L, -tx / L)


def curv_r(th, a=A, b=B):
    """Radius of curvature (metres) at th, for clamping inward offsets."""
    d = 0.012
    p0, p1, p2 = outline(th - d, a, b), outline(th, a, b), outline(th + d, a, b)
    dx, dy = (p2[0] - p0[0]) / (2 * d), (p2[1] - p0[1]) / (2 * d)
    ddx, ddy = (p2[0] - 2 * p1[0] + p0[0]) / (d * d), (p2[1] - 2 * p1[1] + p0[1]) / (d * d)
    num = abs(dx * ddy - dy * ddx)
    return ((dx * dx + dy * dy) ** 1.5) / num if num > 1e-9 else 1e3


def rim_z(y):
    return ZF + (ZH - ZF) * smoothstep(RAISE[0], RAISE[1], cl(-y / B))


def lip_z(y):
    return rim_z(y) - LIP_DROP


def rim_arc(n=1440):
    """Fine (th, x, y, arc fraction) table of the rail centreline, closed, starting at the head tip."""
    out, cum = [], [0.0]
    prev = None
    for i in range(n + 1):
        th = 2 * math.pi * i / n - math.pi / 2
        x, y = outline(th)
        if prev is not None:
            cum.append(cum[-1] + math.hypot(x - prev[0], y - prev[1]))
        prev = (x, y)
        out.append((th, x, y, cum[-1]))
    total = cum[-1]
    return [(th, x, y, a / total) for th, x, y, a in out]


def arc_table(a, b, n=1440):
    """Fine (th, x, y, arc fraction, total length in m) table of an outline, closed, from the head tip."""
    out, cum = [], [0.0]
    prev = None
    for i in range(n + 1):
        th = 2 * math.pi * i / n - math.pi / 2
        x, y = outline(th, a, b)
        if prev is not None:
            cum.append(cum[-1] + math.hypot(x - prev[0], y - prev[1]))
        prev = (x, y)
        out.append((th + math.pi / 2, cum[-1]))
    total = cum[-1]
    return [(t, f / total) for t, f in out], total


def _u_of(table, th):
    tt = (th + math.pi / 2) % (2 * math.pi)
    lo, hi = 0, len(table) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if table[mid][0] <= tt:
            lo = mid
        else:
            hi = mid
    t0, t1 = table[lo][0], table[hi][0]
    f = (tt - t0) / (t1 - t0) if t1 > t0 else 0.0
    return table[lo][1] + (table[hi][1] - table[lo][1]) * f


RAIL_ARC, RAIL_LEN = arc_table(A, B)
SHELL_ARC, SHELL_LEN = arc_table(SHELL_A, SHELL_B)


def rim_u(th):
    return _u_of(RAIL_ARC, th)


def shell_u(th):
    return _u_of(SHELL_ARC, th)


# ---------------------------------------------------------------- builder
class Buf:
    def __init__(self):
        self.v = []
        self.f = []

    def add(self, p):
        self.v.append((p[0] * S, p[1] * S, p[2] * S))
        return len(self.v) - 1

    def face(self, ids, lane, uvs):
        if len(set(ids)) < 3:
            return
        self.f.append((tuple(ids), lane, tuple(dims.uv(lane, u, v) for u, v in uvs)))

    def to_object(self, obj_name, material):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new(common.UV_NAME)
        bv = [bm.verts.new(p) for p in self.v]
        for idx, lane, uvs in self.f:
            try:
                f = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            for loop, uv in zip(f.loops, uvs):
                loop[uvl].uv = uv
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        for p in mesh.polygons:
            p.use_smooth = True
        try:
            mesh.set_sharp_from_angle(angle=math.radians(38.0))
        except Exception:
            pass
        mesh.materials.append(material)
        obj = bpy.data.objects.new(obj_name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def frames(pts, closed):
    n = len(pts)
    out = []
    for i in range(n):
        a, b = (pts[(i - 1) % n], pts[(i + 1) % n]) if closed else (pts[max(0, i - 1)], pts[min(n - 1, i + 1)])
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1.0
        out.append((ty / L, -tx / L))
    return out


def sweep(Bu, pts, prof, lane, u_of, closed=False, caps=(False, False), cap_z=0.8):
    """Section sweep. prof: [(n_off, z_off, v)] (n = horizontal frame normal, z = up, v = lane v)."""
    ns = len(prof)
    fr = frames(pts, closed)
    rings = []
    for i, p in enumerate(pts):
        nx, ny = fr[i]
        rings.append([Bu.add((p[0] + nx * q[0], p[1] + ny * q[0], p[2] + q[1])) for q in prof])
    m = len(rings)
    for i in range(m if closed else m - 1):
        r0, r1 = rings[i], rings[(i + 1) % m]
        u0, u1 = u_of(i), u_of(i + 1)
        for j in range(ns):
            k = (j + 1) % ns
            Bu.face([r0[j], r0[k], r1[k], r1[j]], lane,
                    [(u0, prof[j][2]), (u0, prof[k][2]), (u1, prof[k][2]), (u1, prof[j][2])])
    for end in (0, 1):
        if not caps[end]:
            continue
        i = 0 if end == 0 else m - 1
        j0, j1 = (1, 0) if end == 0 else (m - 2, m - 1)
        t = tuple(pts[j1][k] - pts[j0][k] for k in range(3))
        L = math.sqrt(sum(v * v for v in t)) or 1.0
        t = tuple(v / L for v in t)
        rp = max(q[0] for q in prof)
        c = Bu.add(tuple(pts[i][k] + t[k] * rp * cap_z for k in range(3)))
        u0 = u_of(i)
        uc = u0 + (0.005 if end == 0 else -0.005)
        for j in range(ns):
            k = (j + 1) % ns
            Bu.face([rings[i][j], rings[i][k], c], lane,
                    [(u0, prof[j][2]), (u0, prof[k][2]), (uc, (prof[j][2] + prof[k][2]) / 2.0)])
    return rings


def tube_prof(sides, r, v0=0.0, v1=1.0):
    """Round profile: v 0 outward, 0.25 up, 0.5 inward, 0.75 down."""
    return [(r * math.cos(2 * math.pi * j / sides), r * math.sin(2 * math.pi * j / sides), v0 + (v1 - v0) * j / float(sides))
            for j in range(sides)]


def ribbon(Bu, pts, w, t, lane, u_of):
    """Flat strap: width w along Y, thickness t perpendicular to the path (paths run in the X-Z plane)."""
    rings = []
    per = 2 * (w + t)
    vs = [0.0, w / per, (w + t) / per, (2 * w + t) / per]
    for i, p in enumerate(pts):
        a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
        tx, tz = b[0] - a[0], b[2] - a[2]
        L = math.hypot(tx, tz) or 1.0
        ux, uz = tz / L, -tx / L
        rings.append([Bu.add((p[0] + ux * t / 2, p[1] + w / 2, p[2] + uz * t / 2)),
                      Bu.add((p[0] + ux * t / 2, p[1] - w / 2, p[2] + uz * t / 2)),
                      Bu.add((p[0] - ux * t / 2, p[1] - w / 2, p[2] - uz * t / 2)),
                      Bu.add((p[0] - ux * t / 2, p[1] + w / 2, p[2] - uz * t / 2))])
    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        u0, u1 = u_of(i), u_of(i + 1)
        for j in range(4):
            k = (j + 1) % 4
            Bu.face([r0[j], r0[k], r1[k], r1[j]], lane,
                    [(u0, vs[j]), (u0, vs[k]), (u1, vs[k]), (u1, vs[j])])
    return rings


def box(Bu, c, size, lane, rect, rot=0.0):
    """Block: centre c (m), size (sx, sy, sz), UVs in a sub-rect (u0, u1, v0, v1)."""
    u0, u1, v0, v1 = rect
    ax, ay, az = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    ca, sa = math.cos(rot), math.sin(rot)
    corners = [(-ax, -ay, -az), (ax, -ay, -az), (ax, ay, -az), (-ax, ay, -az),
               (-ax, -ay, az), (ax, -ay, az), (ax, ay, az), (-ax, ay, az)]
    ids = [Bu.add((c[0] + x * ca - y * sa, c[1] + x * sa + y * ca, c[2] + z)) for x, y, z in corners]
    uv = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        Bu.face([ids[i] for i in f], lane, uv)
    return ids


def _basis(axis):
    L = math.sqrt(sum(v * v for v in axis)) or 1.0
    ax = tuple(v / L for v in axis)
    ref = (0.0, 0.0, 1.0) if abs(ax[2]) < 0.9 else (1.0, 0.0, 0.0)
    nx = (ax[1] * ref[2] - ax[2] * ref[1], ax[2] * ref[0] - ax[0] * ref[2], ax[0] * ref[1] - ax[1] * ref[0])
    Ln = math.sqrt(sum(v * v for v in nx)) or 1.0
    nx = tuple(v / Ln for v in nx)
    ny = (ax[1] * nx[2] - ax[2] * nx[1], ax[2] * nx[0] - ax[0] * nx[2], ax[0] * nx[1] - ax[1] * nx[0])
    return ax, nx, ny


def cyl(Bu, c, axis, r, h, lane, rect, segs=6):
    """Stud / bolt head: 2 side rings + a rounded end, UVs in a sub-rect."""
    u0, u1, v0, v1 = rect
    ax, nx, ny = _basis(axis)
    rings = []
    for t, rr, vv in ((0.0, r, 0.12), (h, r * 0.94, 0.78)):
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            ring.append(Bu.add((c[0] + ax[0] * t + (nx[0] * math.cos(a) + ny[0] * math.sin(a)) * rr,
                                c[1] + ax[1] * t + (nx[1] * math.cos(a) + ny[1] * math.sin(a)) * rr,
                                c[2] + ax[2] * t + (nx[2] * math.cos(a) + ny[2] * math.sin(a)) * rr)))
        rings.append((ring, vv))
    for i in range(1):
        for j in range(segs):
            k = (j + 1) % segs
            us = [u0 + (u1 - u0) * j / segs, u0 + (u1 - u0) * (j + 1) / segs]
            Bu.face([rings[i][0][j], rings[i][0][k], rings[i + 1][0][k], rings[i + 1][0][j]], lane,
                    [(us[0], v0 + (v1 - v0) * rings[i][1]), (us[1], v0 + (v1 - v0) * rings[i][1]),
                     (us[1], v0 + (v1 - v0) * rings[i + 1][1]), (us[0], v0 + (v1 - v0) * rings[i + 1][1])])
    cid = Bu.add(tuple(c[k] + ax[k] * (h + r * 0.30) for k in range(3)))
    for j in range(segs):
        k = (j + 1) % segs
        us = [u0 + (u1 - u0) * j / segs, u0 + (u1 - u0) * (j + 1) / segs]
        Bu.face([rings[1][0][j], rings[1][0][k], cid], lane,
                [(us[0], v0 + (v1 - v0) * rings[1][1]), (us[1], v0 + (v1 - v0) * rings[1][1]),
                 (us[1], v0 + (v1 - v0) * 0.98)])


def torus(Bu, centre, axis, R, r, nu, nv, lane, rect):
    """Lifting eye ring: the major circle lies perpendicular to `axis`."""
    u0, u1, v0, v1 = rect
    ax, nx, ny = _basis(axis)
    ring = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        d = tuple(nx[k] * math.cos(a) + ny[k] * math.sin(a) for k in range(3))
        loop = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            k, rr = math.cos(b) * R, math.sin(b) * r
            loop.append(Bu.add(tuple(centre[m] + d[m] * k + ax[m] * rr for m in range(3))))
        ring.append(loop)
    for i in range(nu):
        i1 = (i + 1) % nu
        for j in range(nv):
            j1 = (j + 1) % nv
            us = [u0 + (u1 - u0) * i / nu, u0 + (u1 - u0) * (i + 1) / nu]
            vs = [v0 + (v1 - v0) * j / nv, v0 + (v1 - v0) * (j + 1) / nv]
            Bu.face([ring[i][j], ring[i][j1], ring[i1][j1], ring[i1][j]], lane,
                    [(us[0], vs[0]), (us[0], vs[1]), (us[1], vs[1]), (us[1], vs[0])])


FIT = dims.FIT


# ---------------------------------------------------------------- parts
def build_rim(Bu):
    pts = []
    for i in range(NRIM):
        th = 2 * math.pi * i / NRIM - math.pi / 2
        x, y = outline(th)
        pts.append((x, y, rim_z(y)))
    uarc = [rim_u(2 * math.pi * i / NRIM - math.pi / 2) for i in range(NRIM)]
    sweep(Bu, pts, tube_prof(8, 0.015), "rim", lambda i: uarc[i % NRIM], closed=True)
    for y in RIB_Y:                                   # welds where the ribs meet the rail
        for sx in (1, -1):
            th = th_at_y(y) * sx
            FEATURES.append({"kind": "weld", "lane": "rim", "u": rim_u(th) if sx > 0 else rim_u(th),
                             "v": 0.72, "ru": 0.013, "rv": 0.24, "style": "frame"})
    return uarc


def build_frame(Bu):
    zr = ZB_OUT - RIB_R - 0.0002
    for yi, y in enumerate(RIB_Y):
        xe = x_at_y(y) - 0.008
        pts = [(-xe, y, zr), (0.0, y, zr - 0.0015), (xe, y, zr)]
        base = yi / float(NRIB)
        sweep(Bu, pts, tube_prof(TUBE_S, RIB_R), "ribs",
              lambda i, b=base: b + (i / 2.0) / NRIB, closed=False)
        for f in (0.005, 0.995):
            FEATURES.append({"kind": "weld", "lane": "ribs", "u": base + f / NRIB, "v": 0.75,
                             "ru": 0.010, "rv": 0.20, "style": "frame"})
    for i, x in enumerate(RUN_X):
        pts = []
        for k in range(9):
            t = k / 8.0
            y = -RUN_Y + 2 * RUN_Y * t
            pts.append((x, y, RUN_Z + 0.062 * smoothstep(0.60, RUN_Y, abs(y)) ** 1.4))
        base = i / 2.0
        sweep(Bu, pts, tube_prof(TUBE_S, RUN_R), "runners",
              lambda k, b=base: b + k / 8.0 / 2.0, closed=False, caps=(True, True), cap_z=1.0)
        for y in RIB_Y:
            FEATURES.append({"kind": "weld", "lane": "runners", "u": base + (y + RUN_Y) / (2 * RUN_Y) / 2.0,
                             "v": 0.25, "ru": 0.010, "rv": 0.20, "style": "frame"})
    for th in (0.0, math.pi):                          # two-piece join: a bolted sleeve each side
        pts = []
        for k in range(3):
            x, y = outline(th + (k - 1) * 0.075 / A)
            pts.append((x, y, rim_z(y)))
        rect = FIT["sleeve"]
        sweep(Bu, pts, tube_prof(6, 0.019, rect[2] + 0.03, rect[3] - 0.03), "fittings",
              lambda k: rect[0] + (rect[1] - rect[0]) * (0.30 + 0.4 * k), closed=False, caps=(True, True), cap_z=0.7)
        for x in (x_at_y(0.0) + 0.013, -x_at_y(0.0) - 0.013):
            for y in (-0.030, 0.030):
                cyl(Bu, (x, y, rim_z(y)), (sgn(x), 0.0, 0.0), 0.0045, 0.008, "fittings", FIT["bolt"], segs=6)
    for th in (0.0, math.pi):                          # grab handles
        for off in (-0.16, 0.16):
            a = th + off / A
            x, y = outline(a)
            z = rim_z(y)
            nx, ny = onrm(a)
            pts = []
            for k in range(4):
                t = k / 3.0
                e = math.sin(math.pi * t) * 0.016
                w = (t - 0.5) * 0.170
                pts.append((x + nx * e - ny * w, y + ny * e + nx * w, z - 0.020 - 0.046 * math.sin(math.pi * t)))
            rect = FIT["handle"]
            sweep(Bu, pts, tube_prof(TUBE_S, 0.0090, rect[2] + 0.05, rect[3] - 0.05), "fittings",
                  lambda k: rect[0] + (rect[1] - rect[0]) * (0.10 + 0.28 * k), closed=False, caps=(True, True), cap_z=0.9)
            FEATURES.append({"kind": "grip", "lane": "fittings", "u": rect[0] + 0.55 * (rect[1] - rect[0]),
                             "v": rect[2] + 0.5 * (rect[3] - rect[2]), "su": rect[1] - rect[0],
                             "sv": rect[3] - rect[2]})


def build_shell(Bu):
    """Orange tub: rows from the inner bottom centre out over the fillet, wall, lip, outer wall, outer bottom."""
    cols = NSH
    ths = [2 * math.pi * i / cols - math.pi / 2 for i in range(cols)]

    def rp(th, k):
        x, y = outline(th, SHELL_A, SHELL_B)
        nx, ny = onrm(th, SHELL_A, SHELL_B)
        R = math.hypot(x, y) or 1e-6
        fw = min(FILW, 0.55 * curv_r(th, SHELL_A, SHELL_B), 0.30 * R)
        lip = lip_z(y)
        if k == 0:
            return (x * 0.16, y * 0.16, ZB_IN)
        if k == 1:
            return (x * 0.42, y * 0.42, ZB_IN)
        if k == 2:
            return (x * 0.78, y * 0.78, ZB_IN)
        if k == 3:
            return (x - nx * fw, y - ny * fw, ZB_IN + 0.010)
        if k == 4:
            return (x - nx * fw * 0.30, y - ny * fw * 0.30, ZB_IN + 0.028)
        if k == 5:
            return (x, y, ZB_IN + 0.036)
        if k == 6:
            return (x + nx * 0.002, y + ny * 0.002, lip - 0.016)
        if k == 7:
            return (x + nx * 0.011, y + ny * 0.011, lip + 0.002)
        if k == 8:
            return (x + nx * 0.011, y + ny * 0.011, lip - 0.030)
        if k == 9:
            return (x + nx * 0.004, y + ny * 0.004, ZB_OUT + 0.010)
        if k == 10:
            return (x - nx * 0.001, y - ny * 0.001, ZB_OUT)
        return (x * 0.55, y * 0.55, ZB_OUT)

    ids = [[Bu.add(rp(ths[i], k)) for k in range(12)] for i in range(cols)]

    def plan_uv(ids4):
        out = []
        for i in ids4:
            x, y, z = Bu.v[i]
            out.append(((y / S) / (2 * SHELL_B) + 0.5, (x / S) / (2 * SHELL_A) + 0.5))
        return out

    wallv = [0.0] * 8
    for i in range(cols):
        j = (i + 1) % cols
        prof = [Bu.v[ids[i][k]] for k in range(3, 11)]
        cum = [0.0]
        for k in range(7):
            cum.append(cum[-1] + math.dist(prof[k], prof[k + 1]))
        tot = cum[-1] or 1.0
        wv = [c / tot for c in cum]
        wallv = [a + b for a, b in zip(wallv, wv)]
        u0 = (2.0 * shell_u(ths[i])) % 1.0
        u1 = (2.0 * shell_u(ths[j])) % 1.0
        if u1 <= u0:
            u1 = 1.0
        for k in range(11):
            a, b, c, d = ids[i][k], ids[i][k + 1], ids[j][k + 1], ids[j][k]
            if k <= 2:
                Bu.face([a, b, c, d], "shellin", plan_uv([a, b, c, d]))
            elif k <= 9:
                Bu.face([a, b, c, d], "shellwall",
                        [(u0, wv[k - 3]), (u1, wv[k - 3]), (u1, wv[k - 2]), (u0, wv[k - 2])])
            else:
                Bu.face([a, b, c, d], "shellout", plan_uv([a, b, c, d]))
    cin = Bu.add((0.0, 0.0, ZB_IN))
    cout = Bu.add((0.0, 0.0, ZB_OUT))
    for i in range(cols):
        j = (i + 1) % cols
        for (k, lane, cid) in ((0, "shellin", cin), (10, "shellout", cout)):
            uva, uvb = plan_uv([ids[i][k], ids[j][k]])
            dx, dy = uvb[0] - uva[0], uvb[1] - uva[1]
            L = math.hypot(dx, dy) or 1.0
            mid = ((uva[0] + uvb[0]) / 2.0 - dy / L * 0.004, (uva[1] + uvb[1]) / 2.0 + dx / L * 0.004)
            Bu.face([ids[i][k], cid, ids[j][k]], lane, [uva, mid, uvb])
    return [v / cols for v in wallv]


def build_holes(Bu):
    """Drain holes: a real moulded rim ring + a recessed dark disc (painted too, see features.json)."""
    for r, ys in enumerate(((-0.68, -0.24, 0.26, 0.70), (-0.46, 0.00, 0.50, 0.94))):
        for y in ys:
            if abs(y) > SHELL_B - 0.16:
                continue
            for x in (-0.085, 0.085):
                segs = 8
                ro, ri, dep = 0.0175, 0.0128, 0.0044
                out, inn = [], []
                for jj in range(segs):
                    a = 2 * math.pi * jj / segs
                    out.append(Bu.add((x + ro * math.cos(a), y + ro * math.sin(a), ZB_IN + 0.0006)))
                    inn.append(Bu.add((x + ri * math.cos(a), y + ri * math.sin(a), ZB_IN - dep)))
                cid = Bu.add((x, y, ZB_IN - dep * 1.35))
                for jj in range(segs):
                    kk = (jj + 1) % segs
                    us = [jj / float(segs), (jj + 1) / float(segs)]
                    Bu.face([out[jj], out[kk], inn[kk], inn[jj]], "plastic",
                            [(us[0], 0.10), (us[1], 0.10), (us[1], 0.45), (us[0], 0.45)])
                    Bu.face([inn[jj], inn[kk], cid], "plastic",
                            [(us[0], 0.55), (us[1], 0.55), ((us[0] + us[1]) / 2, 0.95)])
                for lane in ("shellin", "shellout"):
                    FEATURES.append({"kind": "hole", "lane": lane, "u": 0.5 + y / (2 * SHELL_B),
                                     "v": 0.5 + x / (2 * SHELL_A), "r": ro})


def build_foot_plate(Bu):
    """Foot plate across the foot end, bolted to the tub walls."""
    y = FOOT_Y
    w = x_at_y(y, SHELL_A, SHELL_B) - 0.012
    rect = FIT["plate"]
    z0, z1 = ZB_IN + 0.004, lip_z(y) - 0.034
    uv = [(rect[0], rect[2]), (rect[0] + 0.5 * (rect[1] - rect[0]), rect[2]),
          (rect[0] + 0.5 * (rect[1] - rect[0]), rect[3]), (rect[0], rect[3])]
    front = [Bu.add(p) for p in ((w, y, z0), (w, y + 0.010, z0), (w, y + 0.010, z1), (w, y, z1))]
    Bu.face(front, "fittings", uv)
    back = [Bu.add(p) for p in ((-w, y + 0.010, z0), (-w, y, z0), (-w, y, z1), (-w, y + 0.010, z1))]
    Bu.face(back, "fittings", uv)
    top = [front[3], front[2], Bu.add((-w, y + 0.010, z1)), Bu.add((-w, y, z1))]
    Bu.face(top, "fittings", [(rect[0], rect[3]), (rect[0] + 0.5 * (rect[1] - rect[0]), rect[3]),
                              (rect[0] + 0.5 * (rect[1] - rect[0]), rect[3] - 0.06), (rect[0], rect[3] - 0.06)])
    foot = [front[0], Bu.add((-w, y, z0)), back[1], front[1]]
    Bu.face(foot, "fittings", [(rect[0], rect[2]), (rect[0] + 0.5 * (rect[1] - rect[0]), rect[2]),
                              (rect[0] + 0.5 * (rect[1] - rect[0]), rect[2] + 0.06), (rect[0], rect[2] + 0.06)])
    for x in (-w * 0.58, w * 0.58):
        cyl(Bu, (x, y - 0.004, (z0 + z1) / 2), (0, -1, 0), 0.0055, 0.008, "fittings", FIT["bolt"], segs=6)
    FEATURES.append({"kind": "plate", "lane": "fittings", "u": rect[0] + 0.25 * (rect[1] - rect[0]),
                     "v": (rect[2] + rect[3]) / 2, "su": 0.5 * (rect[1] - rect[0]), "sv": (rect[3] - rect[2]) / 2})


def eyes():
    out = []
    for y, tag in ((-SLING_Y, "F"), (SLING_Y, "R")):
        for sx, side in ((1, "L"), (-1, "R")):
            x = sx * x_at_y(y)
            out.append(("%s%s" % (tag, side), (x, y, rim_z(y)), sx))
    return out


def build_eyes(Bu):
    for tag, c, sx in eyes():
        th = th_at_y(c[1]) * sx
        nx, ny = onrm(th)
        axis = (ny, -nx, 0.0)
        centre = (c[0] + nx * 0.045, c[1] + ny * 0.045, c[2] - 0.030)
        torus(Bu, centre, axis, RING_R, RING_r, 8, 5, "fittings", FIT["ring"] if sx > 0 else FIT["ringb"])
        FEATURES.append({"kind": "weld", "lane": "rim", "u": rim_u(th), "v": 0.72, "ru": 0.016, "rv": 0.30,
                         "style": "eye"})


def build_straps(Bu):
    for si, y in enumerate(STRAP_Y):
        xr = x_at_y(y)
        zr = rim_z(y)
        n = 6
        pts = []
        for k in range(n + 1):
            s = k / n
            x = xr * math.cos(math.pi * (1 - s))
            z = zr + 0.001 + (0.013 if si % 2 == 0 else 0.010) * math.sin(math.pi * s)
            pts.append((x, y, z))
        base = si / float(len(STRAP_Y))
        ribbon(Bu, pts, STRAP_W, STRAP_T, "webbing", lambda k, b=base: b + k / float(n) / len(STRAP_Y))
        bk = 0.62
        bx = xr * math.cos(math.pi * (1 - bk))
        bz = zr + 0.001 + 0.0115 * math.sin(math.pi * bk)
        box(Bu, (bx, y, bz + 0.001), (0.042, 0.056, 0.006), "fittings", FIT["buckle"])
        box(Bu, (bx - 0.011, y, bz + 0.008), (0.018, 0.050, 0.011), "fittings", FIT["tab"])
        for sx in (-1, 1):
            box(Bu, (sx * (xr - 0.008), y, zr + 0.011), (0.022, 0.030, 0.006), "fittings", FIT["tab"])
        FEATURES.append({"kind": "strap", "lane": "webbing", "u": base, "w": 1.0 / len(STRAP_Y),
                         "buckle": base + bk / len(STRAP_Y)})


def build_painted_holes():
    for lane in ("shellin", "shellout"):
        for y, x in ((-0.94, 0.0), (1.12, 0.0), (-0.10, 0.155), (-0.10, -0.155)):
            if abs(y) > SHELL_B - 0.16:
                continue
            FEATURES.append({"kind": "hole", "lane": lane, "u": 0.5 + y / (2 * SHELL_B), "v": 0.5 + x / (2 * SHELL_A),
                             "r": 0.0165})


def build_wall_holes():
    """Drain holes in the tub walls, painted at the wall lane's u (mirrored per lap) and profile v."""
    for th in (-2.05, -1.30, 1.30, 2.05):
        FEATURES.append({"kind": "hole", "lane": "shellwall", "u": (2.0 * shell_u(th)) % 1.0, "v": 0.30,
                         "r": 0.030})


def material():
    mat = bpy.data.materials.new(MI)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.70, 0.20, 0.03, 1.0)
    b.inputs["Roughness"].default_value = 0.45
    b.inputs["Metallic"].default_value = 0.0
    return mat


def empty(name, p):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.08
    e.location = (p[0] * S, p[1] * S, p[2] * S)
    bpy.context.scene.collection.objects.link(e)
    return e


def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def build():
    clear()
    Bu = Buf()
    build_rim(Bu)
    build_frame(Bu)
    wallv = build_shell(Bu)
    build_holes(Bu)
    build_painted_holes()
    build_wall_holes()
    build_foot_plate(Bu)
    build_eyes(Bu)
    build_straps(Bu)
    lod0 = Bu.to_object(NAME + "_LOD0", material())
    atts = [empty("ATT_Lift_%s" % tag, c) for tag, c, sx in eyes()]
    atts.append(empty("ATT_Casualty", (0.0, -0.15, ZB_IN + 0.02)))
    rib_len = 2.0 * (x_at_y(RIB_Y[0]) - 0.008)
    run_len = 2.0 * RUN_Y + 0.10
    strap_len = math.pi * x_at_y(STRAP_Y[0]) * 0.5 * 2.0 + 0.05
    world = {"rim": (3.0 * RAIL_LEN, 3.0 * 2 * math.pi * 0.015),
             "ribs": (3.0 * NRIB * rib_len, 3.0 * 2 * math.pi * RIB_R),
             "runners": (3.0 * 2 * run_len, 3.0 * 2 * math.pi * RUN_R),
             "shellwall": (3.0 * 2 * SHELL_LEN, 3.0 * (ZB_IN + 0.036 + 0.27 - ZB_OUT)),
             "webbing": (3.0 * len(STRAP_Y) * strap_len, 3.0 * 2 * (STRAP_W + STRAP_T)),
             "fittings": (20.0, 2.0),
             "shellin": dims.LANE_WORLD["shellin"], "shellout": dims.LANE_WORLD["shellout"],
             "plastic": dims.LANE_WORLD["plastic"]}
    with open(os.path.join(HERE, "features.json"), "w", encoding="utf-8") as f:
        wv4 = [wallv[2], wallv[3], wallv[4], wallv[6]]
        json.dump({"features": FEATURES, "world": {k: list(v) for k, v in world.items()}, "wall_v": wv4}, f, indent=1)
    maketex.build(common.textures_dir(NAME))
    tris = sum(len(p.vertices) - 2 for p in lod0.data.polygons)
    lo = [min(v.co[i] for v in lod0.data.vertices) / S for i in range(3)]
    hi = [max(v.co[i] for v in lod0.data.vertices) / S for i in range(3)]
    print("[%s] tris %d, bbox m %.3f x %.3f x %.3f, wall_v %s" % (NAME, tris, hi[0] - lo[0], hi[1] - lo[1],
                                                                  hi[2] - lo[2], [round(v, 3) for v in wv4]))
    return {
        "name": NAME, "budget": "small_prop", "tris": 3000, "tier": "standard",
        "dims_m": (0.61, 2.13, 0.20), "origin": "base",
        "sets": [{"name": "StretcherBasket", "set": "Kit", "size": 1024, "wet": True,
                  "dir": common.textures_dir(NAME)}],
        "meshes": [{"object": lod0, "set": "Kit"}],
        "attachments": atts,
        "waivers": {"LOD UV layout": "the tub, the tube frame, the webbing and the rings are separate surfaces; "
                                    "collapse merges the thin tube walls and the strap faces, so the LODs keep the same "
                                    "lanes and textures but lose UV area (39%); they sample the same atlas"},
        "closeups": [
            {"name": "headend", "target": [0.0, -2.6, 0.5], "dist": 5.0, "az": 205.0, "el": 20.0},
            {"name": "strap_buckle", "target": [0.4, -0.10, 0.55], "dist": 4.0, "az": 305.0, "el": 28.0},
            {"name": "lift_eye", "target": [0.85, -2.72, 0.56], "dist": 3.2, "az": 250.0, "el": 16.0},
            {"name": "skid", "target": [0.5, 1.5, 0.12], "dist": 4.0, "az": 25.0, "el": 10.0},
        ],
    }
