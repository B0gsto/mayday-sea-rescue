# Rocket Cutter stage (L41-L50): result

Round 2 (art director round 1: 6.5), no score yet for this round. Earlier uploads are superseded: use only the ids below. Concept: artifact b8ff43b0 (Rocket Cutter). Geometry: `pieces.py` + `kit.py` (the Lifeboat stage's Kit with this stage's palette), one thin `build.py` per asset in `art/source/vessels/M_Veh_RocketCutter` and `M_Upg_Rocket_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `build/status/2026-11-04/art/rocket.png` (`sheet_scene.shoot_all()`, then `compose_sheet.py`).

## Ids

The hull's pivot sits where `Boat/Builder buildTidewalkerAsset` expects a Lifeboat-frame model (`Builder.TIDEWALKER_ORIGIN`), so the offset is already applied by that builder. Every other row is authored in HullRoot space: **offset (0, 0, 0)**, `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull, as on the Lifeboat stage.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 41 | `M_Veh_RocketCutter` | 138161022724220 | 85718046701791 | 87034399734856 | (0, -2.8, -0.01) | 9808 / 3432 / 918 |
| 41 | `M_Upg_Rocket_Pilot` | 126471127491874 | 109637142495504 | 114076687632474 | (0, 0, 0) | 1324 / 662 / 327 |
| 42 | `M_Upg_Rocket_SideBoosters` | 134202754687313 | 84373615073890 | 87884720098911 | (0, 0, 0) | 5312 / 2655 / 1328 |
| 43 | `M_Upg_Rocket_GoldPlating` | 110072836627566 | 131670945768831 | 123724614370673 | (0, 0, 0) | 3300 / 1650 / 825 |
| 44 | `M_Upg_Rocket_WaveWall` | 97040277762229 | 122516165689557 | 71543044168157 | (0, 0, 0) | 1360 / 680 / 340 |
| 45 | `M_Upg_Rocket_GoldEagle` | 98218707535728 | 74701960269580 | 140646871274726 | (0, 0, 0) | 1236 / 618 / 308 |
| 46 | `M_Upg_Rocket_RocketFins` | 131740947120033 | 140123533532668 | 112232417087833 | (0, 0, 0) | 600 / 300 / 150 |
| 47 | `M_Upg_Rocket_GoldThrone` | 111497127061131 | 123470425695440 | 122032670105723 | (0, 0, 0) | 1060 / 530 / 264 |
| 48 | `M_Upg_Rocket_PartyCannons` | 131810120995788 | 86407498717332 | 104468224161552 | (0, 0, 0) | 3516 / 1757 / 879 |
| 49 | `M_Upg_Rocket_MegaTrophy` | 102726908160156 | 71996844442537 | 127474263133889 | (0, 0, 0) | 1832 / 916 / 458 |
| 50 | `M_Upg_Rocket_SunBooster` | 140572360259021 | 96286982766885 | 140643131082920 | (0, 0, 0) | 2280 / 1140 / 570 |

Shared palette set (one SurfaceAppearance for all eleven), `T_UpgRocket_Palette_*`, 256 px: ALB 101967041086669, NOR 94365844917813, RGH 117753746694610, MET 104820073034248. Moderation at upload: Approved.

