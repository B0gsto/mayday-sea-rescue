"""Shared geometry helpers for M_Veh_RIB and M_Veh_RIB_Helm (1 Blender unit = 1 stud, 3 studs per metre).

Axes (pipeline): X beam (port +X, starboard -X), Y length (bow -Y, stern +Y), Z up. Base of the skegs at z 0.
Every part is built twice from the same generators: lo (LOD0, one material, UVs) and hi (_HP, named materials for
the bake: base colour / roughness / metalness per slot, more segments, bevels, non-slip relief).
"""
import math

import bmesh
import bpy
from mathutils import Vector, Matrix, noise

# --------------------------------------------------------------------------- layout constants (studs)
K = 0.45            # keel bottom (skegs reach z 0)
DECK = 2.1          # deck surface (greybox deck y 0 -> z 2.1)
TR = 0.825          # tube radius (0.55 m tube)
TX = 3.45           # tube centre half-beam on the straight
TZ = 2.475          # tube centre height on the straight
BOW_Y0 = -6.0       # straight tube ends here; bow arc runs to the stem
BOW_Y1 = -12.2      # tube centreline at the stem
BOW_RISE = 0.45     # tube sheer rise at the stem
STERN_Y = 11.3      # tube cone starts
TRANSOM_Y = 10.9


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(srgb_to_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


PALETTE = {
    # name: (sRGB hex, roughness, metal)
    "HullCharcoal": ("#2B2F33", 0.42, 0.0),
    "HullOrange": ("#FF6600", 0.38, 0.0),
    "BootStripe": ("#FF6600", 0.40, 0.0),
    "TubeGrey": ("#5C6166", 0.62, 0.0),
    "TubeWear": ("#4D5256", 0.70, 0.0),
    "Reflective": ("#B8BDC0", 0.30, 0.0),
    "RubStrake": ("#303336", 0.78, 0.0),
    "Webbing": ("#2F3842", 0.85, 0.0),
    "NonSlip": ("#61676B", 0.88, 0.0),
    "Gelcoat": ("#A4A9AB", 0.42, 0.0),
    "GelcoatWhite": ("#D9DBD7", 0.40, 0.0),
    "Acrylic": ("#23292D", 0.06, 0.0),
    "Stainless": ("#C9CCCD", 0.22, 1.0),
    "Aluminium": ("#BDC1C3", 0.40, 1.0),
    "BlackPlastic": ("#2A2C2E", 0.55, 0.0),
    "Rubber": ("#2D2F31", 0.80, 0.0),
    "LensRed": ("#B3262A", 0.10, 0.0),
    "LensGreen": ("#1F8A4C", 0.10, 0.0),
    "LensWhite": ("#D6D8D6", 0.10, 0.0),
    "LensBlue": ("#2D5BC4", 0.10, 0.0),
    "CowlGrey": ("#3B3F43", 0.32, 0.0),
    "CowlLight": ("#B9BDBE", 0.36, 0.0),
    "Antifoul": ("#34383B", 0.70, 0.0),
    "Screen": ("#1C2830", 0.08, 0.0),
    "ScreenChart": ("#3E5866", 0.10, 0.0),
    "Vinyl": ("#2C2F33", 0.58, 0.0),
    "PodGrey": ("#6B7074", 0.45, 0.0),
    "PanelOrange": ("#FF6600", 0.45, 0.0),
    "LetterWhite": ("#E6E7E3", 0.45, 0.0),
    "CrestCharcoal": ("#2B2F33", 0.45, 0.0),
    "Dial": ("#E2E3DF", 0.20, 0.0),
}


def material(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    hexc, rough, metal = PALETTE.get(name, ("#808080", 0.5, 0.0))
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*hexcol(hexc), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    return mat


# --------------------------------------------------------------------------- tube centreline
def tube_frame(y):
    """Tube centre (x half-beam, z) and radius at a station y (port side)."""
    if y >= BOW_Y0:
        return TX, TZ, TR
    s = min(1.0, (BOW_Y0 - y) / (BOW_Y0 - BOW_Y1))
    t = math.asin(s)
    return TX * math.cos(t), TZ + BOW_RISE * s ** 1.6, TR - 0.05 * s


def tube_path(lo):
    """Port stern -> bow -> starboard stern: list of (Vector, radius)."""
    n_arc = 22 if lo else 36
    side = []
    cone = [(12.12, 0.18), (12.02, 0.42), (11.82, 0.64), (11.58, 0.77)]
    if not lo:
        cone = [(12.16, 0.10), (12.1, 0.3), (12.0, 0.48), (11.85, 0.63), (11.68, 0.74), (11.5, 0.8)]
    for y, r in cone:
        side.append((Vector((TX, y, TZ)), r))
    ys = [STERN_Y] + [9.75 - 1.5 * i for i in range(11)] + [BOW_Y0]
    for y in ys:
        side.append((Vector((TX, y, TZ)), TR))
    for i in range(1, n_arc):
        t = (math.pi / 2) * i / n_arc
        s = math.sin(t)
        x = TX * math.cos(t)
        y = BOW_Y0 + (BOW_Y1 - BOW_Y0) * s
        side.append((Vector((x, y, TZ + BOW_RISE * s ** 1.6)), TR - 0.05 * s))
    centre = (Vector((0.0, BOW_Y1, TZ + BOW_RISE)), TR - 0.05)
    mirrored = [(Vector((-p.x, p.y, p.z)), r) for p, r in reversed(side)]
    return side + [centre] + mirrored


def frames(points):
    """Tangent, side (inward for this U path) and up per path point."""
    out = []
    n = len(points)
    for i in range(n):
        a = points[max(0, i - 1)]
        b = points[min(n - 1, i + 1)]
        t = (b - a).normalized()
        side = t.cross(Vector((0, 0, 1)))
        if side.length < 1e-6:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(t).normalized()
        out.append((t, side, up))
    return out


# --------------------------------------------------------------------------- mesh accumulator
class Geo:
    def __init__(self, hi):
        self.hi = hi
        self.bm = bmesh.new()
        self.mats = []

    def bevel_sharp(self, faces, offset, angle=25, segments=None):
        """Round the sharp edges of a just-built component (chamfer on LOD0, 3 segments on _HP)."""
        if offset <= 0 or not faces:
            return
        fs = set(faces)
        edges = {e for f in faces for e in f.edges
                 if len(e.link_faces) == 2 and all(lf in fs for lf in e.link_faces)
                 and e.calc_face_angle(0.0) > math.radians(angle)}
        if not edges:
            return
        seg = segments or (3 if self.hi else 1)
        try:
            bmesh.ops.bevel(self.bm, geom=list(edges) + list({v for e in edges for v in e.verts}), offset=offset,
                            segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        except Exception as exc:  # keep building; a failed bevel only loses the rounding
            print("[ribgeo] bevel skipped:", exc)

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, vs, mat):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = self.mi(mat)
        return f

    def rings(self, rings, mat, closed=True, cap0=False, cap1=False, matfn=None, recalc=True):
        vs = [[self.bm.verts.new(p) for p in r] for r in rings]
        n = len(rings[0])
        faces = []
        for i in range(len(vs) - 1):
            for j in range(n if closed else n - 1):
                k = (j + 1) % n
                m = matfn(i, j) if matfn else mat
                f = self.face((vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]), m)
                if f:
                    faces.append(f)
        if cap0:
            faces += self.cap(vs[0], mat)
        if cap1:
            faces += self.cap(vs[-1], mat)
        if recalc and faces:
            bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        return faces

    def cap(self, ring, mat):
        c = sum((v.co for v in ring), Vector()) / len(ring)
        cv = self.bm.verts.new(c)
        out = []
        for j in range(len(ring)):
            f = self.face((ring[j], ring[(j + 1) % len(ring)], cv), mat)
            if f:
                out.append(f)
        return out

    def orient(self, faces, fn):
        """Flip faces whose normal points against fn(face centre)."""
        for f in faces:
            f.normal_update()
            if f.normal.dot(fn(f.calc_center_median())) < 0:
                f.normal_flip()

    def add_mesh(self, me, mat, mapfn):
        vs = [self.bm.verts.new(mapfn(v.co)) for v in me.vertices]
        out = []
        for p in me.polygons:
            f = self.face([vs[i] for i in p.vertices], mat)
            if f:
                out.append(f)
        return out

    def to_object(self, name, collection=None, single_mat=None, smooth_angle=40):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        (collection or bpy.context.scene.collection).objects.link(obj)
        if single_mat:
            me.materials.append(material(single_mat) if isinstance(single_mat, str) else single_mat)
            for p in me.polygons:
                p.material_index = 0
        else:
            for m in self.mats:
                me.materials.append(material(m))
        me.shade_smooth()
        if smooth_angle:
            me.set_sharp_from_angle(angle=math.radians(smooth_angle))
        return obj


# --------------------------------------------------------------------------- primitives
def circle_profile(r, seg, phase=0.0):
    return [(r * math.cos(phase + 2 * math.pi * j / seg), r * math.sin(phase + 2 * math.pi * j / seg)) for j in range(seg)]


def sweep(g, pts, profile, mat, closed=True, radii=None, cap0=False, cap1=False, matfn=None, recalc=True):
    """Sweep a 2-D profile (side, up) along a path; radii scales the profile per point."""
    fr = frames(pts)
    rings = []
    for i, p in enumerate(pts):
        t, side, up = fr[i]
        s = radii[i] if radii else 1.0
        rings.append([p + side * (a * s) + up * (b * s) for a, b in profile])
    return g.rings(rings, mat, closed=closed, cap0=cap0, cap1=cap1, matfn=matfn, recalc=recalc)


def rounded_path(corners, radius, seg):
    """Polyline with filleted corners."""
    out = [corners[0]]
    for i in range(1, len(corners) - 1):
        a, b, c = corners[i - 1], corners[i], corners[i + 1]
        da, dc = (a - b).normalized(), (c - b).normalized()
        r = min(radius, (a - b).length * 0.45, (c - b).length * 0.45)
        p0, p1 = b + da * r, b + dc * r
        for k in range(seg + 1):
            t = k / seg
            out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * b + t ** 2 * p1)
    out.append(corners[-1])
    return out


