# 12 · Asset list

The art the boat-upgrade game uses, and what is still a placeholder. Ids: `src/shared/Config/AssetIds.luau` (models),
`UiImages.luau` (UI), `VFXTextures.luau` (VFX). Sources: `art/source/<kind>/<name>/` (`.blend` + `build.py`). Add an
asset here before building it.

| Status | Meaning |
|---|---|
| **In game** | Built, uploaded, wired; keep its look |
| **Placeholder** | Code-built Parts; gameplay works without the final art |
| **Concept** | A concept page exists, not approved or not built |
| **Cut** | Removed; do not build |

## 1. The boat ladder (`BoatLevels`)

| Stage | Levels | Hull | Pieces | Status |
|---|---|---|---|---|
| Jet ski | 1-10 | `M_Veh_JetSki` | 9 (`M_Upg_JetSki_*`: Rescue Sled, Twin Engines, Banana Boat ...) | In game |
| RIB | 11-20 | `M_Veh_RIB` | 9 (`M_Upg_RIB_*`) | In game |
| Lifeboat | 21-30 | Lifeboat hull | 9 (`M_Upg_Lifeboat_*`) | In game |
| Hydrofoil | 31-40 | Parts on the RIB hull (`BoatLevels.levelParts`) | Parts | **Placeholder**, redo |
| Rocket Cutter | 41-50 | Parts on the Lifeboat hull | Parts | **Placeholder**, redo |

**Hydrofoil and Rocket Cutter redo.** The first meshes (`M_Veh_Hydrofoil`, `M_Veh_RocketCutter`, their `M_Upg_*`
pieces) read as weapons and were pulled (owner 2026-11-05); their ids stay in AssetIds, unused. New concepts with no
rocket or missile shapes and one chubby body: concepts round 4 (Hydrofoil 7.5, Rocket Cutter 7.6) approved by the
owner 2026-11-07, then built in Blender on branch `claude/late-boats-blender`: Rocket Cutter mesh passed at 8.2 and is
being wired (`BoatLevels.HullArt`); Hydrofoil mesh 7.8 after 3 rounds, waiting on the owner (ship or a 4th round).

## 2. Other craft

| Asset | Status | Notes |
|---|---|---|
| Storm Runner, Tidewalker, Riptide X, Gilded Gull | In game | Robux looks at your level's stats |
| Rescue helicopter (`M_Veh_RescueHeli`) | In game | Pass craft; winch pick-up |
| Submarine | Placeholder | `Sub/Builder` Parts |
| Pirate boat + captain, deckhand, lookout | In game | `M_Veh_PirateBoat`, `M_Chr_Pirate*` (x2.3) |
| Supply barge, moored boats, Gale Queen | In game | World dressing |
| Star Saucer, Dragonkeel, Quack Attack (paid boats) | Concept | Not built |

## 3. World

| Asset | Status | Notes |
|---|---|---|
| Upgrade Station (`M_Bld_UpgradeStation`) | In game | On every island, x2.5; bay gate fits L50 |
| Six player plates (640 wide, ring 860) | In game | Lego baseplates; `IslandPlates`, `Bridges` |
| Island buildings (`M_Bld_*`: Rescue HQ, Depot, Bunkhouse, addons) | In game | Optional island tree |
| Build station, jetty crane, board kit, build-site kit, sea plates | In game | `M_Prop_*` |
| Hub beacon atoll (`M_Prop_HubKit`) | In game | Centre lagoon landmark, not an island |
| Lagoon kit | In game | Mermaid Lagoon |
| Sector spots (sea stacks, wreck aground, lighthouse rock) | In game | Hub kit pieces scaled up, `server/World/SectorSpots` |
| Outer islands: Penwyn, Puffin Isle, The Arches, Wreck Reef, Gannet Rock, Mermaid Lagoon, Skerry light | In game | Terrain + kits |
| Prize wheel / Deep Spin set | In game | `M_Prop_PrizeWheel`; the Deep set is client-built |
| Zone buoy line | Placeholder | `Ocean/SeaBuoy` Parts |
| Harbour kit, rocks, vegetation, seabed | In game | `M_Hbr_*`, `M_Rock_*`, `M_Veg_*`, `M_Sea_*` |

## 4. Characters and creatures

| Asset | Status | Notes |
|---|---|---|
| Players, survivors, quest givers, crew | In game | R15; survivors in orange life jackets |
| Bosun (`M_Chr_Bosun_LP`) | In game | Low-poly dog |
| Pets: otter, puffin, seal pup, turtle, gull | In game | Scale checks open (docs/NEXT 0l) |
| Wildlife (`M_Ani_*`) | In game | Seals, gulls, puffins, otters, turtles; dolphins, whale |

## 5. UI and VFX

| Asset | Status | Notes |
|---|---|---|
| HUD and kit sprites (103 sources in `art/source/ui/`) | In game | Go back, fuel can + chevron, kit icons, pad, pins, gems, stamps |
| Pirate edge arrow | Placeholder | Reuses the red pin with a flag |
| Product icons | In game | `marketing/items/` (local PNGs) |
| VFX flipbooks | In game | Per moment in `26-vfx.md` |

## 6. Audio

Boat engines, hull slap, sea and wind, UI ticks and stings, level-up slam, pirate and fuel cues
(`Config/AudioConfig`), NPC voices only (`VoiceTTS`). No radio dispatch.

## 7. Cut

Cars, roads, Port Haven town, seaplane, phone UI, dispatch radio, first person, ranks and Rep, hologram previews,
store thumbnails (the owner's). Restorable from git tag `pre-hub-cut` only if the design changes.

## 8. Done means

Reads at chase-camera distance and on a phone, right scale, LODs, no z-fighting (`zfight_check.py`, `zfight_scan`),
no real logos, art director above 8, visible in the live build.
