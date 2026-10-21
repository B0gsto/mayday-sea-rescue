"""M_Kit_StretcherBasket: rescue basket stretcher (Ferno/Stokes style) for the modelling benchmark."""
import math
import os
import sys
import random

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../../"))
sys.path.insert(0, os.path.join(G, "tools/blender"))
import common
import names

ASSET = "M_Kit_StretcherBasket"
STUDS = common.STUDS_PER_METRE
TEX_NAME = "StretcherBasket"
TEX_SET = "Kit"
TEX_SIZE = 1024

# Dimensions in metres (Blender axes: X width, Y length front=-Y, Z up)
L, W, H = 2.13, 0.61, 0.20
RIM_R = 0.022
BED_Z = 0.045
SHELL_T = 0.012


def m2s(v):
    """Metres to studs."""
    if isinstance(v, (tuple, list)):
        return tuple(x * STUDS for x in v)
    return v * STUDS


def clear_scene():
    """Remove any existing mesh objects from previous runs."""
    for o in list(bpy.context.scene.objects):
        if o.type in ('MESH', 'EMPTY'):
            bpy.data.objects.remove(o, do_unlink=True)


def new_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def add_uv_layer(obj, name=common.UV_NAME):
    me = obj.data
    me.uv_layers.new(name=name)
    return me.uv_layers[name]


def smart_unwrap(obj):
    """Smart UV project into 0..1."""
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')


def apply_smooth(obj, angle=40.0):
    obj.data.use_auto_smooth = True
    obj.data.auto_smooth_angle = math.radians(angle)


def create_material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.65
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def tube_along(bm, pts, r, segs=8, caps=True):
    """Add a tube along a polyline to a bmesh, return vertex indices for caps if needed."""
    P = [Vector(p) for p in pts]
    if len(P) < 2:
        return
    cum = [0.0]
    for a, b in zip(P[:-1], P[1:]):
        cum.append(cum[-1] + (b - a).length)
    L = cum[-1]
    # resample to even steps for smoother tube
    n = max(len(P) - 1, 2)
    step = L / n
    Q = []
    for i in range(n + 1):
        s = step * i
        j = min(max(int(np.searchsorted(cum, s, side='right')) - 1, 0), len(P) - 2)
        t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
        Q.append(P[j].lerp(P[j + 1], t))
    # frame
    T = []
    for i in range(len(Q)):
        a, b = Q[max(0, i - 1)], Q[min(len(Q) - 1, i + 1)]
        T.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = T[0].cross(ref).normalized()
    rings = []
    for i, p in enumerate(Q):
        if i:
            nrm = (nrm - T[i] * nrm.dot(T[i])).normalized()
        bn = T[i].cross(nrm)
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            ring.append(p + nrm * (r * math.cos(a)) + bn * (r * math.sin(a)))
        rings.append(ring)
    base = len(bm.verts)
    for ring in rings:
        for v in ring:
            bm.verts.new(v)
    bm.verts.ensure_lookup_table()
    for i in range(len(rings) - 1):
        for j in range(segs):
            j1 = (j + 1) % segs
            bm.faces.new((bm.verts[base + i * segs + j],
                          bm.verts[base + (i + 1) * segs + j],
                          bm.verts[base + (i + 1) * segs + j1],
                          bm.verts[base + i * segs + j1]))
    if caps:
        # start cap
        cap = [bm.verts[base + j] for j in range(segs)]
        bm.faces.new(tuple(reversed(cap)))
        # end cap
        cap = [bm.verts[base + (len(rings) - 1) * segs + j] for j in range(segs)]
        bm.faces.new(cap)


def ring_points(cx, cy, z, rx, ry, segs):
    pts = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a), z))
    return pts


