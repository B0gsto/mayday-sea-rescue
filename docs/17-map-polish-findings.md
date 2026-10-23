# 17 · Map polish findings (art-director pass 2, whole map, 2026-10-23)

Source: `~/RobloxProjects/mayday-tour/build/tour/sheet_1..4.png` (32 viewpoints, `points.json`), full shots in
`build/smoke/<name>.png` (768 px). Read-only review. Pass 1 only saw the station; this pass covers town, coast and aerials.
Verdict: the bones work (good terrace facades, decent sky) but from above it reads as a flat suburban grid on a
blotchy slab in a Caribbean sea, and at street level as wide, empty, pristine roads. Not yet "Cornish harbour town".

## 0. Viewpoints to re-place before the next pass (14 of 32 are useless)

| Viewpoint | Problem | Re-place to (eye -> look) |
|---|---|---|
| harbour_road_east | inside the chandlery arcade | (-40,10,-30) -> (120,4,-30) along the road |
| harbour_quay | inside a parked van | (0,10,-10) -> (0,2,150) over the basin |
| chandlery | face against a wall | (-44,8,-25) -> (-44,6,-60) front of the shop |
| fore_street | face against a wall | (20,8,-150) -> (-300,4,-150) down Fore Street |
| chapel_square | behind a green box | (76,10,-170) -> (76,6,-230) |
| town_crescent | under a bus shelter | step 15 studs into the road |
| hospital | wall at 3 studs | (130,10,-80) -> (130,6,-120) |
| haven_sands_beach | inside the lifeguard tower | (1000,8,330) -> (1000,2,450) |
| haven_sands_car_park, high_road_moor, haven_head_track, skerry_isle | eye inside terrain (props float, hill seen from within) | eye = terrain height + 6 |
| sandy_point | in open sea | Sandy Point is (560, 530) |
| long_strand, tempest_point, kittiwake_cliffs, puffin_isle | outside the +/-2560 bake (open sea; these places do not exist) | drop, or use West Cliff (-900,-40), Trevose Farm (-720,-920), Penmorvah (1040,-1180), Harbour Light (64,322) |

Capture rule: sample `map/generated/terrain_height.i16` for eye Y, raycast eye->look and nudge if blocked < 20 studs,
and hide the KM/H HUD in aerials (it shows in all of them).

## P0: not publishable

