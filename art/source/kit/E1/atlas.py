"""E1b hand-held rescue kit atlas layout (docs/12 2.8; pure python, imported by maketex.py and kitgeo.py).

E1b split (first-person hero kit, seen within 1 m): the E1 Soft set could not hold hero density for the cloth, rope
and foil, so the kit atlas M_Kit_Atlas now has FOUR sets, each 2048 master / 1024 ship, all with _Wet ALB, RGH, NOR:
  T_Kit_Cloth_*  pack cloth, webbing, sewn retro tape, seams, zips, foam, cords, patches   (4 x 4 grid, 256 px cells)
  T_Kit_Soft_*   lifebuoy shell (fit), ropes, clips, moulded PE                             (4 x 4 grid, 256 px cells)
  T_Kit_Foil_*   metallised PET foil, gold and silver, two crinkle variants each          (2 x 2 grid, 512 px cells)
  T_Kit_Hard_*   moulded plastics, metal, knurl, lenses, labels, VHF face, mask PVC       (8 x 8 grid, 128 px cells)
Ship texel density (1 stud = 1/3 m): Cloth tiles 0.25 m / 256 px = 341 px/stud (weave resolvable), strips (seam, zip, retro, webbing)
run 4 widths per tile (far above), Foil 0.45 m / 512 px = 379 px/stud, Hard tiles 0.24 m / 128 px = 178 px/stud,
lifebuoy shell fit 1024 x 256 px over 1.88 m x 0.45 m = 180 / 190 px/stud. All at or above the 100-128 hero floor.
Region tuple: (cx, cy, cw, ch, kind, scale_m, set, signal), cy counted from the bottom (V up), cells of the set grid.
kind tile (periodic, scale_m per cell), strip (periodic along U, one strip width across V; ribbon() runs STRIP_K
widths per tile), rope (tools/blender/rope.py convention: scale_m diameters per tile along the rope), fit (once).
"""
MASTER = 2048
EXPORT = 1024
PAD_PX = 4
NAME = "Kit"
ATLAS_ASSET = "M_Kit_Atlas"
GRIDS = {"Cloth": 4, "Soft": 4, "Foil": 2, "Hard": 8}
GRID = 8          # legacy default (Hard)
T = 0.25          # cloth tile
TH = 0.24         # hard tile
TF = 0.45         # foil tile
STRIP_K = 4.0     # strip tiles span 4 strip widths along the length

