"""M_Prop_SeaPlateKit: the Lego look of the two docs/27 sea plates (src/shared/DockPieces.luau seaPlate).

One FBX, one flat palette material (same cells as M_Prop_BoardKit / M_Prop_BuildSiteKit), every module its own mesh.
Two assembled plates, each authored in situ in its plate frame (Roblox axes: x right, y up, -z out to sea, origin = the
rect centre on the deck top, i.e. the code's C = isle(b, rect centre)). The Ramp Wharf sits at kit x 0, the Freight
Wharf at kit x 160; ATT_RampWharf / ATT_FreightWharf mark the two origins, so the wiring code places every MeshPart of a
plate with one CFrame (C * ATT_<Slot>:Inverse() * part). The code Parts stay as invisible colliders + the fallback.

  Ramp Wharf (SeaPlate1, leisure / slipway)
    L01_RampShafts      round shafts seabed -> just under the water (BuildY 1)
    L02_RampCourseLow   the light round-brick course through the waterline (BuildY 2)
    L03_RampCourseHigh  the dark round-brick course + cap plate under the deck (BuildY 3)
    L04_RampDeck        tan tile deck (dark-tan grout, studded border plates), grey quay kerb with white/red bevel caps
                        + studs, corner posts, lifebuoy roundel and yellow slipway chevrons (inlays), gangway
    L05_RampProps       Lego bollards with rope coils + hanging lines, fenders, swim ladder, lamp posts, benches,
                        parasols, kayak rack, flags, lifebuoy posts
    L06_RampLamps       the two lamp heads (code makes them Neon)
    L07_JumpRamp        RingLayout.RAMP exactly (14 x 32, toe 2 under water, lip 6 over it, yaw 30): flat running
                        surface tiled with yellow chevrons + a red/white kicker band, red rails below the slope edges
  Freight Wharf (SeaPlate2, cargo)
    L08_FreightShafts / L09_FreightCourseLow / L10_FreightCourseHigh  (as L01-L03)
    L11_FreightDeck     two-tone grey deck, dark border band with yellow/black hatch plates, yellow hazard bay
                        round the crane, hatched loading bays, tan walkways, thick dark kerb with yellow/black caps
    L12_FreightProps    chunky bollards with ropes, tyre + bar fenders on the barge face, containers, crates on
                        pallets, lamp posts
    L13_FreightLamps    lamp heads
    L14_CargoCrane      yellow 3 x 3 brick tower crane, cab, counterweight, Technic boom over the barge berth, hook
  Col01_COL             a token box (the code's Parts are the colliders)

    python3 art/source/props/M_Prop_SeaPlateKit/maketex.py --out build/prod/M_Prop_SeaPlateKit/textures/M_Prop_SeaPlateKit
    (Blender GUI via MCP) exec drive.py: build, zfight fix, lod, validate, export, save
LODs are hand-made (patch_lod): LOD1 drops studs, ropes and small trim, LOD2 merges the deck to colour bands.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
import lego  # noqa: E402
import palette as P  # noqa: E402

NAME = "M_Prop_SeaPlateKit"
BUDGET = "hero_building"
TIER = "standard"
SET_NAME, SET = "SeaPlateKit", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_SeaPlateKit_Brick_ALB.png")

SINK = 0.04
SLOTS = {"RampWharf": 0.0, "FreightWharf": 160.0}     # plate origins along Roblox x in the kit file

# --- code geometry (DockPieces.seaPlate, RingLayout): every number below mirrors the code
W, D = 123.0, 96.0                 # RingLayout.SeaPlates rect (both plates)
HW, HD = W / 2, D / 2
SEA = -4.0                         # -RingLayout.PlateauY: the waterline in the plate frame
DECK_T = 1.0                       # RingLayout.SEA_PLATE_DECK
PYL_X, PYL_Z, PYL_R = (-HW + 8, 0.0, HW - 8), (-HD + 8, HD - 8), 2.2
BOLL = [(k * W / 5, -HD + 3) for k in (-2, -1, 0, 1, 2)]
LAMPS = [(s * (HW - 4), -HD + 4) for s in (-1, 1)]
LAMP_Y = 10.4                      # code bulb centre
GANG_X = {"RampWharf": HW - 30, "FreightWharf": -(HW - 30)}   # 30 in from the channel side (island r[2]-30 / r[1]+30)
GANG_Z0, GANG_Z1, GANG_TOP = HD - 3, HD + 9, 0.06              # 14 x 12 plank, centre fwd r[3]-3, 0.06 proud
TEAL = (-HW + 24, -HD + 5, 0.5)    # TealBrick centre x, z, yaw (rad)
RAMP_AT = (51.5, -84.0, 30.0)      # RingLayout.RAMP.at - plate centre: x, z, yaw deg
R_W, R_L, R_LIP, R_TOE = 14.0, 32.0, 6.0, 2.0
R_LOW, R_TOP = SEA - R_TOE, SEA + R_LIP                       # -6 .. +2 (code ramp wedge)
R_WET = 8.0                        # ramp frame z where the running surface meets the waterline (ramp_y = SEA)
BARGE = (10.0, SEA, -HD - 9.5, -90.0)                          # ATT_BargeMoor: x, y, z, yaw deg
CRANE = (12.0, -40.0)              # crane base centre (Freight)


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def patch_lod(prebuilt):
    """The lod step starts from our hand-made LOD1 / LOD2 meshes; versions.decimate only cuts if one is over target."""
    import bpy
    import versions
    orig = getattr(versions, "_orig_decimate", versions.decimate)
    versions._orig_decimate = orig

    def decimate(obj, target, symmetry=None):
        m = prebuilt.pop(obj.name, None)
        if m is not None:
            old = obj.data
            obj.data = m
            bpy.data.meshes.remove(old)
            m.name = obj.name
        orig(obj, target, symmetry)
    versions.decimate = decimate


STUD_SIDE = {P.WHITE: P.STONE, P.YELLOW: P.ORANGE, P.TAN: P.BROWN, P.RIB: P.BROWN, P.RED: P.BROWN, P.LBG: P.DBG,
             P.STONE: P.DBG, P.DBG: P.BLACK, P.BLUE: P.INK, P.ORANGE: P.BROWN}   # r4: two tones darker on the light tops


class K:
    """Roblox-axes authoring on a lego.B: a frame at (ox, oz) turned yaw (CFrame.Angles(0, yaw, 0)); Blender =
    (-x, z, y). lod 0/1/2."""

    def __init__(self, b, ox=0.0, oz=0.0, yaw=0.0, lod=0):
        self.b, self.ox, self.oz, self.lod = b, ox, oz, lod
        self.c, self.s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def sub(self, x, z, yaw):
        """A child frame at (x, z) of this one, turned yaw degrees more."""
        X, Z = self.xz(x, z)
        k = K(self.b, X, Z, 0.0, self.lod)
        k.c, k.s = math.cos(math.atan2(self.s, self.c) + math.radians(yaw)), math.sin(math.atan2(self.s, self.c) + math.radians(yaw))
        return k

    def xz(self, x, z):
        return x * self.c + z * self.s + self.ox, -x * self.s + z * self.c + self.oz

    def p(self, x, y, z):
        X, Z = self.xz(x, z)
        return (-X, Z, y)

    def n(self, x, y, z):
        return (-(x * self.c + z * self.s), -x * self.s + z * self.c, y)

    def sides(self, n):
        return (n, max(6, n - 2), max(6, n // 2))[self.lod]

    def box(self, lo, hi, c, bev=None, drop=()):
        """A brick: bottom full, top inset by the bevel. drop: 'bottom' / 'top' faces left out (hidden)."""
        x0, y0, z0 = (min(a, b) for a, b in zip(lo, hi))
        x1, y1, z1 = (max(a, b) for a, b in zip(lo, hi))
        b = lego.BEVEL if bev is None else bev
        b = min(b, 0.22 * min(x1 - x0, y1 - y0, z1 - z0))
        if self.lod == 2:
            b = 0.0
        if b <= 0:
            top = [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]
        else:
            top = [(x0 + b, y1, z0 + b), (x1 - b, y1, z0 + b), (x1 - b, y1, z1 - b), (x0 + b, y1, z1 - b)]
        bot = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]
        faces = {"bottom": (0, 1, 2, 3), "top": (4, 5, 6, 7), "a": (0, 1, 5, 4), "b": (1, 2, 6, 5),
                 "c": (2, 3, 7, 6), "d": (3, 0, 4, 7)}
        self.b._emit([self.p(*v) for v in bot + top], [f for k, f in faces.items() if k not in drop], c)

    def rbox(self, cx, cz, sx, sz, y0, y1, ang, c, bev=0.05):
        """A box sx x sz centred at (cx, cz) turned ang degrees (inlay tiles, chevron arms)."""
        self.sub(cx, cz, ang).box((-sx / 2, y0, -sz / 2), (sx / 2, y1, sz / 2), c, bev=bev, drop=("bottom",))

    def cyl(self, x, z, y0, y1, r, c, n=8, bottom=True, top=True):
        bx, by, _ = self.p(x, 0, z)
        self.b.cyl(bx, by, y0, y1, r, c, self.sides(n), top=top, bottom=bottom)

    def stud(self, x, y, z, c, r=0.7, h=0.45, n=8):
        """A tall stud with a bevelled top edge (r2: the anchor kits' studs read taller and catch a rim light)."""
        if self.lod:
            return
        n = n if r >= 0.65 else min(n, 6)                # small studs: 6 sides (budget), big deck studs keep 8
        bv = min(0.12, 0.3 * h, 0.25 * r)
        rings = [(y - SINK, r), (y + h - bv, r), (y + h, r - bv)]
        verts = [self.p(x + rr * math.cos(2 * math.pi * i / n), yy, z + rr * math.sin(2 * math.pi * i / n))
                 for yy, rr in rings for i in range(n)]
        faces = [(a * n + i, a * n + (i + 1) % n, (a + 1) * n + (i + 1) % n, (a + 1) * n + i)
                 for a in range(2) for i in range(n)]
        self.b._emit(verts, faces, STUD_SIDE.get(c, c))   # r3: a darker stud wall rings each stud (reads at distance)
        self.b._emit(verts[2 * n:], [tuple(range(n))], c)

    def slab(self, poly, t0, t1, c, yf):
        """A tile on a sloped surface: polygon (x, z), bottom yf(z) + t0, top yf(z) + t1, sides, no bottom."""
        m = len(poly)
        verts = [self.p(x, yf(z) + t0, z) for x, z in poly] + [self.p(x, yf(z) + t1, z) for x, z in poly]
        faces = [tuple(range(m, 2 * m))] + [(i, (i + 1) % m, m + (i + 1) % m, m + i) for i in range(m)]
        self.b._emit(verts, faces, c)

    def studs(self, x0, x1, z0, z1, y, c, pitch=2.0, r=0.7, h=0.45, n=8):
        nx, nz = max(1, round((x1 - x0) / pitch)), max(1, round((z1 - z0) / pitch))
        for i in range(nx):
            for j in range(nz):
                self.stud(x0 + (i + 0.5) * (x1 - x0) / nx, y, z0 + (j + 0.5) * (z1 - z0) / nz, c, r, h, n)

    def poly(self, pts, c, n):
        """One single-sided polygon (Roblox points), n = its outward normal (Roblox)."""
        self.b.want[len(self.b.f)] = self.n(*n)
        self.b._emit([self.p(*q) for q in pts], [tuple(range(len(pts)))], c)

    def beam(self, p0, p1, w, h, c):
        self.b.beam(self.p(*p0), self.p(*p1), w, h, c)

    def frustum(self, x, z, rings, c, n=10):
        n = self.sides(n)
        secs = [[self.p(x + r * math.cos(2 * math.pi * i / n), y, z + r * math.sin(2 * math.pi * i / n))
                 for i in range(n)] for y, r in rings]
        self.b.loft(secs, c)

    def tube(self, pts, r, c, n=6):
        """A rope: a closed tube through Roblox points."""
        from mathutils import Vector
        n = 4 if self.lod else n
        P3 = [Vector(self.p(*q)) for q in pts]
        secs = []
        for i, q in enumerate(P3):
            t = (P3[min(i + 1, len(P3) - 1)] - P3[max(i - 1, 0)]).normalized()
            up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            a = t.cross(up).normalized()
            b = a.cross(t).normalized()
            secs.append([tuple(q + r * (math.cos(2 * math.pi * j / n) * a + math.sin(2 * math.pi * j / n) * b))
                         for j in range(n)])
        self.b.loft(secs, c)

    def hring(self, cx, cz, y, R, r, c, maj=10, mnr=4):
        """A horizontal torus (rope coil round a bollard)."""
        maj = 6 if self.lod else 8
        verts = []
        for i in range(maj):
            u = 2 * math.pi * i / maj
            for j in range(mnr):
                v = 2 * math.pi * j / mnr
                rr = R + r * math.cos(v)
                verts.append(self.p(cx + rr * math.cos(u), y + r * math.sin(v), cz + rr * math.sin(u)))
        faces = [(i * mnr + j, ((i + 1) % maj) * mnr + j, ((i + 1) % maj) * mnr + (j + 1) % mnr, i * mnr + (j + 1) % mnr)
                 for i in range(maj) for j in range(mnr)]
        self.b._emit(verts, faces, c, smooth=True)

    def vring(self, cx, cy, cz, R, r, colours, seg=8, sub=2, mnr=6):
        """A ring round the Roblox z axis (lifebuoys, tyres): seg capped arcs cycling colours."""
        sub, mnr = ((sub, mnr), (1, 5), (1, 4))[self.lod]
        for k in range(seg):
            verts = []
            for i in range(sub + 1):
                u = 2 * math.pi * (k + i / sub) / seg
                for j in range(mnr):
                    v = 2 * math.pi * j / mnr
                    rr = R + r * math.cos(v)
                    verts.append(self.p(cx + rr * math.cos(u), cy + rr * math.sin(u), cz + r * math.sin(v)))
            faces = [(i * mnr + j, (i + 1) * mnr + j, (i + 1) * mnr + (j + 1) % mnr, i * mnr + (j + 1) % mnr)
                     for i in range(sub) for j in range(mnr)]
            faces += [tuple(reversed(range(mnr))), tuple(range(sub * mnr, (sub + 1) * mnr))]
            self.b._emit(verts, faces, colours[k % len(colours)], smooth=True)

    def annulus(self, cx, cz, R0, R1, y0, y1, seg, colours):
        """A flat ring of seg tiles (deck roundel inlay)."""
        for k in range(seg):
            a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
            pts = []
            for y in (y0, y1):
                for R, a in ((R0, a0), (R1, a0), (R1, a1), (R0, a1)):
                    pts.append(self.p(cx + R * math.cos(a), y, cz + R * math.sin(a)))
            faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
            self.b._emit(pts, faces, colours[k % len(colours)])


def round_stack(k, x, z, ys, r, colours, core=P.DBG):
    """Round 2 x 2 bricks between the breakpoints ys, a 0.08 groove between bricks over a dark core."""
    n = len(ys) - 1
    if k.lod == 2:
        k.cyl(x, z, ys[0], ys[-1], r, colours[0], 12, bottom=False)
        return
    for i in range(n):
        k.cyl(x, z, ys[i] + (0.08 if i else 0), ys[i + 1], r, colours[i % len(colours)], 12, bottom=False)
    if n > 1:
        k.cyl(x, z, ys[0] + 0.05, ys[-1] - 0.05, r - 0.18, core, 12, bottom=False, top=False)


# ------------------------------------------------------------------------------------------------ pylons
def shafts(k, slot):
    for x in PYL_X:
        for z in PYL_Z:
            k.cyl(x, z, SEA - 40, SEA - 1, PYL_R - 0.1, P.LBG, 12, bottom=False)       # r4: lighter, reads grey under water
    if slot == "RampWharf":                          # the ramp's two piers under its tall end (at frame)
        r = ramp_frame(k)
        for x in (-4.0, 4.0):
            r.cyl(x, -11.0, SEA - 40, SEA - 1.56, 1.6, P.LBG, 12, bottom=False)       # r4: up under the lip face


def course_low(k, slot):
    for x in PYL_X:
        for z in PYL_Z:
            round_stack(k, x, z, [SEA - 1, SEA + 0.35, SEA + 1], PYL_R, [P.STONE, P.LBG])     # r4: band moved up
            if k.lod < 2:
                k.cyl(x, z, SEA + 0.98, SEA + 1.36, PYL_R + 0.45, P.WHITE, 14 if k.lod == 0 else 10)   # r2: 2 x 2 plate collar
            # r4: the collar's tiny stud ring is gone (unreadable at the waterline; budget for the -x bays)


def course_high(k, slot):
    for x in PYL_X:
        for z in PYL_Z:
            round_stack(k, x, z, [SEA + 1.08, -2.5, -2.0, -1.5], PYL_R, [P.STONE, P.YELLOW, P.BLACK])   # r4: band under the deck
            k.box((x - 2.7, -1.5, z - 2.7), (x + 2.7, -1.06, z + 2.7), P.DBG, bev=0.12)     # cap plate, 0.06 under


# ------------------------------------------------------------------------------------------------ deck
KERB = {"RampWharf": dict(w=1.8, ov=0.4, y0=-2.6, base=(P.STONE, P.LBG), caps=(P.WHITE, P.RED), seg=8.0),
        "FreightWharf": dict(w=2.6, ov=0.7, y0=-3.0, base=(P.DBG, P.STONE), caps=(P.YELLOW, P.BLACK), seg=6.0)}
CAP0, CAP1 = 0.7, 1.3                  # r2: a 0.6 thick bevelled cap (was 0.4)


def kerb_run(k, a0, a1, along_x, fixed, kb):
    """Quay wall: two brick courses in running bond over a dark back plate (the seams read), a bevelled cap plate,
    studs on every other cap; from a0 to a1 along x (or z) at the kerb band fixed."""
    L = a1 - a0
    n = max(1, round(L / kb["seg"]))
    s = L / n
    f0, f1 = fixed
    caps = kb["caps"]
    y0, ym = kb["y0"], (kb["y0"] + CAP0) / 2

    def B(lo, hi, c, bev, drop=()):
        if along_x:
            k.box((lo[0], lo[1], lo[2]), (hi[0], hi[1], hi[2]), c, bev, drop)
        else:
            k.box((lo[2], lo[1], lo[0]), (hi[2], hi[1], hi[0]), c, bev, drop)
    if k.lod == 2:
        B((a0, y0, f0), (a1, CAP1, f1), kb["base"][0], 0)
        return
    if k.lod == 1:
        B((a0, y0, f0 + 0.04), (a1, CAP0 + 0.06, f1 - 0.04), kb["base"][0], 0)
        for i in range(n):
            B((a0 + i * s + 0.05, CAP0, f0), (a0 + (i + 1) * s - 0.05, CAP1, f1), caps[i % 2], 0.25, ("bottom",))
        return
    B((a0, y0 + 0.1, f0 + 0.15), (a1, CAP0, f1 - 0.15), P.DBG if kb["base"][0] != P.DBG else P.BLACK, 0)
    for row, (b0, b1, off) in enumerate(((y0, ym, s / 2), (ym + 0.06, CAP0 + 0.06, 0.0))):
        cuts = sorted({a0, a1} | {a0 + off + i * s for i in range(-1, n + 1) if a0 < a0 + off + i * s < a1})
        for u0, u1 in zip(cuts, cuts[1:]):
            B((u0 + 0.05, b0, f0 + 0.04), (u1 - 0.05, b1, f1 - 0.04), kb["base"][row], 0.08, ("bottom",))
    for i in range(n):
        u0, u1 = a0 + i * s + 0.05, a0 + (i + 1) * s - 0.05
        B((u0, CAP0, f0), (u1, CAP1, f1), caps[i % 2], 0.25, ("bottom",))
        if i % 2:
            continue                                     # smooth bevel tiles between studded caps
        mid = (f0 + f1) / 2
        m = max(1, round((u1 - u0) / 4.0))
        for j in range(m):
            u = u0 + (j + 0.5) * (u1 - u0) / m
            if along_x:
                k.stud(u, CAP1, mid, caps[0], r=0.55)
            else:
                k.stud(mid, CAP1, u, caps[0], r=0.55)


def kerbs(k, slot):
    kb = KERB[slot]
    ox = HW + kb["ov"]                  # outer face of the side kerbs
    ix = ox - kb["w"]                   # inner face
    oz = -(HD + kb["ov"])
    iz = oz + kb["w"]
    cw = kb["w"] + 0.3                  # corner post
    kerb_run(k, -ix + 0.3, ix - 0.3, True, (oz, iz), kb)                      # the outer (sea) edge
    for s in (-1, 1):
        f = (ix, ox) if s > 0 else (-ox, -ix)
        kerb_run(k, iz + 0.3, HD, False, f, kb)                                  # the two sides
        # corner post: a taller studded 2 x 2 brick on the corner
        cx, cz = s * (ox - kb["w"] / 2), oz + kb["w"] / 2
        k.box((cx - cw / 2, kb["y0"] - 0.2, cz - cw / 2), (cx + cw / 2, 2.0, cz + cw / 2), kb["caps"][1], bev=0.25)
        k.studs(cx - cw / 2, cx + cw / 2, cz - cw / 2, cz + cw / 2, 2.0, kb["caps"][1], pitch=cw / 2, r=0.42)
    return ix, iz


def deck_grid(k, slot, ix, iz, tile):
    """8 x 8 tile plates (0.12 grout over the core slab). tile(i, j, nx, nz, cx, cz) -> (palette cell, studded)."""
    x0, x1, z0, z1 = -ix, ix, iz, HD
    nx, nz = round((x1 - x0) / 8), round((z1 - z0) / 8)
    dx, dz = (x1 - x0) / nx, (z1 - z0) / nz
    g = 0.06
    if k.lod == 2:                                   # far: one slab top, colour bands come from the inlays
        k.box((x0, -0.6, z0), (x1, 0.0, z1), tile(1, 1, nx, nz, 0.0, 0.0)[0], bev=0, drop=("bottom",))
        return
    for i in range(nx):
        for j in range(nz):
            a0, a1, b0, b1 = x0 + i * dx + g, x0 + (i + 1) * dx - g, z0 + j * dz + g, z0 + (j + 1) * dz - g
            c, studded = tile(i, j, nx, nz, (a0 + a1) / 2, (b0 + b1) / 2)
            if k.lod == 1:                               # mid distance: tops only, the core shows in the grout
                k.poly([(a0, 0.0, b0), (a1, 0.0, b0), (a1, 0.0, b1), (a0, 0.0, b1)], c, (0.0, 1.0, 0.0))
                continue
            k.box((a0, -0.6, b0), (a1, 0.0, b1), c, bev=0.08, drop=("bottom",))
            if studded:                                  # r2: a 2 x 2 stud plate, tall bevelled studs
                k.studs(a0, a1, b0, b1, 0.0, c, pitch=(a1 - a0) / 2, r=1.0, h=0.55)


def core(k, slot):
    c = P.DTAN if slot == "RampWharf" else P.BLACK      # r3: darker freight seams
    k.box((-HW, -DECK_T, -HD), (HW, -0.5, HD), c, bev=0)


def gangway(k, slot):
    gx = GANG_X[slot]
    n = 6
    dz = (GANG_Z1 - GANG_Z0) / n
    if k.lod == 2:
        k.box((gx - 7, GANG_TOP - 0.5, GANG_Z0), (gx + 7, GANG_TOP, GANG_Z1), P.BROWN, bev=0)
        return
    for i in range(n):
        z0, z1 = GANG_Z0 + i * dz + 0.05, GANG_Z0 + (i + 1) * dz - 0.05
        k.box((gx - 6.4, GANG_TOP - 0.5, z0), (gx + 6.4, GANG_TOP, z1), P.BROWN if i % 2 else P.RIB, bev=0.08,
              drop=("bottom",))
    for s in (-1, 1):                                # studded edge plates along both sides
        k.box((gx + s * 6.45, GANG_TOP - 0.5, GANG_Z0), (gx + s * 7.25, GANG_TOP + 0.3, GANG_Z1), P.DBG, bev=0.08,
              drop=("bottom",))
        for j in range(0, n, 2):
            k.stud(gx + s * 6.85, GANG_TOP + 0.3, GANG_Z0 + (j + 1.0) * dz, P.DBG, r=0.32, h=0.25)


def chevron(k, x, z, size, c, y1=0.08, ang=0.0):
    """A V pointing -z (turned ang) made of two raised tiles."""
    f = k.sub(x, z, ang)
    arm, w = size, size * 0.32
    for s in (-1, 1):
        f.rbox(s * arm * 0.33, arm * 0.33, arm, w, -0.2, y1, -s * 45.0, c, bev=0.04)


PAD = (5, 6, 6, 7)                    # splash pad tiles i0, i1, j0, j1 (Ramp Wharf)


def ramp_deck(k):
    """Bright tan field; an orange-tan promenade along the sea face and path from the gangway, a blue slipway lane
    with yellow chevrons to the ramp corner, white 2 x 2 stud plates along the edges, a blue splash pad."""
    ix, iz = kerbs(k, "RampWharf")
    core(k, "RampWharf")

    def tile(i, j, nx, nz, cx, cz):
        if PAD[0] <= i <= PAD[1] and PAD[2] <= j <= PAD[3]:
            return (P.BLUE if (i + j) % 2 else P.GLASS), False
        if j == 0:
            return (P.WHITE, True) if i % 3 == 1 else (P.BROWN, False)
        if i == nx - 2:
            return P.BLUE, False                         # slipway lane, chevrons on it
        if abs(cx - GANG_X["RampWharf"]) < 4.5:
            return P.BROWN, False                        # r3: reddish-brown boardwalk promenade + path
        if i in (0, nx - 1) and j % 4 == 1:
            return P.WHITE, True
        return (P.TAN if j % 2 else P.RIB), False        # r3: alternating plank tones
    deck_grid(k, "RampWharf", ix, iz, tile)
    nx, nz = round(2 * ix / 8), round((HD - iz) / 8)
    dx, dz = 2 * ix / nx, (HD - iz) / nz
    lane = -ix + (nx - 1.5) * dx
    for z in (28.0, 16.0, 4.0, -8.0, -20.0, -32.0):     # yellow chevrons down the lane toward the ramp corner
        chevron(k, lane, z, 4.6, P.YELLOW)
    if k.lod < 2:
        gx = GANG_X["RampWharf"]                         # raised white edging along the gangway path
        for s in (-1, 1):
            xe = gx + s * 4.0 + 0.5
            for j in range(1, nz):
                k.box((xe - 0.3, -0.2, iz + j * dz + 0.08), (xe + 0.3, 0.25, iz + (j + 1) * dz - 0.08), P.WHITE,
                      bev=0.06, drop=("bottom",))
        # splash pad: a white rim and three water jets
        x0, x1 = -ix + PAD[0] * dx, -ix + (PAD[1] + 1) * dx
        z0, z1 = iz + PAD[2] * dz, iz + (PAD[3] + 1) * dz
        for lo, hi in (((x0, z0), (x1, z0 + 0.8)), ((x0, z1 - 0.8), (x1, z1)), ((x0, z0 + 0.8), (x0 + 0.8, z1 - 0.8)),
                       ((x1 - 0.8, z0 + 0.8), (x1, z1 - 0.8))):
            k.box((lo[0], -0.2, lo[1]), (hi[0], 0.35, hi[1]), P.WHITE, bev=0.1, drop=("bottom",))
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        for jx, jz, hgt in ((cx - 4, cz - 3, 3.6), (cx + 4, cz - 3, 2.6), (cx, cz + 4, 4.4)):
            k.cyl(jx, jz, -0.1, 0.45, 0.8, P.WHITE, 10)
            k.frustum(jx, jz, [(0.4, 0.28), (hgt - 0.6, 0.2), (hgt - 0.2, 0.75), (hgt, 0.55)], P.GLASS, n=8)
    gangway(k, "RampWharf")


def hatch_bay(k, x0, x1, z0, z1, t=0.8):
    """r3: a yellow loading-bay frame with black 45-degree tiles inside both z ends (replaces the white bay lines)."""
    for lo, hi in (((x0, z0), (x1, z0 + t)), ((x0, z1 - t), (x1, z1)), ((x0, z0 + t), (x0 + t, z1 - t)),
                   ((x1 - t, z0 + t), (x1, z1 - t))):
        k.box((lo[0], -0.2, lo[1]), (hi[0], 0.08, hi[1]), P.YELLOW, bev=0.03, drop=("bottom",))
    if k.lod:
        return
    n = max(2, int((x1 - x0 - 2 * t) / 3.0))
    for q in range(n):
        x = x0 + t + (q + 0.5) * (x1 - x0 - 2 * t) / n
        for z in (z0 + t + 1.0, z1 - t - 1.0):
            k.rbox(x, z, 2.2, 0.7, -0.2, 0.08, 45.0, P.BLACK, bev=0.03)


F_BAYS = ((-58.4, -43.0, -38.0, -18.0), (-58.4, -40.0, 18.0, 42.0), (38.0, 58.4, 20.0, 42.0))
F_CROSS = 6                           # r3: tile row of the cross walkway (z ~ 4.9), gangway walkway -> the +x side


def freight_deck(k):
    """Two-tone stone grey field in 2 x 2 tile blocks over dark seams, a dark border band, yellow / black hatch plates
    on the band, a tan walkway with yellow edge lines from the gangway to the barge face and a tan cross walkway,
    yellow hazard bay round the crane, yellow / black hatched loading bays."""
    ix, iz = kerbs(k, "FreightWharf")
    core(k, "FreightWharf")
    gx = GANG_X["FreightWharf"]
    hatch = []

    def tile(i, j, nx, nz, cx, cz):
        if abs(cx - gx) < 4.5 or (j == F_CROSS and cx > gx):
            return P.TAN, False
        if (i in (0, nx - 1) and j % 4 == 1) or (j == nz - 1 and i % 4 == 1 and abs(cx - gx) > 8):
            hatch.append((cx, cz))
            return None, False
        if i in (0, nx - 1) or j in (0, nz - 1):
            return P.DBG, False
        return (P.STONE if (i // 2 + j // 2) % 2 else P.LBG), False
    deck_grid(k, "FreightWharf", ix, iz, lambda *a: (lambda c: (P.YELLOW, False) if c[0] is None else c)(tile(*a)))
    nx, nz = round(2 * ix / 8), round((HD - iz) / 8)
    dx, dz = 2 * ix / nx, (HD - iz) / nz
    if k.lod < 2:                                      # the hatch tiles get their black stripes (deck_grid laid yellow)
        for cx, cz in hatch:
            for d in (-2.6, 0.0, 2.6) if k.lod == 0 else (0.0,):
                hh = min(dx, dz) / 2 - 0.06
                k.rbox(cx + d * 0.7071, cz - d * 0.7071, 2 * (hh * 1.4142 - abs(d)) - 1.8, 1.0, -0.2, 0.05, 45.0,
                       P.BLACK, bev=0.03)
    cz0, cz1 = iz + F_CROSS * dz, iz + (F_CROSS + 1) * dz
    if k.lod == 2:
        k.box((gx - 4, -0.2, iz), (gx + 4, 0.08, HD), P.TAN, bev=0, drop=("bottom",))
        k.box((gx + 4, -0.2, cz0 + 0.5), (ix, 0.08, cz1 - 0.5), P.TAN, bev=0, drop=("bottom",))
    else:
        for s in (-1, 1):
            k.box((gx + s * 4.6 - 0.3, -0.2, iz + 0.5), (gx + s * 4.6 + 0.3, 0.08, HD - 0.5), P.YELLOW, bev=0.03,
                  drop=("bottom",))
        for zz in (cz0 + 0.6, cz1 - 0.6):              # r3: the second walkway's yellow lines
            k.box((gx + 5.2, -0.2, zz - 0.3), (ix - 0.5, 0.08, zz + 0.3), P.YELLOW, bev=0.03, drop=("bottom",))
    # yellow hazard frame round the crane / loading bay along the barge face
    bx0, bx1, bz0, bz1 = -4.0, 36.0, iz + 1.0, -26.0
    t = 0.9
    for lo, hi in (((bx0, bz0), (bx1, bz0 + t)), ((bx0, bz1 - t), (bx1, bz1)),
                   ((bx0, bz0 + t), (bx0 + t, bz1 - t)), ((bx1 - t, bz0 + t), (bx1, bz1 - t))):
        k.box((lo[0], -0.2, lo[1]), (hi[0], 0.08, hi[1]), P.YELLOW, bev=0.04, drop=("bottom",))
    if k.lod < 2:                                      # black diagonal hazard tiles inside the frame's sea edge
        for x in range(int(bx0) + 3, int(bx1) - 1, 4):
            k.rbox(x, bz0 + t + 1.0, 2.2, 0.7, -0.2, 0.08, 45.0, P.BLACK, bev=0.03)
    for b in F_BAYS:                                   # r3: hatched loading bays (were white outlines)
        hatch_bay(k, *b)
    gangway(k, "FreightWharf")


# ------------------------------------------------------------------------------------------------ props
def bollard(k, x, z, s=1.0, rope=True, c=P.DBG, rope_c=P.TAN, kb=None):
    """A Lego mooring bollard: round base brick, neck, mushroom cap, stud; a rope coil + a line over the kerb."""
    if k.lod == 2:
        k.box((x - 0.9 * s, 0, z - 0.9 * s), (x + 0.9 * s, 2.2 * s, z + 0.9 * s), c, bev=0)
        return
    k.box((x - 1.25 * s, -0.1, z - 1.25 * s), (x + 1.25 * s, 0.35 * s, z + 1.25 * s), c, bev=0.12)   # 2 x 2 base plate
    k.cyl(x, z, 0.3 * s, 1.3 * s, 0.95 * s, c, 12, bottom=False)
    k.cyl(x, z, 1.25 * s, 1.85 * s, 0.62 * s, c, 10, bottom=False, top=False)
    k.frustum(x, z, [(1.8 * s, 0.7 * s), (2.0 * s, 1.15 * s), (2.35 * s, 1.15 * s), (2.5 * s, 0.9 * s)], c, n=12)
    k.stud(x, 2.48 * s, z, c, r=0.45 * s, h=0.25 * s, n=10)
    if rope and k.lod == 0:
        k.hring(x, z, 1.55 * s, 0.7 * s, 0.17 * s, rope_c)
        k.hring(x, z, 1.25 * s, 1.0 * s, 0.17 * s, rope_c)
    if rope and kb and k.lod == 0:                                  # a line from the neck over the kerb cap, down the sea face
        oz = -(HD + kb["ov"])
        ztop = oz + kb["w"] / 2
        pts = [(x, 1.5 * s, z - 0.65 * s), (x + 0.2, 1.45, z - 1.6), (x + 0.3, 1.68, ztop + 0.3),
               (x + 0.35, 1.6, oz - 0.25), (x + 0.4, 0.2, oz - 0.45), (x + 0.5, -1.6, oz - 0.55),
               (x + 0.8, -2.8, oz - 0.6)]
        k.tube(pts, 0.17 * s, rope_c)


def lamp_post(k, x, z):
    if k.lod == 2:
        k.box((x - 0.4, -0.1, z - 0.4), (x + 0.4, LAMP_Y - 0.66, z + 0.4), P.DBG, bev=0)
        k.box((x - 1.0, LAMP_Y + 0.66, z - 1.0), (x + 1.0, LAMP_Y + 1.0, z + 1.0), P.DBG, bev=0)
        return
    k.box((x - 1.25, -0.1, z - 1.25), (x + 1.25, 0.5, z + 1.25), P.DBG, bev=0.12)
    round_stack(k, x, z, [0.45, 1.6], 0.9, [P.DBG])
    k.cyl(x, z, 1.55, LAMP_Y - 1.0, 0.38, P.DBG, 10, bottom=False)
    for y in (3.5, 6.5) if k.lod < 2 else ():
        k.cyl(x, z, y, y + 0.35, 0.55, P.DBG, 10)                                 # 1 x 1 round plate collars
    k.box((x - 0.95, LAMP_Y - 1.05, z - 0.95), (x + 0.95, LAMP_Y - 0.7, z + 0.95), P.DBG, bev=0.08)
    for sx in (-1, 1) if k.lod == 0 else ():                                       # lantern corner bars
        for sz in (-1, 1):
            k.box((x + sx * 0.8 - 0.1, LAMP_Y - 0.72, z + sz * 0.8 - 0.1), (x + sx * 0.8 + 0.1, LAMP_Y + 0.72,
                                                                             z + sz * 0.8 + 0.1), P.DBG, bev=0.02)
    k.box((x - 1.05, LAMP_Y + 0.7, z - 1.05), (x + 1.05, LAMP_Y + 1.05, z + 1.05), P.DBG, bev=0.1)
    k.frustum(x, z, [(LAMP_Y + 1.03, 0.9), (LAMP_Y + 1.6, 0.25)], P.DBG, n=8)


def lamp_head(k, x, z):
    k.box((x - 0.66, LAMP_Y - 0.66, z - 0.66), (x + 0.66, LAMP_Y + 0.66, z + 0.66), P.YELLOW, bev=0.1)


def fender_bar(k, x, kb, y0=-3.4, y1=0.5, r=0.42):
    if k.lod == 2:
        return
    oz = -(HD + kb["ov"]) - r - 0.05
    if k.lod:
        k.cyl(x, oz, y0, y1, r, P.STONE, 8)
        return
    ys = [y0, -1.75, -1.25, -0.8, y1]                  # r4: a stone piling with a yellow / black band under the deck
    for q, c in enumerate((P.STONE, P.YELLOW, P.BLACK, P.STONE)):
        k.cyl(x, oz, ys[q] + (0.05 if q else 0.0), ys[q + 1], r, c, 6, bottom=q == 0)


def tyre(k, x, kb, y=-1.6):
    if k.lod == 2:
        return
    oz = -(HD + kb["ov"])
    k.vring(x, y, oz - 0.55, 1.15, 0.5, [P.BLACK], seg=4 if k.lod == 0 else 8, sub=2, mnr=6)


def ladder(k, x, kb):
    if k.lod == 2:
        return
    oz = -(HD + kb["ov"]) - 0.35
    for s in (-1, 1):
        k.box((x + s * 1.2 - 0.18, SEA - 1.5, oz - 0.18), (x + s * 1.2 + 0.18, 2.6, oz + 0.18), P.YELLOW, bev=0.04)
        k.frustum(x + s * 1.2, oz, [(2.55, 0.25), (2.9, 0.25)], P.YELLOW, n=8)
    for y in [SEA - 1 + i * 1.0 for i in range(7)] if k.lod < 2 else ():
        k.box((x - 1.05, y, oz - 0.12), (x + 1.05, y + 0.22, oz + 0.12), P.YELLOW, bev=0.03)


def bench(k, x, z):
    if k.lod == 2:
        return
    for s in (-1, 1):
        k.box((x + s * 1.6 - 0.4, -0.1, z - 0.7), (x + s * 1.6 + 0.4, 1.1, z + 0.7), P.DBG, bev=0.08)
    k.box((x - 2.4, 1.1, z - 0.9), (x + 2.4, 1.45, z + 0.9), P.BROWN, bev=0.1)
    k.box((x - 2.4, 1.45, z + 0.55), (x + 2.4, 2.9, z + 0.9), P.BROWN, bev=0.08)
    k.studs(x - 2.3, x + 2.3, z - 0.8, z + 0.4, 1.45, P.BROWN, pitch=1.2, r=0.28, h=0.18, n=6)


def parasol(k, x, z, c=P.RED):
    if k.lod == 2:
        k.frustum(x, z, [(4.6, 3.3), (6.0, 0.3)], c, n=12)
        return
    k.cyl(x, z, -0.1, 0.25, 1.3, P.DBG, 12)                                       # round base plate
    k.cyl(x, z, 0.2, 5.2, 0.16, P.WHITE, 8, bottom=False)
    k.frustum(x, z, [(4.6, 3.3), (5.0, 3.3), (5.05, 2.8)], P.WHITE, n=12)           # white valance
    k.frustum(x, z, [(5.02, 2.8), (5.6, 1.6), (6.0, 0.3)], c, n=12)
    k.stud(x, 5.98, z, P.WHITE, r=0.3, h=0.3)
    if k.lod:
        return
    # a round table and two stools under it
    k.cyl(x + 2.0, z + 0.3, -0.1, 1.5, 0.2, P.DBG, 6, bottom=False)
    k.cyl(x + 2.0, z + 0.3, 1.5, 1.8, 1.1, P.WHITE, 12)


def kayak(k, x0, x1, y, z, c):
    """A kayak along x (lofted ellipse stations) with a dark cockpit."""
    if k.lod == 2:
        return
    n = k.sides(8)
    st = [(0.0, 0.05, 0.05), (0.15, 0.55, 0.32), (0.5, 0.8, 0.42), (0.85, 0.55, 0.32), (1.0, 0.05, 0.05)]
    secs = []
    for t, w, h in st:
        x = x0 + (x1 - x0) * t
        secs.append([k.p(x, y + h * math.sin(2 * math.pi * i / n), z + w * math.cos(2 * math.pi * i / n)) for i in range(n)])
    k.b.loft(secs, c)
    xm = (x0 + x1) / 2
    k.box((xm - 0.8, y + 0.3, z - 0.42), (xm + 0.8, y + 0.48, z + 0.42), P.INK, bev=0.08)


def kayak_rack(k, x, z0, z1):
    for z in (z0, z1):
        k.box((x - 0.4, -0.1, z - 0.4), (x + 0.4, 4.6, z + 0.4), P.WHITE, bev=0.08)
    for y in (1.2, 2.6, 4.0):
        k.box((x - 0.5, y, z0 - 0.3), (x + 0.5, y + 0.3, z1 + 0.3), P.BLUE, bev=0.06)
    for i, (y, c) in enumerate(((1.5, P.RED), (2.9, P.YELLOW), (4.3, P.ORANGE))):
        kayak(k.sub(x, (z0 + z1) / 2, 90.0), -5.8, 5.8, y + 0.3, 0.0, c)


def flag(k, x, z, colours):
    k.cyl(x, z, -0.1, 0.4, 0.9, P.DBG, 10)
    k.cyl(x, z, 0.35, 11.0, 0.2, P.WHITE, 8, bottom=False)
    if k.lod == 2:
        return
    k.stud(x, 11.0, z, P.YELLOW, r=0.35, h=0.35)
    for i, c in enumerate(colours):
        k.box((x + 0.2, 10.6 - (i + 1) * 1.1, z - 0.06), (x + 4.2, 10.6 - i * 1.1, z + 0.06), c, bev=0)


def buoy_post(k, x, z, face):
    """A white post with a red / white lifebuoy facing face (+1 = +x, -1 = -x)."""
    if k.lod == 2:
        return
    k.box((x - 0.6, -0.1, z - 0.6), (x + 0.6, 4.6, z + 0.6), P.WHITE, bev=0.1)
    k.stud(x, 4.6, z, P.RED, r=0.4, h=0.25)
    f = k.sub(x + face * 0.95, z, 90.0)
    f.vring(0, 3.0, 0, 1.25, 0.4, [P.RED, P.WHITE], seg=8)


def lifeguard_tower(k, x, z):
    """White stilts, a red studded platform with a white rail, a red / white canopy, a yellow ladder (faces -z)."""
    if k.lod == 2:
        k.box((x - 3, 0, z - 3), (x + 3, 6.6, z + 3), P.WHITE, bev=0)
        k.frustum(x, z, [(9.6, 4.0), (11.4, 0.5)], P.RED, n=4)
        return
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.box((x + sx * 2.4 - 0.5, -0.1, z + sz * 2.4 - 0.5), (x + sx * 2.4 + 0.5, 6.04, z + sz * 2.4 + 0.5),
                  P.WHITE, bev=0.1)
    k.box((x - 3.2, 6.0, z - 3.2), (x + 3.2, 6.7, z + 3.2), P.RED, bev=0.15)
    k.studs(x - 3.0, x + 3.0, z + 0.4, z + 3.0, 6.7, P.RED, pitch=2.0)
    for sx in (-1, 1):                                    # rail posts + top rails on three sides
        for sz in (-1, 1):
            k.box((x + sx * 2.9 - 0.2, 6.66, z + sz * 2.9 - 0.2), (x + sx * 2.9 + 0.2, 9.6, z + sz * 2.9 + 0.2), P.WHITE,
                  bev=0.04)
    for lo, hi in (((-3.1, -3.1), (3.1, -2.7)), ((-3.1, 2.7), (3.1, 3.1)), ((-3.1, -2.7), (-2.7, 2.7)),
                   ((2.7, -2.7), (3.1, 2.7))):
        k.box((x + lo[0], 8.1, z + lo[1]), (x + hi[0], 8.5, z + hi[1]), P.WHITE if lo[1] > -3 else P.RED, bev=0.05)
    k.box((x - 1.0, 6.66, z + 0.6), (x + 1.0, 7.9, z + 1.8), P.BLUE, bev=0.1)          # lookout seat
    k.frustum(x, z, [(9.6, 4.3), (9.9, 4.3), (11.4, 0.6)], P.RED, n=8)               # canopy
    k.frustum(x, z, [(9.45, 4.25), (9.62, 4.25)], P.WHITE, n=8)
    k.stud(x, 11.38, z, P.WHITE, r=0.5)
    for sx in (-1, 1):                                    # ladder down the front
        k.box((x + sx * 1.0 - 0.15, -0.1, z - 4.6), (x + sx * 1.0 + 0.15, 6.2, z - 4.3), P.YELLOW, bev=0.03)
    if k.lod:
        return
    for y in (1.0, 2.2, 3.4, 4.6, 5.8):
        k.box((x - 0.9, y, z - 4.55), (x + 0.9, y + 0.22, z - 4.35), P.YELLOW, bev=0.03)
    k.vring(x, 4.5, z - 3.35, 1.0, 0.35, [P.RED, P.WHITE], seg=8)                     # a lifebuoy on the front


def kiosk(k, x, z):
    """Ice-cream kiosk (faces -z): white brick hut, serving hatch, red / white awning, blue studded roof, cone sign."""
    if k.lod == 2:
        k.box((x - 5, 0, z - 3.5), (x + 5, 6.4, z + 3.5), P.WHITE, bev=0)
        return
    k.box((x - 5, -0.1, z - 3.5), (x + 5, 2.4, z + 3.5), P.BLUE, bev=0.12)             # counter course
    k.box((x - 5, 2.36, z - 3.2), (x + 5, 5.64, z + 3.5), P.WHITE, bev=0.1)
    k.box((x - 3.6, 2.6, z - 3.3), (x + 3.6, 5.0, z - 3.1), P.INK, bev=0.05)           # hatch
    k.box((x - 5.2, 2.35, z - 4.3), (x + 5.2, 2.75, z - 3.0), P.WHITE, bev=0.1)        # serving ledge
    for i in range(6):                                    # awning stripes
        xa = x - 5.2 + i * 10.4 / 6
        k.beam((xa + 0.87, 6.0, z - 3.4), (xa + 0.87, 4.9, z - 5.6), 1.66, 0.25, P.RED if i % 2 == 0 else P.WHITE)
    k.box((x - 5.4, 5.6, z - 3.7), (x + 5.4, 6.4, z + 3.7), P.BLUE, bev=0.15)
    k.studs(x - 5.0, x + 5.0, z - 1.0, z + 3.2, 6.4, P.BLUE, pitch=2.6, r=0.6)
    k.frustum(x - 3.4, z - 2.2, [(6.35, 0.15), (8.4, 0.9)], P.RIB, n=8)              # cone sign + scoop
    k.frustum(x - 3.4, z - 2.2, [(8.35, 1.05), (9.0, 1.15), (9.6, 0.8), (9.9, 0.2)], P.WHITE, n=8)
    k.stud(x - 3.4, 9.88, z - 2.2, P.RED, r=0.35)


def planter(k, x, z, along_x=True):
    """A 2 x 6 brown brick planter with a green bush and two red flower studs."""
    w, l = (6.0, 2.6) if along_x else (2.6, 6.0)
    k.box((x - w / 2, -0.1, z - l / 2), (x + w / 2, 1.6, z + l / 2), P.BROWN, bev=0.12)
    if k.lod == 2:
        return
    k.box((x - w / 2 + 0.3, 1.56, z - l / 2 + 0.3), (x + w / 2 - 0.3, 2.3, z + l / 2 - 0.3), P.GREEN, bev=0.2)
    for d in (-1.4, 0.0, 1.4) if k.lod == 0 else ():
        px, pz = (x + d, z) if along_x else (x, z + d)
        k.frustum(px, pz, [(2.2, 1.0), (2.9, 1.15), (3.5, 0.8)], P.GREEN, n=8)
    for d in (-0.7, 0.8):
        px, pz = (x + d, z - 0.3) if along_x else (x - 0.3, z + d)
        k.stud(px, 3.45, pz, P.RED if d < 0 else P.YELLOW, r=0.42)


def forklift(k, x, z, yaw=0.0):
    """Small yellow forklift (forks toward local -z), black wheels, dark cage, studded red roof."""
    f = k.sub(x, z, yaw)
    if k.lod == 1:
        f.box((-1.6, 0.2, -2.0), (1.6, 2.2, 2.4), P.YELLOW, bev=0.1)
        f.box((-1.6, 4.4, -1.9), (1.6, 5.0, 1.2), P.RED, bev=0.1)
        f.box((-1.1, 0.25, -4.6), (1.1, 4.4, -2.1), P.DBG, bev=0.05)
        return
    if k.lod == 2:
        f.box((-1.6, 0, -2.4), (1.6, 3.4, 2.4), P.YELLOW, bev=0)
        return
    f.box((-1.6, 0.6, -2.0), (1.6, 2.2, 2.4), P.YELLOW, bev=0.15)
    f.box((-1.4, 2.16, 1.0), (1.4, 3.0, 2.4), P.DBG, bev=0.12)                           # counterweight
    f.box((-0.9, 2.16, -0.6), (0.9, 2.8, 0.6), P.BLACK, bev=0.1)                          # seat
    for sx in (-1, 1):
        for sz in (-1.6, 0.9):
            f.box((sx * 1.35 - 0.12, 2.16, sz - 0.12), (sx * 1.35 + 0.12, 4.64, sz + 0.12), P.DBG, bev=0.02)
    f.box((-1.6, 4.6, -1.9), (1.6, 5.0, 1.2), P.RED, bev=0.12)
    f.studs(-1.4, 1.4, -1.7, 1.0, 5.0, P.RED, pitch=1.4, r=0.42)
    for sx in (-1, 1):                                    # mast + forks
        f.box((sx * 0.9 - 0.15, 0.3, -2.4), (sx * 0.9 + 0.15, 4.4, -2.1), P.DBG, bev=0.03)
        f.box((sx * 0.7 - 0.2, 0.25, -4.6), (sx * 0.7 + 0.2, 0.45, -2.3), P.DBG, bev=0.03)
    f.box((-1.1, 0.6, -2.35), (1.1, 1.6, -2.1), P.DBG, bev=0.03)
    for sx in (-1, 1):
        for sz in (-1.2, 1.6):
            ff = f.sub(sx * 1.7, sz, 90.0)
            ff.vring(0, 0.62, 0, 0.42, 0.22, [P.BLACK], seg=6, sub=1, mnr=4)


def ramp_props(k):
    kb = KERB["RampWharf"]
    for i, (x, z) in enumerate(BOLL):
        bollard(k, x, z, 1.0, True, P.DBG, P.WHITE, kb)
    for (x, z) in LAMPS:
        lamp_post(k, x, z)
    for x in (-36.9, -12.3, 12.3, 36.9, -55.0, 55.0):
        fender_bar(k, x, kb)
    for x in (-24.6 + 4, 24.6 - 4):
        tyre(k, x, kb)
    ladder(k, -30.0, kb)
    for x in (-12.3, 12.3):
        bench(k, x, -40.5)
    for x, z, c in ((-46.0, 12.0, P.RED), (-30.0, 30.0, P.RED), (-46.0, 34.0, P.RED), (2.0, 26.0, P.BLUE),
                    (-34.0, -2.0, P.BLUE)):
        parasol(k, x, z, c)
    lifeguard_tower(k, -50.0, -33.0)
    kiosk(k, -14.0, 40.5)
    for x, z in ((-18.0, -41.0), (18.0, -41.0), (4.0, 42.0), (16.0, 42.0)):
        planter(k, x, z)
    kayak_rack(k, 56.5, 2.0, 14.0)
    for x in (-57.5, 57.5):
        flag(k, x, 43.0, (P.BLUE, P.WHITE) if x < 0 else (P.RED, P.WHITE))
    buoy_post(k, -57.0, -18.0, 1)
    buoy_post(k, 57.0, -18.0, -1)


def container(k, x, z, y0, c, length=10.0, w=4.2, h=4.2, along_z=True, studs=True):
    f = k.sub(x, z, 90.0 if along_z else 0.0)
    L = length / 2
    f.box((-L, y0, -w / 2), (L, y0 + h, w / 2), c, bev=0.12, drop=("bottom",))   # r4: hidden bottoms dropped
    for s in (-1, 1) if k.lod < 2 else ():           # dark corner posts at the door end and the far end
        for e in (-1, 1):
            f.box((e * L - 0.35 * e - 0.25, y0, s * (w / 2 - 0.1) - 0.25),
                  (e * L - 0.35 * e + 0.25, y0 + h + 0.05, s * (w / 2 - 0.1) + 0.25), P.DBG, bev=0.04, drop=("bottom",))
    if k.lod == 0:
        for i in range(1, 5):                        # corrugation ribs on both long sides (r4: 4, budget)
            u = -L + i * length / 5
            for s in (-1, 1):
                f.box((u - 0.18, y0 + 0.3, s * w / 2 - 0.08), (u + 0.18, y0 + h - 0.3, s * w / 2 + 0.08), c, bev=0.03,
                      drop=("bottom", "a" if s > 0 else "c"))     # r3: the face inside the wall is never seen
        for zz in (-0.9, 0.9):                       # door bars
            f.box((L - 0.05, y0 + 0.4, zz - 0.12), (L + 0.12, y0 + h - 0.4, zz + 0.12), P.DBG, bev=0.03)
        if studs:
            f.studs(-L + 0.6, L - 0.6, -w / 2 + 0.5, w / 2 - 0.5, y0 + h, c, pitch=3.0, r=0.6)


def pallet(k, x, z, s=4.4, top=0.7):
    if k.lod == 2:
        k.box((x - s / 2, -0.1, z - s / 2), (x + s / 2, top, z + s / 2), P.TAN, bev=0)
        return
    for i in range(3):
        zz = z - s / 2 + (i + 0.5) * s / 3
        k.box((x - s / 2, top - 0.3, zz - s / 9), (x + s / 2, top, zz + s / 9), P.TAN, bev=0.04, drop=("bottom",))
    for xx in (x - s / 2 + 0.5, x + s / 2 - 0.5):
        k.box((xx - 0.4, -0.1, z - s / 2 + 0.1), (xx + 0.4, top - 0.28, z + s / 2 - 0.1), P.BROWN, bev=0.04,
              drop=("bottom",))


def crate(k, x, z, y0, size=3.6, h=2.6, c=P.BROWN, top=True):
    k.box((x - size / 2, y0, z - size / 2), (x + size / 2, y0 + h, z + size / 2), c, bev=0.12, drop=("bottom",))
    for dy in (0.3, h - 0.55) if k.lod < 2 else ():
        k.box((x - size / 2 - 0.06, y0 + dy, z - size / 2 - 0.06), (x + size / 2 + 0.06, y0 + dy + 0.24,
                                                                       z + size / 2 + 0.06), P.DTAN, bev=0.02,
              drop=("bottom",))
    if k.lod == 0 and top:                               # r2: vertical slats on the four faces (r4: top crate only)
        for u in (-0.3 * size, 0.3 * size):
            for s in (-1, 1):
                k.box((x + u - 0.2, y0 + 0.5, z + s * (size / 2 + 0.07) - 0.07),
                      (x + u + 0.2, y0 + h - 0.5, z + s * (size / 2 + 0.07) + 0.07), P.DTAN, bev=0.02,
                      drop=("bottom", "a" if s > 0 else "c"))   # r3: drop the face on the crate wall
                k.box((x + s * (size / 2 + 0.07) - 0.07, y0 + 0.5, z + u - 0.2),
                      (x + s * (size / 2 + 0.07) + 0.07, y0 + h - 0.5, z + u + 0.2), P.DTAN, bev=0.02,
                      drop=("bottom", "d" if s > 0 else "b"))
    if top:
        k.studs(x - size / 2 + 0.3, x + size / 2 - 0.3, z - size / 2 + 0.3, z + size / 2 - 0.3, y0 + h, c, pitch=1.8,
                r=0.5)


def freight_props(k):
    kb = KERB["FreightWharf"]
    for i, (x, z) in enumerate(BOLL):
        bollard(k, x, z, 1.4, True, P.BLACK if i % 2 else P.DBG, P.ORANGE, kb)
    for (x, z) in LAMPS:
        lamp_post(k, x, z)
    for x in (-12.0, -4.0, 4.0, 16.0, 28.0, 34.0):                  # the barge berth (barge x ~ -10 .. 30)
        fender_bar(k, x, kb, y0=-3.6, y1=0.6, r=0.6)
    for x in (-8.0, 0.0, 8.0, 20.0, 31.0):
        tyre(k, x, kb, y=-1.9)
    for x in (-50.0, -37.0, 46.0, 56.0):
        fender_bar(k, x, kb, r=0.5)
    # container stack in the left bay (two along z, one on top), one by the inner bay
    container(k, -55.4, -28.0, 0.0, P.RED, studs=False)
    container(k, -50.8, -28.0, 0.0, P.BLUE, studs=False)
    container(k, -53.1, -28.0, 4.25, P.ORANGE)
    container(k, 49.0, 38.5, 0.0, P.WHITE, along_z=False)
    container(k, 43.0, -35.0, 0.0, P.GREEN, studs=False)   # r2: a two-high stack beside the crane bay
    container(k, 47.4, -35.0, 0.0, P.BLUE, studs=False)
    container(k, 45.2, -35.0, 4.25, P.RED)
    container(k, -49.5, 36.5, 0.0, P.GREEN, along_z=False, studs=False)   # r3: fill the empty gangway half
    container(k, -49.5, 36.5, 4.25, P.ORANGE, along_z=False)
    forklift(k, 17.0, -31.0, -90.0)
    # crates on pallets by the crane, in the inner bays and between the walkway and the crane
    for x, z, n in ((24.0, -33.0, 3), (29.5, -33.0, 2), (2.0, -30.0, 2), (45.0, 27.0, 2), (51.0, 27.0, 1),
                    (56.0, 27.0, 2), (-16.0, 22.0, 2), (-10.0, 22.0, 1)):
        pallet(k, x, z)
        for j in range(n):
            crate(k, x, z, 0.7 + j * 2.66, c=(P.BROWN, P.RIB)[j % 2], top=j == n - 1)
    # r4: the two -x bays (right third of the game shot): bigger crates 2-3 high + a two-high container
    container(k, -42.4, 24.0, 0.0, P.BLUE, studs=False)
    container(k, -42.4, 24.0, 4.25, P.GREEN)
    for x, z, n in ((-53.0, 25.0, 3), (-47.2, 25.0, 2), (-46.0, -34.5, 3), (-46.0, -22.0, 2)):
        pallet(k, x, z, s=4.6)
        for j in range(n):
            crate(k, x, z, 0.7 + j * 3.06, size=4.0, h=3.0, c=(P.BROWN, P.RIB)[j % 2], top=j == n - 1)


def crane(k):
    """Yellow brick tower crane on a hazard pedestal, slewing cab + counterweight, Technic boom over the berth."""
    x, z = CRANE
    k.box((x - 3.2, -0.1, z - 3.2), (x + 3.2, 0.8, z + 3.2), P.DBG, bev=0.15)
    k.box((x - 2.8, 0.75, z - 2.8), (x + 2.8, 1.4, z + 2.8), P.YELLOW, bev=0.12)
    for sx in (-1, 1):
        for sz in (-1, 1):
            k.stud(x + sx * 2.1, 1.4, z + sz * 2.1, P.YELLOW, r=0.5)
    ys = [1.35 + i * 1.2 for i in range(10)]          # 3 x 3 brick tower, 9 courses with grooves
    if k.lod == 2:
        k.box((x - 1.5, 1.35, z - 1.5), (x + 1.5, ys[-1], z + 1.5), P.YELLOW, bev=0)
    else:
        for i in range(9):
            k.box((x - 1.5, ys[i] + (0.06 if i else 0), z - 1.5), (x + 1.5, ys[i + 1], z + 1.5),
                  P.YELLOW if i % 3 else P.ORANGE, bev=0.05, drop=("bottom",))
        k.box((x - 1.4, 1.4, z - 1.4), (x + 1.4, ys[-1] - 0.05, z + 1.4), P.DBG, bev=0, drop=("bottom", "top"))
    yt = ys[-1]                                       # 12.15
    k.cyl(x, z, yt - 0.05, yt + 0.6, 2.0, P.DBG, 16)  # slew ring
    y0 = yt + 0.6
    k.box((x - 2.0, y0, z - 1.4), (x + 2.0, y0 + 3.4, z + 2.4), P.YELLOW, bev=0.15)        # cab
    k.box((x - 1.6, y0 + 1.4, z - 1.55), (x + 1.6, y0 + 3.0, z - 1.3), P.GLASS, bev=0.05)   # cab window (front -z)
    for s in (-1, 1):
        k.box((x + s * 2.05 - 0.15, y0 + 1.4, z - 1.0), (x + s * 2.05 + 0.15, y0 + 3.0, z + 1.4), P.GLASS, bev=0.04)
    k.box((x - 2.2, y0 + 3.4, z - 1.6), (x + 2.2, y0 + 3.8, z + 2.6), P.RED, bev=0.15)      # roof plate
    k.studs(x - 2.0, x + 2.0, z - 1.4, z + 2.4, y0 + 3.8, P.RED, pitch=2.0, r=0.5)
    k.box((x - 1.9, y0 + 0.2, z + 2.4), (x + 1.9, y0 + 2.8, z + 5.0), P.DBG, bev=0.15)      # counterweight
    k.box((x - 1.95, y0 + 1.0, z + 4.97), (x + 1.95, y0 + 1.6, z + 5.06), P.YELLOW, bev=0) if k.lod < 2 else None
    # boom: from the cab front up and out over the barge berth (tip over the barge centre)
    tip = (x, y0 + 7.5, BARGE[2] + 0.5)
    root = (x, y0 + 2.2, z - 1.2)
    k.beam(root, tip, 1.8, 1.8, P.YELLOW)                 # r2: a chunkier Technic beam
    if k.lod < 2:
        for i in range(1, 8):                         # Technic holes on both faces
            t = i / 8.0
            px, py, pz = (root[j] + (tip[j] - root[j]) * t for j in range(3))
            bx, by, bz = k.p(px, py, pz)
            k.b.cyl_x(bx, by, bz, 0.4, 1.92, P.INK, n=8 if k.lod == 0 else 6)
    k.box((x - 0.8, tip[1] - 0.8, tip[2] - 0.8), (x + 0.8, tip[1] + 0.8, tip[2] + 0.8), P.RED, bev=0.1)   # tip head
    # A-frame mast on the cab roof + stays to the tip and the counterweight
    mast = (x, y0 + 7.2, z + 1.2)
    k.box((x - 0.35, y0 + 3.8, z + 0.85), (x + 0.35, mast[1], z + 1.55), P.YELLOW, bev=0.05)
    k.beam(mast, (x, tip[1] + 0.6, tip[2] + 0.6), 0.16, 0.16, P.INK)
    k.beam(mast, (x, y0 + 2.8, z + 4.6), 0.16, 0.16, P.INK)
    # hook: cable, red block, hook, a crate on a pallet hanging under it
    hy = 10.0
    k.box((x - 0.07, hy + 1.2, tip[2] - 0.07), (x + 0.07, tip[1] - 0.8, tip[2] + 0.07), P.INK, bev=0)
    k.box((x - 0.6, hy, tip[2] - 0.5), (x + 0.6, hy + 1.25, tip[2] + 0.5), P.RED, bev=0.1)
    k.box((x - 0.15, hy - 0.8, tip[2] - 0.15), (x + 0.15, hy, tip[2] + 0.15), P.DBG, bev=0.03)
    for s in (-1, 1):                                 # sling lines to the crate
        k.beam((x, hy - 0.8, tip[2]), (x + s * 2.8, hy - 2.95, tip[2]), 0.1, 0.1, P.INK)
    container(k, x, tip[2], hy - 5.9, P.GREEN, length=7.0, w=3.2, h=3.0, along_z=False)   # r2: a hanging container


def lamps_of(slot):
    def fn(k):
        for (x, z) in LAMPS:
            lamp_head(k, x, z)
    return fn


# ------------------------------------------------------------------------------------------------ the jump ramp
def ramp_frame(k):
    return k.sub(RAMP_AT[0], RAMP_AT[1], RAMP_AT[2])


def _clip(poly, axis, val, keep_less):
    out = []
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        ina = a[axis] <= val if keep_less else a[axis] >= val
        inb = b[axis] <= val if keep_less else b[axis] >= val
        if ina:
            out.append(a)
        if ina != inb:
            t = (val - a[axis]) / (b[axis] - a[axis])
            out.append(tuple(a[j] + t * (b[j] - a[j]) for j in range(2)))
    return out


def ramp_y(z):
    """The running surface of the code's wedge: R_LOW at the toe (z +16), R_TOP at the lip (z -16)."""
    return R_LOW + (R_L / 2 - z) * (R_TOP - R_LOW) / R_L


def jump_ramp(k):
    """RingLayout.RAMP: the running surface is exactly the code wedge (yellow slope bricks, 0.1 grooves, raised red
    chevrons, red / white kicker row at the lip); one red sloped cheek per side (r4), a red brick face stepping back
    under the lip on stone pylons; a navy base under water; a yellow buoy lane from the toe to the deck edge."""
    r = ramp_frame(k)
    lod = r.lod
    hw, hl = R_W / 2, R_L / 2
    nrm = (0.0, 1.0, (R_TOP - R_LOW) / R_L)
    g = 0.05
    # running surface
    if lod == 2:
        r.poly([(x, ramp_y(z), z) for x, z in ((-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl))], P.YELLOW, nrm)
    else:
        r.poly([(x, ramp_y(z) - 0.3, z) for x, z in ((-hw + 0.02, -hl + 0.02), (hw - 0.02, -hl + 0.02),
                                                      (hw - 0.02, R_WET), (-hw + 0.02, R_WET))], P.DBG, nrm)
        rows, dz = 8, R_L / 8
        for i in range(rows - 2):                        # r3: the two rows wholly under water are left out (ghost slab)
            z0 = -hl + (i * dz + g if i else 0.0)
            z1 = -hl + ((i + 1) * dz - g if i < rows - 1 else R_L)
            m = 4 if i == 0 else 2                       # the lip row is the red / white kicker
            for j in range(m):
                x0 = -hw + (j * R_W / m + g if j else 0.0)
                x1 = -hw + ((j + 1) * R_W / m - g if j < m - 1 else R_W)
                c = (P.RED if j % 2 == 0 else P.WHITE) if i == 0 else P.YELLOW
                r.slab([(x0, z0), (x1, z0), (x1, z1), (x0, z1)], -0.6, 0.0, c, ramp_y)
    iw, a, wz = hw - 0.9, 0.6, 1.6                       # chevrons: apex toward the lip, raised 0.05
    for c0 in (-12.0, -7.5, -3.0, 1.5):                  # r3: all four above the waterline
        hexa = [(-iw, c0 + a * iw), (0.0, c0), (iw, c0 + a * iw), (iw, c0 + a * iw + wz), (0.0, c0 + wz),
                (-iw, c0 + a * iw + wz)]
        r.slab(hexa, -0.1, 0.05, P.RED, ramp_y)
    # r4: one red slope-brick cheek per side whose bevelled top follows the slope line (0.8 over the running
    # surface) down to the waterline, seams every 4 studs, a short studded post at the lip (no steps, no stripes)
    cb = SEA - 1.5
    H, bv = 0.8, (0.12, 0.08, 0.0)[lod]
    top = lambda z: ramp_y(z) + H
    zE = R_L / 2 - 4.0 * (SEA - H - R_LOW)               # where the cheek top meets the water

    def wedge(x0, x1, z0, z1):
        C = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
        I = [(x0 + bv, z0 + bv), (x1 - bv, z0 + bv), (x1 - bv, z1 - bv), (x0 + bv, z1 - bv)]
        v = [(x, cb, z) for x, z in C] + [(x, top(z) - bv, z) for x, z in C] + [(x, top(z), z) for x, z in I]
        f = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (8, 9, 10, 11)]
        if bv:
            f += [(4, 5, 9, 8), (5, 6, 10, 9), (6, 7, 11, 10), (7, 4, 8, 11)]
        else:
            v, f = v[:8], f[:4] + [(4, 5, 6, 7)]
        r.b._emit([r.p(*q) for q in v], f, P.RED)
    zs = [-hl - 0.2, -hl + 1.8] + ([zE] if lod == 2 else [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, zE])
    for s in (-1, 1):
        x0, x1 = sorted((s * (hw + 0.06), s * (hw + 1.7)))
        r.box((x0, cb, zs[0]), (x1, R_TOP + 1.2, zs[1] - 0.03), P.RED, bev=bv, drop=("bottom",))   # the lip post
        r.stud((x0 + x1) / 2, R_TOP + 1.2, (zs[0] + zs[1]) / 2, P.RED, r=0.6)
        for j in range(1, len(zs) - 1):
            wedge(x0, x1, zs[j] + 0.03, zs[j + 1] - (0.03 if j < len(zs) - 2 else 0.0))
    # r4: the r3 underwater brick base is gone (it read as a pale slab under the water); the cheeks reach SEA-1.5
    # lip face: four brick courses, each stepped 2 back under the one above (the treads read from the sea)
    yb = [0.3, -1.3, -2.9, SEA - 1.5]
    yt = [R_TOP - 0.61, yb[0] - 0.06, yb[1] - 0.06, yb[2] - 0.06]
    for i in range(4):
        zf = -hl - 0.3 + 2.0 * i
        m = (1, 1, 1, 1)[i] if lod == 2 else (4, 3, 4, 3)[i]
        for j in range(m):
            x0 = -hw + j * R_W / m + 0.04
            x1 = -hw + (j + 1) * R_W / m - 0.04
            r.box((x0, yb[i], zf), (x1, yt[i], zf + 2.06), P.RED, bev=0.1)      # r4: solid red, no stripes
    if lod < 2:                                          # round 2 x 2 brick pylons under the lip
        for x in (-4.5, 0.0, 4.5):
            ys = [SEA - 3, SEA - 1.5, SEA, SEA + 1.5, -1.0, yb[0] - 0.06]
            if lod == 1:
                r.cyl(x, -15.3, ys[0], ys[-1], 0.9, P.STONE, 8, bottom=False)
                continue
            for q in range(len(ys) - 1):
                r.cyl(x, -15.3, ys[q] + (0.07 if q else 0.0), ys[q + 1], 0.9, (P.STONE, P.STONE, P.STONE, P.YELLOW,
                      P.BLACK)[q], 12, bottom=False)          # r4: stone piling, hazard band under the lip
            r.cyl(x, -15.3, ys[0], ys[-1] - 0.04, 0.75, P.DBG, 8, bottom=False, top=False)
        # r4: a yellow buoy lane from the toe to the deck edge (the ramp and the wharf read as one set)
        for z in (19.0, 25.0, 31.0, 37.0, 43.0):
            for s in (-1, 1):
                x = s * (hw + 3.5)
                if r.xz(x, z)[1] > -HD - 2.5:               # stop short of the quay kerb
                    continue
                r.cyl(x, z, SEA - 0.6, SEA + 0.4, 0.95, P.YELLOW, 10, bottom=False)
                r.cyl(x, z, SEA + 0.46, SEA + 1.2, 0.85, P.YELLOW, 10, bottom=False)
                r.stud(x, SEA + 1.2, z, P.WHITE, r=0.45)


# ------------------------------------------------------------------------------------------------ modules
MODULES = [
    ("L01_RampShafts", "RampWharf", lambda k: shafts(k, "RampWharf")),
    ("L02_RampCourseLow", "RampWharf", lambda k: course_low(k, "RampWharf")),
    ("L03_RampCourseHigh", "RampWharf", lambda k: course_high(k, "RampWharf")),
    ("L04_RampDeck", "RampWharf", ramp_deck),
    ("L05_RampProps", "RampWharf", ramp_props),
    ("L06_RampLamps", "RampWharf", lamps_of("RampWharf")),
    ("L07_JumpRamp", "RampWharf", jump_ramp),
    ("L08_FreightShafts", "FreightWharf", lambda k: shafts(k, "FreightWharf")),
    ("L09_FreightCourseLow", "FreightWharf", lambda k: course_low(k, "FreightWharf")),
    ("L10_FreightCourseHigh", "FreightWharf", lambda k: course_high(k, "FreightWharf")),
    ("L11_FreightDeck", "FreightWharf", freight_deck),
    ("L12_FreightProps", "FreightWharf", freight_props),
    ("L13_FreightLamps", "FreightWharf", lamps_of("FreightWharf")),
    ("L14_CargoCrane", "FreightWharf", crane),
]

# gameplay anchors: (name, slot, (x, y, z) in the plate frame, yaw deg (Roblox CFrame.Angles(0, yaw, 0)))
ATTS = [
    ("ATT_Ramp", "RampWharf", (RAMP_AT[0], 0.0, RAMP_AT[1]), RAMP_AT[2]),        # = code `at` (y 0 = deck top)
    ("ATT_TealBrick", "RampWharf", (TEAL[0], 0.0, TEAL[1]), math.degrees(TEAL[2])),
    ("ATT_Gangway_Ramp", "RampWharf", (GANG_X["RampWharf"], GANG_TOP, (GANG_Z0 + GANG_Z1) / 2), 0.0),
    ("ATT_Lamp_Ramp_L", "RampWharf", (LAMPS[0][0], LAMP_Y, LAMPS[0][1]), 0.0),
    ("ATT_Lamp_Ramp_R", "RampWharf", (LAMPS[1][0], LAMP_Y, LAMPS[1][1]), 0.0),
    ("ATT_Dock_Ramp_01", "RampWharf", (-12.3, SEA, -HD - 4.0), 90.0),        # boats alongside the sea face, bow -x
    ("ATT_Dock_Ramp_02", "RampWharf", (-46.0, SEA, -HD - 4.0), 90.0),
    ("ATT_BargeMoor", "FreightWharf", (BARGE[0], BARGE[1], BARGE[2]), BARGE[3]),  # = code Marks.ATT_BargeMoor
    ("ATT_Gangway_Freight", "FreightWharf", (GANG_X["FreightWharf"], GANG_TOP, (GANG_Z0 + GANG_Z1) / 2), 0.0),
    ("ATT_Lamp_Freight_L", "FreightWharf", (LAMPS[0][0], LAMP_Y, LAMPS[0][1]), 0.0),
    ("ATT_Lamp_Freight_R", "FreightWharf", (LAMPS[1][0], LAMP_Y, LAMPS[1][1]), 0.0),
    ("ATT_CranePivot", "FreightWharf", (CRANE[0], 12.75, CRANE[1]), 0.0),
    ("ATT_CraneHook", "FreightWharf", (CRANE[0], 10.0, BARGE[2] + 0.5), 0.0),
    ("ATT_Dock_Freight_01", "FreightWharf", (-HW - 4.0, SEA, 0.0), 0.0),      # the left side face, bow -z
]


def build():
    import bpy  # noqa: F401
    patch_lod_names()
    mat = lego.material("MI_SeaPlateKit_Brick", ALB)
    meshes, lods = [], {}
    for name, slot, fn in MODULES:
        tris = []
        for lod in (0, 1, 2):
            b = lego.B()
            fn(K(b, SLOTS[slot], 0.0, 0.0, lod))
            tris.append(b.tris())
            if lod:
                lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat)
            else:
                obj = b.to_object(name, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        print("[seaplate] %-22s %5d / %5d / %5d tris" % (name, *tris))
    patch_lod(lods)
    c = lego.B()
    K(c).box((-3, -1.0, -1), (3, 0.0, 1), P.DBG, bev=0)
    meshes.append({"object": c.to_object("Col01_COL", mat), "role": "col"})

    def att(n, slot, pos, yaw):
        X = SLOTS[slot] + pos[0]
        e = lego.attach(n, (-X, pos[2], pos[1]))
        e.rotation_euler = (0.0, 0.0, math.radians(yaw))    # Blender z yaw = Roblox y yaw (export: -Y local = look)
        return e
    atts = [att("ATT_" + s, s, (0.0, 0.0, 0.0), 0.0) for s in SLOTS]
    atts += [att(n, s, p, y) for n, s, p, y in ATTS]

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[seaplate] LOD0 %d tris; dims_m %s" % (total, dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "a kit of two assembled 123 x 96 sea plates placed by code at ATT_RampWharf / ATT_FreightWharf",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_RampShafts...: the wiring code places each module by name",
            "LOD UV layout": "flat palette cells (one shared material): hand-made LODs drop studs and merge tiles, UVs "
                             "are not a unique unwrap by design (tiling=True skips the density check)",
            "texture sets": "one flat Lego palette set shared by every Lego kit (BoardKit, BuildSiteKit); the "
                            "hero_building class is only for its triangle ceilings (two 123 x 96 plates)",
        },
        "meshes": meshes,
        "attachments": atts,
    }
