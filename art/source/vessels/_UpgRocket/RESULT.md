# Rocket Cutter stage (L41-L50): result

Round 1, no art director score yet. Concept: artifact b8ff43b0 (Rocket Cutter). Geometry: `pieces.py` + `kit.py` (the Lifeboat stage's Kit with this stage's palette), one thin `build.py` per asset in `art/source/vessels/M_Veh_RocketCutter` and `M_Upg_Rocket_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `build/status/2026-11-04/art/rocket.png` (`sheet_scene.shoot_all()`, then `compose_sheet.py`).

## Ids

The hull's pivot sits where `Boat/Builder buildTidewalkerAsset` expects a Lifeboat-frame model (`Builder.TIDEWALKER_ORIGIN`), so the offset is already applied by that builder. Every other row is authored in HullRoot space: **offset (0, 0, 0)**, `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull, as on the Lifeboat stage.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 41 | `M_Veh_RocketCutter` | 112306919924355 | 134451409666695 | 72755596693634 | (0, -2.8, -0.01) | 9780 / 3423 / 924 |
| 41 | `M_Upg_Rocket_Pilot` | 124092782653891 | 136847981114679 | 127469206184080 | (0, 0, 0) | 1324 / 662 / 327 |
| 42 | `M_Upg_Rocket_SideBoosters` | 101872685988051 | 131345239159797 | 110956447012453 | (0, 0, 0) | 4688 / 2343 / 1171 |
| 43 | `M_Upg_Rocket_GoldPlating` | 133072901240643 | 130587272671536 | 129052639314978 | (0, 0, 0) | 3556 / 1777 / 888 |
| 44 | `M_Upg_Rocket_WaveWall` | 89753932054187 | 89476835119735 | 96395129267148 | (0, 0, 0) | 1264 / 631 / 316 |
| 45 | `M_Upg_Rocket_GoldEagle` | 111488070403076 | 103365893858784 | 72828489661219 | (0, 0, 0) | 1092 / 546 / 272 |
| 46 | `M_Upg_Rocket_RocketFins` | 106023703826777 | 131412785200697 | 100912240225560 | (0, 0, 0) | 468 / 233 / 117 |
| 47 | `M_Upg_Rocket_GoldThrone` | 128702436479651 | 112762629835454 | 70799578237550 | (0, 0, 0) | 1156 / 578 / 288 |
| 48 | `M_Upg_Rocket_PartyCannons` | 81967195572224 | 75544082526325 | 81448421430729 | (0, 0, 0) | 2200 / 1100 / 549 |
| 49 | `M_Upg_Rocket_MegaTrophy` | 103249963169636 | 99899113738703 | 100387496548601 | (0, 0, 0) | 1840 / 919 / 459 |
| 50 | `M_Upg_Rocket_SunBooster` | 109269895430819 | 111346502473744 | 139930463990531 | (0, 0, 0) | 2484 / 1241 / 621 |

Shared palette set (one SurfaceAppearance for all eleven), `T_UpgRocket_Palette_*`, 256 px: ALB 71059489637718, NOR 94365844917813, RGH 114523207797253, MET 104820073034248. Moderation at upload: Approved.

