"""B02 material library table: one row per MaterialVariant (each also gets a <Name>_Wet twin).

source: Poly Haven texture id (CC0). dims_m: the scan's real size from the Poly Haven info API (StudsPerTile = dims_m x 3).
base: the variant's BaseMaterial. terrain: the Terrain base slot it overrides through MaterialService (docs/10 6.1), or None for a
parts-only variant. pattern: Organic (natural ground, breaks visible tiling) or Regular (laid stone, concrete, deck).
"""
STUDS_PER_M = 3

LIBRARY = [
    # name           source                 dims_m base           terrain        pattern    note (docs/10 6.1 look)
    ("SandDry",      "sand_03",              2.00, "Sand",        "Sand",        "Organic", "dry beach sand"),
    ("SandWet",      "damp_beach_sand",      2.00, "Sandstone",   "Sandstone",   "Organic", "wet sand: swash band and below the tide line"),
    ("SeabedSand",   "damp_beach_sand_02",   1.87, "Salt",        "Salt",        "Organic", "rippled seabed sand"),
    ("ShellGravel",  "shell_floor_01",       3.00, "Limestone",   "Limestone",   "Organic", "shell and maerl gravel on the seabed"),
    ("Shingle",      "pebbles",              4.00, "Pebble",      "Pebble",      "Organic", "shingle"),
    ("Granite",      "rock_face",            2.38, "Rock",        "Rock",        "Organic", "granite: cliff tops, reefs"),
    ("KelpRock",     "low_tide_rocks",       2.17, "Slate",       "Slate",       "Organic", "kelp and wrack covered rock (seabed, intertidal)"),
    ("SplashRock",   "dark_rock",            2.42, "Basalt",      "Basalt",      "Organic", "dark wet rock in the splash zone"),
    ("Turf",         "leafy_grass",          2.00, "Grass",       "Grass",       "Organic", "machair and cliff-top turf"),
    ("Moor",         "withered_grass",       2.00, "LeafyGrass",  "LeafyGrass",  "Organic", "heather and gorse moor (dry turf base)"),
    ("Mud",          "brown_mud_02",         1.30, "Mud",         "Mud",         "Organic", "estuary and track mud"),
    ("Earth",        "stony_dirt_path",      2.17, "Ground",      "Ground",      "Organic", "bare earth and paths"),
    ("Gravel",       "gravel_road",          2.00, "Pavement",    "Pavement",    "Organic", "gravel tracks and cliff-top car parks (Pavement slot: proposed, not in 10 6.1)"),
    ("Asphalt",      "asphalt_02",           3.00, "Asphalt",     "Asphalt",     "Organic", "road asphalt under the road meshes"),
    ("Cobbles",      "square_cobblestone",   2.00, "Cobblestone", "Cobblestone", "Regular", "granite setts: quays, old town"),
    ("Concrete",     "brushed_concrete",     2.50, "Concrete",    "Concrete",    "Regular", "brushed concrete: slipways, station apron"),
    ("QuayStone",    "seaworn_stone_tiles",  2.00, "Granite",     None,          "Regular", "sea-worn granite quay blocks (parts)"),
    ("WeedyConcrete","concrete_moss",        3.00, "Concrete",    None,          "Regular", "weedy slipway bottom (parts)"),
    ("Tarmac",       "worn_asphalt",         2.00, "Asphalt",     None,          "Organic", "worn quay and car-park tarmac (parts)"),
    ("NonSlipDeck",  "anti_slip_concrete",   2.50, "Plastic",     None,          "Regular", "grey non-slip deck (parts; desaturated to deck grey)"),
]

# Building trim sheet strips, top to bottom (px at 1024): name, source, height, profile, metal, tint (multiplier) or None.
TRIM = [
    ("WindowFrame",  "wood_peeling_paint_weathered", 128, "bevel2", False, (1.05, 1.05, 1.03)),
    ("GlazingBar",   "wood_peeling_paint_weathered",  64, "round",  False, (1.05, 1.05, 1.03)),
    ("Sill",         "granite_tile",                 128, "sill",   False, None),
    ("Gutter",       "rusty_painted_metal",          128, "round",  False, (0.35, 0.36, 0.37)),
    ("Downpipe",     "rusty_painted_metal",           64, "round",  False, (0.35, 0.36, 0.37)),
    ("RenderBand",   "white_plaster_rough_01",       128, "bevel1", False, None),
    ("Flashing",     "metal_plate",                   64, "flat",   True,  None),
    ("Fascia",       "wood_peeling_paint_weathered", 128, "bevel1", False, (0.55, 0.62, 0.58)),
    ("DoorPanel",    "wood_peeling_paint_weathered", 128, "panel",  False, (0.52, 0.58, 0.66)),
    ("Coping",       "granite_tile",                  64, "round",  False, None),
]
