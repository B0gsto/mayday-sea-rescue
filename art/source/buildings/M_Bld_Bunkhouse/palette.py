"""Flat colour palette for M_Bld_Bunkhouse (the M_Bld_Depot approach, docs/05 5): one 8 x 8 atlas (1024 px, 128 px
cells) in one texture set T_Bunkhouse_Brick, so Roblox shows the colours (it ignores FBX material colours).
Cell index = the order below (cell 0 bottom-left in UV, v = 0 at the image's bottom row); roughness is per cell.
"""
COLOURS = {   # key: (hex, roughness), the round-3 flat Material colours
    "Log1": ("#C98E52", 0.5), "Log2": ("#BC7F43", 0.5), "LogDark": ("#7A4A26", 0.5), "Cream": ("#EFE4C8", 0.55),
    "Plinth": ("#A3A2A5", 0.55), "Floor": ("#DDC592", 0.55), "Blue": ("#2860D0", 0.4), "Red": ("#E03828", 0.4),
    "Yellow": ("#F2C230", 0.45), "Green": ("#50BE5A", 0.45), "Orange": ("#FA8C1E", 0.45), "White": ("#F6F4EE", 0.42),
    "Navy": ("#1E2C42", 0.4), "Lamp": ("#FFC95A", 0.5), "Steel": ("#8A8E94", 0.35), "Wood": ("#B07A44", 0.5),
    "Cork": ("#CDB68A", 0.6), "Purple": ("#8A4FC8", 0.45), "OwnerColour": ("#E03828", 0.38),
    "Brick": ("#B8442E", 0.5), "Glass": ("#96CDF0", 0.2)}
CELL = {k: i for i, k in enumerate(COLOURS)}
GRID, SIZE = 8, 1024
assert len(COLOURS) <= GRID * GRID


def cell_uv(c, inset=0.08):
    """(u0, v0, u1, v1) of palette cell c, inset so mips never bleed into the next cell."""
    col, row = c % GRID, c // GRID
    return (col + inset) / GRID, (row + inset) / GRID, (col + 1 - inset) / GRID, (row + 1 - inset) / GRID


def write_maps(out_dir, name, set_name, size=SIZE):
    """Writes T_<name>_<set>_{ALB,NOR,RGH,MET}.png into out_dir (flat cells, no wear, no scans)."""
    import os
    from PIL import Image

    os.makedirs(out_dir, exist_ok=True)
    cell = size // GRID
    alb = Image.new("RGB", (size, size), (255, 0, 255))
    rgh = Image.new("RGB", (size, size), (128, 128, 128))
    for i, (hx, r) in enumerate(COLOURS.values()):
        x, y = (i % GRID) * cell, (GRID - 1 - i // GRID) * cell      # image row 0 is the top
        alb.paste(tuple(int(hx[k:k + 2], 16) for k in (1, 3, 5)), (x, y, x + cell, y + cell))
        g = round(r * 255)
        rgh.paste((g, g, g), (x, y, x + cell, y + cell))
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    alb.save(stem + "ALB.png")
    rgh.save(stem + "RGH.png")
    Image.new("RGB", (size, size), (128, 128, 255)).save(stem + "NOR.png")
    Image.new("RGB", (size, size), (0, 0, 0)).save(stem + "MET.png")
    return stem + "ALB.png"
