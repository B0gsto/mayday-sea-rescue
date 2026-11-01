"""Flat Lego palette for M_Veh_RescueHeli: rescue Hull Orange / white / charcoal (Heli/Builder.luau and the shipped
RIB / JetSki livery), Lego yellow hook. One 4 x 4 palette atlas (1024 px, 256 px cells), one material for every mesh.
Cell index = the order below; row 0 of the image is the bottom (v = 0).
"""
PALETTE = [
    (246, 246, 242),   # 0  white (stripe, doors, engine, tip caps)
    (255, 104, 12),    # 1  rescue orange (Builder ORANGE 255,102,0)
    (52, 56, 63),      # 2  charcoal (Builder DARK 45,48,54; skids, blades, belly)
    (36, 42, 50),      # 3  charcoal-smoke glass (the RIB / JetSki screens; r1 navy read off-palette)
    (255, 205, 20),    # 4  Lego bright yellow (hook, handles)
    (150, 156, 164),   # 5  light grey metal (hub, mast, winch arm)
    (215, 28, 30),     # 6  red (fin cap, beacon)
    (88, 92, 100),     # 7  mid grey (struts, root grips)
    (178, 184, 192),   # 8  light bluish grey (rotor blades: lighter than charcoal so they read as paddles)
    (40, 170, 72),     # 9  green (starboard tail light)
    (72, 96, 118),     # 10 r7: tinted cockpit glass (its own Glass mesh; that set's ALB is this colour at GLASS_ALPHA)
    (246, 246, 242),
    (246, 246, 242), (246, 246, 242), (246, 246, 242), (246, 246, 242),
]
WHITE, ORANGE, DARK, GLASS, YELLOW, METAL, RED, GREY, BLADE, GREEN, CGLASS = range(11)
GLASS_ALPHA = 150   # ~0.6 opaque: the pilot reads through it (AlphaMode Transparency, tools/gen_asset_ids.py)

CELL, GRID, SIZE = 256, 4, 1024


def write_maps(out_dir, name, set_name, size=SIZE, glass=False):
    """Writes T_<name>_<set>_{ALB,NOR,RGH,MET}.png into out_dir (one flat palette set; no wear, no scans).
    glass: the ALB is one RGBA fill (CGLASS at GLASS_ALPHA) for the see-through cockpit glass set."""
    import os
    from PIL import Image

    os.makedirs(out_dir, exist_ok=True)
    cell = size // GRID
    alb = Image.new("RGBA", (size, size), PALETTE[CGLASS] + (GLASS_ALPHA,)) if glass else Image.new("RGB", (size, size))
    px = alb.load()
    for i, rgb in enumerate(() if glass else PALETTE):
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
