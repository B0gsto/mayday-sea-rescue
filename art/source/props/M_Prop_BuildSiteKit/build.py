"""M_Prop_BuildSiteKit: the Lego construction-site dressing round a lot that is being built (replaces the code-built
Parts in ConstructionController.makeProps: fence, scaffold, crane, brick stacks, sign; docs/28 Code->mesh, baseline 5.0).

One FBX, one flat palette material, every module its own mesh. Modules sit side by side in the kit along Roblox +X;
each has an ATT_<Module> empty at its own origin (ground centre, Roblox axes: x along the piece, y up, front -z), so
ConstructionController reads AssetIds.Attachments.M_Prop_BuildSiteKit and re-places every MeshPart relative to it.

  L01_FencePanel  8-stud yellow/black brick fence bay, its post at the left end (panels tile; run ends get a post)
  L02_FenceGate   8-stud gate: yellow brick posts, red/white boom, white bars, a warning plate
  L03_FencePost   corner post
  L04_ScaffoldBay 6 x 2.4 x 5 bay (silver tubes, plank deck, toe board, yellow brace); bays stack (+5) and tile in x
  L05_CraneBase   red studded footing + yellow Warren-truss mast (static)
  L06_CraneSlew   slewing ring, red cab, truss jib (+x) with a red tip, counter-jib + ballast, A-frame ties, trolley;
                  it slews round ATT_CranePivot (20.6 up the mast: above the finished buildings)
  L07_CraneHook   twin cable, hazard hook block, red hook and a slung red 2x4 brick (the code bobs it in y)
  L08_StackPallet timber pallet (always shown)
  L09_StackLow / L10_StackMid / L11_StackTop  the three brick courses (fill states: the code hides top first)
  L12_SignBoard   hazard-framed board on two posts (brick + hammer pictogram); ATT_SignUI = top centre
  L13_Cone        studded traffic cone
  L14_Barrier     yellow/black A-frame barrier
  Col01_COL       a token box (the code never collides with the dressing)

    python3 art/source/props/M_Prop_BuildSiteKit/maketex.py --out build/prod/M_Prop_BuildSiteKit/textures/M_Prop_BuildSiteKit
    ~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/source/props/M_Prop_BuildSiteKit/build.py \
        --out-root build/prod/M_Prop_BuildSiteKit --steps build,lod,validate,export,turntable
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

NAME = "M_Prop_BuildSiteKit"
BUDGET = "large_prop"
TIER = "standard"
SET_NAME, SET = "BuildSiteKit", "Brick"
ALB = os.path.join(G, "build/prod", NAME, "textures", NAME, "T_BuildSiteKit_Brick_ALB.png")

Y0 = -0.06                  # every foot just under the ground: never coplanar with it
PIVOT_Y = 20.6              # crane slew pivot (ATT_CranePivot; round 3: taller than the finished buildings)
HOOK_X = 10.5               # hook under the jib, from the mast
SLOTS = {                   # module origins in the kit, Roblox x (studs)
    "Fence": 0, "Gate": 11, "Post": 18, "Scaffold": 25, "Crane": 40, "Stack": 56, "Sign": 63, "Cone": 69, "Barrier": 74,
}


def patch_lod_names():
    import names
    base = lambda n: re.sub(r"_(?:LOD[012]|COL|HP)$", "", n)
    names.mesh_base = base
    names.with_suffix = lambda n, s: base(n) + "_" + s


class K:
    """Roblox-axes authoring (x, y up, z back) on a lego.B at a slot origin; Blender = (-x, z, y)."""

    def __init__(self, b, ox):
        self.b, self.ox = b, ox

    def p(self, x, y, z):
        return (-(x + self.ox), z, y)

    def box(self, lo, hi, c, bev=None):
        self.b.box(self.p(*lo), self.p(*hi), c, bevel=bev)

    def cyl(self, x, z, y0, y1, r, c, n=8):
        bx, by, _ = self.p(x, 0, z)
        self.b.cyl(bx, by, y0, y1, r, c, n)

    def stud(self, x, y, z, c, r=0.26, h=0.2, n=8):
        self.cyl(x, z, y, y + h, r, c, n)

    def tube_x(self, x0, x1, y, z, r, c, n=8):
        bx, by, bz = self.p((x0 + x1) / 2, y, z)
        self.b.cyl_x(bx, by, bz, r, abs(x1 - x0), c, n)

    def beam(self, p0, p1, w, h, c):
        self.b.beam(self.p(*p0), self.p(*p1), w, h, c)

    def frustum(self, x, z, rings, c, n=10):
        """Stacked rings [(y, r)] round a vertical axis, capped both ends."""
        secs = []
        for y, r in rings:
            secs.append([self.p(x + r * math.cos(2 * math.pi * i / n), y, z + r * math.sin(2 * math.pi * i / n))
                         for i in range(n)])
        self.b.loft(secs, c)


# ------------------------------------------------------------------ fence (round 2: 8-stud panels, chunky blocks)
def fence_panel(k):
    k.box((-4.0, Y0, -0.85), (-3.1, 0.35, 0.85), P.DBG, bev=0.1)                     # foot plate
    k.box((-3.98, 0.35, -0.43), (-3.12, 3.15, 0.43), P.YELLOW, bev=0.14)           # post
    k.stud(-3.55, 3.15, 0, P.YELLOW, r=0.3)
    for i in range(4):                                                              # hazard-stripe top rail
        x0 = -3.1 + i * 1.7625 + 0.03
        k.box((x0, 2.1, -0.32), (x0 + 1.7025, 2.9, 0.32), P.YELLOW if i % 2 == 0 else P.BLACK, bev=0.1)
    for i in range(2):                                                              # r5: calm yellow lower rail
        x0 = -3.1 + i * 3.525 + 0.03
        k.box((x0, 0.95, -0.32), (x0 + 3.465, 1.75, 0.32), P.YELLOW, bev=0.1)


def fence_gate(k):
    for s in (-1, 1):
        lo, hi = (3.15, 3.95) if s > 0 else (-3.95, -3.15)
        k.box((lo - 0.2 if s > 0 else lo, Y0, -0.95), (hi if s > 0 else hi + 0.2, 0.35, 0.95), P.DBG, bev=0.1)
        for j in range(3):                                                         # r6: calm yellow brick post
            y0 = 0.35 + j * 1.9
            k.box((lo, y0 + 0.02, -0.45), (hi, y0 + 1.9, 0.45), P.YELLOW, bev=0.12)
        k.stud((lo + hi) / 2, 6.05, 0, P.YELLOW, r=0.3)
    for i in range(5):                                                             # one wide red/white boom
        x0 = -3.15 + i * (6.3 / 5) + 0.02
        k.box((x0, 4.3, -0.4), (x0 + 6.3 / 5 - 0.04, 5.5, 0.4), P.RED if i % 2 == 0 else P.WHITE, bev=0.14)
    k.box((-3.1, 0.55, -0.24), (3.1, 0.98, 0.24), P.DBG, bev=0.08)                 # kick rail
    for i in range(5):                                                             # striped gate leaf
        x0 = -3.15 + i * (6.3 / 5) + 0.02
        k.box((x0, 1.1, -0.3), (x0 + 6.3 / 5 - 0.04, 2.0, 0.3), P.WHITE, bev=0.12)
    for x in (-2.55, 2.55):                                                        # leaf stiles up to the boom
        k.box((x - 0.18, 2.0, -0.18), (x + 0.18, 4.3, 0.18), P.WHITE, bev=0.05)
    # warning plate: big yellow diamond on a black square, a black "!"
    cy = 3.15
    k.box((-1.6, 2.04, -0.2), (1.6, 4.26, 0.2), P.BLACK, bev=0.12)
    k.b.loft([[k.p(0, cy - 1.04, -0.22), k.p(1.04, cy, -0.22), k.p(0, cy + 1.04, -0.22), k.p(-1.04, cy, -0.22)],
              [k.p(0, cy - 0.92, -0.32), k.p(0.92, cy, -0.32), k.p(0, cy + 0.92, -0.32), k.p(-0.92, cy, -0.32)]],
             P.YELLOW)
    k.box((-0.18, cy - 0.12, -0.37), (0.18, cy + 0.62, -0.31), P.BLACK, bev=0.04)
    k.box((-0.18, cy - 0.6, -0.37), (0.18, cy - 0.3, -0.31), P.BLACK, bev=0.04)


def fence_post(k):
    k.box((-0.65, Y0, -0.65), (0.65, 0.35, 0.65), P.DBG, bev=0.1)
    for j, c in enumerate((P.YELLOW, P.BLACK, P.YELLOW)):
        y0 = 0.35 + j * 0.95
        k.box((-0.48, y0 + 0.02, -0.48), (0.48, y0 + 0.95, 0.48), c, bev=0.12)
    k.stud(0, 3.2, 0, P.YELLOW, r=0.3)


# ------------------------------------------------------------------ scaffold bay (round 2: blue tubes, red brace)
def scaffold_bay(k):
    for x in (-2.65, 2.65):
        for z in (-1.0, 1.0):
            k.box((x - 0.3, Y0, z - 0.3), (x + 0.3, 0.3, z + 0.3), P.DBG, bev=0.06)  # base plate
            k.cyl(x, z, 0.3, 4.6, 0.24, P.BLUE)                                     # upright
            k.cyl(x, z, 4.6, 4.94, 0.3, P.YELLOW)                                   # coupler collar
    for z in (-1.0, 1.0):
        k.tube_x(-2.45, 2.45, 2.35, z, 0.17, P.BLUE)                                 # mid ledger (guard rail)
        k.tube_x(-2.45, 2.45, 4.36, z, 0.15, P.BLUE)                                 # deck ledger
    for x in (-2.65, 2.65):                                                          # side transoms
        k.beam((x, 4.36, -0.8), (x, 4.36, 0.8), 0.26, 0.26, P.BLUE)
    for i, c in enumerate((P.TAN, P.DTAN, P.TAN)):                                   # studded plank deck
        z0 = -1.15 + i * 0.77 + 0.03
        k.box((-2.95, 4.52, z0), (2.95, 4.78, z0 + 0.71), c, bev=0.06)
        for x in (-1.75, -0.6, 0.6, 1.75):
            k.stud(x, 4.78, z0 + 0.355, c, r=0.2, h=0.15, n=6)
    k.box((-2.3, 4.78, -1.3), (2.3, 5.2, -1.16), P.YELLOW, bev=0.05)                 # toe board
    k.beam((-2.35, 0.55, -1.36), (2.35, 4.25, -1.36), 0.3, 0.3, P.WHITE)              # front brace (red = the crane's)


# ------------------------------------------------------------------ crane (origin: mast foot; pivot PIVOT_Y)
def warren(k, a, b, w, c, steps):
    """A zigzag between two parallel chords a(t), b(t) (callables, t 0..1)."""
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        p, q = (a(t0), b(t1)) if i % 2 == 0 else (b(t0), a(t1))
        k.beam(p, q, w, w, c)


def crane_base(k):
    """The jetty crane's language: red studded footing with yellow tiles, white mast, red zigzag."""
    k.box((-2.5, Y0, -2.5), (2.5, 1.0, 2.5), P.RED, bev=0.18)
    for x in (-1.75, 1.75):
        for z in (-1.75, 1.75):
            k.box((x - 0.55, 1.0, z - 0.55), (x + 0.55, 1.12, z + 0.55), P.YELLOW, bev=0.04)
            k.stud(x, 1.12, z, P.YELLOW, r=0.34, h=0.26)
    m, top = 0.9, PIVOT_Y - 0.3
    for x in (-m, m):
        for z in (-m, m):
            k.box((x - 0.34, 1.0, z - 0.34), (x + 0.34, top - 0.4, z + 0.34), P.WHITE, bev=0.1)   # r5: chords 1.3x
    y0, y1 = 1.4, top - 0.6
    y = lambda t: y0 + (y1 - y0) * t
    for fx, fz in ((m, None), (-m, None), (None, m), (None, -m)):                  # Warren truss, 4 faces
        if fz is None:
            warren(k, lambda t: (fx, y(t), -m), lambda t: (fx, y(t), m), 0.4, P.RED, 9)
        else:
            warren(k, lambda t: (-m, y(t), fz), lambda t: (m, y(t), fz), 0.4, P.RED, 9)
    k.box((-1.25, top - 0.4, -1.25), (1.25, top - 0.05, 1.25), P.RED, bev=0.1)      # mast cap
    k.cyl(0, 0, top - 0.05, top, 1.1, P.DBG, n=12)                                  # fixed half of the ring


