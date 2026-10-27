"""M_Bld_BoathouseAddons: the Boathouse's Lv3 quick-launch bay, Lego style (docs/25; docs/05 2.2, 3).

The code boathouse (`boathouse()` in src/shared/DockPieces.luau) is a shed at 1.2 scale whose doors face the cove
(island +right). Lv2 is the code lifeboat slip (`lifeboatSlip()`, island fwd 112). This asset adds only the Lv3 bay,
authored in the boathouse's local frame: ground z 0 (the plate top), origin the boathouse ground centre, final scale.
Game frame: right = -80 - y, fwd = 58 + x (the export flips Blender X); the sea is +x, the plaza -x, the cove -Y.
The bay lies along the cove quay (y -35..-47 over the water, x -27..30) because the Harbour pontoon (right -32..-24,
fwd 60..140) closes the cove beyond y -48; the ramp runs out toward the sea along the channel.

Lv3 (engine: the boathouse launches a lifeboat quickly): a 57 x 12 stud timber deck on thick 2x2 columns with yellow
X braces and a studded yellow rim, a short studded kerb on the plate edge, a navy ready room (walk-in door on the sea
side, big life ring on the quay-facing wall) and a yellow winch whose cable hooks a yellow trolley at the top of the
slipway carrying an orange-and-white Lego lifeboat, tilted bow-down to the sea. Three stepped red Lego gable roofs
(ends eave 13.5 / ridge 18.5, middle 15 / 20.5) with white fascia bands on 12 thick columns cover the deck and run out
over the ramp head; a big green go lamp (lenses both ways) in a studded yellow housing tops a white-and-red mast on the
sea-end ridge. The stone slipway runs on to below the water (x 30..52). The static lifeboat is its own mesh
(Lv3_L07_Lifeboat) so code can hide it while a spawned boat launches from ATT_Launch.

Layers: L01_Deck, L02_QuayEdge (the kerb), L03_Ramp, L04_Roof, L05_ReadyRoom, L06_Launch, L07_Lifeboat (one palette
mesh each, flat colours via UVs, one draw call per layer). Collision: one simple box per object, Lv3_ColNN_COL, so the deck, ramp and
walk-in room stay open. Attachments: ATT_Launch (ramp), ATT_Work_Winch (behind the winch), ATT_ReadyRoom.

    python3 art/source/buildings/M_Bld_BoathouseAddons/maketex.py \
        --out build/prod/M_Bld_BoathouseAddons/textures/M_Bld_BoathouseAddons \
        --name Boathouse --set Brick
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- \
        --build art/source/buildings/M_Bld_BoathouseAddons/build.py \
        --out-root build/prod/M_Bld_BoathouseAddons --steps build,lod,validate,export,turntable
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

NAME = "M_Bld_BoathouseAddons"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "Boathouse", "Brick"
TEX = os.path.join(G, "build/prod", NAME, "textures", NAME)
ALB = os.path.join(TEX, "T_Boathouse_Brick_ALB.png")

WATER, DECK = -4.0, 0.55
# Game frame: right = -80 - y, fwd = 58 + x (Boathouse spot isle(-80, 58, -90); Blender X flips on export). Sea = +x.
BAY = (-27.0, 30.0, -35.0, -47.0)            # deck x0 (plaza end), x1 (sea end), y0 (quay side), y1 (water side)
YC = -41.0                                   # the bay's centre line (ridge, ramp, winch)
KERB = (-25.0, 28.0)                         # studded kerb on the plate edge, x0..x1
ROOM = (-24.5, -14.5, -46.0, -36.0)          # x0 (back), x1 (door, sea side), y0 (water side), y1 (quay side)
DOOR = (-43.7, -38.3)                        # door gap on the east wall, y0..y1
RAMP = (30.0, 52.0, -36.5, -45.5)            # x head (deck end), x water end, y quay side, y water side
RAILS = (-38.5, -43.5)
CRADLE = (1.0, 12.0)                         # trolley s0 (winch end) .. s1 (sea end), along the slope from the head
ROOF_X0, ROOF_X1 = -27.6, 33.0               # runs out over the ramp head
ROOF_Y0, ROOF_Y1 = -34.6, -47.4
ROOF_N = 4
# three stepped roof sections (x0, x1, eave, ridge): a taller middle; they overlap 0.5 so no end faces coincide
ROOF = ((ROOF_X0, -6.5, 13.5, 18.5), (-7.0, 18.0, 15.0, 20.5), (17.5, ROOF_X1, 13.5, 18.5))
MAST_X, LAMP_Z = 31.0, 26.0                  # go-lamp mast on the sea-end ridge, lamp centre height
POST_X = (-26.4, -12.5, 1.0, 12.5, 23.0, 32.0)
SLOPE = math.atan2(DECK + 4.2, RAMP[1] - RAMP[0])   # the ramp's pitch (down toward the sea)
POST_Y = (-36.0, -46.0)
WINCH = (10.0, -41.0)


def patch_lod_names():
    """Layer meshes use game node names (Lv3_L01_...), not M_<Cat>_ names: keep the lod step working."""
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


# ------------------------------------------------------------------ small helpers
def grid_studs(b, x0, x1, y0, y1, z, c, nx=2, ny=6, r=0.42, h=0.24, n=8):
    for i in range(nx):
        for j in range(ny):
            b.cyl(x0 + (i + 0.5) * (x1 - x0) / nx, y0 + (j + 0.5) * (y1 - y0) / ny,
                  z, z + h, r, c, n, bottom=False)


def planks(b, x0, x1, y0, y1, z, along_y=True, pitch=1.02, run=4.40):
    """Tan deck planks: dark seam lines between the boards and staggered butt joints, flat on the deck top."""
    a0, a1, c0, c1 = (x0, x1, y0, y1) if along_y else (y0, y1, x0, x1)    # across the boards, along them

    def seam(p0, q0, p1, q1):
        lo, hi = ((p0, q0, z), (p1, q1, z + 0.03)) if along_y else ((q0, p0, z), (q1, p1, z + 0.03))
        b.box(lo, hi, P.DTAN, bevel=0.01)

    n = max(1, round((a1 - a0) / pitch))
    w = (a1 - a0) / n
    for i in range(1, n):
        seam(a0 + i * w - 0.03, c0, a0 + i * w + 0.03, c1)
    for i in range(n):
        y = c0 + (i * 1.7) % run
        while y < c1 - 0.2:
            if y > c0 + 0.2:
                seam(a0 + i * w + 0.03, y - 0.03, a0 + (i + 1) * w - 0.03, y + 0.03)
            y += run


def disc_y(b, cx, cy, cz, r, length, c, n=10):
    """A closed cylinder along Y (go-light lens)."""
    y0, y1 = cy - length / 2, cy + length / 2
    ring = [(cx + r * math.cos(2 * math.pi * i / n), cz + r * math.sin(2 * math.pi * i / n)) for i in range(n)]
    a = [(x, y0, z) for x, z in ring]
    d = [(x, y1, z) for x, z in ring]
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(reversed(range(n))))
    faces.append(tuple(range(n, 2 * n)))
    b._emit(a + d, faces, c)


def torus_y(b, cx, cy, cz, R, r, c, maj=10, mnr=4):
    """A ring around the Y axis (the white rim on the go light)."""
    verts = []
    for i in range(maj):
        u = 2 * math.pi * i / maj
        for j in range(mnr):
            v = 2 * math.pi * j / mnr
            verts.append((cx + (R + r * math.cos(v)) * math.cos(u), cy + r * math.sin(v),
                          cz + (R + r * math.cos(v)) * math.sin(u)))
    faces = []
    for i in range(maj):
        for j in range(mnr):
            a, b2 = i * mnr, ((i + 1) % maj) * mnr
            k = (j + 1) % mnr
            faces.append((a + j, b2 + j, b2 + k, a + k))
    b._emit(verts, faces, c)


def rope(b, p0, p1, sag, c=P.BLACK, n=3, w=0.09):
    """A slack line between two points (short beams, lowest in the middle)."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t,
                    p0[2] + (p1[2] - p0[2]) * t - sag * math.sin(math.pi * t)))
    for a, b2 in zip(pts, pts[1:]):
        b.beam(a, b2, w, w, c)


