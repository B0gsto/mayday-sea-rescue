"""R2 M_Road_CornishHedge (docs/12 2.4, Haven Head road): a Cornish hedge - a stone-faced earth bank - one 5 m
modular section that tiles end to end.

    python3 art/source/roads/M_Road_CornishHedge/hedgetex.py     (the trim set, once; system python3)
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/roads/M_Road_CornishHedge/build.py \
        --out-root build/prod/M_Road_CornishHedge --steps build,lod,validate,export,turntable

Real sizes (art/reference/M_Road_CornishHedge/dims.md: 1.2 to 1.8 m high, base about equal to the height, top about
half the base, concave batter): 1.23 m of faced stone under a turf cap whose crest is 1.44 m, the base 1.48 m wide,
the turf top 0.80 m; gorse and grass take the piece to about 1.66 m. The faces are battered (half-width 0.63 m at the
foot to 0.30 m at the top, a concave `^0.85` profile) and faced with real 3D granite chunks laid on edge in curzyway
courses: each stone is a bevelled block sunk into the bank, its outline and dome jittered, tilted in the face, and
standing 25 to 55 mm proud so the tight joints read as dark shadow over the earth core.

The section tiles: the stone rows stop short of the cut planes and each end carries corner stones on the cut face, so
two pieces butt into a joint line of stone ends and a recessed earth section the way two panels of a real hedge meet.
ATT_Snap_Start / ATT_Snap_End sit on the cut planes at both ends (local -Y pointing out of the piece), ATT_Base on the
ground at the centre - the origin is the centre of the base, so a run stays symmetrical.

Two sets: `T_CornishHedge_Stone_*` (own trim set, layout.py - granite bed, earth core, turf) on the solid mesh, and the
shared `T_FoliageLand_Main` atlas on the alpha-cut vegetation card mesh (cards.py), a separate MeshPart so it can carry
the cutout SurfaceAppearance while the stones stay opaque and cast shadows.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROADS = os.path.dirname(HERE)
sys.path.insert(0, ROADS)
sys.path.insert(0, HERE)
import cards as C  # noqa: E402
import kit  # noqa: E402
import layout as L  # noqa: E402

S = kit.S

# ---------------------------------------------------------------------------------------------------- real sizes (m)
L_MOD = 5.00          # module length between the cut planes
STONE_TOP = 1.23      # top of the facing stonework
A0 = 0.630            # core half-width at the ground (base 1.26 m of earth, 1.38 m over the stones)
A1 = 0.300            # core half-width at STONE_TOP
P_BATTER = 0.85       # concave batter (dims.md: "concave batter", verify)
H_CORE = 1.20         # top of the earth face behind the top stone course
A_LIP = 0.400         # turf lip outer edge: it overhangs the stones by about 70 mm
Z_LIP = 1.335         # height of the lip's outer edge
A_DOME = 0.360        # half-width of the turf crest
Z_DOME = 1.440        # turf crest height
DOME_DROP = 0.040     # the crest falls this much from the centre to the lip
STONE_BACK = 0.090    # how deep a facing stone is bedded into the earth core
END_MARGIN = 0.020    # stone rows run almost to the cut planes; the cut face carries a stone quoin
TOP_Z = 1.62          # ceiling for the vegetation, so the piece keeps its 1.2 to 1.8 m band
Z_MIN = 0.004         # nothing below the ground plane

CORE_STATIONS = 23
CELLS_FLOWER = ("ThriftHeads", "BellHeather", "Ling")


# ---------------------------------------------------------------------------------------------------- the bank profile
def clamp_z(z):
    return min(max(z, 0.03), STONE_TOP)


def batter(z):
    """Core half-width at height z (the design face the stones are bedded into), concave. (m)"""
    t = min(max(z / STONE_TOP, 0.0), 1.0)
    return A0 + (A1 - A0) * t ** P_BATTER


def slope(z):
    """d(half-width)/dz of the design face."""
    t = min(max(z / STONE_TOP, 0.0), 1.0)
    return (A1 - A0) * P_BATTER * t ** (P_BATTER - 1.0) / STONE_TOP


def face_point(s, x, z, out=0.0):
    """A point on the design face of side s (+1 = +Y, -1 = -Y), pushed `out` along the outward normal."""
    k = slope(clamp_z(z))
    n = Vector((0.0, s, -k)).normalized()
    return Vector((x, s * batter(z), z)) + n * out


def face_frame(s, z):
    """(along-wall, up-the-face, outward normal) at height z: the tangents of a battered ruled surface."""
    k = slope(clamp_z(z))
    n = Vector((0.0, s, -k)).normalized()
    up = Vector((0.0, s * k, 1.0)).normalized()
    return Vector((1.0, 0.0, 0.0)), up, n


def dome_z(y):
    return Z_DOME - DOME_DROP * (min(abs(y), A_DOME) / A_DOME) ** 2


def lip_at(x):
    """The turf lip's outer edge at x: turf clumps of different sizes hang out and down in an uneven run."""
    return A_LIP + 0.030 * math.sin(2.1 * x + 0.6) + 0.017 * math.sin(5.7 * x + 2.1) \
        + 0.009 * math.sin(11.3 * x + 0.7)


