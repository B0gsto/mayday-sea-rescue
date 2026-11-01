# M_Prop_CommonsKit: spec (draft 2026-11-01, not yet built in Blender)

One Lego kit for the idle crew's commons (`shared/Hangout.luau`, built today by `DockPieces.hangout`) and the six sold
decorations (`DockPieces.decoration` / `DECOR_BUILDERS`). One FBX, one flat palette material, one mesh per module. Each
module's origin is the code frame it replaces: `Hangout.frame(bay, prop)` or `DockConfig.decorSpot(key, frame)`
(ground centre; Roblox x right, y up, front -Z). Code Parts stay as invisible colliders + fallback; the wiring clones
each module at its frame (AssetLoader.cloneModule, like BoardKit). Author coordinates in `build.py` are in that frame,
so every value below is a code-frame value.

Style: BoardKit (AD 9.2): studs pitch 1, r 0.3, h 0.2 (6-sided), 0.04-0.14 top bevels, 1x plates ~0.4, grooves 0.05
over a darker core. Feet at Y0 = -0.06, studs/props sink 0.04, coplanar faces offset 0.04-0.05.

## Palette (`palette.py`, 4 x 4 cells, 1024 px set `T_CommonsKit_Brick`)

BoardKit cells with two swaps: 9 dark red -> bright green (40,168,64, as SeaPlateKit), 13 orange-tan -> bright pink
(255,120,180). Used: white, light silver, dark grey, red, orange, yellow (also the statue's "gold"), stone, blue, green,
dark tan, tan, reddish brown, pink, glass blue, black.

## Shared pieces

- **Patio**: dark-tan slab (top 0.05) under 2 x 2 tan tiles (top 0.10) + reddish-brown 1x brick edge (top 0.5, studded)
  on chosen sides with walk-in gaps. Workers stand at y 0, so their feet sink 0.1 into the tiles (never float).
- **Flower brick**: green 2 x 2 (or 1 x 1) brick, a brick-built flower per stud: round-bar stem, two 1x1-plate leaves,
  5-petal flower plate, stud centre.
- **Park lamp**: black studded base plate, round post with collars, lantern head (plate, warm globe in the lit mesh,
  plate, four-sided black cap + stud).

## Modules

| Mesh | Code frame | Footprint x/z, height | Parts | LOD0 cap (draft) |
|---|---|---|---|---|
| H01_Canteen | Hangout `Canteen` (14 x 12) | 15.6 x 13.6 (+ awning lip to z -7.85), 8.4 | tan slab + white/tan checker tiles (top 0.4 = CANTEEN_FLOOR), front stud row; white running-bond walls on the code wall volumes (0.8 thick, to 7.45), blue-framed glazed side windows; red studded-ring roof plate (code roof volume) + raised tile; sloped red/white striped awning + valance; blue counter, white studded top, soup pot, bread crate; yellow table (top 3.2, corner studs) on brown legs, laid for four (bowls, noodles, cups, plate, bread, apple); 4 stools: round red tile seat top 2.0 on dark post | 6000 (3983) |
| H02_Campfire (+ H02_CampfireGlow) | `Campfire` (12 x 12) | 11.8 x 11.8, 7.8 | patio, side curbs with walk-in gaps z -1.6..1.6; 3 corner flower bricks + park lamp (back right); 6 studded stones r 1.7; crossed logs; orange flame (3 tongues); 2 flat-topped logs (top 1.3 = LOG) with tan cut ends. Glow: flame core (code NightLamp) + lamp globe | 3500 (2498) / 300 |
| H04_ParkBench | `BenchA` and `BenchB` (6 x 3) | 6.04 x 2.0, 3.25 | dark foot plates + legs, 3 green seat slats (top 1.5 = BENCH), 2 back slats, studded back top, studded dark armrest end panels | 1200 (284) |
| H05_BenchPatio (+ Glow) | `BenchA` frame only (BenchB = its x +12) | x -4.2..16.2, z -3.5..2.6 | one patio under both benches: back + end curbs, back gap x 3..9 holding 2 flower bricks and a park lamp between the benches; front open | 2500 (1746) / 300 |
| H06_Hammock | `Hammock` (3 x 10) | 3 x 10, 4.2 | tile pad; 2 reddish-brown brick posts on dark plates, studded caps; white flat middle (top 2.3 = HAMMOCK), orange ends rising to brown spreader bars, white ropes, pillow at +z (head way) | 1200 (324) |
| H07_IceCart | `Cart` (5 x 4) | patio x -3..3, z -4.2..2.3; umbrella r 2.2; 6.95 | patio with back curb; white body, pink band, glass-blue studded top, dark chassis, black tyres + silver hubs, push handle (+x); pink/white 8-panel umbrella; 3 cones + round-brick scoops | 2200 (932) |
| H08_ChatEast | `ChatEast` (5 x 5) | r 2.45 round pad, 3.45 | round tile pad; standing table (dark base, post, white round top 3.05, centre stud) with one drink per talker | 900 (270) |
| H09_ChatWest (+ Glow) | `ChatWest` (5 x 3) | 5 x 3, 7.4 | patio; lean rail behind the talkers (brown brick posts, studded dark-tan rail top 2.85); park lamp in the rail; two 1x1 flower bricks in front | 1500 (514) / 300 |
| D01_FlowerBed | decor `FlowerBed` (8 x 8) | 8 x 8, 2.5 | green base plate with a stud ring; dark-tan 2-course bed (studded top), soil (top 1.2); 5 x 5 brick-built flowers, pink/yellow/white/red/orange | 3500 (3200) |
| D02_PicnicTable | `PicnicTable` (8 x 8) | 6 x 6.3, 2.75 | 4 dark-tan planks (top 2.55), studded left half, 4 x 4 red/white checked cloth on the right half; 2 two-plank benches (top 1.65) with studded ends; brown A-frame legs, bearers | 1500 (600) |
| D03_LampRow (+ Glow) | `LampRow` (9 x 6) | 9 x 1.6, 11.1 | grey studded rail plate (0.6 tall); 3 black park lamps at x -3/0/3 (globe centre 9.5 = code LampBulb); 1x1 flower bricks between | 1800 (974) / 300 |
| D04_FlagPole | `FlagPole` (7 x 7) | r 1.9, 21.3 | grey round studded base, white studded brick, silver collar, white pole to 20.4 with silver collars, gold (yellow) ball finial 20.3..21.3, cleat. The flag cloth stays the code Part `Flag` (DockService recolours it) | 800 (488) |
| D05_Statue | `Statue` (7 x 7) | 5 x 5 plinth, 9.85 | stepped grey plinth (stud ring, grooved courses), white studded top plate (2.2); yellow "gold" minifig: legs, hips, tapered torso, cylinder head + stud, left arm down, right arm raised; red/white lifebuoy on the left side | 2000 (566) |
| D06_Fountain (+ D06_FountainWater) | `Fountain` (7 x 7) | r 3.49, 5.15 | grey floor; 16 curved grey bricks, staggered white studded coping (top 1.25); grey column with silver collars; white upper bowl with a rim (top 4.3), finial. Water: lower disc top 1.0, upper disc 4.0..4.15 (code makes it Glass / transparent) | 2200 (1184) / 300 |
| Col01_COL | token | | (the code never collides with the kit) | |

Draft totals (system-python count, stub mathutils): LOD0 18,075, LOD1 12,414, LOD2 6,738 tris; all under the caps.
Budget class `hero_building` (waiver, as SeaPlateKit) for its 40k / 10k per-part / 15k LOD1 ceilings; its LOD2 3,000
ceiling is under the hand-made 6,738, so versions.decimate will cut LOD2 (or log a waiver).

## Round 2 changes (AD r1 8.3; every ATT_* unchanged)

- Palette: 8 x 8 cells (1024 px, 128 px cells), cells 16 coral, 17 dark chocolate, 18 lilac, 19 deep water blue added.
- H01: stepped white/red roof centre + ridge cap (top 10.4), yellow sign plate with a noodle bowl on the front fascia,
  jug / plates / fruit bowl on the counter ends.
- H02: flame 5.4 tall (orange shell + tongues, yellow lit core), 2-course ring of round 2 x 2 stones, logs x +-3.15
  (past both sitters), corner planters 1 x 2, lamp base 1 x 1.
- H04: open bench 6.8 long (x +-3.4, armrests to +-3.9), 1x1 legs, 3 back slats to 3.8. H05 patio x -5..17, z -2.6..2.6
  (was -4.2..16.2, -3.5..2.6), green litter bin at x 6.
- H06: 2 x 1 brick posts (z +-4.4, cap top 3.76), striped 3-segment sagging sling, yellow pillow, side table (x 2.25,
  z 1.6, top 1.9, just outside the 3-wide frame) with a cup.
- H07: body 1 brick taller (top 4.2), side wheels + hubs, stand leg, giant cone + scoop topper (7.6), umbrella 7.4..8.35.
- H08: high-top (top 3.62, r 1.0) under a blue / white umbrella r 2.7 (6.6..7.65). H09: drinks barrel table (top 3.15)
  at z -1.0 between the talkers.
- D01: wood-brown bed, chocolate soil, 6 x 6 round pastel pink / lilac / yellow heads (LOD0 4,212, cap 4,500).
- D02: plank tiles over a brown core (no top studs), 3 x 3 coral / white mat centred. D03: green studded plate, thick
  black posts straight on it, round globes under wide black conical shades.
- D04: base r 2.6 (12 studs); D04_FlagCloth = coral rippled cloth y 14.8..20.1, z 0.3..9.0 (1.45x the code Flag's area;
  ATT_FlagPole_Cloth stays at the code centre); new D04_FlagEmblem = white lifebuoy ring through the cloth (own mesh,
  not "Flag", so the owner tint leaves it white).
- D05: 6 x 6 studded base, bevelled 4.4 step, column, bevelled top; lifebuoy r 0.36. D06: thinner basin wall (water
  r 2.9), dark inner rim, upper tier lowered (rim top 3.6), spout + water column / splash crown to the jet (5.15).
- Totals: LOD0 22,111, LOD1 14,088, LOD2 2,866 (decimated at 1.75x the per-mesh target).

## Round 3 changes (AD r2 8.8; every ATT_* unchanged; FlowerBed / LampRow / Statue / Fountain frozen)

- H01: roof front pulled back to z -5.6 (code roof -6.8) and the sloping awning replaced by a striped valance on the
  roof face, so the 3/4 camera sees the front eaters; each eat spot has a white plate + red bowl + yellow noodle dome.
- H02: raised dark hearth in a ring of 8 round grey 2 x 2 stones; 3 stacked cones (orange, yellow lit core, white tip
  to 6.4). H04: 4 back slats, studded top 4.45 (over seated shoulders 3.6). Preview seats BenchB's sitters too.
- H06: matching 2 x 2 brown posts (z +-4, tan studded caps 4.96), 5-stripe red / white sling with a deeper sag,
  square 1 x 1 side table + cup at x -2.25. H07: 2 hubbed wheels per end (x +-2.04..2.42), push handle at -x.
- H08: high-top 4.45 (blue rim, 3 cups). H09: brown barrel high-top (z -1.5, round top r 1.05, 2 cups), shorter lean
  rail with one small lit lantern (lamp and flower boxes removed; ATT_ChatWest_Lamp stays as the code light point).
- D02: one coral mat tile, 0.16 board gaps over a chocolate core, benches z +-2.3..3.6. D04: 6 x 6 green studded
  plate under the base (stack +0.36), cloth y 14.0..20.1 z 0.3..10.3 with a full two-bend ripple, lifebuoy emblem
  R 1.55 with 4 red bands.

## Round 4 changes (AD r3 8.9; every ATT_* unchanged; r4 AD 9.0, ships below the 9.1 bar, see RESULT.md)

- H01: yellow table 0.6 wider each end, food 1.5x (plate r 1.0, bowl r 0.96, noodle dome to +1.5); a blue front
  serving counter with a white studded top at the open front (right corner, clear of the walk-in).
- H02: hearth +1 plate (top 1.3), taller 2-course stones (top 1.45); two chunky round 2-stud logs (r 0.42) crossed,
  tan end grain (LOD0 only); pale flame tip 1.5x. H04: tan seat slats, two tan back slats with a gap + top rail,
  armrests (tan 1 x 2 plate on a dark 1 x 1 post).
- H06: matching 2 x 2 brown brick posts (tan studded caps) at z +-4.5, 3.0-wide red / white sling. H07: body one brick
  taller (glass top 5.4, everything above the chassis +1.2), lower pink trim band, one big 2-stud wheel per end
  (tyre r 1.0, tan hub), umbrella +1.5 bricks (rim 8.4).
- H08: white 3 x 3 round top (r 1.45, top 4.2) on a blue rim, 2 cups. H09: hip-height barrel (top 2.2), small crate
  stack on the camera side. D04: 1-stud round pole, collar under the finial, gold ball 1.5x.
- LOD2 decimate ratio 1.6 (was 1.75) for the 3,000 ceiling (LOD2 2,852).

## ATT_* empties (local = module frame; y = up from the prop's ground)

Slot origins: `ATT_Canteen, ATT_Campfire, ATT_Bench, ATT_Hammock, ATT_Cart, ATT_ChatEast, ATT_ChatWest, ATT_FlowerBed,
ATT_PicnicTable, ATT_LampRow, ATT_FlagPole, ATT_Statue, ATT_Fountain` (H04 and H05 share `ATT_Bench`; H04 is also
cloned at the BenchB frame).

Worker spots: rest point (sit / lie: the spot's `rest`) or stand point (x, 0, z). Unchanged from Hangout.SPOTS.

| ATT | local (x, y, z) | Hangout.SPOTS index (act) |
|---|---|---|
| ATT_Canteen_EatFL | (-1.6, 2.0, -2.9) | 4 (Eat, sit) |
| ATT_Canteen_EatBR | (1.6, 2.0, 1.9) | 5 (Eat, sit) |
| ATT_Canteen_EatFR | (1.6, 2.0, -2.9) | 15 (Eat, sit) |
| ATT_Canteen_EatBL | (-1.6, 2.0, 1.9) | 20 (Eat, sit) |
| ATT_Campfire_SitFL | (-1.3, 1.3, -4.5) | 9 (Chat, sit) |
| ATT_Campfire_SitBR | (1.3, 1.3, 4.5) | 10 (Chat, sit) |
| ATT_Campfire_SitFR | (1.3, 1.3, -4.5) | 21 (Chat, sit) |
| ATT_Campfire_SitBL | (-1.3, 1.3, 4.5) | 24 (Chat, sit) |
| ATT_Campfire_WarmR | (4.6, 0, 0) | 16 (Warm, stand) |
| ATT_Campfire_WarmL | (-4.6, 0, 0) | 25 (Warm, stand) |
| ATT_Bench_SitL | (-1.2, 1.5, 0) | 3 at BenchA, 17 at BenchB (Phone, sit) |
| ATT_Bench_SitR | (1.2, 1.5, 0) | 12 at BenchA, 22 at BenchB (Phone, sit) |
| ATT_Hammock_Lie | (0, 2.3, 0) | 7 (Sleep, lie, head +z) |
| ATT_Cart_ConeL | (-1.3, 0, -3.2) | 6 (Cone, stand) |
| ATT_Cart_ConeR | (1.3, 0, -3.2) | 19 (Cone, stand) |
| ATT_ChatEast_01 / _02 / _03 | (0, 0, -1.8) / (1.56, 0, 0.9) / (-1.56, 0, 0.9) | 1 / 2 / 11 (Chat, stand) |
| ATT_ChatWest_L / _R | (-1.1, 0, 0) / (1.1, 0, 0) | 13 / 14 (Chat, stand) |

SPOTS 8, 18, 23 are Bunkhouse bunks (the Bunkhouse mesh): not in this kit. `python3 build.py` asserts that every other
index 1..25 has exactly one ATT and every name passes `names.RE_ATTACH`.

Light / code anchors: `ATT_Campfire_Flame` (0, 2.3, 0: code FlameCore, NightLamp), `ATT_Campfire_Lamp` (3.8, 6.2, 4.8),
`ATT_BenchPatio_Lamp` (6, 6.2, 1.55), `ATT_ChatWest_Lamp` (0, 5.8, 0.95), `ATT_LampRow_Lamp_01..03` (-3 / 0 / 3, 9.5, 0),
`ATT_FlagPole_Cloth` (0, 17.8, 3.6: the code Flag Part centre), `ATT_FlagPole_Top` (0, 20.8, 0),
`ATT_Fountain_Jet` (0, 5.15, 0: where the jet / splash VFX starts).

## Fits the code volumes

Seats sit on Hangout's heights: stools 2.0 (F 0.4 + STOOL 1.6), logs 1.3, benches 1.5, hammock 2.3; canteen floor
top 0.4. Canteen walls, roof, counter, table and stools fill the code Parts' volumes (the awning slopes 1 stud further
out at 5.6+ up, overhead). Decor stays inside its DockConfig size (umbrella / flag in the air excepted). No decor has
a prompt; the only anchors code uses by name are `Flag` (kept as a code Part) and FlameCore's NightLamp tag (moves to
H02_CampfireGlow).

