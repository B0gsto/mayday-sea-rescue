"""H3 Details atlas table (pure python; maketex.py paints it, kit.py maps to it)."""
# Details atlas (u0, v0, u1, v1); v up (UV space). build.py reads the same table.
DOORS = {k: (i * 0.125, 0.70, (i + 1) * 0.125, 1.0) for i, k in enumerate(("Navy", "Oxblood", "Sage", "Black", "Teal", "Cream"))}
DOOR_RGB = {"Navy": (44, 56, 78), "Oxblood": (112, 74, 68), "Sage": (100, 118, 96), "Black": (38, 44, 42),
            "Teal": (56, 90, 94), "Cream": (204, 196, 172)}
GLASS = (0.75, 0.70, 0.875, 1.0)
LANTERN = (0.875, 0.70, 1.0, 1.0)
WIN_DIM = [(i * 0.125, 0.40, (i + 1) * 0.125, 0.55) for i in range(8)]     # 0..5 interiors, 6 sash far card, 7 casement far card
WIN_LIT = [(i * 0.125, 0.55, (i + 1) * 0.125, 0.70) for i in range(8)]
STRIPS = {"Tar": (0.0, 0.05), "Ridge": (0.05, 0.13), "Pot": (0.13, 0.18), "Lead": (0.18, 0.22), "Iron": (0.22, 0.26),
          "Step": (0.26, 0.31), "Mortar": (0.31, 0.35), "Paint": (0.35, 0.40)}