def z_ramp(x):
    """Ramp top height at x (flat DECK to the head x RAMP[0], then down to -4.2 at the water end x RAMP[1])."""
    if x <= RAMP[0]:
        return DECK
    return DECK + (x - RAMP[0]) * ((-4.2 - DECK) / (RAMP[1] - RAMP[0]))


def eave(x):
    """Eave height of the roof section over x (columns stop under it)."""
    return next(e for x0, x1, e, _ in ROOF if x0 <= x <= x1)


def tilt(src, dst):
    """Copy a builder made flat (x = RAMP head + distance along the slope, z = height above the ramp) onto the
    slope: rotate about the ramp head (x RAMP[0], z DECK) by the ramp pitch."""
    c, s = math.cos(SLOPE), math.sin(SLOPE)
    base = len(dst.v)
    for x, y, z in src.v:
        dx, dz = x - RAMP[0], z
        dst.v.append((RAMP[0] + dx * c + dz * s, y, DECK - dx * s + dz * c))
    dst.f.extend((tuple(base + i for i in f), cell) for f, cell in src.f)


def prism_y(b, y0, y1, prof, c):
    """A closed (x, z) profile extruded along Y (the ramp wedge)."""
    n = len(prof)
    verts = [(x, y0, z) for x, z in prof] + [(x, y1, z) for x, z in prof]
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    b._emit(verts, faces, c)


