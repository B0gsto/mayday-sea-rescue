# Lifeboat stage upgrade pieces (L22-L30): result

Concept: artifact cdf29056 (Lifeboat Stage L21-L30). Geometry: `pieces.py` + `kit.py`, one thin `build.py` per piece in `art/source/vessels/M_Upg_Lifeboat_*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session.

The real hull is code-built (`Boat/Builder.luau` `buildLifeboat`), no mesh. `hull_ref.json` is a Lune dump of its 285 visible parts; `hullref.py` rebuilds it in Blender for fitting and the sheet only.

## Ids

Every piece is authored in the hull frame, so its **Model pivot is the hull origin: offset (0, 0, 0)**. `Model:PivotTo(hullRoot.CFrame)`, then scale round that pivot with the hull. Size is x, y, z in studs (Roblox axes).

| Lv | Asset | LOD0 | LOD1 | LOD2 | Offset | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|---|
| 22 | `M_Upg_Lifeboat_ArmourSpikes` | 77212221357585 | 109520468836402 | 132698266667026 | (0, 0, 0) | 28.3 x 3.6 x 42.7 | 3936 / 1967 / 983 |
| 23 | `M_Upg_Lifeboat_HugeLamps` | 88263540853338 | 112469404121613 | 71848872285738 | (0, 0, 0) | 15.3 x 5.1 x 4.6 | 3352 / 1676 / 838 |
| 24 | `M_Upg_Lifeboat_IcePlough` | 88665905900343 | 134477947064567 | 82004459947272 | (0, 0, 0) | 16.3 x 4.8 x 11.5 | 1384 / 691 / 345 |
| 25 | `M_Upg_Lifeboat_RoofRockets` | 113569326306482 | 77391907536198 | 122596495517933 | (0, 0, 0) | 21.5 x 8.2 x 9.8 | 4920 / 2460 / 1230 |
| 26 | `M_Upg_Lifeboat_CrewDeck` | 125743627321516 | 90774527723143 | 105492338758412 | (0, 0, 0) | 14.0 x 8.9 x 13.1 | 3712 / 1856 / 921 |
| 27 | `M_Upg_Lifeboat_LampTower` | 74798337534456 | 128886213781885 | 93544452749167 | (0, 0, 0) | 5.2 x 19.3 x 6.0 | 4140 / 2070 / 1034 |
| 28 | `M_Upg_Lifeboat_FoilLift` | 116386549933926 | 131932847746383 | 137563086708674 | (0, 0, 0) | 22.6 x 7.0 x 31.6 | 2584 / 1292 / 646 |
| 29 | `M_Upg_Lifeboat_RearRockets` | 110817408926748 | 112759170183699 | 72836635022732 | (0, 0, 0) | 17.4 x 6.1 x 12.1 | 4880 / 2440 / 1220 |
| 30 | `M_Upg_Lifeboat_BattleBridge` | 102126261461270 | 102518909442668 | 139853197805700 | (0, 0, 0) | 14.6 x 12.9 x 21.2 | 7820 / 3910 / 1949 |

Shared palette set (one SurfaceAppearance for all nine), `T_UpgLifeboat_Palette_*`, 256 px: ALB 89572818827627, NOR 94365844917813, RGH 128252020870174, MET 134651320857380. Some uploads were still in moderation review when this was written.

Attachments (hull frame, in each `build/prod/<asset>/fbx/<asset>/<asset>.attachments.json`):
- M_Upg_Lifeboat_HugeLamps: ATT_Lens_P, ATT_Lens_S
- M_Upg_Lifeboat_RoofRockets: ATT_Flame_P, ATT_Flame_S
- M_Upg_Lifeboat_LampTower: ATT_Lens_Fwd00, ATT_Lens_Fwd01, ATT_Lens_Aft0, ATT_Lens_Fwd10, ATT_Lens_Fwd11, ATT_Lens_Aft1, ATT_Beacon
- M_Upg_Lifeboat_RearRockets: ATT_Flame_P, ATT_Flame_S
- M_Upg_Lifeboat_BattleBridge: ATT_Lens_SearchP, ATT_Lens_SearchS

## Checks

validate PASS for all nine (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `texture sets`, with reasons in `pieces.py`). zfight: 27 exported FBX, 0 visible pairs. All nine plus the real hull at L30, piece against piece and piece against hull: 0 visible pairs. Not seen in Studio.

## Changed from the concept to fit the real hull

- **Waterline.** The game floats her with the sea at about hull y +1.5 (float points y -3, draft 4.5); the concept drew it at y 0. On the concept's numbers the spikes and plough would sit under water from L22 to L27.
  - Armour Spikes: y 0.2 to 1.3, tilted up 16 degrees, cone radius 1.55 to 1.25, oval base, so the orange band stays clear.
  - Ice Plough: raised 2.4.
- **Flames.** Opaque rounded tongues in three layers. The concept's translucent cones read as warheads when made opaque.
- Bridge roof studs are border only, to stay under 8,000 tris. Puffs and flag detail reduced.
- Tris: 36,728 for all nine LOD0 together.

## What the game code must do

1. **L30:** raise the hull's mast group +6.5 (`MastBase Mast MastTop Yard RadarPedestal Radar NavMasthead Antenna* BeaconBase Beacon`) and hide `Stay*`, or they go through the Battle Bridge.
2. **L28+:** raise the boat so the sea sits at hull y -3.55: about **+5.05** from the game's float height. The concept's "3.55" assumes its sea at y 0.
3. **Glow:** lenses and flames are plain palette colours. Add the halo, Neon or PointLight and any flame VFX at `ATT_Lens_*`, `ATT_Flame_*` and `ATT_Beacon`.
4. Set CanCollide off; there is no `_COL`.
5. Add `M_Upg_*` to `tools/blender/names.py` (`Upg` is only allowed at run time in `pieces.py`) and run `tools/gen_asset_ids.py` when wiring.

## Open

- The concept's L21 "Big Lifeboat" dress (forepeak block, gunwale plates, rub rails, fenders, bow bumper) and the crew figures are not built: they were not in the nine. The bare hull stands for L21 on the sheet.
- Crew Deck pillars at x +-4.4 stand near survivor slots at x +-3.4 (z 7.5+). Check for overlap in play.
- `BoatLevels` PIECES still lists the old names for L21-L30 (Armour plates, Huge lamps, ...).
- Sheet: `build/status/2026-11-04/art/lifeboat.png`, no art director score yet.
