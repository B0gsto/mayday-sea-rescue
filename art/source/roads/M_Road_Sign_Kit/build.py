"""R2 M_Road_Sign_Kit (docs/12 2.4): five invented UK-style coastal signs on one shared sign atlas, each its own mesh.

    python3 art/source/roads/M_Road_Sign_Kit/signtex.py                    (atlas, once; no heavy slot)
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/roads/M_Road_Sign_Kit/build.py \
        --out-root build/prod/M_Road_Sign_Kit --steps build,lod,validate,export,turntable

The five signs stand on a 4 m grid along +X (the kit's own display line; every sign's post axis and ground point is its
own origin, and the Roblox offsets from the model pivot are in RESULT.md):

  M_Road_Sign_Fingerpost     x 0.0  a Cornish-style painted timber fingerpost: a 110 mm post 2.43 m to the finial and
                                    four pointed blades (1.10 / 0.98 / 0.92 / 0.85 m) on a 0.30 m pitch, each held by a
                                    galvanised strap round the post with two bolts through it. Blades read
                                    PORT HAVEN 1, HAVEN SANDS 1/2, HAVEN HEAD 3/4, GALE ISLES 3.
  M_Road_Sign_TideBoard      x 3.0  the Port Haven tide table board: a 0.90 x 1.15 m plate with a printed table on two
                                    76 mm galvanised posts at 0.72 m centres, eight days of four tides, clamped by a
                                    band clip above and below on each post.
  M_Road_Sign_LaunchSign     x 6.0  the slipway launch sign: a 0.75 x 0.55 m blue panel (slipway and boat pictogram,
                                    LIFEBOAT LAUNCH) with a 0.45 x 0.15 m KEEP CLEAR plate bolted to its lower edge,
                                    on one 76 mm post 2.32 m.
  M_Road_Sign_CarPark        x 9.0  the car park sign: a 0.60 x 0.60 m blue plate (white P) with a 0.60 x 0.20 m
                                    HARBOUR CAR PARK plate bolted under it, on one 76 mm post 2.52 m.
  M_Road_Sign_CliffWarning   x 12.0 the cliff warning: a 900 mm warning triangle (90 mm red border, white rim line,
                                    rockfall pictogram) with a 0.60 x 0.30 m CLIFF EDGE plate, on one 76 mm post 2.95 m.

Real proportions follow the UK Traffic Signs Manual sizes from memory (verify before shipping): 900 mm warning triangle
with a 90 mm red border, 600 x 600 parking place plate, 600 x 450 information plates, 76 mm steel posts, sign plates
folded 22 to 25 mm with a rolled front edge, band clips on 30 mm stainless band with an M8 bolt each side of the post.
Every plate carries two fixing bolts on its printed face and the painter runs rust down from the same points
(sign_layout.FIXINGS), so clip, bolt and rust streak always line up. All names and numbers are invented (docs/01);
no real sign is copied.
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
import sign_layout as L  # noqa: E402

S = kit.S
GRID = 3.0                    # the display line: sign k's post axis stands at x = 3.0 * k (fingerpost, tide board,
                              # launch sign, car park, cliff warning), every one at y 0 on the ground

# ---------------------------------------------------------------------------------------------------- real sizes (m)
POST_D = 0.076                # steel post outside diameter (3 mm wall, as real roadside posts)
POST_CAP = 0.060              # black plastic cap sleeve at the top of a steel post
PLATE_T = 0.022               # sign plate thickness (folded aluminium, 22 mm return)
PLATE_T2 = 0.018              # supplementary plates fold less
BAND_W = 0.030                # band clip width
BAND_T = 0.0022               # stainless band thickness
BAND_GAP = 0.0045             # the band stands this clear of the post's surface
POST_R = POST_D / 2.0
BAND_R = POST_R + BAND_GAP
PLATE_BACK = -(POST_R + BAND_GAP + BAND_T + 0.002)   # the plate's back sits on the band, 2 mm off it
BOLT_R, BOLT_H = 0.0085, 0.010   # M8 hex head (16 mm across the flats, 10 mm high)

# fingerpost
FP_POST, FP_H, FP_FIN = 0.110, 2.340, 0.090          # 110 mm sawn post, 2.34 m to the top, 90 mm finial
FP_BLADE_T, FP_BLADE_H = 0.026, 0.145                # blade 26 mm thick, 145 mm deep
FP_TAIL = 0.045                                      # the pointed tail behind the blade
FP_BLADES = (("blade_a", 1.10, 1.950, 0.0), ("blade_b", 0.98, 1.650, 90.0),
             ("blade_c", 0.92, 1.350, 180.0), ("blade_d", 0.85, 1.050, 270.0))    # (face, length, bottom z, bearing)
FP_DIMS = (2.20, 2.20, FP_H + FP_FIN)

# tide board
TB_POST_X, TB_POST_H = 0.360, 2.020                  # posts at +-0.36 m, 2.02 m tall
TB_W, TB_H, TB_Z0 = 0.900, 1.150, 0.800              # board 0.90 x 1.15 m, bottom edge at 0.80 m
TB_ROWS = (0.945, 0.075)                             # the fixings' heights up the board (fractions)
TB_DIMS = (TB_W, 0.180, TB_POST_H)

# launch sign (one post)
LS_POST_H = 2.320
LS_W, LS_H, LS_Z = 0.750, 0.550, 1.675               # main plate, lower edge 1.675 m (top 2.225)
LS_KW, LS_KH, LS_KZ = 0.450, 0.150, 1.545            # KEEP CLEAR plate, bolted to its lower edge
LS_DIMS = (LS_W, 0.170, LS_POST_H)

# car park sign
CP_POST_H = 2.520
CP_W, CP_H, CP_Z = 0.600, 0.600, 1.820               # P plate, lower edge 1.820 m (top 2.420)
CP_PW, CP_PH, CP_PZ = 0.600, 0.200, 1.640            # HARBOUR CAR PARK plate under it
CP_DIMS = (CP_W, 0.180, CP_POST_H)

# cliff warning
CW_POST_H = 2.950
CW_W, CW_H, CW_Z = 0.900, 0.779, 1.550               # triangle bounding box, lower vertex 1.550 m
CW_PW, CW_PH, CW_PZ = 0.600, 0.300, 1.150            # CLIFF EDGE plate
CW_DIMS = (CW_W, 0.170, CW_POST_H)


# ---------------------------------------------------------------------------------------------------- 2D helpers
def rect_pts(w, h, r):
    """A rounded rectangle (0..w, 0..h) as a point list, anticlockwise in (x, z), 4 points per corner."""
    return [(x + w / 2.0, z + h / 2.0) for x, z in kit.rounded_rect(w, h, r, 4)]


def tri_pts(side, r):
    """An equilateral warning triangle, apex up, in (0..side, 0..side * sqrt(3) / 2), corners rounded."""
    h = side * math.sqrt(3.0) / 2.0
    pts = [(side / 2.0, h), (0.0, 0.0), (side, 0.0)]
    out = []
    m = 3
    for i in range(m):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % m]
        v1 = Vector((p0[0] - p1[0], p0[1] - p1[1]))
        v2 = Vector((p2[0] - p1[0], p2[1] - p1[1]))
        u1, u2 = v1.normalized(), v2.normalized()
        ang = math.acos(max(-1.0, min(1.0, u1.dot(u2))))
        tan = min(r / math.tan(ang / 2.0), v1.length * 0.49, v2.length * 0.49)
        t1 = Vector(p1) + u1 * tan
        t2 = Vector(p1) + u2 * tan
        for k in range(4 + 1):
            t = k / 4.0
            out.append(tuple((1 - t) ** 2 * t1 + 2 * t * (1 - t) * Vector(p1) + t * t * t2))
    return out


def _inward(p0, p1, centre):
    d = Vector((p1[0] - p0[0], p1[1] - p0[1]))
    n = Vector((d.y, -d.x))
    if n.length < 1e-12:
        return n
    n.normalize()
    mid = Vector(((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0))
    if n.dot(Vector(centre) - mid) < 0:
        n = -n
    return n


def inset_pts(pts, d):
    """The convex outline's edges moved inward by d (the rolled edge of a folded sign plate)."""
    m = len(pts)
    centre = (sum(p[0] for p in pts) / m, sum(p[1] for p in pts) / m)
    out = []
    for i in range(m):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % m]
        n1, n2 = _inward(p0, p1, centre), _inward(p1, p2, centre)
        a1 = (p0[0] + n1.x * d, p0[1] + n1.y * d)
        a2 = (p1[0] + n1.x * d, p1[1] + n1.y * d)
        b1 = (p1[0] + n2.x * d, p1[1] + n2.y * d)
        b2 = (p2[0] + n2.x * d, p2[1] + n2.y * d)
        d1 = (a2[0] - a1[0], a2[1] - a1[1])
        d2 = (b2[0] - b1[0], b2[1] - b1[1])
        den = d1[0] * d2[1] - d1[1] * d2[0]
        if abs(den) < 1e-12:
            out.append(a2)
            continue
        t = ((b1[0] - a1[0]) * d2[1] - (b1[1] - a1[1]) * d2[0]) / den
        out.append((a1[0] + d1[0] * t, a1[1] + d1[1] * t))
    return out


