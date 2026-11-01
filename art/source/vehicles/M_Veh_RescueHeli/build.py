"""M_Veh_RescueHeli: chunky Lego coastguard rescue helicopter (replaces the Heli/Builder.luau greybox look).

Frame = Heli/Builder.luau, authored in Roblox axes (x right, y up, nose -z; Blender = (-x, z, y)), 1 unit = 1 stud,
origin = HullRoot centre. One FBX per LOD holds six meshes plus the collider, all with identity transforms:
  M_Veh_RescueHeli_Body       cabin, nose, canopy, boom, fin, skids, winch (welded to HullRoot), minus the orange
  M_Veh_RescueHeli_Paint      the body's orange shell (livery primary, LiveryPaint.MESH_RULES)
  M_Veh_RescueHeli_Glass      r7: the tinted windscreen (set Glass: RGBA ALB, AlphaMode Transparency) over the cockpit;
                              r8: the side and door windows too
  M_Veh_RescueHeli_Gear       r8: skids + winch (welded to HullRoot), minus the orange (Paint holds it)
  M_Veh_RescueHeli_MainRotor  4 blades; built symmetric about the hub, so its bbox centre = ATT_MainRotor (spins on Y)
  M_Veh_RescueHeli_TailRotor  2 blades; bbox centre = ATT_TailRotor (spins on X)
  M_Veh_RescueHeli_COL        the 7 x 6 x 13 HullRoot box
Rotor clearance: the main rotor (hub y 5.5, blades y 4.75..6.25, tip corner r 15.28) stays clear of the fin (leading
edge z >= 19.3 at rotor height), the beacon (top 4.7) and the winch studs (top 4.35), and the tail disc (hub
(1.8, 3.4, 21.0), radius 4.2: z >= 16.8); the stabiliser (z <= 15.4) sits ahead of the tail disc (z >= 17.2 at its height).

    python3 art/source/vehicles/M_Veh_RescueHeli/maketex.py --out build/prod/M_Veh_RescueHeli/textures/M_Veh_RescueHeli
    MCP: run.py -- --build art/source/vehicles/M_Veh_RescueHeli/build.py --out-root build/prod/M_Veh_RescueHeli \
        --steps build,lod,validate,export,turntable
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
for _m in ("lego", "palette"):     # the live MCP session keeps modules between runs (other assets have their own)
    sys.modules.pop(_m, None)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Veh_RescueHeli"
SET_NAME, SET = "RescueHeli", "Lego"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_RescueHeli_Lego_ALB.png")

ROTOR_Y, ROTOR_R = 5.5, 15.0
TAIL_HUB, TAIL_R = (1.8, 3.4, 21.0), 4.2
DOOR_Z0, DOOR_Z1 = 0.4, 4.4                 # right-side sliding door; the winch hangs over its middle (z 2.4)
ROOF, DECK = 3.0, 4.1                       # cabin roof and engine deck tops
WINCH = (7.9, 1.55, 2.4)                    # cable top (under the drum), well outboard so it shows from behind
RING_R, RING_T = 0.95, 0.28                 # r5: the stowed rescue ring right under the hook block (no cable)
HOOK = (WINCH[0], WINCH[1] - 0.85 - RING_R, WINCH[2] + 0.4)   # hook block under the cable top, ring under it;
# r8: 0.4 aft of the cable so the ring clears the door badge in the winch close-up
PITCH, STUD_R, STUD_H = 1.0, 0.3, 0.25      # real Lego stud: 0.6 of the pitch, ~0.2 tall
# tail boom stations (z, half-width, bottom, top, chamfer); the stripe lofts follow the same stations
BOOM = [(5.0, 1.5, 0.3, 2.8, 0.4), (9.0, 1.0, 0.9, 2.7, 0.3), (22.4, 0.6, 1.6, 2.6, 0.2)]   # 3 -> 2 -> 1 studs


class R:
    """Roblox-axes authoring on a lego.B (x, y up, z back) -> Blender (-x, z, y)."""

    def __init__(self, b, lod=0):
        self.b, self.lod = b, lod

    def n(self, n):
        """Round-part sides per LOD."""
        return (n, max(6, n * 2 // 3), 6)[self.lod]

    @staticmethod
    def p(x, y, z):
        return (-x, z, y)

    def box(self, lo, hi, c, bev=None):
        """Every edge chamfered (bev, default 0.08); bev=0 and LOD2 give a plain box."""
        if bev == 0 or self.lod == 2:
            self.b.box(self.p(*lo), self.p(*hi), c, bevel=0)
        else:
            self.b.bbox(self.p(*lo), self.p(*hi), c, b=0.08 if bev is None else bev)

    def courses(self, x0, x1, y0, y1, z0, z1, c, n, brick=4.0, top_bev=0.08, k0=0):
        """A block laid as n brick courses in running bond: chamfered bricks overlap 0.02, so every course and
        brick end reads as a V seam (LOD2: one box)."""
        if self.lod == 2:
            return self.box((x0, y0, z0), (x1, y1, z1), c)
        hy = (y1 - y0) / n
        for k in range(n):
            ya, yb = y0 + k * hy - (0.01 if k else 0), y0 + (k + 1) * hy + (0.01 if k < n - 1 else 0)
            cuts = [z0]
            z = z0 + (brick / 2 if (k + k0) % 2 else brick)
            while z < z1 - 0.8:
                cuts.append(z)
                z += brick
            cuts.append(z1)
            for i in range(len(cuts) - 1):
                za = cuts[i] - (0.01 if i else 0)
                zb = cuts[i + 1] + (0.01 if i < len(cuts) - 2 else 0)
                self.box((x0, ya, za), (x1, yb, zb), c, bev=top_bev if k == n - 1 else 0.08)

    def vcyl(self, x, z, y0, y1, r, c, n=10):
        self.b.cyl(-x, z, y0, y1, r, c, self.n(n))

    def xcyl(self, x, y, z, r, length, c, n=10):
        self.b.cyl_x(-x, z, y, r, length, c, self.n(n))

    def stud(self, x, y, z, c):
        if self.lod < 2:
            self.b.stud(-x, z, y - 0.03, STUD_R, STUD_H + 0.03, c, n=(8, 6)[self.lod], ch=(0.06, 0)[self.lod])

    def studs(self, x0, x1, z0, z1, y, c, skip=lambda x, z: False):
        """Studs on the 1-stud Lego grid (centres on half studs) inside x0..x1, z0..z1."""
        nx, nz = int(round(x1 - x0)), int(round(z1 - z0))
        for i in range(nx):
            for k in range(nz):
                x, z = x0 + (i + 0.5) * PITCH, z0 + (k + 0.5) * PITCH
                if not skip(x, z):
                    self.stud(x, y, z, c)

    def sphere(self, x, y, z, r, c, zmin=-0.9, n=12):
        self.b.sphere(-x, z, y, r, c, n=self.n(n), m=(5, 4, 3)[self.lod], zmin=zmin)

    def ring(self, z, hx, y0, y1, ch, cx=0.0, cb=None, ct=None):
        cb = ch if cb is None else cb
        ct = ch if ct is None else ct
        pts = [(cx - hx + cb, y0), (cx + hx - cb, y0), (cx + hx, y0 + cb), (cx + hx, y1 - ct),
               (cx + hx - ct, y1), (cx - hx + ct, y1), (cx - hx, y1 - ct), (cx - hx, y0 + cb)]
        return [self.p(x, y, z) for x, y in pts]

    def rect(self, z, hx, y0, y1):
        return [self.p(x, y, z) for x, y in ((-hx, y0), (hx, y0), (hx, y1), (-hx, y1))]

    def loft(self, rings, c):
        self.b.loft(rings, c)

    def prof(self, x0, x1, zy, c):
        """A (z, y) side profile extruded across x0..x1."""
        self.b.prof_x(-x1, -x0, list(zy), c)

    def _axis(self, a, b):
        """Blender start point, unit direction, length and two unit normals of the a -> b axis (Roblox points)."""
        A, B = self.p(*a), self.p(*b)
        d = [B[i] - A[i] for i in range(3)]
        L = math.sqrt(sum(v * v for v in d))
        d = [v / L for v in d]
        h = (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (1.0, 0.0, 0.0)
        u = [d[1] * h[2] - d[2] * h[1], d[2] * h[0] - d[0] * h[2], d[0] * h[1] - d[1] * h[0]]
        lu = math.sqrt(sum(v * v for v in u))
        u = [v / lu for v in u]
        w = [d[1] * u[2] - d[2] * u[1], d[2] * u[0] - d[0] * u[2], d[0] * u[1] - d[1] * u[0]]
        return A, d, L, u, w

    def tube(self, a, b, r, c, n=12):
        """A round bar from a to b (Roblox points)."""
        n = self.n(n)
        A, d, L, u, w = self._axis(a, b)
        B = [A[k] + L * d[k] for k in range(3)]
        ring = lambda P0: [tuple(P0[k] + r * (math.cos(2 * math.pi * i / n) * u[k] + math.sin(2 * math.pi * i / n) * w[k])
                                 for k in range(3)) for i in range(n)]
        faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        faces += [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
        self.b._emit(ring(A) + ring(B), faces, c, smooth=True)

    def dome(self, a, b, r, hd, c, n=24):
        """r8: a round domed plate: a disc from a to b, then a dome hd tall on b's face (lamps, skid end caps)."""
        n, m = self.n(n), (6, 4, 2)[self.lod]
        A, d, L, u, w = self._axis(a, b)
        rings = [(r, 0.0)] + [(r * math.cos(math.pi / 2 * j / m), L + hd * math.sin(math.pi / 2 * j / m))
                              for j in range(m)]
        verts = [tuple(A[k] + t * d[k] + rr * (math.cos(2 * math.pi * i / n) * u[k] + math.sin(2 * math.pi * i / n) * w[k])
                       for k in range(3)) for rr, t in rings for i in range(n)]
        verts.append(tuple(A[k] + (L + hd) * d[k] for k in range(3)))
        top = len(verts) - 1
        faces = [(j * n + i, j * n + (i + 1) % n, (j + 1) * n + (i + 1) % n, (j + 1) * n + i)
                 for j in range(len(rings) - 1) for i in range(n)]
        faces += [(m * n + i, m * n + (i + 1) % n, top) for i in range(n)] + [tuple(reversed(range(n)))]
        self.b._emit(verts, faces, c, smooth=True)     # the 90 deg rim edge stays sharp (set_sharp_from_angle 50)

    def torus_z(self, x, y, z, R_, r, c):
        """A ring standing in the x-y plane (faces the chase cam); r8: 48 x 12 at LOD0."""
        self.b.torus(-x, z, y, R_, r, c, maj=(48, 24, 12)[self.lod], mnr=(12, 8, 4)[self.lod], axis=1)


