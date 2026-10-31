"""Lego palette for the prize wheel: an 8 x 8 atlas (1024 px, 128 px cells), one flat cell per colour.

Every cell carries its own roughness / metalness so one material gives glossy plastic, polished gold and chrome.
Cell index = list order; row 0 of the UV space is the bottom (v = 0).
"""
# (rgb, roughness 0..1, metalness 0..1)
CELLS = [
    ((250, 249, 245), 0.45, 0.0),   # 0  white
    ((198, 202, 208), 0.45, 0.0),   # 1  light silver plastic
    ((99, 95, 98), 0.5, 0.0),       # 2  dark bluish grey
    ((30, 44, 66), 0.5, 0.0),       # 3  ink navy
    ((235, 30, 30), 0.35, 0.0),     # 4  red
    ((250, 140, 30), 0.4, 0.0),     # 5  orange
    ((255, 188, 0), 0.35, 0.0),     # 6  Lego yellow
    ((142, 146, 152), 0.5, 0.0),    # 7  stone grey
    ((40, 96, 208), 0.35, 0.0),     # 8  blue
    ((172, 24, 30), 0.4, 0.0),      # 9  dark red
    # rarity segments: base, light facet, dark facet (SpinRules order: Common .. Mythic)
    ((150, 152, 160), 0.4, 0.0), ((222, 224, 230), 0.3, 0.0), ((92, 95, 106), 0.45, 0.0),       # 10-12 Common
    ((70, 185, 85), 0.4, 0.0), ((175, 240, 160), 0.3, 0.0), ((30, 120, 55), 0.45, 0.0),         # 13-15 Uncommon
    ((40, 110, 220), 0.4, 0.0), ((150, 205, 255), 0.3, 0.0), ((20, 60, 150), 0.45, 0.0),        # 16-18 Rare
    ((150, 80, 210), 0.4, 0.0), ((215, 165, 250), 0.3, 0.0), ((92, 40, 150), 0.45, 0.0),        # 19-21 Epic
    ((245, 168, 20), 0.25, 0.55), ((255, 222, 110), 0.2, 0.5), ((180, 104, 8), 0.3, 0.6),      # 22-24 Legendary (deep gold)
    ((255, 80, 190), 0.3, 0.1), ((255, 180, 228), 0.25, 0.1), ((190, 30, 130), 0.35, 0.1),      # 25-27 Mythic
    ((222, 225, 232), 0.18, 1.0),   # 28 chrome
    ((255, 196, 64), 0.22, 1.0),    # 29 polished gold
    ((80, 220, 255), 0.25, 0.1),    # 30 cyan (rainbow gem)
    ((150, 230, 60), 0.3, 0.0),     # 31 lime (rainbow gem)
    ((42, 44, 48), 0.55, 0.0),      # 32 black
]
(WHITE, LSIL, DBG, INK, RED, ORANGE, YELLOW, STONE, BLUE, RRED,
 C0, C0L, C0D, C1, C1L, C1D, C2, C2L, C2D, C3, C3L, C3D, C4, C4L, C4D, C5, C5L, C5D,
 CHROME, GOLD, CYAN, LIME, BLACK) = range(len(CELLS))
RARITY = [(C0, C0L, C0D), (C1, C1L, C1D), (C2, C2L, C2D), (C3, C3L, C3D), (C4, C4L, C4D), (C5, C5L, C5D)]
RARITY_NAMES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]

GRID, SIZE = 8, 1024


def write_maps(out_dir, name, set_name, size=SIZE):
    """Writes T_<name>_<set>_{ALB,NOR,RGH,MET}.png into out_dir."""
    import os
    from PIL import Image

    os.makedirs(out_dir, exist_ok=True)
    cell = size // GRID
    maps = {k: Image.new("RGB", (size, size)) for k in ("ALB", "RGH", "MET")}
    px = {k: v.load() for k, v in maps.items()}
    for i, (rgb, rough, metal) in enumerate(CELLS):
        col, row = i % GRID, GRID - 1 - i // GRID     # image row 0 is the top; cell 0 is bottom-left in UV
        r8, m8 = int(round(rough * 255)), int(round(metal * 255))
        for y in range(row * cell, (row + 1) * cell):
            for x in range(col * cell, (col + 1) * cell):
                px["ALB"][x, y] = rgb
                px["RGH"][x, y] = (r8, r8, r8)
                px["MET"][x, y] = (m8, m8, m8)
    stem = "T_%s_%s_" % (name, set_name)
    for kind, img in maps.items():
        img.save(os.path.join(out_dir, stem + kind + ".png"))
    Image.new("RGB", (size, size), (128, 128, 255)).save(os.path.join(out_dir, stem + "NOR.png"))
    return os.path.join(out_dir, stem + "ALB.png")