## Icon match (marketing/items/Decor*.png)

- FlowerBed: dense multicolour flowers on dark soil in a brown raised bed on a green studded plate. No lilac cell:
  pink stands in for the icon's purple.
- PicnicTable: brown plank table with a red/white checked cloth on one half, two attached benches.
- LampRow: three black lamps with white globes and black conical caps (the globes are the lit mesh).
- FlagPole: grey round base, white pole, gold ball; red flag with a white lifebuoy = the code Flag Part (owner colour).
- Statue: gold minifig, right arm raised, red/white lifebuoy, grey stepped plinth with a light top.
- Fountain: grey/white round two-tier basin, blue water, small top bowl.

## Open questions

1. Patios grow past `Hangout.PROPS.size` (BenchPatio spans both benches; Cart +2.2 forward; ChatEast round). Grow
   the sizes (and rerun tests/Hangout.spec.luau) or confirm the streets / lots clearance some other way.
2. A single big west patio (benches + cart + hammock + ChatWest) would read even more as one place, but it needs a
   lots check (Marina.LOTS) the draft did not do.
3. Statue "gold" is the bright yellow cell (no metal map in the flat set); OK, or add a gold cell?
4. Flag cloth: keep the code Part (owner tint), or add a Lego flag mesh with the lifebuoy emblem and drop the tint?
5. LOD2 over the hero_building 3,000 ceiling: decimate or waiver.