def window(h, side, y0, y1, z0, z1, x_face, frame=P.WHITE):
    """Glass panel standing 0.1 proud of the skin at x_face, framed by four bevelled bars standing 0.06 prouder."""
    s = side
    if h.lod == 2:      # far: glass with one flat frame plate behind it
        h.box((s * (x_face - 0.1), y0 - 0.2, z0 - 0.2), (s * (x_face + 0.05), y1 + 0.2, z1 + 0.2), frame, bev=0)
        h.box((s * (x_face - 0.08), y0, z0), (s * (x_face + 0.12), y1, z1), P.GLASS, bev=0)
        return
    # r8: the canopy's tinted glass over a grey back wall and a charcoal seat back (each face 0.04 apart)
    h.box((s * (x_face - 0.1), y0, z0), (s * (x_face + 0.12), y1, z1), P.CGLASS, bev=0.04)
    h.box((s * (x_face - 0.05), y0 + 0.03, z0 + 0.03), (s * (x_face + 0.04), y1 - 0.03, z1 - 0.03), P.GREY, bev=0.02)
    zc, zw = (z0 + z1) / 2, (z1 - z0) * 0.28
    h.box((s * (x_face - 0.05), y0 + 0.03, zc - zw), (s * (x_face + 0.08), y0 + (y1 - y0) * 0.62, zc + zw), P.DARK,
          bev=0.04)
    f0, f1, t = x_face - 0.1, x_face + 0.16, 0.22
    h.box((s * f0, y1 - 0.02, z0 - t), (s * f1, y1 + t, z1 + t), frame, bev=0.06)       # top
    h.box((s * f0, y0 - t, z0 - t), (s * f1, y0 + 0.02, z1 + t), frame, bev=0.06)       # sill
    h.box((s * f0, y0 - 0.01, z0 - t), (s * f1, y1 + 0.01, z0 + 0.02), frame, bev=0.06)  # front post
    h.box((s * f0, y0 - 0.01, z1 - 0.02), (s * f1, y1 + 0.01, z1 + t), frame, bev=0.06)  # rear post


