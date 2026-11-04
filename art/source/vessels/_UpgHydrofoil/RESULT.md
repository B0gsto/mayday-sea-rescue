# Hydrofoil stage (L31-L40): result

Round 2 (art director round 1: 5.5/10), no score yet. Round 1 uploads are superseded: use only the ids below. Concept: artifact f23406cb (Hydrofoil Boat Concept). Geometry: `pieces.py` on `hk.py` (the Lifeboat kit plus this palette), one thin `build.py` per asset in `art/source/vessels/M_*Hydrofoil*`. Rebuild: `maketex.py` (system python3), then `pipeline.run_all()` in the Blender MCP session. Sheet: `sheet_scene.shoot(level)`, `compose_sheet.py`.

## Ids

Size is x, y, z in studs (Roblox axes), before the game's scale (x1.92 at L31, x2.19 at L40).

| Lv | Asset | LOD0 | LOD1 | LOD2 | Size | Tris LOD0 / 1 / 2 |
|---|---|---|---|---|---|---|
| 31 | `M_Veh_Hydrofoil` | 123241557342005 | 118977357360986 | 86492091881669 | 25.0 x 18.4 x 27.6 | 2324 / 796 / 197 |
| 32 | `M_Upg_Hydrofoil_GiantJets` | 97343773200773 | 109034382065473 | 96385341017643 | 21.3 x 6.5 x 8.1 | 3432 / 1716 / 858 |
| 33 | `M_Upg_Hydrofoil_TTail` | 102852654623506 | 89279125788131 | 79462680920407 | 16.0 x 11.7 x 8.6 | 200 / 100 / 50 |
| 34 | `M_Upg_Hydrofoil_SkyStilts` | 98728363741429 | 131670519879821 | 96798544940420 | 8.2 x 5.2 x 14.6 | 84 / 42 / 20 |
| 35 | `M_Upg_Hydrofoil_NeedleNose` | 124224657301573 | 126694226822520 | 122620920467163 | 3.9 x 4.0 x 9.3 | 444 / 222 / 110 |
| 36 | `M_Upg_Hydrofoil_SkyWings` | 77133728197709 | 127077648244694 | 132960858272853 | 25.6 x 5.6 x 10.2 | 368 / 184 / 92 |
| 37 | `M_Upg_Hydrofoil_Afterburners` | 92963749563271 | 73990537067081 | 84666262918970 | 19.6 x 4.8 x 5.7 | 608 / 304 / 152 |
| 38 | `M_Upg_Hydrofoil_RadarDish` | 130544466102539 | 139192088673253 | 130927787287240 | 8.4 x 8.5 x 6.9 | 728 / 364 / 182 |
| 39 | `M_Upg_Hydrofoil_TopJet` | 81269179017030 | 114547032231953 | 136604533722319 | 9.2 x 4.9 x 9.2 | 1632 / 816 / 408 |
| 40 | `M_Upg_Hydrofoil_TurboHalo` | 83235853758569 | 85174301061468 | 79203577871016 | 12.5 x 3.9 x 12.2 | 800 / 400 / 200 |