def crane_slew(k):
    py = PIVOT_Y
    k.cyl(0, 0, py - 0.3, py, 1.1, P.YELLOW, n=12)                                  # slewing ring
    k.box((-1.3, py, -0.9), (1.3, py + 0.35, 0.9), P.DBG, bev=0.06)                  # turntable deck
    # yellow cab on the front side, blue glass, a red 2x4 roof plate with an overhang (as the jetty crane)
    k.box((0.1, py + 0.35, -2.95), (2.7, py + 2.85, -0.6), P.YELLOW, bev=0.18)
    k.box((2.71, py + 1.5, -2.7), (2.8, py + 2.45, -0.85), P.BLUE, bev=0.02)         # window band (+x)
    k.box((0.35, py + 1.5, -3.04), (2.45, py + 2.45, -2.96), P.BLUE, bev=0.02)       # window band (front)
    k.box((-0.2, py + 2.85, -3.25), (3.0, py + 3.25, -0.3), P.RED, bev=0.12)
    for x in (0.6, 2.2):
        for z in (-2.45, -1.1):
            k.stud(x, py + 3.25, z, P.RED, r=0.32, h=0.24)
    # jib: a solid yellow deck (the trolley runs under it), yellow top chord, red zigzag faces, red tip cap
    x0, x1, yb, yt = 1.0, 12.4, py + 0.45, py + 1.9                                   # r5: reaches the hook at 10.5
    k.box((x0, yb - 0.3, -0.75), (x1, yb + 0.3, 0.75), P.YELLOW, bev=0.1)
    k.beam((x0, yt, 0), (x1, yb + 0.7, 0), 0.62, 0.62, P.YELLOW)
    top = lambda t: (x0 + (x1 - x0) * t, yt + (yb + 0.7 - yt) * t, 0)
    for z in (-0.6, 0.6):
        warren(k, lambda t, z=z: (x0 + (x1 - x0) * t, yb + 0.3, z), top, 0.36, P.RED, 8)
    k.box((x1 - 0.05, yb - 0.35, -0.8), (x1 + 0.8, yb + 1.0, 0.8), P.RED, bev=0.16)
    # trolley under the deck (the hook's cable runs out of it)
    k.box((HOOK_X - 0.6, yb - 0.75, -0.75), (HOOK_X + 0.6, yb - 0.25, 0.75), P.DBG, bev=0.08)
    # counter-jib platform, rail, ballast bricks
    k.box((-5.0, py + 0.3, -0.7), (-1.0, py + 0.66, 0.7), P.YELLOW, bev=0.08)
    k.tube_x(-4.7, -1.2, py + 1.35, 0.62, 0.12, P.WHITE, n=6)
    for x in (-4.6, -3.0, -1.4):
        k.cyl(x, 0.62, py + 0.66, py + 1.35, 0.12, P.WHITE, n=6)
    for x0b, c in ((-4.9, P.STONE), (-3.75, P.DBG)):
        k.box((x0b, py + 0.66, -0.6), (x0b + 1.1, py + 2.05, 0.45), c, bev=0.1)
        k.stud(x0b + 0.55, py + 2.05, -0.08, c, r=0.32)
    # A-frame head and two chunky yellow ties
    apex = (0, py + 4.0, 0)
    for z in (-0.6, 0.6):
        k.beam((-0.6, py + 0.35, z), apex, 0.32, 0.32, P.YELLOW)
        k.beam((0.6, py + 0.35, z), apex, 0.32, 0.32, P.YELLOW)
    k.cyl(0, 0, py + 3.75, py + 4.3, 0.34, P.RED)
    k.beam(apex, (x1 - 1.5, yt - 0.25, 0), 0.4, 0.4, P.YELLOW)
    k.beam(apex, (-4.3, py + 0.66, 0), 0.4, 0.4, P.YELLOW)


