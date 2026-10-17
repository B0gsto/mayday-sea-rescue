"""K1 rocks and cliff kit: the piece table (shared by fetch.py, bake_all.py, compose.py and every build.py).
Each piece is a Poly Haven CC0 photogrammetry scan (https://polyhaven.com/license), decimated to budget,
normal re-baked from the full scan, albedo graded to the 05 granite palette with lichen / barnacle / wrack zones."""
KIT = [
    # asset, polyhaven id, budget class, LOD0 tris, tier, zone (lichen | shore), texture Name
    ("M_Rock_Boulder_01", "boulder_01", "boulder", 4000, "standard", "lichen", "Boulder01"),
    ("M_Rock_Boulder_02", "namaqualand_boulder_05", "boulder", 2500, "standard", "lichen", "Boulder02"),
    ("M_Rock_Boulder_03", "namaqualand_boulder_06", "boulder", 2500, "standard", "lichen", "Boulder03"),
    ("M_Rock_Boulder_04", "namaqualand_boulder_02", "boulder", 4000, "standard", "shore", "Boulder04"),
    ("M_Rock_Boulder_05", "namaqualand_boulder_03", "boulder", 6000, "standard", "shore", "Boulder05"),
    ("M_Rock_Boulder_06", "namaqualand_boulder_04", "boulder", 6000, "standard", "lichen", "Boulder06"),
    ("M_Rock_Cliff_01", "rock_face_01", "rock", 9500, "background", "lichen", "Cliff01"),
    ("M_Rock_Cliff_02", "rock_face_02", "rock", 9000, "background", "lichen", "Cliff02"),
    ("M_Rock_Cliff_03", "mountainside", "rock", 9500, "background", "lichen", "Cliff03"),
    ("M_Rock_Cliff_04", "namaqualand_cliff_01", "rock", 9500, "background", "shore", "Cliff04"),
    ("M_Rock_Cliff_05", "namaqualand_cliff_02", "rock", 9800, "background", "shore", "Cliff05"),
    ("M_Rock_Ledge_01", "coast_land_rocks_02", "boulder", 7800, "background", "shore", "Ledge01"),
    ("M_Rock_Ledge_02", "coast_land_rocks_03", "boulder", 7800, "background", "shore", "Ledge02"),
    ("M_Rock_Ledge_03", "coast_rocks_05", "boulder", 6000, "background", "shore", "Ledge03"),
]
ROOT = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
SRC = ROOT + "build/k1/src/"      # downloads (data only)
WORK = ROOT + "build/k1/work/"    # baked masks / normals / decimated meshes
SET = "Granite"
BAKE = 2048


def piece(asset):
    for row in KIT:
        if row[0] == asset:
            return dict(zip(("asset", "pid", "budget", "tris", "tier", "zone", "tex"), row))
    raise KeyError(asset)


# export size per piece: the two biggest faces ship at 2048 to hold the background texel tier (25 px/stud)
SIZE = {"M_Rock_Cliff_03": 2048, "M_Rock_Cliff_05": 2048}


def size(asset):
    return SIZE.get(asset, 1024)