def rect8(w, h, r):
    """An 8-point rounded section (corner cut r) in (a, b): cheap, and the flat faces stay flat for the printed art."""
    return [(w / 2, -h / 2 + r), (w / 2, h / 2 - r), (w / 2 - r, h / 2), (-w / 2 + r, h / 2),
            (-w / 2, h / 2 - r), (-w / 2, -h / 2 + r), (-w / 2 + r, -h / 2), (w / 2 - r, -h / 2)]


def tube(rings, cap_start=False, cap_end=False):
    """Faces between consecutive rings (a ring is a list of (x, y, z) metres)."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start:
        bm.faces.new(list(reversed(vs[0])))
    if cap_end:
        bm.faces.new(vs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def loop_tube(path, section, up=Vector((0, 0, 1))):
    """A closed tube along a closed path (band clips): no end caps."""
    bm = bmesh.new()
    P = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(P):
        t = (P[(i + 1) % len(P)] - P[(i - 1) % len(P)]).normalized()
        side = t.cross(up)
        if side.length < 1e-4:
            side = t.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(t).normalized()
        rings.append([bm.verts.new(p + side * a + nrm * b) for a, b in section])
    n = len(section)
    for a, b in zip(rings, rings[1:] + rings[:1]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism(r, h, sides=6, taper=0.35):
    """A closed hex prism along +Z (bolt heads and nuts)."""
    ring = lambda z, k: [(r * k * math.cos(2 * math.pi * i / sides), r * k * math.sin(2 * math.pi * i / sides), z)
                         for i in range(sides)]
    return tube([ring(0.0, 1.0), ring(h * 0.70, 1.0), ring(h, 1.0 - taper)], cap_start=True, cap_end=True)


# ---------------------------------------------------------------------------------------------------- UVs
CLIP_V_M = L.TILES["clip"][1]   # the clip cell's V span in metres (the strap's 30 mm width)


def _clamp01(v):
    return min(max(v, 0.0), 1.0)


def _wrap(vals):
    """Per-face tile offset: the face lands inside one tile of the region (the patterns are seamless, so any tile will
    do, and a face that straddled a tile line would smear)."""
    o = math.floor(sum(vals) / len(vals))
    lo, hi = min(vals), max(vals)
    if hi - lo <= 1.0:
        if lo < o:
            o = lo
        elif hi > o + 1.0:
            o = hi - 1.0
    return [v - o for v in vals]


def uv_trim(bm, region, u_off=0.0, alt=None, split_z=None):
    """Box projection of a member into a trim region: U = the horizontal coordinate every TILE_U_M of the region (with
    a per-face tile offset), V = the height above ground over the region's V span for the absz bands (galvbase,
    paintbase) or a plain V tile otherwise. With `alt` and `split_z`, a face lying wholly above split_z takes `alt`
    (the clean steel or paint above the splash band)."""
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        reg = region
        if alt and split_z is not None and min(l.vert.co.z for l in f.loops) >= split_z - 1e-6:
            reg = alt          # a face sitting on the split line belongs to the clean band above it, not below
        u0, v0, u1, v1 = L.region_rect(reg)
        t_u, t_v = L.TILES[reg]
        absz = reg in L.ABSZ
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        hs, vs = [], []
        for l in f.loops:
            c = l.vert.co
            if ax == 2:       # a cap, a plate rim or a bolt top: no height to give, so it takes the band at MID_V
                hs.append(c.x / t_u + u_off)
                vs.append(0.5 + c.y / t_v)
            else:
                hs.append((c.y if ax == 0 else c.x) / t_u + u_off)
                vs.append(c.z / t_v)
        us, vs = _tile_uvs(hs, vs, absz)
        uvs = [(u0 + u * (u1 - u0), v0 + v * (v1 - v0)) for u, v in zip(us, vs)]
        _fix_degenerate(f, uvs, uvl)
        for l, uvp in zip(f.loops, uvs):
            l[uvl].uv = uvp
    return bm


def _tile_uvs(hs, vs, absz):
    """The U and V of one face on the region's tile or (absz) on the height above ground. A face keeps its own tile
    (per-face offset, so the seamless pattern never straddles a tile line inside a face); a decimated face that spans
    more than one tile after a LOD collapse is *compressed* into one, never clamped: clamping collapses its UVs to a
    line (zero area) and moves the sheet's UV bounds - compression keeps both the area and the layout."""
    us = _wrap(hs)
    span_u = max(us) - min(us)
    if span_u > 1.0:
        us = [(u - min(us)) / span_u for u in us]
    vs = [v for v in vs] if absz else _wrap(vs)
    span_v = max(vs) - min(vs)
    if span_v > 1.0 or min(vs) < 0.0 or max(vs) > 1.0:
        lo, hi = min(vs), max(vs)
        vs = [(v - lo) / (hi - lo) if hi - lo > 1e-9 else 0.5 for v in vs]
    return [_clamp01(u) for u in us], [_clamp01(v) for v in vs]