def tube(g, corners, r, mat, seg, fillet=0.3, fseg=4, caps=True):
    pts = rounded_path([Vector(c) for c in corners], fillet, fseg) if len(corners) > 2 else [Vector(c) for c in corners]
    return sweep(g, pts, circle_profile(r, seg), mat, cap0=caps, cap1=caps)


def box(g, centre, size, mat, rot=None, bev=None):
    cx, cy, cz = centre
    sx, sy, sz = (s / 2 for s in size)
    m = rot or Matrix.Identity(3)
    c = Vector(centre)
    v = [g.bm.verts.new(c + m @ Vector((x * sx, y * sy, z * sz))) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    faces = [g.face([v[i] for i in q], mat) for q in quads]
    faces = [f for f in faces if f]
    bmesh.ops.recalc_face_normals(g.bm, faces=faces)
    if bev is None:
        bev = 0.18 * min(size)
    g.bevel_sharp(faces, min(bev, 0.04))
    return faces


def lathe(g, axis_origin, axis, profile, seg, mat, matfn=None):
    """profile: list of (radius, height along axis); radius 0 ends are collapsed to a point ring."""
    axis = Vector(axis).normalized()
    ref = Vector((1, 0, 0)) if abs(axis.x) < 0.9 else Vector((0, 1, 0))
    u = axis.cross(ref).normalized()
    w = axis.cross(u).normalized()
    o = Vector(axis_origin)
    rings = []
    for r, h in profile:
        r = max(r, 1e-4)
        rings.append([o + axis * h + (u * math.cos(2 * math.pi * j / seg) + w * math.sin(2 * math.pi * j / seg)) * r
                      for j in range(seg)])
    return g.rings(rings, mat, matfn=matfn)


def superellipse_ring(cx, cy, z, hx, hy, seg, p=3.0):
    pts = []
    for j in range(seg):
        t = 2 * math.pi * j / seg
        c, s = math.cos(t), math.sin(t)
        x = hx * math.copysign(abs(c) ** (2 / p), c)
        y = hy * math.copysign(abs(s) ** (2 / p), s)
        pts.append(Vector((cx + x, cy + y, z)))
    return pts


def loft(g, sections, seg, mat, cap0=True, cap1=True, p=3.0, matfn=None):
    """sections: (cx, cy, z, hx, hy) bottom to top (superellipse rings)."""
    rings = [superellipse_ring(cx, cy, z, max(hx, 1e-3), max(hy, 1e-3), seg, p) for cx, cy, z, hx, hy in sections]
    return g.rings(rings, mat, cap0=cap0, cap1=cap1, matfn=matfn)


def extrude_profile(g, profile_yz, x0, x1, mat, matfn=None, bev=0.0):
    """Prism: a convex YZ profile extruded from x0 to x1, side caps as fans."""
    rings = [[Vector((x, y, z)) for y, z in profile_yz] for x in (x0, x1)]
    faces = g.rings(rings, mat, cap0=True, cap1=True, matfn=matfn)
    g.bevel_sharp(faces, bev)
    return faces


def text_mesh(body, size, extrude=0.0, font_scale_x=1.0):
    cu = bpy.data.curves.new("TXT_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = extrude
    cu.space_character = 1.05
    ob = bpy.data.objects.new("TXT_" + body, cu)
    bpy.context.scene.collection.objects.link(ob)
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(deps))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    if font_scale_x != 1.0:
        for v in me.vertices:
            v.co.x *= font_scale_x
    return me


def apply_modifiers(obj):
    deps = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(obj.evaluated_get(deps))
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)
    me.name = obj.name


