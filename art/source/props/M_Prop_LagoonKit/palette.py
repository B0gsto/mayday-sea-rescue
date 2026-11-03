"""Flat Lego palette for M_Prop_LagoonKit (the HubKit cells; orange, glass, dark red and ribs swapped for blue, aqua, teal and coral).

One 8 x 8 palette atlas (1024 px, 128 px cells, 26 used) gives every mesh flat colours through one material, so a whole layer
is one draw call. Cell index = the order below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (250, 249, 245),   # 0  white (marble, stripes)
    (92, 176, 66),     # 1  bright green (palms, leaves)
    (122, 122, 128),   # 2  dark grey (rock lower tier)
    (30, 44, 66),      # 3  ink / navy (iron, slots, eyes)
    (235, 30, 30),     # 4  red
    (70, 90, 225),     # 5  agapanthus blue
    (255, 216, 0),     # 6  bright Lego yellow (brass, parasol)
    (160, 162, 168),   # 7  stone grey (rock upper tier, plinth)
    (164, 224, 220),   # 8  aqua (café shack walls, tail rings)
    (28, 164, 172),    # 9  teal (tail, bistro iron, parasol)
    (176, 146, 100),   # 10 dark tan (plank seams)
    (212, 184, 132),   # 11 warm tan (prop bases, planks)
    (105, 64, 40),     # 12 reddish brown (trunks, piles)
    (245, 105, 90),    # 13 coral (parasol, shell, coral)
    (238, 214, 164),   # 14 warm sand (hair, cone, castle)
    (36, 122, 62),     # 15 dark green
    (248, 196, 148),   # 16 warm skin (the statue)
    (255, 176, 0),     # 17 saturated gold (her hair, tower caps, emblem)
    (166, 130, 84),    # 18 umber tan (palm and plant base plates, 25% under warm tan)
    (150, 136, 116),   # 19 grey-tan (faceted rocks, plinth, weathered drums)
    (38, 152, 222),    # 20 tide-pool blue (pools, window panes)
    (226, 44, 140),    # 21 magenta (coral)
    (250, 132, 34),    # 22 orange (coral)
    (134, 150, 170),   # 23 cool grey-blue (rock arch)
    (92, 108, 130),    # 24 dark grey-blue (rock arch)
    (186, 198, 212),   # 25 light grey-blue (rock arch top-face highlights, keystone)
]
WHITE, GREEN, DBG, INK, RED, BLUE, YELLOW, STONE, AQUA, TEAL, DTAN, TAN, BROWN, CORAL, SAND, DGREEN, SKIN, GOLD, UMBER, GREYTAN, TIDE, MAGENTA, ORANGE, SLATE, DSLATE, LSLATE = range(26)

CELL, GRID, SIZE = 128, 8, 1024


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
