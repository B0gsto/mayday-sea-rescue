"""World layout for the Gale Isles terrain generator (hand-authored data, docs/10-world-and-map.md).

Coordinates are studs from the Port Haven station slipway: +X east, -Z north (inland), +Z south (out to sea),
sea level Y = 0, 1 m = 3 studs. This file is the single source for the island masks, roads and points of interest;
gen_terrain.py bakes the terrain from it and writes src/shared/Config/WorldConfig.luau from it.
"""
import math

SEED = 1871  # the year the Port Haven lifeboat station opened (any fixed integer keeps the bake deterministic)

# MVP bake window (doc 10, section 1.2: MVP radius about 2,500 studs). The masks below already cover the whole
# island, so widening HALF_EXTENT (and the domain) is all it takes to bake the full map later.
CELL = 4  # studs per heightmap sample = Terrain voxel size
HALF_EXTENT = 2560  # bake x, z in [-HALF_EXTENT, +HALF_EXTENT]
MVP_RADIUS = 2500
SEABED_FLOOR_Y = -165  # deeper water gets this flat floor (doc 10 section 4.1: detail only to about 40 m)

# Coast kinds. Each polygon vertex carries a kind and a coast-top height H (studs); the profile blends between
# vertices along the coast, so a cliff fades into a rocky shore and then a beach.
CLIFF, ROCKY, BEACH, HARBOUR, MUD = "cliff", "rocky", "beach", "harbour", "mud"
KINDS = (CLIFF, ROCKY, BEACH, HARBOUR, MUD)

# Great Gale, the main island, as one closed polygon (x, z, kind, H), west to east along the south coast, then
# north up the east coast and back along the north and west coasts (doc 10 sections 1.1 and 1.2).
GREAT_GALE = [
    (-5600, 520, CLIFF, 210),  # Tempest Point
    (-5150, 760, CLIFF, 180),  # Wreckers' Cove
    (-4500, 420, CLIFF, 150),
    (-3400, 260, CLIFF, 110),  # West Arm
    (-2500, 130, ROCKY, 60),
    (-1850, -150, BEACH, 0),  # Westgate cove and public slipway [L]
    (-1500, 40, ROCKY, 45),
    (-950, 70, ROCKY, 30),
    (-600, 40, ROCKY, 16),
    (-330, 0, HARBOUR, 4),  # west breakwater root
    (330, 0, HARBOUR, 4),  # east breakwater root
    (480, 40, ROCKY, 10),
    (640, 130, BEACH, 0),  # Haven Sands, north end
    (1000, 370, BEACH, 0),  # Haven Sands centre (doc: +1,000, +400)
    (1340, 590, BEACH, 0),  # Haven Sands, south end (rock pools beyond)
    (1500, 720, ROCKY, 60),  # rock pools under Haven Head
    (1640, 900, CLIFF, 120),  # Haven Head (40 m)
    (1830, 840, CLIFF, 110),
    (2200, 650, CLIFF, 90),
    (2600, 630, BEACH, 0),  # Gull Cove [L]
    (2900, 380, CLIFF, 130),
    (3150, -400, CLIFF, 150),
    (3150, -1200, CLIFF, 150),  # Kittiwake Cliffs [L]
    (2900, -2600, ROCKY, 60),
    (2000, -3900, ROCKY, 40),
    (200, -4500, ROCKY, 20),  # North Quay [P1]
    (-1500, -4300, BEACH, 0),  # Northshore shingle [P1]
    (-2600, -3300, MUD, 0),  # the Saltings [L]
    (-3300, -2500, BEACH, 0),
    (-4150, -1500, BEACH, 0),  # Long Strand, north [L]
    (-4150, -500, BEACH, 0),  # Long Strand, south
    (-4500, 0, CLIFF, 120),
    (-5300, 250, CLIFF, 180),
]

# Skerry Isle (doc: +1,800, +1,750, about 400 x 250 m) sits on the MVP edge; baked as a granite isle now so the
# Skerries [L] only add detail later.
SKERRY_ISLE = [
    (1460, 1700, ROCKY, 30),
    (1700, 1560, CLIFF, 45),
    (2080, 1600, ROCKY, 35),
    (2200, 1800, CLIFF, 40),
    (1950, 1950, ROCKY, 25),
    (1560, 1900, ROCKY, 20),
]

