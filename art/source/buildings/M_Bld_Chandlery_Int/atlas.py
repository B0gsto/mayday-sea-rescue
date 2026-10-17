"""H2 Chandlery interior atlas layout, shared by build.py (Blender) and maketex.py (system python3). No dependencies."""

JOINERY = {"Beam": (0.0, 0.25), "Plank": (0.25, 0.45), "Panel": (0.45, 0.75), "Rail": (0.75, 0.875), "Painted": (0.875, 1.0)}

DETAILS = {
    "Brass": (0.0, 0.875, 0.125, 1.0), "EnamelOut": (0.125, 0.875, 0.25, 1.0), "EnamelIn": (0.25, 0.875, 0.375, 1.0),
    "Iron": (0.375, 0.875, 0.5, 1.0), "Glow": (0.5, 0.875, 0.625, 1.0), "Flex": (0.625, 0.875, 0.6875, 1.0),
    "Rope": (0.6875, 0.875, 0.75, 1.0), "Mirror": (0.75, 0.875, 0.875, 1.0), "Hook": (0.875, 0.875, 1.0, 1.0),
    "CounterTop": (0.0, 0.75, 1.0, 0.875),
    "Chart": (0.0, 0.5, 0.5, 0.75),
    "Card0": (0.5, 0.5, 0.625, 0.75), "Card1": (0.625, 0.5, 0.75, 0.75), "Card2": (0.75, 0.5, 0.875, 0.75),
    "Card3": (0.875, 0.5, 1.0, 0.75),
    "Logbook": (0.5, 0.375, 0.75, 0.5), "TillKeys": (0.75, 0.375, 0.875, 0.5), "TillSign": (0.875, 0.375, 1.0, 0.5),
    "Slatwall": (0.5, 0.25, 0.75, 0.375),
    "Pack0": (0.75, 0.25, 0.8125, 0.375), "Pack1": (0.8125, 0.25, 0.875, 0.375), "Pack2": (0.875, 0.25, 0.9375, 0.375),
    "Pack3": (0.9375, 0.25, 1.0, 0.375),
    "Curtain": (0.0, 0.0, 0.125, 0.25), "Mat": (0.125, 0.125, 0.25, 0.25), "Paper": (0.125, 0.0625, 0.1875, 0.125),
    "Cloth": (0.1875, 0.0625, 0.25, 0.125), "Rubber": (0.125, 0.0, 0.1875, 0.0625),
    # wall posters and notices (aged paper; physical sizes in POSTER_M)
    "Tide": (0.25, 0.0, 0.4375, 0.25), "Lifeboat": (0.4375, 0.0, 0.625, 0.25), "Knots": (0.625, 0.0, 0.875, 0.25),
    "Notice0": (0.875, 0.125, 1.0, 0.25), "Notice1": (0.875, 0.0, 1.0, 0.125),
}
POSTER_M = {"Tide": (0.6, 0.8), "Lifeboat": (0.6, 0.8), "Knots": (0.75, 0.75), "Notice0": (0.3, 0.3), "Notice1": (0.3, 0.3)}

# Pine floor: 4 wear zones as full-width strips (u wraps, 2.4 m along the boards), each 4 boards (0.6 m) across;
# the same boards in every strip, only the wear differs, so zone changes along a board never show a seam
PINE_ZONES = {"Clean": (0.75, 1.0), "Traffic": (0.5, 0.75), "Path": (0.25, 0.5), "Edge": (0.0, 0.25)}
PINE_U_M, PINE_BAND_M = 2.4, 0.6

# Lining: u tiles 1.2 m (10 boards) in every strip; v is zoned: Wall = one storey floor-to-floor (z above the floor
# -0.02 .. 3.23 m), Clean = board pattern constant along v (ceilings, roof boarding, reveals), Sill = under the sashes
LINING_U_M = 1.2
LINING = {"Wall": (0.25, 1.0), "Clean": (0.125, 0.25), "Sill": (0.0, 0.125)}
LINING_WALL_Z = (-0.02, 3.23)
for i in range(16):   # drawer label fronts, 4 x 4 grid in (0, 0.25) .. (0.5, 0.5)
    c, r = i % 4, i // 4
    DETAILS["Drawer%d" % i] = (c * 0.125, 0.25 + r * 0.0625, (c + 1) * 0.125, 0.25 + (r + 1) * 0.0625)

