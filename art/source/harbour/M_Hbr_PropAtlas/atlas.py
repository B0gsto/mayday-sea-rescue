"""HP2a harbour prop atlas layout (pure python; imported by maketex.py, props.py and render.py).

Two sets shared by every HP2a prop (docs/12 2.3): T_HbrProps_Metal_* (cast iron, galvanised, chain, stainless, housing
paint, the lifebuoy sign) and T_HbrProps_Rope_* (rope tiles, PVC / rubber / HDPE plastics, the SOLAS ring, alpha net
cards). Masters 2048 (the Poly Haven scans are 2k), exported at 1024 to assets/textures/M_Hbr_PropAtlas/.
Each set is an 8 x 8 grid of cells; a region is (cx, cy, cw, ch, kind, scale_m, set, signal), cy counted from the
bottom (V up). kind "tile": periodic material box-projected at scale_m metres per region (props kit face_uvs);
"rope": periodic rope tile (U round the rope, V along, one tile = scale_m rope diameters of lay); "fit": decal mapped
exactly onto faces; "net": alpha net card tile (scale_m metres per region).
"""
MASTER = 2048
EXPORT = 1024
GRID = 8
PAD_PX = 3
NAME = "HbrProps"
ATLAS_ASSET = "M_Hbr_PropAtlas"

R = {
    # ---------------- Metal set
    "IronBlack":  (0, 0, 1, 1, "tile", 0.45, "Metal", False),   # chipped black paint over rust (bollards)
    "IronWorn":   (1, 0, 1, 1, "tile", 0.45, "Metal", False),   # rope-polished neck band: bare iron + rust, horizontal rub bands
    "IronRust":   (2, 0, 1, 1, "tile", 0.50, "Metal", False),   # rusted foot, salt crust
    "Galv":       (3, 0, 1, 1, "tile", 0.35, "Metal", False),   # weathered hot-dip galvanised
    "GalvRust":   (4, 0, 1, 1, "tile", 0.35, "Metal", False),   # galvanised with rust bleed and white rust
    "Chain":      (5, 0, 1, 1, "tile", 0.20, "Metal", False),   # rusted mooring chain
    "Stainless":  (6, 0, 1, 1, "tile", 0.25, "Metal", False),   # brushed stainless (hinges, bolts, bracket)
    "BlackPaint": (7, 0, 1, 1, "tile", 0.50, "Metal", False),   # satin black painted steel post
    "HousingRed": (0, 1, 1, 1, "tile", 0.92, "Metal", True),    # red GRP lifebuoy cabinet (signal)
    "Concrete":   (1, 1, 1, 1, "tile", 0.60, "Metal", False),   # quay concrete footing / creel ballast
    "Sign":       (0, 2, 2, 1, "fit", None, "Metal", True),     # LIFEBUOY sign plate 512 x 256
    # ---------------- Rope set (U round, V along)
    "RopeBlue":   (0, 0, 1, 1, "rope", 4.5, "Rope", False),     # sun-faded blue polypropylene, three-strand
    "RopeOrange": (1, 0, 1, 1, "rope", 4.5, "Rope", True),      # orange polysteel, three-strand
    "RopeBuff":   (2, 0, 1, 1, "rope", 4.5, "Rope", False),     # old buff / natural, three-strand
    "RopeBraid":  (3, 0, 1, 1, "rope", 4.0, "Rope", False),     # grimy white braid-on-braid mooring line
    "RopeThrow":  (4, 0, 1, 1, "rope", 4.0, "Rope", True),      # yellow floating throw line
    "RopeBlack":  (5, 0, 1, 1, "rope", 4.5, "Rope", False),     # black pot rope / bridles
    "PVCWhite":   (0, 1, 1, 1, "tile", 0.40, "Rope", False),    # white PVC fender
    "PVCNavy":    (1, 1, 1, 1, "tile", 0.40, "Rope", False),    # navy PVC fender
    "BallOrange": (2, 1, 1, 1, "tile", 0.40, "Rope", True),     # orange ball fender (signal)
    "Rubber":     (3, 1, 1, 1, "tile", 0.40, "Rope", False),    # tyre sidewall rubber
    "Tread":      (4, 1, 1, 1, "tile", 0.30, "Rope", False),    # worn tyre tread
    "FishBlue":   (5, 1, 1, 1, "tile", 0.84, "Rope", False),    # HDPE fish box, faded blue
    "FishRed":    (6, 1, 1, 1, "tile", 0.84, "Rope", True),     # HDPE fish box, red (signal-mask: real HDPE red)
    "PotCoat":    (7, 1, 1, 1, "tile", 0.30, "Rope", False),    # black plastic-coated steel creel frame
    "SOLAS":      (0, 2, 1, 1, "tile", 0.40, "Rope", True),     # SOLAS orange lifebuoy shell
    "Retro":      (1, 2, 1, 1, "tile", 0.10, "Rope", False),    # SOLAS retro-reflective tape
    "Float":      (2, 2, 1, 1, "tile", 0.30, "Rope", True),     # trawl floats
    "PotBase":    (3, 2, 1, 1, "tile", 0.80, "Rope", False),    # moulded rubber pot base
    "NetDense":   (4, 2, 1, 1, "tile", 0.40, "Rope", False),    # opaque core of a heaped net (many layers)
    "NetGreen":   (0, 4, 2, 2, "net", 0.60, "Rope", False),     # trawl net, green PE twine (alpha)
    "NetBlue":    (2, 4, 2, 2, "net", 0.40, "Rope", False),     # creel netting, blue (alpha)
    "NetOrange":  (4, 4, 2, 2, "net", 0.60, "Rope", True),      # trawl net, orange (alpha)
    "NetBlack":   (6, 4, 2, 2, "net", 0.40, "Rope", False),     # inkwell pot netting, black (alpha)
    # HP2a-fix decals (U once round the body, V along the lathe profile / round the ring section)
    "RingFit":    (0, 3, 4, 1, "fit", None, "Rope", True),      # SOLAS ring shell with the 4 retro bands painted in
    "FenderWhite": (0, 6, 2, 2, "fit", None, "Rope", False),    # white PVC cylinder fender body (seams, scuffs, waterline)
    "FenderNavy": (2, 6, 2, 2, "fit", None, "Rope", False),     # navy PVC cylinder fender body
    "BallFit":    (4, 6, 4, 2, "fit", None, "Rope", True),      # orange ball fender body (pole to pole)
}
SETS = ("Metal", "Rope")
ALPHA_REGIONS = ("NetGreen", "NetBlue", "NetOrange", "NetBlack")


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
