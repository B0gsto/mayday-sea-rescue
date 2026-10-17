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
        xm = 0.52 * xc
        zm = zk + 0.03 + (zc - zk) * 0.50
        half = [(0.14, zk + 0.02), (xm, zm), (xm + 0.06, zm - 0.035), (xc, zc), (xc + 0.16, zc + 0.015),
                (xc + 0.18, zc + 0.09), (xs, zs)]
        pts = [Vector((-x, y, z)) for x, z in reversed(half)] + [Vector((x, y, z)) for x, z in half]
        secs.append(pts)
    # stem: collapse to the centreline
    yb = ys[-1] - 0.35
    cx, cz, r = R.tube_frame(yb)
    stem = [Vector((p.x * 0.05, yb, max(p.z, R.K + 1.5))) for p in secs[-1]]
    secs.append(stem)
    return secs


def hull(g):
    secs = hull_sections(g.hi)
    n = len(secs[0])

    def mat(i, j):
        z = (secs[i][j].z + secs[i][j + 1].z) / 2
        zk = secs[i][n // 2].z
        if j in (0, 1, n - 3, n - 2):
            return "BootStripe"
        return "HullCharcoal" if z > zk + 0.05 else "Antifoul"
    faces = g.rings(secs, M(g, "HullCharcoal"), closed=False, matfn=(lambda i, j: mat(i, j)) if g.hi else None, recalc=False)
    g.orient(faces, lambda c: Vector((c.x, 0.0, c.z - R.DECK - 1.0)) if abs(c.x) > 0.05 else Vector((0, 0, -1)))
    # transom panel (fan from the centre), facing aft
    ring = [g.bm.verts.new(p) for p in secs[0]]
    top = [g.bm.verts.new(Vector((x, R.TRANSOM_Y, R.DECK + 0.25))) for x in (secs[0][-1].x, secs[0][0].x)]
    loop = ring + top
    f = g.face(loop, M(g, "HullCharcoal"))
    if f:
        res = bmesh.ops.triangulate(g.bm, faces=[f])
        g.orient(res["faces"], lambda c: Vector((0, 1, 0)))
    # transom cap (engine well top)
    tcap = R.box(g, (0, R.TRANSOM_Y - 0.2, R.DECK + 0.3), (2 * secs[0][-1].x, 0.4, 0.1), M(g, "GelcoatWhite"))


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
    # transom clamp bracket and steering tube
    R.box(g, (x, R.TRANSOM_Y + 0.22, 2.35), (0.56, 0.36, 1.1), M(g, "BlackPlastic"))
    R.tube(g, [(x, R.TRANSOM_Y + 0.25, 3.0), (x, y - 0.3, 3.0)], 0.07, M(g, "Stainless"), 12)
    R.box(g, (x, y - 0.75, 2.75), (0.3, 0.3, 0.5), M(g, "CowlGrey"))


def engines(g):
    for x in ENG_X:
        outboard(g, x)


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
CREST = (-1.15, 3.55, 0.5)   # console side: y centre, z centre, radius


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
    disc(0, rad, 0, "PanelOrange")
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
    poly([(-0.08 * s, -0.3 * s), (0.08 * s, -0.3 * s), (0.055 * s, 0.12 * s), (-0.055 * s, 0.12 * s)], 3, "CrestCharcoal")
    poly([(-0.07 * s, -0.12 * s), (0.07 * s, -0.12 * s), (0.065 * s, -0.04 * s), (-0.065 * s, -0.04 * s)], 4, "LetterWhite")
    poly([(-0.045 * s, 0.13 * s), (0.045 * s, 0.13 * s), (0.045 * s, 0.21 * s), (-0.045 * s, 0.21 * s)], 3, "LetterWhite")
    poly([(-0.07 * s, 0.21 * s), (0.07 * s, 0.21 * s), (0.0, 0.29 * s)], 3, "CrestCharcoal")
    poly([(-0.1 * s, -0.33 * s), (0.1 * s, -0.33 * s), (0.1 * s, -0.3 * s), (-0.1 * s, -0.3 * s)], 3, "CrestCharcoal")


def decals(g):
    for sx in (1, -1):
        y0, y1, a, b = NAME_PANEL
        if g.hi:
            tube_patch(g, sx, y0, y1, a, b, "PanelOrange", DEC_OFF, nu=40, nv=12)
            tube_text(g, sx, (y0 + y1) / 2, (a + b) / 2 - 0.01, "GALE ISLES COASTGUARD", 0.52, "LetterWhite", DEC_OFF + 0.004, 0.92)
        else:
            tube_patch(g, sx, y0, y1, a, b, "X", DEC_OFF, nu=20, nv=8)
        y0, y1, a, b = NUM_PANEL
        if g.hi:
            tube_patch(g, sx, y0, y1, a, b, "PanelOrange", DEC_OFF, nu=12, nv=12)
            tube_text(g, sx, (y0 + y1) / 2, (a + b) / 2 - 0.01, "GI-21", 0.6, "LetterWhite", DEC_OFF + 0.004)
        else:
            tube_patch(g, sx, y0, y1, a, b, "X", DEC_OFF, nu=4, nv=8)
        crest(g, sx, 0.012, g.hi)


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

    no_rust = {"rust": 0.0, "edge": 0.25, "salt": 0.3, "edge_color": (0.62, 0.62, 0.6)}
    sets = [
        {"name": TEX, "set": "Hull", "size": 2048, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(no_rust, edge=0.15)},
        {"name": TEX, "set": "Deck", "size": 2048, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(no_rust, edge=0.3)},
        {"name": TEX, "set": "Rig", "size": 1024, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(no_rust, edge=0.35, edge_color=(0.72, 0.72, 0.7))},
        {"name": TEX, "set": "Decals", "size": 1024, "wet": True, "cage_extrusion": 0.06, "max_ray_distance": 0.15, "wear": dict(no_rust, edge=0.0, salt=0.15)},
    ]
    return {
        "name": NAME,
        "budget": "rib",
        "tris": 35000,
        "tier": "standard",
        "dims_m": (2.85, 8.44, 3.0),
        "size_note": None,
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
