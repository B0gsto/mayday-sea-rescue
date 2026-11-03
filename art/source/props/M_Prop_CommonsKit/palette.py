"""Flat Lego palette for M_Prop_CommonsKit: M_Prop_BoardKit's cells, two swapped (9 dark red -> bright green as in
M_Prop_SeaPlateKit; 13 orange-tan -> bright pink for flowers and the ice-cream cart; 3 ink -> gold for the statue).

One 8 x 8 palette atlas (1024 px, 128 px cells; r2, was 4 x 4) gives every mesh flat colours through one material, so a whole layer
is one draw call. Cell index = the order below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (250, 249, 245),   # 0  white
    (216, 221, 228),   # 1  light silver (saw blade, tools; BoardKit r3 rank-2 tile, was 198,202,208)
    (99, 95, 98),      # 2  dark bluish grey
    (214, 160, 40),    # 3  gold (CommonsKit: statue, flag finial; BoardKit's ink cell, unused here)
    (235, 30, 30),     # 4  red (brighter, round 2)
    (250, 140, 30),    # 5  orange
    (255, 216, 0),     # 6  bright Lego yellow (BoardKit r2: 255,200,12 still read ochre under AgX)
    (142, 146, 152),   # 7  medium stone grey (rims, pillars, gables, steps)
    (40, 96, 208),     # 8  blue
    (40, 168, 64),     # 9  bright green (CommonsKit: leaves, benches, flower bricks; SeaPlateKit's cell 9)
    (176, 146, 100),   # 10 dark tan (plank seams)
    (212, 184, 132),   # 11 tan
    (105, 64, 40),     # 12 reddish brown
    (255, 120, 180),   # 13 bright pink (CommonsKit: flowers, cart band, umbrella)
    (150, 205, 240),   # 14 light glass blue
    (42, 44, 48),      # 15 black (tyres)
    (242, 104, 84),    # 16 coral (r2: flag cloth default, picnic mat; icon salmon red)
    (66, 40, 28),      # 17 dark chocolate (r2: flower-bed soil)
    (190, 150, 235),   # 18 lilac (r2: flower heads, icon purple)
    (70, 140, 210),    # 19 deep water blue (r2: fountain second water tone)
]
WHITE, LBG, DBG, GOLD, RED, ORANGE, YELLOW, STONE, BLUE, GREEN, DTAN, TAN, BROWN, PINK, GLASS, BLACK = range(16)
CORAL, CHOC, LILAC, DEEP = range(16, 20)

CELL, GRID, SIZE = 128, 8, 1024     # r2: 8 x 8 cells (20 used) so the icon colours get their own cells


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
