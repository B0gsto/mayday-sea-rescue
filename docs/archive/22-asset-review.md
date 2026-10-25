# 22 · Launch asset review (art director pass, 2026-10-24)

Source: `build/assets_review/sheet_*.png` (54 Studio shots, taken 15:30 to 19:28) and the owner's live screenshot of a grey car
above the station-yard fence. Bar: polished, AAA-feeling for Roblox, bright sunny Cornish harbour.
Verdicts: **SHIP** (as is), **FIX** (tweak: code, placement, recolour), **REPLACE** (new art), **RETAKE** (the shot can't be judged).
Note: the land shots predate 84844591 (grey asphalt), so the pure-black roads in them are already fixed. Re-check them, but they aren't findings here.

## Boats (`VehicleConfig.luau`, `shared/Boat/Builder.luau`, `VehicleService.luau`)

| Asset | Id / file | Verdict | Problem → fix |
|---|---|---|---|
| Jet Ski | `M_Veh_JetSki` (+`_CloseUp`) | SHIP | Clean, on-palette. |
| RIB | `M_Veh_RIB` + `M_Veh_RIB_Helm` | SHIP (P2) | The aft locker reads as a flat navy cube from the stern chase cam → give it a bevel/trim on the RIB atlas. |
| All-Weather Lifeboat | `buildLifeboat` / Tidewalker frame (Builder.luau:736, :1441) | SHIP | Reads well. |
| Storm Runner | `M_Veh_StormRunner` | SHIP | |
| Tidewalker | `M_Veh_Tidewalker` | SHIP | |
| Riptide X | `M_Veh_JetSki_RiptideX` | SHIP | |
| Gilded Gull | `M_Veh_JetSki_GildedGull` | SHIP | |
| Survivor in water | `M_Chr_Casualty_Swimmer` / R15 | FIX (P2) | Dark clothes on teal. Only the orange hat reads → add an orange lifejacket/strobe (doc 05 rule 1). |
| Survivor aboard jet ski | sled seat, `Boat/Builder` | RETAKE | Frame is washed out (camera at the water surface). Reshoot before judging. |

## Land vehicles and traffic (`LandVehicleConfig.luau`, `shared/Car/Builder.luau`, `LandVehicleService.luau`)

| Asset | Id / file | Verdict | Problem → fix |
|---|---|---|---|
| **Grey car in the station yard (owner shot)** | most likely the static `M_Veh_Coastguard4x4` tow rig, `World/StationYard.luau:388` (or a spawned 4x4 left as greybox, `LandVehicleService.withArt`) | **FIX (P0)** | Full mesh but no SurfaceAppearance, and it floats above the fence. Reproduce in the published place. If it's grey only there, the place was uploaded without texture packs (publish from Studio). Otherwise fix the appearance apply / pivot-to-ground. |
| Lifeguard 4x4 | `M_Veh_LifeguardPickup` | SHIP | |
| Coastguard Response 4x4 | `M_Veh_Coastguard4x4` | SHIP | |
| Beach ATV | `M_Veh_ATV` | SHIP | |
| Harbour GT | `M_Veh_HarbourGT` | FIX (P1) | Spawns clipping through the station-yard fence → move the StationYard spawn point clear. |
| Lighthouse Cruiser | `M_Veh_LighthouseCruiser` | FIX (P1) | Same fence clip. Same red as the parked cars, so the premium car looks like traffic → own livery (navy + cream lighthouse stripe). |
| Ambulance | `M_Veh_Ambulance` | SHIP (verify) | Overlaps a parked car in the Haven Sands car park. Check the bay layout (`Street.luau` car park). |
| 4x4 + boat trailer | `M_Veh_BoatTrailer_RIB` / `_JetSki` | RETAKE | Camera is inside the boatyard shed. |
| Parked / traffic cars | `M_Road_ParkedCar_01..03` (`Street.luau:1168`, `Town.luau:1548`, `TrafficArtService`) | FIX (P1) | Every car is the same red, boxy and lower in detail than the hero cars. A street of clones → 5-6 albedo colour variants (white, navy, silver, teal, cream), picked per bay. |
| Traffic light | `Street.luau` (code Parts) | SHIP (P2) | Plain pole. Fine at road distance. |

## Pets (`shared/WildlifeRig.luau`, `PetSeat.luau`, `PetController.luau`, `PetService.luau`)

| Asset | Id / file | Verdict | Problem → fix |
|---|---|---|---|
| Seal pup, Puffin, Otter, Turtle, Gull (all poses) | code-built Part rigs in `WildlifeRig` | **REPLACE (P1)** | Greybox block animals (the otter is a flat brick). On the RIB they are 1 to 2 studs and unreadable. They are the only Part-built creatures next to meshed Bosun → Opus Blender low-poly set in the `M_Chr_Bosun_LP` style, scaled about 1.5x for readability. Stopgap for the seal: the existing `M_Ani_GreySeal`, scaled down. |
| Pet on 4x4 roof | `PetSeat` roof anchor | FIX (P1) | Lost in the roof-rack clutter → raise it to a clear spot on the rack, or seat it in the rear tub. |
| Pet on RIB | `PetSeat` RIB aft seat | FIX (P2) | Hidden behind the seats from the chase cam. Fixed mostly by the bigger rigs. |

## Station and harbour

| Asset | Id / file | Verdict | Problem → fix |
|---|---|---|---|
| Station exterior | `M_Bld_Station` | SHIP | |
| Station interior hall | `World/StationRig.luau` | FIX (P1) | The RIB floats about 3 studs above its trailer (StationRig.luau:206-207 offset). The walls and floor are a harsh, tiling grey stone (MaterialService remap of Slate/Brick, see memory) and the hall is empty → seat the boat on the rollers, use unmapped materials or a trim SurfaceAppearance, dress with lockers, kit pegs and a tide board. |
| Slipway | `M_Bld_Slipway` | SHIP | |
| Launch bay | `StationRig` | SHIP | |
| Daily crate + sign | `client World/StreakCrate` (code Part box) | REPLACE (P1) | Plain brown box with a black blob. It's a reward object → Opus Blender sea chest `M_Prop_SeaChest` (brass corners, rope handles). Ties in with the future RNG Sea Chests. |
| Moored boats + buoys | `M_Veh_MooredBoat_01..03`, `M_Hbr_MooringBuoy` | SHIP | |
| Moored trawler | `M_Veh_MooredBoat_03` | SHIP | Best-looking boat in the game. |
| Harbour lighthouse | `M_Bld_HarbourLight` | SHIP | |

## Call scenes (`server/Ops/*Scene.luau`, `shared/Ferry/FerryRig.luau`)

| Asset | Id / file | Verdict | Problem → fix |
|---|---|---|---|
| Sinking vessel | `server/Ops/SinkingScene.luau` (code-built trawler) | **REPLACE (P0)** | Pure white untextured blocks with a stick mast, next to the textured moored trawler → clone `M_Veh_MooredBoat_03` (or `_02`) and keep the list/settle tween. |
| Burning cruiser | `server/Ops/FireScene.luau` (code-built cruiser) | **REPLACE (P0)** | Shot occluded, but it's the same code-built greybox → clone `M_Veh_Tidewalker` (static) and keep the fire/smoke emitters. Retake after. |
| Capsized ferry | `M_Veh_GaleQueen`, `M_Sea_Liferaft` | SHIP | |
| Cliff foot casualty | `M_Rock_Cliff_*` | FIX (P2) | Hard cut line where the rock meets the water, mossy underside visible → sink it 1-2 studs, add a foam band. |
| Rip current swimmer | RipFlow | SHIP | |
| Wildlife call | `shared/Ops/Definitions/WildlifeRescue.luau`, `WildlifeRig` | FIX (P1) | Only a human shows. No animal, no net → spawn the animal and its `Entanglement` above the surface, by the casualty. |
| Person in water | `M_Chr_Casualty_Swimmer` | SHIP | |
| Skerry lighthouse | CoastArt | SHIP | Boulder grounded in 84844591. |

## Characters and street

| Asset | Id / file | Verdict | Problem → fix |
|---|---|---|---|
| Chief Aggie | `NpcOutfits.luau` | SHIP (P2) | All-black outfit, low contrast. Optional RNLI yellow jacket. |
| Station crew / Aggie + crew | `NpcOutfits.luau` | SHIP | |
| Pedestrians | `NpcService.luau` / `AmbientController.luau` | FIX (P1) | Two walkers spawn inside each other, and the cyan outfit has an oversized blocky torso → min spawn spacing, swap that outfit. |
| Bosun | `M_Chr_Bosun_LP` | SHIP | Low poly on purpose. |
| Drop-off pad | `World/Harbour.luau` | FIX (P1) | Nothing marks the pad at gameplay distance (only a fender) → painted ring/chevrons on the pontoon deck (decal). |
| Street lamp, bin, bench, tide board | `M_Road_StreetLamp/Bin/Bench` (shared atlas) | SHIP | |
| Lobster pots | `M_Hbr_LobsterPot_01/02` | SHIP | |

## Prioritized fixes

**P0 (visibly broken / untextured)**
1. Grey untextured car floating in the station yard (owner shot).
2. Sinking vessel scene is a white greybox.
3. Burning cruiser scene is a code-built greybox.

**P1 (off-style / low quality)**: Part-built pets; wildlife call missing its animal; identical red traffic cars; Lighthouse Cruiser livery;
GT/Cruiser fence clipping; station hall (floating RIB, tiling stone, empty); daily crate box; pedestrian overlap; drop-off pad unmarked; pet roof seat.

**P2 (nice to have)**: survivor lifejacket; Aggie jacket; RIB aft locker; cliff waterline; traffic light; RIB pet seat. Retakes: trailer rig, survivor aboard jet ski, burning cruiser.

## Work packages (disjoint files; run in parallel)

**WP-1 · P0 code swaps (Opus, code only)**
Files: `server/Ops/SinkingScene.luau`, `server/Ops/FireScene.luau`, `server/World/StationYard.luau`, `server/Assets/AssetLoader.luau` (read, fix only if it's the root cause).
Do: reproduce the grey car in the real client; fix it at the root (texture pack missing from the publish, appearance apply, or pivot). Swap both scene hulls to existing meshes.
Accept: in Play, the sinking and fire calls show textured hulls with listing/fire still working; the station yard shows no grey or floating car in the Studio play and the published test place; `tools/check.sh .` passes.

**WP-2 · Placement and readability (Opus, code only)**
Files: `LandVehicleConfig.luau` (spawn points), `server/World/StationRig.luau`, `server/Services/NpcService.luau` / `client/Controllers/AmbientController.luau`, `NpcOutfits.luau`, `shared/Ops/Definitions/WildlifeRescue.luau` (+ its spawn in `RescueService`), `server/World/Harbour.luau` (drop-off marking), `shared/PetSeat.luau`.
Do: clear the GT/Cruiser spawns of the fence; seat the hall RIB on its trailer and swap the hall's remapped materials; space the pedestrians and swap the cyan outfit; make the wildlife animal and net visible; mark the drop-off pad; move the roof pet seat.
Accept: a fresh contact sheet of those tiles shows no clipping or floating, the animal and the pad readable at 40 studs; `tools/check.sh .` passes.

**WP-3 · Blender rebuilds (Opus agents, max 2 at once)**
Assets: `M_Pet_SealPup/Puffin/Otter/Turtle/Gull` (low poly, `M_Chr_Bosun_LP` style, one atlas), `M_Prop_SeaChest`. Then integrate in `shared/WildlifeRig.luau` and `client World/StreakCrate` (the only code files).
Accept: the pet sheet is redone (RIB, following, roof) and every pet is recognisable at chase-cam distance; an Opus art-director critique passes within 3 rounds; tris and texture under the doc 05 §5 budgets.

**WP-4 · 2D textures (Antigravity Gemini 4 Argon)**
Assets: `M_Road_ParkedCar_01..03` albedo colour variants (5-6), `M_Veh_LighthouseCruiser` livery albedo, the station hall wall/floor trim texture (handed to WP-2 as an image id), RIB aft-locker trim on the RIB atlas.
Accept: one street shot shows at least 4 car colours with no visible clones; the Cruiser is told apart from traffic at a glance; the albedo stays under the doc 05 §3.3 saturation ceiling.

Retakes (Haiku, after WP-1/2): trailer rig, survivor aboard jet ski, burning cruiser.