ISLANDS = [GREAT_GALE, SKERRY_ISLE]

# The greybox harbour (map/Build.luau): breakwater arms at x = +-320 from z = -20 to 368, the 60-stud mouth at
# x = +-30. Gameplay (CallTypes.Areas, the Weather zone tests) depends on this, so the terrain dredges the basin to
# fit it rather than moving it (doc 10 section 6.6 re-lays the mouth to about 900 studs later).
HARBOUR = {"minX": -312, "maxX": 312, "minZ": 4, "maxZ": 368, "innerY": -13, "mouthY": -24, "channelHalf": 40}
TOWN_PLATFORM = {"minX": -720, "maxX": 720, "minZ": -560, "maxZ": -20, "y": 4, "blend": 140}
# WP-3: the hillside behind (north of) the town platform (fading out `fadeX` past its ends and `depth` studs north):
# a natural slope with short granite retaining-wall runs `step` studs high (`wall` = wall share of each run) only in
# the `wallBand` studs above the town and within `roadBand` of Chapel Hill, and contour field hedges every `hedgeRise`
# studs of height; the moor ridge on the skyline behind it (crest z, half-width, height; a col at x colX for the
# High Road) with tors.
TOWN_HILL = {"step": 9, "wall": 0.12, "fadeX": 180, "depth": 520, "wallBand": 150, "roadBand": 60, "hedgeRise": 15,
             "treeY": 64}
MOOR_RIDGE = {"z": -1720, "width": 240, "height": 85, "colX": 40, "tors": 9}
HARBOUR_COVE = {"minX": 186, "maxX": 312, "topZ": -20, "toeZ": 110, "topY": 4, "toeY": -7}  # small sand cove

# Haven Sands: beach dimensions (doc 10 section 2.6) and the Bar sandbar offshore.
BEACH_WIDTH = 120  # studs of sand from the waterline to the dune toe
DUNE_WIDTH = 110
BAR = {"offshore": 250, "width": 46, "topY": -3, "from": (700, 170), "to": (1290, 560)}

# Roads: polylines with width and terrain material (doc 10 section 2.1). Heights follow the terrain, smoothed.
ROADS = [
    {"id": "HarbourRoad", "name": "Harbour Road", "surface": "Asphalt", "width": 30,
     # jogs 5 studs onto the quay past the station so its forecourt row (z -37.6) stands on a pavement; widened
     # 22 -> 30 toward the quay (centre +4 z) so the north kerb stays put
     "points": [(-560, -26), (-300, -26), (-190, -26), (-165, -21), (-55, -21), (-30, -26), (180, -26), (330, -36),
                (420, -46)]},
    {"id": "CoastRoadWest", "name": "Coast Road", "surface": "Asphalt", "width": 26,  # to the West Cliff car park
     "points": [(-560, -26), (-640, -32), (-740, -24), (-840, -12), (-872, -8)]},
    {"id": "CoastRoadEast", "name": "Coast Road", "surface": "Asphalt", "width": 26,
     "points": [(420, -46), (560, -40), (700, -10), (820, 40), (900, 80)]},
    {"id": "HavenHeadTrack", "name": "Haven Head track", "surface": "Ground", "width": 10,
     "points": [(900, 80), (1060, 150), (1230, 260), (1390, 400), (1500, 520), (1590, 640)]},
    {"id": "TownLane", "name": "Chapel Hill", "surface": "Asphalt", "width": 30,  # the Port Haven grid's x 20 avenue
     "points": [(20, -490), (60, -600), (140, -700), (180, -800)]},  # runs on up the hill to the High Road
    {"id": "HighRoad", "name": "High Road", "surface": "Asphalt", "width": 15,
     "points": [(180, -800), (120, -1100), (60, -1500), (0, -1900), (-20, -2060)]},  # the bake coast closes ~2,200 out
    {"id": "SandsSlipway", "name": "Haven Sands slipway", "surface": "Concrete", "width": 12,
     "points": [(900, 150), (940, 205), (985, 262), (1015, 300)]},
]