def _fix_degenerate(f, uvs, uvl):
    """A face that comes out with no UV area (a cap seen edge-on, a face clamped to the region's edge) takes a tiny
    patch of its own plane about the same texel: never a zero-area UV island (kit.uv_piece does the same)."""
    area = 0.0
    for i in range(len(uvs)):
        (xa, ya), (xb, yb) = uvs[i], uvs[(i + 1) % len(uvs)]
        area += xa * yb - xb * ya
    if abs(area) > 1e-12:
        return
    cos = [l.vert.co for l in f.loops]
    n = f.normal
    mu = sum(u for u, _ in uvs) / len(uvs)
    mv = sum(v for _, v in uvs) / len(uvs)
    t1 = (cos[1] - cos[0]).normalized() if (cos[1] - cos[0]).length > 1e-9 else Vector((1, 0, 0))
    t2 = n.cross(t1).normalized()
    ctr = sum(cos, Vector()) / len(cos)
    pts = [((c - ctr).dot(t1), (c - ctr).dot(t2)) for c in cos]
    ext = max(max(abs(p) for p in q) for q in pts) or 1.0
    k = 1.5 / 1024.0 / ext
    for i in range(len(uvs)):
        uvs[i] = (mu + pts[i][0] * k, mv + pts[i][1] * k)


