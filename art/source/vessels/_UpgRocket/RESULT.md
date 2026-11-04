# Rocket Cutter stage (L41-L50): result

Must-fix round 4 (art director: 6.5, 6.5, then 6 with a weapon read), no score yet for this round. Earlier uploads are superseded: use only the ids below. Concept: artifact b8ff43b0 (Rocket Cutter). Geometry: `pieces.py` + `kit.py` (the Lifeboat stage's Kit with this stage's palette), one thin `build.py` per asset in `art/source/vessels/M_Veh_RocketCutter` and `M_Upg_Rocket_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `build/status/2026-11-04/art/rocket.png` (`sheet_scene.shoot_all()`, then `compose_sheet.py`).

## Ids

The hull's pivot sits where `Boat/Builder buildTidewalkerAsset` expects a Lifeboat-frame model (`Builder.TIDEWALKER_ORIGIN`), so the offset is already applied by that builder. Every other row is authored in HullRoot space: **offset (0, 0, 0)**, `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull, as on the Lifeboat stage.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 41 | `M_Veh_RocketCutter` | 86089306993522 | 90447951229913 | 139103986519780 | (0, -2.8, -0.01) | 8200 / 2869 / 755 |
| 41 | `M_Upg_Rocket_Pilot` | 81220112774551 | 137462181212603 | 91917804999377 | (0, 0, 0) | 1148 / 574 / 283 |
| 42 | `M_Upg_Rocket_SideBoosters` | 104513650289925 | 120391320810160 | 111592996617029 | (0, 0, 0) | 1200 / 600 / 300 |
| 43 | `M_Upg_Rocket_GoldPlating` | 115926568558094 | 126198174542503 | 111582219800188 | (0, 0, 0) | 1428 / 714 / 356 |
| 44 | `M_Upg_Rocket_WaveWall` | 118737985030439 | 102680468010463 | 81258890500728 | (0, 0, 0) | 632 / 316 / 157 |
| 45 | `M_Upg_Rocket_GoldEagle` | 99148932852036 | 118159762170603 | 124749591160623 | (0, 0, 0) | 800 / 400 / 200 |
| 46 | `M_Upg_Rocket_RocketFins` | 103439120103218 | 102375826484490 | 76730767855285 | (0, 0, 0) | 96 / 48 / 24 |
| 47 | `M_Upg_Rocket_GoldThrone` | 108333987489035 | 115000514528355 | 134323702883700 | (0, 0, 0) | 548 / 274 / 136 |
| 48 | `M_Upg_Rocket_PartyCannons` | 136029341225940 | 94568099872908 | 78960310754441 | (0, 0, 0) | 2480 / 1240 / 620 |
| 49 | `M_Upg_Rocket_MegaTrophy` | 120582387257646 | 108670364922524 | 72716603627128 | (0, 0, 0) | 964 / 482 / 240 |
| 50 | `M_Upg_Rocket_SunBooster` | 76366722386053 | 78244750359958 | 94666774660866 | (0, 0, 0) | 1732 / 866 / 432 |

Shared palette set (one SurfaceAppearance for all eleven), `T_UpgRocket_Palette_*`, 256 px: ALB 101967041086669, NOR 94365844917813, RGH 117753746694610, MET 104820073034248. Moderation at upload: Approved.

