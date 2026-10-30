"""M_Prop_BuildStation: the foreman's build kiosk on the player's jetty head, Lego style (replaces the code-built
DockPieces.buildStation Parts; owner 2026-10-29: "This is ugly need to be redone in blender"). Round 2 (AD round 1
6/10: "a pile of small bricks, no hero shape"): one kiosk silhouette instead of scattered props.

Same footprint as the code station: a 16 x 12 stud studded light-grey baseplate with a yellow trim band (it must not
vanish into the pad's blue ring), origin the plate's ground centre, front -Y (Roblox -Z; the spawn / player side is +Y).
The plate bottom sinks 0.06 below the origin so it never shares the pad's top plane. Back half: a white booth (back
wall with a blueprint board, side walls, yellow-topped counter, yellow corner pillars) under a red studded roof with a
red / white striped awning and valance; a giant yellow hard hat sits on the roof as the kiosk's sign. Front half: the
build tablet on a lectern where the Parts tablet stood (x 0, y +3.6, centre 6.2 above the origin), a thick yellow
frame tilted 8 degrees back round a white recess; the game lays its `Tablet` Part (SurfaceGui: light panel, big build
icon) in that recess (ATT_Screen = recess centre, opening 7.4 x 4.2, face 0.25 behind the frame centre).

Layers (one palette mesh each, one draw call): L01_Plate, L02_Lectern, L03_Booth, L04_Roof. Collision = plain boxes
(_COL): plate, lectern foot + column, booth back wall, side walls, counter.

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
Z0 = -0.06                            # plate bottom: below the pad / deck top, never coplanar with it
TOP = PH
SINK = 0.04                           # things standing on a face start this far inside it (no coplanar caps)
TAB = (0.0, 3.6, 6.2)                 # tablet frame centre (the code station's Tablet spot)
TILT = 8.0                            # degrees back (top leans toward -Y)
FW, FH, FD, FB = 9.6, 6.4, 1.0, 0.18  # tablet frame: width, height, depth, front chamfer
OW, OH = 7.4, 4.2                     # screen opening (DockPieces' Tablet Part is 7.3 x 4.1 in it)
BX = 7.0                              # booth half width
BY0, BY1 = -5.6, -1.0                 # booth back / front
RZ = 10.2                             # roof slab underside + 0.3


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


def dome(b, cx, cy, z0, rings, c, n=12):
    """A closed solid of revolution through (height, radius) rings above z0 (hard hat)."""
    secs = [[(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), z0 + h)
             for i in range(n)] for h, r in rings]
    b.loft(secs, c)


def disc_y(b, cx, cy, cz, r, t, c, n=16):
    """A round disc facing +Y (badge), centre (cx, cy, cz), thickness t."""
    s0 = len(b.v)
    b.cyl(0, 0, -t / 2, t / 2, r, c, n)
    xform(b, s0, lambda x, y, z: (cx + x, cy + z, cz + y))


def stud(b, x, y, z, c, r=0.68, h=0.45, n=12):
    b.cyl(x, y, z - SINK, z + h, r, c, n)


def ring_frame(b, w, h, d, ow, oh, bev, c):
    """One closed rectangular picture frame round the origin, depth along Y (front +Y), front edges chamfered."""
    rings = [(w / 2, h / 2, -d / 2), (w / 2, h / 2, d / 2 - bev), (w / 2 - bev, h / 2 - bev, d / 2),
             (ow / 2 + bev, oh / 2 + bev, d / 2), (ow / 2, oh / 2, d / 2 - bev), (ow / 2, oh / 2, -d / 2)]
    verts = []
    for hx, hz, y in rings:
        verts += [(-hx, y, -hz), (hx, y, -hz), (hx, y, hz), (-hx, y, hz)]
    n = len(rings)
    faces = [(4 * i + k, 4 * i + (k + 1) % 4, 4 * ((i + 1) % n) + (k + 1) % 4, 4 * ((i + 1) % n) + k)
             for i in range(n) for k in range(4)]
    b._emit(verts, faces, c)


def slab_yz(b, x0, x1, p0, p1, off, thick, c, trim=0.0):
    """A slab along the (y, z) segment p0 -> p1, from `off` to `off + thick` along its upward normal, X from x0 to x1;
    `trim` shortens both ends (stripes laid on a slab never share its end faces)."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dy, dz)
    ty, tz = dy / L, dz / L
    ny, nz = -tz, ty
    if nz < 0:
        ny, nz = -ny, -nz
    a = (p0[0] + ty * trim, p0[1] + tz * trim)
    e = (p1[0] - ty * trim, p1[1] - tz * trim)
    prof = [(a[0] + ny * off, a[1] + nz * off), (e[0] + ny * off, e[1] + nz * off),
            (e[0] + ny * (off + thick), e[1] + nz * (off + thick)), (a[0] + ny * (off + thick), a[1] + nz * (off + thick))]
    b.prof_x(x0, x1, prof, c)


