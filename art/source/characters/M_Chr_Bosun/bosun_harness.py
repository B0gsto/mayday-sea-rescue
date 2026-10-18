"""Bosun harness (CH6 redo): harness_mesh(body_me) -> bpy mesh in build metres (front -Y, Z up), fitted to the body
passed in by ray casts against it (so it follows any body reshape), with HANDLE_APEX / DRING_POS set (build metres;
bosun.harness_mesh copies them back into bosun).

A Hull Orange water-rescue harness (docs/05 8.3; grab handle, retroreflective tape, no cross):
  padded saddle      quilted pad with a rolled webbing binding, stitch row inside the binding, tape strip each side
  girth strap        48 mm webbing behind the elbows, side-release buckle on the left, tri-glide + doubled tail right
  chest strap        48 mm webbing across the chest, tape across the front, buckle on the right, tri-glide left
  grab handle        40 mm webbing loop with a neoprene grip sleeve, feet stitched flat to the saddle (box-X tacks)
  tow D-ring         welded stainless D (8.4 mm wire, weld bead) on a 25 mm webbing tab at the rear of the saddle
Webbing is a real solid (5.5 mm, exaggerated for 2 m reads: rolled edges, crowned face, 0.9 mm stitch channels 4 mm
in from each edge); buckles and tri-glides are scaled up (BK) so they read as chunky parts at game distance.
Fit: straps are cast round the body, then conform() tilts each section to the body's slope under the webbing and
seats its lowest point STRAP_OFF above the skin (the compressed coat; see the note at SAD_OFF), so the straps hug
whatever body shape is passed in. INNER maps label -> body-side vertex indices (for fit checks, not exported).

Per-vertex 0..1 float attributes (POINT domain) for bake_bosun.harness_graph:
  tape     retroreflective tape        metal    stainless D-ring          plastic  black acetal buckles / tri-glides
  grip     neoprene handle sleeve      stitch   stitch rows and box-X tacks (1 on the thread line; shade with a
  edge     webbing / binding edge (wear, fray; 1 on the edge, 0.5 on the corners)     narrow threshold, ~>0.8)
  padding  padded saddle fabric        buckle   buckle and adjuster parts (same as plastic; kept separate for wear)
"""
from bosun import *  # noqa: F401,F403  (helpers: bvh_of, mesh_arrays, vertex_normals, set_attr, ...)
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.interpolate import poly_3d_calc

HANDLE_APEX = DRING_POS = None
INNER = {}                            # label -> harness vertex indices on the body-facing face (fit checks only)
MM = 0.001
ATTRS = ("tape", "metal", "plastic", "grip", "stitch", "edge", "padding", "buckle", "along", "across")  # r5: weave coords (m)

# layout (build metres; same anchors as the first harness, everything else is cast onto the body)
SAD_Y0, SAD_Y1 = -0.22, 0.06          # saddle front / rear edge along the spine
SAD_THETA = 1.20                      # saddle drape down each side (rad from the top)
# Coat: fur_cards keeps card roots 30-40 mm off the harness, so beside a strap the visible coat is the inner layer
# (tufts 5-9 mm above the skin) with the outer back / flank cards (12-20 mm) leaning in over it. The harness bears on
# that compressed coat: inner faces at ~9-10 mm, tops at ~15 mm, so the outer coat bulges round the webbing edges.
SAD_OFF = 0.010                       # saddle underside above the body surface (coat)
STRAP_OFF = 0.009                     # strap inner face above the body surface (lowest point across the width)
GIRTH_Y = -0.105                      # girth strap plane, behind the elbows
STEP = 0.05                           # strap ring spacing along the path (m)
WEB_T = 5.5 * MM                      # webbing thickness (real 3-5 mm, exaggerated so the edge reads at 2 m)
WEB_W = 48 * MM                       # girth / chest webbing width
BK = 1.2                              # buckle / tri-glide scale along the strap and in thickness (chunky at 2 m)
PLASTIC = dict(plastic=1.0, buckle=1.0)


# ------------------------------------------------------------------ geometry container

class Piece:
    def __init__(self):
        self.V, self.F, self.A, self.ref, self.inner, self.name = [], [], [], [], [], None

    def v(self, co, a=None):
        self.V.append(Vector(co))
        self.A.append(a or {})
        return len(self.V) - 1

    def f(self, *idx, out=None):
        self.F.append(tuple(idx))
        if out is not None:
            self.ref.append((len(self.F) - 1, Vector(out)))


def newell(pts):
    n = Vector((0, 0, 0))
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    return n