def bevel_hp(obj, width=0.03, segments=2, angle=35):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    mod.harden_normals = False
    apply_modifiers(obj)


def split_by_part(src, part_faces, names):
    """Split one UV-unwrapped object into one object per part (face index lists), keeping UVs."""
    out = []
    for name, idx in zip(names, part_faces):
        keep = set(idx)
        bm = bmesh.new()
        bm.from_mesh(src.data)
        bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.index not in keep]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in src.data.materials:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        out.append(ob)
    bpy.data.objects.remove(src)
    return out


def build_set(set_name, parts, unwrap, mat_name, angle=55, margin=0.004):
    """parts: [(object_name, geo_fn)] where geo_fn(g) adds lo geometry. Joins, unwraps (one packed UV layout per set),
    then splits back into one MeshPart object per part."""
    g = Geo(False)
    ranges = []
    for name, fn in parts:
        start = len(g.bm.faces)
        fn(g)
        g.bm.faces.ensure_lookup_table()
        ranges.append((start, len(g.bm.faces)))
    # keep the per-part face ranges through remove_doubles by tagging faces
    layer = g.bm.faces.layers.int.new("part")
    g.bm.faces.ensure_lookup_table()
    for pi, (a, b) in enumerate(ranges):
        for i in range(a, b):
            g.bm.faces[i][layer] = pi
    obj = g.to_object("TMP_" + set_name, single_mat=mat_name)
    unwrap(obj, angle=angle, margin=margin)
    obj.data.uv_layers[0].name = "UVMap"
    attr = obj.data.attributes["part"]
    idx = [[] for _ in parts]
    for i, d in enumerate(attr.data):
        idx[d.value].append(i)
    objs = split_by_part(obj, idx, [n for n, _ in parts])
    for o in objs:
        if "part" in o.data.attributes:
            o.data.attributes.remove(o.data.attributes["part"])
    return objs


def build_hp(name, fns, bevel=None):
    g = Geo(True)
    for fn in fns:
        fn(g)
    obj = g.to_object(name)
    if bevel:
        bevel_hp(obj, **bevel)
    return obj


def grit(p, scale=22.0, amp=0.006):
    return amp * noise.noise(p * scale)
