"""M_Kit_ChartTablet: 10-inch rugged tablet in a waterproof case (docs/12 2.8, kit hard set, 1,500 tris).

A chart plotter the coxswain carries and the station keeps on the console: a 0.270 x 0.180 x 0.020 m waterproof
case around a 10-inch glass. The case is one lofted solid: the rounded-rect plan is offset ring by ring from the
back centre out to the bumper's bulge and in again over the bezel to the recessed glass, so the shell, the TPE
overmould and the bezel are a single watertight surface.

Authoring: metres, front -Y, base at Z 0 (the case rests on the brim ring, the widest of the back), screen up
(+Z), the tablet's top edge at +Y. 1 Blender unit = 1 stud (common.STUDS_PER_METRE).

Moulded (not painted on): a raised battery / comms hatch with two stainless screws, a raised TPE grip pad, a
moulded brand plate, a rear camera collar with a recessed lens, a flush front camera, a volume rocker and power
button in the shell band above the bumper, a hinged rubber port flap on the top edge, and a lanyard anchor pad
with a stainless ring lying flush in it. Painted on top of that: the case's moulding grain and a working life on
the water (salt bloom round the bezel seam, abraded bumper corners, scuffs, dust in the recesses, thumb polish on
the buttons, fingerprints on the glass, worn dock contacts).

Split: the glass is its own MeshPart (M_Kit_ChartTablet_Screen_LOD0) so the game can put the chart SurfaceGui on
it and go Neon; the case carries everything else. One set, T_ChartTablet_Kit_* (dry + _Wet), 1024 px, painted
procedurally by maketex.py from layout.py, before validate looks for the maps.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "tools/blender"))
import common  # noqa: E402
import layout  # noqa: E402
import maketex  # noqa: E402
import versions  # noqa: E402

S = common.STUDS_PER_METRE
NAME = "M_Kit_ChartTablet"
MI = "MI_ChartTablet_Kit"

# lane-local sub-rects for the moulded details (painted by maketex.py to match)
SUB = {
    "rubber": {"seal": (0.03, 0.34, 0.73, 0.97), "btn": (0.40, 0.61, 0.73, 0.97), "btn2": (0.67, 0.88, 0.73, 0.97),
               "port": (0.40, 0.88, 0.45, 0.65), "gasket": (0.02, 0.98, 0.31, 0.41), "lanyard": (0.03, 0.34, 0.45, 0.65)},
    "metal": {"collar": (0.03, 0.30, 0.71, 0.97), "lens": (0.36, 0.58, 0.71, 0.97), "screw": (0.63, 0.88, 0.71, 0.97),
              "ring": (0.03, 0.30, 0.35, 0.63)},
}


def sub(lane, name, u, v):
    u0, u1, v0, v1 = SUB[lane][name]
    return layout.uv(lane, u0 + (u1 - u0) * u, v0 + (v1 - v0) * v)


# ---------------------------------------------------------------- plan loops and buffers
def loop(cx, cy, hw, hd, rc, n_long, n_corner):
    """Rounded-rect loop (x, y, nx, ny) counter-clockwise seen from +Z, from the +X edge."""
    out = []
    for i in range(n_long):
        out.append((cx + hw, cy + (-hd + rc) + 2 * (hd - rc) * i / n_long, 1.0, 0.0))
    for ax, ay, a0 in ((1, 1, 0.0), (-1, 1, 90.0), (-1, -1, 180.0), (1, -1, 270.0)):
        ccx, ccy = cx + ax * (hw - rc), cy + ay * (hd - rc)
        for i in range(n_corner):
            a = math.radians(a0 + 90.0 * i / n_corner)
            out.append((ccx + rc * math.cos(a), ccy + rc * math.sin(a), math.cos(a), math.sin(a)))
        if a0 == 0.0:
            for i in range(n_long):
                out.append((cx + (hw - rc) - 2 * (hw - rc) * i / n_long, cy + hd, 0.0, 1.0))
        elif a0 == 90.0:
            for i in range(n_long):
                out.append((cx - hw, cy + (hd - rc) - 2 * (hd - rc) * i / n_long, -1.0, 0.0))
        elif a0 == 180.0:
            for i in range(n_long):
                out.append((cx + (-hw + rc) + 2 * (hw - rc) * i / n_long, cy - hd, 0.0, -1.0))
    return out


def case_ring(t, z):
    """A ring of the case solid at plan inset t (layout.TZ): [(x, y, nx, ny, z)]."""
    return layout.ring(t, z)


def _basis(axis):
    ln = math.sqrt(sum(v * v for v in axis)) or 1.0
    ax = tuple(v / ln for v in axis)
    ref = (0.0, 0.0, 1.0) if abs(ax[2]) < 0.9 else (1.0, 0.0, 0.0)
    nx = (ax[1] * ref[2] - ax[2] * ref[1], ax[2] * ref[0] - ax[0] * ref[2], ax[0] * ref[1] - ax[1] * ref[0])
    l2 = math.sqrt(sum(v * v for v in nx)) or 1.0
    nx = tuple(v / l2 for v in nx)
    ny = (ax[1] * nx[2] - ax[2] * nx[1], ax[2] * nx[0] - ax[0] * nx[2], ax[0] * nx[1] - ax[1] * nx[0])
    return ax, nx, ny


class Buf:
    def __init__(self):
        self.v = []
        self.f = []

    def add(self, p):
        self.v.append((p[0] * S, p[1] * S, p[2] * S))
        return len(self.v) - 1

    def verts(self, pts):
        return [self.add(p) for p in pts]

    def face(self, ids, uvs, want=None):
        """Add a face; with `want` it is wound so its normal points along that direction."""
        if len(set(ids)) < 3:
            return
        if want is not None:
            a, b, c = (Vector(self.v[i]) for i in ids[:3])
            if (b - a).cross(c - a).dot(Vector(want)) < 0.0:
                ids = list(reversed(ids))
                uvs = list(reversed(uvs))
        self.f.append((tuple(ids), tuple(uvs)))

    def quad(self, p0, p1, p2, p3, uvs, want):
        self.face([self.add(p) for p in (p0, p1, p2, p3)], uvs, want)

    def to_object(self, obj_name, material):
        bm = bmesh.new()
        uvl = bm.loops.layers.uv.new(common.UV_NAME)
        bv = [bm.verts.new(p) for p in self.v]
        for idx, uvs in self.f:
            try:
                f = bm.faces.new([bv[i] for i in idx])
            except ValueError:
                continue
            for loop_, uv in zip(f.loops, uvs):
                loop_[uvl].uv = uv
        mesh = bpy.data.meshes.new(obj_name)
        bm.to_mesh(mesh)
        bm.free()
        for p in mesh.polygons:
            p.use_smooth = True
        try:
            mesh.set_sharp_from_angle(angle=math.radians(32.0))
        except Exception:
            pass
        mesh.materials.append(material)
        obj = bpy.data.objects.new(obj_name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        clean(obj)
        versions.weighted_normals(obj)
        return obj


def clean(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    uvl = bm.loops.layers.uv.active
    if uvl is not None:
        for f in bm.faces:
            for l in f.loops:
                l[uvl].uv = (min(max(l[uvl].uv.x, 0.0), 1.0), min(max(l[uvl].uv.y, 0.0), 1.0))
    bm.to_mesh(obj.data)
    bm.free()


# ---------------------------------------------------------------- primitives
def box(Bu, c, size, uvm):
    """Axis-aligned block, six faces each in its own sixth of the mapped sub-rect."""
    ax, ay, az = size[0] / 2.0, size[1] / 2.0, size[2] / 2.0
    corners = [(-ax, -ay, -az), (ax, -ay, -az), (ax, ay, -az), (-ax, ay, -az),
               (-ax, -ay, az), (ax, -ay, az), (ax, ay, az), (-ax, ay, az)]
    ids = [Bu.add((c[0] + x, c[1] + y, c[2] + z)) for x, y, z in corners]
    mid = Vector((c[0] * S, c[1] * S, c[2] * S))
    uv = []
    for k in range(6):
        u0, v0 = 0.03 + 0.32 * (k % 3), 0.03 + 0.49 * (k // 3)
        uv.append([uvm(u0, v0), uvm(u0 + 0.29, v0), uvm(u0 + 0.29, v0 + 0.45), uvm(u0, v0 + 0.45)])
    for f, fuv in zip(((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)), uv):
        fc = sum((Vector(Bu.v[ids[i]]) for i in f), Vector()) / 4.0
        Bu.face([ids[i] for i in f], fuv, fc - mid)
    return ids


def cyl(Bu, c, axis, r, h, uvm, segs=8, lens=True):
    """Collar / stud: side band along `axis` plus a top disc; u round, v up."""
    ax, nx, ny = _basis(axis)
    c = tuple(v * S for v in c)
    ring0, ring1 = [], []
    for j in range(segs):
        a = 2 * math.pi * j / segs
        d = tuple(nx[k] * math.cos(a) + ny[k] * math.sin(a) for k in range(3))
        ring0.append(Bu.add(tuple(c[k] / S + d[k] * r for k in range(3))))
        ring1.append(Bu.add(tuple((c[k] + ax[k] * h * S) / S + d[k] * r for k in range(3))))
    for j in range(segs):
        k = (j + 1) % segs
        u0, u1 = j / segs, (j + 1) / segs
        mid = Vector([(Bu.v[ring0[j]][m] + Bu.v[ring0[k]][m] + Bu.v[ring1[j]][m] + Bu.v[ring1[k]][m]) / 4.0 for m in range(3)])
        want = mid - Vector(c)
        Bu.face([ring0[j], ring0[k], ring1[k], ring1[j]],
                [uvm(u0, 0.0), uvm(u1, 0.0), uvm(u1, 0.74), uvm(u0, 0.74)], want)
    if lens:
        cid = Bu.add(tuple((c[k] + ax[k] * (h * S + r * S * 0.10)) / S for k in range(3)))
        Bu.face(ring1 + [cid], [uvm(j / segs, 0.80) for j in range(segs)] + [uvm(0.5, 1.0)], tuple(ax))
    return ring0, ring1


def torus(Bu, c, axis, R, r, uvm, nu=10, nv=3):
    ax, nx, ny = _basis(axis)
    cen = Vector(c) * S
    rings = []
    for i in range(nu):
        a = 2 * math.pi * i / nu
        d = tuple(nx[k] * math.cos(a) + ny[k] * math.sin(a) for k in range(3))
        ring = []
        for j in range(nv):
            b = 2 * math.pi * j / nv
            ring.append(Bu.add(tuple(c[m] + d[m] * (R + math.cos(b) * r) + ax[m] * (math.sin(b) * r) for m in range(3))))
        rings.append(ring)
    for i in range(nu):
        i1 = (i + 1) % nu
        for j in range(nv):
            j1 = (j + 1) % nv
            fc = (Vector(Bu.v[rings[i][j]]) + Vector(Bu.v[rings[i1][j]]) + Vector(Bu.v[rings[i1][j1]]) + Vector(Bu.v[rings[i][j1]])) / 4.0
            Bu.face([rings[i][j], rings[i1][j], rings[i1][j1], rings[i][j1]],
                    [uvm(i / nu, j / nv), uvm((i + 1) / nu, j / nv), uvm((i + 1) / nu, (j + 1) / nv), uvm(i / nu, (j + 1) / nv)],
                    fc - cen)


def plate(Bu, pts, z_of, lift, uv_of, want_z=-1.0):
    """Raised plate on the back: one ring on the surface and a fan to a slightly higher centre."""
    A = Bu.verts([(x, y, z_of(x, y) + lift) for x, y, _, _ in pts])
    c = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
    cid = Bu.add((c[0], c[1], z_of(c[0], c[1]) + lift + 0.0011))
    for j in range(len(pts)):
        k = (j + 1) % len(pts)
        Bu.face([A[j], A[k], cid], [uv_of(pts[j][0], pts[j][1]), uv_of(pts[k][0], pts[k][1]), uv_of(c[0], c[1])],
                (0.0, 0.0, want_z))


# ---------------------------------------------------------------- the case solid
def wall_and_caps(Bu):
    us = layout.COARSE_U + [1.0]
    ids, rings = [], []
    for t, z in layout.TZ:
        ring = case_ring(t, z)
        rings.append(ring)
        ids.append(Bu.verts([(x, y, z) for x, y, _, _, _ in ring]))
    for k in range(len(ids) - 1):
        A, B = rings[k], rings[k + 1]
        vA, vB = layout.TZ[k][1] / layout.TH, layout.TZ[k + 1][1] / layout.TH
        front = k >= 8                  # bands 8 to 10 are horizontal rings: they map in the bezel lane
        for j in range(len(A)):
            j1 = (j + 1) % len(A)
            if front:
                pts = (A[j], A[j1], B[j1], B[j])
                uva = [layout.uv("bezel", *layout.plan_uv("bezel", p[0], p[1])) for p in pts]
            else:
                uva = [(us[j], vA), (us[j + 1], vA), (us[j + 1], vB), (us[j], vB)]
            Bu.face([ids[k][j], ids[k][j1], ids[k + 1][j1], ids[k + 1][j]],
                    uva, ((A[j][2] + A[j1][2]) / 2.0, (A[j][3] + A[j1][3]) / 2.0, 0.0))
    # back cap: brim ring inward to two rings, then the centre fan (plan projected into the `back` lane)
    back = [ids[0]]
    for t, z in layout.BACK_RINGS:
        back.append(Bu.verts([(x, y, z) for x, y, _, _, _ in case_ring(t, z)]))
    for a_, b_ in zip(back[:-1], back[1:]):
        for j in range(len(back[0])):
            j1 = (j + 1) % len(back[0])
            uva = [layout.uv("back", *layout.plan_uv("back", Bu.v[i][0] / S, Bu.v[i][1] / S)) for i in (a_[j], a_[j1], b_[j1], b_[j])]
            Bu.face([a_[j], a_[j1], b_[j1], b_[j]], uva, (0.0, 0.0, -1.0))
    cid = Bu.add((0.0, 0.0, layout.BACK_RINGS[-1][1] + 0.0003))
    for j in range(len(back[-1])):
        j1 = (j + 1) % len(back[-1])
        uv = [layout.uv("back", *layout.plan_uv("back", Bu.v[i][0] / S, Bu.v[i][1] / S)) for i in (back[-1][j], back[-1][j1])]
        uv.append(layout.uv("back", *layout.plan_uv("back", 0.0, 0.0)))
        Bu.face([back[-1][j], back[-1][j1], cid], uv, (0.0, 0.0, -1.0))


def back_detail(Bu):
    zf = layout.back_z
    # grip pad: TPE sheet, raised, its own lane
    pts = loop(layout.PAD_C[0], layout.PAD_C[1], layout.PAD_SZ[0] / 2, layout.PAD_SZ[1] / 2, layout.PAD_R, 3, 3)
    plate(Bu, pts, zf, 0.0005, lambda x, y: layout.uv("grip", *layout.plan_uv("grip", x, y)))
    # brand plate
    pts = loop(layout.LABEL_C[0], layout.LABEL_C[1], layout.LABEL_SZ[0] / 2, layout.LABEL_SZ[1] / 2, layout.LABEL_R, 3, 3)
    plate(Bu, pts, zf, 0.0003,
          lambda x, y: layout.uv("label", 0.06 + 0.88 * layout.plan_uv("label", x, y)[0],
                                 0.10 + 0.80 * layout.plan_uv("label", x, y)[1]))
    # battery / comms hatch + two stainless screws
    hx, hy = layout.HATCH_C
    pts = loop(hx, hy, layout.HATCH_SZ[0] / 2, layout.HATCH_SZ[1] / 2, layout.HATCH_R, 4, 3)
    plate(Bu, pts, zf, 0.0002, lambda x, y: layout.uv("back", *layout.plan_uv("back", x, y)))
    for sx, sy in layout.SCREW_C:
        cyl(Bu, (sx, sy, zf(sx, sy) + 0.0009), (0.0, 0.0, -1.0), layout.SCREW_R, 0.0010,
            lambda u, v: sub("metal", "screw", u, v), segs=8)
    # rear camera: collar with a recessed lens
    bx, by = layout.CAM_BACK
    z0 = zf(bx, by)
    cyl(Bu, (bx, by, z0 + 0.0002), (0.0, 0.0, -1.0), layout.CAM_BACK_R, 0.0012,
        lambda u, v: sub("metal", "collar", u, v), segs=10, lens=False)
    cyl(Bu, (bx, by, z0 - 0.0001), (0.0, 0.0, -1.0), layout.CAM_BACK_R * 0.60, 0.0001,
        lambda u, v: sub("metal", "lens", u, v), segs=8)
    # lanyard anchor: a moulded pad with a stainless ring lying flush in it
    lx, ly = layout.LANYARD_C
    pts = loop(lx, ly, layout.LANYARD_R, layout.LANYARD_R * 0.72, layout.LANYARD_R * 0.5, 3, 3)
    plate(Bu, pts, zf, 0.0004,
          lambda x, y: sub("rubber", "lanyard", 0.5 + (x - lx) / (2 * layout.LANYARD_R), 0.5 + (y - ly) / (1.44 * layout.LANYARD_R)))
    torus(Bu, (lx, ly, zf(lx, ly) + 0.0026), (0.0, 0.0, 1.0), layout.LANYARD_R * 0.55, 0.0013,
          lambda u, v: sub("metal", "ring", u, v), nu=10, nv=3)


def front_detail(Bu):
    # front camera, flush in the top bezel: a moulded collar with a recessed lens
    fx, fy = layout.CAM_FRONT
    cyl(Bu, (fx, fy, 0.0193), (0.0, 0.0, 1.0), layout.CAM_FRONT_R, 0.0007,
        lambda u, v: sub("metal", "collar", u, v), segs=8, lens=False)
    ring = []
    r = layout.CAM_FRONT_R * 0.62
    for j in range(8):
        a = 2 * math.pi * j / 8
        ring.append(Bu.add((fx + r * math.cos(a), fy + r * math.sin(a), 0.0199)))
    cid = Bu.add((fx, fy, 0.0199))
    Bu.face(ring + [cid], [sub("metal", "lens", 0.5 + 0.5 * math.cos(2 * math.pi * j / 8), 0.5 + 0.5 * math.sin(2 * math.pi * j / 8))
                         for j in range(8)] + [sub("metal", "lens", 0.5, 0.5)], (0.0, 0.0, 1.0))


def edge_detail(Bu):
    """Volume rocker and power button in the shell band above the bumper, and the hinged port flap."""
    z0, z1 = layout.BTN_Z
    for i, y0 in enumerate((layout.VOL_Y[0], layout.VOL_Y[0] + 0.0095)):
        y1 = y0 + 0.0080
        c = (layout.W / 2 - 0.0008 + layout.BTN_OUT / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
        box(Bu, c, (layout.BTN_OUT, y1 - y0, z1 - z0), lambda u, v: sub("rubber", "btn" if i == 0 else "btn2", u, v))
    x0, x1 = layout.PWR_X
    c = ((x0 + x1) / 2.0, layout.D / 2 - 0.0008 + layout.BTN_OUT / 2.0, (z0 + z1) / 2.0)
    box(Bu, c, (x1 - x0, layout.BTN_OUT, z1 - z0), lambda u, v: sub("rubber", "btn", u, v))
    px0, px1 = layout.PORT_X
    c = ((px0 + px1) / 2.0, layout.D / 2 - 0.0010 + 0.0011, 0.0128)
    box(Bu, c, (px1 - px0, 0.0022, 0.0046), lambda u, v: sub("rubber", "port", u, v))
    box(Bu, ((px0 + px1) / 2.0, layout.D / 2 - 0.0012, 0.0157), (px1 - px0, 0.0018, 0.0010),
        lambda u, v: sub("rubber", "seal", u, v))


def build_screen():
    """The glass: its own MeshPart so the game can surface a chart UI on it and go Neon."""
    Bu = Buf()
    us = layout.COARSE_U + [1.0]
    t = layout.GLASS_T
    ring = case_ring(t, layout.GLASS_Z)
    ids = Bu.verts([(x, y, z) for x, y, _, _, z in ring])
    bead = Bu.verts([(x, y, layout.GLASS_Z - 0.0007) for x, y, _, _, z in ring])
    for j in range(len(ring)):
        j1 = (j + 1) % len(ring)
        Bu.face([bead[j], bead[j1], ids[j1], ids[j]],
                [sub("rubber", "gasket", us[j], 0.0), sub("rubber", "gasket", us[j + 1], 0.0),
                 sub("rubber", "gasket", us[j + 1], 1.0), sub("rubber", "gasket", us[j], 1.0)],
                (-ring[j][2], -ring[j][3], 0.0))
    cid = Bu.add((0.0, 0.0, layout.GLASS_Z))
    for j in range(len(ring)):
        j1 = (j + 1) % len(ring)
        Bu.face([ids[j], ids[j1], cid],
                [layout.uv("screen", *layout.plan_uv("screen", ring[j][0], ring[j][1])),
                 layout.uv("screen", *layout.plan_uv("screen", ring[j1][0], ring[j1][1])),
                 layout.uv("screen", *layout.plan_uv("screen", 0.0, 0.0))], (0.0, 0.0, 1.0))
    return Bu


def material():
    mat = bpy.data.materials.new(MI)
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.10, 0.11, 0.12, 1.0)
    b.inputs["Roughness"].default_value = 0.42
    b.inputs["Metallic"].default_value = 0.0
    return mat


def empty(name, p):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.06
    e.location = (p[0] * S, p[1] * S, p[2] * S)
    bpy.context.scene.collection.objects.link(e)
    return e


def clear():
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(NAME) or o.name.startswith("ATT_"):
            bpy.data.objects.remove(o, do_unlink=True)


def build():
    clear()
    case = Buf()
    wall_and_caps(case)
    back_detail(case)
    front_detail(case)
    edge_detail(case)
    lod0 = case.to_object(NAME + "_LOD0", material())
    screen = build_screen().to_object(NAME + "_Screen_LOD0", material())

    atts = [
        empty("ATT_Grip", (0.0, 0.0, 0.0100)),
        empty("ATT_Screen", (0.0, 0.0, layout.GLASS_Z + 0.0012)),
        empty("ATT_Mount", (0.0, 0.0, 0.0018)),
        empty("ATT_Lanyard", (layout.LANYARD_C[0], layout.LANYARD_C[1], layout.back_z(*layout.LANYARD_C) + 0.0013)),
        empty("ATT_Port", ((layout.PORT_X[0] + layout.PORT_X[1]) / 2.0, layout.D / 2 + 0.0001, 0.0128)),
    ]

    maketex.build(common.textures_dir(NAME))
    total = 0
    for o in (lod0, screen):
        n = sum(len(p.vertices) - 2 for p in o.data.polygons)
        total += n
        print("[%s] %-40s %5d tris  %d faces" % (NAME, o.name, n, len(o.data.polygons)))
    lo = [min(v.co[i] for o in (lod0, screen) for v in o.data.vertices) / S for i in range(3)]
    hi = [max(v.co[i] for o in (lod0, screen) for v in o.data.vertices) / S for i in range(3)]
    print("[%s] total %d tris, bbox m %.4f x %.4f x %.4f" % (NAME, total, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]))

    return {
        "name": NAME, "budget": "small_prop", "tris": 1500, "tier": "hero",
        "dims_m": (round(hi[0] - lo[0], 3), round(hi[1] - lo[1], 3), round(hi[2] - lo[2], 3)),
        "size_note": None, "origin": "base",
        "sets": [{"name": "ChartTablet", "set": "Kit", "size": layout.SIZE, "wet": True,
                  "dir": common.textures_dir(NAME)}],
        "meshes": [{"object": lod0, "set": "Kit"}, {"object": screen, "set": "Kit"}],
        "attachments": atts,
        "waivers": {"LOD UV layout": "collapse decimation of the moulded details and the glass fan shifts UV area; "
                                    "both LODs sample the same lanes and textures (no atlas move)"},
        "tiling": False, "lod_symmetry": None,
        "closeups": [
            {"name": "screen_bezel", "target": [layout.CAM_FRONT[0] * S, layout.CAM_FRONT[1] * S, 0.059], "dist": 1.8,
             "az": 196.0, "el": 34.0},
            {"name": "bezel_low", "target": [0.0, layout.D / 2 * S, 0.048], "dist": 2.0, "az": 330.0, "el": 11.0},
            {"name": "ports", "target": [(layout.PORT_X[0] + layout.PORT_X[1]) / 2.0 * S, layout.D / 2 * S, 0.040],
             "dist": 1.5, "az": 168.0, "el": 13.0},
            {"name": "corner", "target": [layout.W / 2 * S, layout.D / 2 * S, 0.030], "dist": 1.3, "az": 48.0, "el": 12.0},
            {"name": "back_low", "target": [layout.HATCH_C[0] * S, (layout.HATCH_C[1] + layout.LABEL_C[1]) / 2.0 * S, 0.006],
             "dist": 2.6, "az": 300.0, "el": 4.0},
        ],
    }
