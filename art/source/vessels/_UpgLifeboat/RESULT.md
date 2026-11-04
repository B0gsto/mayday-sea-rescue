# Lifeboat stage upgrade pieces (L22-L30): result

Round 3 plus the owner's must-fix (art director round 1: 6.5, round 2: 6.8). Earlier uploads are superseded: use only the ids below.

**Owner must-fix:** the red and white pods read as missiles, so Roof Rockets and Rear Rockets are now fat, stubby jets: an open round intake with a fan at the front, a white barrel with two orange straps, no fins, no red, a round steel nozzle. Checked from front, side, rear and top, and on the sheet.

Concept: artifact cdf29056 (Lifeboat Stage L21-L30). Geometry: `pieces.py` + `kit.py`, one thin `build.py` per piece in `art/source/vessels/M_Upg_Lifeboat_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session.

The real hull is code-built (`Boat/Builder.luau` `buildLifeboat`), no mesh. `hull_ref.json` is a Lune dump of its 285 visible parts; `hullref.py` rebuilds it in Blender for fitting and the sheet only.

## Ids

Every piece is authored in the hull frame, so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull. Size is x, y, z in studs (Roblox axes).

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|
| 22 | `M_Upg_Lifeboat_ArmourSpikes` | 112869722359701 | 137875265342819 | 115478240901078 | (0, 0, 0) | 22.0 x 5.0 x 32.8 | 2688 / 1344 / 672 |
| 23 | `M_Upg_Lifeboat_HugeLamps` | 132796952947238 | 86298350592596 | 97853221518398 | (0, 0, 0) | 22.8 x 9.3 x 9.0 | 3608 / 1804 / 901 |
| 24 | `M_Upg_Lifeboat_IcePlough` | 133011600636144 | 70628583672584 | 138003845296622 | (0, 0, 0) | 14.0 x 8.3 x 11.8 | 484 / 241 / 119 |
| 25 | `M_Upg_Lifeboat_RoofRockets` | 121941315525269 | 78100804322744 | 79144608623602 | (0, 0, 0) | 22.2 x 4.8 x 10.9 | 2888 / 1443 / 722 |
| 26 | `M_Upg_Lifeboat_CrewDeck` | 108175690128509 | 102864375929530 | 103827266836753 | (0, 0, 0) | 14.3 x 8.6 x 12.8 | 2336 / 1168 / 584 |
| 27 | `M_Upg_Lifeboat_LampTower` | 78395993993927 | 83282160499949 | 88968642835599 | (0, 0, 0) | 11.0 x 38.6 x 9.0 | 2528 / 1263 / 631 |
| 28 | `M_Upg_Lifeboat_FoilLift` | 121211729729671 | 131319050050328 | 96860785930283 | (0, 0, 0) | 19.6 x 7.4 x 47.5 | 2328 / 1163 / 581 |
| 29 | `M_Upg_Lifeboat_RearRockets` | 82795582429853 | 109358409832307 | 136992668424250 | (0, 0, 0) | 26.1 x 8.2 x 18.2 | 3576 / 1788 / 894 |
| 30 | `M_Upg_Lifeboat_BattleBridge` | 106128335315585 | 102367920176621 | 70516478531009 | (0, 0, 0) | 13.2 x 7.6 x 18.4 | 1364 / 681 / 340 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgLifeboat_Palette_*`, 256 px: ALB 89572818827627, NOR 94365844917813, RGH 128252020870174, MET 134651320857380. Moderation states at upload: Approved.