def lip_z(x):
    """Underside of the overhang: clumps droop 0 to 40 mm below the mean lip line."""
    return Z_LIP + 0.020 * math.sin(1.7 * x + 1.7) + 0.013 * math.sin(6.1 * x + 0.3)


def core_section(x):
    """(y, z) of the right half of the core at x, ground up the face to the crest, the lip scalloped by x."""
    lip, zl = lip_at(x), lip_z(x)
    pts = [(A0, 0.0)]
    for z in (0.18, 0.48, 0.78, 1.02, H_CORE):
        pts.append((batter(z), z))
    pts += [(0.330, 1.265), (lip, zl - 0.010), (lip + 0.020, zl + 0.014),
            (0.330, zl + 0.060), (0.245, Z_DOME - 0.022), (0.120, Z_DOME - 0.006),
            (0.0, Z_DOME + 0.002)]
    return pts


# ---------------------------------------------------------------------------------------------------- facing stones
def strip_uv(bm, faces, rect, spans, ju, jv):
    """Trim-strip UVs: U = (world X + ju) wrapped every span, V = (world Z + jv) up the wall; both clamped inside."""
    u0, v0, u1, v1 = rect
    su, sv = spans
    uvl = bm.loops.layers.uv.verify()
    for f in faces:
        for lp in f.loops:
            co = lp.vert.co
            u = ((co.x + ju) / su) % 1.0
            v = min(max((co.z + jv) / sv, 0.004), 0.996)
            lp[uvl].uv = (u0 + u * (u1 - u0), v0 + v * (v1 - v0))
    return faces


