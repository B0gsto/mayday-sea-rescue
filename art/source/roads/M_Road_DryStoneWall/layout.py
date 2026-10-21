"""M_Road_DryStoneWall sheet layout (pure python; read by build.py in Blender and walltex.py outside it).

One trim set, `T_DryStoneWall_Granite_*` (1024 ship, 2048 master). A dry-stone wall is one material all over, so the
sheet is divided by *surface*, and every cell is drawn for the same granite with a different weather:

  wall    u 0.000..1.000, v 0.629..1.000 (2048 x 760 px at 2048): the split-granite face of the wall's stones, U
          repeats every `WALL_U_M` (2.56 m) along the wall and V runs 0 at ground level to `CELL_V_M` (0.95 m) at the
          top, so the mud splash, the damp line and the salt bloom land at the right height on every stone no matter
          where it sits. Each stone takes its own U offset inside the cell, so no two stones share a crop.
  cope    u 0.000..0.193, v 0.425..0.627 (396 x 418 px): the coping stones' bed - the most weathered granite on the
          wall: heavy grey-green crustose lichen, orange Xanthoria colonies, sun-bleached and rain-scoured.
  lichen  u 0.203..0.397, v 0.425..0.627: a stone carrying a dense crustose lichen community (grey-white, sage,
          orange) over granite. Stones that carry lichen take this cell whole, so the growth stops at the stone's
          joints the way it does on a real wall.
  moss    u 0.406..0.561, v 0.425..0.627: dense moss - the shaded lower courses and the moss lumps that sit in the
          joints.
  joint   u 0.000..0.193, v 0.221..0.425: the inside of a joint. U is the depth back from the wall face (0 at the
          arris, 1.0 = 0.90 m into the wall), V the height, so a joint is gritty and mossy at its mouth and black
          further in.
  grass   u 0.203..0.311, v 0.221..0.425: the grass tufts at the wall's foot, V 0 at the ground to 0.32 m at the
          blade tips.

`CELL_M` is metres of surface across each cell (U, V); `V_REF` the world height (m) the cell's V = 0 sits at, so a
cope stone (0.85 to 1.20 m) maps into the bottom third of the cope cell. `region_rect` returns the cell in atlas UVs
(v up) inset by `INSET_PX` so bilinear filtering stays inside the cell.
"""
REGIONS = {  # (u0, v0, u1, v1) in atlas UVs, v up
    "wall":   (0.0000, 0.6289, 1.0000, 1.0000),
    "cope":   (0.0000, 0.4248, 0.1934, 0.6270),
    "lichen": (0.2031, 0.4248, 0.3965, 0.6270),
    "moss":   (0.4063, 0.4248, 0.5605, 0.6270),
    "joint":  (0.0000, 0.2207, 0.1934, 0.4248),
    "grass":  (0.2031, 0.2207, 0.3105, 0.4248),
}

CELL_M = {  # metres of surface across one cell (U, V) - the same granite texel density everywhere
    "wall":   (2.560, 0.950),
    "cope":   (0.900, 0.950),
    "lichen": (0.900, 0.950),
    "moss":   (0.720, 0.950),
    "joint":  (0.900, 0.950),
    "grass":  (0.500, 0.950),
}

V_REF = {  # the world height (m) a cell's V = 0 sits at
    "wall": 0.00, "lichen": 0.00, "moss": 0.00, "joint": 0.00, "cope": 0.85, "grass": 0.00,
}

WALL_U_M = CELL_M["wall"][0]
CELL_V_M = CELL_M["wall"][1]
GRASS_V_M = 0.32          # grass cell: V 0 at the ground, 1.0 at 0.32 m (the tallest blade)
INSET_PX = 3              # at the 1024 ship size: keeps bilinear filtering inside a cell


def region_rect(cell):
    """(u0, v0, u1, v1) of a cell in atlas UVs, v up, inset for filtering."""
    u0, v0, u1, v1 = REGIONS[cell]
    e = INSET_PX / 1024.0
    return (u0 + e, v0 + e, u1 - e, v1 - e)


def region_px(cell, size):
    """(x0, y0, x1, y1) pixel rect of a cell at `size` px, y from the image top (PIL order)."""
    u0, v0, u1, v1 = REGIONS[cell]
    return (int(round(u0 * size)), int(round((1 - v1) * size)), int(round(u1 * size)), int(round((1 - v0) * size)))