def crane_hook(k):
    py = PIVOT_Y
    yb = py - 4.0                                                                    # r5: hangs higher, over the lot (clears the walls)
    for z in (-0.3, 0.3):                                                            # twin cable (overlaps the trolley)
        k.beam((HOOK_X, py + 0.2, z), (HOOK_X, yb, z), 0.3, 0.3, P.DBG)
    k.box((HOOK_X - 1.1, yb - 2.1, -0.75), (HOOK_X + 1.1, yb, 0.75), P.YELLOW, bev=0.18)   # yellow block, red band
    k.box((HOOK_X - 1.15, yb - 1.3, -0.8), (HOOK_X + 1.15, yb - 0.75, 0.8), P.RED, bev=0.06)
    hy = yb - 2.1
    k.box((HOOK_X - 0.25, hy - 0.8, -0.25), (HOOK_X + 0.25, hy, 0.25), P.LBG, bev=0.07)   # chunky grey hook
    k.box((HOOK_X - 0.25, hy - 1.35, -0.25), (HOOK_X + 1.15, hy - 0.8, 0.25), P.LBG, bev=0.07)
    k.box((HOOK_X + 0.7, hy - 1.35, -0.25), (HOOK_X + 1.15, hy - 0.55, 0.25), P.LBG, bev=0.07)
    by = hy - 3.6                                                                    # slung red 2x4 brick, 1.4x
    # r5: long side across the jib, so it hangs clear of the building's corner (the jib points at it)
    for s in (-1, 1):
        k.beam((HOOK_X, hy - 1.1, 0), (HOOK_X, by + 1.3, s * 1.4), 0.16, 0.16, P.DBG)
    k.box((HOOK_X - 0.9, by, -1.8), (HOOK_X + 0.9, by + 1.3, 1.8), P.RED, bev=0.16)
    for i in range(4):
        for x in (-0.45, 0.45):
            k.stud(HOOK_X + x, by + 1.3, -1.35 + i * 0.9, P.RED, r=0.3, h=0.24)


