"""M_Prop_BuildStation: the foreman's build kiosk on the player's jetty head, Lego style (replaces the code-built
DockPieces.buildStation Parts; owner 2026-10-29: "This is ugly need to be redone in blender").

Same footprint as the code station: a 16 x 12 stud studded blue baseplate (0.8 thick, bevelled edge), origin the
plate's ground centre, front -Y (Roblox -Z; the spawn / player side is +Y). The build tablet stands where the Parts
tablet stood (x 0, y +3.6, centre 6.2 above the plate bottom): a white lectern holds a yellow-bezelled frame tilted 8
degrees back with an empty dark recess; the game lays its `Tablet` Part (SurfaceGui, build icon) in that recess
(ATT_Screen = recess centre, 0.7 deep, opening 5.6 x 3.4). Left-back a lattice jib crane lowers a red brick onto a
small stack; right-back a red toolbox carries a yellow hard hat and loose bricks; low posts and rails close the back
and sides (front stays open to walk on); a red pennant flies from the back-right corner.

Layers (one palette mesh each, one draw call): L01_Plate, L02_Lectern, L03_Crane, L04_Props, L05_Rails. Collision =
plain boxes (_COL): plate, lectern foot + column, crane base, toolbox.

    python3 art/source/props/M_Prop_BuildStation/maketex.py --out build/prod/M_Prop_BuildStation/textures/M_Prop_BuildStation
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_BuildStation/build.py \
        --out-root build/prod/M_Prop_BuildStation --steps build,lod,validate,export,turntable
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

NAME = "M_Prop_BuildStation"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "BuildStation", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_BuildStation_Brick_ALB.png")

PW, PD, PH = 16.0, 12.0, 0.8          # plate studs: x, y, thick
TOP = PH
SINK = 0.04                           # things standing on a face start this far inside it (no coplanar caps)
TAB = (0.0, 3.6, 6.2)                 # tablet frame centre (the code station's Tablet spot)
TILT = 8.0                            # degrees back (top leans toward -Y)
CR = (-4.6, -2.8)                     # crane mast centre
JIB = 4.6                             # jib reach toward +X
TB = (2.4, -4.6, 6.8, -1.8)           # toolbox x0, y0, x1, y1


def patch_lod_names():
    """Layer meshes use plain names (L01_Plate...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ helpers
def xform(b, start, fn):
    """Apply fn(x, y, z) -> (x, y, z) to every vertex added since index `start`."""
    b.v[start:] = [fn(*p) for p in b.v[start:]]


def tilt(b, start, centre, deg):
    """Rotate the shells since `start` about the X axis through `centre` (+deg leans the top toward -Y)."""
    cy, cz = centre[1], centre[2]
    s, c = math.sin(math.radians(deg)), math.cos(math.radians(deg))
    xform(b, start, lambda x, y, z: (x, cy + (y - cy) * c - (z - cz) * s, cz + (y - cy) * s + (z - cz) * c))


def prof_y(b, y0, y1, profile, c):
    """A flat (x, z) profile extruded along Y (pennant)."""
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def dome(b, cx, cy, z0, rings, c, n=12):
    """A closed solid of revolution through (height, radius) rings above z0 (hard hat)."""
    secs = [[(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), z0 + h)
             for i in range(n)] for h, r in rings]
    b.loft(secs, c)


def stud(b, x, y, z, c, r=0.62, h=0.42, n=10):
    b.cyl(x, y, z - SINK, z + h, r, c, n)


def gstuds(b, x0, x1, y0, y1, z, c, nx, ny, r=0.62, h=0.42):
    for i in range(nx):
        for j in range(ny):
            stud(b, x0 + (i + 0.5) * (x1 - x0) / nx, y0 + (j + 0.5) * (y1 - y0) / ny, z, c, r, h)


def tower_braces(b, cx, cy, z0, z1, hw, c, w=0.2):
    """White X braces on the four faces of a square lattice mast (posts at +-hw), 3 bays."""
    zs = [z0 + (z1 - z0) * i / 3 for i in range(4)]
    for i in range(3):
        a, e = zs[i], zs[i + 1]
        for s in (-1, 1):
            b.beam((cx - hw, cy + s * hw, a), (cx + hw, cy + s * hw, e), w, w, c)
            b.beam((cx + hw, cy + s * hw, a), (cx - hw, cy + s * hw, e), w, w, c)
            b.beam((cx + s * hw, cy - hw, a), (cx + s * hw, cy + hw, e), w, w, c)
            b.beam((cx + s * hw, cy + hw, a), (cx + s * hw, cy - hw, e), w, w, c)


