"""M_Prop_Chandlery_Stock atlas layout (pure python; imported by maketex.py and build.py).

T_ChandleryStock_Atlas_* is 2048 px, an 8 x 8 grid of 256 px cells. Each region is a cell rect (cx, cy, cw, ch), cy
counted from the bottom (V up). "tile" regions are periodic material tiles box-projected at `scale` metres per region
width (kit.face_uvs); "rope" regions are periodic rope tiles (U round the rope, V along: one tile = one lay length);
"fit" regions are painted decals (tin labels, book spines, box fronts, chart, covers) mapped exactly onto faces.
The API mirrors M_Prop_Chandlery/atlas.py (R, rect) so kit.py (imported read-only) can use this module as `atlas`.
"""
ATLAS = 2048
CELL = 256
GRID = 8
PAD_PX = 3

# key: (cx, cy, cw, ch, kind, scale_m, rgb sRGB, roughness, metal, pattern, signal)
R = {
    # cy 0: woods, metals, rubber
    "Pine":       (0, 0, 1, 1, "tile", 0.80, (168, 136, 100), 0.66, 0, "grain", False),
    "CrateWood":  (1, 0, 1, 1, "tile", 0.80, (138, 116, 90), 0.82, 0, "grain", False),
    "Galv":       (2, 0, 1, 1, "tile", 0.40, (194, 196, 194), 0.50, 1, "galv", False),
    "Brass":      (3, 0, 1, 1, "tile", 0.30, (222, 192, 134), 0.36, 1, "brass", False),
    "Boot":       (4, 0, 1, 1, "tile", 0.30, (54, 66, 58), 0.48, 0, "rubber", False),
    "Sole":       (5, 0, 1, 1, "tile", 0.25, (58, 52, 46), 0.84, 0, "tread", False),
    "Iron":       (6, 0, 1, 1, "tile", 0.60, (52, 50, 48), 0.72, 0, "iron", False),
    "Oar":        (7, 0, 1, 1, "tile", 1.20, (176, 140, 98), 0.40, 0, "grain", False),
    # cy 1: soft goods, paper, plastics
    "Card":       (0, 1, 1, 1, "tile", 0.30, (178, 150, 112), 0.90, 0, "paper", False),
    "Paper":      (1, 1, 1, 1, "tile", 0.20, (214, 206, 186), 0.88, 0, "paper", False),
    "Suede":      (2, 1, 1, 1, "tile", 0.20, (150, 120, 88), 0.92, 0, "linen", False),
    "BlackPlastic": (3, 1, 1, 1, "tile", 0.20, (46, 47, 50), 0.42, 0, "plastic", False),
    "Glass":      (4, 1, 1, 1, "tile", 0.30, (190, 196, 192), 0.10, 0, "glass", False),
    "Enamel":     (5, 1, 1, 1, "tile", 0.20, (206, 204, 196), 0.30, 0, "enamel", False),
    "LampGreen":  (6, 1, 1, 1, "tile", 0.30, (60, 84, 70), 0.38, 0, "paint", False),
    "Oilskin":    (7, 1, 1, 1, "tile", 0.40, (214, 178, 44), 0.42, 0, "wax", True),
    # cy 2: knit wools, cloth, signal orange
    "WoolNavy":   (0, 2, 1, 1, "tile", 0.12, (56, 64, 86), 0.96, 0, "knit", False),
    "WoolRust":   (1, 2, 1, 1, "tile", 0.12, (132, 86, 72), 0.96, 0, "knit", False),
    "WoolOat":    (2, 2, 1, 1, "tile", 0.12, (176, 162, 136), 0.96, 0, "knit", False),
    "WoolGreen":  (3, 2, 1, 1, "tile", 0.12, (82, 94, 76), 0.96, 0, "knit", False),
    "GloveGrey":  (4, 2, 1, 1, "tile", 0.15, (92, 96, 100), 0.80, 0, "linen", False),
    "SignalOrange": (5, 2, 1, 1, "tile", 0.30, (218, 96, 40), 0.55, 0, "plastic", True),
    "SignalRed":  (6, 2, 1, 1, "tile", 0.30, (186, 52, 44), 0.55, 0, "plastic", True),
    "Lead":       (7, 2, 1, 1, "tile", 0.15, (96, 98, 102), 0.62, 0, "iron", False),
    # cy 3: rope tiles (scale = lay length in rope diameters; hanks: one tile per minor circumference)
    "RopeManila": (0, 3, 1, 1, "rope", 4.5, (164, 141, 102), 0.82, 0, "three_strand", False),
    "RopeCream":  (1, 3, 1, 1, "rope", 4.5, (204, 196, 174), 0.66, 0, "three_strand", False),
    "RopeNavy":   (2, 3, 1, 1, "rope", 4.0, (60, 70, 98), 0.60, 0, "braid", False),
    "RopeRed":    (3, 3, 1, 1, "rope", 4.0, (138, 86, 78), 0.60, 0, "braid", False),
    "RopeGreen":  (4, 3, 1, 1, "rope", 4.0, (80, 106, 76), 0.62, 0, "braid", False),
    "HankManila": (5, 3, 1, 1, "hank", 1.0, (164, 141, 102), 0.82, 0, "three_strand", False),
    "HankCream":  (6, 3, 1, 1, "hank", 1.0, (204, 196, 174), 0.66, 0, "three_strand", False),
    "HankNavy":   (7, 3, 1, 1, "hank", 1.0, (60, 70, 98), 0.60, 0, "braid", False),
    # decals
    "TinLabels":  (0, 4, 8, 2, "fit", None, (200, 190, 170), 0.55, 0, "tins", False),    # 8 labels 512 x 256
    "Spines":     (0, 6, 4, 1, "fit", None, (120, 100, 80), 0.80, 0, "spines", False),  # 16 spines 64 x 256
    "Flares":     (4, 6, 2, 1, "fit", None, (200, 90, 50), 0.60, 0, "flares", True),    # 2 box fronts 256 x 256
    "Chart":      (6, 6, 2, 1, "fit", None, (214, 210, 194), 0.88, 0, "chart", False),  # 512 x 256 chart face
    "Boxes":      (0, 7, 4, 1, "fit", None, (178, 150, 112), 0.88, 0, "boxes", False),  # 4 box fronts 256 x 256
    "Covers":     (4, 7, 2, 1, "fit", None, (60, 70, 90), 0.80, 0, "covers", False),    # 2 book / receipt covers
    "VHF":        (6, 7, 1, 1, "fit", None, (50, 52, 54), 0.45, 0, "vhf", False),       # handheld radio face
    "Tags":       (7, 7, 1, 1, "fit", None, (214, 204, 178), 0.90, 0, "tags", False),   # 4 shelf-edge tickets 256 x 64
}