Attachments (hull frame, in each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Upg_Lifeboat_HugeLamps: ATT_Lens_P, ATT_Lens_S
- M_Upg_Lifeboat_RoofRockets: ATT_Flame_P, ATT_Flame_S
- M_Upg_Lifeboat_LampTower: ATT_Lens_Fwd, ATT_Lens_Aft, ATT_Beacon
- M_Upg_Lifeboat_RearRockets: ATT_Flame_P, ATT_Flame_S

## Checks

validate PASS for all nine (waived where they fail: `_COL proxy`, `LOD UV layout`, `UV faces`, `LOD0 floor` on the plough; reasons in `pieces.py`). zfight: 27 exported FBX, 0 visible pairs. All nine plus the real hull at L30, piece against piece and piece against hull: 0 visible pairs. All nine LOD0 together: 21800 tris. Not seen in Studio.

## Bay fit: the boat does not fit, and the pieces cannot fix that

The lifeboat's look scale is capped at **x1.387** (`BoatLevels.scaleFor`: `MAX_LENGTH` 72 / hull 51.9). Upgrade Station bay: 24 wide (22.7 between fenders), 30 long, clear height 16.9 over the middle 10 and 13.15 across the full 24.

| In the game, at x1.387 | Half-width or reach | Height above hull origin | Against the bay |
|---|---|---|---|
| Bare hull | beam +-12.3, 72 long | mast 25 | Already over: wider, 42 too long, taller than the hoist rail |
| Armour Spikes, was +-18 hull frame (+-25), now +-11.0 | +-15.3 | low | 3.3 past the bay edge |
| Foil Lift skis, was +-11.8, now +-9.8 | +-13.6 | low | 1.6 past the bay edge |
| Ice Plough, was z -34, now z -31.1 | z -43 | 8 | Points out to open sea (`ATT_BoatLanding` looks -Z), so no clash |
| Huge Lamps, Rear Rockets | +-15.8, +-18.1 | above the piers | Clear of the low piers; over the clear height |
| Lamp Tower | | 67 | Far over the hoist rail |

Pieces have CanCollide off, so this is visual clipping only. **Open decision for the integration:** reduce the look scale at the station, land L21+ further out, or widen the bay. Spikes and skis were shrunk as far as they can go and still read.

## Round 3 changes (still in place)

- **Hero masses:** Lamp Tower, Rear Rockets and Huge Lamps. Cut as small clutter: searchlights, horns, flags, bridge wings, roof parapets and walkway walls (Battle Bridge); ladder and life rafts (Crew Deck); six small tower lamps (now one big drum).
- **Battle Bridge:** one brick mass, joined by a solid block to the tower's plinth.
- **Lamp Tower:** three-step plinth, a 6.2-wide base, five broad bands, top y 48.
- **Rear Rockets:** moved out to x +-8 and splayed 11 degrees, with a clear gap at the centre. Flames are 30% longer and orange. The stern view was checked on the phone render.
- **Ice Plough:** one chunky orange toy bumper in three courses, with one dark rubber strip and big studs.
- **Colour:** no red anywhere. Yellow only on the Huge Lamps. Skis are orange on white struts, overriding round 1's yellow.
- **Studs:** big studs (1.3 across) on the walls, plinth, skis, plough and roofs.
- **Spikes:** three a side, white, swept 62 degrees aft along the hull.
- **Bug fixed:** a wrong Euler order meant the concept's yawed spikes never yawed; `kit.rot_m` now matches three.js.

## What the game code must do

1. **L23+:** hide the hull's `Stay*`; they would cut the huge lamps.
2. **L30:** raise the hull's mast group **+7.2** (`MastBase Mast MastTop Yard RadarPedestal Radar NavMasthead Antenna* BeaconBase Beacon`), or it goes through the Battle Bridge.
3. **L28+:** raise the boat so the sea sits at hull y -6.6, with the skis riding on the water: about **+8.1** from the game's float height (sea at hull y +1.5).
4. **Camera:** from L27 the chase cam must pull back about x1.45 (used for the sheet's phone view) or the tower leaves the frame.
5. **Glow:** lenses and flames are plain palette colours. Add the halo, Neon or PointLight and any flame VFX at `ATT_Lens_*`, `ATT_Flame_*` and `ATT_Beacon`.
6. Set CanCollide off; there is no `_COL`.
7. Add `M_Upg_*` to `tools/blender/names.py` (`Upg` is only allowed at run time in `pieces.py`) and run `tools/gen_asset_ids.py` when wiring.

## Open

- The concept's L21 "Big Lifeboat" dress (forepeak block, gunwale plates, rub rails, fenders, bow bumper) and the crew figures are not built: they were not in the nine. The bare hull stands for L21 on the sheet.
- Crew Deck columns moved to x +-5.6 (radius 1.3); survivors at x +-3.4 may still brush them. Check in play.
- `BoatLevels` PIECES still lists the old names for L21-L30.
- Sheet: `build/status/2026-11-04/art/lifeboat.png`, round 3, no art director score yet.
