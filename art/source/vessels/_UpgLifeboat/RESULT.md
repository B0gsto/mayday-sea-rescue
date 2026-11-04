# Lifeboat stage upgrade pieces (L22-L30): result

Round 2 (art director round 1: 6.5/10). Earlier uploads are superseded: use only the ids below.

Concept: artifact cdf29056 (Lifeboat Stage L21-L30). Geometry: `pieces.py` + `kit.py`, one thin `build.py` per piece in `art/source/vessels/M_Upg_Lifeboat_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session.

The real hull is code-built (`Boat/Builder.luau` `buildLifeboat`), no mesh. `hull_ref.json` is a Lune dump of its 285 visible parts; `hullref.py` rebuilds it in Blender for fitting and the sheet only.

## Ids

Every piece is authored in the hull frame, so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull. Size is x, y, z in studs (Roblox axes).

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|
| 22 | `M_Upg_Lifeboat_ArmourSpikes` | 133164090127949 | 114330785980157 | 121231757896755 | (0, 0, 0) | 34.5 x 6.7 x 45.1 | 3936 / 1968 / 984 |
| 23 | `M_Upg_Lifeboat_HugeLamps` | 122474226274027 | 98964886352809 | 75013523330703 | (0, 0, 0) | 22.8 x 9.3 x 9.0 | 4152 / 2076 / 1038 |
| 24 | `M_Upg_Lifeboat_IcePlough` | 109492128290297 | 117293282926229 | 113357296528944 | (0, 0, 0) | 16.9 x 10.8 x 14.3 | 2928 / 1463 / 731 |
| 25 | `M_Upg_Lifeboat_RoofRockets` | 120497757007102 | 72167353518251 | 93367318370611 | (0, 0, 0) | 24.8 x 5.7 x 12.6 | 4128 / 2064 / 1032 |
| 26 | `M_Upg_Lifeboat_CrewDeck` | 75197320314889 | 126567618142194 | 86167308317301 | (0, 0, 0) | 14.7 x 10.1 x 14.2 | 4748 / 2374 / 1186 |
| 27 | `M_Upg_Lifeboat_LampTower` | 126192327568523 | 79697891930731 | 86727100366243 | (0, 0, 0) | 8.6 x 41.0 x 8.6 | 5152 / 2576 / 1287 |
| 28 | `M_Upg_Lifeboat_FoilLift` | 132726935816721 | 119863301031155 | 82997528729563 | (0, 0, 0) | 23.6 x 7.4 x 47.5 | 2568 / 1284 / 642 |
| 29 | `M_Upg_Lifeboat_RearRockets` | 91036606228980 | 136153216298036 | 77982688319839 | (0, 0, 0) | 22.9 x 10.6 x 21.9 | 5152 / 2575 / 1288 |
| 30 | `M_Upg_Lifeboat_BattleBridge` | 86622053201289 | 108501137050309 | 122107978990948 | (0, 0, 0) | 15.1 x 14.3 x 22.4 | 6586 / 3293 / 1645 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgLifeboat_Palette_*`, 256 px: ALB 89572818827627, NOR 94365844917813, RGH 128252020870174, MET 134651320857380. Moderation states at upload: Approved.

Attachments (hull frame, in each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Upg_Lifeboat_HugeLamps: ATT_Lens_P, ATT_Lens_S
- M_Upg_Lifeboat_RoofRockets: ATT_Flame_P, ATT_Flame_S
- M_Upg_Lifeboat_LampTower: ATT_Lens_Fwd00, ATT_Lens_Fwd01, ATT_Lens_Aft0, ATT_Lens_Fwd10, ATT_Lens_Fwd11, ATT_Lens_Aft1, ATT_Beacon
- M_Upg_Lifeboat_RearRockets: ATT_Flame_P, ATT_Flame_S
- M_Upg_Lifeboat_BattleBridge: ATT_Lens_SearchP, ATT_Lens_SearchS

## Checks

validate PASS for all nine (waived where they fail: `_COL proxy`, `LOD UV layout`, `UV faces`; reasons in `pieces.py`). zfight: 27 exported FBX, 0 visible pairs. All nine plus the real hull at L30, piece against piece and piece against hull: 0 visible pairs. All nine LOD0 together: 39350 tris. Not seen in Studio.

## Round 2 changes (these go past the concept on the art director's order)

- **Lamp Tower:** twice the height (top y about 50), a fat stacked orange and white brick column, a big yellow lamp head.
- **Huge Lamps:** radius 1.9 to 3.8, at x +-5.6, z -15. They overhang the cabin sides.
- **Rear Rockets:** radius 3.4, as thick as the hull is deep.
- **Roof Rockets:** radius 1.35 to 1.8.
- **Crew Deck and Battle Bridge:** rails, posts and stilts replaced by two-course brick walls and fat columns. The ladder moved to the centre line with chunky rungs. The bridge is wider and its roof top is now y 15.8.
- **Foil Lift:** two wide yellow water-skis (x +-9, 5.6 wide, y -7 to -5.8) on thick struts, with a cross bar under the keel. The concept's swept foils are gone.
- **Ice Plough:** a wedge that steps up block by block to the nose, with white saw teeth and a rounded white nose.
- **Armour Spikes:** white, cone radius 2.2, 9 long, tilted up 20 degrees from y 0.6. Their roots stay under the orange band.
- **Colour:** lamps are yellow. Rockets are red with white bands, a white dome and a rounded flame, so they read as fireworks.

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
- Crew Deck columns (x +-4.4, radius 1.3) stand in the survivor slots at x +-3.4 (z 7.5+). Move the slots or check in play.
- The Spikes reach x about +-18 and the Plough z about -34: check the bay fit against `BoatLevels.MAX_LENGTH` and the Go back landing.
- `BoatLevels` PIECES still lists the old names for L21-L30.
- Sheet: `build/status/2026-11-04/art/lifeboat.png`, round 2, no art director score yet.
