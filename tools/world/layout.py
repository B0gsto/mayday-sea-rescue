"""World layout for the Gale Isles terrain generator (hand-authored data; docs/23 (k), docs/21).

Coordinates are studs from the map centre (the ring's lagoon): +X east, -Z north, +Z south, sea level Y = 0, 1 m = 3 studs.
This file is the single source for the island masks and points of interest; gen_terrain.py bakes the terrain from
it and writes src/shared/Config/WorldConfig.luau from it (WorldConfig.Ring feeds src/shared/Config/HubLayout.luau).
"""
import math

SEED = 1871  # the year the Port Haven lifeboat station opened (any fixed integer keeps the bake deterministic)

CELL = 4  # studs per heightmap sample = Terrain voxel size
SEABED_FLOOR_Y = -165  # deeper water gets this flat floor (doc 10 section 4.1: detail only to about 40 m)

# Coast kinds. Each polygon vertex carries a kind and a coast-top height H (studs); the profile blends between
# vertices along the coast, so a cliff fades into a rocky shore and then a beach.
CLIFF, ROCKY, BEACH, HARBOUR, MUD = "cliff", "rocky", "beach", "harbour", "mud"
KINDS = (CLIFF, ROCKY, BEACH, HARBOUR, MUD)

BEACH_WIDTH = 120  # studs of sand from the waterline to the dune toe (plateau islands: 40, see bake_island)
DUNE_WIDTH = 110


def ring(cx, cz, pts):
    return [(round(cx + r * math.cos(math.radians(a))), round(cz + r * math.sin(math.radians(a))), k, h)
            for a, r, k, h in pts]


def at(cx, cz, bearing, r):
    return (round(cx + r * math.cos(math.radians(bearing))), round(cz + r * math.sin(math.radians(bearing))))


def oval(cx, cz, rx, rz, kind, h, n=8):
    return ring(cx, cz, [(360 * k / n, rx * rz / math.hypot(rz * math.cos(2 * math.pi * k / n),
                                                            rx * math.sin(2 * math.pi * k / n)), kind, h)
                         for k in range(n)])


# ---------------------------------------------------------------- the ring of six player islands (docs/23 (p))
# WP-27: no island at the centre. The six player islands sit in a tight ring round an open lagoon. Bearings: 0 east,
# 90 south (+Z). Island-local frame (HubLayout.luau uses the same): forward = outward from the ring centre (cos b,
# sin b), right = (-sin b, cos b) = CFrame.lookAt(centre, centre + forward).RightVector. The islands are not terrain
# (WP-24): each is a flat Lego plate built from Parts (src/server/World/IslandPlates.luau, footprint in
# HubLayout.IslandPlate), its berth notch on the forward (sea) face.
PLATEAU_Y = 4  # the plate top, the quays and every lot
# Terrain renders its surface about half a voxel over the baked height (Studio raycasts: +1.9 +-0.25 studs)
RENDER_BIAS = 2
CENTER = (0, 0)  # the lagoon's centre (no island)
# radius 470: the 320-stud plates' nearest corners are 80 studs apart (at 380 they would overlap)
RING = {"radius": 470, "bearings": (0, 60, 120, 180, 240, 300), "islandRadius": 160,
        "notch": {"halfWidth": 45, "head": 30, "floorY": -30}}
WINDOW_HALF_X, WINDOW_HALF_Z = 1536, 1280  # the main window: the ring, the lagoon and the sea round them


def local(cx, cz, bearing, right, fwd):
    b = math.radians(bearing)
    return (cx + fwd * math.cos(b) - right * math.sin(b), cz + fwd * math.sin(b) + right * math.cos(b))


PLAYER_ISLANDS = [{"id": f"Plot{k + 1}", "bearing": b, "center": local(*CENTER, b, 0, RING["radius"])}
                  for k, b in enumerate(RING["bearings"])]

