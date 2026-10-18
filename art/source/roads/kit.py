"""R1a street furniture kit (Blender): geometry + trim-region UVs on the shared Street atlas (street_layout.py).

Every builder works in metres (Blender X right, -Y front, Z up, origin on the ground at the post / centre) and converts
to studs at the end. Each asset returns {part: object} for its LOD0 MeshParts plus a _COL proxy and ATT_* empties;
art/source/roads/<Asset>/build.py wraps it in the run.py spec. Real sizes: art/reference/<Asset>/dims.md.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import street_layout as SL  # noqa: E402

S = 3.0  # studs per metre
LOD = 0  # set by spec(): hand-made LOD1 / LOD2 share the LOD0 UV mapping (fewer segments, no small details)
Q = {0: 1.0, 1: 0.5, 2: 0.3}


def seg(n, mn=6):
    return max(mn, int(round(n * Q[LOD])))


def bev(b):
    return b if LOD == 0 else 0.0
GAME = os.path.abspath(os.path.join(HERE, "../../.."))
TEX = os.path.join(GAME, "assets/textures")


# ---------------------------------------------------------------------------------------------------- primitives
def lathe(profile, segs, flutes=None, cap_bottom=False, cap_top=False, z_cuts=()):
    """bmesh of a surface of revolution; profile [(r, z)] bottom to top; flutes(theta, z) -> radius multiplier."""
    bm = bmesh.new()
    prof = list(profile)
    # extra rings at the requested z cuts (keeps tile lines on ring edges)
    for zc in z_cuts:
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 < zc < z1:
                t = (zc - z0) / (z1 - z0)
                prof.insert(prof.index((r1, z1)), (r0 + (r1 - r0) * t, zc))
                break
    rings = []
    for r, z in prof:
        ring = []
        for i in range(segs):
            th = 2 * math.pi * i / segs
            k = flutes(th, z) if flutes else 1.0
            ring.append(bm.verts.new((r * k * math.cos(th), r * k * math.sin(th), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(size, center, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(center)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5)
    return bm


def sweep(path, section, closed_path=False, up=Vector((0, 0, 1))):
    """Tube along path [(x, y, z)] with a closed section [(a, b)] in the path's (side, normal) frame."""
    bm = bmesh.new()
    P = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(P):
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(t).normalized()
        rings.append([bm.verts.new(p + side * a + nrm * b) for a, b in section])
    n = len(section)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def rounded_rect(w, h, r, k=2):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        if k == 0:
            a = math.radians(a0 + 45)
            pts.append((cx + r * math.sqrt(2) * math.cos(a), cy + r * math.sqrt(2) * math.sin(a)))
            continue
        for i in range(k + 1):
            a = math.radians(a0 + 90 * i / k)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def circle(r, n):
    return [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def arc(c, r, a0, a1, n, plane="xz"):
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        if plane == "xz":
            out.append((c[0] + r * math.cos(a), c[1], c[2] + r * math.sin(a)))
        else:  # yz
            out.append((c[0], c[1] + r * math.cos(a), c[2] + r * math.sin(a)))
    return out


def transform(bm, mat):
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    return bm


def cut_z(bm, step, z0=0.0, z1=10.0):
    z = z0 + step
    while z < z1:
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
        z += step
    return bm


# ---------------------------------------------------------------------------------------------------- UVs
def _wrap_angles(angs):
    if max(angs) - min(angs) > math.pi:
        angs = [a + 2 * math.pi if a < 0 else a for a in angs]
    return angs


def _off(vals, t):
    """Tile offset for a face: the tile holding its centre, nudged so a small face straddling a tile line stays whole."""
    o = math.floor((sum(vals) / len(vals)) / t) * t
    lo, hi = min(vals), max(vals)
    if hi - lo <= t:
        if lo < o:
            o = lo
        elif hi > o + t:
            o = hi - t
    return o


def uv_piece(bm, asset, region, mode="box", center=(0.0, 0.0), axis="z"):
    """UVs every face of bm into the region. mode: box | cyl (tiled), fitcyl | fitplane (whole piece)."""
    uvl = bm.loops.layers.uv.verify()
    alt = "paint" if "paint" in SL.REGIONS[asset] else "iron"
    if SL.REGIONS[asset][region][1] == "fit":
        xs = [v.co for v in bm.verts]
        mn = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
        mx = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
    for f in bm.faces:
        cos = [l.vert.co for l in f.loops]
        n = f.normal
        reg = region
        if SL.REGIONS[asset][region][1] == "absz" and sum(c.z for c in cos) / len(cos) > SL.REGIONS[asset][region][3][1] * 0.97:
            reg = alt     # above the splash band: plain paint
        rect, kind, _mat, par = SL.REGIONS[asset][reg]
        u0, v0, u1, v1 = SL.region_rect(asset, reg)
        if mode in ("cyl", "fitcyl"):
            angs = _wrap_angles([math.atan2(c.y - center[1], c.x - center[0]) for c in cos])
            rad = sum(math.hypot(c.x - center[0], c.y - center[1]) for c in cos) / len(cos)
            if abs(n.z) > 0.8 and mode == "cyl":   # caps: planar
                ab = [(c.x, c.y) for c in cos]
            elif mode == "cyl":
                ab = [(a * max(rad, 0.02), c.z) for a, c in zip(angs, cos)]
            else:
                ab = [((a % (2 * math.pi)) / (2 * math.pi) if i == 0 else a / (2 * math.pi), c.z) for i, (a, c) in enumerate(zip(angs, cos))]
                base = math.floor(min(a for a in angs) / (2 * math.pi))
                ab = [(a / (2 * math.pi) - base, c.z) for a, c in zip(angs, cos)]
        else:
            ax = max(range(3), key=lambda i: abs(n[i]))
            if axis != "z" and mode == "fitplane":
                ax = "xyz".index(axis)
            if ax == 0:
                ab = [(c.y * (1 if n.x > 0 else -1), c.z) for c in cos]
            elif ax == 1:
                ab = [(c.x * (-1 if n.y > 0 else 1), c.z) for c in cos]
            else:
                ab = [(c.x, c.y) for c in cos]
        if kind == "fit":
            if mode == "fitcyl":
                uv = [(a, (b - mn.z) / max(mx.z - mn.z, 1e-6)) for a, b in ab]
                uv = [(a - math.floor(sum(x for x, _ in uv) / len(uv)), b) for a, b in uv]
            else:
                ax = "xyz".index(axis)
                o = [i for i in range(3) if i != ax]
                uv = [((c[o[0]] - mn[o[0]]) / max(mx[o[0]] - mn[o[0]], 1e-6), (c[o[1]] - mn[o[1]]) / max(mx[o[1]] - mn[o[1]], 1e-6))
                      for c in cos]
        else:
            tu = par[0]
            ou = _off([a for a, _ in ab], tu)
            if kind == "absz" and mode in ("cyl", "box") and abs(n.z) < 0.8:
                uv = [((a - ou) / tu, b / par[1]) for a, b in ab]
            elif kind == "absz":   # flange tops / feet: planar, V near the face's height row (dirtiest low down)
                cz = sum(c.z for c in cos) / len(cos)
                ov = _off([b for _, b in ab], tu)
                uv = [((a - ou) / tu, min(0.97, cz / par[1]) * 0.92 + 0.06 * (b - ov) / tu) for a, b in ab]
            else:
                tv = par[1]
                ov = _off([b for _, b in ab], tv)
                uv = [((a - ou) / tu, (b - ov) / tv) for a, b in ab]
        uvs = [(u0 + min(max(a, 0.0), 1.0) * (u1 - u0), v0 + min(max(b, 0.0), 1.0) * (v1 - v0)) for a, b in uv]
        area = 0.0
        for i in range(len(uvs)):
            (xa, ya), (xb, yb) = uvs[i], uvs[(i + 1) % len(uvs)]
            area += xa * yb - xb * ya
        if abs(area) < 1e-9:   # edge-on to the projection (or clamped): a tiny own-plane patch around the same texel
            mu = sum(x for x, _ in uvs) / len(uvs)
            mv = sum(y for _, y in uvs) / len(uvs)
            t1 = (cos[1] - cos[0]).normalized()
            t2 = n.cross(t1).normalized()
            ctr = sum(cos, Vector()) / len(cos)
            pts = [((c - ctr).dot(t1), (c - ctr).dot(t2)) for c in cos]
            ext = max(max(abs(p) for p in q) for q in pts) or 1.0
            k = 1.5 / 1024.0 / ext
            uvs = [(mu + p * k, mv + q * k) for p, q in pts]
        for l, uvp in zip(f.loops, uvs):
            l[uvl].uv = uvp
    return bm


# ---------------------------------------------------------------------------------------------------- assembly
class Part:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()

    def add(self, bm):
        tmp = bpy.data.meshes.new("_tmp")
        bm.to_mesh(tmp)
        bm.free()
        self.bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    def finish(self, mat, sharp_deg=38.0):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4], ngon_method="EAR_CLIP")
        for v in bm.verts:
            v.co *= S
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(sharp_deg):
                e.smooth = False
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        me.uv_layers[0].name = "UVMap"
        me.materials.append(mat)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def material(asset, wet=False):
    """Preview material on the atlas (turntable / bake read the spec's maps; this keeps the .blend honest)."""
    name = "MI_Street_Main" + ("_Wet" if wet else "")
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    d = os.path.join(TEX, asset)

    def img(kind, colour):
        p = os.path.join(d, "%s_%s.png" % (SL.ATLAS_PREFIX, kind))
        if not os.path.exists(p):
            return None
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(p, check_existing=True)
        if not colour:
            n.image.colorspace_settings.name = "Non-Color"
        return n
    a = img("ALB_Wet" if wet else "ALB", True)
    if a:
        nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    r = img("RGH_Wet" if wet else "RGH", False)
    if r:
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    m = img("MET", False)
    if m:
        nt.links.new(m.outputs["Color"], bsdf.inputs["Metallic"])
    nn = img("NOR", False)
    if nn:
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def empty(name, loc_m, rot=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.location = Vector(loc_m) * S
    e.rotation_euler = rot
    bpy.context.scene.collection.objects.link(e)
    return e


def col_object(name, bms):
    p = Part(name)
    for bm in bms:
        p.add(bm)
    bm = p.bm
    for v in bm.verts:
        v.co *= S
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------------------------------------------- street lamp
def street_lamp():
    A = "M_Road_StreetLamp"
    body, lens = Part(A + "_LOD%d" % LOD), Part(A + "_Lens_LOD%d" % LOD)
    # base shroud (cast, ringed) 0 to 0.95 m, door panel on the front
    shroud = [(0.165, 0.0), (0.165, 0.035), (0.150, 0.05), (0.150, 0.09), (0.135, 0.11), (0.128, 0.30), (0.122, 0.62),
              (0.118, 0.80), (0.130, 0.82), (0.130, 0.86), (0.112, 0.88), (0.095, 0.95), (0.075, 0.97)]
    bm = lathe(shroud if LOD < 2 else shroud[::2] + shroud[-1:], seg(20))
    body.add(uv_piece(bm, A, "paintbase", "cyl"))
    door = box((0.10, 0.012, 0.30), (0.0, -0.127, 0.42), bevel=bev(0.003))
    if LOD < 2:
        body.add(uv_piece(door, A, "paintbase", "box"))
    for z in ((0.30, 0.54) if LOD == 0 else (0.30,)):                                   # door hinge / lock bosses
        body.add(uv_piece(lathe([(0.009, 0), (0.009, 0.012)], 6, cap_top=True), A, "galv", "cyl") if False else
                 uv_piece(transform(lathe([(0.0, 0.0), (0.010, 0.0), (0.010, 0.012), (0.0, 0.013)], 6),
                                    Matrix.Translation((0.04, -0.134, z)) @ Matrix.Rotation(math.radians(90), 4, "X")), A, "galv", "box"))
    # tapered column 0.95 to 5.45 m (cut on the 0.6 m tile lines)
    col = [(0.074, 0.95), (0.068, 2.0), (0.060, 3.5), (0.052, 5.0), (0.050, 5.45)]
    bm = lathe(col, seg(14), z_cuts=[0.6 * k for k in range(2, 10)])
    body.add(uv_piece(bm, A, "paint", "cyl"))
    cap = lathe([(0.050, 5.45), (0.058, 5.46), (0.058, 5.49), (0.035, 5.52), (0.0, 5.53)], seg(14))
    body.add(uv_piece(cap, A, "paint", "cyl"))
    # ID plate (invented number) at 2.4 m, facing the road
    plate = box((0.10, 0.006, 0.055), (0.0, -0.066, 2.4), bevel=bev(0.0015))
    if True:
        body.add(uv_piece(plate, A, "plate", "fitplane", axis="y"))
    # outreach bracket: swept tube rising from the column top-side and curving out to +X
    path = [(0.0, 0.0, 5.10), (0.02, 0.0, 5.30)] + arc((0.32, 0.0, 5.30), 0.30, 180, 90, 6)[1:] + [(0.62, 0.0, 5.62), (0.70, 0.0, 5.62)]
    bm = sweep(path, circle(0.026, seg(10, 5)))
    body.add(uv_piece(bm, A, "paint", "box"))
    brace = sweep([(0.0, 0.0, 4.95), (0.22, 0.0, 5.18), (0.40, 0.0, 5.50)], circle(0.012, seg(8, 4)))
    if LOD < 2:
        body.add(uv_piece(brace, A, "paint", "box"))
    # LED lantern head: slim tapered housing 0.62 x 0.26 x 0.09 m, tilted 5 degrees up, cooling fins on the top
    tilt = Matrix.Translation((0.70, 0.0, 5.62)) @ Matrix.Rotation(math.radians(5), 4, "Y")
    sec = rounded_rect(0.26, 0.085, 0.03, 2 if LOD == 0 else (1 if LOD == 1 else 0))
    hpath = [(-0.02, 0, 0), (0.06, 0, 0), (0.30, 0, 0), (0.56, 0, -0.004), (0.62, 0, -0.008)]
    bm = sweep(hpath, [(a, b) for a, b in sec])
    # taper the nose
    for v in bm.verts:
        t = max(0.0, (v.co.x - 0.3) / 0.32)
        v.co.y *= 1.0 - 0.28 * t
        v.co.z *= 1.0 - 0.25 * t
    transform(bm, tilt)
    body.add(uv_piece(bm, A, "housing", "box"))
    for k in range(5 if LOD == 0 else 0):                    # fins
        fin = box((0.36, 0.008, 0.018), (0.30, -0.08 + k * 0.04, 0.050), bevel=0.002)
        transform(fin, tilt)
        body.add(uv_piece(fin, A, "housing", "box"))
    # lens: flat frosted panel on the underside (own MeshPart: Neon / glow at night)
    lb = box((0.46, 0.20, 0.008), (0.33, 0.0, -0.045), bevel=bev(0.003))
    transform(lb, tilt)
    lens.add(uv_piece(lb, A, "lens", "fitplane", axis="z"))
    mat = material(A)
    parts = {"Body": body.finish(mat), "Lens": lens.finish(mat)}
    col = col_object(A + "_COL", [lathe([(0.17, 0.0), (0.17, 0.95), (0.075, 0.95), (0.052, 5.5)], 8, cap_bottom=True, cap_top=True)])
    light_pos = tilt @ Vector((0.33, 0.0, -0.06))
    att = [empty("ATT_Light", light_pos, (math.radians(180), 0, 0)), empty("ATT_Base", (0, 0, 0))]
    return parts, col, att


# ---------------------------------------------------------------------------------------------------- bench
def bench():
    A = "M_Road_Bench"
    body = Part(A + "_LOD%d" % LOD)
    # cast-iron end frames at x = +-0.80 (and a centre bearer), section 0.045 x 0.03 m, side profile in YZ
    sec = rounded_rect(0.045, 0.030, 0.008, 1 if LOD == 0 else 0)
    for x in (-0.80, 0.0, 0.80):
        centre = abs(x) < 0.01
        legs = [
            [(x, -0.24, 0.0), (x, -0.235, 0.20), (x, -0.215, 0.42)],                      # front leg
            [(x, 0.22, 0.0), (x, 0.205, 0.22), (x, 0.17, 0.42)],                          # rear leg into the back post
            [(x, -0.25, 0.405), (x, -0.05, 0.395), (x, 0.17, 0.42)],                      # seat bearer (dished)
            [(x, 0.17, 0.42), (x, 0.205, 0.62), (x, 0.245, 0.82)],                        # back post, raked
        ]
        if not centre:
            legs.append([(x, -0.215, 0.42), (x, -0.235, 0.56), (x, -0.16, 0.64), (x, 0.0, 0.645), (x, 0.19, 0.62)])  # arm scroll
        for path in legs:
            bm = sweep(path, sec, up=Vector((1, 0, 0)))
            uv_piece(bm, A, "ironbase" if path[0][2] < 0.01 else "iron", "box")
            body.add(bm)
        for y in (-0.24, 0.22):                                                          # feet pads
            foot = box((0.06, 0.09, 0.02), (x, y, 0.01), bevel=bev(0.004))
            body.add(uv_piece(foot, A, "ironbase", "box"))
    # slats: 5 seat (dished curve) and 4 back, 0.065 x 0.028 m hardwood, 1.84 m long
    seat_y = [-0.22, -0.13, -0.04, 0.05, 0.14]
    for i, y in enumerate(seat_y):
        z = 0.432 + 0.012 * (1 - abs(i - 2) / 2.0) * -1 + (0.02 if i == 0 else 0)
        s = box((1.84, 0.065, 0.028), (0.0, y, z), bevel=bev(0.006))
        body.add(uv_piece(s, A, "wood", "box"))
    rake = math.radians(16)
    for k in range(4):
        zc = 0.52 + k * 0.085
        yc = 0.17 + (zc - 0.42) * math.tan(rake) + 0.035
        s = box((1.84, 0.028, 0.065), (0.0, 0.0, 0.0), bevel=bev(0.006))
        transform(s, Matrix.Translation((0.0, yc, zc)) @ Matrix.Rotation(-rake, 4, "X"))
        body.add(uv_piece(s, A, "wood", "box"))
    # coach bolts (galvanised) through the slats into the frames
    for x in ((-0.80, 0.0, 0.80) if LOD == 0 else (0.80,)):
        for y in (seat_y if LOD == 0 else seat_y[:1]):
            b = lathe([(0.0, 0.0), (0.009, 0.0), (0.008, 0.004), (0.0, 0.006)], 6)
            transform(b, Matrix.Translation((x, y, 0.432 + 0.014 + (0.02 if y == seat_y[0] else 0) - 0.012 * 0)))
            body.add(uv_piece(b, A, "galv", "box"))
    mat = material(A)
    parts = {"Body": body.finish(mat)}
    col = col_object(A + "_COL", [box((1.86, 0.52, 0.46), (0.0, -0.01, 0.23)), transform(box((1.86, 0.08, 0.40), (0, 0, 0)),
                                   Matrix.Translation((0.0, 0.24, 0.66)) @ Matrix.Rotation(-rake, 4, "X"))])
    att = [empty("ATT_Seat", (0.0, -0.05, 0.45)), empty("ATT_Base", (0, 0, 0))]
    return parts, col, att


# ---------------------------------------------------------------------------------------------------- bin
def litter_bin():
    A = "M_Road_Bin"
    body = Part(A + "_LOD%d" % LOD)
    R = 0.21

    def flute(th, z):
        return 1.0 + (0.025 * max(0.0, math.cos(th * 16)) if 0.13 < z < 0.74 else 0.0)
    prof = [(R + 0.02, 0.0), (R + 0.02, 0.05), (R + 0.005, 0.07), (R - 0.005, 0.12), (R - 0.005, 0.13), (R, 0.40), (R, 0.74),
            (R + 0.004, 0.75)]
    bm = lathe(prof, seg(48, 12), flutes=flute)
    lo = bmesh.new()
    body.add(uv_piece(bm, A, "paintbase", "cyl"))
    band = lathe([(R + 0.006, 0.75), (R + 0.008, 0.76), (R + 0.008, 0.84), (R + 0.006, 0.85)], seg(32, 10))
    body.add(uv_piece(band, A, "band", "fitcyl"))
    rim = lathe([(R + 0.006, 0.85), (R + 0.018, 0.87), (R + 0.018, 0.895), (R + 0.004, 0.91), (R - 0.012, 0.905),
                 (R - 0.016, 0.88)], seg(32, 10))
    body.add(uv_piece(rim, A, "paint", "cyl"))
    liner = lathe([(R - 0.016, 0.88), (R - 0.022, 0.86), (R - 0.022, 0.50), (R - 0.03, 0.49), (0.0, 0.49)], seg(24, 8))
    for f in liner.faces:
        f.normal_flip()
    body.add(uv_piece(liner, A, "galv", "cyl"))
    for th in ((math.radians(-90 + 25), math.radians(-90 - 25)) if LOD == 0 else ()):         # fixing bolts on the plinth
        b = lathe([(0.0, 0.0), (0.012, 0.0), (0.011, 0.008), (0.0, 0.011)], 6)
        transform(b, Matrix.Translation(((R + 0.012) * math.cos(th), (R + 0.012) * math.sin(th), 0.05)))
        body.add(uv_piece(b, A, "paintbase", "box"))
    mat = material(A)
    parts = {"Body": body.finish(mat)}
    col = col_object(A + "_COL", [lathe([(R + 0.02, 0.0), (R + 0.02, 0.91)], 8, cap_bottom=True, cap_top=True)])
    att = [empty("ATT_Opening", (0.0, 0.0, 0.91)), empty("ATT_Base", (0, 0, 0))]
    return parts, col, att


# ---------------------------------------------------------------------------------------------------- bollard
def bollard():
    A = "M_Road_Bollard"
    body = Part(A + "_LOD%d" % LOD)
    prof = [(0.105, 0.0), (0.105, 0.03), (0.095, 0.05), (0.092, 0.10), (0.085, 0.30), (0.078, 0.55), (0.074, 0.68)]
    body.add(uv_piece(lathe(prof, seg(24, 8), z_cuts=[0.35, 0.66]), A, "paintbase", "cyl"))
    band = lathe([(0.074, 0.68), (0.0745, 0.69), (0.0745, 0.75), (0.074, 0.76)], seg(24, 8))
    body.add(uv_piece(band, A, "band", "fitcyl"))
    top = [(0.074, 0.76), (0.074, 0.78), (0.086, 0.79), (0.088, 0.81), (0.080, 0.825), (0.060, 0.83), (0.052, 0.845),
           (0.050, 0.86), (0.040, 0.875), (0.028, 0.885), (0.034, 0.892), (0.030, 0.905), (0.018, 0.912), (0.0, 0.915)]
    body.add(uv_piece(lathe(top if LOD < 2 else top[::2] + top[-1:], seg(24, 8)), A, "paint", "cyl"))
    mat = material(A)
    parts = {"Body": body.finish(mat)}
    col = col_object(A + "_COL", [lathe([(0.105, 0.0), (0.09, 0.915)], 8, cap_bottom=True, cap_top=True)])
    att = [empty("ATT_Base", (0, 0, 0))]
    return parts, col, att


BUILDERS = {"M_Road_StreetLamp": street_lamp, "M_Road_Bench": bench, "M_Road_Bin": litter_bin, "M_Road_Bollard": bollard}
DIMS = {  # real size (m), Blender X, Y, Z; matches art/reference/<Asset>/dims.md
    "M_Road_StreetLamp": (1.49, 0.33, 5.67),
    "M_Road_Bench": (1.84, 0.62, 0.84),
    "M_Road_Bin": (0.46, 0.46, 0.91),
    "M_Road_Bollard": (0.21, 0.21, 0.915),
}


def spec(asset):
    for ob in list(bpy.context.scene.collection.objects):
        if ob.name.startswith(asset):
            bpy.data.objects.remove(ob, do_unlink=True)
    global LOD
    meshes = []
    for LOD in (2, 1, 0):          # LOD0 last so its COL / attachments are the ones kept
        parts, col, att = BUILDERS[asset]()
        meshes += [{"object": o, "set": SL.ATLAS_SET} for o in parts.values()]
        if LOD:
            me = col.data
            bpy.data.objects.remove(col, do_unlink=True)
            bpy.data.meshes.remove(me)
            for e in att:
                bpy.data.objects.remove(e, do_unlink=True)
    meshes.append({"object": col})
    return {
        "name": asset,
        "budget": "large_prop",
        "tris": 2500,                 # docs/12 2.4 row: 800 to 2,500
        "tier": "standard",
        "dims_m": DIMS[asset],
        "size_note": None,
        "origin": "free",             # the post / centre sits on the origin, on the ground
        "atlas": "Street",
        "sets": [{"name": "Street", "set": SL.ATLAS_SET, "size": 1024, "wet": True}],
        "meshes": meshes,
        "attachments": att,
        "closeups": None,
        "waivers": ({"LOD UV layout": "hand-made LODs share the LOD0 trim mapping exactly (bounds 0.000); the 15.6% UV-area "
                                      "drop is the 6 mm slat edge bevels and coach bolts, LOD0 only (R1a)"}
                    if asset == "M_Road_Bench" else {}),
    }
