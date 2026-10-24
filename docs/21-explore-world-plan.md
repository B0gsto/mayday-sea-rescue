# 21 · Explore world plan: the Gale Isles archipelago

Owner, 2026-10-24: "we do not have enough space on water, we need islands and stuff so that the player can explore and stuff on land and also on water. I want a full explore game."

This plan grows the ±2,560-stud bake into an archipelago and brings exploration back as a pillar. It reverses docs/16 C14 (the text logbook cut) **without** bringing back a text logbook or the On watch / Off duty switch: discovery is stamps, stickers and a fogged map, all icons. Rules that still hold: CLAUDE.md (no choice UI, show don't tell, every action on keyboard, touch and gamepad), [simple rescue](09-rescue-operations.md) (drive close, they climb aboard, bring them home), all UI on the phone, third-person camera. Numbers marked (tune) are first guesses; (verify) means check in Studio before code depends on it.

## 1. Vision

1. **Rescue and explore are twin pillars.** Calls happen all over the archipelago, so answering one takes you somewhere new, and exploring always keeps you near the next call.
2. **Every island is a postcard.** One silhouette you can name from the horizon (a lighthouse, a castle, a rusty wreck, a giant arch), one thing to climb, one secret.
3. **The map fills in as you sail.** Fog lifts, stamps land and stickers fill the phone album. Progress is visible, never written.
4. **Further is better.** The far islands are 1:20 away on a stock jet ski and about 1:00 on a fast boat, so a faster boat and a second home port feel like real rewards.
5. **Why players keep sailing:** an unfinished sticker page, a bottle with a picture of a place they haven't found, dolphins on the way, and a lighthouse blinking at night where they've never been.

## 2. World layout

### 2.1 Size and shape

| Item | Now | Plan |
|---|---|---|
| Playable sea | ±2,560 square, `MapRadius` 2,500 | `MapRadius` **7,000** (tune). The map canvas is ±7,168 (14,336 studs, about 4.8 km across), well inside the ±10,000 physics-precision rule (docs/10 §1.2). |
| Terrain | One 1,281² bake (4-stud cells). Great Gale is closed by the window shore. | **Main window unchanged** (byte-identical heights) plus **one small bake window per new island** (§6.1). Deep sea between windows has no voxels. |
| Great Gale | The current closed island, about x ±2,400 and z -2,400 to +900 | Keep it. Baking the full doc 10 polygon (to x -5,600) would eat the new sea. The doc 10 west and north places (Long Strand, Tempest Point, Saltings, North Quay) are retired or moved to the islands below. |
| Edge | Vehicle reset past `MapRadius + 200` | The same rule at 7,000: swell builds, then a gentle turn-back. No text; a Coastguard voice line is fine. |

### 2.2 Islands

Times are from the harbour mouth (0, 400) at full throttle along a straight sea line plus 5 %: jet ski 69, RIB 54, lifeboat 45 and Riptide X 96 studs/s (VehicleConfig).

| # | Place (centre x, z) | Identity and biome | Landmark silhouette (seen from afar) | Size | Jet ski / RIB / lifeboat / Riptide X | On land | On water |
|---|---|---|---|---|---|---|---|
| 0 | **Skerry Isle** (1,800, 1,750), existing | Granite reef isle, kelp, seals | Skerry Light (existing) | 400 x 250 m | 0:34 / 0:43 / 0:52 / 0:24 | Climb to the light gallery; seal haul-out | Kelp maze, the seaplane wreck, seal pups |
| 1 | **St Elowen's Mount** (-200, -3,000) | Tidal castle island off Great Gale's north coast (St Michael's Mount style) | Castle on a cone of rock | 250 m across | Car **0:45** (High Road, north cove, causeway); boat about 2:00 round the west | Causeway walk, a castle-tower lookout, a garden terrace | Causeway floods at high tide: cross it by jet ski (§5) |
| 2 | **Puffin Isle** (-2,600, 3,400), doc 10 name | Green whaleback, sea-pink turf, abandoned hamlet | Twin humps, white bird cliffs, a roofless chapel | 600 x 350 m | 1:00 / 1:17 / 1:33 / 0:43 | Cliff path to the puffin lookout; hamlet ruins; ATV track | Seal beach, puffins rafting on the sea, a stack with a hole |
| 3 | **Penwyn** (-4,800, -300) | Fishing village island: **second harbour and home port** | Harbour wall, a white windmill on the hill, coloured cottages | 900 x 600 m | 1:13 / 1:34 / 1:53 / 0:53 | Village grid (a `TOWNS` entry), café, ice-cream hut, 4x4 and ATV lanes, hilltop windmill | Second set of launch bays, a drop-off dock, fishing boats, a lobster-pot field |
| 4 | **Wreck Reef** (-3,800, 4,200) | Storm-exposed reef: the old Graveyard. Rocks and a beached freighter. | A rusty cargo ship on the reef, bow high | 500 m reef | 1:21 / 1:44 / 2:06 / 0:58 | Walk the tilted deck, inside the hold, the crow's nest viewpoint | Big swell, spilled containers, the *Sterling Silver* yacht, breakers |
| 5 | **The Arches** (5,300, -200) | Sea stacks, arches and smugglers' caves east of Great Gale | A giant natural arch ("the Door") and needle stacks | 700 m cluster | 1:20 / 1:43 / 2:05 / 0:58 | Smugglers' cove beach inside a cave; cliff-top stack path | **Drive through the arch and the cave tunnel** (jet ski and RIB fit, the lifeboat does not) |
| 6 | **Gannet Rock** (3,500, 3,500), doc 10 name | Bare white-streaked stack, gannet colony | Tall red-and-white lighthouse | 80 m rock + a landing ledge | 1:10 / 1:30 / 1:49 / 0:51 | **Climb the lighthouse** (spiral stair, lantern-room view) | Gannets plunge-diving, the *Gannet Star* wreck below |
| 7 | **Mermaid Lagoon** (300, 5,600) | Scilly-style white-sand isles round a turquoise lagoon, palms and agapanthus | Palm-topped sandy isles, a striped beach-café roof, a day-mark tower | 1,000 m ring | 1:18 / 1:41 / 2:02 / 0:57 | Beach café, sandbar walks, dunes for the ATV, a hidden rock pool | Calm lagoon (shelter 0.8), turtles, snorkelling over sand |

### 2.3 Open sea between the islands (something every ~20 s)

| Feature | Where | What it is |
|---|---|---|
| Seamark buoys | Along each route (Port Haven to Penwyn, Lagoon, Gannet, Arches) | Lit cardinal and lateral buoys (existing `Seamarks`) that line the way like breadcrumbs, with bells and gulls on top |
| Sea stacks and rocks | Between Puffin and Wreck Reef, off the Arches | Small rock islets (terrain inside the windows, Part rocks outside) |
| Floating cargo | Drifting on a slow loop west of the Lagoon | Crates and a container from the Wreck Reef spill; bump one and a bottle pops out |
| Kelp mats and a whirl | Off Puffin Isle | Slow water and swirling foam; nothing hurts you |
| Dolphins | Every route | A pod bow-rides any boat above half speed for about 20 s |
| Whale and basking shark | Deep water south of the Lagoon / east of Gannet | Rare: a blow on the horizon, a fin you can follow at walking pace |
| Lighthouse beams | Skerry, Gannet, the Lagoon day-mark, Penwyn harbour | Persistent lights at night: the night-time "go there" |

## 3. Exploration loop without text

| Piece | How it works (no sentences) |
|---|---|
| **Fogged map** | The phone map and minimap start under a soft sea-mist overlay, cleared in 256-stud cells within 400 studs of the player (tune) and saved per player. Island **outlines always show**, each with a "?" badge, so the goal is visible but the inside is a mystery. |
| **Stamp post** | One per island at the landmark: a coast-path letterbox post with a rubber stamp (Dartmoor letterboxing is real). Touch it (prompt glyph) for a big ink-stamp thump on screen with the island's icon. The map's "?" becomes that stamp. |
| **Stickers** | Each island has **6 slots**: stamp, 2 critters, 1 viewpoint, 1 bottle, 1 secret. 9 pages (Great Gale + Skerry + 7 new) = **54 stickers**. |
| Critters | Get near (outside the wildlife ring: animals flee if you charge), or frame the animal in Photo Mode (exists). Uses `Wildlife` species plus gannet, dolphin, basking shark, whale and crab. |
| Viewpoint | A bench or a brass telescope on the lookout. Sit and the camera sweeps the vista for 4 s (photo moment). |
| Bottle | Washed up or floating. Pick it up and a **drawing** opens: a sketch of a spot on that island with an X. |
| Secret | The X spot. Hold to dig and a chest pops (cosmetic or Cash). Also findable without the bottle: gulls circle it, and **Bosun sniffs and points** when you're within 60 studs. |
| **Phone: Explore app** | A sticker album: one page per island (island name, 1-3 words), grey silhouettes that fill with colour stickers, and a "4/6" counter. Completed pages get a gold border. |

**Rewards (amounts tune, docs/03 owns numbers).** Exploration pays no Reputation (rank stays rescue). Small one-time Cash per sticker. A **completed page** gives that island's boat paint (Lagoon teal, Wreck rust, Puffin pink) plus one avatar item or a pet-habitat piece for the sanctuary (puffin perch, seal rock, turtle pool). **All 9 stamps** give a badge and an Explorer pennant on every boat.

**What pulls players further (simple for a 10-year-old):**
1. Distance is the gate: no level locks and **no fuel** (a fuel gauge is a chore). A faster boat (Robux boats, VehicleUpgrades) turns 1:20 into 0:58.
2. The right craft wins: the Arches tunnel fits a jet ski or RIB, Wreck Reef's swell is calmer in the lifeboat, and the Lagoon dunes want the ATV.
3. **Penwyn becomes a second home port once stamped**: boats launch from its bays and "Back to Station" picks the **nearest stamped port automatically** (no choice UI).
4. Night lights and far silhouettes advertise unvisited islands. A "?" on the map is an itch.

## 4. How rescue integrates

Calls spread across the islands using the **same simple ops** (drive close, they board, bring them home). Island calls are new `SpawnZones` rows in `CallTypes`. Offers lean toward the player's current area (docs/10 §5.1). A delivered survivor completes at **any** `DropOff = "Dock"` pad, and Penwyn, Skerry and the Lagoon get one, so far rescues don't mean a 90 s ride home.

| Island | Call (existing kind) | Scene |
|---|---|---|
| Mount | RipCurrent / Swimmer | Walkers cut off on the flooding causeway (high tide) |
| Puffin Isle | Cliff, WildlifeRescue | Climber on the bird cliffs; a puffin tangled in line |
| Penwyn | DriftingCraft, VesselFire | Kayaker blown out of the harbour; a fishing boat fire on the moorings |
| Wreck Reef | Sinking (storm-weighted) | A yacht holed on the reef, 3-6 aboard: capacity routing |
| The Arches | Swimmer | A swimmer stuck in the sea cave: jet ski in through the tunnel |
| Gannet Rock | VesselFire, WildlifeRescue | A trawler fire off the rock; an oiled gannet |
| Mermaid Lagoon | RipCurrent, WildlifeRescue | Rip at the sandbar gap; a turtle in a net |
| Open sea | Swimmer, DriftingCraft | Off the floating cargo; a capsized dinghy on a route |

Rules: the tutorial chain and the first call stay in Calm Bay. Timers scale with the distance from the offered player (`timerMultiplier`). The storm favours Wreck Reef and the Arches. A failed call still sends the NPC boat (simple-rescue fail rule).

## 5. Land exploration

| Element | Plan |
|---|---|
| Paths | Ground-surface `ROADS` per island (landing to landmark to secret), 8-10 studs wide, with the same waymark posts as the coast path. A path always loops back to the landing. |
| Lookouts | Gannet light stair, the Mount castle tower, the Wreck crow's nest, the Penwyn windmill gallery, the Lagoon day-mark: each is the viewpoint sticker. |
| Caves | Smugglers' cave (Arches), the Gull Cove cave, the Puffin chapel crypt. Carved in Terrain with the existing `write_terrain` arch mode (FillBall air), generalised to a `CAVES` list. |
| Tidal causeway | The Mount causeway is a strip of Parts the server raises and lowers on a 10 min cycle (tune), with tide posts in coloured bands at each end. Shortcut: the sea level itself doesn't move (a global tide touches `Waves`, buoyancy and swimming; that stays doc 10 [P1]). Dry means walk or drive across; flooded means jet ski over it. |
| NPC hints (no text) | Islanders (existing `NpcService` rigs) **point** toward the nearest unfound secret, hold up a **picture bubble** of the critter nearby, or wave from the café. Bosun sniffs and points at secrets. The town-NPC numbered-reply exception is not needed here. |
| Land vehicles | Beach ATV spawn posts at the Penwyn quay, Puffin landing and Lagoon café (layout `POINTS` kind VehicleSpawn). Lifeguard 4x4 on Penwyn's lanes and the Great Gale High Road extension to the Mount causeway. No car ferries: islands spawn their own ATV. |

## 6. Tech plan

### 6.1 Terrain: per-island bake windows

- `layout.py` gains `WINDOWS = [{id, center, half, islands, ...}]`. **Main** is today's window (±2,560, `GREAT_GALE` + `SKERRY_ISLE`). Each new island gets a 768-1,024 half-extent window with **only its own polygons** (Great Gale's polygon reaches x -5,600 and must not leak into Penwyn's window).
- `gen_terrain.py` runs `bake()` per window, so 7 small grids (about 1.9 M cells in all) sit next to today's 1.64 M. A single ±7,168 grid (12.9 M cells, float64 temporaries over 100 MB each) would strain this 16 GB Mac and waste voxels on deep sea.
- Each window's shelf ramps to the deep floor (-165) at its edge, like T8 does today. Outside the windows there are no voxels; the opaque ocean and underwater fog hide that (`Seabed.luau` already hides over deep sea).
- Windows are disjoint. The Mount causeway crosses the main window's north seam as a `CAUSEWAY` strip baked in both (like `BAR`); `check_zones.py` checks it is continuous.
- `write_terrain.luau` and `studio_terrain.py` write every window (same shell rules). The Terrain.rbxm grows from about 5 MB to about 10-12 MB (verify).

### 6.2 Streaming, LOD, horizon, perf

| Topic | Plan | Budget (tune, measure on a low-end phone) |
|---|---|---|
| Streaming | Keep the docs/10 §6.2 radii. Each island's dressing is one Model per island area (not Atomic), landmarks `Persistent`. `RequestStreamAroundAsync` before Back-to-Port. | ≤ 3,000 streamed instances per island |
| Far LOD | Persistent proxy per island: a decimated heightmap mesh with baked colour, sunk 1 stud (docs/10 §6.3), plus the landmark's low LOD. Without proxies an island pops in at 1,536 studs. | All proxies ≤ 25k tris, ≤ 60 instances |
| Horizon / ocean | The ocean is client-built and follows the camera (`Horizon` to about 4,200 studs), so a bigger sea costs nothing. Tune Atmosphere haze so a landmark reads at 4,000-5,000 studs in Clear weather. Add island lee `GameConfig.Zones` (Lagoon shelter 0.8, Wreck Reef 0). | No new ocean meshes |
| Server | Discovery checks at 2 Hz by distance (never trust the client); fog bitset per player (56x56 cells, about 400 bytes) in the profile; NPC islanders static or on short loops. | ≤ 1 ms/frame added |
| Client | Ambient life uses the existing caps (about 40 animated creatures near the camera; dolphins and the whale are 1 pod or 1 animal at a time). | ≤ 1.5 ms/frame added on Low |

### 6.3 Map and minimap

`make_map_image.py` composites every window onto the ±7,168 canvas (the deep sea is a flat painted blue), at 4,096 px in **4x4 tiles of 1,024 px** (3.5 studs/px). `MapConfig`: `Origin` (-7,168, -7,168), `Extent` 14,336, a 4x4 `Tiles` table, island `Places`, and `FullMap.maxRadius` about 7,000. The fog overlay is drawn by MapController from the player's bitset.

### 6.4 Assets

| Source | Use |
|---|---|
| Code-built placeholders first (CLAUDE.md) | Every island's buildings, castle, windmill, wreck hull and stamp posts in the first pass |
| Existing kits | `SkerryLight` (Gannet light), `CottageRig` / `TownBuildings` / `TownLayout` (Penwyn via a `TOWNS` entry), `Seamarks` (buoys), `MorwennaRibs` (wreck ribs), `StreetFurniture`, `Wildlife` animals |
| Blender (Opus agents, max 2 at once, see memory) | Hero landmarks: the Mount castle, the freighter wreck, arch and stack rocks, island proxies |
| Antigravity (2D) | Sticker art, stamp icons, Explore app icon, map "?" badges, bottle drawings |
| Creator Store | Mesh-only assets from verified creators with a clear licence, scripts stripped; never free-model scripts (docs/10 §3.3) |

## 7. Work packages

Order: **A** first (blocks everything), then **B** in parallel (disjoint files), then **C**. **M1 "first playable archipelago" = A + B1 (quick pass) + B4**: every island stands, has its landmark and stamp post, and shows on the map.

| WP | Owns (files) | Deliverable | Acceptance |
|---|---|---|---|
| **A · Bake and layout** | `tools/world/layout.py`, `gen_terrain.py`, `write_terrain.luau`, `studio_terrain.py`, `check_zones.py`, generated `WorldConfig.luau`, `map/terrain/Terrain.rbxm`, `GameConfig` (`MapRadius` 7,000, island zones), `src/server/World/Islands/init.luau` (a loader that requires every child module) | `WINDOWS`, 7 island polygons, island roads and paths, `CAUSEWAY`, `CAVES`, and all island POIs/POINTS (stamp, bottles, secrets, viewpoints, critter spots, docks, ATV spawns) | Deterministic bake; main-window heights byte-identical; `check_zones.py` passes for every new point; Terrain loads in Studio with no seam holes; rbxm ≤ 12 MB; `check.sh` green |
| **B1 · Island builds** (one builder per island, 2-3 at a time) | `src/server/World/Islands/<Id>.luau` each | Placeholder landmark (`Persistent`), paths dressing, docks, café or ruins, walkable lookout to the viewpoint spot | Silhouette identifiable at 3,000 studs (contact sheet, art-director check); landing to lookout walkable on foot; ≤ 3,000 instances |
| **B2 · Discovery rules and service** | `src/shared/Explore/ExploreCatalog.luau`, `ExploreRules.luau`, `src/server/Services/ExploreService.luau`, `src/server/Explore/StampPost.luau` (posts, bottles, dig spots, viewpoint benches from WorldConfig), `tests/Explore.spec.luau` | Stickers, fog bitset, rewards, nearest-stamped-port rule | Spec tests pass; each sticker granted once; server-side distance checks; profile migration keeps old saves |
| **B3 · Ops spread** | `src/shared/Calls/CallTypes.luau`, `CallLogic.luau`, `src/server/World/DropOffDocks.luau` | §4 zones, proximity-weighted offers, `DropOff = "Dock"` pads at Penwyn, Skerry and the Lagoon | A 30 min headless sim offers every island zone; every spawn point is in water; a far call completes at the nearest dock |
| **B4 · Map** | `tools/world/make_map_image.py`, `src/shared/Config/MapConfig.luau`, `MapController` (fog overlay) | 4x4 tile map, places, fog overlay | 5 world points line up with the map within 10 studs; fog clears while sailing; tiles uploaded |
| **C1 · Explore app and feedback** | `src/client/UI/ExploreApp.luau`, `src/client/Controllers/ExploreController.luau`, one row in `Phone.luau` | Sticker album, stamp thump, sticker fly-to-phone, bottle drawing view | Keyboard, touch and gamepad; no sentence anywhere; labels ≤ 3 words |
| **C2 · Far LOD and look** | `src/server/World/IslandProxies.luau`, `LightingPresets.luau` (haze), proxy meshes | Proxies, landmark LODs, night beams | From the harbour mouth in Clear weather, ≥ 4 islands visible; no pop when Terrain streams in |
| **C3 · Ambient sea life and open-sea features** | `src/shared/Config/SeaFeatures.luau`, `src/client/World/OpenSea.luau` | §2.3 (buoys, cargo drift, dolphins, whale, kelp, gulls over secrets) | Inside the client caps; no route has 20 s of empty sea (a Haiku playtest drives each route) |
| **C4 · Causeway and island NPCs** | `src/server/World/Causeway.luau`, `src/server/Npc/Islanders.luau` | Tide cycle on the causeway; pointing NPCs | Causeway walkable when dry and jet-skiable when flooded; NPCs point at the nearest unfound secret |

Each package runs `~/RobloxProjects/tools/check.sh .`, its spec tests and a `tools/studio/smoke.py` pass, then a Haiku real-client playtest (memory: playtest harness) before publishing to the test place. One Opus sign-off at M1 and one at the end.

## Sources

- [Fisch boat tier list (Gamezebo)](https://www.gamezebo.com/walkthroughs/fisch-boat-tier-list/): boat speed gates islands and timed events.
- [Fisch fish types and where to find them (Deltia's Gaming)](https://deltiasgaming.com/?p=225406): island-specific bestiary; rods, bait and boats open new areas.
- [Sea of Thieves islands (wiki.gg)](https://seaofthieves.wiki.gg/wiki/Islands) and [Points of interest](https://seaofthieves.wiki.gg/wiki/Point_of_Interest): big islands carry the unique landmarks; beacons and smoke read from afar.
- [Blox Fruits islands and level requirements (Gamer Journalist)](https://gamerjournalist.com/all-islands-locations-and-level-requirements-in-roblox-blox-fruits/): sea-gated progression (we gate by distance and craft instead).
- [Big Changes to StreamingEnabled (DevForum)](https://devforum.roblox.com/t/big-changes-to-streamingenabled/351704) and [Problem with large amounts of Terrain (DevForum)](https://devforum.roblox.com/t/problem-with-large-amounts-of-terrain/1909754): stream by zone; very large terrain exhausts memory, so keep voxels sparse.
