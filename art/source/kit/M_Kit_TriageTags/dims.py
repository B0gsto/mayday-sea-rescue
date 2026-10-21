"""M_Kit_TriageTags: shared design table (build.py, maketex.py and font.py all import this).

A set of three casualty triage tags laid out on the reception boat or the hull (docs/09 section 7 step 4: the
triage sieve ends with a coloured tag on the casualty). The game's tags are Red P1 Immediate, Yellow P2 Urgent and
Green P3 Can wait (src/shared/Ferry/Triage.luau: `Triage.Display`; the same file says "there is no black /
expectant tag anywhere"), so the asset is those three, not the four of the full UK sieve.

Each tag is a waterproof 0.200 x 0.120 m card with a real eyelet (a raised grommet round a hole) and a wire tie
threaded through it. Cards are authored in metres in the card's own frame (X along the length, Y across, +Z the
printed face, card centre at the origin), then placed in the row: one warp per card, one wire pose per card.

Atlas: one 1024 set, T_TriageTags_Kit_*, six card-face lanes (front and back of each colour, each 5:3 to match the
card), a polar lane for the grommet ring (u round, v inner to outer) and a strip lane for the wire tie (u along the
cord, v across it). Everything else is spare card stock, painted so no atlas texel is dead.
"""
import math

NAME = "M_Kit_TriageTags"
SET = "Kit"

# ---------------------------------------------------------------- card (metres)
CARD_L, CARD_W = 0.200, 0.120     # long axis X, across Y
CARD_T = 0.0016                   # full thickness of the pillow: the two faces meet at the silhouette
NC, NR = 4, 3                     # grid of quads per face (4 x 3 = 24 quads for both faces, 48 tris)
CORNER = 0.006                    # the two corner grid points of a card pull in by this much (rounded look)
WARP_A, WARP_T = 0.0028, 0.0018   # long-axis wave amplitude, corner twist (the card is not a flat rectangle)
WARP_PH = {"Red": 0.05, "Yellow": 0.33, "Green": 0.63}

# ---------------------------------------------------------------- eyelet
EYE = (-0.078, 0.042)             # grommet centre, card frame: 22 mm from the left end, 18 mm from the top edge
HOLE_R = 0.0050                   # hole radius (painted dark; the wire passes through)
EYE_R = 0.0082                    # grommet outer radius
EYE_SEG = 8                       # grommet ring segments (8 quads, 16 tris)
EYE_LIFT = 0.0007                 # the ring stands this far off the printed face

# ---------------------------------------------------------------- wire tie (threaded through the eyelet)
WIRE_W, WIRE_T = 0.0008, 0.0005   # 0.8 mm across, 0.5 mm thick (a stiff covered wire tie)
D_OUT = (-math.sqrt(0.5), math.sqrt(0.5))   # outward at 45 degrees, in the card plane: up and to the left
P_SIDE = (math.sqrt(0.5), math.sqrt(0.5))   # lateral, in the card plane
# (along D_OUT m, along P_SIDE m, height above the printed face m): the loop rises as it leaves the hole
WIRE_PATH = ((0.0000, 0.0000, -0.0016),
             (0.0100, 0.0025, 0.0011),
             (0.0240, 0.0110, 0.0060),
             (0.0420, 0.0000, 0.0120),
             (0.0240, -0.0110, 0.0060),
             (0.0100, -0.0025, 0.0011))
ATT_OUT = 0.0050                  # ATT_Attach sits this far past the loop's tip

# ---------------------------------------------------------------- the three tags
TAGS = ("Red", "Yellow", "Green")
RGB = {"Red": (214, 48, 49), "Yellow": (242, 196, 15), "Green": (46, 160, 67)}   # Triage.Display
CODE = {"Red": "P1", "Yellow": "P2", "Green": "P3"}
WORD = {"Red": "IMMEDIATE", "Yellow": "URGENT", "Green": "CAN WAIT"}
SERIAL = {"Red": "0412", "Yellow": "0413", "Green": "0414"}
TICKS = {"Red": (1, 1, 1, 1), "Yellow": (1, 1, 0, 0), "Green": (1, 0, 0, 0)}     # sieve rows ticked on the front
HAND_TICKS = {"Red": (1, 0, 0), "Yellow": (0, 1, 0), "Green": (0, 0, 1)}         # P1 / P2 / P3 ticked on the back
# placement in the row (x m, y m, rotation about Z in degrees): hand-laid, so no two are square
PLACE = {"Red": (0.004, -0.137, 3.4), "Yellow": (-0.003, 0.000, -2.2), "Green": (0.002, 0.137, 4.1)}

# ---------------------------------------------------------------- atlas (1024 px, one set)
SIZE = 1024
INSET = 2.0                       # texels kept free at every lane edge


def _lane(cols, rows):
    """Pixel rect (x0, y0, x1, y1) with y from the *top* -> atlas uv rect (u0, v0, u1, v1), v up."""
    x0, x1, y0, y1 = cols[0], cols[1], rows[0], rows[1]
    return (x0 / float(SIZE), 1.0 - y1 / float(SIZE), x1 / float(SIZE), 1.0 - y0 / float(SIZE))


_C3 = ((0, 341), (341, 683), (683, 1024))
LANES = {
    "RedFront": _lane(_C3[0], (0, 205)), "YellowFront": _lane(_C3[1], (0, 205)), "GreenFront": _lane(_C3[2], (0, 205)),
    "RedBack": _lane(_C3[0], (205, 410)), "YellowBack": _lane(_C3[1], (205, 410)), "GreenBack": _lane(_C3[2], (205, 410)),
    "Wire": _lane((0, 246), (420, 451)),          # u along the cord, v across it
    "Eyelet": _lane((266, 430), (430, 594)),      # u round the ring, v inner to outer
}
LANE_WORLD = {                        # the world size of each lane's two axes in mm: paints isotropic
    "RedFront": (200.0, 120.0), "YellowFront": (200.0, 120.0), "GreenFront": (200.0, 120.0),
    "RedBack": (200.0, 120.0), "YellowBack": (200.0, 120.0), "GreenBack": (200.0, 120.0),
    "Wire": (126.0, 0.8),             # the loop's circumference, the cord's width
    "Eyelet": (51.5, 2.4),            # circumference of the ring's mid radius, its width (inner to outer)
}
FRONT_LANE = {"Red": "RedFront", "Yellow": "YellowFront", "Green": "GreenFront"}
BACK_LANE = {"Red": "RedBack", "Yellow": "YellowBack", "Green": "GreenBack"}


def uv(lane, u, v):
    """Lane-local (u, v) in 0..1 -> atlas UV, INSET texels in from the lane's edges."""
    u0, v0, u1, v1 = LANES[lane]
    w, h = (u1 - u0) * SIZE, (v1 - v0) * SIZE
    ku, kv = INSET / SIZE, INSET / max(h, 1.0)
    return (u0 + (u1 - u0) * (ku + u * (1.0 - 2.0 * ku)), v0 + (v1 - v0) * (kv + v * (1.0 - 2.0 * kv)))
