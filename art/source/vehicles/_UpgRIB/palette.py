"""Flat palette atlas for M_Upg_RIB: 8 x 8 cells, 1024 px, per-cell roughness and metal. Base is the hull's orange and charcoal;
L20 accents are one yellow and one blue (AD rule), with white, dark and chrome as neutrals. Concept's green, red, pink and rainbow are out.

    python3 art/source/vehicles/_UpgRIB/palette.py build/prod/_UpgRIB/textures
"""
GRID, SIZE = 8, 1024
ABS = 0.3

# name: (hex, roughness, metal)
COLOURS = {
    "Yellow": ("FFCB14", ABS, 0), "Blue": ("1C5FC4", ABS, 0), "Neon": ("F4FF2E", 0.16, 0), "White": ("F4F4EE", ABS, 0),
    "Dark": ("2B2F34", 0.36, 0), "Tube": ("C8522C", 0.5, 0), "Chrome": ("C4CDD6", 0.12, 1), "Mouth": ("151A2C", 0.5, 0),
    "BlueDeep": ("143F86", ABS, 0), "Skin": ("E9B88C", 0.4, 0),
    # preview-only stand-in driver (never exported)
    "Jacket": ("F06A1A", 0.5, 0), "Suit": ("33373C", 0.5, 0),
}
CELL = {name: i for i, name in enumerate(COLOURS)}


def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def write_maps(out_dir, name="UpgRIB", set_name="Brick"):
    import os
    from PIL import Image
    os.makedirs(out_dir, exist_ok=True)
    cell = SIZE // GRID
    alb = Image.new("RGB", (SIZE, SIZE), _rgb(COLOURS["Dark"][0]))
    rgh = Image.new("RGB", (SIZE, SIZE), (int(ABS * 255),) * 3)
    met = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    for nm, (hx, r, m) in COLOURS.items():
        i = CELL[nm]
        col, row = i % GRID, GRID - 1 - i // GRID     # image row 0 is the top; cell 0 is bottom-left in UV
        box = (col * cell, row * cell, (col + 1) * cell, (row + 1) * cell)
        alb.paste(_rgb(hx), box)
        rgh.paste((int(r * 255),) * 3, box)
        met.paste((int(m * 255),) * 3, box)
    stem = os.path.join(out_dir, "T_%s_%s_" % (name, set_name))
    alb.save(stem + "ALB.png")
    rgh.save(stem + "RGH.png")
    met.save(stem + "MET.png")
    Image.new("RGB", (SIZE, SIZE), (128, 128, 255)).save(stem + "NOR.png")
    return stem + "ALB.png"


if __name__ == "__main__":
    import sys
    print(write_maps(sys.argv[1]))
