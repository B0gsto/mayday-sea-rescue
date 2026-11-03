# M_Prop_SeaPlateKit (2026-11-01, FIN rounds 5-8: Opus 5.5, Blender MCP)

Status after round 8: AD medians r7 9.0, r8 9.05 (3 Opus ADs, anchors BoardKit r4 9.2 + HQ r6 9.22; each round won
pairwise). Trend r1-r8 6.6, 7.9, 8.2, 8.8, 8.8, 8.9, 9.0, 9.05: 0.05 BELOW the 9.1 bar; ships r8 as the best round
(owner allowed rounds 7-8 only). r9 list: build/status/2026-11-01/perfect/M_Prop_SeaPlateKit/r8_AD.md (main checkout).
Uploaded r8: LOD0 124017354266775, LOD1 126250635097226, LOD2 136267929230470; T_SeaPlateKit_Brick_ALB 71417157896758
(r8 palette: +-8% grey tile contrast; NOR / RGH / MET unchanged). ATT_* unchanged.

## Round 7 (FIN, Opus 5.5, Blender MCP; r6 AD median 8.9)

Jump ramp: two light grey brick floats run the full length under the red cheeks (lip post to past the toe): a stone
waterline course + two light grey running-bond courses (2.5 bricks over the water), studs on the strip beside the
cheek, a black bumper round the outside and the toe. Deck fields: a hash scatter of 4 x 8 half tiles, 4 x 4 quarter
tiles (two tones) and 2 x 2 stud patches on the Ramp tan field and the Freight grey field (deck_grid split tiles).
Round ropes (coils 6-sided section, 8 / 10 segments; lines 8-sided), 12-sided tyres. Crate stacks two high at most
(big crates 2.6 tall, was 3 x 3.0).
Tris cut (hidden): pylon brick tops inside stacks / under cap plates, collar + base bottoms, pylon cores 12 -> 8 sides,
under-water shafts 12 -> 10 sides no tops, ramp lip pylons' two under-water bricks merged, every closed ring's arc
caps (lifebuoys, tyres, wheels), bollard / bush / canopy caps inside other parts, kayak end caps, the low kerb
course's top + deck-side face, lower crates' tops; side-column deck stud plates and field patches drop the stud bevel
ring. ATT_* and collision layout unchanged.
Validate PASS: LOD0 39,700 / 40k, LOD1 12,946, LOD2 2,186 (L12 9,118 / 10k). zfight 0 visible pairs LOD0-2.
Sheet (main checkout): build/status/2026-11-01/perfect/M_Prop_SeaPlateKit/r7/r7_sheet.png. Not uploaded.

Rounds 5-6 (FIN, Opus 5.5, Blender MCP). AD medians r5 8.8, r6 8.9 (three Opus ADs each, same rubric, BoardKit r4
anchor 9.2; r6 won pairwise vs r5, r5 vs r4). Still BELOW the 9.1 bar after round 6; ships r6 as the best round.
r5: Freight middle filled (three two-high container stacks, forklift lane, pallets; a container pair + crates by the
+x bay; these live in L14_CargoCrane for L12's 10k per-MeshPart budget); taller studs (h 0.45 -> 0.6); every kerb cap
studded; 6-sided studs drop the bevel ring (tri budget). r6: the jump ramp sits on two light grey studded floats under
its red cheeks with a black bumper course (the jet-ski lane between stays open water); kerb studs 1.3x in the other
cap colour (red on white, white on red, black on yellow, yellow on black); benches, planters, parasols round the
splash pad. preview.py: the template world's HDRI is unlinked (its sun hotspot was the r5 "glare blob").
Collision: DockPieces makes the props (L05 / L12) and the crane yard (L14) CanCollide + CanQuery (Automatic fidelity).
Validate PASS: LOD0 39,804 / 40k, LOD1 13,165, LOD2 2,323. zfight 0 visible pairs. ATT_* unchanged.
Uploaded: LOD0 71060030921213, LOD1 87543814711311, LOD2 84446441261378 (ALB unchanged, same bytes).
Sheets (main checkout): build/status/2026-11-01/perfect/M_Prop_SeaPlateKit/r5/, r6/.
r7 list (AD consensus): floats 2-3 bricks tall, full length under the cheeks; flat Freight / Ramp deck fields need tile
variation or stud patches; round ropes and 12-side tyres; crate stacks lower (read 2x minifig).

## Round 4

Round 4 (PERF-BL4; AD r3 median 8.2): jump ramp side profile is one wedge: the stepped red/white cheek bricks are replaced by one
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

## r8 (2026-11-01)
r7 AD list items 1-7: one 3.8-tall crate per pallet everywhere (top 4.5), chunkier bevelled slats; Freight bollards
s 0.65 / sy 0.5 (1.5 across, 1 brick, 12-sided); ramp floats trimmed flush with the toe, a yellow plate lip at the waterline,
black bumpers replaced by an inset dark grey bevelled waterline course; red/white launch kicker, 0.22 deck seams over
black; cheeks = 4 stepped bevelled bricks + white post tiles (the hidden wedges past the float top are gone); quay walls
in 1.2 courses, 0.08 grooves, joints every 4 staggered (one face per brick, cheaper than r7); Ramp kerb studs halved for
2x Ramp plaza stud patches; red crane mast bands; palette LBG +8% / stone -8% (Freight deck contrast; maketex rerun).
LOD0 38,404 (L12 8,718), LOD1 12,555, LOD2 2,090. Validate PASS. zfight 0 visible pairs on LOD0-2. Sheet r8/r8_sheet.png.

## r9 (2026-11-01)
r8 AD list: ramp cheeks = lip post (one plate over the kicker) + 2 slope steps, each two red courses under a white cap
plate, 0.1 bevels; float waterline course mid stone grey, sunk 0.2 under a yellow 1-plate lip along the full float;
Ramp plaza: more 4 x 4 quarter tiles in dark tan, promenade + gangway path as seamed 2 x 8 planks; Freight right third:
dark grey / light grey checker past the walkway, a yellow / black hatch strip along it, a pallet pair moved there;
walkway lines 0.6 -> 0.9; tyres 8-sided (budget). Not done: the "stray brown bench slabs" (not pinned down).
LOD0 39,268, LOD1 12,699, LOD2 2,092. Validate PASS. zfight 0 visible pairs on LOD0-2. Sheet r9/r9_sheet.png.

**Shipped r9.** AD 9.15 / 9.05 / 9.1, median 9.1 PASS (bar 9.1; r8 9.05; build/status/2026-11-01/perfect/M_Prop_SeaPlateKit/r9_AD.md).
Ids LOD0 105818248709873 / LOD1 104675938832464 / LOD2 95366638889333 (textures and pivot-relative attachments unchanged).
Tris LOD0 39,268 / LOD1 12,699 / LOD2 2,092 (cap 40,000). Open: flat cheek, float and Freight deck faces (seams);
tyres read octagonal (8 sides); brown bench on brown deck; turntable not re-rendered.
