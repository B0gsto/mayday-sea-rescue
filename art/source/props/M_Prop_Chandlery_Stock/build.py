"""H2 M_Prop_Chandlery_Stock: dense shop stock for the Port Haven Chandlery (docs/12 props row, 1.4a 2 m fidelity).

Authored in place in the shared Chandlery frame (art/source/buildings/M_Bld_Chandlery_Ext/layout.py: metres x 3 = studs,
front -Y, floor 0.15) on the shelves and surfaces M_Bld_Chandlery_Int builds (back-wall range, tall gear shelving,
counter top and its shopkeeper-side shelves) plus floor stock and the bay-window display bed (layout.BAY_FLOOR).
Every repeated item comes from one generator (tin, book, box, hank, coil, lamp, boot, hat, glove, shackle, block).

MeshParts (one material each, all on ONE texture set T_ChandleryStock_Atlas_*, Studio maps every part to set "Atlas"):
  BackWall     worktop, two open shelves and the long stock shelf behind the counter: tins, pilot books, charts, hanks
  GearShelves  the tall gear shelving x 5.3 .. 8.2: sea boots, antifoul, lamps, sou'westers, hats, gloves, flares, boxes
               (the radio bay at ATT_RadioShelf is left to M_Prop_Chandlery)
  Counter      counter-top clutter (receipt book, mug, chart weight, handheld VHF, keys, brass desk lamp by the till,
               ATT_Light_Till at its bulb) and the shopkeeper-side open shelving under the counter
  Floor        crates (rolled charts), a stacked rope coil, a barrel of oars, an Admiralty anchor
  Window       bay display bed: flaked rope, a lantern, sea boots, a chart on a board, tins, hanks, crate

    python3 art/source/props/M_Prop_Chandlery_Stock/maketex.py
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --asset M_Prop_Chandlery_Stock --steps build,lod,validate,export,turntable
"""
import math
import os
import random
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import atlas  # noqa: E402  (this asset's atlas, cached first: kit.py's own `import atlas` then resolves to it)
sys.path.insert(1, os.path.join(G, "art/source/buildings/M_Bld_Chandlery_Ext"))
sys.path.insert(2, os.path.join(G, "art/source/props/M_Prop_Chandlery"))
sys.path.insert(3, os.path.join(G, "tools/blender"))
import kit  # noqa: E402  (read-only reuse of the props kit)
import layout as L  # noqa: E402
import versions  # noqa: E402
from kit import Part, frame, fit_frame  # noqa: E402

assert kit.atlas is atlas, "kit.py must use the stock atlas"

NAME = "M_Prop_Chandlery_Stock"
F = L.FLOOR
WY = L.IY1 - 0.03            # Int back-wall lining face (LY1)
EX = L.IX1 - 0.03            # Int east-wall lining face (LX1)
RNG = random.Random(11)

_base_uvs = kit.face_uvs


def _face_uvs(pts, region, fit):
    if isinstance(fit, tuple) and fit and fit[0] == "uv":
        return list(fit[1]), 0
    return _base_uvs(pts, region, fit)


kit.face_uvs = _face_uvs     # explicit per-loop UVs (labels wrapped round tins, rope tiles)


def W(M, p):
    return M @ Vector(p)


class SP(Part):
    def quad(self, pts, uvs, region):
        b = len(self.v)
        self.v.extend(Vector(p) for p in pts)
        self.f.append((list(range(b, b + len(pts))), region, ("uv", uvs)))

    def tube(self, pts, r, sides, region, closed=False, caps=True, k=3, rz=None):
        """Rope along a polyline in a periodic rope tile: rings resampled so a whole number of tiles fits the length."""
        P = [Vector(p) for p in pts]
        if closed:
            P = P + [P[0]]
        seg = [(P[i + 1] - P[i]).length for i in range(len(P) - 1)]
        Ltot = sum(seg)
        kind, per = atlas.R[region][4], atlas.R[region][5]
        period = per * 2 * r if kind == "rope" else 2 * math.pi * r
        n = k * max(1, int(round(Ltot / period)))
        if not closed and n < 2:
            n = 2
        cum = np.concatenate([[0.0], np.cumsum(seg)])
        Q = []
        for i in range(n + 1):
            s = Ltot * i / n
            j = min(int(np.searchsorted(cum, s, side="right")) - 1, len(seg) - 1)
            t = (s - cum[j]) / max(seg[j], 1e-9)
            Q.append(P[j].lerp(P[j + 1], t))
        if closed:
            Q = Q[:-1]
        m = len(Q)
        T = []
        for i in range(m):
            if closed:
                a, b = Q[(i - 1) % m], Q[(i + 1) % m]
            else:
                a, b = Q[max(0, i - 1)], Q[min(m - 1, i + 1)]
            T.append((b - a).normalized())
        ref = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
        nrm = T[0].cross(ref).normalized()
        rings = []
        rzz = r if rz is None else rz
        for i in range(m):
            if i:
                nrm = (nrm - T[i] * nrm.dot(T[i])).normalized()
            bn = T[i].cross(nrm)
            rings.append([Q[i] + nrm * (r * math.cos(2 * math.pi * j / sides)) + bn * (rzz * math.sin(2 * math.pi * j / sides))
                          for j in range(sides)])
        u0, v0, u1, v1 = atlas.rect(region)
        du, dv = u1 - u0, v1 - v0
        nseg = m if closed else m - 1
        for i in range(nseg):
            A, B = rings[i], rings[(i + 1) % m]
            va = v0 + dv * (i % k) / k
            vb = v0 + dv * (i % k + 1) / k
            for j in range(sides):
                j1 = (j + 1) % sides
                ua, ub = u0 + du * j / sides, u0 + du * (j + 1) / sides
                self.quad([A[j], B[j], B[j1], A[j1]], [(ua, va), (ua, vb), (ub, vb), (ub, va)], region)
        if caps and not closed:
            for ring, rev in ((rings[0], True), (rings[-1], False)):
                pts_ = list(reversed(ring)) if rev else ring
                c = (u0 + du * 0.5, v0 + dv * 0.5)
                self.quad(pts_, [c] * sides, region)

    def wrap(self, M, rad, z0, z1, segs, rc, u_front=0.30, region="TinLabels"):
        """Cylinder side with a label wrapped once round it (rc = label rect); the label's u_front faces local -Y."""
        u0, v0, u1, v1 = rc
        tz = [-math.pi / 2 - u_front * 2 * math.pi + 2 * math.pi * j / segs for j in range(segs + 1)]
        for j in range(segs):
            ta, tb = tz[j], tz[j + 1]
            pa0, pb0 = W(M, (rad * math.cos(ta), rad * math.sin(ta), z0)), W(M, (rad * math.cos(tb), rad * math.sin(tb), z0))
            pa1, pb1 = W(M, (rad * math.cos(ta), rad * math.sin(ta), z1)), W(M, (rad * math.cos(tb), rad * math.sin(tb), z1))
            ua, ub = u0 + (u1 - u0) * j / segs, u0 + (u1 - u0) * (j + 1) / segs
            self.quad([pa0, pb0, pb1, pa1], [(ua, v0), (ub, v0), (ub, v1), (ua, v1)], region)