# The main window is open water: a sand seabed (one wide lagoon-sand shoal, about Y -36 to -44, ramping to the deep
# floor by the window edge) with a basin round each plate deep enough for boats and the submarine.
PLATE_BASIN = {"radius": 420, "floorY": -34}  # full depth inside 210 (past the 160-stud plate), blending out by 420
HUB_WINDOW = {  # the main window (historical name)
    "id": "Hub", "window": (-WINDOW_HALF_X, -WINDOW_HALF_Z, WINDOW_HALF_X, WINDOW_HALF_Z), "biome": "hub",
    "edgeRamp": 120, "polys": [], "peaks": [], "pads": [],
    "shoals": [(*CENTER, 2400, -36, False)],
    "basins": [(*p["center"], PLATE_BASIN["radius"], PLATE_BASIN["floorY"]) for p in PLAYER_ISLANDS],
}

# Seabed areas (rock reefs, kelp) as circles: centre, radius (the Skerries; baked as Skerry Isle's shoals).
REEFS = [
    {"id": "SkerriesReefN", "center": (1600, 1420), "radius": 240, "topY": -2},
    {"id": "SkerriesReefE", "center": (2250, 1500), "radius": 200, "topY": -3},
]
KELP_BEDS = [  # kelp on rock from 2 to 15 m (Slate material now, kelp props later)
    {"id": "SkerriesKelp", "center": (1650, 1450), "radius": 220},
]

# Wrecks and finds on the seabed (Y from the bake). Morwenna lies off the ring past Plot1 and Plot6, the
# Admiralty anchor in the middle of the lagoon, the seaplane on the Skerries sand.
POIS = [
    {"id": "Morwenna", "kind": "Wreck", "name": "Morwenna", "era": "1902",
     "blurb": "A wooden trading schooner lost in the gale of 1902.",
     "pos": (1100, None, -640), "yaw": 28, "length": 84, "beam": 21},
    {"id": "MailSeaplane", "kind": "Wreck", "name": "The mail seaplane", "era": "1960s",
     "blurb": "A mail seaplane that ditched on the Skerries sand; wrasse live in the cockpit.",
     "pos": (1300, None, 1500), "yaw": -35, "length": 39, "beam": 50},
    {"id": "AdmiraltyAnchor", "kind": "Find", "name": "Admiralty anchor", "era": "1840s",
     "blurb": "An Admiralty-pattern anchor lying in the lagoon.",
     "pos": (CENTER[0], None, CENTER[1]), "yaw": 70, "length": 12, "beam": 10},
]

# ---------------------------------------------------------------- the archipelago (docs/21 sections 2.2 and 6.1)
# Each outer island has its own bake window (x0, z0, x1, z1) on the 256-stud tile grid, disjoint from the main
# window and from each other; only that island's polygons are baked in it. Outside every window there are no voxels:
# the opaque mesh ocean hides the missing deep floor. Island polygons are rings round a centre:
# (bearing deg: 0 east, 90 south, 180 west, 270 north; radius; coast kind; coast-top H).
MAP_RADIUS = 7000  # playable sea (GameConfig.MapRadius; vehicles reset past MAP_RADIUS + 200)
MAP_CANVAS = 7168  # the map image covers x, z in +-MAP_CANVAS (MapConfig Origin / Extent)

