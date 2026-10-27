"""Flat Lego palette for the HQ add-ons (docs/05 2.2, 3, 5; colours from src/shared/DockPieces.luau).

One 4 x 4 palette atlas (1024 px, 256 px cells) gives every mesh flat colours through one material, so a whole layer
is one draw call. Cell index = the order below; row 0 of the image is the bottom (v = 0). Cell 10 is the station's
GOLD (the beacon lantern and the crest); the fish-market pink is not used here.
"""
PALETTE = [
    (246, 244, 238),   # 0  white
    (163, 162, 165),   # 1  light bluish grey
    (99, 95, 98),      # 2  dark bluish grey
    (30, 44, 66),      # 3  ink / navy (windows, roof, chart sea)
    (224, 56, 40),     # 4  red
    (250, 140, 30),    # 5  orange
    (250, 208, 40),    # 6  yellow
    (80, 190, 90),     # 7  green
    (40, 96, 208),     # 8  blue
    (60, 220, 255),    # 9  cyan
    (255, 190, 10),    # 10 gold (lantern frame, crest anchor): saturated, not tan
    (212, 184, 132),   # 11 tan
    (105, 64, 40),     # 12 reddish brown
    (255, 226, 72),    # 13 bright lamp yellow
    (150, 205, 240),   # 14 light glass blue
    (42, 44, 48),      # 15 black (radio faces)
]
WHITE, LBG, DBG, INK, RED, ORANGE, YELLOW, GREEN, BLUE, CYAN, GOLD, TAN, BROWN, WARM, GLASS, BLACK = range(16)

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
