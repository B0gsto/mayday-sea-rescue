"""R2 M_Road_CrashBarrier (docs/12 2.4, Haven Head road): UK W-beam safety barrier, one 4 m modular section.

    python3 art/source/roads/M_Road_CrashBarrier/barriertex.py            (trim set, once)
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/roads/M_Road_CrashBarrier/build.py \
        --out-root build/prod/M_Road_CrashBarrier --steps build,lod,validate,export,turntable

Real dimensions (verify): W-beam 312 mm tall, 83 mm deep, 4 mm sheet (6 mm here so the edges read at 3 studs/m),
beam centre 0.55 m above ground, beam top 0.71 m; posts on 2 m centres (4 m panels lap at mid-span), post top 0.72 m.
The section tiles end to end: posts sit at x = 0 and 2 m, the seam at x = 4 m falls between posts, the +X end is the
swaged lap panel that lies over the next piece's plain end (a 10 mm step, so two pieces never share a plane), and the
running surface has a 4 mm periodic wave plus dents that die out at both ends, so a run never reads as one tile. The
origin is on the ground at the -X end post (x = 0 runs along +X here, i.e. Roblox -X). ATT_Snap_Start / ATT_Snap_End
are the end snap points (local -Y forward, pointing out of the piece), ATT_Base the ground point at the -X post.

The game road kit (kit.py) supplies Part / box / transforms / empties / the collision proxy; the trim set is
art/source/roads/M_Road_CrashBarrier/barriertex.py on layout.py, in the same style as the street furniture atlas.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROADS = os.path.dirname(HERE)
sys.path.insert(0, ROADS)
sys.path.insert(0, HERE)
import kit  # noqa: E402
import layout as L  # noqa: E402

S = kit.S

# ---------------------------------------------------------------------------------------------------- real sizes (m)
L_MOD = 4.00          # module length between snap points
POST_X = (0.0, 2.0)   # post centres, 2 m spacing
BEAM_H = 0.312        # W-beam section height
BEAM_D = 0.083        # section depth, crest plane to the valley floors (docs row: 83 mm)
BEAM_T = 0.006        # sheet thickness (a real 4 mm sheet vanishes at 3 studs/m)
Z_BEAM = 0.550        # beam centre above ground
VAL_D = 0.042         # corrugation depth: valley floors behind the crest plane
CORR = 0.105          # corrugation wavelength: crests at z = 0 and +-0.105 m (two valleys = the W)
Y_FRONT = -0.083      # the beam's front (road-facing) plane
POST_H = 0.720        # post top
POST_W = 0.090        # post flange width (along the road)
POST_D = 0.076        # post depth (into the verge)
POST_TF = 0.010       # post flange thickness
POST_TW = 0.009       # post web thickness
POST_FRONT = Y_FRONT + 0.050          # post front face: the valley floors clear it by 2 mm
PLATE = (0.10, 0.008, 0.060)          # reflector plate (width, thickness, height) at mid-span
DENTS = ((2.62, 0.620, 0.30, 0.060, 0.055), (3.28, 0.498, 0.20, 0.045, 0.030), (1.45, 0.578, 0.24, 0.045, 0.018))
DIMS_M = (4.045, 0.152, POST_H)        # X: post flange -0.045 to the beam end; Y: plate bolts to the nuts

U_OFF_POST = (0.0, 0.42)               # per-post U offset so the two posts do not read as one texture patch


def sstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def wave(x):
    """A 4 mm sag between the posts; zero at x = 0 and 2 m so the brackets stay true and the piece still tiles."""
    return 0.004 * math.sin(2 * math.pi * x / L_MOD)


def lap(x):
    """The swaged +X end: the sheet steps 10 mm towards the road over the last 0.4 m (real lapped joint)."""
    return 0.010 * sstep(3.60, 3.82, x)


def dent(x, z):
    """(push back m, crush 0..1) of the worst impact at (x, z)."""
    push, crush = 0.0, 0.0
    for cx, cz, sx, sz, amp in DENTS:
        e = math.exp(-(((x - cx) / sx) ** 2 + ((z - cz) / sz) ** 2))
        push += amp * e
        crush = max(crush, e)
    return push, crush


# ---------------------------------------------------------------------------------------------------- 2D helpers
def arc_fillet(p0, p1, p2, r, seg):
    """Fillet points (including both tangent points) rounding the corner p0-p1-p2 with radius r."""
    v1, v2 = p0 - p1, p2 - p1
    l1, l2 = v1.length, v2.length
    if r <= 1e-6 or l1 < 1e-6 or l2 < 1e-6:
        return [tuple(p1)]
    v1, v2 = v1.normalized(), v2.normalized()
    ang = math.acos(max(-1.0, min(1.0, v1.dot(v2))))
    if ang < 1e-3:
        return [tuple(p1)]
    tan = min(r / math.tan(ang / 2), l1 * 0.49, l2 * 0.49)
    rr = tan * math.tan(ang / 2)
    t1, t2 = p1 + v1 * tan, p1 + v2 * tan
    c = p1 + (v1 + v2).normalized() * (rr / math.sin(ang / 2))
    a1 = math.atan2(t1.y - c.y, t1.x - c.x)
    a2 = math.atan2(t2.y - c.y, t2.x - c.x)
    da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
    return [(c.x + rr * math.cos(a1 + da * k / seg), c.y + rr * math.sin(a1 + da * k / seg)) for k in range(seg + 1)]


def fillet_open(pts, radii, segs):
    out = [tuple(pts[0])]
    for i in range(1, len(pts) - 1):
        out += arc_fillet(Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[i + 1]), radii[i - 1], segs[i - 1])
    return out + [tuple(pts[-1])]


def fillet_closed(pts, radii, segs):
    out, n = [], len(pts)
    for i in range(n):
        out += arc_fillet(Vector(pts[i - 1]), Vector(pts[i]), Vector(pts[(i + 1) % n]), radii[i], segs[i])
    return out


def tube(rings, closed=True, cap_start=False, cap_end=False):
    """Faces between consecutive rings (a ring is a list of (x, y, z) metres)."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n if closed else n - 1):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start:
        bm.faces.new(list(reversed(vs[0])))
    if cap_end:
        bm.faces.new(vs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism(r, h, sides=6, taper=0.0):
    """Closed n-gon prism along +Z from z=0 to z=h (bolt and nut heads)."""
    ring = lambda z, k: [(r * k * math.cos(2 * math.pi * i / sides), r * k * math.sin(2 * math.pi * i / sides), z)
                         for i in range(sides)]
    return tube([ring(0.0, 1.0), ring(h * 0.72, 1.0), ring(h, 1.0 - taper)], cap_start=True, cap_end=True)


# ---------------------------------------------------------------------------------------------------- the barrier
def beam_section(seg=24):
    """The W-beam's outer sheet in (y, z) local to the beam centre: y 0 = the crest plane, +y toward the post.
    A smooth corrugation, y = depth (1 - cos(2 pi z / CORR)) / 2, crests at z = 0 and +-CORR (the two valleys between
    them make the W); the wing tips at the top and bottom edges are eased back so they do not reach the full depth."""
    zh = BEAM_H / 2
    out = []
    for i in range(seg + 1):
        z = -zh + BEAM_H * i / seg
        ease = 1.0 - 0.30 * abs(z / zh) ** 6
        out.append((VAL_D * (1.0 - math.cos(2.0 * math.pi * z / CORR)) / 2.0 * ease, z))
    return out


def sheet_back(front):
    """The inner surface of the sheet: every point offset BEAM_T along the profile's normal, away from the road."""
    back = []
    for i, (y, z) in enumerate(front):
        a = Vector(front[max(i - 1, 0)])
        b = Vector(front[min(i + 1, len(front) - 1)])
        n = Vector((b.y - a.y, -(b.x - a.x)))
        if n.length < 1e-9:
            n = Vector((1.0, 0.0))
        n.normalize()
        if n.y < 0:
            n = -n
        back.append((y + n.x * BEAM_T, z + n.y * BEAM_T))
    return back[::-1]


def stations():
    xs = {round(L_MOD * i / 26.0, 4) for i in range(27)}
    xs |= {3.60, 3.70, 3.80, 3.90}
    return sorted(xs)


def beam_bm():
    """The beam shell: the section swept along the module, both ends closed by a strip between the front and back
    sheets (a cut end, and no see-through hole if two pieces are placed with a gap)."""
    front = beam_section()
    back = sheet_back(front)
    y_mid = sum(p[0] for p in front) / len(front)
    rings = []
    for x in stations():
        ring = []
        for src in (front, back):
            for (y, z) in src:
                dy, crush = dent(x, Z_BEAM + z)
                y2 = y_mid + (y - y_mid) * (1.0 - 0.55 * crush) + dy
                ring.append((x, Y_FRONT + y2 + wave(x) - lap(x), Z_BEAM + z))
        rings.append(ring)
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n, half = len(rings[0]), len(rings[0]) // 2
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for k in (0, -1):
        for i in range(half - 1):
            bm.faces.new((vs[k][i], vs[k][i + 1], vs[k][n - 2 - i], vs[k][n - 1 - i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def post_bm(x_post, u_idx):
    hw, tw = POST_W / 2, POST_TW / 2
    outline = [(-hw, 0.0), (hw, 0.0), (hw, POST_TF), (tw, POST_TF), (tw, POST_D - POST_TF), (hw, POST_D - POST_TF),
               (hw, POST_D), (-hw, POST_D), (-hw, POST_D - POST_TF), (-tw, POST_D - POST_TF), (-tw, POST_TF), (-hw, POST_TF)]
    radii = [0.004, 0.004, 0.006, 0.009, 0.009, 0.006, 0.004, 0.004, 0.006, 0.009, 0.009, 0.006]
    segs = [1, 1, 1, 2, 2, 1, 1, 1, 1, 2, 2, 1]
    sec = fillet_closed(outline, radii, segs)
    cx = sum(p[0] for p in sec) / len(sec)
    cy = sum(p[1] for p in sec) / len(sec)
    rings = []
    for z, k in ((0.0, 1.0), (0.36, 1.0), (POST_H - 0.030, 1.0), (POST_H, 0.90)):
        rings.append([(x_post + cx + (p[0] - cx) * k, POST_FRONT + cy + (p[1] - cy) * k, z) for p in sec])
    bm = tube(rings, cap_start=True, cap_end=True)
    return uv_galv(bm, U_OFF_POST[u_idx])


def fastener(pos, rot, r, h, u_off, taper=0.35):
    bm = prism(r, h, 6, taper)
    kit.transform(bm, Matrix.Translation(pos) @ rot)
    return uv_dark(bm, (pos[0], pos[1] - h / 2.0, pos[2])) if u_off is None else uv_galv(bm, u_off)


# ---------------------------------------------------------------------------------------------------- UVs
MID_V = 0.55          # the V a face lying in the horizontal plane takes (the sheet's rim, a cap, a bolt's top)


def uv_galv(bm, u_off=0.0):
    """Trim UVs: box projection, U along the part every TILE_U_M, V = height above ground over GALV_H_M. A face whose
    dominant normal is +-Z (the sheet's rims, caps, bolt tops) has almost no height to give, so it takes a slice of the
    region at MID_V instead - mapping it by height would push V negative and sample the fixing cell (POL1-B)."""
    u0, v0, u1, v1 = L.region_rect("galv")
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        for l in f.loops:
            c = l.vert.co
            if ax == 2:
                uu, vv = c.x / L.TILE_U_M + u_off, MID_V + 0.5 * (c.y - Y_FRONT) / L.GALV_H_M
            else:
                a = (c.y, c.z) if ax == 0 else (c.x, c.z)
                uu, vv = a[0] / L.TILE_U_M + u_off, a[1] / L.GALV_H_M
            l[uvl].uv = (u0 + uu * (u1 - u0), v0 + min(max(vv, 0.0), 1.0) * (v1 - v0))
    return bm


def uv_dark(bm, centre):
    """Dull fixing cell: a local box projection about the piece's own centre, so nothing leaves the cell."""
    u0, v0, u1, v1 = L.region_rect("dark")
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    o = Vector(centre)
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        for l in f.loops:
            c = l.vert.co - o
            a = (c.y * 6.0, c.z * 6.0) if ax == 0 else (c.x * 6.0, c.z * 6.0) if ax == 1 else (c.x * 6.0, c.y * 6.0)
            l[uvl].uv = (u0 + (0.5 + a[0]) * (u1 - u0), v0 + (0.5 + a[1]) * (v1 - v0))
    return bm


def uv_plate(bm):
    """The reflector plate: the road-facing face fills the plate cell, the edges and back take the fixing cell."""
    u0, v0, u1, v1 = L.region_rect("plate")
    d0, e0, d1, e1 = L.region_rect("dark")
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    x0, z0 = 1.0 - PLATE[0] / 2, Z_BEAM - PLATE[2] / 2
    for f in bm.faces:
        front = f.normal.y < -0.7
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        for l in f.loops:
            c = l.vert.co
            if front:
                u = min(max((c.x - x0) / PLATE[0], 0.0), 1.0)
                v = min(max((c.z - z0) / PLATE[2], 0.0), 1.0)
                l[uvl].uv = (u0 + u * (u1 - u0), v0 + v * (v1 - v0))
            else:
                d = c - Vector((1.0, 0.0, Z_BEAM))
                a = (d.y * 6.0, d.z * 6.0) if ax == 0 else (d.x * 6.0, d.z * 6.0) if ax == 1 else (d.x * 6.0, d.y * 6.0)
                l[uvl].uv = (d0 + (0.5 + a[0]) * (d1 - d0), e0 + (0.5 + a[1]) * (e1 - e0))
    return bm


# ---------------------------------------------------------------------------------------------------- assembly
def geometry():
    body = kit.Part("M_Road_CrashBarrier_LOD0")
    body.add(uv_galv(beam_bm()))
    for i, x in enumerate(POST_X):
        body.add(post_bm(x, i))
        for dz in (0.022, -0.022):
            z = Z_BEAM + dz
            y_face = Y_FRONT + VAL_D * (1.0 - math.cos(2.0 * math.pi * dz / CORR)) / 2.0   # the sheet under the head
            body.add(fastener((x, y_face, z), Matrix.Rotation(math.radians(90), 4, "X"), 0.0138, 0.012, 0.03 + 0.11 * i))
            body.add(fastener((x, POST_FRONT + POST_D, z), Matrix.Rotation(math.radians(-90), 4, "X"), 0.0130, 0.009,
                              None))       # nut behind the post
    for x in (0.13, 0.23, L_MOD - 0.23, L_MOD - 0.13):          # panel lap bolts
        body.add(fastener((x, Y_FRONT - 0.0, Z_BEAM), Matrix.Rotation(math.radians(90), 4, "X"), 0.0130, 0.010, 0.19))
    plate_y = Y_FRONT - PLATE[1] / 2 - 0.002
    body.add(uv_plate(kit.box(PLATE, (1.0, plate_y, Z_BEAM), bevel=0.0015)))
    for sx in (-1, 1):                                          # plate fixing bolts
        body.add(fastener((1.0 + sx * 0.036, Y_FRONT - PLATE[1] - 0.002, Z_BEAM),
                          Matrix.Rotation(math.radians(90), 4, "X"), 0.0045, 0.005, 0.30))
    mat = material()
    parts = {"Body": body.finish(mat, sharp_deg=40.0)}
    y_front, y_back = Y_FRONT - PLATE[1] - 0.002, POST_FRONT + POST_D
    col = kit.col_object("M_Road_CrashBarrier_COL", [
        kit.box((L_MOD, y_back - y_front, 0.30), (L_MOD / 2, (y_front + y_back) / 2, Z_BEAM + 0.06)),
        kit.box((0.11, 0.12, 0.75), (POST_X[0], POST_FRONT + POST_D / 2, 0.02)),
        kit.box((0.11, 0.12, 0.75), (POST_X[1], POST_FRONT + POST_D / 2, 0.02)),
    ])
    att = [kit.empty("ATT_Snap_Start", (0, 0, 0), (0, 0, math.radians(-90))),
           kit.empty("ATT_Snap_End", (L_MOD, 0, 0), (0, 0, math.radians(90))),
           kit.empty("ATT_Base", (0, 0, 0))]
    return parts, col, att


def material():
    """Preview material on the trim set (turntable replaces it with the spec's maps from the texture folder)."""
    name = "MI_CrashBarrier_Galv"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    for cand in (os.path.join(kit.TEX, "M_Road_CrashBarrier"),
                 os.path.join(kit.GAME, "build/prod/M_Road_CrashBarrier/textures/M_Road_CrashBarrier")):
        if os.path.isdir(cand):
            for kind, inp, colour in (("ALB", "Base Color", True), ("RGH", "Roughness", False), ("MET", "Metallic", False)):
                p = os.path.join(cand, "T_CrashBarrier_Galv_%s.png" % kind)
                if not os.path.exists(p):
                    continue
                n = nt.nodes.new("ShaderNodeTexImage")
                n.image = bpy.data.images.load(p, check_existing=True)
                if not colour:
                    n.image.colorspace_settings.name = "Non-Color"
                nt.links.new(n.outputs["Color"], bsdf.inputs[inp])
            return mat
    return mat


def build():
    parts, col, att = geometry()
    return {
        "name": "M_Road_CrashBarrier",
        "budget": "large_prop",
        "tris": 4800,                    # docs/12 2.4: 1,000 to 6,000 per 5 m piece, this piece is 4 m
        "tier": "standard",
        "dims_m": DIMS_M,
        "size_note": None,
        "origin": "free",                # the -X post's ground point sits on the origin
        "sets": [{"name": "CrashBarrier", "set": "Galv", "size": 1024, "wet": True}],
        "meshes": [{"object": o, "set": "Galv"} for o in parts.values()] + [{"object": col}],
        "attachments": att,
        "tiling": True,
        "closeups": [
            {"name": "post_bracket", "target": [POST_X[1] * S, 0.0, Z_BEAM * S], "dist": 2.2 * S, "az": 4, "el": 6},
            {"name": "beam_dent", "target": [2.62 * S, 0.0, 0.60 * S], "dist": 2.6 * S, "az": 18, "el": 10},
            {"name": "reflector", "target": [1.0 * S, 0.0, Z_BEAM * S], "dist": 1.1 * S, "az": 0, "el": 4},
            {"name": "lap_joint", "target": [L_MOD * S, 0.0, Z_BEAM * S], "dist": 1.8 * S, "az": 42, "el": 12},
            {"name": "post_base", "target": [POST_X[0] * S, 0.0, 0.10 * S], "dist": 2.0 * S, "az": 8, "el": 24},
            {"name": "beam_back", "target": [2.0 * S, 0.0, Z_BEAM * S], "dist": 2.6 * S, "az": 205, "el": 14},
        ],
    }
