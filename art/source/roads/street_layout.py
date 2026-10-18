"""R1a street atlas layout (pure python; read by kit.py in Blender and streettex.py outside it).

The cells are B02's (assets/materials/atlases.json, Street / Main, u0 v0 u1 v1 with v up). Inside each asset's cell the
regions below are trim strips: `tile` regions are seamless both ways (faces are cut on tile lines and UV-wrapped, so the
texel density is set by the tile size, not by the asset size); `absz` regions tile along U and map V to the height
above ground 0..`h` m (road splash, salt and dirt fade upward); `fit` regions take one piece whole (lens, plate, band).
"""
CELLS = {  # atlases.json Street / Main
    "M_Road_StreetLamp": (0.0, 0.5, 0.25, 1.0),
    "M_Road_Bench": (0.0, 0.25, 0.25, 0.5),
    "M_Road_Bin": (0.25, 0.25, 0.5, 0.5),
    "M_Road_Bollard": (0.5, 0.25, 0.625, 0.5),
}
OTHER_CELLS = {"M_Road_BeachFlags": (0.75, 0.75, 1.0, 1.0), "Spare": (0.25, 0.75, 0.75, 1.0)}  # owned by other batches

# region: (cell-local rect u0 v0 u1 v1, kind, material, params)
#   tile: (tile_u_m, tile_v_m)   absz: (tile_u_m, h_m)   fit: ()
REGIONS = {
    "M_Road_StreetLamp": {
        "paint":     ((0.0, 0.5, 1.0, 1.0), "tile", "paint_black", (0.6, 0.6)),
        "paintbase": ((0.0, 0.25, 1.0, 0.5), "absz", "paint_black", (1.0, 0.95)),
        "housing":   ((0.0, 0.125, 0.5, 0.25), "tile", "powder_grey", (0.4, 0.2)),
        "lens":      ((0.5, 0.125, 1.0, 0.25), "fit", "led_lens", ()),
        "plate":     ((0.0, 0.0, 0.5, 0.125), "fit", "id_plate", ()),
        "galv":      ((0.5, 0.0, 1.0, 0.125), "tile", "galv", (0.2, 0.1)),
    },
    "M_Road_Bench": {
        "wood":      ((0.0, 0.5, 1.0, 1.0), "tile", "wood_slat", (0.9, 0.45)),
        "iron":      ((0.0, 0.25, 1.0, 0.5), "tile", "paint_black", (0.6, 0.15)),
        "ironbase":  ((0.0, 0.125, 1.0, 0.25), "absz", "paint_black", (0.6, 0.22)),
        "galv":      ((0.0, 0.0, 1.0, 0.125), "tile", "galv", (0.3, 0.0375)),
    },
    "M_Road_Bin": {
        "paint":     ((0.0, 0.5, 1.0, 1.0), "tile", "paint_black", (1.32, 0.66)),
        "paintbase": ((0.0, 0.25, 1.0, 0.5), "absz", "paint_black", (1.32, 0.40)),
        "band":      ((0.0, 0.125, 1.0, 0.25), "fit", "gold_band", ()),
        "galv":      ((0.0, 0.0, 1.0, 0.125), "tile", "galv_dark", (1.2, 0.15)),
    },
    "M_Road_Bollard": {
        "paint":     ((0.0, 0.5, 1.0, 1.0), "tile", "paint_black", (0.66, 0.66)),
        "paintbase": ((0.0, 0.25, 1.0, 0.5), "absz", "paint_black", (0.66, 0.35)),
        "band":      ((0.0, 0.0, 1.0, 0.25), "fit", "reflective_band", ()),
    },
}
ATLAS_SET = "Main"
ATLAS_PREFIX = "T_Street_Main"
INSET_PX = 3  # at the 1024 ship size: keeps bilinear filtering inside a region


def region_rect(asset, region):
    """Atlas UV rect (u0, v0, u1, v1) of a region, inset by INSET_PX at 1024."""
    c = CELLS[asset]
    r = REGIONS[asset][region][0]
    cw, ch = c[2] - c[0], c[3] - c[1]
    e = INSET_PX / 1024.0
    return (c[0] + r[0] * cw + e, c[1] + r[1] * ch + e, c[0] + r[2] * cw - e, c[1] + r[3] * ch - e)
