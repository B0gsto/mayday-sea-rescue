"""Flat Lego palette for the Boathouse add-ons (docs/05 2.2, 3, 5; colours from src/shared/DockPieces.luau).

One 4 x 4 palette atlas (1024 px, 256 px cells) gives every mesh flat colours through one material, so a whole layer
is one draw call. Cell index = the order below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (250, 249, 245),   # 0  white
    (198, 202, 208),   # 1  light silver (saw blade, tools; round 3, was 163,162,165)
    (99, 95, 98),      # 2  dark bluish grey
    (30, 44, 66),      # 3  ink / navy (windows, waterline)
    (235, 30, 30),     # 4  red (brighter, round 2)
    (255, 158, 48),    # 5  orange (PERF-BL11: lighter, it holds in the shed's shade)
    (255, 188, 0),     # 6  Lego yellow, deeper so AgX does not wash it to butter (round 2; was 250,208,40)
    (142, 146, 152),   # 7  medium stone grey (rims, pillars, gables, steps)
    (30, 190, 80),     # 8  go-lamp green (was unused blue)
    (172, 24, 30),     # 9  dark red (alternate roof courses)
    (176, 146, 100),   # 10 dark tan (plank seams)
    (212, 184, 132),   # 11 tan
    (26, 66, 158),     # 12 dark blue (brick seams on the blue walls; PERF-BL11, was unused brown)
    (40, 96, 208),     # 13 blue: the code BRICK_BLUE (PERF-BL11, was unused orange-tan)
    (150, 205, 240),   # 14 light glass blue
    (42, 44, 48),      # 15 black (tyres)
]
WHITE, LBG, DBG, INK, RED, ORANGE, YELLOW, STONE, GREEN, RRED, DTAN, TAN, DBLUE, BLUE, GLASS, BLACK = range(16)
BROWN = DBLUE   # lego.py's crate/pallet defaults (unused here)

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