N_TINS = 8
TIN_NAMES = [   # (brand, product, line, size, band rgb, ground rgb) -- invented, no real brands
    ("KESTREL", "YACHT VARNISH", "High Gloss  Marine Grade", "750 ml", (140, 92, 54), (214, 200, 170)),
    ("KESTREL", "SATIN VARNISH", "Spar & Brightwork", "750 ml", (96, 76, 58), (206, 196, 172)),
    ("TIDEWATER", "TEAK OIL", "Deck & Trim Restorer", "1 litre", (110, 96, 62), (196, 184, 150)),
    ("SEAGUARD", "ANTIFOULING", "Hard Racing  NAVY", "2.5 L", (54, 64, 92), (190, 192, 190)),
    ("SEAGUARD", "ANTIFOULING", "Eroding  RED OXIDE", "2.5 L", (128, 70, 60), (200, 194, 184)),
    ("SEAGUARD", "ANTIFOULING", "Eroding  BLACK", "2.5 L", (44, 46, 50), (186, 186, 182)),
    ("HALYARD", "DECK PAINT", "Non-Slip  Grey", "1 litre", (88, 96, 100), (204, 204, 196)),
    ("PORT HAVEN", "BOOT TOPPING", "Enamel  Signal White", "375 ml", (70, 90, 84), (214, 210, 196)),
]
N_SPINES = 16
SPINES = [   # (title, rgb) pilot books, almanacs, logbooks
    ("WEST COUNTRY PILOT", (60, 74, 98)), ("CHANNEL HARBOURS", (120, 60, 54)), ("TIDAL STREAM ATLAS", (66, 92, 78)),
    ("PORT HAVEN APPROACHES", (150, 128, 84)), ("LIGHTS & SIGNALS", (46, 52, 62)), ("NAUTICAL ALMANAC", (110, 46, 44)),
    ("CRUISING ASSOCIATION", (86, 98, 112)), ("SEAMANSHIP", (60, 54, 48)), ("SHIP'S LOG", (92, 64, 46)),
    ("IRISH SEA PILOT", (70, 98, 92)), ("NORTH BRITTANY", (130, 106, 70)), ("KNOTS & SPLICES", (148, 80, 60)),
    ("COLLISION REGS", (48, 60, 86)), ("RADIO PROCEDURE", (100, 104, 90)), ("TIDE TABLES 2026", (164, 144, 98)),
    ("FIRST AID AFLOAT", (124, 58, 56)),
]
N_BOXES = 4
BOXES = ["GALV SHACKLES  8 mm", "S/S BLOCKS  SINGLE", "WHIPPING TWINE", "FENDER LINES  10 mm"]
N_FLARES = 2
N_COVERS = 2
N_TAGS = 4


def rect(key):
    """UV rect (u0, v0, u1, v1) of a region, padded."""
    cx, cy, cw, ch = R[key][:4]
    p = PAD_PX / ATLAS
    return (cx / GRID + p, cy / GRID + p, (cx + cw) / GRID - p, (cy + ch) / GRID - p)


def sub(key, i, n, cols=None, inset_px=2):
    """Sub-rect i of n equal slots of a decal region (row-major from the top-left when cols < n)."""
    cx, cy, cw, ch = R[key][:4]
    cols = cols or n
    rows = (n + cols - 1) // cols
    c, r = i % cols, i // cols
    u0, v0 = cx / GRID, cy / GRID
    du, dv = cw / GRID / cols, ch / GRID / rows
    p = inset_px / ATLAS
    top = v0 + ch / GRID
    return (u0 + c * du + p, top - (r + 1) * dv + p, u0 + (c + 1) * du - p, top - r * dv - p)


def tin_rect(i):
    return sub("TinLabels", i % N_TINS, N_TINS, cols=4)


def spine_rect(i):
    return sub("Spines", i % N_SPINES, N_SPINES)


def box_rect(i):
    return sub("Boxes", i % N_BOXES, N_BOXES)


def flare_rect(i):
    return sub("Flares", i % N_FLARES, N_FLARES)


def cover_rect(i):
    return sub("Covers", i % N_COVERS, N_COVERS)


def tag_rect(i):
    return sub("Tags", i % N_TAGS, N_TAGS, cols=1)