Attachments (each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Veh_RocketCutter: the full Tidewalker set (DriverSeat, EyePoint, PassengerSeat1-3, TowHitch, BowPoint, DriveAttachment, Nav*, Beacon, Searchlight, Prop1-2, Float1-8), SurvivorSlot1-14, plus Flame_Main and NumberPlate_P/S.
- M_Upg_Rocket_SideBoosters: ATT_Flame_P, ATT_Flame_S
- M_Upg_Rocket_WaveWall: ATT_Crest_P, ATT_Crest_S
- M_Upg_Rocket_PartyCannons: ATT_Confetti_P, ATT_Confetti_S
- M_Upg_Rocket_MegaTrophy: ATT_Gleam
- M_Upg_Rocket_SunBooster: ATT_Flame_Sun

## Frame

Concept (x, y, z) to HullRoot: (z, y + 1.5, 10 - x). Bow -Z, 61 long from z -30 to +31.2, 10 wide, keel at hull y -0.9, sea at hull y +1.5 (the concept's y 0, on the red band). Rocket axis at hull y 9.1.

## Checks

validate PASS for all eleven (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `texture sets`, `LOD0 floor`; reasons in `pieces.py`). zfight: 33 exported FBX, 0 visible pairs. Hull, pilot and all nine pieces together at L50, in the source geometry: 0 visible pairs. The FBX scan ran on an earlier export; the three pieces changed since (WaveWall, RocketFins, GoldThrone) each logged `0 visible pairs left` on re-export, but those three were not re-scanned as FBX. Not tried in Studio or in play.

## What the game code must do

1. **Hull:** on `VehicleConfig.RocketCutter` set `model = "M_Veh_RocketCutter"`. `variant("Lifeboat")` then routes it through `buildTidewalkerAsset` with no Builder change. Run `tools/gen_asset_ids.py` after merging the manifest; it reads the attachments from `assets/fbx/<asset>/`, committed here for all eleven.
2. **Size:** set `hullSize = Vector3.new(10, 7.5, 60)`. With the Lifeboat's 51.9, `scaleFor` caps at x1.387 and she shows 85 long; with 60 she caps at x1.2 and shows 73 (61.2 modelled, swim platform and cutwater included), about `MAX_LENGTH`. The concept's own ladder is x1.00 to x1.15.
3. **Pieces:** clone by level (table above), CanCollide off, no `_COL`. `BoatLevels` PIECES still lists the old names for L41-L50, and `tools/blender/names.py` needs `Upg` (only allowed at run time in `pieces.py`).
4. **Pilot, a decision for the owner:** the player sits at `ATT_DriverSeat`, exactly where the concept's pilot rides, and the two would overlap. So the pilot is its own model, `M_Upg_Rocket_Pilot`. Show it only while nobody drives (moored, other players' idle boats), or show it always and hide the driver's avatar. The sheet shows it at every level.
5. **Survivors:** `buildTidewalkerAsset` only places `spec.survivorCapacity` slots and the variant inherits the Lifeboat's 8, so set it to 14 to get all of `ATT_SurvivorSlot1-14` (room is 12 at L41, 14 at L50). Slots 13-14 are on seats that ship in `SunBooster`. Seats sit at z +-3.4 under the rocket's curve: check heads in play.
6. **Camera:** from L44 the chase cam must pull back about x1.25 (used for the sheet's L45 and L50 phone views) or the wave walls and the sun's flame reach the lens.
7. **Sun at L50:** the sun's hub covers the rocket's own nozzle and flame, and the booster flames stop just short of the disc. Nothing needs hiding.
8. **VFX:** flames, lenses and confetti are plain palette colours. Add moving fire and bursts at `ATT_Flame_*`, `ATT_Confetti_*`, `ATT_Crest_*`, `ATT_Gleam`. The poppers fire confetti only.
9. **Number plate:** the concept's per-level digits are not built (one mesh a level is waste). Draw them with a SurfaceGui at `ATT_NumberPlate_P/S`.

## Departures from the concept (art director notes on the other stages)

- Cut as noise: rails, ladder, rivets, windscreen, chevrons, 40 confetti bits, wake bricks and spray. Fewer, bigger windows.
- **Wave Wall:** two sculpted lofted walls sprung from the stern quarters, opaque aqua, not stacked translucent bricks trailing behind. Lower and shorter than the concept, centre lane open.
- **Gold Throne:** low back plus a fat open arch, so the chase cam looks through it at the pilot. The concept's solid back hid him.
- **Side Boosters:** navy with one white band, so the striped rocket stays the hero. Fat wedge pylons, not struts. Flames 10.6 long, not 13.
- **Sun Booster:** a solid beaming face, r 7.2, on a hub cantilevered 5 aft of the transom, blowing the flame out of its mouth, flame shortened from 22 to 10. The concept's ring and centre cone covered the face from behind.
- **Rocket nose:** a toy ball on the tip and a rounded gold cap, instead of the concept's chrome tip and gold spike: never a warhead.
- **Eagle and trophy:** eagle x1.45 with three fat feathers a wing; trophy x1.17 with fat handles, moved to x 24.5 so it clears the eagle.
- **L50 colour:** gold plus red on the navy and white base. Poppers are red and white with red, gold, white and yellow confetti, dropping the concept's pink, blue, green and purple. Aqua water and flame colours remain.

## Open

- A level-50 boat still has nine additions on it: the sun carries the joke from behind, but the three-quarter views are busier. The art director should judge this first.
- Colours were judged only in Blender's flat EEVEE stage, not under the game's lighting. Gold has metalness 0.35 so it stays bright without reflections.
