"""Procedural M_Kit_StretcherBasket benchmark asset.

The basket is deliberately one visual MeshPart: an orange HDPE shell carries a
welded dark frame, straps, buckles, lifting rings, and drain details.  The
texture atlas keeps the authored object within the one-set/small-prop rules.
"""
import math
import os
import struct
import zlib

import bpy
from mathutils import Vector

import sys
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, os.path.join(REPO, "tools/blender"))
import common  # noqa: E402


ASSET = "M_Kit_StretcherBasket"
REGIONS = {
    "orange": (0.00, 0.50, 0.50, 1.00),
    "black": (0.50, 0.50, 1.00, 1.00),
    "metal": (0.00, 0.00, 0.50, 0.50),
    "yellow": (0.50, 0.00, 1.00, 0.50),
}


def _png(path, kind, size=1024):
    """Write a small deterministic atlas without depending on Pillow in Blender."""
    raw = bytearray()
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            q = (0 if x < size // 2 and y < size // 2 else
                 1 if x >= size // 2 and y < size // 2 else
                 2 if x < size // 2 else 3)
            n = ((x * 17 + y * 31) % 9) - 4
            if kind == "ALB":
                colors = ((238, 67, 18), (18, 22, 24), (107, 119, 121), (245, 166, 16))
                c = colors[q]
                row.extend(max(0, min(255, v + (n if q in (0, 2) else n // 2))) for v in c)
            elif kind == "NOR":
                row.extend((128 + (n if q == 2 else 0), 128, 255))
            elif kind == "MET":
                row.extend((220 if q == 2 else 18, ) * 3)
            else:  # roughness, including the wet variant
                base = (62, 78, 42, 48)[q]
                row.extend((max(0, min(255, base + n)),) * 3)
            row.append(255)
        raw.extend(row)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    payload = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(payload)


def _textures():
    directory = common.textures_dir(ASSET)
    os.makedirs(directory, exist_ok=True)
    names = ["ALB", "NOR", "RGH", "MET", "ALB_Wet", "RGH_Wet"]
    for kind in names:
        path = os.path.join(directory, "T_StretcherBasket_Kit_%s.png" % kind)
        if not os.path.isfile(path):
            _png(path, kind.replace("_Wet", ""))
    return directory


class MeshBuilder:
    def __init__(self):
        self.v = []
        self.f = []
        self.regions = []

    def face(self, indices, region):
        self.f.append(tuple(indices))
        self.regions.append(region)

    def box(self, center, size, region):
        cx, cy, cz = center
        sx, sy, sz = (v / 2.0 for v in size)
        p = [(cx - sx, cy - sy, cz - sz), (cx + sx, cy - sy, cz - sz),
             (cx + sx, cy + sy, cz - sz), (cx - sx, cy + sy, cz - sz),
             (cx - sx, cy - sy, cz + sz), (cx + sx, cy - sy, cz + sz),
             (cx + sx, cy + sy, cz + sz), (cx - sx, cy + sy, cz + sz)]
        i = len(self.v)
        self.v.extend(p)
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                  (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.face([i + n for n in q], region)

    def prism(self, outline, z0, z1, region):
        i = len(self.v)
        self.v.extend([(x, y, z0) for x, y in outline] + [(x, y, z1) for x, y in outline])
        n = len(outline)
        self.face([i + j for j in reversed(range(n))], region)
        self.face([i + n + j for j in range(n)], region)
        for j in range(n):
            k = (j + 1) % n
            self.face([i + j, i + k, i + n + k, i + n + j], region)

    def cylinder(self, center, radius, depth, region, sides=10):
        cx, cy, cz = center
        i = len(self.v)
        for z in (cz - depth / 2.0, cz + depth / 2.0):
            self.v.extend((cx + radius * math.cos(2 * math.pi * j / sides),
                           cy + radius * math.sin(2 * math.pi * j / sides), z) for j in range(sides))
        self.face([i + j for j in reversed(range(sides))], region)
        self.face([i + sides + j for j in range(sides)], region)
        for j in range(sides):
            k = (j + 1) % sides
            self.face([i + j, i + k, i + sides + k, i + sides + j], region)

    def tube(self, points, radius, region, sides=8, closed=False):
        points = [Vector(p) for p in points]
        start = len(self.v)
        count = len(points)
        for i, p in enumerate(points):
            if closed:
                tangent = (points[(i + 1) % count] - points[(i - 1) % count]).normalized()
            elif i == 0:
                tangent = (points[1] - points[0]).normalized()
            elif i == count - 1:
                tangent = (points[-1] - points[-2]).normalized()
            else:
                tangent = (points[i + 1] - points[i - 1]).normalized()
            ref = Vector((0, 0, 1))
            if abs(tangent.dot(ref)) > 0.92:
                ref = Vector((1, 0, 0))
            a = tangent.cross(ref).normalized()
            b = tangent.cross(a).normalized()
            for j in range(sides):
                ang = 2 * math.pi * j / sides
                self.v.append(tuple(p + radius * (a * math.cos(ang) + b * math.sin(ang))))
        last = count if closed else count - 1
        for i in range(last):
            ni = (i + 1) % count
            for j in range(sides):
                k = (j + 1) % sides
                self.face([start + i * sides + j, start + ni * sides + j,
                           start + ni * sides + k, start + i * sides + k], region)
        if not closed:
            self.face([start + j for j in reversed(range(sides))], region)
            self.face([start + (count - 1) * sides + j for j in range(sides)], region)

    def torus_y(self, center, major, minor, region, u_steps=12, v_steps=6):
        cx, cy, cz = center
        start = len(self.v)
        for u in range(u_steps):
            a = 2 * math.pi * u / u_steps
            for v in range(v_steps):
                b = 2 * math.pi * v / v_steps
                rr = major + minor * math.cos(b)
                self.v.append((cx + rr * math.cos(a), cy + minor * math.sin(b), cz + rr * math.sin(a)))
        for u in range(u_steps):
            for v in range(v_steps):
                self.face([start + u * v_steps + v,
                           start + ((u + 1) % u_steps) * v_steps + v,
                           start + ((u + 1) % u_steps) * v_steps + (v + 1) % v_steps,
                           start + u * v_steps + (v + 1) % v_steps], region)

    def finish(self, name, material=None):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(self.v, [], self.f)
        mesh.update()
        uv = mesh.uv_layers.new(name="UVMap")
        for poly, region in zip(mesh.polygons, self.regions):
            u0, v0, u1, v1 = REGIONS[region]
            n = max(1, len(poly.loop_indices) - 1)
            for j, li in enumerate(poly.loop_indices):
                t = j / float(n)
                uv.data[li].uv = (u0 + 0.045 + 0.91 * (t if j % 2 else 0.0),
                                  v0 + 0.045 + 0.91 * (1.0 if j % 2 else 0.0))
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        if material:
            mesh.materials.append(material)
        return obj


def _material(texture_dir):
    mat = bpy.data.materials.new("MAT_StretcherBasket")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    uv = nodes.new("ShaderNodeUVMap")
    uv.uv_map = "UVMap"
    links.new(bsdf.outputs[0], out.inputs[0])
    for kind, input_name in (("ALB", "Base Color"), ("RGH", "Roughness"), ("MET", "Metallic")):
        image = bpy.data.images.load(os.path.join(texture_dir, "T_StretcherBasket_Kit_%s.png" % kind), check_existing=True)
        image.colorspace_settings.name = "sRGB" if kind == "ALB" else "Non-Color"
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        links.new(uv.outputs["UV"], tex.inputs["Vector"])
        links.new(tex.outputs["Color"], bsdf.inputs[input_name])
    image = bpy.data.images.load(os.path.join(texture_dir, "T_StretcherBasket_Kit_NOR.png"), check_existing=True)
    image.colorspace_settings.name = "Non-Color"
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    normal = nodes.new("ShaderNodeNormalMap")
    links.new(uv.outputs["UV"], tex.inputs["Vector"])
    links.new(tex.outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.52
    return mat


def _capsule(half_width, straight, end_steps=7):
    points = []
    for i in range(end_steps + 1):
        a = math.pi + math.pi * i / end_steps
        points.append((half_width * math.cos(a), -straight + half_width * math.sin(a)))
    for i in range(end_steps + 1):
        a = math.pi * i / end_steps
        points.append((half_width * math.cos(a), straight + half_width * math.sin(a)))
    return points


def _build_visual(material):
    b = MeshBuilder()
    # 1.83 x 6.39 x 0.60 stud overall silhouette, base on Z=0.
    b.prism(_capsule(0.76, 2.38), 0.035, 0.185, "orange")
    # Deep side flanges and a raised head board make the shell read as a basket.
    b.box((-0.755, 0.0, 0.315), (0.115, 5.45, 0.29), "orange")
    b.box((0.755, 0.0, 0.315), (0.115, 5.45, 0.29), "orange")
    b.box((0.0, -2.70, 0.335), (1.48, 0.18, 0.31), "orange")
    b.box((0.0, 2.73, 0.315), (1.48, 0.13, 0.27), "orange")

    rim = [(x, y, 0.548) for x, y in _capsule(0.835, 2.355)]
    b.tube(rim, 0.052, "metal", sides=8, closed=True)
    # Center split sleeves and the four short cross braces underneath.
    for y in (-0.065, 0.065):
        b.box((-0.755, y, 0.205), (0.16, 0.16, 0.16), "metal")
        b.box((0.755, y, 0.205), (0.16, 0.16, 0.16), "metal")
        b.cylinder((-0.755, y, 0.29), 0.035, 0.035, "yellow", sides=8)
        b.cylinder((0.755, y, 0.29), 0.035, 0.035, "yellow", sides=8)
    for x in (-0.47, 0.47):
        b.box((x, 0.0, 0.075), (0.105, 5.55, 0.105), "metal")
    for y in (-2.10, -1.05, 0.0, 1.05, 2.10):
        b.box((0.0, y, 0.13), (1.34, 0.085, 0.10), "metal")

    # Five patient straps with bright keeper tabs and contrasting buckles.
    for y in (-2.05, -1.03, 0.0, 1.03, 2.05):
        b.box((0.0, y, 0.215), (1.48, 0.10, 0.028), "black")
        b.box((0.22, y, 0.245), (0.19, 0.13, 0.055), "metal")
        b.box((-0.59, y, 0.244), (0.12, 0.13, 0.048), "yellow")

    # Foot plate and a small orange raised head cushion/pad.
    b.box((0.0, 2.82, 0.405), (1.28, 0.07, 0.30), "metal")
    b.box((0.0, -2.42, 0.255), (1.28, 0.42, 0.12), "orange")

    # Drain holes are recessed black cylinders, spaced down the centreline.
    for y in (-2.25, -1.50, -0.75, 0.0, 0.75, 1.50, 2.25):
        b.cylinder((0.0, y, 0.192), 0.055, 0.018, "black", sides=12)

    # Four grab handles sit just outside the side rails.
    for side in (-1, 1):
        for y in (-1.45, 1.45):
            x = side * 0.84
            b.tube([(x, y - 0.23, 0.48), (side * 0.965, y - 0.23, 0.48),
                    (side * 0.965, y + 0.23, 0.48), (x, y + 0.23, 0.48)],
                   0.027, "black", sides=7, closed=False)

    # Stainless lifting eyes at the four corners, oriented in the XZ plane.
    for x in (-0.72, 0.72):
        for y in (-2.91, 2.91):
            b.box((x, y, 0.48), (0.16, 0.045, 0.09), "metal")
            b.torus_y((x, y, 0.49), 0.062, 0.016, "metal")

    return b.finish(ASSET + "_LOD0", material)


def _collision():
    b = MeshBuilder()
    b.box((0.0, 0.0, 0.27), (1.70, 6.20, 0.54), "metal")
    return b.finish(ASSET + "_COL")


def _empty(name, location, parent=None):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = "PLAIN_AXES"
    ob.location = location
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        ob.parent = parent
    return ob


def build():
    texture_dir = _textures()
    material = _material(texture_dir)
    visual = _build_visual(material)
    col = _collision()
    atts = []
    for name, x, y in (("ATT_Lift_FL", -0.72, -2.91), ("ATT_Lift_FR", 0.72, -2.91),
                       ("ATT_Lift_RL", -0.72, 2.91), ("ATT_Lift_RR", 0.72, 2.91)):
        atts.append(_empty(name, (x, y, 0.49), visual))
    atts.append(_empty("ATT_Casualty", (0.0, 0.0, 0.24), visual))
    return {
        "name": ASSET,
        "budget": "small_prop",
        "tris": 3000,
        "tier": "standard",
        "dims_m": (0.61, 2.13, 0.20),
        "origin": "base",
        "sets": [{"name": "StretcherBasket", "set": "Kit", "size": 1024, "wet": True, "dir": texture_dir}],
        "meshes": [{"object": visual, "set": "Kit"}, {"object": col}],
        "attachments": atts,
        "lod_symmetry": "X",
        "closeups": [
            {"name": "strap_buckle", "target": [0.22, 0.0, 0.26], "dist": 2.2, "az": 42, "el": 28},
            {"name": "lifting_eye", "target": [0.72, -2.91, 0.49], "dist": 1.7, "az": 38, "el": 26},
            {"name": "drains", "target": [0.0, 0.0, 0.19], "dist": 2.4, "az": 15, "el": 62},
        ],
    }
