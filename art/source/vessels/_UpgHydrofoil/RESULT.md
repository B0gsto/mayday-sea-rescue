# Hydrofoil stage (L31-L40): result

Round 3, the last (art director round 1: 5.5/10, round 2: 5/10), no score yet. Earlier uploads are superseded: use only the ids below. Concept: artifact f23406cb (Hydrofoil Boat Concept). Geometry: `pieces.py` on `hk.py` (the Lifeboat kit plus this palette), one thin `build.py` per asset in `art/source/vessels/M_*Hydrofoil*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `sheet_scene.shoot(level)`, `compose_sheet.py`.

## Final size

Measured on the boat with the foils in their level's place, at the `BoatLevels` look scale, in studs:

| Level | Scale | Wide | Long | Total height | Above the sea | Sea to hull bottom |
|---|---|---|---|---|---|---|
| L31 | x1.918 | 43.7 | 51.6 | 20.3 | about 19.5 | 10.0 |
| L40 | x2.194 | 55.8 | 66.6 | **37.3** | 36.4 | 14.9 |

L40 is under the 38 limit and the gate's 39.6 clearance. The margin holds only at this scale: raising L40's scale above about x2.23 breaks the limit.

## Ids

Size is x, y, z in studs (Roblox axes), before the game's scale.

| Lv | Asset | LOD0 | LOD1 | LOD2 | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 31 | `M_Veh_Hydrofoil` | 135782740059521 | 102873608104596 | 100858468763255 | 22.8 x 10.6 x 26.9 | 1592 / 543 / 135 |
| 32 | `M_Upg_Hydrofoil_GiantJets` | 87022821820099 | 112862873829554 | 110365175230522 | 25.4 x 7.0 x 5.8 | 2392 / 1196 / 598 |
| 33 | `M_Upg_Hydrofoil_TTail` | 134780310143667 | 99856912538207 | 119294291375466 | 1.4 x 3.2 x 6.7 | 72 / 36 / 18 |
| 34 | `M_Upg_Hydrofoil_SkyStilts` | 127945511112075 | 121086513948355 | 114442742200876 | 8.2 x 3.6 x 15.2 | 84 / 42 / 20 |
| 35 | `M_Upg_Hydrofoil_NeedleNose` | 85953260237997 | 104200091075748 | 103614228372736 | 5.9 x 2.0 x 7.5 | 244 / 122 / 60 |
| 36 | `M_Upg_Hydrofoil_SkyWings` | 76545494500079 | 121377620867804 | 132544257434857 | 17.6 x 0.8 x 7.5 | 144 / 72 / 36 |
| 37 | `M_Upg_Hydrofoil_Afterburners` | 117746492122850 | 107009706068777 | 119291337210580 | 24.2 x 5.8 x 1.2 | 944 / 472 / 236 |
| 38 | `M_Upg_Hydrofoil_RadarDish` | 74579544616229 | 81866683214233 | 118435069505317 | 2.9 x 2.4 x 2.4 | 352 / 176 / 88 |
| 39 | `M_Upg_Hydrofoil_TopJet` | 131267272335661 | 76276091226214 | 91452394172233 | 2.8 x 3.3 x 3.4 | 812 / 406 / 202 |
| 40 | `M_Upg_Hydrofoil_TurboHalo` | 99743618680144 | 100681311702262 | 86566835630503 | 6.5 x 1.9 x 6.3 | 448 / 224 / 112 |

Shared palette (one SurfaceAppearance for all ten), `T_UpgHydrofoil_Palette_*`, 256 px: ALB 119894043403469 and RGH 117446448784696 (both Reviewing at upload), MET 74132887490056, NOR 94365844917813 (the Lifeboat's flat normal, same file). All meshes Approved at upload. L40 all LOD0 together: 7084 tris.

## Offsets

The hull and every piece share one frame and one pivot: the RIB asset's frame (`Builder.RIB_ORIGIN`), bow -Z, sea at asset y 2.05. So the hull floats on the RIB's own `floatPoints` and draft.

**Offset of every Model's pivot from HullRoot: `Builder.RIB_ORIGIN` = (0, -2.1, -0.0761), times the look scale.** No piece has an offset of its own. Scale round that pivot with the hull.

## What the game code must do

1. `VehicleConfig.Hydrofoil`: add `model = "M_Veh_Hydrofoil"`. `hullSize` can stay (hull 25.0 long without the snout or swept foil, RIB 25.3).
2. `Builder.buildRIBAsset` reads `AssetIds.Attachments.M_Veh_RIB` by name. Change it to `AssetIds.Attachments[spec.model or "M_Veh_RIB"]`, or seats land in the wrong place. The hull has the RIB's `ATT_` names: DriverSeat, EyePoint, PassengerSeat1-2, SurvivorSlot1-4, TowHitch, BowPoint, DriveAttachment, NavPort, NavStarboard, NavMasthead, NavStern, Beacon, Searchlight, Prop1-2, Float1-8. It has no `ATT_DogSlot`, so the fallback applies.
3. **The driver sits off centre:** `ATT_DriverSeat` and `ATT_EyePoint` are at asset x +1.7. That keeps the centre fin and Top Jet from hiding him from a centred chase cam. Do not recentre them.
4. **L34+ (Sky Stilts):** the hull has two MeshParts, body and `M_Veh_Hydrofoil_Foils`. Move the foils part by **(0, -1.6, +0.746)** hull-frame studs, times the scale, so it lands on the sleeves. Raise the boat **1.6** times the scale: the sea then sits at asset y 0.45. `floatPoints` y -1.6 does the lift. `ATT_Prop*` and `ATT_Splash*` go down 1.6 and move +0.746 in z.
5. **Camera:** the sheet's chase cam is 38 back and 20 up from the sea, hull frame, looking at y 7 above the sea. The real chase cam is not checked: from a much lower angle the fin and hull cover more of the driver.
6. **Glow and flames:** nozzles are plain palette colours and no flame is modelled. Set Neon or a light at `ATT_Glow_P/S/Top`, and fire flame VFX at `ATT_Flame_P/S/Top`. Keep flames short and soft: a long pointed one brings back the missile read.
7. **Spin (concept, optional):** turn the whole Radar Dish piece round the vertical at `ATT_Spin` and the whole Turbo Halo round its own axis at `ATT_HaloAxis` (tilted -12 degrees about X).
8. **Wake:** nothing on the sheet's wake ships. Fire water VFX at `ATT_SplashMainP`, `ATT_SplashMainS` and `ATT_SplashRudder`, and light spray at `ATT_SplashTipP` and `ATT_SplashTipS`.
9. **Number tile:** one blank white tile on the stern. Put the level number on at `ATT_NumberStern`. The side tiles were cut.
10. Set CanCollide off; there is no `_COL`. Add `M_Upg_*` to `tools/blender/names.py` (`Upg` is only allowed at run time in `pieces.py`) and run `tools/gen_asset_ids.py` when wiring.
11. `BoatLevels` PIECES still lists the old names for L31-L40 (Main foils ... Jet wall). Rename them, and drop the placeholder `pieceParts` on this hull.

## Round 3: what changed

Art director round 2 said it still walked, read as a missile and a bug from behind, and was clutter at L40. This round removes more than it adds: L40 went from 10620 to 7084 tris.

- **The one joke:** two turbines far too big for the boat, 6.8 across on a hull 4.4 tall. Fat open drums: a wide intake with a visible fan, a flat open exhaust with a glow inside. No bands and no pointed ends.
- **Stance:** two slim raked grey struts (0.7 by 1.9) to one wide, thin, swept yellow T-foil (22.8 span), plus one slim rudder blade aft. Sky Stilts adds white sleeves on the same rake, +1.6.
- **Hull:** wider and lower: 11.2 wide (was 8), 4.4 tall at the stern (was 5.8). Bow blunted.
- **Livery:** white keel and long white band, a white and yellow rescue flash on each side, a white bow chevron, a white stern tile, yellow stern lamps.
- **Tail:** one fat swept fin with a small white cap. No cross plate, so `TTail` is no longer a T.
- **Needle Nose:** no needle left, just a wide flat snout with a broad dark rubber bumper. Nothing pointed, nothing white.
- **Afterburners:** no flame mesh; a yellow hot ring and an orange heart inside each exhaust.
- **Made small:** Sky Wings are short orange strakes (no yellow spar), Radar Dish is 2.9 across on the cockpit wall, Top Jet is a small third turbine on the fin tip, Turbo Halo is a thin ring 6.5 across round the fin.
- **Cut:** rescue rings, side number tiles, most studs, the concept's pods and end plates.
- **Sheet:** all angles over a sea plane with a flat sheet-only wake, so the lift-off gap reads. I checked the rear phone renders at L31, L35 and L40: the turbines lead, the hull is wide and the driver shows.

## Departures from the owner-cleared concept

The art director's rounds moved this well away from the cleared concept, so the owner may want to see it: no T-tail, no needle, no huge foils on chunky orange legs (slim grey struts now), a much lower hull (concept stern top 11.5 above the sea at L31, now 9.6), driver off centre, no modelled flames, small halo round the fin.

## Checks

validate PASS for all ten (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `LOD0 floor`, `texture sets`; reasons in `pieces.py`). zfight: 0 visible pairs at each LOD of each asset, and 0 visible pairs for hull plus pieces together at L33 and L40 (LOD0, foils in their level's place). Not seen in Studio.

## Open

- **Width:** 55.8 wide at L40 against the bay's 24, and 66.6 long against its 30. The height limit is met; length and width are not, and this is the same open decision as the Lifeboat. Parts have CanCollide off, so this is visual only.
- The foils part's name after Roblox import is not checked: confirm it in Studio before step 4.
- Survivors past slot 4 use the RIB fallback spots (room is 10 here), which will not fit this hull. Check in play.
- Boarding height: the seat is about 18 studs above the sea at L31 and 24 at L40. Check pick-ups in play.
- Sheet: `build/status/2026-11-04/art/hydrofoil.png`.