def column(b, x, y, z0, z1, cap=P.RED, collar=P.YELLOW, w=1.0):
    """A thick 2x2 Lego column: stone shaft, coloured cap under the beam, yellow collar at the foot."""
    b.box((x - w, y - w, z0), (x + w, y + w, z1), P.STONE, bevel=0.08)
    b.box((x - w - 0.3, y - w - 0.3, z1 - 0.6), (x + w + 0.3, y + w + 0.3, z1), cap, bevel=0.06)
    b.box((x - w - 0.25, y - w - 0.25, z0), (x + w + 0.25, y + w + 0.25, z0 + 0.9), collar, bevel=0.05)


# ------------------------------------------------------------------ L01 deck
def lv3_deck(b):
    """Timber deck on thick 2x2 columns with yellow X braces, a studded yellow rim round the water edges."""
    x0, x1, y0, y1 = BAY
    b.box((x0, y1, 0.15), (x1, y0, DECK - 0.15), P.DBG, bevel=0.05)
    b.box((x0, y1, DECK - 0.15), (x1, y0, DECK), P.TAN, bevel=0.06)
    planks(b, x0 + 0.15, x1 - 0.15, y1 + 0.15, y0 - 0.15, DECK + 0.005, along_y=False, pitch=1.15, run=9.0)
    r = 0.7                                                                      # studded rim: water edge + east end
    for lo, hi in (((x0, y1, DECK), (x1, y1 + r, DECK + 0.4)), ((x1 - r, y1, DECK), (x1, y0, DECK + 0.4)),
                   ((x0, y0 - 1.5, DECK), (x0 + r, y0, DECK + 0.4)), ((x0, y1, DECK), (x0 + r, y1 + 1.5, DECK + 0.4))):
        b.box(lo, hi, P.YELLOW, bevel=0.03)
    b.stud_row(x0 + 1.0, y1 + r / 2, x1 - 1.0, y1 + r / 2, DECK + 0.4, P.YELLOW, spacing=2.2, r=0.27, h=0.16, n=6)
    b.stud_row(x1 - r / 2, y1 + 1.4, x1 - r / 2, y0 - 1.4, DECK + 0.4, P.YELLOW, spacing=2.2, r=0.27, h=0.16, n=6)
    far = [(x, y1 + 1.2) for x in (-26, -14, -2, 10, 22, 29)]
    mid = [(x, -39.0) for x in (-26, -2, 22)]
    for x, y in far + mid:
        column(b, x, y, WATER - 0.6, 0.15)
    for (xa, y), (xb, _) in zip(far, far[1:]):                                   # yellow X braces on the water row
        b.beam((xa, y, WATER + 1.0), (xb, y, -0.9), 0.5, 0.5, P.YELLOW)
        b.beam((xa, y, -0.9), (xb, y, WATER + 1.0), 0.5, 0.5, P.YELLOW)


# ------------------------------------------------------------------ L02 quay kerb
def lv3_quay(b):
    """A short raised studded kerb tied to the bay on the plate edge, with red end blocks."""
    x0, x1 = KERB
    b.box((x0, -35.0, 0.0), (x1, -33.8, 0.5), P.STONE, bevel=0.06)
    b.stud_row(x0 + 1.5, -34.4, x1 - 1.5, -34.4, 0.5, P.STONE, spacing=2.4, r=0.42, h=0.2, n=6)
    for x in (x0, x1):
        b.box((x - 1.0, -35.0, 0.0), (x + 1.0, -33.0, 1.3), P.RED, bevel=0.06)
        b.box((x - 1.0, -35.0, 1.3), (x + 1.0, -33.0, 1.5), P.YELLOW, bevel=0.04)
        b.cyl(x, -34.0, 1.5, 1.7, 0.42, P.YELLOW, 6)


# ------------------------------------------------------------------ L03 ramp
def lv3_ramp(b):
    """The slipway: stone wedge from the deck head down below the water, dark rails, stone curbs, yellow handrails."""
    xh, xw, ya, yb = RAMP
    prism_y(b, yb, ya, [(xh, DECK), (xw, -4.2), (xw, -4.8), (xh, 0.15)], P.STONE)
    for y in RAILS:
        b.beam((xh - 9.0, y, DECK + 0.08), (xw - 0.4, y, -4.10), 0.6, 0.22, P.DBG)
    for y in (ya - 0.35, yb + 0.35):
        b.beam((xh, y, DECK + 0.15), (xw - 0.3, y, -4.05), 0.7, 0.5, P.STONE)
    for y in (ya - 0.1, yb + 0.1):
        for x in (xh + 4.0, xh + 9.0, xh + 14.0, xh + 19.0):
            z = z_ramp(x)
            b.box((x - 0.12, y - 0.12, z + 0.3), (x + 0.12, y + 0.12, z + 2.7), P.DBG, bevel=0.02)
        b.beam((xh + 3.5, y, z_ramp(xh + 3.5) + 2.75), (xh + 19.5, y, z_ramp(xh + 19.5) + 2.75), 0.24, 0.24, P.YELLOW)
        b.beam((xh + 3.5, y, z_ramp(xh + 3.5) + 1.65), (xh + 19.5, y, z_ramp(xh + 19.5) + 1.65), 0.18, 0.18, P.DBG)