def create_rim(bm):
    """Top tubular rim: rounded rectangle in XY plane at height H, tube radius RIM_R."""
    segs = 24
    rx, ry = W / 2 - RIM_R, L / 2 - RIM_R
    z = H - RIM_R
    pts = ring_points(0, 0, z, rx, ry, segs)
    # close loop
    pts.append(pts[0])
    tube_along(bm, [m2s(p) for p in pts], m2s(RIM_R), segs=12, caps=False)

    # lifting rings at 4 corners (torus hanging outside)
    corners = [(-rx, -ry), (rx, -ry), (-rx, ry), (rx, ry)]
    for x, y in corners:
        # ring loop in YZ plane hanging out
        cx, cy, cz = x, y + math.copysign(RIM_R * 1.2, y), z - RIM_R * 0.5
        pts = []
        for i in range(17):
            a = -math.pi / 2 + math.pi * i / 16
            pts.append((cx, cy + 0.04 * math.sin(a), cz + 0.04 * math.cos(a)))
        tube_along(bm, [m2s(p) for p in pts], m2s(0.008), segs=8, caps=False)

    # grab handles along the long sides
    for sx in (-1, 1):
        x = sx * (W / 2 - RIM_R)
        pts = [(x, -L / 3, z), (x + sx * 0.04, -L / 6, z + 0.02),
               (x + sx * 0.04, L / 6, z + 0.02), (x, L / 3, z)]
        tube_along(bm, [m2s(p) for p in pts], m2s(0.012), segs=8, caps=True)


def create_bed(bm):
    """Plastic bed shell with drain holes."""
    rng = random.Random(7)
    nx, ny = 14, 40
    x0, x1 = -W / 2 + SHELL_T, W / 2 - SHELL_T
    y0, y1 = -L / 2 + SHELL_T, L / 2 - SHELL_T

    # head end raised slightly and split join at middle
    def bed_z(y):
        if y < -L / 2 + 0.35:
            return BED_Z + 0.025 * (1 - abs(y + L / 2 - 0.175) / 0.175)
        return BED_Z

    verts = []
    holes = []
    for j in range(ny + 1):
        y = y0 + (y1 - y0) * j / ny
        z = bed_z(y)
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            # slight dish
            dish = 0.005 * (1 - (2 * x / W) ** 2)
            verts.append(Vector(m2s((x, y, z - dish))))
            # drain holes in a grid, skip edges and split join
            mid_y = abs(y) < 0.08
            edge = i == 0 or i == nx or j == 0 or j == ny
            if not edge and not mid_y and (i % 3 == 1) and (j % 4 == 2):
                holes.append((len(verts) - 1, x, y, z - dish))

    def idx(i, j):
        return j * (nx + 1) + i

    faces = []
    hole_verts = set()
    for j in range(ny):
        for i in range(nx):
            v0 = idx(i, j)
            v1 = idx(i + 1, j)
            v2 = idx(i + 1, j + 1)
            v3 = idx(i, j + 1)
            # skip faces containing a drain hole centre
            skip = False
            for hv, hx, hy, hz in holes:
                if hv in (v0, v1, v2, v3):
                    skip = True
                    break
            if not skip:
                faces.append((v0, v1, v2, v3))
            else:
                # create a small ring around the hole instead
                hole_verts.add((i, j))

    bv = [bm.verts.new(v) for v in verts]
    bm.verts.ensure_lookup_table()
    for f in faces:
        try:
            bm.faces.new((bv[f[0]], bv[f[1]], bv[f[2]], bv[f[3]]))
        except ValueError:
            pass

    # simple drain hole rings: omit the central quad leaving a dark spot
    for i, j in hole_verts:
        cx = x0 + (x1 - x0) * (i + 0.5) / nx
        cy = y0 + (y1 - y0) * (j + 0.5) / ny
        z = bed_z(cy) - 0.005 * (1 - (2 * cx / W) ** 2)
        # create a small raised ring
        rr = 0.018
        ring = []
        for k in range(8):
            a = 2 * math.pi * k / 8
            ring.append(bm.verts.new(m2s((cx + rr * math.cos(a), cy + rr * math.sin(a), z + 0.003))))
        centre = bm.verts.new(m2s((cx, cy, z - 0.002)))
        for k in range(8):
            k1 = (k + 1) % 8
            bm.faces.new((ring[k], ring[k1], centre))