def chunk(bm, origin, e1, e2, n, rng, lx, ly, proj, depth, tilt_deg, off, rect, spans, dome=None):
    """One weathered granite block set into the bank: a 5 to 6 sided squircle outline in the face plane, an outer
    rim `proj` proud of the design face, a domed cap stepped back and up again so the edge reads rounded, sides
    sloping into the earth core, the back left open inside the bank. 23 to 28 triangles. UVs are world projections
    with a per-stone offset, V kept near the stone's real height so the foot of the wall takes the damp staining of
    the trim set."""
    th = math.radians(tilt_deg)
    d1 = e1 * math.cos(th) + e2 * math.sin(th)
    d2 = -e1 * math.sin(th) + e2 * math.cos(th)
    sides = rng.choice((5, 5, 6, 6))
    p = rng.uniform(2.6, 4.4)                      # squircle exponent: blocky with rounded corners
    ring = []
    for i in range(sides):
        a = math.pi * 0.5 + 2.0 * math.pi * i / sides + rng.uniform(-0.10, 0.10)
        c, s = math.cos(a), math.sin(a)
        ex = math.copysign(abs(c) ** (2.0 / p), c) * lx * rng.uniform(0.96, 1.02)
        ey = math.copysign(abs(s) ** (2.0 / p), s) * ly * rng.uniform(0.95, 1.02)
        ring.append(ex * d1 + ey * d2)
    def place(p):
        p.z = max(p.z, Z_MIN)                      # a stone found below the ground is cut flat at its foot
        p.x = min(max(p.x, -L_MOD / 2 + 0.004), L_MOD / 2 - 0.004)   # cut flat at the module joint
        return p
    if dome is None:
        dome = rng.uniform(0.005, 0.010)
    outer = [bm.verts.new(place(origin + r * rng.uniform(0.985, 1.015)
                                + n * (proj + rng.uniform(-0.003, 0.004)))) for r in ring]
    inner = [bm.verts.new(place(origin + r * rng.uniform(0.90, 0.95)
                                + n * (proj + dome * rng.uniform(0.55, 1.45)
                                       + rng.uniform(-0.006, 0.006)))) for r in ring]
    back = [bm.verts.new(place(origin + r * 0.98 - n * depth)) for r in ring]
    bm.faces.new(inner)                                  # domed split face, its uneven rim bevels into the sides
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((outer[i], outer[j], inner[j], inner[i]))
        bm.faces.new((back[i], back[j], outer[j], outer[i]))
    faces = bm.faces[:]
    for f in faces:
        f.normal_update()
        if (f.calc_center_median() - origin).dot(f.normal) < 0.0:
            f.normal_flip()
    # ---- UVs: a box projection of the stone's own surface with a per-stone U offset
    u0, v0, u1, v1 = rect
    su, sv = spans
    uvl = bm.loops.layers.uv.verify()
    uc = (origin.x / su + off[0]) % 1.0                    # one U centre per stone: the face never wraps the atlas
    for f in faces:
        ax = max(range(3), key=lambda i: abs(f.normal[i]))
        for lp in f.loops:
            co = lp.vert.co
            if ax == 1:
                u, v = uc + (co.x - origin.x) / su, co.z / sv
            elif ax == 0:
                u, v = uc + (co.y - origin.y) / su, co.z / sv
            else:
                u, v = uc + (co.x - origin.x) / su, 0.5 + co.y / su * 0.5
            lp[uvl].uv = (u0 + min(max(u, 0.0), 1.0) * (u1 - u0),
                          v0 + min(max(v, 0.004), 0.996) * (v1 - v0))
    # a face whose normal is nearly parallel to the projection plane can collapse in UV: give it a local patch
    uvl = bm.loops.layers.uv.verify()
    for f in faces:
        pts = [lp[uvl].uv for lp in f.loops]
        area = abs(sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y
                       for i in range(len(pts)))) * 0.5
        if area > 1e-9:
            continue
        c = f.calc_center_median()
        t = f.normal.cross(Vector((0.0, 0.0, 1.0)))
        if t.length < 1e-4:
            t = f.normal.cross(Vector((1.0, 0.0, 0.0)))
        t.normalize()
        b = f.normal.cross(t).normalized()
        for lp in f.loops:
            d = lp.vert.co - c
            lp[uvl].uv = (u0 + (0.45 + 0.20 * d.dot(t) / su) * (u1 - u0),
                          v0 + (0.50 + 0.20 * d.dot(b) / sv) * (v1 - v0))
    return faces


def stone_row(bm, side, rng, zc, h, n, tilt, rect, spans, lx, ly, proj):
    """One course of a face: n stones centred on an even pitch, nearly touching, all leaning together by `tilt`
    degrees so alternating courses build the curzyway chevrons."""
    x0, x1 = -L_MOD / 2 + END_MARGIN, L_MOD / 2 - END_MARGIN
    pitch = (x1 - x0) / n
    for i in range(n):
        xc = x0 + (i + 0.5) * pitch
        chunk(bm, face_point(side, xc, zc), *face_frame(side, zc), rng,
              lx * rng.uniform(0.96, 1.03), ly * rng.uniform(0.94, 1.03), proj,
              rng.uniform(0.10, 0.15), tilt + rng.uniform(-2.5, 2.5),
              (rng.random(), 0.0), rect, spans)
    return bm


def end_stones(bm, rng, rect, spans):
    """Both cut ends: stacked quoin stones run in from each corner for the full height over almost the whole face,
    meeting at a narrow earth strip in the centre. Nothing crosses the cut plane, so two modules butt cleanly."""
    gap = 0.040                                          # half the earth strip left showing in the middle
    rows = ((0.105, 0.085), (0.300, 0.090), (0.505, 0.092), (0.710, 0.092),
            (0.925, 0.092), (1.140, 0.072))
    for ex in (-1, 1):
        for side in (-1, 1):
            for zc, ly in rows:
                half = batter(zc)
                lo = side * (gap + 0.004)
                hi = side * (half - 0.012)
                yc = (lo + hi) * 0.5
                chunk(bm, Vector((ex * (L_MOD / 2 - 0.017), yc, zc)),
                      Vector((0.0, 1.0, 0.0)), Vector((0.0, 0.0, 1.0)), Vector((ex, 0.0, 0.0)), rng,
                      abs(hi - lo) * 0.5, ly, rng.uniform(0.012, 0.015),
                      rng.uniform(0.10, 0.14), rng.uniform(-2.5, 2.5),
                      (rng.random(), 0.0), rect, spans, dome=rng.uniform(0.006, 0.008))
    return bm