# ------------------------------------------------------------------ L04 roof
def lv3_roof(b):
    """Thick 2x2 columns with red caps and yellow braces under three stepped red Lego gable roofs (ridges along X, the
    middle one taller), each with a white fascia band round its eaves and gable feet."""
    for x in POST_X:
        z0 = DECK if x <= BAY[1] else WATER - 0.6
        ez = eave(x)
        for y in POST_Y:
            column(b, x, y, z0, ez)
            for s in (-1, 1):
                if POST_X[0] <= x + s * 2.6 <= POST_X[-1]:
                    b.beam((x, y, ez - 3.4), (x + s * 2.6, y, ez - 0.5), 0.34, 0.36, P.YELLOW)
    for x0, x1, ez, rz in ROOF:
        for y0 in (ROOF_Y0, ROOF_Y1):
            dy = (YC - y0) / ROOF_N
            for i in range(ROOF_N):
                ya = y0 + i * dy
                zt = ez + (i + 1) * (rz - ez) / ROOF_N
                c = P.RED if i % 2 == 0 else P.RRED
                b.box((x0, min(ya, ya + dy) - 0.01, ez), (x1, max(ya, ya + dy) + 0.01, zt), c, bevel=0.05)
                b.stud_row(x0 + 1.5, ya + dy / 2, x1 - 1.5, ya + dy / 2, zt, c, spacing=5.0, r=0.42, h=0.2, n=6)
        b.box((x0 - 0.15, YC - 0.55, rz), (x1 + 0.15, YC + 0.55, rz + 0.45), P.RED, bevel=0.06)
        b.stud_row(x0 + 1.5, YC, x1 - 1.5, YC, rz + 0.45, P.RED, spacing=5.0, r=0.3, h=0.18, n=6)
        fz0, fz1 = ez - 0.7, ez + 0.9                                            # white fascia ring, up the first course
        b.box((x0 - 0.1, ROOF_Y0 - 0.6, fz0), (x1 + 0.1, ROOF_Y0 + 0.15, fz1), P.WHITE, bevel=0.04)
        b.box((x0 - 0.1, ROOF_Y1 - 0.15, fz0), (x1 + 0.1, ROOF_Y1 + 0.6, fz1), P.WHITE, bevel=0.04)
        for x in (x0 - 0.1, x1 - 0.5):
            b.box((x, ROOF_Y1 + 0.6, fz0), (x + 0.6, ROOF_Y0 - 0.6, fz1), P.WHITE, bevel=0.04)


# ------------------------------------------------------------------ L05 ready room
def wall(b, x0, y0, x1, y1, z0=DECK, z1=6.5):
    """A navy wall with a red base band, a white trim line and a red top band."""
    b.box((x0, y0, z0), (x1, y1, z0 + 1.00), P.RED, bevel=0.04)
    b.box((x0, y0, z0 + 1.00), (x1, y1, z1 - 0.80), P.INK, bevel=0.04)
    b.box((x0, y0, z1 - 0.80), (x1, y1, z1 - 0.65), P.WHITE, bevel=0.02)
    b.box((x0, y0, z1 - 0.65), (x1, y1, z1), P.RED, bevel=0.04)


def jacket(b, x, y, z):
    """One orange life jacket hanging on the quay-side wall (front faces -Y), white bands and a dark zip."""
    b.box((x - 0.70, y - 0.42, z), (x + 0.70, y, z + 1.90), P.ORANGE, bevel=0.05)
    b.box((x - 0.55, y - 0.48, z + 1.90), (x + 0.55, y, z + 2.15), P.ORANGE, bevel=0.04)
    for zz in (0.45, 1.25):
        b.box((x - 0.70, y - 0.46, z + zz), (x + 0.70, y - 0.38, z + zz + 0.25), P.WHITE, bevel=0.01)
    b.box((x - 0.07, y - 0.48, z + 0.20), (x + 0.07, y - 0.40, z + 1.85), P.DBG, bevel=0.02)
    b.box((x - 0.11, y - 0.12, z + 2.15), (x + 0.11, y + 0.06, z + 2.35), P.DBG, bevel=0.02)