def uv_piece(bm, region, centre, tile=None):
    """Box projection of one small fitting about its own centre, so its faces share one continuous mapping (the LOD
    decimator keeps their UV islands together) and it never leaves the region."""
    u0, v0, u1, v1 = L.region_rect(region)
    t_u, t_v = tile or L.TILES.get(region, (0.40, 0.20))
    o = Vector(centre)
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        us, vs = [], []
        for l in f.loops:
            c = l.vert.co - o
            a, b = (c.y, c.z) if ax == 0 else ((c.x, c.z) if ax == 1 else (c.x, c.y))
            us.append(0.5 + a / t_u)
            vs.append(0.5 + b / t_v)
        us, vs = _wrap(us), _wrap(vs)
        for l, u, v in zip(f.loops, us, vs):
            l[uvl].uv = (u0 + _clamp01(u) * (u1 - u0), v0 + _clamp01(v) * (v1 - v0))
    return bm


def bm_centre(bm):
    xs = [v.co for v in bm.verts]
    return (sum(c.x for c in xs) / len(xs), sum(c.y for c in xs) / len(xs), sum(c.z for c in xs) / len(xs))


def uv_face(bm, region, w, h, y_face=0.0, rest="alu", rest_tile=None):
    """A folded plate in its own local frame: the printed polygon (the plane y = y_face, x 0..w, z 0..h) fills the
    face's rect of the atlas; the folded rim, the rolled edge and the back take the rest region, box-projected about
    the plate's own centre so their mapping is continuous."""
    u0, v0, u1, v1 = L.face_rect(region)
    r0, s0, r1, s1 = L.region_rect(rest)
    t_u, t_v = rest_tile or L.TILES.get(rest, (0.40, 0.20))
    centre = bm_centre(bm)
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        if all(abs(l.vert.co.y - y_face) < 1e-4 for l in f.loops):
            for l in f.loops:
                c = l.vert.co
                l[uvl].uv = (u0 + _clamp01(c.x / w) * (u1 - u0), v0 + _clamp01(c.z / h) * (v1 - v0))
        else:
            for l in f.loops:
                c = l.vert.co - Vector(centre)
                a, b = (c.y, c.z) if ax == 0 else ((c.x, c.z) if ax == 1 else (c.x, c.y))
                u, v = 0.5 + a / t_u, 0.5 + b / t_v
                l[uvl].uv = (r0 + _clamp01(u) * (r1 - r0), s0 + _clamp01(v) * (s1 - s0))
    return bm


def uv_band(bm, cx, cy, z_band, loop_m):
    """The band clip's strap: U runs round the loop from the screw housing (the join, where the painter puts the rust),
    twice round the 0.30 m strap tile of the clip cell, V runs across the strap's 30 mm width. A face on the loop's top
    or bottom edge (its normal vertical) has no width to give, so it takes the band's radial thickness instead - never
    a zero-area UV island."""
    u0, v0, u1, v1 = L.region_rect("clip")
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        flat = abs(f.normal.z) > 0.7
        us, rs, us_, vs = [], [], [], []
        for l in f.loops:
            c = l.vert.co
            rs.append(math.hypot(c.x - cx, c.y - cy))
            a = ((math.atan2(c.y - cy, c.x - cx) - math.pi / 2.0) % (2 * math.pi)) / (2 * math.pi)
            us.append(a * loop_m / L.TILES["clip"][0])    # U = arc length along the unfolded strap
        r0 = min(rs)
        for l in f.loops:                                     # a face on the loop's top or bottom edge has no width to
            c = l.vert.co                                     # give, so it takes the strap's own thickness across V
            r = math.hypot(c.x - cx, c.y - cy)
            vs.append(0.5 + ((r - r0) / (2.0 * CLIP_V_M) if flat else (c.z - z_band) / CLIP_V_M))
        us = _wrap(us)
        for l, u, v in zip(f.loops, us, vs):
            l[uvl].uv = (u0 + _clamp01(u) * (u1 - u0), v0 + _clamp01(v) * (v1 - v0))
    return bm


# ---------------------------------------------------------------------------------------------------- parts
def plate_prism(pts, t, bev=0.002):
    """A folded sign plate in local space: outline in (x, z), the printed face at y = 0, the folded rim running back to
    y = t, with a rolled (2 mm) front edge and a folded back edge. Returns a bmesh."""
    bm = bmesh.new()
    ins = inset_pts(pts, bev)
    r0 = [bm.verts.new((x, 0.0, z)) for x, z in ins]
    r1 = [bm.verts.new((x, bev, z)) for x, z in pts]
    r2 = [bm.verts.new((x, t - bev, z)) for x, z in pts]
    r3 = [bm.verts.new((x, t, z)) for x, z in ins]
    n = len(pts)
    for a, b in ((r0, r1), (r1, r2), (r2, r3)):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(r0)))
    bm.faces.new(r3)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def plate(region, outline, w, h, t, at):
    """A printed plate: local frame 0..w by 0..h with the printed face at y = 0, moved to at = (x_left, y_face, z_bottom)."""
    bm = plate_prism(outline, t)
    uv_face(bm, region, w, h, 0.0, rest="alu", rest_tile=L.PLATE_TILE_M)
    return kit.transform(bm, Matrix.Translation(Vector(at)))


def bolt_head(face_y, out=-1.0, r=BOLT_R, h=BOLT_H):
    """An M8 hex head in local space about its own centre, aimed along `out` Y (a bolt out of a face), UV'd to the
    dull fixing cell."""
    bm = prism(r, h, 6, taper=0.30)
    centre = (0.0, out * h / 2.0, 0.0)
    uv_piece(bm, "dark", centre)
    return kit.transform(bm, Matrix.Rotation(math.radians(90 * out), 4, "X"))