def stones_bm():
    """Both faces: a base course of big flat slabs, two curzyway courses of long stones set on edge and leaning
    alternately, a coping row under the turf lip, and the stacked quoins on both cut ends."""
    bm = bmesh.new()
    rect, spans = L.region_rect("stone"), L.span_m("stone")
    x0, x1 = -L_MOD / 2 + END_MARGIN, L_MOD / 2 - END_MARGIN
    span = x1 - x0
    for side in (-1, 1):
        rng = random.Random(4100 + side)
        # base: big flattish stones bedded level, about 1 cm joints
        n_b = 14
        pitch = span / n_b
        stone_row(bm, side, rng, 0.108, 0.20, n_b, rng.uniform(-4.0, 4.0), rect, spans,
                  pitch * 0.470, 0.095, rng.uniform(0.030, 0.048))
        # curzyway: long thin stones on edge, tilted 42 degrees, the lean alternating course by course
        for ci, zc in enumerate((0.400, 0.800)):
            n = 20
            pitch = span / n
            lx = (pitch * math.cos(math.radians(42.0)) - 0.011) * 0.5
            stone_row(bm, side, rng, zc, 0.40, n, 42.0 if ci == 0 else -42.0, rect, spans,
                      lx * 1.04, 0.275, rng.uniform(0.022, 0.050) * (1.0 + 0.30 * (1.0 - zc / STONE_TOP)))
        # coping: flatter, wider stones tucked under the turf overhang
        n_c = 15
        pitch = span / n_c
        stone_row(bm, side, rng, 1.105, 0.17, n_c, rng.uniform(-4.0, 4.0), rect, spans,
                  pitch * 0.472, 0.085, rng.uniform(0.032, 0.055))
    end_stones(bm, random.Random(4200), rect, spans)
    return bm


# ---------------------------------------------------------------------------------------------------- core and turf
def turf_clumps(bm, rng):
    """Lumpy turf pads hanging over the lip at uneven intervals, so the cap edge breaks into clumps instead of a
    swept band."""
    for side in (-1, 1):
        for xc in (-1.95, -1.15, -0.35, 0.45, 1.25, 1.95):
            xc += rng.uniform(-0.13, 0.13)
            rx, ry = rng.uniform(0.15, 0.25), rng.uniform(0.060, 0.095)
            lip, zl = lip_at(xc), lip_z(xc)
            z0 = zl - rng.uniform(0.050, 0.085)
            y0 = lip + rng.uniform(0.015, 0.045)
            low, high = [], []
            for k in range(5):
                a = 2.0 * math.pi * k / 5.0 + rng.uniform(-0.18, 0.18)
                ex, ey = math.cos(a) * rx * rng.uniform(0.80, 1.0), math.sin(a) * ry * rng.uniform(0.80, 1.0)
                low.append(bm.verts.new((xc + ex, side * (y0 + ey), z0 - rng.uniform(0.0, 0.020))))
                high.append(bm.verts.new((xc + ex * 0.70, side * (lip - 0.020 + ey * 0.45),
                                          zl + rng.uniform(0.012, 0.040))))
            for k in range(5):
                j = (k + 1) % 5
                bm.faces.new((low[k], low[j], high[j], high[k]))
            bm.faces.new(high)
            bm.faces.new(list(reversed(low)))
    return bm