def lv3_room(b):
    """Navy ready room under the roof: banded walls, walk-in door on the sea side, bench, four jackets; a big life
    ring on the quay-facing wall for the walkway."""
    x0, x1, y0, y1 = ROOM                                  # y0 water side, y1 quay side
    d0, d1 = DOOR
    wall(b, x0, y0, x1, y0 + 0.90)                         # water side
    wall(b, x0, y1 - 0.90, x1, y1)                         # quay side
    wall(b, x0, y0 + 0.90, x0 + 0.90, y1 - 0.90)           # west (back)
    wall(b, x1 - 0.90, y0 + 0.90, x1, d0)                  # door wall stubs
    wall(b, x1 - 0.90, d1, x1, y1 - 0.90)
    b.box((x1 - 0.90, d0, 5.50), (x1, d1, 6.50), P.RED, bevel=0.04)                   # door header
    b.box((x0 - 0.35, y0 - 0.35, 6.50), (x1 + 0.35, y1 + 0.35, 6.90), P.RED, bevel=0.06)
    b.box((x1 - 2.20, d0 + 0.20, DECK), (x1 + 2.00, d1 - 0.20, DECK + 0.05), P.DBG, bevel=0.02)   # mat
    for ya, yb in ((d0 - 0.20, d0), (d1, d1 + 0.20)):                                   # yellow door frame
        b.box((x1, ya, DECK), (x1 + 0.14, yb, 5.50), P.YELLOW, bevel=0.02)
    b.box((x1, d0 - 0.20, 5.50), (x1 + 0.14, d1 + 0.20, 5.80), P.YELLOW, bevel=0.02)
    for x in (-23.0, -21.0, -19.0, -17.0, -15.4):                                       # panel seams, outer faces
        b.box((x - 0.03, y0 - 0.06, 1.55), (x + 0.03, y0, 5.70), P.DBG, bevel=0.01)
    for x in (-23.0, -21.0, -15.4):
        b.box((x - 0.03, y1, 1.55), (x + 0.03, y1 + 0.06, 5.70), P.DBG, bevel=0.01)
    # bench along the west wall: navy frame, orange slat seat and back
    bx0, bx1, by0, by1 = x0 + 0.90, x0 + 2.70, -44.3, -38.0
    for y in (by0 + 0.20, by1 - 0.50):
        b.box((bx0, y, DECK), (bx1, y + 0.30, 2.40), P.INK, bevel=0.02)
    b.box((bx0, by0, 2.40), (bx1, by1, 2.65), P.INK, bevel=0.04)
    slat = (by1 - by0 - 0.20) / 3
    for i in range(3):
        b.box((bx0, by0 + i * (slat + 0.10), 2.65), (bx1, by0 + i * (slat + 0.10) + slat, 2.80),
              P.ORANGE, bevel=0.03)
    for y in (by0 + 0.20, by1 - 0.50):
        b.box((bx0, y, 2.80), (bx0 + 0.25, y + 0.30, 4.60), P.INK, bevel=0.02)
    for z in (3.35, 4.05):
        b.box((bx0, by0 + 0.10, z), (bx0 + 0.22, by1 - 0.10, z + 0.30), P.ORANGE, bevel=0.03)
    for x in (-22.4, -20.6, -18.8, -17.0):
        jacket(b, x, y1 - 0.90, 2.70)
    # life ring on the quay-facing wall: yellow board, navy inset, white ring with four red bands
    cx, cz = -19.5, 3.8
    b.box((cx - 2.7, y1, cz - 2.6), (cx + 2.7, y1 + 0.20, cz + 2.6), P.YELLOW, bevel=0.04)
    b.box((cx - 2.3, y1 + 0.20, cz - 2.2), (cx + 2.3, y1 + 0.30, cz + 2.2), P.INK, bevel=0.03)
    torus_y(b, cx, y1 + 0.62, cz, 1.60, 0.38, P.WHITE, 14, 4)
    for dx, dz in ((1.6, 0), (-1.6, 0), (0, 1.6), (0, -1.6)):
        b.box((cx + dx - 0.45, y1 + 0.30, cz + dz - 0.45), (cx + dx + 0.45, y1 + 0.95, cz + dz + 0.45), P.RED, bevel=0.04)