# ------------------------------------------------------------------ layers
def plate(b):
    b.box((-PW / 2, -PD / 2, Z0), (PW / 2, PD / 2, PH), P.LBG, bevel=0.3)
    b.box((-PW / 2 - 0.06, -PD / 2 - 0.06, 0.14), (PW / 2 + 0.06, PD / 2 + 0.06, 0.48), P.YELLOW, bevel=0.0)  # trim band
    # hazard strip along the open front edge: you step on here (6 chunky stripes either side of the lectern)
    for s in (-1, 1):
        for i in range(3):
            x0 = s * (4.0 + i * 1.3)
            b.box((x0, PD / 2 - 1.15, TOP - SINK), (x0 + s * 1.3, PD / 2 - 0.4, TOP + 0.12),
                  P.YELLOW if i % 2 == 0 else P.INK, bevel=0.03)
    for x in (-7, -5, -3, -1, 1, 3, 5, 7):
        for y in (0.0, 2.2, 4.0):
            if abs(x) < 4.6 and y > 1:
                continue
            if y > 3 and abs(x) > 3.5:                       # the hazard strip
                continue
            stud(b, x, y, TOP, P.LBG)


def lectern(b):
    y0 = TAB[1]
    b.box((-3.6, 2.0, TOP - SINK), (3.6, 4.8, 1.6), P.DBG, bevel=0.22)                  # foot
    for s in (-1, 1):
        stud(b, s * 2.5, 4.2, 1.6, P.DBG, 0.5, 0.4)
    b.box((-1.5, y0 - 0.7, 1.6 - SINK), (1.5, y0 + 0.7, 3.5), P.WHITE, bevel=0.12)      # column
    b.box((-1.62, y0 - 0.82, 2.3), (1.62, y0 + 0.82, 2.9), P.YELLOW, bevel=0.06)         # band
    for s in (-1, 1):                                                                    # back struts
        b.beam((s * 2.8, 2.5, 1.5), (s * 2.8, 2.8, 6.4), 0.8, 0.8, P.DBG)
    # tablet frame, built upright round the origin then moved to TAB and tilted
    s0 = len(b.v)
    ring_frame(b, FW, FH, FD, OW, OH, FB, P.YELLOW)
    b.box((-OW / 2 - 0.12, -0.45, -OH / 2 - 0.12), (OW / 2 + 0.12, -0.25, OH / 2 + 0.12), P.WHITE, bevel=0.0)  # recess
    b.box((-FW / 2 + 0.5, -FD / 2 - 0.45, -FH / 2 + 0.5), (FW / 2 - 0.5, -FD / 2 + 0.06, FH / 2 - 0.5), P.DBG,
          bevel=0.15)                                                                    # back shell
    for sx in (-3.0, 0, 3.0):
        stud(b, sx, -0.08, FH / 2, P.YELLOW, 0.62, 0.38)                                 # studs on the top edge
    xform(b, s0, lambda x, y, z: (x, y + TAB[1], z + TAB[2]))
    tilt(b, s0, TAB, TILT)