# Towns: one data block per city (doc 10 section 2.4). A town is a street grid on flat ground: `avenues` run
# north-south at x = origin.x + offset, from the `south` road (its z at that x) to the last street; `streets` run
# east-west at z = origin.z + offset across all avenues. Each grid line becomes a WorldConfig road (id
# <town>_Av<n> / <town>_St<n>, `town` set), so RoadNet finds the junctions and lights; WorldConfig.Towns carries the
# block for src/server/World/TownLayout.luau, which lines every block side that faces a town street with cottages
# (terraced, front to the street) clear of the `keep` rects {x0, z0, x1, z1} (gameplay buildings and yards).
# Another city = another entry here (flat ground under it: a TOWN_PLATFORM-style pad in the bake).
TOWNS = [
    {"id": "PortHaven", "name": "Port Haven", "origin": (0, -30), "south": ("HarbourRoad", "CoastRoadEast"),
     "surface": "Asphalt",  # avenues start on the first `south` road that reaches their x
     "width": 30,  # two 5 m lanes (playtest: 22 read too narrow to drive)
     "footway": 8,  # pavement + parking strip each side (studs)
     "avenues": [(-540, "Penhallow Road"), (-380, "Quay Lane"), (-220, "Station Hill"), (20, "Chapel Hill"),
                 (200, "Hospital Lane"), (380, "Eastgate Hill"), (560, "Tregenna Hill")],
     "streets": [(-130, "Fore Street"), (-240, "Church Street"), (-350, "Trelawney Road"), (-460, "Bodmin Road")],
     "keep": [(-392, -160, -231, -20),  # the boatyard (TownExtras) and the station yard spawn
              (-212, -100, 12, -20),  # station, chandlery, forecourt, notice row
              (88, -152, 176, -20),  # the Cottage Hospital
              (35, -251, 121, -175)]},  # Chapel Square (Town.luau): the chapel and a paved square on Fore Street
]


def _z_on(road_ids, x):
    for road_id in road_ids:
        pts = next(r for r in ROADS if r["id"] == road_id)["points"]
        for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
            if min(x0, x1) <= x <= max(x0, x1) and x0 != x1:
                return z0 + (z1 - z0) * (x - x0) / (x1 - x0)
    raise ValueError(f"{road_ids} do not reach x {x}")


def town_roads(t):
    ox, oz = t["origin"]
    xs = [ox + a for a, _ in t["avenues"]]
    top = oz + t["streets"][-1][0]
    out = []
    for n, (a, name) in enumerate(t["avenues"], 1):
        x = ox + a
        out.append({"id": f"{t['id']}_Av{n}", "name": name, "surface": t["surface"], "width": t["width"],
                    "town": t["id"], "points": [(x, round(_z_on(t["south"], x), 1)), (x, top)]})
    for n, (b, name) in enumerate(t["streets"], 1):
        out.append({"id": f"{t['id']}_St{n}", "name": name, "surface": t["surface"], "width": t["width"],
                    "town": t["id"], "points": [(xs[0], oz + b), (xs[-1], oz + b)]})
    return out


for _t in TOWNS:
    ROADS += town_roads(_t)

CAR_PARKS = [
    {"id": "HavenSandsCarPark", "name": "Haven Sands car park", "surface": "Asphalt",
     "center": (880, 115), "size": (130, 80), "yaw": 33},
    {"id": "WestCliffViewpoint", "name": "West Cliff car park", "surface": "Pavement",  # Coast Road west ends here
     "center": (-900, -5), "size": (64, 44), "yaw": 0},
    {"id": "HavenHeadViewpoint", "name": "Haven Head viewpoint", "surface": "Ground",
     "center": (1600, 665), "size": (60, 40), "yaw": 45},
]

# Farmsteads: a gravel yard (paved and flattened like a car park) with a farmhouse and a barn (Town.luau farms()).
FARMS = [
    {"id": "Trevose", "name": "Trevose Farm", "surface": "Pavement", "center": (-720, -920), "size": (96, 72), "yaw": 18},
    {"id": "Penmorvah", "name": "Penmorvah Farm", "surface": "Pavement", "center": (1040, -1180), "size": (96, 72),
     "yaw": -14},
]