# Island keys: id, name, centre, radius (studs, for zones / discovery), window (None: in the main window), polys,
# peaks [(x, z, height, radius)] (gaussian hills over the coast profile), pads [(x0, z0, x1, z1, y)] (flat ground
# for B1 buildings; y None = the ground's mean), basins [(x, z, radius, floorY)] (dredged harbour water),
# shoals [(x, z, radius, topY, rock)] (raised seabed: reef rock or lagoon sand), biome (material
# accent: granite, chalk, village, reef, stacks, guano, lagoon), landmark (x, z) where the silhouette stands,
# stamp (x, z) the stamp post (land), landing (x, z) the shore end of a jetty (land) and dock (x, z) its sea end
# (water: boats stop here; DropOff docks for B3).
ARCHIPELAGO = [
    {"id": "SkerryIsle", "name": "Skerry Isle", "center": (1800, 1750), "radius": 420,
     "window": (1024, 1280, 2560, 2304), "biome": "granite",
     "polys": [[(1460, 1700, ROCKY, 30), (1700, 1560, CLIFF, 45), (2080, 1600, ROCKY, 35), (2200, 1800, CLIFF, 40),
                (1950, 1950, ROCKY, 25), (1560, 1900, ROCKY, 20)]],
     "peaks": [], "pads": [], "shoals": [(1600, 1420, 240, -2, True), (2250, 1500, 200, -3, True)],
     "landmark": (1520, 1700), "stamp": (1560, 1730), "landing": (1640, 1640), "dock": (1640, 1530)},
    {"id": "PuffinIsle", "name": "Puffin Isle", "center": (-2600, 3400), "radius": 650,
     "window": (-3328, 2816, -1792, 4096), "biome": "chalk",
     "polys": [ring(-2600, 3400, [(0, 560, ROCKY, 20), (35, 380, ROCKY, 25), (70, 330, CLIFF, 60), (110, 340, CLIFF, 80),
                                  (145, 420, CLIFF, 90), (180, 640, CLIFF, 85), (215, 450, CLIFF, 70),
                                  (250, 360, ROCKY, 30), (290, 340, BEACH, 0), (325, 420, BEACH, 0)])],
     "peaks": [(-2850, 3420, 100, 220), (-2380, 3390, 80, 190)], "pads": [(-2660, 3360, -2560, 3440, None)],
     "landmark": (-2610, 3400), "stamp": (-2580, 3360), "landing": at(-2600, 3400, 305, 300),
     "dock": at(-2600, 3400, 305, 450)},
    {"id": "Penwyn", "name": "Penwyn", "center": (-4800, -300), "radius": 850,
     "window": (-6144, -1536, -3584, 1024), "biome": "village",
     # shortcut: kind None (no kind weight) reproduces the original bake, where HARBOUR was shadowed by the old
     # harbour-basin dict; set HARBOUR when Penwyn's dressing is next re-checked against a re-bake
     "polys": [ring(-4800, -300, [(0, 560, None, 4), (22, 700, ROCKY, 12), (55, 580, BEACH, 0), (90, 520, ROCKY, 30),
                                  (125, 560, CLIFF, 60), (160, 760, CLIFF, 80), (180, 820, CLIFF, 90),
                                  (200, 760, CLIFF, 80), (235, 560, ROCKY, 35), (270, 520, ROCKY, 25),
                                  (305, 580, BEACH, 0), (338, 700, ROCKY, 12)])],
     "peaks": [(-5300, -250, 120, 240)], "pads": [(-4720, -520, -4300, -80, 5)], "basins": [(-4120, -300, 170, -12)],
     "landmark": (-5300, -250), "stamp": (-5260, -220), "landing": (-4280, -300), "dock": (-4170, -300)},
    {"id": "WreckReef", "name": "Wreck Reef", "center": (-3800, 4200), "radius": 600,
     "window": (-4864, 3328, -3328, 5120), "biome": "reef",
     "polys": [ring(-3800, 4200, [(0, 170, ROCKY, 10), (60, 90, ROCKY, 8), (120, 100, ROCKY, 6), (180, 180, ROCKY, 12),
                                  (240, 110, ROCKY, 8), (300, 100, ROCKY, 10)]),
               ring(-3580, 4020, [(0, 50, ROCKY, 8), (120, 45, ROCKY, 6), (240, 55, ROCKY, 7)]),
               ring(-4170, 4420, [(0, 60, ROCKY, 9), (120, 50, ROCKY, 7), (240, 45, ROCKY, 6)]),
               ring(-3640, 4560, [(0, 40, ROCKY, 6), (120, 45, ROCKY, 8), (240, 40, ROCKY, 5)]),
               ring(-4080, 3880, [(0, 45, ROCKY, 7), (120, 40, ROCKY, 5), (240, 50, ROCKY, 8)])],
     "peaks": [(-3800, 4200, 12, 90)], "pads": [],
     "shoals": [(-3900, 4250, 460, -3, True)],
     "landmark": (-3800, 4200), "stamp": (-3930, 4210), "landing": (-3660, 4200), "dock": (-3560, 4200)},
    {"id": "TheArches", "name": "The Arches", "center": (5300, -200), "radius": 650,
     "window": (4352, -1024, 6144, 768), "biome": "stacks",
     "polys": [ring(5350, -150, [(0, 330, CLIFF, 90), (50, 250, CLIFF, 80), (100, 260, CLIFF, 70), (140, 280, ROCKY, 30),
                                 (170, 240, BEACH, 0), (200, 250, ROCKY, 25), (240, 280, CLIFF, 70),
                                 (290, 300, CLIFF, 90), (330, 320, CLIFF, 100)]),
               ring(4950, -500, [(0, 35, CLIFF, 90), (120, 30, CLIFF, 85), (240, 38, CLIFF, 95)]),
               ring(5060, -580, [(0, 28, CLIFF, 70), (120, 30, CLIFF, 65), (240, 26, CLIFF, 75)]),
               ring(5720, 180, [(0, 40, CLIFF, 110), (120, 35, CLIFF, 100), (240, 42, CLIFF, 105)]),
               ring(5600, 320, [(0, 30, CLIFF, 60), (120, 28, CLIFF, 70), (240, 32, CLIFF, 65)]),
               ring(4998, 200, [(0, 36, CLIFF, 70), (120, 34, CLIFF, 75), (240, 38, CLIFF, 70)]),  # the Door, west foot
               ring(5102, 260, [(0, 36, CLIFF, 75), (120, 38, CLIFF, 70), (240, 34, CLIFF, 72)])],  # the Door, east foot
     "peaks": [(5420, -200, 40, 160)], "pads": [],
     "landmark": (5050, 230), "stamp": (5330, -120), "landing": at(5350, -150, 170, 190),
     "dock": at(5350, -150, 170, 330)},
    {"id": "GannetRock", "name": "Gannet Rock", "center": (3500, 3500), "radius": 160,
     "window": (2816, 2816, 4096, 4096), "biome": "guano",
     "polys": [ring(3500, 3500, [(0, 110, CLIFF, 70), (60, 100, CLIFF, 75), (120, 105, CLIFF, 70), (165, 115, ROCKY, 8),
                                 (200, 125, ROCKY, 4), (235, 120, ROCKY, 5), (270, 105, CLIFF, 65),
                                 (310, 110, CLIFF, 75)])],
     "peaks": [(3520, 3490, 15, 50)], "pads": [],
     "landmark": (3520, 3490), "stamp": (3490, 3470), "landing": at(3500, 3500, 205, 95),
     "dock": at(3500, 3500, 205, 190)},
    {"id": "MermaidLagoon", "name": "Mermaid Lagoon", "center": (300, 5600), "radius": 900,
     "window": (-1024, 4352, 1536, 6912), "biome": "lagoon",
     "polys": [ring(300, 4980, [(0, 270, BEACH, 0), (35, 170, BEACH, 0), (90, 120, BEACH, 0), (145, 170, BEACH, 0),
                                (180, 270, BEACH, 0), (220, 150, BEACH, 0), (255, 130, ROCKY, 15), (285, 130, ROCKY, 15),
                                (320, 150, BEACH, 0)]),
               oval(930, 5560, 120, 250, BEACH, 0), oval(-340, 5650, 120, 230, BEACH, 0),
               oval(680, 6170, 200, 105, BEACH, 0), oval(-60, 6210, 190, 100, BEACH, 0)],
     "peaks": [(300, 4950, 30, 70)], "pads": [(360, 4960, 450, 5030, None)],
     "shoals": [(300, 5600, 720, -5, False)],
     "landmark": (300, 4950), "stamp": (340, 4990), "landing": (500, 4950), "dock": (500, 4810)},
]
ISLAND_WINDOWS = [i for i in ARCHIPELAGO if i["window"]]

# Extra rock arches (FillBall half rings, write_terrain.luau arch mode): centre on the sea surface, `across` the
# horizontal unit vector between the feet, `radius` from the centre to each foot.
ARCHES = [{"id": "TheDoor", "center": (5050, 230), "y": 0, "across": (0.866, 0.5), "radius": 60, "thick": 12}]
