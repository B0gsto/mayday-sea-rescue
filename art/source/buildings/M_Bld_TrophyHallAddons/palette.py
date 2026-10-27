"""Flat Lego palette for the Trophy Hall add-ons (docs/05 2.2, 3, 5; colours from src/shared/DockPieces.luau).

One 4 x 4 palette atlas (1024 px, 256 px cells) gives every mesh flat colours through one material, so a whole layer
is one draw call. Navy, sand, saturated gold and red carry the asset; white is trim only. Cell index = the order
below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (250, 249, 245),   # 0  white trim
    (212, 184, 132),   # 1  sand
    (186, 153, 100),   # 2  dark sand (seams, dome ribs)
    (30, 44, 66),      # 3  navy
    (253, 200, 18),    # 4  saturated Lego gold
    (214, 126, 12),    # 5  deep orange-gold (dome ribs, equator band)
    (224, 56, 40),     # 6  red
    (163, 162, 165),   # 7  light bluish grey
    (99, 95, 98),      # 8  dark bluish grey
    (120, 185, 235),   # 9  light glass blue
    (105, 64, 40),     # 10 reddish brown
    (42, 44, 48),      # 11 black
    (255, 214, 150),   # 12 warm lamp light
    (20, 28, 42),      # 13 deep navy (porthole glass, shadows)
    (178, 38, 32),     # 14 dark red (flag folds)
    (240, 232, 212),   # 15 cream trim
]
WHITE, SAND, DSAND, NAVY, GOLD, GOLD2, RED, LBG, DBG, GLASS, BROWN, BLACK, WARM, DEEP, RED2, CREAM = range(16)

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
