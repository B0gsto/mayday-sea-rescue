"""M_Prop_Chandlery shared prop atlas layout (pure python; imported by maketex.py and build.py).

T_ChandleryProps_Atlas_* is 2048 px, an 8 x 8 grid of 256 px cells. Each region is a cell rect (cx, cy, cw, ch),
cy counted from the bottom (V up). "tile" regions are periodic material tiles mapped by box projection at `scale`
metres per region width; "fit" regions are painted decals (tags, boards, radio face) mapped exactly onto one face.
T_ChandleryProps_Rope_* is 1024 px: 8 vertical strips of 128 px (U round the rope), each a 128 px tile repeated 8x in V.
"""
ATLAS = 2048
CELL = 256
GRID = 8

# key: (cx, cy, cw, ch, kind, scale_m, rgb sRGB, roughness, metal, pattern, signal)
R = {
    # cy 0: signal and garment fabrics
    "LJ_Orange":  (0, 0, 1, 1, "tile", 0.60, (226, 98, 34), 0.62, 0, "nylon", True),
    "HV_Yellow":  (1, 0, 1, 1, "tile", 0.60, (206, 214, 52), 0.66, 0, "nylon", True),
    "BuoyOrange": (2, 0, 1, 1, "tile", 0.50, (218, 92, 38), 0.38, 0, "pvc", True),
    "Foam":       (3, 0, 1, 1, "tile", 0.40, (212, 84, 40), 0.80, 0, "foam", True),
    "FW_Red":     (4, 0, 1, 1, "tile", 0.60, (140, 88, 81), 0.55, 0, "nylon", False),
    "FW_Navy":    (5, 0, 1, 1, "tile", 0.60, (50, 58, 82), 0.58, 0, "nylon", False),
    "FW_Grey":    (6, 0, 1, 1, "tile", 0.60, (74, 77, 80), 0.70, 0, "nylon", False),
    "DogCoat":    (7, 0, 1, 1, "tile", 0.30, (88, 92, 62), 0.48, 0, "wax", False),
    # cy 1: rubber, plastics, trims
    "Rubber":     (0, 1, 1, 1, "tile", 0.30, (44, 44, 46), 0.86, 0, "rubber", False),
    "Boot":       (1, 1, 1, 1, "tile", 0.30, (52, 64, 58), 0.50, 0, "rubber", False),
    "Webbing":    (2, 1, 1, 1, "tile", 0.15, (40, 42, 46), 0.78, 0, "webbing", False),
    "BlackPlastic": (3, 1, 1, 1, "tile", 0.20, (46, 47, 50), 0.42, 0, "plastic", False),
    "Tape":       (4, 1, 1, 1, "tile", 0.12, (178, 180, 182), 0.35, 0, "tape", False),
    "FenderPVC":  (5, 1, 1, 1, "tile", 0.50, (56, 68, 96), 0.32, 0, "pvc", False),
    "Plastic":    (6, 1, 1, 1, "tile", 0.40, (92, 108, 120), 0.48, 0, "plastic", False),
    "DressForm":  (7, 1, 1, 1, "tile", 0.30, (176, 164, 140), 0.88, 0, "linen", False),
    # cy 2: metals and woods
    "Galv":       (0, 2, 1, 1, "tile", 0.60, (196, 198, 196), 0.48, 1, "galv", False),
    "Stainless":  (1, 2, 1, 1, "tile", 0.30, (206, 206, 204), 0.30, 1, "brushed", False),
    "Brass":      (2, 2, 1, 1, "tile", 0.30, (226, 196, 136), 0.34, 1, "brass", False),
    "Chrome":     (3, 2, 1, 1, "tile", 0.30, (226, 226, 226), 0.12, 1, "smooth", False),
    "Pine":       (4, 2, 1, 1, "tile", 1.20, (164, 130, 96), 0.66, 0, "grain", False),
    "PaintBoard": (5, 2, 1, 1, "tile", 1.20, (52, 76, 70), 0.60, 0, "paint", False),
    "Ebony":      (6, 2, 1, 1, "tile", 0.50, (52, 44, 38), 0.45, 0, "grain", False),
    "Wicker":     (7, 2, 1, 1, "tile", 0.40, (166, 142, 104), 0.74, 0, "wicker", False),
    # cy 3: soft goods, radio
    "Tartan":     (0, 3, 1, 1, "tile", 0.50, (118, 78, 70), 0.92, 0, "tartan", False),
    "String":     (1, 3, 1, 1, "tile", 0.10, (196, 186, 160), 0.85, 0, "webbing", False),
    "Fleece":     (2, 3, 1, 1, "tile", 0.30, (140, 128, 112), 0.95, 0, "linen", False),
    "RadioBody":  (3, 3, 1, 1, "tile", 0.20, (58, 60, 62), 0.50, 0, "plastic", False),
    "Neoprene":   (4, 3, 1, 1, "tile", 0.20, (38, 40, 42), 0.70, 0, "rubber", False),
    "Zip":        (5, 3, 1, 1, "tile", 0.05, (48, 48, 50), 0.40, 0, "zip", False),
    "Sole":       (6, 3, 1, 1, "tile", 0.25, (60, 52, 46), 0.82, 0, "tread", False),
    "Card":       (7, 3, 1, 1, "tile", 0.30, (200, 186, 156), 0.90, 0, "paper", False),
    # decals
    "Tags":       (0, 4, 4, 1, "fit", None, (214, 204, 178), 0.90, 0, "tags", False),
    "Radio":      (4, 4, 2, 1, "fit", None, (50, 52, 54), 0.45, 0, "radio", False),
    "HornBoard":  (0, 6, 4, 2, "fit", None, (52, 76, 70), 0.60, 0, "hornboard", False),
    "SwatchBoard": (4, 6, 4, 2, "fit", None, (52, 76, 70), 0.55, 0, "swatch", False),
}
N_TAGS = 8            # tags in the Tags strip, each 128 x 256 px (0.045 x 0.09 m)
TAG_M = (0.045, 0.09)
RADIO_M = (0.26, 0.13)
BOARD_M = (1.2, 0.6)
PAD_PX = 3