def spine_fit(face, x0, y0, z0, x1, y1, z1, rc, lying=False):
    if face == "-y":
        if lying:
            return fit_frame((x0, y0, z1), (0, 0, -1), (1, 0, 0), z1 - z0, x1 - x0, rc)
        return fit_frame((x0, y0, z0), (1, 0, 0), (0, 0, 1), x1 - x0, z1 - z0, rc)
    if lying:
        return fit_frame((x1, y1, z1), (0, 0, -1), (-1, 0, 0), z1 - z0, x1 - x0, rc)
    return fit_frame((x1, y1, z0), (-1, 0, 0), (0, 0, 1), x1 - x0, z1 - z0, rc)


# ------------------------------------------------------------------ generators (one per repeated item)
def book(P, x0, y0, z0, w, d, h, i, face="-y", lying=False):
    """Standing: w = thickness along X, h = height. Lying: w = length along X, h = thickness."""
    x1, y1, z1 = x0 + w, y0 + d, z0 + h
    back = "+y" if face == "-y" else "-y"
    rc = atlas.spine_rect(i)
    fits = {face: ("Spines", spine_fit(face, x0, y0, z0, x1, y1, z1, rc, lying)), back: "Paper", "+z": "Paper" if not lying else "Suede"}
    P.box((x0, y0, z0), (x1, y1, z1), "Suede", fits=fits, skip=("-z",))


def books_row(P, x0, x1, y0, d, z, face="-y", seed=0, hmin=0.20, hmax=0.27):
    r = random.Random(seed)
    x, k = x0, seed
    while True:
        w = r.uniform(0.022, 0.045)
        if x + w > x1:
            break
        book(P, x, y0 + r.uniform(0, 0.02), z, w, d - 0.025, r.uniform(hmin, hmax), k, face)
        x += w + 0.0015
        k += 1


def book_stack(P, xc, y0, d, z, n, seed=0, face="-y"):
    r = random.Random(seed)
    for j in range(n):
        ln, t = r.uniform(0.20, 0.26), r.uniform(0.025, 0.04)
        xo = xc - ln / 2 + r.uniform(-0.015, 0.015)
        book(P, xo, y0 + r.uniform(0, 0.02), z, ln, d - r.uniform(0.02, 0.06), t, seed * 3 + j, face, lying=True)
        z += t
    return z


def box_item(P, x0, y0, z0, w, d, h, label=None, face="-y", body="Card"):
    """Carton; label = ('Boxes'|'Flares', i) on the facing side."""
    fits = {}
    if label:
        key, i = label
        rc = atlas.box_rect(i) if key == "Boxes" else atlas.flare_rect(i)
        if face == "-y":
            fits["-y"] = (key, fit_frame((x0, y0, z0), (1, 0, 0), (0, 0, 1), w, h, rc))
        else:
            fits["+y"] = (key, fit_frame((x0 + w, y0 + d, z0), (-1, 0, 0), (0, 0, 1), w, h, rc))
    P.box((x0, y0, z0), (x0 + w, y0 + d, z0 + h), body, fits=fits, skip=("-z",))


def tin(P, x, y, z, i, size="1l", yaw=0.0, face_yaw=0.0):
    """Paint / varnish tin; label i wrapped round it, its front facing -Y rotated by face_yaw (deg)."""
    rad, h, segs = {"small": (0.045, 0.085, 8), "1l": (0.055, 0.12, 10), "big": (0.085, 0.19, 12)}[size]
    M = frame(x, y, z, face_yaw + yaw)
    P.lathe([(rad * 0.97, 0.0), (rad, 0.006)], segs, "Galv", M, cap0=False, cap1=False)
    P.wrap(M, rad, 0.006, h - 0.008, segs, atlas.tin_rect(i))
    P.lathe([(rad, h - 0.008), (rad * 1.012, h - 0.002), (rad * 0.93, h + 0.002)], segs, "Galv", M, cap0=False, cap1=True)
    if size == "big":
        pts = [W(M, (rad * 0.98 * math.cos(t), rad * 0.98 * math.sin(t) * 0.25, h + 0.006)) for t in np.linspace(0.15, math.pi - 0.15, 6)]
        P.sweep(pts, 0.0025, 3, "Galv", caps=False)
    return h + 0.002