def steel_post(cx, cy, h, u_off=0.0):
    """A 76 mm galvanised post: the tube (the bottom BASE_M of it a splash band, cut on the tile lines) and its black
    plastic cap sleeve."""
    prof = [(POST_R, 0.0), (POST_R, h - POST_CAP - 0.004), (POST_R * 0.985, h - POST_CAP), (POST_R * 0.965, h)]
    body = kit.lathe(prof, 12, cap_bottom=True, cap_top=True)
    uv_trim(body, "galv", u_off)
    kit.transform(body, Matrix.Translation((cx, cy, 0.0)))
    zc = h - POST_CAP
    cap = kit.lathe([(POST_R + 0.0035, zc - 0.008), (POST_R + 0.0035, h - 0.006), (POST_R * 0.985, h - 0.001),
                     (POST_R * 0.985, zc - 0.008)], 12)
    uv_piece(cap, "dark", (cx, cy, zc))
    kit.transform(cap, Matrix.Translation((cx, cy, 0.0)))
    return [body, cap]


def band(cx, cy, z_band, square=None, u_off=0.0):
    """A stainless band clip round a post at height z_band: the loop (kept on its tile of the clip cell, its join at
    the back) and the screw housing, which is the clip you see from behind."""
    if square:
        half = square / 2.0 + BAND_GAP
        path = [(cx + a, cy + b, z_band) for a, b in kit.rounded_rect(2 * half, 2 * half, 0.012, 2)]
    else:
        path = [(cx + BAND_R * math.cos(2 * math.pi * i / 12), cy + BAND_R * math.sin(2 * math.pi * i / 12), z_band)
                for i in range(12)]
    loop = loop_tube(path, kit.rounded_rect(BAND_T, BAND_W, 0.0006, 0))
    path_m = sum((Vector(path[(i + 1) % len(path)]) - Vector(path[i])).length for i in range(len(path)))
    uv_band(loop, cx, cy, z_band, path_m)
    out = [loop]
    hx = cx if square else cx
    out.append(uv_piece(kit.box((0.024, 0.026, 0.030), (hx, cy + (square or POST_D) / 2.0 + BAND_GAP + 0.010, z_band),
                                bevel=0.0015), "clip", (hx, cy + 0.020, z_band), tile=(0.10, 0.10)))
    return out


def blade_mesh(name, length):
    """A fingerpost blade in its own local frame (x along the blade from the post face, z 0..145 mm): a tapered slab
    with a spear point, its printed face on -Y."""
    sec = rect8(FP_BLADE_T, FP_BLADE_H, 0.0025)
    zs = [(0.0, 1.0), (0.020, 1.0), (length - 0.100, 1.0), (length - 0.068, 0.74), (length - 0.030, 0.38),
          (length, 0.03)]
    rings = [[(u, a * k, FP_BLADE_H / 2.0 + b * k) for a, b in sec] for u, k in zs]
    bm = tube(rings, cap_start=True, cap_end=True)
    return uv_face(bm, name, length, FP_BLADE_H, -FP_BLADE_T / 2.0, rest="paint")


def square_post(cx, cy, size, h, finial, u_off=0.0):
    """The fingerpost's sawn 110 mm post: chamfered arrises, a rain-shedding chamfer at the top and a small finial."""
    sec = kit.rounded_rect(size, size, 0.008, 1)
    stations = [(0.0, 1.0), (2.280, 1.0), (2.310, 0.972), (h, 0.935), (h + 0.042, 0.42), (h + finial, 0.04)]
    rings = []
    for z, k in stations:
        rings.append([(cx + a * k, cy + b * k, z) for a, b in sec])
    bm = tube(rings, cap_start=True, cap_end=True)
    uv_trim(bm, "paint", u_off)
    return bm


