# M_Prop_SeaPlateKit (2026-11-01, PERF-BL4 round 4: Opus 5.5, Blender MCP)

Round 4 (AD r3 median 8.2): jump ramp side profile is one wedge: the stepped red/white cheek bricks are replaced by one
solid red sloped cheek per side (bevelled top 0.8 over the running surface, seams every 4 studs, ending where it meets
the water) with a short one-stud post at the lip; the yellow lip band is gone; the lip face bricks are solid red; the
r3 underwater brick base (the "pale slab") is deleted, the two ramp piers now rise to just under the lip face; the lip
pylons are stone with a yellow/black band under the lip. Buoys yellow, the lane runs from the toe to the quay kerb (stops
2.5 short). Every piling is grey: shafts light bluish grey, the hazard band moved from the waterline to just under the
deck (yellow/black course under the cap plate), fender bars are stone with a yellow/black band under the deck (were
black rods). Freight -x bays (right third of the game shot): a blue/green two-high container + four pallets of bigger
crates (4.0 x 3.0) 2-3 high; lanes clear. Studs: stud walls two tones darker on light tops (white->stone, light grey->
dark grey, tan->reddish brown). Palette: light bluish grey 168,173,179 -> 184,187,189, stone 142,146,152 -> 152,155,158.
Tris freed: pylon collar stud rings dropped, lower crates in a stack skip slats, container ribs 6 -> 4 per side,
hidden bottoms of crates / pallets / containers dropped, fender segments 6 sides.
Validate PASS: LOD0 37,372 / 40k, LOD1 12,216 / 15k, LOD2 2,056 / 3k (L12_FreightProps 9,738 / 10k per MeshPart).
zfight 0 visible pairs on LOD0-2. ATT_* unchanged, running surface unchanged (code wedge). Sheets r4/ (r4_sheet.png).

## Round 3


Round 3 (AD r2 median 7.9): jump ramp: the two running-surface rows wholly under water are gone (the "ghost slab"),
chevrons moved above the waterline, the ramp sits on a dark grey brick base (two-course skirt under each cheek +
stepped core blocks under the slope down to SEA-8), cheek light bricks step white -> light grey -> stone toward the low
end, floating water chevrons dropped (buoys kept). Freight deck: two-tone stone / light bluish grey field in 2 x 2 tile
blocks over black seams, dark grey border band, the dark studded patches are now yellow plates with black 45-degree
hatch stripes, tan cross walkway with yellow lines, all three bays (incl. the old white outline) are yellow frames with
black hatch tiles, a green / orange container stack and 4 crate pallets fill the empty gangway half. Pylons: stone
grey shafts + courses, black / yellow hazard band at the waterline, white stud collar kept. Studs: every stud wall is
one palette tone darker than its top (STUD_SIDE), so stud rings read at distance at zero tri cost. Palette: light grey
216 -> 168,173,179, tan / dark tan / reddish brown warmer and redder; Ramp field alternates tan / orange-tan plank rows,
promenade + gangway path reddish brown. Tris freed: hidden inner faces of crate slats and container ribs dropped,
pylon cylinders 14 -> 12 sides. Preview: ramp shot is now a low side camera.
Validate PASS: LOD0 39,126 / 40k, LOD1 12,665 / 15k, LOD2 2,122 / 3k. zfight 0 visible pairs on LOD0-2. ATT_* unchanged.
Sheets r3/ (r3_sheet.png). No stud normal map: the kit is one flat palette material.

## Round 2

