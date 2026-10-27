"""Flat palette for M_Bld_RescueHQ: the round-4 Material colours, one 4 x 4 cell each (like M_Bld_Depot/palette.py).

Every mesh is one colour, so its UVs sit inside that colour's cell of T_RescueHQ_Brick (Roblox ignores FBX material
colours). Cell index = position in COLOURS; row 0 of the image is the bottom (v = 0). OwnerColour shares Red's cell.
"""
# key: (hex, roughness, metallic, alpha); alpha < 1 is Blender preview only (the ALB has no alpha)
COLOURS = {
    "White": ("#F2F0E8", 0.42), "Cream": ("#E4DFCB", 0.5), "Plinth": ("#A3A2A5", 0.55), "Red": ("#E03828", 0.40),
    "Navy": ("#1E2C42", 0.40), "Steel": ("#8A8E94", 0.35, 0.35), "Gold": ("#DEB23C", 0.30, 0.55),
    "Glass": ("#96CDF0", 0.12, 0.0, 0.62), "Tan": ("#CDB68A", 0.55),
    "Wood": ("#8B5A2B", 0.5), "Sea": ("#2F7FC1", 0.45), "Yellow": ("#F2C230", 0.5),
    "RoofLine": ("#B82A1C", 0.45)}
OWNER = ("OwnerColour", ("#E03828", 0.38))      # its own Blender material, Red's cell in the texture
CELL_OF = {k: i for i, k in enumerate(COLOURS)}
CELL_OF[OWNER[0]] = CELL_OF["Red"]
GRID, SIZE = 4, 1024
INSET = 0.08                                     # UVs keep 8% off the cell edges so filtering never bleeds


def cell_uv(cell, u, v):
    """(u, v) in 0..1 -> inside palette cell `cell`."""
    col, row = cell % GRID, cell // GRID
    k = 1.0 - 2 * INSET
    return ((col + INSET + k * u) / GRID, (row + INSET + k * v) / GRID)


def write_maps(out_dir, name="RescueHQ", set_name="Brick", size=SIZE):
    """T_<name>_<set>_{ALB,NOR,RGH,MET}.png: per-cell colour, roughness and metal; flat normal."""
    import os
    from PIL import Image

    os.makedirs(out_dir, exist_ok=True)
    cell = size // GRID
    maps = {k: Image.new(m, (size, size), c) for k, m, c in
            (("ALB", "RGB", (128, 128, 128)), ("RGH", "L", 205), ("MET", "L", 0))}
    for i, (hexc, *rest) in enumerate(COLOURS.values()):
        rough, metal = (list(rest) + [0.0])[:2]
        col, row = i % GRID, GRID - 1 - i // GRID     # image row 0 is the top; cell 0 is bottom-left in UV
        box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
        maps["ALB"].paste(tuple(int(hexc[j:j + 2], 16) for j in (1, 3, 5)), box)
        maps["RGH"].paste(round(rough * 255), box)
        maps["MET"].paste(round(metal * 255), box)
    maps["NOR"] = Image.new("RGB", (size, size), (128, 128, 255))
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    for k, im in maps.items():
        im.save(stem + k + ".png")
    return stem + "ALB.png"


if __name__ == "__main__":
    assert cell_uv(5, 0.0, 1.0) == ((1 + INSET) / 4, (1 + 1 - INSET) / 4)
    assert len(COLOURS) <= GRID * GRID and CELL_OF["OwnerColour"] == CELL_OF["Red"]
