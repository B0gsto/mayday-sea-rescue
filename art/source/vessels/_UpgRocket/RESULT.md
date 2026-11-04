# Rocket Cutter stage (L41-L50): result

Round 3, the last (art director round 1: 6.5, round 2: 6.5), no score yet for this round. Earlier uploads are superseded: use only the ids below. Concept: artifact b8ff43b0 (Rocket Cutter). Geometry: `pieces.py` + `kit.py` (the Lifeboat stage's Kit with this stage's palette), one thin `build.py` per asset in `art/source/vessels/M_Veh_RocketCutter` and `M_Upg_Rocket_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `build/status/2026-11-04/art/rocket.png` (`sheet_scene.shoot_all()`, then `compose_sheet.py`).

## Ids

The hull's pivot sits where `Boat/Builder buildTidewalkerAsset` expects a Lifeboat-frame model (`Builder.TIDEWALKER_ORIGIN`), so the offset is already applied by that builder. Every other row is authored in HullRoot space: **offset (0, 0, 0)**, `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull, as on the Lifeboat stage.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 41 | `M_Veh_RocketCutter` | 74149292921338 | 73604106048553 | 125220251035692 | (0, -2.8, -0.01) | 8704 / 3046 / 811 |
| 41 | `M_Upg_Rocket_Pilot` | 87798816093621 | 132482248139712 | 138494977558877 | (0, 0, 0) | 1148 / 574 / 283 |
| 42 | `M_Upg_Rocket_SideBoosters` | 111530578916057 | 97478482503356 | 83831462402641 | (0, 0, 0) | 1800 / 899 / 449 |
| 43 | `M_Upg_Rocket_GoldPlating` | 130499514041522 | 127130601967278 | 78522651833113 | (0, 0, 0) | 2212 / 1106 / 553 |
| 44 | `M_Upg_Rocket_WaveWall` | 138802809245316 | 75574607084451 | 107113494866346 | (0, 0, 0) | 736 / 368 / 184 |
| 45 | `M_Upg_Rocket_GoldEagle` | 99148932852036 | 118159762170603 | 124749591160623 | (0, 0, 0) | 800 / 400 / 200 |
| 46 | `M_Upg_Rocket_RocketFins` | 85398662286706 | 128889980047214 | 124943364500892 | (0, 0, 0) | 156 / 78 / 38 |
| 47 | `M_Upg_Rocket_GoldThrone` | 82529215173211 | 95024192342762 | 93103764184258 | (0, 0, 0) | 548 / 274 / 136 |
| 48 | `M_Upg_Rocket_PartyCannons` | 138186028299617 | 136274778631418 | 110189240521218 | (0, 0, 0) | 2612 / 1306 / 652 |
| 49 | `M_Upg_Rocket_MegaTrophy` | 120582387257646 | 108670364922524 | 72716603627128 | (0, 0, 0) | 964 / 482 / 240 |
| 50 | `M_Upg_Rocket_SunBooster` | 78839605384675 | 136564388311616 | 94094794022104 | (0, 0, 0) | 1284 / 641 / 321 |

Shared palette set (one SurfaceAppearance for all eleven), `T_UpgRocket_Palette_*`, 256 px: ALB 101967041086669, NOR 94365844917813, RGH 117753746694610, MET 104820073034248. Moderation at upload: Approved.