# ------------------------------------------------------------------ L06 launch
def lv3_winch(b):
    """Yellow winch (drum along Y, cable leaves toward the ramp): studded base, side plates, red motor and lever."""
    x, y = WINCH
    b.box((x - 1.60, y - 1.80, DECK), (x + 1.60, y + 1.80, DECK + 0.45), P.YELLOW, bevel=0.05)
    grid_studs(b, x - 1.40, x + 1.40, y - 1.60, y + 1.60, DECK + 0.45, P.YELLOW, nx=2, ny=2, r=0.30, h=0.18, n=6)
    for ya, yb in ((y - 1.70, y - 1.30), (y + 1.30, y + 1.70)):
        b.box((x - 1.30, ya, DECK + 0.45), (x + 1.30, yb, 4.40), P.YELLOW, bevel=0.05)
    disc_y(b, x, y, 3.60, 0.95, 2.40, P.DBG, 12)
    for sy in (-0.85, 0.85):
        disc_y(b, x, y + sy, 3.60, 1.12, 0.20, P.YELLOW, 12)
    b.box((x - 2.50, y - 0.90, DECK + 1.00), (x - 1.30, y + 0.90, DECK + 2.40), P.RED, bevel=0.06)
    b.box((x - 2.55, y - 0.75, DECK + 1.15), (x - 2.47, y + 0.75, DECK + 2.25), P.DBG, bevel=0.02)
    b.box((x - 2.15, y - 0.35, DECK + 2.40), (x - 1.85, y + 0.35, DECK + 2.90), P.YELLOW, bevel=0.03)
    b.box((x - 2.05, y - 0.14, DECK + 2.90), (x - 1.95, y + 0.14, DECK + 3.40), P.RED, bevel=0.02)


def lv3_cradle(b):
    """Yellow trolley at the top of the slipway, tilted down the slope: two bunks on black wheels, cross members,
    a red bow stop and a yellow hook eye at the winch end. Built flat, then tilt()."""
    t = lego.B()
    s0, s1 = RAMP[0] + CRADLE[0], RAMP[0] + CRADLE[1]
    for ry in RAILS:
        t.box((s0, ry - 0.8, 0.9), (s1, ry + 0.8, 2.6), P.YELLOW, bevel=0.08)       # the hull bilge rests on them
        for wx in (s0 + 1.2, s1 - 1.2):
            disc_y(t, wx, ry, 0.75, 0.7, 1.2, P.BLACK, 10)
    for wx in (s0 + 1.2, (s0 + s1) / 2, s1 - 1.2):
        t.box((wx - 0.6, RAILS[1] + 0.8, 1.0), (wx + 0.6, RAILS[0] - 0.8, 1.9), P.DBG, bevel=0.05)
    t.box((s1 - 0.2, RAILS[1] - 0.6, 0.9), (s1 + 0.6, RAILS[0] + 0.6, 3.6), P.RED, bevel=0.06)           # bow stop
    t.box((s0 - 1.0, YC - 0.6, 1.0), (s0, YC + 0.6, 1.9), P.YELLOW, bevel=0.05)                         # hook eye
    tilt(t, b)


def lifeboat(b):
    """Orange-and-white Lego lifeboat sitting on the trolley, bow to the sea: orange hull, white gunwale deck, white
    wheelhouse with a navy window band, orange studded roof. Built flat, then tilt()."""
    t = lego.B()
    s0, s1 = RAMP[0] + CRADLE[0], RAMP[0] + CRADLE[1] + 0.4
    keel = 1.9
    st = ((s0, 2.3, keel, 4.5), (s0 + 7.0, 2.3, keel, 4.5), (s1 - 2.4, 1.8, keel + 0.4, 4.7), (s1, 0.35, keel + 1.6, 5.1))
    t.loft([[(x, YC + sy * w * k, z) for sy, k, z in ((1, 1.0, top), (1, 0.92, bot + 1.1), (1, 0.45, bot),
                                                         (-1, 0.45, bot), (-1, 0.92, bot + 1.1), (-1, 1.0, top))]
            for x, w, bot, top in st], P.ORANGE)
    t.loft([[(x, YC + sy * (w + 0.15), z) for sy, z in ((1, top), (1, top + 0.6), (-1, top + 0.6), (-1, top))]
            for x, w, bot, top in st[:3] + ((s1 + 0.1, 0.5, 0, 5.1),)], P.WHITE)
    t.box((s0 - 0.1, YC - 2.5, 3.4), (s0 + 0.3, YC + 2.5, 4.0), P.INK, bevel=0.03)                      # transom band
    c0, c1 = s0 + 1.6, s0 + 6.8                                                                          # wheelhouse
    t.box((c0, YC - 1.7, 5.0), (c1, YC + 1.7, 7.5), P.WHITE, bevel=0.08)
    t.box((c0 + 0.6, YC - 1.78, 6.2), (c1 - 0.4, YC + 1.78, 7.0), P.INK, bevel=0.02)
    t.box((c1 - 0.1, YC - 1.3, 6.2), (c1 + 0.08, YC + 1.3, 7.0), P.INK, bevel=0.02)
    t.box((c0 - 0.2, YC - 1.95, 7.5), (c1 + 0.3, YC + 1.95, 7.95), P.ORANGE, bevel=0.06)
    grid_studs(t, c0 + 0.4, c1 - 0.4, YC - 1.6, YC + 1.6, 7.95, P.ORANGE, nx=3, ny=2, r=0.42, h=0.22, n=6)
    t.stud_row(c1 + 1.0, YC, s1 - 2.0, YC, 5.1, P.WHITE, spacing=1.5, r=0.4, h=0.2, n=6)                 # foredeck
    tilt(t, b)


