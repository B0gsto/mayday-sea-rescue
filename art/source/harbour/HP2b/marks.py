"""HP2b buoy table (pure Python, shared by buoylib.py in Blender and compose.py): docs/12 2.3 rows M_Hbr_MooringBuoy,
M_Hbr_PickupBuoy and M_Hbr_NavMark_* (IALA Region A).

IALA sources (checked 2026-10-18):
  cardinals   https://en.wikipedia.org/wiki/Cardinal_mark (IALA MBS: colours, topmarks, VQ / Q rhythms)
  lateral     https://en.wikipedia.org/wiki/Lateral_mark (Region A: port red can, starboard green cone, any rhythm but Fl(2+1))
  isolated    https://ialacolreg.com/en/iala/iala-isolated-danger (black, red bands, two black balls, white Fl(2))
  safe water  https://en.wikipedia.org/wiki/Safe_water_mark (red/white vertical stripes, red ball, Iso / Oc / LFl 10s / Mo(A))
Heights are metres above the waterline (z 0 = ATT_WaterLine), Blender Z up; the buoy axis is the Z axis.
"""

# sRGB 0..1 paint colours, already weathered a step (faded marine enamel, not catalogue RAL)
RED = (0.66, 0.20, 0.17)
GREEN = (0.16, 0.40, 0.27)
BLACK = (0.17, 0.17, 0.175)
YELLOW = (0.84, 0.66, 0.20)
WHITE = (0.86, 0.85, 0.81)
ORANGE = (0.86, 0.38, 0.16)
BUOY_YELLOW = (0.86, 0.70, 0.22)

LENS = {"R": (0.78, 0.22, 0.18), "G": (0.25, 0.66, 0.38), "W": (0.88, 0.88, 0.84)}

# Pillar body: band edges on the visible structure (float top 0.56 to platform 2.67)
LOW_BAND, HIGH_BAND = 0.95, 1.85
MID = 1.35

# light: IALA characteristic, colour, Studio rhythm as (on, off) seconds for one period (the game loops it)
def _q(n, period, extra=None):
    seq = []
    for i in range(n):
        seq += [0.3, 0.7] if i < n - 1 else [0.3]
    if extra:
        seq += [0.7] + list(extra)
    used = sum(seq)
    seq.append(round(period - used, 2))
    return seq


NAVMARKS = {
    "Port": dict(label="Port hand lateral (IALA A)", bands=[(-99, 99, RED)], top="can", top_col=RED,
                 light="Fl R 4s", lens="R", rhythm=[0.5, 3.5],
                 note="red pillar, single red can topmark; Region A port mark (leave to port going upstream)"),
    "Starboard": dict(label="Starboard hand lateral (IALA A)", bands=[(-99, 99, GREEN)], top="cone", top_col=GREEN,
                      light="Fl G 5s", lens="G", rhythm=[0.5, 4.5],
                      note="green pillar, single green cone point up"),
    "North": dict(label="North cardinal", bands=[(-99, MID, YELLOW), (MID, 99, BLACK)], top="cones_up", top_col=BLACK,
                  light="Q W", lens="W", rhythm=[0.3, 0.7],
                  note="black above yellow; two black cones both point up; Q = 60 flashes a minute (VQ 120 also allowed)"),
    "East": dict(label="East cardinal", bands=[(-99, LOW_BAND, BLACK), (LOW_BAND, HIGH_BAND, YELLOW), (HIGH_BAND, 99, BLACK)],
                 top="cones_base", top_col=BLACK, light="Q(3) W 10s", lens="W", rhythm=_q(3, 10.0),
                 note="black with a broad yellow band; cones base to base; 3 quick flashes every 10 s (VQ(3) 5s also allowed)"),
    "South": dict(label="South cardinal", bands=[(-99, MID, BLACK), (MID, 99, YELLOW)], top="cones_down", top_col=BLACK,
                  light="Q(6)+LFl W 15s", lens="W", rhythm=_q(6, 15.0, extra=[2.0]),
                  note="yellow above black; cones both point down; 6 quick + 1 long flash (2 s) every 15 s (VQ(6)+LFl 10s allowed)"),
    "West": dict(label="West cardinal", bands=[(-99, LOW_BAND, YELLOW), (LOW_BAND, HIGH_BAND, BLACK), (HIGH_BAND, 99, YELLOW)],
                 top="cones_point", top_col=BLACK, light="Q(9) W 15s", lens="W", rhythm=_q(9, 15.0),
                 note="yellow with a broad black band; cones point to point; 9 quick flashes every 15 s (VQ(9) 10s allowed)"),
    "IsolatedDanger": dict(label="Isolated danger", bands=[(-99, LOW_BAND, BLACK), (LOW_BAND, HIGH_BAND, RED), (HIGH_BAND, 99, BLACK)],
                           top="balls2", top_col=BLACK, light="Fl(2) W 5s", lens="W", rhythm=[0.4, 0.6, 0.4, 3.6],
                           note="black with one broad red band; two black balls; white group of two flashes"),
    "SafeWater": dict(label="Safe water", bands="stripes", top="ball", top_col=RED, light="LFl W 10s", lens="W",
                      rhythm=[2.0, 8.0], note="red and white vertical stripes; single red ball; long flash (2 s) every 10 s"),
    "Bell": dict(label="Bell buoy (port hand lateral, IALA A)", bands=[(-99, 99, RED)], top="can", top_col=RED,
                 light="Fl(2) R 10s", lens="R", rhythm=[0.5, 1.0, 0.5, 8.0], bell=True,
                 note="red pillar with a wave-rung bell and four hanging clappers, red can topmark; "
                      "own rhythm so it reads apart from the plain port buoy"),
}

STRIPES = 8          # safe water: 4 red + 4 white vertical stripes round the buoy

MOORINGS = {
    "MooringBuoy": dict(label="Swing mooring buoy", colour=BUOY_YELLOW, d=0.90),
    "PickupBuoy": dict(label="Pick-up buoy", colour=ORANGE, d=0.60),
}

WATERLINE = 0.0
WEED_TOP = 0.07       # weed band top edge (mean) above the waterline: wave wash keeps it green a little above
WEED_BOTTOM = -0.55   # below this barnacles and fouling take over


def asset_name(kind):
    return "M_Hbr_NavMark_" + kind if kind in NAVMARKS else "M_Hbr_" + kind


def tex_name(kind):
    return ("NavMark" + kind) if kind in NAVMARKS else kind


ALL = list(NAVMARKS) + list(MOORINGS)