def create_frame(bm):
    """Cross ribs and longitudinal runners under the bed."""
    # 3 cross ribs
    for y in (-L / 3, 0.0, L / 3):
        pts = [(-W / 2 + 0.03, y, BED_Z - 0.03), (0, y, BED_Z - 0.045), (W / 2 - 0.03, y, BED_Z - 0.03)]
        tube_along(bm, [m2s(p) for p in pts], m2s(0.012), segs=8, caps=True)
    # 2 longitudinal runners
    for x in (-W / 3, W / 3):
        pts = [(x, -L / 2 + 0.06, BED_Z - 0.05), (x, 0, BED_Z - 0.055), (x, L / 2 - 0.06, BED_Z - 0.05)]
        tube_along(bm, [m2s(p) for p in pts], m2s(0.015), segs=8, caps=True)


def create_split_join(bm):
    """Bolting sleeves at the centre of the rim."""
    z = H - RIM_R
    for sx in (-1, 1):
        x = sx * (W / 2 - RIM_R)
        # sleeve tube across the split
        M = Matrix.Translation(m2s((x, 0, z))) @ Matrix.Rotation(math.radians(90), 4, 'X')
        pts = []
        for i in range(9):
            a = -math.pi / 2 + math.pi * i / 8
            pts.append((0.045 * math.cos(a), 0.0, 0.045 * math.sin(a)))
        local_pts = [tuple(M @ Vector(p)) for p in pts]
        tube_along(bm, local_pts, m2s(0.008), segs=8, caps=False)
        # bolt head
        bolt = bm.verts.new(m2s((x * 1.15, 0, z)))
        # not a real bolt, just a small protrusion via an ngon around it


def create_straps(bm):
    """Webbing straps across the bed with buckles."""
    strap_w = 0.035
    positions = [-L / 2 + 0.25, -L / 4, 0.0, L / 4, L / 2 - 0.25]
    for y in positions:
        # strap flat across the bed
        x0, x1 = -W / 2 + 0.04, W / 2 - 0.04
        z = BED_Z + 0.003
        v0 = bm.verts.new(m2s((x0, y - strap_w / 2, z)))
        v1 = bm.verts.new(m2s((x1, y - strap_w / 2, z)))
        v2 = bm.verts.new(m2s((x1, y + strap_w / 2, z)))
        v3 = bm.verts.new(m2s((x0, y + strap_w / 2, z)))
        bm.faces.new((v0, v1, v2, v3))
        # buckle at one side
        bx = x1 + 0.02
        pts = [(bx, y - 0.015, z + 0.005), (bx + 0.02, y - 0.015, z + 0.012),
               (bx + 0.02, y + 0.015, z + 0.012), (bx, y + 0.015, z + 0.005)]
        tube_along(bm, [m2s(p) for p in pts + [pts[0]]], m2s(0.004), segs=6, caps=False)


def create_footplate(bm):
    """Foot plate at the head (-Y) end."""
    x0, x1 = -W / 2 + 0.05, W / 2 - 0.05
    y = -L / 2 + 0.04
    z0 = BED_Z + 0.01
    z1 = z0 + 0.045
    v = []
    for p in [(x0, y, z0), (x1, y, z0), (x1, y + 0.04, z1), (x0, y + 0.04, z1)]:
        v.append(bm.verts.new(m2s(p)))
    bm.faces.new((v[0], v[1], v[2], v[3]))


def build_lod0():
    bm = bmesh.new()
    create_rim(bm)
    create_bed(bm)
    create_frame(bm)
    create_split_join(bm)
    create_straps(bm)
    create_footplate(bm)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    obj = new_object(ASSET + "_LOD0", bm)
    smart_unwrap(obj)
    apply_smooth(obj, 35.0)
    return obj


def build_col():
    bm = bmesh.new()
    x, y, z = m2s(W / 2), m2s(L / 2), m2s(H)
    vs = [bm.verts.new((sx * x, sy * y, sz * z)) for sz in (0, 1) for sy in (-1, 1) for sx in (-1, 1)]
    faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    obj = new_object(ASSET + "_COL", bm)
    return obj


