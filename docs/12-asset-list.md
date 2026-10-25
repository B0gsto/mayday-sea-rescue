# 12 · Asset list

What art and audio the current game needs, what already exists, and what is still a placeholder. The design is
[`00-design.md`](00-design.md); the look is [`05-art-direction.md`](05-art-direction.md). If an asset is not
here, add it here before building it.

## 1. Status words

| Status | Meaning |
|---|---|
| **In game** | Built, uploaded and wired; keep its look. |
| **Placeholder** | Code-built Parts or a temporary model; gameplay works without the final art. |
| **New** | To build in the current style. |
| **Cut** | Removed from main; restorable from git tag `pre-hub-cut`. Do not build. |

## 2. Craft

| Asset | Status | Notes |
|---|---|---|
| Jet ski | In game | Free starter craft, one seat |
| RIB | In game | Lifeguard craft, three survivors |
| Lifeboat | In game | Coxswain craft, eight survivors |
| Storm Runner | In game | Premium RIB variant |
| Tidewalker | In game | Premium lifeboat variant |
| Riptide X | In game | Premium jet ski |
| Gilded Gull | In game | Premium jet ski |
| Rescue helicopter | In game | Hangar craft; winch pick-up |
| Submarine | In game | Sub pen craft; seabed pick-up |
| Patrol cutter | Cut | Not in the current loop |

Premium craft use the same handling as their base craft. Robux buys the boat, never better handling.

## 3. Hub forest

| Asset | Status | Notes |
|---|---|---|
| Hub terrain | In game | Forest island, about 800 studs across; terrain bake |
| Lookout hut HQ | New | Coastguard lookout on legs; radio and call board are props, not a radio system |
| Call board | New | Pager/call board at the HQ |
| Market stall | New | Shop counter; striped awning |
| Harbourmaster shack | New | Small frontier shack on the quay |
| Campfire stage | New | Ring of logs, fire, event space |
| Rescuer monument | New | Clearing monument; weekly top rescuer |
| Visitor jetty | New | Hub drop-off and visitor berth |
| Quest camps | In game | Six givers: Old Maud, Tam, Captain Rook, Nell, Keeper Ives, Pip |
| Ruin | New | Hidden hilltop ruin; view sticker |
| Overgrown wreck | New | Hidden hub wreck; bottle sticker |
| Forest trails, trees, rocks, fog | In game | Terrain and scatter; fog lifts as walked |
| Cave / waterfall | New | Optional hidden landmark; do not block the loop |

No town buildings, roads, parked cars or street furniture on the hub.

## 4. Player islands

| Asset | Status | Notes |
|---|---|---|
| Flat Lego baseplate | In game | Green stud plate, berth notch, no terrain |
| Jetty and name board | In game | Lv 1; owner flag |
| Dock Lv 2: pontoon, lamps, rescue board | In game | Placeholder Parts |
| Dock Lv 3: boathouse, boat board, paint booth | In game | Boat board is the in-world craft picker |
| Dock Lv 4: lookout tower, slipway crane | New | Faster relaunch, lifeboat berth |
| Dock Lv 5: station front, beacon, trophy hall | New | Harbour Master flex |
| Build station / tablet | In progress | Lego builder's yard; top-down build mode (WP-14d) |
| Helipad and hangar | New | Helicopter |
| Sub pen | New | Submarine |
| Crew quarters | New | Late-game crew |
| Spare lots | New | Quest-chain buildings, future buildings |
| Lego build VFX | New | Brick drop, bounce, snap, dust |
| Blueprint table (paper) | Cut | Final game uses the tablet; WP-14c is the interim upgrade flow |

All new island buildings are Lego-style. Existing dock placeholder Parts can be replaced without changing the
layout.

## 5. Outer islands and sea