def core_bm():
    """The earth bank: the battered section swept along the module, the turf lip scalloped station by station and the
    crest wobbling like a laid turf cap, both cut planes closed. Faces below the lip take the earth region, the lip
    and crest take turf."""
    rect_e, spans_e = L.region_rect("earth"), L.span_m("earth")
    rect_t, spans_t = L.region_rect("turf"), L.span_m("turf")
    bm = bmesh.new()
    rings = []
    for i in range(CORE_STATIONS):
        x = -L_MOD / 2 + L_MOD * i / (CORE_STATIONS - 1.0)
        rights = core_section(x)
        loop = [(-y, z) for (y, z) in rights] + [(y, z) for (y, z) in reversed(rights[:-1])]
        dz = 0.011 * math.sin(3.3 * x + 0.5) + 0.006 * math.sin(7.7 * x + 2.2)
        end = i == 0 or i == CORE_STATIONS - 1
        ring = []
        for k, (y, z) in enumerate(loop):
            if z > H_CORE - 0.02:                      # turf crest: clumps of turf, not a swept slab
                z += dz + 0.005 * math.sin(4.7 * x + 1.3 * k + 0.6)
                y += 0.006 * math.sin(2.3 * x + 0.9 * k) + 0.003 * math.sin(5.9 * x + 0.7 * k)
            xv = x - math.copysign(0.018, x) if end and z < 1.25 else x   # recess the earth cuts behind the quoins
            ring.append(bm.verts.new((xv, y, z)))
        rings.append(ring)
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    turf_clumps(bm, random.Random(4300))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        c = f.calc_center_median()
        rect, spans = (rect_t, spans_t) if c.z > H_CORE - 0.01 else (rect_e, spans_e)
        nrm = f.normal
        if abs(nrm.x) > max(abs(nrm.y), abs(nrm.z)):
            proj = "yz"                                # the cut faces (constant x) map across, or they get no UV area
        elif abs(nrm.z) > abs(nrm.y):
            proj = "xy"                                # the flat bottom and any up-facing face
        else:
            proj = "xz"
        u0, v0, u1, v1 = rect
        su, sv = spans
        for lp in f.loops:
            co = lp.vert.co
            if proj == "yz":
                u, v = (co.y + su * 0.5) / su, co.z / sv
            elif proj == "xy":
                u, v = (co.x / su) % 1.0, 0.5 + co.y / sv
            else:
                u, v = (co.x / su) % 1.0, co.z / sv
            lp[uvl].uv = (u0 + min(max(u, 0.0), 1.0) * (u1 - u0), v0 + min(max(v, 0.004), 0.996) * (v1 - v0))
    return bm


# ---------------------------------------------------------------------------------------------------- vegetation
def side_axis(up, rng):
    """A horizontal-ish side axis for a card: perpendicular to `up`, jittered so no two cards share a plane."""
    s = up.cross(Vector((rng.gauss(0, 0.35), rng.gauss(0, 0.35), 0.0)))
    if s.length < 0.05:
        s = up.cross(C.rand_dir_xy(rng))
    return s.normalized() if s.length > 1e-4 else Vector((1, 0, 0))