def booth(b):
    wz = RZ + 0.1
    b.box((-BX, BY0, TOP - SINK), (BX, BY0 + 1.0, wz), P.WHITE, bevel=0.12)             # back wall
    for s in (-1, 1):
        b.box((s * (BX - 1.0), BY0 + 0.9, TOP - SINK), (s * (BX - 0.08), BY1, RZ - 0.05), P.WHITE, bevel=0.1)
        b.box((s * (BX - 0.95), BY1 - 0.95, TOP - SINK), (s * (BX + 0.12), BY1 + 0.12, RZ), P.YELLOW, bevel=0.1)
    # red base course round the outside (back + sides) and two windows on the back, so no face is a blank wall
    b.box((-BX - 0.08, BY0 - 0.08, TOP - SINK), (BX + 0.08, BY0 + 0.6, 2.3), P.RED, bevel=0.06)
    for s in (-1, 1):
        b.box((s * (BX - 0.6), BY0 + 0.4, TOP - SINK), (s * (BX + 0.02), BY1 - 0.85, 2.3), P.RED, bevel=0.06)
        b.box((s * 2.2, BY0 - 0.08, 4.6), (s * 5.4, BY0 + 0.3, 7.8), P.WHITE, bevel=0.06)     # window frame
        b.box((s * 2.55, BY0 - 0.14, 4.95), (s * 5.05, BY0 + 0.2, 7.45), P.GLASS, bevel=0.0)  # pane
        b.box((s * 3.72, BY0 - 0.2, 4.95), (s * 3.88, BY0 + 0.2, 7.45), P.WHITE, bevel=0.0)   # mullion
        b.box((s * 2.0, BY0 - 0.3, 4.3), (s * 5.6, BY0 + 0.2, 4.7), P.YELLOW, bevel=0.04)    # sill
    # yellow band along each side wall (AD r2: from the side it read as a little house), into the back wall and pillar
    for s in (-1, 1):
        b.box((s * (BX - 0.3), BY0 + 0.5, 5.3), (s * (BX + 0.06), BY1 - 0.5, 6.5), P.YELLOW, bevel=0.08)
    # counter between the side walls, yellow top overhanging toward the tablet
    b.box((-(BX - 1.04), BY1 - 1.5, TOP - SINK), (BX - 1.04, BY1 - 0.12, 3.4), P.WHITE, bevel=0.1)
    b.box((-(BX - 0.98), BY1 - 1.7, 3.3), (BX - 0.98, BY1 + 0.25, 3.85), P.YELLOW, bevel=0.08)
    b.box((-(BX - 1.1), BY1 - 0.16, 1.0), (BX - 1.1, BY1 - 0.06, 3.2), P.RED, bevel=0.0)   # counter front panel
    # blueprint board on the back wall: navy frame, blue board, a white house glyph
    yb = BY0 + 1.0
    b.box((-4.6, yb - 0.1, 4.4), (4.6, yb + 0.12, 9.2), P.INK, bevel=0.06)
    b.box((-4.2, yb - 0.1, 4.8), (4.2, yb + 0.22, 8.8), P.BLUE, bevel=0.04)
    w = 0.42
    for p0, p1, dy in (((-1.6, 5.4), (1.6, 5.4), 0.32), ((-1.6, 5.4), (-1.6, 7.0), 0.36), ((1.6, 5.4), (1.6, 7.0), 0.36),
                       ((-2.2, 6.8), (0.0, 8.3), 0.4), ((2.2, 6.8), (0.0, 8.3), 0.44)):  # staggered: no shared faces
        b.beam((p0[0], yb + dy, p0[1]), (p1[0], yb + dy, p1[1]), w, w, P.WHITE)
    b.box((-0.45, yb + 0.16, 5.4), (0.45, yb + 0.4, 6.4), P.WHITE, bevel=0.03)         # door