class Geo:
    def __init__(self):
        self.V, self.F, self.A, self.tris, self.ranges = [], [], [], {}, []

    def commit(self, pc, label):
        """Closed pieces (no ref faces) are oriented by signed volume, open ones by their reference out vectors."""
        if pc.ref:
            s = sum(newell([pc.V[i] for i in pc.F[fi]]).dot(o) for fi, o in pc.ref)
        else:
            s = sum(pc.V[f[0]].dot(pc.V[f[k]].cross(pc.V[f[k + 1]])) for f in pc.F for k in range(1, len(f) - 1))
        faces = pc.F if s >= 0 else [tuple(reversed(f)) for f in pc.F]
        base = len(self.V)
        self.ranges.append((label, base, base + len(pc.V)))
        self.V += pc.V
        self.A += pc.A
        self.F += [tuple(i + base for i in f) for f in faces]
        INNER.setdefault(pc.name or label, []).extend(i + base for i in pc.inner)
        self.tris[label] = self.tris.get(label, 0) + sum(len(f) - 2 for f in faces)


def sweep(pc, frames, prof, attrs, cap=True, loop=False):
    """frames: (o, t, b, n); ring vertex = o + b*w + n*h for (w, h) in prof; attrs: per profile vertex dict."""
    s = np.concatenate([[0.0], np.cumsum([np.linalg.norm(frames[i + 1][0] - frames[i][0]) for i in range(len(frames) - 1)])])
    rings = [[pc.v(o + b * w + n * h, dict(attrs[k] or {}, along=float(s[i]), across=float(w)))   # r5: webbing weave coords
              for k, (w, h) in enumerate(prof)] for i, (o, t, b, n) in enumerate(frames)]
    m = len(prof)
    for i in range(len(rings) if loop else len(rings) - 1):
        a, c = rings[i], rings[(i + 1) % len(rings)]
        for k in range(m):
            pc.f(a[k], a[(k + 1) % m], c[(k + 1) % m], c[k])
    if cap and not loop:
        pc.f(*reversed(rings[0]))
        pc.f(*rings[-1])
    return rings


def path_frames(P, N):
    out = []
    for i in range(len(P)):
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        n = (N[i] - t * N[i].dot(t)).normalized()
        out.append((P[i], t, n.cross(t).normalized(), n))
    return out


def resample(P, N, step, extra=None):
    """Uniform arc-length resample of a polyline with normals (and an optional scalar per point)."""
    L = [0.0]
    for a, b in zip(P, P[1:]):
        L.append(L[-1] + (b - a).length)
    cnt = max(2, int(round(L[-1] / step)) + 1)
    outP, outN, outE, j = [], [], [], 0
    for k in range(cnt):
        s = L[-1] * k / (cnt - 1)
        while j < len(L) - 2 and L[j + 1] < s:
            j += 1
        u = (s - L[j]) / max(L[j + 1] - L[j], 1e-9)
        outP.append(P[j].lerp(P[j + 1], u))
        outN.append(N[j].lerp(N[j + 1], u).normalized())
        if extra is not None:
            outE.append(extra[j] + (extra[j + 1] - extra[j]) * u)
    return outP, outN, outE, L[-1]


def web_top(W, T=WEB_T):
    """Top (outer) half of the webbing section, left to right: rolled edge, stitch channel 4 mm in, crowned middle."""
    return [(-W / 2, 0.30 * T), (-W / 2 + 0.25 * MM, 0.78 * T), (-W / 2 + 1.7 * MM, T), (-W / 2 + 4 * MM, T - 0.9 * MM),
            (0, T + 0.5 * MM), (W / 2 - 4 * MM, T - 0.9 * MM), (W / 2 - 1.7 * MM, T), (W / 2 - 0.25 * MM, 0.78 * T),
            (W / 2, 0.30 * T)]


def web_h(x, W, T=WEB_T):
    """Height of the webbing's outer face at lateral offset x (for tape and tacks laid on the crown)."""
    top = web_top(W, T)[2:-2]
    xs, hs = [p[0] for p in top], [p[1] for p in top]
    return float(np.interp(x, xs, hs))


def web_profile(W, T=WEB_T):
    """11-vertex webbing section: flat underside (vertices 0, 1: the body side), rolled edges that catch the light,
    a stitch channel 4 mm in from each edge (0.9 mm deep) and a crowned middle."""
    c = 1.2 * MM
    prof = [(-W / 2 + c, 0), (W / 2 - c, 0)] + list(reversed(web_top(W, T)))
    attrs = [dict(edge=.5), dict(edge=.5), dict(edge=1.), dict(edge=1.), dict(edge=.5), dict(stitch=1.), {},
             dict(stitch=1.), dict(edge=.5), dict(edge=1.), dict(edge=1.)]
    return prof, attrs


def loop_section(wy, hz, ch):
    """8-vertex chamfered rectangle (y, z) centred at 0."""
    a, b = wy / 2, hz / 2
    return [(a - ch, -b), (a, -b + ch), (a, b - ch), (a - ch, b), (-a + ch, b), (-a, b - ch), (-a, -b + ch), (-a + ch, -b)]


# ------------------------------------------------------------------ main