def vegetation(rng):
    """The hedge top: alpha-cut turf tufts, three gorse clumps in flower, thrift and heather heads, and grass growing
    out of the joints and over the lip (all cells from the shared land-foliage atlas, wind combed along +X)."""
    out = []
    # turf tufts over the whole crest, dense along the middle and the lips
    for _ in range(88):
        x = rng.uniform(-2.30, 2.30)
        y = rng.uniform(-0.34, 0.34)
        base = Vector((x, y, dome_z(y) - rng.uniform(0.020, 0.045)))
        out.append(C.lean_card(rng, base, Vector((0.0, math.copysign(rng.uniform(0.05, 0.32), y), 0.0)),
                               rng.uniform(0.28, 0.40), rng.uniform(0.17, 0.27),
                               "GrassTuft" if rng.random() < 0.8 else "Marram",
                               segs=rng.choice((1, 1, 2)), bend=rng.uniform(0.12, 0.32), normal="up"))
    # gorse: clumps in flower, dense cores with sprays poking out of them
    for cx, cy in ((-1.35, 0.04), (0.55, -0.06), (1.75, 0.05)):
        cx += rng.uniform(-0.22, 0.22)
        for _ in range(6):
            d = C.rand_dir_xy(rng) * rng.uniform(0.0, 0.24)
            base = Vector((cx + d.x, cy + d.y, dome_z(cy + d.y) - rng.uniform(0.035, 0.060)))
            up = (Vector((d.x * 1.4, d.y * 1.4, 1.0)) + Vector((0.6, 0, 0))).normalized()
            out.append(C.Card(base, up, side_axis(up, rng), rng.uniform(0.40, 0.54), rng.uniform(0.20, 0.30),
                              "GorseDense", segs=1, bend=rng.uniform(0.06, 0.16), normal="dome"))
        for _ in range(5):
            d = C.rand_dir_xy(rng) * rng.uniform(0.05, 0.28)
            base = Vector((cx + d.x, cy + d.y, dome_z(cy + d.y) - rng.uniform(0.020, 0.045)))
            up = (Vector((d.x * 0.9, d.y * 0.9, 1.0)) + Vector((0.8, 0, 0)) * rng.uniform(0.2, 0.6)).normalized()
            out.append(C.Card(base, up, side_axis(up, rng), rng.uniform(0.38, 0.52), rng.uniform(0.22, 0.32),
                              "GorseSprig", segs=2, bend=rng.uniform(0.12, 0.26), normal="dome"))
    # wildflowers: thrift heads, bell heather and ling in pockets along the top
    for i in range(18):
        cell = CELLS_FLOWER[i % 3]
        x = rng.uniform(-2.26, 2.26)
        y = rng.uniform(-0.27, 0.27)
        base = Vector((x, y, dome_z(y) - rng.uniform(0.012, 0.030)))
        up = (Vector((0, 0, 1)) + Vector((0.35, 0, 0)) * rng.uniform(0.1, 0.45)
              + Vector((0, math.copysign(rng.uniform(0.05, 0.30), y), 0))).normalized()
        w = rng.uniform(0.20, 0.30) if cell == "ThriftHeads" else rng.uniform(0.28, 0.40)
        h = rng.uniform(0.18, 0.30) if cell == "ThriftHeads" else rng.uniform(0.16, 0.26)
        out.append(C.Card(base, up, side_axis(up, rng), w, h, cell,
                          segs=2 if cell == "ThriftHeads" else 1, bend=rng.uniform(0.1, 0.3), normal="dome"))
    # grass and gorse growing out of the joints of the upper courses
    for i in range(13):
        side = -1 if i % 2 == 0 else 1
        z = rng.uniform(0.42, 1.14)
        base = face_point(side, rng.uniform(-2.24, 2.24), z, rng.uniform(0.03, 0.07))
        d = Vector((0.0, side, -0.35)).normalized()
        up = (d * rng.uniform(0.75, 1.0) + Vector((0, 0, 1)) * 0.25 + Vector((0.25, 0, 0))).normalized()
        out.append(C.Card(base, up, side_axis(up, rng), rng.uniform(0.18, 0.28), rng.uniform(0.14, 0.24),
                          "GrassTuft" if i % 3 else "GorseSprig", segs=1, bend=rng.uniform(0.2, 0.4), normal="dome"))
    # turf clumps spilling over the lip, so the overhang has a soft edge instead of a cut band
    for i in range(28):
        side = -1 if i % 2 == 0 else 1
        x = rng.uniform(-2.26, 2.26)
        ly, lz = lip_at(x), lip_z(x)
        y = side * (ly - rng.uniform(0.0, 0.03))
        base = Vector((x, y, lz - rng.uniform(0.010, 0.040)))
        d = Vector((0.0, side, -0.55)).normalized()
        up = (d * rng.uniform(0.85, 1.05) + Vector((0, 0, 1)) * 0.22 + Vector((0.3, 0, 0))).normalized()
        out.append(C.Card(base, up, side_axis(up, rng), rng.uniform(0.16, 0.26), rng.uniform(0.13, 0.21),
                          "GrassTuft" if i % 4 else "GorseSprig", segs=1, bend=rng.uniform(0.2, 0.45), normal="up"))
    # keep every card inside the module: the piece still snaps on its 5 m, and two pieces butt into one hedge
    xmax = L_MOD / 2 - 0.03
    ymax = 0.62
    for c in out:
        reach = abs(c.base.x) + abs(c.side.x) * c.w * 0.5 + c.h * c.bend * 0.9
        if reach > xmax:
            c.base.x = math.copysign(max(xmax - (reach - abs(c.base.x)), 0.0), c.base.x)
        yreach = abs(c.base.y) + abs(c.side.y) * c.w * 0.5 + abs(c.up.y) * c.h
        if yreach > ymax:
            c.base.y -= math.copysign(yreach - ymax, c.base.y)
    return [C.fit_card(c, TOP_Z) for c in out]