# Seabed areas (rock reefs and kelp, gravel, eelgrass) as circles: centre, radius, kind.
REEFS = [
    {"id": "HavenHeadReef", "center": (1720, 1040), "radius": 260, "topY": -4},
    {"id": "SkerriesReefN", "center": (1600, 1420), "radius": 240, "topY": -2},
    {"id": "SkerriesReefE", "center": (2250, 1500), "radius": 200, "topY": -3},
    {"id": "WestLedges", "center": (-1200, 380), "radius": 230, "topY": -6},
    {"id": "WestArmRocks", "center": (-2300, 520), "radius": 260, "topY": -5},
]
KELP_BEDS = [  # kelp on rock from 2 to 15 m (Slate material now, kelp props later)
    {"id": "HavenHeadKelp", "center": (1700, 1030), "radius": 230},
    {"id": "SkerriesKelp", "center": (1650, 1450), "radius": 220},
    {"id": "WestLedgesKelp", "center": (-1200, 380), "radius": 200},
]
EELGRASS = [  # seagrass meadows on sheltered sand (props later)
    {"id": "CalmBayEelgrass", "center": (860, 520), "radius": 170},
]
# Old Ned's kelp gully: a trench cut through the Haven Head reef, with the rock arch over it.
GULLY = {"from": (1600, 960), "to": (1860, 1130), "halfWidth": 18, "floorY": -30}

# Points of interest and markers (doc 10 sections 3.2, 4.2 and 5.2). Y is filled from the bake where "y" is None.
POIS = [
    {"id": "Morwenna", "kind": "Wreck", "name": "Morwenna", "era": "1902",
     "blurb": "A wooden trading schooner lost off Haven Sands in the gale of 1902.",
     "pos": (620, None, 860), "yaw": 28, "length": 84, "beam": 21},
    {"id": "MailSeaplane", "kind": "Wreck", "name": "The mail seaplane", "era": "1960s",
     "blurb": "A mail seaplane that ditched on the Skerries sand; wrasse live in the cockpit.",
     "pos": (1300, None, 1200), "yaw": -35, "length": 39, "beam": 50},
    {"id": "AdmiraltyAnchor", "kind": "Find", "name": "Admiralty anchor", "era": "1840s",
     "blurb": "An Admiralty-pattern anchor lying beside the harbour wall.",
     "pos": (288, None, 250), "yaw": 70, "length": 12, "beam": 10},
    {"id": "NedsGully", "kind": "Seabed", "name": "Old Ned's kelp gully", "era": "",
     "blurb": "A kelp-lined gully under Haven Head where the old seal hunts.",
     "pos": (1730, None, 1045), "yaw": 33, "length": 300, "beam": 36},
    {"id": "GullyArch", "kind": "Seabed", "name": "The Needle's Eye", "era": "",
     "blurb": "A granite arch spanning Old Ned's gully.",
     "pos": (1760, None, 1066), "yaw": 33, "length": 30, "beam": 60},
    {"id": "HavenHead", "kind": "Viewpoint", "name": "Haven Head", "era": "",
     "blurb": "The headland viewpoint over Calm Bay and the Skerries.",
     "pos": (1600, None, 665), "yaw": 0, "length": 0, "beam": 0},
    {"id": "HavenSandsRockPools", "kind": "RockPool", "name": "Haven Sands rock pools", "era": "",
     "blurb": "Rock pools under Haven Head: anemones, crabs, blennies and a starfish.",
     "pos": (1440, None, 700), "yaw": 0, "length": 0, "beam": 0},
]

# Land points: beaches, launch points, spawns and handover points (doc 10 sections 2.6 and 3.2).
POINTS = [
    {"id": "StationSlipway", "kind": "Launch", "pos": (-165, 2, 30)},
    {"id": "HavenSandsSlipway", "kind": "Launch", "pos": (1015, None, 300)},
    {"id": "HavenSandsCarPark", "kind": "VehicleSpawn", "pos": (880, None, 115)},
    {"id": "StationYard", "kind": "VehicleSpawn", "pos": (-260, 4, -52)},
    {"id": "HavenSandsAmbulance", "kind": "Handover", "pos": (850, None, 95)},
    {"id": "HavenSandsTower", "kind": "LifeguardTower", "pos": (1010, None, 250)},
    {"id": "HavenSandsBeach", "kind": "Beach", "pos": (1000, None, 370)},
]