def tins_row(P, x0, x1, y, z, kinds, size="1l", seed=0, stack=False):
    r = random.Random(seed)
    rad = {"small": 0.045, "1l": 0.055, "big": 0.085}[size]
    n = int((x1 - x0) // (2 * rad + 0.008))
    for j in range(n):
        x = x0 + rad + 0.004 + j * (2 * rad + 0.008)
        h = tin(P, x, y, z, kinds[j % len(kinds)], size, yaw=r.uniform(-25, 25))
        if stack and j < n - 1 and j % 2 == 0:
            tin(P, x + rad + 0.004, y, z + h, kinds[(j + 1) % len(kinds)], size, yaw=r.uniform(-25, 25))


def hank(P, x, y, z, R, r, region, yaw=0.0, binds=2, flat=0.8):
    """Coiled hank lying flat: a torus bundle in a hank tile, whipped in `binds` places."""
    M = frame(x, y, z + r * flat, yaw) @ Matrix.Diagonal((1, 1, flat, 1))
    segs = max(10, int(2 * math.pi * R / (2 * math.pi * r / 3) // 3 * 3))
    pts = [W(M, (R * math.cos(t), R * math.sin(t), 0)) for t in np.linspace(0, 2 * math.pi, segs, endpoint=False)]
    P.tube(pts, r, 6, region, closed=True, k=3, rz=r * flat)
    bind_reg = "RopeCream" if region != "HankCream" else "RopeManila"
    for b in range(binds):
        t = 2 * math.pi * (b + 0.3) / binds + yaw
        c = Vector((x, y, z + r * flat)) + Vector((math.cos(t), math.sin(t), 0)) * R
        rad = Vector((math.cos(t), math.sin(t), 0))
        ring = [c + (rad * math.cos(a) * (r + 0.004)) + Vector((0, 0, math.sin(a) * (r * flat + 0.004))) for a in np.linspace(0, 2 * math.pi, 6, endpoint=False)]
        P.tube(ring, 0.004, 3, bind_reg, closed=True, k=1)
    return z + 2 * r * flat


def stacked_coil(P, x, y, z, R, d, turns, region, yaw=0.0, tail=None):
    """Rope coiled down in stacked turns (mooring line), optional tail laid out to `tail` (world xy)."""
    per = 16
    pts = []
    for i in range(int(turns * per) + 1):
        t = 2 * math.pi * i / per + math.radians(yaw)
        rr = R * (1 + 0.04 * math.sin(3.1 * t)) - 0.25 * d * (i / per % 1.0 > 0.5) * 0
        pts.append((x + rr * math.cos(t), y + rr * math.sin(t), z + d / 2 + d * 0.92 * i / per))
    if tail:
        a = Vector(pts[-1])
        b = Vector((tail[0], tail[1], z + d / 2))
        for k in range(1, 6):
            p = a.lerp(b, k / 5)
            p.z = max(z + d / 2, a.z * (1 - k / 3)) if k < 3 else z + d / 2
            pts.append(tuple(p))
    P.tube(pts, d / 2, 6, region, k=1)


def flake(P, x, y, z, r0, turns, d, region, yaw=0.0):
    """Flemish flake: flat spiral on the ground."""
    per = 14
    pts = []
    for i in range(int(turns * per) + 1):
        t = 2 * math.pi * i / per
        rr = r0 + d * 1.05 * t / (2 * math.pi)
        a = t + math.radians(yaw)
        pts.append((x + rr * math.cos(a), y + rr * math.sin(a), z + d / 2))
    P.tube(pts, d / 2, 5, region, k=1)


def shackle(P, M, size=1.0, region="Galv"):
    R, r, leg = 0.018 * size, 0.0045 * size, 0.022 * size
    P.torus(R, r, 6, 3, region, M @ Matrix.Rotation(math.radians(90), 4, 'X'), arc=math.pi)
    for s in (-1, 1):
        P.cyl(W(M, (s * R, 0, 0)), W(M, (s * R, 0, -leg)), r, 3, region, caps=False)
    P.cyl(W(M, (-R - 0.006 * size, 0, -leg - 0.004 * size)), W(M, (R + 0.01 * size, 0, -leg - 0.004 * size)), r * 1.1, 4, region)


def block(P, M):
    for s in (-1, 1):
        P.lathe([(0.03, s * 0.012), (0.034, s * 0.016)], 8, "BlackPlastic", M @ Matrix.Rotation(math.radians(90), 4, 'Y'), 1.0, 1.45, True, True)
    P.cyl(W(M, (-0.012, 0, 0)), W(M, (0.012, 0, 0)), 0.024, 8, "Galv")
    P.torus(0.014, 0.004, 6, 3, "Galv", M @ Matrix.Translation((0, 0, 0.06)) @ Matrix.Rotation(math.radians(90), 4, 'Y'))


def tray(P, x0, y0, z, w, d, items="shackle", seed=0):
    """Open cardboard tray of shackles or blocks."""
    t = 0.004
    P.box((x0, y0, z), (x0 + w, y0 + d, z + 0.06), "Card", skip=("+z", "-z"))
    P.box((x0 + t, y0 + t, z + 0.004), (x0 + w - t, y0 + d - t, z + 0.03), "Galv" if items == "shackle" else "BlackPlastic", skip=("-z",))
    r = random.Random(seed)
    for k in range(3):
        M = frame(x0 + w * (0.25 + 0.25 * k), y0 + d * r.uniform(0.35, 0.65), z + 0.045, r.uniform(0, 180), r.uniform(50, 90), r.uniform(-20, 20))
        if items == "shackle":
            shackle(P, M, 1.4)
        else:
            block(P, frame(x0 + w * (0.25 + 0.25 * k), y0 + d * 0.5, z + 0.06, r.uniform(-30, 30), 90, 0))


def lamp(P, x, y, z, yaw=0.0, body="Galv"):
    """Hurricane lamp, 0.30 m: fount, glass globe, air tubes, cap, bail."""
    M = frame(x, y, z, yaw)
    P.lathe([(0.072, 0.0), (0.075, 0.012), (0.074, 0.05), (0.058, 0.07), (0.036, 0.08)], 8, body, M, cap0=False, cap1=False)
    P.lathe([(0.036, 0.08), (0.058, 0.115), (0.064, 0.15), (0.054, 0.19), (0.032, 0.215)], 8, "Glass", M, cap0=False, cap1=False)
    P.lathe([(0.032, 0.215), (0.046, 0.232), (0.044, 0.255), (0.022, 0.275), (0.012, 0.29)], 8, body, M, cap0=False, cap1=True)
    for s in (-1, 1):
        P.sweep([W(M, (s * 0.074, 0, 0.045)), W(M, (s * 0.078, 0, 0.2)), W(M, (s * 0.046, 0, 0.245))], 0.006, 4, body, caps=False)
    bail = [W(M, (0.05 * math.cos(t), 0, 0.25 + 0.075 * math.sin(t))) for t in np.linspace(0, math.pi, 7)]
    P.sweep(bail, 0.0025, 3, body, caps=False)
    P.cyl(W(M, (0.06, -0.01, 0.075)), W(M, (0.06, -0.035, 0.075)), 0.008, 5, "Brass")     # wick key


def boot(P, x, y, z, yaw=0.0, region="Boot"):
    M = frame(x, y, z, yaw)
    P.lathe([(0.064, 0.05), (0.069, 0.20), (0.074, 0.33), (0.068, 0.33), (0.062, 0.30)], 8, region, M, 1.0, 1.05, False, False)
    P.lathe([(0.06, 0.012), (0.066, 0.05), (0.05, 0.11)], 8, region, M, 1.0, 1.75, False, True, offset=(0, -0.045))
    P.box((-0.055, -0.15, 0.0), (0.055, 0.075, 0.022), "Sole", M)
    P.box((-0.07, -0.02, 0.27), (0.07, 0.02, 0.29), "Sole", M)


def boots(P, x, y, z, yaw=0.0):
    boot(P, x - 0.075, y, z, yaw + 4)
    boot(P, x + 0.075, y + 0.01, z, yaw - 6)


def beanie(P, x, y, z, region, yaw=0.0):
    M = frame(x, y, z, yaw)
    P.lathe([(0.088, 0.0), (0.091, 0.045), (0.086, 0.055), (0.084, 0.11), (0.068, 0.15), (0.038, 0.172), (0.0, 0.18)], 10, region, M, 1.0, 0.92, False, False)


def souwester(P, x, y, z, yaw=0.0):
    M = frame(x, y, z, yaw)
    prof = [(0.0, 0.16), (0.055, 0.155), (0.085, 0.125), (0.096, 0.07), (0.10, 0.045), (0.15, 0.012), (0.165, 0.0)]
    P.lathe(prof, 10, "Oilskin", M, 1.0, 1.15, False, False, offset=(0, 0.02))
    P.lathe(list(reversed([(r_ * 0.98, z_ - 0.004) for r_, z_ in prof[3:]])), 10, "Oilskin", M, 1.0, 1.15, False, False, offset=(0, 0.02))


def glove(P, M, region="GloveGrey"):
    """Work glove lying flat, fingers toward local +Y."""
    P.box((-0.045, -0.06, 0.0), (0.045, 0.05, 0.022), region, M)
    P.box((-0.05, -0.14, 0.0), (0.05, -0.06, 0.026), "Suede", M)       # cuff
    for k, (dx, ln) in enumerate(((-0.033, 0.06), (-0.011, 0.075), (0.011, 0.072), (0.033, 0.058))):
        P.box((dx - 0.0095, 0.05, 0.002), (dx + 0.0095, 0.05 + ln, 0.018), region, M)
    P.box((0.045, -0.02, 0.002), (0.075, 0.03, 0.018), region, M @ Matrix.Rotation(math.radians(-25), 4, 'Z'))


def gloves(P, x, y, z, yaw=0.0, region="GloveGrey"):
    glove(P, frame(x - 0.05, y, z, yaw), region)
    glove(P, frame(x + 0.05, y + 0.01, z + 0.024, yaw + 8), region)


def crate(P, x0, y0, z0, w, d, h, wood="CrateWood", lid=True):
    t = 0.018
    P.box((x0 + t, y0 + t, z0 + 0.004), (x0 + w - t, y0 + d - t, z0 + h - (0 if lid else 0.02)), wood, skip=("-z",) if lid else ("-z", "+z"))
    if not lid:     # open: inner walls and a floor a little down
        P.box((x0 + 2 * t, y0 + 2 * t, z0 + 0.05), (x0 + w - 2 * t, y0 + d - 2 * t, z0 + h - 0.02), wood, skip=("-z", "+z"))
        P.f[-4:] = [(list(reversed(f[0])), f[1], f[2]) for f in P.f[-4:]]
        P.box((x0 + 2 * t, y0 + 2 * t, z0 + 0.04), (x0 + w - 2 * t, y0 + d - 2 * t, z0 + 0.05), wood, skip=("-z",))
    for zz in (z0, z0 + h - 0.06):      # battens round the top and bottom
        P.box((x0, y0, zz), (x0 + w, y0 + t, zz + 0.06), wood)
        P.box((x0, y0 + d - t, zz), (x0 + w, y0 + d, zz + 0.06), wood)
        P.box((x0, y0 + t, zz), (x0 + t, y0 + d - t, zz + 0.06), wood)
        P.box((x0 + w - t, y0 + t, zz), (x0 + w, y0 + d - t, zz + 0.06), wood)
    for xx in (x0, x0 + w - t):         # corner posts on the front
        P.box((xx, y0 - 0.002, z0 + 0.06), (xx + t, y0 + t, z0 + h - 0.06), wood)


def rolled_charts(P, x, y, z, n, seed=0, top=1.25):
    r = random.Random(seed)
    for k in range(n):
        a = 2 * math.pi * k / n
        px, py = x + 0.07 * math.cos(a) * (k % 3 > 0), y + 0.06 * math.sin(a) * (k % 3 > 0)
        lean = (r.uniform(-0.06, 0.06), r.uniform(-0.06, 0.06))
        P.cyl((px, py, z), (px + lean[0], py + lean[1], top + r.uniform(-0.12, 0.05)), r.uniform(0.022, 0.03), 6,
              "Paper" if k % 3 else "Card", caps=True)


def chart_pile(P, x0, y0, z, w, d, n=3):
    """Folded charts stacked flat, chart face on the top sheet."""
    for k in range(n):
        dx, dy = 0.01 * (k % 2), 0.008 * ((k + 1) % 2)
        zt = z + 0.012 * (k + 1)
        top = k == n - 1
        fits = {"+z": ("Chart", fit_frame((x0 + dx, y0 + dy, zt), (1, 0, 0), (0, 1, 0), w, d, atlas.rect("Chart")))} if top else None
        P.box((x0 + dx, y0 + dy, zt - 0.012), (x0 + dx + w, y0 + dy + d, zt), "Paper", fits=fits, skip=("-z",))


def tag(P, x0, y, z0, i, face="-y"):
    """Shelf-edge ticket 0.08 x 0.02 m on a shelf lip."""
    w, h = 0.08, 0.02
    rc = atlas.tag_rect(i)
    if face == "-y":
        P.box((x0, y - 0.002, z0), (x0 + w, y, z0 + h), "Paper", fits={"-y": ("Tags", fit_frame((x0, y - 0.002, z0), (1, 0, 0), (0, 0, 1), w, h, rc))})
    else:
        P.box((x0, y, z0), (x0 + w, y + 0.002, z0 + h), "Paper", fits={"+y": ("Tags", fit_frame((x0 + w, y + 0.002, z0), (-1, 0, 0), (0, 0, 1), w, h, rc))})


# ------------------------------------------------------------------ zones
def back_wall():
    P = SP("BackWall")
    # worktop (top 0.96, y 4.88 .. 5.42); brackets of the 1.40 shelf at x 0.25 / 1.40 / 2.55 come down to 1.15 at the wall
    zt = 0.96
    tins_row(P, 0.32, 1.32, 5.0, zt, [0, 1, 2], "1l", seed=1)
    hank(P, 1.62, 5.12, zt, 0.12, 0.035, "HankManila", 20)
    hank(P, 1.62, 5.12, zt + 0.056, 0.115, 0.034, "HankNavy", 70)
    chart_pile(P, 1.86, 4.96, zt, 0.42, 0.3, 4)
    tray(P, 2.45, 4.95, zt, 0.3, 0.22, "shackle", 3)
    box_item(P, 2.82, 5.05, zt, 0.26, 0.22, 0.16, ("Boxes", 0))
    box_item(P, 2.84, 5.06, zt + 0.16, 0.22, 0.2, 0.12, ("Boxes", 2))
    tray(P, 3.16, 4.95, zt, 0.3, 0.22, "block", 4)
    box_item(P, 3.54, 5.04, zt, 0.26, 0.24, 0.16, ("Boxes", 1))
    hank(P, 4.0, 5.12, zt, 0.13, 0.04, "HankCream", 40)
    tins_row(P, 4.24, 5.15, 5.06, zt, [3, 4, 5], "big", seed=2, stack=True)
    # open shelf 1.40 (x 0.1 .. 2.7, y 5.12 .. 5.42): pilot books, tins, ticket
    books_row(P, 0.30, 1.34, 5.13, 0.27, 1.40, seed=3, hmin=0.19, hmax=0.23)
    tins_row(P, 1.47, 2.48, 5.25, 1.40, [6, 7, 0, 1], "small", seed=4, stack=True)
    for i, x in enumerate((0.5, 1.7)):
        tag(P, x, WY - 0.30 - 0.001, 1.375, (2, 0)[i])
    # open shelf 1.90: lamps, hanks, flares, books
    lamp(P, 0.48, 5.27, 1.90, 10)
    lamp(P, 0.86, 5.27, 1.90, -25)
    z = hank(P, 1.70, 5.255, 1.90, 0.11, 0.034, "HankCream", 10)
    hank(P, 1.70, 5.255, z, 0.10, 0.032, "HankManila", 50)
    box_item(P, 1.96, 5.16, 1.90, 0.24, 0.22, 0.10, ("Flares", 0))
    box_item(P, 1.98, 5.17, 2.00, 0.22, 0.2, 0.09, ("Flares", 1))
    books_row(P, 2.26, 2.50, 5.13, 0.26, 1.90, seed=5, hmin=0.22, hmax=0.26)
    tag(P, 0.6, WY - 0.30 - 0.001, 1.875, 3)
    # long stock shelf 2.62 (x 0.1 .. 5.2, y 5.10 .. 5.42), items <= 0.26 tall (beams at 2.95)
    zs = 2.62
    box_item(P, 0.2, 5.15, zs, 0.3, 0.25, 0.18, ("Boxes", 3))
    box_item(P, 0.52, 5.16, zs, 0.3, 0.24, 0.18, ("Boxes", 0))
    book_stack(P, 1.05, 5.12, 0.28, zs, 5, seed=6)
    hank(P, 1.52, 5.26, zs, 0.13, 0.04, "HankNavy", 30)
    lamp(P, 1.9, 5.27, zs, 40, body="LampGreen")
    chart_pile(P, 2.0, 5.12, zs, 0.26, 0.28, 3)
    box_item(P, 2.56, 5.15, zs, 0.28, 0.25, 0.2, ("Boxes", 1))           # beam corbels at x 2.3 .. 2.5 / 4.7 .. 4.9
    hank(P, 3.02, 5.26, zs, 0.13, 0.04, "HankManila", 0)
    hank(P, 3.37, 5.26, zs, 0.12, 0.038, "HankCream", 60)
    books_row(P, 3.58, 4.15, 5.12, 0.28, zs, seed=7, hmin=0.2, hmax=0.25)
    box_item(P, 4.2, 5.14, zs, 0.4, 0.26, 0.16, ("Boxes", 2))
    box_item(P, 4.95, 5.15, zs, 0.22, 0.25, 0.2, ("Flares", 0))
    return P


def gear_shelves():
    P = SP("GearShelves")
    bays = [(5.32, 6.25), (6.29, 7.21), (7.25, 8.14)]
    y0, y1 = WY - 0.40, WY
    yc = (y0 + y1) / 2
    for b, (a, c) in enumerate(bays):
        m = (a + c) / 2
        # 0.30: sea boots
        for x in ((a + 0.22, c - 0.22) if b < 2 else (a + 0.22,)):
            boots(P, x, yc + 0.03, 0.30, RNG.uniform(-8, 8))
        if b == 2:
            box_item(P, c - 0.42, y0 + 0.04, 0.30, 0.38, 0.32, 0.26, ("Boxes", 3))
        # 0.75: antifoul (bays 0, 2), big hanks (bay 1)
        if b == 1:
            for x in (a + 0.22, c - 0.22):
                z = hank(P, x, yc, 0.75, 0.13, 0.045, "HankManila" if x < m else "HankNavy", RNG.uniform(0, 90))
                hank(P, x, yc, z, 0.12, 0.042, "HankCream" if x < m else "HankManila", RNG.uniform(0, 90))
        else:
            tins_row(P, a + 0.02, c - 0.02, yc - 0.04, 0.75, [3, 4, 5] if b == 0 else [5, 3], "big", seed=10 + b, stack=True)
            tins_row(P, a + 0.1, c - 0.1, yc + 0.12, 0.75, [4, 3], "big", seed=20 + b)
        # 1.20: lamps (0), sou'westers (1); bay 2 is under the radio shelf (M_Prop_Chandlery): left clear
        if b == 0:
            for k, x in enumerate(np.linspace(a + 0.15, c - 0.15, 3)):
                lamp(P, x, yc, 1.20, RNG.uniform(-40, 40), body="Galv" if k != 1 else "LampGreen")
        elif b == 1:
            for x in np.linspace(a + 0.2, c - 0.2, 3):
                souwester(P, x, yc - 0.02, 1.20, RNG.uniform(-15, 15))
        # 1.60: hats (0), gloves (1)
        if b == 0:
            for k, x in enumerate(np.linspace(a + 0.11, c - 0.11, 4)):
                beanie(P, x, yc + RNG.uniform(-0.04, 0.04), 1.60, ["WoolNavy", "WoolRust", "WoolOat", "WoolGreen"][k], RNG.uniform(0, 90))
        elif b == 1:
            for k, x in enumerate(np.linspace(a + 0.16, c - 0.16, 3)):
                for j in range(2):
                    gloves(P, x, yc - 0.02, 1.60 + 0.05 * j, RNG.uniform(-10, 10) + 180 * j, ("GloveGrey", "Suede")[(k + j) % 2])
        # 2.05: flares (0), hanks (1), pilot books (2)
        if b == 0:
            for k, x in enumerate((a + 0.03, a + 0.32, a + 0.61)):
                for j in range(3 - (k == 1)):
                    box_item(P, x + 0.01 * j, y0 + 0.06, 2.05 + 0.1 * j, 0.27, 0.26, 0.095, ("Flares", (k + j) % 2), body="SignalRed")
        elif b == 1:
            for x, reg in ((a + 0.2, "HankNavy"), (m + 0.1, "HankManila"), (c - 0.16, "HankCream")):
                hank(P, x, yc, 2.05, 0.12 if x != m + 0.1 else 0.1, 0.036, reg, RNG.uniform(0, 90))
        else:
            books_row(P, a + 0.03, c - 0.32, y0 + 0.04, 0.3, 2.05, seed=30, hmin=0.24, hmax=0.30)
            z = hank(P, c - 0.16, yc, 2.05, 0.12, 0.036, "HankNavy", 15)
        # 2.50: cartons (<= 0.19 under the cap)
        xs = {0: (a + 0.03, a + 0.33, a + 0.63), 1: (a + 0.03, a + 0.36), 2: (7.36, 7.7)}[b]     # corbel x 7.1 .. 7.3
        for k, x in enumerate(xs):
            box_item(P, x, y0 + 0.06, 2.50, 0.29, 0.3, RNG.uniform(0.12, 0.16), ("Boxes", (b + k) % 4))
        # shelf-edge tickets
        tag(P, a + 0.05, y0 - 0.001, 0.725, b % 4)
        if b < 2:
            tag(P, a + 0.05, y0 - 0.001, 1.175, (b + 3) % 4)
    return P


def counter():
    P = SP("Counter")
    cx0, cx1, cyf, cyb, ch = L.COUNTER
    tx, ty = L.ATT["ATT_Till"][0], L.ATT["ATT_Till"][1]
    # receipt book and pen (between the chart and the till)
    rx0, ry0 = 4.72, 0.86
    P.box((rx0, ry0, ch), (rx0 + 0.15, ry0 + 0.21, ch + 0.012), "Paper", skip=("-z",))
    P.box((rx0 - 0.002, ry0 - 0.002, ch + 0.012), (rx0 + 0.152, ry0 + 0.212, ch + 0.016), "Covers",
          fits={"+z": ("Covers", fit_frame((rx0, ry0, ch + 0.016), (1, 0, 0), (0, 1, 0), 0.15, 0.21, atlas.cover_rect(0)))}, skip=("-z",))
    P.cyl((rx0 + 0.17, ry0 + 0.02, ch + 0.005), (rx0 + 0.2, ry0 + 0.16, ch + 0.005), 0.004, 5, "BlackPlastic")
    # keys on a cork float fob
    kx, ky = 4.42, 1.02
    P.torus(0.014, 0.0018, 8, 3, "Galv", frame(kx, ky, ch + 0.002))
    for k, a in enumerate((20, 75, 140)):
        M = frame(kx, ky, ch + 0.002, a)
        P.box((0.012, -0.004, 0.0), (0.062, 0.004, 0.0025), "Brass" if k != 1 else "Galv", M)
        P.box((0.008, -0.009, 0.0), (0.024, 0.009, 0.0025), "Brass" if k != 1 else "Galv", M)
    P.box((kx - 0.07, ky - 0.03, ch), (kx - 0.02, ky - 0.012, ch + 0.016), "SignalOrange")
    # chart weight (lead, brass knob) on the counter chart, clear of the Int's weights and rule
    M = frame(3.62, 1.1, ch + 0.007)
    P.lathe([(0.034, 0.0), (0.035, 0.012), (0.03, 0.022), (0.012, 0.026)], 10, "Lead", M, cap0=False, cap1=True)
    P.lathe([(0.012, 0.026), (0.008, 0.032), (0.012, 0.042), (0.0, 0.048)], 8, "Brass", M, cap0=False, cap1=False)
    # enamel mug (west end), inside and coffee
    M = frame(1.05, 0.95, ch, 30)
    prof = [(0.040, 0.0), (0.042, 0.004), (0.042, 0.092), (0.044, 0.096)]
    P.lathe(prof, 10, "Enamel", M, cap0=False, cap1=False)
    P.lathe([(0.044, 0.096), (0.038, 0.094), (0.038, 0.07)], 10, "Enamel", M, cap0=False, cap1=False)
    P.lathe([(0.038, 0.07), (0.0, 0.07)], 10, "Iron", M, cap0=False, cap1=False)
    P.torus(0.026, 0.006, 8, 4, "Enamel", M @ Matrix.Translation((0.045, 0, 0.05)) @ Matrix.Rotation(math.radians(90), 4, 'X'),
            arc=math.pi * 1.1, a0=-math.pi * 0.55)
    # a second logbook / pilot book on the counter west end
    P.box((0.78, 0.72, ch), (1.0, 1.02, ch + 0.03), "Suede",
          fits={"+z": ("Covers", fit_frame((0.78, 0.72, ch + 0.03), (1, 0, 0), (0, 1, 0), 0.22, 0.30, atlas.cover_rect(1)))}, skip=("-z",))
    # handheld VHF in its charging cradle, east of the till (face toward the customer, -Y)
    vx, vy = 6.62, 0.86
    P.box((vx - 0.045, vy - 0.035, ch), (vx + 0.045, vy + 0.04, ch + 0.05), "BlackPlastic", skip=("-z",))
    w, h = 0.058, 0.13
    rc = atlas.rect("VHF")
    rc = (rc[0] + (rc[2] - rc[0]) * 0.25, rc[1], rc[0] + (rc[2] - rc[0]) * 0.75, rc[3])
    zb = ch + 0.02
    P.box((vx - w / 2, vy - 0.016, zb), (vx + w / 2, vy + 0.018, zb + h), "BlackPlastic",
          fits={"-y": ("VHF", fit_frame((vx - w / 2, vy - 0.016, zb), (1, 0, 0), (0, 0, 1), w, h, rc))})
    P.cyl((vx + 0.016, vy + 0.002, zb + h), (vx + 0.016, vy + 0.002, zb + h + 0.11), 0.006, 5, "BlackPlastic")
    P.cyl((vx - 0.012, vy + 0.002, zb + h), (vx - 0.012, vy + 0.002, zb + h + 0.012), 0.008, 6, "BlackPlastic")
    # brass desk lamp by the till (east side), shade over the till keys; ATT_Light_Till at the bulb
    lx, ly = tx + 0.62, ty + 0.12
    M = frame(lx, ly, ch)
    P.lathe([(0.075, 0.0), (0.075, 0.012), (0.05, 0.022), (0.016, 0.03)], 12, "Brass", M, cap0=False, cap1=True)
    top = Vector((lx, ly, ch + 0.36))
    P.cyl((lx, ly, ch + 0.03), top, 0.008, 6, "Brass")
    head = Vector((lx - 0.2, ly - 0.03, ch + 0.42))
    P.cyl(top, head, 0.007, 6, "Brass")
    P.torus(0.012, 0.004, 6, 3, "Brass", Matrix.Translation(top) @ Matrix.Rotation(math.radians(90), 4, 'X'))
    Ms = Matrix.Translation(head) @ Matrix.Rotation(math.radians(-35), 4, 'Y') @ Matrix.Rotation(math.radians(180), 4, 'X')
    shade = [(0.014, -0.01), (0.03, 0.02), (0.058, 0.08), (0.068, 0.11)]
    P.lathe(shade, 12, "LampGreen", Ms, cap0=True, cap1=False)
    P.lathe(list(reversed([(r_ - 0.002, z_) for r_, z_ in shade])), 12, "Enamel", Ms, cap0=False, cap1=False)
    bulb = Ms @ Vector((0, 0, 0.055))
    P.lathe([(0.0, -0.022), (0.016, -0.014), (0.02, 0.0), (0.014, 0.014), (0.006, 0.022)], 8, "Glass", Matrix.Translation(bulb) @ Ms.to_3x3().to_4x4(), cap0=False, cap1=False)
    # shopkeeper-side open shelving (y 0.65 .. 1.22, faces +Y): shelves at 0.275 and 0.605
    ups = [cx0 + 0.02 + k * (cx1 - cx0 - 0.08) / 6 for k in range(7)]
    ya, yb = cyf + 0.07, cyb - 0.05
    for b, (u0, u1) in enumerate(zip(ups, ups[1:])):
        a, c = u0 + 0.06, u1 - 0.02
        m = (a + c) / 2
        for zs, lvl in ((0.275, 0), (0.605, 1)):
            kind = (b + 3 * lvl) % 6
            if kind == 0:
                for x, reg in ((a + 0.2, "HankManila"), (c - 0.22, "HankNavy")):
                    z = hank(P, x, (ya + yb) / 2, zs, 0.14, 0.04, reg, RNG.uniform(0, 90))
                    if lvl == 1:
                        hank(P, x, (ya + yb) / 2, z, 0.13, 0.038, "HankCream", RNG.uniform(0, 90))
            elif kind == 1:
                for k, x in enumerate((a, a + 0.33, a + 0.66)):
                    box_item(P, x, ya + 0.1, zs, 0.3, 0.36, 0.2 + 0.04 * (k % 2), ("Boxes", (b + k) % 4), face="+y")
            elif kind == 2:
                for k, x in enumerate((a + 0.02, a + 0.33, a + 0.64)):
                    for j in range(2):
                        box_item(P, x + 0.01 * j, ya + 0.12, zs + 0.1 * j, 0.27, 0.3, 0.095, ("Flares", (k + j) % 2), face="+y", body="SignalRed")
            elif kind == 3:
                chart_pile(P, a + 0.02, ya + 0.04, zs, 0.44, 0.34, 5)
                for j in range(4):
                    P.box((m + 0.06, ya + 0.08 + 0.005 * j, zs + 0.006 * j), (c - 0.02, yb - 0.04, zs + 0.006 * (j + 1)), "Card", skip=("-z",))
            elif kind == 4:
                tins_row(P, a, c, yb - 0.12, zs, [0, 2, 6, 1], "1l" if lvl == 0 else "small", seed=40 + b, stack=lvl == 1)
                tins_row(P, a + 0.05, c - 0.05, ya + 0.12, zs, [7, 1], "small", seed=50 + b)
            else:
                if lvl == 0:
                    for k in range(3):
                        book_stack(P, a + 0.15 + 0.32 * k, ya + 0.12, 0.3, zs, 4, seed=60 + b + k, face="+y")
                else:
                    books_row(P, a, c, ya + 0.2, 0.3, zs, face="+y", seed=70 + b, hmin=0.2, hmax=0.27)
    return P, bulb


def floor():
    P = SP("Floor")
    # crates against the front wall between the door swing (x <= -6.8) and the bay pilaster (x -4.6)
    yf = L.IY0 + 0.06          # lining 0.03 + skirting
    crate(P, -6.6, yf + 0.01, F, 0.62, 0.46, 0.42)
    crate(P, -6.52, yf + 0.04, F + 0.42, 0.5, 0.38, 0.32)
    box_item(P, -6.44, yf + 0.1, F + 0.74, 0.32, 0.26, 0.16, ("Boxes", 3))
    crate(P, -5.9, yf + 0.01, F, 0.62, 0.46, 0.46, lid=False)
    rolled_charts(P, -5.59, yf + 0.24, F + 0.05, 7, seed=1, top=F + 1.15)
    # stacked mooring-line coil on the floor in front of the bay pilaster
    stacked_coil(P, -4.2, -4.78, F, 0.24, 0.026, 6, "RopeManila", 30, tail=(-3.8, -4.4))
    # barrel of oars (between the hardware wall and the foot of the stair top), leaning to the east wall
    bx, by = 0.3, 0.1          # in front of the counter's west end, clear of the dog corner and the gondola
    stave = [(0.24, 0.0), (0.27, 0.15), (0.28, 0.3), (0.27, 0.45), (0.25, 0.58)]
    M = frame(bx, by, F)
    P.lathe(stave, 12, "Pine", M, cap0=False, cap1=False)
    P.lathe([(0.25, 0.58), (0.235, 0.575), (0.235, 0.5)], 12, "Pine", M, cap0=False, cap1=False)
    P.lathe([(0.235, 0.5), (0.0, 0.5)], 12, "Iron", M, cap0=False, cap1=False)
    for zh in (0.06, 0.2, 0.4, 0.53):
        rr = np.interp(zh, [p[1] for p in stave], [p[0] for p in stave]) + 0.004
        P.lathe([(rr, zh - 0.022), (rr, zh + 0.022)], 12, "Iron", M, cap0=False, cap1=False)
    r = random.Random(3)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        p0 = Vector((bx + 0.12 * math.cos(a), by + 0.12 * math.sin(a), F + 0.5))
        top = Vector((bx + 0.3 * math.cos(a) + r.uniform(-0.04, 0.04), by + 0.3 * math.sin(a), F + r.uniform(1.75, 1.95)))
        d = (top - p0).normalized()
        P.cyl(p0, top, 0.02, 6, "Oar", caps=True)
        P.cyl(top, top + d * 0.12, 0.016, 6, "Oar")                      # grip
        # blade at the bottom, inside the barrel, its loom shows: leather and button
        P.cyl(p0 + d * 0.55, p0 + d * 0.62, 0.025, 6, "Suede", caps=False)
        bl = p0 - d * 0.42
        side = d.cross(Vector((0, 0, 1))).normalized()
        P.mesh([p0 - side * 0.02, p0 + side * 0.02, bl + side * 0.07, bl - side * 0.07], [(0, 1, 2, 3), (3, 2, 1, 0)], "Oar")
    # Admiralty anchor lying flat (stock folded along the shank), crown west, ring toward the barrel (+X)
    ax, ay = -1.12, 0.22
    Ma = frame(ax, ay, 0, -90)          # local +Y (shank) -> world +X
    def A(p):
        return Ma @ Vector(p)
    P.cyl(A((0, 0, F + 0.04)), A((0, 0.78, F + 0.04)), 0.03, 6, "Iron")
    P.torus(0.07, 0.014, 10, 4, "Iron", Ma @ Matrix.Translation((0, 0.86, F + 0.016)))
    P.cyl(A((-0.05, 0.68, F + 0.08)), A((0.05, 0.68, F + 0.08)), 0.018, 6, "Iron")     # stock pin
    P.cyl(A((0.04, 0.12, F + 0.1)), A((0.04, 0.84, F + 0.1)), 0.022, 6, "Iron")        # folded stock
    for s_ in (-1, 1):
        arm = [A((0, 0, F + 0.04)), A((s_ * 0.16, 0.04, F + 0.04)), A((s_ * 0.27, 0.15, F + 0.04)), A((s_ * 0.31, 0.28, F + 0.04))]
        P.sweep(arm, 0.028, 6, "Iron")
        c = (0, 0, 0)
        loc = [(s_ * 0.31 + s_ * -0.06, 0.18, F + 0.02), (s_ * 0.31 + s_ * 0.06, 0.24, F + 0.02), (s_ * 0.31 + s_ * 0.03, 0.40, F + 0.02),
               (s_ * 0.31 + s_ * -0.06, 0.18, F + 0.06), (s_ * 0.31 + s_ * 0.06, 0.24, F + 0.06), (s_ * 0.31 + s_ * 0.03, 0.40, F + 0.06)]
        P.mesh([A(q) for q in loc],
               [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)] if s_ > 0 else
               [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "Iron")
    return P


def window():
    P = SP("Window")
    x0, x1, yo, yi, z = L.BAY_FLOOR
    y = (yo + yi) / 2                       # -6.025
    # west end: crate with a lantern
    crate(P, -4.3, y - 0.2, z, 0.5, 0.36, 0.26)
    lamp(P, -4.05, y - 0.02, z + 0.26, 20)
    # flaked cream line
    flake(P, -1.5, y + 0.02, z, 0.05, 6, 0.022, "RopeCream", 40)
    # sea boots
    boots(P, -0.35, y + 0.05, z, -12)
    # chart on a sloping board, to the street (-Y)
    bx0, bx1 = 0.55, 1.25
    P.box((bx0, y - 0.05, z), (bx1, y + 0.25, z + 0.08), "Pine", skip=("-z",))
    th = math.radians(55)
    M = Matrix.Translation((bx0, y - 0.1, z + 0.02)) @ Matrix.Rotation(th, 4, 'X')
    P.box((0, 0, -0.02), (bx1 - bx0, 0.38, 0.0), "Pine", M)
    o = M @ Vector((0.02, 0.01, 0.001))
    ua = Vector((1, 0, 0))
    va = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
    nrm = (M.to_3x3() @ Vector((0, 0, 1))).normalized()
    cw, chh = bx1 - bx0 - 0.04, 0.33
    pts = [o, o + ua * cw, o + ua * cw + va * chh, o + va * chh]
    rc = atlas.rect("Chart")
    P.quad([p + nrm * 0.002 for p in pts], [(rc[0], rc[1]), (rc[2], rc[1]), (rc[2], rc[3]), (rc[0], rc[3])], "Chart")
    P.box((bx0, y - 0.13, z), (bx1, y - 0.09, z + 0.05), "Pine")       # ledge stop
    # tins pyramid
    for k, xx in enumerate((2.3, 2.48, 2.66)):
        tin(P, xx, y + 0.02, z, (3, 4, 5)[k], "big", yaw=(k - 1) * 12)
    for k, xx in enumerate((2.39, 2.57)):
        tin(P, xx, y + 0.02, z + 0.192, (0, 1)[k], "1l", yaw=(k - 0.5) * 20)
    tin(P, 2.48, y + 0.02, z + 0.314, 7, "small")
    # hanks with a block and shackles
    zz = hank(P, 3.6, y + 0.02, z, 0.16, 0.045, "HankNavy", 15)
    hank(P, 3.6, y + 0.02, zz, 0.14, 0.04, "HankManila", 75)
    block(P, frame(3.95, y - 0.14, z + 0.052, 20, 90, 0))
    shackle(P, frame(3.33, y - 0.2, z + 0.014, 30, 90, 0), 1.6)
    # east of mannequin 02: navy flake, two tins, a crate of flares and a pilot book
    flake(P, 6.2, y + 0.02, z, 0.05, 5, 0.02, "RopeNavy", 0)
    tin(P, 6.75, y - 0.1, z, 2, "1l", yaw=-10)
    tin(P, 6.88, y + 0.08, z, 6, "1l", yaw=15)
    crate(P, 7.15, y - 0.2, z, 0.5, 0.36, 0.22)
    box_item(P, 7.2, y - 0.17, z + 0.22, 0.27, 0.26, 0.095, ("Flares", 0), body="SignalRed")
    box_item(P, 7.21, y - 0.16, z + 0.315, 0.25, 0.24, 0.09, ("Flares", 1), body="SignalRed")
    P.box((7.52, y - 0.17, z + 0.22), (7.62, y + 0.1, z + 0.25), "Suede",
          fits={"+z": ("Covers", fit_frame((7.52, y - 0.17, z + 0.25), (1, 0, 0), (0, 1, 0), 0.1, 0.27, atlas.cover_rect(1)))})
    return P


def clean(obj):
    """Drop zero-area faces (lathe poles, decimation collapses) and the loose verts they leave."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bad = [f for f in bm.faces if f.calc_area() <= 1e-7]
    if bad:
        bmesh.ops.delete(bm, geom=bad, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    if loose:
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def lod1(obj):
    """LOD1 at half the LOD0 triangles (the class makes no LODs: kept for the bay-window view from the quay)."""
    o = versions.copy_object(obj, obj.name.replace("_LOD0", "_LOD1"))
    versions.decimate(o, versions.triangles(obj.data) // 2)
    versions.weighted_normals(o)
    clean(o)
    print("[H2stock] %s %d tris" % (o.name, versions.triangles(o.data)))
    return o


def build():
    bw, gs = back_wall(), gear_shelves()
    cp, bulb = counter()
    groups = [bw, gs, cp, floor(), window()]
    tints = {"BackWall": (0.5, 0.4, 0.3), "GearShelves": (0.35, 0.4, 0.3), "Counter": (0.5, 0.35, 0.2),
             "Floor": (0.4, 0.3, 0.2), "Window": (0.3, 0.35, 0.45)}
    mat = None
    meshes = []
    total = 0
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for P in groups:
        mat = kit.material("MI_ChandleryStock_%s" % P.name, tints[P.name])
        obj = clean(P.to_object("%s_%s_LOD0" % (NAME, P.name), mat))
        meshes.append({"object": obj, "set": "Atlas"})
        meshes.append({"object": lod1(obj), "set": "Atlas"})
        t = versions.triangles(obj.data)
        total += t
        print("[H2stock] %s LOD0 %d tris" % (P.name, t))
        for v in P.v:
            lo = Vector(map(min, lo, v))
            hi = Vector(map(max, hi, v))
    print("[H2stock] LOD0 total %d" % total)
    e = bpy.data.objects.new("ATT_Light_Till", None)
    e.location = L.studs(tuple(bulb))
    bpy.context.scene.collection.objects.link(e)
    size = hi - lo
    print("[H2stock] bbox m %.2f x %.2f x %.2f" % tuple(size))

    def at(p):
        return [p[0] * 3.0, p[1] * 3.0, p[2] * 3.0]
    return {
        "name": NAME,
        "budget": "helm_interior",
        "tris": 30000,
        "tier": "standard",
        "dims_m": (round(size.x, 3), round(size.y, 3), round(size.z, 3)),
        "size_note": None,
        "origin": "free",
        "origin_note": "shared Chandlery frame (layout.py): pivot = M_Bld_Chandlery_Ext / _Int pivot; stock is authored on the Int's shelves",
        "tiling": True,
        "atlas": "ChandleryStock_Atlas",
        "waivers": {
            "texture sets": "one shared 2048 stock atlas (woods, metals, knits, rope and hank tiles, labels) by design: the Studio "
                            "import maps every stock MeshPart to set Atlas; a second set would only split the same small items",
            "LOD1 triangles": "close-up interior set class (30,000 = the docs/12 props row) makes no LODs; a LOD1 at 0.5 is kept "
                              "for the bay-window display seen from the quay",
            "LOD UV layout": "collapse decimation of many small items on one atlas merges small islands (labels, spines, rope tiles), "
                             "so UV area / bounds shift; every LOD still samples the same atlas regions",
        },
        "sets": [{"name": "ChandleryStock", "set": "Atlas", "size": 2048, "wet": False}],
        "meshes": meshes,
        "attachments": [e],
        "closeups": [
            {"name": "back_wall_shelves", "target": at((1.4, 5.2, 1.8)), "dist": 8, "az": 0, "el": 5},
            {"name": "gear_shelves", "target": at((6.7, 5.2, 1.4)), "dist": 9, "az": 0, "el": 5},
            {"name": "counter_till_lamp", "target": at((5.8, 0.95, 1.15)), "dist": 5, "az": 20, "el": 25},
            {"name": "counter_shelves_shopside", "target": at((3.0, 1.0, 0.5)), "dist": 8, "az": 180, "el": 15},
            {"name": "window_display", "target": at((1.5, -6.0, 0.4)), "dist": 12, "az": 0, "el": 15},
            {"name": "barrel_anchor", "target": at((-0.4, 0.2, 0.5)), "dist": 8, "az": 0, "el": 25},
        ],
    }