# ------------------------------------------------------------------ layers
def plate(b):
    b.box((-PW / 2, -PD / 2, 0), (PW / 2, PD / 2, PH), P.BLUE, bevel=0.32)
    # hazard strip along the open front edge: you step on here
    n = 8
    for i in range(n):
        x0 = -PW / 2 + 0.7 + i * (PW - 1.4) / n
        b.box((x0, PD / 2 - 1.05, TOP - SINK), (x0 + (PW - 1.4) / n, PD / 2 - 0.35, TOP + 0.1),
              P.YELLOW if i % 2 == 0 else P.INK, bevel=0.03)
    keep = [(-3.6, 1.9, 3.6, 5.4), (CR[0] - 2.2, CR[1] - 2.2, CR[0] + 2.2, CR[1] + 2.2),
            (TB[0] - 0.6, TB[1] - 0.6, TB[2] + 0.6, TB[3] + 0.6), (-0.6 + 0.9 - 2.4, -4.8, 3.6, -0.6)]
    for ix in range(8):
        for iy in range(6):
            x, y = -7 + 2 * ix, -5 + 2 * iy
            if y > 3.5 and abs(x) < 4:
                continue
            if y > 4.4:
                continue
            if any(a - 0.7 < x < c + 0.7 and d - 0.7 < y < e + 0.7 for a, d, c, e in keep):
                continue
            stud(b, x, y, TOP, P.BLUE, 0.68, 0.45)


def lectern(b):
    x0, y0 = 0.0, TAB[1]
    b.box((-3.2, 2.3, TOP - SINK), (3.2, 5.0, 1.5), P.DBG, bevel=0.2)                   # foot
    b.box((-1.3, y0 - 0.6, 1.5 - SINK), (1.3, y0 + 0.6, 3.9), P.WHITE, bevel=0.1)        # column
    b.box((-1.42, y0 - 0.72, 2.2), (1.42, y0 + 0.72, 2.9), P.YELLOW, bevel=0.06)         # band
    for s in (-1, 1):                                                                    # back struts
        b.beam((s * 2.6, 2.7, 1.5), (s * 2.6, y0 - 0.3, 4.6), 0.7, 0.7, P.DBG)
    b.box((-2.4, y0 - 0.55, 3.9 - SINK), (2.4, y0 + 0.55, 4.5), P.DBG, bevel=0.08)       # hinge block
    # tablet frame, built upright round the origin then tilted + moved to TAB
    s0 = len(b.v)
    w, h, d = 7.6, 5.4, 0.9
    ow, oh = 5.6, 3.4                                                                    # recess opening
    sw, sh = (w - ow) / 2, (h - oh) / 2
    b.box((-w / 2, -d / 2, -h / 2), (-ow / 2, d / 2, h / 2), P.YELLOW, bevel=0.1)        # bezel left
    b.box((ow / 2, -d / 2, -h / 2), (w / 2, d / 2, h / 2), P.YELLOW, bevel=0.1)          # right
    b.box((-ow / 2, -d / 2, -h / 2), (ow / 2, d / 2, -oh / 2), P.YELLOW, bevel=0.1)      # bottom
    b.box((-ow / 2, -d / 2, oh / 2), (ow / 2, d / 2, h / 2), P.YELLOW, bevel=0.1)        # top
    b.box((-ow / 2, -d / 2 + 0.05, -oh / 2), (ow / 2, -0.25, oh / 2), P.INK, bevel=0.0)  # recess floor (dark screen)
    b.box((-w / 2 + 0.3, -d / 2 - 0.5, -h / 2 + 0.3), (w / 2 - 0.3, -d / 2 + 0.05, h / 2 - 0.3), P.DBG, bevel=0.15)  # back
    for sx in (-2.4, 0, 2.4):
        stud(b, sx, 0, h / 2, P.YELLOW, 0.55, 0.3)                                       # studs on the top edge
    # these stand along local Z up; stud() builds along +Z, which is the frame's up: fine.
    tilt_pts = (0, TAB[1], TAB[2])
    xform(b, s0, lambda x, y, z: (x, y + TAB[1], z + TAB[2]))                            # frame local (x,y,z) -> world
    tilt(b, s0, tilt_pts, TILT)