def badge(h, s, xf, y, z, k=1.7):
    """Rescue badge (k = scale): charcoal rim, orange disc, white cross, each 0.04 prouder than the last (s = side)."""
    h.xcyl(s * (xf + 0.03), y, z, 0.78 * k, 0.1, P.DARK, n=20)
    h.xcyl(s * (xf + 0.07), y, z, 0.64 * k, 0.1, P.ORANGE, n=20)
    a, w = 0.44 * k, 0.14 * k
    h.box((s * (xf + 0.08), y - a, z - w), (s * (xf + 0.16), y + a, z + w), P.WHITE, bev=0.03)
    h.box((s * (xf + 0.08), y - w, z - a), (s * (xf + 0.18), y + w, z + a), P.WHITE, bev=0.03)


def boom_at(z):
    """Boom station (hx, y0, y1, ch) at z, interpolated like the loft."""
    for a, b in zip(BOOM, BOOM[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return tuple(a[i] + (b[i] - a[i]) * t for i in range(1, 5))
    raise ValueError(z)


def frame_bar(h, a, b, c=P.DARK, r=0.17):
    h.tube(a, b, r, c, n=6)


def cockpit(h):
    """r7: what the tinted windscreen shows: a charcoal dash with instrument tiles, two seats, a minifig pilot on the
    driver side (the player's character sits buried in the hull at ATT_DriverSeat, so it never doubles up)."""
    h.box((-2.3, 0.3, -5.4), (2.3, 1.0, -4.7), P.DARK, bev=0.08)
    for x, c in ((-1.55, P.GREEN), (-0.6, P.YELLOW), (0.35, P.RED), (1.3, P.METAL)):
        h.box((x - 0.3, 0.95, -5.25), (x + 0.3, 1.08, -4.85), c, bev=0.03)
    for cx in (-1.3, 1.3):
        h.box((cx - 0.7, 0.3, -4.35), (cx + 0.7, 0.75, -3.2), P.DARK, bev=0.08)    # seat base
        h.box((cx - 0.7, 0.7, -3.55), (cx + 0.7, 2.1, -3.2), P.DARK, bev=0.08)     # seat back
    c, zh = 1.3, -3.7
    h.box((c - 0.45, 0.72, -4.4), (c + 0.45, 1.1, -3.5), P.GREY, bev=0.06)          # hips + thighs
    h.box((c - 0.5, 1.05, -3.9), (c + 0.5, 1.8, -3.48), P.WHITE, bev=0.06)          # torso
    h.box((c - 0.55, 1.3, -3.95), (c + 0.55, 1.46, -3.48), P.RED, bev=0.03)         # red chest band
    for s in (-1, 1):
        h.tube((c + s * 0.58, 1.68, -3.7), (c + s * 0.5, 1.22, -4.42), 0.15, P.WHITE, n=8)
        h.sphere(c + s * 0.5, 1.2, -4.5, 0.15, P.YELLOW)
    h.vcyl(c, zh, 1.76, 2.2, 0.28, P.YELLOW, n=12)                                 # head
    h.sphere(c, 2.2, zh, 0.35, P.WHITE, zmin=-0.25)                                # helmet
    h.box((c - 0.27, 1.98, zh - 0.33), (c + 0.27, 2.14, zh - 0.22), P.GLASS, bev=0.03)   # dark visor


def body(h):
    # --- cabin: charcoal belly + belly stripe, orange brick-course hull, charcoal pinline under a white brick stripe
    h.box((-3.1, -2.85, -4.2), (3.1, -2.4, 5.2), P.DARK, bev=0.1)
    h.courses(-3.45, 3.45, -2.6, -1.53, -4.6, 5.5, P.DARK, 1)              # charcoal lower-hull course (abuts)
    h.courses(-3.45, 3.45, -1.53, -0.45, -4.6, 5.5, P.ORANGE, 1, k0=1)
    h.box((-3.52, -0.8, -4.68), (3.52, -0.4, 5.58), P.DARK, bev=0.05)
    h.courses(-3.58, 3.58, -0.5, 0.36, -4.74, 5.64, P.WHITE, 1, brick=2.0, top_bev=0.1)
    h.courses(-3.35, 3.35, 0.3, ROOF, -3.3, 5.5, P.ORANGE, 2, top_bev=0.22)
    # tapered nose in two courses (V seam between them), a white lip on its top edge, the framed windscreen on it
    nose = [(-4.3, 3.37, -2.55, 0.12, 0.45, -1.25), (-6.1, 3.0, -2.4, -0.1, 0.55, -1.25),
            (-7.6, 2.0, -2.0, -0.55, 0.45, -1.3)]
    h.loft([h.ring(z, hx, y0, ys + 0.015, ch, ct=0.08) for z, hx, y0, y1, ch, ys in nose], P.ORANGE)
    h.loft([h.ring(z, hx - 0.01, ys - 0.015, y1, ch, cb=0.08) for z, hx, y0, y1, ch, ys in nose], P.ORANGE)
    h.loft([h.ring(z - (0.05 if z < -7 else 0), hx + 0.07, y1 - 0.2, y1 + 0.1, 0.12) for z, hx, y0, y1, ch, ys in nose],
           P.WHITE)                                                       # lip cap 0.05 ahead of the nose caps
    glass = [(-3.15, 3.2, -0.3, 3.12, 0.5), (-5.3, 2.9, -0.35, 1.55, 0.45), (-6.85, 2.12, -0.4, 0.12, 0.3)]
    h.loft([h.ring(*g) for g in glass], P.CGLASS)                         # r7: see-through tinted glass mesh
    cockpit(h)
    # charcoal windscreen frame: header, centre post, A-pillars on the top and side corners, a cross seam at mid-screen
    h.box((-3.0, 2.85, -3.5), (3.0, 3.35, -2.95), P.DARK, bev=0.1)
    top = [(0, g[3] + 0.02, g[0]) for g in glass]
    for a, b in zip(top, top[1:]):
        frame_bar(h, a, b)
    for s in (-1, 1):
        for k in (0, 1):     # 0: top corner (hx - ch, y1), 1: side corner (hx, y1 - ch)
            pts = [(s * (hx - ch * (1 - k)), y1 - ch * k, z) for z, hx, y0, y1, ch in glass]
            for a, b in zip(pts, pts[1:]):
                frame_bar(h, a, b)
    z, hx, y0, y1, ch = glass[1]
    seam = [(-hx, y0 + 0.4), (-hx, y1 - ch), (-hx + ch, y1), (hx - ch, y1), (hx, y1 - ch), (hx, y0 + 0.4)]
    for a, b in zip(seam, seam[1:]):
        frame_bar(h, (a[0] * 1.01, a[1], z), (b[0] * 1.01, b[1], z), r=0.15)
    # engine deck (white bricks) with intakes, fairing into the boom, mast; studs on every flat top
    h.courses(-2.0, 2.0, 2.8, DECK, -1.6, 4.5, P.WHITE, 1, brick=2.0, top_bev=0.2)
    h.prof(-2.5, 2.5, [(4.3, 2.6), (7.2, 2.6), (7.2, 3.05), (4.3, 4.05)], P.DARK)   # wide charcoal engine cowling
    for s in (-1, 1):
        h.tube((s * 2.0, 3.3, 5.6), (s * 2.95, 3.45, 6.7), 0.3, P.METAL, n=10)      # exhaust stubs
        h.tube((s * 2.9, 3.44, 6.62), (s * 2.97, 3.45, 6.72), 0.2, P.DARK, n=10)
    for s in (-1, 1):
        h.box((s * 1.95, 3.1, -1.2), (s * 2.16, 3.8, 0.2), P.DARK, bev=0.05)
    h.vcyl(0, 0, 3.95, 4.7, 0.55, P.METAL, n=12)                          # mast (top inside the rotor collar)
    h.studs(-3.0, 3.0, -3.0, -2.0, ROOF, P.ORANGE)                        # roof ahead of the deck
    for x0 in (-3.0, 2.0):                                                # white shoulders read from the chase cam
        h.studs(x0, x0 + 1, -2.0, 5.0, ROOF, P.WHITE,
                skip=lambda x, z: x > 2 and 1.3 < z < 3.5)                # roof beside the deck (not under the winch)
    h.studs(-2.0, 2.0, -1.5, 4.5, DECK, P.WHITE,
            skip=lambda x, z: math.hypot(x, z) < 1.6 or (z > 3.4 and abs(x) < 1))
    h.vcyl(0, 3.95, DECK - 0.04, 4.3, 0.45, P.DARK, n=12)                 # red beacon dome on the deck
    h.sphere(0, 4.28, 3.95, 0.42, P.RED, zmin=0.0)
    # --- rear bulkhead: white panel, charcoal frame, orange cross, tail lights (the chase cam's view of the cabin)
    # r5: white clamshell doors (2x the boom), charcoal split under the boom, an orange cross on each leaf,
    # red / green tail-light studs, yellow handles either side of the split
    # r8: each leaf a panel (face z 5.8) recessed 0.15 inside white bevelled rims (stiles + rails, face 5.95), charcoal
    # hinge plates over the outer stiles, domed 1x1 red / green lamps, yellow handles outside the cross arms
    h.box((-3.2, -2.3, 5.45), (3.2, 2.75, 5.8), P.WHITE, bev=0.1)
    for s in (-1, 1):
        h.box((s * 2.92, -2.3, 5.72), (s * 3.25, 2.8, 5.9), P.DARK, bev=0.06)
        for xa, xb in ((0.06, 0.32), (2.66, 2.92)):                         # inner / outer stile
            x0, x1 = sorted((s * xa, s * xb))
            h.box((x0, -2.05, 5.72), (x1, 2.45, 5.95), P.WHITE, bev=0.06)
        x0, x1 = sorted((s * 0.32, s * 2.66))
        for ya, yb in ((-2.05, -1.79), (2.19, 2.45)):                       # bottom / top rail between the stiles
            h.box((x0, ya, 5.72), (x1, yb, 5.95), P.WHITE, bev=0.06)
        x0, x1 = sorted((s * 2.55, s * 3.15))
        for y in (-1.2, 0.9):
            h.box((x0, y - 0.22, 5.85), (x1, y + 0.22, 6.03), P.DARK, bev=0.04)
        x0, x1 = sorted((s * 1.5, s * 1.75))
        h.box((x0, -1.2, 5.76), (x1, -0.45, 6.0), P.YELLOW, bev=0.05)
        h.dome((s * 2.2, 1.6, 5.76), (s * 2.2, 1.6, 6.0), 0.45, 0.2, P.RED if s < 0 else P.GREEN)
    # one raised bevelled cross plate on the doors' centre over the split, its top arm 0.3 under the boom collar
    h.box((-0.06, -2.05, 5.72), (0.06, 0.45, 5.91), P.DARK, bev=0.02)    # the clamshell split, under the rims' face
    h.box((-1.25, -1.15, 5.76), (1.25, -0.5, 6.06), P.ORANGE, bev=0.08)
    h.box((-0.33, -1.7, 5.76), (0.33, 0.05, 6.1), P.ORANGE, bev=0.08)
    h.box((-3.25, -2.4, 5.72), (3.25, -2.05, 5.9), P.DARK, bev=0.06)
    h.box((-3.25, 2.45, 5.72), (3.25, 2.8, 5.9), P.DARK, bev=0.06)
    # --- windows: cockpit side windows, left cabin window, right sliding door (window, rail, handle, badge)
    for s in (-1, 1):
        window(h, s, 0.6, 2.45, -3.0, -0.6, 3.35)
    window(h, -1, 0.6, 2.45, 0.6, 4.5, 3.35)
    h.box((3.35, -2.35, DOOR_Z0), (3.66, 2.75, DOOR_Z1), P.WHITE, bev=0.1)
    h.box((3.56, 0.6, DOOR_Z0 + 0.45), (3.79, 2.35, DOOR_Z1 - 0.45), P.CGLASS, bev=0.04)   # r8: tinted, see-through
    h.box((3.6, 0.63, DOOR_Z0 + 0.48), (3.71, 2.32, DOOR_Z1 - 0.48), P.GREY, bev=0.02)
    h.box((3.6, 0.63, 1.85), (3.75, 1.7, 2.95), P.DARK, bev=0.04)                         # seat back behind it
    h.box((3.5, 2.82, -0.2), (3.72, 3.05, 5.4), P.DARK, bev=0.05)         # door rail
    h.box((3.62, 0.0, DOOR_Z0 + 0.3), (3.84, 0.45, DOOR_Z0 + 0.55), P.YELLOW, bev=0.05)   # handle
    badge(h, 1, 3.66, -1.1, 2.4, k=2.1)
    badge(h, -1, 3.62, -1.1, 2.4, k=2.1)
    # --- tail: wider tapered boom, white stripe + charcoal pinline from the cabin waist, white top band with studs
    # r8: a white boom (the orange lower chamfer read as an orange bar from the side) with the charcoal pinline as its
    # seam; orange only on the flat underside (low rear view), which ends in a charcoal collar at the doors
    h.loft([h.ring(z, hx, y0, y1, ch) for z, hx, y0, y1, ch in BOOM], P.WHITE)
    stripe = [(5.0, 0.9), (9.0, 1.35), (22.0, 1.85)]       # (z, stripe bottom); keeps to the boom's flat side
    h.loft([h.rect(z, boom_at(z)[0] + 0.03, y - 0.16, y + 0.04) for z, y in stripe], P.DARK)   # charcoal pinline
    h.loft([h.rect(z, boom_at(z)[0] - boom_at(z)[3] - 0.02, boom_at(z)[1] - 0.05, boom_at(z)[1] + 0.02)
            for z in (5.0, 9.0, 22.3)], P.ORANGE)
    for z in (8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.5):              # stud row along the boom
        h.stud(0, boom_at(z)[2], z, P.WHITE)
    for za, zb in ((5.84, 6.24), (9.6, 9.9), (16.3, 16.6)):               # root collar + two 0.3 charcoal bands
        h.loft([h.ring(z, boom_at(z)[0] + 0.11, boom_at(z)[1] - 0.09, boom_at(z)[2] + 0.13, boom_at(z)[3])
                for z in (za, zb)], P.DARK)
    # fin 1.5x: orange root, r7 white upper half with an orange cross each side over a charcoal pinline, red cap;
    # gearbox stub out to the tail rotor hub
    h.prof(-0.66, 0.66, [(18.0, 2.0), (22.0, 2.0), (22.6, 6.0), (20.0, 6.0)], P.ORANGE)   # low fin: roof shows over it
    h.prof(-0.7, 0.7, [(18.86, 3.78), (22.31, 3.78), (22.36, 4.08), (19.01, 4.08)], P.DARK)
    h.prof(-0.75, 0.75, [(18.95, 3.95), (22.33, 3.95), (22.62, 5.85), (19.88, 5.85)], P.WHITE)
    h.box((-0.76, 5.8, 19.85), (0.76, 6.45, 22.85), P.RED, bev=0.14)
    for s in (-1, 1):
        h.box((s * 0.7, 4.2, 20.6), (s * 0.82, 5.6, 21.2), P.ORANGE, bev=0.03)
        h.box((s * 0.7, 4.6, 20.15), (s * 0.82, 5.2, 21.65), P.ORANGE, bev=0.03)
    h.xcyl(0.95, TAIL_HUB[1], TAIL_HUB[2], 0.36, 0.8, P.METAL, n=10)      # tail gearbox stub (ends inside the hub)
    # stabiliser: 4-stud white plate, white studded end caps on a charcoal seam, r8: orange only on their tip caps
    h.box((-3.8, 1.6, 11.4), (3.8, 2.2, 15.4), P.WHITE, bev=0.12)       # inboard of the hoist ring in the chase view
    for s in (-1, 1):
        x0, x1 = sorted((s * 3.4, s * 4.2))                # r6: white endplates 40% lower, orange caps (no orange legs)
        h.box((x0, 1.2, 11.2), (x1, 3.0, 15.6), P.WHITE, bev=0.12)
        h.box((x0 - 0.05, 2.96, 11.15), (x1 + 0.05, 3.4, 15.65), P.WHITE, bev=0.1)
        h.box((x0 - 0.08, 2.9, 11.12), (x1 + 0.08, 3.02, 15.68), P.DARK, bev=0.03)
        for za, zb in ((11.1, 11.6), (15.2, 15.7)):
            h.box((x0 - 0.09, 2.88, za), (x1 + 0.09, 3.44, zb), P.ORANGE, bev=0.08)
        for z in (12.4, 13.4, 14.4):
            h.stud(s * 3.8, 3.4, z, P.WHITE)
        for x in (2.0, 3.0):
            for z in (12.4, 14.4):
                h.stud(s * x, 2.2, z, P.WHITE)


def gear(h):
    """r8: skids + winch on their own MeshPart (Gear), so the Body stays under the 10k per-MeshPart limit."""
    # --- round charcoal skid tubes 1.4x wider (bottom at y -4.5 = Flight spec.skid), orange caps, studded steps;
    # r8: 24-sided, the end caps round domed plates
    for s in (-1, 1):
        x = s * 3.6
        h.tube((x, -4.02, 5.3), (x, -4.02, -4.75), 0.48, P.DARK, n=24)
        h.tube((x, -4.02, -4.75), (x, -3.24, -6.2), 0.48, P.DARK, n=24)
        h.sphere(x, -4.02, -4.75, 0.48, P.DARK, n=24)
        h.dome((x, -3.94, 5.0), (x, -3.94, 5.4), 0.56, 0.22, P.DARK)              # charcoal rear cap
        h.stud(x, -3.48, 5.22, P.WHITE)
        h.dome((x, -3.287, -6.112), (x, -3.098, -6.464), 0.56, 0.22, P.ORANGE)
        for z in (-2.5, 2.8):
            h.tube((x, -3.9, z), (s * 2.6, -2.5, z), 0.36, P.DARK, n=16)
            h.tube((x, -3.94, z - 0.3), (x, -3.94, z + 0.3), 0.56, P.DARK, n=24)   # r5: charcoal strut-foot collar
            h.stud(x, -3.48, z, P.WHITE)
        x0, x1 = sorted((s * 2.6, s * 4.6))
        h.box((x0, -3.62, -1.6), (x1, -3.32, 1.4), P.WHITE, bev=0.06)
        h.studs(x0, x1, -1.6, 1.4, -3.32, P.WHITE)
    # --- winch: chunky studded 1.2-stud arm well outboard (hazard bands), drum with white rims, thick cable, big ring
    h.box((2.85, 2.6, 1.5), (3.75, 4.2, 3.3), P.METAL, bev=0.12)
    h.box((3.3, 2.9, 1.8), (WINCH[0] + 0.55, 4.1, 3.0), P.WHITE, bev=0.14)
    for i in range(11):
        xa = 4.1 + i * 0.3
        e = 0.05 if i % 2 == 0 else 0.03
        xa, xb = (xa, xa + 0.3) if e == 0.05 else (xa - 0.03, xa + 0.33)
        h.box((xa, 2.9 - e, 1.8 - e), (xb, 4.1 + e, 3.0 + e), P.YELLOW if e == 0.05 else P.DARK, bev=0.04)
    for x in (3.9, WINCH[0]):
        h.stud(x, 4.1, 2.4, P.WHITE)
    for za, zb in ((1.45, 1.62), (3.18, 3.35)):                           # drum cheeks and the collar tying them
        h.box((WINCH[0] - 0.5, 1.6, za), (WINCH[0] + 0.5, 3.2, zb), P.METAL, bev=0.05)
    h.tube((WINCH[0], 2.3, 1.65), (WINCH[0], 2.3, 3.15), 0.62, P.DARK, n=14)
    for za, zb in ((1.62, 1.76), (3.04, 3.18)):
        h.tube((WINCH[0], 2.3, za), (WINCH[0], 2.3, zb), 0.8, P.WHITE, n=14)
    # r5: no modelled cable (VehicleService draws it from ATT_WinchPoint); the hook block and ring hang stowed
    h.box((WINCH[0] - 0.55, HOOK[1] + RING_R + 0.1, HOOK[2] - 0.5), (WINCH[0] + 0.55, HOOK[1] + RING_R + 0.75, HOOK[2] + 0.5), P.DARK,
          bev=0.12)                                                        # hook block, right under the drum
    h.torus_z(HOOK[0], HOOK[1], HOOK[2], RING_R, RING_T, P.YELLOW)


def body_gear(h):
    body(h)
    gear(h)


def main_rotor(h):
    """Symmetric about the hub (0, ROTOR_Y, 0) in x, y and z: the MeshPart's bbox centre is the pivot (y +-1.85:
    the collar reaches down into the engine deck as far as the studded 2x2 hub tower reaches up)."""
    Y, H = ROTOR_Y, 1.85
    h.vcyl(0, 0, Y - H, Y - 0.5, 0.95, P.DARK, n=16)                      # mast collar
    h.box((-1.0, Y - 0.7, -1.0), (1.0, Y + 0.35, 1.0), P.METAL, bev=0.12)  # r5: 2x2 hub block (was 3x3)
    h.box((-1.02, Y + 0.3, -1.02), (1.02, Y + 0.65, 1.02), P.ORANGE, bev=0.08)
    h.box((-0.5, Y + 0.6, -0.5), (0.5, Y + 1.3, 0.5), P.WHITE, bev=0.08)   # 1x1 hub tower, red studded cap
    top = H - STUD_H if h.lod < 2 else H                                  # LOD2 has no studs: keep the bbox centred
    h.box((-0.52, Y + 1.25, -0.52), (0.52, Y + top, 0.52), P.RED, bev=0.06)
    h.studs(-0.5, 0.5, -0.5, 0.5, Y + top, P.RED)
    for ax in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        def span(r0, r1, c0, c1, y0, y1, c, bev):
            """Box from radius r0..r1, chord c0..c1 (across the blade), height Y+y0..Y+y1."""
            if ax[0]:
                lo, hi = (ax[0] * r0, Y + y0, c0), (ax[0] * r1, Y + y1, c1)
            else:
                lo, hi = (c0, Y + y0, ax[1] * r0), (c1, Y + y1, ax[1] * r1)
            h.box(tuple(map(min, lo, hi)), tuple(map(max, lo, hi)), c, bev=bev)
            return tuple(map(min, lo, hi)), tuple(map(max, lo, hi))
        span(0.95, 3.3, -0.9, 0.9, -0.55, 0.5, P.METAL, 0.12)             # root grip (from the 2x2 hub)
        # full-brick blade: white plate on a charcoal under-plate, charcoal edge strips both sides (r7: 25% narrower);
        # r8: the plate laid as 2-stud tiles (chamfered, overlapping 0.02: a V seam every 2 studs), tips 25% shorter
        # and lower; plates and strips end 0.05 inside the tip
        tip = ROTOR_R - 1.5
        end = tip + 0.05
        cuts = [3.0] + [end - 2.0 * i for i in (4, 3, 2, 1)] + [end] if h.lod < 2 else [3.0, end]
        for i, (r0, r1) in enumerate(zip(cuts, cuts[1:])):
            span(r0 - (0.01 if i else 0), r1 + (0.01 if r1 < end else 0), -1.8, 1.8, -0.1, 0.6, P.WHITE, 0.12)
        span(3.05, end, -1.78, 1.78, -0.6, -0.07, P.DARK, 0.1)
        for e in (-1, 1):
            span(3.1, end, *sorted((e * 1.74, e * 2.03)), -0.64, 0.64, P.DARK, 0.1)   # 3.1: off the plate's end
        lo, hi = span(tip, ROTOR_R, -2.2, 2.2, -0.52, 0.66, P.ORANGE, 0.14)   # 1.5 x 4 orange tip brick
        if ax[0]:      # one row of 4 studs across the tip's middle
            h.studs(lo[0] + 0.25, hi[0] - 0.25, -2.0, 2.0, Y + 0.66, P.WHITE)
        else:
            h.studs(-2.0, 2.0, lo[2] + 0.25, hi[2] - 0.25, Y + 0.66, P.WHITE)
    # rest pose at 45 deg (an X): no blade lies along the boom over the cabin in the chase view; 4-fold symmetric, so
    # the bbox centre stays on the hub
    k = math.sqrt(0.5)
    h.b.v = [(x * k - y * k, x * k + y * k, z) for x, y, z in h.b.v]


def tail_rotor(h):
    """Symmetric about TAIL_HUB: two blades in the y-z plane at the hub's x, spinning about X. Rest pose fore-aft so
    the chase cam sees a hub, not a second vertical column next to the fin."""
    x, y, z = TAIL_HUB
    h.xcyl(x, y, z, 0.85, 0.9, P.ORANGE, n=16)
    h.xcyl(x, y, z, 0.45, 1.5, P.WHITE, n=12)                           # white boss both sides
    for s in (-1, 1):
        lo, hi = sorted((z + s * 0.6, z + s * (TAIL_R - 1.6)))
        h.box((x - 0.32, y - 0.7, lo), (x + 0.32, y + 0.7, hi), P.WHITE, bev=0.08)
        lo, hi = sorted((z + s * (TAIL_R - 1.8), z + s * TAIL_R))
        h.box((x - 0.38, y - 0.8, lo), (x + 0.38, y + 0.8, hi), P.ORANGE, bev=0.1)


def patch_lod(prebuilt):
    """The lod step takes our hand-made LOD1 / LOD2 (no studs, fewer sides, flat window plates) instead of decimating:
    a 10% collapse of a ~200-tri rotor fails and turns the body into mush. Validate still checks the class ceilings."""
    import bpy
    import versions
    orig = getattr(versions, "_orig_decimate", versions.decimate)
    versions._orig_decimate = orig

    def decimate(obj, target, symmetry=None):
        m = prebuilt.pop(obj.name, None)
        if m is None:
            return orig(obj, target, symmetry)
        old = obj.data
        obj.data = m
        bpy.data.meshes.remove(old)
        m.name = obj.name
    versions.decimate = decimate


ATTS = {
    "ATT_MainRotor": (0, ROTOR_Y, 0), "ATT_TailRotor": TAIL_HUB,
    "ATT_DriverSeat": (1.4, -1.4, -2.6), "ATT_PassengerSeat1": (-1.4, -1.4, -2.6), "ATT_EyePoint": (1.4, 1.2, -2.6),
    "ATT_WinchPoint": WINCH, "ATT_WinchHook": HOOK,
    "ATT_SurvivorSlot1": (-1.4, -1.4, 2.4), "ATT_SurvivorSlot2": (1.4, -1.4, 2.4),
    "ATT_PetSeat": (0, -1.9, 4.5), "ATT_Camera": (0, 2, 4),
}


def glass_material():
    """The windscreen's own material: the Glass set's RGBA ALB, alpha into the BSDF (stills match the in-game tint)."""
    import bpy
    mat = lego.material("MI_RescueHeli_Glass", ALB.replace("_Lego_", "_Glass_"))
    nt = mat.node_tree
    tex = next(n for n in nt.nodes if n.type == "TEX_IMAGE")
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.5     # r8: no sun hotspot on the flat screen (in-game RGH is 0.8);
    # set every build: lego.material reuses a saved material
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(mat, attr, val)
        except (AttributeError, TypeError):
            pass
    return mat


def build():
    import bpy  # noqa: F401  (Blender only)
    mats = {SET: lego.material("MI_RescueHeli_Lego", ALB), "Glass": glass_material()}
    meshes, lods = [], {}
    # Paint = the orange shell on its own MeshPart: LiveryPaint repaints it (primary), the rest keeps its colours;
    # r7: Glass = the windscreen on its own MeshPart and set (RGBA ALB, AlphaMode Transparency) so the cockpit shows
    # r8: Gear = skids + winch on their own MeshPart (Body was at 9,776 of the 10k per-MeshPart limit)
    parts = (("Body", body, {P.ORANGE, P.CGLASS}, False, SET), ("Paint", body_gear, {P.ORANGE}, True, SET),
             ("Glass", body, {P.CGLASS}, True, "Glass"), ("Gear", gear, {P.ORANGE}, False, SET),
             ("MainRotor", main_rotor, None, None, SET), ("TailRotor", tail_rotor, None, None, SET))
    for part, fn, cells, keep, st in parts:
        mat = mats[st]
        tris = []
        for lod in (0, 1, 2):
            b = lego.B()
            fn(R(b, lod))
            if cells is not None:
                b = b.pick(cells, keep=keep)
            tris.append(b.tris())
            nm = "%s_%s_LOD%d" % (NAME, part, lod)
            if lod:
                lods[nm] = b.to_mesh(nm + "_src", mat)
            else:
                obj = b.to_object(nm, mat)
        meshes.append({"object": obj, "set": st, "role": "visual", "lod": "LOD0"})
        print("[heli] %-10s %5d / %5d / %5d tris" % (part, *tris))
    patch_lod(lods)
    c = lego.B()
    R(c).box((-3.5, -3.0, -6.5), (3.5, 3.0, 6.5), P.DARK, bev=0)
    meshes.append({"object": c.to_object(NAME + "_COL", mats[SET]), "role": "col"})
    atts = [lego.attach(n, R.p(*p)) for n, p in ATTS.items()]

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    dims = tuple(round((max(p[i] for p in pts) - min(p[i] for p in pts)) / 3.0, 2) for i in range(3))
    return {
        "name": NAME, "budget": "helicopter", "tier": "standard",
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "Lego toy proportions on the Heli/Builder frame (HullRoot centre origin)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False},
                 {"name": SET_NAME, "set": "Glass", "size": 1024, "wet": False}],
        "waivers": {
            "texture sets": "Lego style: one flat palette atlas for every mesh (as M_Prop_BoardKit), not 5 PBR sets",
            "LOD UV layout": "flat palette cells: decimation merges cells by design (tiling=True skips density)",
        },
        "meshes": meshes,
        "attachments": atts,
    }