1. **The town is one repeated block.** `map_aerial_harbour` (0,500,200) / `map_aerial_north`. Every one of the ~25
   blocks is the same ring of 3-storey terraces with pale roofs around an empty green court, all one height, same
   setback. Fix (inside the grid): per-row floors 2/3/4 from a seeded mix (not just "4 on Fore Street"); 1-in-5 lots
   a gap, gable-end-on cottage or chapel/pub/garage; roofs dark slate (#3A3F45) with varied pitch, hipped ends and
   chimney stacks at different heights; 6-8 wall colours (cream, pink, pale blue, sage, white render, bare granite)
   never the same twice in a row; stepped eaves between neighbours. Files: `src/server/World/TownLayout.luau`
   (floors, lot variants), `src/server/World/TownBuildings.luau` (roof/colour/stack variants).
2. **Port Haven sits on a dead-flat plain.** `map_aerial_north`, `chapel_hill` (-100,12,-160). No hill behind it, no
   skyline. Fix without touching the grid platform: raise the land north of z -560 into a 40-80 stud hillside in 3-4
   terraced shelves with granite retaining walls, a skyline of the chapel tower, a row of wind-bent trees and the moor
   ridge behind; add a 1-2 stud rise per street northwards only if Street/Town sample terrain height (check first).
   Files: `tools/world/layout.py` (TOWN_PLATFORM, hill spec), `tools/world/gen_terrain.py`, re-bake `map/terrain`.
3. **Streets are wide, empty and pristine.** `chapel_hill`, `harbour_road_west` (-480,12,-40), `fuel_dock_boatyard`
   (200,14,-20). 30-stud black asphalt with clean white lines, pale gravel pavements, flat bright verges, almost no
   furniture. Fix (keep the 30-stud driving width): parallel-parked cars in painted bays one side (visually narrows
   it), double yellow lines, granite kerbs with a 0.3 lip, Slate-grey flagstone pavements (not the pale Pavement
   gravel), cast-iron lamps every 40 studs, bins, benches, bollards, planters and hanging baskets, A-boards and awnings
   at shopfronts, bunting across Fore Street, telephone box, post box. Files: `src/server/World/Street.luau`
   (kerbs, lines, lamps), `src/server/World/StreetFurniture.luau`, `src/server/World/TownExtras.luau` +
   `TownExtrasLayout.luau` (parked cars, bunting, shop clutter).
4. **No front gardens, walls or trees.** Same views. Houses stand on a strip of mown lawn. Fix: 4-6 stud front
   gardens behind 2-stud granite walls or Cornish hedges (stone base, grass top) with gates, cottage-garden shrubs,
   palms (Cornish cabbage palms) and 1 street tree per ~60 studs on the outer avenues. File: `src/server/World/Town.luau`
   (garden(), extend to front gardens) with `TownLayout.gardens`.
5. **The sea is Caribbean cyan.** Every water tile (`harbour_mouth`, `calm_bay_water`, aerials). Fix: Clear preset
   WaterColor about #2E5A55, deep palette green-grey, less specular glitter; shallow tint over sand a muted
   jade, not turquoise. Files: `src/shared/Config/LightingPresets.luau` (Clear WaterColor line ~170),
   `src/client/Ocean/OceanPalette.luau`.
6. **Blank white sign boards.** `station_slipway` (-230,12,-80), `fuel_dock_boatyard`, `chandlery`: white rectangles on
   black posts, i.e. missing decals. Fix: locate them in Studio (`tools/studio/smoke.py`), give each a real face
   (fingerpost, tide board, car-park P, street name in black-on-white Cornish style) or remove. Likely
   `src/server/World/RoadsShore.luau` SIGNS (line ~79) or `Street.luau`.
7. **Harbour arms are two rulers.** `map_aerial_harbour`: two straight parallel piers ~350 studs long with a rectangular
   basin. Fix (keep the 80-stud channel): dog-leg the outer third of each arm inward so they converge on the mouth,
   granite block texture with a parapet on the sea side, rock armour at the seaward foot, weed band at the waterline,
   lamp + ladder every 40 studs, light towers at both pierheads. File: `src/server/World/Harbour.luau`.

## P1: clearly visible

8. **Island reads as a slab.** `map_aerial_overview` (-2500,2200,1000), `map_aerial_west/east`. Near-rhombus outline
   with long straight coasts, flat top, uniform low edges. Fix in the bake: 2-3 headlands and coves per side, real
   cliffs (Rock/Basalt, 30-60 studs) on the west and north coasts, beaches only in coves. Files: `tools/world/layout.py`
   (GREAT_GALE outline), `gen_terrain.py`.
9. **Moor is camouflage.** Aerials: green with grey dither blotches, no fields, hedges, trees or farms visible except one
   white box. Fix: Cornish patchwork fields bounded by 3D hedges (RoadsShore already has the kit; place along field
   edges, not just roads), gorse clumps, tor outcrops on the ridge, Trevose and Penmorvah farms as stone farm groups.
   Files: `gen_terrain.py` (field pattern, tor heights), `src/server/World/RoadsShore.luau` + `RoadsShoreLayout.luau`.
10. **Sea from altitude is bare seabed.** All aerials: a cyan square near the harbour, then a sand-coloured +/-2560
    slab (the bake's seabed), then pale skirt. The skirt is culled above ~590 studs (Horizon.luau note). Fix: when
    `setHigh`, use 2048-stud tiled Parts over +/-8000 instead of the scaled-mesh skirt. File: `src/client/Ocean/Horizon.luau`.
11. **Far islands are dark loaves.** `calm_bay_water`, `haven_sands_beach`: Skerry and the Skerries read as flat brown
    logs. Fix: taller profiles with cliff faces, white guano streaks, Skerry Light visible on top. File: `RoadsShore.luau`
    islands() (M_Rock_IslandProxy_Kit placements) / `src/server/World/SkerryLight.luau`.
12. **Haven Sands beach.** `haven_sands_beach`: a large black stain on bright white sand (the rock pools read as an oil
    spill); black specks on `calm_bay_water` spit. Fix: rock pools as raised Basalt ledges with rock meshes and wet-sand
    darkening around them; sand warmer and darker (#CDBB94); remove floating specks. Files: `RoadsShore.luau` (pools,
    wrack), sand colour in `src/server/World/Town.luau` TINT.
13. **Terrain shards at Haven Head.** `haven_head_viewpoint` (1580,82,640): dark slivers floating in the sky. Probably the
    eye grazing terrain; if they remain with the eye 10 studs higher it is bake debris. File: `gen_terrain.py` (shell).
14. **Station yard and quay are empty grey fields.** `station_yard` (-230,14,-90). Fix: bay markings, crew car spaces,
    tractor and trailer, fuel bowser, fenced compound, flagpole. Files: `src/server/Services/WorldDressingService.luau`.
15. **Plain box landmarks.** `chapel_square`: a beige block with black holes for windows. Fix: window frames, sills,
    a cornice and a door. File: `TownBuildings.luau` (landmarks).
16. **Light is flat and over-clean.** Every street tile: no haze, distant land as crisp as foreground. Fix: Clear preset
    AtmosphereDensity 0.36 -> 0.42, Haze 1.5-2, a warmer sun, ColorCorrection contrast +0.05, saturation -0.08.
    File: `LightingPresets.luau`.
17. **Carried from pass 1 (station, unverified here):** missing slipway textures, winch box, green box shed, flat blue
    roller door. Files: `Swaps.luau`, `StationRig.luau`, `SharedSetsRig.luau`. Recheck with a fixed `station_slipway`.

## P2: polish

18. Worn road paint, patched asphalt, drain covers. `Street.luau`.
19. Quay railings toy-blue -> galvanised grey. `Harbour.luau`.
20. More moored boats and punts in the basin, gulls on bollards, washing lines up the hill. `TownExtras.luau`.
21. Grass verges too saturated and even: tint olive, add clover/weed patches. `Town.luau` TINT.
22. Lighthouses: give Harbour Light and Skerry Light a beam cone at dusk. `Street.luau` (Harbour Light), `SkerryLight.luau`.

## Work packages (disjoint files, parallel)

- **WP-1 Town massing, gardens, ground tints (P0 1, 4; P1 12 sand colour, 15; P2 21).** `TownLayout.luau`,
  `TownBuildings.luau`, `Town.luau` (incl. TINT).
  Accept: `map_aerial_harbour` shows 3+ roof heights, dark roofs and no two neighbours the same colour; a re-placed
  `chapel_hill` shows front walls, gardens and a tree within 60 studs.
- **WP-2 Streets and street life (P0 3, 6 if in Street; P2 18, 20).** `Street.luau`, `StreetFurniture.luau`,
  `StreetLayout.luau`, `TownExtras.luau`, `TownExtrasLayout.luau`.
  Accept: `chapel_hill` and `fore_street` (re-placed) show parked cars, yellow lines, flagstone pavement, lamps,
  bins, awnings; no blank white boards anywhere in `harbour_road_west` / `fuel_dock_boatyard`.
- **WP-3 Terrain bake (P0 2; P1 8, 9 terrain side, 13).** `tools/world/layout.py`, `tools/world/gen_terrain.py`,
  `map/terrain`, `map/generated`, MapConfig image re-render. Accept: `map_aerial_north` shows a hill with terraces behind
  the town and a field patchwork; `map_aerial_overview` shows headlands, coves and cliff faces; town grid untouched.
- **WP-4 Coast, harbour and shore props (P0 6 if in RoadsShore, 7; P1 9 hedges, 11, 12 pools, 14; P2 19).**
  `Harbour.luau`, `RoadsShore.luau`, `RoadsShoreLayout.luau`, `CoastArt*.luau`, `SkerryLight.luau`,
  `WorldDressingService.luau`. Accept: `map_aerial_harbour` shows converging granite arms
  with lit pierheads; `haven_sands_beach` (re-placed) shows rock ledges, no black stain; `calm_bay_water` shows
  Skerry with a cliff profile and a lighthouse.
- **WP-5 Water and light (P0 5; P1 10, 16).** `LightingPresets.luau`, `src/client/Ocean/OceanPalette.luau`,
  `src/client/Ocean/Horizon.luau`. Accept: `harbour_mouth` water reads green-grey, not cyan; all 6 aerials show
  sea to the horizon with no sand slab; distant headlands visibly hazed in `harbour_road_west`.
- **WP-6 Tour fix (section 0) then pass 3.** `mayday-tour/build/tour/points.json` and its capture script only.
  Accept: 32 tiles, none inside a wall, vehicle or terrain; no HUD in aerials. Run after WP-1..5 land.