Attachments (each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Veh_RocketCutter: the full Tidewalker set (DriverSeat, EyePoint, PassengerSeat1-3, TowHitch, BowPoint, DriveAttachment, Nav*, Beacon, Searchlight, Prop1-2, Float1-8), SurvivorSlot1-14, plus Flame_Main and NumberPlate_P/S.
- M_Upg_Rocket_SideBoosters: ATT_Flame_P, ATT_Flame_S
- M_Upg_Rocket_WaveWall: ATT_Crest_P, ATT_Crest_S
- M_Upg_Rocket_PartyCannons: ATT_Confetti_P, ATT_Confetti_S
- M_Upg_Rocket_MegaTrophy: ATT_Gleam
- M_Upg_Rocket_SunBooster: ATT_Flame_Sun

## Frame

Concept (x, y, z) to HullRoot: (z, y + 1.5, 10 - x). Bow -Z, 61 long from z -30 to +31.2, 10 wide, keel at hull y -0.9, sea at hull y +1.5 (the concept's y 0, on the red band). Rocket axis at hull y 11.3, radius 4.9.

## Checks

validate PASS for all eleven (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `texture sets`, `LOD0 floor`; reasons in `pieces.py`). zfight: all 33 exported FBX scanned, 0 visible pairs. Hull, pilot and all nine pieces together at L50, in the source geometry: 0 visible pairs. Not tried in Studio or in play.

## What the game code must do

1. **Hull:** on `VehicleConfig.RocketCutter` set `model = "M_Veh_RocketCutter"`. `variant("Lifeboat")` then routes it through `buildTidewalkerAsset` with no Builder change. Run `tools/gen_asset_ids.py` after merging the manifest; it reads the attachments from `assets/fbx/<asset>/`, committed here for all eleven.
2. **Size:** set `hullSize = Vector3.new(10, 7.5, 60)`. With the Lifeboat's 51.9, `scaleFor` caps at x1.387 and she shows 85 long; with 60 she caps at x1.2 and shows 73 (61.2 modelled, swim platform and cutwater included), about `MAX_LENGTH`. The concept's own ladder is x1.00 to x1.15.
3. **Pieces:** clone by level (table above), CanCollide off, no `_COL`. `BoatLevels` PIECES still lists the old names for L41-L50, and `tools/blender/names.py` needs `Upg` (only allowed at run time in `pieces.py`).
4. **Pilot (decided):** the player rides the rocket. `ATT_DriverSeat` is the saddle, where the sheet shows the pilot: model (0, 20.45, 0.01), HullRoot (0, 17.65, 0). Keep `M_Upg_Rocket_Pilot` hidden while a player is seated; show it only on an empty boat. The sheet shows it at every level. The seat is 17.65 above HullRoot (x1.2 in play), so check the climb-on and the exit in play.
5. **Survivors:** `buildTidewalkerAsset` only places `spec.survivorCapacity` slots and the variant inherits the Lifeboat's 8, so set it to 14 to get all of `ATT_SurvivorSlot1-14` (room is 12 at L41, 14 at L50). Slots 13-14 are on seats that ship in `SunBooster`. Seats sit at z +-3.4 under the rocket's curve: check heads in play.
6. **Camera:** from L44 the chase cam must pull back about x1.25 (used for the sheet's L45 and L50 phone views) or the wave walls and the sun's flame reach the lens. `ATT_EyePoint` moved up with the saddle.
7. **Sun at L50:** the sun's navy shaft covers the rocket's own flame, and the booster flames pass outside the disc. Nothing needs hiding.
8. **VFX:** flames, lenses and confetti are plain palette colours. Add moving fire and bursts at `ATT_Flame_*`, `ATT_Confetti_*`, `ATT_Crest_*`, `ATT_Gleam`. The poppers fire confetti only.
9. **Number plate:** the concept's per-level digits are not built (one mesh a level is waste). Draw them with a SurfaceGui at `ATT_NumberPlate_P/S`.

## Round 2 changes (art director 6.5/10)

- **Sun:** radius 7.2 to 4.3 (-40%), on a navy shaft 7 behind the nozzle with a studded wedge off the transom. Eight fat rays. New warmer colour, its own palette cell.
- **Rocket:** 1.4x: radius 3.5 to 4.9, about 52 long nozzle to nose. Axis raised so it clears the prow spine; three saddles. The prow now reaches 9 past the nose, not the concept's 17. Rider on top is the highest thing on the boat.
- **Shrunk:** trophy 0.43x and strapped on the rocket's back ahead of the rider, below his head. Throne: arch gone, low back with a navy rear panel, top under his helmet. Eagle a hood ornament on the prow tip.
- **Colour:** rings narrowed, one bow trim cut, fin tips navy, windows navy-rimmed, nose ball white, popper rims white.
- **Brackets:** studded plates and wedge pylons under the boosters, chrome bands round them, navy straps under throne and trophy, bolted fin feet, plate under the eagle.
- **Poppers:** wide flared red and white cones, open dark mouths turned up, out and aft at the chase camera, three flat streamers spilling over the lip.
- **Wave Wall:** peels off the hull sides under the boosters, low until clear of the booster flames.

## Departures from the concept

- Cut as noise: rails, ladder, rivets, windscreen, chevrons, 40 confetti bits, wake bricks and spray. Fewer, bigger windows.
- **Wave Wall:** two sculpted lofted walls, opaque aqua, not stacked translucent bricks. Lower than the concept, centre lane open.
- **Side Boosters:** navy with one white band, so the striped rocket stays the hero. Wider apart (z +-7.8) to clear the bigger rocket.
- **Rocket nose:** a toy ball on the tip and a rounded gold cap, instead of the concept's chrome tip and gold spike: never a warhead.
- **Sun flame:** blown out of the grin, 8 long, not the concept's 22 centre cone.
- **L50 colour:** gold plus red on the navy and white base. Poppers are red and white with red, gold, white and yellow confetti, dropping the concept's pink, blue, green and purple. Aqua water and flame colours remain.

## Open

- "Mega" Trophy is now small, by art director request; its name oversells it.
- Survivor seats sit under the rocket's curve (z +-3.4): heads may clip it. Check in play.
- At x1.2 the boat stands about 27 tall to the rider's helmet: check the Upgrade Station bay (same clearance problem as the Lifeboat stage).
- Colours were judged only in Blender's flat EEVEE stage, not under the game's lighting.
