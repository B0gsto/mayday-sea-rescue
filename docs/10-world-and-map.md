# 10 · World and map

The Gale Isles are one big open map: a main island with a working town, a coast road, beaches, cliffs and lighthouses, outlying islands, and a whole seabed to explore. Players drive to the beach and back to the station, launch boats from slipways and trailers, and roam freely between operations. This file owns the **world layout**: geography, roads, beaches, land vehicles' roles and spawn points, the seabed and what is on it, discoverables, free exploration and the tech for building and streaming the world.

Canon (names, tone, scope) comes from [`01-game-canon.md`](01-game-canon.md). [Document 02](02-core-loop-and-mechanics.md) still owns mechanics, **map scale and vehicle speeds** ([section 4.1](02-core-loop-and-mechanics.md#41-map-scale-and-travel-budget)) and gravity ([section 4.2](02-core-loop-and-mechanics.md#42-gravity-and-scale)); the travel times here are worked from its speed table. [Document 03](03-progression.md) owns numbers (unlock ranks, exploration Cash). [Document 05](05-art-direction.md) owns the look, [document 06](06-tools-and-pipeline.md) owns the general tech, and [document 09](09-rescue-operations.md) owns the operations that use this world. Numbers marked **(tune)** are first guesses; engine facts marked **(verify)** must be checked in Studio or the official docs before code depends on them.

**Coordinates.** All positions are in studs from the Port Haven station slipway at the world origin, as in the greybox (`map/Build.luau`): **+X is east, -Z is north (inland), +Z is south (out to sea)**, sea level is Y = 0. Scale is **1 m = 3 studs** ([document 05](05-art-direction.md), section 4.1).

## 1. The world at a glance

### 1.1 Map

North is up. The sketch is schematic; the coordinates in section 1.2 are the reference.

```
                 ICEBERG NORTH [P1]   6,000-9,000 studs north
                 pale water, floes, Northlight Island (+500, -8,000)
 ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
                    OPEN SEA (north water) [L]
                          North Quay [P1]
             Northshore     o==== Northshore road [P1] ====.
          ___shingle________|______________________________ \___
        _/  Saltings        |      High Moor      ^ Gale       \__
      _/    mudflats [L]    |  High Road (moor)     Beacon        \
     /                      |                       120 m        | Kittiwake
    |  LONG STRAND [L]      |    GREAT GALE (main island)        | Cliffs [L]
    |  700 m surf beach     |    2.9 km x 1.6 km                 | cliff-top
    |  dunes, rips          |                                    | road
    |  Strand beach         |                                   /
    |  station (tractor)    |                                  /  Gull Cove [L]
     \___ Westgate ___      |                      Coast Road /   sea cave
  Tempest  \___West Arm___\===== PORT HAVEN =================/ Haven Head
  Point [L]  cliff-top road   station* town  hospital   Haven Sands [MVP]
  Light, 70 m cliffs          chandlery, harbourmaster   (beach, tower, car park)
                              fuel dock + boatyard  CALM BAY [MVP]
  Wreckers' Cove (cave)       wall ========  mouth  ======== wall + Harbor Light
                                      HARBOUR MOUTH [MVP] (900 studs)
                                                 Sandy Point [MVP] (spit, cold open)
 STORM FRONT [L]                                 THE SKERRIES [L]
 west and south-west,                              Skerry Isle + outpost (2,500)
 6,000-7,000 studs                                 reefs, kelp, seals
                     Puffin Isle [L]
                     (4,300, boat or helicopter)          Gannet Rock + outpost
                                                          (5,000, boat or winch)
                              OPEN SEA [L]
                    ferry lane to the mainland (off the map, south)
 ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ playable edge: 7,500 studs radius ~ ~ ~ ~ ~ ~ ~ ~
```

### 1.2 Places and real dimensions

| Place | Centre (X, Z studs) | Real size (tune) | Reached by | Zone | Scope |
|---|---|---|---|---|---|
| **Port Haven station and slipway** | 0, 0 | Compound about 120 x 80 m | Road, sea, helicopter [L] | Calm Bay | [MVP] |
| Port Haven town (crescent around the inner harbour) | +100, -400 | About 600 x 250 m | Road, foot | Calm Bay | [MVP] |
| Cottage Hospital (pontoon, ambulance bay, helipad [L]) | +150, -150 | | Road, sea | Calm Bay | [MVP] |
| **Port Haven Chandlery** (marine outfitter: the walk-in store for gear, uniforms, cosmetics and passes) | +40, -20 | About 20 x 12 m, two floors (shop and fitting loft) | Road, foot | Calm Bay | [MVP] building and Cash gear; [L] Robux items |
| Harbourmaster's office (Storm Summon desk, storm queue board) | +65, -20 | About 10 x 8 m | Road, foot | Calm Bay | [L] |
| Fuel dock and **boatyard** (boats bought, fitted and collected; slipway, cradles, a travel hoist) | +200, -50 | About 80 x 50 m yard | Road, sea | Calm Bay | [MVP] |
| **Calm Bay** (inside the harbour wall) | +700, +450 | About 500 x 300 m of sheltered water | Sea | Calm Bay | [MVP] |
| **Harbour mouth** (gap in the wall) and Harbor Light on the east wall head | +330, +920 | Gap about 50 m (tune) | Sea | Calm Bay (storm-exposed) | [MVP] |
| **Sandy Point** (a low sandy spit at the outer foot of the east harbour wall; the cold open's casualty is found about 300 m south of it, [document 09](09-rescue-operations.md), section 9.1) | +550, +950 | About 150 x 40 m of sand and shingle (tune) | Foot along the wall, sea | Calm Bay (storm-exposed) | [MVP] |
| **Haven Sands** (beach, lifeguard tower, car park, dunes, rock pools) | +1,000, +400 | About 370 m of sand | Road, sea | Calm Bay | [MVP] |
| Haven Head (headland, viewpoint) | +1,600, +800 | 40 m high | Road, foot | Calm Bay | [MVP] |
| Gull Cove (small cove, steep track, sea cave) | +2,600, +600 | About 120 m of sand | Track, sea | The Skerries | [L] |
| Kittiwake Cliffs (east coast, cliff-top road and rescue point) | +3,000, -1,200 | 50 m cliffs | Road | The Skerries | [L] |
| Gale Beacon (island summit, viewpoint) | +800, -2,600 | 120 m high | Gravel track | | [L] |
| High Moor (heather, standing stones, the High Road) | 0, -2,500 | About 1.2 x 0.7 km | Road | | [L] |
| Saltings (estuary mudflats, bird hide) | -2,800, -2,800 | About 600 x 400 m | Road, track | The Skerries | [L] |
| **Long Strand** (surf beach) and the Strand beach lifeboat station | -3,900, -1,000 | About 700 m of sand, big dunes | Road, sea | The Skerries tier | [L] |
| Westgate (hamlet, public slipway, café) | -1,800, -200 | | Road | | [L] |
| **Tempest Point** and Tempest Point Light | -5,600, +500 | 70 m cliffs | Single-track road, sea | Storm Front | [L] |
| Wreckers' Cove (sea cave under Tempest Point) | -4,800, +700 | | Boat or swim only | Storm Front | [L] |
| **Skerry Isle** (Skerry Light, dive shop, outpost dock) | +1,800, +1,750 | About 400 x 250 m | Boat, helicopter | The Skerries | [L] |
| **Puffin Isle** (abandoned hamlet, puffin colony, seal beach, landing site) | -2,600, +3,400 | About 600 x 350 m | Boat, helicopter | Open Sea | [L] |
| **Gannet Rock** (Gannet Rock Light, outpost dock) | +3,500, +3,550 | About 80 m across | Boat, helicopter winch | Open Sea | [L] |
| North Quay (north harbour, slipway, Iceberg North launch point) | +200, -4,400 | | Road, sea | Open Sea | [P1] |
| Northlight Island (Northlight, research station) | +500, -8,000 | | Boat, hovercraft, helicopter | Iceberg North | [P1] |

**Size.** The main island, **Great Gale**, is about 2.9 km east to west (Tempest Point to Kittiwake Cliffs, about 8,600 studs) and 1.6 km north to south (about 4,800 studs), about 3 km² of land. Its summit is 120 m (360 studs); cliffs run 40 to 70 m (120 to 210 studs). The **playable area** is a circle of 7,500 studs radius (2.5 km, so 5 km across) at launch and 9,000 studs (3 km) with Iceberg North, matching [document 02](02-core-loop-and-mechanics.md#41-map-scale-and-travel-budget). The MVP map is a 2,500-stud radius (tune) around the station. Keep everything inside about ±10,000 studs of the origin, where physics precision is known to hold (verify the distance at which jitter starts).

**Zones on the map.** Document 02's zone rings are distances from the station, measured at sea. The island fills the northern half of the inner rings, so on the map a zone is an area: Calm Bay is the water inside the wall plus Haven Sands; the Skerries are the reefs and isles south-east, plus Gull Cove, Kittiwake Cliffs, the Saltings and the west-coast surf at Long Strand (all paid as the Skerries tier, opened at Lifeguard); Open Sea is the deep water beyond about 3,500 studs (south, and the north water); Storm Front is the west and south-west sea beyond Tempest Point. The zone volumes in `GameConfig.Zones` become polygons instead of circles (section 6.6).

**The edge.** Past the playable radius the swell builds, the Coastguard calls "Haven Rescue, you are leaving the Gale Isles area", and after 20 s (tune) the vehicle is gently turned back. The ferry lane runs off the south edge to an unseen mainland.

### 1.3 Travel times

Big but dense: the world is large enough that the car, the boat and the helicopter each have a job, and small enough that nothing is a chore. Times are from the station, at the cruise speeds in [document 02](02-core-loop-and-mechanics.md#41-map-scale-and-travel-budget) (all tune).

| Destination | Car (4x4) | Jet ski | RIB | Lifeboat | Helicopter |
|---|---|---|---|---|---|
| Harbour mouth | | 0:17 | 0:20 | 0:25 | 0:08 |
| Haven Sands | 0:40 (car park) | 0:21 | 0:24 | 0:31 | 0:10 |
| Gale Beacon viewpoint | 1:10 | | | | 0:25 |
| Skerry Isle outpost | | 0:48 | 0:56 | 1:09 | 0:23 |
| Gull Cove | 1:25 | 0:54 | 1:02 | 1:18 | 0:25 |
| Kittiwake Cliffs rescue point | 1:30 | | | | 0:30 |
| Long Strand car park / Strand station | 1:30 / 1:25 | 2:55 (round Tempest Point) | 3:20 | 4:10 | 0:36 |
| North Quay [P1] | 1:30 | | | | 0:40 |
| Puffin Isle | | 1:23 | 1:36 | 1:59 | 0:39 |
| Gannet Rock outpost | | 1:36 | 1:51 | 2:19 | 0:45 |
| Tempest Point | 2:05 | 1:52 | 2:09 | 2:41 | 0:51 |
| Northlight [P1] | | (from North Quay, hovercraft 1:30) | | | 1:13 |

**Density rules (tune):**

1. **No drive from the station over about 2 minutes**, and none to a beach over 1:30. Tempest Point (2:05) is the one long drive, and it is the best view in the game.
2. **Something every 20 seconds.** No stretch of road longer than about 1,000 studs (20 s at cruise) without a junction, a viewpoint, a beach track, a hamlet, a farm, a point of interest or a change of scenery (town to moor to cliff).
3. **The right tool wins.** The car is the fast way to the west coast and the cliffs, the boat the fast way to the Skerries and the outer isles, the helicopter the fast way to everything. Operations are tasked so that the intended vehicle meets document 02's 45-second passage budget from the nearest open dock, car park or station ([document 09](09-rescue-operations.md), section 10).
4. **Return to station.** On land and off a vehicle, a player can always fade back to their bay (the existing "Back to Station" action, 30 s cooldown, tune), so nobody exploring the moor faces a dead drive to answer a sea tasking.

## 2. Land

### 2.1 Road network

| Road | Route | Surface and width | Character | Scope |
|---|---|---|---|---|
| **Harbour Road** | Station, quays, fish market, ferry pier, hospital, Eastgate | Asphalt and cobbles, 6 m (18 studs) | Town speed (about 30 km/h), parked cars, pedestrians, steep lanes off it | [MVP] |
| **Coast Road, east** | Eastgate, Haven Sands car park, over Haven Head, Gull Cove turn, Kittiwake Cliffs | Asphalt, 6 m, white lines | Rolling, sea views, crash barriers on the headland | [MVP] to Haven Sands; [L] beyond |
| **Coast Road, west** | Station, Westgate, the Saltings, Long Strand, Strand station | Asphalt, 5.5 m | Hedged lanes, then open dunes | [L] |
| **West Arm road** | Coast Road to Tempest Point | Single-track asphalt with passing places, 3.5 m | Cliff-top, wind, the lighthouse ahead the whole way | [L] |
| **High Road** | Port Haven north over the moor to North Quay | Asphalt, 5 m, cattle grids | Open moor, standing stones, Gale Beacon turn | [L] to Gale Beacon; [P1] to North Quay |
| **Northshore road** | North Quay along the north coast | Asphalt | Shingle beach, Iceberg North views | [P1] |
| **Beach access tracks** | Haven Sands slipway; Gull Cove track; Long Strand dune track | Concrete ramp; steep gravel; sand | Low range, the ATV's home | [MVP] Haven Sands; [L] the rest |
| **Cliff-top tracks** | To the Kittiwake and Tempest Point rescue points and viewpoints | Grass and gravel | Slow, bumpy, gated | [L] |

Traffic drives on the **left**, in keeping with the Cornish and Scottish references (decide in playtest). Light NPC traffic [L] (a bus, a farm tractor, a few cars, a delivery van) runs on splines, pulls over for blue lights, and passes through players' vehicles like everything else ([document 02](02-core-loop-and-mechanics.md), section 10). Vehicles never hit pedestrians: characters and cars do not collide (collision groups).

### 2.2 Surfaces

Every surface has a handling profile for the chassis (section 3.3) and a wet variant in rain ([document 05](05-art-direction.md), section 5.2).

| Surface | Where | Grip (tune) | Handling |
|---|---|---|---|
| Asphalt | Roads, car parks in town | 1.0 dry, 0.75 wet | Full speed |
| Cobbles and granite setts | Quays, old town | 0.85 dry, 0.6 wet | Rattly, town speed anyway |
| Concrete | Slipways, station apron | 0.9 dry, 0.5 on weedy wet slipway bottoms | Slipway bottoms are slick, as real ones are |
| Gravel | Tracks, cliff-top car parks | 0.7 | Loose, slides, dust in dry weather |
| Hard wet sand | Beach below the tide line | 0.65 | Good for the ATV and 4x4 |
| Soft dry sand and dunes | Upper beach | 0.5, high rolling resistance | Low range or get stuck (a gentle "dig out" step, never a fail) |
| Mud | Saltings, field gateways, track ruts after rain | 0.35 | Slithers; the Saltings flats are off-limits to vehicles (signs, and the real reason: people get stuck) |
| Grass | Cliff-tops, verges | 0.6 dry, 0.4 wet | Bumpy |

### 2.3 Road furniture

Real, specific, never generic: white and yellow road lines with cat's eyes, passing-place signs on the West Arm, cattle grids and dry-stone walls and Cornish hedges (stone-faced earth banks with gorse), field gates, fingerposts, bus stops and a timetable, street lamps in town only, crash barriers on Haven Head, invented UK-style road signs (no real sign copies), coastal path waymarks, lifebuoy stations along the quays and cliff paths, cliff-edge warning signs, tide-table boards and launch signs at every slipway, an emergency telephone at Long Strand, and red-and-yellow and black-and-white chequered beach flags marking the patrolled swimming zone and the craft zone (verify: RNLI beach flag meanings).

### 2.4 Port Haven town

The crescent harbour from [document 01](01-game-canon.md), section 4, laid out for driving and walking:

- **Waterfront (Harbour Road):** the station at the west end of the harbour wall; right next to it on the quay the **Port Haven Chandlery** (the in-world store, [document 04](04-monetization.md), section 1.1; its door about 30 studs from the station door and the spawn point, tune) and the harbourmaster's office; the fuel dock and the **boatyard** (boats on stands, a price board, the collection pontoon), granite quays with fishing boats on moorings, the fish market, Nell's bait shop on the pier, the ferry pier with Hazel's ticket booth and the *Gale Queen*'s berth.
- **Up the hill:** painted terraces in stepped lanes (foot only), a chapel, a small shop, the Cottage Hospital with its ambulance bay, the hospital pontoon on the water below and a helipad [L].
- **Edges:** Westgate and Eastgate, where Harbour Road becomes the Coast Road; a public car park at each.
- **Street grid (built):** behind Harbour Road the town is a grid of two-lane streets (30 studs = 2 x 5 m lanes, right-hand traffic, an 8-stud pavement and parking strip each side): avenues Quay Lane (x -380), Station Hill (-220), Chapel Hill (20, which carries on up the hill to the High Road), Hospital Lane (200) and Eastgate Hill (380), crossed by Fore Street (z -160) and Church Street (z -270). RoadNet signals all 13 junctions. Every block side facing a grid street is lined with terraced cottages (the six H3 variants, five render colours, fronts to the street); the west block (Quay Lane / Station Hill) is the boatyard (concrete hardstanding, shed, travel hoist with a crabber in its slings); the station, Chandlery, notice row and pet yard, and the hospital keep their blocks.
- **More cities:** a city is one data block in `tools/world/layout.py` `TOWNS` (id, name, origin, south road, width, footway, avenue x offsets with names, street z offsets with names, keep rects). Adding an entry (on flat ground) is all it takes: the generator turns its grid lines into roads (`WorldConfig.Roads`, `town` set) and `WorldConfig.Towns`; at start `World/Town.luau` paints the streets and fills the blocks.

### 2.5 The station compound

- Boathouse and slipway, crew room, changing room with the player lockers, kit store, Chief Aggie's office and the honour board.
- The **bays** (each player's berth and locker, [document 03](03-progression.md), section 6), with their own launch lanes ([document 02](02-core-loop-and-mechanics.md), section 10).
- **Vehicle garage and yard:** the pool 4x4s, response vehicles and trailers, with a marked spawn bay per player (section 3.2).
- Helipad [L], the Lookout Tower upgrade, flagpole, a wash-down point for boats and vehicles.

### 2.6 Beaches

| Beach | Features | Scope |
|---|---|---|
| **Haven Sands** | Dry and wet sand bands, marram dunes with a boardwalk, rock pools under Haven Head (anemones, crabs, blennies, a starfish), the lifeguard tower with flags, the car park with a café and toilets, the vehicle slipway onto the sand, a sandbar ("the Bar") offshore that makes mild rips at its ends | [MVP] |
| **Long Strand** | A 700 m Atlantic surf beach: big dunes, two lifeguard towers, real rip channels between sandbars, the Strand beach lifeboat station (tractor launch, section 3.1), the wreck of an old lifeboat house, flotsam from a cargo spill (section 4.2) | [L] |
| **Gull Cove** | A small sand cove under cliffs at the end of a steep track, a sea cave at mid tide, a tidal pool (the "Mermaid's Pool") | [L] |
| **Puffin Isle seal beach** | A shingle beach where grey seals haul out; boat only, keep your distance (section 4.3) | [L] |
| **Northshore** | A long shingle beach with driftwood and Iceberg North on the horizon | [P1] |

**Tides [P1] (tune).** A server-wide tide on a compressed cycle of about 40 minutes and a range of about 2 m (6 studs), shown on the slipway boards and the HUD clock. It is a single offset added to the shared wave function, so physics stays exact; pontoons and moorings rise with it by script; Terrain does not move. Low water exposes rock pools, the sandbar and wider beaches; high water closes the Gull Cove cave and can cut walkers off below the cliffs, which is how real cliff operations start ([document 09](09-rescue-operations.md), section 8.5). Until [P1] the world sits at a fixed mid tide.

## 3. Land vehicles

### 3.1 The fleet

All land vehicles are station pool vehicles: free, gated by rank (and a certification where noted, [document 03](03-progression.md), section 4), spawned from marked bays, and modelled on real service vehicles with generic details and the Gale Isles Coastguard livery ([document 05](05-art-direction.md), section 4.2). Speeds are owned by [document 02](02-core-loop-and-mechanics.md#43-land-vehicles).

| Vehicle | Real reference | Unlock | Seats | Role in operations | Spawns at | Scope |
|---|---|---|---|---|---|---|
| **Lifeguard 4x4 pickup** | Lifeguard and beach patrol double-cab pickups: light bar, board rack, kit lockers, tow hitch | Recruit, free | 2 front + 3 rear | Gets the crew and beach kit to the tower; answers a Person in the Water off Haven Sands from the beach (drive, then the tower's rescue tube or jet ski); exploring; tows the small jet ski trailer [L] | Station yard, Haven Sands car park | [MVP] |
| **Beach ATV** | Lifeguard quad bikes carrying a rescue board and tube | Lifeguard | 1 (+ a casualty on a towed beach sled) | Rip-current beach rescue: from the tower along the sand to the nearest point to the casualty, drop the board ([document 09](09-rescue-operations.md), section 8.4); beach searches; carries a casualty up the beach to the ambulance. Not road-legal: limited to beaches, tracks and car parks | Lifeguard towers (Haven Sands, Long Strand) | [L] |
| **Coastguard response vehicle + boat trailer** | Coastguard rescue team 4x4s with cliff rope kit, mud rescue kit and floodlights (verify: HM Coastguard rescue team vehicles) | Rescue Swimmer and Helm (the trailer carries your own RIB or jet ski) | 2 + 3 | Shore team at a cliff: park at the rescue point, spot and light the casualty, con the boat or helicopter in by radio ([document 09](09-rescue-operations.md), section 8.5); launch your RIB at any public slipway (Westgate, Haven Sands, North Quay [P1]); mud rescue at the Saltings [P1] | Station yard, cliff-top rescue points | [L] |
| **Ambulance** | Paramedic ambulance in an invented Gale Isles Ambulance livery | NPC [L]; player-drivable on a volunteer shift from the hospital at Rescue Swimmer with Casualty Care [P1] | 2 crew + 1 casualty | The handover: ATMIST to the paramedics at the hospital, the station slipway, Haven Sands and Long Strand car parks, North Quay [P1]. Player-driven [P1]: a graded transport step to the hospital (smooth braking and cornering, blue lights) | Handover points | [MVP] a parked NPC ambulance as a handover point at Haven Sands (tune: cut if the MVP slips); [L] drives; [P1] player |
| **Lifeboat launch tractor** | RNLI beach launch: a tracked tractor pushing a carriage into the surf, as in the Shannon launch and recovery system (verify: RNLI SLARS) | Coxswain (the lifeboat) | 1 driver (the Head Launcher); NPC if solo | The launch at Long Strand is a graded step: push the carriage to wading depth between wave sets (a timing read), tip the cradle, the lifeboat slides off with engines running. Recovery: drive the lifeboat bow-first onto the carriage between sets, winch in, turn it to face the sea (verify: turntable) | Strand beach station | [L] |

### 3.2 Parking and spawn points

| Point | Vehicles | Notes |
|---|---|---|
| Station yard | All except the ATV and tractor | Each player has a marked bay; vehicle spawns face the gate |
| Haven Sands car park | 4x4; ATV at the tower [L] | Ambulance handover point; beach slipway for trailers |
| Long Strand car park and towers | 4x4, ATV | [L]; emergency phone; ambulance point |
| Strand beach station | Launch tractor, lifeboat on its carriage | [L] |
| Westgate public slipway | Trailer launch and recovery | [L]; the west coast boat launch |
| Kittiwake and Tempest Point rescue points | Response vehicle | [L]; floodlight mounts, cliff rope anchor points |
| North Quay | 4x4, response vehicle, trailer slipway | [P1]; the Iceberg North launch point |

**Rules (tune):** one land vehicle and one water vehicle per player at a time; an empty land vehicle despawns 120 s after its driver is more than 300 studs away; spawning picks the nearest open point to the player that holds the vehicle; nothing spawns in sight of another player (the bay doors and car-park pull-ins hide the pop).

**Trailer launch (real sequence, a short graded step):** reverse down the slip with the reversing guide (Assist) or mirrors only (Pro), stop when the boat floats, set the handbrake, release the winch strap and hold the bow line, drive the trailer out. Recovery runs it backwards with the winch. A lifeboat station does exactly this with its inshore boats (verify: RNLI D-class launch).

### 3.3 Car feel: notes for implementers

- **In-house raycast chassis, no free models.** One rigid body per vehicle with real mass (a pickup about 2,200 kg, tune) and four raycast wheels, each a spring-damper with rest length, stiffness, damping (ratio about 0.3 to 0.5, tune) and an anti-roll bar. Tyre forces come from a simple slip curve with grip per surface (section 2.2, read from the raycast result's material; check what it returns for Terrain with MaterialVariants, verify). Visual wheels are separate meshes placed each frame. The client that drives owns the physics; the server checks speed against [document 02](02-core-loop-and-mechanics.md)'s table ([document 06](06-tools-and-pipeline.md), section 3.2). A constraint-based chassis (hinge wheels on springs) is the fallback if raycasting misbehaves on Terrain. Community kits such as A-Chassis are not used: their licence is unchecked and free models can hide backdoors ([`research/tools-and-assets.md`](research/tools-and-assets.md), sections 3 and 5).
- **Tune at our gravity.** With `workspace.Gravity` at about 29.4 studs/s² ([document 02](02-core-loop-and-mechanics.md#42-gravity-and-scale)), springs, damping and weight transfer must be set for real-world motion: body roll in corners, nose dive under braking, squat on launch, a pickup that feels two tonnes, an ATV that feels light.
- **Drivetrain:** a torque curve, a six-speed automatic, four-wheel drive with low range for sand and slipways, engine braking downhill, brake assist and traction control that the Pro setting can switch off.
- **Phone first:** steering slider, throttle and brake pedals, auto-throttle on a full push like the boats, a chase camera with lag (default) and an optional cab view ([document 02](02-core-loop-and-mechanics.md), section 11).
- **Sound and life:** RPM-based engine loops, tyre roar by surface, gravel spatter, indicator ticks, wipers in rain, the siren and blue lights only on a tasking.
- **Trailer:** a second raycast body on a ball joint at the hitch, so reversing is real (and hard), with the reversing guide in Assist.
- **Nothing breaks** ([document 02](02-core-loop-and-mechanics.md), section 4.1): bumps, scrapes and a stuck-in-sand step, never damage.

## 4. Sea and seabed

### 4.1 Depth zones and bathymetry

Real North Atlantic coastal shapes, modelled in Terrain (section 6.1). Depths are below mean sea level (1 m = 3 studs; tune).

| Area | Depth | Seabed |
|---|---|---|
| Inner harbour | 4 to 5 m (Y -12 to -15) | Dredged mud, mooring chains, the odd lost bicycle and lobster pot |
| Calm Bay | 0 to 10 m (to Y -30) | Shelving sand off Haven Sands (about 1:30), the Bar sandbar at 1 m, a marked channel at 8 m to the mouth, rock and kelp under Haven Head, eelgrass meadows on the sand (real: seagrass beds in sheltered bays) |
| Harbour approaches | 12 to 20 m | Sand waves and gravel, scattered boulders |
| The Skerries | Ledges 0.5 to 2 m under the surface, gullies 5 to 15 m, sand patches to 18 m | Granite reef (cold-water rocky reef, as [document 05](05-art-direction.md), section 3.4 assumes: no coral), kelp forests from 2 to 15 m, rocky gullies, tide-race channels between the isles, sea caves on Skerry Isle |
| West coast (Long Strand) | 0 to 10 m out to about 600 studs | Flat sand with parallel sandbars and rip channels between them |
| Open Sea | 30 to 60 m | Sand and gravel plain; the **Shelf Edge** south-east of Gannet Rock drops past 80 m into darkness |
| Storm Front | 20 to 50 m, pinnacles to 5 m | Rock pinnacles and the wreck-strewn "Graveyard" under Tempest Point |
| Iceberg North [P1] | 40 to 100 m | Dark cold water, boulders dropped by ice |

The seabed is modelled in full detail only to about 40 m (120 studs), the deepest a player can see or dive. Deeper water has a simple dark floor that underwater fog hides (section 6.5).

### 4.2 What is on the seabed

**Wrecks of different eras** (no weapons on any wreck, per [document 01](01-game-canon.md), section 7; each has a logbook page with its story):

| Wreck | Era | Where, depth | What you see | Scope |
|---|---|---|---|---|
| *Morwenna*, a wooden trading schooner | 1902 | Calm Bay off Haven Sands, 7 m | Oak ribs in the sand, windlass, anchor chain, the ship's bell | [MVP] |
| *Charity*, a merchant brig | 1771 | The Skerries, 12 m | A ballast-stone mound, a bronze bell, scattered copper sheathing, kelp over everything | [L] |
| SS *Gannet Star*, an iron steamship | 1891 | Gannet Rock reef, 18 m | Boilers, the propeller and shaft, a broken bow; the reason Gannet Rock got its light | [L] |
| A mail seaplane | 1960s | The Skerries sand, 14 m | Intact fuselage and float, wrasse living in the cockpit | [L] |
| *Northern Lass*, a side trawler | 1970s | Off Puffin Isle, 22 m | Upright hull, gallows, nets (a snag hazard for divers [P1]) | [L] |
| Containers from a cargo spill | 2010s | Open Sea, 30 m; toy bricks washing up on Long Strand (real reference: the 1997 *Tokio Express* spill off Cornwall) | Split containers, a beach-clean activity on the strand | [L] |
| *Sterling Silver*, Vance's old yacht | 2010s | Storm Front Graveyard, 25 m | A modern hull on a pinnacle; Vance does not like to talk about it | [L] |

**Other things on the seabed:** an Admiralty-pattern anchor beside the harbour wall at 5 m [MVP], lost lobster pots and creels, old mooring blocks, a lost outboard motor (Barnaby's), a bottle field off the old quay, a Victorian lifeboat slipway's sunken rails at Long Strand.

### 4.3 Marine life

Harmless, realistic, and never a threat ([document 01](01-game-canon.md), section 7). Wildlife is client-side ambience with server-checked sightings (section 6.7).

| Animal | Where | Behaviour | Scope |
|---|---|---|---|
| **Grey seals** | Haven Head (a resident seal, "Old Ned") [MVP]; haul-outs on Skerry Isle and Puffin Isle [L] | Curious in the water, follow divers; on land, a seal that sees you coming too close stampedes into the water | [MVP] one seal; [L] colonies |
| Fish shoals | Everywhere: mackerel and sand eels mid-water, pollack over reefs, wrasse in kelp | Shoals part around a swimmer and boats | [MVP] Calm Bay; [L] all |
| Crabs, lobsters, starfish, anemones, cuttlefish | Rock pools, kelp, reefs | Small animated life on the seabed | [MVP] rock pools; [L] reefs |
| **Dolphins** (common and bottlenose) and harbour porpoises | Open Sea, sometimes the harbour approaches | Bow-ride boats at speed, leap in groups | [L] |
| **Jellyfish** (moon, compass, barrel) | Drifting in summer swarms | Gentle pulses; never sting in the game | [L] |
| **Basking sharks** | Off Long Strand and the Skerries, slowly feeding at the surface | Huge, slow, mouth open; plankton feeders, entirely harmless (real) | [L] |
| Gannets, puffins, kittiwakes | Gannet Rock, Puffin Isle, Kittiwake Cliffs | Gannets plunge-dive into shoals; puffins on the cliff tops | [L] |
| Minke whale | Open Sea, rare | A blow and a back on the horizon | [P1] |

**Wildlife code (real, and taught):** watch seals from a distance and never block their way to the sea; keep 100 m from basking sharks and dolphins and go slow (verify: WiSe and UK basking shark codes of conduct). A sighting only counts for the logbook from a respectful distance; disturbing an animal logs nothing and gets a gentle line from the Coastguard. This is a realism mechanic, not a penalty.

### 4.4 Visibility

North Atlantic water is green and limited, not tropical blue. Underwater horizontal visibility (tune):

| Conditions | Calm Bay | The Skerries | Open Sea | Storm Front |
|---|---|---|---|---|
| Calm, sunny | 15 m (45 studs) | 20 m (60 studs) over white sand | 25 m (75 studs) | 15 m (45 studs) |
| Overcast | 10 m | 15 m | 20 m | 10 m |
| Rain, or the hour after a storm (stirred sediment) | 5 m | 8 m | 15 m | 5 m |
| Storm | 3 m (the bay stays sheltered) | 3 m | 8 m | 2 m |

Light fades and turns green-blue with depth; reds are gone by about 5 m and the world is mostly blue-green below 15 m (real). **From a boat**, the seabed reads through the water down to about 6 m (18 studs) in calm sun and about 3 m overcast, and not at all in a storm (tune).

### 4.5 How the player sees it

| Way | How it works | Scope |
|---|---|---|
| **From boats** | Clear shallows over sand and kelp (section 6.4); an echo sounder depth readout on the RIB and up, which also warns of the Bar and the Skerries ledges | [MVP] |
| **Snorkelling and swimming** | Any player in the water wears a mask and snorkel by default: float face-down to look below, or breath-hold duck dive to about 5 m for about 25 s (tune). Fins gear swims faster. The same underwater view serves the air-pocket dive ([document 09](09-rescue-operations.md#7-operation-3-capsized-ferry-mvp-co-op-big-call-storms-only)) | [MVP] |
| **Freediving** | Breath-hold to about 10 m for about 40 s (tune), enough for the Calm Bay and Skerries wrecks | [L] |
| **Rescue Diver certification** | Scuba from the lifeboat or the dive shop to about 30 m, with real procedure: buddy check, a buddy line or NPC buddy, slow ascent, a short safety stop. It adds the **Rescue Diver** role: air-pocket dives, clearing a fouled propeller, checking a hull before a tow, freeing an entangled seal, recovering lost gear. Never a search for a person underwater ([document 09](09-rescue-operations.md), section 11) | [P1] |
| **Side-scan sonar** | On the lifeboat and patrol cutter: reveals wrecks and features as sonar contacts on the chart, which become logbook entries | [P1] |
| **ROV** | A tethered camera robot from the lifeboat or cutter, to 80 m: the Shelf Edge and the deep wrecks | [P2] |

## 5. Free exploration

### 5.1 On watch and off duty

After the tutorial chain ([document 02](02-core-loop-and-mechanics.md), section 2) there is **no forced tasking queue**. The radio panel has one switch:

- **On watch** (the default): Gale Isles Coastguard offers taskings by radio. Each offer shows the operation, the area and an ETA from where the player is. **"Copy, launching"** accepts; **"Unable"** declines at no cost, and the offer passes to someone else ([document 09](09-rescue-operations.md), section 3.3). Offers favour where the player is and what they can reach: a player on foot at Long Strand gets beach taskings there, a player in a RIB at the Skerries gets a nearby sea tasking, as the real Coastguard tasks the nearest suitable unit.
- **Off duty:** no standard taskings. The storm SECURITE and a big call's MAYDAY RELAY still arrive as an invitation the player can decline, so nobody misses the storm by accident.

Accepting a tasking far from a vehicle offers the nearest spawn point (section 3.2), Return to Station (section 1.3) or, from Slipway level 3, the outposts ([document 03](03-progression.md), section 6). The idle rule in [document 02](02-core-loop-and-mechanics.md), section 10, applies only On watch; an off-duty player who is moving is exploring, not idle.

### 5.2 Discoverables and the logbook

The **logbook** (a tab on the radio panel) collects everything a player finds. A discovery is logged when the player reaches it (or photographs it, for wildlife and far views); the server checks the distance.

| Type | Examples | Count at [L] (tune) |
|---|---|---|
| Named points of interest | Gale Beacon, the standing stones, the Saltings bird hide, the Victorian lifeboat house ruin, the Long Storm memorial on the quay | 20 |
| Wrecks | The seven in section 4.2, each with a story page and a "find the bell" detail | 7 |
| Lighthouse histories | Each light's history and Tobias's keeper's log, unlocked by visiting the light (and completed by relighting it) | 4, then 5 |
| Wildlife sightings | Every species in section 4.3, photographed or spotted with binoculars from a respectful distance | 14 |
| Hidden coves and caves | Wreckers' Cove, the Gull Cove cave, the Mermaid's Pool, a cave on Skerry Isle | 6 |
| Viewpoints | Haven Head, Gale Beacon, Kittiwake Cliffs, Tempest Point, Puffin Isle summit | 8 |
| Rock pools and seabed finds | The Admiralty anchor, Barnaby's outboard, a message in a bottle | 10 |

**MVP:** the *Morwenna*, the Admiralty anchor and Old Ned's kelp gully (three seabed points of interest), plus Haven Head viewpoint, the Haven Sands rock pools and the Harbor Light history.

### 5.3 Exploration rewards

Exploration pays **no Reputation**: rank stays a measure of rescue work ([document 03](03-progression.md), section 1). It pays small one-time **Cash**, **cosmetics** for completing logbook pages (a wreck-hunter mask, a seal plush for the bay, a lighthouse model for the trophy wall), the logbook itself, and **badges**. Amounts and the badge list are in [document 03](03-progression.md), sections 8 and 8.1.

### 5.4 Photo mode [L]

From the radio panel when no operation step is active: the UI hides, the camera frees within about 40 studs of the player or their vehicle (tune), with focal length (18 to 200 mm equivalent), focus and depth of field, exposure and roll. Photos save through the platform's screenshot capture (verify: CaptureService behaviour on each device). Framing an animal or a far view in photo mode logs the sighting.

## 6. Tech for scale

### 6.1 Terrain for land and seabed

- **Terrain everywhere for natural ground:** land, beaches, dunes, cliff tops and the whole seabed down to about 40 m. Man-made things (quays, the harbour wall, the slipways, buildings, roads) are meshes and parts. Vertical cliffs and big rocks are scan-based meshes over the Terrain ([document 05](05-art-direction.md), section 4.3), because smooth Terrain rounds sharp rock.
- **No Terrain water** anywhere ([document 06](06-tools-and-pipeline.md#31-the-ocean)): the mesh ocean covers the sea; Terrain below Y = 0 is dry seabed under it.
- **MaterialVariants.** Terrain takes one override per base material for the whole place through `MaterialService` (verify the override mechanism and that there is no per-region choice). The plan assigns each look a base-material slot (verify which slots allow variants):

| Base slot | Look |
|---|---|
| Sand | Dry beach sand |
| Sandstone | Wet sand (swash band and below the tide line) |
| Salt | Rippled seabed sand |
| Limestone | Shell and maerl gravel on the seabed |
| CrackedLava | Shingle (Pebble is not a Terrain material; the unused CrackedLava slot carries it) |
| Rock | Granite (cliff tops, reefs) |
| Slate | Kelp-covered rock (seabed) |
| Basalt | Dark wet rock in the splash zone |
| Grass | Machair and cliff-top turf |
| LeafyGrass | Heather and gorse moor |
| Mud | Estuary and track mud |
| Ground | Bare earth and paths |
| Asphalt, Cobblestone, Concrete | Under the road and quay meshes, matching them |

  Wet twins for rain are a runtime swap of the override (verify that changing a Terrain override at runtime is supported and cheap); if not, rain wetness on Terrain is limited to the beaches' permanent wet bands and particles.
- **Memory.** Fill Terrain as a shell (about 40 studs thick under land, 20 under the seabed), never solid to a deep floor; leave the deep sea floor empty (section 6.5). Measure Terrain memory per km² in the first spike (verify).

### 6.2 StreamingEnabled and spawning

Starting values (all tune, all property names verify):

**Cold-open spawn.** A first-time player does not spawn at the station: the server streams the area around the Sandy Point datum (`Player:RequestStreamAroundAsync`, verify) behind a short spray fade, seats them on a jet ski already moving, and only then shows the first frame ([document 09](09-rescue-operations.md), section 9.1). The arrival cinematic's path into the harbour is streamed during the rescue. Returning players spawn at the station by the Chandlery.

| Setting | Value | Why |
|---|---|---|
| `StreamingEnabled` | On | The map is far bigger than a phone can hold ([document 06](06-tools-and-pipeline.md), section 5) |
| `StreamingMinRadius` | 384 studs | Enough to drive at 75 studs/s for 5 s |
| `StreamingTargetRadius` | 1,536 desktop; the engine reduces it on low-memory devices | Helicopter at altitude sees far; far islands use proxies (section 6.3) |
| `StreamingIntegrityMode` | Pause outside the loaded area | No driving off unloaded road |
| Vehicles, casualty groups, NPC boats | `ModelStreamingMode` Atomic | A vehicle never streams in half-built |
| Lighthouses, island proxies, the station | Persistent | The horizon and the lights never pop |
| The ocean | Client-built, not streamed | It follows the camera ([document 06](06-tools-and-pipeline.md#31-the-ocean)) |

**Spawn and vehicle streaming:** before a player spawns, takes a vehicle or Returns to Station, the server calls `RequestStreamAroundAsync` for the destination (verify) and the client waits behind a short fade. Operation scenes stream around their crew before the casualties spawn. Discoveries and the logbook are checked on the server by distance, never by what a client has streamed.

### 6.3 LOD for far islands

- Each island and headland gets a **Persistent low-poly proxy** (about 1,000 to 3,000 triangles, tune) baked in Blender from the same heightmap, with a baked colour map, sunk about 1 stud so the real Terrain covers it when it streams in. Cliff faces and lighthouses get their own low LODs.
- Buildings use the streaming low-detail mode for models out of range (verify the `LevelOfDetail` streaming mesh option, [document 06](06-tools-and-pipeline.md), section 2.2).
- Lighthouse beams are Persistent and fade by distance, so every relit light sweeps the horizon from anywhere ([document 01](01-game-canon.md), pillar 6).

### 6.4 Where the mesh ocean meets the shore

- **A shore bake.** The Terrain generator also writes a depth and distance-to-shore grid (8-stud cells, tune) as a shared module. `Waves.luau` uses it to damp amplitude in shallows and behind the wall (replacing the per-zone mask in [document 06](06-tools-and-pipeline.md#31-the-ocean)); the renderer uses it for depth colour and foam.
- **The waterline.** The ocean mesh runs under the beach Terrain, so the sand hides it above the water. A swash-foam strip mesh follows each beach contour and slides up and down with the local wave height; the wet-sand variant is painted from 0 to about +1.5 studs.
- **Depth fade.** Depth colour by vertex colour if `EditableMesh` allows, otherwise the partly transparent shallows tiles over a pre-tinted seabed ([document 05](05-art-direction.md#71-the-deep-water-look)), placed from the bake where depth is under 6 m.
- **Breaking water.** The bake marks reef and rock edges; the generator places breaking-wave and wash emitters there, scaled by the storm.

### 6.5 Underwater rendering

When the camera dips below `heightAt` at its position, the client switches to an underwater preset: a depth- and weather-driven colour correction and fog (Atmosphere density and colour, verify how far Atmosphere can be pushed), a slight blur, marine snow and bubble particles, light shafts as soft beam meshes near the surface, and baked caustic flipbooks on transparent planes just above the sand in water shallower than 10 m (Terrain cannot take decals). The surface seen from below needs a downward-facing copy of the near ocean grid or a double-sided mesh (verify). Sound goes through a muffled underwater sound group. Below 40 m the fog closes to dark blue over the simple deep floor.

### 6.6 Building the world

1. **Author** the heightmap and material splat map (Blender, or a terrain tool with an exportable heightmap), at 4 studs per pixel to match the Terrain voxel size (verify voxel size), over the whole playable area.
2. **Export** with a Python script into small tiles (128 x 128, tune) as encoded buffers in generated ModuleScripts under `map/terrain/tiles/` (verify the ModuleScript source size limit).
3. **Generate in Studio.** A new Studio-only script, `map/terrain/GenerateTerrain.luau`, synced by a separate Rojo project into a working place and run through the Studio MCP or the command bar ([`research/tools-and-assets.md`](research/tools-and-assets.md), section 1), writes the Terrain tile by tile with `WriteVoxels`, writes the shore bake, and places foam strips and breaking-water emitters. Studio's built-in heightmap import is fine for a first look but is not repeatable.
4. **Save** the Terrain into a committed terrain place file, and have the shared map build (`~/RobloxProjects/tools/build-map.luau`, which runs `map/Build.luau`) copy its Terrain into the built place (verify that Lune preserves the Terrain voxel data when copying).
5. **Hand-place detail** on top: scan cliffs and rocks, buildings, roads as spline-generated mesh ribbons with markings over flattened Terrain, vegetation, road furniture, wrecks and discoverables.

**What changes in `map/Build.luau`.** It runs under Lune, which cannot edit Terrain (its header says so), so it stays the builder for parts and markers only:

- **Removed once Terrain lands:** the `OceanFloor` sand tiles at Y = -40, the part-built land and hill under the town, and the sloped `Beach` part (all become Terrain).
- **Kept and moved:** the quay, station, dock and launch bays, hospital and houses (greybox until their meshes land), the drop-off pads, and the `Breakwater` and `HarbourLight`, re-laid so the harbour mouth sits about 900 studs from the station ([document 02](02-core-loop-and-mechanics.md#41-map-scale-and-travel-budget)).
- **Added:** tagged markers for vehicle spawn points, handover points, lifeguard towers, road nodes, discoveries and wrecks; zone polygons instead of circles; `GameConfig.MapRadius` from 2,000 to 2,500 for the MVP and 7,500 at [L] (tune).

### 6.7 Budgets

Mobile numbers are engineering judgment, not sourced; measure on a real low-end phone ([document 06](06-tools-and-pipeline.md#35-mobile-performance-plan)).

- **Client (Low tier):** streaming target radius about 1,024 studs; at most about 20,000 streamed instances (tune); scene triangles per [document 05](05-art-direction.md), section 5.6; wildlife capped at about 40 animated creatures near the camera and shoals as instanced flipbook sprites; one underwater preset at a time.
- **Server:** physics only for player-driven vehicles (client-owned); NPC traffic, NPC boats and big-call craft move on scripted splines at about 10 Hz and are smoothed on clients; wildlife is purely client-side, seeded from server time so players see roughly the same animals; discovery checks at about 2 Hz. Check the server memory cap for a 16-player server with this Terrain (verify).

## 7. Scope

| Tag | World contents |
|---|---|
| **[MVP]** | The main island's south coast around Port Haven: the town, the station compound and slipway, the fuel dock, the hospital; Harbour Road and the Coast Road to **Haven Sands** (beach, tower, car park, dunes, rock pools); **Calm Bay** and the storm-exposed **harbour mouth**; Haven Head; a Terrain seabed with three points of interest (the *Morwenna*, the Admiralty anchor, Old Ned's kelp gully); the **lifeguard 4x4**; a parked NPC ambulance handover point; snorkelling and duck dives; the echo sounder; On watch and Off duty; a basic logbook. Map radius about 2,500 studs. |
| **[L]** | The full main island: the whole Coast Road, the West Arm to Tempest Point, the High Road to Gale Beacon, Long Strand and the Strand beach station, Gull Cove, Kittiwake Cliffs, the Saltings, Westgate; **The Skerries** with Skerry Isle; two outer islands, **Puffin Isle** and **Gannet Rock**; Open Sea and Storm Front; **all land vehicles** (4x4, ATV, response vehicle and trailer, NPC ambulance, launch tractor); light NPC traffic; all launch wrecks and wildlife; freediving; the full logbook, exploration rewards and badges; photo mode. Map radius 7,500 studs. |
| **[P1]** | Tides; North Quay, the Northshore road and **Iceberg North** with Northlight Island; the Rescue Diver certification and scuba; side-scan sonar; the player-drivable ambulance; mud rescue at the Saltings; the minke whale. Map radius 9,000 studs. |
| **[P2]** | The ROV; a second island town ([document 01](01-game-canon.md), section 9); seasonal changes to the world (winter storms, summer basking sharks). |
