# M_Veh_MooredBoat_03 result

Validate: **PASS**, 1,436 checks, 0 failed, 87 waived (the spec's single trim-sheet waiver: bands tile in U and decimation keeps the bands but islands move). `check_textures.py` 28/28.

Triangles: LOD0 **15,276**, LOD1 **5,399**, LOD2 **1,322**, `_COL` 36. Size 4.36 x 15.54 x 8.97 m (15.0 m hull, 15.5 m LOA with the stern gear). Origin at the waterline, midships.

Set: shared **T_FishingBoat_Atlas** 2048, dry + wet. `BANDS` names, ranges and layout are identical to _01/_02; their files and outputs were not touched. Hull bands now bake one unique 0..0.8 U range (no 3 m tile holes or seams), so the old vertical grey bars on the side are gone.

Attachments unchanged: `ATT_Waterline`, `ATT_Moor_Bow`, `ATT_Moor_Stern`, `ATT_Boarding_Port`, `ATT_Boarding_Stbd`.

Fixes: bow name moved aft of the anchor and enlarged, "GALE ISLE PROVIDER" / "PH 42" fully legible on both bows, transom centred with margin; boarding gates are now solid plate with two stout posts and one top rail, bulwark reads solid, rust streaks fewer and broader, only three tyres on thicker lashings. HP is no longer a copy: weld beads, plate butts and rivet rows on hull topsides, antifoul and bulwark inner, all baked into NOR; other parts bake flat NOR. Wheelhouse panel seams stay as LOD0 trim baked into AO.

Open issues: no reference `dims.md`; 13 small parts proxied at LOD2; studio shots not run.