# ---------------------------------------------------------------------------------------------------- the five signs
def fingerpost(x0):
    """The painted timber fingerpost: post, four pointed blades on band clips, blades bolted through the clip tongue."""
    out, col, att = [], [], []
    out.append(square_post(x0, 0.0, FP_POST, FP_H, FP_FIN))
    col.append(kit.box((FP_POST, FP_POST, FP_H + FP_FIN), (x0, 0.0, (FP_H + FP_FIN) / 2.0)))
    for i, (name, length, zb, bearing) in enumerate(FP_BLADES):
        ang = math.radians(bearing)
        d = Vector((math.cos(ang), math.sin(ang), 0.0))
        zc = zb + FP_BLADE_H / 2.0
        M = Matrix.Translation(Vector((x0, 0.0, zc)) + d * (FP_POST / 2.0)) @ Matrix.Rotation(ang, 4, "Z")
        out.append(kit.transform(blade_mesh(name, length), M))
        out += band(x0, 0.0, zc, square=FP_POST, u_off=0.13 * i)
        tx0 = FP_POST / 2.0 + BAND_GAP + BAND_T + 0.001
        tx1 = max(fx for fx, _ in L.FIXINGS[name]) * length + 0.030
        tongue = kit.box((tx1 - tx0, 0.004, 0.036), ((tx0 + tx1) / 2.0, FP_BLADE_T / 2.0 + 0.002, FP_BLADE_H / 2.0),
                         bevel=0.0008)
        uv_piece(tongue, "clip", ((tx0 + tx1) / 2.0, FP_BLADE_T / 2.0 + 0.002, FP_BLADE_H / 2.0), tile=(0.40, 0.10))
        out.append(kit.transform(tongue, M))
        for fx, _fy in L.FIXINGS[name]:                       # head on the printed face, nut outside the tongue
            out.append(kit.transform(bolt_head(0.0), M @ Matrix.Translation((fx * length, -FP_BLADE_T / 2.0, FP_BLADE_H / 2.0))))
            out.append(kit.transform(bolt_head(0.0, 1.0, BOLT_R * 1.12, BOLT_H * 0.75),
                                     M @ Matrix.Translation((fx * length, FP_BLADE_T / 2.0 + 0.004, FP_BLADE_H / 2.0))))
        col.append(kit.transform(kit.box((length + 0.02, FP_BLADE_T + 0.010, FP_BLADE_H), (0, 0, 0)),
                                 M @ Matrix.Translation(((length + 0.02) / 2.0 + FP_POST / 2.0 - 0.01, 0.0, 0.0))))
    att = [("ATT_Fingerpost", (x0, 0.0, 0.0)), ("ATT_Read_Fingerpost", (x0 + 0.55, -0.020, 2.02))]
    return out, col, att


def tideboard(x0):
    """The Port Haven tide table board: two posts, the printed board on four band clips, three stiffening ribs."""
    out, col, att = [], [], []
    for sx in (-1, 1):
        px = x0 + sx * TB_POST_X
        out += steel_post(px, 0.0, TB_POST_H, u_off=0.07 * (sx + 1))
        col.append(kit.box((POST_D, POST_D, TB_POST_H), (px, 0.0, TB_POST_H / 2.0)))
        for zi, fy in enumerate(TB_ROWS):
            out += band(px, 0.0, TB_Z0 + fy * TB_H, u_off=0.05 * (sx + 1) + 0.13 * zi)
    out.append(plate("tideboard", rect_pts(TB_W, TB_H, 0.006), TB_W, TB_H, PLATE_T,
                     (x0 - TB_W / 2.0, PLATE_BACK - PLATE_T, TB_Z0)))
    col.append(kit.box((TB_W, 0.040, TB_H), (x0, PLATE_BACK + 0.012, TB_Z0 + TB_H / 2.0)))
    for fx, fy in L.FIXINGS["tideboard"]:
        out.append(kit.transform(bolt_head(0.0), Matrix.Translation((x0 - TB_W / 2.0 + fx * TB_W,
                                                                    PLATE_BACK - PLATE_T, TB_Z0 + fy * TB_H))))
    for sx in (-1, 0, 1):                                      # the board's stiffening frame, against the posts
        rib = kit.box((0.032, 0.0072, TB_H - 0.05), (x0 + sx * TB_POST_X, PLATE_BACK + 0.0036, TB_Z0 + TB_H / 2.0),
                      bevel=0.001)
        out.append(uv_piece(rib, "alu", (x0 + sx * TB_POST_X, PLATE_BACK + 0.0036, TB_Z0 + TB_H / 2.0), tile=L.PLATE_TILE_M))
    att = [("ATT_TideBoard", (x0, 0.0, 0.0)), ("ATT_Read_TideBoard", (x0, PLATE_BACK - PLATE_T, TB_Z0 + TB_H / 2.0))]
    return out, col, att


def launch(x0):
    """The slipway launch sign: the blue panel and its KEEP CLEAR plate under it, bolted to a tongue on each band."""
    out, col, att = [], [], []
    out += steel_post(x0, 0.0, LS_POST_H, u_off=0.31)
    col.append(kit.box((POST_D, POST_D, LS_POST_H), (x0, 0.0, LS_POST_H / 2.0)))
    y_main = PLATE_BACK - PLATE_T
    out.append(plate("launch", rect_pts(LS_W, LS_H, 0.008), LS_W, LS_H, PLATE_T, (x0 - LS_W / 2.0, y_main, LS_Z)))
    col.append(kit.box((LS_W, 0.032, LS_H), (x0, y_main + 0.016, LS_Z + LS_H / 2.0)))
    y_k = y_main - PLATE_T2
    out.append(plate("launchKeeper", rect_pts(LS_KW, LS_KH, 0.006), LS_KW, LS_KH, PLATE_T2,
                     (x0 - LS_KW / 2.0, y_k, LS_KZ)))
    col.append(kit.box((LS_KW, 0.020, LS_KH), (x0, y_k + 0.010, LS_KZ + LS_KH / 2.0)))
    for fx, fy in L.FIXINGS["launch"]:
        out.append(kit.transform(bolt_head(0.0), Matrix.Translation((x0 - LS_W / 2.0 + fx * LS_W, y_main,
                                                                    LS_Z + fy * LS_H))))
    for fx, fy in L.FIXINGS["launchKeeper"]:
        out.append(kit.transform(bolt_head(0.0, -1.0, BOLT_R * 0.9, BOLT_H * 0.75),
                                 Matrix.Translation((x0 - LS_KW / 2.0 + fx * LS_KW, y_k, LS_KZ + fy * LS_KH))))
    for fy in (0.78, 0.22):
        out += band(x0, 0.0, LS_Z + fy * LS_H, u_off=0.17 + 0.31 * fy)
    att = [("ATT_LaunchSign", (x0, 0.0, 0.0)), ("ATT_Read_LaunchSign", (x0, y_main, LS_Z + LS_H / 2.0))]
    return out, col, att