# rope trim strips: (rgb, roughness, profile, hank)
ROPE_SIZE = 1024
ROPE_STRIPS = [
    ("Manila", (164, 141, 102), 0.82, "three_strand", False),
    ("Cream", (204, 196, 174), 0.66, "three_strand", False),
    ("NavyBraid", (60, 70, 98), 0.60, "braid", False),
    ("RedBraid", (134, 84, 76), 0.60, "braid", False),
    ("ManilaHank", (164, 141, 102), 0.82, "three_strand", True),
    ("CreamHank", (204, 196, 174), 0.66, "three_strand", True),
    ("NavyHank", (60, 70, 98), 0.60, "braid", True),
    ("GreenHank", (79, 107, 74), 0.66, "braid", True),
]
HANK_ROPES = 4        # mini ropes round a hank bundle


def rect(key):
    """UV rect (u0, v0, u1, v1) of a region, padded."""
    cx, cy, cw, ch = R[key][:4]
    p = PAD_PX / ATLAS
    return (cx / GRID + p, cy / GRID + p, (cx + cw) / GRID - p, (cy + ch) / GRID - p)


def tag_rect(i):
    u0, v0, u1, v1 = rect("Tags")
    w = (u1 - u0) / N_TAGS
    p = 2.0 / ATLAS
    return (u0 + i * w + p, v0 + p, u0 + (i + 1) * w - p, v1 - p)


def strip(i):
    """U range of rope strip i."""
    p = 1.5 / ROPE_SIZE
    return (i / 8.0 + p, (i + 1) / 8.0 - p)


def strip_index(name):
    return [s[0] for s in ROPE_STRIPS].index(name)