# ------------------------------------------------------------------ brick stacks (pallet + three courses)
def pallet(k):
    for x in (-1.2, 1.2):
        k.box((x - 0.25, Y0, -1.15), (x + 0.25, 0.3, 1.15), P.BROWN, bev=0.05)
    for i in range(3):
        z0 = -1.2 + i * 0.82 + 0.03
        k.box((-1.7, 0.3, z0), (1.7, 0.55, z0 + 0.74), P.TAN, bev=0.05)
    k.box((0.55, 0.55, 0.15), (1.45, 1.0, 0.95), P.BLUE, bev=0.08)                    # one loose brick on the boards
    k.stud(1.0, 1.0, 0.35, P.BLUE, r=0.2, h=0.15, n=6)
    k.stud(1.0, 1.0, 0.75, P.BLUE, r=0.2, h=0.15, n=6)


def course(k, y0, bricks):
    """bricks: (x0, z0, x1, z1, colour); 0.8 tall, studs on a 0.8 grid."""
    for x0, z0, x1, z1, c in bricks:
        k.box((x0, y0, z0), (x1, y0 + 0.8, z1), c, bev=0.1)
        nx, nz = max(1, round((x1 - x0) / 0.8)), max(1, round((z1 - z0) / 0.8))
        for i in range(nx):
            for j in range(nz):
                k.stud(x0 + (i + 0.5) * (x1 - x0) / nx, y0 + 0.8, z0 + (j + 0.5) * (z1 - z0) / nz, c, r=0.22, h=0.18,
                       n=6)