def carpark(x0):
    """The car park sign: the blue P plate and the HARBOUR CAR PARK plate bolted under it, on one post."""
    out, col, att = [], [], []
    out += steel_post(x0, 0.0, CP_POST_H, u_off=0.53)
    col.append(kit.box((POST_D, POST_D, CP_POST_H), (x0, 0.0, CP_POST_H / 2.0)))
    y_p = PLATE_BACK - PLATE_T
    out.append(plate("carpark", rect_pts(CP_W, CP_H, 0.008), CP_W, CP_H, PLATE_T, (x0 - CP_W / 2.0, y_p, CP_Z)))
    col.append(kit.box((CP_W, 0.032, CP_H), (x0, y_p + 0.016, CP_Z + CP_H / 2.0)))
    y_s = y_p - PLATE_T2
    out.append(plate("carparkPlate", rect_pts(CP_PW, CP_PH, 0.006), CP_PW, CP_PH, PLATE_T2,
                     (x0 - CP_PW / 2.0, y_s, CP_PZ)))
    col.append(kit.box((CP_PW, 0.020, CP_PH), (x0, y_s + 0.010, CP_PZ + CP_PH / 2.0)))
    for fx, fy in L.FIXINGS["carpark"]:
        out.append(kit.transform(bolt_head(0.0), Matrix.Translation((x0 - CP_W / 2.0 + fx * CP_W, y_p,
                                                                    CP_Z + fy * CP_H))))
    for fx, fy in L.FIXINGS["carparkPlate"]:
        out.append(kit.transform(bolt_head(0.0, -1.0, BOLT_R * 0.9, BOLT_H * 0.75),
                                 Matrix.Translation((x0 - CP_PW / 2.0 + fx * CP_PW, y_s, CP_PZ + fy * CP_PH))))
    for fy in (0.80, 0.20):
        out += band(x0, 0.0, CP_Z + fy * CP_H, u_off=0.29 + 0.33 * fy)
    att = [("ATT_CarPark", (x0, 0.0, 0.0)), ("ATT_Read_CarPark", (x0, y_p, CP_Z + CP_H / 2.0))]
    return out, col, att


def cliff(x0):
    """The cliff warning: the 900 mm triangle on one band clip, its CLIFF EDGE plate on a second, one stiffener."""
    out, col, att = [], [], []
    out += steel_post(x0, 0.0, CW_POST_H, u_off=0.77)
    col.append(kit.box((POST_D, POST_D, CW_POST_H), (x0, 0.0, CW_POST_H / 2.0)))
    y_t = PLATE_BACK - PLATE_T
    out.append(plate("cliff", tri_pts(CW_W, 0.020), CW_W, CW_H, PLATE_T, (x0 - CW_W / 2.0, y_t, CW_Z)))
    col.append(kit.box((CW_W * 0.62, 0.032, CW_H * 0.85), (x0, y_t + 0.016, CW_Z + CW_H * 0.45)))
    y_s = y_t - PLATE_T2
    out.append(plate("cliffPlate", rect_pts(CW_PW, CW_PH, 0.006), CW_PW, CW_PH, PLATE_T2,
                     (x0 - CW_PW / 2.0, y_s, CW_PZ)))
    col.append(kit.box((CW_PW, 0.020, CW_PH), (x0, y_s + 0.010, CW_PZ + CW_PH / 2.0)))
    rib = kit.box((0.030, 0.006, 0.360), (x0, PLATE_BACK + 0.003, CW_Z + 0.36), bevel=0.001)
    out.append(uv_piece(rib, "alu", (x0, PLATE_BACK + 0.003, CW_Z + 0.36), tile=L.PLATE_TILE_M))
    for fx, fy in L.FIXINGS["cliff"]:
        out.append(kit.transform(bolt_head(0.0), Matrix.Translation((x0 - CW_W / 2.0 + fx * CW_W, y_t,
                                                                    CW_Z + fy * CW_H))))
    for fx, fy in L.FIXINGS["cliffPlate"]:
        out.append(kit.transform(bolt_head(0.0), Matrix.Translation((x0 - CW_PW / 2.0 + fx * CW_PW, y_s,
                                                                    CW_PZ + fy * CW_PH))))
    out += band(x0, 0.0, CW_Z + L.FIXINGS["cliff"][0][1] * CW_H, u_off=0.61)
    out += band(x0, 0.0, CW_PZ + CW_PH / 2.0, u_off=0.05)
    att = [("ATT_CliffWarning", (x0, 0.0, 0.0)), ("ATT_Read_CliffWarning", (x0, y_t, CW_Z + CW_H / 2.0))]
    return out, col, att


SIGNS = (("Fingerpost", fingerpost), ("TideBoard", tideboard), ("LaunchSign", launch),
         ("CarPark", carpark), ("CliffWarning", cliff))