R = {
    # ---------------- Cloth set (4 x 4)
    "SolasNylon": (0, 0, 1, 1, "tile", T, "Cloth", True),     # SOLAS orange coated ballistic nylon (throw bag)
    "HiVisNylon": (1, 0, 1, 1, "tile", T, "Cloth", True),     # hi-vis yellow coated nylon (crew bags)
    "NavyNylon":  (2, 0, 1, 1, "tile", T, "Cloth", True),    # dark navy pack cloth (bases, panels)
    "Webbing":    (3, 0, 1, 1, "strip", None, "Cloth", False),  # black 25 mm nylon webbing, twill, edge selvedge
    "RetroSewn":  (0, 1, 1, 1, "strip", None, "Cloth", False),  # sewn-on retroreflective tape, worn, edge stitching
    "ZipBlack":   (1, 1, 1, 1, "strip", None, "Cloth", False),  # coil zip, tape and stitching
    "SeamSolas":  (2, 1, 1, 1, "strip", None, "Cloth", True),   # orange folded seam with lock-stitch line
    "SeamHiVis":  (3, 1, 1, 1, "strip", None, "Cloth", True),   # hi-vis folded seam with lock-stitch line
    "SeamNavy":   (0, 2, 1, 1, "strip", None, "Cloth", True),  # navy binding / seam with stitch line
    "FoamSolas":  (1, 2, 1, 1, "tile", T, "Cloth", True),     # SOLAS orange vinyl-skinned closed-cell foam (tube)
    "FoamSeam":   (2, 2, 1, 1, "strip", None, "Cloth", True),   # heat-welded vinyl seam bead on the rescue tube
    "CordYellow": (3, 2, 1, 1, "rope", 8.0, "Cloth", True),   # yellow floating braid (throw bag line)
    "CordBlack":  (0, 3, 1, 1, "rope", 8.0, "Cloth", False),  # black drawcord braid
    "CrossPatch": (1, 3, 1, 1, "fit", None, "Cloth", True),   # first aid patch: white cross on green, stitched border
    "OxyPatch":   (2, 3, 2, 1, "fit", None, "Cloth", True),   # OXYGEN patch 2:1, white on navy, green border
    # ---------------- Soft set (4 x 4)
    "RingFit":    (0, 0, 4, 1, "fit", None, "Soft", True),    # lifebuoy shell: U round the ring, V round the section
    "RopeGrab":   (0, 1, 1, 1, "rope", 8.0, "Soft", False),   # white polyester grab line, grubby
    "RopeThrow":  (1, 1, 1, 1, "rope", 8.0, "Soft", True),    # yellow floating polypropylene braid (throw line)
    "ClipWhite":  (2, 1, 1, 1, "tile", 0.10, "Soft", False),  # white moulded grab-line clips (lifebuoy)
    "RopeOrange": (3, 1, 1, 1, "rope", 8.0, "Soft", True),    # orange lanyard / buoyant line
    "SolasPE":    (3, 2, 1, 1, "tile", 0.20, "Soft", True),   # SOLAS orange moulded PE (light bracket on the ring)
    # ---------------- Foil set (2 x 2)
    "FoilGoldA":   (0, 0, 1, 1, "tile", TF, "Foil", True),   # metallised PET, gold side, crinkle A
    "FoilSilverA": (1, 0, 1, 1, "tile", TF, "Foil", False),   # silver side, crinkle A
    "FoilGoldB":   (0, 1, 1, 1, "tile", TF, "Foil", True),   # gold, crinkle B (alternates per tile)
    "FoilSilverB": (1, 1, 1, 1, "tile", TF, "Foil", False),   # silver, crinkle B
    # ---------------- Hard set (8 x 8)
    "VHFBody":    (0, 0, 1, 1, "tile", TH, "Hard", False),    # dark grey rubberised polycarbonate
    "HiVisABS":   (1, 0, 1, 1, "tile", TH, "Hard", True),     # hi-vis yellow moulded plastic
    "BlackABS":   (2, 0, 1, 1, "tile", TH, "Hard", False),    # black moulded plastic (buckles, sliders, clips)
    "Rubber":     (3, 0, 1, 1, "tile", TH, "Hard", False),    # black rubber
    "Stainless":  (4, 0, 1, 1, "tile", 0.15, "Hard", False),  # brushed stainless (snap hooks, rings)
    "Brass":      (5, 0, 1, 1, "tile", 0.15, "Hard", False),  # chromed brass oxygen fittings
    "CylWhite":   (6, 0, 1, 1, "tile", TH, "Hard", False),    # white painted aluminium cylinder, scuffed
    "GreyABS":    (7, 0, 1, 1, "tile", TH, "Hard", False),    # grey valve guard plastic
    "FlareRed":   (0, 1, 1, 1, "tile", TH, "Hard", True),     # distress red plastic flare tube
    "SolasABS":   (1, 1, 1, 1, "tile", TH, "Hard", True),     # SOLAS orange moulded plastic (strobe, buoy light)
    "LensClear":  (2, 1, 1, 1, "tile", 0.10, "Hard", False),  # frosted clear polycarbonate lens (Neon in game)
    "LensRed":    (3, 1, 1, 1, "tile", 0.10, "Hard", True),   # red flare head composition (Neon in game)
    "Knurl":      (4, 1, 1, 1, "tile", 0.04, "Hard", False),  # black knurled cap grip (diamond knurl)
    "LensStrobe": (5, 1, 1, 1, "fit", None, "Hard", False),   # strobe dome: fresnel rings, xenon tube, reflector
    "ScrewHead":  (6, 1, 1, 1, "fit", None, "Hard", False),   # stainless pan-head cross screw (lathe cap)
    "WhiteABS":   (7, 1, 1, 1, "tile", TH, "Hard", False),    # white moulded plastic (flare caps, buttons)
    "VHFFace":    (0, 2, 2, 2, "fit", None, "Hard", False),   # VHF front: LCD, keypad (generic labels, CH 16)
    "CylLabel":   (2, 2, 4, 2, "fit", None, "Hard", True),    # MEDICAL OXYGEN label band, green hazard diamond
    "StrobeLabel": (6, 2, 2, 2, "fit", None, "Hard", True),   # strobe front label (generic invented text)
    "HandLabel":  (0, 4, 4, 2, "fit", None, "Hard", True),    # hand flare instruction label (generic invented text)
    "ParaLabel":  (4, 4, 2, 4, "fit", None, "Hard", True),    # parachute rocket instruction label (generic)
    "MaskPVC":    (0, 6, 1, 1, "tile", 0.20, "Hard", False),  # clear green-tint PVC (mask, reservoir bag)
    "TubeGreen":  (1, 6, 1, 1, "tile", 0.10, "Hard", False),  # green oxygen tubing
    "WebbingS":   (2, 6, 1, 1, "strip", None, "Hard", False),  # elastic mask head strap
}
SETS = ("Cloth", "Soft", "Foil", "Hard")
ALPHA_REGIONS = ()


def grid(key):
    return GRIDS[R[key][6]]


def cell_px(set_name, size=MASTER):
    return size // GRIDS[set_name]


def rect(key):
    """UV rect (u0, v0, u1, v1) of a region inside its set, padded."""
    cx, cy, cw, ch = R[key][:4]
    g = grid(key)
    p = PAD_PX / MASTER
    return (cx / g + p, cy / g + p, (cx + cw) / g - p, (cy + ch) / g - p)


def set_of(key):
    return R[key][6]


def kind(key):
    return R[key][4]


def scale(key):
    return R[key][5]
