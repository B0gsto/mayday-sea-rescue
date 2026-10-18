"""E1 hand-held rescue kit atlas layout (docs/12 2.8; pure python, imported by maketex.py and kit.py).

One shared kit atlas, two sets, both with _Wet: T_Kit_Soft_* (pack cloth, webbing, foam, rope, foil, PVC) and
T_Kit_Hard_* (moulded plastics, metal fittings, labels, lenses). Masters 2048 (8 x 8 grid, 256 px cells), shipped at
1024 (128 px cells) to assets/textures/M_Kit_Atlas/. Tile regions are periodic materials at scale_m metres per cell:
0.36 m per 128 px cell = 118 px/stud at the shipping size (hero close-up tier 100 to 128). Region tuple:
(cx, cy, cw, ch, kind, scale_m, set, signal), cy counted from the bottom (V up). kind tile / rope / fit as in the
HP2a harbour prop atlas (art/source/harbour/M_Hbr_PropAtlas/atlas.py), whose geometry helpers kit.py reuses.
Signal colours (docs/05 3.2): SOLAS orange for casualty-contact items (lifebuoy, rescue tube, throw bag, strobe),
Hi-Vis yellow + dark navy for crew kit (first aid and oxygen bags, VHF), Distress red for flares.
"""
MASTER = 2048
EXPORT = 1024
GRID = 8
PAD_PX = 3
NAME = "Kit"
ATLAS_ASSET = "M_Kit_Atlas"
T = 0.36

R = {
    # ---------------- Soft set
    "SolasNylon": (0, 0, 1, 1, "tile", T, "Soft", True),      # SOLAS orange 1000D pack cloth (throw bag)
    "NavyNylon":  (1, 0, 1, 1, "tile", T, "Soft", False),     # dark navy pack cloth (bag bases, panels)
    "HiVisNylon": (2, 0, 1, 1, "tile", T, "Soft", True),      # hi-vis yellow coated nylon (crew bags)
    "Webbing":    (3, 0, 1, 1, "tile", 0.14, "Soft", False),  # black 25 mm nylon webbing, twill
    "Retro":      (4, 0, 1, 1, "tile", 0.10, "Soft", False),  # retro-reflective silver tape (prismatic)
    "ZipBlack":   (5, 0, 1, 1, "tile", 0.10, "Soft", False),  # coil zip and edge binding
    "FoamSolas":  (6, 0, 1, 1, "tile", T, "Soft", True),      # SOLAS orange vinyl-skinned closed-cell foam (tube)
    "FoilGold":   (7, 0, 1, 1, "tile", T, "Soft", False),     # metallised PET foil, gold side (crinkled)
    "FoilSilver": (0, 1, 1, 1, "tile", T, "Soft", False),     # metallised PET foil, silver side
    "MaskPVC":    (1, 1, 1, 1, "tile", 0.20, "Soft", False),  # clear green-tint PVC (mask, reservoir bag; opaque approx)
    "TubeGreen":  (2, 1, 1, 1, "tile", 0.10, "Soft", False),  # green oxygen tubing
    "RopeThrow":  (3, 1, 1, 1, "rope", 8.0, "Soft", True),    # yellow floating polypropylene braid
    "RopeGrab":   (4, 1, 1, 1, "rope", 8.0, "Soft", False),   # white polyester grab line, grubby
    "CrossPatch": (5, 1, 1, 1, "fit", None, "Soft", True),    # first aid patch: white cross on green (generic)
    "OxyPatch":   (6, 1, 2, 1, "fit", None, "Soft", True),    # OXYGEN patch, white on navy with a green border
    "RingFit":    (0, 2, 6, 1, "fit", None, "Soft", True),    # lifebuoy shell, 4 retro bands, scuffs (U round, V round section)
    # ---------------- Hard set
    "VHFBody":    (0, 0, 1, 1, "tile", T, "Hard", False),     # dark grey rubberised polycarbonate
    "HiVisABS":   (1, 0, 1, 1, "tile", T, "Hard", True),      # hi-vis yellow moulded plastic
    "BlackABS":   (2, 0, 1, 1, "tile", T, "Hard", False),     # black moulded plastic (caps, buckles, clips)
    "Rubber":     (3, 0, 1, 1, "tile", T, "Hard", False),     # black rubber (antenna, grips)
    "Stainless":  (4, 0, 1, 1, "tile", 0.25, "Hard", False),  # brushed stainless (snap hooks, rings)
    "Brass":      (5, 0, 1, 1, "tile", 0.25, "Hard", False),  # chromed brass oxygen fittings
    "CylWhite":   (6, 0, 1, 1, "tile", T, "Hard", False),     # white painted aluminium cylinder, scuffed
    "GreyABS":    (7, 0, 1, 1, "tile", T, "Hard", False),     # grey valve guard plastic
    "FlareRed":   (0, 1, 1, 1, "tile", T, "Hard", True),      # distress red plastic flare tube
    "SolasABS":   (1, 1, 1, 1, "tile", T, "Hard", True),      # SOLAS orange moulded plastic (strobe, buoy light)
    "LensClear":  (2, 1, 1, 1, "tile", 0.15, "Hard", False),  # frosted clear polycarbonate lens (Neon in game)
    "LensRed":    (3, 1, 1, 1, "tile", 0.15, "Hard", True),   # red flare head / striker composition (Neon in game)
    "VHFFace":    (0, 2, 2, 2, "fit", None, "Hard", False),   # VHF front: LCD, keypad (generic labels, CH 16)
    "CylLabel":   (2, 2, 2, 1, "fit", None, "Hard", True),    # MEDICAL OXYGEN label band, green hazard diamond
    "HandLabel":  (4, 2, 2, 1, "fit", None, "Hard", True),    # hand flare instruction label (generic)
    "ParaLabel":  (6, 2, 2, 1, "fit", None, "Hard", True),    # parachute rocket instruction label (generic)
}
SETS = ("Soft", "Hard")
ALPHA_REGIONS = ()


def rect(key):
    """UV rect (u0, v0, u1, v1) of a region inside its set, padded."""
    cx, cy, cw, ch = R[key][:4]
    p = PAD_PX / MASTER
    return (cx / GRID + p, cy / GRID + p, (cx + cw) / GRID - p, (cy + ch) / GRID - p)


def set_of(key):
    return R[key][6]


def kind(key):
    return R[key][4]


def scale(key):
    return R[key][5]
