"""Flat Lego palette for M_Prop_HubKit (BoardKit cells; light silver, blue and black swapped for green, sand and dark green).

One 4 x 4 palette atlas (1024 px, 256 px cells) gives every mesh flat colours through one material, so a whole layer
is one draw call. Cell index = the order below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (250, 249, 245),   # 0  white
    (92, 176, 66),     # 1  bright green (palms, bushes)
    (138, 138, 142),   # 2  dark bluish grey (two steps lighter since round 2: the rocks read as holes)
    (30, 44, 66),      # 3  ink / navy (windows, waterline)
    (235, 30, 30),     # 4  red (brighter, round 2)
    (250, 140, 30),    # 5  orange
    (255, 216, 0),     # 6  bright Lego yellow (BoardKit r2: 255,200,12 still read ochre under AgX)
    (168, 172, 178),   # 7  medium stone grey (rims, pillars, gables, steps; lighter, round 4)
    (150, 205, 240),   # 8  light glass blue (L10 panes; the code makes them clear)
    (172, 24, 30),     # 9  dark red (alternate roof courses)
    (176, 146, 100),   # 10 dark tan (plank seams)
    (212, 184, 132),   # 11 tan
    (105, 64, 40),     # 12 reddish brown
    (238, 160, 70),    # 13 orange-tan (boat ribs, fresh planks)
    (238, 214, 164),   # 14 warm sand
    (36, 122, 62),     # 15 dark green
]
WHITE, GREEN, DBG, INK, RED, ORANGE, YELLOW, STONE, GLASS, RRED, DTAN, TAN, BROWN, RIB, SAND, DGREEN = range(16)

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