def lv3_golight(b):
    """Big green go lamp on a white-and-red mast rising from the sea-end ridge: studded yellow housing, a green lens
    with a white ring each way (sea and quay)."""
    rz = ROOF[-1][3] + 0.45
    b.box((MAST_X - 0.7, YC - 0.7, rz - 0.3), (MAST_X + 0.7, YC + 0.7, LAMP_Z - 2.2), P.WHITE, bevel=0.06)
    for z in (rz + 1.2, rz + 3.4):
        b.box((MAST_X - 0.8, YC - 0.8, z), (MAST_X + 0.8, YC + 0.8, z + 0.9), P.RED, bevel=0.05)
    hx0, hx1 = MAST_X - 1.3, MAST_X + 1.3
    b.box((hx0, YC - 2.3, LAMP_Z - 2.3), (hx1, YC + 2.3, LAMP_Z + 2.3), P.YELLOW, bevel=0.08)
    grid_studs(b, hx0 + 0.3, hx1 - 0.3, YC - 2.0, YC + 2.0, LAMP_Z + 2.3, P.YELLOW, nx=1, ny=3, r=0.45, h=0.25, n=8)
    for sx in (1, -1):
        x = MAST_X + sx * 1.3
        b.cyl_x(x + sx * 0.15, YC, LAMP_Z, 2.05, 0.30, P.DBG, 14)
        b.cyl_x(x + sx * 0.45, YC, LAMP_Z, 1.70, 0.60, P.GREEN, 14)
        b.torus(x + sx * 0.55, YC, LAMP_Z, 1.95, 0.20, P.WHITE, 14, 4)


def lv3_launch(b):
    lv3_winch(b)
    lv3_cradle(b)
    lv3_golight(b)
    x, y = WINCH
    c, s = math.cos(SLOPE), math.sin(SLOPE)
    hx = RAMP[0] + (CRADLE[0] - 1.0) * c + 1.45 * s                                     # the tilted hook eye
    rope(b, (x + 1.0, y, 3.45), (hx, y, DECK - (CRADLE[0] - 1.0) * s + 1.45 * c), 0.25, P.BLACK, 4, 0.13)


