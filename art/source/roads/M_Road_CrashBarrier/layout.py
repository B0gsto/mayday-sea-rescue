"""M_Road_CrashBarrier sheet layout (pure python; read by build.py in Blender and barriertex.py outside it).

One trim set, `T_CrashBarrier_Galv_*` (1024 ship, 2048 master), three regions: the galvanised steel region that the
W-beam, the posts and the fasteners use (U tiles every `TILE_U_M` along the part, V maps the height above ground
0..`GALV_H_M` m, so road splash sits on the low pixels and the beam's own band is clean), a reflector plate face and a
dull dark metal cell for plates' backs, plate frames and nut heads. `region_rect` gives the cell in atlas UVs (v up),
inset so bilinear filtering stays inside the cell.
"""
CELLS = {
    # asset: (u0, v0, u1, v1) of the whole sheet area this asset owns (this asset owns its sheet)
    "M_Road_CrashBarrier": (0.0, 0.0, 1.0, 1.0),
}

REGIONS = {
    "galv":  (0.004, 0.152, 0.996, 0.996),
    "plate": (0.252, 0.004, 0.500, 0.148),
    "dark":  (0.504, 0.004, 0.752, 0.148),
}

TILE_U_M = 1.90      # galvanised region: metres of part along one U tile (fewer repeats along a 4 m piece)
GALV_H_M = 1.15      # galvanised region: metres of height above ground across the V span (0 at the cell bottom)
PLATE_M = (0.10, 0.06)   # the reflector plate the "plate" cell is drawn for (width, height)


def region_rect(region):
    """(u0, v0, u1, v1) of a region in atlas UVs, v up."""
    return REGIONS[region]
