"""M_Prop_BoardKit: Lego boards and signs that replace four code-built props (docs/28 Code->mesh, tour 2026-10-31).

One FBX, one flat palette material (same cells as M_Prop_BuildSiteKit / M_Prop_JettyCrane), every module its own mesh.
Modules sit side by side along Roblox +X; each has an ATT_<Slot> empty at its own origin (ground centre, Roblox axes:
x across, y up, front -z), so the wiring code re-places every MeshPart relative to it. Text, decals and icons stay in
code: each face has an ATT_* at the face centre, on the plane where the code's SurfaceGui / Decal Part goes.

  L01_RescueBoard    LeaderboardService.Board: navy board in a straight 1-stud red/white brick frame (studded top
                     course) on two 2 x 2 yellow brick legs on 2 x 6 grey plates, a 1.5x gold trophy on a 2 x 2 plinth;
                     both faces carry a 3 x 5 row grid (r2: was 3 x 8), gold/silver/bronze rank tiles. Face 13.14 x 10.06,
                     centre 7.0 up (ATT_BoardFaceF / ATT_BoardFaceB, 0.05 in front of the rank tiles).
  L02_ComingSoon     ComingSoon.place: the 11.5 x 5.75 PNG sign face (r3: was 10 x 5; code Part + Decal at ATT_SoonFace,
                     7.7 up) between two yellow/black 2 x 2 hazard posts (plate to top), orange/white studded courses,
                     a 1.3x red/white barricade on yellow 1 x 1 legs and three cones on a tan 16 x 8 plate.
  L03_IslandSign     DockService.nameSign: arch over the jetty root, yellow 3-brick posts with a grey collar and a
                     studded 2 x 2 cap, a deep white rim with a navy outline round the name plate, a red studded top
                     rail, a lifebuoy on one post. The plate itself stays the code's NameBoard Part (owner colour;
                     27 x 7 x 0.8 at ATT_NamePlate, GUIs on its Front and Back faces).
  L04_HarbourBeacon  DockService.setMaster: red/white banded 3 x 3 brick mast on a studded stepped base with a red
                     trim plate, white-rimmed blue icon plate (ATT_BeaconIcon, 2.6 x 2.6, 4.7 up, z -2.075), railed gallery,
                     4 x 4 lantern room with glazing bars, red roof.
  L05_BeaconLens     the lens alone (so the code can make it Neon); ATT_BeaconLight at its centre (26.7 up, PointLight).
  L06_BeaconPanes    pale-blue lantern panes (r3; the code makes them transparent).
  Col01_COL          a token box (the code never collides with these)

    python3 art/source/props/M_Prop_BoardKit/maketex.py --out build/prod/M_Prop_BoardKit/textures/M_Prop_BoardKit
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_BoardKit/build.py \
        --out-root build/prod/M_Prop_BoardKit --steps build,lod,validate,export
LODs are hand-made (patch_lod): LOD1 drops studs and turns the board tiles into single-sided quads, LOD2 also merges
brick stacks and the row grid; versions.decimate only cuts further if one is over its target.
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

NAME = "M_Prop_BoardKit"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "BoardKit", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_BoardKit_Brick_ALB.png")

Y0 = -0.06          # every foot just under the ground: never coplanar with it
SINK = 0.04         # studs sink this far into the top they stand on (no bottom cap, nothing coplanar)
SLOTS = {"Board": 0, "Soon": 22, "Sign": 50, "Beacon": 76}   # module origins in the kit, Roblox x (studs)

# RescueBoard: the code's panel at 50 px/stud; r2: 5 rows per column, 30% taller than r1 (7.74)
FW, FH, BCY = 13.14, 10.06, 7.0
SLAB, TILE = 0.25, 0.08             # slab half depth; tiles stand this far proud of it
OUTL = 0.4                          # r3: navy outline between the face and the frame
COLS, CW = [0.68 + i * 4.0333 for i in range(3)], 3.7133
ROW0, ROWP, ROWH, NROWS = 3.15, 1.312, 1.18, 5   # row grid, from the face top
# ComingSoon: code board (r2: 1.5 higher); IslandSign: code NameBoard 27 x 7 x 0.8; Beacon lens centre
SW, SH, SCY, SFZ = 11.5, 5.75, 7.7, -0.25    # r3: face 15% bigger (r2 10 x 5)
NW, NH, NCY, ND = 27.0, 7.0, 13.2, 0.8
LENS_Y = 26.7       # r2: mast 3x3 and ~25% shorter (r1 35.1)
MAST_W = 3.45      # r3: 15% wider (r2 3.0)
ICON_Y, ICON_Z = 4.7, -2.075   # r3: 0.225 forward with the wider mast (r2 -1.85)


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


def patch_lod(prebuilt):
    """The lod step starts from our hand-made LOD1 / LOD2 meshes (no studs, single-sided tiles, merged stacks), so the
    board rows stay clean; versions.decimate still runs on them and only cuts if one is over its target."""
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


class K:
    """Roblox-axes authoring (x, y up, z back) on a lego.B at a slot origin; Blender = (-x, z, y). lod 0/1/2."""

    def __init__(self, b, ox, oy=0.0, lod=0):
        self.b, self.ox, self.oy, self.lod = b, ox, oy, lod

    def p(self, x, y, z):
        return (-(x + self.ox), z, y + self.oy)

    def box(self, lo, hi, c, bev=None, drop=()):
        """drop: hidden faces left out (r3 budget): 'bottom', 'top', 'front' (-z), 'back' (+z)."""
        ids = {"bottom": 0, "top": 1, "front": 2, "back": 4}
        self.b.box(self.p(*lo), self.p(*hi), c, bevel=bev, drop=tuple(ids[d] for d in drop))

    def cyl(self, x, z, y0, y1, r, c, n=8, bottom=True):
        bx, by, _ = self.p(x, 0, z)
        self.b.cyl(bx, by, y0 + self.oy, y1 + self.oy, r, c, n, bottom=bottom)

    def stud(self, x, y, z, c, r=0.3, h=0.2, n=None):
        """A Lego stud standing on the top at height y (dropped from the LODs)."""
        if self.lod:
            return
        self.cyl(x, z, y - SINK, y + h, r, c, n or (6 if r <= 0.3 else 8), bottom=False)   # r3: small studs 6-sided

    def studs(self, x0, x1, z0, z1, y, c, pitch=1.0, r=0.3, h=0.2, skip=None):
        """A grid of studs on the top rectangle x0..x1, z0..z1 at height y (pitch 1 = one Roblox stud)."""
        nx, nz = max(1, round((x1 - x0) / pitch)), max(1, round((z1 - z0) / pitch))
        for i in range(nx):
            for j in range(nz):
                x, z = x0 + (i + 0.5) * (x1 - x0) / nx, z0 + (j + 0.5) * (z1 - z0) / nz
                if not (skip and skip(x, z)):
                    self.stud(x, y, z, c, r, h)

    def face(self, x0, x1, y0, y1, z, c, s):
        """A single-sided quad on the plane z facing s (-1 front / +1 back): LOD tiles."""
        pts = [self.p(x0, y0, z), self.p(x1, y0, z), self.p(x1, y1, z), self.p(x0, y1, z)]
        self.b.quad(pts, c, (0.0, float(s), 0.0))

    def beam(self, p0, p1, w, h, c):
        self.b.beam(self.p(*p0), self.p(*p1), w, h, c)

    def frustum(self, x, z, rings, c, n=10, rot=0.0):
        """Stacked rings [(y, r)] round a vertical axis, capped both ends."""
        n = max(5, n - 2 * self.lod)
        secs = []
        for y, r in rings:
            secs.append([self.p(x + r * math.cos(rot + 2 * math.pi * i / n), y, z + r * math.sin(rot + 2 * math.pi * i / n))
                         for i in range(n)])
        self.b.loft(secs, c)

    def ring(self, cx, cy, cz, R, r, colours, seg=8, sub=2, mnr=6):
        """A lifebuoy round the Roblox z axis: seg capped arcs cycling colours."""
        sub, mnr = ((sub, mnr), (1, 6), (1, 4))[self.lod]
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
            self.b._emit(verts, faces, colours[k % len(colours)], smooth=True)


def stack(k, x, z, y0, y1, w, colours, unit=1.2, per=1, gap=0.05, bev=0.04, d=None, seam=P.DBG, ys=None):
    """A flush column of square bricks (w x d, ~`unit` high) from y0 to y1, colour changing every `per` bricks. r3: every
    course is the same footprint with a crisp `gap` groove; a dark core inset 0.1 shows in the grooves (no two faces share
    a plane). LOD2 merges each colour band into one box. r4: ys = explicit course breakpoints (y0 ... y1)."""
    d = d or w
    if ys is None:
        n = max(1, round((y1 - y0) / unit))
        ys = [y0 + i * (y1 - y0) / n for i in range(n + 1)]
    n = len(ys) - 1
    per = n if k.lod == 2 and len(colours) == 1 else per
    groups = [(i, min(i + per, n)) for i in range(0, n, per)] if k.lod == 2 else [(i, i + 1) for i in range(n)]
    for a, b in groups:
        c = colours[(a // per) % len(colours)]
        k.box((x - w / 2, ys[a] + (gap if a else 0), z - d / 2), (x + w / 2, ys[b], z + d / 2), c, bev=bev,
              drop=("bottom",))                     # every brick stands on something
    if len(groups) > 1:
        k.box((x - w / 2 + 0.1, y0 + 0.03, z - d / 2 + 0.1), (x + w / 2 - 0.1, y1 - 0.1, z + d / 2 - 0.1), seam, bev=0,
              drop=("bottom", "top"))
    return n, (y1 - y0) / n


# ------------------------------------------------------------------ (a) rescue board
def rescue_board(k):
    top, bot = BCY + FH / 2, BCY - FH / 2
    e = OUTL + 0.02 if k.lod == 2 else 0.1          # LOD2: the slab itself is the outline
    k.box((-FW / 2 - e, bot - e, -SLAB), (FW / 2 + e, top + e, SLAB), P.INK, bev=0.03)
    # r3: a 1-plate (0.4) navy outline between the face and the frame, standing proud of the slab
    o, oz = OUTL, 0.42
    for y0, y1 in () if k.lod == 2 else ((top, top + o + 0.02), (bot - o - 0.02, bot)):
        k.box((-FW / 2 - o - 0.02, y0, -oz), (FW / 2 + o + 0.02, y1, oz), P.INK, bev=0.06)
    for s in () if k.lod == 2 else (-1, 1):
        k.box((s * FW / 2, bot - 0.1, -oz + 0.01), (s * (FW / 2 + o + 0.01), top + 0.1, oz - 0.01), P.INK, bev=0.06)
    # straight 1-stud red/white frame of ~2-stud blocks, one depth all round; studded top course
    t, d = 1.0, 0.5
    ft, fb, fx = top + o, bot - o, FW / 2 + o                # frame inner edges
    L = 2 * fx + 2 * t
    n = round(L / 2)
    w = L / n
    for i in range(n):
        x0 = -L / 2 + i * w
        for y0, y1, flip in ((ft, ft + t, 0), (fb - t, fb, 1)):
            c = P.RED if (i + flip) % 2 == 0 else P.WHITE
            k.box((x0 + 0.025, y0, -d), (x0 + w - 0.025, y1, d), c, bev=0.03)
            if not flip:
                k.studs(x0 + 0.025, x0 + w - 0.025, -d, d, y1, c, skip=lambda x, z: abs(x) < 1.0)
    ns = round((ft - fb) / 2)
    for s in (-1, 1):
        for j in range(ns):
            y0 = fb + j * (ft - fb) / ns
            c = P.WHITE if j % 2 == 0 else P.RED
            k.box((s * fx, y0 + 0.025, -d), (s * (fx + t), y0 + (ft - fb) / ns - 0.025, d), c, bev=0.03)
    # the row grid on both faces: GUI left = +x seen from the front (-z), -x seen from the back
    rank = {1: P.YELLOW, 2: P.LBG, 3: P.RIB}               # gold / silver / bronze; r3: ranks 4-5 dark navy
    for s in (-1, 1):
        z0, z1 = s * (SLAB - 0.02), s * (SLAB + TILE)
        zb = s * (SLAB + TILE + 0.08)                      # rank 1-3 tiles stand further out

        def tile(u0, u1, v0, v1, c, z=z1, bev=0.04):
            xa, xb = (-FW / 2 + u0, -FW / 2 + u1) if s > 0 else (FW / 2 - u1, FW / 2 - u0)
            if k.lod:
                k.face(xa, xb, top - v1, top - v0, z, c, s)
            else:
                k.box((xa, top - v1, min(z0, z)), (xb, top - v0, max(z0, z)), c, bev=bev,
                      drop=("back" if s < 0 else "front",))          # its foot inside the slab

        tile(0.35, FW - 0.35, 0.34, 1.95, P.RED)                                    # header (title + subtitle)
        for u in COLS:
            tile(u, u + CW, 2.2, 2.9, P.YELLOW)                                     # column title
            if k.lod == 2:                                                          # far: one blue block per column
                tile(u, u + CW, ROW0, ROW0 + (NROWS - 1) * ROWP + ROWH, P.BLUE)
                continue
            for r in range(1, NROWS + 1):
                v = ROW0 + (r - 1) * ROWP
                tile(u, u + ROWH, v, v + ROWH, rank.get(r, P.INK), z=zb if r in rank else z1, bev=0.06)
                tile(u + ROWH + 0.1, u + CW, v, v + ROWH, P.BLUE)                   # name + value tile
    # trophy (r1 x 1.5) on a 2 x 2 studded plinth mid top course
    yb = ft + t
    k.box((-1.0, yb, -1.0), (1.0, yb + 1.2, 1.0), P.DBG, bev=0.16, drop=("bottom",))
    for x in (-0.5, 0.5):
        for z in (-0.5, 0.5):
            k.stud(x, yb + 1.2, z, P.DBG)
    y = yb + 1.2
    k.frustum(0, 0, [(y - 0.02, 0.4), (y + 0.3, 0.4), (y + 0.3, 0.3), (y + 1.35, 0.3), (y + 1.8, 0.85),
                     (y + 2.8, 1.38), (y + 3.4, 1.5), (y + 3.4, 1.3), (y + 3.25, 1.2)], P.YELLOW, n=12)
    if k.lod < 2:
        for s in (-1, 1):                                                           # handles
            k.box((s * 1.25, y + 2.0, -0.18), (s * 2.05, y + 2.3, 0.18), P.YELLOW, bev=0.06)
            k.box((s * 1.75, y + 1.6, -0.18), (s * 2.05, y + 3.0, 0.18), P.YELLOW, bev=0.06)
    # two flush 2 x 2 yellow brick legs on 2 x 6 grey plates, ending one brick above the frame (r3)
    for s in (-1, 1):
        px = s * (fx + t + 0.93)                                                    # bites 0.07 into the frame side
        k.box((px - 1, Y0, -3), (px + 1, 0.4, 3), P.DBG, bev=0.12, drop=("bottom",))
        k.studs(px - 1, px + 1, -3, 3, 0.4, P.DBG, skip=lambda x, z: abs(z) < 1)
        stack(k, px, 0, 0.4, yb + 1.2, 2.0, (P.YELLOW,), bev=0.02)        # r4: truly flush courses
        k.studs(px - 1, px + 1, -1, 1, yb + 1.2, P.YELLOW)


# ------------------------------------------------------------------ (b) coming soon board
CONES = ((-5.5, -4.75), (0.0, -4.75), (5.5, -4.75))   # r4: one even row in front, bases sunk 0.05 into the plate


def cone(k, x, z):
    k.box((x - 0.65, 0.35, z - 0.65), (x + 0.65, 0.62, z + 0.65), P.BLACK, bev=0.1, drop=("bottom",))
    if k.lod == 2:
        k.frustum(x, z, [(0.6, 0.52), (2.1, 0.17)], P.ORANGE, n=8)
        return
    n = 10 - 2 * k.lod                              # LOD1: 6 sides
    k.frustum(x, z, [(0.6, 0.52), (1.22, 0.39)], P.ORANGE, n=n)
    k.frustum(x, z, [(1.22, 0.39), (1.55, 0.31)], P.WHITE, n=n)
    k.frustum(x, z, [(1.55, 0.31), (2.1, 0.17)], P.ORANGE, n=n)


def coming_soon(k):
    # r3: the two yellow/black 2 x 2 hazard posts ARE the frame sides, plate to top; the orange/white courses span between
    t = 1.1                                            # r4: course height ~ the post courses
    top, bot = SCY + SH / 2 + 0.02, SCY - SH / 2 - 0.02
    px, pzc = SW / 2 + 0.02 + 1.0, 0.05                # post centre x (inner face on the frame opening), z
    # one tan 16 x 8 plate, studs round the rim
    px0, px1, pz0, pz1 = -8.0, 8.0, -5.5, 2.5
    k.box((px0, Y0, pz0), (px1, 0.4, pz1), P.TAN, bev=0.14, drop=("bottom",))
    post = lambda x, z: abs(abs(x) - px) < 1.0 and abs(z - pzc) < 1.0
    k.studs(px0, px1, pz0, pz1, 0.4, P.TAN,
            skip=lambda x, z: (px0 + 1 < x < px1 - 1 and z > pz0 + 1) or post(x, z) or
            any(abs(x - cx) < 0.95 and abs(z - cz) < 0.95 for cx, cz in CONES))
    # backing slab: its front sits 0.05 behind the decal plane (ATT_SoonFace)
    fz0, fz1 = SFZ - 0.2, 0.55                       # frame depth: one stud row on the top course
    k.box((-SW / 2 - 0.2, SCY - SH / 2 - 0.2, SFZ + 0.05), (SW / 2 + 0.2, SCY + SH / 2 + 0.2, 0.3), P.BROWN, bev=0.03)
    L = SW + 0.04 + 0.1                              # courses bite 0.05 into each post
    for i in range(6):                               # even 1 x 2 bricks, one height, studded top course
        x0 = -L / 2 + i * L / 6
        x1 = x0 + L / 6
        for y0, y1, flip in ((top, top + t, 0), (bot - t, bot, 1)):
            c = P.ORANGE if (i + flip) % 2 == 0 else P.WHITE
            k.box((x0 + 0.025, y0, fz0), (x1 - 0.025, y1, fz1), c, bev=0.03)
            if flip == 0:
                k.studs(x0 + 0.025, x1 - 0.025, fz0, fz1, y1, c)
    # r4: post seams line up with the frame courses (0.02 under them: no coplanar top / bottom faces in the bite)
    even = lambda a, b, n: [a + i * (b - a) / n for i in range(n)]
    ys = None if k.lod == 2 else (even(0.4, bot - t - 0.02, 3) + [bot - t - 0.02] +
                                  even(bot - 0.02, top - 0.02, 5) + [top - 0.02, top + t])
    hz = (P.BLACK, P.YELLOW)
    for s in (-1, 1):
        n, _ = stack(k, s * px, pzc, 0.4, top + t, 2.0, hz, unit=3.6, bev=0.02, ys=ys)
        k.studs(s * px - 1, s * px + 1, pzc - 1, pzc + 1, top + t, hz[(n - 1) % 2])
    # red/white barricade (r1 x 1.3) centred in front on yellow 1 x 1 brick legs, cones either side
    S, bz = 1.3, -3.4
    yl = 0.4 + 2.36 * S
    for x in (-3.0 * S, 3.0 * S):
        stack(k, x, bz + 0.1, 0.4, yl, 1.0, (P.YELLOW,), unit=1.0, bev=0.02)
    ns = 6 if k.lod < 2 else 3
    for y0, flip in ((0.4 + 1.5 * S, 0), (0.4 + 0.6 * S, 1)):     # r4: studded flush 1 x 2 bricks, small bevel
        for i in range(ns):
            x0 = -3.5 * S + i * 7.0 * S / ns + 0.025
            x1 = x0 + 7.0 * S / ns - 0.05
            c = P.RED if (i + flip) % 2 == 0 else P.WHITE
            k.box((x0, y0, bz - 0.6), (x1, y0 + 0.9, bz - 0.1), c, bev=0.03)
            if flip == 0:
                k.studs(x0, x1, bz - 0.6, bz - 0.1, y0 + 0.9, c, pitch=0.75, r=0.2, h=0.18,
                        skip=lambda x, z: abs(abs(x) - 3.0 * S) < 0.75)
    k.stud(3.0 * S, yl, bz + 0.1, P.YELLOW)
    if k.lod == 2:
        for x, z in CONES:
            cone(k, x, z)
        return
    k.cyl(-3.0 * S, bz + 0.1, yl - 0.02, yl + 0.26, 0.32, P.DBG, n=10)
    k.frustum(-3.0 * S, bz + 0.1, [(yl + 0.26, 0.3), (yl + 0.62, 0.3), (yl + 0.84, 0.12)], P.ORANGE, n=10)
    for x, z in CONES:
        cone(k, x, z)


# ------------------------------------------------------------------ (c) island name sign
def island_sign(k):
    rx, ry, rd = NW / 2 + 0.05, NH / 2 + 0.05, 0.85                 # white rim opening (0.05 clear of the Part)
    rw, ol = 0.6, 0.5                                                # rim width; r3: 0.5 navy outline beyond it
    k.box((-rx - rw - ol, NCY - ry - rw - ol, -0.3), (rx + rw + ol, NCY + ry + rw + ol, 0.3), P.INK, bev=0.03)
    for y0, y1 in ((NCY + ry + rw - 0.05, NCY + ry + rw + ol), (NCY - ry - rw - ol, NCY - ry - rw + 0.05)):
        k.box((-rx - rw - ol, y0, -0.55), (rx + rw + ol, y1, 0.55), P.INK, bev=0.08)   # deeper outline (posts hide the sides)
    for y0, y1 in ((NCY + ry, NCY + ry + rw), (NCY - ry - rw, NCY - ry)):
        k.box((-rx - rw, y0, -rd), (rx + rw, y1, rd), P.WHITE, bev=0.14)
    for s in (-1, 1):
        k.box((s * rx, NCY - ry + 0.02, -rd), (s * (rx + rw), NCY + ry - 0.02, rd), P.WHITE, bev=0.14)
    # red brick top rail, two stud rows
    ytop = NCY + ry + rw + ol
    n = 6
    w = (2 * (rx + rw) + 0.5) / n
    for i in range(n):
        x0 = -(rx + rw) - 0.25 + i * w
        k.box((x0 + 0.03, ytop - 0.02, -0.9), (x0 + w - 0.03, ytop + 1.2, 0.9), P.RED, bev=0.18)
        k.studs(x0 + 0.03, x0 + w - 0.03, -0.9, 0.9, ytop + 1.2, P.RED, pitch=1.6, r=0.42, h=0.3)
    # bright yellow posts: flush brick courses with groove seams (r3), a grey collar plate, a 2 x 2 studded cap
    for s in (-1, 1):
        px = s * (rx + rw + 1.15)
        k.box((px - 1.8, Y0, -1.8), (px + 1.8, 1.0, 1.8), P.DBG, bev=0.18, drop=("bottom",))
        for dx in (-1.5, 1.5):
            for dz in (-1.5, 1.5):
                k.stud(px + dx, 1.0, dz, P.DBG, r=0.24, h=0.18)
        ycol = ytop + 0.6
        stack(k, px, 0, 1.0, ycol, 2.4, (P.YELLOW,))
        k.box((px - 1.4, ycol, -1.4), (px + 1.4, ycol + 0.45, 1.4), P.STONE, bev=0.12)
        k.box((px - 1.2, ycol + 0.45, -1.2), (px + 1.2, ycol + 1.65, 1.2), P.YELLOW, bev=0.2, drop=("bottom",))
        k.studs(px - 1.2, px + 1.2, -1.2, 1.2, ycol + 1.65, P.YELLOW, pitch=1.2, r=0.42, h=0.3)
    # a red/white lifebuoy (r3: 1.6x) at minifig eye height on the right post's front (seen from the front), sea cue
    px, ly = rx + rw + 1.15, 5.0
    k.ring(px, ly, -1.2 - 0.5, 1.6, 0.48, (P.RED, P.WHITE), seg=8 if k.lod < 2 else 4)
    if k.lod < 2:                                   # the peg it hangs on, inside the ring's top
        k.box((px - 0.14, ly + 0.8, -2.05), (px + 0.14, ly + 1.08, -1.1), P.BROWN, bev=0.03)


# ------------------------------------------------------------------ (d) harbour master beacon
def harbour_beacon(k):
    # studded stepped base: grey 7 x 7, red 1-plate trim, grey 5 x 5; studs on both exposed rims
    k.box((-3.5, Y0, -3.5), (3.5, 1.2, 3.5), P.STONE, bev=0.18, drop=("bottom",))   # ground plates: under the ground
    k.studs(-3.5, 3.5, -3.5, 3.5, 1.2, P.STONE, skip=lambda x, z: max(abs(x), abs(z)) < 2.8)
    k.box((-2.65, 1.2, -2.65), (2.65, 1.6, 2.65), P.RED, bev=0.1, drop=("bottom",))
    k.box((-2.5, 1.6, -2.5), (2.5, 2.8, 2.5), P.STONE, bev=0.18, drop=("bottom",))
    k.studs(-2.5, 2.5, -2.5, 2.5, 2.8, P.STONE, skip=lambda x, z: max(abs(x), abs(z)) < 1.8)
    # red/white banded brick mast (r3: 15% wider; r4: flush 1.2 courses, six even 3-course bands like r2, red at the
    # foot behind the icon plate, a white band under the gallery; the r3 band ledges broke the rhythm)
    mtop, mw = 24.4, MAST_W
    stack(k, 0, 0, 2.8, mtop, mw, (P.RED, P.WHITE), unit=1.2, per=3, bev=0.02)
    # white-rimmed icon plate on the mast foot (front -z): navy outline, white rim, blue icon field
    ih, fz = 2.6, -mw / 2                           # fz: the mast front face
    k.box((-1.8, ICON_Y - 1.8, fz - 0.25), (1.8, ICON_Y + 1.8, fz + 0.05), P.INK, bev=0.03)
    k.box((-ih / 2, ICON_Y - ih / 2, ICON_Z + 0.05), (ih / 2, ICON_Y + ih / 2, fz + 0.05), P.BLUE, bev=0.02)
    for y0, y1 in ((ICON_Y + ih / 2, ICON_Y + 1.62), (ICON_Y - 1.62, ICON_Y - ih / 2)):
        k.box((-1.62, y0, ICON_Z - 0.05), (1.62, y1, fz + 0.05), P.WHITE, bev=0.06)
    for s in (-1, 1):
        k.box((s * ih / 2, ICON_Y - ih / 2 + 0.01, ICON_Z - 0.05), (s * 1.62, ICON_Y + ih / 2 - 0.01, fz + 0.05), P.WHITE,
              bev=0.06)
    # gallery deck with a railing ring
    k.box((-3.0, mtop, -3.0), (3.0, mtop + 0.4, 3.0), P.DBG, bev=0.12)
    yd = mtop + 0.4
    if k.lod < 2:
        posts = {(i * 1.375, e) for i in range(-2, 3) for e in (-2.75, 2.75)}
        posts |= {(e, x) for x, e in posts}
        for x, z in sorted(posts):
            k.box((x - 0.11, yd, z - 0.11), (x + 0.11, yd + 1.25, z + 0.11), P.YELLOW, bev=0.03)
    for y in ((yd + 1.25,) if k.lod == 2 else (yd + 0.6, yd + 1.25)):           # rails
        for s in (-1, 1):
            k.box((-2.9, y, s * 2.75 - 0.08), (2.9, y + 0.16, s * 2.75 + 0.08), P.YELLOW, bev=0.03)
            k.box((s * 2.75 - 0.08, y + 0.01, -2.67), (s * 2.75 + 0.08, y + 0.15, 2.67), P.YELLOW, bev=0.03)
    # 4 x 4 lantern room: yellow sill, four dark corner posts, open panes round the lens, top ring, red roof
    k.box((-2.0, yd, -2.0), (2.0, yd + 0.4, 2.0), P.YELLOW, bev=0.12, drop=("bottom",))
    y0, y1 = yd + 0.4, LENS_Y + 1.7
    for x in (-1.8, 1.8):
        for z in (-1.8, 1.8):
            k.box((x - 0.2, y0, z - 0.2), (x + 0.2, y1, z + 0.2), P.DBG, bev=0.05)
    if k.lod < 2:                                   # glazing bars: the panes read as clear glass round the lens
        ym = (y0 + y1) / 2
        for s in (-1, 1):
            k.box((-1.6, ym - 0.07, s * 1.9 - 0.05), (1.6, ym + 0.07, s * 1.9 + 0.05), P.DBG, bev=0.02)
            k.box((s * 1.9 - 0.05, ym - 0.06, -1.6), (s * 1.9 + 0.05, ym + 0.06, 1.6), P.DBG, bev=0.02)
            if k.lod == 0:
                k.box((-0.06, y0, s * 1.9 - 0.05), (0.06, y1, s * 1.9 + 0.05), P.DBG, bev=0.02)
                k.box((s * 1.9 - 0.05, y0, -0.06), (s * 1.9 + 0.05, y1, 0.06), P.DBG, bev=0.02)
    k.box((-2.2, y1, -2.2), (2.2, y1 + 0.4, 2.2), P.YELLOW, bev=0.12)
    k.frustum(0, 0, [(y1 + 0.38, 3.15), (y1 + 0.68, 3.15)], P.RED, n=12)        # r3: red rim plate under the roof
    y1 += 0.3
    k.frustum(0, 0, [(y1 + 0.36, 2.9), (y1 + 0.8, 2.9), (y1 + 2.2, 0.55), (y1 + 2.3, 0.35)], P.RED, n=12)
    k.cyl(0, 0, y1 + 2.22, y1 + 2.5, 0.5, P.RED, n=10)                           # r4: short round 1 x 1 plate
    k.frustum(0, 0, [(y1 + 2.47, 0.36), (y1 + 3.15, 0.05)], P.RED, n=10)           # + cone tip


def beacon_panes(k):
    """Pale-blue clear panes between the lantern mullions (L06: the code makes them transparent)."""
    y0, y1 = 24.4 + 0.4 + 0.4, LENS_Y + 1.7
    if k.lod:                                       # LODs: one outward quad per side
        for s in (-1, 1):
            k.face(-1.62, 1.62, y0 + 0.02, y1 - 0.02, s * 1.9, P.GLASS, s)
            pts = [k.p(s * 1.9, y0 + 0.02, -1.62), k.p(s * 1.9, y0 + 0.02, 1.62), k.p(s * 1.9, y1 - 0.02, 1.62),
                   k.p(s * 1.9, y1 - 0.02, -1.62)]
            k.b.quad(pts, P.GLASS, (-float(s), 0.0, 0.0))       # Roblox +x is Blender -x
        return
    for s in (-1, 1):
        k.box((-1.62, y0 + 0.02, s * 1.9 - 0.02), (1.62, y1 - 0.02, s * 1.9 + 0.02), P.GLASS, bev=0)
        k.box((s * 1.9 - 0.02, y0 + 0.03, -1.62), (s * 1.9 + 0.02, y1 - 0.03, 1.62), P.GLASS, bev=0)


def beacon_lens(k):
    rings = [(LENS_Y - 1.45, 0.9), (LENS_Y - 1.15, 1.25), (LENS_Y + 1.15, 1.25), (LENS_Y + 1.45, 0.9)]
    if k.lod:                                       # LOD1 8 sides, 3 rings; LOD2 6 sides, a drum
        rings = [(LENS_Y - 1.45, 1.0), (LENS_Y, 1.25), (LENS_Y + 1.45, 1.0)] if k.lod == 1 else \
            [(LENS_Y - 1.45, 1.15), (LENS_Y + 1.45, 1.15)]
    k.frustum(0, 0, rings, P.YELLOW, n=(14, 10, 10)[k.lod])      # frustum takes 2 sides off per LOD


MODULES = [
    ("L01_RescueBoard", "Board", rescue_board), ("L02_ComingSoon", "Soon", coming_soon),
    ("L03_IslandSign", "Sign", island_sign), ("L04_HarbourBeacon", "Beacon", harbour_beacon),
    ("L05_BeaconLens", "Beacon", beacon_lens), ("L06_BeaconPanes", "Beacon", beacon_panes),
]

# text / decal / light anchors: (name, slot, (x, y, z) from the slot origin, face size w x h studs or None)
FACES = [
    ("ATT_BoardFaceF", "Board", (0, BCY, -(SLAB + TILE + 0.13)), (FW, FH)),   # 0.05 before the rank tiles
    ("ATT_BoardFaceB", "Board", (0, BCY, SLAB + TILE + 0.13), (FW, FH)),
    ("ATT_SoonFace", "Soon", (0, SCY, SFZ), (SW, SH)),
    ("ATT_NamePlate", "Sign", (0, NCY, 0), (NW, NH)),
    ("ATT_BeaconIcon", "Beacon", (0, ICON_Y, ICON_Z), (2.6, 2.6)),
    ("ATT_BeaconLight", "Beacon", (0, LENS_Y, 0), None),
]


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_BoardKit_Brick", ALB)
    meshes, lods = [], {}
    for name, slot, fn in MODULES:
        tris = []
        for lod in (0, 1, 2):
            b = lego.B()
            fn(K(b, SLOTS[slot], lod=lod))
            tris.append(b.tris())
            if lod:
                lods["%s_LOD%d" % (name, lod)] = b.to_mesh("%s_LOD%d_src" % (name, lod), mat)
            else:
                obj = b.to_object(name, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        print("[boards] %-18s %5d / %5d / %5d tris" % (name, *tris))
    patch_lod(lods)
    c = lego.B()
    K(c, SLOTS["Board"]).box((-3, Y0, -1), (3, 1.0, 1), P.DBG, bev=0)
    meshes.append({"object": c.to_object("Col01_COL", mat), "role": "col"})

    def att(n, x, y=0.0, z=0.0):
        return lego.attach(n, (-x, z, y))
    atts = [att("ATT_" + s, x) for s, x in SLOTS.items()]
    atts += [att(n, SLOTS[s] + p[0], p[1], p[2]) for n, s, p, _ in FACES]

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[boards] LOD0 %d tris; dims_m %s" % (total, dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "a kit strip: every module is placed on its own by its code (ATT_<Slot> origins)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_RescueBoard...: the wiring code places each module by name",
            "LOD UV layout": "flat palette cells (one shared material): hand-made LODs drop studs and merge tiles, UVs "
                             "are not a unique unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
    }
