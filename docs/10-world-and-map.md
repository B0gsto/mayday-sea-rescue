# 10 · World and map

The current world is one hub forest, six player islands on a ring, six suspension bridges and an outer ring of
exploration islands. The design is [`00-design.md`](00-design.md); this file owns the layout and the map data.
The old Port Haven town, coast road, land vehicles and Great Gale terrain are cut.

## 1. Coordinates and scale

- All positions are studs from the world origin. **+X is east, -Z is north (inland), +Z is south (out to sea).**
- Sea level is `Y = 0`; the hub plateau is `Y = 4`.
- Scale is **1 metre = 3 studs**.
- Play radius is `MapRadius = 7000` studs. The seabed floor is `Y = -165`.
- Terrain uses cell size `4`, seed `1871`.

The numbers below come from `src/shared/Config/WorldConfig.luau` and `RingLayout.luau`. Treat them as the map's
source of truth; update the config first, then this table.

## 2. The world at a glance

| Place | What it is |
|---|---|
| **Hub island** | Forest island at the centre, about 800 studs across. Newcomer spawn, Coastguard lookout HQ, call board, market stall, harbourmaster shack, campfire stage, rescuer monument, visitor jetty, six quest camps, hidden ruin and wreck. Terrain. |
| **6 player islands** | One per player, 60° apart on a ring about 1,100 studs out. Flat green Lego baseplates with a berth notch; no terrain, no scatter. |
| **6 suspension bridges** | Walkable hub-to-island links, 14 studs wide, high enough for every boat and the helicopter. No cars. |
| **Outer ring** | Skerry, Puffin Isle, Gannet Rock, Wreck Reef, The Arches, Mermaid Lagoon, Penwyn. Terrain, wrecks, wildlife and calls. |
| **Open sea and seabed** | Deep water, reefs, wrecks and the submarine layer. |

## 3. Hub

| Property | Value |
|---|---|
| Centre | `(0, 4, 0)` |
| Radius | `400` (about 800 across) |
| Bearing | `90` (harbour faces south, +Z) |
| Plateau | `Y = 4` |
| Harbour notch | half-width `50`, head `290`, floor `Y = -30` |
| Spawn | Landing, facing the lookout hut |
| Drop-off | Harbour, sea level, just off the visitor jetty |

### 3.1 Lots

`RingLayout.Hub.lots` places these on the plateau:

| Lot | What stands there |
|---|---|
| `HQ` | Coastguard lookout hut; radio and call board |
| `CallBoard` | Call board beside the HQ |
| `ShopCounter` | Market stall (shop) |
| `Harbourmaster` | Harbourmaster shack on the west quay |
| `Campfire` | Campfire ring/stage for live-ops |
| `Monument` | Rescuer monument in a clearing |
| `Jetty` | Visitor jetty along the east harbour wall |

### 3.2 Clearings and quests

`RingLayout.Hub.clearings` is generated from the terrain bake. Each clearing has a `kind`:

- `outpost` — a frontier camp with a building or stall.
- `bridge` — the hub end of a suspension bridge.
- `quest` — an empty camp for a quest giver; `RingLayout.Hub.questSpots` gives its CFrame and radius.
- `hidden` — a ruin, wreck or other discovery.

The six quest givers are Old Maud, Tam, Captain Rook, Nell, Keeper Ives and Pip. Their camps are in the
`quest` clearings. The ruin and the overgrown wreck are hidden spots with discovery stickers.

### 3.3 Fog

The hub starts fogged. The fog grid comes from `DiscoveryConfig`:

| Property | Value |
|---|---|
| Origin | `(-7168, 0, -7168)` |
| Cell | `256` |
| Count | `56` |
| Radius | `400` |
| Hub cell | `32` |
| Hub radius | `40` |

Walking clears cells. Hidden spots do not need a trail.

## 4. Player islands

Six islands, `Plot1` … `Plot6`, in `WorldConfig` order. Each has:

| Property | Value |
|---|---|
| Centre | on the ring, `Y = 4` |
| Radius | `160` (about 320 across) |
| Bearing | `0, 60, 120, 180, 240, 300` |
| Notch | half-width `45`, head `30`, floor `Y = -30` |
| Plate | flat green Lego baseplate, studs, no terrain |
| Bridge | one per island, hub to island |
| Spawn | off the bridge, facing the station |
| Berths | boat starboard of the jetty; sub in the pen |

### 4.1 Island lots

`RingLayout.Islands[i].lots` uses the same local layout on every island:

| Lot | Use |
|---|---|
| `Station` | Station front, facing the bridge |
| `Boathouse` | Boats and boat board; doors onto the cove |
| `PaintBooth` | Craft paint swatches |
| `Helipad` | Helicopter pad with rotor clearance |
| `Hangar` | Helicopter storage |
| `SubPen` | Submarine pen over the cove water |
| `Jetty` | Along the cove centre |
| `BlueprintTable` | Trestle by the quay (tablet replaces it) |
| `CrewQuarters` | Late-game crew |
| `LifeguardTower` | On the beach |
| `Spare1`, `Spare2` | Quest-chain buildings, future buildings |
| `Spare3` | Between station and cove |