# ---------------------------------------------------------------------------------------------------- assembly
def material():
    """Preview material on the sign atlas (the turntable replaces it with the spec's maps from the texture folder)."""
    name = "MI_Sign_Main"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    for cand in (os.path.join(kit.TEX, "M_Road_Sign_Kit"),
                 os.path.join(kit.GAME, "build/prod/M_Road_Sign_Kit/textures/M_Road_Sign_Kit")):
        if os.path.isdir(cand):
            for kind, inp, colour in (("ALB", "Base Color", True), ("RGH", "Roughness", False), ("MET", "Metallic", False)):
                p = os.path.join(cand, "%s_%s.png" % (STEM, kind))
                if not os.path.exists(p):
                    continue
                n = nt.nodes.new("ShaderNodeTexImage")
                n.image = bpy.data.images.load(p, check_existing=True)
                if not colour:
                    n.image.colorspace_settings.name = "Non-Color"
                nt.links.new(n.outputs["Color"], bsdf.inputs[inp])
            break
    return mat


STEM = "T_Sign_Main"


def geometry():
    """Every sign as its own mesh on the shared atlas: (parts by name, collision proxies, ATT_* empties)."""
    parts, cols, att = {}, [], []
    for k, (name, fn) in enumerate(SIGNS):
        out, col, ents = fn(k * GRID)
        p = kit.Part("M_Road_Sign_%s_LOD0" % name)
        for bm in out:
            p.add(bm)
        parts[name] = p.finish(material(), sharp_deg=40.0)
        cols.append(kit.col_object("M_Road_Sign_%s_COL" % name, col))
        for att_name, loc in ents:
            att.append(kit.empty(att_name, loc))
    return parts, cols, att


def uv_area_rows(spec, report):
    """(info) the UV area each LOD keeps and how it splits over the atlas regions: the printed faces hold their rect
    exactly, so a reader can see that what a LOD drops is its band clips, bolt heads and round post segments."""
    import uvlayout
    for e in spec["meshes"]:
        if e.get("role") != "visual":
            continue
        s = e.get("uv") or uvlayout.mesh_stats(e["object"].data)
        report.add(e["object"].name, "UV area", True, "%.4f of the sheet, %d faces, %.2f m2 of surface, bounds "
                   "u %.4f..%.4f v %.4f..%.4f" % (s["uv_area"], s["faces"], s["area3d"], s["min"][0], s["max"][0],
                                                  s["min"][1], s["max"][1]), info=True)
        if e.get("lod") in (None, "LOD0", "LOD2"):
            faces, _areas = uvlayout.mesh_faces(e["object"].data)
            buckets = {}
            for f in faces:
                u = sum(p[0] for p in f) / len(f)
                v = sum(p[1] for p in f) / len(f)
                name = "base"
                for key in L.TRIMS:
                    r = L.region_rect(key)
                    if r[0] <= u <= r[2] and r[1] <= v <= r[3]:
                        name = key
                        break
                else:
                    for key in ("cliff", "tideboard", "launch", "carpark", "carparkPlate", "cliffPlate",
                                "launchKeeper", "blade_a", "blade_b", "blade_c", "blade_d"):
                        r = L.face_rect(key)
                        if r[0] <= u <= r[2] and r[1] <= v <= r[3]:
                            name = "face:" + key
                            break
                buckets[name] = buckets.get(name, 0.0) + uvlayout.poly_area_2d(f)
            top = [kv for kv in sorted(buckets.items(), key=lambda kv: -kv[1]) if kv[1] > 1e-4][:7]
            report.add(e["object"].name, "UV area by region", True, ", ".join("%s %.4f" % kv for kv in top), info=True)


def build():
    parts, cols, att = geometry()
    return {
        "extra_checks": [uv_area_rows],
        "name": "M_Road_Sign_Kit",
        "budget": "large_prop",
        "tris": 7500,                    # docs/12 2.4 row: 300 to 1,500 per sign, five signs in the kit
        "tier": "standard",
        "dims_m": (None, None, CW_POST_H),   # X and Y free (the kit is a display line); Z = the tallest post
        "size_note": None,
        "origin": "free",                # every sign's post axis stands on the ground on the 4 m display grid
        "sets": [{"name": "Sign", "set": "Main", "size": 1024, "wet": True}],
        "meshes": [{"object": o, "set": "Main"} for o in parts.values()] + [{"object": c} for c in cols],
        "attachments": att,
        "tiling": True,

        "closeups": [
            {"name": "fingerpost_blades", "target": [0.62 * S, 0.0, 2.02 * S], "dist": 1.7 * S, "az": 14, "el": 8},
            {"name": "fingerpost_base", "target": [0.0, -0.10 * S, 0.20 * S], "dist": 1.2 * S, "az": 28, "el": 12},
            {"name": "tideboard_face", "target": [4.0 * S, -0.10 * S, 1.42 * S], "dist": 1.8 * S, "az": 5, "el": 4},
            {"name": "launch_face", "target": [8.0 * S, -0.09 * S, 1.93 * S], "dist": 1.7 * S, "az": 8, "el": 6},
            {"name": "carpark_face", "target": [12.0 * S, -0.09 * S, 2.10 * S], "dist": 1.7 * S, "az": 8, "el": 6},
            {"name": "cliff_triangle", "target": [16.0 * S, -0.08 * S, 1.84 * S], "dist": 1.9 * S, "az": 8, "el": 7},
        ],
    }