def crane(b):
    cx, cy = CR
    b.box((cx - 2.0, cy - 2.0, TOP - SINK), (cx + 2.0, cy + 2.0, 1.6), P.DBG, bevel=0.15)       # base
    for sx in (-1, 1):
        for sy in (-1, 1):
            stud(b, cx + sx * 1.35, cy + sy * 1.35, 1.6, P.DBG, 0.4, 0.3, 8)
    b.cyl(cx, cy, 1.6 - SINK, 2.2, 1.25, P.ORANGE, 12)                                           # turntable
    hw = 0.62
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((cx + sx * hw - 0.2, cy + sy * hw - 0.2, 2.2 - SINK), (cx + sx * hw + 0.2, cy + sy * hw + 0.2, 8.8),
                  P.YELLOW, bevel=0.04)
    tower_braces(b, cx, cy, 2.2, 8.8, hw, P.WHITE)
    b.box((cx - 1.2, cy - 1.2, 8.8 - SINK), (cx + 1.2, cy + 1.2, 9.5), P.ORANGE, bevel=0.1)    # slewing head
    # cab on the -X side
    b.box((cx - 2.5, cy - 0.95, 8.8), (cx - 1.15, cy + 0.95, 10.3), P.WHITE, bevel=0.1)
    b.box((cx - 2.56, cy - 0.65, 9.25), (cx - 2.4, cy + 0.65, 10.0), P.INK, bevel=0.0)           # windscreen
    # jib: two chords + zigzag, counter-jib with weight
    zt, zb = 10.3, 9.5
    jx = cx + JIB
    b.beam((cx, cy, zt), (jx, cy, zt - 0.2), 0.45, 0.45, P.YELLOW)
    b.beam((cx, cy, zb), (jx, cy, zb), 0.45, 0.45, P.YELLOW)
    nseg = 6
    for i in range(nseg):
        x0, x1 = cx + 1.0 + i * (JIB - 1.0) / nseg, cx + 1.0 + (i + 1) * (JIB - 1.0) / nseg
        b.beam((x0, cy, zb if i % 2 == 0 else zt - 0.1), (x1, cy, zt - 0.1 if i % 2 == 0 else zb), 0.22, 0.28, P.WHITE)
    b.box((cx - 3.3, cy - 0.4, zb), (cx - 1.0, cy + 0.4, zt - 0.1), P.YELLOW, bevel=0.05)        # counter-jib
    b.box((cx - 3.4, cy - 0.7, zb - 0.3), (cx - 2.2, cy + 0.7, zt + 0.3), P.DBG, bevel=0.1)      # counterweight
    # A-frame + tie rods
    apex = (cx, cy, 11.9)
    for sy in (-1, 1):
        b.beam((cx, cy + sy * 0.95, 9.5), apex, 0.28, 0.28, P.YELLOW)
    b.box((cx - 0.3, cy - 0.3, 11.8), (cx + 0.3, cy + 0.3, 12.2), P.RED, bevel=0.05)             # beacon
    b.beam(apex, (jx - 0.1, cy, zt - 0.2), 0.12, 0.12, P.BLACK)
    b.beam(apex, (cx - 3.0, cy, zt), 0.12, 0.12, P.BLACK)
    # trolley, fall, hook block, sling, brick
    b.box((jx - 0.6, cy - 0.6, zb - 0.5), (jx + 0.6, cy + 0.6, zb + 0.1), P.RED, bevel=0.06)
    bz = 3.9
    b.box((jx - 0.07, cy - 0.07, bz + 1.6), (jx + 0.07, cy + 0.07, zb - 0.5), P.BLACK, bevel=0.0)  # fall
    b.box((jx - 0.5, cy - 0.4, bz + 1.1), (jx + 0.5, cy + 0.4, bz + 1.7), P.YELLOW, bevel=0.05)  # hook block
    b.box((jx - 0.11, cy - 0.11, bz + 0.7), (jx + 0.11, cy + 0.11, bz + 1.15), P.DBG, bevel=0.0)  # shank
    for sx in (-1, 1):
        b.beam((jx, cy, bz + 0.9), (jx + sx * 1.35, cy, bz + 0.12), 0.1, 0.1, P.BLACK)            # sling legs
    lego.brick(b, jx, cy, bz - 1.2, w=3.6, d=1.8, h=1.3, colour=P.RED)                           # hanging brick
    b.box((jx - 1.55, cy - 0.08, bz + 0.06), (jx - 1.25, cy + 0.08, bz + 0.18), P.DBG, bevel=0.0) # sling eyes
    b.box((jx + 1.25, cy - 0.08, bz + 0.06), (jx + 1.55, cy + 0.08, bz + 0.18), P.DBG, bevel=0.0)
    # the stack waiting below
    lego.brick(b, jx, cy, TOP - SINK, w=3.4, d=2.2, h=1.2, colour=P.YELLOW)
    lego.brick(b, jx - 0.4, cy, TOP + 1.2 - SINK, w=2.2, d=2.2, h=1.2, colour=P.WHITE)