def save_png(name, arr, directory):
    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, name + ".png")
    img = bpy.data.images.new(name, width=TEX_SIZE, height=TEX_SIZE, alpha=(arr.shape[2] == 4))
    # flatten RGBA
    img.pixels = list(arr.ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    return path


def write_textures():
    directory = os.path.join(common.out_root(), "textures", ASSET)
    os.makedirs(directory, exist_ok=True)
    rng = np.random.default_rng(42)
    size = TEX_SIZE

    def make(kind, wet=False):
        h, w = size, size
        if kind == "ALB":
            # orange HDPE with straps and wear
            base = np.array([0.92, 0.42, 0.08], dtype=np.float32)
            if wet:
                base *= 0.75
            noise = rng.uniform(-0.04, 0.04, (h, w, 3))
            img = np.clip(base + noise, 0.0, 1.0)
            # strap bands (darker)
            for yc in [h // 5 * i for i in range(1, 5)]:
                img[max(0, yc - 20):min(h, yc + 20), :, :] *= 0.85
            # scuff patches
            for _ in range(30):
                cx, cy = rng.integers(0, w), rng.integers(0, h)
                r = rng.integers(10, 40)
                yy, xx = np.ogrid[:h, :w]
                mask = (xx - cx) ** 2 + (yy - cy) ** 2 < r ** 2
                img[mask] *= rng.uniform(0.7, 0.95)
            alpha = np.ones((h, w, 1), dtype=np.float32)
            img = np.concatenate([img, alpha], axis=2)
        elif kind == "NOR":
            # OpenGL normal: neutral blue + noise
            img = np.ones((h, w, 4), dtype=np.float32) * np.array([0.5, 0.5, 1.0, 1.0])
            n = rng.uniform(-0.04, 0.04, (h, w, 3))
            img[:, :, :3] = np.clip(img[:, :, :3] + n, 0.0, 1.0)
        elif kind == "RGH":
            v = 0.70 if not wet else 0.35
            img = np.full((h, w), v, dtype=np.float32)
            img += rng.uniform(-0.08, 0.08, (h, w))
            img = np.clip(img, 0.0, 1.0)
            img = np.stack([img, img, img, np.ones_like(img)], axis=2)
        elif kind == "MET":
            v = 0.05
            img = np.full((h, w), v, dtype=np.float32)
            img = np.stack([img, img, img, np.ones_like(img)], axis=2)
        return img

    for kind in common.MAP_KINDS:
        save_png(names.texture_stem(TEX_NAME, TEX_SET, kind), make(kind), directory)
        if kind in ("ALB", "RGH"):
            save_png(names.texture_stem(TEX_NAME, TEX_SET, kind, wet=True), make(kind, wet=True), directory)


def attachments():
    objs = []
    # lifting rings at corners
    rx, ry = W / 2 - RIM_R, L / 2 - RIM_R
    for name, x, y in [("ATT_Lift_FL", -rx, -ry), ("ATT_Lift_FR", rx, -ry),
                       ("ATT_Lift_RL", -rx, ry), ("ATT_Lift_RR", rx, ry)]:
        e = bpy.data.objects.new(name, None)
        e.location = m2s((x, y, H - RIM_R))
        bpy.context.scene.collection.objects.link(e)
        objs.append(e)
    # casualty centre of bed
    e = bpy.data.objects.new("ATT_Casualty", None)
    e.location = m2s((0, 0, BED_Z + 0.05))
    bpy.context.scene.collection.objects.link(e)
    objs.append(e)
    return objs


def build():
    clear_scene()
    mat = create_material("MI_StretcherBasket_Kit", (0.92, 0.42, 0.08))
    lod0 = build_lod0()
    lod0.data.materials.append(mat)
    col = build_col()
    atts = attachments()
    write_textures()

    # Ensure scene units
    us = bpy.context.scene.unit_settings
    us.system = 'NONE'
    us.scale_length = 1.0

    return {
        "name": ASSET,
        "budget": "small_prop",
        "tris": 3000,
        "tier": "standard",
        "dims_m": (W, L, H),
        "origin": "base",
        "sets": [{"name": TEX_NAME, "set": TEX_SET, "size": TEX_SIZE, "wet": True,
                  "dir": os.path.join(common.out_root(), "textures", ASSET)}],
        "meshes": [{"object": lod0, "set": TEX_SET},
                   {"object": col}],
        "attachments": atts,
        "tiling": False,
        "lod_symmetry": None,
        "waivers": {},
    }


if __name__ == "__main__":
    spec = build()
    print(spec)
