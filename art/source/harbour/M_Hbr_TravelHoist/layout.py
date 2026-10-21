"""Shared atlas layout for M_Hbr_TravelHoist (2048 px; build.py and decals.py import it)."""

REG = {
    "paint":  (0.00, 0.00, 0.50, 0.50),      # 1024 px
    "steel":  (0.50, 0.00, 1.00, 0.50),      # 1024 px
    "rubber": (0.00, 0.50, 0.25, 0.75),
    "white":  (0.25, 0.50, 0.50, 0.75),
    "glass":  (0.50, 0.50, 0.75, 0.75),
    "hazard": (0.75, 0.50, 1.00, 0.75),
    "blue":   (0.00, 0.75, 0.25, 1.00),
    "orange": (0.25, 0.75, 0.50, 1.00),
    "sign":   (0.50, 0.75, 1.00, 1.00),      # 1024 x 512 px
}
SCALES = {"paint": 3.043, "steel": 2.783, "rubber": 1.637, "white": 1.713,
          "glass": 1.800, "hazard": 1.173, "sign": 2.297, "blue": 0.81, "orange": 0.81}
PAD = 0.003


def bounds(region):
    u0, v0, u1, v1 = REG[region]
    return u0 + PAD, v0 + PAD, u1 - PAD, v1 - PAD


def pixel_box(region, size=2048):
    """(left, top, right, bottom) in PIL pixels for the inset region."""
    u0, v0, u1, v1 = bounds(region)
    return (round(u0 * size), round((1 - v1) * size), round(u1 * size), round((1 - v0) * size))