# fill states read apart: one course = flat with bare boards, two = a step, three = a stepped tower
def stack_low(k):
    course(k, 0.55, [(-1.62, -1.1, 0.25, 1.1, P.BLUE), (0.31, -1.1, 1.62, -0.05, P.BLUE)])


def stack_mid(k):
    course(k, 1.35, [(-1.6, -1.05, 0.22, 1.05, P.BLUE)])


def stack_top(k):
    course(k, 2.15, [(-1.45, -0.75, -0.05, 0.6, P.BLUE)])


# ------------------------------------------------------------------ sign board (round 2: 1.3x, bigger icons)
def sign_board(k):
    for x in (-2.2, 2.2):
        k.box((x - 0.4, Y0, 0.0), (x + 0.4, 0.3, 0.9), P.DBG, bev=0.06)
        k.box((x - 0.24, 0.3, 0.22), (x + 0.24, 6.0, 0.7), P.DBG, bev=0.06)
    x0, x1, y0, y1, t = -3.0, 3.0, 2.3, 6.2, 0.55                                  # hazard frame bricks
    k.box((x0 + t, y0 + t, -0.12), (x1 - t, y1 - t, 0.2), P.WHITE, bev=0.04)
    n = 6
    w = (x1 - x0) / n
    for i in range(n):
        for ya, yb_ in ((y0, y0 + t), (y1 - t, y1)):
            c = P.YELLOW if (i + (ya > 3)) % 2 == 0 else P.BLACK
            k.box((x0 + i * w + 0.02, ya, -0.22), (x0 + (i + 1) * w - 0.02, yb_, 0.22), c, bev=0.07)
    h = (y1 - y0 - 2 * t) / 2
    for x in (x0, x1 - t):
        for j in range(2):
            c = P.BLACK if j % 2 == 0 else P.YELLOW
            k.box((x, y0 + t + j * h + 0.02, -0.22), (x + t, y0 + t + (j + 1) * h - 0.02, 0.22), c, bev=0.07)
    # pictogram filling the white face (front -z): a big red 2x2 brick and a hammer
    k.box((-2.25, 3.1, -0.26), (-0.15, 4.75, -0.12), P.RED, bev=0.12)
    for x in (-1.7, -0.7):
        k.box((x - 0.32, 4.75, -0.24), (x + 0.32, 5.1, -0.14), P.RED, bev=0.05)
    k.beam((0.45, 3.0, -0.22), (1.7, 4.95, -0.22), 0.75, 0.22, P.BROWN)
    k.beam((0.95, 5.45, -0.26), (2.4, 4.5, -0.26), 0.85, 0.26, P.BLACK)