# ---------------------------------------------------------------------------------------------------- assembly
def material():
    """Preview material on the trim set (the turntable replaces it with the spec's maps)."""
    name = "MI_CornishHedge_Stone"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    for cand in (os.path.join(kit.TEX, "M_Road_CornishHedge"),
                 os.path.join(kit.GAME, "build/prod/M_Road_CornishHedge/textures/M_Road_CornishHedge")):
        if not os.path.isdir(cand):
            continue
        for kind, inp, colour in (("ALB", "Base Color", True), ("RGH", "Roughness", False), ("MET", "Metallic", False)):
            p = os.path.join(cand, "T_CornishHedge_Stone_%s.png" % kind)
            if not os.path.exists(p):
                continue
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(p, check_existing=True)
            if not colour:
                n.image.colorspace_settings.name = "Non-Color"
            nt.links.new(n.outputs["Color"], bsdf.inputs[inp])
        break
    return mat


def geometry():
    stone_part = kit.Part("M_Road_CornishHedge_Stone_LOD0")
    stone_part.add(stones_bm())
    stone_part.add(core_bm())
    veg = C.veg_object("M_Road_CornishHedge_Veg_LOD0", vegetation(random.Random(7501)), C.material())
    parts = {"Stone": stone_part.finish(material(), sharp_deg=28.0), "Veg": veg}
    col = kit.col_object("M_Road_CornishHedge_COL", [
        kit.box((L_MOD, 1.36, 1.44), (0.0, 0.0, 0.72), bevel=0.0),
    ])
    att = [kit.empty("ATT_Snap_Start", (-L_MOD / 2, 0, 0), (0, 0, math.radians(-90))),
           kit.empty("ATT_Snap_End", (L_MOD / 2, 0, 0), (0, 0, math.radians(90))),
           kit.empty("ATT_Base", (0, 0, 0))]
    return parts, col, att


def build():
    parts, col, att = geometry()
    return {
        "name": "M_Road_CornishHedge",
        "budget": "large_prop",
        "tris": 6000,                    # docs/12 2.4: 1,000 to 6,000 per 5 m piece
        "tier": "standard",
        "dims_m": (5.03, 1.33, 1.68),    # measured: module x width over the stones x turf crest with the gorse
        "size_note": None,
        "origin": "base",                # the centre of the base, so a run of pieces stays symmetrical
        "sets": [{"name": "CornishHedge", "set": "Stone", "size": 1024, "wet": True}, C.SET],
        "meshes": [{"object": parts["Stone"], "set": "Stone"}, {"object": parts["Veg"]},
                   {"object": col}],
        "attachments": att,
        "tiling": True,
        "waivers": {
            "LOD UV layout": "LODs are collapse decimations of stone shells and cards: the atlas layout matches but the "
                             "UV area sum moves, because chunk rims merge into faces and card windings weld at distance "
                             "- docs/12 2.5 waives this for the whole veg and rubble families.",
            "geometry": "the decimated LODs strand a few vertices where shells collapse; LOD0 is clean (0 loose verts) "
                        "and Roblox drops loose vertices on import.",
        },
        "closeups": [
            {"name": "curzyway", "target": [0.55 * S, -0.62 * S, 0.55 * S], "dist": 1.6 * S, "az": -14, "el": 8},
            {"name": "stone_corner", "target": [1.2 * S, -0.58 * S, 0.35 * S], "dist": 1.4 * S, "az": 12, "el": 12},
            {"name": "end_cut", "target": [2.48 * S, -0.18 * S, 0.62 * S], "dist": 1.5 * S, "az": 62, "el": 10},
            {"name": "turf_edge", "target": [-1.1 * S, -0.34 * S, 1.38 * S], "dist": 1.5 * S, "az": 8, "el": 14},
            {"name": "overhang", "target": [0.9 * S, -0.34 * S, 1.34 * S], "dist": 1.3 * S, "az": -6, "el": -14},
            {"name": "gorse", "target": [0.55 * S, 0.0, 1.46 * S], "dist": 1.9 * S, "az": 34, "el": 22},
        ],
    }
