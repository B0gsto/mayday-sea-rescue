"""Flat Lego palette for M_Prop_BuildSiteKit (same cells as M_Prop_JettyCrane; colours from src/shared/DockPieces.luau).

One 4 x 4 palette atlas (1024 px, 256 px cells) gives every mesh flat colours through one material, so a whole layer
is one draw call. Cell index = the order below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (250, 249, 245),   # 0  white
    (198, 202, 208),   # 1  light silver (saw blade, tools; round 3, was 163,162,165)
    (99, 95, 98),      # 2  dark bluish grey
    (46, 158, 68),     # 3  bright green (site kit r7: pallet A; was ink, unused here; r8 more saturated)
    (235, 30, 30),     # 4  red (brighter, round 2)
    (240, 127, 30),    # 5  orange (site kit r8: more saturated)
    (242, 194, 27),    # 6  Lego yellow #F2C21B (site kit r8; round 4 was 255,200,12)
    (142, 146, 152),   # 7  medium stone grey (rims, pillars, gables, steps)
    (40, 96, 208),     # 8  blue
    (172, 24, 30),     # 9  dark red (alternate roof courses)
    (176, 146, 100),   # 10 dark tan (plank seams)
    (212, 184, 132),   # 11 tan
    (105, 64, 40),     # 12 reddish brown
    (238, 160, 70),    # 13 orange-tan (boat ribs, fresh planks)
    (155, 203, 46),    # 14 lime (site kit r7: pallet C; was glass blue, unused here; r8 #9BCB2E)
    (42, 44, 48),      # 15 black (tyres)
]
WHITE, LBG, DBG, GREEN, RED, ORANGE, YELLOW, STONE, BLUE, RRED, DTAN, TAN, BROWN, RIB, LIME, BLACK = range(16)

CELL, GRID, SIZE = 256, 4, 1024


def write_maps(out_dir, name, set_name, size=SIZE):
    """Writes T_<name>_<set>_{ALB,NOR,RGH,MET}.png into out_dir (one flat palette set; no wear, no scans)."""
    import os
    from PIL import Image

    os.makedirs(out_dir, exist_ok=True)
    cell = size // GRID
    alb = Image.new("RGB", (size, size))
    px = alb.load()
    for i, rgb in enumerate(PALETTE):
        col, row = i % GRID, GRID - 1 - i // GRID     # row 0 of the image is the top; cell 0 is bottom-left in UV
        for y in range(row * cell, (row + 1) * cell):
            for x in range(col * cell, (col + 1) * cell):
                px[x, y] = rgb
    flat = {
        "NOR": (128, 128, 255),
        "RGH": (205, 205, 205),
        "MET": (0, 0, 0),
    }
    stem = "T_%s_%s_" % (name, set_name)
    alb.save(os.path.join(out_dir, stem + "ALB.png"))
    for kind, rgb in flat.items():
        Image.new("RGB", (size, size), rgb).save(os.path.join(out_dir, stem + kind + ".png"))
    return os.path.join(out_dir, stem + "ALB.png")
