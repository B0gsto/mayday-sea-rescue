"""M_Veh_RIB: Atlantic 85-class inshore lifeboat (generic, not a replica), Gale Isles Coastguard livery. Batch V2.

8.44 m x 2.85 m (25.3 x 8.55 studs at 3 studs/m). Deep-V GRP hull in charcoal with a Hull Orange boot stripe, grey
tube collar with two rub strakes, a retroreflective band and webbing handles, non-slip deck, console shell in Hull Orange,
Hull Orange A-frame with radar, blue beacon, masthead / stern lights and a searchlight, twin outboards (about 115 hp
class, no maker marks), decal panels "GALE ISLES COASTGUARD", fleet number GI-21 and the lighthouse-and-compass crest.

Sets (docs/12 row): Hull (hull + tubes, 2048), Deck (deck + console shell, 2048), Rig (A-frame + engines, 1024),
Decals (1024); every set has _Wet. The helm (wheel, instruments, seats) is M_Veh_RIB_Helm in the same frame.

    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Veh_RIB --steps build,lod,validate,export
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ribgeo as R  # noqa: E402
from ribgeo import Vector as V  # noqa: E402,F401
import rbxkit  # noqa: E402

NAME = "M_Veh_RIB"
TEX = "RIB"


def M(g, name, lo_name="X"):
    return name if g.hi else lo_name


# =========================================================================== Hull set
def hull_sections(hi):
    ys = [R.TRANSOM_Y - i * (0.5 if hi else 0.85) for i in range(int(17 / (0.5 if hi else 0.85)) + 1)]
    ys = [y for y in ys if y > -6.5]
    ys += [-6.9, -7.5, -8.1, -8.7, -9.2, -9.7, -10.1, -10.5, -10.85, -11.2] if hi else [-7.2, -8.0, -8.8, -9.5, -10.1, -10.6, -11.0, -11.2]
    secs = []
    for y in ys:
        cx, cz, r = R.tube_frame(y)
        xs = max(0.04, cx - 0.32)
        zs = cz - r * 0.82
        f = min(1.0, max(0.0, (-y - 2.0) / 9.2))
        zk = R.K + 1.35 * f ** 2.2
        dead = math.radians(22 + 20 * f ** 1.4)
        xc = 0.86 * xs
        zc = min(zk + math.tan(dead) * xc, zs - 0.22)
        xa, za = 0.30 * xc, zk + 0.03 + (zc - zk) * 0.27     # inner spray rail
        xm, zm = 0.60 * xc, zk + 0.03 + (zc - zk) * 0.56     # outer spray rail
        half = [(0.10, zk + 0.0), (0.16, zk + 0.035), (xa, za), (xa + 0.045, za - 0.03), (xm, zm), (xm + 0.06, zm - 0.035),
                (xc, zc), (xc + 0.16, zc + 0.015), (xc + 0.18, zc + 0.09), (xs, zs)]
        pts = [Vector((-x, y, z)) for x, z in reversed(half)] + [Vector((x, y, z)) for x, z in half]
        secs.append(pts)
    yb = ys[-1] - 0.35
    stem = [Vector((p.x * 0.05, yb, max(p.z, R.K + 1.5))) for p in secs[-1]]
    secs.append(stem)
    return secs


def hull(g):
    secs = hull_sections(g.hi)
    n = len(secs[0])
    faces = g.rings(secs, M(g, "HullBody"), closed=False, recalc=False)
    g.orient(faces, lambda c: Vector((c.x, 0.0, c.z - R.DECK - 1.0)) if abs(c.x) > 0.05 else Vector((0, 0, -1)))
    ring = [g.bm.verts.new(p) for p in secs[0]]
    top = [g.bm.verts.new(Vector((x, R.TRANSOM_Y, R.DECK + 0.25))) for x in (secs[0][-1].x, secs[0][0].x)]
    f = g.face(ring + top, M(g, "HullBody"))
    if f:
        res = bmesh.ops.triangulate(g.bm, faces=[f])
        g.orient(res["faces"], lambda c: Vector((0, 1, 0)))
    R.box(g, (0, R.TRANSOM_Y - 0.2, R.DECK + 0.3), (2 * secs[0][-1].x, 0.4, 0.1), M(g, "GelcoatWhite"))
    # stainless keel band along the keel flat, wrapping up the stem
    kp = [Vector((0, s_[n // 2].y, s_[n // 2].z - 0.012)) for s_ in secs[:-1]]
    kp.append(Vector((0, secs[-1][n // 2].y + 0.05, secs[-1][n // 2].z - 0.1)))
    R.sweep(g, kp, [(-0.13, -0.02), (0.13, -0.02), (0.11, 0.03), (-0.11, 0.03)], M(g, "KeelStrip"), cap0=True, cap1=True)
    # sacrificial anodes and the transducer on the transom bottom
    for sx in (1, -1):
        R.box(g, (sx * 0.75, R.TRANSOM_Y + 0.05, 0.95), (0.42, 0.1, 0.16), M(g, "Aluminium"))
    R.box(g, (-1.6, R.TRANSOM_Y + 0.08, 1.0), (0.22, 0.16, 0.12), M(g, "BlackPlastic"))
    if g.hi:
        for sx in (1, -1):
            for dx in (-0.12, 0.12):
                R.lathe(g, (sx * 0.75 + dx, R.TRANSOM_Y + 0.1, 0.95), (0, 1, 0), BOLT, 6, "Bolt")


BOLT = [(0.035, 0.0), (0.035, 0.022), (0.026, 0.032), (0.0, 0.034)]


def bolts(g, pts, axis, mat="Bolt"):
    """HP-only hex bolt heads (baked into NOR / ALB: fasteners read at 2 m without LOD0 triangles)."""
    if g.hi:
        for p in pts:
            R.lathe(g, p, axis, BOLT, 6, mat)


def _tube_deform(hi):
    def fn(co):
        if not (R.BOW_Y0 - 0.2 < co.y < R.STERN_Y):
            return co
        sx = 1 if co.x > 0 else -1
        d = Vector((co.x - sx * R.TX, 0.0, co.z - R.TZ))
        r = d.length
        if r < 1e-4 or r > R.TR * 1.6:
            return co
        u = d / r
        sag = 0.014 * (0.5 - 0.5 * math.cos(2 * math.pi * (co.y - R.STERN_Y) / 3.6)) * max(0.0, u.z) ** 2
        crease = 0.0
        if hi:
            crease = 0.007 * R.noise.noise(Vector((co.y * 1.3, math.atan2(u.z, u.x) * 2.5, sx * 0.7)))
        return co + u * crease - Vector((0, 0, sag))
    return fn


def tubes(g):
    start = len(g.bm.verts)
    path = R.tube_path(not g.hi)
    pts = [p for p, r in path]
    radii = [r / R.TR for p, r in path]
    seg = 48 if g.hi else 32
    prof = R.circle_profile(R.TR, seg, phase=0.0)

    def mat(i, j):
        a, b = prof[j]
        phi = math.degrees(math.atan2(b, -a))
        if 47 <= phi <= 57:
            return "Reflective"
        if -100 <= phi <= -60:
            return "TubeWear"
        return "TubeGrey"
    R.sweep(g, pts, prof, M(g, "TubeGrey"), radii=radii, cap0=True, cap1=True, matfn=mat if g.hi else None)

    def strip(phi_deg, R0, h, w):
        phi = math.radians(phi_deg)
        nx, nz = -math.cos(phi), math.sin(phi)
        tx, tz = math.sin(phi), math.cos(phi)
        return [(nx * R0 - tx * w, nz * R0 - tz * w), (nx * (R0 + h) - tx * w * 0.6, nz * (R0 + h) - tz * w * 0.6),
                (nx * (R0 + h) + tx * w * 0.6, nz * (R0 + h) + tz * w * 0.6), (nx * R0 + tx * w, nz * R0 + tz * w)]
    if g.hi:
        # welded overlap seams: four longitudinal, circumferential panel joins every 1.2 m on the straights
        for phi in (22, 84, -38, -150):
            R.sweep(g, pts, list(reversed(strip(phi, R.TR - 0.002, 0.009, 0.05))), "TubeSeam", radii=radii)
        for sx in (1, -1):
            for y in (-5.2, -1.6, 2.0, 5.6, 9.2):
                rings = []
                for dy, rr in ((-0.05, R.TR - 0.002), (-0.025, R.TR + 0.008), (0.025, R.TR + 0.008), (0.05, R.TR - 0.002)):
                    rings.append([Vector((sx * R.TX + rr * math.cos(2 * math.pi * k / 64), y + dy,
                                          R.TZ + rr * math.sin(2 * math.pi * k / 64))) for k in range(64)])
                fs = g.rings(rings, "TubeSeam", closed=True, recalc=False)
                g.orient(fs, lambda c, sx=sx: Vector((c.x - sx * R.TX, 0, c.z - R.TZ)))
            # chafe patches (gunwale scuffs) where the tube meets quays and casualties
            for y0, y1 in ((-4.4, -2.9), (3.0, 4.6), (8.4, 10.6)):
                tube_patch(g, sx, y0, y1, math.radians(-30), math.radians(-14), "TubeWear", 0.006, nu=10, nv=4)
    # tube-to-hull fillet tape along the hull join (inboard underside)
    span = [i for i, p in enumerate(pts) if p.y <= R.TRANSOM_Y + 0.1]
    fil = [(-math.cos(math.radians(a)) * (R.TR + 0.01), math.sin(math.radians(a)) * (R.TR + 0.01))
           for a in ((-100, -110, -120, -130, -140) if g.hi else (-100, -120, -140))]
    for chunk in _runs(span):
        sp = [pts[i] for i in chunk]
        fs = R.sweep(g, sp, fil, M(g, "TubeFillet"), closed=False, radii=[radii[i] for i in chunk], recalc=False)
        g.orient(fs, lambda c: c - min(sp, key=lambda q: (q - c).length))
    # tube-end caps (moulded rubber cones over the stern tips)
    for sx in (1, -1):
        R.lathe(g, (sx * R.TX, 11.93, R.TZ), (0, 1, 0), [(0.57, 0.0), (0.51, 0.08), (0.37, 0.18), (0.19, 0.26), (0.0, 0.3)],
                24 if g.hi else 14, M(g, "TubeEndCap"))
        if g.hi:
            R.lathe(g, (sx * R.TX, 11.9, R.TZ), (0, 1, 0), [(0.6, 0.0), (0.6, 0.05), (0.55, 0.07)], 24, "TubeEndCap")
    # rub strakes (grey) along the straight and most of the bow arc
    span = [i for i, (p, r) in enumerate(path) if p.y < R.STERN_Y + 0.05 and abs(r - R.TR) < 0.06]
    for phi_deg, h, d in ((-18, 0.15, 0.11), (-52, 0.07, 0.06)):
        for chunk in _runs(span):
            sp = [pts[i] for i in chunk]
            phi = math.radians(phi_deg)
            nx, nz = -math.cos(phi), math.sin(phi)
            tx, tz = math.sin(phi), math.cos(phi)
            rr = R.TR - 0.01
            if g.hi:
                prof2 = [(nx * (rr + d * k) + tx * h * s, nz * (rr + d * k) + tz * h * s)
                         for k, s in ((0, -1), (0.7, -1), (0.92, -0.85), (1, -0.5), (1, 0.5), (0.92, 0.85), (0.7, 1), (0, 1))]
            else:
                prof2 = [(nx * rr - tx * h, nz * rr - tz * h), (nx * (rr + d) - tx * h * 0.7, nz * (rr + d) - tz * h * 0.7),
                         (nx * (rr + d) + tx * h * 0.7, nz * (rr + d) + tz * h * 0.7), (nx * rr + tx * h, nz * rr + tz * h)]
            R.sweep(g, sp, list(reversed(prof2)), M(g, "RubStrake"), cap0=True, cap1=True)
    # outboard lifeline: rope through glued patches, sagging between them
    for sx in (1, -1):
        ys = [-5.4 + 1.6 * k for k in range(11)]
        rp = []
        for a, b in zip(ys, ys[1:]):
            for k in range(4 if g.hi else 2):
                t = k / (4 if g.hi else 2)
                y = a + (b - a) * t
                sg = math.sin(math.pi * t)
                phi = math.radians(64 - 12 * sg)
                rr = R.TR + 0.04 + 0.03 * sg
                rp.append(Vector((sx * (R.TX + rr * math.cos(phi)), y, R.TZ + rr * math.sin(phi))))
        rp.append(Vector((sx * (R.TX + (R.TR + 0.04) * math.cos(math.radians(64))), ys[-1], R.TZ + (R.TR + 0.04) * math.sin(math.radians(64)))))
        R.sweep(g, rp, R.circle_profile(0.03, 8 if g.hi else 5), M(g, "Rope"), cap0=True, cap1=True)
        for y in ys:
            phi = math.radians(64)
            nrm = Vector((sx * math.cos(phi), 0, math.sin(phi)))
            c = Vector((sx * R.TX, y, R.TZ)) + nrm * (R.TR + 0.012)
            R.box(g, tuple(c), (0.2, 0.22, 0.2), M(g, "TubeWear"), rot=Matrix.Rotation(sx * (math.pi / 2 - phi), 3, "Y") @
                  Matrix.Diagonal((1, 1, 0.12)).to_3x3())
    # webbing grab handles on the inner top of both tubes
    for sx in (1, -1):
        for y in [-4.6 + 2.3 * k for k in range(6)]:
            c = Vector((sx * R.TX, y, R.TZ))
            phi = math.radians(70)
            n = Vector((-sx * math.cos(phi), 0, math.sin(phi)))
            base = c + n * R.TR
            seg_a = 10 if g.hi else 6
            arc = []
            for k in range(seg_a + 1):
                t = math.pi * k / seg_a
                arc.append(base + Vector((0, -0.26 * math.cos(t), 0)) + n * (0.2 * math.sin(t) + 0.005))
            w, th = 0.075, 0.018
            prof3 = [(-w, -th), (w, -th), (w, th), (-w, th)]
            R.sweep(g, arc, prof3, M(g, "Webbing"), cap0=True, cap1=True)
            R.box(g, tuple(base - n * 0.005), (0.24, 0.72, 0.02), M(g, "TubeWear"),
                  rot=Matrix.Rotation(-sx * (math.pi / 2 - phi), 3, "Y"))
    # inflation / topping-up valves on the tube tops (one per chamber)
    for sx in (1, -1):
        for y in (-3.4, 2.2, 7.6):
            top = Vector((sx * (R.TX - 0.12), y, R.TZ + R.TR - 0.015))
            R.lathe(g, top, (0, 0, 1), [(0.13, 0.0), (0.13, 0.025), (0.09, 0.04), (0.07, 0.07), (0.0, 0.08)],
                    20 if g.hi else 12, M(g, "BlackPlastic"))
    R.deform(g, start, _tube_deform(g.hi))
    # bow towing eye on the stem with a stainless fairlead plate
    c = Vector((0, R.BOW_Y1 - (R.TR - 0.05) - 0.04, R.TZ + R.BOW_RISE))
    R.box(g, tuple(c + Vector((0, 0.02, 0))), (0.36, 0.06, 0.42), M(g, "RubStrake"))
    ring = [c + Vector((0.09 * math.cos(2 * math.pi * k / 10), -0.05, 0.09 * math.sin(2 * math.pi * k / 10)))
            for k in range(10)]
    R.sweep(g, ring + [ring[0]], R.circle_profile(0.028, 8 if g.hi else 5), M(g, "Stainless"), cap0=True, cap1=True)
    bolts(g, [c + Vector((dx, -0.01, dz)) for dx in (-0.12, 0.12) for dz in (-0.15, 0.15)], (0, -1, 0))


def tubes(g):
    path = R.tube_path(not g.hi)
    pts = [p for p, r in path]
    radii = [r / R.TR for p, r in path]
    seg = 48 if g.hi else 32
    prof = R.circle_profile(R.TR, seg, phase=0.0)

    def mat(i, j):
        # profile angle: a = side (inward), b = up; outward band angle phi measured from outward horizontal
        a, b = prof[j]
        phi = math.degrees(math.atan2(b, -a))
        if 47 <= phi <= 57:
            return "Reflective"
        if -100 <= phi <= -60:
            return "TubeWear"
        return "TubeGrey"
    R.sweep(g, pts, prof, M(g, "TubeGrey"), radii=radii, cap0=True, cap1=True, matfn=mat if g.hi else None)
    # rub strakes along the straight and most of the bow arc (outward side, below the centre)
    span = [i for i, (p, r) in enumerate(path) if p.y < R.STERN_Y + 0.05 and abs(r - R.TR) < 0.06]
    for phi_deg, h, d in ((-18, 0.15, 0.11), (-52, 0.07, 0.06)):
        for chunk in _runs(span):
            sp = [pts[i] for i in chunk]
            phi = math.radians(phi_deg)
            nx, nz = -math.cos(phi), math.sin(phi)      # outward is -side
            tx, tz = math.sin(phi), math.cos(phi)
            rr = R.TR - 0.01
            if g.hi:
                prof2 = [(nx * (rr + d * k) + tx * h * s, nz * (rr + d * k) + tz * h * s)
                         for k, s in ((0, -1), (0.7, -1), (1, -0.6), (1, 0.6), (0.7, 1), (0, 1))]
            else:
                prof2 = [(nx * rr - tx * h, nz * rr - tz * h), (nx * (rr + d) - tx * h * 0.7, nz * (rr + d) - tz * h * 0.7),
                         (nx * (rr + d) + tx * h * 0.7, nz * (rr + d) + tz * h * 0.7), (nx * rr + tx * h, nz * rr + tz * h)]
            R.sweep(g, sp, list(reversed(prof2)), M(g, "RubStrake"), cap0=True, cap1=True)
    # webbing grab handles on the inner top of both tubes
    for sx in (1, -1):
        for y in [-4.6 + 2.3 * k for k in range(6)]:
            c = Vector((sx * R.TX, y, R.TZ))
            phi = math.radians(70)
            n = Vector((-sx * math.cos(phi), 0, math.sin(phi)))  # inward-up
            base = c + n * R.TR
            seg_a = 10 if g.hi else 6
            arc = []
            for k in range(seg_a + 1):
                t = math.pi * k / seg_a
                arc.append(base + Vector((0, -0.26 * math.cos(t), 0)) + n * (0.2 * math.sin(t) + 0.005))
            w, th = 0.075, 0.018
            prof = [(-w, -th), (w, -th), (w, th), (-w, th)]
            R.sweep(g, arc, prof, M(g, "Webbing"), cap0=True, cap1=True)
            # glued patch under each handle
            R.box(g, tuple(base - n * 0.005), (0.24, 0.72, 0.02), M(g, "TubeWear"),
                  rot=Matrix.Rotation(-sx * (math.pi / 2 - phi), 3, "Y"))
    # inflation / topping-up valves on the tube tops (one per chamber)
    for sx in (1, -1):
        for y in (-8.0 if False else -3.4, 2.2, 7.6):
            top = Vector((sx * (R.TX - 0.12), y, R.TZ + R.TR - 0.015))
            R.lathe(g, top, (0, 0, 1), [(0.13, 0.0), (0.13, 0.025), (0.09, 0.04), (0.07, 0.07), (0.0, 0.08)],
                    20 if g.hi else 12, M(g, "BlackPlastic"))
    # bow towing eye on the stem
    c = Vector((0, R.BOW_Y1 - (R.TR - 0.05) - 0.04, R.TZ + R.BOW_RISE))
    R.box(g, tuple(c + Vector((0, 0.02, 0))), (0.36, 0.06, 0.42), M(g, "RubStrake"))
    ring = [c + Vector((0.09 * math.cos(2 * math.pi * k / 10), -0.05, 0.09 * math.sin(2 * math.pi * k / 10)))
            for k in range(10)]
    R.sweep(g, ring + [ring[0]], R.circle_profile(0.028, 8 if g.hi else 5), M(g, "Stainless"), cap0=True, cap1=True)


def _runs(idx):
    out, cur = [], []
    for i in idx:
        if cur and i != cur[-1] + 1:
            out.append(cur)
            cur = []
        cur.append(i)
    if cur:
        out.append(cur)
    return [c for c in out if len(c) > 1]


# =========================================================================== Deck set
_OUTLINE = None


def deck_half(y):
    """Half-width of the deck where the deck plane meets the tube's inner side (interpolated along the tube path)."""
    global _OUTLINE
    if _OUTLINE is None:
        path = R.tube_path(False)
        half = path[:len(path) // 2 + 1]
        fr = R.frames([p for p, r in half])
        pts = []
        for (p, r), (t, side, up) in zip(half, fr):
            if p.y > R.STERN_Y:
                continue
            dz = p.z - R.DECK
            w = math.sqrt(max(0.0, r * r - dz * dz))
            q = p + side * max(0.0, w - 0.04)
            pts.append((q.y, abs(q.x)))
        _OUTLINE = sorted(pts)
    ys = _OUTLINE
    if y <= ys[0][0]:
        return max(0.05, ys[0][1])
    for (y0, x0), (y1, x1) in zip(ys, ys[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / max(1e-6, y1 - y0)
            return max(0.05, x0 + (x1 - x0) * t)
    return ys[-1][1]


def deck(g):
    y0, y1 = -11.4, R.TRANSOM_Y - 0.4
    if not g.hi:
        ys = [y1 - 0.9 * i for i in range(20)] + [-7.6, -8.3, -8.9, -9.5, -10.0, -10.5, -10.9, -11.2, y0]
        rings = []
        for y in ys:
            h = deck_half(y)
            rings.append([Vector((x * h, y, R.DECK)) for x in (-1, -0.5, 0, 0.5, 1)])
        faces = g.rings(rings, "X", closed=False, recalc=False)
        g.orient(faces, lambda c: Vector((0, 0, 1)))
        return
    step = 0.03
    ny = int((y1 - y0) / step)
    nx = 64
    rows = []
    for i in range(ny + 1):
        y = y1 - i * step
        h = deck_half(y)
        rows.append([(u * h, y) for u in [(-1 + 2 * k / nx) for k in range(nx + 1)]])

    def pad(x, y):
        h = deck_half(y)
        if abs(x) > h - 0.28 or abs(x) < 0.1:
            return False
        cell = (y - y0) % 2.1
        return 0.22 < cell < 2.1
    verts = []
    for r in rows:
        vr = []
        for x, y in r:
            z = R.DECK
            if pad(x, y):
                z += 0.012 + R.grit(Vector((x, y, 0.0)), 40.0, 0.004)
            vr.append(g.bm.verts.new(Vector((x, y, z))))
        verts.append(vr)
    faces = []
    for i in range(ny):
        for j in range(nx):
            x, y = rows[i][j]
            m = "NonSlip" if pad(x + 0.01, y - 0.015) else "Gelcoat"
            f = g.face((verts[i][j], verts[i][j + 1], verts[i + 1][j + 1], verts[i + 1][j]), m)
            if f:
                faces.append(f)
    g.orient(faces, lambda c: Vector((0, 0, 1)))


CONSOLE = [(-2.4, R.DECK), (-2.4, 4.45), (-2.2, 4.9), (-1.8, 5.1), (-0.8, 5.1), (-0.05, 4.6), (0.05, 4.45),
           (0.05, R.DECK)]


def console(g):
    def mat(i, j):
        if j in (3, 4):
            return "GelcoatWhite"
        return "HullOrange"
    R.extrude_profile(g, CONSOLE, -1.35, 1.35, M(g, "HullOrange"), matfn=mat if g.hi else None, bev=0.07)
    # console side faces get orange through the cap material (caps use the base mat)
    # windscreen: smoked acrylic, three panes, stainless top frame
    zb, zt = 5.08, 6.3
    yb, yt = -1.82, -2.12
    th = 0.03
    panes = [((-1.15, yb, zb), (1.15, yb, zb), (1.15, yt, zt), (-1.15, yt, zt))]
    for sx in (1, -1):
        panes.append(((sx * 1.15, yb, zb), (sx * 1.34, yb + 0.55, zb), (sx * 1.3, yt + 0.5, zt), (sx * 1.15, yt, zt)))
    for p in panes:
        a = [Vector(v) for v in p]
        n = (a[1] - a[0]).cross(a[3] - a[0]).normalized()
        ring0 = [v - n * th for v in a]
        ring1 = [v + n * th for v in a]
        g.rings([ring0, ring1], M(g, "Acrylic"), cap0=True, cap1=True)
    top = [(1.3, yt + 0.5, zt + 0.03), (1.15, yt, zt + 0.03), (-1.15, yt, zt + 0.03), (-1.3, yt + 0.5, zt + 0.03)]
    R.tube(g, top, 0.035, M(g, "Stainless"), 10 if g.hi else 8, fillet=0.12, fseg=3)
    bolts(g, [(sx * 1.3, yt + 0.5, zt - 0.02) for sx in (1, -1)] + [(sx * 0.6, yt, zt - 0.02) for sx in (1, -1)], (0, 1, 0), "Stainless")
    if g.hi:   # rubber windscreen seal along the console top
        R.box(g, (0, yb + 0.02, zb - 0.01), (2.32, 0.08, 0.04), "Rubber")
    # sidelight housings with lenses (port red +X, starboard green -X)
    for sx, lens in ((1, "LensRed"), (-1, "LensGreen")):
        R.box(g, (sx * 1.40, -2.0, 4.72), (0.1, 0.42, 0.22), M(g, "BlackPlastic"))
        R.box(g, (sx * 1.455, -2.0, 4.72), (0.02, 0.34, 0.15), M(g, lens))


def fittings(g):
    seg = 24 if g.hi else 16
    # bow locker hatch
    R.box(g, (0, -8.1, R.DECK + 0.04), (2.0, 1.7, 0.08), M(g, "GelcoatWhite"))
    for sx in (1, -1):
        R.box(g, (sx * 0.6, -8.98, R.DECK + 0.06), (0.25, 0.08, 0.06), M(g, "Stainless"))
    R.box(g, (0, -7.22, R.DECK + 0.07), (0.4, 0.06, 0.05), M(g, "Stainless"))
    # tow post (samson post) with cross pin at the stern
    R.lathe(g, (0, 10.45, R.DECK), (0, 0, 1), [(0.26, 0), (0.26, 0.05), (0.15, 0.08), (0.15, 0.75), (0.19, 0.8),
                                              (0.19, 0.86), (0.0, 0.9)], seg, M(g, "Stainless"))
    R.tube(g, [(-0.42, 10.45, R.DECK + 0.62), (0.42, 10.45, R.DECK + 0.62)], 0.045, M(g, "Stainless"), seg // 2)
    # fuel fillers and deck drains near the transom
    for sx in (1, -1):
        R.lathe(g, (sx * 2.2, 9.4, R.DECK), (0, 0, 1), [(0.16, 0), (0.16, 0.03), (0.11, 0.05), (0.0, 0.06)], seg,
                M(g, "Stainless"))
        R.box(g, (sx * 1.9, 10.25, R.DECK + 0.01), (0.5, 0.24, 0.02), M(g, "BlackPlastic"))
    # casualty D-rings in the forward well
    for sx in (1, -1):
        for y in (-6.3, -3.8):
            R.box(g, (sx * 2.1, y, R.DECK + 0.015), (0.18, 0.14, 0.03), M(g, "Stainless"))
            ring = [Vector((sx * 2.1, y + 0.07 * math.cos(math.pi * k / 6), R.DECK + 0.03 + 0.08 * math.sin(math.pi * k / 6)))
                    for k in range(7)]
            R.sweep(g, ring, R.circle_profile(0.016, 6), M(g, "Stainless"), cap0=True, cap1=True)
    # transom lifting eyes and drain bungs
    for sx in (1, -1):
        R.box(g, (sx * 2.5, R.TRANSOM_Y + 0.04, R.DECK + 0.18), (0.22, 0.08, 0.2), M(g, "Stainless"))
        R.lathe(g, (sx * 0.5, R.TRANSOM_Y + 0.01, 1.0), (0, 1, 0), [(0.09, 0.0), (0.09, 0.04), (0.06, 0.06), (0.0, 0.07)],
                12, M(g, "Stainless"))
    # console foot plinth
    R.box(g, (0, -1.18, R.DECK + 0.04), (2.82, 2.6, 0.08), M(g, "Gelcoat"))
    D = R.DECK
    # fasteners on the existing fittings
    bolts(g, [(sx * 0.6 + dx, -8.98, D + 0.09) for sx in (1, -1) for dx in (-0.08, 0.08)], (0, 0, 1))
    bolts(g, [(0.2 * math.cos(a), 10.45 + 0.2 * math.sin(a), D + 0.05) for a in [k * math.pi / 3 for k in range(6)]], (0, 0, 1))
    bolts(g, [(sx * 2.1 + dx, y, D + 0.03) for sx in (1, -1) for y in (-6.3, -3.8) for dx in (-0.06, 0.06)], (0, 0, 1))
    # cleats (bow pair, stern pair)
    for x, y in ((1.45, -9.3), (-1.45, -9.3), (2.35, 9.9), (-2.35, 9.9)):
        R.box(g, (x, y, D + 0.03), (0.14, 0.42, 0.06), M(g, "Stainless"))
        for dy in (-0.09, 0.09):
            R.box(g, (x, y + dy, D + 0.1), (0.07, 0.07, 0.1), M(g, "Stainless"))
        R.tube(g, [(x, y - 0.26, D + 0.17), (x, y + 0.26, D + 0.17)], 0.035, M(g, "Stainless"), 10 if g.hi else 6)
        bolts(g, [(x, y + dy, D + 0.06) for dy in (-0.17, 0.17)], (0, 0, 1))
    # bow fairleads either side of the stem
    for sx in (1, -1):
        x, y = sx * 0.42, -10.75
        R.box(g, (x, y, D + 0.025), (0.2, 0.36, 0.05), M(g, "Stainless"))
        for dx in (-0.07, 0.07):
            R.box(g, (x + dx, y, D + 0.1), (0.04, 0.3, 0.12), M(g, "Stainless"))
        R.tube(g, [(x - 0.07, y, D + 0.16), (x + 0.07, y, D + 0.16)], 0.025, M(g, "Stainless"), 8 if g.hi else 6)
        bolts(g, [(x, y + dy, D + 0.05) for dy in (-0.13, 0.13)], (0, 0, 1))
    # lashing pad eyes along the deck edges
    for sx in (1, -1):
        for y in (-5.0, -1.0, 3.0, 7.0):
            x = sx * (deck_half(y) - 0.32)
            R.box(g, (x, y, D + 0.012), (0.16, 0.24, 0.024), M(g, "Stainless"))
            ring = [Vector((x, y + 0.08 * math.cos(math.pi * k / 6), D + 0.024 + 0.07 * math.sin(math.pi * k / 6)))
                    for k in range(7)]
            R.sweep(g, ring, R.circle_profile(0.015, 6 if g.hi else 4), M(g, "Stainless"), cap0=True, cap1=True)
            bolts(g, [(x, y + dy, D + 0.024) for dy in (-0.09, 0.09)], (0, 0, 1))
    # round inspection hatches and the stern stowage locker (hinges, latch)
    for sx in (1, -1):
        R.lathe(g, (sx * 1.55, 7.4, D), (0, 0, 1), [(0.36, 0.0), (0.36, 0.04), (0.31, 0.06), (0.29, 0.05), (0.0, 0.055)],
                24 if g.hi else 14, M(g, "BlackPlastic"))
        if g.hi:
            for k in range(4):
                a = k * math.pi / 4
                R.box(g, (sx * 1.55, 7.4, D + 0.06), (0.5 * abs(math.cos(a)) + 0.03, 0.5 * abs(math.sin(a)) + 0.03, 0.012),
                      "BlackPlastic", rot=Matrix.Rotation(a, 3, "Z"))
            bolts(g, [(sx * 1.55 + 0.335 * math.cos(a), 7.4 + 0.335 * math.sin(a), D + 0.04)
                      for a in [k * math.pi / 4 for k in range(8)]], (0, 0, 1))
    R.box(g, (0, 8.5, D + 0.035), (1.7, 1.1, 0.07), M(g, "GelcoatWhite"))
    for x in (-0.55, 0.55):
        R.box(g, (x, 9.07, D + 0.06), (0.22, 0.06, 0.04), M(g, "Stainless"))
        R.tube(g, [(x - 0.1, 9.1, D + 0.08), (x + 0.1, 9.1, D + 0.08)], 0.02, M(g, "Stainless"), 8 if g.hi else 5)
    R.box(g, (0, 7.93, D + 0.08), (0.3, 0.06, 0.04), M(g, "BlackPlastic"))
    if g.hi:
        R.box(g, (0, 8.5, D + 0.071), (1.62, 0.02, 0.004), "Vent")     # lid gutter line
    # transom scuppers: dark outlets with rubber flaps
    for sx in (1, -1):
        R.box(g, (sx * 1.05, R.TRANSOM_Y + 0.015, D - 0.12), (0.4, 0.03, 0.18), M(g, "Vent"))
        R.box(g, (sx * 1.05, R.TRANSOM_Y + 0.05, D - 0.1), (0.44, 0.02, 0.22), M(g, "Rubber"),
              rot=Matrix.Rotation(math.radians(-12), 3, "X"))
        bolts(g, [(sx * 1.05 + dx, R.TRANSOM_Y + 0.06, D + 0.02) for dx in (-0.16, 0.16)], (0, 1, 0))


# =========================================================================== Rig set
AF_BASE = 10.15
AF_TOP = 8.15


def aframe(g):
    seg = 24 if g.hi else 18
    r = 0.15
    pts = [(2.85, AF_BASE + 0.15, R.DECK + 0.05), (2.45, AF_BASE - 0.05, AF_TOP), (-2.45, AF_BASE - 0.05, AF_TOP),
           (-2.85, AF_BASE + 0.15, R.DECK + 0.05)]
    R.tube(g, pts, r, M(g, "HullOrange"), seg, fillet=0.5, fseg=8)
    for sx in (1, -1):
        R.box(g, (sx * 2.85, AF_BASE + 0.15, R.DECK + 0.03), (0.5, 0.5, 0.06), M(g, "Aluminium"))
        R.box(g, (sx * 2.84, AF_BASE + 0.15, R.DECK + 0.25), (0.08, 0.36, 0.4), M(g, "Aluminium"))
    # mid rail and diagonal stays to the transom
    R.tube(g, [(2.63, AF_BASE + 0.05, 5.3), (-2.63, AF_BASE + 0.05, 5.3)], 0.09, M(g, "HullOrange"), seg // 2 + 2)
    # radar platform, dome, beacon, masthead light, stern light, searchlight
    zt = AF_TOP + r
    R.box(g, (0, AF_BASE - 0.05, zt + 0.03), (1.7, 0.9, 0.06), M(g, "Aluminium"))
    R.lathe(g, (0, AF_BASE - 0.05, zt + 0.06), (0, 0, 1),
            [(0.12, 0), (0.12, 0.05), (0.68, 0.06), (0.69, 0.12), (0.69, 0.4), (0.62, 0.5), (0.45, 0.6), (0.2, 0.66),
             (0.0, 0.67)], 48 if g.hi else 36, M(g, "GelcoatWhite"),
            matfn=(lambda i, j: "BlackPlastic" if i < 2 else "GelcoatWhite") if g.hi else None)
    for sx, lens, name in ((1, "LensBlue", "beacon"), (-1, "LensWhite", "masthead")):
        x = sx * 1.25
        R.box(g, (x, AF_BASE - 0.05, zt + 0.04), (0.3, 0.3, 0.08), M(g, "Aluminium"))
        h = 0.36 if name == "beacon" else 0.22
        R.lathe(g, (x, AF_BASE - 0.05, zt + 0.08), (0, 0, 1),
                [(0.13, 0), (0.13, 0.08), (0.11, 0.09), (0.11, 0.09 + h), (0.08, 0.12 + h), (0.0, 0.14 + h)],
                seg, M(g, lens), matfn=(lambda i, j: "BlackPlastic" if i < 1 or i >= 3 else lens) if g.hi else None)
    R.box(g, (0, AF_BASE + 0.12, AF_TOP - 0.25), (0.22, 0.12, 0.16), M(g, "BlackPlastic"))
    R.box(g, (0, AF_BASE + 0.19, AF_TOP - 0.25), (0.16, 0.02, 0.1), M(g, "LensWhite"))
    R.lathe(g, (-0.62, AF_BASE - 0.05, zt + 0.06), (0, 0, 1), [(0.08, 0), (0.08, 0.2), (0.0, 0.21)], seg // 2, M(g, "BlackPlastic"))
    R.lathe(g, (-0.62, AF_BASE - 0.35, zt + 0.38), (0, -1, 0),
            [(0.0, -0.15), (0.16, -0.15), (0.18, 0.0), (0.18, 0.12), (0.16, 0.14), (0.0, 0.14)], seg, M(g, "BlackPlastic"),
            matfn=(lambda i, j: "LensWhite" if i >= 4 else "BlackPlastic") if g.hi else None)
    # light bar on the forward edge of the radar platform: blue strobes and white floods
    R.box(g, (0, AF_BASE - 0.56, zt + 0.14), (2.0, 0.2, 0.18), M(g, "BlackPlastic"))
    for k in range(8):
        x = -0.875 + 0.25 * k
        R.box(g, (x, AF_BASE - 0.665, zt + 0.14), (0.2, 0.02, 0.11), M(g, "LensBlue" if k in (0, 1, 6, 7) else "LensWhite"))
    for sx in (1, -1):
        R.box(g, (sx * 0.8, AF_BASE - 0.5, zt + 0.06), (0.1, 0.25, 0.08), M(g, "Aluminium"))
        bolts(g, [(sx * 0.8, AF_BASE - 0.5 + dy, zt + 0.1) for dy in (-0.07, 0.07)], (0, 0, 1))
    # VHF / AIS whips on ratchet mounts at the aft platform corners, raked aft
    for sx in (1, -1):
        b = Vector((sx * 0.72, AF_BASE + 0.32, zt + 0.06))   # whips lowered aft on the ratchet (transit position)
        R.box(g, tuple(b + Vector((0, 0, 0.08))), (0.12, 0.12, 0.16), M(g, "Aluminium"))
        R.lathe(g, tuple(b + Vector((0, 0, 0.16))), (0, 0.95, 0.31), [(0.045, 0.0), (0.045, 0.25), (0.03, 0.3), (0.0, 0.31)],
                10 if g.hi else 6, M(g, "BlackPlastic"))
        R.lathe(g, tuple(b + Vector((0, 0.05, 0.46))), (0, 0.95, 0.31), [(0.03, 0.0), (0.012, 2.2), (0.0, 2.22)],
                8 if g.hi else 5, M(g, "GelcoatWhite"))
    # platform and foot-plate fasteners
    bolts(g, [(sx * 0.78, AF_BASE - 0.05 + sy * 0.38, zt + 0.06) for sx in (1, -1) for sy in (1, -1)], (0, 0, 1))
    bolts(g, [(sx * 2.85 + dx, AF_BASE + 0.15 + dy, R.DECK + 0.06) for sx in (1, -1) for dx in (-0.18, 0.18)
              for dy in (-0.18, 0.18)], (0, 0, 1))
    # cable runs down the starboard leg (radar, lights, aerials) with clips, into a deck gland
    a, b = Vector((-2.45, AF_BASE - 0.05, AF_TOP)), Vector((-2.85, AF_BASE + 0.15, R.DECK + 0.05))
    for k, off in enumerate((0.21, 0.26)):
        cp = [Vector((-0.5 - 0.3 * k, AF_BASE - 0.05 + off * 0.0 + 0.2, zt + 0.07)), Vector((-2.2, AF_BASE + 0.12 + 0.06 * k, AF_TOP + 0.05))]
        for t in (0.08, 0.3, 0.55, 0.8, 0.97):
            q = a.lerp(b, t)
            cp.append(q + Vector((0.0, off, 0.0)))
        cp.append(Vector((-2.85 + 0.25, AF_BASE + 0.15 + off, R.DECK + 0.08)))
        R.tube(g, [tuple(v) for v in cp], 0.022, M(g, "Cable"), 8 if g.hi else 5, fillet=0.15, fseg=3)
    for t in (0.2, 0.45, 0.7):
        q = a.lerp(b, t)
        R.box(g, tuple(q + Vector((0, 0.235, 0))), (0.06, 0.12, 0.05), M(g, "BlackPlastic"))
    R.box(g, (-2.6, AF_BASE + 0.4, R.DECK + 0.06), (0.2, 0.16, 0.12), M(g, "BlackPlastic"))
    # GPS puck and short aerial bases
    R.lathe(g, (0.62, AF_BASE - 0.05, zt + 0.06), (0, 0, 1), [(0.12, 0), (0.12, 0.06), (0.08, 0.1), (0.0, 0.11)], seg,
            M(g, "GelcoatWhite"))


ENG_X = (1.3, -1.3)
ENG_Y = 12.1


def outboard(g, x):
    seg = 40 if g.hi else 32
    y = ENG_Y
    # top cowl (superellipse loft)
    secs = [(x, y, 3.05, 0.5, 0.78), (x, y, 3.2, 0.6, 0.86), (x, y, 3.9, 0.62, 0.86), (x, y + 0.02, 4.35, 0.59, 0.8),
            (x, y + 0.05, 4.58, 0.5, 0.66), (x, y + 0.08, 4.7, 0.33, 0.42), (x, y + 0.1, 4.74, 0.05, 0.06)]
    def cowl(i, j):
        return "CowlLight" if i == 0 else "CowlGrey"
    R.loft(g, secs, seg, M(g, "CowlGrey"), cap0=True, cap1=True, p=3.2, matfn=cowl if g.hi else None)
    # lower cowl / midsection and the leg
    secs2 = [(x, y - 0.05, 1.85, 0.3, 0.42), (x, y - 0.08, 2.4, 0.42, 0.62), (x, y - 0.08, 3.06, 0.48, 0.74)]
    R.loft(g, secs2, seg, M(g, "CowlLight"), cap0=False, cap1=False, p=2.6)
    secs3 = [(x, y - 0.05, 0.95, 0.15, 0.4), (x, y - 0.05, 1.4, 0.17, 0.42), (x, y - 0.05, 1.86, 0.3, 0.42)]
    R.loft(g, secs3, seg, M(g, "CowlLight"), cap0=False, cap1=False, p=2.0)
    # anti-ventilation plate
    R.loft(g, [(x, y + 0.1, 0.92, 0.36, 0.62), (x, y + 0.1, 0.97, 0.36, 0.62)], seg, M(g, "CowlLight"), p=2.4)
    # gearcase torpedo, skeg, propeller
    R.lathe(g, (x, y - 0.42, 0.62), (0, 1, 0), [(0.0, 0.0), (0.09, 0.05), (0.15, 0.2), (0.16, 0.45), (0.14, 0.72),
                                                (0.1, 0.8)], seg, M(g, "CowlLight"))
    R.loft(g, [(x, y - 0.08, 0.6, 0.15, 0.32), (x, y - 0.1, 0.62, 0.15, 0.32)], seg, M(g, "CowlLight"), p=2.0)
    skeg = [(y - 0.15, 0.55), (y + 0.2, 0.55), (y + 0.24, 0.0), (y + 0.02, 0.02)]
    R.extrude_profile(g, skeg, x - 0.03, x + 0.03, M(g, "CowlLight"))
    R.lathe(g, (x, y + 0.38, 0.62), (0, 1, 0), [(0.1, 0.0), (0.09, 0.22), (0.05, 0.3), (0.0, 0.32)], seg, M(g, "Aluminium"))
    for b in range(3):
        a0 = 2 * math.pi * b / 3
        rings = []
        for k in range(6 if not g.hi else 9):
            t = k / (5 if not g.hi else 8)
            rr = 0.09 + t * 0.41
            ang = a0 + 0.35 * t
            chord = 0.2 * math.sin(math.pi * (0.25 + 0.6 * t))
            pitch = 0.6
            c = Vector((x + rr * math.cos(ang), y + 0.46, 0.62 + rr * math.sin(ang)))
            tdir = Vector((-math.sin(ang), 0, math.cos(ang)))
            ax = Vector((0, 1, 0))
            d = (tdir * math.cos(pitch) + ax * math.sin(pitch)) * chord
            rings.append([c - d, c + d])
        g.rings(rings, M(g, "Aluminium"), closed=False)
    if g.hi:
        # cowl parting-line seal and the aft / side intake vents
        R.loft(g, [(x, y, 3.03, 0.515, 0.795), (x, y, 3.1, 0.515, 0.795)], seg, "Rubber", cap0=False, cap1=False, p=3.2)
        R.box(g, (x, y + 0.815, 4.28), (0.62, 0.04, 0.32), "Vent", rot=Matrix.Rotation(math.radians(-14), 3, "X"))
        for k in range(5):
            R.box(g, (x, y + 0.84 - 0.012 * k, 4.15 + 0.065 * k), (0.6, 0.03, 0.025), "CowlGrey",
                  rot=Matrix.Rotation(math.radians(-14), 3, "X"))
        for sx in (1, -1):
            R.box(g, (x + sx * 0.6, y + 0.35, 4.2), (0.04, 0.5, 0.18), "Vent")
            for k in range(4):
                R.box(g, (x + sx * 0.615, y + 0.35, 4.13 + 0.045 * k), (0.03, 0.48, 0.018), "CowlGrey")
    # idle exhaust relief and the tell-tale on the midsection's aft face
    R.lathe(g, (x, y + 0.5, 2.3), (0, 1, 0), [(0.11, -0.02), (0.11, 0.02), (0.08, 0.035), (0.075, 0.0), (0.0, -0.01)],
            16 if g.hi else 8, M(g, "Vent"), matfn=(lambda i, j: "Rubber" if i < 2 else "Vent") if g.hi else None)
    R.lathe(g, (x + 0.2, y + 0.42, 2.75), (0, 1, 0), [(0.025, -0.02), (0.025, 0.02), (0.0, 0.025)], 8, M(g, "BlackPlastic"))
    # trim tab under the plate
    R.box(g, (x, y + 0.36, 0.86), (0.07, 0.32, 0.05), M(g, "Aluminium"))
    # power trim / tilt: twin rams between clamp bracket and swivel
    for dx in (-0.2, 0.2):
        R.tube(g, [(x + dx, R.TRANSOM_Y + 0.34, 1.9), (x + dx, y - 0.62, 2.45)], 0.075, M(g, "Aluminium"), 12 if g.hi else 8)
        R.tube(g, [(x + dx, y - 0.65, 2.47), (x + dx, y - 0.48, 2.58)], 0.035, M(g, "Stainless"), 8 if g.hi else 6)
    R.box(g, (x, R.TRANSOM_Y + 0.3, 1.95), (0.5, 0.18, 0.22), M(g, "Aluminium"))
    bolts(g, [(x + dx, R.TRANSOM_Y + 0.42, z) for dx in (-0.2, 0.2) for z in (1.95, 2.6)], (0, 1, 0))
    # steering arm forward of the swivel
    R.box(g, (x, y - 0.62, 3.12), (0.12, 0.4, 0.1), M(g, "Aluminium"))
    # rigging: fuel line and cable bundle in a corrugated boot from the transom to the cowl front
    sg = [(x * 0.62, R.TRANSOM_Y + 0.05, 2.95), (x * 0.75, R.TRANSOM_Y + 0.4, 2.7), (x * 0.9, y - 0.95, 2.62), (x, y - 0.72, 2.9)]
    R.tube(g, sg, 0.075, M(g, "Rubber"), 12 if g.hi else 6, fillet=0.18, fseg=3)
    R.tube(g, [(p[0] + 0.1, p[1], p[2] + 0.02) for p in sg[:3]] + [(x + 0.12, y - 0.74, 2.8)], 0.032, M(g, "Cable"),
           8 if g.hi else 5, fillet=0.18, fseg=3)
    if g.hi:
        for k in range(10):
            q = Vector(sg[1]).lerp(Vector(sg[2]), k / 9)
            R.lathe(g, tuple(q), (0, 1, 0), [(0.085, -0.012), (0.085, 0.012)], 12, "Rubber")
    # transom clamp bracket and steering tube
    R.box(g, (x, R.TRANSOM_Y + 0.22, 2.35), (0.56, 0.36, 1.1), M(g, "BlackPlastic"))
    R.tube(g, [(x, R.TRANSOM_Y + 0.25, 3.0), (x, y - 0.3, 3.0)], 0.07, M(g, "Stainless"), 12)
    R.box(g, (x, y - 0.75, 2.75), (0.3, 0.3, 0.5), M(g, "CowlGrey"))


def engines(g):
    for x in ENG_X:
        outboard(g, x)
    # steering tie bar between the two arms, with rod ends; hydraulic steering cylinder on the starboard tilt tube
    R.tube(g, [(ENG_X[0], ENG_Y - 0.8, 3.15), (ENG_X[1], ENG_Y - 0.8, 3.15)], 0.04, M(g, "Stainless"), 10 if g.hi else 6)
    for x in ENG_X:
        R.box(g, (x, ENG_Y - 0.8, 3.15), (0.12, 0.12, 0.12), M(g, "Stainless"))
    R.tube(g, [(ENG_X[1] - 0.45, R.TRANSOM_Y + 0.45, 2.85), (ENG_X[1] + 0.45, R.TRANSOM_Y + 0.45, 2.85)], 0.075,
           M(g, "Aluminium"), 12 if g.hi else 8)
    R.tube(g, [(ENG_X[1] + 0.45, R.TRANSOM_Y + 0.45, 2.85), (ENG_X[1] + 0.75, R.TRANSOM_Y + 0.45, 2.85)], 0.03,
           M(g, "Stainless"), 8 if g.hi else 6)


# =========================================================================== Decals set
DEC_OFF = 0.035


def tube_patch(g, sx, y0, y1, th0, th1, mat, off, nu=10, nv=6):
    rr = R.TR + off
    rings = []
    for i in range(nu + 1):
        y = y0 + (y1 - y0) * i / nu
        rings.append([Vector((sx * (R.TX + rr * math.cos(th0 + (th1 - th0) * j / nv)), y,
                              R.TZ + rr * math.sin(th0 + (th1 - th0) * j / nv))) for j in range(nv + 1)])
    faces = g.rings(rings, mat, closed=False, recalc=False)
    g.orient(faces, lambda c: Vector((c.x - sx * R.TX, 0, c.z - R.TZ)))


def tube_text(g, sx, yc, thc, body, size, mat, off, scale_x=1.0):
    me = R.text_mesh(body, size, font_scale_x=scale_x)
    rr = R.TR + off

    def mp(co):
        u, v = co.x, co.y
        th = thc + v / rr
        y = yc + (u if sx > 0 else -u)
        return Vector((sx * (R.TX + rr * math.cos(th)), y, R.TZ + rr * math.sin(th)))
    faces = g.add_mesh(me, mat, mp)
    g.orient(faces, lambda c: Vector((c.x - sx * R.TX, 0, c.z - R.TZ)))
    bpy.data.meshes.remove(me)


NAME_PANEL = (-3.6, 6.4, math.radians(-8), math.radians(36))
NUM_PANEL = (-5.95, -4.25, math.radians(-8), math.radians(36))
CREST = (-1.15, 3.42, 0.5)   # console side: y centre, z centre, radius


def crest(g, sx, off_base, layers):
    yc, zc, rad = CREST
    x0 = sx * 1.35

    def P(u, v, k):
        return Vector((x0 + sx * (off_base + 0.004 * k), yc + (u if sx > 0 else -u), zc + v))

    def disc(r0, r1, k, mat, n=40):
        if r0 <= 0:
            c = g.bm.verts.new(P(0, 0, k))
            ring = [g.bm.verts.new(P(r1 * math.cos(2 * math.pi * i / n), r1 * math.sin(2 * math.pi * i / n), k)) for i in range(n)]
            fs = [g.face((c, ring[i], ring[(i + 1) % n]), mat) for i in range(n)]
        else:
            a = [g.bm.verts.new(P(r0 * math.cos(2 * math.pi * i / n), r0 * math.sin(2 * math.pi * i / n), k)) for i in range(n)]
            b = [g.bm.verts.new(P(r1 * math.cos(2 * math.pi * i / n), r1 * math.sin(2 * math.pi * i / n), k)) for i in range(n)]
            fs = [g.face((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]), mat) for i in range(n)]
        fs = [f for f in fs if f]
        g.orient(fs, lambda c: Vector((sx, 0, 0)))

    def poly(pts, k, mat):
        vs = [g.bm.verts.new(P(u, v, k)) for u, v in pts]
        f = g.face(vs, mat)
        if f:
            res = bmesh.ops.triangulate(g.bm, faces=[f])
            g.orient(res["faces"], lambda c: Vector((sx, 0, 0)))
    if not layers:
        disc(0, rad, 0, "X", n=20)
        return
    disc(0, rad, 0, "PanelNavy")
    disc(rad * 0.86, rad * 0.95, 1, "LetterWhite")
    # compass rose: 8 points
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 2
        L = rad * (0.8 if i % 2 == 0 else 0.5)
        w = 0.07 * rad / 0.5
        tip = (L * math.cos(a), L * math.sin(a))
        l = (w * math.cos(a + math.pi / 2), w * math.sin(a + math.pi / 2))
        r = (w * math.cos(a - math.pi / 2), w * math.sin(a - math.pi / 2))
        poly([l, tip, r], 2, "LetterWhite")
    # lighthouse: tapered tower with a charcoal band, lantern, cap
    s = rad / 0.5
    poly([(-0.08 * s, -0.3 * s), (0.08 * s, -0.3 * s), (0.055 * s, 0.12 * s), (-0.055 * s, 0.12 * s)], 3, "PanelConsole")
    poly([(-0.07 * s, -0.12 * s), (0.07 * s, -0.12 * s), (0.065 * s, -0.04 * s), (-0.065 * s, -0.04 * s)], 4, "LetterWhite")
    poly([(-0.045 * s, 0.13 * s), (0.045 * s, 0.13 * s), (0.045 * s, 0.21 * s), (-0.045 * s, 0.21 * s)], 3, "LetterWhite")
    poly([(-0.07 * s, 0.21 * s), (0.07 * s, 0.21 * s), (0.0, 0.29 * s)], 3, "PanelConsole")
    poly([(-0.1 * s, -0.33 * s), (0.1 * s, -0.33 * s), (0.1 * s, -0.3 * s), (-0.1 * s, -0.3 * s)], 3, "PanelConsole")


def tube_poly(g, sx, yc, thc, pts, mat, off):
    """Flat polygon in (u along the tube, v around it) mapped onto the tube surface (subdivided for the curve)."""
    rr = R.TR + off

    def mp(u, v):
        th = thc + v / rr
        return Vector((sx * (R.TX + rr * math.cos(th)), yc + (u if sx > 0 else -u), R.TZ + rr * math.sin(th)))
    vs = [g.bm.verts.new(mp(u, v)) for u, v in pts]
    f = g.face(vs, mat)
    if f:
        res = bmesh.ops.triangulate(g.bm, faces=[f])
        g.orient(res["faces"], lambda c: Vector((c.x - sx * R.TX, 0, c.z - R.TZ)))


CHEV = (7.1, 10.7, math.radians(-8), math.radians(36))


def chevrons(g, sx):
    y0, y1, a, b = CHEV
    yc, thc = (y0 + y1) / 2, (a + b) / 2
    hv = (b - a) / 2 * (R.TR + DEC_OFF) * 0.96
    L = (y1 - y0) / 2 * 0.98
    w, step = 0.22, 0.44
    k = -L - hv
    i = 0
    while k < L:
        # chevron arms leaning toward the bow; clipped to the panel
        def clip(u):
            return max(-L, min(L, u))
        quad = [(clip(k), -hv), (clip(k + w), -hv), (clip(k + w + hv), 0.0), (clip(k + hv), 0.0)]
        quad2 = [(clip(k + hv), 0.0), (clip(k + w + hv), 0.0), (clip(k + w), hv), (clip(k), hv)]
        for q in (quad, quad2):
            if abs(q[0][0] - q[1][0]) + abs(q[2][0] - q[3][0]) > 0.01:
                tube_poly(g, sx, yc, thc, q, "ChevronYellow" if i % 2 else "ChevronSilver", DEC_OFF + 0.004)
        k += step
        i += 1


def console_text(g, sx, body, size, yc, zc, mat, off):
    me = R.text_mesh(body, size)
    x0 = sx * 1.35

    def mp(co):
        return Vector((x0 + sx * off, yc + (co.x if sx > 0 else -co.x), zc + co.y))
    faces = g.add_mesh(me, mat, mp)
    g.orient(faces, lambda c: Vector((sx, 0, 0)))
    bpy.data.meshes.remove(me)


def console_patch(g, sx, yc, zc, w, h, mat, off):
    x0 = sx * (1.35 + off)
    vs = [g.bm.verts.new(Vector((x0, yc + du * w / 2, zc + dv * h / 2))) for du, dv in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = g.face(vs, mat)
    if f:
        g.orient([f], lambda c: Vector((sx, 0, 0)))


def decals(g):
    for sx in (1, -1):
        y0, y1, a, b = NAME_PANEL
        if g.hi:
            tube_patch(g, sx, y0, y1, a, b, "PanelOrange", DEC_OFF, nu=40, nv=12)
            tube_text(g, sx, (y0 + y1) / 2, (a + b) / 2 - 0.01, "GALE ISLES COASTGUARD", 0.52, "LetterNavy", DEC_OFF + 0.004, 0.92)
        else:
            tube_patch(g, sx, y0, y1, a, b, "X", DEC_OFF, nu=20, nv=8)
        y0, y1, a, b = NUM_PANEL
        if g.hi:
            tube_patch(g, sx, y0, y1, a, b, "PanelOrange", DEC_OFF, nu=12, nv=12)
            tube_text(g, sx, (y0 + y1) / 2, (a + b) / 2 - 0.01, "GI-21", 0.6, "LetterNavy", DEC_OFF + 0.004)
        else:
            tube_patch(g, sx, y0, y1, a, b, "X", DEC_OFF, nu=4, nv=8)
        y0, y1, a, b = CHEV
        if g.hi:
            tube_patch(g, sx, y0, y1, a, b, "PanelNavy", DEC_OFF, nu=16, nv=12)
            chevrons(g, sx)
        else:
            tube_patch(g, sx, y0, y1, a, b, "X", DEC_OFF, nu=8, nv=8)
        crest(g, sx, 0.012, g.hi)
        # RESCUE on the console sides above the crest, a station plate below it
        if g.hi:
            console_patch(g, sx, -1.15, 4.18, 2.1, 0.4, "PanelConsole", 0.012)
            console_text(g, sx, "RESCUE", 0.3, -1.15, 4.18, "LetterNavy", 0.016)
            console_patch(g, sx, -1.15, 2.72, 1.3, 0.28, "PanelNavy", 0.012)
            console_text(g, sx, "STATION 7  PORT GALE", 0.13, -1.15, 2.72, "LetterWhite", 0.016)
        else:
            console_patch(g, sx, -1.15, 4.18, 2.1, 0.4, "X", 0.012)
            console_patch(g, sx, -1.15, 2.72, 1.3, 0.28, "X", 0.012)


# =========================================================================== collision, attachments
def collision():
    bm = bmesh.new()
    pts = []
    for y in (-12.9, -11.6, -9.5, -6.0, 0.0, 6.0, 11.0, 12.15):
        cx, cz, r = R.tube_frame(min(y, R.STERN_Y))
        rr = r if y < 12.0 else 0.4
        f = min(1.0, max(0.0, (-y - 2.0) / 9.2))
        zk = R.K + 1.35 * f ** 2.2
        pts += [(0, y, zk), (cx * 0.6, y, zk + 0.6), (-cx * 0.6, y, zk + 0.6)]
        for a in range(0, 360, 45):
            t = math.radians(a)
            for s in (1, -1):
                pts.append((s * (cx + rr * math.cos(t)), y, cz + rr * math.sin(t)))
    vs = [bm.verts.new(p) for p in pts]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list(set(res.get("geom_interior", []) + res.get("geom_unused", [])))
    vjunk = [v for v in junk if isinstance(v, bmesh.types.BMVert)]
    if vjunk:
        bmesh.ops.delete(bm, geom=vjunk, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(NAME + "_COL")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(NAME + "_COL", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def gb(rx, ry, rz):
    """Greybox (Roblox model space, deck at y 0) -> this model's Blender frame."""
    return (-rx, rz, ry + R.DECK)


ATTACHMENTS = {
    "ATT_DriverSeat": gb(0, 2.25, 1.6),
    "ATT_EyePoint": gb(0, 2.25 + 2.7, 1.6 - 0.5),
    "ATT_PassengerSeat1": gb(-1.3, 2.25, 4.8),
    "ATT_PassengerSeat2": gb(1.3, 2.25, 4.8),
    "ATT_SurvivorSlot1": gb(-1.3, 0.1, -5.0),
    "ATT_SurvivorSlot2": gb(1.3, 0.1, -5.0),
    "ATT_TowHitch": (0.0, 10.45, R.DECK + 0.62),
    "ATT_BowPoint": (0.0, R.BOW_Y1 - R.TR - 0.1, R.TZ + R.BOW_RISE),
    "ATT_DriveAttachment": gb(0, -0.85, 0.9),
    "ATT_NavPort": (1.47, -2.0, 4.72),
    "ATT_NavStarboard": (-1.47, -2.0, 4.72),
    "ATT_NavMasthead": (-1.25, AF_BASE - 0.05, AF_TOP + 0.15 + 0.3),
    "ATT_NavStern": (0.0, AF_BASE + 0.21, AF_TOP - 0.25),
    "ATT_Beacon": (1.25, AF_BASE - 0.05, AF_TOP + 0.15 + 0.36),
    "ATT_Searchlight": (-0.62, AF_BASE - 0.5, AF_TOP + 0.53),
    "ATT_Prop1": (ENG_X[0], ENG_Y + 0.46, 0.62),
    "ATT_Prop2": (ENG_X[1], ENG_Y + 0.46, 0.62),
}
FLOATS = [(-2.2, -9), (2.2, -9), (-3.4, -3), (3.4, -3), (-3.6, 3), (3.6, 3), (-3.6, 9), (3.6, 9)]


def build():
    unwrap = rbxkit.smart_uv
    hull_set = R.build_set("Hull", [(NAME + "_Hull_LOD0", hull), (NAME + "_Tubes_LOD0", tubes)], unwrap, "MI_RIB_Hull")
    deck_set = R.build_set("Deck", [(NAME + "_Deck_LOD0", lambda g: (deck(g), fittings(g))),
                                    (NAME + "_Console_LOD0", console)], unwrap, "MI_RIB_Deck")
    rig_set = R.build_set("Rig", [(NAME + "_AFrame_LOD0", aframe), (NAME + "_Engines_LOD0", engines)], unwrap, "MI_RIB_Rig")
    dec_set = R.build_set("Decals", [(NAME + "_Decals_LOD0", decals)], unwrap, "MI_RIB_Decals", angle=70)

    hps = [
        R.build_hp(NAME + "_Hull_HP", [hull], bevel=None),
        R.build_hp(NAME + "_Tubes_HP", [tubes]),
        R.build_hp(NAME + "_Deck_HP", [deck, fittings]),
        R.build_hp(NAME + "_Console_HP", [console], bevel=dict(width=0.04, segments=3, angle=30)),
        R.build_hp(NAME + "_AFrame_HP", [aframe], bevel=dict(width=0.02, segments=2, angle=40)),
        R.build_hp(NAME + "_Engines_HP", [engines], bevel=dict(width=0.015, segments=2, angle=40)),
        R.build_hp(NAME + "_Decals_HP", [decals]),
    ]
    col = collision()

    atts = []
    for name, p in list(ATTACHMENTS.items()) + [("ATT_Float%d" % (i + 1), gb(x, -1.65, z)) for i, (x, z) in enumerate(FLOATS)]:
        e = bpy.data.objects.new(name, None)
        e.location = p
        bpy.context.scene.collection.objects.link(e)
        atts.append(e)

    # recentre: bbox centre of the LOD0 meshes at x 0 / y 0, lowest point at z 0 (origin "base"); the helm reads the
    # same offset from frame_offset.json so both assets share one frame
    lod0 = hull_set + deck_set + rig_set + dec_set
    lo = [min(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for o in lod0 for v in o.data.vertices) for k in range(3)]
    off = Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))
    for o in lod0 + hps + [col]:
        o.data.transform(Matrix.Translation(off))
    for e in atts:
        e.location = e.location + off
    import json
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "frame_offset.json"), "w") as f:
        json.dump({"offset": list(off), "bbox_studs": [h - l for l, h in zip(lo, hi)]}, f)
    print("[M_Veh_RIB] offset %s bbox %s" % (tuple(round(c, 3) for c in off), [round(h - l, 3) for l, h in zip(lo, hi)]))

    meshes = []
    for objs, s in ((hull_set, "Hull"), (deck_set, "Deck"), (rig_set, "Rig"), (dec_set, "Decals")):
        for o in objs:
            meshes.append({"object": o, "set": s})
    for h in hps:
        meshes.append({"object": h})
    meshes.append({"object": col})

    streak = {"rust": 0.3, "rust_color": (0.47, 0.49, 0.49), "rust_rough": 0.75, "rust_length": 0.5, "rust_fingers": 14,
              "salt": 0.5, "salt_range": (0.25, 0.7), "salt_color": (0.82, 0.81, 0.77), "edge_color": (0.66, 0.66, 0.63)}
    sets = [
        {"name": TEX, "set": "Hull", "size": 2048, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15,
         "wear": dict(streak, edge=0.3, edge_color=(0.62, 0.6, 0.56))},
        {"name": TEX, "set": "Deck", "size": 2048, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15,
         "wear": dict(streak, edge=0.4, rust=0.18)},
        {"name": TEX, "set": "Rig", "size": 2048, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15,
         "wear": dict(streak, edge=0.4, rust=0.15, salt=0.4, edge_color=(0.74, 0.74, 0.72))},
        {"name": TEX, "set": "Decals", "size": 1024, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15,
         "wear": dict(streak, edge=0.0, salt=0.25, rust=0.12)},
    ]
    return {
        "name": NAME,
        "budget": "rib",
        "tris": 35000,
        "tier": "standard",
        "dims_m": (2.85, 8.44, 3.0),
        "size_note": "Z includes the two VHF / AIS whips lowered aft on their ratchet mounts above the radar dome "
                     "(thin, no gameplay footprint); hull, tubes and A-frame are within 1% of 3.0 m.",
        "origin": "base",
        "sets": sets,
        "meshes": meshes,
        "attachments": atts,
        "bake_samples": 16,
        "waivers": {
            "LOD UV layout": "LOD2 at 10% of LOD0 collapses small A-frame / engine UV island borders (area 26-31% off, bounds "
                             "within 0.002); LOD2 is only seen beyond 500 studs, where the maps are mip-mapped far below "
                             "the island size. LOD1 passes.",
            "geometry": "Console LOD2: 8 loose verts left by collapse decimation at 40 tris (harmless, not rendered); "
                        "LOD0 and LOD1 pass.",
        },
    }