def harness_mesh(body_me):
    global HANDLE_APEX, DRING_POS
    INNER.clear()
    tree = bvh_of(body_me)
    Vb = mesh_arrays(body_me)
    Nb = vertex_normals(body_me)
    polys = [p.vertices[:] for p in body_me.polygons]
    G = Geo()

    def cast(origin, direction):
        loc, _, fi, _ = tree.ray_cast(Vector(origin), Vector(direction).normalized())
        if loc is None:
            return None, None
        ids = polys[fi]
        w = poly_3d_calc([Vector(Vb[i]) for i in ids], loc)
        n = Vector(sum((Nb[i] * wi for i, wi in zip(ids, w)), np.zeros(3))).normalized()
        return loc, n

    def axis_z(y):
        top = cast((0, y, 3.0), (0, 0, -1))[0].z
        bot = cast((0, y, -1.0), (0, 0, 1))[0].z
        return 0.5 * (top + bot)

    # ---------------- saddle: a (along the spine) x b (around the barrel) grid, squircle-rounded corners
    sad_yc, sad_hy = 0.5 * (SAD_Y0 + SAD_Y1), 0.5 * (SAD_Y1 - SAD_Y0)
    zc_cache = {}

    def saddle_surf(a, b):
        k = 0.55
        a2 = a * math.sqrt(max(1 - k * min(b * b, 1.2) / 2, 0.1))
        b2 = b * math.sqrt(max(1 - k * min(a * a, 1.2) / 2, 0.1))
        y = sad_yc + a2 * sad_hy * (1 - 0.14 * b2 * b2)
        th = b2 * SAD_THETA
        ky = round(y, 3)
        if ky not in zc_cache:
            zc_cache[ky] = axis_z(ky)
        d = Vector((math.sin(th), 0, math.cos(th)))
        c = Vector((0, y, zc_cache[ky]))
        loc, n = cast(c + d * 1.5, -d)
        return loc, n

    SEAM_A, SEAM_B = 0.085, 0.05            # binding width ~12 mm in param units

    def pad_h(a, b):
        e = max(abs(a), abs(b))
        if e >= 1 - 1e-6:
            return 6.8 * MM
        dome = 8.5 * MM + 6.5 * MM * (1 - abs(a) ** 4) * (1 - abs(b) ** 4)
        on_seam = abs(abs(a) - (1 - SEAM_A)) < 1e-6 or abs(abs(b) - (1 - SEAM_B)) < 1e-6
        return dome - (2.2 * MM if on_seam and abs(a) <= 1 - SEAM_A + 1e-6 and abs(b) <= 1 - SEAM_B + 1e-6 else 0)

    def saddle_top(a, b, extra=0.0):
        loc, n = saddle_surf(a, b)
        return loc + n * (SAD_OFF + pad_h(a, b) + extra), n

    def stations(seam, d, n_int):
        inner = list(np.linspace(-1 + seam + d, 1 - seam - d, n_int + 2))
        return [-1.0, -1 + seam] + inner + [1 - seam, 1.0]

    A_ST, B_ST = stations(SEAM_A, 0.022, 5), stations(SEAM_B, 0.014, 9)
    pc = Piece()
    grid = {}
    for i, a in enumerate(A_ST):
        for j, b in enumerate(B_ST):
            p, n = saddle_top(a, b)
            inside = abs(a) < 1 - SEAM_A - 1e-6 and abs(b) < 1 - SEAM_B - 1e-6
            boundary = abs(a) > 1 - 1e-6 or abs(b) > 1 - 1e-6
            on_seam = not inside and not boundary
            grid[i, j] = pc.v(p, dict(padding=1.0 if inside else 0.0, stitch=1.0 if on_seam else 0.0,
                                      edge=0.6 if boundary else 0.0))
            grid[i, j, "n"] = n
    for i in range(len(A_ST) - 1):
        for j in range(len(B_ST) - 1):
            pc.f(grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1], out=grid[i, j, "n"])
    # perimeter (counter-clockwise in index space) and the rolled binding rim beyond it
    ni, nj = len(A_ST) - 1, len(B_ST) - 1
    perim = [(i, 0) for i in range(ni)] + [(ni, j) for j in range(nj)] + \
            [(i, nj) for i in range(ni, 0, -1)] + [(0, j) for j in range(nj, 0, -1)]
    ea, eb = 6.0 * MM / sad_hy, 6.0 * MM / (SAD_THETA * 0.21)
    rims = [[grid[ij] for ij in perim]]
    for sa, h, at in ((0.75, 4.6 * MM, dict(edge=1.0)), (1.0, 1.6 * MM, dict(edge=1.0)), (-0.6, 0.0, dict(edge=0.5))):
        row = []
        for (i, j) in perim:
            a, b = A_ST[i], B_ST[j]
            a2 = a + math.copysign(ea * sa, a) if abs(a) > 1 - 1e-6 else a
            b2 = b + math.copysign(eb * sa, b) if abs(b) > 1 - 1e-6 else b
            loc, n = saddle_surf(a2, b2)
            row.append(pc.v(loc + n * (SAD_OFF + h), at))
        rims.append(row)
    pc.inner = list(rims[-1])
    for r0, r1 in zip(rims, rims[1:]):
        for m in range(len(perim)):
            m2 = (m + 1) % len(perim)
            pc.f(r0[m2], r0[m], r1[m], r1[m2])          # opposite winding to the grid's boundary edges
    G.commit(pc, "saddle")

    # saddle tape strips (25 mm) along each side
    for sb in (1, -1):
        pc = Piece()
        half = 12.5 * MM / (SAD_THETA * 0.21)
        rows = []
        for a in [x for x in A_ST if abs(x) <= 0.8]:
            rows.append([pc.v(saddle_top(a, sb * 0.60 + o, 0.5 * MM)[0], dict(tape=1.0)) for o in (-half, half)])
            rows[-1].append(saddle_top(a, sb * 0.60, 0)[1])
        for r0, r1 in zip(rows, rows[1:]):
            pc.f(r0[0], r0[1], r1[1], r1[0], out=r0[2])
        G.commit(pc, "tape")

    # ---------------- strap paths cast in a plane through the body, pulled taut over hollows
    def band(C, e_up, e_side, phi0, phi1, steps=160):
        pn = e_up.cross(e_side).normalized()
        phis = np.linspace(phi0, phi1, steps)
        R, Nh = [], []
        for ph in phis:
            d = e_up * math.cos(ph) + e_side * math.sin(ph)
            loc, n = cast(C + d * 1.5, -d)
            R.append((loc - C).dot(d))
            Nh.append(n)
        R = np.array(R)
        # taut: bridge concavities with the upper envelope of chords over a short window (a strap under tension)
        Rt = R.copy()
        for i in range(len(R)):
            for w in range(2, 7):
                if i - w >= 0 and i + w < len(R):
                    Rt[i] = max(Rt[i], 0.5 * (R[i - w] + R[i + w]) * math.cos(w * (phis[1] - phis[0])))
        P, N = [], []
        for k, ph in enumerate(phis):
            d = e_up * math.cos(ph) + e_side * math.sin(ph)
            P.append(C + d * Rt[k])
        for k in range(len(P)):
            t = (P[min(k + 1, len(P) - 1)] - P[max(k - 1, 0)]).normalized()
            n_in = pn.cross(t).normalized()
            if n_in.dot(P[k] - C) < 0:
                n_in = -n_in
            N.append((n_in + pn * Nh[k].dot(pn)).normalized())
        for _ in range(3):
            N = [N[0]] + [(N[k - 1] + N[k] * 2 + N[k + 1]).normalized() for k in range(1, len(N) - 1)] + [N[-1]]
        P = [p + n * STRAP_OFF for p, n in zip(P, N)]
        P, N, E, L = resample(P, N, STEP, list(phis))
        P, N = conform(P, N, WEB_W)
        return P, N, E, L

    def clearance(p, n):
        loc = cast(p + n * 0.25, -n)[0]
        return 1.0 if loc is None else (p - loc).dot(n)

    def conform(P, N, W, need=STRAP_OFF, iters=6):
        """Seat the strap on the coat across its whole width: per station, tilt the section about the path so it
        follows the body's slope under the webbing (least-squares over 5 points across), then move it in or out
        along its normal until its lowest point is `need` above the body. The offset is lightly blurred along the
        path (never below a station's own need), so the strap runs smoothly and dips into hollows instead of
        bridging them (the coat fills under a real strap; a bridged gap reads as floating at game distance)."""
        xs = np.linspace(-W / 2, W / 2, 5)
        P, N = list(P), list(N)
        m = len(P)
        total = np.zeros(m)
        for _ in range(iters):
            fr = path_frames(P, N)
            tilt, off = [], []
            for o, t, b, n in fr:
                c = np.minimum([clearance(o + b * x, n) for x in xs], 0.08)
                tilt.append(math.atan(np.polyfit(xs, c, 1)[0]))
                off.append(need - float(c.min()))
            tilt[0], tilt[-1] = tilt[1], tilt[-2]                    # one-sided end frames: borrow the neighbour
            tilt = [0.8 * (0.5 * tilt[i] + 0.25 * tilt[max(i - 1, 0)] + 0.25 * tilt[min(i + 1, m - 1)]) for i in range(m)]
            tilt = np.clip(total + tilt, -0.6, 0.6) - total          # total tilt off the band's normal <= 0.6 rad
            total += tilt
            sm = [0.25 * off[max(i - 1, 0)] + 0.5 * off[i] + 0.25 * off[min(i + 1, m - 1)] for i in range(m)]
            off = [max(a, b) for a, b in zip(off, sm)]
            P = [o + n * d for (o, t, b, n), d in zip(fr, off)]
            N = [n * math.cos(a) + b * math.sin(a) for (o, t, b, n), a in zip(fr, tilt)]
        return P, N

    def strap(P, N, W, label, name=None):
        prof, attrs = web_profile(W)
        pc = Piece()
        pc.name = name
        rings = sweep(pc, path_frames(P, N), prof, attrs)
        pc.inner = [r[k] for r in rings for k in (0, 1)]
        G.commit(pc, label)

    def frame_at(P, N, s):
        """Frame on a resampled path at arc length s."""
        L = [0.0]
        for a, b in zip(P, P[1:]):
            L.append(L[-1] + (b - a).length)
        j = max(0, min(len(P) - 2, int(np.searchsorted(L, s)) - 1))
        u = (s - L[j]) / max(L[j + 1] - L[j], 1e-9)
        o = P[j].lerp(P[j + 1], u)
        t = (P[j + 1] - P[j]).normalized()
        n = N[j].lerp(N[j + 1], u)
        n = (n - t * n.dot(t)).normalized()
        return o, t, n.cross(t).normalized(), n

    def sub_path(P, N, s0, s1, step=0.03):
        cnt = max(2, int(round((s1 - s0) / step)) + 1)
        return [frame_at(P, N, s0 + (s1 - s0) * k / (cnt - 1)) for k in range(cnt)]

    def overlay(frames, w, web, attr, label):
        """Sewn-on strip (tape) 0.5 mm proud of the crowned webbing face, 3 vertices across so it follows the crown."""
        pc = Piece()
        xs = (-w / 2, 0.0, w / 2)
        rows = [[pc.v(o + b * x + n * (web_h(x, *web) + 0.5 * MM), attr) for x in xs] for o, t, b, n in frames]
        for (o, t, b, n), r0, r1 in zip(frames, rows, rows[1:]):
            for k in range(len(xs) - 1):
                pc.f(r0[k], r0[k + 1], r1[k + 1], r1[k], out=n)
        G.commit(pc, label)

    def tack(o, t, b, n, L, W, h, web=None):
        """Box-X bar tack: six raised thread ribbons (1.6 mm wide, standing 0.8 mm proud) over the webbing face;
        web = (webbing width, thickness) lays the corners on the crowned face instead of a flat height h."""
        pc = Piece()
        hh = [h if web is None else web_h(sw * W / 2, *web) + 0.8 * MM for sw in (-1, 1, 1, -1)]
        c = [o + t * (sl * L / 2) + b * (sw * W / 2) + n * hk
             for (sl, sw), hk in zip(((-1, -1), (1, -1), (1, 1), (-1, 1)), hh)]
        for p, q in ((c[0], c[1]), (c[1], c[2]), (c[2], c[3]), (c[3], c[0]), (c[0], c[2]), (c[1], c[3])):
            sd = (q - p).cross(n).normalized() * 0.8 * MM
            ids = [pc.v(x, dict(stitch=1.0)) for x in (p - sd, q - sd, q + sd, p + sd)]
            pc.f(*ids, out=n)
        G.commit(pc, "stitch")

    def lofted(pc, xs, a=None):
        """Chamfered-rectangle loft along local x: xs = [(x, wy, hz, ch)], returns nothing (capped)."""
        rings = []
        for x, wy, hz, ch in xs:
            rings.append([(x, y, z) for y, z in loop_section(wy, hz, ch)])
        return rings

    def solid(rings_local, place, attr, label, tube_axis=None):
        pc = Piece()
        rings = [[pc.v(place(p), attr) for p in ring] for ring in rings_local]
        m = len(rings[0])
        for r0, r1 in zip(rings, rings[1:]):
            for k in range(m):
                pc.f(r0[k], r0[(k + 1) % m], r1[(k + 1) % m], r1[k])
        pc.f(*reversed(rings[0]))
        pc.f(*rings[-1])
        G.commit(pc, label)

    def box(place, c, size, attr, label, ch=0.0):
        cx, cy, cz = c
        lx, ly, lz = size
        sec = loop_section(ly, lz, ch) if ch > 0 else [(ly / 2, -lz / 2), (ly / 2, lz / 2), (-ly / 2, lz / 2), (-ly / 2, -lz / 2)]
        rings = [[(cx + sx * lx / 2, cy + y, cz + z) for y, z in sec] for sx in (-1, 1)]
        solid(rings, place, attr, label)

    def bar(place, c, length, r, attr, label, segs=6, along="y"):
        cx, cy, cz = c
        sec = [(r * math.cos(2 * math.pi * k / segs), r * math.sin(2 * math.pi * k / segs)) for k in range(segs)]
        if along == "y":
            rings = [[(cx + u, cy + s * length / 2, cz + v) for u, v in sec] for s in (-1, 1)]
        else:
            rings = [[(cx + s * length / 2, cy + u, cz + v) for u, v in sec] for s in (-1, 1)]
        solid(rings, place, attr, label)

    def placer(o, t, b, n, flip=1.0, k=1.0):
        """Local (x along the strap, y across, z out) -> world; k scales x and z (length, thickness), not the width."""
        def place(p):
            x, y, z = p
            return o + t * (x * flip * k) + b * y + n * (z * k)
        return place

    def side_release_buckle(fr, W):
        """Female (+x) and male (-x) halves, mouth at x=0, centred on the strap mid-thickness."""
        o, t, b, n = fr
        bw = W + 14 * MM
        # rigid part on a curved strap: lift it until its underside corners sit on the coat (STRAP_OFF - 3 mm)
        und = 6.5 * MM * BK - (WEB_T / 2 + 2.0 * MM)          # buckle underside below the strap's inner face
        lift = max(0.0, max(STRAP_OFF - 0.003 - clearance(o + t * (x * BK) + b * y - n * und, n)
                            for x in (-46 * MM, 0.0, 52 * MM) for y in (-bw / 2, bw / 2)))
        place = placer(o + n * (WEB_T / 2 + 2.0 * MM + lift), t, b, n, k=BK)
        # female: hollow mouth, body, tapered back, webbing bar on two posts, release prong tips through side windows
        solid(lofted(None, [(8 * MM, bw - 8 * MM, 7 * MM, 1.5 * MM), (1.5 * MM, bw - 8 * MM, 7 * MM, 1.5 * MM),
                            (0.0, bw, 13 * MM, 3 * MM), (27 * MM, bw, 13 * MM, 3 * MM),
                            (40 * MM, bw - 4 * MM, 9 * MM, 2.5 * MM), (44 * MM, bw - 8 * MM, 7 * MM, 2 * MM)]),
              place, PLASTIC, "buckle")
        for s in (1, -1):
            box(place, (16 * MM, s * (bw / 2 + 0.8 * MM), 0.0), (9 * MM, 3.5 * MM, 7.5 * MM), PLASTIC, "buckle")
            box(place, (48 * MM, s * (bw / 2 - 4 * MM), 0.0), (9 * MM, 3.0 * MM, 4.5 * MM), PLASTIC, "buckle")
        bar(place, (52 * MM, 0, 0), bw - 5 * MM, 2.6 * MM, PLASTIC, "buckle")
        # male: body with a raised rib, then a ladder-lock frame (side rails, adjust bar, end bar)
        solid(lofted(None, [(6 * MM, bw - 10 * MM, 6 * MM, 1.5 * MM), (-1 * MM, bw - 10 * MM, 6 * MM, 1.5 * MM),
                            (-1.5 * MM, bw - 2 * MM, 10 * MM, 2.5 * MM), (-19 * MM, bw - 2 * MM, 10 * MM, 2.5 * MM),
                            (-23 * MM, bw - 5 * MM, 7 * MM, 2 * MM)]), place, PLASTIC, "buckle")
        box(place, (-10 * MM, 0, 5.4 * MM), (15 * MM, 5 * MM, 1.6 * MM), PLASTIC, "buckle")
        for s in (1, -1):
            box(place, (-34 * MM, s * (bw / 2 - 3.5 * MM), 0.0), (24 * MM, 4 * MM, 6 * MM), PLASTIC, "buckle")
        bar(place, (-32 * MM, 0, 0.6 * MM), bw - 7 * MM, 2.4 * MM, PLASTIC, "buckle")
        bar(place, (-44 * MM, 0, 0), bw - 3 * MM, 2.8 * MM, PLASTIC, "buckle")

    def tri_glide(P, N, s, W, direction):
        """Tri-glide on the strap at arc length s, with the doubled tail lying on the strap toward `direction`."""
        o, t, b, n = frame_at(P, N, s)
        place = placer(o + n * (WEB_T + 2.2 * MM * BK), t, b, n, k=BK)
        gw = W + 8 * MM
        for s_ in (1, -1):
            box(place, (0, s_ * (gw / 2 - 1.8 * MM), 0), (21 * MM, 3.6 * MM, 4.4 * MM), PLASTIC, "buckle")
        for x in (-8.5 * MM, 0.0, 8.5 * MM):
            bar(place, (x, 0, 0), gw - 3 * MM, 1.9 * MM, PLASTIC, "buckle", segs=4)
        s_end = s + direction * 0.055
        fr = sub_path(P, N, min(s, s_end), max(s, s_end), 0.025)
        fr = [(o_ + n_ * (WEB_T + 0.6 * MM), t_, b_, n_) for o_, t_, b_, n_ in fr]
        prof, attrs = web_profile(W)
        pc = Piece()
        sweep(pc, fr, prof, attrs)
        G.commit(pc, "webbing")

    # ---------------- girth strap
    def plane_band(C, e_up, e_side, phi0, phi1):
        P, N, phis, L = band(C, e_up, e_side, phi0, phi1)
        return P, N, phis, L

    gz = axis_z(GIRTH_Y)
    a_g = (GIRTH_Y - sad_yc) / sad_hy
    th_edge = SAD_THETA * math.sqrt(1 - 0.55 * a_g * a_g / 2)
    Cg = Vector((0, GIRTH_Y, gz))
    Pg, Ng, phg, Lg = plane_band(Cg, Vector((0, 0, 1)), Vector((1, 0, 0)), th_edge - 0.09, 2 * math.pi - th_edge + 0.09)
    strap(Pg, Ng, WEB_W, "webbing", "girth")

    def s_of_phi(phis, L, ph):
        return L * float(np.interp(ph, phis, np.linspace(0, 1, len(phis))))

    side_release_buckle(frame_at(Pg, Ng, s_of_phi(phg, Lg, 2 * math.pi - 1.95)), WEB_W)
    tri_glide(Pg, Ng, s_of_phi(phg, Lg, 1.80), WEB_W, +1)
    for ph in (th_edge + 0.05, 2 * math.pi - th_edge - 0.05):
        tack(*frame_at(Pg, Ng, s_of_phi(phg, Lg, ph)), 26 * MM, WEB_W - 10 * MM, 0.0, (WEB_W, WEB_T))

    # ---------------- chest strap: plane through the saddle's lower front corners and the front of the chest
    corner = saddle_surf(-0.80, 0.86)[0]
    Cc = Vector((0, corner.y, corner.z))
    y_ch = -0.35
    top, bot = cast((0, y_ch, 3.0), (0, 0, -1))[0].z, cast((0, y_ch, -1.0), (0, 0, 1))[0].z
    F = cast((0, -3.0, bot + 0.40 * (top - bot)), (0, 1, 0))[0]
    e_up = (F - Cc).normalized()
    e_side = Vector((1, 0, 0))
    Pc, Nc, phc, Lc = plane_band(Cc, e_up, e_side, -math.pi / 2 - 0.22, math.pi / 2 + 0.22)
    strap(Pc, Nc, WEB_W, "webbing", "chest")
    mid = s_of_phi(phc, Lc, 0.0)
    # tape on the strap's own ring stations (a finer or offset sampling would dip under the chord of the strap)
    Lcum = np.concatenate([[0.0], np.cumsum([(b - a).length for a, b in zip(Pc, Pc[1:])])])
    overlay([f for f, s in zip(path_frames(Pc, Nc), Lcum) if abs(s - mid) <= 0.16], 25 * MM, (WEB_W, WEB_T),
            dict(tape=1.0), "tape")
    side_release_buckle(frame_at(Pc, Nc, s_of_phi(phc, Lc, 0.95)), WEB_W)
    tri_glide(Pc, Nc, s_of_phi(phc, Lc, -0.95), WEB_W, -1)
    for ph in (-math.pi / 2 + 0.22, math.pi / 2 - 0.22):
        tack(*frame_at(Pc, Nc, s_of_phi(phc, Lc, ph)), 26 * MM, WEB_W - 10 * MM, 0.0, (WEB_W, WEB_T))

    # ---------------- grab handle: webbing loop, feet stitched flat on the saddle, neoprene grip sleeve
    HW = 40 * MM
    a_f, a_b = -0.50, 0.36
    pa, na = saddle_top(a_f, 0.0, 0.3 * MM)
    pb, nb = saddle_top(a_b, 0.0, 0.3 * MM)
    up = (na + nb).normalized()
    u = (pb - pa).normalized()
    Ry, H = (pb - pa).length / 2, 0.072
    M = (pa + pb) / 2
    P, N = [], []
    foot = 0.24
    for a in (a_f - foot, a_f - foot / 2):
        p, n = saddle_top(a, 0.0, 0.3 * MM)
        P.append(p)
        N.append(n)
    arc_n = 13
    for k in range(arc_n):
        ph = math.pi * k / (arc_n - 1)
        p = M - u * (Ry * math.cos(ph)) + up * (H * math.sin(ph))
        n = (-u * (H * math.cos(ph)) + up * (Ry * math.sin(ph))).normalized()
        if k == 0:
            n = (n + na).normalized()
        if k == arc_n - 1:
            n = (n + nb).normalized()
        P.append(p)
        N.append(n)
    for a in (a_b + foot / 2, a_b + foot):
        p, n = saddle_top(a, 0.0, 0.3 * MM)
        P.append(p)
        N.append(n)
    prof, attrs = web_profile(HW)
    pc = Piece()
    hf = path_frames(P, N)
    sweep(pc, hf, prof, attrs)
    G.commit(pc, "handle")
    for i in (0, len(hf) - 1):
        o, t, b, n = path_frames(P, N)[i]
        o2 = o.lerp(P[1 if i == 0 else -2], 0.5)
        tack(o2, t, b, n, 24 * MM, HW - 10 * MM, 0.0, (HW, WEB_T))
    # grip sleeve
    pc = Piece()
    segs, GR = 8, (27 * MM, 12.5 * MM)       # grip sleeve half-width / half-height
    sec = []
    for k in range(segs):
        ang = 2 * math.pi * k / segs
        c, s = math.cos(ang), math.sin(ang)
        sec.append((GR[0] * math.copysign(abs(c) ** 0.6, c), GR[1] * math.copysign(abs(s) ** 0.6, s)))
    fr = []
    ph0, ph1, st = 0.30 * math.pi, 0.70 * math.pi, 9
    for k in range(-1, st + 1):
        ph = ph0 + (ph1 - ph0) * min(max(k, 0), st - 1) / (st - 1)
        sc = 0.80 if k in (-1, st) else 1.0
        dph = 0.035 if k == -1 else (-0.035 if k == st else 0.0)
        ph -= dph
        p = M - u * (Ry * math.cos(ph)) + up * (H * math.sin(ph))
        n = (-u * (H * math.cos(ph)) + up * (Ry * math.sin(ph))).normalized()
        t = (u * (Ry * math.sin(ph)) + up * (H * math.cos(ph))).normalized()
        b = n.cross(t).normalized()
        fr.append((p + n * (WEB_T / 2), t, b * sc, n * sc))
    sweep(pc, fr, sec, [dict(grip=1.0)] * segs)
    G.commit(pc, "grip")
    apex_p = M + up * H
    HANDLE_APEX = tuple(apex_p + up * (WEB_T / 2 + GR[1]))

    # ---------------- tow D-ring on a webbing tab behind the saddle
    TW, TAB_T, wr = 25 * MM, 4.5 * MM, 4.2 * MM
    y_bar = SAD_Y1 + 0.030
    hit, nrm = cast((0, y_bar, 3.0), (0, 0, -1))
    rear_top = saddle_top(0.93, 0.0)[0]
    bc = Vector((0, y_bar, max(hit.z + SAD_OFF + wr + 2 * MM, rear_top.z - 0.004)))
    q = Vector((0, math.cos(math.radians(22)), math.sin(math.radians(22))))
    ex = Vector((1, 0, 0))
    hw, rc, side = 24 * MM, 6 * MM, 11 * MM
    outline = [(-hw + rc, 0), (0, 0), (hw - rc, 0)]
    outline += [(hw - rc + rc * math.sin(a), rc - rc * math.cos(a)) for a in (math.pi / 4, math.pi / 2)]
    outline += [(hw, side)]
    outline += [(hw * math.cos(a), side + hw * math.sin(a)) for a in np.linspace(0, math.pi, 10)[1:-1]]
    outline += [(-hw, side)]
    outline += [(-hw + rc - rc * math.sin(a), rc - rc * math.cos(a)) for a in (math.pi / 2, math.pi / 4)]
    pts = [bc + ex * x + q * y for x, y in outline]
    pn = ex.cross(q).normalized()
    fr = []
    for i, p in enumerate(pts):
        t = (pts[(i + 1) % len(pts)] - pts[i - 1]).normalized()
        m = t.cross(pn).normalized()
        r = wr * (1.35 if i == 8 else 1.0)            # weld bead on the curve
        fr.append((p, t, pn * r, m * r))
    sec6 = [(math.cos(2 * math.pi * k / 6), math.sin(2 * math.pi * k / 6)) for k in range(6)]
    pc = Piece()
    sweep(pc, fr, sec6, [dict(metal=1.0)] * 6, loop=True)
    G.commit(pc, "dring")
    DRING_POS = tuple(bc + q * (side + hw))
    # tab: flat on the saddle, over the bar, wrapped round it and back underneath
    P, N = [], []
    for a in (0.68, 0.82, 0.93):
        p, n = saddle_top(a, 0.0, 0.3 * MM)
        P.append(p)
        N.append(n)
    rr = wr + 0.3 * MM
    for ang in np.linspace(math.pi / 2, -math.pi / 2, 6):     # over the top, round the back, to the bottom
        rad = Vector((0, math.cos(ang), math.sin(ang)))
        P.append(bc + rad * rr)
        N.append(rad)
    P.append(bc + Vector((0, -0.020, -rr)))
    N.append(Vector((0, 0, -1)))
    prof, attrs = web_profile(TW, TAB_T)
    pc = Piece()
    tf = path_frames(P, N)
    sweep(pc, tf, prof, attrs)
    G.commit(pc, "tab")
    o, t, b, n = tf[1]
    tack(o, t, b, n, 20 * MM, TW - 7 * MM, 0.0, (TW, TAB_T))

    # ---------------- mesh
    me = bpy.data.meshes.new("BosunHarness")
    me.from_pydata([tuple(v) for v in G.V], [], G.F)
    me.validate(clean_customdata=False)
    bm = bmesh.new()
    bm.from_mesh(me)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(60):
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    n = len(me.vertices)
    for name in ATTRS:
        set_attr(me, name, np.array([float(a.get(name, 0.0)) for a in G.A]))
    me["harness_tris"] = str(G.tris)
    me["harness_ranges"] = str(G.ranges)
    return me
