"""The Jet Ski stage's nine upgrade pieces (levels 2-10), from the owner-cleared concept (artifact 236fbf08).

One asset per piece (thin build.py in ../M_Upg_JetSki_<Piece>), all sharing one palette set. Built in the frame of the shipped
M_Veh_JetSki hull, so each piece's Model pivot is the hull origin. Authored in the concept frame (X starboard, Y up, Z aft);
the pipeline frame is bx = -X, by = Z + frame_offset, bz = Y. Bare ski at L1 means hiding the hull's old Sled MeshPart.

    python3 art/source/vehicles/_UpgJetSki/palette.py build/prod/_UpgJetSki/textures
    In Blender: import pipeline; pipeline.run_all()
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
HULL = os.path.join(HERE, "..", "M_Veh_JetSki")
sys.path[:0] = [HERE, HULL]
import palette as PAL  # noqa: E402

from mathutils import Matrix, Vector  # noqa: E402

import kitgeo  # noqa: E402
import pwc as P  # noqa: E402  (hull maths: profile, top_z, side_point)

PREFIX = "M_Upg_JetSki_"
SET_NAME, SET = "UpgJetSki", "Brick"
TEX_DIR = os.path.join(G, "build/prod/_UpgJetSki/textures")
STEM = os.path.join(TEX_DIR, "T_%s_%s_" % (SET_NAME, SET))
HULL_OFF = json.load(open(os.path.join(HULL, "frame_offset.json")))["offset"][1]
Rx = lambda a: Matrix.Rotation(a, 4, "X")
Ry = lambda a: Matrix.Rotation(a, 4, "Y")
Rz = lambda a: Matrix.Rotation(a, 4, "Z")
Tr = Matrix.Translation
SIDES = (1, -1)


def conv(q):
    """pwc frame (x port, y aft, z up) to the concept frame."""
    return Vector((-q.x, q.z, q.y))


def side_frame(sx, y, t):
    """Hull topside point + outward normal, tangent along the hull, tangent up the side (concept frame)."""
    p = conv(P.side_point(sx, y, t))
    ey = (conv(P.side_point(sx, y + 0.01, t)) - conv(P.side_point(sx, y - 0.01, t))).normalized()
    et = (conv(P.side_point(sx, y, t + 0.01)) - conv(P.side_point(sx, y, t - 0.01))).normalized()
    n = ey.cross(et).normalized()
    if n.x * -sx < 0:
        n = -n
    return p, ey, et, n


class Curve:
    """Catmull-Rom through points, sampled by arc length (the concept's CatmullRomCurve3 getPointAt)."""

    def __init__(self, pts, dense=200):
        pts = [Vector(p) for p in pts]
        ext = [2 * pts[0] - pts[1]] + pts + [2 * pts[-1] - pts[-2]]
        self.p = []
        for i in range(1, len(ext) - 2):
            a, b, c, d = ext[i - 1:i + 3]
            for k in range(dense // (len(pts) - 1)):
                t = k / (dense // (len(pts) - 1))
                self.p.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
        self.p.append(pts[-1])
        self.s = [0.0]
        for u, v in zip(self.p, self.p[1:]):
            self.s.append(self.s[-1] + (v - u).length)
        self.length = self.s[-1]

    def at(self, s):
        d = max(0.0, min(1.0, s)) * self.length
        for i in range(len(self.s) - 1):
            if d <= self.s[i + 1]:
                k = (d - self.s[i]) / max(self.s[i + 1] - self.s[i], 1e-9)
                return self.p[i].lerp(self.p[i + 1], k)
        return self.p[-1]

    def tangent(self, s):
        return (self.at(s + 0.005) - self.at(s - 0.005)).normalized()


def brick(b, c, size, cell, r=0.12, T=None, studs=True, xs=None, mask=None):
    b.rbox(c, size, cell, r=r, T=T)
    if studs:
        b.studs(c, size, cell, T=T, xs=xs, mask=mask)


# ------------------------------------------------------------------ L2
def _face_edges():
    """Sticker's lower and upper v per u, from the art's outline (the mesh is cut to it; the atlas has no alpha)."""
    upper = PAL._quad((0, .42), (.02, .92), (.2, .97)) + [(.97, .97), (1, .85)]
    lower = PAL._quad((0, .42), (.02, .05), (.25, .03)) + [(.94, .03), (1, .1)]

    def interp(line, u):
        for (u0, v0), (u1, v1) in zip(line, line[1:]):
            if u <= u1 and u1 > u0:
                return v0 + (v1 - v0) * (u - u0) / (u1 - u0)
        return line[-1][1]
    return lambda u: interp(lower, u), lambda u: interp(upper, u)


def shark_fin(b):
    # AD round 3: one clean saturated fin on the passenger seat, mid-back like a real shark, low enough to keep the rider in view
    brick(b, (0, 3.0, 3.25), (1.5, .36, 2.4), "SharkTeal", r=.12, xs=[-.52, .52])
    steps = {0: 14, 1: 8, 2: 4}[b.lod]
    c = [(-1.05, 0), (-.6, .85), (.25, 1.32), (1.2, 1.38)]
    poly = []
    for k in range(steps):
        t = k / steps
        poly.append(tuple((1 - t) ** 3 * c[0][i] + 3 * (1 - t) ** 2 * t * c[1][i] + 3 * (1 - t) * t * t * c[2][i] + t ** 3 * c[3][i] for i in (0, 1)))
    poly += PAL._quad((1.2, 1.38), (.5, .85), (.95, 0), max(steps // 2, 2))
    b.extrude(poly, .25, .12, .12, "SharkTeal", T=Tr((0, 3.18, 3.25)))

    # printed grin, raised teeth, eyes: lifted 0.075 so it clears the hull's livery panels (0.025 + 0.007)
    Y0, Y1, T0, T1 = -5.0, -2.95, .05, .95
    lo, hi = _face_edges()
    us = {0: [.004, .012, .03, .06, .1, .15, .2, .28, .36, .44, .52, .6, .68, .76, .84, .92, .97, 1],
          1: [.004, .03, .1, .2, .36, .52, .68, .84, 1], 2: [.004, .1, .36, .68, 1]}[b.lod]
    nv = {0: 5, 1: 3, 2: 2}[b.lod]
    ua, va, ub, vb = PAL.FACE_UV
    for sx in SIDES:
        rows, uvs, nrm = [], [], []
        for u in us:
            r, q, m = [], [], []
            for j in range(nv + 1):
                v = lo(u) + (hi(u) - lo(u)) * j / nv
                y, t = Y0 + u * (Y1 - Y0), T0 + v * (T1 - T0)
                p, _, _, n = side_frame(sx, y, t)
                r.append(p + n * .075)
                m.append(n)
                q.append((ua + u * (ub - ua), va + v * (vb - va)))
            rows.append(r)
            uvs.append(q)
            nrm.append(m)
        b.patch(rows, uvs, nrm)
        if b.lod < 2:
            sl = P.side_len(-4)

            def tooth(u, v, h, w, down):
                p, _, et, n = side_frame(sx, Y0 + u * (Y1 - Y0), T0 + v * (T1 - T0))
                ey = (et - n * et.dot(n)).normalized()
                ex = ey.cross(n)
                M = Matrix((ex, ey, n)).transposed().to_4x4()
                M.translation = p
                b.prism(((-w / 2, 0), (w / 2, 0), (0, -h if down else h)), .06, .16, "ToothWhite", M)
            for k in range(6):
                s = .14 + .72 * k / 5
                gap = (PAL.mouth_upper(s) - PAL.mouth_lower(s)) * (T1 - T0) * sl
                tooth(PAL.mouth_u(s), PAL.mouth_upper(s) - .02, max(.15, min(.24, gap * .45)), .24, True)
            for k in range(5):
                s = .2 + .6 * k / 4
                gap = (PAL.mouth_upper(s) - PAL.mouth_lower(s)) * (T1 - T0) * sl
                tooth(PAL.mouth_u(s), PAL.mouth_lower(s) + .02, max(.14, min(.22, gap * .4)), .23, False)
        p, _, _, n = side_frame(sx, Y0 + .86 * (Y1 - Y0), T0 + .78 * (T1 - T0))
        E = kitgeo.orient(p + n * .05, n)
        b.revolve([(0, 0), (.22, 0), (.23, .04), (.22, .08), (0, .085)], "ToothWhite", b.seg(14), E)
        b.revolve([(0, 0), (.11, 0), (.11, .03), (0, .04)], "HullCharcoal", b.seg(12), E @ Tr((.03, .08, -.02)))


# ------------------------------------------------------------------ L3
SLED_Z = 6.35


def rescue_tile(b, sx):
    """White side tile, its outer face printed: one surface, nothing lies on top of it."""
    X0, X1, Y0, Y1, Z0, Z1 = 1.70, 1.78, 1.02, 1.46, 5.4, 7.3
    ring = [(Y0, Z0), (Y0, Z1), (Y1, Z1), (Y1, Z0)]
    for (y0, z0), (y1, z1), n in ((ring[0], ring[1], (0, -1, 0)), (ring[1], ring[2], (0, 0, 1)),
                                  (ring[2], ring[3], (0, 1, 0)), (ring[3], ring[0], (0, 0, -1))):
        vs = [(sx * X0, y0, z0), (sx * X1, y0, z0), (sx * X1, y1, z1), (sx * X0, y1, z1)]
        f = len(b.f)
        b.emit(vs, [n] * 4, [(0, 1, 2, 3)], "BrickWhite")
        b.want[f] = n
    ua, va, ub, vb = PAL.RESCUE_UV
    w = (Z1 - Z0) / (Y1 - Y0) * 128 / 1024     # keep the text's aspect on the strip
    u0, u1 = .5 - w / 2, .5 + w / 2
    n = (sx, 0, 0)
    # viewed from outside, the text runs bow-ward on starboard and aft-ward on port
    z_start, z_end = (Z1, Z0) if sx > 0 else (Z0, Z1)
    rows = [[(sx * X1, Y0, z_start), (sx * X1, Y1, z_start)], [(sx * X1, Y0, z_end), (sx * X1, Y1, z_end)]]
    uvs = [[(u0, va), (u0, vb)], [(u1, va), (u1, vb)]]
    b.patch(rows, uvs, [[n, n], [n, n]])


def rescue_sled(b):
    brick(b, (0, 1.12, SLED_Z), (3.4, .28, 2.4), "BrickOrange", studs=False)
    brick(b, (0, 1.4, SLED_Z), (3.2, .28, 2.2), "BrickOrange", mask=lambda x, z: z + SLED_Z > 6.3)
    brick(b, (0, 1.76, 5.45), (3.4, .45, 1.6), "BrickOrange")
    for sx in SIDES:
        rescue_tile(b, sx)
    # life ring hangs on the stern, facing the chase camera
    b.torus((0, 0, 0), .42, .18, None, maj=24, mnr=8, T=Tr((0, 1.45, 7.75)) @ Rx(math.pi / 2), cells=lambda k: "BrickWhite" if k % 2 else "BrickOrange")


# ------------------------------------------------------------------ L4
def twin_engines(b):
    # AD round 3: two low pods flush on the transom, on the sled deck; no towers, legs or props
    for sx in SIDES:
        c, size = (sx * 1.0, 2.25, 6.35), (1.44, 1.44, 2.5)
        b.rbox(c, size, "BrickNavy", r=.45, soft=True)
        b.studs(c, size, "BrickNavy")


# ------------------------------------------------------------------ L5
def flame_pipes(b):
    d = Vector((0, .1, 1)).normalized()
    for sx in SIDES:
        base = Vector((sx * 1.0, 2.25, 7.55))
        b.lathe(base, d, [(0, 0), (.6, 0), (.66, .1), (.8, .3), (.72, .38), (0, .38)], "Chrome", 16)
        for r, h, y, cell in ((.85, 1.15, .35, "FlameRed"), (.62, .95, 1.05, "FlameOrange"), (.4, .8, 1.65, "FlameYellow")):
            prof = [(0, 0), (r * .9, 0), (r, h * .12), (r * .86, h * .45), (r * .45, h * .82), (r * .12, h), (0, h)]
            b.lathe(base + d * y, d, prof, cell, 16)


# ------------------------------------------------------------------ L6
def banana_boat(b):
    # built on, not towed: the nose docks under the life ring on a short coupler
    c = Curve([(0, 1.15, 8.0), (0, .92, 8.4), (0, .84, 9.0), (0, .82, 9.8), (0, .84, 10.6), (0, 1.05, 11.2), (0, 1.5, 11.55)])

    def rad(s):
        e = min(s, 1 - s)
        return .2 + e * 2.4 if e < .04 else .68 * math.sin(math.pi * max(0, min(1, (s - .02) / .96))) ** .3
    mid = {0: 14, 1: 9, 2: 5}[b.lod]
    ss = [0, .02, .05] + [.05 + .9 * k / mid for k in range(1, mid)] + [.95, .98, 1]
    cells = ["BananaTip" if (s0 + s1) / 2 < .05 or (s0 + s1) / 2 > .95 else "BananaYellow" for s0, s1 in zip(ss, ss[1:])]
    b.sweep([c.at(s) for s in ss], [rad(s) for s in ss], None, {0: 14, 1: 10, 2: 6}[b.lod], cells=cells)
    for z in (9.1, 9.9, 10.7):
        brick(b, (0, 1.62, z), (.9, .42, .72), "BrickRed", r=.16)
    b.rbox((0, 1.0, 7.8), (.7, .3, .7), "BrickDark", r=.08)
    p = c.at(.14)
    for dx in (-.3, .3):
        T = Tr((dx, p.y + .5, p.z)) @ Rx(.9)
        b.sphere((0, 0, 0), .24, "ToothWhite", n=10, T=T)
        if b.lod < 2:
            b.sphere((0, .09, -.15), .12, "HullCharcoal", n=8, T=T)


# ------------------------------------------------------------------ L7
def huge_spoiler(b):
    # AD round 3: very wide and low, resting on the pods; the rider stays in view above it from the chase camera
    W = Tr((0, 3.25, 6.3)) @ Rx(math.radians(-5))
    brick(b, (0, 0, 0), (12.4, .6, 2.6), "BrickRed", r=.22, T=W, mask=lambda x, z: z < -.4)
    b.rbox((0, .33, .75), (12.2, .1, .7), "BrickWhite", r=.04, T=W)
    for sx in SIDES:
        brick(b, (sx * 6.4, -.5, .1), (.8, 2.2, 3.0), "BrickRed", r=.24, T=W)


# ------------------------------------------------------------------ L8
def bull_nose(b):
    # AD round 3: a big face on the bow: eyes, brows, muzzle, horns. Shallow, so the orange hull still shows behind it
    S, Z = (4.0, 2.8, 1.8), (0, 2.5, -6.1)
    b.rbox(Z, S, "BullBlue", r=.7, soft=True)
    b.rbox((0, 1.75, -7.0), (2.9, 1.3, 1.0), "HornCream", r=.4, soft=True)
    for sx in SIDES:
        b.lathe(Vector((sx * .65, 1.85, -7.46)), (0, 0, -1), [(0, 0), (.3, 0), (.3, .06), (.22, .1), (0, .1)], "HullCharcoal", 14)
        d = Vector((sx * .25, .1, -1)).normalized()
        eye = Vector((sx * 1.05, 2.95, -6.9))
        b.lathe(eye, d, [(0, 0), (.75, 0), (.8, .06), (.72, .18), (.4, .28), (0, .3)], "ToothWhite", 18)
        b.lathe(eye + d * .26 + Vector((-sx * .13, -.05, 0)), d, [(0, 0), (.38, 0), (.38, .08), (.2, .13), (0, .14)], "HullCharcoal", 14)
        b.rbox((0, 0, 0), (1.5, .34, .4), "HullCharcoal", r=.1, T=Tr((sx * 1.05, 3.85, -6.82)) @ Rz(sx * .35))
    b.torus((0, 0, 0), .45, .14, "Gold", maj=20, mnr=8, T=Tr((0, 1.4, -7.52)) @ Rx(math.pi / 2))
    for sx in SIDES:
        c = Curve([(sx * 1.7, 3.4, -6.1), (sx * 3.0, 3.5, -6.1), (sx * 3.9, 4.4, -6.2), (sx * 3.9, 5.6, -6.3)])
        n = {0: 10, 1: 6, 2: 3}[b.lod]
        ss = [k / n for k in range(n + 1)]
        b.sweep([c.at(s) for s in ss], [.8 + (.16 - .8) * s for s in ss], "HornCream", {0: 12, 1: 8, 2: 5}[b.lod])


# ------------------------------------------------------------------ L9
def horn_stack(b):
    # AD round 3: part of the one joke: the bull's ears are air horns, with red squeeze bulbs on its cheeks
    L, R0, R = 1.5, .3, .8
    steps = {0: 7, 1: 5, 2: 3}[b.lod]
    for sx in SIDES:
        M = kitgeo.orient(Vector((sx * 1.85, 2.55, -5.8)), (sx, .25, -.25))
        prof = [(0, -.12), (R0 + .06, -.12), (R0 + .08, -.04)] + [(R0 + (R - R0) * (k / steps) ** 2.4, L * k / steps) for k in range(steps + 1)]
        prof += [(R + .12, L + .02), (R + .08, L + .12), (R - .08, L + .1), (R * .55, L - .35), (0, L - .35)]   # closed throat: Roblox culls back faces
        b.revolve(prof, "Gold", b.seg(16), M)
        b.sphere((sx * 2.0, 1.9, -5.7), .5, "BulbRed", n=12, scale=(1, .9, 1))


# ------------------------------------------------------------------ L10
def turbo_crown(b):
    # AD round 3: huge, straight on the hood and the bull's head, no pillar: the rider stays clear behind it
    C = Tr((0, 2.5, -3.7))
    b.revolve([(0, 0), (1.85, 0), (1.95, .1), (1.95, .85), (1.85, .95), (0, .95)], "Gold", b.seg(28), C)
    b.revolve([(1.75, .95), (2.2, 2.2), (2.08, 2.2), (1.63, .95), (1.75, .95)], "Gold", b.seg(28), C, open_end=True)
    for y, r, t in ((.98, 1.75, .22), (2.2, 2.2, .24)):
        b.torus((0, y, 0), r, t, "Gold", maj=28, mnr=6, T=C)
    for k in range(5):
        a = k * 2 * math.pi / 5 + math.pi
        px, pz = math.sin(a) * 2.05, math.cos(a) * 2.05
        b.revolve([(0, 0), (.7, 0), (.66, .45), (.44, 1.05), (.2, 1.5), (0, 1.6)], "Gold", b.seg(12), C @ Tr((px, 2.22, pz)))
        b.sphere((px, 3.95, pz), .45, "GemRed", n=10, T=C)
    b.revolve([(0, 0), (1.4, 0), (1.25, .6), (.6, 1.2), (0, 1.35)], "BrickOrange", b.seg(14), C @ Tr((0, .95, 0)))


PIECES = [(2, "SharkFin", shark_fin), (3, "RescueSled", rescue_sled), (4, "TwinEngines", twin_engines), (5, "FlamePipes", flame_pipes),
          (6, "BananaBoat", banana_boat), (7, "HugeSpoiler", huge_spoiler), (8, "BullNose", bull_nose), (9, "HornStack", horn_stack),
          (10, "TurboCrown", turbo_crown)]


def patch_pipeline(prebuilt):
    """Hand-made LODs (like M_Prop_HubKit), the new Upg category and the 8 x 8 palette, without touching tools/."""
    import names
    import versions
    import zfight_check
    if "Upg" not in names.CATEGORIES:   # shortcut: run-time only, tools/ is not ours; add Upg to names.py when upgrade pieces settle
        names.CATEGORIES = (*names.CATEGORIES, "Upg")
    zfight_check.GRID = PAL.GRID
    orig = getattr(versions, "_orig_decimate", versions.decimate)
    versions._orig_decimate = orig

    def decimate(obj, target, symmetry=None):
        import bpy
        m = prebuilt.pop(obj.name, None)
        if m is not None:
            old = obj.data
            obj.data = m
            bpy.data.meshes.remove(old)
            m.name = obj.name
        orig(obj, target, symmetry)
    versions.decimate = decimate


def spec(short):
    level, fn = next((lv, f) for lv, s, f in PIECES if s == short)
    mat = kitgeo.material("MI_UpgJetSki_Brick", STEM)
    name = PREFIX + short
    lods, tris = {}, []
    for lod in (0, 1, 2):
        b = kitgeo.B(lod)
        fn(b)
        tris.append(b.tris())
        if lod:
            lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat, HULL_OFF)
        else:
            obj = b.to_object(name + "_LOD0", mat, HULL_OFF)
    patch_pipeline(lods)
    vs = [v.co for v in obj.data.vertices]
    lo, hi = [min(v[i] for v in vs) for i in range(3)], [max(v[i] for v in vs) for i in range(3)]
    cb = [(lo[i] + hi[i]) / 2 for i in range(3)]
    path = os.path.join(HERE, "offsets.json")
    table = json.load(open(path)) if os.path.exists(path) else {}
    table[short] = {"level": level, "tris_authored": tris, "meshpart_centre_roblox": [round(-cb[0], 3), round(cb[2], 3), round(cb[1], 3)],
                    "size_roblox": [round(hi[0] - lo[0], 3), round(hi[2] - lo[2], 3), round(hi[1] - lo[1], 3)]}
    with open(path, "w") as f:
        json.dump(table, f, indent=1)
    return {
        "name": name, "budget": "large_prop", "tier": "standard",
        "dims_m": tuple(round((hi[i] - lo[i]) / 3.0, 3) for i in range(3)), "origin": "free", "tiling": True,
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False, "dir": TEX_DIR}],
        "meshes": [{"object": obj, "set": SET}],
        "attachments": [],
        "waivers": {
            "_COL proxy": "bolt-on look only: CanCollide off, the hull's own _COL is the collision",
            "LOD UV layout": "flat palette cells: hand-made LODs drop studs and bevels, UVs are not a unique unwrap by design",
            "texture sets": "one flat palette set shared by all nine pieces (toy-brick rule, like M_Prop_HubKit)",
        },
    }