# ------------------------------------------------------------------ cone and barrier
def cone(k):
    k.box((-0.9, Y0, -0.9), (0.9, 0.33, 0.9), P.BLACK, bev=0.1)                      # r5: 1.5x
    k.frustum(0, 0, [(0.33, 0.72), (1.2, 0.54)], P.ORANGE)
    k.frustum(0, 0, [(1.2, 0.54), (1.65, 0.435)], P.WHITE)
    k.frustum(0, 0, [(1.65, 0.435), (2.4, 0.255)], P.ORANGE)
    k.stud(0, 2.4, 0, P.ORANGE, r=0.22, h=0.2)


def barrier(k):
    for x in (-2.2, 2.2):
        for z in (-1, 1):
            k.beam((x, Y0 + 0.06, z * 0.6), (x, 2.6, 0), 0.3, 0.3, P.YELLOW)
        k.box((x - 0.3, Y0, -0.85), (x + 0.3, 0.16, -0.4), P.DBG, bev=0.03)
        k.box((x - 0.3, Y0, 0.4), (x + 0.3, 0.16, 0.85), P.DBG, bev=0.03)
    for y0, flip in ((1.75, 0), (0.75, 1)):                                          # two bold striped boards
        for i in range(5):
            x0 = -2.6 + i * 1.04 + 0.02
            c = P.YELLOW if (i + flip) % 2 == 0 else P.BLACK
            k.box((x0, y0, -0.36), (x0 + 1.0, y0 + 0.72, -0.1), c, bev=0.07)


