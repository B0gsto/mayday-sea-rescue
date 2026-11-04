# Hydrofoil stage (L31-L40): result

Round 1, no art director score yet. Concept: artifact f23406cb (Hydrofoil Boat Concept). Geometry: `pieces.py` on `hk.py` (the Lifeboat kit plus this palette), one thin `build.py` per asset in `art/source/vessels/M_*Hydrofoil*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `sheet_scene.shoot(level)`, `compose_sheet.py`.

## Ids

Size is x, y, z in studs (Roblox axes), before the game's scale (x1.92 at L31, x2.19 at L40).

| Lv | Asset | LOD0 | LOD1 | LOD2 | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 31 | `M_Veh_Hydrofoil` | 81401917998062 | 138121969645766 | 128313763321836 | 24.8 x 13.0 x 25.1 | 5200 / 1782 / 443 |
| 32 | `M_Upg_Hydrofoil_GiantJets` | 129505964348851 | 129924183503539 | 101376693882178 | 21.3 x 6.5 x 8.1 | 3432 / 1716 / 858 |
| 33 | `M_Upg_Hydrofoil_TTail` | 98980340312682 | 117556525638460 | 94543051402572 | 16.5 x 14.0 x 9.4 | 552 / 275 / 138 |
| 34 | `M_Upg_Hydrofoil_SkyStilts` | 109612626955715 | 105717029051954 | 122562957670873 | 9.6 x 4.9 x 16.0 | 704 / 352 / 176 |
| 35 | `M_Upg_Hydrofoil_NeedleNose` | 137789152598576 | 139985226037024 | 132091641025304 | 3.7 x 2.6 x 17.3 | 568 / 284 / 142 |
| 36 | `M_Upg_Hydrofoil_SkyWings` | 124589540275713 | 132937043684442 | 135462466921517 | 25.4 x 2.8 x 6.0 | 400 / 200 / 99 |
| 37 | `M_Upg_Hydrofoil_Afterburners` | 123216469847524 | 80822599718932 | 70460845277185 | 20.7 x 6.1 x 8.1 | 2280 / 1140 / 570 |
| 38 | `M_Upg_Hydrofoil_RadarDish` | 79654248038286 | 136661135975722 | 125167626460048 | 5.8 x 5.5 x 4.8 | 648 / 324 / 162 |
| 39 | `M_Upg_Hydrofoil_TopJet` | 98413738805279 | 79248743221523 | 118991431068378 | 5.3 x 3.9 x 10.6 | 2468 / 1234 / 616 |
| 40 | `M_Upg_Hydrofoil_TurboHalo` | 120845420969407 | 95490018314160 | 130524048427803 | 10.1 x 4.8 x 10.1 | 1008 / 503 / 252 |

Shared palette (one SurfaceAppearance for all ten), `T_UpgHydrofoil_Palette_*`, 256 px: ALB 119894043403469 and RGH 117446448784696 (both Reviewing at upload), MET 74132887490056, NOR 94365844917813 (the Lifeboat's flat normal, same file). All meshes Approved at upload. L40 all LOD0 together: 17260 tris.

## Offsets

The hull and every piece share one frame and one pivot: the RIB asset's frame (`Builder.RIB_ORIGIN`), bow -Z, sea at asset y 2.05. So the hull floats on the RIB's own `floatPoints` and draft.

**Offset of every Model's pivot from HullRoot: `Builder.RIB_ORIGIN` = (0, -2.1, -0.0761), times the look scale.** No piece has an offset of its own. Scale round that pivot with the hull.

## What the game code must do

1. `VehicleConfig.Hydrofoil`: add `model = "M_Veh_Hydrofoil"`. `hullSize` can stay (25.1 long against the RIB's 25.3).
2. `Builder.buildRIBAsset` reads `AssetIds.Attachments.M_Veh_RIB` by name. Change it to `AssetIds.Attachments[spec.model or "M_Veh_RIB"]`, or seats land inside the legs. The hull has the RIB's `ATT_` names: DriverSeat, EyePoint, PassengerSeat1-2, SurvivorSlot1-4, TowHitch, BowPoint, DriveAttachment, NavPort, NavStarboard, NavMasthead, NavStern, Beacon, Searchlight, Prop1-2, Float1-8. It has no `ATT_DogSlot`, so the fallback applies.
3. **L34+ (Sky Stilts):** the hull has two MeshParts, body and `M_Veh_Hydrofoil_Foils`. Move the foils part by **(0, -2.5, +1.329)** hull-frame studs, times the scale, so it lands on the stilts. Raise the boat **2.5** times the scale: the sea then sits at asset y -0.45. `floatPoints` y -2.5 does both the lift and the draft. `ATT_Splash*` and `ATT_Prop*` go down 2.5; the pod and tip splash markers also move +1.329 in z.
4. **Camera:** the sheet's chase cam backs off x1.15 from L34 and x1.3 from L39. Tune it in play.
5. **Glow:** nozzles and flames are plain palette colours. Set Neon or a light at `ATT_Glow_P/S/Top` and `ATT_Flame_P/S/Top`, and any VFX there.
6. **Spin (concept, optional):** turn the whole Radar Dish piece round the vertical at `ATT_Spin` (1.6 rad/s; collar and mast are round) and the whole Turbo Halo round its own tilted axis at `ATT_HaloAxis` (0.5 rad/s; tilt -18 degrees about X).
7. **Splash:** the concept's solid splashes and spray are not meshes. Fire water VFX at `ATT_Splash{Front,Rear}{P,S}_{Pod,Tip}`.
8. **Number tiles:** three blank white tiles. Put the level number on at `ATT_NumberStern`, `ATT_NumberP`, `ATT_NumberS`.
9. Set CanCollide off; there is no `_COL`. Add `M_Upg_*` to `tools/blender/names.py` (`Upg` is only allowed at run time in `pieces.py`) and run `tools/gen_asset_ids.py` when wiring.
10. `BoatLevels` PIECES still lists the old names for L31-L40 (Main foils ... Jet wall). Rename them, and drop the placeholder `pieceParts` on this hull.

## Past the concept, on purpose

- **Twin-fin tail, not one fin.** Two fat swept fins carry the tailplane. The sight line from the chase cam to the driver runs between them, and the Top Jet sits in the gap, so nothing has to move at L39 (the concept lifted the fin +3.4). The small crown fin on top is the fin the halo circles.
- **Stern deck slopes** 9.7 degrees down towards the cockpit and the seat stands 0.6 higher, so the driver shows from behind. Cockpit and seat fit an R15 at the game's scale; he is not part of the mesh (the sheet's figure is a proxy).
- **Colour:** orange base, yellow and white accents, dark as the neutral. Cyan only in nozzles and screen. Red and separate gold were cut, and the needle's bands are orange and white.
- **Fatter:** legs, pods, jets (r 3.0, was 2.6), needle (r 1.28, was 0.85), radar mast. The needle ends in a round tip and flames are blunt lobes, so nothing reads as a missile.
- **Cut as noise:** flag and pole, vent tiles, red stripes, second burner ring, inner halo glow.

## Checks

validate PASS for all ten (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `LOD0 floor`, `texture sets`; reasons in `pieces.py`). zfight: 0 visible pairs at each LOD of each asset, and hull plus pieces together at L33 and L40 (LOD0, foils in their level's place): 0 pairs. Not seen in Studio.

## Open

- **Bay fit:** at x1.92 the bare boat is 48 wide (bay 24) and 48 long (bay 30). At L40 (x2.19) it is about 56 wide, 88 long without flames, and about 59 tall above the sea (clear height 16.9). Same open decision as the Lifeboat: smaller look at the station, land further out, or a wider bay. Parts have CanCollide off, so this is visual only.
- The foils part's name after Roblox import is not checked: confirm it in Studio before step 3.
- Survivors past slot 4 use the RIB fallback spots (room is 10 here), which will not fit this hull. Check in play.
- Float points stay narrow under a wide, tall boat. Check the feel in play.
- Sheet: `build/status/2026-11-04/art/hydrofoil.png`.