Round 2 (AD r1 median 6.6): jump ramp rebuilt on the exact code wedge (yellow slope-brick tiles with 0.1 grooves,
raised red chevrons, red/white kicker row, stepped red/white studded cheeks, yellow lip band, lip face stepping back
under the lip on three round-brick pylons, buoy lane + floating chevrons before the toe); taller bevelled studs (2 x 2
deck stud plates); quay kerb = two running-bond courses over a dark back plate + 0.6 bevelled cap; white stud-ring
collars on every pylon at the waterline; Ramp deck: orange-tan promenade + gangway path with white edging, blue
slipway lane with yellow chevrons, blue splash pad with water jets (bullseye dropped), lifeguard tower, ice-cream
kiosk, 4 planters, 2 more parasols; Freight deck: light grey field, tan walkway with yellow lines, a two-high
container stack by the crane, crates 2-3 high with slats, forklift; crane: chunkier boom, hanging green container.
Palette (this kit's texture only): cell 9 dark red (unused) -> bright green, tan brightened to 236,204,140.
Preview only: the shipped M_Veh_SupplyBarge at ATT_BargeMoor with 3 containers and 2 mooring lines.
Validate PASS: LOD0 39,302 / 40k, LOD1 12,206 / 15k, LOD2 1,862 / 3k. zfight 0 visible pairs on LOD0-2. Sheets r2/.

## Round 1

Validate PASS (waivers: layer naming, LOD UV layout, texture sets: one flat palette set, hero_building only for its
triangle ceilings). LOD0 35,656 tris (largest mesh L04_RampDeck 8,654), LOD1 10,632, LOD2 1,889. zfight: run.py-style
fix moved 2 / 2 / 4 faces, 0 visible pairs left on LOD0-2. FBX + attachments.json in build/prod/M_Prop_SeaPlateKit/fbx
(attachments.json copied to assets/fbx/). Not uploaded, so no .rbxm yet (assets.py writes them on upload).

Two assembled plates, each in its plate frame (code C: rect centre, deck top y 0, -z to sea); Ramp Wharf at kit x 0,
Freight Wharf at x 160. Place every module of a plate with C * ATT_<Slot>:Inverse(). Modules: L01-L07 Ramp (shafts
BuildY 1, low course 2, high course 3, deck, props, lamp heads = Neon, jump ramp), L08-L14 Freight (shafts, courses,
deck, props, lamp heads, cargo crane), Col01_COL token.

Attachments (yaw = Roblox CFrame.Angles(0, yaw, 0)): ATT_RampWharf, ATT_FreightWharf, ATT_Ramp (= code `at`),
ATT_TealBrick, ATT_Gangway_Ramp / _Freight (plank top), ATT_Lamp_*_L/R, ATT_Dock_Ramp_01/02, ATT_Dock_Freight_01,
ATT_BargeMoor (= code Marks attachment), ATT_CranePivot, ATT_CraneHook.

Sheets: build/status/2026-11-01/perfect/M_Prop_SeaPlateKit/r1/ (main checkout). The teal brick stays the code Part
(no teal cell in the shared palette).

## Final (2026-11-01): AD, upload, wiring

AD medians (three Opus ADs per round; rubric read 3 / craft 3 / fit 2 / function 2; anchored on M_Prop_BoardKit r4 at
9.2; the old code plates 6.4 Ramp / 5.8 Freight): r1 6.6, r2 7.9, r3 8.2, r4 8.8. r4 is BELOW the 9.1 perfect-pass
bar. Fixes the ADs named for a later round: fill the empty middle of the Freight deck (container block / forklift
lane); seat the jump ramp at the waterline (pontoon or stud base, no pale underwater band); make the studs read at
game distance (stud strips on the edge trims).
Sheets (main checkout): build/status/2026-11-01/perfect/M_Prop_SeaPlateKit/r1/ .. r4/ (r<N>_sheet.png plus
ramp_game / ramp_close / ramp_fig / ramp_jump / freight_game / freight_close / freight_fig / freight_crane).

Uploaded (manifest, assets/models/M_Prop_SeaPlateKit{,_LOD1,_LOD2}.rbxm): LOD0 79572915290245, LOD1 129685240928000,
LOD2 95540036297985; T_SeaPlateKit_Brick_ALB 74281249048177 (NOR / RGH / MET are the Depot palette's bytes, SHARED_BYTES).
AssetIds + Appearances entries added by hand (gen_asset_ids in a worktree re-points other assets).

Wiring: DepotArtService preloads the kit; DockPieces seaPlate clones it through DockPieces.meshes, places it at
C * CFrame.new(-ATT_RampWharf / ATT_FreightWharf), keeps that plate's L01-L07 / L08-L14 (anchored, no collide /
query / touch; Col01_COL dropped), sets BuildY 1 / 2 / 3 on shafts / low course / high course (the rest PLATE_TOP) and
makes the lamp heads Neon (WARM). Every code Part stays with its collision but goes invisible (Transparency 1, no
shadow, stud textures removed): Deck, Skirt, Ramp wedge physics, RampLip, Gangway, Marks / ATT_BargeMoor, bollards,
lamp poles (the hidden bulbs keep their NightLamp lights), rim, rails. The TealBrick stays visible.
Fallback: no kit (Lune tests, a failed load) builds the code plates exactly as before. Kit props (crates, crane,
kiosk) have no collision. Not seen in Studio yet.