Shared palette (one SurfaceAppearance for all ten), `T_UpgHydrofoil_Palette_*`, 256 px: ALB 119894043403469 and RGH 117446448784696 (both Reviewing at upload), MET 74132887490056, NOR 94365844917813 (the Lifeboat's flat normal, same file). All meshes Approved at upload. L40 all LOD0 together: 10620 tris.

## Offsets

The hull and every piece share one frame and one pivot: the RIB asset's frame (`Builder.RIB_ORIGIN`), bow -Z, sea at asset y 2.05. So the hull floats on the RIB's own `floatPoints` and draft.

**Offset of every Model's pivot from HullRoot: `Builder.RIB_ORIGIN` = (0, -2.1, -0.0761), times the look scale.** No piece has an offset of its own. Scale round that pivot with the hull.

## What the game code must do

1. `VehicleConfig.Hydrofoil`: add `model = "M_Veh_Hydrofoil"`. `hullSize` can stay (hull 25.1 long without the swept foils, RIB 25.3).
2. `Builder.buildRIBAsset` reads `AssetIds.Attachments.M_Veh_RIB` by name. Change it to `AssetIds.Attachments[spec.model or "M_Veh_RIB"]`, or seats land inside the legs. The hull has the RIB's `ATT_` names: DriverSeat, EyePoint, PassengerSeat1-2, SurvivorSlot1-4, TowHitch, BowPoint, DriveAttachment, NavPort, NavStarboard, NavMasthead, NavStern, Beacon, Searchlight, Prop1-2, Float1-8. It has no `ATT_DogSlot`, so the fallback applies.
3. **L34+ (Sky Stilts):** the hull has two MeshParts, body and `M_Veh_Hydrofoil_Foils`. Move the foils part straight down **4.0** hull-frame studs, times the scale, so it lands on the sleeves. Raise the boat **4.0** times the scale: the sea then sits at asset y -1.95. `floatPoints` y -4 does the lift. `ATT_Prop*` and `ATT_Splash*` go down 4.
4. **Camera:** the sheet's chase cam is 40 back and 24 up (hull frame), times x1.15 from L34 and x1.3 from L39, looking at y 13 above the sea. The seat is far above HullRoot (31 studs over the sea at L31, 44 at L40): the chase focus must follow the deck, not the root. Tune it in play.
5. **Glow:** nozzles and flames are plain palette colours. Set Neon or a light at `ATT_Glow_P/S/Top` and `ATT_Flame_P/S/Top`, and any VFX there.
6. **Spin (concept, optional):** turn the whole Radar Dish piece round the vertical at `ATT_Spin` (1.6 rad/s; collar and mast are round) and the whole Turbo Halo round its own tilted axis at `ATT_HaloAxis` (0.5 rad/s; tilt -18 degrees about X).
7. **Splash:** the concept's solid splashes and spray are not meshes. The three strut tips cut the sea: fire water VFX at `ATT_SplashFront`, `ATT_SplashRearP`, `ATT_SplashRearS`.
8. **Number tiles:** three blank white tiles. Put the level number on at `ATT_NumberStern`, `ATT_NumberP`, `ATT_NumberS`.
9. Set CanCollide off; there is no `_COL`. Add `M_Upg_*` to `tools/blender/names.py` (`Upg` is only allowed at run time in `pieces.py`) and run `tools/gen_asset_ids.py` when wiring.
10. `BoatLevels` PIECES still lists the old names for L31-L40 (Main foils ... Jet wall). Rename them, and drop the placeholder `pieceParts` on this hull.

## Past the concept, on purpose

Art director round 1 said it read as a walking animal with brick feet, crab-claw flames, a heaped halo, a dart nose and a goalpost tail. So:

- **Stance:** hull bottom at y 12, twice the concept. Four jointed legs became three straight keel-fin struts, one forward and two aft, yellow so they group with the foils. They hang straight down, so the concept's raked legs are gone; only the leading edge rakes back.
- **Foils:** two thin swept foils, nearly flat, 18 and 25 wide. End plates, pods and studs cut. The strut tips alone reach the sea.
- **Sky Stilts:** white sleeves telescoping from the strut ends, +4.
- **Tail:** two fins splayed 26 degrees in an open V, yellow caps, no crossbar and no crown fin. The asset keeps the name `TTail`, but it is no longer a T. It is the owner-cleared concept's biggest departure, so the owner may want to see it.
- **Top Jet:** a fat engine (r 2.2) in the V's throat on two short stubs, above the sight line to the driver.
- **Turbo Halo:** one smooth yellow ring, R 5.4, thick 0.85, resting on both fins' inner faces and tilted 12 degrees to the chase cam. No bricks or studs. It no longer floats round a fin, which the concept asked for.
- **Afterburners:** a yellow can and one simple cone on each jet.
- **Needle Nose:** a short fat orange snout with a big rounded white bumper; no stripes. It is no longer a needle.
- **Sky Wings:** raised 25 degrees, 8.4 root chord, so the tips clear the jets.
- **Radar Dish:** r 4.2 on a fat mast, its lower edge above the driver.
- **Kept from round 1:** the stern deck sloping 9.7 degrees towards the cockpit, a raised seat, orange base with yellow and white accents, cyan only in nozzles and screen, no flag, vents or red.

## Checks

validate PASS for all ten (waived: `_COL proxy`, `LOD UV layout`, `UV faces`, `LOD0 floor`, `texture sets`; reasons in `pieces.py`). zfight: 0 visible pairs at each LOD of each asset, and hull plus pieces together at L33 and L40 (LOD0, foils in their level's place): 0 pairs. Not seen in Studio.

## Open

- **Bay fit:** at x1.92 the bare boat is 48 wide (bay 24), 53 long (bay 30) and 34 tall above the sea (clear height 16.9). At L40 (x2.19) it is about 56 wide, 73 long without flames and 69 tall. Same open decision as the Lifeboat: smaller look at the station, land further out, or a wider bay. Parts have CanCollide off, so this is visual only.
- **Tall:** L40 is now barely longer than tall (73 against 69), against the concept's "longer than tall", because of the doubled stance. Cutting the Sky Stilts lift or shortening the fins would fix it.
- **Boarding:** the seat is 31 to 44 studs above the sea, and pick-ups happen from up there. Check both in play.
- The foils part's name after Roblox import is not checked: confirm it in Studio before step 3.
- Survivors past slot 4 use the RIB fallback spots (room is 10 here), which will not fit this hull. Check in play.
- Float points stay narrow under a wide, tall boat. Check the feel in play.
- Sheet: `build/status/2026-11-04/art/hydrofoil.png`.