Attachments (each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Veh_RocketCutter: the full Tidewalker set (DriverSeat, EyePoint, PassengerSeat1-3, TowHitch, BowPoint, DriveAttachment, Nav*, Beacon, Searchlight, Prop1-2, Float1-8), SurvivorSlot1-14, plus Flame_Main and NumberPlate_P/S.
- M_Upg_Rocket_SideBoosters: ATT_Flame_P, ATT_Flame_S
- M_Upg_Rocket_WaveWall: ATT_Crest_P, ATT_Crest_S
- M_Upg_Rocket_PartyCannons: ATT_Confetti_P, ATT_Confetti_S
- M_Upg_Rocket_MegaTrophy: ATT_Gleam
- M_Upg_Rocket_SunBooster: ATT_Flame_Sun

## Frame

Concept (x, y, z) to HullRoot: (z, y + 1.5, 10 - x). Bow -Z, 61 long from z -30 to +31.2, 18 wide (half beam 9), keel at hull y -0.9, sea at hull y +1.5 (on the red band). The egg: axis at hull y 12.9, half height 9, half width 9.8, 32 long, centred at concept x -1. Overall at x1.2: 29.6 from the sea to the rider's helmet, 40 wide across the poppers, 34 across the wave flares.

## Checks

validate PASS for all eleven (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `texture sets`, `LOD0 floor`; reasons in `pieces.py`). zfight: all 33 exported FBX scanned, 0 visible pairs. Hull, pilot and all nine pieces together at L50, in the source geometry: 0 visible pairs. Not tried in Studio or in play.

## What the game code must do

1. **Hull:** on `VehicleConfig.RocketCutter` set `model = "M_Veh_RocketCutter"`. `variant("Lifeboat")` then routes it through `buildTidewalkerAsset` with no Builder change. Run `tools/gen_asset_ids.py` after merging the manifest; it reads the attachments from `assets/fbx/<asset>/`, committed here for all eleven.
2. **Size:** set `hullSize = Vector3.new(18, 7.5, 60)`. With the Lifeboat's 51.9, `scaleFor` caps at x1.387 and she shows 85 long; with 60 she caps at x1.2 and shows 73, about `MAX_LENGTH`. The collision box grows with it: the hull is now 18 wide.
3. **Pieces:** clone by level (table above), CanCollide off, no `_COL`. `BoatLevels` PIECES still lists the old names for L41-L50, and `tools/blender/names.py` needs `Upg` (only allowed at run time in `pieces.py`).
4. **Pilot (decided):** the player rides the ride. `ATT_DriverSeat` is in the cockpit, where the sheet shows the pilot: model (0, 22.6, 9.01), HullRoot (0, 19.8, 9.0). Keep `M_Upg_Rocket_Pilot` hidden while a player is seated; show it only on an empty boat. The seat is inside the egg mesh, so the rider's legs are hidden: the egg must stay CanCollide off, and the climb-on and exit need checking in play.
5. **Survivors:** `buildTidewalkerAsset` only places `spec.survivorCapacity` slots and the variant inherits the Lifeboat's 8, so set it to 14 to get all of `ATT_SurvivorSlot1-14` (room is 12 at L41, 14 at L50). The twelve seats are now in the open on the foredeck, clear of the egg; slots 13-14 are on seats that ship in `SunBooster`, beside her nose.
6. **Camera:** the sheet's phone views use about x1.15 pull-back from L41.
7. **Sun at L50:** the disc stands right behind the transom on a short hub that hides the tail puff. Nothing needs hiding in code.
8. **VFX:** puffs and confetti are plain palette colours. Keep any exhaust VFX at `ATT_Flame_*` soft and round: a long pointed flame brings the weapon read back. Bursts at `ATT_Confetti_*`, spray at `ATT_Crest_*`, sparkle at `ATT_Gleam`. The poppers fire confetti only.
9. **Number plate:** the concept's per-level digits are not built (one mesh a level is waste). Draw them with a SurfaceGui at `ATT_NumberPlate_P/S`.

## Must-fix changes (art director: weapon read)

- **The ride:** a squat round egg, 32 long by 18 tall by 19.6 wide, sunk in the deck like a fairground ride. Round at both ends. No cradle, no saddles, no tail cone. Porthole face on the nose, four big windows, chunky rounded red side fins.
- **Side tube deleted:** Side Boosters are now two red and white beach-ball pods on studded plates on the aft deck, with soft puffs.
- **Exhaust:** every cone is gone. A short navy ring on her tail and a soft cloud of round puffs.
- **L50 stern:** one big plain round sun face, radius 9.8 with its rim, across the stern. No spikes, no flame, eyes, cheeks and a grin. Rider's head and the cockpit stay above it.
- **Deck widened:** half beam 5 to 9, so she stands on the boat. The knife is wider too.
- **Wave Wall:** the hull flaring out, with the same navy, red and white courses at the same heights, a continuous waterline and an aqua scoop on top. Low.
- **Party Cannons:** moved amidships to the deck edge, mouths up and out over the side, well clear of the stern.
- **Rocket Fins:** one chunky rounded dorsal fin. Eagle and trophy stay small on the prow.

## Departures from the concept

The hull's courses, red prow and chrome cutwater survive. Otherwise this is a long way from the owner-cleared concept, on the art director's weapon-read note, and the owner has not seen it:
- **Rocket:** an egg, not the concept's Ø7 x 36 tube "twice too big". She reads as a ride, no longer strictly a rocket: the name "Rocket Cutter" now leans on the fins and portholes.
- **Hull:** 18 wide, not 10. The prow reaches 25 past her nose, not 17.
- **Seats:** on the foredeck, not along the cockpit, and navy, not yellow.
- **Cut:** rails, ladder, rivets, windscreen, chevrons, 40 confetti bits, wake bricks and spray, booster tubes, flames, rays.
- **Mega Trophy:** small, by art director request. Its name oversells it.
- **L50 colour:** gold plus red on the navy and white base. Sun orange and aqua remain. Poppers are red and white with red, gold, white and yellow bits, dropping the concept's pink, blue, green and purple.

## Open

- The owner should see this round: it moves away from the cleared concept.
- At L50 the sun hides most of the ride from dead behind: the rider's head and shoulders stay above it, and the poppers show only as the camera swings. Check in play that the rider still reads.
- Width: check the Upgrade Station bay (40 across the poppers in play).
- Weapon-read check is mine, from the sheet's side, rear and phone views: I saw no missile, torpedo, launcher or warhead, but the art director has not scored it.
- Colours were judged only in Blender's flat EEVEE stage, not under the game's lighting. Not tried in Studio or in play.