| Asset | Status | Notes |
|---|---|---|
| Skerry Isle | In game | Terrain; seaplane wreck, *Gannet Star* |
| Puffin Isle | In game | Terrain; puffins |
| Penwyn | In game | Terrain; windmill and harbour |
| Wreck Reef | In game | Terrain; cargo wreck |
| The Arches | In game | Terrain; stone arches |
| Gannet Rock | In game | Terrain; lighthouse |
| Mermaid Lagoon | In game | Terrain; turquoise lagoon |
| Seabed | In game | Terrain, wrecks, kelp, sand |
| Wildlife | In game | Seal pup, puffin, otter, gull, turtle |
| Buoys, nav marks, moorings | In game | Existing harbour kit |
| Storm and ocean VFX | In game | Shared wave function; spray, foam, rain |

## 6. UI and 2D art

| Asset | Status | Notes |
|---|---|---|
| UI kit | Planned | `src/client/UI/Kit/` (WP-23b; not created yet) |
| Left button icons | New | Shop, Quests, Album, Companion, Crew, Settings, Boat to me, Map |
| Panel, card, price button | New | 9-slice simulator-style kit |
| Build tablet cards | New | Dock, boathouse, lookout, station, hangar, sub pen, crew, spare |
| Album stamps | In game | Existing sticker ids; drop St Elowen |
| Quest giver icons | New | `!` bubble, role glyphs |
| World signs | New | See [`19-world-sign-art.md`](19-world-sign-art.md) |
| Store art | New | Icon and thumbnails; see [`07-store-page-thumbnails-and-trailer.md`](07-store-page-thumbnails-and-trailer.md) |

New UI art goes under `marketing/ui/icons/`. The old phone sets are cut; do not port them.

## 7. Characters and creatures

| Asset | Status | Notes |
|---|---|---|
| Player avatar | In game | Simple R15 |
| Quest givers | In game | Six named NPCs |
| Survivors | In game | R15 with orange lifejacket |
| Crew | In game (basic) | Simple R15; roles shown by icon; full crew is WP-15 |
| Bosun | In game | Low-poly dog; one companion |
| Wildlife | In game | Existing models and animations |
| First-person arms | Cut | Third person only |
| Custom human meshes | Cut | R15 only |

## 8. Audio

| Asset | Status | Notes |
|---|---|---|
| Boat engines, hull slap, wind and sea | In game | Per craft and weather |
| UI ticks, reward stings, rank-up | In game | Existing clips |
| Quest NPC voices | In game | Voices only for NPCs |
| Radio dispatch and voice lines | Cut | No dispatch radio |
| Sea Shanty Radio music item | In game | Music item only |
| Lego build snaps and dust | New | Short, chunky |

## 9. Cut list

Do not build or restore these for the current game:

- Cars and all land vehicles, car garage, roads, traffic, Port Haven town.
- Seaplane, land calls, cliff calls, NPC racer.
- First-person camera, viewmodel, photo mode.
- Rare rescue variants and their dressing.
- Dispatch radio, phone UI, iOS app tiles, phone wallpaper.
- Street name plates, tide boards, car-park signs, cliff-warning signs.

Restorable from git tag `pre-hub-cut` if the design changes.

## 10. Production

- **New Blender:** DeepSeek V4.1 Flash via T3 `delegate_task`, `art/bench/PROD_BRIEF.md`; at most three at a
  time, two Blender jobs.
- **New code and placeholder art:** DeepSeek V4 Pro builders, several in parallel; Opus reviews.
- **Existing finished assets:** do not redesign. Only integrate or fix.
- **Placeholders first:** gameplay never waits on art.
- **Asset diet (WP-16):** drop unused ids, merge near-duplicate PBR surfaces, measure phone memory and load.
- **Naming:** `M_` models, `T_` textures, `M_Bld_`, `M_Veh_`, `M_Hbr_`, `M_Kit_`, `M_Ani_`, `M_Veg_`, `M_Rock_`.
- **Ids:** `src/shared/Config/AssetIds.luau`; UI in `UiImages.luau`.
- **Definition of done:** reads at gameplay distance, correct scale, no real logos, no missing textures,
  passes `check.sh`, and is visible in the live build.