def props(b):
    x0, y0, x1, y1 = TB
    zt = 2.5
    b.box((x0, y0, TOP - SINK), (x1, y1, zt), P.RED, bevel=0.12)                                # toolbox body
    b.box((x0 - 0.1, y0 - 0.1, zt - SINK), (x1 + 0.1, y1 + 0.1, zt + 0.5), P.WHITE, bevel=0.1)   # lid
    for lx in (x0 + 1.0, x1 - 1.0):                                                            # latches
        b.box((lx - 0.4, y1 + 0.08, 1.7), (lx + 0.4, y1 + 0.3, 2.9), P.DBG, bevel=0.03)
    cxm = (x0 + x1) / 2
    for hx in (cxm - 0.8, cxm + 0.8):                                                          # handle on the back
        b.box((hx - 0.15, y0 - 0.5, zt + 0.1), (hx + 0.15, y0 - 0.1, zt + 0.9), P.DBG, bevel=0.0)
    b.box((cxm - 0.95, y0 - 0.5, zt + 0.7), (cxm + 0.95, y0 - 0.1, zt + 0.95), P.DBG, bevel=0.0)
    lz = zt + 0.5
    hx, hy = x0 + 1.5, (y0 + y1) / 2
    b.cyl(hx, hy, lz - SINK, lz + 0.18, 1.75, P.ORANGE, 14)                                    # brim
    b.box((hx - 1.0, hy + 1.2, lz - SINK), (hx + 1.0, hy + 1.65, lz + 0.18), P.ORANGE, bevel=0.05)  # peak
    dome(b, hx, hy, lz + 0.18 - SINK, [(0, 1.4), (0.5, 1.35), (0.95, 1.05), (1.25, 0.55), (1.35, 0.2)], P.YELLOW, 14)
    b.box((hx - 0.2, hy - 1.0, lz + 1.0), (hx + 0.2, hy + 1.0, lz + 1.5), P.ORANGE, bevel=0.05)   # ridge strip
    lego.brick(b, x1 - 1.2, hy - 0.5, lz - SINK, w=2.4, d=1.6, h=1.0, colour=P.BLUE)
    lego.brick(b, x1 - 1.2, hy - 0.5, lz + 1.0 - SINK, w=1.6, d=1.6, h=1.0, colour=P.ORANGE)
    lego.brick(b, x1 - 3.0, hy + 0.5, lz - SINK, w=1.8, d=1.8, h=1.0, colour=P.WHITE)
    # loose bricks on the plate, one tipped by the toolbox, one by the lectern
    lego.brick(b, 1.0, -0.3, TOP - SINK, w=2.4, d=1.6, h=1.0, colour=P.ORANGE)
    lego.brick(b, 5.2, 1.0, TOP - SINK, w=1.8, d=1.8, h=1.0, colour=P.RED)
    # cone near the crane
    n = 12
    b.box((-7.0, 1.2, TOP - SINK), (-5.4, 2.8, TOP + 0.2), P.ORANGE, bevel=0.04)
    dome(b, -6.2, 2.0, TOP + 0.2 - SINK, [(0, 0.62), (1.2, 0.34), (2.0, 0.2)], P.ORANGE, n)
    b.cyl(-6.2, 2.0, TOP + 1.0, TOP + 1.35, 0.46, P.WHITE, n)