# ------------------------------------------------------------------ build
def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_Boathouse_Brick", ALB)
    meshes = []
    nodes = {"Lv3": lego.node("Lv3")}

    def out(name, b, node):
        if b.empty():
            return
        obj = b.to_object(name, mat)
        obj.parent = nodes[node]
        role = "col" if name.endswith("_COL") else "visual"
        meshes.append({"object": obj, "set": SET, "role": role, "lod": "LOD0"} if role == "visual"
                      else {"object": obj, "role": "col"})
        print("[boathouse] %-28s %5d tris" % (name, b.tris()))

    def out_cols(node, c):
        # one object per box (8 verts, 6 faces each): Roblox hulls each _COL mesh, so a merged one fills decks
        assert len(c.v) == 8 * (len(c.f) // 6) and len(c.f) % 6 == 0, "COL must be plain boxes"
        for k in range(len(c.f) // 6):
            box = lego.B()
            box.v = c.v[8 * k:8 * k + 8]
            box.f = [(tuple(i - 8 * k for i in f), cell) for f, cell in c.f[6 * k:6 * k + 6]]
            assert all(0 <= i < 8 for f, _ in box.f for i in f)
            out("%s_Col%02d_COL" % (node, k + 1), box, node)

    b = lego.B()
    lv3_deck(b)
    out("Lv3_L01_Deck", b, "Lv3")

    b = lego.B()
    lv3_quay(b)
    out("Lv3_L02_QuayEdge", b, "Lv3")

    b = lego.B()
    lv3_ramp(b)
    out("Lv3_L03_Ramp", b, "Lv3")

    b = lego.B()
    lv3_roof(b)
    out("Lv3_L04_Roof", b, "Lv3")

    b = lego.B()
    lv3_room(b)
    out("Lv3_L05_ReadyRoom", b, "Lv3")

    b = lego.B()
    lv3_launch(b)
    out("Lv3_L06_Launch", b, "Lv3")

    b = lego.B()
    lifeboat(b)
    out("Lv3_L07_Lifeboat", b, "Lv3")

    c = lego.B()
    x0, x1, y0, y1 = ROOM
    d0, d1 = DOOR
    c.box((BAY[0], BAY[3], 0.10), (BAY[1], BAY[2], DECK), P.DBG, bevel=0)                 # deck
    c.box((KERB[0], -35.0, 0.0), (KERB[1], -33.8, 0.50), P.DBG, bevel=0)                  # kerb
    c.box((x0, y0, DECK), (x1, y0 + 0.9, 6.50), P.DBG, bevel=0)                           # room water wall
    c.box((x0, y1 - 0.9, DECK), (x1, y1, 6.50), P.DBG, bevel=0)                           # room quay wall
    c.box((x0, y0 + 0.9, DECK), (x0 + 0.9, y1 - 0.9, 6.50), P.DBG, bevel=0)               # room back
    c.box((x1 - 0.9, y0 + 0.9, DECK), (x1, d0, 6.50), P.DBG, bevel=0)                     # door stub water side
    c.box((x1 - 0.9, d1, DECK), (x1, y1 - 0.9, 6.50), P.DBG, bevel=0)                     # door stub quay side
    c.box((x1 - 0.9, d0, 5.50), (x1, d1, 6.50), P.DBG, bevel=0)                           # door header
    c.box((x0 + 0.9, -44.3, DECK), (x0 + 2.7, -38.0, 4.60), P.DBG, bevel=0)               # bench
    c.box((WINCH[0] - 2.6, WINCH[1] - 1.9, DECK), (WINCH[0] + 1.7, WINCH[1] + 1.9, 4.55), P.DBG, bevel=0)   # winch
    n = 6                                                                                 # ramp steps
    for i in range(n):
        xa = RAMP[0] + i * (RAMP[1] - RAMP[0]) / n
        xb = xa + (RAMP[1] - RAMP[0]) / n
        c.box((xa, RAMP[3], -4.80), (xb, RAMP[2], z_ramp((xa + xb) / 2.0)), P.DBG, bevel=0)
    for x0, x1, ez, rz in ROOF:
        c.box((x0, ROOF_Y1, ez), (x1, ROOF_Y0, rz + 0.45), P.DBG, bevel=0)               # roof overhead
    for x in POST_X:
        for y in POST_Y:
            c.box((x - 1.0, y - 1.0, DECK if x <= BAY[1] else WATER - 0.6), (x + 1.0, y + 1.0, eave(x)),
                  P.DBG, bevel=0)                                                         # roof columns
    t = lego.B()                                                                          # lifeboat + trolley
    t.box((RAMP[0] + CRADLE[0], YC - 2.45, 0.0), (RAMP[0] + CRADLE[1] + 0.5, YC + 2.45, 7.95), P.DBG, bevel=0)
    tilt(t, c)
    out_cols("Lv3", c)

    atts = [lego.attach("ATT_Launch", (RAMP[0] + 12.0, YC, z_ramp(RAMP[0] + 12.0))),
            lego.attach("ATT_Work_Winch", (WINCH[0], -37.6, DECK)),
            lego.attach("ATT_ReadyRoom", ((ROOM[0] + ROOM[1]) / 2, YC, DECK))]

    pts = []
    for e in meshes:
        if e["role"] == "visual" and e.get("lod") == "LOD0":
            pts.extend(e["object"].matrix_world @ v.co for v in e["object"].data.vertices)
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    print("[boathouse] bbox studs %.2f..%.2f, %.2f..%.2f, %.2f..%.2f; dims_m %s"
          % (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2], dims))

    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[boathouse] LOD0 %d tris in %d meshes" % (total, sum(e["role"] == "visual" for e in meshes)))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "add-ons only: the Lv3 bay lies along the cove quay beside the code boathouse (deck, roof and "
                     "ramp over the water at y -35..-47, sea end +x) plus a short kerb on the code plate; the bbox is "
                     "that bay, not the boathouse. Front -Y, origin the boathouse ground centre, authored at the "
                     "code boathouse's final 1.2 scale (no extra scale); Lv1/Lv2 stay code-built",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "gameplay node/layer names (docs/25): Lv3_L01_..., Lv3_Col01_COL..; the FBX importer "
                      "flattens empty parents, so the node name is the mesh prefix",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "ready_room", "target": [-19.5, -38.0, 3.0], "dist": 22, "az": -150, "el": 10},
            {"name": "winch", "target": [10.0, -41.0, 2.6], "dist": 16, "az": 40, "el": 16},
            {"name": "lifeboat", "target": [36.5, -41.0, 2.5], "dist": 30, "az": 40, "el": 20},
            {"name": "go_light", "target": [MAST_X, YC, 23.0], "dist": 24, "az": 55, "el": 8},
            {"name": "roof", "target": [3.0, -41.0, 15.0], "dist": 66, "az": 60, "el": 26},
        ],
    }