MODULES = [
    ("L01_FencePanel", "Fence", fence_panel), ("L02_FenceGate", "Gate", fence_gate), ("L03_FencePost", "Post", fence_post),
    ("L04_ScaffoldBay", "Scaffold", scaffold_bay), ("L05_CraneBase", "Crane", crane_base),
    ("L06_CraneSlew", "Crane", crane_slew), ("L07_CraneHook", "Crane", crane_hook),
    ("L08_StackPallet", "Stack", pallet), ("L09_StackLow", "Stack", stack_low), ("L10_StackMid", "Stack", stack_mid),
    ("L11_StackTop", "Stack", stack_top), ("L12_SignBoard", "Sign", sign_board), ("L13_Cone", "Cone", cone),
    ("L14_Barrier", "Barrier", barrier),
]


def build():
    import bpy  # noqa: F401  (Blender only)
    patch_lod_names()
    mat = lego.material("MI_BuildSiteKit_Brick", ALB)
    meshes = []
    for name, slot, fn in MODULES:
        b = lego.B()
        fn(K(b, SLOTS[slot]))
        obj = b.to_object(name, mat)
        meshes.append({"object": obj, "set": SET, "role": "visual", "lod": "LOD0"})
        print("[site] %-16s %5d tris" % (name, b.tris()))
    c = lego.B()
    K(c, SLOTS["Crane"]).box((-2.5, Y0, -2.5), (2.5, 1.0, 2.5), P.DBG, bev=0)
    meshes.append({"object": c.to_object("Col01_COL", mat), "role": "col"})

    def att(n, x, y=0.0, z=0.0):
        return lego.attach(n, (-x, z, y))
    atts = [att("ATT_" + s, x) for s, x in SLOTS.items()]
    atts.append(att("ATT_CranePivot", SLOTS["Crane"], PIVOT_Y))
    atts.append(att("ATT_SignUI", SLOTS["Sign"], 6.6))

    pts = [e["object"].matrix_world @ v.co for e in meshes if e["role"] == "visual" for v in e["object"].data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    dims = tuple(round((hi[i] - lo[i]) / 3.0, 2) for i in range(3))
    total = sum(len(p.vertices) - 2 for e in meshes if e["role"] == "visual" for p in e["object"].data.polygons)
    print("[site] LOD0 %d tris; dims_m %s" % (total, dims))
    return {
        "name": NAME, "budget": BUDGET, "tier": TIER,
        "dims_m": dims, "origin": "free", "tiling": True,
        "size_note": "a kit strip: every module is placed on its own by ConstructionController (ATT_<Module> origins)",
        "sets": [{"name": SET_NAME, "set": SET, "size": 1024, "wet": False}],
        "waivers": {
            "naming": "layer names L01_FencePanel...: ConstructionController places each module by name",
            "LOD UV layout": "flat palette cells (one shared material): decimation merges cells, UVs are not a unique "
                             "unwrap by design (tiling=True skips the density check)",
        },
        "meshes": meshes,
        "attachments": atts,
        "closeups": [
            {"name": "crane", "target": [-SLOTS["Crane"] - 3, 0, 11], "dist": 26, "az": -30, "el": 12},
            {"name": "fence", "target": [-8, 0, 2], "dist": 22, "az": -20, "el": 14},
            {"name": "stacks", "target": [-SLOTS["Stack"] - 7, 0, 2], "dist": 20, "az": -25, "el": 18},
        ],
    }