Attachments (each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Veh_RocketCutter: the full Tidewalker set (DriverSeat, EyePoint, PassengerSeat1-3, TowHitch, BowPoint, DriveAttachment, Nav*, Beacon, Searchlight, Prop1-2, Float1-8), SurvivorSlot1-14, plus Flame_Main and NumberPlate_P/S.
- M_Upg_Rocket_SideBoosters: ATT_Flame_P, ATT_Flame_S
- M_Upg_Rocket_WaveWall: ATT_Crest_P, ATT_Crest_S
- M_Upg_Rocket_PartyCannons: ATT_Confetti_P, ATT_Confetti_S
- M_Upg_Rocket_MegaTrophy: ATT_Gleam
- M_Upg_Rocket_SunBooster: ATT_Flame_Sun

## Frame

Concept (x, y, z) to HullRoot: (z, y + 1.5, 10 - x). Bow -Z, 61 long from z -30 to +31.2, 10 wide, keel at hull y -0.9, sea at hull y +1.5 (the concept's y 0, on the red band). Rocket axis at hull y 13.4, half height 7, half width 9.8, fattest at concept x 3. Overall: 28 tall from the sea to the rider's helmet at x1.2 (23.3 unscaled), 46 wide across the poppers at x1.2.

## Checks

validate PASS for all eleven (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `texture sets`, `LOD0 floor`; reasons in `pieces.py`). zfight: all 33 exported FBX scanned, 0 visible pairs. Hull, pilot and all nine pieces together at L50, in the source geometry: 0 visible pairs. Not tried in Studio or in play.

## What the game code must do

1. **Hull:** on `VehicleConfig.RocketCutter` set `model = "M_Veh_RocketCutter"`. `variant("Lifeboat")` then routes it through `buildTidewalkerAsset` with no Builder change. Run `tools/gen_asset_ids.py` after merging the manifest; it reads the attachments from `assets/fbx/<asset>/`, committed here for all eleven.
2. **Size:** set `hullSize = Vector3.new(10, 7.5, 60)`. With the Lifeboat's 51.9, `scaleFor` caps at x1.387 and she shows 85 long; with 60 she caps at x1.2 and shows 73 (61.2 modelled, swim platform and cutwater included), about `MAX_LENGTH`. The concept's own ladder is x1.00 to x1.15.
3. **Pieces:** clone by level (table above), CanCollide off, no `_COL`. `BoatLevels` PIECES still lists the old names for L41-L50, and `tools/blender/names.py` needs `Upg` (only allowed at run time in `pieces.py`).
4. **Pilot (decided):** the player rides the rocket. `ATT_DriverSeat` is in the cockpit, where the sheet shows the pilot: model (0, 21.2, 7.01), HullRoot (0, 18.4, 7.0). Keep `M_Upg_Rocket_Pilot` hidden while a player is seated; show it only on an empty boat. The seat is inside the rocket mesh: the rider's legs are meant to be hidden, so the rocket must stay CanCollide off, and the climb-on and exit need checking in play.
5. **Survivors:** `buildTidewalkerAsset` only places `spec.survivorCapacity` slots and the variant inherits the Lifeboat's 8, so set it to 14 to get all of `ATT_SurvivorSlot1-14` (room is 12 at L41, 14 at L50). Slots 13-14 are on seats that ship in `SunBooster`. Seats sit at z +-3.4 under the rocket's belly (y about 5.3 at that z), so seated survivors' heads will be inside it. Decide in play: hide them, or move the slots.
6. **Camera:** the chase cam needs about x1.15 pull-back from L41, used for all the sheet's phone views: the rocket is wide.
7. **Sun at L50:** the disc sits flush on the tail with the nozzle through it. Its bigger flame encloses the hull's. Nothing needs hiding.
8. **VFX:** flames, lenses and confetti are plain palette colours. Add moving fire and bursts at `ATT_Flame_*`, `ATT_Confetti_*`, `ATT_Crest_*`, `ATT_Gleam`. The poppers fire confetti only.
9. **Number plate:** the concept's per-level digits are not built (one mesh a level is waste). Draw them with a SurfaceGui at `ATT_NumberPlate_P/S`.

## Round 3 changes (art director 6.5/10 twice)

- **Rocket:** one chubby egg, width doubled (half width 9.8) but height only x1.43 (half height 7), so girth is about x1.7 rather than a literal x2: a true x2 would stand about 35 tall in play. A legs-in cockpit keeps the rider's helmet near the old height. Stubby red side fins on the hull, a porthole face on the nose (two eyes, a smile), big side portholes.
- **Side Boosters:** no tubes or points. Stubby navy drums with blunt white caps and wide flared mouths at the back, hugging the belly on a studded bracket.
- **Party Cannons:** big wide-mouth cones, dark open mouth, white rim, a small burst in the centre, one fat streamer. x1.25, mouths up, out and slightly aft.
- **Sun Booster:** spikes and shaft gone. A plain round disc flush on the tail, the nozzle through it as its nose, eyes and a grin. Bigger flame.
- **Wave Wall:** grown out of the hull: the inner edge is the hull's side from amidships, sweeping out and up to the crest, peeling open only past the stern. One silhouette from behind.
- **Accents off the silhouette:** trophy and eagle are small on the prow, under the nose line, hidden from behind. Throne is a gold cockpit collar and a low back. Rocket Fins are one dorsal fin plus white tips on the side fins.
- **Calmer:** seats navy, gold caps studless, three gold rings, a small gold nose tip. Rider moved aft to amidships (x 3) so the chase camera sees him.

## Departures from the concept

- **Hull kept:** the 60 x 10 knife, five raked courses, red prow, chrome cutwater. Its deck is now mostly under the rocket, and the prow reaches 9 past the nose, not 17.
- **Rocket:** an oval egg, not the concept's round Ø7 x 36 tube; a toy-rounded nose, not a chrome tip and gold spike.
- **Cut as noise:** rails, ladder, rivets, windscreen, chevrons, 40 confetti bits, wake bricks and spray, the throne arch.
- **Mega Trophy:** by far smaller than the concept, by art director request. Its name oversells it.
- **L50 colour:** gold plus red on the navy and white base. Poppers are red and white with red, gold, white and yellow bits, dropping the concept's pink, blue, green and purple. Aqua water, sun orange and flame colours remain.

## Open

- Survivor heads clip the rocket's belly (step 5).
- Width: 46 across the poppers and 42 across the wave walls in play; 28 tall. Check the Upgrade Station bay (same clearance problem as the Lifeboat stage, worse here).
- From behind the rider is small: a head and shoulders above the rocket. The real avatar has not been tried in the seat.
- Colours were judged only in Blender's flat EEVEE stage, not under the game's lighting.