def roof(b):
    y0, y1 = BY0 - 0.3, BY1 + 0.45
    b.box((-BX - 0.6, y0, RZ - 0.3), (BX + 0.6, y1, RZ + 0.7), P.RED, bevel=0.2)
    b.box((-BX - 0.66, y0 - 0.06, RZ - 0.18), (BX + 0.66, y1 + 0.06, RZ + 0.12), P.WHITE, bevel=0.0)  # fascia band
    cy = (y0 + y1) / 2
    for x in (-6.4, -4.4, 4.4, 6.4):
        for y in (y0 + 1.1, cy, y1 - 1.1):
            stud(b, x, y, RZ + 0.7, P.RED, 0.7, 0.45)
    # striped awning over the counter, valance flaps at its edge
    p0, p1 = (BY1 + 0.25, RZ - 0.15), (BY1 + 2.5, RZ - 1.45)
    ax = BX + 0.5
    slab_yz(b, -ax, ax, p0, p1, 0.0, 0.3, P.WHITE)
    n = 13
    for i in range(0, n, 2):
        xa = -ax + 0.06 + i * (2 * ax - 0.12) / n
        slab_yz(b, xa, xa + (2 * ax - 0.12) / n, p0, p1, 0.22, 0.16, P.RED, trim=0.06)
    vy, vz = p1
    b.box((-ax + 0.04, vy - 0.12, vz - 0.75), (ax - 0.04, vy + 0.0, vz + 0.05), P.WHITE, bevel=0.0)
    for i in range(0, n, 2):
        xa = -ax + 0.06 + i * (2 * ax - 0.12) / n
        b.box((xa, vy - 0.2, vz - 1.05), (xa + (2 * ax - 0.12) / n, vy + 0.1, vz + 0.02), P.RED, bevel=0.04)
    # the sign: a giant hard hat on a grey plinth
    hz = RZ + 0.7
    b.box((-2.2, cy - 2.0, hz - SINK), (2.2, cy + 2.0, hz + 0.5), P.DBG, bevel=0.12)
    bz = hz + 0.5 - SINK
    b.cyl(0, cy, bz, bz + 0.4, 3.1, P.YELLOW, 24)                                         # brim
    b.box((-2.0, cy + 2.3, bz + 0.05), (2.0, cy + 3.7, bz + 0.34), P.YELLOW, bevel=0.1)   # peak toward the player
    dz = bz + 0.4 - SINK
    dome(b, 0, cy, dz, [(0, 2.55), (0.9, 2.5), (1.7, 2.2), (2.35, 1.65), (2.75, 0.95), (2.9, 0.3)], P.YELLOW, 24)
    b.box((-0.35, cy - 1.9, dz + 2.1), (0.35, cy + 1.9, dz + 3.02), P.ORANGE, bevel=0.12)  # ridge
    # a white "+" on the hat front (AD r2: the red-in-white disc read as a cyclops eye)
    b.box((-0.24, cy + 1.9, dz + 0.45), (0.24, cy + 2.62, dz + 1.75), P.WHITE, bevel=0.06)
    b.box((-0.68, cy + 1.92, dz + 0.86), (0.68, cy + 2.58, dz + 1.34), P.WHITE, bevel=0.06)


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

    for name, fn in (("L01_Plate", plate), ("L02_Lectern", lectern), ("L03_Booth", booth), ("L04_Roof", roof)):
        b = lego.B()
        fn(b)
        out(name, b)

    cols = [((-PW / 2, -PD / 2, Z0), (PW / 2, PD / 2, PH)),
            ((-3.6, 2.0, PH), (3.6, 4.8, 1.6)),
            ((-1.5, TAB[1] - 0.7, 1.6), (1.5, TAB[1] + 0.7, 3.5)),
            ((-BX, BY0, PH), (BX, BY0 + 1.0, RZ)),
            ((-BX - 0.12, BY0 + 0.9, PH), (-(BX - 1.0), BY1 + 0.12, RZ)),
            ((BX - 1.0, BY0 + 0.9, PH), (BX + 0.12, BY1 + 0.12, RZ)),
            ((-(BX - 1.0), BY1 - 1.7, PH), (BX - 1.0, BY1 + 0.25, 3.85))]
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
        "size_note": "stylised Lego kiosk on a 16 x 12 stud plate; the hard-hat sign on its roof sets the height",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_Plate..., Col01_COL...: DockPieces.buildStation places the Model as one piece",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "tablet", "target": [0, 3.6, 6.2], "dist": 18, "az": -10, "el": 14},
            {"name": "booth", "target": [0, -3.0, 7], "dist": 24, "az": 25, "el": 18},
            {"name": "hat", "target": [0, -3.3, 13], "dist": 14, "az": -30, "el": 20},
        ],
    }