The flat plate is deliberate: it keeps the tycoon readable and cheap on phones. Do not add terrain or scatter.

## 5. Bridges

| Property | Value |
|---|---|
| Deck start, hub | `320` studs from the hub centre |
| Deck end, island | `90` studs behind the island centre |
| Towers, hub | `372` studs from the hub centre |
| Towers, island | `145` studs behind the island centre |
| Deck width | `14` studs |
| Apex | `Y = 50` (underside about `48.8` over the sea) |
| Tower top | `Y = 74` |
| Cable low point | `Y = 57` |

`RingLayout.deckY(bridge, t)` is a sine arch from the plateau at both ends to `apexY` at mid-span. The deck is
walkable; boats and the helicopter pass under. No road, no cars.

## 6. Outer ring

| Island | Centre | Radius | Role |
|---|---|---|---|
| Skerry Isle | `(1800, 0, 1750)` | `420` | Skerry light, seaplane wreck *Gannet Star* |
| Puffin Isle | `(-2600, 0, 3400)` | `650` | Puffins, grass humps |
| Penwyn | `(-4800, 0, -300)` | `850` | Windmill, small harbour |
| Wreck Reef | `(-3800, 0, 4200)` | `600` | Cargo wreck, reef |
| The Arches | `(5300, 0, -200)` | `650` | Stone arches, needle stack |
| Gannet Rock | `(3500, 0, 3500)` | `160` | Lighthouse, gannets |
| Mermaid Lagoon | `(300, 0, 5600)` | `900` | Turquoise lagoon, palms, turtle |

The outer islands are terrain, not baseplates. They are exploration and rescue spaces: calls, wrecks, wildlife,
bottles, views and critter stickers.

## 7. Sea and seabed

- The visible ocean is a client-built mesh driven by the shared wave function. Terrain below `Y = 0` is dry
  seabed; no Terrain water.
- The seabed runs to `Y = -165`. Wrecks, kelp, sand ripples and rock pools use the existing seabed assets.
- The submarine dives under the mesh ocean. Diver calls and wreck salvage happen on the seabed.
- Swimming and snorkelling are free-roam; the submarine is the deep exploration craft.
- No land vehicles. Travel is by boat, helicopter, submarine or on foot.

## 8. Calls and travel

- Calls 1–2 spawn inside the hub harbour, near the station.
- From call 3, calls spawn among the outer islands, about 600–2,000 studs out, farther as the best owned craft
  and rank grow.
- Rank caps reach (`CallLogic.craftReach`): Recruit 2,000; Lifeguard 3,500; Coxswain 5,500. A Robux boat buys
  speed, not extra reach.
- Drop-off is the player's own berth or the hub quay, whichever is nearer.
- Distance pay starts at 1,500 studs, scales with distance, cap ×4.
- A late call can fail ("Too slow"); nobody steals it.
- Free-roam swimmers appear between the islands for anyone sailing around.

## 9. Discovery

`DiscoveryConfig.Pages` has eight pages: `SkerryIsle`, `PuffinIsle`, `Penwyn`, `WreckReef`, `TheArches`,
`GannetRock`, `MermaidLagoon` and `Hub`. Each island page has a bottle, a view and one rare critter; the hub
page has the ruin view and the wreck bottle.

| Kind | Range | Cash |
|---|---|---|
| Stamp | 12 | 150 |
| Bottle | 8 | 75 |
| View | 9 | 75 |
| Critter | 24 | 75 |
| Wreck | 30 | 150 |
| Page | — | 300 |

Critter species: `SealPup`, `Puffin`, `Otter`, `Gull`, `SealPup`, `Gull`, `Turtle`. `Pages` is currently
empty in config; fill it as pages are wired.

## 10. Streaming and performance

- `StreamingEnabled` is on.
- `StreamingMinRadius = 384`; `StreamingTargetRadius = 1024`.
- The map and zones models are `Persistent`; dock pieces are `Persistent` so a player's island does not pop.
- The ocean is client-built and follows the camera.
- Re-measure phone memory and load time after the hub and islands land. The old town mobile numbers are retired.
- Keep the horizon clean: the ocean must cover the view from a player camera, with no square water edge.

## 11. Building the map

- `tools/world/` generates terrain, layout and the hub map image.
- `map/Build.luau` builds the place: terrain, zones, streaming, ocean and world pieces.
- `WorldConfig` holds the hub, ring, island radius and outer island rows.
- `RingLayout` is generated from `tools/world/layout.py`, so the layout always matches the bake.
- Regenerate and commit the layout data with any map change; do not hand-place lots in Studio only.
- The old `map/terrain/GenerateTerrain.luau` and Port Haven passes are historical; see the archive.

## 12. Scope

**In:** hub forest, six Lego islands, bridges, outer islands, seabed, calls, quests, dock/island building,
helicopter, submarine, wildlife, album.

**Cut:** Port Haven town, roads, cars and land vehicles, car garage, seaplane, land/cliff calls, NPC racer,
first person, photo mode, dispatch radio, phone UI.