def rails(b):
    post_pts = [(x, -5.4) for x in (-7.2, -3.6, 0.0, 3.6, 7.2)] + [(-7.2, y) for y in (-1.8, 1.8)] + \
               [(7.2, y) for y in (-1.8, 1.8)]
    for x, y in post_pts:
        b.cyl(x, y, TOP - SINK, 2.9, 0.34, P.YELLOW, 10)
        b.cyl(x, y, 1.5, 1.95, 0.4, P.INK, 10)
        b.cyl(x, y, 2.9 - SINK, 3.1, 0.42, P.YELLOW, 10)

    def rail(p0, p1, z, c):
        b.beam((p0[0], p0[1], z), (p1[0], p1[1], z), 0.3, 0.3, c)

    back = [(x, -5.4) for x in (-7.2, -3.6, 0.0, 3.6, 7.2)]
    for a, e in zip(back, back[1:]):
        rail(a, e, 2.55, P.WHITE)
        rail(a, e, 1.7, P.RED)
    for sx in (-7.2, 7.2):
        pts = [(sx, -5.4), (sx, -1.8), (sx, 1.8)]
        for a, e in zip(pts, pts[1:]):
            rail(a, e, 2.55, P.WHITE)
            rail(a, e, 1.7, P.RED)
    # front corner bollards (open between them)
    for sx in (-7.2, 7.2):
        lego_bollard(b, sx, 5.2)
    # pennant pole at the back-right corner post
    px, py = 7.2, -5.4
    b.cyl(px, py, 3.1 - SINK, 12.6, 0.2, P.WHITE, 8)
    b.cyl(px, py, 12.6 - SINK, 13.0, 0.42, P.YELLOW, 8)
    for z0, z1 in ((8.6, 9.0), (10.8, 11.2)):
        b.cyl(px, py, z0, z1, 0.3, P.DBG, 8)
    top = 12.3
    red = [(px - 0.2, top), (px - 2.4, top - 0.2), (px - 4.6, top - 0.9), (px - 3.2, top - 1.2),
           (px - 4.6, top - 1.6), (px - 2.4, top - 1.9), (px - 0.2, top - 2.1)]
    prof_y(b, py - 0.1, py + 0.1, red, P.RED)
    stripe = [(px - 0.5, top - 0.7), (px - 3.0, top - 0.8), (px - 3.6, top - 1.0), (px - 3.0, top - 1.3),
              (px - 0.5, top - 1.4)]
    prof_y(b, py - 0.13, py + 0.13, stripe, P.WHITE)


def lego_bollard(b, x, y):
    b.cyl(x, y, TOP - SINK, 1.9, 0.62, P.YELLOW, 10)
    b.cyl(x, y, 1.2, 1.55, 0.74, P.INK, 10)
    b.cyl(x, y, 1.9 - SINK, 2.1, 0.74, P.YELLOW, 10)
    stud(b, x, y, 2.1, P.YELLOW, 0.34, 0.25, 8)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_BuildStation_Brick", ALB)
    meshes = []

    def out(name, b):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[station] %-18s %5d tris" % (name, b.tris()))

    for name, fn in (("L01_Plate", plate), ("L02_Lectern", lectern), ("L03_Crane", crane), ("L04_Props", props),
                     ("L05_Rails", rails)):
        b = lego.B()
        fn(b)
        out(name, b)

    cols = [((-PW / 2, -PD / 2, 0), (PW / 2, PD / 2, PH)),
            ((-3.2, 2.3, PH), (3.2, 5.0, 1.5)),
            ((-1.3, TAB[1] - 0.6, 1.5), (1.3, TAB[1] + 0.6, 3.9)),
            ((CR[0] - 2.0, CR[1] - 2.0, PH), (CR[0] + 2.0, CR[1] + 2.0, 1.6)),
            ((TB[0], TB[1], PH), (TB[2], TB[3], 2.5))]
    for k, (lo, hi) in enumerate(cols):
        c = lego.B()
        c.box(lo, hi, P.DBG, bevel=0)
        out("Col%02d_COL" % (k + 1), c)

    atts = [lego.attach("ATT_Screen", TAB)]

    pts = []
    for e in meshes:
        if e["role"] == "visual":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[station] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[station] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "stylised Lego kiosk on a 16 x 12 stud plate; flag pole and crane above it set the height",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Plate..., Col01_COL...: DockPieces.buildStation places the Model as one piece",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "tablet", "target": [0, 3.6, 6.2], "dist": 16, "az": -10, "el": 14},
            {"name": "crane", "target": [CR[0] + 2, CR[1], 8], "dist": 22, "az": 35, "el": 16},
            {"name": "toolbox", "target": [4.6, -3.2, 3], "dist": 14, "az": -35, "el": 20},
        ],
    }