# ---------------------------------------------------------------- the archipelago (docs/21 sections 2.2 and 6.1)
# The main window above stays byte-identical. Each new island gets its own bake window (x0, z0, x1, z1) on the
# 256-stud tile grid, disjoint from the main window and from each other; only that island's polygons are baked in
# it (Great Gale's polygon reaches x -5,600 and must not leak into Penwyn). Outside every window there are no voxels:
# the opaque mesh ocean hides the missing deep floor. Island polygons are rings round a centre:
# (bearing deg: 0 east, 90 south, 180 west, 270 north; radius; coast kind; coast-top H).
MAP_RADIUS = 7000  # playable sea (GameConfig.MapRadius; vehicles reset past MAP_RADIUS + 200)
MAP_CANVAS = 7168  # the map image covers x, z in +-MAP_CANVAS (MapConfig Origin / Extent)


def ring(cx, cz, pts):
    return [(round(cx + r * math.cos(math.radians(a))), round(cz + r * math.sin(math.radians(a))), k, h)
            for a, r, k, h in pts]


def at(cx, cz, bearing, r):
    return (round(cx + r * math.cos(math.radians(bearing))), round(cz + r * math.sin(math.radians(bearing))))


def oval(cx, cz, rx, rz, kind, h, n=8):
    return ring(cx, cz, [(360 * k / n, rx * rz / math.hypot(rz * math.cos(2 * math.pi * k / n),
                                                            rx * math.sin(2 * math.pi * k / n)), kind, h)
                         for k in range(n)])


# Island keys: id, name, centre, radius (studs, for zones / discovery), window (None: in the main window), polys,
# peaks [(x, z, height, radius)] (gaussian hills over the coast profile), pads [(x0, z0, x1, z1, y)] (flat ground
# for B1 buildings; y None = the ground's mean), basins [(x, z, radius, floorY)] (dredged harbour water),
# shoals [(x, z, radius, topY, rock)] (raised seabed: reef rock or lagoon sand), biome (material
# accent: granite, chalk, village, reef, stacks, guano, lagoon), landmark (x, z) where the silhouette stands,
# stamp (x, z) the stamp post (land), landing (x, z) the shore end of a jetty (land) and dock (x, z) its sea end
# (water: boats stop here; DropOff docks for B3).
ARCHIPELAGO = [
    {"id": "SkerryIsle", "name": "Skerry Isle", "center": (1800, 1750), "radius": 420, "window": None,
     "landmark": (1520, 1700), "stamp": (1560, 1730), "landing": (1640, 1640), "dock": (1640, 1530)},
    {"id": "StElowensMount", "name": "St Elowen's Mount", "center": (-200, -3000), "radius": 320,
     "window": (-768, -3840, 512, -2560), "biome": "granite",
     "polys": [ring(-200, -3000, [(0, 290, ROCKY, 30), (40, 270, ROCKY, 18), (75, 265, BEACH, 0), (100, 280, BEACH, 0),
                                  (135, 265, ROCKY, 15), (180, 300, CLIFF, 50), (225, 290, CLIFF, 70),
                                  (270, 310, CLIFF, 80), (315, 300, CLIFF, 60)])],
     "peaks": [(-210, -3030, 150, 170)], "pads": [(-250, -2870, -150, -2810, None)],
     "landmark": (-210, -3030), "stamp": (-180, -2950), "landing": at(-200, -3000, 50, 210),
     "dock": at(-200, -3000, 50, 340)},
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
     "polys": [ring(-4800, -300, [(0, 560, HARBOUR, 4), (22, 700, ROCKY, 12), (55, 580, BEACH, 0), (90, 520, ROCKY, 30),
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

# The Mount causeway: a sand spit from Great Gale's north shore to the Mount's south beach, its top just under the
# sea (C4 raises / lowers the walkway Parts on it). Only the Mount-window part is baked (z < -2560); the main window
# stays byte-identical, so north of the seam the walkway stands on the -30 to -36 stud seabed.
CAUSEWAY = {"from": (-150, -2290), "to": (-190, -2720), "width": 34, "topY": -3}

# Extra rock arches (FillBall half rings, write_terrain.luau arch mode): centre on the sea surface, `across` the
# horizontal unit vector between the feet, `radius` from the centre to each foot.
ARCHES = [{"id": "TheDoor", "center": (5050, 230), "y": 0, "across": (0.866, 0.5), "radius": 60, "thick": 12}]
